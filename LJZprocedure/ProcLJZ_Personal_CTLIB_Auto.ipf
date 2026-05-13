#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma DefaultTab={3,20,4}

// ============================================================================
//  ProcLJZ_Personal_CTLIB_Auto.ipf
//
//  Personal startup color-table library for Igor Pro.
//
//  What it does:
//    1) Creates folders:
//         root:ARPES_LJZ:CTLUZ:
//         root:ARPES_LJZ:CTLUZ:CTLIB:
//         root:ARPES_LJZ:CTLUZ:APPLIED:
//
//    2) Installs the personal 5-anchor palettes originally embedded in
//       ctluz_install_builtin_ctlib():
//         Nilou, KujouSara, Xiangling, Zhongli, Kirara, Keqing,
//         NavyBurgundy, Chasca, Xilonen, Mualani, Mavuika,
//         Kinich, Citlali, Varesa, NeonClash, CyberPunk, ToxicHeat.
//
//    3) Rebuilds root:ARPES_LJZ:CTLUZ:ctlib_menu_list so older LJZ tools can
//       still find the palette list.
//
//    4) Creates workspace waves if missing:
//         root:ARPES_LJZ:CTLUZ:ct_table
//         root:ARPES_LJZ:CTLUZ:ct_lut
//
//  Important:
//    - This file deliberately does NOT define ctluz_* functions.
//      It can therefore be loaded together with your older CTLUZ panel without
//      duplicate-function compile errors.
//    - Startup loading uses IgorStartOrNewHook.
//    - Normal startup load does not overwrite existing palette waves.
//      Use the Force Reload menu item if you intentionally want to overwrite.
// ============================================================================


Menu "ARPES_LJZ"
    "Reload Personal CTLIB", LJZ_PersonalCTLib_Load()
    "Force Reload Personal CTLIB", LJZ_PersonalCTLib_ForceReload()
End


Static Function IgorStartOrNewHook(igorApplicationNameStr)
    String igorApplicationNameStr

    LJZ_PersonalCTLib_Load()
    return 0
End


// ============================================================================
//  Basic helpers
// ============================================================================

Function LJZ_PersonalCTLib_Clamp(v, lo, hi)
    Variable v, lo, hi

    if (v < lo)
        return lo
    endif
    if (v > hi)
        return hi
    endif
    return v
End


Function LJZ_PersonalCTLib_EnsureFolders()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:CTLUZ
    NewDataFolder/O root:ARPES_LJZ:CTLUZ:CTLIB
    NewDataFolder/O root:ARPES_LJZ:CTLUZ:APPLIED

    SVAR/Z menuList = root:ARPES_LJZ:CTLUZ:ctlib_menu_list
    if (!SVAR_Exists(menuList))
        String/G root:ARPES_LJZ:CTLUZ:ctlib_menu_list = ""
    endif

    return 0
End


Function LJZ_PersonalCTLib_FillLinearLUT(lut)
    Wave lut

    Variable n = numpnts(lut)
    Variable i

    if (n <= 0)
        return -1
    endif

    for (i = 0; i < n; i += 1)
        if (n > 1)
            lut[i] = i / (n - 1.0)
        else
            lut[i] = 0
        endif
    endfor

    return 0
End


// ============================================================================
//  5-anchor CT construction
//  Output wave format: 65536 x 4 unsigned 16-bit RGBA.
// ============================================================================

