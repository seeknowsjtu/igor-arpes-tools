#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
// LJZ_TraceOverlay.ipf
// Collect traces from existing graph windows and overlay them in one graph.
// Igor Pro 8 compatible style.
//
// Usage:
//   1. Put this file in User Procedures, or paste it into the procedure window.
//   2. Compile.
//   3. Macros -> LJZ Trace Overlay Panel...
// ============================================================================

Menu "Macros"
    "LJZ Trace Overlay Panel...", LJZ_TO_OpenPanel()
End

// ---------- Data folder and state ----------

Function LJZ_TO_EnsureDF()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:TraceOverlay

    SVAR/Z sSourceGraph = root:ARPES_LJZ:TraceOverlay:sSourceGraph
    if (!SVAR_Exists(sSourceGraph))
        String/G root:ARPES_LJZ:TraceOverlay:sSourceGraph = ""
    endif

    SVAR/Z sTargetGraph = root:ARPES_LJZ:TraceOverlay:sTargetGraph
    if (!SVAR_Exists(sTargetGraph))
        String/G root:ARPES_LJZ:TraceOverlay:sTargetGraph = "LJZ_TraceOverlay"
    endif

    SVAR/Z sGraphFilter = root:ARPES_LJZ:TraceOverlay:sGraphFilter
    if (!SVAR_Exists(sGraphFilter))
        String/G root:ARPES_LJZ:TraceOverlay:sGraphFilter = ""
    endif

    SVAR/Z sXPreset = root:ARPES_LJZ:TraceOverlay:sXPreset
    if (!SVAR_Exists(sXPreset))
        String/G root:ARPES_LJZ:TraceOverlay:sXPreset = "Delay (ps)"
    endif

    SVAR/Z sYPreset = root:ARPES_LJZ:TraceOverlay:sYPreset
    if (!SVAR_Exists(sYPreset))
        String/G root:ARPES_LJZ:TraceOverlay:sYPreset = "Intensity (arb. units)"
    endif

    NVAR/Z gVisibleOnly = root:ARPES_LJZ:TraceOverlay:gVisibleOnly
    if (!NVAR_Exists(gVisibleOnly))
        Variable/G root:ARPES_LJZ:TraceOverlay:gVisibleOnly = 1
    endif

    NVAR/Z gPrefixTraceName = root:ARPES_LJZ:TraceOverlay:gPrefixTraceName
    if (!NVAR_Exists(gPrefixTraceName))
        Variable/G root:ARPES_LJZ:TraceOverlay:gPrefixTraceName = 1
    endif

    NVAR/Z gXOffset = root:ARPES_LJZ:TraceOverlay:gXOffset
    if (!NVAR_Exists(gXOffset))
        Variable/G root:ARPES_LJZ:TraceOverlay:gXOffset = 0
    endif

    NVAR/Z gYOffset = root:ARPES_LJZ:TraceOverlay:gYOffset
    if (!NVAR_Exists(gYOffset))
        Variable/G root:ARPES_LJZ:TraceOverlay:gYOffset = 0
    endif

    NVAR/Z gUseXRange = root:ARPES_LJZ:TraceOverlay:gUseXRange
    if (!NVAR_Exists(gUseXRange))
        Variable/G root:ARPES_LJZ:TraceOverlay:gUseXRange = 0
    endif

    NVAR/Z gXMin = root:ARPES_LJZ:TraceOverlay:gXMin
    if (!NVAR_Exists(gXMin))
        Variable/G root:ARPES_LJZ:TraceOverlay:gXMin = -10
    endif

    NVAR/Z gXMax = root:ARPES_LJZ:TraceOverlay:gXMax
    if (!NVAR_Exists(gXMax))
        Variable/G root:ARPES_LJZ:TraceOverlay:gXMax = 10
    endif

    NVAR/Z gUseYRange = root:ARPES_LJZ:TraceOverlay:gUseYRange
    if (!NVAR_Exists(gUseYRange))
        Variable/G root:ARPES_LJZ:TraceOverlay:gUseYRange = 0
    endif

    NVAR/Z gYMin = root:ARPES_LJZ:TraceOverlay:gYMin
    if (!NVAR_Exists(gYMin))
        Variable/G root:ARPES_LJZ:TraceOverlay:gYMin = 0
    endif

    NVAR/Z gYMax = root:ARPES_LJZ:TraceOverlay:gYMax
    if (!NVAR_Exists(gYMax))
        Variable/G root:ARPES_LJZ:TraceOverlay:gYMax = 1
    endif

    Make/O/T/N=0 root:ARPES_LJZ:TraceOverlay:twTraceList
    Make/O/N=0 root:ARPES_LJZ:TraceOverlay:nwTraceSel
