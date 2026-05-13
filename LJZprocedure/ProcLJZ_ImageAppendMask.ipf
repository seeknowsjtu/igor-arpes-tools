#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma DefaultTab={3,20,4}

// ============================================================================
//  ProcLJZ_ImageAppendMask_v4.ipf
//
//  Stable graph-image manager for Igor Pro.
//
//  Main features:
//    1) Graph can be left blank. The procedure then uses the top graph window.
//    2) Show existing images in the selected/top graph with a ListBox.
//    3) Select a graph image from the ListBox.
//    4) Delete the selected graph image from the graph.
//       If the displayed image is an iam4_* copied wave created by this tool
//       inside root:Packages:LJZ_ImageAppendMaskV4:Output:, it can also kill
//       that copied wave to avoid accumulation.
//    5) Process an existing graph image: mask / symmetry / append or replace.
//    6) Append a 2D image wave by Igor wave path.
//    7) Data-level mask: masked pixels are set to NaN in a copied wave.
//    8) Symmetry output:
//         SymMode = 0: none
//         SymMode = 1: mirror about x axis, y -> -y
//         SymMode = 2: mirror about y axis, x -> -x
//         SymMode = 3: center symmetry, x -> -x and y -> -y
//
//  Notes:
//    - ImageWavePath is an Igor internal wave path, for example:
//        root:ARPES_LJZ:EKKMapOutput:KxKy:kxky_map1
//      It is not a Windows png/tif path.
//    - Existing image operations use graph image names from ImageNameList.
//    - Source waves are never modified.
// ============================================================================


Menu "ARPES_LJZ"
    "Image Append + Mask v4", LJZ_IAM4_OpenPanel()
End


// ============================================================================
//  Section 0. base paths
// ============================================================================

Function/S LJZ_IAM4_BaseDF()
    return "root:Packages:LJZ_ImageAppendMaskV4"
End


Function/S LJZ_IAM4_OutputDF()
    return "root:Packages:LJZ_ImageAppendMaskV4:Output:"
End


Function/S LJZ_IAM4_PanelName()
    return "LJZ_ImageAppendMaskV4_Panel"
End


