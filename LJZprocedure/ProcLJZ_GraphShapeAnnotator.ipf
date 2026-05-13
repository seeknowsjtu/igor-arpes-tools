#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma DefaultTab={3,20,4}

// ============================================================================
//  LJZ Graph Shape Annotator v2
//
//  Purpose:
//    Add colored drawing objects to the top graph window:
//      line, rectangle, ellipse, circle, triangle by 3 vertices,
//      and triangle by center/width/height.
//
//  Coordinates:
//    All coordinates are graph-axis coordinates.
//    Default target axes are bottom and left.
//
//  Menu:
//    ARPES_LJZ -> Graph Shape Annotator v2
//
//  Notes:
//    R/G/B use Igor's 0-65535 color scale.
//    FillPat = 0 means hollow outline.
//    Dash = 0 means solid line.
// ============================================================================


Menu "ARPES_LJZ"
    "Graph Shape Annotator v2", LJZ_GSA2_OpenPanel()
    "Clear Graph Shape Layer v2", LJZ_GSA2_ClearTopGraphDrawings()
End


Function/S LJZ_GSA2_BaseDF()
    return "root:Packages:LJZ_GraphShapeAnnotatorV2"
End


Function/S LJZ_GSA2_PanelName()
    return "LJZ_GraphShapeAnnotatorV2_Panel"
End


