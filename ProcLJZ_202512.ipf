#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3


//============================================================
// Helpers
//============================================================
Function s6_ensure_folder()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:SHOW6LAYER
End

Function/S s6_df_with_colon(inStr)
    String inStr
    String s = inStr

    if (strlen(s) == 0)
        return "root:"
    endif

    if (StringMatch(s, "root"))
        s = "root:"
    endif

    // avoid s[...], use pattern match
    if (!StringMatch(s, "*:"))
        s += ":"
    endif

    return s
End

Function s6_df_exists(dfStr)
    String dfStr
    DFREF dfr = $dfStr
    return DataFolderRefStatus(dfr) != 0
End

//============================================================
// Defaults
//============================================================
Function s6_init_defaults_if_needed()
    s6_ensure_folder()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:SHOW6LAYER

    if (!WaveExists($"LB_Items"))
        Make/O/T/N=0 LB_Items
    endif
    if (!WaveExists($"LB_Sel"))
        Make/O/U/B/N=0 LB_Sel
    endif

    SVAR/Z s6_wavePath = root:ARPES_LJZ:SHOW6LAYER:s6_wavePath
    if (!SVAR_Exists(s6_wavePath))
        String/G s6_wavePath = ""
    endif

    SVAR/Z s6_baseDF = root:ARPES_LJZ:SHOW6LAYER:s6_baseDF
    if (!SVAR_Exists(s6_baseDF))
        String/G s6_baseDF = "root:"
    endif

    NVAR/Z s6_recursive = root:ARPES_LJZ:SHOW6LAYER:s6_recursive
    if (!NVAR_Exists(s6_recursive))
        Variable/G s6_recursive = 0
    endif

    NVAR/Z s6_l1 = root:ARPES_LJZ:SHOW6LAYER:s6_l1
    if (!NVAR_Exists(s6_l1))
        Variable/G s6_l1=0, s6_l2=1, s6_l3=2, s6_l4=3, s6_l5=4, s6_l6=5
    endif

    NVAR/Z s6_xMin = root:ARPES_LJZ:SHOW6LAYER:s6_xMin
    if (!NVAR_Exists(s6_xMin))
        Variable/G s6_xMin=-0.27, s6_xMax=-0.06
        Variable/G s6_useYLim=0, s6_yMin=NaN, s6_yMax=NaN
    endif

    NVAR/Z s6_labelType = root:ARPES_LJZ:SHOW6LAYER:s6_labelType
    if (!NVAR_Exists(s6_labelType))
        Variable/G s6_labelType = 0
    endif

    SVAR/Z s6_ctPick = root:ARPES_LJZ:SHOW6LAYER:s6_ctPick
    if (!SVAR_Exists(s6_ctPick))
        String/G s6_ctPick = "None"
    endif

    NVAR/Z s6_useLUT = root:ARPES_LJZ:SHOW6LAYER:s6_useLUT
    if (!NVAR_Exists(s6_useLUT))
        Variable/G s6_useLUT = 1
    endif
    // ---- TextBox style defaults ----
    NVAR/Z s6_tbFontSize = root:ARPES_LJZ:SHOW6LAYER:s6_tbFontSize
    if (!NVAR_Exists(s6_tbFontSize))
        Variable/G s6_tbFontSize = 12
    endif

    NVAR/Z s6_tbX = root:ARPES_LJZ:SHOW6LAYER:s6_tbX
    if (!NVAR_Exists(s6_tbX))
        Variable/G s6_tbX = 20       // percent
    endif

    NVAR/Z s6_tbY = root:ARPES_LJZ:SHOW6LAYER:s6_tbY
    if (!NVAR_Exists(s6_tbY))
        Variable/G s6_tbY = 25       // percent
    endif
// ---- Dim2 info cache (for panel display) ----
NVAR/Z s6_dim2_off = root:ARPES_LJZ:SHOW6LAYER:s6_dim2_off
if (!NVAR_Exists(s6_dim2_off))
    Variable/G s6_dim2_off = NaN
endif

NVAR/Z s6_dim2_del = root:ARPES_LJZ:SHOW6LAYER:s6_dim2_del
if (!NVAR_Exists(s6_dim2_del))
    Variable/G s6_dim2_del = NaN
endif

NVAR/Z s6_dim2_n = root:ARPES_LJZ:SHOW6LAYER:s6_dim2_n
if (!NVAR_Exists(s6_dim2_n))
    Variable/G s6_dim2_n = NaN
endif

NVAR/Z s6_dim2_v0 = root:ARPES_LJZ:SHOW6LAYER:s6_dim2_v0
if (!NVAR_Exists(s6_dim2_v0))
    Variable/G s6_dim2_v0 = NaN
endif

NVAR/Z s6_dim2_v1 = root:ARPES_LJZ:SHOW6LAYER:s6_dim2_v1
if (!NVAR_Exists(s6_dim2_v1))
    Variable/G s6_dim2_v1 = NaN
endif

    SetDataFolder df0
End

//============================================================
// Entry
//============================================================
Proc SHOW6LAYER_LJZ()
    s6_init_defaults_if_needed()

    DoWindow/F SHOW6LAYER_LJZ_P
    if (V_flag == 0)
        SHOW6LAYER_LJZ_P()
    endif

    // refresh CT menu list (requires CTLUZ loaded)
    ctluz_ensure_folder()
    ctluz_refresh_ctlib_menu()

    s6_rebuild_lb()
End

