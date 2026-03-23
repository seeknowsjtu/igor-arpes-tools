#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  LJZ_MDCWB Part 1 : Core + Result Record
//  只负责：
//    1) package runtime state
//    2) per-wave standard fit record read/write
//
//  本部分不负责：
//    - panel / callbacks
//    - fit engine
//    - export
//    - model bank
//    - fitmeta 文本主存储
// ============================================================================


// ============================================================================
//  Section 0. Shared path helpers
// ============================================================================

Function/S LJZ_MDCWB_BaseDF()
    return "root:Packages:ARPES_LJZ:MDCWB"
End

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

Function LJZ_MDCWB_EnsureNumWaveLen12(w, fillVal)
    Wave w
    Variable fillVal

    Variable oldN = numpnts(w)
    if (oldN != 12)
        Redimension/N=12 w
        if (oldN < 12)
            w[oldN, 11] = fillVal
        endif
    endif
    return 0
End

Function LJZ_MDCWB_EnsureTextWaveLen12(w, fillStr)
    Wave/T w
    String fillStr

    Variable oldN = numpnts(w)
    if (oldN != 12)
        Redimension/N=12 w
        if (oldN < 12)
            w[oldN, 11] = fillStr
        endif
    endif
    return 0
End


// ============================================================================
//  Section 1. Package runtime state
// ============================================================================

Function LJZ_MDCWB_EnsureDF()
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:ARPES_LJZ
    NewDataFolder/O $(LJZ_MDCWB_BaseDF())

    LJZ_MDCWB_EnsureRuntimeState()

    return 0
End

Function LJZ_MDCWB_EnsureRuntimeState()
    String base = LJZ_MDCWB_BaseDF()

    // ---------- current target / selection ----------
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

    // ---------- current edit state ----------
    NVAR/Z eModel = $(base + ":EditModelID")
    if (!NVAR_Exists(eModel))
        Variable/G $(base + ":EditModelID") = 1
    endif

    NVAR/Z eBG = $(base + ":EditBGOrder")
    if (!NVAR_Exists(eBG))
        Variable/G $(base + ":EditBGOrder") = 2
    endif

    NVAR/Z eXLo = $(base + ":EditXLo")
    if (!NVAR_Exists(eXLo))
        Variable/G $(base + ":EditXLo") = NaN
    endif

    NVAR/Z eXHi = $(base + ":EditXHi")
    if (!NVAR_Exists(eXHi))
        Variable/G $(base + ":EditXHi") = NaN
    endif

    NVAR/Z useCsr = $(base + ":UseCursors")
    if (!NVAR_Exists(useCsr))
        Variable/G $(base + ":UseCursors") = 1
    endif

    NVAR/Z isDirty = $(base + ":Dirty")
    if (!NVAR_Exists(isDirty))
        Variable/G $(base + ":Dirty") = 1
    endif

    SVAR/Z lastErrorMsg = $(base + ":LastErrorMsg")
    if (!SVAR_Exists(lastErrorMsg))
        String/G $(base + ":LastErrorMsg") = ""
    endif

    Wave/Z wPar = $(base + ":EditPar")
    if (!WaveExists(wPar))
        Make/O/N=12 $(base + ":EditPar") = NaN
    else
        LJZ_MDCWB_EnsureNumWaveLen12(wPar, NaN)
    endif

    Wave/Z wHold = $(base + ":EditHold")
    if (!WaveExists(wHold))
        Make/O/N=12 $(base + ":EditHold") = 0
    else
        LJZ_MDCWB_EnsureNumWaveLen12(wHold, 0)
    endif

    // 这两个名字/enable 只是给后面 panel 用，Part 1 先准备好
    Wave/T/Z wPName = $(base + ":EditParName")
    if (!WaveExists(wPName))
        Make/O/T/N=12 $(base + ":EditParName") = ""
    else
        LJZ_MDCWB_EnsureTextWaveLen12(wPName, "")
    endif

    Wave/Z wPEn = $(base + ":EditParEnable")
    if (!WaveExists(wPEn))
        Make/O/N=12 $(base + ":EditParEnable") = 0
    else
        LJZ_MDCWB_EnsureNumWaveLen12(wPEn, 0)
    endif

    return 0
End


// ============================================================================
//  Section 2. Runtime state helpers
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
    SVAR lastErrorMsg = $(LJZ_MDCWB_BaseDF() + ":LastErrorMsg")
    lastErrorMsg = ""
    return 0
End

Function LJZ_MDCWB_SetLastError(msg)
    String msg
    SVAR lastErrorMsg = $(LJZ_MDCWB_BaseDF() + ":LastErrorMsg")
    lastErrorMsg = msg
    return 0
End

Function/S LJZ_MDCWB_GetLastError()
    SVAR lastErrorMsg = $(LJZ_MDCWB_BaseDF() + ":LastErrorMsg")
    return lastErrorMsg
End

Function LJZ_MDCWB_HandleGuessBuildFailure(contextStr)
    String contextStr

    // OP-FLOW HAZARD: never leave guess/preview save failures silent after an edit action.
    LJZ_MDCWB_MarkDirty(1)
    LJZ_MDCWB_SetLastError(contextStr + " Preview/guess update failed.")
    LJZ_MDCWB_RefreshCurrentRowDisplayMark()
    Beep
    DoAlert 0, LJZ_MDCWB_GetLastError()
    return 0
End

Function LJZ_MDCWB_ClearEditState()
    LJZ_MDCWB_EnsureDF()

    NVAR eModel = $(LJZ_MDCWB_BaseDF() + ":EditModelID")
    NVAR eBG    = $(LJZ_MDCWB_BaseDF() + ":EditBGOrder")
    NVAR eXLo   = $(LJZ_MDCWB_BaseDF() + ":EditXLo")
    NVAR eXHi   = $(LJZ_MDCWB_BaseDF() + ":EditXHi")

    Wave ePar   = $(LJZ_MDCWB_BaseDF() + ":EditPar")
    Wave eHold  = $(LJZ_MDCWB_BaseDF() + ":EditHold")
    Wave/T pName = $(LJZ_MDCWB_BaseDF() + ":EditParName")
    Wave pEn     = $(LJZ_MDCWB_BaseDF() + ":EditParEnable")

    eModel = 1
    eBG    = 2
    eXLo   = NaN
    eXHi   = NaN

    ePar   = NaN
    eHold  = 0
    pName  = ""
    pEn    = 0

    LJZ_MDCWB_MarkDirty(1)
    return 0
End


// ============================================================================
//  Section 3. MDC listing helpers
// ============================================================================

Function/S LJZ_MDCWB_ListMDCWaves(dfPath)
    String dfPath

    dfPath = LJZ_MDCWB_NormDFPath(dfPath)
    if (strlen(dfPath) == 0)
        return ""
    endif

    String out = ""

    // 优先按 mdc_show_0,1,2,... 顺序列
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

    // 否则扫描 1D wave 名字里含 mdc 的对象
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
    return str2num(tail)
End


// ============================================================================
//  Section 4. Per-wave standard result paths
// ============================================================================

Function/S LJZ_MDCWB_ResultGuessPath(wData)
    Wave wData
    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    return dfW + nm + "_guess"
End

Function/S LJZ_MDCWB_ResultCoefPath(wData)
    Wave wData
    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    return dfW + nm + "_fitcoef"
End

Function/S LJZ_MDCWB_ResultSigmaPath(wData)
    Wave wData
    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    return dfW + nm + "_fitsigma"
End

Function/S LJZ_MDCWB_ResultInfoPath(wData)
    Wave wData
    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    return dfW + nm + "_fitinfo"
End

Function/S LJZ_MDCWB_ResultFitPath(wData)
    Wave wData
    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    return dfW + nm + "_fit"
End

Function/S LJZ_MDCWB_ResultResPath(wData)
    Wave wData
    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    return dfW + nm + "_res"
End

Function/S LJZ_MDCWB_ResultAcceptPath(wData)
    Wave wData
    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    return dfW + nm + "_accept"
End


// ============================================================================
//  Section 5. Standard result schema helpers
// ============================================================================

// fitinfo[12] fixed layout:
// [0]  modelID
// [1]  bgOrder
// [2]  xLo
// [3]  xHi
// [4]  fitOK
// [5]  guessRMSE
// [6]  fitRMSE
// [7]  rssROI (unweighted residual sum of squares inside ROI; not Igor V_chisq)
// [8]  maxAbsRes
// [9]  nROI
// [10] fitQuitReason
// [11] fitNumIters

Function LJZ_MDCWB_InitInfoWave(infoW)
    Wave infoW
    LJZ_MDCWB_EnsureNumWaveLen12(infoW, NaN)
    return 0
End

Function/S LJZ_MDCWB_FitInfoSchemaNote()
    String txt = ""
    txt += "fitinfo[0]=modelID;"
    txt += "fitinfo[1]=bgOrder;"
    txt += "fitinfo[2]=xLo;"
    txt += "fitinfo[3]=xHi;"
    txt += "fitinfo[4]=fitOK;"
    txt += "fitinfo[5]=guessRMSE;"
    txt += "fitinfo[6]=fitRMSE;"
    // FIX: fitinfo[7] stores unweighted RSS in ROI, not Igor V_chisq.
    txt += "fitinfo[7]=rssROI_unweighted_in_ROI_not_Igor_V_chisq;"
    txt += "fitinfo[8]=maxAbsRes;"
    txt += "fitinfo[9]=nROI;"
    txt += "fitinfo[10]=fitQuitReason;"
    txt += "fitinfo[11]=fitNumIters"
    return txt
End


// ============================================================================
//  Section 6. Guess wave I/O
// ============================================================================

Function LJZ_MDCWB_SaveGuessWave(wData, guessW)
    Wave wData, guessW

    // FIX: protect SetDataFolder restoration around write helpers.
    LJZ_MDCWB_EnsureDF()

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    String localDF = RemoveEnding(dfW, ":")

    String oldDF = GetDataFolder(1)
    Variable hadError = 0

    try
        SetDataFolder $localDF
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

    String guessPath = LJZ_MDCWB_ResultGuessPath(wData)
    KillWaves/Z $guessPath

    return 0
End


// ============================================================================
//  Section 7. Fit record write
// ============================================================================

// 保存正式拟合记录：
//   - fitcoef[12]
//   - fitsigma[12]
//   - fitinfo[12]
//   - fit
//   - res
//
// 注意：
//   - accept 单独保存，不在这里改
//   - guess 单独用 SaveGuessWave 保存
Function LJZ_MDCWB_SaveFitRecord(wData, coefW, sigmaW, infoW, fitW, resW)
    Wave wData, coefW, infoW, fitW, resW
    Wave/Z sigmaW

    // FIX: protect SetDataFolder restoration around write helpers.
    LJZ_MDCWB_EnsureDF()

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    String localDF = RemoveEnding(dfW, ":")

    String oldDF = GetDataFolder(1)
    Variable hadError = 0
    Variable replaceStarted = 0

    try
        SetDataFolder $localDF

        // ROBUST: clear stale temp/backup waves before atomic record replace.
        KillWaves/Z $(nm + "_fitcoef__tmp"), $(nm + "_fitsigma__tmp"), $(nm + "_fitinfo__tmp"), $(nm + "_fit__tmp"), $(nm + "_res__tmp")
        KillWaves/Z $(nm + "_fitcoef__bak"), $(nm + "_fitsigma__bak"), $(nm + "_fitinfo__bak"), $(nm + "_fit__bak"), $(nm + "_res__bak")

        // ---------- fitcoef temp ----------
        Duplicate/O coefW, $(nm + "_fitcoef__tmp")
        Wave wCoefOut = $(nm + "_fitcoef__tmp")
        LJZ_MDCWB_EnsureNumWaveLen12(wCoefOut, NaN)

        // ---------- fitsigma temp ----------
        if (WaveExists(sigmaW))
            Duplicate/O sigmaW, $(nm + "_fitsigma__tmp")
        else
            Make/O/N=12 $(nm + "_fitsigma__tmp") = NaN
        endif
        Wave wSigmaOut = $(nm + "_fitsigma__tmp")
        LJZ_MDCWB_EnsureNumWaveLen12(wSigmaOut, NaN)

        // ---------- fitinfo temp ----------
        Duplicate/O infoW, $(nm + "_fitinfo__tmp")
        Wave wInfoOut = $(nm + "_fitinfo__tmp")
        LJZ_MDCWB_InitInfoWave(wInfoOut)

        Note/K wInfoOut
        Note wInfoOut, LJZ_MDCWB_FitInfoSchemaNote()

        // ---------- fit / res temp ----------
        Duplicate/O fitW, $(nm + "_fit__tmp")
        Duplicate/O resW, $(nm + "_res__tmp")

        // ROBUST: snapshot old official record before multi-wave replace.
        Wave/Z oldCoef = $(nm + "_fitcoef")
        Wave/Z oldSigma = $(nm + "_fitsigma")
        Wave/Z oldInfo = $(nm + "_fitinfo")
        Wave/Z oldFit = $(nm + "_fit")
        Wave/Z oldRes = $(nm + "_res")
        Variable hadOldCoef = WaveExists(oldCoef)
        Variable hadOldSigma = WaveExists(oldSigma)
        Variable hadOldInfo = WaveExists(oldInfo)
        Variable hadOldFit = WaveExists(oldFit)
        Variable hadOldRes = WaveExists(oldRes)

        if (hadOldCoef)
            Duplicate/O oldCoef, $(nm + "_fitcoef__bak")
        endif
        if (hadOldSigma)
            Duplicate/O oldSigma, $(nm + "_fitsigma__bak")
        endif
        if (hadOldInfo)
            Duplicate/O oldInfo, $(nm + "_fitinfo__bak")
        endif
        if (hadOldFit)
            Duplicate/O oldFit, $(nm + "_fit__bak")
        endif
        if (hadOldRes)
            Duplicate/O oldRes, $(nm + "_res__bak")
        endif

        replaceStarted = 1

        Duplicate/O wCoefOut, $(nm + "_fitcoef")
        Duplicate/O wSigmaOut, $(nm + "_fitsigma")
        Duplicate/O wInfoOut, $(nm + "_fitinfo")
        Duplicate/O $(nm + "_fit__tmp"), $(nm + "_fit")
        Duplicate/O $(nm + "_res__tmp"), $(nm + "_res")
    catch
        hadError = 1
    endtry

    if (hadError || GetRTError(1) != 0)
        SetDataFolder $localDF
        if (replaceStarted)
            // ROBUST: restore full old record when any stage of the atomic replace fails.
            Wave/Z bakCoef = $(nm + "_fitcoef__bak")
            Wave/Z bakSigma = $(nm + "_fitsigma__bak")
            Wave/Z bakInfo = $(nm + "_fitinfo__bak")
            Wave/Z bakFit = $(nm + "_fit__bak")
            Wave/Z bakRes = $(nm + "_res__bak")

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

        KillWaves/Z $(nm + "_fitcoef__tmp"), $(nm + "_fitsigma__tmp"), $(nm + "_fitinfo__tmp"), $(nm + "_fit__tmp"), $(nm + "_res__tmp")
        KillWaves/Z $(nm + "_fitcoef__bak"), $(nm + "_fitsigma__bak"), $(nm + "_fitinfo__bak"), $(nm + "_fit__bak"), $(nm + "_res__bak")
        SetDataFolder $oldDF
        return -1
    endif

    SetDataFolder $localDF
    KillWaves/Z $(nm + "_fitcoef__tmp"), $(nm + "_fitsigma__tmp"), $(nm + "_fitinfo__tmp"), $(nm + "_fit__tmp"), $(nm + "_res__tmp")
    KillWaves/Z $(nm + "_fitcoef__bak"), $(nm + "_fitsigma__bak"), $(nm + "_fitinfo__bak"), $(nm + "_fit__bak"), $(nm + "_res__bak")
    SetDataFolder $oldDF

    return 0
End


// ============================================================================
//  Section 8. Fit record existence / validity
// ============================================================================

Function LJZ_MDCWB_HasFitRecord(wData)
    Wave wData

    Wave/Z coef = $(LJZ_MDCWB_ResultCoefPath(wData))
    Wave/Z sigma = $(LJZ_MDCWB_ResultSigmaPath(wData))
    Wave/Z info = $(LJZ_MDCWB_ResultInfoPath(wData))
    Wave/Z fit  = $(LJZ_MDCWB_ResultFitPath(wData))
    Wave/Z res  = $(LJZ_MDCWB_ResultResPath(wData))

    if (!WaveExists(coef))
        return 0
    endif
    if (!WaveExists(sigma))
        return 0
    endif
    if (!WaveExists(info))
        return 0
    endif
    if (!WaveExists(fit))
        return 0
    endif
    if (!WaveExists(res))
        return 0
    endif

    if (numpnts(coef) < 12)
        return 0
    endif
    if (numpnts(sigma) < 12)
        return 0
    endif
    if (numpnts(info) < 12)
        return 0
    endif
    if (numpnts(fit) != numpnts(wData))
        return 0
    endif
    if (numpnts(res) != numpnts(wData))
        return 0
    endif
    // ROBUST: reject partially written fitinfo metadata as invalid record.
    if (numtype(info[0]) != 0 || numtype(info[1]) != 0 || numtype(info[2]) != 0 || numtype(info[3]) != 0 || numtype(info[4]) != 0 || numtype(info[9]) != 0)
        return 0
    endif
    if (info[9] <= 0)
        return 0
    endif

    return 1
