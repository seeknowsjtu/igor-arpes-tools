#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// LJZ_A2K1D_Core.ipf
// Core A2K1D logic only: initialization, data-folder helpers, geometry and angle/k transforms,
// sigma/value/spectra transforms, name parsing, wave collection, correction/batch helpers,
// cleanup helpers, long-table transforms, and delta-k generation. Keep UI and plotting in LJZ_A2K1D_UIPlot.ipf.

Function a2k1d_ensure_folder()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:A2K1D
    NewDataFolder/O root:ARPES_LJZ:OUTPUT
    NewDataFolder/O root:ARPES_LJZ:OUTPUT:A2K1D
End

Function/S a2k1d_df_with_colon(inStr)
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

Function a2k1d_df_exists(dfStr)
    String dfStr
    String s = a2k1d_df_with_colon(dfStr)
    return DataFolderExists(s)
End

Function/S a2k1d_norm_list(listStr)
    String listStr
    String s=listStr
    s = ReplaceString("\r", s, ";")
    s = ReplaceString("\n", s, ";")
    return s
End



//============================================================
// Unified A2K1D / EKKMap geometry compatibility
//============================================================
Function a2k1d_sync_legacy_from_unified()
    a2k1d_ensure_folder()

    NVAR/Z ThetaAngle = root:ARPES_LJZ:A2K1D:ThetaAngle
    NVAR/Z hv = root:ARPES_LJZ:A2K1D:hv
    NVAR/Z WorkFunc = root:ARPES_LJZ:A2K1D:WorkFunc
    NVAR/Z EnergyRel = root:ARPES_LJZ:A2K1D:EnergyRel
    NVAR/Z MDCKf = root:ARPES_LJZ:A2K1D:MDCKf
    NVAR/Z LatticeA = root:ARPES_LJZ:A2K1D:LatticeA
    NVAR/Z Pixel = root:ARPES_LJZ:A2K1D:Pixel

    if (!NVAR_Exists(ThetaAngle) || !NVAR_Exists(hv) || !NVAR_Exists(WorkFunc) || !NVAR_Exists(EnergyRel) || !NVAR_Exists(MDCKf) || !NVAR_Exists(LatticeA) || !NVAR_Exists(Pixel))
        return -1
    endif

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:A2K1D
    Variable/G a2k1d_thetaOffset = -ThetaAngle
    Variable/G a2k1d_hv = hv
    Variable/G a2k1d_workFunc = WorkFunc
    Variable/G a2k1d_energyE = EnergyRel
    Variable/G a2k1d_kShift = MDCKf
    Variable/G a2k1d_LC = LatticeA
    Variable/G a2k1d_degPerPix = Pixel
    SetDataFolder df0
    return 0
End

Function a2k1d_sync_unified_from_legacy_if_missing()
    a2k1d_ensure_folder()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:A2K1D

    NVAR/Z legacyThetaOffset = root:ARPES_LJZ:A2K1D:a2k1d_thetaOffset
    if (!NVAR_Exists(legacyThetaOffset))
        Variable/G a2k1d_thetaOffset = 0
    endif
    NVAR/Z legacyHv = root:ARPES_LJZ:A2K1D:a2k1d_hv
    if (!NVAR_Exists(legacyHv))
        Variable/G a2k1d_hv = 21.2
    endif
    NVAR/Z legacyWorkFunc = root:ARPES_LJZ:A2K1D:a2k1d_workFunc
    if (!NVAR_Exists(legacyWorkFunc))
        Variable/G a2k1d_workFunc = 4.5
    endif
    NVAR/Z legacyEnergyRel = root:ARPES_LJZ:A2K1D:a2k1d_energyE
    if (!NVAR_Exists(legacyEnergyRel))
        Variable/G a2k1d_energyE = 0
    endif
    NVAR/Z legacyMDCKf = root:ARPES_LJZ:A2K1D:a2k1d_kShift
    if (!NVAR_Exists(legacyMDCKf))
        Variable/G a2k1d_kShift = 0
    endif
    NVAR/Z legacyLatticeA = root:ARPES_LJZ:A2K1D:a2k1d_LC
    if (!NVAR_Exists(legacyLatticeA))
        Variable/G a2k1d_LC = 0
    endif
    NVAR/Z legacyPixel = root:ARPES_LJZ:A2K1D:a2k1d_degPerPix
    if (!NVAR_Exists(legacyPixel))
        Variable/G a2k1d_degPerPix = 0
    endif

    NVAR legacyThetaOffset2 = root:ARPES_LJZ:A2K1D:a2k1d_thetaOffset
    NVAR legacyHv2 = root:ARPES_LJZ:A2K1D:a2k1d_hv
    NVAR legacyWorkFunc2 = root:ARPES_LJZ:A2K1D:a2k1d_workFunc
    NVAR legacyEnergyRel2 = root:ARPES_LJZ:A2K1D:a2k1d_energyE
    NVAR legacyMDCKf2 = root:ARPES_LJZ:A2K1D:a2k1d_kShift
    NVAR legacyLatticeA2 = root:ARPES_LJZ:A2K1D:a2k1d_LC
    NVAR legacyPixel2 = root:ARPES_LJZ:A2K1D:a2k1d_degPerPix

    NVAR/Z ThetaAngle = root:ARPES_LJZ:A2K1D:ThetaAngle
    if (!NVAR_Exists(ThetaAngle))
        Variable/G ThetaAngle = -legacyThetaOffset2
    endif
    NVAR/Z hv = root:ARPES_LJZ:A2K1D:hv
    if (!NVAR_Exists(hv))
        Variable/G hv = legacyHv2
    endif
    NVAR/Z WorkFunc = root:ARPES_LJZ:A2K1D:WorkFunc
    if (!NVAR_Exists(WorkFunc))
        Variable/G WorkFunc = legacyWorkFunc2
    endif
    NVAR/Z EnergyRel = root:ARPES_LJZ:A2K1D:EnergyRel
    if (!NVAR_Exists(EnergyRel))
        Variable/G EnergyRel = legacyEnergyRel2
    endif
    NVAR/Z MDCKf = root:ARPES_LJZ:A2K1D:MDCKf
    if (!NVAR_Exists(MDCKf))
        Variable/G MDCKf = legacyMDCKf2
    endif
    NVAR/Z LatticeA = root:ARPES_LJZ:A2K1D:LatticeA
    if (!NVAR_Exists(LatticeA))
        Variable/G LatticeA = legacyLatticeA2
    endif
    NVAR/Z Pixel = root:ARPES_LJZ:A2K1D:Pixel
    if (!NVAR_Exists(Pixel))
        Variable/G Pixel = legacyPixel2
    endif

    SetDataFolder df0
    a2k1d_sync_legacy_from_unified()
    return 0
End

Static Function a2k1d_KScaleA(latticeA)
    Variable latticeA
    Variable kScale = 0.5118
    if (latticeA != 0)
        kScale *= latticeA / pi
    endif
    return kScale
End

Static Function a2k1d_EKin(hv, workFunc, energyRel)
    Variable hv, workFunc, energyRel
    return hv - workFunc + energyRel
End

Static Function a2k1d_RawValueToAngle(rawValue, pixel)
    Variable rawValue, pixel
    Variable scale = (pixel == 0) ? 1 : pixel
    return rawValue * scale
End

Static Function a2k1d_AngleToK_Unified(rawAngleDeg, hv, workFunc, energyRel, thetaAngle, mdcKf, latticeA)
    Variable rawAngleDeg, hv, workFunc, energyRel, thetaAngle, mdcKf, latticeA
    Variable ekin = a2k1d_EKin(hv, workFunc, energyRel)
    if (numtype(ekin) != 0 || ekin <= 0)
        return NaN
    endif
    Variable k0 = a2k1d_KScaleA(latticeA) * sqrt(ekin)
    return k0 * sin((rawAngleDeg - thetaAngle) * pi / 180) - mdcKf
End

Static Function a2k1d_KToAngle_Unified(kVal, hv, workFunc, energyRel, thetaAngle, mdcKf, latticeA)
    Variable kVal, hv, workFunc, energyRel, thetaAngle, mdcKf, latticeA
    Variable ekin = a2k1d_EKin(hv, workFunc, energyRel)
    if (numtype(ekin) != 0 || ekin <= 0)
        return NaN
    endif
    Variable k0 = a2k1d_KScaleA(latticeA) * sqrt(ekin)
    if (k0 == 0)
        return NaN
    endif
    return asin(max(-1, min(1, (kVal + mdcKf) / k0))) * 180 / pi + thetaAngle
End

Static Function a2k1d_SigmaAngleToK_Unified(rawAngleDeg, sigmaAngle, pixel, hv, workFunc, energyRel, thetaAngle, latticeA)
    Variable rawAngleDeg, sigmaAngle, pixel, hv, workFunc, energyRel, thetaAngle, latticeA
    if (numtype(sigmaAngle) != 0 || sigmaAngle < 0)
        return NaN
    endif
    Variable ekin = a2k1d_EKin(hv, workFunc, energyRel)
    if (numtype(ekin) != 0 || ekin <= 0)
        return NaN
    endif
    Variable scale = (pixel == 0) ? 1 : pixel
    Variable k0 = a2k1d_KScaleA(latticeA) * sqrt(ekin)
    return abs(k0 * cos((rawAngleDeg - thetaAngle) * pi / 180) * scale * pi / 180) * sigmaAngle
End