Function LJZ_IAM4_EnsureDF()
    NewDataFolder/O root:Packages
    NewDataFolder/O $(LJZ_IAM4_BaseDF())
    NewDataFolder/O root:Packages:LJZ_ImageAppendMaskV4
    NewDataFolder/O root:Packages:LJZ_ImageAppendMaskV4:Output

    SVAR/Z GraphName = $(LJZ_IAM4_BaseDF() + ":GraphName")
    if (!SVAR_Exists(GraphName))
        String/G $(LJZ_IAM4_BaseDF() + ":GraphName") = ""
    endif

    SVAR/Z ImageWavePath = $(LJZ_IAM4_BaseDF() + ":ImageWavePath")
    if (!SVAR_Exists(ImageWavePath))
        String/G $(LJZ_IAM4_BaseDF() + ":ImageWavePath") = ""
    endif

    SVAR/Z ExistingImageName = $(LJZ_IAM4_BaseDF() + ":ExistingImageName")
    if (!SVAR_Exists(ExistingImageName))
        String/G $(LJZ_IAM4_BaseDF() + ":ExistingImageName") = ""
    endif

    SVAR/Z OutputSuffix = $(LJZ_IAM4_BaseDF() + ":OutputSuffix")
    if (!SVAR_Exists(OutputSuffix))
        String/G $(LJZ_IAM4_BaseDF() + ":OutputSuffix") = "_proc"
    endif

    NVAR/Z Counter = $(LJZ_IAM4_BaseDF() + ":Counter")
    if (!NVAR_Exists(Counter))
        Variable/G $(LJZ_IAM4_BaseDF() + ":Counter") = 0
    endif

    NVAR/Z SelImageRow = $(LJZ_IAM4_BaseDF() + ":SelImageRow")
    if (!NVAR_Exists(SelImageRow))
        Variable/G $(LJZ_IAM4_BaseDF() + ":SelImageRow") = -1
    endif

    NVAR/Z MaskEnable = $(LJZ_IAM4_BaseDF() + ":MaskEnable")
    if (!NVAR_Exists(MaskEnable))
        Variable/G $(LJZ_IAM4_BaseDF() + ":MaskEnable") = 1
    endif

    NVAR/Z MaskMode = $(LJZ_IAM4_BaseDF() + ":MaskMode")
    if (!NVAR_Exists(MaskMode))
        Variable/G $(LJZ_IAM4_BaseDF() + ":MaskMode") = 1
    endif

    NVAR/Z MaskX1 = $(LJZ_IAM4_BaseDF() + ":MaskX1")
    if (!NVAR_Exists(MaskX1))
        Variable/G $(LJZ_IAM4_BaseDF() + ":MaskX1") = 0
    endif

    NVAR/Z MaskX2 = $(LJZ_IAM4_BaseDF() + ":MaskX2")
    if (!NVAR_Exists(MaskX2))
        Variable/G $(LJZ_IAM4_BaseDF() + ":MaskX2") = 1
    endif

    NVAR/Z MaskY1 = $(LJZ_IAM4_BaseDF() + ":MaskY1")
    if (!NVAR_Exists(MaskY1))
        Variable/G $(LJZ_IAM4_BaseDF() + ":MaskY1") = 0
    endif

    NVAR/Z MaskY2 = $(LJZ_IAM4_BaseDF() + ":MaskY2")
    if (!NVAR_Exists(MaskY2))
        Variable/G $(LJZ_IAM4_BaseDF() + ":MaskY2") = 1
    endif

    NVAR/Z SymMode = $(LJZ_IAM4_BaseDF() + ":SymMode")
    if (!NVAR_Exists(SymMode))
        Variable/G $(LJZ_IAM4_BaseDF() + ":SymMode") = 0
    endif

    NVAR/Z StackAbove = $(LJZ_IAM4_BaseDF() + ":StackAbove")
    if (!NVAR_Exists(StackAbove))
        Variable/G $(LJZ_IAM4_BaseDF() + ":StackAbove") = 0
    endif

    NVAR/Z AlignXToGraph = $(LJZ_IAM4_BaseDF() + ":AlignXToGraph")
    if (!NVAR_Exists(AlignXToGraph))
        Variable/G $(LJZ_IAM4_BaseDF() + ":AlignXToGraph") = 0
    endif

    NVAR/Z GapY = $(LJZ_IAM4_BaseDF() + ":GapY")
    if (!NVAR_Exists(GapY))
        Variable/G $(LJZ_IAM4_BaseDF() + ":GapY") = 0.02
    endif

    NVAR/Z XShift = $(LJZ_IAM4_BaseDF() + ":XShift")
    if (!NVAR_Exists(XShift))
        Variable/G $(LJZ_IAM4_BaseDF() + ":XShift") = 0
    endif

    NVAR/Z YShift = $(LJZ_IAM4_BaseDF() + ":YShift")
    if (!NVAR_Exists(YShift))
        Variable/G $(LJZ_IAM4_BaseDF() + ":YShift") = 0
    endif

    NVAR/Z OverrideScale = $(LJZ_IAM4_BaseDF() + ":OverrideScale")
    if (!NVAR_Exists(OverrideScale))
        Variable/G $(LJZ_IAM4_BaseDF() + ":OverrideScale") = 0
    endif

    NVAR/Z NewX1 = $(LJZ_IAM4_BaseDF() + ":NewX1")
    if (!NVAR_Exists(NewX1))
        Variable/G $(LJZ_IAM4_BaseDF() + ":NewX1") = -1
    endif

    NVAR/Z NewX2 = $(LJZ_IAM4_BaseDF() + ":NewX2")
    if (!NVAR_Exists(NewX2))
        Variable/G $(LJZ_IAM4_BaseDF() + ":NewX2") = 1
    endif

    NVAR/Z NewY1 = $(LJZ_IAM4_BaseDF() + ":NewY1")
    if (!NVAR_Exists(NewY1))
        Variable/G $(LJZ_IAM4_BaseDF() + ":NewY1") = -1
    endif

    NVAR/Z NewY2 = $(LJZ_IAM4_BaseDF() + ":NewY2")
    if (!NVAR_Exists(NewY2))
        Variable/G $(LJZ_IAM4_BaseDF() + ":NewY2") = 1
    endif

    NVAR/Z AutoScaleGraph = $(LJZ_IAM4_BaseDF() + ":AutoScaleGraph")
    if (!NVAR_Exists(AutoScaleGraph))
        Variable/G $(LJZ_IAM4_BaseDF() + ":AutoScaleGraph") = 1
    endif

    NVAR/Z DeleteOutputWaveOnDelete = $(LJZ_IAM4_BaseDF() + ":DeleteOutputWaveOnDelete")
    if (!NVAR_Exists(DeleteOutputWaveOnDelete))
        Variable/G $(LJZ_IAM4_BaseDF() + ":DeleteOutputWaveOnDelete") = 1
    endif

    Wave/T/Z ImgList = $(LJZ_IAM4_BaseDF() + ":ImgList")
    if (!WaveExists(ImgList))
        Make/O/T/N=0 $(LJZ_IAM4_BaseDF() + ":ImgList")
    endif

    Wave/Z ImgSel = $(LJZ_IAM4_BaseDF() + ":ImgSel")
    if (!WaveExists(ImgSel))
        Make/O/N=0 $(LJZ_IAM4_BaseDF() + ":ImgSel")
    endif

    return 0
End


// ============================================================================
//  Section 1. graph and image-list helpers
// ============================================================================

Function/S LJZ_IAM4_GetGraphName(createIfMissing)
    Variable createIfMissing

    LJZ_IAM4_EnsureDF()

    SVAR GraphName = $(LJZ_IAM4_BaseDF() + ":GraphName")

    String gName
    gName = GraphName

    if (strlen(gName) == 0)
        gName = WinName(0, 1)
    endif

    if (strlen(gName) == 0)
        if (createIfMissing)
            Display/N=LJZ_IAM4_Graph
            gName = "LJZ_IAM4_Graph"
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


