#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

//============================================================
// SliceGallery v1 - Module 1
// State + Scan
// Runtime DF: root:ARPES_LJZ:SliceGallery
//============================================================
Menu "ARPES_LJZ"
    "SliceGallery (LJZ)", SliceGallery_LJZ()
End

//============================================================
// Helpers
//============================================================

Function sg_ensure_folder()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:SliceGallery
    NewDataFolder/O root:ARPES_LJZ:SliceGallery:TMP
End


Function/S sg_df_with_colon(inStr)
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


Function sg_df_exists(dfStr)
    String dfStr
    String s = sg_df_with_colon(dfStr)

    DFREF dfr = $s
    return DataFolderRefStatus(dfr) != 0
End


// 返回较短的显示名；真实路径始终保存在 LB_Path 中
// 例：root:FD1:RUN3:mywave  ->  RUN3:mywave
//    root:FD1:mywave       ->  FD1:mywave
//    root:mywave           ->  mywave
Function/S sg_make_display_name_from_path(fullPath)
    String fullPath

    Variable n = ItemsInList(fullPath, ":")
    if (n <= 0)
        return fullPath
    endif

    String waveName = StringFromList(n - 1, fullPath, ":")
    String f1 = "", f2 = ""

    if (n >= 2)
        f2 = StringFromList(n - 2, fullPath, ":")
    endif
    if (n >= 3)
        f1 = StringFromList(n - 3, fullPath, ":")
    endif

    if (strlen(f2) == 0 || StringMatch(f2, "root"))
        return waveName
    endif

    if (strlen(f1) == 0 || StringMatch(f1, "root"))
        return f2 + ":" + waveName
    endif

    return f1 + ":" + f2 + ":" + waveName
End


Function sg_wave_is_valid_3d(w)
    Wave w
    if (!WaveExists(w))
        return 0
    endif
    return (WaveDims(w) == 3)
End


Function sg_reset_cached_wave_info()
    sg_ensure_folder()

    NVAR dim0_n    = root:ARPES_LJZ:SliceGallery:dim0_n
    NVAR dim1_n    = root:ARPES_LJZ:SliceGallery:dim1_n
    NVAR dim2_n    = root:ARPES_LJZ:SliceGallery:dim2_n
    NVAR dim0_off  = root:ARPES_LJZ:SliceGallery:dim0_off
    NVAR dim1_off  = root:ARPES_LJZ:SliceGallery:dim1_off
    NVAR dim2_off  = root:ARPES_LJZ:SliceGallery:dim2_off
    NVAR dim0_del  = root:ARPES_LJZ:SliceGallery:dim0_del
    NVAR dim1_del  = root:ARPES_LJZ:SliceGallery:dim1_del
    NVAR dim2_del  = root:ARPES_LJZ:SliceGallery:dim2_del
    NVAR dim2_vmin = root:ARPES_LJZ:SliceGallery:dim2_vmin
    NVAR dim2_vmax = root:ARPES_LJZ:SliceGallery:dim2_vmax

    dim0_n    = NaN
    dim1_n    = NaN
    dim2_n    = NaN
    dim0_off  = NaN
    dim1_off  = NaN
    dim2_off  = NaN
    dim0_del  = NaN
    dim1_del  = NaN
    dim2_del  = NaN
    dim2_vmin = NaN
    dim2_vmax = NaN
End


//============================================================
// State init
//============================================================

Function sg_init_defaults_if_needed()
    sg_ensure_folder()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:SliceGallery

    // ---------- list waves ----------
    Wave/T/Z LB_Disp = root:ARPES_LJZ:SliceGallery:LB_Disp
    if (!WaveExists(LB_Disp))
        Make/O/T/N=0 LB_Disp
    endif

    Wave/T/Z LB_Path = root:ARPES_LJZ:SliceGallery:LB_Path
    if (!WaveExists(LB_Path))
        Make/O/T/N=0 LB_Path
    endif

    Wave/U/B/Z LB_Sel = root:ARPES_LJZ:SliceGallery:LB_Sel
    if (!WaveExists(LB_Sel))
        Make/O/U/B/N=0 LB_Sel
    endif

    // ---------- layer selection result ----------
    Wave/Z selLayers = root:ARPES_LJZ:SliceGallery:selLayers
    if (!WaveExists(selLayers))
        Make/O/N=0 selLayers
    endif

    Wave/Z selValuesDim2 = root:ARPES_LJZ:SliceGallery:selValuesDim2
    if (!WaveExists(selValuesDim2))
        Make/O/N=0 selValuesDim2
    endif

    // ---------- strings ----------
    SVAR/Z baseDF = root:ARPES_LJZ:SliceGallery:baseDF
    if (!SVAR_Exists(baseDF))
        String/G baseDF = "root:"
    endif

    SVAR/Z targetWavePath = root:ARPES_LJZ:SliceGallery:targetWavePath
    if (!SVAR_Exists(targetWavePath))
        String/G targetWavePath = ""
    endif

    SVAR/Z layoutMode = root:ARPES_LJZ:SliceGallery:layoutMode
    if (!SVAR_Exists(layoutMode))
        String/G layoutMode = "Auto"
    endif

    SVAR/Z selectionMode = root:ARPES_LJZ:SliceGallery:selectionMode
    if (!SVAR_Exists(selectionMode))
        String/G selectionMode = "Manual"
    endif

    SVAR/Z ctPick = root:ARPES_LJZ:SliceGallery:ctPick
    if (!SVAR_Exists(ctPick))
        String/G ctPick = "Current"
    endif
    
    SVAR/Z ctMenuList = root:ARPES_LJZ:SliceGallery:ctMenuList
    if (!SVAR_Exists(ctMenuList))
        String/G ctMenuList = "Current"
    endif
    
    Wave/T/Z CT_LB_Items = root:ARPES_LJZ:SliceGallery:CT_LB_Items
    if (!WaveExists(CT_LB_Items))
        Make/O/T/N=0 CT_LB_Items
    endif

    Wave/U/B/Z CT_LB_Sel = root:ARPES_LJZ:SliceGallery:CT_LB_Sel
    if (!WaveExists(CT_LB_Sel))
        Make/O/U/B/N=0 CT_LB_Sel
    endif
    
    SVAR/Z previewWinName = root:ARPES_LJZ:SliceGallery:previewWinName
    if (!SVAR_Exists(previewWinName))
        String/G previewWinName = "SG_PREVIEW"
    endif
    
    SVAR/Z renderStyle = root:ARPES_LJZ:SliceGallery:renderStyle
    if (!SVAR_Exists(renderStyle))
        String/G renderStyle = "LegacyTight"
    endif

    SVAR/Z exportWinName = root:ARPES_LJZ:SliceGallery:exportWinName
    if (!SVAR_Exists(exportWinName))
        String/G exportWinName = ""
    endif

    SVAR/Z manualInputStr = root:ARPES_LJZ:SliceGallery:manualInputStr
    if (!SVAR_Exists(manualInputStr))
        String/G manualInputStr = "0,1,2,3,4,5"
    endif

    SVAR/Z dim2InputStr = root:ARPES_LJZ:SliceGallery:dim2InputStr
    if (!SVAR_Exists(dim2InputStr))
        String/G dim2InputStr = ""
    endif
    SVAR/Z exportBaseName = root:ARPES_LJZ:SliceGallery:exportBaseName
    if (!SVAR_Exists(exportBaseName))
        String/G exportBaseName = "SGExport"
    endif
    // ---------- numerics ----------
    NVAR/Z recursive = root:ARPES_LJZ:SliceGallery:recursive
    if (!NVAR_Exists(recursive))
        Variable/G recursive = 0
    endif

    NVAR/Z panelCount = root:ARPES_LJZ:SliceGallery:panelCount
    if (!NVAR_Exists(panelCount))
        Variable/G panelCount = 6
    endif

    NVAR/Z startLayer = root:ARPES_LJZ:SliceGallery:startLayer
    if (!NVAR_Exists(startLayer))
        Variable/G startLayer = NaN
    endif

    NVAR/Z endLayer = root:ARPES_LJZ:SliceGallery:endLayer
    if (!NVAR_Exists(endLayer))
        Variable/G endLayer = NaN
    endif

    NVAR/Z xUse = root:ARPES_LJZ:SliceGallery:xUse
    if (!NVAR_Exists(xUse))
        Variable/G xUse = 1
    endif

    NVAR/Z xMin = root:ARPES_LJZ:SliceGallery:xMin
    if (!NVAR_Exists(xMin))
        Variable/G xMin = -0.27
    endif

    NVAR/Z xMax = root:ARPES_LJZ:SliceGallery:xMax
    if (!NVAR_Exists(xMax))
        Variable/G xMax = -0.06
    endif

    NVAR/Z yUse = root:ARPES_LJZ:SliceGallery:yUse
    if (!NVAR_Exists(yUse))
        Variable/G yUse = 0
    endif

    NVAR/Z yMin = root:ARPES_LJZ:SliceGallery:yMin
    if (!NVAR_Exists(yMin))
        Variable/G yMin = NaN
    endif

    NVAR/Z yMax = root:ARPES_LJZ:SliceGallery:yMax
    if (!NVAR_Exists(yMax))
        Variable/G yMax = NaN
    endif

    NVAR/Z useLUT = root:ARPES_LJZ:SliceGallery:useLUT
    if (!NVAR_Exists(useLUT))
        Variable/G useLUT = 1
    endif

    NVAR/Z invertColors = root:ARPES_LJZ:SliceGallery:invertColors
    if (!NVAR_Exists(invertColors))
        Variable/G invertColors = 0
    endif

    NVAR/Z displayMode = root:ARPES_LJZ:SliceGallery:displayMode
    if (!NVAR_Exists(displayMode))
        Variable/G displayMode = 0    // 0 raw, 1 d2/dx2, 2 d2/dy2, 3 d2/dx2+d2/dy2
    endif

    NVAR/Z colorMode = root:ARPES_LJZ:SliceGallery:colorMode
    if (!NVAR_Exists(colorMode))
        Variable/G colorMode = 1      // 0 per-panel, 1 shared, 2 manual
    endif

    NVAR/Z cMin = root:ARPES_LJZ:SliceGallery:cMin
    if (!NVAR_Exists(cMin))
        Variable/G cMin = NaN
    endif

    NVAR/Z cMax = root:ARPES_LJZ:SliceGallery:cMax
    if (!NVAR_Exists(cMax))
        Variable/G cMax = NaN
    endif

    NVAR/Z labelMode = root:ARPES_LJZ:SliceGallery:labelMode
    if (!NVAR_Exists(labelMode))
        Variable/G labelMode = 2      // 0 none, 1 index, 2 dim2 value, 3 both
    endif

    NVAR/Z labelType = root:ARPES_LJZ:SliceGallery:labelType
    if (!NVAR_Exists(labelType))
        Variable/G labelType = 2      // 0 none, 1 fluence, 2 delay, 3 temp
    endif

    NVAR/Z fluenceCoeff = root:ARPES_LJZ:SliceGallery:fluenceCoeff
    if (!NVAR_Exists(fluenceCoeff))
        Variable/G fluenceCoeff = 60
    endif

    NVAR/Z tbFont = root:ARPES_LJZ:SliceGallery:tbFont
    if (!NVAR_Exists(tbFont))
        Variable/G tbFont = 12
    endif

    NVAR/Z tbX = root:ARPES_LJZ:SliceGallery:tbX
    if (!NVAR_Exists(tbX))
        Variable/G tbX = 20
    endif

    NVAR/Z tbY = root:ARPES_LJZ:SliceGallery:tbY
    if (!NVAR_Exists(tbY))
        Variable/G tbY = 25
    endif

    NVAR/Z sortLayers = root:ARPES_LJZ:SliceGallery:sortLayers
    if (!NVAR_Exists(sortLayers))
        Variable/G sortLayers = 0
    endif

    NVAR/Z dedupLayers = root:ARPES_LJZ:SliceGallery:dedupLayers
    if (!NVAR_Exists(dedupLayers))
        Variable/G dedupLayers = 0
    endif

    NVAR/Z reverseOrder = root:ARPES_LJZ:SliceGallery:reverseOrder
    if (!NVAR_Exists(reverseOrder))
        Variable/G reverseOrder = 0
    endif

    // ---------- cached target-wave info ----------
    NVAR/Z dim0_n = root:ARPES_LJZ:SliceGallery:dim0_n
    if (!NVAR_Exists(dim0_n))
        Variable/G dim0_n = NaN
    endif

    NVAR/Z dim1_n = root:ARPES_LJZ:SliceGallery:dim1_n
    if (!NVAR_Exists(dim1_n))
        Variable/G dim1_n = NaN
    endif

    NVAR/Z dim2_n = root:ARPES_LJZ:SliceGallery:dim2_n
    if (!NVAR_Exists(dim2_n))
        Variable/G dim2_n = NaN
    endif

    NVAR/Z dim0_off = root:ARPES_LJZ:SliceGallery:dim0_off
    if (!NVAR_Exists(dim0_off))
        Variable/G dim0_off = NaN
    endif

    NVAR/Z dim1_off = root:ARPES_LJZ:SliceGallery:dim1_off
    if (!NVAR_Exists(dim1_off))
        Variable/G dim1_off = NaN
    endif

    NVAR/Z dim2_off = root:ARPES_LJZ:SliceGallery:dim2_off
    if (!NVAR_Exists(dim2_off))
        Variable/G dim2_off = NaN
    endif

    NVAR/Z dim0_del = root:ARPES_LJZ:SliceGallery:dim0_del
    if (!NVAR_Exists(dim0_del))
        Variable/G dim0_del = NaN
    endif

    NVAR/Z dim1_del = root:ARPES_LJZ:SliceGallery:dim1_del
    if (!NVAR_Exists(dim1_del))
        Variable/G dim1_del = NaN
    endif

    NVAR/Z dim2_del = root:ARPES_LJZ:SliceGallery:dim2_del
    if (!NVAR_Exists(dim2_del))
        Variable/G dim2_del = NaN
    endif

    NVAR/Z dim2_vmin = root:ARPES_LJZ:SliceGallery:dim2_vmin
    if (!NVAR_Exists(dim2_vmin))
        Variable/G dim2_vmin = NaN
    endif

    NVAR/Z dim2_vmax = root:ARPES_LJZ:SliceGallery:dim2_vmax
    if (!NVAR_Exists(dim2_vmax))
        Variable/G dim2_vmax = NaN
    endif

    SetDataFolder df0
End


//============================================================
// Scan
//============================================================

