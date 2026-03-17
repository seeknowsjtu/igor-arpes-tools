#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Menu "ARPES_LJZ"
    "-"
    "Layout Tool (Panel)", LJZ_LayoutTool()
End

// ============================================================
// Init
// ============================================================
Function LJZ_LT_Init()
    String df0 = GetDataFolder(1)

    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:ARPES_LJZ
    NewDataFolder/O root:Packages:ARPES_LJZ:LayoutTool
    SetDataFolder root:Packages:ARPES_LJZ:LayoutTool

    if (!WaveExists($"LayoutList"))
        Make/O/T/N=0 LayoutList
    endif
    if (!WaveExists($"LayoutSel"))
        Make/O/U/B/N=0 LayoutSel
    endif

    if (!WaveExists($"ObjDisp"))
        Make/O/T/N=0 ObjDisp
    endif
    if (!WaveExists($"ObjSel"))
        Make/O/U/B/N=0 ObjSel
    endif
    if (!WaveExists($"ObjName"))
        Make/O/T/N=0 ObjName
    endif
    if (!WaveExists($"ObjSpec"))
        Make/O/T/N=0 ObjSpec
    endif
    if (!WaveExists($"ObjType"))
        Make/O/T/N=0 ObjType
    endif
    if (!WaveExists($"ObjIndex"))
        Make/O/D/N=0 ObjIndex
    endif
    if (!WaveExists($"ObjLeft"))
        Make/O/D/N=0 ObjLeft
    endif
    if (!WaveExists($"ObjTop"))
        Make/O/D/N=0 ObjTop
    endif
    if (!WaveExists($"ObjWidth"))
        Make/O/D/N=0 ObjWidth
    endif
    if (!WaveExists($"ObjHeight"))
        Make/O/D/N=0 ObjHeight
    endif

    // ---------- append/search 新体系 ----------
    if (!WaveExists($"AppendRawName"))
        Make/O/T/N=0 AppendRawName
    endif
    if (!WaveExists($"AppendRawType"))
        Make/O/T/N=0 AppendRawType
    endif
    if (!WaveExists($"AppendRawSpec"))
        Make/O/T/N=0 AppendRawSpec
    endif

    if (!WaveExists($"AppendViewName"))
        Make/O/T/N=0 AppendViewName
    endif
    if (!WaveExists($"AppendViewSpec"))
        Make/O/T/N=0 AppendViewSpec
    endif
    if (!WaveExists($"AppendViewSel"))
        Make/O/U/B/N=0 AppendViewSel
    endif
    if (!WaveExists($"AppendViewMap"))
        Make/O/D/N=0 AppendViewMap
    endif

    SVAR/Z CurrentLayout = root:Packages:ARPES_LJZ:LayoutTool:CurrentLayout
    if (!SVAR_Exists(CurrentLayout))
        String/G CurrentLayout = ""
    endif

    SVAR/Z AppendSearch = root:Packages:ARPES_LJZ:LayoutTool:AppendSearch
    if (!SVAR_Exists(AppendSearch))
        String/G AppendSearch = ""
    endif

    NVAR/Z SetWidthIn = root:Packages:ARPES_LJZ:LayoutTool:SetWidthIn
    if (!NVAR_Exists(SetWidthIn))
        Variable/G SetWidthIn = 3
    endif

    NVAR/Z SetHeightIn = root:Packages:ARPES_LJZ:LayoutTool:SetHeightIn
    if (!NVAR_Exists(SetHeightIn))
        Variable/G SetHeightIn = 2
    endif

    NVAR/Z GapHIn = root:Packages:ARPES_LJZ:LayoutTool:GapHIn
    if (!NVAR_Exists(GapHIn))
        Variable/G GapHIn = 0.15
    endif

    NVAR/Z GapVIn = root:Packages:ARPES_LJZ:LayoutTool:GapVIn
    if (!NVAR_Exists(GapVIn))
        Variable/G GapVIn = 0.15
    endif

    NVAR/Z TileRows = root:Packages:ARPES_LJZ:LayoutTool:TileRows
    if (!NVAR_Exists(TileRows))
        Variable/G TileRows = 2
    endif

    NVAR/Z TileCols = root:Packages:ARPES_LJZ:LayoutTool:TileCols
    if (!NVAR_Exists(TileCols))
        Variable/G TileCols = 2
    endif

    SetDataFolder df0
End

Proc LJZ_LayoutTool()
    LJZ_LT_Init()
    LJZ_LT_RebuildAll()

    DoWindow/F LJZ_LayoutTool_Panel
    if (V_flag == 0)
        LJZ_LayoutTool_Panel()
    endif

    LJZ_LT_SyncPanel()
End

