#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma DefaultTab={3,20,4}

// ============================================================================
//  LJZ_EDCFermiFit : panel-inline Fermi-edge fit tool for existing edc_show_* waves
//  只负责：
//    1) 从当前 EDCExtract RunDF 或手动指定 DF 扫描 edc_show_*
//    2) 在 panel 内联 graph 中显示当前选中的 edc_show_i
//    3) 对单条 / 全部 EDC 做 Fermi edge 拟合
//    4) 把 Height / EF / Te / BG / Res / SB / sigma / chisq / ok 写回 SourceDF
//
//  不负责：
//    - 3D 提取
//    - smoothing
//    - summary export
// ============================================================================

Menu "ARPES_LJZ"
    "2026EDCFermiFit_LJZ", LJZ_EDCFermiFit()
End


// ============================================================================
//  Section 0. paths / state
// ============================================================================

Function/S LJZ_EDCFermiFit_BaseDF()
    return "root:ARPES_LJZ:EDCFermiFit"
End

Function/S LJZ_EDCFermiFit_PanelName()
    return "LJZ_EDCFermiFit_Panel"
End

Function/S LJZ_EDCFermiFit_GraphName()
    return "edcGraph"
End

Function/S LJZ_EDCFermiFit_GraphPath()
    return LJZ_EDCFermiFit_PanelName() + "#" + LJZ_EDCFermiFit_GraphName()
End

Function/S LJZ_EDCFermiFit_df_with_colon(inStr)
    String inStr
    String s = inStr

    if (strlen(s) == 0)
        return "root:"
    endif

    if (StringMatch(s, "root"))
        s = "root:"
    endif

    if (!StringMatch(s, "*:"))
        s += ":"
    endif

    return s
End

Function LJZ_EDCFermiFit_df_exists(dfStr)
    String dfStr
    String s = LJZ_EDCFermiFit_df_with_colon(dfStr)
    return DataFolderExists(s)
End

Function LJZ_EDCFermiFit_Is1DWave(w)
    Wave/Z w

    if (!WaveExists(w))
        return 0
    endif

    if (DimSize(w, 0) <= 0)
        return 0
    endif

    if (DimSize(w, 1) > 0 || DimSize(w, 2) > 0 || DimSize(w, 3) > 0)
        return 0
    endif

    return 1
End

Function/S LJZ_EDCFermiFit_WaveShortLabel(wPath)
    String wPath

    String nm = NameOfWave($wPath)
    if (strlen(nm) == 0)
        nm = wPath
    endif

    return nm
End

Function LJZ_EDCFermiFit_Clamp(v, lo, hi)
    Variable v, lo, hi

    if (v < lo)
        return lo
    endif
    if (v > hi)
        return hi
    endif
    return v
End

Function/S LJZ_EDCFermiFit_ShortenForTitle(s, maxLen)
    String s
    Variable maxLen

    if (strlen(s) <= maxLen)
        return s
    endif

    return s[0, maxLen-4] + "..."
End

Function LJZ_EDCFermiFit_HasChildSubwindow(hostWin, childName)
    String hostWin, childName

    String childList = ChildWindowList(hostWin)
    return (WhichListItem(childName, childList, ";", 0, 0) >= 0)
End

Function LJZ_EDCFermiFit_EnsureDF()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O $(LJZ_EDCFermiFit_BaseDF())

    SVAR/Z sSourceDF = $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF")
    if (!SVAR_Exists(sSourceDF))
        String/G $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF") = "root:"
    endif

    SVAR/Z sWave = $(LJZ_EDCFermiFit_BaseDF() + ":WaveSel")
    if (!SVAR_Exists(sWave))
        String/G $(LJZ_EDCFermiFit_BaseDF() + ":WaveSel") = ""
    endif

    NVAR/Z SelRow = $(LJZ_EDCFermiFit_BaseDF() + ":SelRow")
    if (!NVAR_Exists(SelRow))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":SelRow") = -1
    endif

    NVAR/Z FitX1 = $(LJZ_EDCFermiFit_BaseDF() + ":FitX1")
    if (!NVAR_Exists(FitX1))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":FitX1") = NaN
    endif

    NVAR/Z FitX2 = $(LJZ_EDCFermiFit_BaseDF() + ":FitX2")
    if (!NVAR_Exists(FitX2))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":FitX2") = NaN
    endif

    NVAR/Z Height = $(LJZ_EDCFermiFit_BaseDF() + ":Height")
    if (!NVAR_Exists(Height))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":Height") = 1
    endif

    NVAR/Z EF = $(LJZ_EDCFermiFit_BaseDF() + ":EF")
    if (!NVAR_Exists(EF))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":EF") = 0
    endif

    NVAR/Z Te = $(LJZ_EDCFermiFit_BaseDF() + ":Te")
    if (!NVAR_Exists(Te))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":Te") = 20
    endif

    NVAR/Z BG = $(LJZ_EDCFermiFit_BaseDF() + ":BG")
    if (!NVAR_Exists(BG))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":BG") = 0
    endif

    NVAR/Z Res = $(LJZ_EDCFermiFit_BaseDF() + ":Res")
    if (!NVAR_Exists(Res))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":Res") = 12
    endif

    NVAR/Z SB = $(LJZ_EDCFermiFit_BaseDF() + ":SB")
    if (!NVAR_Exists(SB))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":SB") = 0
    endif

    NVAR/Z HHeight = $(LJZ_EDCFermiFit_BaseDF() + ":HHeight")
    if (!NVAR_Exists(HHeight))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":HHeight") = 0
    endif

    NVAR/Z HEF = $(LJZ_EDCFermiFit_BaseDF() + ":HEF")
    if (!NVAR_Exists(HEF))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":HEF") = 0
    endif

    NVAR/Z HTe = $(LJZ_EDCFermiFit_BaseDF() + ":HTe")
    if (!NVAR_Exists(HTe))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":HTe") = 1
    endif

    NVAR/Z HBG = $(LJZ_EDCFermiFit_BaseDF() + ":HBG")
    if (!NVAR_Exists(HBG))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":HBG") = 0
    endif

    NVAR/Z HRes = $(LJZ_EDCFermiFit_BaseDF() + ":HRes")
    if (!NVAR_Exists(HRes))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":HRes") = 1
    endif

    NVAR/Z HSB = $(LJZ_EDCFermiFit_BaseDF() + ":HSB")
    if (!NVAR_Exists(HSB))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":HSB") = 0
    endif

    SVAR/Z sWorkSrc = $(LJZ_EDCFermiFit_BaseDF() + ":WorkWaveSource")
    if (!SVAR_Exists(sWorkSrc))
        String/G $(LJZ_EDCFermiFit_BaseDF() + ":WorkWaveSource") = ""
    endif

    SVAR/Z sWorkLabel = $(LJZ_EDCFermiFit_BaseDF() + ":WorkWaveLabel")
    if (!SVAR_Exists(sWorkLabel))
        String/G $(LJZ_EDCFermiFit_BaseDF() + ":WorkWaveLabel") = ""
    endif

    NVAR/Z LastHeight = $(LJZ_EDCFermiFit_BaseDF() + ":LastHeight")
    if (!NVAR_Exists(LastHeight))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":LastHeight") = NaN
    endif

    NVAR/Z LastEF = $(LJZ_EDCFermiFit_BaseDF() + ":LastEF")
    if (!NVAR_Exists(LastEF))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":LastEF") = NaN
    endif

    NVAR/Z LastTe = $(LJZ_EDCFermiFit_BaseDF() + ":LastTe")
    if (!NVAR_Exists(LastTe))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":LastTe") = NaN
    endif

    NVAR/Z LastBG = $(LJZ_EDCFermiFit_BaseDF() + ":LastBG")
    if (!NVAR_Exists(LastBG))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":LastBG") = NaN
    endif

    NVAR/Z LastRes = $(LJZ_EDCFermiFit_BaseDF() + ":LastRes")
    if (!NVAR_Exists(LastRes))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":LastRes") = NaN
    endif

    NVAR/Z LastSB = $(LJZ_EDCFermiFit_BaseDF() + ":LastSB")
    if (!NVAR_Exists(LastSB))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":LastSB") = NaN
    endif

    NVAR/Z LastChiSq = $(LJZ_EDCFermiFit_BaseDF() + ":LastChiSq")
    if (!NVAR_Exists(LastChiSq))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":LastChiSq") = NaN
    endif

    NVAR/Z LastOK = $(LJZ_EDCFermiFit_BaseDF() + ":LastOK")
    if (!NVAR_Exists(LastOK))
        Variable/G $(LJZ_EDCFermiFit_BaseDF() + ":LastOK") = 0
    endif

    Wave/T/Z wDisp = $(LJZ_EDCFermiFit_BaseDF() + ":LB_Disp")
    if (!WaveExists(wDisp))
        Make/O/T/N=0 $(LJZ_EDCFermiFit_BaseDF() + ":LB_Disp")
    endif

    Wave/Z wSel = $(LJZ_EDCFermiFit_BaseDF() + ":LB_Sel")
    if (!WaveExists(wSel))
        Make/O/N=0 $(LJZ_EDCFermiFit_BaseDF() + ":LB_Sel") = 0
    endif

    Wave/Z wWork = $(LJZ_EDCFermiFit_BaseDF() + ":CurrentWorkWave")
    if (!WaveExists(wWork))
        Make/O/N=0 $(LJZ_EDCFermiFit_BaseDF() + ":CurrentWorkWave")
    endif

    Wave/Z wWorkMask = $(LJZ_EDCFermiFit_BaseDF() + ":CurrentWorkMask")
    if (!WaveExists(wWorkMask))
        Make/O/N=0 $(LJZ_EDCFermiFit_BaseDF() + ":CurrentWorkMask")
    endif

    Make/O/N=2 $(LJZ_EDCFermiFit_BaseDF() + ":GraphStub") = NaN
    SetScale/P x, 0, 1, "", $(LJZ_EDCFermiFit_BaseDF() + ":GraphStub")

    return 0
End


// ============================================================================
//  Section 1. source DF / scan edc_show_*
// ============================================================================

Function/S LJZ_EDCFermiFit_GetCurrentRunDF()
    String out = ""

    SVAR/Z sRun1 = root:ARPES_LJZ:EDCExtract:RunDF
    if (SVAR_Exists(sRun1))
        if (strlen(sRun1) > 0 && DataFolderExists(RemoveEnding(sRun1, ":")))
            out = LJZ_EDCFermiFit_df_with_colon(sRun1)
            return out
        endif
    endif

    SVAR/Z sRun2 = root:Packages:ARPES_LJZ:EDCWB:TargetDF
    if (SVAR_Exists(sRun2))
        if (strlen(sRun2) > 0 && DataFolderExists(RemoveEnding(sRun2, ":")))
            out = LJZ_EDCFermiFit_df_with_colon(sRun2)
            return out
        endif
    endif

    return ""
