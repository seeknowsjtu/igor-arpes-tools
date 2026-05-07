#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  LJZ_MDCWB Part 1 : Core data model + Persistence
//
//  Contract (DO NOT VIOLATE in any other Part):
//
//    1. A single MDC's edit-state is expressed by 5 disk waves under the
//       same DF as the data wave:
//          <wname>_peaks_num    : Npeak x 7   double matrix
//          <wname>_peaks_hold   : Npeak x 5   double matrix
//          <wname>_bg           : 4-element 1D vector
//          <wname>_resH         : 2-element 1D vector
//          <wname>_roi          : 2-element 1D vector
//
//       Plus an optional schema marker:
//          <wname>_peaksMeta    : 1-element text wave
//                                 [0] = "schema=peaks_v1"
//
//    2. Fit products keep their existing names (compatible):
//          <wname>_fit          (full-length curve)
//          <wname>_res          (full-length residual)
//          <wname>_fitcoef      (flat coef wave, length = totalSlots)
//          <wname>_fitsigma     (same length)
//          <wname>_fitinfo      (12-element fixed schema, see below)
//          <wname>_guess        (full-length cached guess)
//          <wname>_accept       (1-element: 1=accept, 0=unchecked, -1=reject)
//
//    3. Edit-state and fit-products may go stale independently.
//       Part 1 does not enforce consistency between them; that is Part 2's job.
//
//    4. Part 1 contains NO model logic. There is no "modelID" anywhere.
//       Peaks are listed explicitly. The fit engine in Part 2 is the only
//       module that walks the peak table to build a flat coef vector.
//
//    5. Peak type encoding (used in column 0 of _peaks_num):
//          1 = PV
//          2 = Lor       (Part 2 will force eta=1 during fit)
//          3 = Gau       (Part 2 will force eta=0 during fit)
//          4 = AsymPV    (wR column is meaningful; otherwise NaN)
//
//    6. _peaks_num column layout (Npeak x 7):
//          col 0 : type
//          col 1 : x0
//          col 2 : w     (PV/Lor/Gau width, or wL for AsymPV)
//          col 3 : wR    (only for AsymPV; NaN otherwise)
//          col 4 : H
//          col 5 : eta
//          col 6 : group_id (reserved, default 0)
//
//    7. _peaks_hold column layout (Npeak x 5):
//          col 0 : hold_x0
//          col 1 : hold_w
//          col 2 : hold_wR
//          col 3 : hold_H
//          col 4 : hold_eta
//
//    8. _bg layout (4 elements):
//          [0] order  (0/1/2)
//          [1] c0
//          [2] c1
//          [3] c2
//          (BG hold is captured separately as a bitmask in _peaksMeta[0])
//          Update: to keep things simple and self-describing, we store BG
//          hold as 3 extra elements directly; total length becomes 6.
//          See LJZ_MDCWB_BGSize() for the canonical length.
//
//          Final _bg layout (6 elements):
//          [0] order
//          [1] c0
//          [2] c1
//          [3] c2
//          [4] hold0_packed_as_3bit_mask  (bit0=hold c0, bit1=hold c1, bit2=hold c2)
//          [5] reserved (NaN)
//
//    9. _resH layout (2 elements):
//          [0] value
//          [1] hold (0 or 1)
//
//   10. _roi layout (2 elements):
//          [0] xLo
//          [1] xHi
//
//   11. fitinfo[12] schema (unchanged from old code; Part 2 fills it):
//          [0] reserved (legacy modelID slot; will be set to 0 by Part 2)
//          [1] bgOrder
//          [2] xLo
//          [3] xHi
//          [4] fitOK     (1=ok, 0=fail)
//          [5] guessRMSE
//          [6] fitRMSE
//          [7] rssROI    (unweighted residual sum of squares in ROI)
//          [8] maxAbsRes
//          [9] nROI
//          [10] fitQuitReason
//          [11] fitNumIters
//
// ============================================================================


// ============================================================================
//  Section 0. Constants and small helpers
// ============================================================================

// ---- runtime DF (same as before) ----
Function/S LJZ_MDCWB_BaseDF()
    return "root:Packages:ARPES_LJZ:MDCWB"
End

// ---- per-MDC schema sizes ----
Function LJZ_MDCWB_PeaksNumCols()
    return 7
End

Function LJZ_MDCWB_PeaksHoldCols()
    return 5
End

Function LJZ_MDCWB_BGSize()
    return 6
End

Function LJZ_MDCWB_ResHSize()
    return 2
End

Function LJZ_MDCWB_ROISize()
    return 2
End

Function LJZ_MDCWB_FitInfoSize()
    return 12
End

Function LJZ_MDCWB_MaxPeaks()
    return 8
End

// ---- peak type ids ----
Function LJZ_MDCWB_PeakTypePV()
    return 1
End

Function LJZ_MDCWB_PeakTypeLor()
    return 2
End

Function LJZ_MDCWB_PeakTypeGau()
    return 3
End

Function LJZ_MDCWB_PeakTypeAsymPV()
    return 4
End

Function LJZ_MDCWB_IsValidPeakType(t)
    Variable t

    if (t == 1 || t == 2 || t == 3 || t == 4)
        return 1
    endif
    return 0
End

Function/S LJZ_MDCWB_PeakTypeName(t)
    Variable t

    if (t == 1)
        return "PV"
    elseif (t == 2)
        return "Lor"
    elseif (t == 3)
        return "Gau"
    elseif (t == 4)
        return "AsymPV"
    endif
    return "?"
End

// Number of free coef slots used by a peak when packed into the flat coef
// vector for FuncFit. Part 2 uses this; Part 1 exposes it because it is a
// pure function of peak-type and is shared across modules.
Function LJZ_MDCWB_PeakSlotCount(t)
    Variable t

    if (t == 4)
        return 5    // x0, wL, wR, H, eta
    endif
    return 4        // x0, w, H, eta
End

// ---- DF path normalization ----
Function/S LJZ_MDCWB_NormDFPath(df)
    String df

    if (strlen(df) == 0)
        return ""
    endif

    df = RemoveEnding(df, ":") + ":"
    if (!DataFolderExists(df))
        return ""
    endif

    return df
End


// ============================================================================
//  Section 1. Per-wave persistent path helpers
// ============================================================================

