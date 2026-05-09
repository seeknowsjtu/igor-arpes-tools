#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma DefaultTab={3,20,4}

// ============================================================================
//  ProcLJZ_MDCEDCExtract
//
//  两个独立但对称的提取工具，共享公共工具函数：
//
//  LJZ_MDCExtract  ── MDC 提取（沿 Energy 轴平均 → mdc_raw_i / mdc_show_i）
//    输入约定：3D wave，轴顺序 energy × kparallel × stack(t/delay/hv)
//    提取：在 [eStart, eEnd] 能量窗内对 dim0 平均，每个 stack 层输出一条 MDC
//
//  LJZ_EDCExtract  ── EDC 提取（沿 kparallel 轴平均 → edc_raw_i / edc_show_i）
//    输入约定：3D wave，轴顺序 energy × kparallel × stack(t/delay/hv)
//    提取：在 [kStart, kEnd] 动量窗内对 dim1 平均，每个 stack 层输出一条 EDC
//
//  两者都负责：
//    1) 扫描指定 SourceDF 下的 3D 数值 wave（可选递归）
//    2) 在两个 x-window 内提取并平均，输出 <prefix>_raw_i 和 <prefix>_show_i
//    3) 可选平滑（Smooth / Savitzky-Golay，单次或双次）
//    4) 叠加显示输出曲线（可选垂直偏置）
//    5) 将 RunDF 路径写入公共兼容位置供下游工具（EDCWB / MDCWB）读取
//    6) 在 RunDF 下写入提取元数据（kStart/kEnd 或 eStart/eEnd，t0/dt/nT）
//
//  不负责：
//    - 拟合
//    - EDCWB / MDCWB 模型 / export
//    - 3D 提取（如 kxky / kxkz 变换）
//    - delay scan 折叠或 volume collapse
//
//  命名约定（Contract）：
//    - 原始提取结果：<prefix>_raw_i  （不得由平滑步骤修改）
//    - 显示/使用结果：<prefix>_show_i （由平滑步骤从 raw 生成，可反复重建）
//    - RunDF 下必须有以上两组 wave，索引从 0 连续，无空缺
//    - RunMeta 变量写在 BaseDF 全局 + 写一份到 RunDF 本地，方便下游独立读取
//
//  RunDF 路径格式：
//    MDCExtract: root:ARPES_LJZ:MDCExtract_RUNS:<wavename>_MDC_e<e0>_<e1>:
//    EDCExtract: root:ARPES_LJZ:EDCExtract_RUNS:<wavename>_EDC_k<k0>_<k1>:
// ============================================================================

Menu "ARPES_LJZ"
    "2026MDCExtract_LJZ", LJZ_MDCExtract()
    "2026EDCExtract_LJZ", LJZ_EDCExtract()
End


// ============================================================================
//  Section 0. Shared utilities
//  （所有以 LJZ_Extract_ 开头的函数均为两个模块共用）
// ============================================================================

// ---- DF path normalization ----

Function/S LJZ_Extract_df_with_colon(inStr)
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

Function LJZ_Extract_df_exists(dfStr)
    String dfStr
    String s = LJZ_Extract_df_with_colon(dfStr)
    return DataFolderExists(s)
End

Function LJZ_Extract_EnsureDataFolderPath(dfPath)
    String dfPath

    String p = LJZ_Extract_df_with_colon(dfPath)
    String cur = "root:"
    Variable i, n = ItemsInList(p, ":")
    for (i = 1; i < n; i += 1)
        String seg = StringFromList(i, p, ":")
        if (strlen(seg) == 0)
            continue
        endif
        cur += seg + ":"
        NewDataFolder/O $(RemoveEnding(cur, ":"))
    endfor
    return 0
End

// ---- Wave type checks ----

Function LJZ_Extract_Is3DNumericWave(w)
    Wave/Z w

    if (!WaveExists(w))
        return 0
    endif
    // WaveType(w,1)==1 → numeric; ==2 → text; others → wave ref / null
    if (WaveType(w, 1) != 1)
        return 0
    endif
    if (DimSize(w, 0) <= 0 || DimSize(w, 1) <= 0 || DimSize(w, 2) <= 0)
        return 0
    endif
    if (DimSize(w, 3) > 0)
        return 0
    endif
    return 1
End

// ---- Title truncation ----

Function/S LJZ_Extract_ShortenForTitle(s, maxLen)
    String s
    Variable maxLen

    if (strlen(s) <= maxLen)
        return s
    endif
    return s[0, maxLen - 4] + "..."
End

// ---- Wave list scan ----

// 在单个 dfStr（必须以 : 结尾）下列出所有合法 3D numeric wave，返回 ; 分隔全路径列表。
Function/S LJZ_Extract_List3DWaves_OneDF(dfStr)
    String dfStr

    String out = ""
    Variable iObj, nObj
    nObj = CountObjects(dfStr, 1)
    for (iObj = 0; iObj < nObj; iObj += 1)
        String nm = GetIndexedObjName(dfStr, 1, iObj)
        Wave/Z w = $(dfStr + nm)
        if (!LJZ_Extract_Is3DNumericWave(w))
            continue
        endif
        out = AddListItem(dfStr + nm, out, ";", Inf)
    endfor
    return out
End

// 递归或非递归扫描，返回 ; 分隔全路径列表。
Function/S LJZ_Extract_List3DWaves(dfStr, recursive)
    String dfStr
    Variable recursive

    dfStr = LJZ_Extract_df_with_colon(dfStr)
    if (!DataFolderExists(dfStr))
        return ""
    endif

    String out = LJZ_Extract_List3DWaves_OneDF(dfStr)

    if (!recursive)
        return out
    endif

    Variable iObj, nObj
    nObj = CountObjects(dfStr, 4)
    for (iObj = 0; iObj < nObj; iObj += 1)
        String subDF = GetIndexedObjName(dfStr, 4, iObj)
        if (strlen(subDF) == 0)
            continue
        endif
        out += LJZ_Extract_List3DWaves(dfStr + subDF + ":", 1)
    endfor
    return out
End

// ---- Smoothing kernel ----
// method: 0=none, 1=Smooth(binomial), 2=Smooth/S(Savitzky-Golay)
// n1/n2: first and second smoothing pass point count (n2=0 skips second pass)
// poly:  polynomial order for Savitzky-Golay

Function LJZ_Extract_ApplySmoothToWave(sh, method, n1, n2, poly)
    Wave sh
    Variable method, n1, n2, poly

    if (method == 0)
        return 0
    endif

    n1 = max(3, round(n1))
    if (n2 < 3)
        n2 = 0
    else
        n2 = round(n2)
    endif
    poly = max(2, round(poly))

    if (method == 1)
        Smooth n1, sh
        if (n2 >= 3)
            Smooth n2, sh
        endif
    elseif (method == 2)
        Smooth/S=(poly) n1, sh
        if (n2 >= 3)
            Smooth/S=(poly) n2, sh
        endif
    endif

    return 0
End

// ---- Overlay graph builder ----
// prefix: "mdc_show" or "edc_show"
// runDF: full path ending with :
// graphName: window name to (re)create
// axisLabel: x-axis label string
// evary: vertical offset between successive traces (0 = no offset)

Function LJZ_Extract_BuildOverlayGraph(runDF, prefix, graphName, graphTitle, axisLabel, evary)
    String runDF, prefix, graphName, graphTitle, axisLabel
    Variable evary

    DoWindow/K $graphName

    String oldDF = GetDataFolder(1)
    SetDataFolder $(RemoveEnding(runDF, ":"))

    Variable t = 0
    do
        Wave/Z sh = $(prefix + "_" + num2str(t))
        if (!WaveExists(sh))
            break
        endif

        if (t == 0)
            Display/N=$graphName sh
            Label/W=$graphName left "Intensity (a.u.)"
            Label/W=$graphName bottom axisLabel
        else
            AppendToGraph/W=$graphName sh
            if (evary != 0)
                ModifyGraph/W=$graphName offset($NameOfWave(sh))={0, t * evary}
            endif
        endif
        t += 1
    while (1)

    SetDataFolder $oldDF

    if (t > 0)
        ModifyGraph/W=$graphName mirror=2
        DoWindow/T $graphName, graphTitle
    endif

    return 0
End

// ---- Push RunDF path to downstream workbench global ----
// targetGlobalPath: full Igor path to the String/G variable to set, e.g.
//   "root:Packages:ARPES_LJZ:EDCWB:TargetDF"

Function LJZ_Extract_PushRunDFToWorkbench(runDF, targetGlobalPath)
    String runDF, targetGlobalPath

    Variable p = strsearch(targetGlobalPath, ":", Inf)
    String dfPart = ""
    if (p > 0)
        dfPart = targetGlobalPath[0, p - 1]
    endif
    if (strlen(dfPart) > 0)
        LJZ_Extract_EnsureDataFolderPath(dfPart)
    endif
    String/G $targetGlobalPath = runDF
    return 0
End

Function/S LJZ_Extract_BuildDimInfoString(w)
    Wave/Z w
    String s
    if (!WaveExists(w))
        return "Source wave not found."
    endif
    sprintf s, "Dim0(E): n=%d off=%.6g d=%.6g u=%s | Dim1(k): n=%d off=%.6g d=%.6g u=%s | Dim2(stack): n=%d off=%.6g d=%.6g u=%s", \
        DimSize(w,0), DimOffset(w,0), DimDelta(w,0), WaveUnits(w,0), \
        DimSize(w,1), DimOffset(w,1), DimDelta(w,1), WaveUnits(w,1), \
        DimSize(w,2), DimOffset(w,2), DimDelta(w,2), WaveUnits(w,2)
    return s
End

Function LJZ_Extract_PrintDimSanity(w, label)
    Wave/Z w
    String label
    String s = LJZ_Extract_BuildDimInfoString(w)
    Print label + " | " + s
    if (!LJZ_Extract_Is3DNumericWave(w))
        Print "WARNING: selected source wave is not a strict 3D numeric wave (dim0=E, dim1=k, dim2=stack expected)."
    endif
    return 0
End

Function LJZ_Extract_WindowPhysToIndex(off, delta, n, v0In, v1In, idxLo, idxHi)
    Variable off, delta, n, v0In, v1In, &idxLo, &idxHi
    Variable lo = v0In, hi = v1In, t
    if (n <= 0 || numtype(delta) != 0 || delta == 0)
        idxLo = 0; idxHi = -1
        return -1
    endif
    if (lo > hi)
        t = lo; lo = hi; hi = t
    endif
    if (delta > 0)
        idxLo = ceil((lo - off) / delta)
        idxHi = floor((hi - off) / delta)
    else
        idxLo = ceil((hi - off) / delta)
        idxHi = floor((lo - off) / delta)
    endif
    t = idxLo
    idxLo = max(0, min(n - 1, idxLo))
    idxHi = max(0, min(n - 1, idxHi))
    if (idxLo > idxHi)
        return -1
    endif
    return 0
End

