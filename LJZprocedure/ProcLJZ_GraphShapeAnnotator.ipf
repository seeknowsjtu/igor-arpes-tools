#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma DefaultTab={3,20,4}

// ============================================================================
//  LJZ Graph Shape Annotator v3 - fixed stable build
//
//  Main fixes in this build:
//    1) No repeated local NVAR/Z or SVAR/Z declarations in EnsureDF.
//    2) No inline if/for/do syntax.
//    3) Circle/Ellipse and Triangle tabs use independent cx/cy controls.
//    4) polyX/polyY are assigned point-by-point.
//    5) Color preview uses TitleBox labelBack.
//    6) Fill color has full RGB controls, including fillB.
//    7) Drawing is fixed to ProgFront so Undo/Clear are stable.
//    8) Panel is rebuilt when opened, avoiding stale old controls.
//    9) Tab 1/2 controls are created with disable=1 (hidden) to avoid initial overlap.
// ============================================================================

Menu "ARPES_LJZ"
    "Graph Shape Annotator v3", LJZ_GSA2_OpenPanel()
    "Clear Graph Shape Layer v3", LJZ_GSA2_ClearTopGraphDrawings()
End

// ============================================================================
//  Section 0. Paths and names
// ============================================================================

Function/S LJZ_GSA2_BaseDF()
    return "root:Packages:LJZ_GraphShapeAnnotatorV3"
End

Function/S LJZ_GSA2_PanelName()
    return "LJZ_GraphShapeAnnotatorV3_Panel"
End

// ============================================================================
//  Section 1. Safe global variable helpers
// ============================================================================

Function LJZ_GSA2_EnsureNumVar(varName, defaultValue)
    String varName
    Variable defaultValue

    String fullPath = LJZ_GSA2_BaseDF() + ":" + varName
    NVAR/Z nv = $fullPath
    if (!NVAR_Exists(nv))
        Variable/G $fullPath = defaultValue
    endif
    return 0
End

Function LJZ_GSA2_EnsureStrVar(varName, defaultText)
    String varName
    String defaultText

    String fullPath = LJZ_GSA2_BaseDF() + ":" + varName
    SVAR/Z sv = $fullPath
    if (!SVAR_Exists(sv))
        String/G $fullPath = defaultText
    endif
    return 0
End

Function LJZ_GSA2_EnsureDF()
    NewDataFolder/O root:Packages
    NewDataFolder/O $(LJZ_GSA2_BaseDF())

    LJZ_GSA2_EnsureNumVar("x1", -0.5)
    LJZ_GSA2_EnsureNumVar("y1", 0)
    LJZ_GSA2_EnsureNumVar("x2", 0.5)
    LJZ_GSA2_EnsureNumVar("y2", 0)

    LJZ_GSA2_EnsureNumVar("cx", 0)
    LJZ_GSA2_EnsureNumVar("cy", 0)
    LJZ_GSA2_EnsureNumVar("rx", 0.1)
    LJZ_GSA2_EnsureNumVar("ry", 0.3)
    LJZ_GSA2_EnsureNumVar("radius", 0.2)

    LJZ_GSA2_EnsureNumVar("tx1", 0)
    LJZ_GSA2_EnsureNumVar("ty1", 0)
    LJZ_GSA2_EnsureNumVar("tx2", 0.2)
    LJZ_GSA2_EnsureNumVar("ty2", 0)
    LJZ_GSA2_EnsureNumVar("tx3", 0.1)
    LJZ_GSA2_EnsureNumVar("ty3", 0.2)

    LJZ_GSA2_EnsureNumVar("triWidth", 1)
    LJZ_GSA2_EnsureNumVar("triHeight", 1)
    LJZ_GSA2_EnsureNumVar("triDir", 0)

    LJZ_GSA2_EnsureNumVar("red", 0)
    LJZ_GSA2_EnsureNumVar("green", 0)
    LJZ_GSA2_EnsureNumVar("blue", 0)
    LJZ_GSA2_EnsureNumVar("lineThick", 2)
    LJZ_GSA2_EnsureNumVar("dash", 0)
    LJZ_GSA2_EnsureNumVar("fillPat", 0)
    LJZ_GSA2_EnsureNumVar("drawFront", 1)

    LJZ_GSA2_EnsureStrVar("lockedGraph", "")
    LJZ_GSA2_EnsureNumVar("undoCount", 0)
    LJZ_GSA2_EnsureStrVar("undoNames", "")
    LJZ_GSA2_EnsureStrVar("undoLayers", "")
    LJZ_GSA2_EnsureNumVar("activeTab", 0)
    LJZ_GSA2_EnsureNumVar("shapeID", 0)

    LJZ_GSA2_EnsureNumVar("fillR", 0)
    LJZ_GSA2_EnsureNumVar("fillG", 0)
    LJZ_GSA2_EnsureNumVar("fillB", 0)
    LJZ_GSA2_EnsureNumVar("useSepFill", 0)

    Make/O/D/N=4 $(LJZ_GSA2_BaseDF() + ":polyX")
    Make/O/D/N=4 $(LJZ_GSA2_BaseDF() + ":polyY")
    return 0
End

// ============================================================================
//  Section 2. Target graph
// ============================================================================

Function/S LJZ_GSA2_GetTopGraph()
    String gName = WinName(0, 1)
    if (strlen(gName) == 0)
        DoAlert 0, "No graph window found. Please activate a graph first."
        return ""
    endif
    return gName
