#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  LJZ_EDCWB Part 1 : Core data model + Persistence
//
//  Contract (DO NOT VIOLATE in any other Part):
//
//    1. A single EDC's edit-state is expressed by 4 disk waves under the
//       same DF as the data wave:
//          <wname>_editpar      : nPar-element 1D double vector
//                                 (length = LJZ_EDCWB_ModelNPar(modelID))
//          <wname>_edithold     : nPar-element 1D double vector  (0 or 1)
//          <wname>_editinfo     : LJZ_EDCWB_EditInfoSize()-element vector
//          <wname>_roi          : 2-element 1D vector
//
//       Plus an optional schema marker:
//          <wname>_editMeta     : 1-element text wave
//                                 [0] = "schema=edc_v1"
//
//    2. Fit products keep their existing names (compatible with old EDCWB):
//          <wname>_fit          (full-length curve)
//          <wname>_res          (full-length residual)
//          <wname>_fitcoef      (flat coef wave, length = nPar)
//          <wname>_fitsigma     (same length)
//          <wname>_fitinfo      (LJZ_EDCWB_FitInfoSize()-element fixed schema)
//          <wname>_guess        (full-length cached guess)
//          <wname>_accept       (1-element: 1=accept, 0=unchecked, -1=reject)
//
//    3. Edit-state and fit-products may go stale independently.
//       Part 1 does not enforce consistency between them; that is Part 2's job.
//
//    4. Part 1 contains NO model physics. There is no FitFunc here.
//       The fit engine in Part 2 is the only module that assembles coef vectors.
//
//    5. _editinfo layout (LJZ_EDCWB_EditInfoSize() = 8 elements):
//          [0] modelID
//          [1] xLo
//          [2] xHi
//          [3] T        (temperature, K)
//          [4] EF       (Fermi energy, eV)
//          [5] res      (energy resolution FWHM, eV)
//          [6] normMode (0=none, 1=peak, 2=tail)
//          [7] reserved (NaN)
//
//    6. _fitinfo layout (LJZ_EDCWB_FitInfoSize() = 12 elements):
//          [0]  modelID
//          [1]  xLo
//          [2]  xHi
//          [3]  fitOK          (1=ok, 0=fail)
//          [4]  guessRMSE
//          [5]  fitRMSE
//          [6]  rssROI         (unweighted residual sum of squares in ROI)
//          [7]  maxAbsRes
//          [8]  nROI
//          [9]  fitQuitReason
//          [10] fitNumIters
//          [11] reserved (NaN)
//
// ============================================================================


// ============================================================================
//  Section 0. Constants and small helpers
// ============================================================================

// ---- runtime DF ----
Function/S LJZ_EDCWB_BaseDF()
    return "root:Packages:ARPES_LJZ:EDCWB"
End

// ---- per-EDC schema sizes ----
Function LJZ_EDCWB_EditInfoSize()
    return 8
End

Function LJZ_EDCWB_FitInfoSize()
    return 12
End

// ---- model IDs (Part 2 defines physics; Part 1 stores the ID only) ----
Function LJZ_EDCWB_Model_SinglePeakFD()
    return 1
End

Function LJZ_EDCWB_Model_EffectiveGap()
    return 2
End

Function LJZ_EDCWB_Model_SymGap()
    return 3
End

Function LJZ_EDCWB_IsValidModelID(m)
    Variable m
    if (m == 1 || m == 2 || m == 3)
        return 1
    endif
    return 0
End

Function/S LJZ_EDCWB_ModelName(m)
    Variable m
    if (m == 1)
        return "SinglePeak*FD*GaussConv"
    endif
    if (m == 2)
        return "EffectiveGap*FD*GaussConv"
    endif
    if (m == 3)
        return "SymmetrizedGap"
    endif
    return "Unknown"
End

// Number of free parameter slots for each model.
// Part 2 uses this to build the flat coef vector.
//   Model 1 (SinglePeakFD):   bg0 bg1 A x0 w eta T EF res   = 9
//   Model 2 (EffectiveGap):   bg0 bg1 A Delta Gamma T EF res = 8
//   Model 3 (SymGap):         bg0 bg1 A Delta Gamma x0       = 6
Function LJZ_EDCWB_ModelNPar(m)
    Variable m
    if (m == 1)
        return 9
    endif
    if (m == 2)
        return 8
    endif
    if (m == 3)
        return 6
    endif
    return 0
End

Function/S LJZ_EDCWB_ModelPopupList()
    String s = ""
    s = AddListItem(LJZ_EDCWB_ModelName(1), s, ";", Inf)
    s = AddListItem(LJZ_EDCWB_ModelName(2), s, ";", Inf)
    s = AddListItem(LJZ_EDCWB_ModelName(3), s, ";", Inf)
    return s
End

// ---- editinfo field index helpers ----
Function LJZ_EDCWB_EI_ModelID()
    return 0
End
Function LJZ_EDCWB_EI_XLo()
    return 1
End
Function LJZ_EDCWB_EI_XHi()
    return 2
End
Function LJZ_EDCWB_EI_T()
    return 3
End
Function LJZ_EDCWB_EI_EF()
    return 4
End
Function LJZ_EDCWB_EI_Res()
    return 5
End
Function LJZ_EDCWB_EI_NormMode()
    return 6
End

// ---- fitinfo field index helpers ----
Function LJZ_EDCWB_FI_ModelID()
    return 0