Function LJZ_Extract_KillWavesByPatternInRunDF(runDF, patt)
    String runDF, patt

    DFREF oldDF = GetDataFolderDFR()

    if (DataFolderExists(runDF) == 0)
        return 0
    endif

    SetDataFolder $runDF

    String list = WaveList(patt, ";", "DIMS:1")
    Variable i, n = ItemsInList(list, ";")

    for (i = 0; i < n; i += 1)
        String nm = StringFromList(i, list, ";")
        if (strlen(nm) > 0)
            KillWaves/Z $nm
        endif
    endfor

    SetDataFolder oldDF
    return 0
End


// ============================================================================
//  Section 1. MDC Extract – state / paths
// ============================================================================

Function/S LJZ_MDCExtract_BaseDF()
    return "root:ARPES_LJZ:MDCExtract"
End

Function/S LJZ_MDCExtract_RunRoot()
    return "root:ARPES_LJZ:MDCExtract_RUNS"
End

Function/S LJZ_MDCExtract_PanelName()
    return "LJZ_MDCExtract_Panel"
End

Function/S LJZ_MDCExtract_GraphName()
    return "LJZ_MDCExtract_Graph"
End

Function LJZ_MDCExtract_EnsureDF()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O $(LJZ_MDCExtract_BaseDF())
    NewDataFolder/O $(LJZ_MDCExtract_RunRoot())

    // ---- source DF ----
    SVAR/Z sBase = $(LJZ_MDCExtract_BaseDF() + ":SourceDF")
    if (!SVAR_Exists(sBase))
        String/G $(LJZ_MDCExtract_BaseDF() + ":SourceDF") = "root:"
    endif

    NVAR/Z rec = $(LJZ_MDCExtract_BaseDF() + ":Recursive")
    if (!NVAR_Exists(rec))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":Recursive") = 0
    endif

    // ---- current selected wave ----
    SVAR/Z sWave = $(LJZ_MDCExtract_BaseDF() + ":WaveSel")
    if (!SVAR_Exists(sWave))
        String/G $(LJZ_MDCExtract_BaseDF() + ":WaveSel") = ""
    endif

    NVAR/Z selRow = $(LJZ_MDCExtract_BaseDF() + ":SelRow")
    if (!NVAR_Exists(selRow))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":SelRow") = -1
    endif

    // ---- extraction parameters ----
    // Energy window: [EIndex, Exe] are pixel/index values for the energy range.
    // Physical-value mode uses dim0 scaling to convert; index mode is the default.
    NVAR/Z e0 = $(LJZ_MDCExtract_BaseDF() + ":EIndex")
    if (!NVAR_Exists(e0))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":EIndex") = 0
    endif

    NVAR/Z e1 = $(LJZ_MDCExtract_BaseDF() + ":Exe")
    if (!NVAR_Exists(e1))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":Exe") = 0
    endif

    NVAR/Z usePhysE = $(LJZ_MDCExtract_BaseDF() + ":UsePhysE")
    if (!NVAR_Exists(usePhysE))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":UsePhysE") = 0    // 0=index, 1=physical value
    endif
    NVAR/Z UseFermiWeightedMDC = $(LJZ_MDCExtract_BaseDF() + ":UseFermiWeightedMDC")
    if (!NVAR_Exists(UseFermiWeightedMDC))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":UseFermiWeightedMDC") = 0
    endif
    NVAR/Z FermiE = $(LJZ_MDCExtract_BaseDF() + ":FermiE")
    if (!NVAR_Exists(FermiE))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":FermiE") = 1.7545
    endif
    NVAR/Z FermiHalfWidth = $(LJZ_MDCExtract_BaseDF() + ":FermiHalfWidth")
    if (!NVAR_Exists(FermiHalfWidth))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":FermiHalfWidth") = 0.01
    endif
    NVAR/Z FermiSigma = $(LJZ_MDCExtract_BaseDF() + ":FermiSigma")
    if (!NVAR_Exists(FermiSigma))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":FermiSigma") = 0.004
    endif
    NVAR/Z FermiWeightMethod = $(LJZ_MDCExtract_BaseDF() + ":FermiWeightMethod")
    if (!NVAR_Exists(FermiWeightMethod))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":FermiWeightMethod") = 1
    endif

    NVAR/Z evary = $(LJZ_MDCExtract_BaseDF() + ":evary")
    if (!NVAR_Exists(evary))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":evary") = 0
    endif

    SVAR/Z bn = $(LJZ_MDCExtract_BaseDF() + ":BaseName")
    if (!SVAR_Exists(bn))
        String/G $(LJZ_MDCExtract_BaseDF() + ":BaseName") = "MDC"
    endif

    // ---- run metadata ----
    SVAR/Z runDF = $(LJZ_MDCExtract_BaseDF() + ":RunDF")
    if (!SVAR_Exists(runDF))
        String/G $(LJZ_MDCExtract_BaseDF() + ":RunDF") = ""
    endif

    NVAR/Z Run_eStart = $(LJZ_MDCExtract_BaseDF() + ":Run_eStart")
    if (!NVAR_Exists(Run_eStart))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":Run_eStart") = NaN
    endif

    NVAR/Z Run_eEnd = $(LJZ_MDCExtract_BaseDF() + ":Run_eEnd")
    if (!NVAR_Exists(Run_eEnd))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":Run_eEnd") = NaN
    endif

    NVAR/Z Run_t0 = $(LJZ_MDCExtract_BaseDF() + ":Run_t0")
    if (!NVAR_Exists(Run_t0))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":Run_t0") = NaN
    endif

    NVAR/Z Run_dt = $(LJZ_MDCExtract_BaseDF() + ":Run_dt")
    if (!NVAR_Exists(Run_dt))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":Run_dt") = NaN
    endif

    NVAR/Z Run_nT = $(LJZ_MDCExtract_BaseDF() + ":Run_nT")
    if (!NVAR_Exists(Run_nT))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":Run_nT") = NaN
    endif

    // ---- smoothing parameters ----
    NVAR/Z SmEnable = $(LJZ_MDCExtract_BaseDF() + ":SmEnable")
    if (!NVAR_Exists(SmEnable))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":SmEnable") = 0
    endif

    NVAR/Z SmMethod = $(LJZ_MDCExtract_BaseDF() + ":SmMethod")
    if (!NVAR_Exists(SmMethod))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":SmMethod") = 1
    endif

    NVAR/Z SmN = $(LJZ_MDCExtract_BaseDF() + ":SmN")
    if (!NVAR_Exists(SmN))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":SmN") = 11
    endif

    NVAR/Z SmN2 = $(LJZ_MDCExtract_BaseDF() + ":SmN2")
    if (!NVAR_Exists(SmN2))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":SmN2") = 7
    endif

    NVAR/Z SmPoly = $(LJZ_MDCExtract_BaseDF() + ":SmPoly")
    if (!NVAR_Exists(SmPoly))
        Variable/G $(LJZ_MDCExtract_BaseDF() + ":SmPoly") = 4
    endif

    // ---- listbox waves ----
    Wave/T/Z wDisp = $(LJZ_MDCExtract_BaseDF() + ":LB_Disp")
    if (!WaveExists(wDisp))
        Make/O/T/N=0 $(LJZ_MDCExtract_BaseDF() + ":LB_Disp")
    endif

    Wave/Z wSel = $(LJZ_MDCExtract_BaseDF() + ":LB_Sel")
    if (!WaveExists(wSel))
        Make/O/N=0 $(LJZ_MDCExtract_BaseDF() + ":LB_Sel") = 0
    endif

    Wave/T/Z wPath = $(LJZ_MDCExtract_BaseDF() + ":LB_Path")
    if (!WaveExists(wPath))
        Make/O/T/N=0 $(LJZ_MDCExtract_BaseDF() + ":LB_Path")
    endif

    return 0
End

Function LJZ_MDCExtract_EnergyWeight(ePhys, eCenter, halfWidth, sigma, method)
    Variable ePhys, eCenter, halfWidth, sigma, method

    halfWidth = abs(halfWidth)
    if (halfWidth <= 0 || numtype(halfWidth) != 0)
        return 0
    endif
    if (abs(ePhys - eCenter) > halfWidth)
        return 0
    endif

    Variable w = 1
    if (method == 0)
        w = 1
    elseif (method == 1)
        if (sigma <= 0 || numtype(sigma) != 0)
            sigma = halfWidth / 2
        endif
        w = exp(-0.5 * ((ePhys - eCenter) / sigma)^2)
    elseif (method == 2)
        w = max(0, 1 - abs(ePhys - eCenter) / halfWidth)
    else
        w = 1
    endif
    return w
End


// ============================================================================
//  Section 2. MDC Extract – wave list
// ============================================================================

Function LJZ_MDCExtract_RebuildWaveList()
    LJZ_MDCExtract_EnsureDF()

    SVAR sBase = $(LJZ_MDCExtract_BaseDF() + ":SourceDF")
    NVAR rec   = $(LJZ_MDCExtract_BaseDF() + ":Recursive")
    SVAR sWave = $(LJZ_MDCExtract_BaseDF() + ":WaveSel")
    NVAR selRow = $(LJZ_MDCExtract_BaseDF() + ":SelRow")

    String prevWave = sWave
    String dfStr = LJZ_Extract_df_with_colon(sBase)

    if (!DataFolderExists(dfStr))
        Make/O/T/N=0 $(LJZ_MDCExtract_BaseDF() + ":LB_Disp")
        Make/O/T/N=0 $(LJZ_MDCExtract_BaseDF() + ":LB_Path")
        Make/O/N=0   $(LJZ_MDCExtract_BaseDF() + ":LB_Sel")
        sWave = ""
        selRow = -1
        return -1
    endif

    String listStr = LJZ_Extract_List3DWaves(dfStr, rec)
    Variable n = ItemsInList(listStr, ";")

    Make/O/T/N=(n) $(LJZ_MDCExtract_BaseDF() + ":LB_Disp")
    Make/O/T/N=(n) $(LJZ_MDCExtract_BaseDF() + ":LB_Path")
    Make/O/N=(n)   $(LJZ_MDCExtract_BaseDF() + ":LB_Sel") = 0

    Wave/T wDisp = $(LJZ_MDCExtract_BaseDF() + ":LB_Disp")
    Wave/T wPath = $(LJZ_MDCExtract_BaseDF() + ":LB_Path")
    Wave   wSel  = $(LJZ_MDCExtract_BaseDF() + ":LB_Sel")

    Variable i
    for (i = 0; i < n; i += 1)
        String wFull = StringFromList(i, listStr, ";")
        wPath[i] = wFull
        wDisp[i] = NameOfWave($wFull)
    endfor

    // Try to restore previous selection
    Variable keepRow = WhichListItem(prevWave, listStr, ";", 0, 0)
    if (keepRow < 0 && n > 0)
        keepRow = 0
    endif

    if (n > 0 && keepRow >= 0)
        keepRow = max(0, min(n - 1, keepRow))
        wSel[keepRow] = 1
        sWave = wPath[keepRow]
        selRow = keepRow
    else
        sWave = ""
        selRow = -1
    endif

    return 0
End

