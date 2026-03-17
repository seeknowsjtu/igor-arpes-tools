#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// FFTfilter with light tunables:
//   hfFrac:      high-frequency cutoff ratio in [0,1], default 0.30
//   kSigma:      threshold = median + kSigma * MAD, default 3.0
//   radDilate:   integer dilation radius (pixels), default 2  (≈5x5 kernel)
//   notchFactor: 0..1 notch depth (0=hard clamp to thr, 1=no change), default 0.0
//   smoothN:     smoothing points for display, default 50
//   doSymDisplay:1 to output spectrum slices, 0 to skip, default 1
//
// 输出：在  <NameOfWave(w)>_FFT3Dfilter  文件夹中保留 3 个 3D 波：
//   <base>_Half_FFT_log          : 每层半谱 log 幅度 叠成 3D
//   <base>_Half_FFT_log_Mask     : 每层 notch 后的 log 幅度 叠成 3D
//   <base>_after_fftdenoise      : IFFT 去噪后的 3D 结果
Function LJZ_20251014FFTfilter3D(w, hfFrac, kSigma, radDilate, notchFactor, attenDB, smoothN, doSymDisplay)
    Wave w
    Variable hfFrac, kSigma, radDilate, notchFactor, attenDB, smoothN, doSymDisplay

//    // ---------- defaults ----------
//    if (ParamIsDefault(hfFrac))
//        hfFrac = 0.8
//    endif
//    if (ParamIsDefault(kSigma))
//        kSigma = 3
//    endif
//    if (ParamIsDefault(radDilate))
//        radDilate = 8
//    endif
//    if (ParamIsDefault(notchFactor))
//        notchFactor = 0
//    endif
//    if (ParamIsDefault(attenDB))
//        attenDB = 0
//    endif
//    if (ParamIsDefault(smoothN))
//        smoothN = 50
//    endif
//    if (ParamIsDefault(doSymDisplay))
//        doSymDisplay = 0
//    endif

    // ---------- basic checks ----------
    Variable dims = WaveDims(w)
    if (dims != 2 && dims != 3)
        Abort "FFTfilter3D: input must be 2D or 3D."
    endif

    String base = NameOfWave(w)
    String outNameDenoise = base + "_after_fftdenoise"
    String outNameLog     = base + "_Half_FFT_log"
    String outNameLogMask = base + "_Half_FFT_log_Mask"

    DFREF savedDFR = GetDataFolderDFR()
    String tmpDF = (base + "_FFT3Dfilter")
    NewDataFolder/O/S $tmpDF

    try
        // ===== 原始尺寸与偶数裁剪 =====
        Variable nx0 = DimSize(w, 0)
        Variable ny0 = DimSize(w, 1)
        Variable nz0
        if (dims == 3)
            nz0 = DimSize(w, 2)
        else
            nz0 = 1
        endif

        Variable nxEven = nx0
        if (nx0/2 != floor(nx0/2))
            nxEven = nx0 - 1
        endif
        Variable nyEven = ny0
        if (ny0/2 != floor(ny0/2))
            nyEven = ny0 - 1
        endif
        if (nxEven < 2 || nyEven < 2)
            Abort "FFTfilter3D: wave too small after even-trim."
        endif

        // ===== 工作波（裁偶后）=====
        Wave w_work
        if (dims == 3)
            Make/O/N=(nxEven, nyEven, nz0) w_work
            SetScale/P x, DimOffset(w,0), DimDelta(w,0), "", w_work
            SetScale/P y, DimOffset(w,1), DimDelta(w,1), "", w_work
            SetScale/P z, DimOffset(w,2), DimDelta(w,2), "", w_work
            w_work = w[p][q][r]
        else
            Make/O/N=(nxEven, nyEven) w_work
            SetScale/P x, DimOffset(w,0), DimDelta(w,0), "", w_work
            SetScale/P y, DimOffset(w,1), DimDelta(w,1), "", w_work
            w_work = w[p][q]
        endif

        // ===== 半谱尺寸与网格 =====
        Variable nxHalf = nxEven/2 + 1
        Variable ny = nyEven
        Make/O/N=(nxHalf) kx = p
        Make/O/N=(ny)     ky = p
        Variable cy = (ny - 1) / 2.0
        ky -= cy
        Make/O/N=(nxHalf, ny) rmap = sqrt(kx[p]^2 + ky[q]^2)

        // ===== 预分配所有临时波（循环内覆写，不 Kill）=====
        Make/O/N=(nxEven, nyEven) layer
        Make/O/N=(nxHalf, ny)     mag, ph, logMag, logMagNotched, mag2
        Make/O/N=(nxHalf, ny)     maskRaw, mask
        Variable flatLen = nxHalf * ny
        Make/O/N=(flatLen)        flat, sorted, dev
        Make/O/N=(nxHalf, ny)     realPart, imagPart
        Make/O/C/N=(nxHalf, ny)   spec

        // ===== 创建 3 个最终 3D 输出波（直接写 slice）=====
        Make/O/N=(nxEven, nyEven, nz0)   $outNameDenoise
        Make/O/N=(nxHalf, ny,     nz0)   $outNameLog
        Make/O/N=(nxHalf, ny,     nz0)   $outNameLogMask
        Wave out3D = $outNameDenoise
        Wave outLog3D = $outNameLog
        Wave outLogMask3D = $outNameLogMask

        // 继承去噪结果的坐标（x,y 来自 w_work，z 来自原始第三维）
        SetScale/P x, DimOffset(w_work,0), DimDelta(w_work,0), "", out3D
        SetScale/P y, DimOffset(w_work,1), DimDelta(w_work,1), "", out3D
        if (dims == 3)
            SetScale/P z, DimOffset(w_work,2), DimDelta(w_work,2), "", out3D
        endif

        // 半谱 3D 堆叠不强制加单位（保留索引坐标），如需可自行 SetScale

        // ===== 常量 =====
        Variable eps = 1e-12
        Variable attenNat = attenDB * ln(10) / 20.0
        Variable rr = max(0, radDilate)
        
        Progress_OpenFFT3D(0, 1, nz0)

        // ===== 主循环：逐层处理并写入 3 个 3D 输出 =====
        Variable k
        for (k = 0; k < nz0; k += 1)
        
                    // ★ 可中止检查（Stop 按钮把 abort=1）
            NVAR abortFlag = root:Packages:LJZ_FFT3D:ljzabortion
            if (abortFlag != 0)
                Progress_CloseFFT3D()
                Abort "User stopped FFT3D."
            endif

            // 取层
            if (dims == 3)
                layer = w_work[p][q][k]
            else
                layer = w_work[p][q]
            endif

            // 半谱 FFT
            FFT/OUT=3/DEST=mag layer
            FFT/OUT=5/DEST=ph  layer
            mag = max(mag, eps)

            // log 幅度
            logMag = ln(mag)

            // 鲁棒阈值 median + kSigma*MAD
            Redimension/N=(flatLen) flat
            flat = logMag[mod(p, nxHalf)][floor(p / nxHalf)]
            Duplicate/O flat, sorted
            Sort sorted, sorted
            Variable n = flatLen
            Variable midIdx = round(0.5 * (n - 1))
            Variable med = sorted[midIdx]
            dev = abs(sorted[p] - med)
            Sort dev, dev
            Variable mad = dev[midIdx]
            Variable sigma = 1.4826 * mad
            Variable thr = med + kSigma * sigma

            // 掩膜（高频环域）与膨胀
            Variable rMin = hfFrac * min(nxHalf, cy)
            maskRaw = ((rmap > rMin) && (logMag > thr))
            mask = 0
            Variable i, j, ii, jj
            for (i = 0; i < nxHalf; i += 1)
                for (j = 0; j < ny; j += 1)
                    if (maskRaw[i][j] != 0)
                        for (ii = max(0, i - rr); ii <= min(nxHalf - 1, i + rr); ii += 1)
                            for (jj = max(0, j - rr); jj <= min(ny - 1, j + rr); jj += 1)
                                mask[ii][jj] = 1
                            endfor
                        endfor
                    endif
                endfor
            endfor

            // notch + 掩膜内额外 dB 衰减（log 域）
            logMagNotched = mask * ( (thr + notchFactor * (logMag - thr)) - attenNat ) + (1 - mask) * logMag

            // —— 叠层保存半谱 log（两个 3D 输出）——
            outLog3D[][][k] = logMag[p][q]
            outLogMask3D[][][k] = logMagNotched[p][q]

            // 回线性幅度并重建复谱，再 IFFT
            mag2 = exp(min(logMagNotched, 700))
            realPart = mag2 * cos(ph)
            imagPart = mag2 * sin(ph)
            MatrixOP/C/O spec = cmplx(realPart, imagPart)
            IFFT spec      // 结果为实域 (nxEven, nyEven)

            // 写回去噪 3D
            out3D[][][k] = spec[p][q]
		 Progress_SetFFT3D(k + 1)
        endfor
        Progress_CloseFFT3D()

        // 清理临时波（仅删除中间量，三个 3D 输出与文件夹都会保留）
        KillWaves/Z spec, imagPart, realPart
        KillWaves/Z mag2, logMagNotched, logMag, ph, mag
        KillWaves/Z mask, maskRaw, rmap, ky, kx
        KillWaves/Z dev, sorted, flat, layer, w_work

        // 回到调用前数据夹（不删除 tmpDF）
        SetDataFolder savedDFR

    catch
        // 出错也不删文件夹，方便排查
        Progress_CloseFFT3D()
        SetDataFolder savedDFR
        Variable err = GetRTError(0)
        String msg
        if (err != 0)
            msg = GetErrMessage(err)
        else
            msg = "Aborted inside LJZ_20251014FFTfilter3D."
        endif
        err = GetRTError(1)
        Abort msg
    endtry
