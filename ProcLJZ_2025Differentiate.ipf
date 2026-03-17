#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

//============================================================
// SD3D: Second Derivative for 3D wave (SG optional)
// Style aligned to SHOW6LAYER template
//============================================================

//============================================================
// Helpers
//============================================================
Function sd3d_ensure_folder()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:SD3D
    NewDataFolder/O root:ARPES_LJZ:OUTPUT
    NewDataFolder/O root:ARPES_LJZ:OUTPUT:SD3D
End

Function/S sd3d_df_with_colon(inStr)
    String inStr
    String s = inStr

    if (strlen(s) == 0)
        return "root:"
    endif

    if (StringMatch(s, "root"))
        s = "root:"
    endif

    // avoid s[...]
    if (!StringMatch(s, "*:"))
        s += ":"
    endif

    return s
End

Function sd3d_df_exists(dfStr)
    String dfStr
    DFREF dfr = $dfStr
    return DataFolderRefStatus(dfr) != 0
End

//============================================================
// Defaults
//============================================================
Function sd3d_init_defaults_if_needed()
    sd3d_ensure_folder()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:SD3D

    if (!WaveExists($"LB_Items"))
        Make/O/T/N=0 LB_Items
    endif
    if (!WaveExists($"LB_Sel"))
        Make/O/U/B/N=0 LB_Sel
    endif

    SVAR/Z sd3d_wavePath = root:ARPES_LJZ:SD3D:sd3d_wavePath
    if (!SVAR_Exists(sd3d_wavePath))
        String/G sd3d_wavePath = ""
    endif

    SVAR/Z sd3d_baseDF = root:ARPES_LJZ:SD3D:sd3d_baseDF
    if (!SVAR_Exists(sd3d_baseDF))
        String/G sd3d_baseDF = "root:"
    endif

    NVAR/Z sd3d_recursive = root:ARPES_LJZ:SD3D:sd3d_recursive
    if (!NVAR_Exists(sd3d_recursive))
        Variable/G sd3d_recursive = 0
    endif

    // parameters
    NVAR/Z sd3d_mode = root:ARPES_LJZ:SD3D:sd3d_mode
    if (!NVAR_Exists(sd3d_mode))
        Variable/G sd3d_mode = 1     // 1: d2x+d2y, 2: d2x, 3: d2y
    endif

    NVAR/Z sd3d_winN = root:ARPES_LJZ:SD3D:sd3d_winN
    if (!NVAR_Exists(sd3d_winN))
        Variable/G sd3d_winN = 0     // <=0 off
    endif

    NVAR/Z sd3d_sgOrder = root:ARPES_LJZ:SD3D:sd3d_sgOrder
    if (!NVAR_Exists(sd3d_sgOrder))
        Variable/G sd3d_sgOrder = 2  // 2 or 4
    endif

    SVAR/Z sd3d_baseName = root:ARPES_LJZ:SD3D:sd3d_baseName
    if (!SVAR_Exists(sd3d_baseName))
        String/G sd3d_baseName = ""
    endif

    NVAR/Z sd3d_outToOutput = root:ARPES_LJZ:SD3D:sd3d_outToOutput
    if (!NVAR_Exists(sd3d_outToOutput))
        Variable/G sd3d_outToOutput = 1
    endif

    SetDataFolder df0
End

//============================================================
// Entry
//============================================================
Proc SD3D_LJZ()
    sd3d_init_defaults_if_needed()

    DoWindow/F SD3D_LJZ_P
    if (V_flag == 0)
        SD3D_LJZ_P()
    endif

    sd3d_rebuild_lb()
End

Menu "ARPES_LJZ"
    "SecondDeriv 3D (SG optional)", SD3D_LJZ()
End

