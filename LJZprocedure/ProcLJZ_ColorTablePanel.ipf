#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma DefaultTab={3,20,4}

// ============================================================================
//  ProcLJZ_ColorTablePanel_v2_1.ipf
//
//  Safer color-table manager for Igor Pro image graphs.
//
//  Main changes from v2:
//    1) Connects the user palette library:
//         root:ARPES_LJZ:CTLUZ:CTLIB:
//       It lists all valid numeric N x 3 color-table waves in that folder.
//    2) Library palettes can be previewed, applied to the selected graph image,
//       loaded into the Custom 5-anchor editor, or overwritten by Custom 5.
//    3) Custom 5 editor now has Swap A/B tools to swap two selected anchor colors.
//       It swaps only RGB values, not anchor positions.
//    4) This file intentionally does not define old ctluz_* functions, so it can
//       coexist with ProcLJZ_CTLUZ_Compat_v2.ipf or your older CTLUZ tools.
//    5) No lookup=lutWave is used anywhere in this panel.
//
//  Recommended workflow:
//    Graph on top -> open panel -> Refresh images -> select one image.
//    Then use either built-in CT or CTLIB palette -> Apply selected.
// ============================================================================


Menu "ARPES_LJZ"
    "ColorTable Panel v2.1", LJZ_CTP2_OpenPanel()
End


// ============================================================================
//  Section 0. Paths / state
// ============================================================================

Function/S LJZ_CTP2_BaseDF()
    return "root:Packages:LJZ_ColorTablePanelV2"
End


Function/S LJZ_CTP2_CTLIB_DF()
    return "root:ARPES_LJZ:CTLUZ:CTLIB"
End


Function/S LJZ_CTP2_CTLIB_DF_Colon()
    return "root:ARPES_LJZ:CTLUZ:CTLIB:"
End


Function/S LJZ_CTP2_PanelName()
    return "LJZ_ColorTablePanelV2_Panel"
End


Function/S LJZ_CTP2_PreviewGraphName()
    return "ctPreviewGraph"
End


Function/S LJZ_CTP2_PreviewGraphPath()
    return LJZ_CTP2_PanelName() + "#" + LJZ_CTP2_PreviewGraphName()
End


Function LJZ_CTP2_HasChildSubwindow(hostWin, childName)
    String hostWin
    String childName

    String childList
    childList = ChildWindowList(hostWin)

    if (WhichListItem(childName, childList, ";", 0, 0) >= 0)
        return 1
    endif

    return 0
End


Function LJZ_CTP2_Clamp(v, lo, hi)
    Variable v
    Variable lo
    Variable hi

    if (v < lo)
        return lo
    endif

    if (v > hi)
        return hi
    endif

    return v
End


Function LJZ_CTP2_EnsureCTLIB()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:CTLUZ
    NewDataFolder/O root:ARPES_LJZ:CTLUZ:CTLIB

    // These defaults are created only if absent. Existing user palettes are not
    // touched and no CTLIB folder is ever killed by this panel.
    Wave/Z/W/U wMualani = root:ARPES_LJZ:CTLUZ:CTLIB:Mualani
    if (!WaveExists(wMualani))
        Make/O/W/U/N=(256,3) root:ARPES_LJZ:CTLUZ:CTLIB:Mualani
        Wave/W/U mualani = root:ARPES_LJZ:CTLUZ:CTLIB:Mualani
        LJZ_CTP2_FillMualaniCT(mualani)
    endif

    Wave/Z/W/U wGray = root:ARPES_LJZ:CTLUZ:CTLIB:Gray
    if (!WaveExists(wGray))
        Make/O/W/U/N=(256,3) root:ARPES_LJZ:CTLUZ:CTLIB:Gray
        Wave/W/U gray = root:ARPES_LJZ:CTLUZ:CTLIB:Gray
        LJZ_CTP2_FillGrayCT(gray)
    endif

    Wave/Z/W/U wCyanHot = root:ARPES_LJZ:CTLUZ:CTLIB:CyanHot
    if (!WaveExists(wCyanHot))
        Make/O/W/U/N=(256,3) root:ARPES_LJZ:CTLUZ:CTLIB:CyanHot
        Wave/W/U cyanhot = root:ARPES_LJZ:CTLUZ:CTLIB:CyanHot
        LJZ_CTP2_FillCyanHotCT(cyanhot)
    endif

    Wave/Z/W/U wWhiteBlue = root:ARPES_LJZ:CTLUZ:CTLIB:WhiteBlue
    if (!WaveExists(wWhiteBlue))
        Make/O/W/U/N=(256,3) root:ARPES_LJZ:CTLUZ:CTLIB:WhiteBlue
        Wave/W/U whiteBlue = root:ARPES_LJZ:CTLUZ:CTLIB:WhiteBlue
        LJZ_CTP2_FillWhiteBlueCT(whiteBlue)
    endif

    Wave/Z/W/U wWhiteGray = root:ARPES_LJZ:CTLUZ:CTLIB:WhiteGray
    if (!WaveExists(wWhiteGray))
        Make/O/W/U/N=(256,3) root:ARPES_LJZ:CTLUZ:CTLIB:WhiteGray
        Wave/W/U whiteGray = root:ARPES_LJZ:CTLUZ:CTLIB:WhiteGray
        LJZ_CTP2_FillWhiteGrayCT(whiteGray)
    endif

    return 0
End


Function LJZ_CTP2_EnsureDF()
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:LJZ_ColorTablePanelV2
    LJZ_CTP2_EnsureCTLIB()

    SVAR/Z GraphName = $(LJZ_CTP2_BaseDF() + ":GraphName")
    if (!SVAR_Exists(GraphName))
        String/G $(LJZ_CTP2_BaseDF() + ":GraphName") = ""
    endif

    SVAR/Z ExistingImageName = $(LJZ_CTP2_BaseDF() + ":ExistingImageName")
    if (!SVAR_Exists(ExistingImageName))
        String/G $(LJZ_CTP2_BaseDF() + ":ExistingImageName") = ""
    endif

    SVAR/Z BuiltinCTName = $(LJZ_CTP2_BaseDF() + ":BuiltinCTName")
    if (!SVAR_Exists(BuiltinCTName))
        String/G $(LJZ_CTP2_BaseDF() + ":BuiltinCTName") = "Grays"
    endif

    SVAR/Z LibraryCTName = $(LJZ_CTP2_BaseDF() + ":LibraryCTName")
    if (!SVAR_Exists(LibraryCTName))
        String/G $(LJZ_CTP2_BaseDF() + ":LibraryCTName") = "Mualani"
    endif

    SVAR/Z LibraryMenuList = $(LJZ_CTP2_BaseDF() + ":LibraryMenuList")
    if (!SVAR_Exists(LibraryMenuList))
        String/G $(LJZ_CTP2_BaseDF() + ":LibraryMenuList") = "Mualani;Gray;CyanHot;"
    endif
    
    Wave/T/Z LibList = $(LJZ_CTP2_BaseDF() + ":LibList")
    if (!WaveExists(LibList))
        Make/O/T/N=0 $(LJZ_CTP2_BaseDF() + ":LibList")
    endif

    Wave/Z LibSel = $(LJZ_CTP2_BaseDF() + ":LibSel")
    if (!WaveExists(LibSel))
        Make/O/N=0 $(LJZ_CTP2_BaseDF() + ":LibSel")
    endif

    SVAR/Z SaveCustomName = $(LJZ_CTP2_BaseDF() + ":SaveCustomName")
    if (!SVAR_Exists(SaveCustomName))
        String/G $(LJZ_CTP2_BaseDF() + ":SaveCustomName") = "MyCustomCT"
    endif

    NVAR/Z SelImageRow = $(LJZ_CTP2_BaseDF() + ":SelImageRow")
    if (!NVAR_Exists(SelImageRow))
        Variable/G $(LJZ_CTP2_BaseDF() + ":SelImageRow") = -1
    endif

    NVAR/Z ReverseCT = $(LJZ_CTP2_BaseDF() + ":ReverseCT")
    if (!NVAR_Exists(ReverseCT))
        Variable/G $(LJZ_CTP2_BaseDF() + ":ReverseCT") = 0
    endif

    NVAR/Z UseManualRange = $(LJZ_CTP2_BaseDF() + ":UseManualRange")
    if (!NVAR_Exists(UseManualRange))
        Variable/G $(LJZ_CTP2_BaseDF() + ":UseManualRange") = 0
    endif

    NVAR/Z CMin = $(LJZ_CTP2_BaseDF() + ":CMin")
    if (!NVAR_Exists(CMin))
        Variable/G $(LJZ_CTP2_BaseDF() + ":CMin") = 0
    endif

    NVAR/Z CMax = $(LJZ_CTP2_BaseDF() + ":CMax")
    if (!NVAR_Exists(CMax))
        Variable/G $(LJZ_CTP2_BaseDF() + ":CMax") = 1
    endif

    NVAR/Z ApplyToAllConfirm = $(LJZ_CTP2_BaseDF() + ":ApplyToAllConfirm")
    if (!NVAR_Exists(ApplyToAllConfirm))
        Variable/G $(LJZ_CTP2_BaseDF() + ":ApplyToAllConfirm") = 0
    endif

    NVAR/Z SwapA = $(LJZ_CTP2_BaseDF() + ":SwapA")
    if (!NVAR_Exists(SwapA))
        Variable/G $(LJZ_CTP2_BaseDF() + ":SwapA") = 1
    endif

    NVAR/Z SwapB = $(LJZ_CTP2_BaseDF() + ":SwapB")
    if (!NVAR_Exists(SwapB))
        Variable/G $(LJZ_CTP2_BaseDF() + ":SwapB") = 3
    endif

    NVAR/Z p0 = $(LJZ_CTP2_BaseDF() + ":p0")
    if (!NVAR_Exists(p0))
        Variable/G $(LJZ_CTP2_BaseDF() + ":p0") = 0
    endif

    NVAR/Z p1 = $(LJZ_CTP2_BaseDF() + ":p1")
    if (!NVAR_Exists(p1))
        Variable/G $(LJZ_CTP2_BaseDF() + ":p1") = 0.25
    endif

    NVAR/Z p2 = $(LJZ_CTP2_BaseDF() + ":p2")
    if (!NVAR_Exists(p2))
        Variable/G $(LJZ_CTP2_BaseDF() + ":p2") = 0.50
    endif

    NVAR/Z p3 = $(LJZ_CTP2_BaseDF() + ":p3")
    if (!NVAR_Exists(p3))
        Variable/G $(LJZ_CTP2_BaseDF() + ":p3") = 0.75
    endif

    NVAR/Z p4 = $(LJZ_CTP2_BaseDF() + ":p4")
    if (!NVAR_Exists(p4))
        Variable/G $(LJZ_CTP2_BaseDF() + ":p4") = 1
    endif

    NVAR/Z r0 = $(LJZ_CTP2_BaseDF() + ":r0")
    if (!NVAR_Exists(r0))
        Variable/G $(LJZ_CTP2_BaseDF() + ":r0") = 0
        Variable/G $(LJZ_CTP2_BaseDF() + ":g0") = 0
        Variable/G $(LJZ_CTP2_BaseDF() + ":b0") = 0

        Variable/G $(LJZ_CTP2_BaseDF() + ":r1") = 0
        Variable/G $(LJZ_CTP2_BaseDF() + ":g1") = 0
        Variable/G $(LJZ_CTP2_BaseDF() + ":b1") = 255

        Variable/G $(LJZ_CTP2_BaseDF() + ":r2") = 0
        Variable/G $(LJZ_CTP2_BaseDF() + ":g2") = 255
        Variable/G $(LJZ_CTP2_BaseDF() + ":b2") = 255

        Variable/G $(LJZ_CTP2_BaseDF() + ":r3") = 255
        Variable/G $(LJZ_CTP2_BaseDF() + ":g3") = 255
        Variable/G $(LJZ_CTP2_BaseDF() + ":b3") = 0

        Variable/G $(LJZ_CTP2_BaseDF() + ":r4") = 255
        Variable/G $(LJZ_CTP2_BaseDF() + ":g4") = 255
        Variable/G $(LJZ_CTP2_BaseDF() + ":b4") = 255
    endif

    Wave/T/Z ImgList = $(LJZ_CTP2_BaseDF() + ":ImgList")
    if (!WaveExists(ImgList))
        Make/O/T/N=0 $(LJZ_CTP2_BaseDF() + ":ImgList")
    endif

    Wave/Z ImgSel = $(LJZ_CTP2_BaseDF() + ":ImgSel")
    if (!WaveExists(ImgSel))
        Make/O/N=0 $(LJZ_CTP2_BaseDF() + ":ImgSel")
    endif

    Wave/Z/W/U CustomCT = $(LJZ_CTP2_BaseDF() + ":CustomCT")
    if (!WaveExists(CustomCT))
        Make/O/W/U/N=(256,3) $(LJZ_CTP2_BaseDF() + ":CustomCT")
    endif

    Wave/Z PreviewImage = $(LJZ_CTP2_BaseDF() + ":PreviewImage")
    if (!WaveExists(PreviewImage))
        Make/O/N=(256,16) $(LJZ_CTP2_BaseDF() + ":PreviewImage")
        Wave prev = $(LJZ_CTP2_BaseDF() + ":PreviewImage")
        LJZ_CTP2_InitPreviewImage(prev)
    endif

    LJZ_CTP2_RefreshLibraryList()
    return 0