End

Function/S LJZ_GSA2_GetTargetGraph()
    LJZ_GSA2_EnsureDF()

    SVAR lockedGraph = $(LJZ_GSA2_BaseDF() + ":lockedGraph")
    if (strlen(lockedGraph) > 0)
        DoWindow/F $lockedGraph
        if (V_flag == 1)
            return lockedGraph
        endif
    endif
    return LJZ_GSA2_GetTopGraph()
End

// ============================================================================
//  Section 3. Utility functions
// ============================================================================

Function LJZ_GSA2_ClampColor(v)
    Variable v

    if (numtype(v) != 0)
        return 0
    endif
    if (v < 0)
        return 0
    endif
    if (v > 65535)
        return 65535
    endif
    return round(v)
End

Function LJZ_GSA2_Abs(v)
    Variable v

    if (numtype(v) != 0)
        return 0
    endif
    if (v < 0)
        return -v
    endif
    return v
End

Function LJZ_GSA2_GetBox(xx1, yy1, xx2, yy2)
    Variable &xx1, &yy1, &xx2, &yy2

    LJZ_GSA2_EnsureDF()
    String base = LJZ_GSA2_BaseDF()

    NVAR x1 = $(base + ":x1")
    NVAR y1 = $(base + ":y1")
    NVAR x2 = $(base + ":x2")
    NVAR y2 = $(base + ":y2")

    xx1 = min(x1, x2)
    xx2 = max(x1, x2)
    yy1 = min(y1, y2)
    yy2 = max(y1, y2)
    return 0
End

// ============================================================================
//  Section 4. Undo stack
// ============================================================================

Function/S LJZ_GSA2_NewGroupName()
    LJZ_GSA2_EnsureDF()

    NVAR shapeID = $(LJZ_GSA2_BaseDF() + ":shapeID")
    shapeID += 1

    String gn
    gn = "GSA_" + num2str(shapeID)
    return gn
End

Function LJZ_GSA2_RegisterUndo(groupName)
    String groupName

    if (strlen(groupName) == 0)
        return 0
    endif

    LJZ_GSA2_EnsureDF()
    NVAR undoCount = $(LJZ_GSA2_BaseDF() + ":undoCount")
    SVAR undoNames = $(LJZ_GSA2_BaseDF() + ":undoNames")
    SVAR undoLayers = $(LJZ_GSA2_BaseDF() + ":undoLayers")

    undoNames = AddListItem(groupName, undoNames, ";", Inf)
    undoLayers = AddListItem("ProgFront", undoLayers, ";", Inf)
    undoCount += 1

    do
        if (undoCount <= 20)
            break
        endif
        undoNames = RemoveFromList(StringFromList(0, undoNames, ";"), undoNames, ";")
        undoLayers = RemoveFromList(StringFromList(0, undoLayers, ";"), undoLayers, ";")
        undoCount -= 1
    while (1)

    return 0
End

Function LJZ_GSA2_ResetUndo()
    LJZ_GSA2_EnsureDF()

    NVAR undoCount = $(LJZ_GSA2_BaseDF() + ":undoCount")
    SVAR undoNames = $(LJZ_GSA2_BaseDF() + ":undoNames")
    SVAR undoLayers = $(LJZ_GSA2_BaseDF() + ":undoLayers")

    undoCount = 0
    undoNames = ""
    undoLayers = ""
    return 0
End

Function LJZ_GSA2_Undo()
    LJZ_GSA2_EnsureDF()

    NVAR undoCount = $(LJZ_GSA2_BaseDF() + ":undoCount")
    SVAR undoNames = $(LJZ_GSA2_BaseDF() + ":undoNames")
    SVAR undoLayers = $(LJZ_GSA2_BaseDF() + ":undoLayers")

    if (undoCount <= 0)
        Beep
        return -1
    endif

    String groupName = StringFromList(undoCount - 1, undoNames, ";")
    String layerName = StringFromList(undoCount - 1, undoLayers, ";")

    undoNames = RemoveFromList(groupName, undoNames, ";")
    undoLayers = RemoveFromList(layerName, undoLayers, ";")
    undoCount -= 1

    String gName = LJZ_GSA2_GetTargetGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    // This stable build draws only on ProgFront.
    DrawAction/W=$gName/L=ProgFront getgroup=$groupName
    if (V_flag)
        DrawAction/W=$gName/L=ProgFront getgroup=$groupName, delete
    endif
    return 0
End

// ============================================================================
//  Section 5. Draw environment
// ============================================================================

