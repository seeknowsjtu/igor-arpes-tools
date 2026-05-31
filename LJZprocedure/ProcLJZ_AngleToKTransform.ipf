#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


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

    // ---------------- parameters ----------------
    // DegPerPixel: 
    // NOW INTERPRETED AS: Multiplier for the Y-value (if 0, treated as 1)
    NVAR/Z a2k1d_degPerPix = root:ARPES_LJZ:A2K1D:a2k1d_degPerPix
    if (!NVAR_Exists(a2k1d_degPerPix))
        Variable/G a2k1d_degPerPix = 0
    endif

    NVAR/Z a2k1d_thetaOffset = root:ARPES_LJZ:A2K1D:a2k1d_thetaOffset
    if (!NVAR_Exists(a2k1d_thetaOffset))
        Variable/G a2k1d_thetaOffset = 0
    endif

    NVAR/Z a2k1d_hv = root:ARPES_LJZ:A2K1D:a2k1d_hv
    if (!NVAR_Exists(a2k1d_hv))
        Variable/G a2k1d_hv = 21.2
    endif

    NVAR/Z a2k1d_workFunc = root:ARPES_LJZ:A2K1D:a2k1d_workFunc
    if (!NVAR_Exists(a2k1d_workFunc))
        Variable/G a2k1d_workFunc = 4.5
    endif

    // EnergyTermE: Ek = hv + EnergyTermE - WorkFunc
    NVAR/Z a2k1d_energyE = root:ARPES_LJZ:A2K1D:a2k1d_energyE
    if (!NVAR_Exists(a2k1d_energyE))
        Variable/G a2k1d_energyE = 0
    endif

    // kShift: output value = k_calc - kShift
    NVAR/Z a2k1d_kShift = root:ARPES_LJZ:A2K1D:a2k1d_kShift
    if (!NVAR_Exists(a2k1d_kShift))
        Variable/G a2k1d_kShift = 0
    endif

    // LatticeConstant:
    //   ==0 : output in A^-1
    //   !=0 : output in pi/a
    NVAR/Z a2k1d_LC = root:ARPES_LJZ:A2K1D:a2k1d_LC
    if (!NVAR_Exists(a2k1d_LC))
        Variable/G a2k1d_LC = 0
    endif

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
// Entry
//============================================================
Proc A2K1D_LJZ()
    a2k1d_init_defaults_if_needed()
    
    // 启动时构建一次颜色列表
    a2k1d_rebuild_ct_list()

    DoWindow/F A2K1D_LJZ_P
    if (V_flag == 0)
        A2K1D_LJZ_P()
    endif

    a2k1d_rebuild_lb()
End

Menu "ARPES_LJZ"
    "Angle->k (Value Transform)", A2K1D_LJZ()
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

Function a2k1d_sv_df_proc(ctrlName, varNum, varStr, varName) : SetVariableControl
    String ctrlName, varStr, varName
    Variable varNum
    SVAR a2k1d_baseDF = root:ARPES_LJZ:A2K1D:a2k1d_baseDF
    String s = a2k1d_df_with_colon(a2k1d_baseDF)
    if (!a2k1d_df_exists(s))
        s = "root:"
    endif
    a2k1d_baseDF = s
    a2k1d_rebuild_lb()
    return 0
End

Function a2k1d_rebuild_lb()
    a2k1d_ensure_folder()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:A2K1D

    SVAR a2k1d_baseDF = root:ARPES_LJZ:A2K1D:a2k1d_baseDF
    NVAR a2k1d_recursive = root:ARPES_LJZ:A2K1D:a2k1d_recursive
    SVAR a2k1d_wavePath = root:ARPES_LJZ:A2K1D:a2k1d_wavePath

    Wave/T   LB_Items = root:ARPES_LJZ:A2K1D:LB_Items
    Wave/U/B LB_Sel   = root:ARPES_LJZ:A2K1D:LB_Sel

    Redimension/N=0 LB_Items, LB_Sel
    a2k1d_wavePath = ""

    String base = a2k1d_df_with_colon(a2k1d_baseDF)
    if (!a2k1d_df_exists(base))
        base = "root:"
    endif
    a2k1d_baseDF = base

    // 收集（理论上已较干净）
    String layers = a2k1d_collect_layers(base, a2k1d_recursive)
    String peaks  = a2k1d_collect_peak_sigma(base, a2k1d_recursive)

    // ✅ 最终硬过滤：任何 *_k 或 *_k_spec 都不进列表（避免误操作）
    String listStr = ""
    String rawList = layers + peaks

    Variable i, n
    n = ItemsInList(rawList, ";")
    for (i=0; i<n; i+=1)
        String wp = StringFromList(i, rawList, ";")
        if (strlen(wp) == 0)
            continue
        endif

        String wn = a2k1d_tail_wavename(wp)

        // hard drop outputs
        if (a2k1d_is_result_wave_name(wn))
            continue
        endif

        // allow only: raw layers OR peak/sigmap
        if (a2k1d_is_layer_int_name(wn) || a2k1d_is_peak_sigma_name(wn))
            listStr += wp + ";"
        endif
    endfor

    n = ItemsInList(listStr, ";")
    if (n > 0)
        Redimension/N=(n) LB_Items, LB_Sel
        for (i=0; i<n; i+=1)
            String fullPath = StringFromList(i, listStr, ";")

            if (!a2k1d_recursive)
                LB_Items[i] = a2k1d_tail_wavename(fullPath)
            else
                LB_Items[i] = fullPath
            endif

            LB_Sel[i] = 0
        endfor
    endif

    SetDataFolder df0

    DoWindow A2K1D_LJZ_P
    if (V_flag)
        ControlUpdate/W=A2K1D_LJZ_P a2k1d_lb
        TitleBox a2k1d_status, win=A2K1D_LJZ_P, title="Selected: (none)"
        TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title="Status: idle"
    endif

    return 0
End


//============================================================
// ListBox proc
//============================================================
Function a2k1d_lb_proc(ctrlName, row, col, eventCode) : ListBoxControl
    String ctrlName
    Variable row, col, eventCode

    if (eventCode != 4)
        return 0
    endif

    Wave/U/B LB_Sel = root:ARPES_LJZ:A2K1D:LB_Sel
    Wave/T   LB_Items = root:ARPES_LJZ:A2K1D:LB_Items
    SVAR     a2k1d_wavePath = root:ARPES_LJZ:A2K1D:a2k1d_wavePath
    SVAR     a2k1d_baseDF = root:ARPES_LJZ:A2K1D:a2k1d_baseDF
    NVAR     a2k1d_recursive = root:ARPES_LJZ:A2K1D:a2k1d_recursive

    if (row < 0 || row >= DimSize(LB_Items, 0))
        return 0
    endif

    LB_Sel = 0
    LB_Sel[row] = 1

    String item = LB_Items[row]
    if (strlen(item) == 0)
        a2k1d_wavePath = ""
    else
        if (a2k1d_recursive)
            a2k1d_wavePath = item
        else
            String base = a2k1d_df_with_colon(a2k1d_baseDF)
            a2k1d_baseDF = base
            a2k1d_wavePath = base + item
        endif
    endif

    DoWindow A2K1D_LJZ_P
    if (V_flag)
        TitleBox a2k1d_status, win=A2K1D_LJZ_P, title="Selected: " + a2k1d_wavePath
    endif

    return 0
End

//============================================================
// Buttons
//============================================================
Function a2k1d_btn_scan(ctrlName) : ButtonControl
    String ctrlName
    a2k1d_rebuild_lb()
    return 0
End

Function a2k1d_btn_abort(ctrlName) : ButtonControl
    String ctrlName
    NVAR a2k1d_abortFlag = root:ARPES_LJZ:A2K1D:a2k1d_abortFlag
    a2k1d_abortFlag = 1
    DoWindow A2K1D_LJZ_P
    if (V_flag)
        TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title="Status: abort requested"
    endif
    return 0
End


Function a2k1d_btn_table_peak_k(ctrlName) : ButtonControl
    String ctrlName

    a2k1d_init_defaults_if_needed()

    SVAR a2k1d_baseDF = root:ARPES_LJZ:A2K1D:a2k1d_baseDF
    String fdf = a2k1d_df_with_colon(a2k1d_baseDF)

    if (DataFolderExists(fdf) && (WaveExists($(fdf + "Long_PeakAngle"))))
        Print "A2K1D Table Peak->K: using baseDF " + fdf
        LJZ_A2K1D_TransformLongTable(fdf)
        return 0
    endif

    String candidate = RemoveEnding(fdf, ":") + ":FIT_HP:"
    if (DataFolderExists(candidate) && (WaveExists($(candidate + "Long_PeakAngle"))))
        Print "A2K1D Table Peak->K: baseDF had no Long_PeakAngle, falling back to " + candidate
        LJZ_A2K1D_TransformLongTable(candidate)
        return 0
    endif

    DoAlert 0, "Table Peak->K: Long_PeakAngle not found in checked folders:\r1) " + fdf + "\r2) " + candidate + "\rPlease point Base DF to FIT_HP or run MDCWB Export first."
    return 0
End

//============================================================
// Helper: forbid using result waves as input
//============================================================
Function a2k1d_is_result_wave_name(wn)
    String wn
    // 结果波：*_k_spec 或 *_k
    if (StringMatch(wn, "*_k_spec"))
        return 1
    endif
    if (StringMatch(wn, "*_k"))
        return 1
    endif
    return 0
End


Function a2k1d_btn_spec_run(ctrlName) : ButtonControl
    String ctrlName

    // 1. Get Selected Wave
    SVAR a2k1d_wavePath = root:ARPES_LJZ:A2K1D:a2k1d_wavePath
    if (strlen(a2k1d_wavePath) == 0)
        Abort "A2K1D: No wave selected."
    endif

    Wave/Z src = $a2k1d_wavePath
    if (!WaveExists(src))
        Abort "A2K1D: selected wave not found."
    endif

    // ✅ 核心：禁止把 *_k_spec 或 *_k 当输入
    String wn = NameOfWave(src)
    if (a2k1d_is_result_wave_name(wn))
        Abort "A2K1D Spectra: Please select RAW 'layer_show_i' (input). '*_k_spec'/'*_k' are outputs and must NOT be re-processed."
    endif

    // ✅ 强约束：Spectra 插值只接受 layer_show_纯数字
    if (!a2k1d_is_layer_int_name(wn))
        Abort "A2K1D Spectra: Input must be 'layer_show_<integer>' (raw)."
    endif

    // 2. Get Parameters
    NVAR a2k1d_thetaOffset= root:ARPES_LJZ:A2K1D:a2k1d_thetaOffset
    NVAR a2k1d_hv         = root:ARPES_LJZ:A2K1D:a2k1d_hv
    NVAR a2k1d_workFunc   = root:ARPES_LJZ:A2K1D:a2k1d_workFunc
    NVAR a2k1d_energyE    = root:ARPES_LJZ:A2K1D:a2k1d_energyE
    NVAR a2k1d_kShift     = root:ARPES_LJZ:A2K1D:a2k1d_kShift
    NVAR a2k1d_LC         = root:ARPES_LJZ:A2K1D:a2k1d_LC
    SVAR a2k1d_baseName   = root:ARPES_LJZ:A2K1D:a2k1d_baseName

    // baseName: 默认用输入名（layer_show_i）
    String useBaseName = a2k1d_baseName
    if (strlen(useBaseName) == 0)
        useBaseName = wn
    endif

    // 3. Set Output Folder: SAME DF as source wave
    String df0 = GetDataFolder(1)
    SetDataFolder GetWavesDataFolder(src, 1)

    // 4. Update Status UI
    DoWindow A2K1D_LJZ_P
    if (V_flag)
        TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title="Status: Interpolating..."
    endif

    // 5. Run (✅ 输出会 Duplicate/O 覆盖已有 *_k_spec)
    Variable rc
    rc = LJZ_Spectra_Interp_Run(a2k1d_wavePath, useBaseName, a2k1d_thetaOffset, a2k1d_hv, a2k1d_workFunc, a2k1d_energyE, a2k1d_kShift, a2k1d_LC)

    SetDataFolder df0

    // 6. Finish UI
    DoWindow A2K1D_LJZ_P
    if (V_flag)
        if (rc == 0)
            TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title="Status: Done (Spectra)"
        else
            TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title="Status: Failed"
        endif
    endif

    return 0
End


Function a2k1d_btn_run(ctrlName) : ButtonControl
    String ctrlName

    SVAR a2k1d_wavePath = root:ARPES_LJZ:A2K1D:a2k1d_wavePath
    if (strlen(a2k1d_wavePath) == 0)
        Abort "A2K1D: No wave selected."
    endif

    Wave/Z src = $a2k1d_wavePath
    if (!WaveExists(src))
        Abort "A2K1D: selected wave not found."
    endif

    // gather params
    NVAR a2k1d_degPerPix  = root:ARPES_LJZ:A2K1D:a2k1d_degPerPix
    NVAR a2k1d_thetaOffset= root:ARPES_LJZ:A2K1D:a2k1d_thetaOffset
    NVAR a2k1d_hv         = root:ARPES_LJZ:A2K1D:a2k1d_hv
    NVAR a2k1d_workFunc   = root:ARPES_LJZ:A2K1D:a2k1d_workFunc
    NVAR a2k1d_energyE    = root:ARPES_LJZ:A2K1D:a2k1d_energyE
    NVAR a2k1d_kShift     = root:ARPES_LJZ:A2K1D:a2k1d_kShift
    NVAR a2k1d_LC         = root:ARPES_LJZ:A2K1D:a2k1d_LC
    NVAR a2k1d_outN       = root:ARPES_LJZ:A2K1D:a2k1d_outN
    SVAR a2k1d_baseName   = root:ARPES_LJZ:A2K1D:a2k1d_baseName

    // reset abort
    NVAR a2k1d_abortFlag = root:ARPES_LJZ:A2K1D:a2k1d_abortFlag
    a2k1d_abortFlag = 0

    DoWindow A2K1D_LJZ_P
    if (V_flag)
        TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title="Status: running..."
    endif

    String useBaseName = a2k1d_baseName
    if (strlen(useBaseName) == 0)
        useBaseName = NameOfWave(src)
    endif

	String df0 = GetDataFolder(1)
	SetDataFolder GetWavesDataFolder(src, 1)   // output next to src

    Variable rc
    rc = LJZ_A2K1D_Run(a2k1d_wavePath, useBaseName, a2k1d_degPerPix, a2k1d_thetaOffset, a2k1d_hv, a2k1d_workFunc, a2k1d_energyE, a2k1d_kShift, a2k1d_LC, a2k1d_outN)

    SetDataFolder df0

    DoWindow A2K1D_LJZ_P
    if (V_flag)
        if (rc == 0)
            TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title="Status: done"
        else
            TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title="Status: failed"
        endif
    endif

    if (rc < 0)
        Abort "A2K1D: algorithm failed."
    endif

    return 0
End

Function a2k1d_btn_close(ctrlName) : ButtonControl
    String ctrlName
    DoWindow/K A2K1D_LJZ_P
    return 0
End

Function a2k1d_btn_help(ctrlName) : ButtonControl
    String ctrlName
    String nb = "A2K1D_LJZ_HELP"
    DoWindow/F $nb
    if (V_flag == 0)
        NewNotebook/N=$nb/F=1/V=1 as "Angle->k Value Help"
    endif
    Notebook $nb selection={startOfFile, endOfFile}
    Notebook $nb text=""
    Notebook $nb text="Angle->k (Value Transform)\r"
    Notebook $nb text="===========================\r"
    Notebook $nb text="Input: Wave where Y = Angle, X = Time/Step.\r"
    Notebook $nb text="Output: Wave where Y = Momentum (k), X = unchanged.\r\r"
    Notebook $nb text="Formula:\r  k = 0.5118 * sqrt(Ek) * sin(Angle_Deg)\r"
    Notebook $nb text="  Ek = hv + EnergyE - WorkFunc\r\r"
    Notebook $nb text="Angle Calculation:\r"
    Notebook $nb text="  If DegPerPix = 0: Angle = Y_raw + ThetaOffset\r"
    Notebook $nb text="  If DegPerPix != 0: Angle = Y_raw * DegPerPix + ThetaOffset\r\r"
    Notebook $nb text="Note: OutN is ignored in this mode.\r"
    return 0
End