End


Function LJZ_CTP2_InitPreviewImage(prev)
    Wave prev

    Variable nx
    Variable ny
    Variable i
    Variable j

    nx = DimSize(prev, 0)
    ny = DimSize(prev, 1)

    if (nx <= 0 || ny <= 0)
        return -1
    endif

    for (i = 0; i < nx; i += 1)
        for (j = 0; j < ny; j += 1)
            prev[i][j] = i
        endfor
    endfor

    SetScale/I x, 0, nx - 1, "", prev
    SetScale/I y, 0, 1, "", prev
    return 0
End


// ============================================================================
//  Section 1. Graph / image selection
// ============================================================================

Function/S LJZ_CTP2_GetGraphName(createIfMissing)
    Variable createIfMissing

    LJZ_CTP2_EnsureDF()

    SVAR GraphName = $(LJZ_CTP2_BaseDF() + ":GraphName")
    String gName
    gName = GraphName

    if (strlen(gName) == 0)
        gName = WinName(0, 1)
    endif

    if (strlen(gName) == 0)
        if (createIfMissing)
            Display/N=LJZ_CTP2_Graph
            gName = "LJZ_CTP2_Graph"
        else
            return ""
        endif
    endif

    if (WinType(gName) == 0)
        if (createIfMissing)
            Display/N=$gName
        else
            return ""
        endif
    endif

    return gName
End


Function LJZ_CTP2_SetSelectedImage(row)
    Variable row

    LJZ_CTP2_EnsureDF()

    Wave/T ImgList = $(LJZ_CTP2_BaseDF() + ":ImgList")
    Wave ImgSel = $(LJZ_CTP2_BaseDF() + ":ImgSel")
    NVAR SelImageRow = $(LJZ_CTP2_BaseDF() + ":SelImageRow")
    SVAR ExistingImageName = $(LJZ_CTP2_BaseDF() + ":ExistingImageName")

    ImgSel = 0

    if (numpnts(ImgList) <= 0)
        SelImageRow = -1
        ExistingImageName = ""
        return -1
    endif

    if (row < 0 || row >= numpnts(ImgList))
        SelImageRow = -1
        ExistingImageName = ""
        return -1
    endif

    ImgSel[row] = 1
    SelImageRow = row
    ExistingImageName = ImgList[row]
    return 0
End


Function LJZ_CTP2_RefreshImageList()
    LJZ_CTP2_EnsureDF()

    String gName
    gName = LJZ_CTP2_GetGraphName(0)

    Wave/T ImgList = $(LJZ_CTP2_BaseDF() + ":ImgList")
    Wave ImgSel = $(LJZ_CTP2_BaseDF() + ":ImgSel")
    SVAR ExistingImageName = $(LJZ_CTP2_BaseDF() + ":ExistingImageName")
    NVAR SelImageRow = $(LJZ_CTP2_BaseDF() + ":SelImageRow")

    String imgs
    imgs = ""

    if (strlen(gName) > 0)
        imgs = ImageNameList(gName, ";")
    endif

    Variable n
    n = ItemsInList(imgs, ";")

    Redimension/N=(n) ImgList
    Redimension/N=(n) ImgSel
    ImgSel = 0

    Variable i
    for (i = 0; i < n; i += 1)
        ImgList[i] = StringFromList(i, imgs, ";")
    endfor

    Variable keepRow
    keepRow = -1

    if (strlen(ExistingImageName) > 0)
        for (i = 0; i < n; i += 1)
            if (CmpStr(ExistingImageName, ImgList[i]) == 0)
                keepRow = i
            endif
        endfor
    endif

    if (keepRow < 0 && n > 0)
        keepRow = 0
    endif

    LJZ_CTP2_SetSelectedImage(keepRow)

    String pName
    pName = LJZ_CTP2_PanelName()

    if (WinType(pName) != 0)
        ListBox/Z lbImages, win=$pName, selRow=SelImageRow
        ControlUpdate/A/W=$pName
    endif

    Print "LJZ_CTP2 graph = " + gName
    Print "LJZ_CTP2 images = " + imgs
    return 0
End


// ============================================================================
//  Section 2. CTLIB palette library
// ============================================================================

Function LJZ_CTP2_IsValidCTWave(w)
    Wave/Z w

    if (!WaveExists(w))
        return 0
    endif

    if (WaveType(w, 1) != 1)
        return 0
    endif

    if (DimSize(w, 0) <= 0)
        return 0
    endif

    if (DimSize(w, 1) < 3)
        return 0
    endif

    if (DimSize(w, 2) > 0 || DimSize(w, 3) > 0)
        return 0
    endif

    return 1
End


Function LJZ_CTP2_RefreshLibraryList()
    LJZ_CTP2_EnsureCTLIB()

    SVAR/Z LibraryMenuList = $(LJZ_CTP2_BaseDF() + ":LibraryMenuList")
    if (!SVAR_Exists(LibraryMenuList))
        String/G $(LJZ_CTP2_BaseDF() + ":LibraryMenuList") = ""
    endif

    SVAR/Z LibraryCTName = $(LJZ_CTP2_BaseDF() + ":LibraryCTName")
    if (!SVAR_Exists(LibraryCTName))
        String/G $(LJZ_CTP2_BaseDF() + ":LibraryCTName") = "Mualani"
    endif

    SVAR menuRef = $(LJZ_CTP2_BaseDF() + ":LibraryMenuList")
    SVAR pickRef = $(LJZ_CTP2_BaseDF() + ":LibraryCTName")

    String preferredList
    preferredList = ""

    SVAR/Z personalList = root:ARPES_LJZ:CTLUZ:ctlib_menu_list
    if (SVAR_Exists(personalList))
        preferredList = personalList
    endif

    String out
    out = ""

    Variable i
    Variable n
    String nm

    n = ItemsInList(preferredList, ";")
    for (i = 0; i < n; i += 1)
        nm = StringFromList(i, preferredList, ";")
        if (strlen(nm) == 0)
            continue
        endif

        Wave/Z wPref = $("root:ARPES_LJZ:CTLUZ:CTLIB:" + nm)
        if (!LJZ_CTP2_IsValidCTWave(wPref))
            continue
        endif

        if (WhichListItem(nm, out, ";", 0, 0) < 0)
            out += nm + ";"
        endif
    endfor

    String oldDF
    oldDF = GetDataFolder(1)

    SetDataFolder root:ARPES_LJZ:CTLUZ:CTLIB
    String wl
    wl = WaveList("*", ";", "")
    SetDataFolder oldDF

    n = ItemsInList(wl, ";")
    for (i = 0; i < n; i += 1)
        nm = StringFromList(i, wl, ";")
        if (strlen(nm) == 0)
            continue
        endif

        Wave/Z w = $("root:ARPES_LJZ:CTLUZ:CTLIB:" + nm)
        if (!LJZ_CTP2_IsValidCTWave(w))
            continue
        endif

        if (WhichListItem(nm, out, ";", 0, 0) < 0)
            out += nm + ";"
        endif
    endfor

    if (strlen(out) == 0)
        out = "Mualani;Gray;CyanHot;"
    endif

    menuRef = out

    if (WhichListItem(pickRef, menuRef, ";", 0, 0) < 0)
        pickRef = StringFromList(0, menuRef, ";")
    endif

    LJZ_CTP2_RebuildLibraryListWaves()

    return 0
End


Function/S LJZ_CTP2_CTLIBPopupList()
    LJZ_CTP2_RefreshLibraryList()
    SVAR LibraryMenuList = $(LJZ_CTP2_BaseDF() + ":LibraryMenuList")
    return LibraryMenuList
End


Function LJZ_CTP2_ChannelTo255(v)
    Variable v

    if (numtype(v) != 0)
        return 0
    endif

    if (v > 255)
        v = v / 257
    endif

    v = LJZ_CTP2_Clamp(v, 0, 255)
    return round(v)
End


Function LJZ_CTP2_RGB255ToU16(v)
    Variable v

    v = LJZ_CTP2_Clamp(v, 0, 255)
    return round(v * 257)
End


Function/S LJZ_CTP2_GetSelectedLibraryPath()
    LJZ_CTP2_EnsureDF()
    SVAR LibraryCTName = $(LJZ_CTP2_BaseDF() + ":LibraryCTName")
    if (strlen(LibraryCTName) == 0)
        return ""
    endif
    return LJZ_CTP2_CTLIB_DF_Colon() + LibraryCTName
End