//============================================================
// Recursive scan: returns FULL PATH list, only 3D waves
//============================================================
Function/S sd3d_collect_3d_waves_recursive(baseDF)
    String baseDF

    String df0 = GetDataFolder(1)
    String outList = ""

    if (!sd3d_df_exists(baseDF))
        return ""
    endif

    SetDataFolder $baseDF

    String here = WaveList("*", ";", "DIMS:3")
    Variable i, n
    n = ItemsInList(here, ";")
    for (i=0; i<n; i+=1)
        String wn = StringFromList(i, here, ";")
        if (strlen(wn) == 0)
            continue
        endif
        outList += (baseDF + wn + ";")
    endfor

    String subList = DataFolderDir(2)
    Variable m
    m = ItemsInList(subList, ";")
    for (i=0; i<m; i+=1)
        String fd = StringFromList(i, subList, ";")
        if (strlen(fd) == 0)
            continue
        endif
        outList += sd3d_collect_3d_waves_recursive(baseDF + fd + ":")
    endfor

    SetDataFolder df0
    return outList
End

//============================================================
// List build
//============================================================
Function sd3d_rebuild_lb()
    sd3d_ensure_folder()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:SD3D

    SVAR sd3d_baseDF = root:ARPES_LJZ:SD3D:sd3d_baseDF
    NVAR sd3d_recursive = root:ARPES_LJZ:SD3D:sd3d_recursive
    SVAR sd3d_wavePath = root:ARPES_LJZ:SD3D:sd3d_wavePath

    Wave/T   LB_Items = root:ARPES_LJZ:SD3D:LB_Items
    Wave/U/B LB_Sel   = root:ARPES_LJZ:SD3D:LB_Sel

    Redimension/N=0 LB_Items, LB_Sel
    sd3d_wavePath = ""

    String base = sd3d_df_with_colon(sd3d_baseDF)
    if (!sd3d_df_exists(base))
        base = "root:"
    endif
    sd3d_baseDF = base

    String listStr
    if (sd3d_recursive)
        listStr = sd3d_collect_3d_waves_recursive(base)   // full paths
    else
        String df1 = GetDataFolder(1)
        SetDataFolder $base
        listStr = WaveList("*", ";", "DIMS:3")             // names only
        SetDataFolder df1
    endif

    Variable n
    n = ItemsInList(listStr, ";")
    if (n > 0)
        Redimension/N=(n) LB_Items, LB_Sel
        Variable i
        for (i=0; i<n; i+=1)
            LB_Items[i] = StringFromList(i, listStr, ";")
            LB_Sel[i] = 0
        endfor
    endif

    SetDataFolder df0

    DoWindow SD3D_LJZ_P
    if (V_flag)
        ControlUpdate/W=SD3D_LJZ_P sd3d_lb
        TitleBox sd3d_status, win=SD3D_LJZ_P, title="Selected: (none)"
    endif

    return 0
End

//============================================================
// ListBox proc: single select
//============================================================
Function sd3d_lb_proc(ctrlName, row, col, eventCode) : ListBoxControl
    String ctrlName
    Variable row, col, eventCode

    if (eventCode != 4)
        return 0
    endif

    Wave/U/B LB_Sel = root:ARPES_LJZ:SD3D:LB_Sel
    Wave/T   LB_Items = root:ARPES_LJZ:SD3D:LB_Items
    SVAR     sd3d_wavePath = root:ARPES_LJZ:SD3D:sd3d_wavePath
    SVAR     sd3d_baseDF = root:ARPES_LJZ:SD3D:sd3d_baseDF
    NVAR     sd3d_recursive = root:ARPES_LJZ:SD3D:sd3d_recursive

    if (row < 0 || row >= DimSize(LB_Items, 0))
        return 0
    endif

    LB_Sel = 0
    LB_Sel[row] = 1

    String item = LB_Items[row]
    if (strlen(item) == 0)
        sd3d_wavePath = ""
    else
        if (sd3d_recursive)
            sd3d_wavePath = item
        else
            String base = sd3d_df_with_colon(sd3d_baseDF)
            sd3d_baseDF = base
            sd3d_wavePath = base + item
        endif
    endif

    DoWindow SD3D_LJZ_P
    if (V_flag)
        TitleBox sd3d_status, win=SD3D_LJZ_P, title="Selected: " + sd3d_wavePath
    endif

    return 0
