#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  LJZ_MDCWB Part 2 (Revised) : Model + Fit Engine + Auto-detect
//
//  Depends on:
//    - LJZ_MDCWB Part 1 : Core data model + Persistence
//
//  Responsibilities:
//    1) Sanitize Work_* edit-state.
//    2) Assemble Work_* -> flat coefficient vector + hold mask + slot map.
//    3) Provide one generic MultiPeak FitFunc (LJZ_MDCWB_MultiPeakModel).
//    4) Build guess (in-memory + on-disk cache), run FuncFit, compute metrics,
//       save fit products (and only on user-driven save, the edit-state).
//    5) Provide semantic edit actions used by Part 3 callbacks.
//    6) Auto-init / auto-detect / per-peak component evaluation helpers.
//
//  Behavioral guarantees (DO NOT VIOLATE):
//    A. The edit-state on disk is touched only by:
//         - LJZ_MDCWB_SaveWorkToDisk      (explicit user save)
//         - LJZ_MDCWB_RunFit on success   (post-fit canonical save)
//       Building a guess, auto-init, auto-detect, sanitize, etc. NEVER write
//       the edit-state. This is the fix for the "preview silently overwrites
//       saved init" bug.
//    B. After LoadCurrentToWork(), Dirty == 0 only if the loaded edit-state
//       survived sanitation unchanged. Otherwise Dirty == 1.
//    C. resH and ROI are user inputs. Auto-init/auto-detect refresh peaks and
//       BG only; they do not clobber a non-default resH or a user ROI.
//    D. RunFit requires finiteCount >= max(2*P, P+10), where P = numpnts(coef).
//       Multi-peak fits over 13 points are no longer silently accepted.
//    E. Lor/Gau eta is forced both during sanitation, during assembly
//       (flatCoef[s+eta_slot] == 1 or 0), and during model evaluation.
//    F. During FuncFit, Active_peakTypes and Active_slotMap are frozen
//       snapshots; nothing else may write to them.
// ============================================================================


// ============================================================================
//  Section 0. Constants / fit-time active state
// ============================================================================

// Flat coef layout always starts with: c0, c1, c2, resH (4 slots). Per-peak
// slots follow. Keep this here; Part 1's PeakSlotCount() handles per-peak
// counts.
Function LJZ_MDCWB_FlatBaseSlots()
    return 4
End

Function LJZ_MDCWB_MinWidth()
    return 1e-6
End

Function LJZ_MDCWB_MinResH()
    return 1e-6
End

Function LJZ_MDCWB_DefaultPeakEta()
    return 0.7
End

Function LJZ_MDCWB_DefaultPeakWidthFromData(dataWave)
    Wave dataWave

    Variable dx = abs(DimDelta(dataWave, 0))
    if (numtype(dx) != 0 || dx <= 0)
        dx = 1
    endif
    return max(5 * dx, LJZ_MDCWB_MinWidth())
End

// Active_* are the snapshots FuncFit's MultiPeakModel uses while a fit is
// in flight. They are written by CopyActiveLayoutFromWork() right before
// FuncFit and never mutated mid-fit.
Function LJZ_MDCWB_EnsureFitEngineState()
    LJZ_MDCWB_EnsureBaseDF()

    String base = LJZ_MDCWB_BaseDF()

    Wave/Z activeTypes = $(base + ":Active_peakTypes")
    if (!WaveExists(activeTypes))
        Make/O/N=0 $(base + ":Active_peakTypes")
    endif

    Wave/Z activeSlotMap = $(base + ":Active_slotMap")
    if (!WaveExists(activeSlotMap))
        Make/O/N=1 $(base + ":Active_slotMap") = LJZ_MDCWB_FlatBaseSlots()
    endif

    Wave/Z activeSigma = $(base + ":Active_lastSigma")
    if (!WaveExists(activeSigma))
        Make/O/N=0 $(base + ":Active_lastSigma") = NaN
    endif

    return 0
End


// ============================================================================
//  Section 1. Kernel functions
//
//  Convention:
//    w / wL / wR are HWHM-like widths BEFORE instrumental broadening.
//    resH is folded in via sqrt(w^2 + resH^2). This keeps the parameter
//    role compatible with the historical resH behavior without external XOPs.
// ============================================================================

Function LJZ_MDCWB_EffectiveHWHM(widthIn, resHIn)
    Variable widthIn, resHIn

    Variable w = abs(widthIn)
    Variable r = abs(resHIn)
    if (numtype(w) != 0 || w < LJZ_MDCWB_MinWidth())
        w = LJZ_MDCWB_MinWidth()
    endif
    if (numtype(r) != 0 || r < LJZ_MDCWB_MinResH())
        r = LJZ_MDCWB_MinResH()
    endif
    return sqrt(w*w + r*r)
End

Function LJZ_MDCWB_PVKernel(H, x, x0, widthIn, etaIn, resHIn)
    Variable H, x, x0, widthIn, etaIn, resHIn

    if (numtype(H) != 0 || numtype(x0) != 0)
        return 0
    endif

    Variable eta = etaIn
    if (numtype(eta) != 0)
        eta = LJZ_MDCWB_DefaultPeakEta()
    endif
    eta = min(1, max(0, eta))

    Variable wEff = LJZ_MDCWB_EffectiveHWHM(widthIn, resHIn)
    Variable u = (x - x0) / wEff

    Variable lor = 1 / (1 + u*u)
    Variable gau = exp(-ln(2) * u*u)

    return H * (eta * lor + (1 - eta) * gau)
End

Function LJZ_MDCWB_AsymPVKernel(H, x, x0, wLIn, wRIn, etaIn, resHIn)
    Variable H, x, x0, wLIn, wRIn, etaIn, resHIn

    Variable wUse
    if (x < x0)
        wUse = wLIn
    else
        wUse = wRIn
    endif
    return LJZ_MDCWB_PVKernel(H, x, x0, wUse, etaIn, resHIn)
End


// ============================================================================
//  Section 2. Sanitation
// ============================================================================

// Idempotent: if the row is already valid, returns 0 with no changes.
// If anything was changed, returns 1 (caller can decide whether to mark dirty).
Function LJZ_MDCWB_SanitizePeakRow(wPN, wPH, ip)
    Wave wPN, wPH
    Variable ip

    Variable changed = 0

    Variable t = round(wPN[ip][0])
    if (!LJZ_MDCWB_IsValidPeakType(t))
        t = LJZ_MDCWB_PeakTypePV()
        changed = 1
    endif
    if (wPN[ip][0] != t)
        wPN[ip][0] = t
        changed = 1
    endif

    if (numtype(wPN[ip][1]) != 0)
        wPN[ip][1] = 0
        changed = 1
    endif

    Variable wOld = wPN[ip][2]
    if (numtype(wOld) != 0 || wOld <= 0)
        wPN[ip][2] = LJZ_MDCWB_MinWidth()
        changed = 1
    else
        Variable wNew = max(LJZ_MDCWB_MinWidth(), abs(wOld))
        if (wNew != wOld)
            wPN[ip][2] = wNew
            changed = 1
        endif
    endif

    if (t == LJZ_MDCWB_PeakTypeAsymPV())
        Variable wRold = wPN[ip][3]
        if (numtype(wRold) != 0 || wRold <= 0)
            wPN[ip][3] = wPN[ip][2]
            changed = 1
        else
            Variable wRnew = max(LJZ_MDCWB_MinWidth(), abs(wRold))
            if (wRnew != wRold)
                wPN[ip][3] = wRnew
                changed = 1
            endif
        endif
    else
        if (numtype(wPN[ip][3]) == 0)
            wPN[ip][3] = NaN
            changed = 1
        endif
        // wR has no meaning for non-AsymPV → force its hold true so an old
        // 1 in the hold mask stays consistent with the unused value.
        if (wPH[ip][2] != 1)
            wPH[ip][2] = 1
            changed = 1
        endif
    endif

    if (numtype(wPN[ip][4]) != 0)
        wPN[ip][4] = 0
        changed = 1
    endif

    if (t == LJZ_MDCWB_PeakTypeLor())
        if (wPN[ip][5] != 1)
            wPN[ip][5] = 1
            changed = 1
        endif
        if (wPH[ip][4] != 1)
            wPH[ip][4] = 1
            changed = 1
        endif
    elseif (t == LJZ_MDCWB_PeakTypeGau())
        if (wPN[ip][5] != 0)
            wPN[ip][5] = 0
            changed = 1
        endif
        if (wPH[ip][4] != 1)
            wPH[ip][4] = 1
            changed = 1
        endif
    else
        if (numtype(wPN[ip][5]) != 0)
            wPN[ip][5] = LJZ_MDCWB_DefaultPeakEta()
            changed = 1
        else
            Variable etaClamped = min(1, max(0, wPN[ip][5]))
            if (etaClamped != wPN[ip][5])
                wPN[ip][5] = etaClamped
                changed = 1
            endif
        endif
    endif

    if (numtype(wPN[ip][6]) != 0)
        wPN[ip][6] = 0
        changed = 1
    endif

    Variable ih
    for (ih = 0; ih < LJZ_MDCWB_PeaksHoldCols(); ih += 1)
        Variable hVal = (wPH[ip][ih] != 0) ? 1 : 0
        if (wPH[ip][ih] != hVal)
            wPH[ip][ih] = hVal
            changed = 1
        endif
    endfor

    return changed