Function LJZ_CTP2_LoadLibraryToCustom5()
    LJZ_CTP2_EnsureDF()

    String ctPath
    ctPath = LJZ_CTP2_GetSelectedLibraryPath()

    if (strlen(ctPath) == 0)
        DoAlert 0, "No CTLIB palette selected."
        return -1
    endif

    Wave/Z ct = $ctPath
    if (!LJZ_CTP2_IsValidCTWave(ct))
        DoAlert 0, "Selected CTLIB palette is not a valid N x 3 color-table wave."
        return -1
    endif

    NVAR p0 = $(LJZ_CTP2_BaseDF() + ":p0")
    NVAR p1 = $(LJZ_CTP2_BaseDF() + ":p1")
    NVAR p2 = $(LJZ_CTP2_BaseDF() + ":p2")
    NVAR p3 = $(LJZ_CTP2_BaseDF() + ":p3")
    NVAR p4 = $(LJZ_CTP2_BaseDF() + ":p4")

    NVAR r0 = $(LJZ_CTP2_BaseDF() + ":r0")
    NVAR g0 = $(LJZ_CTP2_BaseDF() + ":g0")
    NVAR b0 = $(LJZ_CTP2_BaseDF() + ":b0")

    NVAR r1 = $(LJZ_CTP2_BaseDF() + ":r1")
    NVAR g1 = $(LJZ_CTP2_BaseDF() + ":g1")
    NVAR b1 = $(LJZ_CTP2_BaseDF() + ":b1")

    NVAR r2 = $(LJZ_CTP2_BaseDF() + ":r2")
    NVAR g2 = $(LJZ_CTP2_BaseDF() + ":g2")
    NVAR b2 = $(LJZ_CTP2_BaseDF() + ":b2")

    NVAR r3 = $(LJZ_CTP2_BaseDF() + ":r3")
    NVAR g3 = $(LJZ_CTP2_BaseDF() + ":g3")
    NVAR b3 = $(LJZ_CTP2_BaseDF() + ":b3")

    NVAR r4 = $(LJZ_CTP2_BaseDF() + ":r4")
    NVAR g4 = $(LJZ_CTP2_BaseDF() + ":g4")
    NVAR b4 = $(LJZ_CTP2_BaseDF() + ":b4")

    Variable n
    Variable idx0
    Variable idx1
    Variable idx2
    Variable idx3
    Variable idx4

    n = DimSize(ct, 0)
    idx0 = 0
    idx1 = round(0.25 * (n - 1))
    idx2 = round(0.50 * (n - 1))
    idx3 = round(0.75 * (n - 1))
    idx4 = n - 1

    p0 = 0
    p1 = 0.25
    p2 = 0.50
    p3 = 0.75
    p4 = 1

    r0 = LJZ_CTP2_ChannelTo255(ct[idx0][0])
    g0 = LJZ_CTP2_ChannelTo255(ct[idx0][1])
    b0 = LJZ_CTP2_ChannelTo255(ct[idx0][2])

    r1 = LJZ_CTP2_ChannelTo255(ct[idx1][0])
    g1 = LJZ_CTP2_ChannelTo255(ct[idx1][1])
    b1 = LJZ_CTP2_ChannelTo255(ct[idx1][2])

    r2 = LJZ_CTP2_ChannelTo255(ct[idx2][0])
    g2 = LJZ_CTP2_ChannelTo255(ct[idx2][1])
    b2 = LJZ_CTP2_ChannelTo255(ct[idx2][2])

    r3 = LJZ_CTP2_ChannelTo255(ct[idx3][0])
    g3 = LJZ_CTP2_ChannelTo255(ct[idx3][1])
    b3 = LJZ_CTP2_ChannelTo255(ct[idx3][2])

    r4 = LJZ_CTP2_ChannelTo255(ct[idx4][0])
    g4 = LJZ_CTP2_ChannelTo255(ct[idx4][1])
    b4 = LJZ_CTP2_ChannelTo255(ct[idx4][2])

    LJZ_CTP2_UpdatePreviewCustom()

    String pName
    pName = LJZ_CTP2_PanelName()
    if (WinType(pName) != 0)
        ControlUpdate/A/W=$pName
    endif

    return 0
End


Function LJZ_CTP2_SaveCustom5ToLibrary()
    LJZ_CTP2_EnsureDF()
    LJZ_CTP2_BuildCustomCT()

    SVAR SaveCustomName = $(LJZ_CTP2_BaseDF() + ":SaveCustomName")
    SVAR LibraryCTName = $(LJZ_CTP2_BaseDF() + ":LibraryCTName")

    String nm
    nm = CleanupName(SaveCustomName, 0)

    if (strlen(nm) == 0)
        DoAlert 0, "Please enter a valid SaveName for the CTLIB palette."
        return -1
    endif

    Wave/W/U custom = $(LJZ_CTP2_BaseDF() + ":CustomCT")
    Duplicate/O custom, $(LJZ_CTP2_CTLIB_DF_Colon() + nm)

    SaveCustomName = nm
    LibraryCTName = nm

    LJZ_CTP2_RefreshLibraryList()

    String pName
    pName = LJZ_CTP2_PanelName()
    if (WinType(pName) != 0)
        ListBox/Z lbLibCT, win=$pName
        ControlUpdate/A/W=$pName
    endif

    Print "LJZ_CTP2 saved Custom5 to CTLIB: " + LJZ_CTP2_CTLIB_DF_Colon() + nm
    return 0
End


// ============================================================================
//  Section 3. Custom 5 construction and swap
// ============================================================================

Function LJZ_CTP2_SanitizeCustomParams()
    LJZ_CTP2_EnsureDF()

    NVAR p0 = $(LJZ_CTP2_BaseDF() + ":p0")
    NVAR p1 = $(LJZ_CTP2_BaseDF() + ":p1")
    NVAR p2 = $(LJZ_CTP2_BaseDF() + ":p2")
    NVAR p3 = $(LJZ_CTP2_BaseDF() + ":p3")
    NVAR p4 = $(LJZ_CTP2_BaseDF() + ":p4")

    NVAR r0 = $(LJZ_CTP2_BaseDF() + ":r0")
    NVAR g0 = $(LJZ_CTP2_BaseDF() + ":g0")
    NVAR b0 = $(LJZ_CTP2_BaseDF() + ":b0")

    NVAR r1 = $(LJZ_CTP2_BaseDF() + ":r1")
    NVAR g1 = $(LJZ_CTP2_BaseDF() + ":g1")
    NVAR b1 = $(LJZ_CTP2_BaseDF() + ":b1")

    NVAR r2 = $(LJZ_CTP2_BaseDF() + ":r2")
    NVAR g2 = $(LJZ_CTP2_BaseDF() + ":g2")
    NVAR b2 = $(LJZ_CTP2_BaseDF() + ":b2")

    NVAR r3 = $(LJZ_CTP2_BaseDF() + ":r3")
    NVAR g3 = $(LJZ_CTP2_BaseDF() + ":g3")
    NVAR b3 = $(LJZ_CTP2_BaseDF() + ":b3")

    NVAR r4 = $(LJZ_CTP2_BaseDF() + ":r4")
    NVAR g4 = $(LJZ_CTP2_BaseDF() + ":g4")
    NVAR b4 = $(LJZ_CTP2_BaseDF() + ":b4")

    p0 = 0
    p4 = 1

    p1 = LJZ_CTP2_Clamp(p1, 0.001, 0.999)
    p2 = LJZ_CTP2_Clamp(p2, 0.001, 0.999)
    p3 = LJZ_CTP2_Clamp(p3, 0.001, 0.999)

    if (p2 <= p1)
        p2 = p1 + 0.001
    endif

    if (p3 <= p2)
        p3 = p2 + 0.001
    endif

    if (p3 >= 1)
        p3 = 0.999
    endif

    r0 = LJZ_CTP2_Clamp(r0, 0, 255)
    g0 = LJZ_CTP2_Clamp(g0, 0, 255)
    b0 = LJZ_CTP2_Clamp(b0, 0, 255)

    r1 = LJZ_CTP2_Clamp(r1, 0, 255)
    g1 = LJZ_CTP2_Clamp(g1, 0, 255)
    b1 = LJZ_CTP2_Clamp(b1, 0, 255)

    r2 = LJZ_CTP2_Clamp(r2, 0, 255)
    g2 = LJZ_CTP2_Clamp(g2, 0, 255)
    b2 = LJZ_CTP2_Clamp(b2, 0, 255)

    r3 = LJZ_CTP2_Clamp(r3, 0, 255)
    g3 = LJZ_CTP2_Clamp(g3, 0, 255)
    b3 = LJZ_CTP2_Clamp(b3, 0, 255)

    r4 = LJZ_CTP2_Clamp(r4, 0, 255)
    g4 = LJZ_CTP2_Clamp(g4, 0, 255)
    b4 = LJZ_CTP2_Clamp(b4, 0, 255)

    return 0
End


Function LJZ_CTP2_Interp(v0, v1, f)
    Variable v0
    Variable v1
    Variable f

    return v0 + (v1 - v0) * f
End


Function LJZ_CTP2_BuildCustomCT()
    LJZ_CTP2_SanitizeCustomParams()

    NVAR p0 = $(LJZ_CTP2_BaseDF() + ":p0")
    NVAR p1 = $(LJZ_CTP2_BaseDF() + ":p1")
    NVAR p2 = $(LJZ_CTP2_BaseDF() + ":p2")
    NVAR p3 = $(LJZ_CTP2_BaseDF() + ":p3")
    NVAR p4 = $(LJZ_CTP2_BaseDF() + ":p4")

    NVAR r0 = $(LJZ_CTP2_BaseDF() + ":r0")
    NVAR g0 = $(LJZ_CTP2_BaseDF() + ":g0")
    NVAR b0 = $(LJZ_CTP2_BaseDF() + ":b0")

    NVAR r1 = $(LJZ_CTP2_BaseDF() + ":r1")
    NVAR g1 = $(LJZ_CTP2_BaseDF() + ":g1")
    NVAR b1 = $(LJZ_CTP2_BaseDF() + ":b1")

    NVAR r2 = $(LJZ_CTP2_BaseDF() + ":r2")
    NVAR g2 = $(LJZ_CTP2_BaseDF() + ":g2")
    NVAR b2 = $(LJZ_CTP2_BaseDF() + ":b2")

    NVAR r3 = $(LJZ_CTP2_BaseDF() + ":r3")
    NVAR g3 = $(LJZ_CTP2_BaseDF() + ":g3")
    NVAR b3 = $(LJZ_CTP2_BaseDF() + ":b3")

    NVAR r4 = $(LJZ_CTP2_BaseDF() + ":r4")
    NVAR g4 = $(LJZ_CTP2_BaseDF() + ":g4")
    NVAR b4 = $(LJZ_CTP2_BaseDF() + ":b4")

    Wave/W/U ct = $(LJZ_CTP2_BaseDF() + ":CustomCT")

    Variable n
    n = DimSize(ct, 0)

    if (n <= 1)
        Redimension/W/U/N=(256,3) ct
        n = 256
    endif

    Variable i
    Variable t
    Variable f
    Variable rr
    Variable gg
    Variable bb

    for (i = 0; i < n; i += 1)
        t = i / (n - 1)

        if (t <= p1)
            f = (t - p0) / (p1 - p0)
            rr = LJZ_CTP2_Interp(r0, r1, f)
            gg = LJZ_CTP2_Interp(g0, g1, f)
            bb = LJZ_CTP2_Interp(b0, b1, f)
        elseif (t <= p2)
            f = (t - p1) / (p2 - p1)
            rr = LJZ_CTP2_Interp(r1, r2, f)
            gg = LJZ_CTP2_Interp(g1, g2, f)
            bb = LJZ_CTP2_Interp(b1, b2, f)
        elseif (t <= p3)
            f = (t - p2) / (p3 - p2)
            rr = LJZ_CTP2_Interp(r2, r3, f)
            gg = LJZ_CTP2_Interp(g2, g3, f)
            bb = LJZ_CTP2_Interp(b2, b3, f)
        else
            f = (t - p3) / (p4 - p3)
            rr = LJZ_CTP2_Interp(r3, r4, f)
            gg = LJZ_CTP2_Interp(g3, g4, f)
            bb = LJZ_CTP2_Interp(b3, b4, f)
        endif

        ct[i][0] = LJZ_CTP2_RGB255ToU16(rr)
        ct[i][1] = LJZ_CTP2_RGB255ToU16(gg)
        ct[i][2] = LJZ_CTP2_RGB255ToU16(bb)
    endfor

    return 0
End


