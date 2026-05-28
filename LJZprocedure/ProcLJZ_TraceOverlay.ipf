#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma DefaultTab={3,20,4}

// ============================================================================
//  ProcLJZ_TraceOverlay  (2026 rev-5)
//
//  Purpose:
//    Collect traces from existing graph windows into one target graph window.
//
//  Main features:
//    1) Source graph / target graph / trace list are all ListBox based.
//    2) Trace list supports local drop, source-graph removal, and persistent
//       custom order per source graph.
//    3) Appended traces are duplicated to root:ARPES_LJZ:TraceOverlay:OverlayData:
//       so that x scaling and y data transform can be controlled safely.
//    4) Optional Y standard-deviation/error wave transfer by naming convention.
//       Default candidates in same data folder:
//           yName + _sd / _std / _err / _sigma / _stderr
//       and common replacements:
//           edc_show_0 -> edc_sd_0 / edc_std_0 / edc_err_0 / edc_sigma_0
//           mdc_show_0 -> mdc_sd_0 / mdc_std_0 / mdc_err_0 / mdc_sigma_0
//    5) Axis preset, manual axis range, display offset, line size, color scheme.
//
//  Igor 8 compatibility notes:
//    - SetVariable uses value= for global string/numeric variables.
//    - CheckBox uses variable= for global numeric variables.
//    - AppendToGraph/W=... keeps /W as the first flag.
//    - ErrorBars/W=... keeps /W as the first flag.
//    - Reorder is implemented by editing ListBox waves; no ReorderTraces needed.
// ============================================================================

Menu "ARPES_LJZ"
    "2026TraceOverlay_LJZ", LJZ_TraceOverlay()
End


// ============================================================================
//  Section 0. Paths / state
// ============================================================================

Function/S LJZ_TO_BaseDF()
    return "root:ARPES_LJZ:TraceOverlay"
End

Function/S LJZ_TO_DataDF()
    return "root:ARPES_LJZ:TraceOverlay:OverlayData:"
End

Function/S LJZ_TO_DefaultTargetGraph()
    return "LJZ_TraceOverlay_Graph"
End

Function/S LJZ_TO_PanelName()
    return "LJZ_TraceOverlay_Panel"
End

Function/S LJZ_TO_df_with_colon(inStr)
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

Function LJZ_TO_EnsureStringVar(varName, defaultValue)
    String varName, defaultValue

    SVAR/Z sv = $varName
    if (!SVAR_Exists(sv))
        String/G $varName = defaultValue
    endif
    return 0
End

Function LJZ_TO_EnsureNumericVar(varName, defaultValue)
    String varName
    Variable defaultValue

    NVAR/Z nv = $varName
    if (!NVAR_Exists(nv))
        Variable/G $varName = defaultValue
    endif
    return 0
End

Function LJZ_TO_EnsureWaveText(wPath)
    String wPath

    Wave/T/Z wt = $wPath
    if (!WaveExists(wt))
        Make/O/T/N=0 $wPath
    endif
    return 0
End

Function LJZ_TO_EnsureWaveNum(wPath)
    String wPath

    Wave/Z wn = $wPath
    if (!WaveExists(wn))
        Make/O/N=0 $wPath = 0
    endif
    return 0
End

Function LJZ_TO_EnsureDF()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O $(LJZ_TO_BaseDF())
    NewDataFolder/O $(RemoveEnding(LJZ_TO_DataDF(), ":"))

    // ---- string scalars ----
    LJZ_TO_EnsureStringVar(LJZ_TO_BaseDF() + ":SourceGraph", "")
    LJZ_TO_EnsureStringVar(LJZ_TO_BaseDF() + ":TargetGraph", LJZ_TO_DefaultTargetGraph())
    LJZ_TO_EnsureStringVar(LJZ_TO_BaseDF() + ":TraceSel", "")
    LJZ_TO_EnsureStringVar(LJZ_TO_BaseDF() + ":FilterSrc", "")
    LJZ_TO_EnsureStringVar(LJZ_TO_BaseDF() + ":FilterTgt", "")
    LJZ_TO_EnsureStringVar(LJZ_TO_BaseDF() + ":FilterTrace", "")
    LJZ_TO_EnsureStringVar(LJZ_TO_BaseDF() + ":StdSuffixList", "_sd;_std;_err;_sigma;_stderr;")

    // ---- numeric scalars ----
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":SourceRow", -1)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":TargetRow", 0)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":TraceRow", -1)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":VisibleOnly", 1)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":PrefixTraceName", 1)

    // display style, not data transform
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":XOffset", 0)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":YOffset", 0)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":LineSize", 1)

    // axis label/range
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":XPreset", 0)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":YPreset", 0)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":UseXRange", 0)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":UseYRange", 0)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":XMin", NaN)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":XMax", NaN)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":YMin", NaN)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":YMax", NaN)

    // data transform at append time
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":UseManualXScale", 0)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":XScaleStart", 0)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":XScaleDelta", 1)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":UseYDataTransform", 0)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":YDataScale", 1)
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":YDataOffset", 0)

    // standard-deviation/error transfer
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":TransferStd", 1)

    // ColorMode: 0=none 1=rainbow 2=Tableau10 3=CoolWarm
    LJZ_TO_EnsureNumericVar(LJZ_TO_BaseDF() + ":ColorMode", 0)

    // ---- list-box waves (source) ----
    LJZ_TO_EnsureWaveText(LJZ_TO_BaseDF() + ":LB_SourceDisp")
    LJZ_TO_EnsureWaveText(LJZ_TO_BaseDF() + ":LB_SourcePath")
    LJZ_TO_EnsureWaveNum(LJZ_TO_BaseDF() + ":LB_SourceSel")

    // ---- list-box waves (target) ----
    LJZ_TO_EnsureWaveText(LJZ_TO_BaseDF() + ":LB_TargetDisp")
    LJZ_TO_EnsureWaveText(LJZ_TO_BaseDF() + ":LB_TargetPath")
    LJZ_TO_EnsureWaveNum(LJZ_TO_BaseDF() + ":LB_TargetSel")

    // ---- list-box waves (trace) ----
    LJZ_TO_EnsureWaveText(LJZ_TO_BaseDF() + ":LB_TraceDisp")
    LJZ_TO_EnsureWaveText(LJZ_TO_BaseDF() + ":LB_TracePath")
    LJZ_TO_EnsureWaveNum(LJZ_TO_BaseDF() + ":LB_TraceSel")

    return 0
End

Function/S LJZ_TO_ShortenForTitle(s, maxLen)
    String s
    Variable maxLen

    if (strlen(s) <= maxLen)
        return s
    endif
    return s[0, maxLen - 4] + "..."
End

// Returns 1 if the listbox selection value v means "selected".
Function LJZ_TO_SelectedBit(v)
    Variable v

    return ((v & 1) != 0 || (v & 8) != 0)
End

Function/S LJZ_TO_StateVarName(prefix, srcGraph)
    String prefix, srcGraph

    String nm = CleanupName(prefix + "_" + srcGraph, 0)
    if (strlen(nm) > 58)
        nm = nm[0, 57]
    endif
    return LJZ_TO_BaseDF() + ":" + nm
End

Function/S LJZ_TO_GetPerSourceString(prefix, srcGraph)
    String prefix, srcGraph

    String vName = LJZ_TO_StateVarName(prefix, srcGraph)
    LJZ_TO_EnsureStringVar(vName, "")
    SVAR s = $vName
    return s
End

Function LJZ_TO_SetPerSourceString(prefix, srcGraph, value)
    String prefix, srcGraph, value

    String vName = LJZ_TO_StateVarName(prefix, srcGraph)
    LJZ_TO_EnsureStringVar(vName, "")
    SVAR s = $vName
    s = value
    return 0
End


// ============================================================================
//  Section 1. Filter / list helpers
// ============================================================================

Function LJZ_TO_PassFilter(s, f)
    String s, f

    if (strlen(f) == 0)
        return 1
    endif
    return (strsearch(LowerStr(s), LowerStr(f), 0) >= 0)
End

Function/S LJZ_TO_RemoveListItemByName(listStr, item)
    String listStr, item

    String out = ""
    Variable i, n = ItemsInList(listStr, ";")
    for (i = 0; i < n; i += 1)
        String s = StringFromList(i, listStr, ";")
        if (CmpStr(s, item) != 0)
            out = AddListItem(s, out, ";", Inf)
        endif
    endfor
    return out
End

Function/S LJZ_TO_ReorderListBySavedOrder(listStr, orderStr)
    String listStr, orderStr

    if (strlen(orderStr) == 0)
        return listStr
    endif

    String out = ""
    Variable i, nOrder = ItemsInList(orderStr, ";")
    for (i = 0; i < nOrder; i += 1)
        String item = StringFromList(i, orderStr, ";")
        if (WhichListItem(item, listStr, ";", 0, 0) >= 0)
            if (WhichListItem(item, out, ";", 0, 0) < 0)
                out = AddListItem(item, out, ";", Inf)
            endif
        endif
    endfor

    Variable j, n = ItemsInList(listStr, ";")
    for (j = 0; j < n; j += 1)
        item = StringFromList(j, listStr, ";")
        if (WhichListItem(item, out, ";", 0, 0) < 0)
            out = AddListItem(item, out, ";", Inf)
        endif
    endfor

    return out