Function LJZ_GSA2_SetDrawEnv(gName)
    String gName

    LJZ_GSA2_EnsureDF()
    String base = LJZ_GSA2_BaseDF()

    NVAR red        = $(base + ":red")
    NVAR green      = $(base + ":green")
    NVAR blue       = $(base + ":blue")
    NVAR fillR      = $(base + ":fillR")
    NVAR fillG      = $(base + ":fillG")
    NVAR fillB      = $(base + ":fillB")
    NVAR useSepFill = $(base + ":useSepFill")
    NVAR lineThick  = $(base + ":lineThick")
    NVAR dash       = $(base + ":dash")
    NVAR fillPat    = $(base + ":fillPat")

    Variable r  = LJZ_GSA2_ClampColor(red)
    Variable g  = LJZ_GSA2_ClampColor(green)
    Variable b  = LJZ_GSA2_ClampColor(blue)
    Variable fr
    Variable fg
    Variable fb

    if (useSepFill == 1)
        fr = LJZ_GSA2_ClampColor(fillR)
        fg = LJZ_GSA2_ClampColor(fillG)
        fb = LJZ_GSA2_ClampColor(fillB)
    else
        fr = r
        fg = g
        fb = b
    endif

    Variable lt = lineThick
    Variable ds = round(dash)
    Variable fp = round(fillPat)

    if (numtype(lt) != 0 || lt <= 0)
        lt = 1
    endif
    if (numtype(ds) != 0 || ds < 0)
        ds = 0
    endif
    if (numtype(fp) != 0 || fp < 0)
        fp = 0
    endif

    // Stable build: always draw to ProgFront so Undo and Clear remain reliable.
    SetDrawLayer/W=$gName ProgFront
    SetDrawEnv/W=$gName xcoord=bottom, ycoord=left, linefgc=(r,g,b), fillfgc=(fr,fg,fb), linethick=lt, dash=ds, fillpat=fp
    return 0
End

// ============================================================================
//  Section 6. Drawing functions
// ============================================================================

Function LJZ_GSA2_AddLine()
    LJZ_GSA2_EnsureDF()

    String gName = LJZ_GSA2_GetTargetGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    String base = LJZ_GSA2_BaseDF()
    NVAR x1 = $(base + ":x1")
    NVAR y1 = $(base + ":y1")
    NVAR x2 = $(base + ":x2")
    NVAR y2 = $(base + ":y2")

    String gn = LJZ_GSA2_NewGroupName()
    LJZ_GSA2_SetDrawEnv(gName)
    SetDrawEnv/W=$gName gstart, gname=$gn
    DrawLine/W=$gName x1, y1, x2, y2
    SetDrawEnv/W=$gName gstop
    LJZ_GSA2_RegisterUndo(gn)
    return 0
End

Function LJZ_GSA2_AddRectangleByBox()
    LJZ_GSA2_EnsureDF()

    String gName = LJZ_GSA2_GetTargetGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    Variable xx1, yy1, xx2, yy2
    LJZ_GSA2_GetBox(xx1, yy1, xx2, yy2)

    String gn = LJZ_GSA2_NewGroupName()
    LJZ_GSA2_SetDrawEnv(gName)
    SetDrawEnv/W=$gName gstart, gname=$gn
    DrawRect/W=$gName xx1, yy1, xx2, yy2
    SetDrawEnv/W=$gName gstop
    LJZ_GSA2_RegisterUndo(gn)
    return 0
End

Function LJZ_GSA2_AddEllipseByBox()
    LJZ_GSA2_EnsureDF()

    String gName = LJZ_GSA2_GetTargetGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    Variable xx1, yy1, xx2, yy2
    LJZ_GSA2_GetBox(xx1, yy1, xx2, yy2)

    String gn = LJZ_GSA2_NewGroupName()
    LJZ_GSA2_SetDrawEnv(gName)
    SetDrawEnv/W=$gName gstart, gname=$gn
    DrawOval/W=$gName xx1, yy1, xx2, yy2
    SetDrawEnv/W=$gName gstop
    LJZ_GSA2_RegisterUndo(gn)
    return 0
End

Function LJZ_GSA2_AddEllipseByCenter()
    LJZ_GSA2_EnsureDF()

    String gName = LJZ_GSA2_GetTargetGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    String base = LJZ_GSA2_BaseDF()
    NVAR cx = $(base + ":cx")
    NVAR cy = $(base + ":cy")
    NVAR rx = $(base + ":rx")
    NVAR ry = $(base + ":ry")

    Variable rxx = LJZ_GSA2_Abs(rx)
    Variable ryy = LJZ_GSA2_Abs(ry)
    Variable xx1 = cx - rxx
    Variable xx2 = cx + rxx
    Variable yy1 = cy - ryy
    Variable yy2 = cy + ryy

    String gn = LJZ_GSA2_NewGroupName()
    LJZ_GSA2_SetDrawEnv(gName)
    SetDrawEnv/W=$gName gstart, gname=$gn
    DrawOval/W=$gName xx1, yy1, xx2, yy2
    SetDrawEnv/W=$gName gstop
    LJZ_GSA2_RegisterUndo(gn)
    return 0
End

Function LJZ_GSA2_AddCircleByCenter()
    LJZ_GSA2_EnsureDF()

    String gName = LJZ_GSA2_GetTargetGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    String base = LJZ_GSA2_BaseDF()
    NVAR cx = $(base + ":cx")
    NVAR cy = $(base + ":cy")
    NVAR radius = $(base + ":radius")
    Variable rr = LJZ_GSA2_Abs(radius)

    String gn = LJZ_GSA2_NewGroupName()
    LJZ_GSA2_SetDrawEnv(gName)
    SetDrawEnv/W=$gName gstart, gname=$gn
    DrawOval/W=$gName cx - rr, cy - rr, cx + rr, cy + rr
    SetDrawEnv/W=$gName gstop
    LJZ_GSA2_RegisterUndo(gn)
    return 0
End