Function LJZ_CTP2_SwapTwoAnchorColors()
    LJZ_CTP2_EnsureDF()

    NVAR SwapA = $(LJZ_CTP2_BaseDF() + ":SwapA")
    NVAR SwapB = $(LJZ_CTP2_BaseDF() + ":SwapB")

    Variable ia
    Variable ib

    ia = round(SwapA)
    ib = round(SwapB)

    ia = LJZ_CTP2_Clamp(ia, 0, 4)
    ib = LJZ_CTP2_Clamp(ib, 0, 4)

    SwapA = ia
    SwapB = ib

    if (ia == ib)
        DoAlert 0, "Swap A and Swap B are the same anchor."
        return 0
    endif

    NVAR rA = $(LJZ_CTP2_BaseDF() + ":r" + num2str(ia))
    NVAR gA = $(LJZ_CTP2_BaseDF() + ":g" + num2str(ia))
    NVAR bA = $(LJZ_CTP2_BaseDF() + ":b" + num2str(ia))

    NVAR rB = $(LJZ_CTP2_BaseDF() + ":r" + num2str(ib))
    NVAR gB = $(LJZ_CTP2_BaseDF() + ":g" + num2str(ib))
    NVAR bB = $(LJZ_CTP2_BaseDF() + ":b" + num2str(ib))

    Variable tr
    Variable tg
    Variable tb

    tr = rA
    tg = gA
    tb = bA

    rA = rB
    gA = gB
    bA = bB

    rB = tr
    gB = tg
    bB = tb

    LJZ_CTP2_UpdatePreviewCustom()

    String pName
    pName = LJZ_CTP2_PanelName()
    if (WinType(pName) != 0)
        ControlUpdate/A/W=$pName
    endif

    return 0
End


// ============================================================================
//  Section 4. Applying color tables
// ============================================================================

Function LJZ_CTP2_ApplyBuiltInToImage(gName, imgName)
    String gName
    String imgName

    LJZ_CTP2_EnsureDF()

    SVAR BuiltinCTName = $(LJZ_CTP2_BaseDF() + ":BuiltinCTName")
    NVAR ReverseCT = $(LJZ_CTP2_BaseDF() + ":ReverseCT")
    NVAR UseManualRange = $(LJZ_CTP2_BaseDF() + ":UseManualRange")
    NVAR CMin = $(LJZ_CTP2_BaseDF() + ":CMin")
    NVAR CMax = $(LJZ_CTP2_BaseDF() + ":CMax")

    Variable rev
    rev = round(ReverseCT)

    String ctName
    ctName = BuiltinCTName

    if (strlen(gName) == 0 || strlen(imgName) == 0)
        return -1
    endif

    if (strlen(ctName) == 0)
        ctName = "Grays"
        BuiltinCTName = ctName
    endif

    if (UseManualRange)
        if (CMax == CMin)
            DoAlert 0, "CMax equals CMin. Manual color range was not applied."
            return -1
        endif
        ModifyImage/W=$gName $imgName ctab={CMin,CMax,$ctName,rev}
    else
        ModifyImage/W=$gName $imgName ctab={*,*,$ctName,rev}
    endif

    return 0
End


Function LJZ_CTP2_ApplyLibraryToImage(gName, imgName)
    String gName
    String imgName

    LJZ_CTP2_EnsureDF()

    String ctPath
    ctPath = LJZ_CTP2_GetSelectedLibraryPath()

    if (strlen(gName) == 0 || strlen(imgName) == 0 || strlen(ctPath) == 0)
        return -1
    endif

    Wave/Z ct = $ctPath
    if (!LJZ_CTP2_IsValidCTWave(ct))
        DoAlert 0, "Selected CTLIB palette is not a valid N x 3 color-table wave."
        return -1
    endif

    NVAR ReverseCT = $(LJZ_CTP2_BaseDF() + ":ReverseCT")
    NVAR UseManualRange = $(LJZ_CTP2_BaseDF() + ":UseManualRange")
    NVAR CMin = $(LJZ_CTP2_BaseDF() + ":CMin")
    NVAR CMax = $(LJZ_CTP2_BaseDF() + ":CMax")

    Variable rev
    rev = round(ReverseCT)

    if (UseManualRange)
        if (CMax == CMin)
            DoAlert 0, "CMax equals CMin. Manual color range was not applied."
            return -1
        endif
        ModifyImage/W=$gName $imgName ctab={CMin,CMax,ct,rev}
    else
        ModifyImage/W=$gName $imgName ctab={*,*,ct,rev}
    endif

    return 0
End


Function LJZ_CTP2_ApplyCustomToImage(gName, imgName)
    String gName
    String imgName

    LJZ_CTP2_EnsureDF()
    LJZ_CTP2_BuildCustomCT()

    Wave/W/U ct = $(LJZ_CTP2_BaseDF() + ":CustomCT")

    NVAR ReverseCT = $(LJZ_CTP2_BaseDF() + ":ReverseCT")
    NVAR UseManualRange = $(LJZ_CTP2_BaseDF() + ":UseManualRange")
    NVAR CMin = $(LJZ_CTP2_BaseDF() + ":CMin")
    NVAR CMax = $(LJZ_CTP2_BaseDF() + ":CMax")

    Variable rev
    rev = round(ReverseCT)

    if (strlen(gName) == 0 || strlen(imgName) == 0)
        return -1
    endif

    if (UseManualRange)
        if (CMax == CMin)
            DoAlert 0, "CMax equals CMin. Manual color range was not applied."
            return -1
        endif
        ModifyImage/W=$gName $imgName ctab={CMin,CMax,ct,rev}
    else
        ModifyImage/W=$gName $imgName ctab={*,*,ct,rev}
    endif

    return 0
End


Function LJZ_CTP2_ResetImageToGrays(gName, imgName)
    String gName
    String imgName

    if (strlen(gName) == 0 || strlen(imgName) == 0)
        return -1
    endif

    ModifyImage/W=$gName $imgName ctab={*,*,Grays,0}
    return 0
End


Function LJZ_CTP2_ComputeImageRobustRange(gName, imgName, lowPct, highPct, cminOut, cmaxOut)
    String gName
    String imgName
    Variable lowPct
    Variable highPct
    Variable &cminOut
    Variable &cmaxOut

    if (strlen(gName) == 0 || strlen(imgName) == 0)
        return -1
    endif

    Wave/Z img = ImageNameToWaveRef(gName, imgName)
    if (!WaveExists(img))
        return -2
    endif

    if (WaveDims(img) != 2)
        return -3
    endif

    Variable nx
    Variable ny
    nx = DimSize(img, 0)
    ny = DimSize(img, 1)

    if (nx <= 0 || ny <= 0)
        return -4
    endif

    lowPct = LJZ_CTP2_Clamp(lowPct, 0, 100)
    highPct = LJZ_CTP2_Clamp(highPct, 0, 100)
    if (highPct <= lowPct)
        return -5
    endif

    Make/FREE/D/N=(nx * ny) validVals

    Variable i
    Variable j
    Variable k
    Variable v
    k = 0

    for (j = 0; j < ny; j += 1)
        for (i = 0; i < nx; i += 1)
            v = img[i][j]
            if (numtype(v) == 0)
                validVals[k] = v
                k += 1
            endif
        endfor
    endfor

    if (k < 2)
        return -6
    endif

    Redimension/N=(k) validVals
    Sort validVals, validVals

    Variable posLo
    Variable posHi
    Variable idxLo
    Variable idxHi
    Variable fracLo
    Variable fracHi

    posLo = (lowPct / 100) * (k - 1)
    posHi = (highPct / 100) * (k - 1)

    idxLo = floor(posLo)
    idxHi = floor(posHi)
    fracLo = posLo - idxLo
    fracHi = posHi - idxHi

    if (idxLo >= k - 1)
        cminOut = validVals[k - 1]
    else
        cminOut = validVals[idxLo] + fracLo * (validVals[idxLo + 1] - validVals[idxLo])
    endif

    if (idxHi >= k - 1)
        cmaxOut = validVals[k - 1]
    else
        cmaxOut = validVals[idxHi] + fracHi * (validVals[idxHi + 1] - validVals[idxHi])
    endif

    if (numtype(cminOut) != 0 || numtype(cmaxOut) != 0 || cmaxOut <= cminOut)
        return -7
    endif

    return 0
End


Function LJZ_CTP2_ApplyWhiteFloorToSelected()
    LJZ_CTP2_EnsureDF()

    String gName
    gName = LJZ_CTP2_GetGraphName(0)

    SVAR ExistingImageName = $(LJZ_CTP2_BaseDF() + ":ExistingImageName")
    SVAR LibraryCTName = $(LJZ_CTP2_BaseDF() + ":LibraryCTName")
    NVAR UseManualRange = $(LJZ_CTP2_BaseDF() + ":UseManualRange")
    NVAR CMin = $(LJZ_CTP2_BaseDF() + ":CMin")
    NVAR CMax = $(LJZ_CTP2_BaseDF() + ":CMax")

    if (strlen(gName) == 0 || strlen(ExistingImageName) == 0)
        DoAlert 0, "No graph or image selected."
        return -1
    endif

    LibraryCTName = "WhiteBlue"
    UseManualRange = 1

    if (numtype(CMin) != 0 || numtype(CMax) != 0 || CMax <= CMin)
        Variable autoMin
        Variable autoMax
        Variable rc

        rc = LJZ_CTP2_ComputeImageRobustRange(gName, ExistingImageName, 8, 99.5, autoMin, autoMax)
        if (rc < 0)
            DoAlert 0, "Could not estimate a robust white-floor color range from the selected image. Please set CMin/CMax manually, then click Apply White Floor again."
            return rc
        endif

        CMin = autoMin
        CMax = autoMax
    endif

    LJZ_CTP2_RefreshLibraryList()
    LJZ_CTP2_ApplyLibraryToImage(gName, ExistingImageName)
    DoWindow/F $gName

    String pName
    pName = LJZ_CTP2_PanelName()
    if (WinType(pName) != 0)
        ListBox/Z lbLibCT, win=$pName
        ControlUpdate/A/W=$pName
    endif

    return 0
End

Function LJZ_CTP2_AddColorbarToSelected()
    LJZ_CTP2_EnsureDF()

    String gName
    gName = LJZ_CTP2_GetGraphName(0)

    SVAR ExistingImageName = $(LJZ_CTP2_BaseDF() + ":ExistingImageName")

    if (strlen(gName) == 0 || strlen(ExistingImageName) == 0)
        DoAlert 0, "No graph or image selected."
        return -1
    endif

    String csName
    csName = "ljz_ctp2_colorbar"

    // If this colorbar already exists, update it.
    // Otherwise create it.
    String annList
    annList = AnnotationList(gName)

    if (WhichListItem(csName, annList, ";", 0, 0) >= 0)
        ColorScale/W=$gName/C/N=$csName/A=RT/X=2/Y=0 image=$ExistingImageName, heightPct=55, width=10, frame=0, fsize=9, "Intensity"
    else
        ColorScale/W=$gName/N=$csName/A=RT/X=2/Y=0 image=$ExistingImageName, heightPct=55, width=10, frame=0, fsize=9, "Intensity"
    endif

    DoWindow/F $gName
    return 0
End

Function LJZ_CTP2_ApplySelectedBuiltIn()
    LJZ_CTP2_EnsureDF()

    String gName
    gName = LJZ_CTP2_GetGraphName(0)

    SVAR ExistingImageName = $(LJZ_CTP2_BaseDF() + ":ExistingImageName")

    if (strlen(gName) == 0 || strlen(ExistingImageName) == 0)
        DoAlert 0, "No graph or image selected."
        return -1
    endif

    LJZ_CTP2_ApplyBuiltInToImage(gName, ExistingImageName)
    DoWindow/F $gName
    return 0
End


Function LJZ_CTP2_ApplySelectedLibrary()
    LJZ_CTP2_EnsureDF()

    String gName
    gName = LJZ_CTP2_GetGraphName(0)

    SVAR ExistingImageName = $(LJZ_CTP2_BaseDF() + ":ExistingImageName")

    if (strlen(gName) == 0 || strlen(ExistingImageName) == 0)
        DoAlert 0, "No graph or image selected."
        return -1
    endif

    LJZ_CTP2_ApplyLibraryToImage(gName, ExistingImageName)
    DoWindow/F $gName
    return 0
End