End

Function LJZ_EDCFermiFit_UseCurrentRunDF()
    LJZ_EDCFermiFit_EnsureDF()

    SVAR sSourceDF = $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF")
    String runDF = LJZ_EDCFermiFit_GetCurrentRunDF()

    if (strlen(runDF) == 0)
        DoAlert 0, "没有找到当前 EDCExtract 的有效 RunDF。"
        return -1
    endif

    sSourceDF = runDF
    LJZ_EDCFermiFit_RebuildWaveList()
    LJZ_EDCFermiFit_RefreshCurrentSelection()
    LJZ_EDCFermiFit_RefreshTitleBoxes()

    return 0
End

Function LJZ_EDCFermiFit_IsTargetEDCWave(w, nm)
    Wave/Z w
    String nm

    if (!LJZ_EDCFermiFit_Is1DWave(w))
        return 0
    endif

    if (!StringMatch(nm, "edc_show_*"))
        return 0
    endif

    return 1
End

Function LJZ_EDCFermiFit_ParseWaveIndex(nm)
    String nm

    Variable idx = NaN
    sscanf nm, "edc_show_%d", idx
    if (V_flag != 1)
        return NaN
    endif

    return idx
End

Function/S LJZ_EDCFermiFit_InsertWavePathSorted(pathIn, listIn)
    String pathIn, listIn

    String out = listIn
    String nmIn = NameOfWave($pathIn)
    Variable idxIn = LJZ_EDCFermiFit_ParseWaveIndex(nmIn)
    Variable n = ItemsInList(out, ";")
    Variable i

    if (n <= 0)
        return AddListItem(pathIn, "", ";", 0)
    endif

    for (i = 0; i < n; i += 1)
        String pathCur = StringFromList(i, out, ";")
        String nmCur = NameOfWave($pathCur)
        Variable idxCur = LJZ_EDCFermiFit_ParseWaveIndex(nmCur)
        if (numtype(idxCur) != 0 || idxIn < idxCur)
            return AddListItem(pathIn, out, ";", i)
        endif
    endfor

    return AddListItem(pathIn, out, ";", Inf)
End

Function/S LJZ_EDCFermiFit_ListEDCShowWaves_OneDF(dfStr)
    String dfStr

    String out = ""
    Variable iObj, nObj
    nObj = CountObjects(dfStr, 1)

    for (iObj = 0; iObj < nObj; iObj += 1)
        String nm = GetIndexedObjName(dfStr, 1, iObj)
        Wave/Z w = $(dfStr + nm)
        if (!WaveExists(w))
            continue
        endif
        if (!LJZ_EDCFermiFit_IsTargetEDCWave(w, nm))
            continue
        endif
        if (numtype(LJZ_EDCFermiFit_ParseWaveIndex(nm)) != 0)
            continue
        endif

        out = LJZ_EDCFermiFit_InsertWavePathSorted(dfStr + nm, out)
    endfor

    return out
End

Function/S LJZ_EDCFermiFit_CurrentWaveList()
    SVAR sDF = $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF")
    return LJZ_EDCFermiFit_ListEDCShowWaves_OneDF(LJZ_EDCFermiFit_df_with_colon(sDF))
End

Function LJZ_EDCFermiFit_MaxWaveIndexInList(listStr)
    String listStr

    Variable maxIdx = -1
    Variable n = ItemsInList(listStr, ";")
    Variable i

    for (i = 0; i < n; i += 1)
        String wPath = StringFromList(i, listStr, ";")
        Variable idx = LJZ_EDCFermiFit_ParseWaveIndex(NameOfWave($wPath))
        if (numtype(idx) == 0)
            maxIdx = max(maxIdx, idx)
        endif
    endfor

    return maxIdx
End

Function LJZ_EDCFermiFit_RebuildWaveList()
    LJZ_EDCFermiFit_EnsureDF()

    SVAR sDF   = $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF")
    SVAR sWave = $(LJZ_EDCFermiFit_BaseDF() + ":WaveSel")
    NVAR SelRow = $(LJZ_EDCFermiFit_BaseDF() + ":SelRow")

    String dfStr = LJZ_EDCFermiFit_df_with_colon(sDF)
    if (!DataFolderExists(dfStr))
        Make/O/T/N=0 $(LJZ_EDCFermiFit_BaseDF() + ":LB_Disp")
        Make/O/N=0   $(LJZ_EDCFermiFit_BaseDF() + ":LB_Sel")
        sWave = ""
        SelRow = -1
        return -1
    endif

    String prevWave = sWave
    String listStr = LJZ_EDCFermiFit_ListEDCShowWaves_OneDF(dfStr)
    Variable n = ItemsInList(listStr, ";")

    Make/O/T/N=(n) $(LJZ_EDCFermiFit_BaseDF() + ":LB_Disp")
    Make/O/N=(n)   $(LJZ_EDCFermiFit_BaseDF() + ":LB_Sel") = 0

    Wave/T wDisp = $(LJZ_EDCFermiFit_BaseDF() + ":LB_Disp")
    Wave   wSel  = $(LJZ_EDCFermiFit_BaseDF() + ":LB_Sel")

    Variable i
    String wPath
    for (i = 0; i < n; i += 1)
        wPath = StringFromList(i, listStr, ";")
        wDisp[i] = LJZ_EDCFermiFit_WaveShortLabel(wPath)
    endfor

    Variable keepRow = WhichListItem(prevWave, listStr, ";", 0, 0)
    if (keepRow < 0)
        keepRow = 0
    endif

    if (n > 0)
        keepRow = LJZ_EDCFermiFit_Clamp(keepRow, 0, n-1)
        wSel[keepRow] = 1
        sWave = StringFromList(keepRow, listStr, ";")
        SelRow = keepRow
    else
        sWave = ""
        SelRow = -1
    endif

    LJZ_EDCFermiFit_ClearCurrentWorkWave()
    LJZ_EDCFermiFit_EnsureResultWaves()
    return 0
End

Function LJZ_EDCFermiFit_SelectWaveRow(row)
    Variable row

    LJZ_EDCFermiFit_EnsureDF()

    String listStr = LJZ_EDCFermiFit_CurrentWaveList()
    Variable n = ItemsInList(listStr, ";")
    if (n <= 0)
        return -1
    endif

    row = max(0, min(n - 1, row))

    Wave wSel = $(LJZ_EDCFermiFit_BaseDF() + ":LB_Sel")
    if (numpnts(wSel) != n)
        Redimension/N=(n) wSel
    endif
    wSel = 0
    wSel[row] = 1

    SVAR sWave = $(LJZ_EDCFermiFit_BaseDF() + ":WaveSel")
    NVAR SelRow = $(LJZ_EDCFermiFit_BaseDF() + ":SelRow")
    sWave = StringFromList(row, listStr, ";")
    SelRow = row
    LJZ_EDCFermiFit_ClearCurrentWorkWave()

    return 0
End

Function LJZ_EDCFermiFit_CurrentWaveResultIndex()
    SVAR sWave = $(LJZ_EDCFermiFit_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        return NaN
    endif

    return LJZ_EDCFermiFit_ParseWaveIndex(NameOfWave($sWave))
End

Function/S LJZ_EDCFermiFit_FitWaveNameByIndex(idx)
    Variable idx
    return "edc_fit_" + num2str(idx)
End


// ============================================================================
//  Section 2. result waves / read-write
// ============================================================================

Function LJZ_EDCFermiFit_ResultWaveShouldUseRunScale(dfStr)
    String dfStr

    String srcDF = LJZ_EDCFermiFit_df_with_colon(dfStr)
    String curRun = LJZ_EDCFermiFit_GetCurrentRunDF()
    if (CmpStr(srcDF, curRun) != 0)
        return 0
    endif

    NVAR/Z Run_t0 = root:ARPES_LJZ:EDCExtract:Run_t0
    NVAR/Z Run_dt = root:ARPES_LJZ:EDCExtract:Run_dt
    if (!NVAR_Exists(Run_t0) || !NVAR_Exists(Run_dt))
        return 0
    endif
    if (numtype(Run_t0) != 0 || numtype(Run_dt) != 0)
        return 0
    endif

    return 1
End

Function LJZ_EDCFermiFit_ApplyResultWaveScale(w, dfStr)
    Wave w
    String dfStr

    if (LJZ_EDCFermiFit_ResultWaveShouldUseRunScale(dfStr))
        NVAR Run_t0 = root:ARPES_LJZ:EDCExtract:Run_t0
        NVAR Run_dt = root:ARPES_LJZ:EDCExtract:Run_dt
        SetScale/P x, Run_t0, Run_dt, "", w
    else
        SetScale/P x, 0, 1, "", w
    endif

    return 0
End

Function LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, nm, nResult)
    String dfStr, nm
    Variable nResult

    Wave/Z w = $(dfStr + nm)
    if (!WaveExists(w))
        Make/O/N=(nResult) $(dfStr + nm) = NaN
    else
        Variable oldN = numpnts(w)
        if (oldN != nResult)
            Redimension/N=(nResult) w
            if (nResult > oldN)
                w[oldN, nResult-1] = NaN
            endif
        endif
    endif

    Wave w2 = $(dfStr + nm)
    LJZ_EDCFermiFit_ApplyResultWaveScale(w2, dfStr)
    return 0
End

Function LJZ_EDCFermiFit_EnsureResultWaves()
    LJZ_EDCFermiFit_EnsureDF()

    SVAR sDF = $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF")
    String dfStr = LJZ_EDCFermiFit_df_with_colon(sDF)
    String listStr = LJZ_EDCFermiFit_ListEDCShowWaves_OneDF(dfStr)
    Variable maxIdx = LJZ_EDCFermiFit_MaxWaveIndexInList(listStr)
    Variable nResult = maxIdx + 1

    if (!DataFolderExists(dfStr))
        return -1
    endif

    if (nResult < 0)
        nResult = 0
    endif

    LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, "edc_ff_height", nResult)
    LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, "edc_ff_ef", nResult)
    LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, "edc_ff_te", nResult)
    LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, "edc_ff_bg", nResult)
    LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, "edc_ff_res", nResult)
    LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, "edc_ff_sb", nResult)

    LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, "edc_ff_height_sig", nResult)
    LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, "edc_ff_ef_sig", nResult)
    LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, "edc_ff_te_sig", nResult)
    LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, "edc_ff_bg_sig", nResult)
    LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, "edc_ff_res_sig", nResult)
    LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, "edc_ff_sb_sig", nResult)

    LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, "edc_ff_chisq", nResult)
    LJZ_EDCFermiFit_EnsureOneResultWave(dfStr, "edc_ff_ok", nResult)

    return 0