Function LJZ_MDCExtract_BuildRawMDCsWeightedFermi(w, eCenterPhys, halfWidthPhys, sigmaPhys, weightMethod, runDF)
    Wave w
    Variable eCenterPhys, halfWidthPhys, sigmaPhys, weightMethod
    String runDF

    Variable nE = DimSize(w, 0), nK = DimSize(w, 1), nT = DimSize(w, 2)
    if (nE <= 0 || nK <= 0 || nT <= 0)
        return -1
    endif

    Variable halfWidth = abs(halfWidthPhys)
    Variable eLowPhys = eCenterPhys - halfWidth
    Variable eHighPhys = eCenterPhys + halfWidth
    Variable eStart, eEnd
    if (LJZ_Extract_WindowPhysToIndex(DimOffset(w,0), DimDelta(w,0), nE, eLowPhys, eHighPhys, eStart, eEnd) != 0)
        Print "WARNING: weighted-Fermi MDC window is empty after physical→index conversion. Extraction skipped."
        return -1
    endif

    Variable k0 = DimOffset(w, 1), dk = DimDelta(w, 1)
    NewDataFolder/O $(RemoveEnding(runDF, ":"))
    String oldDF = GetDataFolder(1)
    Variable hadError = 0
    try
        SetDataFolder $(RemoveEnding(runDF, ":"))
        LJZ_Extract_KillWavesByPatternInRunDF(runDF, "mdc_raw_*")
        LJZ_Extract_KillWavesByPatternInRunDF(runDF, "mdc_show_*")
        LJZ_Extract_KillWavesByPatternInRunDF(runDF, "edc_raw_*")
        LJZ_Extract_KillWavesByPatternInRunDF(runDF, "edc_show_*")

        Variable t, k, e, wt, v, wsum, acc, ePhys
        for (t = 0; t < nT; t += 1)
            Make/O/N=(nK) $("mdc_raw_" + num2str(t)) = NaN
            Wave mdc = $("mdc_raw_" + num2str(t))
            SetScale/P x, k0, dk, WaveUnits(w, 1), mdc
            for (k = 0; k < nK; k += 1)
                acc = 0; wsum = 0
                for (e = eStart; e <= eEnd; e += 1)
                    ePhys = DimOffset(w,0) + e * DimDelta(w,0)
                    wt = LJZ_MDCExtract_EnergyWeight(ePhys, eCenterPhys, halfWidth, sigmaPhys, weightMethod)
                    v = w[e][k][t]
                    if (numtype(v) == 0 && numtype(wt) == 0 && wt > 0)
                        acc += wt * v
                        wsum += wt
                    endif
                endfor
                if (wsum > 0)
                    mdc[k] = acc / wsum
                else
                    mdc[k] = NaN
                endif
            endfor
        endfor
    catch
        hadError = 1
    endtry
    SetDataFolder $oldDF
    if (hadError || GetRTError(1) != 0)
        return -1
    endif
    return 0
End

Function LJZ_MDCExtract_SelectWaveRow(row)
    Variable row

    LJZ_MDCExtract_EnsureDF()

    Wave/T wPath = $(LJZ_MDCExtract_BaseDF() + ":LB_Path")
    Wave   wSel  = $(LJZ_MDCExtract_BaseDF() + ":LB_Sel")
    SVAR sWave   = $(LJZ_MDCExtract_BaseDF() + ":WaveSel")
    NVAR selRow  = $(LJZ_MDCExtract_BaseDF() + ":SelRow")

    Variable n = numpnts(wPath)
    if (n <= 0 || row < 0 || row >= n)
        return -1
    endif

    wSel = 0
    wSel[row] = 1
    sWave  = wPath[row]
    selRow = row

    return 0
End

Function LJZ_MDCExtract_RestoreSelectionUI()
    String p = LJZ_MDCExtract_PanelName()
    if (WinType(p) == 0)
        return 0
    endif

    NVAR selRow = $(LJZ_MDCExtract_BaseDF() + ":SelRow")
    ListBox/Z lbWave, win=$p, selRow=selRow
    ControlUpdate/W=$p lbWave
    return 0
End


// ============================================================================
//  Section 3. MDC Extract – kernel
// ============================================================================

// Convert physical energy value to pixel index using wave scaling.
// Returns clamped integer index.
Function LJZ_MDCExtract_PhysEToIndex(w, physE)
    Wave w
    Variable physE

    Variable de = DimDelta(w, 0)
    if (numtype(de) != 0 || de == 0)
        return 0
    endif
    Variable idx = round((physE - DimOffset(w, 0)) / de)
    idx = max(0, min(DimSize(w, 0) - 1, idx))
    return idx
End

// Build raw MDC waves in runDF from source 3D wave.
// Averages dim0 (energy) from eStart to eEnd (pixel indices) for each stack layer.
// Output: <runDF>mdc_raw_0 ... mdc_raw_(nT-1)
// Returns 0 on success, -1 on invalid input.
Function LJZ_MDCExtract_BuildRawMDCs(w, eStart, eEnd, runDF)
    Wave w
    Variable eStart, eEnd
    String runDF

    Variable nE = DimSize(w, 0)
    Variable nK = DimSize(w, 1)
    Variable nT = DimSize(w, 2)

    if (nE <= 0 || nK <= 0 || nT <= 0)
        return -1
    endif

    eStart = max(0, min(nE - 1, round(eStart)))
    eEnd   = max(0, min(nE - 1, round(eEnd)))
    if (eStart > eEnd)
        Variable tmp = eStart
        eStart = eEnd
        eEnd = tmp
    endif

    Variable nAvg = eEnd - eStart + 1
    if (nAvg <= 0)
        return -1
    endif

    Variable k0 = DimOffset(w, 1)
    Variable dk = DimDelta(w, 1)

    NewDataFolder/O $(RemoveEnding(runDF, ":"))
    String oldDF = GetDataFolder(1)

    Variable hadError = 0
    try
        SetDataFolder $(RemoveEnding(runDF, ":"))

        LJZ_Extract_KillWavesByPatternInRunDF(runDF, "mdc_raw_*")
        LJZ_Extract_KillWavesByPatternInRunDF(runDF, "mdc_show_*")
        LJZ_Extract_KillWavesByPatternInRunDF(runDF, "edc_raw_*")
        LJZ_Extract_KillWavesByPatternInRunDF(runDF, "edc_show_*")

        Variable t, e, k, cnt, v
        for (t = 0; t < nT; t += 1)
            Make/O/N=(nK) $("mdc_raw_" + num2str(t)) = NaN
            Wave mdc = $("mdc_raw_" + num2str(t))
            SetScale/P x, k0, dk, WaveUnits(w, 1), mdc
            for (k = 0; k < nK; k += 1)
                mdc[k] = 0
                cnt = 0
                for (e = eStart; e <= eEnd; e += 1)
                    v = w[e][k][t]
                    if (numtype(v) == 0)
                        mdc[k] += v
                        cnt += 1
                    endif
                endfor
                if (cnt > 0)
                    mdc[k] /= cnt
                else
                    mdc[k] = NaN
                endif
            endfor
        endfor
    catch
        hadError = 1
    endtry

    SetDataFolder $oldDF
    if (hadError || GetRTError(1) != 0)
        return -1
    endif
    return 0
End

// Build show waves from raw waves, applying smoothing if enabled.
// Always recreates mdc_show_i from mdc_raw_i to guarantee consistency.
Function LJZ_MDCExtract_ApplySmoothing(runDF)
    String runDF

    NVAR SmEnable = $(LJZ_MDCExtract_BaseDF() + ":SmEnable")
    NVAR SmMethod = $(LJZ_MDCExtract_BaseDF() + ":SmMethod")
    NVAR SmN      = $(LJZ_MDCExtract_BaseDF() + ":SmN")
    NVAR SmN2     = $(LJZ_MDCExtract_BaseDF() + ":SmN2")
    NVAR SmPoly   = $(LJZ_MDCExtract_BaseDF() + ":SmPoly")

    Variable t = 0
    do
        Wave/Z raw = $(runDF + "mdc_raw_" + num2str(t))
        if (!WaveExists(raw))
            break
        endif
        Duplicate/O raw, $(runDF + "mdc_show_" + num2str(t))
        Wave sh = $(runDF + "mdc_show_" + num2str(t))

        if (SmEnable)
            LJZ_Extract_ApplySmoothToWave(sh, SmMethod, SmN, SmN2, SmPoly)
        endif
        t += 1
    while (1)

    // Kill any stale show waves with index >= current raw count.
    do
        Wave/Z stale = $(runDF + "mdc_show_" + num2str(t))
        if (!WaveExists(stale))
            break
        endif
        KillWaves/Z stale
        t += 1
    while (1)

    return 0
End

// Write run metadata to BaseDF globals and also locally into RunDF for
// downstream tools that only know the RunDF path.
Function LJZ_MDCExtract_RecordRunMeta(w, eStart, eEnd, runDF, useFermi, fermiE, fermiHalfWidth, fermiSigma, fermiMethod)
    Wave w
    Variable eStart, eEnd, useFermi, fermiE, fermiHalfWidth, fermiSigma, fermiMethod
    String runDF
    NVAR SmEnable = $(LJZ_MDCExtract_BaseDF() + ":SmEnable")
    NVAR SmN = $(LJZ_MDCExtract_BaseDF() + ":SmN")
    NVAR SmN2 = $(LJZ_MDCExtract_BaseDF() + ":SmN2")
    NVAR SmMethod = $(LJZ_MDCExtract_BaseDF() + ":SmMethod")
    NVAR SmPoly = $(LJZ_MDCExtract_BaseDF() + ":SmPoly")
    Variable lowPhys = DimOffset(w,0) + eStart * DimDelta(w,0)
    Variable highPhys = DimOffset(w,0) + eEnd * DimDelta(w,0)
    if (useFermi)
        lowPhys = fermiE - abs(fermiHalfWidth)
        highPhys = fermiE + abs(fermiHalfWidth)
    else
        fermiE = NaN; fermiHalfWidth = NaN; fermiSigma = NaN; fermiMethod = 0
    endif

    // BaseDF globals (current session)
    String/G  $(LJZ_MDCExtract_BaseDF() + ":RunDF")      = runDF
    Variable/G $(LJZ_MDCExtract_BaseDF() + ":Run_eStart") = eStart
    Variable/G $(LJZ_MDCExtract_BaseDF() + ":Run_eEnd")   = eEnd
    Variable/G $(LJZ_MDCExtract_BaseDF() + ":Run_t0")     = DimOffset(w, 2)
    Variable/G $(LJZ_MDCExtract_BaseDF() + ":Run_dt")     = DimDelta(w, 2)
    Variable/G $(LJZ_MDCExtract_BaseDF() + ":Run_nT")     = DimSize(w, 2)

    // Local copy in RunDF
    String oldDF = GetDataFolder(1)
    SetDataFolder $(RemoveEnding(runDF, ":"))
    Variable/G Run_eStart = eStart
    Variable/G Run_eEnd   = eEnd
    Variable/G Run_t0     = DimOffset(w, 2)
    Variable/G Run_dt     = DimDelta(w, 2)
    Variable/G Run_nT     = DimSize(w, 2)
    String/G   SourceWave = GetWavesDataFolder(w, 2)
    String/G   Run_sourceWavePath = GetWavesDataFolder(w, 2)
    String/G   Run_sourceWaveName = NameOfWave(w)
    String/G   Run_mode = "MDC"
    Variable/G Run_nTraces = DimSize(w, 2)
    Variable/G Run_smoothingEnabled = SmEnable
    Variable/G Run_smoothingN = SmN
    Variable/G Run_smoothingN2 = SmN2
    Variable/G Run_smoothingMethod = SmMethod
    Variable/G Run_smoothingPoly = SmPoly
    Make/O/N=3 Run_dimSize = {DimSize(w,0), DimSize(w,1), DimSize(w,2)}
    Make/O/N=3 Run_dimOffset = {DimOffset(w,0), DimOffset(w,1), DimOffset(w,2)}
    Make/O/N=3 Run_dimDelta = {DimDelta(w,0), DimDelta(w,1), DimDelta(w,2)}
    Make/O/T/N=3 Run_dimUnits = {WaveUnits(w,0), WaveUnits(w,1), WaveUnits(w,2)}
    Make/O/N=(DimSize(w,2)) Run_windowLow = eStart
    Make/O/N=(DimSize(w,2)) Run_windowHigh = eEnd
    Make/O/N=(DimSize(w,2)) Run_indexLow = eStart
    Make/O/N=(DimSize(w,2)) Run_indexHigh = eEnd
    Variable/G Run_useFermiWeightedMDC = useFermi != 0
    Variable/G Run_FermiE = fermiE
    Variable/G Run_FermiHalfWidth = fermiHalfWidth
    Variable/G Run_FermiSigma = fermiSigma
    Variable/G Run_FermiWeightMethod = fermiMethod
    Variable/G Run_energyWindowLowPhys = lowPhys
    Variable/G Run_energyWindowHighPhys = highPhys
    Variable/G Run_energyIndexLow = eStart
    Variable/G Run_energyIndexHigh = eEnd
    String/G Run_createdAt = Secs2Date(DateTime, 0) + " " + Secs2Time(DateTime, 3)
    SetDataFolder $oldDF

    return 0
