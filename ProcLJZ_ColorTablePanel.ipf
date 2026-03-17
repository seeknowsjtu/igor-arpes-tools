#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
//============================================================
// CTLUZ_LJZ: 5-point ColorTable + Lookup wave + Apply to Top Graph
// SAFE workflow version:
//   1) editor workspace lives in root:ARPES_LJZ:CTLUZ
//   2) applying to a graph writes per-image CT/LUT snapshots into
//      root:ARPES_LJZ:CTLUZ:APPLIED
//   3) reopening the panel will NOT reset current state
//
// State in: root:ARPES_LJZ:CTLUZ
//============================================================


// ============================================================
// Folder / init helpers
// ============================================================

Function ctluz_ensure_folder()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:CTLUZ
    NewDataFolder/O root:ARPES_LJZ:CTLUZ:CTLIB
    NewDataFolder/O root:ARPES_LJZ:CTLUZ:APPLIED

    ctluz_install_builtin_ctlib()
End

Function ctluz_init_defaults_if_needed()
    ctluz_ensure_folder()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:CTLUZ

    // ---- positions (0..1) ----
    NVAR/Z ct_p0 = root:ARPES_LJZ:CTLUZ:ct_p0
    if (!NVAR_Exists(ct_p0))
        Variable/G ct_p0 = 0
    endif

    NVAR/Z ct_p1 = root:ARPES_LJZ:CTLUZ:ct_p1
    if (!NVAR_Exists(ct_p1))
        Variable/G ct_p1 = 0.25
    endif

    NVAR/Z ct_p2 = root:ARPES_LJZ:CTLUZ:ct_p2
    if (!NVAR_Exists(ct_p2))
        Variable/G ct_p2 = 0.50
    endif

    NVAR/Z ct_p3 = root:ARPES_LJZ:CTLUZ:ct_p3
    if (!NVAR_Exists(ct_p3))
        Variable/G ct_p3 = 0.75
    endif

    NVAR/Z ct_p4 = root:ARPES_LJZ:CTLUZ:ct_p4
    if (!NVAR_Exists(ct_p4))
        Variable/G ct_p4 = 1
    endif

    // ---- colors (RGB 0..255) ----
    NVAR/Z ct_rgb0_r = root:ARPES_LJZ:CTLUZ:ct_rgb0_r
    if (!NVAR_Exists(ct_rgb0_r))
        Variable/G ct_rgb0_r = 0
        Variable/G ct_rgb0_g = 0
        Variable/G ct_rgb0_b = 0

        Variable/G ct_rgb1_r = 0
        Variable/G ct_rgb1_g = 0
        Variable/G ct_rgb1_b = 255

        Variable/G ct_rgb2_r = 0
        Variable/G ct_rgb2_g = 255
        Variable/G ct_rgb2_b = 255

        Variable/G ct_rgb3_r = 255
        Variable/G ct_rgb3_g = 255
        Variable/G ct_rgb3_b = 0

        Variable/G ct_rgb4_r = 255
        Variable/G ct_rgb4_g = 255
        Variable/G ct_rgb4_b = 255
    endif

    // ---- swap points ----
    NVAR/Z ct_swap_x = root:ARPES_LJZ:CTLUZ:ct_swap_x
    if (!NVAR_Exists(ct_swap_x))
        Variable/G ct_swap_x = 0
    endif

    NVAR/Z ct_swap_y = root:ARPES_LJZ:CTLUZ:ct_swap_y
    if (!NVAR_Exists(ct_swap_y))
        Variable/G ct_swap_y = 1
    endif

    // ---- output waves ----
    Wave/Z/W/U ct_table = root:ARPES_LJZ:CTLUZ:ct_table
    if (!WaveExists(ct_table))
        Make/O/W/U/N=(65536,4) ct_table
    endif

    Wave/Z ct_lut = root:ARPES_LJZ:CTLUZ:ct_lut
    if (!WaveExists(ct_lut))
        Make/O/N=65536 ct_lut
    endif

    // ---- library UI state ----
    SVAR/Z ct_save_name = root:ARPES_LJZ:CTLUZ:ct_save_name
    if (!SVAR_Exists(ct_save_name))
        String/G ct_save_name = ""
    endif

    SVAR/Z ct_pick_name = root:ARPES_LJZ:CTLUZ:ct_pick_name
    if (!SVAR_Exists(ct_pick_name))
        String/G ct_pick_name = "Mualani"
    endif

    SVAR/Z ctlib_menu_list = root:ARPES_LJZ:CTLUZ:ctlib_menu_list
    if (!SVAR_Exists(ctlib_menu_list))
        String/G ctlib_menu_list = "None;"
    endif

    SetDataFolder df0
End


// ============================================================
// Entry
// ============================================================

Proc CTLUZ_LJZ()
    ctluz_init_defaults_if_needed()
    ctluz_refresh_ctlib_menu()
    ctluz_rebuild()

    SetDataFolder root:
    DoWindow/F CTLUZ_LJZ_P
    if (V_flag == 0)
        CTLUZ_LJZ_P()
    endif

    ctluz_sync_panel_state()