Window A2K1D_LJZ_P() : Panel
	PauseUpdate; Silent 1
	NewPanel /W=(420,60,982.2,790.0) as "Angle->k (Value & Spectra) (LJZ)"
	ModifyPanel frameStyle=1
	ShowTools/A

	// --- Status bar ---
	TitleBox a2k1d_t0,pos={12,9},size={312,18},title="Transform: Value or Spectra Interpolation",frame=0
	TitleBox a2k1d_status,pos={12,27},size={312,18},title="Selected: (none)",frame=0
	TitleBox a2k1d_runstat,pos={12,45},size={312,18},title="Status: idle",frame=0

	// --- Base DF row ---
	TitleBox a2k1d_tdf,pos={12,69},size={48,18},title="Base DF:",frame=0
	SetVariable a2k1d_sv_df,pos={64,66},size={260,19.80},proc=a2k1d_sv_df_proc
	SetVariable a2k1d_sv_df,value= root:ARPES_LJZ:A2K1D:a2k1d_baseDF
	CheckBox a2k1d_ck_rec,pos={336,69},size={80,18},title="Recursive"
	CheckBox a2k1d_ck_rec,variable= root:ARPES_LJZ:A2K1D:a2k1d_recursive
	Button a2k1d_btn_scan,pos={432,66},size={72,21},proc=a2k1d_btn_scan,title="Scan"

	// --- Left: ListBox ---
	ListBox a2k1d_lb,pos={12,96},size={312,348},proc=a2k1d_lb_proc
	ListBox a2k1d_lb,listWave=root:ARPES_LJZ:A2K1D:LB_Items
	ListBox a2k1d_lb,selWave=root:ARPES_LJZ:A2K1D:LB_Sel,mode=1,selRow=0

	// --- Right: Physics params ---
	TitleBox a2k1d_tp,pos={336,96},size={204,18},title="-- Physics --",frame=0

	SetVariable a2k1d_sv_th,pos={336,116},size={98,19.80},title="ThetaOff"
	SetVariable a2k1d_sv_th,limits={-360,360,0.01},value= root:ARPES_LJZ:A2K1D:a2k1d_thetaOffset
	SetVariable a2k1d_sv_hv,pos={438,116},size={102,19.80},title="hv(eV)"
	SetVariable a2k1d_sv_hv,limits={0,1e+06,0.01},value= root:ARPES_LJZ:A2K1D:a2k1d_hv

	SetVariable a2k1d_sv_wf,pos={336,140},size={98,19.80},title="WorkFunc"
	SetVariable a2k1d_sv_wf,limits={0,100,0.01},value= root:ARPES_LJZ:A2K1D:a2k1d_workFunc
	SetVariable a2k1d_sv_e,pos={438,140},size={102,19.80},title="EnergyE"
	SetVariable a2k1d_sv_e,limits={-100000,100000,0.01},value= root:ARPES_LJZ:A2K1D:a2k1d_energyE

	SetVariable a2k1d_sv_ksh,pos={336,164},size={98,19.80},title="kShift"
	SetVariable a2k1d_sv_ksh,limits={-100000,100000,0.0001},value= root:ARPES_LJZ:A2K1D:a2k1d_kShift
	SetVariable a2k1d_sv_lc,pos={438,164},size={102,19.80},title="LC(a)"
	SetVariable a2k1d_sv_lc,limits={0,1e+06,0.0001},value= root:ARPES_LJZ:A2K1D:a2k1d_LC

	// --- Right: Single-wave ---
	TitleBox a2k1d_tp_single,pos={336,192},size={204,18},title="-- Single wave --",frame=0

	SetVariable a2k1d_sv_bn,pos={336,212},size={204,19.80},title="BaseName"
	SetVariable a2k1d_sv_bn,value= root:ARPES_LJZ:A2K1D:a2k1d_baseName

	SetVariable a2k1d_sv_deg,pos={336,236},size={98,19.80},title="DegPerPix"
	SetVariable a2k1d_sv_deg,limits={-999,999,0.001},value= root:ARPES_LJZ:A2K1D:a2k1d_degPerPix
	SetVariable a2k1d_sv_n,pos={438,236},size={102,19.80},title="OutN"
	SetVariable a2k1d_sv_n,limits={0,1e+07,1},value= root:ARPES_LJZ:A2K1D:a2k1d_outN

	Button a2k1d_btn_run,pos={336,260},size={204,22},proc=a2k1d_btn_run,title="Run Value Trans (Y=Angle)"
	Button a2k1d_btn_spec,pos={336,284},size={204,22},proc=a2k1d_btn_spec_run,title="Run Spectra (X=Angle->k Interp)"

	// --- Right: Batch ---
	TitleBox a2k1d_tp_batch,pos={336,314},size={204,18},title="-- Batch --",frame=0

	Button a2k1d_btn_batch_layer,pos={336,334},size={204,22},proc=a2k1d_btn_batch_layers_interp,title="Batch: layer_xx Spectra->k"
	Button a2k1d_btn_batch_peak,pos={336,358},size={204,22},proc=a2k1d_btn_batch_peaks_valuetrans,title="Batch: peak/sigmap Value->k"
	Button a2k1d_btn_table_peak_k,pos={336,382},size={204,22},proc=a2k1d_btn_table_peak_k,title="Table Peak->K"

	SetVariable a2k1d_sv_corr_df,pos={336,410},size={204,19.80},title="CorrRunDF"
	SetVariable a2k1d_sv_corr_df,value= root:ARPES_LJZ:A2K1D:a2k1d_corrRunDF
	CheckBox a2k1d_ck_angle_corr,pos={336,434},size={104,18},title="Use angle corr"
	CheckBox a2k1d_ck_angle_corr,variable= root:ARPES_LJZ:A2K1D:a2k1d_useAngleCorr
	CheckBox a2k1d_ck_corr_skip,pos={444,434},size={96,18},title="skip flagged"
	CheckBox a2k1d_ck_corr_skip,variable= root:ARPES_LJZ:A2K1D:a2k1d_corrSkipFlagged
	SetVariable a2k1d_sv_corr_mode,pos={336,456},size={98,19.80},title="CorrMode"
	SetVariable a2k1d_sv_corr_mode,limits={0,2,1},value= root:ARPES_LJZ:A2K1D:a2k1d_corrMode
	TitleBox a2k1d_tb_corr_mode,pos={438,458},size={102,18},title="0 full, 1 first, 2 mean",frame=0
	Button a2k1d_btn_corr_peaks,pos={336,480},size={98,22},proc=a2k1d_btn_make_corr_peaks,title="Make Corr Peaks"
	Button a2k1d_btn_corr_layers,pos={442,480},size={98,22},proc=a2k1d_btn_make_corr_layers,title="Make Corr Layers"

	Button a2k1d_btn_abort,pos={336,506},size={204,22},proc=a2k1d_btn_abort,title="Abort"
	Button a2k1d_btn_help,pos={336,532},size={98,22},proc=a2k1d_btn_help,title="Help"
	Button a2k1d_btn_close,pos={442,532},size={98,22},proc=a2k1d_btn_close,title="Close"

	// --- Bottom: Plot / Visualization ---

	// Row 1: peak plots | kVary | stack
	Button a2k1d_btn_plot_peaks,pos={12,580},size={90,22},proc=a2k1d_btn_plot_peaks_err,title="Plot Peaks"
	Button a2k1d_btn_plot_delta,pos={108,580},size={90,22},proc=a2k1d_btn_plot_delta_err,title="Plot Dk12"
	SetVariable a2k1d_sv_kvary,pos={210,582},size={108,19.80},title="kVary"
	SetVariable a2k1d_sv_kvary,limits={-1e+06,1e+06,0.001},value= root:ARPES_LJZ:A2K1D:a2k1d_kvary
	Button a2k1d_btn_plot_layers,pos={324,580},size={216,22},proc=a2k1d_btn_plot_layers_stack,title="Plot: stack layer_*_k_spec"

	// Row 2: color table | heatmap
	CheckBox a2k1d_ck_useCT,pos={12,608},size={72,18},title="GradColor"
	CheckBox a2k1d_ck_useCT,variable= root:ARPES_LJZ:A2K1D:a2k1d_useCT
	CheckBox a2k1d_ck_invCT,pos={88,608},size={52,18},title="Invert"
	CheckBox a2k1d_ck_invCT,variable= root:ARPES_LJZ:A2K1D:a2k1d_ctInvert
	TitleBox a2k1d_tb_ct_current,pos={144,608},size={88,18},title="CT: NeonClash",frame=0
	Button a2k1d_btn_browse_ct,pos={236,606},size={38,20},proc=a2k1d_btn_open_ct_browser,title="..."
	Button a2k1d_btn_plot_heat,pos={282,604},size={258,24},proc=a2k1d_btn_plot_layers_heatmap,title="Plot: 2D Heatmap"

	// Row 3: heatmap axis params
	SetVariable a2k1d_sv_hmY0,pos={12,634},size={116,19.80},title="HM y0"
	SetVariable a2k1d_sv_hmY0,limits={-1e+09,1e+09,0.01},value= root:ARPES_LJZ:A2K1D:a2k1d_hmY0
	SetVariable a2k1d_sv_hmDY,pos={132,634},size={116,19.80},title="HM dY"
	SetVariable a2k1d_sv_hmDY,limits={-1e+09,1e+09,0.01},value= root:ARPES_LJZ:A2K1D:a2k1d_hmDY
	PopupMenu a2k1d_pm_hmUnit,pos={252,634},size={152,20.40},proc=a2k1d_pm_hm_unit_proc,title="HM Unit"
	PopupMenu a2k1d_pm_hmUnit,mode=3,popvalue="Fluence(uJ/cm^2)",value= #"\"Delay(ps);Temperature(K);Fluence(uJ/cm^2);Frame Index\""
	SetVariable a2k1d_sv_hmMul,pos={408,634},size={132,19.80},title="HM mul"
	SetVariable a2k1d_sv_hmMul,limits={-1e+09,1e+09,0.0001},value= root:ARPES_LJZ:A2K1D:a2k1d_hmYMul

EndMacro





//============================================================
// Core (public API) REWRITTEN
// Y-Value Transformation: Angle -> k
//============================================================
Function LJZ_A2K1D_Run(srcPathStr, baseName, degPerPix, thetaOffset, hv, workFunc, energyE, kShift, LC, outN)
    String srcPathStr
    String baseName
    Variable degPerPix, thetaOffset, hv, workFunc, energyE, kShift, LC, outN

    Wave/Z src = $srcPathStr
    if (!WaveExists(src))
        DoAlert 0, "A2K1D: src wave not found."
        return -1
    endif

    // -------- SAFETY CHECKS (same style as Spectra Interp) --------
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
    // ------------------------------------------------------------

    // --- output goes next to source wave ---
    String df0 = GetDataFolder(1)
    String outDF = GetWavesDataFolder(src, 1)
    if (strlen(outDF) == 0)
        outDF = "root:"
    endif

    // 1) Calculate Kinetic Energy (do BEFORE SetDataFolder, so early return is clean)
    Variable Ek = hv + energyE - workFunc
    if (numtype(Ek) != 0 || Ek <= 0)
        DoAlert 0, "A2K1D: Ek = hv + EnergyE - WorkFunc must be > 0."
        return -1
    endif

    SetDataFolder $outDF

    Variable constantV = 0.5118
    Variable unitFactor = 1
    if (LC != 0)
        unitFactor = LC / pi
    endif

    Variable A = constantV * sqrt(Ek) * unitFactor

    // 2) Prepare Output Wave (clone src)
    String destName = baseName + "_k"
    Duplicate/O src, $destName
    Wave dest = $destName

    // 3) Transform
    Variable scale = (degPerPix == 0) ? 1 : degPerPix
    dest = A * sin( (src * scale + thetaOffset) * pi/180 ) - kShift

    // 4) Units
    if (LC == 0)
        SetScale d, 0, 0, "Å\\S-1", dest
    else
        SetScale d, 0, 0, "pi/a", dest
    endif

    // 5) Note
    Note/K dest
    String noteStr = ""
    noteStr += "A2K1D Value Transform (LJZ)\r"
    noteStr += "srcPath=" + srcPathStr + "\r"
    noteStr += "degPerPix (Multiplier)=" + num2str(scale) + "\r"
    noteStr += "thetaOffset=" + num2str(thetaOffset) + "\r"
    noteStr += "hv=" + num2str(hv) + "\r"
    noteStr += "Ek=" + num2str(Ek) + "\r"
    noteStr += "kShift=" + num2str(kShift) + "\r"
    Note dest, noteStr

    // 6) Show optional
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

    Printf "A2K1D Transformed: %s -> %s (Ek=%.2f)\r", NameOfWave(src), destName, Ek
    SetDataFolder df0
    return 0
End


//============================================================
// Sigma transform (error propagation)
// Given: peakAngleWave (angleRaw) and sigmaAngleWave (sigma in same raw units)
// Output: sigma_k wave (same X as sigma wave), named baseName+"_k"
//============================================================
Function LJZ_A2K1D_Run_Sigma(peakPathStr, sigmaPathStr, baseName, degPerPix, thetaOffset, hv, workFunc, energyE, kShift, LC)
    String peakPathStr, sigmaPathStr
    String baseName
    Variable degPerPix, thetaOffset, hv, workFunc, energyE, kShift, LC

    Wave/Z wPeak = $peakPathStr
    Wave/Z wSig  = $sigmaPathStr
    if (!WaveExists(wPeak) || !WaveExists(wSig))
        Printf "A2K1D Sigma: missing peak or sigma wave. peak=%s sigma=%s\r", peakPathStr, sigmaPathStr
        return -1
    endif

    // numeric + 1D
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

    // output next to sigma wave (or peak wave; choose sigma as anchor)
    String df0 = GetDataFolder(1)
    String outDF = GetWavesDataFolder(wSig, 1)
    if (strlen(outDF)==0)
        outDF="root:"
    endif
    SetDataFolder $outDF

    Variable Ek = hv + energyE - workFunc
    if (numtype(Ek)!=0 || Ek<=0)
        Printf "A2K1D Sigma: Ek must be >0.\r"
        SetDataFolder df0
        return -1
    endif

    Variable constantV = 0.5118
    Variable unitFactor = 1
    if (LC != 0)
        unitFactor = LC / pi
    endif
    Variable A = constantV * sqrt(Ek) * unitFactor

    // IMPORTANT: derivative uses scale
    Variable scale = (degPerPix == 0) ? 1 : degPerPix
    Variable dth_draw = scale * pi/180.0

    String destName = baseName + "_k"
    Duplicate/O wSig, $destName
    Wave dest = $destName

    // theta(rad) = (peakRaw*scale + thetaOffset) * pi/180
    // sigma_k = |A*cos(theta)*dtheta/draw| * sigma_raw
    dest = abs( A * cos( (wPeak * scale + thetaOffset) * pi/180.0 ) * dth_draw ) * wSig

    // units
    if (LC == 0)
        SetScale d, 0, 0, "Å\\S-1", dest
    else
        SetScale d, 0, 0, "pi/a", dest
    endif

    Note/K dest
    String noteStr=""
    noteStr += "A2K1D Sigma Transform (LJZ)\r"
    noteStr += "peak=" + peakPathStr + "\r"
    noteStr += "sigma=" + sigmaPathStr + "\r"
    noteStr += "scale=" + num2str(scale) + "\r"
    noteStr += "thetaOffset=" + num2str(thetaOffset) + "\r"
    noteStr += "Ek=" + num2str(Ek) + "\r"
    Note dest, noteStr

    SetDataFolder df0
    return 0
End

Static Function a2k1d_angle_to_k(angle, degPerPix, thetaOffset, hv, workFunc, energyE, kShift, LC)
    Variable angle, degPerPix, thetaOffset, hv, workFunc, energyE, kShift, LC

    Variable Ek = hv + energyE - workFunc
    if (numtype(Ek) != 0 || Ek <= 0)
        return NaN
    endif

    Variable scale = (degPerPix == 0) ? 1 : degPerPix
    Variable constantV = 0.5118
    Variable unitFactor = 1
    if (LC != 0)
        unitFactor = LC / pi
    endif

    Variable A = constantV * sqrt(Ek) * unitFactor
    return A * sin((angle * scale + thetaOffset) * pi / 180) - kShift
End