End

Function LJZ_MDCWB_ReadFitOK(wData)
    Wave wData

    Wave/Z info = $(LJZ_MDCWB_ResultInfoPath(wData))
    if (!WaveExists(info) || numpnts(info) < 5)
        return 0
    endif

    if (numtype(info[4]) != 0)
        return 0
    endif

    if (info[4] > 0.5)
        return 1
    endif

    return 0
End


// ============================================================================
//  Section 9. Load persistent fit record -> current edit state
// ============================================================================

// 只从标准结果记录恢复“核心编辑态”：
//   EditModelID / EditBGOrder / EditXLo / EditXHi / EditPar
//
// 注意：
//   - 不恢复 EditHold
//   - 不依赖 fitmeta 文本
//   - 成功返回 1，失败返回 0
Function LJZ_MDCWB_LoadFitRecordToEditState(wData)
    Wave wData

    LJZ_MDCWB_EnsureDF()

    if (!LJZ_MDCWB_HasFitRecord(wData))
        return 0
    endif

    Wave coef = $(LJZ_MDCWB_ResultCoefPath(wData))
    Wave info = $(LJZ_MDCWB_ResultInfoPath(wData))

    if (numpnts(coef) < 12 || numpnts(info) < 12)
        return 0
    endif

    NVAR eModel = $(LJZ_MDCWB_BaseDF() + ":EditModelID")
    NVAR eBG    = $(LJZ_MDCWB_BaseDF() + ":EditBGOrder")
    NVAR eXLo   = $(LJZ_MDCWB_BaseDF() + ":EditXLo")
    NVAR eXHi   = $(LJZ_MDCWB_BaseDF() + ":EditXHi")
    Wave ePar   = $(LJZ_MDCWB_BaseDF() + ":EditPar")

    if (numtype(info[0]) == 0)
        eModel = info[0]
    endif
    if (numtype(info[1]) == 0)
        eBG = info[1]
    endif
    if (numtype(info[2]) == 0)
        eXLo = info[2]
    endif
    if (numtype(info[3]) == 0)
        eXHi = info[3]
    endif

    ePar = coef[p]
    LJZ_MDCWB_EnsureNumWaveLen12(ePar, NaN)

    return 1
End


// ============================================================================
//  Section 10. Accept state read/write
// ============================================================================

Function LJZ_MDCWB_ReadAcceptState(wData)
    Wave wData

    Wave/Z wAcc = $(LJZ_MDCWB_ResultAcceptPath(wData))
    if (!WaveExists(wAcc))
        return 0
    endif

    if (numpnts(wAcc) < 1)
        return 0
    endif

    if (numtype(wAcc[0]) != 0)
        return 0
    endif

    return wAcc[0]
End

Function LJZ_MDCWB_WriteAcceptState(wData, newState)
    Wave wData
    Variable newState

    // FIX: protect SetDataFolder restoration around write helpers.
    LJZ_MDCWB_EnsureDF()

    if (newState > 0)
        newState = 1
    elseif (newState < 0)
        newState = -1
    else
        newState = 0
    endif

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    String localDF = RemoveEnding(dfW, ":")

    String oldDF = GetDataFolder(1)
    Variable hadError = 0

    try
        SetDataFolder $localDF

        Make/O/N=1 $(nm + "_accept")
        Wave wAcc = $(nm + "_accept")
        wAcc[0] = newState

        Note/K wAcc
        Note wAcc, "accept[0]: 1=accepted; 0=unchecked; -1=rejected"
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
//  Section 11. Optional cleanup helpers
// ============================================================================

Function LJZ_MDCWB_DeleteFitRecord(wData)
    Wave wData

    KillWaves/Z $(LJZ_MDCWB_ResultCoefPath(wData))
    KillWaves/Z $(LJZ_MDCWB_ResultSigmaPath(wData))
    KillWaves/Z $(LJZ_MDCWB_ResultInfoPath(wData))
    KillWaves/Z $(LJZ_MDCWB_ResultFitPath(wData))
    KillWaves/Z $(LJZ_MDCWB_ResultResPath(wData))

    return 0
End

Function LJZ_MDCWB_DeleteAllRecordWaves(wData)
    Wave wData

    LJZ_MDCWB_DeleteGuessWave(wData)
    LJZ_MDCWB_DeleteFitRecord(wData)
    KillWaves/Z $(LJZ_MDCWB_ResultAcceptPath(wData))

    return 0
End


// ============================================================================
//  LJZ_MDCWB Part 2 : Model + Fit Engine
//
//  依赖：
//    - Part 1 : Core + Result Record
//    - 外部模型函数：
//         one_pv_ljz
//         two_pv_ljz
//         asympv_plus_pv_ljz
//
//  本部分负责：
//    - model / bg metadata
//    - edit parameter layout
//    - default hold policy
//    - sanitize / auto init
//    - load current wave record or auto init
//    - build guess
//    - run fit and save standard result record
// ============================================================================


// ============================================================================
//  Section 1. Model metadata
// ============================================================================

Function LJZ_MDCWB_ClampModelID(modelIDInput)
    Variable modelIDInput

    Variable modelIDClamped = round(modelIDInput)
    if (modelIDClamped < 1)
        modelIDClamped = 1
    endif
    if (modelIDClamped > 5)
        modelIDClamped = 5
    endif

    return modelIDClamped
End

Function LJZ_MDCWB_ClampBGOrder(bgOrderInput)
    Variable bgOrderInput

    Variable bgOrderClamped = round(bgOrderInput)
    if (bgOrderClamped < 0)
        bgOrderClamped = 0
    endif
    if (bgOrderClamped > 2)
        bgOrderClamped = 2
    endif

    return bgOrderClamped
End

Function LJZ_MDCWB_ModelNPar(modelIDInput)
    Variable modelIDInput

    Variable modelIDLocal = LJZ_MDCWB_ClampModelID(modelIDInput)

    if (modelIDLocal == 2 || modelIDLocal == 5)
        return 12
    endif

    return 8
End

Function/S LJZ_MDCWB_ModelName(modelIDInput)
    Variable modelIDInput

    Variable modelIDLocal = LJZ_MDCWB_ClampModelID(modelIDInput)

    if (modelIDLocal == 1)
        return "1PV"
    elseif (modelIDLocal == 2)
        return "2PV"
    elseif (modelIDLocal == 3)
        return "1Lor"
    elseif (modelIDLocal == 4)
        return "1Gau"
    elseif (modelIDLocal == 5)
        return "AsymPV+PV"
    endif

    return "Unknown"
End

Function/S LJZ_MDCWB_BGName(bgOrderInput)
    Variable bgOrderInput

    Variable bgOrderLocal = LJZ_MDCWB_ClampBGOrder(bgOrderInput)

    if (bgOrderLocal == 0)
        return "Const"
    elseif (bgOrderLocal == 1)
        return "Linear"
    elseif (bgOrderLocal == 2)
        return "Quad"
    endif

    return "Unknown"
End


// ============================================================================
//  Section 2. Edit-state layout helpers
// ============================================================================

Function LJZ_MDCWB_SetParamLayout()
    LJZ_MDCWB_EnsureDF()

    NVAR editModelID = $(LJZ_MDCWB_BaseDF() + ":EditModelID")
    NVAR editBGOrder = $(LJZ_MDCWB_BaseDF() + ":EditBGOrder")

    Wave/T editParNameWave = $(LJZ_MDCWB_BaseDF() + ":EditParName")
    Wave   editParEnableWave = $(LJZ_MDCWB_BaseDF() + ":EditParEnable")

    Variable modelIDLocal = LJZ_MDCWB_ClampModelID(editModelID)
    Variable bgOrderLocal = LJZ_MDCWB_ClampBGOrder(editBGOrder)

    editModelID = modelIDLocal
    editBGOrder = bgOrderLocal

    editParNameWave = ""
    editParEnableWave = 0

    // background slots always 0,1,2
    editParNameWave[0] = "c0 (bg const)"
    editParNameWave[1] = "c1 (bg linear)"
    editParNameWave[2] = "c2 (bg quad)"

    editParEnableWave[0] = 1
    editParEnableWave[1] = 1
    editParEnableWave[2] = 1

    if (modelIDLocal == 1 || modelIDLocal == 3 || modelIDLocal == 4)
        editParNameWave[3] = "H1"
        editParNameWave[4] = "x1"
        editParNameWave[5] = "w1_free"
        editParNameWave[6] = "eta1"
        editParNameWave[7] = "resH"

        editParEnableWave[3] = 1
        editParEnableWave[4] = 1
        editParEnableWave[5] = 1
        editParEnableWave[6] = 1
        editParEnableWave[7] = 1

    elseif (modelIDLocal == 2)
        editParNameWave[3]  = "H1"
        editParNameWave[4]  = "x1"
        editParNameWave[5]  = "w1_free"
        editParNameWave[6]  = "eta1"
        editParNameWave[7]  = "H2"
        editParNameWave[8]  = "x2"
        editParNameWave[9]  = "w2_free"
        editParNameWave[10] = "eta2"
        editParNameWave[11] = "resH"

        editParEnableWave[3,11] = 1

    elseif (modelIDLocal == 5)
        editParNameWave[3]  = "H_asym"
        editParNameWave[4]  = "x_asym"
        editParNameWave[5]  = "wL_free"
        editParNameWave[6]  = "wR_free"
        editParNameWave[7]  = "H_sym"
        editParNameWave[8]  = "x_sym"
        editParNameWave[9]  = "w_sym_free"
        editParNameWave[10] = "eta_shared"
        editParNameWave[11] = "resH"

        editParEnableWave[3,11] = 1
    endif

    return 0
End

Function LJZ_MDCWB_ApplyModelSpecialsToWave(paramWave, holdWave, modelIDInput)
    Wave paramWave, holdWave
    Variable modelIDInput

    Variable modelIDLocal = LJZ_MDCWB_ClampModelID(modelIDInput)

    if (modelIDLocal == 3)
        paramWave[6] = 1
        holdWave[6]  = 1
    elseif (modelIDLocal == 4)
        paramWave[6] = 0
        holdWave[6]  = 1
    endif

    return 0
End

// doFullReset = 1 : all holds reset to 0, then apply defaults
// doFullReset = 0 : only managed slots are updated
Function LJZ_MDCWB_ApplyDefaultHoldPolicy(doFullReset)
    Variable doFullReset

    LJZ_MDCWB_EnsureDF()

    NVAR editModelID = $(LJZ_MDCWB_BaseDF() + ":EditModelID")
    NVAR editBGOrder = $(LJZ_MDCWB_BaseDF() + ":EditBGOrder")
    Wave editHoldWave = $(LJZ_MDCWB_BaseDF() + ":EditHold")
    Wave editParWave  = $(LJZ_MDCWB_BaseDF() + ":EditPar")

    Variable modelIDLocal = LJZ_MDCWB_ClampModelID(editModelID)
    Variable bgOrderLocal = LJZ_MDCWB_ClampBGOrder(editBGOrder)

    if (doFullReset)
        editHoldWave = 0
    endif

    // background defaults
    editHoldWave[0] = 0
    if (bgOrderLocal == 0)
        editHoldWave[1] = 1
        editHoldWave[2] = 1
    elseif (bgOrderLocal == 1)
        editHoldWave[1] = 0
        editHoldWave[2] = 1
    else
        editHoldWave[1] = 0
        editHoldWave[2] = 0
    endif

    // resolution default hold
    if (modelIDLocal == 2 || modelIDLocal == 5)
        editHoldWave[11] = 1
    else
        editHoldWave[7] = 1
    endif
// eta default hold for multi-peak models
if (modelIDLocal == 2)
    editHoldWave[6]  = 1      // eta1
    editHoldWave[10] = 1      // eta2
elseif (modelIDLocal == 5)
    editHoldWave[10] = 1      // eta_shared
endif
    // fixed eta for Lor/Gau
    LJZ_MDCWB_ApplyModelSpecialsToWave(editParWave, editHoldWave, modelIDLocal)

    return 0
End


// ============================================================================
//  Section 3. Parameter sanitation
// ============================================================================

Function LJZ_MDCWB_SanitizeParamWave(paramWave, modelIDInput)
    Wave paramWave
    Variable modelIDInput

    Variable modelIDLocal = LJZ_MDCWB_ClampModelID(modelIDInput)

    Variable minWidthValue = 1e-4
    Variable minResValue   = 1e-4
    Variable minSepValue   = 1e-4

    if (modelIDLocal == 2)
        paramWave[5]  = max(minWidthValue, abs(paramWave[5]))
        paramWave[6]  = min(1, max(0, paramWave[6]))
        paramWave[9]  = max(minWidthValue, abs(paramWave[9]))
        paramWave[10] = min(1, max(0, paramWave[10]))
        paramWave[11] = max(minResValue, abs(paramWave[11]))

        if (numtype(paramWave[4]) == 0 && numtype(paramWave[8]) == 0)
            if (paramWave[8] <= paramWave[4] + minSepValue)
                paramWave[8] = paramWave[4] + minSepValue
            endif
        endif

    elseif (modelIDLocal == 5)
        paramWave[5]  = max(minWidthValue, abs(paramWave[5]))
        paramWave[6]  = max(minWidthValue, abs(paramWave[6]))
        paramWave[9]  = max(minWidthValue, abs(paramWave[9]))
        paramWave[10] = min(1, max(0, paramWave[10]))
        paramWave[11] = max(minResValue, abs(paramWave[11]))

        if (numtype(paramWave[4]) == 0 && numtype(paramWave[8]) == 0)
            if (paramWave[8] <= paramWave[4] + minSepValue)
                paramWave[8] = paramWave[4] + minSepValue
            endif
        endif

    else
        paramWave[5] = max(minWidthValue, abs(paramWave[5]))
        paramWave[6] = min(1, max(0, paramWave[6]))
        paramWave[7] = max(minResValue, abs(paramWave[7]))

        if (modelIDLocal == 3)
            paramWave[6] = 1
        elseif (modelIDLocal == 4)
            paramWave[6] = 0
        endif
    endif

    return 0
End

Function LJZ_MDCWB_SanitizeCurrentEditPar()
    LJZ_MDCWB_EnsureDF()

    NVAR editModelID = $(LJZ_MDCWB_BaseDF() + ":EditModelID")
    Wave editParWave  = $(LJZ_MDCWB_BaseDF() + ":EditPar")
    Wave editHoldWave = $(LJZ_MDCWB_BaseDF() + ":EditHold")

    LJZ_MDCWB_SanitizeParamWave(editParWave, editModelID)
    LJZ_MDCWB_ApplyModelSpecialsToWave(editParWave, editHoldWave, editModelID)

    return 0
End


// ============================================================================
//  Section 4. ROI + metric helpers
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
        Variable swapIndex = roiIndexLo
        roiIndexLo = roiIndexHi
        roiIndexHi = swapIndex
    endif

    return 0
End

// FIX: count only finite data points inside ROI when validating fit readiness.
Function LJZ_MDCWB_CountFinitePointsInROI(dataWave, roiXLoInput, roiXHiInput)
    Wave dataWave
    Variable roiXLoInput, roiXHiInput

    Variable roiIndexLo, roiIndexHi
    LJZ_MDCWB_GetROIIndexRange(dataWave, roiXLoInput, roiXHiInput, roiIndexLo, roiIndexHi)

    Variable finiteCount = 0
    Variable pointIndex
    for (pointIndex = roiIndexLo; pointIndex <= roiIndexHi; pointIndex += 1)
        if (numtype(dataWave[pointIndex]) == 0)
            finiteCount += 1
        endif
    endfor

    return finiteCount
End

Function LJZ_MDCWB_ComputeFitMetrics(dataWave, guessWave, fitWave, resWave, roiXLoInput, roiXHiInput, guessRMSEOut, fitRMSEOut, rssROIOut, maxAbsResOut, nROIOut)
    Wave dataWave, guessWave, fitWave, resWave
    Variable roiXLoInput, roiXHiInput
    Variable &guessRMSEOut, &fitRMSEOut, &rssROIOut, &maxAbsResOut, &nROIOut

    Variable roiIndexLo, roiIndexHi
    LJZ_MDCWB_GetROIIndexRange(dataWave, roiXLoInput, roiXHiInput, roiIndexLo, roiIndexHi)

    Variable dataIndex
    Variable guessCount = 0
    Variable fitCount = 0
    Variable guessSqSum = 0
    Variable fitSqSum = 0
    Variable maxAbsLocal = NaN
    Variable dataValue, guessValue, fitValue, resValue, absResValue

    guessRMSEOut = NaN
    fitRMSEOut = NaN
    rssROIOut = NaN
    maxAbsResOut = NaN
    nROIOut = 0

    for (dataIndex = roiIndexLo; dataIndex <= roiIndexHi; dataIndex += 1)
        dataValue = dataWave[dataIndex]
        guessValue = guessWave[dataIndex]
        fitValue = fitWave[dataIndex]
        resValue = resWave[dataIndex]

        if (numtype(dataValue) == 0 && numtype(guessValue) == 0)
            guessSqSum += (dataValue - guessValue)^2
            guessCount += 1
        endif

        if (numtype(dataValue) == 0 && numtype(fitValue) == 0 && numtype(resValue) == 0)
            absResValue = abs(resValue)
            fitSqSum += resValue^2
            fitCount += 1
            if (numtype(maxAbsLocal) != 0 || absResValue > maxAbsLocal)
                maxAbsLocal = absResValue
            endif
        endif
    endfor

    // ROBUST: metrics must only count finite valid samples inside ROI.
    if (guessCount <= 0 || fitCount <= 0)
        return -1
    endif

    guessRMSEOut = sqrt(guessSqSum / guessCount)
    fitRMSEOut = sqrt(fitSqSum / fitCount)
    // FIX: this is unweighted RSS inside ROI, not true chi-square.
    rssROIOut  = fitSqSum
    maxAbsResOut = maxAbsLocal
    nROIOut = fitCount

    return 0