End

//============================
// 列出 root: 及其一级子文件夹（用于下拉菜单）
// 结果形如 "root:;root:DF1:;root:DF2:" （分号分隔）
//============================
Function/S LJZ_ListRootDFs()
    String lst = "root:"
    Variable n = CountObjects("root:", 4)
    Variable i
    for (i=0; i<n; i+=1)
        String sub = GetIndexedObjName("root:", 4, i)
        if (strlen(sub) > 0)
            lst = AddListItem("root:" + sub + ":", lst, ";", Inf)
        endif
    endfor
    return lst
End

//============================
// 非递归：列出 path 下的 3D 波（仅当前层）
// 返回分号分隔全路径
//============================
Function/S LJZ_List3DWavesHere(path)
    String path
    path = RemoveEnding(path, ":") + ":"
    String out = ""
    Variable n = CountObjects(path, 1)
    Variable i
    for (i=0; i<n; i+=1)
        String nm = GetIndexedObjName(path, 1, i)
        Wave/Z w = $(path + nm)
        if (WaveExists(w) && WaveDims(w) >= 3 && DimSize(w, 2) > 0)
            out = AddListItem(path + nm, out, ";", Inf)
        endif
    endfor
    return out
End

//============================
// 重建（非递归）ListBox 的数据波
// 使用：root:ARPES_LJZ:FFT3D:LB_Items3D / LB_Sel3D
//============================
Function LJZ_RebuildWaveLB_Here(basePath)
    String basePath
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:FFT3D
    String s = LJZ_List3DWavesHere(basePath)
    Variable n = ItemsInList(s, ";")
    Variable Nn
    if (n > 0)
        Nn = n
    else
        Nn = 1
    endif
    Make/O/T/N=(Nn) root:ARPES_LJZ:FFT3D:LB_Items3D
    Make/O/N=(Nn)  root:ARPES_LJZ:FFT3D:LB_Sel3D
    Wave/T wItems = root:ARPES_LJZ:FFT3D:LB_Items3D
    Wave    wSel  = root:ARPES_LJZ:FFT3D:LB_Sel3D
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