// 递归扫描：返回完整路径列表，元素形如
// root:folderA:folderB:waveName;
Function/S sg_collect_3d_waves_recursive(baseDF)
    String baseDF

    String df0 = GetDataFolder(1)
    String outList = ""

    String base = sg_df_with_colon(baseDF)
    if (!sg_df_exists(base))
        return ""
    endif

    SetDataFolder $base

    String here = WaveList("*", ";", "DIMS:3")
    Variable i, n = ItemsInList(here, ";")
    for (i = 0; i < n; i += 1)
        String wn = StringFromList(i, here, ";")
        if (strlen(wn) == 0)
            continue
        endif
        outList += base + wn + ";"
    endfor

    String subList = DataFolderDir(2)      // folder1;folder2;...
    Variable m = ItemsInList(subList, ";")
    for (i = 0; i < m; i += 1)
        String fd = StringFromList(i, subList, ";")
        if (strlen(fd) == 0)
            continue
        endif
        outList += sg_collect_3d_waves_recursive(base + fd + ":")
    endfor

    SetDataFolder df0
    return outList
End


Function sg_rebuild_wave_list()
    sg_init_defaults_if_needed()

    SVAR baseDF         = root:ARPES_LJZ:SliceGallery:baseDF
    SVAR targetWavePath = root:ARPES_LJZ:SliceGallery:targetWavePath
    NVAR recursive      = root:ARPES_LJZ:SliceGallery:recursive

    Wave/T   LB_Disp    = root:ARPES_LJZ:SliceGallery:LB_Disp
    Wave/T   LB_Path    = root:ARPES_LJZ:SliceGallery:LB_Path
    Wave/U/B LB_Sel     = root:ARPES_LJZ:SliceGallery:LB_Sel

    String oldTarget = targetWavePath
    String base = sg_df_with_colon(baseDF)

    Redimension/N=0 LB_Disp, LB_Path, LB_Sel
    targetWavePath = ""
    sg_reset_cached_wave_info()

    if (!sg_df_exists(base))
        base = "root:"
    endif
    baseDF = base

    String listStr = ""
    Variable i, n

    if (recursive)
        listStr = sg_collect_3d_waves_recursive(base)
        n = ItemsInList(listStr, ";")
        if (n > 0)
            Redimension/N=(n) LB_Disp, LB_Path, LB_Sel
            for (i = 0; i < n; i += 1)
                String fullPath = StringFromList(i, listStr, ";")
                LB_Path[i] = fullPath
                LB_Disp[i] = sg_make_display_name_from_path(fullPath)
                LB_Sel[i] = 0
            endfor
        endif
    else
        String df0 = GetDataFolder(1)
        SetDataFolder $base
        listStr = WaveList("*", ";", "DIMS:3")
        SetDataFolder df0

        n = ItemsInList(listStr, ";")
        if (n > 0)
            Redimension/N=(n) LB_Disp, LB_Path, LB_Sel
            for (i = 0; i < n; i += 1)
                String wn = StringFromList(i, listStr, ";")
                LB_Disp[i] = wn
                LB_Path[i] = base + wn
                LB_Sel[i] = 0
            endfor
        endif
    endif

    // 尝试恢复旧选择
    n = DimSize(LB_Path, 0)
    for (i = 0; i < n; i += 1)
        if (StringMatch(LB_Path[i], oldTarget))
            LB_Sel = 0
            LB_Sel[i] = 1
            targetWavePath = LB_Path[i]
            break
        endif
    endfor

    if (strlen(targetWavePath) > 0)
        sg_refresh_target_wave_info()
    else
        sg_reset_cached_wave_info()
    endif

    sg_sync_panel_from_state()
    return 0
End


//============================================================
// Target wave info
//============================================================

Function sg_refresh_target_wave_info()
    sg_init_defaults_if_needed()

    SVAR targetWavePath = root:ARPES_LJZ:SliceGallery:targetWavePath

    NVAR dim0_n    = root:ARPES_LJZ:SliceGallery:dim0_n
    NVAR dim1_n    = root:ARPES_LJZ:SliceGallery:dim1_n
    NVAR dim2_n    = root:ARPES_LJZ:SliceGallery:dim2_n
    NVAR dim0_off  = root:ARPES_LJZ:SliceGallery:dim0_off
    NVAR dim1_off  = root:ARPES_LJZ:SliceGallery:dim1_off
    NVAR dim2_off  = root:ARPES_LJZ:SliceGallery:dim2_off
    NVAR dim0_del  = root:ARPES_LJZ:SliceGallery:dim0_del
    NVAR dim1_del  = root:ARPES_LJZ:SliceGallery:dim1_del
    NVAR dim2_del  = root:ARPES_LJZ:SliceGallery:dim2_del
    NVAR dim2_vmin = root:ARPES_LJZ:SliceGallery:dim2_vmin
    NVAR dim2_vmax = root:ARPES_LJZ:SliceGallery:dim2_vmax

    if (strlen(targetWavePath) == 0)
        sg_reset_cached_wave_info()
        sg_sync_panel_from_state()
        return -1
    endif

    Wave/Z w = $targetWavePath
    if (!WaveExists(w) || !sg_wave_is_valid_3d(w))
        sg_reset_cached_wave_info()
        sg_sync_panel_from_state()
        return -1
    endif

    dim0_n   = DimSize(w, 0)
    dim1_n   = DimSize(w, 1)
    dim2_n   = DimSize(w, 2)
    dim0_off = DimOffset(w, 0)
    dim1_off = DimOffset(w, 1)
    dim2_off = DimOffset(w, 2)
    dim0_del = DimDelta(w, 0)
    dim1_del = DimDelta(w, 1)
    dim2_del = DimDelta(w, 2)

    dim2_vmin = dim2_off
    dim2_vmax = dim2_off + dim2_del * (dim2_n - 1)

    sg_sync_panel_from_state()
    return 0
End


Function sg_update_selected_wave_from_row(row)
    Variable row

    sg_init_defaults_if_needed()

    Wave/T   LB_Path = root:ARPES_LJZ:SliceGallery:LB_Path
    Wave/U/B LB_Sel  = root:ARPES_LJZ:SliceGallery:LB_Sel
    SVAR targetWavePath = root:ARPES_LJZ:SliceGallery:targetWavePath

    Variable n = DimSize(LB_Path, 0)
    if (row < 0 || row >= n)
        return -1
    endif

    LB_Sel = 0
    LB_Sel[row] = 1

    targetWavePath = LB_Path[row]
    sg_refresh_target_wave_info()
    sg_sync_panel_from_state()

    return 0
End


//============================================================
// Panel sync
// 这一层故意做成“安全 no-op”风格：
// 如果 panel 还没写，函数不会报错。
// 如果 panel 后面用了这些控件名，它就能自动刷新。
//============================================================




//============================================================
// UI callbacks
//============================================================

Function sg_lb_proc(ctrlName, row, col, eventCode) : ListBoxControl
    String ctrlName
    Variable row, col, eventCode

    // 4 = mouse up selection change
    if (eventCode != 4)
        return 0
    endif

    sg_update_selected_wave_from_row(row)
    return 0
End


Function sg_btn_scan(ctrlName) : ButtonControl
    String ctrlName
    sg_rebuild_wave_list()
    return 0
End


//============================================================
// Optional helpers for later modules
//============================================================

// 给定当前 target wave 的 dim2 index，返回 physical value
Function sg_layer_value_from_index(w, idx)
    Wave w
    Variable idx

    if (!WaveExists(w) || WaveDims(w) != 3)
        return NaN
    endif

    return DimOffset(w, 2) + DimDelta(w, 2) * idx
End


// 根据 dim2 physical value 返回最近 index
Function sg_index_from_dim2_value(w, val)
    Wave w
    Variable val

    if (!WaveExists(w) || WaveDims(w) != 3)
        return NaN
    endif

    Variable d = DimDelta(w, 2)
    Variable n = DimSize(w, 2)
    if (numtype(d) != 0 || abs(d) < 1e-15 || n <= 0)
        return NaN
    endif

    Variable idx = round((val - DimOffset(w, 2)) / d)
    idx = max(0, min(n - 1, idx))
    return idx
End


//============================================================
// Debug / init entry (temporary)
// 先用于测试模块 1，本身不依赖 panel
//============================================================

Proc SliceGallery_LJZ_Init()
    sg_init_defaults_if_needed()
    sg_rebuild_wave_list()
End

//============================================================
// SliceGallery v1 - Module 2
// Layer Selection
// Depends on Module 1
//============================================================


//============================================================
// Basic helpers
//============================================================

// 判断当前 targetWavePath 是否对应一个合法 3D wave
// doAlertFlag = 1 时弹窗提示
Function sg_target_wave_is_ready(doAlertFlag)
    Variable doAlertFlag

    SVAR targetWavePath = root:ARPES_LJZ:SliceGallery:targetWavePath

    if (strlen(targetWavePath) == 0)
        if (doAlertFlag)
            DoAlert 0, "SliceGallery: No target 3D wave selected."
        endif
        return 0
    endif

    Wave/Z w = $targetWavePath
    if (!WaveExists(w) || WaveDims(w) != 3)
        if (doAlertFlag)
            DoAlert 0, "SliceGallery: selected target is not a valid 3D wave."
        endif
        return 0
    endif

    return 1
End


// 把用户输入统一整理成 ; 分隔的列表字符串
// 支持逗号、分号、空格、tab、回车
Function/S sg_normalize_number_list_string(inStr)
    String inStr

    String s = inStr
    s = ReplaceString(",", s, ";")
    s = ReplaceString(" ", s, ";")
    s = ReplaceString("\t", s, ";")
    s = ReplaceString("\r", s, ";")
    s = ReplaceString("\n", s, ";")

    return s
End


//============================================================
// In-place wave utilities
//============================================================

// 1D 数值 wave 升序排序（简单版，N 很小时足够）
Function sg_sort_numeric_wave_ascending(wv)
    Wave wv

    Variable n = DimSize(wv, 0)
    Variable i, j, tempVal

    if (n <= 1)
        return 0
    endif

    for (i = 0; i < n - 1; i += 1)
        for (j = i + 1; j < n; j += 1)
            if (wv[j] < wv[i])
                tempVal = wv[i]
                wv[i] = wv[j]
                wv[j] = tempVal
            endif
        endfor
    endfor

    return 0
End


// 1D 数值 wave 原地反序
Function sg_reverse_numeric_wave(wv)
    Wave wv

    Variable n = DimSize(wv, 0)
    Variable i, j, tempVal

    if (n <= 1)
        return 0
    endif

    for (i = 0; i < floor(n / 2); i += 1)
        j = n - 1 - i
        tempVal = wv[i]
        wv[i] = wv[j]
        wv[j] = tempVal
    endfor

    return 0
End


// 保持原顺序去重
Function sg_dedup_numeric_wave_keep_order(wv)
    Wave wv

    Variable n = DimSize(wv, 0)
    if (n <= 1)
        return 0
    endif

    Make/FREE/D/N=(n) tempKeep
    Variable outCount = 0
    Variable i, j, v, foundSame

    for (i = 0; i < n; i += 1)
        v = wv[i]
        foundSame = 0

        for (j = 0; j < outCount; j += 1)
            if (tempKeep[j] == v)
                foundSame = 1
                break
            endif
        endfor

        if (!foundSame)
            tempKeep[outCount] = v
            outCount += 1
        endif
    endfor

    Redimension/N=(outCount) tempKeep
    Duplicate/O tempKeep, wv

    return 0
End


//============================================================
// Selection bookkeeping
//============================================================

// 根据 selLayers 更新 selValuesDim2
Function sg_update_sel_values_from_layers()
    sg_init_defaults_if_needed()

    Wave selLayers      = root:ARPES_LJZ:SliceGallery:selLayers
    Wave selValuesDim2  = root:ARPES_LJZ:SliceGallery:selValuesDim2
    SVAR targetWavePath = root:ARPES_LJZ:SliceGallery:targetWavePath

    if (!sg_target_wave_is_ready(0))
        Redimension/N=0 selValuesDim2
        return -1
    endif

    Wave w = $targetWavePath
    Variable n = DimSize(selLayers, 0)

    Redimension/N=(n) selValuesDim2
    if (n <= 0)
        return 0
    endif

    selValuesDim2 = sg_layer_value_from_index(w, selLayers[p])
    return 0
End


// 对 selLayers 做统一后处理：
// 1) round
// 2) clamp 到合法范围
// 3) 可选 sort
// 4) 可选 dedup
// 5) 可选 reverse
// 6) 更新 selValuesDim2
Function sg_postprocess_layers()
    sg_init_defaults_if_needed()

    if (!sg_target_wave_is_ready(1))
        return -1
    endif

    Wave selLayers     = root:ARPES_LJZ:SliceGallery:selLayers
    NVAR sortLayers    = root:ARPES_LJZ:SliceGallery:sortLayers
    NVAR dedupLayers   = root:ARPES_LJZ:SliceGallery:dedupLayers
    NVAR reverseOrder  = root:ARPES_LJZ:SliceGallery:reverseOrder
    NVAR dim2_n        = root:ARPES_LJZ:SliceGallery:dim2_n

    Variable n = DimSize(selLayers, 0)
    if (n <= 0)
        sg_update_sel_values_from_layers()
        return 0
    endif

    // round + clamp
    selLayers = round(selLayers[p])
    selLayers = max(0, min(dim2_n - 1, selLayers[p]))

    if (sortLayers)
        sg_sort_numeric_wave_ascending(selLayers)
    endif

    if (dedupLayers)
        sg_dedup_numeric_wave_keep_order(selLayers)
    endif

    if (reverseOrder)
        sg_reverse_numeric_wave(selLayers)
    endif

    sg_update_sel_values_from_layers()
    return 0
End


//============================================================
// Build layers: Manual
//============================================================

// 从字符串解析 index 列表，写入 selLayers
// 返回最终条数
Function sg_build_layers_manual(inputStr)
    String inputStr

    sg_init_defaults_if_needed()

    Wave selLayers = root:ARPES_LJZ:SliceGallery:selLayers

    if (!sg_target_wave_is_ready(1))
        Redimension/N=0 selLayers
        return -1
    endif

    String s = sg_normalize_number_list_string(inputStr)
    Variable itemCount = ItemsInList(s, ";")

    if (itemCount <= 0)
        Redimension/N=0 selLayers
        sg_update_sel_values_from_layers()
        return 0
    endif

    Make/FREE/D/N=(itemCount) tempVals
    Variable goodCount = 0
    Variable i, v
    String tok

    for (i = 0; i < itemCount; i += 1)
        tok = StringFromList(i, s, ";")
        if (strlen(tok) == 0)
            continue
        endif

        v = str2num(tok)
        if (numtype(v) != 0)
            continue
        endif

        tempVals[goodCount] = v
        goodCount += 1
    endfor

    Redimension/N=(goodCount) tempVals
    Duplicate/O tempVals, selLayers

    sg_postprocess_layers()
    return DimSize(selLayers, 0)