//============================================================
// Defaults
//============================================================
Function a2k1d_init_defaults_if_needed()
    a2k1d_ensure_folder()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:A2K1D

    if (!WaveExists($"LB_Items"))
        Make/O/T/N=0 LB_Items
    endif
    if (!WaveExists($"LB_Sel"))
        Make/O/U/B/N=0 LB_Sel
    endif
        // --- 【新增】颜色盘选择列表 ---
    if (!WaveExists($"CT_LB_Items"))
        Make/O/T/N=0 CT_LB_Items
    endif
    if (!WaveExists($"CT_LB_Sel"))
        Make/O/U/B/N=0 CT_LB_Sel
    endif
    // --------- behavior knobs (no UI needed) ---------
    // 1) For batch: suppress graph windows
    NVAR/Z a2k1d_showGraph = root:ARPES_LJZ:A2K1D:a2k1d_showGraph
    if (!NVAR_Exists(a2k1d_showGraph))
        Variable/G a2k1d_showGraph = 1      // 1=show check window, 0=silent
    endif

    // 2) layer_x maximum index (default 60; change in command line if needed)
    NVAR/Z a2k1d_layerMax = root:ARPES_LJZ:A2K1D:a2k1d_layerMax
    if (!NVAR_Exists(a2k1d_layerMax))
        Variable/G a2k1d_layerMax = 60
    endif

    SVAR/Z a2k1d_wavePath = root:ARPES_LJZ:A2K1D:a2k1d_wavePath
    if (!SVAR_Exists(a2k1d_wavePath))
        String/G a2k1d_wavePath = ""
    endif

    SVAR/Z a2k1d_baseDF = root:ARPES_LJZ:A2K1D:a2k1d_baseDF
    if (!SVAR_Exists(a2k1d_baseDF))
        String/G a2k1d_baseDF = "root:"
    endif

    NVAR/Z a2k1d_recursive = root:ARPES_LJZ:A2K1D:a2k1d_recursive
    if (!NVAR_Exists(a2k1d_recursive))
        Variable/G a2k1d_recursive = 0
    endif

    SVAR/Z a2k1d_corrRunDF = root:ARPES_LJZ:A2K1D:a2k1d_corrRunDF
    if (!SVAR_Exists(a2k1d_corrRunDF))
        String/G a2k1d_corrRunDF = ""
    endif

    NVAR/Z a2k1d_useAngleCorr = root:ARPES_LJZ:A2K1D:a2k1d_useAngleCorr
    if (!NVAR_Exists(a2k1d_useAngleCorr))
        Variable/G a2k1d_useAngleCorr = 0
    endif

    NVAR/Z a2k1d_corrSkipFlagged = root:ARPES_LJZ:A2K1D:a2k1d_corrSkipFlagged
    if (!NVAR_Exists(a2k1d_corrSkipFlagged))
        Variable/G a2k1d_corrSkipFlagged = 1
    endif

    NVAR/Z a2k1d_corrMode = root:ARPES_LJZ:A2K1D:a2k1d_corrMode
    if (!NVAR_Exists(a2k1d_corrMode))
        Variable/G a2k1d_corrMode = 0
    endif

    // Abort flag (for long loops)
    NVAR/Z a2k1d_abortFlag = root:ARPES_LJZ:A2K1D:a2k1d_abortFlag
    if (!NVAR_Exists(a2k1d_abortFlag))
        Variable/G a2k1d_abortFlag = 0
    endif

    // ---------------- unified geometry parameters ----------------
    // Legacy variables are kept for compatibility only. Core A2K1D geometry
    // reads ThetaAngle/hv/WorkFunc/EnergyRel/MDCKf/LatticeA/Pixel.
    a2k1d_sync_unified_from_legacy_if_missing()

    // outN: IGNORED in this mode (point-to-point map)
    NVAR/Z a2k1d_outN = root:ARPES_LJZ:A2K1D:a2k1d_outN
    if (!NVAR_Exists(a2k1d_outN))
        Variable/G a2k1d_outN = 0
    endif

    // Output baseName (optional). If empty, use NameOfWave(src)
    SVAR/Z a2k1d_baseName = root:ARPES_LJZ:A2K1D:a2k1d_baseName
    if (!SVAR_Exists(a2k1d_baseName))
        String/G a2k1d_baseName = ""
    endif
    
        // ---------------- plotting params ----------------
    // kvary: layer stack vertical offset per index
    NVAR/Z a2k1d_kvary = root:ARPES_LJZ:A2K1D:a2k1d_kvary
    if (!NVAR_Exists(a2k1d_kvary))
        Variable/G a2k1d_kvary = 0.0
    endif

    // Publication-style layer-stack plotting knobs (hidden; init only if missing)
    NVAR/Z a2k1d_stackCTLo = root:ARPES_LJZ:A2K1D:a2k1d_stackCTLo
    if (!NVAR_Exists(a2k1d_stackCTLo))
        Variable/G a2k1d_stackCTLo = 0.18
    endif

    NVAR/Z a2k1d_stackCTHi = root:ARPES_LJZ:A2K1D:a2k1d_stackCTHi
    if (!NVAR_Exists(a2k1d_stackCTHi))
        Variable/G a2k1d_stackCTHi = 0.92
    endif

    NVAR/Z a2k1d_stackHideYNumbers = root:ARPES_LJZ:A2K1D:a2k1d_stackHideYNumbers
    if (!NVAR_Exists(a2k1d_stackHideYNumbers))
        Variable/G a2k1d_stackHideYNumbers = 1
    endif


    // ---- CTLUZ params: ONLY init if missing (do NOT reset every time) ----
    SVAR/Z a2k1d_ctPickName = root:ARPES_LJZ:A2K1D:a2k1d_ctPickName
    if (!SVAR_Exists(a2k1d_ctPickName))
        String/G root:ARPES_LJZ:A2K1D:a2k1d_ctPickName = "Mavuika"
    endif

    NVAR/Z a2k1d_useCT = root:ARPES_LJZ:A2K1D:a2k1d_useCT
    if (!NVAR_Exists(a2k1d_useCT))
        Variable/G root:ARPES_LJZ:A2K1D:a2k1d_useCT = 1
    endif

    NVAR/Z a2k1d_ctInvert = root:ARPES_LJZ:A2K1D:a2k1d_ctInvert
    if (!NVAR_Exists(a2k1d_ctInvert))
        Variable/G root:ARPES_LJZ:A2K1D:a2k1d_ctInvert = 0
    endif
    // ---------------- heatmap params ----------------
    // y-axis physical value = hmY0 + rowIndex * hmDY
    NVAR/Z a2k1d_hmY0 = root:ARPES_LJZ:A2K1D:a2k1d_hmY0
    if (!NVAR_Exists(a2k1d_hmY0))
        Variable/G root:ARPES_LJZ:A2K1D:a2k1d_hmY0 = 0
    endif

    NVAR/Z a2k1d_hmDY = root:ARPES_LJZ:A2K1D:a2k1d_hmDY
    if (!NVAR_Exists(a2k1d_hmDY))
        Variable/G root:ARPES_LJZ:A2K1D:a2k1d_hmDY = 1
    endif

    // 0=Delay(ps), 1=Temperature(K), 2=Fluence(uJ/cm^2), 3=Frame Index
    NVAR/Z a2k1d_hmUnitMode = root:ARPES_LJZ:A2K1D:a2k1d_hmUnitMode
    if (!NVAR_Exists(a2k1d_hmUnitMode))
        Variable/G root:ARPES_LJZ:A2K1D:a2k1d_hmUnitMode = 0
    endif
    
    NVAR/Z a2k1d_hmYMul = root:ARPES_LJZ:A2K1D:a2k1d_hmYMul
    if (!NVAR_Exists(a2k1d_hmYMul))
        Variable/G root:ARPES_LJZ:A2K1D:a2k1d_hmYMul = 1
    endif

    NVAR/Z a2k1d_hmDisplayMode = root:ARPES_LJZ:A2K1D:a2k1d_hmDisplayMode
    if (!NVAR_Exists(a2k1d_hmDisplayMode))
        Variable/G root:ARPES_LJZ:A2K1D:a2k1d_hmDisplayMode = 1
    endif

    NVAR/Z a2k1d_hmLoFrac = root:ARPES_LJZ:A2K1D:a2k1d_hmLoFrac
    if (!NVAR_Exists(a2k1d_hmLoFrac))
        Variable/G root:ARPES_LJZ:A2K1D:a2k1d_hmLoFrac = 0.02
    endif

    NVAR/Z a2k1d_hmHiFrac = root:ARPES_LJZ:A2K1D:a2k1d_hmHiFrac
    if (!NVAR_Exists(a2k1d_hmHiFrac))
        Variable/G root:ARPES_LJZ:A2K1D:a2k1d_hmHiFrac = 0.995
    endif

    NVAR/Z a2k1d_hmGamma = root:ARPES_LJZ:A2K1D:a2k1d_hmGamma
    if (!NVAR_Exists(a2k1d_hmGamma))
        Variable/G root:ARPES_LJZ:A2K1D:a2k1d_hmGamma = 0.80
    endif

    NVAR/Z a2k1d_hmBgSmooth = root:ARPES_LJZ:A2K1D:a2k1d_hmBgSmooth
    if (!NVAR_Exists(a2k1d_hmBgSmooth))
        Variable/G root:ARPES_LJZ:A2K1D:a2k1d_hmBgSmooth = 11
    endif

    NVAR/Z a2k1d_hmCTWhiteMix = root:ARPES_LJZ:A2K1D:a2k1d_hmCTWhiteMix
    if (!NVAR_Exists(a2k1d_hmCTWhiteMix))
        Variable/G root:ARPES_LJZ:A2K1D:a2k1d_hmCTWhiteMix = 0.25
    endif
    
    SetDataFolder df0
End

//============================================================
// Recursive scan: returns FULL PATH list, only 1D waves
//============================================================
Function/S a2k1d_collect_1d_waves_recursive(baseDF)
    String baseDF

    String df0 = GetDataFolder(1)
    String outList = ""

    if (!a2k1d_df_exists(baseDF))
        return ""
    endif

    SetDataFolder $baseDF

    String here = WaveList("*", ";", "DIMS:1")
    Variable idx, n
    n = ItemsInList(here, ";")
    for (idx=0; idx<n; idx+=1)
        String wn = StringFromList(idx, here, ";")
        if (strlen(wn) == 0)
            continue
        endif
        outList += (baseDF + wn + ";")
    endfor

    String subList = a2k1d_norm_list(DataFolderDir(2))
    Variable m
    m = ItemsInList(subList, ";")
    for (idx=0; idx<m; idx+=1)
        String fd = StringFromList(idx, subList, ";")
        if (strlen(fd) == 0)
            continue
        endif
        outList += a2k1d_collect_1d_waves_recursive(baseDF + fd + ":")
    endfor

    SetDataFolder df0
    return outList
End

Function a2k1d_is_generated_proc_wave_name(wn)
    String wn

    String lw = LowerStr(wn)

    // corrected angle-domain outputs
    if (StringMatch(lw, "layer_show_*_corr"))
        return 1
    endif
    if (StringMatch(lw, "peak1k_corr") || StringMatch(lw, "peak2k_corr") || StringMatch(lw, "peak3k_corr"))
        return 1
    endif
    if (StringMatch(lw, "sigmap1k_corr") || StringMatch(lw, "sigmap2k_corr") || StringMatch(lw, "sigmap3k_corr"))
        return 1
    endif

    // k-domain spectra/value outputs
    if (StringMatch(lw, "layer_show_*_k_spec"))
        return 1
    endif
    if (StringMatch(lw, "layer_show_*_k_spec_corr"))
        return 1
    endif
    if (StringMatch(lw, "peak1k_k") || StringMatch(lw, "peak2k_k") || StringMatch(lw, "peak3k_k"))
        return 1
    endif
    if (StringMatch(lw, "peak1k_k_corr") || StringMatch(lw, "peak2k_k_corr") || StringMatch(lw, "peak3k_k_corr"))
        return 1
    endif
    if (StringMatch(lw, "sigmap1k_k") || StringMatch(lw, "sigmap2k_k") || StringMatch(lw, "sigmap3k_k"))
        return 1
    endif
    if (StringMatch(lw, "sigmap1k_k_corr") || StringMatch(lw, "sigmap2k_k_corr") || StringMatch(lw, "sigmap3k_k_corr"))
        return 1
    endif

    // delta outputs, support both lower and upper spelling via LowerStr
    if (StringMatch(lw, "deltak12_k") || StringMatch(lw, "deltak12_k_corr"))
        return 1
    endif
    if (StringMatch(lw, "sigmadeltak12_k") || StringMatch(lw, "sigmadeltak12_k_corr"))
        return 1
    endif

    // plotting helper waves generated by A2K1D in source folders, if any
    if (StringMatch(lw, "*_disp_p*_x") || StringMatch(lw, "*_disp_p*_y"))
        return 1
    endif
    if (StringMatch(lw, "*_hm_p*_x") || StringMatch(lw, "*_hm_p*_y") || StringMatch(lw, "*_hm_s*"))
        return 1
    endif
    if (StringMatch(lw, "*_layerheat_kspec*"))
        return 1
    endif

    return 0
End

Function a2k1d_cleanup_protected_df(dfPath)
    String dfPath

    String df = LowerStr(a2k1d_df_with_colon(dfPath))

    if (StringMatch(df, "root:arpes_ljz:a2k1d:"))
        return 1
    endif
    if (StringMatch(df, "root:arpes_ljz:a2k1d:*"))
        return 1
    endif
    if (StringMatch(df, "root:arpes_ljz:output:a2k1d:"))
        return 1
    endif
    if (StringMatch(df, "root:arpes_ljz:output:a2k1d:*"))
        return 1
    endif
    if (StringMatch(df, "root:arpes_ljz:mdctrack_runs:"))
        return 1
    endif
    if (StringMatch(df, "root:arpes_ljz:mdctrack_runs:*"))
        return 1
    endif

    return 0
End

Function/S a2k1d_cleanup_generated_in_df(dfPath, dryRun)
    String dfPath
    Variable dryRun

    String df = a2k1d_df_with_colon(dfPath)
    if (!DataFolderExists(df))
        return ""
    endif
    if (a2k1d_cleanup_protected_df(df))
        return ""
    endif

    String oldDF = GetDataFolder(1)
    SetDataFolder $df

    String list = WaveList("*", ";", "")
    String deletedList = ""
    Variable i, n
    n = ItemsInList(list, ";")

    for (i = 0; i < n; i += 1)
        String wn = StringFromList(i, list, ";")
        if (strlen(wn) == 0)
            continue
        endif

        if (a2k1d_is_generated_proc_wave_name(wn))
            deletedList += df + wn + ";"
            if (!dryRun)
                KillWaves/Z $wn
            endif
        endif
    endfor

    SetDataFolder oldDF
    return deletedList
End

Function/S a2k1d_cleanup_generated_recursive(dfPath, dryRun)
    String dfPath
    Variable dryRun

    String df = a2k1d_df_with_colon(dfPath)
    if (!DataFolderExists(df))
        return ""
    endif
    if (a2k1d_cleanup_protected_df(df))
        return ""
    endif

    String oldDF = GetDataFolder(1)
    String out = ""

    out += a2k1d_cleanup_generated_in_df(df, dryRun)

    SetDataFolder $df
    String subList = a2k1d_norm_list(DataFolderDir(2))
    SetDataFolder oldDF

    Variable i, n
    n = ItemsInList(subList, ";")
    for (i = 0; i < n; i += 1)
        String sub = StringFromList(i, subList, ";")
        if (strlen(sub) == 0)
            continue
        endif
        out += a2k1d_cleanup_generated_recursive(df + sub + ":", dryRun)
    endfor

    return out
End

Function/S a2k1d_list_output_temp_waves()
    Print "a2k1d_list_output_temp_waves is deprecated. Use a2k1d_cleanup_output_temp_for_group(groupTag, dryRun)."
    return ""
End