End

// Returns 1 if any sanitation made a change, 0 otherwise.
Function LJZ_MDCWB_SanitizeWorkState()
    LJZ_MDCWB_EnsureBaseDF()

    String base = LJZ_MDCWB_BaseDF()
    Wave wPN  = $(base + ":Work_peaks_num")
    Wave wPH  = $(base + ":Work_peaks_hold")
    Wave wBG  = $(base + ":Work_bg")
    Wave wRH  = $(base + ":Work_resH")
    Wave wROI = $(base + ":Work_roi")

    Variable changed = 0

    Variable nPN = DimSize(wPN, 0)
    Variable nPH = DimSize(wPH, 0)
    Variable n = min(nPN, nPH)
    if (n < 0)
        n = 0
    endif
    if (n > LJZ_MDCWB_MaxPeaks())
        n = LJZ_MDCWB_MaxPeaks()
        changed = 1
    endif

    if (DimSize(wPN, 0) != n || DimSize(wPN, 1) != LJZ_MDCWB_PeaksNumCols())
        Redimension/N=(n, LJZ_MDCWB_PeaksNumCols()) wPN
        changed = 1
    endif
    if (DimSize(wPH, 0) != n || DimSize(wPH, 1) != LJZ_MDCWB_PeaksHoldCols())
        Redimension/N=(n, LJZ_MDCWB_PeaksHoldCols()) wPH
        changed = 1
    endif

    Variable ip
    for (ip = 0; ip < n; ip += 1)
        if (LJZ_MDCWB_SanitizePeakRow(wPN, wPH, ip))
            changed = 1
        endif
    endfor

    if (numpnts(wBG) != LJZ_MDCWB_BGSize())
        Redimension/N=(LJZ_MDCWB_BGSize()) wBG
        changed = 1
    endif

    Variable bgOrderClamped
    if (numtype(wBG[0]) != 0)
        bgOrderClamped = 2
    else
        bgOrderClamped = round(min(2, max(0, wBG[0])))
    endif
    if (wBG[0] != bgOrderClamped)
        wBG[0] = bgOrderClamped
        changed = 1
    endif

    Variable ib
    for (ib = 1; ib <= 3; ib += 1)
        if (numtype(wBG[ib]) != 0)
            wBG[ib] = 0
            changed = 1
        endif
    endfor
    Variable bgMaskClamped
    if (numtype(wBG[4]) != 0)
        bgMaskClamped = 0
    else
        bgMaskClamped = round(wBG[4]) & 7
    endif
    if (wBG[4] != bgMaskClamped)
        wBG[4] = bgMaskClamped
        changed = 1
    endif
    if (numtype(wBG[5]) == 0)
        wBG[5] = NaN
        changed = 1
    endif

    if (numpnts(wRH) != LJZ_MDCWB_ResHSize())
        Redimension/N=(LJZ_MDCWB_ResHSize()) wRH
        changed = 1
    endif
    Variable resHNew
    if (numtype(wRH[0]) != 0 || wRH[0] <= 0)
        resHNew = LJZ_MDCWB_MinResH()
    else
        resHNew = max(LJZ_MDCWB_MinResH(), abs(wRH[0]))
    endif
    if (resHNew != wRH[0])
        wRH[0] = resHNew
        changed = 1
    endif
    Variable resHHoldNew = (wRH[1] != 0) ? 1 : 0
    if (resHHoldNew != wRH[1])
        wRH[1] = resHHoldNew
        changed = 1
    endif

    if (numpnts(wROI) != LJZ_MDCWB_ROISize())
        Redimension/N=(LJZ_MDCWB_ROISize()) wROI
        wROI = NaN
        changed = 1
    endif

    NVAR/Z selPeak = $(base + ":Work_selectedPeak")
    if (NVAR_Exists(selPeak))
        if (selPeak < 0 || selPeak >= n)
            if (selPeak != -1)
                selPeak = -1
                changed = 1
            endif
        endif
    endif

    return changed
End


// ============================================================================
//  Section 3. Semantic edit actions (called by Part 3 callbacks)
// ============================================================================

Function LJZ_MDCWB_SetPeakType(idx, newType)
    Variable idx, newType

    LJZ_MDCWB_EnsureBaseDF()
    Variable n = LJZ_MDCWB_WorkNumPeaks()
    if (idx < 0 || idx >= n || !LJZ_MDCWB_IsValidPeakType(newType))
        LJZ_MDCWB_SetLastError("Invalid peak type change.")
        return -1
    endif

    Wave wPN = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
    Wave wPH = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_hold")

    Variable nt = round(newType)
    wPN[idx][0] = nt

    if (nt == LJZ_MDCWB_PeakTypeAsymPV())
        if (numtype(wPN[idx][3]) != 0 || wPN[idx][3] <= 0)
            wPN[idx][3] = wPN[idx][2]
        endif
        // wR free now → its hold may be cleared (user can re-hold if wanted)
        wPH[idx][2] = 0
    elseif (nt == LJZ_MDCWB_PeakTypeLor())
        wPN[idx][3] = NaN
        wPN[idx][5] = 1
        wPH[idx][2] = 1
        wPH[idx][4] = 1
    elseif (nt == LJZ_MDCWB_PeakTypeGau())
        wPN[idx][3] = NaN
        wPN[idx][5] = 0
        wPH[idx][2] = 1
        wPH[idx][4] = 1
    else
        // PV: wR not used; eta becomes a free PV parameter again.
        wPN[idx][3] = NaN
        if (numtype(wPN[idx][5]) != 0)
            wPN[idx][5] = LJZ_MDCWB_DefaultPeakEta()
        endif
        wPH[idx][2] = 1
        // Clear eta-hold so going Lor->PV does not lock eta forever.
        wPH[idx][4] = 0
    endif

    LJZ_MDCWB_SanitizePeakRow(wPN, wPH, idx)
    LJZ_MDCWB_MarkDirty(1)
    LJZ_MDCWB_ClearLastError()
    return 0
End

Function LJZ_MDCWB_AddPeak(t, x0, w, H)
    Variable t, x0, w, H

    Variable idx = LJZ_MDCWB_WorkAppendPeak(t, x0, w, H)
    if (idx < 0)
        LJZ_MDCWB_SetLastError("Could not add peak.")
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif

    Wave wPN = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
    Wave wPH = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_hold")
    LJZ_MDCWB_SanitizePeakRow(wPN, wPH, idx)

    NVAR selPeak = $(LJZ_MDCWB_BaseDF() + ":Work_selectedPeak")
    selPeak = idx

    LJZ_MDCWB_MarkDirty(1)
    LJZ_MDCWB_ClearLastError()
    return idx
End

Function LJZ_MDCWB_DeletePeak(idx)
    Variable idx

    Variable rc = LJZ_MDCWB_WorkDeletePeak(idx)
    if (rc != 0)
        LJZ_MDCWB_SetLastError("Could not delete peak.")
        return -1
    endif

    LJZ_MDCWB_MarkDirty(1)
    LJZ_MDCWB_ClearLastError()
    return 0
End