End


// ============================================================
// Small helpers
// ============================================================

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

Function/S ctluz_applied_df()
    ctluz_ensure_folder()
    return "root:ARPES_LJZ:CTLUZ:APPLIED:"
End

Function/S ctluz_make_apply_key(graphName, imageName)
    String graphName, imageName
    return CleanupName(graphName + "__" + imageName, 0)
End

Function ctluz_sync_panel_state()
    DoWindow CTLUZ_LJZ_P
    if (V_flag == 0)
        return 0
    endif

    SVAR ct_pick_name   = root:ARPES_LJZ:CTLUZ:ct_pick_name
    SVAR ctlib_menu_list = root:ARPES_LJZ:CTLUZ:ctlib_menu_list

    PopupMenu ctpm_saved,win=CTLUZ_LJZ_P,value=#"root:ARPES_LJZ:CTLUZ:ctlib_menu_list"

    if (WhichListItem(ct_pick_name, ctlib_menu_list, ";", 0, 0) < 0)
        if (WhichListItem("Mualani", ctlib_menu_list, ";", 0, 0) >= 0)
            ct_pick_name = "Mualani"
        else
            ct_pick_name = StringFromList(0, ctlib_menu_list, ";")
        endif
    endif

    if (strlen(ct_pick_name) > 0)
        PopupMenu ctpm_saved,win=CTLUZ_LJZ_P,popvalue=ct_pick_name
    endif

    ControlUpdate/W=CTLUZ_LJZ_P ctpm_saved
    return 0
End


// ============================================================
// Rebuild CT + LUT from current editor variables
// ============================================================

