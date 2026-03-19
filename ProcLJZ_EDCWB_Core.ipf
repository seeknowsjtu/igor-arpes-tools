#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  LJZ_EDCWB Core / Record
//  只负责：
//    1) package runtime state
//    2) source/result path helpers
//    3) per-wave fit record read/write
//    4) accept/reject state
//
//  不负责：
//    - panel / callbacks
//    - model bank
//    - preprocess / auto guess / fit engine
//    - summary export
// ============================================================================


// ============================================================================
//  Section 0. Base path / basic helpers
// ============================================================================

Function/S LJZ_EDCWB_BaseDF()
    return "root:Packages:ARPES_LJZ:EDCWB"
End

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

Function/S LJZ_EDCWB_WaveNameFromPath(wPath)
    String wPath

    Variable p
    p = strsearch(wPath, ":", Inf)
    if (p < 0)
        return ""
    endif

    return wPath[p + 1, Inf]
End

Function/S LJZ_EDCWB_WaveDFFromPath(wPath)
    String wPath

    Variable p
    p = strsearch(wPath, ":", Inf)
    if (p < 0)
        return ""
    endif

    return wPath[0, p]
End

Function LJZ_EDCWB_Is1DWave(w)
    Wave/Z w

    if (!WaveExists(w))
        return 0
    endif

    if (DimSize(w, 1) > 0 || DimSize(w, 2) > 0 || DimSize(w, 3) > 0)
        return 0
    endif

    return 1
End

Function LJZ_EDCWB_EnsureNumWaveLen12(w, fillVal)
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

Function LJZ_EDCWB_EnsureNumWaveLen16(w, fillVal)
    Wave w
    Variable fillVal

    Variable oldN = numpnts(w)
    if (oldN != 16)
        Redimension/N=16 w
        if (oldN < 16)
            w[oldN, 15] = fillVal
        endif
    endif

    return 0
End

Function LJZ_EDCWB_EnsureTextWaveLen12(w, fillStr)
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
//  Section 1. fitinfo schema indices
// ============================================================================

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

Function LJZ_EDCWB_FI_ChiSq()
    return 6
End

Function LJZ_EDCWB_FI_MaxAbsRes()
    return 7
End

Function LJZ_EDCWB_FI_NROI()
    return 8
End

Function LJZ_EDCWB_FI_Temperature()
    return 9
End

Function LJZ_EDCWB_FI_Resolution()
    return 10
End

Function LJZ_EDCWB_FI_EFermi()
    return 11
End

Function LJZ_EDCWB_FI_NormMode()
    return 12
End

Function LJZ_EDCWB_FI_SmoothUsed()
    return 13
End

Function LJZ_EDCWB_FI_Reserved14()
    return 14
End

Function LJZ_EDCWB_FI_Reserved15()
    return 15
End


// ============================================================================
//  Section 2. Package runtime state
// ============================================================================

Function LJZ_EDCWB_EnsureDF()
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:ARPES_LJZ
    NewDataFolder/O $(LJZ_EDCWB_BaseDF())

    LJZ_EDCWB_EnsureRuntimeState()
    return 0
End