Static Function a2k1d_sigma_angle_to_k(angle, sigma_angle, degPerPix, thetaOffset, hv, workFunc, energyE, LC)
    Variable angle, sigma_angle, degPerPix, thetaOffset, hv, workFunc, energyE, LC

    if (numtype(sigma_angle) != 0 || sigma_angle < 0)
        return NaN
    endif

    Variable Ek = hv + energyE - workFunc
    if (numtype(Ek) != 0 || Ek <= 0)
        return NaN
    endif

    Variable scale = (degPerPix == 0) ? 1 : degPerPix
    Variable constantV = 0.5118
    Variable unitFactor = 1
    if (LC != 0)
        unitFactor = LC / pi
    endif

    Variable A = constantV * sqrt(Ek) * unitFactor
    return abs(A * cos((angle * scale + thetaOffset) * pi / 180) * scale * pi / 180) * sigma_angle
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

    NVAR/Z degPerPix = root:ARPES_LJZ:A2K1D:a2k1d_degPerPix
    NVAR/Z thetaOffset = root:ARPES_LJZ:A2K1D:a2k1d_thetaOffset
    NVAR/Z hv = root:ARPES_LJZ:A2K1D:a2k1d_hv
    NVAR/Z workFunc = root:ARPES_LJZ:A2K1D:a2k1d_workFunc
    NVAR/Z energyE = root:ARPES_LJZ:A2K1D:a2k1d_energyE
    NVAR/Z kShift = root:ARPES_LJZ:A2K1D:a2k1d_kShift
    NVAR/Z LC = root:ARPES_LJZ:A2K1D:a2k1d_LC

    if (!NVAR_Exists(degPerPix) || !NVAR_Exists(thetaOffset) || !NVAR_Exists(hv) || !NVAR_Exists(workFunc) || !NVAR_Exists(energyE) || !NVAR_Exists(kShift) || !NVAR_Exists(LC))
        DoAlert 0, "A2K1D LongTable: required ATKT panel parameters are missing."
        return -1
    endif

    Variable Ek = hv + energyE - workFunc
    if (numtype(Ek) != 0 || Ek <= 0)
        DoAlert 0, "A2K1D LongTable: Ek = hv + EnergyE - WorkFunc must be > 0."
        return -1
    endif

    Variable i, angleV, kV, sigmaV
    Variable converted = 0
    Variable skipped = 0
    Variable failed = 0
    Variable scale = (degPerPix == 0) ? 1 : degPerPix

    for (i = 0; i < nRows; i += 1)
        angleV = wAngle[i]
        if (numtype(angleV) != 0)
            wK[i] = NaN
            wSigmaK[i] = NaN
            skipped += 1
            continue
        endif

        kV = a2k1d_angle_to_k(angleV, degPerPix, thetaOffset, hv, workFunc, energyE, kShift, LC)
        if (numtype(kV) != 0)
            wK[i] = NaN
            wSigmaK[i] = NaN
            failed += 1
            continue
        endif

        wK[i] = kV
        converted += 1

        if (hasSigmaAngle)
            sigmaV = a2k1d_sigma_angle_to_k(angleV, wSigmaAngle[i], degPerPix, thetaOffset, hv, workFunc, energyE, LC)
            wSigmaK[i] = sigmaV
        else
            wSigmaK[i] = NaN
        endif
    endfor

    Note/K wK
    String noteK = ""
    noteK += "A2K1D LongTable PeakAngle->PeakK\r"
    noteK += "degPerPix=" + num2str(degPerPix) + "\r"
    noteK += "scale=" + num2str(scale) + "\r"
    noteK += "thetaOffset=" + num2str(thetaOffset) + "\r"
    noteK += "hv=" + num2str(hv) + "\r"
    noteK += "workFunc=" + num2str(workFunc) + "\r"
    noteK += "energyE=" + num2str(energyE) + "\r"
    noteK += "kShift=" + num2str(kShift) + "\r"
    noteK += "LC=" + num2str(LC) + "\r"
    noteK += "Ek=" + num2str(Ek) + "\r"
    noteK += "formulaVersion=LJZ_A2K1D_Run_equivalent_v1\r"
    Note wK, noteK

    Note/K wSigmaK
    String noteSigma = ""
    noteSigma += "A2K1D LongTable SigmaAngle->SigmaK\r"
    noteSigma += "degPerPix=" + num2str(degPerPix) + "\r"
    noteSigma += "scale=" + num2str(scale) + "\r"
    noteSigma += "thetaOffset=" + num2str(thetaOffset) + "\r"
    noteSigma += "hv=" + num2str(hv) + "\r"
    noteSigma += "workFunc=" + num2str(workFunc) + "\r"
    noteSigma += "energyE=" + num2str(energyE) + "\r"
    noteSigma += "kShift=" + num2str(kShift) + "\r"
    noteSigma += "LC=" + num2str(LC) + "\r"
    noteSigma += "Ek=" + num2str(Ek) + "\r"
    noteSigma += "formulaVersion=LJZ_A2K1D_RunSigma_equivalent_v1\r"
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
Function LJZ_Spectra_Interp_Run(srcPathStr, baseName, thetaOffset, hv, workFunc, energyE, kShift, LC)
    String srcPathStr, baseName
    Variable thetaOffset, hv, workFunc, energyE, kShift, LC

    Wave/Z src = $srcPathStr
    if (!WaveExists(src))
        DoAlert 0, "A2K1D: src wave not found: " + srcPathStr
        return -1
    endif
    
    // --- SAFETY CHECKS (CORRECTED) ---
    // 1. Check if wave is Text. 
    // In Igor, WaveType returns 0 for Text, non-zero for Numeric.
    if (WaveType(src) == 0)
        Printf "Skipping '%s': It is a TEXT wave.\r", NameOfWave(src)
        return -1
    endif
    
    // 2. Check Dimensions (Must be 1D)
    if (WaveDims(src) != 1)
        Printf "Skipping '%s': It is not a 1D wave (Dims=%g).\r", NameOfWave(src), WaveDims(src)
        return -1
    endif
    
    // 3. Check Points (Must not be empty)
    if (DimSize(src, 0) <= 1)
        Printf "Skipping '%s': Wave has insufficient points (N=%g).\r", NameOfWave(src), DimSize(src, 0)
        return -1
    endif
    // ---------------------------------------------

    // --- output goes next to source wave ---
    String df0 = GetDataFolder(1)
    String outDF = GetWavesDataFolder(src, 1)
    if (strlen(outDF) == 0)
        outDF = "root:" 
    endif
    SetDataFolder $outDF

    // 1. Calculate Kinetic Energy & Constants
    Variable Ek = hv + energyE - workFunc
    if (numtype(Ek) != 0 || Ek <= 0)
        SetDataFolder df0
        Printf "Error for '%s': Ek (%.2f) must be > 0. Check hv, WorkFunc, EnergyE.\r", NameOfWave(src), Ek
        return -1
    endif

    Variable constantV = 0.5118
    Variable unitFactor = 1 // Default A^-1
    String unitStr = "A\\S-1"
    
    if (LC != 0)
        unitFactor = LC / pi
        unitStr = "pi/a"
    endif

    // Pre-factor for k = C * sin(theta)
    Variable C = constantV * sqrt(Ek) * unitFactor

    // 2. Determine K-Range from Source Angle Range
    Variable thetaMin = LeftX(src)
    Variable thetaMax = RightX(src)
    
    // Convert edges to k
    Variable k_start = C * sin((thetaMin + thetaOffset) * pi/180) - kShift
    Variable k_end   = C * sin((thetaMax + thetaOffset) * pi/180) - kShift
//   Printf "DBG %s | thetaMin=%.6g thetaMax=%.6g thetaOffset=%.6g\r", NameOfWave(src), thetaMin, thetaMax, thetaOffset
//Printf "DBG hv=%.6g workFunc=%.6g energyE=%.6g => Ek=%.6g\r", hv, workFunc, energyE, Ek
//Printf "DBG LC=%.6g unitFactor=%.6g C=%.6g\r", LC, unitFactor, C
//Printf "DBG k_start=%.9g k_end=%.9g (span=%.9g)\r", k_start, k_end, abs(k_end-k_start)
 
    if (abs(k_start - k_end) < 1e-9)
        SetDataFolder df0
        Printf "Error for '%s': Calculated k-range is near zero. Check input scaling.\r", NameOfWave(src)
        return -1
    endif

    // 3. Create Destination Wave (Linear k grid)
    Variable nPoints = DimSize(src, 0)
    String destName = baseName + "_k_spec"
    
    Duplicate/O src, $destName
    Wave dest = $destName
    
    Variable kLo = min(k_start, k_end)
	Variable kHi = max(k_start, k_end)
	SetScale/I x, kLo, kHi, unitStr, dest

// 4. Interpolation Logic  (with angle clamp)
// 注意：LeftX/RightX 可能出现反向刻度，因此用 min/max 构造角度合法域
Variable angLo = min(LeftX(src), RightX(src))
Variable angHi = max(LeftX(src), RightX(src))

// 反解得到 angle（deg），再 clamp 到 [angLo, angHi]，避免外推/NaN
dest = src( a2k1d_clamp( (asin( max(-1, min(1, (x + kShift)/C )) ) * 180 / pi) - thetaOffset, angLo, angHi ) )

    // 5. Clean up units and notes
    SetScale d, 0, 0, WaveUnits(src, -1), dest 
    
    Note/K dest
    String noteStr = ""
    noteStr += "A2K1D Spectra Interpolation (LJZ)\r"
    noteStr += "Method: Linear k-grid generation -> Inverse Angle Mapping -> Interpolation\r"
    noteStr += "Source=" + srcPathStr + "\r"
    noteStr += "ThetaOffset=" + num2str(thetaOffset) + "\r"
    noteStr += "Ek=" + num2str(Ek) + "\r"
    noteStr += "k_range=" + num2str(kLo) + " to " + num2str(kHi) + "\r"
    Note dest, noteStr

    // 6. Display (single fixed window; optional)
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
    return (StringMatch(wn, "peak1k") || StringMatch(wn, "peak2k") || StringMatch(wn, "peak3k"))
End

Function a2k1d_is_sigmap_name(wn)
    String wn
    return (StringMatch(wn, "sigmap1k") || StringMatch(wn, "sigmap2k") || StringMatch(wn, "sigmap3k"))
End


Function a2k1d_is_peak_sigma_name(wn)
    String wn
    if (StringMatch(wn, "peak1k") || StringMatch(wn, "peak2k") || StringMatch(wn, "peak3k"))
        return 1
    endif
    if (StringMatch(wn, "sigmap1k") || StringMatch(wn, "sigmap2k") || StringMatch(wn, "sigmap3k"))
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
        // 修改通配符，只初步筛选以 layer_show_ 开头的波形
        listAll = WaveList("layer_show_*", ";", "DIMS:1")
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
        if (a2k1d_is_peak_sigma_name(wn))
            out += wp + ";"
        endif
    endfor

    return out
End


Function a2k1d_btn_batch_layers_interp(ctrlName) : ButtonControl
    String ctrlName

    SVAR a2k1d_baseDF      = root:ARPES_LJZ:A2K1D:a2k1d_baseDF
    NVAR a2k1d_recursive   = root:ARPES_LJZ:A2K1D:a2k1d_recursive

    NVAR a2k1d_thetaOffset = root:ARPES_LJZ:A2K1D:a2k1d_thetaOffset
    NVAR a2k1d_hv          = root:ARPES_LJZ:A2K1D:a2k1d_hv
    NVAR a2k1d_workFunc    = root:ARPES_LJZ:A2K1D:a2k1d_workFunc
    NVAR a2k1d_energyE     = root:ARPES_LJZ:A2K1D:a2k1d_energyE
    NVAR a2k1d_kShift      = root:ARPES_LJZ:A2K1D:a2k1d_kShift
    NVAR a2k1d_LC          = root:ARPES_LJZ:A2K1D:a2k1d_LC

    NVAR a2k1d_abortFlag   = root:ARPES_LJZ:A2K1D:a2k1d_abortFlag
    NVAR a2k1d_showGraph   = root:ARPES_LJZ:A2K1D:a2k1d_showGraph

    a2k1d_abortFlag = 0

    // ✅ 只收集原始 layer_show_<int>，不会包含 *_k_spec
    String list = a2k1d_collect_layers(a2k1d_baseDF, a2k1d_recursive)
    Variable n = ItemsInList(list, ";")
    if (n <= 0)
        DoAlert 0, "Batch layer interp: no raw layer_show_<int> waves under " + a2k1d_baseDF
        return 0
    endif

    // batch: silent
    Variable oldShow = a2k1d_showGraph
    a2k1d_showGraph = 0

    DoWindow A2K1D_LJZ_P
    if (V_flag)
        TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title="Status: batch layer interp..."
    endif

    Variable i, ok=0, fail=0
    for (i=0; i<n; i+=1)
        if (a2k1d_abortFlag)
            break
        endif

        String wp = StringFromList(i, list, ";")
        Wave/Z w = $wp
        if (!WaveExists(w))
            fail += 1
            continue
        endif

        // ✅ 再保险：如果有人手动改名成 *_k_spec，也直接拒绝
        String wn = NameOfWave(w)
        if (a2k1d_is_result_wave_name(wn))
            fail += 1
            continue
        endif
        if (!a2k1d_is_layer_int_name(wn))
            fail += 1
            continue
        endif

        // 输出 baseName = 原始名（或你也可以用 a2k1d_baseName，但这里按 raw 名更稳）
        Variable rc = LJZ_Spectra_Interp_Run(wp, wn, a2k1d_thetaOffset, a2k1d_hv, a2k1d_workFunc, a2k1d_energyE, a2k1d_kShift, a2k1d_LC)
        if (rc == 0)
            ok += 1
        else
            fail += 1
        endif

        DoWindow A2K1D_LJZ_P
        if (V_flag)
            TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title=("Batch layer: " + num2str(i+1) + "/" + num2str(n))
        endif
    endfor

    a2k1d_showGraph = oldShow

    DoWindow A2K1D_LJZ_P
    if (V_flag)
        if (a2k1d_abortFlag)
            TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title=("Status: aborted | ok=" + num2str(ok) + ", fail=" + num2str(fail))
        else
            TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title=("Status: done | ok=" + num2str(ok) + ", fail=" + num2str(fail))
        endif
    endif

    Printf "Batch layer interp finished: ok=%d fail=%d total=%d\r", ok, fail, n
    return 0
End