End


//============================================================
// Build layers: Even spacing
//============================================================

// 在 [idxStart, idxEnd] 内等间隔选 nPanels 张
// 若 idxStart/idxEnd 为 NaN，则默认取全范围
Function sg_build_layers_even(nPanels, idxStart, idxEnd)
    Variable nPanels, idxStart, idxEnd

    sg_init_defaults_if_needed()

    Wave selLayers = root:ARPES_LJZ:SliceGallery:selLayers
    NVAR dim2_n    = root:ARPES_LJZ:SliceGallery:dim2_n

    if (!sg_target_wave_is_ready(1))
        Redimension/N=0 selLayers
        return -1
    endif

    nPanels = round(nPanels)
    if (numtype(nPanels) != 0 || nPanels < 1)
        DoAlert 0, "SliceGallery: panelCount must be >= 1."
        return -1
    endif

    Variable firstIdx, lastIdx, tempVal
    firstIdx = idxStart
    lastIdx  = idxEnd

    if (numtype(firstIdx) != 0)
        firstIdx = 0
    endif
    if (numtype(lastIdx) != 0)
        lastIdx = dim2_n - 1
    endif

    firstIdx = round(firstIdx)
    lastIdx  = round(lastIdx)

    firstIdx = max(0, min(dim2_n - 1, firstIdx))
    lastIdx  = max(0, min(dim2_n - 1, lastIdx))

    if (firstIdx > lastIdx)
        tempVal = firstIdx
        firstIdx = lastIdx
        lastIdx = tempVal
    endif

    Make/FREE/D/N=(nPanels) tempVals
    Variable i

    if (nPanels == 1)
        tempVals[0] = round((firstIdx + lastIdx) / 2)
    else
        for (i = 0; i < nPanels; i += 1)
            tempVals[i] = round(firstIdx + (lastIdx - firstIdx) * i / (nPanels - 1))
        endfor
    endif

    Duplicate/O tempVals, selLayers

    sg_postprocess_layers()
    return DimSize(selLayers, 0)
End


//============================================================
// Build layers: by dim2 physical values
//============================================================

// 输入一串 dim2 物理值，映射到最近 layer index
Function sg_build_layers_by_dim2(inputStr)
    String inputStr

    sg_init_defaults_if_needed()

    Wave selLayers      = root:ARPES_LJZ:SliceGallery:selLayers
    SVAR targetWavePath = root:ARPES_LJZ:SliceGallery:targetWavePath

    if (!sg_target_wave_is_ready(1))
        Redimension/N=0 selLayers
        return -1
    endif

    Wave w = $targetWavePath
    Variable d2 = DimDelta(w, 2)
    Variable n2 = DimSize(w, 2)

    if (numtype(d2) != 0 || abs(d2) < 1e-15 || n2 <= 0)
        DoAlert 0, "SliceGallery: dim2 scaling is invalid for Dim2Values selection."
        return -1
    endif

    String s = sg_normalize_number_list_string(inputStr)
    Variable itemCount = ItemsInList(s, ";")

    if (itemCount <= 0)
        Redimension/N=0 selLayers
        sg_update_sel_values_from_layers()
        return 0
    endif

    Make/FREE/D/N=(itemCount) tempVals
    Variable goodCount = 0
    Variable i, v, idx
    String tok

    for (i = 0; i < itemCount; i += 1)
        tok = StringFromList(i, s, ";")
        if (strlen(tok) == 0)
            continue
        endif

        v = str2num(tok)
        if (numtype(v) != 0)
            continue
        endif

        idx = sg_index_from_dim2_value(w, v)
        if (numtype(idx) != 0)
            continue
        endif

        tempVals[goodCount] = idx
        goodCount += 1
    endfor

    Redimension/N=(goodCount) tempVals
    Duplicate/O tempVals, selLayers

    sg_postprocess_layers()
    return DimSize(selLayers, 0)
End


//============================================================
// Unified entry
//============================================================

// 根据全局 selectionMode 自动调用对应的 build 函数
Function sg_build_layers_from_current_selection()
    sg_init_defaults_if_needed()

    SVAR selectionMode = root:ARPES_LJZ:SliceGallery:selectionMode
    SVAR manualInputStr = root:ARPES_LJZ:SliceGallery:manualInputStr
    SVAR dim2InputStr   = root:ARPES_LJZ:SliceGallery:dim2InputStr

    NVAR panelCount = root:ARPES_LJZ:SliceGallery:panelCount
    NVAR startLayer = root:ARPES_LJZ:SliceGallery:startLayer
    NVAR endLayer   = root:ARPES_LJZ:SliceGallery:endLayer

    if (StringMatch(selectionMode, "Manual"))
        return sg_build_layers_manual(manualInputStr)
    endif

    if (StringMatch(selectionMode, "EvenSpacing"))
        return sg_build_layers_even(panelCount, startLayer, endLayer)
    endif

    if (StringMatch(selectionMode, "Dim2Values"))
        return sg_build_layers_by_dim2(dim2InputStr)
    endif

    DoAlert 0, "SliceGallery: unknown selectionMode."
    return -1
End


//============================================================
// String summaries
//============================================================

Function/S sg_layers_to_string()
    sg_init_defaults_if_needed()

    Wave selLayers = root:ARPES_LJZ:SliceGallery:selLayers
    Variable n = DimSize(selLayers, 0)

    if (n <= 0)
        return ""
    endif

    String outStr = ""
    Variable i

    for (i = 0; i < n; i += 1)
        outStr += num2str(selLayers[i])
        if (i < n - 1)
            outStr += ", "
        endif
    endfor

    return outStr
End


Function/S sg_values_to_string()
    sg_init_defaults_if_needed()

    Wave selValuesDim2 = root:ARPES_LJZ:SliceGallery:selValuesDim2
    Variable n = DimSize(selValuesDim2, 0)

    if (n <= 0)
        return ""
    endif

    String outStr = ""
    Variable i

    for (i = 0; i < n; i += 1)
        outStr += num2str(selValuesDim2[i])
        if (i < n - 1)
            outStr += ", "
        endif
    endfor

    return outStr
End


//============================================================
// Small utilities
//============================================================

Function sg_clear_selected_layers()
    sg_init_defaults_if_needed()

    Wave selLayers     = root:ARPES_LJZ:SliceGallery:selLayers
    Wave selValuesDim2 = root:ARPES_LJZ:SliceGallery:selValuesDim2

    Redimension/N=0 selLayers, selValuesDim2
    return 0
End


//============================================================
// UI callbacks for Module 2
//============================================================

Function sg_btn_build_layers(ctrlName) : ButtonControl
    String ctrlName

    Variable nMade = sg_build_layers_from_current_selection()
    if (nMade >= 0)
        Print "SliceGallery selLayers = {" + sg_layers_to_string() + "}"
        Print "SliceGallery selValuesDim2 = {" + sg_values_to_string() + "}"
    endif

    return 0
End


Function sg_btn_clear_layers(ctrlName) : ButtonControl
    String ctrlName

    sg_clear_selected_layers()
    Print "SliceGallery selLayers cleared."
    return 0
End


Function sg_pm_selection_proc(ctrlName, popNumber, popText) : PopupMenuControl
    String ctrlName
    Variable popNumber
    String popText

    SVAR selectionMode = root:ARPES_LJZ:SliceGallery:selectionMode
    selectionMode = popText
    return 0
End


//============================================================
// Debug / test entry (temporary)
//============================================================

Proc SliceGallery_LJZ_TestLayers()
    Variable nMade

    nMade = sg_build_layers_from_current_selection()
    Print "Selected count = ", nMade
    Print "selLayers     = {" + sg_layers_to_string() + "}"
    Print "selValuesDim2 = {" + sg_values_to_string() + "}"
End

//============================================================
// SliceGallery v1 - Module 3
// Main Panel + UI Sync
// Depends on Module 1 + Module 2
//============================================================


//============================================================
// SliceGallery v1 - Module 3
// Main Panel + UI Sync
// Depends on Module 1 + Module 2
//
// IMPORTANT:
//   This module REPLACES the old sg_sync_panel_from_state()
//============================================================


//============================================================
// Panel sync (REPLACE old version in Module 1)
//============================================================

Function sg_sync_panel_from_state()
    DoWindow SLICEGALLERY_LJZ_P
    if (V_flag == 0)
        return 0
    endif

    SVAR targetWavePath = root:ARPES_LJZ:SliceGallery:targetWavePath

    String st
    if (strlen(targetWavePath) == 0)
        st = "Selected: (none)"
    else
        st = "Selected: " + targetWavePath
    endif

    TitleBox sg_status,win=SLICEGALLERY_LJZ_P,title=st

    // base / scan
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_df
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_ck_rec
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_lb

    // dim cache
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_d0n
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_d1n
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_d2n

    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_d0off
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_d1off
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_d2off

    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_d0del
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_d1del
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_d2del

    // selection controls
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_manual
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_dim2in
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_np
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_s0
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_s1
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_ck_sort
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_ck_dedup
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_ck_rev
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_exportname
    // rendering-related state
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_ck_xuse
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_x0
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_x1

    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_ck_yuse
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_y0
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_y1

    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_ck_lut
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_ck_invert_ct
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_c0
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_c1
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_flucoef
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_tbf
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_tbx
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_sv_tby
    ControlUpdate/W=SLICEGALLERY_LJZ_P sg_pm_rstyle

    // summaries
    TitleBox sg_layers_txt,win=SLICEGALLERY_LJZ_P,title="Layers: " + sg_layers_to_string()
    TitleBox sg_vals_txt,win=SLICEGALLERY_LJZ_P,title="Dim2: " + sg_values_to_string()
    TitleBox sg_tb_ct_current,win=SLICEGALLERY_LJZ_P,title=sg_ct_display_string()
    TitleBox sg_tb_mode_hint,win=SLICEGALLERY_LJZ_P,title=sg_color_mode_hint_string()
    TitleBox sg_tb_range_hint,win=SLICEGALLERY_LJZ_P,title=sg_color_range_hint_string()

    sg_sync_popup_states()
    return 0
End

//============================================================
// CT menu helpers
//============================================================

Function sg_refresh_ct_menu_list()
    sg_init_defaults_if_needed()

    SVAR ctMenuList = root:ARPES_LJZ:SliceGallery:ctMenuList
    SVAR ctPick     = root:ARPES_LJZ:SliceGallery:ctPick

    // 依赖 CTLUZ
    ctluz_ensure_folder()
    ctluz_refresh_ctlib_menu()

    SVAR/Z libMenu = root:ARPES_LJZ:CTLUZ:ctlib_menu_list

    if (SVAR_Exists(libMenu))
        if (strlen(libMenu) > 0)
            if (WhichListItem("Current", libMenu, ";", 0, 0) >= 0)
                ctMenuList = libMenu
            else
                ctMenuList = "Current;" + libMenu
            endif
        else
            ctMenuList = "Current"
        endif
    else
        ctMenuList = "Current"
    endif

    if (WhichListItem(ctPick, ctMenuList, ";", 0, 0) < 0)
        ctPick = "Current"
    endif

    return 0
End


Function sg_btn_refresh_ct_panel(ctrlName) : ButtonControl
    String ctrlName

    sg_refresh_ct_menu_list()
    return 0
End

Function sg_sync_popup_states()
    DoWindow SLICEGALLERY_LJZ_P
    if (V_flag == 0)
        return 0
    endif
    
    SVAR renderStyle   = root:ARPES_LJZ:SliceGallery:renderStyle
    SVAR selectionMode = root:ARPES_LJZ:SliceGallery:selectionMode
    SVAR layoutMode    = root:ARPES_LJZ:SliceGallery:layoutMode

    NVAR displayMode = root:ARPES_LJZ:SliceGallery:displayMode
    NVAR colorMode = root:ARPES_LJZ:SliceGallery:colorMode
    NVAR labelMode = root:ARPES_LJZ:SliceGallery:labelMode
    NVAR labelType = root:ARPES_LJZ:SliceGallery:labelType

    PopupMenu sg_pm_sel,win=SLICEGALLERY_LJZ_P,mode=sg_selection_mode_to_popup(selectionMode)
    PopupMenu sg_pm_sel,win=SLICEGALLERY_LJZ_P,popvalue=selectionMode

    PopupMenu sg_pm_layout,win=SLICEGALLERY_LJZ_P,mode=sg_layout_mode_to_popup(layoutMode)
    PopupMenu sg_pm_layout,win=SLICEGALLERY_LJZ_P,popvalue=layoutMode

    PopupMenu sg_pm_rstyle,win=SLICEGALLERY_LJZ_P,mode=sg_render_style_to_popup(renderStyle)
    PopupMenu sg_pm_rstyle,win=SLICEGALLERY_LJZ_P,popvalue=renderStyle

    PopupMenu sg_pm_disp,win=SLICEGALLERY_LJZ_P,mode=max(1, min(4, displayMode + 1))
    PopupMenu sg_pm_disp,win=SLICEGALLERY_LJZ_P,popvalue=sg_display_mode_to_string(displayMode)

    PopupMenu sg_pm_color,win=SLICEGALLERY_LJZ_P,mode=max(1, min(3, colorMode + 1))
    PopupMenu sg_pm_color,win=SLICEGALLERY_LJZ_P,popvalue=sg_color_mode_to_string(colorMode)

    PopupMenu sg_pm_label,win=SLICEGALLERY_LJZ_P,mode=max(1, min(4, labelMode + 1))
    PopupMenu sg_pm_label,win=SLICEGALLERY_LJZ_P,popvalue=sg_label_mode_to_string(labelMode)

    PopupMenu sg_pm_labtype,win=SLICEGALLERY_LJZ_P,mode=max(1, min(4, labelType + 1))
    PopupMenu sg_pm_labtype,win=SLICEGALLERY_LJZ_P,popvalue=sg_label_type_to_string(labelType)

    return 0
End

//============================================================
// Popup mapping helpers
//============================================================

Function sg_selection_mode_to_popup(selModeStr)
    String selModeStr

    if (StringMatch(selModeStr, "Manual"))
        return 1
    endif
    if (StringMatch(selModeStr, "EvenSpacing"))
        return 2
    endif
    if (StringMatch(selModeStr, "Dim2Values"))
        return 3
    endif
    return 1
End