End

Function LJZ_MDCWB_BuildInfoWave(infoWave, modelIDInput, bgOrderInput, roiXLoInput, roiXHiInput, fitOKInput, guessRMSEInput, fitRMSEInput, rssROIInput, maxAbsResInput, nROIInput)
    Wave infoWave
    Variable modelIDInput, bgOrderInput, roiXLoInput, roiXHiInput
    Variable fitOKInput, guessRMSEInput, fitRMSEInput, rssROIInput, maxAbsResInput, nROIInput

    LJZ_MDCWB_InitInfoWave(infoWave)

    infoWave[0] = LJZ_MDCWB_ClampModelID(modelIDInput)
    infoWave[1] = LJZ_MDCWB_ClampBGOrder(bgOrderInput)
    infoWave[2] = roiXLoInput
    infoWave[3] = roiXHiInput
    infoWave[4] = fitOKInput
    infoWave[5] = guessRMSEInput
    infoWave[6] = fitRMSEInput
    // FIX: fitinfo[7] remains the existing slot, but now documented as RSS in ROI.
    infoWave[7] = rssROIInput
    infoWave[8] = maxAbsResInput
    infoWave[9] = nROIInput
    infoWave[10] = NaN
    infoWave[11] = NaN

    return 0
End


// ============================================================================
//  Section 5. Auto init from data
// ============================================================================

Function LJZ_MDCWB_AutoInitFromData(dataWave)
    Wave dataWave

    LJZ_MDCWB_EnsureDF()

    NVAR editXLo = $(LJZ_MDCWB_BaseDF() + ":EditXLo")
    NVAR editXHi = $(LJZ_MDCWB_BaseDF() + ":EditXHi")
    NVAR editModelID = $(LJZ_MDCWB_BaseDF() + ":EditModelID")

    Wave editParWave  = $(LJZ_MDCWB_BaseDF() + ":EditPar")
    Wave editHoldWave = $(LJZ_MDCWB_BaseDF() + ":EditHold")

    Variable modelIDLocal = LJZ_MDCWB_ClampModelID(editModelID)

    Variable defaultResH = 0
    NVAR/Z globalResH = root:ARPES_LJZ:MDCFit:Res
    if (NVAR_Exists(globalResH) && numtype(globalResH) == 0)
        defaultResH = globalResH
    endif

    Variable pointCount = numpnts(dataWave)
    if (pointCount <= 5)
        return -1
    endif

    Variable axisX0 = DimOffset(dataWave, 0)
    Variable axisDX = DimDelta(dataWave, 0)
    if (numtype(axisDX) != 0 || axisDX == 0)
        axisDX = 1
    endif

    Variable fullXMin = axisX0
    Variable fullXMax = axisX0 + axisDX * (pointCount - 1)
    Variable editXLoLocal = editXLo
    Variable editXHiLocal = editXHi

    if (numtype(editXLoLocal) != 0)
        editXLoLocal = fullXMin
    endif
    if (numtype(editXHiLocal) != 0)
        editXHiLocal = fullXMax
    endif

    Variable roiIndexLo, roiIndexHi
    LJZ_MDCWB_GetROIIndexRange(dataWave, editXLoLocal, editXHiLocal, roiIndexLo, roiIndexHi)

    if ((roiIndexHi - roiIndexLo) < 6)
        roiIndexLo = max(0, roiIndexLo - 3)
        roiIndexHi = min(pointCount - 1, roiIndexHi + 3)
    endif

    Variable finiteROIPointCount = 0
    Variable edgeLoValue = NaN
    Variable edgeHiValue = NaN
    Variable roiScanIndex
    Variable roiScanValue
    for (roiScanIndex = roiIndexLo; roiScanIndex <= roiIndexHi; roiScanIndex += 1)
        roiScanValue = dataWave[roiScanIndex]
        if (numtype(roiScanValue) == 0)
            finiteROIPointCount += 1
            if (numtype(edgeLoValue) != 0)
                edgeLoValue = roiScanValue
            endif
            edgeHiValue = roiScanValue
        endif
    endfor
    // ROBUST: abort auto init when ROI finite support is too sparse for stable seed stats.
    if (finiteROIPointCount < 3)
        return -1
    endif

    Make/FREE/N=(roiIndexHi-roiIndexLo+1) roiDataWave = dataWave[roiIndexLo+p]
    SetScale/P x, axisX0 + roiIndexLo*axisDX, axisDX, roiDataWave

    WaveStats/Q/M=1 roiDataWave

    Variable segMinY = V_min
    Variable segMaxY = V_max
    Variable segPeakX = V_maxLoc

    // ROBUST: refuse to seed edit parameters from non-finite stats or edge background samples.
    if (numtype(segMinY) != 0 || numtype(segMaxY) != 0 || numtype(segPeakX) != 0)
        return -1
    endif
    if (numtype(edgeLoValue) != 0 || numtype(edgeHiValue) != 0)
        return -1
    endif

    Make/FREE/N=12 editParWorkingWave = NaN

    // background
    editParWorkingWave[0] = (segMinY + edgeLoValue + edgeHiValue) / 3
    editParWorkingWave[1] = 0
    editParWorkingWave[2] = 0

    if (modelIDLocal == 2)
        Variable initX1 = axisX0 + (roiIndexLo + round((roiIndexHi-roiIndexLo)*0.33))*axisDX
        Variable initX2 = axisX0 + (roiIndexLo + round((roiIndexHi-roiIndexLo)*0.67))*axisDX

        editParWorkingWave[3]  = max(1e-6, segMaxY - segMinY)
        editParWorkingWave[4]  = initX1
        editParWorkingWave[5]  = max(1e-6, 3*abs(axisDX))
        editParWorkingWave[6]  = 0.8

        editParWorkingWave[7]  = max(1e-6, segMaxY - segMinY)
        editParWorkingWave[8]  = initX2
        editParWorkingWave[9]  = max(1e-6, 3*abs(axisDX))
        editParWorkingWave[10] = 0.8

        editParWorkingWave[11] = max(defaultResH, 1e-6)

    elseif (modelIDLocal == 5)
        Variable initXAsym = axisX0 + (roiIndexLo + round((roiIndexHi-roiIndexLo)*0.40))*axisDX
        Variable initXSym  = axisX0 + (roiIndexLo + round((roiIndexHi-roiIndexLo)*0.72))*axisDX

        editParWorkingWave[3]  = max(1e-6, 0.8*(segMaxY - segMinY))
        editParWorkingWave[4]  = initXAsym
        editParWorkingWave[5]  = max(1e-6, 2*abs(axisDX))
        editParWorkingWave[6]  = max(1e-6, 4*abs(axisDX))

        editParWorkingWave[7]  = max(1e-6, 0.5*(segMaxY - segMinY))
        editParWorkingWave[8]  = initXSym
        editParWorkingWave[9]  = max(1e-6, 3*abs(axisDX))
        editParWorkingWave[10] = 0.8

        editParWorkingWave[11] = max(defaultResH, 1e-6)

    else
        editParWorkingWave[3] = max(1e-6, segMaxY - segMinY)
        editParWorkingWave[4] = segPeakX
        editParWorkingWave[5] = max(1e-6, 3*abs(axisDX))
        editParWorkingWave[6] = 0.8
        editParWorkingWave[7] = max(defaultResH, 1e-6)
    endif

    editXLo = editXLoLocal
    editXHi = editXHiLocal
    editParWave = editParWorkingWave[p]
    LJZ_MDCWB_ApplyDefaultHoldPolicy(1)
    LJZ_MDCWB_SanitizeCurrentEditPar()
    LJZ_MDCWB_SetParamLayout()
    LJZ_MDCWB_MarkDirty(1)

    return 0
End


// ============================================================================
//  Section 6. Current-wave load / model change / bg change
// ============================================================================

// 规则：
//   1) 若当前波有标准拟合记录 -> 载入 fitcoef + fitinfo 到 edit state
//   2) hold 不从持久层恢复，只套当前默认 hold 规则
//   3) 若没有正式拟合记录 -> 从数据 auto init
Function LJZ_MDCWB_LoadCurrentWaveToEditState()
    LJZ_MDCWB_EnsureDF()

    SVAR currentWavePath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
    if (strlen(currentWavePath) == 0)
        return -1
    endif

    Wave/Z dataWave = $currentWavePath
    if (!WaveExists(dataWave))
        LJZ_MDCWB_SetLastError("No current wave selected.")
        return -1
    endif

    Variable didLoadRecord = LJZ_MDCWB_LoadFitRecordToEditState(dataWave)

    LJZ_MDCWB_SetParamLayout()
    LJZ_MDCWB_ApplyDefaultHoldPolicy(1)
    LJZ_MDCWB_SanitizeCurrentEditPar()

    if (didLoadRecord)
        if (LJZ_MDCWB_ReadFitOK(dataWave))
            LJZ_MDCWB_MarkDirty(0)
        else
            LJZ_MDCWB_MarkDirty(1)
        endif
        return 0
    endif

    if (LJZ_MDCWB_AutoInitFromData(dataWave) != 0)
        // ROBUST: clear edit state when auto init fails so callers do not see partial state.
        LJZ_MDCWB_ClearEditState()
        return -1
    endif

    LJZ_MDCWB_MarkDirty(1)
    return 0
End

// 新架构下：切模型 = 不保留“旧模型临时猜值”
// 直接对当前波重新 auto init
Function LJZ_MDCWB_ChangeModel(newModelIDInput)
    Variable newModelIDInput

    LJZ_MDCWB_EnsureDF()

    NVAR editModelID = $(LJZ_MDCWB_BaseDF() + ":EditModelID")
    Variable newModelIDLocal = LJZ_MDCWB_ClampModelID(newModelIDInput)

    if (editModelID == newModelIDLocal)
        return 0
    endif

    Variable oldModelID = editModelID
    NVAR editBGOrder = $(LJZ_MDCWB_BaseDF() + ":EditBGOrder")
    NVAR editXLo = $(LJZ_MDCWB_BaseDF() + ":EditXLo")
    NVAR editXHi = $(LJZ_MDCWB_BaseDF() + ":EditXHi")
    Wave editParWave = $(LJZ_MDCWB_BaseDF() + ":EditPar")
    Wave editHoldWave = $(LJZ_MDCWB_BaseDF() + ":EditHold")
    Variable oldBGOrder = editBGOrder
    Variable oldXLo = editXLo
    Variable oldXHi = editXHi
    Variable oldDirtyState = LJZ_MDCWB_IsDirty()
    Make/FREE/N=12 oldEditParWave = editParWave[p]
    Make/FREE/N=12 oldEditHoldWave = editHoldWave[p]

    editModelID = newModelIDLocal
    LJZ_MDCWB_SetParamLayout()

    SVAR currentWavePath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
    if (strlen(currentWavePath) > 0)
        Wave/Z dataWave = $currentWavePath
        if (WaveExists(dataWave))
            if (LJZ_MDCWB_AutoInitFromData(dataWave) != 0)
                // ROBUST: restore previous edit state when model-switch auto init fails.
                editModelID = oldModelID
                editBGOrder = oldBGOrder
                editXLo = oldXLo
                editXHi = oldXHi
                editParWave = oldEditParWave[p]
                editHoldWave = oldEditHoldWave[p]
                LJZ_MDCWB_SetParamLayout()
                LJZ_MDCWB_MarkDirty(oldDirtyState)
                return -1
            endif
            return 0
        endif
    endif

    LJZ_MDCWB_ApplyDefaultHoldPolicy(1)
    LJZ_MDCWB_SanitizeCurrentEditPar()
    LJZ_MDCWB_MarkDirty(1)

    return 0
End

Function LJZ_MDCWB_ChangeBG(newBGOrderInput)
    Variable newBGOrderInput

    LJZ_MDCWB_EnsureDF()

    NVAR editBGOrder = $(LJZ_MDCWB_BaseDF() + ":EditBGOrder")
    editBGOrder = LJZ_MDCWB_ClampBGOrder(newBGOrderInput)

    LJZ_MDCWB_SetParamLayout()
    LJZ_MDCWB_ApplyDefaultHoldPolicy(0)
    LJZ_MDCWB_SanitizeCurrentEditPar()
    LJZ_MDCWB_MarkDirty(1)

    return 0
End


// ============================================================================
//  Section 7. Guess generation
// ============================================================================

Function LJZ_MDCWB_BuildGuessWaveFromCurrentState(dataWave)
    Wave dataWave

    LJZ_MDCWB_EnsureDF()

    Duplicate/FREE dataWave, guessFullWave
    if (LJZ_MDCWB_FillGuessWaveFromEditState(dataWave, guessFullWave) != 0)
        return -1
    endif

    if (LJZ_MDCWB_SaveGuessWave(dataWave, guessFullWave) != 0)
        return -1
    endif
    LJZ_MDCWB_MarkDirty(1)

    return 0
End

Function LJZ_MDCWB_BuildGuessForCurrentWave()
    LJZ_MDCWB_EnsureDF()

    SVAR currentWavePath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
    if (strlen(currentWavePath) == 0)
        return -1
    endif

    Wave/Z dataWave = $currentWavePath
    if (!WaveExists(dataWave))
        LJZ_MDCWB_SetLastError("No current wave selected.")
        return -1
    endif

    return LJZ_MDCWB_BuildGuessWaveFromCurrentState(dataWave)
End

Function/S LJZ_MDCWB_PreviewGuessPath()
    return LJZ_MDCWB_BaseDF() + ":GuessPreview"
End

Function LJZ_MDCWB_FillGuessWaveFromEditState(dataWave, outGuessWave)
    Wave dataWave, outGuessWave

    LJZ_MDCWB_EnsureDF()

    NVAR editModelID = $(LJZ_MDCWB_BaseDF() + ":EditModelID")
    Wave editParWave  = $(LJZ_MDCWB_BaseDF() + ":EditPar")
    Wave editHoldWave = $(LJZ_MDCWB_BaseDF() + ":EditHold")

    Variable modelIDLocal = LJZ_MDCWB_ClampModelID(editModelID)

    Make/FREE/N=12 coefWorkingWave = editParWave[p]
    Make/FREE/N=12 holdWorkingWave = editHoldWave[p]

    LJZ_MDCWB_ApplyModelSpecialsToWave(coefWorkingWave, holdWorkingWave, modelIDLocal)
    LJZ_MDCWB_SanitizeParamWave(coefWorkingWave, modelIDLocal)

    // 保持与 dataWave 同长度同 x 标度
    Variable axisX0 = DimOffset(dataWave, 0)
    Variable axisDX = DimDelta(dataWave, 0)
    // ROBUST: guard preview/guess generation against invalid x-step at runtime.
    if (numtype(axisDX) != 0 || axisDX == 0)
        axisDX = 1
    endif
    Redimension/N=(numpnts(dataWave)) outGuessWave
    SetScale/P x, axisX0, axisDX, outGuessWave

    if (modelIDLocal == 2)
        outGuessWave = two_pv_ljz(coefWorkingWave, x)
    elseif (modelIDLocal == 5)
        outGuessWave = asympv_plus_pv_ljz(coefWorkingWave, x)
    else
        outGuessWave = one_pv_ljz(coefWorkingWave, x)
    endif

    return 0
End

Function LJZ_MDCWB_UpdatePreviewGuessWave(dataWave)
    Wave dataWave

    LJZ_MDCWB_EnsureDF()

    Variable axisX0 = DimOffset(dataWave, 0)
    Variable axisDX = DimDelta(dataWave, 0)
    // ROBUST: keep preview wave scale finite even when source axis metadata is broken.
    if (numtype(axisDX) != 0 || axisDX == 0)
        axisDX = 1
    endif

    Duplicate/O dataWave, $(LJZ_MDCWB_PreviewGuessPath())
    Wave previewGuessWave = $(LJZ_MDCWB_PreviewGuessPath())
    SetScale/P x, axisX0, axisDX, previewGuessWave

    return LJZ_MDCWB_FillGuessWaveFromEditState(dataWave, previewGuessWave)
End
// ============================================================================
//  Section 8. Fit helpers
// ============================================================================

Function LJZ_MDCWB_CopyFitResultToEditState(coefWorkingWave, holdWorkingWave, paramCountInput)
    Wave coefWorkingWave, holdWorkingWave
    Variable paramCountInput

    LJZ_MDCWB_EnsureDF()

    Wave editParWave  = $(LJZ_MDCWB_BaseDF() + ":EditPar")
    Wave editHoldWave = $(LJZ_MDCWB_BaseDF() + ":EditHold")

    editParWave = NaN
    editHoldWave = 0

    editParWave[0, paramCountInput-1]  = coefWorkingWave[p]
    editHoldWave[0, paramCountInput-1] = holdWorkingWave[p]

    return 0
End