Function a2k1d_btn_batch_peaks_valuetrans(ctrlName) : ButtonControl
    String ctrlName

    SVAR a2k1d_baseDF      = root:ARPES_LJZ:A2K1D:a2k1d_baseDF
    NVAR a2k1d_recursive   = root:ARPES_LJZ:A2K1D:a2k1d_recursive

    NVAR a2k1d_degPerPix   = root:ARPES_LJZ:A2K1D:a2k1d_degPerPix
    NVAR a2k1d_thetaOffset = root:ARPES_LJZ:A2K1D:a2k1d_thetaOffset
    NVAR a2k1d_hv          = root:ARPES_LJZ:A2K1D:a2k1d_hv
    NVAR a2k1d_workFunc    = root:ARPES_LJZ:A2K1D:a2k1d_workFunc
    NVAR a2k1d_energyE     = root:ARPES_LJZ:A2K1D:a2k1d_energyE
    NVAR a2k1d_kShift      = root:ARPES_LJZ:A2K1D:a2k1d_kShift
    NVAR a2k1d_LC          = root:ARPES_LJZ:A2K1D:a2k1d_LC
    NVAR a2k1d_outN        = root:ARPES_LJZ:A2K1D:a2k1d_outN

    NVAR a2k1d_abortFlag   = root:ARPES_LJZ:A2K1D:a2k1d_abortFlag
    NVAR a2k1d_showGraph   = root:ARPES_LJZ:A2K1D:a2k1d_showGraph

    a2k1d_abortFlag = 0

    String list = a2k1d_collect_peak_sigma(a2k1d_baseDF, a2k1d_recursive)
    Variable n = ItemsInList(list, ";")
    if (n <= 0)
        DoAlert 0, "Batch peak/sigma: no peak1k/2k/3k or sigmap1k/2k/3k found under " + a2k1d_baseDF
        return 0
    endif

    // batch: silent (no windows)
    Variable oldShow = a2k1d_showGraph
    a2k1d_showGraph = 0

    DoWindow A2K1D_LJZ_P
    if (V_flag)
        TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title="Status: batch peak -> k, sigma -> k, delta -> k..."
    endif

    // -------- Pass 0: collect unique folders (outDF list) --------
    String folderList = ""
    Variable i
    for (i=0; i<n; i+=1)
        String wp0 = StringFromList(i, list, ";")
        if (strlen(wp0) == 0)
            continue
        endif

        Wave/Z w0 = $wp0
        if (!WaveExists(w0))
            continue
        endif

        String outDF0 = GetWavesDataFolder(w0, 1)
        if (strlen(outDF0)==0)
            outDF0 = "root:"
        endif

        if (WhichListItem(outDF0, folderList, ";") == -1)
            folderList += outDF0 + ";"
        endif
    endfor

    // -------- Pass 1: ONLY transform peaks (value -> k) --------
    Variable okP=0, failP=0, skipP=0
    for (i=0; i<n; i+=1)
        if (a2k1d_abortFlag)
            break
        endif

        String wp = StringFromList(i, list, ";")
        if (strlen(wp) == 0)
            continue
        endif

        Wave/Z w = $wp
        if (!WaveExists(w))
            failP += 1
            continue
        endif

        String wn = NameOfWave(w)

        // only peaks; sigmas are handled later by propagation
        if (!a2k1d_is_peak_name(wn))
            continue
        endif

        Variable rc = LJZ_A2K1D_Run(wp, wn, a2k1d_degPerPix, a2k1d_thetaOffset, a2k1d_hv, a2k1d_workFunc, a2k1d_energyE, a2k1d_kShift, a2k1d_LC, a2k1d_outN)
        if (rc == 0)
            okP += 1
        else
            failP += 1
        endif

        DoWindow A2K1D_LJZ_P
        if (V_flag)
            TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title=("Batch peaks: " + num2str(i+1) + "/" + num2str(n))
        endif
    endfor

    // -------- Pass 2: sigma propagation + delta per folder --------
    Variable okS=0, failS=0, skipS=0
    Variable okD=0, failD=0, skipD=0
    Variable okSD=0, failSD=0, skipSD=0

    Variable nf = ItemsInList(folderList, ";")
    for (i=0; i<nf; i+=1)
        if (a2k1d_abortFlag)
            break
        endif

        String fdf = StringFromList(i, folderList, ";")
        if (strlen(fdf) == 0)
            continue
        endif

        // ---- sigma propagation: sigmap1k -> sigmap1k_k
        if (WaveExists($(fdf+"peak1k")) && WaveExists($(fdf+"sigmap1k")))
            Variable rc1 = LJZ_A2K1D_Run_Sigma(fdf+"peak1k", fdf+"sigmap1k", "sigmap1k", a2k1d_degPerPix, a2k1d_thetaOffset, a2k1d_hv, a2k1d_workFunc, a2k1d_energyE, a2k1d_kShift, a2k1d_LC)
            if (rc1 == 0)
                okS += 1
            else
                failS += 1
            endif
        else
            skipS += 1
        endif

        // ---- sigma propagation: sigmap2k -> sigmap2k_k
        if (WaveExists($(fdf+"peak2k")) && WaveExists($(fdf+"sigmap2k")))
            Variable rc2 = LJZ_A2K1D_Run_Sigma(fdf+"peak2k", fdf+"sigmap2k", "sigmap2k", a2k1d_degPerPix, a2k1d_thetaOffset, a2k1d_hv, a2k1d_workFunc, a2k1d_energyE, a2k1d_kShift, a2k1d_LC)
            if (rc2 == 0)
                okS += 1
            else
                failS += 1
            endif
        else
            skipS += 1
        endif

        // ---- sigma propagation: sigmap3k -> sigmap3k_k
        if (WaveExists($(fdf+"peak3k")) && WaveExists($(fdf+"sigmap3k")))
            Variable rc3 = LJZ_A2K1D_Run_Sigma(fdf+"peak3k", fdf+"sigmap3k", "sigmap3k", a2k1d_degPerPix, a2k1d_thetaOffset, a2k1d_hv, a2k1d_workFunc, a2k1d_energyE, a2k1d_kShift, a2k1d_LC)
            if (rc3 == 0)
                okS += 1
            else
                failS += 1
            endif
        else
            skipS += 1
        endif

        // ---- delta k: deltak12_k = abs(peak1k_k - peak2k_k)
        if (WaveExists($(fdf+"peak1k_k")) && WaveExists($(fdf+"peak2k_k")))
            Wave/Z wP1K = $(fdf+"peak1k_k")
            Wave/Z wP2K = $(fdf+"peak2k_k")

            if (WaveExists(wP1K) && WaveExists(wP2K) && WaveDims(wP1K)==1 && WaveDims(wP2K)==1 && DimSize(wP1K,0)==DimSize(wP2K,0))
                Duplicate/O wP1K, $(fdf+"deltak12_k")
                Wave wDeltaK = $(fdf+"deltak12_k")

                wDeltaK = abs(wP1K - wP2K)

                SetScale/P x, DimOffset(wP1K,0), DimDelta(wP1K,0), WaveUnits(wP1K,0), wDeltaK
                SetScale d, 0, 0, WaveUnits(wP1K,-1), wDeltaK

                Note/K wDeltaK
                String noteDelta = ""
                noteDelta += "A2K1D DeltaK (LJZ)\r"
                noteDelta += "wave1=" + fdf + "peak1k_k\r"
                noteDelta += "wave2=" + fdf + "peak2k_k\r"
                noteDelta += "formula=abs(peak1k_k-peak2k_k)\r"
                Note wDeltaK, noteDelta

                okD += 1
            else
                failD += 1
            endif
        else
            skipD += 1
        endif

        // ---- sigma(delta k): sigmadeltak12_k = sqrt(sigmap1k_k^2 + sigmap2k_k^2)
        if (WaveExists($(fdf+"sigmap1k_k")) && WaveExists($(fdf+"sigmap2k_k")))
            Wave/Z wS1K = $(fdf+"sigmap1k_k")
            Wave/Z wS2K = $(fdf+"sigmap2k_k")

            if (WaveExists(wS1K) && WaveExists(wS2K) && WaveDims(wS1K)==1 && WaveDims(wS2K)==1 && DimSize(wS1K,0)==DimSize(wS2K,0))
                Duplicate/O wS1K, $(fdf+"sigmadeltak12_k")
                Wave wSigmaDeltaK = $(fdf+"sigmadeltak12_k")

                wSigmaDeltaK = sqrt(wS1K^2 + wS2K^2)

                SetScale/P x, DimOffset(wS1K,0), DimDelta(wS1K,0), WaveUnits(wS1K,0), wSigmaDeltaK
                SetScale d, 0, 0, WaveUnits(wS1K,-1), wSigmaDeltaK

                Note/K wSigmaDeltaK
                String noteSigmaDelta = ""
                noteSigmaDelta += "A2K1D SigmaDeltaK (LJZ)\r"
                noteSigmaDelta += "sigma1=" + fdf + "sigmap1k_k\r"
                noteSigmaDelta += "sigma2=" + fdf + "sigmap2k_k\r"
                noteSigmaDelta += "formula=sqrt(sigmap1k_k^2+sigmap2k_k^2)\r"
                Note wSigmaDeltaK, noteSigmaDelta

                okSD += 1
            else
                failSD += 1
            endif
        else
            skipSD += 1
        endif

        DoWindow A2K1D_LJZ_P
        if (V_flag)
            TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title=("Batch sigma/delta: " + num2str(i+1) + "/" + num2str(nf))
        endif
    endfor

    a2k1d_showGraph = oldShow

    DoWindow A2K1D_LJZ_P
    if (V_flag)
        if (a2k1d_abortFlag)
            TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title=("Status: aborted | peaks(ok/skip/fail)=" + num2str(okP)+"/"+num2str(skipP)+"/"+num2str(failP) + " | sigma(ok/skip/fail)=" + num2str(okS)+"/"+num2str(skipS)+"/"+num2str(failS) + " | delta(ok/skip/fail)=" + num2str(okD)+"/"+num2str(skipD)+"/"+num2str(failD) + " | sigmadelta(ok/skip/fail)=" + num2str(okSD)+"/"+num2str(skipSD)+"/"+num2str(failSD))
        else
            TitleBox a2k1d_runstat, win=A2K1D_LJZ_P, title=("Status: done | peaks(ok/skip/fail)=" + num2str(okP)+"/"+num2str(skipP)+"/"+num2str(failP) + " | sigma(ok/skip/fail)=" + num2str(okS)+"/"+num2str(skipS)+"/"+num2str(failS) + " | delta(ok/skip/fail)=" + num2str(okD)+"/"+num2str(skipD)+"/"+num2str(failD) + " | sigmadelta(ok/skip/fail)=" + num2str(okSD)+"/"+num2str(skipSD)+"/"+num2str(failSD))
        endif
    endif

    Printf "Batch peaks->k: ok=%d skip=%d fail=%d | sigma->k: ok=%d skip=%d fail=%d | delta->k: ok=%d skip=%d fail=%d | sigmadelta->k: ok=%d skip=%d fail=%d | folders=%d\r", okP, skipP, failP, okS, skipS, failS, okD, skipD, failD, okSD, skipSD, failSD, nf

    return 0
End


Function a2k1d_is_layer_int_name(wn)
    String wn
    
    // 1. 必须以 "layer_show_" 开头
    if (!StringMatch(wn, "layer_show_*"))
        return 0
    endif
    
    // 2. 获取 "layer_show_" 之后的部分
    // "layer_show_" 长度为 11
    if (strlen(wn) <= 11)
        return 0
    endif
    String sNum = wn[11, strlen(wn)-1]
    
    // 3. 严格检查：后缀中是否包含任何“非数字”字符？
    // 如果包含下划线（如 _k_spec）或字母，则返回失败
    if (StringMatch(sNum, "*[!0-9]*")) 
        return 0 
    endif

    return 1
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
    out = a2k1d_strip_suffix_once(out, "_k_spec")
    out = a2k1d_strip_suffix_once(out, "_k")
    return out
End

//============================================================
// Plot Layers Stack (Final + Lifted Markers) - FIXED
// 修复：标记点波形不再使用全局固定名称，而是加上 BaseName 前缀，防止多图覆盖
//============================================================
Function a2k1d_btn_plot_layers_stack(ctrlName) : ButtonControl
    String ctrlName

    SVAR a2k1d_baseDF    = root:ARPES_LJZ:A2K1D:a2k1d_baseDF
    NVAR a2k1d_recursive = root:ARPES_LJZ:A2K1D:a2k1d_recursive
    NVAR a2k1d_kvary     = root:ARPES_LJZ:A2K1D:a2k1d_kvary
    SVAR a2k1d_baseName  = root:ARPES_LJZ:A2K1D:a2k1d_baseName
    
    // Gradient Color Params
    NVAR a2k1d_useCT      = root:ARPES_LJZ:A2K1D:a2k1d_useCT
    NVAR a2k1d_ctInvert   = root:ARPES_LJZ:A2K1D:a2k1d_ctInvert
    SVAR a2k1d_ctPickName = root:ARPES_LJZ:A2K1D:a2k1d_ctPickName

    String base = a2k1d_df_with_colon(a2k1d_baseDF)
    if (!a2k1d_df_exists(base))
        Abort "Plot layers: baseDF not found."
    endif

    // 1. Collect Waves
    String rawList = a2k1d_collect_layers(base, a2k1d_recursive)
    Variable n = ItemsInList(rawList, ";")
    if (n <= 0)
        Abort "Error: No layer waves found."
    endif

    // 2. Window Setup & Unique Prefix
    String wname
    String prefix = "Default" // 默认前缀
    if (strlen(a2k1d_baseName) > 0)
        wname = a2k1d_baseName + "_LayerStack_kSpec"
        prefix = a2k1d_baseName
    else
        wname = "A2K1D_LayerStack_kSpec"
    endif
    DoWindow/K $wname 

    // 3. Build valid spectra list
    String listKS = ""
    Variable i
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

    Variable m = ItemsInList(listKS, ";")
    if (m <= 0)
        Abort "Error: No *_k_spec waves found."
    endif
    
    // 4. Find Peak Waves
    String p1_path = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "peak1k_k")
    String p2_path = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "peak2k_k")
    String p3_path = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "peak3k_k")

    Wave/Z wP1_k = $p1_path
    Wave/Z wP2_k = $p2_path
    Wave/Z wP3_k = $p3_path

    // 5. Prepare Marker Waves (FIXED: Added prefix to wave names)
    a2k1d_ensure_folder()
    String dispDF = "root:ARPES_LJZ:OUTPUT:A2K1D:"
    
    // 构建带前缀的唯一名称，例如: root:...:p4_Disp_P1_X
    String wnP1X = dispDF + prefix + "_Disp_P1_X"
    String wnP1Y = dispDF + prefix + "_Disp_P1_Y"
    String wnP2X = dispDF + prefix + "_Disp_P2_X"
    String wnP2Y = dispDF + prefix + "_Disp_P2_Y"
    String wnP3X = dispDF + prefix + "_Disp_P3_X"
    String wnP3Y = dispDF + prefix + "_Disp_P3_Y"

    Make/O/N=(m) $wnP1X/Wave=dwP1_X, $wnP1Y/Wave=dwP1_Y
    Make/O/N=(m) $wnP2X/Wave=dwP2_X, $wnP2Y/Wave=dwP2_Y
    Make/O/N=(m) $wnP3X/Wave=dwP3_X, $wnP3Y/Wave=dwP3_Y
    
    dwP1_X = NaN; dwP1_Y = NaN
    dwP2_X = NaN; dwP2_Y = NaN
    dwP3_X = NaN; dwP3_Y = NaN

    // 6. Plot Loop
String wp0 = StringFromList(0, listKS, ";")
Display/N=$wname $wp0
ModifyGraph/W=$wname mode=0
ModifyGraph/W=$wname mirror=2
ModifyGraph/W=$wname offset($NameOfWave($wp0))={0,0}
Label/W=$wname left "Intensity (a.u.)"
Label/W=$wname bottom "k\\B//\\M (Å\\S-1\\M)"

    Variable j, r16, g16, b16
    Variable layerIdx, kVal, intVal
    Variable lift 

    for (j=0; j<m; j+=1)
        String wpj = StringFromList(j, listKS, ";")
        Wave wj = $wpj 
        
        if (j > 0)
            AppendToGraph/W=$wname wj
        endif
        
        Variable currentOffset = j * a2k1d_kvary
        ModifyGraph/W=$wname offset($NameOfWave(wj)) = {0, currentOffset}

        if (a2k1d_useCT)
            Variable tt = (m<=1) ? 0 : (j/(m-1.0))
            a2k1d_ctluz_rgb16_at_t(a2k1d_ctPickName, tt, a2k1d_ctInvert, r16, g16, b16)
            ModifyGraph/W=$wname rgb($NameOfWave(wj)) = (r16, g16, b16)
        endif
        
        // --- Calculate Lift Amount ---
        lift = a2k1d_kvary*0.4

        // --- Calculate Markers ---
        layerIdx = a2k1d_get_layer_index(NameOfWave(wj))
        
        if (layerIdx >= 0)
            // Peak 1
            if (WaveExists(wP1_k) && layerIdx < DimSize(wP1_k, 0))
                kVal = wP1_k[layerIdx]
                if (numtype(kVal) == 0 && kVal >= min(LeftX(wj), RightX(wj)) && kVal <= max(LeftX(wj), RightX(wj)))
                     intVal = a2k1d_safe_y_at_x(wj, kVal)
                     if (numtype(intVal) == 0)
                         dwP1_X[j] = kVal
                         dwP1_Y[j] = intVal + currentOffset + lift
                     endif
                endif
            endif
            
            // Peak 2
            if (WaveExists(wP2_k) && layerIdx < DimSize(wP2_k, 0))
                kVal = wP2_k[layerIdx]
                if (numtype(kVal) == 0 && kVal >= min(LeftX(wj), RightX(wj)) && kVal <= max(LeftX(wj), RightX(wj)))
                     intVal = a2k1d_safe_y_at_x(wj, kVal)
                     if (numtype(intVal) == 0)
                         dwP2_X[j] = kVal
                         dwP2_Y[j] = intVal + currentOffset + lift
                     endif
                endif
            endif

            // Peak 3
            if (WaveExists(wP3_k) && layerIdx < DimSize(wP3_k, 0))
                kVal = wP3_k[layerIdx]
                if (numtype(kVal) == 0 && kVal >= min(LeftX(wj), RightX(wj)) && kVal <= max(LeftX(wj), RightX(wj)))
                     intVal = a2k1d_safe_y_at_x(wj, kVal)
                     if (numtype(intVal) == 0)
                         dwP3_X[j] = kVal
                         dwP3_Y[j] = intVal + currentOffset + lift
                     endif
                endif
            endif
        endif
    endfor

    // 7. Append Markers (FIXED: Use dynamic Trace Name)
    // 之前硬编码了 "Disp_P1_Y"，现在需要获取加上前缀后的真实波形名
    
    if (WaveExists(wP1_k))
        AppendToGraph/W=$wname dwP1_Y vs dwP1_X
        String trName1 = NameOfWave(dwP1_Y) 
        ModifyGraph/W=$wname mode($trName1)=3, marker($trName1)=19, msize($trName1)=2, rgb($trName1)=(0,0,0)
    endif
    if (WaveExists(wP2_k))
        AppendToGraph/W=$wname dwP2_Y vs dwP2_X
        String trName2 = NameOfWave(dwP2_Y)
        ModifyGraph/W=$wname mode($trName2)=3, marker($trName2)=17, msize($trName2)=2, rgb($trName2)=(65535,0,0)
    endif
    if (WaveExists(wP3_k))
        AppendToGraph/W=$wname dwP3_Y vs dwP3_X
        String trName3 = NameOfWave(dwP3_Y)
        ModifyGraph/W=$wname mode($trName3)=3, marker($trName3)=16, msize($trName3)=2, rgb($trName3)=(0,0,65535)
    endif
    //============================================================
    // 8) Smart X-axis clamp around peak region (NEW)
    //============================================================
    Variable kLoAuto, kHiAuto
    Variable okRange

    // marginFrac=0.25 表示左右各扩 25% 的 peak-span
    // minAbsMargin=0.03 是绝对最小扩展（单位同 k）
    okRange = a2k1d_peak_global_krange(wP1_k, wP2_k, wP3_k, m, 0.5, 0.03, kLoAuto, kHiAuto)

    if (okRange)
        SetAxis/W=$wname bottom kLoAuto, kHiAuto
    else
        // fallback: keep auto axis
        // SetAxis/A/W=$wname bottom
    endif

    //============================================================
    // 9) Smart Y-axis clamp based on intensity inside [kLoAuto, kHiAuto]
    //    (decouple from offset-driven autoscale)
    //============================================================
    if (okRange)   // 只有在 X-window 合法时才做
        Variable rawMin = NaN, rawMax = NaN
        Variable hasY = 0
        Variable jj

        for (jj=0; jj<m; jj+=1)
            String wpY = StringFromList(jj, listKS, ";")
            Wave/Z wY = $wpY
            if (!WaveExists(wY))
                continue
            endif

            // 只统计峰附近的窗口范围
            WaveStats/Q/R=(kLoAuto, kHiAuto) wY

            if (V_npnts <= 0)
                continue
            endif

            // 这里用窗口内 min/max（原始强度，未加offset）
            if (!hasY)
                rawMin = V_min
                rawMax = V_max
                hasY = 1
            else
                if (V_min < rawMin)
                    rawMin = V_min
                endif
                if (V_max > rawMax)
                    rawMax = V_max
                endif
            endif
        endfor

        if (hasY)
            // 给一点上下 margin（按强度跨度的比例）
            Variable spanY = rawMax - rawMin
            Variable yMargin = 0.08 * spanY
            if (yMargin < 1e-6)
                yMargin = 1e-6
            endif

            // 顶部要加上堆叠 offset + marker lift
            Variable yLo = rawMin - yMargin
            Variable yHi = rawMax + (m-1)*a2k1d_kvary + lift + yMargin

            SetAxis/W=$wname left yLo, yHi
        endif
    endif

    ModifyGraph/W=$wname tickUnit(bottom)=1, tickUnit(left)=1
    
    return 0
