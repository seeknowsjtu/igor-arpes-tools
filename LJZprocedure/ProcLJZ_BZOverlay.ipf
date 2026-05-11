#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma DefaultTab={3,20,4}

// ============================================================================
//  LJZ_BZOverlay.ipf
//  Brillouin-zone overlay utility for 2D kx-ky / Fermi-surface images.
//
//  Usage:
//      1) Load this procedure file in Igor Pro 8.
//      2) Run LJZ_BZOverlay(), or use menu: ARPES_LJZ -> BZ Overlay for FS.
//      3) Select a 2D Fermi-surface wave whose x/y axes are already kx/ky.
//      4) Set lattice type, lattice constants and repeat number.
//      5) Optionally enable analyzer-scan cut overlays.
//      6) Click "Display FS + BZ" or "Overlay Top Graph".
//
//  Design:
//      - This file does NOT calculate full ARPES kx-ky mapping.
//      - It draws BZ boundaries and optional hemispherical-analyzer scan cuts
//        over an already generated 2D k-space image.
//      - It uses a generic Wigner-Seitz construction from reciprocal vectors,
//        so square, rectangular, hexagonal, and custom 2D lattices are all handled
//        by the same clipping algorithm.
// ============================================================================

Menu "ARPES_LJZ"
    "BZ Overlay for FS", LJZ_BZOverlay()
End

// ------------------------ persistent state folders --------------------------
Function/S BZOV_BaseDF()
    return "root:ARPES_LJZ:BZOverlay"
End

Function/S BZOV_OutputDF()
    return "root:ARPES_LJZ:BZOverlay:Output"
End

Function BZOV_EnsureDF()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:BZOverlay
    NewDataFolder/O root:ARPES_LJZ:BZOverlay:Output

    String df0 = GetDataFolder(1)
    SetDataFolder $BZOV_BaseDF()

    if (!WaveExists($"LB_Items"))
        Make/O/T/N=0 LB_Items
    endif
    if (!WaveExists($"LB_Sel"))
        Make/O/U/B/N=0 LB_Sel
    endif

    SVAR/Z baseDF = root:ARPES_LJZ:BZOverlay:baseDF
    if (!SVAR_Exists(baseDF))
        String/G root:ARPES_LJZ:BZOverlay:baseDF = "root:"
    endif

    SVAR/Z wavePath = root:ARPES_LJZ:BZOverlay:wavePath
    if (!SVAR_Exists(wavePath))
        String/G root:ARPES_LJZ:BZOverlay:wavePath = ""
    endif

    NVAR/Z latticeType = root:ARPES_LJZ:BZOverlay:latticeType
    if (!NVAR_Exists(latticeType))
        Variable/G root:ARPES_LJZ:BZOverlay:latticeType = 0       // 0 square, 1 rectangular, 2 hexagonal, 3 custom2D
    endif

    NVAR/Z unitMode = root:ARPES_LJZ:BZOverlay:unitMode
    if (!NVAR_Exists(unitMode))
        Variable/G root:ARPES_LJZ:BZOverlay:unitMode = 0          // 0 A^-1, 1 pi/a
    endif

    NVAR/Z a = root:ARPES_LJZ:BZOverlay:a
    if (!NVAR_Exists(a))
        Variable/G root:ARPES_LJZ:BZOverlay:a = 4.0               // Angstrom
    endif

    NVAR/Z b = root:ARPES_LJZ:BZOverlay:b
    if (!NVAR_Exists(b))
        Variable/G root:ARPES_LJZ:BZOverlay:b = 4.0               // Angstrom
    endif

    NVAR/Z gammaDeg = root:ARPES_LJZ:BZOverlay:gammaDeg
    if (!NVAR_Exists(gammaDeg))
        Variable/G root:ARPES_LJZ:BZOverlay:gammaDeg = 90.0
    endif

    NVAR/Z centerX = root:ARPES_LJZ:BZOverlay:centerX
    if (!NVAR_Exists(centerX))
        Variable/G root:ARPES_LJZ:BZOverlay:centerX = 0.0
    endif

    NVAR/Z centerY = root:ARPES_LJZ:BZOverlay:centerY
    if (!NVAR_Exists(centerY))
        Variable/G root:ARPES_LJZ:BZOverlay:centerY = 0.0
    endif

    NVAR/Z repeatN = root:ARPES_LJZ:BZOverlay:repeatN
    if (!NVAR_Exists(repeatN))
        Variable/G root:ARPES_LJZ:BZOverlay:repeatN = 1
    endif

    NVAR/Z showRepeated = root:ARPES_LJZ:BZOverlay:showRepeated
    if (!NVAR_Exists(showRepeated))
        Variable/G root:ARPES_LJZ:BZOverlay:showRepeated = 1
    endif

    NVAR/Z showLabels = root:ARPES_LJZ:BZOverlay:showLabels
    if (!NVAR_Exists(showLabels))
        Variable/G root:ARPES_LJZ:BZOverlay:showLabels = 1
    endif

    NVAR/Z colorMode = root:ARPES_LJZ:BZOverlay:colorMode
    if (!NVAR_Exists(colorMode))
        Variable/G root:ARPES_LJZ:BZOverlay:colorMode = 1         // BZ color, see BZOV_ColorPopupList()
    endif

    NVAR/Z cutShow = root:ARPES_LJZ:BZOverlay:cutShow
    if (!NVAR_Exists(cutShow))
        Variable/G root:ARPES_LJZ:BZOverlay:cutShow = 0
    endif

    NVAR/Z cutMode = root:ARPES_LJZ:BZOverlay:cutMode
    if (!NVAR_Exists(cutMode))
        Variable/G root:ARPES_LJZ:BZOverlay:cutMode = 0           // 0 single scan cut, 1 multiple scan cuts
    endif

    NVAR/Z cutColorMode = root:ARPES_LJZ:BZOverlay:cutColorMode
    if (!NVAR_Exists(cutColorMode))
        Variable/G root:ARPES_LJZ:BZOverlay:cutColorMode = 8      // orange by default
    endif

    NVAR/Z cutLineWidth = root:ARPES_LJZ:BZOverlay:cutLineWidth
    if (!NVAR_Exists(cutLineWidth))
        Variable/G root:ARPES_LJZ:BZOverlay:cutLineWidth = 1.0
    endif

    NVAR/Z cutLineStyle = root:ARPES_LJZ:BZOverlay:cutLineStyle
    if (!NVAR_Exists(cutLineStyle))
        Variable/G root:ARPES_LJZ:BZOverlay:cutLineStyle = 0      // Igor line style index
    endif

    NVAR/Z cutShowLabels = root:ARPES_LJZ:BZOverlay:cutShowLabels
    if (!NVAR_Exists(cutShowLabels))
        Variable/G root:ARPES_LJZ:BZOverlay:cutShowLabels = 0
    endif

    NVAR/Z cutHv = root:ARPES_LJZ:BZOverlay:cutHv
    if (!NVAR_Exists(cutHv))
        Variable/G root:ARPES_LJZ:BZOverlay:cutHv = 6.0
    endif

    NVAR/Z cutWorkFunc = root:ARPES_LJZ:BZOverlay:cutWorkFunc
    if (!NVAR_Exists(cutWorkFunc))
        Variable/G root:ARPES_LJZ:BZOverlay:cutWorkFunc = 4.3
    endif

    NVAR/Z cutEnergyRel = root:ARPES_LJZ:BZOverlay:cutEnergyRel
    if (!NVAR_Exists(cutEnergyRel))
        Variable/G root:ARPES_LJZ:BZOverlay:cutEnergyRel = 0.0
    endif

    NVAR/Z cutTilt = root:ARPES_LJZ:BZOverlay:cutTilt
    if (!NVAR_Exists(cutTilt))
        Variable/G root:ARPES_LJZ:BZOverlay:cutTilt = 0.0
    endif

    NVAR/Z cutAzimuth = root:ARPES_LJZ:BZOverlay:cutAzimuth
    if (!NVAR_Exists(cutAzimuth))
        Variable/G root:ARPES_LJZ:BZOverlay:cutAzimuth = 0.0
    endif

    NVAR/Z cutScanOffset = root:ARPES_LJZ:BZOverlay:cutScanOffset
    if (!NVAR_Exists(cutScanOffset))
        Variable/G root:ARPES_LJZ:BZOverlay:cutScanOffset = 0.0
    endif

    NVAR/Z cutLatticeA = root:ARPES_LJZ:BZOverlay:cutLatticeA
    if (!NVAR_Exists(cutLatticeA))
        Variable/G root:ARPES_LJZ:BZOverlay:cutLatticeA = 0.0
    endif

    NVAR/Z cutGeometry = root:ARPES_LJZ:BZOverlay:cutGeometry
    if (!NVAR_Exists(cutGeometry))
        Variable/G root:ARPES_LJZ:BZOverlay:cutGeometry = 1
    endif

    NVAR/Z cutAlphaMin = root:ARPES_LJZ:BZOverlay:cutAlphaMin
    if (!NVAR_Exists(cutAlphaMin))
        Variable/G root:ARPES_LJZ:BZOverlay:cutAlphaMin = -20.0
    endif

    NVAR/Z cutAlphaMax = root:ARPES_LJZ:BZOverlay:cutAlphaMax
    if (!NVAR_Exists(cutAlphaMax))
        Variable/G root:ARPES_LJZ:BZOverlay:cutAlphaMax = 20.0
    endif

    NVAR/Z cutAlphaN = root:ARPES_LJZ:BZOverlay:cutAlphaN
    if (!NVAR_Exists(cutAlphaN))
        Variable/G root:ARPES_LJZ:BZOverlay:cutAlphaN = 401
    endif

    NVAR/Z cutScanValue = root:ARPES_LJZ:BZOverlay:cutScanValue
    if (!NVAR_Exists(cutScanValue))
        Variable/G root:ARPES_LJZ:BZOverlay:cutScanValue = 0.0
    endif

    NVAR/Z cutScanMin = root:ARPES_LJZ:BZOverlay:cutScanMin
    if (!NVAR_Exists(cutScanMin))
        Variable/G root:ARPES_LJZ:BZOverlay:cutScanMin = -16.5
    endif

    NVAR/Z cutScanMax = root:ARPES_LJZ:BZOverlay:cutScanMax
    if (!NVAR_Exists(cutScanMax))
        Variable/G root:ARPES_LJZ:BZOverlay:cutScanMax = 16.5
    endif

    NVAR/Z cutScanStep = root:ARPES_LJZ:BZOverlay:cutScanStep
    if (!NVAR_Exists(cutScanStep))
        Variable/G root:ARPES_LJZ:BZOverlay:cutScanStep = 2.0
    endif

    NVAR/Z lineWidth = root:ARPES_LJZ:BZOverlay:lineWidth
    if (!NVAR_Exists(lineWidth))
        Variable/G root:ARPES_LJZ:BZOverlay:lineWidth = 1.5
    endif

    NVAR/Z labelSize = root:ARPES_LJZ:BZOverlay:labelSize
    if (!NVAR_Exists(labelSize))
        Variable/G root:ARPES_LJZ:BZOverlay:labelSize = 12
    endif

    NVAR/Z imagePlan = root:ARPES_LJZ:BZOverlay:imagePlan
    if (!NVAR_Exists(imagePlan))
        Variable/G root:ARPES_LJZ:BZOverlay:imagePlan = 1         // for kx/ky image, Plan aspect is usually desired
    endif

    SetDataFolder df0
    return 0