End

Function/S LJZ_MDCExtract_WeightMethodName(method)
    Variable method
    if (method == 0)
        return "Uniform"
    elseif (method == 1)
        return "Gaussian"
    elseif (method == 2)
        return "Triangular"
    endif
    return "Unknown"
End

// Build a graph title string for the overlay graph.
Function/S LJZ_MDCExtract_BuildGraphTitle(w, eStart, eEnd, baseName)
    Wave w
    Variable eStart, eEnd
    String baseName

    String nm
    if (strlen(baseName) > 0)
        nm = baseName
    else
        nm = NameOfWave(w)
    endif
    nm = LJZ_Extract_ShortenForTitle(nm, 60)

    Variable physE0 = DimOffset(w, 0) + eStart * DimDelta(w, 0)
    Variable physE1 = DimOffset(w, 0) + eEnd   * DimDelta(w, 0)

    String title
    NVAR/Z UseFermiWeightedMDC = $(LJZ_MDCExtract_BaseDF() + ":UseFermiWeightedMDC")
    if (NVAR_Exists(UseFermiWeightedMDC) && UseFermiWeightedMDC != 0)
        NVAR FermiE = $(LJZ_MDCExtract_BaseDF() + ":FermiE")
        NVAR FermiHalfWidth = $(LJZ_MDCExtract_BaseDF() + ":FermiHalfWidth")
        NVAR FermiSigma = $(LJZ_MDCExtract_BaseDF() + ":FermiSigma")
        NVAR FermiWeightMethod = $(LJZ_MDCExtract_BaseDF() + ":FermiWeightMethod")
        Variable sigmaUsed = FermiSigma
        if (sigmaUsed <= 0)
            sigmaUsed = abs(FermiHalfWidth) / 2
        endif
        sprintf title, "%s | weighted EF=%.6g, halfWidth=%.6g, sigma=%.6g, %s", nm, FermiE, abs(FermiHalfWidth), sigmaUsed, LJZ_MDCExtract_WeightMethodName(FermiWeightMethod)
    else
        sprintf title, "%s | E=[%.4g, %.4g] (idx %d-%d)", nm, physE0, physE1, eStart, eEnd
    endif
    return title
End

// Full MDC run: extract → smooth → display → push RunDF → return RunDF path.
// Returns empty string on failure.
Function/S LJZ_MDCExtract_RunFrom3DWave(w, e0, e1, baseName)
    Wave w
    Variable e0, e1
    String baseName

    LJZ_MDCExtract_EnsureDF()

    if (!LJZ_Extract_Is3DNumericWave(w))
        return ""
    endif

    Variable nE = DimSize(w, 0)
    Variable eStart = max(0, min(nE - 1, min(round(e0), round(e1))))
    Variable eEnd   = max(0, min(nE - 1, max(round(e0), round(e1))))

    NVAR UseFermiWeightedMDC = $(LJZ_MDCExtract_BaseDF() + ":UseFermiWeightedMDC")
    Variable fermiUse = UseFermiWeightedMDC != 0
    Variable fermiE = NaN, fermiHalfWidth = NaN, fermiSigmaUsed = NaN, fermiMethod = 0

    String nm = CleanupName(NameOfWave(w), 0)
    if (strlen(nm) > 20)
        nm = nm[0, 19]
    endif
    String tag
    if (strlen(CleanupName(baseName, 0)) > 0)
        tag = CleanupName(baseName, 0)
    else
        tag = "MDC"
    endif
    String runDF
    if (!fermiUse)
        runDF = LJZ_MDCExtract_RunRoot() + ":" + nm + "_" + tag + "_e" + num2str(eStart) + "_" + num2str(eEnd) + ":"
        if (LJZ_MDCExtract_BuildRawMDCs(w, eStart, eEnd, runDF) != 0)
            DoAlert 0, "MDC 提取失败：无法从源 wave 构建原始 MDC。"
            return ""
        endif
    else
        NVAR FermiE = $(LJZ_MDCExtract_BaseDF() + ":FermiE")
        NVAR FermiHalfWidth = $(LJZ_MDCExtract_BaseDF() + ":FermiHalfWidth")
        NVAR FermiSigma = $(LJZ_MDCExtract_BaseDF() + ":FermiSigma")
        NVAR FermiWeightMethod = $(LJZ_MDCExtract_BaseDF() + ":FermiWeightMethod")
        Variable eLow = FermiE - abs(FermiHalfWidth)
        Variable eHigh = FermiE + abs(FermiHalfWidth)
        if (LJZ_Extract_WindowPhysToIndex(DimOffset(w,0), DimDelta(w,0), nE, eLow, eHigh, eStart, eEnd) != 0)
            DoAlert 0, "MDC 提取失败：EF 加权窗口在当前能量轴上为空。"
            return ""
        endif
        fermiE = FermiE
        fermiHalfWidth = FermiHalfWidth
        fermiMethod = FermiWeightMethod
        fermiSigmaUsed = FermiSigma
        if (fermiSigmaUsed <= 0)
            fermiSigmaUsed = abs(fermiHalfWidth) / 2
        endif
        runDF = LJZ_MDCExtract_RunRoot() + ":" + nm + "_" + tag + "_EFw_EF" + CleanupName(num2str(fermiE),0) + "_hw" + CleanupName(num2str(abs(fermiHalfWidth)),0) + "_e" + num2str(eStart) + "_" + num2str(eEnd) + ":"
        if (LJZ_MDCExtract_BuildRawMDCsWeightedFermi(w, fermiE, fermiHalfWidth, FermiSigma, fermiMethod, runDF) != 0)
            DoAlert 0, "MDC 提取失败：无法构建 EF 加权原始 MDC。"
            return ""
        endif
    endif

    LJZ_MDCExtract_ApplySmoothing(runDF)
    LJZ_MDCExtract_RecordRunMeta(w, eStart, eEnd, runDF, fermiUse, fermiE, fermiHalfWidth, fermiSigmaUsed, fermiMethod)

    // Push to MDCWB TargetDF for downstream fitting
    LJZ_Extract_PushRunDFToWorkbench(runDF, "root:Packages:ARPES_LJZ:MDCWB:TargetDF")

    NVAR evary = $(LJZ_MDCExtract_BaseDF() + ":evary")
    String title = LJZ_MDCExtract_BuildGraphTitle(w, eStart, eEnd, baseName)
    LJZ_Extract_BuildOverlayGraph(runDF, "mdc_show", LJZ_MDCExtract_GraphName(), title, "k (Å⁻¹)", evary)

    return runDF
End

// Re-smooth and re-display the last successful run without re-extracting raw data.
Function LJZ_MDCExtract_ReShowCurrentRun()
    LJZ_MDCExtract_EnsureDF()

    SVAR runDF = $(LJZ_MDCExtract_BaseDF() + ":RunDF")
    SVAR bn    = $(LJZ_MDCExtract_BaseDF() + ":BaseName")
    NVAR evary = $(LJZ_MDCExtract_BaseDF() + ":evary")

    if (strlen(runDF) == 0 || !DataFolderExists(RemoveEnding(runDF, ":")))
        return -1
    endif

    LJZ_MDCExtract_ApplySmoothing(runDF)

    // Rebuild title from saved metadata in runDF
    NVAR/Z es = $(runDF + "Run_eStart")
    NVAR/Z ee = $(runDF + "Run_eEnd")
    SVAR/Z srcW = $(runDF + "SourceWave")
    String title = bn
    if (NVAR_Exists(es) && NVAR_Exists(ee))
        sprintf title, "%s | E idx [%d, %d]", bn, round(es), round(ee)
    endif
    LJZ_Extract_BuildOverlayGraph(runDF, "mdc_show", LJZ_MDCExtract_GraphName(), title, "k (Å⁻¹)", evary)

    return 0
End


// ============================================================================
//  Section 4. MDC Extract – user action wrappers
// ============================================================================