Function LJZ_MDCWB_ValidateCoefWaveFinite(coefWave, paramCountInput)
    Wave coefWave
    Variable paramCountInput

    Variable coefIndex
    for (coefIndex = 0; coefIndex < paramCountInput; coefIndex += 1)
        if (numtype(coefWave[coefIndex]) != 0)
            return 0
        endif
    endfor

    return 1
End


// ============================================================================
//  Section 9. Run fit and save standard result record
// ============================================================================

Function LJZ_MDCWB_CommitFitForCurrentWave()
    LJZ_MDCWB_EnsureDF()
    LJZ_MDCWB_ClearLastError()

    SVAR currentWavePath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
    if (strlen(currentWavePath) == 0)
        LJZ_MDCWB_SetLastError("No current wave selected.")
        return -1
    endif

    Wave/Z dataWave = $currentWavePath
    if (!WaveExists(dataWave))
        LJZ_MDCWB_SetLastError("No current wave selected.")
        return -1
    endif

    NVAR editModelID = $(LJZ_MDCWB_BaseDF() + ":EditModelID")
    NVAR editBGOrder = $(LJZ_MDCWB_BaseDF() + ":EditBGOrder")
    NVAR editXLo = $(LJZ_MDCWB_BaseDF() + ":EditXLo")
    NVAR editXHi = $(LJZ_MDCWB_BaseDF() + ":EditXHi")

    Wave editParWave  = $(LJZ_MDCWB_BaseDF() + ":EditPar")
    Wave editHoldWave = $(LJZ_MDCWB_BaseDF() + ":EditHold")

    Variable modelIDLocal = LJZ_MDCWB_ClampModelID(editModelID)
    Variable bgOrderLocal = LJZ_MDCWB_ClampBGOrder(editBGOrder)
    Variable paramCountLocal = LJZ_MDCWB_ModelNPar(modelIDLocal)

    Variable dataPointCount = numpnts(dataWave)
    if (dataPointCount <= 3)
        LJZ_MDCWB_SetLastError("ROI has too few finite points.")
        return -1
    endif

    Variable axisX0 = DimOffset(dataWave, 0)
    Variable axisDX = DimDelta(dataWave, 0)
    if (numtype(axisDX) != 0 || axisDX == 0)
        axisDX = 1
    endif

    if (numtype(editXLo) != 0 || numtype(editXHi) != 0)
        editXLo = axisX0
        editXHi = axisX0 + axisDX * (dataPointCount - 1)
    endif

    // ---------- local working copies ----------
    Make/FREE/N=(paramCountLocal) coefWorkingWave = editParWave[p]
    Make/FREE/N=(paramCountLocal) holdWorkingWave = editHoldWave[p]

    LJZ_MDCWB_ApplyModelSpecialsToWave(coefWorkingWave, holdWorkingWave, modelIDLocal)
    LJZ_MDCWB_SanitizeParamWave(coefWorkingWave, modelIDLocal)

    if (!LJZ_MDCWB_ValidateCoefWaveFinite(coefWorkingWave, paramCountLocal))
        LJZ_MDCWB_SetLastError("Fit coefficients became non-finite.")
        return -1
    endif

    // ---------- ROI ----------
    Variable roiIndexLo, roiIndexHi
    LJZ_MDCWB_GetROIIndexRange(dataWave, editXLo, editXHi, roiIndexLo, roiIndexHi)

    Variable roiPointCount = roiIndexHi - roiIndexLo + 1
    Variable finiteROIPointCount = LJZ_MDCWB_CountFinitePointsInROI(dataWave, editXLo, editXHi)

    if (modelIDLocal == 2 || modelIDLocal == 5)
        if (finiteROIPointCount <= (paramCountLocal + 4))
            LJZ_MDCWB_MarkDirty(1)
            LJZ_MDCWB_SetLastError("ROI has too few finite points.")
            return -1
        endif
    else
        if (finiteROIPointCount < max(12, paramCountLocal + 2))
            LJZ_MDCWB_MarkDirty(1)
            LJZ_MDCWB_SetLastError("ROI has too few finite points.")
            return -1
        endif
    endif

    Make/FREE/N=(roiPointCount) roiDataWave = dataWave[roiIndexLo + p]
    SetScale/P x, axisX0 + roiIndexLo * axisDX, axisDX, roiDataWave

    // ---------- full guess from current edit state ----------
    Duplicate/FREE dataWave, guessFullWave
    if (modelIDLocal == 2)
        guessFullWave = two_pv_ljz(coefWorkingWave, x)
    elseif (modelIDLocal == 5)
        guessFullWave = asympv_plus_pv_ljz(coefWorkingWave, x)
    else
        guessFullWave = one_pv_ljz(coefWorkingWave, x)
    endif

    // ROBUST: abort commit if guess persistence fails, so fit record cannot outrun its guess.
    if (LJZ_MDCWB_SaveGuessWave(dataWave, guessFullWave) != 0)
        LJZ_MDCWB_MarkDirty(1)
        LJZ_MDCWB_SetLastError("Guess save failed.")
        return -1
    endif

    // ---------- hold mask ----------
    String holdMaskString = ""
    Variable holdIndex
    for (holdIndex = 0; holdIndex < paramCountLocal; holdIndex += 1)
        if (holdWorkingWave[holdIndex] != 0)
            holdMaskString += "1"
        else
            holdMaskString += "0"
        endif
    endfor

    // ---------- run FuncFit safely ----------
    // AbortOnRTE must be placed AFTER FuncFit inside try/catch.
    // Do not define local Variable V_FitError / V_FitQuitReason / V_FitNumIters,
    // or they may shadow Igor's built-in fit status variables.
    Variable fitCaughtError = 0
    Variable runtimeErrorCode = 0
    Variable fitFailed = 0
    Variable fitQuitReasonLocal = NaN
    Variable fitNumItersLocal = NaN
    String oldDF = GetDataFolder(1)

    KillWaves/Z W_sigma

    try
        if (modelIDLocal == 2)
            FuncFit/H=holdMaskString two_pv_ljz, coefWorkingWave, roiDataWave
        elseif (modelIDLocal == 5)
            FuncFit/H=holdMaskString asympv_plus_pv_ljz, coefWorkingWave, roiDataWave
        else
            FuncFit/H=holdMaskString one_pv_ljz, coefWorkingWave, roiDataWave
        endif

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
        // Read Igor's built-in fit result variables only on the success path.
        NVAR/Z fitErrorRef = V_FitError
        NVAR/Z fitQuitReasonRef = V_FitQuitReason
        NVAR/Z fitNumItersRef = V_FitNumIters

        if (NVAR_Exists(fitErrorRef) && numtype(fitErrorRef) == 0 && fitErrorRef != 0)
            fitFailed = 1
            LJZ_MDCWB_SetLastError("FuncFit runtime failure.")
        endif

        if (NVAR_Exists(fitQuitReasonRef) && numtype(fitQuitReasonRef) == 0)
            fitQuitReasonLocal = fitQuitReasonRef
        endif

        if (NVAR_Exists(fitNumItersRef) && numtype(fitNumItersRef) == 0)
            fitNumItersLocal = fitNumItersRef
        endif
    endif

    LJZ_MDCWB_SanitizeParamWave(coefWorkingWave, modelIDLocal)

    if (!LJZ_MDCWB_ValidateCoefWaveFinite(coefWorkingWave, paramCountLocal))
        fitFailed = 1
        LJZ_MDCWB_SetLastError("Fit coefficients became non-finite.")
    endif

    if (finiteROIPointCount <= 0)
        fitFailed = 1
        LJZ_MDCWB_SetLastError("ROI has too few finite points.")
    endif

    if (fitFailed)
        // On any fit failure, keep the previous official record untouched and stay dirty.
        LJZ_MDCWB_MarkDirty(1)
        return -1
    endif

    // ---------- build full fit / residual ----------
    Duplicate/FREE dataWave, fitFullWave
    Duplicate/FREE dataWave, resFullWave

    if (modelIDLocal == 2)
        fitFullWave = two_pv_ljz(coefWorkingWave, x)
    elseif (modelIDLocal == 5)
        fitFullWave = asympv_plus_pv_ljz(coefWorkingWave, x)
    else
        fitFullWave = one_pv_ljz(coefWorkingWave, x)
    endif

    resFullWave = dataWave - fitFullWave

    // ---------- sigma ----------
    Make/FREE/N=12 sigmaWorkingWave = NaN
    Wave/Z nativeSigmaWave = W_sigma
    if (WaveExists(nativeSigmaWave))
        Variable sigmaCountLocal = min(numpnts(nativeSigmaWave), paramCountLocal)
        sigmaWorkingWave[0, sigmaCountLocal - 1] = nativeSigmaWave[p]
    endif

    // ---------- coef padded to 12 ----------
    Make/FREE/N=12 coefPaddedWave = NaN
    coefPaddedWave[0, paramCountLocal - 1] = coefWorkingWave[p]

    // ---------- metrics ----------
    Variable metricGuessRMSE, metricFitRMSE, metricRSSROI, metricMaxAbsRes, metricNROI
    if (LJZ_MDCWB_ComputeFitMetrics(dataWave, guessFullWave, fitFullWave, resFullWave, editXLo, editXHi, metricGuessRMSE, metricFitRMSE, metricRSSROI, metricMaxAbsRes, metricNROI) != 0)
        LJZ_MDCWB_MarkDirty(1)
        LJZ_MDCWB_SetLastError("Metric computation failed.")
        return -1
    endif

    // ---------- info ----------
    Make/FREE/N=12 infoWorkingWave = NaN
    LJZ_MDCWB_BuildInfoWave(infoWorkingWave, modelIDLocal, bgOrderLocal, editXLo, editXHi, 1, metricGuessRMSE, metricFitRMSE, metricRSSROI, metricMaxAbsRes, metricNROI)
    infoWorkingWave[10] = fitQuitReasonLocal
    infoWorkingWave[11] = fitNumItersLocal

    // ---------- save official record ----------
    if (LJZ_MDCWB_SaveFitRecord(dataWave, coefPaddedWave, sigmaWorkingWave, infoWorkingWave, fitFullWave, resFullWave) != 0)
        LJZ_MDCWB_MarkDirty(1)
        LJZ_MDCWB_SetLastError("Saving fit record failed.")
        return -1
    endif

    // ---------- sync current edit state ----------
    LJZ_MDCWB_CopyFitResultToEditState(coefWorkingWave, holdWorkingWave, paramCountLocal)
    LJZ_MDCWB_SetParamLayout()
    LJZ_MDCWB_ApplyDefaultHoldPolicy(0)
    LJZ_MDCWB_SanitizeCurrentEditPar()

    LJZ_MDCWB_MarkDirty(0)

    return 0
End



// ============================================================================
//  LJZ_MDCWB Part 3 : View + Panel + Callback + Export
//
//  依赖：
//    - Part 1 : Core + Result Record
//    - Part 2 : Model + Fit Engine
//    - 外部模型/面积辅助（若环境里已有则不会冲突）：
//         LJZ_HWHM_eff
//         LJZ_PVArea_FromCoef
//
//  本部分负责：
//    - panel state for listbox / metric display
//    - preview graph
//    - callbacks
//    - accept/reject/clear
//    - export summary
// ============================================================================


Menu "ARPES_LJZ"
    "MDC Workbench", LJZ_MDCWB_OpenPanel()
End


// ============================================================================
//  Section 1. View-state waves
// ============================================================================

Function LJZ_MDCWB_EnsureViewState()
    LJZ_MDCWB_EnsureDF()

    String base = LJZ_MDCWB_BaseDF()

    Wave/T/Z listDispWave = $(base + ":LB_Disp")
    if (!WaveExists(listDispWave))
        Make/O/T/N=1 $(base + ":LB_Disp") = "(empty)"
    endif

    Wave/T/Z listPathWave = $(base + ":LB_Path")
    if (!WaveExists(listPathWave))
        Make/O/T/N=1 $(base + ":LB_Path") = ""
    endif

    Wave/Z listSelWave = $(base + ":LB_Sel")
    if (!WaveExists(listSelWave))
        Make/O/N=1 $(base + ":LB_Sel") = 0
    endif

    Wave/Z listStateWave = $(base + ":LB_State")
    if (!WaveExists(listStateWave))
        Make/O/N=1 $(base + ":LB_State") = 0
    endif

    Wave/T/Z metricDispWave = $(base + ":MetricDisp")
    if (!WaveExists(metricDispWave))
        Make/O/T/N=1 $(base + ":MetricDisp") = ""
    endif

    Wave/Z metricSelWave = $(base + ":MetricSel")
    if (!WaveExists(metricSelWave))
        Make/O/N=1 $(base + ":MetricSel") = 0
    endif

    Wave/T/Z resultDispLeftWave = $(base + ":ResDispL")
    if (!WaveExists(resultDispLeftWave))
        Make/O/T/N=1 $(base + ":ResDispL") = ""
    endif

    Wave/Z resultSelLeftWave = $(base + ":ResSelL")
    if (!WaveExists(resultSelLeftWave))
        Make/O/N=1 $(base + ":ResSelL") = 0
    endif

    Wave/T/Z resultDispRightWave = $(base + ":ResDispR")
    if (!WaveExists(resultDispRightWave))
        Make/O/T/N=1 $(base + ":ResDispR") = ""
    endif

    Wave/Z resultSelRightWave = $(base + ":ResSelR")
    if (!WaveExists(resultSelRightWave))
        Make/O/N=1 $(base + ":ResSelR") = 0
    endif

    return 0
End


// ============================================================================
//  Section 2. Small UI helpers
// ============================================================================

Function/S LJZ_MDCWB_StateMark(stateValueInput)
    Variable stateValueInput

    if (stateValueInput > 0)
        return "✓ "
    elseif (stateValueInput < 0)
        return "✗ "
    endif

    return "· "
End

Function/S LJZ_MDCWB_RowStateMark(stateValueInput, currentRowInput, dirtyFlagInput)
    Variable stateValueInput, currentRowInput, dirtyFlagInput

    String baseMark = LJZ_MDCWB_StateMark(stateValueInput)
    if (currentRowInput && dirtyFlagInput)
        return "~" + baseMark
    endif

    return baseMark
End

Function/S LJZ_MDCWB_TrimTrailingCR(textInput)
    String textInput

    do
        if (strlen(textInput) <= 0)
            break
        endif
        if (cmpstr(textInput[strlen(textInput)-1, strlen(textInput)-1], "\r") == 0)
            textInput = textInput[0, strlen(textInput)-2]
        else
            break
        endif
    while (1)

    return textInput
End

Function LJZ_MDCWB_TextToListWave(textWave, selWave, sourceText)
    Wave/T textWave
    Wave selWave
    String sourceText

    sourceText = LJZ_MDCWB_TrimTrailingCR(sourceText)

    if (strlen(sourceText) == 0)
        Redimension/N=(1) textWave, selWave
        textWave[0] = ""
        selWave[0] = 0
        return 0
    endif

    String listText = ReplaceString("\r", sourceText, ";")
    Variable itemCount = ItemsInList(listText, ";")
    if (itemCount <= 0)
        itemCount = 1
    endif

    Redimension/N=(itemCount) textWave, selWave

    Variable itemIndex
    for (itemIndex = 0; itemIndex < itemCount; itemIndex += 1)
        textWave[itemIndex] = StringFromList(itemIndex, listText, ";")
        selWave[itemIndex] = 0
    endfor

    return 0
End

Function LJZ_MDCWB_ParseSuffixIndex(controlNameInput, prefixInput)
    String controlNameInput, prefixInput

    if (!StringMatch(controlNameInput, prefixInput + "*"))
        return -1
    endif

    String suffixText = controlNameInput[strlen(prefixInput), inf]
    return str2num(suffixText)
End

Function LJZ_MDCWB_HasChildSubwindow(hostWindowName, childWindowName)
    String hostWindowName, childWindowName

    String childList = ChildWindowList(hostWindowName)
    return (WhichListItem(childWindowName, childList, ";", 0, 0) >= 0)
End

Function LJZ_MDCWB_ClearGraphTracesByWin(windowPath)
    String windowPath

    String traceList = TraceNameList(windowPath, ";", 1)
    Variable traceCount = ItemsInList(traceList, ";")
    Variable traceIndex

    for (traceIndex = 0; traceIndex < traceCount; traceIndex += 1)
        String traceNameLocal = StringFromList(traceIndex, traceList, ";")
        if (strlen(traceNameLocal) > 0)
            RemoveFromGraph/Z/W=$windowPath $traceNameLocal
        endif
    endfor

    return 0
End

Function LJZ_MDCWB_RestoreCurrentSelectionUI()
    LJZ_MDCWB_EnsureViewState()

    NVAR currentRow = $(LJZ_MDCWB_BaseDF() + ":CurRow")
    Wave listSelWave = $(LJZ_MDCWB_BaseDF() + ":LB_Sel")

    listSelWave = 0
    if (currentRow >= 0 && currentRow < numpnts(listSelWave))
        listSelWave[currentRow] = 1
        ListBox/Z lbMDC, win=MDCIFit_LJZ_Panel, selRow=currentRow
    else
        ListBox/Z lbMDC, win=MDCIFit_LJZ_Panel, selRow=-1
    endif

    ControlUpdate/W=MDCIFit_LJZ_Panel lbMDC
    return 0
End