End


// ============================================================================
//  Section 2. Graph / trace list rebuild
// ============================================================================

Function/S LJZ_TO_NormalGraphList()
    String out = ""
    String all = WinList("*", ";", "WIN:1")   // graphs only
    Variable i, n = ItemsInList(all, ";")

    for (i = 0; i < n; i += 1)
        String g = StringFromList(i, all, ";")
        if (strlen(g) == 0)
            continue
        endif
        out = AddListItem(g, out, ";", Inf)
    endfor

    return out
End

Function LJZ_TO_RebuildGraphLists()
    LJZ_TO_EnsureDF()

    SVAR srcGraph = $(LJZ_TO_BaseDF() + ":SourceGraph")
    SVAR tgtGraph = $(LJZ_TO_BaseDF() + ":TargetGraph")
    SVAR filterSrc = $(LJZ_TO_BaseDF() + ":FilterSrc")
    SVAR filterTgt = $(LJZ_TO_BaseDF() + ":FilterTgt")
    NVAR srcRow = $(LJZ_TO_BaseDF() + ":SourceRow")
    NVAR tgtRow = $(LJZ_TO_BaseDF() + ":TargetRow")

    String graphList = LJZ_TO_NormalGraphList()

    // ---- source list ----
    String filtSrcList = ""
    Variable i, n = ItemsInList(graphList, ";")
    for (i = 0; i < n; i += 1)
        String g = StringFromList(i, graphList, ";")
        if (LJZ_TO_PassFilter(g, filterSrc))
            filtSrcList = AddListItem(g, filtSrcList, ";", Inf)
        endif
    endfor

    Variable nSrc = ItemsInList(filtSrcList, ";")
    Make/O/T/N=(nSrc) $(LJZ_TO_BaseDF() + ":LB_SourceDisp")
    Make/O/T/N=(nSrc) $(LJZ_TO_BaseDF() + ":LB_SourcePath")
    Make/O/N=(nSrc)   $(LJZ_TO_BaseDF() + ":LB_SourceSel") = 0

    Wave/T srcDisp = $(LJZ_TO_BaseDF() + ":LB_SourceDisp")
    Wave/T srcPath = $(LJZ_TO_BaseDF() + ":LB_SourcePath")
    Wave   srcSel  = $(LJZ_TO_BaseDF() + ":LB_SourceSel")

    Variable keepSrc = -1
    for (i = 0; i < nSrc; i += 1)
        g = StringFromList(i, filtSrcList, ";")
        srcPath[i] = g
        srcDisp[i] = g + "  (" + num2str(ItemsInList(TraceNameList(g, ";", 1), ";")) + " traces)"
        if (CmpStr(g, srcGraph) == 0)
            keepSrc = i
        endif
    endfor

    if (keepSrc < 0 && nSrc > 0)
        keepSrc = 0
    endif
    if (keepSrc >= 0 && nSrc > 0)
        srcSel[keepSrc] = 1
        srcGraph = srcPath[keepSrc]
        srcRow = keepSrc
    else
        srcGraph = ""
        srcRow = -1
    endif

    // ---- target list ----
    String defaultTarget = LJZ_TO_DefaultTargetGraph()
    String targetList = graphList
    if (WhichListItem(defaultTarget, targetList, ";", 0, 0) < 0)
        targetList = AddListItem(defaultTarget, targetList, ";", 0)
    endif

    String filtTgtList = ""
    n = ItemsInList(targetList, ";")
    for (i = 0; i < n; i += 1)
        g = StringFromList(i, targetList, ";")
        if (LJZ_TO_PassFilter(g, filterTgt))
            filtTgtList = AddListItem(g, filtTgtList, ";", Inf)
        endif
    endfor

    Variable nTgt = ItemsInList(filtTgtList, ";")
    Make/O/T/N=(nTgt) $(LJZ_TO_BaseDF() + ":LB_TargetDisp")
    Make/O/T/N=(nTgt) $(LJZ_TO_BaseDF() + ":LB_TargetPath")
    Make/O/N=(nTgt)   $(LJZ_TO_BaseDF() + ":LB_TargetSel") = 0

    Wave/T tgtDisp = $(LJZ_TO_BaseDF() + ":LB_TargetDisp")
    Wave/T tgtPath = $(LJZ_TO_BaseDF() + ":LB_TargetPath")
    Wave   tgtSel  = $(LJZ_TO_BaseDF() + ":LB_TargetSel")

    Variable keepTgt = -1
    for (i = 0; i < nTgt; i += 1)
        g = StringFromList(i, filtTgtList, ";")
        tgtPath[i] = g
        if (WinType(g) == 1)
            tgtDisp[i] = g + "  (existing, " + num2str(ItemsInList(TraceNameList(g, ";", 1), ";")) + " traces)"
        else
            tgtDisp[i] = g + "  (new)"
        endif
        if (CmpStr(g, tgtGraph) == 0)
            keepTgt = i
        endif
    endfor

    if (keepTgt < 0)
        keepTgt = WhichListItem(defaultTarget, filtTgtList, ";", 0, 0)
    endif
    if (keepTgt < 0 && nTgt > 0)
        keepTgt = 0
    endif
    if (keepTgt >= 0 && nTgt > 0)
        tgtSel[keepTgt] = 1
        tgtGraph = tgtPath[keepTgt]
        tgtRow = keepTgt
    else
        tgtGraph = defaultTarget
        tgtRow = -1
    endif

    LJZ_TO_RebuildTraceList()
    return 0
End

Function LJZ_TO_SetActiveSourceRow(row)
    Variable row

    LJZ_TO_EnsureDF()

    Wave/T srcPath = $(LJZ_TO_BaseDF() + ":LB_SourcePath")
    SVAR srcGraph = $(LJZ_TO_BaseDF() + ":SourceGraph")
    NVAR srcRow = $(LJZ_TO_BaseDF() + ":SourceRow")

    Variable n = numpnts(srcPath)
    if (row < 0 || row >= n)
        return -1
    endif

    srcGraph = srcPath[row]
    srcRow = row
    LJZ_TO_RebuildTraceList()
    LJZ_TO_RefreshTitleBoxes()
    return 0
End

Function LJZ_TO_SelectTargetRow(row)
    Variable row

    LJZ_TO_EnsureDF()

    Wave/T tgtPath = $(LJZ_TO_BaseDF() + ":LB_TargetPath")
    Wave   tgtSel  = $(LJZ_TO_BaseDF() + ":LB_TargetSel")
    SVAR tgtGraph  = $(LJZ_TO_BaseDF() + ":TargetGraph")
    NVAR tgtRow    = $(LJZ_TO_BaseDF() + ":TargetRow")

    Variable n = numpnts(tgtPath)
    if (row < 0 || row >= n)
        return -1
    endif

    tgtSel = 0
    tgtSel[row] = 1
    tgtGraph = tgtPath[row]
    tgtRow = row
    LJZ_TO_RefreshTitleBoxes()
    return 0
End

Function LJZ_TO_RebuildTraceList()
    LJZ_TO_EnsureDF()

    SVAR srcGraph  = $(LJZ_TO_BaseDF() + ":SourceGraph")
    SVAR traceSel  = $(LJZ_TO_BaseDF() + ":TraceSel")
    SVAR filterTr  = $(LJZ_TO_BaseDF() + ":FilterTrace")
    NVAR traceRow  = $(LJZ_TO_BaseDF() + ":TraceRow")
    NVAR visibleOnly = $(LJZ_TO_BaseDF() + ":VisibleOnly")

    String oldSelectedList = ""
    Wave/T/Z oldPath = $(LJZ_TO_BaseDF() + ":LB_TracePath")
    Wave/Z oldSel = $(LJZ_TO_BaseDF() + ":LB_TraceSel")
    if (WaveExists(oldPath) && WaveExists(oldSel))
        Variable oi, on = numpnts(oldPath)
        for (oi = 0; oi < on; oi += 1)
            if (LJZ_TO_SelectedBit(oldSel[oi]))
                oldSelectedList = AddListItem(oldPath[oi], oldSelectedList, ";", Inf)
            endif
        endfor
    endif

    if (strlen(srcGraph) == 0 || WinType(srcGraph) != 1)
        Make/O/T/N=0 $(LJZ_TO_BaseDF() + ":LB_TraceDisp")
        Make/O/T/N=0 $(LJZ_TO_BaseDF() + ":LB_TracePath")
        Make/O/N=0   $(LJZ_TO_BaseDF() + ":LB_TraceSel") = 0
        traceSel = ""
        traceRow = -1
        return -1
    endif

    Variable opt = 1
    if (visibleOnly)
        opt = 1 + 4
    endif

    String traceList = TraceNameList(srcGraph, ";", opt)
    String excludeList = LJZ_TO_GetPerSourceString("Exclude", srcGraph)
    String orderList = LJZ_TO_GetPerSourceString("Order", srcGraph)

    // apply filter and drop list
    String filtList = ""
    Variable i, n = ItemsInList(traceList, ";")
    for (i = 0; i < n; i += 1)
        String tn = StringFromList(i, traceList, ";")
        if (WhichListItem(tn, excludeList, ";", 0, 0) >= 0)
            continue
        endif
        if (LJZ_TO_PassFilter(tn, filterTr))
            filtList = AddListItem(tn, filtList, ";", Inf)
        endif
    endfor

    filtList = LJZ_TO_ReorderListBySavedOrder(filtList, orderList)

    Variable nTrace = ItemsInList(filtList, ";")
    Make/O/T/N=(nTrace) $(LJZ_TO_BaseDF() + ":LB_TraceDisp")
    Make/O/T/N=(nTrace) $(LJZ_TO_BaseDF() + ":LB_TracePath")
    Make/O/N=(nTrace)   $(LJZ_TO_BaseDF() + ":LB_TraceSel") = 0

    Wave/T trDisp = $(LJZ_TO_BaseDF() + ":LB_TraceDisp")
    Wave/T trPath = $(LJZ_TO_BaseDF() + ":LB_TracePath")
    Wave   trSel  = $(LJZ_TO_BaseDF() + ":LB_TraceSel")

    Variable prevRow = -1
    Variable firstSelected = -1
    for (i = 0; i < nTrace; i += 1)
        tn = StringFromList(i, filtList, ";")
        trPath[i] = tn

        Wave/Z yw = TraceNameToWaveRef(srcGraph, tn)
        Wave/Z xw = XWaveRefFromTrace(srcGraph, tn)

        String yName = "?"
        String xName = "calc"
        if (WaveExists(yw))
            yName = NameOfWave(yw)
        endif
        if (WaveExists(xw))
            xName = NameOfWave(xw)
        endif

        String stdName = LJZ_TO_FindStdWaveNameForY(yw)
        if (strlen(stdName) > 0)
            trDisp[i] = tn + "  |  Y=" + yName + "  X=" + xName + "  SD=" + stdName
        else
            trDisp[i] = tn + "  |  Y=" + yName + "  X=" + xName
        endif

        if (CmpStr(tn, traceSel) == 0)
            prevRow = i
        endif
        if (WhichListItem(tn, oldSelectedList, ";", 0, 0) >= 0)
            trSel[i] = 1
            if (firstSelected < 0)
                firstSelected = i
            endif
        endif
    endfor

    if (nTrace > 0)
        Variable selRow = -1
        if (prevRow >= 0)
            selRow = prevRow
        elseif (firstSelected >= 0)
            selRow = firstSelected
        else
            selRow = 0
            trSel[selRow] = 1
        endif
        traceSel = trPath[selRow]
        traceRow = selRow
    else
        traceSel = ""
        traceRow = -1
    endif

    return 0