Function/S a2k1d_cleanup_output_temp_for_group(groupTag, dryRun)
    String groupTag
    Variable dryRun

    String outDF = "root:ARPES_LJZ:OUTPUT:A2K1D:"
    if (!DataFolderExists(outDF))
        return ""
    endif

    groupTag = CleanupName(groupTag, 0)
    if (strlen(groupTag) == 0)
        Print "A2K1D cleanup output temp: empty groupTag; skip."
        return ""
    endif

    String oldDF = GetDataFolder(1)
    SetDataFolder $outDF

    String list = WaveList("*", ";", "")
    String outList = ""

    Variable i, n
    String wn, lw
    String prefix = LowerStr(groupTag + "_")

    n = ItemsInList(list, ";")
    for (i = 0; i < n; i += 1)
        wn = StringFromList(i, list, ";")
        if (strlen(wn) == 0)
            continue
        endif

        lw = LowerStr(wn)

        // Only this group, e.g. p3d5mW_*.
        // Do NOT clean p1mW_*, p2mW_*, p4mW_*.
        // Do NOT clean generic a2k1d_* temporary waves here.
        if (StringMatch(lw, prefix + "*"))
            outList += outDF + wn + ";"
            if (!dryRun)
                KillWaves/Z $wn
            endif
        endif
    endfor

    SetDataFolder oldDF

    if (dryRun)
        if (ItemsInList(outList, ";") > 0)
            Print "DryRun: A2K1D plotting candidates for group '" + groupTag + "':"
            for (i = 0; i < ItemsInList(outList, ";"); i += 1)
                Print "  " + StringFromList(i, outList, ";")
            endfor
        else
            Print "DryRun: no A2K1D plotting waves found for group '" + groupTag + "' under " + outDF
        endif
    endif

    return outList
End

Function a2k1d_preview_cleanup_candidates(base, recursive)
    String base
    Variable recursive

    String candidates = ""

    if (recursive)
        candidates = a2k1d_cleanup_generated_recursive(base, 1)
    else
        candidates = a2k1d_cleanup_generated_in_df(base, 1)
    endif

    SVAR/Z baseName = root:ARPES_LJZ:A2K1D:a2k1d_baseName
    if (SVAR_Exists(baseName) && strlen(baseName) > 0)
        candidates += a2k1d_cleanup_output_temp_for_group(baseName, 1)
    else
        Print "A2K1D Cleanup preview: baseName is empty; skip OUTPUT:A2K1D group cleanup."
    endif

    Variable n = ItemsInList(candidates, ";")
    if (n <= 0)
        Print "A2K1D Cleanup candidates: none under " + base
        return 0
    endif

    Print "A2K1D Cleanup candidates:"
    Variable i
    for (i = 0; i < n; i += 1)
        Print "  " + StringFromList(i, candidates, ";")
    endfor

    return n
End

Function a2k1d_is_result_wave_name(wn)
    String wn
    String lw = LowerStr(wn)

    // Result waves must not be offered as angle/value inputs.
    // Keep corrected angle-domain inputs (Peak1K_corr, Sigmap1K_corr,
    // layer_show_i_corr) allowed, but exclude every final k-domain output.
    if (StringMatch(lw, "*_k_spec_corr"))
        return 1
    endif
    if (StringMatch(lw, "*_k_spec"))
        return 1
    endif
    if (StringMatch(lw, "deltak*_k_corr"))
        return 1
    endif
    if (StringMatch(lw, "sigmadeltak*_k_corr"))
        return 1
    endif
    if (StringMatch(lw, "deltak*_k"))
        return 1
    endif
    if (StringMatch(lw, "sigmadeltak*_k"))
        return 1
    endif
    if (StringMatch(lw, "*_k_corr"))
        return 1
    endif
    if (StringMatch(lw, "*_k"))
        return 1
    endif
    return 0
End


Function/S a2k1d_value_k_output_name(baseName)
    String baseName

    String outName = baseName
    Variable n = strlen(outName)
    if (n >= 5 && StringMatch(LowerStr(outName[n-5, n-1]), "_corr"))
        outName = outName[0, n-6] + "_k_corr"
    else
        outName += "_k"
    endif

    return CleanupName(outName, 0)
End

Function/S a2k1d_spec_k_output_name(baseName)
    String baseName

    String outName = baseName
    Variable n = strlen(outName)
    if (n >= 5 && StringMatch(LowerStr(outName[n-5, n-1]), "_corr"))
        outName = outName[0, n-6] + "_k_spec_corr"
    else
        outName += "_k_spec"
    endif

    return CleanupName(outName, 0)
End

Function LJZ_A2K1D_Run(srcPathStr, baseName, pixel, thetaAngle, hv, workFunc, energyRel, mdcKf, latticeA, outN)
    String srcPathStr
    String baseName
    Variable pixel, thetaAngle, hv, workFunc, energyRel, mdcKf, latticeA, outN

    Wave/Z src = $srcPathStr
    if (!WaveExists(src))
        DoAlert 0, "A2K1D: src wave not found."
        return -1
    endif

    if (WaveType(src) == 0)
        Printf "A2K1D: Skipping '%s' (TEXT wave).\r", NameOfWave(src)
        return -1
    endif
    if (WaveDims(src) != 1)
        Printf "A2K1D: Skipping '%s' (not 1D, dims=%g).\r", NameOfWave(src), WaveDims(src)
        return -1
    endif
    if (DimSize(src, 0) <= 1)
        Printf "A2K1D: Skipping '%s' (insufficient points, N=%g).\r", NameOfWave(src), DimSize(src,0)
        return -1
    endif

    Variable ekin = a2k1d_EKin(hv, workFunc, energyRel)
    if (numtype(ekin) != 0 || ekin <= 0)
        DoAlert 0, "A2K1D: EKin = hv - WorkFunc + EnergyRel must be > 0."
        return -1
    endif

    String df0 = GetDataFolder(1)
    String outDF = GetWavesDataFolder(src, 1)
    if (strlen(outDF) == 0)
        outDF = "root:"
    endif
    SetDataFolder $outDF

    String destName = a2k1d_value_k_output_name(baseName)
    Duplicate/O src, $destName
    Wave dest = $destName

    dest = a2k1d_AngleToK_Unified(a2k1d_RawValueToAngle(src, pixel), hv, workFunc, energyRel, thetaAngle, mdcKf, latticeA)

    if (latticeA == 0)
        SetScale d, 0, 0, "Å\\S-1", dest
    else
        SetScale d, 0, 0, "pi/a", dest
    endif

    Variable scale = (pixel == 0) ? 1 : pixel
    Note/K dest
    String noteStr = ""
    noteStr += "A2K1D Value Transform (LJZ unified geometry)\r"
    noteStr += "srcPath=" + srcPathStr + "\r"
    noteStr += "Pixel=" + num2str(pixel) + "\r"
    noteStr += "scale=" + num2str(scale) + "\r"
    noteStr += "ThetaAngle=" + num2str(thetaAngle) + "\r"
    noteStr += "hv=" + num2str(hv) + "\r"
    noteStr += "WorkFunc=" + num2str(workFunc) + "\r"
    noteStr += "EnergyRel=" + num2str(energyRel) + "\r"
    noteStr += "MDCKf=" + num2str(mdcKf) + "\r"
    noteStr += "LatticeA=" + num2str(latticeA) + "\r"
    noteStr += "EKin=" + num2str(ekin) + "\r"
    noteStr += "formulaVersion=A2K1D_unified_with_EKKMap_v1\r"
    Note dest, noteStr

    NVAR/Z showGraph = root:ARPES_LJZ:A2K1D:a2k1d_showGraph
    Variable doGraph = 1
    if (NVAR_Exists(showGraph))
        doGraph = showGraph
    endif

    if (doGraph)
        String gname = "A2K1D_Check_Value"
        DoWindow/K $gname
        Display/K=1/N=$gname dest
        ModifyGraph/W=$gname mode=0
    endif

    Printf "A2K1D Transformed: %s -> %s (EKin=%.2f)\r", NameOfWave(src), destName, ekin
    SetDataFolder df0
    return 0
End

Function LJZ_A2K1D_Run_Sigma(peakPathStr, sigmaPathStr, baseName, pixel, thetaAngle, hv, workFunc, energyRel, mdcKf, latticeA)
    String peakPathStr, sigmaPathStr
    String baseName
    Variable pixel, thetaAngle, hv, workFunc, energyRel, mdcKf, latticeA

    Wave/Z wPeak = $peakPathStr
    Wave/Z wSig  = $sigmaPathStr
    if (!WaveExists(wPeak) || !WaveExists(wSig))
        Printf "A2K1D Sigma: missing peak or sigma wave. peak=%s sigma=%s\r", peakPathStr, sigmaPathStr
        return -1
    endif

    if (WaveType(wPeak)==0 || WaveType(wSig)==0)
        Printf "A2K1D Sigma: peak/sigma must be numeric waves.\r"
        return -1
    endif
    if (WaveDims(wPeak)!=1 || WaveDims(wSig)!=1)
        Printf "A2K1D Sigma: peak/sigma must be 1D.\r"
        return -1
    endif
    if (DimSize(wPeak,0) != DimSize(wSig,0))
        Printf "A2K1D Sigma: size mismatch peak=%d sigma=%d\r", DimSize(wPeak,0), DimSize(wSig,0)
        return -1
    endif

    Variable ekin = a2k1d_EKin(hv, workFunc, energyRel)
    if (numtype(ekin)!=0 || ekin<=0)
        Printf "A2K1D Sigma: EKin must be >0.\r"
        return -1
    endif

    String df0 = GetDataFolder(1)
    String outDF = GetWavesDataFolder(wSig, 1)
    if (strlen(outDF)==0)
        outDF="root:"
    endif
    SetDataFolder $outDF

    String destName = a2k1d_value_k_output_name(baseName)
    Duplicate/O wSig, $destName
    Wave dest = $destName

    dest = a2k1d_SigmaAngleToK_Unified(a2k1d_RawValueToAngle(wPeak, pixel), wSig, pixel, hv, workFunc, energyRel, thetaAngle, latticeA)

    if (latticeA == 0)
        SetScale d, 0, 0, "Å\\S-1", dest
    else
        SetScale d, 0, 0, "pi/a", dest
    endif

    Variable scale = (pixel == 0) ? 1 : pixel
    Note/K dest
    String noteStr=""
    noteStr += "A2K1D Sigma Transform (LJZ unified geometry)\r"
    noteStr += "peak=" + peakPathStr + "\r"
    noteStr += "sigma=" + sigmaPathStr + "\r"
    noteStr += "Pixel=" + num2str(pixel) + "\r"
    noteStr += "scale=" + num2str(scale) + "\r"
    noteStr += "ThetaAngle=" + num2str(thetaAngle) + "\r"
    noteStr += "hv=" + num2str(hv) + "\r"
    noteStr += "WorkFunc=" + num2str(workFunc) + "\r"
    noteStr += "EnergyRel=" + num2str(energyRel) + "\r"
    noteStr += "MDCKf=" + num2str(mdcKf) + "\r"
    noteStr += "LatticeA=" + num2str(latticeA) + "\r"
    noteStr += "EKin=" + num2str(ekin) + "\r"
    noteStr += "formulaVersion=A2K1D_unified_with_EKKMap_v1\r"
    Note dest, noteStr

    SetDataFolder df0
    return 0
End

Static Function a2k1d_angle_to_k(rawValue, pixel, thetaAngle, hv, workFunc, energyRel, mdcKf, latticeA)
    Variable rawValue, pixel, thetaAngle, hv, workFunc, energyRel, mdcKf, latticeA
    return a2k1d_AngleToK_Unified(a2k1d_RawValueToAngle(rawValue, pixel), hv, workFunc, energyRel, thetaAngle, mdcKf, latticeA)
End

Static Function a2k1d_sigma_angle_to_k(rawValue, sigmaRaw, pixel, thetaAngle, hv, workFunc, energyRel, latticeA)
    Variable rawValue, sigmaRaw, pixel, thetaAngle, hv, workFunc, energyRel, latticeA
    return a2k1d_SigmaAngleToK_Unified(a2k1d_RawValueToAngle(rawValue, pixel), sigmaRaw, pixel, hv, workFunc, energyRel, thetaAngle, latticeA)
End

