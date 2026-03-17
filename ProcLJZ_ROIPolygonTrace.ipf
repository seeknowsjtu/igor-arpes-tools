#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

//============================================================
// ROIVARY (LJZ) : Polygon ROI (T/Q/P) -> integrate 3D wave vs time
//  - SD3D-style folder selection (SetVariable Base DF + Recursive + Scan)
//  - Output unified to root:ARPES_LJZ:ROIVARY_OUT:
//  - Supports: Preview first frame, read cursors -> indices, Draw overlay, Run trace, Load from Code
//============================================================

//============================================================
// 0) Folder / String helpers (SD3D style)
//============================================================
Function roivary_ensure_folder()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:ROIVARY
    NewDataFolder/O root:ARPES_LJZ:ROIVARY_OUT
End

Function/S roivary_df_with_colon(inStr)
    String inStr
    String s = inStr

    if (strlen(s) == 0)
        return "root:"
    endif

    // allow "root" -> "root:"
    if (StringMatch(s, "root"))
        s = "root:"
    endif

    if (!StringMatch(s, "*:"))
        s += ":"
    endif

    return s
End

Function roivary_df_exists(dfStr)
    String dfStr
    String s = roivary_df_with_colon(dfStr)
    return DataFolderExists(s)
End

// normalize list separators for DataFolderDir outputs (often \r)
Function/S roivary_norm_list(listStr)
    String listStr
    String s = listStr
    s = ReplaceString("\r", s, ";")
    s = ReplaceString("\n", s, ";")
    if (strlen(s) > 0)
        if (cmpstr(s[strlen(s)-1], ";") != 0)
            s += ";"
        endif
    endif
    return s
End

//============================================================
// 1) Math helpers: integer min/max
//============================================================
Function Min3i(a,b,c)
    Variable a,b,c
    return min(a, min(b, c))
End
Function Max3i(a,b,c)
    Variable a,b,c
    return max(a, max(b, c))
End
Function Min4i(a,b,c,d)
    Variable a,b,c,d
    return min(min(a,b), min(c,d))
End
Function Max4i(a,b,c,d)
    Variable a,b,c,d
    return max(max(a,b), max(c,d))
End
Function Min5i(a,b,c,d,e)
    Variable a,b,c,d,e
    return min(min(min(a,b), min(c,d)), e)
End
Function Max5i(a,b,c,d,e)
    Variable a,b,c,d,e
    return max(max(max(a,b), max(c,d)), e)
End

//============================================================
// 2) Point-in-polygon helpers (T / Q / P)
//============================================================
Function TSign(px, py, x1, y1, x2, y2)
    Variable px, py, x1, y1, x2, y2
    return (px - x2) * (y1 - y2) - (x1 - x2) * (py - y2)
End

Function PointInTriangle(px, py, x1, y1, x2, y2, x3, y3)
    Variable px, py, x1, y1, x2, y2, x3, y3
    Variable d1 = TSign(px, py, x1, y1, x2, y2)
    Variable d2 = TSign(px, py, x2, y2, x3, y3)
    Variable d3 = TSign(px, py, x3, y3, x1, y1)
    Variable has_neg = (d1 < 0) || (d2 < 0) || (d3 < 0)
    Variable has_pos = (d1 > 0) || (d2 > 0) || (d3 > 0)
    return !(has_neg && has_pos)
End

Function PointInQuadrilateral(px, py, x1, y1, x2, y2, x3, y3, x4, y4)
    Variable px, py, x1, y1, x2, y2, x3, y3, x4, y4
    // avoid "\" line continuation
    Variable a = PointInTriangle(px, py, x1, y1, x2, y2, x3, y3)
    Variable b = PointInTriangle(px, py, x1, y1, x3, y3, x4, y4)
    return (a || b)
End

Function PointInPentagon(px, py, x1, y1, x2, y2, x3, y3, x4, y4, x5, y5)
    Variable px, py, x1, y1, x2, y2, x3, y3, x4, y4, x5, y5
    Variable a = PointInTriangle(px, py, x1, y1, x2, y2, x3, y3)
    Variable b = PointInTriangle(px, py, x1, y1, x3, y3, x4, y4)
    Variable c = PointInTriangle(px, py, x1, y1, x4, y4, x5, y5)
    return (a || b || c)
End

//============================================================
// 3) Base36 hash helpers
//============================================================
Function/S PadLeft(s, width)
    String s
    Variable width
    String out = s
    do
        if (strlen(out) >= width)
            break
        endif
        out = "0" + out
    while (1)
    return out
End

Function/S ToBase36(n)
    Variable n
    String A = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    if (n <= 0)
        return "0"
    endif
    String out = ""
    do
        Variable d = mod(n, 36)
        out = A[d, d] + out
        n = floor(n/36)
    while (n > 0)
    return out
End

Function LJZ_ROIVARY_EnsureOutRoot()
    roivary_ensure_folder()
    NewDataFolder/O root:ARPES_LJZ:ROIVARY_OUT
End

Function/S TriangleHash36(idx1, idy1, idx2, idy2, idx3, idy3[, nChars])
    Variable idx1, idy1, idx2, idy2, idx3, idy3, nChars
    if (ParamIsDefault(nChars))
        nChars = 6
    endif
    nChars = max(4, min(10, nChars))

    Variable A = 2000003, B = 10007, h = 1357911, M = 1
    Variable i
    for (i=0; i<nChars; i+=1)
        M *= 36
    endfor

    Make/FREE/D/N=6 v = {idx1, idy1, idx2, idy2, idx3, idy3}
    for (i=0; i<6; i+=1)
        h = mod(h*A + v[i]*B, M)
    endfor

    Variable chk = mod(h + idx1+idy1+idx2+idy2+idx3+idy3, 36)
    String body = PadLeft(ToBase36(h), nChars)
    String tail = ToBase36(chk)
    return "T" + body + tail
End

Function/S HashWave36(v, nChars)
    Wave v
    Variable nChars
    nChars = max(4, min(10, nChars))

    Variable i, M = 1
    for (i=0; i<nChars; i+=1)
        M *= 36
    endfor

    Variable A = 2000003, B = 10007, h = 1357911, S = 0
    Variable N = DimSize(v, 0)
    for (i=0; i<N; i+=1)
        h = mod(h*A + v[i]*B, M)
        S += v[i]
    endfor

    Variable chk = mod(h + S, 36)
    String body = PadLeft(ToBase36(h), nChars)
    String tail = ToBase36(chk)
    return body + tail
End

Function/S QuadHash36(idx1, idy1, idx2, idy2, idx3, idy3, idx4, idy4[, nChars])
    Variable idx1, idy1, idx2, idy2, idx3, idy3, idx4, idy4, nChars
    if (ParamIsDefault(nChars))
        nChars = 6
    endif
    Make/FREE/D/N=8 v = {idx1,idy1, idx2,idy2, idx3,idy3, idx4,idy4}
    return "Q" + HashWave36(v, nChars)
End

Function/S PentHash36(idx1, idy1, idx2, idy2, idx3, idy3, idx4, idy4, idx5, idy5[, nChars])
    Variable idx1, idy1, idx2, idy2, idx3, idy3, idx4, idy4, idx5, idy5, nChars
    if (ParamIsDefault(nChars))
        nChars = 6
    endif
    Make/FREE/D/N=10 v = {idx1,idy1, idx2,idy2, idx3,idy3, idx4,idy4, idx5,idy5}
    return "P" + HashWave36(v, nChars)
End

//============================================================
// 4) ROI integrate core (TVT / TVQ / TVP)  --- Output to ROIVARY_OUT
//============================================================
Function TVT3D_LJZ20251016(w, idx1, idy1, idx2, idy2, idx3, idy3[, Uz, showImg])
    Wave w
    Variable idx1, idy1, idx2, idy2, idx3, idy3
    Variable Uz, showImg

    if (!WaveExists(w) || WaveDims(w) != 3)
        Print "TVT3D: input wave must be 3D."
        return -1
    endif

    DFREF saved = GetDataFolderDFR()

    Variable nx = DimSize(w,0), ny = DimSize(w,1), nt = DimSize(w,2)
    Variable dx = DimDelta(w,0), x0 = DimOffset(w,0)
    Variable dy = DimDelta(w,1), y0 = DimOffset(w,1)
    Variable dt = DimDelta(w,2), t0 = DimOffset(w,2)

    String base = NameOfWave(w)
    String code = TriangleHash36(idx1, idy1, idx2, idy2, idx3, idy3, nChars=6)

    LJZ_ROIVARY_EnsureOutRoot()
    String outRoot = "root:ARPES_LJZ:ROIVARY_OUT:"
    String dfLeaf = base + "_TVT_" + code
    NewDataFolder/O $(outRoot + dfLeaf)
    SetDataFolder $(outRoot + dfLeaf)
    String dfFull = GetDataFolder(1)

    if (ParamIsDefault(showImg))
        showImg = 1
    endif

    String xlist = base + "_X_" + code
    String ylist = base + "_Y_" + code
    Make/O/N=4 $xlist = {idx1*dx+x0, idx2*dx+x0, idx3*dx+x0, idx1*dx+x0}
    Make/O/N=4 $ylist = {idy1*dy+y0, idy2*dy+y0, idy3*dy+y0, idy1*dy+y0}

    Printf "TVT indices: (%d,%d),(%d,%d),(%d,%d) -> %s\r", idx1,idy1,idx2,idy2,idx3,idy3,code

if (showImg)
    Wave wX = $xlist
    Wave wY = $ylist
    roivary_show_first_last_overlay_from3d(base, code, "T", w, wX, wY)
endif

    String traceName = base + "_T_" + code
    Make/O/N=(nt) $traceName
    Wave TVT_trace = $traceName
    SetScale/P x, t0, dt, TVT_trace

    Variable k,i,j
    Variable minX = Min3i(idx1, idx2, idx3)
    Variable maxX = Max3i(idx1, idx2, idx3)
    Variable minY = Min3i(idy1, idy2, idy3)
    Variable maxY = Max3i(idy1, idy2, idy3)

    for (k=0; k<nt; k+=1)
        Variable s = 0
        for (i=minX; i<=maxX; i+=1)
            for (j=minY; j<=maxY; j+=1)
                if (PointInTriangle(i, j, idx1, idy1, idx2, idy2, idx3, idy3))
                    s += w[i][j][k]
                endif
            endfor
        endfor
        TVT_trace[k] = s
    endfor

    String winTrace = base + "_T_" + code
    DoWindow/K $winTrace
    Display/N=$winTrace $(dfFull + traceName)
    DoWindow/F $winTrace
    Label left, "Integral of ROI (a.u.)"
    if (ParamIsDefault(Uz) || Uz == 0)
        Label bottom, "delay time (ps)"
    elseif (Uz == 1)
        Label bottom, "Temperature (K)"
    else
        Label bottom, "Fluence (mW)"
    endif
	ROIVARY_RememberLastTrace(dfFull + traceName)
	    SVAR/Z LastTracePath_RV = root:ARPES_LJZ:ROIVARY:LastTracePath_RV
    if (!SVAR_Exists(LastTracePath_RV))
        String/G root:ARPES_LJZ:ROIVARY:LastTracePath_RV = ""
    endif
    SVAR LastTracePath_RV2 = root:ARPES_LJZ:ROIVARY:LastTracePath_RV
    LastTracePath_RV2 = dfFull + traceName

    SVAR/Z LastResidualPath_RV = root:ARPES_LJZ:ROIVARY:LastResidualPath_RV
    if (!SVAR_Exists(LastResidualPath_RV))
        String/G root:ARPES_LJZ:ROIVARY:LastResidualPath_RV = ""
    endif
    SVAR LastResidualPath_RV2 = root:ARPES_LJZ:ROIVARY:LastResidualPath_RV
    LastResidualPath_RV2 = ""

SVAR/Z LastRunCode_RV = root:ARPES_LJZ:ROIVARY:LastRunCode_RV
if (!SVAR_Exists(LastRunCode_RV))
    String/G root:ARPES_LJZ:ROIVARY:LastRunCode_RV = ""
endif
SVAR LastRunCode_RV2 = root:ARPES_LJZ:ROIVARY:LastRunCode_RV
LastRunCode_RV2 = code

SVAR/Z CurrentCode_RV = root:ARPES_LJZ:ROIVARY:CurrentCode_RV
if (!SVAR_Exists(CurrentCode_RV))
    String/G root:ARPES_LJZ:ROIVARY:CurrentCode_RV = ""
endif
SVAR CurrentCode_RV2 = root:ARPES_LJZ:ROIVARY:CurrentCode_RV
CurrentCode_RV2 = code

    SetDataFolder saved
    return 0
End

Function TVQ3D_LJZ20251016(w, idx1, idy1, idx2, idy2, idx3, idy3, idx4, idy4[, Uz, showImg])
    Wave w
    Variable idx1, idy1, idx2, idy2, idx3, idy3, idx4, idy4
    Variable Uz, showImg

    if (!WaveExists(w) || WaveDims(w) != 3)
        Print "TVQ3D: input wave must be 3D."
        return -1
    endif

    DFREF saved = GetDataFolderDFR()

    Variable nx = DimSize(w,0), ny = DimSize(w,1), nt = DimSize(w,2)
    Variable dx = DimDelta(w,0), x0 = DimOffset(w,0)
    Variable dy = DimDelta(w,1), y0 = DimOffset(w,1)
    Variable dt = DimDelta(w,2), t0 = DimOffset(w,2)

    String base = NameOfWave(w)
    String code = QuadHash36(idx1, idy1, idx2, idy2, idx3, idy3, idx4, idy4, nChars=6)
    Printf "TVQ indices: (%d,%d),(%d,%d),(%d,%d),(%d,%d) -> %s\r", idx1,idy1,idx2,idy2,idx3,idy3,idx4,idy4,code

    LJZ_ROIVARY_EnsureOutRoot()
    String outRoot = "root:ARPES_LJZ:ROIVARY_OUT:"
    String dfLeaf = base + "_TVQ_" + code
    NewDataFolder/O $(outRoot + dfLeaf)
    SetDataFolder $(outRoot + dfLeaf)
    String dfFull = GetDataFolder(1)

    if (ParamIsDefault(showImg))
        showImg = 1
    endif

    String xlist = base + "_X_" + code
    String ylist = base + "_Y_" + code
    Make/O/N=5 $xlist = {idx1*dx+x0, idx2*dx+x0, idx3*dx+x0, idx4*dx+x0, idx1*dx+x0}
    Make/O/N=5 $ylist = {idy1*dy+y0, idy2*dy+y0, idy3*dy+y0, idy4*dy+y0, idy1*dy+y0}

    if (showImg)
        Wave wX = $xlist
        Wave wY = $ylist
        roivary_show_first_last_overlay_from3d(base, code, "Q", w, wX, wY)
    endif
    
    String traceName = base + "_Q_" + code
    Make/O/N=(nt) $traceName
    Wave TVQ_trace = $traceName
    SetScale/P x, t0, dt, TVQ_trace

    Variable k,i,j
    Variable minX = Min4i(idx1, idx2, idx3, idx4)
    Variable maxX = Max4i(idx1, idx2, idx3, idx4)
    Variable minY = Min4i(idy1, idy2, idy3, idy4)
    Variable maxY = Max4i(idy1, idy2, idy3, idy4)

    for (k=0; k<nt; k+=1)
        Variable s = 0
        for (i=minX; i<=maxX; i+=1)
            for (j=minY; j<=maxY; j+=1)
                if (PointInQuadrilateral(i, j, idx1, idy1, idx2, idy2, idx3, idy3, idx4, idy4))
                    s += w[i][j][k]
                endif
            endfor
        endfor
        TVQ_trace[k] = s
    endfor

    String winTrace = base + "_Q_" + code
    DoWindow/K $winTrace
    Display/N=$winTrace $(dfFull + traceName)
    DoWindow/F $winTrace
    Label left, "Integral of ROI (a.u.)"
    if (ParamIsDefault(Uz) || Uz == 0)
        Label bottom, "delay time (ps)"
    elseif (Uz == 1)
        Label bottom, "Temperature (K)"
    else
        Label bottom, "Fluence (mW)"
    endif
ROIVARY_RememberLastTrace(dfFull + traceName)
    SVAR/Z LastTracePath_RV = root:ARPES_LJZ:ROIVARY:LastTracePath_RV
    if (!SVAR_Exists(LastTracePath_RV))
        String/G root:ARPES_LJZ:ROIVARY:LastTracePath_RV = ""
    endif
    SVAR LastTracePath_RV2 = root:ARPES_LJZ:ROIVARY:LastTracePath_RV
    LastTracePath_RV2 = dfFull + traceName

    SVAR/Z LastResidualPath_RV = root:ARPES_LJZ:ROIVARY:LastResidualPath_RV
    if (!SVAR_Exists(LastResidualPath_RV))
        String/G root:ARPES_LJZ:ROIVARY:LastResidualPath_RV = ""
    endif
    SVAR LastResidualPath_RV2 = root:ARPES_LJZ:ROIVARY:LastResidualPath_RV
    LastResidualPath_RV2 = ""

SVAR/Z LastRunCode_RV = root:ARPES_LJZ:ROIVARY:LastRunCode_RV
if (!SVAR_Exists(LastRunCode_RV))
    String/G root:ARPES_LJZ:ROIVARY:LastRunCode_RV = ""
endif
SVAR LastRunCode_RV2 = root:ARPES_LJZ:ROIVARY:LastRunCode_RV
LastRunCode_RV2 = code

SVAR/Z CurrentCode_RV = root:ARPES_LJZ:ROIVARY:CurrentCode_RV
if (!SVAR_Exists(CurrentCode_RV))
    String/G root:ARPES_LJZ:ROIVARY:CurrentCode_RV = ""
endif
SVAR CurrentCode_RV2 = root:ARPES_LJZ:ROIVARY:CurrentCode_RV
CurrentCode_RV2 = code

    SetDataFolder saved
    return 0
End

Function TVP3D_LJZ20251016(w, idx1, idy1, idx2, idy2, idx3, idy3, idx4, idy4, idx5, idy5[, Uz, showImg])
    Wave w
    Variable idx1, idy1, idx2, idy2, idx3, idy3, idx4, idy4, idx5, idy5
    Variable Uz, showImg

    if (!WaveExists(w) || WaveDims(w) != 3)
        Print "TVP3D: input wave must be 3D."
        return -1
    endif

    DFREF saved = GetDataFolderDFR()

    Variable nx = DimSize(w,0), ny = DimSize(w,1), nt = DimSize(w,2)
    Variable dx = DimDelta(w,0), x0 = DimOffset(w,0)
    Variable dy = DimDelta(w,1), y0 = DimOffset(w,1)
    Variable dt = DimDelta(w,2), t0 = DimOffset(w,2)

    String base = NameOfWave(w)
    String code = PentHash36(idx1,idy1, idx2,idy2, idx3,idy3, idx4,idy4, idx5,idy5, nChars=6)
    Printf "TVP indices: (%d,%d),(%d,%d),(%d,%d),(%d,%d),(%d,%d) -> %s\r", idx1,idy1,idx2,idy2,idx3,idy3,idx4,idy4,idx5,idy5,code

    LJZ_ROIVARY_EnsureOutRoot()
    String outRoot = "root:ARPES_LJZ:ROIVARY_OUT:"
    String dfLeaf = base + "_TVP_" + code
    NewDataFolder/O $(outRoot + dfLeaf)
    SetDataFolder $(outRoot + dfLeaf)
    String dfFull = GetDataFolder(1)

    if (ParamIsDefault(showImg))
        showImg = 1
    endif

    String xlist = base + "_X_" + code
    String ylist = base + "_Y_" + code
    Make/O/N=6 $xlist = {idx1*dx+x0, idx2*dx+x0, idx3*dx+x0, idx4*dx+x0, idx5*dx+x0, idx1*dx+x0}
    Make/O/N=6 $ylist = {idy1*dy+y0, idy2*dy+y0, idy3*dy+y0, idy4*dy+y0, idy5*dy+y0, idy1*dy+y0}

    if (showImg)
        Wave wX = $xlist
        Wave wY = $ylist
        roivary_show_first_last_overlay_from3d(base, code, "P", w, wX, wY)
    endif
    
    String traceName = base + "_P_" + code
    Make/O/N=(nt) $traceName
    Wave TVP_trace = $traceName
    SetScale/P x, t0, dt, TVP_trace

    Variable k,i,j
    Variable minX = Min5i(idx1, idx2, idx3, idx4, idx5)
    Variable maxX = Max5i(idx1, idx2, idx3, idx4, idx5)
    Variable minY = Min5i(idy1, idy2, idy3, idy4, idy5)
    Variable maxY = Max5i(idy1, idy2, idy3, idy4, idy5)

    for (k=0; k<nt; k+=1)
        Variable s = 0
        for (i=minX; i<=maxX; i+=1)
            for (j=minY; j<=maxY; j+=1)
                if (PointInPentagon(i, j, idx1,idy1, idx2,idy2, idx3,idy3, idx4,idy4, idx5,idy5))
                    s += w[i][j][k]
                endif
            endfor
        endfor
        TVP_trace[k] = s
    endfor

    String winTrace = base + "_P_" + code
    DoWindow/K $winTrace
    Display/N=$winTrace $(dfFull + traceName)
    DoWindow/F $winTrace
    Label left, "Integral of ROI (a.u.)"
    if (ParamIsDefault(Uz) || Uz == 0)
        Label bottom, "delay time (ps)"
    elseif (Uz == 1)
        Label bottom, "Temperature (K)"
    else
        Label bottom, "Fluence (mW)"
    endif