Function LJZ_IAM4_SetSelectedImage(row)
    Variable row

    LJZ_IAM4_EnsureDF()

    Wave/T ImgList = $(LJZ_IAM4_BaseDF() + ":ImgList")
    Wave ImgSel = $(LJZ_IAM4_BaseDF() + ":ImgSel")
    NVAR SelImageRow = $(LJZ_IAM4_BaseDF() + ":SelImageRow")
    SVAR ExistingImageName = $(LJZ_IAM4_BaseDF() + ":ExistingImageName")

    ImgSel = 0

    if (numpnts(ImgList) <= 0 || row < 0 || row >= numpnts(ImgList))
        SelImageRow = -1
        ExistingImageName = ""
        return -1
    endif

    ImgSel[row] = 1
    SelImageRow = row
    ExistingImageName = ImgList[row]

    return 0
End


Function LJZ_IAM4_RefreshImageList()
    LJZ_IAM4_EnsureDF()

    String gName
    gName = LJZ_IAM4_GetGraphName(0)

    Wave/T ImgList = $(LJZ_IAM4_BaseDF() + ":ImgList")
    Wave ImgSel = $(LJZ_IAM4_BaseDF() + ":ImgSel")
    NVAR SelImageRow = $(LJZ_IAM4_BaseDF() + ":SelImageRow")
    SVAR ExistingImageName = $(LJZ_IAM4_BaseDF() + ":ExistingImageName")

    String imgs
    imgs = ""

    if (strlen(gName) > 0)
        imgs = ImageNameList(gName, ";")
    endif

    Variable n
    n = ItemsInList(imgs, ";")

    Redimension/N=(n) ImgList, ImgSel
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
                break
            endif
        endfor
    endif

    if (keepRow < 0 && n > 0)
        keepRow = 0
    endif

    LJZ_IAM4_SetSelectedImage(keepRow)

    String pName
    pName = LJZ_IAM4_PanelName()
    if (WinType(pName) != 0)
        ListBox/Z lbImages,win=$pName,selRow=SelImageRow
        ControlUpdate/A/W=$pName
    endif

    Print "LJZ_IAM4 graph = " + gName
    Print "LJZ_IAM4 images = " + imgs

    return 0
End


Function LJZ_IAM4_UseFirstImage()
    LJZ_IAM4_RefreshImageList()
    LJZ_IAM4_SetSelectedImage(0)

    String pName
    pName = LJZ_IAM4_PanelName()
    if (WinType(pName) != 0)
        ListBox/Z lbImages,win=$pName,selRow=0
        ControlUpdate/A/W=$pName
    endif

    return 0
End


Function LJZ_IAM4_IsManagedOutputWave(w)
    Wave/Z w

    if (!WaveExists(w))
        return 0
    endif

    String wPath
    wPath = GetWavesDataFolder(w, 2)

    if (StringMatch(wPath, LJZ_IAM4_OutputDF() + "iam4_*"))
        return 1
    endif

    return 0
End


Function LJZ_IAM4_RemoveImageAndMaybeKillWave(gName, imgName, doKill)
    String gName
    String imgName
    Variable doKill

    Wave/Z imgWave = ImageNameToWaveRef(gName, imgName)

    String wPath
    Variable killOK

    wPath = ""
    killOK = 0

    if (WaveExists(imgWave))
        wPath = GetWavesDataFolder(imgWave, 2)
        killOK = LJZ_IAM4_IsManagedOutputWave(imgWave)
    endif

    RemoveImage/W=$gName/Z $imgName

    if (doKill && killOK && strlen(wPath) > 0)
        KillWaves/Z $wPath
        Print "LJZ_IAM4 removed image and killed copied wave: " + imgName + "  wave=" + wPath
    else
        Print "LJZ_IAM4 removed image only: " + imgName
        if (strlen(wPath) > 0)
            Print "LJZ_IAM4 kept wave: " + wPath
        endif
    endif

    return 0
End


Function LJZ_IAM4_DeleteSelectedImage()
    LJZ_IAM4_EnsureDF()

    String gName
    gName = LJZ_IAM4_GetGraphName(0)

    if (strlen(gName) == 0)
        DoAlert 0, "No graph found. Leave Graph empty to use the top graph."
        return -1
    endif

    SVAR ExistingImageName = $(LJZ_IAM4_BaseDF() + ":ExistingImageName")
    NVAR DeleteOutputWaveOnDelete = $(LJZ_IAM4_BaseDF() + ":DeleteOutputWaveOnDelete")

    if (strlen(ExistingImageName) == 0)
        DoAlert 0, "No image selected. Click Refresh images and select one image first."
        return -1
    endif

    String imgName
    imgName = ExistingImageName

    LJZ_IAM4_RemoveImageAndMaybeKillWave(gName, imgName, DeleteOutputWaveOnDelete)

    LJZ_IAM4_RefreshImageList()
    DoWindow/F $gName

    return 0
End


// ============================================================================
//  Section 2. wave processing
// ============================================================================