End

Function LJZ_EDCFermiFit_ClearAllResultWaves()
    LJZ_EDCFermiFit_EnsureResultWaves()

    SVAR sDF = $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF")
    String dfStr = LJZ_EDCFermiFit_df_with_colon(sDF)

    Wave/Z w1 = $(dfStr + "edc_ff_height")
    Wave/Z w2 = $(dfStr + "edc_ff_ef")
    Wave/Z w3 = $(dfStr + "edc_ff_te")
    Wave/Z w4 = $(dfStr + "edc_ff_bg")
    Wave/Z w5 = $(dfStr + "edc_ff_res")
    Wave/Z w6 = $(dfStr + "edc_ff_sb")
    Wave/Z w7 = $(dfStr + "edc_ff_height_sig")
    Wave/Z w8 = $(dfStr + "edc_ff_ef_sig")
    Wave/Z w9 = $(dfStr + "edc_ff_te_sig")
    Wave/Z w10 = $(dfStr + "edc_ff_bg_sig")
    Wave/Z w11 = $(dfStr + "edc_ff_res_sig")
    Wave/Z w12 = $(dfStr + "edc_ff_sb_sig")
    Wave/Z w13 = $(dfStr + "edc_ff_chisq")
    Wave/Z w14 = $(dfStr + "edc_ff_ok")

    if (WaveExists(w1))
        w1 = NaN
    endif
    if (WaveExists(w2))
        w2 = NaN
    endif
    if (WaveExists(w3))
        w3 = NaN
    endif
    if (WaveExists(w4))
        w4 = NaN
    endif
    if (WaveExists(w5))
        w5 = NaN
    endif
    if (WaveExists(w6))
        w6 = NaN
    endif
    if (WaveExists(w7))
        w7 = NaN
    endif
    if (WaveExists(w8))
        w8 = NaN
    endif
    if (WaveExists(w9))
        w9 = NaN
    endif
    if (WaveExists(w10))
        w10 = NaN
    endif
    if (WaveExists(w11))
        w11 = NaN
    endif
    if (WaveExists(w12))
        w12 = NaN
    endif
    if (WaveExists(w13))
        w13 = NaN
    endif
    if (WaveExists(w14))
        w14 = 0
    endif

    return 0
End

Function LJZ_EDCFermiFit_ClearCurrentResultDisplay()
    NVAR LastHeight = $(LJZ_EDCFermiFit_BaseDF() + ":LastHeight")
    NVAR LastEF = $(LJZ_EDCFermiFit_BaseDF() + ":LastEF")
    NVAR LastTe = $(LJZ_EDCFermiFit_BaseDF() + ":LastTe")
    NVAR LastBG = $(LJZ_EDCFermiFit_BaseDF() + ":LastBG")
    NVAR LastRes = $(LJZ_EDCFermiFit_BaseDF() + ":LastRes")
    NVAR LastSB = $(LJZ_EDCFermiFit_BaseDF() + ":LastSB")
    NVAR LastChiSq = $(LJZ_EDCFermiFit_BaseDF() + ":LastChiSq")
    NVAR LastOK = $(LJZ_EDCFermiFit_BaseDF() + ":LastOK")

    LastHeight = NaN
    LastEF = NaN
    LastTe = NaN
    LastBG = NaN
    LastRes = NaN
    LastSB = NaN
    LastChiSq = NaN
    LastOK = 0

    String panelName = LJZ_EDCFermiFit_PanelName()
    String graphName = LJZ_EDCFermiFit_GraphName()
    String graphPath = LJZ_EDCFermiFit_GraphPath()
    if (LJZ_EDCFermiFit_HasChildSubwindow(panelName, graphName))
        TextBox/W=$graphPath/K/N=tbFit
        SetDrawLayer/W=$graphPath UserFront
        DrawAction/W=$graphPath getgroup=FitMarks, delete
    endif

    return 0
End

Function LJZ_EDCFermiFit_LoadStoredResultForSelection()
    LJZ_EDCFermiFit_ClearCurrentResultDisplay()

    SVAR sDF = $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF")
    Variable idx = LJZ_EDCFermiFit_CurrentWaveResultIndex()
    if (numtype(idx) != 0)
        return -1
    endif

    String dfStr = LJZ_EDCFermiFit_df_with_colon(sDF)
    Wave/Z wH = $(dfStr + "edc_ff_height")
    Wave/Z wEF = $(dfStr + "edc_ff_ef")
    Wave/Z wTe = $(dfStr + "edc_ff_te")
    Wave/Z wBG = $(dfStr + "edc_ff_bg")
    Wave/Z wRes = $(dfStr + "edc_ff_res")
    Wave/Z wSB = $(dfStr + "edc_ff_sb")
    Wave/Z wCS = $(dfStr + "edc_ff_chisq")
    Wave/Z wOK = $(dfStr + "edc_ff_ok")

    if (!WaveExists(wH) || !WaveExists(wEF) || !WaveExists(wTe) || !WaveExists(wBG) || !WaveExists(wRes) || !WaveExists(wSB) || !WaveExists(wCS) || !WaveExists(wOK))
        return -1
    endif
    if (idx < 0 || idx >= numpnts(wH))
        return -1
    endif

    NVAR LastHeight = $(LJZ_EDCFermiFit_BaseDF() + ":LastHeight")
    NVAR LastEF = $(LJZ_EDCFermiFit_BaseDF() + ":LastEF")
    NVAR LastTe = $(LJZ_EDCFermiFit_BaseDF() + ":LastTe")
    NVAR LastBG = $(LJZ_EDCFermiFit_BaseDF() + ":LastBG")
    NVAR LastRes = $(LJZ_EDCFermiFit_BaseDF() + ":LastRes")
    NVAR LastSB = $(LJZ_EDCFermiFit_BaseDF() + ":LastSB")
    NVAR LastChiSq = $(LJZ_EDCFermiFit_BaseDF() + ":LastChiSq")
    NVAR LastOK = $(LJZ_EDCFermiFit_BaseDF() + ":LastOK")

    LastHeight = wH[idx]
    LastEF = wEF[idx]
    LastTe = wTe[idx]
    LastBG = wBG[idx]
    LastRes = wRes[idx]
    LastSB = wSB[idx]
    LastChiSq = wCS[idx]
    LastOK = wOK[idx]

    return 0
End

Function LJZ_EDCFermiFit_WriteResultForWave(wPath, pw, sigw, chisqVal, okFlag)
    String wPath
    Wave pw, sigw
    Variable chisqVal, okFlag

    SVAR sDF = $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF")
    String dfStr = LJZ_EDCFermiFit_df_with_colon(sDF)
    Variable idx = LJZ_EDCFermiFit_ParseWaveIndex(NameOfWave($wPath))

    if (numtype(idx) != 0)
        return -1
    endif

    LJZ_EDCFermiFit_EnsureResultWaves()

    Wave/Z wH = $(dfStr + "edc_ff_height")
    Wave/Z wEF = $(dfStr + "edc_ff_ef")
    Wave/Z wTe = $(dfStr + "edc_ff_te")
    Wave/Z wBG = $(dfStr + "edc_ff_bg")
    Wave/Z wRes = $(dfStr + "edc_ff_res")
    Wave/Z wSB = $(dfStr + "edc_ff_sb")
    Wave/Z wHs = $(dfStr + "edc_ff_height_sig")
    Wave/Z wEFs = $(dfStr + "edc_ff_ef_sig")
    Wave/Z wTes = $(dfStr + "edc_ff_te_sig")
    Wave/Z wBGs = $(dfStr + "edc_ff_bg_sig")
    Wave/Z wRess = $(dfStr + "edc_ff_res_sig")
    Wave/Z wSBs = $(dfStr + "edc_ff_sb_sig")
    Wave/Z wCS = $(dfStr + "edc_ff_chisq")
    Wave/Z wOK = $(dfStr + "edc_ff_ok")

    if (!WaveExists(wH) || idx < 0 || idx >= numpnts(wH))
        return -1
    endif

    wH[idx]   = pw[0]
    wEF[idx]  = pw[1]
    wTe[idx]  = pw[2]
    wBG[idx]  = pw[3]
    wRes[idx] = pw[4]
    wSB[idx]  = pw[5]

    wHs[idx]   = sigw[0]
    wEFs[idx]  = sigw[1]
    wTes[idx]  = sigw[2]
    wBGs[idx]  = sigw[3]
    wRess[idx] = sigw[4]
    wSBs[idx]  = sigw[5]

    wCS[idx] = chisqVal
    wOK[idx] = okFlag

    NVAR LastHeight = $(LJZ_EDCFermiFit_BaseDF() + ":LastHeight")
    NVAR LastEF = $(LJZ_EDCFermiFit_BaseDF() + ":LastEF")
    NVAR LastTe = $(LJZ_EDCFermiFit_BaseDF() + ":LastTe")
    NVAR LastBG = $(LJZ_EDCFermiFit_BaseDF() + ":LastBG")
    NVAR LastRes = $(LJZ_EDCFermiFit_BaseDF() + ":LastRes")
    NVAR LastSB = $(LJZ_EDCFermiFit_BaseDF() + ":LastSB")
    NVAR LastChiSq = $(LJZ_EDCFermiFit_BaseDF() + ":LastChiSq")
    NVAR LastOK = $(LJZ_EDCFermiFit_BaseDF() + ":LastOK")

    LastHeight = pw[0]
    LastEF = pw[1]
    LastTe = pw[2]
    LastBG = pw[3]
    LastRes = pw[4]
    LastSB = pw[5]
    LastChiSq = chisqVal
    LastOK = okFlag

    return 0
End

Function LJZ_EDCFermiFit_ClearResultForWave(wPath)
    String wPath

    Make/FREE/D/N=6 pwNaN = NaN
    Make/FREE/D/N=6 sigNaN = NaN
    LJZ_EDCFermiFit_WriteResultForWave(wPath, pwNaN, sigNaN, NaN, 0)
    return 0
End


// ============================================================================
//  Section 3. model kernel / guess helpers
// ============================================================================

Function LJZ_EDCFermiFit_WindowMean(w, p1, p2)
    Wave w
    Variable p1, p2

    Variable n = numpnts(w)
    if (n <= 0)
        return NaN
    endif

    p1 = LJZ_EDCFermiFit_Clamp(round(p1), 0, n-1)
    p2 = LJZ_EDCFermiFit_Clamp(round(p2), 0, n-1)

    Variable pLo = min(p1, p2)
    Variable pHi = max(p1, p2)
    Variable i, s = 0, c = 0

    for (i = pLo; i <= pHi; i += 1)
        if (numtype(w[i]) == 0)
            s += w[i]
            c += 1
        endif
    endfor

    if (c <= 0)
        return NaN
    endif

    return s / c