Function LJZ_MDCWB_SetPeakField(idx, fieldId, val)
    Variable idx, fieldId, val

    if (fieldId == LJZ_MDCWB_FieldType())
        return LJZ_MDCWB_SetPeakType(idx, val)
    endif

    Variable rc = LJZ_MDCWB_WorkSetPeakField(idx, fieldId, val)
    if (rc != 0)
        LJZ_MDCWB_SetLastError("Could not set peak field.")
        return -1
    endif

    Wave wPN = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
    Wave wPH = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_hold")
    LJZ_MDCWB_SanitizePeakRow(wPN, wPH, idx)

    LJZ_MDCWB_MarkDirty(1)
    LJZ_MDCWB_ClearLastError()
    return 0
End

Function LJZ_MDCWB_HasFreeAsymPVWidthWithFreeResH()
    Wave wPN = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
    Wave wPH = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_hold")
    Wave wRH = $(LJZ_MDCWB_BaseDF() + ":Work_resH")
    if (!WaveExists(wPN) || !WaveExists(wPH) || !WaveExists(wRH))
        return 0
    endif
    if (numpnts(wRH) < 2 || wRH[1] != 0)
        return 0
    endif
    Variable np = DimSize(wPN, 0)
    Variable ip
    for (ip = 0; ip < np; ip += 1)
        if (round(wPN[ip][0]) == LJZ_MDCWB_PeakTypeAsymPV())
            if ((wPH[ip][1] == 0) || (wPH[ip][2] == 0))
                return 1
            endif
        endif
    endfor
    return 0
End

Function LJZ_MDCWB_SetPeakHold(idx, holdFieldId, on)
    Variable idx, holdFieldId, on

    Variable rc = LJZ_MDCWB_WorkSetPeakHold(idx, holdFieldId, on)
    if (rc != 0)
        LJZ_MDCWB_SetLastError("Could not set peak hold.")
        return -1
    endif

    Wave wPN = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
    Wave wPH = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_hold")
    LJZ_MDCWB_SanitizePeakRow(wPN, wPH, idx)

    LJZ_MDCWB_MarkDirty(1)
    LJZ_MDCWB_ClearLastError()
    return 0
End

Function LJZ_MDCWB_SelectPeak(idx)
    Variable idx

    LJZ_MDCWB_EnsureBaseDF()
    Variable n = LJZ_MDCWB_WorkNumPeaks()
    NVAR selPeak = $(LJZ_MDCWB_BaseDF() + ":Work_selectedPeak")

    if (idx < 0 || idx >= n)
        selPeak = -1
    else
        selPeak = idx
    endif
    return 0
End

Function LJZ_MDCWB_SetBGOrder(order)
    Variable order
    LJZ_MDCWB_WorkSetBGOrder(order)
    LJZ_MDCWB_SanitizeWorkState()
    LJZ_MDCWB_MarkDirty(1)
    return 0
End

Function LJZ_MDCWB_SetBGCoef(i, val)
    Variable i, val
    Variable rc = LJZ_MDCWB_WorkSetBGCoef(i, val)
    if (rc != 0)
        LJZ_MDCWB_SetLastError("Could not set background coefficient.")
        return -1
    endif
    LJZ_MDCWB_MarkDirty(1)
    return 0
End

Function LJZ_MDCWB_SetBGHold(i, on)
    Variable i, on
    Variable rc = LJZ_MDCWB_WorkSetBGHold(i, on)
    if (rc != 0)
        LJZ_MDCWB_SetLastError("Could not set background hold.")
        return -1
    endif
    LJZ_MDCWB_MarkDirty(1)
    return 0
End

Function LJZ_MDCWB_SetResH(val)
    Variable val
    LJZ_MDCWB_WorkSetResH(val)
    LJZ_MDCWB_SanitizeWorkState()
    LJZ_MDCWB_MarkDirty(1)
    return 0
End

Function LJZ_MDCWB_SetResHHold(on)
    Variable on
    LJZ_MDCWB_WorkSetResHHold(on)
    LJZ_MDCWB_MarkDirty(1)
    return 0
End

Function LJZ_MDCWB_SetROI(xLo, xHi)
    Variable xLo, xHi
    LJZ_MDCWB_WorkSetROI(xLo, xHi)
    LJZ_MDCWB_MarkDirty(1)
    return 0
End

// Explicit user save: this is the ONE place outside of RunFit that writes
// the edit-state to disk.
Function LJZ_MDCWB_SaveWorkToDisk(wData)
    Wave wData

    LJZ_MDCWB_SanitizeWorkState()
    Variable rc = LJZ_MDCWB_SaveEditStateFromWork(wData)
    if (rc != 0)
        LJZ_MDCWB_SetLastError("Saving edit state failed.")
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif
    LJZ_MDCWB_MarkDirty(0)
    LJZ_MDCWB_ClearLastError()
    return 0
End

Function LJZ_MDCWB_SetAccept(wData, state)
    Wave wData
    Variable state

    Variable rc = LJZ_MDCWB_WriteAcceptState(wData, state)
    if (rc != 0)
        LJZ_MDCWB_SetLastError("Accept-state write failed.")
        return -1
    endif
    return 0
End


// ============================================================================
//  Section 4. ROI and metrics
// ============================================================================

Function LJZ_MDCWB_GetROIIndexRange(dataWave, roiXLoInput, roiXHiInput, roiIndexLo, roiIndexHi)
    Wave dataWave
    Variable roiXLoInput, roiXHiInput
    Variable &roiIndexLo, &roiIndexHi

    Variable pointCount = numpnts(dataWave)
    Variable axisX0 = DimOffset(dataWave, 0)
    Variable axisDX = DimDelta(dataWave, 0)

    if (numtype(axisDX) != 0 || axisDX == 0)
        axisDX = 1
    endif

    if (pointCount <= 0)
        roiIndexLo = 0
        roiIndexHi = -1
        return -1
    endif

    if (numtype(roiXLoInput) != 0 || numtype(roiXHiInput) != 0)
        roiIndexLo = 0
        roiIndexHi = pointCount - 1
        return 0
    endif

    Variable roiXMin = min(roiXLoInput, roiXHiInput)
    Variable roiXMax = max(roiXLoInput, roiXHiInput)

    roiIndexLo = round((roiXMin - axisX0) / axisDX)
    roiIndexHi = round((roiXMax - axisX0) / axisDX)

    roiIndexLo = max(0, min(pointCount - 1, roiIndexLo))
    roiIndexHi = max(0, min(pointCount - 1, roiIndexHi))

    if (roiIndexHi < roiIndexLo)
        Variable tmp = roiIndexLo
        roiIndexLo = roiIndexHi
        roiIndexHi = tmp
    endif

    return 0
End

Function LJZ_MDCWB_CountFinitePointsInROI(dataWave, roiXLoInput, roiXHiInput)
    Wave dataWave
    Variable roiXLoInput, roiXHiInput

    Variable lo, hi
    if (LJZ_MDCWB_GetROIIndexRange(dataWave, roiXLoInput, roiXHiInput, lo, hi) != 0)
        return 0
    endif

    Variable cnt = 0
    Variable ip
    for (ip = lo; ip <= hi; ip += 1)
        if (numtype(dataWave[ip]) == 0)
            cnt += 1
        endif
    endfor
    return cnt
End

Function LJZ_MDCWB_ComputeFitMetrics(dataWave, guessWave, fitWave, resWave, roiXLoInput, roiXHiInput, guessRMSEOut, fitRMSEOut, rssROIOut, maxAbsResOut, nROIOut)
    Wave dataWave, guessWave, fitWave, resWave
    Variable roiXLoInput, roiXHiInput
    Variable &guessRMSEOut, &fitRMSEOut, &rssROIOut, &maxAbsResOut, &nROIOut

    guessRMSEOut = NaN
    fitRMSEOut = NaN
    rssROIOut = NaN
    maxAbsResOut = NaN
    nROIOut = 0

    Variable lo, hi
    if (LJZ_MDCWB_GetROIIndexRange(dataWave, roiXLoInput, roiXHiInput, lo, hi) != 0)
        return -1
    endif

    Variable guessCount = 0
    Variable fitCount = 0
    Variable guessSq = 0
    Variable fitSq = 0
    Variable maxAbs = NaN
    Variable ip, dv, gv, fv, rv, ar

    for (ip = lo; ip <= hi; ip += 1)
        dv = dataWave[ip]
        gv = guessWave[ip]
        fv = fitWave[ip]
        rv = resWave[ip]

        if (numtype(dv) == 0 && numtype(gv) == 0)
            guessSq += (dv - gv)^2
            guessCount += 1
        endif

        if (numtype(dv) == 0 && numtype(fv) == 0 && numtype(rv) == 0)
            fitSq += rv^2
            fitCount += 1
            ar = abs(rv)
            if (numtype(maxAbs) != 0 || ar > maxAbs)
                maxAbs = ar
            endif
        endif
    endfor

    if (guessCount <= 0 || fitCount <= 0)
        return -1
    endif

    guessRMSEOut = sqrt(guessSq / guessCount)
    fitRMSEOut = sqrt(fitSq / fitCount)
    rssROIOut = fitSq
    maxAbsResOut = maxAbs
    nROIOut = fitCount
    return 0