Function LJZ_MDCExtract_DoExtract()
    LJZ_MDCExtract_EnsureDF()

    SVAR sWave = $(LJZ_MDCExtract_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        DoAlert 0, "请先选择一个 3D wave。"
        return -1
    endif

    Wave/Z w = $sWave
    LJZ_Extract_PrintDimSanity(w, "MDC source")
    if (!LJZ_Extract_Is3DNumericWave(w))
        DoAlert 0, "当前选择不是有效的 3D wave（energy × k × stack）。"
        return -1
    endif

    NVAR e0      = $(LJZ_MDCExtract_BaseDF() + ":EIndex")
    NVAR e1      = $(LJZ_MDCExtract_BaseDF() + ":Exe")
    NVAR usePhys = $(LJZ_MDCExtract_BaseDF() + ":UsePhysE")
    SVAR bn      = $(LJZ_MDCExtract_BaseDF() + ":BaseName")

    Variable eStart = round(e0)
    Variable eEnd   = round(e1)
    if (usePhys)
        if (LJZ_Extract_WindowPhysToIndex(DimOffset(w,0), DimDelta(w,0), DimSize(w,0), e0, e1, eStart, eEnd) != 0)
            Print "WARNING: MDC energy window is empty after physical→index conversion. Extraction skipped."
            return -1
        endif
    endif

    String runDF = LJZ_MDCExtract_RunFrom3DWave(w, eStart, eEnd, bn)
    if (strlen(runDF) == 0)
        return -1
    endif

    LJZ_MDCExtract_RefreshTitleBoxes()
    return 0
End


// ============================================================================
//  Section 5. MDC Extract – panel
// ============================================================================

Function LJZ_MDCExtract()
    LJZ_MDCExtract_EnsureDF()
    LJZ_MDCExtract_RebuildWaveList()
    LJZ_MDCExtract_OpenPanel()
    LJZ_MDCExtract_RefreshTitleBoxes()
    return 0
End

Function LJZ_MDCExtract_OpenPanel()
    LJZ_MDCExtract_EnsureDF()

    String p = LJZ_MDCExtract_PanelName()
    DoWindow/F $p
    if (V_flag != 0)
        return 0
    endif

    NewPanel/N=$p /W=(80, 80, 760, 620) as "MDC Extract (LJZ)"

    // ---- top row: source DF ----
    GroupBox gbSrc, pos={6,6}, size={748,56}, title="Data Source"
    TitleBox tbSrcDF, pos={18,28}, size={52,18}, title="Source DF:", frame=0
    SetVariable svSourceDF, pos={80,26}, size={490,20}, title=" "
    SetVariable svSourceDF, value=root:ARPES_LJZ:MDCExtract:SourceDF, proc=LJZ_MDCExtract_SetVarProc
    CheckBox cbRec, pos={592,29}, size={78,16}, title="Recursive"
    CheckBox cbRec, variable=root:ARPES_LJZ:MDCExtract:Recursive, proc=LJZ_MDCExtract_CheckProc
    Button btScan, pos={686,24}, size={60,24}, title="Scan", proc=LJZ_MDCExtract_ButtonProc

    // ---- left: wave list ----
    GroupBox gbList, pos={6,70}, size={340,386}, title="Available 3D Waves"
    ListBox lbWave, pos={18,90}, size={318,358}
    ListBox lbWave, listWave=root:ARPES_LJZ:MDCExtract:LB_Disp
    ListBox lbWave, selWave=root:ARPES_LJZ:MDCExtract:LB_Sel, mode=1, proc=LJZ_MDCExtract_ListBoxProc

    // ---- right: extraction parameters ----
    GroupBox gbParam, pos={358,70}, size={396,154}, title="Energy Window (dim0)"
    TitleBox tbEMode, pos={370,92}, size={380,16}, title="Mode: 0=index  1=physical value", frame=0
    CheckBox cbPhysE, pos={370,114}, size={120,16}, title="Use physical E value"
    CheckBox cbPhysE, variable=root:ARPES_LJZ:MDCExtract:UsePhysE, proc=LJZ_MDCExtract_CheckProc

    SetVariable svE0, pos={370,138}, size={180,20}, title="E start"
    SetVariable svE0, variable=root:ARPES_LJZ:MDCExtract:EIndex, proc=LJZ_MDCExtract_SetVarProc
    SetVariable svE1, pos={564,138}, size={180,20}, title="E end"
    SetVariable svE1, variable=root:ARPES_LJZ:MDCExtract:Exe, proc=LJZ_MDCExtract_SetVarProc

    SetVariable svEvary, pos={370,168}, size={180,20}, title="Vertical offset"
    SetVariable svEvary, variable=root:ARPES_LJZ:MDCExtract:evary, proc=LJZ_MDCExtract_SetVarProc
    SetVariable svBaseName, pos={564,168}, size={180,20}, title="Base name"
    SetVariable svBaseName, value=root:ARPES_LJZ:MDCExtract:BaseName, proc=LJZ_MDCExtract_SetVarProc
    GroupBox gbFermi, pos={358,198}, size={396,96}, title="Fermi-weighted MDC"
    CheckBox cbFermiWeightedMDC, pos={370,220}, size={130,16}, title="Weighted EF MDC"
    CheckBox cbFermiWeightedMDC, variable=root:ARPES_LJZ:MDCExtract:UseFermiWeightedMDC, proc=LJZ_MDCExtract_CheckProc
    SetVariable svFermiE, pos={370,242}, size={120,20}, title="EF"
    SetVariable svFermiE, variable=root:ARPES_LJZ:MDCExtract:FermiE, proc=LJZ_MDCExtract_SetVarProc
    SetVariable svFermiHalfWidth, pos={500,242}, size={120,20}, title="Half width"
    SetVariable svFermiHalfWidth, variable=root:ARPES_LJZ:MDCExtract:FermiHalfWidth, proc=LJZ_MDCExtract_SetVarProc
    SetVariable svFermiSigma, pos={630,242}, size={114,20}, title="Sigma"
    SetVariable svFermiSigma, variable=root:ARPES_LJZ:MDCExtract:FermiSigma, proc=LJZ_MDCExtract_SetVarProc
    PopupMenu pmFermiWeightMethod, pos={370,266}, size={220,20}, title="Weight"
    PopupMenu pmFermiWeightMethod, value="0 Uniform;1 Gaussian;2 Triangular;", proc=LJZ_MDCExtract_PopupProc

    // ---- right: smoothing ----
    GroupBox gbSm, pos={358,302}, size={396,130}, title="Smoothing"
    CheckBox cbSmEn, pos={370,324}, size={68,16}, title="Enable"
    CheckBox cbSmEn, variable=root:ARPES_LJZ:MDCExtract:SmEnable, proc=LJZ_MDCExtract_CheckProc
    PopupMenu pmSmMethod, pos={452,322}, size={180,20}, title="Method"
    PopupMenu pmSmMethod, mode=2, popvalue="Smooth", value="0 None;1 Smooth;2 Savitzky-Golay;"
    PopupMenu pmSmMethod, proc=LJZ_MDCExtract_PopupProc

    SetVariable svSmN, pos={370,352}, size={170,20}, title="N1 (points)"
    SetVariable svSmN, variable=root:ARPES_LJZ:MDCExtract:SmN, proc=LJZ_MDCExtract_SetVarProc
    SetVariable svSmN2, pos={554,352}, size={170,20}, title="N2 (2nd pass)"
    SetVariable svSmN2, variable=root:ARPES_LJZ:MDCExtract:SmN2, proc=LJZ_MDCExtract_SetVarProc
    SetVariable svSmPoly, pos={370,380}, size={170,20}, title="Poly order (SG)"
    SetVariable svSmPoly, variable=root:ARPES_LJZ:MDCExtract:SmPoly, proc=LJZ_MDCExtract_SetVarProc

    // ---- action buttons ----
    Button btExtract, pos={370,446}, size={120,32}, title="Extract MDC", proc=LJZ_MDCExtract_ButtonProc
    Button btReShow,  pos={504,446}, size={120,32}, title="Re-smooth",   proc=LJZ_MDCExtract_ButtonProc
    Button btFocusG,  pos={638,446}, size={110,32}, title="Focus Graph", proc=LJZ_MDCExtract_ButtonProc

    // ---- info boxes ----
    GroupBox gbInfo, pos={6,524}, size={748,80}, title="Status"
    TitleBox tbSel, pos={18,544}, size={720,18}, frame=0, title="Selected: "
    TitleBox tbRun, pos={18,568}, size={720,18}, frame=0, title="RunDF: "

    // Set popup to current SmMethod
    NVAR SmMethod = $(LJZ_MDCExtract_BaseDF() + ":SmMethod")
    PopupMenu pmSmMethod, win=$p, mode=(SmMethod + 1)
    NVAR FermiWeightMethod = $(LJZ_MDCExtract_BaseDF() + ":FermiWeightMethod")
    PopupMenu pmFermiWeightMethod, win=$p, mode=(FermiWeightMethod + 1)

    LJZ_MDCExtract_RefreshTitleBoxes()
    return 0
End

Function LJZ_MDCExtract_RefreshTitleBoxes()
    String p = LJZ_MDCExtract_PanelName()
    if (WinType(p) == 0)
        return 0
    endif

    SVAR sWave = $(LJZ_MDCExtract_BaseDF() + ":WaveSel")
    SVAR runDF = $(LJZ_MDCExtract_BaseDF() + ":RunDF")

    TitleBox tbSel, win=$p, title="Selected: " + LJZ_Extract_ShortenForTitle(sWave, 100)
    TitleBox tbRun, win=$p, title="RunDF: "    + LJZ_Extract_ShortenForTitle(runDF, 100)
    return 0
End


// ============================================================================
//  Section 6. MDC Extract – callbacks
// ============================================================================

Function LJZ_MDCExtract_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    String c = ba.ctrlName

    if (CmpStr(c, "btScan") == 0)
        LJZ_MDCExtract_RebuildWaveList()
        LJZ_MDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(c, "btExtract") == 0)
        LJZ_MDCExtract_DoExtract()
        return 0
    endif

    if (CmpStr(c, "btReShow") == 0)
        LJZ_MDCExtract_ReShowCurrentRun()
        LJZ_MDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(c, "btFocusG") == 0)
        DoWindow/F $(LJZ_MDCExtract_GraphName())
        return 0
    endif

    return 0
End

Function LJZ_MDCExtract_PopupProc(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa

    if (pa.eventCode != 2)
        return 0
    endif

    if (CmpStr(pa.ctrlName, "pmSmMethod") == 0)
        NVAR SmMethod = $(LJZ_MDCExtract_BaseDF() + ":SmMethod")
        SmMethod = pa.popNum - 1
        LJZ_MDCExtract_ReShowCurrentRun()
        return 0
    endif
    if (CmpStr(pa.ctrlName, "pmFermiWeightMethod") == 0)
        NVAR FermiWeightMethod = $(LJZ_MDCExtract_BaseDF() + ":FermiWeightMethod")
        FermiWeightMethod = pa.popNum - 1
        LJZ_MDCExtract_RefreshTitleBoxes()
        return 0
    endif

    return 0
End

Function LJZ_MDCExtract_SetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    // Respond only on commit (mouse-up=1, enter=2) and end-of-edit (8).
    // Live typing (3) is intentionally ignored to avoid mid-type re-extractions.
    if (sva.eventCode != 1 && sva.eventCode != 2 && sva.eventCode != 8)
        return 0
    endif

    String c = sva.ctrlName

    if (CmpStr(c, "svSourceDF") == 0)
        SVAR sDF = $(LJZ_MDCExtract_BaseDF() + ":SourceDF")
        sDF = LJZ_Extract_df_with_colon(sva.sval)
        LJZ_MDCExtract_RebuildWaveList()
        LJZ_MDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(c, "svSmN") == 0 || CmpStr(c, "svSmN2") == 0 || CmpStr(c, "svSmPoly") == 0 || CmpStr(c, "svEvary") == 0)
        LJZ_MDCExtract_ReShowCurrentRun()
        LJZ_MDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(c, "svFermiE") == 0 || CmpStr(c, "svFermiHalfWidth") == 0 || CmpStr(c, "svFermiSigma") == 0)
        LJZ_MDCExtract_RefreshTitleBoxes()
        return 0
    endif

    LJZ_MDCExtract_RefreshTitleBoxes()
    return 0