//============================================================
// Recursive scan: returns FULL PATH list, only 3D waves
//============================================================
Function/S s6_collect_3d_waves_recursive(baseDF)
    String baseDF

    String df0 = GetDataFolder(1)
    String outList = ""

    if (!s6_df_exists(baseDF))
        return ""
    endif

    SetDataFolder $baseDF
    String here = WaveList("*", ";", "DIMS:3")
    Variable i, n = ItemsInList(here, ";")
    for (i=0; i<n; i+=1)
        String wn = StringFromList(i, here, ";")
        if (strlen(wn) == 0)
            continue
        endif
        outList += (baseDF + wn + ";")
    endfor

    String subList = DataFolderDir(2)   // "folder1;folder2;..."
    Variable m = ItemsInList(subList, ";")
    for (i=0; i<m; i+=1)
        String fd = StringFromList(i, subList, ";")
        if (strlen(fd) == 0)
            continue
        endif
        outList += s6_collect_3d_waves_recursive(baseDF + fd + ":")
    endfor

    SetDataFolder df0
    return outList
End

//============================================================
// List build
//============================================================
Function s6_rebuild_lb()
    s6_ensure_folder()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:SHOW6LAYER

    SVAR s6_baseDF = root:ARPES_LJZ:SHOW6LAYER:s6_baseDF
    NVAR s6_recursive = root:ARPES_LJZ:SHOW6LAYER:s6_recursive
    SVAR s6_wavePath = root:ARPES_LJZ:SHOW6LAYER:s6_wavePath

    Wave/T   LB_Items = root:ARPES_LJZ:SHOW6LAYER:LB_Items
    Wave/U/B LB_Sel   = root:ARPES_LJZ:SHOW6LAYER:LB_Sel

    Redimension/N=0 LB_Items, LB_Sel
    s6_wavePath = ""

    String base = s6_df_with_colon(s6_baseDF)
    if (!s6_df_exists(base))
        base = "root:"
    endif
    s6_baseDF = base

    String listStr
    if (s6_recursive)
        listStr = s6_collect_3d_waves_recursive(base)     // full paths
    else
        String df1 = GetDataFolder(1)
        SetDataFolder $base
        listStr = WaveList("*", ";", "DIMS:3")             // names only
        SetDataFolder df1
    endif

    Variable n = ItemsInList(listStr, ";")
    if (n > 0)
        Redimension/N=(n) LB_Items, LB_Sel
        Variable i
        for (i=0; i<n; i+=1)
            LB_Items[i] = StringFromList(i, listStr, ";")
            LB_Sel[i] = 0
        endfor
    endif

    SetDataFolder df0
    DoWindow SHOW6LAYER_LJZ_P
    if (V_flag)
        ControlUpdate/W=SHOW6LAYER_LJZ_P s6_lb
        TitleBox s6_status, win=SHOW6LAYER_LJZ_P, title="Selected: (none)"
    endif
    return 0
End

//============================================================
// ListBox proc: single select
//============================================================
Function s6_lb_proc(ctrlName, row, col, eventCode) : ListBoxControl
    String ctrlName
    Variable row, col, eventCode

    if (eventCode != 4)
        return 0
    endif

    Wave/U/B LB_Sel = root:ARPES_LJZ:SHOW6LAYER:LB_Sel
    Wave/T   LB_Items = root:ARPES_LJZ:SHOW6LAYER:LB_Items
    SVAR     s6_wavePath = root:ARPES_LJZ:SHOW6LAYER:s6_wavePath
    SVAR     s6_baseDF = root:ARPES_LJZ:SHOW6LAYER:s6_baseDF
    NVAR     s6_recursive = root:ARPES_LJZ:SHOW6LAYER:s6_recursive

    if (row < 0 || row >= DimSize(LB_Items, 0))
        return 0
    endif

    LB_Sel = 0
    LB_Sel[row] = 1

    String item = LB_Items[row]
    if (strlen(item) == 0)
        s6_wavePath = ""
    else
        if (s6_recursive)
            s6_wavePath = item
        else
            String base = s6_df_with_colon(s6_baseDF)
            s6_baseDF = base
            s6_wavePath = base + item
        endif
    endif

    DoWindow SHOW6LAYER_LJZ_P
    if (V_flag)
        TitleBox s6_status, win=SHOW6LAYER_LJZ_P, title="Selected: " + s6_wavePath
    endif
    return 0
End

//============================================================
// Popup procs
//============================================================
Function s6_pm_ct_proc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName
    Variable popNum
    String popStr
    SVAR s6_ctPick = root:ARPES_LJZ:SHOW6LAYER:s6_ctPick
    s6_ctPick = popStr
    return 0
End

Function s6_pm_label_proc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName
    Variable popNum
    String popStr
    Variable v = str2num(StringFromList(0, popStr, ":"))
    if (numtype(v) != 0)
        v = 0
    endif
    NVAR s6_labelType = root:ARPES_LJZ:SHOW6LAYER:s6_labelType
    s6_labelType = v
    return 0
End

//============================================================
// Buttons
//============================================================
Function s6_btn_scan(ctrlName) : ButtonControl
    String ctrlName
    s6_rebuild_lb()
    return 0
End

Function s6_btn_refresh_ct(ctrlName) : ButtonControl
    String ctrlName
    ctluz_ensure_folder()
    ctluz_refresh_ctlib_menu()
    ControlUpdate/W=SHOW6LAYER_LJZ_P s6_pm_ct
    return 0
End

