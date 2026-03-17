#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
//============================================================
// CTLUZ_LJZ: 5-point ColorTable + Lookup wave + Apply to Top Graph
// Igor identifiers are case-insensitive -> avoid any name collisions by prefixing.
// State in: root:ARPES_LJZ:CTLUZ
//============================================================

Function ctluz_ensure_folder()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:CTLUZ
    NewDataFolder/O root:ARPES_LJZ:CTLUZ:CTLIB     // <-- NEW: 存库
    
    ctluz_install_builtin_ctlib()
End

// ----------------------------
// Entry
// ----------------------------
Proc CTLUZ_LJZ()
    ctluz_ensure_folder()
    SetDataFolder root:ARPES_LJZ:CTLUZ

    // ---- positions (0..1) ----
    Variable/G ct_p0 = 0
    Variable/G ct_p1 = 0.25
    Variable/G ct_p2 = 0.50
    Variable/G ct_p3 = 0.75
    Variable/G ct_p4 = 1

    // ---- colors (RGB 0..255) ----
    // default: black -> blue -> cyan -> yellow -> white
    Variable/G ct_rgb0_r=0,   ct_rgb0_g=0,   ct_rgb0_b=0
    Variable/G ct_rgb1_r=0,   ct_rgb1_g=0,   ct_rgb1_b=255
    Variable/G ct_rgb2_r=0,   ct_rgb2_g=255, ct_rgb2_b=255
    Variable/G ct_rgb3_r=255, ct_rgb3_g=255, ct_rgb3_b=0
    Variable/G ct_rgb4_r=255, ct_rgb4_g=255, ct_rgb4_b=255
    // ---- NEW: swap points (0..4) ----
    Variable/G ct_swap_x = 0
    Variable/G ct_swap_y = 1

    // ---- output waves ----
    // CT_Table: 65536x4 U16, RGBA 0..65535 (alpha=65535)
    // CT_LUT  : 65536 float, 0..1
    Make/O/W/U/N=(65536,4) ct_table
    Make/O/N=65536 ct_lut
	    // ---- NEW: library UI state ----
    String/G ct_save_name = ""          // 你输入的保存名字
    String/G ct_pick_name = ""          // popup 选中的库名字
    String/G ctlib_menu_list = "None;"  // popup 使用的列表（分号分隔）

    ctluz_refresh_ctlib_menu()          // NEW: 生成菜单列表

    ctluz_rebuild()

    SetDataFolder root:
    DoWindow/F CTLUZ_LJZ_P
    if (V_flag == 0)
        CTLUZ_LJZ_P()
    endif
End

// ----------------------------
// clamp helpers
// ----------------------------
Function ctluz_clamp(v, lo, hi)
    Variable v, lo, hi
    if (v < lo)
        return lo
    endif
    if (v > hi)
        return hi
    endif
    return v
End