Function/S LJZ_MDCWB_PathPeaksNum(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_peaks_num"
End

Function/S LJZ_MDCWB_PathPeaksHold(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_peaks_hold"
End

Function/S LJZ_MDCWB_PathBG(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_bg"
End

Function/S LJZ_MDCWB_PathResH(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_resH"
End

Function/S LJZ_MDCWB_PathROI(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_roi"
End

Function/S LJZ_MDCWB_PathPeaksMeta(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_peaksMeta"
End

Function/S LJZ_MDCWB_PathFit(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_fit"
End

Function/S LJZ_MDCWB_PathRes(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_res"
End

Function/S LJZ_MDCWB_PathFitCoef(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_fitcoef"
End

Function/S LJZ_MDCWB_PathFitSigma(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_fitsigma"
End

Function/S LJZ_MDCWB_PathFitInfo(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_fitinfo"
End

Function/S LJZ_MDCWB_PathGuess(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_guess"
End

Function/S LJZ_MDCWB_PathAccept(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_accept"
End


// ============================================================================
//  Section 2. Runtime DF + Work-state initialization
// ============================================================================

Function LJZ_MDCWB_EnsureBaseDF()
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:ARPES_LJZ
    NewDataFolder/O $(LJZ_MDCWB_BaseDF())

    LJZ_MDCWB_EnsureRuntimeState()

    return 0
End

// Working copy of the current MDC's edit-state, plus a few session globals.
// Naming convention: Work_*  for editable mirror, Active_*  for fit-time snapshot.
Function LJZ_MDCWB_EnsureRuntimeState()
    String base = LJZ_MDCWB_BaseDF()

    // ---- selection / target ----
    SVAR/Z sTarget = $(base + ":TargetDF")
    if (!SVAR_Exists(sTarget))
        String/G $(base + ":TargetDF") = ""
    endif

    NVAR/Z curRow = $(base + ":CurRow")
    if (!NVAR_Exists(curRow))
        Variable/G $(base + ":CurRow") = -1
    endif

    SVAR/Z curWavePath = $(base + ":CurWavePath")
    if (!SVAR_Exists(curWavePath))
        String/G $(base + ":CurWavePath") = ""
    endif

    // ---- session ui prefs (kept) ----
    NVAR/Z useCsr = $(base + ":UseCursors")
    if (!NVAR_Exists(useCsr))
        Variable/G $(base + ":UseCursors") = 1
    endif

    NVAR/Z defType = $(base + ":DefaultPeakType")
    if (!NVAR_Exists(defType))
        Variable/G $(base + ":DefaultPeakType") = LJZ_MDCWB_PeakTypePV()
    endif

    NVAR/Z selPeak = $(base + ":Work_selectedPeak")
    if (!NVAR_Exists(selPeak))
        Variable/G $(base + ":Work_selectedPeak") = -1
    endif

    NVAR/Z dirty = $(base + ":Dirty")
    if (!NVAR_Exists(dirty))
        Variable/G $(base + ":Dirty") = 1
    endif

    SVAR/Z lastErr = $(base + ":LastErrorMsg")
    if (!SVAR_Exists(lastErr))
        String/G $(base + ":LastErrorMsg") = ""
    endif

    // ---- working copy ----
    Wave/Z wPN = $(base + ":Work_peaks_num")
    if (!WaveExists(wPN))
        Make/O/N=(0, 7) $(base + ":Work_peaks_num") = NaN
    endif

    Wave/Z wPH = $(base + ":Work_peaks_hold")
    if (!WaveExists(wPH))
        Make/O/N=(0, 5) $(base + ":Work_peaks_hold") = 0
    endif

    Wave/Z wBG = $(base + ":Work_bg")
    if (!WaveExists(wBG))
        Make/O/N=(6) $(base + ":Work_bg") = NaN
        Wave wBGNew = $(base + ":Work_bg")
        wBGNew[0] = 2       // default order = quad
        wBGNew[1] = 0
        wBGNew[2] = 0
        wBGNew[3] = 0
        wBGNew[4] = 0       // hold mask
        wBGNew[5] = NaN
    endif

    Wave/Z wRH = $(base + ":Work_resH")
    if (!WaveExists(wRH))
        Make/O/N=(2) $(base + ":Work_resH") = NaN
        Wave wRHNew = $(base + ":Work_resH")
        wRHNew[0] = 1e-4
        wRHNew[1] = 1       // default: hold resH
    endif

    Wave/Z wROI = $(base + ":Work_roi")
    if (!WaveExists(wROI))
        Make/O/N=(2) $(base + ":Work_roi") = NaN
    endif

    return 0
End


// ============================================================================
//  Section 3. Dirty / error state helpers (unchanged behavior)
// ============================================================================

Function LJZ_MDCWB_MarkDirty(flag)
    Variable flag
    NVAR isDirty = $(LJZ_MDCWB_BaseDF() + ":Dirty")
    isDirty = flag
    return 0
End

Function LJZ_MDCWB_IsDirty()
    NVAR isDirty = $(LJZ_MDCWB_BaseDF() + ":Dirty")
    return isDirty
End

Function LJZ_MDCWB_ClearLastError()
    SVAR lastErr = $(LJZ_MDCWB_BaseDF() + ":LastErrorMsg")
    lastErr = ""
    return 0
End

Function LJZ_MDCWB_SetLastError(msg)
    String msg
    SVAR lastErr = $(LJZ_MDCWB_BaseDF() + ":LastErrorMsg")
    lastErr = msg
    return 0
End

Function/S LJZ_MDCWB_GetLastError()
    SVAR lastErr = $(LJZ_MDCWB_BaseDF() + ":LastErrorMsg")
    return lastErr
End


// ============================================================================
//  Section 4. MDC list discovery (unchanged: mdc_show_<k>)
// ============================================================================

Function/S LJZ_MDCWB_ListMDCWaves(dfPath)
    String dfPath

    dfPath = LJZ_MDCWB_NormDFPath(dfPath)
    if (strlen(dfPath) == 0)
        return ""
    endif

    String out = ""

    // Prefer the canonical mdc_show_0,1,2,... sequence
    Wave/Z w0 = $(dfPath + "mdc_show_0")
    if (WaveExists(w0))
        Variable k = 0
        do
            Wave/Z wk = $(dfPath + "mdc_show_" + Num2Str(k))
            if (!WaveExists(wk))
                break
            endif
            out = AddListItem(dfPath + NameOfWave(wk), out, ";", Inf)
            k += 1
        while (1)
        return out
    endif

    // Fallback: any 1D wave whose name contains "mdc"
    Variable iObj, nObj
    nObj = CountObjects(dfPath, 1)

    for (iObj = 0; iObj < nObj; iObj += 1)
        String nm = GetIndexedObjName(dfPath, 1, iObj)
        Wave/Z w = $(dfPath + nm)
        if (!WaveExists(w))
            continue
        endif

        if (DimSize(w, 1) > 0 || DimSize(w, 2) > 0 || DimSize(w, 3) > 0)
            continue
        endif

        if (StringMatch(LowerStr(nm), "*mdc*"))
            out = AddListItem(dfPath + nm, out, ";", Inf)
        endif
    endfor

    return out
End

Function LJZ_MDCWB_ParseMDCIndex(nm)
    String nm

    if (!StringMatch(nm, "mdc_show_*"))
        return -1
    endif

    String tail = ReplaceString("mdc_show_", nm, "")
    Variable v = str2num(tail)
    if (numtype(v) != 0)
        return -1
    endif
    return v
End


// ============================================================================
//  Section 5. Edit-state read: disk -> Work_*
//
//  This section is intentionally tolerant. Missing / malformed waves do NOT
//  crash; the caller can use LJZ_MDCWB_HasEditState() to detect "no saved
//  edit state on disk" and fall back to auto-init in Part 2.
// ============================================================================

// True iff at least the 5 mandatory edit-state waves exist with sane shapes.
// _peaksMeta is optional and not required.
Function LJZ_MDCWB_HasEditState(wData)
    Wave wData

    Wave/Z wPN  = $(LJZ_MDCWB_PathPeaksNum(wData))
    Wave/Z wPH  = $(LJZ_MDCWB_PathPeaksHold(wData))
    Wave/Z wBG  = $(LJZ_MDCWB_PathBG(wData))
    Wave/Z wRH  = $(LJZ_MDCWB_PathResH(wData))
    Wave/Z wROI = $(LJZ_MDCWB_PathROI(wData))

    if (!WaveExists(wPN) || !WaveExists(wPH))
        return 0
    endif
    if (!WaveExists(wBG) || !WaveExists(wRH) || !WaveExists(wROI))
        return 0
    endif

    if (DimSize(wPN, 1) != LJZ_MDCWB_PeaksNumCols())
        return 0
    endif
    if (DimSize(wPH, 1) != LJZ_MDCWB_PeaksHoldCols())
        return 0
    endif
    if (DimSize(wPN, 0) != DimSize(wPH, 0))
        return 0
    endif
    if (numpnts(wBG) != LJZ_MDCWB_BGSize())
        return 0
    endif
    if (numpnts(wRH) != LJZ_MDCWB_ResHSize())
        return 0
    endif
    if (numpnts(wROI) != LJZ_MDCWB_ROISize())
        return 0
    endif

    return 1
End

// Copy disk edit-state into Work_*. Returns 1 on success, 0 on missing/invalid.
Function LJZ_MDCWB_LoadEditStateToWork(wData)
    Wave wData

    LJZ_MDCWB_EnsureBaseDF()

    if (!LJZ_MDCWB_HasEditState(wData))
        return 0
    endif

    Wave src_pn  = $(LJZ_MDCWB_PathPeaksNum(wData))
    Wave src_ph  = $(LJZ_MDCWB_PathPeaksHold(wData))
    Wave src_bg  = $(LJZ_MDCWB_PathBG(wData))
    Wave src_rh  = $(LJZ_MDCWB_PathResH(wData))
    Wave src_roi = $(LJZ_MDCWB_PathROI(wData))

    String base = LJZ_MDCWB_BaseDF()

    Variable nPeak = DimSize(src_pn, 0)
    Variable maxPk = LJZ_MDCWB_MaxPeaks()
    if (nPeak > maxPk)
        nPeak = maxPk
    endif

    Wave dst_pn = $(base + ":Work_peaks_num")
    Wave dst_ph = $(base + ":Work_peaks_hold")

    Redimension/N=(nPeak, LJZ_MDCWB_PeaksNumCols())  dst_pn
    Redimension/N=(nPeak, LJZ_MDCWB_PeaksHoldCols()) dst_ph

    Variable ip, ic
    for (ip = 0; ip < nPeak; ip += 1)
        for (ic = 0; ic < LJZ_MDCWB_PeaksNumCols(); ic += 1)
            dst_pn[ip][ic] = src_pn[ip][ic]
        endfor
        for (ic = 0; ic < LJZ_MDCWB_PeaksHoldCols(); ic += 1)
            dst_ph[ip][ic] = src_ph[ip][ic]
        endfor
    endfor

    Wave dst_bg = $(base + ":Work_bg")
    dst_bg = src_bg[p]

    Wave dst_rh = $(base + ":Work_resH")
    dst_rh = src_rh[p]

    Wave dst_roi = $(base + ":Work_roi")
    dst_roi = src_roi[p]

    return 1
End

// Reset Work_* to "empty edit state" without touching disk. Used when the user
// switches away from a wave that has no saved edit state and Part 2 will then
// drive auto-init.
Function LJZ_MDCWB_ResetWorkState()
    LJZ_MDCWB_EnsureBaseDF()

    String base = LJZ_MDCWB_BaseDF()

    Wave wPN = $(base + ":Work_peaks_num")
    Redimension/N=(0, LJZ_MDCWB_PeaksNumCols()) wPN

    Wave wPH = $(base + ":Work_peaks_hold")
    Redimension/N=(0, LJZ_MDCWB_PeaksHoldCols()) wPH

    Wave wBG = $(base + ":Work_bg")
    wBG = NaN
    wBG[0] = 2
    wBG[1] = 0
    wBG[2] = 0
    wBG[3] = 0
    wBG[4] = 0
    wBG[5] = NaN

    Wave wRH = $(base + ":Work_resH")
    wRH[0] = 1e-4
    wRH[1] = 1

    Wave wROI = $(base + ":Work_roi")
    wROI = NaN

    NVAR selPeak = $(base + ":Work_selectedPeak")
    selPeak = -1

    return 0
End


// ============================================================================
//  Section 6. Edit-state write: Work_* -> disk (atomic per-wave)
//
//  Writes are best-effort atomic per individual wave (Duplicate/O is a single
//  Igor operation). We don't try cross-wave atomicity here: the 5 waves
//  describe a single edit state, but the failure modes are dominated by
//  out-of-memory or DF permission issues that are unlikely in practice.
// ============================================================================

Function LJZ_MDCWB_SaveEditStateFromWork(wData)
    Wave wData

    LJZ_MDCWB_EnsureBaseDF()

    String base = LJZ_MDCWB_BaseDF()
    String dfW  = GetWavesDataFolder(wData, 1)
    String nm   = NameOfWave(wData)
    String dfWNoColon = RemoveEnding(dfW, ":")

    Wave src_pn  = $(base + ":Work_peaks_num")
    Wave src_ph  = $(base + ":Work_peaks_hold")
    Wave src_bg  = $(base + ":Work_bg")
    Wave src_rh  = $(base + ":Work_resH")
    Wave src_roi = $(base + ":Work_roi")

    String oldDF = GetDataFolder(1)
    Variable hadError = 0

    try
        SetDataFolder $dfWNoColon

        Duplicate/O src_pn,  $(nm + "_peaks_num")
        Duplicate/O src_ph,  $(nm + "_peaks_hold")
        Duplicate/O src_bg,  $(nm + "_bg")
        Duplicate/O src_rh,  $(nm + "_resH")
        Duplicate/O src_roi, $(nm + "_roi")

        Make/O/T/N=1 $(nm + "_peaksMeta")
        Wave/T meta = $(nm + "_peaksMeta")
        meta[0] = "schema=peaks_v1;saved=" + Secs2Date(DateTime, -2) + " " + Secs2Time(DateTime, 3)
    catch
        hadError = 1
    endtry

    SetDataFolder $oldDF
    if (hadError || GetRTError(1) != 0)
        return -1
    endif

    return 0
End

Function LJZ_MDCWB_DeleteEditState(wData)
    Wave wData

    KillWaves/Z $(LJZ_MDCWB_PathPeaksNum(wData))
    KillWaves/Z $(LJZ_MDCWB_PathPeaksHold(wData))
    KillWaves/Z $(LJZ_MDCWB_PathBG(wData))
    KillWaves/Z $(LJZ_MDCWB_PathResH(wData))
    KillWaves/Z $(LJZ_MDCWB_PathROI(wData))
    KillWaves/Z $(LJZ_MDCWB_PathPeaksMeta(wData))

    return 0
End


// ============================================================================
//  Section 7. Work-state convenience accessors
//
//  These are used heavily by Part 2 (fit engine) and Part 3 (panel callbacks).
//  Keep them dumb: read/write only, no policy, no dirty marking.
// ============================================================================

Function LJZ_MDCWB_WorkNumPeaks()
    LJZ_MDCWB_EnsureBaseDF()
    Wave wPN = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
    return DimSize(wPN, 0)
End

// Resize work peak tables to exactly `n` rows. New rows are filled with NaN
// (peaks_num) and 0 (peaks_hold). Truncates if shrinking.
Function LJZ_MDCWB_WorkResizePeaks(n)
    Variable n

    LJZ_MDCWB_EnsureBaseDF()

    if (n < 0)
        n = 0
    endif

    Variable maxPk = LJZ_MDCWB_MaxPeaks()
    if (n > maxPk)
        n = maxPk
    endif

    Wave wPN = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
    Wave wPH = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_hold")

    Variable oldN = DimSize(wPN, 0)

    Redimension/N=(n, LJZ_MDCWB_PeaksNumCols())  wPN
    Redimension/N=(n, LJZ_MDCWB_PeaksHoldCols()) wPH

    Variable ip, ic
    for (ip = oldN; ip < n; ip += 1)
        for (ic = 0; ic < LJZ_MDCWB_PeaksNumCols(); ic += 1)
            wPN[ip][ic] = NaN
        endfor
        for (ic = 0; ic < LJZ_MDCWB_PeaksHoldCols(); ic += 1)
            wPH[ip][ic] = 0
        endfor
    endfor

    return 0
End

Function LJZ_MDCWB_WorkAppendPeak(t, x0, w, H)
    Variable t, x0, w, H

    LJZ_MDCWB_EnsureBaseDF()

    if (!LJZ_MDCWB_IsValidPeakType(t))
        return -1
    endif

    Variable n = LJZ_MDCWB_WorkNumPeaks()
    if (n >= LJZ_MDCWB_MaxPeaks())
        return -1
    endif

    LJZ_MDCWB_WorkResizePeaks(n + 1)

    Wave wPN = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
    Wave wPH = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_hold")

    wPN[n][0] = t
    wPN[n][1] = x0
    wPN[n][2] = w
    if (t == LJZ_MDCWB_PeakTypeAsymPV())
        wPN[n][3] = w        // initialize wR equal to wL
    else
        wPN[n][3] = NaN
    endif
    wPN[n][4] = H
    if (t == LJZ_MDCWB_PeakTypeLor())
        wPN[n][5] = 1
    elseif (t == LJZ_MDCWB_PeakTypeGau())
        wPN[n][5] = 0
    else
        wPN[n][5] = 0.7
    endif
    wPN[n][6] = 0     // group_id

    Variable ic
    for (ic = 0; ic < LJZ_MDCWB_PeaksHoldCols(); ic += 1)
        wPH[n][ic] = 0
    endfor

    return n
End

Function LJZ_MDCWB_WorkDeletePeak(idx)
    Variable idx

    LJZ_MDCWB_EnsureBaseDF()

    Variable n = LJZ_MDCWB_WorkNumPeaks()
    if (idx < 0 || idx >= n)
        return -1
    endif

    Wave wPN = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
    Wave wPH = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_hold")

    Variable ip, ic
    for (ip = idx; ip < n - 1; ip += 1)
        for (ic = 0; ic < LJZ_MDCWB_PeaksNumCols(); ic += 1)
            wPN[ip][ic] = wPN[ip + 1][ic]
        endfor
        for (ic = 0; ic < LJZ_MDCWB_PeaksHoldCols(); ic += 1)
            wPH[ip][ic] = wPH[ip + 1][ic]
        endfor
    endfor

    LJZ_MDCWB_WorkResizePeaks(n - 1)

    NVAR selPeak = $(LJZ_MDCWB_BaseDF() + ":Work_selectedPeak")
    if (selPeak == idx)
        selPeak = -1
    elseif (selPeak > idx)
        selPeak -= 1
    endif

    return 0
End

// Field id constants for SetPeakField. Using small integers makes call sites
// shorter than passing column names as strings. Part 3 will translate UI
// control names to these ids.
Function LJZ_MDCWB_FieldType()
    return 0
End
Function LJZ_MDCWB_FieldX0()
    return 1
End
Function LJZ_MDCWB_FieldW()
    return 2
End
Function LJZ_MDCWB_FieldWR()
    return 3
End
Function LJZ_MDCWB_FieldH()
    return 4
End
Function LJZ_MDCWB_FieldEta()
    return 5
End

Function LJZ_MDCWB_HoldFieldX0()
    return 0
End
Function LJZ_MDCWB_HoldFieldW()
    return 1
End
Function LJZ_MDCWB_HoldFieldWR()
    return 2
End
Function LJZ_MDCWB_HoldFieldH()
    return 3
End
Function LJZ_MDCWB_HoldFieldEta()
    return 4
End

Function LJZ_MDCWB_WorkSetPeakField(idx, fieldId, val)
    Variable idx, fieldId, val

    LJZ_MDCWB_EnsureBaseDF()

    Variable n = LJZ_MDCWB_WorkNumPeaks()
    if (idx < 0 || idx >= n)
        return -1
    endif
    if (fieldId < 0 || fieldId > 5)
        return -1
    endif

    Wave wPN = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
    wPN[idx][fieldId] = val

    return 0
End

Function LJZ_MDCWB_WorkGetPeakField(idx, fieldId)
    Variable idx, fieldId

    LJZ_MDCWB_EnsureBaseDF()

    Variable n = LJZ_MDCWB_WorkNumPeaks()
    if (idx < 0 || idx >= n)
        return NaN
    endif
    if (fieldId < 0 || fieldId > 5)
        return NaN
    endif

    Wave wPN = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
    return wPN[idx][fieldId]
End

Function LJZ_MDCWB_WorkSetPeakHold(idx, holdFieldId, on)
    Variable idx, holdFieldId, on

    LJZ_MDCWB_EnsureBaseDF()

    Variable n = LJZ_MDCWB_WorkNumPeaks()
    if (idx < 0 || idx >= n)
        return -1
    endif
    if (holdFieldId < 0 || holdFieldId > 4)
        return -1
    endif

    Wave wPH = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_hold")
    wPH[idx][holdFieldId] = (on != 0)

    return 0
End

Function LJZ_MDCWB_WorkGetPeakHold(idx, holdFieldId)
    Variable idx, holdFieldId

    LJZ_MDCWB_EnsureBaseDF()

    Variable n = LJZ_MDCWB_WorkNumPeaks()
    if (idx < 0 || idx >= n)
        return 0
    endif
    if (holdFieldId < 0 || holdFieldId > 4)
        return 0
    endif

    Wave wPH = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_hold")
    return (wPH[idx][holdFieldId] != 0)
End

// BG accessors: indices 0..2 for c0/c1/c2.
Function LJZ_MDCWB_WorkGetBGOrder()
    LJZ_MDCWB_EnsureBaseDF()
    Wave wBG = $(LJZ_MDCWB_BaseDF() + ":Work_bg")
    return wBG[0]
End

Function LJZ_MDCWB_WorkSetBGOrder(order)
    Variable order

    LJZ_MDCWB_EnsureBaseDF()
    if (order < 0)
        order = 0
    endif
    if (order > 2)
        order = 2
    endif

    Wave wBG = $(LJZ_MDCWB_BaseDF() + ":Work_bg")
    wBG[0] = order
    return 0
End

Function LJZ_MDCWB_WorkGetBGCoef(i)
    Variable i

    LJZ_MDCWB_EnsureBaseDF()
    if (i < 0 || i > 2)
        return NaN
    endif
    Wave wBG = $(LJZ_MDCWB_BaseDF() + ":Work_bg")
    return wBG[1 + i]
End

Function LJZ_MDCWB_WorkSetBGCoef(i, val)
    Variable i, val

    LJZ_MDCWB_EnsureBaseDF()
    if (i < 0 || i > 2)
        return -1
    endif
    Wave wBG = $(LJZ_MDCWB_BaseDF() + ":Work_bg")
    wBG[1 + i] = val
    return 0
End

Function LJZ_MDCWB_WorkGetBGHold(i)
    Variable i

    LJZ_MDCWB_EnsureBaseDF()
    if (i < 0 || i > 2)
        return 0
    endif
    Wave wBG = $(LJZ_MDCWB_BaseDF() + ":Work_bg")
    Variable mask = wBG[4]
    if (numtype(mask) != 0)
        return 0
    endif
    Variable bit = 2^i
    return ((mask & bit) != 0)
End

Function LJZ_MDCWB_WorkSetBGHold(i, on)
    Variable i, on

    LJZ_MDCWB_EnsureBaseDF()
    if (i < 0 || i > 2)
        return -1
    endif
    Wave wBG = $(LJZ_MDCWB_BaseDF() + ":Work_bg")
    Variable mask = wBG[4]
    if (numtype(mask) != 0)
        mask = 0
    endif
    Variable bit = 2^i
    if (on)
        mask = mask | bit
    else
        mask = mask & (~bit)
    endif
    wBG[4] = mask
    return 0
End

// resH accessors
Function LJZ_MDCWB_WorkGetResH()
    LJZ_MDCWB_EnsureBaseDF()
    Wave wRH = $(LJZ_MDCWB_BaseDF() + ":Work_resH")
    return wRH[0]
End

Function LJZ_MDCWB_WorkSetResH(val)
    Variable val
    LJZ_MDCWB_EnsureBaseDF()
    Wave wRH = $(LJZ_MDCWB_BaseDF() + ":Work_resH")
    wRH[0] = val
    return 0
End

Function LJZ_MDCWB_WorkGetResHHold()
    LJZ_MDCWB_EnsureBaseDF()
    Wave wRH = $(LJZ_MDCWB_BaseDF() + ":Work_resH")
    return (wRH[1] != 0)
End

Function LJZ_MDCWB_WorkSetResHHold(on)
    Variable on
    LJZ_MDCWB_EnsureBaseDF()
    Wave wRH = $(LJZ_MDCWB_BaseDF() + ":Work_resH")
    wRH[1] = (on != 0)
    return 0
End

// ROI accessors
Function LJZ_MDCWB_WorkGetROI(xLoOut, xHiOut)
    Variable &xLoOut, &xHiOut

    LJZ_MDCWB_EnsureBaseDF()
    Wave wROI = $(LJZ_MDCWB_BaseDF() + ":Work_roi")
    xLoOut = wROI[0]
    xHiOut = wROI[1]
    return 0
End

Function LJZ_MDCWB_WorkSetROI(xLo, xHi)
    Variable xLo, xHi
    LJZ_MDCWB_EnsureBaseDF()
    Wave wROI = $(LJZ_MDCWB_BaseDF() + ":Work_roi")
    wROI[0] = xLo
    wROI[1] = xHi
    return 0
End


// ============================================================================
//  Section 8. Fit-product save / load (atomic per-record)
//
//  This is the part most likely to corrupt downstream analyses if it goes
//  half-applied. We keep the same backup-and-restore approach as the old
//  SaveFitRecord but generalized to a variable-length flat coef vector.
// ============================================================================

// fitinfo schema description (sticks as a Note on the wave for human readers)
Function/S LJZ_MDCWB_FitInfoSchemaNote()
    String s = ""
    s += "fitinfo[0]=reserved_legacy_modelID;"
    s += "fitinfo[1]=bgOrder;"
    s += "fitinfo[2]=xLo;"
    s += "fitinfo[3]=xHi;"
    s += "fitinfo[4]=fitOK;"
    s += "fitinfo[5]=guessRMSE;"
    s += "fitinfo[6]=fitRMSE;"
    s += "fitinfo[7]=rssROI_unweighted_in_ROI;"
    s += "fitinfo[8]=maxAbsRes;"
    s += "fitinfo[9]=nROI;"
    s += "fitinfo[10]=fitQuitReason;"
    s += "fitinfo[11]=fitNumIters"
    return s
End

Function LJZ_MDCWB_InitFitInfoWave(infoW)
    Wave infoW
    if (numpnts(infoW) != LJZ_MDCWB_FitInfoSize())
        Redimension/N=(LJZ_MDCWB_FitInfoSize()) infoW
    endif
    infoW = NaN
    return 0
End

// Save full fit record. coefW / sigmaW are flat vectors of identical length;
// length is determined by Part 2 from the (Active) peak table at fit time.
// fitW / resW must match length(wData).
Function LJZ_MDCWB_SaveFitRecord(wData, coefW, sigmaW, infoW, fitW, resW)
    Wave wData, coefW, infoW, fitW, resW
    Wave/Z sigmaW

    LJZ_MDCWB_EnsureBaseDF()

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    String dfWNoColon = RemoveEnding(dfW, ":")

    String oldDF = GetDataFolder(1)
    Variable hadError = 0
    Variable replaceStarted = 0

    try
        SetDataFolder $dfWNoColon

        KillWaves/Z $(nm + "_fitcoef__tmp"), $(nm + "_fitsigma__tmp"), $(nm + "_fitinfo__tmp")
        KillWaves/Z $(nm + "_fit__tmp"), $(nm + "_res__tmp")
        KillWaves/Z $(nm + "_fitcoef__bak"), $(nm + "_fitsigma__bak"), $(nm + "_fitinfo__bak")
        KillWaves/Z $(nm + "_fit__bak"), $(nm + "_res__bak")

        // ---- temp copies ----
        Duplicate/O coefW, $(nm + "_fitcoef__tmp")

        if (WaveExists(sigmaW))
            Duplicate/O sigmaW, $(nm + "_fitsigma__tmp")
        else
            Duplicate/O coefW, $(nm + "_fitsigma__tmp")
            Wave wsTmp = $(nm + "_fitsigma__tmp")
            wsTmp = NaN
        endif

        Duplicate/O infoW, $(nm + "_fitinfo__tmp")
        Wave wInfoTmp = $(nm + "_fitinfo__tmp")
        if (numpnts(wInfoTmp) != LJZ_MDCWB_FitInfoSize())
            Redimension/N=(LJZ_MDCWB_FitInfoSize()) wInfoTmp
        endif
        Note/K wInfoTmp
        Note wInfoTmp, LJZ_MDCWB_FitInfoSchemaNote()

        Duplicate/O fitW, $(nm + "_fit__tmp")
        Duplicate/O resW, $(nm + "_res__tmp")

        // ---- backup current official record ----
        Wave/Z oldCoef  = $(nm + "_fitcoef")
        Wave/Z oldSigma = $(nm + "_fitsigma")
        Wave/Z oldInfo  = $(nm + "_fitinfo")
        Wave/Z oldFit   = $(nm + "_fit")
        Wave/Z oldRes   = $(nm + "_res")

        if (WaveExists(oldCoef))
            Duplicate/O oldCoef, $(nm + "_fitcoef__bak")
        endif
        if (WaveExists(oldSigma))
            Duplicate/O oldSigma, $(nm + "_fitsigma__bak")
        endif
        if (WaveExists(oldInfo))
            Duplicate/O oldInfo, $(nm + "_fitinfo__bak")
        endif
        if (WaveExists(oldFit))
            Duplicate/O oldFit, $(nm + "_fit__bak")
        endif
        if (WaveExists(oldRes))
            Duplicate/O oldRes, $(nm + "_res__bak")
        endif

        replaceStarted = 1

        Duplicate/O $(nm + "_fitcoef__tmp"),  $(nm + "_fitcoef")
        Duplicate/O $(nm + "_fitsigma__tmp"), $(nm + "_fitsigma")
        Duplicate/O $(nm + "_fitinfo__tmp"),  $(nm + "_fitinfo")
        Duplicate/O $(nm + "_fit__tmp"),      $(nm + "_fit")
        Duplicate/O $(nm + "_res__tmp"),      $(nm + "_res")
    catch
        hadError = 1
    endtry

    if (hadError || GetRTError(1) != 0)
        SetDataFolder $dfWNoColon

        if (replaceStarted)
            Wave/Z bakCoef  = $(nm + "_fitcoef__bak")
            Wave/Z bakSigma = $(nm + "_fitsigma__bak")
            Wave/Z bakInfo  = $(nm + "_fitinfo__bak")
            Wave/Z bakFit   = $(nm + "_fit__bak")
            Wave/Z bakRes   = $(nm + "_res__bak")

            if (WaveExists(bakCoef))
                Duplicate/O bakCoef, $(nm + "_fitcoef")
            else
                KillWaves/Z $(nm + "_fitcoef")
            endif
            if (WaveExists(bakSigma))
                Duplicate/O bakSigma, $(nm + "_fitsigma")
            else
                KillWaves/Z $(nm + "_fitsigma")
            endif
            if (WaveExists(bakInfo))
                Duplicate/O bakInfo, $(nm + "_fitinfo")
            else
                KillWaves/Z $(nm + "_fitinfo")
            endif
            if (WaveExists(bakFit))
                Duplicate/O bakFit, $(nm + "_fit")
            else
                KillWaves/Z $(nm + "_fit")
            endif
            if (WaveExists(bakRes))
                Duplicate/O bakRes, $(nm + "_res")
            else
                KillWaves/Z $(nm + "_res")
            endif
        endif

        KillWaves/Z $(nm + "_fitcoef__tmp"),  $(nm + "_fitsigma__tmp"), $(nm + "_fitinfo__tmp")
        KillWaves/Z $(nm + "_fit__tmp"),      $(nm + "_res__tmp")
        KillWaves/Z $(nm + "_fitcoef__bak"),  $(nm + "_fitsigma__bak"), $(nm + "_fitinfo__bak")
        KillWaves/Z $(nm + "_fit__bak"),      $(nm + "_res__bak")
        SetDataFolder $oldDF
        return -1
    endif

    SetDataFolder $dfWNoColon
    KillWaves/Z $(nm + "_fitcoef__tmp"),  $(nm + "_fitsigma__tmp"), $(nm + "_fitinfo__tmp")
    KillWaves/Z $(nm + "_fit__tmp"),      $(nm + "_res__tmp")
    KillWaves/Z $(nm + "_fitcoef__bak"),  $(nm + "_fitsigma__bak"), $(nm + "_fitinfo__bak")
    KillWaves/Z $(nm + "_fit__bak"),      $(nm + "_res__bak")
    SetDataFolder $oldDF

    return 0
End

Function LJZ_MDCWB_HasFitRecord(wData)
    Wave wData

    Wave/Z coef  = $(LJZ_MDCWB_PathFitCoef(wData))
    Wave/Z sigma = $(LJZ_MDCWB_PathFitSigma(wData))
    Wave/Z info  = $(LJZ_MDCWB_PathFitInfo(wData))
    Wave/Z fit   = $(LJZ_MDCWB_PathFit(wData))
    Wave/Z res   = $(LJZ_MDCWB_PathRes(wData))

    if (!WaveExists(coef) || !WaveExists(sigma) || !WaveExists(info))
        return 0
    endif
    if (!WaveExists(fit) || !WaveExists(res))
        return 0
    endif

    if (numpnts(info) != LJZ_MDCWB_FitInfoSize())
        return 0
    endif
    if (numpnts(coef) <= 0)
        return 0
    endif
    if (numpnts(sigma) != numpnts(coef))
        return 0
    endif
    if (numpnts(fit) != numpnts(wData))
        return 0
    endif
    if (numpnts(res) != numpnts(wData))
        return 0
    endif

    if (numtype(info[1]) != 0 || numtype(info[2]) != 0 || numtype(info[3]) != 0)
        return 0
    endif
    if (numtype(info[4]) != 0)
        return 0
    endif
    if (numtype(info[9]) != 0 || info[9] <= 0)
        return 0
    endif

    return 1
End

Function LJZ_MDCWB_ReadFitOK(wData)
    Wave wData

    Wave/Z info = $(LJZ_MDCWB_PathFitInfo(wData))
    if (!WaveExists(info) || numpnts(info) < 5)
        return 0
    endif
    if (numtype(info[4]) != 0)
        return 0
    endif
    return (info[4] > 0.5)
End

Function LJZ_MDCWB_DeleteFitRecord(wData)
    Wave wData

    KillWaves/Z $(LJZ_MDCWB_PathFitCoef(wData))
    KillWaves/Z $(LJZ_MDCWB_PathFitSigma(wData))
    KillWaves/Z $(LJZ_MDCWB_PathFitInfo(wData))
    KillWaves/Z $(LJZ_MDCWB_PathFit(wData))
    KillWaves/Z $(LJZ_MDCWB_PathRes(wData))
    return 0
End


// ============================================================================
//  Section 9. Guess wave I/O (full-length cached preview)
// ============================================================================

Function LJZ_MDCWB_SaveGuessWave(wData, guessW)
    Wave wData, guessW

    LJZ_MDCWB_EnsureBaseDF()

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    String dfWNoColon = RemoveEnding(dfW, ":")

    String oldDF = GetDataFolder(1)
    Variable hadError = 0

    try
        SetDataFolder $dfWNoColon
        Duplicate/O guessW, $(nm + "_guess")
    catch
        hadError = 1
    endtry

    SetDataFolder $oldDF
    if (hadError || GetRTError(1) != 0)
        return -1
    endif
    return 0
End

Function LJZ_MDCWB_DeleteGuessWave(wData)
    Wave wData
    KillWaves/Z $(LJZ_MDCWB_PathGuess(wData))
    return 0
End


// ============================================================================
//  Section 10. Accept-state I/O
// ============================================================================

Function LJZ_MDCWB_ReadAcceptState(wData)
    Wave wData

    Wave/Z wA = $(LJZ_MDCWB_PathAccept(wData))
    if (!WaveExists(wA) || numpnts(wA) < 1)
        return 0
    endif
    if (numtype(wA[0]) != 0)
        return 0
    endif
    return wA[0]
End

Function LJZ_MDCWB_WriteAcceptState(wData, newState)
    Wave wData
    Variable newState

    LJZ_MDCWB_EnsureBaseDF()

    if (newState > 0)
        newState = 1
    elseif (newState < 0)
        newState = -1
    else
        newState = 0
    endif

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    String dfWNoColon = RemoveEnding(dfW, ":")

    String oldDF = GetDataFolder(1)
    Variable hadError = 0

    try
        SetDataFolder $dfWNoColon
        Make/O/N=1 $(nm + "_accept")
        Wave wA = $(nm + "_accept")
        wA[0] = newState

        Note/K wA
        Note wA, "accept[0]: 1=accepted; 0=unchecked; -1=rejected"
    catch
        hadError = 1
    endtry

    SetDataFolder $oldDF
    if (hadError || GetRTError(1) != 0)
        return -1
    endif
    return 0
End


// ============================================================================
//  Section 11. Bulk cleanup helpers
// ============================================================================

Function LJZ_MDCWB_DeleteAllPersistent(wData)
    Wave wData

    LJZ_MDCWB_DeleteEditState(wData)
    LJZ_MDCWB_DeleteFitRecord(wData)
    LJZ_MDCWB_DeleteGuessWave(wData)
    KillWaves/Z $(LJZ_MDCWB_PathAccept(wData))

    return 0
End


// ============================================================================
//  Section 12. Self-test
//
//  Run from the command line as:   LJZ_MDCWB_Part1_SelfTest()
//  This creates a synthetic mdc_show_0 wave under root:TEST_MDCWB_PART1, then
//  exercises every Part-1 entry point. Prints a pass/fail summary. Used to
//  verify Part 1 in isolation before Part 2 is wired in.
// ============================================================================

Function LJZ_MDCWB_Part1_SelfTest()
    NewDataFolder/O root:TEST_MDCWB_PART1
    String oldDF = GetDataFolder(1)
    SetDataFolder root:TEST_MDCWB_PART1

    Variable nFail = 0
    Variable nPass = 0
    String name = ""

    // --- prepare a fake mdc_show_0 ---
    Variable nk = 201
    Make/O/N=(nk) mdc_show_0 = sin(p / 30) + 0.05 * gnoise(1)
    SetScale/P x, -0.2, 0.002, mdc_show_0

    Make/O/N=(nk) mdc_show_1 = mdc_show_0[p]
    Make/O/N=(nk) mdc_show_2 = mdc_show_0[p]
    SetScale/P x, -0.2, 0.002, mdc_show_1, mdc_show_2

    Wave w = mdc_show_0

    // --- list discovery ---
    name = "ListMDCWaves"
    String lst = LJZ_MDCWB_ListMDCWaves("root:TEST_MDCWB_PART1:")
    if (ItemsInList(lst, ";") == 3)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL: got list =", lst
        nFail += 1
    endif

    name = "ParseMDCIndex"
    if (LJZ_MDCWB_ParseMDCIndex("mdc_show_5") == 5 && LJZ_MDCWB_ParseMDCIndex("foo") == -1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    // --- runtime DF setup ---
    LJZ_MDCWB_EnsureBaseDF()
    LJZ_MDCWB_ResetWorkState()

    // --- HasEditState should be false initially ---
    name = "HasEditState_initiallyFalse"
    if (LJZ_MDCWB_HasEditState(w) == 0)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    // --- append peaks in Work_* ---
    Variable idx0 = LJZ_MDCWB_WorkAppendPeak(LJZ_MDCWB_PeakTypePV(), -0.05, 0.012, 1.0)
    Variable idx1 = LJZ_MDCWB_WorkAppendPeak(LJZ_MDCWB_PeakTypeAsymPV(), 0.03, 0.010, 0.85)

    name = "WorkAppendPeak_indices"
    if (idx0 == 0 && idx1 == 1 && LJZ_MDCWB_WorkNumPeaks() == 2)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL: idx0=", idx0, "idx1=", idx1, "n=", LJZ_MDCWB_WorkNumPeaks()
        nFail += 1
    endif

    name = "WorkGetPeakField_AsymPV_wR_initialized"
    Variable wRVal = LJZ_MDCWB_WorkGetPeakField(1, LJZ_MDCWB_FieldWR())
    if (numtype(wRVal) == 0 && wRVal == 0.010)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL: wR=", wRVal
        nFail += 1
    endif

    name = "WorkSetPeakHold_roundtrip"
    LJZ_MDCWB_WorkSetPeakHold(0, LJZ_MDCWB_HoldFieldX0(), 1)
    if (LJZ_MDCWB_WorkGetPeakHold(0, LJZ_MDCWB_HoldFieldX0()) == 1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    // --- BG accessors ---
    LJZ_MDCWB_WorkSetBGOrder(2)
    LJZ_MDCWB_WorkSetBGCoef(0, 0.1)
    LJZ_MDCWB_WorkSetBGCoef(1, 0.2)
    LJZ_MDCWB_WorkSetBGCoef(2, 0.3)
    LJZ_MDCWB_WorkSetBGHold(2, 1)

    name = "BG_roundtrip"
    if (LJZ_MDCWB_WorkGetBGOrder() == 2 && LJZ_MDCWB_WorkGetBGCoef(1) == 0.2 && LJZ_MDCWB_WorkGetBGHold(2) == 1 && LJZ_MDCWB_WorkGetBGHold(0) == 0)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    // --- ROI / resH ---
    LJZ_MDCWB_WorkSetROI(-0.1, 0.1)
    LJZ_MDCWB_WorkSetResH(2e-3)
    LJZ_MDCWB_WorkSetResHHold(0)

    Variable xL, xH
    LJZ_MDCWB_WorkGetROI(xL, xH)

    name = "ROI_roundtrip"
    if (xL == -0.1 && xH == 0.1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    name = "ResH_roundtrip"
    if (LJZ_MDCWB_WorkGetResH() == 2e-3 && LJZ_MDCWB_WorkGetResHHold() == 0)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    // --- save edit state to disk ---
    Variable rc = LJZ_MDCWB_SaveEditStateFromWork(w)
    name = "SaveEditStateFromWork"
    if (rc == 0 && LJZ_MDCWB_HasEditState(w) == 1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL: rc=", rc
        nFail += 1
    endif

    // --- mutate Work_*, then load from disk and check restoration ---
    LJZ_MDCWB_WorkResizePeaks(0)
    LJZ_MDCWB_WorkSetROI(NaN, NaN)
    LJZ_MDCWB_WorkSetResH(NaN)

    Variable loaded = LJZ_MDCWB_LoadEditStateToWork(w)
    Variable xL2, xH2
    LJZ_MDCWB_WorkGetROI(xL2, xH2)

    name = "LoadEditStateToWork_restoresROI"
    if (loaded == 1 && xL2 == -0.1 && xH2 == 0.1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL: loaded=", loaded, "xL=", xL2, "xH=", xH2
        nFail += 1
    endif

    name = "LoadEditStateToWork_restoresPeaks"
    if (LJZ_MDCWB_WorkNumPeaks() == 2 && LJZ_MDCWB_WorkGetPeakField(0, LJZ_MDCWB_FieldX0()) == -0.05)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    // --- accept-state roundtrip ---
    LJZ_MDCWB_WriteAcceptState(w, 1)
    name = "Accept_roundtrip"
    if (LJZ_MDCWB_ReadAcceptState(w) == 1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    // --- delete a peak ---
    LJZ_MDCWB_WorkDeletePeak(0)
    name = "DeletePeak"
    if (LJZ_MDCWB_WorkNumPeaks() == 1 && LJZ_MDCWB_WorkGetPeakField(0, LJZ_MDCWB_FieldType()) == LJZ_MDCWB_PeakTypeAsymPV())
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    // --- fit record save (synthetic) ---
    Make/O/N=9 fakeCoef = {0.1, 0, 0, 1e-3, -0.05, 0.012, 1.0, 0.7, 0}    // BG3 + resH + 4-slot peak (filler)
    Make/O/N=9 fakeSigma = NaN
    Make/O/N=12 fakeInfo = NaN
    fakeInfo[0] = 0
    fakeInfo[1] = 2
    fakeInfo[2] = -0.1
    fakeInfo[3] = 0.1
    fakeInfo[4] = 1
    fakeInfo[9] = 50

    Duplicate/O w, fakeFit, fakeRes
    fakeFit = 0
    fakeRes = 0

    Variable rcFit = LJZ_MDCWB_SaveFitRecord(w, fakeCoef, fakeSigma, fakeInfo, fakeFit, fakeRes)
    name = "SaveFitRecord"
    if (rcFit == 0 && LJZ_MDCWB_HasFitRecord(w) == 1 && LJZ_MDCWB_ReadFitOK(w) == 1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL: rc=", rcFit
        nFail += 1
    endif

    // --- delete everything for cleanliness ---
    LJZ_MDCWB_DeleteAllPersistent(w)
    name = "DeleteAllPersistent"
    if (LJZ_MDCWB_HasEditState(w) == 0 && LJZ_MDCWB_HasFitRecord(w) == 0)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    Print "----"
    Print "Part 1 self-test summary: ", nPass, "passed,", nFail, "failed"

    SetDataFolder $oldDF
    return nFail
End