Function ctluz_rebuild()
    ctluz_init_defaults_if_needed()
    SetDataFolder root:ARPES_LJZ:CTLUZ

    // ---- read vars ----
    NVAR ct_p0 = root:ARPES_LJZ:CTLUZ:ct_p0
    NVAR ct_p1 = root:ARPES_LJZ:CTLUZ:ct_p1
    NVAR ct_p2 = root:ARPES_LJZ:CTLUZ:ct_p2
    NVAR ct_p3 = root:ARPES_LJZ:CTLUZ:ct_p3
    NVAR ct_p4 = root:ARPES_LJZ:CTLUZ:ct_p4

    NVAR ct_rgb0_r = root:ARPES_LJZ:CTLUZ:ct_rgb0_r
    NVAR ct_rgb0_g = root:ARPES_LJZ:CTLUZ:ct_rgb0_g
    NVAR ct_rgb0_b = root:ARPES_LJZ:CTLUZ:ct_rgb0_b

    NVAR ct_rgb1_r = root:ARPES_LJZ:CTLUZ:ct_rgb1_r
    NVAR ct_rgb1_g = root:ARPES_LJZ:CTLUZ:ct_rgb1_g
    NVAR ct_rgb1_b = root:ARPES_LJZ:CTLUZ:ct_rgb1_b

    NVAR ct_rgb2_r = root:ARPES_LJZ:CTLUZ:ct_rgb2_r
    NVAR ct_rgb2_g = root:ARPES_LJZ:CTLUZ:ct_rgb2_g
    NVAR ct_rgb2_b = root:ARPES_LJZ:CTLUZ:ct_rgb2_b

    NVAR ct_rgb3_r = root:ARPES_LJZ:CTLUZ:ct_rgb3_r
    NVAR ct_rgb3_g = root:ARPES_LJZ:CTLUZ:ct_rgb3_g
    NVAR ct_rgb3_b = root:ARPES_LJZ:CTLUZ:ct_rgb3_b

    NVAR ct_rgb4_r = root:ARPES_LJZ:CTLUZ:ct_rgb4_r
    NVAR ct_rgb4_g = root:ARPES_LJZ:CTLUZ:ct_rgb4_g
    NVAR ct_rgb4_b = root:ARPES_LJZ:CTLUZ:ct_rgb4_b

    Wave/W/U ct_table = root:ARPES_LJZ:CTLUZ:ct_table
    Wave     ct_lut   = root:ARPES_LJZ:CTLUZ:ct_lut

    // ---- sanitize rgb ----
    ct_rgb0_r = ctluz_clamp(ct_rgb0_r, 0, 255)
    ct_rgb0_g = ctluz_clamp(ct_rgb0_g, 0, 255)
    ct_rgb0_b = ctluz_clamp(ct_rgb0_b, 0, 255)

    ct_rgb1_r = ctluz_clamp(ct_rgb1_r, 0, 255)
    ct_rgb1_g = ctluz_clamp(ct_rgb1_g, 0, 255)
    ct_rgb1_b = ctluz_clamp(ct_rgb1_b, 0, 255)

    ct_rgb2_r = ctluz_clamp(ct_rgb2_r, 0, 255)
    ct_rgb2_g = ctluz_clamp(ct_rgb2_g, 0, 255)
    ct_rgb2_b = ctluz_clamp(ct_rgb2_b, 0, 255)

    ct_rgb3_r = ctluz_clamp(ct_rgb3_r, 0, 255)
    ct_rgb3_g = ctluz_clamp(ct_rgb3_g, 0, 255)
    ct_rgb3_b = ctluz_clamp(ct_rgb3_b, 0, 255)

    ct_rgb4_r = ctluz_clamp(ct_rgb4_r, 0, 255)
    ct_rgb4_g = ctluz_clamp(ct_rgb4_g, 0, 255)
    ct_rgb4_b = ctluz_clamp(ct_rgb4_b, 0, 255)

    // ---- sanitize positions ----
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

    // ---- build CT_Table in base space s in [0,1] ----
    Variable loc_n = DimSize(ct_table, 0)
    Variable loc_i, loc_seg
    Variable loc_s, loc_u
    Variable loc_r0, loc_g0, loc_b0, loc_r1, loc_g1, loc_b1

    for (loc_i = 0; loc_i < loc_n; loc_i += 1)
        loc_s = loc_i / (loc_n - 1.0)
        loc_seg = floor(4 * loc_s)
        if (loc_seg < 0)
            loc_seg = 0
        endif
        if (loc_seg > 3)
            loc_seg = 3
        endif
        loc_u = 4 * loc_s - loc_seg

        if (loc_seg == 0)
            loc_r0 = ct_rgb0_r * 257
            loc_g0 = ct_rgb0_g * 257
            loc_b0 = ct_rgb0_b * 257

            loc_r1 = ct_rgb1_r * 257
            loc_g1 = ct_rgb1_g * 257
            loc_b1 = ct_rgb1_b * 257

        elseif (loc_seg == 1)
            loc_r0 = ct_rgb1_r * 257
            loc_g0 = ct_rgb1_g * 257
            loc_b0 = ct_rgb1_b * 257

            loc_r1 = ct_rgb2_r * 257
            loc_g1 = ct_rgb2_g * 257
            loc_b1 = ct_rgb2_b * 257

        elseif (loc_seg == 2)
            loc_r0 = ct_rgb2_r * 257
            loc_g0 = ct_rgb2_g * 257
            loc_b0 = ct_rgb2_b * 257

            loc_r1 = ct_rgb3_r * 257
            loc_g1 = ct_rgb3_g * 257
            loc_b1 = ct_rgb3_b * 257

        else
            loc_r0 = ct_rgb3_r * 257
            loc_g0 = ct_rgb3_g * 257
            loc_b0 = ct_rgb3_b * 257

            loc_r1 = ct_rgb4_r * 257
            loc_g1 = ct_rgb4_g * 257
            loc_b1 = ct_rgb4_b * 257
        endif

        ct_table[loc_i][0] = round((1 - loc_u) * loc_r0 + loc_u * loc_r1)
        ct_table[loc_i][1] = round((1 - loc_u) * loc_g0 + loc_u * loc_g1)
        ct_table[loc_i][2] = round((1 - loc_u) * loc_b0 + loc_u * loc_b1)
        ct_table[loc_i][3] = 65535
    endfor

    // ---- build lookup: desired t -> base s ----
    Variable loc_t, loc_denom
    for (loc_i = 0; loc_i < loc_n; loc_i += 1)
        loc_t = loc_i / (loc_n - 1.0)

        if (loc_t <= ct_p1)
            loc_denom = (ct_p1 - ct_p0)
            loc_u = (loc_denom <= 0) ? 0 : (loc_t - ct_p0) / loc_denom
            ct_lut[loc_i] = 0 + 0.25 * loc_u

        elseif (loc_t <= ct_p2)
            loc_denom = (ct_p2 - ct_p1)
            loc_u = (loc_denom <= 0) ? 0 : (loc_t - ct_p1) / loc_denom
            ct_lut[loc_i] = 0.25 + 0.25 * loc_u

        elseif (loc_t <= ct_p3)
            loc_denom = (ct_p3 - ct_p2)
            loc_u = (loc_denom <= 0) ? 0 : (loc_t - ct_p2) / loc_denom
            ct_lut[loc_i] = 0.50 + 0.25 * loc_u

        else
            loc_denom = (ct_p4 - ct_p3)
            loc_u = (loc_denom <= 0) ? 0 : (loc_t - ct_p3) / loc_denom
            ct_lut[loc_i] = 0.75 + 0.25 * loc_u
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


// ============================================================
// Get / set RGB
// ============================================================