// ----------------------------
// rebuild CT + LUT from variables
// ----------------------------
Function ctluz_rebuild()
    ctluz_ensure_folder()
    SetDataFolder root:ARPES_LJZ:CTLUZ

    // ---- read vars ----
    NVAR ct_p0 = root:ARPES_LJZ:CTLUZ:ct_p0
    NVAR ct_p1 = root:ARPES_LJZ:CTLUZ:ct_p1
    NVAR ct_p2 = root:ARPES_LJZ:CTLUZ:ct_p2
    NVAR ct_p3 = root:ARPES_LJZ:CTLUZ:ct_p3
    NVAR ct_p4 = root:ARPES_LJZ:CTLUZ:ct_p4

    NVAR ct_rgb0_r=root:ARPES_LJZ:CTLUZ:ct_rgb0_r; NVAR ct_rgb0_g=root:ARPES_LJZ:CTLUZ:ct_rgb0_g; NVAR ct_rgb0_b=root:ARPES_LJZ:CTLUZ:ct_rgb0_b
    NVAR ct_rgb1_r=root:ARPES_LJZ:CTLUZ:ct_rgb1_r; NVAR ct_rgb1_g=root:ARPES_LJZ:CTLUZ:ct_rgb1_g; NVAR ct_rgb1_b=root:ARPES_LJZ:CTLUZ:ct_rgb1_b
    NVAR ct_rgb2_r=root:ARPES_LJZ:CTLUZ:ct_rgb2_r; NVAR ct_rgb2_g=root:ARPES_LJZ:CTLUZ:ct_rgb2_g; NVAR ct_rgb2_b=root:ARPES_LJZ:CTLUZ:ct_rgb2_b
    NVAR ct_rgb3_r=root:ARPES_LJZ:CTLUZ:ct_rgb3_r; NVAR ct_rgb3_g=root:ARPES_LJZ:CTLUZ:ct_rgb3_g; NVAR ct_rgb3_b=root:ARPES_LJZ:CTLUZ:ct_rgb3_b
    NVAR ct_rgb4_r=root:ARPES_LJZ:CTLUZ:ct_rgb4_r; NVAR ct_rgb4_g=root:ARPES_LJZ:CTLUZ:ct_rgb4_g; NVAR ct_rgb4_b=root:ARPES_LJZ:CTLUZ:ct_rgb4_b

    Wave/W/U ct_table = root:ARPES_LJZ:CTLUZ:ct_table
    Wave     ct_lut   = root:ARPES_LJZ:CTLUZ:ct_lut

    // ---- sanitize rgb ----
    ct_rgb0_r = ctluz_clamp(ct_rgb0_r,0,255); ct_rgb0_g=ctluz_clamp(ct_rgb0_g,0,255); ct_rgb0_b=ctluz_clamp(ct_rgb0_b,0,255)
    ct_rgb1_r = ctluz_clamp(ct_rgb1_r,0,255); ct_rgb1_g=ctluz_clamp(ct_rgb1_g,0,255); ct_rgb1_b=ctluz_clamp(ct_rgb1_b,0,255)
    ct_rgb2_r = ctluz_clamp(ct_rgb2_r,0,255); ct_rgb2_g=ctluz_clamp(ct_rgb2_g,0,255); ct_rgb2_b=ctluz_clamp(ct_rgb2_b,0,255)
    ct_rgb3_r = ctluz_clamp(ct_rgb3_r,0,255); ct_rgb3_g=ctluz_clamp(ct_rgb3_g,0,255); ct_rgb3_b=ctluz_clamp(ct_rgb3_b,0,255)
    ct_rgb4_r = ctluz_clamp(ct_rgb4_r,0,255); ct_rgb4_g=ctluz_clamp(ct_rgb4_g,0,255); ct_rgb4_b=ctluz_clamp(ct_rgb4_b,0,255)

    // ---- sanitize positions: force p0=0, p4=1, enforce p1<p2<p3 ----
    Variable loc_eps = 1e-4
    ct_p0 = 0
    ct_p4 = 1

    ct_p1 = ctluz_clamp(ct_p1, loc_eps, 1-loc_eps)
    ct_p2 = ctluz_clamp(ct_p2, loc_eps, 1-loc_eps)
    ct_p3 = ctluz_clamp(ct_p3, loc_eps, 1-loc_eps)

    if (ct_p1 > ct_p2 - loc_eps)
        ct_p1 = ct_p2 - loc_eps
    endif
    if (ct_p2 < ct_p1 + loc_eps)
        ct_p2 = ct_p1 + loc_eps
    endif
    if (ct_p2 > ct_p3 - loc_eps)
        ct_p2 = ct_p3 - loc_eps
    endif
    if (ct_p3 < ct_p2 + loc_eps)
        ct_p3 = ct_p2 + loc_eps
    endif
    if (ct_p3 > 1 - loc_eps)
        ct_p3 = 1 - loc_eps
    endif

    // ---- build CT_Table in base space s in [0,1] with 4 equal segments ----
    Variable loc_n = DimSize(ct_table,0)
    Variable loc_i, loc_seg
    Variable loc_s, loc_u
    Variable loc_r0, loc_g0, loc_b0, loc_r1, loc_g1, loc_b1

    for (loc_i=0; loc_i<loc_n; loc_i+=1)
        loc_s = loc_i/(loc_n-1.0)
        loc_seg = floor(4*loc_s)
        if (loc_seg < 0)
            loc_seg = 0
        endif
        if (loc_seg > 3)
            loc_seg = 3
        endif
        loc_u = 4*loc_s - loc_seg

        if (loc_seg == 0)
            loc_r0 = ct_rgb0_r*257; loc_g0 = ct_rgb0_g*257; loc_b0 = ct_rgb0_b*257
            loc_r1 = ct_rgb1_r*257; loc_g1 = ct_rgb1_g*257; loc_b1 = ct_rgb1_b*257
        elseif (loc_seg == 1)
            loc_r0 = ct_rgb1_r*257; loc_g0 = ct_rgb1_g*257; loc_b0 = ct_rgb1_b*257
            loc_r1 = ct_rgb2_r*257; loc_g1 = ct_rgb2_g*257; loc_b1 = ct_rgb2_b*257
        elseif (loc_seg == 2)
            loc_r0 = ct_rgb2_r*257; loc_g0 = ct_rgb2_g*257; loc_b0 = ct_rgb2_b*257
            loc_r1 = ct_rgb3_r*257; loc_g1 = ct_rgb3_g*257; loc_b1 = ct_rgb3_b*257
        else
            loc_r0 = ct_rgb3_r*257; loc_g0 = ct_rgb3_g*257; loc_b0 = ct_rgb3_b*257
            loc_r1 = ct_rgb4_r*257; loc_g1 = ct_rgb4_g*257; loc_b1 = ct_rgb4_b*257
        endif

        ct_table[loc_i][0] = round((1-loc_u)*loc_r0 + loc_u*loc_r1)
        ct_table[loc_i][1] = round((1-loc_u)*loc_g0 + loc_u*loc_g1)
        ct_table[loc_i][2] = round((1-loc_u)*loc_b0 + loc_u*loc_b1)
        ct_table[loc_i][3] = 65535
    endfor

    // ---- build lookup: desired t -> base s ----
    Variable loc_t, loc_denom
    for (loc_i=0; loc_i<loc_n; loc_i+=1)
        loc_t = loc_i/(loc_n-1.0)

        if (loc_t <= ct_p1)
            loc_denom = (ct_p1 - ct_p0)
            loc_u = (loc_denom <= 0) ? 0 : (loc_t - ct_p0)/loc_denom
            ct_lut[loc_i] = 0 + 0.25*loc_u
        elseif (loc_t <= ct_p2)
            loc_denom = (ct_p2 - ct_p1)
            loc_u = (loc_denom <= 0) ? 0 : (loc_t - ct_p1)/loc_denom
            ct_lut[loc_i] = 0.25 + 0.25*loc_u
        elseif (loc_t <= ct_p3)
            loc_denom = (ct_p3 - ct_p2)
            loc_u = (loc_denom <= 0) ? 0 : (loc_t - ct_p2)/loc_denom
            ct_lut[loc_i] = 0.50 + 0.25*loc_u
        else
            loc_denom = (ct_p4 - ct_p3)
            loc_u = (loc_denom <= 0) ? 0 : (loc_t - ct_p3)/loc_denom
            ct_lut[loc_i] = 0.75 + 0.25*loc_u
        endif

        if (ct_lut[loc_i] < 0)
            ct_lut[loc_i] = 0
        endif
        if (ct_lut[loc_i] > 1)
            ct_lut[loc_i] = 1
        endif
    endfor

    SetDataFolder root:
    return 0