Function sg_layout_mode_to_popup(layoutStr)
    String layoutStr

    if (StringMatch(layoutStr, "Auto"))
        return 1
    endif
    if (StringMatch(layoutStr, "1xN"))
        return 2
    endif
    if (StringMatch(layoutStr, "2x3"))
        return 3
    endif
    if (StringMatch(layoutStr, "2x4"))
        return 4
    endif
    if (StringMatch(layoutStr, "3x3"))
        return 5
    endif
    return 1
End

Function sg_render_style_to_popup(styleStr)
    String styleStr

    if (StringMatch(styleStr, "LegacyTight"))
        return 1
    endif
    if (StringMatch(styleStr, "EqualPlot"))
        return 2
    endif

    return 1
End

Function/S sg_display_mode_to_string(modeNum)
    Variable modeNum

    switch (round(modeNum))
        case 0:
            return "Raw"
        case 1:
            return "SecondDerivXX"
        case 2:
            return "SecondDerivYY"
        case 3:
            return "SecondDerivXY"
    endswitch

    return "Raw"
End

Function/S sg_color_mode_to_string(modeNum)
    Variable modeNum

    switch (round(modeNum))
        case 0:
            return "PerPanelAuto"
        case 1:
            return "SharedAuto"
        case 2:
            return "Manual"
    endswitch
    return "SharedAuto"
End


Function/S sg_label_mode_to_string(modeNum)
    Variable modeNum

    switch (round(modeNum))
        case 0:
            return "None"
        case 1:
            return "Index"
        case 2:
            return "Dim2Value"
        case 3:
            return "Index+Value"
    endswitch
    return "Dim2Value"
End


Function/S sg_label_type_to_string(typeNum)
    Variable typeNum

    switch (round(typeNum))
        case 0:
            return "None"
        case 1:
            return "Fluence"
        case 2:
            return "Delay"
        case 3:
            return "Temp"
    endswitch
    return "Delay"
End


//============================================================
// Extra popup callbacks
//============================================================

Function sg_pm_layout_proc(ctrlName, popNumber, popText) : PopupMenuControl
    String ctrlName
    Variable popNumber
    String popText

    SVAR layoutMode = root:ARPES_LJZ:SliceGallery:layoutMode
    layoutMode = popText
    return 0
End

Function sg_pm_rstyle_proc(ctrlName, popNumber, popText) : PopupMenuControl
    String ctrlName
    Variable popNumber
    String popText

    SVAR renderStyle = root:ARPES_LJZ:SliceGallery:renderStyle
    renderStyle = popText
    return 0
End

Function sg_apply_display_mode_linked_options()
    sg_init_defaults_if_needed()

    NVAR displayMode   = root:ARPES_LJZ:SliceGallery:displayMode
    NVAR invertColors  = root:ARPES_LJZ:SliceGallery:invertColors

    if (round(displayMode) == 0)
        invertColors = 0
    else
        invertColors = 1
    endif
End

Function sg_pm_display_proc(ctrlName, popNumber, popText) : PopupMenuControl
    String ctrlName
    Variable popNumber
    String popText

    NVAR displayMode = root:ARPES_LJZ:SliceGallery:displayMode

    if (StringMatch(popText, "SecondDerivXX"))
        displayMode = 1
    elseif (StringMatch(popText, "SecondDerivYY"))
        displayMode = 2
    elseif (StringMatch(popText, "SecondDerivXY"))
        displayMode = 3
    else
        displayMode = 0
    endif

    sg_apply_display_mode_linked_options()
    sg_sync_panel_from_state()
    return 0
End

Function sg_pm_color_proc(ctrlName, popNumber, popText) : PopupMenuControl
    String ctrlName
    Variable popNumber
    String popText

    NVAR colorMode = root:ARPES_LJZ:SliceGallery:colorMode

    if (StringMatch(popText, "PerPanelAuto"))
        colorMode = 0
    elseif (StringMatch(popText, "SharedAuto"))
        colorMode = 1
    elseif (StringMatch(popText, "Manual"))
        colorMode = 2
    else
        colorMode = 1
    endif

    return 0
End


Function sg_pm_label_proc(ctrlName, popNumber, popText) : PopupMenuControl
    String ctrlName
    Variable popNumber
    String popText

    NVAR labelMode = root:ARPES_LJZ:SliceGallery:labelMode

    if (StringMatch(popText, "None"))
        labelMode = 0
    elseif (StringMatch(popText, "Index"))
        labelMode = 1
    elseif (StringMatch(popText, "Dim2Value"))
        labelMode = 2
    elseif (StringMatch(popText, "Index+Value"))
        labelMode = 3
    else
        labelMode = 2
    endif

    return 0
End


Function sg_pm_labeltype_proc(ctrlName, popNumber, popText) : PopupMenuControl
    String ctrlName
    Variable popNumber
    String popText

    NVAR labelType = root:ARPES_LJZ:SliceGallery:labelType

    if (StringMatch(popText, "None"))
        labelType = 0
    elseif (StringMatch(popText, "Fluence"))
        labelType = 1
    elseif (StringMatch(popText, "Delay"))
        labelType = 2
    elseif (StringMatch(popText, "Temp"))
        labelType = 3
    else
        labelType = 2
    endif

    return 0
End


Function sg_pm_ct_proc(ctrlName, popNumber, popText) : PopupMenuControl
    String ctrlName
    Variable popNumber
    String popText

    SVAR ctPick = root:ARPES_LJZ:SliceGallery:ctPick
    ctPick = popText
    return 0
End


//============================================================
// Button callbacks for panel control
//============================================================

Function sg_btn_apply_selection(ctrlName) : ButtonControl
    String ctrlName

    Variable nMade = sg_build_layers_from_current_selection()
    if (nMade >= 0)
        sg_sync_panel_from_state()
        Print "SliceGallery selLayers = {" + sg_layers_to_string() + "}"
        Print "SliceGallery selValuesDim2 = {" + sg_values_to_string() + "}"
    endif

    return 0
End


Function sg_btn_sync(ctrlName) : ButtonControl
    String ctrlName
    sg_sync_panel_from_state()
    return 0
End


Function sg_btn_close_panel(ctrlName) : ButtonControl
    String ctrlName
    DoWindow/K SLICEGALLERY_LJZ_P
    return 0
End


Function sg_btn_clear_layers_panel(ctrlName) : ButtonControl
    String ctrlName
    sg_clear_selected_layers()
    sg_sync_panel_from_state()
    return 0
End


Function sg_btn_scan_panel(ctrlName) : ButtonControl
    String ctrlName
    sg_rebuild_wave_list()
    return 0
End


//============================================================
// Help notebook
//============================================================

Function sg_show_help_notebook()
    String nbName = "SLICEGALLERY_LJZ_HELP"

    DoWindow/F $nbName
    if (V_flag == 0)
        NewNotebook/N=$nbName/F=1/V=1 as "SliceGallery Help"
    endif

    Notebook $nbName selection={startOfFile, endOfFile}
    Notebook $nbName text=""

    Notebook $nbName text="SliceGallery v1 Help\r"
    Notebook $nbName text="====================\r\r"

    Notebook $nbName text="Base DF / Recursive / Scan\r"
    Notebook $nbName text="  - 扫描 3D waves。\r"
    Notebook $nbName text="  - 左侧 List 选择目标 wave。\r\r"

    Notebook $nbName text="Selection Mode\r"
    Notebook $nbName text="  - Manual: 直接输入 layer indices。\r"
    Notebook $nbName text="  - EvenSpacing: 在 start..end 范围内等间隔取 panelCount 张。\r"
    Notebook $nbName text="  - Dim2Values: 输入物理值，自动映射到最近 layer。\r\r"

    Notebook $nbName text="Sort / Dedup / Reverse\r"
    Notebook $nbName text="  - 作用在最终 selLayers 上。\r\r"

    Notebook $nbName text="Layout / Color / Label\r"
    Notebook $nbName text="  - Label Settings 里可设置 Fluence 的换算系数 k。\r"
    Notebook $nbName text="  - 当 label type=Fluence 时，显示值 = k × dim2(mW)，单位为 μJ/cm\\S2\\M。\r"
    Notebook $nbName text="  - 真正的绘图在 Render 模块里完成。\r\r"

    Notebook $nbName text="Build Layers\r"
    Notebook $nbName text="  - 根据当前 Selection Mode 构造 selLayers 和 selValuesDim2。\r\r"

    Notebook $nbName text="Clear Layers\r"
    Notebook $nbName text="  - 清空当前 layer 选择结果。\r\r"

    Notebook $nbName text="Sync\r"
    Notebook $nbName text="  - 强制从 state 刷新 panel 显示。\r"
End


Function sg_btn_help(ctrlName) : ButtonControl
    String ctrlName
    sg_show_help_notebook()
    return 0
End


//============================================================
// Main entry
//============================================================

Proc SliceGallery_LJZ()
    sg_init_defaults_if_needed()

    // refresh CT menu list (requires CTLUZ loaded)
    sg_refresh_ct_menu_list()

    DoWindow/F SLICEGALLERY_LJZ_P
    if (V_flag == 0)
        SLICEGALLERY_LJZ_P()
    endif

    sg_rebuild_wave_list()
    sg_sync_panel_from_state()
End