Function LJZ_GSA2_AddTriangleByBox()
    LJZ_GSA2_EnsureDF()

    String gName = LJZ_GSA2_GetTargetGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    Variable xx1, yy1, xx2, yy2
    LJZ_GSA2_GetBox(xx1, yy1, xx2, yy2)

    Variable width  = xx2 - xx1
    Variable height = yy2 - yy1

    Wave polyX = $(LJZ_GSA2_BaseDF() + ":polyX")
    Wave polyY = $(LJZ_GSA2_BaseDF() + ":polyY")

    polyX[0] = 0
    polyY[0] = 0
    polyX[1] = width
    polyY[1] = 0
    polyX[2] = 0.5 * width
    polyY[2] = height
    polyX[3] = 0
    polyY[3] = 0

    String gn = LJZ_GSA2_NewGroupName()
    LJZ_GSA2_SetDrawEnv(gName)
    SetDrawEnv/W=$gName gstart, gname=$gn
    DrawPoly/W=$gName xx1, yy1, 1, 1, polyX, polyY
    SetDrawEnv/W=$gName gstop
    LJZ_GSA2_RegisterUndo(gn)
    return 0
End

Function LJZ_GSA2_AddTriangleBy3Points()
    LJZ_GSA2_EnsureDF()

    String gName = LJZ_GSA2_GetTargetGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    String base = LJZ_GSA2_BaseDF()
    NVAR tx1 = $(base + ":tx1")
    NVAR ty1 = $(base + ":ty1")
    NVAR tx2 = $(base + ":tx2")
    NVAR ty2 = $(base + ":ty2")
    NVAR tx3 = $(base + ":tx3")
    NVAR ty3 = $(base + ":ty3")

    Wave polyX = $(base + ":polyX")
    Wave polyY = $(base + ":polyY")

    polyX[0] = 0
    polyY[0] = 0
    polyX[1] = tx2 - tx1
    polyY[1] = ty2 - ty1
    polyX[2] = tx3 - tx1
    polyY[2] = ty3 - ty1
    polyX[3] = 0
    polyY[3] = 0

    String gn = LJZ_GSA2_NewGroupName()
    LJZ_GSA2_SetDrawEnv(gName)
    SetDrawEnv/W=$gName gstart, gname=$gn
    DrawPoly/W=$gName tx1, ty1, 1, 1, polyX, polyY
    SetDrawEnv/W=$gName gstop
    LJZ_GSA2_RegisterUndo(gn)
    return 0
End

Function LJZ_GSA2_AddTriangleByCenter()
    LJZ_GSA2_EnsureDF()

    String gName = LJZ_GSA2_GetTargetGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    String base = LJZ_GSA2_BaseDF()
    NVAR cx = $(base + ":cx")
    NVAR cy = $(base + ":cy")
    NVAR triWidth = $(base + ":triWidth")
    NVAR triHeight = $(base + ":triHeight")
    NVAR triDir = $(base + ":triDir")

    Variable halfW = 0.5 * LJZ_GSA2_Abs(triWidth)
    Variable halfH = 0.5 * LJZ_GSA2_Abs(triHeight)
    Variable dir = round(triDir)

    Wave polyX = $(base + ":polyX")
    Wave polyY = $(base + ":polyY")

    if (dir == 1)
        // Down
        polyX[0] = -halfW
        polyY[0] =  halfH
        polyX[1] =  halfW
        polyY[1] =  halfH
        polyX[2] =  0
        polyY[2] = -halfH
    elseif (dir == 2)
        // Right
        polyX[0] = -halfW
        polyY[0] = -halfH
        polyX[1] = -halfW
        polyY[1] =  halfH
        polyX[2] =  halfW
        polyY[2] =  0
    elseif (dir == 3)
        // Left
        polyX[0] =  halfW
        polyY[0] = -halfH
        polyX[1] =  halfW
        polyY[1] =  halfH
        polyX[2] = -halfW
        polyY[2] =  0
    else
        // Up
        polyX[0] = -halfW
        polyY[0] = -halfH
        polyX[1] =  halfW
        polyY[1] = -halfH
        polyX[2] =  0
        polyY[2] =  halfH
    endif

    polyX[3] = polyX[0]
    polyY[3] = polyY[0]

    String gn = LJZ_GSA2_NewGroupName()
    LJZ_GSA2_SetDrawEnv(gName)
    SetDrawEnv/W=$gName gstart, gname=$gn
    DrawPoly/W=$gName cx, cy, 1, 1, polyX, polyY
    SetDrawEnv/W=$gName gstop
    LJZ_GSA2_RegisterUndo(gn)
    return 0
End

// ============================================================================
//  Section 7. Clear and color presets
// ============================================================================

Function LJZ_GSA2_ClearTopGraphDrawings()
    String gName = LJZ_GSA2_GetTargetGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    SetDrawLayer/K/W=$gName ProgFront
    LJZ_GSA2_ResetUndo()
    Print "LJZ_GSA2: cleared ProgFront in: " + gName
    return 0
End

Function LJZ_GSA2_SetColor(newR, newG, newB)
    Variable newR, newG, newB

    LJZ_GSA2_EnsureDF()
    String base = LJZ_GSA2_BaseDF()
    NVAR red   = $(base + ":red")
    NVAR green = $(base + ":green")
    NVAR blue  = $(base + ":blue")

    red   = LJZ_GSA2_ClampColor(newR)
    green = LJZ_GSA2_ClampColor(newG)
    blue  = LJZ_GSA2_ClampColor(newB)

    LJZ_GSA2_RefreshColorPreview()
    return 0
End

Function LJZ_GSA2_RedPreset()
    LJZ_GSA2_SetColor(65535, 0, 0)
    return 0
End

Function LJZ_GSA2_BluePreset()
    LJZ_GSA2_SetColor(0, 20000, 65535)
    return 0