End
// ============================
// NEW: get/set RGB(0..255) for point 0..4 (case-insensitive safe)
// ============================
Function ctluz_get_rgb8(loc_pt, loc_r, loc_g, loc_b)
    Variable loc_pt
    Variable &loc_r, &loc_g, &loc_b

    switch (loc_pt)
        case 0:
            NVAR vR=root:ARPES_LJZ:CTLUZ:ct_rgb0_r; NVAR vG=root:ARPES_LJZ:CTLUZ:ct_rgb0_g; NVAR vB=root:ARPES_LJZ:CTLUZ:ct_rgb0_b
            loc_r=vR; loc_g=vG; loc_b=vB
            break
        case 1:
            NVAR vR=root:ARPES_LJZ:CTLUZ:ct_rgb1_r; NVAR vG=root:ARPES_LJZ:CTLUZ:ct_rgb1_g; NVAR vB=root:ARPES_LJZ:CTLUZ:ct_rgb1_b
            loc_r=vR; loc_g=vG; loc_b=vB
            break
        case 2:
            NVAR vR=root:ARPES_LJZ:CTLUZ:ct_rgb2_r; NVAR vG=root:ARPES_LJZ:CTLUZ:ct_rgb2_g; NVAR vB=root:ARPES_LJZ:CTLUZ:ct_rgb2_b
            loc_r=vR; loc_g=vG; loc_b=vB
            break
        case 3:
            NVAR vR=root:ARPES_LJZ:CTLUZ:ct_rgb3_r; NVAR vG=root:ARPES_LJZ:CTLUZ:ct_rgb3_g; NVAR vB=root:ARPES_LJZ:CTLUZ:ct_rgb3_b
            loc_r=vR; loc_g=vG; loc_b=vB
            break
        default:
            NVAR vR=root:ARPES_LJZ:CTLUZ:ct_rgb4_r; NVAR vG=root:ARPES_LJZ:CTLUZ:ct_rgb4_g; NVAR vB=root:ARPES_LJZ:CTLUZ:ct_rgb4_b
            loc_r=vR; loc_g=vG; loc_b=vB
            break
    endswitch
End

Function ctluz_set_rgb8(loc_pt, loc_r, loc_g, loc_b)
    Variable loc_pt, loc_r, loc_g, loc_b

    // clamp to 0..255
    loc_r = ctluz_clamp(loc_r,0,255)
    loc_g = ctluz_clamp(loc_g,0,255)
    loc_b = ctluz_clamp(loc_b,0,255)

    switch (loc_pt)
        case 0:
            NVAR vR=root:ARPES_LJZ:CTLUZ:ct_rgb0_r; NVAR vG=root:ARPES_LJZ:CTLUZ:ct_rgb0_g; NVAR vB=root:ARPES_LJZ:CTLUZ:ct_rgb0_b
            vR=loc_r; vG=loc_g; vB=loc_b
            break
        case 1:
            NVAR vR=root:ARPES_LJZ:CTLUZ:ct_rgb1_r; NVAR vG=root:ARPES_LJZ:CTLUZ:ct_rgb1_g; NVAR vB=root:ARPES_LJZ:CTLUZ:ct_rgb1_b
            vR=loc_r; vG=loc_g; vB=loc_b
            break
        case 2:
            NVAR vR=root:ARPES_LJZ:CTLUZ:ct_rgb2_r; NVAR vG=root:ARPES_LJZ:CTLUZ:ct_rgb2_g; NVAR vB=root:ARPES_LJZ:CTLUZ:ct_rgb2_b
            vR=loc_r; vG=loc_g; vB=loc_b
            break
        case 3:
            NVAR vR=root:ARPES_LJZ:CTLUZ:ct_rgb3_r; NVAR vG=root:ARPES_LJZ:CTLUZ:ct_rgb3_g; NVAR vB=root:ARPES_LJZ:CTLUZ:ct_rgb3_b
            vR=loc_r; vG=loc_g; vB=loc_b
            break
        default:
            NVAR vR=root:ARPES_LJZ:CTLUZ:ct_rgb4_r; NVAR vG=root:ARPES_LJZ:CTLUZ:ct_rgb4_g; NVAR vB=root:ARPES_LJZ:CTLUZ:ct_rgb4_b
            vR=loc_r; vG=loc_g; vB=loc_b
            break
    endswitch
End

// ============================
// NEW: swap RGB between ptX and ptY (0..4), then rebuild
// ============================
Function ctluz_swap_pts_rgb()
    NVAR ct_swap_x = root:ARPES_LJZ:CTLUZ:ct_swap_x
    NVAR ct_swap_y = root:ARPES_LJZ:CTLUZ:ct_swap_y

    Variable loc_x = round(ct_swap_x)
    Variable loc_y = round(ct_swap_y)

    loc_x = ctluz_clamp(loc_x,0,4)
    loc_y = ctluz_clamp(loc_y,0,4)

    ct_swap_x = loc_x
    ct_swap_y = loc_y

    if (loc_x == loc_y)
        return 0
    endif

    Variable rx,gx,bx, ry,gy,by
    ctluz_get_rgb8(loc_x, rx,gx,bx)
    ctluz_get_rgb8(loc_y, ry,gy,by)

    ctluz_set_rgb8(loc_x, ry,gy,by)
    ctluz_set_rgb8(loc_y, rx,gx,bx)

    // 绑定控件会自动刷新显示；这里重建色表
    ctluz_rebuild()
    return 0