Function ctluz_get_rgb8(loc_pt, loc_r, loc_g, loc_b)
    Variable loc_pt
    Variable &loc_r, &loc_g, &loc_b

    switch (loc_pt)
        case 0:
            NVAR vR0 = root:ARPES_LJZ:CTLUZ:ct_rgb0_r
            NVAR vG0 = root:ARPES_LJZ:CTLUZ:ct_rgb0_g
            NVAR vB0 = root:ARPES_LJZ:CTLUZ:ct_rgb0_b
            loc_r = vR0; loc_g = vG0; loc_b = vB0
            break

        case 1:
            NVAR vR1 = root:ARPES_LJZ:CTLUZ:ct_rgb1_r
            NVAR vG1 = root:ARPES_LJZ:CTLUZ:ct_rgb1_g
            NVAR vB1 = root:ARPES_LJZ:CTLUZ:ct_rgb1_b
            loc_r = vR1; loc_g = vG1; loc_b = vB1
            break

        case 2:
            NVAR vR2 = root:ARPES_LJZ:CTLUZ:ct_rgb2_r
            NVAR vG2 = root:ARPES_LJZ:CTLUZ:ct_rgb2_g
            NVAR vB2 = root:ARPES_LJZ:CTLUZ:ct_rgb2_b
            loc_r = vR2; loc_g = vG2; loc_b = vB2
            break

        case 3:
            NVAR vR3 = root:ARPES_LJZ:CTLUZ:ct_rgb3_r
            NVAR vG3 = root:ARPES_LJZ:CTLUZ:ct_rgb3_g
            NVAR vB3 = root:ARPES_LJZ:CTLUZ:ct_rgb3_b
            loc_r = vR3; loc_g = vG3; loc_b = vB3
            break

        default:
            NVAR vR4 = root:ARPES_LJZ:CTLUZ:ct_rgb4_r
            NVAR vG4 = root:ARPES_LJZ:CTLUZ:ct_rgb4_g
            NVAR vB4 = root:ARPES_LJZ:CTLUZ:ct_rgb4_b
            loc_r = vR4; loc_g = vG4; loc_b = vB4
            break
    endswitch
End

Function ctluz_set_rgb8(loc_pt, loc_r, loc_g, loc_b)
    Variable loc_pt, loc_r, loc_g, loc_b

    loc_r = ctluz_clamp(loc_r, 0, 255)
    loc_g = ctluz_clamp(loc_g, 0, 255)
    loc_b = ctluz_clamp(loc_b, 0, 255)

    switch (loc_pt)
        case 0:
            NVAR vR0 = root:ARPES_LJZ:CTLUZ:ct_rgb0_r
            NVAR vG0 = root:ARPES_LJZ:CTLUZ:ct_rgb0_g
            NVAR vB0 = root:ARPES_LJZ:CTLUZ:ct_rgb0_b
            vR0 = loc_r; vG0 = loc_g; vB0 = loc_b
            break

        case 1:
            NVAR vR1 = root:ARPES_LJZ:CTLUZ:ct_rgb1_r
            NVAR vG1 = root:ARPES_LJZ:CTLUZ:ct_rgb1_g
            NVAR vB1 = root:ARPES_LJZ:CTLUZ:ct_rgb1_b
            vR1 = loc_r; vG1 = loc_g; vB1 = loc_b
            break

        case 2:
            NVAR vR2 = root:ARPES_LJZ:CTLUZ:ct_rgb2_r
            NVAR vG2 = root:ARPES_LJZ:CTLUZ:ct_rgb2_g
            NVAR vB2 = root:ARPES_LJZ:CTLUZ:ct_rgb2_b
            vR2 = loc_r; vG2 = loc_g; vB2 = loc_b
            break

        case 3:
            NVAR vR3 = root:ARPES_LJZ:CTLUZ:ct_rgb3_r
            NVAR vG3 = root:ARPES_LJZ:CTLUZ:ct_rgb3_g
            NVAR vB3 = root:ARPES_LJZ:CTLUZ:ct_rgb3_b
            vR3 = loc_r; vG3 = loc_g; vB3 = loc_b
            break

        default:
            NVAR vR4 = root:ARPES_LJZ:CTLUZ:ct_rgb4_r
            NVAR vG4 = root:ARPES_LJZ:CTLUZ:ct_rgb4_g
            NVAR vB4 = root:ARPES_LJZ:CTLUZ:ct_rgb4_b
            vR4 = loc_r; vG4 = loc_g; vB4 = loc_b
            break
    endswitch
End


// ============================================================
// Swap RGB between two control points
// ============================================================

Function ctluz_swap_pts_rgb()
    NVAR ct_swap_x = root:ARPES_LJZ:CTLUZ:ct_swap_x
    NVAR ct_swap_y = root:ARPES_LJZ:CTLUZ:ct_swap_y

    Variable loc_x = round(ct_swap_x)
    Variable loc_y = round(ct_swap_y)

    loc_x = ctluz_clamp(loc_x, 0, 4)
    loc_y = ctluz_clamp(loc_y, 0, 4)

    ct_swap_x = loc_x
    ct_swap_y = loc_y

    if (loc_x == loc_y)
        return 0
    endif

    Variable rx, gx, bx, ry, gy, by
    ctluz_get_rgb8(loc_x, rx, gx, bx)
    ctluz_get_rgb8(loc_y, ry, gy, by)

    ctluz_set_rgb8(loc_x, ry, gy, by)
    ctluz_set_rgb8(loc_y, rx, gx, bx)

    ctluz_rebuild()
    return 0
End

Function CTLUZ_btn_swappts(ctrlName) : ButtonControl
    String ctrlName
    ctluz_swap_pts_rgb()
    return 0