Function LJZ_IAM4_Is2DNumeric(w)
    Wave/Z w

    if (!WaveExists(w))
        return 0
    endif

    if (WaveType(w, 1) != 1)
        return 0
    endif

    if (DimSize(w, 0) <= 0 || DimSize(w, 1) <= 0)
        return 0
    endif

    if (DimSize(w, 2) > 0 || DimSize(w, 3) > 0)
        return 0
    endif

    return 1
End


Function/S LJZ_IAM4_MakeOutPath(src, tag)
    Wave src
    String tag

    LJZ_IAM4_EnsureDF()

    NVAR Counter = $(LJZ_IAM4_BaseDF() + ":Counter")
    SVAR OutputSuffix = $(LJZ_IAM4_BaseDF() + ":OutputSuffix")

    Counter += 1

    String nm
    nm = CleanupName("iam4_" + NameOfWave(src) + OutputSuffix + tag + "_" + num2str(Counter), 0)

    return LJZ_IAM4_OutputDF() + nm
End


Function LJZ_IAM4_CopyScale(src, dest)
    Wave src
    Wave dest

    SetScale/P x, DimOffset(src, 0), DimDelta(src, 0), WaveUnits(src, 0), dest
    SetScale/P y, DimOffset(src, 1), DimDelta(src, 1), WaveUnits(src, 1), dest

    return 0
End


Function LJZ_IAM4_FillCopy(src, dest)
    Wave src
    Wave dest

    Redimension/D/N=(DimSize(src, 0), DimSize(src, 1)) dest
    LJZ_IAM4_CopyScale(src, dest)
    dest = src[p][q]

    return 0
End


Function LJZ_IAM4_ApplyMaskInPlace(w)
    Wave w

    LJZ_IAM4_EnsureDF()

    NVAR MaskEnable = $(LJZ_IAM4_BaseDF() + ":MaskEnable")
    NVAR MaskMode = $(LJZ_IAM4_BaseDF() + ":MaskMode")
    NVAR MaskX1 = $(LJZ_IAM4_BaseDF() + ":MaskX1")
    NVAR MaskX2 = $(LJZ_IAM4_BaseDF() + ":MaskX2")
    NVAR MaskY1 = $(LJZ_IAM4_BaseDF() + ":MaskY1")
    NVAR MaskY2 = $(LJZ_IAM4_BaseDF() + ":MaskY2")

    if (!MaskEnable)
        return 0
    endif

    Variable xLo
    Variable xHi
    Variable yLo
    Variable yHi

    xLo = min(MaskX1, MaskX2)
    xHi = max(MaskX1, MaskX2)
    yLo = min(MaskY1, MaskY2)
    yHi = max(MaskY1, MaskY2)

    if (round(MaskMode) == 2)
        w = (x >= xLo && x <= xHi && y >= yLo && y <= yHi) ? w[p][q] : NaN
    else
        w = (x >= xLo && x <= xHi && y >= yLo && y <= yHi) ? NaN : w[p][q]
    endif

    return 0
End


Function LJZ_IAM4_ApplySymmetry(src, dest, symMode)
    Wave src
    Wave dest
    Variable symMode

    Variable nx
    Variable ny
    Variable xA
    Variable xB
    Variable yA
    Variable yB

    nx = DimSize(src, 0)
    ny = DimSize(src, 1)

    xA = DimOffset(src, 0)
    xB = DimOffset(src, 0) + DimDelta(src, 0) * (nx - 1)
    yA = DimOffset(src, 1)
    yB = DimOffset(src, 1) + DimDelta(src, 1) * (ny - 1)

    Redimension/D/N=(nx, ny) dest

    if (round(symMode) == 1)
        dest = src[p][ny - 1 - q]
        SetScale/I x, xA, xB, WaveUnits(src, 0), dest
        SetScale/I y, -yB, -yA, WaveUnits(src, 1), dest
    elseif (round(symMode) == 2)
        dest = src[nx - 1 - p][q]
        SetScale/I x, -xB, -xA, WaveUnits(src, 0), dest
        SetScale/I y, yA, yB, WaveUnits(src, 1), dest
    elseif (round(symMode) == 3)
        dest = src[nx - 1 - p][ny - 1 - q]
        SetScale/I x, -xB, -xA, WaveUnits(src, 0), dest
        SetScale/I y, -yB, -yA, WaveUnits(src, 1), dest
    else
        dest = src[p][q]
        SetScale/I x, xA, xB, WaveUnits(src, 0), dest
        SetScale/I y, yA, yB, WaveUnits(src, 1), dest
    endif

    return 0
End