End

Function LJZ_MDCWB_BuildInfoWave(infoWave, bgOrderInput, roiXLoInput, roiXHiInput, fitOKInput, guessRMSEInput, fitRMSEInput, rssROIInput, maxAbsResInput, nROIInput, fitQuitReasonInput, fitNumItersInput)
    Wave infoWave
    Variable bgOrderInput, roiXLoInput, roiXHiInput
    Variable fitOKInput, guessRMSEInput, fitRMSEInput, rssROIInput, maxAbsResInput, nROIInput
    Variable fitQuitReasonInput, fitNumItersInput

    LJZ_MDCWB_InitFitInfoWave(infoWave)

    infoWave[0]  = 0
    infoWave[1]  = round(min(2, max(0, bgOrderInput)))
    infoWave[2]  = roiXLoInput
    infoWave[3]  = roiXHiInput
    infoWave[4]  = (fitOKInput > 0.5) ? 1 : 0
    infoWave[5]  = guessRMSEInput
    infoWave[6]  = fitRMSEInput
    infoWave[7]  = rssROIInput
    infoWave[8]  = maxAbsResInput
    infoWave[9]  = nROIInput
    infoWave[10] = fitQuitReasonInput
    infoWave[11] = fitNumItersInput
    return 0
End


// ============================================================================
//  Section 5. Flat parameter assembly / distribution
//
//  flat layout:
//      [0] c0   [1] c1   [2] c2   [3] resH
//      per-peak (in order):
//         PV/Lor/Gau:  [x0, w, H, eta]
//         AsymPV:      [x0, wL, wR, H, eta]
//
//  ASSEMBLE INVARIANT:
//      For Lor peaks, flatCoef[s+3] is forced to 1 and flatHold[s+3] = 1.
//      For Gau peaks, flatCoef[s+3] is forced to 0 and flatHold[s+3] = 1.
//      This is belt-and-braces: even if Work_* is briefly inconsistent,
//      the value pushed to FuncFit is correct.
// ============================================================================

Function/S LJZ_MDCWB_BuildHoldMask(flatHold)
    Wave flatHold

    String s = ""
    Variable i
    for (i = 0; i < numpnts(flatHold); i += 1)
        if (flatHold[i] != 0)
            s += "1"
        else
            s += "0"
        endif
    endfor
    return s
End

Function LJZ_MDCWB_AssembleFitParams(flatCoef, flatHold, slotMap, holdMask)
    Wave flatCoef, flatHold, slotMap
    String &holdMask

    LJZ_MDCWB_SanitizeWorkState()

    String base = LJZ_MDCWB_BaseDF()
    Wave wPN = $(base + ":Work_peaks_num")
    Wave wPH = $(base + ":Work_peaks_hold")
    Wave wBG = $(base + ":Work_bg")
    Wave wRH = $(base + ":Work_resH")

    Variable nPeak = DimSize(wPN, 0)
    Variable totalSlots = LJZ_MDCWB_FlatBaseSlots()
    Variable ip
    for (ip = 0; ip < nPeak; ip += 1)
        totalSlots += LJZ_MDCWB_PeakSlotCount(wPN[ip][0])
    endfor

    Redimension/N=(totalSlots) flatCoef, flatHold
    Redimension/N=(nPeak + 1) slotMap
    flatCoef = NaN
    flatHold = 0

    Variable bgOrder = round(wBG[0])
    Variable bgMask = round(wBG[4]) & 7

    flatCoef[0] = wBG[1]
    flatCoef[1] = wBG[2]
    flatCoef[2] = wBG[3]
    flatCoef[3] = wRH[0]

    flatHold[0] = ((bgMask & 1) != 0) ? 1 : 0
    flatHold[1] = (((bgMask & 2) != 0) || (bgOrder < 1)) ? 1 : 0
    flatHold[2] = (((bgMask & 4) != 0) || (bgOrder < 2)) ? 1 : 0
    flatHold[3] = (wRH[1] != 0) ? 1 : 0

    Variable cursor = LJZ_MDCWB_FlatBaseSlots()
    Variable t
    for (ip = 0; ip < nPeak; ip += 1)
        t = round(wPN[ip][0])
        slotMap[ip] = cursor

        flatCoef[cursor + 0] = wPN[ip][1]    // x0
        flatCoef[cursor + 1] = wPN[ip][2]    // w (or wL)

        if (t == LJZ_MDCWB_PeakTypeAsymPV())
            flatCoef[cursor + 2] = wPN[ip][3]  // wR
            flatCoef[cursor + 3] = wPN[ip][4]  // H
            flatCoef[cursor + 4] = wPN[ip][5]  // eta

            flatHold[cursor + 0] = (wPH[ip][0] != 0) ? 1 : 0
            flatHold[cursor + 1] = (wPH[ip][1] != 0) ? 1 : 0
            flatHold[cursor + 2] = (wPH[ip][2] != 0) ? 1 : 0
            flatHold[cursor + 3] = (wPH[ip][3] != 0) ? 1 : 0
            flatHold[cursor + 4] = (wPH[ip][4] != 0) ? 1 : 0

            cursor += 5
        else
            flatCoef[cursor + 2] = wPN[ip][4]  // H
            flatCoef[cursor + 3] = wPN[ip][5]  // eta

            flatHold[cursor + 0] = (wPH[ip][0] != 0) ? 1 : 0
            flatHold[cursor + 1] = (wPH[ip][1] != 0) ? 1 : 0
            flatHold[cursor + 2] = (wPH[ip][3] != 0) ? 1 : 0
            flatHold[cursor + 3] = (wPH[ip][4] != 0) ? 1 : 0

            // Belt-and-braces: force eta value AND hold for Lor/Gau,
            // even if SanitizePeakRow already did so.
            if (t == LJZ_MDCWB_PeakTypeLor())
                flatCoef[cursor + 3] = 1
                flatHold[cursor + 3] = 1
            elseif (t == LJZ_MDCWB_PeakTypeGau())
                flatCoef[cursor + 3] = 0
                flatHold[cursor + 3] = 1
            endif

            cursor += 4
        endif
    endfor
    slotMap[nPeak] = cursor

    holdMask = LJZ_MDCWB_BuildHoldMask(flatHold)
    return 0
End

Function LJZ_MDCWB_CopyActiveLayoutFromWork(slotMap)
    Wave slotMap

    LJZ_MDCWB_EnsureFitEngineState()

    String base = LJZ_MDCWB_BaseDF()
    Wave wPN = $(base + ":Work_peaks_num")
    Variable nPeak = DimSize(wPN, 0)

    Make/O/N=(nPeak) $(base + ":Active_peakTypes")
    Make/O/N=(nPeak + 1) $(base + ":Active_slotMap")

    Wave activeTypes   = $(base + ":Active_peakTypes")
    Wave activeSlotMap = $(base + ":Active_slotMap")

    // Active_* is only a live evaluator snapshot for FuncFit callbacks.
    // Persistent fit metadata must be re-derived from per-wave fit records.
    Make/FREE/N=(nPeak) rebuiltTypes
    Make/FREE/N=(nPeak + 1) rebuiltSlots
    if (LJZ_MDCWB_BuildLayoutFromPeaksNum(wPN, rebuiltTypes, rebuiltSlots) != 0)
        return -1
    endif
    if (numpnts(slotMap) < nPeak + 1)
        return -1
    endif

    Variable ip
    for (ip = 0; ip < nPeak; ip += 1)
        activeTypes[ip] = rebuiltTypes[ip]
        // keep the caller-provided slot map used for this fit pass
        activeSlotMap[ip] = slotMap[ip]
    endfor
    activeSlotMap[nPeak] = slotMap[nPeak]

    return 0