End

Function LJZ_GSA2_WhitePreset()
    LJZ_GSA2_SetColor(65535, 65535, 65535)
    return 0
End

Function LJZ_GSA2_BlackPreset()
    LJZ_GSA2_SetColor(0, 0, 0)
    return 0
End

Function LJZ_GSA2_YellowPreset()
    LJZ_GSA2_SetColor(65535, 52000, 0)
    return 0
End

// ============================================================================
//  Section 8. Preview refresh
// ============================================================================

Function LJZ_GSA2_RefreshColorPreview()
    String p = LJZ_GSA2_PanelName()
    DoWindow $p
    if (!V_flag)
        return 0
    endif

    String base = LJZ_GSA2_BaseDF()
    NVAR red        = $(base + ":red")
    NVAR green      = $(base + ":green")
    NVAR blue       = $(base + ":blue")
    NVAR fillR      = $(base + ":fillR")
    NVAR fillG      = $(base + ":fillG")
    NVAR fillB      = $(base + ":fillB")
    NVAR useSepFill = $(base + ":useSepFill")

    Variable r  = LJZ_GSA2_ClampColor(red)
    Variable g  = LJZ_GSA2_ClampColor(green)
    Variable b  = LJZ_GSA2_ClampColor(blue)
    Variable fr
    Variable fg
    Variable fb

    if (useSepFill == 1)
        fr = LJZ_GSA2_ClampColor(fillR)
        fg = LJZ_GSA2_ClampColor(fillG)
        fb = LJZ_GSA2_ClampColor(fillB)
    else
        fr = r
        fg = g
        fb = b
    endif

    TitleBox tbColorPrev, win=$p, title=" ", labelBack=(r,g,b)
    TitleBox tbFillPrev,  win=$p, title=" ", labelBack=(fr,fg,fb)
    return 0
End

// ============================================================================
//  Section 9. Control callbacks
// ============================================================================

Function LJZ_GSA2_SVProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    if (sva.eventCode != 1 && sva.eventCode != 2 && sva.eventCode != 8)
        return 0
    endif

    LJZ_GSA2_RefreshColorPreview()
    return 0
End