End

Function LJZ_EDCFermiFit_FindLevelCrossing(w, p1, p2, level)
    Wave w
    Variable p1, p2, level

    Variable n = numpnts(w)
    if (n < 2)
        return NaN
    endif

    p1 = LJZ_EDCFermiFit_Clamp(round(p1), 0, n-1)
    p2 = LJZ_EDCFermiFit_Clamp(round(p2), 0, n-1)

    Variable pLo = min(p1, p2)
    Variable pHi = max(p1, p2)
    if (pHi - pLo < 1)
        return NaN
    endif

    Variable bestX = NaN
    Variable bestScore = -Inf
    Variable p

    for (p = pLo; p < pHi; p += 1)
        Variable xA = pnt2x(w, p)
        Variable xB = pnt2x(w, p+1)
        Variable yA = w[p]
        Variable yB = w[p+1]

        if (numtype(xA) != 0 || numtype(xB) != 0 || numtype(yA) != 0 || numtype(yB) != 0)
            continue
        endif
        if (xA == xB || yA == yB)
            continue
        endif
        if ((yA - level) * (yB - level) > 0)
            continue
        endif

        Variable frac = (level - yA) / (yB - yA)
        if (frac < 0 || frac > 1)
            continue
        endif

        Variable xC = xA + frac * (xB - xA)
        Variable score = abs((yB - yA) / (xB - xA))
        if (score > bestScore)
            bestScore = score
            bestX = xC
        endif
    endfor

    return bestX
End

Function LJZ_EDCFermiFit_FWHMMeV_to_SigmaEV(fwhmMeV)
    Variable fwhmMeV

    Variable fwhmEV = abs(fwhmMeV) / 1000
    return fwhmEV / (2 * sqrt(2 * ln(2)))
End

Function LJZ_EDCFermiFit_SigmaEV_to_FWHMMeV(sigEV)
    Variable sigEV
    return abs(sigEV) * (2 * sqrt(2 * ln(2))) * 1000
End

Function/S LJZ_EDCFermiFit_HoldString()
    NVAR HHeight = $(LJZ_EDCFermiFit_BaseDF() + ":HHeight")
    NVAR HEF = $(LJZ_EDCFermiFit_BaseDF() + ":HEF")
    NVAR HTe = $(LJZ_EDCFermiFit_BaseDF() + ":HTe")
    NVAR HBG = $(LJZ_EDCFermiFit_BaseDF() + ":HBG")
    NVAR HRes = $(LJZ_EDCFermiFit_BaseDF() + ":HRes")
    NVAR HSB = $(LJZ_EDCFermiFit_BaseDF() + ":HSB")

    return num2str(HHeight) + num2str(HEF) + num2str(HTe) + num2str(HBG) + num2str(HRes) + num2str(HSB)
End

Function LJZ_EDCFermiFit_ClearCurrentWorkWave()
    SVAR sWorkSrc = $(LJZ_EDCFermiFit_BaseDF() + ":WorkWaveSource")
    SVAR sWorkLabel = $(LJZ_EDCFermiFit_BaseDF() + ":WorkWaveLabel")
    sWorkSrc = ""
    sWorkLabel = ""

    Wave workW = $(LJZ_EDCFermiFit_BaseDF() + ":CurrentWorkWave")
    Wave workMask = $(LJZ_EDCFermiFit_BaseDF() + ":CurrentWorkMask")
    Redimension/N=(0) workW, workMask
    return 0
End

Function/WAVE LJZ_EDCFermiFit_GetActiveWaveForPath(wPath)
    String wPath

    SVAR/Z sWorkSrc = $(LJZ_EDCFermiFit_BaseDF() + ":WorkWaveSource")
    Wave/Z workW = $(LJZ_EDCFermiFit_BaseDF() + ":CurrentWorkWave")
    if (SVAR_Exists(sWorkSrc) && WaveExists(workW) && (CmpStr(sWorkSrc, wPath) == 0) && (numpnts(workW) > 0))
        return workW
    endif

    Wave/Z srcW = $wPath
    return srcW
End

Function/S LJZ_EDCFermiFit_GetDisplayLabelForPath(wPath)
    String wPath

    SVAR/Z sWorkSrc = $(LJZ_EDCFermiFit_BaseDF() + ":WorkWaveSource")
    SVAR/Z sWorkLabel = $(LJZ_EDCFermiFit_BaseDF() + ":WorkWaveLabel")
    if (SVAR_Exists(sWorkSrc) && SVAR_Exists(sWorkLabel) && (CmpStr(sWorkSrc, wPath) == 0) && (strlen(sWorkLabel) > 0))
        return sWorkLabel
    endif

    return ""
End

Function LJZ_EDCFermiFit_GetFitPointWindow(w, x1, x2, pLoOut, pHiOut)
    Wave w
    Variable x1, x2
    Variable &pLoOut, &pHiOut

    Variable n = numpnts(w)
    if (n < 2)
        pLoOut = 0
        pHiOut = -1
        return -1
    endif

    Variable p1 = x2pnt(w, x1)
    Variable p2 = x2pnt(w, x2)
    if (numtype(p1) != 0 || numtype(p2) != 0)
        pLoOut = 0
        pHiOut = n - 1
        return 0
    endif

    p1 = LJZ_EDCFermiFit_Clamp(round(p1), 0, n - 1)
    p2 = LJZ_EDCFermiFit_Clamp(round(p2), 0, n - 1)
    pLoOut = min(p1, p2)
    pHiOut = max(p1, p2)
    if (pHiOut <= pLoOut)
        if (pLoOut > 0)
            pLoOut -= 1
        endif
        if (pHiOut < n - 1)
            pHiOut += 1
        endif
    endif
    pLoOut = LJZ_EDCFermiFit_Clamp(pLoOut, 0, n - 1)
    pHiOut = LJZ_EDCFermiFit_Clamp(pHiOut, 0, n - 1)
    if (pHiOut - pLoOut < 2)
        pLoOut = 0
        pHiOut = n - 1
    endif
    return 0
End

Function LJZ_EDCFermiFit_ParamsLookValid(w, x1, x2, pw)
    Wave w, pw
    Variable x1, x2

    Variable pLo, pHi
    LJZ_EDCFermiFit_GetFitPointWindow(w, x1, x2, pLo, pHi)
    Variable xLo = min(pnt2x(w, pLo), pnt2x(w, pHi))
    Variable xHi = max(pnt2x(w, pLo), pnt2x(w, pHi))
    Variable span = abs(xHi - xLo)
    Variable sigmaMax = max(span, abs(DimDelta(w, 0))) * 0.8

    if (numtype(pw[0]) != 0 || abs(pw[0]) < 1e-9)
        return 0
    endif
    if (numtype(pw[1]) != 0 || pw[1] < xLo - 0.35 * span || pw[1] > xHi + 0.35 * span)
        return 0
    endif
    if (numtype(pw[2]) != 0 || abs(pw[2]) < 0.2 || abs(pw[2]) > 600)
        return 0
    endif
    if (numtype(pw[3]) != 0)
        return 0
    endif
    if (numtype(pw[4]) != 0 || abs(pw[4]) < 1e-6 || abs(pw[4]) > sigmaMax)
        return 0
    endif
    if (numtype(pw[5]) != 0)
        return 0
    endif

    return 1
End

Function LJZ_EDCFermiFit_UIToCoefWave(pw)
    Wave pw

    NVAR Height = $(LJZ_EDCFermiFit_BaseDF() + ":Height")
    NVAR EF = $(LJZ_EDCFermiFit_BaseDF() + ":EF")
    NVAR Te = $(LJZ_EDCFermiFit_BaseDF() + ":Te")
    NVAR BG = $(LJZ_EDCFermiFit_BaseDF() + ":BG")
    NVAR Res = $(LJZ_EDCFermiFit_BaseDF() + ":Res")
    NVAR SB = $(LJZ_EDCFermiFit_BaseDF() + ":SB")

    pw[0] = Height
    pw[1] = EF
    pw[2] = max(abs(Te), 0.2)
    pw[3] = BG
    pw[4] = LJZ_EDCFermiFit_FWHMMeV_to_SigmaEV(Res)
    pw[5] = SB
    return 0
End

Function LJZ_EDCFermiFit_CoefWaveToUI(pw)
    Wave pw

    NVAR Height = $(LJZ_EDCFermiFit_BaseDF() + ":Height")
    NVAR EF = $(LJZ_EDCFermiFit_BaseDF() + ":EF")
    NVAR Te = $(LJZ_EDCFermiFit_BaseDF() + ":Te")
    NVAR BG = $(LJZ_EDCFermiFit_BaseDF() + ":BG")
    NVAR Res = $(LJZ_EDCFermiFit_BaseDF() + ":Res")
    NVAR SB = $(LJZ_EDCFermiFit_BaseDF() + ":SB")

    Height = pw[0]
    EF = pw[1]
    Te = pw[2]
    BG = pw[3]
    Res = LJZ_EDCFermiFit_SigmaEV_to_FWHMMeV(pw[4])
    SB = pw[5]
    return 0
End

Function LJZ_EDCFermiFit_ResultPWToStorePW(pwFit, pwStore)
    Wave pwFit, pwStore

    pwStore[0] = pwFit[0]
    pwStore[1] = pwFit[1]
    pwStore[2] = abs(pwFit[2])
    pwStore[3] = pwFit[3]
    pwStore[4] = LJZ_EDCFermiFit_SigmaEV_to_FWHMMeV(pwFit[4])
    pwStore[5] = pwFit[5]

    return 0
End

Function LJZ_EDCFermiFit_ResultSigToStoreSig(sigFit, sigStore)
    Wave sigFit, sigStore

    sigStore[0] = abs(sigFit[0])
    sigStore[1] = abs(sigFit[1])
    sigStore[2] = abs(sigFit[2])
    sigStore[3] = abs(sigFit[3])
    sigStore[4] = LJZ_EDCFermiFit_SigmaEV_to_FWHMMeV(sigFit[4])
    sigStore[5] = abs(sigFit[5])

    return 0
End