Function LJZ_A2K1D_TransformLongTable(fitHPDF)
    String fitHPDF

    String fdf = a2k1d_df_with_colon(fitHPDF)
    if (!a2k1d_df_exists(fdf))
        DoAlert 0, "A2K1D LongTable: fitHP data folder not found."
        return -1
    endif

    Wave/Z wAngle = $(fdf + "Long_PeakAngle")
    if (!WaveExists(wAngle))
        DoAlert 0, "A2K1D LongTable: Long_PeakAngle is required."
        return -1
    endif

    Variable nRows = DimSize(wAngle, 0)
    Wave/Z wK0 = $(fdf + "Long_PeakK")
    if (!WaveExists(wK0))
        Make/O/N=(nRows) $(fdf + "Long_PeakK") = NaN
    endif
    Wave wK = $(fdf + "Long_PeakK")

    Wave/Z wSigmaK0 = $(fdf + "Long_SigmaK")
    if (!WaveExists(wSigmaK0))
        Make/O/N=(nRows) $(fdf + "Long_SigmaK") = NaN
    endif
    Wave wSigmaK = $(fdf + "Long_SigmaK")

    Wave/Z wSigmaAngle = $(fdf + "Long_SigmaAngle")
    Variable hasSigmaAngle = WaveExists(wSigmaAngle)

    a2k1d_sync_unified_from_legacy_if_missing()
    NVAR/Z Pixel = root:ARPES_LJZ:A2K1D:Pixel
    NVAR/Z ThetaAngle = root:ARPES_LJZ:A2K1D:ThetaAngle
    NVAR/Z hv = root:ARPES_LJZ:A2K1D:hv
    NVAR/Z WorkFunc = root:ARPES_LJZ:A2K1D:WorkFunc
    NVAR/Z EnergyRel = root:ARPES_LJZ:A2K1D:EnergyRel
    NVAR/Z MDCKf = root:ARPES_LJZ:A2K1D:MDCKf
    NVAR/Z LatticeA = root:ARPES_LJZ:A2K1D:LatticeA

    if (!NVAR_Exists(Pixel) || !NVAR_Exists(ThetaAngle) || !NVAR_Exists(hv) || !NVAR_Exists(WorkFunc) || !NVAR_Exists(EnergyRel) || !NVAR_Exists(MDCKf) || !NVAR_Exists(LatticeA))
        DoAlert 0, "A2K1D LongTable: required unified geometry parameters are missing."
        return -1
    endif

    Variable EKin = a2k1d_EKin(hv, WorkFunc, EnergyRel)
    if (numtype(EKin) != 0 || EKin <= 0)
        DoAlert 0, "A2K1D LongTable: EKin = hv - WorkFunc + EnergyRel must be > 0."
        return -1
    endif

    Variable i, angleV, kV, sigmaV
    Variable converted = 0
    Variable skipped = 0
    Variable failed = 0
    Variable scale = (Pixel == 0) ? 1 : Pixel

    for (i = 0; i < nRows; i += 1)
        angleV = wAngle[i]
        if (numtype(angleV) != 0)
            wK[i] = NaN
            wSigmaK[i] = NaN
            skipped += 1
            continue
        endif

        kV = a2k1d_angle_to_k(angleV, Pixel, ThetaAngle, hv, WorkFunc, EnergyRel, MDCKf, LatticeA)
        if (numtype(kV) != 0)
            wK[i] = NaN
            wSigmaK[i] = NaN
            failed += 1
            continue
        endif

        wK[i] = kV
        converted += 1

        if (hasSigmaAngle)
            sigmaV = a2k1d_sigma_angle_to_k(angleV, wSigmaAngle[i], Pixel, ThetaAngle, hv, WorkFunc, EnergyRel, LatticeA)
            wSigmaK[i] = sigmaV
        else
            wSigmaK[i] = NaN
        endif
    endfor

    Note/K wK
    String noteK = ""
    noteK += "A2K1D LongTable PeakAngle->PeakK\r"
    noteK += "Pixel=" + num2str(Pixel) + "\r"
    noteK += "scale=" + num2str(scale) + "\r"
    noteK += "ThetaAngle=" + num2str(ThetaAngle) + "\r"
    noteK += "hv=" + num2str(hv) + "\r"
    noteK += "WorkFunc=" + num2str(WorkFunc) + "\r"
    noteK += "EnergyRel=" + num2str(EnergyRel) + "\r"
    noteK += "MDCKf=" + num2str(MDCKf) + "\r"
    noteK += "LatticeA=" + num2str(LatticeA) + "\r"
    noteK += "EKin=" + num2str(EKin) + "\r"
    noteK += "formulaVersion=A2K1D_unified_with_EKKMap_v1\r"
    Note wK, noteK

    Note/K wSigmaK
    String noteSigma = ""
    noteSigma += "A2K1D LongTable SigmaAngle->SigmaK\r"
    noteSigma += "Pixel=" + num2str(Pixel) + "\r"
    noteSigma += "scale=" + num2str(scale) + "\r"
    noteSigma += "ThetaAngle=" + num2str(ThetaAngle) + "\r"
    noteSigma += "hv=" + num2str(hv) + "\r"
    noteSigma += "WorkFunc=" + num2str(WorkFunc) + "\r"
    noteSigma += "EnergyRel=" + num2str(EnergyRel) + "\r"
    noteSigma += "MDCKf=" + num2str(MDCKf) + "\r"
    noteSigma += "LatticeA=" + num2str(LatticeA) + "\r"
    noteSigma += "EKin=" + num2str(EKin) + "\r"
    noteSigma += "formulaVersion=A2K1D_unified_with_EKKMap_v1\r"
    Note wSigmaK, noteSigma

    Variable syncRc = LJZ_A2K1D_SyncAllTableFromLong(fdf)
    Printf "A2K1D LongTable: converted=%d skipped=%d failed=%d syncRc=%d (DF=%s)\r", converted, skipped, failed, syncRc, fdf
    DoAlert 0, "A2K1D LongTable done. converted=" + num2str(converted) + ", skipped=" + num2str(skipped) + ", failed=" + num2str(failed)
    return 0
End

Function LJZ_A2K1D_SyncAllTableFromLong(fdf)
    String fdf

    String df = a2k1d_df_with_colon(fdf)
    Wave/Z wRow = $(df + "Long_MDCRow")
    Wave/Z wRank = $(df + "Long_PeakRank")
    Wave/Z wK = $(df + "Long_PeakK")
    Wave/Z wSigmaK = $(df + "Long_SigmaK")
    Wave/Z wPeakAll = $(df + "PeakK_All")
    Wave/Z wSigmaAll = $(df + "SigmaK_All")

    if (!WaveExists(wPeakAll))
        return -1
    endif
    if (!WaveExists(wRow) || !WaveExists(wRank) || !WaveExists(wK))
        return -1
    endif

    wPeakAll = NaN
    if (WaveExists(wSigmaAll))
        wSigmaAll = NaN
    endif

    Variable nRows = DimSize(wRow, 0)
    Variable i, rr, cc
    for (i = 0; i < nRows; i += 1)
        if (numtype(wRow[i]) != 0 || numtype(wRank[i]) != 0)
            continue
        endif
        rr = trunc(wRow[i])
        cc = trunc(wRank[i]) - 1
        if (rr < 0 || cc < 0)
            continue
        endif
        if (rr >= DimSize(wPeakAll, 0) || cc >= DimSize(wPeakAll, 1))
            continue
        endif
        wPeakAll[rr][cc] = wK[i]
        if (WaveExists(wSigmaAll) && WaveExists(wSigmaK))
            if (i < DimSize(wSigmaK, 0))
                wSigmaAll[rr][cc] = wSigmaK[i]
            endif
        endif
    endfor

    return 0
End

//============================================================
// Delta-k transform
// Given: peak1k_k and peak2k_k
// Output: deltak12_k = abs(peak1k_k - peak2k_k)
// Saved in the SAME folder as the input peak waves
//============================================================
Function LJZ_A2K1D_MakeDeltaK(peak1KPathStr, peak2KPathStr, baseName)
    String peak1KPathStr, peak2KPathStr
    String baseName

    Wave/Z wP1 = $peak1KPathStr
    Wave/Z wP2 = $peak2KPathStr

    if (!WaveExists(wP1) || !WaveExists(wP2))
        Printf "A2K1D DeltaK: missing peak waves. p1=%s p2=%s\r", peak1KPathStr, peak2KPathStr
        return -1
    endif

    if (WaveType(wP1)==0 || WaveType(wP2)==0)
        Printf "A2K1D DeltaK: peak waves must be numeric.\r"
        return -1
    endif

    if (WaveDims(wP1)!=1 || WaveDims(wP2)!=1)
        Printf "A2K1D DeltaK: peak waves must be 1D.\r"
        return -1
    endif

    if (DimSize(wP1,0) != DimSize(wP2,0))
        Printf "A2K1D DeltaK: size mismatch p1=%d p2=%d\r", DimSize(wP1,0), DimSize(wP2,0)
        return -1
    endif

    String df0 = GetDataFolder(1)
    String outDF = GetWavesDataFolder(wP1, 1)
    if (strlen(outDF)==0)
        outDF = "root:"
    endif
    SetDataFolder $outDF

    String destName = baseName + "_k"
    Duplicate/O wP1, $destName
    Wave dest = $destName

    dest = abs(wP1 - wP2)

    // 保持与 peak wave 相同的 x 轴和数据单位
    SetScale/P x, DimOffset(wP1,0), DimDelta(wP1,0), WaveUnits(wP1,0), dest
    SetScale d, 0, 0, WaveUnits(wP1,-1), dest

    Note/K dest
    String noteStr=""
    noteStr += "A2K1D DeltaK (LJZ)\r"
    noteStr += "peak1=" + peak1KPathStr + "\r"
    noteStr += "peak2=" + peak2KPathStr + "\r"
    noteStr += "formula=abs(peak1k_k-peak2k_k)\r"
    Note dest, noteStr

    SetDataFolder df0
    return 0
End
//============================================================
// NEW: Spectra Transform (Interpolation Mode)
// Input: Wave where X = Angle, Y = Intensity
// Output: Wave where X = k (Linear), Y = Intensity (Interpolated)
//============================================================
Function LJZ_Spectra_Interp_Run(srcPathStr, baseName, thetaAngle, hv, workFunc, energyRel, mdcKf, latticeA)
    String srcPathStr, baseName
    Variable thetaAngle, hv, workFunc, energyRel, mdcKf, latticeA

    Wave/Z src = $srcPathStr
    if (!WaveExists(src))
        DoAlert 0, "A2K1D: src wave not found: " + srcPathStr
        return -1
    endif

    if (WaveType(src) == 0)
        Printf "Skipping '%s': It is a TEXT wave.\r", NameOfWave(src)
        return -1
    endif
    if (WaveDims(src) != 1)
        Printf "Skipping '%s': It is not a 1D wave (Dims=%g).\r", NameOfWave(src), WaveDims(src)
        return -1
    endif
    if (DimSize(src, 0) <= 1)
        Printf "Skipping '%s': Wave has insufficient points (N=%g).\r", NameOfWave(src), DimSize(src, 0)
        return -1
    endif

    Variable EKin = a2k1d_EKin(hv, workFunc, energyRel)
    if (numtype(EKin) != 0 || EKin <= 0)
        Printf "Error for '%s': EKin (%.2f) must be > 0. Check hv, WorkFunc, EnergyRel.\r", NameOfWave(src), EKin
        return -1
    endif

    String df0 = GetDataFolder(1)
    String outDF = GetWavesDataFolder(src, 1)
    if (strlen(outDF) == 0)
        outDF = "root:" 
    endif
    SetDataFolder $outDF

    String unitStr = "A\\S-1"
    if (latticeA != 0)
        unitStr = "pi/a"
    endif

    Variable thetaMin = LeftX(src)
    Variable thetaMax = RightX(src)
    Variable k_start = a2k1d_AngleToK_Unified(thetaMin, hv, workFunc, energyRel, thetaAngle, mdcKf, latticeA)
    Variable k_end   = a2k1d_AngleToK_Unified(thetaMax, hv, workFunc, energyRel, thetaAngle, mdcKf, latticeA)
 
    if (numtype(k_start) != 0 || numtype(k_end) != 0 || abs(k_start - k_end) < 1e-9)
        SetDataFolder df0
        Printf "Error for '%s': Calculated k-range is invalid or near zero. Check input scaling.\r", NameOfWave(src)
        return -1
    endif

    String destName = a2k1d_spec_k_output_name(baseName)
    Duplicate/O src, $destName
    Wave dest = $destName

    Variable kLo = min(k_start, k_end)
    Variable kHi = max(k_start, k_end)
    SetScale/I x, kLo, kHi, unitStr, dest

    Variable angLo = min(LeftX(src), RightX(src))
    Variable angHi = max(LeftX(src), RightX(src))
    dest = src(a2k1d_clamp(a2k1d_KToAngle_Unified(x, hv, workFunc, energyRel, thetaAngle, mdcKf, latticeA), angLo, angHi))

    SetScale d, 0, 0, WaveUnits(src, -1), dest 

    Note/K dest
    String noteStr = ""
    noteStr += "A2K1D Spectra Interpolation (LJZ unified geometry)\r"
    noteStr += "Method: Linear k-grid generation -> Inverse Angle Mapping -> Interpolation\r"
    noteStr += "Source=" + srcPathStr + "\r"
    noteStr += "ThetaAngle=" + num2str(thetaAngle) + "\r"
    noteStr += "hv=" + num2str(hv) + "\r"
    noteStr += "WorkFunc=" + num2str(workFunc) + "\r"
    noteStr += "EnergyRel=" + num2str(energyRel) + "\r"
    noteStr += "MDCKf=" + num2str(mdcKf) + "\r"
    noteStr += "LatticeA=" + num2str(latticeA) + "\r"
    noteStr += "EKin=" + num2str(EKin) + "\r"
    noteStr += "k_range=" + num2str(kLo) + " to " + num2str(kHi) + "\r"
    noteStr += "formulaVersion=A2K1D_unified_with_EKKMap_v1\r"
    Note dest, noteStr

    NVAR/Z showGraph = root:ARPES_LJZ:A2K1D:a2k1d_showGraph
    Variable doGraph = 1
    if (NVAR_Exists(showGraph))
        doGraph = showGraph
    endif

    if (doGraph)
        String gname = "A2K1D_Check_Spec"
        DoWindow/K $gname
        Display/K=1/N=$gname dest
        ModifyGraph/W=$gname mode=0
    endif

    Printf "A2K1D Spectra: %s converted to k-space.\r", destName

    SetDataFolder df0
    return 0