Function LJZ_EDCWB_EnsureRuntimeState()
    String base = LJZ_EDCWB_BaseDF()

    // ---------- target / current selection ----------
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

    NVAR/Z eXLo = $(base + ":EditXLo")
    if (!NVAR_Exists(eXLo))
        Variable/G $(base + ":EditXLo") = NaN
    endif

    NVAR/Z eXHi = $(base + ":EditXHi")
    if (!NVAR_Exists(eXHi))
        Variable/G $(base + ":EditXHi") = NaN
    endif

    NVAR/Z isDirty = $(base + ":Dirty")
    if (!NVAR_Exists(isDirty))
        Variable/G $(base + ":Dirty") = 0
    endif

    // ---------- preprocess / aux ----------
    NVAR/Z smEn = $(base + ":SmoothEnable")
    if (!NVAR_Exists(smEn))
        Variable/G $(base + ":SmoothEnable") = 0
    endif

    NVAR/Z smMethod = $(base + ":SmoothMethod")
    if (!NVAR_Exists(smMethod))
        Variable/G $(base + ":SmoothMethod") = 0
    endif

    NVAR/Z smP1 = $(base + ":SmoothParam1")
    if (!NVAR_Exists(smP1))
        Variable/G $(base + ":SmoothParam1") = 5
    endif

    NVAR/Z smP2 = $(base + ":SmoothParam2")
    if (!NVAR_Exists(smP2))
        Variable/G $(base + ":SmoothParam2") = 2
    endif

    NVAR/Z shRaw = $(base + ":ShowRaw")
    if (!NVAR_Exists(shRaw))
        Variable/G $(base + ":ShowRaw") = 1
    endif

    NVAR/Z shSm = $(base + ":ShowSmooth")
    if (!NVAR_Exists(shSm))
        Variable/G $(base + ":ShowSmooth") = 0
    endif

    NVAR/Z shGuess = $(base + ":ShowGuess")
    if (!NVAR_Exists(shGuess))
        Variable/G $(base + ":ShowGuess") = 1
    endif

    NVAR/Z shFit = $(base + ":ShowFit")
    if (!NVAR_Exists(shFit))
        Variable/G $(base + ":ShowFit") = 1
    endif

    NVAR/Z shRes = $(base + ":ShowResidual")
    if (!NVAR_Exists(shRes))
        Variable/G $(base + ":ShowResidual") = 1
    endif

    NVAR/Z smGuess = $(base + ":UseSmoothForGuess")
    if (!NVAR_Exists(smGuess))
        Variable/G $(base + ":UseSmoothForGuess") = 1
    endif

    NVAR/Z fitOnSm = $(base + ":FitOnSmooth")
    if (!NVAR_Exists(fitOnSm))
        Variable/G $(base + ":FitOnSmooth") = 0
    endif

    // ---------- physical aux ----------
    NVAR/Z eTemp = $(base + ":EditTemperature")
    if (!NVAR_Exists(eTemp))
        Variable/G $(base + ":EditTemperature") = 10
    endif

    NVAR/Z eEF = $(base + ":EditEFermi")
    if (!NVAR_Exists(eEF))
        Variable/G $(base + ":EditEFermi") = 0
    endif

    NVAR/Z eRes = $(base + ":EditResolution")
    if (!NVAR_Exists(eRes))
        Variable/G $(base + ":EditResolution") = 0.01
    endif

    NVAR/Z eNorm = $(base + ":EditNormMode")
    if (!NVAR_Exists(eNorm))
        Variable/G $(base + ":EditNormMode") = 0
    endif

    // ---------- param edit waves ----------
    Wave/Z wPar = $(base + ":EditPar")
    if (!WaveExists(wPar))
        Make/O/N=12 $(base + ":EditPar") = NaN
    else
        LJZ_EDCWB_EnsureNumWaveLen12(wPar, NaN)
    endif

    Wave/Z wHold = $(base + ":EditHold")
    if (!WaveExists(wHold))
        Make/O/N=12 $(base + ":EditHold") = 0
    else
        LJZ_EDCWB_EnsureNumWaveLen12(wHold, 0)
    endif

    Wave/T/Z wParName = $(base + ":EditParName")
    if (!WaveExists(wParName))
        Make/O/T/N=12 $(base + ":EditParName") = ""
    else
        LJZ_EDCWB_EnsureTextWaveLen12(wParName, "")
    endif

    Wave/Z wParEn = $(base + ":EditParEnable")
    if (!WaveExists(wParEn))
        Make/O/N=12 $(base + ":EditParEnable") = 0
    else
        LJZ_EDCWB_EnsureNumWaveLen12(wParEn, 0)
    endif

    // ---------- listbox waves ----------
    Wave/T/Z wDisp = $(base + ":LB_Disp")
    if (!WaveExists(wDisp))
        Make/O/T/N=0 $(base + ":LB_Disp")
    endif

    Wave/Z wSel = $(base + ":LB_Sel")
    if (!WaveExists(wSel))
        Make/O/N=0 $(base + ":LB_Sel") = 0
    endif

    return 0
End


// ============================================================================
//  Section 3. runtime state helpers
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