End

Function/S LJZ_TO_PanelName()
    return "LJZ_TraceOverlay_Panel"
End

// ---------- Popup list helpers ----------

Function/S LJZ_TO_GraphPopup()
    String glist = WinList("*", ";", "WIN:1")
    if (strlen(glist) == 0)
        return "_none_;"
    endif
    return glist
End

Function/S LJZ_TO_XPresetPopup()
    return "Delay (ps);Temperature (K);E - EF (eV);Energy (eV);Momentum k (1/A);Angle (deg);Index / calculated x;Custom / keep label;"
End

Function/S LJZ_TO_YPresetPopup()
    return "Intensity (arb. units);Normalized intensity;Counts;MDC intensity;EDC intensity;Delta k (1/A);Peak position;Peak width;Residual;Custom / keep label;"
End

// ---------- Panel ----------

Function LJZ_TO_OpenPanel()
    LJZ_TO_EnsureDF()

    String p = LJZ_TO_PanelName()
    DoWindow/F $p
    if (V_flag)
        LJZ_TO_RefreshTraceList()
        return 0
    endif

    NewPanel/N=$p/W=(80,70,780,520) as "LJZ Trace Overlay"
    ModifyPanel frameStyle=1

    TitleBox tbTitle,pos={12,8},size={360,18},title="Trace Overlay: collect traces from graph windows",frame=0,fSize=12

    PopupMenu pmSource,pos={12,36},size={310,20},title="Source graph:",proc=LJZ_TO_PopupProc,fSize=11
    PopupMenu pmSource,mode=1,value=#"LJZ_TO_GraphPopup()"
    Button btUseTop,pos={335,34},size={72,22},title="Use Top",proc=LJZ_TO_ButtonProc,fSize=11
    Button btRefresh,pos={415,34},size={72,22},title="Refresh",proc=LJZ_TO_ButtonProc,fSize=11

    SetVariable svTarget,pos={12,68},size={310,20},title="Target:",fSize=11
    SetVariable svTarget,value=root:ARPES_LJZ:TraceOverlay:sTargetGraph
    SetVariable svFilter,pos={335,68},size={250,20},title="Graph filter:",fSize=11
    SetVariable svFilter,value=root:ARPES_LJZ:TraceOverlay:sGraphFilter

    CheckBox cbVisible,pos={600,39},size={90,16},title="visible only",fSize=11
    CheckBox cbVisible,value=root:ARPES_LJZ:TraceOverlay:gVisibleOnly
    CheckBox cbPrefix,pos={600,70},size={94,16},title="prefix names",fSize=11
    CheckBox cbPrefix,value=root:ARPES_LJZ:TraceOverlay:gPrefixTraceName

    TitleBox tbTrace,pos={12,104},size={360,18},title="Traces in source graph (select rows, or use Add All)",frame=0,fSize=11
    ListBox lbTraces,pos={12,126},size={420,245},listWave=root:ARPES_LJZ:TraceOverlay:twTraceList
    ListBox lbTraces,selWave=root:ARPES_LJZ:TraceOverlay:nwTraceSel,mode=4,proc=LJZ_TO_ListBoxProc,fSize=11

    Button btSelectAll,pos={12,382},size={80,22},title="Select All",proc=LJZ_TO_ButtonProc,fSize=11
    Button btSelectNone,pos={100,382},size={80,22},title="Select None",proc=LJZ_TO_ButtonProc,fSize=11
    Button btAddSel,pos={194,382},size={105,22},title="Add Selected",proc=LJZ_TO_ButtonProc,fSize=11
    Button btAddSrc,pos={310,382},size={122,22},title="Add Source All",proc=LJZ_TO_ButtonProc,fSize=11

    GroupBox gbAxis,pos={455,112},size={225,165},title="Axis presets / ranges",fSize=11
    PopupMenu pmX,pos={468,138},size={195,20},title="X:",proc=LJZ_TO_PopupProc,fSize=11
    PopupMenu pmX,mode=1,value=#"LJZ_TO_XPresetPopup()"
    PopupMenu pmY,pos={468,166},size={195,20},title="Y:",proc=LJZ_TO_PopupProc,fSize=11
    PopupMenu pmY,mode=1,value=#"LJZ_TO_YPresetPopup()"

    CheckBox cbXRange,pos={468,198},size={70,16},title="x range",fSize=11
    CheckBox cbXRange,value=root:ARPES_LJZ:TraceOverlay:gUseXRange
    SetVariable svXMin,pos={540,196},size={62,20},title="",fSize=11
    SetVariable svXMin,value=root:ARPES_LJZ:TraceOverlay:gXMin
    SetVariable svXMax,pos={610,196},size={62,20},title="",fSize=11
    SetVariable svXMax,value=root:ARPES_LJZ:TraceOverlay:gXMax

    CheckBox cbYRange,pos={468,226},size={70,16},title="y range",fSize=11
    CheckBox cbYRange,value=root:ARPES_LJZ:TraceOverlay:gUseYRange
    SetVariable svYMin,pos={540,224},size={62,20},title="",fSize=11
    SetVariable svYMin,value=root:ARPES_LJZ:TraceOverlay:gYMin
    SetVariable svYMax,pos={610,224},size={62,20},title="",fSize=11
    SetVariable svYMax,value=root:ARPES_LJZ:TraceOverlay:gYMax

    Button btApplyAxis,pos={468,250},size={95,22},title="Apply Axis",proc=LJZ_TO_ButtonProc,fSize=11
    Button btAutoAxis,pos={575,250},size={95,22},title="Auto Axis",proc=LJZ_TO_ButtonProc,fSize=11

    GroupBox gbStyle,pos={455,292},size={225,80},title="Display offsets",fSize=11
    SetVariable svXOffset,pos={468,318},size={95,20},title="x off:",fSize=11
    SetVariable svXOffset,value=root:ARPES_LJZ:TraceOverlay:gXOffset
    SetVariable svYOffset,pos={575,318},size={95,20},title="y off:",fSize=11
    SetVariable svYOffset,value=root:ARPES_LJZ:TraceOverlay:gYOffset
    Button btRestyle,pos={468,344},size={95,22},title="Restyle",proc=LJZ_TO_ButtonProc,fSize=11
    Button btClear,pos={575,344},size={95,22},title="Clear Target",proc=LJZ_TO_ButtonProc,fSize=11

    Button btAddAllGraphs,pos={455,382},size={225,24},title="Add All Graphs Passing Filter",proc=LJZ_TO_ButtonProc,fSize=11

    TitleBox tbHint,pos={12,420},size={650,18},title="Tip: The original waves are not duplicated. XY traces keep their original X wave; waveform traces keep their X scaling.",frame=0,fSize=10

    LJZ_TO_InitSourceIfEmpty()
    LJZ_TO_RefreshTraceList()
    return 0