//============================================================
// Main panel
//============================================================
Window SLICEGALLERY_LJZ_P() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(220.2,46.8,1325.4,735.6) as "SliceGallery (LJZ)"
	ModifyPanel frameStyle=1
	ShowTools/A
	TitleBox sg_title,pos={12.00,6.00},size={291.60,18.00},title="SliceGallery v1  —  State / Scan / Layer Selection / UI"
	TitleBox sg_title,frame=0
	TitleBox sg_status,pos={12.00,30.00},size={418.20,18.00},title="Selected: root:Ekimage:EK_DS_Sw6_dv4_1mW_10272024_Combine0To23_VV"
	TitleBox sg_status,frame=0
	GroupBox sg_gb_data,pos={6.00,57.00},size={432.00,87.00},title="Data Source"
	TitleBox sg_t_scan,pos={18.00,78.00},size={60.60,18.00},title="Wave Scan"
	TitleBox sg_t_scan,frame=0
	TitleBox sg_t_df,pos={18.00,102.00},size={47.40,18.00},title="Base DF:",frame=0
	SetVariable sg_sv_df,pos={81.00,99.00},size={279.00,19.80}
	SetVariable sg_sv_df,value= root:ARPES_LJZ:SliceGallery:baseDF
	CheckBox sg_ck_rec,pos={372.00,102.00},size={63.60,18.00},title="Recursive"
	CheckBox sg_ck_rec,variable= root:ARPES_LJZ:SliceGallery:recursive
	Button sg_btn_scan,pos={453.00,69.00},size={54.00,78.60},proc=sg_btn_scan_panel,title="Scan"
	GroupBox sg_gb_list,pos={6.00,156.00},size={498.00,408.00},title="Available Waves"
	ListBox sg_lb,pos={18.00,177.00},size={480.00,378.00},proc=sg_lb_proc
	ListBox sg_lb,listWave=root:ARPES_LJZ:SliceGallery:LB_Disp
	ListBox sg_lb,selWave=root:ARPES_LJZ:SliceGallery:LB_Sel,mode= 1,selRow= 0
	GroupBox sg_gb_info,pos={519.00,57.00},size={300.00,117.00},title="Target Wave Information"
	SetVariable sg_sv_d0n,pos={531.00,81.00},size={78.00,19.80},title="Dim0 N"
	SetVariable sg_sv_d0n,value= root:ARPES_LJZ:SliceGallery:dim0_n,noedit= 1
	SetVariable sg_sv_d1n,pos={618.00,81.00},size={78.00,19.80},title="Dim1 N"
	SetVariable sg_sv_d1n,value= root:ARPES_LJZ:SliceGallery:dim1_n,noedit= 1
	SetVariable sg_sv_d2n,pos={708.00,81.00},size={78.00,19.80},title="Dim2 N"
	SetVariable sg_sv_d2n,value= root:ARPES_LJZ:SliceGallery:dim2_n,noedit= 1
	SetVariable sg_sv_d0off,pos={531.00,108.00},size={78.00,19.80},title="D0 Off"
	SetVariable sg_sv_d0off,value= root:ARPES_LJZ:SliceGallery:dim0_off,noedit= 1
	SetVariable sg_sv_d1off,pos={618.00,108.00},size={78.00,19.80},title="D1 Off"
	SetVariable sg_sv_d1off,value= root:ARPES_LJZ:SliceGallery:dim1_off,noedit= 1
	SetVariable sg_sv_d2off,pos={708.00,108.00},size={78.00,19.80},title="D2 Off"
	SetVariable sg_sv_d2off,value= root:ARPES_LJZ:SliceGallery:dim2_off,noedit= 1
	SetVariable sg_sv_d0del,pos={531.00,132.00},size={78.00,19.80},title="D0 Del"
	SetVariable sg_sv_d0del,value= root:ARPES_LJZ:SliceGallery:dim0_del,noedit= 1
	SetVariable sg_sv_d1del,pos={618.00,132.00},size={78.00,19.80},title="D1 Del"
	SetVariable sg_sv_d1del,value= root:ARPES_LJZ:SliceGallery:dim1_del,noedit= 1
	SetVariable sg_sv_d2del,pos={708.00,132.00},size={78.00,19.80},title="D2 Del"
	SetVariable sg_sv_d2del,value= root:ARPES_LJZ:SliceGallery:dim2_del,noedit= 1
	GroupBox sg_gb_sel,pos={519.00,183.00},size={300.00,255.00},title="Selection Parameters"
	PopupMenu sg_pm_sel,pos={531.00,210.00},size={55.20,20.40},proc=sg_pm_selection_proc
	PopupMenu sg_pm_sel,mode=1,popvalue="Manual",value= #"\"Manual;EvenSpacing;Dim2Values\""
	SetVariable sg_sv_manual,pos={531.00,240.00},size={255.00,19.80},title="Manual"
	SetVariable sg_sv_manual,value= root:ARPES_LJZ:SliceGallery:manualInputStr
	SetVariable sg_sv_dim2in,pos={531.00,270.00},size={255.00,19.80},title="Dim2"
	SetVariable sg_sv_dim2in,value= root:ARPES_LJZ:SliceGallery:dim2InputStr
	SetVariable sg_sv_np,pos={531.00,300.00},size={117.00,19.80},title="N Panels"
	SetVariable sg_sv_np,limits={1,999,1},value= root:ARPES_LJZ:SliceGallery:panelCount
	SetVariable sg_sv_s0,pos={660.00,300.00},size={126.00,19.80},title="Start"
	SetVariable sg_sv_s0,value= root:ARPES_LJZ:SliceGallery:startLayer
	SetVariable sg_sv_s1,pos={531.00,330.00},size={126.00,19.80},title="End"
	SetVariable sg_sv_s1,value= root:ARPES_LJZ:SliceGallery:endLayer
	CheckBox sg_ck_sort,pos={672.00,330.00},size={33.60,18.00},title="Sort"
	CheckBox sg_ck_sort,variable= root:ARPES_LJZ:SliceGallery:sortLayers
	CheckBox sg_ck_dedup,pos={531.00,360.00},size={48.60,18.00},title="Dedup"
	CheckBox sg_ck_dedup,variable= root:ARPES_LJZ:SliceGallery:dedupLayers
	CheckBox sg_ck_rev,pos={612.00,360.00},size={54.00,18.00},title="Reverse"
	CheckBox sg_ck_rev,variable= root:ARPES_LJZ:SliceGallery:reverseOrder
	Button sg_btn_build,pos={531.00,390.00},size={117.00,24.00},proc=sg_btn_apply_selection,title="Build Layers"
	Button sg_btn_clear,pos={669.00,390.00},size={117.00,24.00},proc=sg_btn_clear_layers_panel,title="Clear Layers"
	GroupBox sg_gb_render,pos={840.00,57.00},size={186.60,204.60},title="Rendering Options"
	PopupMenu sg_pm_layout,pos={852.00,84.00},size={35.40,20.40},proc=sg_pm_layout_proc
	PopupMenu sg_pm_layout,mode=2,popvalue="1xN",value= #"\"Auto;1xN;2x3;2x4;3x3\""
	PopupMenu sg_pm_rstyle,pos={673.20,28.80},size={79.80,20.40},proc=sg_pm_rstyle_proc
	PopupMenu sg_pm_rstyle,mode=1,popvalue="LegacyTight",value= #"\"LegacyTight;EqualPlot\""
	PopupMenu sg_pm_disp,pos={852.00,108.60},size={78.00,20.40},proc=sg_pm_display_proc
	PopupMenu sg_pm_disp,mode=1,popvalue="Raw",value= #"\"Raw;SecondDerivXX;SecondDerivYY;SecondDerivXY\""
	CheckBox sg_ck_xuse,pos={906.00,84.00},size={42.60,18.00},title="Use X"
	CheckBox sg_ck_xuse,variable= root:ARPES_LJZ:SliceGallery:xUse
	SetVariable sg_sv_x0,pos={852.00,138.60},size={162.00,19.80},title="xMin"
	SetVariable sg_sv_x0,value= root:ARPES_LJZ:SliceGallery:xMin
	SetVariable sg_sv_x1,pos={852.00,165.60},size={162.00,19.80},title="xMax"
	SetVariable sg_sv_x1,value= root:ARPES_LJZ:SliceGallery:xMax
	CheckBox sg_ck_yuse,pos={967.00,84.00},size={42.60,18.00},title="Use Y"
	CheckBox sg_ck_yuse,variable= root:ARPES_LJZ:SliceGallery:yUse
	SetVariable sg_sv_y0,pos={852.00,195.60},size={162.00,19.80},title="yMin"
	SetVariable sg_sv_y0,value= root:ARPES_LJZ:SliceGallery:yMin
	SetVariable sg_sv_y1,pos={852.00,223.80},size={162.00,19.80},title="yMax"
	SetVariable sg_sv_y1,value= root:ARPES_LJZ:SliceGallery:yMax
	GroupBox sg_gb_color,pos={840.00,270.60},size={186.00,210.60},title="Color Settings"
	TitleBox sg_tb_ct_current,pos={852.60,299.40},size={66.00,18.00},title="CT: Mualani"
	TitleBox sg_tb_ct_current,frame=0
	Button sg_btn_browse_ct,pos={962.40,300.60},size={30.00,18.00},proc=sg_btn_open_ct_browser,title="..."
	TitleBox sg_tb_mode_hint,pos={764.40,35.40},size={267.00,12.60},title="Mode: Raw slices; color popup controls PerPanel/Shared/Manual"
	TitleBox sg_tb_mode_hint,fSize=10,frame=0
	CheckBox sg_ck_lut,pos={852.00,328.80},size={56.40,18.00},title="Use LUT"
	CheckBox sg_ck_lut,variable= root:ARPES_LJZ:SliceGallery:useLUT
	CheckBox sg_ck_invert_ct,pos={930.00,328.80},size={43.20,18.00},title="Invert"
	CheckBox sg_ck_invert_ct,variable= root:ARPES_LJZ:SliceGallery:invertColors
	PopupMenu sg_pm_color,pos={852.00,358.80},size={55.20,20.40},proc=sg_pm_color_proc
	PopupMenu sg_pm_color,mode=3,popvalue="Manual",value= #"\"PerPanelAuto;SharedAuto;Manual\""
	SetVariable sg_sv_c0,pos={852.00,388.80},size={78.00,19.80},title="cMin"
	SetVariable sg_sv_c0,value= root:ARPES_LJZ:SliceGallery:cMin
	SetVariable sg_sv_c1,pos={852.00,415.80},size={78.00,19.80},title="cMax"
	SetVariable sg_sv_c1,value= root:ARPES_LJZ:SliceGallery:cMax
	TitleBox sg_tb_range_hint,pos={852.00,441.60},size={100.20,12.60},title="Manual c range: [0, 500]"
	TitleBox sg_tb_range_hint,fSize=10,frame=0
	GroupBox sg_gb_label,pos={840.00,492.00},size={184.80,178.20},title="Label Settings"
	PopupMenu sg_pm_label,pos={852.00,519.00},size={72.60,20.40},proc=sg_pm_label_proc
	PopupMenu sg_pm_label,mode=3,popvalue="Dim2Value",value= #"\"None;Index;Dim2Value;Index+Value\""
	PopupMenu sg_pm_labtype,pos={867.00,555.00},size={44.40,20.40},proc=sg_pm_labeltype_proc
	PopupMenu sg_pm_labtype,mode=3,popvalue="Delay",value= #"\"None;Fluence;Delay;Temp\""
	SetVariable sg_sv_flucoef,pos={852.00,578.00},size={146.40,19.80},title="k mW→uJ"
	SetVariable sg_sv_flucoef,value= root:ARPES_LJZ:SliceGallery:fluenceCoeff
	SetVariable sg_sv_tbf,pos={852.00,600.00},size={78.00,19.80},title="Font"
	SetVariable sg_sv_tbf,limits={6,72,1},value= root:ARPES_LJZ:SliceGallery:tbFont
	SetVariable sg_sv_tbx,pos={852.00,622.00},size={78.00,19.80},title="X%"
	SetVariable sg_sv_tbx,value= root:ARPES_LJZ:SliceGallery:tbX
	SetVariable sg_sv_tby,pos={852.00,644.00},size={78.00,19.80},title="Y%"
	SetVariable sg_sv_tby,value= root:ARPES_LJZ:SliceGallery:tbY
	GroupBox sg_gb_summary,pos={6.00,576.00},size={810.00,84.00},title="Summary Information"
	TitleBox sg_layers_txt,pos={18.00,600.00},size={127.20,18.00},title="Layers: 0, 1, 4, 7, 11, 18"
	TitleBox sg_layers_txt,frame=0
	TitleBox sg_vals_txt,pos={18.00,624.00},size={105.60,12.60},title="Dim2: -1, 4, 19, 34, 54, 89"
	TitleBox sg_vals_txt,fSize=10,frame=0
	GroupBox sg_gb_buttons,pos={519.00,441.00},size={297.00,120.00},title="Actions"
	SetVariable sg_sv_exportname,pos={537.00,609.60},size={249.00,19.80},title="Name"
	SetVariable sg_sv_exportname,value= root:ARPES_LJZ:SliceGallery:exportBaseName
	Button sg_btn_sync,pos={558.00,474.00},size={99.00,33.00},proc=sg_btn_sync,title="Sync"
	Button sg_btn_preview,pos={678.60,474.00},size={99.00,33.00},proc=sg_btn_preview,title="Preview"
	Button sg_btn_export,pos={558.00,513.00},size={99.00,30.00},proc=sg_btn_export,title="Export"
	Button sg_btn_close,pos={678.60,513.00},size={99.00,30.00},proc=sg_btn_close_panel,title="Close"
EndMacro

//============================================================
// SliceGallery v1 - Module 4
// Render Preview Basic (old Show6Layers-style placement)
// Replace the whole old Module 4 with this block
//============================================================


//============================================================
// Render helpers
//============================================================

Function/S sg_preview_tmp_df()
    return "root:ARPES_LJZ:SliceGallery:TMP:PREVIEW:"
End


Function/S sg_img_name_from_index(imgIdx)
    Variable imgIdx

    String outName
    sprintf outName, "img_%03d", round(imgIdx)
    return outName
End


Function/S sg_graph_name_from_index(imgIdx)
    Variable imgIdx

    String outName
    sprintf outName, "SGPV_%03d", round(imgIdx)
    return outName
End


Function/S sg_label_unit_string(labelTypeNum)
    Variable labelTypeNum

    switch (round(labelTypeNum))
        case 1:
            return "μJ/cm\\S2\\M"
        case 2:
            return "ps"
        case 3:
            return "K"
    endswitch

    return ""
End


Function sg_label_value_for_display(val, labelTypeNum)
    Variable val, labelTypeNum

    sg_init_defaults_if_needed()

    NVAR fluenceCoeff = root:ARPES_LJZ:SliceGallery:fluenceCoeff

    if (round(labelTypeNum) == 1)
        return val * fluenceCoeff
    endif

    return val
End


Function/S sg_format_value_with_unit(val, labelTypeNum)
    Variable val, labelTypeNum

    Variable displayVal = sg_label_value_for_display(val, labelTypeNum)
    String unitStr = sg_label_unit_string(labelTypeNum)
    Variable rval = round(displayVal)
    String outStr

    if (abs(displayVal - rval) < 1e-6)
        if (strlen(unitStr) > 0)
            sprintf outStr, "%d %s", rval, unitStr
        else
            sprintf outStr, "%d", rval
        endif
    else
        if (strlen(unitStr) > 0)
            sprintf outStr, "%.4g %s", displayVal, unitStr
        else
            sprintf outStr, "%.4g", displayVal
        endif
    endif

    return outStr
End


Function/S sg_make_panel_label(layerIdx)
    Variable layerIdx

    sg_init_defaults_if_needed()

    NVAR labelMode      = root:ARPES_LJZ:SliceGallery:labelMode
    NVAR labelType      = root:ARPES_LJZ:SliceGallery:labelType
    SVAR targetWavePath = root:ARPES_LJZ:SliceGallery:targetWavePath

    if (!sg_target_wave_is_ready(0))
        return ""
    endif

    Wave w = $targetWavePath
    Variable dim2Val = sg_layer_value_from_index(w, layerIdx)

    String idxStr = "#" + num2str(layerIdx)
    String valStr = sg_format_value_with_unit(dim2Val, labelType)

    switch (round(labelMode))
        case 0:
            return ""
        case 1:
            return idxStr
        case 2:
            return valStr
        case 3:
            return idxStr + "   " + valStr
    endswitch

    return valStr
End


Function sg_get_layout_code(nPanels, layoutStr)
    Variable nPanels
    String layoutStr

    Variable rows = 1
    Variable cols = max(1, round(nPanels))

    if (StringMatch(layoutStr, "1xN"))
        rows = 1
        cols = max(1, round(nPanels))
        return rows * 1000 + cols
    endif

    if (StringMatch(layoutStr, "2x3"))
        rows = 2
        cols = 3
        return rows * 1000 + cols
    endif

    if (StringMatch(layoutStr, "2x4"))
        rows = 2
        cols = 4
        return rows * 1000 + cols
    endif

    if (StringMatch(layoutStr, "3x3"))
        rows = 3
        cols = 3
        return rows * 1000 + cols
    endif

    // Auto
    if (nPanels <= 1)
        rows = 1; cols = 1
    elseif (nPanels == 2)
        rows = 1; cols = 2
    elseif (nPanels == 3)
        rows = 1; cols = 3
    elseif (nPanels == 4)
        rows = 2; cols = 2
    elseif (nPanels <= 6)
        rows = 2; cols = 3
    elseif (nPanels <= 8)
        rows = 2; cols = 4
    else
        rows = 3; cols = 3
    endif

    return rows * 1000 + cols
End


Function sg_layout_rows_from_code(codeVal)
    Variable codeVal
    return floor(codeVal / 1000)
End


Function sg_layout_cols_from_code(codeVal)
    Variable codeVal
    return mod(codeVal, 1000)
End


Function sg_prepare_preview_tmp_folder()
    sg_ensure_folder()

    KillDataFolder/Z root:ARPES_LJZ:SliceGallery:TMP:PREVIEW
    NewDataFolder/O root:ARPES_LJZ:SliceGallery:TMP:PREVIEW

    return 0
End


//============================================================
// Slice extraction
//============================================================

Function sg_second_derivative_view_enabled()
    NVAR displayMode = root:ARPES_LJZ:SliceGallery:displayMode
    return (round(displayMode) >= 1 && round(displayMode) <= 3)
End

Function/S sg_second_derivative_mode_label(modeNum)
    Variable modeNum

    switch (round(modeNum))
        case 1:
            return "d2/dx2 (xx)"
        case 2:
            return "d2/dy2 (yy)"
        case 3:
            return "d2/dx2+d2/dy2 (xy)"
    endswitch

    return "Raw"
End

Function sg_apply_second_derivative_to_image(imgWave)
    Wave imgWave

    if (!WaveExists(imgWave))
        return -1
    endif

    if (WaveDims(imgWave) != 2)
        return -1
    endif

    if (DimSize(imgWave, 0) < 3 || DimSize(imgWave, 1) < 3)
        return -1
    endif

    NVAR displayMode = root:ARPES_LJZ:SliceGallery:displayMode
    Variable derivMode = round(displayMode)

    Variable needDx2 = (derivMode == 1) || (derivMode == 3)
    Variable needDy2 = (derivMode == 2) || (derivMode == 3)

    if (!needDx2 && !needDy2)
        return 0
    endif

    Wave/Z tmpDx2
    Wave/Z tmpDy2

    if (needDx2)
        Duplicate/FREE imgWave, tmpDx2
        Differentiate/DIM=0 tmpDx2
        Differentiate/DIM=0 tmpDx2
    endif

    if (needDy2)
        Duplicate/FREE imgWave, tmpDy2
        Differentiate/DIM=1 tmpDy2
        Differentiate/DIM=1 tmpDy2
    endif

    if (derivMode == 1)
        imgWave[][] = tmpDx2[p][q]
    elseif (derivMode == 2)
        imgWave[][] = tmpDy2[p][q]
    else
        imgWave[][] = tmpDx2[p][q] + tmpDy2[p][q]
    endif

    return 0