ROIVARY_RememberLastTrace(dfFull + traceName)
    SVAR/Z LastTracePath_RV = root:ARPES_LJZ:ROIVARY:LastTracePath_RV
    if (!SVAR_Exists(LastTracePath_RV))
        String/G root:ARPES_LJZ:ROIVARY:LastTracePath_RV = ""
    endif
    SVAR LastTracePath_RV2 = root:ARPES_LJZ:ROIVARY:LastTracePath_RV
    LastTracePath_RV2 = dfFull + traceName

    SVAR/Z LastResidualPath_RV = root:ARPES_LJZ:ROIVARY:LastResidualPath_RV
    if (!SVAR_Exists(LastResidualPath_RV))
        String/G root:ARPES_LJZ:ROIVARY:LastResidualPath_RV = ""
    endif
    SVAR LastResidualPath_RV2 = root:ARPES_LJZ:ROIVARY:LastResidualPath_RV
    LastResidualPath_RV2 = ""

SVAR/Z LastRunCode_RV = root:ARPES_LJZ:ROIVARY:LastRunCode_RV
if (!SVAR_Exists(LastRunCode_RV))
    String/G root:ARPES_LJZ:ROIVARY:LastRunCode_RV = ""
endif
SVAR LastRunCode_RV2 = root:ARPES_LJZ:ROIVARY:LastRunCode_RV
LastRunCode_RV2 = code

SVAR/Z CurrentCode_RV = root:ARPES_LJZ:ROIVARY:CurrentCode_RV
if (!SVAR_Exists(CurrentCode_RV))
    String/G root:ARPES_LJZ:ROIVARY:CurrentCode_RV = ""
endif
SVAR CurrentCode_RV2 = root:ARPES_LJZ:ROIVARY:CurrentCode_RV
CurrentCode_RV2 = code

    SetDataFolder saved
    return 0
End

//============================================================
// 5) Wave list collection (SD3D style)
//============================================================
Function/S roivary_collect_3d_waves_recursive(baseDF)
    String baseDF

    String df0 = GetDataFolder(1)
    String outList = ""

    String base = roivary_df_with_colon(baseDF)
    if (!roivary_df_exists(base))
        return ""
    endif

    SetDataFolder $base

    String here = WaveList("*", ";", "DIMS:3")
    Variable i, n
    n = ItemsInList(here, ";")
    for (i=0; i<n; i+=1)
        String wn = StringFromList(i, here, ";")
        if (strlen(wn) == 0)
            continue
        endif
        outList += (base + wn + ";")
    endfor

    String subList = roivary_norm_list(DataFolderDir(2))
    Variable m = ItemsInList(subList, ";")
    for (i=0; i<m; i+=1)
        String fd = StringFromList(i, subList, ";")
        if (strlen(fd) == 0)
            continue
        endif
        outList += roivary_collect_3d_waves_recursive(base + fd + ":")
    endfor

    SetDataFolder df0
    return outList
End

//============================================================
// 6) Init / Defaults (globals, list waves)
//============================================================
Function roivary_init_defaults_if_needed()
    roivary_ensure_folder()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:ROIVARY

    if (!WaveExists($"LB_Items3D_RV"))
        Make/O/T/N=0 LB_Items3D_RV
    endif
    if (!WaveExists($"LB_Sel3D_RV"))
        Make/O/U/B/N=0 LB_Sel3D_RV
    endif

    SVAR/Z BasePathSel_RV = root:ARPES_LJZ:ROIVARY:BasePathSel_RV
    if (!SVAR_Exists(BasePathSel_RV))
        String/G BasePathSel_RV = "root:"
    endif

    NVAR/Z Recursive_RV = root:ARPES_LJZ:ROIVARY:Recursive_RV
    if (!NVAR_Exists(Recursive_RV))
        Variable/G Recursive_RV = 0
    endif

    SVAR/Z WaveSel_RV = root:ARPES_LJZ:ROIVARY:WaveSel_RV
    if (!SVAR_Exists(WaveSel_RV))
        String/G WaveSel_RV = ""
    endif

// user input code: only for Load Code textbox
SVAR/Z InputCode_RV = root:ARPES_LJZ:ROIVARY:InputCode_RV
if (!SVAR_Exists(InputCode_RV))
    String/G InputCode_RV = "T"
endif
if (strlen(InputCode_RV) == 0)
    InputCode_RV = "T"
endif

// current code: always derived from current ROI vertices
SVAR/Z CurrentCode_RV = root:ARPES_LJZ:ROIVARY:CurrentCode_RV
if (!SVAR_Exists(CurrentCode_RV))
    String/G CurrentCode_RV = ""
endif

// last run code: last ROI code that actually produced output
SVAR/Z LastRunCode_RV = root:ARPES_LJZ:ROIVARY:LastRunCode_RV
if (!SVAR_Exists(LastRunCode_RV))
    String/G LastRunCode_RV = ""
endif

    NVAR/Z ROI_shape_RV = root:ARPES_LJZ:ROIVARY:ROI_shape_RV
    if (!NVAR_Exists(ROI_shape_RV))
        Variable/G ROI_shape_RV = 1
    endif

    NVAR/Z ROI_Uz_RV = root:ARPES_LJZ:ROIVARY:ROI_Uz_RV
    if (!NVAR_Exists(ROI_Uz_RV))
        Variable/G ROI_Uz_RV = 1
    endif

    NVAR/Z ShowImages_RV = root:ARPES_LJZ:ROIVARY:ShowImages_RV
    if (!NVAR_Exists(ShowImages_RV))
        Variable/G ShowImages_RV = 1
    endif

    NVAR/Z ROI_ix1_RV = root:ARPES_LJZ:ROIVARY:ROI_ix1_RV
    if (!NVAR_Exists(ROI_ix1_RV))
        Variable/G ROI_ix1_RV = 0
    endif
    NVAR/Z ROI_iy1_RV = root:ARPES_LJZ:ROIVARY:ROI_iy1_RV
    if (!NVAR_Exists(ROI_iy1_RV))
        Variable/G ROI_iy1_RV = 0
    endif
    NVAR/Z ROI_ix2_RV = root:ARPES_LJZ:ROIVARY:ROI_ix2_RV
    if (!NVAR_Exists(ROI_ix2_RV))
        Variable/G ROI_ix2_RV = 0
    endif
    NVAR/Z ROI_iy2_RV = root:ARPES_LJZ:ROIVARY:ROI_iy2_RV
    if (!NVAR_Exists(ROI_iy2_RV))
        Variable/G ROI_iy2_RV = 0
    endif
    NVAR/Z ROI_ix3_RV = root:ARPES_LJZ:ROIVARY:ROI_ix3_RV
    if (!NVAR_Exists(ROI_ix3_RV))
        Variable/G ROI_ix3_RV = 0
    endif
    NVAR/Z ROI_iy3_RV = root:ARPES_LJZ:ROIVARY:ROI_iy3_RV
    if (!NVAR_Exists(ROI_iy3_RV))
        Variable/G ROI_iy3_RV = 0
    endif
    NVAR/Z ROI_ix4_RV = root:ARPES_LJZ:ROIVARY:ROI_ix4_RV
    if (!NVAR_Exists(ROI_ix4_RV))
        Variable/G ROI_ix4_RV = 0
    endif
    NVAR/Z ROI_iy4_RV = root:ARPES_LJZ:ROIVARY:ROI_iy4_RV
    if (!NVAR_Exists(ROI_iy4_RV))
        Variable/G ROI_iy4_RV = 0
    endif
    NVAR/Z ROI_ix5_RV = root:ARPES_LJZ:ROIVARY:ROI_ix5_RV
    if (!NVAR_Exists(ROI_ix5_RV))
        Variable/G ROI_ix5_RV = 0
    endif
    NVAR/Z ROI_iy5_RV = root:ARPES_LJZ:ROIVARY:ROI_iy5_RV
    if (!NVAR_Exists(ROI_iy5_RV))
        Variable/G ROI_iy5_RV = 0
    endif
       SVAR/Z WaveFilter_RV = root:ARPES_LJZ:ROIVARY:WaveFilter_RV
    if (!SVAR_Exists(WaveFilter_RV))
        String/G WaveFilter_RV = ""
    endif
    //name
SVAR/Z PlotBaseName_RV = root:ARPES_LJZ:ROIVARY:PlotBaseName_RV
if (!SVAR_Exists(PlotBaseName_RV))
    String/G PlotBaseName_RV = ""
endif

SVAR/Z FFTPlotBaseName_RV = root:ARPES_LJZ:ROIVARY:FFTPlotBaseName_RV
if (!SVAR_Exists(FFTPlotBaseName_RV))
    String/G FFTPlotBaseName_RV = ""
endif

    // -------- background / residual --------
    NVAR/Z BGMode_RV = root:ARPES_LJZ:ROIVARY:BGMode_RV
    if (!NVAR_Exists(BGMode_RV))
        Variable/G BGMode_RV = 1          // 1=DoubleExp, 2=Polynomial
    endif

    NVAR/Z BGPolyOrder_RV = root:ARPES_LJZ:ROIVARY:BGPolyOrder_RV
    if (!NVAR_Exists(BGPolyOrder_RV))
        Variable/G BGPolyOrder_RV = 2     // 1..4
    endif

    NVAR/Z BGFitX0_RV = root:ARPES_LJZ:ROIVARY:BGFitX0_RV
    if (!NVAR_Exists(BGFitX0_RV))
        Variable/G BGFitX0_RV = 0
    endif

    NVAR/Z BGFitX1_RV = root:ARPES_LJZ:ROIVARY:BGFitX1_RV
    if (!NVAR_Exists(BGFitX1_RV))
        Variable/G BGFitX1_RV = 20
    endif

    SVAR/Z LastTracePath_RV = root:ARPES_LJZ:ROIVARY:LastTracePath_RV
    if (!SVAR_Exists(LastTracePath_RV))
        String/G LastTracePath_RV = ""
    endif

    SVAR/Z LastResidualPath_RV = root:ARPES_LJZ:ROIVARY:LastResidualPath_RV
    if (!SVAR_Exists(LastResidualPath_RV))
        String/G LastResidualPath_RV = ""
    endif

    NVAR/Z FitXRef_RV = root:ARPES_LJZ:ROIVARY:FitXRef_RV
    if (!NVAR_Exists(FitXRef_RV))
        Variable/G FitXRef_RV = 0
    endif

    // -------- FFT --------
    NVAR/Z FFTX0_RV = root:ARPES_LJZ:ROIVARY:FFTX0_RV
    if (!NVAR_Exists(FFTX0_RV))
        Variable/G FFTX0_RV = 0
    endif

    NVAR/Z FFTX1_RV = root:ARPES_LJZ:ROIVARY:FFTX1_RV
    if (!NVAR_Exists(FFTX1_RV))
        Variable/G FFTX1_RV = 20
    endif

    NVAR/Z FFTWindowMode_RV = root:ARPES_LJZ:ROIVARY:FFTWindowMode_RV
    if (!NVAR_Exists(FFTWindowMode_RV))
        Variable/G FFTWindowMode_RV = 2    // 1=None 2=Hann 3=Hamming 4=Blackman
    endif

    NVAR/Z FFTDetrendMode_RV = root:ARPES_LJZ:ROIVARY:FFTDetrendMode_RV
    if (!NVAR_Exists(FFTDetrendMode_RV))
        Variable/G FFTDetrendMode_RV = 3   // 1=None 2=Mean 3=Mean+Linear
    endif

    NVAR/Z FFTZeroPadMode_RV = root:ARPES_LJZ:ROIVARY:FFTZeroPadMode_RV
    if (!NVAR_Exists(FFTZeroPadMode_RV))
        Variable/G FFTZeroPadMode_RV = 2   // 1=None 2=NextPow2 3=Factor
    endif

    NVAR/Z FFTZeroPadFactor_RV = root:ARPES_LJZ:ROIVARY:FFTZeroPadFactor_RV
    if (!NVAR_Exists(FFTZeroPadFactor_RV))
        Variable/G FFTZeroPadFactor_RV = 4
    endif

    NVAR/Z FFTFreqUnitMode_RV = root:ARPES_LJZ:ROIVARY:FFTFreqUnitMode_RV
    if (!NVAR_Exists(FFTFreqUnitMode_RV))
        Variable/G FFTFreqUnitMode_RV = 1  // 1 THz, 2 cm^-1, 3 meV
    endif

    NVAR/Z FFTOutputMode_RV = root:ARPES_LJZ:ROIVARY:FFTOutputMode_RV
    if (!NVAR_Exists(FFTOutputMode_RV))
        Variable/G FFTOutputMode_RV = 2    // 1 Mag, 2 Power, 3 Re, 4 Im
    endif

    NVAR/Z FFTPeakFind_RV = root:ARPES_LJZ:ROIVARY:FFTPeakFind_RV
    if (!NVAR_Exists(FFTPeakFind_RV))
        Variable/G FFTPeakFind_RV = 1
    endif

    NVAR/Z FFTPeakF0_RV = root:ARPES_LJZ:ROIVARY:FFTPeakF0_RV
    if (!NVAR_Exists(FFTPeakF0_RV))
        Variable/G FFTPeakF0_RV = 0.1
    endif

    NVAR/Z FFTPeakF1_RV = root:ARPES_LJZ:ROIVARY:FFTPeakF1_RV
    if (!NVAR_Exists(FFTPeakF1_RV))
        Variable/G FFTPeakF1_RV = 10
    endif
    roivary_fftwb_init_if_needed()
    SetDataFolder df0
End

//============================================================
// 7) List build (SD3D style)
//============================================================
Function roivary_rebuild_lb()
    roivary_ensure_folder()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:ROIVARY

    SVAR BasePathSel_RV = root:ARPES_LJZ:ROIVARY:BasePathSel_RV
    NVAR Recursive_RV   = root:ARPES_LJZ:ROIVARY:Recursive_RV
    SVAR WaveSel_RV     = root:ARPES_LJZ:ROIVARY:WaveSel_RV

    Wave/T   LB_Items3D_RV = root:ARPES_LJZ:ROIVARY:LB_Items3D_RV
    Wave/U/B LB_Sel3D_RV   = root:ARPES_LJZ:ROIVARY:LB_Sel3D_RV

    Redimension/N=0 LB_Items3D_RV, LB_Sel3D_RV
    WaveSel_RV = ""

    String base = roivary_df_with_colon(BasePathSel_RV)
    if (!roivary_df_exists(base))
        base = "root:"
    endif
    BasePathSel_RV = base

    SVAR WaveFilter_RV = root:ARPES_LJZ:ROIVARY:WaveFilter_RV

    String listStr
    if (Recursive_RV)
        listStr = roivary_collect_3d_waves_recursive(base)   // full paths
    else
        String df1 = GetDataFolder(1)
        SetDataFolder $base
        listStr = WaveList("*", ";", "DIMS:3")               // names only
        SetDataFolder df1
    endif

    // apply filter
    String filteredList = ""
    Variable ii, nn = ItemsInList(listStr, ";")
    for (ii=0; ii<nn; ii+=1)
        String oneItem = StringFromList(ii, listStr, ";")
        if (strlen(oneItem) == 0)
            continue
        endif

        // non-recursive mode listStr is just wave name, recursive mode is full path
        String onePath
        if (Recursive_RV)
            onePath = oneItem
        else
            onePath = base + oneItem
        endif

        if (roivary_filter_match(onePath, WaveFilter_RV))
            filteredList += oneItem + ";"
        endif
    endfor

    listStr = filteredList

    Variable n = ItemsInList(listStr, ";")
    if (n > 0)
        Redimension/N=(n) LB_Items3D_RV, LB_Sel3D_RV
        Variable i
        for (i=0; i<n; i+=1)
            LB_Items3D_RV[i] = StringFromList(i, listStr, ";")
            LB_Sel3D_RV[i] = 0
        endfor
    endif

    SetDataFolder df0

    DoWindow ROIVARY_LJZ_P
    if (V_flag)
        ControlUpdate/W=ROIVARY_LJZ_P lbWave3DRV
        TitleBox rv_status, win=ROIVARY_LJZ_P, title="Selected: (none)"
    endif

    return 0
End

//============================================================
// 8) ListBox proc: single select (SD3D style)
//============================================================
Function ROIVARY_LBProc(ctrlName, row, col, eventCode) : ListBoxControl
    String ctrlName
    Variable row, col, eventCode

    if (eventCode != 4)
        return 0
    endif

    Wave/U/B LB_Sel3D_RV   = root:ARPES_LJZ:ROIVARY:LB_Sel3D_RV
    Wave/T   LB_Items3D_RV = root:ARPES_LJZ:ROIVARY:LB_Items3D_RV
    SVAR     WaveSel_RV    = root:ARPES_LJZ:ROIVARY:WaveSel_RV
    SVAR     BasePathSel_RV= root:ARPES_LJZ:ROIVARY:BasePathSel_RV
    NVAR     Recursive_RV  = root:ARPES_LJZ:ROIVARY:Recursive_RV

    if (row < 0 || row >= DimSize(LB_Items3D_RV, 0))
        return 0
    endif

    LB_Sel3D_RV = 0
    LB_Sel3D_RV[row] = 1

    String item = LB_Items3D_RV[row]
    if (strlen(item) == 0)
        WaveSel_RV = ""
    else
        if (Recursive_RV)
            WaveSel_RV = item          // already full path
        else
            String base = roivary_df_with_colon(BasePathSel_RV)
            BasePathSel_RV = base
            WaveSel_RV = base + item   // build full path
        endif
    endif

    DoWindow ROIVARY_LJZ_P
    if (V_flag)
        TitleBox rv_status, win=ROIVARY_LJZ_P, title="Selected: " + WaveSel_RV
    endif

    return 0
End

//============================================================
// 9) Panel control procs (SetVariable / CheckBox / Buttons / Popups)
//============================================================
Function ROIVARY_SVBaseDFProc(ctrlName, varNum, varStr, varName) : SetVariableControl
    String ctrlName
    Variable varNum
    String varStr, varName

    SVAR BasePathSel_RV = root:ARPES_LJZ:ROIVARY:BasePathSel_RV
    String s = roivary_df_with_colon(BasePathSel_RV)
    if (!roivary_df_exists(s))
        s = "root:"
    endif
    BasePathSel_RV = s
    return 0
End

Function ROIVARY_CKRecProc(ctrlName, checked) : CheckBoxControl
    String ctrlName
    Variable checked
    // just scan again
    roivary_rebuild_lb()
    return 0
End

Function ROIVARY_SyncShapeUz()
    NVAR shp = root:ARPES_LJZ:ROIVARY:ROI_shape_RV
    NVAR uzm = root:ARPES_LJZ:ROIVARY:ROI_Uz_RV
    shp = max(1, min(3, shp))
    uzm = max(1, min(3, uzm))
    PopupMenu pmShapeRV, win=ROIVARY_LJZ_P, mode=shp
    PopupMenu pmUzRV,    win=ROIVARY_LJZ_P, mode=uzm
    return 0
End

Function ROIVARY_ROI_ShapeProc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName
    Variable popNum
    String popStr
    NVAR shp = root:ARPES_LJZ:ROIVARY:ROI_shape_RV
    shp = popNum
    return 0
End

Function ROIVARY_ROI_UzProc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName
    Variable popNum
    String popStr
    NVAR uzm = root:ARPES_LJZ:ROIVARY:ROI_Uz_RV
    uzm = popNum
    return 0
End

Function ROIVARY_RefreshList(ctrlName) : ButtonControl
    String ctrlName
    roivary_rebuild_lb()
    return 0
End

//============================================================
// 10) Preview / Overlay drawing
//============================================================
Function ROIVARY_Display(ctrlName) : ButtonControl
    String ctrlName

    SVAR wavePath = root:ARPES_LJZ:ROIVARY:WaveSel_RV
    if (strlen(wavePath) == 0)
        DoAlert 0, "Please select a 3D wave first."
        return 0
    endif

    Wave/Z wSel = $wavePath
    if (!WaveExists(wSel) || WaveDims(wSel) != 3)
        DoAlert 0, "Selected wave must be 3D."
        return 0
    endif

    Variable nx = DimSize(wSel,0)
    Variable ny = DimSize(wSel,1)
    Variable dx = DimDelta(wSel,0), x0 = DimOffset(wSel,0)
    Variable dy = DimDelta(wSel,1), y0 = DimOffset(wSel,1)

    String baseName = NameOfWave(wSel)
    String previewWaveName = baseName + "_ROIVARY_Preview"
    String windowName = roivary_sanitize_name(baseName + "_ROIVARY_PreviewWindow")

    Make/O/N=(nx,ny) $previewWaveName = wSel[p][q][0]
    Wave previewWave = $previewWaveName
    SetScale/P x, x0, dx, previewWave
    SetScale/P y, y0, dy, previewWave

    String xLab = roivary_nonempty_label(WaveUnits(previewWave,0), "X")
    String yLab = roivary_nonempty_label(WaveUnits(previewWave,1), "Y")

    DoWindow/K $windowName
    Display/N=$windowName
    AppendImage/W=$windowName previewWave
    DoWindow/F $windowName

    ModifyGraph/W=$windowName tick=2
    ModifyGraph/W=$windowName standoff=0
    ModifyGraph/W=$windowName mirror=0
    ModifyGraph/W=$windowName margin(left)=58,margin(bottom)=48,margin(right)=18,margin(top)=18
    ModifyImage/W=$windowName $NameOfWave(previewWave) ctab={*,*,Terrain256,0}

    Label/W=$windowName left, yLab
    Label/W=$windowName bottom, xLab
    SetAxis/A/W=$windowName left
    SetAxis/A/W=$windowName bottom

    ShowInfo/W=$windowName
    return 0
End