End


// ============================================================
// CTLIB menu
// ============================================================

Function ctluz_refresh_ctlib_menu()
    ctluz_ensure_folder()

    String loc_df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:CTLUZ:CTLIB

    String allList = WaveList("*", ";", "DIMS:2")

    String prefList = "Mualani;NavyBurgundy;Nilou;Mavuika;Citlali;Kinich;Varesa;Zhongli;Kirara;KujouSara;Chasca;Xilonen;Xiangling;Keqing;NeonClash;CyberPunk;ToxicHeat;"
    String finalList = ""
    Variable i, n
    String nm

    n = ItemsInList(prefList, ";")
    for (i = 0; i < n; i += 1)
        nm = StringFromList(i, prefList, ";")
        if (strlen(nm) == 0)
            continue
        endif

        if (WaveExists($nm))
            if (WhichListItem(nm, finalList, ";", 0, 0) < 0)
                finalList += nm + ";"
            endif
        endif
    endfor

    n = ItemsInList(allList, ";")
    for (i = 0; i < n; i += 1)
        nm = StringFromList(i, allList, ";")
        if (strlen(nm) == 0)
            continue
        endif

        if (WhichListItem(nm, finalList, ";", 0, 0) < 0)
            finalList += nm + ";"
        endif
    endfor

    if (strlen(finalList) == 0)
        finalList = "None;"
    endif

    SetDataFolder root:ARPES_LJZ:CTLUZ
    SVAR ctlib_menu_list = root:ARPES_LJZ:CTLUZ:ctlib_menu_list
    ctlib_menu_list = finalList

    SetDataFolder loc_df0

    ctluz_sync_panel_state()
    return 0
End


// ============================================================
// Save current editor CT into CTLIB
// NOTE: saves ct_table only; current ct_lut remains workspace state
// ============================================================

Function ctluz_save_current_ct()
    ctluz_init_defaults_if_needed()

    SVAR ct_save_name = root:ARPES_LJZ:CTLUZ:ct_save_name
    String loc_name = CleanupName(ct_save_name, 0)

    if (strlen(loc_name) == 0)
        Abort "Save name is empty."
    endif

    Wave/W/U loc_src = root:ARPES_LJZ:CTLUZ:ct_table
    Duplicate/O loc_src, $("root:ARPES_LJZ:CTLUZ:CTLIB:" + loc_name)

    ctluz_refresh_ctlib_menu()

    SVAR ct_pick_name = root:ARPES_LJZ:CTLUZ:ct_pick_name
    ct_pick_name = loc_name

    ctluz_sync_panel_state()
    return 0
End


// ============================================================
// Popup proc
// ============================================================

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


// ============================================================
// Load 5-point RGB parameters from a saved CT wave
// Assumes 4 equal linear segments in base space
// ============================================================

Function ctluz_load_params_from_ct_wave(loc_ct)
    Wave/W/U loc_ct

    Variable loc_n = DimSize(loc_ct, 0)
    if (loc_n <= 1)
        Abort "CT wave has invalid size."
    endif

    Variable loc_i0 = 0
    Variable loc_i1 = round(0.25 * (loc_n - 1))
    Variable loc_i2 = round(0.50 * (loc_n - 1))
    Variable loc_i3 = round(0.75 * (loc_n - 1))
    Variable loc_i4 = loc_n - 1

    Variable loc_r, loc_g, loc_b

    loc_r = round(loc_ct[loc_i0][0] / 257)
    loc_g = round(loc_ct[loc_i0][1] / 257)
    loc_b = round(loc_ct[loc_i0][2] / 257)
    NVAR vR0 = root:ARPES_LJZ:CTLUZ:ct_rgb0_r
    NVAR vG0 = root:ARPES_LJZ:CTLUZ:ct_rgb0_g
    NVAR vB0 = root:ARPES_LJZ:CTLUZ:ct_rgb0_b
    vR0 = ctluz_clamp(loc_r, 0, 255)
    vG0 = ctluz_clamp(loc_g, 0, 255)
    vB0 = ctluz_clamp(loc_b, 0, 255)

    loc_r = round(loc_ct[loc_i1][0] / 257)
    loc_g = round(loc_ct[loc_i1][1] / 257)
    loc_b = round(loc_ct[loc_i1][2] / 257)
    NVAR vR1 = root:ARPES_LJZ:CTLUZ:ct_rgb1_r
    NVAR vG1 = root:ARPES_LJZ:CTLUZ:ct_rgb1_g
    NVAR vB1 = root:ARPES_LJZ:CTLUZ:ct_rgb1_b
    vR1 = ctluz_clamp(loc_r, 0, 255)
    vG1 = ctluz_clamp(loc_g, 0, 255)
    vB1 = ctluz_clamp(loc_b, 0, 255)

    loc_r = round(loc_ct[loc_i2][0] / 257)
    loc_g = round(loc_ct[loc_i2][1] / 257)
    loc_b = round(loc_ct[loc_i2][2] / 257)
    NVAR vR2 = root:ARPES_LJZ:CTLUZ:ct_rgb2_r
    NVAR vG2 = root:ARPES_LJZ:CTLUZ:ct_rgb2_g
    NVAR vB2 = root:ARPES_LJZ:CTLUZ:ct_rgb2_b
    vR2 = ctluz_clamp(loc_r, 0, 255)
    vG2 = ctluz_clamp(loc_g, 0, 255)
    vB2 = ctluz_clamp(loc_b, 0, 255)

    loc_r = round(loc_ct[loc_i3][0] / 257)
    loc_g = round(loc_ct[loc_i3][1] / 257)
    loc_b = round(loc_ct[loc_i3][2] / 257)
    NVAR vR3 = root:ARPES_LJZ:CTLUZ:ct_rgb3_r
    NVAR vG3 = root:ARPES_LJZ:CTLUZ:ct_rgb3_g
    NVAR vB3 = root:ARPES_LJZ:CTLUZ:ct_rgb3_b
    vR3 = ctluz_clamp(loc_r, 0, 255)
    vG3 = ctluz_clamp(loc_g, 0, 255)
    vB3 = ctluz_clamp(loc_b, 0, 255)

    loc_r = round(loc_ct[loc_i4][0] / 257)
    loc_g = round(loc_ct[loc_i4][1] / 257)
    loc_b = round(loc_ct[loc_i4][2] / 257)
    NVAR vR4 = root:ARPES_LJZ:CTLUZ:ct_rgb4_r
    NVAR vG4 = root:ARPES_LJZ:CTLUZ:ct_rgb4_g
    NVAR vB4 = root:ARPES_LJZ:CTLUZ:ct_rgb4_b
    vR4 = ctluz_clamp(loc_r, 0, 255)
    vG4 = ctluz_clamp(loc_g, 0, 255)
    vB4 = ctluz_clamp(loc_b, 0, 255)

    return 0