Function LJZ_CTP2_ApplySelectedCustom()
    LJZ_CTP2_EnsureDF()

    String gName
    gName = LJZ_CTP2_GetGraphName(0)

    SVAR ExistingImageName = $(LJZ_CTP2_BaseDF() + ":ExistingImageName")

    if (strlen(gName) == 0 || strlen(ExistingImageName) == 0)
        DoAlert 0, "No graph or image selected."
        return -1
    endif

    LJZ_CTP2_ApplyCustomToImage(gName, ExistingImageName)
    DoWindow/F $gName
    return 0
End


Function LJZ_CTP2_ResetSelected()
    LJZ_CTP2_EnsureDF()

    String gName
    gName = LJZ_CTP2_GetGraphName(0)

    SVAR ExistingImageName = $(LJZ_CTP2_BaseDF() + ":ExistingImageName")

    if (strlen(gName) == 0 || strlen(ExistingImageName) == 0)
        DoAlert 0, "No graph or image selected."
        return -1
    endif

    LJZ_CTP2_ResetImageToGrays(gName, ExistingImageName)
    DoWindow/F $gName
    return 0
End


Function LJZ_CTP2_ApplyAllBuiltIn()
    LJZ_CTP2_EnsureDF()

    NVAR ApplyToAllConfirm = $(LJZ_CTP2_BaseDF() + ":ApplyToAllConfirm")

    if (!ApplyToAllConfirm)
        DoAlert 0, "For safety, check Confirm all first."
        return -1
    endif

    String gName
    gName = LJZ_CTP2_GetGraphName(0)

    if (strlen(gName) == 0)
        DoAlert 0, "No graph found."
        return -1
    endif

    String imgs
    imgs = ImageNameList(gName, ";")

    Variable n
    n = ItemsInList(imgs, ";")

    Variable i
    String im

    for (i = 0; i < n; i += 1)
        im = StringFromList(i, imgs, ";")
        if (strlen(im) > 0)
            LJZ_CTP2_ApplyBuiltInToImage(gName, im)
        endif
    endfor

    DoWindow/F $gName
    return 0
End


Function LJZ_CTP2_ResetAll()
    LJZ_CTP2_EnsureDF()

    NVAR ApplyToAllConfirm = $(LJZ_CTP2_BaseDF() + ":ApplyToAllConfirm")

    if (!ApplyToAllConfirm)
        DoAlert 0, "For safety, check Confirm all first."
        return -1
    endif

    String gName
    gName = LJZ_CTP2_GetGraphName(0)

    if (strlen(gName) == 0)
        DoAlert 0, "No graph found."
        return -1
    endif

    String imgs
    imgs = ImageNameList(gName, ";")

    Variable n
    n = ItemsInList(imgs, ";")

    Variable i
    String im

    for (i = 0; i < n; i += 1)
        im = StringFromList(i, imgs, ";")
        if (strlen(im) > 0)
            LJZ_CTP2_ResetImageToGrays(gName, im)
        endif
    endfor

    DoWindow/F $gName
    return 0
End


// ============================================================================
//  Section 5. Preview
// ============================================================================

Function LJZ_CTP2_CreatePreviewGraph()
    LJZ_CTP2_EnsureDF()

    String pName
    pName = LJZ_CTP2_PanelName()

    if (WinType(pName) == 0)
        return -1
    endif

    String childName
    childName = LJZ_CTP2_PreviewGraphName()

    String graphPath
    graphPath = LJZ_CTP2_PreviewGraphPath()

    if (LJZ_CTP2_HasChildSubwindow(pName, childName))
        KillWindow/Z $graphPath
    endif

    Wave prev = $(LJZ_CTP2_BaseDF() + ":PreviewImage")

    // Child graph coords are relative to the panel content area.
    // Preview GroupBox: pos={290,44}, size={492,72}
    // Inset 6px on each side, 18px below group title.
    Display/HOST=$pName/N=$childName/W=(296,62,780,112)
    AppendImage/W=$graphPath prev

    ModifyGraph/W=$graphPath margin(left)=2,margin(bottom)=2,margin(right)=2,margin(top)=2
    ModifyGraph/W=$graphPath noLabel=2,axThick=0,standoff=0
    ModifyGraph/W=$graphPath width=0,height=0
    SetAxis/W=$graphPath bottom 0,255
    SetAxis/W=$graphPath left 0,1

    LJZ_CTP2_UpdatePreviewLibrary()
    return 0
End



Function LJZ_CTP2_UpdatePreviewBuiltIn()
    LJZ_CTP2_EnsureDF()

    String graphPath
    graphPath = LJZ_CTP2_PreviewGraphPath()

    if (WinType(graphPath) == 0)
        return -1
    endif

    SVAR BuiltinCTName = $(LJZ_CTP2_BaseDF() + ":BuiltinCTName")
    NVAR ReverseCT = $(LJZ_CTP2_BaseDF() + ":ReverseCT")

    Variable rev
    rev = round(ReverseCT)

    String ctName
    ctName = BuiltinCTName

    if (strlen(ctName) == 0)
        ctName = "Grays"
        BuiltinCTName = ctName
    endif

    ModifyImage/W=$graphPath PreviewImage ctab={*,*,$ctName,rev}
    return 0
End


Function LJZ_CTP2_UpdatePreviewLibrary()
    LJZ_CTP2_EnsureDF()

    String graphPath
    graphPath = LJZ_CTP2_PreviewGraphPath()

    if (WinType(graphPath) == 0)
        return -1
    endif

    String ctPath
    ctPath = LJZ_CTP2_GetSelectedLibraryPath()

    Wave/Z ct = $ctPath
    if (!LJZ_CTP2_IsValidCTWave(ct))
        return LJZ_CTP2_UpdatePreviewBuiltIn()
    endif

    NVAR ReverseCT = $(LJZ_CTP2_BaseDF() + ":ReverseCT")
    Variable rev
    rev = round(ReverseCT)

    ModifyImage/W=$graphPath PreviewImage ctab={*,*,ct,rev}
    return 0
End


Function LJZ_CTP2_UpdatePreviewCustom()
    LJZ_CTP2_EnsureDF()
    LJZ_CTP2_BuildCustomCT()

    String graphPath
    graphPath = LJZ_CTP2_PreviewGraphPath()

    if (WinType(graphPath) == 0)
        return -1
    endif

    Wave/W/U ct = $(LJZ_CTP2_BaseDF() + ":CustomCT")
    NVAR ReverseCT = $(LJZ_CTP2_BaseDF() + ":ReverseCT")

    Variable rev
    rev = round(ReverseCT)

    ModifyImage/W=$graphPath PreviewImage ctab={*,*,ct,rev}
    return 0
End


// ============================================================================
//  Section 6. Built-in/default CT fillers
// ============================================================================

Function LJZ_CTP2_FillGrayCT(ct)
    Wave/W/U ct

    Variable n
    Variable i
    Variable t

    n = DimSize(ct, 0)
    if (n <= 0)
        return -1
    endif

    for (i = 0; i < n; i += 1)
        if (n > 1)
            t = i / (n - 1)
        else
            t = 0
        endif

        ct[i][0] = round(t * 65535)
        ct[i][1] = round(t * 65535)
        ct[i][2] = round(t * 65535)
    endfor

    return 0
End


Function LJZ_CTP2_FillMualaniCT(ct)
    Wave/W/U ct

    Variable n
    Variable i
    Variable t
    Variable r
    Variable g
    Variable b

    n = DimSize(ct, 0)
    if (n <= 0)
        return -1
    endif

    for (i = 0; i < n; i += 1)
        if (n > 1)
            t = i / (n - 1)
        else
            t = 0
        endif

        if (t < 0.22)
            r = 0.02 + 0.02 * (t / 0.22)
            g = 0.02 + 0.18 * (t / 0.22)
            b = 0.05 + 0.75 * (t / 0.22)
        elseif (t < 0.48)
            r = 0.04 + 0.02 * ((t - 0.22) / 0.26)
            g = 0.20 + 0.70 * ((t - 0.22) / 0.26)
            b = 0.80 + 0.18 * ((t - 0.22) / 0.26)
        elseif (t < 0.72)
            r = 0.06 + 0.88 * ((t - 0.48) / 0.24)
            g = 0.90 + 0.08 * ((t - 0.48) / 0.24)
            b = 0.98 - 0.82 * ((t - 0.48) / 0.24)
        else
            r = 0.94 + 0.06 * ((t - 0.72) / 0.28)
            g = 0.98 + 0.02 * ((t - 0.72) / 0.28)
            b = 0.16 + 0.84 * ((t - 0.72) / 0.28)
        endif

        ct[i][0] = round(LJZ_CTP2_Clamp(r, 0, 1) * 65535)
        ct[i][1] = round(LJZ_CTP2_Clamp(g, 0, 1) * 65535)
        ct[i][2] = round(LJZ_CTP2_Clamp(b, 0, 1) * 65535)
    endfor

    return 0
End


Function LJZ_CTP2_FillCyanHotCT(ct)
    Wave/W/U ct

    Variable n
    Variable i
    Variable t
    Variable r
    Variable g
    Variable b

    n = DimSize(ct, 0)
    if (n <= 0)
        return -1
    endif

    for (i = 0; i < n; i += 1)
        if (n > 1)
            t = i / (n - 1)
        else
            t = 0
        endif

        r = min(1, max(0, 1.8 * t - 0.25))
        g = min(1, max(0, 2.0 * t))
        b = min(1, max(0, 1.3 - 1.2 * t))

        ct[i][0] = round(r * 65535)
        ct[i][1] = round(g * 65535)
        ct[i][2] = round(b * 65535)
    endfor

    return 0
End


Function LJZ_CTP2_FillWhiteBlueCT(ct)
    Wave/W/U ct

    Variable n
    Variable i
    Variable t
    Variable u
    Variable r
    Variable g
    Variable b

    n = DimSize(ct, 0)
    if (n <= 0)
        return -1
    endif

    for (i = 0; i < n; i += 1)
        if (n > 1)
            t = i / (n - 1)
        else
            t = 0
        endif

        if (t < 0.08)
            r = 1
            g = 1
            b = 1
        else
            u = (t - 0.08) / 0.92
            u = LJZ_CTP2_Clamp(u, 0, 1)

            // white -> deep blue
            r = 1.00 - 0.96 * u
            g = 1.00 - 0.78 * u
            b = 1.00 - 0.32 * u
        endif

        ct[i][0] = round(LJZ_CTP2_Clamp(r, 0, 1) * 65535)
        ct[i][1] = round(LJZ_CTP2_Clamp(g, 0, 1) * 65535)
        ct[i][2] = round(LJZ_CTP2_Clamp(b, 0, 1) * 65535)
    endfor

    return 0
End


Function LJZ_CTP2_FillWhiteGrayCT(ct)
    Wave/W/U ct

    Variable n
    Variable i
    Variable t
    Variable u
    Variable r
    Variable g
    Variable b

    n = DimSize(ct, 0)
    if (n <= 0)
        return -1
    endif

    for (i = 0; i < n; i += 1)
        if (n > 1)
            t = i / (n - 1)
        else
            t = 0
        endif

        if (t < 0.08)
            r = 1
            g = 1
            b = 1
        else
            u = (t - 0.08) / 0.92
            u = LJZ_CTP2_Clamp(u, 0, 1)

            // white -> dark gray / black
            r = 1.00 - 0.92 * u
            g = 1.00 - 0.92 * u
            b = 1.00 - 0.92 * u
        endif

        ct[i][0] = round(LJZ_CTP2_Clamp(r, 0, 1) * 65535)
        ct[i][1] = round(LJZ_CTP2_Clamp(g, 0, 1) * 65535)
        ct[i][2] = round(LJZ_CTP2_Clamp(b, 0, 1) * 65535)
    endfor

    return 0
End


// ============================================================================
//  Section 7. Callbacks
// ============================================================================