Function ROIVARY_GetCursorPositions(ctrlName) : ButtonControl
    String ctrlName

    SVAR wavePath = root:ARPES_LJZ:ROIVARY:WaveSel_RV
    if (strlen(wavePath) == 0)
        DoAlert 0, "Please select a 3D wave first."
        return 0
    endif

    Wave/Z wSel = $wavePath
    if (!WaveExists(wSel) || WaveDims(wSel) != 3)
        DoAlert 0, "Selected wave must be 3D."
        return 0
    endif

    Variable nx = DimSize(wSel,0), ny = DimSize(wSel,1)

    String baseName = NameOfWave(wSel)
    String windowName = roivary_sanitize_name(baseName + "_ROIVARY_PreviewWindow")
    if (!WinType(windowName))
        DoAlert 0, "Preview window does not exist. Please run Preview first."
        return 0
    endif

    NVAR i1 = root:ARPES_LJZ:ROIVARY:ROI_ix1_RV
    NVAR j1 = root:ARPES_LJZ:ROIVARY:ROI_iy1_RV
    NVAR i2 = root:ARPES_LJZ:ROIVARY:ROI_ix2_RV
    NVAR j2 = root:ARPES_LJZ:ROIVARY:ROI_iy2_RV
    NVAR i3 = root:ARPES_LJZ:ROIVARY:ROI_ix3_RV
    NVAR j3 = root:ARPES_LJZ:ROIVARY:ROI_iy3_RV
    NVAR i4 = root:ARPES_LJZ:ROIVARY:ROI_ix4_RV
    NVAR j4 = root:ARPES_LJZ:ROIVARY:ROI_iy4_RV
    NVAR i5 = root:ARPES_LJZ:ROIVARY:ROI_ix5_RV
    NVAR j5 = root:ARPES_LJZ:ROIVARY:ROI_iy5_RV

    i1 = NaN; j1 = NaN
    i2 = NaN; j2 = NaN
    i3 = NaN; j3 = NaN
    i4 = NaN; j4 = NaN
    i5 = NaN; j5 = NaN

    Variable cursorCount = 0
    String infoStr, yPointStr
    Variable isFree, px, py

    // ---------- Cursor A ----------
    infoStr = CsrInfo(A, windowName)
    if (strlen(infoStr) > 0)
        yPointStr = StringByKey("YPOINT", infoStr, ":", ";")
        if (strlen(yPointStr) > 0)
            isFree = NumberByKey("ISFREE", infoStr, ":", ";")
            px = NumberByKey("POINT", infoStr, ":", ";")
            py = NumberByKey("YPOINT", infoStr, ":", ";")

            if (isFree)
                i1 = max(0, min(nx-1, round(px*(nx-1))))
                j1 = max(0, min(ny-1, round(py*(ny-1))))
            else
                i1 = max(0, min(nx-1, round(px)))
                j1 = max(0, min(ny-1, round(py)))
            endif

            cursorCount += 1
            Printf "Cursor A -> (i,j)=(%d,%d)\r", i1, j1
        endif
    endif

    // ---------- Cursor B ----------
    infoStr = CsrInfo(B, windowName)
    if (strlen(infoStr) > 0)
        yPointStr = StringByKey("YPOINT", infoStr, ":", ";")
        if (strlen(yPointStr) > 0)
            isFree = NumberByKey("ISFREE", infoStr, ":", ";")
            px = NumberByKey("POINT", infoStr, ":", ";")
            py = NumberByKey("YPOINT", infoStr, ":", ";")

            if (isFree)
                i2 = max(0, min(nx-1, round(px*(nx-1))))
                j2 = max(0, min(ny-1, round(py*(ny-1))))
            else
                i2 = max(0, min(nx-1, round(px)))
                j2 = max(0, min(ny-1, round(py)))
            endif

            cursorCount += 1
            Printf "Cursor B -> (i,j)=(%d,%d)\r", i2, j2
        endif
    endif

    // ---------- Cursor C ----------
    infoStr = CsrInfo(C, windowName)
    if (strlen(infoStr) > 0)
        yPointStr = StringByKey("YPOINT", infoStr, ":", ";")
        if (strlen(yPointStr) > 0)
            isFree = NumberByKey("ISFREE", infoStr, ":", ";")
            px = NumberByKey("POINT", infoStr, ":", ";")
            py = NumberByKey("YPOINT", infoStr, ":", ";")

            if (isFree)
                i3 = max(0, min(nx-1, round(px*(nx-1))))
                j3 = max(0, min(ny-1, round(py*(ny-1))))
            else
                i3 = max(0, min(nx-1, round(px)))
                j3 = max(0, min(ny-1, round(py)))
            endif

            cursorCount += 1
            Printf "Cursor C -> (i,j)=(%d,%d)\r", i3, j3
        endif
    endif

    // ---------- Cursor D ----------
    infoStr = CsrInfo(D, windowName)
    if (strlen(infoStr) > 0)
        yPointStr = StringByKey("YPOINT", infoStr, ":", ";")
        if (strlen(yPointStr) > 0)
            isFree = NumberByKey("ISFREE", infoStr, ":", ";")
            px = NumberByKey("POINT", infoStr, ":", ";")
            py = NumberByKey("YPOINT", infoStr, ":", ";")

            if (isFree)
                i4 = max(0, min(nx-1, round(px*(nx-1))))
                j4 = max(0, min(ny-1, round(py*(ny-1))))
            else
                i4 = max(0, min(nx-1, round(px)))
                j4 = max(0, min(ny-1, round(py)))
            endif

            cursorCount += 1
            Printf "Cursor D -> (i,j)=(%d,%d)\r", i4, j4
        endif
    endif

    // ---------- Cursor E ----------
    infoStr = CsrInfo(E, windowName)
    if (strlen(infoStr) > 0)
        yPointStr = StringByKey("YPOINT", infoStr, ":", ";")
        if (strlen(yPointStr) > 0)
            isFree = NumberByKey("ISFREE", infoStr, ":", ";")
            px = NumberByKey("POINT", infoStr, ":", ";")
            py = NumberByKey("YPOINT", infoStr, ":", ";")

            if (isFree)
                i5 = max(0, min(nx-1, round(px*(nx-1))))
                j5 = max(0, min(ny-1, round(py*(ny-1))))
            else
                i5 = max(0, min(nx-1, round(px)))
                j5 = max(0, min(ny-1, round(py)))
            endif

            cursorCount += 1
            Printf "Cursor E -> (i,j)=(%d,%d)\r", i5, j5
        endif
    endif

    if (cursorCount > 0)
        DoAlert 0, "Read " + num2str(cursorCount) + " cursor(s) into ROI indices."
    else
        DoAlert 0, "No valid image cursors found. Please click Preview, then place cursors A/B/C/... on the image."
    endif

    return 0
End



Function ROIVARY_ROI_DrawOverlay(ctrlName) : ButtonControl
    String ctrlName

    SVAR wavePath = root:ARPES_LJZ:ROIVARY:WaveSel_RV
    if (strlen(wavePath) == 0)
        DoAlert 0, "Please select a 3D wave first."
        return 0
    endif

    Wave/Z wSel = $wavePath
    if (!WaveExists(wSel) || WaveDims(wSel) != 3)
        DoAlert 0, "Selected wave must be 3D."
        return 0
    endif

    if (roivary_validate_current_roi_for_wave(wSel, 1) != 0)
        return 0
    endif

    NVAR shp = root:ARPES_LJZ:ROIVARY:ROI_shape_RV
    NVAR i1 = root:ARPES_LJZ:ROIVARY:ROI_ix1_RV
    NVAR j1 = root:ARPES_LJZ:ROIVARY:ROI_iy1_RV
    NVAR i2 = root:ARPES_LJZ:ROIVARY:ROI_ix2_RV
    NVAR j2 = root:ARPES_LJZ:ROIVARY:ROI_iy2_RV
    NVAR i3 = root:ARPES_LJZ:ROIVARY:ROI_ix3_RV
    NVAR j3 = root:ARPES_LJZ:ROIVARY:ROI_iy3_RV
    NVAR i4 = root:ARPES_LJZ:ROIVARY:ROI_ix4_RV
    NVAR j4 = root:ARPES_LJZ:ROIVARY:ROI_iy4_RV
    NVAR i5 = root:ARPES_LJZ:ROIVARY:ROI_ix5_RV
    NVAR j5 = root:ARPES_LJZ:ROIVARY:ROI_iy5_RV

    Variable dx = DimDelta(wSel,0), x0 = DimOffset(wSel,0)
    Variable dy = DimDelta(wSel,1), y0 = DimOffset(wSel,1)

    String base = NameOfWave(wSel)
    String code = roivary_get_current_code_from_state()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:ROIVARY

    String xName = roivary_sanitize_name("DrawX_" + base + "_" + code)
    String yName = roivary_sanitize_name("DrawY_" + base + "_" + code)

    String tagPrefix = "D"

    if (shp == 1)
        Make/O/N=4 $xName = {i1*dx+x0, i2*dx+x0, i3*dx+x0, i1*dx+x0}
        Make/O/N=4 $yName = {j1*dy+y0, j2*dy+y0, j3*dy+y0, j1*dy+y0}
        tagPrefix = "DT"
    elseif (shp == 2)
        Make/O/N=5 $xName = {i1*dx+x0, i2*dx+x0, i3*dx+x0, i4*dx+x0, i1*dx+x0}
        Make/O/N=5 $yName = {j1*dy+y0, j2*dy+y0, j3*dy+y0, j4*dy+y0, j1*dy+y0}
        tagPrefix = "DQ"
    else
        Make/O/N=6 $xName = {i1*dx+x0, i2*dx+x0, i3*dx+x0, i4*dx+x0, i5*dx+x0, i1*dx+x0}
        Make/O/N=6 $yName = {j1*dy+y0, j2*dy+y0, j3*dy+y0, j4*dy+y0, j5*dy+y0, j1*dy+y0}
        tagPrefix = "DP"
    endif

    Wave wX = $xName
    Wave wY = $yName

    SetDataFolder df0

    roivary_show_first_last_overlay_from3d(base, code, tagPrefix, wSel, wX, wY)
    return 0
End

//============================================================
// 11) Run integration button
//============================================================
Function ROIVARY_ROI_RunButton(ctrlName) : ButtonControl
    String ctrlName

    SVAR wavePath = root:ARPES_LJZ:ROIVARY:WaveSel_RV
    if (strlen(wavePath) == 0)
        DoAlert 0, "Please select a 3D wave first."
        return 0
    endif

    Wave/Z wSel = $wavePath
    if (!WaveExists(wSel) || WaveDims(wSel) != 3)
        DoAlert 0, "Selected wave must be 3D."
        return 0
    endif
    if (roivary_validate_current_roi_for_wave(wSel, 1) != 0)
        return 0 // 验证不通过，拦截运行
    endif

    NVAR shp = root:ARPES_LJZ:ROIVARY:ROI_shape_RV
    NVAR uzm = root:ARPES_LJZ:ROIVARY:ROI_Uz_RV
    NVAR showImg = root:ARPES_LJZ:ROIVARY:ShowImages_RV

    NVAR i1 = root:ARPES_LJZ:ROIVARY:ROI_ix1_RV, j1 = root:ARPES_LJZ:ROIVARY:ROI_iy1_RV
    NVAR i2 = root:ARPES_LJZ:ROIVARY:ROI_ix2_RV, j2 = root:ARPES_LJZ:ROIVARY:ROI_iy2_RV
    NVAR i3 = root:ARPES_LJZ:ROIVARY:ROI_ix3_RV, j3 = root:ARPES_LJZ:ROIVARY:ROI_iy3_RV
    NVAR i4 = root:ARPES_LJZ:ROIVARY:ROI_ix4_RV, j4 = root:ARPES_LJZ:ROIVARY:ROI_iy4_RV
    NVAR i5 = root:ARPES_LJZ:ROIVARY:ROI_ix5_RV, j5 = root:ARPES_LJZ:ROIVARY:ROI_iy5_RV

    // UI uzm: 1..3 ; algorithm Uz: 0..2
    Variable Uz = uzm - 1

    if (shp == 1)
        TVT3D_LJZ20251016(wSel, i1,j1, i2,j2, i3,j3, Uz=Uz, showImg=showImg)
    elseif (shp == 2)
        TVQ3D_LJZ20251016(wSel, i1,j1, i2,j2, i3,j3, i4,j4, Uz=Uz, showImg=showImg)
    else
        TVP3D_LJZ20251016(wSel, i1,j1, i2,j2, i3,j3, i4,j4, i5,j5, Uz=Uz, showImg=showImg)
    endif

    return 0
End

//============================================================
// 12) Load from code (now O(1) because output fixed to ROIVARY_OUT)
//============================================================
Function ROIVARY_LoadParamsFromCode(ctrlName) : ButtonControl
    String ctrlName

    SVAR codeIn  = root:ARPES_LJZ:ROIVARY:InputCode_RV
    SVAR wavePath = root:ARPES_LJZ:ROIVARY:WaveSel_RV

    String code = UpperStr(ReplaceString(" ", codeIn, ""))
    if (strlen(code) < 5)
        DoAlert 0, "Invalid Code."
        return 0
    endif
    if (strlen(wavePath) == 0)
        DoAlert 0, "Please select a 3D wave first."
        return 0
    endif

    Wave/Z w = $wavePath
    if (!WaveExists(w) || WaveDims(w) != 3)
        DoAlert 0, "Selected wave must be 3D."
        return 0
    endif

    String firstChar = code[0,0]
    String typeStr = ""
    Variable targetShape = 0
    if (StringMatch(firstChar, "T"))
        typeStr = "_TVT_"
        targetShape = 1
    elseif (StringMatch(firstChar, "Q"))
        typeStr = "_TVQ_"
        targetShape = 2
    elseif (StringMatch(firstChar, "P"))
        typeStr = "_TVP_"
        targetShape = 3
    else
        DoAlert 0, "Unknown Code type. Must start with T/Q/P."
        return 0
    endif

    String baseName = NameOfWave(w)

    // output fixed root
    LJZ_ROIVARY_EnsureOutRoot()
    String dfAbs = "root:ARPES_LJZ:ROIVARY_OUT:" + baseName + typeStr + code + ":"
    if (!DataFolderExists(dfAbs))
        DoAlert 0, "ROI folder not found in root:ARPES_LJZ:ROIVARY_OUT:. Re-run ROI once."
        return 0
    endif

    String xName = baseName + "_X_" + code
    String yName = baseName + "_Y_" + code
    Wave/Z wX = $(dfAbs + xName)
    Wave/Z wY = $(dfAbs + yName)
    if (!WaveExists(wX) || !WaveExists(wY))
        DoAlert 0, "X/Y waves not found in ROI folder."
        return 0
    endif

    Variable needN
    if (targetShape == 1)
        needN = 4
    elseif (targetShape == 2)
        needN = 5
    else
        needN = 6
    endif
    if (DimSize(wX,0) < needN || DimSize(wY,0) < needN)
        DoAlert 0, "X/Y waves have unexpected length."
        return 0
    endif

    Variable nx = DimSize(w,0), ny = DimSize(w,1)
    Variable dx = DimDelta(w,0), x0 = DimOffset(w,0)
    Variable dy = DimDelta(w,1), y0 = DimOffset(w,1)

    NVAR shp = root:ARPES_LJZ:ROIVARY:ROI_shape_RV
    NVAR i1 = root:ARPES_LJZ:ROIVARY:ROI_ix1_RV, j1 = root:ARPES_LJZ:ROIVARY:ROI_iy1_RV
    NVAR i2 = root:ARPES_LJZ:ROIVARY:ROI_ix2_RV, j2 = root:ARPES_LJZ:ROIVARY:ROI_iy2_RV
    NVAR i3 = root:ARPES_LJZ:ROIVARY:ROI_ix3_RV, j3 = root:ARPES_LJZ:ROIVARY:ROI_iy3_RV
    NVAR i4 = root:ARPES_LJZ:ROIVARY:ROI_ix4_RV, j4 = root:ARPES_LJZ:ROIVARY:ROI_iy4_RV
    NVAR i5 = root:ARPES_LJZ:ROIVARY:ROI_ix5_RV, j5 = root:ARPES_LJZ:ROIVARY:ROI_iy5_RV

    shp = targetShape

    Variable ti
    ti = round((wX[0]-x0)/dx);  i1 = max(0, min(nx-1, ti))
    ti = round((wY[0]-y0)/dy);  j1 = max(0, min(ny-1, ti))

    ti = round((wX[1]-x0)/dx);  i2 = max(0, min(nx-1, ti))
    ti = round((wY[1]-y0)/dy);  j2 = max(0, min(ny-1, ti))

    ti = round((wX[2]-x0)/dx);  i3 = max(0, min(nx-1, ti))
    ti = round((wY[2]-y0)/dy);  j3 = max(0, min(ny-1, ti))

    if (targetShape >= 2)
        ti = round((wX[3]-x0)/dx);  i4 = max(0, min(nx-1, ti))
        ti = round((wY[3]-y0)/dy);  j4 = max(0, min(ny-1, ti))
    endif
    if (targetShape >= 3)
        ti = round((wX[4]-x0)/dx);  i5 = max(0, min(nx-1, ti))
        ti = round((wY[4]-y0)/dy);  j5 = max(0, min(ny-1, ti))
    endif

    ROIVARY_SyncShapeUz()
    ROIVARY_UpdateCurrentCode()
    Print "Loaded ROI vertices from: " + dfAbs
    return 0
End

//============================================================
// 13) Help / Close
//============================================================
Function ROIVARY_Help(ctrlName) : ButtonControl
    String ctrlName

    String msg = "ROIVARY (LJZ) usage:\r"
    msg += "1) Set Base DF and Scan 3D waves.\r"
    msg += "2) Select one 3D wave.\r"
    msg += "3) Preview first frame, place cursors A/B/C/... .\r"
    msg += "4) Get Cursor Position and adjust ROI vertices if needed.\r"
    msg += "5) Draw ROI overlay and Run ROI Trace.\r"
    msg += "6) The latest generated trace will be remembered automatically.\r"
    msg += "7) For time-resolved data (Uz=delay), you can then run:\r"
    msg += "   - DoubleExp BG + FFT\r"
    msg += "   - Polynomial BG + FFT\r"
    msg += "8) FFT is applied to the residual within the selected FFT time range.\r"
    msg += "Output folders are under root:ARPES_LJZ:ROIVARY_OUT:\r"

    DoAlert 0, msg
    return 0
End

Function ROIVARY_Close(ctrlName) : ButtonControl
    String ctrlName
    DoWindow/K ROIVARY_LJZ_P
    return 0
End

//============================================================
// 14) Entry Proc + Menu
//============================================================
Proc ROIVARY_LJZ()
    roivary_init_defaults_if_needed()

    DoWindow/F ROIVARY_LJZ_P
    if (V_flag == 0)
        ROIVARY_LJZ_P()
    endif

    roivary_rebuild_lb()
    ROIVARY_SyncShapeUz()
End

Menu "ARPES_LJZ"
    "ROIVARY (Polygon ROI -> Trace)", ROIVARY_LJZ()
End