Function/WAVE LJZ_IAM4_ProcessSourceWave(src, useMask, useSym)
    Wave src
    Variable useMask
    Variable useSym

    LJZ_IAM4_EnsureDF()

    if (!LJZ_IAM4_Is2DNumeric(src))
        Make/O/D/N=(2,2) $(LJZ_IAM4_OutputDF() + "InvalidOutput") = NaN
        Wave invalid = $(LJZ_IAM4_OutputDF() + "InvalidOutput")
        return invalid
    endif

    NVAR SymMode = $(LJZ_IAM4_BaseDF() + ":SymMode")

    String tmpPath
    String outPath
    String tag

    tmpPath = LJZ_IAM4_OutputDF() + "tmpIAM4MaskBase"
    Make/O/D/N=(DimSize(src, 0), DimSize(src, 1)) $tmpPath
    Wave tmp = $tmpPath

    LJZ_IAM4_FillCopy(src, tmp)

    if (useMask)
        LJZ_IAM4_ApplyMaskInPlace(tmp)
    endif

    if (useSym)
        tag = "_sym"
    else
        tag = "_copy"
    endif

    outPath = LJZ_IAM4_MakeOutPath(src, tag)
    Make/O/D/N=(DimSize(tmp, 0), DimSize(tmp, 1)) $outPath
    Wave out = $outPath

    if (useSym)
        LJZ_IAM4_ApplySymmetry(tmp, out, SymMode)
    else
        LJZ_IAM4_FillCopy(tmp, out)
    endif

    KillWaves/Z $tmpPath

    Print "LJZ_IAM4 output wave: " + outPath

    return out
End


// ============================================================================
//  Section 3. placement and appending
// ============================================================================

Function LJZ_IAM4_GetAxisRange(gName, axisName, vMin, vMax)
    String gName
    String axisName
    Variable &vMin
    Variable &vMax

    GetAxis/Q/W=$gName $axisName
    if (V_flag != 0)
        return -1
    endif

    vMin = V_min
    vMax = V_max

    return 0
End


Function LJZ_IAM4_ApplyPlacement(w, gName)
    Wave w
    String gName

    LJZ_IAM4_EnsureDF()

    NVAR StackAbove = $(LJZ_IAM4_BaseDF() + ":StackAbove")
    NVAR AlignXToGraph = $(LJZ_IAM4_BaseDF() + ":AlignXToGraph")
    NVAR GapY = $(LJZ_IAM4_BaseDF() + ":GapY")
    NVAR XShift = $(LJZ_IAM4_BaseDF() + ":XShift")
    NVAR YShift = $(LJZ_IAM4_BaseDF() + ":YShift")
    NVAR OverrideScale = $(LJZ_IAM4_BaseDF() + ":OverrideScale")
    NVAR NewX1 = $(LJZ_IAM4_BaseDF() + ":NewX1")
    NVAR NewX2 = $(LJZ_IAM4_BaseDF() + ":NewX2")
    NVAR NewY1 = $(LJZ_IAM4_BaseDF() + ":NewY1")
    NVAR NewY2 = $(LJZ_IAM4_BaseDF() + ":NewY2")

    Variable xA
    Variable xB
    Variable yA
    Variable yB
    Variable axMin
    Variable axMax
    Variable h

    xA = DimOffset(w, 0)
    xB = DimOffset(w, 0) + DimDelta(w, 0) * (DimSize(w, 0) - 1)
    yA = DimOffset(w, 1)
    yB = DimOffset(w, 1) + DimDelta(w, 1) * (DimSize(w, 1) - 1)

    if (OverrideScale)
        SetScale/I x, NewX1, NewX2, WaveUnits(w, 0), w
        SetScale/I y, NewY1, NewY2, WaveUnits(w, 1), w
        return 0
    endif

    if (AlignXToGraph && LJZ_IAM4_GetAxisRange(gName, "bottom", axMin, axMax) == 0)
        SetScale/I x, axMin, axMax, WaveUnits(w, 0), w
    else
        SetScale/I x, xA + XShift, xB + XShift, WaveUnits(w, 0), w
    endif

    if (StackAbove && LJZ_IAM4_GetAxisRange(gName, "left", axMin, axMax) == 0)
        h = abs(yB - yA)
        SetScale/I y, axMax + GapY, axMax + GapY + h, WaveUnits(w, 1), w
    else
        SetScale/I y, yA + YShift, yB + YShift, WaveUnits(w, 1), w
    endif

    return 0
End


Function LJZ_IAM4_AppendWaveToGraph(w)
    Wave w

    LJZ_IAM4_EnsureDF()

    NVAR AutoScaleGraph = $(LJZ_IAM4_BaseDF() + ":AutoScaleGraph")

    String gName
    gName = LJZ_IAM4_GetGraphName(1)

    if (strlen(gName) == 0)
        DoAlert 0, "No graph is available."
        return -1
    endif

    LJZ_IAM4_ApplyPlacement(w, gName)

    AppendImage/W=$gName w

    if (AutoScaleGraph)
        SetAxis/A/W=$gName
    endif

    DoWindow/F $gName
    LJZ_IAM4_RefreshImageList()

    return 0
End


// ============================================================================
//  Section 4. source getters and run actions
// ============================================================================

Function/WAVE LJZ_IAM4_GetWaveByPath()
    LJZ_IAM4_EnsureDF()

    SVAR ImageWavePath = $(LJZ_IAM4_BaseDF() + ":ImageWavePath")
    Wave/Z src = $ImageWavePath

    if (!LJZ_IAM4_Is2DNumeric(src))
        DoAlert 0, "ImageWavePath is not a valid 2D numeric wave."
        Make/O/D/N=(2,2) $(LJZ_IAM4_OutputDF() + "InvalidInput") = NaN
        Wave invalid = $(LJZ_IAM4_OutputDF() + "InvalidInput")
        return invalid
    endif

    return src