End

Function LJZ_TO_InitSourceIfEmpty()
    LJZ_TO_EnsureDF()
    SVAR sSourceGraph = root:ARPES_LJZ:TraceOverlay:sSourceGraph
    if (strlen(sSourceGraph) == 0)
        String topGraph = WinName(0, 1)
        if (strlen(topGraph) > 0)
            sSourceGraph = topGraph
        endif
    endif
End

// ---------- Control callbacks ----------

Function LJZ_TO_PopupProc(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa

    if (pa.eventCode != 2)
        return 0
    endif

    LJZ_TO_EnsureDF()
    SVAR sSourceGraph = root:ARPES_LJZ:TraceOverlay:sSourceGraph
    SVAR sXPreset = root:ARPES_LJZ:TraceOverlay:sXPreset
    SVAR sYPreset = root:ARPES_LJZ:TraceOverlay:sYPreset

    strswitch (pa.ctrlName)
        case "pmSource":
            if (!StringMatch(pa.popStr, "_none_"))
                sSourceGraph = pa.popStr
                LJZ_TO_RefreshTraceList()
            endif
            break
        case "pmX":
            sXPreset = pa.popStr
            break
        case "pmY":
            sYPreset = pa.popStr
            break
    endswitch

    return 0
End

Function LJZ_TO_ListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    return 0
End

Function LJZ_TO_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    strswitch (ba.ctrlName)
        case "btUseTop":
            LJZ_TO_SetSourceToTopGraph()
            break
        case "btRefresh":
            LJZ_TO_RefreshTraceList()
            break
        case "btSelectAll":
            LJZ_TO_SelectAllTraces(1)
            break
        case "btSelectNone":
            LJZ_TO_SelectAllTraces(0)
            break
        case "btAddSel":
            LJZ_TO_AddSelectedFromSource()
            break
        case "btAddSrc":
            LJZ_TO_AddAllFromSource()
            break
        case "btAddAllGraphs":
            LJZ_TO_AddAllGraphsPassingFilter()
            break
        case "btApplyAxis":
            LJZ_TO_ApplyAxisPreset()
            break
        case "btAutoAxis":
            LJZ_TO_AutoAxis()
            break
        case "btRestyle":
            LJZ_TO_RestyleTarget()
            break
        case "btClear":
            LJZ_TO_ClearTargetGraph()
            break
    endswitch

    return 0
End

// ---------- Source graph and trace list ----------

Function LJZ_TO_SetSourceToTopGraph()
    LJZ_TO_EnsureDF()
    SVAR sSourceGraph = root:ARPES_LJZ:TraceOverlay:sSourceGraph

    String topGraph = WinName(0, 1)
    if (strlen(topGraph) == 0)
        Print "LJZ Trace Overlay: no graph window is available."
        return -1
    endif

    sSourceGraph = topGraph
    LJZ_TO_RefreshTraceList()
    return 0
End

Function LJZ_TO_RefreshTraceList()
    LJZ_TO_EnsureDF()
    SVAR sSourceGraph = root:ARPES_LJZ:TraceOverlay:sSourceGraph
    NVAR gVisibleOnly = root:ARPES_LJZ:TraceOverlay:gVisibleOnly
    Wave/T tw = root:ARPES_LJZ:TraceOverlay:twTraceList
    Wave sel = root:ARPES_LJZ:TraceOverlay:nwTraceSel

    String src = sSourceGraph
    if (strlen(src) == 0)
        src = WinName(0, 1)
        sSourceGraph = src
    endif

    if ((strlen(src) == 0) || (WinType(src) != 1))
        Redimension/N=0 tw, sel
        return -1
    endif

    Variable opt = 1
    if (gVisibleOnly)
        opt = 1 + 4
    endif

    String traces = TraceNameList(src, ";", opt)
    Variable n = ItemsInList(traces, ";")
    Redimension/N=(n) tw, sel
    sel = 0

    Variable i
    for (i = 0; i < n; i += 1)
        String tr = StringFromList(i, traces, ";")
        Wave/Z yw = TraceNameToWaveRef(src, tr)
        String yPath = ""
        if (WaveExists(yw))
            yPath = GetWavesDataFolder(yw, 2)
        endif
        tw[i] = tr + "    ->    " + yPath
    endfor

    String p = LJZ_TO_PanelName()
    DoWindow $p
    if (V_flag)
        ListBox lbTraces,win=$p,listWave=root:ARPES_LJZ:TraceOverlay:twTraceList
        ListBox lbTraces,win=$p,selWave=root:ARPES_LJZ:TraceOverlay:nwTraceSel,mode=4
        PopupMenu pmSource,win=$p,value=#"LJZ_TO_GraphPopup()"
    endif

    return 0
End

Function LJZ_TO_SelectAllTraces(flag)
    Variable flag
    LJZ_TO_EnsureDF()
    Wave sel = root:ARPES_LJZ:TraceOverlay:nwTraceSel
    if (flag)
        sel = 1
    else
        sel = 0
    endif
    return 0
End

// ---------- Target graph ----------

Function/S LJZ_TO_GetOrMakeTargetGraph()
    LJZ_TO_EnsureDF()
    SVAR sTargetGraph = root:ARPES_LJZ:TraceOverlay:sTargetGraph

    String tgt = CleanupName(sTargetGraph, 0)
    if (strlen(tgt) == 0)
        tgt = "LJZ_TraceOverlay"
    endif
    sTargetGraph = tgt

    DoWindow $tgt
    if (!V_flag)
        Display/N=$tgt/W=(80,80,760,560)
        DoWindow/C $tgt
        ModifyGraph/W=$tgt mirror=1,tick=2,minor=1,standoff=0,fSize=12
        ModifyGraph/W=$tgt margin(left)=58,margin(bottom)=48,margin(right)=18,margin(top)=18
    else
        DoWindow/F $tgt
    endif

    return tgt
End

Function LJZ_TO_ClearTargetGraph()
    LJZ_TO_EnsureDF()
    SVAR sTargetGraph = root:ARPES_LJZ:TraceOverlay:sTargetGraph
    String tgt = sTargetGraph

    if ((strlen(tgt) == 0) || (WinType(tgt) != 1))
        return 0
    endif

    String traces = TraceNameList(tgt, ";", 1)
    Variable n = ItemsInList(traces, ";")
    Variable i
    for (i = n - 1; i >= 0; i -= 1)
        String tr = StringFromList(i, traces, ";")
        RemoveFromGraph/W=$tgt/Z $tr
    endfor

    return 0
End

// ---------- Append operations ----------

Function LJZ_TO_AddSelectedFromSource()
    LJZ_TO_EnsureDF()
    SVAR sSourceGraph = root:ARPES_LJZ:TraceOverlay:sSourceGraph
    Wave sel = root:ARPES_LJZ:TraceOverlay:nwTraceSel

    if ((strlen(sSourceGraph) == 0) || (WinType(sSourceGraph) != 1))
        Print "LJZ Trace Overlay: invalid source graph."
        return -1
    endif

    String tgt = LJZ_TO_GetOrMakeTargetGraph()
    String traces = LJZ_TO_GetTraceListForSource(sSourceGraph)
    Variable n = ItemsInList(traces, ";")
    Variable baseIndex = ItemsInList(TraceNameList(tgt, ";", 1), ";")
    Variable nAdded = 0

    Variable i
    for (i = 0; i < n; i += 1)
        if ((i < numpnts(sel)) && ((sel[i] & 1) != 0))
            String tr = StringFromList(i, traces, ";")
            LJZ_TO_AppendOneTrace(sSourceGraph, tr, tgt, baseIndex + nAdded)
            nAdded += 1
        endif
    endfor

    LJZ_TO_ApplyAxisPreset()
    Print "LJZ Trace Overlay: added ", nAdded, " selected trace(s) from ", sSourceGraph
    return nAdded
End

Function LJZ_TO_AddAllFromSource()
    LJZ_TO_EnsureDF()
    SVAR sSourceGraph = root:ARPES_LJZ:TraceOverlay:sSourceGraph

    if ((strlen(sSourceGraph) == 0) || (WinType(sSourceGraph) != 1))
        Print "LJZ Trace Overlay: invalid source graph."
        return -1
    endif

    String tgt = LJZ_TO_GetOrMakeTargetGraph()
    Variable nAdded = LJZ_TO_AppendAllFromGraph(sSourceGraph, tgt)
    LJZ_TO_ApplyAxisPreset()
    Print "LJZ Trace Overlay: added ", nAdded, " trace(s) from ", sSourceGraph
    return nAdded
End

Function LJZ_TO_AddAllGraphsPassingFilter()
    LJZ_TO_EnsureDF()
    SVAR sGraphFilter = root:ARPES_LJZ:TraceOverlay:sGraphFilter
    SVAR sTargetGraph = root:ARPES_LJZ:TraceOverlay:sTargetGraph

    String tgt = LJZ_TO_GetOrMakeTargetGraph()
    String glist = WinList("*", ";", "WIN:1")
    Variable nG = ItemsInList(glist, ";")
    Variable total = 0

    Variable i
    for (i = 0; i < nG; i += 1)
        String g = StringFromList(i, glist, ";")
        if (StringMatch(g, tgt))
            continue
        endif
        if (!LJZ_TO_PassFilter(g, sGraphFilter))
            continue
        endif
        total += LJZ_TO_AppendAllFromGraph(g, tgt)
    endfor

    LJZ_TO_ApplyAxisPreset()
    Print "LJZ Trace Overlay: added ", total, " trace(s) from graphs passing filter [", sGraphFilter, "]."
    return total
End

Function LJZ_TO_AppendAllFromGraph(src, tgt)
    String src, tgt

    String traces = LJZ_TO_GetTraceListForSource(src)
    Variable n = ItemsInList(traces, ";")
    Variable baseIndex = ItemsInList(TraceNameList(tgt, ";", 1), ";")
    Variable nAdded = 0

    Variable i
    for (i = 0; i < n; i += 1)
        String tr = StringFromList(i, traces, ";")
        Variable err = LJZ_TO_AppendOneTrace(src, tr, tgt, baseIndex + nAdded)
        if (err == 0)
            nAdded += 1
        endif
    endfor

    return nAdded
End

Function/S LJZ_TO_GetTraceListForSource(src)
    String src
    NVAR gVisibleOnly = root:ARPES_LJZ:TraceOverlay:gVisibleOnly

    Variable opt = 1
    if (gVisibleOnly)
        opt = 1 + 4
    endif
    return TraceNameList(src, ";", opt)
End

Function LJZ_TO_AppendOneTrace(src, tr, tgt, idx)
    String src, tr, tgt
    Variable idx

    LJZ_TO_EnsureDF()
    NVAR gPrefixTraceName = root:ARPES_LJZ:TraceOverlay:gPrefixTraceName

    Wave/Z yW = TraceNameToWaveRef(src, tr)
    if (!WaveExists(yW))
        Print "LJZ Trace Overlay: skipped trace without valid Y wave: ", src, " / ", tr
        return -1
    endif

    Wave/Z xW = XWaveRefFromTrace(src, tr)

    String srcClean = CleanupName(src, 0)
    String trClean = CleanupName(tr, 0)
    String base
    if (gPrefixTraceName)
        base = srcClean + "_" + trClean
    else
        base = trClean
    endif
    if (strlen(base) > 46)
        base = base[0,45]
    endif

    String newTN
    sprintf newTN, "%s_%04d", base, idx

    if (WaveExists(xW))
        AppendToGraph/W=$tgt yW/TN=$newTN vs xW
    else
        AppendToGraph/W=$tgt yW/TN=$newTN
    endif

    LJZ_TO_StyleOneTrace(tgt, newTN, idx)
    return 0
End

Function LJZ_TO_StyleOneTrace(tgt, tr, idx)
    String tgt, tr
    Variable idx

    NVAR gXOffset = root:ARPES_LJZ:TraceOverlay:gXOffset
    NVAR gYOffset = root:ARPES_LJZ:TraceOverlay:gYOffset

    Variable r = 0, g = 0, b = 0
    Variable c = mod(idx, 8)

    switch (c)
        case 0:
            r = 0; g = 0; b = 0
            break
        case 1:
            r = 12000; g = 25000; b = 52000
            break
        case 2:
            r = 52000; g = 16000; b = 12000
            break
        case 3:
            r = 0; g = 39000; b = 19000
            break
        case 4:
            r = 42000; g = 16000; b = 52000
            break
        case 5:
            r = 55000; g = 33000; b = 0
            break
        case 6:
            r = 0; g = 42000; b = 46000
            break
        case 7:
            r = 36000; g = 36000; b = 36000
            break
    endswitch

    ModifyGraph/W=$tgt/Z mode($tr)=0,lsize($tr)=1.2,rgb($tr)=(r,g,b)
    ModifyGraph/W=$tgt/Z offset($tr)={gXOffset * idx, gYOffset * idx}
    return 0
End

Function LJZ_TO_RestyleTarget()
    LJZ_TO_EnsureDF()
    SVAR sTargetGraph = root:ARPES_LJZ:TraceOverlay:sTargetGraph
    String tgt = sTargetGraph

    if ((strlen(tgt) == 0) || (WinType(tgt) != 1))
        return -1
    endif

    String traces = TraceNameList(tgt, ";", 1)
    Variable n = ItemsInList(traces, ";")

    Variable i
    for (i = 0; i < n; i += 1)
        String tr = StringFromList(i, traces, ";")
        LJZ_TO_StyleOneTrace(tgt, tr, i)
    endfor

    return 0
End

// ---------- Axis presets ----------

Function LJZ_TO_ApplyAxisPreset()
    LJZ_TO_EnsureDF()
    SVAR sTargetGraph = root:ARPES_LJZ:TraceOverlay:sTargetGraph
    SVAR sXPreset = root:ARPES_LJZ:TraceOverlay:sXPreset
    SVAR sYPreset = root:ARPES_LJZ:TraceOverlay:sYPreset
    NVAR gUseXRange = root:ARPES_LJZ:TraceOverlay:gUseXRange
    NVAR gXMin = root:ARPES_LJZ:TraceOverlay:gXMin
    NVAR gXMax = root:ARPES_LJZ:TraceOverlay:gXMax
    NVAR gUseYRange = root:ARPES_LJZ:TraceOverlay:gUseYRange
    NVAR gYMin = root:ARPES_LJZ:TraceOverlay:gYMin
    NVAR gYMax = root:ARPES_LJZ:TraceOverlay:gYMax

    String tgt = sTargetGraph
    if ((strlen(tgt) == 0) || (WinType(tgt) != 1))
        return -1
    endif

    String xLabel = LJZ_TO_XLabelFromPreset(sXPreset)
    String yLabel = LJZ_TO_YLabelFromPreset(sYPreset)

    if (strlen(xLabel) > 0)
        Label/W=$tgt/Z bottom, xLabel
    endif
    if (strlen(yLabel) > 0)
        Label/W=$tgt/Z left, yLabel
    endif

    ModifyGraph/W=$tgt/Z mirror=1,tick=2,minor=1,standoff=0,fSize=12

    if (gUseXRange)
        SetAxis/W=$tgt/Z bottom, gXMin, gXMax
    else
        SetAxis/W=$tgt/Z/A bottom
    endif

    if (gUseYRange)
        SetAxis/W=$tgt/Z left, gYMin, gYMax
    else
        SetAxis/W=$tgt/Z/A left
    endif

    Legend/W=$tgt/C/N=LJZ_TO_Legend/A=RT/F=0/X=2/Y=2 ""
    return 0
End

Function LJZ_TO_AutoAxis()
    LJZ_TO_EnsureDF()
    SVAR sTargetGraph = root:ARPES_LJZ:TraceOverlay:sTargetGraph
    if ((strlen(sTargetGraph) == 0) || (WinType(sTargetGraph) != 1))
        return -1
    endif

    SetAxis/W=$sTargetGraph/Z/A bottom
    SetAxis/W=$sTargetGraph/Z/A left
    return 0
End

Function/S LJZ_TO_XLabelFromPreset(preset)
    String preset

    strswitch (preset)
        case "Delay (ps)":
            return "Delay (ps)"
        case "Temperature (K)":
            return "Temperature (K)"
        case "E - EF (eV)":
            return "E - EF (eV)"
        case "Energy (eV)":
            return "Energy (eV)"
        case "Momentum k (1/A)":
            return "k (1/A)"
        case "Angle (deg)":
            return "Angle (deg)"
        case "Index / calculated x":
            return "x"
        case "Custom / keep label":
            return ""
    endswitch

    return preset
End

Function/S LJZ_TO_YLabelFromPreset(preset)
    String preset

    strswitch (preset)
        case "Intensity (arb. units)":
            return "Intensity (arb. units)"
        case "Normalized intensity":
            return "Normalized intensity"
        case "Counts":
            return "Counts"
        case "MDC intensity":
            return "MDC intensity (arb. units)"
        case "EDC intensity":
            return "EDC intensity (arb. units)"
        case "Delta k (1/A)":
            return "Delta k (1/A)"
        case "Peak position":
            return "Peak position"
        case "Peak width":
            return "Peak width"
        case "Residual":
            return "Residual"
        case "Custom / keep label":
            return ""
    endswitch

    return preset
End

// ---------- Utility ----------

Function LJZ_TO_PassFilter(s, filter)
    String s, filter

    if (strlen(filter) == 0)
        return 1
    endif

    String su = UpperStr(s)
    String fu = UpperStr(filter)
    return StringMatch(su, "*" + fu + "*")
End