//============================================================
// 15) Panel (SD3D-style Base DF selection)  --- COMPLETE
//============================================================
Window ROIVARY_LJZ_P() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(330,79.8,1003.8,747) as "ROIVARY_LJZ"
	ModifyPanel frameStyle=1
	ShowTools/A
	GroupBox gbSource,pos={12.00,9.00},size={318.00,372.00},title="Source / Wave Selection"
	TitleBox rv_status,pos={24.00,30.60},size={88.80,18.00},title="Selected: (none)"
	TitleBox rv_status,frame=0
	TitleBox rv_tdf,pos={24.00,57.00},size={47.40,18.00},title="Base DF:",frame=0
	SetVariable rv_sv_df,pos={81.00,54.00},size={174.60,19.80},proc=ROIVARY_SVBaseDFProc
	SetVariable rv_sv_df,value= root:ARPES_LJZ:ROIVARY:BasePathSel_RV
	CheckBox rv_ck_rec,pos={24.00,84.00},size={63.60,18.00},proc=ROIVARY_CKRecProc,title="Recursive"
	CheckBox rv_ck_rec,variable= root:ARPES_LJZ:ROIVARY:Recursive_RV
	Button btnRefreshRV,pos={120.60,78.60},size={90.60,21.00},proc=ROIVARY_RefreshList,title="Scan"
	
	TitleBox tFilterRV,pos={24.00,108.60},size={37.80,18.00},title="Filter:",frame=0
	SetVariable rv_sv_filter,pos={69.00,105.60},size={186.00,19.80},proc=ROIVARY_SVFilterProc
	SetVariable rv_sv_filter,value= root:ARPES_LJZ:ROIVARY:WaveFilter_RV
	Button btnClrFilterRV,pos={262.80,105.60},size={43.20,19.80},proc=ROIVARY_ClearFilter,title="Clear"

	TitleBox t1,pos={24.00,135.60},size={55.80,18.00},title="3D waves:",frame=0
	ListBox lbWave3DRV,pos={24.00,157.20},size={282.00,205.20},proc=ROIVARY_LBProc
	ListBox lbWave3DRV,listWave=root:ARPES_LJZ:ROIVARY:LB_Items3D_RV
	ListBox lbWave3DRV,selWave=root:ARPES_LJZ:ROIVARY:LB_Sel3D_RV,mode= 1,selRow= 0
	
	GroupBox gbROI,pos={342.00,9.00},size={318.60,252.00},title="ROI Settings"
	TitleBox r0,pos={354.00,33.00},size={37.20,18.00},title="Shape:",frame=0
	PopupMenu pmShapeRV,pos={402.60,30.00},size={56.40,20.40},proc=ROIVARY_ROI_ShapeProc
	PopupMenu pmShapeRV,mode=1,popvalue="Triangle",value= #"\"Triangle;Quadrilateral;Pentagon;\""
	TitleBox rUz,pos={528.00,33.00},size={17.40,18.00},title="Uz:",frame=0
	PopupMenu pmUzRV,pos={558.00,30.00},size={62.40,20.40},proc=ROIVARY_ROI_UzProc
	PopupMenu pmUzRV,mode=1,popvalue="delay(ps)",value= #"\"delay(ps);Temperature(K);Fluence(mW);\""
	TitleBox r2,pos={354.00,60.00},size={73.80,18.00},title="Indices (ix,iy):"
	TitleBox r2,frame=0
	SetVariable ix1,pos={354.00,84.00},size={66.60,19.80},title="i1"
	SetVariable ix1,limits={0,inf,1},value= root:ARPES_LJZ:ROIVARY:ROI_ix1_RV
	SetVariable iy1,pos={432.00,84.00},size={66.60,19.80},title="j1"
	SetVariable iy1,limits={0,inf,1},value= root:ARPES_LJZ:ROIVARY:ROI_iy1_RV
	SetVariable ix2,pos={510.00,84.00},size={66.60,19.80},title="i2"
	SetVariable ix2,limits={0,inf,1},value= root:ARPES_LJZ:ROIVARY:ROI_ix2_RV
	SetVariable iy2,pos={588.00,84.00},size={66.60,19.80},title="j2"
	SetVariable iy2,limits={0,inf,1},value= root:ARPES_LJZ:ROIVARY:ROI_iy2_RV
	SetVariable ix3,pos={354.00,108.60},size={66.60,19.80},title="i3"
	SetVariable ix3,limits={0,inf,1},value= root:ARPES_LJZ:ROIVARY:ROI_ix3_RV
	SetVariable iy3,pos={432.00,108.60},size={66.60,19.80},title="j3"
	SetVariable iy3,limits={0,inf,1},value= root:ARPES_LJZ:ROIVARY:ROI_iy3_RV
	SetVariable ix4,pos={510.00,108.60},size={66.60,19.80},title="i4"
	SetVariable ix4,limits={0,inf,1},value= root:ARPES_LJZ:ROIVARY:ROI_ix4_RV
	SetVariable iy4,pos={588.00,108.60},size={66.60,19.80},title="j4"
	SetVariable iy4,limits={0,inf,1},value= root:ARPES_LJZ:ROIVARY:ROI_iy4_RV
	SetVariable ix5,pos={354.00,135.00},size={66.60,19.80},title="i5"
	SetVariable ix5,limits={0,inf,1},value= root:ARPES_LJZ:ROIVARY:ROI_ix5_RV
	SetVariable iy5,pos={432.00,135.00},size={66.60,19.80},title="j5"
	SetVariable iy5,limits={0,inf,1},value= root:ARPES_LJZ:ROIVARY:ROI_iy5_RV
	CheckBox cbShowImg,pos={354.00,165.00},size={138.60,18.00},title="Show First/Last Images"
	CheckBox cbShowImg,variable= root:ARPES_LJZ:ROIVARY:ShowImages_RV
	TitleBox tCode,pos={354.00,192.60},size={31.80,18.00},title="Code:",frame=0
	SetVariable svCode,pos={391.80,192.00},size={198.60,19.80}
	SetVariable svCode,value= root:ARPES_LJZ:ROIVARY:InputCode_RV
	TitleBox tPlotBase,pos={354.00,219.00},size={50.40,18.00},title="PlotBase:"
	TitleBox tPlotBase,frame=0
	SetVariable svPlotBase,pos={414.60,216.60},size={198.60,19.80}
	SetVariable svPlotBase,value= root:ARPES_LJZ:ROIVARY:PlotBaseName_RV
	Button btnLoadCode,pos={564.00,159.00},size={84.00,24.00},proc=ROIVARY_LoadParamsFromCode,title="Load Code"
	GroupBox gbAction,pos={342.00,270.00},size={318.60,111.00},title="Actions"
	Button btnPreview,pos={354.00,294.00},size={144.00,27.00},proc=ROIVARY_Display,title="Preview (first)"
	Button btnGetCursor,pos={507.00,294.00},size={144.00,27.00},proc=ROIVARY_GetCursorPositions,title="Get Cursor Position"
	Button btnDraw,pos={354.00,330.00},size={144.00,27.00},proc=ROIVARY_ROI_DrawOverlay,title="Draw ROI"
	Button btnGo,pos={507.00,330.00},size={144.00,27.00},proc=ROIVARY_ROI_RunButton,title="Run ROI Trace"
	GroupBox gbUtility,pos={342.00,390.00},size={318.60,72.00},title="Utility"
	Button btnHelp,pos={354.00,417.00},size={144.00,24.00},proc=ROIVARY_Help,title="Help"
	Button btnClose,pos={507.00,417.00},size={144.00,24.00},proc=ROIVARY_Close,title="Close"
	GroupBox gbBG,pos={12.00,390.00},size={318.00,111.00},title="Background / Residual"
	PopupMenu pmBGModeRV,pos={24.00,417.00},size={126.60,20.40},proc=ROIVARY_BGModeProc,title="BG Mode"
	PopupMenu pmBGModeRV,mode=1,popvalue="DoubleExp",value= #"\"DoubleExp;Polynomial;\""
	SetVariable svBGFitX0,pos={24.00,447.00},size={93.00,19.80},title="Fit x0"
	SetVariable svBGFitX0,limits={-inf,inf,0.1},value= root:ARPES_LJZ:ROIVARY:BGFitX0_RV
	SetVariable svBGFitX1,pos={126.00,447.00},size={93.00,19.80},title="Fit x1"
	SetVariable svBGFitX1,limits={-inf,inf,0.1},value= root:ARPES_LJZ:ROIVARY:BGFitX1_RV
	SetVariable svBGPolyOrder,pos={228.00,447.00},size={75.00,19.80},title="Poly N"
	SetVariable svBGPolyOrder,limits={1,4,1},value= root:ARPES_LJZ:ROIVARY:BGPolyOrder_RV
	Button btnBGRun,pos={96.60,474.00},size={138.60,24.00},proc=ROIVARY_BG_RunButton,title="Fit BG + Residual"
	GroupBox gbFFT,pos={12.00,510.00},size={648.60,144.00},title="FFT Analysis"
	SetVariable svFFTX0,pos={24.00,534.60},size={90.60,19.80},title="FFT x0"
	SetVariable svFFTX0,limits={-inf,inf,0.1},value= root:ARPES_LJZ:ROIVARY:FFTX0_RV
	SetVariable svFFTX1,pos={126.00,534.60},size={90.60,19.80},title="FFT x1"
	SetVariable svFFTX1,limits={-inf,inf,0.1},value= root:ARPES_LJZ:ROIVARY:FFTX1_RV
	PopupMenu pmFFTWindowRV,pos={234.60,534.60},size={90.60,20.40},proc=ROIVARY_FFTWindowProc,title="Window"
	PopupMenu pmFFTWindowRV,mode=2,popvalue="Hann",value= #"\"None;Hann;Hamming;Blackman;\""
	PopupMenu pmFFTDetrendRV,pos={360.00,534.60},size={133.80,20.40},proc=ROIVARY_FFTDetrendProc,title="Detrend"
	PopupMenu pmFFTDetrendRV,mode=3,popvalue="Mean+Linear",value= #"\"None;Mean;Mean+Linear;\""
	PopupMenu pmFFTZeroPadRV,pos={24.00,564.60},size={116.40,20.40},proc=ROIVARY_FFTZeroPadProc,title="ZeroPad"
	PopupMenu pmFFTZeroPadRV,mode=2,popvalue="NextPow2",value= #"\"None;NextPow2;Factor;\""
	SetVariable svFFTPadFac,pos={147.00,564.60},size={90.60,19.80},title="Pad Fac"
	SetVariable svFFTPadFac,limits={1,32,1},value= root:ARPES_LJZ:ROIVARY:FFTZeroPadFactor_RV
	PopupMenu pmFFTUnitRV,pos={255.00,564.60},size={59.40,20.40},proc=ROIVARY_FFTUnitProc,title="Unit"
	PopupMenu pmFFTUnitRV,mode=1,popvalue="THz",value= #"\"THz;cm^-1;meV;\""
	PopupMenu pmFFTOutputRV,pos={360.60,564.60},size={88.20,20.40},proc=ROIVARY_FFTOutputProc,title="Output"
	PopupMenu pmFFTOutputRV,mode=2,popvalue="Power",value= #"\"Magnitude;Power;Real;Imag;\""
	CheckBox cbFFTPeak,pos={24.00,594.60},size={64.20,18.00},title="Peak Find"
	CheckBox cbFFTPeak,variable= root:ARPES_LJZ:ROIVARY:FFTPeakFind_RV
	SetVariable svFFTPeakF0,pos={120.00,594.60},size={90.00,19.80},title="Peak f0"
	SetVariable svFFTPeakF0,limits={0,inf,0.1},value= root:ARPES_LJZ:ROIVARY:FFTPeakF0_RV
	SetVariable svFFTPeakF1,pos={222.00,594.60},size={90.00,19.80},title="Peak f1"
	SetVariable svFFTPeakF1,limits={0,inf,0.1},value= root:ARPES_LJZ:ROIVARY:FFTPeakF1_RV
	Button btnFFTPrev,pos={387.00,594.00},size={114.60,24.60},proc=ROIVARY_FFTPreviewButton,title="Preview FFT"
	Button btnFFTRun,pos={516.00,594.00},size={114.60,24.60},proc=ROIVARY_FFT_RunButton,title="Run FFT"
     Button btnFFTWB,pos={387.00,624.00},size={243.60,22.80},proc=ROIVARY_OpenFFTWorkbench,title="FFT Workbench"
EndMacro
//============================================================
// 12.5) Post-process helpers: remember trace / labels
//============================================================
Function ROIVARY_RememberLastTrace(tracePathStr)
    String tracePathStr

    SVAR/Z LastTracePath_RV = root:ARPES_LJZ:ROIVARY:LastTracePath_RV
    if (!SVAR_Exists(LastTracePath_RV))
        String/G root:ARPES_LJZ:ROIVARY:LastTracePath_RV = ""
        SVAR LastTracePath_RV = root:ARPES_LJZ:ROIVARY:LastTracePath_RV
    endif

    LastTracePath_RV = tracePathStr
    return 0
End

Function/S ROIVARY_LabelFromUzMode(uzMode)
    Variable uzMode

    if (uzMode == 0)
        return "delay time (ps)"
    elseif (uzMode == 1)
        return "Temperature (K)"
    else
        return "Fluence (mW)"
    endif
End

Function ROIVARY_CheckDelayModeForFFT()
    NVAR uzm = root:ARPES_LJZ:ROIVARY:ROI_Uz_RV
    if (uzm != 1)
        DoAlert 0, "Current Uz is not delay(ps). FFT frequency axis is only physically meaningful when the x-axis is time in ps."
        return -1
    endif
    return 0
End



//============================================================
// 16) ROI current trace helpers
//============================================================
Function/S roivary_get_current_code_from_state()
    NVAR shp = root:ARPES_LJZ:ROIVARY:ROI_shape_RV
    NVAR i1 = root:ARPES_LJZ:ROIVARY:ROI_ix1_RV, j1 = root:ARPES_LJZ:ROIVARY:ROI_iy1_RV
    NVAR i2 = root:ARPES_LJZ:ROIVARY:ROI_ix2_RV, j2 = root:ARPES_LJZ:ROIVARY:ROI_iy2_RV
    NVAR i3 = root:ARPES_LJZ:ROIVARY:ROI_ix3_RV, j3 = root:ARPES_LJZ:ROIVARY:ROI_iy3_RV
    NVAR i4 = root:ARPES_LJZ:ROIVARY:ROI_ix4_RV, j4 = root:ARPES_LJZ:ROIVARY:ROI_iy4_RV
    NVAR i5 = root:ARPES_LJZ:ROIVARY:ROI_ix5_RV, j5 = root:ARPES_LJZ:ROIVARY:ROI_iy5_RV

    if (shp == 1)
        return TriangleHash36(i1,j1,i2,j2,i3,j3, nChars=6)
    elseif (shp == 2)
        return QuadHash36(i1,j1,i2,j2,i3,j3,i4,j4, nChars=6)
    else
        return PentHash36(i1,j1,i2,j2,i3,j3,i4,j4,i5,j5, nChars=6)
    endif
End

Function/S roivary_get_current_trace_path()
    SVAR/Z LastTracePath_RV = root:ARPES_LJZ:ROIVARY:LastTracePath_RV
    if (SVAR_Exists(LastTracePath_RV))
        if (strlen(LastTracePath_RV) > 0)
            if (WaveExists($LastTracePath_RV))
                return LastTracePath_RV
            endif
        endif
    endif

    SVAR wavePath = root:ARPES_LJZ:ROIVARY:WaveSel_RV
    if (strlen(wavePath) == 0)
        return ""
    endif

    Wave/Z w = $wavePath
    if (!WaveExists(w) || WaveDims(w) != 3)
        return ""
    endif

    NVAR shp = root:ARPES_LJZ:ROIVARY:ROI_shape_RV
    String code = roivary_get_current_code_from_state()
    String baseName = NameOfWave(w)

    String dfAbs = ""
    String tracePath = ""

    if (shp == 1)
        dfAbs = "root:ARPES_LJZ:ROIVARY_OUT:" + baseName + "_TVT_" + code + ":"
        tracePath = dfAbs + baseName + "_T_" + code
    elseif (shp == 2)
        dfAbs = "root:ARPES_LJZ:ROIVARY_OUT:" + baseName + "_TVQ_" + code + ":"
        tracePath = dfAbs + baseName + "_Q_" + code
    else
        dfAbs = "root:ARPES_LJZ:ROIVARY_OUT:" + baseName + "_TVP_" + code + ":"
        tracePath = dfAbs + baseName + "_P_" + code
    endif

    if (WaveExists($tracePath))
        return tracePath
    endif

    return ""
End

Function/S roivary_get_trace_axis_label()
    NVAR uzm = root:ARPES_LJZ:ROIVARY:ROI_Uz_RV
    if (uzm == 1)
        return "delay time (ps)"
    elseif (uzm == 2)
        return "Temperature (K)"
    else
        return "Fluence (mW)"
    endif
End

//============================================================
// 17) Popup procs for BG / FFT
//============================================================
Function ROIVARY_BGModeProc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName, popStr
    Variable popNum
    NVAR BGMode_RV = root:ARPES_LJZ:ROIVARY:BGMode_RV
    BGMode_RV = popNum
    return 0
End

Function ROIVARY_FFTWindowProc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName, popStr
    Variable popNum
    NVAR FFTWindowMode_RV = root:ARPES_LJZ:ROIVARY:FFTWindowMode_RV
    FFTWindowMode_RV = popNum
    return 0
End

Function ROIVARY_FFTDetrendProc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName, popStr
    Variable popNum
    NVAR FFTDetrendMode_RV = root:ARPES_LJZ:ROIVARY:FFTDetrendMode_RV
    FFTDetrendMode_RV = popNum
    return 0
End

Function ROIVARY_FFTZeroPadProc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName, popStr
    Variable popNum
    NVAR FFTZeroPadMode_RV = root:ARPES_LJZ:ROIVARY:FFTZeroPadMode_RV
    FFTZeroPadMode_RV = popNum
    return 0
End

Function ROIVARY_FFTUnitProc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName, popStr
    Variable popNum
    NVAR FFTFreqUnitMode_RV = root:ARPES_LJZ:ROIVARY:FFTFreqUnitMode_RV
    FFTFreqUnitMode_RV = popNum
    return 0
End

Function ROIVARY_FFTOutputProc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName, popStr
    Variable popNum
    NVAR FFTOutputMode_RV = root:ARPES_LJZ:ROIVARY:FFTOutputMode_RV
    FFTOutputMode_RV = popNum
    return 0
End

//============================================================
// 18) Labels / mode text
//============================================================
Function/S roivary_bg_mode_label(mode)
    Variable mode
    if (mode == 1)
        return "DoubleExp"
    else
        return "Polynomial"
    endif
End

Function/S roivary_fft_window_label(mode)
    Variable mode
    if (mode == 1)
        return "None"
    elseif (mode == 2)
        return "Hann"
    elseif (mode == 3)
        return "Hamming"
    else
        return "Blackman"
    endif
End

Function/S roivary_fft_detrend_label(mode)
    Variable mode
    if (mode == 1)
        return "None"
    elseif (mode == 2)
        return "Mean"
    else
        return "Mean+Linear"
    endif
End

Function/S roivary_fft_pad_label(mode)
    Variable mode
    if (mode == 1)
        return "None"
    elseif (mode == 2)
        return "NextPow2"
    else
        return "Factor"
    endif
End

Function/S roivary_fft_unit_label(mode)
    Variable mode
    if (mode == 1)
        return "THz"
    elseif (mode == 2)
        return "cm\\S-1\\M"
    else
        return "meV"
    endif
End

Function/S roivary_fft_axis_label(mode)
    Variable mode
    if (mode == 1)
        return "Frequency (THz)"
    elseif (mode == 2)
        return "Frequency (cm\\S-1\\M)"
    else
        return "Frequency (meV)"
    endif
End

Function/S roivary_fft_output_label(mode)
    Variable mode
    if (mode == 1)
        return "|FFT|"
    elseif (mode == 2)
        return "|FFT|\\S2\\M"
    elseif (mode == 3)
        return "Re(FFT)"
    else
        return "Im(FFT)"
    endif
End

Function roivary_fft_unit_factor(mode)
    Variable mode
    if (mode == 1)
        return 1
    elseif (mode == 2)
        return 33.35641
    else
        return 4.135667696
    endif
End

//============================================================
// 19) Background fit model functions
//============================================================
Function roivary_eval_doubleexp(cw, xx)
    Wave cw
    Variable xx

    NVAR xRef = root:ARPES_LJZ:ROIVARY:FitXRef_RV

    Variable xr = xx - xRef
    if (xr < 0)
        xr = 0
    endif

    Variable tau1 = abs(cw[2])
    Variable tau2 = abs(cw[4])

    if (tau1 < 1e-9)
        tau1 = 1e-9
    endif
    if (tau2 < 1e-9)
        tau2 = 1e-9
    endif

    return cw[0] + cw[1]*exp(-xr/tau1) + cw[3]*exp(-xr/tau2)
End

Function roivary_fit_doubleexp(cw, x) : FitFunc
    Wave cw
    Variable x
    return roivary_eval_doubleexp(cw, x)
End

Function roivary_eval_poly1(cw, xx)
    Wave cw
    Variable xx
    NVAR xRef = root:ARPES_LJZ:ROIVARY:FitXRef_RV
    Variable xr = xx - xRef
    return cw[0] + cw[1]*xr
End

Function roivary_fit_poly1(cw, x) : FitFunc
    Wave cw
    Variable x
    return roivary_eval_poly1(cw, x)
End

Function roivary_eval_poly2(cw, xx)
    Wave cw
    Variable xx
    NVAR xRef = root:ARPES_LJZ:ROIVARY:FitXRef_RV
    Variable xr = xx - xRef
    return cw[0] + cw[1]*xr + cw[2]*xr^2
End

Function roivary_fit_poly2(cw, x) : FitFunc
    Wave cw
    Variable x
    return roivary_eval_poly2(cw, x)
End

Function roivary_eval_poly3(cw, xx)
    Wave cw
    Variable xx
    NVAR xRef = root:ARPES_LJZ:ROIVARY:FitXRef_RV
    Variable xr = xx - xRef
    return cw[0] + cw[1]*xr + cw[2]*xr^2 + cw[3]*xr^3
End

Function roivary_fit_poly3(cw, x) : FitFunc
    Wave cw
    Variable x
    return roivary_eval_poly3(cw, x)
End

Function roivary_eval_poly4(cw, xx)
    Wave cw
    Variable xx
    NVAR xRef = root:ARPES_LJZ:ROIVARY:FitXRef_RV
    Variable xr = xx - xRef
    return cw[0] + cw[1]*xr + cw[2]*xr^2 + cw[3]*xr^3 + cw[4]*xr^4
End

Function roivary_fit_poly4(cw, x) : FitFunc
    Wave cw
    Variable x
    return roivary_eval_poly4(cw, x)
End