End

//============================================================
// Helpers: name parsing & collectors
//============================================================
Function/S a2k1d_tail_wavename(fullPath)
    String fullPath
    Variable n = ItemsInList(fullPath, ":")
    if (n <= 0)
        return fullPath
    endif
    return StringFromList(n-1, fullPath, ":")
End

Function a2k1d_is_peak_name(wn)
    String wn
    String lw = LowerStr(wn)

    // Raw angle-domain peak waves
    if (StringMatch(lw, "peak1k") || StringMatch(lw, "peak2k") || StringMatch(lw, "peak3k"))
        return 1
    endif

    // Corrected angle-domain peak waves
    // These are still angle-domain inputs, not final k outputs.
    if (StringMatch(lw, "peak1k_corr") || StringMatch(lw, "peak2k_corr") || StringMatch(lw, "peak3k_corr"))
        return 1
    endif

    return 0
End

Function a2k1d_is_sigmap_name(wn)
    String wn
    String lw = LowerStr(wn)

    // Raw angle-domain sigma waves
    if (StringMatch(lw, "sigmap1k") || StringMatch(lw, "sigmap2k") || StringMatch(lw, "sigmap3k"))
        return 1
    endif

    // Corrected angle-domain sigma waves
    // These are still angle-domain inputs, not final k outputs.
    if (StringMatch(lw, "sigmap1k_corr") || StringMatch(lw, "sigmap2k_corr") || StringMatch(lw, "sigmap3k_corr"))
        return 1
    endif

    return 0
End

Function a2k1d_is_peak_sigma_name(wn)
    String wn

    if (a2k1d_is_peak_name(wn))
        return 1
    endif

    if (a2k1d_is_sigmap_name(wn))
        return 1
    endif

    return 0
End

Function/S a2k1d_collect_layers(baseDF, recursive)
    String baseDF
    Variable recursive

    String base = a2k1d_df_with_colon(baseDF)
    if (!a2k1d_df_exists(base))
        return ""
    endif

    String out = ""
    String listAll = ""
    Variable i, n

    if (recursive)
        listAll = a2k1d_collect_1d_waves_recursive(base)
        n = ItemsInList(listAll, ";")
        for (i=0; i<n; i+=1)
            String wp = StringFromList(i, listAll, ";")
            if (strlen(wp) == 0) 
            continue
            endif
            String wn = a2k1d_tail_wavename(wp)
            if (a2k1d_is_layer_int_name(wn))
                out += wp + ";"
            endif
        endfor
    else
        String df0 = GetDataFolder(1)
        SetDataFolder $base
        // Collect all 1D waves, then let the strict parser accept modern/legacy raw layer names.
        listAll = WaveList("*", ";", "DIMS:1")
        SetDataFolder df0

        n = ItemsInList(listAll, ";")
        for (i=0; i<n; i+=1)
            String wn2 = StringFromList(i, listAll, ";")
            if (strlen(wn2) == 0) 
            continue
            endif
            // 调用上面修改过的严格判定函数
            if (a2k1d_is_layer_int_name(wn2))
                out += base + wn2 + ";"
            endif
        endfor
    endif

    return out
End


Function/S a2k1d_collect_peak_sigma(baseDF, recursive)
    String baseDF
    Variable recursive

    String base = a2k1d_df_with_colon(baseDF)
    if (!a2k1d_df_exists(base))
        return ""
    endif

    String out = ""
    String listAll
    Variable i, n

    if (recursive)
        listAll = a2k1d_collect_1d_waves_recursive(base)   // full paths
    else
        // non-recursive: build full paths from names
        String df0 = GetDataFolder(1)
        SetDataFolder $base
        listAll = WaveList("*", ";", "DIMS:1")
        SetDataFolder df0

        // convert to full paths
        String tmp = ""
        n = ItemsInList(listAll, ";")
        for (i=0; i<n; i+=1)
            String wn0 = StringFromList(i, listAll, ";")
            if (strlen(wn0) == 0)
                continue
            endif
            tmp += base + wn0 + ";"
        endfor
        listAll = tmp
    endif

    n = ItemsInList(listAll, ";")
    for (i=0; i<n; i+=1)
        String wp = StringFromList(i, listAll, ";")
        if (strlen(wp) == 0)
            continue
        endif
        String wn = a2k1d_tail_wavename(wp)
        if (a2k1d_is_result_wave_name(wn))
            continue
        endif
        if (a2k1d_is_peak_sigma_name(wn))
            out += wp + ";"
        endif
    endfor

    return out
End


Function a2k1d_same_wave_path(pathA, pathB)
    String pathA, pathB
    return cmpstr(LowerStr(pathA), LowerStr(pathB)) == 0
End

Function a2k1d_string_all_digits(s)
    String s

    if (strlen(s) <= 0)
        return 0
    endif
    if (StringMatch(s, "*[!0-9]*"))
        return 0
    endif
    return 1
End

Function/S a2k1d_strip_corr_suffix_for_layer_name(lw)
    String lw

    Variable n = strlen(lw)
    if (n >= 5 && StringMatch(lw[n-5,n-1], "_corr"))
        return lw[0,n-6]
    endif
    if (n >= 4 && StringMatch(lw[n-4,n-1], "corr"))
        return lw[0,n-5]
    endif
    return lw
End

Function a2k1d_layer_name_has_corr_suffix(wn)
    String wn
    String lw = LowerStr(wn)
    return StringMatch(lw, "*_corr") || StringMatch(lw, "*corr")
End

Function a2k1d_layer_name_has_k_output_suffix(wn)
    String wn
    String lw = LowerStr(wn)

    if (StringMatch(lw, "*_k") || StringMatch(lw, "*_k_corr"))
        return 1
    endif
    if (StringMatch(lw, "*_k_spec") || StringMatch(lw, "*_k_spec_corr"))
        return 1
    endif
    return 0
End

Function a2k1d_get_layer_index_safe(wn)
    String wn

    String lw = LowerStr(wn)
    if (a2k1d_layer_name_has_k_output_suffix(lw))
        return -1
    endif

    lw = a2k1d_strip_corr_suffix_for_layer_name(lw)

    String rest = ""
    if (StringMatch(lw, "layer_show_*"))
        if (strlen(lw) <= 11)
            return -1
        endif
        rest = lw[11, strlen(lw)-1]
    elseif (StringMatch(lw, "layer_show*"))
        if (strlen(lw) <= 10)
            return -1
        endif
        rest = lw[10, strlen(lw)-1]
    elseif (StringMatch(lw, "layershow*"))
        if (strlen(lw) <= 9)
            return -1
        endif
        rest = lw[9, strlen(lw)-1]
    else
        return -1
    endif

    if (!a2k1d_string_all_digits(rest))
        return -1
    endif

    return str2num(rest)
End

Function a2k1d_is_layer_int_name(wn)
    String wn

    if (a2k1d_layer_name_has_k_output_suffix(wn))
        return 0
    endif
    if (a2k1d_layer_name_has_corr_suffix(wn))
        return 0
    endif
    return a2k1d_get_layer_index_safe(wn) >= 0
End

Function a2k1d_is_layer_corr_name(wn)
    String wn

    if (a2k1d_layer_name_has_k_output_suffix(wn))
        return 0
    endif
    if (!a2k1d_layer_name_has_corr_suffix(wn))
        return 0
    endif
    return a2k1d_get_layer_index_safe(wn) >= 0
End

Function a2k1d_test_layer_name_parser()
    String names = "layer_show_0;layer_show_12;layer_show_0_corr;layer_show0corr;layershow0;layer_show_0_k_spec;layer_show_0_k_spec_corr;Peak1K_k;"
    Variable i, n = ItemsInList(names, ";")
    for (i=0; i<n; i+=1)
        String wn = StringFromList(i, names, ";")
        Printf "A2K1D parser test: %s -> idx=%d raw=%d corr=%d kOutput=%d\r", wn, a2k1d_get_layer_index_safe(wn), a2k1d_is_layer_int_name(wn), a2k1d_is_layer_corr_name(wn), a2k1d_layer_name_has_k_output_suffix(wn)
    endfor
    return 0
End

Function/S a2k1d_strip_suffix_once(s, suf)
    String s, suf
    Variable ls = strlen(s)
    Variable lf = strlen(suf)
    if (ls >= lf && StringMatch(s[ls-lf, ls-1], suf))
        return s[0, ls-lf-1]
    endif
    return s
End

Function/S a2k1d_clean_basename(wn)
    String wn
    String out = wn
    // 你现在会生成两类输出：_k_spec（谱插值）和 _k（value trans）
    // 这里按顺序剥一次，避免无限叠加
    out = a2k1d_strip_suffix_once(out, "_k_spec_corr")
    out = a2k1d_strip_suffix_once(out, "_k_corr")
    out = a2k1d_strip_suffix_once(out, "_k_spec")
    out = a2k1d_strip_suffix_once(out, "_k")
    return out
End

//============================================================
// Layer index helper
//============================================================
Function a2k1d_get_layer_index(wn)
    String wn
    return a2k1d_get_layer_index_safe(wn)
End

Function/S a2k1d_corr_df_with_colon(runDF)
    String runDF
    return a2k1d_df_with_colon(runDF)
End

Function a2k1d_corr_run_is_valid(runDF)
    String runDF

    String df = a2k1d_df_with_colon(runDF)
    if (!DataFolderExists(df))
        return 0
    endif

    Wave/Z dK = $(df + "dK_toRef")
    Wave/Z sc = $(df + "scale_toRef")

    if (!WaveExists(dK) || !WaveExists(sc))
        return 0
    endif
    if (DimSize(dK,0) <= 0 || DimSize(sc,0) <= 0)
        return 0
    endif

    return 1
End

Function a2k1d_corr_nrows(runDF)
    String runDF
    String df = a2k1d_df_with_colon(runDF)
    Wave/Z dK = $(df + "dK_toRef")
    Wave/Z sc = $(df + "scale_toRef")
    if (!WaveExists(dK) || !WaveExists(sc))
        return 0
    endif
    return min(DimSize(dK,0), DimSize(sc,0))
End

Function a2k1d_corr_row_for_layer(layer, nTrack)
    Variable layer, nTrack

    if (nTrack <= 1)
        return 0
    endif

    return round(layer)
End

Function a2k1d_corr_mean_finite(w)
    Wave w

    Variable i, n, v, sum, cnt
    n = DimSize(w,0)
    sum = 0
    cnt = 0

    for (i=0; i<n; i+=1)
        v = w[i]
        if (numtype(v) == 0)
            sum += v
            cnt += 1
        endif
    endfor

    if (cnt <= 0)
        return NaN
    endif

    return sum / cnt
End

Function a2k1d_get_theta_center_from_corr_run(runDF)
    String runDF

    String df = a2k1d_df_with_colon(runDF)

    NVAR/Z kcRun = $(df + "KCenter")
    if (NVAR_Exists(kcRun))
        if (numtype(kcRun) == 0)
            return kcRun
        endif
    endif

    NVAR/Z kcGlobal = root:ARPES_LJZ:MDCTrack:KCenter
    if (NVAR_Exists(kcGlobal))
        if (numtype(kcGlobal) == 0)
            return kcGlobal
        endif
    endif

    return 0
End