Function LJZ_GSA2_EnsureDF()
    NewDataFolder/O root:Packages
    NewDataFolder/O $(LJZ_GSA2_BaseDF())

    NVAR/Z x1 = $(LJZ_GSA2_BaseDF() + ":x1")
    if (!NVAR_Exists(x1))
        Variable/G $(LJZ_GSA2_BaseDF() + ":x1") = 0
    endif

    NVAR/Z y1 = $(LJZ_GSA2_BaseDF() + ":y1")
    if (!NVAR_Exists(y1))
        Variable/G $(LJZ_GSA2_BaseDF() + ":y1") = 0
    endif

    NVAR/Z x2 = $(LJZ_GSA2_BaseDF() + ":x2")
    if (!NVAR_Exists(x2))
        Variable/G $(LJZ_GSA2_BaseDF() + ":x2") = 1
    endif

    NVAR/Z y2 = $(LJZ_GSA2_BaseDF() + ":y2")
    if (!NVAR_Exists(y2))
        Variable/G $(LJZ_GSA2_BaseDF() + ":y2") = 1
    endif

    NVAR/Z cx = $(LJZ_GSA2_BaseDF() + ":cx")
    if (!NVAR_Exists(cx))
        Variable/G $(LJZ_GSA2_BaseDF() + ":cx") = 0
    endif

    NVAR/Z cy = $(LJZ_GSA2_BaseDF() + ":cy")
    if (!NVAR_Exists(cy))
        Variable/G $(LJZ_GSA2_BaseDF() + ":cy") = 0
    endif

    NVAR/Z rx = $(LJZ_GSA2_BaseDF() + ":rx")
    if (!NVAR_Exists(rx))
        Variable/G $(LJZ_GSA2_BaseDF() + ":rx") = 0.1
    endif

    NVAR/Z ry = $(LJZ_GSA2_BaseDF() + ":ry")
    if (!NVAR_Exists(ry))
        Variable/G $(LJZ_GSA2_BaseDF() + ":ry") = 1
    endif

    NVAR/Z radius = $(LJZ_GSA2_BaseDF() + ":radius")
    if (!NVAR_Exists(radius))
        Variable/G $(LJZ_GSA2_BaseDF() + ":radius") = 1
    endif

    NVAR/Z tx1 = $(LJZ_GSA2_BaseDF() + ":tx1")
    if (!NVAR_Exists(tx1))
        Variable/G $(LJZ_GSA2_BaseDF() + ":tx1") = 0
    endif

    NVAR/Z ty1 = $(LJZ_GSA2_BaseDF() + ":ty1")
    if (!NVAR_Exists(ty1))
        Variable/G $(LJZ_GSA2_BaseDF() + ":ty1") = 0
    endif

    NVAR/Z tx2 = $(LJZ_GSA2_BaseDF() + ":tx2")
    if (!NVAR_Exists(tx2))
        Variable/G $(LJZ_GSA2_BaseDF() + ":tx2") = 1
    endif

    NVAR/Z ty2 = $(LJZ_GSA2_BaseDF() + ":ty2")
    if (!NVAR_Exists(ty2))
        Variable/G $(LJZ_GSA2_BaseDF() + ":ty2") = 0
    endif

    NVAR/Z tx3 = $(LJZ_GSA2_BaseDF() + ":tx3")
    if (!NVAR_Exists(tx3))
        Variable/G $(LJZ_GSA2_BaseDF() + ":tx3") = 0.5
    endif

    NVAR/Z ty3 = $(LJZ_GSA2_BaseDF() + ":ty3")
    if (!NVAR_Exists(ty3))
        Variable/G $(LJZ_GSA2_BaseDF() + ":ty3") = 1
    endif

    NVAR/Z triWidth = $(LJZ_GSA2_BaseDF() + ":triWidth")
    if (!NVAR_Exists(triWidth))
        Variable/G $(LJZ_GSA2_BaseDF() + ":triWidth") = 1
    endif

    NVAR/Z triHeight = $(LJZ_GSA2_BaseDF() + ":triHeight")
    if (!NVAR_Exists(triHeight))
        Variable/G $(LJZ_GSA2_BaseDF() + ":triHeight") = 1
    endif

    NVAR/Z triDir = $(LJZ_GSA2_BaseDF() + ":triDir")
    if (!NVAR_Exists(triDir))
        Variable/G $(LJZ_GSA2_BaseDF() + ":triDir") = 0
    endif

    NVAR/Z red = $(LJZ_GSA2_BaseDF() + ":red")
    if (!NVAR_Exists(red))
        Variable/G $(LJZ_GSA2_BaseDF() + ":red") = 65535
    endif

    NVAR/Z green = $(LJZ_GSA2_BaseDF() + ":green")
    if (!NVAR_Exists(green))
        Variable/G $(LJZ_GSA2_BaseDF() + ":green") = 0
    endif

    NVAR/Z blue = $(LJZ_GSA2_BaseDF() + ":blue")
    if (!NVAR_Exists(blue))
        Variable/G $(LJZ_GSA2_BaseDF() + ":blue") = 0
    endif

    NVAR/Z lineThick = $(LJZ_GSA2_BaseDF() + ":lineThick")
    if (!NVAR_Exists(lineThick))
        Variable/G $(LJZ_GSA2_BaseDF() + ":lineThick") = 2
    endif

    NVAR/Z dash = $(LJZ_GSA2_BaseDF() + ":dash")
    if (!NVAR_Exists(dash))
        Variable/G $(LJZ_GSA2_BaseDF() + ":dash") = 0
    endif

    NVAR/Z fillPat = $(LJZ_GSA2_BaseDF() + ":fillPat")
    if (!NVAR_Exists(fillPat))
        Variable/G $(LJZ_GSA2_BaseDF() + ":fillPat") = 0
    endif

    NVAR/Z drawFront = $(LJZ_GSA2_BaseDF() + ":drawFront")
    if (!NVAR_Exists(drawFront))
        Variable/G $(LJZ_GSA2_BaseDF() + ":drawFront") = 1
    endif

    Make/O/D/N=4 $(LJZ_GSA2_BaseDF() + ":polyX")
    Make/O/D/N=4 $(LJZ_GSA2_BaseDF() + ":polyY")

    return 0
End


Function/S LJZ_GSA2_GetTopGraph()
    String gName

    gName = WinName(0, 1)

    if (strlen(gName) == 0)
        DoAlert 0, "No graph window found. Please activate or open a graph first."
        return ""
    endif

    return gName
End


Function LJZ_GSA2_NormalizeColorValue(v)
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


Function LJZ_GSA2_AbsValue(v)
    Variable v

    if (numtype(v) != 0)
        return 0
    endif

    if (v < 0)
        return -v
    endif

    return v
End


