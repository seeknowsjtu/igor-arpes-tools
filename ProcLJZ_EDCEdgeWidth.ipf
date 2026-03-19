#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma DefaultTab={3,20,4}

// ============================================================================
//  LJZ_EDCEdgeWidth : panel-inline edge-width tool for existing edc_show_* waves
//  只负责：
//    1) 从当前 EDCExtract RunDF 或手动指定 DF 扫描 edc_show_*
//    2) 在 panel 内联 graph 中显示当前选中的 edc_show_i
//    3) 在两个 x-window 内分别寻找 rising / falling center
//    4) 把 XRise / XFall / Width 写回 SourceDF 下的结果 wave
//
//  不负责：
//    - 3D 提取
//    - smoothing
//    - fit
// ============================================================================

Menu "ARPES_LJZ"
    "2026EDCEdgeWidth_LJZ", LJZ_EDCEdgeWidth()
End


// ============================================================================
//  Section 0. paths / state
// ============================================================================

Function/S LJZ_EDCEdgeWidth_BaseDF()
    return "root:ARPES_LJZ:EDCEdgeWidth"
End

Function/S LJZ_EDCEdgeWidth_PanelName()
    return "LJZ_EDCEdgeWidth_Panel"
End

Function/S LJZ_EDCEdgeWidth_GraphName()
    return "edcGraph"
End

Function/S LJZ_EDCEdgeWidth_GraphPath()
    return LJZ_EDCEdgeWidth_PanelName() + "#" + LJZ_EDCEdgeWidth_GraphName()
End

Function/S LJZ_EDCEdgeWidth_df_with_colon(inStr)
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

Function LJZ_EDCEdgeWidth_df_exists(dfStr)
    String dfStr
    String s = LJZ_EDCEdgeWidth_df_with_colon(dfStr)
    return DataFolderExists(s)
End

Function LJZ_EDCEdgeWidth_Is1DWave(w)
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

Function/S LJZ_EDCEdgeWidth_WaveShortLabel(wPath)
    String wPath

    String nm = NameOfWave($wPath)
    if (strlen(nm) == 0)
        nm = wPath
    endif

    return nm
End

Function LJZ_EDCEdgeWidth_Clamp(v, lo, hi)
    Variable v, lo, hi

    if (v < lo)
        return lo
    endif
    if (v > hi)
        return hi
    endif
    return v
End

Function/S LJZ_EDCEdgeWidth_ShortenForTitle(s, maxLen)
    String s
    Variable maxLen

    if (strlen(s) <= maxLen)
        return s
    endif

    return s[0, maxLen-4] + "..."
End

Function LJZ_EDCEdgeWidth_HasChildSubwindow(hostWin, childName)
    String hostWin, childName

    String childList = ChildWindowList(hostWin)
    return (WhichListItem(childName, childList, ";", 0, 0) >= 0)
End