Function a2k1d_get_effective_corr(runDF, row, corrMode, skipFlagged, dThetaOut, scaleOut)
    String runDF
    Variable row, corrMode, skipFlagged
    Variable &dThetaOut, &scaleOut

    String df = a2k1d_df_with_colon(runDF)

    Wave/Z dK = $(df + "dK_toRef")
    Wave/Z sc = $(df + "scale_toRef")
    Wave/Z flag = $(df + "flag")

    dThetaOut = NaN
    scaleOut = NaN

    if (!WaveExists(dK) || !WaveExists(sc))
        return -1
    endif

    Variable nTrack = min(DimSize(dK,0), DimSize(sc,0))
    if (row < 0 || row >= nTrack)
        return -2
    endif

    if (skipFlagged != 0 && WaveExists(flag))
        if (row < DimSize(flag,0))
            if (numtype(flag[row]) == 0 && flag[row] != 0)
                return -3
            endif
        endif
    endif

    Variable d0, s0, meanD, meanS

    if (numtype(dK[row]) != 0 || numtype(sc[row]) != 0 || sc[row] <= 0)
        return -4
    endif

    if (corrMode == 1)
        d0 = dK[0]
        s0 = sc[0]

        if (numtype(d0) == 0)
            dThetaOut = dK[row] - d0
        else
            dThetaOut = dK[row]
        endif

        if (numtype(s0) == 0 && s0 > 0)
            scaleOut = sc[row] / s0
        else
            scaleOut = sc[row]
        endif

    elseif (corrMode == 2)
        meanD = a2k1d_corr_mean_finite(dK)
        meanS = a2k1d_corr_mean_finite(sc)

        if (numtype(meanD) == 0)
            dThetaOut = dK[row] - meanD
        else
            dThetaOut = dK[row]
        endif

        if (numtype(meanS) == 0 && meanS > 0)
            scaleOut = sc[row] / meanS
        else
            scaleOut = sc[row]
        endif

    else
        dThetaOut = dK[row]
        scaleOut = sc[row]
    endif

    if (numtype(dThetaOut) != 0 || numtype(scaleOut) != 0 || scaleOut <= 0)
        return -5
    endif

    return 0
End

Function/S a2k1d_make_corr_angle_name(rawName)
    String rawName

    String wn = rawName
    String lower = LowerStr(wn)

    if (StringMatch(lower, "*_corr"))
        return wn
    endif

    return CleanupName(wn + "_corr", 0)
End

Function/S a2k1d_make_corr_peak_angle_wave(peakPath, runDF)
    String peakPath, runDF

    Wave/Z src = $peakPath
    if (!WaveExists(src))
        Print "AngleCorr peak: source missing: " + peakPath
        return ""
    endif

    if (WaveType(src) == 0 || WaveDims(src) != 1)
        Print "AngleCorr peak: source must be numeric 1D: " + peakPath
        return ""
    endif

    if (!a2k1d_corr_run_is_valid(runDF))
        Print "AngleCorr peak: invalid correction run: " + runDF
        return ""
    endif

    String df0 = GetDataFolder(1)
    String outDF = GetWavesDataFolder(src, 1)
    if (strlen(outDF) == 0)
        outDF = "root:"
    endif

    String outName = a2k1d_make_corr_angle_name(NameOfWave(src))
    String outPath = outDF + outName
    String srcPath = outDF + NameOfWave(src)

    if (a2k1d_same_wave_path(srcPath, outPath))
        Print "AngleCorr peak: source already appears corrected; keeping existing wave: " + srcPath
        SetDataFolder df0
        return srcPath
    endif

    Duplicate/O src, $outPath
    Wave out = $outPath

    String cdf = a2k1d_df_with_colon(runDF)
    Variable nTrack = a2k1d_corr_nrows(cdf)
    Variable thetaCenter = a2k1d_get_theta_center_from_corr_run(cdf)

    NVAR corrMode = root:ARPES_LJZ:A2K1D:a2k1d_corrMode
    NVAR skipFlagged = root:ARPES_LJZ:A2K1D:a2k1d_corrSkipFlagged

    Variable i, row, rc, dTh, scEff, raw
    for (i=0; i<DimSize(src,0); i+=1)
        row = a2k1d_corr_row_for_layer(i, nTrack)
        if (row < 0 || row >= nTrack)
            out[i] = NaN
            continue
        endif
        rc = a2k1d_get_effective_corr(cdf, row, corrMode, skipFlagged, dTh, scEff)

        raw = src[i]
        if (rc == 0 && numtype(raw) == 0)
            out[i] = thetaCenter + scEff * (raw - thetaCenter) + dTh
        else
            out[i] = NaN
        endif
    endfor

    SetScale/P x, DimOffset(src,0), DimDelta(src,0), WaveUnits(src,0), out
    SetScale d, 0, 0, WaveUnits(src,-1), out

    Note/K out
    String noteStr = ""
    noteStr += "A2K1D angle correction from MDCTrack\r"
    noteStr += "source=" + peakPath + "\r"
    noteStr += "corrRunDF=" + cdf + "\r"
    noteStr += "formula=thetaCorr=thetaCenter+scaleEff*(thetaRaw-thetaCenter)+dThetaEff\r"
    noteStr += "thetaCenter=" + num2str(thetaCenter) + "\r"
    noteStr += "corrMode=" + num2str(corrMode) + "\r"
    noteStr += "skipFlagged=" + num2str(skipFlagged) + "\r"
    Note out, noteStr

    Print "AngleCorr peak written: " + outPath
    SetDataFolder df0
    return outPath
End

Function/S a2k1d_make_corr_sigma_angle_wave(sigmaPath, runDF)
    String sigmaPath, runDF

    Wave/Z src = $sigmaPath
    if (!WaveExists(src))
        Print "AngleCorr sigma: source missing: " + sigmaPath
        return ""
    endif

    if (WaveType(src) == 0 || WaveDims(src) != 1)
        Print "AngleCorr sigma: source must be numeric 1D: " + sigmaPath
        return ""
    endif

    if (!a2k1d_corr_run_is_valid(runDF))
        Print "AngleCorr sigma: invalid correction run: " + runDF
        return ""
    endif

    String outDF = GetWavesDataFolder(src, 1)
    if (strlen(outDF) == 0)
        outDF = "root:"
    endif

    String outName = a2k1d_make_corr_angle_name(NameOfWave(src))
    String outPath = outDF + outName
    String srcPath = outDF + NameOfWave(src)

    if (a2k1d_same_wave_path(srcPath, outPath))
        Print "AngleCorr sigma: source already appears corrected; keeping existing wave: " + srcPath
        return srcPath
    endif

    Duplicate/O src, $outPath
    Wave out = $outPath

    String cdf = a2k1d_df_with_colon(runDF)
    Variable nTrack = a2k1d_corr_nrows(cdf)

    NVAR corrMode = root:ARPES_LJZ:A2K1D:a2k1d_corrMode
    NVAR skipFlagged = root:ARPES_LJZ:A2K1D:a2k1d_corrSkipFlagged

    Variable i, row, rc, dTh, scEff, raw
    for (i=0; i<DimSize(src,0); i+=1)
        row = a2k1d_corr_row_for_layer(i, nTrack)
        if (row < 0 || row >= nTrack)
            out[i] = NaN
            continue
        endif
        rc = a2k1d_get_effective_corr(cdf, row, corrMode, skipFlagged, dTh, scEff)

        raw = src[i]
        if (rc == 0 && numtype(raw) == 0)
            out[i] = abs(scEff) * raw
        else
            out[i] = NaN
        endif
    endfor

    SetScale/P x, DimOffset(src,0), DimDelta(src,0), WaveUnits(src,0), out
    SetScale d, 0, 0, WaveUnits(src,-1), out

    Note/K out
    String noteStr = ""
    noteStr += "A2K1D sigma angle correction from MDCTrack\r"
    noteStr += "source=" + sigmaPath + "\r"
    noteStr += "corrRunDF=" + cdf + "\r"
    noteStr += "formula=sigmaThetaCorr=abs(scaleEff)*sigmaThetaRaw\r"
    noteStr += "corrMode=" + num2str(corrMode) + "\r"
    noteStr += "skipFlagged=" + num2str(skipFlagged) + "\r"
    Note out, noteStr

    Print "AngleCorr sigma written: " + outPath
    return outPath
End

Function/S a2k1d_make_corr_layer_angle_wave(layerPath, runDF)
    String layerPath, runDF

    Wave/Z src = $layerPath
    if (!WaveExists(src))
        Print "AngleCorr layer: source missing: " + layerPath
        return ""
    endif

    if (WaveType(src) == 0 || WaveDims(src) != 1)
        Print "AngleCorr layer: source must be numeric 1D: " + layerPath
        return ""
    endif

    String wn = NameOfWave(src)
    String srcDF = GetWavesDataFolder(src, 1)
    if (strlen(srcDF) == 0)
        srcDF = "root:"
    endif
    String srcPath = srcDF + wn

    if (a2k1d_is_layer_corr_name(wn))
        Print "AngleCorr layer: source already appears corrected; keeping existing wave: " + srcPath
        return srcPath
    endif

    if (!a2k1d_is_layer_int_name(wn))
        Print "AngleCorr layer: source must be raw angle-domain layer name: " + layerPath
        return ""
    endif

    if (!a2k1d_corr_run_is_valid(runDF))
        Print "AngleCorr layer: invalid correction run: " + runDF
        return ""
    endif

    Variable layerIdx = a2k1d_get_layer_index_safe(wn)
    String cdf = a2k1d_df_with_colon(runDF)
    Variable nTrack = a2k1d_corr_nrows(cdf)
    Variable row = a2k1d_corr_row_for_layer(layerIdx, nTrack)
    if (layerIdx < 0 || row < 0 || row >= nTrack)
        Print "AngleCorr layer: invalid layer index or correction row: " + wn
        return ""
    endif

    NVAR corrMode = root:ARPES_LJZ:A2K1D:a2k1d_corrMode
    NVAR skipFlagged = root:ARPES_LJZ:A2K1D:a2k1d_corrSkipFlagged

    Variable dTh, scEff
    Variable rc = a2k1d_get_effective_corr(cdf, row, corrMode, skipFlagged, dTh, scEff)
    if (rc != 0)
        Print "AngleCorr layer: invalid/skipped correction row. layer=", layerIdx, " row=", row
        return ""
    endif

    Variable thetaCenter = a2k1d_get_theta_center_from_corr_run(cdf)

    String outDF = srcDF
    String outName = a2k1d_make_corr_angle_name(wn)
    String outPath = outDF + outName

    if (a2k1d_same_wave_path(srcPath, outPath))
        Print "AngleCorr layer: source and output are identical; keeping existing wave: " + srcPath
        return srcPath
    endif

    Duplicate/O src, $outPath
    Wave out = $outPath

    Variable rawOff = DimOffset(src,0)
    Variable rawDel = DimDelta(src,0)
    Variable corrOff = thetaCenter + scEff * (rawOff - thetaCenter) + dTh
    Variable corrDel = scEff * rawDel

    SetScale/P x, corrOff, corrDel, WaveUnits(src,0), out
    SetScale d, 0, 0, WaveUnits(src,-1), out

    Note/K out
    String noteStr = ""
    noteStr += "A2K1D layer angle-axis correction from MDCTrack\r"
    noteStr += "source=" + layerPath + "\r"
    noteStr += "corrRunDF=" + cdf + "\r"
    noteStr += "layerIdx=" + num2str(layerIdx) + "\r"
    noteStr += "row=" + num2str(row) + "\r"
    noteStr += "dThetaEff=" + num2str(dTh) + "\r"
    noteStr += "scaleEff=" + num2str(scEff) + "\r"
    noteStr += "thetaCenter=" + num2str(thetaCenter) + "\r"
    noteStr += "xScaleFormula=thetaCorr=thetaCenter+scaleEff*(thetaRaw-thetaCenter)+dThetaEff\r"
    Note out, noteStr

    Print "AngleCorr layer written: " + outPath
    return outPath
End

Function/S a2k1d_find_wave_by_tail_ci(baseDF, recursive, tailName)
    String baseDF, tailName
    Variable recursive

    String found = a2k1d_find_wave_by_tail(baseDF, recursive, tailName)
    if (strlen(found) > 0)
        return found
    endif

    String base = a2k1d_df_with_colon(baseDF)
    if (!a2k1d_df_exists(base))
        return ""
    endif

    String tailLower = LowerStr(tailName)
    if (!recursive)
        String df0 = GetDataFolder(1)
        SetDataFolder $base
        String allNames = WaveList("*", ";", "DIMS:1")
        SetDataFolder df0

        Variable j, m
        m = ItemsInList(allNames, ";")
        for (j=0; j<m; j+=1)
            String wn0 = StringFromList(j, allNames, ";")
            if (strlen(wn0) == 0)
                continue
            endif
            if (cmpstr(LowerStr(wn0), tailLower) == 0)
                if (WaveExists($(base + wn0)))
                    return base + wn0
                endif
            endif
        endfor
        return ""
    endif

    String all = a2k1d_collect_1d_waves_recursive(base)
    Variable n = ItemsInList(all, ";")
    Variable i
    for (i=0; i<n; i+=1)
        String wp = StringFromList(i, all, ";")
        if (strlen(wp) == 0)
            continue
        endif
        if (cmpstr(LowerStr(a2k1d_tail_wavename(wp)), tailLower) == 0)
            if (WaveExists($wp))
                return wp
            endif
        endif
    endfor

    return ""
End