Function LJZ_GSA2_SetDrawEnv(gName)
    String gName

    LJZ_GSA2_EnsureDF()

    NVAR red = $(LJZ_GSA2_BaseDF() + ":red")
    NVAR green = $(LJZ_GSA2_BaseDF() + ":green")
    NVAR blue = $(LJZ_GSA2_BaseDF() + ":blue")
    NVAR lineThick = $(LJZ_GSA2_BaseDF() + ":lineThick")
    NVAR dash = $(LJZ_GSA2_BaseDF() + ":dash")
    NVAR fillPat = $(LJZ_GSA2_BaseDF() + ":fillPat")
    NVAR drawFront = $(LJZ_GSA2_BaseDF() + ":drawFront")

    Variable r
    Variable g
    Variable b
    Variable lt
    Variable ds
    Variable fp

    r = LJZ_GSA2_NormalizeColorValue(red)
    g = LJZ_GSA2_NormalizeColorValue(green)
    b = LJZ_GSA2_NormalizeColorValue(blue)

    lt = lineThick
    if (numtype(lt) != 0 || lt <= 0)
        lt = 1
    endif

    ds = round(dash)
    if (numtype(ds) != 0 || ds < 0)
        ds = 0
    endif

    fp = round(fillPat)
    if (numtype(fp) != 0 || fp < 0)
        fp = 0
    endif

    if (drawFront)
        SetDrawLayer/W=$gName ProgFront
    else
        SetDrawLayer/W=$gName UserFront
    endif

    SetDrawEnv/W=$gName xcoord=bottom, ycoord=left, linefgc=(r,g,b), fillfgc=(r,g,b), linethick=lt, dash=ds, fillpat=fp

    return 0
End


Function LJZ_GSA2_GetBox(xx1, yy1, xx2, yy2)
    Variable &xx1
    Variable &yy1
    Variable &xx2
    Variable &yy2

    LJZ_GSA2_EnsureDF()

    NVAR x1 = $(LJZ_GSA2_BaseDF() + ":x1")
    NVAR y1 = $(LJZ_GSA2_BaseDF() + ":y1")
    NVAR x2 = $(LJZ_GSA2_BaseDF() + ":x2")
    NVAR y2 = $(LJZ_GSA2_BaseDF() + ":y2")

    xx1 = min(x1, x2)
    xx2 = max(x1, x2)
    yy1 = min(y1, y2)
    yy2 = max(y1, y2)

    return 0
End


Function LJZ_GSA2_AddLine()
    String gName

    LJZ_GSA2_EnsureDF()

    gName = LJZ_GSA2_GetTopGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    NVAR x1 = $(LJZ_GSA2_BaseDF() + ":x1")
    NVAR y1 = $(LJZ_GSA2_BaseDF() + ":y1")
    NVAR x2 = $(LJZ_GSA2_BaseDF() + ":x2")
    NVAR y2 = $(LJZ_GSA2_BaseDF() + ":y2")

    LJZ_GSA2_SetDrawEnv(gName)
    DrawLine/W=$gName x1, y1, x2, y2

    return 0
End


Function LJZ_GSA2_AddRectangleByBox()
    String gName
    Variable xx1
    Variable yy1
    Variable xx2
    Variable yy2

    LJZ_GSA2_EnsureDF()

    gName = LJZ_GSA2_GetTopGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    LJZ_GSA2_GetBox(xx1, yy1, xx2, yy2)

    LJZ_GSA2_SetDrawEnv(gName)
    DrawRect/W=$gName xx1, yy1, xx2, yy2

    return 0
End


Function LJZ_GSA2_AddEllipseByBox()
    String gName
    Variable xx1
    Variable yy1
    Variable xx2
    Variable yy2

    LJZ_GSA2_EnsureDF()

    gName = LJZ_GSA2_GetTopGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    LJZ_GSA2_GetBox(xx1, yy1, xx2, yy2)

    LJZ_GSA2_SetDrawEnv(gName)
    DrawOval/W=$gName xx1, yy1, xx2, yy2

    return 0
End


Function LJZ_GSA2_AddEllipseByCenter()
    String gName
    Variable xx1
    Variable yy1
    Variable xx2
    Variable yy2
    Variable rxx
    Variable ryy

    LJZ_GSA2_EnsureDF()

    gName = LJZ_GSA2_GetTopGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    NVAR cx = $(LJZ_GSA2_BaseDF() + ":cx")
    NVAR cy = $(LJZ_GSA2_BaseDF() + ":cy")
    NVAR rx = $(LJZ_GSA2_BaseDF() + ":rx")
    NVAR ry = $(LJZ_GSA2_BaseDF() + ":ry")

    rxx = LJZ_GSA2_AbsValue(rx)
    ryy = LJZ_GSA2_AbsValue(ry)

    xx1 = cx - rxx
    xx2 = cx + rxx
    yy1 = cy - ryy
    yy2 = cy + ryy

    LJZ_GSA2_SetDrawEnv(gName)
    DrawOval/W=$gName xx1, yy1, xx2, yy2

    return 0