Function LJZ_PersonalCTLib_Fill5(dest, c0r,c0g,c0b, c1r,c1g,c1b, c2r,c2g,c2b, c3r,c3g,c3b, c4r,c4g,c4b)
    Wave/W/U dest
    Variable c0r,c0g,c0b
    Variable c1r,c1g,c1b
    Variable c2r,c2g,c2b
    Variable c3r,c3g,c3b
    Variable c4r,c4g,c4b

    Variable nn = DimSize(dest, 0)
    if (nn <= 1)
        return -1
    endif

    c0r = LJZ_PersonalCTLib_Clamp(c0r, 0, 255)
    c0g = LJZ_PersonalCTLib_Clamp(c0g, 0, 255)
    c0b = LJZ_PersonalCTLib_Clamp(c0b, 0, 255)

    c1r = LJZ_PersonalCTLib_Clamp(c1r, 0, 255)
    c1g = LJZ_PersonalCTLib_Clamp(c1g, 0, 255)
    c1b = LJZ_PersonalCTLib_Clamp(c1b, 0, 255)

    c2r = LJZ_PersonalCTLib_Clamp(c2r, 0, 255)
    c2g = LJZ_PersonalCTLib_Clamp(c2g, 0, 255)
    c2b = LJZ_PersonalCTLib_Clamp(c2b, 0, 255)

    c3r = LJZ_PersonalCTLib_Clamp(c3r, 0, 255)
    c3g = LJZ_PersonalCTLib_Clamp(c3g, 0, 255)
    c3b = LJZ_PersonalCTLib_Clamp(c3b, 0, 255)

    c4r = LJZ_PersonalCTLib_Clamp(c4r, 0, 255)
    c4g = LJZ_PersonalCTLib_Clamp(c4g, 0, 255)
    c4b = LJZ_PersonalCTLib_Clamp(c4b, 0, 255)

    Variable ii
    Variable seg
    Variable uu
    Variable ss
    Variable a0r16, a0g16, a0b16
    Variable a1r16, a1g16, a1b16

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
            a0r16 = c0r * 257
            a0g16 = c0g * 257
            a0b16 = c0b * 257
            a1r16 = c1r * 257
            a1g16 = c1g * 257
            a1b16 = c1b * 257
        elseif (seg == 1)
            a0r16 = c1r * 257
            a0g16 = c1g * 257
            a0b16 = c1b * 257
            a1r16 = c2r * 257
            a1g16 = c2g * 257
            a1b16 = c2b * 257
        elseif (seg == 2)
            a0r16 = c2r * 257
            a0g16 = c2g * 257
            a0b16 = c2b * 257
            a1r16 = c3r * 257
            a1g16 = c3g * 257
            a1b16 = c3b * 257
        else
            a0r16 = c3r * 257
            a0g16 = c3g * 257
            a0b16 = c3b * 257
            a1r16 = c4r * 257
            a1g16 = c4g * 257
            a1b16 = c4b * 257
        endif

        dest[ii][0] = round((1 - uu) * a0r16 + uu * a1r16)
        dest[ii][1] = round((1 - uu) * a0g16 + uu * a1g16)
        dest[ii][2] = round((1 - uu) * a0b16 + uu * a1b16)
        dest[ii][3] = 65535
    endfor

    return 0
End


Function LJZ_PersonalCTLib_InstallPalette(ctName, overwrite, c0r,c0g,c0b, c1r,c1g,c1b, c2r,c2g,c2b, c3r,c3g,c3b, c4r,c4g,c4b)
    String ctName
    Variable overwrite
    Variable c0r,c0g,c0b
    Variable c1r,c1g,c1b
    Variable c2r,c2g,c2b
    Variable c3r,c3g,c3b
    Variable c4r,c4g,c4b

    LJZ_PersonalCTLib_EnsureFolders()

    String cleanName = CleanupName(ctName, 0)
    if (strlen(cleanName) == 0)
        return -1
    endif

    String outPath = "root:ARPES_LJZ:CTLUZ:CTLIB:" + cleanName

    Wave/Z/W/U existing = $outPath
    if (WaveExists(existing) && !overwrite)
        return 0
    endif

    Make/O/W/U/N=(65536,4) $outPath
    Wave/W/U dest = $outPath

    LJZ_PersonalCTLib_Fill5(dest, c0r,c0g,c0b, c1r,c1g,c1b, c2r,c2g,c2b, c3r,c3g,c3b, c4r,c4g,c4b)

    return 0
End


// ============================================================================
//  Personal palettes
// ============================================================================

Function LJZ_PersonalCTLib_InstallAll(overwrite)
    Variable overwrite

    LJZ_PersonalCTLib_EnsureFolders()

    LJZ_PersonalCTLib_InstallPalette("Nilou", overwrite, 246,248,250, 188,221,230, 92,156,186, 228,126,102, 76,98,128)
    LJZ_PersonalCTLib_InstallPalette("KujouSara", overwrite, 245,244,246, 206,196,216, 131,104,152, 208,170,92, 82,78,106)
    LJZ_PersonalCTLib_InstallPalette("Xiangling", overwrite, 249,246,238, 245,212,150, 222,133,73, 122,168,104, 82,96,120)
    LJZ_PersonalCTLib_InstallPalette("Zhongli", overwrite, 248,244,236, 228,205,160, 196,140,78, 252,208,110, 106,98,116)
    LJZ_PersonalCTLib_InstallPalette("Kirara", overwrite, 246,248,244, 202,228,214, 124,182,176, 220,194,118, 92,142,92)
    LJZ_PersonalCTLib_InstallPalette("Keqing", overwrite, 249,244,244, 230,198,214, 180,136,186, 228,124,110, 108,86,120)
    LJZ_PersonalCTLib_InstallPalette("NavyBurgundy", overwrite, 246,247,249, 203,220,238, 112,138,182, 186,98,98, 72,84,118)
    LJZ_PersonalCTLib_InstallPalette("Chasca", overwrite, 249,245,242, 192,225,228, 96,116,184, 176,84,116, 72,72,110)
    LJZ_PersonalCTLib_InstallPalette("Xilonen", overwrite, 250,246,238, 244,215,176, 238,138,64, 171,224,197, 88,108,100)
    LJZ_PersonalCTLib_InstallPalette("Mualani", overwrite, 246,247,249, 198,222,238, 82,122,204, 90,188,196, 232,188,74)
    LJZ_PersonalCTLib_InstallPalette("Mavuika", overwrite, 252,240,230, 244,192,176, 232,92,62, 205,114,118, 96,82,86)
    LJZ_PersonalCTLib_InstallPalette("Kinich", overwrite, 246,243,228, 216,234,176, 110,188,144, 72,126,136, 76,88,66)
    LJZ_PersonalCTLib_InstallPalette("Citlali", overwrite, 252,244,242, 233,204,226, 150,136,204, 236,118,170, 86,74,116)
    LJZ_PersonalCTLib_InstallPalette("Varesa", overwrite, 250,240,236, 244,204,206, 118,208,196, 250,226,154, 156,122,186)
    LJZ_PersonalCTLib_InstallPalette("NeonClash", overwrite, 248,244,248, 236,138,162, 176,74,170, 88,92,224, 28,126,220)
    LJZ_PersonalCTLib_InstallPalette("CyberPunk", overwrite, 248,244,249, 240,150,212, 176,92,210, 82,112,226, 48,210,210)
    LJZ_PersonalCTLib_InstallPalette("ToxicHeat", overwrite, 246,248,238, 188,220,118, 228,190,64, 232,112,48, 182,42,38)

    LJZ_PersonalCTLib_UpdateMenuList()

    return 0