Function LJZ_MDCWB_ConfirmLeaveIfDirty()
    SVAR currentWavePath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
    NVAR currentRow = $(LJZ_MDCWB_BaseDF() + ":CurRow")

    if (strlen(currentWavePath) == 0 || currentRow < 0)
        return 1
    endif

    if (!LJZ_MDCWB_IsDirty())
        return 1
    endif

    DoAlert 1, "Current MDC has unsaved/stale edits. Discard them and continue?"
    if (V_flag == 1)
        return 1
    endif

    return 0
End


// ============================================================================
//  Section 3. List / selection logic
// ============================================================================

Function LJZ_MDCWB_RefreshCurrentRowDisplayMark()
    LJZ_MDCWB_EnsureViewState()

    NVAR currentRow = $(LJZ_MDCWB_BaseDF() + ":CurRow")
    SVAR currentWavePath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
    Wave/T/Z listDispWave = $(LJZ_MDCWB_BaseDF() + ":LB_Disp")
    Wave/Z listStateWave = $(LJZ_MDCWB_BaseDF() + ":LB_State")

    if (!WaveExists(listDispWave) || !WaveExists(listStateWave))
        return -1
    endif
    if (currentRow < 0 || currentRow >= numpnts(listStateWave))
        return -1
    endif
    if (strlen(currentWavePath) == 0)
        return -1
    endif

    Wave/Z dataWave = $currentWavePath
    if (!WaveExists(dataWave))
        LJZ_MDCWB_SetLastError("No current wave selected.")
        return -1
    endif

    // OP-FLOW HAZARD: make dirty current-row state visibly different from last clean accept/reject mark.
    listDispWave[currentRow] = LJZ_MDCWB_RowStateMark(listStateWave[currentRow], 1, LJZ_MDCWB_IsDirty()) + NameOfWave(dataWave)
    LJZ_MDCWB_RestoreCurrentSelectionUI()
    return 0
End

Function LJZ_MDCWB_SetCurrentRowStateMark(newStateInput)
    Variable newStateInput

    LJZ_MDCWB_EnsureViewState()

    NVAR currentRow = $(LJZ_MDCWB_BaseDF() + ":CurRow")
    SVAR currentWavePath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
    Wave listStateWave = $(LJZ_MDCWB_BaseDF() + ":LB_State")

    if (currentRow < 0 || currentRow >= numpnts(listStateWave))
        return -1
    endif
    if (strlen(currentWavePath) == 0)
        return -1
    endif

    Wave/Z dataWave = $currentWavePath
    if (!WaveExists(dataWave))
        return -1
    endif

    LJZ_MDCWB_WriteAcceptState(dataWave, newStateInput)

    listStateWave[currentRow] = LJZ_MDCWB_ReadAcceptState(dataWave)
    LJZ_MDCWB_RefreshCurrentRowDisplayMark()

    return 0
End

Function LJZ_MDCWB_RebuildLB()
    LJZ_MDCWB_EnsureViewState()

    SVAR targetDFPath = $(LJZ_MDCWB_BaseDF() + ":TargetDF")
    SVAR currentWavePath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
    NVAR currentRow = $(LJZ_MDCWB_BaseDF() + ":CurRow")

    String oldWavePath = currentWavePath
    Variable oldDirtyState = LJZ_MDCWB_IsDirty()

    String normalizedDFPath = LJZ_MDCWB_NormDFPath(targetDFPath)
    if (strlen(normalizedDFPath) == 0)
        SVAR/Z defaultRunDF = root:ARPES_LJZ:MDCFit:RunDF
        if (SVAR_Exists(defaultRunDF))
            normalizedDFPath = LJZ_MDCWB_NormDFPath(defaultRunDF)
            if (strlen(normalizedDFPath) > 0)
                targetDFPath = normalizedDFPath
            endif
        endif
    endif

    String mdcWaveList = LJZ_MDCWB_ListMDCWaves(targetDFPath)
    Variable listCount = ItemsInList(mdcWaveList, ";")
    if (listCount <= 0)
        listCount = 1
    endif

    Make/O/T/N=(listCount) $(LJZ_MDCWB_BaseDF() + ":LB_Disp")
    Make/O/T/N=(listCount) $(LJZ_MDCWB_BaseDF() + ":LB_Path")
    Make/O/N=(listCount)   $(LJZ_MDCWB_BaseDF() + ":LB_Sel")
    Make/O/N=(listCount)   $(LJZ_MDCWB_BaseDF() + ":LB_State")

    Wave/T listDispWave = $(LJZ_MDCWB_BaseDF() + ":LB_Disp")
    Wave/T listPathWave = $(LJZ_MDCWB_BaseDF() + ":LB_Path")
    Wave listSelWave = $(LJZ_MDCWB_BaseDF() + ":LB_Sel")
    Wave listStateWave = $(LJZ_MDCWB_BaseDF() + ":LB_State")

    listSelWave = 0
    listStateWave = 0

    if (ItemsInList(mdcWaveList, ";") <= 0)
        currentRow = -1
        currentWavePath = ""
        LJZ_MDCWB_ClearEditState()

        listDispWave[0] = "(no MDC waves)"
        listPathWave[0] = ""
        listStateWave[0] = 0

        return 0
    endif

    Variable foundOldRow = -1
    Variable listIndex
    Variable totalListCount = ItemsInList(mdcWaveList, ";")

    for (listIndex = 0; listIndex < totalListCount; listIndex += 1)
        String fullWavePath = StringFromList(listIndex, mdcWaveList, ";")
        Wave/Z oneWave = $fullWavePath
        if (!WaveExists(oneWave))
            continue
        endif

        listPathWave[listIndex] = fullWavePath
        listStateWave[listIndex] = LJZ_MDCWB_ReadAcceptState(oneWave)
        listDispWave[listIndex] = LJZ_MDCWB_RowStateMark(listStateWave[listIndex], cmpstr(fullWavePath, oldWavePath) == 0, oldDirtyState) + NameOfWave(oneWave)

        if (cmpstr(fullWavePath, oldWavePath) == 0)
            foundOldRow = listIndex
        endif
    endfor

    if (foundOldRow >= 0)
        currentRow = foundOldRow
        currentWavePath = listPathWave[foundOldRow]
        listSelWave[foundOldRow] = 1
        LJZ_MDCWB_MarkDirty(oldDirtyState)
    else
        currentRow = -1
        currentWavePath = ""
        LJZ_MDCWB_ClearEditState()
    endif

    return 0
End

Function LJZ_MDCWB_SelectCurrentRow(newRowInput)
    Variable newRowInput

    LJZ_MDCWB_EnsureViewState()

    Wave/T listPathWave = $(LJZ_MDCWB_BaseDF() + ":LB_Path")
    Wave listSelWave = $(LJZ_MDCWB_BaseDF() + ":LB_Sel")

    if (newRowInput < 0 || newRowInput >= numpnts(listPathWave))
        return -1
    endif

    NVAR currentRow = $(LJZ_MDCWB_BaseDF() + ":CurRow")
    SVAR currentWavePath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")

    currentRow = newRowInput
    currentWavePath = listPathWave[newRowInput]

    listSelWave = 0
    listSelWave[newRowInput] = 1
    LJZ_MDCWB_RestoreCurrentSelectionUI()

    Wave/Z dataWave = $currentWavePath
    if (!WaveExists(dataWave))
        return -1
    endif

    LJZ_MDCWB_LoadCurrentWaveToEditState()
    LJZ_MDCWB_RefreshCurrentRowDisplayMark()
    return 0
End

Function LJZ_MDCWB_FindNextUnchecked(startRowInput)
    Variable startRowInput

    Wave listStateWave = $(LJZ_MDCWB_BaseDF() + ":LB_State")

    Variable rowIndex
    for (rowIndex = startRowInput + 1; rowIndex < numpnts(listStateWave); rowIndex += 1)
        if (listStateWave[rowIndex] == 0)
            return rowIndex
        endif
    endfor

    return -1
End


// ============================================================================
//  Section 4. Preview graph
// ============================================================================

Function LJZ_MDCWB_CreatePreviewGraph()
    DoWindow MDCIFit_LJZ_Panel
    if (V_flag == 0)
        return -1
    endif

    KillWindow/Z MDCIFit_LJZ_Panel#pvGraph
    KillWindow/Z MDCIFit_LJZ_Panel#rsGraph

    Display/HOST=MDCIFit_LJZ_Panel/N=pvGraph/W=(250,208,690,338)
    ModifyGraph/W=$"MDCIFit_LJZ_Panel#pvGraph" margin(left)=40,margin(bottom)=20
    ModifyGraph/W=$"MDCIFit_LJZ_Panel#pvGraph" mirror=1
    Label/W=$"MDCIFit_LJZ_Panel#pvGraph" left "Intensity"

    Display/HOST=MDCIFit_LJZ_Panel/N=rsGraph/W=(250,342,690,392)
    ModifyGraph/W=$"MDCIFit_LJZ_Panel#rsGraph" margin(left)=40,margin(bottom)=28
    ModifyGraph/W=$"MDCIFit_LJZ_Panel#rsGraph" mirror=1
    Label/W=$"MDCIFit_LJZ_Panel#rsGraph" left "Res"
    Label/W=$"MDCIFit_LJZ_Panel#rsGraph" bottom "k / x"

    return 0
End

Function LJZ_MDCWB_GetPreviewYRange(dataWave, guessWave, fitWave, resWave, xShowLoInput, xShowHiInput, dirtyFlagInput, modeInput, yMinOut, yMaxOut)
    Wave dataWave
    Wave/Z guessWave, fitWave, resWave
    Variable xShowLoInput, xShowHiInput, dirtyFlagInput, modeInput
    Variable &yMinOut, &yMaxOut

    Variable plotIndexLo, plotIndexHi
    LJZ_MDCWB_GetROIIndexRange(dataWave, xShowLoInput, xShowHiInput, plotIndexLo, plotIndexHi)

    yMinOut = Inf
    yMaxOut = -Inf

    if (modeInput == 0)
        WaveStats/Q/R=[plotIndexLo, plotIndexHi] dataWave
        yMinOut = min(yMinOut, V_min)
        yMaxOut = max(yMaxOut, V_max)

        if (WaveExists(guessWave))
            WaveStats/Q/R=[plotIndexLo, plotIndexHi] guessWave
            yMinOut = min(yMinOut, V_min)
            yMaxOut = max(yMaxOut, V_max)
        endif

        if ((!dirtyFlagInput) && WaveExists(fitWave))
            WaveStats/Q/R=[plotIndexLo, plotIndexHi] fitWave
            yMinOut = min(yMinOut, V_min)
            yMaxOut = max(yMaxOut, V_max)
        endif

        if (numtype(yMinOut) != 0 || numtype(yMaxOut) != 0 || yMaxOut <= yMinOut)
            yMinOut = 0
            yMaxOut = 1
        endif

    else
        if ((!dirtyFlagInput) && WaveExists(resWave))
            WaveStats/Q/R=[plotIndexLo, plotIndexHi] resWave
            Variable maxAbsResidual = max(abs(V_min), abs(V_max))
            if (numtype(maxAbsResidual) != 0 || maxAbsResidual <= 0)
                maxAbsResidual = 1
            endif
            yMinOut = -1.08 * maxAbsResidual
            yMaxOut =  1.08 * maxAbsResidual
        else
            yMinOut = -1
            yMaxOut = 1
        endif
    endif

    return 0
End

Function LJZ_MDCWB_RefreshPreviewGraph()
    String hostWindowName = "MDCIFit_LJZ_Panel"
    String mainGraphName = "pvGraph"
    String residualGraphName = "rsGraph"
    String mainGraphPath = hostWindowName + "#" + mainGraphName
    String residualGraphPath = hostWindowName + "#" + residualGraphName

    DoWindow $hostWindowName
    if (V_flag == 0)
        return -1
    endif

    if (!LJZ_MDCWB_HasChildSubwindow(hostWindowName, mainGraphName) || !LJZ_MDCWB_HasChildSubwindow(hostWindowName, residualGraphName))
        LJZ_MDCWB_CreatePreviewGraph()
    endif

    SVAR currentWavePath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
    NVAR editXLo = $(LJZ_MDCWB_BaseDF() + ":EditXLo")
    NVAR editXHi = $(LJZ_MDCWB_BaseDF() + ":EditXHi")

    if (strlen(currentWavePath) == 0)
        LJZ_MDCWB_ClearGraphTracesByWin(mainGraphPath)
        LJZ_MDCWB_ClearGraphTracesByWin(residualGraphPath)
        TextBox/W=$mainGraphPath/K/N=previewStatus
        SetAxis/Z/W=$mainGraphPath bottom, 0, 1
        SetAxis/Z/W=$mainGraphPath left, 0, 1
        SetAxis/Z/W=$residualGraphPath bottom, 0, 1
        SetAxis/Z/W=$residualGraphPath left, -1, 1
        return -1
    endif

    Wave/Z dataWave = $currentWavePath
    if (!WaveExists(dataWave))
        LJZ_MDCWB_ClearGraphTracesByWin(mainGraphPath)
        LJZ_MDCWB_ClearGraphTracesByWin(residualGraphPath)
        TextBox/W=$mainGraphPath/K/N=previewStatus
        SetAxis/Z/W=$mainGraphPath bottom, 0, 1
        SetAxis/Z/W=$mainGraphPath left, 0, 1
        SetAxis/Z/W=$residualGraphPath bottom, 0, 1
        SetAxis/Z/W=$residualGraphPath left, -1, 1
        return -1
    endif

Variable previewUpdateOK = (LJZ_MDCWB_UpdatePreviewGuessWave(dataWave) == 0)
if (!previewUpdateOK)
    // OP-FLOW HAZARD: never leave the previous preview curve on screen when the new preview build failed.
    KillWaves/Z $(LJZ_MDCWB_PreviewGuessPath())
endif

Wave/Z guessWave = $(LJZ_MDCWB_PreviewGuessPath())
Wave/Z fitWave = $(LJZ_MDCWB_ResultFitPath(dataWave))
Wave/Z resWave = $(LJZ_MDCWB_ResultResPath(dataWave))

    Variable dirtyFlagLocal = LJZ_MDCWB_IsDirty()

    Variable axisDX = DimDelta(dataWave, 0)
    if (numtype(axisDX) != 0 || axisDX == 0)
        axisDX = 1
    endif

    Variable xShowLo, xShowHi
    Variable useROIWindow = 0

    if (numtype(editXLo) == 0 && numtype(editXHi) == 0)
        Variable roiXMin = min(editXLo, editXHi)
        Variable roiXMax = max(editXLo, editXHi)
        if (roiXMin != roiXMax)
            Variable xPadValue = max(0.08 * abs(roiXMax - roiXMin), 2 * abs(axisDX))
            xShowLo = roiXMin - xPadValue
            xShowHi = roiXMax + xPadValue
            useROIWindow = 1
        endif
    endif

    if (!useROIWindow)
        Variable axisX0 = DimOffset(dataWave, 0)
        Variable pointCount = numpnts(dataWave)
        xShowLo = axisX0
        xShowHi = axisX0 + axisDX * (pointCount - 1)
    endif

    Variable yMainMin, yMainMax
    Variable yResMin, yResMax
    LJZ_MDCWB_GetPreviewYRange(dataWave, guessWave, fitWave, resWave, xShowLo, xShowHi, dirtyFlagLocal, 0, yMainMin, yMainMax)
    LJZ_MDCWB_GetPreviewYRange(dataWave, guessWave, fitWave, resWave, xShowLo, xShowHi, dirtyFlagLocal, 1, yResMin, yResMax)

    Variable yMainPad = 0.06 * (yMainMax - yMainMin)
    if (numtype(yMainPad) != 0 || yMainPad <= 0)
        yMainPad = 1
    endif

    LJZ_MDCWB_ClearGraphTracesByWin(mainGraphPath)
    AppendToGraph/W=$mainGraphPath dataWave
    if (previewUpdateOK && WaveExists(guessWave))
        AppendToGraph/W=$mainGraphPath guessWave
    endif

if ((!dirtyFlagLocal) && WaveExists(fitWave))
    AppendToGraph/W=$mainGraphPath fitWave
endif

ModifyGraph/W=$mainGraphPath mode=0
ModifyGraph/W=$mainGraphPath lsize=1.5
ModifyGraph/W=$mainGraphPath rgb($NameOfWave(dataWave))=(0,0,0)

if (previewUpdateOK && WaveExists(guessWave))
    ModifyGraph/W=$mainGraphPath rgb($NameOfWave(guessWave))=(0,0,65535)
    ModifyGraph/W=$mainGraphPath lstyle($NameOfWave(guessWave))=2
endif

if ((!dirtyFlagLocal) && WaveExists(fitWave))
    ModifyGraph/W=$mainGraphPath rgb($NameOfWave(fitWave))=(65535,0,0)