End


Function LJZ_GSA2_AddCircleByCenter()
    String gName
    Variable rr

    LJZ_GSA2_EnsureDF()

    gName = LJZ_GSA2_GetTopGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    NVAR cx = $(LJZ_GSA2_BaseDF() + ":cx")
    NVAR cy = $(LJZ_GSA2_BaseDF() + ":cy")
    NVAR radius = $(LJZ_GSA2_BaseDF() + ":radius")

    rr = LJZ_GSA2_AbsValue(radius)

    LJZ_GSA2_SetDrawEnv(gName)
    DrawOval/W=$gName cx - rr, cy - rr, cx + rr, cy + rr

    return 0
End


Function LJZ_GSA2_AddTriangleByBox()
    String gName
    Variable xx1
    Variable yy1
    Variable xx2
    Variable yy2
    Variable width
    Variable height

    LJZ_GSA2_EnsureDF()

    gName = LJZ_GSA2_GetTopGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    LJZ_GSA2_GetBox(xx1, yy1, xx2, yy2)

    width = xx2 - xx1
    height = yy2 - yy1

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

    LJZ_GSA2_SetDrawEnv(gName)
    DrawPoly/W=$gName xx1, yy1, 1, 1, polyX, polyY

    return 0
End


Function LJZ_GSA2_AddTriangleBy3Points()
    String gName

    LJZ_GSA2_EnsureDF()

    gName = LJZ_GSA2_GetTopGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    NVAR tx1 = $(LJZ_GSA2_BaseDF() + ":tx1")
    NVAR ty1 = $(LJZ_GSA2_BaseDF() + ":ty1")
    NVAR tx2 = $(LJZ_GSA2_BaseDF() + ":tx2")
    NVAR ty2 = $(LJZ_GSA2_BaseDF() + ":ty2")
    NVAR tx3 = $(LJZ_GSA2_BaseDF() + ":tx3")
    NVAR ty3 = $(LJZ_GSA2_BaseDF() + ":ty3")

    Wave polyX = $(LJZ_GSA2_BaseDF() + ":polyX")
    Wave polyY = $(LJZ_GSA2_BaseDF() + ":polyY")

    polyX[0] = 0
    polyY[0] = 0

    polyX[1] = tx2 - tx1
    polyY[1] = ty2 - ty1

    polyX[2] = tx3 - tx1
    polyY[2] = ty3 - ty1

    polyX[3] = 0
    polyY[3] = 0

    LJZ_GSA2_SetDrawEnv(gName)
    DrawPoly/W=$gName tx1, ty1, 1, 1, polyX, polyY

    return 0
End


Function LJZ_GSA2_AddTriangleByCenter()
    String gName
    Variable halfW
    Variable halfH
    Variable dir

    LJZ_GSA2_EnsureDF()

    gName = LJZ_GSA2_GetTopGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    NVAR cx = $(LJZ_GSA2_BaseDF() + ":cx")
    NVAR cy = $(LJZ_GSA2_BaseDF() + ":cy")
    NVAR triWidth = $(LJZ_GSA2_BaseDF() + ":triWidth")
    NVAR triHeight = $(LJZ_GSA2_BaseDF() + ":triHeight")
    NVAR triDir = $(LJZ_GSA2_BaseDF() + ":triDir")

    halfW = 0.5 * LJZ_GSA2_AbsValue(triWidth)
    halfH = 0.5 * LJZ_GSA2_AbsValue(triHeight)
    dir = round(triDir)

    Wave polyX = $(LJZ_GSA2_BaseDF() + ":polyX")
    Wave polyY = $(LJZ_GSA2_BaseDF() + ":polyY")

    if (dir == 1)
        polyX[0] = -halfW
        polyY[0] = halfH
        polyX[1] = halfW
        polyY[1] = halfH
        polyX[2] = 0
        polyY[2] = -halfH
    elseif (dir == 2)
        polyX[0] = -halfW
        polyY[0] = -halfH
        polyX[1] = -halfW
        polyY[1] = halfH
        polyX[2] = halfW
        polyY[2] = 0
    elseif (dir == 3)
        polyX[0] = halfW
        polyY[0] = -halfH
        polyX[1] = halfW
        polyY[1] = halfH
        polyX[2] = -halfW
        polyY[2] = 0
    else
        polyX[0] = -halfW
        polyY[0] = -halfH
        polyX[1] = halfW
        polyY[1] = -halfH
        polyX[2] = 0
        polyY[2] = halfH
    endif

    polyX[3] = polyX[0]
    polyY[3] = polyY[0]

    LJZ_GSA2_SetDrawEnv(gName)
    DrawPoly/W=$gName cx, cy, 1, 1, polyX, polyY

    return 0