End

Function CTLUZ_btn_swappts(ctrlName) : ButtonControl
    String ctrlName
    ctluz_swap_pts_rgb()
    return 0
End

// ============================
// NEW: build popup menu list from CTLIB
// ============================
Function ctluz_refresh_ctlib_menu()
    ctluz_ensure_folder()
    String loc_df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:CTLUZ:CTLIB

    // 只列 2D waves（ctable是 65536x4）
    String loc_list = WaveList("*", ";", "DIMS:2")
    if (strlen(loc_list) == 0)
        loc_list = "None;"
    endif

    SetDataFolder root:ARPES_LJZ:CTLUZ
    SVAR ctlib_menu_list = root:ARPES_LJZ:CTLUZ:ctlib_menu_list
    ctlib_menu_list = loc_list

    SetDataFolder loc_df0
    return 0
End

// ============================
// NEW: save current ct_table into CTLIB with user name
// ============================
Function ctluz_save_current_ct()
    ctluz_ensure_folder()
    SVAR ct_save_name = root:ARPES_LJZ:CTLUZ:ct_save_name
    String loc_name = CleanupName(ct_save_name, 0)

    if (strlen(loc_name) == 0)
        Abort "Save name is empty."
    endif

    Wave/W/U loc_src = root:ARPES_LJZ:CTLUZ:ct_table

    // 目标波：root:ARPES_LJZ:CTLUZ:CTLIB:<name>
    Duplicate/O loc_src $("root:ARPES_LJZ:CTLUZ:CTLIB:"+loc_name)

    // 刷新菜单，并把当前 pick 指向这个名字
    ctluz_refresh_ctlib_menu()
    SVAR ct_pick_name = root:ARPES_LJZ:CTLUZ:ct_pick_name
    ct_pick_name = loc_name
    return 0
End

// ============================
// NEW: popup proc (choose saved CT)
// ============================
Function CTLUZ_pm_ctlib_proc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName
    Variable popNum
    String popStr

    SVAR ct_pick_name = root:ARPES_LJZ:CTLUZ:ct_pick_name
    if (StringMatch(popStr, "None"))
        ct_pick_name = ""
    else
        ct_pick_name = popStr
    endif
    return 0
End

// ============================
// NEW: apply selected saved CT (still using current ct_lut)
// ============================
Function ctluz_apply_picked_ct()
    SVAR ct_pick_name = root:ARPES_LJZ:CTLUZ:ct_pick_name
    if (strlen(ct_pick_name) == 0)
        Abort "No saved CT selected."
    endif

    Wave/Z/W/U loc_ct = $("root:ARPES_LJZ:CTLUZ:CTLIB:"+ct_pick_name)
    if (!WaveExists(loc_ct))
        Abort "Selected CT wave not found in CTLIB."
    endif

    String loc_g = WinName(0,1)
    if (strlen(loc_g) == 0)
        Abort "No graph window found."
    endif

    String loc_imgs = ImageNameList(loc_g, ";")
    Variable loc_nimg = ItemsInList(loc_imgs, ";")
    if (loc_nimg <= 0)
        Abort "Top graph has no images."
    endif

    Variable loc_i
    for (loc_i=0; loc_i<loc_nimg; loc_i+=1)
        String loc_im = StringFromList(loc_i, loc_imgs, ";")
        ModifyImage/W=$loc_g $loc_im ctab={*,*,loc_ct,0}, lookup=root:ARPES_LJZ:CTLUZ:ct_lut
    endfor
    
        // NEW: after applying, load parameters back into panel
    ctluz_load_params_from_ct_wave(loc_ct)

    return 0
End

