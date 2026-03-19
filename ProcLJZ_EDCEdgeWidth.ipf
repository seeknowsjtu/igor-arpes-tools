#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma DefaultTab={3,20,4}

// ============================================================================
//  LJZ_EDCEdgeWidth : post-panel for existing edc_show_* waves
//  只负责：
//    1) 从当前 EDCExtract RunDF 或手动指定 DF 扫描 edc_show_*
//    2) 选中一条 edc_show_k 显示
//    3) 在两个 x-window 内分别寻找 rising / falling center
//    4) 输出 width
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
    return "LJZ_EDCEdgeWidth_Graph"
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

        out = AddListItem(dfStr + nm, out, ";", Inf)
    endfor

    return out
End

Function/S LJZ_EDCEdgeWidth_CurrentWaveList()
    SVAR sDF = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")
    return LJZ_EDCEdgeWidth_ListEDCShowWaves_OneDF(LJZ_EDCEdgeWidth_df_with_colon(sDF))
End

Function LJZ_EDCEdgeWidth_RebuildWaveList()
    LJZ_EDCEdgeWidth_EnsureDF()

    SVAR sDF   = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")
    SVAR sWave = $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel")

    String dfStr = LJZ_EDCEdgeWidth_df_with_colon(sDF)
    if (!DataFolderExists(dfStr))
        Make/O/T/N=0 $(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Disp")
        Make/O/N=0   $(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Sel")
        sWave = ""
        return -1
    endif

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

    if (n > 0)
        wSel[0] = 1
        sWave = StringFromList(0, listStr, ";")
    else
        sWave = ""
    endif

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
    sWave = StringFromList(row, listStr, ";")

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

Function LJZ_EDCEdgeWidth_ShowCurrentWave()
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

    String g = LJZ_EDCEdgeWidth_GraphName()
    DoWindow/K $g

    Display/N=$g w
    Label/W=$g left "Intensity (a.u.)"
    Label/W=$g bottom "Energy"
    ModifyGraph/W=$g mirror=2

    DoWindow/T $g, NameOfWave(w)

    NVAR XRise = $(LJZ_EDCEdgeWidth_BaseDF() + ":XRise")
    NVAR XFall = $(LJZ_EDCEdgeWidth_BaseDF() + ":XFall")
    NVAR Width = $(LJZ_EDCEdgeWidth_BaseDF() + ":Width")

    XRise = NaN
    XFall = NaN
    Width = NaN

    LJZ_EDCEdgeWidth_RefreshTitleBoxes()
    return 0
End

Function LJZ_EDCEdgeWidth_UpdateGraphMarks()
    LJZ_EDCEdgeWidth_EnsureDF()

    String g = LJZ_EDCEdgeWidth_GraphName()
    if (WinType(g) == 0)
        return 0
    endif

    SVAR sWave = $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        return 0
    endif

    Wave/Z w = $sWave
    if (!WaveExists(w))
        return 0
    endif

    NVAR XRise = $(LJZ_EDCEdgeWidth_BaseDF() + ":XRise")
    NVAR XFall = $(LJZ_EDCEdgeWidth_BaseDF() + ":XFall")
    NVAR Width = $(LJZ_EDCEdgeWidth_BaseDF() + ":Width")

    if (numtype(XRise) == 0)
        Cursor/W=$g/P A, w, round(x2pnt(w, XRise))
    endif
    if (numtype(XFall) == 0)
        Cursor/W=$g/P B, w, round(x2pnt(w, XFall))
    endif

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

    if (strlen(tb) > 0)
        TextBox/W=$g/C/N=tbEdge/F=0/A=RT tb
    endif

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

    RiseX1 = xMin + 0.15 * span
    RiseX2 = xMin + 0.35 * span
    FallX1 = xMin + 0.65 * span
    FallX2 = xMin + 0.85 * span

    return 0
End

Function LJZ_EDCEdgeWidth_FindWidth()
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

    NVAR RiseX1 = $(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX1")
    NVAR RiseX2 = $(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX2")
    NVAR FallX1 = $(LJZ_EDCEdgeWidth_BaseDF() + ":FallX1")
    NVAR FallX2 = $(LJZ_EDCEdgeWidth_BaseDF() + ":FallX2")
    NVAR XRise  = $(LJZ_EDCEdgeWidth_BaseDF() + ":XRise")
    NVAR XFall  = $(LJZ_EDCEdgeWidth_BaseDF() + ":XFall")
    NVAR Width  = $(LJZ_EDCEdgeWidth_BaseDF() + ":Width")

    XRise = LJZ_EDCEdgeWidth_EdgeCenter(w, RiseX1, RiseX2, 1)
    XFall = LJZ_EDCEdgeWidth_EdgeCenter(w, FallX1, FallX2, 0)

    if (numtype(XRise) != 0 || numtype(XFall) != 0)
        Width = NaN
        LJZ_EDCEdgeWidth_UpdateGraphMarks()
        LJZ_EDCEdgeWidth_RefreshTitleBoxes()
        DoAlert 0, "在指定窗口内没有找到合法的 rising / falling center，请调整两个搜索范围。"
        return -1
    endif

    Width = abs(XFall - XRise)

    LJZ_EDCEdgeWidth_UpdateGraphMarks()
    LJZ_EDCEdgeWidth_RefreshTitleBoxes()

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
    LJZ_EDCEdgeWidth_RefreshTitleBoxes()

    return 0
End

Function LJZ_EDCEdgeWidth_OpenPanel()
    LJZ_EDCEdgeWidth_EnsureDF()

    String p = LJZ_EDCEdgeWidth_PanelName()
    DoWindow/F $p
    if (V_flag == 0)
        NewPanel/N=$p /W=(90,90,760,560)
    else
        DoWindow/F $p
        return 0
    endif

    SetVariable svSourceDF,pos={10,10},size={455,20},title="Source DF"
    SetVariable svSourceDF,value=_STR:LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF",proc=LJZ_EDCEdgeWidth_SetVarProc

    Button btUseCurrent,pos={480,8},size={80,24},title="Current",proc=LJZ_EDCEdgeWidth_ButtonProc
    Button btScan,pos={575,8},size={70,24},title="Scan",proc=LJZ_EDCEdgeWidth_ButtonProc

    ListBox lbWave,pos={10,42},size={330,220},listWave=$(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Disp"),selWave=$(LJZ_EDCEdgeWidth_BaseDF() + ":LB_Sel"),proc=LJZ_EDCEdgeWidth_ListBoxProc

    Button btShow,pos={365,42},size={120,28},title="Show EDC",proc=LJZ_EDCEdgeWidth_ButtonProc
    Button btFocus,pos={500,42},size={120,28},title="Focus Graph",proc=LJZ_EDCEdgeWidth_ButtonProc

    TitleBox tbR1,pos={365,92},size={180,18},frame=0,title="Rising edge window"
    SetVariable svRiseX1,pos={365,116},size={130,20},title="Rise x1"
    SetVariable svRiseX1,variable=$(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX1"),proc=LJZ_EDCEdgeWidth_SetVarProc

    SetVariable svRiseX2,pos={510,116},size={130,20},title="Rise x2"
    SetVariable svRiseX2,variable=$(LJZ_EDCEdgeWidth_BaseDF() + ":RiseX2"),proc=LJZ_EDCEdgeWidth_SetVarProc

    TitleBox tbF1,pos={365,160},size={180,18},frame=0,title="Falling edge window"
    SetVariable svFallX1,pos={365,184},size={130,20},title="Fall x1"
    SetVariable svFallX1,variable=$(LJZ_EDCEdgeWidth_BaseDF() + ":FallX1"),proc=LJZ_EDCEdgeWidth_SetVarProc

    SetVariable svFallX2,pos={510,184},size={130,20},title="Fall x2"
    SetVariable svFallX2,variable=$(LJZ_EDCEdgeWidth_BaseDF() + ":FallX2"),proc=LJZ_EDCEdgeWidth_SetVarProc

    Button btAuto,pos={365,228},size={90,28},title="AutoFill",proc=LJZ_EDCEdgeWidth_ButtonProc
    Button btMeasure,pos={470,228},size={90,28},title="Measure",proc=LJZ_EDCEdgeWidth_ButtonProc

    TitleBox tbRes1,pos={10,282},size={280,18},frame=0,title="Measurement Result"

    SetVariable svXRise,pos={10,308},size={180,20},title="XRise"
    SetVariable svXRise,variable=$(LJZ_EDCEdgeWidth_BaseDF() + ":XRise"),proc=LJZ_EDCEdgeWidth_SetVarProc,noedit=1

    SetVariable svXFall,pos={205,308},size={180,20},title="XFall"
    SetVariable svXFall,variable=$(LJZ_EDCEdgeWidth_BaseDF() + ":XFall"),proc=LJZ_EDCEdgeWidth_SetVarProc,noedit=1

    SetVariable svWidth,pos={400,308},size={180,20},title="Width"
    SetVariable svWidth,variable=$(LJZ_EDCEdgeWidth_BaseDF() + ":Width"),proc=LJZ_EDCEdgeWidth_SetVarProc,noedit=1

    TitleBox tbSel,pos={10,350},size={635,20},frame=0,title="Selected Wave: "
    TitleBox tbSrc,pos={10,378},size={635,20},frame=0,title="Source DF: "
    TitleBox tbMsg,pos={10,410},size={635,40},frame=0,title="Definition: center = half-height crossing inside each window"

    LJZ_EDCEdgeWidth_RefreshTitleBoxes()
    return 0
End

Function LJZ_EDCEdgeWidth_RefreshTitleBoxes()
    SVAR sWave = $(LJZ_EDCEdgeWidth_BaseDF() + ":WaveSel")
    SVAR sDF   = $(LJZ_EDCEdgeWidth_BaseDF() + ":SourceDF")

    String p = LJZ_EDCEdgeWidth_PanelName()
    if (WinType(p) == 0)
        return 0
    endif

    TitleBox tbSel win=$p, title="Selected Wave: " + LJZ_EDCEdgeWidth_ShortenForTitle(sWave, 90)
    TitleBox tbSrc win=$p, title="Source DF: " + LJZ_EDCEdgeWidth_ShortenForTitle(sDF, 90)

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
        LJZ_EDCEdgeWidth_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(ctrlName, "btShow") == 0)
        LJZ_EDCEdgeWidth_ShowCurrentWave()
        return 0
    endif

    if (CmpStr(ctrlName, "btFocus") == 0)
        DoWindow/F $(LJZ_EDCEdgeWidth_GraphName())
        return 0
    endif

    if (CmpStr(ctrlName, "btAuto") == 0)
        LJZ_EDCEdgeWidth_AutoFillWindows()
        return 0
    endif

    if (CmpStr(ctrlName, "btMeasure") == 0)
        LJZ_EDCEdgeWidth_FindWidth()
        return 0
    endif

    return 0
End

Function LJZ_EDCEdgeWidth_SetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    if ((sva.eventCode != 1) && (sva.eventCode != 2) && (sva.eventCode != 3))
        return 0
    endif

    String ctrlName = sva.ctrlName

    if (CmpStr(ctrlName, "svSourceDF") == 0)
        LJZ_EDCEdgeWidth_RebuildWaveList()
        LJZ_EDCEdgeWidth_RefreshTitleBoxes()
        return 0
    endif

    if ((CmpStr(ctrlName, "svRiseX1") == 0) || (CmpStr(ctrlName, "svRiseX2") == 0) || (CmpStr(ctrlName, "svFallX1") == 0) || (CmpStr(ctrlName, "svFallX2") == 0))
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
            LJZ_EDCEdgeWidth_RefreshTitleBoxes()
        endif
    endif

    return 0
End