End


// ============================================================================
//  Section 3. Trace-list local order / drop / removal
// ============================================================================

Function LJZ_TO_SaveTraceOrderForSource()
    LJZ_TO_EnsureDF()

    SVAR srcGraph = $(LJZ_TO_BaseDF() + ":SourceGraph")
    Wave/T trPath = $(LJZ_TO_BaseDF() + ":LB_TracePath")

    String order = ""
    Variable i, n = numpnts(trPath)
    for (i = 0; i < n; i += 1)
        order = AddListItem(trPath[i], order, ";", Inf)
    endfor

    if (strlen(srcGraph) > 0)
        LJZ_TO_SetPerSourceString("Order", srcGraph, order)
    endif
    return 0
End

Function LJZ_TO_MoveTraceRow(delta)
    Variable delta

    LJZ_TO_EnsureDF()

    NVAR traceRow = $(LJZ_TO_BaseDF() + ":TraceRow")
    SVAR traceSel = $(LJZ_TO_BaseDF() + ":TraceSel")
    Wave/T trDisp = $(LJZ_TO_BaseDF() + ":LB_TraceDisp")
    Wave/T trPath = $(LJZ_TO_BaseDF() + ":LB_TracePath")
    Wave   trSel  = $(LJZ_TO_BaseDF() + ":LB_TraceSel")

    Variable n = numpnts(trPath)
    Variable row = traceRow
    Variable newRow = row + delta

    if (row < 0 || row >= n || newRow < 0 || newRow >= n)
        return 0
    endif

    String tmpD = trDisp[row]
    String tmpP = trPath[row]
    Variable tmpS = trSel[row]

    trDisp[row] = trDisp[newRow]
    trPath[row] = trPath[newRow]
    trSel[row]  = trSel[newRow]

    trDisp[newRow] = tmpD
    trPath[newRow] = tmpP
    trSel[newRow]  = tmpS

    traceRow = newRow
    traceSel = trPath[newRow]
    trSel = 0
    trSel[newRow] = 1

    LJZ_TO_SaveTraceOrderForSource()
    ControlUpdate/W=$(LJZ_TO_PanelName()) lbTrace
    LJZ_TO_RefreshTitleBoxes()
    return 0
End

Function LJZ_TO_ReverseTraceList()
    LJZ_TO_EnsureDF()

    Wave/T trDisp = $(LJZ_TO_BaseDF() + ":LB_TraceDisp")
    Wave/T trPath = $(LJZ_TO_BaseDF() + ":LB_TracePath")
    Wave   trSel  = $(LJZ_TO_BaseDF() + ":LB_TraceSel")
    SVAR traceSel = $(LJZ_TO_BaseDF() + ":TraceSel")
    NVAR traceRow = $(LJZ_TO_BaseDF() + ":TraceRow")

    Variable n = numpnts(trPath)
    Variable i
    for (i = 0; i < floor(n/2); i += 1)
        Variable j = n - 1 - i
        String tmpD = trDisp[i]
        String tmpP = trPath[i]
        Variable tmpS = trSel[i]
        trDisp[i] = trDisp[j]
        trPath[i] = trPath[j]
        trSel[i] = trSel[j]
        trDisp[j] = tmpD
        trPath[j] = tmpP
        trSel[j] = tmpS
    endfor

    traceRow = -1
    for (i = 0; i < n; i += 1)
        if (LJZ_TO_SelectedBit(trSel[i]) && traceRow < 0)
            traceRow = i
            traceSel = trPath[i]
        endif
    endfor
    if (traceRow < 0 && n > 0)
        traceRow = 0
        traceSel = trPath[0]
        trSel[0] = 1
    endif

    LJZ_TO_SaveTraceOrderForSource()
    ControlUpdate/W=$(LJZ_TO_PanelName()) lbTrace
    LJZ_TO_RefreshTitleBoxes()
    return 0
End

Function LJZ_TO_DropSelectedTracesFromList()
    LJZ_TO_EnsureDF()

    SVAR srcGraph = $(LJZ_TO_BaseDF() + ":SourceGraph")
    Wave/T trPath = $(LJZ_TO_BaseDF() + ":LB_TracePath")
    Wave   trSel  = $(LJZ_TO_BaseDF() + ":LB_TraceSel")

    if (strlen(srcGraph) == 0)
        return 0
    endif

    String exclude = LJZ_TO_GetPerSourceString("Exclude", srcGraph)
    Variable i, n = numpnts(trPath)
    for (i = 0; i < n; i += 1)
        if (LJZ_TO_SelectedBit(trSel[i]))
            if (WhichListItem(trPath[i], exclude, ";", 0, 0) < 0)
                exclude = AddListItem(trPath[i], exclude, ";", Inf)
            endif
        endif
    endfor

    LJZ_TO_SetPerSourceString("Exclude", srcGraph, exclude)
    LJZ_TO_RebuildTraceList()
    ControlUpdate/W=$(LJZ_TO_PanelName()) lbTrace
    LJZ_TO_RefreshTitleBoxes()
    return 0
End

Function LJZ_TO_ResetTraceDrops()
    LJZ_TO_EnsureDF()

    SVAR srcGraph = $(LJZ_TO_BaseDF() + ":SourceGraph")
    if (strlen(srcGraph) > 0)
        LJZ_TO_SetPerSourceString("Exclude", srcGraph, "")
    endif

    LJZ_TO_RebuildTraceList()
    ControlUpdate/W=$(LJZ_TO_PanelName()) lbTrace
    LJZ_TO_RefreshTitleBoxes()
    return 0
End

Function LJZ_TO_RemoveSelectedTracesFromSourceGraph()
    LJZ_TO_EnsureDF()

    SVAR srcGraph = $(LJZ_TO_BaseDF() + ":SourceGraph")
    Wave/T trPath = $(LJZ_TO_BaseDF() + ":LB_TracePath")
    Wave   trSel  = $(LJZ_TO_BaseDF() + ":LB_TraceSel")

    if (strlen(srcGraph) == 0 || WinType(srcGraph) != 1)
        return 0
    endif

    DoAlert 1, "Remove selected traces from SOURCE graph? This does not kill waves, but it changes the source graph window."
    if (V_flag != 1)
        return 0
    endif

    Variable i, n = numpnts(trPath)
    for (i = n - 1; i >= 0; i -= 1)
        if (LJZ_TO_SelectedBit(trSel[i]))
            String tn = trPath[i]
            if (strlen(tn) > 0)
                RemoveFromGraph/W=$srcGraph $tn
            endif
        endif
    endfor

    LJZ_TO_RebuildGraphLists()
    ControlUpdate/W=$(LJZ_TO_PanelName()) lbSource
    ControlUpdate/W=$(LJZ_TO_PanelName()) lbTrace
    LJZ_TO_RefreshTitleBoxes()
    return 0
End


// ============================================================================
//  Section 4. Standard deviation / data copy helpers
// ============================================================================

