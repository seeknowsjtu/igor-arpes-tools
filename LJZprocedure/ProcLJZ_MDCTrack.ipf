#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma DefaultTab={3,20,4}

// ============================================================================
//  ProcLJZ_MDCTrack : MDC reference-frame tracking and peak-position correction
//
//  负责：
//    1) 从用户指定的 1D / 2D / 3D reference wave 构造一条 RefProfile(k)。
//    2) 从每个 target 2D / 3D wave 的高 binding-energy / band-bottom 窗口构造 TargetProfile(k)。
//    3) 用 normalized cross-correlation 搜索 target 相对 reference 的 k 轴平移 dK_toRef，
//       可选同时搜索一个小范围 scale_toRef。
//    4) 输出每个 target layer 的 dK_toRef / scale_toRef / similarity / flag。
//    5) 对已经拟合出的 MDC peak position wave 做坐标校正：
//          k_corr = kCenter + scale_toRef * (k_raw - kCenter) + dK_toRef
//
//  不负责：
//    - MDC 多峰拟合本身。
//    - 完整 2D/3D ARPES 几何重建。
//    - 覆盖原始 MDC 或原始 peak position。
//
//  输入约定：
//    - 1D wave: dim0 = kparallel，直接作为 reference profile。
//    - 2D wave: dim0 = energy，dim1 = kparallel。
//    - 3D wave: dim0 = energy，dim1 = kparallel，dim2 = stack(t/delay/hv)。
//
//  输出约定：
//    root:ARPES_LJZ:MDCTrack_RUNS:<runName>:
//      ref_profile             // 1D reference profile on its k scale
//      ref_profile_proc        // preprocessed reference profile
//      target_path             // text wave, one row per registered target layer
//      target_layer            // layer index in target wave; 0 for 2D wave
//      dK_toRef                // correction to add to raw peak positions, in k units
//      scale_toRef             // scale around kCenter; 1 for shift-only
//      similarity              // best local Pearson correlation coefficient
//      residual                // normalized RMS residual after alignment
//      flag                    // 0 OK; 1 low corr; 2 shift at bound; 3 bad scale; 4 too few points; 5 wave error
//      nPairs                  // number of valid points used in the best correlation
//      nPairsFrac              // nPairs divided by the number of k-window points
//      flag_reason             // text explanation for each flag
//      corr_vs_shift           // 2D diagnostic image: row x shift, corr at best scale
//      corr_shift_axis         // shift-axis values used by corr_vs_shift
//      corr_vs_scale           // 2D diagnostic image: row x scale, corr at best shift
//      corr_scale_axis         // scale-axis values used by corr_vs_scale
//      kPeak_corr              // optional corrected peak positions written by Correct Peak button
//      ApplyCorrLastOutputList // optional list of full-data waves written by Apply Corr
//
//  推荐用法：
//    1) 打开 ARPES_LJZ -> 2026MDCTrack_LJZ。
//    2) 填 RefWavePath，设置 RefE0/RefE1 和 K0/K1。
//    3) Build Reference。
//    4) 填 TargetDF，Refresh Target List，Register Selected 或 Register All。
//    5) 如果已经有 peak position wave，填 PeakRawPath，Correct Peak Wave。
//    6) 如需把 dK/scale 应用到完整 1D/2D/3D 数据，设置 ApplySuffix，点击 Apply Corr。
// ============================================================================

Menu "ARPES_LJZ"
    "2026MDCTrack_LJZ", LJZ_MDCTrack_OpenPanel()
End

// ============================================================================
// Section 0. Paths / state
// ============================================================================

Function/S LJZ_MDCTrack_BaseDF()
    return "root:ARPES_LJZ:MDCTrack"
End

Function/S LJZ_MDCTrack_RunRoot()
    return "root:ARPES_LJZ:MDCTrack_RUNS"
End

Function/S LJZ_MDCTrack_PanelName()
    return "LJZ_MDCTrack_Panel"
End

Function/S LJZ_MDCTrack_GraphName()
    return "LJZ_MDCTrack_Graph"
End

Function/S LJZ_MDCTrack_df_with_colon(inStr)
    String inStr

    String s
    s = inStr

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

Function LJZ_MDCTrack_EnsureDataFolderPath(dfPath)
    String dfPath

    String df
    df = LJZ_MDCTrack_df_with_colon(dfPath)

    String oldDF
    oldDF = GetDataFolder(1)

    NewDataFolder/O/S root:ARPES_LJZ

    Variable i
    Variable n
    String accum
    String item
    accum = "root:ARPES_LJZ:"

    String rest
    rest = ReplaceString("root:ARPES_LJZ:", df, "")
    n = ItemsInList(rest, ":")

    for (i = 0; i < n; i += 1)
        item = StringFromList(i, rest, ":")
        if (strlen(item) > 0)
            accum += item + ":"
            NewDataFolder/O $accum
        endif
    endfor

    SetDataFolder oldDF
    return 0
End

Function LJZ_MDCTrack_EnsureDF()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O $(LJZ_MDCTrack_BaseDF())
    NewDataFolder/O $(LJZ_MDCTrack_RunRoot())

    SVAR/Z refPath = $(LJZ_MDCTrack_BaseDF() + ":RefWavePath")
    if (!SVAR_Exists(refPath))
        String/G $(LJZ_MDCTrack_BaseDF() + ":RefWavePath") = ""
    endif

    SVAR/Z targetDF = $(LJZ_MDCTrack_BaseDF() + ":TargetDF")
    if (!SVAR_Exists(targetDF))
        String/G $(LJZ_MDCTrack_BaseDF() + ":TargetDF") = "root:"
    endif

    NVAR/Z recursive = $(LJZ_MDCTrack_BaseDF() + ":Recursive")
    if (!NVAR_Exists(recursive))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":Recursive") = 0
    endif

    SVAR/Z targetSel = $(LJZ_MDCTrack_BaseDF() + ":TargetWaveSel")
    if (!SVAR_Exists(targetSel))
        String/G $(LJZ_MDCTrack_BaseDF() + ":TargetWaveSel") = ""
    endif

    SVAR/Z runName = $(LJZ_MDCTrack_BaseDF() + ":RunName")
    if (!SVAR_Exists(runName))
        String/G $(LJZ_MDCTrack_BaseDF() + ":RunName") = "MDCTrack_run"
    endif

    SVAR/Z runDF = $(LJZ_MDCTrack_BaseDF() + ":RunDF")
    if (!SVAR_Exists(runDF))
        String/G $(LJZ_MDCTrack_BaseDF() + ":RunDF") = ""
    endif

    SVAR/Z peakRaw = $(LJZ_MDCTrack_BaseDF() + ":PeakRawPath")
    if (!SVAR_Exists(peakRaw))
        String/G $(LJZ_MDCTrack_BaseDF() + ":PeakRawPath") = ""
    endif

    SVAR/Z applySuffix = $(LJZ_MDCTrack_BaseDF() + ":ApplySuffix")
    if (!SVAR_Exists(applySuffix))
        String/G $(LJZ_MDCTrack_BaseDF() + ":ApplySuffix") = "_corr"
    endif

    SVAR/Z applyLastOut = $(LJZ_MDCTrack_BaseDF() + ":ApplyCorrLastOutputList")
    if (!SVAR_Exists(applyLastOut))
        String/G $(LJZ_MDCTrack_BaseDF() + ":ApplyCorrLastOutputList") = ""
    endif

    NVAR/Z applySkipFlagged = $(LJZ_MDCTrack_BaseDF() + ":ApplySkipFlagged")
    if (!NVAR_Exists(applySkipFlagged))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":ApplySkipFlagged") = 0
    endif

    NVAR/Z applyOutputToRunDF = $(LJZ_MDCTrack_BaseDF() + ":ApplyOutputToRunDF")
    if (!NVAR_Exists(applyOutputToRunDF))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":ApplyOutputToRunDF") = 0
    endif

    SVAR/Z status = $(LJZ_MDCTrack_BaseDF() + ":Status")
    if (!SVAR_Exists(status))
        String/G $(LJZ_MDCTrack_BaseDF() + ":Status") = "Ready."
    endif

    NVAR/Z usePhysE = $(LJZ_MDCTrack_BaseDF() + ":UsePhysE")
    if (!NVAR_Exists(usePhysE))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":UsePhysE") = 1
    endif

    NVAR/Z refE0 = $(LJZ_MDCTrack_BaseDF() + ":RefE0")
    if (!NVAR_Exists(refE0))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":RefE0") = -0.60
    endif

    NVAR/Z refE1 = $(LJZ_MDCTrack_BaseDF() + ":RefE1")
    if (!NVAR_Exists(refE1))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":RefE1") = -0.30
    endif

    NVAR/Z usePhysK = $(LJZ_MDCTrack_BaseDF() + ":UsePhysK")
    if (!NVAR_Exists(usePhysK))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":UsePhysK") = 1
    endif

    NVAR/Z k0 = $(LJZ_MDCTrack_BaseDF() + ":K0")
    if (!NVAR_Exists(k0))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":K0") = -0.20
    endif

    NVAR/Z k1 = $(LJZ_MDCTrack_BaseDF() + ":K1")
    if (!NVAR_Exists(k1))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":K1") = 0.20
    endif

    NVAR/Z refStack0 = $(LJZ_MDCTrack_BaseDF() + ":RefStack0")
    if (!NVAR_Exists(refStack0))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":RefStack0") = 0
    endif

    NVAR/Z refStack1 = $(LJZ_MDCTrack_BaseDF() + ":RefStack1")
    if (!NVAR_Exists(refStack1))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":RefStack1") = 0
    endif

    NVAR/Z maxShift = $(LJZ_MDCTrack_BaseDF() + ":MaxShift")
    if (!NVAR_Exists(maxShift))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":MaxShift") = 0.030
    endif

    NVAR/Z shiftSubDiv = $(LJZ_MDCTrack_BaseDF() + ":ShiftSubDiv")
    if (!NVAR_Exists(shiftSubDiv))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":ShiftSubDiv") = 5
    endif

    NVAR/Z corrThresh = $(LJZ_MDCTrack_BaseDF() + ":CorrThresh")
    if (!NVAR_Exists(corrThresh))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":CorrThresh") = 0.85
    endif

    NVAR/Z preprocess = $(LJZ_MDCTrack_BaseDF() + ":PreprocessMode")
    if (!NVAR_Exists(preprocess))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":PreprocessMode") = 1
    endif

    NVAR/Z smoothN = $(LJZ_MDCTrack_BaseDF() + ":SmoothN")
    if (!NVAR_Exists(smoothN))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":SmoothN") = 3
    endif

    NVAR/Z fitScale = $(LJZ_MDCTrack_BaseDF() + ":FitScale")
    if (!NVAR_Exists(fitScale))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":FitScale") = 0
    endif

    NVAR/Z scaleMin = $(LJZ_MDCTrack_BaseDF() + ":ScaleMin")
    if (!NVAR_Exists(scaleMin))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":ScaleMin") = 0.98
    endif

    NVAR/Z scaleMax = $(LJZ_MDCTrack_BaseDF() + ":ScaleMax")
    if (!NVAR_Exists(scaleMax))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":ScaleMax") = 1.02
    endif

    NVAR/Z scaleN = $(LJZ_MDCTrack_BaseDF() + ":ScaleN")
    if (!NVAR_Exists(scaleN))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":ScaleN") = 9
    endif

    NVAR/Z kCenter = $(LJZ_MDCTrack_BaseDF() + ":KCenter")
    if (!NVAR_Exists(kCenter))
        Variable/G $(LJZ_MDCTrack_BaseDF() + ":KCenter") = 0
    endif

    Wave/T/Z wDisp = $(LJZ_MDCTrack_BaseDF() + ":LB_Disp")
    if (!WaveExists(wDisp))
        Make/O/T/N=0 $(LJZ_MDCTrack_BaseDF() + ":LB_Disp")
    endif

    Wave/T/Z wPath = $(LJZ_MDCTrack_BaseDF() + ":LB_Path")
    if (!WaveExists(wPath))
        Make/O/T/N=0 $(LJZ_MDCTrack_BaseDF() + ":LB_Path")
    endif

    Wave/Z wSel = $(LJZ_MDCTrack_BaseDF() + ":LB_Sel")
    if (!WaveExists(wSel))
        Make/O/N=0 $(LJZ_MDCTrack_BaseDF() + ":LB_Sel") = 0
    endif

    return 0
End

// ============================================================================
// Section 1. Safe helpers
// ============================================================================

Function LJZ_MDCTrack_IsNumericWave(w)
    Wave w

    if (WaveType(w, 1) != 1)
        return 0
    endif

    return 1
End

Function LJZ_MDCTrack_IsAllowedSourceWave(w)
    Wave w

    Variable nd
    nd = WaveDims(w)

    if (LJZ_MDCTrack_IsNumericWave(w) == 0)
        return 0
    endif

    if (nd < 1 || nd > 3)
        return 0
    endif

    if (DimSize(w, 0) <= 1)
        return 0
    endif

    if (nd >= 2)
        if (DimSize(w, 1) <= 1)
            return 0
        endif
    endif

    return 1
End

Function/S LJZ_MDCTrack_SafeRunName(inStr)
    String inStr

    String s
    s = inStr
    if (strlen(s) == 0)
        s = "MDCTrack_run"
    endif

    s = CleanupName(s, 0)
    if (strlen(s) == 0)
        s = "MDCTrack_run"
    endif

    return s
End