End
Function LJZ_EDCWB_FI_XLo()
    return 1
End
Function LJZ_EDCWB_FI_XHi()
    return 2
End
Function LJZ_EDCWB_FI_FitOK()
    return 3
End
Function LJZ_EDCWB_FI_GuessRMSE()
    return 4
End
Function LJZ_EDCWB_FI_FitRMSE()
    return 5
End
Function LJZ_EDCWB_FI_RssROI()
    return 6
End
Function LJZ_EDCWB_FI_MaxAbsRes()
    return 7
End
Function LJZ_EDCWB_FI_NROI()
    return 8
End
Function LJZ_EDCWB_FI_FitQuitReason()
    return 9
End
Function LJZ_EDCWB_FI_FitNumIters()
    return 10
End

// ---- DF path normalization ----
Function/S LJZ_EDCWB_NormDFPath(df)
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

Function/S LJZ_EDCWB_PathEditPar(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_editpar"
End

Function/S LJZ_EDCWB_PathEditHold(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_edithold"
End

Function/S LJZ_EDCWB_PathEditInfo(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_editinfo"
End

Function/S LJZ_EDCWB_PathROI(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_roi"
End

Function/S LJZ_EDCWB_PathEditMeta(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_editMeta"
End

Function/S LJZ_EDCWB_PathFit(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_fit"
End

Function/S LJZ_EDCWB_PathRes(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_res"
End

Function/S LJZ_EDCWB_PathFitCoef(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_fitcoef"
End

Function/S LJZ_EDCWB_PathFitSigma(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_fitsigma"
End

Function/S LJZ_EDCWB_PathFitInfo(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_fitinfo"
End

Function/S LJZ_EDCWB_PathGuess(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_guess"
End

Function/S LJZ_EDCWB_PathAccept(wData)
    Wave wData
    return GetWavesDataFolder(wData, 1) + NameOfWave(wData) + "_accept"
End


// ============================================================================
//  Section 2. Runtime DF + Work-state initialization
// ============================================================================

Function LJZ_EDCWB_EnsureBaseDF()
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:ARPES_LJZ
    NewDataFolder/O $(LJZ_EDCWB_BaseDF())
    LJZ_EDCWB_EnsureRuntimeState()
    return 0
End

// Working copy of the current EDC's edit-state, plus session globals.
// Naming convention: Work_*  for editable mirror, Active_*  for fit-time snapshot.
Function LJZ_EDCWB_EnsureRuntimeState()
    String base = LJZ_EDCWB_BaseDF()

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

    // ---- session UI prefs (persisted across wave switches) ----
    NVAR/Z useCsr = $(base + ":UseCursors")
    if (!NVAR_Exists(useCsr))
        Variable/G $(base + ":UseCursors") = 1
    endif

    NVAR/Z defModel = $(base + ":DefaultModelID")
    if (!NVAR_Exists(defModel))
        Variable/G $(base + ":DefaultModelID") = LJZ_EDCWB_Model_SinglePeakFD()
    endif

    NVAR/Z dirty = $(base + ":Dirty")
    if (!NVAR_Exists(dirty))
        Variable/G $(base + ":Dirty") = 1
    endif

    SVAR/Z lastErr = $(base + ":LastErrorMsg")
    if (!SVAR_Exists(lastErr))
        String/G $(base + ":LastErrorMsg") = ""
    endif

    // ---- working copy of edit-state ----
    // Work_par and Work_hold are resized when the model changes.
    // They are always exactly nPar(modelID) long.
    Wave/Z wPar = $(base + ":Work_par")
    if (!WaveExists(wPar))
        Make/O/N=(LJZ_EDCWB_ModelNPar(LJZ_EDCWB_Model_SinglePeakFD())) $(base + ":Work_par") = NaN
    endif

    Wave/Z wHold = $(base + ":Work_hold")
    if (!WaveExists(wHold))
        Make/O/N=(LJZ_EDCWB_ModelNPar(LJZ_EDCWB_Model_SinglePeakFD())) $(base + ":Work_hold") = 0
    endif

    Wave/Z wEI = $(base + ":Work_editinfo")
    if (!WaveExists(wEI))
        Make/O/N=(LJZ_EDCWB_EditInfoSize()) $(base + ":Work_editinfo") = NaN
        Wave wEINew = $(base + ":Work_editinfo")
        wEINew[LJZ_EDCWB_EI_ModelID()]   = LJZ_EDCWB_Model_SinglePeakFD()
        wEINew[LJZ_EDCWB_EI_T()]         = 10      // K
        wEINew[LJZ_EDCWB_EI_EF()]        = 0       // eV
        wEINew[LJZ_EDCWB_EI_Res()]       = 0.01    // eV FWHM
        wEINew[LJZ_EDCWB_EI_NormMode()]  = 0
    endif

    Wave/Z wROI = $(base + ":Work_roi")
    if (!WaveExists(wROI))
        Make/O/N=(2) $(base + ":Work_roi") = NaN
    endif

    return 0
End


// ============================================================================
//  Section 3. Dirty / error state helpers
// ============================================================================

Function LJZ_EDCWB_MarkDirty(flag)
    Variable flag
    NVAR isDirty = $(LJZ_EDCWB_BaseDF() + ":Dirty")
    isDirty = flag
    return 0
End

Function LJZ_EDCWB_IsDirty()
    NVAR isDirty = $(LJZ_EDCWB_BaseDF() + ":Dirty")
    return isDirty
End

Function LJZ_EDCWB_ClearLastError()
    SVAR lastErr = $(LJZ_EDCWB_BaseDF() + ":LastErrorMsg")
    lastErr = ""
    return 0
End

Function LJZ_EDCWB_SetLastError(msg)
    String msg
    SVAR lastErr = $(LJZ_EDCWB_BaseDF() + ":LastErrorMsg")
    lastErr = msg
    return 0
End

Function/S LJZ_EDCWB_GetLastError()
    SVAR lastErr = $(LJZ_EDCWB_BaseDF() + ":LastErrorMsg")
    return lastErr
End


// ============================================================================
//  Section 4. EDC list discovery  (edc_show_<k>)
// ============================================================================

Function/S LJZ_EDCWB_ListEDCWaves(dfPath)
    String dfPath

    dfPath = LJZ_EDCWB_NormDFPath(dfPath)
    if (strlen(dfPath) == 0)
        return ""
    endif

    String out = ""

    // Prefer the canonical edc_show_0, 1, 2, ... sequence
    Wave/Z w0 = $(dfPath + "edc_show_0")
    if (WaveExists(w0))
        Variable k = 0
        do
            Wave/Z wk = $(dfPath + "edc_show_" + Num2Str(k))
            if (!WaveExists(wk))
                break
            endif
            out = AddListItem(dfPath + NameOfWave(wk), out, ";", Inf)
            k += 1
        while (1)
        return out
    endif

    // Fallback: any 1D numeric wave whose name contains "edc"
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
        if (StringMatch(LowerStr(nm), "*edc*"))
            out = AddListItem(dfPath + nm, out, ";", Inf)
        endif
    endfor

    out = SortList(out, ";", 16)
    return out
End

Function LJZ_EDCWB_ParseEDCIndex(nm)
    String nm

    if (!StringMatch(nm, "edc_show_*"))
        return -1
    endif

    String tail = ReplaceString("edc_show_", nm, "")
    Variable v = str2num(tail)
    if (numtype(v) != 0)
        return -1
    endif

    // Exact round-trip check to reject "edc_show_007" etc.
    String exact
    sprintf exact, "%d", round(v)
    if (CmpStr(tail, exact) != 0)
        return -1
    endif

    return round(v)
End


// ============================================================================
//  Section 5. Edit-state read: disk -> Work_*
//
//  Intentionally tolerant. Missing / malformed waves do NOT crash; the caller
//  can use LJZ_EDCWB_HasEditState() to detect "no saved edit state on disk"
//  and fall back to auto-init in Part 2.
// ============================================================================

// True iff the 4 mandatory edit-state waves exist with sane shapes.
Function LJZ_EDCWB_HasEditState(wData)
    Wave wData

    Wave/Z wPar  = $(LJZ_EDCWB_PathEditPar(wData))
    Wave/Z wHold = $(LJZ_EDCWB_PathEditHold(wData))
    Wave/Z wEI   = $(LJZ_EDCWB_PathEditInfo(wData))
    Wave/Z wROI  = $(LJZ_EDCWB_PathROI(wData))

    if (!WaveExists(wPar) || !WaveExists(wHold) || !WaveExists(wEI) || !WaveExists(wROI))
        return 0
    endif

    // editinfo must have the right length
    if (numpnts(wEI) != LJZ_EDCWB_EditInfoSize())
        return 0
    endif

    // modelID in editinfo must be valid
    Variable m = round(wEI[LJZ_EDCWB_EI_ModelID()])
    if (!LJZ_EDCWB_IsValidModelID(m))
        return 0
    endif

    // par and hold must both have exactly nPar(m) elements
    Variable nPar = LJZ_EDCWB_ModelNPar(m)
    if (numpnts(wPar) != nPar || numpnts(wHold) != nPar)
        return 0
    endif

    // ROI wave must be 2-element
    if (numpnts(wROI) != 2)
        return 0
    endif

    return 1
End

// Copy disk edit-state into Work_*. Returns 1 on success, 0 on missing/invalid.
Function LJZ_EDCWB_LoadEditStateToWork(wData)
    Wave wData

    LJZ_EDCWB_EnsureBaseDF()

    if (!LJZ_EDCWB_HasEditState(wData))
        return 0
    endif

    Wave src_par  = $(LJZ_EDCWB_PathEditPar(wData))
    Wave src_hold = $(LJZ_EDCWB_PathEditHold(wData))
    Wave src_ei   = $(LJZ_EDCWB_PathEditInfo(wData))
    Wave src_roi  = $(LJZ_EDCWB_PathROI(wData))

    String base  = LJZ_EDCWB_BaseDF()
    Variable m   = round(src_ei[LJZ_EDCWB_EI_ModelID()])
    Variable nPar = LJZ_EDCWB_ModelNPar(m)

    Wave dst_par  = $(base + ":Work_par")
    Wave dst_hold = $(base + ":Work_hold")

    Redimension/N=(nPar) dst_par, dst_hold

    Variable i
    for (i = 0; i < nPar; i += 1)
        dst_par[i]  = src_par[i]
        dst_hold[i] = src_hold[i]
    endfor

    Wave dst_ei  = $(base + ":Work_editinfo")
    dst_ei = src_ei[p]

    Wave dst_roi = $(base + ":Work_roi")
    dst_roi = src_roi[p]

    return 1
End

// Reset Work_* to "empty edit state" for the default model.
// Used when switching to a wave that has no saved edit state.
Function LJZ_EDCWB_ResetWorkState()
    LJZ_EDCWB_EnsureBaseDF()

    String base = LJZ_EDCWB_BaseDF()

    NVAR defModel = $(base + ":DefaultModelID")
    Variable m = defModel
    if (!LJZ_EDCWB_IsValidModelID(m))
        m = LJZ_EDCWB_Model_SinglePeakFD()
    endif
    Variable nPar = LJZ_EDCWB_ModelNPar(m)

    Wave wPar  = $(base + ":Work_par")
    Wave wHold = $(base + ":Work_hold")
    Redimension/N=(nPar) wPar, wHold
    wPar  = NaN
    wHold = 0

    Wave wEI = $(base + ":Work_editinfo")
    wEI = NaN
    wEI[LJZ_EDCWB_EI_ModelID()]   = m
    wEI[LJZ_EDCWB_EI_T()]         = 10
    wEI[LJZ_EDCWB_EI_EF()]        = 0
    wEI[LJZ_EDCWB_EI_Res()]       = 0.01
    wEI[LJZ_EDCWB_EI_NormMode()]  = 0

    Wave wROI = $(base + ":Work_roi")
    wROI = NaN

    return 0
End


// ============================================================================
//  Section 6. Edit-state write: Work_* -> disk (atomic per-wave)
// ============================================================================

Function LJZ_EDCWB_SaveEditStateFromWork(wData)
    Wave wData

    LJZ_EDCWB_EnsureBaseDF()

    String base      = LJZ_EDCWB_BaseDF()
    String dfW       = GetWavesDataFolder(wData, 1)
    String nm        = NameOfWave(wData)
    String dfWNoColon = RemoveEnding(dfW, ":")

    Wave src_par  = $(base + ":Work_par")
    Wave src_hold = $(base + ":Work_hold")
    Wave src_ei   = $(base + ":Work_editinfo")
    Wave src_roi  = $(base + ":Work_roi")

    String oldDF   = GetDataFolder(1)
    Variable hadError = 0

    try
        SetDataFolder $dfWNoColon

        Duplicate/O src_par,  $(nm + "_editpar")
        Duplicate/O src_hold, $(nm + "_edithold")
        Duplicate/O src_ei,   $(nm + "_editinfo")
        Duplicate/O src_roi,  $(nm + "_roi")

        Make/O/T/N=1 $(nm + "_editMeta")
        Wave/T meta = $(nm + "_editMeta")
        meta[0] = "schema=edc_v1;saved=" + Secs2Date(DateTime, -2) + " " + Secs2Time(DateTime, 3)
    catch
        hadError = 1
    endtry

    SetDataFolder $oldDF
    if (hadError || GetRTError(1) != 0)
        return -1
    endif

    return 0
End

Function LJZ_EDCWB_DeleteEditState(wData)
    Wave wData

    KillWaves/Z $(LJZ_EDCWB_PathEditPar(wData))
    KillWaves/Z $(LJZ_EDCWB_PathEditHold(wData))
    KillWaves/Z $(LJZ_EDCWB_PathEditInfo(wData))
    KillWaves/Z $(LJZ_EDCWB_PathROI(wData))
    KillWaves/Z $(LJZ_EDCWB_PathEditMeta(wData))

    return 0
End


// ============================================================================
//  Section 7. Work-state convenience accessors
//
//  Keep them dumb: read/write only, no policy, no dirty marking.
// ============================================================================

Function LJZ_EDCWB_WorkGetModelID()
    LJZ_EDCWB_EnsureBaseDF()
    Wave wEI = $(LJZ_EDCWB_BaseDF() + ":Work_editinfo")
    return round(wEI[LJZ_EDCWB_EI_ModelID()])
End

Function LJZ_EDCWB_WorkSetModelID(m)
    Variable m

    LJZ_EDCWB_EnsureBaseDF()
    if (!LJZ_EDCWB_IsValidModelID(m))
        return -1
    endif
    Wave wEI = $(LJZ_EDCWB_BaseDF() + ":Work_editinfo")
    wEI[LJZ_EDCWB_EI_ModelID()] = m

    // Resize Work_par / Work_hold to match the new model's nPar.
    Variable nPar = LJZ_EDCWB_ModelNPar(m)
    Wave wPar  = $(LJZ_EDCWB_BaseDF() + ":Work_par")
    Wave wHold = $(LJZ_EDCWB_BaseDF() + ":Work_hold")
    Variable oldN = numpnts(wPar)
    Redimension/N=(nPar) wPar, wHold
    if (nPar > oldN)
        wPar[oldN, nPar - 1]  = NaN
        wHold[oldN, nPar - 1] = 0
    endif
    return 0
End

// Par value accessors (by slot index 0..nPar-1)
Function LJZ_EDCWB_WorkGetPar(idx)
    Variable idx

    LJZ_EDCWB_EnsureBaseDF()
    Wave wPar = $(LJZ_EDCWB_BaseDF() + ":Work_par")
    if (idx < 0 || idx >= numpnts(wPar))
        return NaN
    endif
    return wPar[idx]
End

Function LJZ_EDCWB_WorkSetPar(idx, val)
    Variable idx, val

    LJZ_EDCWB_EnsureBaseDF()
    Wave wPar = $(LJZ_EDCWB_BaseDF() + ":Work_par")
    if (idx < 0 || idx >= numpnts(wPar))
        return -1
    endif
    wPar[idx] = val
    return 0
End

// Hold accessors
Function LJZ_EDCWB_WorkGetHold(idx)
    Variable idx

    LJZ_EDCWB_EnsureBaseDF()
    Wave wHold = $(LJZ_EDCWB_BaseDF() + ":Work_hold")
    if (idx < 0 || idx >= numpnts(wHold))
        return 0
    endif
    return (wHold[idx] != 0)
End

Function LJZ_EDCWB_WorkSetHold(idx, on)
    Variable idx, on

    LJZ_EDCWB_EnsureBaseDF()
    Wave wHold = $(LJZ_EDCWB_BaseDF() + ":Work_hold")
    if (idx < 0 || idx >= numpnts(wHold))
        return -1
    endif
    wHold[idx] = (on != 0)
    return 0
End

// Physical aux accessors (T, EF, res, normMode stored in Work_editinfo)
Function LJZ_EDCWB_WorkGetT()
    LJZ_EDCWB_EnsureBaseDF()
    Wave wEI = $(LJZ_EDCWB_BaseDF() + ":Work_editinfo")
    return wEI[LJZ_EDCWB_EI_T()]
End

Function LJZ_EDCWB_WorkSetT(val)
    Variable val
    LJZ_EDCWB_EnsureBaseDF()
    if (val < 0)
        val = 0
    endif
    Wave wEI = $(LJZ_EDCWB_BaseDF() + ":Work_editinfo")
    wEI[LJZ_EDCWB_EI_T()] = val
    return 0
End

Function LJZ_EDCWB_WorkGetEF()
    LJZ_EDCWB_EnsureBaseDF()
    Wave wEI = $(LJZ_EDCWB_BaseDF() + ":Work_editinfo")
    return wEI[LJZ_EDCWB_EI_EF()]
End

Function LJZ_EDCWB_WorkSetEF(val)
    Variable val
    LJZ_EDCWB_EnsureBaseDF()
    Wave wEI = $(LJZ_EDCWB_BaseDF() + ":Work_editinfo")
    wEI[LJZ_EDCWB_EI_EF()] = val
    return 0
End

Function LJZ_EDCWB_WorkGetRes()
    LJZ_EDCWB_EnsureBaseDF()
    Wave wEI = $(LJZ_EDCWB_BaseDF() + ":Work_editinfo")
    return wEI[LJZ_EDCWB_EI_Res()]
End

Function LJZ_EDCWB_WorkSetRes(val)
    Variable val
    LJZ_EDCWB_EnsureBaseDF()
    if (val <= 0)
        val = 1e-4
    endif
    Wave wEI = $(LJZ_EDCWB_BaseDF() + ":Work_editinfo")
    wEI[LJZ_EDCWB_EI_Res()] = val
    return 0
End

Function LJZ_EDCWB_WorkGetNormMode()
    LJZ_EDCWB_EnsureBaseDF()
    Wave wEI = $(LJZ_EDCWB_BaseDF() + ":Work_editinfo")
    return round(wEI[LJZ_EDCWB_EI_NormMode()])
End

Function LJZ_EDCWB_WorkSetNormMode(mode)
    Variable mode
    LJZ_EDCWB_EnsureBaseDF()
    if (mode < 0)
        mode = 0
    endif
    Wave wEI = $(LJZ_EDCWB_BaseDF() + ":Work_editinfo")
    wEI[LJZ_EDCWB_EI_NormMode()] = mode
    return 0
End

// ROI accessors
Function LJZ_EDCWB_WorkGetROI(xLoOut, xHiOut)
    Variable &xLoOut, &xHiOut

    LJZ_EDCWB_EnsureBaseDF()
    Wave wROI = $(LJZ_EDCWB_BaseDF() + ":Work_roi")
    xLoOut = wROI[0]
    xHiOut = wROI[1]
    return 0
End

Function LJZ_EDCWB_WorkSetROI(xLo, xHi)
    Variable xLo, xHi
    LJZ_EDCWB_EnsureBaseDF()
    Wave wROI = $(LJZ_EDCWB_BaseDF() + ":Work_roi")
    wROI[0] = xLo
    wROI[1] = xHi
    return 0
End


// ============================================================================
//  Section 8. Fit-product save / load (atomic per-record)
//
//  Uses the same temp -> backup -> replace -> cleanup pattern as MDC Part 1.
//  fitW / resW must match length(wData).
//  coefW / sigmaW must both have length = ModelNPar(modelID).
// ============================================================================

Function/S LJZ_EDCWB_FitInfoSchemaNote()
    String s = ""
    s += "fitinfo[0]=modelID;"
    s += "fitinfo[1]=xLo;"
    s += "fitinfo[2]=xHi;"
    s += "fitinfo[3]=fitOK;"
    s += "fitinfo[4]=guessRMSE;"
    s += "fitinfo[5]=fitRMSE;"
    s += "fitinfo[6]=rssROI_unweighted;"
    s += "fitinfo[7]=maxAbsRes;"
    s += "fitinfo[8]=nROI;"
    s += "fitinfo[9]=fitQuitReason;"
    s += "fitinfo[10]=fitNumIters;"
    s += "fitinfo[11]=reserved"
    return s
End

Function LJZ_EDCWB_InitFitInfoWave(infoW)
    Wave infoW
    if (numpnts(infoW) != LJZ_EDCWB_FitInfoSize())
        Redimension/N=(LJZ_EDCWB_FitInfoSize()) infoW
    endif
    infoW = NaN
    return 0
End

Function LJZ_EDCWB_SaveFitRecord(wData, coefW, sigmaW, infoW, fitW, resW)
    Wave wData, coefW, infoW, fitW, resW
    Wave/Z sigmaW

    LJZ_EDCWB_EnsureBaseDF()

    String dfW       = GetWavesDataFolder(wData, 1)
    String nm        = NameOfWave(wData)
    String dfWNoColon = RemoveEnding(dfW, ":")

    String oldDF      = GetDataFolder(1)
    Variable hadError = 0
    Variable replaceStarted = 0

    try
        SetDataFolder $dfWNoColon

        KillWaves/Z $(nm + "_fitcoef__tmp"), $(nm + "_fitsigma__tmp"), $(nm + "_fitinfo__tmp")
        KillWaves/Z $(nm + "_fit__tmp"),     $(nm + "_res__tmp")
        KillWaves/Z $(nm + "_fitcoef__bak"), $(nm + "_fitsigma__bak"), $(nm + "_fitinfo__bak")
        KillWaves/Z $(nm + "_fit__bak"),     $(nm + "_res__bak")

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
        if (numpnts(wInfoTmp) != LJZ_EDCWB_FitInfoSize())
            Redimension/N=(LJZ_EDCWB_FitInfoSize()) wInfoTmp
        endif
        Note/K wInfoTmp
        Note wInfoTmp, LJZ_EDCWB_FitInfoSchemaNote()

        Duplicate/O fitW, $(nm + "_fit__tmp")
        Duplicate/O resW, $(nm + "_res__tmp")

        // ---- backup current official record ----
        Wave/Z oldCoef  = $(nm + "_fitcoef")
        Wave/Z oldSigma = $(nm + "_fitsigma")
        Wave/Z oldInfo  = $(nm + "_fitinfo")
        Wave/Z oldFit   = $(nm + "_fit")
        Wave/Z oldRes   = $(nm + "_res")

        if (WaveExists(oldCoef))
            Duplicate/O oldCoef,  $(nm + "_fitcoef__bak")
        endif
        if (WaveExists(oldSigma))
            Duplicate/O oldSigma, $(nm + "_fitsigma__bak")
        endif
        if (WaveExists(oldInfo))
            Duplicate/O oldInfo,  $(nm + "_fitinfo__bak")
        endif
        if (WaveExists(oldFit))
            Duplicate/O oldFit,   $(nm + "_fit__bak")
        endif
        if (WaveExists(oldRes))
            Duplicate/O oldRes,   $(nm + "_res__bak")
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
                Duplicate/O bakCoef,  $(nm + "_fitcoef")
            else
                KillWaves/Z $(nm + "_fitcoef")
            endif
            if (WaveExists(bakSigma))
                Duplicate/O bakSigma, $(nm + "_fitsigma")
            else
                KillWaves/Z $(nm + "_fitsigma")
            endif
            if (WaveExists(bakInfo))
                Duplicate/O bakInfo,  $(nm + "_fitinfo")
            else
                KillWaves/Z $(nm + "_fitinfo")
            endif
            if (WaveExists(bakFit))
                Duplicate/O bakFit,   $(nm + "_fit")
            else
                KillWaves/Z $(nm + "_fit")
            endif
            if (WaveExists(bakRes))
                Duplicate/O bakRes,   $(nm + "_res")
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

    KillWaves/Z $(nm + "_fitcoef__tmp"),  $(nm + "_fitsigma__tmp"), $(nm + "_fitinfo__tmp")
    KillWaves/Z $(nm + "_fit__tmp"),      $(nm + "_res__tmp")
    KillWaves/Z $(nm + "_fitcoef__bak"),  $(nm + "_fitsigma__bak"), $(nm + "_fitinfo__bak")
    KillWaves/Z $(nm + "_fit__bak"),      $(nm + "_res__bak")
    SetDataFolder $oldDF

    return 0
End

Function LJZ_EDCWB_HasFitRecord(wData)
    Wave wData

    Wave/Z coef  = $(LJZ_EDCWB_PathFitCoef(wData))
    Wave/Z sigma = $(LJZ_EDCWB_PathFitSigma(wData))
    Wave/Z info  = $(LJZ_EDCWB_PathFitInfo(wData))
    Wave/Z fit   = $(LJZ_EDCWB_PathFit(wData))
    Wave/Z res   = $(LJZ_EDCWB_PathRes(wData))

    if (!WaveExists(coef) || !WaveExists(sigma) || !WaveExists(info))
        return 0
    endif
    if (!WaveExists(fit) || !WaveExists(res))
        return 0
    endif
    if (numpnts(info) != LJZ_EDCWB_FitInfoSize())
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

    // modelID must be valid
    Variable modelID = round(info[LJZ_EDCWB_FI_ModelID()])
    if (!LJZ_EDCWB_IsValidModelID(modelID))
        return 0
    endif
    if (numpnts(coef) != LJZ_EDCWB_ModelNPar(modelID))
        return 0
    endif
    // fitOK must be present
    if (numtype(info[LJZ_EDCWB_FI_FitOK()]) != 0)
        return 0
    endif
    // nROI must be positive
    if (numtype(info[LJZ_EDCWB_FI_NROI()]) != 0 || info[LJZ_EDCWB_FI_NROI()] <= 0)
        return 0
    endif

    return 1
End

Function LJZ_EDCWB_ReadFitOK(wData)
    Wave wData

    Wave/Z info = $(LJZ_EDCWB_PathFitInfo(wData))
    if (!WaveExists(info) || numpnts(info) < LJZ_EDCWB_FitInfoSize())
        return 0
    endif
    if (numtype(info[LJZ_EDCWB_FI_FitOK()]) != 0)
        return 0
    endif
    return (info[LJZ_EDCWB_FI_FitOK()] > 0.5)
End

Function LJZ_EDCWB_DeleteFitRecord(wData)
    Wave wData

    KillWaves/Z $(LJZ_EDCWB_PathFitCoef(wData))
    KillWaves/Z $(LJZ_EDCWB_PathFitSigma(wData))
    KillWaves/Z $(LJZ_EDCWB_PathFitInfo(wData))
    KillWaves/Z $(LJZ_EDCWB_PathFit(wData))
    KillWaves/Z $(LJZ_EDCWB_PathRes(wData))
    return 0
End


// ============================================================================
//  Section 9. Guess wave I/O (full-length cached preview)
// ============================================================================

Function LJZ_EDCWB_SaveGuessWave(wData, guessW)
    Wave wData, guessW

    LJZ_EDCWB_EnsureBaseDF()

    String dfW       = GetWavesDataFolder(wData, 1)
    String nm        = NameOfWave(wData)
    String dfWNoColon = RemoveEnding(dfW, ":")

    String oldDF   = GetDataFolder(1)
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

Function LJZ_EDCWB_DeleteGuessWave(wData)
    Wave wData
    KillWaves/Z $(LJZ_EDCWB_PathGuess(wData))
    return 0
End


// ============================================================================
//  Section 10. Accept-state I/O
// ============================================================================

Function LJZ_EDCWB_ReadAcceptState(wData)
    Wave wData

    Wave/Z wA = $(LJZ_EDCWB_PathAccept(wData))
    if (!WaveExists(wA) || numpnts(wA) < 1)
        return 0
    endif
    if (numtype(wA[0]) != 0)
        return 0
    endif
    return wA[0]
End

Function LJZ_EDCWB_WriteAcceptState(wData, newState)
    Wave wData
    Variable newState

    LJZ_EDCWB_EnsureBaseDF()

    if (newState > 0)
        newState = 1
    elseif (newState < 0)
        newState = -1
    else
        newState = 0
    endif

    String dfW       = GetWavesDataFolder(wData, 1)
    String nm        = NameOfWave(wData)
    String dfWNoColon = RemoveEnding(dfW, ":")

    String oldDF   = GetDataFolder(1)
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

Function LJZ_EDCWB_DeleteAllPersistent(wData)
    Wave wData

    LJZ_EDCWB_DeleteEditState(wData)
    LJZ_EDCWB_DeleteFitRecord(wData)
    LJZ_EDCWB_DeleteGuessWave(wData)
    KillWaves/Z $(LJZ_EDCWB_PathAccept(wData))

    return 0
End


// ============================================================================
//  Section 12. Self-test
//
//  Run from the command line as:   LJZ_EDCWB_Part1_SelfTest()
//  Creates synthetic edc_show_0/1/2 waves under root:TEST_EDCWB_PART1,
//  exercises every Part-1 entry point, and prints a pass/fail summary.
// ============================================================================

Function LJZ_EDCWB_Part1_SelfTest()
    NewDataFolder/O root:TEST_EDCWB_PART1
    String oldDF = GetDataFolder(1)
    SetDataFolder root:TEST_EDCWB_PART1

    Variable nFail = 0
    Variable nPass = 0
    String name = ""

    // --- prepare synthetic edc_show_0/1/2 ---
    Variable nE = 201
    Make/O/N=(nE) edc_show_0 = exp(-((p - 100) / 20)^2) * 0.7 / (exp((p - 100) * 0.01 / 0.025) + 1) + 0.02 * gnoise(1) + 0.05
    SetScale/P x, -0.5, 0.005, edc_show_0
    Make/O/N=(nE) edc_show_1 = edc_show_0[p]
    Make/O/N=(nE) edc_show_2 = edc_show_0[p]
    SetScale/P x, -0.5, 0.005, edc_show_1, edc_show_2

    Wave w = edc_show_0

    // --- list discovery ---
    name = "ListEDCWaves"
    String lst = LJZ_EDCWB_ListEDCWaves("root:TEST_EDCWB_PART1:")
    if (ItemsInList(lst, ";") == 3)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL: got list =", lst
        nFail += 1
    endif

    name = "ParseEDCIndex"
    if (LJZ_EDCWB_ParseEDCIndex("edc_show_5") == 5 && LJZ_EDCWB_ParseEDCIndex("foo") == -1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    // --- runtime DF setup ---
    LJZ_EDCWB_EnsureBaseDF()
    LJZ_EDCWB_ResetWorkState()

    // --- HasEditState should be false initially ---
    name = "HasEditState_initiallyFalse"
    if (LJZ_EDCWB_HasEditState(w) == 0)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    // --- model switch and par/hold resize ---
    LJZ_EDCWB_WorkSetModelID(LJZ_EDCWB_Model_EffectiveGap())
    name = "WorkSetModelID_EffectiveGap"
    Wave wPar = $(LJZ_EDCWB_BaseDF() + ":Work_par")
    if (LJZ_EDCWB_WorkGetModelID() == LJZ_EDCWB_Model_EffectiveGap() && numpnts(wPar) == LJZ_EDCWB_ModelNPar(LJZ_EDCWB_Model_EffectiveGap()))
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL: nPar =", numpnts(wPar)
        nFail += 1
    endif

    // --- par/hold accessors ---
    LJZ_EDCWB_WorkSetPar(0, 0.05)
    LJZ_EDCWB_WorkSetPar(2, 1.2)
    LJZ_EDCWB_WorkSetHold(0, 0)
    LJZ_EDCWB_WorkSetHold(5, 1)   // T slot for EffectiveGap

    name = "WorkPar_roundtrip"
    if (LJZ_EDCWB_WorkGetPar(0) == 0.05 && LJZ_EDCWB_WorkGetPar(2) == 1.2)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    name = "WorkHold_roundtrip"
    if (LJZ_EDCWB_WorkGetHold(0) == 0 && LJZ_EDCWB_WorkGetHold(5) == 1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    // --- T / EF / res / normMode ---
    LJZ_EDCWB_WorkSetT(20)
    LJZ_EDCWB_WorkSetEF(0.002)
    LJZ_EDCWB_WorkSetRes(0.015)
    LJZ_EDCWB_WorkSetNormMode(1)

    name = "AuxState_roundtrip"
    if (LJZ_EDCWB_WorkGetT() == 20 && LJZ_EDCWB_WorkGetEF() == 0.002 && LJZ_EDCWB_WorkGetRes() == 0.015 && LJZ_EDCWB_WorkGetNormMode() == 1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    // --- ROI ---
    LJZ_EDCWB_WorkSetROI(-0.3, 0.1)
    Variable xL, xH
    LJZ_EDCWB_WorkGetROI(xL, xH)

    name = "ROI_roundtrip"
    if (xL == -0.3 && xH == 0.1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL:", xL, xH
        nFail += 1
    endif

    // --- save edit state to disk ---
    Variable rc = LJZ_EDCWB_SaveEditStateFromWork(w)
    name = "SaveEditStateFromWork"
    if (rc == 0 && LJZ_EDCWB_HasEditState(w) == 1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL: rc =", rc
        nFail += 1
    endif

    // --- mutate Work_*, then load from disk and check restoration ---
    LJZ_EDCWB_WorkSetPar(0, NaN)
    LJZ_EDCWB_WorkSetROI(NaN, NaN)
    LJZ_EDCWB_WorkSetT(999)

    Variable loaded = LJZ_EDCWB_LoadEditStateToWork(w)
    Variable xL2, xH2
    LJZ_EDCWB_WorkGetROI(xL2, xH2)

    name = "LoadEditStateToWork_restoresROI"
    if (loaded == 1 && xL2 == -0.3 && xH2 == 0.1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL: loaded =", loaded, "xL =", xL2, "xH =", xH2
        nFail += 1
    endif

    name = "LoadEditStateToWork_restoresPar"
    if (LJZ_EDCWB_WorkGetPar(0) == 0.05 && LJZ_EDCWB_WorkGetPar(2) == 1.2)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    name = "LoadEditStateToWork_restoresT"
    if (LJZ_EDCWB_WorkGetT() == 20)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL: T =", LJZ_EDCWB_WorkGetT()
        nFail += 1
    endif

    // --- accept-state roundtrip ---
    LJZ_EDCWB_WriteAcceptState(w, 1)
    name = "Accept_roundtrip"
    if (LJZ_EDCWB_ReadAcceptState(w) == 1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL"
        nFail += 1
    endif

    // --- fit record save (synthetic) ---
    Variable nParM2 = LJZ_EDCWB_ModelNPar(LJZ_EDCWB_Model_EffectiveGap())
    Make/O/N=(nParM2) fakeCoef = {0.05, 0, 1.0, 0.02, 0.008, 20, 0.002, 0.015}
    Make/O/N=(nParM2) fakeSigma = NaN
    Make/O/N=(LJZ_EDCWB_FitInfoSize()) fakeInfo = NaN
    fakeInfo[LJZ_EDCWB_FI_ModelID()] = LJZ_EDCWB_Model_EffectiveGap()
    fakeInfo[LJZ_EDCWB_FI_XLo()]     = -0.3
    fakeInfo[LJZ_EDCWB_FI_XHi()]     = 0.1
    fakeInfo[LJZ_EDCWB_FI_FitOK()]   = 1
    fakeInfo[LJZ_EDCWB_FI_NROI()]    = 80

    Duplicate/O w, fakeFit, fakeRes
    fakeFit = 0
    fakeRes = 0

    Variable rcFit = LJZ_EDCWB_SaveFitRecord(w, fakeCoef, fakeSigma, fakeInfo, fakeFit, fakeRes)
    name = "SaveFitRecord"
    if (rcFit == 0 && LJZ_EDCWB_HasFitRecord(w) == 1 && LJZ_EDCWB_ReadFitOK(w) == 1)
        Print name, "PASS"
        nPass += 1
    else
        Print name, "FAIL: rc =", rcFit
        nFail += 1
    endif

    // --- delete everything ---
    LJZ_EDCWB_DeleteAllPersistent(w)
    name = "DeleteAllPersistent"
    if (LJZ_EDCWB_HasEditState(w) == 0 && LJZ_EDCWB_HasFitRecord(w) == 0)
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