End

Function LJZ_MDCExtract_CheckProc(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba

    if (cba.eventCode != 2)
        return 0
    endif

    String c = cba.ctrlName

    if (CmpStr(c, "cbRec") == 0)
        LJZ_MDCExtract_RebuildWaveList()
        LJZ_MDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(c, "cbSmEn") == 0)
        LJZ_MDCExtract_ReShowCurrentRun()
        LJZ_MDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(c, "cbPhysE") == 0)
        LJZ_MDCExtract_RefreshTitleBoxes()
        return 0
    endif
    if (CmpStr(c, "cbFermiWeightedMDC") == 0)
        LJZ_MDCExtract_RefreshTitleBoxes()
        return 0
    endif

    return 0
End

Function LJZ_MDCExtract_ListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    // eventCode 4 = mouse-up selection change (single-click confirm)
    if (lba.eventCode != 4)
        return 0
    endif

    if (lba.row < 0)
        return 0
    endif

    LJZ_MDCExtract_SelectWaveRow(lba.row)
    Wave/T wPath = $(LJZ_MDCExtract_BaseDF() + ":LB_Path")
    Wave/Z wSel = $(wPath[lba.row])
    LJZ_Extract_PrintDimSanity(wSel, "MDC selected")
    LJZ_MDCExtract_RefreshTitleBoxes()
    return 0
End


// ============================================================================
//  Section 7. EDC Extract – state / paths
// ============================================================================

Function/S LJZ_EDCExtract_BaseDF()
    return "root:ARPES_LJZ:EDCExtract"
End

Function/S LJZ_EDCExtract_RunRoot()
    return "root:ARPES_LJZ:EDCExtract_RUNS"
End

Function/S LJZ_EDCExtract_PanelName()
    return "LJZ_EDCExtract_Panel"
End

Function/S LJZ_EDCExtract_GraphName()
    return "LJZ_EDCExtract_Graph"
End

Function LJZ_EDCExtract_EnsureDF()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O $(LJZ_EDCExtract_BaseDF())
    NewDataFolder/O $(LJZ_EDCExtract_RunRoot())

    // ---- source DF ----
    SVAR/Z sBase = $(LJZ_EDCExtract_BaseDF() + ":SourceDF")
    if (!SVAR_Exists(sBase))
        String/G $(LJZ_EDCExtract_BaseDF() + ":SourceDF") = "root:"
    endif

    NVAR/Z rec = $(LJZ_EDCExtract_BaseDF() + ":Recursive")
    if (!NVAR_Exists(rec))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Recursive") = 0
    endif

    // ---- current selected wave ----
    SVAR/Z sWave = $(LJZ_EDCExtract_BaseDF() + ":WaveSel")
    if (!SVAR_Exists(sWave))
        String/G $(LJZ_EDCExtract_BaseDF() + ":WaveSel") = ""
    endif

    NVAR/Z selRow = $(LJZ_EDCExtract_BaseDF() + ":SelRow")
    if (!NVAR_Exists(selRow))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":SelRow") = -1
    endif

    // ---- extraction parameters ----
    // kStart / kEnd are pixel indices into dim1 (kparallel).
    // UsePhysK=1 means the panel values are physical k values (Å⁻¹ or other units).
    NVAR/Z k0 = $(LJZ_EDCExtract_BaseDF() + ":KIndex")
    if (!NVAR_Exists(k0))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":KIndex") = 0
    endif

    NVAR/Z k1 = $(LJZ_EDCExtract_BaseDF() + ":Kxe")
    if (!NVAR_Exists(k1))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Kxe") = 0
    endif

    NVAR/Z usePhysK = $(LJZ_EDCExtract_BaseDF() + ":UsePhysK")
    if (!NVAR_Exists(usePhysK))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":UsePhysK") = 0    // 0=index, 1=physical
    endif

    NVAR/Z evary = $(LJZ_EDCExtract_BaseDF() + ":evary")
    if (!NVAR_Exists(evary))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":evary") = 0
    endif

    SVAR/Z bn = $(LJZ_EDCExtract_BaseDF() + ":BaseName")
    if (!SVAR_Exists(bn))
        String/G $(LJZ_EDCExtract_BaseDF() + ":BaseName") = "EDC"
    endif

    // ---- run metadata ----
    SVAR/Z runDF = $(LJZ_EDCExtract_BaseDF() + ":RunDF")
    if (!SVAR_Exists(runDF))
        String/G $(LJZ_EDCExtract_BaseDF() + ":RunDF") = ""
    endif

    NVAR/Z Run_kStart = $(LJZ_EDCExtract_BaseDF() + ":Run_kStart")
    if (!NVAR_Exists(Run_kStart))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_kStart") = NaN
    endif

    NVAR/Z Run_kEnd = $(LJZ_EDCExtract_BaseDF() + ":Run_kEnd")
    if (!NVAR_Exists(Run_kEnd))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_kEnd") = NaN
    endif

    NVAR/Z Run_t0 = $(LJZ_EDCExtract_BaseDF() + ":Run_t0")
    if (!NVAR_Exists(Run_t0))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_t0") = NaN
    endif

    NVAR/Z Run_dt = $(LJZ_EDCExtract_BaseDF() + ":Run_dt")
    if (!NVAR_Exists(Run_dt))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_dt") = NaN
    endif

    NVAR/Z Run_nT = $(LJZ_EDCExtract_BaseDF() + ":Run_nT")
    if (!NVAR_Exists(Run_nT))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_nT") = NaN
    endif

    // ---- smoothing parameters ----
    NVAR/Z SmEnable = $(LJZ_EDCExtract_BaseDF() + ":SmEnable")
    if (!NVAR_Exists(SmEnable))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":SmEnable") = 0
    endif

    NVAR/Z SmMethod = $(LJZ_EDCExtract_BaseDF() + ":SmMethod")
    if (!NVAR_Exists(SmMethod))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":SmMethod") = 1
    endif

    NVAR/Z SmN = $(LJZ_EDCExtract_BaseDF() + ":SmN")
    if (!NVAR_Exists(SmN))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":SmN") = 11
    endif

    NVAR/Z SmN2 = $(LJZ_EDCExtract_BaseDF() + ":SmN2")
    if (!NVAR_Exists(SmN2))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":SmN2") = 7
    endif

    NVAR/Z SmPoly = $(LJZ_EDCExtract_BaseDF() + ":SmPoly")
    if (!NVAR_Exists(SmPoly))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":SmPoly") = 4
    endif

    // ---- listbox waves ----
    Wave/T/Z wDisp = $(LJZ_EDCExtract_BaseDF() + ":LB_Disp")
    if (!WaveExists(wDisp))
        Make/O/T/N=0 $(LJZ_EDCExtract_BaseDF() + ":LB_Disp")
    endif

    Wave/Z wSel = $(LJZ_EDCExtract_BaseDF() + ":LB_Sel")
    if (!WaveExists(wSel))
        Make/O/N=0 $(LJZ_EDCExtract_BaseDF() + ":LB_Sel") = 0
    endif

    Wave/T/Z wPath = $(LJZ_EDCExtract_BaseDF() + ":LB_Path")
    if (!WaveExists(wPath))
        Make/O/T/N=0 $(LJZ_EDCExtract_BaseDF() + ":LB_Path")
    endif

    return 0
End


// ============================================================================
//  Section 8. EDC Extract – wave list
// ============================================================================

Function LJZ_EDCExtract_RebuildWaveList()
    LJZ_EDCExtract_EnsureDF()

    SVAR sBase  = $(LJZ_EDCExtract_BaseDF() + ":SourceDF")
    NVAR rec    = $(LJZ_EDCExtract_BaseDF() + ":Recursive")
    SVAR sWave  = $(LJZ_EDCExtract_BaseDF() + ":WaveSel")
    NVAR selRow = $(LJZ_EDCExtract_BaseDF() + ":SelRow")

    String prevWave = sWave
    String dfStr = LJZ_Extract_df_with_colon(sBase)

    if (!DataFolderExists(dfStr))
        Make/O/T/N=0 $(LJZ_EDCExtract_BaseDF() + ":LB_Disp")
        Make/O/T/N=0 $(LJZ_EDCExtract_BaseDF() + ":LB_Path")
        Make/O/N=0   $(LJZ_EDCExtract_BaseDF() + ":LB_Sel")
        sWave = ""
        selRow = -1
        return -1
    endif

    String listStr = LJZ_Extract_List3DWaves(dfStr, rec)
    Variable n = ItemsInList(listStr, ";")

    Make/O/T/N=(n) $(LJZ_EDCExtract_BaseDF() + ":LB_Disp")
    Make/O/T/N=(n) $(LJZ_EDCExtract_BaseDF() + ":LB_Path")
    Make/O/N=(n)   $(LJZ_EDCExtract_BaseDF() + ":LB_Sel") = 0

    Wave/T wDisp = $(LJZ_EDCExtract_BaseDF() + ":LB_Disp")
    Wave/T wPath = $(LJZ_EDCExtract_BaseDF() + ":LB_Path")
    Wave   wSel  = $(LJZ_EDCExtract_BaseDF() + ":LB_Sel")

    Variable i
    for (i = 0; i < n; i += 1)
        String wFull = StringFromList(i, listStr, ";")
        wPath[i] = wFull
        wDisp[i] = NameOfWave($wFull)
    endfor

    Variable keepRow = WhichListItem(prevWave, listStr, ";", 0, 0)
    if (keepRow < 0 && n > 0)
        keepRow = 0
    endif

    if (n > 0 && keepRow >= 0)
        keepRow = max(0, min(n - 1, keepRow))
        wSel[keepRow] = 1
        sWave  = wPath[keepRow]
        selRow = keepRow
    else
        sWave = ""
        selRow = -1
    endif

    return 0
End

Function LJZ_EDCExtract_SelectWaveRow(row)
    Variable row

    LJZ_EDCExtract_EnsureDF()

    Wave/T wPath = $(LJZ_EDCExtract_BaseDF() + ":LB_Path")
    Wave   wSel  = $(LJZ_EDCExtract_BaseDF() + ":LB_Sel")
    SVAR sWave   = $(LJZ_EDCExtract_BaseDF() + ":WaveSel")
    NVAR selRow  = $(LJZ_EDCExtract_BaseDF() + ":SelRow")

    Variable n = numpnts(wPath)
    if (n <= 0 || row < 0 || row >= n)
        return -1
    endif

    wSel = 0
    wSel[row] = 1
    sWave  = wPath[row]
    selRow = row

    return 0
End

Function LJZ_EDCExtract_RestoreSelectionUI()
    String p = LJZ_EDCExtract_PanelName()
    if (WinType(p) == 0)
        return 0
    endif

    NVAR selRow = $(LJZ_EDCExtract_BaseDF() + ":SelRow")
    ListBox/Z lbWave, win=$p, selRow=selRow
    ControlUpdate/W=$p lbWave
    return 0
End


// ============================================================================
//  Section 9. EDC Extract – kernel
// ============================================================================

