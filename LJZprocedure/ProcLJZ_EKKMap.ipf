#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma DefaultTab={3,20,4}

// ============================================================================
//  LJZ_EKKMap : E-k / kx-ky / kx-kz mapping workbench
//
//  来源与重构目标：
//    - 提取并重写 ZWT 系列里与 GetEKImage_WTZG / kxky_WTZG_Button /
//      kxkz_WTZG_Button / CalcKxKyP1_ZWT / CalcKxKzP1_ZWT / E-k 计算相关的部分
//    - UI / 状态管理风格参考 ProcLJZ 系列（尤其是 MDCPeakSep 的工程写法）
//
//  只负责：
//    1) 扫描指定 SourceDF 下的 2D / 3D 数值 wave
//    2) 在 panel 内联 graph 中预览当前 image（3D 时预览指定 z slice）
//    3) 对选中 wave 做 E-k / kx-ky / kx-kz 映射
//    4) 结果输出到 root:ARPES_LJZ:EKKMapOutput 下
//
//  约定（与原 ZWT 代码保持兼容）：
//    - E-k 的 2D 输入：angle × energy
//    - E-k 的 3D 输入：angle × energy × stack
//    - kx-ky 的 2D 输入：mode-angle × scan-angle
//    - kx-ky 的 3D 输入：energy × mode-angle × scan-angle
//    - kx-kz 的 2D 输入：mode-angle × hv
//    - kx-kz 的 3D 输入：energy × mode-angle × hv
//
//  这版相对旧代码的明确修正：
//    - 所有计算都在临时 wave 上完成，不再修改源 wave 的 scaling
//    - kx-ky 3D 正负 DimDelta 分支统一，去掉原来一支调用 CalcKxKyP_ZWT、
//      另一支调用 CalcKxKyP1_ZWT 的不一致
//    - 原代码里多处 degPixel -> x scale 的公式把 DimDelta 重复乘了一次，
//      这里统一改为真正的“每像素角度”标定：x = (p-(N-1)/2)*degPixel
//    - 统一做 sqrt / asin / 二次方程判别式的合法性检查，非法点直接写 NaN
//    - 3D 输出一律按固定 slice 索引写回，不再依赖正反向循环分支
//
//  不负责：
//    - MDC / EDC 提取与拟合
//    - fitting zone / graph wave edit
//    - delay scan / volume collapse
// ============================================================================

Menu "ARPES_LJZ"
    "2026EKKMap_LJZ", LJZ_EKKMap()
End


// ============================================================================
//  Section 0. paths / state
// ============================================================================

Constant LJZ_EKKMap_Mode_EK = 1
Constant LJZ_EKKMap_Mode_KxKy = 2
Constant LJZ_EKKMap_Mode_KxKz = 3

Function/S LJZ_EKKMap_BaseDF()
    return "root:ARPES_LJZ:EKKMap"
End

Function/S LJZ_EKKMap_OutputBaseDF()
    return "root:ARPES_LJZ:EKKMapOutput"
End

Function/S LJZ_EKKMap_PanelName()
    return "LJZ_EKKMap_Panel"
End

Function/S LJZ_EKKMap_GraphName()
    return "imgGraph"
End

Function/S LJZ_EKKMap_GraphPath()
    return LJZ_EKKMap_PanelName() + "#" + LJZ_EKKMap_GraphName()
End

Function/S LJZ_EKKMap_df_with_colon(inStr)
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

Function LJZ_EKKMap_df_exists(dfStr)
    String dfStr
    String s = LJZ_EKKMap_df_with_colon(dfStr)
    return DataFolderExists(s)
End

Function LJZ_EKKMap_HasChildSubwindow(hostWin, childName)
    String hostWin, childName
    String childList = ChildWindowList(hostWin)
    return (WhichListItem(childName, childList, ";", 0, 0) >= 0)
End

Function/S LJZ_EKKMap_ModeName(mode)
    Variable mode

    if (mode == LJZ_EKKMap_Mode_EK)
        return "E-k"
    endif
    if (mode == LJZ_EKKMap_Mode_KxKy)
        return "kx-ky"
    endif
    if (mode == LJZ_EKKMap_Mode_KxKz)
        return "kx-kz"
    endif
    return "E-k"
End

Function LJZ_EKKMap_IsNumericImageWave(w)
    Wave/Z w

    // 注意：WaveType(w,1) 才是稳定的类别判断；不要再用 WaveType(w)
    // 直接把 wave 误判成 numeric / text。这里只接受 2D / 3D numeric image wave。
    if (!WaveExists(w))
        return 0
    endif

    Variable waveClass = WaveType(w, 1)
    if (waveClass != 1)
        // waveClass == 2 为 text；其它类别（wave ref / data folder ref / null 等）
        // 也一律排除，不允许进入 image wave 列表。
        return 0
    endif

    if (DimSize(w,0) <= 0)
        return 0
    endif
    if (DimSize(w,1) <= 0)
        return 0
    endif
    if (DimSize(w,3) > 0)
        return 0
    endif
    if (DimSize(w,2) > 0)
        return 1
    endif
    return 1
End

Function LJZ_EKKMap_Is2DWave(w)
    Wave/Z w
    if (!WaveExists(w))
        return 0
    endif
    if (DimSize(w,0) <= 0 || DimSize(w,1) <= 0)
        return 0
    endif
    if (DimSize(w,2) > 0 || DimSize(w,3) > 0)
        return 0
    endif
    return 1
End

Function LJZ_EKKMap_Is3DWave(w)
    Wave/Z w
    if (!WaveExists(w))
        return 0
    endif
    if (DimSize(w,0) <= 0 || DimSize(w,1) <= 0 || DimSize(w,2) <= 0)
        return 0
    endif
    if (DimSize(w,3) > 0)
        return 0
    endif
    return 1
End

Function/S LJZ_EKKMap_WaveShortLabel(wPath)
    String wPath

    Wave/Z w = $wPath
    String nm = ""
    if (WaveExists(w))
        nm = NameOfWave(w)
        if (LJZ_EKKMap_Is3DWave(w))
            nm += " [3D]"
        else
            nm += " [2D]"
        endif
    else
        nm = wPath
    endif
    return nm
End

Function LJZ_EKKMap_Clamp(v, lo, hi)
    Variable v, lo, hi
    if (v < lo)
        return lo
    endif
    if (v > hi)
        return hi
    endif
    return v
End

Function LJZ_EKKMap_IsFinite(v)
    Variable v
    return (numtype(v) == 0)
End

Function LJZ_EKKMap_ClampToUnit(v)
    Variable v

    if (!LJZ_EKKMap_IsFinite(v))
        return NaN
    endif
    if (v > 1)
        return 1
    endif
    if (v < -1)
        return -1
    endif
    return v
End

Function LJZ_EKKMap_Min2(a, b)
    Variable a, b
    if (!LJZ_EKKMap_IsFinite(a))
        return b
    endif
    if (!LJZ_EKKMap_IsFinite(b))
        return a
    endif
    return (a < b) ? a : b
End

Function LJZ_EKKMap_Max2(a, b)
    Variable a, b
    if (!LJZ_EKKMap_IsFinite(a))
        return b
    endif
    if (!LJZ_EKKMap_IsFinite(b))
        return a
    endif
    return (a > b) ? a : b
End

Function LJZ_EKKMap_DimMin(w, dim)
    Wave w
    Variable dim

    Variable a = DimOffset(w, dim)
    Variable b = DimOffset(w, dim) + DimDelta(w, dim) * (DimSize(w, dim) - 1)
    return (a < b) ? a : b
End

Function LJZ_EKKMap_DimMax(w, dim)
    Wave w
    Variable dim

    Variable a = DimOffset(w, dim)
    Variable b = DimOffset(w, dim) + DimDelta(w, dim) * (DimSize(w, dim) - 1)
    return (a > b) ? a : b
End

Function/S LJZ_EKKMap_GetSuggestedSourceDF()
    String cur = GetDataFolder(1)
    if (DataFolderExists(cur))
        return LJZ_EKKMap_df_with_colon(cur)
    endif
    return "root:"
End

Function LJZ_EKKMap_SetCurrentMode(mode)
    Variable mode
    NVAR CurrentMode = $(LJZ_EKKMap_BaseDF() + ":CurrentMode")
    CurrentMode = mode
    LJZ_EKKMap_ClampPreviewZToCurrentWave()
    LJZ_EKKMap_RefreshTitleBoxes()
    return 0
End

Function LJZ_EKKMap_GetPreviewDimForMode(w, mode)
    Wave/Z w
    Variable mode

    if (!WaveExists(w))
        return -1
    endif
    if (!LJZ_EKKMap_Is3DWave(w))
        return -1
    endif

    // 3D 输入约定：
    //   EK:    angle × energy × stack  -> preview 切 dim2
    //   K maps energy × angle × scan   -> preview 切 dim0
    if (mode == LJZ_EKKMap_Mode_EK)
        return 2
    endif
    return 0
End