Function LJZ_EDCFermiFit_GuessParamsFromWave(w, x1, x2, outPW)
    Wave w, outPW
    Variable x1, x2

    Variable n = numpnts(w)
    if (n < 7)
        return -1
    endif

    Variable pLo, pHi
    LJZ_EDCFermiFit_GetFitPointWindow(w, x1, x2, pLo, pHi)
    Variable spanN = pHi - pLo + 1
    if (spanN < 7)
        return -1
    endif

    Make/FREE/D/N=(spanN) ySm
    SetScale/P x, pnt2x(w, pLo), DimDelta(w, 0), "", ySm
    Variable i, j, pj, c, s
    for (i = 0; i < spanN; i += 1)
        s = 0
        c = 0
        for (j = -2; j <= 2; j += 1)
            pj = pLo + i + j
            if (pj < pLo || pj > pHi)
                continue
            endif
            if (numtype(w[pj]) == 0)
                s += w[pj]
                c += 1
            endif
        endfor
        if (c > 0)
            ySm[i] = s / c
        else
            ySm[i] = NaN
        endif
    endfor

    Variable nSeg = max(4, round(spanN * 0.14))
    nSeg = min(nSeg, max(4, round(spanN * 0.33)))

    Variable meanL = LJZ_EDCFermiFit_WindowMean(ySm, 0, nSeg - 1)
    Variable meanR = LJZ_EDCFermiFit_WindowMean(ySm, spanN - nSeg, spanN - 1)
    if (numtype(meanL) != 0 || numtype(meanR) != 0)
        return -1
    endif

    Variable descending = (meanL >= meanR)
    Variable hiLevel, loLevel
    if (descending)
        hiLevel = meanL
        loLevel = meanR
    else
        hiLevel = meanR
        loLevel = meanL
    endif
    Variable height = hiLevel - loLevel
    if (abs(height) < 1e-9)
        height = max(1, 0.05 * max(abs(hiLevel), abs(loLevel)))
    endif

    Variable slopeBest = -Inf
    Variable bestP = pLo
    for (i = pLo + 1; i <= pHi - 1; i += 1)
        Variable xA = pnt2x(w, i - 1)
        Variable xB = pnt2x(w, i + 1)
        if (numtype(xA) != 0 || numtype(xB) != 0 || xA == xB)
            continue
        endif
        Variable dy = ySm[i - pLo + 1] - ySm[i - pLo - 1]
        Variable slope = dy / (xB - xA)
        if (descending)
            slope = -slope
        endif
        if (numtype(slope) == 0 && slope > slopeBest)
            slopeBest = slope
            bestP = i
        endif
    endfor

    Variable bg = loLevel
    Variable yHalf = loLevel + 0.5 * height
    Variable ef = LJZ_EDCFermiFit_FindLevelCrossing(ySm, 0, spanN - 1, yHalf)
    if (numtype(ef) != 0)
        ef = pnt2x(w, bestP)
    endif

    Variable y10 = loLevel + 0.1 * height
    Variable y90 = loLevel + 0.9 * height
    Variable x10 = LJZ_EDCFermiFit_FindLevelCrossing(ySm, 0, spanN - 1, y10)
    Variable x90 = LJZ_EDCFermiFit_FindLevelCrossing(ySm, 0, spanN - 1, y90)

    Variable kB = 8.617333262e-5
    Variable teGuess = 18
    Variable totalWidth = NaN
    if (numtype(x10) == 0 && numtype(x90) == 0)
        totalWidth = abs(x90 - x10)
        if (totalWidth > 0)
            teGuess = totalWidth / (4.39444915467 * kB)
        endif
    endif
    teGuess = max(4, min(220, teGuess))

    NVAR Res = $(LJZ_EDCFermiFit_BaseDF() + ":Res")
    Variable resGuessMeV = 14
    if (numtype(Res) == 0 && abs(Res) >= 2 && abs(Res) <= 80)
        resGuessMeV = abs(Res)
    elseif (numtype(totalWidth) == 0 && totalWidth > 0)
        Variable thermal1090 = 4.39444915467 * kB * teGuess
        Variable instrWidthEV = sqrt(max(totalWidth^2 - thermal1090^2, 0))
        resGuessMeV = max(4, min(60, instrWidthEV * 1000))
    endif

    Variable sbGuess = max(0, min(0.35 * abs(height), max(0, hiLevel - LJZ_EDCFermiFit_WindowMean(ySm, spanN - max(3, round(spanN * 0.08)), spanN - 1))))

    outPW[0] = max(height, 1e-6)
    outPW[1] = ef
    outPW[2] = teGuess
    outPW[3] = bg
    outPW[4] = LJZ_EDCFermiFit_FWHMMeV_to_SigmaEV(resGuessMeV)
    outPW[5] = sbGuess

    return 0
End

Function LJZ_EDCFermiFit_EvalModel(pw, yw, xw)
    Wave pw, yw, xw

    Variable n = numpnts(xw)
    if (n <= 0)
        return -1
    endif

    Variable kB = 8.617333262e-5
    Variable A   = pw[0]
    Variable EF  = pw[1]
    Variable T   = max(abs(pw[2]), 0.2)
    Variable BG  = pw[3]
    Variable sig = abs(pw[4])
    Variable SB  = max(pw[5], 0)

    Variable dx
    if (n > 1)
        dx = xw[1] - xw[0]
    else
        dx = 1e-4
    endif
    if (dx == 0 && n > 1)
        dx = (xw[n - 1] - xw[0]) / max(1, n - 1)
    endif
    if (dx == 0)
        dx = 1e-4
    endif
    Variable dxAbs = abs(dx)
    Variable blurEV = max(sig, 4 * kB * T)
    Variable padN = max(24, ceil(8 * blurEV / dxAbs))
    Variable nExt = n + 2 * padN

    Make/FREE/D/N=(nExt) xExt, yFD
    xExt = xw[0] + (p - padN) * dx
    Variable i, arg
    for (i = 0; i < nExt; i += 1)
        arg = (xExt[i] - EF) / (kB * T)
        if (arg > 60)
            yFD[i] = 0
        elseif (arg < -60)
            yFD[i] = A
        else
            yFD[i] = A / (1 + exp(arg))
        endif
    endfor

    if (sig > 1e-7 * dxAbs)
        Variable rad = max(3, ceil(4 * sig / dxAbs))
        Variable gN = 2 * rad + 1
        Make/FREE/D/N=(gN) gk
        gk = exp(-(((p - rad) * dxAbs)^2) / (2 * sig^2))
        Variable gsum = sum(gk, -inf, inf)
        if (numtype(gsum) != 0 || gsum <= 0)
            gsum = 1
        endif
        gk /= gsum
        Convolve/A gk, yFD
    endif

    Make/FREE/D/N=(n) yCrop, yTail, shirleyShape
    yCrop = yFD[p + padN]

    Variable rightRef = yCrop[n - 1]
    yTail = max(yCrop[p] - rightRef, 0)
    Duplicate/FREE yTail, shirleyShape
    Reverse shirleyShape
    Integrate shirleyShape
    Reverse shirleyShape

    Variable shMax = shirleyShape[0]
    if (numtype(shMax) != 0 || shMax <= 0)
        shirleyShape = 0
    else
        shirleyShape /= shMax
    endif

    yw = yCrop[p] + BG + SB * shirleyShape[p]
    return 0
End

Function LJZ_EDCFermiFit_ModelAA(pw, yw, xw) : FitFunc
    Wave pw, yw, xw
    return LJZ_EDCFermiFit_EvalModel(pw, yw, xw)
End

Function LJZ_EDCFermiFit_CreateStoredFitWave(wPath, pwFit)
    String wPath
    Wave pwFit

    SVAR sDF = $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF")
    String dfStr = LJZ_EDCFermiFit_df_with_colon(sDF)
    Variable idx = LJZ_EDCFermiFit_ParseWaveIndex(NameOfWave($wPath))
    Wave/Z w = $wPath

    if (!WaveExists(w) || !LJZ_EDCFermiFit_Is1DWave(w) || numtype(idx) != 0)
        return -1
    endif

    Variable n = numpnts(w)
    Make/O/N=(n) $(dfStr + LJZ_EDCFermiFit_FitWaveNameByIndex(idx)) = NaN
    Wave fitW = $(dfStr + LJZ_EDCFermiFit_FitWaveNameByIndex(idx))
    SetScale/P x, DimOffset(w, 0), DimDelta(w, 0), "", fitW

    Make/FREE/D/N=(n) xFull
    xFull = pnt2x(fitW, p)
    LJZ_EDCFermiFit_EvalModel(pwFit, fitW, xFull)

    NVAR FitX1 = $(LJZ_EDCFermiFit_BaseDF() + ":FitX1")
    NVAR FitX2 = $(LJZ_EDCFermiFit_BaseDF() + ":FitX2")
    Variable pLo, pHi
    LJZ_EDCFermiFit_GetFitPointWindow(w, FitX1, FitX2, pLo, pHi)
    fitW[p < pLo || p > pHi] = NaN
    return 0
End


// ============================================================================
//  Section 4. fitting engine
// ============================================================================