Function s6_btn_run(ctrlName) : ButtonControl
    String ctrlName

    SVAR s6_wavePath = root:ARPES_LJZ:SHOW6LAYER:s6_wavePath
    if (strlen(s6_wavePath) == 0)
        Abort "Show6Layers: No wave selected."
    endif

    Wave/Z w = $s6_wavePath
    if (!WaveExists(w))
        Abort "Show6Layers: selected wave not found."
    endif
    if (WaveDims(w) != 3)
        Abort "Show6Layers: selected wave is not 3D."
    endif

    NVAR s6_l1=root:ARPES_LJZ:SHOW6LAYER:s6_l1; NVAR s6_l2=root:ARPES_LJZ:SHOW6LAYER:s6_l2
    NVAR s6_l3=root:ARPES_LJZ:SHOW6LAYER:s6_l3; NVAR s6_l4=root:ARPES_LJZ:SHOW6LAYER:s6_l4
    NVAR s6_l5=root:ARPES_LJZ:SHOW6LAYER:s6_l5; NVAR s6_l6=root:ARPES_LJZ:SHOW6LAYER:s6_l6

    NVAR s6_xMin=root:ARPES_LJZ:SHOW6LAYER:s6_xMin; NVAR s6_xMax=root:ARPES_LJZ:SHOW6LAYER:s6_xMax
    NVAR s6_useYLim=root:ARPES_LJZ:SHOW6LAYER:s6_useYLim
    NVAR s6_yMin=root:ARPES_LJZ:SHOW6LAYER:s6_yMin; NVAR s6_yMax=root:ARPES_LJZ:SHOW6LAYER:s6_yMax
    NVAR s6_labelType=root:ARPES_LJZ:SHOW6LAYER:s6_labelType

    SVAR s6_ctPick=root:ARPES_LJZ:SHOW6LAYER:s6_ctPick
    NVAR s6_useLUT=root:ARPES_LJZ:SHOW6LAYER:s6_useLUT
    NVAR s6_tbFontSize=root:ARPES_LJZ:SHOW6LAYER:s6_tbFontSize
    NVAR s6_tbX=root:ARPES_LJZ:SHOW6LAYER:s6_tbX
    NVAR s6_tbY=root:ARPES_LJZ:SHOW6LAYER:s6_tbY

    if (s6_xMin >= s6_xMax)
        Abort "Show6Layers: xMin must be < xMax."
    endif

    Variable yy0=NaN, yy1=NaN
    if (s6_useYLim)
        if (numtype(s6_yMin)!=0 || numtype(s6_yMax)!=0)
            Abort "Show6Layers: yMin/yMax must be numbers when Use YLim is checked."
        endif
        if (s6_yMin >= s6_yMax)
            Abort "Show6Layers: yMin must be < yMax."
        endif
        yy0 = s6_yMin
        yy1 = s6_yMax
    endif

    String ctSel = ""
    if (!StringMatch(s6_ctPick, "None"))
        ctSel = s6_ctPick
    endif

    // Your function must support ctName/useLUT; otherwise remove these two args.
    Show6Layers_LJZ20251226(w, s6_l1, s6_l2, s6_l3, s6_l4, s6_l5, s6_l6, \
    labelType=s6_labelType, \
    xMin=s6_xMin, xMax=s6_xMax, \
    yMin=yy0, yMax=yy1, \
    ctName=ctSel, useLUT=s6_useLUT, \
    tbFont=s6_tbFontSize, tbX=s6_tbX, tbY=s6_tbY)

    return 0
End

Function s6_btn_close(ctrlName) : ButtonControl
    String ctrlName
    DoWindow/K SHOW6LAYER_LJZ_P
    return 0
End