// ============================
// NEW: load 5-point RGB parameters from a saved CT wave (65536x4 U16)
// Assumes CT was generated by our piecewise-linear 4 segments scheme.
// It samples base-space s = 0,0.25,0.5,0.75,1.
// ============================
Function ctluz_load_params_from_ct_wave(loc_ct)
    Wave/W/U loc_ct

    Variable loc_n = DimSize(loc_ct,0)
    if (loc_n <= 1)
        Abort "CT wave has invalid size."
    endif

    // indices corresponding to s = 0,0.25,0.5,0.75,1
    Variable loc_i0 = 0
    Variable loc_i1 = round(0.25*(loc_n-1))
    Variable loc_i2 = round(0.50*(loc_n-1))
    Variable loc_i3 = round(0.75*(loc_n-1))
    Variable loc_i4 = loc_n-1

    // read U16 -> convert back to 0..255 by /257 (and clamp)
    Variable loc_r, loc_g, loc_b

    // pt0
    loc_r = round(loc_ct[loc_i0][0]/257); loc_g = round(loc_ct[loc_i0][1]/257); loc_b = round(loc_ct[loc_i0][2]/257)
    NVAR vR0=root:ARPES_LJZ:CTLUZ:ct_rgb0_r; NVAR vG0=root:ARPES_LJZ:CTLUZ:ct_rgb0_g; NVAR vB0=root:ARPES_LJZ:CTLUZ:ct_rgb0_b
    vR0=ctluz_clamp(loc_r,0,255); vG0=ctluz_clamp(loc_g,0,255); vB0=ctluz_clamp(loc_b,0,255)

    // pt1
    loc_r = round(loc_ct[loc_i1][0]/257); loc_g = round(loc_ct[loc_i1][1]/257); loc_b = round(loc_ct[loc_i1][2]/257)
    NVAR vR1=root:ARPES_LJZ:CTLUZ:ct_rgb1_r; NVAR vG1=root:ARPES_LJZ:CTLUZ:ct_rgb1_g; NVAR vB1=root:ARPES_LJZ:CTLUZ:ct_rgb1_b
    vR1=ctluz_clamp(loc_r,0,255); vG1=ctluz_clamp(loc_g,0,255); vB1=ctluz_clamp(loc_b,0,255)

    // pt2
    loc_r = round(loc_ct[loc_i2][0]/257); loc_g = round(loc_ct[loc_i2][1]/257); loc_b = round(loc_ct[loc_i2][2]/257)
    NVAR vR2=root:ARPES_LJZ:CTLUZ:ct_rgb2_r; NVAR vG2=root:ARPES_LJZ:CTLUZ:ct_rgb2_g; NVAR vB2=root:ARPES_LJZ:CTLUZ:ct_rgb2_b
    vR2=ctluz_clamp(loc_r,0,255); vG2=ctluz_clamp(loc_g,0,255); vB2=ctluz_clamp(loc_b,0,255)

    // pt3
    loc_r = round(loc_ct[loc_i3][0]/257); loc_g = round(loc_ct[loc_i3][1]/257); loc_b = round(loc_ct[loc_i3][2]/257)
    NVAR vR3=root:ARPES_LJZ:CTLUZ:ct_rgb3_r; NVAR vG3=root:ARPES_LJZ:CTLUZ:ct_rgb3_g; NVAR vB3=root:ARPES_LJZ:CTLUZ:ct_rgb3_b
    vR3=ctluz_clamp(loc_r,0,255); vG3=ctluz_clamp(loc_g,0,255); vB3=ctluz_clamp(loc_b,0,255)

    // pt4
    loc_r = round(loc_ct[loc_i4][0]/257); loc_g = round(loc_ct[loc_i4][1]/257); loc_b = round(loc_ct[loc_i4][2]/257)
    NVAR vR4=root:ARPES_LJZ:CTLUZ:ct_rgb4_r; NVAR vG4=root:ARPES_LJZ:CTLUZ:ct_rgb4_g; NVAR vB4=root:ARPES_LJZ:CTLUZ:ct_rgb4_b
    vR4=ctluz_clamp(loc_r,0,255); vG4=ctluz_clamp(loc_g,0,255); vB4=ctluz_clamp(loc_b,0,255)

    return 0
End

Function CTLUZ_btn_save(ctrlName) : ButtonControl
    String ctrlName
    ctluz_rebuild()          // 先按当前输入重建
    ctluz_save_current_ct()
    return 0
End

Function CTLUZ_btn_apply_saved(ctrlName) : ButtonControl
    String ctrlName
    ctluz_apply_picked_ct()
    return 0
End

// ----------------------------
// apply to top graph, all images
// ----------------------------
Function ctluz_apply_to_top_graph()
    String loc_g = WinName(0,1)
    if (strlen(loc_g) == 0)
        Abort "No graph window found."
    endif

    String loc_imgs = ImageNameList(loc_g, ";")
    Variable loc_nimg = ItemsInList(loc_imgs, ";")
    if (loc_nimg <= 0)
        Abort "Top graph has no images."
    endif

    Variable loc_i
    for (loc_i=0; loc_i<loc_nimg; loc_i+=1)
        String loc_im = StringFromList(loc_i, loc_imgs, ";")
        ModifyImage/W=$loc_g $loc_im ctab={*,*,root:ARPES_LJZ:CTLUZ:ct_table,0}, lookup=root:ARPES_LJZ:CTLUZ:ct_lut
    endfor
    return 0
End

// ----------------------------
// buttons
// ----------------------------
Function CTLUZ_btn_rebuild(ctrlName) : ButtonControl
    String ctrlName
    ctluz_rebuild()
    return 0
End

Function CTLUZ_btn_apply(ctrlName) : ButtonControl
    String ctrlName
    ctluz_rebuild()
    ctluz_apply_to_top_graph()
    return 0
End

Function CTLUZ_btn_close(ctrlName) : ButtonControl
    String ctrlName
    DoWindow/K CTLUZ_LJZ_P
    return 0
End

Function CTLUZ_btn_refreshlib(ctrlName) : ButtonControl
    String ctrlName
    ctluz_refresh_ctlib_menu()
    return 0
End