End


Function LJZ_GSA2_ClearTopGraphDrawings()
    String gName

    gName = LJZ_GSA2_GetTopGraph()
    if (strlen(gName) == 0)
        return -1
    endif

    SetDrawLayer/K/W=$gName ProgFront

    Print "LJZ_GSA2: cleared ProgFront drawing layer in graph: " + gName

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


Function LJZ_GSA2_OpenPanel()
    LJZ_GSA2_EnsureDF()

    String p
    p = LJZ_GSA2_PanelName()

    DoWindow/F $p
    if (V_flag)
        return 0
    endif

    NewPanel/N=$p /W=(150,80,850,640)
    ModifyPanel frameStyle=1
    ModifyPanel cbRGB=(60000,60000,60000)

    TitleBox tbTitle,pos={12,8},size={360,18},title="LJZ Graph Shape Annotator v2",frame=0
    TitleBox tbHint,pos={12,30},size={650,34},title="Draws into the top graph using bottom/left axis coordinates. More direct controls for ellipse/circle/triangle.",frame=0

    GroupBox gbBox,pos={12,72},size={210,158},title="Line / box coordinates"
    SetVariable svX1,pos={28,100},size={170,20},title="x1"
    SetVariable svX1,limits={-inf,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":x1")
    SetVariable svY1,pos={28,128},size={170,20},title="y1"
    SetVariable svY1,limits={-inf,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":y1")
    SetVariable svX2,pos={28,156},size={170,20},title="x2"
    SetVariable svX2,limits={-inf,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":x2")
    SetVariable svY2,pos={28,184},size={170,20},title="y2"
    SetVariable svY2,limits={-inf,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":y2")
    Button btLine,pos={28,202},size={52,22},title="Line",proc=LJZ_GSA2_ButtonProc
    Button btRect,pos={86,202},size={62,22},title="Rect",proc=LJZ_GSA2_ButtonProc
    Button btEllipseBox,pos={154,202},size={58,22},title="OvalBox",proc=LJZ_GSA2_ButtonProc

    GroupBox gbCenter,pos={242,72},size={210,218},title="Center shape controls"
    SetVariable svCX,pos={258,100},size={170,20},title="cx"
    SetVariable svCX,limits={-inf,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":cx")
    SetVariable svCY,pos={258,128},size={170,20},title="cy"
    SetVariable svCY,limits={-inf,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":cy")
    SetVariable svRX,pos={258,156},size={170,20},title="rx"
    SetVariable svRX,limits={0,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":rx")
    SetVariable svRY,pos={258,184},size={170,20},title="ry"
    SetVariable svRY,limits={0,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":ry")
    SetVariable svRad,pos={258,212},size={170,20},title="radius"
    SetVariable svRad,limits={0,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":radius")
    Button btEllipseCenter,pos={258,244},size={82,24},title="Ellipse",proc=LJZ_GSA2_ButtonProc
    Button btCircleCenter,pos={350,244},size={82,24},title="Circle",proc=LJZ_GSA2_ButtonProc

    GroupBox gbTri3,pos={472,72},size={210,246},title="Triangle: 3 vertices"
    SetVariable svTX1,pos={488,100},size={170,20},title="tx1"
    SetVariable svTX1,limits={-inf,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":tx1")
    SetVariable svTY1,pos={488,128},size={170,20},title="ty1"
    SetVariable svTY1,limits={-inf,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":ty1")
    SetVariable svTX2,pos={488,156},size={170,20},title="tx2"
    SetVariable svTX2,limits={-inf,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":tx2")
    SetVariable svTY2,pos={488,184},size={170,20},title="ty2"
    SetVariable svTY2,limits={-inf,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":ty2")
    SetVariable svTX3,pos={488,212},size={170,20},title="tx3"
    SetVariable svTX3,limits={-inf,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":tx3")
    SetVariable svTY3,pos={488,240},size={170,20},title="ty3"
    SetVariable svTY3,limits={-inf,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":ty3")
    Button btTri3P,pos={488,276},size={82,24},title="Tri 3P",proc=LJZ_GSA2_ButtonProc
    Button btTriBox,pos={580,276},size={82,24},title="Tri Box",proc=LJZ_GSA2_ButtonProc

    GroupBox gbTriC,pos={12,250},size={210,142},title="Triangle: center mode"
    SetVariable svTriW,pos={28,278},size={170,20},title="width"
    SetVariable svTriW,limits={0,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":triWidth")
    SetVariable svTriH,pos={28,306},size={170,20},title="height"
    SetVariable svTriH,limits={0,inf,0.01},value=$(LJZ_GSA2_BaseDF() + ":triHeight")
    SetVariable svTriDir,pos={28,334},size={170,20},title="dir"
    SetVariable svTriDir,limits={0,3,1},value=$(LJZ_GSA2_BaseDF() + ":triDir")
    Button btTriCenter,pos={28,362},size={140,24},title="Tri Center",proc=LJZ_GSA2_ButtonProc
    TitleBox tbTriHint,pos={170,360},size={46,28},title="0 up\r1 down",frame=0

    GroupBox gbStyle,pos={242,340},size={440,138},title="Style"
    SetVariable svR,pos={258,368},size={124,20},title="R"
    SetVariable svR,limits={0,65535,1000},value=$(LJZ_GSA2_BaseDF() + ":red")
    SetVariable svG,pos={258,396},size={124,20},title="G"
    SetVariable svG,limits={0,65535,1000},value=$(LJZ_GSA2_BaseDF() + ":green")
    SetVariable svB,pos={258,424},size={124,20},title="B"
    SetVariable svB,limits={0,65535,1000},value=$(LJZ_GSA2_BaseDF() + ":blue")
    SetVariable svThick,pos={400,368},size={124,20},title="Thick"
    SetVariable svThick,limits={0.1,30,0.5},value=$(LJZ_GSA2_BaseDF() + ":lineThick")
    SetVariable svDash,pos={400,396},size={124,20},title="Dash"
    SetVariable svDash,limits={0,17,1},value=$(LJZ_GSA2_BaseDF() + ":dash")
    SetVariable svFill,pos={400,424},size={124,20},title="FillPat"
    SetVariable svFill,limits={0,20,1},value=$(LJZ_GSA2_BaseDF() + ":fillPat")
    CheckBox ckFront,pos={542,370},size={100,18},title="ProgFront"
    CheckBox ckFront,variable=$(LJZ_GSA2_BaseDF() + ":drawFront")

    Button btRed,pos={258,490},size={52,24},title="Red",proc=LJZ_GSA2_ButtonProc
    Button btBlue,pos={318,490},size={52,24},title="Blue",proc=LJZ_GSA2_ButtonProc
    Button btYellow,pos={378,490},size={62,24},title="Yellow",proc=LJZ_GSA2_ButtonProc
    Button btWhite,pos={448,490},size={52,24},title="White",proc=LJZ_GSA2_ButtonProc
    Button btBlack,pos={508,490},size={52,24},title="Black",proc=LJZ_GSA2_ButtonProc
    Button btClear,pos={572,490},size={92,24},title="Clear",proc=LJZ_GSA2_ButtonProc
    Button btClose,pos={572,526},size={92,24},title="Close",proc=LJZ_GSA2_ButtonProc

    TitleBox tbUse,pos={24,502},size={500,54},title="Circle uses cx,cy,radius. Ellipse uses cx,cy,rx,ry. Tri 3P uses tx1/ty1, tx2/ty2, tx3/ty3. Tri Center uses cx,cy,width,height,dir.",frame=0

    return 0