//============================
// 打开/初始化 FFT3D 参数面板
//============================
Proc FFT3D_LJZ()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O/S root:ARPES_LJZ:FFT3D

    // 选择状态
    String/G BasePathSel = "root:"              // 当前“根目录”
    String/G FFTWaveSel  = ""                   // 选中的 3D 波全路径

    // 下拉菜单项缓存（可直接用函数）与参数
    String/G DFMenuList = LJZ_ListRootDFs()

    // 滤波参数（与函数形参一致）
    Variable/G hfFrac = 0.8
    Variable/G kSigma = 3
    Variable/G radDilate = 8
    Variable/G notchFactor = 0
    Variable/G attenDB = 0
    Variable/G smoothN = 50
    Variable/G doSymDisplay = 0

    // 首次构建列表（非递归，只扫 BasePathSel）
    LJZ_RebuildWaveLB_Here(BasePathSel)

    SetDataFolder root:
    DoWindow/F FFT3D_LJZ_P
    if (V_flag == 0)
        FFT3D_LJZ_P()
    endif
End

//============================
// 面板定义
//============================
Window FFT3D_LJZ_P() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(326.4,166.8,887.4,595.8) as "2025FFT3D_LJZ"
	ModifyPanel frameStyle=1
	ShowTools/A
	ShowInfo/W=$WinName(0,64)
	TitleBox tb0,pos={12.00,6.00},size={66.60,18.00},title="Base Folder:",frame=0
	PopupMenu pmBase,pos={99.00,6.00},size={102.60,20.40},proc=FFT3D_PMBaseProc
	PopupMenu pmBase,mode=3,popvalue="root:ARPES_LJZ:",value= #"root:ARPES_LJZ:FFT3D:DFMenuList"
	TitleBox tb1,pos={12.00,33.00},size={120.60,18.00},title="3D Waves (here only):"
	TitleBox tb1,frame=0
	ListBox lbWave3D,pos={12.00,54.00},size={540.00,180.00},proc=FFT3D_LBProc
	ListBox lbWave3D,listWave=root:ARPES_LJZ:FFT3D:LB_Items3D
	ListBox lbWave3D,selWave=root:ARPES_LJZ:FFT3D:LB_Sel3D,mode= 1,selRow= 29
	ListBox lbWave3D,userColumnResize= 1
	Button btnRefresh,pos={280.80,9.00},size={268.20,36.00},proc=FFT3D_RefreshList,title="Refresh List"
	TitleBox tb2,pos={12.00,246.00},size={95.40,18.00},title="Filter Parameters:"
	TitleBox tb2,frame=0
	SetVariable svHf,pos={12.00,267.00},size={258.00,19.80},title="hfFrac (0~1)"
	SetVariable svHf,limits={0,1,0.01},value= root:ARPES_LJZ:FFT3D:hfFrac
	SetVariable svKS,pos={279.00,267.00},size={258.00,19.80},title="kSigma"
	SetVariable svKS,limits={0,inf,0.1},value= root:ARPES_LJZ:FFT3D:kSigma
	SetVariable svRD,pos={12.00,294.00},size={258.00,19.80},title="radDilate"
	SetVariable svRD,limits={0,inf,1},value= root:ARPES_LJZ:FFT3D:radDilate
	SetVariable svNF,pos={279.00,294.00},size={258.00,19.80},title="notchFactor"
	SetVariable svNF,limits={0,inf,0.1},value= root:ARPES_LJZ:FFT3D:notchFactor
	SetVariable svAD,pos={12.00,324.00},size={258.00,19.80},title="attenDB (dB)"
	SetVariable svAD,limits={-inf,inf,0.5},value= root:ARPES_LJZ:FFT3D:attenDB
	SetVariable svSM,pos={279.00,324.00},size={258.00,19.80},title="smoothN"
	SetVariable svSM,limits={0,inf,1},value= root:ARPES_LJZ:FFT3D:smoothN
	CheckBox cbSym,pos={447.00,243.00},size={88.80,18.00},title="doSymDisplay"
	CheckBox cbSym,variable= root:ARPES_LJZ:FFT3D:doSymDisplay
	Button btnRun,pos={24.00,360.00},size={180.00,48.00},proc=FFT3D_RunButton,title="Run FFT Denoise"
	Button btnHelp,pos={228.00,360.00},size={120.00,48.00},proc=FFT3D_Help,title="Help"
	Button btnClose,pos={375.00,360.00},size={159.00,48.00},proc=FFT3D_Close,title="Close"
	Execute/Q/Z "SetWindow kwTopWin sizeLimit={27,49.2,inf,inf}" // sizeLimit requires Igor 7 or later