Function LJZ_EDCEdgeWidth_EnsureDF()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O $(LJZ_EDCEdgeWidth_BaseDF())

    SVAR/Z sSourceDF = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")
    if (!SVAR_Exists(sSourceDF))
        String/G $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF") = "root:"
    endif

    SVAR/Z sWave = $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel")
    if (!SVAR_Exists(sWave))
        String/G $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel") = ""
    endif

    NVAR/Z SelRow = $(LJZ_EDCEdgeWidth_BaseDF() + ":SelRow")
    if (!NVAR_Exists(SelRow))
        Variable/G $(LJZ_EDCEdgeWidth_BaseDF() + ":SelRow") = -1
    endif

    NVAR/Z RiseX1 = $(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX1")
    if (!NVAR_Exists(RiseX1))
        Variable/G $(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX1") = NaN
    endif

    NVAR/Z RiseX2 = $(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX2")
    if (!NVAR_Exists(RiseX2))
        Variable/G $(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX2") = NaN
    endif

    NVAR/Z FallX1 = $(LJZ_EDCEdgeWidth_BaseDF() + ":FallX1")
    if (!NVAR_Exists(FallX1))
        Variable/G $(LJZ_EDCEdgeWidth_BaseDF() + ":FallX1") = NaN
    endif

    NVAR/Z FallX2 = $(LJZ_EDCEdgeWidth_BaseDF() + ":FallX2")
    if (!NVAR_Exists(FallX2))
        Variable/G $(LJZ_EDCEdgeWidth_BaseDF() + ":FallX2") = NaN
    endif

    NVAR/Z XRise = $(LJZ_EDCEdgeWidth_BaseDF() + ":XRise")
    if (!NVAR_Exists(XRise))
        Variable/G $(LJZ_EDCEdgeWidth_BaseDF() + ":XRise") = NaN
    endif

    NVAR/Z XFall = $(LJZ_EDCEdgeWidth_BaseDF() + ":XFall")
    if (!NVAR_Exists(XFall))
        Variable/G $(LJZ_EDCEdgeWidth_BaseDF() + ":XFall") = NaN
    endif

    NVAR/Z Width = $(LJZ_EDCEdgeWidth_BaseDF() + ":Width")
    if (!NVAR_Exists(Width))
        Variable/G $(LJZ_EDCEdgeWidth_BaseDF() + ":Width") = NaN
    endif

    Wave/T/Z wDisp = $(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Disp")
    if (!WaveExists(wDisp))
        Make/O/T/N=0 $(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Disp")
    endif

    Wave/Z wSel = $(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Sel")
    if (!WaveExists(wSel))
        Make/O/N=0 $(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Sel") = 0
    endif

    Make/O/N=2 $(LJZ_EDCEdgeWidth_BaseDF() + ":GraphStub") = NaN
    SetScale/P x, 0, 1, "", $(LJZ_EDCEdgeWidth_BaseDF() + ":GraphStub")

    return 0
End


// ============================================================================
//  Section 1. source DF
// ============================================================================

// 优先从现有 EDCExtract 拿当前 RunDF
Function/S LJZ_EDCEdgeWidth_GetCurrentRunDF()
    String out = ""

    SVAR/Z sRun1 = root:ARPES_LJZ:EDCExtract:RunDF
    if (SVAR_Exists(sRun1))
        if (strlen(sRun1) > 0 && DataFolderExists(RemoveEnding(sRun1, ":")))
            out = LJZ_EDCEdgeWidth_df_with_colon(sRun1)
            return out
        endif
    endif

    // 兼容 EDCWB TargetDF
    SVAR/Z sRun2 = root:Packages:ARPES_LJZ:EDCWB:TargetDF
    if (SVAR_Exists(sRun2))
        if (strlen(sRun2) > 0 && DataFolderExists(RemoveEnding(sRun2, ":")))
            out = LJZ_EDCEdgeWidth_df_with_colon(sRun2)
            return out
        endif
    endif

    return ""
End

Function LJZ_EDCEdgeWidth_UseCurrentRunDF()
    LJZ_EDCEdgeWidth_EnsureDF()

    SVAR sSourceDF = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")
    String runDF = LJZ_EDCEdgeWidth_GetCurrentRunDF()

    if (strlen(runDF) == 0)
        DoAlert 0, "没有找到当前 EDCExtract 的有效 RunDF。"
        return -1
    endif

    sSourceDF = runDF
    LJZ_EDCEdgeWidth_RebuildWaveList()
    LJZ_EDCEdgeWidth_RefreshCurrentSelection()
    LJZ_EDCEdgeWidth_RefreshTitleBoxes()

    return 0
End


// ============================================================================
//  Section 2. scan edc_show_*
// ============================================================================

Function LJZ_EDCEdgeWidth_IsTargetEDCWave(w, nm)
    Wave/Z w
    String nm

    if (!LJZ_EDCEdgeWidth_Is1DWave(w))
        return 0
    endif

    if (!StringMatch(nm, "edc_show_*"))
        return 0
    endif

    return 1
End

Function LJZ_EDCEdgeWidth_ParseWaveIndex(nm)
    String nm

    Variable idx = NaN
    // 在 Igor 中 sscanf 是指令，结果保存在内置变量 V_flag 中
    sscanf nm, "edc_show_%d", idx

    if (V_flag != 1)
        return NaN
    endif

    return idx
End

Function/S LJZ_EDCEdgeWidth_InsertWavePathSorted(pathIn, listIn)
    String pathIn, listIn

    String out = listIn
    String nmIn = NameOfWave($pathIn)
    Variable idxIn = LJZ_EDCEdgeWidth_ParseWaveIndex(nmIn)
    Variable n = ItemsInList(out, ";")
    Variable i

    if (n <= 0)
        return AddListItem(pathIn, "", ";", 0)
    endif

    for (i = 0; i < n; i += 1)
        String pathCur = StringFromList(i, out, ";")
        String nmCur = NameOfWave($pathCur)
        Variable idxCur = LJZ_EDCEdgeWidth_ParseWaveIndex(nmCur)
        if (numtype(idxCur) != 0 || idxIn < idxCur)
            return AddListItem(pathIn, out, ";", i)
        endif
    endfor

    return AddListItem(pathIn, out, ";", Inf)
End

Function/S LJZ_EDCEdgeWidth_ListEDCShowWaves_OneDF(dfStr)
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
        if (!LJZ_EDCEdgeWidth_IsTargetEDCWave(w, nm))
            continue
        endif
        if (numtype(LJZ_EDCEdgeWidth_ParseWaveIndex(nm)) != 0)
            continue
        endif

        out = LJZ_EDCEdgeWidth_InsertWavePathSorted(dfStr + nm, out)
    endfor

    return out
End

Function/S LJZ_EDCEdgeWidth_CurrentWaveList()
    SVAR sDF = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")
    return LJZ_EDCEdgeWidth_ListEDCShowWaves_OneDF(LJZ_EDCEdgeWidth_df_with_colon(sDF))
End

Function LJZ_EDCEdgeWidth_MaxWaveIndexInList(listStr)
    String listStr

    Variable maxIdx = -1
    Variable n = ItemsInList(listStr, ";")
    Variable i

    for (i = 0; i < n; i += 1)
        String wPath = StringFromList(i, listStr, ";")
        Variable idx = LJZ_EDCEdgeWidth_ParseWaveIndex(NameOfWave($wPath))
        if (numtype(idx) == 0)
            maxIdx = max(maxIdx, idx)
        endif
    endfor

    return maxIdx
End

Function LJZ_EDCEdgeWidth_ResultWaveShouldUseRunScale(dfStr)
    String dfStr

    String srcDF = LJZ_EDCEdgeWidth_df_with_colon(dfStr)
    String curRun = LJZ_EDCEdgeWidth_GetCurrentRunDF()
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

Function LJZ_EDCEdgeWidth_ApplyResultWaveScale(w, dfStr)
    Wave w
    String dfStr

    if (LJZ_EDCEdgeWidth_ResultWaveShouldUseRunScale(dfStr))
        NVAR Run_t0 = root:ARPES_LJZ:EDCExtract:Run_t0
        NVAR Run_dt = root:ARPES_LJZ:EDCExtract:Run_dt
        SetScale/P x, Run_t0, Run_dt, "", w
    else
        SetScale/P x, 0, 1, "", w
    endif

    return 0
End

// 维护 SourceDF 下的结果 wave；结果长度必须按 edc_show_i 的最大编号 + 1，
// 这样即使某些编号缺失，也能保证 edc_show_i -> result[i] 一一对应，缺口留 NaN。
Function LJZ_EDCEdgeWidth_EnsureResultWaves()
    LJZ_EDCEdgeWidth_EnsureDF()

    SVAR sDF = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")
    String dfStr = LJZ_EDCEdgeWidth_df_with_colon(sDF)
    String listStr = LJZ_EDCEdgeWidth_ListEDCShowWaves_OneDF(dfStr)
    Variable maxIdx = LJZ_EDCEdgeWidth_MaxWaveIndexInList(listStr)
    Variable nResult = maxIdx + 1

    if (!DataFolderExists(dfStr))
        return -1
    endif

    if (nResult < 0)
        nResult = 0
    endif

    Wave/Z wRise = $(dfStr + "edc_xrise")
    if (!WaveExists(wRise))
        Make/O/N=(nResult) $(dfStr + "edc_xrise") = NaN
    else
        Variable oldRiseN = numpnts(wRise)
        if (oldRiseN != nResult)
            Redimension/N=(nResult) wRise
            if (nResult > oldRiseN)
                wRise[oldRiseN, nResult-1] = NaN
            endif
        endif
    endif

    Wave/Z wFall = $(dfStr + "edc_xfall")
    if (!WaveExists(wFall))
        Make/O/N=(nResult) $(dfStr + "edc_xfall") = NaN
    else
        Variable oldFallN = numpnts(wFall)
        if (oldFallN != nResult)
            Redimension/N=(nResult) wFall
            if (nResult > oldFallN)
                wFall[oldFallN, nResult-1] = NaN
            endif
        endif
    endif

    Wave/Z wWidth = $(dfStr + "edc_width")
    if (!WaveExists(wWidth))
        Make/O/N=(nResult) $(dfStr + "edc_width") = NaN
    else
        Variable oldWidthN = numpnts(wWidth)
        if (oldWidthN != nResult)
            Redimension/N=(nResult) wWidth
            if (nResult > oldWidthN)
                wWidth[oldWidthN, nResult-1] = NaN
            endif
        endif
    endif

    Wave wRise2 = $(dfStr + "edc_xrise")
    Wave wFall2 = $(dfStr + "edc_xfall")
    Wave wWidth2 = $(dfStr + "edc_width")
    LJZ_EDCEdgeWidth_ApplyResultWaveScale(wRise2, dfStr)
    LJZ_EDCEdgeWidth_ApplyResultWaveScale(wFall2, dfStr)
    LJZ_EDCEdgeWidth_ApplyResultWaveScale(wWidth2, dfStr)

    return 0
End

Function LJZ_EDCEdgeWidth_RebuildWaveList()
    LJZ_EDCEdgeWidth_EnsureDF()

    SVAR sDF   = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")
    SVAR sWave = $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel")
    NVAR SelRow = $(LJZ_EDCEdgeWidth_BaseDF() + ":SelRow")

    String dfStr = LJZ_EDCEdgeWidth_df_with_colon(sDF)
    if (!DataFolderExists(dfStr))
        Make/O/T/N=0 $(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Disp")
        Make/O/N=0   $(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Sel")
        sWave = ""
        SelRow = -1
        return -1
    endif

    String prevWave = sWave
    String listStr = LJZ_EDCEdgeWidth_ListEDCShowWaves_OneDF(dfStr)
    Variable n = ItemsInList(listStr, ";")

    Make/O/T/N=(n) $(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Disp")
    Make/O/N=(n)   $(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Sel") = 0

    Wave/T wDisp = $(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Disp")
    Wave   wSel  = $(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Sel")

    Variable i
    String wPath
    for (i = 0; i < n; i += 1)
        wPath = StringFromList(i, listStr, ";")
        wDisp[i] = LJZ_EDCEdgeWidth_WaveShortLabel(wPath)
    endfor

    Variable keepRow = WhichListItem(prevWave, listStr, ";", 0, 0)
    if (keepRow < 0)
        keepRow = 0
    endif

    if (n > 0)
        keepRow = LJZ_EDCEdgeWidth_Clamp(keepRow, 0, n-1)
        wSel[keepRow] = 1
        sWave = StringFromList(keepRow, listStr, ";")
        SelRow = keepRow
    else
        sWave = ""
        SelRow = -1
    endif

    LJZ_EDCEdgeWidth_EnsureResultWaves()
    return 0
End

Function LJZ_EDCEdgeWidth_SelectWaveRow(row)
    Variable row

    LJZ_EDCEdgeWidth_EnsureDF()

    String listStr = LJZ_EDCEdgeWidth_CurrentWaveList()
    Variable n = ItemsInList(listStr, ";")
    if (n <= 0)
        return -1
    endif

    row = max(0, min(n - 1, row))

    Wave wSel = $(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Sel")
    if (numpnts(wSel) != n)
        Redimension/N=(n) wSel
    endif
    wSel = 0
    wSel[row] = 1

    SVAR sWave = $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel")
    NVAR SelRow = $(LJZ_EDCEdgeWidth_BaseDF() + ":SelRow")
    sWave = StringFromList(row, listStr, ";")
    SelRow = row

    return 0
End

Function LJZ_EDCEdgeWidth_CurrentWaveResultIndex()
    SVAR sWave = $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        return NaN
    endif

    return LJZ_EDCEdgeWidth_ParseWaveIndex(NameOfWave($sWave))
End

Function LJZ_EDCEdgeWidth_ClearCurrentResultDisplay()
    NVAR XRise = $(LJZ_EDCEdgeWidth_BaseDF() + ":XRise")
    NVAR XFall = $(LJZ_EDCEdgeWidth_BaseDF() + ":XFall")
    NVAR Width = $(LJZ_EDCEdgeWidth_BaseDF() + ":Width")

    XRise = NaN
    XFall = NaN
    Width = NaN

    String panelName = LJZ_EDCEdgeWidth_PanelName()
    String graphName = LJZ_EDCEdgeWidth_GraphName()
    String graphPath = LJZ_EDCEdgeWidth_GraphPath()

    if (LJZ_EDCEdgeWidth_HasChildSubwindow(panelName, graphName))
        TextBox/W=$graphPath/K/N=tbEdge
        SetDrawLayer/W=$graphPath UserFront
        DrawAction/W=$graphPath getgroup=EdgeMarks, delete
    endif

    return 0
End

Function LJZ_EDCEdgeWidth_LoadStoredResultForSelection()
    LJZ_EDCEdgeWidth_ClearCurrentResultDisplay()

    SVAR sDF = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")
    Variable idx = LJZ_EDCEdgeWidth_CurrentWaveResultIndex()
    if (numtype(idx) != 0)
        return -1
    endif

    String dfStr = LJZ_EDCEdgeWidth_df_with_colon(sDF)
    Wave/Z wRise = $(dfStr + "edc_xrise")
    Wave/Z wFall = $(dfStr + "edc_xfall")
    Wave/Z wWidth = $(dfStr + "edc_width")
    if (!WaveExists(wRise) || !WaveExists(wFall) || !WaveExists(wWidth))
        return -1
    endif
    if (idx < 0 || idx >= numpnts(wRise) || idx >= numpnts(wFall) || idx >= numpnts(wWidth))
        return -1
    endif

    NVAR XRise = $(LJZ_EDCEdgeWidth_BaseDF() + ":XRise")
    NVAR XFall = $(LJZ_EDCEdgeWidth_BaseDF() + ":XFall")
    NVAR Width = $(LJZ_EDCEdgeWidth_BaseDF() + ":Width")

    XRise = wRise[idx]
    XFall = wFall[idx]
    Width = wWidth[idx]

    return 0
End

// 结果写回严格按 edc_show_i 的 i 写入，而不是按 listbox row，
// 因为 list 可能有缺号，row 与真实结果索引并不总是相同。
Function LJZ_EDCEdgeWidth_WriteResultForWave(wPath, xRiseVal, xFallVal, widthVal)
    String wPath
    Variable xRiseVal, xFallVal, widthVal

    SVAR sDF = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")
    String dfStr = LJZ_EDCEdgeWidth_df_with_colon(sDF)
    Variable idx = LJZ_EDCEdgeWidth_ParseWaveIndex(NameOfWave($wPath))

    if (numtype(idx) != 0)
        return -1
    endif

    LJZ_EDCEdgeWidth_EnsureResultWaves()

    Wave/Z wRise = $(dfStr + "edc_xrise")
    Wave/Z wFall = $(dfStr + "edc_xfall")
    Wave/Z wWidth = $(dfStr + "edc_width")
    if (!WaveExists(wRise) || !WaveExists(wFall) || !WaveExists(wWidth))
        return -1
    endif
    if (idx < 0 || idx >= numpnts(wRise) || idx >= numpnts(wFall) || idx >= numpnts(wWidth))
        return -1
    endif

    wRise[idx] = xRiseVal
    wFall[idx] = xFallVal
    wWidth[idx] = widthVal

    return 0
End


// ============================================================================
//  Section 3. edge kernel
// ============================================================================

Function LJZ_EDCEdgeWidth_EdgeCenter(w, x1, x2, isRising)
    Wave w
    Variable x1, x2, isRising

    Variable n = numpnts(w)
    if (n < 2)
        return NaN
    endif

    Variable p1 = round(x2pnt(w, x1))
    Variable p2 = round(x2pnt(w, x2))

    if (numtype(p1) != 0 || numtype(p2) != 0)
        return NaN
    endif

    p1 = LJZ_EDCEdgeWidth_Clamp(p1, 0, n-1)
    p2 = LJZ_EDCEdgeWidth_Clamp(p2, 0, n-1)

    Variable pLo = min(p1, p2)
    Variable pHi = max(p1, p2)

    if (pHi - pLo < 1)
        return NaN
    endif

    Variable p
    Variable ymin = Inf
    Variable ymax = -Inf

    for (p = pLo; p <= pHi; p += 1)
        if (numtype(w[p]) != 0)
            continue
        endif
        ymin = min(ymin, w[p])
        ymax = max(ymax, w[p])
    endfor

    if (numtype(ymin) != 0 || numtype(ymax) != 0)
        return NaN
    endif
    if (ymax <= ymin)
        return NaN
    endif

    Variable yMid = 0.5 * (ymin + ymax)

    Variable bestX = NaN
    Variable bestScore = -Inf

    // 先找半高 crossing
    for (p = pLo; p < pHi; p += 1)
        Variable xA = pnt2x(w, p)
        Variable xB = pnt2x(w, p+1)
        Variable yA = w[p]
        Variable yB = w[p+1]

        if (numtype(xA) != 0 || numtype(xB) != 0 || numtype(yA) != 0 || numtype(yB) != 0)
            continue
        endif
        if (xA == xB)
            continue
        endif
        if (yA == yB)
            continue
        endif

        Variable cross = ((yA - yMid) * (yB - yMid) <= 0)
        if (!cross)
            continue
        endif

        Variable slopeX = (yB - yA) / (xB - xA)

        if (isRising)
            if (slopeX <= 0)
                continue
            endif
        else
            if (slopeX >= 0)
                continue
            endif
        endif

        Variable frac = (yMid - yA) / (yB - yA)
        if (frac < 0 || frac > 1)
            continue
        endif

        Variable xC = xA + frac * (xB - xA)
        Variable score = abs(slopeX)

        if (score > bestScore)
            bestScore = score
            bestX = xC
        endif
    endfor

    // fallback：改找最大斜率中点
    if (numtype(bestX) != 0)
        bestScore = -Inf

        for (p = pLo; p < pHi; p += 1)
            Variable xxA = pnt2x(w, p)
            Variable xxB = pnt2x(w, p+1)
            Variable yyA = w[p]
            Variable yyB = w[p+1]

            if (numtype(xxA) != 0 || numtype(xxB) != 0 || numtype(yyA) != 0 || numtype(yyB) != 0)
                continue
            endif
            if (xxA == xxB)
                continue
            endif

            Variable sX = (yyB - yyA) / (xxB - xxA)

            if (isRising)
                if (sX <= 0)
                    continue
                endif
            else
                if (sX >= 0)
                    continue
                endif
            endif

            Variable sc = abs(sX)
            if (sc > bestScore)
                bestScore = sc
                bestX = 0.5 * (xxA + xxB)
            endif
        endfor
    endif

    return bestX
End


// ============================================================================
//  Section 4. graph / measurement
// ============================================================================

// panel 内 graph 通过 HOST=subwindow 创建；这里始终把 panel#subwindow 当作 subwindow path，
// 只通过 /W=graphPath、ChildWindowList() 和 KillWindow/Z 这套方式管理，不把它当普通 window name。
Function LJZ_EDCEdgeWidth_CreateGraphSubwindow()
    LJZ_EDCEdgeWidth_EnsureDF()

    String panelName = LJZ_EDCEdgeWidth_PanelName()
    String graphName = LJZ_EDCEdgeWidth_GraphName()
    String graphPath = LJZ_EDCEdgeWidth_GraphPath()
    if (WinType(panelName) == 0)
        return -1
    endif

    if (LJZ_EDCEdgeWidth_HasChildSubwindow(panelName, graphName))
        KillWindow/Z $graphPath
    endif

    SVAR sWave = $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel")
    Wave/Z w = $sWave
    if (!WaveExists(w) || !LJZ_EDCEdgeWidth_Is1DWave(w))
        Wave stub = $(LJZ_EDCEdgeWidth_BaseDF() + ":GraphStub")
        Display/HOST=$panelName/N=$graphName/W=(250,40,960,360) stub
        ModifyGraph/W=$graphPath margin(left)=48,margin(bottom)=32,margin(right)=16,margin(top)=12,mirror=2
        Label/W=$graphPath left "Intensity (a.u.)"
        Label/W=$graphPath bottom "Energy"
        return 0
    endif

    Display/HOST=$panelName/N=$graphName/W=(250,40,960,360) w
    ModifyGraph/W=$graphPath margin(left)=48,margin(bottom)=32,margin(right)=16,margin(top)=12,mirror=2
    Label/W=$graphPath left "Intensity (a.u.)"
    Label/W=$graphPath bottom "Energy"

    return 0
End

Function LJZ_EDCEdgeWidth_UpdateGraphMarks()
    LJZ_EDCEdgeWidth_EnsureDF()

    String panelName = LJZ_EDCEdgeWidth_PanelName()
    String graphName = LJZ_EDCEdgeWidth_GraphName()
    String graphPath = LJZ_EDCEdgeWidth_GraphPath()
    if (!LJZ_EDCEdgeWidth_HasChildSubwindow(panelName, graphName))
        return 0
    endif

    NVAR XRise = $(LJZ_EDCEdgeWidth_BaseDF() + ":XRise")
    NVAR XFall = $(LJZ_EDCEdgeWidth_BaseDF() + ":XFall")
    NVAR Width = $(LJZ_EDCEdgeWidth_BaseDF() + ":Width")
    NVAR RiseX1 = $(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX1")
    NVAR RiseX2 = $(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX2")
    NVAR FallX1 = $(LJZ_EDCEdgeWidth_BaseDF() + ":FallX1")
    NVAR FallX2 = $(LJZ_EDCEdgeWidth_BaseDF() + ":FallX2")

    String tb = ""
    if (numtype(XRise) == 0)
        tb += "Rise = " + num2str(XRise) + "\r"
    endif
    if (numtype(XFall) == 0)
        tb += "Fall = " + num2str(XFall) + "\r"
    endif
    if (numtype(Width) == 0)
        tb += "Width = " + num2str(Width)
    endif

    TextBox/W=$graphPath/K/N=tbEdge
    if (strlen(tb) > 0)
        TextBox/W=$graphPath/C/N=tbEdge/F=0/A=RT tb
    endif

    SetDrawLayer/W=$graphPath UserFront
    DrawAction/W=$graphPath getgroup=EdgeMarks, delete

    SetDrawEnv/W=$graphPath gstart, gname=EdgeMarks

    // ------------------------------
    // 先画搜索窗口边界（细一点、浅一点）
    // ------------------------------
    if (numtype(RiseX1) == 0)
        SetDrawEnv/W=$graphPath xcoord=bottom,ycoord=prel,linefgc=(45000,45000,65535),linethick=1,dash=1
        DrawLine/W=$graphPath RiseX1, 0, RiseX1, 1
    endif

    if (numtype(RiseX2) == 0)
        SetDrawEnv/W=$graphPath xcoord=bottom,ycoord=prel,linefgc=(45000,45000,65535),linethick=1,dash=1
        DrawLine/W=$graphPath RiseX2, 0, RiseX2, 1
    endif

    if (numtype(FallX1) == 0)
        SetDrawEnv/W=$graphPath xcoord=bottom,ycoord=prel,linefgc=(65535,45000,45000),linethick=1,dash=1
        DrawLine/W=$graphPath FallX1, 0, FallX1, 1
    endif

    if (numtype(FallX2) == 0)
        SetDrawEnv/W=$graphPath xcoord=bottom,ycoord=prel,linefgc=(65535,45000,45000),linethick=1,dash=1
        DrawLine/W=$graphPath FallX2, 0, FallX2, 1
    endif

    // ------------------------------
    // 再画最终找到的位置（粗一点）
    // ------------------------------
    if (numtype(XRise) == 0)
        SetDrawEnv/W=$graphPath xcoord=bottom,ycoord=prel,linefgc=(0,0,65535),linethick=2,dash=2
        DrawLine/W=$graphPath XRise, 0, XRise, 1
    endif

    if (numtype(XFall) == 0)
        SetDrawEnv/W=$graphPath xcoord=bottom,ycoord=prel,linefgc=(65535,0,0),linethick=2,dash=2
        DrawLine/W=$graphPath XFall, 0, XFall, 1
    endif

    SetDrawEnv/W=$graphPath gstop
    return 0
End

Function LJZ_EDCEdgeWidth_ShowCurrentWave()
    LJZ_EDCEdgeWidth_EnsureDF()

    SVAR sWave = $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        LJZ_EDCEdgeWidth_CreateGraphSubwindow()
        LJZ_EDCEdgeWidth_ClearCurrentResultDisplay()
        LJZ_EDCEdgeWidth_RefreshTitleBoxes()
        return -1
    endif

    Wave/Z w = $sWave
    if (!WaveExists(w) || !LJZ_EDCEdgeWidth_Is1DWave(w))
        LJZ_EDCEdgeWidth_CreateGraphSubwindow()
        LJZ_EDCEdgeWidth_ClearCurrentResultDisplay()
        LJZ_EDCEdgeWidth_RefreshTitleBoxes()
        return -1
    endif

    LJZ_EDCEdgeWidth_CreateGraphSubwindow()
    LJZ_EDCEdgeWidth_UpdateGraphMarks()
    LJZ_EDCEdgeWidth_RefreshTitleBoxes()
    return 0
End

Function LJZ_EDCEdgeWidth_AutoFillWindows()
    LJZ_EDCEdgeWidth_EnsureDF()

    SVAR sWave = $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        DoAlert 0, "请先选择一个 edc_show_* 波形。"
        return -1
    endif

    Wave/Z w = $sWave
    if (!WaveExists(w) || !LJZ_EDCEdgeWidth_Is1DWave(w))
        DoAlert 0, "当前选择不是有效的 1D wave。"
        return -1
    endif

    Variable n = numpnts(w)
    if (n < 2)
        return -1
    endif

    Variable xA = pnt2x(w, 0)
    Variable xB = pnt2x(w, n-1)

    Variable xMin = min(xA, xB)
    Variable xMax = max(xA, xB)
    Variable span = xMax - xMin

    if (span <= 0)
        return -1
    endif

    NVAR RiseX1 = $(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX1")
    NVAR RiseX2 = $(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX2")
    NVAR FallX1 = $(LJZ_EDCEdgeWidth_BaseDF() + ":FallX1")
    NVAR FallX2 = $(LJZ_EDCEdgeWidth_BaseDF() + ":FallX2")

    // AutoFill 只负责给当前选中 wave 填窗口，不做测量、不写结果 wave。
    RiseX1 = xMin + 0.15 * span
    RiseX2 = xMin + 0.35 * span
    FallX1 = xMin + 0.65 * span
    FallX2 = xMin + 0.85 * span

    return 0
End

Function LJZ_EDCEdgeWidth_MeasureWaveByPath(wPath, doAlertOnFail)
    String wPath
    Variable doAlertOnFail

    Wave/Z w = $wPath
    if (!WaveExists(w) || !LJZ_EDCEdgeWidth_Is1DWave(w))
        LJZ_EDCEdgeWidth_WriteResultForWave(wPath, NaN, NaN, NaN)
        return -1
    endif

    NVAR RiseX1 = $(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX1")
    NVAR RiseX2 = $(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX2")
    NVAR FallX1 = $(LJZ_EDCEdgeWidth_BaseDF() + ":FallX1")
    NVAR FallX2 = $(LJZ_EDCEdgeWidth_BaseDF() + ":FallX2")
    NVAR XRise  = $(LJZ_EDCEdgeWidth_BaseDF() + ":XRise")
    NVAR XFall  = $(LJZ_EDCEdgeWidth_BaseDF() + ":XFall")
    NVAR Width  = $(LJZ_EDCEdgeWidth_BaseDF() + ":Width")

    Variable xRiseVal = LJZ_EDCEdgeWidth_EdgeCenter(w, RiseX1, RiseX2, 1)
    Variable xFallVal = LJZ_EDCEdgeWidth_EdgeCenter(w, FallX1, FallX2, 0)
    Variable widthVal = NaN

    if (numtype(xRiseVal) == 0 && numtype(xFallVal) == 0)
        widthVal = abs(xFallVal - xRiseVal)
        XRise = xRiseVal
        XFall = xFallVal
        Width = widthVal
        LJZ_EDCEdgeWidth_WriteResultForWave(wPath, xRiseVal, xFallVal, widthVal)
        return 0
    endif

    // 单条测量失败时，对应结果点统一写 NaN，而不是只停留在全局变量里。
    XRise = NaN
    XFall = NaN
    Width = NaN
    LJZ_EDCEdgeWidth_WriteResultForWave(wPath, NaN, NaN, NaN)

    if (doAlertOnFail)
        DoAlert 0, "在指定窗口内没有找到合法的 rising / falling center，请调整两个搜索范围。"
    endif

    return -1
End

Function LJZ_EDCEdgeWidth_FindWidth()
    LJZ_EDCEdgeWidth_EnsureDF()

    SVAR sWave = $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        DoAlert 0, "请先选择一个 edc_show_* 波形。"
        return -1
    endif

    Variable ret = LJZ_EDCEdgeWidth_MeasureWaveByPath(sWave, 1)
    LJZ_EDCEdgeWidth_ShowCurrentWave()
    LJZ_EDCEdgeWidth_RefreshTitleBoxes()
    return ret
End

Function LJZ_EDCEdgeWidth_MeasureAll()
    LJZ_EDCEdgeWidth_EnsureDF()

    String listStr = LJZ_EDCEdgeWidth_CurrentWaveList()
    Variable n = ItemsInList(listStr, ";")
    if (n <= 0)
        DoAlert 0, "当前 SourceDF 下没有 edc_show_* 波形可测量。"
        return -1
    endif

    LJZ_EDCEdgeWidth_EnsureResultWaves()
    SVAR sDF = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")
    String dfStr = LJZ_EDCEdgeWidth_df_with_colon(sDF)

    Wave/Z wRise = $(dfStr + "edc_xrise")
    Wave/Z wFall = $(dfStr + "edc_xfall")
    Wave/Z wWidth = $(dfStr + "edc_width")

    if (WaveExists(wRise))
        wRise = NaN
    endif
    if (WaveExists(wFall))
        wFall = NaN
    endif
    if (WaveExists(wWidth))
        wWidth = NaN
    endif
    // Measure All 按当前 SourceDF 扫描全部 edc_show_i；
    // 每条都通过 wave 名解析真实 i，并完整写回三个结果 wave。
    Variable i
    for (i = 0; i < n; i += 1)
        String wPath = StringFromList(i, listStr, ";")
        LJZ_EDCEdgeWidth_MeasureWaveByPath(wPath, 0)
    endfor

    LJZ_EDCEdgeWidth_LoadStoredResultForSelection()
    LJZ_EDCEdgeWidth_ShowCurrentWave()
    LJZ_EDCEdgeWidth_RefreshTitleBoxes()
    return 0
End

Function LJZ_EDCEdgeWidth_RefreshCurrentSelection()
    LJZ_EDCEdgeWidth_LoadStoredResultForSelection()
    LJZ_EDCEdgeWidth_ShowCurrentWave()
    return 0
End


// ============================================================================
//  Section 5. panel
// ============================================================================

Function LJZ_EDCEdgeWidth()
    LJZ_EDCEdgeWidth_EnsureDF()

    // 启动时优先尝试 current runDF
    SVAR sSourceDF = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")
    if (CmpStr(sSourceDF, "root:") == 0)
        String curRun = LJZ_EDCEdgeWidth_GetCurrentRunDF()
        if (strlen(curRun) > 0)
            sSourceDF = curRun
        endif
    endif

    LJZ_EDCEdgeWidth_RebuildWaveList()
    LJZ_EDCEdgeWidth_OpenPanel()
    LJZ_EDCEdgeWidth_RefreshCurrentSelection()
    LJZ_EDCEdgeWidth_RefreshTitleBoxes()

    return 0
End

Function LJZ_EDCEdgeWidth_OpenPanel()
    LJZ_EDCEdgeWidth_EnsureDF()

    String p = LJZ_EDCEdgeWidth_PanelName()
    DoWindow/F $p
    if (V_flag == 0)
        NewPanel/N=$p /W=(90,90,1040,620)
    else
        DoWindow/F $p
        LJZ_EDCEdgeWidth_CreateGraphSubwindow()
        return 0
    endif

    SetVariable svSourceDF,pos={10,10},size={455,20},title="Source DF"
    SetVariable svSourceDF,value=_STR:LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF",proc=LJZ_EDCEdgeWidth_SetVarProc

    Button btUseCurrent,pos={480,8},size={80,24},title="Current",proc=LJZ_EDCEdgeWidth_ButtonProc
    Button btScan,pos={575,8},size={70,24},title="Scan",proc=LJZ_EDCEdgeWidth_ButtonProc

    ListBox lbWave,pos={10,42},size={225,318},listWave=$(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Disp"),selWave=$(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Sel"),proc=LJZ_EDCEdgeWidth_ListBoxProc


    // ------------------------------------------------------------
    // Row 1 : action buttons
    // ------------------------------------------------------------
    Button btRefresh,pos={250,372},size={95,28},title="Refresh",proc=LJZ_EDCEdgeWidth_ButtonProc
    Button btAuto,pos={360,372},size={90,28},title="AutoFill",proc=LJZ_EDCEdgeWidth_ButtonProc
    Button btMeasure,pos={465,372},size={90,28},title="Measure",proc=LJZ_EDCEdgeWidth_ButtonProc
    Button btMeasureAll,pos={570,372},size={100,28},title="Measure All",proc=LJZ_EDCEdgeWidth_ButtonProc
    Button btMeasureNext,pos={685,372},size={120,28},title="Measure+Next",proc=LJZ_EDCEdgeWidth_ButtonProc
    Button btPlotResult,pos={820,372},size={110,28},title="Plot Result",proc=LJZ_EDCEdgeWidth_ButtonProc

    // ------------------------------------------------------------
    // Row 2 : edge windows
    // ------------------------------------------------------------
    TitleBox tbR1,pos={250,414},size={160,18},frame=0,title="Rising edge window"
    SetVariable svRiseX1,pos={250,438},size={145,20},title="Rise x1"
    SetVariable svRiseX1,variable=$(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX1"),proc=LJZ_EDCEdgeWidth_SetVarProc

    SetVariable svRiseX2,pos={410,438},size={145,20},title="Rise x2"
    SetVariable svRiseX2,variable=$(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX2"),proc=LJZ_EDCEdgeWidth_SetVarProc

    Button btAutoRise,pos={570,436},size={90,24},title="Auto Rise",proc=LJZ_EDCEdgeWidth_ButtonProc

    TitleBox tbF1,pos={690,414},size={170,18},frame=0,title="Falling edge window"
    SetVariable svFallX1,pos={690,438},size={145,20},title="Fall x1"
    SetVariable svFallX1,variable=$(LJZ_EDCEdgeWidth_BaseDF() + ":FallX1"),proc=LJZ_EDCEdgeWidth_SetVarProc

    SetVariable svFallX2,pos={850,438},size={145,20},title="Fall x2"
    SetVariable svFallX2,variable=$(LJZ_EDCEdgeWidth_BaseDF() + ":FallX2"),proc=LJZ_EDCEdgeWidth_SetVarProc

    Button btAutoFall,pos={850,468},size={90,24},title="Auto Fall",proc=LJZ_EDCEdgeWidth_ButtonProc

    // ------------------------------------------------------------
    // Row 3 : measurement result
    // ------------------------------------------------------------
    TitleBox tbRes1,pos={10,480},size={200,18},frame=0,title="Measurement Result"

    SetVariable svXRise,pos={10,506},size={180,20},title="XRise"
    SetVariable svXRise,variable=$(LJZ_EDCEdgeWidth_BaseDF() + ":XRise"),proc=LJZ_EDCEdgeWidth_SetVarProc,noedit=1

    SetVariable svXFall,pos={205,506},size={180,20},title="XFall"
    SetVariable svXFall,variable=$(LJZ_EDCEdgeWidth_BaseDF() + ":XFall"),proc=LJZ_EDCEdgeWidth_SetVarProc,noedit=1

    SetVariable svWidth,pos={400,506},size={180,20},title="Width"
    SetVariable svWidth,variable=$(LJZ_EDCEdgeWidth_BaseDF() + ":Width"),proc=LJZ_EDCEdgeWidth_SetVarProc,noedit=1

    // ------------------------------------------------------------
    // Bottom info
    // ------------------------------------------------------------
    SetVariable svSelWave,pos={10,542},size={985,20},title="Selected Wave:"
    SetVariable svSelWave,value=_STR:LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel",noedit=1

    SetVariable svSrcDF,pos={10,566},size={985,20},title="Source DF:"
    SetVariable svSrcDF,value=_STR:LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF",noedit=1

    TitleBox tbMsg,pos={10,592},size={985,18},frame=0,title="Definition: center = half-height crossing inside each window; fallback = max-slope midpoint"
    LJZ_EDCEdgeWidth_CreateGraphSubwindow()
    return 0
End

Function LJZ_EDCEdgeWidth_RefreshTitleBoxes()
    String p = LJZ_EDCEdgeWidth_PanelName()
    if (WinType(p) == 0)
        return 0
    endif

    SVAR sWave = $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel")
    SVAR sDF   = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")

    SetVariable svSourceDF win=$p, value=_STR:sDF
    SetVariable svSelWave  win=$p, value=_STR:sWave
    SetVariable svSrcDF    win=$p, value=_STR:sDF

    return 0
End


// ============================================================================
//  Section 6. callbacks
// ============================================================================

Function LJZ_EDCEdgeWidth_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    String ctrlName = ba.ctrlName

    if (CmpStr(ctrlName, "btUseCurrent") == 0)
        LJZ_EDCEdgeWidth_UseCurrentRunDF()
        return 0
    endif

    if (CmpStr(ctrlName, "btScan") == 0)
        LJZ_EDCEdgeWidth_RebuildWaveList()
        LJZ_EDCEdgeWidth_RefreshCurrentSelection()
        LJZ_EDCEdgeWidth_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(ctrlName, "btRefresh") == 0)
        LJZ_EDCEdgeWidth_RefreshCurrentSelection()
        return 0
    endif

    if (CmpStr(ctrlName, "btAuto") == 0)
        LJZ_EDCEdgeWidth_AutoFillWindows()
        LJZ_EDCEdgeWidth_UpdateGraphMarks()
        return 0
    endif
    
    if (CmpStr(ctrlName, "btAutoRise") == 0)
        LJZ_EDCEdgeWidth_AutoFillRiseWindow()
        LJZ_EDCEdgeWidth_UpdateGraphMarks()
        return 0
    endif

    if (CmpStr(ctrlName, "btAutoFall") == 0)
        LJZ_EDCEdgeWidth_AutoFillFallWindow()
        LJZ_EDCEdgeWidth_UpdateGraphMarks()
        return 0
    endif
    if (CmpStr(ctrlName, "btMeasure") == 0)
        LJZ_EDCEdgeWidth_FindWidth()
        return 0
    endif

    if (CmpStr(ctrlName, "btMeasureAll") == 0)
        LJZ_EDCEdgeWidth_MeasureAll()
        return 0
    endif

    if (CmpStr(ctrlName, "btMeasureNext") == 0)
        LJZ_EDCEdgeWidth_MeasureAndNext()
        return 0
    endif
    
    if (CmpStr(ctrlName, "btPlotResult") == 0)
        LJZ_EDCEdgeWidth_PlotResults()
        return 0
    endif
        
    return 0
End

Function LJZ_EDCEdgeWidth_SetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    if ((sva.eventCode != 1) && (sva.eventCode != 2))
        return 0
    endif

    String ctrlName = sva.ctrlName

    if (CmpStr(ctrlName, "svSourceDF") == 0)
        SVAR sDF = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")
        sDF = LJZ_EDCEdgeWidth_df_with_colon(sva.sval)
        return 0
    endif

    if ((CmpStr(ctrlName, "svRiseX1") == 0) || (CmpStr(ctrlName, "svRiseX2") == 0) || (CmpStr(ctrlName, "svFallX1") == 0) || (CmpStr(ctrlName, "svFallX2") == 0))
        LJZ_EDCEdgeWidth_UpdateGraphMarks()
        return 0
    endif

    return 0
End

Function LJZ_EDCEdgeWidth_ListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if ((lba.eventCode != 1) && (lba.eventCode != 4))
        return 0
    endif

    if (CmpStr(lba.ctrlName, "lbWave") == 0)
        if (lba.row >= 0)
            LJZ_EDCEdgeWidth_SelectWaveRow(lba.row)
            LJZ_EDCEdgeWidth_RefreshCurrentSelection()
            LJZ_EDCEdgeWidth_RefreshTitleBoxes()
        endif
    endif

    return 0
End

Function LJZ_EDCEdgeWidth_MeasureAndNext()
    LJZ_EDCEdgeWidth_EnsureDF()

    Variable ret = LJZ_EDCEdgeWidth_FindWidth()

    String listStr = LJZ_EDCEdgeWidth_CurrentWaveList()
    Variable n = ItemsInList(listStr, ";")
    NVAR SelRow = $(LJZ_EDCEdgeWidth_BaseDF() + ":SelRow")

    if (ret == 0 && n > 0)
        if (SelRow < n - 1)
            LJZ_EDCEdgeWidth_SelectWaveRow(SelRow + 1)
            LJZ_EDCEdgeWidth_RefreshCurrentSelection()
            LJZ_EDCEdgeWidth_RefreshTitleBoxes()
        endif
    endif

    return 0
End

Function LJZ_EDCEdgeWidth_AutoFillRiseWindow()
    LJZ_EDCEdgeWidth_EnsureDF()

    SVAR sWave = $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        return -1
    endif

    Wave/Z w = $sWave
    if (!WaveExists(w) || !LJZ_EDCEdgeWidth_Is1DWave(w))
        return -1
    endif

    Variable xA = pnt2x(w, 0)
    Variable xB = pnt2x(w, numpnts(w)-1)
    Variable xMin = min(xA, xB)
    Variable xMax = max(xA, xB)
    Variable span = xMax - xMin

    if (span <= 0)
        return -1
    endif

    NVAR RiseX1 = $(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX1")
    NVAR RiseX2 = $(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX2")

    RiseX1 = xMin + 0.15 * span
    RiseX2 = xMin + 0.35 * span

    return 0
End

Function LJZ_EDCEdgeWidth_AutoFillFallWindow()
    LJZ_EDCEdgeWidth_EnsureDF()

    SVAR sWave = $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        return -1
    endif

    Wave/Z w = $sWave
    if (!WaveExists(w) || !LJZ_EDCEdgeWidth_Is1DWave(w))
        return -1
    endif

    Variable xA = pnt2x(w, 0)
    Variable xB = pnt2x(w, numpnts(w)-1)
    Variable xMin = min(xA, xB)
    Variable xMax = max(xA, xB)
    Variable span = xMax - xMin

    if (span <= 0)
        return -1
    endif

    NVAR FallX1 = $(LJZ_EDCEdgeWidth_BaseDF() + ":FallX1")
    NVAR FallX2 = $(LJZ_EDCEdgeWidth_BaseDF() + ":FallX2")

    FallX1 = xMin + 0.65 * span
    FallX2 = xMin + 0.85 * span

    return 0
End

Function LJZ_EDCEdgeWidth_PlotResults()
    LJZ_EDCEdgeWidth_EnsureDF()

    SVAR sDF = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")
    String dfStr = LJZ_EDCEdgeWidth_df_with_colon(sDF)

    Wave/Z wRise  = $(dfStr + "edc_xrise")
    Wave/Z wFall  = $(dfStr + "edc_xfall")
    Wave/Z wWidth = $(dfStr + "edc_width")

    if (!WaveExists(wRise) || !WaveExists(wFall) || !WaveExists(wWidth))
        DoAlert 0, "结果 wave 不存在，请先 Measure 或 Measure All。"
        return -1
    endif

    String g = "EDCEdgeWidth_ResultGraph"
    DoWindow/K $g

    Display/N=$g wWidth
    AppendToGraph/R wRise
    AppendToGraph/R wFall

    ModifyGraph mode=3,marker=19
    ModifyGraph rgb(edc_width)=(0,0,0)
    ModifyGraph rgb(edc_xrise)=(0,0,65535)
    ModifyGraph rgb(edc_xfall)=(65535,0,0)

    Label left "Width"
    Label right "XRise / XFall"
    Label bottom "Index or t"

    return 0
End