End

Function sg_set_second_deriv_color_range(globalMin, globalMax)
    Variable globalMin, globalMax

    NVAR cMin = root:ARPES_LJZ:SliceGallery:cMin
    NVAR cMax = root:ARPES_LJZ:SliceGallery:cMax

    if (numtype(globalMin) != 0)
        return -1
    endif

    if (globalMin >= 0)
        globalMin = min(globalMin, -1e-12)
    endif

    cMin = globalMin
    cMax = 0
    return 0
End

Function sg_extract_selected_slices_to_preview_tmp()
    sg_init_defaults_if_needed()

    if (!sg_target_wave_is_ready(1))
        return -1
    endif

    Wave selLayers      = root:ARPES_LJZ:SliceGallery:selLayers
    SVAR targetWavePath = root:ARPES_LJZ:SliceGallery:targetWavePath

    Variable nSel = DimSize(selLayers, 0)
    if (nSel <= 0)
        DoAlert 0, "SliceGallery: selLayers is empty. Please build layers first."
        return -1
    endif

    Wave sourceWave = $targetWavePath
    sg_prepare_preview_tmp_folder()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:SliceGallery:TMP:PREVIEW

    Variable i, layerIdx
    Variable nx = DimSize(sourceWave, 0)
    Variable ny = DimSize(sourceWave, 1)

    for (i = 0; i < nSel; i += 1)
        layerIdx = round(selLayers[i])

        String imgName = sg_img_name_from_index(i)
        Make/O/N=(nx, ny) $imgName

        Wave imgWave = $imgName
        imgWave[][] = sourceWave[p][q][layerIdx]

        SetScale/P x DimOffset(sourceWave, 0), DimDelta(sourceWave, 0), imgWave
        SetScale/P y DimOffset(sourceWave, 1), DimDelta(sourceWave, 1), imgWave

        if (sg_second_derivative_view_enabled())
            sg_apply_second_derivative_to_image(imgWave)
        endif
    endfor

    SetDataFolder df0
    return 0
End


//============================================================
// Color range
//============================================================

Function sg_compute_shared_color_range()
    sg_init_defaults_if_needed()

    Wave selLayers = root:ARPES_LJZ:SliceGallery:selLayers
    NVAR cMin = root:ARPES_LJZ:SliceGallery:cMin
    NVAR cMax = root:ARPES_LJZ:SliceGallery:cMax
    NVAR displayMode = root:ARPES_LJZ:SliceGallery:displayMode

    Variable nSel = DimSize(selLayers, 0)

    if (nSel <= 0)
        return NaN
    endif

    Variable globalMin = NaN
    Variable globalMax = NaN
    Variable i

    for (i = 0; i < nSel; i += 1)
        String imgPath = sg_preview_tmp_df() + sg_img_name_from_index(i)
        Wave/Z imgWave = $imgPath
        if (!WaveExists(imgWave))
            continue
        endif

        WaveStats/Q imgWave
        if (numtype(globalMin) != 0)
            globalMin = V_min
            globalMax = V_max
        else
            globalMin = min(globalMin, V_min)
            globalMax = max(globalMax, V_max)
        endif
    endfor

    if (numtype(globalMin) != 0 || numtype(globalMax) != 0)
        return NaN
    endif

    if (sg_second_derivative_view_enabled())
        return sg_set_second_deriv_color_range(globalMin, globalMax)
    endif

    if (globalMin == globalMax)
        globalMin -= 1e-12
        globalMax += 1e-12
    endif

    cMin = globalMin
    cMax = globalMax

    return 0
End


Function sg_validate_manual_color_range()
    NVAR cMin = root:ARPES_LJZ:SliceGallery:cMin
    NVAR cMax = root:ARPES_LJZ:SliceGallery:cMax

    if (numtype(cMin) != 0 || numtype(cMax) != 0)
        DoAlert 0, "SliceGallery: manual cMin/cMax must both be numeric."
        return -1
    endif

    if (cMin >= cMax)
        DoAlert 0, "SliceGallery: manual cMin must be < cMax."
        return -1
    endif

    return 0
End

//============================================================
// CT snapshot helpers
// 每张图 / 每个 image 使用自己的 palette 快照
// 防止后续修改 CTLUZ 当前 palette 时，旧图被联动改色
//============================================================

Function/S sg_ct_applied_df()
    ctluz_ensure_folder()
    NewDataFolder/O root:ARPES_LJZ:CTLUZ:APPLIED
    return "root:ARPES_LJZ:CTLUZ:APPLIED:"
End

Function/S sg_ct_snapshot_key(graphName, imageName)
    String graphName, imageName

    String g = CleanupName(graphName, 0)
    String im = CleanupName(imageName, 0)
    String key = g + "__" + im
    return CleanupName(key, 0)
End

Function/S sg_ct_snapshot_ct_path(graphName, imageName)
    String graphName, imageName
    return sg_ct_applied_df() + sg_ct_snapshot_key(graphName, imageName) + "_ct"
End

Function/S sg_ct_snapshot_lut_path(graphName, imageName)
    String graphName, imageName
    return sg_ct_applied_df() + sg_ct_snapshot_key(graphName, imageName) + "_lut"
End

Function sg_build_effective_ct(destCT, srcCT, srcLUT, useLookup, invertColors)
    Wave/W/U destCT
    Wave/W/U srcCT
    Wave/Z srcLUT
    Variable useLookup, invertColors

    Variable destN = DimSize(destCT, 0)
    Variable srcN  = DimSize(srcCT, 0)
    Variable ii, jj, srcIdx, lutIdx, lutVal

    if (destN <= 0 || srcN <= 0)
        return -1
    endif

    for (ii = 0; ii < destN; ii += 1)
        jj = invertColors ? (destN - 1 - ii) : ii

        if (useLookup && WaveExists(srcLUT))
            lutIdx = round(jj * (DimSize(srcLUT, 0) - 1) / max(destN - 1, 1))
            lutIdx = max(0, min(DimSize(srcLUT, 0) - 1, lutIdx))
            lutVal = srcLUT[lutIdx]
        else
            lutVal = jj / max(destN - 1.0, 1)
        endif

        if (numtype(lutVal) != 0)
            lutVal = 0
        endif
        lutVal = max(0, min(1, lutVal))

        srcIdx = round(lutVal * (srcN - 1))
        srcIdx = max(0, min(srcN - 1, srcIdx))

        destCT[ii][] = srcCT[srcIdx][q]
    endfor

    return 0
End

// 根据 SliceGallery 当前 ctPick / useLUT
// 为 graphName:imageName 生成冻结 palette 快照
Function sg_prepare_ct_snapshot_for_image(graphName, imageName)
    String graphName, imageName

    sg_init_defaults_if_needed()
    ctluz_ensure_folder()

    SVAR ctPick       = root:ARPES_LJZ:SliceGallery:ctPick
    NVAR useLUT       = root:ARPES_LJZ:SliceGallery:useLUT
    NVAR invertColors = root:ARPES_LJZ:SliceGallery:invertColors
    NVAR displayMode  = root:ARPES_LJZ:SliceGallery:displayMode

    Wave/Z/W/U srcCT = root:ARPES_LJZ:CTLUZ:ct_table
    Wave/Z srcLUT    = root:ARPES_LJZ:CTLUZ:ct_lut

    if (!StringMatch(ctPick, "Current"))
        Wave/Z/W/U pickedCT = $("root:ARPES_LJZ:CTLUZ:CTLIB:" + ctPick)
        if (WaveExists(pickedCT))
            srcCT = pickedCT
        endif
    endif

    if (!WaveExists(srcCT))
        return -1
    endif

    Variable effectiveInvert = invertColors
    if (sg_second_derivative_view_enabled())
        effectiveInvert = 1
    endif

    String ctPath  = sg_ct_snapshot_ct_path(graphName, imageName)
    String lutPath = sg_ct_snapshot_lut_path(graphName, imageName)

    if (effectiveInvert)
        Duplicate/O srcCT, $ctPath
        Wave/W/U snapCT = $ctPath
        sg_build_effective_ct(snapCT, srcCT, srcLUT, useLUT, 1)

        Note/K snapCT
        Note snapCT, "SliceGallery CT snapshot\r" + \
                     "graph=" + graphName + "\r" + \
                     "image=" + imageName + "\r" + \
                     "ctPick=" + ctPick + "\r" + \
                     "invertColors=1\r"

        // invert 后直接把 LUT 烘焙进 CT，避免 lookup 方向和 CT 方向不一致
        KillWaves/Z $lutPath
    else
        Duplicate/O srcCT, $ctPath
        Wave/W/U snapCT = $ctPath

        Note/K snapCT
        Note snapCT, "SliceGallery CT snapshot\r" + \
                     "graph=" + graphName + "\r" + \
                     "image=" + imageName + "\r" + \
                     "ctPick=" + ctPick + "\r" + \
                     "invertColors=0\r"

        // LUT: 若不用 LUT，则删掉旧 snapshot lut，避免误用
        KillWaves/Z $lutPath
        if (useLUT && WaveExists(srcLUT))
            Duplicate/O srcLUT, $lutPath
            Wave snapLUT = $lutPath
            Note/K snapLUT
            Note snapLUT, "SliceGallery LUT snapshot\r" + \
                          "graph=" + graphName + "\r" + \
                          "image=" + imageName + "\r" + \
                          "ctPick=" + ctPick + "\r" + \
                          "invertColors=0\r"
        endif
    endif

    return 0
End
//============================================================
// Graph styling
//============================================================

Function sg_apply_image_style_basic(graphName, imageName, useFixedRange, c0, c1)
    String graphName, imageName
    Variable useFixedRange, c0, c1

    sg_init_defaults_if_needed()

    NVAR useLUT = root:ARPES_LJZ:SliceGallery:useLUT
    NVAR xUse   = root:ARPES_LJZ:SliceGallery:xUse
    NVAR xMin   = root:ARPES_LJZ:SliceGallery:xMin
    NVAR xMax   = root:ARPES_LJZ:SliceGallery:xMax
    NVAR yUse   = root:ARPES_LJZ:SliceGallery:yUse
    NVAR yMin   = root:ARPES_LJZ:SliceGallery:yMin
    NVAR yMax   = root:ARPES_LJZ:SliceGallery:yMax

    // 先为当前 graph/image 生成 palette 快照
    Variable rc = sg_prepare_ct_snapshot_for_image(graphName, imageName)

    String ctPath  = sg_ct_snapshot_ct_path(graphName, imageName)
    String lutPath = sg_ct_snapshot_lut_path(graphName, imageName)

    Wave/Z/W/U ctWave = $ctPath
    Wave/Z lutWave    = $lutPath

    if (rc == 0 && WaveExists(ctWave))
        if (useFixedRange)
            if (useLUT && WaveExists(lutWave))
                ModifyImage/W=$graphName $imageName ctab={c0,c1,ctWave,0}, lookup=lutWave
            else
                ModifyImage/W=$graphName $imageName ctab={c0,c1,ctWave,0}
            endif
        else
            if (useLUT && WaveExists(lutWave))
                ModifyImage/W=$graphName $imageName ctab={*,*,ctWave,0}, lookup=lutWave
            else
                ModifyImage/W=$graphName $imageName ctab={*,*,ctWave,0}
            endif
        endif
    else
        // fallback
        if (useFixedRange)
            ModifyImage/W=$graphName $imageName ctab={c0,c1,YellowHot256,0}
        else
            ModifyImage/W=$graphName $imageName ctab={*,*,YellowHot256,0}
        endif
    endif

    ModifyGraph/W=$graphName mirror=2
    ModifyGraph/W=$graphName zero(left)=4

    if (xUse)
        if (xMin < xMax)
            SetAxis/W=$graphName bottom xMin, xMax
        endif
    endif

    if (yUse)
        if (yMin < yMax)
            SetAxis/W=$graphName left yMin, yMax
        endif
    endif

    return 0
End


Function sg_apply_panel_textbox(graphName, layerIdx)
    String graphName
    Variable layerIdx

    NVAR tbFont = root:ARPES_LJZ:SliceGallery:tbFont
    NVAR tbX    = root:ARPES_LJZ:SliceGallery:tbX
    NVAR tbY    = root:ARPES_LJZ:SliceGallery:tbY

    String labelStr = sg_make_panel_label(layerIdx)
    if (strlen(labelStr) <= 0)
        return 0
    endif

    String textStr = "\\Z" + num2str(tbFont) + labelStr

    TextBox/W=$graphName/K/N=sg_lbl
    TextBox/W=$graphName/N=sg_lbl/A=MT/F=0/B=1/X=(tbX)/Y=(tbY) textStr

    return 0
End


//============================================================
// Preview render
// old Show6Layers-style:
//  - first column gets wider layout rectangle
//  - non-first columns use tiny left/right margins
//============================================================