//============================================================
// Panel
//============================================================
Window SHOW6LAYER_LJZ_P() : Panel
    PauseUpdate; Silent 1        // building window...
    NewPanel /W=(420,49.8,941.4,615) as "Show6Layers (LJZ)"
    ModifyPanel frameStyle=1
    ShowTools/A

    // ===== Header =====
    TitleBox s6_t0,pos={12.00,9.00},size={500.00,18.00},title="Show 6 layers from a 3D wave (independent module; CT from CTLUZ library)"
    TitleBox s6_t0,frame=0

    TitleBox s6_status,pos={12.00,27.00},size={500.00,18.00},title="Selected: (none)"
    TitleBox s6_status,frame=0

    // ===== Base DF + Scan =====
    TitleBox s6_tdf,pos={12.00,51.00},size={47.40,18.00},title="Base DF:",frame=0
    SetVariable s6_sv_df,pos={84.00,48.00},size={249.00,19.80}
    SetVariable s6_sv_df,value= root:ARPES_LJZ:SHOW6LAYER:s6_baseDF

    CheckBox s6_ck_rec,pos={348.00,51.00},size={63.60,18.00},title="Recursive"
    CheckBox s6_ck_rec,variable= root:ARPES_LJZ:SHOW6LAYER:s6_recursive

    Button s6_btn_scan,pos={438.00,48.00},size={69.00,21.00},proc=s6_btn_scan,title="Scan"

    // ===== ListBox =====
    ListBox s6_lb,pos={12.00,78.00},size={249.00,345.00},proc=s6_lb_proc
    ListBox s6_lb,listWave=root:ARPES_LJZ:SHOW6LAYER:LB_Items
    ListBox s6_lb,selWave=root:ARPES_LJZ:SHOW6LAYER:LB_Sel,mode=1,selRow=3

    // ===== Right column: Layers =====
    TitleBox s6_tl,pos={279.00,78.00},size={120.00,18.00},title="Layers (z index):"
    TitleBox s6_tl,frame=0

    SetVariable s6_sv_l1,pos={279.00,102.00},size={108.00,19.80},title="l1"
    SetVariable s6_sv_l1,limits={0,inf,1},value= root:ARPES_LJZ:SHOW6LAYER:s6_l1
    SetVariable s6_sv_l2,pos={399.00,102.00},size={108.00,19.80},title="l2"
    SetVariable s6_sv_l2,limits={0,inf,1},value= root:ARPES_LJZ:SHOW6LAYER:s6_l2

    SetVariable s6_sv_l3,pos={279.00,126.00},size={108.00,19.80},title="l3"
    SetVariable s6_sv_l3,limits={0,inf,1},value= root:ARPES_LJZ:SHOW6LAYER:s6_l3
    SetVariable s6_sv_l4,pos={399.00,126.00},size={108.00,19.80},title="l4"
    SetVariable s6_sv_l4,limits={0,inf,1},value= root:ARPES_LJZ:SHOW6LAYER:s6_l4

    SetVariable s6_sv_l5,pos={279.00,150.00},size={108.00,19.80},title="l5"
    SetVariable s6_sv_l5,limits={0,inf,1},value= root:ARPES_LJZ:SHOW6LAYER:s6_l5
    SetVariable s6_sv_l6,pos={399.00,150.00},size={108.00,19.80},title="l6"
    SetVariable s6_sv_l6,limits={0,inf,1},value= root:ARPES_LJZ:SHOW6LAYER:s6_l6

    // ===== Axes (Aligned) =====
    TitleBox s6_tax,pos={279.00,180.00},size={50.00,18.00},title="Axes:"
    TitleBox s6_tax,frame=0

    // xMin / xMax (same row)
    SetVariable s6_sv_x0,pos={279.00,204.00},size={108.00,19.80},title="xMin"
    SetVariable s6_sv_x0,value= root:ARPES_LJZ:SHOW6LAYER:s6_xMin
    SetVariable s6_sv_x1,pos={399.00,204.00},size={108.00,19.80},title="xMax"
    SetVariable s6_sv_x1,value= root:ARPES_LJZ:SHOW6LAYER:s6_xMax

    // UseYlim + yMin/yMax aligned
    CheckBox s6_ck_y,pos={279.00,228.00},size={80.00,18.00},title="Use YLim"
    CheckBox s6_ck_y,variable= root:ARPES_LJZ:SHOW6LAYER:s6_useYLim

    SetVariable s6_sv_y0,pos={279.00,252.00},size={108.00,19.80},title="yMin"
    SetVariable s6_sv_y0,value= root:ARPES_LJZ:SHOW6LAYER:s6_yMin
    SetVariable s6_sv_y1,pos={399.00,252.00},size={108.00,19.80},title="yMax"
    SetVariable s6_sv_y1,value= root:ARPES_LJZ:SHOW6LAYER:s6_yMax

    // ===== Dim2 label =====
    TitleBox s6_tlab,pos={279.00,282.00},size={75.00,18.00},title="Dim2 label:"
    TitleBox s6_tlab,frame=0
    PopupMenu s6_pm_lab,pos={360.00,279.00},size={147.00,20.40},proc=s6_pm_label_proc
    PopupMenu s6_pm_lab,mode=3,popvalue="2:Delay (ps)",value= #"\"0:None;1:Fluence (μJ/cm^2);2:Delay (ps);3:Temp (K);\""

    // ===== CT / LUT =====
    TitleBox s6_tct,pos={279.00,312.00},size={220.00,18.00},title="CT palette (from CTLUZ CTLIB):"
    TitleBox s6_tct,frame=0
    PopupMenu s6_pm_ct,pos={279.00,333.00},size={120.00,20.40},proc=s6_pm_ct_proc
    PopupMenu s6_pm_ct,mode=12,popvalue="Mualani",value= #"root:ARPES_LJZ:CTLUZ:ctlib_menu_list"

    CheckBox s6_ck_lut,pos={409.00,333.00},size={80.00,18.00},title="Use LUT"
    CheckBox s6_ck_lut,variable= root:ARPES_LJZ:SHOW6LAYER:s6_useLUT

    Button s6_btn_ctrefresh,pos={279.00,360.00},size={228.00,22.20},proc=s6_btn_refresh_ct,title="Refresh CT list"

    // ===== Run/Close/Help/Dim2 buttons (aligned 2 columns) =====
    Button s6_btn_run,pos={279.00,392.00},size={108.00,27.00},proc=s6_btn_run,title="Run"
    Button s6_btn_close,pos={399.00,392.00},size={108.00,27.00},proc=s6_btn_close,title="Close"

    Button s6_btn_help,pos={279.00,425.00},size={108.00,27.00},proc=s6_btn_help,title="Help"
    Button s6_btn_dim2,pos={399.00,425.00},size={108.00,27.00},proc=s6_btn_dim2info,title="Dim2 Info"

    // ===== Dim2 scaling display =====
    TitleBox s6_tdim2,pos={279.00,458.00},size={120.00,18.00},title="Dim2 scaling:"
    TitleBox s6_tdim2,frame=0

    SetVariable s6_sv_d2off,pos={279.00,478.00},size={228.00,19.80},title="Off"
    SetVariable s6_sv_d2off,limits={-inf,inf,0},value= root:ARPES_LJZ:SHOW6LAYER:s6_dim2_off,noedit=1

    SetVariable s6_sv_d2del,pos={279.00,503.00},size={108.00,19.80},title="Del"
    SetVariable s6_sv_d2del,limits={-inf,inf,0},value= root:ARPES_LJZ:SHOW6LAYER:s6_dim2_del,noedit=1

    SetVariable s6_sv_d2n,pos={399.00,503.00},size={108.00,19.80},title="N"
    SetVariable s6_sv_d2n,limits={-inf,inf,0},value= root:ARPES_LJZ:SHOW6LAYER:s6_dim2_n,noedit=1

    SetVariable s6_sv_d2v0,pos={279.00,528.00},size={108.00,19.80},title="Min"
    SetVariable s6_sv_d2v0,limits={-inf,inf,0},value= root:ARPES_LJZ:SHOW6LAYER:s6_dim2_v0,noedit=1

    SetVariable s6_sv_d2v1,pos={399.00,528.00},size={108.00,19.80},title="Max"
    SetVariable s6_sv_d2v1,limits={-inf,inf,0},value= root:ARPES_LJZ:SHOW6LAYER:s6_dim2_v1,noedit=1

    // ===== Left bottom: TextBox style =====
    TitleBox s6_ttb,pos={12.00,441.00},size={100.00,18.00},title="TextBox style:"
    TitleBox s6_ttb,frame=0

    SetVariable s6_sv_tbf,pos={12.00,462.00},size={249.00,19.80},title="Font"
    SetVariable s6_sv_tbf,limits={6,72,1},value= root:ARPES_LJZ:SHOW6LAYER:s6_tbFontSize

    SetVariable s6_sv_tbx,pos={12.00,486.00},size={249.00,19.80},title="X (%)"
    SetVariable s6_sv_tbx,limits={-100,100,1},value= root:ARPES_LJZ:SHOW6LAYER:s6_tbX

    SetVariable s6_sv_tby,pos={12.00,510.00},size={249.00,19.80},title="Y (%)"
    SetVariable s6_sv_tby,limits={-100,100,1},value= root:ARPES_LJZ:SHOW6LAYER:s6_tbY