// ============================================================
// Panel
// ============================================================
Window LJZ_LayoutTool_Panel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(327,135.6,1126.8,735) as "Layout Tool (active page)"
	ModifyPanel frameStyle=1
	ShowTools/A
	TitleBox tbHead,pos={9.60,7.80},size={178.20,18.00},title="Layout Tool (official API style)"
	TitleBox tbHead,frame=0,fStyle=1
	PopupMenu pmLayout,pos={9.60,36.00},size={96.00,20.40},proc=LJZ_LT_PopLayout,title="Layout"
	PopupMenu pmLayout,mode=1,popvalue="Layout2",value= #"LJZ_LT_LayoutPopupList()"
	Button btnRefresh,pos={567.00,24.00},size={90.00,21.60},proc=LJZ_LT_BtnRefresh,title="Refresh"
	Button btnFront,pos={667.80,24.00},size={109.80,21.60},proc=LJZ_LT_BtnFront,title="Bring Front"
	Button btnSync,pos={643.80,60.60},size={129.60,21.60},proc=LJZ_LT_BtnSyncSel,title="Sync Selection"
	TitleBox tbInfo,pos={9.60,63.60},size={537.60,18.00},title="Layout: LayerComparisonEK_FD_Sw6_dv4_t900_10252103_Combine0To19 | Objects: 8 | Selected: 0"
	TitleBox tbInfo,frame=0
	GroupBox gbObj,pos={9.60,90.00},size={429.60,499.80},title="Objects in current layout page"
	ListBox lbObj,pos={19.80,111.60},size={409.80,240.00}
	ListBox lbObj,listWave=root:Packages:ARPES_LJZ:LayoutTool:ObjDisp
	ListBox lbObj,selWave=root:Packages:ARPES_LJZ:LayoutTool:ObjSel,mode= 9
	SetVariable svW,pos={21.60,369.60},size={114.60,19.80},title="Width (in)"
	SetVariable svW,limits={0,inf,0.05},value= root:Packages:ARPES_LJZ:LayoutTool:SetWidthIn
	SetVariable svH,pos={150.00,369.60},size={114.60,19.80},title="Height (in)"
	SetVariable svH,limits={0,inf,0.05},value= root:Packages:ARPES_LJZ:LayoutTool:SetHeightIn
	SetVariable svGapH,pos={21.60,397.80},size={114.60,19.80},title="H Gap (in)"
	SetVariable svGapH,limits={0,inf,0.02},value= root:Packages:ARPES_LJZ:LayoutTool:GapHIn
	SetVariable svGapV,pos={150.00,397.80},size={114.60,19.80},title="V Gap (in)"
	SetVariable svGapV,limits={0,inf,0.02},value= root:Packages:ARPES_LJZ:LayoutTool:GapVIn
	SetVariable svRows,pos={21.60,426.00},size={114.60,19.80},title="Rows"
	SetVariable svRows,limits={1,100,1},value= root:Packages:ARPES_LJZ:LayoutTool:TileRows
	SetVariable svCols,pos={150.00,426.00},size={114.60,19.80},title="Cols"
	SetVariable svCols,limits={1,100,1},value= root:Packages:ARPES_LJZ:LayoutTool:TileCols
	Button btnSetWH,pos={279.60,367.80},size={139.80,24.00},proc=LJZ_LT_BtnSetWH,title="Apply W && H"
	Button btnSameW,pos={21.60,462.00},size={120.00,24.00},proc=LJZ_LT_BtnSameW,title="Same Width"
	Button btnSameH,pos={150.00,462.00},size={120.00,24.00},proc=LJZ_LT_BtnSameH,title="Same Height"
	Button btnSameWH,pos={279.60,462.00},size={139.80,24.00},proc=LJZ_LT_BtnSameWH,title="Same W && H"
	Button btnAlignL,pos={21.60,493.80},size={120.00,24.00},proc=LJZ_LT_BtnAlignL,title="Align Left"
	Button btnAlignT,pos={150.00,493.80},size={120.00,24.00},proc=LJZ_LT_BtnAlignT,title="Align Top"
	Button btnNorm,pos={279.60,493.80},size={139.80,24.00},proc=LJZ_LT_BtnNormalize,title="Normalize Style"
	Button btnDistH,pos={21.60,525.60},size={120.00,24.00},proc=LJZ_LT_BtnDistH,title="Distribute H"
	Button btnDistV,pos={150.00,525.60},size={120.00,24.00},proc=LJZ_LT_BtnDistV,title="Distribute V"
	Button btnTile,pos={279.60,525.60},size={139.80,24.00},proc=LJZ_LT_BtnTile,title="Tile Grid"
	Button btnRemove,pos={21.60,558.00},size={397.80,25.80},proc=LJZ_LT_BtnRemove,title="Remove Selected Objects"
	GroupBox gbSrc,pos={454.80,90.00},size={330.00,499.80},title="Append graph/table windows"
	SetVariable svAppendSearch,pos={465.00,111.60},size={240.00,19.80},proc=LJZ_LT_SVAppendSearchProc,title="Search"
	SetVariable svAppendSearch,value= root:Packages:ARPES_LJZ:LayoutTool:AppendSearch
	Button btnAppendSearchClear,pos={711.60,111.60},size={63.00,19.80},proc=LJZ_LT_BtnAppendSearchClear,title="Clear"
	ListBox lbAppend,pos={465.00,138.00},size={309.60,384.00}
	ListBox lbAppend,listWave=root:Packages:ARPES_LJZ:LayoutTool:AppendViewSpec
	ListBox lbAppend,selWave=root:Packages:ARPES_LJZ:LayoutTool:AppendViewSel
	ListBox lbAppend,mode= 9
	Button btnAppend,pos={465.00,537.60},size={309.60,30.00},proc=LJZ_LT_BtnAppend,title="Append Selected Windows to Layout"
	Execute/Q/Z "SetWindow kwTopWin sizeLimit={79.8,79.8,inf,inf}" // sizeLimit requires Igor 7 or later
EndMacro

// ============================================================
// Popup helpers
// ============================================================
Function/S LJZ_LT_LayoutPopupList()
    Wave/T/Z w = root:Packages:ARPES_LJZ:LayoutTool:LayoutList
    if (!WaveExists(w) || DimSize(w,0) <= 0)
        return "(No Layout)"
    endif

    String out = ""
    Variable i, n = DimSize(w,0)
    for (i=0; i<n; i+=1)
        out += w[i] + ";"
    endfor
    return out
End

