#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//============================
// 菜单入口
//============================
Menu "ARPES_LJZ"
    "2025FFT3D_LJZ", FFT3D_LJZ()
    "2025MDCFIT_LJZ", MDCFit_LJZ()
    "2025ROIVARY_LJZ",ROIVARY_LJZ()
    "CT Panel (5 colors)", CTLUZ_LJZ()
    "Show6Layers (Panel)", SHOW6LAYER_LJZ()
End

#pragma DefaultTab={3,20,4} // Set default tab width


// =========================================================================
//  PART 1: 物理模型与拟合函数 (Pseudo-Voigt, HWHM based)
// =========================================================================

// HWHM 有效宽度：把仪器分辨率(半高宽)作为下限，用平滑方式合并
Function LJZ_HWHM_eff(wfree, resH)
    Variable wfree, resH
    // 有效宽度 s = sqrt(resH^2 + wfree^2) ，可导且始终 >= resH
    return sqrt(resH*resH + wfree*wfree)
End

// ============================================================================
//  Peak area for pseudo-Voigt in "Height + HWHM" parameterization
//  PV = eta * Lorentz(H,s) + (1-eta) * Gaussian(H,s)
//  Lorentz: H*s^2 / ((x-x0)^2 + s^2)   => area = H*pi*s
//  Gaussian: H*exp(-ln(2)*((x-x0)/s)^2) => area = H*s*sqrt(pi/ln(2))
//  s uses effective HWHM = LJZ_HWHM_eff(wfree, resH)
// ============================================================================
Function LJZ_PVArea_FromCoef(H, wfree, eta, resH)
    Variable H, wfree, eta, resH

    if (numtype(H) != 0)
        return NaN
    endif
    if (numtype(wfree) != 0)
        return NaN
    endif
    if (numtype(eta) != 0)
        eta = 0.8
    endif
    if (numtype(resH) != 0)
        resH = 0
    endif

    if (H <= 0)
        return 0
    endif

    if (eta < 0)
        eta = 0
    endif
    if (eta > 1)
        eta = 1
    endif

    Variable wloc = wfree
    if (wloc < 0)
        wloc = 0
    endif

    Variable rloc = resH
    if (rloc < 0)
        rloc = 0
    endif

    Variable sEff = LJZ_HWHM_eff(wloc, rloc)
    if (numtype(sEff) != 0 || sEff <= 0)
        return NaN
    endif

    Variable areaLor = H * pi * sEff
    Variable areaGau = H * sEff * sqrt(pi / ln(2))

    return eta * areaLor + (1 - eta) * areaGau
End

// 高度参数化的 Lorentz：H · s^2 / ((x-x0)^2 + s^2)
Function LJZ_LorH(H, x, x0, s)
    Variable H, x, x0, s
    if (s <= 0)
        s = 1e-12
    endif
    return H * (s*s) / ( (x - x0)*(x - x0) + s*s )
End

// 高度参数化的 Gaussian（以 HWHM=s）：H · exp( -ln(2) · ((x-x0)/s)^2 )
Function LJZ_GauH(H, x, x0, s)
    Variable H, x, x0, s
    if (s <= 0)
        s = 1e-12
    endif
    return H * exp( -ln(2) * ((x - x0)/s)*((x - x0)/s) )
End

// 伪 Voigt：eta*Lor + (1-eta)*Gauss
Function LJZ_PseudoVoigtH(H, x, x0, s, eta)
    Variable H, x, x0, s, eta
    if (eta < 0)
        eta = 0
    elseif (eta > 1)
        eta = 1
    endif
    return eta * LJZ_LorH(H, x, x0, s) + (1 - eta) * LJZ_GauH(H, x, x0, s)
End


Function one_pv_ljz(w, x) : FitFunc
    Wave w
    Variable x

    Variable c0   = w[0]
    Variable c1   = w[1]
    Variable c2   = w[2]
    Variable H1   = w[3]
    Variable x1   = w[4]
    Variable w1f  = max(1e-4, abs(w[5]))
    Variable eta1 = min(1, max(0, w[6]))
    Variable resH = max(1e-4, abs(w[7]))

    Variable s1 = LJZ_HWHM_eff(w1f, resH)
    Variable bg = c0 + c1*x + c2*x*x
    return bg + LJZ_PseudoVoigtH(H1, x, x1, s1, eta1)
End

Function two_pv_ljz(w, x) : FitFunc
    Wave w
    Variable x

    Variable c0   = w[0]
    Variable c1   = w[1]
    Variable c2   = w[2]

    Variable Ha   = w[3]
    Variable xa   = w[4]
    Variable wa   = max(1e-4, abs(w[5]))
    Variable etaa = min(1, max(0, w[6]))

    Variable Hb   = w[7]
    Variable xb   = w[8]
    Variable wb   = max(1e-4, abs(w[9]))
    Variable etab = min(1, max(0, w[10]))

    Variable resH = max(1e-4, abs(w[11]))

    Variable H1, x1, w1f, eta1
    Variable H2, x2, w2f, eta2

    if (xa <= xb)
        H1 = Ha; x1 = xa; w1f = wa; eta1 = etaa
        H2 = Hb; x2 = xb; w2f = wb; eta2 = etab
    else
        H1 = Hb; x1 = xb; w1f = wb; eta1 = etab
        H2 = Ha; x2 = xa; w2f = wa; eta2 = etaa
    endif

    Variable s1 = LJZ_HWHM_eff(w1f, resH)
    Variable s2 = LJZ_HWHM_eff(w2f, resH)

    Variable bg = c0 + c1*x + c2*x*x
    return bg + LJZ_PseudoVoigtH(H1, x, x1, s1, eta1) + LJZ_PseudoVoigtH(H2, x, x2, s2, eta2)
End

// =========================================================================
//  PART 2: 辅助工具函数 (Fix syntax errors)
// =========================================================================

// [Fix] 移除了原代码中错误的方括号 []
Function/S LJZ_HoldMask(n[, hdx1, hdx2, hdx3, hdx4, hdx5])
    Variable n, hdx1, hdx2, hdx3, hdx4, hdx5
    if (n <= 0)
        return ""
    endif

    Make/FREE/N=(n) flag = 0
    Variable t

    // 检查 hdx1
    if (!ParamIsDefault(hdx1) && numtype(hdx1)==0)
        t = round(hdx1)
        if (t >= 0 && t < n) 
            flag[t] = 1 
        endif
    endif

    // 检查 hdx2
    if (!ParamIsDefault(hdx2) && numtype(hdx2)==0)
        t = round(hdx2)
        if (t >= 0 && t < n) 
            flag[t] = 1 
        endif
    endif

    // 检查 hdx3
    if (!ParamIsDefault(hdx3) && numtype(hdx3)==0)
        t = round(hdx3)
        if (t >= 0 && t < n) 
            flag[t] = 1 
        endif
    endif

    // 检查 hdx4
    if (!ParamIsDefault(hdx4) && numtype(hdx4)==0)
        t = round(hdx4)
        if (t >= 0 && t < n) 
            flag[t] = 1 
        endif
    endif

    // 检查 hdx5
    if (!ParamIsDefault(hdx5) && numtype(hdx5)==0)
        t = round(hdx5)
        if (t >= 0 && t < n) 
            flag[t] = 1 
        endif
    endif

    String s = ""
    Variable i
    for (i=0; i<n; i+=1)
        if (flag[i] != 0)
            s += "1"
        else
            s += "0"
        endif
    endfor
    return s
End

Function LJZ_BG_EdgeAvg(tpt)
    Wave tpt
    Variable n = numpnts(tpt)
    Variable nEdge = max(1, min(5, n/4))
    Variable sL=0, sR=0, i
    for (i=0; i<nEdge; i+=1)
        sL += tpt[i]
        sR += tpt[n-1-i]
    endfor
    return (sL + sR) / (2*nEdge)
End

Function LJZ_WfreeFromEff(eff, Res)
    Variable eff, Res
    Variable e2 = eff*eff - Res*Res
    if (e2 <= 0)
        return 0
    endif
    return sqrt(e2)
End

Function LJZ_Clamp(x, lo, hi)
    Variable x, lo, hi
    if (lo > hi)
        Variable tmp = lo; lo = hi; hi = tmp
    endif
    if (numtype(x) != 0)
        return (lo + hi)/2
    endif
    if (x < lo)
        return lo
    endif
    if (x > hi)
        return hi
    endif
    return x
End


Function LJZ_EnsureMDCFitDF()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:MDCFit

    SVAR/Z s0 = root:ARPES_LJZ:MDCFit:MDCWaveSel
    if (!SVAR_Exists(s0))
        String/G root:ARPES_LJZ:MDCFit:MDCWaveSel = ""
    endif
    SVAR/Z s1 = root:ARPES_LJZ:MDCFit:RunDF
    if (!SVAR_Exists(s1))
        String/G root:ARPES_LJZ:MDCFit:RunDF = ""
    endif
    SVAR/Z s2 = root:ARPES_LJZ:MDCFit:gBaseName
    if (!SVAR_Exists(s2))
        String/G root:ARPES_LJZ:MDCFit:gBaseName = ""
    endif
    return 0
End

// =========================================================================
//  PART 3: UI 面板与交互逻辑
// =========================================================================

// 启动入口
Proc MDCFit_LJZ()
    LJZ_EnsureMDCFitDF()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O/S root:ARPES_LJZ:MDCFit

    Variable/G Kpeak1 = NaN, Kpeak2 = NaN, Eindex = 28
    Variable/G Exe = 32, Res = 0.01, bdta = 50, fdta = 50
    Variable/G kvary = 50, wi1 = 1, wi2 = 1, uz = 0, ddta = 10, WidRatio = 200, Fitmode = 1

    Variable/G SmEnable   = 1
    Variable/G SmMethod   = 1
    Variable/G SmN        = 11
    Variable/G SmN2       = 7
    Variable/G SmS        = 4
    Variable/G SmCutoff   = 0.18
    String/G   RunDF      = ""
    Variable/G Run_jStart = 0
    Variable/G Run_jEnd   = 0

    LJZ_RebuildWaveLB("root:")

    SetDataFolder root:
    DoWindow/F MDCFit_LJZ_P
    if (V_flag == 0)
        MDCFit_LJZ_P()
    endif
End

// 递归列出 3D Waves
Function/S LJZ_List3DWavesUnder(path)
    String path
    path = RemoveEnding(path, ":") + ":"
    String out = ""
    Variable i, n

    n = CountObjects(path, 1)
    for (i=0; i<n; i+=1)
        String nm = GetIndexedObjName(path, 1, i)
        Wave/Z w = $(path + nm)
        if (WaveExists(w) && WaveDims(w) == 3 && DimSize(w,0)>0 && DimSize(w,1)>0 && DimSize(w,2)>0)
            out = AddListItem(path + nm, out, ";", Inf)
        endif
    endfor

    n = CountObjects(path, 4)
    for (i=0; i<n; i+=1)
        String sub = GetIndexedObjName(path, 4, i)
        String subList = LJZ_List3DWavesUnder(path + sub + ":")
        Variable j, m = ItemsInList(subList, ";")
        for (j=0; j<m; j+=1)
            String item = StringFromList(j, subList, ";")
            if (strlen(item) > 0)
                out = AddListItem(item, out, ";", Inf)
            endif
        endfor
    endfor
    return out
End

Function LJZ_RebuildWaveLB(basePath)
    String basePath
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:MDCFit
    String s = LJZ_List3DWavesUnder(basePath)
    Variable n = ItemsInList(s, ";")
    Variable Nn = (n > 0) ? n : 1

    Make/O/T/N=(Nn) root:ARPES_LJZ:MDCFit:LB_Items
    Make/O/N=(Nn)   root:ARPES_LJZ:MDCFit:LB_Sel
    Wave/T wItems = root:ARPES_LJZ:MDCFit:LB_Items
    Wave   wSel   = root:ARPES_LJZ:MDCFit:LB_Sel
    wSel = 0
    if (n == 0)
        wItems[0] = "None"
    else
        Variable i
        for (i=0; i<n; i+=1)
            wItems[i] = StringFromList(i, s, ";")
        endfor
    endif
End

// UI 窗口定义
Window MDCFit_LJZ_P() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(420,102,1095.6,619.8) as "2026MDCFIT_LJZ"
	ModifyPanel frameStyle=1
	ShowTools/A
	TitleBox tb1,pos={12.00,6.00},size={46.20,18.00},title="Wave(s):",frame=0
	ListBox lbWave,pos={12.00,27.00},size={480.00,159.00},proc=MDCLB_WaveProc_LJZ
	ListBox lbWave,listWave=root:ARPES_LJZ:MDCFit:LB_Items
	ListBox lbWave,selWave=root:ARPES_LJZ:MDCFit:LB_Sel,row= 8,mode= 1,selRow= 8
	ListBox lbWave,userColumnResize= 1
	PopupMenu pmUZ,pos={510.00,27.00},size={89.40,20.40},proc=MDCPF_UZPopProc_LJZ,title="Z Label:"
	PopupMenu pmUZ,mode=1,popvalue="Delay",value= #"\"Delay;Temperature;Fluence\""
	Button btnRefreshLB,pos={510.00,54.00},size={126.00,99.00},proc=MDCPF_RefreshWaveList_LJZ,title="Refresh Wave List"
	PopupMenu pmMode,pos={510.00,162.00},size={125.40,20.40},proc=MDCPF_choosemode_LJZ,title="Fit mode:"
	PopupMenu pmMode,mode=1,popvalue="MergeLock",value= #"\"MergeLock;Adaptive2to1;RobustAdaptive;PeakTracking;StrictRobust\""
	SetVariable svK1,pos={12.00,198.00},size={300.00,19.80},title="Kpeak1"
	SetVariable svK1,limits={-inf,inf,0},value= root:ARPES_LJZ:MDCFit:Kpeak1
	SetVariable svK2,pos={330.00,198.00},size={300.00,19.80},title="Kpeak2"
	SetVariable svK2,limits={-inf,inf,0},value= root:ARPES_LJZ:MDCFit:Kpeak2
	SetVariable svE1,pos={12.00,228.00},size={300.00,19.80},title="Eindex (start)"
	SetVariable svE1,value= root:ARPES_LJZ:MDCFit:Eindex
	SetVariable svE2,pos={330.00,228.00},size={300.00,19.80},title="Exe (end)"
	SetVariable svE2,limits={0,inf,1},value= root:ARPES_LJZ:MDCFit:Exe
	SetVariable svRes,pos={12.00,255.00},size={300.00,19.80},title="Res (>=0)"
	SetVariable svRes,limits={0,inf,0.01},value= root:ARPES_LJZ:MDCFit:Res
	SetVariable svFd,pos={330.00,255.00},size={300.00,19.80},title="forward delta"
	SetVariable svFd,limits={0,inf,1},value= root:ARPES_LJZ:MDCFit:fdta
	SetVariable svBd,pos={12.00,282.00},size={300.00,19.80},title="back delta"
	SetVariable svBd,limits={0,inf,1},value= root:ARPES_LJZ:MDCFit:bdta
	SetVariable svKv,pos={330.00,282.00},size={300.00,19.80},title="kvary"
	SetVariable svKv,limits={-inf,inf,0.1},value= root:ARPES_LJZ:MDCFit:kvary
	SetVariable svW1,pos={12.00,312.00},size={300.00,19.80},title="width1"
	SetVariable svW1,limits={-inf,inf,0.1},value= root:ARPES_LJZ:MDCFit:wi1
	SetVariable svW2,pos={330.00,312.00},size={300.00,19.80},title="width2"
	SetVariable svW2,limits={-inf,inf,0.1},value= root:ARPES_LJZ:MDCFit:wi2
	SetVariable ddta,pos={12.00,339.00},size={300.00,19.80},title="expand delta"
	SetVariable ddta,limits={-inf,inf,0.1},value= root:ARPES_LJZ:MDCFit:ddta
	SetVariable WidRatio,pos={330.00,339.00},size={300.00,19.80},title="WidthRatio"
	SetVariable WidRatio,limits={-inf,inf,0.1},value= root:ARPES_LJZ:MDCFit:WidRatio
	Button btnAuto,pos={12.00,372.00},size={99.00,30.00},proc=MDCPF_AutoFill_LJZ,title="Auto-Fill"
	Button btnShow,pos={126.00,372.00},size={99.00,30.00},proc=MDCPF_ShowMDC_LJZ,title="Show MDC"
	Button btnFit,pos={240.00,372.00},size={99.00,30.00},proc=MDCPF_RunFit_LJZ,title="Run Fit"
	Button btnHelp,pos={363.00,369.60},size={99.00,30.00},proc=MDCPF_HelpButton_LJZ,title="Help"
	Button btnClose,pos={498.00,369.00},size={99.00,30.00},proc=MDCPF_Close_LJZ,title="Close"
	SetVariable mdcsv_bn,pos={402.60,453.00},size={189.60,19.80},title="BaseName"
	SetVariable mdcsv_bn,value= root:ARPES_LJZ:MDCFit:gBaseName
	CheckBox cbSm,pos={12.00,423.00},size={54.60,18.00},proc=MDCPF_SmCheckProc_LJZ,title="Smooth"
	CheckBox cbSm,variable= root:ARPES_LJZ:MDCFit:SmEnable
	SetVariable svSmN,pos={171.00,415.80},size={180.00,19.80},proc=MDCPF_SmCtl_LJZ,title="N1"
	SetVariable svSmN,limits={3,999,2},value= root:ARPES_LJZ:MDCFit:SmN
	SetVariable svSmS,pos={171.00,462.00},size={180.00,19.80},proc=MDCPF_SmCtl_LJZ,title="S"
	SetVariable svSmS,limits={1,20,1},value= root:ARPES_LJZ:MDCFit:SmS
	PopupMenu pmSm,pos={12.00,475.80},size={88.20,20.40},proc=MDCPF_SmPopProc_LJZ,title="Method:"
	PopupMenu pmSm,mode=4,popvalue="BLPF",value= #"\"None;Smooth;SmoothS;BLPF\""
	SetVariable svSmN2,pos={171.00,439.80},size={180.00,19.80},proc=MDCPF_SmCtl_LJZ,title="N2"
	SetVariable svSmN2,limits={0,999,2},value= root:ARPES_LJZ:MDCFit:SmN2
	SetVariable svCut,pos={204.00,483.60},size={147.00,19.80},proc=MDCPF_SmCtl_LJZ,title="cutoff"
	SetVariable svCut,limits={0.001,0.499,0.01},value= root:ARPES_LJZ:MDCFit:SmCutoff
EndMacro