Function/S a2k1d_find_wave_tail_in_df_ci(dfIn, tailName)
    String dfIn, tailName

    String df = a2k1d_df_with_colon(dfIn)
    if (!a2k1d_df_exists(df))
        return ""
    endif

    String df0 = GetDataFolder(1)
    SetDataFolder $df

    String list = WaveList("*", ";", "DIMS:1")
    SetDataFolder df0

    String want = LowerStr(tailName)
    Variable i, n
    n = ItemsInList(list, ";")

    for (i=0; i<n; i+=1)
        String wn = StringFromList(i, list, ";")
        if (strlen(wn) == 0)
            continue
        endif
        if (CmpStr(LowerStr(wn), want) == 0)
            return df + wn
        endif
    endfor

    return ""
End

Function a2k1d_path_is_corr_k_output(wp)
    String wp
    String lw = LowerStr(a2k1d_tail_wavename(wp))
    if (StringMatch(lw, "*_k_spec_corr") || StringMatch(lw, "*_k_corr"))
        return 1
    endif
    return 0
End

Function/S a2k1d_find_preferred_k_peak(baseDF, recursive, rank)
    String baseDF
    Variable recursive, rank

    NVAR/Z useCorr = root:ARPES_LJZ:A2K1D:a2k1d_useAngleCorr
    Variable preferCorr = 0
    if (NVAR_Exists(useCorr))
        preferCorr = useCorr
    endif

    String corrTail = "Peak" + num2str(rank) + "K_k_corr"
    String oldTail  = "Peak" + num2str(rank) + "K_k"
    String firstTail, secondTail
    if (preferCorr)
        firstTail = corrTail
        secondTail = oldTail
    else
        firstTail = oldTail
        secondTail = corrTail
    endif

    String found = a2k1d_find_wave_by_tail_ci(baseDF, recursive, firstTail)
    if (strlen(found) > 0)
        return found
    endif

    found = a2k1d_find_wave_by_tail_ci(baseDF, recursive, secondTail)
    if (strlen(found) > 0 && preferCorr)
        Print "A2K1D: corrected output missing for peak " + num2str(rank) + "; fallback to uncorrected."
    endif
    return found
End

Function/S a2k1d_find_preferred_k_sigma(baseDF, recursive, rank)
    String baseDF
    Variable recursive, rank

    NVAR/Z useCorr = root:ARPES_LJZ:A2K1D:a2k1d_useAngleCorr
    Variable preferCorr = 0
    if (NVAR_Exists(useCorr))
        preferCorr = useCorr
    endif

    String corrTail = "Sigmap" + num2str(rank) + "K_k_corr"
    String oldTail  = "Sigmap" + num2str(rank) + "K_k"
    String firstTail, secondTail
    if (preferCorr)
        firstTail = corrTail
        secondTail = oldTail
    else
        firstTail = oldTail
        secondTail = corrTail
    endif

    String found = a2k1d_find_wave_by_tail_ci(baseDF, recursive, firstTail)
    if (strlen(found) > 0)
        return found
    endif

    found = a2k1d_find_wave_by_tail_ci(baseDF, recursive, secondTail)
    if (strlen(found) > 0 && preferCorr)
        Print "A2K1D: corrected sigma missing for peak " + num2str(rank) + "; fallback sigma is available."
    endif
    return found
End

Function/S a2k1d_find_preferred_delta_wave(baseDF, recursive, sigmaFlag)
    String baseDF
    Variable recursive, sigmaFlag

    NVAR/Z useCorr = root:ARPES_LJZ:A2K1D:a2k1d_useAngleCorr
    Variable preferCorr = 0
    if (NVAR_Exists(useCorr))
        preferCorr = useCorr
    endif

    String oldTail, corrTail
    if (sigmaFlag)
        oldTail = "SigmaDeltaK12_k"
        corrTail = "SigmaDeltaK12_k_corr"
    else
        oldTail = "DeltaK12_k"
        corrTail = "DeltaK12_k_corr"
    endif

    String firstTail, secondTail
    if (preferCorr)
        firstTail = corrTail
        secondTail = oldTail
    else
        firstTail = oldTail
        secondTail = corrTail
    endif

    String found = a2k1d_find_wave_by_tail_ci(baseDF, recursive, firstTail)
    if (strlen(found) > 0)
        return found
    endif

    found = a2k1d_find_wave_by_tail_ci(baseDF, recursive, secondTail)
    if (strlen(found) > 0 && preferCorr && !sigmaFlag)
        Print "A2K1D: corrected output missing for DeltaK12; fallback to uncorrected."
    endif
    return found
End

Function a2k1d_batch_corr_peaks_to_k(baseDF, recursive)
    String baseDF
    Variable recursive

    a2k1d_init_defaults_if_needed()

    String base = a2k1d_df_with_colon(baseDF)
    if (!a2k1d_df_exists(base))
        Print "Corr Peaks -> K: base data folder not found: " + base
        return -1
    endif

    a2k1d_sync_unified_from_legacy_if_missing()
    NVAR Pixel = root:ARPES_LJZ:A2K1D:Pixel
    NVAR ThetaAngle = root:ARPES_LJZ:A2K1D:ThetaAngle
    NVAR hv = root:ARPES_LJZ:A2K1D:hv
    NVAR WorkFunc = root:ARPES_LJZ:A2K1D:WorkFunc
    NVAR EnergyRel = root:ARPES_LJZ:A2K1D:EnergyRel
    NVAR MDCKf = root:ARPES_LJZ:A2K1D:MDCKf
    NVAR LatticeA = root:ARPES_LJZ:A2K1D:LatticeA
    NVAR outN        = root:ARPES_LJZ:A2K1D:a2k1d_outN

    String p1 = a2k1d_find_wave_by_tail_ci(base, recursive, "Peak1K_corr")
    String p2 = a2k1d_find_wave_by_tail_ci(base, recursive, "Peak2K_corr")
    String p3 = a2k1d_find_wave_by_tail_ci(base, recursive, "Peak3K_corr")

    String s1 = a2k1d_find_wave_by_tail_ci(base, recursive, "Sigmap1K_corr")
    String s2 = a2k1d_find_wave_by_tail_ci(base, recursive, "Sigmap2K_corr")
    String s3 = a2k1d_find_wave_by_tail_ci(base, recursive, "Sigmap3K_corr")

    Variable okP = 0
    Variable skipP = 0
    Variable failP = 0
    Variable okS = 0
    Variable skipS = 0
    Variable failS = 0
    Variable deltaCreated = 0
    Variable deltaSkipped = 0
    Variable sigmaDeltaCreated = 0
    Variable sigmaDeltaSkipped = 0

    if (strlen(p1) > 0)
        Wave/Z wP1 = $p1
        if (WaveExists(wP1) && LJZ_A2K1D_Run(p1, NameOfWave(wP1), Pixel, ThetaAngle, hv, WorkFunc, EnergyRel, MDCKf, LatticeA, outN) == 0)
            okP += 1
        else
            failP += 1
        endif
    else
        skipP += 1
    endif

    if (strlen(p2) > 0)
        Wave/Z wP2 = $p2
        if (WaveExists(wP2) && LJZ_A2K1D_Run(p2, NameOfWave(wP2), Pixel, ThetaAngle, hv, WorkFunc, EnergyRel, MDCKf, LatticeA, outN) == 0)
            okP += 1
        else
            failP += 1
        endif
    else
        skipP += 1
    endif

    if (strlen(p3) > 0)
        Wave/Z wP3 = $p3
        if (WaveExists(wP3) && LJZ_A2K1D_Run(p3, NameOfWave(wP3), Pixel, ThetaAngle, hv, WorkFunc, EnergyRel, MDCKf, LatticeA, outN) == 0)
            okP += 1
        else
            failP += 1
        endif
    else
        skipP += 1
    endif

    if (strlen(p1) > 0 && strlen(s1) > 0)
        Wave/Z wS1 = $s1
        if (WaveExists(wS1) && LJZ_A2K1D_Run_Sigma(p1, s1, NameOfWave(wS1), Pixel, ThetaAngle, hv, WorkFunc, EnergyRel, MDCKf, LatticeA) == 0)
            okS += 1
        else
            failS += 1
        endif
    else
        skipS += 1
    endif

    if (strlen(p2) > 0 && strlen(s2) > 0)
        Wave/Z wS2 = $s2
        if (WaveExists(wS2) && LJZ_A2K1D_Run_Sigma(p2, s2, NameOfWave(wS2), Pixel, ThetaAngle, hv, WorkFunc, EnergyRel, MDCKf, LatticeA) == 0)
            okS += 1
        else
            failS += 1
        endif
    else
        skipS += 1
    endif

    if (strlen(p3) > 0 && strlen(s3) > 0)
        Wave/Z wS3 = $s3
        if (WaveExists(wS3) && LJZ_A2K1D_Run_Sigma(p3, s3, NameOfWave(wS3), Pixel, ThetaAngle, hv, WorkFunc, EnergyRel, MDCKf, LatticeA) == 0)
            okS += 1
        else
            failS += 1
        endif
    else
        skipS += 1
    endif

    String p1k = a2k1d_find_wave_by_tail_ci(base, recursive, "Peak1K_k_corr")
    String p2k = a2k1d_find_wave_by_tail_ci(base, recursive, "Peak2K_k_corr")
    if (strlen(p1k) > 0 && strlen(p2k) > 0)
        Wave/Z wP1K = $p1k
        Wave/Z wP2K = $p2k
        if (WaveExists(wP1K) && WaveExists(wP2K) && WaveDims(wP1K)==1 && WaveDims(wP2K)==1 && DimSize(wP1K,0)==DimSize(wP2K,0))
            String deltaDF = GetWavesDataFolder(wP1K, 1)
            if (strlen(deltaDF) == 0)
                deltaDF = "root:"
            endif
            String deltaPath = deltaDF + "DeltaK12_k_corr"
            Duplicate/O wP1K, $deltaPath
            Wave wDelta = $deltaPath
            wDelta = abs(wP1K - wP2K)
            SetScale/P x, DimOffset(wP1K,0), DimDelta(wP1K,0), WaveUnits(wP1K,0), wDelta
            SetScale d, 0, 0, WaveUnits(wP1K,-1), wDelta
            Note/K wDelta
            String noteDelta = ""
            noteDelta += "A2K1D corrected DeltaK12 in k-space\r"
            noteDelta += "wave1=" + p1k + "\r"
            noteDelta += "wave2=" + p2k + "\r"
            noteDelta += "formula=abs(Peak1K_k_corr-Peak2K_k_corr)\r"
            Note wDelta, noteDelta
            deltaCreated = 1
        else
            deltaSkipped = 1
        endif
    else
        deltaSkipped = 1
    endif

    String s1k = a2k1d_find_wave_by_tail_ci(base, recursive, "Sigmap1K_k_corr")
    String s2k = a2k1d_find_wave_by_tail_ci(base, recursive, "Sigmap2K_k_corr")
    if (strlen(s1k) > 0 && strlen(s2k) > 0)
        Wave/Z wS1K = $s1k
        Wave/Z wS2K = $s2k
        if (WaveExists(wS1K) && WaveExists(wS2K) && WaveDims(wS1K)==1 && WaveDims(wS2K)==1 && DimSize(wS1K,0)==DimSize(wS2K,0))
            String sigmaDeltaDF = GetWavesDataFolder(wS1K, 1)
            if (strlen(sigmaDeltaDF) == 0)
                sigmaDeltaDF = "root:"
            endif
            String sigmaDeltaPath = sigmaDeltaDF + "SigmaDeltaK12_k_corr"
            Duplicate/O wS1K, $sigmaDeltaPath
            Wave wSigmaDelta = $sigmaDeltaPath
            wSigmaDelta = sqrt(wS1K^2 + wS2K^2)
            SetScale/P x, DimOffset(wS1K,0), DimDelta(wS1K,0), WaveUnits(wS1K,0), wSigmaDelta
            SetScale d, 0, 0, WaveUnits(wS1K,-1), wSigmaDelta
            Note/K wSigmaDelta
            String noteSigmaDelta = ""
            noteSigmaDelta += "A2K1D corrected SigmaDeltaK12 in k-space\r"
            noteSigmaDelta += "sigma1=" + s1k + "\r"
            noteSigmaDelta += "sigma2=" + s2k + "\r"
            noteSigmaDelta += "formula=sqrt(Sigmap1K_k_corr^2+Sigmap2K_k_corr^2)\r"
            Note wSigmaDelta, noteSigmaDelta
            sigmaDeltaCreated = 1
        else
            sigmaDeltaSkipped = 1
        endif
    else
        sigmaDeltaSkipped = 1
    endif

    Printf "Corr Peaks -> K summary: corrected peaks converted=%d skipped=%d failed=%d | corrected sigmas converted=%d skipped=%d failed=%d | DeltaK12_k_corr %s | SigmaDeltaK12_k_corr %s\r", okP, skipP, failP, okS, skipS, failS, SelectString(deltaCreated, "skipped", "created"), SelectString(sigmaDeltaCreated, "skipped", "created")
    return 0