Function LJZ_LT_PopLayout(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa

    switch(pa.eventCode)
        case 2:
            SVAR CurrentLayout = root:Packages:ARPES_LJZ:LayoutTool:CurrentLayout
            if (StringMatch(pa.popStr, "(No Layout)"))
                CurrentLayout = ""
            else
                CurrentLayout = pa.popStr
            endif
            LJZ_LT_ScanObjects(CurrentLayout)
            LJZ_LT_SyncPanel()
            break
    endswitch

    return 0
End

// ============================================================
// Rebuild / scan
// ============================================================
Function LJZ_LT_RebuildAll()
    LJZ_LT_RebuildLayouts()
    LJZ_LT_RebuildSources()

    SVAR CurrentLayout = root:Packages:ARPES_LJZ:LayoutTool:CurrentLayout
    if (strlen(CurrentLayout) > 0)
        LJZ_LT_ScanObjects(CurrentLayout)
    else
        LJZ_LT_ClearObjects()
    endif
End

Function LJZ_LT_RebuildLayouts()
    Wave/T LayoutList = root:Packages:ARPES_LJZ:LayoutTool:LayoutList
    Wave/U/B LayoutSel = root:Packages:ARPES_LJZ:LayoutTool:LayoutSel
    SVAR CurrentLayout = root:Packages:ARPES_LJZ:LayoutTool:CurrentLayout

    String list = WinList("*", ";", "WIN:4")
    Variable n = ItemsInList(list, ";")

    Redimension/N=(n) LayoutList, LayoutSel
    Variable i
    for (i=0; i<n; i+=1)
        LayoutList[i] = StringFromList(i, list, ";")
        LayoutSel[i] = 0
    endfor

    if (strlen(CurrentLayout) == 0 || WinType(CurrentLayout) != 3)
        if (n > 0)
            CurrentLayout = LayoutList[0]
        else
            CurrentLayout = ""
        endif
    endif

    for (i=0; i<n; i+=1)
        if (StringMatch(LayoutList[i], CurrentLayout))
            LayoutSel[i] = 1
            break
        endif
    endfor
End

Function LJZ_LT_RebuildSources()

    // 新结构
    Wave/T AppendRawName = root:Packages:ARPES_LJZ:LayoutTool:AppendRawName
    Wave/T AppendRawType = root:Packages:ARPES_LJZ:LayoutTool:AppendRawType
    Wave/T AppendRawSpec = root:Packages:ARPES_LJZ:LayoutTool:AppendRawSpec

    String gList = WinList("*", ";", "WIN:1")
    String tList = WinList("*", ";", "WIN:2")

    Variable ng = ItemsInList(gList, ";")
    Variable nt = ItemsInList(tList, ";")
    Variable n = ng + nt

    Redimension/N=(n) AppendRawName, AppendRawType, AppendRawSpec

    Variable i, k = 0
    String nm

    // Graph windows
    for (i=0; i<ng; i+=1)
        nm = StringFromList(i, gList, ";")
        if (strlen(nm) <= 0)
            continue
        endif

        AppendRawName[k] = nm
        AppendRawType[k] = "Graph"
        AppendRawSpec[k] = "[Graph] " + nm
        k += 1
    endfor

    // Table windows
    for (i=0; i<nt; i+=1)
        nm = StringFromList(i, tList, ";")
        if (strlen(nm) <= 0)
            continue
        endif

        AppendRawName[k] = nm
        AppendRawType[k] = "Table"
        AppendRawSpec[k] = "[Table] " + nm
        k += 1
    endfor

    Redimension/N=(k) AppendRawName, AppendRawType, AppendRawSpec

    LJZ_LT_RebuildAppendView()
    return 0
End

Function LJZ_LT_ClearObjects()
    Wave/T ObjDisp = root:Packages:ARPES_LJZ:LayoutTool:ObjDisp
    Wave/U/B ObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel
    Wave/T ObjName = root:Packages:ARPES_LJZ:LayoutTool:ObjName
    Wave/T ObjSpec = root:Packages:ARPES_LJZ:LayoutTool:ObjSpec
    Wave/T ObjType = root:Packages:ARPES_LJZ:LayoutTool:ObjType
    Wave ObjIndex = root:Packages:ARPES_LJZ:LayoutTool:ObjIndex
    Wave ObjLeft = root:Packages:ARPES_LJZ:LayoutTool:ObjLeft
    Wave ObjTop = root:Packages:ARPES_LJZ:LayoutTool:ObjTop
    Wave ObjWidth = root:Packages:ARPES_LJZ:LayoutTool:ObjWidth
    Wave ObjHeight = root:Packages:ARPES_LJZ:LayoutTool:ObjHeight

    Redimension/N=0 ObjDisp, ObjSel, ObjName, ObjSpec, ObjType
    Redimension/N=0 ObjIndex, ObjLeft, ObjTop, ObjWidth, ObjHeight
End

Function LJZ_LT_ScanObjects(layoutName)
    String layoutName

    if (strlen(layoutName) == 0 || WinType(layoutName) != 3)
        LJZ_LT_ClearObjects()
        return 0
    endif

    String infoL = LayoutInfo(layoutName, "Layout")
    if (strlen(infoL) == 0)
        LJZ_LT_ClearObjects()
        return 0
    endif

    // ------------------------------------------------
    // 先备份 panel 自己的选择状态
    // 注意：ObjSel 是 panel selection，不是 layout 内部 selection
    // ------------------------------------------------
    Variable hadOldSel = 0

    Wave/T/Z oldObjSpec = root:Packages:ARPES_LJZ:LayoutTool:ObjSpec
    Wave/U/B/Z oldObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel

    if (WaveExists(oldObjSpec) && WaveExists(oldObjSel))
        hadOldSel = 1
        Duplicate/O oldObjSpec, root:Packages:ARPES_LJZ:LayoutTool:ObjSpecBakTmp
        Duplicate/O oldObjSel,  root:Packages:ARPES_LJZ:LayoutTool:ObjSelBakTmp
    endif

    Variable n = str2num(StringByKey("NUMOBJECTS", infoL))
    if (numtype(n) != 0 || n < 0)
        n = 0
    endif

    Wave/T ObjDisp = root:Packages:ARPES_LJZ:LayoutTool:ObjDisp
    Wave/U/B ObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel
    Wave/T ObjName = root:Packages:ARPES_LJZ:LayoutTool:ObjName
    Wave/T ObjSpec = root:Packages:ARPES_LJZ:LayoutTool:ObjSpec
    Wave/T ObjType = root:Packages:ARPES_LJZ:LayoutTool:ObjType
    Wave ObjIndex = root:Packages:ARPES_LJZ:LayoutTool:ObjIndex
    Wave ObjLeft = root:Packages:ARPES_LJZ:LayoutTool:ObjLeft
    Wave ObjTop = root:Packages:ARPES_LJZ:LayoutTool:ObjTop
    Wave ObjWidth = root:Packages:ARPES_LJZ:LayoutTool:ObjWidth
    Wave ObjHeight = root:Packages:ARPES_LJZ:LayoutTool:ObjHeight

    Redimension/N=(n) ObjDisp, ObjSel, ObjName, ObjSpec, ObjType
    Redimension/N=(n) ObjIndex, ObjLeft, ObjTop, ObjWidth, ObjHeight

    Variable i, inst
    String info, nm, tp

    // 先清零，稍后按旧 panel selection 恢复
    ObjSel = 0

    for (i=0; i<n; i+=1)
        info = LayoutInfo(layoutName, num2str(i))

        nm = StringByKey("NAME", info)
        tp = StringByKey("TYPE", info)

        ObjName[i]   = nm
        ObjType[i]   = tp
        ObjIndex[i]  = str2num(StringByKey("INDEX", info))
        ObjLeft[i]   = str2num(StringByKey("LEFT", info))
        ObjTop[i]    = str2num(StringByKey("TOP", info))
        ObjWidth[i]  = str2num(StringByKey("WIDTH", info))
        ObjHeight[i] = str2num(StringByKey("HEIGHT", info))

        inst = LJZ_LT_NameInstanceIndex(ObjName, i, nm)
        if (inst <= 0)
            ObjSpec[i] = nm
        else
            ObjSpec[i] = nm + "#" + num2str(inst)
        endif

        ObjDisp[i] = "[" + num2str(i) + "] " + nm + " | " + tp \
                   + " | L=" + num2str(round(ObjLeft[i]*10)/10) \
                   + " T=" + num2str(round(ObjTop[i]*10)/10) \
                   + " W=" + num2str(round(ObjWidth[i]*10)/10) \
                   + " H=" + num2str(round(ObjHeight[i]*10)/10)
    endfor

    // ------------------------------------------------
    // 恢复旧的 panel 选择（按 ObjSpec 匹配）
    // ------------------------------------------------
    if (hadOldSel)
        Wave/T specBak = root:Packages:ARPES_LJZ:LayoutTool:ObjSpecBakTmp
        Wave/U/B selBak = root:Packages:ARPES_LJZ:LayoutTool:ObjSelBakTmp

        Variable j, nOld = DimSize(specBak, 0)
        for (i=0; i<n; i+=1)
            for (j=0; j<nOld; j+=1)
                if (selBak[j] != 0 && StringMatch(ObjSpec[i], specBak[j]))
                    ObjSel[i] = 1
                    break
                endif
            endfor
        endfor

        KillWaves/Z root:Packages:ARPES_LJZ:LayoutTool:ObjSpecBakTmp
        KillWaves/Z root:Packages:ARPES_LJZ:LayoutTool:ObjSelBakTmp
    endif

    return 0
End

Function LJZ_LT_NameInstanceIndex(wNames, row, targetName)
    Wave/T wNames
    Variable row
    String targetName

    Variable i, cnt = 0
    for (i=0; i<row; i+=1)
        if (StringMatch(wNames[i], targetName))
            cnt += 1
        endif
    endfor
    return cnt
End

// ============================================================
// Sync panel
// ============================================================
Function LJZ_LT_SyncPanel()
    DoWindow LJZ_LayoutTool_Panel
    if (V_flag == 0)
        return 0
    endif

    SVAR CurrentLayout = root:Packages:ARPES_LJZ:LayoutTool:CurrentLayout
    Wave/T ObjDisp = root:Packages:ARPES_LJZ:LayoutTool:ObjDisp
    Wave/U/B ObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel
    Wave/T/Z AppendViewSpec = root:Packages:ARPES_LJZ:LayoutTool:AppendViewSpec

    PopupMenu pmLayout,win=LJZ_LayoutTool_Panel,value=#"LJZ_LT_LayoutPopupList()"
    if (strlen(CurrentLayout) > 0)
        PopupMenu pmLayout,win=LJZ_LayoutTool_Panel,popvalue=CurrentLayout
    endif

    ControlUpdate/W=LJZ_LayoutTool_Panel lbObj
    ControlUpdate/W=LJZ_LayoutTool_Panel lbAppend

    Variable nObj = DimSize(ObjDisp,0)
    Variable nSel = LJZ_LT_CountSelected(ObjSel)

    if (strlen(CurrentLayout) > 0)
        TitleBox tbInfo,win=LJZ_LayoutTool_Panel,title="Layout: " + CurrentLayout + " | Objects: " + num2str(nObj) + " | Selected: " + num2str(nSel)
    else
        TitleBox tbInfo,win=LJZ_LayoutTool_Panel,title="Layout: (none)"
    endif

    return 0
End

Function LJZ_LT_CountSelected(wSel)
    Wave wSel
    Variable i, n=DimSize(wSel,0), cnt=0
    for (i=0; i<n; i+=1)
        if (wSel[i] != 0)
            cnt += 1
        endif
    endfor
    return cnt
End

// ============================================================
// Helpers
// ============================================================
Function/S LJZ_LT_CurrentLayout()
    SVAR CurrentLayout = root:Packages:ARPES_LJZ:LayoutTool:CurrentLayout
    if (strlen(CurrentLayout) == 0 || WinType(CurrentLayout) != 3)
        return ""
    endif
    return CurrentLayout
End

Function LJZ_LT_FirstSelectedRow()
    Wave/U/B ObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel
    Variable i, n = DimSize(ObjSel,0)
    for (i=0; i<n; i+=1)
        if (ObjSel[i] != 0)
            return i
        endif
    endfor
    return -1
End

Function LJZ_LT_ModifyByIndex(layoutName, objIndex, keyName, value)
    String layoutName, keyName
    Variable objIndex, value

    String cmd = "ModifyLayout/W=" + layoutName + " " + keyName + "[" + num2str(objIndex) + "]=" + num2str(value)
    Execute/Q/Z cmd
    return 0
End

Function LJZ_LT_StyleByIndex(layoutName, objIndex, frameCode, transCode, fidelityCode)
    String layoutName
    Variable objIndex, frameCode, transCode, fidelityCode

    String cmd
    cmd = "ModifyLayout/W=" + layoutName \
        + " frame[" + num2str(objIndex) + "]=" + num2str(frameCode) \
        + ",trans[" + num2str(objIndex) + "]=" + num2str(transCode) \
        + ",fidelity[" + num2str(objIndex) + "]=" + num2str(fidelityCode)
    Execute/Q/Z cmd
    return 0
End

Function LJZ_LT_GetSelectedRows(tempRowPath)
    String tempRowPath

    Wave/U/B ObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel
    Variable n = DimSize(ObjSel,0)
    Variable i, k = 0

    Make/O/D/N=(n) $tempRowPath
    Wave tempRow = $tempRowPath

    for (i=0; i<n; i+=1)
        if (ObjSel[i] != 0)
            tempRow[k] = i
            k += 1
        endif
    endfor

    Redimension/N=(k) tempRow
    return k
End

// ============================================================
// Buttons: refresh / sync / front
// ============================================================
Function LJZ_LT_BtnRefresh(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode == 2)
        LJZ_LT_RebuildAll()
        LJZ_LT_SyncPanel()
    endif
    return 0
End

Function LJZ_LT_BtnFront(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode == 2)
        String lay = LJZ_LT_CurrentLayout()
        if (strlen(lay) > 0)
            DoWindow/F $lay
        endif
    endif
    return 0
End

Function LJZ_LT_BtnSyncSel(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    String lay = LJZ_LT_CurrentLayout()
    if (strlen(lay) <= 0)
        DoAlert 0, "No valid layout selected."
        return 0
    endif

    String infoL = LayoutInfo(lay, "Layout")
    String selList = StringByKey("SELECTED", infoL)
    selList = ReplaceString(",", selList, ";")

    Wave/T/Z ObjSpec = root:Packages:ARPES_LJZ:LayoutTool:ObjSpec
    Wave/U/B/Z ObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel

    if (!WaveExists(ObjSpec) || !WaveExists(ObjSel))
        return 0
    endif

    Variable i, n = DimSize(ObjSel, 0)
    ObjSel = 0

    for (i=0; i<n; i+=1)
        if (WhichListItem(ObjSpec[i], selList, ";") >= 0)
            ObjSel[i] = 1
        endif
    endfor

    LJZ_LT_SyncPanel()
    return 0
End

// ============================================================
// Buttons: append / remove
// ============================================================
Function LJZ_LT_BtnAppend(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    String lay = LJZ_LT_CurrentLayout()
    if (strlen(lay) <= 0)
        DoAlert 0, "No valid layout selected."
        return 0
    endif

    Wave/T AppendRawName = root:Packages:ARPES_LJZ:LayoutTool:AppendRawName
    Wave/T AppendRawType = root:Packages:ARPES_LJZ:LayoutTool:AppendRawType
    Wave/U/B AppendViewSel = root:Packages:ARPES_LJZ:LayoutTool:AppendViewSel
    Wave AppendViewMap = root:Packages:ARPES_LJZ:LayoutTool:AppendViewMap

    Variable i, n = DimSize(AppendViewSel,0)
    Variable rawIdx
    String src, tp, cmd

    for (i=0; i<n; i+=1)
        if (AppendViewSel[i] == 0)
            continue
        endif

        rawIdx = AppendViewMap[i]
        if (rawIdx < 0 || rawIdx >= DimSize(AppendRawName,0))
            continue
        endif

        src = AppendRawName[rawIdx]
        tp  = AppendRawType[rawIdx]

        if (StringMatch(tp, "Graph"))
            cmd = "AppendLayoutObject/W=" + lay + " Graph " + src
            Execute/Q/Z cmd
        elseif (StringMatch(tp, "Table"))
            cmd = "AppendLayoutObject/W=" + lay + " Table " + src
            Execute/Q/Z cmd
        endif
    endfor

    LJZ_LT_ScanObjects(lay)
    LJZ_LT_SyncPanel()
    return 0
End

Function LJZ_LT_BtnRemove(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode == 2)
        String lay = LJZ_LT_CurrentLayout()
        if (strlen(lay) <= 0)
            DoAlert 0, "No valid layout selected."
            return 0
        endif

        Wave/T ObjSpec = root:Packages:ARPES_LJZ:LayoutTool:ObjSpec
        Wave/U/B ObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel

        Variable i, n = DimSize(ObjSel,0)
        String cmd
        for (i=n-1; i>=0; i-=1)
            if (ObjSel[i] == 0)
                continue
            endif
            cmd = "RemoveLayoutObjects/W=" + lay + "/Z " + ObjSpec[i]
            Execute/Q/Z cmd
        endfor

        LJZ_LT_ScanObjects(lay)
        LJZ_LT_SyncPanel()
    endif
    return 0
End

// ============================================================
// Buttons: size / same size
// ============================================================
Function LJZ_LT_BtnSetWH(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode == 2)
        String lay = LJZ_LT_CurrentLayout()
        if (strlen(lay) <= 0)
            DoAlert 0, "No valid layout selected."
            return 0
        endif

        NVAR SetWidthIn = root:Packages:ARPES_LJZ:LayoutTool:SetWidthIn
        NVAR SetHeightIn = root:Packages:ARPES_LJZ:LayoutTool:SetHeightIn
        Wave ObjIndex = root:Packages:ARPES_LJZ:LayoutTool:ObjIndex
        Wave/U/B ObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel

        Variable i, n = DimSize(ObjSel,0)
        Variable wPt = 72*SetWidthIn
        Variable hPt = 72*SetHeightIn

        for (i=0; i<n; i+=1)
            if (ObjSel[i] == 0)
                continue
            endif
            LJZ_LT_ModifyByIndex(lay, ObjIndex[i], "width", wPt)
            LJZ_LT_ModifyByIndex(lay, ObjIndex[i], "height", hPt)
        endfor

        LJZ_LT_ScanObjects(lay)
        LJZ_LT_SyncPanel()
    endif
    return 0
End

Function LJZ_LT_BtnSameW(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode == 2)
        String lay = LJZ_LT_CurrentLayout()
        Variable ref = LJZ_LT_FirstSelectedRow()
        if (strlen(lay) <= 0 || ref < 0)
            DoAlert 0, "Select at least one object."
            return 0
        endif

        Wave ObjWidth = root:Packages:ARPES_LJZ:LayoutTool:ObjWidth
        Wave ObjIndex = root:Packages:ARPES_LJZ:LayoutTool:ObjIndex
        Wave/U/B ObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel

        Variable refW = ObjWidth[ref]
        Variable i, n = DimSize(ObjSel,0)
        for (i=0; i<n; i+=1)
            if (ObjSel[i] != 0)
                LJZ_LT_ModifyByIndex(lay, ObjIndex[i], "width", refW)
            endif
        endfor

        LJZ_LT_ScanObjects(lay)
        LJZ_LT_SyncPanel()
    endif
    return 0
End

Function LJZ_LT_BtnSameH(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode == 2)
        String lay = LJZ_LT_CurrentLayout()
        Variable ref = LJZ_LT_FirstSelectedRow()
        if (strlen(lay) <= 0 || ref < 0)
            DoAlert 0, "Select at least one object."
            return 0
        endif

        Wave ObjHeight = root:Packages:ARPES_LJZ:LayoutTool:ObjHeight
        Wave ObjIndex = root:Packages:ARPES_LJZ:LayoutTool:ObjIndex
        Wave/U/B ObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel

        Variable refH = ObjHeight[ref]
        Variable i, n = DimSize(ObjSel,0)
        for (i=0; i<n; i+=1)
            if (ObjSel[i] != 0)
                LJZ_LT_ModifyByIndex(lay, ObjIndex[i], "height", refH)
            endif
        endfor

        LJZ_LT_ScanObjects(lay)
        LJZ_LT_SyncPanel()
    endif
    return 0
End

Function LJZ_LT_BtnSameWH(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode == 2)
        String lay = LJZ_LT_CurrentLayout()
        Variable ref = LJZ_LT_FirstSelectedRow()
        if (strlen(lay) <= 0 || ref < 0)
            DoAlert 0, "Select at least one object."
            return 0
        endif

        Wave ObjWidth = root:Packages:ARPES_LJZ:LayoutTool:ObjWidth
        Wave ObjHeight = root:Packages:ARPES_LJZ:LayoutTool:ObjHeight
        Wave ObjIndex = root:Packages:ARPES_LJZ:LayoutTool:ObjIndex
        Wave/U/B ObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel

        Variable refW = ObjWidth[ref]
        Variable refH = ObjHeight[ref]
        Variable i, n = DimSize(ObjSel,0)
        for (i=0; i<n; i+=1)
            if (ObjSel[i] != 0)
                LJZ_LT_ModifyByIndex(lay, ObjIndex[i], "width", refW)
                LJZ_LT_ModifyByIndex(lay, ObjIndex[i], "height", refH)
            endif
        endfor

        LJZ_LT_ScanObjects(lay)
        LJZ_LT_SyncPanel()
    endif
    return 0
End

// ============================================================
// Buttons: align / normalize
// ============================================================
Function LJZ_LT_BtnAlignL(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode == 2)
        String lay = LJZ_LT_CurrentLayout()
        Variable ref = LJZ_LT_FirstSelectedRow()
        if (strlen(lay) <= 0 || ref < 0)
            DoAlert 0, "Select at least one object."
            return 0
        endif

        Wave ObjLeft = root:Packages:ARPES_LJZ:LayoutTool:ObjLeft
        Wave ObjIndex = root:Packages:ARPES_LJZ:LayoutTool:ObjIndex
        Wave/U/B ObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel

        Variable refL = ObjLeft[ref]
        Variable i, n = DimSize(ObjSel,0)
        for (i=0; i<n; i+=1)
            if (ObjSel[i] != 0)
                LJZ_LT_ModifyByIndex(lay, ObjIndex[i], "left", refL)
            endif
        endfor

        LJZ_LT_ScanObjects(lay)
        LJZ_LT_SyncPanel()
    endif
    return 0
End

Function LJZ_LT_BtnAlignT(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode == 2)
        String lay = LJZ_LT_CurrentLayout()
        Variable ref = LJZ_LT_FirstSelectedRow()
        if (strlen(lay) <= 0 || ref < 0)
            DoAlert 0, "Select at least one object."
            return 0
        endif

        Wave ObjTop = root:Packages:ARPES_LJZ:LayoutTool:ObjTop
        Wave ObjIndex = root:Packages:ARPES_LJZ:LayoutTool:ObjIndex
        Wave/U/B ObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel

        Variable refT = ObjTop[ref]
        Variable i, n = DimSize(ObjSel,0)
        for (i=0; i<n; i+=1)
            if (ObjSel[i] != 0)
                LJZ_LT_ModifyByIndex(lay, ObjIndex[i], "top", refT)
            endif
        endfor

        LJZ_LT_ScanObjects(lay)
        LJZ_LT_SyncPanel()
    endif
    return 0
End

Function LJZ_LT_BtnNormalize(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode == 2)
        String lay = LJZ_LT_CurrentLayout()
        if (strlen(lay) <= 0)
            DoAlert 0, "No valid layout selected."
            return 0
        endif

        Wave ObjIndex = root:Packages:ARPES_LJZ:LayoutTool:ObjIndex
        Wave/U/B ObjSel = root:Packages:ARPES_LJZ:LayoutTool:ObjSel

        Variable i, n = DimSize(ObjSel,0)
        for (i=0; i<n; i+=1)
            if (ObjSel[i] != 0)
                LJZ_LT_StyleByIndex(lay, ObjIndex[i], 0, 1, 1)
            endif
        endfor

        LJZ_LT_ScanObjects(lay)
        LJZ_LT_SyncPanel()
    endif
    return 0
End

// ============================================================
// Buttons: distribute
// ============================================================
Function LJZ_LT_BtnDistH(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode == 2)
        String lay = LJZ_LT_CurrentLayout()
        if (strlen(lay) <= 0)
            DoAlert 0, "No valid layout selected."
            return 0
        endif

        String rowPath = "root:Packages:ARPES_LJZ:LayoutTool:tmpRows"
        Variable k = LJZ_LT_GetSelectedRows(rowPath)
        if (k < 2)
            DoAlert 0, "Select at least two objects."
            KillWaves/Z $rowPath
            return 0
        endif

        NVAR GapHIn = root:Packages:ARPES_LJZ:LayoutTool:GapHIn
        Wave rows = $rowPath
        Wave ObjLeft = root:Packages:ARPES_LJZ:LayoutTool:ObjLeft
        Wave ObjTop = root:Packages:ARPES_LJZ:LayoutTool:ObjTop
        Wave ObjWidth = root:Packages:ARPES_LJZ:LayoutTool:ObjWidth
        Wave ObjIndex = root:Packages:ARPES_LJZ:LayoutTool:ObjIndex

        Make/O/D/N=(k) root:Packages:ARPES_LJZ:LayoutTool:tmpPosH
        Make/O/D/N=(k) root:Packages:ARPES_LJZ:LayoutTool:tmpWidH
        Make/O/D/N=(k) root:Packages:ARPES_LJZ:LayoutTool:tmpIdxH

        Wave posW = root:Packages:ARPES_LJZ:LayoutTool:tmpPosH
        Wave widW = root:Packages:ARPES_LJZ:LayoutTool:tmpWidH
        Wave idxW = root:Packages:ARPES_LJZ:LayoutTool:tmpIdxH

        Variable i, r
        for (i=0; i<k; i+=1)
            r = rows[i]
            posW[i] = ObjLeft[r]
            widW[i] = ObjWidth[r]
            idxW[i] = r
        endfor

        Sort posW, posW, widW, idxW

        Variable baseTop = ObjTop[idxW[0]]
        Variable curLeft = posW[0]
        Variable gapPt = 72*GapHIn

        LJZ_LT_ModifyByIndex(lay, ObjIndex[idxW[0]], "top", baseTop)
        for (i=1; i<k; i+=1)
            curLeft += widW[i-1] + gapPt
            LJZ_LT_ModifyByIndex(lay, ObjIndex[idxW[i]], "left", curLeft)
            LJZ_LT_ModifyByIndex(lay, ObjIndex[idxW[i]], "top", baseTop)
        endfor

        KillWaves/Z rows, posW, widW, idxW
        LJZ_LT_ScanObjects(lay)
        LJZ_LT_SyncPanel()
    endif
    return 0
End

Function LJZ_LT_BtnDistV(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode == 2)
        String lay = LJZ_LT_CurrentLayout()
        if (strlen(lay) <= 0)
            DoAlert 0, "No valid layout selected."
            return 0
        endif

        String rowPath = "root:Packages:ARPES_LJZ:LayoutTool:tmpRows"
        Variable k = LJZ_LT_GetSelectedRows(rowPath)
        if (k < 2)
            DoAlert 0, "Select at least two objects."
            KillWaves/Z $rowPath
            return 0
        endif

        NVAR GapVIn = root:Packages:ARPES_LJZ:LayoutTool:GapVIn
        Wave rows = $rowPath
        Wave ObjLeft = root:Packages:ARPES_LJZ:LayoutTool:ObjLeft
        Wave ObjTop = root:Packages:ARPES_LJZ:LayoutTool:ObjTop
        Wave ObjHeight = root:Packages:ARPES_LJZ:LayoutTool:ObjHeight
        Wave ObjIndex = root:Packages:ARPES_LJZ:LayoutTool:ObjIndex

        Make/O/D/N=(k) root:Packages:ARPES_LJZ:LayoutTool:tmpPosV
        Make/O/D/N=(k) root:Packages:ARPES_LJZ:LayoutTool:tmpHeiV
        Make/O/D/N=(k) root:Packages:ARPES_LJZ:LayoutTool:tmpIdxV

        Wave posW = root:Packages:ARPES_LJZ:LayoutTool:tmpPosV
        Wave heiW = root:Packages:ARPES_LJZ:LayoutTool:tmpHeiV
        Wave idxW = root:Packages:ARPES_LJZ:LayoutTool:tmpIdxV

        Variable i, r
        for (i=0; i<k; i+=1)
            r = rows[i]
            posW[i] = ObjTop[r]
            heiW[i] = ObjHeight[r]
            idxW[i] = r
        endfor

        Sort posW, posW, heiW, idxW

        Variable baseLeft = ObjLeft[idxW[0]]
        Variable curTop = posW[0]
        Variable gapPt = 72*GapVIn

        LJZ_LT_ModifyByIndex(lay, ObjIndex[idxW[0]], "left", baseLeft)
        for (i=1; i<k; i+=1)
            curTop += heiW[i-1] + gapPt
            LJZ_LT_ModifyByIndex(lay, ObjIndex[idxW[i]], "top", curTop)
            LJZ_LT_ModifyByIndex(lay, ObjIndex[idxW[i]], "left", baseLeft)
        endfor

        KillWaves/Z rows, posW, heiW, idxW
        LJZ_LT_ScanObjects(lay)
        LJZ_LT_SyncPanel()
    endif
    return 0
End

// ============================================================
// Buttons: tile
// ============================================================
Function LJZ_LT_BtnTile(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode == 2)
        String lay = LJZ_LT_CurrentLayout()
        if (strlen(lay) <= 0)
            DoAlert 0, "No valid layout selected."
            return 0
        endif

        String rowPath = "root:Packages:ARPES_LJZ:LayoutTool:tmpRows"
        Variable k = LJZ_LT_GetSelectedRows(rowPath)
        if (k < 1)
            DoAlert 0, "Select at least one object."
            KillWaves/Z $rowPath
            return 0
        endif

        NVAR TileRows = root:Packages:ARPES_LJZ:LayoutTool:TileRows
        NVAR TileCols = root:Packages:ARPES_LJZ:LayoutTool:TileCols
        NVAR SetWidthIn = root:Packages:ARPES_LJZ:LayoutTool:SetWidthIn
        NVAR SetHeightIn = root:Packages:ARPES_LJZ:LayoutTool:SetHeightIn
        NVAR GapHIn = root:Packages:ARPES_LJZ:LayoutTool:GapHIn
        NVAR GapVIn = root:Packages:ARPES_LJZ:LayoutTool:GapVIn

        if (TileRows <= 0 || TileCols <= 0)
            DoAlert 0, "Rows/Cols must be positive."
            KillWaves/Z $rowPath
            return 0
        endif
        if (TileRows*TileCols < k)
            DoAlert 0, "Rows*Cols is smaller than the number of selected objects."
            KillWaves/Z $rowPath
            return 0
        endif

        Wave rows = $rowPath
        Wave ObjLeft = root:Packages:ARPES_LJZ:LayoutTool:ObjLeft
        Wave ObjTop = root:Packages:ARPES_LJZ:LayoutTool:ObjTop
        Wave ObjWidth = root:Packages:ARPES_LJZ:LayoutTool:ObjWidth
        Wave ObjHeight = root:Packages:ARPES_LJZ:LayoutTool:ObjHeight
        Wave ObjIndex = root:Packages:ARPES_LJZ:LayoutTool:ObjIndex

        Variable firstRow = rows[0]
        Variable baseLeft = ObjLeft[firstRow]
        Variable baseTop = ObjTop[firstRow]

        Variable wPt, hPt
        if (SetWidthIn > 0)
            wPt = 72*SetWidthIn
        else
            wPt = ObjWidth[firstRow]
        endif
        if (SetHeightIn > 0)
            hPt = 72*SetHeightIn
        else
            hPt = ObjHeight[firstRow]
        endif

        Variable gapHPt = 72*GapHIn
        Variable gapVPt = 72*GapVIn

        Variable i, rr, cc, leftPt, topPt
        for (i=0; i<k; i+=1)
            rr = floor(i/TileCols)
            cc = i - rr*TileCols

            leftPt = baseLeft + cc*(wPt + gapHPt)
            topPt = baseTop + rr*(hPt + gapVPt)

            LJZ_LT_ModifyByIndex(lay, ObjIndex[rows[i]], "left", leftPt)
            LJZ_LT_ModifyByIndex(lay, ObjIndex[rows[i]], "top", topPt)
            LJZ_LT_ModifyByIndex(lay, ObjIndex[rows[i]], "width", wPt)
            LJZ_LT_ModifyByIndex(lay, ObjIndex[rows[i]], "height", hPt)
        endfor

        KillWaves/Z rows
        LJZ_LT_ScanObjects(lay)
        LJZ_LT_SyncPanel()
    endif
    return 0
End



Function LJZ_LT_StrContains_NoCase(s, key)
    String s, key

    String ss = LowerStr(s)
    String kk = LowerStr(key)

    if (strlen(kk) <= 0)
        return 1
    endif

    return (strsearch(ss, kk, 0) >= 0)
End

Function LJZ_LT_RebuildAppendView()
    Wave/T/Z AppendRawName = root:Packages:ARPES_LJZ:LayoutTool:AppendRawName
    Wave/T/Z AppendRawSpec = root:Packages:ARPES_LJZ:LayoutTool:AppendRawSpec

    Wave/T/Z AppendViewName = root:Packages:ARPES_LJZ:LayoutTool:AppendViewName
    Wave/T/Z AppendViewSpec = root:Packages:ARPES_LJZ:LayoutTool:AppendViewSpec
    Wave/U/B/Z AppendViewSel = root:Packages:ARPES_LJZ:LayoutTool:AppendViewSel
    Wave/Z AppendViewMap = root:Packages:ARPES_LJZ:LayoutTool:AppendViewMap

    SVAR/Z AppendSearch = root:Packages:ARPES_LJZ:LayoutTool:AppendSearch

    if (!WaveExists(AppendRawName) || !WaveExists(AppendRawSpec) || !WaveExists(AppendViewName) || !WaveExists(AppendViewSpec) || !WaveExists(AppendViewSel) || !WaveExists(AppendViewMap) || !SVAR_Exists(AppendSearch))
        return 0
    endif

    Variable nRaw = DimSize(AppendRawName, 0)
    Variable i, nHit = 0

    for (i=0; i<nRaw; i+=1)
        if (LJZ_LT_StrContains_NoCase(AppendRawName[i], AppendSearch) || LJZ_LT_StrContains_NoCase(AppendRawSpec[i], AppendSearch))
            nHit += 1
        endif
    endfor

    Redimension/N=(nHit) AppendViewName, AppendViewSpec, AppendViewSel, AppendViewMap

    Variable j = 0
    for (i=0; i<nRaw; i+=1)
        if (LJZ_LT_StrContains_NoCase(AppendRawName[i], AppendSearch) || LJZ_LT_StrContains_NoCase(AppendRawSpec[i], AppendSearch))
            AppendViewName[j] = AppendRawName[i]
            AppendViewSpec[j] = AppendRawSpec[i]
            AppendViewSel[j]  = 0
            AppendViewMap[j]  = i
            j += 1
        endif
    endfor

    DoWindow LJZ_LayoutTool_Panel
    if (V_flag)
        ControlUpdate/W=LJZ_LayoutTool_Panel lbAppend
    endif

    return 0
End

Function LJZ_LT_SVAppendSearchProc(ctrlName, varNum, varStr, varName) : SetVariableControl
    String ctrlName, varStr, varName
    Variable varNum

    LJZ_LT_RebuildAppendView()
    return 0
End

Function LJZ_LT_BtnAppendSearchClear(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    SVAR/Z AppendSearch = root:Packages:ARPES_LJZ:LayoutTool:AppendSearch
    if (SVAR_Exists(AppendSearch))
        AppendSearch = ""
    endif

    ControlUpdate/W=LJZ_LayoutTool_Panel svAppendSearch
    LJZ_LT_RebuildAppendView()
    return 0
End