// ----------------------------
// panel
// ----------------------------
Window CTLUZ_LJZ_P() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(887.4,343.2,1360.2,760.8) as "CTLUZ_LJZ (CT + LUT + Apply)"
	ModifyPanel frameStyle=1
	ShowTools/A
	TitleBox ctt0,pos={13.80,12.60},size={268.20,11.40},title="5-point ColorTable (RGB 0..255) + Positions (0..1)  |  Apply to top graph"
	TitleBox ctt0,font="Times New Roman",fSize=10,frame=0
	TitleBox cth0,pos={12.00,30.00},size={11.40,18.00},title="Pt",frame=0
	TitleBox cth1,pos={51.00,30.00},size={7.20,18.00},title="p",frame=0
	TitleBox cth2,pos={168.00,30.00},size={7.80,18.00},title="R",frame=0
	TitleBox cth3,pos={270.00,30.00},size={8.40,18.00},title="G",frame=0
	TitleBox cth4,pos={369.00,30.00},size={7.20,18.00},title="B",frame=0
	TitleBox ctpt0,pos={12.00,51.00},size={6.60,18.00},title="0",frame=0
	SetVariable ctsv_p0,pos={51.00,51.00},size={108.00,19.80}
	SetVariable ctsv_p0,limits={0,1,0.001},value= root:ARPES_LJZ:CTLUZ:ct_p0
	SetVariable ctsv_r0,pos={168.00,51.00},size={90.00,19.80}
	SetVariable ctsv_r0,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb0_r
	SetVariable ctsv_g0,pos={270.00,51.00},size={90.00,19.80}
	SetVariable ctsv_g0,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb0_g
	SetVariable ctsv_b0,pos={369.00,51.00},size={90.00,19.80}
	SetVariable ctsv_b0,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb0_b
	TitleBox ctpt1,pos={12.00,78.00},size={6.60,18.00},title="1",frame=0
	SetVariable ctsv_p1,pos={51.00,78.00},size={108.00,19.80}
	SetVariable ctsv_p1,limits={0,1,0.001},value= root:ARPES_LJZ:CTLUZ:ct_p1
	SetVariable ctsv_r1,pos={168.00,78.00},size={90.00,19.80}
	SetVariable ctsv_r1,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb1_r
	SetVariable ctsv_g1,pos={270.00,78.00},size={90.00,19.80}
	SetVariable ctsv_g1,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb1_g
	SetVariable ctsv_b1,pos={369.00,78.00},size={90.00,19.80}
	SetVariable ctsv_b1,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb1_b
	TitleBox ctpt2,pos={12.00,102.00},size={6.60,18.00},title="2",frame=0
	SetVariable ctsv_p2,pos={51.00,102.00},size={108.00,19.80}
	SetVariable ctsv_p2,limits={0,1,0.001},value= root:ARPES_LJZ:CTLUZ:ct_p2
	SetVariable ctsv_r2,pos={168.00,102.00},size={90.00,19.80}
	SetVariable ctsv_r2,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb2_r
	SetVariable ctsv_g2,pos={270.00,102.00},size={90.00,19.80}
	SetVariable ctsv_g2,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb2_g
	SetVariable ctsv_b2,pos={369.00,102.00},size={90.00,19.80}
	SetVariable ctsv_b2,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb2_b
	TitleBox ctpt3,pos={12.00,129.00},size={6.60,18.00},title="3",frame=0
	SetVariable ctsv_p3,pos={51.00,129.00},size={108.00,19.80}
	SetVariable ctsv_p3,limits={0,1,0.001},value= root:ARPES_LJZ:CTLUZ:ct_p3
	SetVariable ctsv_r3,pos={168.00,129.00},size={90.00,19.80}
	SetVariable ctsv_r3,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb3_r
	SetVariable ctsv_g3,pos={270.00,129.00},size={90.00,19.80}
	SetVariable ctsv_g3,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb3_g
	SetVariable ctsv_b3,pos={369.00,129.00},size={90.00,19.80}
	SetVariable ctsv_b3,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb3_b
	TitleBox ctpt4,pos={12.00,156.00},size={6.60,18.00},title="4",frame=0
	SetVariable ctsv_p4,pos={51.00,156.00},size={108.00,19.80}
	SetVariable ctsv_p4,limits={0,1,0.001},value= root:ARPES_LJZ:CTLUZ:ct_p4
	SetVariable ctsv_r4,pos={168.00,156.00},size={90.00,19.80}
	SetVariable ctsv_r4,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb4_r
	SetVariable ctsv_g4,pos={270.00,156.00},size={90.00,19.80}
	SetVariable ctsv_g4,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb4_g
	SetVariable ctsv_b4,pos={369.00,156.00},size={90.00,19.80}
	SetVariable ctsv_b4,limits={0,255,1},value= root:ARPES_LJZ:CTLUZ:ct_rgb4_b
	TitleBox ctnote,pos={12.00,189.00},size={409.20,18.00},title="Note: p0 forced to 0 and p4 forced to 1; p1<p2<p3 enforced with epsilon."
	TitleBox ctnote,frame=0
	Button ctbtn_rebuild,pos={12.00,219.00},size={120.00,24.00},proc=CTLUZ_btn_rebuild,title="Rebuild"
	Button ctbtn_apply,pos={150.00,219.00},size={168.00,24.00},proc=CTLUZ_btn_apply,title="Apply (Top Graph)"
	Button ctbtn_close,pos={339.00,219.00},size={90.00,24.00},proc=CTLUZ_btn_close,title="Close"
	TitleBox ctlib_t0,pos={12.00,249.00},size={181.80,18.00},title="Save current CT to CTLIB (name):"
	TitleBox ctlib_t0,frame=0
	SetVariable ctsv_savename,pos={219.00,246.00},size={180.00,19.80}
	SetVariable ctsv_savename,value= root:ARPES_LJZ:CTLUZ:ct_save_name
	Button ctbtn_save,pos={189.00,276.00},size={144.00,39.00},proc=CTLUZ_btn_save,title="Save"
	Button ctbtn_refreshlib,pos={354.00,273.00},size={102.00,42.00},proc=CTLUZ_btn_refreshlib,title="Refresh CT list"
	TitleBox ctlib_t1,pos={12.00,279.00},size={88.20,18.00},title="Apply saved CT:"
	TitleBox ctlib_t1,frame=0
	PopupMenu ctpm_saved,pos={120.00,276.00},size={58.20,20.40},proc=CTLUZ_pm_ctlib_proc
	PopupMenu ctpm_saved,mode=12,popvalue="Mualani",value= #"root:ARPES_LJZ:CTLUZ:ctlib_menu_list"
	Button ctbtn_apply_saved,pos={339.00,321.00},size={117.00,48.00},proc=CTLUZ_btn_apply_saved,title="Apply Saved (Top)"
	TitleBox ctout0,pos={12.00,303.00},size={48.00,18.00},title="Outputs:",frame=0
	TitleBox ctout1,pos={12.00,327.00},size={292.20,18.00},title="root:ARPES_LJZ:CTLUZ:ct_table  (65536x4 U16 RGBA)"
	TitleBox ctout1,frame=0
	TitleBox ctout2,pos={12.00,351.00},size={264.60,18.00},title="root:ARPES_LJZ:CTLUZ:ct_lut    (65536 float 0..1)"
	TitleBox ctout2,frame=0
	TitleBox ctswap_t0,pos={12.00,381.00},size={148.20,18.00},title="Swap RGB between points:"
	TitleBox ctswap_t0,frame=0
	SetVariable ctsv_swapx,pos={171.00,379.80},size={69.00,19.80},title="x"
	SetVariable ctsv_swapx,limits={0,4,1},value= root:ARPES_LJZ:CTLUZ:ct_swap_x
	SetVariable ctsv_swapy,pos={244.80,379.80},size={69.00,19.80},title="y"
	SetVariable ctsv_swapy,limits={0,4,1},value= root:ARPES_LJZ:CTLUZ:ct_swap_y
	Button ctbtn_swappts,pos={318.60,381.00},size={138.00,21.00},proc=CTLUZ_btn_swappts,title="Swap RGB (x<->y)"