Function LJZ_GSA2_CheckProc(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba

    if (cba.eventCode != 2)
        return 0
    endif

    if (CmpStr(cba.ctrlName, "ckSepFill") != 0)
        return 0
    endif

    String p = LJZ_GSA2_PanelName()
    Variable dis
    if (cba.checked)
        dis = 0
    else
        dis = 1
    endif

    SetVariable svFillR,    win=$p, disable=dis
    SetVariable svFillG,    win=$p, disable=dis
    SetVariable svFillB,    win=$p, disable=dis
    TitleBox    tbFillPrev, win=$p, disable=dis

    LJZ_GSA2_RefreshColorPreview()
    return 0
End

Function LJZ_GSA2_PopupProc(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa

    if (pa.eventCode != 2)
        return 0
    endif

    if (CmpStr(pa.ctrlName, "pmTriDir") != 0)
        return 0
    endif

    NVAR triDir = $(LJZ_GSA2_BaseDF() + ":triDir")
    triDir = pa.popNum - 1
    return 0
End

Function LJZ_GSA2_TabProc(tca) : TabControl
    STRUCT WMTabControlAction &tca

    if (tca.eventCode != 2)
        return 0
    endif

    NVAR activeTab = $(LJZ_GSA2_BaseDF() + ":activeTab")
    activeTab = tca.tab
    LJZ_GSA2_UpdateTabVisibility()
    return 0
End

// ============================================================================
//  Section 10. Tab visibility
//  Igor controls: disable=1 means hidden; disable=2 only disables user input.
// ============================================================================

Function LJZ_GSA2_UpdateTabVisibility()
    String p = LJZ_GSA2_PanelName()
    DoWindow $p
    if (!V_flag)
        return 0
    endif

    NVAR activeTab = $(LJZ_GSA2_BaseDF() + ":activeTab")

    Variable d0 = 1
    Variable d1 = 1
    Variable d2 = 1

    if (activeTab == 0)
        d0 = 0
    endif
    if (activeTab == 1)
        d1 = 0
    endif
    if (activeTab == 2)
        d2 = 0
    endif

    // Tab 0: Line / Box
    SetVariable svX1,         win=$p, disable=d0
    SetVariable svY1,         win=$p, disable=d0
    SetVariable svX2,         win=$p, disable=d0
    SetVariable svY2,         win=$p, disable=d0
    Button      btLine,       win=$p, disable=d0
    Button      btRect,       win=$p, disable=d0
    Button      btEllipseBox, win=$p, disable=d0

    // Tab 1: Circle / Ellipse, with its own cx/cy controls.
    SetVariable svCX_c,          win=$p, disable=d1
    SetVariable svCY_c,          win=$p, disable=d1
    SetVariable svRX,            win=$p, disable=d1
    SetVariable svRY,            win=$p, disable=d1
    SetVariable svRad,           win=$p, disable=d1
    Button      btEllipseCenter, win=$p, disable=d1
    Button      btCircleCenter,  win=$p, disable=d1

    // Tab 2: Triangle, with its own cx/cy controls bound to the same NVARs.
    SetVariable svCX_t,      win=$p, disable=d2
    SetVariable svCY_t,      win=$p, disable=d2
    TitleBox    tbT3,        win=$p, disable=d2
    SetVariable svTX1,       win=$p, disable=d2
    SetVariable svTY1,       win=$p, disable=d2
    SetVariable svTX2,       win=$p, disable=d2
    SetVariable svTY2,       win=$p, disable=d2
    SetVariable svTX3,       win=$p, disable=d2
    SetVariable svTY3,       win=$p, disable=d2
    Button      btTri3P,     win=$p, disable=d2
    Button      btTriBox,    win=$p, disable=d2
    TitleBox    tbTC,        win=$p, disable=d2
    SetVariable svTriW,      win=$p, disable=d2
    SetVariable svTriH,      win=$p, disable=d2
    PopupMenu   pmTriDir,    win=$p, disable=d2
    Button      btTriCenter, win=$p, disable=d2

    return 0
End

// ============================================================================
//  Section 11. Panel
// ============================================================================

Function LJZ_GSA2_OpenPanel()
    LJZ_GSA2_EnsureDF()

    String p = LJZ_GSA2_PanelName()
    String base = LJZ_GSA2_BaseDF()

    // Always rebuild the panel so stale controls from older builds do not survive.
    DoWindow $p
    if (V_flag)
        DoWindow/K $p
    endif

    NVAR activeTab = $(base + ":activeTab")
    activeTab = 0

    NewPanel/N=$p /W=(150,60,635,590) as "LJZ Graph Shape Annotator v3"
    ModifyPanel cbRGB=(60000,60000,60000)

    GroupBox gbHeader, pos={8,8}, size={468,54}, title=""
    TitleBox tbTitle, pos={18,16}, size={190,18}, title="Graph Shape Annotator v3", frame=0, fStyle=1, fSize=13
    TitleBox tbHint,  pos={18,38}, size={220,14}, title="Axis-coordinate drawing helper", frame=0, fSize=9

    Button btLock,  pos={260,16}, size={74,22}, title="Lock",  proc=LJZ_GSA2_ButtonProc
    Button btUndo,  pos={340,16}, size={58,22}, title="Undo",  proc=LJZ_GSA2_ButtonProc
    Button btClear, pos={404,16}, size={58,22}, title="Clear", proc=LJZ_GSA2_ButtonProc
    TitleBox tbLockedName, pos={260,40}, size={150,16}, title="unlocked", frame=0, fSize=9
    Button btClose, pos={416,40}, size={46,18}, title="Close", proc=LJZ_GSA2_ButtonProc

    GroupBox gbShape, pos={8,70}, size={468,300}, title="Shape"
    TabControl tcShape, pos={18,92}, size={448,258}, proc=LJZ_GSA2_TabProc
    TabControl tcShape, tabLabel(0)="Line / Box", tabLabel(1)="Circle / Ellipse", tabLabel(2)="Triangle", value=0

    // Tab 0: line / box
    SetVariable svX1, pos={38,130}, size={145,20}, title="x1", limits={-inf,inf,0.01}, value=$(base+":x1")
    SetVariable svY1, pos={198,130}, size={145,20}, title="y1", limits={-inf,inf,0.01}, value=$(base+":y1")
    SetVariable svX2, pos={38,158}, size={145,20}, title="x2", limits={-inf,inf,0.01}, value=$(base+":x2")
    SetVariable svY2, pos={198,158}, size={145,20}, title="y2", limits={-inf,inf,0.01}, value=$(base+":y2")

    Button btLine,       pos={38,198},  size={86,26}, title="Line",     proc=LJZ_GSA2_ButtonProc
    Button btRect,       pos={134,198}, size={86,26}, title="Rect",     proc=LJZ_GSA2_ButtonProc
    Button btEllipseBox, pos={230,198}, size={92,26}, title="OvalBox",  proc=LJZ_GSA2_ButtonProc

    // Tab 1: circle / ellipse. Created hidden to prevent initial overlap before UpdateTabVisibility().
    SetVariable svCX_c, pos={38,130},  size={145,20}, title="cx", limits={-inf,inf,0.01}, value=$(base+":cx"), disable=1
    SetVariable svCY_c, pos={198,130}, size={145,20}, title="cy", limits={-inf,inf,0.01}, value=$(base+":cy"), disable=1

    SetVariable svRX,  pos={38,166},  size={145,20}, title="rx",     limits={0,inf,0.01}, value=$(base+":rx"), disable=1
    SetVariable svRY,  pos={198,166}, size={145,20}, title="ry",     limits={0,inf,0.01}, value=$(base+":ry"), disable=1
    SetVariable svRad, pos={38,194},  size={145,20}, title="radius", limits={0,inf,0.01}, value=$(base+":radius"), disable=1

    Button btEllipseCenter, pos={38,232},  size={100,26}, title="Ellipse", proc=LJZ_GSA2_ButtonProc, disable=1
    Button btCircleCenter,  pos={148,232}, size={100,26}, title="Circle",  proc=LJZ_GSA2_ButtonProc, disable=1

    // Tab 2: triangle. Created hidden to prevent initial overlap before UpdateTabVisibility().
    SetVariable svCX_t, pos={38,130},  size={145,20}, title="cx", limits={-inf,inf,0.01}, value=$(base+":cx"), disable=1
    SetVariable svCY_t, pos={198,130}, size={145,20}, title="cy", limits={-inf,inf,0.01}, value=$(base+":cy"), disable=1

    TitleBox tbT3, pos={38,160}, size={120,16}, title="3 vertices", frame=0, fStyle=1, fSize=10, disable=1
    SetVariable svTX1, pos={38,182},  size={135,20}, title="x1", limits={-inf,inf,0.01}, value=$(base+":tx1"), disable=1
    SetVariable svTY1, pos={184,182}, size={135,20}, title="y1", limits={-inf,inf,0.01}, value=$(base+":ty1"), disable=1
    SetVariable svTX2, pos={38,206},  size={135,20}, title="x2", limits={-inf,inf,0.01}, value=$(base+":tx2"), disable=1
    SetVariable svTY2, pos={184,206}, size={135,20}, title="y2", limits={-inf,inf,0.01}, value=$(base+":ty2"), disable=1
    SetVariable svTX3, pos={38,230},  size={135,20}, title="x3", limits={-inf,inf,0.01}, value=$(base+":tx3"), disable=1
    SetVariable svTY3, pos={184,230}, size={135,20}, title="y3", limits={-inf,inf,0.01}, value=$(base+":ty3"), disable=1

    Button btTri3P,  pos={334,184}, size={92,24}, title="Tri 3P",  proc=LJZ_GSA2_ButtonProc, disable=1
    Button btTriBox, pos={334,212}, size={92,24}, title="Tri Box", proc=LJZ_GSA2_ButtonProc, disable=1

    TitleBox tbTC, pos={38,264}, size={220,16}, title="Center mode uses cx / cy above", frame=0, fStyle=1, fSize=10, disable=1
    SetVariable svTriW, pos={38,286},  size={135,20}, title="w", limits={0,inf,0.01}, value=$(base+":triWidth"), disable=1
    SetVariable svTriH, pos={184,286}, size={135,20}, title="h", limits={0,inf,0.01}, value=$(base+":triHeight"), disable=1
    PopupMenu pmTriDir, pos={334,284}, size={120,22}, title="", value="Up;Down;Right;Left", proc=LJZ_GSA2_PopupProc, disable=1
    Button btTriCenter, pos={334,312}, size={92,24}, title="Tri Center", proc=LJZ_GSA2_ButtonProc, disable=1

    // Style area
    GroupBox gbStyle, pos={8,382}, size={468,138}, title="Style"

    TitleBox tbStrokeLabel, pos={20,404}, size={80,14}, title="Stroke", frame=0, fStyle=1, fSize=10
    TitleBox tbColorPrev, pos={20,424}, size={34,34}, title=" ", frame=1, labelBack=(0,0,0)

    SetVariable svR, pos={62,400}, size={102,18}, title="R", limits={0,65535,1000}, value=$(base+":red"),   proc=LJZ_GSA2_SVProc
    SetVariable svG, pos={62,422}, size={102,18}, title="G", limits={0,65535,1000}, value=$(base+":green"), proc=LJZ_GSA2_SVProc
    SetVariable svB, pos={62,444}, size={102,18}, title="B", limits={0,65535,1000}, value=$(base+":blue"),  proc=LJZ_GSA2_SVProc

    Button btRed,    pos={176,402}, size={34,20}, title="R", fColor=(65535,0,0),         proc=LJZ_GSA2_ButtonProc
    Button btBlue,   pos={214,402}, size={34,20}, title="B", fColor=(0,20000,65535),     proc=LJZ_GSA2_ButtonProc
    Button btYellow, pos={252,402}, size={34,20}, title="Y", fColor=(65535,52000,0),     proc=LJZ_GSA2_ButtonProc
    Button btWhite,  pos={290,402}, size={34,20}, title="W", fColor=(65535,65535,65535), proc=LJZ_GSA2_ButtonProc
    Button btBlack,  pos={328,402}, size={34,20}, title="K", fColor=(0,0,0),             proc=LJZ_GSA2_ButtonProc

    SetVariable svThick, pos={176,432}, size={112,18}, title="thick", limits={0.1,30,0.5}, value=$(base+":lineThick")
    SetVariable svDash,  pos={300,432}, size={100,18}, title="dash",  limits={0,17,1},     value=$(base+":dash")
    SetVariable svFill,  pos={300,456}, size={100,18}, title="fill",  limits={0,20,1},     value=$(base+":fillPat")

    CheckBox ckSepFill, pos={20,474}, size={130,18}, title="Separate fill", variable=$(base+":useSepFill"), proc=LJZ_GSA2_CheckProc
    TitleBox tbFillPrev, pos={20,496}, size={34,18}, title=" ", frame=1, labelBack=(0,0,0)

    SetVariable svFillR, pos={62,492},  size={92,18}, title="fR", limits={0,65535,1000}, value=$(base+":fillR"), proc=LJZ_GSA2_SVProc
    SetVariable svFillG, pos={162,492}, size={92,18}, title="fG", limits={0,65535,1000}, value=$(base+":fillG"), proc=LJZ_GSA2_SVProc
    SetVariable svFillB, pos={262,492}, size={92,18}, title="fB", limits={0,65535,1000}, value=$(base+":fillB"), proc=LJZ_GSA2_SVProc

    LJZ_GSA2_UpdateTabVisibility()
    LJZ_GSA2_RefreshColorPreview()

    SVAR lockedGraph = $(base + ":lockedGraph")
    if (strlen(lockedGraph) > 0)
        TitleBox tbLockedName, win=$p, title=lockedGraph
        Button   btLock,       win=$p, title="Unlock"
    else
        TitleBox tbLockedName, win=$p, title="unlocked"
        Button   btLock,       win=$p, title="Lock"
    endif

    NVAR useSepFill = $(base + ":useSepFill")
    if (useSepFill == 0)
        SetVariable svFillR,    win=$p, disable=1
        SetVariable svFillG,    win=$p, disable=1
        SetVariable svFillB,    win=$p, disable=1
        TitleBox    tbFillPrev, win=$p, disable=1
    endif

    return 0
End

// ============================================================================
//  Section 12. Button callback
// ============================================================================

Function LJZ_GSA2_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    String base = LJZ_GSA2_BaseDF()
    String p = LJZ_GSA2_PanelName()
    String c = ba.ctrlName

    if (CmpStr(c, "btLock") == 0)
        String gn = WinName(0, 1)
        if (strlen(gn) == 0)
            DoAlert 0, "No graph on top."
            return 0
        endif

        SVAR lockedGraph = $(base + ":lockedGraph")
        if (cmpstr(lockedGraph, gn) == 0)
            lockedGraph = ""
            TitleBox tbLockedName, win=$p, title="unlocked"
            Button   btLock,       win=$p, title="Lock"
        else
            lockedGraph = gn
            TitleBox tbLockedName, win=$p, title=gn
            Button   btLock,       win=$p, title="Unlock"
        endif
        return 0
    endif

    if (CmpStr(c, "btUndo") == 0)
        LJZ_GSA2_Undo()
        return 0
    endif

    if (CmpStr(c, "btClear") == 0)
        LJZ_GSA2_ClearTopGraphDrawings()
        return 0
    endif

    if (CmpStr(c, "btClose") == 0)
        DoWindow/K $p
        return 0
    endif

    if (CmpStr(c, "btLine") == 0)
        LJZ_GSA2_AddLine()
        return 0
    endif
    if (CmpStr(c, "btRect") == 0)
        LJZ_GSA2_AddRectangleByBox()
        return 0
    endif
    if (CmpStr(c, "btEllipseBox") == 0)
        LJZ_GSA2_AddEllipseByBox()
        return 0
    endif
    if (CmpStr(c, "btEllipseCenter") == 0)
        LJZ_GSA2_AddEllipseByCenter()
        return 0
    endif
    if (CmpStr(c, "btCircleCenter") == 0)
        LJZ_GSA2_AddCircleByCenter()
        return 0
    endif
    if (CmpStr(c, "btTri3P") == 0)
        LJZ_GSA2_AddTriangleBy3Points()
        return 0
    endif
    if (CmpStr(c, "btTriBox") == 0)
        LJZ_GSA2_AddTriangleByBox()
        return 0
    endif
    if (CmpStr(c, "btTriCenter") == 0)
        LJZ_GSA2_AddTriangleByCenter()
        return 0
    endif

    if (CmpStr(c, "btRed") == 0)
        LJZ_GSA2_RedPreset()
        return 0
    endif
    if (CmpStr(c, "btBlue") == 0)
        LJZ_GSA2_BluePreset()
        return 0
    endif
    if (CmpStr(c, "btYellow") == 0)
        LJZ_GSA2_YellowPreset()
        return 0
    endif
    if (CmpStr(c, "btWhite") == 0)
        LJZ_GSA2_WhitePreset()
        return 0
    endif
    if (CmpStr(c, "btBlack") == 0)
        LJZ_GSA2_BlackPreset()
        return 0
    endif

    return 0
End

// ============================================================================
//  Section 13. Helper API kept for v2 compatibility
// ============================================================================

Function LJZ_GSA2_SetCoords(newX1, newY1, newX2, newY2)
    Variable newX1, newY1, newX2, newY2

    LJZ_GSA2_EnsureDF()
    String base = LJZ_GSA2_BaseDF()
    NVAR x1 = $(base + ":x1")
    NVAR y1 = $(base + ":y1")
    NVAR x2 = $(base + ":x2")
    NVAR y2 = $(base + ":y2")

    x1 = newX1
    y1 = newY1
    x2 = newX2
    y2 = newY2
    return 0
End

Function LJZ_GSA2_SetCenter(newCX, newCY)
    Variable newCX, newCY

    LJZ_GSA2_EnsureDF()
    String base = LJZ_GSA2_BaseDF()
    NVAR cx = $(base + ":cx")
    NVAR cy = $(base + ":cy")

    cx = newCX
    cy = newCY
    return 0
End

Function LJZ_GSA2_SetRadii(newRX, newRY)
    Variable newRX, newRY

    LJZ_GSA2_EnsureDF()
    String base = LJZ_GSA2_BaseDF()
    NVAR rx = $(base + ":rx")
    NVAR ry = $(base + ":ry")

    rx = newRX
    ry = newRY
    return 0
End

Function LJZ_GSA2_SetTriangle3P(newTX1, newTY1, newTX2, newTY2, newTX3, newTY3)
    Variable newTX1, newTY1, newTX2, newTY2, newTX3, newTY3

    LJZ_GSA2_EnsureDF()
    String base = LJZ_GSA2_BaseDF()
    NVAR tx1 = $(base + ":tx1")
    NVAR ty1 = $(base + ":ty1")
    NVAR tx2 = $(base + ":tx2")
    NVAR ty2 = $(base + ":ty2")
    NVAR tx3 = $(base + ":tx3")
    NVAR ty3 = $(base + ":ty3")

    tx1 = newTX1
    ty1 = newTY1
    tx2 = newTX2
    ty2 = newTY2
    tx3 = newTX3
    ty3 = newTY3
    return 0
End