Function/S LJZ_TO_FindStdWaveNameForY(yw)
    Wave/Z yw

    if (!WaveExists(yw))
        return ""
    endif

    SVAR suffixList = $(LJZ_TO_BaseDF() + ":StdSuffixList")

    String df = LJZ_TO_df_with_colon(GetWavesDataFolder(yw, 1))
    String yName = NameOfWave(yw)
    String cand = ""
    Variable i, n

    // --------------------------------------------------------------------
    // 1) OverlayData second-transfer case.
    //
    // In rev-4, appended traces are copied as
    //      <newTrace>_Y
    //      <newTrace>_X
    //      <newTrace>_SD
    // and the target graph displays <newTrace> while its Y wave is
    // <newTrace>_Y. If this overlay trace is later used as a new source,
    // the old name rule yName + "_sd" will search for
    //      <newTrace>_Y_sd
    // which is wrong. Try the paired <newTrace>_SD name first.
    // --------------------------------------------------------------------
    if (StringMatch(yName, "*_Y"))
        String baseOverlay = RemoveEnding(yName, "_Y")

        cand = baseOverlay + "_SD"
        Wave/Z swOverlay = $(df + cand)
        if (WaveExists(swOverlay))
            return cand
        endif

        cand = baseOverlay + "_sd"
        Wave/Z swOverlay2 = $(df + cand)
        if (WaveExists(swOverlay2))
            return cand
        endif

        cand = baseOverlay + "_std"
        Wave/Z swOverlay3 = $(df + cand)
        if (WaveExists(swOverlay3))
            return cand
        endif

        cand = baseOverlay + "_err"
        Wave/Z swOverlay4 = $(df + cand)
        if (WaveExists(swOverlay4))
            return cand
        endif

        cand = baseOverlay + "_sigma"
        Wave/Z swOverlay5 = $(df + cand)
        if (WaveExists(swOverlay5))
            return cand
        endif
    endif

    // --------------------------------------------------------------------
    // 2) Direct naming convention in the same data folder:
    //      yName + suffix
    // --------------------------------------------------------------------
    n = ItemsInList(suffixList, ";")
    for (i = 0; i < n; i += 1)
        String suf = StringFromList(i, suffixList, ";")
        cand = yName + suf
        Wave/Z sw = $(df + cand)
        if (WaveExists(sw))
            return cand
        endif
    endfor

    // --------------------------------------------------------------------
    // 3) Common MDC/EDC convention:
    //      edc_show_0 -> edc_sd_0 / edc_std_0 / edc_err_0 / edc_sigma_0
    //      mdc_show_0 -> mdc_sd_0 / mdc_std_0 / mdc_err_0 / mdc_sigma_0
    // --------------------------------------------------------------------
    String stem
    if (strsearch(yName, "_show_", 0) >= 0)
        stem = ReplaceString("_show_", yName, "_sd_")
        Wave/Z sw2 = $(df + stem)
        if (WaveExists(sw2))
            return stem
        endif

        stem = ReplaceString("_show_", yName, "_std_")
        Wave/Z sw3 = $(df + stem)
        if (WaveExists(sw3))
            return stem
        endif

        stem = ReplaceString("_show_", yName, "_err_")
        Wave/Z sw4 = $(df + stem)
        if (WaveExists(sw4))
            return stem
        endif

        stem = ReplaceString("_show_", yName, "_sigma_")
        Wave/Z sw5 = $(df + stem)
        if (WaveExists(sw5))
            return stem
        endif
    endif

    return ""
End

Function/WAVE LJZ_TO_FindStdWaveForY(yw)
    Wave/Z yw

    if (!WaveExists(yw))
        return $""
    endif

    String nm = LJZ_TO_FindStdWaveNameForY(yw)
    if (strlen(nm) == 0)
        return $""
    endif

    String df = LJZ_TO_df_with_colon(GetWavesDataFolder(yw, 1))
    Wave/Z sw = $(df + nm)
    return sw
End

Function/S LJZ_TO_SafeWaveName(base)
    String base

    String nm = CleanupName(base, 0)
    if (strlen(nm) == 0)
        nm = "tr"
    endif
    if (strlen(nm) > 55)
        nm = nm[0, 54]
    endif
    return nm
End

Function LJZ_TO_CopyTraceWaves(srcGraph, traceName, newTrace, yPathOut, xPathOut, sdPathOut)
    String srcGraph, traceName, newTrace
    String &yPathOut, &xPathOut, &sdPathOut

    LJZ_TO_EnsureDF()

    NVAR useManualX = $(LJZ_TO_BaseDF() + ":UseManualXScale")
    NVAR x0 = $(LJZ_TO_BaseDF() + ":XScaleStart")
    NVAR dx = $(LJZ_TO_BaseDF() + ":XScaleDelta")
    NVAR useYTrans = $(LJZ_TO_BaseDF() + ":UseYDataTransform")
    NVAR yScale = $(LJZ_TO_BaseDF() + ":YDataScale")
    NVAR yOffset = $(LJZ_TO_BaseDF() + ":YDataOffset")
    NVAR transferStd = $(LJZ_TO_BaseDF() + ":TransferStd")

    yPathOut = ""
    xPathOut = ""
    sdPathOut = ""

    Wave/Z yw = TraceNameToWaveRef(srcGraph, traceName)
    Wave/Z xw = XWaveRefFromTrace(srcGraph, traceName)
    if (!WaveExists(yw))
        return -1
    endif

    String dataDF = LJZ_TO_DataDF()
    String yPath = dataDF + LJZ_TO_SafeWaveName(newTrace + "_Y")
    Duplicate/O yw, $yPath
    Wave yCopy = $yPath

    if (useYTrans)
        yCopy = yScale * yCopy + yOffset
    endif

    if (useManualX)
        if (numtype(dx) != 0 || dx == 0)
            dx = 1
        endif
        SetScale/P x, x0, dx, "", yCopy
    else
        if (WaveExists(xw))
            String xPath = dataDF + LJZ_TO_SafeWaveName(newTrace + "_X")
            Duplicate/O xw, $xPath
            xPathOut = xPath
        endif
    endif

    if (transferStd)
        Wave/Z sw = LJZ_TO_FindStdWaveForY(yw)
        if (WaveExists(sw))
            String sPath = dataDF + LJZ_TO_SafeWaveName(newTrace + "_SD")
            Duplicate/O sw, $sPath
            Wave sCopy = $sPath
            if (useYTrans)
                sCopy = abs(yScale) * sCopy
            endif
            sdPathOut = sPath
        endif
    endif

    yPathOut = yPath
    return 0
End


// ============================================================================
//  Section 5. Axis presets / target styling
// ============================================================================

Function/S LJZ_TO_XAxisLabelFromPreset(preset)
    Variable preset

    switch (preset)
        case 1:
            return "Delay (ps)"
        case 2:
            return "Temperature (K)"
        case 3:
            return "E - EF (eV)"
        case 4:
            return "Energy (eV)"
        case 5:
            return "k (1/A)"
        case 6:
            return "Angle (deg)"
        case 7:
            return "Photon energy (eV)"
    endswitch
    return ""
End

Function/S LJZ_TO_YAxisLabelFromPreset(preset)
    Variable preset

    switch (preset)
        case 1:
            return "Intensity (a.u.)"
        case 2:
            return "Normalized intensity"
        case 3:
            return "MDC intensity (a.u.)"
        case 4:
            return "EDC intensity (a.u.)"
        case 5:
            return "Delta k (1/A)"
        case 6:
            return "Peak position"
        case 7:
            return "Peak width"
        case 8:
            return "Residual"
    endswitch
    return ""
End

Function LJZ_TO_ApplyAxisToTarget()
    LJZ_TO_EnsureDF()

    SVAR tgtGraph = $(LJZ_TO_BaseDF() + ":TargetGraph")
    NVAR xPreset = $(LJZ_TO_BaseDF() + ":XPreset")
    NVAR yPreset = $(LJZ_TO_BaseDF() + ":YPreset")
    NVAR useX = $(LJZ_TO_BaseDF() + ":UseXRange")
    NVAR useY = $(LJZ_TO_BaseDF() + ":UseYRange")
    NVAR xMin = $(LJZ_TO_BaseDF() + ":XMin")
    NVAR xMax = $(LJZ_TO_BaseDF() + ":XMax")
    NVAR yMin = $(LJZ_TO_BaseDF() + ":YMin")
    NVAR yMax = $(LJZ_TO_BaseDF() + ":YMax")

    if (strlen(tgtGraph) == 0 || WinType(tgtGraph) != 1)
        return -1
    endif

    String xLab = LJZ_TO_XAxisLabelFromPreset(xPreset)
    String yLab = LJZ_TO_YAxisLabelFromPreset(yPreset)

    if (strlen(xLab) > 0)
        Label/W=$tgtGraph bottom xLab
    endif
    if (strlen(yLab) > 0)
        Label/W=$tgtGraph left yLab
    endif

    if (useX && numtype(xMin) == 0 && numtype(xMax) == 0)
        SetAxis/W=$tgtGraph bottom xMin, xMax
    endif
    if (useY && numtype(yMin) == 0 && numtype(yMax) == 0)
        SetAxis/W=$tgtGraph left yMin, yMax
    endif

    ModifyGraph/W=$tgtGraph mirror=2
    return 0
End