EndMacro

// ============================
// build a 5-point linear CT into a given 65536x4 U16 wave
// inputs are 8-bit RGB (0..255)
// ============================
Function ctluz_make_ct_from_5rgb(dest, c0r,c0g,c0b, c1r,c1g,c1b, c2r,c2g,c2b, c3r,c3g,c3b, c4r,c4g,c4b)
    Wave/W/U dest
    Variable c0r,c0g,c0b, c1r,c1g,c1b, c2r,c2g,c2b, c3r,c3g,c3b, c4r,c4g,c4b

    Variable nn = DimSize(dest,0)
    if (nn <= 1)
        Abort "dest CT wave has invalid size."
    endif

    Variable ii, seg, uu, ss
    Variable a0r16, a0g16, a0b16, a1r16, a1g16, a1b16

    // clamp 0..255
    c0r=ctluz_clamp(c0r,0,255); c0g=ctluz_clamp(c0g,0,255); c0b=ctluz_clamp(c0b,0,255)
    c1r=ctluz_clamp(c1r,0,255); c1g=ctluz_clamp(c1g,0,255); c1b=ctluz_clamp(c1b,0,255)
    c2r=ctluz_clamp(c2r,0,255); c2g=ctluz_clamp(c2g,0,255); c2b=ctluz_clamp(c2b,0,255)
    c3r=ctluz_clamp(c3r,0,255); c3g=ctluz_clamp(c3g,0,255); c3b=ctluz_clamp(c3b,0,255)
    c4r=ctluz_clamp(c4r,0,255); c4g=ctluz_clamp(c4g,0,255); c4b=ctluz_clamp(c4b,0,255)

    for (ii=0; ii<nn; ii+=1)
        ss = ii/(nn-1.0)
        seg = floor(4*ss)
        if (seg < 0)
            seg = 0
        endif
        if (seg > 3)
            seg = 3
        endif
        uu = 4*ss - seg

        if (seg == 0)
            a0r16=c0r*257; a0g16=c0g*257; a0b16=c0b*257
            a1r16=c1r*257; a1g16=c1g*257; a1b16=c1b*257
        elseif (seg == 1)
            a0r16=c1r*257; a0g16=c1g*257; a0b16=c1b*257
            a1r16=c2r*257; a1g16=c2g*257; a1b16=c2b*257
        elseif (seg == 2)
            a0r16=c2r*257; a0g16=c2g*257; a0b16=c2b*257
            a1r16=c3r*257; a1g16=c3g*257; a1b16=c3b*257
        else
            a0r16=c3r*257; a0g16=c3g*257; a0b16=c3b*257
            a1r16=c4r*257; a1g16=c4g*257; a1b16=c4b*257
        endif

        dest[ii][0] = round((1-uu)*a0r16 + uu*a1r16)
        dest[ii][1] = round((1-uu)*a0g16 + uu*a1g16)
        dest[ii][2] = round((1-uu)*a0b16 + uu*a1b16)
        dest[ii][3] = 65535
    endfor

    return 0
End