End

Function LJZ_MDCWB_BuildLayoutFromPeaksNum(pn, types, slotMap)
    Wave pn, types, slotMap

    Variable nPeak = DimSize(pn, 0)
    if (DimSize(pn, 1) != LJZ_MDCWB_PeaksNumCols())
        return -1
    endif
    if (nPeak < 0)
        return -1
    endif
    if (nPeak > LJZ_MDCWB_MaxPeaks())
        return -1
    endif

    Redimension/N=(nPeak) types
    Redimension/N=(nPeak + 1) slotMap

    Variable cursor = LJZ_MDCWB_FlatBaseSlots()
    Variable ip, t, nSlot
    for (ip = 0; ip < nPeak; ip += 1)
        t = round(pn[ip][0])
        if (!LJZ_MDCWB_IsValidPeakType(t))
            return -1
        endif
        nSlot = LJZ_MDCWB_PeakSlotCount(t)
        if (nSlot <= 0)
            return -1
        endif
        types[ip] = t
        slotMap[ip] = cursor
        cursor += nSlot
    endfor
    slotMap[nPeak] = cursor

    return 0
End

Function LJZ_MDCWB_DistributeFitResult(flatCoef, flatSigma, slotMap)
    Wave flatCoef, slotMap
    Wave/Z flatSigma

    LJZ_MDCWB_EnsureBaseDF()

    String base = LJZ_MDCWB_BaseDF()
    Wave wPN = $(base + ":Work_peaks_num")
    Wave wBG = $(base + ":Work_bg")
    Wave wRH = $(base + ":Work_resH")
    Variable debugAsym = 0

    Variable nPeak = DimSize(wPN, 0)
    if (numpnts(slotMap) < nPeak + 1)
        return -1
    endif
    if (numpnts(flatCoef) < slotMap[nPeak])
        return -1
    endif

    wBG[1] = flatCoef[0]
    wBG[2] = flatCoef[1]
    wBG[3] = flatCoef[2]
    wRH[0] = flatCoef[3]

    Variable ip, s, t
    for (ip = 0; ip < nPeak; ip += 1)
        s = slotMap[ip]
        t = round(wPN[ip][0])

        wPN[ip][1] = flatCoef[s + 0]
        wPN[ip][2] = flatCoef[s + 1]

        if (t == LJZ_MDCWB_PeakTypeAsymPV())
            wPN[ip][3] = flatCoef[s + 2]
            wPN[ip][4] = flatCoef[s + 3]
            wPN[ip][5] = flatCoef[s + 4]
            if (debugAsym)
                Print "AsymPV result ip=", ip, " x0=", wPN[ip][1], " wL=", wPN[ip][2], " wR=", wPN[ip][3], " H=", wPN[ip][4], " eta=", wPN[ip][5]
            endif
        else
            wPN[ip][3] = NaN
            wPN[ip][4] = flatCoef[s + 2]
            wPN[ip][5] = flatCoef[s + 3]
        endif
    endfor

    LJZ_MDCWB_SanitizeWorkState()

    if (WaveExists(flatSigma))
        Duplicate/O flatSigma, $(base + ":Active_lastSigma")
    else
        Make/O/N=(numpnts(flatCoef)) $(base + ":Active_lastSigma") = NaN
    endif

    return 0
End


// ============================================================================
//  Section 6. Generic FitFunc
// ============================================================================

Function LJZ_MDCWB_MultiPeakModel(w, x) : FitFunc
    Wave w
    Variable x

    Wave/Z types = root:Packages:ARPES_LJZ:MDCWB:Active_peakTypes
    Wave/Z slots = root:Packages:ARPES_LJZ:MDCWB:Active_slotMap

    if (!WaveExists(types) || !WaveExists(slots))
        return NaN
    endif

    Variable nPeak = numpnts(types)
    if (numpnts(slots) < nPeak + 1 || numpnts(w) < LJZ_MDCWB_FlatBaseSlots())
        return NaN
    endif

    Variable c0 = w[0]
    Variable c1 = w[1]
    Variable c2 = w[2]
    Variable resH = max(LJZ_MDCWB_MinResH(), abs(w[3]))

    Variable y = c0 + c1 * x + c2 * x * x
    Variable ip, s, t, etaUse

    for (ip = 0; ip < nPeak; ip += 1)
        s = slots[ip]
        t = round(types[ip])

        if (t == LJZ_MDCWB_PeakTypeAsymPV())
            if (numpnts(w) >= s + 5)
                y += LJZ_MDCWB_AsymPVKernel(w[s + 3], x, w[s + 0], w[s + 1], w[s + 2], w[s + 4], resH)
            endif
        else
            if (numpnts(w) >= s + 4)
                etaUse = w[s + 3]
                if (t == LJZ_MDCWB_PeakTypeLor())
                    etaUse = 1
                elseif (t == LJZ_MDCWB_PeakTypeGau())
                    etaUse = 0
                endif
                y += LJZ_MDCWB_PVKernel(w[s + 2], x, w[s + 0], w[s + 1], etaUse, resH)
            endif
        endif
    endfor

    return y
End

Function LJZ_MDCWB_EvaluateModelWave(dataWave, coefW, outWave)
    Wave dataWave, coefW, outWave

    if (numpnts(outWave) != numpnts(dataWave))
        Redimension/N=(numpnts(dataWave)) outWave
    endif
    SetScale/P x, DimOffset(dataWave, 0), DimDelta(dataWave, 0), outWave
    outWave = LJZ_MDCWB_MultiPeakModel(coefW, x)
    return 0
End


// ============================================================================
//  Section 7. Auto-init / Auto-detect / Load helpers
//
//  Important behavior change vs. previous version:
//    - AutoInit no longer overwrites a user-set ROI or non-default resH.
//    - AutoInit/AutoDetect never write the edit-state to disk.
// ============================================================================

Function LJZ_MDCWB_EstimateBaselineInROI(dataWave, roiLo, roiHi)
    Wave dataWave
    Variable roiLo, roiHi

    Variable lo, hi
    if (LJZ_MDCWB_GetROIIndexRange(dataWave, roiLo, roiHi, lo, hi) != 0)
        return 0
    endif

    Variable n = hi - lo + 1
    if (n <= 0)
        return 0
    endif

    Variable edgeN = max(1, min(5, floor(n / 5)))
    Variable sum = 0
    Variable cnt = 0
    Variable i, v

    for (i = 0; i < edgeN; i += 1)
        v = dataWave[lo + i]
        if (numtype(v) == 0)
            sum += v
            cnt += 1
        endif
        v = dataWave[hi - i]
        if (numtype(v) == 0)
            sum += v
            cnt += 1
        endif
    endfor

    if (cnt <= 0)
        return 0
    endif
    return sum / cnt
End