End


Function/WAVE LJZ_IAM4_GetExistingImageWave()
    LJZ_IAM4_EnsureDF()

    String gName
    gName = LJZ_IAM4_GetGraphName(0)

    if (strlen(gName) == 0)
        DoAlert 0, "No graph found. Leave Graph empty to use the top graph, or enter a graph name."
        Make/O/D/N=(2,2) $(LJZ_IAM4_OutputDF() + "InvalidImageInput") = NaN
        Wave invalid0 = $(LJZ_IAM4_OutputDF() + "InvalidImageInput")
        return invalid0
    endif

    SVAR ExistingImageName = $(LJZ_IAM4_BaseDF() + ":ExistingImageName")

    if (strlen(ExistingImageName) == 0)
        LJZ_IAM4_UseFirstImage()
    endif

    if (strlen(ExistingImageName) == 0)
        DoAlert 0, "No image selected in the graph."
        Make/O/D/N=(2,2) $(LJZ_IAM4_OutputDF() + "InvalidImageInput") = NaN
        Wave invalid1 = $(LJZ_IAM4_OutputDF() + "InvalidImageInput")
        return invalid1
    endif

    String imgName
    imgName = ExistingImageName

    Wave/Z src = ImageNameToWaveRef(gName, imgName)

    if (!LJZ_IAM4_Is2DNumeric(src))
        DoAlert 0, "Selected graph image does not point to a valid 2D image wave."
        Make/O/D/N=(2,2) $(LJZ_IAM4_OutputDF() + "InvalidImageInput") = NaN
        Wave invalid2 = $(LJZ_IAM4_OutputDF() + "InvalidImageInput")
        return invalid2
    endif

    return src
End


Function LJZ_IAM4_AppendPathRaw()
    Wave src = LJZ_IAM4_GetWaveByPath()
    if (!LJZ_IAM4_Is2DNumeric(src))
        return -1
    endif

    Wave out = LJZ_IAM4_ProcessSourceWave(src, 0, 0)
    return LJZ_IAM4_AppendWaveToGraph(out)
End


Function LJZ_IAM4_AppendPathProcessed()
    Wave src = LJZ_IAM4_GetWaveByPath()
    if (!LJZ_IAM4_Is2DNumeric(src))
        return -1
    endif

    Wave out = LJZ_IAM4_ProcessSourceWave(src, 1, 1)
    return LJZ_IAM4_AppendWaveToGraph(out)
End


Function LJZ_IAM4_AppendExistingProcessed()
    Wave src = LJZ_IAM4_GetExistingImageWave()
    if (!LJZ_IAM4_Is2DNumeric(src))
        return -1
    endif

    Wave out = LJZ_IAM4_ProcessSourceWave(src, 1, 1)
    return LJZ_IAM4_AppendWaveToGraph(out)
End


Function LJZ_IAM4_EditExistingImage()
    LJZ_IAM4_EnsureDF()

    String gName
    gName = LJZ_IAM4_GetGraphName(0)

    if (strlen(gName) == 0)
        DoAlert 0, "No graph found."
        return -1
    endif

    SVAR ExistingImageName = $(LJZ_IAM4_BaseDF() + ":ExistingImageName")
    NVAR DeleteOutputWaveOnDelete = $(LJZ_IAM4_BaseDF() + ":DeleteOutputWaveOnDelete")

    if (strlen(ExistingImageName) == 0)
        DoAlert 0, "No image selected. Click Refresh images and select one image first."
        return -1
    endif

    String imgName
    imgName = ExistingImageName

    Wave src = LJZ_IAM4_GetExistingImageWave()
    if (!LJZ_IAM4_Is2DNumeric(src))
        return -1
    endif

    Wave out = LJZ_IAM4_ProcessSourceWave(src, 1, 1)

    LJZ_IAM4_RemoveImageAndMaybeKillWave(gName, imgName, DeleteOutputWaveOnDelete)
    AppendImage/W=$gName out

    NVAR AutoScaleGraph = $(LJZ_IAM4_BaseDF() + ":AutoScaleGraph")
    if (AutoScaleGraph)
        SetAxis/A/W=$gName
    endif

    Print "LJZ_IAM4 edited graph image: " + imgName + " -> " + NameOfWave(out)

    DoWindow/F $gName
    LJZ_IAM4_RefreshImageList()

    return 0
End


Function LJZ_IAM4_SetMaskFromCursors()
    LJZ_IAM4_EnsureDF()

    String gName
    gName = LJZ_IAM4_GetGraphName(0)

    if (strlen(gName) == 0)
        DoAlert 0, "No graph found."
        return -1
    endif

    NVAR MaskX1 = $(LJZ_IAM4_BaseDF() + ":MaskX1")
    NVAR MaskX2 = $(LJZ_IAM4_BaseDF() + ":MaskX2")
    NVAR MaskY1 = $(LJZ_IAM4_BaseDF() + ":MaskY1")
    NVAR MaskY2 = $(LJZ_IAM4_BaseDF() + ":MaskY2")

    Variable xa
    Variable xb
    Variable ya
    Variable yb

    xa = hcsr(A, gName)
    xb = hcsr(B, gName)
    ya = vcsr(A, gName)
    yb = vcsr(B, gName)

    if (numtype(xa) != 0 || numtype(xb) != 0 || numtype(ya) != 0 || numtype(yb) != 0)
        DoAlert 0, "Please place cursors A and B on the graph first."
        return -1
    endif

    MaskX1 = xa
    MaskX2 = xb
    MaskY1 = ya
    MaskY2 = yb

    String pName
    pName = LJZ_IAM4_PanelName()
    if (WinType(pName) != 0)
        ControlUpdate/A/W=$pName
    endif

    return 0