endif


    SetAxis/Z/W=$mainGraphPath bottom, xShowLo, xShowHi
    SetAxis/Z/W=$mainGraphPath left, yMainMin - 0.3*yMainPad, yMainMax + yMainPad

    if (ItemsInList(TraceNameList(mainGraphPath, ";", 1), ";") > 0)
        Legend/W=$mainGraphPath/C/N=text0/J
    else
        Legend/W=$mainGraphPath/K/N=text0
    endif
    // OP-FLOW HAZARD: preview failures must be explicit so old blue curves cannot masquerade as current params.
    if (!previewUpdateOK)
        TextBox/W=$mainGraphPath/C/N=previewStatus/F=0/A=RT/X=-2/Y=2 "\\Z12Preview failed\\rCurrent preview unavailable"
    elseif (dirtyFlagLocal)
        TextBox/W=$mainGraphPath/C/N=previewStatus/F=0/A=RT/X=-2/Y=2 "\\Z12Preview is dirty\\rOfficial fit may be stale"
    else
        TextBox/W=$mainGraphPath/C/N=previewStatus/F=0/A=RT/X=-2/Y=2 "\\Z12Official fit is current"
    endif

    LJZ_MDCWB_ClearGraphTracesByWin(residualGraphPath)
    if ((!dirtyFlagLocal) && WaveExists(resWave))
        AppendToGraph/W=$residualGraphPath resWave
        ModifyGraph/W=$residualGraphPath mode=0
        ModifyGraph/W=$residualGraphPath lsize=1.2
        ModifyGraph/W=$residualGraphPath rgb($NameOfWave(resWave))=(30000,30000,30000)
    endif

    SetAxis/Z/W=$residualGraphPath bottom, xShowLo, xShowHi
    SetAxis/Z/W=$residualGraphPath left, yResMin, yResMax

    return 0
End

Function LJZ_MDCWB_ApplyROIFromPreviewCursorsIfWanted()
    LJZ_MDCWB_EnsureDF()

    NVAR useCursorsFlag = $(LJZ_MDCWB_BaseDF() + ":UseCursors")
    if (!useCursorsFlag)
        return 0
    endif

    String graphPath = "MDCIFit_LJZ_Panel#pvGraph"

    DoWindow MDCIFit_LJZ_Panel
    if (V_flag == 0)
        return 0
    endif

    if (!LJZ_MDCWB_HasChildSubwindow("MDCIFit_LJZ_Panel", "pvGraph"))
        return 0
    endif

    String cursorInfoA = CsrInfo(A, graphPath)
    String cursorInfoB = CsrInfo(B, graphPath)

    if (strlen(cursorInfoA) == 0 || strlen(cursorInfoB) == 0)
        return 0
    endif

    Variable cursorXA = xcsr(A, graphPath)
    Variable cursorXB = xcsr(B, graphPath)

    if (numtype(cursorXA) != 0 || numtype(cursorXB) != 0)
        return 0
    endif

    NVAR editXLo = $(LJZ_MDCWB_BaseDF() + ":EditXLo")
    NVAR editXHi = $(LJZ_MDCWB_BaseDF() + ":EditXHi")

    editXLo = cursorXA
    editXHi = cursorXB

    return 1
End


// ============================================================================
//  Section 5. Metric / result display
// ============================================================================

Function LJZ_MDCWB_RefreshMetricBox()
    LJZ_MDCWB_EnsureViewState()

    SVAR currentWavePath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")

    Wave/T metricDispWave = $(LJZ_MDCWB_BaseDF() + ":MetricDisp")
    Wave metricSelWave = $(LJZ_MDCWB_BaseDF() + ":MetricSel")
    Wave/T resultDispLeftWave = $(LJZ_MDCWB_BaseDF() + ":ResDispL")
    Wave resultSelLeftWave = $(LJZ_MDCWB_BaseDF() + ":ResSelL")
    Wave/T resultDispRightWave = $(LJZ_MDCWB_BaseDF() + ":ResDispR")
    Wave resultSelRightWave = $(LJZ_MDCWB_BaseDF() + ":ResSelR")

    String metricText = ""
    String resultTextLeft = ""
    String resultTextRight = ""

    if (strlen(currentWavePath) == 0)
        metricText = "No MDC selected."
        LJZ_MDCWB_TextToListWave(metricDispWave, metricSelWave, metricText)
        LJZ_MDCWB_TextToListWave(resultDispLeftWave, resultSelLeftWave, "")
        LJZ_MDCWB_TextToListWave(resultDispRightWave, resultSelRightWave, "")
        return 0
    endif

    Wave/Z dataWave = $currentWavePath
    if (!WaveExists(dataWave))
        metricText = "Selected wave not found."
        LJZ_MDCWB_TextToListWave(metricDispWave, metricSelWave, metricText)
        LJZ_MDCWB_TextToListWave(resultDispLeftWave, resultSelLeftWave, "")
        LJZ_MDCWB_TextToListWave(resultDispRightWave, resultSelRightWave, "")
        return 0
    endif

    String waveNameLocal = NameOfWave(dataWave)

    NVAR editModelID = $(LJZ_MDCWB_BaseDF() + ":EditModelID")
    NVAR editBGOrder = $(LJZ_MDCWB_BaseDF() + ":EditBGOrder")
    NVAR editXLo = $(LJZ_MDCWB_BaseDF() + ":EditXLo")
    NVAR editXHi = $(LJZ_MDCWB_BaseDF() + ":EditXHi")
    NVAR currentRow = $(LJZ_MDCWB_BaseDF() + ":CurRow")

    Wave listStateWave = $(LJZ_MDCWB_BaseDF() + ":LB_State")
    Wave/T editParNameWave = $(LJZ_MDCWB_BaseDF() + ":EditParName")
    Wave editParEnableWave = $(LJZ_MDCWB_BaseDF() + ":EditParEnable")
    Wave editParWave = $(LJZ_MDCWB_BaseDF() + ":EditPar")
    Wave editHoldWave = $(LJZ_MDCWB_BaseDF() + ":EditHold")

    Variable acceptStateLocal = 0
    if (currentRow >= 0 && currentRow < numpnts(listStateWave))
        acceptStateLocal = listStateWave[currentRow]
    else
        acceptStateLocal = LJZ_MDCWB_ReadAcceptState(dataWave)
    endif

    String stateTextLocal = "Unchecked"
    if (acceptStateLocal > 0)
        stateTextLocal = "Accepted"
    elseif (acceptStateLocal < 0)
        stateTextLocal = "Rejected"
    endif

    if (LJZ_MDCWB_IsDirty() && acceptStateLocal != 0)
        stateTextLocal += " (last clean fit)"
    endif

    metricText += "Wave: " + waveNameLocal + "\r"
    metricText += "Model: " + LJZ_MDCWB_ModelName(editModelID) + "\r"
    metricText += "BG: " + LJZ_MDCWB_BGName(editBGOrder) + "\r"
    metricText += "ROI: [" + Num2Str(editXLo) + ", " + Num2Str(editXHi) + "]\r"
    metricText += "State: " + stateTextLocal + "\r"
    metricText += "N(all): " + Num2Str(numpnts(dataWave)) + "\r"
    Wave/Z coefWave = $(LJZ_MDCWB_ResultCoefPath(dataWave))
    Wave/Z sigmaWave = $(LJZ_MDCWB_ResultSigmaPath(dataWave))
    Wave/Z infoWave = $(LJZ_MDCWB_ResultInfoPath(dataWave))

    Variable previewMetricOK = (LJZ_MDCWB_UpdatePreviewGuessWave(dataWave) == 0)
    if (!previewMetricOK)
        KillWaves/Z $(LJZ_MDCWB_PreviewGuessPath())
    endif

    Variable guessRMSELocal = NaN, fitRMSEDummy, rssROIDummy, maxAbsDummy, nROIDummy
    Wave/Z guessMetricWave = $(LJZ_MDCWB_PreviewGuessPath())
    Wave/Z fitWaveForDummy = $(LJZ_MDCWB_ResultFitPath(dataWave))
    Wave/Z resWaveForDummy = $(LJZ_MDCWB_ResultResPath(dataWave))

    if (previewMetricOK && WaveExists(guessMetricWave))
        if (WaveExists(fitWaveForDummy) && WaveExists(resWaveForDummy))
            if (LJZ_MDCWB_ComputeFitMetrics(dataWave, guessMetricWave, fitWaveForDummy, resWaveForDummy, editXLo, editXHi, guessRMSELocal, fitRMSEDummy, rssROIDummy, maxAbsDummy, nROIDummy) != 0)
                guessRMSELocal = NaN
            endif
        else
            Make/FREE/N=(numpnts(dataWave)) dummyFitWave = dataWave
            Make/FREE/N=(numpnts(dataWave)) dummyResWave = 0
            SetScale/P x, DimOffset(dataWave,0), DimDelta(dataWave,0), dummyFitWave, dummyResWave
            if (LJZ_MDCWB_ComputeFitMetrics(dataWave, guessMetricWave, dummyFitWave, dummyResWave, editXLo, editXHi, guessRMSELocal, fitRMSEDummy, rssROIDummy, maxAbsDummy, nROIDummy) != 0)
                guessRMSELocal = NaN
            endif
        endif
    endif

    if (numtype(guessRMSELocal) == 0)
        metricText += "GuessRMSE: " + Num2Str(guessRMSELocal) + "\r"
    elseif (previewMetricOK)
        metricText += "GuessRMSE: --\r"
    else
        metricText += "GuessRMSE: preview failed\r"
    endif

    Variable dirtyFlagLocal = LJZ_MDCWB_IsDirty()

    if (dirtyFlagLocal)
        // FIX: clearly tell the user that the preview is not the official fit.
        metricText += "Preview is dirty\r"
        metricText += "Official fit may be stale\r"
        metricText += "FitRMSE: stale\r"
        metricText += "RSS(ROI): stale\r"
        metricText += "max|res|: stale\r"
        metricText += "N(ROI): stale\r"

        resultTextLeft = "Current preview guess\r"
        resultTextRight = ""

        Variable enabledParamCounterGuess = 0
        Variable paramIndexGuess
        for (paramIndexGuess = 0; paramIndexGuess < 12; paramIndexGuess += 1)
            if (!editParEnableWave[paramIndexGuess])
                continue
            endif

            String guessLine = editParNameWave[paramIndexGuess] + " = " + Num2Str(editParWave[paramIndexGuess])
            if (editHoldWave[paramIndexGuess] != 0)
                guessLine += " (H)"
            endif

            if (mod(enabledParamCounterGuess, 2) == 0)
                resultTextLeft += guessLine + "\r"
            else
                resultTextRight += guessLine + "\r"
            endif
            enabledParamCounterGuess += 1
        endfor

    else
        metricText += "Official fit is current\r"
        if (WaveExists(infoWave) && numpnts(infoWave) >= 10)
            if (numtype(infoWave[6]) == 0)
                metricText += "FitRMSE: " + Num2Str(infoWave[6]) + "\r"
            else
                metricText += "FitRMSE: --\r"
            endif

            if (numtype(infoWave[7]) == 0)
                metricText += "RSS(ROI): " + Num2Str(infoWave[7]) + "\r"
            else
                metricText += "RSS(ROI): --\r"
            endif

            if (numtype(infoWave[8]) == 0)
                metricText += "max|res|: " + Num2Str(infoWave[8]) + "\r"
            else
                metricText += "max|res|: --\r"
            endif

            if (numtype(infoWave[9]) == 0)
                metricText += "N(ROI): " + Num2Str(infoWave[9]) + "\r"
            else
                metricText += "N(ROI): --\r"
            endif
        else
            metricText += "FitRMSE: --\r"
            metricText += "RSS(ROI): --\r"
            metricText += "max|res|: --\r"
            metricText += "N(ROI): --\r"
        endif

        resultTextLeft = "Fitted params\r"
        resultTextRight = ""

        if (WaveExists(coefWave))
            Variable enabledParamCounterFit = 0
            Variable paramIndexFit
            for (paramIndexFit = 0; paramIndexFit < 12; paramIndexFit += 1)
                if (!editParEnableWave[paramIndexFit])
                    continue
                endif

                String fitLine = editParNameWave[paramIndexFit] + " = " + Num2Str(coefWave[paramIndexFit])
                if (WaveExists(sigmaWave) && paramIndexFit < numpnts(sigmaWave) && numtype(sigmaWave[paramIndexFit]) == 0)
                    fitLine += " ± " + Num2Str(sigmaWave[paramIndexFit])
                endif

                if (mod(enabledParamCounterFit, 2) == 0)
                    resultTextLeft += fitLine + "\r"
                else
                    resultTextRight += fitLine + "\r"
                endif
                enabledParamCounterFit += 1
            endfor
        endif
    endif

    LJZ_MDCWB_TextToListWave(metricDispWave, metricSelWave, metricText)
    LJZ_MDCWB_TextToListWave(resultDispLeftWave, resultSelLeftWave, resultTextLeft)
    LJZ_MDCWB_TextToListWave(resultDispRightWave, resultSelRightWave, resultTextRight)

    return 0
End


// ============================================================================
//  Section 6. Parameter controls
// ============================================================================

Function LJZ_MDCWB_BuildParamControls()
    DoWindow MDCIFit_LJZ_Panel
    if (V_flag == 0)
        return -1
    endif

    Variable paramIndex
    for (paramIndex = 0; paramIndex < 12; paramIndex += 1)
        String titleBoxName = "tbP" + Num2Str(paramIndex)
        String setVarName   = "svP" + Num2Str(paramIndex)
        String checkBoxName = "cbH" + Num2Str(paramIndex)

        KillControl/W=MDCIFit_LJZ_Panel $titleBoxName
        KillControl/W=MDCIFit_LJZ_Panel $setVarName
        KillControl/W=MDCIFit_LJZ_Panel $checkBoxName
    endfor

    Variable leftNameX = 250
    Variable leftValueX = 325
    Variable leftHoldX = 440

    Variable rightNameX = 480
    Variable rightValueX = 555
    Variable rightHoldX = 670

    Variable yStart = 428
    Variable yStep = 24

    for (paramIndex = 0; paramIndex < 12; paramIndex += 1)
        String titleBoxName2 = "tbP" + Num2Str(paramIndex)
        String setVarName2   = "svP" + Num2Str(paramIndex)
        String checkBoxName2 = "cbH" + Num2Str(paramIndex)

        Variable columnIndex = trunc(paramIndex / 6)
        Variable rowIndex = mod(paramIndex, 6)

        Variable controlY = yStart + rowIndex * yStep
        Variable nameX, valueX, holdX

        if (columnIndex == 0)
            nameX = leftNameX
            valueX = leftValueX
            holdX = leftHoldX
        else
            nameX = rightNameX
            valueX = rightValueX
            holdX = rightHoldX
        endif

        Execute/Q ("TitleBox " + titleBoxName2 + ",win=MDCIFit_LJZ_Panel,pos={" + Num2Str(nameX) + "," + Num2Str(controlY) + "},size={120,16},title=\"P" + Num2Str(paramIndex) + "\",frame=0\r")
        Execute/Q ("SetVariable " + setVarName2 + ",win=MDCIFit_LJZ_Panel,pos={" + Num2Str(valueX) + "," + Num2Str(controlY-3) + "},size={95,20},proc=LJZ_MDCWB_SetVarProc,title=\"\"\r")
        Execute/Q ("CheckBox " + checkBoxName2 + ",win=MDCIFit_LJZ_Panel,pos={" + Num2Str(holdX) + "," + Num2Str(controlY-1) + "},size={34,16},proc=LJZ_MDCWB_CheckProc,title=\"H\"\r")
    endfor

    LJZ_MDCWB_SetParamLayout()
    LJZ_MDCWB_RefreshParamControls()

    return 0
End