Function sg_render_preview_legacytight()
    sg_init_defaults_if_needed()

    if (!sg_target_wave_is_ready(1))
        return -1
    endif

    Wave selLayers = root:ARPES_LJZ:SliceGallery:selLayers
    Variable nSel = DimSize(selLayers, 0)
    if (nSel <= 0)
        DoAlert 0, "SliceGallery: selLayers is empty. Please build layers first."
        return -1
    endif

    SVAR previewWinName = root:ARPES_LJZ:SliceGallery:previewWinName

    // close old preview layout
    DoWindow/K $previewWinName

    // close old graph windows
    Variable iKill
    for (iKill = 0; iKill < 128; iKill += 1)
        String oldGraphName = sg_graph_name_from_index(iKill)
        KillWindow/Z $oldGraphName
    endfor

    // rebuild temp slices
    if (sg_extract_selected_slices_to_preview_tmp() != 0)
        return -1
    endif

    SVAR layoutMode = root:ARPES_LJZ:SliceGallery:layoutMode
    NVAR displayMode = root:ARPES_LJZ:SliceGallery:displayMode
    NVAR colorMode  = root:ARPES_LJZ:SliceGallery:colorMode

    Variable useFixedRange = 0
    Variable fixedC0 = NaN
    Variable fixedC1 = NaN

    if (sg_second_derivative_view_enabled())
        if (sg_compute_shared_color_range() != 0)
            DoAlert 0, "SliceGallery: failed to compute second-derivative color range."
            return -1
        endif
        NVAR cMinDeriv = root:ARPES_LJZ:SliceGallery:cMin
        NVAR cMaxDeriv = root:ARPES_LJZ:SliceGallery:cMax
        useFixedRange = 1
        fixedC0 = cMinDeriv
        fixedC1 = cMaxDeriv
    elseif (colorMode == 1)
        if (sg_compute_shared_color_range() != 0)
            DoAlert 0, "SliceGallery: failed to compute shared color range."
            return -1
        endif
        NVAR cMinShared = root:ARPES_LJZ:SliceGallery:cMin
        NVAR cMaxShared = root:ARPES_LJZ:SliceGallery:cMax
        useFixedRange = 1
        fixedC0 = cMinShared
        fixedC1 = cMaxShared
    elseif (colorMode == 2)
        if (sg_validate_manual_color_range() != 0)
            return -1
        endif
        NVAR cMinManual = root:ARPES_LJZ:SliceGallery:cMin
        NVAR cMaxManual = root:ARPES_LJZ:SliceGallery:cMax
        useFixedRange = 1
        fixedC0 = cMinManual
        fixedC1 = cMaxManual
    else
        useFixedRange = 0
    endif

    Variable layoutCode = sg_get_layout_code(nSel, layoutMode)
    Variable nRows = sg_layout_rows_from_code(layoutCode)
    Variable nCols = sg_layout_cols_from_code(layoutCode)

    // --------------------------------------------------------
    // old-style geometry
    // graph window size itself
    // --------------------------------------------------------
    Variable graphW, graphH
    if (nCols >= 6)
        graphW = 95
        graphH = 180
    elseif (nCols >= 4)
        graphW = 110
        graphH = 190
    else
        graphW = 125
        graphH = 200
    endif

    // first column gets extra layout width to compensate y-axis
    Variable firstColScale = 1.55
    Variable firstColLeftPad = 0.18 * graphW

    // spacing between layout rectangles
    Variable gapX = 0
    Variable gapY = 6

    // global layout offset
    Variable left0 = 12
    Variable top0  = 12

    NewLayout/N=$previewWinName/K=1

    Variable i, rowIdx, colIdx
    Variable rectL, rectT, rectR, rectB
    Variable rowBaseX, rowBaseY
    Variable layerIdx
    String graphName, imgName, imgPath
    Wave/Z imgWave

    for (i = 0; i < nSel; i += 1)
        layerIdx = round(selLayers[i])

        graphName = sg_graph_name_from_index(i)
        imgName   = sg_img_name_from_index(i)
        imgPath   = sg_preview_tmp_df() + imgName

        Wave/Z imgWave = $imgPath
        if (!WaveExists(imgWave))
            continue
        endif

        KillWindow/Z $graphName
        Display/W=(0,0,graphW,graphH)/N=$graphName
        AppendImage/W=$graphName imgWave

        sg_apply_image_style_basic(graphName, imgName, useFixedRange, fixedC0, fixedC1)
        sg_apply_panel_textbox(graphName, layerIdx)

        rowIdx = floor(i / nCols)
        colIdx = mod(i, nCols)

        // -------- graph internal style --------
        Label/W=$graphName bottom "k\\B// \\M(Å\\S-1\\M)"

        if (colIdx == 0)
            Label/W=$graphName left "E-E\\Bf \\M (eV)"
            ModifyGraph/W=$graphName lblMargin(left)=10,lblLatPos(left)=5
            ModifyGraph/W=$graphName margin(right)=1
        else
            ModifyGraph/W=$graphName tick(left)=3,noLabel(left)=2
            ModifyGraph/W=$graphName margin(left)=1,margin(right)=1
        endif

        // -------- layout position --------
        rowBaseY = top0 + rowIdx * (graphH + gapY)

        if (colIdx == 0)
            rectL = left0 + firstColLeftPad
            rectR = rectL + firstColScale * graphW
        else
            rowBaseX = left0 + firstColLeftPad + firstColScale * graphW + gapX
            rectL = rowBaseX + (colIdx - 1) * (graphW + gapX)
            rectR = rectL + graphW
        endif

        rectT = rowBaseY
        rectB = rectT + graphH

        AppendLayoutObject/R=(rectL,rectT,rectR,rectB)/W=$previewWinName/F=0 graph $graphName
    endfor

    DoWindow/F $previewWinName
    return 0
End

Function sg_render_preview_dispatch()
    sg_init_defaults_if_needed()

    SVAR renderStyle = root:ARPES_LJZ:SliceGallery:renderStyle

    if (StringMatch(renderStyle, "LegacyTight"))
        return sg_render_preview_legacytight()
    endif

    if (StringMatch(renderStyle, "EqualPlot"))
        return sg_render_preview_equalplot()
    endif

    renderStyle = "LegacyTight"
    return sg_render_preview_legacytight()
End
//============================================================
// UI callbacks
//============================================================

Function sg_btn_preview(ctrlName) : ButtonControl
    String ctrlName

    sg_render_preview_dispatch()
    return 0
End


//============================================================
// Debug / command-line entry
//============================================================

Proc SliceGallery_LJZ_Preview()
    sg_render_preview_dispatch()
End

Function sg_render_preview_equalplot()
    sg_init_defaults_if_needed()

    if (!sg_target_wave_is_ready(1))
        return -1
    endif

    Wave selLayers = root:ARPES_LJZ:SliceGallery:selLayers
    Variable nSel = DimSize(selLayers, 0)
    if (nSel <= 0)
        DoAlert 0, "SliceGallery: selLayers is empty. Please build layers first."
        return -1
    endif

    SVAR previewWinName = root:ARPES_LJZ:SliceGallery:previewWinName

    // close old preview layout
    DoWindow/K $previewWinName

    // close old graph windows
    Variable iKill
    for (iKill = 0; iKill < 128; iKill += 1)
        String oldGraphName = sg_graph_name_from_index(iKill)
        KillWindow/Z $oldGraphName
    endfor

    // rebuild temp slices
    if (sg_extract_selected_slices_to_preview_tmp() != 0)
        return -1
    endif

    SVAR layoutMode = root:ARPES_LJZ:SliceGallery:layoutMode
    NVAR displayMode = root:ARPES_LJZ:SliceGallery:displayMode
    NVAR colorMode  = root:ARPES_LJZ:SliceGallery:colorMode

    Variable useFixedRange = 0
    Variable fixedC0 = NaN
    Variable fixedC1 = NaN

    if (sg_second_derivative_view_enabled())
        if (sg_compute_shared_color_range() != 0)
            DoAlert 0, "SliceGallery: failed to compute second-derivative color range."
            return -1
        endif
        NVAR cMinDeriv = root:ARPES_LJZ:SliceGallery:cMin
        NVAR cMaxDeriv = root:ARPES_LJZ:SliceGallery:cMax
        useFixedRange = 1
        fixedC0 = cMinDeriv
        fixedC1 = cMaxDeriv
    elseif (colorMode == 1)
        if (sg_compute_shared_color_range() != 0)
            DoAlert 0, "SliceGallery: failed to compute shared color range."
            return -1
        endif
        NVAR cMinShared = root:ARPES_LJZ:SliceGallery:cMin
        NVAR cMaxShared = root:ARPES_LJZ:SliceGallery:cMax
        useFixedRange = 1
        fixedC0 = cMinShared
        fixedC1 = cMaxShared
    elseif (colorMode == 2)
        if (sg_validate_manual_color_range() != 0)
            return -1
        endif
        NVAR cMinManual = root:ARPES_LJZ:SliceGallery:cMin
        NVAR cMaxManual = root:ARPES_LJZ:SliceGallery:cMax
        useFixedRange = 1
        fixedC0 = cMinManual
        fixedC1 = cMaxManual
    else
        useFixedRange = 0
    endif

    Variable layoutCode = sg_get_layout_code(nSel, layoutMode)
    Variable nRows = sg_layout_rows_from_code(layoutCode)
    Variable nCols = sg_layout_cols_from_code(layoutCode)

    // --------------------------------------------------------
    // EqualPlot geometry:
    // plotW/plotH = 真正想要统一的数据绘图区大小
    // firstColExtraW = 第一列额外给 y 轴标签/刻度留的宽度
    // --------------------------------------------------------
    Variable plotW, plotH
    if (nCols >= 6)
        plotW = 95
        plotH = 180
    elseif (nCols >= 4)
        plotW = 110
        plotH = 190
    else
        plotW = 125
        plotH = 200
    endif

    Variable firstColExtraW = 36      // 这就是“补给第一列的轴区宽度”
    Variable gapX = 0
    Variable gapY = 6
    Variable left0 = 12
    Variable top0  = 12

    NewLayout/N=$previewWinName/K=1

    Variable i, rowIdx, colIdx
    Variable rectL, rectT, rectR, rectB
    Variable rowBaseX, rowBaseY
    Variable thisGraphW, thisGraphH
    Variable layerIdx

    String graphName, imgName, imgPath
    Wave/Z imgWave

    for (i = 0; i < nSel; i += 1)
        layerIdx = round(selLayers[i])

        graphName = sg_graph_name_from_index(i)
        imgName   = sg_img_name_from_index(i)
        imgPath   = sg_preview_tmp_df() + imgName

        Wave/Z imgWave = $imgPath
        if (!WaveExists(imgWave))
            continue
        endif

        rowIdx = floor(i / nCols)
        colIdx = mod(i, nCols)

        if (colIdx == 0)
            thisGraphW = plotW + firstColExtraW
        else
            thisGraphW = plotW
        endif
        thisGraphH = plotH

        KillWindow/Z $graphName
        Display/W=(0,0,thisGraphW,thisGraphH)/N=$graphName
        AppendImage/W=$graphName imgWave

        sg_apply_image_style_basic(graphName, imgName, useFixedRange, fixedC0, fixedC1)
        sg_apply_panel_textbox(graphName, layerIdx)

        // -------- graph internal style --------
        Label/W=$graphName bottom "k\\B// \\M(Å\\S-1\\M)"

        if (colIdx == 0)
            Label/W=$graphName left "E-E\\Bf \\M (eV)"
            ModifyGraph/W=$graphName margin(left)=firstColExtraW,margin(right)=1
            ModifyGraph/W=$graphName lblMargin(left)=10,lblLatPos(left)=5
        else
            ModifyGraph/W=$graphName tick(left)=3,noLabel(left)=2
            ModifyGraph/W=$graphName margin(left)=1,margin(right)=1
        endif

        // -------- layout position --------
        rowBaseX = left0
        rowBaseY = top0 + rowIdx * (plotH + gapY)

        if (colIdx == 0)
            rectL = rowBaseX
            rectR = rectL + plotW + firstColExtraW
        else
            rectL = rowBaseX + (plotW + firstColExtraW + gapX) + (colIdx - 1) * (plotW + gapX)
            rectR = rectL + plotW
        endif

        rectT = rowBaseY
        rectB = rectT + plotH

        AppendLayoutObject/R=(rectL,rectT,rectR,rectB)/W=$previewWinName/F=0 graph $graphName
    endfor

    DoWindow/F $previewWinName
    return 0
End

//============================================================
// Module 5
// Export current preview by copying waves + renaming windows
// Allow overwrite
//============================================================

Function/S sg_export_root_df()
    sg_ensure_folder()
    NewDataFolder/O root:ARPES_LJZ:SliceGallery:EXPORT
    return "root:ARPES_LJZ:SliceGallery:EXPORT:"
End


Function/S sg_export_df_from_name(baseName)
    String baseName

    String clean = CleanupName(baseName, 0)
    if (strlen(clean) == 0)
        clean = "SGExport"
    endif

    return sg_export_root_df() + clean + ":"
End


Function/S sg_export_graph_name(baseName, idx)
    String baseName
    Variable idx

    String s
    sprintf s, "%s_G%03d", CleanupName(baseName, 0), round(idx)
    return CleanupName(s, 0)
End


Function/S sg_export_layout_name(baseName)
    String baseName
    return CleanupName(CleanupName(baseName, 0) + "_Layout", 0)
End


Function sg_export_duplicate_preview_waves(outDF)
    String outDF

    Wave selLayers = root:ARPES_LJZ:SliceGallery:selLayers
    Variable nSel = DimSize(selLayers, 0)

    Variable i
    for (i = 0; i < nSel; i += 1)
        String srcPath = sg_preview_tmp_df() + sg_img_name_from_index(i)
        String dstPath = outDF + sg_img_name_from_index(i)

        Wave/Z wsrc = $srcPath
        if (!WaveExists(wsrc))
            continue
        endif

        Duplicate/O wsrc, $dstPath
    endfor

    Duplicate/O selLayers, $(outDF + "selLayers")
    Duplicate/O root:ARPES_LJZ:SliceGallery:selValuesDim2, $(outDF + "selValuesDim2")

    return 0
End


Function sg_export_kill_existing(baseName)
    String baseName

    Variable i
    String layoutName = sg_export_layout_name(baseName)

    DoWindow/K $layoutName

    for (i = 0; i < 256; i += 1)
        String gname = sg_export_graph_name(baseName, i)
        KillWindow/Z $gname
    endfor

    String outDF = sg_export_df_from_name(baseName)
    String outNoColon = RemoveEnding(outDF, ":")

    KillDataFolder/Z $outNoColon
    NewDataFolder/O $outNoColon

    return 0
End