Function LJZ_EDCWB_ClearEditState()
    LJZ_EDCWB_EnsureDF()

    NVAR eModel = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR eXLo   = $(LJZ_EDCWB_BaseDF() + ":EditXLo")
    NVAR eXHi   = $(LJZ_EDCWB_BaseDF() + ":EditXHi")
    NVAR eTemp  = $(LJZ_EDCWB_BaseDF() + ":EditTemperature")
    NVAR eEF    = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    NVAR eRes   = $(LJZ_EDCWB_BaseDF() + ":EditResolution")
    NVAR eNorm  = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")

    Wave ePar   = $(LJZ_EDCWB_BaseDF() + ":EditPar")
    Wave eHold  = $(LJZ_EDCWB_BaseDF() + ":EditHold")
    Wave/T pName = $(LJZ_EDCWB_BaseDF() + ":EditParName")
    Wave pEn     = $(LJZ_EDCWB_BaseDF() + ":EditParEnable")

    eModel = 1
    eXLo   = NaN
    eXHi   = NaN
    eTemp  = 10
    eEF    = 0
    eRes   = 0.01
    eNorm  = 0

    ePar  = NaN
    eHold = 0
    pName = ""
    pEn   = 0

    LJZ_EDCWB_MarkDirty(1)
    return 0
End

Function LJZ_EDCWB_SetCurrentWave(wPath, row)
    String wPath
    Variable row

    LJZ_EDCWB_EnsureDF()

    SVAR sPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR nRow  = $(LJZ_EDCWB_BaseDF() + ":CurRow")

    sPath = wPath
    nRow  = row

    return 0
End


// ============================================================================
//  Section 4. result naming helpers
// ============================================================================

Function/S LJZ_EDCWB_ResultBaseName(srcWavePath)
    String srcWavePath

    String nm = LJZ_EDCWB_WaveNameFromPath(srcWavePath)
    if (strlen(nm) == 0)
        return ""
    endif

    return nm
End

Function/S LJZ_EDCWB_ResultGuessPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_guess"
End

Function/S LJZ_EDCWB_ResultFitCoefPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_fitcoef"
End

Function/S LJZ_EDCWB_ResultFitSigmaPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_fitsigma"
End

Function/S LJZ_EDCWB_ResultFitInfoPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_fitinfo"
End

Function/S LJZ_EDCWB_ResultFitPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_fit"
End

Function/S LJZ_EDCWB_ResultResPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_res"
End

Function/S LJZ_EDCWB_ResultEditCoefPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_editsnapcoef"
End

Function/S LJZ_EDCWB_ResultEditInfoPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_editsnapinfo"
End

Function/S LJZ_EDCWB_ResultAcceptPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_accept"
End


// ============================================================================
//  Section 5. ensure standard per-wave record
// ============================================================================