//============================================================
// 20) BG / residual core
//============================================================
Function roivary_make_bg_and_residual_from_current(showPlots)
    Variable showPlots

    String tracePath = roivary_get_current_trace_path()
    if (strlen(tracePath) == 0)
        DoAlert 0, "No active ROI trace found. Please run ROI Trace first."
        return -1
    endif

    Wave/Z wIn = $tracePath
    if (!WaveExists(wIn) || WaveDims(wIn) != 1)
        DoAlert 0, "Active ROI trace is invalid."
        return -1
    endif

    NVAR BGMode_RV = root:ARPES_LJZ:ROIVARY:BGMode_RV
    NVAR BGPolyOrder_RV = root:ARPES_LJZ:ROIVARY:BGPolyOrder_RV
    NVAR BGFitX0_RV = root:ARPES_LJZ:ROIVARY:BGFitX0_RV
    NVAR BGFitX1_RV = root:ARPES_LJZ:ROIVARY:BGFitX1_RV
    NVAR FitXRef_RV = root:ARPES_LJZ:ROIVARY:FitXRef_RV

    Variable xLoData = min(LeftX(wIn), RightX(wIn))
    Variable xHiData = max(LeftX(wIn), RightX(wIn))
    Variable fitLo = min(BGFitX0_RV, BGFitX1_RV)
    Variable fitHi = max(BGFitX0_RV, BGFitX1_RV)

    fitLo = max(fitLo, xLoData)
    fitHi = min(fitHi, xHiData)

    if (fitHi <= fitLo)
        DoAlert 0, "Background fit range is invalid."
        return -1
    endif

    String outDF = GetWavesDataFolder(wIn, 1)
    String df0 = GetDataFolder(1)
    SetDataFolder $outDF

    String baseName = NameOfWave(wIn)

    String fitYName = baseName + "_fitYTmp_RV"
    String fitXName = baseName + "_fitXTmp_RV"

    Duplicate/O/R=(fitLo, fitHi) wIn, $fitYName
    Wave fitY = $fitYName

    Variable nFit = DimSize(fitY, 0)
    if (nFit < 5)
        KillWaves/Z $fitYName, $fitXName
        SetDataFolder df0
        DoAlert 0, "Too few points in fit range."
        return -1
    endif

    Duplicate/O fitY, $fitXName
    Wave fitX = $fitXName
    fitX = x

    FitXRef_RV = fitLo

    String coefName = baseName + "_bgCoef"
    Variable xSpan = fitHi - fitLo
    Variable dx = abs(DimDelta(wIn, 0))
    if (dx <= 0)
        dx = 1
    endif

    if (BGMode_RV == 1)
        Make/O/D/N=5 $coefName
        Wave coefW = $coefName

        coefW[0] = fitY[nFit-1]
        coefW[1] = fitY[0] - fitY[nFit-1]
        coefW[2] = max(0.15*xSpan, dx)
        coefW[3] = 0.4*(fitY[0] - fitY[nFit-1])
        coefW[4] = max(0.70*xSpan, 3*dx)

        FuncFit/Q roivary_fit_doubleexp coefW fitY /X=fitX /D

    else
        Variable ord = round(BGPolyOrder_RV)
        ord = max(1, min(4, ord))
        BGPolyOrder_RV = ord

        Make/O/D/N=(ord+1) $coefName
        Wave coefW = $coefName
        coefW = 0

        WaveStats/Q fitY
        coefW[0] = V_avg

        if (ord == 1)
            FuncFit/Q roivary_fit_poly1 coefW fitY /X=fitX /D
        elseif (ord == 2)
            FuncFit/Q roivary_fit_poly2 coefW fitY /X=fitX /D
        elseif (ord == 3)
            FuncFit/Q roivary_fit_poly3 coefW fitY /X=fitX /D
        else
            FuncFit/Q roivary_fit_poly4 coefW fitY /X=fitX /D
        endif
    endif

    String bgName = baseName + "_bg"
    String resName = baseName + "_res"

    Duplicate/O wIn, $bgName
    Duplicate/O wIn, $resName
    Wave wBg = $bgName
    Wave wRes = $resName

    if (BGMode_RV == 1)
        wBg = roivary_eval_doubleexp(coefW, x)
    else
        Variable ord2 = round(BGPolyOrder_RV)
        ord2 = max(1, min(4, ord2))
        if (ord2 == 1)
            wBg = roivary_eval_poly1(coefW, x)
        elseif (ord2 == 2)
            wBg = roivary_eval_poly2(coefW, x)
        elseif (ord2 == 3)
            wBg = roivary_eval_poly3(coefW, x)
        else
            wBg = roivary_eval_poly4(coefW, x)
        endif
    endif

    wRes = wIn - wBg

    Note/K wBg
    Note/K wRes

    String noteBG = ""
    noteBG += "ROIVARY background\r"
    noteBG += "source=" + tracePath + "\r"
    noteBG += "mode=" + roivary_bg_mode_label(BGMode_RV) + "\r"
    noteBG += "fitRange=" + num2str(fitLo) + "," + num2str(fitHi) + "\r"
    if (BGMode_RV == 2)
        noteBG += "polyOrder=" + num2str(BGPolyOrder_RV) + "\r"
    endif
    Note wBg, noteBG

    String noteRes = ""
    noteRes += "ROIVARY residual\r"
    noteRes += "source=" + tracePath + "\r"
    noteRes += "bgWave=" + outDF + bgName + "\r"
    noteRes += "mode=" + roivary_bg_mode_label(BGMode_RV) + "\r"
    noteRes += "fitRange=" + num2str(fitLo) + "," + num2str(fitHi) + "\r"
    if (BGMode_RV == 2)
        noteRes += "polyOrder=" + num2str(BGPolyOrder_RV) + "\r"
    endif
    Note wRes, noteRes

    SVAR LastResidualPath_RV = root:ARPES_LJZ:ROIVARY:LastResidualPath_RV
    LastResidualPath_RV = outDF + resName

    if (showPlots)
String winBG = roivary_make_plot_win_name("BG")
String winRes = roivary_make_plot_win_name("Res")
        DoWindow/K $winBG
        Display/N=$winBG wIn
        AppendToGraph/W=$winBG wBg
        ModifyGraph/W=$winBG rgb($NameOfWave(wIn))=(0,0,0)
        ModifyGraph/W=$winBG rgb($NameOfWave(wBg))=(65535,0,0)
        Label/W=$winBG left "Integral of ROI (a.u.)"
        Label/W=$winBG bottom roivary_get_trace_axis_label()

        DoWindow/K $winRes
        Display/N=$winRes wRes
        ModifyGraph/W=$winRes rgb($NameOfWave(wRes))=(0,0,65535)
        Label/W=$winRes left "Residual (a.u.)"
        Label/W=$winRes bottom roivary_get_trace_axis_label()
    endif

    KillWaves/Z $fitYName, $fitXName
    SetDataFolder df0

    return 0
End

Function ROIVARY_BG_RunButton(ctrlName) : ButtonControl
    String ctrlName
    roivary_make_bg_and_residual_from_current(1)
    return 0
End

//============================================================
// 21) FFT preprocess helpers
//============================================================
Function roivary_next_pow2_int(nIn)
    Variable nIn
    Variable n = max(1, round(nIn))
    Variable p = 1
    do
        if (p >= n)
            break
        endif
        p *= 2
    while (1)
    return p
End

Function roivary_window_weight(mode, idx, nPts)
    Variable mode, idx, nPts

    if (nPts <= 1)
        return 1
    endif

    Variable a = 2*pi*idx/(nPts-1)

    if (mode == 1)
        return 1
    elseif (mode == 2)
        return 0.5*(1 - cos(a))
    elseif (mode == 3)
        return 0.54 - 0.46*cos(a)
    else
        return 0.42 - 0.5*cos(a) + 0.08*cos(2*a)
    endif
End

Function roivary_remove_mean_inplace(w)
    Wave w
    WaveStats/Q w
    Variable avg = V_avg
    w = w[p] - avg
    return 0
End

Function roivary_remove_linear_trend_inplace(w)
    Wave w

    Variable n = DimSize(w,0)
    if (n < 2)
        return -1
    endif

    Variable sx=0, sy=0, sxx=0, sxy=0
    Variable i, xi, yi

    for (i=0; i<n; i+=1)
        xi = pnt2x(w, i)
        yi = w[i]
        sx += xi
        sy += yi
        sxx += xi*xi
        sxy += xi*yi
    endfor

    Variable den = n*sxx - sx*sx
    if (abs(den) < 1e-20)
        return -1
    endif

    Variable slope = (n*sxy - sx*sy)/den
    Variable intercept = (sy - slope*sx)/n

    for (i=0; i<n; i+=1)
        xi = pnt2x(w, i)
        w[i] = w[i] - (intercept + slope*xi)
    endfor

    return 0
End

Function roivary_has_nan_or_inf(w)
    Wave w
    Variable n = DimSize(w,0)
    Variable i
    for (i=0; i<n; i+=1)
        if (numtype(w[i]) != 0)
            return 1
        endif
    endfor
    return 0
End

//============================================================
// 22) FFT peak find helper
//============================================================
Function roivary_find_peak_in_wave(w, x0, x1, peakX, peakY)
    Wave w
    Variable x0, x1
    Variable &peakX, &peakY

    Variable n = DimSize(w,0)
    if (n <= 0)
        return -1
    endif

    Variable lo = min(x0, x1)
    Variable hi = max(x0, x1)

    Variable axisLo = min(LeftX(w), RightX(w))
    Variable axisHi = max(LeftX(w), RightX(w))

    lo = max(lo, axisLo)
    hi = min(hi, axisHi)

    if (hi <= lo)
        return -1
    endif

    Variable i0 = round(x2pnt(w, lo))
    Variable i1 = round(x2pnt(w, hi))

    i0 = max(0, min(n-1, i0))
    i1 = max(0, min(n-1, i1))

    if (i1 < i0)
        Variable it = i0
        i0 = i1
        i1 = it
    endif

    Variable i
    Variable bestAbs = -1
    Variable bestIdx = -1
    for (i=i0; i<=i1; i+=1)
        if (numtype(w[i]) == 0)
            if (abs(w[i]) > bestAbs)
                bestAbs = abs(w[i])
                bestIdx = i
            endif
        endif
    endfor

    if (bestIdx < 0)
        return -1
    endif

    peakX = pnt2x(w, bestIdx)
    peakY = w[bestIdx]
    return 0
End

//============================================================
// 23) FFT preview
//============================================================
Function ROIVARY_FFTPreviewButton(ctrlName) : ButtonControl
    String ctrlName

    NVAR uzm = root:ARPES_LJZ:ROIVARY:ROI_Uz_RV
    if (uzm != 1)
        DoAlert 0, "FFT preview is intended for delay(ps) traces only."
        return 0
    endif

    Variable rc = roivary_make_bg_and_residual_from_current(0)
    if (rc != 0)
        return 0
    endif

    SVAR LastResidualPath_RV = root:ARPES_LJZ:ROIVARY:LastResidualPath_RV
    if (strlen(LastResidualPath_RV) == 0)
        DoAlert 0, "Residual was not generated."
        return 0
    endif

    Wave/Z wRes = $LastResidualPath_RV
    if (!WaveExists(wRes))
        DoAlert 0, "Residual wave not found."
        return 0
    endif

    NVAR FFTX0_RV = root:ARPES_LJZ:ROIVARY:FFTX0_RV
    NVAR FFTX1_RV = root:ARPES_LJZ:ROIVARY:FFTX1_RV

    String outDF = GetWavesDataFolder(wRes, 1)
    String markName = NameOfWave(wRes) + "_fftMark"
    Duplicate/O wRes, $(outDF + markName)
    Wave wMark = $(outDF + markName)

    Variable xLo = min(FFTX0_RV, FFTX1_RV)
    Variable xHi = max(FFTX0_RV, FFTX1_RV)
    Variable i, n = DimSize(wMark,0), xx
    for (i=0; i<n; i+=1)
        xx = pnt2x(wMark, i)
        if (xx < xLo || xx > xHi)
            wMark[i] = NaN
        endif
    endfor

    String winName = roivary_make_plot_win_name("FFTPrev")
    DoWindow/K $winName
    Display/N=$winName wRes
    AppendToGraph/W=$winName wMark
    ModifyGraph/W=$winName rgb($NameOfWave(wRes))=(0,0,0)
    ModifyGraph/W=$winName rgb($NameOfWave(wMark))=(65535,0,0)
    ModifyGraph/W=$winName lsize($NameOfWave(wMark))=2
    Label/W=$winName left "Residual (a.u.)"
    Label/W=$winName bottom "delay time (ps)"

    return 0
End

Function roivary_run_fft_from_current(showPlot)
    Variable showPlot

    NVAR uzm = root:ARPES_LJZ:ROIVARY:ROI_Uz_RV
    if (uzm != 1)
        DoAlert 0, "FFT is enabled only when Uz = delay(ps)."
        return -1
    endif

    Variable rc0 = roivary_make_bg_and_residual_from_current(0)
    if (rc0 != 0)
        return -1
    endif

    SVAR LastResidualPath_RV = root:ARPES_LJZ:ROIVARY:LastResidualPath_RV
    if (strlen(LastResidualPath_RV) == 0)
        DoAlert 0, "Residual wave missing."
        return -1
    endif

    Wave/Z wRes = $LastResidualPath_RV
    if (!WaveExists(wRes) || WaveDims(wRes) != 1)
        DoAlert 0, "Residual wave invalid."
        return -1
    endif

    NVAR FFTX0_RV = root:ARPES_LJZ:ROIVARY:FFTX0_RV
    NVAR FFTX1_RV = root:ARPES_LJZ:ROIVARY:FFTX1_RV
    NVAR FFTWindowMode_RV = root:ARPES_LJZ:ROIVARY:FFTWindowMode_RV
    NVAR FFTDetrendMode_RV = root:ARPES_LJZ:ROIVARY:FFTDetrendMode_RV
    NVAR FFTZeroPadMode_RV = root:ARPES_LJZ:ROIVARY:FFTZeroPadMode_RV
    NVAR FFTZeroPadFactor_RV = root:ARPES_LJZ:ROIVARY:FFTZeroPadFactor_RV
    NVAR FFTFreqUnitMode_RV = root:ARPES_LJZ:ROIVARY:FFTFreqUnitMode_RV
    NVAR FFTOutputMode_RV = root:ARPES_LJZ:ROIVARY:FFTOutputMode_RV
    NVAR FFTPeakFind_RV = root:ARPES_LJZ:ROIVARY:FFTPeakFind_RV
    NVAR FFTPeakF0_RV = root:ARPES_LJZ:ROIVARY:FFTPeakF0_RV
    NVAR FFTPeakF1_RV = root:ARPES_LJZ:ROIVARY:FFTPeakF1_RV

    Variable xLoData = min(LeftX(wRes), RightX(wRes))
    Variable xHiData = max(LeftX(wRes), RightX(wRes))
    Variable xLo = min(FFTX0_RV, FFTX1_RV)
    Variable xHi = max(FFTX0_RV, FFTX1_RV)

    xLo = max(xLo, xLoData)
    xHi = min(xHi, xHiData)

    if (xHi <= xLo)
        DoAlert 0, "FFT range is invalid."
        return -1
    endif

    String outDF = GetWavesDataFolder(wRes, 1)
    String df0 = GetDataFolder(1)
    SetDataFolder $outDF

    String fftBase = roivary_sanitize_name(roivary_get_fft_output_base_name())

    String segName  = NameOfWave(wRes) + "_fftSeg"
    String procName = NameOfWave(wRes) + "_fftProc"
    String padName  = NameOfWave(wRes) + "_fftPad"
    String cName    = NameOfWave(wRes) + "_fftC"

    Duplicate/O/R=(xLo, xHi) wRes, $segName
    Wave wSeg = $segName

    Variable nSeg = DimSize(wSeg,0)
    if (nSeg < 8)
        KillWaves/Z $segName, $procName, $padName, $cName
        SetDataFolder df0
        DoAlert 0, "FFT segment has too few points."
        return -1
    endif

    Duplicate/O wSeg, $procName
    Wave wProc = $procName

    if (roivary_has_nan_or_inf(wProc))
        KillWaves/Z $segName, $procName, $padName, $cName
        SetDataFolder df0
        DoAlert 0, "Residual segment contains NaN/Inf."
        return -1
    endif

    Variable dt = abs(DimDelta(wProc,0))
    if (dt <= 0)
        KillWaves/Z $segName, $procName, $padName, $cName
        SetDataFolder df0
        DoAlert 0, "FFT requires uniformly scaled x-axis with positive spacing."
        return -1
    endif

    if (FFTDetrendMode_RV == 2)
        roivary_remove_mean_inplace(wProc)
    elseif (FFTDetrendMode_RV == 3)
        roivary_remove_mean_inplace(wProc)
        roivary_remove_linear_trend_inplace(wProc)
    endif

    Variable i
    Variable wMean = 0
    for (i=0; i<nSeg; i+=1)
        wMean += roivary_window_weight(FFTWindowMode_RV, i, nSeg)
    endfor
    wMean /= nSeg
    if (wMean <= 0)
        wMean = 1
    endif

    for (i=0; i<nSeg; i+=1)
        wProc[i] *= roivary_window_weight(FFTWindowMode_RV, i, nSeg)
    endfor

    Variable nFFT
    Variable padFac
    if (FFTZeroPadMode_RV == 1)
        nFFT = nSeg
    elseif (FFTZeroPadMode_RV == 2)
        nFFT = roivary_next_pow2_int(nSeg)
    else
        padFac = max(1, round(FFTZeroPadFactor_RV))
        nFFT = max(nSeg, nSeg*padFac)
    endif

    Make/O/D/N=(nFFT) $padName
    Wave wPad = $padName
    wPad = 0
    wPad[0, nSeg-1] = wProc[p]

    Make/O/C/N=(nFFT) $cName
    Wave/C wC = $cName
    FFT/DEST=wC wPad

    Variable nHalf = floor(nFFT/2)
    Variable convF = roivary_fft_unit_factor(FFTFreqUnitMode_RV)
    Variable dfTHz = 1/(nFFT*dt)
    Variable dfOut = dfTHz*convF

    String reName  = fftBase + "_fftRe"
    String imName  = fftBase + "_fftIm"
    String magName = fftBase + "_fftMag"
    String powName = fftBase + "_fftPow"

    Make/O/D/N=(nHalf+1) $reName
    Make/O/D/N=(nHalf+1) $imName
    Make/O/D/N=(nHalf+1) $magName
    Make/O/D/N=(nHalf+1) $powName

    Wave wRe  = $reName
    Wave wIm  = $imName
    Wave wMag = $magName
    Wave wPow = $powName

    SetScale/P x, 0, dfOut, roivary_fft_unit_label(FFTFreqUnitMode_RV), wRe
    SetScale/P x, 0, dfOut, roivary_fft_unit_label(FFTFreqUnitMode_RV), wIm
    SetScale/P x, 0, dfOut, roivary_fft_unit_label(FFTFreqUnitMode_RV), wMag
    SetScale/P x, 0, dfOut, roivary_fft_unit_label(FFTFreqUnitMode_RV), wPow

    Variable k
    Variable ampScale
    Variable rawRe, rawIm

    for (k=0; k<=nHalf; k+=1)
        rawRe = real(wC[k])
        rawIm = imag(wC[k])

        ampScale = 1/max(nSeg, 1)
        if (k > 0)
            if (!(mod(nFFT,2)==0 && k==nHalf))
                ampScale *= 2
            endif
        endif
        ampScale /= wMean

        wRe[k]  = rawRe*ampScale
        wIm[k]  = rawIm*ampScale
        wMag[k] = sqrt(wRe[k]^2 + wIm[k]^2)
        wPow[k] = wMag[k]^2
    endfor

    Note/K wRe
    Note/K wIm
    Note/K wMag
    Note/K wPow

    String fftNote = ""
    fftNote += "ROIVARY FFT\r"
    fftNote += "sourceResidual=" + LastResidualPath_RV + "\r"
    fftNote += "fftRange=" + num2str(xLo) + "," + num2str(xHi) + "\r"
    fftNote += "window=" + roivary_fft_window_label(FFTWindowMode_RV) + "\r"
    fftNote += "detrend=" + roivary_fft_detrend_label(FFTDetrendMode_RV) + "\r"
    fftNote += "padMode=" + roivary_fft_pad_label(FFTZeroPadMode_RV) + "\r"
    fftNote += "padN=" + num2str(nFFT) + "\r"
    fftNote += "freqUnit=" + roivary_fft_unit_label(FFTFreqUnitMode_RV) + "\r"

    Note wRe,  fftNote + "output=Re\r"
    Note wIm,  fftNote + "output=Im\r"
    Note wMag, fftNote + "output=Mag\r"
    Note wPow, fftNote + "output=Power\r"

    String dispName = ""
    if (FFTOutputMode_RV == 1)
        dispName = NameOfWave(wMag)
    elseif (FFTOutputMode_RV == 2)
        dispName = NameOfWave(wPow)
    elseif (FFTOutputMode_RV == 3)
        dispName = NameOfWave(wRe)
    else
        dispName = NameOfWave(wIm)
    endif

    Wave/Z wDisp = $dispName
    if (!WaveExists(wDisp))
        KillWaves/Z $segName, $procName, $padName, $cName
        SetDataFolder df0
        DoAlert 0, "FFT display wave is missing."
        return -1
    endif

    ROIVARY_FFTWB_SaveCurrentFFT(wDisp, LastResidualPath_RV)

    if (FFTPeakFind_RV)
        Variable peakX, peakY
        Variable okPeak = roivary_find_peak_in_wave(wDisp, FFTPeakF0_RV, FFTPeakF1_RV, peakX, peakY)

        String peakFreqName = NameOfWave(wDisp) + "_peakFreq"
        String peakAmpName  = NameOfWave(wDisp) + "_peakAmp"
        Make/O/D/N=1 $peakFreqName
        Make/O/D/N=1 $peakAmpName
        Wave wPeakFreq = $peakFreqName
        Wave wPeakAmp  = $peakAmpName

        if (okPeak == 0)
            wPeakFreq[0] = peakX
            wPeakAmp[0]  = peakY
            Printf "ROIVARY FFT peak: f=%.6g %s, amp=%.6g\r", peakX, roivary_fft_unit_label(FFTFreqUnitMode_RV), peakY
        else
            wPeakFreq[0] = NaN
            wPeakAmp[0]  = NaN
        endif
    endif

    if (showPlot)
        String winFFT = fftBase + "_FFT"
        DoWindow/K $winFFT
        Display/N=$winFFT wDisp
        ModifyGraph/W=$winFFT rgb($NameOfWave(wDisp))=(0,0,0)
        Label/W=$winFFT left roivary_fft_output_label(FFTOutputMode_RV)
        Label/W=$winFFT bottom roivary_fft_axis_label(FFTFreqUnitMode_RV)

        if (FFTPeakFind_RV)
            Wave/Z wPeakFreq2 = $(NameOfWave(wDisp) + "_peakFreq")
            Wave/Z wPeakAmp2  = $(NameOfWave(wDisp) + "_peakAmp")
            if (WaveExists(wPeakFreq2) && WaveExists(wPeakAmp2))
                String pXName = NameOfWave(wDisp) + "_peakXW"
                String pYName = NameOfWave(wDisp) + "_peakYW"
                Make/O/D/N=1 $pXName
                Make/O/D/N=1 $pYName
                Wave wPX = $pXName
                Wave wPY = $pYName
                wPX[0] = wPeakFreq2[0]
                wPY[0] = wPeakAmp2[0]
                if (numtype(wPX[0]) == 0 && numtype(wPY[0]) == 0)
                    AppendToGraph/W=$winFFT wPY vs wPX
                    ModifyGraph/W=$winFFT mode($NameOfWave(wPY))=3
                    ModifyGraph/W=$winFFT marker($NameOfWave(wPY))=19
                    ModifyGraph/W=$winFFT msize($NameOfWave(wPY))=3
                    ModifyGraph/W=$winFFT rgb($NameOfWave(wPY))=(65535,0,0)
                endif
            endif
        endif
    endif

    KillWaves/Z $segName, $procName, $padName, $cName
    SetDataFolder df0

    return 0