End

Function a2k1d_batch_corr_layers_to_k(baseDF, recursive, corrRunDF)
    String baseDF, corrRunDF
    Variable recursive

    a2k1d_init_defaults_if_needed()

    String base = a2k1d_df_with_colon(baseDF)
    String corrBase = a2k1d_df_with_colon(corrRunDF)

    if (!a2k1d_df_exists(base))
        Print "Corr Layers -> K: base data folder not found: " + base
        return -1
    endif

    if (!a2k1d_corr_run_is_valid(corrBase))
        Print "Corr Layers -> K: invalid correction run: " + corrBase
        return -1
    endif

    NVAR ThetaAngle = root:ARPES_LJZ:A2K1D:ThetaAngle
    NVAR hv = root:ARPES_LJZ:A2K1D:hv
    NVAR WorkFunc = root:ARPES_LJZ:A2K1D:WorkFunc
    NVAR EnergyRel = root:ARPES_LJZ:A2K1D:EnergyRel
    NVAR MDCKf = root:ARPES_LJZ:A2K1D:MDCKf
    NVAR LatticeA = root:ARPES_LJZ:A2K1D:LatticeA
    NVAR corrMode    = root:ARPES_LJZ:A2K1D:a2k1d_corrMode
    NVAR skipFlagged = root:ARPES_LJZ:A2K1D:a2k1d_corrSkipFlagged
    NVAR showGraph   = root:ARPES_LJZ:A2K1D:a2k1d_showGraph

    String list = a2k1d_collect_layers(base, recursive)
    Variable n = ItemsInList(list, ";")

    Variable oldShow = showGraph
    showGraph = 0

    Variable i
    Variable okCorr = 0
    Variable okK = 0
    Variable fail = 0
    Variable skipFlag = 0
    Variable skipInvalid = 0
    Variable nTrack = a2k1d_corr_nrows(corrBase)

    for (i=0; i<n; i+=1)
        String rawPath = StringFromList(i, list, ";")
        if (strlen(rawPath) == 0)
            continue
        endif

        Wave/Z rawLayer = $rawPath
        if (!WaveExists(rawLayer))
            fail += 1
            continue
        endif

        String rawName = NameOfWave(rawLayer)
        if (a2k1d_is_result_wave_name(rawName) || !a2k1d_is_layer_int_name(rawName))
            fail += 1
            continue
        endif

        Variable layerIdx = a2k1d_get_layer_index_safe(rawName)
        Variable row = a2k1d_corr_row_for_layer(layerIdx, nTrack)
        if (layerIdx < 0 || row < 0 || row >= nTrack)
            Print "Skip " + rawName + ": invalid layer index or correction row."
            skipInvalid += 1
            continue
        endif

        Variable dTh, scEff
        Variable corrRC = a2k1d_get_effective_corr(corrBase, row, corrMode, skipFlagged, dTh, scEff)
        if (corrRC == -3)
            skipFlag += 1
            continue
        endif
        if (corrRC != 0)
            Print "Skip " + rawName + ": invalid layer index or correction row."
            skipInvalid += 1
            continue
        endif

        String corrPath = a2k1d_make_corr_layer_angle_wave(rawPath, corrBase)
        if (strlen(corrPath) <= 0)
            fail += 1
            continue
        endif
        okCorr += 1

        Wave/Z corrWave = $corrPath
        if (!WaveExists(corrWave))
            fail += 1
            continue
        endif

        if (LJZ_Spectra_Interp_Run(corrPath, NameOfWave(corrWave), ThetaAngle, hv, WorkFunc, EnergyRel, MDCKf, LatticeA) == 0)
            okK += 1
        else
            fail += 1
        endif
    endfor

    showGraph = oldShow

    Printf "Corr Layers -> K summary: raw layers found=%d angle-corrected layers created=%d corrected k-space spectra created=%d failed=%d skipped flagged rows=%d skipped invalid rows=%d\r", n, okCorr, okK, fail, skipFlag, skipInvalid
    return 0
End

Function/S a2k1d_find_wave_by_tail(baseDF, recursive, tailName)
    String baseDF, tailName
    Variable recursive

    String base = a2k1d_df_with_colon(baseDF)
    if (!a2k1d_df_exists(base))
        return ""
    endif

    if (!recursive)
        // direct in base folder
        if (WaveExists($(base + tailName)))
            return base + tailName
        endif
        return ""
    endif

    // recursive search in all 1D waves (full paths)
    String all = a2k1d_collect_1d_waves_recursive(base)
    Variable n = ItemsInList(all, ";")
    Variable i
    for (i=0; i<n; i+=1)
        String wp = StringFromList(i, all, ";")
        if (strlen(wp) == 0)
            continue
        endif
        if (StringMatch(a2k1d_tail_wavename(wp), tailName))
            if (WaveExists($wp))
                return wp
            endif
        endif
    endfor

    return ""
End

Function a2k1d_clamp(v, lo, hi)
    Variable v, lo, hi
    if (v < lo)
        return lo
    endif
    if (v > hi)
        return hi
    endif
    return v
End

//============================================================
// Helper: compute global k-range from optional peak wave paths without
// creating Wave/Z references from empty strings.
//============================================================
Function a2k1d_path_is_valid_1d_wave(wp)
    String wp

    if (strlen(wp) <= 0)
        return 0
    endif

    Wave/Z w = $wp
    if (!WaveExists(w))
        return 0
    endif

    if (WaveDims(w) != 1)
        return 0
    endif

    return 1
End

Function a2k1d_value_from_1d_path(wp, idx)
    String wp
    Variable idx

    if (strlen(wp) <= 0)
        return NaN
    endif

    Wave/Z w = $wp
    if (!WaveExists(w))
        return NaN
    endif

    if (WaveDims(w) != 1)
        return NaN
    endif

    if (idx < 0 || idx >= DimSize(w, 0))
        return NaN
    endif

    return w[idx]
End

Function a2k1d_wave_has_any_finite(w)
    Wave w

    Variable i, n
    n = DimSize(w, 0)

    for (i = 0; i < n; i += 1)
        if (numtype(w[i]) == 0)
            return 1
        endif
    endfor

    return 0
End

Function a2k1d_accumulate_peak_range_from_path(peakPath, nLayers, kMinOut, kMaxOut, hasOut)
    String peakPath
    Variable nLayers
    Variable &kMinOut, &kMaxOut, &hasOut

    if (!a2k1d_path_is_valid_1d_wave(peakPath))
        return 0
    endif

    Wave/Z w = $peakPath
    if (!WaveExists(w))
        return 0
    endif

    Variable n = min(nLayers, DimSize(w, 0))
    Variable i, v

    for (i = 0; i < n; i += 1)
        v = w[i]
        if (numtype(v) == 0)
            if (hasOut == 0)
                kMinOut = v
                kMaxOut = v
                hasOut = 1
            else
                if (v < kMinOut)
                    kMinOut = v
                endif
                if (v > kMaxOut)
                    kMaxOut = v
                endif
            endif
        endif
    endfor

    return 0
End

//============================================================
// Helper: compute global k-range from optional peak wave paths without
// creating Wave/Z references from empty strings.
//============================================================
Function a2k1d_peak_global_krange_paths(p1Path, p2Path, p3Path, nLayers, marginFrac, minAbsMargin, kLoOut, kHiOut)
    String p1Path, p2Path, p3Path
    Variable nLayers, marginFrac, minAbsMargin
    Variable &kLoOut, &kHiOut

    Variable kMin = NaN
    Variable kMax = NaN
    Variable has = 0

    a2k1d_accumulate_peak_range_from_path(p1Path, nLayers, kMin, kMax, has)
    a2k1d_accumulate_peak_range_from_path(p2Path, nLayers, kMin, kMax, has)
    a2k1d_accumulate_peak_range_from_path(p3Path, nLayers, kMin, kMax, has)

    if (has == 0)
        kLoOut = NaN
        kHiOut = NaN
        return 0
    endif

    Variable span = kMax - kMin
    Variable margin = abs(span) * marginFrac

    if (margin < minAbsMargin)
        margin = minAbsMargin
    endif

    kLoOut = kMin - margin
    kHiOut = kMax + margin

    if (numtype(kLoOut) != 0 || numtype(kHiOut) != 0)
        return 0
    endif

    if (kHiOut <= kLoOut)
        return 0
    endif

    return 1
End

//============================================================
// 打开颜色盘选择器 (极速版：只读全局波形)
//============================================================
Function/S a2k1d_collect_existing_kspec_list(baseDF, recursive)
    String baseDF
    Variable recursive

    String rawList = a2k1d_collect_layers(baseDF, recursive)
    String listKS = ""

    Variable i, n = ItemsInList(rawList, ";")
    for (i=0; i<n; i+=1)
        String wp = StringFromList(i, rawList, ";")
        if (strlen(wp) == 0)
            continue
        endif

        Wave/Z wRaw = $wp
        if (!WaveExists(wRaw))
            continue
        endif

        String outDF = GetWavesDataFolder(wRaw, 1)
        if (strlen(outDF) == 0)
            outDF = "root:"
        endif

        String bn = a2k1d_clean_basename(NameOfWave(wRaw))
        String wps = outDF + bn + "_k_spec"
        Wave/Z wSpec = $wps

        if (WaveExists(wSpec))
            if (WhichListItem(wps, listKS, ";") == -1)
                listKS += wps + ";"
            endif
        endif
    endfor

    return listKS
End

Function/S a2k1d_collect_existing_kspec_list_prefer_corr(baseDF, recursive, preferCorr)
    String baseDF
    Variable recursive, preferCorr

    String rawList = a2k1d_collect_layers(baseDF, recursive)
    rawList = a2k1d_sort_kspec_list_by_layerindex(rawList)
    String listKS = ""
    Variable corrUsed = 0
    Variable fallbackUsed = 0
    Variable oldUsed = 0
    Variable corrFallbackUsed = 0

    Variable i, n = ItemsInList(rawList, ";")
    for (i=0; i<n; i+=1)
        String wp = StringFromList(i, rawList, ";")
        if (strlen(wp) == 0)
            continue
        endif

        Wave/Z wRaw = $wp
        if (!WaveExists(wRaw))
            continue
        endif

        String outDF = GetWavesDataFolder(wRaw, 1)
        if (strlen(outDF) == 0)
            outDF = "root:"
        endif

        String bn = a2k1d_clean_basename(NameOfWave(wRaw))
        String oldPath = outDF + bn + "_k_spec"
        String corrPath = outDF + bn + "_k_spec_corr"
        String chosen = ""

        Wave/Z wOld = $oldPath
        Wave/Z wCorr = $corrPath

        if (preferCorr)
            if (WaveExists(wCorr))
                chosen = corrPath
                corrUsed += 1
            elseif (WaveExists(wOld))
                chosen = oldPath
                fallbackUsed += 1
            endif
        else
            if (WaveExists(wOld))
                chosen = oldPath
                oldUsed += 1
            elseif (WaveExists(wCorr))
                chosen = corrPath
                corrFallbackUsed += 1
            endif
        endif

        if (strlen(chosen) > 0 && WhichListItem(chosen, listKS, ";") == -1)
            listKS += chosen + ";"
        endif
    endfor

    if (preferCorr)
        Printf "A2K1D: corrected spectra used = %d; fallback spectra used = %d\r", corrUsed, fallbackUsed
    else
        if (corrFallbackUsed > 0)
            Printf "A2K1D: uncorrected spectra used = %d; corrected fallback spectra used = %d\r", oldUsed, corrFallbackUsed
        endif
    endif

    return listKS
End

Function/S a2k1d_sort_kspec_list_by_layerindex(listIn)
    String listIn

    Variable n = ItemsInList(listIn, ";")
    if (n <= 1)
        return listIn
    endif

    String df0 = GetDataFolder(1)
    a2k1d_ensure_folder()
    SetDataFolder root:ARPES_LJZ:OUTPUT:A2K1D

    Make/O/D/N=(n) a2k1d_sort_idx
    Make/O/T/N=(n) a2k1d_sort_path

    Wave idxW = a2k1d_sort_idx
    Wave/T pathW = a2k1d_sort_path

    Variable i
    for (i=0; i<n; i+=1)
        String wp = StringFromList(i, listIn, ";")
        pathW[i] = wp
        idxW[i] = a2k1d_get_layer_index_safe(a2k1d_clean_basename(a2k1d_tail_wavename(wp)))
        if (numtype(idxW[i]) != 0)
            idxW[i] = 1e9
        endif
    endfor

    Sort idxW, idxW, pathW

    String out = ""
    for (i=0; i<n; i+=1)
        if (strlen(pathW[i]) > 0)
            out += pathW[i] + ";"
        endif
    endfor

    KillWaves/Z a2k1d_sort_idx, a2k1d_sort_path
    SetDataFolder df0
    return out
End