End


// ============================================================
// Snapshot apply helpers
// Each graph/image gets its own frozen CT/LUT copy
// ============================================================

Function ctluz_apply_snapshot_to_image(graphName, imageName, srcCT, srcLUT, useLookup)
    String graphName, imageName
    Wave/W/U srcCT
    Wave srcLUT
    Variable useLookup

    String baseDF = ctluz_applied_df()
    String key = ctluz_make_apply_key(graphName, imageName)

    String ctPath  = baseDF + key + "_ct"
    String lutPath = baseDF + key + "_lut"

    Duplicate/O srcCT, $ctPath
    Wave/W/U ctLocal = $ctPath

    if (useLookup && WaveExists(srcLUT))
        Duplicate/O srcLUT, $lutPath
        Wave lutLocal = $lutPath
        ModifyImage/W=$graphName $imageName ctab={*,*,ctLocal,0}, lookup=lutLocal
    else
        ModifyImage/W=$graphName $imageName ctab={*,*,ctLocal,0}
    endif

    return 0
End


// ============================================================
// Apply selected saved CT to top graph (safe snapshot)
// Still uses current ct_lut workspace
// ============================================================

Function ctluz_apply_picked_ct()
    ctluz_init_defaults_if_needed()

    SVAR ct_pick_name = root:ARPES_LJZ:CTLUZ:ct_pick_name
    if (strlen(ct_pick_name) == 0)
        Abort "No saved CT selected."
    endif

    Wave/Z/W/U loc_ct = $("root:ARPES_LJZ:CTLUZ:CTLIB:" + ct_pick_name)
    if (!WaveExists(loc_ct))
        Abort "Selected CT wave not found in CTLIB."
    endif

    Wave/Z loc_lut = root:ARPES_LJZ:CTLUZ:ct_lut

    String loc_g = WinName(0, 1)
    if (strlen(loc_g) == 0)
        Abort "No graph window found."
    endif

    String loc_imgs = ImageNameList(loc_g, ";")
    Variable loc_nimg = ItemsInList(loc_imgs, ";")
    if (loc_nimg <= 0)
        Abort "Top graph has no images."
    endif

    Variable loc_i
    for (loc_i = 0; loc_i < loc_nimg; loc_i += 1)
        String loc_im = StringFromList(loc_i, loc_imgs, ";")
        ctluz_apply_snapshot_to_image(loc_g, loc_im, loc_ct, loc_lut, 1)
    endfor

    // also load palette anchors back into editor workspace
    ctluz_load_params_from_ct_wave(loc_ct)

    return 0
End


// ============================================================
// Apply current editor workspace CT to top graph (safe snapshot)
// ============================================================

Function ctluz_apply_to_top_graph()
    ctluz_init_defaults_if_needed()

    String loc_g = WinName(0, 1)
    if (strlen(loc_g) == 0)
        Abort "No graph window found."
    endif

    String loc_imgs = ImageNameList(loc_g, ";")
    Variable loc_nimg = ItemsInList(loc_imgs, ";")
    if (loc_nimg <= 0)
        Abort "Top graph has no images."
    endif

    Wave/W/U loc_ct = root:ARPES_LJZ:CTLUZ:ct_table
    Wave loc_lut = root:ARPES_LJZ:CTLUZ:ct_lut

    Variable loc_i
    for (loc_i = 0; loc_i < loc_nimg; loc_i += 1)
        String loc_im = StringFromList(loc_i, loc_imgs, ";")
        ctluz_apply_snapshot_to_image(loc_g, loc_im, loc_ct, loc_lut, 1)
    endfor

    return 0