Function LJZ_TO_AutoAxisTarget()
    LJZ_TO_EnsureDF()

    SVAR tgtGraph = $(LJZ_TO_BaseDF() + ":TargetGraph")
    if (strlen(tgtGraph) == 0 || WinType(tgtGraph) != 1)
        return -1
    endif

    SetAxis/A/W=$tgtGraph bottom
    SetAxis/A/W=$tgtGraph left
    return 0
End


// ============================================================================
//  Section 6. Color utilities
// ============================================================================

Function LJZ_TO_GetTraceColor(i, n, colorMode, rOut, gOut, bOut)
    Variable i, n, colorMode
    Variable &rOut, &gOut, &bOut

    rOut = 0
    gOut = 0
    bOut = 0

    if (colorMode == 0)
        rOut = -1
        gOut = -1
        bOut = -1
        return 0
    endif

    Variable total = max(n, 1)
    Variable frac = 0
    if (total > 1)
        frac = i / (total - 1)
    endif

    if (colorMode == 1)
        Variable h = frac * 300
        Variable ss = 0.85
        Variable vv = 0.92
        Variable hi = floor(h / 60)
        Variable f = h / 60 - hi
        Variable p = vv * (1 - ss)
        Variable q = vv * (1 - ss * f)
        Variable tv = vv * (1 - ss * (1 - f))
        Variable r, g, b
        switch (hi)
            case 0:
                r = vv; g = tv; b = p
                break
            case 1:
                r = q; g = vv; b = p
                break
            case 2:
                r = p; g = vv; b = tv
                break
            case 3:
                r = p; g = q; b = vv
                break
            case 4:
                r = tv; g = p; b = vv
                break
            default:
                r = vv; g = p; b = q
                break
        endswitch
        rOut = round(r * 65535)
        gOut = round(g * 65535)
        bOut = round(b * 65535)
        return 0
    endif

    if (colorMode == 2)
        Make/FREE/N=(10,3) pal
        pal[0][0]=31;  pal[0][1]=119; pal[0][2]=180
        pal[1][0]=255; pal[1][1]=127; pal[1][2]=14
        pal[2][0]=44;  pal[2][1]=160; pal[2][2]=44
        pal[3][0]=214; pal[3][1]=39;  pal[3][2]=40
        pal[4][0]=148; pal[4][1]=103; pal[4][2]=189
        pal[5][0]=140; pal[5][1]=86;  pal[5][2]=75
        pal[6][0]=227; pal[6][1]=119; pal[6][2]=194
        pal[7][0]=127; pal[7][1]=127; pal[7][2]=127
        pal[8][0]=188; pal[8][1]=189; pal[8][2]=34
        pal[9][0]=23;  pal[9][1]=190; pal[9][2]=207
        Variable idx = mod(i, 10)
        rOut = round(pal[idx][0] / 255 * 65535)
        gOut = round(pal[idx][1] / 255 * 65535)
        bOut = round(pal[idx][2] / 255 * 65535)
        return 0
    endif

    if (colorMode == 3)
        Variable blue_r = 0.230, blue_g = 0.299, blue_b = 0.754
        Variable red_r  = 0.706, red_g  = 0.016, red_b  = 0.150
        rOut = round((blue_r + frac*(red_r - blue_r)) * 65535)
        gOut = round((blue_g + frac*(red_g - blue_g)) * 65535)
        bOut = round((blue_b + frac*(red_b - blue_b)) * 65535)
        return 0
    endif

    return 0
End

Function LJZ_TO_RecolorTarget()
    LJZ_TO_EnsureDF()

    SVAR tgtGraph = $(LJZ_TO_BaseDF() + ":TargetGraph")
    NVAR colorMode = $(LJZ_TO_BaseDF() + ":ColorMode")

    if (strlen(tgtGraph) == 0 || WinType(tgtGraph) != 1)
        return -1
    endif
    if (colorMode == 0)
        return 0
    endif

    String list = TraceNameList(tgtGraph, ";", 1)
    Variable n = ItemsInList(list, ";")
    Variable i
    for (i = 0; i < n; i += 1)
        String tn = StringFromList(i, list, ";")
        if (strlen(tn) == 0)
            continue
        endif
        Variable rr, gg, bb
        LJZ_TO_GetTraceColor(i, n, colorMode, rr, gg, bb)
        if (rr >= 0)
            ModifyGraph/W=$tgtGraph rgb($tn)=(rr, gg, bb)
        endif
    endfor
    return 0
End

Function LJZ_TO_RestyleTarget()
    LJZ_TO_EnsureDF()

    SVAR tgtGraph = $(LJZ_TO_BaseDF() + ":TargetGraph")
    NVAR xOff = $(LJZ_TO_BaseDF() + ":XOffset")
    NVAR yOff = $(LJZ_TO_BaseDF() + ":YOffset")
    NVAR lSize = $(LJZ_TO_BaseDF() + ":LineSize")
    NVAR colorMode = $(LJZ_TO_BaseDF() + ":ColorMode")

    if (strlen(tgtGraph) == 0 || WinType(tgtGraph) != 1)
        return -1
    endif

    String traceList = TraceNameList(tgtGraph, ";", 1)
    Variable i, n = ItemsInList(traceList, ";")
    for (i = 0; i < n; i += 1)
        String tn = StringFromList(i, traceList, ";")
        if (strlen(tn) == 0)
            continue
        endif
        ModifyGraph/W=$tgtGraph mode($tn)=0
        ModifyGraph/W=$tgtGraph lsize($tn)=lSize
        ModifyGraph/W=$tgtGraph offset($tn)={i * xOff, i * yOff}
        Variable rr, gg, bb
        LJZ_TO_GetTraceColor(i, n, colorMode, rr, gg, bb)
        if (rr >= 0)
            ModifyGraph/W=$tgtGraph rgb($tn)=(rr, gg, bb)
        endif
    endfor

    ModifyGraph/W=$tgtGraph mirror=2
    return 0
End


// ============================================================================
//  Section 7. Append / clear operations
// ============================================================================

Function/S LJZ_TO_MakeTraceBaseName(srcGraph, traceName)
    String srcGraph, traceName

    NVAR prefix = $(LJZ_TO_BaseDF() + ":PrefixTraceName")

    String s
    if (prefix)
        s = srcGraph + "_" + traceName
    else
        s = traceName
    endif

    s = ReplaceString("'", s, "")
    s = ReplaceString("#", s, "_")
    s = CleanupName(s, 0)
    if (strlen(s) == 0)
        s = "tr"
    endif
    if (strlen(s) > 45)
        s = s[0, 44]
    endif
    return s
End

Function/S LJZ_TO_UniqueTraceName(tgtGraph, baseName)
    String tgtGraph, baseName

    String tn = CleanupName(baseName, 0)
    if (strlen(tn) == 0)
        tn = "tr"
    endif

    String list = ""
    if (WinType(tgtGraph) == 1)
        list = TraceNameList(tgtGraph, ";", 1)
    endif

    if (WhichListItem(tn, list, ";", 0, 0) < 0)
        return tn
    endif

    Variable i = 1
    do
        String trial = tn + "_" + num2str(i)
        if (WhichListItem(trial, list, ";", 0, 0) < 0)
            return trial
        endif
        i += 1
    while (i < 100000)

    return tn + "_x"
End

Function LJZ_TO_AppendOneTrace(srcGraph, traceName, ordinal)
    String srcGraph, traceName
    Variable ordinal

    LJZ_TO_EnsureDF()

    SVAR tgtGraph = $(LJZ_TO_BaseDF() + ":TargetGraph")
    NVAR xOff = $(LJZ_TO_BaseDF() + ":XOffset")
    NVAR yOff = $(LJZ_TO_BaseDF() + ":YOffset")

    if (strlen(srcGraph) == 0 || WinType(srcGraph) != 1)
        return -1
    endif
    if (strlen(tgtGraph) == 0)
        tgtGraph = LJZ_TO_DefaultTargetGraph()
    endif

    Wave/Z yw0 = TraceNameToWaveRef(srcGraph, traceName)
    if (!WaveExists(yw0))
        Print "TraceOverlay: skipped non-wave trace: " + srcGraph + " / " + traceName
        return -1
    endif

    String base = LJZ_TO_MakeTraceBaseName(srcGraph, traceName)
    String newTrace = LJZ_TO_UniqueTraceName(tgtGraph, base)

    String yPath = ""
    String xPath = ""
    String sdPath = ""
    if (LJZ_TO_CopyTraceWaves(srcGraph, traceName, newTrace, yPath, xPath, sdPath) != 0)
        Print "TraceOverlay: failed to copy trace waves: " + srcGraph + " / " + traceName
        return -1
    endif

    Wave yCopy = $yPath

    if (WinType(tgtGraph) != 1)
        if (strlen(xPath) > 0)
            Wave xCopy = $xPath
            Display/N=$tgtGraph yCopy/TN=$newTrace vs xCopy
        else
            Display/N=$tgtGraph yCopy/TN=$newTrace
        endif
        DoWindow/T $tgtGraph, "Trace Overlay"
    else
        if (strlen(xPath) > 0)
            Wave xCopy2 = $xPath
            AppendToGraph/W=$tgtGraph yCopy/TN=$newTrace vs xCopy2
        else
            AppendToGraph/W=$tgtGraph yCopy/TN=$newTrace
        endif
    endif

    if (strlen(sdPath) > 0)
        Wave sdCopy = $sdPath
        ErrorBars/W=$tgtGraph $newTrace, Y wave=(sdCopy,sdCopy)
    endif

    ModifyGraph/W=$tgtGraph offset($newTrace)={ordinal * xOff, ordinal * yOff}
    DoWindow/F $tgtGraph
    return 0