End

//============================================================
// Helper: Extract numeric index from layer name
// Robust version: Splits by "_" and finds the first number.
// Handles: "layer_14_k_spec", "layer_show_14_k_spec", etc.
//============================================================
Function a2k1d_get_layer_index(wn)
    String wn
    
    // 必须包含 layer
    if (StringMatch(wn, "*layer*") == 0)
        return -1
    endif
    
    // 按下划线拆分
    Variable n = ItemsInList(wn, "_")
    Variable i
    
    for (i=0; i<n; i+=1)
        String item = StringFromList(i, wn, "_")
        
        // 尝试转为数字
        Variable val = str2num(item)
        
        // 检查是否为有效数字 (NaN 表示转换失败)
        // 且为了防止匹配到 "layer" (如果layer被误转), 确保它是纯数字
        if (numtype(val) == 0)
            // 排除掉一些可能的非索引数字干扰，通常索引是整数
            // 这里直接返回找到的第一个有效数字
            return val
        endif
    endfor
    
    return -1 // 没找到数字
End

Function a2k1d_btn_plot_peaks_err(ctrlName) : ButtonControl
    String ctrlName

    SVAR a2k1d_baseDF    = root:ARPES_LJZ:A2K1D:a2k1d_baseDF
    NVAR a2k1d_recursive = root:ARPES_LJZ:A2K1D:a2k1d_recursive
    NVAR a2k1d_hmUnitMode = root:ARPES_LJZ:A2K1D:a2k1d_hmUnitMode
    SVAR a2k1d_baseName  = root:ARPES_LJZ:A2K1D:a2k1d_baseName
    NVAR a2k1d_LC        = root:ARPES_LJZ:A2K1D:a2k1d_LC

    String base = a2k1d_df_with_colon(a2k1d_baseDF)
    if (!a2k1d_df_exists(base))
        Abort "Plot peaks: baseDF not found."
    endif

    // Window name
    String wname
    if (strlen(a2k1d_baseName) > 0)
        wname = a2k1d_baseName + "_Peaks_k"
    else
        wname = "A2K1D_Peaks_k"
    endif
    DoWindow/K $wname

    // Find waves (full paths)
    String p1 = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "peak1k_k")
    String p2 = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "peak2k_k")
    String p3 = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "peak3k_k")

    String s1 = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "sigmap1k_k")
    String s2 = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "sigmap2k_k")
    String s3 = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "sigmap3k_k")

    // Checks
    if (strlen(p1)==0 || strlen(p2)==0 || strlen(p3)==0)
        Abort "Plot peaks: missing peak waves (1, 2, or 3)."
    endif
    if (strlen(s1)==0 || strlen(s2)==0 || strlen(s3)==0)
        Abort "Plot peaks: missing sigma waves (1, 2, or 3)."
    endif

    // Display
    // 注意：Display 后，图上的 Trace 名称默认是波的名字（不含路径）
    // 为了防止路径解析错误，这里建立 Wave 引用来获取准确名字
    Wave wP1 = $p1
    Wave wP2 = $p2
    Wave wP3 = $p3
    
String outDF = "root:ARPES_LJZ:OUTPUT:A2K1D:"
String axisPath
if (strlen(a2k1d_baseName) > 0)
    axisPath = outDF + a2k1d_baseName + "_AxisX"
else
    axisPath = outDF + "A2K1D_AxisX"
endif

Wave wAxis = a2k1d_make_axis_wave(DimSize(wP1,0), axisPath)

Display/N=$wname wP1 vs wAxis
AppendToGraph/W=$wname wP2 vs wAxis
AppendToGraph/W=$wname wP3 vs wAxis

ModifyGraph/W=$wname mirror=2
    
    // 设置线条颜色，便于区分
    ModifyGraph/W=$wname rgb($NameOfWave(wP1))=(0,0,0)          // Black
    ModifyGraph/W=$wname rgb($NameOfWave(wP2))=(65535,0,0)      // Red
    ModifyGraph/W=$wname rgb($NameOfWave(wP3))=(0,0,65535)      // Blue

    // Error bars
    // 【修复1】这里全部改用黑色 RGB=(0,0,0)，你原来的第三个是 Cyan，很难看清。
    // 使用 NameOfWave() 确保 Trace 名字匹配
    ErrorBars/W=$wname/RGB=(0,0,0) $NameOfWave(wP1) Y, wave=($s1, $s1)
    ErrorBars/W=$wname/RGB=(0,0,0) $NameOfWave(wP2) Y, wave=($s2, $s2)
    ErrorBars/W=$wname/RGB=(0,0,0) $NameOfWave(wP3) Y, wave=($s3, $s3)

    // Labels
    // 【修复2】Angstrom 单位修正
    if (a2k1d_LC == 0)
        // \S 进入上标，\M 退出上标（回到正常基线）
        Label/W=$wname left, "k (Å\\S-1\\M)" 
    else
        Label/W=$wname left, "k (π/a)"
    endif

    Label/W=$wname bottom, a2k1d_heat_unit_label(a2k1d_hmUnitMode)
    
    ModifyGraph tickUnit(left)=1
    // 自动调整一下范围，防止误差棒画到图外面
    SetAxis/A/W=$wname

    return 0
End


//============================================================
// MDCTrack angle-correction helpers (angle-domain outputs only)
//============================================================
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

    Duplicate/O src, $outPath
    Wave out = $outPath

    String cdf = a2k1d_df_with_colon(runDF)
    Variable nTrack = a2k1d_corr_nrows(cdf)

    NVAR corrMode = root:ARPES_LJZ:A2K1D:a2k1d_corrMode
    NVAR skipFlagged = root:ARPES_LJZ:A2K1D:a2k1d_corrSkipFlagged

    Variable i, row, rc, dTh, scEff, raw
    for (i=0; i<DimSize(src,0); i+=1)
        row = a2k1d_corr_row_for_layer(i, nTrack)
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
    if (!a2k1d_is_layer_int_name(wn))
        Print "AngleCorr layer: source must be raw layer_show_<integer>: " + layerPath
        return ""
    endif

    if (!a2k1d_corr_run_is_valid(runDF))
        Print "AngleCorr layer: invalid correction run: " + runDF
        return ""
    endif

    Variable layerIdx = a2k1d_get_layer_index(wn)
    String cdf = a2k1d_df_with_colon(runDF)
    Variable nTrack = a2k1d_corr_nrows(cdf)
    Variable row = a2k1d_corr_row_for_layer(layerIdx, nTrack)

    NVAR corrMode = root:ARPES_LJZ:A2K1D:a2k1d_corrMode
    NVAR skipFlagged = root:ARPES_LJZ:A2K1D:a2k1d_corrSkipFlagged

    Variable dTh, scEff
    Variable rc = a2k1d_get_effective_corr(cdf, row, corrMode, skipFlagged, dTh, scEff)
    if (rc != 0)
        Print "AngleCorr layer: invalid/skipped correction row. layer=", layerIdx, " row=", row
        return ""
    endif

    Variable thetaCenter = a2k1d_get_theta_center_from_corr_run(cdf)

    String outDF = GetWavesDataFolder(src, 1)
    if (strlen(outDF) == 0)
        outDF = "root:"
    endif

    String outName = a2k1d_make_corr_angle_name(wn)
    String outPath = outDF + outName

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
            if (StringMatch(LowerStr(wn0), tailLower))
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
        if (StringMatch(LowerStr(a2k1d_tail_wavename(wp)), tailLower))
            if (WaveExists($wp))
                return wp
            endif
        endif
    endfor

    return ""
End

Function a2k1d_btn_make_corr_peaks(ctrlName) : ButtonControl
    String ctrlName

    SVAR baseDF = root:ARPES_LJZ:A2K1D:a2k1d_baseDF
    NVAR recursive = root:ARPES_LJZ:A2K1D:a2k1d_recursive
    SVAR corrRunDF = root:ARPES_LJZ:A2K1D:a2k1d_corrRunDF

    String base = a2k1d_df_with_colon(baseDF)
    if (!a2k1d_corr_run_is_valid(corrRunDF))
        DoAlert 0, "Invalid MDCTrack correction run."
        return 0
    endif

    String p1 = a2k1d_find_wave_by_tail_ci(base, recursive, "Peak1K")
    String p2 = a2k1d_find_wave_by_tail_ci(base, recursive, "Peak2K")
    String p3 = a2k1d_find_wave_by_tail_ci(base, recursive, "Peak3K")

    String s1 = a2k1d_find_wave_by_tail_ci(base, recursive, "Sigmap1K")
    String s2 = a2k1d_find_wave_by_tail_ci(base, recursive, "Sigmap2K")
    String s3 = a2k1d_find_wave_by_tail_ci(base, recursive, "Sigmap3K")

    Variable ok = 0

    if (strlen(p1) > 0)
        if (strlen(a2k1d_make_corr_peak_angle_wave(p1, corrRunDF)) > 0)
            ok += 1
        endif
    endif
    if (strlen(p2) > 0)
        if (strlen(a2k1d_make_corr_peak_angle_wave(p2, corrRunDF)) > 0)
            ok += 1
        endif
    endif
    if (strlen(p3) > 0)
        if (strlen(a2k1d_make_corr_peak_angle_wave(p3, corrRunDF)) > 0)
            ok += 1
        endif
    endif

    if (strlen(s1) > 0)
        a2k1d_make_corr_sigma_angle_wave(s1, corrRunDF)
    endif
    if (strlen(s2) > 0)
        a2k1d_make_corr_sigma_angle_wave(s2, corrRunDF)
    endif
    if (strlen(s3) > 0)
        a2k1d_make_corr_sigma_angle_wave(s3, corrRunDF)
    endif

    Print "Make Corr Peaks done. Peak outputs created=", ok
    return 0
End

Function a2k1d_btn_make_corr_layers(ctrlName) : ButtonControl
    String ctrlName

    SVAR baseDF = root:ARPES_LJZ:A2K1D:a2k1d_baseDF
    NVAR recursive = root:ARPES_LJZ:A2K1D:a2k1d_recursive
    SVAR corrRunDF = root:ARPES_LJZ:A2K1D:a2k1d_corrRunDF

    if (!a2k1d_corr_run_is_valid(corrRunDF))
        DoAlert 0, "Invalid MDCTrack correction run."
        return 0
    endif

    String list = a2k1d_collect_layers(baseDF, recursive)
    Variable n = ItemsInList(list, ";")
    Variable i, ok, fail
    ok = 0
    fail = 0

    for (i=0; i<n; i+=1)
        String wp = StringFromList(i, list, ";")
        if (strlen(wp) == 0)
            continue
        endif
        String outp = a2k1d_make_corr_layer_angle_wave(wp, corrRunDF)
        if (strlen(outp) > 0)
            ok += 1
        else
            fail += 1
        endif
    endfor

    Printf "Make Corr Layers done: ok=%d fail=%d total=%d\r", ok, fail, n
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
// 打开颜色盘选择器 (极速版：只读全局波形)
//============================================================
Function a2k1d_btn_open_ct_browser(ctrlName) : ButtonControl
    String ctrlName
    String winName = "A2K1D_CT_Browser_Panel"
    
    // 1. 窗口复用
    DoWindow/F $winName
    if (V_flag != 0)
        return 0
    endif
    
    // 2. 确保列表不为空 (防呆)
    Wave/T wList = root:ARPES_LJZ:A2K1D:CT_LB_Items
    if (DimSize(wList, 0) == 0)
        a2k1d_rebuild_ct_list()
    endif
    
    // 3. 同步选中状态 (高亮当前项)
    Wave/U/B wSel = root:ARPES_LJZ:A2K1D:CT_LB_Sel
    wSel = 0
    SVAR curName = root:ARPES_LJZ:A2K1D:a2k1d_ctPickName
    FindValue/TEXT=curName/TXOP=4 wList
    Variable findIdx = -1
    if (V_Value >= 0)
        wSel[V_Value] = 1
        findIdx = V_Value
    endif

    // 4. 创建面板
    NewPanel/K=1/W=(500,200,750,600) as "Select Color Table"
    DoWindow/C $winName
    
    // 列表框：直接引用全局波形
    ListBox lb_ct,pos={10,10},size={230,350},proc=a2k1d_ct_browser_lb_proc
    ListBox lb_ct,listWave=root:ARPES_LJZ:A2K1D:CT_LB_Items
    ListBox lb_ct,selWave=root:ARPES_LJZ:A2K1D:CT_LB_Sel
    ListBox lb_ct,mode=1
    
    if (findIdx >= 0)
        ListBox lb_ct, row=findIdx
    endif
    
    // 按钮
    Button btn_refresh,pos={10,370},size={60,20},title="Refresh",proc=a2k1d_ct_browser_refresh
    Button btn_close,pos={180,370},size={60,20},title="Close",proc=a2k1d_ct_browser_close
End

// 新增：手动刷新按钮 (如果你加了新颜色，点这个)
Function a2k1d_ct_browser_refresh(ctrlName) : ButtonControl
    String ctrlName
    a2k1d_rebuild_ct_list()
    // 刷新 ListBox
    ListBox lb_ct, win=A2K1D_CT_Browser_Panel, listWave=root:ARPES_LJZ:A2K1D:CT_LB_Items
    ListBox lb_ct, win=A2K1D_CT_Browser_Panel, selWave=root:ARPES_LJZ:A2K1D:CT_LB_Sel
    return 0
End

Function a2k1d_ct_browser_lb_proc(ctrlName, row, col, eventCode) : ListBoxControl
    String ctrlName
    Variable row, col, eventCode

    if (eventCode != 1 && eventCode != 4 && eventCode != 3)
        return 0
    endif
    if (row < 0)
        return 0
    endif
    
    // 1. 获取选中的名字
    Wave/T wList = root:ARPES_LJZ:A2K1D:CT_LB_Items
    String selectedName = wList[row]
    
    // 2. 更新选中波形 (ListBox 需要手动互斥，或者依赖 mode=1 自动处理，这里手动保险)
    Wave/U/B wSel = root:ARPES_LJZ:A2K1D:CT_LB_Sel
    wSel = 0
    wSel[row] = 1
    
    // 3. 更新全局变量
    SVAR a2k1d_ctPickName = root:ARPES_LJZ:A2K1D:a2k1d_ctPickName
    a2k1d_ctPickName = selectedName
    
    // 4. 更新主界面显示
    DoWindow A2K1D_LJZ_P
    if (V_flag)
        TitleBox a2k1d_tb_ct_current, win=A2K1D_LJZ_P, title="CT: " + selectedName
    endif
    
    // 5. 双击关闭
    if (eventCode == 4)
        DoWindow/K A2K1D_CT_Browser_Panel
    endif

    return 0