Function LJZ_EKKMap_EnsureDF()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O $(LJZ_EKKMap_BaseDF())
    NewDataFolder/O $(LJZ_EKKMap_OutputBaseDF())

    SVAR/Z sSourceDF = $(LJZ_EKKMap_BaseDF() + ":SourceDF")
    if (!SVAR_Exists(sSourceDF))
        String/G $(LJZ_EKKMap_BaseDF() + ":SourceDF") = LJZ_EKKMap_GetSuggestedSourceDF()
    endif

    SVAR/Z sSourceDFLastGood = $(LJZ_EKKMap_BaseDF() + ":SourceDFLastGood")
    if (!SVAR_Exists(sSourceDFLastGood))
        String/G $(LJZ_EKKMap_BaseDF() + ":SourceDFLastGood") = ""
    endif
    SVAR sSourceDFLastGoodRef = $(LJZ_EKKMap_BaseDF() + ":SourceDFLastGood")
    SVAR sSourceDFRef = $(LJZ_EKKMap_BaseDF() + ":SourceDF")
    if (!DataFolderExists(sSourceDFLastGoodRef))
        sSourceDFLastGoodRef = sSourceDFRef
    endif

    SVAR/Z sWave = $(LJZ_EKKMap_BaseDF() + ":WaveSel")
    if (!SVAR_Exists(sWave))
        String/G $(LJZ_EKKMap_BaseDF() + ":WaveSel") = ""
    endif

    NVAR/Z SelRow = $(LJZ_EKKMap_BaseDF() + ":SelRow")
    if (!NVAR_Exists(SelRow))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":SelRow") = -1
    endif

    NVAR/Z PreviewZ = $(LJZ_EKKMap_BaseDF() + ":PreviewZ")
    if (!NVAR_Exists(PreviewZ))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":PreviewZ") = 0
    endif

    NVAR/Z CurrentMode = $(LJZ_EKKMap_BaseDF() + ":CurrentMode")
    if (!NVAR_Exists(CurrentMode))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":CurrentMode") = LJZ_EKKMap_Mode_EK
    endif

    NVAR/Z ThetaAngle = $(LJZ_EKKMap_BaseDF() + ":ThetaAngle")
    if (!NVAR_Exists(ThetaAngle))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":ThetaAngle") = 0
    endif

    NVAR/Z hv = $(LJZ_EKKMap_BaseDF() + ":hv")
    if (!NVAR_Exists(hv))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":hv") = 5.9
    endif

    NVAR/Z WorkFunc = $(LJZ_EKKMap_BaseDF() + ":WorkFunc")
    if (!NVAR_Exists(WorkFunc))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":WorkFunc") = 4.3
    endif

    NVAR/Z MDCKf = $(LJZ_EKKMap_BaseDF() + ":MDCKf")
    if (!NVAR_Exists(MDCKf))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":MDCKf") = 0
    endif

    NVAR/Z FL = $(LJZ_EKKMap_BaseDF() + ":FL")
    if (!NVAR_Exists(FL))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":FL") = 0
    endif

    NVAR/Z Pixel = $(LJZ_EKKMap_BaseDF() + ":Pixel")
    if (!NVAR_Exists(Pixel))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":Pixel") = 0
    endif

    Variable energyRelInit = 0
    NVAR/Z EnergyRel = $(LJZ_EKKMap_BaseDF() + ":EnergyRel")
    if (!NVAR_Exists(EnergyRel))
        NVAR/Z LegacyEnergy = $(LJZ_EKKMap_BaseDF() + ":Energy")
        if (NVAR_Exists(LegacyEnergy))
            energyRelInit = LegacyEnergy
        endif
        Variable/G $(LJZ_EKKMap_BaseDF() + ":EnergyRel") = energyRelInit
    endif
    NVAR EnergyRelRef = $(LJZ_EKKMap_BaseDF() + ":EnergyRel")

    // Keep a legacy variable for older experiments/macros that may still read :Energy.
    NVAR/Z EnergyCompat = $(LJZ_EKKMap_BaseDF() + ":Energy")
    if (!NVAR_Exists(EnergyCompat))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":Energy") = EnergyRelRef
    endif
    NVAR EnergyCompatRef = $(LJZ_EKKMap_BaseDF() + ":Energy")
    EnergyCompatRef = EnergyRelRef

    NVAR/Z Azimuth = $(LJZ_EKKMap_BaseDF() + ":Azimuth")
    if (!NVAR_Exists(Azimuth))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":Azimuth") = 0
    endif

    NVAR/Z ScanOffset = $(LJZ_EKKMap_BaseDF() + ":ScanOffset")
    if (!NVAR_Exists(ScanOffset))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":ScanOffset") = 0
    endif

    NVAR/Z LatticeA = $(LJZ_EKKMap_BaseDF() + ":LatticeA")
    if (!NVAR_Exists(LatticeA))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":LatticeA") = 0
    endif

    NVAR/Z LatticeC = $(LJZ_EKKMap_BaseDF() + ":LatticeC")
    if (!NVAR_Exists(LatticeC))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":LatticeC") = 0
    endif

    NVAR/Z V0 = $(LJZ_EKKMap_BaseDF() + ":V0")
    if (!NVAR_Exists(V0))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":V0") = 0
    endif

    NVAR/Z Transpose = $(LJZ_EKKMap_BaseDF() + ":Transpose")
    if (!NVAR_Exists(Transpose))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":Transpose") = 0
    endif

    NVAR/Z Geometry = $(LJZ_EKKMap_BaseDF() + ":Geometry")
    if (!NVAR_Exists(Geometry))
        Variable/G $(LJZ_EKKMap_BaseDF() + ":Geometry") = 1
    endif

    Wave/T/Z wDisp = $(LJZ_EKKMap_BaseDF() + ":LB_Disp")
    if (!WaveExists(wDisp))
        Make/O/T/N=0 $(LJZ_EKKMap_BaseDF() + ":LB_Disp")
    endif

    Wave/T/Z wPath = $(LJZ_EKKMap_BaseDF() + ":LB_Path")
    if (!WaveExists(wPath))
        Make/O/T/N=0 $(LJZ_EKKMap_BaseDF() + ":LB_Path")
    endif

    Wave/Z wSel = $(LJZ_EKKMap_BaseDF() + ":LB_Sel")
    if (!WaveExists(wSel))
        Make/O/N=0 $(LJZ_EKKMap_BaseDF() + ":LB_Sel") = 0
    endif

    Make/O/N=(2,2) $(LJZ_EKKMap_BaseDF() + ":GraphStub") = NaN
    SetScale/P x, 0, 1, "", $(LJZ_EKKMap_BaseDF() + ":GraphStub")
    SetScale/P y, 0, 1, "", $(LJZ_EKKMap_BaseDF() + ":GraphStub")

    Make/O/N=(2,2) $(LJZ_EKKMap_BaseDF() + ":Preview2D") = NaN
    SetScale/P x, 0, 1, "", $(LJZ_EKKMap_BaseDF() + ":Preview2D")
    SetScale/P y, 0, 1, "", $(LJZ_EKKMap_BaseDF() + ":Preview2D")

    return 0
End


// ============================================================================
//  Section 1. scan / selection / preview
// ============================================================================

Function/S LJZ_EKKMap_ListImageWaves_OneDF(df)
    String df

    String dfc = LJZ_EKKMap_df_with_colon(df)
    if (!DataFolderExists(dfc))
        return ""
    endif

    String oldDF = GetDataFolder(1)
    SetDataFolder $dfc
    String wl = WaveList("*", ";", "")
    SetDataFolder $oldDF

    String out = ""
    Variable i, n = ItemsInList(wl, ";")
    for (i=0; i<n; i+=1)
        String nm = StringFromList(i, wl, ";")
        Wave/Z w = $(dfc + nm)
        if (!WaveExists(w))
            continue
        endif
        if (!LJZ_EKKMap_IsNumericImageWave(w))
            continue
        endif
        if (!(LJZ_EKKMap_Is2DWave(w) || LJZ_EKKMap_Is3DWave(w)))
            continue
        endif
        out += dfc + nm + ";"
    endfor
    return out
End

Function LJZ_EKKMap_RebuildWaveList()
    LJZ_EKKMap_EnsureDF()

    SVAR sDF = $(LJZ_EKKMap_BaseDF() + ":SourceDF")
    SVAR sWave = $(LJZ_EKKMap_BaseDF() + ":WaveSel")
    NVAR SelRow = $(LJZ_EKKMap_BaseDF() + ":SelRow")

    String prevWave = sWave
    String listStr = LJZ_EKKMap_ListImageWaves_OneDF(sDF)
    Variable n = ItemsInList(listStr, ";")

    Make/O/T/N=(n) $(LJZ_EKKMap_BaseDF() + ":LB_Disp")
    Make/O/T/N=(n) $(LJZ_EKKMap_BaseDF() + ":LB_Path")
    Make/O/N=(n) $(LJZ_EKKMap_BaseDF() + ":LB_Sel") = 0

    Wave/T wDisp = $(LJZ_EKKMap_BaseDF() + ":LB_Disp")
    Wave/T wPath = $(LJZ_EKKMap_BaseDF() + ":LB_Path")
    Wave wSel = $(LJZ_EKKMap_BaseDF() + ":LB_Sel")

    Variable i
    for (i=0; i<n; i+=1)
        String wFull = StringFromList(i, listStr, ";")
        wPath[i] = wFull
        wDisp[i] = LJZ_EKKMap_WaveShortLabel(wFull)
    endfor

    Variable keepRow = WhichListItem(prevWave, listStr, ";", 0, 0)
    if (keepRow < 0 && n > 0)
        keepRow = 0
    endif

    if (n > 0)
        keepRow = LJZ_EKKMap_Clamp(keepRow, 0, n-1)
        LJZ_EKKMap_SetSingleSelection(keepRow)
    else
        LJZ_EKKMap_SetSingleSelection(-1)
    endif

    LJZ_EKKMap_RestoreCurrentSelectionUI()
    LJZ_EKKMap_ShowCurrentWave()
    return 0
End

Function LJZ_EKKMap_RestoreCurrentSelectionUI()
    String p = LJZ_EKKMap_PanelName()
    if (WinType(p) == 0)
        return 0
    endif

    Wave/T/Z wPath = $(LJZ_EKKMap_BaseDF() + ":LB_Path")
    Wave/Z wSel = $(LJZ_EKKMap_BaseDF() + ":LB_Sel")
    NVAR/Z SelRow = $(LJZ_EKKMap_BaseDF() + ":SelRow")
    SVAR/Z sWave = $(LJZ_EKKMap_BaseDF() + ":WaveSel")
    if (!WaveExists(wPath) || !WaveExists(wSel) || !NVAR_Exists(SelRow) || !SVAR_Exists(sWave))
        return 0
    endif

    // 工程收尾：ListBox 改成严格单选后，这里统一修正 selWave / SelRow / WaveSel。
    if (numpnts(wPath) <= 0)
        wSel = 0
        SelRow = -1
        sWave = ""
        ListBox/Z lbWave, win=$p, selRow=-1
        ControlUpdate/W=$p lbWave
        return 0
    endif

    Variable keepRow = -1
    Variable i
    if (SelRow < 0 || SelRow >= numpnts(wPath) || CmpStr(sWave, wPath[SelRow]) != 0)
        for (i=0; i<numpnts(wPath); i+=1)
            if (CmpStr(sWave, wPath[i]) == 0)
                keepRow = i
                break
            endif
        endfor
        if (keepRow < 0)
            keepRow = SelRow
        endif
        if (keepRow < 0 || keepRow >= numpnts(wPath))
            keepRow = 0
        endif
        LJZ_EKKMap_SetSingleSelection(keepRow)
    else
        for (i=0; i<numpnts(wSel); i+=1)
            wSel[i] = (i == SelRow)
        endfor
    endif

    ListBox/Z lbWave, win=$p, selRow=SelRow
    ControlUpdate/W=$p lbWave
    return 0
End

Function LJZ_EKKMap_ClampPreviewZToCurrentWave()
    NVAR PreviewZ = $(LJZ_EKKMap_BaseDF() + ":PreviewZ")
    NVAR CurrentMode = $(LJZ_EKKMap_BaseDF() + ":CurrentMode")
    SVAR sWave = $(LJZ_EKKMap_BaseDF() + ":WaveSel")
    Wave/Z w = $sWave

    if (!WaveExists(w))
        PreviewZ = 0
        return 0
    endif

    if (LJZ_EKKMap_Is3DWave(w))
        Variable previewDim = LJZ_EKKMap_GetPreviewDimForMode(w, CurrentMode)
        if (previewDim < 0)
            PreviewZ = 0
        else
            PreviewZ = LJZ_EKKMap_Clamp(round(PreviewZ), 0, DimSize(w, previewDim) - 1)
        endif
    else
        PreviewZ = 0
    endif
    return 0
End

Function LJZ_EKKMap_MakeSliceFrom3D(src3D, iz, transpose, dest)
    Wave src3D
    Variable iz, transpose
    Wave dest

    Variable nx = DimSize(src3D,1)
    Variable ny = DimSize(src3D,2)

    // 默认给 kx-ky / kx-kz 3D 用：输入是 energy × angle × scan(hv)
    // transpose 仅供 preview；Run 阶段必须固定传 0，保持物理轴含义不变。
    // Transpose is for display only, not for physical mapping.
    if (transpose)
        Redimension/N=(ny,nx) dest
        SetScale/P x, DimOffset(src3D,2), DimDelta(src3D,2), WaveUnits(src3D,2), dest
        SetScale/P y, DimOffset(src3D,1), DimDelta(src3D,1), WaveUnits(src3D,1), dest
        dest = src3D[iz][q][p]
    else
        Redimension/N=(nx,ny) dest
        SetScale/P x, DimOffset(src3D,1), DimDelta(src3D,1), WaveUnits(src3D,1), dest
        SetScale/P y, DimOffset(src3D,2), DimDelta(src3D,2), WaveUnits(src3D,2), dest
        dest = src3D[iz][p][q]
    endif
    return 0
End

Function LJZ_EKKMap_MakeSliceFrom3D_EK(src3D, iz, transpose, dest)
    Wave src3D
    Variable iz, transpose
    Wave dest

    Variable nx = DimSize(src3D,0)
    Variable ny = DimSize(src3D,1)

    // E-k 3D 用：输入是 angle × energy × stack
    // transpose 仅供 preview；Run 阶段必须固定传 0，保持 angle / energy / stack 不变。
    // Transpose is for display only, not for physical mapping.
    if (transpose)
        Redimension/N=(ny,nx) dest
        SetScale/P x, DimOffset(src3D,1), DimDelta(src3D,1), WaveUnits(src3D,1), dest
        SetScale/P y, DimOffset(src3D,0), DimDelta(src3D,0), WaveUnits(src3D,0), dest
        dest = src3D[q][p][iz]
    else
        Redimension/N=(nx,ny) dest
        SetScale/P x, DimOffset(src3D,0), DimDelta(src3D,0), WaveUnits(src3D,0), dest
        SetScale/P y, DimOffset(src3D,1), DimDelta(src3D,1), WaveUnits(src3D,1), dest
        dest = src3D[p][q][iz]
    endif
    return 0