Function LJZ_MDCWB_RefreshParamControls()
    DoWindow MDCIFit_LJZ_Panel
    if (V_flag == 0)
        return 0
    endif

    SVAR targetDFPath = $(LJZ_MDCWB_BaseDF() + ":TargetDF")
    NVAR editModelID = $(LJZ_MDCWB_BaseDF() + ":EditModelID")
    NVAR editBGOrder = $(LJZ_MDCWB_BaseDF() + ":EditBGOrder")
    NVAR editXLo = $(LJZ_MDCWB_BaseDF() + ":EditXLo")
    NVAR editXHi = $(LJZ_MDCWB_BaseDF() + ":EditXHi")
    NVAR useCursorsFlag = $(LJZ_MDCWB_BaseDF() + ":UseCursors")

    Wave/T editParNameWave = $(LJZ_MDCWB_BaseDF() + ":EditParName")
    Wave editParEnableWave = $(LJZ_MDCWB_BaseDF() + ":EditParEnable")
    Wave editParWave = $(LJZ_MDCWB_BaseDF() + ":EditPar")
    Wave editHoldWave = $(LJZ_MDCWB_BaseDF() + ":EditHold")

    SetVariable/Z svTarget, win=MDCIFit_LJZ_Panel, value=_STR:targetDFPath
    SetVariable/Z svXLo, win=MDCIFit_LJZ_Panel, value=_NUM:editXLo
    SetVariable/Z svXHi, win=MDCIFit_LJZ_Panel, value=_NUM:editXHi

    PopupMenu/Z pmModel, win=MDCIFit_LJZ_Panel, mode=editModelID
    PopupMenu/Z pmBG, win=MDCIFit_LJZ_Panel, mode=(editBGOrder + 1)
    CheckBox/Z cbCsr, win=MDCIFit_LJZ_Panel, value=useCursorsFlag

    Variable leftNameX = 250
    Variable leftValueX = 325
    Variable leftHoldX = 440

    Variable rightNameX = 480
    Variable rightValueX = 555
    Variable rightHoldX = 670

    Variable yStart = 428
    Variable yStep = 24

    Variable visibleCounter = 0
    Variable paramIndex

    for (paramIndex = 0; paramIndex < 12; paramIndex += 1)
        String titleBoxName = "tbP" + Num2Str(paramIndex)
        String setVarName   = "svP" + Num2Str(paramIndex)
        String checkBoxName = "cbH" + Num2Str(paramIndex)

        Variable currentParamValue = editParWave[paramIndex]
        Variable currentHoldValue = (editHoldWave[paramIndex] != 0)

        TitleBox/Z $titleBoxName, win=MDCIFit_LJZ_Panel, title=editParNameWave[paramIndex]
        SetVariable/Z $setVarName, win=MDCIFit_LJZ_Panel, value=_NUM:currentParamValue
        CheckBox/Z $checkBoxName, win=MDCIFit_LJZ_Panel, value=currentHoldValue

        if (editParEnableWave[paramIndex])
            Variable columnIndex = trunc(visibleCounter / 6)
            Variable rowIndex = mod(visibleCounter, 6)
            Variable controlY = yStart + rowIndex * yStep

            Variable nameX, valueX, holdX
            if (columnIndex == 0)
                nameX = leftNameX
                valueX = leftValueX
                holdX = leftHoldX
            else
                nameX = rightNameX
                valueX = rightValueX
                holdX = rightHoldX
            endif

            TitleBox/Z $titleBoxName, win=MDCIFit_LJZ_Panel, pos={nameX, controlY}
            SetVariable/Z $setVarName, win=MDCIFit_LJZ_Panel, pos={valueX, controlY-3}
            CheckBox/Z $checkBoxName, win=MDCIFit_LJZ_Panel, pos={holdX, controlY-1}

            ModifyControl/Z $titleBoxName, win=MDCIFit_LJZ_Panel, disable=0
            ModifyControl/Z $setVarName, win=MDCIFit_LJZ_Panel, disable=0
            ModifyControl/Z $checkBoxName, win=MDCIFit_LJZ_Panel, disable=0

            visibleCounter += 1
        else
            TitleBox/Z $titleBoxName, win=MDCIFit_LJZ_Panel, pos={-500,-500}
            SetVariable/Z $setVarName, win=MDCIFit_LJZ_Panel, pos={-500,-500}
            CheckBox/Z $checkBoxName, win=MDCIFit_LJZ_Panel, pos={-500,-500}

            ModifyControl/Z $titleBoxName, win=MDCIFit_LJZ_Panel, disable=2
            ModifyControl/Z $setVarName, win=MDCIFit_LJZ_Panel, disable=2
            ModifyControl/Z $checkBoxName, win=MDCIFit_LJZ_Panel, disable=2
        endif
    endfor

    return 0
End


// ============================================================================
//  Section 7. Panel init / open
// ============================================================================

Function LJZ_MDCWB_InitPanelState()
    LJZ_MDCWB_EnsureViewState()

    SVAR targetDFPath = $(LJZ_MDCWB_BaseDF() + ":TargetDF")
    SVAR/Z defaultRunDF = root:ARPES_LJZ:MDCFit:RunDF

    if (SVAR_Exists(defaultRunDF))
        if (strlen(defaultRunDF) > 0)
            targetDFPath = defaultRunDF
        endif
    endif

    LJZ_MDCWB_RebuildLB()
    return 0
End

Proc LJZ_MDCWB_OpenPanel()
    LJZ_MDCWB_InitPanelState()

    DoWindow/F MDCIFit_LJZ_Panel
    if (V_flag == 0)
        LJZ_MDCWB_Panel()
    endif
End


// ============================================================================
//  Section 8. Panel definition
// ============================================================================

Window LJZ_MDCWB_Panel() : Panel
    PauseUpdate; Silent 1
    NewPanel /W=(120,60,940,650) /N=MDCIFit_LJZ_Panel as "MDC Workbench"
    ModifyPanel frameStyle=1

    TitleBox tbT,pos={12,8},size={250,18},title="Target DF (default: ShowMDC runDF)",frame=0

    SetVariable svTarget,pos={12,28},size={500,20},proc=LJZ_MDCWB_SetVarProc,title="DF:"
    SetVariable svTarget,value=_STR:""

    Button btnRebuild,pos={525,27},size={95,22},proc=LJZ_MDCWB_ButtonProc,title="Refresh"

    ListBox lbMDC,pos={12,58},size={220,520},proc=LJZ_MDCWB_LBProc
    ListBox lbMDC,listWave=$(LJZ_MDCWB_BaseDF() + ":LB_Disp")
    ListBox lbMDC,selWave=$(LJZ_MDCWB_BaseDF() + ":LB_Sel"),mode=1

    PopupMenu pmModel,pos={250,62},size={145,20},proc=LJZ_MDCWB_ModelPopProc,title="Model:"
    PopupMenu pmModel,mode=1,popvalue="1PV",value=#"\"1PV;2PV;1Lor(eta=1 hold);1Gau(eta=0 hold);AsymPV+PV\""

    PopupMenu pmBG,pos={250,90},size={145,20},proc=LJZ_MDCWB_BGPopProc,title="BG:"
    PopupMenu pmBG,mode=3,popvalue="Quad",value=#"\"Const;Linear;Quad\""

    CheckBox cbCsr,pos={430,92},size={135,16},proc=LJZ_MDCWB_CheckProc,title="Read cursors A/B"
    CheckBox cbCsr,value=1

    SetVariable svXLo,pos={250,122},size={150,20},proc=LJZ_MDCWB_SetVarProc,title="xLo"
    SetVariable svXLo,value=_NUM:0

    SetVariable svXHi,pos={415,122},size={150,20},proc=LJZ_MDCWB_SetVarProc,title="xHi"
    SetVariable svXHi,value=_NUM:0

    Button btnGuess,pos={250,154},size={78,24},proc=LJZ_MDCWB_ButtonProc,title="Guess"
    Button btnFit,pos={336,154},size={78,24},proc=LJZ_MDCWB_ButtonProc,title="Fit"

    Button btnAccept,pos={430,154},size={72,24},proc=LJZ_MDCWB_ButtonProc,title="Accept"
    Button btnReject,pos={508,154},size={72,24},proc=LJZ_MDCWB_ButtonProc,title="Reject"
    Button btnClearMark,pos={586,154},size={82,24},proc=LJZ_MDCWB_ButtonProc,title="Clear"
    Button btnExport,pos={676,154},size={72,24},proc=LJZ_MDCWB_ButtonProc,title="Export"

    Button btnPrev,pos={428,62},size={55,24},proc=LJZ_MDCWB_ButtonProc,title="Prev"
    Button btnNext,pos={499,62},size={55,24},proc=LJZ_MDCWB_ButtonProc,title="Next"
    Button btnNextUnchecked,pos={565,62},size={105,24},proc=LJZ_MDCWB_ButtonProc,title="Next Unchecked"

    TitleBox tbPreviewHead,pos={250,186},size={80,18},title="Preview",frame=0,fStyle=1
    TitleBox tbParamHead,pos={250,402},size={90,18},title="Parameters",frame=0,fStyle=1

    TitleBox tbMetricHead,pos={740,12},size={70,20},title="Metrics",frame=0,fStyle=1
    GroupBox gbMetric,pos={740,36},size={235,210},title=""
    ListBox lbMetric,pos={750,48},size={215,190}
    ListBox lbMetric,listWave=$(LJZ_MDCWB_BaseDF() + ":MetricDisp")
    ListBox lbMetric,selWave=$(LJZ_MDCWB_BaseDF() + ":MetricSel"),mode=1

    TitleBox tbResHead,pos={740,258},size={85,20},title="Fit Result",frame=0,fStyle=1
    GroupBox gbRes,pos={740,282},size={235,300},title=""

    ListBox lbResL,pos={750,294},size={102,278}
    ListBox lbResL,listWave=$(LJZ_MDCWB_BaseDF() + ":ResDispL")
    ListBox lbResL,selWave=$(LJZ_MDCWB_BaseDF() + ":ResSelL"),mode=1

    ListBox lbResR,pos={862,294},size={102,278}
    ListBox lbResR,listWave=$(LJZ_MDCWB_BaseDF() + ":ResDispR")
    ListBox lbResR,selWave=$(LJZ_MDCWB_BaseDF() + ":ResSelR"),mode=1

    LJZ_MDCWB_CreatePreviewGraph()
    LJZ_MDCWB_BuildParamControls()
    LJZ_MDCWB_SetParamLayout()
    LJZ_MDCWB_RefreshParamControls()
    LJZ_MDCWB_RefreshPreviewGraph()
    LJZ_MDCWB_RefreshMetricBox()
EndMacro


// ============================================================================
//  Section 9. Callback adapters
// ============================================================================

Function LJZ_MDCWB_LBProc(listBoxAction) : ListBoxControl
    STRUCT WMListboxAction &listBoxAction

    if (listBoxAction.eventCode != 4)
        return 0
    endif
    if (listBoxAction.row < 0)
        return 0
    endif

    NVAR currentRow = $(LJZ_MDCWB_BaseDF() + ":CurRow")
    if (listBoxAction.row == currentRow)
        return 0
    endif

    if (!LJZ_MDCWB_ConfirmLeaveIfDirty())
        LJZ_MDCWB_RestoreCurrentSelectionUI()
        return 0
    endif

    LJZ_MDCWB_SelectCurrentRow(listBoxAction.row)
    LJZ_MDCWB_RefreshParamControls()
    LJZ_MDCWB_RefreshPreviewGraph()
    LJZ_MDCWB_RefreshMetricBox()

    return 0
End

Function LJZ_MDCWB_ModelPopProc(controlName, popNum, popStr) : PopupMenuControl
    String controlName
    Variable popNum
    String popStr

    NVAR editModelID = $(LJZ_MDCWB_BaseDF() + ":EditModelID")
    Variable oldModelID = editModelID

    // OP-FLOW HAZARD: never overwrite dirty edits with a new model choice without the same confirmation used for row changes.
    if (LJZ_MDCWB_IsDirty() && popNum != oldModelID)
        if (!LJZ_MDCWB_ConfirmLeaveIfDirty())
            LJZ_MDCWB_RefreshParamControls()
            return 0
        endif
    endif

    if (LJZ_MDCWB_ChangeModel(popNum) != 0)
        Beep
        DoAlert 0, "Changing model failed."
        LJZ_MDCWB_RefreshParamControls()
        return 0
    endif

    LJZ_MDCWB_RefreshCurrentRowDisplayMark()
    LJZ_MDCWB_RefreshParamControls()
    LJZ_MDCWB_RefreshPreviewGraph()
    LJZ_MDCWB_RefreshMetricBox()

    return 0
End

Function LJZ_MDCWB_BGPopProc(controlName, popNum, popStr) : PopupMenuControl
    String controlName
    Variable popNum
    String popStr

    NVAR editBGOrder = $(LJZ_MDCWB_BaseDF() + ":EditBGOrder")
    Variable oldBGOrder = editBGOrder

    // OP-FLOW HAZARD: background changes must not silently discard dirty preview edits.
    if (LJZ_MDCWB_IsDirty() && (popNum - 1) != oldBGOrder)
        if (!LJZ_MDCWB_ConfirmLeaveIfDirty())
            LJZ_MDCWB_RefreshParamControls()
            return 0
        endif
    endif

    if (LJZ_MDCWB_ChangeBG(popNum - 1) != 0)
        Beep
        DoAlert 0, "Changing background failed."
        LJZ_MDCWB_RefreshParamControls()
        return 0
    endif

    LJZ_MDCWB_RefreshCurrentRowDisplayMark()
    LJZ_MDCWB_RefreshParamControls()
    LJZ_MDCWB_RefreshPreviewGraph()
    LJZ_MDCWB_RefreshMetricBox()

    return 0
End

Function LJZ_MDCWB_SetVarProc(setVarAction) : SetVariableControl
    STRUCT WMSetVariableAction &setVarAction

// FIX: svTarget stays commit-only; edit fields must not rebuild on live update.
if (StringMatch(setVarAction.ctrlName, "svTarget"))
    if (setVarAction.eventCode != 1 && setVarAction.eventCode != 2)
        return 0
    endif
else
    if ((StringMatch(setVarAction.ctrlName, "svP*") || StringMatch(setVarAction.ctrlName, "svXLo") || StringMatch(setVarAction.ctrlName, "svXHi")) && setVarAction.eventCode == 3)
        return 0
    endif
    switch (setVarAction.eventCode)
        case 1:     // mouse up
        case 2:     // enter key
            break
        default:
            return 0
    endswitch
endif

LJZ_MDCWB_EnsureViewState()

    if (StringMatch(setVarAction.ctrlName, "svTarget"))
        SVAR targetDFPath = $(LJZ_MDCWB_BaseDF() + ":TargetDF")

        if (cmpstr(targetDFPath, setVarAction.sval) != 0)
            if (!LJZ_MDCWB_ConfirmLeaveIfDirty())
                LJZ_MDCWB_RefreshParamControls()
                return 0
            endif
        endif

        targetDFPath = setVarAction.sval
        LJZ_MDCWB_RebuildLB()
        LJZ_MDCWB_RefreshParamControls()
        LJZ_MDCWB_RefreshPreviewGraph()
        LJZ_MDCWB_RefreshMetricBox()
        return 0
    endif

if (StringMatch(setVarAction.ctrlName, "svXLo"))
    if (numtype(setVarAction.dval) != 0)
        return 0
    endif

    NVAR editXLo = $(LJZ_MDCWB_BaseDF() + ":EditXLo")
    editXLo = setVarAction.dval
    LJZ_MDCWB_MarkDirty(1)
    if (LJZ_MDCWB_BuildGuessForCurrentWave() != 0)
        LJZ_MDCWB_HandleGuessBuildFailure("ROI update failed.")
    endif
    LJZ_MDCWB_RefreshCurrentRowDisplayMark()
    LJZ_MDCWB_RefreshParamControls()
    LJZ_MDCWB_RefreshPreviewGraph()
    LJZ_MDCWB_RefreshMetricBox()
    return 0
endif

if (StringMatch(setVarAction.ctrlName, "svXHi"))
    if (numtype(setVarAction.dval) != 0)
        return 0
    endif

    NVAR editXHi = $(LJZ_MDCWB_BaseDF() + ":EditXHi")
    editXHi = setVarAction.dval
    LJZ_MDCWB_MarkDirty(1)
    if (LJZ_MDCWB_BuildGuessForCurrentWave() != 0)
        LJZ_MDCWB_HandleGuessBuildFailure("ROI update failed.")
    endif
    LJZ_MDCWB_RefreshCurrentRowDisplayMark()
    LJZ_MDCWB_RefreshParamControls()
    LJZ_MDCWB_RefreshPreviewGraph()
    LJZ_MDCWB_RefreshMetricBox()
    return 0
endif

if (StringMatch(setVarAction.ctrlName, "svP*"))
    if (numtype(setVarAction.dval) != 0)
        return 0
    endif

    Variable paramIndex = LJZ_MDCWB_ParseSuffixIndex(setVarAction.ctrlName, "svP")
    if (numtype(paramIndex) == 0 && paramIndex >= 0 && paramIndex < 12)
        Wave editParWave = $(LJZ_MDCWB_BaseDF() + ":EditPar")
        editParWave[paramIndex] = setVarAction.dval

        // FIX: sanitize/build/refresh only on committed edits, never during live typing.
        LJZ_MDCWB_SanitizeCurrentEditPar()
        LJZ_MDCWB_MarkDirty(1)
        if (LJZ_MDCWB_BuildGuessForCurrentWave() != 0)
            LJZ_MDCWB_HandleGuessBuildFailure("Parameter update failed.")
        endif
        LJZ_MDCWB_RefreshCurrentRowDisplayMark()
        LJZ_MDCWB_RefreshParamControls()
        LJZ_MDCWB_RefreshPreviewGraph()
        LJZ_MDCWB_RefreshMetricBox()
    endif
    return 0
endif

    return 0
End

Function LJZ_MDCWB_CheckProc(checkBoxAction) : CheckBoxControl
    STRUCT WMCheckboxAction &checkBoxAction

    if (checkBoxAction.eventCode != 2)
        return 0
    endif

    LJZ_MDCWB_EnsureViewState()

    if (StringMatch(checkBoxAction.ctrlName, "cbCsr"))
        NVAR useCursorsFlag = $(LJZ_MDCWB_BaseDF() + ":UseCursors")
        useCursorsFlag = checkBoxAction.checked
        LJZ_MDCWB_RefreshParamControls()
        LJZ_MDCWB_RefreshMetricBox()
        return 0
    endif

    if (StringMatch(checkBoxAction.ctrlName, "cbH*"))
        Variable paramIndex = LJZ_MDCWB_ParseSuffixIndex(checkBoxAction.ctrlName, "cbH")
        if (numtype(paramIndex) == 0 && paramIndex >= 0 && paramIndex < 12)
            Wave editHoldWave = $(LJZ_MDCWB_BaseDF() + ":EditHold")
            editHoldWave[paramIndex] = checkBoxAction.checked

            LJZ_MDCWB_MarkDirty(1)
            if (LJZ_MDCWB_BuildGuessForCurrentWave() != 0)
                LJZ_MDCWB_HandleGuessBuildFailure("Hold update failed.")
            endif
            LJZ_MDCWB_RefreshCurrentRowDisplayMark()
            LJZ_MDCWB_RefreshParamControls()
            LJZ_MDCWB_RefreshPreviewGraph()
            LJZ_MDCWB_RefreshMetricBox()
        endif
        return 0
    endif

    return 0
End