// AutoInit: replace peaks with a single best-guess peak; refresh BG and
// keep user ROI / resH if already set. Marks Dirty (Part 3 will refresh UI).
Function LJZ_MDCWB_AutoInitFromData(wData)
    Wave wData

    LJZ_MDCWB_EnsureBaseDF()

    Variable nPts = numpnts(wData)
    if (nPts < 5)
        LJZ_MDCWB_SetLastError("Too few data points for auto init.")
        return -1
    endif

    Variable axisX0 = DimOffset(wData, 0)
    Variable axisDX = DimDelta(wData, 0)
    if (numtype(axisDX) != 0 || axisDX == 0)
        axisDX = 1
    endif
    Variable fullLo = axisX0
    Variable fullHi = axisX0 + axisDX * (nPts - 1)

    // Preserve user-set ROI; only fill if missing.
    Variable xLo, xHi
    LJZ_MDCWB_WorkGetROI(xLo, xHi)
    if (numtype(xLo) != 0 || numtype(xHi) != 0)
        xLo = fullLo
        xHi = fullHi
        LJZ_MDCWB_WorkSetROI(xLo, xHi)
    endif

    Variable lo, hi
    if (LJZ_MDCWB_GetROIIndexRange(wData, xLo, xHi, lo, hi) != 0)
        LJZ_MDCWB_SetLastError("Invalid ROI for auto init.")
        return -1
    endif
    if (hi - lo + 1 < 5)
        LJZ_MDCWB_SetLastError("ROI too small for auto init.")
        return -1
    endif

    Make/FREE/N=(hi - lo + 1) roiW = wData[lo + p]
    SetScale/P x, axisX0 + lo * axisDX, axisDX, roiW
    WaveStats/Q/M=1 roiW

    if (numtype(V_max) != 0 || numtype(V_min) != 0 || numtype(V_maxLoc) != 0)
        LJZ_MDCWB_SetLastError("Auto init failed: non-finite ROI statistics.")
        return -1
    endif

    Variable bg = LJZ_MDCWB_EstimateBaselineInROI(wData, xLo, xHi)
    Variable amp = V_max - bg
    if (numtype(amp) != 0 || amp <= 0)
        amp = max(1e-6, V_max - V_min)
    endif

    Variable dx = abs(axisDX)
    Variable width0 = max(3 * dx, abs(xHi - xLo) / 20)

    NVAR/Z defType = $(LJZ_MDCWB_BaseDF() + ":DefaultPeakType")
    Variable t = LJZ_MDCWB_PeakTypePV()
    if (NVAR_Exists(defType) && LJZ_MDCWB_IsValidPeakType(defType))
        t = defType
    endif

    // Clear existing peaks (but keep ROI / resH).
    Variable npExisting = LJZ_MDCWB_WorkNumPeaks()
    Variable kp
    for (kp = npExisting - 1; kp >= 0; kp -= 1)
        LJZ_MDCWB_WorkDeletePeak(kp)
    endfor

    LJZ_MDCWB_WorkSetBGOrder(2)
    LJZ_MDCWB_WorkSetBGCoef(0, bg)
    LJZ_MDCWB_WorkSetBGCoef(1, 0)
    LJZ_MDCWB_WorkSetBGCoef(2, 0)
    LJZ_MDCWB_WorkSetBGHold(2, 1)

    // Do NOT clobber user-set resH unless it is missing/invalid.
    Variable curRH = LJZ_MDCWB_WorkGetResH()
    if (numtype(curRH) != 0 || curRH <= 0)
        LJZ_MDCWB_WorkSetResH(LJZ_MDCWB_MinResH())
        LJZ_MDCWB_WorkSetResHHold(1)
    endif

    LJZ_MDCWB_AddPeak(t, V_maxLoc, width0, amp)
    LJZ_MDCWB_MarkDirty(1)
    LJZ_MDCWB_ClearLastError()
    return 0
End

// AutoDetect: replace peaks with multiple peaks found via local-max search
// over a smoothed ROI. Like AutoInit, does not write edit-state to disk.
Function LJZ_MDCWB_AutoDetectPeaks(wData, detectMax)
    Wave wData
    Variable detectMax

    LJZ_MDCWB_EnsureBaseDF()

    if (detectMax <= 0)
        detectMax = 4
    endif
    if (detectMax > LJZ_MDCWB_MaxPeaks())
        detectMax = LJZ_MDCWB_MaxPeaks()
    endif

    Variable nPts = numpnts(wData)
    if (nPts < 9)
        LJZ_MDCWB_SetLastError("Wave too short for auto detection.")
        return -1
    endif

    Variable axisX0 = DimOffset(wData, 0)
    Variable axisDX = DimDelta(wData, 0)
    if (numtype(axisDX) != 0 || axisDX == 0)
        axisDX = 1
    endif

    // Use existing ROI; fill if missing.
    Variable xLo, xHi
    LJZ_MDCWB_WorkGetROI(xLo, xHi)
    if (numtype(xLo) != 0 || numtype(xHi) != 0)
        xLo = axisX0
        xHi = axisX0 + axisDX * (nPts - 1)
        LJZ_MDCWB_WorkSetROI(xLo, xHi)
    endif

    Variable lo, hi
    if (LJZ_MDCWB_GetROIIndexRange(wData, xLo, xHi, lo, hi) != 0)
        LJZ_MDCWB_SetLastError("Invalid ROI for auto detect.")
        return -1
    endif

    Variable n = hi - lo + 1
    if (n < 9)
        LJZ_MDCWB_SetLastError("ROI too small for auto detect.")
        return -1
    endif

    Variable bg = LJZ_MDCWB_EstimateBaselineInROI(wData, xLo, xHi)
    Make/FREE/N=(n) seg = wData[lo + p] - bg
    Smooth/E=2 5, seg

    WaveStats/Q seg
    Variable noise = max(1e-12, V_sdev * 0.5)
    Variable thresh = max(noise * 3, V_max * 0.05)
    if (numtype(thresh) != 0)
        thresh = 0
    endif

    Variable dx = abs(axisDX)
    Variable x0Axis = axisX0 + lo * dx

    NVAR/Z defType = $(LJZ_MDCWB_BaseDF() + ":DefaultPeakType")
    Variable t = LJZ_MDCWB_PeakTypePV()
    if (NVAR_Exists(defType) && LJZ_MDCWB_IsValidPeakType(defType))
        t = defType
    endif

    // Clear existing peaks; keep ROI / resH.
    Variable npExisting = LJZ_MDCWB_WorkNumPeaks()
    Variable kp
    for (kp = npExisting - 1; kp >= 0; kp -= 1)
        LJZ_MDCWB_WorkDeletePeak(kp)
    endfor

    Variable nFound = 0
    Variable i, v0, v1, v2
    for (i = 1; i < n - 1; i += 1)
        if (nFound >= detectMax)
            break
        endif
        v0 = seg[i - 1]
        v1 = seg[i]
        v2 = seg[i + 1]
        if (numtype(v0) != 0 || numtype(v1) != 0 || numtype(v2) != 0)
            continue
        endif
        if (v1 <= thresh)
            continue
        endif
        if (v1 < v0 || v1 < v2)
            continue
        endif

        // FWHM at half-prominence (estimate).
        Variable half = v1 / 2
        Variable jL = i
        do
            jL -= 1
            if (jL < 0)
                break
            endif
            if (seg[jL] < half)
                break
            endif
        while (1)
        Variable jR = i
        do
            jR += 1
            if (jR >= n)
                break
            endif
            if (seg[jR] < half)
                break
            endif
        while (1)

        Variable wid = max(2 * dx, (jR - jL) * dx * 0.5)
        Variable cx = x0Axis + i * dx
        Variable amp = v1
        if (numtype(amp) != 0 || amp <= 0)
            amp = 1
        endif

        LJZ_MDCWB_AddPeak(t, cx, wid, amp)
        nFound += 1
    endfor

    if (nFound == 0)
        // Fallback: single peak at ROI center.
        LJZ_MDCWB_AddPeak(t, x0Axis + (n / 2) * dx, max(3 * dx, abs(xHi - xLo) / 20), 1)
    endif

    LJZ_MDCWB_WorkSetBGOrder(2)
    LJZ_MDCWB_WorkSetBGCoef(0, bg)
    LJZ_MDCWB_WorkSetBGCoef(1, 0)
    LJZ_MDCWB_WorkSetBGCoef(2, 0)
    LJZ_MDCWB_WorkSetBGHold(2, 1)

    Variable curRH = LJZ_MDCWB_WorkGetResH()
    if (numtype(curRH) != 0 || curRH <= 0)
        LJZ_MDCWB_WorkSetResH(LJZ_MDCWB_MinResH())
        LJZ_MDCWB_WorkSetResHHold(1)
    endif

    LJZ_MDCWB_MarkDirty(1)
    LJZ_MDCWB_ClearLastError()
    return 0
End

// LoadCurrentToWork: pull saved edit-state into Work_*. If sanitation
// changed anything, the result is dirty. Returns 1 on edit-state load,
// 0 if it fell back to AutoInit, -1 on hard failure.
Function LJZ_MDCWB_LoadCurrentToWork(wData)
    Wave wData

    LJZ_MDCWB_EnsureBaseDF()

    if (LJZ_MDCWB_HasEditState(wData))
        if (LJZ_MDCWB_LoadEditStateToWork(wData))
            Variable changed = LJZ_MDCWB_SanitizeWorkState()
            if (changed)
                LJZ_MDCWB_MarkDirty(1)
            else
                // Edit-state survived sanitation unchanged → really clean.
                // Note: fit-products may still be missing/stale; we only
                // flip to "fully clean" when both edit-state and fit-products
                // are consistent. Part 3 inspects HasFitRecord / ReadFitOK
                // for that.
                if (LJZ_MDCWB_HasFitRecord(wData) && LJZ_MDCWB_ReadFitOK(wData))
                    LJZ_MDCWB_MarkDirty(0)
                else
                    LJZ_MDCWB_MarkDirty(1)
                endif
            endif
            LJZ_MDCWB_ClearLastError()
            return 1
        endif
    endif

    Variable rc = LJZ_MDCWB_AutoInitFromData(wData)
    if (rc != 0)
        LJZ_MDCWB_ResetWorkState()
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif

    LJZ_MDCWB_MarkDirty(1)
    return 0