End

Function LJZ_EKKMap_BuildPreviewWave_EK3D(src3D, iz, transpose, dest)
    Wave src3D
    Variable iz, transpose
    Wave dest

    // EK 3D: angle × energy × stack，所以 preview z 切 dim2。
    return LJZ_EKKMap_MakeSliceFrom3D_EK(src3D, iz, transpose, dest)
End

Function LJZ_EKKMap_BuildPreviewWave_KMap3D(src3D, iz, transpose, dest)
    Wave src3D
    Variable iz, transpose
    Wave dest

    // K-map 3D: energy × angle × scan(hv)，panel preview 的 z 表示 energy slice，故切 dim0。
    return LJZ_EKKMap_MakeSliceFrom3D(src3D, iz, transpose, dest)
End

Function LJZ_EKKMap_BuildPreviewWave()
    LJZ_EKKMap_EnsureDF()
    LJZ_EKKMap_ClampPreviewZToCurrentWave()

    SVAR sWave = $(LJZ_EKKMap_BaseDF() + ":WaveSel")
    NVAR PreviewZ = $(LJZ_EKKMap_BaseDF() + ":PreviewZ")
    NVAR Transpose = $(LJZ_EKKMap_BaseDF() + ":Transpose")
    NVAR CurrentMode = $(LJZ_EKKMap_BaseDF() + ":CurrentMode")

    Wave/Z src = $sWave
    Wave preview = $(LJZ_EKKMap_BaseDF() + ":Preview2D")

    if (!WaveExists(src))
        preview = NaN
        return -1
    endif

    if (LJZ_EKKMap_Is2DWave(src))
        if (Transpose)
            Duplicate/O src, preview
            MatrixTranspose preview
        else
            Duplicate/O src, preview
        endif
        return 0
    endif

    if (LJZ_EKKMap_Is3DWave(src))
        if (CurrentMode == LJZ_EKKMap_Mode_EK)
            return LJZ_EKKMap_BuildPreviewWave_EK3D(src, PreviewZ, Transpose, preview)
        endif
        return LJZ_EKKMap_BuildPreviewWave_KMap3D(src, PreviewZ, Transpose, preview)
    endif

    preview = NaN
    return -1
End


// ============================================================================
//  Section 2. graph / panel refresh
// ============================================================================

Function LJZ_EKKMap_CreateGraphSubwindow()
    LJZ_EKKMap_EnsureDF()

    String panelName = LJZ_EKKMap_PanelName()
    String graphName = LJZ_EKKMap_GraphName()
    String graphPath = LJZ_EKKMap_GraphPath()
    if (WinType(panelName) == 0)
        return -1
    endif

    if (LJZ_EKKMap_HasChildSubwindow(panelName, graphName))
        KillWindow/Z $graphPath
    endif

    Wave preview = $(LJZ_EKKMap_BaseDF() + ":Preview2D")
    if (!WaveExists(preview))
        Wave stub = $(LJZ_EKKMap_BaseDF() + ":GraphStub")
        Display/HOST=$panelName/N=$graphName/W=(250,40,980,360)
        AppendImage/W=$graphPath stub
    else
        Display/HOST=$panelName/N=$graphName/W=(250,40,980,360)
        AppendImage/W=$graphPath preview
    endif

    ModifyGraph/W=$graphPath margin(left)=52,margin(bottom)=36,margin(right)=16,margin(top)=12,mirror=2
    ModifyGraph/W=$graphPath width={Plan,1,bottom,left}
    Label/W=$graphPath left "Y"
    Label/W=$graphPath bottom "X"
    return 0
End

Function LJZ_EKKMap_RefreshTitleBoxes()
    String p = LJZ_EKKMap_PanelName()
    if (WinType(p) == 0)
        return 0
    endif

    SVAR sWave = $(LJZ_EKKMap_BaseDF() + ":WaveSel")
    NVAR PreviewZ = $(LJZ_EKKMap_BaseDF() + ":PreviewZ")
    NVAR CurrentMode = $(LJZ_EKKMap_BaseDF() + ":CurrentMode")
    Wave/Z w = $sWave

    String t = "Current: none"
    if (WaveExists(w))
        t = "Current: " + NameOfWave(w) + "   mode = " + LJZ_EKKMap_ModeName(CurrentMode)
        if (LJZ_EKKMap_Is3DWave(w))
            if (CurrentMode == LJZ_EKKMap_Mode_EK)
                t += "   preview stack = " + num2str(PreviewZ)
            else
                t += "   preview energy slice = " + num2str(PreviewZ)
            endif
        endif
    endif

    TitleBox/Z tbCur, win=$p, title=t
    return 0
End

Function LJZ_EKKMap_ShowCurrentWave()
    LJZ_EKKMap_BuildPreviewWave()
    LJZ_EKKMap_CreateGraphSubwindow()
    LJZ_EKKMap_RefreshTitleBoxes()
    return 0
End

Function LJZ_EKKMap_RefreshWindowControls()
    String p = LJZ_EKKMap_PanelName()
    if (WinType(p) == 0)
        return 0
    endif

    // svSourceDF / svPreviewZ 都绑定到状态变量本身；这里只做 ControlUpdate，
    // 避免把绑定控件重新覆盖成内部字符串造成闪烁或回写异常。
    ControlUpdate/W=$p svSourceDF
    ControlUpdate/W=$p svPreviewZ
    return 0
End


// ============================================================================
//  Section 3. output helpers
// ============================================================================

Function/S LJZ_EKKMap_EnsureOutputDF(subName)
    String subName

    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O $(LJZ_EKKMap_OutputBaseDF())
    NewDataFolder/O $(LJZ_EKKMap_OutputBaseDF() + ":" + subName)
    return LJZ_EKKMap_OutputBaseDF() + ":" + subName + ":"
End

Function/S LJZ_EKKMap_KUnitA(latticeA)
    Variable latticeA
    if (latticeA == 0)
        return "Å\S-1"
    endif
    return "π/a"
End

Function/S LJZ_EKKMap_KUnitC(latticeC)
    Variable latticeC
    if (latticeC == 0)
        return "Å\S-1"
    endif
    return "π/c"
End

Function LJZ_EKKMap_KScaleA(latticeA)
    Variable latticeA
    if (latticeA == 0)
        return 0.5118
    endif
    return 0.5118 * latticeA / pi
End

Function LJZ_EKKMap_KScaleC(latticeC)
    Variable latticeC
    if (latticeC == 0)
        return 0.5118
    endif
    return 0.5118 * latticeC / pi
End

Function LJZ_EKKMap_SetRawAngleScale2D(w, degPixel)
    Wave w
    Variable degPixel

    if (degPixel == 0)
        return 0
    endif

    Variable n = DimSize(w,0)
    if (n <= 1)
        return 0
    endif

    SetScale/P x, -0.5 * (n - 1) * degPixel, degPixel, "deg", w
    return 0
End

Function LJZ_EKKMap_ClipToWave2D(src, xq, yq)
    Wave src
    Variable xq, yq

    if (!LJZ_EKKMap_IsFinite(xq) || !LJZ_EKKMap_IsFinite(yq))
        return NaN
    endif
    if (xq < LJZ_EKKMap_DimMin(src,0) || xq > LJZ_EKKMap_DimMax(src,0))
        return NaN
    endif
    if (yq < LJZ_EKKMap_DimMin(src,1) || yq > LJZ_EKKMap_DimMax(src,1))
        return NaN
    endif
    return src(xq)(yq)
End

Function LJZ_EKKMap_MinMaxFrom4(v1, v2, v3, v4, isMax)
    Variable v1, v2, v3, v4, isMax

    Variable out = NaN
    if (isMax)
        out = LJZ_EKKMap_Max2(v1, v2)
        out = LJZ_EKKMap_Max2(out, v3)
        out = LJZ_EKKMap_Max2(out, v4)
    else
        out = LJZ_EKKMap_Min2(v1, v2)
        out = LJZ_EKKMap_Min2(out, v3)
        out = LJZ_EKKMap_Min2(out, v4)
    endif
    return out
End

Function LJZ_EKKMap_SetLegacyEnergyCompat()
    NVAR/Z EnergyRel = $(LJZ_EKKMap_BaseDF() + ":EnergyRel")
    NVAR/Z EnergyCompat = $(LJZ_EKKMap_BaseDF() + ":Energy")

    if (NVAR_Exists(EnergyRel) && NVAR_Exists(EnergyCompat))
        EnergyCompat = EnergyRel
    endif
    return 0
End

Function LJZ_EKKMap_SetSingleSelection(row)
    Variable row

    Wave/T/Z wPath = $(LJZ_EKKMap_BaseDF() + ":LB_Path")
    Wave/Z wSel = $(LJZ_EKKMap_BaseDF() + ":LB_Sel")
    NVAR/Z SelRow = $(LJZ_EKKMap_BaseDF() + ":SelRow")
    SVAR/Z sWave = $(LJZ_EKKMap_BaseDF() + ":WaveSel")

    if (!WaveExists(wPath) || !WaveExists(wSel) || !NVAR_Exists(SelRow) || !SVAR_Exists(sWave))
        return -1
    endif

    // 严格单选：每次先清空旧选择，再只保留当前一行。
    wSel = 0
    if (numpnts(wPath) <= 0 || row < 0 || row >= numpnts(wPath))
        SelRow = -1
        sWave = ""
        return -1
    endif

    wSel[row] = 1
    SelRow = row
    sWave = wPath[row]
    return 0
End

Function/S LJZ_EKKMap_GetSelectedWaveList()
    Wave/T/Z wPath = $(LJZ_EKKMap_BaseDF() + ":LB_Path")
    Wave/Z wSel = $(LJZ_EKKMap_BaseDF() + ":LB_Sel")
    NVAR/Z SelRow = $(LJZ_EKKMap_BaseDF() + ":SelRow")
    SVAR/Z sWave = $(LJZ_EKKMap_BaseDF() + ":WaveSel")

    if (!(WaveExists(wPath) && WaveExists(wSel) && NVAR_Exists(SelRow) && SVAR_Exists(sWave)))
        return ""
    endif
    if (numpnts(wPath) <= 0)
        LJZ_EKKMap_SetSingleSelection(-1)
        return ""
    endif
    if (SelRow < 0 || SelRow >= numpnts(wPath))
        return ""
    endif
    if (CmpStr(sWave, wPath[SelRow]) != 0 || wSel[SelRow] == 0)
        if (LJZ_EKKMap_SetSingleSelection(SelRow) != 0)
            return ""
        endif
    endif
    return wPath[SelRow] + ";"
End

Function/S LJZ_EKKMap_GetLastGoodSourceDF()
    SVAR/Z sLast = $(LJZ_EKKMap_BaseDF() + ":SourceDFLastGood")
    SVAR/Z sDF = $(LJZ_EKKMap_BaseDF() + ":SourceDF")

    if (SVAR_Exists(sLast) && DataFolderExists(sLast))
        return LJZ_EKKMap_df_with_colon(sLast)
    endif
    if (SVAR_Exists(sDF) && DataFolderExists(sDF))
        return LJZ_EKKMap_df_with_colon(sDF)
    endif
    return LJZ_EKKMap_GetSuggestedSourceDF()
End

Function LJZ_EKKMap_RestoreLastGoodSourceDF()
    SVAR/Z sDF = $(LJZ_EKKMap_BaseDF() + ":SourceDF")
    if (!SVAR_Exists(sDF))
        return -1
    endif

    sDF = LJZ_EKKMap_GetLastGoodSourceDF()
    LJZ_EKKMap_RefreshWindowControls()
    return 0
End

Function/S LJZ_EKKMap_InputShapeMessage(mode, is3D)
    Variable mode, is3D

    if (mode == LJZ_EKKMap_Mode_EK)
        return is3D ? "EK 3D expects angle × energy × stack." : "EK 2D expects angle × energy."
    endif
    if (mode == LJZ_EKKMap_Mode_KxKy)
        return is3D ? "KxKy 3D expects energy × angle × scan-angle." : "KxKy 2D expects mode-angle × scan-angle."
    endif
    return is3D ? "KxKz 3D expects energy × angle × hv." : "KxKz 2D expects mode-angle × hv."