End

//============================================================
// Popup procs
//============================================================
Function sd3d_pm_mode_proc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName
    Variable popNum
    String popStr

    Variable v
    v = str2num(StringFromList(0, popStr, ":"))
    if (numtype(v) != 0)
        v = 1
    endif

    NVAR sd3d_mode = root:ARPES_LJZ:SD3D:sd3d_mode
    sd3d_mode = v

    return 0
End

Function sd3d_pm_sgorder_proc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName
    Variable popNum
    String popStr

    Variable v
    v = str2num(popStr)
    if (numtype(v) != 0)
        v = 2
    endif
    if (v != 2 && v != 4)
        v = 2
    endif

    NVAR sd3d_sgOrder = root:ARPES_LJZ:SD3D:sd3d_sgOrder
    sd3d_sgOrder = v

    return 0
End

//============================================================
// Buttons
//============================================================
Function sd3d_btn_scan(ctrlName) : ButtonControl
    String ctrlName
    sd3d_rebuild_lb()
    return 0
End

Function sd3d_btn_run(ctrlName) : ButtonControl
    String ctrlName

    SVAR sd3d_wavePath = root:ARPES_LJZ:SD3D:sd3d_wavePath
    if (strlen(sd3d_wavePath) == 0)
        Abort "SD3D: No wave selected."
    endif

    Wave/Z w = $sd3d_wavePath
    if (!WaveExists(w))
        Abort "SD3D: selected wave not found."
    endif
    if (WaveDims(w) != 3)
        Abort "SD3D: selected wave is not 3D."
    endif

    NVAR sd3d_mode = root:ARPES_LJZ:SD3D:sd3d_mode
    NVAR sd3d_winN = root:ARPES_LJZ:SD3D:sd3d_winN
    NVAR sd3d_sgOrder = root:ARPES_LJZ:SD3D:sd3d_sgOrder
    NVAR sd3d_outToOutput = root:ARPES_LJZ:SD3D:sd3d_outToOutput
    SVAR sd3d_baseName = root:ARPES_LJZ:SD3D:sd3d_baseName
    SVAR sd3d_baseDF = root:ARPES_LJZ:SD3D:sd3d_baseDF

    String useBaseName
    useBaseName = sd3d_baseName
    if (strlen(useBaseName) == 0)
        useBaseName = NameOfWave(w)
    endif

    String df0 = GetDataFolder(1)

    if (sd3d_outToOutput)
        SetDataFolder root:ARPES_LJZ:OUTPUT:SD3D
    else
        String base = sd3d_df_with_colon(sd3d_baseDF)
        if (!sd3d_df_exists(base))
            Abort "SD3D: Base DF does not exist."
        endif
        SetDataFolder $base
    endif

    Variable rc
    rc = MDC_SecondDeriv3D_LJZ(w, sd3d_mode, useBaseName, sd3d_winN, sd3d_sgOrder)

    SetDataFolder df0

    if (rc != 0)
        Abort "SD3D: algorithm failed (rc != 0)."
    endif

    return 0
End

Function sd3d_btn_close(ctrlName) : ButtonControl
    String ctrlName
    DoWindow/K SD3D_LJZ_P
    return 0
End