End

Function ROIVARY_FFT_RunButton(ctrlName) : ButtonControl
    String ctrlName
    roivary_run_fft_from_current(1)
    return 0
End

Function/S roivary_sanitize_name(inStr)
    String inStr

    String s = inStr
    s = ReplaceString(" ", s, "_")
    s = ReplaceString(":", s, "_")
    s = ReplaceString(";", s, "_")
    s = ReplaceString("/", s, "_")
    s = ReplaceString("\\", s, "_")
    s = ReplaceString(".", s, "_")
    s = ReplaceString(",", s, "_")
    s = ReplaceString("(", s, "_")
    s = ReplaceString(")", s, "_")
    s = ReplaceString("[", s, "_")
    s = ReplaceString("]", s, "_")
    s = ReplaceString("{", s, "_")
    s = ReplaceString("}", s, "_")
    s = ReplaceString("-", s, "_")
    s = ReplaceString("+", s, "_")
    s = ReplaceString("=", s, "_")

    do
        if (StringMatch(s, "*__*") == 0)
            break
        endif
        s = ReplaceString("__", s, "_")
    while (1)

    if (strlen(s) == 0)
        s = "ROIVARY"
    endif

    return s
End


Function roivary_filter_match(itemPath, filt)
    String itemPath, filt

    String f = filt
    if (strlen(f) == 0)
        return 1
    endif

    String itemL = LowerStr(itemPath)
    String tailL = LowerStr(roivary_wave_tail_from_path(itemPath))
    String filtL = LowerStr(f)

    if (strsearch(itemL, filtL, 0) >= 0)
        return 1
    endif
    if (strsearch(tailL, filtL, 0) >= 0)
        return 1
    endif

    return 0
End

Function ROIVARY_SVFilterProc(ctrlName, varNum, varStr, varName) : SetVariableControl
    String ctrlName
    Variable varNum
    String varStr, varName

    SVAR WaveFilter_RV = root:ARPES_LJZ:ROIVARY:WaveFilter_RV
    WaveFilter_RV = varStr
    roivary_rebuild_lb()
    return 0
End

Function ROIVARY_ClearFilter(ctrlName) : ButtonControl
    String ctrlName

    SVAR WaveFilter_RV = root:ARPES_LJZ:ROIVARY:WaveFilter_RV
    WaveFilter_RV = ""

    DoWindow ROIVARY_LJZ_P
    if (V_flag)
        ControlUpdate/W=ROIVARY_LJZ_P rv_sv_filter
    endif

    roivary_rebuild_lb()
    return 0
End

//============================================================
// 25) FFT Workbench : folder / init
//============================================================
Function roivary_fftwb_ensure_folder()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:ROIVARY
    NewDataFolder/O root:ARPES_LJZ:ROIVARY:FFTWB
    NewDataFolder/O root:ARPES_LJZ:ROIVARY:FFTWB:OUT
    NewDataFolder/O root:ARPES_LJZ:ROIVARY:FFTWB:TMP
End

Function roivary_fftwb_init_if_needed()
    roivary_fftwb_ensure_folder()

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:ROIVARY

    if (!WaveExists($"FFTWB_Items_RV"))
        Make/O/T/N=0 FFTWB_Items_RV
    endif
    if (!WaveExists($"FFTWB_Paths_RV"))
        Make/O/T/N=0 FFTWB_Paths_RV
    endif
    if (!WaveExists($"FFTWB_Sel_RV"))
        Make/O/U/B/N=0 FFTWB_Sel_RV
    endif

    SVAR/Z FFTWB_Filter_RV = root:ARPES_LJZ:ROIVARY:FFTWB_Filter_RV
    if (!SVAR_Exists(FFTWB_Filter_RV))
        String/G FFTWB_Filter_RV = ""
    endif

    SVAR/Z FFTWB_EditLabel_RV = root:ARPES_LJZ:ROIVARY:FFTWB_EditLabel_RV
    if (!SVAR_Exists(FFTWB_EditLabel_RV))
        String/G FFTWB_EditLabel_RV = ""
    endif

    NVAR/Z FFTWB_EditFluence_RV = root:ARPES_LJZ:ROIVARY:FFTWB_EditFluence_RV
    if (!NVAR_Exists(FFTWB_EditFluence_RV))
        Variable/G FFTWB_EditFluence_RV = NaN
    endif

    NVAR/Z FFTWB_X0_RV = root:ARPES_LJZ:ROIVARY:FFTWB_X0_RV
    if (!NVAR_Exists(FFTWB_X0_RV))
        Variable/G FFTWB_X0_RV = 0
    endif

    NVAR/Z FFTWB_X1_RV = root:ARPES_LJZ:ROIVARY:FFTWB_X1_RV
    if (!NVAR_Exists(FFTWB_X1_RV))
        Variable/G FFTWB_X1_RV = 10
    endif

    NVAR/Z FFTWB_YStep_RV = root:ARPES_LJZ:ROIVARY:FFTWB_YStep_RV
    if (!NVAR_Exists(FFTWB_YStep_RV))
        Variable/G FFTWB_YStep_RV = 0.95
    endif

    NVAR/Z FFTWB_SortByFlu_RV = root:ARPES_LJZ:ROIVARY:FFTWB_SortByFlu_RV
    if (!NVAR_Exists(FFTWB_SortByFlu_RV))
        Variable/G FFTWB_SortByFlu_RV = 1
    endif
    NVAR/Z FFTWB_Normalize_RV = root:ARPES_LJZ:ROIVARY:FFTWB_Normalize_RV
    if (!NVAR_Exists(FFTWB_Normalize_RV))
        Variable/G FFTWB_Normalize_RV = 1
    endif
    
    NVAR/Z FFTWB_PeakCenter_RV = root:ARPES_LJZ:ROIVARY:FFTWB_PeakCenter_RV
    if (!NVAR_Exists(FFTWB_PeakCenter_RV))
        Variable/G FFTWB_PeakCenter_RV = 3.4
    endif

    NVAR/Z FFTWB_PeakHalfWidth_RV = root:ARPES_LJZ:ROIVARY:FFTWB_PeakHalfWidth_RV
    if (!NVAR_Exists(FFTWB_PeakHalfWidth_RV))
        Variable/G FFTWB_PeakHalfWidth_RV = 0.6
    endif

    NVAR/Z FFTWB_PeakSmoothN_RV = root:ARPES_LJZ:ROIVARY:FFTWB_PeakSmoothN_RV
    if (!NVAR_Exists(FFTWB_PeakSmoothN_RV))
        Variable/G FFTWB_PeakSmoothN_RV = 5
    endif
    
SVAR/Z FFTPlotBaseName_RV = root:ARPES_LJZ:ROIVARY:FFTPlotBaseName_RV
if (!SVAR_Exists(FFTPlotBaseName_RV))
    String/G root:ARPES_LJZ:ROIVARY:FFTPlotBaseName_RV = ""
endif

    SetDataFolder df0
End

//============================================================
// 26) FFT Workbench : note / parsing helpers
//============================================================
Function/S roivary_note_set_key(noteStr, key, val)
    String noteStr, key, val
    return ReplaceStringByKey(key, noteStr, val, "=", "\r")
End

Function/S roivary_note_get_key(noteStr, key)
    String noteStr, key
    return StringByKey(key, noteStr, "=", "\r")
End

Function roivary_is_digit_char(ch)
    String ch
    if (cmpstr(ch, "0") >= 0 && cmpstr(ch, "9") <= 0)
        return 1
    endif
    return 0
End

Function roivary_try_parse_fluence_from_string(inStr, outFlu)
    String inStr
    Variable &outFlu

    String s = LowerStr(inStr)
    Variable p = 0
    Variable L = strlen(s)

    do
        p = strsearch(s, "_p", p)
        if (p < 0)
            return 0
        endif

        if (p+2 >= L)
            return 0
        endif

        String tok = ""
        Variable j = p + 2
        do
            if (j >= L)
                break
            endif

            String ch = s[j,j]
            if (roivary_is_digit_char(ch) || StringMatch(ch, "d") || StringMatch(ch, "."))
                tok += ch
                j += 1
            else
                break
            endif
        while (1)

        if (strlen(tok) > 0)
            tok = ReplaceString("d", tok, ".")
            outFlu = str2num(tok)
            if (numtype(outFlu) == 0)
                return 1
            endif
        endif

        p += 2
    while (1)

    return 0
End

Function roivary_try_get_fluence_from_wavepath(wavePath, outFlu)
    String wavePath
    Variable &outFlu

    Wave/Z w = $wavePath
    if (WaveExists(w))
        String nt = note(w)
        String sVal = roivary_note_get_key(nt, "PumpFluence")
        if (strlen(sVal) == 0)
            sVal = roivary_note_get_key(nt, "Fluence")
        endif
        if (strlen(sVal) == 0)
            sVal = roivary_note_get_key(nt, "WB_Fluence")
        endif

        if (strlen(sVal) > 0)
            outFlu = str2num(sVal)
            if (numtype(outFlu) == 0)
                return 1
            endif
        endif
    endif

    return roivary_try_parse_fluence_from_string(wavePath, outFlu)
End



Function roivary_fftwb_filter_match(w, filt)
    Wave w
    String filt

    if (strlen(filt) == 0)
        return 1
    endif

    String f = LowerStr(filt)
    String nameL = LowerStr(NameOfWave(w))
    String itemL = LowerStr(roivary_fftwb_make_item_text(w))
    String ntL   = LowerStr(note(w))

    if (strsearch(nameL, f, 0) >= 0)
        return 1
    endif
    if (strsearch(itemL, f, 0) >= 0)
        return 1
    endif
    if (strsearch(ntL, f, 0) >= 0)
        return 1
    endif

    return 0
End

Function roivary_wave_max_in_range(w, x0, x1)
    Wave w
    Variable x0, x1

    Variable n = DimSize(w,0)
    if (n <= 0)
        return 1
    endif

    Variable lo = min(x0, x1)
    Variable hi = max(x0, x1)

    Variable i0 = round(x2pnt(w, lo))
    Variable i1 = round(x2pnt(w, hi))
    i0 = max(0, min(n-1, i0))
    i1 = max(0, min(n-1, i1))

    if (i1 < i0)
        Variable it = i0
        i0 = i1
        i1 = it
    endif

    Variable i, vmax = -1e30
    for (i=i0; i<=i1; i+=1)
        if (numtype(w[i]) == 0)
            if (w[i] > vmax)
                vmax = w[i]
            endif
        endif
    endfor

    if (numtype(vmax) != 0 || vmax <= 0)
        vmax = 1
    endif
    return vmax
End

//============================================================
// 28) FFT Workbench : rebuild list
//============================================================
Function ROIVARY_FFTWB_RebuildList()
    roivary_fftwb_init_if_needed()

    Wave/T items = root:ARPES_LJZ:ROIVARY:FFTWB_Items_RV
    Wave/T paths = root:ARPES_LJZ:ROIVARY:FFTWB_Paths_RV
    Wave/U/B sel = root:ARPES_LJZ:ROIVARY:FFTWB_Sel_RV
    SVAR filt = root:ARPES_LJZ:ROIVARY:FFTWB_Filter_RV

    Redimension/N=0 items, paths, sel

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:ROIVARY:FFTWB:OUT

    String list = WaveList("*_WBMAIN", ";", "DIMS:1")
    Variable n0 = ItemsInList(list, ";")
    Variable i, cnt = 0

    for (i=0; i<n0; i+=1)
        String wn = StringFromList(i, list, ";")
        if (strlen(wn) == 0)
            continue
        endif

        Wave/Z w = $wn
        if (!WaveExists(w))
            continue
        endif

        if (roivary_fftwb_filter_match(w, filt))
            cnt += 1
        endif
    endfor

    if (cnt > 0)
        Redimension/N=(cnt) items, paths, sel
        cnt = 0
        for (i=0; i<n0; i+=1)
            String wn2 = StringFromList(i, list, ";")
            if (strlen(wn2) == 0)
                continue
            endif

            Wave/Z w2 = $wn2
            if (!WaveExists(w2))
                continue
            endif

            if (roivary_fftwb_filter_match(w2, filt))
                items[cnt] = roivary_fftwb_make_item_text(w2)
                paths[cnt] = "root:ARPES_LJZ:ROIVARY:FFTWB:OUT:" + wn2
                sel[cnt] = 0
                cnt += 1
            endif
        endfor
    endif

    SetDataFolder df0

    DoWindow ROIVARY_FFTWB_P
    if (V_flag)
        ControlUpdate/W=ROIVARY_FFTWB_P lbFFTWB
    endif

    return 0
End

//============================================================
// 29) FFT Workbench : selection / editing
//============================================================
Function ROIVARY_FFTWB_LBProc(ctrlName, row, col, eventCode) : ListBoxControl
    String ctrlName
    Variable row, col, eventCode

    if (eventCode != 4)
        return 0
    endif

    ROIVARY_FFTWB_LoadFirstSelectedMeta()
    return 0
End

Function ROIVARY_FFTWB_FilterProc(ctrlName, varNum, varStr, varName) : SetVariableControl
    String ctrlName
    Variable varNum
    String varStr, varName

    SVAR filt = root:ARPES_LJZ:ROIVARY:FFTWB_Filter_RV
    filt = varStr
    ROIVARY_FFTWB_RebuildList()
    return 0
End

Function ROIVARY_FFTWB_ClearFilter(ctrlName) : ButtonControl
    String ctrlName
    SVAR filt = root:ARPES_LJZ:ROIVARY:FFTWB_Filter_RV
    filt = ""
    DoWindow ROIVARY_FFTWB_P
    if (V_flag)
        ControlUpdate/W=ROIVARY_FFTWB_P wb_sv_filter
    endif
    ROIVARY_FFTWB_RebuildList()
    return 0
End

Function ROIVARY_FFTWB_AutoFluence(ctrlName) : ButtonControl
    String ctrlName

    Wave/T paths = root:ARPES_LJZ:ROIVARY:FFTWB_Paths_RV
    Wave/U/B sel = root:ARPES_LJZ:ROIVARY:FFTWB_Sel_RV

    Variable i, n = DimSize(paths,0)
    for (i=0; i<n; i+=1)
        if (!sel[i])
            continue
        endif

        Wave/Z w = $paths[i]
        if (!WaveExists(w))
            continue
        endif

        String nt = note(w)
        String src = roivary_note_get_key(nt, "WB_SourceResidual")

        Variable flu = NaN
        if (!roivary_try_get_fluence_from_wavepath(src, flu))
            roivary_try_get_fluence_from_wavepath(paths[i], flu)
        endif

        nt = roivary_note_set_key(nt, "WB_Fluence", num2str(flu))
        Note/K w
        Note w, nt
    endfor

    ROIVARY_FFTWB_RebuildList()
    return 0
End

Function ROIVARY_FFTWB_ApplyMeta(ctrlName) : ButtonControl
    String ctrlName

    Wave/T paths = root:ARPES_LJZ:ROIVARY:FFTWB_Paths_RV
    Wave/U/B sel = root:ARPES_LJZ:ROIVARY:FFTWB_Sel_RV
    NVAR editFlu = root:ARPES_LJZ:ROIVARY:FFTWB_EditFluence_RV
    SVAR editLab = root:ARPES_LJZ:ROIVARY:FFTWB_EditLabel_RV

    Variable i, n = DimSize(paths,0)
    for (i=0; i<n; i+=1)
        if (!sel[i])
            continue
        endif

        Wave/Z w = $paths[i]
        if (!WaveExists(w))
            continue
        endif

        String nt = note(w)
        if (numtype(editFlu) == 0)
            nt = roivary_note_set_key(nt, "WB_Fluence", num2str(editFlu))
        endif
        if (strlen(editLab) > 0)
            nt = roivary_note_set_key(nt, "WB_Label", editLab)
        endif

        Note/K w
        Note w, nt
    endfor

    ROIVARY_FFTWB_RebuildList()
    return 0
End

Function ROIVARY_FFTWB_RemoveSelected(ctrlName) : ButtonControl
    String ctrlName

    Wave/T paths = root:ARPES_LJZ:ROIVARY:FFTWB_Paths_RV
    Wave/U/B sel = root:ARPES_LJZ:ROIVARY:FFTWB_Sel_RV

    Variable i, n = DimSize(paths,0)
    for (i=0; i<n; i+=1)
        if (!sel[i])
            continue
        endif

        Wave/Z w = $paths[i]
        if (!WaveExists(w))
            continue
        endif

        KillWaves/Z $paths[i]
    endfor

    ROIVARY_FFTWB_RebuildList()
    return 0
End

Function ROIVARY_FFTWB_ClearAll(ctrlName) : ButtonControl
    String ctrlName

    DoAlert 1, "Delete all FFT workbench waves?"
    if (V_flag != 1)
        return 0
    endif

    String df0 = GetDataFolder(1)
    SetDataFolder root:ARPES_LJZ:ROIVARY:FFTWB:OUT

    String list = WaveList("*", ";", "")
    Variable i, n = ItemsInList(list, ";")
    for (i=0; i<n; i+=1)
        String wn = StringFromList(i, list, ";")
        if (strlen(wn) == 0)
            continue
        endif
        KillWaves/Z $wn
    endfor

    SetDataFolder df0
    ROIVARY_FFTWB_RebuildList()
    return 0
End