Function LJZ_EDCFermiFit_AutoFillWindow()
    LJZ_EDCFermiFit_EnsureDF()

    SVAR sWave = $(LJZ_EDCFermiFit_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        DoAlert 0, "请先选择一个 edc_show_* 波形。"
        return -1
    endif

    Wave/Z w = LJZ_EDCFermiFit_GetActiveWaveForPath(sWave)
    if (!WaveExists(w) || !LJZ_EDCFermiFit_Is1DWave(w))
        DoAlert 0, "当前选择不是有效的 1D wave。"
        return -1
    endif

    Variable n = numpnts(w)
    if (n < 4)
        return -1
    endif

    Variable bestP = 0
    Variable bestSlope = -Inf
    Variable p
    for (p = 0; p < n - 1; p += 1)
        Variable xA = pnt2x(w, p)
        Variable xB = pnt2x(w, p+1)
        if (xA == xB)
            continue
        endif
        Variable s = abs((w[p+1] - w[p]) / (xB - xA))
        if (numtype(s) == 0 && s > bestSlope)
            bestSlope = s
            bestP = p
        endif
    endfor

    Variable x0 = 0.5 * (pnt2x(w, bestP) + pnt2x(w, bestP + 1))
    Variable xMin = min(pnt2x(w, 0), pnt2x(w, n-1))
    Variable xMax = max(pnt2x(w, 0), pnt2x(w, n-1))
    Variable span = xMax - xMin
    if (span <= 0)
        return -1
    endif

    NVAR FitX1 = $(LJZ_EDCFermiFit_BaseDF() + ":FitX1")
    NVAR FitX2 = $(LJZ_EDCFermiFit_BaseDF() + ":FitX2")
    FitX1 = max(xMin, x0 - 0.18 * span)
    FitX2 = min(xMax, x0 + 0.18 * span)

    return 0
End

Function LJZ_EDCFermiFit_GuessCurrent()
    LJZ_EDCFermiFit_EnsureDF()

    SVAR sWave = $(LJZ_EDCFermiFit_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        DoAlert 0, "请先选择一个 edc_show_* 波形。"
        return -1
    endif

    Wave/Z w = LJZ_EDCFermiFit_GetActiveWaveForPath(sWave)
    if (!WaveExists(w) || !LJZ_EDCFermiFit_Is1DWave(w))
        DoAlert 0, "当前选择不是有效的 1D wave。"
        return -1
    endif

    NVAR FitX1 = $(LJZ_EDCFermiFit_BaseDF() + ":FitX1")
    NVAR FitX2 = $(LJZ_EDCFermiFit_BaseDF() + ":FitX2")

    Variable x1, x2
    if (numtype(FitX1) == 0)
        x1 = FitX1
    else
        x1 = min(pnt2x(w, 0), pnt2x(w, numpnts(w)-1))
    endif
    if (numtype(FitX2) == 0)
        x2 = FitX2
    else
        x2 = max(pnt2x(w, 0), pnt2x(w, numpnts(w)-1))
    endif

    Make/FREE/D/N=6 pwGuess
    if (LJZ_EDCFermiFit_GuessParamsFromWave(w, x1, x2, pwGuess) != 0)
        DoAlert 0, "当前波形无法生成稳定初值，请先调整拟合窗口。"
        return -1
    endif

    LJZ_EDCFermiFit_CoefWaveToUI(pwGuess)
    LJZ_EDCFermiFit_RefreshTitleBoxes()
    return 0
End

Function LJZ_EDCFermiFit_FitWaveByPath(wPath, initPW, holdStr, updateUI, doAlertOnFail)
    String wPath, holdStr
    Wave initPW
    Variable updateUI, doAlertOnFail

    Wave/Z wSrc = $wPath
    Wave/Z wFit = LJZ_EDCFermiFit_GetActiveWaveForPath(wPath)
    if (!WaveExists(wSrc) || !LJZ_EDCFermiFit_Is1DWave(wSrc) || !WaveExists(wFit) || !LJZ_EDCFermiFit_Is1DWave(wFit))
        LJZ_EDCFermiFit_ClearResultForWave(wPath)
        return -1
    endif

    Variable n = numpnts(wFit)
    if (n < 7)
        LJZ_EDCFermiFit_ClearResultForWave(wPath)
        return -1
    endif

    NVAR FitX1 = $(LJZ_EDCFermiFit_BaseDF() + ":FitX1")
    NVAR FitX2 = $(LJZ_EDCFermiFit_BaseDF() + ":FitX2")

    Variable xMin = min(pnt2x(wFit, 0), pnt2x(wFit, n-1))
    Variable xMax = max(pnt2x(wFit, 0), pnt2x(wFit, n-1))
    Variable xLo, xHi
    if (numtype(FitX1) == 0)
        xLo = FitX1
    else
        xLo = xMin
    endif
    if (numtype(FitX2) == 0)
        xHi = FitX2
    else
        xHi = xMax
    endif
    xLo = max(xMin, min(xLo, xMax))
    xHi = max(xMin, min(xHi, xMax))

    Variable pLo, pHi
    LJZ_EDCFermiFit_GetFitPointWindow(wFit, xLo, xHi, pLo, pHi)
    if (pHi - pLo < 4)
        LJZ_EDCFermiFit_ClearResultForWave(wPath)
        if (doAlertOnFail)
            DoAlert 0, "拟合窗口过窄，请重新设置 FitX1 / FitX2。"
        endif
        return -1
    endif

    Make/FREE/D/N=6 startPW
    startPW = initPW[p]
    if (!LJZ_EDCFermiFit_ParamsLookValid(wFit, xLo, xHi, startPW))
        if (LJZ_EDCFermiFit_GuessParamsFromWave(wFit, xLo, xHi, startPW) != 0)
            LJZ_EDCFermiFit_ClearResultForWave(wPath)
            if (doAlertOnFail)
                DoAlert 0, "当前波形无法生成稳定初值，请先调整拟合窗口。"
            endif
            return -1
        endif
    endif

    String oldDF = GetDataFolder(1)
    SetDataFolder $(LJZ_EDCFermiFit_BaseDF())

    Duplicate/O startPW, pw_fit
    KillWaves/Z W_sigma

    FuncFit/Q/NTHR=0/N/G/H=holdStr LJZ_EDCFermiFit_ModelAA pw_fit wFit[pLo, pHi]
    Variable fitErr = V_FitError
    Variable chiSq = V_chisq

    Make/FREE/D/N=6 pwStore, sigStore
    Make/FREE/D/N=6 pwOut = NaN
    Make/FREE/D/N=6 sigOut = NaN

    Variable ok = 0
    if (numtype(fitErr) == 0 && fitErr == 0)
        ok = 1
    endif
    Variable i
    for (i = 0; i < 6; i += 1)
        if (numtype(pw_fit[i]) != 0)
            ok = 0
        endif
    endfor
    if (ok && !LJZ_EDCFermiFit_ParamsLookValid(wFit, xLo, xHi, pw_fit))
        ok = 0
    endif

    Wave/Z wSig = W_sigma
    if (WaveExists(wSig) && numpnts(wSig) >= 6)
        for (i = 0; i < 6; i += 1)
            sigOut[i] = abs(wSig[i])
        endfor
    endif

    if (numtype(chiSq) != 0)
        chiSq = NaN
    endif

    if (ok)
        pwOut = pw_fit[p]
        initPW = pw_fit[p]

        LJZ_EDCFermiFit_ResultPWToStorePW(pwOut, pwStore)
        LJZ_EDCFermiFit_ResultSigToStoreSig(sigOut, sigStore)
        LJZ_EDCFermiFit_WriteResultForWave(wPath, pwStore, sigStore, chiSq, 1)
        LJZ_EDCFermiFit_CreateStoredFitWave(wPath, pwOut)

        if (updateUI)
            LJZ_EDCFermiFit_CoefWaveToUI(pwOut)
        endif
    else
        LJZ_EDCFermiFit_ClearResultForWave(wPath)
        if (doAlertOnFail)
            DoAlert 0, "Fermi 拟合失败，请检查拟合窗口、初值和 hold 设置。"
        endif
    endif

    SetDataFolder $oldDF
    if (ok)
        return 0
    endif
    return -1
End

Function LJZ_EDCFermiFit_FitCurrent()
    LJZ_EDCFermiFit_EnsureDF()

    SVAR sWave = $(LJZ_EDCFermiFit_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        DoAlert 0, "请先选择一个 edc_show_* 波形。"
        return -1
    endif

    Make/FREE/D/N=6 initPW
    LJZ_EDCFermiFit_UIToCoefWave(initPW)
    String holdStr = LJZ_EDCFermiFit_HoldString()

    Variable ret = LJZ_EDCFermiFit_FitWaveByPath(sWave, initPW, holdStr, 1, 1)
    LJZ_EDCFermiFit_ShowCurrentWave()
    LJZ_EDCFermiFit_RefreshTitleBoxes()
    return ret
End

Function LJZ_EDCFermiFit_FitAll()
    LJZ_EDCFermiFit_EnsureDF()

    String listStr = LJZ_EDCFermiFit_CurrentWaveList()
    Variable n = ItemsInList(listStr, ";")
    if (n <= 0)
        DoAlert 0, "当前 SourceDF 下没有 edc_show_* 波形可拟合。"
        return -1
    endif

    Make/FREE/D/N=6 baseInit, workInit
    LJZ_EDCFermiFit_UIToCoefWave(baseInit)
    workInit = baseInit[p]
    String holdStr = LJZ_EDCFermiFit_HoldString()

    LJZ_EDCFermiFit_ClearAllResultWaves()

    Variable i, okCount = 0
    for (i = 0; i < n; i += 1)
        String wPath = StringFromList(i, listStr, ";")
        Variable ret = LJZ_EDCFermiFit_FitWaveByPath(wPath, workInit, holdStr, 0, 0)
        if (ret == 0)
            okCount += 1
        else
            workInit = baseInit[p]
        endif
    endfor

    LJZ_EDCFermiFit_LoadStoredResultForSelection()
    LJZ_EDCFermiFit_ShowCurrentWave()
    LJZ_EDCFermiFit_RefreshTitleBoxes()

    if (okCount <= 0)
        DoAlert 0, "批量拟合已完成，但没有成功条目。请先调好当前条的窗口和初值。"
        return -1
    endif

    return 0
End

Function LJZ_EDCFermiFit_FitAndNext()
    LJZ_EDCFermiFit_EnsureDF()

    Variable ret = LJZ_EDCFermiFit_FitCurrent()

    String listStr = LJZ_EDCFermiFit_CurrentWaveList()
    Variable n = ItemsInList(listStr, ";")
    NVAR SelRow = $(LJZ_EDCFermiFit_BaseDF() + ":SelRow")

    if (ret == 0 && n > 0)
        if (SelRow < n - 1)
            LJZ_EDCFermiFit_SelectWaveRow(SelRow + 1)
            LJZ_EDCFermiFit_RefreshCurrentSelection()
            LJZ_EDCFermiFit_RefreshTitleBoxes()
        endif
    endif

    return 0
End

Function LJZ_EDCFermiFit_LoadCursorsToWindow()
    String graphPath = LJZ_EDCFermiFit_GraphPath()
    if (WinType(LJZ_EDCFermiFit_PanelName()) == 0)
        return -1
    endif

    Variable xA = hcsr(A, graphPath)
    Variable xB = hcsr(B, graphPath)
    if (numtype(xA) != 0 || numtype(xB) != 0)
        DoAlert 0, "请先在 panel 内 graph 上放置 A / B 两个 cursor。"
        return -1
    endif

    NVAR FitX1 = $(LJZ_EDCFermiFit_BaseDF() + ":FitX1")
    NVAR FitX2 = $(LJZ_EDCFermiFit_BaseDF() + ":FitX2")
    FitX1 = min(xA, xB)
    FitX2 = max(xA, xB)

    LJZ_EDCFermiFit_UpdateGraphMarks()
    return 0
End

Function LJZ_EDCFermiFit_RmBGCurrent()
    LJZ_EDCFermiFit_EnsureDF()

    SVAR sWave = $(LJZ_EDCFermiFit_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        DoAlert 0, "请先选择一个 edc_show_* 波形。"
        return -1
    endif

    Wave/Z srcW = $sWave
    if (!WaveExists(srcW) || !LJZ_EDCFermiFit_Is1DWave(srcW))
        DoAlert 0, "当前选择不是有效的 1D wave。"
        return -1
    endif

    String graphPath = LJZ_EDCFermiFit_GraphPath()
    Variable xA = hcsr(A, graphPath)
    Variable xB = hcsr(B, graphPath)
    if (numtype(xA) != 0 || numtype(xB) != 0)
        DoAlert 0, "RmBG 需要先在 panel graph 上放置 A / B cursor。"
        return -1
    endif

    Variable pLo, pHi
    LJZ_EDCFermiFit_GetFitPointWindow(srcW, xA, xB, pLo, pHi)
    Variable bgShift = LJZ_EDCFermiFit_WindowMean(srcW, pLo, pHi)
    if (numtype(bgShift) != 0)
        DoAlert 0, "无法从 cursor 区间得到有效平均背景。"
        return -1
    endif

    Duplicate/O srcW, $(LJZ_EDCFermiFit_BaseDF() + ":CurrentWorkWave")
    Wave workW = $(LJZ_EDCFermiFit_BaseDF() + ":CurrentWorkWave")
    workW -= bgShift

    Make/O/N=(numpnts(srcW)) $(LJZ_EDCFermiFit_BaseDF() + ":CurrentWorkMask") = 0
    Wave workMask = $(LJZ_EDCFermiFit_BaseDF() + ":CurrentWorkMask")
    workMask[pLo, pHi] = 1

    SVAR sWorkSrc = $(LJZ_EDCFermiFit_BaseDF() + ":WorkWaveSource")
    SVAR sWorkLabel = $(LJZ_EDCFermiFit_BaseDF() + ":WorkWaveLabel")
    sWorkSrc = sWave
    sWorkLabel = "RmBG current (offset=" + num2str(bgShift) + ")"

    LJZ_EDCFermiFit_ShowCurrentWave()
    return 0
End


// ============================================================================
//  Section 5. graph / current selection
// ============================================================================

Function LJZ_EDCFermiFit_CreateGraphSubwindow()
    LJZ_EDCFermiFit_EnsureDF()

    String panelName = LJZ_EDCFermiFit_PanelName()
    String graphName = LJZ_EDCFermiFit_GraphName()
    String graphPath = LJZ_EDCFermiFit_GraphPath()
    if (WinType(panelName) == 0)
        return -1
    endif

    if (LJZ_EDCFermiFit_HasChildSubwindow(panelName, graphName))
        KillWindow/Z $graphPath
    endif

    SVAR sWave = $(LJZ_EDCFermiFit_BaseDF() + ":WaveSel")
    Wave/Z w = LJZ_EDCFermiFit_GetActiveWaveForPath(sWave)
    if (!WaveExists(w) || !LJZ_EDCFermiFit_Is1DWave(w))
        Wave stub = $(LJZ_EDCFermiFit_BaseDF() + ":GraphStub")
        Display/HOST=$panelName/N=$graphName/W=(250,40,960,350) stub
        ModifyGraph/W=$graphPath margin(left)=48,margin(bottom)=32,margin(right)=16,margin(top)=12,mirror=2
        Label/W=$graphPath left "Intensity (a.u.)"
        Label/W=$graphPath bottom "Energy (eV)"
        return 0
    endif

    Display/HOST=$panelName/N=$graphName/W=(250,40,960,350) w
    ModifyGraph/W=$graphPath margin(left)=48,margin(bottom)=32,margin(right)=16,margin(top)=12,mirror=2
    Label/W=$graphPath left "Intensity (a.u.)"
    Label/W=$graphPath bottom "Energy (eV)"

    String dataNm = NameOfWave(w)
    ModifyGraph/W=$graphPath rgb($dataNm)=(0,0,0),lsize($dataNm)=1.5
    String dispLabel = LJZ_EDCFermiFit_GetDisplayLabelForPath(sWave)
    if (strlen(dispLabel) > 0)
        TextBox/W=$graphPath/K/N=tbData
        TextBox/W=$graphPath/C/N=tbData/F=0/A=LT dispLabel
    else
        TextBox/W=$graphPath/K/N=tbData
    endif

    Variable idx = LJZ_EDCFermiFit_ParseWaveIndex(NameOfWave($sWave))
    if (numtype(idx) == 0)
        SVAR sDF = $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF")
        String fitPath = LJZ_EDCFermiFit_df_with_colon(sDF) + LJZ_EDCFermiFit_FitWaveNameByIndex(idx)
        Wave/Z fitW = $fitPath
        if (WaveExists(fitW) && LJZ_EDCFermiFit_Is1DWave(fitW))
            AppendToGraph/W=$graphPath fitW
            String fitNm = NameOfWave(fitW)
            ModifyGraph/W=$graphPath rgb($fitNm)=(0,0,65535),lstyle($fitNm)=0,lsize($fitNm)=1.5
        endif
    endif

    return 0
End

Function LJZ_EDCFermiFit_UpdateGraphMarks()
    LJZ_EDCFermiFit_EnsureDF()

    String panelName = LJZ_EDCFermiFit_PanelName()
    String graphName = LJZ_EDCFermiFit_GraphName()
    String graphPath = LJZ_EDCFermiFit_GraphPath()
    if (!LJZ_EDCFermiFit_HasChildSubwindow(panelName, graphName))
        return 0
    endif

    NVAR FitX1 = $(LJZ_EDCFermiFit_BaseDF() + ":FitX1")
    NVAR FitX2 = $(LJZ_EDCFermiFit_BaseDF() + ":FitX2")
    NVAR LastEF = $(LJZ_EDCFermiFit_BaseDF() + ":LastEF")
    NVAR LastTe = $(LJZ_EDCFermiFit_BaseDF() + ":LastTe")
    NVAR LastRes = $(LJZ_EDCFermiFit_BaseDF() + ":LastRes")
    NVAR LastChiSq = $(LJZ_EDCFermiFit_BaseDF() + ":LastChiSq")
    NVAR LastOK = $(LJZ_EDCFermiFit_BaseDF() + ":LastOK")

    String tb = ""
    if (numtype(LastEF) == 0)
        tb += "EF = " + num2str(LastEF) + "\r"
    endif
    if (numtype(LastTe) == 0)
        tb += "Te = " + num2str(LastTe) + " K\r"
    endif
    if (numtype(LastRes) == 0)
        tb += "Res = " + num2str(LastRes) + " meV\r"
    endif
    if (numtype(LastChiSq) == 0)
        tb += "ChiSq = " + num2str(LastChiSq) + "\r"
    endif
    tb += "OK = " + num2str(LastOK)

    TextBox/W=$graphPath/K/N=tbFit
    if (strlen(tb) > 0)
        TextBox/W=$graphPath/C/N=tbFit/F=0/A=RT tb
    endif

    SetDrawLayer/W=$graphPath UserFront
    DrawAction/W=$graphPath getgroup=FitMarks, delete
    SetDrawEnv/W=$graphPath gstart, gname=FitMarks

    if (numtype(FitX1) == 0)
        SetDrawEnv/W=$graphPath xcoord=bottom,ycoord=prel,linefgc=(45000,45000,45000),linethick=1,dash=1
        DrawLine/W=$graphPath FitX1, 0, FitX1, 1
    endif
    if (numtype(FitX2) == 0)
        SetDrawEnv/W=$graphPath xcoord=bottom,ycoord=prel,linefgc=(45000,45000,45000),linethick=1,dash=1
        DrawLine/W=$graphPath FitX2, 0, FitX2, 1
    endif
    if (numtype(LastEF) == 0 && LastOK > 0)
        SetDrawEnv/W=$graphPath xcoord=bottom,ycoord=prel,linefgc=(0,0,65535),linethick=2,dash=2
        DrawLine/W=$graphPath LastEF, 0, LastEF, 1
    endif

    SetDrawEnv/W=$graphPath gstop
    return 0
End

Function LJZ_EDCFermiFit_ShowCurrentWave()
    LJZ_EDCFermiFit_EnsureDF()

    LJZ_EDCFermiFit_CreateGraphSubwindow()
    LJZ_EDCFermiFit_UpdateGraphMarks()
    return 0
End

Function LJZ_EDCFermiFit_RefreshCurrentSelection()
    LJZ_EDCFermiFit_LoadStoredResultForSelection()
    LJZ_EDCFermiFit_ShowCurrentWave()
    return 0
End


// ============================================================================
//  Section 6. result plotting
// ============================================================================

Function LJZ_EDCFermiFit_PlotOneResult(wPath, errPath, winName, titleStr, yLabel)
    String wPath, errPath, winName, titleStr, yLabel

    Wave/Z w = $wPath
    if (!WaveExists(w))
        return -1
    endif

    DoWindow/F $winName
    if (!V_flag)
        Display/N=$winName w
    else
        DoWindow/F $winName
        String nm = NameOfWave(w)
        RemoveFromGraph/Z/W=$winName $nm
        AppendToGraph/W=$winName w
    endif

    ModifyGraph/W=$winName mirror=2
    Label/W=$winName left yLabel
    Label/W=$winName bottom "Index / time"
    TextBox/W=$winName/K/N=tb0
    TextBox/W=$winName/C/N=tb0/F=0/A=LT titleStr

    Wave/Z we = $errPath
    if (WaveExists(we))
        String nm2 = NameOfWave(w)
        ErrorBars/W=$winName $nm2 Y,wave=(we,we)
    endif

    return 0
End

Function LJZ_EDCFermiFit_PlotResults()
    LJZ_EDCFermiFit_EnsureDF()

    SVAR sDF = $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF")
    String dfStr = LJZ_EDCFermiFit_df_with_colon(sDF)

    LJZ_EDCFermiFit_PlotOneResult(dfStr + "edc_ff_ef", dfStr + "edc_ff_ef_sig", "EDCFF_EF", "Fermi level", "EF (eV)")
    LJZ_EDCFermiFit_PlotOneResult(dfStr + "edc_ff_te", dfStr + "edc_ff_te_sig", "EDCFF_Te", "Temperature", "Te (K)")
    LJZ_EDCFermiFit_PlotOneResult(dfStr + "edc_ff_res", dfStr + "edc_ff_res_sig", "EDCFF_Res", "Resolution", "Res (meV)")
    return 0
End


// ============================================================================
//  Section 7. panel
// ============================================================================

Function LJZ_EDCFermiFit()
    LJZ_EDCFermiFit_EnsureDF()

    SVAR sSourceDF = $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF")
    if (CmpStr(sSourceDF, "root:") == 0)
        String curRun = LJZ_EDCFermiFit_GetCurrentRunDF()
        if (strlen(curRun) > 0)
            sSourceDF = curRun
        endif
    endif

    LJZ_EDCFermiFit_RebuildWaveList()
    LJZ_EDCFermiFit_OpenPanel()
    LJZ_EDCFermiFit_RefreshCurrentSelection()
    LJZ_EDCFermiFit_RefreshTitleBoxes()

    return 0
End

Function LJZ_EDCFermiFit_OpenPanel()
    LJZ_EDCFermiFit_EnsureDF()

    String p = LJZ_EDCFermiFit_PanelName()
    DoWindow/F $p
    if (V_flag == 0)
        NewPanel/N=$p /W=(80,80,1045,690)
    else
        DoWindow/F $p
        LJZ_EDCFermiFit_CreateGraphSubwindow()
        return 0
    endif

    SetVariable svSourceDF,pos={10,10},size={455,20},title="Source DF"
    SetVariable svSourceDF,value=_STR:LJZ_EDCFermiFit_BaseDF() + ":SourceDF",proc=LJZ_EDCFermiFit_SetVarProc

    Button btUseCurrent,pos={480,8},size={80,24},title="Current",proc=LJZ_EDCFermiFit_ButtonProc
    Button btScan,pos={575,8},size={70,24},title="Scan",proc=LJZ_EDCFermiFit_ButtonProc

    ListBox lbWave,pos={10,42},size={225,335},listWave=$(LJZ_EDCFermiFit_BaseDF() + ":LB_Disp"),selWave=$(LJZ_EDCFermiFit_BaseDF() + ":LB_Sel"),proc=LJZ_EDCFermiFit_ListBoxProc

    Button btRefresh,pos={250,364},size={82,28},title="Refresh",proc=LJZ_EDCFermiFit_ButtonProc
    Button btAutoWin,pos={340,364},size={82,28},title="AutoWin",proc=LJZ_EDCFermiFit_ButtonProc
    Button btCursor,pos={430,364},size={82,28},title="Cursors",proc=LJZ_EDCFermiFit_ButtonProc
    Button btRmBG,pos={520,364},size={82,28},title="RmBG",proc=LJZ_EDCFermiFit_ButtonProc
    Button btGuess,pos={610,364},size={82,28},title="Guess",proc=LJZ_EDCFermiFit_ButtonProc
    Button btFit,pos={700,364},size={72,28},title="Fit",proc=LJZ_EDCFermiFit_ButtonProc
    Button btFitAll,pos={780,364},size={82,28},title="Fit All",proc=LJZ_EDCFermiFit_ButtonProc
    Button btFitNext,pos={870,364},size={88,28},title="Fit+Next",proc=LJZ_EDCFermiFit_ButtonProc

    TitleBox tbWin,pos={250,404},size={160,18},frame=0,title="Fit window"
    SetVariable svFitX1,pos={250,428},size={150,20},title="Fit x1"
    SetVariable svFitX1,variable=$(LJZ_EDCFermiFit_BaseDF() + ":FitX1"),proc=LJZ_EDCFermiFit_SetVarProc

    SetVariable svFitX2,pos={415,428},size={150,20},title="Fit x2"
    SetVariable svFitX2,variable=$(LJZ_EDCFermiFit_BaseDF() + ":FitX2"),proc=LJZ_EDCFermiFit_SetVarProc

    TitleBox tbPar,pos={250,466},size={180,18},frame=0,title="Initial / hold parameters"
    TitleBox tbHold,pos={620,466},size={70,18},frame=0,title="Hold?"

    SetVariable svHeight,pos={250,492},size={175,20},title="Height"
    SetVariable svHeight,variable=$(LJZ_EDCFermiFit_BaseDF() + ":Height"),proc=LJZ_EDCFermiFit_SetVarProc
    CheckBox cbHHeight,pos={635,494},size={20,15},title="",mode=0,variable=$(LJZ_EDCFermiFit_BaseDF() + ":HHeight")

    SetVariable svEF,pos={250,518},size={175,20},title="EF"
    SetVariable svEF,variable=$(LJZ_EDCFermiFit_BaseDF() + ":EF"),proc=LJZ_EDCFermiFit_SetVarProc
    CheckBox cbHEF,pos={635,520},size={20,15},title="",mode=0,variable=$(LJZ_EDCFermiFit_BaseDF() + ":HEF")

    SetVariable svTe,pos={250,544},size={175,20},title="Te (K)"
    SetVariable svTe,variable=$(LJZ_EDCFermiFit_BaseDF() + ":Te"),proc=LJZ_EDCFermiFit_SetVarProc
    CheckBox cbHTe,pos={635,546},size={20,15},title="",mode=0,variable=$(LJZ_EDCFermiFit_BaseDF() + ":HTe")

    SetVariable svBG,pos={250,570},size={175,20},title="BG"
    SetVariable svBG,variable=$(LJZ_EDCFermiFit_BaseDF() + ":BG"),proc=LJZ_EDCFermiFit_SetVarProc
    CheckBox cbHBG,pos={635,572},size={20,15},title="",mode=0,variable=$(LJZ_EDCFermiFit_BaseDF() + ":HBG")

    SetVariable svRes,pos={250,596},size={175,20},title="Res (meV)"
    SetVariable svRes,variable=$(LJZ_EDCFermiFit_BaseDF() + ":Res"),proc=LJZ_EDCFermiFit_SetVarProc
    CheckBox cbHRes,pos={635,598},size={20,15},title="",mode=0,variable=$(LJZ_EDCFermiFit_BaseDF() + ":HRes")

    SetVariable svSB,pos={250,622},size={175,20},title="Shirley"
    SetVariable svSB,variable=$(LJZ_EDCFermiFit_BaseDF() + ":SB"),proc=LJZ_EDCFermiFit_SetVarProc
    CheckBox cbHSB,pos={635,624},size={20,15},title="",mode=0,variable=$(LJZ_EDCFermiFit_BaseDF() + ":HSB")

    TitleBox tbLast,pos={690,466},size={180,18},frame=0,title="Stored result for selection"

    SetVariable svLastEF,pos={690,492},size={170,20},title="Last EF"
    SetVariable svLastEF,variable=$(LJZ_EDCFermiFit_BaseDF() + ":LastEF"),noedit=1

    SetVariable svLastTe,pos={690,518},size={170,20},title="Last Te"
    SetVariable svLastTe,variable=$(LJZ_EDCFermiFit_BaseDF() + ":LastTe"),noedit=1

    SetVariable svLastRes,pos={690,544},size={170,20},title="Last Res"
    SetVariable svLastRes,variable=$(LJZ_EDCFermiFit_BaseDF() + ":LastRes"),noedit=1

    SetVariable svLastBG,pos={690,570},size={170,20},title="Last BG"
    SetVariable svLastBG,variable=$(LJZ_EDCFermiFit_BaseDF() + ":LastBG"),noedit=1

    SetVariable svLastChiSq,pos={690,596},size={170,20},title="Last ChiSq"
    SetVariable svLastChiSq,variable=$(LJZ_EDCFermiFit_BaseDF() + ":LastChiSq"),noedit=1

    SetVariable svLastOK,pos={690,622},size={170,20},title="Last OK"
    SetVariable svLastOK,variable=$(LJZ_EDCFermiFit_BaseDF() + ":LastOK"),noedit=1

    Button btPlotResult,pos={875,618},size={80,24},title="Plot",proc=LJZ_EDCFermiFit_ButtonProc

    SetVariable svSelWave,pos={10,654},size={945,20},title="Selected Wave:"
    SetVariable svSelWave,value=_STR:LJZ_EDCFermiFit_BaseDF() + ":WaveSel",noedit=1

    TitleBox tbMsg,pos={10,676},size={945,18},frame=0,title="Model: [FD step convolved with Gaussian] + BG + normalized Shirley; RmBG only offsets current work wave"

    LJZ_EDCFermiFit_CreateGraphSubwindow()
    return 0
End

Function LJZ_EDCFermiFit_RefreshTitleBoxes()
    String p = LJZ_EDCFermiFit_PanelName()
    if (WinType(p) == 0)
        return 0
    endif

    SVAR sWave = $(LJZ_EDCFermiFit_BaseDF() + ":WaveSel")
    SVAR sDF   = $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF")

    SetVariable svSourceDF win=$p, value=_STR:sDF
    SetVariable svSelWave  win=$p, value=_STR:sWave

    return 0
End


// ============================================================================
//  Section 8. callbacks
// ============================================================================

Function LJZ_EDCFermiFit_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    String ctrlName = ba.ctrlName

    if (CmpStr(ctrlName, "btUseCurrent") == 0)
        LJZ_EDCFermiFit_UseCurrentRunDF()
        return 0
    endif

    if (CmpStr(ctrlName, "btScan") == 0)
        LJZ_EDCFermiFit_RebuildWaveList()
        LJZ_EDCFermiFit_RefreshCurrentSelection()
        LJZ_EDCFermiFit_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(ctrlName, "btRefresh") == 0)
        LJZ_EDCFermiFit_RefreshCurrentSelection()
        return 0
    endif

    if (CmpStr(ctrlName, "btAutoWin") == 0)
        LJZ_EDCFermiFit_AutoFillWindow()
        LJZ_EDCFermiFit_UpdateGraphMarks()
        return 0
    endif

    if (CmpStr(ctrlName, "btCursor") == 0)
        LJZ_EDCFermiFit_LoadCursorsToWindow()
        LJZ_EDCFermiFit_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(ctrlName, "btRmBG") == 0)
        LJZ_EDCFermiFit_RmBGCurrent()
        return 0
    endif

    if (CmpStr(ctrlName, "btGuess") == 0)
        LJZ_EDCFermiFit_GuessCurrent()
        LJZ_EDCFermiFit_UpdateGraphMarks()
        return 0
    endif

    if (CmpStr(ctrlName, "btFit") == 0)
        LJZ_EDCFermiFit_FitCurrent()
        return 0
    endif

    if (CmpStr(ctrlName, "btFitAll") == 0)
        LJZ_EDCFermiFit_FitAll()
        return 0
    endif

    if (CmpStr(ctrlName, "btFitNext") == 0)
        LJZ_EDCFermiFit_FitAndNext()
        return 0
    endif

    if (CmpStr(ctrlName, "btPlotResult") == 0)
        LJZ_EDCFermiFit_PlotResults()
        return 0
    endif

    return 0
End

Function LJZ_EDCFermiFit_SetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    if ((sva.eventCode != 1) && (sva.eventCode != 2))
        return 0
    endif

    String ctrlName = sva.ctrlName

    if (CmpStr(ctrlName, "svSourceDF") == 0)
        SVAR sDF = $(LJZ_EDCFermiFit_BaseDF() + ":SourceDF")
        sDF = LJZ_EDCFermiFit_df_with_colon(sva.sval)
        LJZ_EDCFermiFit_ClearCurrentWorkWave()
        return 0
    endif

    if ((CmpStr(ctrlName, "svFitX1") == 0) || (CmpStr(ctrlName, "svFitX2") == 0))
        LJZ_EDCFermiFit_UpdateGraphMarks()
        return 0
    endif

    return 0
End

Function LJZ_EDCFermiFit_ListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if ((lba.eventCode != 1) && (lba.eventCode != 4))
        return 0
    endif

    if (CmpStr(lba.ctrlName, "lbWave") == 0)
        if (lba.row >= 0)
            LJZ_EDCFermiFit_SelectWaveRow(lba.row)
            LJZ_EDCFermiFit_RefreshCurrentSelection()
            LJZ_EDCFermiFit_RefreshTitleBoxes()
        endif
    endif

    return 0
End