EndMacro


//============================================================
// Helper: label text from Dim=2 scaling
// labelType: 0=none, 1=fluence (μJ/cm^2), 2=delay (ps), 3=temp (K)
//============================================================
Function/S LJZ_MakeLayerLabel_LJZ20251226(w, layerIndex, labelType)
    Wave w
    Variable layerIndex, labelType

    Variable o3 = DimOffset(w, 2)
    Variable d3 = DimDelta(w, 2)
    Variable val = o3 + d3 * layerIndex

    String unitStr = ""
    switch (round(labelType))
        case 1:
            unitStr = "μJ/cm\\S2\\M"
            break
        case 2:
            unitStr = "ps"
            break
        case 3:
            unitStr = "K"
            break
        default:
            unitStr = ""
            break
    endswitch

    Variable rval = round(val)
    String out
    if (abs(val - rval) < 1e-6)
        sprintf out, "%d %s", rval, unitStr
    else
        sprintf out, "%.3g %s", val, unitStr
    endif
    return out
End

//============================================================
// Show6Layers API (Igor-style optional params, NO keyword args)
// Optional params order:
//   mode, labelType, xMin, xMax, yMin, yMax, ctName, useLUT
// mode: 1..4 (your old meanings)
// ctName: "" means use CTLUZ current ct_table, else use CTLIB:ctName
// useLUT: 1 uses root:ARPES_LJZ:CTLUZ:ct_lut if exists, else no LUT
//============================================================
//Function Show6Layers_LJZ20251226(w, l1, l2, l3, l4, l5, l6[, labelType, xMin, xMax, yMin, yMax, ctName, useLUT, tbFont, tbX, tbY])
//    Wave w
//    Variable l1, l2, l3, l4, l5, l6
//    Variable tbFont, tbX, tbY
//    Variable labelType, xMin, xMax, yMin, yMax
//    String ctName
//    Variable useLUT
//
//    DFREF savedDF = GetDataFolderDFR()
//
//    // -------- defaults --------
//    if (ParamIsDefault(labelType))
//        labelType = 0
//    endif
//    if (ParamIsDefault(xMin))
//        xMin = -0.27
//    endif
//    if (ParamIsDefault(xMax))
//        xMax = -0.06
//    endif
//    if (ParamIsDefault(yMin))
//        yMin = NaN
//    endif
//    if (ParamIsDefault(yMax))
//        yMax = NaN
//    endif
//    if (ParamIsDefault(ctName))
//        ctName = ""
//    endif
//    if (ParamIsDefault(useLUT))
//        useLUT = 1
//    endif
//    if (ParamIsDefault(tbFont))
//        tbFont = 12
//    endif
//    if (ParamIsDefault(tbX))
//        tbX = 20
//    endif
//    if (ParamIsDefault(tbY))
//        tbY = 25
//    endif
//
//    // -------- checks --------
//    if (!WaveExists(w))
//        Abort "Show6Layers: input wave does not exist."
//    endif
//    if (WaveDims(w) != 3)
//        Abort "Show6Layers: input wave must be 3D."
//    endif
//    if (xMin >= xMax)
//        Abort "Show6Layers: xMin must be < xMax."
//    endif
//    if (numtype(yMin)==0 && numtype(yMax)==0)
//        if (yMin >= yMax)
//            Abort "Show6Layers: yMin must be < yMax."
//        endif
//    endif
//
//    Variable maxLayer = DimSize(w, 2) - 1
//    if (l1<0 || l2<0 || l3<0 || l4<0 || l5<0 || l6<0)
//        Abort "Show6Layers: layer index cannot be negative."
//    endif
//    if (l1>maxLayer || l2>maxLayer || l3>maxLayer || l4>maxLayer || l5>maxLayer || l6>maxLayer)
//        Abort "Show6Layers: layer index exceeds DimSize(w,2)-1."
//    endif
//
//    // -------- CT resolve --------
//    Wave/Z/W/U ctWave = root:ARPES_LJZ:CTLUZ:ct_table
//    Wave/Z     lutWave = root:ARPES_LJZ:CTLUZ:ct_lut
//
//    if (strlen(ctName) > 0)
//        Wave/Z/W/U tmpCT = $("root:ARPES_LJZ:CTLUZ:CTLIB:" + ctName)
//        if (WaveExists(tmpCT))
//            ctWave = tmpCT
//        endif
//    endif
//
//    Variable useLookup = (useLUT != 0) && WaveExists(lutWave)
//
//    // -------- layer order wave --------
//    Make/O/N=6 s6_layerOrder = {l1, l2, l3, l4, l5, l6}
//
//    // -------- layout window --------
//    String windName = "LayerComparison6_" + NameOfWave(w)
//    DoWindow/K $windName
//    NewLayout/N=$windName/P=LANDSCAPE/K=1
//
//    // temp folder
//    NewDataFolder/O/S root:ARPES_LJZ:SHOW6LAYER_TMP
//    String sub = CleanupName(NameOfWave(w) + "_6show", 0)
//    NewDataFolder/O/S $sub
//
//    // build 6 temporary 2D layers
//    Make/O/N=(DimSize(w,0), DimSize(w,1)) s6_im0, s6_im1, s6_im2, s6_im3, s6_im4, s6_im5
//    s6_im0[][] = w[p][q][l1]
//    s6_im1[][] = w[p][q][l2]
//    s6_im2[][] = w[p][q][l3]
//    s6_im3[][] = w[p][q][l4]
//    s6_im4[][] = w[p][q][l5]
//    s6_im5[][] = w[p][q][l6]
//
//    SetScale/P x DimOffset(w,0), DimDelta(w,0), s6_im0, s6_im1, s6_im2, s6_im3, s6_im4, s6_im5
//    SetScale/P y DimOffset(w,1), DimDelta(w,1), s6_im0, s6_im1, s6_im2, s6_im3, s6_im4, s6_im5
//
//    Variable graphWidth=100, graphHeight=200
//    Variable i, xStart
//
//    for (i=0; i<6; i+=1)
//        xStart = (i + 0.7) * graphWidth
//
//        String plotName = "s6_plot" + Num2Str(i) + "_" + CleanupName(NameOfWave(w),0)
//        KillWindow/Z $plotName
//
//        Display/W=(0,0,graphWidth,graphHeight)/N=$plotName
//        AppendImage $("s6_im" + Num2Str(i))
//
//        String imName = "s6_im" + Num2Str(i)
//
//        // ---- colortable (single policy) ----
//        if (WaveExists(ctWave))
//            if (useLookup)
//                ModifyImage $imName ctab={*,*,ctWave,0}, lookup=lutWave
//            else
//                ModifyImage $imName ctab={*,*,ctWave,0}
//            endif
//        else
//            ModifyImage $imName ctab={*,*,YellowHot256,0}
//        endif
//
//        ModifyGraph mirror=2
//        SetAxis bottom xMin, xMax
//        if (numtype(yMin)==0 && numtype(yMax)==0)
//            SetAxis left yMin, yMax
//        endif
//        ModifyGraph zero(left)=4
//
//        String layerText = LJZ_MakeLayerLabel_LJZ20251226(w, s6_layerOrder[i], labelType)
//	String t = "\\Z" + Num2Str(tbFont) + layerText   // 注意双反斜杠
//
//	TextBox/K/N=s6_txt0
//	TextBox/N=s6_txt0/A=MT/F=0/B=1/X=(tbX)/Y=(tbY) t
//
//
//
//        Label bottom "k\\B// \\M(Å\\S-1\\M)"
//        if (i == 0)
//            Label left "E-E\\Bf \\M (eV)"
//            ModifyGraph lblMargin(left)=10, lblLatPos(left)=5
//            ModifyGraph margin(right)=1
//            AppendLayoutObject/R=(0.2*graphWidth, 0, 1.7*graphWidth, graphHeight)/W=$windName/F=0 graph $plotName
//        else
//            ModifyGraph tick(left)=3, noLabel(left)=2
//            ModifyGraph margin(left)=1, margin(right)=1
//            AppendLayoutObject/R=(xStart, 0, xStart+graphWidth, graphHeight)/W=$windName/F=0 graph $plotName
//        endif
//    endfor
//
//    SetDataFolder savedDF
//End
Function Show6Layers_LJZ20251226(w, l1, l2, l3, l4, l5, l6[, labelType, xMin, xMax, yMin, yMax, ctName, useLUT, tbFont, tbX, tbY])
    Wave w
    Variable l1, l2, l3, l4, l5, l6
    Variable tbFont, tbX, tbY
    Variable labelType, xMin, xMax, yMin, yMax
    String ctName
    Variable useLUT

    DFREF savedDF = GetDataFolderDFR()

    // -------- defaults --------
    if (ParamIsDefault(labelType))
        labelType = 0
    endif
    if (ParamIsDefault(xMin))
        xMin = -0.27
    endif
    if (ParamIsDefault(xMax))
        xMax = -0.06
    endif
    if (ParamIsDefault(yMin))
        yMin = NaN
    endif
    if (ParamIsDefault(yMax))
        yMax = NaN
    endif
    if (ParamIsDefault(ctName))
        ctName = ""
    endif
    if (ParamIsDefault(useLUT))
        useLUT = 1
    endif
    if (ParamIsDefault(tbFont))
        tbFont = 12
    endif
    if (ParamIsDefault(tbX))
        tbX = 20
    endif
    if (ParamIsDefault(tbY))
        tbY = 25
    endif

    // -------- checks --------
    if (!WaveExists(w))
        Abort "Show6Layers: input wave does not exist."
    endif
    if (WaveDims(w) != 3)
        Abort "Show6Layers: input wave must be 3D."
    endif
    if (xMin >= xMax)
        Abort "Show6Layers: xMin must be < xMax."
    endif
    if (numtype(yMin)==0 && numtype(yMax)==0)
        if (yMin >= yMax)
            Abort "Show6Layers: yMin must be < yMax."
        endif
    endif

    Variable nLayer = DimSize(w, 2)
    if (nLayer < 6)
        Abort "Show6Layers: DimSize(w,2) < 6, choose valid layers."
    endif
    Variable maxLayer = nLayer - 1

    // -------- sanitize layer indices (avoid NaN / non-integer / out-of-range) --------
    Make/FREE/N=6 lay = {l1, l2, l3, l4, l5, l6}

    // NaN/Inf -> default 0..5