End

Function/S BZOV_DFWithColon(sIn)
    String sIn
    String s = sIn
    if (strlen(s) == 0)
        return "root:"
    endif
    if (StringMatch(s, "root"))
        return "root:"
    endif
    if (!StringMatch(s, "*:"))
        s += ":"
    endif
    return s
End

Function BZOV_DFExists(sIn)
    String sIn
    String s = BZOV_DFWithColon(sIn)
    return DataFolderExists(s)
End

Function/S BZOV_SafeWinName(prefix, w)
    String prefix
    Wave w
    String s = prefix + CleanupName(NameOfWave(w), 0)
    if (strlen(s) > 60)
        s = s[0,59]
    endif
    return s
End

Function/S BZOV_ColorPopupList()
    return "Black;White;Red;Green;Blue;Yellow;Cyan;Magenta;Orange;Purple;Gray"
End

Function/S BZOV_CutModePopupList()
    return "Single scan angle;Multiple scan angles"
End

// ------------------------------ entry point ---------------------------------
Proc LJZ_BZOverlay()
    BZOV_EnsureDF()
    BZOV_RebuildLB()
    DoWindow/F LJZ_BZOverlay_Panel
    if (V_flag == 0)
        LJZ_BZOverlay_Panel()
    endif
End

// ---------------------------------- panel -----------------------------------
Window LJZ_BZOverlay_Panel() : Panel
    PauseUpdate; Silent 1
    NewPanel /W=(400,70,1120,780) as "BZ Overlay + Analyzer Cuts for kx-ky FS (LJZ)"
    ModifyPanel frameStyle=1

    TitleBox bzov_title,pos={12,10},size={260,18},title="BZ Overlay for selected 2D k-space image",frame=0
    TitleBox bzov_status,pos={12,30},size={260,18},title="Selected: (none)",frame=0

    TitleBox bzov_df_t,pos={12,58},size={55,18},title="Source DF",frame=0
    SetVariable bzov_sv_df,pos={78,55},size={305,20},proc=BZOV_sv_df_proc,title=""
    SetVariable bzov_sv_df,value=root:ARPES_LJZ:BZOverlay:baseDF
    Button bzov_btn_cur,pos={392,54},size={72,22},proc=BZOV_btn_current,title="Current"
    Button bzov_btn_scan,pos={472,54},size={72,22},proc=BZOV_btn_scan,title="Scan"

    ListBox bzov_lb,pos={12,88},size={245,395},proc=BZOV_lb_proc
    ListBox bzov_lb,listWave=root:ARPES_LJZ:BZOverlay:LB_Items
    ListBox bzov_lb,selWave=root:ARPES_LJZ:BZOverlay:LB_Sel,mode=1,selRow=0

    TitleBox bzov_params,pos={275,88},size={170,18},title="Lattice / overlay parameters",frame=0

    PopupMenu bzov_pm_lattice,pos={275,116},size={210,20},proc=BZOV_pm_lattice,title="Lattice"
    PopupMenu bzov_pm_lattice,mode=1,popvalue="Square",value=#"\"Square;Rectangular;Hexagonal;Custom2D\""

    PopupMenu bzov_pm_unit,pos={275,144},size={210,20},proc=BZOV_pm_unit,title="Axes unit"
    PopupMenu bzov_pm_unit,mode=1,popvalue="A^-1",value=#"\"A^-1;pi/a\""

    SetVariable bzov_sv_a,pos={275,176},size={230,20},title="a (Å)"
    SetVariable bzov_sv_a,limits={1e-9,1e9,0.01},value=root:ARPES_LJZ:BZOverlay:a
    SetVariable bzov_sv_b,pos={275,204},size={230,20},title="b (Å)"
    SetVariable bzov_sv_b,limits={1e-9,1e9,0.01},value=root:ARPES_LJZ:BZOverlay:b
    SetVariable bzov_sv_g,pos={275,232},size={230,20},title="gamma (deg)"
    SetVariable bzov_sv_g,limits={1,179,0.1},value=root:ARPES_LJZ:BZOverlay:gammaDeg

    SetVariable bzov_sv_cx,pos={275,268},size={230,20},title="center kx"
    SetVariable bzov_sv_cx,limits={-1e9,1e9,0.001},value=root:ARPES_LJZ:BZOverlay:centerX
    SetVariable bzov_sv_cy,pos={275,296},size={230,20},title="center ky"
    SetVariable bzov_sv_cy,limits={-1e9,1e9,0.001},value=root:ARPES_LJZ:BZOverlay:centerY

    SetVariable bzov_sv_rep,pos={275,332},size={230,20},title="repeat N"
    SetVariable bzov_sv_rep,limits={0,5,1},value=root:ARPES_LJZ:BZOverlay:repeatN
    CheckBox bzov_ck_rep,pos={275,362},size={150,18},title="Show repeated BZ"
    CheckBox bzov_ck_rep,variable=root:ARPES_LJZ:BZOverlay:showRepeated
    CheckBox bzov_ck_lab,pos={275,386},size={150,18},title="Show Γ/X/M/K labels"
    CheckBox bzov_ck_lab,variable=root:ARPES_LJZ:BZOverlay:showLabels
    CheckBox bzov_ck_plan,pos={275,410},size={150,18},title="Plan aspect for image"
    CheckBox bzov_ck_plan,variable=root:ARPES_LJZ:BZOverlay:imagePlan

    PopupMenu bzov_pm_color,pos={275,442},size={210,20},proc=BZOV_pm_color,title="BZ color"
    PopupMenu bzov_pm_color,mode=2,popvalue="White",value=#"BZOV_ColorPopupList()"
    SetVariable bzov_sv_lw,pos={275,472},size={230,20},title="BZ line width"
    SetVariable bzov_sv_lw,limits={0.1,10,0.1},value=root:ARPES_LJZ:BZOverlay:lineWidth
    SetVariable bzov_sv_fs,pos={275,500},size={230,20},title="label size"
    SetVariable bzov_sv_fs,limits={6,36,1},value=root:ARPES_LJZ:BZOverlay:labelSize

    TitleBox bzov_cut_title,pos={590,88},size={250,18},title="Analyzer scan-cut overlay",frame=0
    CheckBox bzov_ck_cutshow,pos={590,116},size={155,18},title="Show analyzer cuts"
    CheckBox bzov_ck_cutshow,variable=root:ARPES_LJZ:BZOverlay:cutShow
    PopupMenu bzov_pm_cutmode,pos={590,144},size={250,20},proc=BZOV_pm_cutmode,title="Cut mode"
    PopupMenu bzov_pm_cutmode,mode=1,popvalue="Single scan angle",value=#"BZOV_CutModePopupList()"
    Button bzov_btn_use_ekk,pos={855,142},size={140,23},proc=BZOV_btn_use_ekk,title="Use EKKMap params"

    SetVariable bzov_sv_chv,pos={590,176},size={185,20},title="hv"
    SetVariable bzov_sv_chv,limits={0,1e6,0.1},value=root:ARPES_LJZ:BZOverlay:cutHv
    SetVariable bzov_sv_cwf,pos={790,176},size={185,20},title="WorkFunc"
    SetVariable bzov_sv_cwf,limits={0,1e6,0.1},value=root:ARPES_LJZ:BZOverlay:cutWorkFunc
    SetVariable bzov_sv_ce,pos={590,204},size={185,20},title="E_rel"
    SetVariable bzov_sv_ce,limits={-1e6,1e6,0.001},value=root:ARPES_LJZ:BZOverlay:cutEnergyRel
    SetVariable bzov_sv_ca,pos={790,204},size={185,20},title="LatticeA"
    SetVariable bzov_sv_ca,limits={0,1e6,0.001},value=root:ARPES_LJZ:BZOverlay:cutLatticeA

    SetVariable bzov_sv_ctilt,pos={590,240},size={185,20},title="Tilt"
    SetVariable bzov_sv_ctilt,limits={-360,360,0.1},value=root:ARPES_LJZ:BZOverlay:cutTilt
    SetVariable bzov_sv_cazi,pos={790,240},size={185,20},title="Azimuth"
    SetVariable bzov_sv_cazi,limits={-360,360,0.1},value=root:ARPES_LJZ:BZOverlay:cutAzimuth
    SetVariable bzov_sv_cso,pos={590,268},size={185,20},title="Scan offset"
    SetVariable bzov_sv_cso,limits={-360,360,0.1},value=root:ARPES_LJZ:BZOverlay:cutScanOffset
    CheckBox bzov_ck_cgeo,pos={790,270},size={155,18},title="WTZ geometry"
    CheckBox bzov_ck_cgeo,variable=root:ARPES_LJZ:BZOverlay:cutGeometry

    SetVariable bzov_sv_amin,pos={590,304},size={185,20},title="alpha min"
    SetVariable bzov_sv_amin,limits={-360,360,0.1},value=root:ARPES_LJZ:BZOverlay:cutAlphaMin
    SetVariable bzov_sv_amax,pos={790,304},size={185,20},title="alpha max"
    SetVariable bzov_sv_amax,limits={-360,360,0.1},value=root:ARPES_LJZ:BZOverlay:cutAlphaMax
    SetVariable bzov_sv_an,pos={590,332},size={185,20},title="alpha N"
    SetVariable bzov_sv_an,limits={2,5000,1},value=root:ARPES_LJZ:BZOverlay:cutAlphaN

    SetVariable bzov_sv_sval,pos={590,368},size={185,20},title="single scan"
    SetVariable bzov_sv_sval,limits={-360,360,0.1},value=root:ARPES_LJZ:BZOverlay:cutScanValue
    SetVariable bzov_sv_smin,pos={590,396},size={185,20},title="scan min"
    SetVariable bzov_sv_smin,limits={-360,360,0.1},value=root:ARPES_LJZ:BZOverlay:cutScanMin
    SetVariable bzov_sv_smax,pos={790,396},size={185,20},title="scan max"
    SetVariable bzov_sv_smax,limits={-360,360,0.1},value=root:ARPES_LJZ:BZOverlay:cutScanMax
    SetVariable bzov_sv_sstep,pos={590,424},size={185,20},title="scan step"
    SetVariable bzov_sv_sstep,limits={0.001,360,0.1},value=root:ARPES_LJZ:BZOverlay:cutScanStep

    PopupMenu bzov_pm_cutcolor,pos={590,456},size={210,20},proc=BZOV_pm_cutcolor,title="Cut color"
    PopupMenu bzov_pm_cutcolor,mode=9,popvalue="Orange",value=#"BZOV_ColorPopupList()"
    SetVariable bzov_sv_clw,pos={590,486},size={185,20},title="cut width"
    SetVariable bzov_sv_clw,limits={0.1,10,0.1},value=root:ARPES_LJZ:BZOverlay:cutLineWidth
    SetVariable bzov_sv_cls,pos={790,486},size={185,20},title="cut style"
    SetVariable bzov_sv_cls,limits={0,18,1},value=root:ARPES_LJZ:BZOverlay:cutLineStyle
    CheckBox bzov_ck_clab,pos={590,514},size={170,18},title="Label scan angles"
    CheckBox bzov_ck_clab,variable=root:ARPES_LJZ:BZOverlay:cutShowLabels

    Button bzov_btn_display,pos={12,590},size={155,28},proc=BZOV_btn_display,title="Display FS + BZ"
    Button bzov_btn_overlay,pos={176,590},size={125,28},proc=BZOV_btn_overlay_top,title="Overlay Top Graph"
    Button bzov_btn_cuts,pos={310,590},size={105,28},proc=BZOV_btn_draw_cuts,title="Draw Cuts"
    Button bzov_btn_clear,pos={425,590},size={105,28},proc=BZOV_btn_clear_top,title="Clear Top"
    Button bzov_btn_help,pos={540,590},size={65,24},proc=BZOV_btn_help,title="Help"
    Button bzov_btn_close,pos={615,590},size={65,24},proc=BZOV_btn_close,title="Close"