Function sg_export_current_preview()
    sg_init_defaults_if_needed()

    SVAR exportBaseName = root:ARPES_LJZ:SliceGallery:exportBaseName
    SVAR previewWinName = root:ARPES_LJZ:SliceGallery:previewWinName
    SVAR exportWinName  = root:ARPES_LJZ:SliceGallery:exportWinName

    Wave selLayers = root:ARPES_LJZ:SliceGallery:selLayers
    Variable nSel = DimSize(selLayers, 0)

    if (nSel <= 0)
        DoAlert 0, "SliceGallery: no selected layers to export."
        return -1
    endif

    DoWindow $previewWinName
    if (V_flag == 0)
        DoAlert 0, "SliceGallery: no preview layout exists. Please Preview first."
        return -1
    endif

    String baseName = CleanupName(exportBaseName, 0)
    if (strlen(baseName) == 0)
        baseName = "SGExport"
        exportBaseName = baseName
    endif

    // overwrite mode
    sg_export_kill_existing(baseName)

    String outDF = sg_export_df_from_name(baseName)
    String layoutName = sg_export_layout_name(baseName)

    // copy current preview waves to persistent DF
    sg_export_duplicate_preview_waves(outDF)

    // rebuild exported graph windows from persistent waves
    Variable i, layerIdx
    Variable nCols, layoutCode
    Variable rowIdx, colIdx
    Variable rectL, rectT, rectR, rectB
    Variable rowBaseX, rowBaseY
    Variable graphW, graphH
    Variable plotW, plotH, firstColExtraW
    Variable firstColScale, firstColLeftPad
    Variable gapX, gapY, left0, top0

    SVAR layoutMode = root:ARPES_LJZ:SliceGallery:layoutMode
    SVAR renderStyle = root:ARPES_LJZ:SliceGallery:renderStyle
    NVAR displayMode = root:ARPES_LJZ:SliceGallery:displayMode
    NVAR colorMode = root:ARPES_LJZ:SliceGallery:colorMode

    Variable useFixedRange = 0
    Variable fixedC0 = NaN
    Variable fixedC1 = NaN

    if (sg_second_derivative_view_enabled() || colorMode == 1)
        // 用导出后的永久 wave 算 shared range
        Variable globalMin = NaN, globalMax = NaN
        for (i = 0; i < nSel; i += 1)
            Wave/Z wt = $(outDF + sg_img_name_from_index(i))
            if (!WaveExists(wt))
                continue
            endif
            WaveStats/Q wt
            if (numtype(globalMin) != 0)
                globalMin = V_min
                globalMax = V_max
            else
                globalMin = min(globalMin, V_min)
                globalMax = max(globalMax, V_max)
            endif
        endfor
        if (numtype(globalMin) == 0 && numtype(globalMax) == 0)
            if (sg_second_derivative_view_enabled())
                if (sg_set_second_deriv_color_range(globalMin, globalMax) == 0)
                    NVAR cMinDeriv = root:ARPES_LJZ:SliceGallery:cMin
                    NVAR cMaxDeriv = root:ARPES_LJZ:SliceGallery:cMax
                    useFixedRange = 1
                    fixedC0 = cMinDeriv
                    fixedC1 = cMaxDeriv
                endif
            else
                if (globalMin == globalMax)
                    globalMin -= 1e-12
                    globalMax += 1e-12
                endif
                useFixedRange = 1
                fixedC0 = globalMin
                fixedC1 = globalMax
            endif
        endif
    elseif (colorMode == 2)
        if (sg_validate_manual_color_range() != 0)
            return -1
        endif
        NVAR cMinManual = root:ARPES_LJZ:SliceGallery:cMin
        NVAR cMaxManual = root:ARPES_LJZ:SliceGallery:cMax
        useFixedRange = 1
        fixedC0 = cMinManual
        fixedC1 = cMaxManual
    endif

    layoutCode = sg_get_layout_code(nSel, layoutMode)
    nCols = sg_layout_cols_from_code(layoutCode)

    gapX = 0
    gapY = 6
    left0 = 12
    top0  = 12

    NewLayout/N=$layoutName/K=1

    if (StringMatch(renderStyle, "EqualPlot"))
        if (nCols >= 6)
            plotW = 95; plotH = 180
        elseif (nCols >= 4)
            plotW = 110; plotH = 190
        else
            plotW = 125; plotH = 200
        endif
        firstColExtraW = 36

        for (i = 0; i < nSel; i += 1)
            layerIdx = round(selLayers[i])

            String gname = sg_export_graph_name(baseName, i)
            String imgName = sg_img_name_from_index(i)
            Wave/Z imgWave = $(outDF + imgName)
            if (!WaveExists(imgWave))
                continue
            endif

            rowIdx = floor(i / nCols)
            colIdx = mod(i, nCols)

            Variable thisGraphW = plotW
            if (colIdx == 0)
                thisGraphW = plotW + firstColExtraW
            endif

            Display/W=(0,0,thisGraphW,plotH)/N=$gname
            AppendImage/W=$gname imgWave

            sg_apply_image_style_basic(gname, NameOfWave(imgWave), useFixedRange, fixedC0, fixedC1)
            sg_apply_panel_textbox(gname, layerIdx)

            Label/W=$gname bottom "k\\B// \\M(Å\\S-1\\M)"
            if (colIdx == 0)
                Label/W=$gname left "E-E\\Bf \\M (eV)"
                ModifyGraph/W=$gname margin(left)=firstColExtraW,margin(right)=1
                ModifyGraph/W=$gname lblMargin(left)=10,lblLatPos(left)=5
            else
                ModifyGraph/W=$gname tick(left)=3,noLabel(left)=2
                ModifyGraph/W=$gname margin(left)=1,margin(right)=1
            endif

            rowBaseX = left0
            rowBaseY = top0 + rowIdx * (plotH + gapY)

            if (colIdx == 0)
                rectL = rowBaseX
                rectR = rectL + plotW + firstColExtraW
            else
                rectL = rowBaseX + (plotW + firstColExtraW + gapX) + (colIdx - 1) * (plotW + gapX)
                rectR = rectL + plotW
            endif

            rectT = rowBaseY
            rectB = rectT + plotH

            AppendLayoutObject/R=(rectL,rectT,rectR,rectB)/W=$layoutName/F=0 graph $gname
        endfor

    else
        if (nCols >= 6)
            graphW = 95; graphH = 180
        elseif (nCols >= 4)
            graphW = 110; graphH = 190
        else
            graphW = 125; graphH = 200
        endif

        firstColScale = 1.55
        firstColLeftPad = 0.18 * graphW

        for (i = 0; i < nSel; i += 1)
            layerIdx = round(selLayers[i])

            String gname2 = sg_export_graph_name(baseName, i)
            String imgName2 = sg_img_name_from_index(i)
            Wave/Z imgWave2 = $(outDF + imgName2)
            if (!WaveExists(imgWave2))
                continue
            endif

            Display/W=(0,0,graphW,graphH)/N=$gname2
            AppendImage/W=$gname2 imgWave2

            sg_apply_image_style_basic(gname2, NameOfWave(imgWave2), useFixedRange, fixedC0, fixedC1)
            sg_apply_panel_textbox(gname2, layerIdx)

            rowIdx = floor(i / nCols)
            colIdx = mod(i, nCols)

            Label/W=$gname2 bottom "k\\B// \\M(Å\\S-1\\M)"
            if (colIdx == 0)
                Label/W=$gname2 left "E-E\\Bf \\M (eV)"
                ModifyGraph/W=$gname2 lblMargin(left)=10,lblLatPos(left)=5
                ModifyGraph/W=$gname2 margin(right)=1
            else
                ModifyGraph/W=$gname2 tick(left)=3,noLabel(left)=2
                ModifyGraph/W=$gname2 margin(left)=1,margin(right)=1
            endif

            rowBaseY = top0 + rowIdx * (graphH + gapY)

            if (colIdx == 0)
                rectL = left0 + firstColLeftPad
                rectR = rectL + firstColScale * graphW
            else
                rowBaseX = left0 + firstColLeftPad + firstColScale * graphW + gapX
                rectL = rowBaseX + (colIdx - 1) * (graphW + gapX)
                rectR = rectL + graphW
            endif

            rectT = rowBaseY
            rectB = rectT + graphH

            AppendLayoutObject/R=(rectL,rectT,rectR,rectB)/W=$layoutName/F=0 graph $gname2
        endfor
    endif

    exportWinName = layoutName
    DoWindow/F $layoutName

    Print "SliceGallery export layout = " + layoutName
    Print "SliceGallery export waves  = " + outDF

    return 0
End


Function sg_btn_export(ctrlName) : ButtonControl
    String ctrlName
    return sg_export_current_preview()
End

//============================================================
// CT browser helpers
//============================================================

Function sg_rebuild_ct_list()
    sg_init_defaults_if_needed()

    Wave/T ctItems = root:ARPES_LJZ:SliceGallery:CT_LB_Items
    Wave/U/B ctSel = root:ARPES_LJZ:SliceGallery:CT_LB_Sel
    SVAR ctMenuList = root:ARPES_LJZ:SliceGallery:ctMenuList

    ctluz_ensure_folder()
    ctluz_refresh_ctlib_menu()

    SVAR/Z libMenu = root:ARPES_LJZ:CTLUZ:ctlib_menu_list

    String s = ""
    if (SVAR_Exists(libMenu))
        s = libMenu
    endif

    Variable n = ItemsInList(s, ";")
    Variable i, outN = 0
    String nm

    // 先数有效项（去掉空串和 None）
    for (i=0; i<n; i+=1)
        nm = StringFromList(i, s, ";")
        if (strlen(nm) == 0)
            continue
        endif
        if (StringMatch(nm, "None"))
            continue
        endif
        outN += 1
    endfor

    Redimension/N=(outN) ctItems, ctSel
    ctSel = 0

    Variable j = 0
    for (i=0; i<n; i+=1)
        nm = StringFromList(i, s, ";")
        if (strlen(nm) == 0)
            continue
        endif
        if (StringMatch(nm, "None"))
            continue
        endif

        ctItems[j] = nm
        ctSel[j] = 0
        j += 1
    endfor

    ctMenuList = s
    return 0
End




Function/S sg_ct_display_string()
    sg_init_defaults_if_needed()

    SVAR ctPick = root:ARPES_LJZ:SliceGallery:ctPick

    if (strlen(ctPick) == 0)
        return "CT: Current"
    endif

    if (StringMatch(ctPick, "Current"))
        return "CT: Current"
    endif

    return "CT: " + ctPick
End

Function/S sg_color_mode_hint_string()
    sg_init_defaults_if_needed()

    NVAR displayMode = root:ARPES_LJZ:SliceGallery:displayMode

    if (sg_second_derivative_view_enabled())
        return "Mode: " + sg_second_derivative_mode_label(displayMode) + "; inverted CT + c range [auto min, 0]"
    endif

    return "Mode: Raw slices; color popup controls PerPanel/Shared/Manual"
End

Function/S sg_color_range_hint_string()
    sg_init_defaults_if_needed()

    NVAR displayMode = root:ARPES_LJZ:SliceGallery:displayMode
    NVAR colorMode   = root:ARPES_LJZ:SliceGallery:colorMode
    NVAR cMin        = root:ARPES_LJZ:SliceGallery:cMin
    NVAR cMax        = root:ARPES_LJZ:SliceGallery:cMax

    String outStr
    if (sg_second_derivative_view_enabled())
        if (numtype(cMin) == 0)
            sprintf outStr, "Suggested c range: cMin≈%.4g, cMax=0", cMin
        else
            outStr = "Suggested c range: cMin=auto(min), cMax=0"
        endif
        return outStr
    endif

    if (round(colorMode) == 2)
        if (numtype(cMin) == 0 && numtype(cMax) == 0)
            sprintf outStr, "Manual c range: [%.4g, %.4g]", cMin, cMax
        else
            outStr = "Manual c range: enter numeric cMin < cMax"
        endif
    elseif (round(colorMode) == 1)
        outStr = "SharedAuto: preview/export will fill cMin/cMax from selected slices"
    else
        outStr = "PerPanelAuto: each panel uses its own auto range"
    endif

    return outStr
End


Function sg_btn_open_ct_browser(ctrlName) : ButtonControl
    String ctrlName

    String winName = "SG_CT_Browser_Panel"

    DoWindow/F $winName
    if (V_flag != 0)
        return 0
    endif

    sg_rebuild_ct_list()

    Wave/T wList = root:ARPES_LJZ:SliceGallery:CT_LB_Items
    Wave/U/B wSel = root:ARPES_LJZ:SliceGallery:CT_LB_Sel
    SVAR curName = root:ARPES_LJZ:SliceGallery:ctPick

    wSel = 0

    Variable findIdx = -1
    if (!StringMatch(curName, "Current"))
        FindValue/TEXT=curName/TXOP=4 wList
        if (V_Value >= 0)
            wSel[V_Value] = 1
            findIdx = V_Value
        endif
    endif

    NewPanel/K=1/W=(500,200,760,610) as "Select Color Table"
    DoWindow/C $winName

    ListBox lb_ct,pos={10,10},size={240,350},proc=sg_ct_browser_lb_proc
    ListBox lb_ct,listWave=root:ARPES_LJZ:SliceGallery:CT_LB_Items
    ListBox lb_ct,selWave=root:ARPES_LJZ:SliceGallery:CT_LB_Sel
    ListBox lb_ct,mode=1

    if (findIdx >= 0)
        ListBox lb_ct,row=findIdx
    endif

    Button btn_refresh,pos={10,372},size={60,20},title="Refresh",proc=sg_ct_browser_refresh
    Button btn_current,pos={92,372},size={78,20},title="Use Current",proc=sg_ct_browser_use_current
    Button btn_close,pos={190,372},size={60,20},title="Close",proc=sg_ct_browser_close

    return 0
End


Function sg_ct_browser_refresh(ctrlName) : ButtonControl
    String ctrlName

    sg_rebuild_ct_list()

    ListBox lb_ct,win=SG_CT_Browser_Panel,listWave=root:ARPES_LJZ:SliceGallery:CT_LB_Items
    ListBox lb_ct,win=SG_CT_Browser_Panel,selWave=root:ARPES_LJZ:SliceGallery:CT_LB_Sel

    return 0
End


Function sg_ct_browser_use_current(ctrlName) : ButtonControl
    String ctrlName

    SVAR ctPick = root:ARPES_LJZ:SliceGallery:ctPick
    Wave/U/B wSel = root:ARPES_LJZ:SliceGallery:CT_LB_Sel

    ctPick = "Current"
    wSel = 0

    DoWindow SLICEGALLERY_LJZ_P
    if (V_flag)
        TitleBox sg_tb_ct_current,win=SLICEGALLERY_LJZ_P,title=sg_ct_display_string()
    endif

    DoWindow/K SG_CT_Browser_Panel
    return 0
End


Function sg_ct_browser_lb_proc(ctrlName, row, col, eventCode) : ListBoxControl
    String ctrlName
    Variable row, col, eventCode

    if (eventCode != 1 && eventCode != 3 && eventCode != 4)
        return 0
    endif

    if (row < 0)
        return 0
    endif

    Wave/T wList = root:ARPES_LJZ:SliceGallery:CT_LB_Items
    Wave/U/B wSel = root:ARPES_LJZ:SliceGallery:CT_LB_Sel
    SVAR ctPick = root:ARPES_LJZ:SliceGallery:ctPick

    if (row >= DimSize(wList, 0))
        return 0
    endif

    wSel = 0
    wSel[row] = 1

    ctPick = wList[row]

    DoWindow SLICEGALLERY_LJZ_P
    if (V_flag)
        TitleBox sg_tb_ct_current,win=SLICEGALLERY_LJZ_P,title=sg_ct_display_string()
    endif

    if (eventCode == 4)
        DoWindow/K SG_CT_Browser_Panel
    endif

    return 0
End


Function sg_ct_browser_close(ctrlName) : ButtonControl
    String ctrlName
    DoWindow/K SG_CT_Browser_Panel
    return 0
End