EndMacro

//============================
// 下拉菜单回调：更新 BasePathSel 并刷新 ListBox
//============================
Function FFT3D_PMBaseProc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName
    Variable popNum
    String popStr
    SVAR basePath = root:ARPES_LJZ:FFT3D:BasePathSel
    SVAR dfList   = root:ARPES_LJZ:FFT3D:DFMenuList

    // popStr 就是被选中的路径，如 "root:" 或 "root:DF1:"
    if (strlen(popStr) > 0)
        basePath = popStr
    endif

    // 重新扫描当前根目录（非递归）
    LJZ_RebuildWaveLB_Here(basePath)
    return 0
End

//============================
// ListBox 回调：记录选中的 3D 波路径
//============================
Function FFT3D_LBProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba
    if (lba.eventCode == 4 && lba.row >= 0)
        Wave/T wList = lba.listWave
        Wave/Z sel   = lba.selWave
        SVAR pickVar = root:ARPES_LJZ:FFT3D:FFTWaveSel
        String pick = wList[lba.row]
        if (StringMatch(pick, "None"))
            pickVar = ""
        else
            pickVar = pick
        endif
        if (WaveExists(sel))
            sel = 0
            sel[lba.row] = 1
        endif
    endif
    return 0
End

//============================
// “Refresh List” 按钮：重扫当前 BasePathSel
//============================
Function FFT3D_RefreshList(ctrlName) : ButtonControl
    String ctrlName
    SVAR basePath = root:ARPES_LJZ:FFT3D:BasePathSel
    LJZ_RebuildWaveLB_Here(basePath)
    return 0