Function LJZ_CTP2_ListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if (lba.eventCode != 4)
        return 0
    endif

    LJZ_CTP2_SetSelectedImage(lba.row)

    String pName
    pName = LJZ_CTP2_PanelName()

    if (WinType(pName) != 0)
        ControlUpdate/A/W=$pName
    endif

    return 0
End


Function LJZ_CTP2_ButtonProc(ctrlName) : ButtonControl
    String ctrlName

    strswitch(ctrlName)
        case "btRefreshImages":
            LJZ_CTP2_RefreshImageList()
            break

        case "btRefreshLib":
            LJZ_CTP2_RefreshLibraryList()
            ControlUpdate/A/W=$(LJZ_CTP2_PanelName())
            break

        case "btPreviewBuiltin":
            LJZ_CTP2_UpdatePreviewBuiltIn()
            break

        case "btPreviewLib":
            LJZ_CTP2_UpdatePreviewLibrary()
            break

        case "btPreviewCustom":
            LJZ_CTP2_UpdatePreviewCustom()
            break

        case "btApplyBuiltIn":
            LJZ_CTP2_ApplySelectedBuiltIn()
            break

        case "btApplyLib":
            LJZ_CTP2_ApplySelectedLibrary()
            break

        case "btApplyWhiteFloor":
            LJZ_CTP2_ApplyWhiteFloorToSelected()
            break

        case "btApplyCustom":
            LJZ_CTP2_ApplySelectedCustom()
            break
            
        case "btAddColorbar":
            LJZ_CTP2_AddColorbarToSelected()
            break
            
        case "btLoadLibToCustom":
            LJZ_CTP2_LoadLibraryToCustom5()
            break

        case "btSaveCustomToLib":
            LJZ_CTP2_SaveCustom5ToLibrary()
            break

        case "btSwapCustom":
            LJZ_CTP2_SwapTwoAnchorColors()
            break

        case "btResetSelected":
            LJZ_CTP2_ResetSelected()
            break

        case "btApplyAllBuiltIn":
            LJZ_CTP2_ApplyAllBuiltIn()
            break

        case "btResetAll":
            LJZ_CTP2_ResetAll()
            break

        case "btClose":
            DoWindow/K $(LJZ_CTP2_PanelName())
            break
    endswitch

    return 0
End


Function LJZ_CTP2_PopupProc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName
    Variable popNum
    String popStr

    if (CmpStr(ctrlName, "pmBuiltInCT") == 0)
        SVAR BuiltinCTName = $(LJZ_CTP2_BaseDF() + ":BuiltinCTName")
        BuiltinCTName = popStr
        LJZ_CTP2_UpdatePreviewBuiltIn()
    endif

    if (CmpStr(ctrlName, "pmLibCT") == 0)
        SVAR LibraryCTName = $(LJZ_CTP2_BaseDF() + ":LibraryCTName")
        LibraryCTName = popStr
        LJZ_CTP2_UpdatePreviewLibrary()
    endif

    return 0
End


Function LJZ_CTP2_CheckProc(ctrlName, checked) : CheckBoxControl
    String ctrlName
    Variable checked

    if (CmpStr(ctrlName, "ckReverse") == 0)
        LJZ_CTP2_UpdatePreviewLibrary()
    endif

    return 0
End


Function LJZ_CTP2_SetVarProc(ctrlName, varNum, varStr, varName) : SetVariableControl
    String ctrlName
    Variable varNum
    String varStr
    String varName

    if (CmpStr(ctrlName, "svGraph") == 0)
        LJZ_CTP2_RefreshImageList()
    elseif (CmpStr(ctrlName, "svCMin") == 0)
        // no automatic graph apply
    elseif (CmpStr(ctrlName, "svCMax") == 0)
        // no automatic graph apply
    elseif (CmpStr(ctrlName, "svSaveName") == 0)
        // save name only
    else
        LJZ_CTP2_UpdatePreviewCustom()
    endif

    return 0
End


// ============================================================================
//  Section 8. Panel
// ============================================================================