Function sd3d_btn_help(ctrlName) : ButtonControl
    String ctrlName

    String nb = "SD3D_LJZ_HELP"
    DoWindow/F $nb
    if (V_flag == 0)
        NewNotebook/N=$nb/F=1/V=1 as "SecondDeriv3D (LJZ) Help"
    endif

    Notebook $nb selection={startOfFile, endOfFile}
    Notebook $nb text=""

    Notebook $nb text="SecondDeriv 3D (SD3D) Help\r"
    Notebook $nb text="===========================\r\r"
    Notebook $nb text="Mode:\r"
    Notebook $nb text="  1: Laplacian = d2/dx2 + d2/dy2\r"
    Notebook $nb text="  2: d2/dx2 only\r"
    Notebook $nb text="  3: d2/dy2 only\r\r"
    Notebook $nb text="SG winN:\r"
    Notebook $nb text="  <=0: no smoothing\r"
    Notebook $nb text="  >0 : Savitzky-Golay smoothing on 1st derivative, then differentiate again\r"
    Notebook $nb text="  window auto-clamped to [5,25] and forced odd\r\r"
    Notebook $nb text="SG order:\r"
    Notebook $nb text="  2 or 4 only; other values forced to 2\r\r"
    Notebook $nb text="Output:\r"
    Notebook $nb text="  checked : root:ARPES_LJZ:OUTPUT:SD3D\r"
    Notebook $nb text="  unchecked: output to Base DF\r"

    return 0
End

//============================================================
// Panel
//============================================================
Window SD3D_LJZ_P() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(420,60,957.6,507) as "SecondDeriv 3D (LJZ)"
	ModifyPanel frameStyle=1
	ShowTools/A
	TitleBox sd3d_t0,pos={12.00,9.00},size={246.00,18.00},title="Second derivative for 3D wave (SG optional)."
	TitleBox sd3d_t0,frame=0
	TitleBox sd3d_status,pos={12.00,27.00},size={88.80,18.00},title="Selected: (none)"
	TitleBox sd3d_status,frame=0
	TitleBox sd3d_tdf,pos={12.00,51.00},size={47.40,18.00},title="Base DF:",frame=0
	SetVariable sd3d_sv_df,pos={84.00,48.00},size={240.00,19.80}
	SetVariable sd3d_sv_df,value= root:ARPES_LJZ:SD3D:sd3d_baseDF
	CheckBox sd3d_ck_rec,pos={336.00,51.00},size={63.60,18.00},title="Recursive"
	CheckBox sd3d_ck_rec,variable= root:ARPES_LJZ:SD3D:sd3d_recursive
	Button sd3d_btn_scan,pos={426.00,48.00},size={69.00,21.00},proc=sd3d_btn_scan,title="Scan"
	ListBox sd3d_lb,pos={12.00,78.00},size={312.00,360.00},proc=sd3d_lb_proc
	ListBox sd3d_lb,listWave=root:ARPES_LJZ:SD3D:LB_Items
	ListBox sd3d_lb,selWave=root:ARPES_LJZ:SD3D:LB_Sel,mode= 1,selRow= 0
	TitleBox sd3d_tp,pos={336.00,78.00},size={64.80,18.00},title="Parameters:"
	TitleBox sd3d_tp,frame=0
	PopupMenu sd3d_pm_mode,pos={336.00,102.00},size={99.00,20.40},proc=sd3d_pm_mode_proc,title="Mode"
	PopupMenu sd3d_pm_mode,mode=1,popvalue="1:Laplace",value= #"\"1:Laplace(d2x+d2y);2:d2x only;3:d2y only;\""
	SetVariable sd3d_sv_bn,pos={336.00,132.00},size={159.60,19.80},title="BaseName"
	SetVariable sd3d_sv_bn,value= root:ARPES_LJZ:SD3D:sd3d_baseName
	SetVariable sd3d_sv_win,pos={336.00,156.00},size={159.60,19.80},title="SG winN"
	SetVariable sd3d_sv_win,limits={-1,9999,1},value= root:ARPES_LJZ:SD3D:sd3d_winN
	PopupMenu sd3d_pm_sg,pos={336.00,180.00},size={69.60,20.40},proc=sd3d_pm_sgorder_proc,title="SG order"
	PopupMenu sd3d_pm_sg,mode=1,popvalue="2",value= #"\"2;4;\""
	CheckBox sd3d_ck_out,pos={336.00,210.00},size={188.40,18.00},title="Output to root:...:OUTPUT:SD3D"
	CheckBox sd3d_ck_out,variable= root:ARPES_LJZ:SD3D:sd3d_outToOutput
	Button sd3d_btn_run,pos={339.60,239.40},size={184.80,58.20},proc=sd3d_btn_run,title="Run"
	Button sd3d_btn_close,pos={339.60,304.20},size={184.20,65.40},proc=sd3d_btn_close,title="Close"
	Button sd3d_btn_help,pos={342.00,374.40},size={181.80,63.60},proc=sd3d_btn_help,title="Help"