//============================================================
// 30) FFT Workbench : plotting
//============================================================
Function ROIVARY_FFTWB_PlotStacked(ctrlName) : ButtonControl
    String ctrlName

    roivary_fftwb_init_if_needed()

    Wave/T   paths = root:ARPES_LJZ:ROIVARY:FFTWB_Paths_RV
    Wave/U/B sel   = root:ARPES_LJZ:ROIVARY:FFTWB_Sel_RV

    NVAR x0        = root:ARPES_LJZ:ROIVARY:FFTWB_X0_RV
    NVAR x1        = root:ARPES_LJZ:ROIVARY:FFTWB_X1_RV
    NVAR yStep     = root:ARPES_LJZ:ROIVARY:FFTWB_YStep_RV
    NVAR sortByFlu = root:ARPES_LJZ:ROIVARY:FFTWB_SortByFlu_RV
    NVAR doNorm    = root:ARPES_LJZ:ROIVARY:FFTWB_Normalize_RV

    String plotBase = ROIVARY_FFTWB_GetPlotBaseName()
    if (strlen(plotBase) == 0)
        DoAlert 0, "Please input FFT PlotBase first."
        return 0
    endif

    Variable i, n = DimSize(paths,0)
    Variable nSel = 0
    for (i=0; i<n; i+=1)
        if (sel[i])
            Wave/Z wTest = $paths[i]
            if (WaveExists(wTest))
                nSel += 1
            endif
        endif
    endfor

    if (nSel <= 0)
        DoAlert 0, "Please select valid FFT waves in the workbench."
        return 0
    endif
    if (!roivary_fftwb_selected_xunits_consistent())
        DoAlert 0, "Selected FFT waves do not share the same frequency unit. Please select waves with the same unit before plotting together."
        return 0
    endif

    String xUnit = roivary_fftwb_first_selected_xunit()
    Make/FREE/T/N=(nSel) pathW, labW
    Make/FREE/D/N=(nSel) fluW, ampRefW, offsetW, dispHW, sortKey

    Variable j = 0
    for (i=0; i<n; i+=1)
        if (!sel[i])
            continue
        endif

        Wave/Z wIn = $paths[i]
        if (!WaveExists(wIn))
            continue
        endif

        String nt = note(wIn)

        pathW[j] = paths[i]

        labW[j] = roivary_note_get_key(nt, "WB_Label")
        if (strlen(labW[j]) == 0)
            labW[j] = NameOfWave(wIn)
        endif

        fluW[j] = str2num(roivary_note_get_key(nt, "WB_Fluence"))

        ampRefW[j] = roivary_wave_max_in_range(wIn, x0, x1)
        if (numtype(ampRefW[j]) != 0 || ampRefW[j] <= 0)
            ampRefW[j] = 1
        endif

        j += 1
    endfor

    if (j <= 0)
        DoAlert 0, "No valid FFT waves remain after selection."
        return 0
    endif

    Redimension/N=(j) pathW, labW, fluW, ampRefW, offsetW, dispHW, sortKey
    nSel = j

    if (sortByFlu && nSel > 1)
        for (i=0; i<nSel; i+=1)
            if (numtype(fluW[i]) == 0)
                sortKey[i] = fluW[i]
            else
                sortKey[i] = 1e30 + i
            endif
        endfor
        Sort sortKey, sortKey, fluW, ampRefW, pathW, labW
    endif

    for (i=0; i<nSel; i+=1)
        if (doNorm)
            dispHW[i] = 1
        else
            dispHW[i] = ampRefW[i]
            if (numtype(dispHW[i]) != 0 || dispHW[i] <= 0)
                dispHW[i] = 1
            endif
        endif
    endfor

    offsetW[0] = 0
    for (i=1; i<nSel; i+=1)
        offsetW[i] = offsetW[i-1] + dispHW[i-1] * yStep
    endfor

    String tmpDF       = "root:ARPES_LJZ:ROIVARY:FFTWB:TMP:"
    String stackWin    = ROIVARY_FFTWB_GetPlotWinName("Stacked")
    String tmpWaveBase = ROIVARY_FFTWB_GetTmpWaveBase("Stacked")

    if (strlen(stackWin) == 0 || strlen(tmpWaveBase) == 0)
        DoAlert 0, "FFT PlotBase name is invalid."
        return 0
    endif

    DoWindow/K $stackWin
    Display/N=$stackWin

    String leg = ""

    for (i=0; i<nSel; i+=1)
        Wave/Z wRaw = $pathW[i]
        if (!WaveExists(wRaw))
            continue
        endif

        String wn = tmpDF + tmpWaveBase + "_stack_" + num2str(i)
        Duplicate/O wRaw, $wn
        Wave wD = $wn

        if (doNorm)
            Variable denom = ampRefW[i]
            if (numtype(denom) != 0 || denom <= 0)
                denom = 1
            endif
            wD = wRaw[p]/denom + offsetW[i]
        else
            wD = wRaw[p] + offsetW[i]
        endif

        AppendToGraph/W=$stackWin wD
        ModifyGraph/W=$stackWin lsize($NameOfWave(wD))=2

        if (mod(i,6) == 0)
            ModifyGraph/W=$stackWin rgb($NameOfWave(wD))=(0,0,0)
        elseif (mod(i,6) == 1)
            ModifyGraph/W=$stackWin rgb($NameOfWave(wD))=(57982,32896,0)
        elseif (mod(i,6) == 2)
            ModifyGraph/W=$stackWin rgb($NameOfWave(wD))=(0,29491,52428)
        elseif (mod(i,6) == 3)
            ModifyGraph/W=$stackWin rgb($NameOfWave(wD))=(0,39321,19660)
        elseif (mod(i,6) == 4)
            ModifyGraph/W=$stackWin rgb($NameOfWave(wD))=(52428,0,0)
        else
            ModifyGraph/W=$stackWin rgb($NameOfWave(wD))=(39321,19660,45875)
        endif

        String oneLeg = labW[i]
        if (numtype(fluW[i]) == 0)
            oneLeg += " (" + num2str(fluW[i]) + " mW)"
        endif

        leg += "\\s(" + NameOfWave(wD) + ") " + oneLeg
        if (i < nSel-1)
            leg += "\r"
        endif
    endfor

    Variable yTop = offsetW[nSel-1] + dispHW[nSel-1]
    if (numtype(yTop) != 0 || yTop <= 0)
        yTop = 1
    endif
    Variable yPad = 0.03*yTop

    SetAxis/W=$stackWin bottom, x0, x1
    SetAxis/W=$stackWin left, -yPad, yTop + yPad

    Label/W=$stackWin bottom "Frequency (" + xUnit + ")"
    if (doNorm)
        Label/W=$stackWin left "Normalized FFT + chained offset"
    else
        Label/W=$stackWin left "FFT intensity + chained offset"
    endif

    ModifyGraph/W=$stackWin mirror=2
    ModifyGraph/W=$stackWin tick=2
    ModifyGraph/W=$stackWin standoff=0
    ModifyGraph/W=$stackWin margin(left)=72,margin(bottom)=48,margin(right)=24,margin(top)=20
    ModifyGraph/W=$stackWin tickUnit(bottom)=1
    Legend/W=$stackWin/C/N=legbox/J/A=RT/X=2/Y=2 leg

    return 0
End

Function ROIVARY_FFTWB_PlotPeakVsFlu(ctrlName) : ButtonControl
    String ctrlName

    roivary_fftwb_init_if_needed()

    ROIVARY_FFTWB_UpdateSelectedPeaks()

    Wave/T   paths = root:ARPES_LJZ:ROIVARY:FFTWB_Paths_RV
    Wave/U/B sel   = root:ARPES_LJZ:ROIVARY:FFTWB_Sel_RV

    String plotBase = ROIVARY_FFTWB_GetPlotBaseName()
    if (strlen(plotBase) == 0)
        DoAlert 0, "Please input FFTOut first."
        return 0
    endif

    Variable i, n = DimSize(paths,0), nSel = 0
    for (i=0; i<n; i+=1)
        if (sel[i])
            nSel += 1
        endif
    endfor

    if (nSel <= 0)
        DoAlert 0, "Please select FFT waves in the workbench."
        return 0
    endif
    
    if (!roivary_fftwb_selected_xunits_consistent())
        DoAlert 0, "Selected FFT waves do not share the same frequency unit. Please select waves with the same unit before plotting together."
        return 0
    endif

    String xUnit = roivary_fftwb_first_selected_xunit()
    String tmpDF = "root:ARPES_LJZ:ROIVARY:FFTWB:TMP:"

    NVAR pkc = root:ARPES_LJZ:ROIVARY:FFTWB_PeakCenter_RV
    String pkcStr  = ReplaceString(".", num2str(pkc), "p")
    String tagStr  = "PeakVsFlu_pkc" + pkcStr
    String winName = ROIVARY_FFTWB_GetPlotWinName(tagStr)
    String tmpBase = ROIVARY_FFTWB_GetTmpWaveBase(tagStr)

    if (strlen(winName) == 0 || strlen(tmpBase) == 0)
        DoAlert 0, "FFTOut name is invalid."
        return 0
    endif

    String xName = tmpDF + tmpBase + "_X"
    String fName = tmpDF + tmpBase + "_Freq"
    String aName = tmpDF + tmpBase + "_Amp"

    Make/O/D/N=(nSel) $xName
    Make/O/D/N=(nSel) $fName
    Make/O/D/N=(nSel) $aName

    Wave xW     = $xName
    Wave yFreqW = $fName
    Wave yAmpW  = $aName

    Variable j = 0

    for (i=0; i<n; i+=1)
        if (!sel[i])
            continue
        endif

        Wave/Z w = $paths[i]
        if (!WaveExists(w))
            continue
        endif

        String nt = note(w)
        Variable flu = str2num(roivary_note_get_key(nt, "WB_Fluence"))
        Variable pkX = str2num(roivary_note_get_key(nt, "WB_PeakX"))
        Variable pkY = str2num(roivary_note_get_key(nt, "WB_PeakY"))

        if (numtype(flu) != 0 || numtype(pkX) != 0 || numtype(pkY) != 0)
            continue
        endif

        xW[j]     = flu
        yFreqW[j] = pkX
        yAmpW[j]  = pkY
        j += 1
    endfor

    if (j <= 0)
        KillWaves/Z $xName, $fName, $aName
        DoAlert 0, "Selected items do not have valid fluence / peak information in the chosen search window."
        return 0
    endif

    Redimension/N=(j) xW, yFreqW, yAmpW
    Sort xW, xW, yFreqW, yAmpW

    DoWindow/K $winName
    Display/N=$winName yFreqW vs xW
    AppendToGraph/R/W=$winName yAmpW vs xW

    ModifyGraph/W=$winName mode($NameOfWave(yFreqW))=4
    ModifyGraph/W=$winName marker($NameOfWave(yFreqW))=19
    ModifyGraph/W=$winName msize($NameOfWave(yFreqW))=4
    ModifyGraph/W=$winName lsize($NameOfWave(yFreqW))=2
    ModifyGraph/W=$winName rgb($NameOfWave(yFreqW))=(0,0,65535)

    ModifyGraph/W=$winName mode($NameOfWave(yAmpW))=4
    ModifyGraph/W=$winName marker($NameOfWave(yAmpW))=16
    ModifyGraph/W=$winName msize($NameOfWave(yAmpW))=4
    ModifyGraph/W=$winName lsize($NameOfWave(yAmpW))=2
    ModifyGraph/W=$winName rgb($NameOfWave(yAmpW))=(56000,0,0)

    ModifyGraph/W=$winName mirror(bottom)=2
    ModifyGraph/W=$winName tick=2
    ModifyGraph/W=$winName standoff=0

    Label/W=$winName bottom "Pump Fluence (mW)"
    Label/W=$winName left "Peak Frequency (" + xUnit + ")"
    Label/W=$winName right "Peak Intensity (a.u.)"

    Legend/W=$winName/C/N=pkleg/J/A=RT/X=2/Y=2 "\\s(" + NameOfWave(yFreqW) + ") Peak frequency\r" + "\\s(" + NameOfWave(yAmpW) + ") Peak intensity"

    return 0
End

//============================================================
// 31) FFT Workbench : open panel
//============================================================
Function ROIVARY_OpenFFTWorkbench(ctrlName) : ButtonControl
    String ctrlName

    roivary_fftwb_init_if_needed()

    DoWindow/F ROIVARY_FFTWB_P
    if (V_flag == 0)
        Execute/Q "ROIVARY_FFTWB_P()"
    endif

    ROIVARY_FFTWB_RebuildList()
    return 0
End

Window ROIVARY_FFTWB_P() : Panel
    PauseUpdate; Silent 1
    NewPanel /W=(180,120,930,730) as "ROIVARY_FFTWB"
    ModifyPanel frameStyle=1

    //================================================
    // Left: FFT library
    //================================================
    GroupBox gbLib,pos={12,8},size={320,640},title="FFT Library"

    TitleBox t1,pos={24,30},size={30,18},title="Filter:",frame=0
    SetVariable wb_sv_filter,pos={68,27},size={188,20},proc=ROIVARY_FFTWB_FilterProc
    SetVariable wb_sv_filter,value=root:ARPES_LJZ:ROIVARY:FFTWB_Filter_RV
    Button wb_btn_cf,pos={264,27},size={48,20},proc=ROIVARY_FFTWB_ClearFilter,title="Clear"

    ListBox lbFFTWB,pos={24,58},size={288,300},proc=ROIVARY_FFTWB_LBProc
    ListBox lbFFTWB,listWave=root:ARPES_LJZ:ROIVARY:FFTWB_Items_RV
    ListBox lbFFTWB,selWave=root:ARPES_LJZ:ROIVARY:FFTWB_Sel_RV,mode=4

    Button wb_btn_ref,pos={24,370},size={88,24},proc=ROIVARY_FFTWB_RefreshButton,title="Refresh"
    Button wb_btn_auto,pos={124,370},size={88,24},proc=ROIVARY_FFTWB_AutoFluence,title="Auto Fluence"
    Button wb_btn_rm,pos={224,370},size={88,24},proc=ROIVARY_FFTWB_RemoveSelected,title="Remove"

    Button wb_btn_clearall,pos={24,402},size={288,24},proc=ROIVARY_FFTWB_ClearAll,title="Clear All"

    //================================================
    // Left-bottom: metadata editing
    //================================================
    GroupBox gbMeta,pos={24,445},size={288,150},title="Metadata for Selected"

    TitleBox t2,pos={36,470},size={46,18},title="Fluence:",frame=0
    SetVariable wb_sv_flu,pos={92,467},size={200,20}
    SetVariable wb_sv_flu,limits={-inf,inf,0.1},value=root:ARPES_LJZ:ROIVARY:FFTWB_EditFluence_RV

    TitleBox t3,pos={36,500},size={32,18},title="Label:",frame=0
    SetVariable wb_sv_lab,pos={92,497},size={200,20}
    SetVariable wb_sv_lab,value=root:ARPES_LJZ:ROIVARY:FFTWB_EditLabel_RV

    Button wb_btn_apply,pos={36,532},size={256,26},proc=ROIVARY_FFTWB_ApplyMeta,title="Apply Meta To Selected"

    TitleBox tMetaHint,pos={36,566},size={248,18},frame=0
    TitleBox tMetaHint,title="Tip: click one selected item to load its label/fluence."

    //================================================
    // Right-top: stacked plot settings
    //================================================
    GroupBox gbPlot,pos={348,8},size={340,150},title="Stack Plot Settings"

    SetVariable wb_sv_x0,pos={360,32},size={92,20},title="x0"
    SetVariable wb_sv_x0,limits={-inf,inf,0.1},value=root:ARPES_LJZ:ROIVARY:FFTWB_X0_RV

    SetVariable wb_sv_x1,pos={468,32},size={92,20},title="x1"
    SetVariable wb_sv_x1,limits={-inf,inf,0.1},value=root:ARPES_LJZ:ROIVARY:FFTWB_X1_RV

    SetVariable wb_sv_ystep,pos={576,32},size={92,20},title="yStep"
    SetVariable wb_sv_ystep,limits={0.1,inf,0.05},value=root:ARPES_LJZ:ROIVARY:FFTWB_YStep_RV

    CheckBox wb_ck_sort,pos={360,66},size={96,18},title="Sort by Fluence"
    CheckBox wb_ck_sort,variable=root:ARPES_LJZ:ROIVARY:FFTWB_SortByFlu_RV

    CheckBox wb_ck_norm,pos={500,66},size={132,18},title="Normalize each trace"
    CheckBox wb_ck_norm,variable=root:ARPES_LJZ:ROIVARY:FFTWB_Normalize_RV

    Button wb_btn_stack,pos={360,102},size={138,28},proc=ROIVARY_FFTWB_PlotStacked,title="Plot Stacked"
    Button wb_btn_peak,pos={514,102},size={154,28},proc=ROIVARY_FFTWB_PlotPeakVsFlu,title="Plot Peak vs Fluence"

    //================================================
    // Right-middle: peak settings
    //================================================
    GroupBox gbPeak,pos={348,176},size={340,105},title="Peak Settings"

    SetVariable wb_sv_pkc,pos={360,202},size={92,20},title="PeakC"
    SetVariable wb_sv_pkc,limits={-inf,inf,0.1},value=root:ARPES_LJZ:ROIVARY:FFTWB_PeakCenter_RV

    SetVariable wb_sv_pkh,pos={468,202},size={92,20},title="HalfW"
    SetVariable wb_sv_pkh,limits={0.01,inf,0.05},value=root:ARPES_LJZ:ROIVARY:FFTWB_PeakHalfWidth_RV

    SetVariable wb_sv_pks,pos={576,202},size={92,20},title="SmoothN"
    SetVariable wb_sv_pks,limits={1,21,2},value=root:ARPES_LJZ:ROIVARY:FFTWB_PeakSmoothN_RV

    TitleBox tPeakHint,pos={360,235},size={300,18},frame=0
    TitleBox tPeakHint,title="Use a fixed search window for consistent peak extraction."

    //================================================
    // Right-lower: output naming
    //================================================
    GroupBox gbOut,pos={348,300},size={340,100},title="Output Naming"

   TitleBox tFFTBase,pos={360,328},size={74,18},title="FFT PlotBase:",frame=0
   SetVariable svFFTBase,pos={440,325},size={220,20}
   SetVariable svFFTBase,value=root:ARPES_LJZ:ROIVARY:FFTPlotBaseName_RV

    TitleBox tOutHint,pos={360,356},size={300,18},frame=0
    TitleBox tOutHint,title="Used for saved FFT names and FFTWB plot window names."

    //================================================
    // Right-bottom: note area
    //================================================
    GroupBox gbInfo,pos={348,418},size={340,130},title="Notes"

    TitleBox tInfo1,pos={360,442},size={300,18},frame=0
    TitleBox tInfo1,title="1. Select FFT waves on the left."

    TitleBox tInfo2,pos={360,464},size={300,18},frame=0
    TitleBox tInfo2,title="2. Edit metadata if needed."

    TitleBox tInfo3,pos={360,486},size={300,18},frame=0
    TitleBox tInfo3,title="3. Set x-range / offset / normalize."

    TitleBox tInfo4,pos={360,508},size={300,18},frame=0
    TitleBox tInfo4,title="4. Plot stacked curves or peak vs fluence."
EndMacro


Function ROIVARY_FFTWB_LoadFirstSelectedMeta()
    Wave/T paths = root:ARPES_LJZ:ROIVARY:FFTWB_Paths_RV
    Wave/U/B sel = root:ARPES_LJZ:ROIVARY:FFTWB_Sel_RV
    SVAR editLab = root:ARPES_LJZ:ROIVARY:FFTWB_EditLabel_RV
    NVAR editFlu = root:ARPES_LJZ:ROIVARY:FFTWB_EditFluence_RV

    Variable i, n = DimSize(sel, 0)

    editLab = ""
    editFlu = NaN

    for (i=0; i<n; i+=1)
        if (!sel[i])
            continue
        endif

        Wave/Z w = $paths[i]
        if (!WaveExists(w))
            continue
        endif

        String nt = note(w)

        editLab = roivary_note_get_key(nt, "WB_Label")
        if (strlen(editLab) == 0)
            editLab = NameOfWave(w)
        endif

        String sFlu = roivary_note_get_key(nt, "WB_Fluence")
        if (strlen(sFlu) > 0)
            editFlu = str2num(sFlu)
        endif

        break
    endfor

    DoWindow ROIVARY_FFTWB_P
    if (V_flag)
        ControlUpdate/W=ROIVARY_FFTWB_P wb_sv_lab
        ControlUpdate/W=ROIVARY_FFTWB_P wb_sv_flu
    endif

    return 0
End

Function roivary_find_peak_near_target_in_wave(w, xCenter, halfWidth, smoothN, peakX, peakY)
    Wave w
    Variable xCenter, halfWidth, smoothN
    Variable &peakX, &peakY

    peakX = NaN
    peakY = NaN

    Variable n = DimSize(w,0)
    if (n < 3)
        return -1
    endif

    Variable lo = xCenter - abs(halfWidth)
    Variable hi = xCenter + abs(halfWidth)

    Variable axisLo = min(LeftX(w), RightX(w))
    Variable axisHi = max(LeftX(w), RightX(w))

    lo = max(lo, axisLo)
    hi = min(hi, axisHi)

    if (hi <= lo)
        return -1
    endif

    Variable i0 = round(x2pnt(w, lo))
    Variable i1 = round(x2pnt(w, hi))

    i0 = max(1, min(n-2, i0))
    i1 = max(1, min(n-2, i1))

    if (i1 < i0)
        Variable it = i0
        i0 = i1
        i1 = it
    endif

    Duplicate/FREE w, wSm
    Variable sn = round(smoothN)
    if (sn >= 3)
        sn = max(3, sn)
        if (mod(sn,2) == 0)
            sn += 1
        endif
        Smooth sn, wSm
    endif

    Variable i
    Variable bestIdx = -1
    Variable bestDist = 1e30

    // 先找局部峰，选择最接近目标中心的
    for (i=i0; i<=i1; i+=1)
        if (numtype(wSm[i]) != 0)
            continue
        endif

        if (wSm[i] >= wSm[i-1] && wSm[i] >= wSm[i+1])
            Variable xi = pnt2x(wSm, i)
            Variable dist = abs(xi - xCenter)
            if (dist < bestDist)
                bestDist = dist
                bestIdx = i
            endif
        endif
    endfor

    // 如果没有局部峰，再退回成窗口内最高点
    if (bestIdx < 0)
        Variable vmax = -1e30
        for (i=i0; i<=i1; i+=1)
            if (numtype(wSm[i]) == 0)
                if (wSm[i] > vmax)
                    vmax = wSm[i]
                    bestIdx = i
                endif
            endif
        endfor
    endif

    if (bestIdx < 0)
        return -1
    endif

    peakX = pnt2x(w, bestIdx)
    peakY = w[bestIdx]
    return 0
End

Function ROIVARY_FFTWB_UpdateSelectedPeaks()
    Wave/T paths = root:ARPES_LJZ:ROIVARY:FFTWB_Paths_RV
    Wave/U/B sel = root:ARPES_LJZ:ROIVARY:FFTWB_Sel_RV

    NVAR peakCenter = root:ARPES_LJZ:ROIVARY:FFTWB_PeakCenter_RV
    NVAR peakHalfW  = root:ARPES_LJZ:ROIVARY:FFTWB_PeakHalfWidth_RV
    NVAR peakSmN    = root:ARPES_LJZ:ROIVARY:FFTWB_PeakSmoothN_RV

    Variable i, n = DimSize(paths,0)

    for (i=0; i<n; i+=1)
        if (!sel[i])
            continue
        endif

        Wave/Z w = $paths[i]
        if (!WaveExists(w))
            continue
        endif

        Variable pkX, pkY
        Variable rc = roivary_find_peak_near_target_in_wave(w, peakCenter, peakHalfW, peakSmN, pkX, pkY)

        String nt = note(w)
        if (rc == 0)
            nt = roivary_note_set_key(nt, "WB_PeakX", num2str(pkX))
            nt = roivary_note_set_key(nt, "WB_PeakY", num2str(pkY))
        else
            nt = roivary_note_set_key(nt, "WB_PeakX", "NaN")
            nt = roivary_note_set_key(nt, "WB_PeakY", "NaN")
        endif

        nt = roivary_note_set_key(nt, "WB_PeakCenter", num2str(peakCenter))
        nt = roivary_note_set_key(nt, "WB_PeakHalfWidth", num2str(peakHalfW))

        Note/K w
        Note w, nt
    endfor

    return 0
End


Function ROIVARY_FFTWB_RefreshButton(ctrlName) : ButtonControl
    String ctrlName
    ROIVARY_FFTWB_RebuildList()
    return 0
End

//============================================================
// A) core naming / source parsing / workbench store
//============================================================

Function roivary_is_alpha_char(ch)
    String ch
    String s = LowerStr(ch)
    if (cmpstr(s, "a") >= 0 && cmpstr(s, "z") <= 0)
        return 1
    endif
    return 0
End