End


Function LJZ_GSA2_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btLine") == 0)
        LJZ_GSA2_AddLine()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btRect") == 0)
        LJZ_GSA2_AddRectangleByBox()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btEllipseBox") == 0)
        LJZ_GSA2_AddEllipseByBox()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btEllipseCenter") == 0)
        LJZ_GSA2_AddEllipseByCenter()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btCircleCenter") == 0)
        LJZ_GSA2_AddCircleByCenter()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btTri3P") == 0)
        LJZ_GSA2_AddTriangleBy3Points()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btTriBox") == 0)
        LJZ_GSA2_AddTriangleByBox()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btTriCenter") == 0)
        LJZ_GSA2_AddTriangleByCenter()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btRed") == 0)
        LJZ_GSA2_RedPreset()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btBlue") == 0)
        LJZ_GSA2_BluePreset()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btYellow") == 0)
        LJZ_GSA2_YellowPreset()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btWhite") == 0)
        LJZ_GSA2_WhitePreset()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btBlack") == 0)
        LJZ_GSA2_BlackPreset()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btClear") == 0)
        LJZ_GSA2_ClearTopGraphDrawings()
        return 0
    endif

    if (CmpStr(ba.ctrlName, "btClose") == 0)
        DoWindow/K $(LJZ_GSA2_PanelName())
        return 0
    endif

    return 0