End

Function a2k1d_ct_browser_close(ctrlName) : ButtonControl
    String ctrlName
    DoWindow/K A2K1D_CT_Browser_Panel
    return 0
End


// ------------------------------------------------------------
// Get RGB(0..65535) from CTLUZ CTLIB palette at t in [0,1]
// If CTLIB:<pickName> missing, fall back to current root:ARPES_LJZ:CTLUZ:ct_table
// If ct_lut exists, use it: t -> s (base space) -> color index
// ------------------------------------------------------------
Function a2k1d_ctluz_rgb16_at_t(pickName, t, inv, r16, g16, b16)
    String pickName
    Variable t, inv
    Variable &r16, &g16, &b16

    // ensure CTLUZ folders + builtins exist
    ctluz_ensure_folder()

    Variable tt = t
    if (tt < 0) 
     tt = 0 ; 
     endif
    if (tt > 1) 
     tt = 1 ; 
     endif
    if (inv)
        tt = 1 - tt
    endif

    Wave/Z/W/U ct = $("root:ARPES_LJZ:CTLUZ:CTLIB:"+pickName)
    if (!WaveExists(ct))
        Wave/W/U ct2 = root:ARPES_LJZ:CTLUZ:ct_table
        ct = ct2
    endif

    Wave/Z lut = root:ARPES_LJZ:CTLUZ:ct_lut     // float 0..1
    Variable n = DimSize(ct, 0)
    if (n <= 1)
        r16 = 0; g16 = 0; b16 = 0
        return 0
    endif

    Variable it = round(tt*(n-1))
    if (it < 0) 
     it = 0 ;
     endif
    if (it > n-1) 
     it = n-1 ;
     endif

    // t -> s via LUT (if exists), else s=t
    Variable s = tt
    if (WaveExists(lut) && DimSize(lut,0) == n)
        s = lut[it]
        if (s < 0) 
         s = 0 
          endif
        if (s > 1) 
         s = 1 
          endif
    endif

    Variable ic = round(s*(n-1))
    if (ic < 0) 
     ic = 0 
      endif
    if (ic > n-1) 
     ic = n-1 
     endif

    r16 = ct[ic][0]
    g16 = ct[ic][1]
    b16 = ct[ic][2]
    return 0
End

Function a2k1d_pm_ctlib_proc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName, popStr
    Variable popNum

    SVAR a2k1d_ctPickName = root:ARPES_LJZ:A2K1D:a2k1d_ctPickName
    if (StringMatch(popStr, "None"))
        a2k1d_ctPickName = ""
    else
        a2k1d_ctPickName = popStr
    endif
    return 0
End

//============================================================
// Rebuild Color Table List (将字符串转为全局波形)
//============================================================
Function a2k1d_rebuild_ct_list()
    ctluz_ensure_folder()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:A2K1D
    
    // 1. 获取源字符串
    SVAR/Z listStr = root:ARPES_LJZ:CTLUZ:ctlib_menu_list
    if (!SVAR_Exists(listStr))
        // 尝试修复：如果字符串不存在，可能是 CTLUZ 还没初始化
        // 这里只是防错，生成一个空的
        String/G root:ARPES_LJZ:CTLUZ:ctlib_menu_list = ""
        SVAR listStr = root:ARPES_LJZ:CTLUZ:ctlib_menu_list
    endif
    
    // 2. 获取波形引用
    Wave/T CT_LB_Items = CT_LB_Items
    Wave/U/B CT_LB_Sel = CT_LB_Sel
    
    // 3. 填充波形
    Variable n = ItemsInList(listStr, ";")
    Redimension/N=(n) CT_LB_Items, CT_LB_Sel
    
    Variable i
    for(i=0; i<n; i+=1)
        CT_LB_Items[i] = StringFromList(i, listStr, ";")
        CT_LB_Sel[i] = 0 // 重置选择
    endfor
    
    // 4. 同步当前选中的项
    SVAR curName = root:ARPES_LJZ:A2K1D:a2k1d_ctPickName
    FindValue/TEXT=curName/TXOP=4 CT_LB_Items
    if (V_Value >= 0)
        CT_LB_Sel[V_Value] = 1
    endif
    
    SetDataFolder df0
    return 0
End

//============================================================
// Helper: compute global k-range from peak waves (peak*_k) in a sensible way
// - scans up to maxLayers points (usually m, the number of layers plotted)
// - ignores NaN/Inf
// - expands range by (marginFrac) of span, with a minimum absolute margin
// Returns: 1 if valid range found, else 0.
//============================================================
Function a2k1d_peak_global_krange(wP1_k, wP2_k, wP3_k, maxLayers, marginFrac, minAbsMargin, kLo, kHi)
    Wave/Z wP1_k, wP2_k, wP3_k
    Variable maxLayers, marginFrac, minAbsMargin
    Variable &kLo, &kHi

    Variable has = 0
    Variable kmin = 0, kmax = 0
    Variable i, kv

    // local helper macro-like: update min/max
    // (Igor doesn't have inline macros; we just repeat)

    if (WaveExists(wP1_k))
        for (i=0; i<min(maxLayers, DimSize(wP1_k,0)); i+=1)
            kv = wP1_k[i]
            if (numtype(kv)==0)
                if (!has)
                    kmin = kv; kmax = kv; has = 1
                else
                    if (kv < kmin)  
                    kmin = kv
                    endif
                    if (kv > kmax)  
                    kmax = kv
                    endif
                endif
            endif
        endfor
    endif

    if (WaveExists(wP2_k))
        for (i=0; i<min(maxLayers, DimSize(wP2_k,0)); i+=1)
            kv = wP2_k[i]
            if (numtype(kv)==0)
                if (!has)
                    kmin = kv; kmax = kv; has = 1
                else
                    if (kv < kmin)  
                    kmin = kv
                    endif
                    if (kv > kmax)  
                    kmax = kv
                    endif
                endif
            endif
        endfor
    endif

    if (WaveExists(wP3_k))
        for (i=0; i<min(maxLayers, DimSize(wP3_k,0)); i+=1)
            kv = wP3_k[i]
            if (numtype(kv)==0)
                if (!has)
                    kmin = kv; kmax = kv; has = 1
                else
                    if (kv < kmin)  
                    kmin = kv
                    endif
                    if (kv > kmax)  
                    kmax = kv
                    endif
                endif
            endif
        endfor
    endif

    if (!has)
        return 0
    endif

    Variable span = abs(kmax - kmin)
    Variable margin = span * marginFrac
    if (margin < minAbsMargin)
        margin = minAbsMargin
    endif
    if (span < 1e-12)
        // all peaks nearly identical -> just give symmetric small window
        margin = max(minAbsMargin, 0.02)
    endif

    kLo = min(kmin, kmax) - margin
    kHi = max(kmin, kmax) + margin

    // guard
    if (numtype(kLo)!=0 || numtype(kHi)!=0 || abs(kHi-kLo)<1e-12)
        return 0
    endif

    return 1
End

//============================================================
// Safe 1D linear interpolation at x (no out-of-range).
// Works for increasing or decreasing x-scale.
// Returns NaN if wave invalid.
//============================================================
Function a2k1d_safe_y_at_x(w, x)
    Wave w
    Variable x

    Variable n = DimSize(w,0)
    if (n <= 0)
        return NaN
    endif
    if (n == 1)
        return w[0]
    endif

    // x domain (handle reversed scale)
    Variable x0 = LeftX(w)
    Variable x1 = RightX(w)
    Variable lo = min(x0,x1)
    Variable hi = max(x0,x1)

    // clamp x into legal domain
    if (x < lo) 
        x = lo
    endif
    if (x > hi) 
        x = hi
    endif

    // convert to point index (may be fractional conceptually, but x2pnt gives nearest integer-like)
    Variable p = x2pnt(w, x)

    // critical: clamp p to [0, n-2] so p+1 is always valid
    if (p < 0)
        p = 0
    endif
    if (p > n-2)
        p = n-2
    endif

    Variable xa = pnt2x(w, p)
    Variable xb = pnt2x(w, p+1)

    // avoid division by zero (shouldn't happen for proper scaling, but just in case)
    if (abs(xb - xa) < 1e-15)
        return w[p]
    endif

    Variable t = (x - xa) / (xb - xa)
    return w[p] + t * (w[p+1] - w[p])
End

Function a2k1d_pm_hm_unit_proc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName, popStr
    Variable popNum

    NVAR a2k1d_hmUnitMode = root:ARPES_LJZ:A2K1D:a2k1d_hmUnitMode
    a2k1d_hmUnitMode = popNum - 1
    return 0
End

Function/S a2k1d_heat_unit_label(mode)
    Variable mode

    switch(mode)
        case 0:
            return "Delay Time (ps)"
        case 1:
            return "Temperature (K)"
        case 2:
            return "Fluence (μJ/cm\\S2\\M)"
        default:
            return "Frame Index"
    endswitch
End

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
        idxW[i] = a2k1d_get_layer_index(a2k1d_tail_wavename(wp))
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




Function a2k1d_apply_twoband_ct_to_image(winName, imgName, imgWave, xViewLo, xViewHi)
    String winName, imgName
    Wave imgWave
    Variable xViewLo, xViewHi

    Wave ctLocal = a2k1d_make_twoband_ct(256)
    String ctPath = "root:ARPES_LJZ:OUTPUT:A2K1D:a2k1d_twoband_ct"

    String imgInst = imgName
    String imgList = ImageNameList(winName, ";")
    if (WhichListItem(imgInst, imgList, ";") < 0)
        imgInst = StringFromList(0, imgList, ";")
    endif
    if (strlen(imgInst) == 0)
        return -1
    endif

    Variable pLo = round(x2pnt(imgWave, min(xViewLo, xViewHi)))
    Variable pHi = round(x2pnt(imgWave, max(xViewLo, xViewHi)))

    if (pLo < 0)
        pLo = 0
    endif
    if (pHi > DimSize(imgWave,0)-1)
        pHi = DimSize(imgWave,0)-1
    endif
    if (pHi < pLo)
        Variable tmpP = pLo
        pLo = pHi
        pHi = tmpP
    endif

    Duplicate/O/R=[pLo,pHi][] imgWave, root:ARPES_LJZ:OUTPUT:A2K1D:a2k1d_ctStat2D
    Wave stat2D = root:ARPES_LJZ:OUTPUT:A2K1D:a2k1d_ctStat2D

    Redimension/N=(DimSize(stat2D,0)*DimSize(stat2D,1)) stat2D
    Sort stat2D, stat2D

    Variable n = DimSize(stat2D,0)
    if (n < 2)
        KillWaves/Z stat2D
        return -1
    endif

    // 这是给增强后的 display wave 用的，不是原始图
    Variable zLo = stat2D[round(0.08*(n-1))]
    Variable zHi = stat2D[round(0.995*(n-1))]

    if (numtype(zLo) != 0 || numtype(zHi) != 0 || zHi <= zLo)
        zLo = 0.03
        zHi = 1.00
    endif

    ModifyImage/W=$winName $imgInst, ctab={zLo,zHi,$ctPath,0}
    DoUpdate

    KillWaves/Z stat2D
    return 0
End