End

Function LJZ_TO_TargetTraceCount()
    LJZ_TO_EnsureDF()
    SVAR tgtGraph = $(LJZ_TO_BaseDF() + ":TargetGraph")

    if (strlen(tgtGraph) == 0 || WinType(tgtGraph) != 1)
        return 0
    endif

    return ItemsInList(TraceNameList(tgtGraph, ";", 1), ";")
End

Function LJZ_TO_AddSelectedTraces()
    LJZ_TO_EnsureDF()

    SVAR srcGraph = $(LJZ_TO_BaseDF() + ":SourceGraph")
    Wave/T trPath = $(LJZ_TO_BaseDF() + ":LB_TracePath")
    Wave   trSel  = $(LJZ_TO_BaseDF() + ":LB_TraceSel")

    Variable n = numpnts(trPath)
    if (n <= 0)
        return -1
    endif

    Variable count = LJZ_TO_TargetTraceCount()
    Variable i, nAdded = 0
    for (i = 0; i < n; i += 1)
        if (!LJZ_TO_SelectedBit(trSel[i]))
            continue
        endif
        if (LJZ_TO_AppendOneTrace(srcGraph, trPath[i], count + nAdded) == 0)
            nAdded += 1
        endif
    endfor

    LJZ_TO_ApplyAxisToTarget()
    LJZ_TO_RestyleTarget()
    LJZ_TO_RebuildGraphLists()
    LJZ_TO_RefreshTitleBoxes()
    return nAdded
End

Function LJZ_TO_AddCurrentSourceAll()
    LJZ_TO_EnsureDF()

    Wave/T trPath = $(LJZ_TO_BaseDF() + ":LB_TracePath")
    Wave   trSel  = $(LJZ_TO_BaseDF() + ":LB_TraceSel")

    Variable i, n = numpnts(trPath)
    for (i = 0; i < n; i += 1)
        trSel[i] = 1
    endfor
    ControlUpdate/W=$(LJZ_TO_PanelName()) lbTrace

    return LJZ_TO_AddSelectedTraces()
End

Function LJZ_TO_AddAllTracesFromGraph(srcGraph)
    String srcGraph

    LJZ_TO_EnsureDF()

    NVAR visibleOnly = $(LJZ_TO_BaseDF() + ":VisibleOnly")
    SVAR tgtGraph = $(LJZ_TO_BaseDF() + ":TargetGraph")

    if (strlen(srcGraph) == 0 || WinType(srcGraph) != 1)
        return 0
    endif
    if (CmpStr(srcGraph, tgtGraph) == 0)
        Print "TraceOverlay: skipped target graph as source: " + srcGraph
        return 0
    endif

    Variable opt = 1
    if (visibleOnly)
        opt = 1 + 4
    endif

    String traceList = TraceNameList(srcGraph, ";", opt)
    String excludeList = LJZ_TO_GetPerSourceString("Exclude", srcGraph)
    String orderList = LJZ_TO_GetPerSourceString("Order", srcGraph)

    String cleanList = ""
    Variable i, n = ItemsInList(traceList, ";")
    for (i = 0; i < n; i += 1)
        String tn = StringFromList(i, traceList, ";")
        if (WhichListItem(tn, excludeList, ";", 0, 0) < 0)
            cleanList = AddListItem(tn, cleanList, ";", Inf)
        endif
    endfor
    cleanList = LJZ_TO_ReorderListBySavedOrder(cleanList, orderList)

    Variable count = LJZ_TO_TargetTraceCount()
    Variable nAdded = 0
    n = ItemsInList(cleanList, ";")
    for (i = 0; i < n; i += 1)
        tn = StringFromList(i, cleanList, ";")
        if (strlen(tn) == 0)
            continue
        endif
        if (LJZ_TO_AppendOneTrace(srcGraph, tn, count + nAdded) == 0)
            nAdded += 1
        endif
    endfor

    return nAdded
End

Function LJZ_TO_AddSelectedSourcesAll()
    LJZ_TO_EnsureDF()

    Wave/T srcPath = $(LJZ_TO_BaseDF() + ":LB_SourcePath")
    Wave   srcSel  = $(LJZ_TO_BaseDF() + ":LB_SourceSel")

    Variable i, n = numpnts(srcPath)
    Variable total = 0

    for (i = 0; i < n; i += 1)
        if (!LJZ_TO_SelectedBit(srcSel[i]))
            continue
        endif
        total += LJZ_TO_AddAllTracesFromGraph(srcPath[i])
    endfor

    LJZ_TO_ApplyAxisToTarget()
    LJZ_TO_RestyleTarget()
    LJZ_TO_RebuildGraphLists()
    LJZ_TO_RefreshTitleBoxes()
    return total
End

Function LJZ_TO_ClearTarget()
    LJZ_TO_EnsureDF()

    SVAR tgtGraph = $(LJZ_TO_BaseDF() + ":TargetGraph")
    if (strlen(tgtGraph) == 0 || WinType(tgtGraph) != 1)
        return 0
    endif

    String list = TraceNameList(tgtGraph, ";", 1)
    Variable i, n = ItemsInList(list, ";")
    for (i = n - 1; i >= 0; i -= 1)
        String tn = StringFromList(i, list, ";")
        if (strlen(tn) > 0)
            RemoveFromGraph/W=$tgtGraph $tn
        endif
    endfor

    LJZ_TO_RebuildGraphLists()
    LJZ_TO_RefreshTitleBoxes()
    return 0
End


// ============================================================================
//  Section 8. Panel
// ============================================================================

Function LJZ_TraceOverlay()
    LJZ_TO_EnsureDF()
    LJZ_TO_RebuildGraphLists()
    LJZ_TO_OpenPanel()
    LJZ_TO_RefreshTitleBoxes()
    return 0
End