Function LJZ_MDCTrack_WindowToIndex(off, delta, n, usePhys, v0In, v1In, idxLoOut, idxHiOut)
    Variable off
    Variable delta
    Variable n
    Variable usePhys
    Variable v0In
    Variable v1In
    Variable &idxLoOut
    Variable &idxHiOut

    Variable a
    Variable b
    Variable lo
    Variable hi

    if (n <= 0)
        idxLoOut = -1
        idxHiOut = -1
        return -1
    endif

    if (usePhys != 0)
        if (delta == 0)
            idxLoOut = -1
            idxHiOut = -1
            return -2
        endif
        a = (v0In - off) / delta
        b = (v1In - off) / delta
    else
        a = v0In
        b = v1In
    endif

    if (a <= b)
        lo = floor(a + 0.5)
        hi = floor(b + 0.5)
    else
        lo = floor(b + 0.5)
        hi = floor(a + 0.5)
    endif

    lo = max(0, lo)
    hi = min(n - 1, hi)

    if (hi < lo)
        idxLoOut = -1
        idxHiOut = -1
        return -3
    endif

    idxLoOut = lo
    idxHiOut = hi
    return 0
End

Function LJZ_MDCTrack_ScaledX(w, i)
    Wave w
    Variable i

    return DimOffset(w, 0) + DimDelta(w, 0) * i
End

Function LJZ_MDCTrack_InterpScaled(w, xVal)
    Wave w
    Variable xVal

    Variable n
    Variable off
    Variable del
    Variable pos
    Variable i0
    Variable frac
    Variable v0
    Variable v1

    n = numpnts(w)
    if (n <= 0)
        return NaN
    endif

    off = DimOffset(w, 0)
    del = DimDelta(w, 0)
    if (del == 0)
        return NaN
    endif

    pos = (xVal - off) / del
    i0 = floor(pos)
    frac = pos - i0

    if (i0 < 0 || i0 >= n - 1)
        if (abs(pos) < 1e-9)
            return w[0]
        endif
        if (abs(pos - (n - 1)) < 1e-9)
            return w[n - 1]
        endif
        return NaN
    endif

    v0 = w[i0]
    v1 = w[i0 + 1]
    if (numtype(v0) != 0 || numtype(v1) != 0)
        return NaN
    endif

    return v0 * (1 - frac) + v1 * frac
End

Function LJZ_MDCTrack_CountFiniteInWave(w)
    Wave w

    Variable i
    Variable n
    Variable c

    n = numpnts(w)
    c = 0
    for (i = 0; i < n; i += 1)
        if (numtype(w[i]) == 0)
            c += 1
        endif
    endfor

    return c
End

Function LJZ_MDCTrack_CountKWindowPoints(refW, k0In, k1In, usePhysK)
    Wave refW
    Variable k0In
    Variable k1In
    Variable usePhysK

    Variable kLo
    Variable kHi
    Variable ret

    ret = LJZ_MDCTrack_WindowToIndex(DimOffset(refW, 0), DimDelta(refW, 0), numpnts(refW), usePhysK, k0In, k1In, kLo, kHi)
    if (ret != 0)
        return 0
    endif

    return kHi - kLo + 1
End

Function/S LJZ_MDCTrack_PreprocessErrorText(errCode)
    Variable errCode

    if (errCode == -1)
        return "empty profile"
    elseif (errCode == -2)
        return "too few finite points after preprocessing"
    elseif (errCode == -3)
        return "zero variance after preprocessing"
    endif

    return "preprocess failed"
End

Function/S LJZ_MDCTrack_FlagText(flagValue)
    Variable flagValue

    if (numtype(flagValue) != 0)
        return "not evaluated"
    endif
    if (flagValue == 0)
        return "OK"
    elseif (flagValue == 1)
        return "low correlation"
    elseif (flagValue == 2)
        return "shift near boundary"
    elseif (flagValue == 3)
        return "scale near boundary"
    elseif (flagValue == 4)
        return "too few valid pairs"
    elseif (flagValue == 5)
        return "wave or preprocessing error"
    endif

    return "unknown flag"
End

Function/S LJZ_MDCTrack_RunLabelFromDF(runDFIn)
    String runDFIn

    String s
    String label
    Variable n

    s = LJZ_MDCTrack_df_with_colon(runDFIn)
    s = RemoveEnding(s, ":")
    n = ItemsInList(s, ":")
    if (n <= 0)
        return "MDCTrack_run"
    endif

    label = StringFromList(n - 1, s, ":")
    label = CleanupName(label, 0)
    if (strlen(label) == 0)
        label = "MDCTrack_run"
    endif
    if (strlen(label) > 45)
        label = label[0, 44]
    endif

    return label
End

Function/S LJZ_MDCTrack_GraphNameForRun(prefix, runDFIn)
    String prefix
    String runDFIn

    String name
    name = CleanupName(prefix + LJZ_MDCTrack_RunLabelFromDF(runDFIn), 0)
    if (strlen(name) == 0)
        name = prefix + "MDCTrack_run"
    endif
    if (strlen(name) > 60)
        name = name[0, 59]
    endif
    return name
End

Function LJZ_MDCTrack_EnsureLandscapeWaves(runDF, nRowsNeed, nShift, nScale, maxShift, shiftStep, scaleLow, scaleHigh, fitScale)
    String runDF
    Variable nRowsNeed
    Variable nShift
    Variable nScale
    Variable maxShift
    Variable shiftStep
    Variable scaleLow
    Variable scaleHigh
    Variable fitScale

    String df
    Variable totalRows
    Variable oldRows
    Variable i
    Variable j
    Variable scaleStep

    df = LJZ_MDCTrack_df_with_colon(runDF)
    LJZ_MDCTrack_EnsureDataFolderPath(df)

    if (nRowsNeed < 1)
        nRowsNeed = 1
    endif
    if (nShift < 1)
        nShift = 1
    endif
    if (nScale < 1)
        nScale = 1
    endif

    totalRows = nRowsNeed
    Wave/T/Z targetPath = $(df + "target_path")
    if (WaveExists(targetPath))
        totalRows = max(totalRows, numpnts(targetPath))
    endif

    Wave/Z corrShift = $(df + "corr_vs_shift")
    if (!WaveExists(corrShift) || DimSize(corrShift, 1) != nShift)
        if (WaveExists(corrShift) && DimSize(corrShift, 0) > 0 && DimSize(corrShift, 1) != nShift)
            Print "WARNING: corr_vs_shift column count changed inside an existing run. Rebuilding corr_vs_shift; previous landscape values will be cleared."
        endif
        Make/O/D/N=(totalRows, nShift) $(df + "corr_vs_shift") = NaN
    else
        oldRows = DimSize(corrShift, 0)
        if (oldRows < totalRows)
            Redimension/N=(totalRows, nShift) corrShift
            for (i = oldRows; i < totalRows; i += 1)
                for (j = 0; j < nShift; j += 1)
                    corrShift[i][j] = NaN
                endfor
            endfor
        endif
    endif
    Wave corrShift2 = $(df + "corr_vs_shift")
    SetScale/P x, 0, 1, "row", corrShift2
    SetScale/P y, -maxShift, shiftStep, "dK", corrShift2

    Make/O/D/N=(nShift) $(df + "corr_shift_axis")
    Wave shiftAxis = $(df + "corr_shift_axis")
    for (i = 0; i < nShift; i += 1)
        shiftAxis[i] = -maxShift + i * shiftStep
    endfor
    SetScale/P x, -maxShift, shiftStep, "dK", shiftAxis

    Wave/Z corrScale = $(df + "corr_vs_scale")
    if (!WaveExists(corrScale) || DimSize(corrScale, 1) != nScale)
        if (WaveExists(corrScale) && DimSize(corrScale, 0) > 0 && DimSize(corrScale, 1) != nScale)
            Print "WARNING: corr_vs_scale column count changed inside an existing run. Rebuilding corr_vs_scale; previous landscape values will be cleared."
        endif
        Make/O/D/N=(totalRows, nScale) $(df + "corr_vs_scale") = NaN
    else
        oldRows = DimSize(corrScale, 0)
        if (oldRows < totalRows)
            Redimension/N=(totalRows, nScale) corrScale
            for (i = oldRows; i < totalRows; i += 1)
                for (j = 0; j < nScale; j += 1)
                    corrScale[i][j] = NaN
                endfor
            endfor
        endif
    endif
    Wave corrScale2 = $(df + "corr_vs_scale")
    SetScale/P x, 0, 1, "row", corrScale2
    if (nScale <= 1 || fitScale == 0)
        SetScale/P y, 1, 1, "scale", corrScale2
    else
        scaleStep = (scaleHigh - scaleLow) / (nScale - 1)
        SetScale/P y, scaleLow, scaleStep, "scale", corrScale2
    endif

    Make/O/D/N=(nScale) $(df + "corr_scale_axis")
    Wave scaleAxis = $(df + "corr_scale_axis")
    if (nScale <= 1 || fitScale == 0)
        scaleAxis[0] = 1
        SetScale/P x, 1, 1, "scale", scaleAxis
    else
        scaleStep = (scaleHigh - scaleLow) / (nScale - 1)
        for (i = 0; i < nScale; i += 1)
            scaleAxis[i] = scaleLow + i * scaleStep
        endfor
        SetScale/P x, scaleLow, scaleStep, "scale", scaleAxis
    endif

    return 0
End


Function LJZ_MDCTrack_SetResultRowScale(runDF)
    String runDF

    String df
    df = LJZ_MDCTrack_df_with_colon(runDF)

    Wave/Z dK = $(df + "dK_toRef")
    if (WaveExists(dK))
        SetScale/P x, 0, 1, "row", dK
    endif

    Wave/Z sc = $(df + "scale_toRef")
    if (WaveExists(sc))
        SetScale/P x, 0, 1, "row", sc
    endif

    Wave/Z corr = $(df + "similarity")
    if (WaveExists(corr))
        SetScale/P x, 0, 1, "row", corr
    endif

    Wave/Z res = $(df + "residual")
    if (WaveExists(res))
        SetScale/P x, 0, 1, "row", res
    endif

    Wave/Z flg = $(df + "flag")
    if (WaveExists(flg))
        SetScale/P x, 0, 1, "row", flg
    endif

    Wave/Z np = $(df + "nPairs")
    if (WaveExists(np))
        SetScale/P x, 0, 1, "row", np
    endif

    Wave/Z frac = $(df + "nPairsFrac")
    if (WaveExists(frac))
        SetScale/P x, 0, 1, "row", frac
    endif

    Wave/Z bsi = $(df + "best_shift_index")
    if (WaveExists(bsi))
        SetScale/P x, 0, 1, "row", bsi
    endif

    Wave/Z bci = $(df + "best_scale_index")
    if (WaveExists(bci))
        SetScale/P x, 0, 1, "row", bci
    endif

    return 0
End

Function LJZ_MDCTrack_RedimensionLandscapeRows(runDF, totalRows)
    String runDF
    Variable totalRows

    String df
    Variable oldRows
    Variable nCols
    Variable i
    Variable j

    df = LJZ_MDCTrack_df_with_colon(runDF)
    if (totalRows < 0)
        totalRows = 0
    endif

    Wave/Z corrShift = $(df + "corr_vs_shift")
    if (WaveExists(corrShift))
        oldRows = DimSize(corrShift, 0)
        nCols = DimSize(corrShift, 1)
        if (nCols < 1)
            nCols = 1
        endif
        if (oldRows < totalRows)
            Redimension/N=(totalRows, nCols) corrShift
            for (i = oldRows; i < totalRows; i += 1)
                for (j = 0; j < nCols; j += 1)
                    corrShift[i][j] = NaN
                endfor
            endfor
        endif
        SetScale/P x, 0, 1, "row", corrShift
    endif

    Wave/Z corrScale = $(df + "corr_vs_scale")
    if (WaveExists(corrScale))
        oldRows = DimSize(corrScale, 0)
        nCols = DimSize(corrScale, 1)
        if (nCols < 1)
            nCols = 1
        endif
        if (oldRows < totalRows)
            Redimension/N=(totalRows, nCols) corrScale
            for (i = oldRows; i < totalRows; i += 1)
                for (j = 0; j < nCols; j += 1)
                    corrScale[i][j] = NaN
                endfor
            endfor
        endif
        SetScale/P x, 0, 1, "row", corrScale
    endif

    return 0
End

// ============================================================================
// Section 2. Wave scanning / validation
// ============================================================================

Function/S LJZ_MDCTrack_ListWavesOneDF(dfStr)
    String dfStr

    String df
    String list
    String oneName
    String onePath
    Variable iObj
    Variable nObj

    df = LJZ_MDCTrack_df_with_colon(dfStr)
    if (!DataFolderExists(df))
        return ""
    endif

    list = ""
    nObj = CountObjects(df, 1)

    for (iObj = 0; iObj < nObj; iObj += 1)
        oneName = GetIndexedObjName(df, 1, iObj)
        onePath = df + oneName
        Wave/Z w = $onePath
        if (WaveExists(w))
            if (LJZ_MDCTrack_IsAllowedSourceWave(w) != 0)
                list = AddListItem(onePath, list, ";", Inf)
            endif
        endif
    endfor

    return list
End

Function/S LJZ_MDCTrack_ListTargetWaves(dfStr, recursive)
    String dfStr
    Variable recursive

    String df
    String list
    String subName
    Variable iObj
    Variable nObj

    df = LJZ_MDCTrack_df_with_colon(dfStr)
    if (!DataFolderExists(df))
        return ""
    endif

    list = LJZ_MDCTrack_ListWavesOneDF(df)

    if (recursive == 0)
        return list
    endif

    nObj = CountObjects(df, 4)
    for (iObj = 0; iObj < nObj; iObj += 1)
        subName = GetIndexedObjName(df, 4, iObj)
        if (strlen(subName) > 0)
            list += LJZ_MDCTrack_ListTargetWaves(df + subName + ":", 1)
        endif
    endfor

    return list
End