End


// ============================================================================
//  Section 5. callbacks
// ============================================================================

Function LJZ_IAM4_ListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if (lba.eventCode != 4)
        return 0
    endif

    LJZ_IAM4_SetSelectedImage(lba.row)

    String pName
    pName = LJZ_IAM4_PanelName()
    if (WinType(pName) != 0)
        ControlUpdate/A/W=$pName
    endif

    return 0
End


Function LJZ_IAM4_ButtonProc(ctrlName) : ButtonControl
    String ctrlName

    strswitch(ctrlName)
        case "btRefreshImages":
            LJZ_IAM4_RefreshImageList()
            break
        case "btUseFirst":
            LJZ_IAM4_UseFirstImage()
            break
        case "btDeleteImage":
            LJZ_IAM4_DeleteSelectedImage()
            break
        case "btAppendRaw":
            LJZ_IAM4_AppendPathRaw()
            break
        case "btAppendProc":
            LJZ_IAM4_AppendPathProcessed()
            break
        case "btAppendExisting":
            LJZ_IAM4_AppendExistingProcessed()
            break
        case "btEditExisting":
            LJZ_IAM4_EditExistingImage()
            break
        case "btCursor":
            LJZ_IAM4_SetMaskFromCursors()
            break
        case "btClose":
            DoWindow/K $(LJZ_IAM4_PanelName())
            break
    endswitch

    return 0
End


// ============================================================================
//  Section 6. panel
// ============================================================================