EndMacro

//============================================================
// Core algorithm (same API as you had)
// mode=1: d2x+d2y -> baseName+"_d2xy"
// mode=2: d2x     -> baseName+"_d2x"
// mode=3: d2y     -> baseName+"_d2y"
// winN<=0: no SG smoothing
//============================================================
Function MDC_SecondDeriv3D_LJZ(srcWave, mode, baseName, winN, sgOrder)
    Wave srcWave
    Variable mode
    String baseName
    Variable winN, sgOrder

    if (WaveDims(srcWave) != 3)
        DoAlert 0, "MDC_SecondDeriv3D_LJZ: input wave is not 3D."
        return -1
    endif

    Variable n0, n1, n2
    n0 = DimSize(srcWave, 0)
    n1 = DimSize(srcWave, 1)
    n2 = DimSize(srcWave, 2)

    if ((n0 < 3) || (n1 < 3))
        DoAlert 0, "MDC_SecondDeriv3D_LJZ: dim0/dim1 need >=3 points."
        return -1
    endif

    Variable d0, d1
    d0 = DimDelta(srcWave, 0)
    d1 = DimDelta(srcWave, 1)
    if ((d0 == 0) || (d1 == 0))
        DoAlert 0, "MDC_SecondDeriv3D_LJZ: DimDelta(0/1) cannot be 0."
        return -1
    endif

    // ---- SG params ----
    Variable doSmooth
    doSmooth = 0
    if (winN > 0)
        doSmooth = 1

        if (winN < 5)
            winN = 5
        endif
        if (winN > 25)
            winN = 25
        endif
        if (mod(winN, 2) == 0)
            winN += 1
        endif

        if (sgOrder != 2 && sgOrder != 4)
            sgOrder = 2
        endif
    endif

    // ---- output name ----
    String destName
    if (mode == 1)
        destName = baseName + "_d2xy"
    elseif (mode == 2)
        destName = baseName + "_d2x"
    elseif (mode == 3)
        destName = baseName + "_d2y"
    else
        DoAlert 0, "MDC_SecondDeriv3D_LJZ: mode must be 1,2,3."
        return -1
    endif

    Make/O/N=(n0, n1, n2) $destName
    Wave outW = $destName

    SetScale/P x, DimOffset(srcWave,0), DimDelta(srcWave,0), outW
    SetScale/P y, DimOffset(srcWave,1), DimDelta(srcWave,1), outW
    SetScale/P z, DimOffset(srcWave,2), DimDelta(srcWave,2), outW

    Wave tmpDx2
    Wave tmpDy2

    if ((mode == 1) || (mode == 2))
        Duplicate/FREE srcWave, tmpDx2
        Differentiate/DIM=0 tmpDx2
        if (doSmooth)
            Smooth/DIM=0/S=(sgOrder) winN, tmpDx2
        endif
        Differentiate/DIM=0 tmpDx2
    endif

    if ((mode == 1) || (mode == 3))
        Duplicate/FREE srcWave, tmpDy2
        Differentiate/DIM=1 tmpDy2
        if (doSmooth)
            Smooth/DIM=1/S=(sgOrder) winN, tmpDy2
        endif
        Differentiate/DIM=1 tmpDy2
    endif

    if (mode == 1)
        outW = tmpDx2 + tmpDy2
    elseif (mode == 2)
        outW = tmpDx2
    else
        outW = tmpDy2
    endif

    Printf "MDC_SecondDeriv3D_LJZ: out=%s mode=%d smooth=%d winN=%d sgOrder=%d\r", destName, mode, doSmooth, winN, sgOrder
    return 0
End