Function LJZ_MDCTrack_RebuildTargetList()
    LJZ_MDCTrack_EnsureDF()

    SVAR targetDF = $(LJZ_MDCTrack_BaseDF() + ":TargetDF")
    SVAR targetSel = $(LJZ_MDCTrack_BaseDF() + ":TargetWaveSel")
    NVAR recursive = $(LJZ_MDCTrack_BaseDF() + ":Recursive")

    String list
    list = LJZ_MDCTrack_ListTargetWaves(targetDF, recursive)

    Variable n
    Variable i
    String pth
    String shortName

    n = ItemsInList(list, ";")

    Make/O/T/N=(n) $(LJZ_MDCTrack_BaseDF() + ":LB_Path")
    Make/O/T/N=(n) $(LJZ_MDCTrack_BaseDF() + ":LB_Disp")
    Make/O/N=(n) $(LJZ_MDCTrack_BaseDF() + ":LB_Sel") = 0

    Wave/T wPath = $(LJZ_MDCTrack_BaseDF() + ":LB_Path")
    Wave/T wDisp = $(LJZ_MDCTrack_BaseDF() + ":LB_Disp")
    Wave wSel = $(LJZ_MDCTrack_BaseDF() + ":LB_Sel")

    for (i = 0; i < n; i += 1)
        pth = StringFromList(i, list, ";")
        wPath[i] = pth
        shortName = pth
        if (strlen(shortName) > 55)
            shortName = shortName[strlen(shortName) - 55, strlen(shortName) - 1]
        endif
        wDisp[i] = shortName
        wSel[i] = 0
    endfor

    if (n > 0 && strlen(targetSel) == 0)
        targetSel = wPath[0]
        wSel[0] = 1
    endif

    return n
End

// ============================================================================
// Section 3. Core algorithm
// ============================================================================

Function LJZ_MDCTrack_MakeProfile(src, outPath, e0In, e1In, usePhysE, stack0In, stack1In)
    Wave src
    String outPath
    Variable e0In
    Variable e1In
    Variable usePhysE
    Variable stack0In
    Variable stack1In

    Variable nd
    Variable nE
    Variable nK
    Variable nS
    Variable eLo
    Variable eHi
    Variable sLo
    Variable sHi
    Variable ret
    Variable iK
    Variable iE
    Variable iS
    Variable sum
    Variable cnt
    Variable v
    Variable offK
    Variable delK

    nd = WaveDims(src)

    if (nd == 1)
        Duplicate/O src, $outPath
        Wave out1 = $outPath
        return 0
    endif

    nE = DimSize(src, 0)
    nK = DimSize(src, 1)
    nS = 1
    if (nd == 3)
        nS = DimSize(src, 2)
    endif

    ret = LJZ_MDCTrack_WindowToIndex(DimOffset(src, 0), DimDelta(src, 0), nE, usePhysE, e0In, e1In, eLo, eHi)
    if (ret != 0)
        return -1
    endif

    if (nd == 3)
        sLo = round(stack0In)
        sHi = round(stack1In)
        if (sLo > sHi)
            Variable sTmp
            sTmp = sLo
            sLo = sHi
            sHi = sTmp
        endif
        sLo = max(0, sLo)
        sHi = min(nS - 1, sHi)
    else
        sLo = 0
        sHi = 0
    endif

    if (sHi < sLo)
        return -2
    endif

    Make/O/D/N=(nK) $outPath = NaN
    Wave out = $outPath

    offK = DimOffset(src, 1)
    delK = DimDelta(src, 1)
    SetScale/P x, offK, delK, "", out

    for (iK = 0; iK < nK; iK += 1)
        sum = 0
        cnt = 0
        for (iE = eLo; iE <= eHi; iE += 1)
            for (iS = sLo; iS <= sHi; iS += 1)
                if (nd == 3)
                    v = src[iE][iK][iS]
                else
                    v = src[iE][iK]
                endif
                if (numtype(v) == 0)
                    sum += v
                    cnt += 1
                endif
            endfor
        endfor
        if (cnt > 0)
            out[iK] = sum / cnt
        endif
    endfor

    return 0
End

Function LJZ_MDCTrack_PreprocessProfile(inW, outPath, mode, smoothN)
    Wave inW
    String outPath
    Variable mode
    Variable smoothN

    Variable n
    Variable i
    Variable v
    Variable prev
    Variable next
    Variable dx
    Variable sum
    Variable sum2
    Variable cnt
    Variable mean
    Variable rms

    n = numpnts(inW)
    if (n <= 0)
        return -1
    endif

    Duplicate/O inW, $outPath
    Wave out = $outPath

    if (smoothN >= 2)
        Smooth smoothN, out
    endif

    if (mode == 2)
        Make/FREE/D/N=(n) tmpDeriv
        SetScale/P x, DimOffset(out, 0), DimDelta(out, 0), "", tmpDeriv
        for (i = 0; i < n; i += 1)
            tmpDeriv[i] = NaN
        endfor
        dx = abs(DimDelta(out, 0))
        if (dx == 0)
            dx = 1
        endif
        for (i = 1; i < n - 1; i += 1)
            prev = out[i - 1]
            next = out[i + 1]
            if (numtype(prev) == 0 && numtype(next) == 0)
                tmpDeriv[i] = (next - prev) / (2 * dx)
            endif
        endfor
        for (i = 0; i < n; i += 1)
            out[i] = tmpDeriv[i]
        endfor
    elseif (mode == 3)
        // crude local baseline removal by subtracting a straight line between first and last finite points
        Variable firstIdx
        Variable lastIdx
        Variable firstVal
        Variable lastVal
        Variable base
        firstIdx = -1
        lastIdx = -1
        for (i = 0; i < n; i += 1)
            if (numtype(out[i]) == 0)
                if (firstIdx < 0)
                    firstIdx = i
                    firstVal = out[i]
                endif
                lastIdx = i
                lastVal = out[i]
            endif
        endfor
        if (firstIdx >= 0 && lastIdx > firstIdx)
            for (i = 0; i < n; i += 1)
                if (numtype(out[i]) == 0)
                    base = firstVal + (lastVal - firstVal) * (i - firstIdx) / (lastIdx - firstIdx)
                    out[i] = out[i] - base
                endif
            endfor
        endif
    endif

    sum = 0
    sum2 = 0
    cnt = 0
    for (i = 0; i < n; i += 1)
        v = out[i]
        if (numtype(v) == 0)
            sum += v
            sum2 += v * v
            cnt += 1
        endif
    endfor

    if (cnt < 3)
        return -2
    endif

    mean = sum / cnt
    rms = sqrt(max(0, sum2 / cnt - mean * mean))
    if (rms <= 0)
        return -3
    endif

    for (i = 0; i < n; i += 1)
        v = out[i]
        if (numtype(v) == 0)
            out[i] = (v - mean) / rms
        else
            out[i] = NaN
        endif
    endfor

    return 0
End

Function LJZ_MDCTrack_CorrAt(refW, tarW, k0In, k1In, usePhysK, dK, scale, kCenter, nPairsOut, residualOut)
    Wave refW
    Wave tarW
    Variable k0In
    Variable k1In
    Variable usePhysK
    Variable dK
    Variable scale
    Variable kCenter
    Variable &nPairsOut
    Variable &residualOut

    Variable n
    Variable i
    Variable kLo
    Variable kHi
    Variable ret
    Variable xRef
    Variable xTar
    Variable a
    Variable b
    Variable sumA
    Variable sumB
    Variable sumAA
    Variable sumBB
    Variable sumAB
    Variable cnt
    Variable meanA
    Variable meanB
    Variable varA
    Variable varB
    Variable covAB
    Variable corr
    Variable diff
    Variable sumRes
    Variable sumRef2

    nPairsOut = 0
    residualOut = NaN

    if (scale <= 0)
        return NaN
    endif

    n = numpnts(refW)
    ret = LJZ_MDCTrack_WindowToIndex(DimOffset(refW, 0), DimDelta(refW, 0), n, usePhysK, k0In, k1In, kLo, kHi)
    if (ret != 0)
        return NaN
    endif

    sumA = 0
    sumB = 0
    sumAA = 0
    sumBB = 0
    sumAB = 0
    cnt = 0

    for (i = kLo; i <= kHi; i += 1)
        xRef = LJZ_MDCTrack_ScaledX(refW, i)
        xTar = kCenter + (xRef - kCenter - dK) / scale
        a = refW[i]
        b = LJZ_MDCTrack_InterpScaled(tarW, xTar)
        if (numtype(a) == 0 && numtype(b) == 0)
            sumA += a
            sumB += b
            sumAA += a * a
            sumBB += b * b
            sumAB += a * b
            cnt += 1
        endif
    endfor

    nPairsOut = cnt
    if (cnt < 5)
        return NaN
    endif

    meanA = sumA / cnt
    meanB = sumB / cnt
    varA = sumAA - cnt * meanA * meanA
    varB = sumBB - cnt * meanB * meanB
    covAB = sumAB - cnt * meanA * meanB

    if (varA <= 0 || varB <= 0)
        return NaN
    endif

    corr = covAB / sqrt(varA * varB)

    sumRes = 0
    sumRef2 = 0
    for (i = kLo; i <= kHi; i += 1)
        xRef = LJZ_MDCTrack_ScaledX(refW, i)
        xTar = kCenter + (xRef - kCenter - dK) / scale
        a = refW[i]
        b = LJZ_MDCTrack_InterpScaled(tarW, xTar)
        if (numtype(a) == 0 && numtype(b) == 0)
            diff = (a - meanA) - (b - meanB)
            sumRes += diff * diff
            sumRef2 += (a - meanA) * (a - meanA)
        endif
    endfor

    if (sumRef2 > 0)
        residualOut = sqrt(sumRes / sumRef2)
    endif

    return corr
End