Function/S roivary_get_current_roi_hash()
    ROIVARY_UpdateCurrentCode()

    SVAR/Z CurrentCode_RV = root:ARPES_LJZ:ROIVARY:CurrentCode_RV
    String out = ""

    if (SVAR_Exists(CurrentCode_RV))
        out = roivary_sanitize_name(CurrentCode_RV)
    endif
    return out
End

// 纯 PlotBase：只负责前面板系列名，不自动拼 hash
Function/S roivary_get_plot_base_name()
    SVAR/Z PlotBaseName_RV = root:ARPES_LJZ:ROIVARY:PlotBaseName_RV
    SVAR/Z WaveSel_RV      = root:ARPES_LJZ:ROIVARY:WaveSel_RV

    String out = ""

    if (SVAR_Exists(PlotBaseName_RV))
        if (strlen(PlotBaseName_RV) > 0)
            out = PlotBaseName_RV
        endif
    endif

    if (strlen(out) == 0)
        Wave/Z w = $WaveSel_RV
        if (WaveExists(w))
            out = NameOfWave(w)
        else
            out = "ROIVARY"
        endif
    endif

    return roivary_sanitize_name(out)
End

// 前面板统一前缀：PlotBase + ROIHash
Function/S roivary_get_front_plot_prefix()
    String base = roivary_get_plot_base_name()
    String roi  = roivary_get_current_roi_hash()

    if (strlen(roi) > 0)
        return roivary_sanitize_name(base + "_" + roi)
    endif
    return roivary_sanitize_name(base)
End



Function/S roivary_wave_tail_from_path(wp)
    String wp

    Variable n = ItemsInList(wp, ":")
    if (n <= 0)
        return wp
    endif

    return StringFromList(n-1, wp, ":")
End

Function/S roivary_path_parent_leaf(pathStr)
    String pathStr

    Variable n = ItemsInList(pathStr, ":")
    if (n < 2)
        return ""
    endif

    return StringFromList(n-2, pathStr, ":")
End

Function/S roivary_cut_before_marker_ci(inStr, markerStr)
    String inStr, markerStr

    String sU = UpperStr(inStr)
    String mU = UpperStr(markerStr)

    Variable p = strsearch(sU, mU, 0)
    if (p > 0)
        return inStr[0, p-1]
    elseif (p == 0)
        return ""
    endif

    return inStr
End

// 从 residual path 反推出“原始 source wave 的 base 名”
// 例如：p0d5Tp18_roi2_TVQ_QJD4K9NN  ->  p0d5Tp18_roi2
Function/S roivary_source_base_from_residual_path(sourceResidualPath)
    String sourceResidualPath

    String s = roivary_path_parent_leaf(sourceResidualPath)
    if (strlen(s) == 0)
        s = roivary_wave_tail_from_path(sourceResidualPath)
    endif

    s = roivary_cut_before_marker_ci(s, "_TVT_")
    s = roivary_cut_before_marker_ci(s, "_TVQ_")
    s = roivary_cut_before_marker_ci(s, "_TVP_")

    return s
End

// 显示时不想总看到 roi2、roi3 这种尾巴，就截掉
Function/S roivary_trim_roi_suffix_simple(inStr)
    String inStr

    String sL = LowerStr(inStr)
    Variable p = strsearch(sL, "_roi", 0)
    if (p > 0)
        return inStr[0, p-1]
    endif

    return inStr
End

Function/S roivary_num_to_tag_token(v)
    Variable v

    String s = num2str(v)
    s = ReplaceString(".", s, "d")
    s = ReplaceString("-", s, "m")
    s = ReplaceString("+", s, "")
    return s
End

Function roivary_try_parse_p_from_string(inStr, outP)
    String inStr
    Variable &outP

    String s = LowerStr(inStr)
    Variable i, j, L = strlen(s)

    outP = NaN

    for (i=0; i<L; i+=1)
        if (cmpstr(s[i,i], "p") != 0)
            continue
        endif

        if (i > 0)
            if (roivary_is_alpha_char(s[i-1,i-1]))
                continue
            endif
        endif

        if (i+1 >= L)
            continue
        endif
        if (!roivary_is_digit_char(s[i+1,i+1]))
            continue
        endif

        String tok = ""
        for (j=i+1; j<L; j+=1)
            String ch = s[j,j]
            if (roivary_is_digit_char(ch) || StringMatch(ch, "d") || StringMatch(ch, "."))
                tok += ch
            else
                break
            endif
        endfor

        if (strlen(tok) > 0)
            tok = ReplaceString("d", tok, ".")
            outP = str2num(tok)
            if (numtype(outP) == 0)
                return 1
            endif
        endif
    endfor

    return 0
End

Function roivary_try_parse_tp_from_string(inStr, outTp)
    String inStr
    Variable &outTp

    String s = LowerStr(inStr)
    Variable i, j, L = strlen(s)

    outTp = NaN

    for (i=0; i<L-1; i+=1)
        if (cmpstr(s[i,i+1], "tp") != 0)
            continue
        endif

        if (i > 0)
            if (roivary_is_alpha_char(s[i-1,i-1]))
                continue
            endif
        endif

        if (i+2 >= L)
            continue
        endif
        if (!roivary_is_digit_char(s[i+2,i+2]))
            continue
        endif

        String tok = ""
        for (j=i+2; j<L; j+=1)
            String ch = s[j,j]
            if (roivary_is_digit_char(ch) || StringMatch(ch, "d") || StringMatch(ch, "."))
                tok += ch
            else
                break
            endif
        endfor

        if (strlen(tok) > 0)
            tok = ReplaceString("d", tok, ".")
            outTp = str2num(tok)
            if (numtype(outTp) == 0)
                return 1
            endif
        endif
    endfor

    return 0
End

// 给 workbench 一个干净的 source short：优先 p / Tp，不够再退回源名截断
Function/S roivary_make_source_short(sourceResidualPath)
    String sourceResidualPath

    String sourceBase = roivary_source_base_from_residual_path(sourceResidualPath)
    String srcDisp    = roivary_trim_roi_suffix_simple(sourceBase)

    Variable pVal = NaN, tpVal = NaN
    Variable hasP  = roivary_try_parse_p_from_string(srcDisp, pVal)
    Variable hasTp = roivary_try_parse_tp_from_string(srcDisp, tpVal)

    String out = ""

    if (hasP)
        out += "p" + roivary_num_to_tag_token(pVal)
    endif
    if (hasTp)
        out += "Tp" + roivary_num_to_tag_token(tpVal)
    endif

    if (strlen(out) == 0)
        out = srcDisp
        if (strlen(out) > 24)
            out = out[0,23]
        endif
    endif

    return roivary_sanitize_name(out)
End

Function/S roivary_fftwb_make_store_name(sourceResidualPath)
    String sourceResidualPath

    String fftBase        = roivary_get_fft_plot_base_name()
    String sourceBase     = roivary_source_base_from_residual_path(sourceResidualPath)
    String sourceBaseSafe = roivary_sanitize_name(sourceBase)

    if (strlen(sourceBaseSafe) == 0)
        sourceBaseSafe = roivary_make_source_short(sourceResidualPath)
    endif

    return roivary_sanitize_name("WB__" + fftBase + "__" + sourceBaseSafe + "_WBMAIN")
End

//==============================
// workbench plot names
//==============================
Function/S ROIVARY_FFTWB_GetPlotBaseName()
    return roivary_get_fft_plot_base_name()
End



//==============================
// workbench save
//==============================
Function ROIVARY_FFTWB_SaveCurrentFFT(wDisp, sourceResidualPath)
    Wave wDisp
    String sourceResidualPath

    roivary_fftwb_init_if_needed()

String outDF         = "root:ARPES_LJZ:ROIVARY:FFTWB:OUT:"
String frontPlotBase = roivary_get_plot_base_name()
String fftPlotBase   = roivary_get_fft_plot_base_name()
String roiHash       = roivary_get_current_roi_hash()
String frontBase     = roivary_get_front_plot_prefix()
String sourceBase    = roivary_source_base_from_residual_path(sourceResidualPath)
String sourceShort   = roivary_make_source_short(sourceResidualPath)
String outMain       = roivary_fftwb_make_store_name(sourceResidualPath)

    Variable flu  = NaN
    Variable tpV  = NaN

    if (!roivary_try_get_fluence_from_wavepath(sourceResidualPath, flu))
        roivary_try_parse_p_from_string(sourceBase, flu)
    endif
    roivary_try_parse_tp_from_string(sourceBase, tpV)

    Duplicate/O wDisp, $(outDF + outMain)
    Wave wOut = $(outDF + outMain)

String lab = sourceShort
if (strlen(lab) == 0)
    lab = sourceBase
endif
if (strlen(lab) == 0)
    lab = fftPlotBase
endif

    String nt = note(wDisp)
nt = roivary_note_set_key(nt, "WB_SourceFFT", GetWavesDataFolder(wDisp, 2))
nt = roivary_note_set_key(nt, "WB_SourceResidual", sourceResidualPath)
nt = roivary_note_set_key(nt, "WB_SourceBase", sourceBase)
nt = roivary_note_set_key(nt, "WB_SourceShort", sourceShort)

nt = roivary_note_set_key(nt, "WB_FrontPlotBase", frontPlotBase)
nt = roivary_note_set_key(nt, "WB_FFTPlotBase", fftPlotBase)
nt = roivary_note_set_key(nt, "WB_FrontBase", frontBase)
nt = roivary_note_set_key(nt, "WB_ROIHash", roiHash)

nt = roivary_note_set_key(nt, "WB_Label", lab)
nt = roivary_note_set_key(nt, "WB_Fluence", num2str(flu))

    if (numtype(tpV) == 0)
        nt = roivary_note_set_key(nt, "WB_Tp", num2str(tpV))
    else
        nt = roivary_note_set_key(nt, "WB_Tp", "")
    endif

    Note/K wOut
    Note wOut, nt

    DoWindow ROIVARY_FFTWB_P
    if (V_flag)
        ROIVARY_FFTWB_RebuildList()
    endif

    return 0
End

Function/S roivary_fftwb_make_item_text(w)
    Wave w

    String nt           = note(w)
    String fftPlotBase  = roivary_note_get_key(nt, "WB_FFTPlotBase")
    String roiHash      = roivary_note_get_key(nt, "WB_ROIHash")
    String sourceShort  = roivary_note_get_key(nt, "WB_SourceShort")
    String labelStr     = roivary_note_get_key(nt, "WB_Label")

    Variable flu = str2num(roivary_note_get_key(nt, "WB_Fluence"))
    Variable tpV = str2num(roivary_note_get_key(nt, "WB_Tp"))

    String out = fftPlotBase


    if (numtype(flu) == 0)
        out = " | p=" + num2str(flu)
    endif

    // if (numtype(tpV) == 0)
    //     out += " | Tp=" + num2str(tpV)
    // endif

    if (strlen(roiHash) > 0)
        out += " | #" + roiHash
    endif

    if (strlen(sourceShort) > 0)
        out += " | src:" + sourceShort
    endif

    if (strlen(labelStr) > 0 && cmpstr(labelStr, sourceShort) != 0)
        out += " | label:" + labelStr
    endif

    if (strlen(out) == 0)
        out += NameOfWave(w)
    endif
    return out
End

Function/S roivary_make_plot_win_name(suffixStr)
    String suffixStr

    String prefixStr  = roivary_get_front_plot_prefix()
    String suffixSafe = roivary_sanitize_name(suffixStr)

    return roivary_sanitize_name(prefixStr + "_" + suffixSafe)
End

Function/S ROIVARY_FFTWB_GetPlotWinName(suffixStr)
    String suffixStr

    String baseStr    = roivary_get_fft_plot_base_name()
    String suffixSafe = roivary_sanitize_name(suffixStr)

    if (strlen(baseStr) == 0)
        baseStr = "ROIVARY_FFT"
    endif

    return roivary_sanitize_name(baseStr + "_" + suffixSafe)
End

Function/S ROIVARY_FFTWB_GetTmpWaveBase(suffixStr)
    String suffixStr

    String baseStr    = roivary_get_fft_plot_base_name()
    String suffixSafe = roivary_sanitize_name(suffixStr)

    if (strlen(baseStr) == 0)
        baseStr = "ROIVARY_FFT"
    endif

    return roivary_sanitize_name("TMP_" + baseStr + "_" + suffixSafe)
End

//============================================================
// B) nicer image windows : Display + AppendImage + overlay
//============================================================

Function/S roivary_nonempty_label(inStr, fallbackStr)
    String inStr, fallbackStr

    if (strlen(inStr) > 0)
        return inStr
    endif
    return fallbackStr
End

Function roivary_open_image_graph_basic(winName, imgWave, leftLab, bottomLab)
    String winName, leftLab, bottomLab
    Wave imgWave

    DoWindow/K $winName
    Display/N=$winName
    AppendImage imgWave
    DoWindow/F $winName

    ModifyGraph/W=$winName tick=2
    ModifyGraph/W=$winName standoff=0
    ModifyGraph/W=$winName mirror=0
    ModifyGraph/W=$winName margin(left)=58,margin(bottom)=48,margin(right)=18,margin(top)=18

    ModifyImage $NameOfWave(imgWave) ctab={*,*,Terrain256,0}

    Label/W=$winName left leftLab
    Label/W=$winName bottom bottomLab

    SetAxis/A/W=$winName left
    SetAxis/A/W=$winName bottom

    return 0
End

Function roivary_open_image_graph_overlay(winName, imgWave, xW, yW, leftLab, bottomLab)
    String winName, leftLab, bottomLab
    Wave imgWave
    Wave xW
    Wave yW

    roivary_open_image_graph_basic(winName, imgWave, leftLab, bottomLab)

    DoWindow/F $winName
    AppendToGraph/W=$winName yW vs xW

    ModifyGraph/W=$winName lsize($NameOfWave(yW))=2.5
    ModifyGraph/W=$winName rgb($NameOfWave(yW))=(65535,16385,0)
    ModifyGraph/W=$winName marker($NameOfWave(yW))=19
    ModifyGraph/W=$winName msize($NameOfWave(yW))=3

    return 0
End

// 统一生成 first / last image，并叠加 ROI 轮廓
Function roivary_show_first_last_overlay_from3d(baseName, code, tagPrefix, w3d, xW, yW)
    String baseName, code, tagPrefix
    Wave w3d
    Wave xW
    Wave yW

    Variable nx = DimSize(w3d,0)
    Variable ny = DimSize(w3d,1)
    Variable nt = DimSize(w3d,2)

    Variable dx = DimDelta(w3d,0), x0 = DimOffset(w3d,0)
    Variable dy = DimDelta(w3d,1), y0 = DimOffset(w3d,1)

    String wFirstName = baseName + "_FirstW_" + code
    String wLastName  = baseName + "_LastW_"  + code

    Make/O/N=(nx,ny) $wFirstName = w3d[p][q][0]
    Make/O/N=(nx,ny) $wLastName  = w3d[p][q][nt-1]

    Wave wFirst = $wFirstName
    Wave wLast  = $wLastName

    SetScale/P x, x0, dx, wFirst
    SetScale/P y, y0, dy, wFirst
    SetScale/P x, x0, dx, wLast
    SetScale/P y, y0, dy, wLast

    String xLab = roivary_nonempty_label(WaveUnits(wFirst,0), "X")
    String yLab = roivary_nonempty_label(WaveUnits(wFirst,1), "Y")

    String winFirst = baseName + "_" + tagPrefix + "FIR_" + code
    String winLast  = baseName + "_" + tagPrefix + "LST_" + code

    roivary_open_image_graph_overlay(winFirst, wFirst, xW, yW, yLab, xLab)
    roivary_open_image_graph_overlay(winLast,  wLast,  xW, yW, yLab, xLab)

    return 0
End

Function/S roivary_get_fft_output_base_name()
    return roivary_get_fft_plot_base_name()
End

Function/S roivary_fftwb_first_selected_xunit()
    Wave/T paths = root:ARPES_LJZ:ROIVARY:FFTWB_Paths_RV
    Wave/U/B sel = root:ARPES_LJZ:ROIVARY:FFTWB_Sel_RV

    Variable i, n = DimSize(paths, 0)
    for (i=0; i<n; i+=1)
        if (!sel[i])
            continue
        endif

        Wave/Z w = $paths[i]
        if (!WaveExists(w))
            continue
        endif

        String u = WaveUnits(w, 0)
        if (strlen(u) == 0)
            u = "THz"
        endif
        return u
    endfor

    return "THz"
End

Function roivary_fftwb_selected_xunits_consistent()
    Wave/T paths = root:ARPES_LJZ:ROIVARY:FFTWB_Paths_RV
    Wave/U/B sel = root:ARPES_LJZ:ROIVARY:FFTWB_Sel_RV

    String u0 = ""
    String u
    Variable i, n = DimSize(paths, 0)

    for (i=0; i<n; i+=1)
        if (!sel[i])
            continue
        endif

        Wave/Z w = $paths[i]
        if (!WaveExists(w))
            continue
        endif

        u = WaveUnits(w, 0)
        if (strlen(u) == 0)
            u = "THz"
        endif

        if (strlen(u0) == 0)
            u0 = u
        else
            if (cmpstr(u, u0) != 0)
                return 0
            endif
        endif
    endfor

    return 1
End

Function roivary_validate_current_roi_for_wave(w, showAlert)
    Wave w
    Variable showAlert

    Variable nx, ny
    NVAR shp = root:ARPES_LJZ:ROIVARY:ROI_shape_RV
    NVAR i1 = root:ARPES_LJZ:ROIVARY:ROI_ix1_RV
    NVAR j1 = root:ARPES_LJZ:ROIVARY:ROI_iy1_RV
    NVAR i2 = root:ARPES_LJZ:ROIVARY:ROI_ix2_RV
    NVAR j2 = root:ARPES_LJZ:ROIVARY:ROI_iy2_RV
    NVAR i3 = root:ARPES_LJZ:ROIVARY:ROI_ix3_RV
    NVAR j3 = root:ARPES_LJZ:ROIVARY:ROI_iy3_RV
    NVAR i4 = root:ARPES_LJZ:ROIVARY:ROI_ix4_RV
    NVAR j4 = root:ARPES_LJZ:ROIVARY:ROI_iy4_RV
    NVAR i5 = root:ARPES_LJZ:ROIVARY:ROI_ix5_RV
    NVAR j5 = root:ARPES_LJZ:ROIVARY:ROI_iy5_RV

    if (WaveDims(w) != 3)
        if (showAlert)
            DoAlert 0, "Selected wave must be a valid 3D wave."
        endif
        return -1
    endif

    nx = DimSize(w, 0)
    ny = DimSize(w, 1)

    if (shp < 1 || shp > 3)
        if (showAlert)
            DoAlert 0, "ROI shape must be Triangle, Quadrilateral, or Pentagon."
        endif
        return -1
    endif

    if (numtype(i1) != 0 || numtype(j1) != 0 || \
        numtype(i2) != 0 || numtype(j2) != 0 || \
        numtype(i3) != 0 || numtype(j3) != 0)
        if (showAlert)
            DoAlert 0, "Triangle ROI requires valid vertices 1-3."
        endif
        return -1
    endif

    if (shp >= 2)
        if (numtype(i4) != 0 || numtype(j4) != 0)
            if (showAlert)
                DoAlert 0, "Quadrilateral ROI requires valid vertex 4."
            endif
            return -1
        endif
    endif

    if (shp >= 3)
        if (numtype(i5) != 0 || numtype(j5) != 0)
            if (showAlert)
                DoAlert 0, "Pentagon ROI requires valid vertex 5."
            endif
            return -1
        endif
    endif

    if (i1 < 0 || i1 >= nx || j1 < 0 || j1 >= ny || \
        i2 < 0 || i2 >= nx || j2 < 0 || j2 >= ny || \
        i3 < 0 || i3 >= nx || j3 < 0 || j3 >= ny)
        if (showAlert)
            DoAlert 0, "ROI vertices 1-3 are out of image bounds."
        endif
        return -1
    endif

    if (shp >= 2)
        if (i4 < 0 || i4 >= nx || j4 < 0 || j4 >= ny)
            if (showAlert)
                DoAlert 0, "ROI vertex 4 is out of image bounds."
            endif
            return -1
        endif
    endif

    if (shp >= 3)
        if (i5 < 0 || i5 >= nx || j5 < 0 || j5 >= ny)
            if (showAlert)
                DoAlert 0, "ROI vertex 5 is out of image bounds."
            endif
            return -1
        endif
    endif

    return 0
End

Function ROIVARY_UpdateCurrentCode()
    SVAR/Z CurrentCode_RV = root:ARPES_LJZ:ROIVARY:CurrentCode_RV
    if (!SVAR_Exists(CurrentCode_RV))
        String/G root:ARPES_LJZ:ROIVARY:CurrentCode_RV = ""
        SVAR CurrentCode_RV = root:ARPES_LJZ:ROIVARY:CurrentCode_RV
    endif

    CurrentCode_RV = roivary_get_current_code_from_state()
    return 0
End

Function/S roivary_get_fft_plot_base_name()
    SVAR/Z FFTPlotBaseName_RV = root:ARPES_LJZ:ROIVARY:FFTPlotBaseName_RV
    SVAR/Z WaveSel_RV         = root:ARPES_LJZ:ROIVARY:WaveSel_RV

    String out = ""

    if (SVAR_Exists(FFTPlotBaseName_RV))
        if (strlen(FFTPlotBaseName_RV) > 0)
            out = FFTPlotBaseName_RV
        endif
    endif

    if (strlen(out) == 0)
        Wave/Z w = $WaveSel_RV
        if (WaveExists(w))
            out = NameOfWave(w) + "_FFT"
        else
            out = "ROIVARY_FFT"
        endif
    endif

    return roivary_sanitize_name(out)
End