End

Function LJZ_EKKMap_AlertInvalidInput(w, msg)
    Wave/Z w
    String msg

    String prefix = ""
    if (WaveExists(w))
        prefix = NameOfWave(w) + ": "
    endif
    DoAlert 0, prefix + msg
    return 0
End

Function LJZ_EKKMap_ValidateInputForEK(w, is3D)
    Wave/Z w
    Variable is3D

    if (!WaveExists(w))
        LJZ_EKKMap_AlertInvalidInput(w, "Selected wave does not exist.")
        return 0
    endif
    if (is3D)
        if (!LJZ_EKKMap_Is3DWave(w))
            LJZ_EKKMap_AlertInvalidInput(w, LJZ_EKKMap_InputShapeMessage(LJZ_EKKMap_Mode_EK, 1))
            return 0
        endif
    else
        if (!LJZ_EKKMap_Is2DWave(w))
            LJZ_EKKMap_AlertInvalidInput(w, LJZ_EKKMap_InputShapeMessage(LJZ_EKKMap_Mode_EK, 0))
            return 0
        endif
    endif
    return 1
End

Function LJZ_EKKMap_ValidateInputForKxKy(w, is3D)
    Wave/Z w
    Variable is3D

    if (!WaveExists(w))
        LJZ_EKKMap_AlertInvalidInput(w, "Selected wave does not exist.")
        return 0
    endif
    if (is3D)
        if (!LJZ_EKKMap_Is3DWave(w))
            LJZ_EKKMap_AlertInvalidInput(w, LJZ_EKKMap_InputShapeMessage(LJZ_EKKMap_Mode_KxKy, 1))
            return 0
        endif
    else
        if (!LJZ_EKKMap_Is2DWave(w))
            LJZ_EKKMap_AlertInvalidInput(w, LJZ_EKKMap_InputShapeMessage(LJZ_EKKMap_Mode_KxKy, 0))
            return 0
        endif
    endif
    return 1
End

Function LJZ_EKKMap_ValidateInputForKxKz(w, is3D)
    Wave/Z w
    Variable is3D

    if (!WaveExists(w))
        LJZ_EKKMap_AlertInvalidInput(w, "Selected wave does not exist.")
        return 0
    endif
    if (is3D)
        if (!LJZ_EKKMap_Is3DWave(w))
            LJZ_EKKMap_AlertInvalidInput(w, LJZ_EKKMap_InputShapeMessage(LJZ_EKKMap_Mode_KxKz, 1))
            return 0
        endif
    else
        if (!LJZ_EKKMap_Is2DWave(w))
            LJZ_EKKMap_AlertInvalidInput(w, LJZ_EKKMap_InputShapeMessage(LJZ_EKKMap_Mode_KxKz, 0))
            return 0
        endif
    endif
    return 1
End

Function/S LJZ_EKKMap_TempDisplaySlicePath(graphName)
    String graphName
    return LJZ_EKKMap_BaseDF() + ":DisplaySlice_" + CleanupName(graphName, 0)
End

Function LJZ_EKKMap_MakeDisplaySliceFrom3D(w3D, iz, dest)
    Wave w3D
    Variable iz
    Wave dest

    Variable nz = DimSize(w3D,2)
    Variable useZ = LJZ_EKKMap_Clamp(round(iz), 0, nz-1)
    Redimension/N=(DimSize(w3D,0), DimSize(w3D,1)) dest
    SetScale/P x, DimOffset(w3D,0), DimDelta(w3D,0), WaveUnits(w3D,0), dest
    SetScale/P y, DimOffset(w3D,1), DimDelta(w3D,1), WaveUnits(w3D,1), dest
    dest = w3D[p][q][useZ]
    return 0
End

Function LJZ_EKKMap_ShowResultWave(w, graphName)
    Wave/Z w
    String graphName

    if (!WaveExists(w))
        return -1
    endif

    DoWindow/K $graphName
    Display/K=1/N=$graphName

    if (LJZ_EKKMap_Is3DWave(w))
        NVAR PreviewZ = $(LJZ_EKKMap_BaseDF() + ":PreviewZ")
        Make/O/N=(2,2) $(LJZ_EKKMap_TempDisplaySlicePath(graphName)) = NaN
        Wave dispSlice = $(LJZ_EKKMap_TempDisplaySlicePath(graphName))
        LJZ_EKKMap_MakeDisplaySliceFrom3D(w, PreviewZ, dispSlice)
        String imName3D = NameOfWave(dispSlice)
        AppendImage/W=$graphName dispSlice
        ModifyGraph/W=$graphName width={Plan,1,bottom,left}
        ModifyGraph/W=$graphName mirror=2
        ModifyImage/W=$graphName $imName3D, ctab={*,*,Rainbow,0}
    else
        String imName2D = NameOfWave(w)
        AppendImage/W=$graphName w
        ModifyGraph/W=$graphName width={Plan,1,bottom,left}
        ModifyGraph/W=$graphName mirror=2
        ModifyImage/W=$graphName $imName2D, ctab={*,*,Rainbow,0}
    endif
    return 0
End

Function/S LJZ_EKKMap_RecreateTempDF(subName)
    String subName

    String dfPath = LJZ_EKKMap_BaseDF() + ":" + subName
    KillDataFolder/Z $dfPath
    NewDataFolder/O $dfPath
    return dfPath + ":"
End

Function LJZ_EKKMap_Resample2DToCommonGrid(src, xMin, xMax, yMin, yMax, nx, ny, dest)
    Wave src
    Variable xMin, xMax, yMin, yMax, nx, ny
    Wave dest

    Redimension/N=(nx,ny) dest
    SetScale/I x, xMin, xMax, WaveUnits(src,0), dest
    SetScale/I y, yMin, yMax, WaveUnits(src,1), dest
    dest = LJZ_EKKMap_ClipToWave2D(src, x, y)
    return 0
End


// ============================================================================
//  Section 4. core kernels
// ============================================================================

Function LJZ_EKKMap_KxFromAngleE(relE, angleDeg, hv, workFunc, latticeA)
    Variable relE, angleDeg, hv, workFunc, latticeA

    Variable kin = hv - workFunc + relE
    if (kin <= 0)
        return NaN
    endif
    return LJZ_EKKMap_KScaleA(latticeA) * sqrt(kin) * sin(angleDeg * pi / 180)
End

Function LJZ_EKKMap_AngleFromKxE(kxVal, relE, hv, workFunc, latticeA)
    Variable kxVal, relE, hv, workFunc, latticeA

    Variable kin = hv - workFunc + relE
    Variable fac = LJZ_EKKMap_KScaleA(latticeA)
    if (kin <= 0 || fac == 0)
        return NaN
    endif

    Variable arg = LJZ_EKKMap_ClampToUnit(kxVal / fac / sqrt(kin))
    if (!LJZ_EKKMap_IsFinite(arg))
        return NaN
    endif
    return asin(arg) * 180 / pi
End

Function/WAVE LJZ_EKKMap_CalcEK2D(srcIn, tilt, hv, workFunc, FL, degPixel, latticeA, mdcKf)
    Wave srcIn
    Variable tilt, hv, workFunc, FL, degPixel, latticeA, mdcKf

    Duplicate/O srcIn, LJZ_EKKMap_tmpEK_src
    Wave src = LJZ_EKKMap_tmpEK_src
    LJZ_EKKMap_SetRawAngleScale2D(src, degPixel)

    Variable rawXMin = LJZ_EKKMap_DimMin(src,0)
    Variable rawXMax = LJZ_EKKMap_DimMax(src,0)
    Variable relEMin = LJZ_EKKMap_DimMin(src,1) - FL
    Variable relEMax = LJZ_EKKMap_DimMax(src,1) - FL
    Variable actA1 = rawXMin + tilt
    Variable actA2 = rawXMax + tilt

    Variable k1 = LJZ_EKKMap_KxFromAngleE(relEMin, actA1, hv, workFunc, latticeA)
    Variable k2 = LJZ_EKKMap_KxFromAngleE(relEMax, actA1, hv, workFunc, latticeA)
    Variable k3 = LJZ_EKKMap_KxFromAngleE(relEMin, actA2, hv, workFunc, latticeA)
    Variable k4 = LJZ_EKKMap_KxFromAngleE(relEMax, actA2, hv, workFunc, latticeA)

    Variable kMin = LJZ_EKKMap_MinMaxFrom4(k1,k2,k3,k4,0)
    Variable kMax = LJZ_EKKMap_MinMaxFrom4(k1,k2,k3,k4,1)
    if (!LJZ_EKKMap_IsFinite(kMin) || !LJZ_EKKMap_IsFinite(kMax) || kMin == kMax)
        Make/O/N=(2,2) LJZ_EKKMap_tmpEK = NaN
        return LJZ_EKKMap_tmpEK
    endif

    Variable nx = max(2, DimSize(src,0))
    Variable ny = max(2, DimSize(src,1))

    Make/O/N=(nx,ny) LJZ_EKKMap_tmpEK, LJZ_EKKMap_tmpEK_phi
    SetScale/I x, kMin - mdcKf, kMax - mdcKf, LJZ_EKKMap_KUnitA(latticeA), LJZ_EKKMap_tmpEK, LJZ_EKKMap_tmpEK_phi
    SetScale/I y, relEMin, relEMax, "eV", LJZ_EKKMap_tmpEK, LJZ_EKKMap_tmpEK_phi

    LJZ_EKKMap_tmpEK_phi = LJZ_EKKMap_AngleFromKxE(x + mdcKf, y, hv, workFunc, latticeA) - tilt
    LJZ_EKKMap_tmpEK = LJZ_EKKMap_ClipToWave2D(src, LJZ_EKKMap_tmpEK_phi(x)(y), y + FL)

    KillWaves/Z LJZ_EKKMap_tmpEK_src, LJZ_EKKMap_tmpEK_phi
    return LJZ_EKKMap_tmpEK
End