End

//============================
// Run FFT Denoise：调用你的滤波函数
// 输出三个 3D 波，保留在 <name>_FFT3Dfilter 文件夹
//============================
Function FFT3D_RunButton(ctrlName) : ButtonControl
    String ctrlName

    SVAR wavePath = root:ARPES_LJZ:FFT3D:FFTWaveSel
    if (strlen(wavePath) == 0)
        DoAlert 0, "Please select a 3D wave."
        return 0
    endif

    Wave/Z wSel = $wavePath
    if (!WaveExists(wSel))
        DoAlert 0, "Selected wave not found: " + wavePath
        return 0
    endif
    if (WaveDims(wSel) < 2)
        DoAlert 0, "Selected wave must be 2D or 3D."
        return 0
    endif

    NVAR hfFrac = root:ARPES_LJZ:FFT3D:hfFrac
    NVAR kSigma = root:ARPES_LJZ:FFT3D:kSigma
    NVAR radDilate = root:ARPES_LJZ:FFT3D:radDilate
    NVAR notchFactor = root:ARPES_LJZ:FFT3D:notchFactor
    NVAR attenDB = root:ARPES_LJZ:FFT3D:attenDB
    NVAR smoothN = root:ARPES_LJZ:FFT3D:smoothN
    NVAR doSymDisplay = root:ARPES_LJZ:FFT3D:doSymDisplay

    // 调用你的核心函数（须已编译在环境中）
    // 输出会在 <NameOfWave(w)>_FFT3Dfilter 文件夹中生成 3 个 3D 波
    LJZ_20251014FFTfilter3D(wSel, hfFrac, kSigma, radDilate, notchFactor, attenDB, smoothN, doSymDisplay)

    DoAlert 0, "FFT denoise done for:\r" + NameOfWave(wSel)
    return 0