Function LJZ_MDCTrack_RegisterOneProfile(refProc, targetProfile, outDF, row, targetPath, layer)
    Wave refProc
    Wave targetProfile
    String outDF
    Variable row
    String targetPath
    Variable layer

    LJZ_MDCTrack_EnsureDF()

    NVAR usePhysK = $(LJZ_MDCTrack_BaseDF() + ":UsePhysK")
    NVAR k0 = $(LJZ_MDCTrack_BaseDF() + ":K0")
    NVAR k1 = $(LJZ_MDCTrack_BaseDF() + ":K1")
    NVAR maxShift = $(LJZ_MDCTrack_BaseDF() + ":MaxShift")
    NVAR shiftSubDiv = $(LJZ_MDCTrack_BaseDF() + ":ShiftSubDiv")
    NVAR corrThresh = $(LJZ_MDCTrack_BaseDF() + ":CorrThresh")
    NVAR preprocess = $(LJZ_MDCTrack_BaseDF() + ":PreprocessMode")
    NVAR smoothN = $(LJZ_MDCTrack_BaseDF() + ":SmoothN")
    NVAR fitScale = $(LJZ_MDCTrack_BaseDF() + ":FitScale")
    NVAR scaleMin = $(LJZ_MDCTrack_BaseDF() + ":ScaleMin")
    NVAR scaleMax = $(LJZ_MDCTrack_BaseDF() + ":ScaleMax")
    NVAR scaleN = $(LJZ_MDCTrack_BaseDF() + ":ScaleN")
    NVAR kCenter = $(LJZ_MDCTrack_BaseDF() + ":KCenter")

    String df
    df = LJZ_MDCTrack_df_with_colon(outDF)

    Wave/T target_path = $(df + "target_path")
    Wave target_layer = $(df + "target_layer")
    Wave dK_toRef = $(df + "dK_toRef")
    Wave scale_toRef = $(df + "scale_toRef")
    Wave similarity = $(df + "similarity")
    Wave residual = $(df + "residual")
    Wave flag = $(df + "flag")
    Wave nPairs = $(df + "nPairs")
    Wave/Z nPairsFrac = $(df + "nPairsFrac")
    Wave/T/Z flagReason = $(df + "flag_reason")
    Wave/Z bestShiftIndex = $(df + "best_shift_index")
    Wave/Z bestScaleIndex = $(df + "best_scale_index")

    String procPath
    procPath = df + "target_profile_proc_tmp"
    Variable ret
    ret = LJZ_MDCTrack_PreprocessProfile(targetProfile, procPath, preprocess, smoothN)
    if (ret != 0)
        target_path[row] = targetPath
        target_layer[row] = layer
        dK_toRef[row] = NaN
        scale_toRef[row] = NaN
        similarity[row] = NaN
        residual[row] = NaN
        flag[row] = 5
        nPairs[row] = 0
        if (WaveExists(nPairsFrac))
            nPairsFrac[row] = 0
        endif
        if (WaveExists(flagReason))
            flagReason[row] = LJZ_MDCTrack_PreprocessErrorText(ret)
        endif
        if (WaveExists(bestShiftIndex))
            bestShiftIndex[row] = NaN
        endif
        if (WaveExists(bestScaleIndex))
            bestScaleIndex[row] = NaN
        endif
        return -1
    endif

    Wave targetProc = $procPath

    Variable baseStep
    baseStep = abs(DimDelta(refProc, 0))
    if (baseStep <= 0)
        baseStep = 0.001
    endif
    if (shiftSubDiv < 1)
        shiftSubDiv = 1
    endif
    baseStep = baseStep / shiftSubDiv
    if (baseStep <= 0)
        baseStep = maxShift / 50
    endif
    if (baseStep <= 0)
        baseStep = 0.001
    endif

    Variable nShift
    nShift = floor(2 * maxShift / baseStep + 0.5) + 1
    if (nShift < 3)
        nShift = 3
    endif

    Variable scaleLow
    Variable scaleHigh
    Variable scaleTmp
    scaleLow = scaleMin
    scaleHigh = scaleMax
    if (scaleLow > scaleHigh)
        scaleTmp = scaleLow
        scaleLow = scaleHigh
        scaleHigh = scaleTmp
    endif

    Variable nScale
    Variable iScale
    Variable iShift
    Variable scaleThis
    Variable shiftThis
    Variable corrThis
    Variable bestCorr
    Variable bestShift
    Variable bestScale
    Variable bestRes
    Variable thisRes
    Variable bestNPairs
    Variable thisNPairs
    Variable scaleStep
    Variable bestIShift
    Variable bestIScale

    if (fitScale != 0)
        nScale = max(1, round(scaleN))
        if (nScale < 5 && row == 0)
            Print "WARNING: fit scale is enabled but ScaleN < 5. Scale grid may be too coarse."
        endif
    else
        nScale = 1
    endif

    if (nScale == 1)
        scaleStep = 0
    else
        scaleStep = (scaleHigh - scaleLow) / (nScale - 1)
    endif

    bestCorr = -Inf
    bestShift = NaN
    bestScale = 1
    bestRes = NaN
    bestNPairs = 0
    bestIShift = -1
    bestIScale = -1

    for (iScale = 0; iScale < nScale; iScale += 1)
        if (fitScale != 0)
            scaleThis = scaleLow + iScale * scaleStep
        else
            scaleThis = 1
        endif

        for (iShift = 0; iShift < nShift; iShift += 1)
            shiftThis = -maxShift + iShift * baseStep
            corrThis = LJZ_MDCTrack_CorrAt(refProc, targetProc, k0, k1, usePhysK, shiftThis, scaleThis, kCenter, thisNPairs, thisRes)
            if (numtype(corrThis) == 0)
                if (corrThis > bestCorr)
                    bestCorr = corrThis
                    bestShift = shiftThis
                    bestScale = scaleThis
                    bestRes = thisRes
                    bestNPairs = thisNPairs
                    bestIShift = iShift
                    bestIScale = iScale
                endif
            endif
        endfor
    endfor

    Variable cMinus
    Variable cPlus
    Variable npTmp
    Variable resTmp
    Variable denom
    Variable deltaFine
    Variable refinedShift
    Variable refinedCorr
    Variable refinedRes

    // Sub-grid refinement in shift, at current best scale.
    if (numtype(bestShift) == 0)
        cMinus = LJZ_MDCTrack_CorrAt(refProc, targetProc, k0, k1, usePhysK, bestShift - baseStep, bestScale, kCenter, npTmp, resTmp)
        cPlus = LJZ_MDCTrack_CorrAt(refProc, targetProc, k0, k1, usePhysK, bestShift + baseStep, bestScale, kCenter, npTmp, resTmp)
        if (numtype(cMinus) == 0 && numtype(cPlus) == 0)
            denom = cMinus - 2 * bestCorr + cPlus
            if (abs(denom) > 1e-12)
                deltaFine = 0.5 * (cMinus - cPlus) / denom * baseStep
                if (abs(deltaFine) <= baseStep)
                    refinedShift = bestShift + deltaFine
                    refinedCorr = LJZ_MDCTrack_CorrAt(refProc, targetProc, k0, k1, usePhysK, refinedShift, bestScale, kCenter, npTmp, refinedRes)
                    if (numtype(refinedCorr) == 0)
                        if (refinedCorr >= bestCorr - 1e-6)
                            bestShift = refinedShift
                            bestCorr = refinedCorr
                            bestRes = refinedRes
                            bestNPairs = npTmp
                        endif
                    endif
                endif
            endif
        endif
    endif

    // Sub-grid refinement in scale, at current best shift.
    Variable refinedScale
    if (fitScale != 0 && nScale > 1 && scaleStep > 0 && numtype(bestScale) == 0 && numtype(bestShift) == 0)
        cMinus = LJZ_MDCTrack_CorrAt(refProc, targetProc, k0, k1, usePhysK, bestShift, bestScale - scaleStep, kCenter, npTmp, resTmp)
        cPlus = LJZ_MDCTrack_CorrAt(refProc, targetProc, k0, k1, usePhysK, bestShift, bestScale + scaleStep, kCenter, npTmp, resTmp)
        if (numtype(cMinus) == 0 && numtype(cPlus) == 0)
            denom = cMinus - 2 * bestCorr + cPlus
            if (abs(denom) > 1e-12)
                deltaFine = 0.5 * (cMinus - cPlus) / denom * scaleStep
                if (abs(deltaFine) <= scaleStep)
                    refinedScale = bestScale + deltaFine
                    if (refinedScale >= scaleLow && refinedScale <= scaleHigh)
                        refinedCorr = LJZ_MDCTrack_CorrAt(refProc, targetProc, k0, k1, usePhysK, bestShift, refinedScale, kCenter, npTmp, refinedRes)
                        if (numtype(refinedCorr) == 0)
                            if (refinedCorr >= bestCorr - 1e-6)
                                bestScale = refinedScale
                                bestCorr = refinedCorr
                                bestRes = refinedRes
                                bestNPairs = npTmp
                            endif
                        endif
                    endif
                endif
            endif
        endif
    endif

    LJZ_MDCTrack_EnsureLandscapeWaves(df, row + 1, nShift, nScale, maxShift, baseStep, scaleLow, scaleHigh, fitScale)
    Wave corrShiftWave = $(df + "corr_vs_shift")
    Wave corrScaleWave = $(df + "corr_vs_scale")

    for (iShift = 0; iShift < nShift; iShift += 1)
        shiftThis = -maxShift + iShift * baseStep
        corrShiftWave[row][iShift] = LJZ_MDCTrack_CorrAt(refProc, targetProc, k0, k1, usePhysK, shiftThis, bestScale, kCenter, npTmp, resTmp)
    endfor

    for (iScale = 0; iScale < nScale; iScale += 1)
        if (fitScale != 0)
            scaleThis = scaleLow + iScale * scaleStep
        else
            scaleThis = 1
        endif
        corrScaleWave[row][iScale] = LJZ_MDCTrack_CorrAt(refProc, targetProc, k0, k1, usePhysK, bestShift, scaleThis, kCenter, npTmp, resTmp)
    endfor

    target_path[row] = targetPath
    target_layer[row] = layer
    dK_toRef[row] = bestShift
    scale_toRef[row] = bestScale
    similarity[row] = bestCorr
    residual[row] = bestRes
    nPairs[row] = bestNPairs
    if (WaveExists(bestShiftIndex))
        bestShiftIndex[row] = bestIShift
    endif
    if (WaveExists(bestScaleIndex))
        bestScaleIndex[row] = bestIScale
    endif

    Variable kWinPoints
    kWinPoints = LJZ_MDCTrack_CountKWindowPoints(refProc, k0, k1, usePhysK)
    if (WaveExists(nPairsFrac))
        if (kWinPoints > 0)
            nPairsFrac[row] = bestNPairs / kWinPoints
        else
            nPairsFrac[row] = NaN
        endif
    endif

    Variable flagValue
    Variable pairFracValue
    Variable pairFracIsLow
    String reason
    pairFracValue = NaN
    pairFracIsLow = 0
    if (WaveExists(nPairsFrac))
        pairFracValue = nPairsFrac[row]
        if (numtype(pairFracValue) == 0 && pairFracValue < 0.5)
            pairFracIsLow = 1
        endif
    endif

    if (numtype(bestCorr) != 0)
        flagValue = 5
        reason = "no valid correlation maximum"
    elseif (bestNPairs < 5)
        flagValue = 4
        reason = "too few valid point pairs"
    elseif (pairFracIsLow)
        flagValue = 4
        reason = "valid pair fraction < 0.5"
    elseif (bestCorr < corrThresh)
        flagValue = 1
        reason = "best correlation below threshold"
    elseif (abs(abs(bestShift) - maxShift) <= 1.5 * baseStep)
        flagValue = 2
        reason = "best shift near +/- maxShift"
    elseif (fitScale != 0 && nScale > 1 && scaleStep > 0 && (abs(bestScale - scaleLow) <= 1.5 * scaleStep || abs(bestScale - scaleHigh) <= 1.5 * scaleStep))
        flagValue = 3
        reason = "best scale near scale search boundary"
    else
        flagValue = 0
        reason = "OK"
    endif

    flag[row] = flagValue
    if (WaveExists(flagReason))
        flagReason[row] = reason
    endif

    KillWaves/Z $procPath
    return 0
End

Function LJZ_MDCTrack_PrepareResultWaves(runDF, nRows)
    String runDF
    Variable nRows

    String df
    df = LJZ_MDCTrack_df_with_colon(runDF)
    LJZ_MDCTrack_EnsureDataFolderPath(df)

    Make/O/T/N=(nRows) $(df + "target_path")
    Make/O/D/N=(nRows) $(df + "target_layer") = NaN
    Make/O/D/N=(nRows) $(df + "dK_toRef") = NaN
    Make/O/D/N=(nRows) $(df + "scale_toRef") = NaN
    Make/O/D/N=(nRows) $(df + "similarity") = NaN
    Make/O/D/N=(nRows) $(df + "residual") = NaN
    Make/O/D/N=(nRows) $(df + "flag") = NaN
    Make/O/D/N=(nRows) $(df + "nPairs") = NaN
    Make/O/D/N=(nRows) $(df + "nPairsFrac") = NaN
    Make/O/T/N=(nRows) $(df + "flag_reason") = ""
    Make/O/D/N=(nRows) $(df + "best_shift_index") = NaN
    Make/O/D/N=(nRows) $(df + "best_scale_index") = NaN

    KillWaves/Z $(df + "corr_vs_shift")
    KillWaves/Z $(df + "corr_shift_axis")
    KillWaves/Z $(df + "corr_vs_scale")
    KillWaves/Z $(df + "corr_scale_axis")
    KillWaves/Z $(df + "diag_row_index")
    KillWaves/Z $(df + "diag_dK_good")
    KillWaves/Z $(df + "diag_dK_lowCorr")
    KillWaves/Z $(df + "diag_dK_shiftBound")
    KillWaves/Z $(df + "diag_dK_scaleBound")
    KillWaves/Z $(df + "diag_dK_fewPairs")
    KillWaves/Z $(df + "diag_dK_error")

    LJZ_MDCTrack_SetResultRowScale(df)
    return 0
End

Function LJZ_MDCTrack_BuildReference()
    LJZ_MDCTrack_EnsureDF()

    SVAR refPath = $(LJZ_MDCTrack_BaseDF() + ":RefWavePath")
    SVAR runName = $(LJZ_MDCTrack_BaseDF() + ":RunName")
    SVAR runDFGlobal = $(LJZ_MDCTrack_BaseDF() + ":RunDF")
    SVAR status = $(LJZ_MDCTrack_BaseDF() + ":Status")

    NVAR refE0 = $(LJZ_MDCTrack_BaseDF() + ":RefE0")
    NVAR refE1 = $(LJZ_MDCTrack_BaseDF() + ":RefE1")
    NVAR usePhysE = $(LJZ_MDCTrack_BaseDF() + ":UsePhysE")
    NVAR refStack0 = $(LJZ_MDCTrack_BaseDF() + ":RefStack0")
    NVAR refStack1 = $(LJZ_MDCTrack_BaseDF() + ":RefStack1")
    NVAR preprocess = $(LJZ_MDCTrack_BaseDF() + ":PreprocessMode")
    NVAR smoothN = $(LJZ_MDCTrack_BaseDF() + ":SmoothN")
    NVAR k0 = $(LJZ_MDCTrack_BaseDF() + ":K0")
    NVAR k1 = $(LJZ_MDCTrack_BaseDF() + ":K1")
    NVAR kCenter = $(LJZ_MDCTrack_BaseDF() + ":KCenter")
    NVAR maxShift = $(LJZ_MDCTrack_BaseDF() + ":MaxShift")
    NVAR shiftSubDiv = $(LJZ_MDCTrack_BaseDF() + ":ShiftSubDiv")
    NVAR corrThresh = $(LJZ_MDCTrack_BaseDF() + ":CorrThresh")
    NVAR fitScale = $(LJZ_MDCTrack_BaseDF() + ":FitScale")
    NVAR scaleMin = $(LJZ_MDCTrack_BaseDF() + ":ScaleMin")
    NVAR scaleMax = $(LJZ_MDCTrack_BaseDF() + ":ScaleMax")
    NVAR scaleN = $(LJZ_MDCTrack_BaseDF() + ":ScaleN")

    Wave/Z refW = $refPath
    if (!WaveExists(refW))
        status = "Reference wave does not exist."
        Print status
        return -1
    endif

    if (LJZ_MDCTrack_IsAllowedSourceWave(refW) == 0)
        status = "Reference wave must be numeric 1D/2D/3D."
        Print status
        return -2
    endif

    String safeName
    String runDF
    safeName = LJZ_MDCTrack_SafeRunName(runName)
    runDF = LJZ_MDCTrack_df_with_colon(LJZ_MDCTrack_RunRoot() + ":" + safeName)
    LJZ_MDCTrack_EnsureDataFolderPath(runDF)

    String/G $(runDF + "RefWavePath") = refPath
    Variable/G $(runDF + "RefE0") = refE0
    Variable/G $(runDF + "RefE1") = refE1
    Variable/G $(runDF + "UsePhysE") = usePhysE
    Variable/G $(runDF + "RefStack0") = refStack0
    Variable/G $(runDF + "RefStack1") = refStack1
    Variable/G $(runDF + "K0") = k0
    Variable/G $(runDF + "K1") = k1
    Variable/G $(runDF + "KCenter") = kCenter
    String/G $(runDF + "RunName") = safeName
    Variable/G $(runDF + "MaxShift") = maxShift
    Variable/G $(runDF + "ShiftSubDiv") = shiftSubDiv
    Variable/G $(runDF + "CorrThresh") = corrThresh
    Variable/G $(runDF + "PreprocessMode") = preprocess
    Variable/G $(runDF + "SmoothN") = smoothN
    Variable/G $(runDF + "FitScale") = fitScale
    Variable/G $(runDF + "ScaleMin") = scaleMin
    Variable/G $(runDF + "ScaleMax") = scaleMax
    Variable/G $(runDF + "ScaleN") = scaleN

    Variable ret
    ret = LJZ_MDCTrack_MakeProfile(refW, runDF + "ref_profile", refE0, refE1, usePhysE, refStack0, refStack1)
    if (ret != 0)
        status = "Failed to build reference profile."
        Print status
        return -3
    endif

    Wave refProfile = $(runDF + "ref_profile")
    ret = LJZ_MDCTrack_PreprocessProfile(refProfile, runDF + "ref_profile_proc", preprocess, smoothN)
    if (ret != 0)
        status = "Failed to preprocess reference profile."
        Print status
        return -4
    endif

    runDFGlobal = runDF
    status = "Reference built: " + runDF
    Print status

    return 0