Function LJZ_TO_OpenPanel()
    LJZ_TO_EnsureDF()

    String p = LJZ_TO_PanelName()
    DoWindow/F $p
    if (V_flag != 0)
        return 0
    endif

    NewPanel/N=$p /W=(60,50,1160,830) as "Trace Overlay (LJZ 2026 rev-4)"
    ModifyPanel frameStyle=1

    // =====================================================================
    //  Source Graphs block
    // =====================================================================
    GroupBox gbSrc, win=$p, pos={8,6}, size={308,272}, title="Source Graphs"

    SetVariable svFilterSrc, win=$p, pos={18,26}, size={278,20}, title="Filter:"
    SetVariable svFilterSrc, value=root:ARPES_LJZ:TraceOverlay:FilterSrc
    SetVariable svFilterSrc, proc=LJZ_TO_FilterSetVarProc

    ListBox lbSource, win=$p, pos={18,52}, size={278,186}
    ListBox lbSource, listWave=root:ARPES_LJZ:TraceOverlay:LB_SourceDisp
    ListBox lbSource, selWave=root:ARPES_LJZ:TraceOverlay:LB_SourceSel
    ListBox lbSource, mode=4, proc=LJZ_TO_SourceListBoxProc

    Button btRefreshGraphs, win=$p, pos={18,244}, size={72,26}, title="Refresh", proc=LJZ_TO_ButtonProc
    Button btTopSource,     win=$p, pos={96,244}, size={72,26}, title="Use Top", proc=LJZ_TO_ButtonProc
    Button btSelAllSrc,     win=$p, pos={174,244},size={68,26}, title="Sel All",  proc=LJZ_TO_ButtonProc
    Button btSelNoneSrc,    win=$p, pos={248,244},size={68,26}, title="Sel None", proc=LJZ_TO_ButtonProc

    // =====================================================================
    //  Target Graph block
    // =====================================================================
    GroupBox gbTgt, win=$p, pos={324,6}, size={308,272}, title="Target Graph"

    SetVariable svFilterTgt, win=$p, pos={334,26}, size={278,20}, title="Filter:"
    SetVariable svFilterTgt, value=root:ARPES_LJZ:TraceOverlay:FilterTgt
    SetVariable svFilterTgt, proc=LJZ_TO_FilterSetVarProc

    ListBox lbTarget, win=$p, pos={334,52}, size={278,186}
    ListBox lbTarget, listWave=root:ARPES_LJZ:TraceOverlay:LB_TargetDisp
    ListBox lbTarget, selWave=root:ARPES_LJZ:TraceOverlay:LB_TargetSel
    ListBox lbTarget, mode=1, proc=LJZ_TO_TargetListBoxProc

    Button btTopTarget,  win=$p, pos={334,244},size={72,26}, title="Use Top", proc=LJZ_TO_ButtonProc
    Button btFocusTarget,win=$p, pos={412,244},size={72,26}, title="Focus",   proc=LJZ_TO_ButtonProc
    Button btClearTarget,win=$p, pos={490,244},size={72,26}, title="Clear",   proc=LJZ_TO_ButtonProc

    // =====================================================================
    //  Right settings column
    // =====================================================================

    GroupBox gbAxis, win=$p, pos={640,6}, size={452,180}, title="Axis Presets"
    PopupMenu pmX, win=$p, pos={658,28}, size={396,22}, title="X axis"
    PopupMenu pmX, value="Keep;Delay (ps);Temperature (K);E - EF (eV);Energy (eV);k (1/A);Angle (deg);Photon energy (eV);"
    PopupMenu pmX, proc=LJZ_TO_PopupProc

    PopupMenu pmY, win=$p, pos={658,56}, size={396,22}, title="Y axis"
    PopupMenu pmY, value="Keep;Intensity (a.u.);Normalized intensity;MDC intensity;EDC intensity;Delta k;Peak position;Peak width;Residual;"
    PopupMenu pmY, proc=LJZ_TO_PopupProc

    CheckBox cbXRange, win=$p, pos={658,88}, size={58,16}, title="x range"
    CheckBox cbXRange, variable=root:ARPES_LJZ:TraceOverlay:UseXRange, proc=LJZ_TO_CheckProc
    SetVariable svXMin, win=$p, pos={724,84}, size={150,20}, title="min"
    SetVariable svXMin, value=root:ARPES_LJZ:TraceOverlay:XMin, proc=LJZ_TO_SetVarProc
    SetVariable svXMax, win=$p, pos={884,84}, size={150,20}, title="max"
    SetVariable svXMax, value=root:ARPES_LJZ:TraceOverlay:XMax, proc=LJZ_TO_SetVarProc

    CheckBox cbYRange, win=$p, pos={658,114}, size={58,16}, title="y range"
    CheckBox cbYRange, variable=root:ARPES_LJZ:TraceOverlay:UseYRange, proc=LJZ_TO_CheckProc
    SetVariable svYMin, win=$p, pos={724,110}, size={150,20}, title="min"
    SetVariable svYMin, value=root:ARPES_LJZ:TraceOverlay:YMin, proc=LJZ_TO_SetVarProc
    SetVariable svYMax, win=$p, pos={884,110}, size={150,20}, title="max"
    SetVariable svYMax, value=root:ARPES_LJZ:TraceOverlay:YMax, proc=LJZ_TO_SetVarProc

    Button btApplyAxis, win=$p, pos={658,142}, size={176,30}, title="Apply Axis", proc=LJZ_TO_ButtonProc
    Button btAutoAxis,  win=$p, pos={850,142}, size={176,30}, title="Auto Axis",  proc=LJZ_TO_ButtonProc

    GroupBox gbStyle, win=$p, pos={640,194}, size={452,104}, title="Display Offset / Style"
    SetVariable svXOff,    win=$p, pos={658,216}, size={176,20}, title="x offset"
    SetVariable svXOff,    value=root:ARPES_LJZ:TraceOverlay:XOffset, proc=LJZ_TO_SetVarProc
    SetVariable svYOff,    win=$p, pos={850,216}, size={176,20}, title="y offset"
    SetVariable svYOff,    value=root:ARPES_LJZ:TraceOverlay:YOffset, proc=LJZ_TO_SetVarProc
    SetVariable svLineSize,win=$p, pos={658,244}, size={176,20}, title="line size"
    SetVariable svLineSize,value=root:ARPES_LJZ:TraceOverlay:LineSize, proc=LJZ_TO_SetVarProc
    Button btRestyle,      win=$p, pos={850,240}, size={176,30}, title="Restyle",  proc=LJZ_TO_ButtonProc

    GroupBox gbScale, win=$p, pos={640,306}, size={452,170}, title="Data Scale / Std Transfer"
    CheckBox cbManualX, win=$p, pos={658,328}, size={92,16}, title="manual x scale"
    CheckBox cbManualX, variable=root:ARPES_LJZ:TraceOverlay:UseManualXScale, proc=LJZ_TO_CheckProc
    SetVariable svXScaleStart, win=$p, pos={760,324}, size={128,20}, title="x0"
    SetVariable svXScaleStart, value=root:ARPES_LJZ:TraceOverlay:XScaleStart, proc=LJZ_TO_SetVarProc
    SetVariable svXScaleDelta, win=$p, pos={900,324}, size={128,20}, title="dx"
    SetVariable svXScaleDelta, value=root:ARPES_LJZ:TraceOverlay:XScaleDelta, proc=LJZ_TO_SetVarProc

    CheckBox cbYDataTrans, win=$p, pos={658,354}, size={104,16}, title="manual y data"
    CheckBox cbYDataTrans, variable=root:ARPES_LJZ:TraceOverlay:UseYDataTransform, proc=LJZ_TO_CheckProc
    SetVariable svYDataScale, win=$p, pos={760,350}, size={128,20}, title="scale"
    SetVariable svYDataScale, value=root:ARPES_LJZ:TraceOverlay:YDataScale, proc=LJZ_TO_SetVarProc
    SetVariable svYDataOffset, win=$p, pos={900,350}, size={128,20}, title="offset"
    SetVariable svYDataOffset, value=root:ARPES_LJZ:TraceOverlay:YDataOffset, proc=LJZ_TO_SetVarProc

    CheckBox cbTransferStd, win=$p, pos={658,382}, size={92,16}, title="transfer SD"
    CheckBox cbTransferStd, variable=root:ARPES_LJZ:TraceOverlay:TransferStd, proc=LJZ_TO_CheckProc
    SetVariable svStdSuffix, win=$p, pos={760,378}, size={268,20}, title="suffix"
    SetVariable svStdSuffix, value=root:ARPES_LJZ:TraceOverlay:StdSuffixList, proc=LJZ_TO_SetVarProc

    TitleBox tbScaleHint, win=$p, pos={658,406}, size={410,48}, frame=0
    TitleBox tbScaleHint, title="manual x/y applies only to newly appended copied waves. SD is searched in the Y-wave data folder."

    GroupBox gbColor, win=$p, pos={640,484}, size={452,78}, title="Color Scheme"
    PopupMenu pmColor, win=$p, pos={658,506}, size={260,22}, title="Scheme"
    PopupMenu pmColor, value="None (auto);Rainbow;Tableau 10;Cool-to-Warm;"
    PopupMenu pmColor, proc=LJZ_TO_PopupProc
    Button btRecolor, win=$p, pos={930,504}, size={96,26}, title="Recolor", proc=LJZ_TO_ButtonProc

    GroupBox gbBatch, win=$p, pos={640,570}, size={452,58}, title="Batch"
    Button btAddSelectedSources, win=$p, pos={658,592}, size={368,28}
    Button btAddSelectedSources, title="Add All Traces from Selected Source Graphs"
    Button btAddSelectedSources, proc=LJZ_TO_ButtonProc

    // =====================================================================
    //  Trace list block
    // =====================================================================
    GroupBox gbTrace, win=$p, pos={8,286}, size={624,330}, title="Traces in Active Source Graph"

    SetVariable svFilterTrace, win=$p, pos={18,306}, size={600,20}, title="Filter:"
    SetVariable svFilterTrace, value=root:ARPES_LJZ:TraceOverlay:FilterTrace
    SetVariable svFilterTrace, proc=LJZ_TO_FilterSetVarProc

    ListBox lbTrace, win=$p, pos={18,332}, size={600,184}
    ListBox lbTrace, listWave=root:ARPES_LJZ:TraceOverlay:LB_TraceDisp
    ListBox lbTrace, selWave=root:ARPES_LJZ:TraceOverlay:LB_TraceSel
    ListBox lbTrace, mode=4, proc=LJZ_TO_TraceListBoxProc

    CheckBox cbVisible, win=$p, pos={18,524}, size={82,18}, title="visible only"
    CheckBox cbVisible, variable=root:ARPES_LJZ:TraceOverlay:VisibleOnly, proc=LJZ_TO_CheckProc
    CheckBox cbPrefix,  win=$p, pos={112,524},size={92,18}, title="prefix names"
    CheckBox cbPrefix,  variable=root:ARPES_LJZ:TraceOverlay:PrefixTraceName, proc=LJZ_TO_CheckProc

    Button btTraceUp,     win=$p, pos={218,520}, size={58,26}, title="Up",       proc=LJZ_TO_ButtonProc
    Button btTraceDown,   win=$p, pos={282,520}, size={58,26}, title="Down",     proc=LJZ_TO_ButtonProc
    Button btTraceReverse,win=$p, pos={346,520}, size={68,26}, title="Reverse",  proc=LJZ_TO_ButtonProc
    Button btDropTrace,   win=$p, pos={420,520}, size={82,26}, title="Drop Row", proc=LJZ_TO_ButtonProc
    Button btResetDrop,   win=$p, pos={508,520}, size={86,26}, title="Reset Drop", proc=LJZ_TO_ButtonProc

    Button btSelAllTrace,  win=$p, pos={18,552}, size={86,26}, title="Trace All",  proc=LJZ_TO_ButtonProc
    Button btSelNoneTrace, win=$p, pos={110,552}, size={86,26}, title="Trace None", proc=LJZ_TO_ButtonProc
    Button btRemoveSource, win=$p, pos={202,552}, size={112,26}, title="Remove Src", proc=LJZ_TO_ButtonProc
    Button btAddSelected,  win=$p, pos={406,548}, size={106,30}, title="Add Selected", proc=LJZ_TO_ButtonProc
    Button btAddSourceAll, win=$p, pos={518,548}, size={106,30}, title="Add Source All",proc=LJZ_TO_ButtonProc

    // =====================================================================
    //  Status bar
    // =====================================================================
    GroupBox gbInfo, win=$p, pos={8,636}, size={1084,82}, title="Status"
    TitleBox tbSrc, win=$p, pos={20,656}, size={1050,18}, frame=0, title="Source: "
    TitleBox tbTgt, win=$p, pos={20,678}, size={1050,18}, frame=0, title="Target: "
    TitleBox tbTr,  win=$p, pos={20,700}, size={1050,18}, frame=0, title="Active trace: "

    NVAR xPreset = $(LJZ_TO_BaseDF() + ":XPreset")
    NVAR yPreset = $(LJZ_TO_BaseDF() + ":YPreset")
    NVAR colorMode = $(LJZ_TO_BaseDF() + ":ColorMode")
    PopupMenu pmX,     win=$p, mode=(xPreset + 1)
    PopupMenu pmY,     win=$p, mode=(yPreset + 1)
    PopupMenu pmColor, win=$p, mode=(colorMode + 1)

    LJZ_TO_RefreshTitleBoxes()
    return 0