Function LJZ_MDCWB_ButtonProc(buttonAction) : ButtonControl
    STRUCT WMButtonAction &buttonAction

    if (buttonAction.eventCode != 2)
        return 0
    endif

    buttonAction.blockReentry = 1

    if (StringMatch(buttonAction.ctrlName, "btnRebuild"))
        if (!LJZ_MDCWB_ConfirmLeaveIfDirty())
            return 0
        endif
        LJZ_MDCWB_RebuildLB()
        LJZ_MDCWB_RefreshParamControls()
        LJZ_MDCWB_RefreshPreviewGraph()
        LJZ_MDCWB_RefreshMetricBox()
        return 0
    endif

    if (StringMatch(buttonAction.ctrlName, "btnGuess"))
        LJZ_MDCWB_ApplyROIFromPreviewCursorsIfWanted()
        if (LJZ_MDCWB_BuildGuessForCurrentWave() != 0)
            LJZ_MDCWB_HandleGuessBuildFailure("Guess rebuild failed.")
        endif
        LJZ_MDCWB_RefreshCurrentRowDisplayMark()
        LJZ_MDCWB_RefreshParamControls()
        LJZ_MDCWB_RefreshPreviewGraph()
        LJZ_MDCWB_RefreshMetricBox()
        return 0
    endif

    if (StringMatch(buttonAction.ctrlName, "btnFit"))
        LJZ_MDCWB_ApplyROIFromPreviewCursorsIfWanted()

        Variable fitReturnCode = LJZ_MDCWB_CommitFitForCurrentWave()
        if (fitReturnCode != 0)
            String fitErrorMsg = LJZ_MDCWB_GetLastError()
            if (strlen(fitErrorMsg) <= 0)
                fitErrorMsg = "Fit failed."
            endif
            Beep
            DoAlert 0, fitErrorMsg
        endif

        LJZ_MDCWB_RebuildLB()
        LJZ_MDCWB_RestoreCurrentSelectionUI()
        LJZ_MDCWB_RefreshParamControls()
        LJZ_MDCWB_RefreshPreviewGraph()
        LJZ_MDCWB_RefreshMetricBox()
        return 0
    endif

    if (StringMatch(buttonAction.ctrlName, "btnAccept"))
        if (LJZ_MDCWB_IsDirty())
            Beep
            DoAlert 0, "Current fit is stale. Please fit again before Accept."
            return 0
        endif

        LJZ_MDCWB_SetCurrentRowStateMark(1)
        LJZ_MDCWB_RefreshMetricBox()
        return 0
    endif

    if (StringMatch(buttonAction.ctrlName, "btnReject"))
        if (LJZ_MDCWB_IsDirty())
            Beep
            DoAlert 0, "Current fit is stale. Please fit again before Reject."
            return 0
        endif

        LJZ_MDCWB_SetCurrentRowStateMark(-1)
        LJZ_MDCWB_RefreshMetricBox()
        return 0
    endif

    if (StringMatch(buttonAction.ctrlName, "btnClearMark"))
        if (LJZ_MDCWB_IsDirty())
            Beep
            DoAlert 0, "Current fit is stale. Please fit again before changing mark."
            return 0
        endif

        LJZ_MDCWB_SetCurrentRowStateMark(0)
        LJZ_MDCWB_RefreshMetricBox()
        return 0
    endif

    if (StringMatch(buttonAction.ctrlName, "btnExport"))
        if (LJZ_MDCWB_IsDirty())
            // OP-FLOW HAZARD: export uses last clean saved records, never the current dirty preview.
            DoAlert 1, "Current preview is dirty. Export uses the last clean saved fit records, not the current dirty preview. Continue?"
            if (V_flag != 1)
                return 0
            endif
        endif
        LJZ_MDCWB_ExportSummary()
        return 0
    endif

    if (StringMatch(buttonAction.ctrlName, "btnPrev") || StringMatch(buttonAction.ctrlName, "btnNext"))
        Wave/T listPathWave = $(LJZ_MDCWB_BaseDF() + ":LB_Path")
        if (numpnts(listPathWave) <= 0)
            return 0
        endif

        NVAR currentRow = $(LJZ_MDCWB_BaseDF() + ":CurRow")

        Variable stepValue = -1
        if (StringMatch(buttonAction.ctrlName, "btnNext"))
            stepValue = 1
        endif

        Variable newRowValue = currentRow + stepValue
        newRowValue = max(0, min(numpnts(listPathWave)-1, newRowValue))

        if (newRowValue == currentRow)
            return 0
        endif

        if (!LJZ_MDCWB_ConfirmLeaveIfDirty())
            return 0
        endif

        LJZ_MDCWB_SelectCurrentRow(newRowValue)
        LJZ_MDCWB_RefreshParamControls()
        LJZ_MDCWB_RefreshPreviewGraph()
        LJZ_MDCWB_RefreshMetricBox()
        return 0
    endif

    if (StringMatch(buttonAction.ctrlName, "btnNextUnchecked"))
        NVAR currentRow2 = $(LJZ_MDCWB_BaseDF() + ":CurRow")
        Variable nextUncheckedRow = LJZ_MDCWB_FindNextUnchecked(currentRow2)

        if (nextUncheckedRow >= 0)
            if (!LJZ_MDCWB_ConfirmLeaveIfDirty())
                return 0
            endif

            LJZ_MDCWB_SelectCurrentRow(nextUncheckedRow)
            LJZ_MDCWB_RefreshParamControls()
            LJZ_MDCWB_RefreshPreviewGraph()
            LJZ_MDCWB_RefreshMetricBox()
        else
            Beep
            DoAlert 0, "No unchecked MDC after current row."
        endif

        return 0
    endif

    return 0
End


// ============================================================================
//  Section 10. Export helpers
// ============================================================================
Function LJZ_MDCWB_DeleteExportPreviewWaves(exportDFPath)
    String exportDFPath

    exportDFPath = RemoveEnding(exportDFPath, ":") + ":"
    if (!DataFolderExists(exportDFPath))
        return 0
    endif

    Variable iObj, nObj
    nObj = CountObjects(exportDFPath, 1)

    for (iObj = nObj - 1; iObj >= 0; iObj -= 1)
        String nm = GetIndexedObjName(exportDFPath, 1, iObj)
        if (StringMatch(nm, "layer_show_*") || StringMatch(nm, "fit_layer_*"))
            KillWaves/Z $(exportDFPath + nm)
        endif
    endfor

    return 0
End
// 若你环境里已有 LJZ_HWHM_eff / LJZ_PVArea_FromCoef，就优先用已有的。
// 这里给本模块一个自洽 fallback 版本，避免 export 依赖外部旧代码逻辑。

Function LJZ_MDCWB_HWHM_eff_Local(widthFreeInput, resHInput)
    Variable widthFreeInput, resHInput

    Variable widthFreeLocal = max(0, widthFreeInput)
    Variable resHLocal = max(0, resHInput)

    return sqrt(widthFreeLocal^2 + resHLocal^2)
End

Function LJZ_MDCWB_PVArea_FromCoef_Local(heightInput, widthFreeInput, etaInput, resHInput)
    Variable heightInput, widthFreeInput, etaInput, resHInput

    Variable effHWHM = LJZ_MDCWB_HWHM_eff_Local(widthFreeInput, resHInput)
    Variable etaLocal = min(1, max(0, etaInput))

    Variable lorArea = pi * abs(heightInput) * effHWHM
    Variable gauArea = sqrt(pi / ln(2)) * abs(heightInput) * effHWHM

    return etaLocal * lorArea + (1 - etaLocal) * gauArea
End


// ============================================================================
//  Section 11. Export summary
// ============================================================================

Function LJZ_MDCWB_ExportSummary()
    LJZ_MDCWB_EnsureViewState()

    SVAR targetDFPath = $(LJZ_MDCWB_BaseDF() + ":TargetDF")
    String normalizedDFPath = LJZ_MDCWB_NormDFPath(targetDFPath)

    if (strlen(normalizedDFPath) == 0)
        DoAlert 0, "Target DF is invalid."
        return -1
    endif

    String mdcWaveList = LJZ_MDCWB_ListMDCWaves(normalizedDFPath)
    Variable listCount = ItemsInList(mdcWaveList, ";")
    if (listCount <= 0)
        DoAlert 0, "No MDC waves found."
        return -1
    endif

    String originalDF = GetDataFolder(1)

String exportDFPath = RemoveEnding(normalizedDFPath, ":") + ":FIT_HP"
NewDataFolder/O $exportDFPath
LJZ_MDCWB_DeleteExportPreviewWaves(exportDFPath)
SetDataFolder $exportDFPath

Make/O/N=(listCount) MDCIndex
Make/O/N=(listCount) Peak1K, Peak2K, Peak3K
Make/O/N=(listCount) SigmaP1K, SigmaP2K, SigmaP3K
Make/O/N=(listCount) AreaP1K, AreaP2K, AreaP3K
Make/O/N=(listCount) AreaSum12K, Sep12K
Make/O/N=(listCount) WeffP1K, WeffP2K, WeffP3K
Make/O/N=(listCount) BG_c0, BG_c1, BG_c2
MDCIndex = NaN
    Peak1K = NaN
    Peak2K = NaN
    Peak3K = NaN
    SigmaP1K = NaN
    SigmaP2K = NaN
    SigmaP3K = NaN
    AreaP1K = NaN
    AreaP2K = NaN
    AreaP3K = NaN
    AreaSum12K = NaN
    Sep12K = NaN
    WeffP1K = NaN
    WeffP2K = NaN
    WeffP3K = NaN
    BG_c0 = NaN
    BG_c1 = NaN
    BG_c2 = NaN

    Variable listIndex
    Variable skippedCount = 0
    for (listIndex = 0; listIndex < listCount; listIndex += 1)
        String fullWavePath = StringFromList(listIndex, mdcWaveList, ";")
        Wave/Z dataWave = $fullWavePath
        if (!WaveExists(dataWave))
            continue
        endif

        String waveNameLocal = NameOfWave(dataWave)

Variable exportIndex = LJZ_MDCWB_ParseMDCIndex(waveNameLocal)
if (exportIndex < 0)
    exportIndex = listIndex
endif

MDCIndex[listIndex] = exportIndex

        Duplicate/O dataWave, $("layer_show_" + Num2Str(exportIndex))

        Wave/Z coefWave = $(LJZ_MDCWB_ResultCoefPath(dataWave))
        Wave/Z sigmaWave = $(LJZ_MDCWB_ResultSigmaPath(dataWave))
        Wave/Z infoWave = $(LJZ_MDCWB_ResultInfoPath(dataWave))
        Wave/Z fitWave = $(LJZ_MDCWB_ResultFitPath(dataWave))
        Wave/Z resWave = $(LJZ_MDCWB_ResultResPath(dataWave))

        // FIX: skip incomplete or stale records instead of exporting half-records.
        if (!WaveExists(infoWave))
            skippedCount += 1
            continue
        endif
        if (numpnts(infoWave) < 12 || numtype(infoWave[4]) != 0 || infoWave[4] != 1)
            skippedCount += 1
            continue
        endif
        if (!WaveExists(coefWave) || numpnts(coefWave) != 12)
            skippedCount += 1
            continue
        endif
        if (!WaveExists(sigmaWave) || numpnts(sigmaWave) != 12)
            skippedCount += 1
            continue
        endif
        if (!WaveExists(fitWave) || !WaveExists(resWave))
            skippedCount += 1
            continue
        endif

        if (WaveExists(fitWave))
            Duplicate/O fitWave, $("fit_layer_" + Num2Str(exportIndex))
        endif

        Variable modelIDLocal = round(infoWave[0])

        if (numpnts(coefWave) >= 3)
            BG_c0[listIndex] = coefWave[0]
            BG_c1[listIndex] = coefWave[1]
            BG_c2[listIndex] = coefWave[2]
        endif

        // ---------- model 5 : AsymPV + PV ----------
        if (modelIDLocal == 5 && numpnts(coefWave) >= 12)
            Variable asymHeight = coefWave[3]
            Variable asymCenter = coefWave[4]
            Variable asymLeftWidth = max(0, coefWave[5])
            Variable asymRightWidth = max(0, coefWave[6])

            Variable symHeight = coefWave[7]
            Variable symCenter = coefWave[8]
            Variable symWidth = max(0, coefWave[9])

            Variable sharedEta = coefWave[10]
            Variable sharedResH = max(0, coefWave[11])

            Variable leftEffWidth = LJZ_MDCWB_HWHM_eff_Local(asymLeftWidth, sharedResH)
            Variable rightEffWidth = LJZ_MDCWB_HWHM_eff_Local(asymRightWidth, sharedResH)

            Peak1K[listIndex] = asymCenter
            Peak2K[listIndex] = symCenter

            WeffP1K[listIndex] = 0.5 * (leftEffWidth + rightEffWidth)
            WeffP2K[listIndex] = LJZ_MDCWB_HWHM_eff_Local(symWidth, sharedResH)

            Variable leftAreaLocal = LJZ_MDCWB_PVArea_FromCoef_Local(asymHeight, asymLeftWidth, sharedEta, sharedResH)
            Variable rightAreaLocal = LJZ_MDCWB_PVArea_FromCoef_Local(asymHeight, asymRightWidth, sharedEta, sharedResH)

            AreaP1K[listIndex] = 0.5 * (leftAreaLocal + rightAreaLocal)
            AreaP2K[listIndex] = LJZ_MDCWB_PVArea_FromCoef_Local(symHeight, symWidth, sharedEta, sharedResH)

            AreaSum12K[listIndex] = AreaP1K[listIndex] + AreaP2K[listIndex]
            Sep12K[listIndex] = abs(symCenter - asymCenter)

            if (WaveExists(sigmaWave) && numpnts(sigmaWave) >= 12)
                SigmaP1K[listIndex] = sigmaWave[4]
                SigmaP2K[listIndex] = sigmaWave[8]
            endif

        // ---------- model 2 : 2PV ----------
        elseif (modelIDLocal == 2 && numpnts(coefWave) >= 12)
            Variable peak1Height = coefWave[3]
            Variable peak1Center = coefWave[4]
            Variable peak1Width = max(0, coefWave[5])
            Variable peak1Eta = coefWave[6]

            Variable peak2Height = coefWave[7]
            Variable peak2Center = coefWave[8]
            Variable peak2Width = max(0, coefWave[9])
            Variable peak2Eta = coefWave[10]

            Variable sharedResH2 = max(0, coefWave[11])

            if (peak1Center <= peak2Center)
                Peak1K[listIndex] = peak1Center
                Peak2K[listIndex] = peak2Center

                WeffP1K[listIndex] = LJZ_MDCWB_HWHM_eff_Local(peak1Width, sharedResH2)
                WeffP2K[listIndex] = LJZ_MDCWB_HWHM_eff_Local(peak2Width, sharedResH2)

                AreaP1K[listIndex] = LJZ_MDCWB_PVArea_FromCoef_Local(peak1Height, peak1Width, peak1Eta, sharedResH2)
                AreaP2K[listIndex] = LJZ_MDCWB_PVArea_FromCoef_Local(peak2Height, peak2Width, peak2Eta, sharedResH2)

                if (WaveExists(sigmaWave) && numpnts(sigmaWave) >= 12)
                    SigmaP1K[listIndex] = sigmaWave[4]
                    SigmaP2K[listIndex] = sigmaWave[8]
                endif
            else
                Peak1K[listIndex] = peak2Center
                Peak2K[listIndex] = peak1Center

                WeffP1K[listIndex] = LJZ_MDCWB_HWHM_eff_Local(peak2Width, sharedResH2)
                WeffP2K[listIndex] = LJZ_MDCWB_HWHM_eff_Local(peak1Width, sharedResH2)

                AreaP1K[listIndex] = LJZ_MDCWB_PVArea_FromCoef_Local(peak2Height, peak2Width, peak2Eta, sharedResH2)
                AreaP2K[listIndex] = LJZ_MDCWB_PVArea_FromCoef_Local(peak1Height, peak1Width, peak1Eta, sharedResH2)

                if (WaveExists(sigmaWave) && numpnts(sigmaWave) >= 12)
                    SigmaP1K[listIndex] = sigmaWave[8]
                    SigmaP2K[listIndex] = sigmaWave[4]
                endif
            endif

            AreaSum12K[listIndex] = AreaP1K[listIndex] + AreaP2K[listIndex]
            Sep12K[listIndex] = abs(Peak2K[listIndex] - Peak1K[listIndex])

        // ---------- single peak models ----------
        else
            if (numpnts(coefWave) >= 8)
                Variable singleHeight = coefWave[3]
                Variable singleCenter = coefWave[4]
                Variable singleWidth = max(0, coefWave[5])
                Variable singleEta = coefWave[6]
                Variable singleResH = max(0, coefWave[7])

                Peak3K[listIndex] = singleCenter
                WeffP3K[listIndex] = LJZ_MDCWB_HWHM_eff_Local(singleWidth, singleResH)
                AreaP3K[listIndex] = LJZ_MDCWB_PVArea_FromCoef_Local(singleHeight, singleWidth, singleEta, singleResH)

                if (WaveExists(sigmaWave) && numpnts(sigmaWave) >= 8)
                    SigmaP3K[listIndex] = sigmaWave[4]
                endif
            endif
        endif
    endfor

    SetDataFolder $originalDF
    DoAlert 0, "FIT_HP exported under: " + exportDFPath + ":\rSkipped incomplete/stale records: " + Num2Str(skippedCount)

    return 0
End