End


// ============================================================================
//  Section 8. Per-peak component evaluation (used by Part 3 if it wants to
//  draw individual peaks). Independent of FuncFit, no Active_* needed.
// ============================================================================

Function LJZ_MDCWB_EvaluatePeakComponent(wData, idx, outComponent)
    Wave wData, outComponent
    Variable idx

    LJZ_MDCWB_EnsureBaseDF()

    Variable np = LJZ_MDCWB_WorkNumPeaks()
    if (idx < 0 || idx >= np)
        return -1
    endif

    Wave wPN = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
    Wave wRH = $(LJZ_MDCWB_BaseDF() + ":Work_resH")

    if (numpnts(outComponent) != numpnts(wData))
        Redimension/N=(numpnts(wData)) outComponent
    endif
    SetScale/P x, DimOffset(wData, 0), DimDelta(wData, 0), outComponent

    Variable t = round(wPN[idx][0])
    Variable x0 = wPN[idx][1]
    Variable w  = wPN[idx][2]
    Variable wR = wPN[idx][3]
    Variable H  = wPN[idx][4]
    Variable eta = wPN[idx][5]
    Variable resH = wRH[0]

    if (t == LJZ_MDCWB_PeakTypeAsymPV())
        outComponent = LJZ_MDCWB_AsymPVKernel(H, x, x0, w, wR, eta, resH)
    else
        Variable etaUse = eta
        if (t == LJZ_MDCWB_PeakTypeLor())
            etaUse = 1
        elseif (t == LJZ_MDCWB_PeakTypeGau())
            etaUse = 0
        endif
        outComponent = LJZ_MDCWB_PVKernel(H, x, x0, w, etaUse, resH)
    endif

    return 0
End


// ============================================================================
//  Section 9. Guess generation
//
//  Critical: BuildGuess writes a CACHED guess wave on disk (<wname>_guess)
//  but DOES NOT write the edit-state. The cached guess is a derived artifact;
//  the edit-state is the user's intent and is written only by
//  SaveWorkToDisk() or RunFit() success.
// ============================================================================

Function LJZ_MDCWB_BuildGuess(wData)
    Wave wData

    LJZ_MDCWB_EnsureFitEngineState()
    LJZ_MDCWB_SanitizeWorkState()

    if (LJZ_MDCWB_WorkNumPeaks() <= 0)
        // No peaks => no guess. Wipe any stale cache.
        LJZ_MDCWB_DeleteGuessWave(wData)
        LJZ_MDCWB_SetLastError("No peak in current Work state.")
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif

    Make/FREE/N=1 flatCoef, flatHold, slotMap
    String holdMask = ""
    LJZ_MDCWB_AssembleFitParams(flatCoef, flatHold, slotMap, holdMask)
    LJZ_MDCWB_CopyActiveLayoutFromWork(slotMap)

    Duplicate/FREE wData, guessW
    LJZ_MDCWB_EvaluateModelWave(wData, flatCoef, guessW)

    if (LJZ_MDCWB_SaveGuessWave(wData, guessW) != 0)
        LJZ_MDCWB_SetLastError("Guess save failed.")
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif

    // INTENTIONAL: do NOT call SaveEditStateFromWork here. See contract A.
    LJZ_MDCWB_ClearLastError()
    return 0
End


// ============================================================================
//  Section 10. RunFit
// ============================================================================

Function LJZ_MDCWB_ValidateFlatCoef(flatCoef)
    Wave flatCoef
    Variable i
    for (i = 0; i < numpnts(flatCoef); i += 1)
        if (numtype(flatCoef[i]) != 0)
            return 0
        endif
    endfor
    return 1
End

// Required ROI finite-point count: at least max(2*P, P+10) where P is the
// total flat coef count. This rules out the previous "13 points fits 12
// parameters" foot-gun.
Function LJZ_MDCWB_MinFiniteForFit(paramCount)
    Variable paramCount
    return max(2 * paramCount, paramCount + 10)
End

Function LJZ_MDCWB_RunFit(wData)
    Wave wData

    LJZ_MDCWB_EnsureFitEngineState()
    LJZ_MDCWB_SanitizeWorkState()

    if (LJZ_MDCWB_WorkNumPeaks() <= 0)
        LJZ_MDCWB_SetLastError("No peak to fit.")
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif

    Variable xLo, xHi
    LJZ_MDCWB_WorkGetROI(xLo, xHi)

    Variable roiLo, roiHi
    if (LJZ_MDCWB_GetROIIndexRange(wData, xLo, xHi, roiLo, roiHi) != 0)
        LJZ_MDCWB_SetLastError("Invalid ROI.")
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif
    Variable roiPointCount = roiHi - roiLo + 1
    if (roiPointCount <= 0)
        LJZ_MDCWB_SetLastError("Invalid ROI.")
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif

    Make/FREE/N=1 flatCoef, flatHold, slotMap
    String holdMask = ""
    LJZ_MDCWB_AssembleFitParams(flatCoef, flatHold, slotMap, holdMask)
    LJZ_MDCWB_CopyActiveLayoutFromWork(slotMap)

    if (LJZ_MDCWB_HasFreeAsymPVWidthWithFreeResH())
        Wave wPN_dbg = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
        Wave wPH_dbg = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_hold")
        Wave wRH_dbg = $(LJZ_MDCWB_BaseDF() + ":Work_resH")
        String warnMsg = "Warning: resH is free while AsymPV wL/wR are also free. This fit is underconstrained because resH broadens both sides and can trade off against wL/wR. Hold resH unless you intentionally want this."
        LJZ_MDCWB_SetLastError(warnMsg)
        Print warnMsg
        Print "resH value=", wRH_dbg[0], " hold=", wRH_dbg[1]
        Variable npDbg = DimSize(wPN_dbg, 0)
        Variable ipDbg
        for (ipDbg = 0; ipDbg < npDbg; ipDbg += 1)
            if (round(wPN_dbg[ipDbg][0]) == LJZ_MDCWB_PeakTypeAsymPV())
                Print "AsymPV ip=", ipDbg, " wL=", wPN_dbg[ipDbg][2], " wR=", wPN_dbg[ipDbg][3], " hold_w=", wPH_dbg[ipDbg][1], " hold_wR=", wPH_dbg[ipDbg][2]
            endif
        endfor
    endif

    Variable paramCount = numpnts(flatCoef)
    Variable required   = LJZ_MDCWB_MinFiniteForFit(paramCount)
    Variable finiteCount = LJZ_MDCWB_CountFinitePointsInROI(wData, xLo, xHi)
    if (finiteCount < required)
        String msg
        sprintf msg, "ROI has %d finite points; need >= %d for %d parameters.", finiteCount, required, paramCount
        LJZ_MDCWB_SetLastError(msg)
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif

    // Write the guess cache BEFORE the fit so preview and fit record use the
    // same model evaluation.
    Duplicate/FREE wData, guessFull
    LJZ_MDCWB_EvaluateModelWave(wData, flatCoef, guessFull)
    if (LJZ_MDCWB_SaveGuessWave(wData, guessFull) != 0)
        LJZ_MDCWB_SetLastError("Guess save failed.")
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif

    Make/FREE/N=(roiPointCount) roiData = wData[roiLo + p]
    SetScale/P x, DimOffset(wData, 0) + roiLo * DimDelta(wData, 0), DimDelta(wData, 0), roiData

    Variable fitCaughtError = 0
    Variable runtimeErrorCode = 0
    Variable fitFailed = 0
    Variable fitQuitReasonLocal = NaN
    Variable fitNumItersLocal = NaN
    String oldDF = GetDataFolder(1)

    KillWaves/Z W_sigma

    try
        FuncFit/H=holdMask LJZ_MDCWB_MultiPeakModel, flatCoef, roiData
        AbortOnRTE
    catch
        fitCaughtError = 1
    endtry

    SetDataFolder $oldDF
    runtimeErrorCode = GetRTError(1)

    if (fitCaughtError || runtimeErrorCode != 0)
        fitFailed = 1
        LJZ_MDCWB_SetLastError("FuncFit runtime failure.")
    else
        NVAR/Z fitErrorRef = V_FitError
        NVAR/Z fitQuitReasonRef = V_FitQuitReason
        NVAR/Z fitNumItersRef = V_FitNumIters

        if (NVAR_Exists(fitErrorRef) && numtype(fitErrorRef) == 0 && fitErrorRef != 0)
            fitFailed = 1
            LJZ_MDCWB_SetLastError("FuncFit reported a fit error.")
        endif
        if (NVAR_Exists(fitQuitReasonRef) && numtype(fitQuitReasonRef) == 0)
            fitQuitReasonLocal = fitQuitReasonRef
        endif
        if (NVAR_Exists(fitNumItersRef) && numtype(fitNumItersRef) == 0)
            fitNumItersLocal = fitNumItersRef
        endif
    endif

    if (!LJZ_MDCWB_ValidateFlatCoef(flatCoef))
        fitFailed = 1
        LJZ_MDCWB_SetLastError("Fit coefficients became non-finite.")
    endif

    if (fitFailed)
        // Old fit-products are intact (we never wrote new ones yet);
        // dirty stays high so user knows preview is stale.
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif

    // Snapshot W_sigma before anything else can overwrite it.
    Wave/Z ws = W_sigma
    Make/FREE/N=(numpnts(flatCoef)) sigmaLocal = NaN
    if (WaveExists(ws) && numpnts(ws) == numpnts(flatCoef))
        sigmaLocal = ws[p]
    endif

    LJZ_MDCWB_DistributeFitResult(flatCoef, sigmaLocal, slotMap)

    Duplicate/FREE wData, fitFull
    Duplicate/FREE wData, resFull
    LJZ_MDCWB_EvaluateModelWave(wData, flatCoef, fitFull)
    resFull = wData[p] - fitFull[p]

    Variable guessRMSE, fitRMSE, rssROI, maxAbsRes, nROI
    if (LJZ_MDCWB_ComputeFitMetrics(wData, guessFull, fitFull, resFull, xLo, xHi, guessRMSE, fitRMSE, rssROI, maxAbsRes, nROI) != 0)
        LJZ_MDCWB_SetLastError("Metric computation failed.")
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif

    Make/FREE/N=(LJZ_MDCWB_FitInfoSize()) infoW = NaN
    LJZ_MDCWB_BuildInfoWave(infoW, LJZ_MDCWB_WorkGetBGOrder(), xLo, xHi, 1, guessRMSE, fitRMSE, rssROI, maxAbsRes, nROI, fitQuitReasonLocal, fitNumItersLocal)

    if (LJZ_MDCWB_SaveFitRecord(wData, flatCoef, sigmaLocal, infoW, fitFull, resFull) != 0)
        LJZ_MDCWB_SetLastError("Fit record save failed.")
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif

    // Persist the post-fit edit-state. This is one of two allowed write paths.
    if (LJZ_MDCWB_SaveEditStateFromWork(wData) != 0)
        LJZ_MDCWB_SetLastError("Fit succeeded but edit-state save failed.")
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif

    LJZ_MDCWB_MarkDirty(0)
    LJZ_MDCWB_ClearLastError()
    return 0