End

Function LJZ_TO_RefreshTitleBoxes()
    String p = LJZ_TO_PanelName()
    if (WinType(p) == 0)
        return 0
    endif

    SVAR srcGraph = $(LJZ_TO_BaseDF() + ":SourceGraph")
    SVAR tgtGraph = $(LJZ_TO_BaseDF() + ":TargetGraph")
    SVAR traceSel = $(LJZ_TO_BaseDF() + ":TraceSel")

    TitleBox tbSrc, win=$p, title="Source: " + LJZ_TO_ShortenForTitle(srcGraph, 160)
    TitleBox tbTgt, win=$p, title="Target: " + LJZ_TO_ShortenForTitle(tgtGraph, 160)
    TitleBox tbTr,  win=$p, title="Active trace: " + LJZ_TO_ShortenForTitle(traceSel, 160)
    return 0
End


// ============================================================================
//  Section 9. Callbacks
// ============================================================================

Function LJZ_TO_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    String c = ba.ctrlName
    SVAR toSrcGraph = $(LJZ_TO_BaseDF() + ":SourceGraph")
    SVAR toTgtGraph = $(LJZ_TO_BaseDF() + ":TargetGraph")
    String topGraph

    strswitch (c)
        case "btRefreshGraphs":
            LJZ_TO_RebuildGraphLists()
            LJZ_TO_RefreshTitleBoxes()
            break

        case "btTopSource":
            topGraph = WinName(0, 1)
            if (strlen(topGraph) > 0 && WinType(topGraph) == 1)
                toSrcGraph = topGraph
                LJZ_TO_RebuildGraphLists()
                LJZ_TO_RefreshTitleBoxes()
            endif
            break

        case "btTopTarget":
            topGraph = WinName(0, 1)
            if (strlen(topGraph) > 0 && WinType(topGraph) == 1)
                toTgtGraph = topGraph
                LJZ_TO_RebuildGraphLists()
                LJZ_TO_RefreshTitleBoxes()
            endif
            break

        case "btSelAllSrc":
            Wave srcSel = $(LJZ_TO_BaseDF() + ":LB_SourceSel")
            srcSel = 1
            ControlUpdate/W=$(LJZ_TO_PanelName()) lbSource
            break

        case "btSelNoneSrc":
            Wave srcSel2 = $(LJZ_TO_BaseDF() + ":LB_SourceSel")
            srcSel2 = 0
            ControlUpdate/W=$(LJZ_TO_PanelName()) lbSource
            break

        case "btSelAllTrace":
            Wave trSel = $(LJZ_TO_BaseDF() + ":LB_TraceSel")
            trSel = 1
            ControlUpdate/W=$(LJZ_TO_PanelName()) lbTrace
            break

        case "btSelNoneTrace":
            Wave trSel2 = $(LJZ_TO_BaseDF() + ":LB_TraceSel")
            trSel2 = 0
            ControlUpdate/W=$(LJZ_TO_PanelName()) lbTrace
            break

        case "btTraceUp":
            LJZ_TO_MoveTraceRow(-1)
            break

        case "btTraceDown":
            LJZ_TO_MoveTraceRow(1)
            break

        case "btTraceReverse":
            LJZ_TO_ReverseTraceList()
            break

        case "btDropTrace":
            LJZ_TO_DropSelectedTracesFromList()
            break

        case "btResetDrop":
            LJZ_TO_ResetTraceDrops()
            break

        case "btRemoveSource":
            LJZ_TO_RemoveSelectedTracesFromSourceGraph()
            break

        case "btAddSelected":
            LJZ_TO_AddSelectedTraces()
            break

        case "btAddSourceAll":
            LJZ_TO_AddCurrentSourceAll()
            break

        case "btAddSelectedSources":
            LJZ_TO_AddSelectedSourcesAll()
            break

        case "btClearTarget":
            LJZ_TO_ClearTarget()
            break

        case "btFocusTarget":
            DoWindow/F $toTgtGraph
            break

        case "btApplyAxis":
            LJZ_TO_ApplyAxisToTarget()
            break

        case "btAutoAxis":
            LJZ_TO_AutoAxisTarget()
            break

        case "btRestyle":
            LJZ_TO_RestyleTarget()
            break

        case "btRecolor":
            LJZ_TO_RecolorTarget()
            break
    endswitch

    return 0
End

Function LJZ_TO_SourceListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if (lba.eventCode != 4)
        return 0
    endif
    if (lba.row < 0)
        return 0
    endif

    // Set active source for trace list, but do not wipe multi-select state.
    LJZ_TO_SetActiveSourceRow(lba.row)
    return 0
End

Function LJZ_TO_TargetListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if (lba.eventCode != 4)
        return 0
    endif
    if (lba.row < 0)
        return 0
    endif

    LJZ_TO_SelectTargetRow(lba.row)
    return 0
End

Function LJZ_TO_TraceListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if (lba.eventCode != 4)
        return 0
    endif
    if (lba.row < 0)
        return 0
    endif

    Wave/T trPath = $(LJZ_TO_BaseDF() + ":LB_TracePath")
    SVAR traceSel = $(LJZ_TO_BaseDF() + ":TraceSel")
    NVAR traceRow = $(LJZ_TO_BaseDF() + ":TraceRow")

    if (lba.row < numpnts(trPath))
        traceSel = trPath[lba.row]
        traceRow = lba.row
    endif

    LJZ_TO_RefreshTitleBoxes()
    return 0
End

Function LJZ_TO_CheckProc(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba

    if (cba.eventCode != 2)
        return 0
    endif

    strswitch (cba.ctrlName)
        case "cbVisible":
            LJZ_TO_RebuildTraceList()
            LJZ_TO_RefreshTitleBoxes()
            break

        case "cbPrefix":
        case "cbManualX":
        case "cbYDataTrans":
        case "cbTransferStd":
            LJZ_TO_RefreshTitleBoxes()
            break

        case "cbXRange":
        case "cbYRange":
            LJZ_TO_ApplyAxisToTarget()
            break
    endswitch

    return 0
End

Function LJZ_TO_SetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    // 1=mouse, 2=enter, 8=tab/end edit. Avoid heavy work on every keystroke.
    if (sva.eventCode != 1 && sva.eventCode != 2 && sva.eventCode != 8)
        return 0
    endif

    strswitch (sva.ctrlName)
        case "svXOff":
        case "svYOff":
        case "svLineSize":
            LJZ_TO_RestyleTarget()
            break

        case "svXMin":
        case "svXMax":
        case "svYMin":
        case "svYMax":
            LJZ_TO_ApplyAxisToTarget()
            break

        case "svStdSuffix":
            LJZ_TO_RebuildTraceList()
            LJZ_TO_RefreshTitleBoxes()
            break

        case "svXScaleStart":
        case "svXScaleDelta":
        case "svYDataScale":
        case "svYDataOffset":
            LJZ_TO_RefreshTitleBoxes()
            break
    endswitch

    return 0
End

Function LJZ_TO_FilterSetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    // fire on every keystroke (6) and on commit/end edit
    if (sva.eventCode != 1 && sva.eventCode != 2 && sva.eventCode != 6 && sva.eventCode != 8)
        return 0
    endif

    strswitch (sva.ctrlName)
        case "svFilterSrc":
        case "svFilterTgt":
            LJZ_TO_RebuildGraphLists()
            LJZ_TO_RefreshTitleBoxes()
            break

        case "svFilterTrace":
            LJZ_TO_RebuildTraceList()
            LJZ_TO_RefreshTitleBoxes()
            break
    endswitch

    return 0
End

Function LJZ_TO_PopupProc(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa

    if (pa.eventCode != 2)
        return 0
    endif

    strswitch (pa.ctrlName)
        case "pmX":
            NVAR xPreset = $(LJZ_TO_BaseDF() + ":XPreset")
            xPreset = pa.popNum - 1
            LJZ_TO_ApplyAxisToTarget()
            break

        case "pmY":
            NVAR yPreset = $(LJZ_TO_BaseDF() + ":YPreset")
            yPreset = pa.popNum - 1
            LJZ_TO_ApplyAxisToTarget()
            break

        case "pmColor":
            NVAR colorMode = $(LJZ_TO_BaseDF() + ":ColorMode")
            colorMode = pa.popNum - 1
            LJZ_TO_RecolorTarget()
            break
    endswitch

    return 0
End