Function LJZ_CTP2_OpenPanel()
    LJZ_CTP2_EnsureDF()

    String pName
    pName = LJZ_CTP2_PanelName()

    DoWindow/F $pName
    if (V_flag)
        LJZ_CTP2_RefreshImageList()
        LJZ_CTP2_RefreshLibraryList()
        LJZ_CTP2_CreatePreviewGraph()
        return 0
    endif

    // ---- outer window: 796 wide x 594 tall ----
    NewPanel/N=$pName /W=(80,70,876,570) as "LJZ ColorTable Panel v2.2"
    ModifyPanel frameStyle=1
    ModifyPanel cbRGB=(60000,60000,60000)
    ModifyPanel fixedSize=1

    // ---- header ----
    TitleBox tbTitle,pos={10,8},size={260,16},title="LJZ ColorTable Panel v2.2",frame=0
    TitleBox tbTitle,font="Arial",fSize=12,fStyle=1
    TitleBox tbHint,pos={10,28},size={760,14},frame=0
    TitleBox tbHint,title="Select image -> preview palette -> apply.   CTLIB = root:ARPES_LJZ:CTLUZ:CTLIB:"
    TitleBox tbHint,font="Arial",fSize=9

    // ========================================================
    //  LEFT COLUMN   x 10-282
    // ========================================================

    // ---- 1. Graph / selected image  (y 44-208) ----
    GroupBox gbGraph,pos={10,44},size={272,164},title="1. Graph / selected image"
    GroupBox gbGraph,font="Arial",fSize=10,fStyle=1

    SetVariable svGraph,pos={24,66},size={240,20},title="Graph"
    SetVariable svGraph,value=$(LJZ_CTP2_BaseDF() + ":GraphName"),proc=LJZ_CTP2_SetVarProc,bodyWidth=192

    Button btRefreshImages,pos={24,92},size={118,22},title="Refresh images",proc=LJZ_CTP2_ButtonProc

    SetVariable svSelected,pos={24,120},size={240,18},title="Selected"
    SetVariable svSelected,value=$(LJZ_CTP2_BaseDF() + ":ExistingImageName"),bodyWidth=184

    ListBox lbImages,pos={24,144},size={240,52},listWave=$(LJZ_CTP2_BaseDF() + ":ImgList")
    ListBox lbImages,selWave=$(LJZ_CTP2_BaseDF() + ":ImgSel"),mode=1,proc=LJZ_CTP2_ListBoxProc

    // ---- 2. Your CTLIB palettes  (y 214-370) ----
    GroupBox gbLib,pos={10,214},size={272,156},title="2. Your CTLIB palettes"
    GroupBox gbLib,font="Arial",fSize=10,fStyle=1

    ListBox lbLibCT,pos={24,234},size={240,72},listWave=$(LJZ_CTP2_BaseDF() + ":LibList")
    ListBox lbLibCT,selWave=$(LJZ_CTP2_BaseDF() + ":LibSel"),mode=1,proc=LJZ_CTP2_LibListBoxProc

    Button btRefreshLib,pos={24,312},size={56,22},title="Refresh",proc=LJZ_CTP2_ButtonProc
    Button btPreviewLib,pos={86,312},size={56,22},title="Preview",proc=LJZ_CTP2_ButtonProc
    Button btApplyLib,pos={148,312},size={56,22},title="Apply",proc=LJZ_CTP2_ButtonProc

    Button btLoadLibToCustom,pos={24,340},size={126,22},title="Load to Custom5",proc=LJZ_CTP2_ButtonProc
    TitleBox tbLibNote,pos={158,344},size={108,14},title="non-destructive",frame=0
    TitleBox tbLibNote,font="Arial",fSize=9

    // ========================================================
    //  RIGHT COLUMN   x 290-782
    // ========================================================

    // ---- Preview strip  (y 44-116) ----
    GroupBox gbPreview,pos={290,44},size={492,72},title="Preview"
    GroupBox gbPreview,font="Arial",fSize=10,fStyle=1

    // child subwindow – see LJZ_CTP2_CreatePreviewGraph()
    // W=(296,62,780,112)

    // ---- Custom 5-anchor table  (y 122-458) ----
    GroupBox gbCustom,pos={290,122},size={492,248},title="Custom 5-anchor color table"
    GroupBox gbCustom,font="Arial",fSize=10,fStyle=1

    TitleBox tbP,pos={336,143},size={20,14},title="p",frame=0
    TitleBox tbR,pos={418,143},size={16,14},title="R",frame=0
    TitleBox tbG,pos={502,143},size={16,14},title="G",frame=0
    TitleBox tbB,pos={586,143},size={16,14},title="B",frame=0

    // --- row 0  y=162 ---
    TitleBox tbRow0,pos={298,164},size={14,16},title="0",frame=0
    SetVariable svP0,pos={314,160},size={82,20},title="",limits={0,1,0.01}
    SetVariable svP0,value=$(LJZ_CTP2_BaseDF() + ":p0"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svR0,pos={398,160},size={82,20},title="",limits={0,255,1}
    SetVariable svR0,value=$(LJZ_CTP2_BaseDF() + ":r0"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svG0,pos={482,160},size={82,20},title="",limits={0,255,1}
    SetVariable svG0,value=$(LJZ_CTP2_BaseDF() + ":g0"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svB0,pos={566,160},size={82,20},title="",limits={0,255,1}
    SetVariable svB0,value=$(LJZ_CTP2_BaseDF() + ":b0"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68

    // --- row 1  y=186 ---
    TitleBox tbRow1,pos={298,188},size={14,16},title="1",frame=0
    SetVariable svP1,pos={314,184},size={82,20},title="",limits={0,1,0.01}
    SetVariable svP1,value=$(LJZ_CTP2_BaseDF() + ":p1"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svR1,pos={398,184},size={82,20},title="",limits={0,255,1}
    SetVariable svR1,value=$(LJZ_CTP2_BaseDF() + ":r1"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svG1,pos={482,184},size={82,20},title="",limits={0,255,1}
    SetVariable svG1,value=$(LJZ_CTP2_BaseDF() + ":g1"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svB1,pos={566,184},size={82,20},title="",limits={0,255,1}
    SetVariable svB1,value=$(LJZ_CTP2_BaseDF() + ":b1"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68

    // --- row 2  y=210 ---
    TitleBox tbRow2,pos={298,212},size={14,16},title="2",frame=0
    SetVariable svP2,pos={314,208},size={82,20},title="",limits={0,1,0.01}
    SetVariable svP2,value=$(LJZ_CTP2_BaseDF() + ":p2"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svR2,pos={398,208},size={82,20},title="",limits={0,255,1}
    SetVariable svR2,value=$(LJZ_CTP2_BaseDF() + ":r2"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svG2,pos={482,208},size={82,20},title="",limits={0,255,1}
    SetVariable svG2,value=$(LJZ_CTP2_BaseDF() + ":g2"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svB2,pos={566,208},size={82,20},title="",limits={0,255,1}
    SetVariable svB2,value=$(LJZ_CTP2_BaseDF() + ":b2"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68

    // --- row 3  y=234 ---
    TitleBox tbRow3,pos={298,236},size={14,16},title="3",frame=0
    SetVariable svP3,pos={314,232},size={82,20},title="",limits={0,1,0.01}
    SetVariable svP3,value=$(LJZ_CTP2_BaseDF() + ":p3"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svR3,pos={398,232},size={82,20},title="",limits={0,255,1}
    SetVariable svR3,value=$(LJZ_CTP2_BaseDF() + ":r3"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svG3,pos={482,232},size={82,20},title="",limits={0,255,1}
    SetVariable svG3,value=$(LJZ_CTP2_BaseDF() + ":g3"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svB3,pos={566,232},size={82,20},title="",limits={0,255,1}
    SetVariable svB3,value=$(LJZ_CTP2_BaseDF() + ":b3"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68

    // --- row 4  y=258 ---
    TitleBox tbRow4,pos={298,260},size={14,16},title="4",frame=0
    SetVariable svP4,pos={314,256},size={82,20},title="",limits={0,1,0.01}
    SetVariable svP4,value=$(LJZ_CTP2_BaseDF() + ":p4"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svR4,pos={398,256},size={82,20},title="",limits={0,255,1}
    SetVariable svR4,value=$(LJZ_CTP2_BaseDF() + ":r4"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svG4,pos={482,256},size={82,20},title="",limits={0,255,1}
    SetVariable svG4,value=$(LJZ_CTP2_BaseDF() + ":g4"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68
    SetVariable svB4,pos={566,256},size={82,20},title="",limits={0,255,1}
    SetVariable svB4,value=$(LJZ_CTP2_BaseDF() + ":b4"),proc=LJZ_CTP2_SetVarProc,bodyWidth=68

    // --- swap row  y=286 ---
    SetVariable svSwapA,pos={298,286},size={80,20},title="Swap A"
    SetVariable svSwapA,limits={0,4,1},value=$(LJZ_CTP2_BaseDF() + ":SwapA"),proc=LJZ_CTP2_SetVarProc,bodyWidth=38
    SetVariable svSwapB,pos={388,286},size={80,20},title="Swap B"
    SetVariable svSwapB,limits={0,4,1},value=$(LJZ_CTP2_BaseDF() + ":SwapB"),proc=LJZ_CTP2_SetVarProc,bodyWidth=38
    Button btSwapCustom,pos={478,284},size={96,24},title="Swap RGB",proc=LJZ_CTP2_ButtonProc

    // --- action row  y=316 ---
    Button btPreviewCustom,pos={298,316},size={114,24},title="Preview custom",proc=LJZ_CTP2_ButtonProc
    Button btApplyCustom,pos={420,316},size={114,24},title="Apply custom",proc=LJZ_CTP2_ButtonProc
    SetVariable svSaveName,pos={542,317},size={154,22},title="Save"
    SetVariable svSaveName,value=$(LJZ_CTP2_BaseDF() + ":SaveCustomName"),proc=LJZ_CTP2_SetVarProc,bodyWidth=108
    Button btSaveCustomToLib,pos={700,316},size={74,24},title="to CTLIB",proc=LJZ_CTP2_ButtonProc

    // --- note row  y=348 ---
    TitleBox tbCustomSafe,pos={298,348},size={478,16},frame=0
    TitleBox tbCustomSafe,title="Swap changes only RGB anchors; p0..p4 kept. No lookup waves used."
    TitleBox tbCustomSafe,font="Arial",fSize=9

    // ========================================================
    //  3. BUILT-IN IGOR COLOR TABLE
    //  horizontal full-width row, below CTLIB and Custom5
    // ========================================================

GroupBox gbBuiltIn,pos={10,376},size={774,58},title="3. Built-in Igor color table"
GroupBox gbBuiltIn,font="Arial",fSize=10,fStyle=1

PopupMenu pmBuiltInCT,pos={24,398},size={180,20},title="Built-in"
PopupMenu pmBuiltInCT,value="*COLORTABLEPOP*",proc=LJZ_CTP2_PopupProc

CheckBox ckReverse,pos={214,400},size={74,18},title="Reverse"
CheckBox ckReverse,variable=$(LJZ_CTP2_BaseDF() + ":ReverseCT"),proc=LJZ_CTP2_CheckProc

CheckBox ckManual,pos={292,400},size={104,18},title="Manual range"
CheckBox ckManual,variable=$(LJZ_CTP2_BaseDF() + ":UseManualRange")

SetVariable svCMin,pos={402,398},size={82,20},title="CMin"
SetVariable svCMin,value=$(LJZ_CTP2_BaseDF() + ":CMin"),proc=LJZ_CTP2_SetVarProc,bodyWidth=44

SetVariable svCMax,pos={490,398},size={82,20},title="CMax"
SetVariable svCMax,value=$(LJZ_CTP2_BaseDF() + ":CMax"),proc=LJZ_CTP2_SetVarProc,bodyWidth=44

Button btPreviewBuiltin,pos={582,396},size={88,24},title="Preview",proc=LJZ_CTP2_ButtonProc
Button btApplyBuiltIn,pos={680,396},size={90,24},title="Apply",proc=LJZ_CTP2_ButtonProc

    // ========================================================
    //  BOTTOM ROW   full-width   y 528-582
    // ========================================================

GroupBox gbSave,pos={10,440},size={774,54},title="Save-safe reset / all-image actions"
GroupBox gbSave,font="Arial",fSize=10,fStyle=1

Button btResetSelected,pos={24,462},size={108,24},title="Reset selected",proc=LJZ_CTP2_ButtonProc

Button btAddColorbar,pos={140,462},size={104,24},title="Add colorbar",proc=LJZ_CTP2_ButtonProc

Button btApplyWhiteFloor,pos={252,462},size={128,24},title="Apply White Floor",proc=LJZ_CTP2_ButtonProc

CheckBox ckConfirmAll,pos={390,466},size={88,18},title="Confirm all"
CheckBox ckConfirmAll,variable=$(LJZ_CTP2_BaseDF() + ":ApplyToAllConfirm")

Button btApplyAllBuiltIn,pos={488,462},size={118,24},title="Apply all built-in",proc=LJZ_CTP2_ButtonProc
Button btResetAll,pos={614,462},size={96,24},title="Reset Grays",proc=LJZ_CTP2_ButtonProc

Button btClose,pos={718,462},size={54,24},title="Close",proc=LJZ_CTP2_ButtonProc

    LJZ_CTP2_RefreshLibraryList()
    LJZ_CTP2_CreatePreviewGraph()
    LJZ_CTP2_RefreshImageList()

    return 0
End

// ============================================================================
//  ProcLJZ_CTLUZ_Compat_v2.ipf
//
//  Compatibility shim for older LJZ procedures that call old ctluz_* functions.
//
//  Covers the dependencies seen in SliceGallery / AngleToKTransform:
//    ctluz_ensure_folder()
//    ctluz_refresh_ctlib_menu()
//    root:ARPES_LJZ:CTLUZ:ct_table
//    root:ARPES_LJZ:CTLUZ:ct_lut
//    root:ARPES_LJZ:CTLUZ:ctlib_menu_list
//    root:ARPES_LJZ:CTLUZ:CTLIB:<palette waves>
//
//  Important:
//    Do not load this together with the original old ProcLJZ_ColorTablePanel.ipf
//    if that file defines the same ctluz_* functions.
// ============================================================================


// ============================================================================
//  Paths
// ============================================================================

Function/S ctluz_base_df()
    return "root:ARPES_LJZ:CTLUZ"
End


Function/S ctluz_base_df_colon()
    return "root:ARPES_LJZ:CTLUZ:"
End


Function/S ctluz_ctlib_df()
    return "root:ARPES_LJZ:CTLUZ:CTLIB"
End


Function/S ctluz_ctlib_df_colon()
    return "root:ARPES_LJZ:CTLUZ:CTLIB:"
End


Function/S ctluz_applied_df()
    return "root:ARPES_LJZ:CTLUZ:APPLIED"
End


Function/S ctluz_applied_df_colon()
    return "root:ARPES_LJZ:CTLUZ:APPLIED:"
End


// ============================================================================
//  Folder and default-state construction
// ============================================================================

Function ctluz_ensure_folder()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:CTLUZ
    NewDataFolder/O root:ARPES_LJZ:CTLUZ:CTLIB
    NewDataFolder/O root:ARPES_LJZ:CTLUZ:APPLIED

    Wave/Z/W/U ct = root:ARPES_LJZ:CTLUZ:ct_table
    if (!WaveExists(ct))
        Make/O/W/U/N=(256,3) root:ARPES_LJZ:CTLUZ:ct_table
        Wave/W/U ctNew = root:ARPES_LJZ:CTLUZ:ct_table
        ctluz_fill_mualani_ct(ctNew)
    endif

    Wave/Z lut = root:ARPES_LJZ:CTLUZ:ct_lut
    if (!WaveExists(lut))
        Make/O/N=256 root:ARPES_LJZ:CTLUZ:ct_lut
        Wave lutNew = root:ARPES_LJZ:CTLUZ:ct_lut
        ctluz_fill_linear_lut(lutNew)
    endif

    SVAR/Z menuList = root:ARPES_LJZ:CTLUZ:ctlib_menu_list
    if (!SVAR_Exists(menuList))
        String/G root:ARPES_LJZ:CTLUZ:ctlib_menu_list = ""
    endif

    ctluz_ensure_builtin_library()
    ctluz_refresh_ctlib_menu()

    return 0
End


Function ctluz_ensure_builtin_library()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:CTLUZ
    NewDataFolder/O root:ARPES_LJZ:CTLUZ:CTLIB

    Wave/Z/W/U wMualani = root:ARPES_LJZ:CTLUZ:CTLIB:Mualani
    if (!WaveExists(wMualani))
        Make/O/W/U/N=(256,3) root:ARPES_LJZ:CTLUZ:CTLIB:Mualani
        Wave/W/U tmpMualani = root:ARPES_LJZ:CTLUZ:CTLIB:Mualani
        ctluz_fill_mualani_ct(tmpMualani)
    endif

    Wave/Z/W/U wDefault = root:ARPES_LJZ:CTLUZ:CTLIB:DefaultLJZ
    if (!WaveExists(wDefault))
        Make/O/W/U/N=(256,3) root:ARPES_LJZ:CTLUZ:CTLIB:DefaultLJZ
        Wave/W/U tmpDefault = root:ARPES_LJZ:CTLUZ:CTLIB:DefaultLJZ
        ctluz_fill_default_ct(tmpDefault)
    endif

    Wave/Z/W/U wGray = root:ARPES_LJZ:CTLUZ:CTLIB:Gray
    if (!WaveExists(wGray))
        Make/O/W/U/N=(256,3) root:ARPES_LJZ:CTLUZ:CTLIB:Gray
        Wave/W/U tmpGray = root:ARPES_LJZ:CTLUZ:CTLIB:Gray
        ctluz_fill_gray_ct(tmpGray)
    endif

    Wave/Z/W/U wCyanHot = root:ARPES_LJZ:CTLUZ:CTLIB:CyanHot
    if (!WaveExists(wCyanHot))
        Make/O/W/U/N=(256,3) root:ARPES_LJZ:CTLUZ:CTLIB:CyanHot
        Wave/W/U tmpCyanHot = root:ARPES_LJZ:CTLUZ:CTLIB:CyanHot
        ctluz_fill_cyan_hot_ct(tmpCyanHot)
    endif

    Wave/Z/W/U wWhiteBlue = root:ARPES_LJZ:CTLUZ:CTLIB:WhiteBlue
    if (!WaveExists(wWhiteBlue))
        Make/O/W/U/N=(256,3) root:ARPES_LJZ:CTLUZ:CTLIB:WhiteBlue
        Wave/W/U tmpWhiteBlue = root:ARPES_LJZ:CTLUZ:CTLIB:WhiteBlue
        ctluz_fill_white_blue_ct(tmpWhiteBlue)
    endif

    Wave/Z/W/U wWhiteGray = root:ARPES_LJZ:CTLUZ:CTLIB:WhiteGray
    if (!WaveExists(wWhiteGray))
        Make/O/W/U/N=(256,3) root:ARPES_LJZ:CTLUZ:CTLIB:WhiteGray
        Wave/W/U tmpWhiteGray = root:ARPES_LJZ:CTLUZ:CTLIB:WhiteGray
        ctluz_fill_white_gray_ct(tmpWhiteGray)
    endif

    return 0
End


// ============================================================================
//  Missing old function: rebuild CT library menu
// ============================================================================

Function ctluz_refresh_ctlib_menu()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:CTLUZ
    NewDataFolder/O root:ARPES_LJZ:CTLUZ:CTLIB

    ctluz_ensure_builtin_library()

    SVAR/Z menuList = root:ARPES_LJZ:CTLUZ:ctlib_menu_list
    if (!SVAR_Exists(menuList))
        String/G root:ARPES_LJZ:CTLUZ:ctlib_menu_list = ""
    endif
    SVAR menuListRef = root:ARPES_LJZ:CTLUZ:ctlib_menu_list

    String oldDF
    oldDF = GetDataFolder(1)

    SetDataFolder root:ARPES_LJZ:CTLUZ:CTLIB
    String wl
    wl = WaveList("*", ";", "")
    SetDataFolder oldDF

    String out
    out = ""

    Variable i
    Variable n
    String nm
    n = ItemsInList(wl, ";")

    for (i = 0; i < n; i += 1)
        nm = StringFromList(i, wl, ";")
        if (strlen(nm) == 0)
            continue
        endif

        Wave/Z w = $("root:ARPES_LJZ:CTLUZ:CTLIB:" + nm)
        if (!WaveExists(w))
            continue
        endif

        if (DimSize(w, 0) <= 0 || DimSize(w, 1) < 3)
            continue
        endif

        if (WaveType(w, 1) != 1)
            continue
        endif

        out += nm + ";"
    endfor

    if (strlen(out) == 0)
        out = "Mualani;DefaultLJZ;Gray;CyanHot;"
    endif

    menuListRef = out

    return 0
End


// ============================================================================
//  Fillers
// ============================================================================

Function ctluz_fill_linear_lut(lut)
    Wave lut

    Variable n
    Variable i

    n = numpnts(lut)
    if (n <= 0)
        return -1
    endif

    for (i = 0; i < n; i += 1)
        if (n > 1)
            lut[i] = i / (n - 1)
        else
            lut[i] = 0
        endif
    endfor

    return 0
End


Function ctluz_clip01(v)
    Variable v

    if (v < 0)
        return 0
    endif

    if (v > 1)
        return 1
    endif

    return v
End


Function ctluz_rgb_to_u16(v)
    Variable v

    v = ctluz_clip01(v)
    return round(v * 65535)
End


Function ctluz_fill_gray_ct(ct)
    Wave/W/U ct

    Variable n
    Variable i
    Variable t

    n = DimSize(ct, 0)
    if (n <= 0)
        return -1
    endif

    for (i = 0; i < n; i += 1)
        if (n > 1)
            t = i / (n - 1)
        else
            t = 0
        endif

        ct[i][0] = ctluz_rgb_to_u16(t)
        ct[i][1] = ctluz_rgb_to_u16(t)
        ct[i][2] = ctluz_rgb_to_u16(t)
    endfor

    return 0
End


Function ctluz_fill_default_ct(ct)
    Wave/W/U ct

    Variable n
    Variable i
    Variable t
    Variable r
    Variable g
    Variable b

    n = DimSize(ct, 0)
    if (n <= 0)
        return -1
    endif

    for (i = 0; i < n; i += 1)
        if (n > 1)
            t = i / (n - 1)
        else
            t = 0
        endif

        if (t < 0.25)
            r = 0
            g = 0
            b = 4 * t
        elseif (t < 0.50)
            r = 0
            g = 4 * (t - 0.25)
            b = 1
        elseif (t < 0.75)
            r = 4 * (t - 0.50)
            g = 1
            b = 1 - 4 * (t - 0.50)
        else
            r = 1
            g = 1
            b = 4 * (t - 0.75)
        endif

        ct[i][0] = ctluz_rgb_to_u16(r)
        ct[i][1] = ctluz_rgb_to_u16(g)
        ct[i][2] = ctluz_rgb_to_u16(b)
    endfor

    return 0
End


Function ctluz_fill_mualani_ct(ct)
    Wave/W/U ct

    Variable n
    Variable i
    Variable t
    Variable r
    Variable g
    Variable b

    n = DimSize(ct, 0)
    if (n <= 0)
        return -1
    endif

    for (i = 0; i < n; i += 1)
        if (n > 1)
            t = i / (n - 1)
        else
            t = 0
        endif

        // dark navy -> blue -> cyan-green -> yellow-orange -> white
        if (t < 0.22)
            r = 0.02 + 0.02 * (t / 0.22)
            g = 0.02 + 0.18 * (t / 0.22)
            b = 0.05 + 0.75 * (t / 0.22)
        elseif (t < 0.48)
            r = 0.04 + 0.02 * ((t - 0.22) / 0.26)
            g = 0.20 + 0.70 * ((t - 0.22) / 0.26)
            b = 0.80 + 0.18 * ((t - 0.22) / 0.26)
        elseif (t < 0.72)
            r = 0.06 + 0.88 * ((t - 0.48) / 0.24)
            g = 0.90 + 0.08 * ((t - 0.48) / 0.24)
            b = 0.98 - 0.82 * ((t - 0.48) / 0.24)
        else
            r = 0.94 + 0.06 * ((t - 0.72) / 0.28)
            g = 0.98 + 0.02 * ((t - 0.72) / 0.28)
            b = 0.16 + 0.84 * ((t - 0.72) / 0.28)
        endif

        ct[i][0] = ctluz_rgb_to_u16(r)
        ct[i][1] = ctluz_rgb_to_u16(g)
        ct[i][2] = ctluz_rgb_to_u16(b)
    endfor

    return 0
End


Function ctluz_fill_cyan_hot_ct(ct)
    Wave/W/U ct

    Variable n
    Variable i
    Variable t
    Variable r
    Variable g
    Variable b

    n = DimSize(ct, 0)
    if (n <= 0)
        return -1
    endif

    for (i = 0; i < n; i += 1)
        if (n > 1)
            t = i / (n - 1)
        else
            t = 0
        endif

        r = min(1, max(0, 1.8 * t - 0.25))
        g = min(1, max(0, 2.0 * t))
        b = min(1, max(0, 1.3 - 1.2 * t))

        ct[i][0] = ctluz_rgb_to_u16(r)
        ct[i][1] = ctluz_rgb_to_u16(g)
        ct[i][2] = ctluz_rgb_to_u16(b)
    endfor

    return 0
End


Function ctluz_fill_white_blue_ct(ct)
    Wave/W/U ct

    Variable n
    Variable i
    Variable t
    Variable u
    Variable r
    Variable g
    Variable b

    n = DimSize(ct, 0)
    if (n <= 0)
        return -1
    endif

    for (i = 0; i < n; i += 1)
        if (n > 1)
            t = i / (n - 1)
        else
            t = 0
        endif

        if (t < 0.08)
            r = 1
            g = 1
            b = 1
        else
            u = (t - 0.08) / 0.92
            u = ctluz_clip01(u)

            // white -> deep blue
            r = 1.00 - 0.96 * u
            g = 1.00 - 0.78 * u
            b = 1.00 - 0.32 * u
        endif

        ct[i][0] = ctluz_rgb_to_u16(r)
        ct[i][1] = ctluz_rgb_to_u16(g)
        ct[i][2] = ctluz_rgb_to_u16(b)
    endfor

    return 0
End


Function ctluz_fill_white_gray_ct(ct)
    Wave/W/U ct

    Variable n
    Variable i
    Variable t
    Variable u
    Variable r
    Variable g
    Variable b

    n = DimSize(ct, 0)
    if (n <= 0)
        return -1
    endif

    for (i = 0; i < n; i += 1)
        if (n > 1)
            t = i / (n - 1)
        else
            t = 0
        endif

        if (t < 0.08)
            r = 1
            g = 1
            b = 1
        else
            u = (t - 0.08) / 0.92
            u = ctluz_clip01(u)

            // white -> dark gray / black
            r = 1.00 - 0.92 * u
            g = 1.00 - 0.92 * u
            b = 1.00 - 0.92 * u
        endif

        ct[i][0] = ctluz_rgb_to_u16(r)
        ct[i][1] = ctluz_rgb_to_u16(g)
        ct[i][2] = ctluz_rgb_to_u16(b)
    endfor

    return 0
End


// ============================================================================
//  Convenience and compatibility helpers
// ============================================================================

Function/S ctluz_default_ct_path()
    ctluz_ensure_folder()
    return "root:ARPES_LJZ:CTLUZ:ct_table"
End


Function/S ctluz_default_lut_path()
    ctluz_ensure_folder()
    return "root:ARPES_LJZ:CTLUZ:ct_lut"
End


Function ctluz_set_current_ct_from_library(ctName)
    String ctName

    ctluz_ensure_folder()

    if (strlen(ctName) == 0)
        return -1
    endif

    Wave/Z/W/U src = $("root:ARPES_LJZ:CTLUZ:CTLIB:" + ctName)
    if (!WaveExists(src))
        return -1
    endif

    Duplicate/O src, root:ARPES_LJZ:CTLUZ:ct_table
    return 0
End


Function ctluz_rgb16_at_t(t, r16, g16, b16)
    Variable t
    Variable &r16
    Variable &g16
    Variable &b16

    ctluz_ensure_folder()

    Wave/W/U ct = root:ARPES_LJZ:CTLUZ:ct_table

    Variable n
    Variable idx

    n = DimSize(ct, 0)
    if (n <= 0)
        r16 = 0
        g16 = 0
        b16 = 0
        return -1
    endif

    if (t < 0)
        t = 0
    endif
    if (t > 1)
        t = 1
    endif

    idx = round(t * (n - 1))

    if (idx < 0)
        idx = 0
    endif
    if (idx > n - 1)
        idx = n - 1
    endif

    r16 = ct[idx][0]
    g16 = ct[idx][1]
    b16 = ct[idx][2]

    return 0
End

Function LJZ_CTP2_RebuildLibraryListWaves()
    LJZ_CTP2_EnsureCTLIB()

    SVAR LibraryMenuList = $(LJZ_CTP2_BaseDF() + ":LibraryMenuList")
    SVAR LibraryCTName = $(LJZ_CTP2_BaseDF() + ":LibraryCTName")

    Wave/T LibList = $(LJZ_CTP2_BaseDF() + ":LibList")
    Wave LibSel = $(LJZ_CTP2_BaseDF() + ":LibSel")

    Variable n
    Variable i
    Variable row
    String nm

    n = ItemsInList(LibraryMenuList, ";")
    Redimension/N=(n) LibList
    Redimension/N=(n) LibSel
    LibSel = 0

    row = -1

    for (i = 0; i < n; i += 1)
        nm = StringFromList(i, LibraryMenuList, ";")
        LibList[i] = nm

        if (CmpStr(nm, LibraryCTName) == 0)
            row = i
        endif
    endfor

    if (n > 0)
        if (row < 0)
            row = 0
            LibraryCTName = LibList[0]
        endif
        LibSel[row] = 1
    endif

    return 0
End

Function LJZ_CTP2_SetSelectedLibrary(row)
    Variable row

    Wave/T LibList = $(LJZ_CTP2_BaseDF() + ":LibList")
    Wave LibSel = $(LJZ_CTP2_BaseDF() + ":LibSel")
    SVAR LibraryCTName = $(LJZ_CTP2_BaseDF() + ":LibraryCTName")

    LibSel = 0

    if (numpnts(LibList) <= 0)
        LibraryCTName = ""
        return -1
    endif

    if (row < 0 || row >= numpnts(LibList))
        row = 0
    endif

    LibSel[row] = 1
    LibraryCTName = LibList[row]

    return 0
End

Function LJZ_CTP2_LibListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if (lba.eventCode != 4)
        return 0
    endif

    LJZ_CTP2_SetSelectedLibrary(lba.row)
    LJZ_CTP2_UpdatePreviewLibrary()

    String pName
    pName = LJZ_CTP2_PanelName()
    if (WinType(pName) != 0)
        ControlUpdate/A/W=$pName
    endif

    return 0
End