Function a2k1d_btn_plot_layers_heatmap(ctrlName) : ButtonControl
    String ctrlName

    SVAR a2k1d_baseDF     = root:ARPES_LJZ:A2K1D:a2k1d_baseDF
    NVAR a2k1d_recursive  = root:ARPES_LJZ:A2K1D:a2k1d_recursive
    SVAR a2k1d_baseName   = root:ARPES_LJZ:A2K1D:a2k1d_baseName

    NVAR a2k1d_hmY0       = root:ARPES_LJZ:A2K1D:a2k1d_hmY0
    NVAR a2k1d_hmDY       = root:ARPES_LJZ:A2K1D:a2k1d_hmDY
    NVAR a2k1d_hmYMul     = root:ARPES_LJZ:A2K1D:a2k1d_hmYMul
    NVAR a2k1d_hmUnitMode = root:ARPES_LJZ:A2K1D:a2k1d_hmUnitMode
    NVAR a2k1d_LC         = root:ARPES_LJZ:A2K1D:a2k1d_LC

    String base = a2k1d_df_with_colon(a2k1d_baseDF)
    if (!a2k1d_df_exists(base))
        Abort "Heatmap: baseDF not found."
    endif

    //================================================
    // 1) collect *_k_spec and sort
    //================================================
    String listKS = a2k1d_collect_existing_kspec_list(base, a2k1d_recursive)
    listKS = a2k1d_sort_kspec_list_by_layerindex(listKS)

    Variable m = ItemsInList(listKS, ";")
    if (m <= 0)
        Abort "Heatmap: no *_k_spec waves found."
    endif

    String wp0 = StringFromList(0, listKS, ";")
    Wave/Z w0 = $wp0
    if (!WaveExists(w0))
        Abort "Heatmap: template wave missing."
    endif

    Variable nx = DimSize(w0, 0)
    if (nx <= 1)
        Abort "Heatmap: template wave has too few points."
    endif

    Variable xLo = min(LeftX(w0), RightX(w0))
    Variable xHi = max(LeftX(w0), RightX(w0))

    //================================================
    // 2) build raw image matrix: dim0 = k, dim1 = delay index
    //================================================
    a2k1d_ensure_folder()
    String outDF = "root:ARPES_LJZ:OUTPUT:A2K1D:"
    String prefix
    if (strlen(a2k1d_baseName) > 0)
        prefix = a2k1d_baseName
    else
        prefix = "A2K1D"
    endif

    String imgName = outDF + prefix + "_LayerHeat_kSpec"
    Make/O/D/N=(nx, m) $imgName
    Wave img = $imgName
    img = NaN

    Variable i, j
    for (j=0; j<m; j+=1)
        String wpj = StringFromList(j, listKS, ";")
        Wave/Z wj = $wpj
        if (!WaveExists(wj))
            continue
        endif

        Variable xLoJ = min(LeftX(wj), RightX(wj))
        Variable xHiJ = max(LeftX(wj), RightX(wj))

        if (DimSize(wj,0) == nx && abs(xLoJ-xLo) < 1e-9 && abs(xHiJ-xHi) < 1e-9)
            for (i=0; i<nx; i+=1)
                img[i][j] = wj[i]
            endfor
        else
            for (i=0; i<nx; i+=1)
                Variable xx = xLo + (xHi-xLo) * i / (nx-1.0)
                img[i][j] = a2k1d_safe_y_at_x(wj, xx)
            endfor
        endif
    endfor

    // raw image scales: x=k, y=delay-index-physical
    SetScale/I x, xLo, xHi, WaveUnits(w0, 0), img
    SetScale/I y, a2k1d_axis_value_from_index(0), a2k1d_axis_value_from_index(m-1), "", img
    SetScale d, 0, 0, WaveUnits(w0, -1), img

    //================================================
    // 3) peak overlay waves
    //================================================
    String p1_path = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "peak1k_k")
    String p2_path = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "peak2k_k")
    String p3_path = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "peak3k_k")

    Wave/Z wP1_k = $p1_path
    Wave/Z wP2_k = $p2_path
    Wave/Z wP3_k = $p3_path

    String s1_path = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "sigmap1k_k")
    String s2_path = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "sigmap2k_k")
    String s3_path = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "sigmap3k_k")

    Wave/Z wS1_k = $s1_path
    Wave/Z wS2_k = $s2_path
    Wave/Z wS3_k = $s3_path
    
    String wnP1X = outDF + prefix + "_HM_P1_X"
    String wnP1Y = outDF + prefix + "_HM_P1_Y"
    String wnP2X = outDF + prefix + "_HM_P2_X"
    String wnP2Y = outDF + prefix + "_HM_P2_Y"
    String wnP3X = outDF + prefix + "_HM_P3_X"
    String wnP3Y = outDF + prefix + "_HM_P3_Y"
    String wnS1  = outDF + prefix + "_HM_S1"
    String wnS2  = outDF + prefix + "_HM_S2"
    String wnS3  = outDF + prefix + "_HM_S3"
    
    Make/O/D/N=(m) $wnP1X/WAVE=hmP1X, $wnP1Y/WAVE=hmP1Y
    Make/O/D/N=(m) $wnP2X/WAVE=hmP2X, $wnP2Y/WAVE=hmP2Y
    Make/O/D/N=(m) $wnP3X/WAVE=hmP3X, $wnP3Y/WAVE=hmP3Y
    Make/O/D/N=(m) $wnS1/WAVE=hmS1, $wnS2/WAVE=hmS2, $wnS3/WAVE=hmS3

    hmP1X = NaN; hmP1Y = NaN
    hmP2X = NaN; hmP2Y = NaN
    hmP3X = NaN; hmP3Y = NaN
    hmS1  = NaN; hmS2  = NaN; hmS3  = NaN

    for (j=0; j<m; j+=1)
        String wpj2 = StringFromList(j, listKS, ";")
        String wnj2 = a2k1d_tail_wavename(wpj2)
        Variable layerIdx2 = a2k1d_get_layer_index(wnj2)
        Variable yVal = a2k1d_axis_value_from_index(j)

        if (layerIdx2 < 0)
            continue
        endif

        if (WaveExists(wP1_k) && layerIdx2 < DimSize(wP1_k,0) && numtype(wP1_k[layerIdx2]) == 0)
            hmP1X[j] = wP1_k[layerIdx2]
            hmP1Y[j] = yVal
            if (WaveExists(wS1_k) && layerIdx2 < DimSize(wS1_k,0) && numtype(wS1_k[layerIdx2]) == 0)
                hmS1[j] = wS1_k[layerIdx2]
            endif
        endif

        if (WaveExists(wP2_k) && layerIdx2 < DimSize(wP2_k,0) && numtype(wP2_k[layerIdx2]) == 0)
            hmP2X[j] = wP2_k[layerIdx2]
            hmP2Y[j] = yVal
            if (WaveExists(wS2_k) && layerIdx2 < DimSize(wS2_k,0) && numtype(wS2_k[layerIdx2]) == 0)
                hmS2[j] = wS2_k[layerIdx2]
            endif
        endif

        if (WaveExists(wP3_k) && layerIdx2 < DimSize(wP3_k,0) && numtype(wP3_k[layerIdx2]) == 0)
            hmP3X[j] = wP3_k[layerIdx2]
            hmP3Y[j] = yVal
            if (WaveExists(wS3_k) && layerIdx2 < DimSize(wS3_k,0) && numtype(wS3_k[layerIdx2]) == 0)
                hmS3[j] = wS3_k[layerIdx2]
            endif
        endif
    endfor

    //================================================
    // 3.5) make display wave by selected heatmap mode
    //================================================
    NVAR a2k1d_hmDisplayMode = root:ARPES_LJZ:A2K1D:a2k1d_hmDisplayMode
    NVAR a2k1d_hmLoFrac      = root:ARPES_LJZ:A2K1D:a2k1d_hmLoFrac
    NVAR a2k1d_hmHiFrac      = root:ARPES_LJZ:A2K1D:a2k1d_hmHiFrac
    NVAR a2k1d_hmGamma       = root:ARPES_LJZ:A2K1D:a2k1d_hmGamma
    NVAR a2k1d_hmBgSmooth    = root:ARPES_LJZ:A2K1D:a2k1d_hmBgSmooth

    String imgDispPath = ""

    if (a2k1d_hmDisplayMode == 3)
        Variable dispWid1      = 0.006
        Variable dispWid2      = 0.009
        Variable dispWid3      = 0.012
        Variable dispGain1     = 1.00
        Variable dispGain2     = 1.25
        Variable dispGain3     = 1.55
        Variable dispBgSmooth  = 17
        Variable dispBaseFrac  = 0.85
        Variable dispPeakThresh = 0.10

        Wave imgDispLegacy = a2k1d_make_peak_guided_display_wave(img, hmP1X, hmP2X, hmP3X, dispWid1, dispWid2, dispWid3, dispGain1, dispGain2, dispGain3, dispBgSmooth, dispBaseFrac, dispPeakThresh)
        imgDispPath = GetWavesDataFolder(imgDispLegacy, 2)
    else
        Variable doBgSub = 0
        if (a2k1d_hmDisplayMode == 2)
            doBgSub = 1
        endif

        Wave imgDispSoft = a2k1d_make_row_norm_display_wave(img, a2k1d_hmLoFrac, a2k1d_hmHiFrac, a2k1d_hmGamma, a2k1d_hmBgSmooth, doBgSub)
        imgDispPath = GetWavesDataFolder(imgDispSoft, 2)
    endif

    Wave/Z imgDisp = $imgDispPath
    if (!WaveExists(imgDisp))
        Abort "Heatmap: display wave generation failed."
    endif
    //================================================
    // 3.6) build PLOTTING wave directly in swapped orientation
    // final display:
    //   horizontal axis = delay
    //   vertical axis   = k
    // so AppendImage needs dim0 = delay, dim1 = k
    //================================================
    String imgPlotName = outDF + prefix + "_LayerHeat_kSpec_SwappedPlot"
    Make/O/D/N=(m, nx) $imgPlotName
    Wave imgPlot = $imgPlotName

    for (j=0; j<m; j+=1)
        for (i=0; i<nx; i+=1)
            imgPlot[j][i] = imgDisp[i][j]
        endfor
    endfor

	Variable delayLo = a2k1d_axis_value_from_index(0)
	Variable delayHi = a2k1d_axis_value_from_index(m-1)
	SetScale/I x, delayLo, delayHi, "", imgPlot
    SetScale/I y, xLo, xHi, WaveUnits(w0, 0), imgPlot
    SetScale d, 0, 0, WaveUnits(w0, -1), imgPlot

    //================================================
    // 4) display in final geometry (NO swapXY here)
    //================================================
    String wname
    if (strlen(a2k1d_baseName) > 0)
        wname = a2k1d_baseName + "_LayerHeat_kSpec"
    else
        wname = "A2K1D_LayerHeat_kSpec"
    endif

    DoWindow/K $wname
    Display/N=$wname
    AppendImage imgPlot

    ModifyGraph/W=$wname standoff=0
    ModifyGraph/W=$wname mirror=2

    Label/W=$wname bottom a2k1d_heat_unit_label(a2k1d_hmUnitMode)
    if (a2k1d_LC == 0)
        Label/W=$wname left "k\\B//\\M (Å\\S-1\\M)"
    else
        Label/W=$wname left "k (π/a)"
    endif

    SetAxis/W=$wname bottom delayLo, delayHi

    // k window (used both for axis crop and CT stats)
    Variable kLoAuto, kHiAuto
    Variable okRange
    okRange = a2k1d_peak_global_krange(wP1_k, wP2_k, wP3_k, m, 0.5, 0.03, kLoAuto, kHiAuto)

    if (okRange)
        SetAxis/W=$wname left kLoAuto, kHiAuto
    else
        SetAxis/W=$wname left xLo, xHi
    endif

    // apply CT to plotted image instance,
    // but use imgDisp (unswapped, k along dim0) for statistics window
    // apply fixed 3-peak CT (不要再做 percentile 压缩)
    String imgInst = StringFromList(0, ImageNameList(wname, ";"))
    if (a2k1d_hmDisplayMode == 3)
        a2k1d_apply_threepeak_ct_to_image(wname, imgInst)
    else
        a2k1d_apply_personal_soft_heat_ct_to_image(wname, imgInst)
    endif

    ColorScale/C/N=heatScale/F=0/A=RB/E=0/W=$wname image=$imgInst, heightPct=30, widthPct=3, frame=1

    //================================================
    // 5) overlay peaks in the SAME swapped coordinate system
    // x = delay, y = k
    // so: AppendToGraph yWave(k) vs xWave(delay)
    //================================================
    if (WaveExists(wP1_k))
        AppendToGraph/W=$wname hmP1X vs hmP1Y
        ModifyGraph/W=$wname mode($NameOfWave(hmP1X))=3,marker($NameOfWave(hmP1X))=19,msize($NameOfWave(hmP1X))=3,rgb($NameOfWave(hmP1X))=(0,0,0)
        if (WaveExists(wS1_k))
            ErrorBars/W=$wname/RGB=(0,0,0) $NameOfWave(hmP1X) Y, wave=(hmS1,hmS1)
        endif
    endif

    if (WaveExists(wP2_k))
        AppendToGraph/W=$wname hmP2X vs hmP2Y
        ModifyGraph/W=$wname mode($NameOfWave(hmP2X))=3,marker($NameOfWave(hmP2X))=17,msize($NameOfWave(hmP2X))=3,rgb($NameOfWave(hmP2X))=(52000,12000,6000)
        if (WaveExists(wS2_k))
            ErrorBars/W=$wname/RGB=(52000,12000,6000) $NameOfWave(hmP2X) Y, wave=(hmS2,hmS2)
        endif
    endif

    if (WaveExists(wP3_k))
        AppendToGraph/W=$wname hmP3X vs hmP3Y
        ModifyGraph/W=$wname mode($NameOfWave(hmP3X))=3,marker($NameOfWave(hmP3X))=16,msize($NameOfWave(hmP3X))=3,rgb($NameOfWave(hmP3X))=(0,18000,52000)
        if (WaveExists(wS3_k))
            ErrorBars/W=$wname/RGB=(0,18000,52000) $NameOfWave(hmP3X) Y, wave=(hmS3,hmS3)
        endif
    endif

    ModifyGraph/W=$wname tickUnit(bottom)=1, tickUnit(left)=1

    return 0
End

Function/WAVE a2k1d_make_twoband_ct(nSamp)
    Variable nSamp

    a2k1d_ensure_folder()
    if (nSamp < 2)
        nSamp = 256
    endif

    String outPath = "root:ARPES_LJZ:OUTPUT:A2K1D:a2k1d_twoband_ct"
    Make/O/W/U/N=(nSamp,3) $outPath
    Wave ct = $outPath

    Variable i, t, u
    Variable r, g, b

    for (i=0; i<nSamp; i+=1)
        t = i/(nSamp-1.0)

        if (t < 0.22)
            // 背景：白 -> 很浅灰蓝
            u = t/0.22
            r = a2k1d_lerp(65535, 59000, u)
            g = a2k1d_lerp(65535, 59000, u)
            b = a2k1d_lerp(65535, 62000, u)

        elseif (t < 0.46)
            // 第一峰：浅灰 -> 橙 -> 深红
            u = (t-0.22)/(0.46-0.22)
            r = a2k1d_lerp(59000, 65535, u)
            g = a2k1d_lerp(59000,  8000, u)
            b = a2k1d_lerp(62000,     0, u)

        elseif (t < 0.58)
            // 中间分隔：红 -> 近白
            u = (t-0.46)/(0.58-0.46)
            r = a2k1d_lerp(65535, 61000, u)
            g = a2k1d_lerp( 8000, 61000, u)
            b = a2k1d_lerp(    0, 65535, u)

        else
            // 第二峰：近白 -> 亮蓝 -> 深蓝
            u = (t-0.58)/(1.00-0.58)
            r = a2k1d_lerp(61000,     0, u)
            g = a2k1d_lerp(61000, 12000, u)
            b = a2k1d_lerp(65535, 65535, u)
        endif

        r = max(0, min(65535, r))
        g = max(0, min(65535, g))
        b = max(0, min(65535, b))

        ct[i][0] = r
        ct[i][1] = g
        ct[i][2] = b
    endfor

    return ct
End

Function a2k1d_lerp(a, b, u)
    Variable a, b, u
    return a + (b-a)*u
End

// legacy peak-guided visualization; not recommended as default paper figure because the base image contains fit-position prior.
Function/WAVE a2k1d_make_peak_guided_display_wave(imgIn, wP1X, wP2X, wP3X, wid1, wid2, wid3, gain1, gain2, gain3, bgSmoothN, baseFrac, peakThresh)
    Wave imgIn
    Wave wP1X, wP2X, wP3X
    Variable wid1, wid2, wid3, gain1, gain2, gain3, bgSmoothN, baseFrac, peakThresh

    a2k1d_ensure_folder()

    Variable nx = DimSize(imgIn, 0)
    Variable ny = DimSize(imgIn, 1)

    String outDF = "root:ARPES_LJZ:OUTPUT:A2K1D:"

    String dispPath = outDF + "a2k1d_img_disp"
    String rowPath  = outDF + "a2k1d_rowTmp"
    String bgPath   = outDF + "a2k1d_bgTmp"
    String resPath  = outDF + "a2k1d_resTmp"

    Make/O/D/N=(nx, ny) $dispPath
    Make/O/D/N=(nx)     $rowPath, $bgPath, $resPath

    Wave imgDisp = $dispPath
    Wave rowTmp  = $rowPath
    Wave bgTmp   = $bgPath
    Wave resTmp  = $resPath

    SetScale/P x, DimOffset(imgIn,0), DimDelta(imgIn,0), WaveUnits(imgIn,0), rowTmp
    SetScale/P x, DimOffset(imgIn,0), DimDelta(imgIn,0), WaveUnits(imgIn,0), bgTmp
    SetScale/P x, DimOffset(imgIn,0), DimDelta(imgIn,0), WaveUnits(imgIn,0), resTmp

    Variable i, j
    Variable xVal, p1, p2, p3, m1, m2, m3
    Variable rowMaxRes, rowMinRaw, rowMaxRaw, rawN
    Variable d1, d2, d3
    Variable c1, c2, c3, cMax, alpha
    Variable baseV

    // fixed numeric bands that match the CT
    Variable bgLo = 0.03, bgHi = 0.16
    Variable p1Lo = 0.22, p1Hi = 0.46
    Variable p2Lo = 0.50, p2Hi = 0.74
    Variable p3Lo = 0.78, p3Hi = 0.98

    imgDisp = 0

    for (j=0; j<ny; j+=1)

        // raw row
        rowTmp = imgIn[p][j]

        WaveStats/Q rowTmp
        rowMinRaw = V_min
        rowMaxRaw = V_max

        if (numtype(rowMinRaw) != 0 || numtype(rowMaxRaw) != 0 || rowMaxRaw <= rowMinRaw)
            continue
        endif

        // smooth background
        bgTmp = rowTmp[p]
        if (bgSmoothN > 1)
            Smooth bgSmoothN, bgTmp
        endif

        // positive residual
        resTmp = rowTmp[p] - bgTmp[p]
        resTmp = max(resTmp[p], 0)

        WaveStats/Q resTmp
        rowMaxRes = V_max
        if (numtype(rowMaxRes) != 0 || rowMaxRes <= 0)
            // 没有明显结构时仍保留背景
            for (i=0; i<nx; i+=1)
                rawN = (rowTmp[i] - rowMinRaw) / (rowMaxRaw - rowMinRaw)
                rawN = max(0, min(1, rawN))
                imgDisp[i][j] = bgLo + (bgHi-bgLo) * min(1, baseFrac * sqrt(rawN))
            endfor
            continue
        endif

        // init peak states
        p1 = NaN; p2 = NaN; p3 = NaN
        m1 = 0;   m2 = 0;   m3 = 0

        if (j < DimSize(wP1X,0) && numtype(wP1X[j]) == 0)
            p1 = wP1X[j]
            WaveStats/Q/R=(p1-1.2*wid1, p1+1.2*wid1) resTmp
            if (V_npnts > 0 && numtype(V_max) == 0 && V_max > 0)
                m1 = V_max
            endif
        endif

        if (j < DimSize(wP2X,0) && numtype(wP2X[j]) == 0)
            p2 = wP2X[j]
            WaveStats/Q/R=(p2-1.2*wid2, p2+1.2*wid2) resTmp
            if (V_npnts > 0 && numtype(V_max) == 0 && V_max > 0)
                m2 = V_max
            endif
        endif

        if (j < DimSize(wP3X,0) && numtype(wP3X[j]) == 0)
            p3 = wP3X[j]
            WaveStats/Q/R=(p3-1.2*wid3, p3+1.2*wid3) resTmp
            if (V_npnts > 0 && numtype(V_max) == 0 && V_max > 0)
                m3 = V_max
            endif
        endif

        for (i=0; i<nx; i+=1)
            xVal = pnt2x(resTmp, i)

            // preserve whole row weakly as background band
            rawN = (rowTmp[i] - rowMinRaw) / (rowMaxRaw - rowMinRaw)
            rawN = max(0, min(1, rawN))
            baseV = bgLo + (bgHi-bgLo) * min(1, baseFrac * sqrt(rawN))

            c1 = 0
            c2 = 0
            c3 = 0

            if (numtype(p1) == 0 && m1 > 0)
                d1 = (xVal - p1) / wid1
                c1 = gain1 * exp(-0.5*d1*d1) * resTmp[i] / m1
            endif

            if (numtype(p2) == 0 && m2 > 0)
                d2 = (xVal - p2) / wid2
                c2 = gain2 * exp(-0.5*d2*d2) * resTmp[i] / m2
            endif

            if (numtype(p3) == 0 && m3 > 0)
                d3 = (xVal - p3) / wid3
                c3 = gain3 * exp(-0.5*d3*d3) * resTmp[i] / m3
            endif

            c1 = max(0, c1)
            c2 = max(0, c2)
            c3 = max(0, c3)

            cMax = max(c1, max(c2, c3))

            if (cMax < peakThresh)
                imgDisp[i][j] = baseV
            else
                if (c1 >= c2 && c1 >= c3)
                    alpha = min(1, c1)
                    imgDisp[i][j] = max(baseV, p1Lo + (p1Hi-p1Lo)*alpha)

                elseif (c2 >= c1 && c2 >= c3)
                    alpha = min(1, c2)
                    imgDisp[i][j] = max(baseV, p2Lo + (p2Hi-p2Lo)*alpha)

                else
                    alpha = min(1, c3)
                    imgDisp[i][j] = max(baseV, p3Lo + (p3Hi-p3Lo)*alpha)
                endif
            endif
        endfor
    endfor

    imgDisp = max(0, min(1, imgDisp[p][q]))

    SetScale/P x, DimOffset(imgIn,0), DimDelta(imgIn,0), WaveUnits(imgIn,0), imgDisp
    SetScale/P y, DimOffset(imgIn,1), DimDelta(imgIn,1), WaveUnits(imgIn,1), imgDisp
    SetScale d, 0, 0, WaveUnits(imgIn,-1), imgDisp

    return imgDisp