Function LJZ_IAM4_OpenPanel()
    LJZ_IAM4_EnsureDF()

    String p
    p = LJZ_IAM4_PanelName()

    DoWindow/F $p
    if (V_flag)
        LJZ_IAM4_RefreshImageList()
        return 0
    endif

    NewPanel/N=$p /W=(130,70,930,710) as "LJZ Image Append + Mask v4"
    ModifyPanel frameStyle=1
    ModifyPanel cbRGB=(60000,60000,60000)

    TitleBox tbTitle,pos={12,8},size={450,18},title="LJZ Image Append + Mask v4",frame=0
    TitleBox tbHint,pos={12,30},size={740,34},title="Leave Graph empty to use the top graph. Select existing images from the list; delete selected can also kill iam4 copied waves.",frame=0

    GroupBox gbInput,pos={12,72},size={765,130},title="Graph / source"
    SetVariable svGraph,pos={28,100},size={660,20},title="Graph"
    SetVariable svGraph,value=$(LJZ_IAM4_BaseDF() + ":GraphName")

    SetVariable svPath,pos={28,128},size={660,20},title="ImageWavePath"
    SetVariable svPath,value=$(LJZ_IAM4_BaseDF() + ":ImageWavePath")

    SetVariable svImgName,pos={28,156},size={420,20},title="Selected image"
    SetVariable svImgName,value=$(LJZ_IAM4_BaseDF() + ":ExistingImageName")

    SetVariable svSuffix,pos={470,156},size={180,20},title="Suffix"
    SetVariable svSuffix,value=$(LJZ_IAM4_BaseDF() + ":OutputSuffix")

    Button btRefreshImages,pos={28,178},size={100,22},title="Refresh images",proc=LJZ_IAM4_ButtonProc
    Button btUseFirst,pos={138,178},size={80,22},title="Use first",proc=LJZ_IAM4_ButtonProc
    Button btDeleteImage,pos={228,178},size={110,22},title="Delete selected",proc=LJZ_IAM4_ButtonProc
    CheckBox ckKillWave,pos={350,180},size={170,18},title="Kill iam4 wave too"
    CheckBox ckKillWave,variable=$(LJZ_IAM4_BaseDF() + ":DeleteOutputWaveOnDelete")

    GroupBox gbImages,pos={12,214},size={260,230},title="Images in graph"
    ListBox lbImages,pos={28,240},size={228,188},listWave=$(LJZ_IAM4_BaseDF() + ":ImgList"),selWave=$(LJZ_IAM4_BaseDF() + ":ImgSel"),mode=1,proc=LJZ_IAM4_ListBoxProc

    GroupBox gbMask,pos={292,214},size={230,230},title="Mask"
    CheckBox ckMask,pos={308,242},size={90,18},title="Enable"
    CheckBox ckMask,variable=$(LJZ_IAM4_BaseDF() + ":MaskEnable")

    SetVariable svMaskMode,pos={410,240},size={95,20},title="Mode"
    SetVariable svMaskMode,limits={1,2,1},value=$(LJZ_IAM4_BaseDF() + ":MaskMode")

    SetVariable svMX1,pos={308,270},size={95,20},title="x1"
    SetVariable svMX1,limits={-inf,inf,0.01},value=$(LJZ_IAM4_BaseDF() + ":MaskX1")

    SetVariable svMX2,pos={410,270},size={95,20},title="x2"
    SetVariable svMX2,limits={-inf,inf,0.01},value=$(LJZ_IAM4_BaseDF() + ":MaskX2")

    SetVariable svMY1,pos={308,298},size={95,20},title="y1"
    SetVariable svMY1,limits={-inf,inf,0.01},value=$(LJZ_IAM4_BaseDF() + ":MaskY1")

    SetVariable svMY2,pos={410,298},size={95,20},title="y2"
    SetVariable svMY2,limits={-inf,inf,0.01},value=$(LJZ_IAM4_BaseDF() + ":MaskY2")

    Button btCursor,pos={308,332},size={140,24},title="Mask from cursors",proc=LJZ_IAM4_ButtonProc
    TitleBox tbMask,pos={308,370},size={190,44},title="Mode 1 masks inside rectangle.\rMode 2 keeps only inside rectangle.",frame=0

    GroupBox gbSym,pos={542,214},size={205,108},title="Symmetry"
    SetVariable svSym,pos={558,242},size={130,20},title="SymMode"
    SetVariable svSym,limits={0,3,1},value=$(LJZ_IAM4_BaseDF() + ":SymMode")
    TitleBox tbSym,pos={558,270},size={160,44},title="0 none; 1 x-axis; 2 y-axis;\r3 center symmetry.",frame=0

    GroupBox gbPlace,pos={542,336},size={205,210},title="Placement for append"
    CheckBox ckStack,pos={558,364},size={115,18},title="Stack above"
    CheckBox ckStack,variable=$(LJZ_IAM4_BaseDF() + ":StackAbove")

    CheckBox ckAlign,pos={558,390},size={115,18},title="Align X"
    CheckBox ckAlign,variable=$(LJZ_IAM4_BaseDF() + ":AlignXToGraph")

    SetVariable svGap,pos={558,416},size={130,20},title="GapY"
    SetVariable svGap,limits={-inf,inf,0.01},value=$(LJZ_IAM4_BaseDF() + ":GapY")

    SetVariable svXS,pos={558,444},size={130,20},title="XShift"
    SetVariable svXS,limits={-inf,inf,0.01},value=$(LJZ_IAM4_BaseDF() + ":XShift")

    SetVariable svYS,pos={558,472},size={130,20},title="YShift"
    SetVariable svYS,limits={-inf,inf,0.01},value=$(LJZ_IAM4_BaseDF() + ":YShift")

    CheckBox ckAuto,pos={558,506},size={130,18},title="AutoScale graph"
    CheckBox ckAuto,variable=$(LJZ_IAM4_BaseDF() + ":AutoScaleGraph")

    GroupBox gbOverride,pos={292,458},size={230,112},title="Override scale"
    CheckBox ckOver,pos={308,486},size={125,18},title="Override scale"
    CheckBox ckOver,variable=$(LJZ_IAM4_BaseDF() + ":OverrideScale")

    SetVariable svNX1,pos={308,514},size={95,20},title="new x1"
    SetVariable svNX1,limits={-inf,inf,0.01},value=$(LJZ_IAM4_BaseDF() + ":NewX1")

    SetVariable svNX2,pos={410,514},size={95,20},title="new x2"
    SetVariable svNX2,limits={-inf,inf,0.01},value=$(LJZ_IAM4_BaseDF() + ":NewX2")

    SetVariable svNY1,pos={308,542},size={95,20},title="new y1"
    SetVariable svNY1,limits={-inf,inf,0.01},value=$(LJZ_IAM4_BaseDF() + ":NewY1")

    SetVariable svNY2,pos={410,542},size={95,20},title="new y2"
    SetVariable svNY2,limits={-inf,inf,0.01},value=$(LJZ_IAM4_BaseDF() + ":NewY2")

    GroupBox gbRun,pos={12,466},size={260,104},title="Run"
    Button btAppendRaw,pos={28,494},size={110,26},title="Append path raw",proc=LJZ_IAM4_ButtonProc
    Button btAppendProc,pos={148,494},size={110,26},title="Append path proc",proc=LJZ_IAM4_ButtonProc
    Button btAppendExisting,pos={28,532},size={110,26},title="Append selected",proc=LJZ_IAM4_ButtonProc
    Button btEditExisting,pos={148,532},size={110,26},title="Replace selected",proc=LJZ_IAM4_ButtonProc

    Button btClose,pos={646,584},size={90,28},title="Close",proc=LJZ_IAM4_ButtonProc

    TitleBox tbUse,pos={28,590},size={680,56},title="Recommended: Refresh images -> select one image -> Append selected to test. Use Replace selected only after confirming the result.\rDelete selected removes the image. If Kill iam4 wave too is checked, copied iam4_* waves are also killed.",frame=0

    LJZ_IAM4_RefreshImageList()

    return 0
End