End


Function LJZ_GSA2_SetCoords(newX1, newY1, newX2, newY2)
    Variable newX1
    Variable newY1
    Variable newX2
    Variable newY2

    LJZ_GSA2_EnsureDF()

    NVAR x1 = $(LJZ_GSA2_BaseDF() + ":x1")
    NVAR y1 = $(LJZ_GSA2_BaseDF() + ":y1")
    NVAR x2 = $(LJZ_GSA2_BaseDF() + ":x2")
    NVAR y2 = $(LJZ_GSA2_BaseDF() + ":y2")

    x1 = newX1
    y1 = newY1
    x2 = newX2
    y2 = newY2

    return 0
End


Function LJZ_GSA2_SetCenter(newCX, newCY)
    Variable newCX
    Variable newCY

    LJZ_GSA2_EnsureDF()

    NVAR cx = $(LJZ_GSA2_BaseDF() + ":cx")
    NVAR cy = $(LJZ_GSA2_BaseDF() + ":cy")

    cx = newCX
    cy = newCY

    return 0
End


Function LJZ_GSA2_SetRadii(newRX, newRY)
    Variable newRX
    Variable newRY

    LJZ_GSA2_EnsureDF()

    NVAR rx = $(LJZ_GSA2_BaseDF() + ":rx")
    NVAR ry = $(LJZ_GSA2_BaseDF() + ":ry")

    rx = newRX
    ry = newRY

    return 0
End


Function LJZ_GSA2_SetTriangle3P(newTX1, newTY1, newTX2, newTY2, newTX3, newTY3)
    Variable newTX1
    Variable newTY1
    Variable newTX2
    Variable newTY2
    Variable newTX3
    Variable newTY3

    LJZ_GSA2_EnsureDF()

    NVAR tx1 = $(LJZ_GSA2_BaseDF() + ":tx1")
    NVAR ty1 = $(LJZ_GSA2_BaseDF() + ":ty1")
    NVAR tx2 = $(LJZ_GSA2_BaseDF() + ":tx2")
    NVAR ty2 = $(LJZ_GSA2_BaseDF() + ":ty2")
    NVAR tx3 = $(LJZ_GSA2_BaseDF() + ":tx3")
    NVAR ty3 = $(LJZ_GSA2_BaseDF() + ":ty3")

    tx1 = newTX1
    ty1 = newTY1
    tx2 = newTX2
    ty2 = newTY2
    tx3 = newTX3
    ty3 = newTY3

    return 0
End


Function LJZ_GSA2_SetColor(newR, newG, newB)
    Variable newR
    Variable newG
    Variable newB

    LJZ_GSA2_EnsureDF()

    NVAR red = $(LJZ_GSA2_BaseDF() + ":red")
    NVAR green = $(LJZ_GSA2_BaseDF() + ":green")
    NVAR blue = $(LJZ_GSA2_BaseDF() + ":blue")

    red = LJZ_GSA2_NormalizeColorValue(newR)
    green = LJZ_GSA2_NormalizeColorValue(newG)
    blue = LJZ_GSA2_NormalizeColorValue(newB)

    return 0
End