EndMacro

// ------------------------------- UI callbacks -------------------------------
Function BZOV_sv_df_proc(ctrlName, varNum, varStr, varName) : SetVariableControl
    String ctrlName, varStr, varName
    Variable varNum
    BZOV_RebuildLB()
    return 0
End

Function BZOV_btn_current(ctrlName) : ButtonControl
    String ctrlName
    SVAR baseDF = root:ARPES_LJZ:BZOverlay:baseDF
    baseDF = GetDataFolder(1)
    BZOV_RebuildLB()
    return 0
End

Function BZOV_btn_scan(ctrlName) : ButtonControl
    String ctrlName
    BZOV_RebuildLB()
    return 0
End

Function BZOV_btn_close(ctrlName) : ButtonControl
    String ctrlName
    DoWindow/K LJZ_BZOverlay_Panel
    return 0
End

Function BZOV_pm_lattice(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName, popStr
    Variable popNum
    NVAR latticeType = root:ARPES_LJZ:BZOverlay:latticeType
    NVAR a = root:ARPES_LJZ:BZOverlay:a
    NVAR b = root:ARPES_LJZ:BZOverlay:b
    NVAR gammaDeg = root:ARPES_LJZ:BZOverlay:gammaDeg

    latticeType = popNum - 1
    if (latticeType == 0)
        b = a
        gammaDeg = 90
    elseif (latticeType == 2)
        b = a
        gammaDeg = 60
    elseif (latticeType == 1)
        gammaDeg = 90
    endif
    return 0
End

Function BZOV_pm_unit(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName, popStr
    Variable popNum
    NVAR unitMode = root:ARPES_LJZ:BZOverlay:unitMode
    unitMode = popNum - 1
    return 0
End

Function BZOV_pm_color(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName, popStr
    Variable popNum
    NVAR colorMode = root:ARPES_LJZ:BZOverlay:colorMode
    colorMode = popNum - 1
    return 0
End

Function BZOV_pm_cutcolor(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName, popStr
    Variable popNum
    NVAR cutColorMode = root:ARPES_LJZ:BZOverlay:cutColorMode
    cutColorMode = popNum - 1
    return 0
End

Function BZOV_pm_cutmode(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName, popStr
    Variable popNum
    NVAR cutMode = root:ARPES_LJZ:BZOverlay:cutMode
    cutMode = popNum - 1
    return 0
End

Function BZOV_btn_use_ekk(ctrlName) : ButtonControl
    String ctrlName
    BZOV_CopyEKKMapParamsToCuts()
    return 0
End

Function BZOV_btn_draw_cuts(ctrlName) : ButtonControl
    String ctrlName
    String gName = WinName(0,1)
    if (strlen(gName) == 0)
        Abort "BZ Overlay: no top graph window. First display a 2D FS image."
    endif
    BZOV_DrawCutsOverlay(gName)
    return 0
End

Function BZOV_lb_proc(ctrlName, row, col, eventCode) : ListBoxControl
    String ctrlName
    Variable row, col, eventCode
    if (eventCode != 4 && eventCode != 1 && eventCode != 3)
        return 0
    endif

    Wave/T items = root:ARPES_LJZ:BZOverlay:LB_Items
    Wave/U/B sel = root:ARPES_LJZ:BZOverlay:LB_Sel
    SVAR wavePath = root:ARPES_LJZ:BZOverlay:wavePath
    SVAR baseDF = root:ARPES_LJZ:BZOverlay:baseDF

    if (row < 0 || row >= DimSize(items,0))
        return 0
    endif

    sel = 0
    sel[row] = 1
    wavePath = BZOV_DFWithColon(baseDF) + items[row]

    DoWindow LJZ_BZOverlay_Panel
    if (V_flag)
        TitleBox bzov_status, win=LJZ_BZOverlay_Panel, title=("Selected: " + wavePath)
    endif
    return 0
End

Function BZOV_btn_display(ctrlName) : ButtonControl
    String ctrlName
    Wave fs = BZOV_GetSelectedWave()
    BZOV_DisplayFSWithBZ(fs)
    return 0
End

Function BZOV_btn_overlay_top(ctrlName) : ButtonControl
    String ctrlName
    String gName = WinName(0,1)
    if (strlen(gName) == 0)
        Abort "BZ Overlay: no top graph window. First display a 2D FS image."
    endif
    BZOV_DrawBZOverlay(gName)
    return 0
End

Function BZOV_btn_clear_top(ctrlName) : ButtonControl
    String ctrlName
    String gName = WinName(0,1)
    if (strlen(gName) == 0)
        Abort "BZ Overlay: no top graph window."
    endif
    BZOV_ClearOverlay(gName)
    return 0
End

Function BZOV_btn_help(ctrlName) : ButtonControl
    String ctrlName
    String nb = "LJZ_BZOverlay_Help"
    DoWindow/F $nb
    if (V_flag == 0)
        NewNotebook/N=$nb/F=1/V=1 as "BZ Overlay Help"
    endif
    Notebook $nb selection={startOfFile,endOfFile}
    Notebook $nb text="LJZ_BZOverlay help\r"
    Notebook $nb text="==================\r"
    Notebook $nb text="Input wave must be a 2D kx-ky Fermi-surface image.\r"
    Notebook $nb text="The wave x/y axes are used directly as kx/ky coordinates.\r\r"
    Notebook $nb text="Unit mode:\r"
    Notebook $nb text="  A^-1 : a,b are in Angstrom and BZ is drawn in inverse Angstrom.\r"
    Notebook $nb text="  pi/a : reciprocal vectors are multiplied by a/pi, so square-lattice BZ edges are at +/-1.\r\r"
    Notebook $nb text="Lattice type:\r"
    Notebook $nb text="  Square:      b=a, gamma=90 deg.\r"
    Notebook $nb text="  Rectangular: gamma=90 deg.\r"
    Notebook $nb text="  Hexagonal:   b=a, gamma=60 deg.\r"
    Notebook $nb text="  Custom2D:    use a,b,gamma directly.\r\r"
    Notebook $nb text="center kx/ky shifts the BZ center without changing the image data.\r"
    Notebook $nb text="repeat N=1 draws a 3x3 group of BZ cells if Show repeated BZ is checked.\r\r"
    Notebook $nb text="Analyzer cuts:\r"
    Notebook $nb text="  Enable Show analyzer cuts, then choose Single scan angle or Multiple scan angles.\r"
    Notebook $nb text="  alpha min/max/N define the analyzer-slit angular coordinate sampled along each cut.\r"
    Notebook $nb text="  single scan is one manipulator/scan angle; scan min/max/step draws a family of scan cuts.\r"
    Notebook $nb text="  hv, WorkFunc, E_rel, Tilt, Azimuth, Scan offset, LatticeA and WTZ geometry use the same convention as LJZ_EKKMap_CalcKxKy2D.\r"
    Notebook $nb text="  Use EKKMap params copies common mapping parameters from root:ARPES_LJZ:EKKMap if that panel has been used.\r"
    return 0
End

// ---------------------------- list/select waves -----------------------------
Function BZOV_RebuildLB()
    BZOV_EnsureDF()
    SVAR baseDF = root:ARPES_LJZ:BZOverlay:baseDF
    SVAR wavePath = root:ARPES_LJZ:BZOverlay:wavePath
    Wave/T items = root:ARPES_LJZ:BZOverlay:LB_Items
    Wave/U/B sel = root:ARPES_LJZ:BZOverlay:LB_Sel

    String df0 = GetDataFolder(1)
    String base = BZOV_DFWithColon(baseDF)
    if (!BZOV_DFExists(base))
        base = "root:"
    endif
    baseDF = base
    wavePath = ""

    SetDataFolder $base
    String list = WaveList("*", ";", "DIMS:2")
    SetDataFolder df0

    Variable nRaw = ItemsInList(list, ";")
    String goodList = ""
    Variable i
    for (i=0; i<nRaw; i+=1)
        String wn = StringFromList(i, list, ";")
        Wave/Z w = $(base + wn)
        if (!WaveExists(w))
            continue
        endif
        if (WaveType(w) == 0)
            continue
        endif
        goodList += wn + ";"
    endfor

    Variable n = ItemsInList(goodList, ";")
    Redimension/N=(n) items, sel
    for (i=0; i<n; i+=1)
        items[i] = StringFromList(i, goodList, ";")
        sel[i] = 0
    endfor

    if (n > 0)
        sel[0] = 1
        wavePath = base + items[0]
    endif

    DoWindow LJZ_BZOverlay_Panel
    if (V_flag)
        ControlUpdate/W=LJZ_BZOverlay_Panel bzov_lb
        TitleBox bzov_status, win=LJZ_BZOverlay_Panel, title=("Selected: " + SelectString(strlen(wavePath)>0, "(none)", wavePath))
    endif
    return 0
End

Function/WAVE BZOV_GetSelectedWave()
    SVAR wavePath = root:ARPES_LJZ:BZOverlay:wavePath
    if (strlen(wavePath) == 0)
        Abort "BZ Overlay: no 2D wave selected."
    endif
    Wave/Z w = $wavePath
    if (!WaveExists(w))
        Abort "BZ Overlay: selected wave does not exist."
    endif
    if (WaveType(w) == 0 || WaveDims(w) != 2)
        Abort "BZ Overlay: selected wave must be a numeric 2D image."
    endif
    return w
End

// -------------------------- display and graph style -------------------------
Function BZOV_DisplayFSWithBZ(fs)
    Wave fs

    String gName = BZOV_SafeWinName("BZFS_", fs)
    DoWindow/K $gName
    Display/K=1/N=$gName
    AppendImage/W=$gName fs

    ModifyGraph/W=$gName margin(left)=58,margin(bottom)=48,margin(right)=22,margin(top)=16,mirror=2,standoff=0
    NVAR imagePlan = root:ARPES_LJZ:BZOverlay:imagePlan
    if (imagePlan)
        ModifyGraph/W=$gName width={Plan,1,bottom,left}
    else
        ModifyGraph/W=$gName width=0,height=0
    endif

    String xu = WaveUnits(fs,0)
    String yu = WaveUnits(fs,1)
    if (strlen(xu) == 0)
        xu = ""
    endif
    if (strlen(yu) == 0)
        yu = ""
    endif
    Label/W=$gName bottom, "k\Bx\M " + SelectString(strlen(xu)>0, "", "("+xu+")")
    Label/W=$gName left,   "k\By\M " + SelectString(strlen(yu)>0, "", "("+yu+")")

    SetAxis/A/W=$gName bottom
    SetAxis/A/W=$gName left
    ColorScale/C/N=bzov_colorScale/F=0/A=RC/E/W=$gName image=$NameOfWave(fs), heightPct=35, widthPct=3, frame=1

    BZOV_DrawBZOverlay(gName)
    return 0
End

// ------------------------ reciprocal lattice vectors ------------------------
Function BZOV_GetRealParams(latticeType, aIn, bIn, gammaIn, aOut, bOut, gammaOut)
    Variable latticeType, aIn, bIn, gammaIn
    Variable &aOut, &bOut, &gammaOut

    aOut = aIn
    bOut = bIn
    gammaOut = gammaIn

    if (latticeType == 0)       // square
        bOut = aOut
        gammaOut = 90
    elseif (latticeType == 1)   // rectangular
        gammaOut = 90
    elseif (latticeType == 2)   // hexagonal / triangular real lattice
        bOut = aOut
        gammaOut = 60
    endif

    if (aOut <= 0 || bOut <= 0)
        Abort "BZ Overlay: lattice constants must be positive."
    endif
    if (gammaOut <= 0 || gammaOut >= 180)
        Abort "BZ Overlay: gamma must be between 0 and 180 degrees."
    endif
    return 0
End

Function BZOV_GetReciprocalVectors(b1x, b1y, b2x, b2y)
    Variable &b1x, &b1y, &b2x, &b2y

    NVAR latticeType = root:ARPES_LJZ:BZOverlay:latticeType
    NVAR aIn = root:ARPES_LJZ:BZOverlay:a
    NVAR bIn = root:ARPES_LJZ:BZOverlay:b
    NVAR gammaIn = root:ARPES_LJZ:BZOverlay:gammaDeg
    NVAR unitMode = root:ARPES_LJZ:BZOverlay:unitMode

    Variable aa, bb, gg
    BZOV_GetRealParams(latticeType, aIn, bIn, gammaIn, aa, bb, gg)

    Variable gr = gg*pi/180.0
    Variable s = sin(gr)
    Variable c = cos(gr)
    if (abs(s) < 1e-12)
        Abort "BZ Overlay: invalid lattice angle; sin(gamma) too small."
    endif

    // Real-space basis convention:
    //   a1 = (a, 0)
    //   a2 = (b cos gamma, b sin gamma)
    // Reciprocal vectors satisfy ai · bj = 2*pi*delta_ij.
    b1x = 2*pi/aa
    b1y = -2*pi*c/(aa*s)
    b2x = 0
    b2y = 2*pi/(bb*s)

    // If the image axes are in pi/a units, convert A^-1 -> pi/a by multiplying a/pi.
    if (unitMode == 1)
        Variable conv = aa/pi
        b1x *= conv
        b1y *= conv
        b2x *= conv
        b2y *= conv
    endif
    return 0
End

// -------------------- Wigner-Seitz first-BZ construction --------------------
Function/WAVE BZOV_MakeFirstBZPolygon()
    BZOV_EnsureDF()

    Variable b1x, b1y, b2x, b2y
    BZOV_GetReciprocalVectors(b1x, b1y, b2x, b2y)

    String outDF = BZOV_OutputDF()
    String polyAPath = outDF + ":bzov_polyA"
    String polyBPath = outDF + ":bzov_polyB"

    Variable R = 4*(abs(b1x)+abs(b1y)+abs(b2x)+abs(b2y)+1)
    Make/O/D/N=(4,2) $polyAPath
    Wave polyA = $polyAPath
    polyA[0][0] = -R; polyA[0][1] = -R
    polyA[1][0] =  R; polyA[1][1] = -R
    polyA[2][0] =  R; polyA[2][1] =  R
    polyA[3][0] = -R; polyA[3][1] =  R

    Make/O/D/N=(16,2) $polyBPath
    Wave polyB = $polyBPath

    Variable m, n
    for (m=-3; m<=3; m+=1)
        for (n=-3; n<=3; n+=1)
            if (m == 0 && n == 0)
                continue
            endif
            Variable Gx = m*b1x + n*b2x
            Variable Gy = m*b1y + n*b2y
            if (sqrt(Gx*Gx + Gy*Gy) < 1e-12)
                continue
            endif
            BZOV_ClipPolygonByG(polyA, polyB, Gx, Gy)
            Duplicate/O polyB, polyA
            if (DimSize(polyA,0) < 3)
                Abort "BZ Overlay: Wigner-Seitz polygon collapsed. Check lattice parameters."
            endif
        endfor
    endfor

    // Sort vertices angularly around Gamma to make a clean boundary path.
    BZOV_SortPolygonByAngle(polyA)
    return polyA
End

Function BZOV_ClipPolygonByG(src, dest, Gx, Gy)
    Wave src
    Wave dest
    Variable Gx, Gy

    Variable n = DimSize(src,0)
    if (n < 3)
        Redimension/N=(0,2) dest
        return 0
    endif

    Redimension/N=(2*n+4,2) dest
    dest = NaN

    Variable c = 0.5*(Gx*Gx + Gy*Gy)
    Variable eps = 1e-10*(1+abs(c))
    Variable i, k=0

    for (i=0; i<n; i+=1)
        Variable i2 = mod(i+1,n)
        Variable sx = src[i][0]
        Variable sy = src[i][1]
        Variable ex = src[i2][0]
        Variable ey = src[i2][1]
        Variable ds = sx*Gx + sy*Gy - c
        Variable de = ex*Gx + ey*Gy - c
        Variable inS = (ds <= eps)
        Variable inE = (de <= eps)

        if (inS && inE)
            dest[k][0] = ex
            dest[k][1] = ey
            k += 1
        elseif (inS && !inE)
            BZOV_AddIntersection(dest, k, sx, sy, ex, ey, ds, de)
        elseif (!inS && inE)
            BZOV_AddIntersection(dest, k, sx, sy, ex, ey, ds, de)
            dest[k][0] = ex
            dest[k][1] = ey
            k += 1
        endif
    endfor

    Redimension/N=(k,2) dest
    return k
End

Function BZOV_AddIntersection(dest, k, sx, sy, ex, ey, ds, de)
    Wave dest
    Variable &k
    Variable sx, sy, ex, ey, ds, de

    Variable denom = ds - de
    if (abs(denom) < 1e-20)
        return 0
    endif
    Variable t = ds/(ds-de)
    t = max(0, min(1, t))
    dest[k][0] = sx + t*(ex-sx)
    dest[k][1] = sy + t*(ey-sy)
    k += 1
    return 0
End

Function BZOV_SortPolygonByAngle(poly)
    Wave poly
    Variable n = DimSize(poly,0)
    if (n <= 2)
        return 0
    endif

    String outDF = BZOV_OutputDF()
    Make/O/D/N=(n) $(outDF+":bzov_angle")
    Make/O/D/N=(n) $(outDF+":bzov_xsort")
    Make/O/D/N=(n) $(outDF+":bzov_ysort")
    Wave ang = $(outDF+":bzov_angle")
    Wave xs  = $(outDF+":bzov_xsort")
    Wave ys  = $(outDF+":bzov_ysort")

    Variable i
    for (i=0; i<n; i+=1)
        xs[i] = poly[i][0]
        ys[i] = poly[i][1]
        ang[i] = atan2(poly[i][1], poly[i][0])
    endfor

    Sort ang, ang, xs, ys
    for (i=0; i<n; i+=1)
        poly[i][0] = xs[i]
        poly[i][1] = ys[i]
    endfor

    KillWaves/Z ang, xs, ys
    return 0
End

// ----------------------------- draw overlay ---------------------------------
Function BZOV_DrawBZOverlay(gName)
    String gName
    if (WinType(gName) != 1)
        Abort "BZ Overlay: target must be a graph."
    endif

    Wave poly = BZOV_MakeFirstBZPolygon()
    BZOV_ClearOverlay(gName)

    Variable b1x, b1y, b2x, b2y
    BZOV_GetReciprocalVectors(b1x, b1y, b2x, b2y)

    NVAR centerX = root:ARPES_LJZ:BZOverlay:centerX
    NVAR centerY = root:ARPES_LJZ:BZOverlay:centerY
    NVAR repeatN = root:ARPES_LJZ:BZOverlay:repeatN
    NVAR showRepeated = root:ARPES_LJZ:BZOverlay:showRepeated
    NVAR showLabels = root:ARPES_LJZ:BZOverlay:showLabels
    NVAR lineWidth = root:ARPES_LJZ:BZOverlay:lineWidth
    NVAR colorMode = root:ARPES_LJZ:BZOverlay:colorMode

    repeatN = round(repeatN)
    if (repeatN < 0)
        repeatN = 0
    endif
    if (!showRepeated)
        repeatN = 0
    endif

    Variable r16, g16, b16
    BZOV_RGBFromMode(colorMode, r16, g16, b16)

    String outDF = BZOV_OutputDF()
    Variable nv = DimSize(poly,0)
    Variable idx = 0
    Variable m, n, i
    for (m=-repeatN; m<=repeatN; m+=1)
        for (n=-repeatN; n<=repeatN; n+=1)
            Variable tx = centerX + m*b1x + n*b2x
            Variable ty = centerY + m*b1y + n*b2y

            String xPath = outDF + ":bzov_lineX_" + num2str(idx)
            String yPath = outDF + ":bzov_lineY_" + num2str(idx)
            Make/O/D/N=(nv+1) $xPath/WAVE=xw, $yPath/WAVE=yw
            for (i=0; i<nv; i+=1)
                xw[i] = poly[i][0] + tx
                yw[i] = poly[i][1] + ty
            endfor
            xw[nv] = poly[0][0] + tx
            yw[nv] = poly[0][1] + ty

            AppendToGraph/W=$gName yw vs xw
            String tr = NameOfWave(yw)
            if (m == 0 && n == 0)
                ModifyGraph/W=$gName mode($tr)=0,lsize($tr)=lineWidth,rgb($tr)=(r16,g16,b16)
            else
                ModifyGraph/W=$gName mode($tr)=0,lsize($tr)=max(0.5,lineWidth*0.7),lstyle($tr)=3,rgb($tr)=(r16,g16,b16)
            endif
            idx += 1
        endfor
    endfor

    if (showLabels)
        BZOV_DrawHighSymLabels(gName, r16, g16, b16)
    endif

    NVAR cutShow = root:ARPES_LJZ:BZOverlay:cutShow
    if (cutShow)
        BZOV_DrawCutsOverlay_NoClear(gName)
    endif

    ModifyGraph/W=$gName tickUnit(bottom)=1,tickUnit(left)=1
    DoUpdate
    return 0
End

Function BZOV_ClearOverlay(gName)
    String gName
    if (WinType(gName) != 1)
        return -1
    endif

    // Remove line/marker traces from previous BZ overlays.
    String trList = TraceNameList(gName, ";", 1)
    Variable i, n = ItemsInList(trList, ";")
    for (i=n-1; i>=0; i-=1)
        String tr = StringFromList(i, trList, ";")
        if (StringMatch(tr, "bzov_lineY_*") || StringMatch(tr, "bzov_labelY") || StringMatch(tr, "bzov_cutY_*") || StringMatch(tr, "bzov_cutMarkY"))
            RemoveFromGraph/W=$gName/Z $tr
        endif
    endfor

    // Clear our text labels by clearing UserFront drawing layer.
    // This will remove other UserFront drawings in the target graph as well.
    SetDrawLayer/W=$gName/K UserFront
    SetDrawLayer/W=$gName UserFront
    return 0
End

Function BZOV_RGBFromMode(mode, r16, g16, b16)
    Variable mode
    Variable &r16, &g16, &b16

    if (mode == 0)          // black
        r16 = 0;      g16 = 0;      b16 = 0
    elseif (mode == 1)      // white
        r16 = 65535;  g16 = 65535;  b16 = 65535
    elseif (mode == 2)      // red
        r16 = 65535;  g16 = 0;      b16 = 0
    elseif (mode == 3)      // green
        r16 = 0;      g16 = 52000;  b16 = 0
    elseif (mode == 4)      // blue
        r16 = 0;      g16 = 16000;  b16 = 65535
    elseif (mode == 5)      // yellow
        r16 = 65535;  g16 = 52000;  b16 = 0
    elseif (mode == 6)      // cyan
        r16 = 0;      g16 = 52000;  b16 = 65535
    elseif (mode == 7)      // magenta
        r16 = 65535;  g16 = 0;      b16 = 65535
    elseif (mode == 8)      // orange
        r16 = 65535;  g16 = 31000;  b16 = 0
    elseif (mode == 9)      // purple
        r16 = 41000;  g16 = 0;      b16 = 65535
    else                    // gray
        r16 = 40000;  g16 = 40000;  b16 = 40000
    endif
    return 0
End


// ------------------------ analyzer scan-cut overlay -------------------------
Function BZOV_KScaleA(latticeA)
    Variable latticeA
    if (latticeA == 0)
        return 0.5118
    endif
    return 0.5118 * latticeA / pi
End

Function BZOV_KxKyForward(alphaDeg, scanDeg, energyRel, hv, workFunc, tilt, azimuth, scanOffset, latticeA, geo, kxOut, kyOut)
    Variable alphaDeg, scanDeg, energyRel, hv, workFunc, tilt, azimuth, scanOffset, latticeA, geo
    Variable &kxOut, &kyOut

    Variable kin = hv - workFunc + energyRel
    if (kin <= 0 || numtype(kin) != 0)
        kxOut = NaN
        kyOut = NaN
        return -1
    endif

    Variable k0 = BZOV_KScaleA(latticeA) * sqrt(kin)
    Variable ar = alphaDeg*pi/180
    Variable sr, ky0, kz0, kx1, ky1, kz1, rr, ph

    if (geo)
        // Same forward geometry convention as LJZ_EKKMap_CalcKxKy2D:
        // x = analyzer/slit angle alpha, y = scan angle.
        ky0 = k0 * sin(ar)
        kz0 = k0 * cos(ar)
        sr = (scanDeg - scanOffset)*pi/180
        kx1 = kz0 * sin(sr)
        ky1 = ky0 * cos(tilt*pi/180) - kz0 * cos(sr) * sin(tilt*pi/180)
        rr = sqrt(kx1*kx1 + ky1*ky1)
        ph = atan2(ky1, kx1) + azimuth*pi/180
        kxOut = rr * cos(ph)
        kyOut = rr * sin(ph)
    else
        // Legacy alternate convention retained for compatibility with the mapping panel.
        Variable ty1 = k0 * sin((scanDeg + scanOffset)*pi/180) * cos((alphaDeg + tilt)*pi/180)
        Variable tx1 = k0 * sin((alphaDeg + tilt)*pi/180)
        rr = sqrt(tx1*tx1 + ty1*ty1)
        ph = atan2(ty1, tx1) + azimuth*pi/180
        kxOut = rr * cos(ph)
        kyOut = rr * sin(ph)
    endif
    return 0
End

Function BZOV_CopyEKKMapParamsToCuts()
    BZOV_EnsureDF()

    NVAR cutHv = root:ARPES_LJZ:BZOverlay:cutHv
    NVAR cutWorkFunc = root:ARPES_LJZ:BZOverlay:cutWorkFunc
    NVAR cutEnergyRel = root:ARPES_LJZ:BZOverlay:cutEnergyRel
    NVAR cutTilt = root:ARPES_LJZ:BZOverlay:cutTilt
    NVAR cutAzimuth = root:ARPES_LJZ:BZOverlay:cutAzimuth
    NVAR cutScanOffset = root:ARPES_LJZ:BZOverlay:cutScanOffset
    NVAR cutLatticeA = root:ARPES_LJZ:BZOverlay:cutLatticeA
    NVAR cutGeometry = root:ARPES_LJZ:BZOverlay:cutGeometry

    NVAR/Z hv = root:ARPES_LJZ:EKKMap:hv
    if (NVAR_Exists(hv))
        cutHv = hv
    endif
    NVAR/Z wf = root:ARPES_LJZ:EKKMap:WorkFunc
    if (NVAR_Exists(wf))
        cutWorkFunc = wf
    endif
    NVAR/Z er = root:ARPES_LJZ:EKKMap:EnergyRel
    if (NVAR_Exists(er))
        cutEnergyRel = er
    endif
    NVAR/Z theta = root:ARPES_LJZ:EKKMap:ThetaAngle
    if (NVAR_Exists(theta))
        cutTilt = theta
    endif
    NVAR/Z azi = root:ARPES_LJZ:EKKMap:Azimuth
    if (NVAR_Exists(azi))
        cutAzimuth = azi
    endif
    NVAR/Z off = root:ARPES_LJZ:EKKMap:ScanOffset
    if (NVAR_Exists(off))
        cutScanOffset = off
    endif
    NVAR/Z la = root:ARPES_LJZ:EKKMap:LatticeA
    if (NVAR_Exists(la))
        cutLatticeA = la
    endif
    NVAR/Z geo = root:ARPES_LJZ:EKKMap:Geometry
    if (NVAR_Exists(geo))
        cutGeometry = geo
    endif

    DoWindow LJZ_BZOverlay_Panel
    if (V_flag)
        ControlUpdate/W=LJZ_BZOverlay_Panel bzov_sv_chv
        ControlUpdate/W=LJZ_BZOverlay_Panel bzov_sv_cwf
        ControlUpdate/W=LJZ_BZOverlay_Panel bzov_sv_ce
        ControlUpdate/W=LJZ_BZOverlay_Panel bzov_sv_ctilt
        ControlUpdate/W=LJZ_BZOverlay_Panel bzov_sv_cazi
        ControlUpdate/W=LJZ_BZOverlay_Panel bzov_sv_cso
        ControlUpdate/W=LJZ_BZOverlay_Panel bzov_sv_ca
        ControlUpdate/W=LJZ_BZOverlay_Panel bzov_ck_cgeo
    endif
    return 0
End

Function BZOV_ClearCutsOnly(gName)
    String gName
    if (WinType(gName) != 1)
        return -1
    endif

    String trList = TraceNameList(gName, ";", 1)
    Variable i, n = ItemsInList(trList, ";")
    for (i=n-1; i>=0; i-=1)
        String tr = StringFromList(i, trList, ";")
        if (StringMatch(tr, "bzov_cutY_*") || StringMatch(tr, "bzov_cutMarkY"))
            RemoveFromGraph/W=$gName/Z $tr
        endif
    endfor
    // Cut text labels share UserFront with BZ labels. Redrawing full overlay is cleaner
    // when labels are used; Draw Cuts only avoids clearing existing BZ lines.
    return 0
End

Function BZOV_DrawCutsOverlay(gName)
    String gName
    BZOV_ClearCutsOnly(gName)
    return BZOV_DrawCutsOverlay_NoClear(gName)
End

Function BZOV_DrawCutsOverlay_NoClear(gName)
    String gName
    if (WinType(gName) != 1)
        Abort "BZ Overlay: target must be a graph."
    endif

    NVAR cutMode = root:ARPES_LJZ:BZOverlay:cutMode
    NVAR cutColorMode = root:ARPES_LJZ:BZOverlay:cutColorMode
    NVAR cutLineWidth = root:ARPES_LJZ:BZOverlay:cutLineWidth
    NVAR cutLineStyle = root:ARPES_LJZ:BZOverlay:cutLineStyle
    NVAR cutShowLabels = root:ARPES_LJZ:BZOverlay:cutShowLabels
    NVAR cutHv = root:ARPES_LJZ:BZOverlay:cutHv
    NVAR cutWorkFunc = root:ARPES_LJZ:BZOverlay:cutWorkFunc
    NVAR cutEnergyRel = root:ARPES_LJZ:BZOverlay:cutEnergyRel
    NVAR cutTilt = root:ARPES_LJZ:BZOverlay:cutTilt
    NVAR cutAzimuth = root:ARPES_LJZ:BZOverlay:cutAzimuth
    NVAR cutScanOffset = root:ARPES_LJZ:BZOverlay:cutScanOffset
    NVAR cutLatticeA = root:ARPES_LJZ:BZOverlay:cutLatticeA
    NVAR cutGeometry = root:ARPES_LJZ:BZOverlay:cutGeometry
    NVAR cutAlphaMin = root:ARPES_LJZ:BZOverlay:cutAlphaMin
    NVAR cutAlphaMax = root:ARPES_LJZ:BZOverlay:cutAlphaMax
    NVAR cutAlphaN = root:ARPES_LJZ:BZOverlay:cutAlphaN
    NVAR cutScanValue = root:ARPES_LJZ:BZOverlay:cutScanValue
    NVAR cutScanMin = root:ARPES_LJZ:BZOverlay:cutScanMin
    NVAR cutScanMax = root:ARPES_LJZ:BZOverlay:cutScanMax
    NVAR cutScanStep = root:ARPES_LJZ:BZOverlay:cutScanStep
    NVAR labelSize = root:ARPES_LJZ:BZOverlay:labelSize

    Variable kin = cutHv - cutWorkFunc + cutEnergyRel
    if (kin <= 0 || numtype(kin) != 0)
        Abort "BZ Overlay: invalid cut kinetic energy. Need hv - WorkFunc + E_rel > 0."
    endif

    Variable nAlpha = max(2, round(cutAlphaN))
    Variable cR, cG, cB
    BZOV_RGBFromMode(cutColorMode, cR, cG, cB)

    Variable s0, s1, ds, nCuts
    if (cutMode == 0)
        s0 = cutScanValue
        s1 = cutScanValue
        ds = 1
        nCuts = 1
    else
        s0 = cutScanMin
        s1 = cutScanMax
        ds = abs(cutScanStep)
        if (ds <= 0)
            Abort "BZ Overlay: cutScanStep must be positive."
        endif
        nCuts = floor(abs(s1-s0)/ds + 0.5) + 1
        nCuts = max(1, nCuts)
        if (nCuts > 300)
            Abort "BZ Overlay: too many cuts. Increase scan step or reduce scan range."
        endif
    endif

    String outDF = BZOV_OutputDF()
    Variable ic, ia
    for (ic=0; ic<nCuts; ic+=1)
        Variable scanVal
        if (cutMode == 0)
            scanVal = s0
        else
            scanVal = (s1 >= s0) ? (s0 + ic*ds) : (s0 - ic*ds)
            if ((s1 >= s0 && scanVal > s1) || (s1 < s0 && scanVal < s1))
                scanVal = s1
            endif
        endif

        String xPath = outDF + ":bzov_cutX_" + num2str(ic)
        String yPath = outDF + ":bzov_cutY_" + num2str(ic)
        Make/O/D/N=(nAlpha) $xPath/WAVE=xw, $yPath/WAVE=yw

        for (ia=0; ia<nAlpha; ia+=1)
            Variable alphaVal
            if (nAlpha == 1)
                alphaVal = cutAlphaMin
            else
                alphaVal = cutAlphaMin + (cutAlphaMax-cutAlphaMin)*ia/(nAlpha-1)
            endif
            Variable kxv, kyv
            BZOV_KxKyForward(alphaVal, scanVal, cutEnergyRel, cutHv, cutWorkFunc, cutTilt, cutAzimuth, cutScanOffset, cutLatticeA, cutGeometry, kxv, kyv)
            xw[ia] = kxv
            yw[ia] = kyv
        endfor

        AppendToGraph/W=$gName yw vs xw
        String tr = NameOfWave(yw)
        ModifyGraph/W=$gName mode($tr)=0,lsize($tr)=cutLineWidth,lstyle($tr)=round(cutLineStyle),rgb($tr)=(cR,cG,cB)

        if (cutShowLabels)
            Variable labIndex = max(0, min(nAlpha-1, nAlpha-1))
            SetDrawLayer/W=$gName UserFront
            SetDrawEnv/W=$gName xcoord=bottom,ycoord=left,textrgb=(cR,cG,cB),fsize=labelSize,save
            DrawText/W=$gName xw[labIndex], yw[labIndex], num2str(scanVal) + "°"
        endif
    endfor

    DoUpdate
    return 0
End

// -------------------------- high-symmetry labels ----------------------------
Function BZOV_DrawHighSymLabels(gName, r16, g16, b16)
    String gName
    Variable r16, g16, b16

    NVAR latticeType = root:ARPES_LJZ:BZOverlay:latticeType
    NVAR centerX = root:ARPES_LJZ:BZOverlay:centerX
    NVAR centerY = root:ARPES_LJZ:BZOverlay:centerY
    NVAR labelSize = root:ARPES_LJZ:BZOverlay:labelSize

    Variable b1x, b1y, b2x, b2y
    BZOV_GetReciprocalVectors(b1x, b1y, b2x, b2y)

    String outDF = BZOV_OutputDF()
    String xPath = outDF + ":bzov_labelX"
    String yPath = outDF + ":bzov_labelY"
    String tPath = outDF + ":bzov_labelText"

    Variable nLab
    if (latticeType == 2)
        nLab = 3
    else
        nLab = 4
    endif

    Make/O/D/N=(nLab) $xPath/WAVE=xw, $yPath/WAVE=yw
    Make/O/T/N=(nLab) $tPath/WAVE=tw

    // Gamma
    xw[0] = centerX
    yw[0] = centerY
    tw[0] = "Γ"

    if (latticeType == 2)
        // Hexagonal BZ using triangular real lattice convention.
        // K = (2*b1+b2)/3, M = b1/2, both translated by center.
        xw[1] = centerX + (2*b1x + b2x)/3
        yw[1] = centerY + (2*b1y + b2y)/3
        tw[1] = "K"

        xw[2] = centerX + 0.5*b1x
        yw[2] = centerY + 0.5*b1y
        tw[2] = "M"
    else
        // Square / rectangular / custom: mark +b1/2, +b2/2, and (b1+b2)/2.
        xw[1] = centerX + 0.5*b1x
        yw[1] = centerY + 0.5*b1y
        tw[1] = "X"

        xw[2] = centerX + 0.5*b2x
        yw[2] = centerY + 0.5*b2y
        tw[2] = "Y"

        xw[3] = centerX + 0.5*(b1x+b2x)
        yw[3] = centerY + 0.5*(b1y+b2y)
        tw[3] = "M"
    endif

    AppendToGraph/W=$gName yw vs xw
    String tr = NameOfWave(yw)
    ModifyGraph/W=$gName mode($tr)=3,marker($tr)=19,msize($tr)=3,rgb($tr)=(r16,g16,b16)

    // Draw text labels in axis coordinates. We put all BZ labels on UserFront.
    SetDrawLayer/W=$gName UserFront
    SetDrawEnv/W=$gName xcoord=bottom,ycoord=left,textrgb=(r16,g16,b16),fsize=labelSize,save

    Variable i
    for (i=0; i<nLab; i+=1)
        DrawText/W=$gName xw[i], yw[i], tw[i]
    endfor

    return 0
End

// ------------------------------- public API ---------------------------------
Function LJZ_BZOverlay_DrawSelected()
    BZOV_EnsureDF()
    Wave fs = BZOV_GetSelectedWave()
    return BZOV_DisplayFSWithBZ(fs)
End

Function LJZ_BZOverlay_DrawOnTopGraph()
    BZOV_EnsureDF()
    String gName = WinName(0,1)
    if (strlen(gName) == 0)
        Abort "BZ Overlay: no top graph."
    endif
    return BZOV_DrawBZOverlay(gName)
End

Function LJZ_BZOverlay_ClearTopGraph()
    String gName = WinName(0,1)
    if (strlen(gName) == 0)
        Abort "BZ Overlay: no top graph."
    endif
    return BZOV_ClearOverlay(gName)
End

Function LJZ_BZOverlay_DrawCutsOnTopGraph()
    BZOV_EnsureDF()
    String gName = WinName(0,1)
    if (strlen(gName) == 0)
        Abort "BZ Overlay: no top graph."
    endif
    return BZOV_DrawCutsOverlay(gName)
End

// Convenience command for scripting. Example:
//     Wave fs = root:ARPES_LJZ:EKKMapOutput:FS:fs_my_map
//     LJZ_BZOverlay_DisplayWave(fs)
Function LJZ_BZOverlay_DisplayWave(fs)
    Wave fs
    BZOV_EnsureDF()
    if (WaveType(fs) == 0 || WaveDims(fs) != 2)
        Abort "LJZ_BZOverlay_DisplayWave: input must be a numeric 2D wave."
    endif
    return BZOV_DisplayFSWithBZ(fs)
End