End

Function LJZ_MDCTrack_CountRowsForTarget(target)
    Wave target

    Variable nd
    nd = WaveDims(target)

    if (nd == 3)
        return DimSize(target, 2)
    endif

    if (nd == 2)
        return 1
    endif

    return 1
End

Function LJZ_MDCTrack_RegisterTargetWavePath(targetPath, appendMode)
    String targetPath
    Variable appendMode

    LJZ_MDCTrack_EnsureDF()

    SVAR runDFGlobal = $(LJZ_MDCTrack_BaseDF() + ":RunDF")
    SVAR status = $(LJZ_MDCTrack_BaseDF() + ":Status")

    NVAR refE0 = $(LJZ_MDCTrack_BaseDF() + ":RefE0")
    NVAR refE1 = $(LJZ_MDCTrack_BaseDF() + ":RefE1")
    NVAR usePhysE = $(LJZ_MDCTrack_BaseDF() + ":UsePhysE")

    String runDF
    runDF = LJZ_MDCTrack_df_with_colon(runDFGlobal)
    if (!DataFolderExists(runDF))
        status = "RunDF does not exist. Build Reference first."
        Print status
        return -1
    endif

    Wave/Z refProc = $(runDF + "ref_profile_proc")
    if (!WaveExists(refProc))
        status = "ref_profile_proc missing. Build Reference first."
        Print status
        return -2
    endif

    Wave/Z target = $targetPath
    if (!WaveExists(target))
        status = "Target wave does not exist: " + targetPath
        Print status
        return -3
    endif

    if (LJZ_MDCTrack_IsAllowedSourceWave(target) == 0)
        status = "Target wave is not a numeric 1D/2D/3D source."
        Print status
        return -4
    endif

    Variable nd
    Variable nRows
    Variable oldRows
    Variable row0
    Variable iLayer
    Variable ret
    nd = WaveDims(target)
    nRows = LJZ_MDCTrack_CountRowsForTarget(target)

    if (appendMode == 0)
        LJZ_MDCTrack_PrepareResultWaves(runDF, nRows)
        row0 = 0
    else
        Wave/T/Z oldPath = $(runDF + "target_path")
        if (!WaveExists(oldPath))
            LJZ_MDCTrack_PrepareResultWaves(runDF, nRows)
            row0 = 0
        else
            oldRows = numpnts(oldPath)
            row0 = oldRows
            Redimension/N=(oldRows + nRows) $(runDF + "target_path")
            Redimension/N=(oldRows + nRows) $(runDF + "target_layer")
            Redimension/N=(oldRows + nRows) $(runDF + "dK_toRef")
            Redimension/N=(oldRows + nRows) $(runDF + "scale_toRef")
            Redimension/N=(oldRows + nRows) $(runDF + "similarity")
            Redimension/N=(oldRows + nRows) $(runDF + "residual")
            Redimension/N=(oldRows + nRows) $(runDF + "flag")
            Redimension/N=(oldRows + nRows) $(runDF + "nPairs")
            Redimension/N=(oldRows + nRows) $(runDF + "nPairsFrac")
            Redimension/N=(oldRows + nRows) $(runDF + "flag_reason")
            Redimension/N=(oldRows + nRows) $(runDF + "best_shift_index")
            Redimension/N=(oldRows + nRows) $(runDF + "best_scale_index")
            LJZ_MDCTrack_SetResultRowScale(runDF)
            LJZ_MDCTrack_RedimensionLandscapeRows(runDF, oldRows + nRows)
        endif
    endif

    String profPath
    if (nd == 3)
        for (iLayer = 0; iLayer < DimSize(target, 2); iLayer += 1)
            profPath = runDF + "target_profile_tmp"
            ret = LJZ_MDCTrack_MakeProfile(target, profPath, refE0, refE1, usePhysE, iLayer, iLayer)
            if (ret == 0)
                Wave prof = $profPath
                LJZ_MDCTrack_RegisterOneProfile(refProc, prof, runDF, row0 + iLayer, targetPath, iLayer)
            else
                Wave/T target_path = $(runDF + "target_path")
                Wave target_layer = $(runDF + "target_layer")
                Wave flag = $(runDF + "flag")
                target_path[row0 + iLayer] = targetPath
                target_layer[row0 + iLayer] = iLayer
                flag[row0 + iLayer] = 5
            endif
        endfor
    else
        profPath = runDF + "target_profile_tmp"
        ret = LJZ_MDCTrack_MakeProfile(target, profPath, refE0, refE1, usePhysE, 0, 0)
        if (ret == 0)
            Wave prof2 = $profPath
            LJZ_MDCTrack_RegisterOneProfile(refProc, prof2, runDF, row0, targetPath, 0)
        else
            Wave/T target_path2 = $(runDF + "target_path")
            Wave target_layer2 = $(runDF + "target_layer")
            Wave flag2 = $(runDF + "flag")
            target_path2[row0] = targetPath
            target_layer2[row0] = 0
            flag2[row0] = 5
        endif
    endif

    KillWaves/Z $(runDF + "target_profile_tmp")
    status = "Registered target: " + targetPath
    Print status

    return 0
End

Function LJZ_MDCTrack_RegisterSelected()
    LJZ_MDCTrack_EnsureDF()

    SVAR targetSel = $(LJZ_MDCTrack_BaseDF() + ":TargetWaveSel")
    if (strlen(targetSel) == 0)
        Print "No target selected."
        return -1
    endif

    return LJZ_MDCTrack_RegisterTargetWavePath(targetSel, 0)
End

Function LJZ_MDCTrack_RegisterAllTargets()
    LJZ_MDCTrack_EnsureDF()

    Wave/T/Z wPath = $(LJZ_MDCTrack_BaseDF() + ":LB_Path")
    SVAR runDFGlobal = $(LJZ_MDCTrack_BaseDF() + ":RunDF")
    SVAR status = $(LJZ_MDCTrack_BaseDF() + ":Status")

    if (!WaveExists(wPath))
        status = "Target list is empty."
        Print status
        return -1
    endif

    String runDF
    runDF = LJZ_MDCTrack_df_with_colon(runDFGlobal)
    if (!DataFolderExists(runDF))
        status = "Build Reference first."
        Print status
        return -2
    endif

    Variable i
    Variable n
    Variable totalRows
    Variable rowsThis
    Wave/Z w

    n = numpnts(wPath)
    totalRows = 0
    for (i = 0; i < n; i += 1)
        Wave/Z ww = $(wPath[i])
        if (WaveExists(ww))
            totalRows += LJZ_MDCTrack_CountRowsForTarget(ww)
        endif
    endfor

    if (totalRows <= 0)
        status = "No valid target waves."
        Print status
        return -3
    endif

    LJZ_MDCTrack_PrepareResultWaves(runDF, 0)

    for (i = 0; i < n; i += 1)
        LJZ_MDCTrack_RegisterTargetWavePath(wPath[i], 1)
    endfor

    status = "Registered all target waves."
    Print status

    return 0
End

Function LJZ_MDCTrack_CorrectPeakPositionsFromPaths(peakRawPath, runDFIn, outName)
    String peakRawPath
    String runDFIn
    String outName

    String runDF
    runDF = LJZ_MDCTrack_df_with_colon(runDFIn)

    Wave/Z peakRaw = $peakRawPath
    if (!WaveExists(peakRaw))
        Print "Peak raw wave does not exist: ", peakRawPath
        return -1
    endif

    Wave/Z dK = $(runDF + "dK_toRef")
    Wave/Z sc = $(runDF + "scale_toRef")
    if (!WaveExists(dK) || !WaveExists(sc))
        Print "Tracking waves dK_toRef / scale_toRef missing in ", runDF
        return -2
    endif

    NVAR/Z kCenterRun = $(runDF + "KCenter")
    Variable kCenter
    if (NVAR_Exists(kCenterRun))
        kCenter = kCenterRun
    else
        NVAR kCenterGlobal = $(LJZ_MDCTrack_BaseDF() + ":KCenter")
        kCenter = kCenterGlobal
    endif

    Variable nd
    Variable n0
    Variable n1
    Variable i
    Variable j
    Variable scaleThis
    Variable dKThis
    Variable raw
    Variable nTrack

    nd = WaveDims(peakRaw)
    nTrack = min(numpnts(dK), numpnts(sc))
    if (numpnts(dK) != numpnts(sc))
        Print "WARNING: dK_toRef and scale_toRef have different row counts. Using overlapping rows only. dK rows=", numpnts(dK), "; scale rows=", numpnts(sc)
    endif
    String outPath
    outPath = runDF + outName

    if (nd == 1)
        n0 = DimSize(peakRaw, 0)
        if (n0 != nTrack)
            Print "WARNING: peakRaw row count does not match tracking row count. Peak rows=", n0, "; tracking rows=", nTrack, ". Check that peakRaw and this run have the same target/layer order."
        endif
        Make/O/D/N=(n0) $outPath = NaN
        Wave out1 = $outPath
        SetScale/P x, DimOffset(peakRaw, 0), DimDelta(peakRaw, 0), "", out1
        for (i = 0; i < n0; i += 1)
            if (i < numpnts(dK) && i < numpnts(sc))
                raw = peakRaw[i]
                dKThis = dK[i]
                scaleThis = sc[i]
                if (numtype(raw) == 0 && numtype(dKThis) == 0 && numtype(scaleThis) == 0)
                    out1[i] = kCenter + scaleThis * (raw - kCenter) + dKThis
                endif
            endif
        endfor
    elseif (nd == 2)
        n0 = DimSize(peakRaw, 0)
        n1 = DimSize(peakRaw, 1)
        if (n0 != nTrack)
            Print "WARNING: peakRaw row count does not match tracking row count. Peak rows=", n0, "; tracking rows=", nTrack, ". Check that peakRaw and this run have the same target/layer order."
        endif
        Make/O/D/N=(n0, n1) $outPath = NaN
        Wave out2 = $outPath
        SetScale/P x, DimOffset(peakRaw, 0), DimDelta(peakRaw, 0), "", out2
        SetScale/P y, DimOffset(peakRaw, 1), DimDelta(peakRaw, 1), "", out2
        for (i = 0; i < n0; i += 1)
            if (i < numpnts(dK) && i < numpnts(sc))
                dKThis = dK[i]
                scaleThis = sc[i]
                for (j = 0; j < n1; j += 1)
                    raw = peakRaw[i][j]
                    if (numtype(raw) == 0 && numtype(dKThis) == 0 && numtype(scaleThis) == 0)
                        out2[i][j] = kCenter + scaleThis * (raw - kCenter) + dKThis
                    endif
                endfor
            endif
        endfor
    else
        Print "Peak raw wave must be 1D or 2D."
        return -3
    endif

    String/G $(runDF + "PeakRawPath") = peakRawPath
    String/G $(runDF + "PeakCorrPath") = outPath
    Print "Corrected peak wave written: ", outPath

    return 0
End

Function LJZ_MDCTrack_CorrectPeakFromPanel()
    LJZ_MDCTrack_EnsureDF()

    SVAR peakRaw = $(LJZ_MDCTrack_BaseDF() + ":PeakRawPath")
    SVAR runDF = $(LJZ_MDCTrack_BaseDF() + ":RunDF")
    SVAR status = $(LJZ_MDCTrack_BaseDF() + ":Status")

    Variable ret
    ret = LJZ_MDCTrack_CorrectPeakPositionsFromPaths(peakRaw, runDF, "kPeak_corr")
    if (ret == 0)
        status = "Peak correction done."
    else
        status = "Peak correction failed."
    endif

    return ret
End

// ---- Apply dK/scale correction to full data waves ----

Function LJZ_MDCTrack_RunUsesSingleCorrection(runDFIn)
    String runDFIn

    String runDF
    runDF = LJZ_MDCTrack_df_with_colon(runDFIn)

    // Prefer the frozen reference-stack information in the run folder.
    // If it is missing, fall back to the tracking result length.
    NVAR/Z refS0 = $(runDF + "RefStack0")
    NVAR/Z refS1 = $(runDF + "RefStack1")
    if (NVAR_Exists(refS0) && NVAR_Exists(refS1))
        if (numtype(refS0) == 0 && numtype(refS1) == 0)
            if (round(refS0) == round(refS1))
                return 1
            endif
            return 0
        endif
    endif

    Wave/Z dK = $(runDF + "dK_toRef")
    if (WaveExists(dK))
        if (numpnts(dK) <= 1)
            return 1
        endif
    endif

    return 0
End

Function LJZ_MDCTrack_CorrectionRowForLayer(layer, singleCorrection)
    Variable layer
    Variable singleCorrection

    if (singleCorrection != 0)
        return 0
    endif

    return round(layer)
End