Function/WAVE LJZ_EKKMap_CalcKxKy2D(srcIn, energyRel, hv, workFunc, tilt, azimuth, scanOffset, degPixel, latticeA, geo)
    Wave srcIn
    Variable energyRel, hv, workFunc, tilt, azimuth, scanOffset, degPixel, latticeA, geo

    Duplicate/O srcIn, LJZ_EKKMap_tmpKxKy_src
    Wave src = LJZ_EKKMap_tmpKxKy_src
    LJZ_EKKMap_SetRawAngleScale2D(src, degPixel)

    Variable k0 = LJZ_EKKMap_KScaleA(latticeA) * sqrt(hv - workFunc + energyRel)
    if (!LJZ_EKKMap_IsFinite(k0) || k0 <= 0)
        Make/O/N=(2,2) LJZ_EKKMap_tmpKxKy = NaN
        return LJZ_EKKMap_tmpKxKy
    endif

    Duplicate/O src, LJZ_EKKMap_tmpKx1, LJZ_EKKMap_tmpKy1, LJZ_EKKMap_tmpKx2, LJZ_EKKMap_tmpKy2

    if (geo)
        Duplicate/O src, LJZ_EKKMap_tmpKy0, LJZ_EKKMap_tmpKz0, LJZ_EKKMap_tmpKx1b, LJZ_EKKMap_tmpKy1b, LJZ_EKKMap_tmpKz1b
        LJZ_EKKMap_tmpKy0 = k0 * sin(x*pi/180)
        LJZ_EKKMap_tmpKz0 = k0 * cos(x*pi/180)
        LJZ_EKKMap_tmpKx1b = LJZ_EKKMap_tmpKz0 * sin((y - scanOffset)*pi/180)
        LJZ_EKKMap_tmpKy1b = LJZ_EKKMap_tmpKy0
        LJZ_EKKMap_tmpKz1b = LJZ_EKKMap_tmpKz0 * cos((y - scanOffset)*pi/180)

        LJZ_EKKMap_tmpKx1 = LJZ_EKKMap_tmpKx1b
        LJZ_EKKMap_tmpKy1 = LJZ_EKKMap_tmpKy1b * cos(tilt*pi/180) - LJZ_EKKMap_tmpKz1b * sin(tilt*pi/180)
        LJZ_EKKMap_tmpKy2 = sqrt(LJZ_EKKMap_tmpKy1^2 + LJZ_EKKMap_tmpKx1^2) * sin(atan2(LJZ_EKKMap_tmpKy1, LJZ_EKKMap_tmpKx1) + azimuth*pi/180)
        LJZ_EKKMap_tmpKx2 = sqrt(LJZ_EKKMap_tmpKy1^2 + LJZ_EKKMap_tmpKx1^2) * cos(atan2(LJZ_EKKMap_tmpKy1, LJZ_EKKMap_tmpKx1) + azimuth*pi/180)
        KillWaves/Z LJZ_EKKMap_tmpKy0, LJZ_EKKMap_tmpKz0, LJZ_EKKMap_tmpKx1b, LJZ_EKKMap_tmpKy1b, LJZ_EKKMap_tmpKz1b
    else
        Duplicate/O src, LJZ_EKKMap_tmpTy1, LJZ_EKKMap_tmpTx1
        LJZ_EKKMap_tmpTy1 = k0 * sin((y + scanOffset)*pi/180) * cos((x + tilt)*pi/180)
        LJZ_EKKMap_tmpTx1 = k0 * sin((x + tilt)*pi/180)
        LJZ_EKKMap_tmpKy2 = sqrt(LJZ_EKKMap_tmpTy1^2 + LJZ_EKKMap_tmpTx1^2) * sin(atan2(LJZ_EKKMap_tmpTy1, LJZ_EKKMap_tmpTx1) + azimuth*pi/180)
        LJZ_EKKMap_tmpKx2 = sqrt(LJZ_EKKMap_tmpTy1^2 + LJZ_EKKMap_tmpTx1^2) * cos(atan2(LJZ_EKKMap_tmpTy1, LJZ_EKKMap_tmpTx1) + azimuth*pi/180)
        KillWaves/Z LJZ_EKKMap_tmpTy1, LJZ_EKKMap_tmpTx1
    endif

    Variable kxMin = WaveMin(LJZ_EKKMap_tmpKx2)
    Variable kxMax = WaveMax(LJZ_EKKMap_tmpKx2)
    Variable kyMin = WaveMin(LJZ_EKKMap_tmpKy2)
    Variable kyMax = WaveMax(LJZ_EKKMap_tmpKy2)

    if (!LJZ_EKKMap_IsFinite(kxMin) || !LJZ_EKKMap_IsFinite(kxMax) || kxMin == kxMax)
        Make/O/N=(2,2) LJZ_EKKMap_tmpKxKy = NaN
        return LJZ_EKKMap_tmpKxKy
    endif

    Variable nx = max(2, DimSize(src,0))
    Variable ny = max(2, round(abs((kyMax-kyMin)/(kxMax-kxMin))*(nx-1) + 1))

    Make/O/N=(nx,ny) LJZ_EKKMap_tmpKxKy
    SetScale/I x, kxMin, kxMax, LJZ_EKKMap_KUnitA(latticeA), LJZ_EKKMap_tmpKxKy
    SetScale/I y, kyMin, kyMax, LJZ_EKKMap_KUnitA(latticeA), LJZ_EKKMap_tmpKxKy

    Duplicate/O LJZ_EKKMap_tmpKxKy, LJZ_EKKMap_tmpA2, LJZ_EKKMap_tmpB2

    if (geo)
        if (abs(tilt) < 1e-10)
            LJZ_EKKMap_tmpA2 = asin(LJZ_EKKMap_ClampToUnit(sqrt(x^2+y^2)/k0 * sin(atan2(y,x) - azimuth*pi/180))) * 180/pi
            LJZ_EKKMap_tmpB2 = abs(cos(LJZ_EKKMap_tmpA2*pi/180)) < 1e-12 ? NaN : asin(LJZ_EKKMap_ClampToUnit(sqrt(x^2+y^2)/k0 * cos(atan2(y,x) - azimuth*pi/180) / cos(LJZ_EKKMap_tmpA2*pi/180))) * 180/pi
        else
            Duplicate/O LJZ_EKKMap_tmpKxKy, LJZ_EKKMap_tmpKxr, LJZ_EKKMap_tmpKyr, LJZ_EKKMap_tmpAA, LJZ_EKKMap_tmpBB, LJZ_EKKMap_tmpCC, LJZ_EKKMap_tmpDisc
            LJZ_EKKMap_tmpKxr = sqrt(x^2+y^2) * cos(atan2(y,x) - azimuth*pi/180)
            LJZ_EKKMap_tmpKyr = sqrt(x^2+y^2) * sin(atan2(y,x) - azimuth*pi/180)
            LJZ_EKKMap_tmpAA = 1 + cot(tilt*pi/180)^2
            LJZ_EKKMap_tmpBB = -2 * LJZ_EKKMap_tmpKyr / k0 / sin(tilt*pi/180)^2 * cos(tilt*pi/180)
            LJZ_EKKMap_tmpCC = (LJZ_EKKMap_tmpKxr/k0)^2 + (LJZ_EKKMap_tmpKyr/k0/sin(tilt*pi/180))^2 - 1
            LJZ_EKKMap_tmpDisc = LJZ_EKKMap_tmpBB^2 - 4 * LJZ_EKKMap_tmpAA * LJZ_EKKMap_tmpCC

            if (tilt > 0)
                LJZ_EKKMap_tmpA2 = LJZ_EKKMap_tmpDisc < 0 ? NaN : asin(LJZ_EKKMap_ClampToUnit((-LJZ_EKKMap_tmpBB + sqrt(LJZ_EKKMap_tmpDisc)) / (2 * LJZ_EKKMap_tmpAA))) * 180/pi
            else
                LJZ_EKKMap_tmpA2 = LJZ_EKKMap_tmpDisc < 0 ? NaN : asin(LJZ_EKKMap_ClampToUnit((-LJZ_EKKMap_tmpBB - sqrt(LJZ_EKKMap_tmpDisc)) / (2 * LJZ_EKKMap_tmpAA))) * 180/pi
            endif
            LJZ_EKKMap_tmpB2 = abs(cos(LJZ_EKKMap_tmpA2*pi/180)) < 1e-12 ? NaN : asin(LJZ_EKKMap_ClampToUnit(LJZ_EKKMap_tmpKxr / k0 / cos(LJZ_EKKMap_tmpA2*pi/180))) * 180/pi
            KillWaves/Z LJZ_EKKMap_tmpKxr, LJZ_EKKMap_tmpKyr, LJZ_EKKMap_tmpAA, LJZ_EKKMap_tmpBB, LJZ_EKKMap_tmpCC, LJZ_EKKMap_tmpDisc
        endif

        LJZ_EKKMap_tmpB2 -= scanOffset
        LJZ_EKKMap_tmpKxKy = LJZ_EKKMap_ClipToWave2D(src, LJZ_EKKMap_tmpA2(x)(y), LJZ_EKKMap_tmpB2(x)(y))
    else
        LJZ_EKKMap_tmpA2 = asin(LJZ_EKKMap_ClampToUnit(sqrt(x^2+y^2)/k0 * cos(atan2(y,x)-azimuth*pi/180))) * 180/pi
        LJZ_EKKMap_tmpB2 = abs(cos(LJZ_EKKMap_tmpA2*pi/180)) < 1e-12 ? NaN : asin(LJZ_EKKMap_ClampToUnit(sqrt(x^2+y^2)/k0 * sin(atan2(y,x)-azimuth*pi/180) / cos(LJZ_EKKMap_tmpA2*pi/180))) * 180/pi
        LJZ_EKKMap_tmpA2 -= tilt
        LJZ_EKKMap_tmpB2 -= scanOffset
        LJZ_EKKMap_tmpKxKy = LJZ_EKKMap_ClipToWave2D(src, LJZ_EKKMap_tmpA2(x)(y), LJZ_EKKMap_tmpB2(x)(y))
    endif

    KillWaves/Z LJZ_EKKMap_tmpKxKy_src, LJZ_EKKMap_tmpKx1, LJZ_EKKMap_tmpKy1, LJZ_EKKMap_tmpKx2, LJZ_EKKMap_tmpKy2, LJZ_EKKMap_tmpA2, LJZ_EKKMap_tmpB2
    return LJZ_EKKMap_tmpKxKy
End

Function/WAVE LJZ_EKKMap_CalcKxKz2D(srcIn, energyRel, workFunc, tilt, V0, degPixel, latticeA, latticeC)
    Wave srcIn
    Variable energyRel, workFunc, tilt, V0, degPixel, latticeA, latticeC

    Duplicate/O srcIn, LJZ_EKKMap_tmpKxKz_src
    Wave src = LJZ_EKKMap_tmpKxKz_src
    LJZ_EKKMap_SetRawAngleScale2D(src, degPixel)

    Variable facA = LJZ_EKKMap_KScaleA(latticeA)
    Variable facC = LJZ_EKKMap_KScaleC(latticeC)
    if (facA == 0 || facC == 0)
        Make/O/N=(2,2) LJZ_EKKMap_tmpKxKz = NaN
        return LJZ_EKKMap_tmpKxKz
    endif

    Duplicate/O src, LJZ_EKKMap_tmpKx2D, LJZ_EKKMap_tmpKz2D
    LJZ_EKKMap_tmpKx2D = (y - workFunc + energyRel) <= 0 ? NaN : facA * sqrt(y - workFunc + energyRel) * sin((x + tilt)*pi/180)
    LJZ_EKKMap_tmpKz2D = ((y - workFunc + energyRel) * cos((x + tilt)*pi/180)^2 + V0) <= 0 ? NaN : facC * sqrt((y - workFunc + energyRel) * cos((x + tilt)*pi/180)^2 + V0)

    Variable kxMin = WaveMin(LJZ_EKKMap_tmpKx2D)
    Variable kxMax = WaveMax(LJZ_EKKMap_tmpKx2D)
    Variable kzMin = WaveMin(LJZ_EKKMap_tmpKz2D)
    Variable kzMax = WaveMax(LJZ_EKKMap_tmpKz2D)

    if (!LJZ_EKKMap_IsFinite(kxMin) || !LJZ_EKKMap_IsFinite(kxMax) || kxMin == kxMax)
        Make/O/N=(2,2) LJZ_EKKMap_tmpKxKz = NaN
        return LJZ_EKKMap_tmpKxKz
    endif

    Variable nx = max(2, DimSize(src,0))
    Variable ny = max(2, round(abs((kzMax-kzMin)/(kxMax-kxMin))*(nx-1) + 1))

    Make/O/N=(nx,ny) LJZ_EKKMap_tmpKxKz, LJZ_EKKMap_tmpHv2D, LJZ_EKKMap_tmpAng2D
    SetScale/I x, kxMin, kxMax, LJZ_EKKMap_KUnitA(latticeA), LJZ_EKKMap_tmpKxKz, LJZ_EKKMap_tmpHv2D, LJZ_EKKMap_tmpAng2D
    SetScale/I y, kzMin, kzMax, LJZ_EKKMap_KUnitC(latticeC), LJZ_EKKMap_tmpKxKz, LJZ_EKKMap_tmpHv2D, LJZ_EKKMap_tmpAng2D

    LJZ_EKKMap_tmpHv2D = (x/facA)^2 + (y/facC)^2 - V0 + workFunc - energyRel
    LJZ_EKKMap_tmpAng2D = ((x/facA)^2 + (y/facC)^2 - V0) <= 0 ? NaN : asin(LJZ_EKKMap_ClampToUnit(x/facA / sqrt((x/facA)^2 + (y/facC)^2 - V0))) * 180/pi - tilt
    LJZ_EKKMap_tmpKxKz = LJZ_EKKMap_ClipToWave2D(src, LJZ_EKKMap_tmpAng2D(x)(y), LJZ_EKKMap_tmpHv2D(x)(y))

    KillWaves/Z LJZ_EKKMap_tmpKxKz_src, LJZ_EKKMap_tmpKx2D, LJZ_EKKMap_tmpKz2D, LJZ_EKKMap_tmpHv2D, LJZ_EKKMap_tmpAng2D
    return LJZ_EKKMap_tmpKxKz