End


// ============================================================
// Buttons
// ============================================================

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

Function CTLUZ_btn_save(ctrlName) : ButtonControl
    String ctrlName
    ctluz_rebuild()
    ctluz_save_current_ct()
    return 0
End

Function CTLUZ_btn_apply_saved(ctrlName) : ButtonControl
    String ctrlName
    ctluz_apply_picked_ct()
    return 0
End


// ============================================================
// Panel
// ============================================================

Window CTLUZ_LJZ_P() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(887.4,343.2,1360.2,760.8) as "CTLUZ_LJZ (CT + LUT + Apply)"
	ModifyPanel frameStyle=1
	ShowTools/A
	TitleBox ctt0,pos={13.80,12.60},size={307.80,11.40},title="5-point ColorTable (RGB 0..255) + Positions (0..1)  |  Safe Snapshot Apply"
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

	TitleBox ctnote,pos={12.00,189.00},size={430.20,18.00},title="Note: p0 forced to 0 and p4 forced to 1; p1<p2<p3 enforced with epsilon."
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
	PopupMenu ctpm_saved,mode=1,popvalue="Mualani",value= #"root:ARPES_LJZ:CTLUZ:ctlib_menu_list"
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


// ============================================================
// Build a 5-point linear CT into a given 65536x4 U16 wave
// inputs are 8-bit RGB (0..255)
// ============================================================

Function ctluz_make_ct_from_5rgb(dest, c0r,c0g,c0b, c1r,c1g,c1b, c2r,c2g,c2b, c3r,c3g,c3b, c4r,c4g,c4b)
    Wave/W/U dest
    Variable c0r,c0g,c0b, c1r,c1g,c1b, c2r,c2g,c2b, c3r,c3g,c3b, c4r,c4g,c4b

    Variable nn = DimSize(dest, 0)
    if (nn <= 1)
        Abort "dest CT wave has invalid size."
    endif

    Variable ii, seg, uu, ss
    Variable a0r16, a0g16, a0b16, a1r16, a1g16, a1b16

    c0r = ctluz_clamp(c0r, 0, 255)
    c0g = ctluz_clamp(c0g, 0, 255)
    c0b = ctluz_clamp(c0b, 0, 255)

    c1r = ctluz_clamp(c1r, 0, 255)
    c1g = ctluz_clamp(c1g, 0, 255)
    c1b = ctluz_clamp(c1b, 0, 255)

    c2r = ctluz_clamp(c2r, 0, 255)
    c2g = ctluz_clamp(c2g, 0, 255)
    c2b = ctluz_clamp(c2b, 0, 255)

    c3r = ctluz_clamp(c3r, 0, 255)
    c3g = ctluz_clamp(c3g, 0, 255)
    c3b = ctluz_clamp(c3b, 0, 255)

    c4r = ctluz_clamp(c4r, 0, 255)
    c4g = ctluz_clamp(c4g, 0, 255)
    c4b = ctluz_clamp(c4b, 0, 255)

    for (ii = 0; ii < nn; ii += 1)
        ss = ii / (nn - 1.0)
        seg = floor(4 * ss)
        if (seg < 0)
            seg = 0
        endif
        if (seg > 3)
            seg = 3
        endif
        uu = 4 * ss - seg

        if (seg == 0)
            a0r16 = c0r * 257; a0g16 = c0g * 257; a0b16 = c0b * 257
            a1r16 = c1r * 257; a1g16 = c1g * 257; a1b16 = c1b * 257

        elseif (seg == 1)
            a0r16 = c1r * 257; a0g16 = c1g * 257; a0b16 = c1b * 257
            a1r16 = c2r * 257; a1g16 = c2g * 257; a1b16 = c2b * 257

        elseif (seg == 2)
            a0r16 = c2r * 257; a0g16 = c2g * 257; a0b16 = c2b * 257
            a1r16 = c3r * 257; a1g16 = c3g * 257; a1b16 = c3b * 257

        else
            a0r16 = c3r * 257; a0g16 = c3g * 257; a0b16 = c3b * 257
            a1r16 = c4r * 257; a1g16 = c4g * 257; a1b16 = c4b * 257
        endif

        dest[ii][0] = round((1 - uu) * a0r16 + uu * a1r16)
        dest[ii][1] = round((1 - uu) * a0g16 + uu * a1g16)
        dest[ii][2] = round((1 - uu) * a0b16 + uu * a1b16)
        dest[ii][3] = 65535
    endfor

    return 0
End


// ============================================================
// install built-in palettes into CTLIB (only if missing)
// unified "light-background" family
// saved as English names under root:ARPES_LJZ:CTLUZ:CTLIB
// ============================================================