Function LJZ_MDCTrack_GetKCenterFromRun(runDFIn)
    String runDFIn

    String runDF
    Variable kCenter

    runDF = LJZ_MDCTrack_df_with_colon(runDFIn)
    NVAR/Z kCenterRun = $(runDF + "KCenter")
    if (NVAR_Exists(kCenterRun))
        kCenter = kCenterRun
    else
        LJZ_MDCTrack_EnsureDF()
        NVAR kCenterGlobal = $(LJZ_MDCTrack_BaseDF() + ":KCenter")
        kCenter = kCenterGlobal
    endif

    return kCenter
End

Function/S LJZ_MDCTrack_MakeApplyOutputPath(srcPath, runDFIn, suffix, outputToRunDF)
    String srcPath
    String runDFIn
    String suffix
    Variable outputToRunDF

    Wave/Z src = $srcPath
    if (!WaveExists(src))
        return ""
    endif

    String srcName
    String outName
    String outDF

    srcName = NameOfWave(src)
    outName = CleanupName(srcName + suffix, 0)
    if (strlen(outName) == 0)
        return ""
    endif
    if (CmpStr(outName, CleanupName(srcName, 0)) == 0)
        return ""
    endif

    if (outputToRunDF != 0)
        outDF = LJZ_MDCTrack_df_with_colon(runDFIn)
    else
        outDF = GetWavesDataFolder(src, 1)
        outDF = LJZ_MDCTrack_df_with_colon(outDF)
    endif

    return outDF + outName
End

Function LJZ_MDCTrack_FillKProfile1D(src, tmp, eIndex, zIndex)
    Wave src
    Wave tmp
    Variable eIndex
    Variable zIndex

    Variable nd
    Variable iK
    Variable nK

    nd = WaveDims(src)
    nK = numpnts(tmp)

    if (nd == 1)
        for (iK = 0; iK < nK; iK += 1)
            tmp[iK] = src[iK]
        endfor
    elseif (nd == 2)
        for (iK = 0; iK < nK; iK += 1)
            tmp[iK] = src[eIndex][iK]
        endfor
    elseif (nd == 3)
        for (iK = 0; iK < nK; iK += 1)
            tmp[iK] = src[eIndex][iK][zIndex]
        endfor
    endif

    return 0
End

Function LJZ_MDCTrack_ApplyCorrectionToWaveEx(srcPath, runDFIn, suffix, skipFlagged, outputToRunDF)
    String srcPath
    String runDFIn
    String suffix
    Variable skipFlagged
    Variable outputToRunDF

    LJZ_MDCTrack_EnsureDF()
    String/G $(LJZ_MDCTrack_BaseDF() + ":ApplyCorrLastOutputList") = ""

    String runDF
    runDF = LJZ_MDCTrack_df_with_colon(runDFIn)

    Wave/Z src = $srcPath
    if (!WaveExists(src))
        Print "ApplyCorrectionToWave: source wave does not exist: " + srcPath
        return -1
    endif

    if (LJZ_MDCTrack_IsAllowedSourceWave(src) == 0)
        Print "ApplyCorrectionToWave: source must be numeric 1D/2D/3D: " + srcPath
        return -2
    endif

    Wave/Z dK = $(runDF + "dK_toRef")
    Wave/Z sc = $(runDF + "scale_toRef")
    if (!WaveExists(dK) || !WaveExists(sc))
        Print "ApplyCorrectionToWave: dK_toRef / scale_toRef missing in " + runDF
        return -3
    endif

    Wave/Z flag = $(runDF + "flag")
    if (numpnts(dK) != numpnts(sc))
        Print "WARNING: dK_toRef and scale_toRef have different row counts. Using overlapping rows only. dK rows=", numpnts(dK), "; scale rows=", numpnts(sc)
    endif

    Variable nTrack
    nTrack = min(numpnts(dK), numpnts(sc))
    if (nTrack <= 0)
        Print "ApplyCorrectionToWave: no tracking rows available in " + runDF
        return -4
    endif

    String outPath
    outPath = LJZ_MDCTrack_MakeApplyOutputPath(srcPath, runDF, suffix, outputToRunDF)
    if (strlen(outPath) == 0)
        Print "ApplyCorrectionToWave: invalid suffix or output name. Refusing to overwrite source wave. Source=", srcPath, "; suffix=", suffix
        return -5
    endif

    Wave/Z outExisting = $outPath
    if (WaveExists(outExisting))
        if (WaveRefsEqual(outExisting, src))
            Print "ApplyCorrectionToWave: output wave is the same object as the source. Refusing to overwrite source wave: " + srcPath
            String/G $(LJZ_MDCTrack_BaseDF() + ":ApplyCorrLastOutputList") = ""
            return -6
        endif
    endif

    Variable nd
    Variable nE
    Variable nK
    Variable nZ
    Variable iE
    Variable iK
    Variable iZ
    Variable row
    Variable singleCorrection
    Variable kCenter
    Variable dKThis
    Variable scaleThis
    Variable flagThis
    Variable kOut
    Variable kSrc
    Variable nWritten
    Variable nSkippedFlag
    Variable nSkippedMissing

    nd = WaveDims(src)
    singleCorrection = LJZ_MDCTrack_RunUsesSingleCorrection(runDF)
    kCenter = LJZ_MDCTrack_GetKCenterFromRun(runDF)

    if (nd == 1)
        nE = 1
        nK = DimSize(src, 0)
        nZ = 1
        Make/O/D/N=(nK) $outPath = NaN
    elseif (nd == 2)
        nE = DimSize(src, 0)
        nK = DimSize(src, 1)
        nZ = 1
        Make/O/D/N=(nE, nK) $outPath = NaN
    else
        nE = DimSize(src, 0)
        nK = DimSize(src, 1)
        nZ = DimSize(src, 2)
        Make/O/D/N=(nE, nK, nZ) $outPath = NaN
    endif

    Wave out = $outPath
    SetScale/P x, DimOffset(src, 0), DimDelta(src, 0), WaveUnits(src, 0), out
    if (nd >= 2)
        SetScale/P y, DimOffset(src, 1), DimDelta(src, 1), WaveUnits(src, 1), out
    endif
    if (nd >= 3)
        SetScale/P z, DimOffset(src, 2), DimDelta(src, 2), WaveUnits(src, 2), out
    endif

    if (singleCorrection == 0 && nZ != nTrack)
        Print "WARNING: source layer count does not match tracking row count. Source layers=", nZ, "; tracking rows=", nTrack, ". Overlapping layers will be corrected; out-of-range layers remain NaN. Check target/layer order."
    endif
    if (singleCorrection != 0 && nTrack > 1)
        Print "ApplyCorrectionToWave: run is treated as single-reference correction. All source layers will use row 0; additional tracking rows are ignored."
    endif
    if (skipFlagged != 0 && !WaveExists(flag))
        Print "WARNING: skipFlagged is enabled but flag wave is missing. No layers will be skipped by flag."
    endif

    Make/FREE/D/N=(nK) tmpKProfile
    if (nd == 1)
        SetScale/P x, DimOffset(src, 0), DimDelta(src, 0), "", tmpKProfile
    else
        SetScale/P x, DimOffset(src, 1), DimDelta(src, 1), "", tmpKProfile
    endif

    nWritten = 0
    nSkippedFlag = 0
    nSkippedMissing = 0

    for (iZ = 0; iZ < nZ; iZ += 1)
        row = LJZ_MDCTrack_CorrectionRowForLayer(iZ, singleCorrection)
        if (row < 0 || row >= nTrack)
            nSkippedMissing += 1
            continue
        endif

        dKThis = dK[row]
        scaleThis = sc[row]
        if (numtype(dKThis) != 0 || numtype(scaleThis) != 0 || scaleThis <= 0)
            nSkippedMissing += 1
            continue
        endif

        if (skipFlagged != 0 && WaveExists(flag))
            flagThis = flag[row]
            if (numtype(flagThis) == 0 && flagThis != 0)
                Print "ApplyCorrectionToWave: skipped layer ", iZ, " using row ", row, " because flag=", flagThis
                nSkippedFlag += 1
                continue
            endif
        endif

        for (iE = 0; iE < nE; iE += 1)
            LJZ_MDCTrack_FillKProfile1D(src, tmpKProfile, iE, iZ)
            for (iK = 0; iK < nK; iK += 1)
                if (nd == 1)
                    kOut = DimOffset(src, 0) + iK * DimDelta(src, 0)
                else
                    kOut = DimOffset(src, 1) + iK * DimDelta(src, 1)
                endif
                kSrc = kCenter + (kOut - kCenter - dKThis) / scaleThis
                if (nd == 1)
                    out[iK] = LJZ_MDCTrack_InterpScaled(tmpKProfile, kSrc)
                elseif (nd == 2)
                    out[iE][iK] = LJZ_MDCTrack_InterpScaled(tmpKProfile, kSrc)
                else
                    out[iE][iK][iZ] = LJZ_MDCTrack_InterpScaled(tmpKProfile, kSrc)
                endif
            endfor
        endfor
        nWritten += 1
    endfor

    String/G $(runDF + "ApplyCorrLastSourcePath") = srcPath
    String/G $(runDF + "ApplyCorrLastOutputPath") = outPath
    Variable/G $(runDF + "ApplyCorrLastSkipFlagged") = skipFlagged
    String/G $(LJZ_MDCTrack_BaseDF() + ":ApplyCorrLastOutputList") = outPath + ";"

    Print "ApplyCorrectionToWave: written ", outPath
    Printf "ApplyCorrectionToWave summary: source layers=%d; corrected layers=%d; skipped by flag=%d; missing/invalid rows=%d; singleCorrection=%d\r", nZ, nWritten, nSkippedFlag, nSkippedMissing, singleCorrection

    return 0
End

Function LJZ_MDCTrack_ApplyCorrectionToWave(srcPath, runDFIn, suffix, skipFlagged)
    String srcPath
    String runDFIn
    String suffix
    Variable skipFlagged

    return LJZ_MDCTrack_ApplyCorrectionToWaveEx(srcPath, runDFIn, suffix, skipFlagged, 0)
End

Function LJZ_MDCTrack_ApplyCorrectionToListEx(pathListIn, runDFIn, suffix, skipFlagged, outputToRunDF)
    String pathListIn
    String runDFIn
    String suffix
    Variable skipFlagged
    Variable outputToRunDF

    LJZ_MDCTrack_EnsureDF()

    String pathList
    String onePath
    String outList
    Variable i
    Variable n
    Variable ret
    Variable nOK
    Variable nFail

    pathList = pathListIn
    if (strlen(pathList) == 0)
        Wave/T/Z wPath = $(LJZ_MDCTrack_BaseDF() + ":LB_Path")
        if (WaveExists(wPath))
            n = numpnts(wPath)
            for (i = 0; i < n; i += 1)
                pathList = AddListItem(wPath[i], pathList, ";", Inf)
            endfor
        endif
    endif

    n = ItemsInList(pathList, ";")
    if (n <= 0)
        Print "ApplyCorrectionToList: empty source wave list."
        return -1
    endif

    outList = ""
    nOK = 0
    nFail = 0
    for (i = 0; i < n; i += 1)
        onePath = StringFromList(i, pathList, ";")
        if (strlen(onePath) == 0)
            continue
        endif
        String/G $(LJZ_MDCTrack_BaseDF() + ":ApplyCorrLastOutputList") = ""
        ret = LJZ_MDCTrack_ApplyCorrectionToWaveEx(onePath, runDFIn, suffix, skipFlagged, outputToRunDF)
        if (ret == 0)
            SVAR lastOut = $(LJZ_MDCTrack_BaseDF() + ":ApplyCorrLastOutputList")
            if (strlen(lastOut) > 0)
                outList += lastOut
            else
                Print "WARNING: ApplyCorrectionToList: success return but no output path was recorded for " + onePath
            endif
            nOK += 1
        else
            nFail += 1
        endif
    endfor

    String/G $(LJZ_MDCTrack_BaseDF() + ":ApplyCorrLastOutputList") = outList
    String runDF
    runDF = LJZ_MDCTrack_df_with_colon(runDFIn)
    if (DataFolderExists(runDF))
        String/G $(runDF + "ApplyCorrLastOutputList") = outList
    endif
    if (LJZ_MDCTrack_RunUsesSingleCorrection(runDFIn))
        Print "ApplyCorrectionToList mapping: single-reference run; all source layers use correction row 0."
    else
        Print "ApplyCorrectionToList mapping: multi-reference run; each source wave maps layer iz to correction row iz independently."
        Print "If your run rows concatenate multiple source waves, apply waves separately or use a row-offset workflow."
    endif
    Printf "ApplyCorrectionToList summary: input waves=%d; succeeded=%d; failed=%d\r", n, nOK, nFail

    return nOK
End

Function LJZ_MDCTrack_ApplyCorrectionToList(pathList, runDFIn, suffix, skipFlagged)
    String pathList
    String runDFIn
    String suffix
    Variable skipFlagged

    return LJZ_MDCTrack_ApplyCorrectionToListEx(pathList, runDFIn, suffix, skipFlagged, 0)
End

Function LJZ_MDCTrack_ApplyCorrectionFromPanel(applyAll)
    Variable applyAll

    LJZ_MDCTrack_EnsureDF()

    SVAR targetSel = $(LJZ_MDCTrack_BaseDF() + ":TargetWaveSel")
    SVAR runDF = $(LJZ_MDCTrack_BaseDF() + ":RunDF")
    SVAR suffix = $(LJZ_MDCTrack_BaseDF() + ":ApplySuffix")
    SVAR status = $(LJZ_MDCTrack_BaseDF() + ":Status")
    NVAR skipFlagged = $(LJZ_MDCTrack_BaseDF() + ":ApplySkipFlagged")
    NVAR outputToRunDF = $(LJZ_MDCTrack_BaseDF() + ":ApplyOutputToRunDF")

    Variable ret
    if (applyAll != 0)
        ret = LJZ_MDCTrack_ApplyCorrectionToListEx("", runDF, suffix, skipFlagged, outputToRunDF)
    else
        if (strlen(targetSel) == 0)
            Print "Apply Corr: no target/source wave selected."
            status = "Apply Corr failed: no selected wave."
            return -1
        endif
        ret = LJZ_MDCTrack_ApplyCorrectionToWaveEx(targetSel, runDF, suffix, skipFlagged, outputToRunDF)
    endif

    if (ret >= 0)
        status = "Apply Corr done."
    else
        status = "Apply Corr failed."
    endif

    return ret