// NaN/Inf -> default 0..5
if (numtype(lay[0]) != 0)
    lay[0] = 0
endif
if (numtype(lay[1]) != 0)
    lay[1] = 1
endif
if (numtype(lay[2]) != 0)
    lay[2] = 2
endif
if (numtype(lay[3]) != 0)
    lay[3] = 3
endif
if (numtype(lay[4]) != 0)
    lay[4] = 4
endif
if (numtype(lay[5]) != 0)
    lay[5] = 5
endif


    // force integer
    lay = round(lay)

    // clamp to [0, maxLayer]
    lay = max(0, min(maxLayer, lay[p]))

    // -------- CT resolve --------
    Wave/Z/W/U ctWave = root:ARPES_LJZ:CTLUZ:ct_table
    Wave/Z     lutWave = root:ARPES_LJZ:CTLUZ:ct_lut

    if (strlen(ctName) > 0)
        Wave/Z/W/U tmpCT = $("root:ARPES_LJZ:CTLUZ:CTLIB:" + ctName)
        if (WaveExists(tmpCT))
            ctWave = tmpCT
        endif
    endif

    Variable useLookup = (useLUT != 0) && WaveExists(lutWave)

    // -------- layout window --------
    String windName = "LayerComparison6_" + NameOfWave(w)
    DoWindow/K $windName
    NewLayout/N=$windName/P=LANDSCAPE/K=1

    // temp folder
    NewDataFolder/O/S root:ARPES_LJZ:SHOW6LAYER_TMP
    String sub = CleanupName(NameOfWave(w) + "_6show", 0)
    NewDataFolder/O/S $sub

    // build 6 temporary 2D layers
    Make/O/N=(DimSize(w,0), DimSize(w,1)) s6_im0, s6_im1, s6_im2, s6_im3, s6_im4, s6_im5
    s6_im0[][] = w[p][q][lay[0]]
    s6_im1[][] = w[p][q][lay[1]]
    s6_im2[][] = w[p][q][lay[2]]
    s6_im3[][] = w[p][q][lay[3]]
    s6_im4[][] = w[p][q][lay[4]]
    s6_im5[][] = w[p][q][lay[5]]

    SetScale/P x DimOffset(w,0), DimDelta(w,0), s6_im0, s6_im1, s6_im2, s6_im3, s6_im4, s6_im5
    SetScale/P y DimOffset(w,1), DimDelta(w,1), s6_im0, s6_im1, s6_im2, s6_im3, s6_im4, s6_im5

    Variable graphWidth=100, graphHeight=200
    Variable i, xStart

    for (i=0; i<6; i+=1)
        xStart = (i + 0.7) * graphWidth

        String plotName = "s6_plot" + Num2Str(i) + "_" + CleanupName(NameOfWave(w),0)
        KillWindow/Z $plotName

        Display/W=(0,0,graphWidth,graphHeight)/N=$plotName
        AppendImage $("s6_im" + Num2Str(i))

        String imName = "s6_im" + Num2Str(i)

        // colortable
        if (WaveExists(ctWave))
            if (useLookup)
                ModifyImage $imName ctab={*,*,ctWave,0}, lookup=lutWave
            else
                ModifyImage $imName ctab={*,*,ctWave,0}
            endif
        else
            ModifyImage $imName ctab={*,*,YellowHot256,0}
        endif

        ModifyGraph mirror=2
        SetAxis bottom xMin, xMax
        if (numtype(yMin)==0 && numtype(yMax)==0)
            SetAxis left yMin, yMax
        endif
        ModifyGraph zero(left)=4

        // label uses lay[i]
        String layerText = LJZ_MakeLayerLabel_LJZ20251226(w, lay[i], labelType)
        String t = "\\Z" + Num2Str(tbFont) + layerText

        // TextBox (推荐指定窗口，避免跑错图)
        TextBox/W=$plotName/K/N=s6_txt0
        TextBox/W=$plotName/N=s6_txt0/A=MT/F=0/B=1/X=(tbX)/Y=(tbY) t

        Label bottom "k\\B// \\M(Å\\S-1\\M)"
        if (i == 0)
            Label left "E-E\\Bf \\M (eV)"
            ModifyGraph lblMargin(left)=10, lblLatPos(left)=5
            ModifyGraph margin(right)=1
            AppendLayoutObject/R=(0.2*graphWidth, 0, 1.7*graphWidth, graphHeight)/W=$windName/F=0 graph $plotName
        else
            ModifyGraph tick(left)=3, noLabel(left)=2
            ModifyGraph margin(left)=1, margin(right)=1
            AppendLayoutObject/R=(xStart, 0, xStart+graphWidth, graphHeight)/W=$windName/F=0 graph $plotName
        endif
    endfor

    SetDataFolder savedDF