End


// ============================================================================
//  Section 5. run kernels on selected waves
// ============================================================================

Function LJZ_EKKMap_RunKxKy_3D_TwoPass(w, outPath, hv, workFunc, FL, thetaAngle, azimuth, scanOffset, pixel, latticeA, geometry)
    Wave w
    String outPath
    Variable hv, workFunc, FL, thetaAngle, azimuth, scanOffset, pixel, latticeA, geometry

    Variable nz = DimSize(w,0)
    if (DimSize(w,1) <= 0 || DimSize(w,2) <= 0 || nz <= 0)
        DoAlert 0, "Invalid 3D wave for kx-ky. Expected energy × angle × scan-angle."
        return -1
    endif

    String tmpDF = LJZ_EKKMap_RecreateTempDF("TmpKxKySlices")
    Make/O/N=(nz) $(tmpDF + "xMin") = NaN
    Make/O/N=(nz) $(tmpDF + "xMax") = NaN
    Make/O/N=(nz) $(tmpDF + "yMin") = NaN
    Make/O/N=(nz) $(tmpDF + "yMax") = NaN
    Make/O/N=(nz) $(tmpDF + "nx") = NaN
    Make/O/N=(nz) $(tmpDF + "ny") = NaN
    Wave wXMin = $(tmpDF + "xMin")
    Wave wXMax = $(tmpDF + "xMax")
    Wave wYMin = $(tmpDF + "yMin")
    Wave wYMax = $(tmpDF + "yMax")
    Wave wNX = $(tmpDF + "nx")
    Wave wNY = $(tmpDF + "ny")

    Make/O/N=(2,2) $(LJZ_EKKMap_BaseDF() + ":tmpSlice2D") = NaN
    Make/O/N=(2,2) $(LJZ_EKKMap_BaseDF() + ":tmpCommonSlice") = NaN
    Wave tmpSlice = $(LJZ_EKKMap_BaseDF() + ":tmpSlice2D")
    Wave commonSlice = $(LJZ_EKKMap_BaseDF() + ":tmpCommonSlice")

    Variable iz
    Variable globalXMin = NaN
    Variable globalXMax = NaN
    Variable globalYMin = NaN
    Variable globalYMax = NaN
    Variable commonNX = 2
    Variable commonNY = 2
    Variable validCount = 0

    // Low-memory two-pass remap: pass 1 only records each slice's reachable k-window
    // and suggested grid size, then releases the temporary 2D map immediately.
    for (iz=0; iz<nz; iz+=1)
        Variable energyRel = DimOffset(w,0) + iz * DimDelta(w,0) - FL
        LJZ_EKKMap_MakeSliceFrom3D(w, iz, 0, tmpSlice)
        Duplicate/O LJZ_EKKMap_CalcKxKy2D(tmpSlice, energyRel, hv, workFunc, thetaAngle, azimuth, scanOffset, pixel, latticeA, geometry), $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
        Wave map2D = $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")

        if (DimSize(map2D,0) >= 2 && DimSize(map2D,1) >= 2)
            wXMin[iz] = LJZ_EKKMap_DimMin(map2D,0)
            wXMax[iz] = LJZ_EKKMap_DimMax(map2D,0)
            wYMin[iz] = LJZ_EKKMap_DimMin(map2D,1)
            wYMax[iz] = LJZ_EKKMap_DimMax(map2D,1)
            wNX[iz] = DimSize(map2D,0)
            wNY[iz] = DimSize(map2D,1)

            if (LJZ_EKKMap_IsFinite(wXMin[iz]) && LJZ_EKKMap_IsFinite(wXMax[iz]) && LJZ_EKKMap_IsFinite(wYMin[iz]) && LJZ_EKKMap_IsFinite(wYMax[iz]))
                globalXMin = LJZ_EKKMap_Min2(globalXMin, wXMin[iz])
                globalXMax = LJZ_EKKMap_Max2(globalXMax, wXMax[iz])
                globalYMin = LJZ_EKKMap_Min2(globalYMin, wYMin[iz])
                globalYMax = LJZ_EKKMap_Max2(globalYMax, wYMax[iz])
                commonNX = max(commonNX, round(wNX[iz]))
                commonNY = max(commonNY, round(wNY[iz]))
                validCount += 1
            endif
        endif
        KillWaves/Z $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
    endfor

    if (validCount <= 0 || !LJZ_EKKMap_IsFinite(globalXMin) || !LJZ_EKKMap_IsFinite(globalXMax) || !LJZ_EKKMap_IsFinite(globalYMin) || !LJZ_EKKMap_IsFinite(globalYMax) || globalXMin == globalXMax || globalYMin == globalYMax)
        Make/O/N=(2,2,nz) $outPath = NaN
        Wave outFail = $outPath
        SetScale/P z, DimOffset(w,0), DimDelta(w,0), WaveUnits(w,0), outFail
        KillWaves/Z $(LJZ_EKKMap_BaseDF() + ":tmpSlice2D"), $(LJZ_EKKMap_BaseDF() + ":tmpCommonSlice"), $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
        KillDataFolder/Z $(LJZ_EKKMap_BaseDF() + ":TmpKxKySlices")
        return 0
    endif

    Make/O/N=(commonNX,commonNY,nz) $outPath = NaN
    Wave out3D = $outPath
    SetScale/I x, globalXMin, globalXMax, LJZ_EKKMap_KUnitA(latticeA), out3D
    SetScale/I y, globalYMin, globalYMax, LJZ_EKKMap_KUnitA(latticeA), out3D
    SetScale/P z, DimOffset(w,0), DimDelta(w,0), WaveUnits(w,0), out3D

    // Pass 2 recomputes each slice, resamples it to the common global grid, and
    // writes directly into the output volume so we never cache all slice_i maps.
    for (iz=0; iz<nz; iz+=1)
        Variable energyRel2 = DimOffset(w,0) + iz * DimDelta(w,0) - FL
        if (!LJZ_EKKMap_IsFinite(wXMin[iz]) || !LJZ_EKKMap_IsFinite(wXMax[iz]) || !LJZ_EKKMap_IsFinite(wYMin[iz]) || !LJZ_EKKMap_IsFinite(wYMax[iz]))
            out3D[][][iz] = NaN
            continue
        endif

        LJZ_EKKMap_MakeSliceFrom3D(w, iz, 0, tmpSlice)
        Duplicate/O LJZ_EKKMap_CalcKxKy2D(tmpSlice, energyRel2, hv, workFunc, thetaAngle, azimuth, scanOffset, pixel, latticeA, geometry), $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
        Wave map2D2 = $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
        LJZ_EKKMap_Resample2DToCommonGrid(map2D2, globalXMin, globalXMax, globalYMin, globalYMax, commonNX, commonNY, commonSlice)
        out3D[][][iz] = commonSlice[p][q]
        KillWaves/Z $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
    endfor

    KillWaves/Z $(LJZ_EKKMap_BaseDF() + ":tmpSlice2D"), $(LJZ_EKKMap_BaseDF() + ":tmpCommonSlice"), $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
    KillDataFolder/Z $(LJZ_EKKMap_BaseDF() + ":TmpKxKySlices")
    return 0
End

Function LJZ_EKKMap_RunKxKz_3D_TwoPass(w, outPath, workFunc, FL, thetaAngle, V0, pixel, latticeA, latticeC)
    Wave w
    String outPath
    Variable workFunc, FL, thetaAngle, V0, pixel, latticeA, latticeC

    Variable nz = DimSize(w,0)
    if (DimSize(w,1) <= 0 || DimSize(w,2) <= 0 || nz <= 0)
        DoAlert 0, "Invalid 3D wave for kx-kz. Expected energy × angle × hv."
        return -1
    endif

    String tmpDF = LJZ_EKKMap_RecreateTempDF("TmpKxKzSlices")
    Make/O/N=(nz) $(tmpDF + "xMin") = NaN
    Make/O/N=(nz) $(tmpDF + "xMax") = NaN
    Make/O/N=(nz) $(tmpDF + "yMin") = NaN
    Make/O/N=(nz) $(tmpDF + "yMax") = NaN
    Make/O/N=(nz) $(tmpDF + "nx") = NaN
    Make/O/N=(nz) $(tmpDF + "ny") = NaN
    Wave wXMin = $(tmpDF + "xMin")
    Wave wXMax = $(tmpDF + "xMax")
    Wave wYMin = $(tmpDF + "yMin")
    Wave wYMax = $(tmpDF + "yMax")
    Wave wNX = $(tmpDF + "nx")
    Wave wNY = $(tmpDF + "ny")

    Make/O/N=(2,2) $(LJZ_EKKMap_BaseDF() + ":tmpSlice2D") = NaN
    Make/O/N=(2,2) $(LJZ_EKKMap_BaseDF() + ":tmpCommonSlice") = NaN
    Wave tmpSlice = $(LJZ_EKKMap_BaseDF() + ":tmpSlice2D")
    Wave commonSlice = $(LJZ_EKKMap_BaseDF() + ":tmpCommonSlice")

    Variable iz
    Variable globalXMin = NaN
    Variable globalXMax = NaN
    Variable globalYMin = NaN
    Variable globalYMax = NaN
    Variable commonNX = 2
    Variable commonNY = 2
    Variable validCount = 0

    // Low-memory two-pass remap: pass 1 only records slice bounds and preferred
    // grid sizes so large 3D runs do not keep every intermediate map in memory.
    for (iz=0; iz<nz; iz+=1)
        Variable energyRel = DimOffset(w,0) + iz * DimDelta(w,0) - FL
        LJZ_EKKMap_MakeSliceFrom3D(w, iz, 0, tmpSlice)
        Duplicate/O LJZ_EKKMap_CalcKxKz2D(tmpSlice, energyRel, workFunc, thetaAngle, V0, pixel, latticeA, latticeC), $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
        Wave map2D = $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")

        if (DimSize(map2D,0) >= 2 && DimSize(map2D,1) >= 2)
            wXMin[iz] = LJZ_EKKMap_DimMin(map2D,0)
            wXMax[iz] = LJZ_EKKMap_DimMax(map2D,0)
            wYMin[iz] = LJZ_EKKMap_DimMin(map2D,1)
            wYMax[iz] = LJZ_EKKMap_DimMax(map2D,1)
            wNX[iz] = DimSize(map2D,0)
            wNY[iz] = DimSize(map2D,1)

            if (LJZ_EKKMap_IsFinite(wXMin[iz]) && LJZ_EKKMap_IsFinite(wXMax[iz]) && LJZ_EKKMap_IsFinite(wYMin[iz]) && LJZ_EKKMap_IsFinite(wYMax[iz]))
                globalXMin = LJZ_EKKMap_Min2(globalXMin, wXMin[iz])
                globalXMax = LJZ_EKKMap_Max2(globalXMax, wXMax[iz])
                globalYMin = LJZ_EKKMap_Min2(globalYMin, wYMin[iz])
                globalYMax = LJZ_EKKMap_Max2(globalYMax, wYMax[iz])
                commonNX = max(commonNX, round(wNX[iz]))
                commonNY = max(commonNY, round(wNY[iz]))
                validCount += 1
            endif
        endif
        KillWaves/Z $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
    endfor

    if (validCount <= 0 || !LJZ_EKKMap_IsFinite(globalXMin) || !LJZ_EKKMap_IsFinite(globalXMax) || !LJZ_EKKMap_IsFinite(globalYMin) || !LJZ_EKKMap_IsFinite(globalYMax) || globalXMin == globalXMax || globalYMin == globalYMax)
        Make/O/N=(2,2,nz) $outPath = NaN
        Wave outFail = $outPath
        SetScale/P z, DimOffset(w,0), DimDelta(w,0), WaveUnits(w,0), outFail
        KillWaves/Z $(LJZ_EKKMap_BaseDF() + ":tmpSlice2D"), $(LJZ_EKKMap_BaseDF() + ":tmpCommonSlice"), $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
        KillDataFolder/Z $(LJZ_EKKMap_BaseDF() + ":TmpKxKzSlices")
        return 0
    endif

    Make/O/N=(commonNX,commonNY,nz) $outPath = NaN
    Wave out3D = $outPath
    SetScale/I x, globalXMin, globalXMax, LJZ_EKKMap_KUnitA(latticeA), out3D
    SetScale/I y, globalYMin, globalYMax, LJZ_EKKMap_KUnitC(latticeC), out3D
    SetScale/P z, DimOffset(w,0), DimDelta(w,0), WaveUnits(w,0), out3D

    // Pass 2 recomputes, resamples, and immediately stores each slice into out3D.
    for (iz=0; iz<nz; iz+=1)
        Variable energyRel2 = DimOffset(w,0) + iz * DimDelta(w,0) - FL
        if (!LJZ_EKKMap_IsFinite(wXMin[iz]) || !LJZ_EKKMap_IsFinite(wXMax[iz]) || !LJZ_EKKMap_IsFinite(wYMin[iz]) || !LJZ_EKKMap_IsFinite(wYMax[iz]))
            out3D[][][iz] = NaN
            continue
        endif

        LJZ_EKKMap_MakeSliceFrom3D(w, iz, 0, tmpSlice)
        Duplicate/O LJZ_EKKMap_CalcKxKz2D(tmpSlice, energyRel2, workFunc, thetaAngle, V0, pixel, latticeA, latticeC), $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
        Wave map2D2 = $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
        LJZ_EKKMap_Resample2DToCommonGrid(map2D2, globalXMin, globalXMax, globalYMin, globalYMax, commonNX, commonNY, commonSlice)
        out3D[][][iz] = commonSlice[p][q]
        KillWaves/Z $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
    endfor

    KillWaves/Z $(LJZ_EKKMap_BaseDF() + ":tmpSlice2D"), $(LJZ_EKKMap_BaseDF() + ":tmpCommonSlice"), $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
    KillDataFolder/Z $(LJZ_EKKMap_BaseDF() + ":TmpKxKzSlices")
    return 0