End

//============================
// Help / Close
//============================
Function FFT3D_Help(ctrlName) : ButtonControl
    String ctrlName
    String msg = "Select a base folder (root or its first-level subfolders),\r"
    msg += "then pick a 3D wave in that folder (non-recursive scan).\r"
    msg += "Set filter params and click 'Run FFT Denoise'.\r"
    msg += "Outputs are saved in <wave>_FFT3Dfilter:\r"
    msg += "  *_Half_FFT_log (3D)\r"
    msg += "  *_Half_FFT_log_Mask (3D)\r"
    msg += "  *_after_fftdenoise (3D)"
    DoAlert 0, msg
    return 0
End

Function FFT3D_Close(ctrlName) : ButtonControl
    String ctrlName
    DoWindow/K FFT3D_LJZ_P
    return 0
End

// 打开/重置进度窗（用你的变量名；用 _NUM: 逐次更新）
Function Progress_OpenFFT3D(indefinite, useIgorDraw, high)
    Variable indefinite, useIgorDraw, high

    DFREF savedDF = GetDataFolderDFR()

    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:LJZ_FFT3D
    SetDataFolder root:Packages:LJZ_FFT3D

    // 你的全局变量（可供外部查看/中止）
    Variable/G ljzprogressVal = 0
    Variable/G ljzmaxVal = max(1, high)
    Variable/G ljzabortion = 0

    DoWindow/K FFT3D_Progress
    NewPanel/N=FFT3D_Progress/W=(0,10,420,60) as "FFT3D Progress"

    // 只显示条；用 high（局部数值）设置上限；初值 0
    ValDisplay pv, win=FFT3D_Progress, pos={5,5}, size={342,18}
    ValDisplay pv, win=FFT3D_Progress, barmisc={0,0}
    ValDisplay pv, win=FFT3D_Progress, limits={0, high, 0}
    ValDisplay pv, win=FFT3D_Progress, value=_NUM:0

    if (indefinite)
        ValDisplay pv, win=FFT3D_Progress, mode=4   // 不确定型（糖果条）
    else
        ValDisplay pv, win=FFT3D_Progress, mode=3   // 确定型
    endif
    if (useIgorDraw)
        ValDisplay pv, win=FFT3D_Progress, highColor=(0,0,65535)
    endif

    Button bStop, win=FFT3D_Progress, pos={360,4}, size={50,20}, title="Stop", proc=FFT3D_ProgressStop

    DoUpdate/W=FFT3D_Progress/E=1
    SetDataFolder savedDF
End

// Stop 按钮：设置你的中止变量
Function FFT3D_ProgressStop(ctrlName) : ButtonControl
    String ctrlName
    NVAR ljzabortion = root:Packages:LJZ_FFT3D:ljzabortion
    ljzabortion = 1
    return 0
End

// 确定型更新：显式设置当前值 + 同步你的全局变量
Function Progress_SetFFT3D(val)
    Variable val
    NVAR prog = root:Packages:LJZ_FFT3D:ljzprogressVal
    prog = val
    ValDisplay pv, win=FFT3D_Progress, value=_NUM:val
    DoUpdate/W=FFT3D_Progress
    return 0
End

//// 不确定型更新：推动一次糖果条
//Function Progress_TickFFT3D()
//    ValDisplay pv, win=FFT3D_Progress, value=_NUM:1
//    DoUpdate/W=FFT3D_Progress
//    return 0
//End

Function Progress_CloseFFT3D()
    DoWindow/K FFT3D_Progress
    return 0
End