// ============================
// install built-in palettes into CTLIB (only if missing)
// saved as English names under root:ARPES_LJZ:CTLUZ:CTLIB
// ============================
Function ctluz_install_builtin_ctlib()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:CTLUZ:CTLIB

    // Nilou
    if (!WaveExists($("Nilou")))
        Make/O/W/U/N=(65536,4) Nilou
        ctluz_make_ct_from_5rgb(Nilou, 20,54,95, 118,162,185, 191,217,229, 248,242,236, 214,79,56)
    endif

    // KujouSara
    if (!WaveExists($("KujouSara")))
        Make/O/W/U/N=(65536,4) KujouSara
        ctluz_make_ct_from_5rgb(KujouSara, 71,73,97, 176,69,71, 243,242,239, 204,169,76, 106,64,140)
    endif

    // Xiangling
    if (!WaveExists($("Xiangling")))
        Make/O/W/U/N=(65536,4) Xiangling
        ctluz_make_ct_from_5rgb(Xiangling, 0,0,0, 56,72,113, 231,189,57, 171,79,63, 71,133,90)
    endif

    // Zhongli
    if (!WaveExists($("Zhongli")))
        Make/O/W/U/N=(65536,4) Zhongli
        ctluz_make_ct_from_5rgb(Zhongli, 47,35,33, 170,79,35, 248,235,220, 254,216,117, 108,98,122)
    endif

    // Kirara
    if (!WaveExists($("Kirara")))
        Make/O/W/U/N=(65536,4) Kirara
        ctluz_make_ct_from_5rgb(Kirara, 53,93,115, 141,192,200, 213,199,172, 234,199,114, 105,169,78)
    endif

    // Keqing
    if (!WaveExists($("Keqing")))
        Make/O/W/U/N=(65536,4) Keqing
        ctluz_make_ct_from_5rgb(Keqing, 97,30,30, 205,68,50, 239,145,99, 236,194,155, 243,217,190)
    endif

    // NavyBurgundy (your extra cropped palette)
    if (!WaveExists($("NavyBurgundy")))
        Make/O/W/U/N=(65536,4) NavyBurgundy
        ctluz_make_ct_from_5rgb(NavyBurgundy, 51,57,91, 93,116,162, 196,216,242, 242,232,227, 142,45,48)
    endif
    // -----------------------------
    // NEW: White/Light-background vivid palettes (5 colors each)
    // -----------------------------

    // Chasca  #6b0923 #0c6980 #29347e #feefe0 #231717
    if (!WaveExists($("Chasca")))
        Make/O/W/U/N=(65536,4) Chasca
        ctluz_make_ct_from_5rgb(Chasca, 107,9,35,  12,105,128,  41,52,126,  254,239,224,  35,23,23)
    endif

    // Xilonen  #f07621 #f2ead6 #f07621 #b5f2d3 #311214
    if (!WaveExists($("Xilonen")))
        Make/O/W/U/N=(65536,4) Xilonen
        ctluz_make_ct_from_5rgb(Xilonen, 240,118,33,  242,234,214,  240,118,33,  181,242,211,  49,18,20)
    endif

    // Mualani  #f6f7f9 #3556c1 #f2c52c #f1eddd #5ab9c1
    if (!WaveExists($("Mualani")))
        Make/O/W/U/N=(65536,4) Mualani
        ctluz_make_ct_from_5rgb(Mualani, 246,247,249,  53,86,193,  242,197,44,  241,237,221,  90,185,193)
    endif

    // Mavuika  #e83317 #cb5c62 #e95320 #212121 #fcedde
    if (!WaveExists($("Mavuika")))
        Make/O/W/U/N=(65536,4) Mavuika
        ctluz_make_ct_from_5rgb(Mavuika, 232,51,23,  203,92,98,  233,83,32,  33,33,33,  252,237,222)
    endif

    // Kinich  #f3eddb #261f1b #2f6975 #6bfaa4 #f3e453
    if (!WaveExists($("Kinich")))
        Make/O/W/U/N=(65536,4) Kinich
        ctluz_make_ct_from_5rgb(Kinich, 243,237,219,  38,31,27,  47,105,117,  107,250,164,  243,228,83)
    endif

    // Citlali  #fef2ec #e4acd2 #4d4c94 #30233d #f76fa1
    if (!WaveExists($("Citlali")))
        Make/O/W/U/N=(65536,4) Citlali
        ctluz_make_ct_from_5rgb(Citlali, 254,242,236,  228,172,210,  77,76,148,  48,35,61,  247,111,161)
    endif

    // Varesa  #f9e9e0 #fcc7c9 #59d8c8 #fbeec2 #ab81c9
    if (!WaveExists($("Varesa")))
        Make/O/W/U/N=(65536,4) Varesa
        ctluz_make_ct_from_5rgb(Varesa, 249,233,224,  252,199,201,  89,216,200,  251,238,194,  171,129,201)
    endif
// 1. NeonClash (霓虹对撞): 经典的物理学冷暖对比，高饱和度。
    // 渐变: 猩红 (Deep Red) -> 浆果紫 -> 靛蓝 -> 电光蓝 (Electric Blue)
    // 视觉感: 从极其火热到极其冰冷，中间过渡非常顺滑，充满能量感。
    if (!WaveExists($("NeonClash")))
        Make/O/W/U/N=(65536,4) NeonClash
        ctluz_make_ct_from_5rgb(NeonClash, 220,10,40,   180,0,90,    120,20,160,   60,50,220,   0,140,255)
    endif

    // 2. CyberPunk (赛博朋克): 极具未来感的配色，深邃且刺眼。
    // 渐变: 激光洋红 (Magenta) -> 深紫 -> 宝蓝 -> 霓虹青 (Cyan)
    // 视觉感: 像霓虹灯牌一样的配色，在深色背景下非常“跳”，对比度极高。
    if (!WaveExists($("CyberPunk")))
        Make/O/W/U/N=(65536,4) CyberPunk
        ctluz_make_ct_from_5rgb(CyberPunk, 255,0,130,   180,20,190,   90,40,220,    0,100,240,   0,230,230)
    endif

    // 3. ToxicHeat (毒性热辐射): 危险且迷人的警示色渐变。
    // 渐变: 放射绿 (Radioactive Green) -> 柠檬黄 -> 焦糖橙 -> 熔岩红 (Lava Red)
    // 视觉感: 从诡异的深绿色过渡到炽热的深红色，非常适合展示能级或强度的变化。
    if (!WaveExists($("ToxicHeat")))
        Make/O/W/U/N=(65536,4) ToxicHeat
        ctluz_make_ct_from_5rgb(ToxicHeat, 0,180,60,    100,170,0,    190,140,0,    230,70,0,    255,0,20)
    endif
    
    SetDataFolder df0
    return 0
End