Function LJZ_EDCWB_EnsureResultRecord(srcWavePath)
    String srcWavePath

    Wave/Z src = $srcWavePath
    if (!WaveExists(src))
        return -1
    endif
    if (!LJZ_EDCWB_Is1DWave(src))
        return -1
    endif

    Wave/Z wGuess = $(LJZ_EDCWB_ResultGuessPath(srcWavePath))
    if (!WaveExists(wGuess))
        Duplicate/O src, $(LJZ_EDCWB_ResultGuessPath(srcWavePath))
        Wave wGuess2 = $(LJZ_EDCWB_ResultGuessPath(srcWavePath))
        wGuess2 = NaN
    endif

    Wave/Z wFit = $(LJZ_EDCWB_ResultFitPath(srcWavePath))
    if (!WaveExists(wFit))
        Duplicate/O src, $(LJZ_EDCWB_ResultFitPath(srcWavePath))
        Wave wFit2 = $(LJZ_EDCWB_ResultFitPath(srcWavePath))
        wFit2 = NaN
    endif

    Wave/Z wRes = $(LJZ_EDCWB_ResultResPath(srcWavePath))
    if (!WaveExists(wRes))
        Duplicate/O src, $(LJZ_EDCWB_ResultResPath(srcWavePath))
        Wave wRes2 = $(LJZ_EDCWB_ResultResPath(srcWavePath))
        wRes2 = NaN
    endif

    Wave/Z wCoef = $(LJZ_EDCWB_ResultFitCoefPath(srcWavePath))
    if (!WaveExists(wCoef))
        Make/O/N=12 $(LJZ_EDCWB_ResultFitCoefPath(srcWavePath)) = NaN
    else
        LJZ_EDCWB_EnsureNumWaveLen12(wCoef, NaN)
    endif

    Wave/Z wSig = $(LJZ_EDCWB_ResultFitSigmaPath(srcWavePath))
    if (!WaveExists(wSig))
        Make/O/N=12 $(LJZ_EDCWB_ResultFitSigmaPath(srcWavePath)) = NaN
    else
        LJZ_EDCWB_EnsureNumWaveLen12(wSig, NaN)
    endif

    Wave/Z wInfo = $(LJZ_EDCWB_ResultFitInfoPath(srcWavePath))
    if (!WaveExists(wInfo))
        Make/O/N=16 $(LJZ_EDCWB_ResultFitInfoPath(srcWavePath)) = NaN
    else
        LJZ_EDCWB_EnsureNumWaveLen16(wInfo, NaN)
    endif

    Wave/Z wEditCoef = $(LJZ_EDCWB_ResultEditCoefPath(srcWavePath))
    if (!WaveExists(wEditCoef))
        Make/O/N=12 $(LJZ_EDCWB_ResultEditCoefPath(srcWavePath)) = NaN
    else
        LJZ_EDCWB_EnsureNumWaveLen12(wEditCoef, NaN)
    endif

    Wave/Z wEditInfo = $(LJZ_EDCWB_ResultEditInfoPath(srcWavePath))
    if (!WaveExists(wEditInfo))
        Make/O/N=16 $(LJZ_EDCWB_ResultEditInfoPath(srcWavePath)) = NaN
    else
        LJZ_EDCWB_EnsureNumWaveLen16(wEditInfo, NaN)
    endif

    Wave/Z wAcc = $(LJZ_EDCWB_ResultAcceptPath(srcWavePath))
    if (!WaveExists(wAcc))
        Make/O/N=1 $(LJZ_EDCWB_ResultAcceptPath(srcWavePath)) = 0
    else
        Redimension/N=1 wAcc
    endif

    return 0
End


// ============================================================================
//  Section 6. accept state read/write
// ============================================================================