End


// ============================================================================
//  Section 11. Self-test
//
//  Runs after Part 1 and Part 2 are compiled:
//      LJZ_MDCWB_Part2_SelfTest()
//
//  Asserts:
//    - Assemble produces a slot map with totalSlots = 4 + sum of per-peak sizes
//    - Lor/Gau eta is forced to 1/0 in flatCoef AND in flatHold
//    - BuildGuess writes <wname>_guess but NOT <wname>_peaks_num (no edit save)
//    - RunFit converges and HasFitRecord returns true on synthetic data
//    - Tightened finite-point check rejects an ROI with too few points
// ============================================================================

Function LJZ_MDCWB_Part2_SelfTest()
    NewDataFolder/O root:TEST_MDCWB_PART2
    String oldDF = GetDataFolder(1)
    SetDataFolder root:TEST_MDCWB_PART2

    Variable nPass = 0
    Variable nFail = 0
    String name

    // Synthetic 2-peak MDC: PV + Lor.
    Make/O/N=301 mdc_show_0
    SetScale/P x, -0.3, 0.002, mdc_show_0
    mdc_show_0 = 0.05 + LJZ_MDCWB_PVKernel(1.2, x, -0.05, 0.018, 0.7, 1e-4) + LJZ_MDCWB_PVKernel(0.65, x, 0.08, 0.022, 1, 1e-4) + 0.005 * gnoise(1)
    Wave w = mdc_show_0

    LJZ_MDCWB_EnsureBaseDF()
    LJZ_MDCWB_ResetWorkState()
    LJZ_MDCWB_WorkSetROI(-0.2, 0.2)
    LJZ_MDCWB_WorkSetBGOrder(0)
    LJZ_MDCWB_WorkSetBGCoef(0, 0.05)
    LJZ_MDCWB_WorkSetBGHold(0, 0)
    LJZ_MDCWB_WorkSetResH(1e-4)
    LJZ_MDCWB_WorkSetResHHold(1)
    LJZ_MDCWB_AddPeak(LJZ_MDCWB_PeakTypePV(),  -0.045, 0.020, 1.0)
    LJZ_MDCWB_AddPeak(LJZ_MDCWB_PeakTypeLor(),  0.075, 0.020, 0.5)

    Make/FREE/N=1 fc, fh, sm
    String hm = ""
    LJZ_MDCWB_AssembleFitParams(fc, fh, sm, hm)

    name = "AssembleFitParams_length"
    if (numpnts(fc) == 12 && numpnts(sm) == 3 && sm[0] == 4 && sm[1] == 8 && sm[2] == 12)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    name = "Assemble_LorEta_forced"
    // PV peak at slot 4: eta slot is 7. Lor peak at slot 8: eta slot is 11.
    if (fc[11] == 1 && fh[11] == 1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL", fc[11], fh[11]
        nFail += 1
    endif

    name = "Assemble_holdMask_string"
    if (strlen(hm) == 12)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL", hm
        nFail += 1
    endif

    name = "BuildGuess_doesNotWriteEditState"
    // Make sure no _peaks_num exists yet for this wave.
    KillWaves/Z $(LJZ_MDCWB_PathPeaksNum(w))
    Variable rcGuess = LJZ_MDCWB_BuildGuess(w)
    Wave/Z afterPN = $(LJZ_MDCWB_PathPeaksNum(w))
    if (rcGuess == 0 && !WaveExists(afterPN))
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL: rc=", rcGuess, "peaks_num exists=", WaveExists(afterPN)
        nFail += 1
    endif

    name = "RunFit_basic"
    if (LJZ_MDCWB_RunFit(w) == 0 && LJZ_MDCWB_HasFitRecord(w))
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL", LJZ_MDCWB_GetLastError()
        nFail += 1
    endif

    name = "RunFit_rejectsTinyROI"
    LJZ_MDCWB_WorkSetROI(-0.001, 0.001)   // ~ a couple of points
    Variable rcTiny = LJZ_MDCWB_RunFit(w)
    LJZ_MDCWB_WorkSetROI(-0.2, 0.2)        // restore for cleanliness
    if (rcTiny != 0)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL: tiny ROI was accepted"
        nFail += 1
    endif

    name = "SetPeakType_PV_to_Lor_to_PV_clearsEtaHold"
    LJZ_MDCWB_SetPeakType(0, LJZ_MDCWB_PeakTypeLor())
    LJZ_MDCWB_SetPeakType(0, LJZ_MDCWB_PeakTypePV())
    if (LJZ_MDCWB_WorkGetPeakHold(0, LJZ_MDCWB_HoldFieldEta()) == 0)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    Print "----"
    Print "Part 2 self-test summary: ", nPass, "passed,", nFail, "failed"

    SetDataFolder $oldDF
    return nFail
End