// Convert physical k value to pixel index using wave dim1 scaling.
Function LJZ_EDCExtract_PhysKToIndex(w, physK)
    Wave w
    Variable physK

    Variable dk = DimDelta(w, 1)
    if (numtype(dk) != 0 || dk == 0)
        return 0
    endif
    Variable idx = round((physK - DimOffset(w, 1)) / dk)
    idx = max(0, min(DimSize(w, 1) - 1, idx))
    return idx
End

// Build raw EDC waves in runDF from source 3D wave.
// Averages dim1 (kparallel) from kStart to kEnd (pixel indices) for each stack layer.
// Output: <runDF>edc_raw_0 ... edc_raw_(nT-1)
// Returns 0 on success, -1 on invalid input.
Function LJZ_EDCExtract_BuildRawEDCs(w, kStart, kEnd, runDF)
    Wave w
    Variable kStart, kEnd
    String runDF

    Variable nE = DimSize(w, 0)
    Variable nK = DimSize(w, 1)
    Variable nT = DimSize(w, 2)

    if (nE <= 0 || nK <= 0 || nT <= 0)
        return -1
    endif

    kStart = max(0, min(nK - 1, round(kStart)))
    kEnd   = max(0, min(nK - 1, round(kEnd)))
    if (kStart > kEnd)
        Variable tmp = kStart
        kStart = kEnd
        kEnd = tmp
    endif

    Variable nAvg = kEnd - kStart + 1
    if (nAvg <= 0)
        return -1
    endif

    Variable e0 = DimOffset(w, 0)
    Variable de = DimDelta(w, 0)

    NewDataFolder/O $(RemoveEnding(runDF, ":"))
    String oldDF = GetDataFolder(1)

    Variable hadError = 0
    try
        SetDataFolder $(RemoveEnding(runDF, ":"))

        LJZ_Extract_KillWavesByPatternInRunDF(runDF, "mdc_raw_*")
        LJZ_Extract_KillWavesByPatternInRunDF(runDF, "mdc_show_*")
        LJZ_Extract_KillWavesByPatternInRunDF(runDF, "edc_raw_*")
        LJZ_Extract_KillWavesByPatternInRunDF(runDF, "edc_show_*")

        Variable t, k, e, cnt, v
        for (t = 0; t < nT; t += 1)
            Make/O/N=(nE) $("edc_raw_" + num2str(t)) = NaN
            Wave edc = $("edc_raw_" + num2str(t))
            SetScale/P x, e0, de, WaveUnits(w, 0), edc
            for (e = 0; e < nE; e += 1)
                edc[e] = 0
                cnt = 0
                for (k = kStart; k <= kEnd; k += 1)
                    v = w[e][k][t]
                    if (numtype(v) == 0)
                        edc[e] += v
                        cnt += 1
                    endif
                endfor
                if (cnt > 0)
                    edc[e] /= cnt
                else
                    edc[e] = NaN
                endif
            endfor
        endfor
    catch
        hadError = 1
    endtry

    SetDataFolder $oldDF
    if (hadError || GetRTError(1) != 0)
        return -1
    endif
    return 0
End

// Build show waves from raw waves, applying smoothing if enabled.
Function LJZ_EDCExtract_ApplySmoothing(runDF)
    String runDF

    NVAR SmEnable = $(LJZ_EDCExtract_BaseDF() + ":SmEnable")
    NVAR SmMethod = $(LJZ_EDCExtract_BaseDF() + ":SmMethod")
    NVAR SmN      = $(LJZ_EDCExtract_BaseDF() + ":SmN")
    NVAR SmN2     = $(LJZ_EDCExtract_BaseDF() + ":SmN2")
    NVAR SmPoly   = $(LJZ_EDCExtract_BaseDF() + ":SmPoly")

    Variable t = 0
    do
        Wave/Z raw = $(runDF + "edc_raw_" + num2str(t))
        if (!WaveExists(raw))
            break
        endif
        Duplicate/O raw, $(runDF + "edc_show_" + num2str(t))
        Wave sh = $(runDF + "edc_show_" + num2str(t))
        if (SmEnable)
            LJZ_Extract_ApplySmoothToWave(sh, SmMethod, SmN, SmN2, SmPoly)
        endif
        t += 1
    while (1)

    do
        Wave/Z stale = $(runDF + "edc_show_" + num2str(t))
        if (!WaveExists(stale))
            break
        endif
        KillWaves/Z stale
        t += 1
    while (1)

    return 0
End

// Write run metadata to BaseDF globals and also locally into RunDF.
Function LJZ_EDCExtract_RecordRunMeta(w, kStart, kEnd, runDF)
    Wave w
    Variable kStart, kEnd
    String runDF
    NVAR SmEnable = $(LJZ_EDCExtract_BaseDF() + ":SmEnable")
    NVAR SmN = $(LJZ_EDCExtract_BaseDF() + ":SmN")
    NVAR SmN2 = $(LJZ_EDCExtract_BaseDF() + ":SmN2")
    NVAR SmMethod = $(LJZ_EDCExtract_BaseDF() + ":SmMethod")
    NVAR SmPoly = $(LJZ_EDCExtract_BaseDF() + ":SmPoly")

    String/G  $(LJZ_EDCExtract_BaseDF() + ":RunDF")       = runDF
    Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_kStart") = kStart
    Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_kEnd")   = kEnd
    Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_t0")     = DimOffset(w, 2)
    Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_dt")     = DimDelta(w, 2)
    Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_nT")     = DimSize(w, 2)

    String oldDF = GetDataFolder(1)
    SetDataFolder $(RemoveEnding(runDF, ":"))
    Variable/G Run_kStart = kStart
    Variable/G Run_kEnd   = kEnd
    Variable/G Run_t0     = DimOffset(w, 2)
    Variable/G Run_dt     = DimDelta(w, 2)
    Variable/G Run_nT     = DimSize(w, 2)
    String/G   SourceWave = GetWavesDataFolder(w, 2)
    String/G   Run_sourceWavePath = GetWavesDataFolder(w, 2)
    String/G   Run_sourceWaveName = NameOfWave(w)
    String/G   Run_mode = "EDC"
    Variable/G Run_nTraces = DimSize(w, 2)
    Variable/G Run_smoothingEnabled = SmEnable
    Variable/G Run_smoothingN = SmN
    Variable/G Run_smoothingN2 = SmN2
    Variable/G Run_smoothingMethod = SmMethod
    Variable/G Run_smoothingPoly = SmPoly
    Make/O/N=3 Run_dimSize = {DimSize(w,0), DimSize(w,1), DimSize(w,2)}
    Make/O/N=3 Run_dimOffset = {DimOffset(w,0), DimOffset(w,1), DimOffset(w,2)}
    Make/O/N=3 Run_dimDelta = {DimDelta(w,0), DimDelta(w,1), DimDelta(w,2)}
    Make/O/T/N=3 Run_dimUnits = {WaveUnits(w,0), WaveUnits(w,1), WaveUnits(w,2)}
    Make/O/N=(DimSize(w,2)) Run_windowLow = kStart
    Make/O/N=(DimSize(w,2)) Run_windowHigh = kEnd
    Make/O/N=(DimSize(w,2)) Run_indexLow = kStart
    Make/O/N=(DimSize(w,2)) Run_indexHigh = kEnd
    String/G Run_createdAt = Secs2Date(DateTime, 0) + " " + Secs2Time(DateTime, 3)
    SetDataFolder $oldDF

    return 0
End

// Build a graph title string for the overlay graph.
Function/S LJZ_EDCExtract_BuildGraphTitle(w, kStart, kEnd, baseName)
    Wave w
    Variable kStart, kEnd
    String baseName

    String nm
    if (strlen(baseName) > 0)
        nm = baseName
    else
        nm = NameOfWave(w)
    endif
    nm = LJZ_Extract_ShortenForTitle(nm, 60)

    Variable physK0 = DimOffset(w, 1) + kStart * DimDelta(w, 1)
    Variable physK1 = DimOffset(w, 1) + kEnd   * DimDelta(w, 1)

    String title
    sprintf title, "%s | k=[%.4g, %.4g] %s (idx %d-%d)", nm, physK0, physK1, WaveUnits(w, 1), kStart, kEnd
    return title
End

// Full EDC run: extract → smooth → display → push RunDF → return RunDF path.
Function/S LJZ_EDCExtract_RunFrom3DWave(w, k0, k1, baseName)
    Wave w
    Variable k0, k1
    String baseName

    LJZ_EDCExtract_EnsureDF()

    if (!LJZ_Extract_Is3DNumericWave(w))
        return ""
    endif

    Variable nK = DimSize(w, 1)
    Variable kStart = max(0, min(nK - 1, min(round(k0), round(k1))))
    Variable kEnd   = max(0, min(nK - 1, max(round(k0), round(k1))))

    String nm = CleanupName(NameOfWave(w), 0)
    if (strlen(nm) > 20)
        nm = nm[0, 19]
    endif
    String tag
    if (strlen(CleanupName(baseName, 0)) > 0)
        tag = CleanupName(baseName, 0)
    else
        tag = "EDC"
    endif
    String runDF = LJZ_EDCExtract_RunRoot() + ":" + nm + "_" + tag + "_k" + num2str(kStart) + "_" + num2str(kEnd) + ":"

    if (LJZ_EDCExtract_BuildRawEDCs(w, kStart, kEnd, runDF) != 0)
        DoAlert 0, "EDC 提取失败：无法从源 wave 构建原始 EDC。"
        return ""
    endif

    LJZ_EDCExtract_ApplySmoothing(runDF)
    LJZ_EDCExtract_RecordRunMeta(w, kStart, kEnd, runDF)

    // Push to EDCWB TargetDF for downstream fitting
    LJZ_Extract_PushRunDFToWorkbench(runDF, "root:Packages:ARPES_LJZ:EDCWB:TargetDF")

    NVAR evary = $(LJZ_EDCExtract_BaseDF() + ":evary")
    String title = LJZ_EDCExtract_BuildGraphTitle(w, kStart, kEnd, baseName)
    LJZ_Extract_BuildOverlayGraph(runDF, "edc_show", LJZ_EDCExtract_GraphName(), title, "Energy", evary)

    return runDF
End

// Re-smooth and re-display the last successful run without re-extracting.
Function LJZ_EDCExtract_ReShowCurrentRun()
    LJZ_EDCExtract_EnsureDF()

    SVAR runDF = $(LJZ_EDCExtract_BaseDF() + ":RunDF")
    SVAR bn    = $(LJZ_EDCExtract_BaseDF() + ":BaseName")
    NVAR evary = $(LJZ_EDCExtract_BaseDF() + ":evary")

    if (strlen(runDF) == 0 || !DataFolderExists(RemoveEnding(runDF, ":")))
        return -1
    endif

    LJZ_EDCExtract_ApplySmoothing(runDF)

    NVAR/Z ks = $(runDF + "Run_kStart")
    NVAR/Z ke = $(runDF + "Run_kEnd")
    String title = bn
    if (NVAR_Exists(ks) && NVAR_Exists(ke))
        sprintf title, "%s | k idx [%d, %d]", bn, round(ks), round(ke)
    endif
    LJZ_Extract_BuildOverlayGraph(runDF, "edc_show", LJZ_EDCExtract_GraphName(), title, "Energy", evary)

    return 0