Function ctluz_install_builtin_ctlib()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:CTLUZ:CTLIB

    // Nilou
    if (!WaveExists($("Nilou")))
        Make/O/W/U/N=(65536,4) Nilou
        ctluz_make_ct_from_5rgb(Nilou, 246,248,250, 188,221,230, 92,156,186, 228,126,102, 76,98,128)
    endif

    // KujouSara
    if (!WaveExists($("KujouSara")))
        Make/O/W/U/N=(65536,4) KujouSara
        ctluz_make_ct_from_5rgb(KujouSara, 245,244,246, 206,196,216, 131,104,152, 208,170,92, 82,78,106)
    endif

    // Xiangling
    if (!WaveExists($("Xiangling")))
        Make/O/W/U/N=(65536,4) Xiangling
        ctluz_make_ct_from_5rgb(Xiangling, 249,246,238, 245,212,150, 222,133,73, 122,168,104, 82,96,120)
    endif

    // Zhongli
    if (!WaveExists($("Zhongli")))
        Make/O/W/U/N=(65536,4) Zhongli
        ctluz_make_ct_from_5rgb(Zhongli, 248,244,236, 228,205,160, 196,140,78, 252,208,110, 106,98,116)
    endif

    // Kirara
    if (!WaveExists($("Kirara")))
        Make/O/W/U/N=(65536,4) Kirara
        ctluz_make_ct_from_5rgb(Kirara, 246,248,244, 202,228,214, 124,182,176, 220,194,118, 92,142,92)
    endif

    // Keqing
    if (!WaveExists($("Keqing")))
        Make/O/W/U/N=(65536,4) Keqing
        ctluz_make_ct_from_5rgb(Keqing, 249,244,244, 230,198,214, 180,136,186, 228,124,110, 108,86,120)
    endif

    // NavyBurgundy
    if (!WaveExists($("NavyBurgundy")))
        Make/O/W/U/N=(65536,4) NavyBurgundy
        ctluz_make_ct_from_5rgb(NavyBurgundy, 246,247,249, 203,220,238, 112,138,182, 186,98,98, 72,84,118)
    endif

    // Chasca
    if (!WaveExists($("Chasca")))
        Make/O/W/U/N=(65536,4) Chasca
        ctluz_make_ct_from_5rgb(Chasca, 249,245,242, 192,225,228, 96,116,184, 176,84,116, 72,72,110)
    endif

    // Xilonen
    if (!WaveExists($("Xilonen")))
        Make/O/W/U/N=(65536,4) Xilonen
        ctluz_make_ct_from_5rgb(Xilonen, 250,246,238, 244,215,176, 238,138,64, 171,224,197, 88,108,100)
    endif

    // Mualani
    if (!WaveExists($("Mualani")))
        Make/O/W/U/N=(65536,4) Mualani
        ctluz_make_ct_from_5rgb(Mualani, 246,247,249, 198,222,238, 82,122,204, 90,188,196, 232,188,74)
    endif

    // Mavuika
    if (!WaveExists($("Mavuika")))
        Make/O/W/U/N=(65536,4) Mavuika
        ctluz_make_ct_from_5rgb(Mavuika, 252,240,230, 244,192,176, 232,92,62, 205,114,118, 96,82,86)
    endif

    // Kinich
    if (!WaveExists($("Kinich")))
        Make/O/W/U/N=(65536,4) Kinich
        ctluz_make_ct_from_5rgb(Kinich, 246,243,228, 216,234,176, 110,188,144, 72,126,136, 76,88,66)
    endif

    // Citlali
    if (!WaveExists($("Citlali")))
        Make/O/W/U/N=(65536,4) Citlali
        ctluz_make_ct_from_5rgb(Citlali, 252,244,242, 233,204,226, 150,136,204, 236,118,170, 86,74,116)
    endif

    // Varesa
    if (!WaveExists($("Varesa")))
        Make/O/W/U/N=(65536,4) Varesa
        ctluz_make_ct_from_5rgb(Varesa, 250,240,236, 244,204,206, 118,208,196, 250,226,154, 156,122,186)
    endif

    // NeonClash
    if (!WaveExists($("NeonClash")))
        Make/O/W/U/N=(65536,4) NeonClash
        ctluz_make_ct_from_5rgb(NeonClash, 248,244,248, 236,138,162, 176,74,170, 88,92,224, 28,126,220)
    endif

    // CyberPunk
    if (!WaveExists($("CyberPunk")))
        Make/O/W/U/N=(65536,4) CyberPunk
        ctluz_make_ct_from_5rgb(CyberPunk, 248,244,249, 240,150,212, 176,92,210, 82,112,226, 48,210,210)
    endif

    // ToxicHeat
    if (!WaveExists($("ToxicHeat")))
        Make/O/W/U/N=(65536,4) ToxicHeat
        ctluz_make_ct_from_5rgb(ToxicHeat, 246,248,238, 188,220,118, 228,190,64, 232,112,48, 182,42,38)
    endif

    SetDataFolder df0
    return 0
End