End

Function LJZ_EKKMap_RunEK()
    LJZ_EKKMap_EnsureDF()
    LJZ_EKKMap_SetCurrentMode(LJZ_EKKMap_Mode_EK)

    String listStr = LJZ_EKKMap_GetSelectedWaveList()
    Variable n = ItemsInList(listStr, ";")
    if (n <= 0)
        DoAlert 0, "No wave selected."
        return -1
    endif

    NVAR ThetaAngle = $(LJZ_EKKMap_BaseDF() + ":ThetaAngle")
    NVAR hv = $(LJZ_EKKMap_BaseDF() + ":hv")
    NVAR WorkFunc = $(LJZ_EKKMap_BaseDF() + ":WorkFunc")
    NVAR FL = $(LJZ_EKKMap_BaseDF() + ":FL")
    NVAR Pixel = $(LJZ_EKKMap_BaseDF() + ":Pixel")
    NVAR LatticeA = $(LJZ_EKKMap_BaseDF() + ":LatticeA")
    NVAR MDCKf = $(LJZ_EKKMap_BaseDF() + ":MDCKf")
    Variable is3D

    String outDF = LJZ_EKKMap_EnsureOutputDF("EK")
    Variable i
    for (i=0; i<n; i+=1)
        String wPath = StringFromList(i, listStr, ";")
        Wave/Z w = $wPath
        if (!WaveExists(w))
            continue
        endif

        String nm = NameOfWave(w)
        String outName = "ek_" + nm
        is3D = LJZ_EKKMap_Is3DWave(w)
        if (!LJZ_EKKMap_ValidateInputForEK(w, is3D))
            continue
        endif

        if (LJZ_EKKMap_Is2DWave(w))
            Duplicate/O LJZ_EKKMap_CalcEK2D(w, ThetaAngle, hv, WorkFunc, FL, Pixel, LatticeA, MDCKf), $(outDF + outName)
            Wave out2D = $(outDF + outName)
            LJZ_EKKMap_ShowResultWave(out2D, "Im_" + outName)
        elseif (LJZ_EKKMap_Is3DWave(w))
            Make/O/N=(2,2) $(LJZ_EKKMap_BaseDF() + ":tmpSlice2D") = NaN
            Wave tmpSlice = $(LJZ_EKKMap_BaseDF() + ":tmpSlice2D")

            Variable nz = DimSize(w,2)
            Variable iz
            Variable didAlloc = 0
            for (iz=0; iz<nz; iz+=1)
                // 物理计算固定按 angle × energy × stack 取 slice；Transpose 只用于 preview。
                LJZ_EKKMap_MakeSliceFrom3D_EK(w, iz, 0, tmpSlice)
                Duplicate/O LJZ_EKKMap_CalcEK2D(tmpSlice, ThetaAngle, hv, WorkFunc, FL, Pixel, LatticeA, MDCKf), $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
                Wave map2D = $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
                if (!didAlloc)
                    Make/O/N=(DimSize(map2D,0), DimSize(map2D,1), nz) $(outDF + outName)
                    SetScale/P x, DimOffset(map2D,0), DimDelta(map2D,0), WaveUnits(map2D,0), $(outDF + outName)
                    SetScale/P y, DimOffset(map2D,1), DimDelta(map2D,1), WaveUnits(map2D,1), $(outDF + outName)
                    SetScale/P z, DimOffset(w,2), DimDelta(w,2), WaveUnits(w,2), $(outDF + outName)
                    didAlloc = 1
                endif
                Wave out3D = $(outDF + outName)
                out3D[][][iz] = map2D[p][q]
            endfor
            Wave out3DShow = $(outDF + outName)
            LJZ_EKKMap_ShowResultWave(out3DShow, "Im_" + outName)
            KillWaves/Z $(LJZ_EKKMap_BaseDF() + ":tmpMapped2D")
            KillWaves/Z $(LJZ_EKKMap_BaseDF() + ":tmpSlice2D")
        endif
    endfor
    return 0
End

Function LJZ_EKKMap_RunKxKy()
    LJZ_EKKMap_EnsureDF()
    LJZ_EKKMap_SetCurrentMode(LJZ_EKKMap_Mode_KxKy)

    String listStr = LJZ_EKKMap_GetSelectedWaveList()
    Variable n = ItemsInList(listStr, ";")
    if (n <= 0)
        DoAlert 0, "No wave selected."
        return -1
    endif

    NVAR ThetaAngle = $(LJZ_EKKMap_BaseDF() + ":ThetaAngle")
    NVAR hv = $(LJZ_EKKMap_BaseDF() + ":hv")
    NVAR WorkFunc = $(LJZ_EKKMap_BaseDF() + ":WorkFunc")
    NVAR FL = $(LJZ_EKKMap_BaseDF() + ":FL")
    NVAR Pixel = $(LJZ_EKKMap_BaseDF() + ":Pixel")
    NVAR LatticeA = $(LJZ_EKKMap_BaseDF() + ":LatticeA")
    NVAR EnergyRel = $(LJZ_EKKMap_BaseDF() + ":EnergyRel")
    NVAR Azimuth = $(LJZ_EKKMap_BaseDF() + ":Azimuth")
    NVAR ScanOffset = $(LJZ_EKKMap_BaseDF() + ":ScanOffset")
    NVAR Geometry = $(LJZ_EKKMap_BaseDF() + ":Geometry")
    Variable is3D

    // 2D kx-ky uses panel EnergyRel as user-entered binding energy relative to FL.
    // 3D kx-ky ignores that panel field for per-slice mapping; each slice uses dim0 - FL.
    LJZ_EKKMap_SetLegacyEnergyCompat()

    String outDF = LJZ_EKKMap_EnsureOutputDF("KxKy")
    Variable i
    for (i=0; i<n; i+=1)
        String wPath = StringFromList(i, listStr, ";")
        Wave/Z w = $wPath
        if (!WaveExists(w))
            continue
        endif

        String nm = NameOfWave(w)
        String outName = "kxky_" + nm
        is3D = LJZ_EKKMap_Is3DWave(w)
        if (!LJZ_EKKMap_ValidateInputForKxKy(w, is3D))
            continue
        endif

        if (LJZ_EKKMap_Is2DWave(w))
            Duplicate/O LJZ_EKKMap_CalcKxKy2D(w, EnergyRel, hv, WorkFunc, ThetaAngle, Azimuth, ScanOffset, Pixel, LatticeA, Geometry), $(outDF + outName)
            Wave out2D = $(outDF + outName)
            LJZ_EKKMap_ShowResultWave(out2D, "Im_" + outName)
        elseif (LJZ_EKKMap_Is3DWave(w))
            LJZ_EKKMap_RunKxKy_3D_TwoPass(w, outDF + outName, hv, WorkFunc, FL, ThetaAngle, Azimuth, ScanOffset, Pixel, LatticeA, Geometry)
            Wave out3DShow = $(outDF + outName)
            LJZ_EKKMap_ShowResultWave(out3DShow, "Im_" + outName)
        endif
    endfor
    return 0
End

Function LJZ_EKKMap_RunKxKz()
    LJZ_EKKMap_EnsureDF()
    LJZ_EKKMap_SetCurrentMode(LJZ_EKKMap_Mode_KxKz)

    String listStr = LJZ_EKKMap_GetSelectedWaveList()
    Variable n = ItemsInList(listStr, ";")
    if (n <= 0)
        DoAlert 0, "No wave selected."
        return -1
    endif

    NVAR ThetaAngle = $(LJZ_EKKMap_BaseDF() + ":ThetaAngle")
    NVAR WorkFunc = $(LJZ_EKKMap_BaseDF() + ":WorkFunc")
    NVAR FL = $(LJZ_EKKMap_BaseDF() + ":FL")
    NVAR Pixel = $(LJZ_EKKMap_BaseDF() + ":Pixel")
    NVAR LatticeA = $(LJZ_EKKMap_BaseDF() + ":LatticeA")
    NVAR LatticeC = $(LJZ_EKKMap_BaseDF() + ":LatticeC")
    NVAR EnergyRel = $(LJZ_EKKMap_BaseDF() + ":EnergyRel")
    NVAR V0 = $(LJZ_EKKMap_BaseDF() + ":V0")
    Variable is3D

    // 2D kx-kz uses panel EnergyRel as user-entered binding energy relative to FL.
    // 3D kx-kz ignores that panel field for per-slice mapping; each slice uses dim0 - FL.
    LJZ_EKKMap_SetLegacyEnergyCompat()

    String outDF = LJZ_EKKMap_EnsureOutputDF("KxKz")
    Variable i
    for (i=0; i<n; i+=1)
        String wPath = StringFromList(i, listStr, ";")
        Wave/Z w = $wPath
        if (!WaveExists(w))
            continue
        endif

        String nm = NameOfWave(w)
        String outName = "kxkz_" + nm
        is3D = LJZ_EKKMap_Is3DWave(w)
        if (!LJZ_EKKMap_ValidateInputForKxKz(w, is3D))
            continue
        endif

        if (LJZ_EKKMap_Is2DWave(w))
            Duplicate/O LJZ_EKKMap_CalcKxKz2D(w, EnergyRel, WorkFunc, ThetaAngle, V0, Pixel, LatticeA, LatticeC), $(outDF + outName)
            Wave out2D = $(outDF + outName)
            LJZ_EKKMap_ShowResultWave(out2D, "Im_" + outName)
        elseif (LJZ_EKKMap_Is3DWave(w))
            LJZ_EKKMap_RunKxKz_3D_TwoPass(w, outDF + outName, WorkFunc, FL, ThetaAngle, V0, Pixel, LatticeA, LatticeC)
            Wave out3DShow = $(outDF + outName)
            LJZ_EKKMap_ShowResultWave(out3DShow, "Im_" + outName)
        endif
    endfor
    return 0
End


// ============================================================================
//  Section 6. panel callbacks
// ============================================================================