End


// ============================================================================
//  Section 10. EDC Extract – user action wrappers
// ============================================================================

Function LJZ_EDCExtract_DoExtract()
    LJZ_EDCExtract_EnsureDF()

    SVAR sWave = $(LJZ_EDCExtract_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        DoAlert 0, "请先选择一个 3D wave。"
        return -1
    endif

    Wave/Z w = $sWave
    LJZ_Extract_PrintDimSanity(w, "EDC source")
    if (!LJZ_Extract_Is3DNumericWave(w))
        DoAlert 0, "当前选择不是有效的 3D wave（energy × k × stack）。"
        return -1
    endif

    NVAR k0      = $(LJZ_EDCExtract_BaseDF() + ":KIndex")
    NVAR k1      = $(LJZ_EDCExtract_BaseDF() + ":Kxe")
    NVAR usePhys = $(LJZ_EDCExtract_BaseDF() + ":UsePhysK")
    SVAR bn      = $(LJZ_EDCExtract_BaseDF() + ":BaseName")

    Variable kStart = round(k0)
    Variable kEnd   = round(k1)
    if (usePhys)
        if (LJZ_Extract_WindowPhysToIndex(DimOffset(w,1), DimDelta(w,1), DimSize(w,1), k0, k1, kStart, kEnd) != 0)
            Print "WARNING: EDC k window is empty after physical→index conversion. Extraction skipped."
            return -1
        endif
    endif

    String runDF = LJZ_EDCExtract_RunFrom3DWave(w, kStart, kEnd, bn)
    if (strlen(runDF) == 0)
        return -1
    endif

    LJZ_EDCExtract_RefreshTitleBoxes()
    return 0
End


// ============================================================================
//  Section 11. EDC Extract – panel
// ============================================================================

Function LJZ_EDCExtract()
    LJZ_EDCExtract_EnsureDF()
    LJZ_EDCExtract_RebuildWaveList()
    LJZ_EDCExtract_OpenPanel()
    LJZ_EDCExtract_RefreshTitleBoxes()
    return 0
End

Function LJZ_EDCExtract_OpenPanel()
    LJZ_EDCExtract_EnsureDF()

    String p = LJZ_EDCExtract_PanelName()
    DoWindow/F $p
    if (V_flag != 0)
        return 0
    endif

    NewPanel/N=$p /W=(120, 120, 800, 600) as "EDC Extract (LJZ)"

    // ---- top row: source DF ----
    GroupBox gbSrc, pos={6,6}, size={748,56}, title="Data Source"
    TitleBox tbSrcDF, pos={18,28}, size={52,18}, title="Source DF:", frame=0
    SetVariable svSourceDF, pos={80,26}, size={490,20}, title=" "
    SetVariable svSourceDF, value=root:ARPES_LJZ:EDCExtract:SourceDF, proc=LJZ_EDCExtract_SetVarProc
    CheckBox cbRec, pos={592,29}, size={78,16}, title="Recursive"
    CheckBox cbRec, variable=root:ARPES_LJZ:EDCExtract:Recursive, proc=LJZ_EDCExtract_CheckProc
    Button btScan, pos={686,24}, size={60,24}, title="Scan", proc=LJZ_EDCExtract_ButtonProc

    // ---- left: wave list ----
    GroupBox gbList, pos={6,70}, size={340,386}, title="Available 3D Waves"
    ListBox lbWave, pos={18,90}, size={318,358}
    ListBox lbWave, listWave=root:ARPES_LJZ:EDCExtract:LB_Disp
    ListBox lbWave, selWave=root:ARPES_LJZ:EDCExtract:LB_Sel, mode=1, proc=LJZ_EDCExtract_ListBoxProc

    // ---- right: extraction parameters ----
    GroupBox gbParam, pos={358,70}, size={396,154}, title="k Window (dim1)"
    TitleBox tbKMode, pos={370,92}, size={380,16}, title="Mode: 0=index  1=physical value", frame=0
    CheckBox cbPhysK, pos={370,114}, size={120,16}, title="Use physical k value"
    CheckBox cbPhysK, variable=root:ARPES_LJZ:EDCExtract:UsePhysK, proc=LJZ_EDCExtract_CheckProc

    SetVariable svK0, pos={370,138}, size={180,20}, title="k start"
    SetVariable svK0, variable=root:ARPES_LJZ:EDCExtract:KIndex, proc=LJZ_EDCExtract_SetVarProc
    SetVariable svK1, pos={564,138}, size={180,20}, title="k end"
    SetVariable svK1, variable=root:ARPES_LJZ:EDCExtract:Kxe, proc=LJZ_EDCExtract_SetVarProc

    SetVariable svEvary, pos={370,168}, size={180,20}, title="Vertical offset"
    SetVariable svEvary, variable=root:ARPES_LJZ:EDCExtract:evary, proc=LJZ_EDCExtract_SetVarProc
    SetVariable svBaseName, pos={564,168}, size={180,20}, title="Base name"
    SetVariable svBaseName, value=root:ARPES_LJZ:EDCExtract:BaseName, proc=LJZ_EDCExtract_SetVarProc

    // ---- right: smoothing ----
    GroupBox gbSm, pos={358,232}, size={396,130}, title="Smoothing"
    CheckBox cbSmEn, pos={370,254}, size={68,16}, title="Enable"
    CheckBox cbSmEn, variable=root:ARPES_LJZ:EDCExtract:SmEnable, proc=LJZ_EDCExtract_CheckProc
    PopupMenu pmSmMethod, pos={452,252}, size={180,20}, title="Method"
    PopupMenu pmSmMethod, mode=2, popvalue="Smooth", value="0 None;1 Smooth;2 Savitzky-Golay;"
    PopupMenu pmSmMethod, proc=LJZ_EDCExtract_PopupProc

    SetVariable svSmN, pos={370,282}, size={170,20}, title="N1 (points)"
    SetVariable svSmN, variable=root:ARPES_LJZ:EDCExtract:SmN, proc=LJZ_EDCExtract_SetVarProc
    SetVariable svSmN2, pos={554,282}, size={170,20}, title="N2 (2nd pass)"
    SetVariable svSmN2, variable=root:ARPES_LJZ:EDCExtract:SmN2, proc=LJZ_EDCExtract_SetVarProc
    SetVariable svSmPoly, pos={370,310}, size={170,20}, title="Poly order (SG)"
    SetVariable svSmPoly, variable=root:ARPES_LJZ:EDCExtract:SmPoly, proc=LJZ_EDCExtract_SetVarProc

    // ---- action buttons ----
    Button btExtract, pos={370,376}, size={120,32}, title="Extract EDC", proc=LJZ_EDCExtract_ButtonProc
    Button btReShow,  pos={504,376}, size={120,32}, title="Re-smooth",   proc=LJZ_EDCExtract_ButtonProc
    Button btFocusG,  pos={638,376}, size={110,32}, title="Focus Graph", proc=LJZ_EDCExtract_ButtonProc

    // ---- info boxes ----
    GroupBox gbInfo, pos={6,464}, size={748,80}, title="Status"
    TitleBox tbSel, pos={18,484}, size={720,18}, frame=0, title="Selected: "
    TitleBox tbRun, pos={18,508}, size={720,18}, frame=0, title="RunDF: "

    NVAR SmMethod = $(LJZ_EDCExtract_BaseDF() + ":SmMethod")
    PopupMenu pmSmMethod, win=$p, mode=(SmMethod + 1)

    LJZ_EDCExtract_RefreshTitleBoxes()
    return 0
End

Function LJZ_EDCExtract_RefreshTitleBoxes()
    String p = LJZ_EDCExtract_PanelName()
    if (WinType(p) == 0)
        return 0
    endif

    SVAR sWave = $(LJZ_EDCExtract_BaseDF() + ":WaveSel")
    SVAR runDF = $(LJZ_EDCExtract_BaseDF() + ":RunDF")

    TitleBox tbSel, win=$p, title="Selected: " + LJZ_Extract_ShortenForTitle(sWave, 100)
    TitleBox tbRun, win=$p, title="RunDF: "    + LJZ_Extract_ShortenForTitle(runDF, 100)
    return 0
End


// ============================================================================
//  Section 12. EDC Extract – callbacks
// ============================================================================

Function LJZ_EDCExtract_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    String c = ba.ctrlName

    if (CmpStr(c, "btScan") == 0)
        LJZ_EDCExtract_RebuildWaveList()
        LJZ_EDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(c, "btExtract") == 0)
        LJZ_EDCExtract_DoExtract()
        return 0
    endif

    if (CmpStr(c, "btReShow") == 0)
        LJZ_EDCExtract_ReShowCurrentRun()
        LJZ_EDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(c, "btFocusG") == 0)
        DoWindow/F $(LJZ_EDCExtract_GraphName())
        return 0
    endif

    return 0
End

Function LJZ_EDCExtract_PopupProc(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa

    if (pa.eventCode != 2)
        return 0
    endif

    if (CmpStr(pa.ctrlName, "pmSmMethod") == 0)
        NVAR SmMethod = $(LJZ_EDCExtract_BaseDF() + ":SmMethod")
        SmMethod = pa.popNum - 1
        LJZ_EDCExtract_ReShowCurrentRun()
        return 0
    endif

    return 0
End

Function LJZ_EDCExtract_SetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    if (sva.eventCode != 1 && sva.eventCode != 2 && sva.eventCode != 8)
        return 0
    endif

    String c = sva.ctrlName

    if (CmpStr(c, "svSourceDF") == 0)
        SVAR sDF = $(LJZ_EDCExtract_BaseDF() + ":SourceDF")
        sDF = LJZ_Extract_df_with_colon(sva.sval)
        LJZ_EDCExtract_RebuildWaveList()
        LJZ_EDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(c, "svSmN") == 0 || CmpStr(c, "svSmN2") == 0 || CmpStr(c, "svSmPoly") == 0 || CmpStr(c, "svEvary") == 0)
        LJZ_EDCExtract_ReShowCurrentRun()
        LJZ_EDCExtract_RefreshTitleBoxes()
        return 0
    endif

    LJZ_EDCExtract_RefreshTitleBoxes()
    return 0
End

Function LJZ_EDCExtract_CheckProc(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba

    if (cba.eventCode != 2)
        return 0
    endif

    String c = cba.ctrlName

    if (CmpStr(c, "cbRec") == 0)
        LJZ_EDCExtract_RebuildWaveList()
        LJZ_EDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(c, "cbSmEn") == 0)
        LJZ_EDCExtract_ReShowCurrentRun()
        LJZ_EDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(c, "cbPhysK") == 0)
        return 0
    endif

    return 0
End

Function LJZ_EDCExtract_ListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if (lba.eventCode != 4)
        return 0
    endif

    if (lba.row < 0)
        return 0
    endif

    LJZ_EDCExtract_SelectWaveRow(lba.row)
    LJZ_EDCExtract_RefreshTitleBoxes()
    return 0
End