End


Function s6_btn_help(ctrlName) : ButtonControl
    String ctrlName

    s6_show_help_notebook()
    return 0
End


Function s6_show_help_notebook()
    String nb = "SHOW6LAYER_LJZ_HELP"

    // 如果已存在就前置；不存在就创建
    DoWindow/F $nb
    if (V_flag == 0)
        NewNotebook/N=$nb/F=1/V=1 as "Show6Layers (LJZ) Help"
    endif

    // 清空旧内容（用 Selection 全选再替换，兼容性好）
    Notebook $nb selection={startOfFile, endOfFile}
    Notebook $nb text=""

    // 逐段写入（比拼一个超长字符串稳）
    Notebook $nb text="Show6Layers (LJZ) Panel Help\r"
    Notebook $nb text="================================\r\r"

    Notebook $nb text="Base DF:\r"
    Notebook $nb text="  - 你要扫描的起始 data folder（比如 root:ekimage:）。\r"
    Notebook $nb text="  - Scan 会在这个 folder 下找 3D waves (DIMS:3)。\r\r"

    Notebook $nb text="Recursive:\r"
    Notebook $nb text="  - OFF: 只扫描 Base DF 这一层（不进子文件夹）。List 显示 wave 名字。\r"
    Notebook $nb text="  - ON : 递归扫描 Base DF 及其所有子文件夹。List 显示完整路径（root:...:wave）。\r"
    Notebook $nb text="  - Selected 显示的是最终用于绘图的 wave 完整路径。\r\r"

    Notebook $nb text="Axes (xMin/xMax):\r"
    Notebook $nb text="  - 每张图的 bottom 轴范围（一般对应 k 轴）。\r\r"

    Notebook $nb text="Use YLim:\r"
    Notebook $nb text="  - OFF: 不强制 y 轴范围。\r"
    Notebook $nb text="  - ON : 强制所有 6 张图使用同一个 yMin..yMax（便于对比）。\r"
    Notebook $nb text="  - 注意：yMin/yMax 必须是数字且 yMin<yMax。\r\r"

    Notebook $nb text="Dim2 label:\r"
    Notebook $nb text="  - 用 wave 的第 3 维 (Dim=2) scaling：\r"
    Notebook $nb text="      value = DimOffset(w,2) + DimDelta(w,2)*layerIndex\r"
    Notebook $nb text="  - 仅影响每张图左上角显示文字（Fluence/Delay/Temp 或不显示）。\r\r"

    Notebook $nb text="CT palette (from CTLUZ CTLIB):\r"
    Notebook $nb text="  - 选择 CTLUZ 库中的 palette：root:ARPES_LJZ:CTLUZ:CTLIB:XXX\r"
    Notebook $nb text="  - None：用 CTLUZ 当前正在编辑/输出的 ct_table。\r\r"

    Notebook $nb text="Use LUT:\r"
    Notebook $nb text="  - ON : ModifyImage 同时使用 lookup=ct_lut。\r"
    Notebook $nb text="         作用：按 CTLUZ 的 p1/p2/p3 对颜色位置做非线性重映射（压缩/拉伸对比）。\r"
    Notebook $nb text="  - OFF: 只用 ct_table 线性上色（不做非线性扭曲）。\r\r"

    Notebook $nb text="建议用法:\r"
    Notebook $nb text="  - 6 张严格可比：Use YLim=ON + 同一个 yMin/yMax，同时 xMin/xMax 也统一。\r"
    Notebook $nb text="  - 增强某段对比：Use LUT=ON（先在 CTLUZ 调好 p1/p2/p3）。\r"
    Notebook $nb text="  - wave 分散在子文件夹：Recursive=ON。\r"