End


Function/WAVE a2k1d_make_row_norm_display_wave(imgIn, loFrac, hiFrac, gammaVal, bgSmoothN, doBgSub)
    Wave imgIn
    Variable loFrac, hiFrac, gammaVal, bgSmoothN, doBgSub

    a2k1d_ensure_folder()

    Variable nx = DimSize(imgIn, 0)
    Variable ny = DimSize(imgIn, 1)

    String outDF = "root:ARPES_LJZ:OUTPUT:A2K1D:"
    String dispPath = outDF + "a2k1d_img_disp_soft"
    String rowPath  = outDF + "a2k1d_row_soft"
    String bgPath   = outDF + "a2k1d_bg_soft"
    String statPath = outDF + "a2k1d_stat_soft"

    Make/O/D/N=(nx, ny) $dispPath
    Make/O/D/N=(nx) $rowPath, $bgPath, $statPath

    Wave imgDisp = $dispPath
    Wave rowTmp  = $rowPath
    Wave bgTmp   = $bgPath
    Wave statTmp = $statPath

    SetScale/P x, DimOffset(imgIn,0), DimDelta(imgIn,0), WaveUnits(imgIn,0), imgDisp
    SetScale/P y, DimOffset(imgIn,1), DimDelta(imgIn,1), WaveUnits(imgIn,1), imgDisp
    SetScale d, 0, 0, WaveUnits(imgIn,-1), imgDisp

    if (loFrac < 0)
        loFrac = 0
    endif
    if (hiFrac > 1)
        hiFrac = 1
    endif
    if (hiFrac <= loFrac)
        loFrac = 0.02
        hiFrac = 0.995
    endif
    if (gammaVal <= 0 || numtype(gammaVal) != 0)
        gammaVal = 1
    endif
    if (bgSmoothN < 1 || numtype(bgSmoothN) != 0)
        bgSmoothN = 1
    endif

    Variable i, j
    Variable vLo, vHi, val

    for (j = 0; j < ny; j += 1)
        rowTmp = imgIn[p][j]

        if (doBgSub)
            bgTmp = rowTmp[p]
            if (bgSmoothN > 1)
                Smooth bgSmoothN, bgTmp
            endif
            rowTmp = rowTmp[p] - bgTmp[p]
            rowTmp = max(rowTmp[p], 0)
        endif

        statTmp = rowTmp[p]
        Sort statTmp, statTmp

        vLo = statTmp[round(loFrac * (nx - 1))]
        vHi = statTmp[round(hiFrac * (nx - 1))]

        if (numtype(vLo) != 0 || numtype(vHi) != 0 || vHi <= vLo)
            WaveStats/Q rowTmp
            vLo = V_min
            vHi = V_max
        endif

        if (numtype(vLo) != 0 || numtype(vHi) != 0 || vHi <= vLo)
            for (i = 0; i < nx; i += 1)
                imgDisp[i][j] = 0
            endfor
            continue
        endif

        for (i = 0; i < nx; i += 1)
            val = (rowTmp[i] - vLo) / (vHi - vLo)
            if (val < 0)
                val = 0
            endif
            if (val > 1)
                val = 1
            endif

            val = val^gammaVal
            imgDisp[i][j] = val
        endfor
    endfor

    imgDisp = max(0, min(1, imgDisp[p][q]))

    return imgDisp
End

Function/WAVE a2k1d_make_personal_soft_heat_ct(nSamp)
    Variable nSamp

    a2k1d_ensure_folder()
    ctluz_ensure_folder()

    if (nSamp < 2)
        nSamp = 256
    endif

    SVAR/Z pickName = root:ARPES_LJZ:A2K1D:a2k1d_ctPickName
    NVAR/Z invCT    = root:ARPES_LJZ:A2K1D:a2k1d_ctInvert
    NVAR/Z whiteMix = root:ARPES_LJZ:A2K1D:a2k1d_hmCTWhiteMix

    String pick = "Mualani"
    if (SVAR_Exists(pickName) && strlen(pickName) > 0)
        pick = pickName
    endif

    Variable inv = 0
    if (NVAR_Exists(invCT))
        inv = invCT
    endif

    Variable wm = 0.25
    if (NVAR_Exists(whiteMix))
        wm = whiteMix
    endif
    if (wm < 0)
        wm = 0
    endif
    if (wm > 1)
        wm = 1
    endif

    String outPath = "root:ARPES_LJZ:OUTPUT:A2K1D:a2k1d_personal_soft_heat_ct"
    Make/O/W/U/N=(nSamp,3) $outPath
    Wave ct = $outPath

    Variable i, t, q
    Variable r, g, b
    Variable mix

    for (i = 0; i < nSamp; i += 1)
        t = i / (nSamp - 1.0)
        q = t^0.85

        a2k1d_ctluz_rgb16_at_t(pick, q, inv, r, g, b)

        mix = wm * (1 - t)^1.5
        r = r * (1 - mix) + 65535 * mix
        g = g * (1 - mix) + 65535 * mix
        b = b * (1 - mix) + 65535 * mix

        ct[i][0] = max(0, min(65535, r))
        ct[i][1] = max(0, min(65535, g))
        ct[i][2] = max(0, min(65535, b))
    endfor

    return ct
End

Function a2k1d_apply_personal_soft_heat_ct_to_image(winName, imgName)
    String winName, imgName

    Wave ctLocal = a2k1d_make_personal_soft_heat_ct(256)
    String ctPath = "root:ARPES_LJZ:OUTPUT:A2K1D:a2k1d_personal_soft_heat_ct"

    String imgInst = imgName
    String imgList = ImageNameList(winName, ";")
    if (WhichListItem(imgInst, imgList, ";") < 0)
        imgInst = StringFromList(0, imgList, ";")
    endif
    if (strlen(imgInst) == 0)
        return -1
    endif

    ModifyImage/W=$winName $imgInst, ctab={0,1,$ctPath,0}
    DoUpdate

    return 0
End

Function a2k1d_btn_plot_delta_err(ctrlName) : ButtonControl
    String ctrlName

    SVAR a2k1d_baseDF    = root:ARPES_LJZ:A2K1D:a2k1d_baseDF
    NVAR a2k1d_recursive = root:ARPES_LJZ:A2K1D:a2k1d_recursive
    NVAR a2k1d_hmUnitMode  = root:ARPES_LJZ:A2K1D:a2k1d_hmUnitMode
    SVAR a2k1d_baseName  = root:ARPES_LJZ:A2K1D:a2k1d_baseName
    NVAR a2k1d_LC        = root:ARPES_LJZ:A2K1D:a2k1d_LC

    String base = a2k1d_df_with_colon(a2k1d_baseDF)
    if (!a2k1d_df_exists(base))
        Abort "Plot delta: baseDF not found."
    endif

    String wname
    if (strlen(a2k1d_baseName) > 0)
        wname = a2k1d_baseName + "_DeltaK12"
    else
        wname = "A2K1D_DeltaK12"
    endif
    DoWindow/K $wname

    String d12  = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "deltak12_k")
    String sd12 = a2k1d_find_wave_by_tail(base, a2k1d_recursive, "sigmadeltak12_k")

    if (strlen(d12) == 0)
        Abort "Plot delta: missing deltak12_k."
    endif
    if (strlen(sd12) == 0)
        Abort "Plot delta: missing sigmadeltak12_k."
    endif

    Wave wD12   = $d12
    Wave wSD12  = $sd12

    if (!WaveExists(wD12) || !WaveExists(wSD12))
        Abort "Plot delta: wave reference failed."
    endif

    if (WaveDims(wD12) != 1 || WaveDims(wSD12) != 1)
        Abort "Plot delta: waves must be 1D."
    endif

    if (DimSize(wD12,0) != DimSize(wSD12,0))
        Abort "Plot delta: deltak12_k and sigmadeltak12_k size mismatch."
    endif
    
String outDF = "root:ARPES_LJZ:OUTPUT:A2K1D:"
String axisPath
if (strlen(a2k1d_baseName) > 0)
    axisPath = outDF + a2k1d_baseName + "_AxisX"
else
    axisPath = outDF + "A2K1D_AxisX"
endif

Wave wAxis = a2k1d_make_axis_wave(DimSize(wD12,0), axisPath)

Display/N=$wname wD12 vs wAxis

ModifyGraph/W=$wname mirror=2
ModifyGraph/W=$wname mode($NameOfWave(wD12))=0
ModifyGraph/W=$wname rgb($NameOfWave(wD12))=(0,0,0)

    ErrorBars/W=$wname/RGB=(0,0,0) $NameOfWave(wD12) Y, wave=(wSD12, wSD12)

    if (a2k1d_LC == 0)
        Label/W=$wname left "Δk\\B12\\M (Å\\S-1\\M)"
    else
        Label/W=$wname left "Δk\\B12\\M (π/a)"
    endif

    Label/W=$wname bottom, a2k1d_heat_unit_label(a2k1d_hmUnitMode)

    // -------- y-axis: force lower bound to 0 --------
    Duplicate/O wD12, root:ARPES_LJZ:OUTPUT:A2K1D:a2k1d_tmp_deltaTop
    Wave tmpTop = root:ARPES_LJZ:OUTPUT:A2K1D:a2k1d_tmp_deltaTop
    tmpTop = wD12 + wSD12

    WaveStats/Q tmpTop
    Variable yHi = V_max
    if (numtype(yHi) != 0 || yHi <= 0)
        yHi = 1
    else
        yHi *= 1.08
    endif

    SetAxis/W=$wname left, 0, yHi
    SetAxis/A/W=$wname bottom
    ModifyGraph/W=$wname tickUnit(left)=1, tickUnit(bottom)=1

    KillWaves/Z tmpTop

    return 0
End

// legacy peak-guided visualization; not recommended as default paper figure because the base image contains fit-position prior.
Function/WAVE a2k1d_make_threepeak_ct(nSamp)
    Variable nSamp

    a2k1d_ensure_folder()
    if (nSamp < 2)
        nSamp = 256
    endif

    String outPath = "root:ARPES_LJZ:OUTPUT:A2K1D:a2k1d_threepeak_ct"
    Make/O/W/U/N=(nSamp,3) $outPath
    Wave ct = $outPath

    Variable i, t, u
    Variable r, g, b

    for (i=0; i<nSamp; i+=1)
        t = i/(nSamp-1.0)

        // ------------------------------------------------
        // 0.00 - 0.18 : 背景带（白 -> 浅灰蓝）
        // 0.22 - 0.46 : peak1 带（暖色：橙 -> 红）
        // 0.50 - 0.74 : peak2 带（冷色：青 -> 蓝）
        // 0.78 - 1.00 : peak3 带（紫色：淡紫 -> 洋红/紫）
        // 中间留一点过渡空隙，避免颜色串带
        // ------------------------------------------------
        if (t < 0.18)
            u = t/0.18
            r = a2k1d_lerp(65535, 57000, u)
            g = a2k1d_lerp(65535, 58500, u)
            b = a2k1d_lerp(65535, 62000, u)

        elseif (t < 0.22)
            // bg -> peak1 warm separator
            u = (t-0.18)/(0.22-0.18)
            r = a2k1d_lerp(57000, 65535, u)
            g = a2k1d_lerp(58500, 62000, u)
            b = a2k1d_lerp(62000, 56000, u)

        elseif (t < 0.46)
            // peak1: 浅暖白 -> 橙 -> 深红
            u = (t-0.22)/(0.46-0.22)
            r = a2k1d_lerp(65535, 52000, u)
            g = a2k1d_lerp(62000,  2000, u)
            b = a2k1d_lerp(56000,     0, u)

        elseif (t < 0.50)
            // peak1 -> peak2 cyan separator
            u = (t-0.46)/(0.50-0.46)
            r = a2k1d_lerp(52000, 56000, u)
            g = a2k1d_lerp( 2000, 63000, u)
            b = a2k1d_lerp(    0, 65535, u)

        elseif (t < 0.74)
            // peak2: 浅青白 -> 蓝
            u = (t-0.50)/(0.74-0.50)
            r = a2k1d_lerp(56000,     0, u)
            g = a2k1d_lerp(63000, 16000, u)
            b = a2k1d_lerp(65535, 52000, u)

        elseif (t < 0.78)
            // peak2 -> peak3 violet separator
            u = (t-0.74)/(0.78-0.74)
            r = a2k1d_lerp(    0, 62000, u)
            g = a2k1d_lerp(16000, 52000, u)
            b = a2k1d_lerp(52000, 65535, u)

        else
            // peak3: 浅紫 -> 洋红/深紫
            u = (t-0.78)/(1.00-0.78)
            r = a2k1d_lerp(62000, 36000, u)
            g = a2k1d_lerp(52000,     0, u)
            b = a2k1d_lerp(65535, 42000, u)
        endif

        r = max(0, min(65535, r))
        g = max(0, min(65535, g))
        b = max(0, min(65535, b))

        ct[i][0] = r
        ct[i][1] = g
        ct[i][2] = b
    endfor

    return ct
End

Function a2k1d_apply_threepeak_ct_to_image(winName, imgName)
    String winName, imgName

    Wave ctLocal = a2k1d_make_threepeak_ct(512)
    String ctPath = "root:ARPES_LJZ:OUTPUT:A2K1D:a2k1d_threepeak_ct"

    String imgInst = imgName
    String imgList = ImageNameList(winName, ";")
    if (WhichListItem(imgInst, imgList, ";") < 0)
        imgInst = StringFromList(0, imgList, ";")
    endif
    if (strlen(imgInst) == 0)
        return -1
    endif

    // 这里必须固定映射 0 -> 1
    // 不再做 percentile，否则 band identity 会被压坏
    ModifyImage/W=$winName $imgInst, ctab={0,1,$ctPath,0}
    DoUpdate

    return 0
End

Function a2k1d_axis_value_from_index(idx)
    Variable idx

    NVAR a2k1d_hmY0       = root:ARPES_LJZ:A2K1D:a2k1d_hmY0
    NVAR a2k1d_hmDY       = root:ARPES_LJZ:A2K1D:a2k1d_hmDY
    NVAR a2k1d_hmUnitMode = root:ARPES_LJZ:A2K1D:a2k1d_hmUnitMode
    NVAR a2k1d_hmYMul     = root:ARPES_LJZ:A2K1D:a2k1d_hmYMul

    Variable v = a2k1d_hmY0 + idx*a2k1d_hmDY
    if (a2k1d_hmUnitMode == 2)
        v *= a2k1d_hmYMul
    endif
    return v
End

Function a2k1d_axis_delta_value()
    NVAR a2k1d_hmDY       = root:ARPES_LJZ:A2K1D:a2k1d_hmDY
    NVAR a2k1d_hmUnitMode = root:ARPES_LJZ:A2K1D:a2k1d_hmUnitMode
    NVAR a2k1d_hmYMul     = root:ARPES_LJZ:A2K1D:a2k1d_hmYMul

    Variable dv = a2k1d_hmDY
    if (a2k1d_hmUnitMode == 2)
        dv *= a2k1d_hmYMul
    endif
    return dv
End

Function/WAVE a2k1d_make_axis_wave(nPts, outPath)
    Variable nPts
    String outPath

    Make/O/D/N=(nPts) $outPath
    Wave w = $outPath

    Variable i
    for (i=0; i<nPts; i+=1)
        w[i] = a2k1d_axis_value_from_index(i)
    endfor

    return w
End