Function LJZ_EDCWB_ReadAcceptState(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Wave/Z wAcc = $(LJZ_EDCWB_ResultAcceptPath(srcWavePath))
    if (!WaveExists(wAcc))
        return 0
    endif

    return wAcc[0]
End

Function LJZ_EDCWB_WriteAcceptState(srcWavePath, state)
    String srcWavePath
    Variable state

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Wave/Z wAcc = $(LJZ_EDCWB_ResultAcceptPath(srcWavePath))
    if (!WaveExists(wAcc))
        return -1
    endif

    wAcc[0] = state
    return 0
End


// ============================================================================
//  Section 7. save / clear curves and vectors
// ============================================================================

Function LJZ_EDCWB_SaveGuessCurve(srcWavePath, wGuessIn)
    String srcWavePath
    Wave/Z wGuessIn

    if (!WaveExists(wGuessIn))
        return -1
    endif

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Wave wGuess = $(LJZ_EDCWB_ResultGuessPath(srcWavePath))
    if (numpnts(wGuess) != numpnts(wGuessIn))
        Duplicate/O wGuessIn, wGuess
    else
        wGuess = wGuessIn[p]
    endif

    return 0
End

Function LJZ_EDCWB_SaveFitCurve(srcWavePath, wFitIn, wResIn)
    String srcWavePath
    Wave/Z wFitIn, wResIn

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    if (WaveExists(wFitIn))
        Wave wFit = $(LJZ_EDCWB_ResultFitPath(srcWavePath))
        if (numpnts(wFit) != numpnts(wFitIn))
            Duplicate/O wFitIn, wFit
        else
            wFit = wFitIn[p]
        endif
    endif

    if (WaveExists(wResIn))
        Wave wRes = $(LJZ_EDCWB_ResultResPath(srcWavePath))
        if (numpnts(wRes) != numpnts(wResIn))
            Duplicate/O wResIn, wRes
        else
            wRes = wResIn[p]
        endif
    endif

    return 0
End

Function LJZ_EDCWB_SaveFitVectors(srcWavePath, wCoefIn, wSigmaIn, wInfoIn)
    String srcWavePath
    Wave/Z wCoefIn, wSigmaIn, wInfoIn

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    if (WaveExists(wCoefIn))
        Wave wCoef = $(LJZ_EDCWB_ResultFitCoefPath(srcWavePath))
        LJZ_EDCWB_EnsureNumWaveLen12(wCoef, NaN)
        wCoef = NaN
        Variable n0 = min(11, numpnts(wCoefIn) - 1)
        if (n0 >= 0)
            wCoef[0, n0] = wCoefIn[p]
        endif
    endif

    if (WaveExists(wSigmaIn))
        Wave wSig = $(LJZ_EDCWB_ResultFitSigmaPath(srcWavePath))
        LJZ_EDCWB_EnsureNumWaveLen12(wSig, NaN)
        wSig = NaN
        Variable n1 = min(11, numpnts(wSigmaIn) - 1)
        if (n1 >= 0)
            wSig[0, n1] = wSigmaIn[p]
        endif
    endif

    if (WaveExists(wInfoIn))
        Wave wInfo = $(LJZ_EDCWB_ResultFitInfoPath(srcWavePath))
        LJZ_EDCWB_EnsureNumWaveLen16(wInfo, NaN)
        wInfo = NaN
        Variable n2 = min(15, numpnts(wInfoIn) - 1)
        if (n2 >= 0)
            wInfo[0, n2] = wInfoIn[p]
        endif
    endif

    return 0
End

Function LJZ_EDCWB_ClearStoredFitOutputs(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Wave/Z wFit = $(LJZ_EDCWB_ResultFitPath(srcWavePath))
    if (WaveExists(wFit))
        wFit = NaN
    endif

    Wave/Z wRes = $(LJZ_EDCWB_ResultResPath(srcWavePath))
    if (WaveExists(wRes))
        wRes = NaN
    endif

    Wave/Z wSig = $(LJZ_EDCWB_ResultFitSigmaPath(srcWavePath))
    if (WaveExists(wSig))
        LJZ_EDCWB_EnsureNumWaveLen12(wSig, NaN)
        wSig = NaN
    endif

    Wave/Z wInfo = $(LJZ_EDCWB_ResultFitInfoPath(srcWavePath))
    if (WaveExists(wInfo))
        LJZ_EDCWB_EnsureNumWaveLen16(wInfo, NaN)
        wInfo[LJZ_EDCWB_FI_FitOK()]     = NaN
        wInfo[LJZ_EDCWB_FI_FitRMSE()]   = NaN
        wInfo[LJZ_EDCWB_FI_ChiSq()]     = NaN
        wInfo[LJZ_EDCWB_FI_MaxAbsRes()] = NaN
        wInfo[LJZ_EDCWB_FI_NROI()]      = NaN
    endif

    return 0
End


// ============================================================================
//  Section 8. save / load edit-state record
// ============================================================================

Function LJZ_EDCWB_SaveCurrentEditSnapshot(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    NVAR eModel   = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR eXLo     = $(LJZ_EDCWB_BaseDF() + ":EditXLo")
    NVAR eXHi     = $(LJZ_EDCWB_BaseDF() + ":EditXHi")
    NVAR eTemp    = $(LJZ_EDCWB_BaseDF() + ":EditTemperature")
    NVAR eEF      = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    NVAR eRes     = $(LJZ_EDCWB_BaseDF() + ":EditResolution")
    NVAR eNorm    = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")
    NVAR fitOnSm  = $(LJZ_EDCWB_BaseDF() + ":FitOnSmooth")

    Wave ePar     = $(LJZ_EDCWB_BaseDF() + ":EditPar")
    Wave wCoef    = $(LJZ_EDCWB_ResultEditCoefPath(srcWavePath))
    Wave wInfo    = $(LJZ_EDCWB_ResultEditInfoPath(srcWavePath))

    LJZ_EDCWB_EnsureNumWaveLen12(wCoef, NaN)
    LJZ_EDCWB_EnsureNumWaveLen16(wInfo, NaN)

    wCoef = NaN
    wCoef = ePar[p]
    wInfo = NaN

    wInfo[LJZ_EDCWB_FI_ModelID()]     = eModel
    wInfo[LJZ_EDCWB_FI_XLo()]         = eXLo
    wInfo[LJZ_EDCWB_FI_XHi()]         = eXHi
    wInfo[LJZ_EDCWB_FI_Temperature()] = eTemp
    wInfo[LJZ_EDCWB_FI_Resolution()]  = eRes
    wInfo[LJZ_EDCWB_FI_EFermi()]      = eEF
    wInfo[LJZ_EDCWB_FI_NormMode()]    = eNorm
    wInfo[LJZ_EDCWB_FI_SmoothUsed()]  = fitOnSm

    return 0
End

// legacy compatibility name: this now stores only edit/guess snapshot,
// never the true fit result record.
Function LJZ_EDCWB_SaveCurrentEditToCoef(srcWavePath)
    String srcWavePath

    return LJZ_EDCWB_SaveCurrentEditSnapshot(srcWavePath)
End

Function LJZ_EDCWB_LoadRecordToEditState_Generic(srcWavePath, coefPath, infoPath)
    String srcWavePath, coefPath, infoPath

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Wave/Z wCoef = $coefPath
    Wave/Z wInfo = $infoPath
    if (!WaveExists(wCoef) || !WaveExists(wInfo))
        return -1
    endif

    NVAR eModel   = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR eXLo     = $(LJZ_EDCWB_BaseDF() + ":EditXLo")
    NVAR eXHi     = $(LJZ_EDCWB_BaseDF() + ":EditXHi")
    NVAR eTemp    = $(LJZ_EDCWB_BaseDF() + ":EditTemperature")
    NVAR eEF      = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    NVAR eRes     = $(LJZ_EDCWB_BaseDF() + ":EditResolution")
    NVAR eNorm    = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")
    NVAR fitOnSm  = $(LJZ_EDCWB_BaseDF() + ":FitOnSmooth")

    Wave ePar     = $(LJZ_EDCWB_BaseDF() + ":EditPar")

    if (numtype(wInfo[LJZ_EDCWB_FI_ModelID()]) == 0)
        eModel = wInfo[LJZ_EDCWB_FI_ModelID()]
    endif

    LJZ_EDCWB_SetParamLayout(eModel)
    LJZ_EDCWB_EnsureNumWaveLen12(ePar, NaN)
    ePar = wCoef[p]
    LJZ_EDCWB_FillNaNParsWithDefaults(eModel)
    LJZ_EDCWB_SanitizeParamWave(eModel, ePar)
    if (numtype(wInfo[LJZ_EDCWB_FI_XLo()]) == 0)
        eXLo = wInfo[LJZ_EDCWB_FI_XLo()]
    endif
    if (numtype(wInfo[LJZ_EDCWB_FI_XHi()]) == 0)
        eXHi = wInfo[LJZ_EDCWB_FI_XHi()]
    endif
    if (numtype(wInfo[LJZ_EDCWB_FI_Temperature()]) == 0)
        eTemp = wInfo[LJZ_EDCWB_FI_Temperature()]
    endif
    if (numtype(wInfo[LJZ_EDCWB_FI_EFermi()]) == 0)
        eEF = wInfo[LJZ_EDCWB_FI_EFermi()]
    endif
    if (numtype(wInfo[LJZ_EDCWB_FI_Resolution()]) == 0)
        eRes = wInfo[LJZ_EDCWB_FI_Resolution()]
    endif
    if (numtype(wInfo[LJZ_EDCWB_FI_NormMode()]) == 0)
        eNorm = wInfo[LJZ_EDCWB_FI_NormMode()]
    endif
    if (numtype(wInfo[LJZ_EDCWB_FI_SmoothUsed()]) == 0)
        fitOnSm = wInfo[LJZ_EDCWB_FI_SmoothUsed()]
    endif

    LJZ_EDCWB_SyncParToAuxState()
    LJZ_EDCWB_MarkDirty(0)
    return 0
End

Function LJZ_EDCWB_LoadFitRecordToEditState(srcWavePath)
    String srcWavePath

    return LJZ_EDCWB_LoadRecordToEditState_Generic(srcWavePath, LJZ_EDCWB_ResultFitCoefPath(srcWavePath), LJZ_EDCWB_ResultFitInfoPath(srcWavePath))
End

Function LJZ_EDCWB_LoadEditSnapshotToEditState(srcWavePath)
    String srcWavePath

    return LJZ_EDCWB_LoadRecordToEditState_Generic(srcWavePath, LJZ_EDCWB_ResultEditCoefPath(srcWavePath), LJZ_EDCWB_ResultEditInfoPath(srcWavePath))
End


// ============================================================================
//  Section 9. clear / detect existing record
// ============================================================================

Function LJZ_EDCWB_HasFitRecord(srcWavePath)
    String srcWavePath

    Wave/Z wCoef = $(LJZ_EDCWB_ResultFitCoefPath(srcWavePath))
    Wave/Z wInfo = $(LJZ_EDCWB_ResultFitInfoPath(srcWavePath))

    if (!WaveExists(wCoef) || !WaveExists(wInfo))
        return 0
    endif

    LJZ_EDCWB_EnsureNumWaveLen12(wCoef, NaN)
    LJZ_EDCWB_EnsureNumWaveLen16(wInfo, NaN)

    if (numtype(wInfo[LJZ_EDCWB_FI_ModelID()]) != 0)
        return 0
    endif
    if (numtype(wInfo[LJZ_EDCWB_FI_FitOK()]) != 0)
        return 0
    endif

    WaveStats/Q wCoef
    if (V_numNaNs >= numpnts(wCoef))
        return 0
    endif

    return 1
End

Function LJZ_EDCWB_HasEditSnapshot(srcWavePath)
    String srcWavePath

    Wave/Z wCoef = $(LJZ_EDCWB_ResultEditCoefPath(srcWavePath))
    Wave/Z wInfo = $(LJZ_EDCWB_ResultEditInfoPath(srcWavePath))

    if (!WaveExists(wCoef) || !WaveExists(wInfo))
        return 0
    endif

    LJZ_EDCWB_EnsureNumWaveLen12(wCoef, NaN)
    LJZ_EDCWB_EnsureNumWaveLen16(wInfo, NaN)

    if (numtype(wInfo[LJZ_EDCWB_FI_ModelID()]) != 0)
        return 0
    endif

    WaveStats/Q wCoef
    if (V_numNaNs >= numpnts(wCoef))
        return 0
    endif

    return 1
End

Function LJZ_EDCWB_ClearEditSnapshot(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Wave/Z wEditCoef = $(LJZ_EDCWB_ResultEditCoefPath(srcWavePath))
    if (WaveExists(wEditCoef))
        wEditCoef = NaN
    endif

    Wave/Z wEditInfo = $(LJZ_EDCWB_ResultEditInfoPath(srcWavePath))
    if (WaveExists(wEditInfo))
        wEditInfo = NaN
    endif

    return 0
End

Function LJZ_EDCWB_ClearFitRecord(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Wave wGuess = $(LJZ_EDCWB_ResultGuessPath(srcWavePath))
    Wave wCoef  = $(LJZ_EDCWB_ResultFitCoefPath(srcWavePath))
    Wave wSig   = $(LJZ_EDCWB_ResultFitSigmaPath(srcWavePath))
    Wave wInfo  = $(LJZ_EDCWB_ResultFitInfoPath(srcWavePath))
    Wave wFit   = $(LJZ_EDCWB_ResultFitPath(srcWavePath))
    Wave wRes   = $(LJZ_EDCWB_ResultResPath(srcWavePath))
    Wave wAcc   = $(LJZ_EDCWB_ResultAcceptPath(srcWavePath))

    wGuess = NaN
    wCoef  = NaN
    wSig   = NaN
    wInfo  = NaN
    wFit   = NaN
    wRes   = NaN
    wAcc[0] = 0
    LJZ_EDCWB_ClearEditSnapshot(srcWavePath)

    return 0
End