End


// ============================================================================
//  Menu list and workspace waves
// ============================================================================

Function LJZ_PersonalCTLib_UpdateMenuList()
    LJZ_PersonalCTLib_EnsureFolders()

    String prefList = "Mualani;NavyBurgundy;Nilou;Mavuika;Citlali;Kinich;Varesa;Zhongli;Kirara;KujouSara;Chasca;Xilonen;Xiangling;Keqing;NeonClash;CyberPunk;ToxicHeat;"
    String finalList = ""

    Variable i
    Variable n
    String nm

    n = ItemsInList(prefList, ";")
    for (i = 0; i < n; i += 1)
        nm = StringFromList(i, prefList, ";")
        if (strlen(nm) == 0)
            continue
        endif

        Wave/Z wPref = $("root:ARPES_LJZ:CTLUZ:CTLIB:" + nm)
        if (WaveExists(wPref))
            if (WhichListItem(nm, finalList, ";", 0, 0) < 0)
                finalList += nm + ";"
            endif
        endif
    endfor

    String oldDF = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:CTLUZ:CTLIB
    String allList = WaveList("*", ";", "DIMS:2")
    SetDataFolder oldDF

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

    SVAR/Z menuList = root:ARPES_LJZ:CTLUZ:ctlib_menu_list
    if (!SVAR_Exists(menuList))
        String/G root:ARPES_LJZ:CTLUZ:ctlib_menu_list = finalList
    else
        menuList = finalList
    endif

    return 0
End


Function LJZ_PersonalCTLib_EnsureWorkspaceWaves()
    LJZ_PersonalCTLib_EnsureFolders()

    Wave/Z lut = root:ARPES_LJZ:CTLUZ:ct_lut
    if (!WaveExists(lut))
        Make/O/N=65536 root:ARPES_LJZ:CTLUZ:ct_lut
        Wave lutNew = root:ARPES_LJZ:CTLUZ:ct_lut
        LJZ_PersonalCTLib_FillLinearLUT(lutNew)
    endif

    Wave/Z/W/U curCT = root:ARPES_LJZ:CTLUZ:ct_table
    if (!WaveExists(curCT))
        Wave/Z/W/U mualani = root:ARPES_LJZ:CTLUZ:CTLIB:Mualani
        if (WaveExists(mualani))
            Duplicate/O mualani, root:ARPES_LJZ:CTLUZ:ct_table
        else
            Make/O/W/U/N=(65536,4) root:ARPES_LJZ:CTLUZ:ct_table
            Wave/W/U fallback = root:ARPES_LJZ:CTLUZ:ct_table
            LJZ_PersonalCTLib_Fill5(fallback, 246,247,249, 198,222,238, 82,122,204, 90,188,196, 232,188,74)
        endif
    endif

    return 0
End


// ============================================================================
//  Public entry points
// ============================================================================

Function LJZ_PersonalCTLib_Load()
    // Safe mode: install only missing palettes.
    LJZ_PersonalCTLib_InstallAll(0)
    LJZ_PersonalCTLib_EnsureWorkspaceWaves()
    LJZ_PersonalCTLib_UpdateMenuList()
    return 0
End


Function LJZ_PersonalCTLib_ForceReload()
    // Overwrite mode: intentionally rewrite all built-in personal palettes.
    LJZ_PersonalCTLib_InstallAll(1)

    Wave/Z/W/U mualani = root:ARPES_LJZ:CTLUZ:CTLIB:Mualani
    if (WaveExists(mualani))
        Duplicate/O mualani, root:ARPES_LJZ:CTLUZ:ct_table
    endif

    Make/O/N=65536 root:ARPES_LJZ:CTLUZ:ct_lut
    Wave lut = root:ARPES_LJZ:CTLUZ:ct_lut
    LJZ_PersonalCTLib_FillLinearLUT(lut)

    LJZ_PersonalCTLib_UpdateMenuList()
    return 0
End