// 控件回调函数群
Function MDCLB_WaveProc_LJZ(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if (lba.eventCode == 4 && lba.row >= 0)
        Wave/T wList = lba.listWave
        Wave/Z  sel  = lba.selWave
        LJZ_EnsureMDCFitDF()
        SVAR/Z sWave = root:ARPES_LJZ:MDCFit:MDCWaveSel
        if (!SVAR_Exists(sWave))
            return 0
        endif
        String pick = wList[lba.row]
        if (StringMatch(pick, "None"))
            sWave = ""
        else
            sWave = pick
        endif
        if (WaveExists(sel))
            sel = 0
            sel[lba.row] = 1
        endif
    endif
    return 0
End

Function MDCPF_RefreshWaveList_LJZ(ctrlName) : ButtonControl
    String ctrlName
    LJZ_RebuildWaveLB("root:")
    return 0
End

Function MDCPF_UZPopProc_LJZ(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName; Variable popNum; String popStr
    NVAR uz = root:ARPES_LJZ:MDCFit:uz
    if (StringMatch(popStr, "Delay"))
        uz = 0
    elseif (StringMatch(popStr, "Temperature"))
        uz = 1
    else
        uz = 2
    endif
End

Function MDCPF_AutoFill_LJZ(ctrlName) : ButtonControl
    String ctrlName
    SVAR/Z sWave = root:ARPES_LJZ:MDCFit:MDCWaveSel
    if (!SVAR_Exists(sWave) || strlen(sWave)==0)
        DoAlert 0, "请先选择一个 3D 波形。"
        return -1
    endif
    Wave/Z w = $sWave
    if (!WaveExists(w) || WaveDims(w) < 3)
        DoAlert 0, "选择的波形不是 3D。"
        return -1
    endif
    NVAR Kpeak1 = root:ARPES_LJZ:MDCFit:Kpeak1
    NVAR Kpeak2 = root:ARPES_LJZ:MDCFit:Kpeak2
    NVAR Eindex = root:ARPES_LJZ:MDCFit:Eindex
    NVAR Exe    = root:ARPES_LJZ:MDCFit:Exe
    Eindex = 0
    Exe    = DimSize(w, 0) - 1
    Variable t0 = DimOffset(w, 1)
    Variable dt = DimDelta(w, 1)
    Variable nt = DimSize(w, 1)
    Kpeak1 = t0 + dt * round(nt*0.30)
    Kpeak2 = t0 + dt * round(nt*0.70)
    return 0
End

Function MDCPF_choosemode_LJZ(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName; Variable popNum; String popStr
    LJZ_EnsureMDCFitDF()
    NVAR/Z FitMode = root:ARPES_LJZ:MDCFit:Fitmode
    if (!NVAR_Exists(FitMode))
        Variable/G root:ARPES_LJZ:MDCFit:Fitmode = popNum
        NVAR FitMode = root:ARPES_LJZ:MDCFit:Fitmode
    else
        FitMode = popNum
    endif
    return 0
End



Function MDCPF_Close_LJZ(ctrlName) : ButtonControl
    String ctrlName
    DoWindow/K MDCFIT_LJZ2026
    return 0
End

// =========================================================================
//  PART 4: 数据处理与平滑 (Show MDC Logic)
// =========================================================================

Function/S LJZ_MakeRunDFName(w, jStart, jEnd, tag)
    Wave w; Variable jStart, jEnd; String tag
    String nm = NameOfWave(w)
    return "root:ARPES_LJZ:MDCFit:" + nm + "_RUN_" + tag + "_f" + Num2Str(jStart) + "2" + Num2Str(jEnd) + ":"
End

Function LJZ_ApplySmoothing_All(runDF)
    String runDF
    NVAR SmEnable = root:ARPES_LJZ:MDCFit:SmEnable
    NVAR SmMethod = root:ARPES_LJZ:MDCFit:SmMethod
    NVAR SmN      = root:ARPES_LJZ:MDCFit:SmN
    NVAR SmN2     = root:ARPES_LJZ:MDCFit:SmN2
    NVAR SmS      = root:ARPES_LJZ:MDCFit:SmS
    NVAR SmCutoff = root:ARPES_LJZ:MDCFit:SmCutoff

    Variable k = 0
    do
        Wave/Z raw = $(runDF + "mdc_raw_" + Num2Str(k))
        if (!WaveExists(raw))
            break
        endif
        Duplicate/O raw, $(runDF + "mdc_show_" + Num2Str(k))
        Wave sh = $(runDF + "mdc_show_" + Num2Str(k))
        if (SmEnable)
            Variable n1 = max(3, round(SmN))
            Variable n2 = max(3, round(SmN2))
            if (SmMethod == 1)
                Smooth n1, sh
                if (SmN2 >= 3)
                    Smooth n2, sh
                endif
            elseif (SmMethod == 2)
                Variable sg = (SmS <= 2) ? 2 : 4
                Smooth/S=(sg) n1, sh
                if (SmN2 >= 3)
                    Smooth/S=(sg) n2, sh
                endif
            elseif (SmMethod == 3)
                Variable fc = min(max(SmCutoff, 0.001), 0.499)
                Smooth/BLPF fc, sh
            endif
        endif
        k += 1
    while(1)
End

// =========================================================================
//  修复后的 Show MDC：先关闭旧窗口，防止堆积
// =========================================================================
Function MDCPF_ShowMDC_LJZ(ctrlName) : ButtonControl
    String ctrlName
    LJZ_EnsureMDCFitDF()
    SVAR/Z sWave = root:ARPES_LJZ:MDCFit:MDCWaveSel
    if (!SVAR_Exists(sWave) || strlen(sWave)==0)
        DoAlert 0, "请先选择一个 3D 波形。"
        return -1
    endif
    Wave/Z w = $sWave
    if (!WaveExists(w) || WaveDims(w) < 3)
        DoAlert 0, "无效的 3D 波形: " + sWave
        return -1
    endif

    NVAR Eindex = root:ARPES_LJZ:MDCFit:Eindex
    NVAR Exe    = root:ARPES_LJZ:MDCFit:Exe
    NVAR kvary  = root:ARPES_LJZ:MDCFit:kvary

    Variable nx = DimSize(w, 0)
    Variable ny = DimSize(w, 1)
    Variable nt = DimSize(w, 2)
    Variable y0 = DimOffset(w, 1)
    Variable dy = DimDelta(w, 1)

    Variable jStart = max(0, min(nx-1, min(Eindex, Exe)))
    Variable jEnd   = max(0, min(nx-1, max(Eindex, Exe)))
    Variable nAvg   = jEnd - jStart + 1

    String runDF = LJZ_MakeRunDFName(w, jStart, jEnd, "MDC")
    NewDataFolder/O $(RemoveEnding(runDF, ":"))
    SetDataFolder $(RemoveEnding(runDF, ":"))

    Variable k, j
    for (k=0; k<nt; k+=1)
        Make/O/N=(ny) $("mdc_raw_" + Num2Str(k)) = 0
        Wave m = $("mdc_raw_" + Num2Str(k))
        SetScale/P x, y0, dy, m
        for (j=jStart; j<=jEnd; j+=1)
            m += w[j][p][k]
        endfor
        m /= nAvg
    endfor

    SetDataFolder root:
    LJZ_ApplySmoothing_All(runDF)

    SVAR bn = root:ARPES_LJZ:MDCFit:gBaseName
    String bnTag = bn
    if (strlen(bnTag) == 0)
        bnTag = NameOfWave(w)
    endif
    
    // [修改开始] 固定窗口名，并在创建前尝试关闭旧窗口
    String wNameBase = "MDC_Overlapping_" + CleanupName(bnTag, 0)
    KillWindow/Z $wNameBase 
    String wOlap = wNameBase
    // [修改结束]

    SetDataFolder $(RemoveEnding(runDF, ":"))
    for (k=0; k<nt; k+=1)
        Wave/Z sh = $("mdc_show_" + Num2Str(k))
        if (!WaveExists(sh))
            break
        endif
        if (k==0)
            Display/N=$wOlap sh
            Label left, "Intensity (a.u.)"
            Label bottom, "Degree"
        else
            AppendToGraph sh
            ModifyGraph offset($NameOfWave(sh)) = {0, k*kvary}
        endif
    endfor
    SetDataFolder root:

    String/G root:ARPES_LJZ:MDCFit:RunDF = runDF
    Variable/G root:ARPES_LJZ:MDCFit:Run_jStart = jStart
    Variable/G root:ARPES_LJZ:MDCFit:Run_jEnd   = jEnd
    Variable/G root:ARPES_LJZ:MDCFit:Run_t0 = DimOffset(w, 2)
    Variable/G root:ARPES_LJZ:MDCFit:Run_dt = DimDelta(w, 2)
    return 0
End

Function MDCPF_SmCtl_LJZ(ctrlName, varNum, varStr, varName) : SetVariableControl
    String ctrlName; Variable varNum; String varStr, varName
    SVAR runDF = root:ARPES_LJZ:MDCFit:RunDF
    if (strlen(runDF) == 0)
        return 0
    endif
    if (StringMatch(ctrlName, "cbSm"))
        NVAR SmEnable = root:ARPES_LJZ:MDCFit:SmEnable
        SmEnable = (varNum != 0)
    endif
    if (StringMatch(ctrlName, "pmSm"))
        NVAR SmMethod = root:ARPES_LJZ:MDCFit:SmMethod
        if (StringMatch(varStr, "None"))
            SmMethod = 0
        elseif (StringMatch(varStr, "Smooth"))
            SmMethod = 1
        elseif (StringMatch(varStr, "SmoothS"))
            SmMethod = 2
        else
            SmMethod = 3
        endif
    endif
    LJZ_ApplySmoothing_All(runDF)
    return 0
End

Function MDCPF_SmCheckProc_LJZ(cb) : CheckBoxControl
    STRUCT WMCheckboxAction &cb
    if (cb.eventCode != 2)
        return 0
    endif
    SVAR runDF = root:ARPES_LJZ:MDCFit:RunDF
    if (strlen(runDF) == 0)
        return 0
    endif
    NVAR SmEnable = root:ARPES_LJZ:MDCFit:SmEnable
    SmEnable = (cb.checked != 0)
    LJZ_ApplySmoothing_All(runDF)
    return 0
End

Function MDCPF_SmPopProc_LJZ(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName, popStr; Variable popNum
    MDCPF_SmCtl_LJZ(ctrlName, popNum, popStr, "")
    return 0
End

// =========================================================================
//  PART 5: 拟合入口 (Run Fit)
// =========================================================================

Function MDCPF_RunFit_LJZ(ctrlName) : ButtonControl
    String ctrlName
    LJZ_EnsureMDCFitDF()

    SVAR runDF = root:ARPES_LJZ:MDCFit:RunDF
    if (strlen(runDF) == 0)
        DoAlert 0, "请先点击 Show MDC 生成堆叠 MDC。"
        return -1
    endif

    NVAR Kpeak1 = root:ARPES_LJZ:MDCFit:Kpeak1
    NVAR Kpeak2 = root:ARPES_LJZ:MDCFit:Kpeak2
    NVAR Res    = root:ARPES_LJZ:MDCFit:Res
    NVAR bdta   = root:ARPES_LJZ:MDCFit:bdta
    NVAR fdta   = root:ARPES_LJZ:MDCFit:fdta
    NVAR kvary  = root:ARPES_LJZ:MDCFit:kvary
    NVAR wi1    = root:ARPES_LJZ:MDCFit:wi1
    NVAR wi2    = root:ARPES_LJZ:MDCFit:wi2
    NVAR uz     = root:ARPES_LJZ:MDCFit:uz
    NVAR ddta   = root:ARPES_LJZ:MDCFit:ddta
    NVAR WidRatio = root:ARPES_LJZ:MDCFit:WidRatio
    NVAR FitMode  = root:ARPES_LJZ:MDCFit:Fitmode

    if (FitMode == 1)
        MDC_NdSb_LJZ_MergeLock_FromShow(runDF, Kpeak1, Kpeak2, Res, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio)
    elseif (FitMode == 2)
        MDC_NdSb_LJZ_A21_FromShow(runDF, Kpeak1, Kpeak2, Res, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio)
    elseif (FitMode == 3)
        // [修复] 此函数之前缺失，现在已整合在 PART 6
        MDC_NdSb_LJZ_RA_BGFree_UCenter(runDF, Kpeak1, Kpeak2, Res, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio)
    elseif (FitMode == 4)
//        MDC_NdSb_LJZ_TPH_TrajectoryLock(runDF, Kpeak1, Kpeak2, Res, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio)
//        MDC_NdSb_LJZ_PR2S_UC(runDF, Kpeak1, Kpeak2, Res, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio)
	   MDC_NdSb_LJZ_PT_UC(runDF, Kpeak1, Kpeak2, Res, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio)
    elseif (FitMode == 5)
    		MDC_NdSb_LJZ_PTF_RobustFit_UC(runDF, Kpeak1, Kpeak2, Res, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio)
    else
        DoAlert 0, "未知 FitMode = " + Num2Str(FitMode)
        return -1
    endif
    return 0
End

// =========================================================================
//  PART 6: 核心拟合引擎 (DTS) + Robust Gate Log (per-frame GateCode/GateMsg)
//   GateCode: 2=2P_OK, 1=1P_OK, 0=FAIL/NaN
// =========================================================================

// =========================================================================
//  PART 6: 核心拟合引擎 (DTS) + Robust Gate Log (per-frame GateCode/GateMsg)
//   GateCode: 2=2P_OK, 1=1P_OK, 0=FAIL/NaN
//   修改点：一旦进入单峰(1P)流程且 1P 失败/无法拟合，则立刻退出整个拟合流程（停止后续帧）
// =========================================================================

Function MDC_NdSb_LJZ_A21_FromShow(runDF, Kpeak1, Kpeak2, Res, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio)
    String runDF
    Variable Kpeak1, Kpeak2, Res, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio

    String df0
    df0 = GetDataFolder(1)

    if (strlen(runDF) == 0)
        DoAlert 0, "runDF 为空"
        SetDataFolder df0
        return -1
    endif

    LJZ_EnsureMDCFitDF()

    String/G root:ARPES_LJZ:MDCFit:gLastGateReason = ""
    SVAR gGateReason = root:ARPES_LJZ:MDCFit:gLastGateReason
    gGateReason = ""

    runDF = RemoveEnding(runDF, ":") + ":"

    Variable nt
    nt = 0

    do
        Wave/Z wTest = $(runDF + "mdc_show_" + Num2Str(nt))
        if (!WaveExists(wTest))
            break
        endif
        nt += 1
    while (1)

    if (nt <= 0)
        DoAlert 0, "runDF 下找不到 mdc_show_0"
        SetDataFolder df0
        return -1
    endif

    Wave/Z w0 = $(runDF + "mdc_show_0")
    if (!WaveExists(w0))
        DoAlert 0, "mdc_show_0 不存在"
        SetDataFolder df0
        return -1
    endif

    Variable ny
    Variable y0
    Variable dy
    ny = numpnts(w0)
    y0 = DimOffset(w0, 0)
    dy = DimDelta(w0, 0)

    if (ny < 7)
        DoAlert 0, "点数太少"
        SetDataFolder df0
        return -1
    endif
    if (numtype(dy) != 0 || dy == 0)
        DoAlert 0, "DimDelta 非法"
        SetDataFolder df0
        return -1
    endif

    Variable t0
    Variable dt
    t0 = 0
    dt = 1

    NVAR/Z g_t0 = root:ARPES_LJZ:MDCFit:Run_t0
    NVAR/Z g_dt = root:ARPES_LJZ:MDCFit:Run_dt

    if (NVAR_Exists(g_t0))
        if (numtype(g_t0) == 0)
            t0 = g_t0
        endif
    endif
    if (NVAR_Exists(g_dt))
        if (numtype(g_dt) == 0)
            if (g_dt != 0)
                dt = g_dt
            endif
        endif
    endif

    String fitDF
    fitDF = runDF + "FIT_A21:"
    NewDataFolder/O $(RemoveEnding(fitDF, ":"))
    SetDataFolder $(RemoveEnding(fitDF, ":"))

    Make/O/N=12 coef_wave
    Make/O/N=8  cfw
    coef_wave = 0
    cfw = 0

    Make/O/N=(nt) Peak1K
    Make/O/N=(nt) Peak2K
    Make/O/N=(nt) Peak3K
    Make/O/N=(nt) SigmaP1K
    Make/O/N=(nt) SigmaP2K
    Make/O/N=(nt) SigmaP3K

    Peak1K = NaN
    Peak2K = NaN
    Peak3K = NaN
    SigmaP1K = NaN
    SigmaP2K = NaN
    SigmaP3K = NaN

    SetScale/P x, t0, dt, Peak1K
    SetScale/P x, t0, dt, Peak2K
    SetScale/P x, t0, dt, Peak3K
    SetScale/P x, t0, dt, SigmaP1K
    SetScale/P x, t0, dt, SigmaP2K
    SetScale/P x, t0, dt, SigmaP3K

    // -------------------------
    // Robust per-frame gate logs
    // -------------------------
    Make/T/O/N=(nt) GateMsg
    Make/O/N=(nt) GateCode
    GateMsg = ""
    GateCode = NaN
    SetScale/P x, t0, dt, GateCode

    SVAR bn = root:ARPES_LJZ:MDCFit:gBaseName
    String bnTag
    bnTag = bn
    if (strlen(bnTag) == 0)
        bnTag = runDF
    endif

    String wOlap
    String wTLF
    String wLog

    wOlap = "MDC_Olap_A21_" + CleanupName(bnTag, 0)
    wTLF  = "MDC_Traj_A21_" + CleanupName(bnTag, 0)
    wLog  = "MDC_GateLog_A21_" + CleanupName(bnTag, 0)

    KillWindow/Z $wOlap
    KillWindow/Z $wTLF
    KillWindow/Z $wLog

    Variable lastGood1
    Variable lastGood2
    Variable haveGood1
    Variable haveGood2

    lastGood1 = Kpeak1
    lastGood2 = Kpeak2
    haveGood1 = 0
    haveGood2 = 0

    Variable w1f0_global
    Variable w2f0_global
    w1f0_global = sqrt(max(0, max(wi1, Res)^2 - Res^2))
    w2f0_global = sqrt(max(0, max(wi2, Res)^2 - Res^2))

    Variable lastW1
    Variable lastW2
    Variable haveGoodW
    lastW1 = w1f0_global
    lastW2 = w2f0_global
    haveGoodW = 0

    // 状态锁：0=尝试双峰, 1=强制单峰
    Variable forceSingleMode
    forceSingleMode = 0

    // -------------------------
    // ABORT flags: stop all fitting if 1P fails / cannot fit
    // -------------------------
    Variable abortAll
    Variable abortAt
    String abortMsg
    abortAll = 0
    abortAt  = -1
    abortMsg = ""

    Variable k
    for (k = 0; k < nt; k += 1)

        Wave/Z mdc_wave = $(runDF + "mdc_show_" + Num2Str(k))
        if (!WaveExists(mdc_wave))
            GateCode[k] = 0
            GateMsg[k] = "NO_WAVE;"
            continue
        endif

        Duplicate/O mdc_wave, $("layer_show_" + Num2Str(k))

        Variable didDouble
        didDouble = 0

        // -------------------------
        // Try 2-peak if not forced
        // -------------------------
        if (forceSingleMode == 0)

            Variable x1seed
            Variable x2seed

            x1seed = Kpeak1
            if (haveGood1)
                x1seed = lastGood1
            endif

            x2seed = Kpeak2
            if (haveGood2)
                x2seed = lastGood2
            endif

            Variable idx1
            Variable idx2
            idx1 = round((x1seed - y0) / dy)
            idx2 = round((x2seed - y0) / dy)

            idx1 = max(0, min(ny - 1, idx1))
            idx2 = max(0, min(ny - 1, idx2))

            Variable tmpIdx
            if (idx2 < idx1)
                tmpIdx = idx1
                idx1 = idx2
                idx2 = tmpIdx
            endif

            Variable startIdx
            Variable endIdx
            Variable npts
            startIdx = max(0, idx1 - fdta)
            endIdx = min(ny - 1, idx2 + bdta)
            npts = endIdx - startIdx + 1

            if (npts >= 7)

                Make/O/N=(npts) tpt
                tpt = mdc_wave[startIdx + p]
                SetScale/P x, y0 + startIdx * dy, dy, tpt

                Variable x1_0
                Variable x2_0
                Variable H1_0
                Variable H2_0
                Variable w1_init
                Variable w2_init

                x1_0 = y0 + idx1 * dy
                x2_0 = y0 + idx2 * dy
                H1_0 = mdc_wave[idx1]
                H2_0 = mdc_wave[idx2]

                w1_init = w1f0_global
                if (haveGoodW)
                    w1_init = lastW1
                endif

                w2_init = w2f0_global
                if (haveGoodW)
                    w2_init = lastW2
                endif

                coef_wave = 0
                coef_wave[3]  = H1_0
                coef_wave[4]  = LJZ_Clamp(x1_0, y0 + startIdx * dy, y0 + endIdx * dy)
                coef_wave[5]  = w1_init
                coef_wave[6]  = 0.8
                coef_wave[7]  = H2_0
                coef_wave[8]  = LJZ_Clamp(x2_0, y0 + startIdx * dy, y0 + endIdx * dy)
                coef_wave[9]  = w2_init
                coef_wave[10] = 0.8
                coef_wave[11] = max(Res, 1e-6)

                String hold2
                hold2 = LJZ_HoldMask(12, hdx1=6, hdx2=10, hdx3=11)

                Make/FREE/N=12 coef0
                coef0 = coef_wave[p]

                KillWaves/Z W_sigma
                Duplicate/O tpt, $("fit_layer_" + Num2Str(k))
                FuncFit/H=hold2/Q two_pv_ljz, coef_wave, tpt /D=$("fit_layer_" + Num2Str(k))

                Variable xminFit
                Variable xmaxFit
                Variable roiSpanFit

                xminFit = y0 + startIdx * dy
                xmaxFit = y0 + endIdx * dy
                roiSpanFit = abs((npts - 1) * dy)

                Variable twoOK
                gGateReason = ""
                twoOK = LJZ_Check2P_ResultAndStore_A21(tpt, coef_wave, Peak1K, Peak2K, SigmaP1K, SigmaP2K, k, xminFit, xmaxFit, roiSpanFit, dy, Res)

                if (twoOK)
                    GateCode[k] = 2
                    GateMsg[k] = "2P_OK"
                else
                    GateCode[k] = 0
                    GateMsg[k] = "2P_FAIL;"
                    GateMsg[k] += gGateReason
                endif

                if (!twoOK)

                    coef_wave = coef0[p]
                    coef_wave[4] = Kpeak1
                    coef_wave[8] = Kpeak2

                    FuncFit/M=2/H=hold2/Q two_pv_ljz, coef_wave, tpt /D=$("fit_layer_" + Num2Str(k))

                    xminFit = y0 + startIdx * dy
                    xmaxFit = y0 + endIdx * dy
                    roiSpanFit = abs((npts - 1) * dy)

                    gGateReason = ""
                    twoOK = LJZ_Check2P_ResultAndStore_A21(tpt, coef_wave, Peak1K, Peak2K, SigmaP1K, SigmaP2K, k, xminFit, xmaxFit, roiSpanFit, dy, Res)

                    if (twoOK)
                        GateCode[k] = 2
                        GateMsg[k] = "2P_OK_RETRY"
                    else
                        GateCode[k] = 0
                        GateMsg[k] = "2P_FAIL_RETRY;"
                        GateMsg[k] += gGateReason
                    endif
                endif

                if (twoOK)

                    didDouble = 1

                    lastGood1 = Peak1K[k]
                    lastGood2 = Peak2K[k]
                    haveGood1 = 1
                    haveGood2 = 1

                    lastW1 = coef_wave[5]
                    lastW2 = coef_wave[9]
                    haveGoodW = 1
                endif

                KillWaves/Z tpt

            else
                GateCode[k] = 0
                GateMsg[k] = "2P_SKIP_NPTS<7;"
            endif
        endif

        // -------------------------
        // Single peak fallback
        // -------------------------
        if (!didDouble)

            forceSingleMode = 1

            Variable sCenter
            sCenter = (Kpeak1 + Kpeak2) / 2
            if (haveGood1 && haveGood2)
                sCenter = (lastGood1 + lastGood2) / 2
            endif

            Variable sIdx
            sIdx = round((sCenter - y0) / dy)

            Variable idxLo
            Variable idxHi
            idxLo = max(0, sIdx - ddta)
            idxHi = min(ny - 1, sIdx + ddta)

            if (idxHi - idxLo + 1 >= 7)

                Make/O/N=(idxHi - idxLo + 1) tpt1
                tpt1 = mdc_wave[idxLo + p]
                SetScale/P x, y0 + idxLo * dy, dy, tpt1

                WaveStats/Q tpt1
                Variable localMin
                Variable localMax
                Variable localPos

                localMin = V_min
                localMax = V_max
                localPos = V_maxLoc

                Variable initW
                initW = max(Res, 3 * abs(dy))
                if (haveGoodW)
                    initW = (lastW1 + lastW2) / 2
                endif

                cfw = 0
                cfw[0] = localMin
                cfw[1] = 0
                cfw[3] = localMax - localMin
                cfw[4] = localPos
                cfw[5] = initW
                cfw[6] = 0.5
                cfw[7] = max(Res, 1e-6)

                KillWaves/Z W_sigma
                Duplicate/O tpt1, $("fit_layer_" + Num2Str(k))

                FuncFit/M=2/Q/H="00000011" one_pv_ljz, cfw, tpt1 /D=$("fit_layer_" + Num2Str(k))
                // -------------------------------------------------
                // ROI bounds (必须在调用 1P gate 前定义)
                // -------------------------------------------------
                Variable xLo1
                Variable xHi1
                Variable roiSpan1

                xLo1 = y0 + idxLo * dy
                xHi1 = y0 + idxHi * dy

                if (xLo1 > xHi1)
                    Variable xSwap1
                    xSwap1 = xLo1
                    xLo1 = xHi1
                    xHi1 = xSwap1
                endif

                roiSpan1 = abs((idxHi - idxLo) * dy)
                if (roiSpan1 <= 0)
                    roiSpan1 = abs((idxHi - idxLo + 1) * dy)
                endif

                // -------------------------------------------------
                // Call unified 1P gate
                // -------------------------------------------------
                gGateReason = ""

                Variable localSD1
                localSD1 = NaN
                if (numtype(V_sdev) == 0)
                    localSD1 = V_sdev
                endif

                Variable onePeakOK
                onePeakOK = LJZ_Check1P_ResultAndStore_A21(tpt1, cfw, Peak3K, SigmaP3K, k, xLo1, xHi1, roiSpan1, dy, Res, localMin, localMax, localSD1)

                if (onePeakOK)

                    if (strlen(GateMsg[k]) == 0)
                        GateMsg[k] = "1P_OK"
                    else
                        GateMsg[k] += " | 1P_OK"
                    endif
                    GateCode[k] = 1

                    if (haveGoodW)
                        lastW1 = max(0, cfw[5])
                        lastW2 = max(0, cfw[5])
                    else
                        lastW1 = max(0, cfw[5])
                        lastW2 = max(0, cfw[5])
                        haveGoodW = 1
                    endif

                    KillWaves/Z tpt1

                else

                    if (strlen(GateMsg[k]) == 0)
                        GateMsg[k] = "1P_FAIL;"
                        GateMsg[k] += gGateReason
                    else
                        GateMsg[k] += " | 1P_FAIL;"
                        GateMsg[k] += gGateReason
                    endif
                    GateCode[k] = 0

                    // ---- 关键修改：单峰失败 -> 立刻退出所有拟合流程 ----
                    abortAll = 1
                    abortAt  = k
                    abortMsg = "ABORT_AFTER_1P_FAIL@k=" + Num2Str(k) + ";" + gGateReason

                    KillWaves/Z tpt1
                    break
                endif

            else

                Peak3K[k] = NaN
                SigmaP3K[k] = NaN

                if (strlen(GateMsg[k]) == 0)
                    GateMsg[k] = "1P_SKIP_NPTS<7;"
                else
                    GateMsg[k] += " | 1P_SKIP_NPTS<7;"
                endif
                GateCode[k] = 0

                // ---- 关键修改：单峰无法拟合(点数不足) -> 立刻退出所有拟合流程 ----
                abortAll = 1
                abortAt  = k
                abortMsg = "ABORT_AFTER_1P_SKIP_NPTS<7@k=" + Num2Str(k)
                break

            endif
        endif

        // -------------------------
        // Overlap plot
        // -------------------------
        if (k == 0)
            Display/N=$wOlap $("layer_show_" + Num2Str(k))
            Label/W=$wOlap left "Intensity (a.u.)"
            Label/W=$wOlap bottom "Angle (degree)"
        else
            AppendToGraph $("layer_show_" + Num2Str(k))
            ModifyGraph offset($("layer_show_" + Num2Str(k))) = {0, k * kvary}
        endif

        Wave/Z fW = $("fit_layer_" + Num2Str(k))
        if (WaveExists(fW))
            AppendToGraph/C=(0, 65535, 65535) fW
            ModifyGraph offset($NameOfWave(fW)) = {0, k * kvary}
        endif

    endfor

    // -------------------------
    // 如果中止：标记剩余帧 GateLog（避免表里一堆 NaN 看不出发生了啥）
    // -------------------------
    if (abortAll)
        Variable kk
        for (kk = abortAt + 1; kk < nt; kk += 1)
            GateCode[kk] = 0
            GateMsg[kk]  = abortMsg
        endfor
    endif

    // -------------------------
    // Trajectory plot
    // -------------------------
    Display/N=$wTLF Peak1K
    AppendToGraph Peak2K
    AppendToGraph Peak3K

    ErrorBars/RGB=(0,0,0) Peak1K Y, wave=(SigmaP1K, SigmaP1K)
    ErrorBars/RGB=(0,0,0) Peak2K Y, wave=(SigmaP2K, SigmaP2K)
    ErrorBars/RGB=(0,65535,65535) Peak3K Y, wave=(SigmaP3K, SigmaP3K)

    String xLabelStr
    xLabelStr = ""

    switch (uz)
        case 0:
            xLabelStr = "Delay (ps)"
            break
        case 1:
            xLabelStr = "Temperature (K)"
            break
        case 2:
            xLabelStr = "Fluence (uJ/cm\\S2\\M)"
            break
        default:
            xLabelStr = "Frame Index"
    endswitch

    Label/W=$wTLF bottom xLabelStr
    Label/W=$wTLF left "Angle (degree)"

    // -------------------------
    // Gate log view (table)
    // -------------------------
    Edit/N=$wLog GateCode, GateMsg

    Variable retCode
    retCode = 0
    if (abortAll)
        retCode = -2
    endif

    SetDataFolder df0
    return retCode
End


Function LJZ_Check1P_ResultAndStore_A21(wFit, coefWave1, Peak3K, SigmaP3K, frameIdx, xLoIn, xHiIn, roiSpan, dy, Res, localMin, localMax, localSdev)
    Wave wFit
    Wave coefWave1
    Wave Peak3K, SigmaP3K
    Variable frameIdx, xLoIn, xHiIn, roiSpan, dy, Res
    Variable localMin, localMax, localSdev

    SVAR gGateReason = root:ARPES_LJZ:MDCFit:gLastGateReason
    gGateReason = ""

    String tmp
    tmp = ""

    Variable ok = 1
    Variable dxA = abs(dy)

    // -------------------------
    // Fit status
    // -------------------------
    NVAR/Z vfe1 = V_FitError
    if (NVAR_Exists(vfe1) && vfe1 != 0)
        ok = 0
        sprintf tmp, "V_FitError=%g;", vfe1
        gGateReason += tmp
    endif

    NVAR/Z vfq1 = V_FitQuitReason
    if (NVAR_Exists(vfq1) && vfq1 != 0)
        ok = 0
        sprintf tmp, "V_FitQuitReason=%g;", vfq1
        gGateReason += tmp
    endif

    // -------------------------
    // Params
    // one_pv_ljz: [0]=bg, [3]=amp, [4]=pos, [5]=widFree, [6]=shape, [7]=res
    // -------------------------
    Variable sPos, sH, wFree, resFit
    sPos  = coefWave1[4]
    sH    = coefWave1[3]
    wFree = max(0, coefWave1[5])
    resFit = coefWave1[7]

    if (numtype(resFit) != 0 || resFit < 0)
        resFit = Res
    endif

    // -------------------------
    // Basic sanity
    // -------------------------
    if (ok)
        if (numtype(sPos) != 0 || numtype(sH) != 0)
            ok = 0
            sprintf tmp, "NAN_PARAM(pos=%g,H=%g);", sPos, sH
            gGateReason += tmp
        endif
    endif

    if (ok)
        if (sH <= 0)
            ok = 0
            sprintf tmp, "NEG_H(H=%g);", sH
            gGateReason += tmp
        endif
    endif

    // -------------------------
    // ROI check
    // allow some slack: +/- 0.1*roiSpan
    // -------------------------
    Variable xLo, xHi
    xLo = xLoIn
    xHi = xHiIn
    if (xLo > xHi)
        Variable tSwap
        tSwap = xLo
        xLo = xHi
        xHi = tSwap
    endif

    if (ok)
        Variable slack
        slack = 0.1 * roiSpan
        if (sPos < xLo - slack || sPos > xHi + slack)
            ok = 0
            sprintf tmp, "POS_OUTSIDE_ROI(pos=%.6g, ROI=[%.6g,%.6g], slack=0.1*roiSpan=%.6g, roiSpan=%.6g);", sPos, xLo, xHi, slack, roiSpan
            gGateReason += tmp
        endif
    endif

    // -------------------------
    // Width sanity (effective HWHM)
    // -------------------------
    Variable weff
    weff = LJZ_HWHM_eff(wFree, resFit)

    if (ok)
        if (numtype(weff) != 0)
            ok = 0
            sprintf tmp, "NAN_W(weff=%g,wFree=%g,res=%g);", weff, wFree, resFit
            gGateReason += tmp
        endif
    endif

    if (ok)
        if (weff <= 0)
            ok = 0
            sprintf tmp, "BAD_W<=0(weff=%.6g,wFree=%.6g,res=%.6g);", weff, wFree, resFit
            gGateReason += tmp
        endif
    endif

    if (ok)
        Variable wThr
        wThr = 2 * roiSpan
        if (weff > wThr)
            ok = 0
            sprintf tmp, "W_TOO_BIG(weff=%.6g > 2*roiSpan=%.6g; roiSpan=%.6g; wFree=%.6g; res=%.6g);", weff, wThr, roiSpan, wFree, resFit
            gGateReason += tmp
        endif
    endif

    // -------------------------
    // Significance (amp vs noise)
    // uses localMin/localMax/localSdev from WaveStats on ROI
    // -------------------------
    if (ok)
        Variable amp
        amp = localMax - localMin

        if (numtype(localSdev) == 0 && localSdev > 0)
            if (amp < 1.5 * localSdev)
                ok = 0
                sprintf tmp, "NOT_SIGNIFICANT(amp=%.6g < 1.5*sdev=%.6g; sdev=%.6g; min=%.6g; max=%.6g);", amp, 1.5*localSdev, localSdev, localMin, localMax
                gGateReason += tmp
            endif
        endif
    endif

    // -------------------------
    // Sigma gate (position uncertainty)
    // W_sigma[4] corresponds to coef[4] (position)
    // -------------------------
    Wave/Z wSig = W_sigma
    Variable sx = NaN

    if (ok)
        if (WaveExists(wSig))
            if (DimSize(wSig, 0) >= 8)
                sx = wSig[4]
                if (numtype(sx) != 0)
                    ok = 0
                    gGateReason += "SIGMA_NAN;"
                else
                    Variable sxThr
                    sxThr = max(0.2 * weff, 0.8 * dxA)
                    if (sx > sxThr)
                        ok = 0
                        sprintf tmp, "SIGMA_TOO_BIG(sx=%.6g > thr=max(0.2*weff,0.5*|dy|)=%.6g; weff=%.6g; dy=%.6g);", sx, sxThr, weff, dy
                        gGateReason += tmp
                    endif
                endif
            else
                sprintf tmp, "NO_SIGMA_DIM(dim0=%d);", DimSize(wSig,0)
                gGateReason += tmp
                // 若你希望没 sigma 就 fail，取消下面注释：
                // ok = 0
            endif
        else
            gGateReason += "NO_SIGMA_WAVE;"
            // 若你希望没 sigma 就 fail，取消下面注释：
            // ok = 0
        endif
    endif

    // -------------------------
    // Store result
    // -------------------------
    if (ok)
        Peak3K[frameIdx] = sPos
        SigmaP3K[frameIdx] = sx
        gGateReason = "OK"
        return 1
    endif

    if (strlen(gGateReason) == 0)
        gGateReason = "UNKNOWN_FAIL"
    endif

    return 0
End


Function LJZ_Check2P_ResultAndStore_A21(wFit, coefWave, Peak1K, Peak2K, SigmaP1K, SigmaP2K, frameIdx, xminX, xmaxX, roiSpan, dy, Res)
    Wave wFit
    Wave coefWave
    Wave Peak1K, Peak2K, SigmaP1K, SigmaP2K
    Variable frameIdx, xminX, xmaxX, roiSpan, dy, Res

    SVAR gGateReason = root:ARPES_LJZ:MDCFit:gLastGateReason
    gGateReason = ""

    String tmp
    tmp = ""

    Variable ok = 1
    Variable dxA = abs(dy)

    // 提取拟合参数
    Variable H1, x1, w1f, eta1
    Variable H2, x2, w2f, eta2

    H1 = coefWave[3]
    x1 = coefWave[4]
    w1f = max(0, coefWave[5])
    eta1 = coefWave[6]

    H2 = coefWave[7]
    x2 = coefWave[8]
    w2f = max(0, coefWave[9])
    eta2 = coefWave[10]

    // 处理分辨率
    Variable resFit = coefWave[11]
    if (numtype(resFit) != 0 || resFit < 0)
        resFit = Res
    endif

    // 记录是否发生了左右互换
    Variable swapped = 0

    // Swap blocks to enforce x1 <= x2 (保证左峰在左，右峰在右)
    if (numtype(x1) == 0 && numtype(x2) == 0)
        if (x1 > x2)
            Variable vTmp

            // 交换系数波中的参数
            vTmp = coefWave[3];  coefWave[3]  = coefWave[7];  coefWave[7]  = vTmp // Amp
            vTmp = coefWave[4];  coefWave[4]  = coefWave[8];  coefWave[8]  = vTmp // Pos
            vTmp = coefWave[5];  coefWave[5]  = coefWave[9];  coefWave[9]  = vTmp // Wid
            vTmp = coefWave[6];  coefWave[6]  = coefWave[10]; coefWave[10] = vTmp // Shape

            // 更新本地变量
            H1 = coefWave[3]
            x1 = coefWave[4]
            w1f = max(0, coefWave[5])
            eta1 = coefWave[6]

            H2 = coefWave[7]
            x2 = coefWave[8]
            w2f = max(0, coefWave[9])
            eta2 = coefWave[10]

            swapped = 1
        endif
    endif

    // ------------------------------------------------------------
    // 1) Fit Status Checks
    // ------------------------------------------------------------
    NVAR/Z vfe = V_FitError
    if (NVAR_Exists(vfe) && vfe != 0)
        ok = 0
        sprintf tmp, "V_FitError=%g;", vfe
        gGateReason += tmp
    endif

    NVAR/Z vfq = V_FitQuitReason
    if (NVAR_Exists(vfq) && vfq != 0)
        ok = 0
        sprintf tmp, "V_FitQuitReason=%g;", vfq
        gGateReason += tmp
    endif

    // ------------------------------------------------------------
    // 2) NaN Checks
    // ------------------------------------------------------------
    if (numtype(H1) != 0 || numtype(H2) != 0 || numtype(x1) != 0 || numtype(x2) != 0)
        ok = 0
        sprintf tmp, "NAN_PARAM(H1=%g,H2=%g,x1=%g,x2=%g);", H1, H2, x1, x2
        gGateReason += tmp
    endif

    // ------------------------------------------------------------
    // 3) ROI Checks
    // ------------------------------------------------------------
    if (ok)
        if (x1 < xminX || x1 > xmaxX)
            ok = 0
            sprintf tmp, "X1_OUTSIDE_ROI(x1=%.6g, ROI=[%.6g,%.6g]);", x1, xminX, xmaxX
            gGateReason += tmp
        endif
        if (x2 < xminX || x2 > xmaxX)
            ok = 0
            sprintf tmp, "X2_OUTSIDE_ROI(x2=%.6g, ROI=[%.6g,%.6g]);", x2, xminX, xmaxX
            gGateReason += tmp
        endif
    endif

    // ------------------------------------------------------------
    // 4) Height Checks
    // ------------------------------------------------------------
    if (ok)
        if (H1 <= 0 || H2 <= 0)
            ok = 0
            sprintf tmp, "NEG_HEIGHT(H1=%.6g,H2=%.6g);", H1, H2
            gGateReason += tmp
        endif
    endif

    // ------------------------------------------------------------
    // 5) Width Checks (Effective HWHM)
    // ------------------------------------------------------------
    Variable s1, s2
    s1 = LJZ_HWHM_eff(w1f, resFit)
    s2 = LJZ_HWHM_eff(w2f, resFit)

    if (ok)
        if (numtype(s1) != 0 || numtype(s2) != 0)
            ok = 0
            sprintf tmp, "NAN_WIDTH(s1=%g,s2=%g,w1f=%g,w2f=%g,res=%.6g);", s1, s2, w1f, w2f, resFit
            gGateReason += tmp
        endif

        if (ok)
            if (s1 <= 0 || s2 <= 0)
                ok = 0
                sprintf tmp, "BAD_WIDTH<=0(s1=%.6g,s2=%.6g,w1f=%.6g,w2f=%.6g,res=%.6g);", s1, s2, w1f, w2f, resFit
                gGateReason += tmp
            endif
        endif

        if (ok)
            Variable wThr
            wThr = 0.6 * roiSpan
            if (s1 > wThr || s2 > wThr)
                ok = 0
                sprintf tmp, "WIDTH_TOO_BIG(s1=%.6g,s2=%.6g,thr=0.6*roiSpan=%.6g,roiSpan=%.6g);", s1, s2, wThr, roiSpan
                gGateReason += tmp
            endif
        endif
    endif

    // ------------------------------------------------------------
    // 6) Separation Check
    // ------------------------------------------------------------
    if (ok)
        Variable sep = abs(x2 - x1)
        Variable needSep = max(Res, 3 * dxA)
        if (sep < needSep)
            ok = 0
            sprintf tmp, "TOO_CLOSE(sep=%.6g < needSep=max(Res,3*|dy|)=%.6g; Res=%.6g; dy=%.6g);", sep, needSep, Res, dy
            gGateReason += tmp
        endif
    endif

    // ------------------------------------------------------------
    // 7) Sigma Gate (误差判定)
    // ------------------------------------------------------------
    Wave/Z sigmaW = W_sigma
    Variable sx1 = NaN, sx2 = NaN

    if (ok)
        if (WaveExists(sigmaW))
            if (DimSize(sigmaW, 0) >= 12)

                // W_sigma[4] 对应原始 coef[4], W_sigma[8] 对应原始 coef[8]
                if (swapped)
                    sx1 = sigmaW[8]
                    sx2 = sigmaW[4]
                else
                    sx1 = sigmaW[4]
                    sx2 = sigmaW[8]
                endif

                if (numtype(sx1) != 0 || numtype(sx2) != 0)
                    ok = 0
                    sprintf tmp, "SIGMA_NAN(sx1=%g,sx2=%g; swapped=%g);", sx1, sx2, swapped
                    gGateReason += tmp
                endif

                if (ok)
                    Variable sx1thr = max(0.2 * s1, 2.2 * dxA)
                    Variable sx2thr = max(0.2 * s2, 2.2 * dxA)

                    if (sx1 > sx1thr)
                        ok = 0
                        sprintf tmp, "SIGMA_X1_TOO_BIG(sx1=%.6g > thr=max(0.2*s1,0.5*|dy|)=%.6g; s1=%.6g; dy=%.6g);", sx1, sx1thr, s1, dy
                        gGateReason += tmp
                    endif
                    if (sx2 > sx2thr)
                        ok = 0
                        sprintf tmp, "SIGMA_X2_TOO_BIG(sx2=%.6g > thr=max(0.2*s2,0.5*|dy|)=%.6g; s2=%.6g; dy=%.6g);", sx2, sx2thr, s2, dy
                        gGateReason += tmp
                    endif
                endif

            else
                // sigmaW dim 不够：这里按 warning 记，但不强制 fail（你可改成 fail）
                sprintf tmp, "NO_SIGMA_DIM(dim0=%d);", DimSize(sigmaW,0)
                gGateReason += tmp
                // 若你希望没有 sigma 也直接判失败，取消下面注释：
                // ok = 0
            endif
        else
            // 没有误差波：按 warning 记，但不强制 fail
            gGateReason += "NO_SIGMA_WAVE;"
            // 若你希望没有误差波就判失败，取消下面注释：
            // ok = 0
        endif
    endif

    // ------------------------------------------------------------
    // 8) Jump Check (稳定性检查)
    // ------------------------------------------------------------
    if (ok && frameIdx > 0)
        Variable jumpThr = 10 * dxA

        Variable prevX1 = Peak1K[frameIdx - 1]
        Variable prevX2 = Peak2K[frameIdx - 1]

        if (numtype(prevX1) == 0 && numtype(prevX2) == 0)

            Variable j1 = abs(x1 - prevX1)
            Variable j2 = abs(x2 - prevX2)

            if (j1 > jumpThr || j2 > jumpThr)
                ok = 0
                sprintf tmp, "PEAK_JUMP(|dx1|=%.6g,|dx2|=%.6g > thr=25*|dy|=%.6g; prev=(%.6g,%.6g), now=(%.6g,%.6g), dy=%.6g);", j1, j2, jumpThr, prevX1, prevX2, x1, x2, dy
                gGateReason += tmp
            endif
        endif
    endif

    // ------------------------------------------------------------
    // 9) Result Storage
    // ------------------------------------------------------------
    if (ok)
        Peak1K[frameIdx] = x1
        Peak2K[frameIdx] = x2

        // 存误差（若没有 sigmaW，此时 sx1/sx2 可能还是 NaN）
        SigmaP1K[frameIdx] = sx1
        SigmaP2K[frameIdx] = sx2

        gGateReason = "OK"
        return 1
    endif

    if (strlen(gGateReason) == 0)
        gGateReason = "UNKNOWN_FAIL"
    endif

    return 0
End




// =====================================================
// FromShow 版：SingleLock（先双峰；一旦某帧单峰成功 -> 后面锁定全部只做单峰）
// 输入：runDF 必须包含 mdc_show_k
// 输出：runDF:FIT_SingleLock: 下生成 Peak1K/Peak2K/Peak3K 等
// =====================================================
Function MDC_NdSb_LJZ_MergeLock_FromShow(runDF, Kpeak1, Kpeak2, Res, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio)
    String   runDF
    Variable Kpeak1, Kpeak2, Res, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio
    LJZ_EnsureMDCFitDF()

    runDF = RemoveEnding(runDF, ":") + ":"

    // ---- nt ----
    Variable nt = 0
    do
        Wave/Z wTest = $(runDF + "mdc_show_" + Num2Str(nt))
        if (!WaveExists(wTest))
            break
        endif
        nt += 1
    while(1)

    if (nt <= 0)
        DoAlert 0, "FromShow: runDF 下找不到 mdc_show_0, 无法拟合。"
        return -1
    endif

    // ---- ny/y0/dy ----
    Wave w0 = $(runDF + "mdc_show_0")
    Variable ny = numpnts(w0)
    Variable y0 = DimOffset(w0, 0)
    Variable dy = DimDelta(w0, 0)
    if (ny < 7 || numtype(dy) != 0 || dy == 0)
        DoAlert 0, "FromShow: mdc_show_0 的点数/坐标不合法。"
        return -1
    endif

    // ---- 默认参数 ----
    if (numtype(wi1) != 0)
        wi1 = 1
    endif
    if (numtype(wi2) != 0)
        wi2 = wi1
    endif
    if (numtype(uz) != 0)
        uz = 0
    endif
    if (numtype(ddta) != 0)
        ddta = 10
    endif
    if (ddta < 0)
        ddta = 0
    endif
    if (numtype(WidRatio) != 0 || WidRatio <= 0)
        WidRatio = 1
    endif
    if (numtype(Res) != 0 || Res < 0)
        Res = 0
    endif

    Variable needSep = max(Res, 3 * abs(dy))

    // ---- t 轴刻度 ----
    Variable t0 = 0, dt = 1
    NVAR/Z g_t0 = root:ARPES_LJZ:MDCFit:Run_t0
    NVAR/Z g_dt = root:ARPES_LJZ:MDCFit:Run_dt
    if (NVAR_Exists(g_t0) && NVAR_Exists(g_dt))
        if (numtype(g_t0) == 0)
            t0 = g_t0
        endif
        if (numtype(g_dt) == 0 && g_dt != 0)
            dt = g_dt
        endif
    endif

    // ---- 输出 DF ----
    String fitDF = runDF + "FIT_ML:"
    NewDataFolder/O $(RemoveEnding(fitDF, ":"))
    SetDataFolder $(RemoveEnding(fitDF, ":"))

    Make/O/N=12 coef_wave = 0
    Make/O/N=8  cfw       = 0

    Make/O/N=(nt) Peak1K=NaN, Peak2K=NaN, Peak3K=NaN
    Make/O/N=(nt) SigmaP1K=NaN, SigmaP2K=NaN, SigmaP3K=NaN
    SetScale/P x, t0, dt, Peak1K, Peak2K, Peak3K, SigmaP1K, SigmaP2K, SigmaP3K

    // =====================================================
    // 窗口命名：清洗 + 截断 + 运行前 kill，防止重复窗口
    // =====================================================
    SVAR bn = root:ARPES_LJZ:MDCFit:gBaseName
    String bnTag = bn
    if (strlen(bnTag) == 0)
        bnTag = runDF
    endif
    bnTag = CleanupName(bnTag, 0)        // 关键：去掉冒号等非法字符
    if (strlen(bnTag) > 20)
        bnTag = bnTag[0,19]              // 可选：避免窗口名过长
    endif

	String wOlap = "MDC_Olap_ML_" + bnTag
	String wTLF  = "MDC_Traj_ML_" + bnTag

    // （可选但推荐）先清掉旧窗口，避免同名重复/AppendToGraph 混乱
    killwindow/Z $wOlap
    killwindow/Z $wTLF

    Variable lastGood1 = Kpeak1, lastGood2 = Kpeak2
    Variable haveGood1 = 0,      haveGood2 = 0
    Variable singleOnly = 0

    // 宽度初值（自由宽度）
    Variable w1f0, w2f0, tmpv
    tmpv = max(wi1, Res)
    w1f0 = tmpv*tmpv - Res*Res
    if (w1f0 < 0)
        w1f0 = 0
    endif
    w1f0 = sqrt(w1f0)

    tmpv = max(wi2, Res)
    w2f0 = tmpv*tmpv - Res*Res
    if (w2f0 < 0)
        w2f0 = 0
    endif
    w2f0 = sqrt(w2f0)

    Variable k
    for (k = 0; k < nt; k += 1)

        Wave/Z mdc_wave = $(runDF + "mdc_show_" + Num2Str(k))
        if (!WaveExists(mdc_wave))
            continue
        endif

        Duplicate/O mdc_wave, $("layer_show_" + Num2Str(k))

        Variable didDouble = 0

        // =====================================================
        // 1) 双峰（仅当 singleOnly==0）
        // =====================================================
        if (!singleOnly)

            Variable x1seed, x2seed
            if (haveGood1)
                x1seed = lastGood1
            else
                x1seed = Kpeak1
            endif
            if (haveGood2)
                x2seed = lastGood2
            else
                x2seed = Kpeak2
            endif

            Variable idx1 = round((x1seed - y0) / dy)
            Variable idx2 = round((x2seed - y0) / dy)
            idx1 = max(0, min(ny - 1, idx1))
            idx2 = max(0, min(ny - 1, idx2))
            if (idx2 < idx1)
                Variable tmpIdx = idx1
                idx1 = idx2
                idx2 = tmpIdx
            endif

            Variable startIdx = max(0, idx1 - fdta)
            Variable endIdx   = min(ny - 1, idx2 + bdta)
            Variable npts     = endIdx - startIdx + 1

            if (npts >= 7)

                Make/O/N=(npts) tpt
                tpt = mdc_wave[startIdx + p]
                SetScale/P x, y0 + startIdx * dy, dy, tpt

                // 初值
                Variable x1_0 = y0 + idx1 * dy
                Variable x2_0 = y0 + idx2 * dy
                Variable H1_0 = mdc_wave[idx1]
                Variable H2_0 = mdc_wave[idx2]

                coef_wave[0]  = 0
                coef_wave[1]  = 0
                coef_wave[2]  = 0
                coef_wave[3]  = H1_0
                coef_wave[4]  = LJZ_Clamp(x1_0, y0 + startIdx*dy, y0 + endIdx*dy)

                // 宽度：k=0 用 w1f0/w2f0；之后沿用上一帧成功结果（coef_wave[5]/[9]）
                if (k == 0)
                    coef_wave[5] = w1f0
                endif
                coef_wave[6]  = 0.8
                coef_wave[7]  = H2_0
                coef_wave[8]  = LJZ_Clamp(x2_0, y0 + startIdx*dy, y0 + endIdx*dy)
                if (k == 0)
                    coef_wave[9] = w2f0
                endif
                coef_wave[10] = 0.8
                coef_wave[11] = max(Res, 1e-6)

                String hold2 = LJZ_HoldMask(12, hdx1 = 6, hdx2 = 10, hdx3 = 11)

                Make/FREE/N=12 coef0
                coef0 = coef_wave[p]

                // 第一次双峰
                KillWaves/Z W_sigma
                Duplicate/O tpt, $("fit_layer_" + Num2Str(k))
                FuncFit/M=2/H=hold2/Q two_pv_ljz, coef_wave, tpt/D=$("fit_layer_" + Num2Str(k))

                Wave/Z W_sigma
                Variable twoOK = 0

                Variable x1f, x2f, H1f, H2f, w1f, w2f, resH2
                Variable s1eff, s2eff, sx1, sx2, sx1thr, sx2thr
                Variable posOK

                if (WaveExists(W_sigma) && DimSize(W_sigma, 0) >= 12)

                    x1f   = coef_wave[4]
                    x2f   = coef_wave[8]
                    H1f   = coef_wave[3]
                    H2f   = coef_wave[7]
                    w1f   = coef_wave[5]
                    w2f   = coef_wave[9]
                    resH2 = coef_wave[11]
                    s1eff = sqrt(resH2*resH2 + w1f*w1f)
                    s2eff = sqrt(resH2*resH2 + w2f*w2f)
                    sx1   = W_sigma[4]
                    sx2   = W_sigma[8]

                    if (numtype(x1f) == 0 && numtype(x2f) == 0)
                        if (x2f < x1f)
                            Variable tx = x1f; x1f = x2f; x2f = tx
                            Variable tH = H1f; H1f = H2f; H2f = tH
                            Variable tw = w1f; w1f = w2f; w2f = tw
                            Variable ts = sx1; sx1 = sx2; sx2 = ts
                            Variable te = s1eff; s1eff = s2eff; s2eff = te
                        endif
                    endif

                    sx1thr = max(0.2 * s1eff, 0.5 * abs(dy))
                    sx2thr = max(0.2 * s2eff, 0.5 * abs(dy))

                    posOK = (numtype(x1f) == 0 && numtype(x2f) == 0) \
                            && ((x2f - x1f) >= needSep) \
                            && (numtype(sx1) == 0 && numtype(sx2) == 0) \
                            && (sx1 <= sx1thr) && (sx2 <= sx2thr)

                    if (posOK)
                        twoOK = 1
                    endif
                endif

                // 第二次双峰：恢复初值 coef0 再试一次
                if (!twoOK)

                    coef_wave = coef0[p]

                    KillWaves/Z W_sigma
                    Duplicate/O tpt, $("fit_layer_" + Num2Str(k))
                    FuncFit/M=2/H=hold2/Q two_pv_ljz, coef_wave, tpt/D=$("fit_layer_" + Num2Str(k))

                    Wave/Z W_sigma
                    if (WaveExists(W_sigma) && DimSize(W_sigma, 0) >= 12)

                        x1f   = coef_wave[4]
                        x2f   = coef_wave[8]
                        H1f   = coef_wave[3]
                        H2f   = coef_wave[7]
                        w1f   = coef_wave[5]
                        w2f   = coef_wave[9]
                        resH2 = coef_wave[11]
                        s1eff = sqrt(resH2*resH2 + w1f*w1f)
                        s2eff = sqrt(resH2*resH2 + w2f*w2f)
                        sx1   = W_sigma[4]
                        sx2   = W_sigma[8]

                        if (numtype(x1f) == 0 && numtype(x2f) == 0)
                            if (x2f < x1f)
                                Variable tx2 = x1f; x1f = x2f; x2f = tx2
                                Variable tH2 = H1f; H1f = H2f; H2f = tH2
                                Variable tw2 = w1f; w1f = w2f; w2f = tw2
                                Variable ts2 = sx1; sx1 = sx2; sx2 = ts2
                                Variable te2 = s1eff; s1eff = s2eff; s2eff = te2
                            endif
                        endif

                        sx1thr = max(0.2 * s1eff, 0.5 * abs(dy))
                        sx2thr = max(0.2 * s2eff, 0.5 * abs(dy))

                        posOK = (numtype(x1f) == 0 && numtype(x2f) == 0) \
                                && ((x2f - x1f) >= needSep) \
                                && (numtype(sx1) == 0 && numtype(sx2) == 0) \
                                && (sx1 <= sx1thr) && (sx2 <= sx2thr)

                        if (posOK)
                            twoOK = 1
                        endif
                    endif
                endif

                // 接受双峰
                // [修改 1] 健壮的数据保存：直接读取 Wave，不依赖临时变量
            if (twoOK)
                didDouble = 1
                // 保存位置
                Peak1K[k] = coef_wave[4]
                Peak2K[k] = coef_wave[8]
                
                // 保存误差 (安全检查)
                Wave/Z wSig = W_sigma
                if (WaveExists(wSig))
                    SigmaP1K[k] = wSig[4]
                    SigmaP2K[k] = wSig[8]
                else
                    SigmaP1K[k] = NaN
                    SigmaP2K[k] = NaN
                endif

                // 更新种子
                lastGood1 = Peak1K[k]
                lastGood2 = Peak2K[k]
                haveGood1 = 1
                haveGood2 = 1
            endif

                KillWaves/Z tpt
            endif // npts>=7
        endif // !singleOnly

        // =====================================================
        // 2) 单峰兜底（若本层未双峰成功；并且一旦成功就锁 singleOnly=1）
        // =====================================================
        if (!didDouble)

            Variable sStart = max(0, round((lastGood1 - y0) / dy) - fdta - ddta)
            Variable sEnd   = min(ny - 1, round((lastGood1 - y0) / dy) + bdta + ddta)
            Variable sn     = sEnd - sStart + 1

            if (sn >= 7)

                Make/O/N=(sn) tpt1
                tpt1 = mdc_wave[sStart + p]
                SetScale/P x, y0 + sStart*dy, dy, tpt1

                cfw[0] = 0
                cfw[1] = 0
                cfw[2] = 0

                cfw[3] = tpt1[round(sn/2)]
                cfw[4] = (lastGood2 * 0.2 + lastGood1 * 1.8) / 2

                Variable wGuess = coef_wave[9]
                if (numtype(wGuess) != 0 || wGuess <= 0)
                    wGuess = w2f0
                endif
                wGuess = wGuess / WidRatio
                cfw[5] = max(wGuess, 1e-6)

                cfw[6] = 0.8
                cfw[7] = max(Res, 1e-6)

                String hold1 = LJZ_HoldMask(8, hdx1 = 2, hdx2 = 6, hdx3 = 7)

                KillWaves/Z W_sigma
                Duplicate/O tpt1, $("fit_layer_" + Num2Str(k))
                FuncFit/Q/H=hold1 one_pv_ljz, cfw, tpt1/D=$("fit_layer_" + Num2Str(k))

                Wave/Z W_sigma

                Peak3K[k] = cfw[4]
                if (WaveExists(W_sigma) && DimSize(W_sigma, 0) >= 8 && numtype(W_sigma[4]) == 0)
                    SigmaP3K[k] = W_sigma[4]
                else
                    SigmaP3K[k] = NaN
                endif

                lastGood1 = cfw[4]
                lastGood2 = cfw[4]
                haveGood1 = 1
                haveGood2 = 1
                singleOnly = 1

                KillWaves/Z tpt1
            endif
        endif

        // =====================================================
        // 3) 叠图
        // =====================================================
        if (k == 0)
            // 注意：这里不再需要 killwindow（前面已 kill 过）
            Display/N=$wOlap $("layer_show_" + Num2Str(k))
            Label left, "Intensity (a.u.)"
            Label bottom, "Angle (degree)" 
        else
            AppendToGraph $("layer_show_" + Num2Str(k))
            ModifyGraph offset($("layer_show_" + Num2Str(k))) = {0, k * kvary}
        endif

        Wave/Z fW = $("fit_layer_" + Num2Str(k))
        if (WaveExists(fW))
            AppendToGraph/C=(0,65535,65535) fW
            ModifyGraph offset($NameOfWave(fW)) = {0, k * kvary}
        endif

    endfor

    // =====================================================
    // 4) 轨迹图
    // =====================================================
    Display/N=$wTLF Peak1K
    AppendToGraph Peak2K
    AppendToGraph Peak3K
    ErrorBars/RGB=(0,0,0) Peak1K Y, wave=(SigmaP1K, SigmaP1K)
    ErrorBars/RGB=(0,0,0) Peak2K Y, wave=(SigmaP2K, SigmaP2K)
    ErrorBars/RGB=(0,65535,65535) Peak3K Y, wave=(SigmaP3K, SigmaP3K)

    // [修改 3] 修正标签和单位
    Label left, "Angle (degree)" 
    
    switch(uz)
        case 0: // Delay
            Label bottom, "Delay Time (ps)"
            break
        case 1: // Temperature
            Label bottom, "Temperature (K)"
            break
        case 2: // Fluence (使用 Igor 的上标语法 \S...\M)
            Label bottom, "Fluence (uJ/cm\S2\M)" 
            break
        default:
            Label bottom, "Frame Index"
    endswitch

    KillWaves/Z coef_wave, cfw, W_sigma
    SetDataFolder root:
    return 0
End


// ============================================================================
// Helper: x 坐标 -> 索引（x2pnt + floor + clamp）
// ============================================================================
Function LJZ_X2Idx_Clamp_GPT(w, x)
    Wave w
    Variable x

    Variable npt = numpnts(w)
    Variable t = x2pnt(w, x)
    Variable idx = floor(t)

    if (idx < 0) 
    idx = 0 
    endif
    if (idx > npt-1) 
    idx = npt-1 
    endif
    return idx
End


// ============================================================================
// Helper: 智能双峰猜测（更稳版）
// 输出 wOut: [pos1, pos2, heightAtPos1, heightAtPos2]
// 逻辑：
//  1) 先用平滑后的二阶导找候选峰顶（D2 的负极小）
//  2) 若失败：分别在 seed1/seed2 附近窗口内直接找最大值兜底
// ============================================================================
Function LJZ_SmartGuess_Doublet_GPT(wSrc, seed1, seed2, ResH, wOut)
    Wave wSrc
    Variable seed1, seed2, ResH
    Wave wOut

    Variable npt = numpnts(wSrc)
    Variable x0  = DimOffset(wSrc, 0)
    Variable dx  = DimDelta(wSrc, 0)

    // 兜底先填 seed
    wOut[0] = seed1
    wOut[1] = seed2
    wOut[2] = wSrc[LJZ_X2Idx_Clamp_GPT(wSrc, seed1)]
    wOut[3] = wSrc[LJZ_X2Idx_Clamp_GPT(wSrc, seed2)]

    if (npt < 9) 
    return 0 
    endif
    if (numtype(dx)!=0 || dx==0) 
    return 0 
    endif

    // --- 平滑（避免 D2 被噪声毁掉）---
    Duplicate/FREE wSrc, wSm
    Smooth/B 9, wSm

    // --- 二阶导 ---
    Duplicate/FREE wSm, wD2
    Differentiate/METH=2 wD2
    Differentiate/METH=2 wD2

    // --- 阈值：排除纯噪声候选 ---
    Variable mx = WaveMax(wSrc)
    Variable thr = 0.05 * mx

    // --- 候选收集 ---
    Make/FREE/N=20 candX = NaN
    Make/FREE/N=20 candH = NaN
    Variable count = 0
    Variable i
    for (i=2; i<npt-2; i+=1)
        if (wD2[i] < wD2[i-1] && wD2[i] < wD2[i+1] && wD2[i] < 0)
            if (wSrc[i] > thr)
                candX[count] = x0 + i*dx
                candH[count] = wSrc[i]
                count += 1
                if (count >= 20) 
                break 
                endif
            endif
        endif
    endfor

    // --- 如果二阶导完全没抓到：按 seed 附近直接找最大值兜底 ---
// --- 如果二阶导完全没抓到：按 seed 附近直接找最大值兜底 ---
if (count <= 0)
    Variable win = max(0.8, 6*abs(dx))

    Variable bx, by

    LJZ_LocalMaxNearSeed_GPT(wSrc, seed1, win, bx, by)
    wOut[0] = bx
    wOut[2] = by

    LJZ_LocalMaxNearSeed_GPT(wSrc, seed2, win, bx, by)
    wOut[1] = bx
    wOut[3] = by

    return 0
endif


    // --- seed 匹配：离 seed1/seed2 最近的候选 ---
    Variable best1 = 0
    Variable best2 = 0
    Variable bestD1 = abs(candX[0]-seed1)
    Variable bestD2 = abs(candX[0]-seed2)

    Variable j
    for (j=1; j<count; j+=1)
        Variable d1 = abs(candX[j]-seed1)
        if (d1 < bestD1)
            bestD1 = d1
            best1 = j
        endif

        Variable d2 = abs(candX[j]-seed2)
        if (d2 < bestD2)
            bestD2 = d2
            best2 = j
        endif
    endfor

    // --- 若两个 seed 指向同一候选：用“另一侧最强”补一个 ---
    if (best1 == best2)
        wOut[0] = candX[best1]
        wOut[2] = candH[best1]

        Variable bestAlt = -1
        Variable bestAltH = -1e30
        for (j=0; j<count; j+=1)
            if (j != best1)
                if (candH[j] > bestAltH)
                    bestAltH = candH[j]
                    bestAlt = j
                endif
            endif
        endfor

        if (bestAlt >= 0)
            wOut[1] = candX[bestAlt]
            wOut[3] = candH[bestAlt]
        endif
    else
        wOut[0] = candX[best1];  wOut[2] = candH[best1]
        wOut[1] = candX[best2];  wOut[3] = candH[best2]
    endif

    // --- 太近就推开一点（保持可分辨性）---
    Variable minSep = 0.8 * max(abs(dx), ResH)
    if (abs(wOut[0]-wOut[1]) < minSep)
        Variable push = (seed2 < seed1) ? (-minSep) : (minSep)
        wOut[1] = wOut[0] + push
        wOut[3] = 0.7 * wOut[2]
    endif

    return 0
End


// ============================================================================
// Helper: 在 seed 附近窗口内找最大值（兜底用）
// 传回：bestX, bestY（用引用参数的写法）
// ============================================================================
Function LJZ_LocalMaxNearSeed_GPT(w, seed, win, bestX, bestY)
    Wave w
    Variable seed, win
    Variable &bestX, &bestY

    Variable n = numpnts(w)
    Variable x0 = DimOffset(w,0)
    Variable dx = DimDelta(w,0)

    Variable i0 = LJZ_X2Idx_Clamp_GPT(w, seed - win)
    Variable i1 = LJZ_X2Idx_Clamp_GPT(w, seed + win)
    if (i1 < i0)
        Variable t=i0; i0=i1; i1=t
    endif

    Variable imax = i0
    Variable vbest = w[i0]
    Variable i
    for (i=i0; i<=i1; i+=1)
        if (w[i] > vbest)
            vbest = w[i]
            imax = i
        endif
    endfor

    bestX = x0 + imax*dx
    bestY = vbest
    return 0
End












Function MDC_NdSb_LJZ_RA_BGFree_UCenter(runDF, Kpeak1, Kpeak2, ResH, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio)
    String   runDF
    Variable Kpeak1, Kpeak2, ResH, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio

    String saveDF = GetDataFolder(1)

    LJZ_EnsureMDCFitDF()
    runDF = RemoveEnding(runDF, ":") + ":"

    String/G root:ARPES_LJZ:MDCFit:gLastGateReason = ""
    SVAR gGateReason = root:ARPES_LJZ:MDCFit:gLastGateReason

    Variable nt = 0
    do
        Wave/Z wTest = $(runDF + "mdc_show_" + Num2Str(nt))
        if (!WaveExists(wTest))
            break
        endif
        nt += 1
    while(1)

    if (nt <= 0)
        DoAlert 0, "TOS_BGFree_UCenter: runDF 下找不到 mdc_show_0"
        SetDataFolder saveDF
        return -1
    endif

    Wave w0 = $(runDF + "mdc_show_0")
    Variable ny = numpnts(w0)
    Variable y0 = DimOffset(w0, 0)
    Variable dy = DimDelta(w0, 0)
    Variable dyA = abs(dy)

    if (ny < 7)
        DoAlert 0, "TOS_BGFree_UCenter: 点数太少"
        SetDataFolder saveDF
        return -1
    endif
    if (numtype(dy) != 0 || dy == 0)
        DoAlert 0, "TOS_BGFree_UCenter: DimDelta 非法"
        SetDataFolder saveDF
        return -1
    endif

    if (numtype(wi1) != 0)
        wi1 = 1
    endif
    if (numtype(wi2) != 0)
        wi2 = wi1
    endif
    if (numtype(uz)  != 0)
        uz  = 0
    endif
    if (numtype(ddta) != 0 || ddta < 0)
        ddta = 10
    endif
    if (numtype(WidRatio) != 0 || WidRatio <= 0)
        WidRatio = 1
    endif
    if (numtype(ResH) != 0 || ResH < 0)
        ResH = 0.002
    endif

    Variable t0 = 0
    Variable dt = 1
    NVAR/Z g_t0 = root:ARPES_LJZ:MDCFit:Run_t0
    NVAR/Z g_dt = root:ARPES_LJZ:MDCFit:Run_dt
    if (NVAR_Exists(g_t0) && numtype(g_t0) == 0)
        t0 = g_t0
    endif
    if (NVAR_Exists(g_dt) && numtype(g_dt) == 0 && g_dt != 0)
        dt = g_dt
    endif

    String fitDF = runDF + "FIT_RA:"
    NewDataFolder/O $(RemoveEnding(fitDF, ":"))
    SetDataFolder $(RemoveEnding(fitDF, ":"))

    Make/O/N=(nt) Peak1K
    Make/O/N=(nt) Peak2K
    Make/O/N=(nt) Peak3K
    Make/O/N=(nt) SigmaP1K
    Make/O/N=(nt) SigmaP2K
    Make/O/N=(nt) SigmaP3K

    Peak1K = NaN
    Peak2K = NaN
    Peak3K = NaN
    SigmaP1K = NaN
    SigmaP2K = NaN
    SigmaP3K = NaN

    SetScale/P x, t0, dt, Peak1K
    SetScale/P x, t0, dt, Peak2K
    SetScale/P x, t0, dt, Peak3K
    SetScale/P x, t0, dt, SigmaP1K
    SetScale/P x, t0, dt, SigmaP2K
    SetScale/P x, t0, dt, SigmaP3K

    // ---- NEW: Areas + separation + effective widths ----
    Make/O/N=(nt) AreaP1K
    Make/O/N=(nt) AreaP2K
    Make/O/N=(nt) AreaP3K
    Make/O/N=(nt) AreaSum12K
    Make/O/N=(nt) Sep12K
    Make/O/N=(nt) WeffP1K
    Make/O/N=(nt) WeffP2K
    Make/O/N=(nt) WeffP3K

    AreaP1K = NaN
    AreaP2K = NaN
    AreaP3K = NaN
    AreaSum12K = NaN
    Sep12K = NaN
    WeffP1K = NaN
    WeffP2K = NaN
    WeffP3K = NaN

    SetScale/P x, t0, dt, AreaP1K
    SetScale/P x, t0, dt, AreaP2K
    SetScale/P x, t0, dt, AreaP3K
    SetScale/P x, t0, dt, AreaSum12K
    SetScale/P x, t0, dt, Sep12K
    SetScale/P x, t0, dt, WeffP1K
    SetScale/P x, t0, dt, WeffP2K
    SetScale/P x, t0, dt, WeffP3K

    Make/O/N=(nt) BG_c0
    Make/O/N=(nt) BG_c1
    Make/O/N=(nt) BG_c2
    BG_c0 = NaN
    BG_c1 = NaN
    BG_c2 = NaN
    SetScale/P x, t0, dt, BG_c0
    SetScale/P x, t0, dt, BG_c1
    SetScale/P x, t0, dt, BG_c2

    Make/O/N=12 coef_wave = 0
    Make/O/N=8  cfw       = 0

    SVAR bn = root:ARPES_LJZ:MDCFit:gBaseName
    String bnTag = bn
    if (strlen(bnTag) == 0)
        bnTag = runDF
    endif
    bnTag = CleanupName(bnTag, 0)

	String wOlap = "MDC_Olap_RA_" + bnTag
	String wTLF  = "MDC_Traj_RA_" + bnTag
    KillWindow/Z $wOlap
    KillWindow/Z $wTLF

    Variable target1 = Kpeak1
    Variable target2 = Kpeak2

    Variable alphaPos = 0.80
    Variable alphaWid = 0.90

    Variable lastK1 = target1
    Variable lastK2 = target2

    Variable lastW1f = LJZ_WfreeFromEff(wi1, ResH)
    Variable lastW2f = LJZ_WfreeFromEff(wi2, ResH)
    Variable lastWSf = max(lastW1f, lastW2f)
    Variable hasHistory = 0

    Variable lastC0 = 0
    Variable lastC1 = 0
    Variable lastC2 = 0
    Variable hasBGHistory = 0

    String hold2P_main  = LJZ_HoldMask(12, hdx1=6, hdx2=10, hdx3=11)
    String hold2P_retry = LJZ_HoldMask(12, hdx1=6, hdx2=10, hdx3=11)
    String hold1P       = LJZ_HoldMask(8,  hdx1=2, hdx2=6, hdx3=7)

    Variable forceSingle = 0

    Variable frameIdx
    for (frameIdx = 0; frameIdx < nt; frameIdx += 1)

        Wave/Z mdc_wave = $(runDF + "mdc_show_" + Num2Str(frameIdx))
        if (!WaveExists(mdc_wave))
            continue
        endif

        Duplicate/O mdc_wave, $("layer_show_" + Num2Str(frameIdx))

        Variable seed1
        Variable seed2
        if (hasHistory)
            seed1 = lastK1
            seed2 = lastK2
        else
            seed1 = target1
            seed2 = target2
        endif

        Variable idxSeed1 = round((seed1 - y0) / dy)
        Variable idxSeed2 = round((seed2 - y0) / dy)
        idxSeed1 = max(0, min(ny - 1, idxSeed1))
        idxSeed2 = max(0, min(ny - 1, idxSeed2))

        Variable idxMin = min(idxSeed1, idxSeed2)
        Variable idxMax = max(idxSeed1, idxSeed2)

        Variable roiStart = max(0, idxMin - fdta - ddta)
        Variable roiEnd   = min(ny - 1, idxMax + bdta + ddta)

        Variable npts = roiEnd - roiStart + 1
        if (npts < 7)
            continue
        endif

        Make/O/N=(npts) wROI
        wROI = mdc_wave[roiStart + p]

        Variable xROI0 = y0 + roiStart * dy
        Variable dxROI = dy
        Variable xminROI = min(xROI0, xROI0 + (npts - 1) * dxROI)
        Variable xmaxROI = max(xROI0, xROI0 + (npts - 1) * dxROI)
        Variable xCenter = 0.5 * (xminROI + xmaxROI)

        SetScale/P x, (xROI0 - xCenter), dxROI, wROI

        Variable xminU = xminROI - xCenter
        Variable xmaxU = xmaxROI - xCenter
        Variable roiSpan = abs((npts - 1) * dxROI)

        Variable seed1U = seed1 - xCenter
        Variable seed2U = seed2 - xCenter

        Make/FREE/N=4 guessOut = NaN
        LJZ_SmartGuess_Doublet_RA_Snap_NoSmooth(wROI, seed1U, seed2U, ResH, guessOut)

        Variable gPos1U = LJZ_Clamp(guessOut[0], xminU, xmaxU)
        Variable gPos2U = LJZ_Clamp(guessOut[1], xminU, xmaxU)
        Variable gHabs1 = guessOut[2]
        Variable gHabs2 = guessOut[3]

        Variable isMerged = 0
        if (abs(gPos1U - gPos2U) < 2 * max(abs(dxROI), ResH))
            isMerged = 1
        endif

        Variable fitSuccess = 0
        Variable doDoubleNow = 0
        if (forceSingle == 0 && isMerged == 0)
            doDoubleNow = 1
        endif

        if (doDoubleNow)

            Variable bg0 = 0
            Variable aSpan = max(1e-9, WaveMax(wROI) - bg0)

            Variable H10 = gHabs1 - bg0
            Variable H20 = gHabs2 - bg0
            if (numtype(H10) != 0 || H10 <= 0)
                H10 = 0.55 * aSpan
            endif
            if (numtype(H20) != 0 || H20 <= 0)
                H20 = 0.35 * aSpan
            endif

            Variable w1f0
            Variable w2f0
            if (hasHistory)
                w1f0 = lastW1f
                w2f0 = lastW2f
            else
                w1f0 = LJZ_WfreeFromEff(wi1, ResH)
                w2f0 = LJZ_WfreeFromEff(wi2, ResH)
            endif
            w1f0 = max(1e-12, w1f0)
            w2f0 = max(1e-12, w2f0)

            gGateReason = ""

            coef_wave = 0
            if (hasBGHistory)
                coef_wave[0] = lastC0
                coef_wave[1] = lastC1
                coef_wave[2] = lastC2
            else
                coef_wave[0] = 0
                coef_wave[1] = 0
                coef_wave[2] = 0
            endif

            coef_wave[3]  = max(1e-9, H10)
            coef_wave[4]  = gPos1U
            coef_wave[5]  = w1f0
            coef_wave[6]  = 0.8
            coef_wave[7]  = max(1e-9, H20)
            coef_wave[8]  = gPos2U
            coef_wave[9]  = w2f0
            coef_wave[10] = 0.8
            coef_wave[11] = ResH

            KillWaves/Z W_sigma
            Duplicate/O wROI, $("fit_layer_" + Num2Str(frameIdx))
            FuncFit/Q/H=hold2P_main/NTHR=0 two_pv_ljz, coef_wave, wROI /D=$("fit_layer_" + Num2Str(frameIdx))

            fitSuccess = LJZ_Check2P_ResultAndStore_BGFree_UCenter_RA(wROI, coef_wave, Peak1K, Peak2K, SigmaP1K, SigmaP2K, AreaP1K, AreaP2K, AreaSum12K, Sep12K, WeffP1K, WeffP2K, frameIdx, xminU, xmaxU, roiSpan, dxROI, ResH, xCenter, lastK1, lastK2)

            if (fitSuccess == 0)

                gGateReason = ""

                Variable rgPos1U = LJZ_Clamp(seed1U, xminU, xmaxU)
                Variable rgPos2U = LJZ_Clamp(seed2U, xminU, xmaxU)
                if (rgPos1U > rgPos2U)
                    Variable ttmp
                    ttmp = rgPos1U
                    rgPos1U = rgPos2U
                    rgPos2U = ttmp
                endif

                Variable i1r = LJZ_X2Idx_Clamp_Local(wROI, rgPos1U)
                Variable i2r = LJZ_X2Idx_Clamp_Local(wROI, rgPos2U)

                Variable Hr1 = wROI[i1r]
                Variable Hr2 = wROI[i2r]
                if (numtype(Hr1) != 0 || Hr1 <= 0)
                    Hr1 = 0.55 * aSpan
                endif
                if (numtype(Hr2) != 0 || Hr2 <= 0)
                    Hr2 = 0.35 * aSpan
                endif

                Variable wSafe = max(w1f0, w2f0)

                coef_wave = 0
                if (hasBGHistory)
                    coef_wave[0] = lastC0
                    coef_wave[1] = lastC1
                    coef_wave[2] = lastC2
                else
                    coef_wave[0] = 0
                    coef_wave[1] = 0
                    coef_wave[2] = 0
                endif

                coef_wave[3]  = max(1e-9, Hr1)
                coef_wave[4]  = rgPos1U
                coef_wave[5]  = max(1e-12, wSafe)
                coef_wave[6]  = 0.8
                coef_wave[7]  = max(1e-9, Hr2)
                coef_wave[8]  = rgPos2U
                coef_wave[9]  = max(1e-12, wSafe)
                coef_wave[10] = 0.8
                coef_wave[11] = ResH

                KillWaves/Z W_sigma
                Duplicate/O wROI, $("fit_layer_" + Num2Str(frameIdx))
                FuncFit/Q/H=hold2P_retry/NTHR=0 two_pv_ljz, coef_wave, wROI /D=$("fit_layer_" + Num2Str(frameIdx))

                fitSuccess = LJZ_Check2P_ResultAndStore_BGFree_UCenter_RA(wROI, coef_wave, Peak1K, Peak2K, SigmaP1K, SigmaP2K, AreaP1K, AreaP2K, AreaSum12K, Sep12K, WeffP1K, WeffP2K, frameIdx, xminU, xmaxU, roiSpan, dxROI, ResH, xCenter, lastK1, lastK2)
            endif

            if (fitSuccess)

                lastK1 = alphaPos * Peak1K[frameIdx] + (1 - alphaPos) * lastK1
                lastK2 = alphaPos * Peak2K[frameIdx] + (1 - alphaPos) * lastK2

                lastW1f = alphaWid * max(0, coef_wave[5]) + (1 - alphaWid) * lastW1f
                lastW2f = alphaWid * max(0, coef_wave[9]) + (1 - alphaWid) * lastW2f
                lastWSf = max(lastW1f, lastW2f)
                hasHistory = 1

                lastC0 = coef_wave[0]
                lastC1 = coef_wave[1]
                lastC2 = coef_wave[2]
                hasBGHistory = 1

                BG_c0[frameIdx] = lastC0
                BG_c1[frameIdx] = lastC1
                BG_c2[frameIdx] = lastC2

            else
                forceSingle = 1
            endif

        endif

        // Fallback to Single Peak Fit (Improved)
        // =========================================================
        if (fitSuccess == 0)

            // 1. 改进猜测逻辑 (Smart Guess)
            Variable bestGuessU
            
            // 如果有双峰的历史记录，单峰很可能位于之前的两个峰之间，或者在这个 ROI 的中心
            if (hasHistory)
                // 尝试取之前两个峰的平均位置作为单峰的种子
                bestGuessU = (lastK1 + lastK2) / 2 - xCenter 
            else
                // 如果没有历史，使用之前的 seed2 或者 ROI 中心
                bestGuessU = seed2U
            endif
            
            // 钳位在 ROI 范围内
            bestGuessU = LJZ_Clamp(bestGuessU, xminU, xmaxU)

            // 只有当最大值非常显著且离猜测位置不远时，才去抓最大值
            // 防止抓到边缘的噪点
            Variable iMax = 0
            Variable vMax = -1e9
            Variable idxLoop
            for (idxLoop = 0; idxLoop < npts; idxLoop += 1)
                if (wROI[idxLoop] > vMax)
                    vMax = wROI[idxLoop]
                    iMax = idxLoop
                endif
            endfor
            Variable uAtMax = DimOffset(wROI,0) + iMax * DimDelta(wROI,0)
            
            // 只有当最大值位置离原来的猜测不算太远（比如在 1/3 ROI 范围内），才采纳最大值
            // 否则坚持使用基于历史的猜测
            if (abs(uAtMax - bestGuessU) < 0.33 * roiSpan)
                 bestGuessU = uAtMax
            endif

            cfw = 0
            if (hasBGHistory)
                cfw[0] = lastC0
                cfw[1] = lastC1
                cfw[2] = lastC2
            else
                cfw[0] = 0
                cfw[1] = 0
                cfw[2] = 0
            endif

            Variable aSpanS = max(1e-9, WaveMax(wROI))

            cfw[3] = 0.65 * aSpanS
            cfw[4] = LJZ_Clamp(bestGuessU, xminU, xmaxU)

            Variable wSf0
            if (hasHistory)
                wSf0 = lastWSf
            else
                wSf0 = LJZ_WfreeFromEff(max(wi1, wi2), ResH)
            endif
            // 限制初始宽度不要太离谱
            cfw[5] = max(1e-12, wSf0) 
            cfw[6] = 0.8
            cfw[7] = ResH

            KillWaves/Z W_sigma
            Duplicate/O wROI, $("fit_layer_" + Num2Str(frameIdx))
            
            // 执行单峰拟合
            FuncFit/Q/H=hold1P/NTHR=0 one_pv_ljz, cfw, wROI /D=$("fit_layer_" + Num2Str(frameIdx))
            
            // 2. 增加单峰结果检查 (Sanity Check for Single Peak)
            // ---------------------------------------------------------
            Variable sPeakPos = cfw[4]
            Variable sPeakWid = max(0, cfw[5]) // 确保宽度为正
            Variable sPeakH   = cfw[3]
            Variable isSingleOK = 1
            
            // 检查 A: 位置是否在 ROI 内 (允许稍微超出一点点，比如 10%)
            if (sPeakPos < xminU - 0.1*roiSpan || sPeakPos > xmaxU + 0.1*roiSpan)
                isSingleOK = 0
            endif
            
            // 检查 B: 宽度是否太离谱 (太接近 0 或 超过整个 ROI)
            if (sPeakWid < 1e-4 || sPeakWid > 1.5 * roiSpan)
                isSingleOK = 0
            endif
            
            // 检查 C: 高度是否为负
            if (sPeakH <= 0)
                isSingleOK = 0
            endif

            // 3. 只有检查通过才写入结果和更新历史
            // ---------------------------------------------------------
            if (isSingleOK)
                Peak3K[frameIdx] = sPeakPos + xCenter

                Wave/Z sigmaW2 = $("W_sigma")
                if (WaveExists(sigmaW2) && DimSize(sigmaW2,0) >= 8)
                    SigmaP3K[frameIdx] = sigmaW2[4]
                else
                    SigmaP3K[frameIdx] = NaN
                endif

                // 计算面积和有效宽度
                AreaP3K[frameIdx] = LJZ_PVArea_FromCoef(cfw[3], cfw[5], cfw[6], cfw[7])
                WeffP3K[frameIdx] = LJZ_HWHM_eff(max(0, cfw[5]), max(0, cfw[7]))

                // 更新历史 (加入平滑因子)
                lastWSf = alphaWid * sPeakWid + (1 - alphaWid) * lastWSf
                hasHistory = 1

                lastC0 = cfw[0]
                lastC1 = cfw[1]
                lastC2 = cfw[2]
                hasBGHistory = 1
                
                BG_c0[frameIdx] = lastC0
                BG_c1[frameIdx] = lastC1
                BG_c2[frameIdx] = lastC2
                
                // 如果是从双峰强制转过来的，更新 lastK1/K2 为当前单峰位置，避免下次跳跃
                if (forceSingle)
                    lastK1 = Peak3K[frameIdx]
                    lastK2 = Peak3K[frameIdx] 
                endif
            else
                // 拟合失败的处理：写入 NaN 或者沿用上一帧
                // 这里选择写入 NaN，并在图上断开，提示用户这里没拟合好
                Peak3K[frameIdx]   = NaN 
                SigmaP3K[frameIdx] = NaN
                AreaP3K[frameIdx]  = NaN
                WeffP3K[frameIdx]  = NaN
                
                // 【关键】不要更新历史 (lastWSf, lastK)，
                // 这样下一帧会继续使用上一次“成功”的历史作为种子，而不是这次飞掉的值。
            endif

        endif
        if (frameIdx == 0)
            Display/N=$wOlap $("layer_show_" + Num2Str(frameIdx))
            Label left, "Intensity (a.u.)"
            Label bottom, "Angle (degree)"
        else
            AppendToGraph $("layer_show_" + Num2Str(frameIdx))
            ModifyGraph offset($("layer_show_" + Num2Str(frameIdx))) = {0, frameIdx * kvary}
        endif

        Wave/Z fW = $("fit_layer_" + Num2Str(frameIdx))
        if (WaveExists(fW))
            Variable f_x0_u = DimOffset(fW,0)
            Variable f_dx_u = DimDelta(fW,0)
            SetScale/P x, (f_x0_u + xCenter), f_dx_u, fW

            AppendToGraph/C=(0,65535,0) fW
            ModifyGraph offset($NameOfWave(fW)) = {0, frameIdx * kvary}
        endif

        KillWaves/Z wROI

    endfor

    Display/N=$wTLF Peak1K
    AppendToGraph Peak2K
    AppendToGraph Peak3K

    ModifyGraph mode=3
    ModifyGraph marker=19
    ModifyGraph msize=2
    ModifyGraph rgb(Peak1K)=(65535,0,0)
    ModifyGraph rgb(Peak2K)=(0,0,65535)
    ModifyGraph rgb(Peak3K)=(0,0,0)

    ErrorBars/RGB=(65535,0,0) Peak1K Y, wave=(SigmaP1K, SigmaP1K)
    ErrorBars/RGB=(0,0,65535) Peak2K Y, wave=(SigmaP2K, SigmaP2K)
    ErrorBars/RGB=(0,0,0) Peak3K Y, wave=(SigmaP3K, SigmaP3K)

    Label left, "Momentum / Angle"
    if (uz == 0)
        Label bottom, "Delay Time (ps)"
    endif
    if (uz == 1)
        Label bottom, "Temperature (K)"
    endif
    if (uz == 2)
        Label bottom, "Fluence (uJ/cm\\S2\\M)"
    endif
    if (uz != 0 && uz != 1 && uz != 2)
        Label bottom, "Frame Index"
    endif

    KillWaves/Z coef_wave
    KillWaves/Z cfw
    KillWaves/Z W_sigma
    SetDataFolder saveDF
    return 0
End




// ============================================================================
//  Gate (BGFree + UCenter)
//  - 在 u 坐标里检查；成功后写入 Peak1K/2K（加回 xCenter）
//  - 交换组保证 x1<x2（仍在 u）
//  - needSep + W_sigma 门禁（缺 sigma 不判死）
// ============================================================================

Function LJZ_Check2P_ResultAndStore_BGFree_UCenter_RA(wROI, coef_wave, Peak1K, Peak2K, SigmaP1K, SigmaP2K, AreaP1K, AreaP2K, AreaSum12K, Sep12K, WeffP1K, WeffP2K, frameIdx, xminU, xmaxU, roiSpan, dxROI, ResH, xCenter, refK1, refK2)
    Wave wROI
    Wave coef_wave
    Wave Peak1K, Peak2K, SigmaP1K, SigmaP2K
    Wave AreaP1K, AreaP2K, AreaSum12K, Sep12K
    Wave WeffP1K, WeffP2K
    Variable frameIdx, xminU, xmaxU, roiSpan, dxROI, ResH, xCenter, refK1, refK2

    SVAR gGateReason = root:ARPES_LJZ:MDCFit:gLastGateReason
    gGateReason = ""

    Variable dxA = abs(dxROI)
    Variable ok = 1

    Variable H1  = coef_wave[3]
    Variable x1u = coef_wave[4]
    Variable w1f = max(0, coef_wave[5])
    Variable eta1 = coef_wave[6]

    Variable H2  = coef_wave[7]
    Variable x2u = coef_wave[8]
    Variable w2f = max(0, coef_wave[9])
    Variable eta2 = coef_wave[10]

    Variable resFit = coef_wave[11]
    if (numtype(resFit) != 0 || resFit < 0)
        resFit = ResH
    endif

    Variable s1 = LJZ_HWHM_eff(w1f, resFit)
    Variable s2 = LJZ_HWHM_eff(w2f, resFit)

    if (numtype(x1u) == 0 && numtype(x2u) == 0 && x1u > x2u)

        Variable tmp
        tmp = coef_wave[3]
        coef_wave[3] = coef_wave[7]
        coef_wave[7] = tmp

        tmp = coef_wave[4]
        coef_wave[4] = coef_wave[8]
        coef_wave[8] = tmp

        tmp = coef_wave[5]
        coef_wave[5] = coef_wave[9]
        coef_wave[9] = tmp

        tmp = coef_wave[6]
        coef_wave[6] = coef_wave[10]
        coef_wave[10] = tmp

        H1  = coef_wave[3]
        x1u = coef_wave[4]
        w1f = max(0, coef_wave[5])
        eta1 = coef_wave[6]

        H2  = coef_wave[7]
        x2u = coef_wave[8]
        w2f = max(0, coef_wave[9])
        eta2 = coef_wave[10]

        s1 = LJZ_HWHM_eff(w1f, resFit)
        s2 = LJZ_HWHM_eff(w2f, resFit)
    endif

    NVAR/Z vfe = V_FitError
    if (NVAR_Exists(vfe) && vfe != 0)
        ok = 0
        gGateReason += "V_FitError=" + Num2Str(vfe) + ";"
    endif

    NVAR/Z vfq = V_FitQuitReason
    if (NVAR_Exists(vfq) && vfq != 0)
        ok = 0
        gGateReason += "V_FitQuitReason=" + Num2Str(vfq) + ";"
    endif

    if (!(numtype(x1u)==0 && numtype(x2u)==0 && numtype(H1)==0 && numtype(H2)==0))
        ok = 0
        gGateReason += "NAN_PARAM;"
    endif

    if (!(x1u >= xminU && x1u <= xmaxU && x2u >= xminU && x2u <= xmaxU))
        ok = 0
        gGateReason += "OUTSIDE_ROI;"
    endif

    if (H1 <= 0 || H2 <= 0)
        ok = 0
        gGateReason += "NEG_HEIGHT;"
    endif

    if (s1 <= 0 || s2 <= 0)
        ok = 0
        gGateReason += "BAD_WIDTH<=0;"
    endif
    if (s1 > 0.6*roiSpan || s2 > 0.6*roiSpan)
        ok = 0
        gGateReason += "WIDTH_TOO_BIG;"
    endif

    Variable sep = abs(x2u - x1u)
    Variable needSep = max(ResH, 3*dxA)
    if (sep < needSep)
        ok = 0
        gGateReason += "TOO_CLOSE;"
    endif
    // -------------------------
    // Jump gate: reject abnormal frame-to-frame jump
    // use global coordinates
    // -------------------------
    Variable x1g = x1u + xCenter
    Variable x2g = x2u + xCenter

    if (ok && frameIdx > 0)
        Variable jumpThr = 0.5      // 你要求“超过1就不接受”

        if (numtype(refK1) == 0)
            if (abs(x1g - refK1) > jumpThr)
                ok = 0
                gGateReason += "JUMP_X1_TOO_BIG;"
            endif
        endif

        if (numtype(refK2) == 0)
            if (abs(x2g - refK2) > jumpThr)
                ok = 0
                gGateReason += "JUMP_X2_TOO_BIG;"
            endif
        endif
    endif
    Wave/Z sigmaW = $("W_sigma")
    if (WaveExists(sigmaW) && DimSize(sigmaW,0) >= 12)

        Variable sx1 = sigmaW[4]
        Variable sx2 = sigmaW[8]

        Variable sx1thr = max(0.2*s1, 0.5*dxA)
        Variable sx2thr = max(0.2*s2, 0.5*dxA)

        if (!(numtype(sx1)==0 && numtype(sx2)==0))
            ok = 0
            gGateReason += "SIGMA_NAN;"
        else
            if (sx1 > sx1thr || sx2 > sx2thr)
                ok = 0
                gGateReason += "SIGMA_TOO_BIG;"
            endif
        endif
    else
        gGateReason += "NO_SIGMA;"
    endif

    if (ok)

        Peak1K[frameIdx] = x1u + xCenter
        Peak2K[frameIdx] = x2u + xCenter

        if (WaveExists(sigmaW) && DimSize(sigmaW,0) >= 12)
            SigmaP1K[frameIdx] = sigmaW[4]
            SigmaP2K[frameIdx] = sigmaW[8]
        else
            SigmaP1K[frameIdx] = NaN
            SigmaP2K[frameIdx] = NaN
        endif

        // ---- NEW: write widths, sep, areas ----
        WeffP1K[frameIdx] = s1
        WeffP2K[frameIdx] = s2

        Sep12K[frameIdx] = abs(Peak2K[frameIdx] - Peak1K[frameIdx])

        AreaP1K[frameIdx] = LJZ_PVArea_FromCoef(H1, w1f, eta1, resFit)
        AreaP2K[frameIdx] = LJZ_PVArea_FromCoef(H2, w2f, eta2, resFit)
        AreaSum12K[frameIdx] = AreaP1K[frameIdx] + AreaP2K[frameIdx]

        gGateReason = "OK"
        return 1
    endif

    if (strlen(gGateReason) == 0)
        gGateReason = "UNKNOWN_FAIL"
    endif

    return 0
End




// ============================================================================
//  SmartGuess 双峰（无 Smooth；输入已 Smooth 过）
//  输出 wOut: [pos1, pos2, heightAtPos1, heightAtPos2]
//  注意：这里的 seed/pos 全都是 “当前 wave 的 x 轴坐标”，
//        所以你在主函数里给它的是 seedU，它就会在 u 坐标下工作。
// ============================================================================

Function LJZ_SmartGuess_Doublet_RA_Snap_NoSmooth(wSrc, seed1, seed2, ResH, wOut)
    Wave wSrc
    Variable seed1, seed2, ResH
    Wave wOut

    Variable npt = numpnts(wSrc)
    Variable x0  = DimOffset(wSrc, 0)
    Variable dx  = DimDelta(wSrc, 0)
    Variable dxA = abs(dx)

    wOut[0] = seed1
    wOut[1] = seed2
    wOut[2] = wSrc[LJZ_X2Idx_Clamp_Local(wSrc, seed1)]
    wOut[3] = wSrc[LJZ_X2Idx_Clamp_Local(wSrc, seed2)]

    if (npt < 9)
        return 0
    endif
    if (numtype(dx) != 0 || dx == 0)
        return 0
    endif

    Variable maxSnap = max(10 * dxA, 5 * ResH)

    Duplicate/FREE wSrc, wD2
    Differentiate/METH=2 wD2
    Differentiate/METH=2 wD2

    Variable thr = 0.05 * WaveMax(wSrc)

    Make/FREE/N=40 candX = NaN
    Make/FREE/N=40 candH = NaN
    Variable count = 0
    Variable i
    for (i = 2; i < npt - 2; i += 1)
        if (wD2[i] < wD2[i - 1] && wD2[i] < wD2[i + 1] && wD2[i] < 0)
            if (wSrc[i] > thr)
                candX[count] = x0 + i * dx
                candH[count] = wSrc[i]
                count += 1
                if (count >= 40)
                    break
                endif
            endif
        endif
    endfor

    if (count <= 0)
        Variable win = max(0.8, 6 * dxA)
        Variable bx, by
        LJZ_LocalMaxNearSeed_Local(wSrc, seed1, win, bx, by)
        wOut[0] = bx
        wOut[2] = by
        LJZ_LocalMaxNearSeed_Local(wSrc, seed2, win, bx, by)
        wOut[1] = bx
        wOut[3] = by
        return 0
    endif

    Variable best1 = -1
    Variable best2 = -1
    Variable bestD1 = 1e30
    Variable bestD2 = 1e30
    Variable j
    for (j = 0; j < count; j += 1)
        Variable d1 = abs(candX[j] - seed1)
        if (d1 < bestD1)
            bestD1 = d1
            best1 = j
        endif

        Variable d2 = abs(candX[j] - seed2)
        if (d2 < bestD2)
            bestD2 = d2
            best2 = j
        endif
    endfor

    if (best1 >= 0 && bestD1 <= maxSnap)
        wOut[0] = candX[best1]
        wOut[2] = candH[best1]
    endif
    if (best2 >= 0 && bestD2 <= maxSnap)
        wOut[1] = candX[best2]
        wOut[3] = candH[best2]
    endif

    if (best1 == best2 && best1 >= 0)
        wOut[1] = seed2
        wOut[3] = wSrc[LJZ_X2Idx_Clamp_Local(wSrc, seed2)]
    endif

    Variable minSep = 1.6 * max(dxA, ResH)
    if (abs(wOut[0] - wOut[1]) < minSep)
        Variable push = (seed2 < seed1) ? (-minSep) : (minSep)
        wOut[1] = wOut[0] + push
        wOut[3] = 0.7 * wOut[2]
    endif

    return 0
End



// ============================================================================
//  Local helpers
// ============================================================================

Function LJZ_X2Idx_Clamp_Local(w, x)
    Wave w
    Variable x

    Variable npt = numpnts(w)
    Variable t = x2pnt(w, x)
    Variable idx = round(t)

    if (idx < 0)
        idx = 0
    endif
    if (idx > npt - 1)
        idx = npt - 1
    endif

    return idx
End

Function LJZ_LocalMaxNearSeed_Local(w, seed, win, bestX, bestY)
    Wave w
    Variable seed, win
    Variable &bestX, &bestY

    Variable n = numpnts(w)
    Variable x0 = DimOffset(w, 0)
    Variable dx = DimDelta(w, 0)

    Variable i0 = LJZ_X2Idx_Clamp_Local(w, seed - win)
    Variable i1 = LJZ_X2Idx_Clamp_Local(w, seed + win)

    if (i1 < i0)
        Variable t = i0
        i0 = i1
        i1 = t
    endif

    Variable imax = i0
    Variable vbest = w[i0]
    Variable i

    for (i = i0; i <= i1; i += 1)
        if (w[i] > vbest)
            vbest = w[i]
            imax = i
        endif
    endfor

    bestX = x0 + imax * dx
    bestY = vbest
    return 0
End







// ============================================================================
//  极简版：不拟合，只“找点/巡点”
//  - 逻辑：每帧在 seed1/seed2 附近各找一个局部最大 -> 得到候选 2 点
//          若两个点太近/弱点不显著 -> 认为单峰，写 Peak3K
//          否则写 Peak1K/Peak2K
//  - 叠图：每帧画原曲线 + 红点(p1) + 蓝点(p2) 或 黑点(p3)
//  - 输出：Peak1K Peak2K Peak3K (+ Sigma waves 置 NaN) FitMode=2(双峰)/1(单峰)/0(失败)
// ============================================================================


// 边缘估 baseline + noise
Function LJZ_EdgeMeanSigma(w, nEdge, meanOut, sigOut)
    Wave w
    Variable nEdge
    Variable &meanOut, &sigOut

    Variable n=numpnts(w)
    nEdge = max(2, min(nEdge, floor(n/3)))

    Variable s=0, s2=0, cnt=0, i, v
    for (i=0; i<nEdge; i+=1)
        v=w[i]
        if (numtype(v)==0)
            s+=v; s2+=v*v; cnt+=1
        endif
    endfor
    for (i=0; i<nEdge; i+=1)
        v=w[n-1-i]
        if (numtype(v)==0)
            s+=v; s2+=v*v; cnt+=1
        endif
    endfor

    if (cnt<=2)
        meanOut=0; sigOut=0
        return 0
    endif

    meanOut = s/cnt
    sigOut = sqrt(max(0, s2/cnt - meanOut*meanOut))
    return 0
End

// 用一阶差分估计噪声 sigma（对背景斜率/慢变趋势更鲁棒）
Function LJZ_NoiseSigma_Diff(w, i0, i1, sigOut)
    Wave w
    Variable i0, i1
    Variable &sigOut

    sigOut = 0
    Variable n = numpnts(w)
    i0 = max(0, min(n-2, i0))
    i1 = max(1, min(n-1, i1))
    if (i1 <= i0+2)
        return 0
    endif

    Make/FREE/N=(i1-i0) d
    d = w[i0+p+1] - w[i0+p]

    // 用 RMS 估计差分噪声，再除 sqrt(2)
    WaveStats/Q d
    sigOut = V_sdev / sqrt(2)
    sigOut = max(sigOut, 1e-12)
    return 0
End


// ============================================================================
//  主函数（极简 pick 版）
// ============================================================================

// ============================================================================
//  主函数（极简 pick + tracking seed 版，不做非线性拟合）
// ============================================================================
Function MDC_NdSb_LJZ_PT_UC(runDF, Kpeak1, Kpeak2, ResH, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio)
    String   runDF
    Variable Kpeak1, Kpeak2, ResH, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio

    String saveDF = GetDataFolder(1)

    LJZ_EnsureMDCFitDF()
    runDF = RemoveEnding(runDF, ":") + ":"

    // ---- count frames ----
    Variable nt = 0
    do
        Wave/Z wTest = $(runDF + "mdc_show_" + Num2Str(nt))
        if (!WaveExists(wTest))
            break
        endif
        nt += 1
    while(1)

    if (nt <= 0)
        DoAlert 0, "PeakPick_UC: runDF 下找不到 mdc_show_0"
        SetDataFolder saveDF
        return -1
    endif

    Wave w0 = $(runDF + "mdc_show_0")
    Variable dy = DimDelta(w0,0)
    if (numtype(dy)!=0 || dy==0)
        DoAlert 0, "PeakPick_UC: DimDelta 非法"
        SetDataFolder saveDF
        return -1
    endif
    Variable dyA = abs(dy)

    // ---- x scale for output ----
    Variable t0=0, dt=1
    NVAR/Z g_t0 = root:ARPES_LJZ:MDCFit:Run_t0
    NVAR/Z g_dt = root:ARPES_LJZ:MDCFit:Run_dt
    if (NVAR_Exists(g_t0) && numtype(g_t0)==0)
        t0=g_t0
    endif
    if (NVAR_Exists(g_dt) && numtype(g_dt)==0 && g_dt!=0)
        dt=g_dt
    endif

    // ---- output folder ----
    String fitDF = runDF + "FIT_PT:"
    String fitDF0 = RemoveEnding(fitDF, ":")
    NewDataFolder/O $fitDF0
    SetDataFolder $fitDF0

    // ---- outputs ----
    Make/O/N=(nt) Peak1K, Peak2K, Peak3K
    Make/O/N=(nt) SigmaP1K, SigmaP2K, SigmaP3K
    Make/O/N=(nt) FitMode
    
    // ---- NEW outputs: height / width / area / uncertainties (no fit) ----
    Make/O/N=(nt) HgtP1K, HgtP2K, HgtP3K
    Make/O/N=(nt) FwhmP1K, FwhmP2K, FwhmP3K
    Make/O/N=(nt) AreaP1K, AreaP2K, AreaP3K
    Make/O/N=(nt) dXP1K, dXP2K, dXP3K
    Make/O/N=(nt) dHP1K, dHP2K, dHP3K
    Make/O/N=(nt) dAP1K, dAP2K, dAP3K

    HgtP1K=NaN; HgtP2K=NaN; HgtP3K=NaN
    FwhmP1K=NaN; FwhmP2K=NaN; FwhmP3K=NaN
    AreaP1K=NaN; AreaP2K=NaN; AreaP3K=NaN
    dXP1K=NaN; dXP2K=NaN; dXP3K=NaN
    dHP1K=NaN; dHP2K=NaN; dHP3K=NaN
    dAP1K=NaN; dAP2K=NaN; dAP3K=NaN

    Peak1K=NaN; Peak2K=NaN; Peak3K=NaN
    SigmaP1K=NaN; SigmaP2K=NaN; SigmaP3K=NaN
    FitMode=0

    SetScale/P x, t0, dt, Peak1K, Peak2K, Peak3K
    SetScale/P x, t0, dt, SigmaP1K, SigmaP2K, SigmaP3K
    SetScale/P x, t0, dt, FitMode
    SetScale/P x, t0, dt, HgtP1K, HgtP2K, HgtP3K
    SetScale/P x, t0, dt, FwhmP1K, FwhmP2K, FwhmP3K
    SetScale/P x, t0, dt, AreaP1K, AreaP2K, AreaP3K
    SetScale/P x, t0, dt, dXP1K, dXP2K, dXP3K
    SetScale/P x, t0, dt, dHP1K, dHP2K, dHP3K
    SetScale/P x, t0, dt, dAP1K, dAP2K, dAP3K

    SVAR bn = root:ARPES_LJZ:MDCFit:gBaseName
    String bnTag = bn
    if (strlen(bnTag) == 0)
        bnTag = runDF
    endif
    
    // ---- window names ----
    bnTag = CleanupName(bnTag, 0)
	String wOlap = "MDC_Olap_PT_" + bnTag
	String wTLF  = "MDC_Traj_PT_" + bnTag
    KillWindow/Z $wOlap
    KillWindow/Z $wTLF

    // ---- params ----
    if (numtype(ddta)!=0 || ddta<0)
        ddta = 10
    endif

    Variable nSmooth = 7                 // 7/9/11
    Variable weakThrSig = 0.8           // 关键：你那帧弱峰~1σ，2.5σ 会必杀
    Variable doSyn = 0                   // 1=生成每帧合成曲线 synFull_#, 0=不生成
    
    // tracking seeds (全局坐标，真正有用)
    Variable seed1G = Kpeak1
    Variable seed2Fix = Kpeak2

    // seed 初始间距（用于限制窗口，避免撞车）
    Variable seedSep0 = abs(Kpeak2 - Kpeak1)
    seedSep0 = max(seedSep0, 10*dyA)

    // ---- loop ----
    Variable frameIdx
    for (frameIdx=0; frameIdx<nt; frameIdx+=1)

        Wave/Z mdc = $(runDF + "mdc_show_" + Num2Str(frameIdx))
        if (!WaveExists(mdc))
            continue
        endif

        Variable ny = numpnts(mdc)

        // ---------- 自适应 winPick：足够追踪漂移，但不跨越到另一峰 ----------
        Variable seedSep = abs(seed2Fix - seed1G)
        if (numtype(seedSep)!=0 || seedSep < 5*dyA)
            seedSep = seedSep0
        endif

        Variable winPick = max(40*dyA, 3*ResH)
        // 上限：不允许超过 0.45*seedSep（防止两次寻点撞到同一峰）
        winPick = min(winPick, 0.45*seedSep)

        // 双峰最小分离：不要依赖 ResH 的单位正确性，按 seedSep 比例更稳
        Variable sepNeed = max(3*dyA, 0.8*seedSep)


        // ---------- ROI：围绕当前 seed1G/seed2G（而不是固定 Kpeak1/Kpeak2） ----------
        Variable idx1 = round(x2pnt(mdc, seed1G))
        Variable idx2 = round(x2pnt(mdc, seed2Fix))
        idx1 = max(0, min(ny-1, idx1))
        idx2 = max(0, min(ny-1, idx2))
        Variable iMin=min(idx1,idx2), iMax=max(idx1,idx2)

        Variable roiStart = max(0, iMin - fdta - ddta)
        Variable roiEnd   = min(ny-1, iMax + bdta + ddta)
        Variable npts = roiEnd - roiStart + 1
        if (npts < 9)
            FitMode[frameIdx]=0
            continue
        endif

        Make/FREE/N=(npts) wROI
        wROI = mdc[roiStart + p]

        // ROI 居中（数值上更稳），但 seed 更新必须在全局坐标做
        Variable xROI0 = DimOffset(mdc,0) + roiStart*dy
        Variable xminROI = min(xROI0, xROI0 + (npts-1)*dy)
        Variable xmaxROI = max(xROI0, xROI0 + (npts-1)*dy)
        Variable xCenter = 0.5*(xminROI + xmaxROI)
        SetScale/P x, (xROI0 - xCenter), dy, wROI

        Variable seed1U = seed1G - xCenter
        Variable seed2U = seed2Fix - xCenter

        // ---------- baseline + noise ----------
        Variable bg=0, tmpSig=0, sig=0
        LJZ_EdgeMeanSigma(wROI, 8, bg, tmpSig)              // bg 够用
        LJZ_NoiseSigma_Diff(wROI, 0, numpnts(wROI)-1, sig)  // sig 用差分估计（鲁棒）

        // ---------- 在两个 seed 附近各巡一个点 ----------
        Variable xA, yA, okA, curvA
        Variable xB, yB, okB, curvB
        LJZ_FindLocalMaxNearSeed_Curv(wROI, seed1U, winPick, nSmooth, xA, yA, curvA, okA)
        LJZ_FindLocalMaxNearSeed_Curv(wROI, seed2U, winPick, nSmooth, xB, yB, curvB, okB)

        if (!(okA && okB))
            FitMode[frameIdx]=0
            continue
        endif

        // 转回全局坐标
        Variable xAg = xA + xCenter
        Variable xBg = xB + xCenter
        Variable aA = yA - bg
        Variable aB = yB - bg

        // 保证 xAg < xBg（仅用于排序；tracking 本身靠 seed，不靠这个）
        if (xAg > xBg)
            Variable tx=xAg; xAg=xBg; xBg=tx
            Variable ta=aA;  aA=aB;  aB=ta
            Variable ty=yA;  yA=yB;  yB=ty
        endif

        Variable sep = abs(xBg - xAg)
        Variable weakAmp = min(aA, aB)

        // ---------- 判断双峰 ----------
        Variable is2P = 1
        if (sep < sepNeed)
            is2P = 0
        endif
        if (weakAmp < weakThrSig*sig)
            is2P = 0
        endif

        if (is2P)
            Peak1K[frameIdx] = xAg
            Peak2K[frameIdx] = xBg
            Peak3K[frameIdx] = NaN
            FitMode[frameIdx] = 2
            
            // ---- NEW: peak metrics on wROI (U coords), then store to *K arrays (global x) ----
            // Heights (use raw wROI interpolation for consistency)
            Variable h1 = wROI(xA) - bg
            Variable h2 = wROI(xB) - bg
            HgtP1K[frameIdx] = (numtype(h1)==0) ? max(0,h1) : NaN
            HgtP2K[frameIdx] = (numtype(h2)==0) ? max(0,h2) : NaN
            HgtP3K[frameIdx] = NaN

            // FWHM (U coords)
            FwhmP1K[frameIdx] = LJZ_FWHM_FromPeak(wROI, xA, bg, winPick)
            FwhmP2K[frameIdx] = LJZ_FWHM_FromPeak(wROI, xB, bg, winPick)
            FwhmP3K[frameIdx] = NaN

            // Area
            Variable Wint1 = (numtype(FwhmP1K[frameIdx])==0) ? (0.75*FwhmP1K[frameIdx]) : max(3*ResH, 8*dyA)
            Variable Wint2 = (numtype(FwhmP2K[frameIdx])==0) ? (0.75*FwhmP2K[frameIdx]) : max(3*ResH, 8*dyA)

            AreaP1K[frameIdx] = LJZ_Area_FromWindow(wROI, xA, bg, Wint1)
            AreaP2K[frameIdx] = LJZ_Area_FromWindow(wROI, xB, bg, Wint2)
            AreaP3K[frameIdx] = NaN

            // Uncertainties
            dXP1K[frameIdx] = LJZ_dX_FromCurv(sig, curvA, dyA, winPick)
            dXP2K[frameIdx] = LJZ_dX_FromCurv(sig, curvB, dyA, winPick)
            dXP3K[frameIdx] = NaN

            dHP1K[frameIdx] = sig
            dHP2K[frameIdx] = sig
            dHP3K[frameIdx] = NaN

            dAP1K[frameIdx] = LJZ_dArea_Window(sig, wROI, xA, Wint1)
            dAP2K[frameIdx] = LJZ_dArea_Window(sig, wROI, xB, Wint2)
            dAP3K[frameIdx] = NaN
            
            // ---- NEW: build synthetic curve (if enabled) ----
            if (doSyn)
                // 修正1：纯洛伦兹线型
                Variable eta1 = 1
                Variable eta2 = 1

                // 修正2：宽度测量与锁定
                Variable f1 = FwhmP1K[frameIdx]
                if (numtype(f1)!=0 || f1 <= 0)
                    f1 = max(5*dyA, 3*ResH) 
                endif
                
                Variable fwhmScale = 8
                f1 *= fwhmScale
                Variable f2 = f1 

                // 修正3：二次背景拟合
                Variable bg0, bgSlope, bgQuad, A1LS, A2LS
                Variable okLS = LJZ_LS2PV_QuadBG_Op(wROI, xA, f1, eta1, xB, f2, eta2, bg0, bgSlope, bgQuad, A1LS, A2LS)

                if (!okLS)
                    bg0 = bg; bgSlope = 0; bgQuad = 0
                    A1LS = (numtype(HgtP1K[frameIdx])==0) ? HgtP1K[frameIdx] : 0
                    A2LS = (numtype(HgtP2K[frameIdx])==0) ? HgtP2K[frameIdx] : 0
                endif

                HgtP1K[frameIdx] = A1LS
                HgtP2K[frameIdx] = A2LS

                // 生成曲线
                Make/FREE/N=(npts) synROI
                SetScale/P x, (xROI0 - xCenter), dy, synROI 

                synROI = (bg0 + bgSlope*x + bgQuad*x*x) \
                       + A1LS * LJZ_PV_NormSafe(x, xA, f1, eta1) \
                       + A2LS * LJZ_PV_NormSafe(x, xB, f2, eta2)

                String synNameD = "synFull_" + Num2Str(frameIdx)
                KillWaves/Z $synNameD
                Make/O/N=(ny) $synNameD
                Wave synFullD = $synNameD
                SetScale/P x, DimOffset(mdc,0), dy, synFullD
                synFullD = NaN

                Variable ii
                for (ii=0; ii<npts; ii+=1)
                    synFullD[roiStart + ii] = synROI[ii]
                endfor
            endif
            
            // tracking seeds：全局更新（关键）
            seed1G = xAg

        else
            // 单峰：取更强的那个
            Variable xS = xAg
            Variable aS = aA
            Variable xSU = xA     // U coord of chosen single peak
            Variable curvS = curvA
            if (aB > aA)
                xS = xBg
                aS = aB
                xSU = xB
                curvS = curvB
            endif

            Peak3K[frameIdx] = xS
            Peak1K[frameIdx] = NaN
            Peak2K[frameIdx] = NaN
            FitMode[frameIdx] = 1
            
            // ---- NEW: single-peak metrics ----
            HgtP3K[frameIdx] = (numtype(aS)==0) ? max(0,aS) : NaN
            HgtP1K[frameIdx] = NaN
            HgtP2K[frameIdx] = NaN

            FwhmP3K[frameIdx] = LJZ_FWHM_FromPeak(wROI, xSU, bg, winPick)
            FwhmP1K[frameIdx] = NaN
            FwhmP2K[frameIdx] = NaN

            Variable WintS = (numtype(FwhmP3K[frameIdx])==0) ? (0.75*FwhmP3K[frameIdx]) : max(3*ResH, 8*dyA)
            AreaP3K[frameIdx] = LJZ_Area_FromWindow(wROI, xSU, bg, WintS)
            AreaP1K[frameIdx] = NaN
            AreaP2K[frameIdx] = NaN

            dXP3K[frameIdx] = LJZ_dX_FromCurv(sig, curvS, dyA, winPick)
            dXP1K[frameIdx] = NaN
            dXP2K[frameIdx] = NaN

            dHP3K[frameIdx] = sig
            dHP1K[frameIdx] = NaN
            dHP2K[frameIdx] = NaN

            dAP3K[frameIdx] = LJZ_dArea_Window(sig, wROI, xSU, WintS)
            dAP1K[frameIdx] = NaN
            dAP2K[frameIdx] = NaN

            if (doSyn)
                Variable eta1P = 0.5
                Variable f1P = FwhmP3K[frameIdx]
                if (numtype(f1P)!=0 || f1P<=0)
                    f1P = max(3*ResH, 8*dyA)
                endif
                Variable fwhmScale1P = 1.15
                f1P *= fwhmScale1P

                Variable bg1P, A1P
                Variable ok1P = LJZ_LS1PV_ConstBG(wROI, xSU, f1P, eta1P, bg1P, A1P)

                if (!ok1P)
                    bg1P = bg
                    A1P  = max(0, wROI(xSU) - bg)
                endif

                HgtP3K[frameIdx] = A1P

                Make/FREE/N=(npts) synROI1P
                SetScale/P x, (xROI0 - xCenter), dy, synROI1P

                synROI1P = bg1P + A1P*LJZ_PV_NormSafe(x, xSU, f1P, eta1P)

                String synName1P = "synFull_" + Num2Str(frameIdx)
                KillWaves/Z $synName1P
                Make/O/N=(ny) $synName1P
                Wave synFull1P = $synName1P
                SetScale/P x, DimOffset(mdc,0), dy, synFull1P
                synFull1P = NaN

                Variable i1P
                for (i1P=0; i1P<npts; i1P+=1)
                    synFull1P[roiStart + i1P] = synROI1P[i1P]
                endfor
            endif

            // tracking：至少把主峰 seed1G 跟上
            seed1G = xS
        endif

        // ---- marker waves for overlay ----
        KillWaves/Z $("p1_" + Num2Str(frameIdx)), $("p2_" + Num2Str(frameIdx)), $("p3_" + Num2Str(frameIdx))

        if (FitMode[frameIdx]==2)
            Make/O/N=1 $("p1_" + Num2Str(frameIdx))
            Wave p1 = $("p1_" + Num2Str(frameIdx))
            SetScale/P x, Peak1K[frameIdx], 1, p1
            p1[0] = mdc(Peak1K[frameIdx])

            Make/O/N=1 $("p2_" + Num2Str(frameIdx))
            Wave p2 = $("p2_" + Num2Str(frameIdx))
            SetScale/P x, Peak2K[frameIdx], 1, p2
            p2[0] = mdc(Peak2K[frameIdx])
        elseif (FitMode[frameIdx]==1)
            Make/O/N=1 $("p3_" + Num2Str(frameIdx))
            Wave p3 = $("p3_" + Num2Str(frameIdx))
            SetScale/P x, Peak3K[frameIdx], 1, p3
            p3[0] = mdc(Peak3K[frameIdx])
        endif

    endfor

    // ---- overlay plot (最多 80 帧) ----
    Variable showMax = min(nt, 80)
    for (frameIdx=0; frameIdx<showMax; frameIdx+=1)

        Wave/Z mdc = $(runDF + "mdc_show_" + Num2Str(frameIdx))
        if (!WaveExists(mdc))
            continue
        endif

        String layerName = "layer_" + Num2Str(frameIdx)
        Duplicate/O mdc, $layerName

        if (frameIdx==0)
            // 确保先杀掉旧窗口，防止图层叠加混乱
            KillWindow/Z $wOlap 
            Display/N=$wOlap $layerName
            Label left, "Intensity (a.u.)"
            Label bottom, "Angle / k"
            ModifyGraph offset($layerName)={0, 0}
        else
            AppendToGraph $layerName
            ModifyGraph offset($layerName)={0, frameIdx*kvary}
        endif

//        // ---- Synthetic curve (注释掉的部分，保留以备用) ----
//
//        Wave/Z synFull = $("synFull_" + Num2Str(frameIdx))
//        if (WaveExists(synFull))
//            AppendToGraph synFull
//            ModifyGraph offset($NameOfWave(synFull))={0, frameIdx*kvary}
//            ModifyGraph mode($NameOfWave(synFull))=0
//            ModifyGraph lsize($NameOfWave(synFull))=1.2
//            ModifyGraph rgb($NameOfWave(synFull))=(20000,20000,20000)
//        endif


        // ---- markers (修正版：只根据 FitMode 画点，杜绝幽灵点) ----
        
        // 1. 如果是双峰模式，只画 p1 和 p2
        if (FitMode[frameIdx] == 2)
            Wave/Z p1 = $("p1_" + Num2Str(frameIdx))
            if (WaveExists(p1))
                AppendToGraph p1
                ModifyGraph mode($NameOfWave(p1))=3, marker($NameOfWave(p1))=19, msize($NameOfWave(p1))=2
                ModifyGraph rgb($NameOfWave(p1))=(65535,0,0) // 红
                ModifyGraph offset($NameOfWave(p1))={0, frameIdx*kvary}
            endif

            Wave/Z p2 = $("p2_" + Num2Str(frameIdx))
            if (WaveExists(p2))
                AppendToGraph p2
                ModifyGraph mode($NameOfWave(p2))=3, marker($NameOfWave(p2))=19, msize($NameOfWave(p2))=2
                ModifyGraph rgb($NameOfWave(p2))=(0,0,65535) // 蓝
                ModifyGraph offset($NameOfWave(p2))={0, frameIdx*kvary}
            endif

        // 2. 如果是单峰模式，只画 p3
        elseif (FitMode[frameIdx] == 1)
            Wave/Z p3 = $("p3_" + Num2Str(frameIdx))
            if (WaveExists(p3))
                AppendToGraph p3
                ModifyGraph mode($NameOfWave(p3))=3, marker($NameOfWave(p3))=19, msize($NameOfWave(p3))=2
                ModifyGraph rgb($NameOfWave(p3))=(0,0,0)     // 黑
                ModifyGraph offset($NameOfWave(p3))={0, frameIdx*kvary}
            endif
        endif

    endfor

    // ---- trajectory plot ----
    Display/N=$wTLF Peak1K
    AppendToGraph Peak2K
    AppendToGraph Peak3K
    ModifyGraph mode=3, marker=19, msize=2
    ModifyGraph rgb(Peak1K)=(65535,0,0)
    ModifyGraph rgb(Peak2K)=(0,0,65535)
    ModifyGraph rgb(Peak3K)=(0,0,0)

    Label left, "Momentum / Angle"
    if (uz == 0)
        Label bottom, "Delay Time (ps)"
    elseif (uz == 1)
        Label bottom, "Temperature (K)"
    elseif (uz == 2)
        Label bottom, "Fluence (uJ/cm\\S2\\M)"
    else
        Label bottom, "Frame Index"
    endif

    SetDataFolder saveDF
    return 0
End

// ============================================================================
//  Helper: peak finding with curvature output (robust version)
//  修正点：
//  1. 恢复了 Smooth，防止卡在噪声造成的局部极值（肩峰）上。
//  2. 增加了 (yC > yL && yC > yR) 判断，防止在斜坡边缘强行拟合抛物线。
// ============================================================================
Function LJZ_FindLocalMaxNearSeed_Curv(w, xSeed, win, nSmooth, xOut, yOut, curvOut, ok)
    Wave w
    Variable xSeed, win, nSmooth
    Variable &xOut, &yOut, &curvOut, &ok

    ok = 0
    xOut = xSeed
    yOut = NaN
    curvOut = NaN

    Variable n = numpnts(w)
    if (n < 5)
        return 0
    endif

    Variable dx = DimDelta(w,0)
    if (numtype(dx)!=0 || dx==0)
        return 0
    endif

    Duplicate/FREE w, wSm  // 使用 /FREE 自动管理内存
    
    // [修复 1] 必须平滑！否则会卡在 shoulder 的噪声上
    // 如果 nSmooth 未定义或过小，给一个默认值 7
    if (numtype(nSmooth)!=0 || nSmooth < 1)
        nSmooth = 7 
    endif
    nSmooth = round(nSmooth)
    // Box smooth 比较猛，如果想要柔和点可以用 Smooth/B
//    Smooth nSmooth, wSm  

    // 确定搜索范围索引
    Variable i0 = round(x2pnt(wSm, xSeed - abs(win)))
    Variable i1 = round(x2pnt(wSm, xSeed + abs(win)))
    
    // 边界保护：留出左右各 1 个点用于差分计算
    i0 = max(1, min(n-2, i0))
    i1 = max(1, min(n-2, i1))
    if (i1 < i0)
        Variable t=i0; i0=i1; i1=t
    endif

    // 粗搜最大值
    Variable im=i0, vmax=-1e308, ii, v
    for (ii=i0; ii<=i1; ii+=1)
        v = wSm[ii]
        if (numtype(v)==0 && v > vmax)
            vmax = v
            im = ii
        endif
    endfor
    
    if (vmax <= -1e300)
        return 0
    endif

    // 获取三点用于抛物线插值
    Variable yL = wSm[im-1]
    Variable yC = wSm[im]
    Variable yR = wSm[im+1]

    // [修复 2] 核心检查：这真的只是一个斜坡吗？
    // 如果最大值点在窗口边缘，且呈上升/下降趋势，说明峰在窗口外面。
    // 此时强行做抛物线拟合会得到错误的 delta。
    // 我们只接受 "凸" 的形状，或者至少平顶。
    if (yC < yL || yC < yR)
        // 没找到真正的峰（可能峰在窗口外），直接返回粗搜结果，不算 sub-pixel
        xOut = pnt2x(wSm, im)
        yOut = yC
        curvOut = 0 // 这种情况下曲率不可靠
        
        // 这种情况通常意味着 fit 失败或者需要扩大窗口，
        // 但为了程序不崩，我们返回 ok=1 (降级处理) 或者 ok=0 (报错)
        // 这里选择返回边界点，不瞎改位置
        ok = 1 
        return 0
    endif

    // 抛物线插值计算 sub-pixel shift
    // Formula: delta = 0.5 * (yL - yR) / (yL - 2*yC + yR)
    Variable denom = (yL - 2*yC + yR)
    Variable delta = 0
    
    // [修复 3] 数值稳定性检查
    if (numtype(denom)==0 && abs(denom) > 1e-12)
        delta = 0.5 * (yL - yR) / denom
        // 限制 delta 在 +/- 0.5 之间，防止飞出去
        delta = max(-0.5, min(0.5, delta))
    endif

    xOut = pnt2x(wSm, im) + delta*dx
    
    // 抛物线顶点的估算高度 (Height estimation)
    // yPeak = yC - 0.25 * (yL-yR) * delta
    yOut = yC - 0.25 * (yL - yR) * delta

    // 曲率估算 (I'')
    curvOut = denom / (dx*dx)

    ok = 1
    return 0
End


// ============================================================================
//  Helper: FWHM from a peak position (no nonlinear fit)
//  - w must have proper x scale
//  - bg is constant baseline (use your edge mean bg)
//  - win is half-window around peak to search crossing
//  - return NaN if cannot find both sides
// ============================================================================
Function LJZ_FWHM_FromPeak(w, xPeak, bg, win)
    Wave w
    Variable xPeak, bg, win

    Variable dx = DimDelta(w,0)
    if (numtype(dx)!=0 || dx==0)
        return NaN
    endif
    Variable dxA = abs(dx)

    Variable yPk = w(xPeak)
    if (numtype(yPk)!=0)
        return NaN
    endif

    Variable h = yPk - bg
    if (numtype(h)!=0 || h <= 0)
        return NaN
    endif
    Variable yHalf = bg + 0.5*h

    Variable n = numpnts(w)
    Variable idxPk = round(x2pnt(w, xPeak))
    idxPk = max(1, min(n-2, idxPk))

    Variable idxL = round(x2pnt(w, xPeak - abs(win)))
    Variable idxR = round(x2pnt(w, xPeak + abs(win)))
    idxL = max(1, min(n-2, idxL))
    idxR = max(1, min(n-2, idxR))
    if (idxR < idxL)
        Variable tt=idxL; idxL=idxR; idxR=tt
    endif

    // ---- left crossing ----
    Variable xLeft = NaN
    Variable i, y0, y1, x0, x1
    for (i=idxPk; i>=idxL+1; i-=1)
        y0 = w[i]     - yHalf
        y1 = w[i-1]   - yHalf
        if (numtype(y0)==0 && numtype(y1)==0)
            if (y0 >= 0 && y1 <= 0)
                x0 = pnt2x(w, i)
                x1 = pnt2x(w, i-1)
                if (abs(w[i]-w[i-1]) > 1e-30)
                    xLeft = x0 + (yHalf - w[i])*(x1-x0)/(w[i-1]-w[i])
                else
                    xLeft = x0
                endif
                break
            endif
        endif
    endfor

    // ---- right crossing ----
    Variable xRight = NaN
    for (i=idxPk; i<=idxR-1; i+=1)
        y0 = w[i]     - yHalf
        y1 = w[i+1]   - yHalf
        if (numtype(y0)==0 && numtype(y1)==0)
            if (y0 >= 0 && y1 <= 0)
                x0 = pnt2x(w, i)
                x1 = pnt2x(w, i+1)
                if (abs(w[i+1]-w[i]) > 1e-30)
                    xRight = x0 + (yHalf - w[i])*(x1-x0)/(w[i+1]-w[i])
                else
                    xRight = x0
                endif
                break
            endif
        endif
    endfor

    if (numtype(xLeft)!=0 || numtype(xRight)!=0)
        return NaN
    endif

    Variable fwhm = abs(xRight - xLeft)
    if (fwhm < 0.5*dxA)
        return NaN
    endif
    return fwhm
End


// ============================================================================
//  Helper: area by window integration (no nonlinear fit)
//  - integrates (w - bg) within [xPeak-Wint, xPeak+Wint], trapezoid rule
//  - returns NaN if too few points
// ============================================================================
Function LJZ_Area_FromWindow(w, xPeak, bg, Wint)
    Wave w
    Variable xPeak, bg, Wint

    Variable dx = DimDelta(w,0)
    if (numtype(dx)!=0 || dx==0)
        return NaN
    endif
    Variable dxA = abs(dx)

    Variable n = numpnts(w)
    Variable i0 = round(x2pnt(w, xPeak - abs(Wint)))
    Variable i1 = round(x2pnt(w, xPeak + abs(Wint)))
    i0 = max(0, min(n-2, i0))
    i1 = max(1, min(n-1, i1))
    if (i1 <= i0+1)
        return NaN
    endif

    Variable area=0
    Variable i, v0, v1
    for (i=i0; i<i1; i+=1)
        v0 = w[i]   - bg
        v1 = w[i+1] - bg
        if (numtype(v0)==0 && numtype(v1)==0)
            area += 0.5*(v0+v1)*dxA
        endif
    endfor

    return area
End


// ============================================================================
//  Helper: uncertainty estimate for peak position from curvature + noise
//  - curv is ~ second derivative (I''), sigma is noise (intensity)
//  - dxA used for floors; win used for caps
// ============================================================================
Function LJZ_dX_FromCurv(sigma, curv, dxA, win)
    Variable sigma, curv, dxA, win

    if (numtype(sigma)!=0 || sigma<=0)
        return NaN
    endif
    if (numtype(curv)!=0)
        return NaN
    endif

    Variable cA = abs(curv)
    // floor curvature to avoid blow-up when peak is flat
    Variable cFloor = sigma / max((10*dxA)*(10*dxA), 1e-24)
    cA = max(cA, cFloor)

    Variable dxEst = sqrt(sigma / cA)

    // clamp: not smaller than ~0.1dx, not larger than ~0.8win
    dxEst = max(dxEst, 0.1*dxA)
    if (numtype(win)==0 && win>0)
        dxEst = min(dxEst, 0.8*abs(win))
    endif
    return dxEst
End


// ============================================================================
//  Helper: uncertainty estimate for area in a window (white noise)
//  dA ≈ sigma * sqrt(N) * dx
// ============================================================================
Function LJZ_dArea_Window(sigma, w, xPeak, Wint)
    Variable sigma
    Wave w
    Variable xPeak, Wint

    Variable dx = DimDelta(w,0)
    if (numtype(dx)!=0 || dx==0)
        return NaN
    endif
    Variable dxA = abs(dx)

    Variable n = numpnts(w)
    Variable i0 = round(x2pnt(w, xPeak - abs(Wint)))
    Variable i1 = round(x2pnt(w, xPeak + abs(Wint)))
    i0 = max(0, min(n-2, i0))
    i1 = max(1, min(n-1, i1))
    if (i1 <= i0+1)
        return NaN
    endif

    Variable Np = (i1 - i0 + 1)
    if (Np < 3)
        return NaN
    endif

    return sigma * sqrt(Np) * dxA
End

// ============================================================================
//  Helper: pseudo-Voigt normalized line shape (value=1 at x=x0)
//  fwhm > 0; eta in [0,1]
// ============================================================================
Function LJZ_PV_Norm(x, x0, fwhm, eta)
    Variable x, x0, fwhm, eta

    if (numtype(fwhm)!=0 || fwhm<=0)
        return NaN
    endif
    if (numtype(eta)!=0)
        eta = 0.5
    endif
    eta = max(0, min(1, eta))

    Variable sigma = fwhm/(2*sqrt(2*ln(2)))
    Variable gamma = fwhm/2

    Variable dx = x - x0
    Variable G = exp(-0.5*(dx/sigma)^2)
    Variable L = (gamma*gamma)/(dx*dx + gamma*gamma)

    return eta*L + (1-eta)*G
End




// ============================================================================
//  Helper: safe PV value (never NaN; invalid -> 0)
// ============================================================================
Function LJZ_PV_NormSafe(x, x0, fwhm, eta)
    Variable x, x0, fwhm, eta
    Variable v = LJZ_PV_Norm(x, x0, fwhm, eta)
    if (numtype(v)!=0)
        return 0
    endif
    return v
End

// ============================================================================
//  Helper: solve 2x2 linear system (robust)
//  [a b; c d] [x;y] = [e;f]
// ============================================================================
Function LJZ_Solve2x2(a,b,c,d,e,f,xOut,yOut)
    Variable a,b,c,d,e,f
    Variable &xOut,&yOut
    Variable det = a*d - b*c
    if (numtype(det)!=0 || abs(det) < 1e-20)
        xOut = NaN; yOut = NaN
        return 0
    endif
    xOut = ( e*d - b*f ) / det
    yOut = ( a*f - e*c ) / det
    return 1
End



// ============================================================================
//  LSQ: 1 peak + constant bg
//    y(x) = c0 + c1*PV(x; x1,f1,eta1)
// ============================================================================
Function LJZ_LS1PV_ConstBG(w, x1, f1, eta1, c0, c1)
    Wave w
    Variable x1, f1, eta1
    Variable &c0, &c1

    c0=NaN; c1=NaN

    Variable n=numpnts(w)
    if (n<5)
        return 0
    endif

    Variable S00=0, S01=0, S11=0
    Variable R0=0, R1=0
    Variable i, xi, yi, b1

    for (i=0; i<n; i+=1)
        yi = w[i]
        if (numtype(yi)!=0)
            continue
        endif
        xi = pnt2x(w, i)
        b1 = LJZ_PV_NormSafe(xi, x1, f1, eta1)

        S00 += 1
        S01 += b1
        S11 += b1*b1
        R0  += yi
        R1  += yi*b1
    endfor

    if (S00 < 5)
        return 0
    endif

    Variable ok = LJZ_Solve2x2(S00,S01,S01,S11, R0,R1, c0,c1)
    // 物理上幅度不应为负；若你希望允许负峰，删掉这一段
    if (ok && numtype(c1)==0)
        c1 = max(0, c1)
    endif
    return ok
End


// ============================================================================
//  Helper: 快速线性回归 (二次背景)
//  y = c0 + c1*x + c2*x^2 + A1*PV1 + A2*PV2
// ============================================================================
Function LJZ_LS2PV_QuadBG_Op(w, x1, f1, eta1, x2, f2, eta2, c0, c1, c2, A1, A2)
    Wave w
    Variable x1, f1, eta1, x2, f2, eta2
    Variable &c0, &c1, &c2, &A1, &A2

    c0=0; c1=0; c2=0; A1=0; A2=0
    Variable nTotal = numpnts(w)
    
    // 统计有效点数
    Variable nValid = 0
    Variable i
    for (i=0; i<nTotal; i+=1)
        if (numtype(w[i]) == 0)
            nValid += 1
        endif
    endfor

    // 参数个数为 5，点数必须 >= 7 (留点自由度)
    if (nValid < 7) 
        return 0
    endif

    // 构建矩阵 (N x 5)
    Make/D/FREE/N=(nValid, 5) MatA
    Make/D/FREE/N=(nValid)    VecB

    Variable row = 0
    Variable xi
    for (i=0; i<nTotal; i+=1)
        if (numtype(w[i]) != 0)
            continue
        endif
        
        xi = pnt2x(w, i) // U 坐标 (Centered)，防止 x^2 数值爆炸
        
        MatA[row][0] = 1.0                             // c0 (常数)
        MatA[row][1] = xi                              // c1 (斜率)
        MatA[row][2] = xi * xi                         // c2 (二次项)
        MatA[row][3] = LJZ_PV_NormSafe(xi, x1, f1, eta1) // A1 (峰1)
        MatA[row][4] = LJZ_PV_NormSafe(xi, x2, f2, eta2) // A2 (峰2)
        VecB[row]    = w[i]
        
        row += 1
    endfor

    // 使用 MatrixLLS 求解
    MatrixLLS /Z MatA, VecB

    if (V_flag != 0)
        return 0
    endif

    // 提取结果（M_B 的前 5 行）
    Wave M_B 
    if (numpnts(M_B) < 5)
        return 0
    endif

    c0 = M_B[0]
    c1 = M_B[1]
    c2 = M_B[2]
    A1 = M_B[3]
    A2 = M_B[4]
    
    KillWaves/Z M_B

    // 约束：幅度不为负
    if (A1 < 0) 
        A1 = 0 
    endif
    if (A2 < 0) 
        A2 = 0 
    endif

    return 1
End
// ============================================================================
//  HELP TEXT (集中维护，避免你以后改一次要找半天)
// ============================================================================
Function/S MDCFit_LJZ_HelpText()
    String s = ""
    s += "====================================================\r"
    s += " MDCFit_LJZ (2026) — Help / Notes\r"
    s += "====================================================\r\r"

    s += "【0. 你在干什么】\r"
    s += "本工具从一个 3D wave 里抽取每一帧的 MDC（角度/动量方向的一维切片），\r"
    s += "对每一帧做 1峰/2峰 Pseudo-Voigt 拟合，并输出峰位随帧（Delay/T/Fluence）变化的轨迹。\r\r"

    s += "【1. 输入数据要求（必须匹配）】\r"
    s += "你在 Wave(s) 列表里选择的必须是 3D wave：\r"
    s += "  dim0: X-index（你用 Eindex~Exe 做平均；通常是能量/像素索引）\r"
    s += "  dim1: Angle / K 轴（MDC 横轴，单位=degree 或 momentum）\r"
    s += "  dim2: Frame（Delay/Temperature/Fluence 的序列）\r"
    s += "Show MDC 会把 dim0 的 [Eindex..Exe] 平均，得到每帧一条 mdc。\r\r"

    s += "【2. 标准工作流（别跳步）】\r"
    s += "Step A: 选一个 3D wave\r"
    s += "Step B: (可选) Auto-Fill 自动填 Kpeak1/Kpeak2/Eindex/Exe\r"
    s += "Step C: Show MDC 生成堆叠 MDC 图 + 生成 runDF 下的 mdc_show_k\r"
    s += "Step D: (可选) 开 Smooth，调 Method/N1/N2/S/cutoff\r"
    s += "Step E: Run Fit（按 Fit mode 执行对应引擎）\r\r"

    s += "【3. Show MDC 做了什么（非常关键）】\r"
    s += "Show MDC 会创建一个 runDF：\r"
    s += "  runDF = root:ARPES_LJZ:MDCFit:<WaveName>_RUN_MDC_f<Eindex>2<Exe>:\r"
    s += "在 runDF 里生成：\r"
    s += "  mdc_raw_k   : 第 k 帧原始 MDC（dim1 方向）\r"
    s += "  mdc_show_k  : 可显示/可拟合 MDC（如果 Smooth 开启，会被平滑）\r"
    s += "并画一个 Overlapping 窗口，把每一帧按 kvary 垂直错开。\r\r"

    s += "【4. Smooth 参数说明（只影响 mdc_show_k）】\r"
    s += "Smooth 勾选=对每一帧 mdc_show_k 做平滑。\r"
    s += "Method:\r"
    s += "  None   : 不平滑\r"
    s += "  Smooth : Igor Smooth n 点（可叠加 N2）\r"
    s += "  SmoothS: Smooth/S=(sg)（sg 由 SmS 控制，偏更强的平滑核）\r"
    s += "  BLPF   : 低通 Smooth/BLPF cutoff（0~0.5）\r"
    s += "建议：先用 Smooth N1=9~15；N2 可先=0；太糊再加 N2。\r\r"

    s += "【5. 核心拟合模型（你代码里真实用的）】\r"
    s += "背景：bg = c0 + c1*x + c2*x^2\r"
    s += "峰：Pseudo-Voigt（Height + HWHM 形式）\r"
    s += "  sEff = sqrt(resH^2 + wfree^2)  (resH 是仪器分辨率HWHM下限)\r"
    s += "  PV = eta*Lorentz(H,sEff) + (1-eta)*Gauss(H,sEff)\r"
    s += "one_pv_ljz 系数： [c0 c1 c2 H1 x1 w1f eta1 resH]\r"
    s += "two_pv_ljz 系数： [c0 c1 c2 H1 x1 w1f eta1 H2 x2 w2f eta2 resH]\r\r"

    s += "【6. 面板参数 —— 你现在最容易晕的部分】\r"
    s += "Kpeak1 / Kpeak2:\r"
    s += "  两个峰的初始位置 seed（单位=dim1 的坐标单位，比如 degree）。\r"
    s += "Eindex (start) / Exe (end):\r"
    s += "  在 dim0 上做平均的范围（包含端点），平均后得到每帧 MDC。\r"
    s += "Res (>=0):\r"
    s += "  仪器分辨率的 HWHM 下限（与 dim1 同单位）。sEff = sqrt(Res^2+wfree^2)。\r"
    s += "forward delta / back delta (fdta / bdta):\r"
    s += "  从 seed 附近扩展 ROI 的点数（用于截取局部区间做拟合）。\r"
    s += "kvary:\r"
    s += "  叠图时每一帧向上平移的量（仅显示用）。\r"
    s += "width1 / width2 (wi1/wi2):\r"
    s += "  初始宽度尺度。不同模式里它可能被当作“有效宽度”或转换成 wfree。\r"
    s += "expand delta (ddta):\r"
    s += "  在 ROI 外额外扩一点（用于容错/漂移）。\r"
    s += "WidthRatio (WidRatio):\r"
    s += "  单峰兜底时会把某些宽度猜测除以 WidRatio，让单峰更窄/更保守。\r"
    s += "Z Label (uz):\r"
    s += "  轨迹图横轴标签：Delay/Temperature/Fluence（单位只影响标签显示）。\r\r"

// ============================================================================
//  更完整的 Fit mode 说明（可直接替换你原来那段 s+=...）
//  目标：把“行为差异 / gate 逻辑 / seed 逻辑 / 输出DF结构 / 适用场景 / 常见坑”讲清楚
// ============================================================================

s += "【7. Fit mode 到底区别是什么（完整版）】\r"
s += "Fit mode 不是“画图风格”，而是“每一帧如何选 ROI/如何给初值/如何判定双峰 vs 单峰/失败后如何兜底/是否带记忆锁定/输出哪些诊断量”的策略集合。\r\r"

s += "【7.1 通用输入参数（所有模式基本都用）】\r"
s += "runDF: 数据文件夹（最后会强制补 ':'），要求至少存在 runDF:mdc_show_0, mdc_show_1 ...\r"
s += "Kpeak1/Kpeak2: 你认为的两峰大致位置（单位=角度或k），用于初始 seed/ROI。\r"
s += "Res/ResH: 分辨率（与 x 轴同单位），在 Voigt 模型里当作“resH(HWHM_res)”或用于 needSep 门槛。\r"
s += "bdta/fdta/ddta: ROI 扩展（右/左/额外容错），数值越大越不容易截断，但更易把别的结构拉进来。\r"
s += "kvary: 叠图时每帧的纵向 offset。\r"
s += "wi1/wi2: 宽度初值（通常你希望理解为有效宽度 HWHM_eff 的量级）；部分模式会转成 wfree。\r"
s += "WidRatio: 单峰兜底时把宽度缩放（例如弱峰变窄时防止过宽吃背景）。\r"
s += "uz: 横轴含义标签（0 delay / 1 temperature / 2 fluence / else frame index）。\r\r"

s += "【7.2 输出数据结构统一约定】\r"
s += "每个 mode 都会在 runDF 下新建一个 FIT_* 子文件夹，并输出：\r"
s += "  - Peak1K/Peak2K: 双峰时两峰位置（按 x 从小到大排序）；单峰帧一般置 NaN。\r"
s += "  - Peak3K: 单峰位置；双峰帧一般置 NaN。\r"
s += "  - SigmaP*K: 位置不确定度（若来自 FuncFit 的 W_sigma 则填；否则 NaN）。\r"
s += "  - 叠图窗口：展示每帧原始曲线（layer_show_*）及拟合/标记。\r"
s += "  - 轨迹窗口：Peak1K/Peak2K/Peak3K 随帧（或随 t0/dt 轴）变化。\r\r"

s += "【7.3 SingleLock（强记忆锁定：一旦单峰成功就永远单峰）】\r"
s += "对应函数：MDC_NdSb_LJZ_MergeLock_FromShow（你贴出来的版本）。\r"
s += "核心思想：\r"
s += "  (1) 每帧优先尝试双峰 two_pv_ljz；\r"
s += "  (2) 如果某一帧双峰 gate 失败，则用单峰 one_pv_ljz 兜底；\r"
s += "  (3) 一旦任何帧“单峰兜底成功”，就触发 singleOnly=1：后续帧不再允许双峰（防止双/单之间乱跳）。\r"
s += "seed/记忆：\r"
s += "  - lastGood1/lastGood2 是双峰成功后更新的种子；\r"
s += "  - 单峰成功后会把 lastGood1/2 都写成单峰位置，并且直接 singleOnly=1。\r"
s += "gate（你代码里的硬门槛）：\r"
s += "  - 双峰必须满足 needSep=max(Res,3*|dy|) 的最小分离；\r"
s += "  - 若存在 W_sigma，则要求 sx <= max(0.2*s_eff, 0.5*|dy|)（s_eff=sqrt(res^2+wfree^2)）；\r"
s += "  - 双峰失败会尝试“恢复初值再拟合一次”（两次机会）。\r"
s += "优点：\r"
s += "  - 对“确实发生合并/不可分辨”的数据非常稳，不会后面又突然拆成双峰。\r"
s += "  - 适合做 quick-look：你只想要一条连续轨迹，不想中间跳来跳去。\r"
s += "缺点/坑：\r"
s += "  - 只要某一帧弱峰被噪声击穿导致单峰兜底成功，后面即使双峰重新变清晰也永远回不去双峰。\r"
s += "  - 因此它适合“物理上真的进入单峰相/真的合并”的场景，不适合“弱峰短暂变弱但随后恢复”的场景。\r"
s += "输出：runDF:FIT_SingleLock: Peak1K/Peak2K/Peak3K + SigmaP*。\r\r"

s += "【7.4 DTSLocalWin（逐帧局部窗口的双峰：每帧独立判定，不做全局锁死）】\r"
s += "对应思想：Doublet-Then-Single, Local Window。\r"
s += "核心思想：\r"
s += "  - 每一帧都在 seed1/seed2 附近开一个“局部 ROI 窗口”，只在局部做双峰拟合；\r"
s += "  - 双峰失败只影响当前帧：当前帧做单峰兜底，但下一帧仍然会重新尝试双峰（不锁死）。\r"
s += "seed/记忆：\r"
s += "  - 双峰成功更新 seed1/seed2；\r"
s += "  - 单峰成功通常只更新一个“主峰 seed”，另一个 seed 可保持/轻微回拉（防止漂移过远）。\r"
s += "适用：\r"
s += "  - 你数据中存在“弱峰间歇性变弱/又恢复”的情况；\r"
s += "  - 你不希望像 SingleLock 那样一次误判就永远单峰。\r"
s += "输出：runDF:FIT_DTS: Peak1K/Peak2K/Peak3K + SigmaP*（若用拟合）。\r"
s += "备注：DTSLocalWin 的关键是 ROI 必须足够小，否则背景曲率/旁瓣会把双峰拟合带跑。\r\r"

s += "【7.5 GPT（你现在的整合版本：TwinORSingle + 更严格 gate + 诊断量更全）】\r"
s += "对应函数族：\r"
s += "  - MDC_NdSb_LJZ_TwinORSingle_GPT（含 target窗/seed窗/SmartGuess/严格 gate 的框架）\r"
s += "  - MDC_NdSb_LJZ_TOS_GPT_BGFree_UCenter（你最终在用的 BGFree + UCenter + 面积/宽度/背景输出版本）\r"
s += "核心特点（最重要的差异点）：\r"
s += "  (A) UCenter：每帧把 ROI 的 x 平移到中心（u 坐标），在数值上更稳定，减少大常数导致的拟合病态。\r"
s += "  (B) BGFree：背景参数 c0/c1/c2 作为拟合参数输出并可带历史（hasBGHistory），用于诊断“背景把峰吃掉”。\r"
s += "  (C) SmartGuess：先用二阶导候选/或 seed 附近局部最大做初值，且强制夹在 ROI 内。\r"
s += "  (D) Gate 更系统：同时检查 V_FitError/V_FitQuitReason、参数 NaN、是否出 ROI、正高度、宽度相对 ROI、最小分离 needSep。\r"
s += "  (E) 失败处理：双峰失败会用 seed 回退再 retry（两套初值）；仍失败则 forceSingle=1，后续偏向单峰（但你也可改成“只影响当前帧”）。\r"
s += "输出更全（这是 GPT 模式相对 SingleLock/DTS 的最大价值）：\r"
s += "  - Peak* + Sigma*（同上）\r"
s += "  - WeffP*：有效宽度（HWHM_eff）\r"
s += "  - Sep12K：双峰分离度\r"
s += "  - AreaP1K/AreaP2K/AreaSum12K/AreaP3K：峰面积（由系数解析算或近似积分）\r"
s += "  - BG_c0/BG_c1/BG_c2：背景系数历史（用于排查失败原因）\r"
s += "  - gLastGateReason：最后一次 gate 失败原因字符串（例如 TOO_CLOSE / OUTSIDE_ROI / SIGMA_TOO_BIG 等）\r"
s += "适用：\r"
s += "  - 你要“可信+可诊断”的正式产出；\r"
s += "  - 你怀疑拟合失败是背景/初值/宽度/分离度导致，需要可解释的失败原因。\r"
s += "输出DF：runDF:FIT_TwinORSingle_GPT_BGFree_UCenter: Peak* Sigma* Area* Weff* Sep12K BG_c*。\r\r"

s += "【7.6 PeakPick（极简找点：不做非线性拟合，只做巡点与判定）】\r"
s += "对应函数：MDC_NdSb_LJZ_PeakPick_UC（你贴出来的版本，已加入高度/宽度/面积/误差估计）。\r"
s += "核心思想：\r"
s += "  - 每帧在 seed1/seed2 附近各找一个局部最大（可平滑、可抛物线亚像素修正）；\r"
s += "  - 用 sepNeed + 弱峰显著性（weakAmp > weakThrSig*sigma）判定双峰；否则单峰取更强者。\r"
s += "  - 不调用 FuncFit，因此没有真正的模型参数；速度快、鲁棒、不会出现拟合发散。\r"
s += "你这版的增强输出（很关键）：\r"
s += "  - FitMode：2=双峰，1=单峰，0=失败/未判定。\r"
s += "  - HgtP*：峰高（减 baseline 后的幅度）。\r"
s += "  - FwhmP*：从半高交点搜索得到的 FWHM（纯几何，不是 Voigt 参数）。\r"
s += "  - AreaP*：在 +/-Wint 窗口内对 (I-bg) 做梯形积分得到面积。\r"
s += "  - dX/dH/dA：用噪声 sigma 与曲率 curv 的粗略不确定度估计（用于置信度/筛帧）。\r"
s += "优点：\r"
s += "  - 非常适合做“先验巡检/给拟合提供 seed/快速扫参数”。\r"
s += "  - 对弱峰短暂变弱也不会把整个历史锁死（因为它本质是逐帧局部判定）。\r"
s += "缺点/坑：\r"
s += "  - 当背景强弯曲或峰形非对称时，FWHM/Area 可能偏；\r"
s += "  - 若 seed 设错、winPick 过大，会把两个寻点都找到同一峰（你已用 0.45*seedSep 做了上限，这是正确的）。\r"
s += "输出DF：runDF:FIT_PeakPick_UCenter: Peak* FitMode + Hgt/Fwhm/Area/dX/dH/dA。\r\r"

s += "【7.7 PTF_Robust_UC（强 gate + 多阶段 retry：最稳但最慢）】\r"
s += "对应函数：MDC_NdSb_LJZ_PTF_RobustFit_UC（你 RunFit 里绑定但未在片段里展示）。\r"
s += "典型设计（你现在代码体系里它通常会这样做）：\r"
s += "  - Stage-0：PeakPick/SmartGuess 给初值（确保起点合理）；\r"
s += "  - Stage-1：严格 ROI 双峰拟合；\r"
s += "  - Stage-2：若失败，回退到 seed 初值/更宽 ROI/更强 hold 再试；\r"
s += "  - Stage-3：若仍失败，单峰兜底，但不会轻易锁死（可配置）。\r"
s += "  - 额外诊断：记录每个 stage 的失败原因、最终采用哪一套结果。\r"
s += "适用：\r"
s += "  - 你要批量跑很长序列，且不想人工盯着；\r"
s += "  - 你愿意用更多计算时间换更少的失败帧。\r\r"

s += "【7.8 选择建议（最实用的一段）】\r"
s += "想要连续轨迹、且物理上确实会合并成单峰：用 SingleLock。\r"
s += "弱峰会短暂消失又回来、你不希望一次误判就锁死：用 DTSLocalWin 或 PeakPick。\r"
s += "要正式产出、需要面积/宽度/背景/失败原因可追溯：用 GPT_BGFree_UCenter。\r"
s += "要跑超长序列且尽量少失败帧：用 PTF_Robust_UC。\r\r"

s += "【7.9 常见失败/乱跳的根因与对策】\r"
s += "(1) TOO_CLOSE：两峰间距 < max(ResH,3*|dx|)。对策：确认 ResH 单位；或降低 needSep；或改用 PeakPick。\r"
s += "(2) SIGMA_TOO_BIG：W_sigma 给出位置误差过大。对策：缩小 ROI；增强 hold（锁背景曲率/eta/resH）；提高平滑或改 SmartGuess。\r"
s += "(3) 背景吃峰：拟合把峰高拟成背景曲率。对策：用 BGFree 输出 BG_c* 诊断；必要时锁 c2 或限制背景范围。\r"
s += "(4) seed 漂移：某帧误判把 seed 拉到错峰。对策：只在双峰 gate 通过时更新双峰 seed；单峰只更新主峰 seed。\r"
s += "(5) ROI 截断：fdta/bdta 太小导致峰半边不在 ROI。对策：增大 fdta/bdta/ddta，或用按 seed 自适应 ROI。\r\r"


    s += "【8. 输出在哪里看】\r"
    s += "1) Overlapping 窗口：每帧原始曲线 layer_show_k（+可选拟合曲线 fit_layer_k）\r"
    s += "2) Trajectory 窗口：Peak1K / Peak2K / Peak3K 随帧变化，附 ErrorBars（SigmaP*）\r"
    s += "3) DataFolder：所有结果都在 runDF 下的 FIT_* 子文件夹里。\r\r"

    s += "【9. 最常见翻车点（快速排查）】\r"
    s += "(i) 选错 3D wave：dim1 不是角度轴 / dim2 不是帧 -> 拟合一定乱。\r"
    s += "(ii) Kpeak1/Kpeak2 不在实际峰附近 -> ROI 截错，双峰永远失败。\r"
    s += "(iii) Res 设太大：sEff 被强行抬高，两个峰容易被“糊成一个”。\r"
    s += "(iv) Smooth 太狠：二阶导/峰形被抹平，PeakPick/Guess 会变差。\r"
    s += "(v) fdta/bdta 太小：ROI 不够，峰翼/背景进不来，拟合会飘。\r\r"

    s += "【10. 你后续要维护时的建议】\r"
    s += "把每个 FitMode 的主入口函数名和输出 DF 名字固定（现在已经基本固定）。\r"
    s += "Deprecated 的旧函数建议移到单独文件 MDCFit_LJZ_deprecated.ipf，保留但不让主文件变成垃圾堆。\r\r"

    return s
End

// ============================================================================
//  Help Button: 打开/刷新 Notebook
// ============================================================================
Function MDCPF_HelpButton_LJZ(ctrlName) : ButtonControl
    String ctrlName
    String nb = "MDCFit_LJZ_HELP"
    DoWindow/F $nb
    if (V_flag == 0)
        NewNotebook/N=$nb/F=1/V=1 as "MDCFit (LJZ) Help"
    endif

    // 每次点击都刷新内容（防止你改了代码但 help 没更新）
    Notebook $nb selection={startOfFile, endOfFile}
    Notebook $nb text=MDCFit_LJZ_HelpText()
    return 0
End