Function LJZ_EKKMap_SelectRow(row)
    Variable row

    if (LJZ_EKKMap_SetSingleSelection(row) != 0)
        LJZ_EKKMap_RestoreCurrentSelectionUI()
        LJZ_EKKMap_ShowCurrentWave()
        return -1
    endif

    LJZ_EKKMap_ClampPreviewZToCurrentWave()
    LJZ_EKKMap_RestoreCurrentSelectionUI()
    LJZ_EKKMap_RefreshWindowControls()
    LJZ_EKKMap_ShowCurrentWave()
    return 0
End

Function LJZ_EKKMap_SetSourceDF(dfStr)
    String dfStr

    String s = LJZ_EKKMap_df_with_colon(dfStr)
    if (!DataFolderExists(s))
        return -1
    endif

    SVAR sDF = $(LJZ_EKKMap_BaseDF() + ":SourceDF")
    SVAR sLastGood = $(LJZ_EKKMap_BaseDF() + ":SourceDFLastGood")
    sDF = s
    sLastGood = s
    LJZ_EKKMap_RebuildWaveList()
    LJZ_EKKMap_RefreshWindowControls()
    return 0
End

Proc LJZ_EKKMap_ButtonProc(ctrlName) : ButtonControl
    String ctrlName

    strswitch(ctrlName)
        case "btCurrent":
            LJZ_EKKMap_SetSourceDF(LJZ_EKKMap_GetSuggestedSourceDF())
            break
        case "btScan":
        case "btRefresh":
            LJZ_EKKMap_RebuildWaveList()
            break
        case "btPrevZ":
            NVAR PreviewZ1 = $(LJZ_EKKMap_BaseDF() + ":PreviewZ")
            PreviewZ1 -= 1
            LJZ_EKKMap_ClampPreviewZToCurrentWave()
            LJZ_EKKMap_RefreshWindowControls()
            LJZ_EKKMap_ShowCurrentWave()
            break
        case "btNextZ":
            NVAR PreviewZ2 = $(LJZ_EKKMap_BaseDF() + ":PreviewZ")
            PreviewZ2 += 1
            LJZ_EKKMap_ClampPreviewZToCurrentWave()
            LJZ_EKKMap_RefreshWindowControls()
            LJZ_EKKMap_ShowCurrentWave()
            break
        case "btModeEK":
            LJZ_EKKMap_SetCurrentMode(LJZ_EKKMap_Mode_EK)
            LJZ_EKKMap_RefreshWindowControls()
            LJZ_EKKMap_ShowCurrentWave()
            break
        case "btModeKxKy":
            LJZ_EKKMap_SetCurrentMode(LJZ_EKKMap_Mode_KxKy)
            LJZ_EKKMap_RefreshWindowControls()
            LJZ_EKKMap_ShowCurrentWave()
            break
        case "btModeKxKz":
            LJZ_EKKMap_SetCurrentMode(LJZ_EKKMap_Mode_KxKz)
            LJZ_EKKMap_RefreshWindowControls()
            LJZ_EKKMap_ShowCurrentWave()
            break
        case "btEK":
            LJZ_EKKMap_RunEK()
            break
        case "btKxKy":
            LJZ_EKKMap_RunKxKy()
            break
        case "btKxKz":
            LJZ_EKKMap_RunKxKz()
            break
    endswitch
End

Proc LJZ_EKKMap_SetVarProc(ctrlName, varNum, varStr, varName) : SetVariableControl
    String ctrlName
    Variable varNum
    String varStr
    String varName

    strswitch(ctrlName)
        case "svSourceDF":
            if (LJZ_EKKMap_SetSourceDF(varStr) != 0)
                DoAlert 0, "Invalid Source DF."
                LJZ_EKKMap_RestoreLastGoodSourceDF()
            endif
            break
        case "svPreviewZ":
            NVAR PreviewZ = $(LJZ_EKKMap_BaseDF() + ":PreviewZ")
            PreviewZ = round(varNum)
            LJZ_EKKMap_ClampPreviewZToCurrentWave()
            LJZ_EKKMap_RefreshWindowControls()
            LJZ_EKKMap_ShowCurrentWave()
            break
        default:
            LJZ_EKKMap_SetLegacyEnergyCompat()
            LJZ_EKKMap_ShowCurrentWave()
            break
    endswitch
End

Function LJZ_EKKMap_ListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    switch(lba.eventCode)
        case 1:
        case 4:
        case 5:
            LJZ_EKKMap_SelectRow(lba.row)
            break
    endswitch
    return 0
End

Proc LJZ_EKKMap_CheckProc(ctrlName, checked) : CheckBoxControl
    String ctrlName
    Variable checked

    // Transpose 只影响 panel preview，不允许参与实际物理映射。
    LJZ_EKKMap_ShowCurrentWave()
End


// ============================================================================
//  Section 7. panel
// ============================================================================

Function LJZ_EKKMap_OpenPanel()
    LJZ_EKKMap_EnsureDF()

    String p = LJZ_EKKMap_PanelName()
    DoWindow/F $p
    if (V_flag == 0)
        NewPanel/N=$p /W=(80,80,1040,670) as "E-k / kx-ky / kx-kz"
    else
        DoWindow/F $p
        LJZ_EKKMap_CreateGraphSubwindow()
        return 0
    endif

    SetVariable svSourceDF,pos={10,10},size={455,20},title="Source DF"
    // 绑定到真正的 SourceDF 字符串变量，避免只改控件内部 _STR: 文本。
    SetVariable svSourceDF,value=root:ARPES_LJZ:EKKMap:SourceDF,proc=LJZ_EKKMap_SetVarProc

    Button btCurrent,pos={480,8},size={80,24},title="Current",proc=LJZ_EKKMap_ButtonProc
    Button btScan,pos={575,8},size={70,24},title="Scan",proc=LJZ_EKKMap_ButtonProc

    // 严格单选：当前 preview / run / WaveSel 始终对应同一行。
    ListBox lbWave,pos={10,42},size={225,360},listWave=$(LJZ_EKKMap_BaseDF() + ":LB_Disp"),selWave=$(LJZ_EKKMap_BaseDF() + ":LB_Sel"),mode=1,proc=LJZ_EKKMap_ListBoxProc

    Button btRefresh,pos={10,414},size={80,26},title="Refresh",proc=LJZ_EKKMap_ButtonProc
    Button btPrevZ,pos={100,414},size={54,26},title="Z-",proc=LJZ_EKKMap_ButtonProc
    Button btNextZ,pos={160,414},size={54,26},title="Z+",proc=LJZ_EKKMap_ButtonProc
    SetVariable svPreviewZ,pos={10,448},size={205,20},title="Preview z"
    SetVariable svPreviewZ,variable=$(LJZ_EKKMap_BaseDF() + ":PreviewZ"),proc=LJZ_EKKMap_SetVarProc

    Button btModeEK,pos={10,478},size={64,22},title="EK",proc=LJZ_EKKMap_ButtonProc
    Button btModeKxKy,pos={80,478},size={64,22},title="KxKy",proc=LJZ_EKKMap_ButtonProc
    Button btModeKxKz,pos={150,478},size={64,22},title="KxKz",proc=LJZ_EKKMap_ButtonProc

    TitleBox tbCur,pos={250,370},size={700,18},frame=0,title="Current: none"

    GroupBox gbGeom,pos={250,402},size={320,118},title="Geometry / Energy"
    GroupBox gbGeom,font="Arial",fSize=10,fStyle=2

    SetVariable svTilt,pos={265,424},size={135,20},title="Tilt"
    SetVariable svTilt,variable=$(LJZ_EKKMap_BaseDF() + ":ThetaAngle"),proc=LJZ_EKKMap_SetVarProc

    SetVariable svAz,pos={415,424},size={135,20},title="Azimuth"
    SetVariable svAz,variable=$(LJZ_EKKMap_BaseDF() + ":Azimuth"),proc=LJZ_EKKMap_SetVarProc

    SetVariable svOffset,pos={265,450},size={135,20},title="Scan offset"
    SetVariable svOffset,variable=$(LJZ_EKKMap_BaseDF() + ":ScanOffset"),proc=LJZ_EKKMap_SetVarProc

    SetVariable svEnergy,pos={415,450},size={135,20},title="E_rel"
    SetVariable svEnergy,variable=$(LJZ_EKKMap_BaseDF() + ":EnergyRel"),proc=LJZ_EKKMap_SetVarProc

    CheckBox cbGeometry,pos={265,478},size={120,18},title="WTZ geometry"
    CheckBox cbGeometry,variable=$(LJZ_EKKMap_BaseDF() + ":Geometry"),proc=LJZ_EKKMap_CheckProc

    CheckBox cbTranspose,pos={415,478},size={90,18},title="Transpose"
    CheckBox cbTranspose,variable=$(LJZ_EKKMap_BaseDF() + ":Transpose"),proc=LJZ_EKKMap_CheckProc

    GroupBox gbPhoto,pos={590,402},size={350,118},title="Photon / lattice"
    GroupBox gbPhoto,font="Arial",fSize=10,fStyle=2

    SetVariable svHv,pos={605,424},size={150,20},title="hv"
    SetVariable svHv,variable=$(LJZ_EKKMap_BaseDF() + ":hv"),proc=LJZ_EKKMap_SetVarProc

    SetVariable svWF,pos={775,424},size={150,20},title="WorkFunc"
    SetVariable svWF,variable=$(LJZ_EKKMap_BaseDF() + ":WorkFunc"),proc=LJZ_EKKMap_SetVarProc

    SetVariable svFL,pos={605,450},size={150,20},title="Fermi E"
    SetVariable svFL,variable=$(LJZ_EKKMap_BaseDF() + ":FL"),proc=LJZ_EKKMap_SetVarProc

    SetVariable svPixel,pos={775,450},size={150,20},title="deg/pixel"
    SetVariable svPixel,variable=$(LJZ_EKKMap_BaseDF() + ":Pixel"),proc=LJZ_EKKMap_SetVarProc

    SetVariable svA,pos={605,478},size={100,20},title="a"
    SetVariable svA,variable=$(LJZ_EKKMap_BaseDF() + ":LatticeA"),proc=LJZ_EKKMap_SetVarProc

    SetVariable svC,pos={715,478},size={100,20},title="c"
    SetVariable svC,variable=$(LJZ_EKKMap_BaseDF() + ":LatticeC"),proc=LJZ_EKKMap_SetVarProc

    SetVariable svV0,pos={825,478},size={100,20},title="V0"
    SetVariable svV0,variable=$(LJZ_EKKMap_BaseDF() + ":V0"),proc=LJZ_EKKMap_SetVarProc

    GroupBox gbRun,pos={250,534},size={690,86},title="Run"
    GroupBox gbRun,font="Arial",fSize=10,fStyle=2

    SetVariable svMDCKf,pos={265,560},size={150,20},title="MDC K_F shift"
    SetVariable svMDCKf,variable=$(LJZ_EKKMap_BaseDF() + ":MDCKf"),proc=LJZ_EKKMap_SetVarProc

    Button btEK,pos={445,552},size={120,32},title="Calc E-k",proc=LJZ_EKKMap_ButtonProc
    Button btKxKy,pos={590,552},size={120,32},title="Calc kx-ky",proc=LJZ_EKKMap_ButtonProc
    Button btKxKz,pos={735,552},size={120,32},title="Calc kx-kz",proc=LJZ_EKKMap_ButtonProc

    TitleBox tbNote,pos={265,592},size={650,18},frame=0,title="Single-select run target = current preview. 2D K-map uses E_rel; 3D K-map slice energy comes from dim0-FL."

    LJZ_EKKMap_CreateGraphSubwindow()
    LJZ_EKKMap_RefreshWindowControls()
    LJZ_EKKMap_RefreshTitleBoxes()
    return 0
End


// ============================================================================
//  Section 8. entry
// ============================================================================

Function LJZ_EKKMap()
    String oldDF = GetDataFolder(1)
    LJZ_EKKMap_EnsureDF()
    LJZ_EKKMap_OpenPanel()

    SVAR sDF = $(LJZ_EKKMap_BaseDF() + ":SourceDF")
    if (!DataFolderExists(sDF))
        sDF = LJZ_EKKMap_GetSuggestedSourceDF()
    endif

    LJZ_EKKMap_RebuildWaveList()
    SetDataFolder oldDF
    return 0
End