End



Function s6_btn_dim2info(ctrlName) : ButtonControl
    String ctrlName

    SVAR s6_wavePath = root:ARPES_LJZ:SHOW6LAYER:s6_wavePath
    if (strlen(s6_wavePath) == 0)
        DoAlert 0, "Dim2 Info: No wave selected."
        return 0
    endif

    Wave/Z w = $s6_wavePath
    if (!WaveExists(w) || WaveDims(w) != 3)
        DoAlert 0, "Dim2 Info: selected wave not found or not 3D."
        return 0
    endif

    NVAR s6_dim2_off = root:ARPES_LJZ:SHOW6LAYER:s6_dim2_off
    NVAR s6_dim2_del = root:ARPES_LJZ:SHOW6LAYER:s6_dim2_del
    NVAR s6_dim2_n   = root:ARPES_LJZ:SHOW6LAYER:s6_dim2_n
    NVAR s6_dim2_v0  = root:ARPES_LJZ:SHOW6LAYER:s6_dim2_v0
    NVAR s6_dim2_v1  = root:ARPES_LJZ:SHOW6LAYER:s6_dim2_v1

    s6_dim2_off = DimOffset(w, 2)
    s6_dim2_del = DimDelta(w, 2)
    s6_dim2_n   = DimSize(w, 2)
    s6_dim2_v0  = s6_dim2_off
    s6_dim2_v1  = s6_dim2_off + s6_dim2_del*(s6_dim2_n-1)

    // 强制刷新控件显示
    DoWindow SHOW6LAYER_LJZ_P
    if (V_flag)
        ControlUpdate/W=SHOW6LAYER_LJZ_P s6_sv_d2off
        ControlUpdate/W=SHOW6LAYER_LJZ_P s6_sv_d2del
        ControlUpdate/W=SHOW6LAYER_LJZ_P s6_sv_d2n
        ControlUpdate/W=SHOW6LAYER_LJZ_P s6_sv_d2v0
        ControlUpdate/W=SHOW6LAYER_LJZ_P s6_sv_d2v1
    endif

    return 0
End