End

// ============================================================================
// Section 4. Graph display and text summary
// ============================================================================

Function LJZ_MDCTrack_PrepareDiagnosticMaskWaves(runDF)
    String runDF

    String df
    df = LJZ_MDCTrack_df_with_colon(runDF)

    Wave/Z dK = $(df + "dK_toRef")
    Wave/Z flag = $(df + "flag")
    if (!WaveExists(dK) || !WaveExists(flag))
        return -1
    endif

    Variable n
    Variable i
    Variable f
    n = numpnts(dK)

    Make/O/D/N=(n) $(df + "diag_row_index") = p
    Make/O/D/N=(n) $(df + "diag_dK_good") = NaN
    Make/O/D/N=(n) $(df + "diag_dK_lowCorr") = NaN
    Make/O/D/N=(n) $(df + "diag_dK_shiftBound") = NaN
    Make/O/D/N=(n) $(df + "diag_dK_scaleBound") = NaN
    Make/O/D/N=(n) $(df + "diag_dK_fewPairs") = NaN
    Make/O/D/N=(n) $(df + "diag_dK_error") = NaN

    Wave good = $(df + "diag_dK_good")
    Wave lowCorr = $(df + "diag_dK_lowCorr")
    Wave shiftBound = $(df + "diag_dK_shiftBound")
    Wave scaleBound = $(df + "diag_dK_scaleBound")
    Wave fewPairs = $(df + "diag_dK_fewPairs")
    Wave waveError = $(df + "diag_dK_error")

    SetScale/P x, 0, 1, "row", good
    SetScale/P x, 0, 1, "row", lowCorr
    SetScale/P x, 0, 1, "row", shiftBound
    SetScale/P x, 0, 1, "row", scaleBound
    SetScale/P x, 0, 1, "row", fewPairs
    SetScale/P x, 0, 1, "row", waveError

    for (i = 0; i < n; i += 1)
        f = flag[i]
        if (numtype(dK[i]) != 0 || numtype(f) != 0)
            continue
        endif
        if (f == 0)
            good[i] = dK[i]
        elseif (f == 1)
            lowCorr[i] = dK[i]
        elseif (f == 2)
            shiftBound[i] = dK[i]
        elseif (f == 3)
            scaleBound[i] = dK[i]
        elseif (f == 4)
            fewPairs[i] = dK[i]
        else
            waveError[i] = dK[i]
        endif
    endfor

    return 0
End

Function LJZ_MDCTrack_ShowDiagnostics()
    LJZ_MDCTrack_EnsureDF()

    SVAR runDFGlobal = $(LJZ_MDCTrack_BaseDF() + ":RunDF")
    String runDF
    runDF = LJZ_MDCTrack_df_with_colon(runDFGlobal)

    Wave/Z dK = $(runDF + "dK_toRef")
    Wave/Z corr = $(runDF + "similarity")
    Wave/Z flag = $(runDF + "flag")
    Wave/Z frac = $(runDF + "nPairsFrac")
    if (!WaveExists(dK) || !WaveExists(corr))
        Print "No diagnostics available."
        return -1
    endif

    LJZ_MDCTrack_SetResultRowScale(runDF)
    LJZ_MDCTrack_PrepareDiagnosticMaskWaves(runDF)

    Wave/Z good = $(runDF + "diag_dK_good")
    Wave/Z lowCorr = $(runDF + "diag_dK_lowCorr")
    Wave/Z shiftBound = $(runDF + "diag_dK_shiftBound")
    Wave/Z scaleBound = $(runDF + "diag_dK_scaleBound")
    Wave/Z fewPairs = $(runDF + "diag_dK_fewPairs")
    Wave/Z waveError = $(runDF + "diag_dK_error")

    String graphName
    graphName = LJZ_MDCTrack_GraphNameForRun("MDCTrackDiag", runDF)
    DoWindow/K $graphName
    Display/N=$graphName dK
    AppendToGraph/R corr
    if (WaveExists(frac))
        AppendToGraph/R=pairAxis frac
    endif
    if (WaveExists(flag))
        AppendToGraph/L=flagAxis flag
    endif
    if (WaveExists(good))
        AppendToGraph good, lowCorr, shiftBound, scaleBound, fewPairs, waveError
    endif

    ModifyGraph/W=$graphName mode=4, marker=19
    ModifyGraph/W=$graphName rgb(dK_toRef)=(0,0,0)
    if (WaveExists(good))
        ModifyGraph/W=$graphName rgb(diag_dK_good)=(0,40000,0), rgb(diag_dK_lowCorr)=(65535,32768,0)
        ModifyGraph/W=$graphName rgb(diag_dK_shiftBound)=(65535,0,0), rgb(diag_dK_scaleBound)=(45000,0,65535)
        ModifyGraph/W=$graphName rgb(diag_dK_fewPairs)=(0,30000,65535), rgb(diag_dK_error)=(30000,30000,30000)
        ModifyGraph/W=$graphName msize(diag_dK_good)=4, msize(diag_dK_lowCorr)=4, msize(diag_dK_shiftBound)=4
        ModifyGraph/W=$graphName msize(diag_dK_scaleBound)=4, msize(diag_dK_fewPairs)=4, msize(diag_dK_error)=4
    endif
    ModifyGraph/W=$graphName mirror=2
    if (WaveExists(flag))
        ModifyGraph/W=$graphName axisEnab(flagAxis)={0,0.20}
    endif
    Label/W=$graphName left "dK_toRef"
    Label/W=$graphName right "similarity"
    if (WaveExists(frac))
        Label/W=$graphName pairAxis "nPairs fraction"
    endif
    Label/W=$graphName bottom "registered row"
    if (WaveExists(flag))
        Label/W=$graphName flagAxis "flag"
    endif
    DoWindow/T $graphName, "MDCTrack Diagnostics: " + LJZ_MDCTrack_RunLabelFromDF(runDF)

    LJZ_MDCTrack_PrintSummary()
    return 0
End

Function LJZ_MDCTrack_ShowCorrShiftLandscape()
    LJZ_MDCTrack_EnsureDF()

    SVAR runDFGlobal = $(LJZ_MDCTrack_BaseDF() + ":RunDF")
    String runDF
    runDF = LJZ_MDCTrack_df_with_colon(runDFGlobal)

    Wave/Z corrShift = $(runDF + "corr_vs_shift")
    Wave/Z dK = $(runDF + "dK_toRef")
    if (!WaveExists(corrShift))
        Print "corr_vs_shift missing. Register targets first."
        return -1
    endif

    String graphName
    graphName = LJZ_MDCTrack_GraphNameForRun("MDCTrackCorrShift", runDF)
    DoWindow/K $graphName
    Display/N=$graphName
    AppendImage corrShift
    if (WaveExists(dK))
        SetScale/P x, 0, 1, "row", dK
        AppendToGraph dK
        ModifyGraph/W=$graphName rgb(dK_toRef)=(65535,0,0), lsize(dK_toRef)=2
    endif
    ModifyGraph/W=$graphName mirror=2
    Label/W=$graphName bottom "registered row"
    Label/W=$graphName left "trial dK"
    DoWindow/T $graphName, "Corr vs shift: " + LJZ_MDCTrack_RunLabelFromDF(runDF)
    return 0
End

Function LJZ_MDCTrack_ShowCorrScaleLandscape()
    LJZ_MDCTrack_EnsureDF()

    SVAR runDFGlobal = $(LJZ_MDCTrack_BaseDF() + ":RunDF")
    String runDF
    runDF = LJZ_MDCTrack_df_with_colon(runDFGlobal)

    Wave/Z corrScale = $(runDF + "corr_vs_scale")
    Wave/Z sc = $(runDF + "scale_toRef")
    if (!WaveExists(corrScale))
        Print "corr_vs_scale missing. Register targets first."
        return -1
    endif

    String graphName
    graphName = LJZ_MDCTrack_GraphNameForRun("MDCTrackCorrScale", runDF)
    DoWindow/K $graphName
    Display/N=$graphName
    AppendImage corrScale
    if (WaveExists(sc))
        SetScale/P x, 0, 1, "row", sc
        AppendToGraph sc
        ModifyGraph/W=$graphName rgb(scale_toRef)=(65535,0,0), lsize(scale_toRef)=2
    endif
    ModifyGraph/W=$graphName mirror=2
    Label/W=$graphName bottom "registered row"
    Label/W=$graphName left "trial scale"
    DoWindow/T $graphName, "Corr vs scale: " + LJZ_MDCTrack_RunLabelFromDF(runDF)
    return 0
End

Function LJZ_MDCTrack_ShowReference()
    LJZ_MDCTrack_EnsureDF()

    SVAR runDFGlobal = $(LJZ_MDCTrack_BaseDF() + ":RunDF")
    String runDF
    runDF = LJZ_MDCTrack_df_with_colon(runDFGlobal)

    Wave/Z ref = $(runDF + "ref_profile")
    Wave/Z refProc = $(runDF + "ref_profile_proc")
    if (!WaveExists(ref))
        Print "ref_profile missing."
        return -1
    endif

    String graphName
    graphName = LJZ_MDCTrack_GraphNameForRun("MDCTrackRef", runDF)
    DoWindow/K $graphName
    Display/N=$graphName ref
    if (WaveExists(refProc))
        AppendToGraph/R refProc
        Label/W=$graphName right "processed"
    endif
    ModifyGraph/W=$graphName mirror=2
    Label/W=$graphName left "raw reference"
    Label/W=$graphName bottom "k"
    DoWindow/T $graphName, "MDCTrack Reference: " + LJZ_MDCTrack_RunLabelFromDF(runDF)

    return 0
End

Function LJZ_MDCTrack_PrintSummary()
    LJZ_MDCTrack_EnsureDF()

    SVAR runDFGlobal = $(LJZ_MDCTrack_BaseDF() + ":RunDF")
    String runDF
    runDF = LJZ_MDCTrack_df_with_colon(runDFGlobal)

    Wave/T/Z targetPath = $(runDF + "target_path")
    Wave/Z targetLayer = $(runDF + "target_layer")
    Wave/Z dK = $(runDF + "dK_toRef")
    Wave/Z sc = $(runDF + "scale_toRef")
    Wave/Z corr = $(runDF + "similarity")
    Wave/Z res = $(runDF + "residual")
    Wave/Z flag = $(runDF + "flag")
    Wave/Z np = $(runDF + "nPairs")
    Wave/Z frac = $(runDF + "nPairsFrac")
    Wave/T/Z reason = $(runDF + "flag_reason")

    if (!WaveExists(targetPath) || !WaveExists(dK) || !WaveExists(corr) || !WaveExists(flag))
        Print "No MDCTrack summary available."
        return -1
    endif

    Variable i
    Variable n
    Variable nFlag
    String shortPath
    String mark
    String why
    Variable fracVal
    n = numpnts(dK)
    nFlag = 0

    Print ""
    Print "===== MDCTrack Summary: " + LJZ_MDCTrack_RunLabelFromDF(runDF) + " ====="
    Print "RunDF: " + runDF
    Print "row | target | layer | dK | scale | similarity | residual | nPairs | nPairsFrac | flag | reason"

    for (i = 0; i < n; i += 1)
        shortPath = targetPath[i]
        if (strlen(shortPath) > 48)
            shortPath = shortPath[strlen(shortPath) - 48, strlen(shortPath) - 1]
        endif
        if (flag[i] != 0)
            mark = "*** "
            nFlag += 1
        else
            mark = "    "
        endif
        if (WaveExists(reason))
            why = reason[i]
        else
            why = LJZ_MDCTrack_FlagText(flag[i])
        endif
        if (WaveExists(frac))
            fracVal = frac[i]
        else
            fracVal = NaN
        endif
        Printf "%s%4d | %s | %.0f | %.6g | %.6g | %.6g | %.6g | %.0f | %.3f | %.0f | %s\r", mark, i, shortPath, targetLayer[i], dK[i], sc[i], corr[i], res[i], np[i], fracVal, flag[i], why
    endfor

    Printf "Total rows: %d; flagged rows: %d\r", n, nFlag
    Print "=============================================="
    return 0
End

// ============================================================================
// Section 5. Panel creation
// ============================================================================

Function LJZ_MDCTrack_OpenPanel()
    LJZ_MDCTrack_EnsureDF()

    String pn
    pn = LJZ_MDCTrack_PanelName()

    DoWindow/F $pn
    if (V_flag != 0)
        return 0
    endif

    NewPanel/K=1/N=$pn/W=(80,80,980,680) as "LJZ MDC Track"

    SVAR refPath = $(LJZ_MDCTrack_BaseDF() + ":RefWavePath")
    SVAR targetDF = $(LJZ_MDCTrack_BaseDF() + ":TargetDF")
    SVAR runName = $(LJZ_MDCTrack_BaseDF() + ":RunName")
    SVAR peakRaw = $(LJZ_MDCTrack_BaseDF() + ":PeakRawPath")
    SVAR runDF = $(LJZ_MDCTrack_BaseDF() + ":RunDF")
    SVAR status = $(LJZ_MDCTrack_BaseDF() + ":Status")
    SVAR applySuffix = $(LJZ_MDCTrack_BaseDF() + ":ApplySuffix")

    NVAR applySkipFlagged = $(LJZ_MDCTrack_BaseDF() + ":ApplySkipFlagged")
    NVAR applyOutputToRunDF = $(LJZ_MDCTrack_BaseDF() + ":ApplyOutputToRunDF")
    NVAR usePhysE = $(LJZ_MDCTrack_BaseDF() + ":UsePhysE")
    NVAR refE0 = $(LJZ_MDCTrack_BaseDF() + ":RefE0")
    NVAR refE1 = $(LJZ_MDCTrack_BaseDF() + ":RefE1")
    NVAR usePhysK = $(LJZ_MDCTrack_BaseDF() + ":UsePhysK")
    NVAR k0 = $(LJZ_MDCTrack_BaseDF() + ":K0")
    NVAR k1 = $(LJZ_MDCTrack_BaseDF() + ":K1")
    NVAR refStack0 = $(LJZ_MDCTrack_BaseDF() + ":RefStack0")
    NVAR refStack1 = $(LJZ_MDCTrack_BaseDF() + ":RefStack1")
    NVAR maxShift = $(LJZ_MDCTrack_BaseDF() + ":MaxShift")
    NVAR corrThresh = $(LJZ_MDCTrack_BaseDF() + ":CorrThresh")
    NVAR fitScale = $(LJZ_MDCTrack_BaseDF() + ":FitScale")
    NVAR scaleMin = $(LJZ_MDCTrack_BaseDF() + ":ScaleMin")
    NVAR scaleMax = $(LJZ_MDCTrack_BaseDF() + ":ScaleMax")
    NVAR scaleN = $(LJZ_MDCTrack_BaseDF() + ":ScaleN")
    NVAR kCenter = $(LJZ_MDCTrack_BaseDF() + ":KCenter")
    NVAR preprocess = $(LJZ_MDCTrack_BaseDF() + ":PreprocessMode")
    NVAR smoothN = $(LJZ_MDCTrack_BaseDF() + ":SmoothN")
    NVAR recursive = $(LJZ_MDCTrack_BaseDF() + ":Recursive")

    SetVariable svRef,pos={12,14},size={560,18},title="RefWavePath",value=root:ARPES_LJZ:MDCTrack:RefWavePath,proc=LJZ_MDCTrack_SetVarProc
    SetVariable svTargetDF,pos={12,40},size={560,18},title="TargetDF",value=root:ARPES_LJZ:MDCTrack:TargetDF,proc=LJZ_MDCTrack_SetVarProc
    SetVariable svRunName,pos={12,66},size={300,18},title="RunName",value=root:ARPES_LJZ:MDCTrack:RunName,proc=LJZ_MDCTrack_SetVarProc
    CheckBox cbRecursive,pos={330,68},title="recursive",variable=root:ARPES_LJZ:MDCTrack:Recursive,proc=LJZ_MDCTrack_CheckProc
    Button btRefresh,pos={430,64},size={110,22},title="Refresh Targets",proc=LJZ_MDCTrack_ButtonProc

    SetVariable svRefE0,pos={12,104},size={150,18},title="RefE0",value=root:ARPES_LJZ:MDCTrack:RefE0,proc=LJZ_MDCTrack_SetVarProc
    SetVariable svRefE1,pos={170,104},size={150,18},title="RefE1",value=root:ARPES_LJZ:MDCTrack:RefE1,proc=LJZ_MDCTrack_SetVarProc
    CheckBox cbUsePhysE,pos={335,106},title="phys E",variable=root:ARPES_LJZ:MDCTrack:UsePhysE,proc=LJZ_MDCTrack_CheckProc
    SetVariable svRefS0,pos={430,104},size={120,18},title="RefS0",value=root:ARPES_LJZ:MDCTrack:RefStack0,proc=LJZ_MDCTrack_SetVarProc
    SetVariable svRefS1,pos={560,104},size={120,18},title="RefS1",value=root:ARPES_LJZ:MDCTrack:RefStack1,proc=LJZ_MDCTrack_SetVarProc

    SetVariable svK0,pos={12,130},size={150,18},title="K0",value=root:ARPES_LJZ:MDCTrack:K0,proc=LJZ_MDCTrack_SetVarProc
    SetVariable svK1,pos={170,130},size={150,18},title="K1",value=root:ARPES_LJZ:MDCTrack:K1,proc=LJZ_MDCTrack_SetVarProc
    CheckBox cbUsePhysK,pos={335,132},title="phys K",variable=root:ARPES_LJZ:MDCTrack:UsePhysK,proc=LJZ_MDCTrack_CheckProc
    SetVariable svKCenter,pos={430,130},size={150,18},title="kCenter",value=root:ARPES_LJZ:MDCTrack:KCenter,proc=LJZ_MDCTrack_SetVarProc

    SetVariable svMaxShift,pos={12,156},size={150,18},title="maxShift",value=root:ARPES_LJZ:MDCTrack:MaxShift,proc=LJZ_MDCTrack_SetVarProc
    SetVariable svCorrThresh,pos={170,156},size={150,18},title="corrThresh",value=root:ARPES_LJZ:MDCTrack:CorrThresh,proc=LJZ_MDCTrack_SetVarProc
    SetVariable svPreprocess,pos={335,156},size={130,18},title="preproc",value=root:ARPES_LJZ:MDCTrack:PreprocessMode,proc=LJZ_MDCTrack_SetVarProc
    SetVariable svSmoothN,pos={475,156},size={130,18},title="smoothN",value=root:ARPES_LJZ:MDCTrack:SmoothN,proc=LJZ_MDCTrack_SetVarProc

    CheckBox cbFitScale,pos={12,184},title="fit scale",variable=root:ARPES_LJZ:MDCTrack:FitScale,proc=LJZ_MDCTrack_CheckProc
    SetVariable svScaleMin,pos={110,182},size={130,18},title="scaleMin",value=root:ARPES_LJZ:MDCTrack:ScaleMin,proc=LJZ_MDCTrack_SetVarProc
    SetVariable svScaleMax,pos={250,182},size={130,18},title="scaleMax",value=root:ARPES_LJZ:MDCTrack:ScaleMax,proc=LJZ_MDCTrack_SetVarProc
    SetVariable svScaleN,pos={390,182},size={120,18},title="scaleN",value=root:ARPES_LJZ:MDCTrack:ScaleN,proc=LJZ_MDCTrack_SetVarProc

    Button btBuildRef,pos={12,216},size={110,24},title="Build Reference",proc=LJZ_MDCTrack_ButtonProc
    Button btShowRef,pos={132,216},size={80,24},title="Show Ref",proc=LJZ_MDCTrack_ButtonProc
    Button btRegSel,pos={222,216},size={110,24},title="Register Sel",proc=LJZ_MDCTrack_ButtonProc
    Button btRegAll,pos={342,216},size={82,24},title="Reg All",proc=LJZ_MDCTrack_ButtonProc
    Button btDiag,pos={434,216},size={82,24},title="Diag",proc=LJZ_MDCTrack_ButtonProc
    Button btCorrShift,pos={526,216},size={88,24},title="Corr Shift",proc=LJZ_MDCTrack_ButtonProc
    Button btCorrScale,pos={624,216},size={88,24},title="Corr Scale",proc=LJZ_MDCTrack_ButtonProc
    Button btSummary,pos={722,216},size={78,24},title="Summary",proc=LJZ_MDCTrack_ButtonProc

    SetVariable svRunDF,pos={12,252},size={760,18},title="RunDF",value=root:ARPES_LJZ:MDCTrack:RunDF,proc=LJZ_MDCTrack_SetVarProc
    SetVariable svPeakRaw,pos={12,278},size={620,18},title="PeakRawPath",value=root:ARPES_LJZ:MDCTrack:PeakRawPath,proc=LJZ_MDCTrack_SetVarProc
    Button btCorrectPeak,pos={645,274},size={125,24},title="Correct Peak",proc=LJZ_MDCTrack_ButtonProc

    SetVariable svApplySuffix,pos={12,306},size={180,18},title="ApplySuffix",value=root:ARPES_LJZ:MDCTrack:ApplySuffix,proc=LJZ_MDCTrack_SetVarProc
    CheckBox cbApplySkipFlagged,pos={210,308},title="skip flagged",variable=root:ARPES_LJZ:MDCTrack:ApplySkipFlagged,proc=LJZ_MDCTrack_CheckProc
    CheckBox cbApplyToRunDF,pos={325,308},title="to runDF",variable=root:ARPES_LJZ:MDCTrack:ApplyOutputToRunDF,proc=LJZ_MDCTrack_CheckProc
    Button btApplyCorr,pos={430,302},size={110,24},title="Apply Corr",proc=LJZ_MDCTrack_ButtonProc
    Button btApplyCorrAll,pos={550,302},size={120,24},title="Apply Corr All",proc=LJZ_MDCTrack_ButtonProc

    ListBox lbTargets,pos={12,340},size={860,150},listWave=$(LJZ_MDCTrack_BaseDF() + ":LB_Disp"),selWave=$(LJZ_MDCTrack_BaseDF() + ":LB_Sel"),mode=1,proc=LJZ_MDCTrack_ListBoxProc

    SetVariable svStatus,pos={12,530},size={860,18},title="Status",value=root:ARPES_LJZ:MDCTrack:Status,proc=LJZ_MDCTrack_SetVarProc,noedit=1

    LJZ_MDCTrack_RebuildTargetList()

    return 0
End

// ============================================================================
// Section 6. Control callbacks
// ============================================================================

Function LJZ_MDCTrack_SetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    if (sva.eventCode != 1 && sva.eventCode != 2 && sva.eventCode != 3)
        return 0
    endif

    return 0
End

Function LJZ_MDCTrack_CheckProc(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba

    if (cba.eventCode != 2)
        return 0
    endif

    return 0
End

Function LJZ_MDCTrack_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btRefresh") == 0)
        LJZ_MDCTrack_RebuildTargetList()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btBuildRef") == 0)
        LJZ_MDCTrack_BuildReference()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btShowRef") == 0)
        LJZ_MDCTrack_ShowReference()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btRegSel") == 0)
        LJZ_MDCTrack_RegisterSelected()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btRegAll") == 0)
        LJZ_MDCTrack_RegisterAllTargets()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btDiag") == 0)
        LJZ_MDCTrack_ShowDiagnostics()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btCorrShift") == 0)
        LJZ_MDCTrack_ShowCorrShiftLandscape()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btCorrScale") == 0)
        LJZ_MDCTrack_ShowCorrScaleLandscape()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btSummary") == 0)
        LJZ_MDCTrack_PrintSummary()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btCorrectPeak") == 0)
        LJZ_MDCTrack_CorrectPeakFromPanel()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btApplyCorr") == 0)
        LJZ_MDCTrack_ApplyCorrectionFromPanel(0)
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btApplyCorrAll") == 0)
        LJZ_MDCTrack_ApplyCorrectionFromPanel(1)
        return 0
    endif

    return 0
End

Function LJZ_MDCTrack_ListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if (lba.eventCode != 4)
        return 0
    endif

    LJZ_MDCTrack_EnsureDF()

    Wave/T/Z wPath = $(LJZ_MDCTrack_BaseDF() + ":LB_Path")
    Wave/Z wSel = $(LJZ_MDCTrack_BaseDF() + ":LB_Sel")
    SVAR targetSel = $(LJZ_MDCTrack_BaseDF() + ":TargetWaveSel")

    if (!WaveExists(wPath) || !WaveExists(wSel))
        return 0
    endif

    Variable row
    row = lba.row
    if (row < 0 || row >= numpnts(wPath))
        return 0
    endif

    Variable i
    for (i = 0; i < numpnts(wSel); i += 1)
        if (i == row)
            wSel[i] = 1
        else
            wSel[i] = 0
        endif
    endfor

    targetSel = wPath[row]

    return 0
End

// ============================================================================
// Section 7. Command-line helpers
// ============================================================================

Function LJZ_MDCTrack_RunSimple(refWavePath, targetWavePath, runNameIn, e0, e1, k0In, k1In, maxShiftIn)
    String refWavePath
    String targetWavePath
    String runNameIn
    Variable e0
    Variable e1
    Variable k0In
    Variable k1In
    Variable maxShiftIn

    LJZ_MDCTrack_EnsureDF()

    SVAR refPath = $(LJZ_MDCTrack_BaseDF() + ":RefWavePath")
    SVAR targetSel = $(LJZ_MDCTrack_BaseDF() + ":TargetWaveSel")
    SVAR runName = $(LJZ_MDCTrack_BaseDF() + ":RunName")
    NVAR refE0 = $(LJZ_MDCTrack_BaseDF() + ":RefE0")
    NVAR refE1 = $(LJZ_MDCTrack_BaseDF() + ":RefE1")
    NVAR k0 = $(LJZ_MDCTrack_BaseDF() + ":K0")
    NVAR k1 = $(LJZ_MDCTrack_BaseDF() + ":K1")
    NVAR maxShift = $(LJZ_MDCTrack_BaseDF() + ":MaxShift")
    NVAR fitScale = $(LJZ_MDCTrack_BaseDF() + ":FitScale")
    NVAR usePhysE = $(LJZ_MDCTrack_BaseDF() + ":UsePhysE")
    NVAR usePhysK = $(LJZ_MDCTrack_BaseDF() + ":UsePhysK")

    refPath = refWavePath
    targetSel = targetWavePath
    runName = runNameIn
    refE0 = e0
    refE1 = e1
    k0 = k0In
    k1 = k1In
    maxShift = maxShiftIn
    fitScale = 0
    usePhysE = 1
    usePhysK = 1

    Variable ret
    ret = LJZ_MDCTrack_BuildReference()
    if (ret != 0)
        return ret
    endif

    ret = LJZ_MDCTrack_RegisterSelected()
    return ret
End
