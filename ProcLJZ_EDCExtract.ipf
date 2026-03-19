#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  LJZ_EDCExtract : standalone EDC extraction panel
//  只负责：
//    1) scan 3D waves
//    2) extract EDCs from w[E][K][T]
//    3) optional smoothing
//    4) overlapping display
//    5) runDF metadata
//
//  不负责：
//    - fit engine
//    - EDCWB model / guess / export
// ============================================================================

Menu "ARPES_LJZ"
    "2026EDCExtract_LJZ", LJZ_EDCExtract()
End

#pragma DefaultTab={3,20,4}

// ============================================================================
//  Section 0. paths / state
// ============================================================================

Function/S LJZ_EDCExtract_BaseDF()
    return "root:ARPES_LJZ:EDCExtract"
End

Function/S LJZ_EDCExtract_RunRoot()
    return "root:ARPES_LJZ:EDCExtract_RUNS"
End

Function/S LJZ_EDCExtract_PanelName()
    return "LJZ_EDCExtract_Panel"
End

Function/S LJZ_EDCExtract_GraphName()
    return "LJZ_EDCExtract_Graph"
End

Function/S LJZ_EDCExtract_df_with_colon(inStr)
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

Function LJZ_EDCExtract_df_exists(dfStr)
    String dfStr
    String s = LJZ_EDCExtract_df_with_colon(dfStr)
    return DataFolderExists(s)
End

Function/S LJZ_EDCExtract_WaveNameFromPath(wPath)
    String wPath

    Variable p
    p = strsearch(wPath, ":", Inf)
    if (p < 0)
        return ""
    endif

    return wPath[p + 1, Inf]
End

Function/S LJZ_EDCExtract_WaveDFFromPath(wPath)
    String wPath

    Variable p
    p = strsearch(wPath, ":", Inf)
    if (p < 0)
        return ""
    endif

    return wPath[0, p]
End

Function LJZ_EDCExtract_Is1DWave(w)
    Wave/Z w

    if (!WaveExists(w))
        return 0
    endif

    if (DimSize(w, 1) > 0 || DimSize(w, 2) > 0 || DimSize(w, 3) > 0)
        return 0
    endif

    return 1
End

Function LJZ_EDCExtract_Is3DWave(w)
    Wave/Z w

    if (!WaveExists(w))
        return 0
    endif

    if (DimSize(w, 0) <= 0)
        return 0
    endif
    if (DimSize(w, 1) <= 0)
        return 0
    endif
    if (DimSize(w, 2) <= 0)
        return 0
    endif

    return 1
End

Function LJZ_EDCExtract_EnsureDF()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O $(LJZ_EDCExtract_BaseDF())
    NewDataFolder/O $(LJZ_EDCExtract_RunRoot())

    SVAR/Z sBase = $(LJZ_EDCExtract_BaseDF() + ":BaseDF")
    if (!SVAR_Exists(sBase))
        String/G $(LJZ_EDCExtract_BaseDF() + ":BaseDF") = "root:"
    endif

    NVAR/Z rec = $(LJZ_EDCExtract_BaseDF() + ":Recursive")
    if (!NVAR_Exists(rec))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Recursive") = 0
    endif

    SVAR/Z sWave = $(LJZ_EDCExtract_BaseDF() + ":WaveSel")
    if (!SVAR_Exists(sWave))
        String/G $(LJZ_EDCExtract_BaseDF() + ":WaveSel") = ""
    endif

    NVAR/Z k0 = $(LJZ_EDCExtract_BaseDF() + ":Kindex")
    if (!NVAR_Exists(k0))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Kindex") = 0
    endif

    NVAR/Z k1 = $(LJZ_EDCExtract_BaseDF() + ":Kxe")
    if (!NVAR_Exists(k1))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Kxe") = 0
    endif

    NVAR/Z evary = $(LJZ_EDCExtract_BaseDF() + ":evary")
    if (!NVAR_Exists(evary))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":evary") = 0.2
    endif

    SVAR/Z bn = $(LJZ_EDCExtract_BaseDF() + ":BaseName")
    if (!SVAR_Exists(bn))
        String/G $(LJZ_EDCExtract_BaseDF() + ":BaseName") = ""
    endif

    SVAR/Z runDF = $(LJZ_EDCExtract_BaseDF() + ":RunDF")
    if (!SVAR_Exists(runDF))
        String/G $(LJZ_EDCExtract_BaseDF() + ":RunDF") = ""
    endif

    NVAR/Z Run_kStart = $(LJZ_EDCExtract_BaseDF() + ":Run_kStart")
    if (!NVAR_Exists(Run_kStart))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_kStart") = NaN
    endif

    NVAR/Z Run_kEnd = $(LJZ_EDCExtract_BaseDF() + ":Run_kEnd")
    if (!NVAR_Exists(Run_kEnd))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_kEnd") = NaN
    endif

    NVAR/Z Run_t0 = $(LJZ_EDCExtract_BaseDF() + ":Run_t0")
    if (!NVAR_Exists(Run_t0))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_t0") = NaN
    endif

    NVAR/Z Run_dt = $(LJZ_EDCExtract_BaseDF() + ":Run_dt")
    if (!NVAR_Exists(Run_dt))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_dt") = NaN
    endif

    NVAR/Z Run_nT = $(LJZ_EDCExtract_BaseDF() + ":Run_nT")
    if (!NVAR_Exists(Run_nT))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_nT") = NaN
    endif

    NVAR/Z SmEnable = $(LJZ_EDCExtract_BaseDF() + ":SmEnable")
    if (!NVAR_Exists(SmEnable))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":SmEnable") = 1
    endif

    NVAR/Z SmMethod = $(LJZ_EDCExtract_BaseDF() + ":SmMethod")
    if (!NVAR_Exists(SmMethod))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":SmMethod") = 1
    endif

    NVAR/Z SmN = $(LJZ_EDCExtract_BaseDF() + ":SmN")
    if (!NVAR_Exists(SmN))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":SmN") = 11
    endif

    NVAR/Z SmN2 = $(LJZ_EDCExtract_BaseDF() + ":SmN2")
    if (!NVAR_Exists(SmN2))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":SmN2") = 7
    endif

    NVAR/Z SmS = $(LJZ_EDCExtract_BaseDF() + ":SmS")
    if (!NVAR_Exists(SmS))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":SmS") = 4
    endif

    NVAR/Z SmCutoff = $(LJZ_EDCExtract_BaseDF() + ":SmCutoff")
    if (!NVAR_Exists(SmCutoff))
        Variable/G $(LJZ_EDCExtract_BaseDF() + ":SmCutoff") = 0.18
    endif

    Wave/T/Z wDisp = $(LJZ_EDCExtract_BaseDF() + ":LB_Disp")
    if (!WaveExists(wDisp))
        Make/O/T/N=0 $(LJZ_EDCExtract_BaseDF() + ":LB_Disp")
    endif

    Wave/Z wSel = $(LJZ_EDCExtract_BaseDF() + ":LB_Sel")
    if (!WaveExists(wSel))
        Make/O/N=0 $(LJZ_EDCExtract_BaseDF() + ":LB_Sel") = 0
    endif

    return 0
End

// ============================================================================
//  Section 1. scan 3D waves
// ============================================================================

Function/S LJZ_EDCExtract_WaveShortLabel(wPath)
    String wPath

    String nm = NameOfWave($wPath)
    if (strlen(nm) == 0)
        nm = wPath
    endif

    return nm
End

Function/S LJZ_EDCExtract_List3DWaves_OneDF(dfStr)
    String dfStr

    String out = ""
    Variable iObj, nObj
    nObj = CountObjects(dfStr, 1)

    for (iObj = 0; iObj < nObj; iObj += 1)
        String nm = GetIndexedObjName(dfStr, 1, iObj)
        Wave/Z w = $(dfStr + nm)
        if (!WaveExists(w))
            continue
        endif
        if (!LJZ_EDCExtract_Is3DWave(w))
            continue
        endif

        out = AddListItem(dfStr + nm, out, ";", Inf)
    endfor

    return out
End

Function/S LJZ_EDCExtract_List3DWaves(dfStr, recursive)
    String dfStr
    Variable recursive

    dfStr = LJZ_EDCExtract_df_with_colon(dfStr)
    if (!DataFolderExists(dfStr))
        return ""
    endif

    String out = ""
    out = LJZ_EDCExtract_List3DWaves_OneDF(dfStr)

    if (!recursive)
        return out
    endif

    Variable iObj, nObj
    nObj = CountObjects(dfStr, 4)

    for (iObj = 0; iObj < nObj; iObj += 1)
        String subDF = GetIndexedObjName(dfStr, 4, iObj)
        if (strlen(subDF) == 0)
            continue
        endif
        out += LJZ_EDCExtract_List3DWaves(dfStr + subDF + ":", 1)
    endfor

    return out
End

Function/S LJZ_EDCExtract_CurrentWaveList()
    SVAR sBase = $(LJZ_EDCExtract_BaseDF() + ":BaseDF")
    NVAR rec   = $(LJZ_EDCExtract_BaseDF() + ":Recursive")
    return LJZ_EDCExtract_List3DWaves(LJZ_EDCExtract_df_with_colon(sBase), rec)
End

Function LJZ_EDCExtract_RebuildWaveList()
    LJZ_EDCExtract_EnsureDF()

    SVAR sBase = $(LJZ_EDCExtract_BaseDF() + ":BaseDF")
    NVAR rec   = $(LJZ_EDCExtract_BaseDF() + ":Recursive")
    SVAR sWave = $(LJZ_EDCExtract_BaseDF() + ":WaveSel")

    String dfStr = LJZ_EDCExtract_df_with_colon(sBase)
    if (!DataFolderExists(dfStr))
        Make/O/T/N=0 $(LJZ_EDCExtract_BaseDF() + ":LB_Disp")
        Make/O/N=0   $(LJZ_EDCExtract_BaseDF() + ":LB_Sel")
        sWave = ""
        return -1
    endif

    String listStr = LJZ_EDCExtract_List3DWaves(dfStr, rec)
    Variable n = ItemsInList(listStr, ";")

    Make/O/T/N=(n) $(LJZ_EDCExtract_BaseDF() + ":LB_Disp")
    Make/O/N=(n)   $(LJZ_EDCExtract_BaseDF() + ":LB_Sel") = 0

    Wave/T wDisp = $(LJZ_EDCExtract_BaseDF() + ":LB_Disp")
    Wave   wSel  = $(LJZ_EDCExtract_BaseDF() + ":LB_Sel")

    Variable i
    String wPath
    for (i = 0; i < n; i += 1)
        wPath = StringFromList(i, listStr, ";")
        wDisp[i] = LJZ_EDCExtract_WaveShortLabel(wPath)
    endfor

    if (n > 0)
        wSel[0] = 1
        sWave = StringFromList(0, listStr, ";")
    else
        sWave = ""
    endif

    return 0
End

Function LJZ_EDCExtract_SelectWaveRow(row)
    Variable row

    LJZ_EDCExtract_EnsureDF()

    String listStr = LJZ_EDCExtract_CurrentWaveList()
    Variable n = ItemsInList(listStr, ";")
    if (n <= 0)
        return -1
    endif

    row = max(0, min(n - 1, row))

    Wave wSel = $(LJZ_EDCExtract_BaseDF() + ":LB_Sel")
    if (numpnts(wSel) != n)
        Redimension/N=(n) wSel
    endif
    wSel = 0
    wSel[row] = 1

    SVAR sWave = $(LJZ_EDCExtract_BaseDF() + ":WaveSel")
    sWave = StringFromList(row, listStr, ";")

    return 0
End

// ============================================================================
//  Section 2. extraction kernel
// ============================================================================

Function/S LJZ_EDCExtract_MakeRunDFName(w, kStart, kEnd, tag)
    Wave w
    Variable kStart, kEnd
    String tag

    String nm = CleanupName(NameOfWave(w), 0)
    return LJZ_EDCExtract_RunRoot() + ":" + nm + "_RUN_" + tag + "_k" + num2str(kStart) + "2" + num2str(kEnd) + ":"
End

Function LJZ_EDCExtract_BuildRawEDCs(w, kStart, kEnd, runDF)
    Wave w
    Variable kStart, kEnd
    String runDF

    Variable nE = DimSize(w, 0)
    Variable nK = DimSize(w, 1)
    Variable nT = DimSize(w, 2)

    Variable e0 = DimOffset(w, 0)
    Variable de = DimDelta(w, 0)

    if (nE <= 0 || nK <= 0 || nT <= 0)
        return -1
    endif

    kStart = max(0, min(nK - 1, kStart))
    kEnd   = max(0, min(nK - 1, kEnd))
    if (kStart > kEnd)
        Variable tmp = kStart
        kStart = kEnd
        kEnd = tmp
    endif

    Variable nAvg = kEnd - kStart + 1
    if (nAvg <= 0)
        return -1
    endif

    NewDataFolder/O $(RemoveEnding(runDF, ":"))
    String oldDf = GetDataFolder(1)
    SetDataFolder $(RemoveEnding(runDF, ":"))

    Variable t, k
    for (t = 0; t < nT; t += 1)
        Make/O/N=(nE) $("edc_raw_" + num2str(t)) = 0
        Wave edc = $("edc_raw_" + num2str(t))
        SetScale/P x, e0, de, edc

        for (k = kStart; k <= kEnd; k += 1)
            edc += w[p][k][t]
        endfor

        edc /= nAvg
    endfor

    SetDataFolder $oldDf
    return 0
End

Function LJZ_EDCExtract_ApplySmoothing(runDF)
    String runDF

    NVAR SmEnable = $(LJZ_EDCExtract_BaseDF() + ":SmEnable")
    NVAR SmMethod = $(LJZ_EDCExtract_BaseDF() + ":SmMethod")
    NVAR SmN      = $(LJZ_EDCExtract_BaseDF() + ":SmN")
    NVAR SmN2     = $(LJZ_EDCExtract_BaseDF() + ":SmN2")
    NVAR SmS      = $(LJZ_EDCExtract_BaseDF() + ":SmS")
    NVAR SmCutoff = $(LJZ_EDCExtract_BaseDF() + ":SmCutoff")

    Variable t = 0
    do
        Wave/Z raw = $(runDF + "edc_raw_" + num2str(t))
        if (!WaveExists(raw))
            break
        endif

        Duplicate/O raw, $(runDF + "edc_show_" + num2str(t))
        Wave sh = $(runDF + "edc_show_" + num2str(t))

        if (SmEnable)
            Variable n1 = max(3, round(SmN))
            Variable n2 = max(3, round(SmN2))

            if (SmMethod == 1)
                Smooth n1, sh
                if (n2 >= 3)
                    Smooth n2, sh
                endif
            elseif (SmMethod == 2)
                Variable poly = round(SmS)
                if (poly < 2)
                    poly = 2
                endif
                Smooth/S=(poly) n1, sh
                if (n2 >= 3)
                    Smooth/S=(poly) n2, sh
                endif
            elseif (SmMethod == 3)
                Variable fc = min(max(SmCutoff, 0.001), 0.499)
                Smooth/BLPF fc, sh
            endif
        endif

        t += 1
    while (1)

    return 0
End

Function LJZ_EDCExtract_RecordRunMeta(w, kStart, kEnd, runDF)
    Wave w
    Variable kStart, kEnd
    String runDF

    String/G   $(LJZ_EDCExtract_BaseDF() + ":RunDF")      = runDF
    Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_kStart") = kStart
    Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_kEnd")   = kEnd
    Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_t0")     = DimOffset(w, 2)
    Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_dt")     = DimDelta(w, 2)
    Variable/G $(LJZ_EDCExtract_BaseDF() + ":Run_nT")     = DimSize(w, 2)

    return 0
End

Function LJZ_EDCExtract_PushRunDFToEDCWB(runDF)
    String runDF

    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:ARPES_LJZ
    NewDataFolder/O root:Packages:ARPES_LJZ:EDCWB
    String/G root:Packages:ARPES_LJZ:EDCWB:TargetDF = runDF

    return 0
End

Function/S LJZ_EDCExtract_BuildGraphTitle(baseName, runDF)
    String baseName, runDF

    if (strlen(baseName) > 0)
        return "EDC_Overlapping_" + CleanupName(baseName, 0)
    endif

    return "EDC_Overlapping_" + CleanupName(RemoveEnding(runDF, ":"), 0)
End

Function LJZ_EDCExtract_RebuildOverlayGraph(runDF, baseName, evary)
    String runDF, baseName
    Variable evary

    String g = LJZ_EDCExtract_GraphName()
    DoWindow/F $g
    if (V_flag == 0)
        Display/N=$g
    endif

    RemoveFromGraph/Z /W=$g *

    String oldDf = GetDataFolder(1)
    SetDataFolder $(RemoveEnding(runDF, ":"))

    Variable t = 0
    do
        Wave/Z sh = $("edc_show_" + num2str(t))
        if (!WaveExists(sh))
            break
        endif

        if (t == 0)
            AppendToGraph/W=$g sh
        else
            AppendToGraph/W=$g sh
            ModifyGraph/W=$g offset($NameOfWave(sh))={0, t * evary}
        endif

        t += 1
    while (1)

    SetDataFolder $oldDf

    ModifyGraph/W=$g mirror=1,axThick=1.2
    Label/W=$g left "Intensity (a.u.)"
    Label/W=$g bottom "Energy"
    DoWindow/T $g, LJZ_EDCExtract_BuildGraphTitle(baseName, runDF)

    return 0
End

Function/S LJZ_EDCExtract_RunFrom3DWave(w, k0, k1, baseName)
    Wave w
    Variable k0, k1
    String baseName

    LJZ_EDCExtract_EnsureDF()

    if (!WaveExists(w) || !LJZ_EDCExtract_Is3DWave(w))
        return ""
    endif

    Variable nK = DimSize(w, 1)
    if (nK <= 0)
        return ""
    endif

    Variable kStart = max(0, min(nK - 1, min(k0, k1)))
    Variable kEnd   = max(0, min(nK - 1, max(k0, k1)))

    String runDF = LJZ_EDCExtract_MakeRunDFName(w, kStart, kEnd, "EDC")
    NewDataFolder/O $(RemoveEnding(runDF, ":"))

    Variable ok
    ok = LJZ_EDCExtract_BuildRawEDCs(w, kStart, kEnd, runDF)
    if (ok != 0)
        return ""
    endif

    LJZ_EDCExtract_ApplySmoothing(runDF)
    LJZ_EDCExtract_RecordRunMeta(w, kStart, kEnd, runDF)
    LJZ_EDCExtract_PushRunDFToEDCWB(runDF)

    NVAR evary = $(LJZ_EDCExtract_BaseDF() + ":evary")
    LJZ_EDCExtract_RebuildOverlayGraph(runDF, baseName, evary)

    return runDF
End

Function LJZ_EDCExtract_ReShowCurrentRun()
    LJZ_EDCExtract_EnsureDF()

    SVAR runDF = $(LJZ_EDCExtract_BaseDF() + ":RunDF")
    SVAR bn    = $(LJZ_EDCExtract_BaseDF() + ":BaseName")
    NVAR evary = $(LJZ_EDCExtract_BaseDF() + ":evary")

    if (strlen(runDF) == 0)
        return -1
    endif
    if (!DataFolderExists(RemoveEnding(runDF, ":")))
        return -1
    endif

    LJZ_EDCExtract_ApplySmoothing(runDF)
    LJZ_EDCExtract_RebuildOverlayGraph(runDF, bn, evary)

    return 0
End

// ============================================================================
//  Section 3. user action wrappers
// ============================================================================

Function LJZ_EDCExtract_DoExtract()
    LJZ_EDCExtract_EnsureDF()

    SVAR sWave = $(LJZ_EDCExtract_BaseDF() + ":WaveSel")
    if (strlen(sWave) == 0)
        DoAlert 0, "请先选择一个 3D wave。"
        return -1
    endif

    Wave/Z w = $sWave
    if (!WaveExists(w) || !LJZ_EDCExtract_Is3DWave(w))
        DoAlert 0, "当前选择不是有效的 3D wave。"
        return -1
    endif

    NVAR k0 = $(LJZ_EDCExtract_BaseDF() + ":Kindex")
    NVAR k1 = $(LJZ_EDCExtract_BaseDF() + ":Kxe")
    SVAR bn = $(LJZ_EDCExtract_BaseDF() + ":BaseName")

    String runDF = LJZ_EDCExtract_RunFrom3DWave(w, k0, k1, bn)
    if (strlen(runDF) == 0)
        DoAlert 0, "EDC 提取失败。"
        return -1
    endif

    LJZ_EDCExtract_RefreshTitleBoxes()
    return 0
End

// ============================================================================
//  Section 4. panel
// ============================================================================

Function LJZ_EDCExtract()
    LJZ_EDCExtract_EnsureDF()
    LJZ_EDCExtract_RebuildWaveList()
    LJZ_EDCExtract_OpenPanel()
    LJZ_EDCExtract_RefreshTitleBoxes()
    return 0
End

Function LJZ_EDCExtract_OpenPanel()
    LJZ_EDCExtract_EnsureDF()

    String p = LJZ_EDCExtract_PanelName()
    DoWindow/F $p
    if (V_flag == 0)
        NewPanel/N=$p /W=(80,80,525,535)
    else
        DoWindow/F $p
        return 0
    endif

    SetVariable svBaseDF,pos={10,10},size={250,18},title="Base DF"
    SetVariable svBaseDF,value=_STR:LJZ_EDCExtract_BaseDF() + ":BaseDF",proc=LJZ_EDCExtract_SetVarProc

    CheckBox cbRecursive,pos={270,10},title="Recursive"
    CheckBox cbRecursive,variable=$(LJZ_EDCExtract_BaseDF() + ":Recursive"),proc=LJZ_EDCExtract_CheckProc

    Button btScan,pos={360,8},size={55,20},title="Scan",proc=LJZ_EDCExtract_ButtonProc

    ListBox lbWave,pos={10,40},size={210,240},listWave=$(LJZ_EDCExtract_BaseDF() + ":LB_Disp"),selWave=$(LJZ_EDCExtract_BaseDF() + ":LB_Sel"),proc=LJZ_EDCExtract_ListBoxProc

    SetVariable svK0,pos={240,50},size={150,18},title="Kindex"
    SetVariable svK0,variable=$(LJZ_EDCExtract_BaseDF() + ":Kindex"),proc=LJZ_EDCExtract_SetVarProc

    SetVariable svK1,pos={240,80},size={150,18},title="Kxe"
    SetVariable svK1,variable=$(LJZ_EDCExtract_BaseDF() + ":Kxe"),proc=LJZ_EDCExtract_SetVarProc

    SetVariable svEvary,pos={240,110},size={150,18},title="evary"
    SetVariable svEvary,variable=$(LJZ_EDCExtract_BaseDF() + ":evary"),proc=LJZ_EDCExtract_SetVarProc

    SetVariable svBaseName,pos={240,140},size={180,18},title="BaseName"
    SetVariable svBaseName,value=_STR:LJZ_EDCExtract_BaseDF() + ":BaseName",proc=LJZ_EDCExtract_SetVarProc

    Button btShowEDC,pos={240,180},size={120,26},title="Extract EDC",proc=LJZ_EDCExtract_ButtonProc
    Button btReShowEDC,pos={240,215},size={120,26},title="ReShow EDC",proc=LJZ_EDCExtract_ButtonProc

    CheckBox cbSm,pos={240,255},title="Smooth"
    CheckBox cbSm,variable=$(LJZ_EDCExtract_BaseDF() + ":SmEnable"),proc=LJZ_EDCExtract_CheckProc

    PopupMenu pmSm,pos={240,285},size={125,20},title="Method"
    PopupMenu pmSm,mode=2,popvalue="Smooth",value="0:None;1:Smooth;2:SmoothS;3:BLPF;",proc=LJZ_EDCExtract_PopupProc

    SetVariable svSmN,pos={240,315},size={150,18},title="N1"
    SetVariable svSmN,variable=$(LJZ_EDCExtract_BaseDF() + ":SmN"),proc=LJZ_EDCExtract_SetVarProc

    SetVariable svSmN2,pos={240,345},size={150,18},title="N2"
    SetVariable svSmN2,variable=$(LJZ_EDCExtract_BaseDF() + ":SmN2"),proc=LJZ_EDCExtract_SetVarProc

    SetVariable svSmS,pos={240,375},size={150,18},title="S"
    SetVariable svSmS,variable=$(LJZ_EDCExtract_BaseDF() + ":SmS"),proc=LJZ_EDCExtract_SetVarProc

    SetVariable svCut,pos={240,405},size={150,18},title="cutoff"
    SetVariable svCut,variable=$(LJZ_EDCExtract_BaseDF() + ":SmCutoff"),proc=LJZ_EDCExtract_SetVarProc

    Button btGraph,pos={240,445},size={120,24},title="Focus Graph",proc=LJZ_EDCExtract_ButtonProc

    TitleBox tbSel,pos={10,292},size={410,40},title="Selected Wave: "
    TitleBox tbRun,pos={10,342},size={410,70},title="RunDF: "

    return 0
End

Function LJZ_EDCExtract_RefreshTitleBoxes()
    SVAR sWave = $(LJZ_EDCExtract_BaseDF() + ":WaveSel")
    SVAR runDF = $(LJZ_EDCExtract_BaseDF() + ":RunDF")

    String p = LJZ_EDCExtract_PanelName()
    if (WinType(p) == 0)
        return 0
    endif

    TitleBox tbSel win=$p, title="Selected Wave: " + sWave
    TitleBox tbRun win=$p, title="RunDF: " + runDF

    return 0
End

// ============================================================================
//  Section 5. callbacks
// ============================================================================

Function LJZ_EDCExtract_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    String ctrlName = ba.ctrlName

    if (CmpStr(ctrlName, "btScan") == 0)
        LJZ_EDCExtract_RebuildWaveList()
        LJZ_EDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(ctrlName, "btShowEDC") == 0)
        LJZ_EDCExtract_DoExtract()
        return 0
    endif

    if (CmpStr(ctrlName, "btReShowEDC") == 0)
        LJZ_EDCExtract_ReShowCurrentRun()
        LJZ_EDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(ctrlName, "btGraph") == 0)
        DoWindow/F $(LJZ_EDCExtract_GraphName())
        return 0
    endif

    return 0
End

Function LJZ_EDCExtract_PopupProc(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa

    if (pa.eventCode != 2)
        return 0
    endif

    if (CmpStr(pa.ctrlName, "pmSm") == 0)
        NVAR SmMethod = $(LJZ_EDCExtract_BaseDF() + ":SmMethod")
        SmMethod = str2num(StringFromList(0, pa.popStr, ":"))
        LJZ_EDCExtract_ReShowCurrentRun()
        return 0
    endif

    return 0
End

Function LJZ_EDCExtract_SetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    if ((sva.eventCode != 1) && (sva.eventCode != 2) && (sva.eventCode != 3))
        return 0
    endif

    String ctrlName = sva.ctrlName

    if (CmpStr(ctrlName, "svBaseDF") == 0)
        LJZ_EDCExtract_RebuildWaveList()
        LJZ_EDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if ((CmpStr(ctrlName, "svSmN") == 0) || (CmpStr(ctrlName, "svSmN2") == 0) || (CmpStr(ctrlName, "svSmS") == 0) || (CmpStr(ctrlName, "svCut") == 0) || (CmpStr(ctrlName, "svEvary") == 0))
        LJZ_EDCExtract_ReShowCurrentRun()
        LJZ_EDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if ((CmpStr(ctrlName, "svK0") == 0) || (CmpStr(ctrlName, "svK1") == 0) || (CmpStr(ctrlName, "svBaseName") == 0))
        LJZ_EDCExtract_RefreshTitleBoxes()
        return 0
    endif

    return 0
End

Function LJZ_EDCExtract_CheckProc(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba

    if (cba.eventCode != 2)
        return 0
    endif

    if (CmpStr(cba.ctrlName, "cbRecursive") == 0)
        LJZ_EDCExtract_RebuildWaveList()
        LJZ_EDCExtract_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(cba.ctrlName, "cbSm") == 0)
        LJZ_EDCExtract_ReShowCurrentRun()
        return 0
    endif

    return 0
End

Function LJZ_EDCExtract_ListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if ((lba.eventCode != 1) && (lba.eventCode != 4))
        return 0
    endif

    if (CmpStr(lba.ctrlName, "lbWave") == 0)
        if (lba.row >= 0)
            LJZ_EDCExtract_SelectWaveRow(lba.row)
            LJZ_EDCExtract_RefreshTitleBoxes()
        endif
    endif

    return 0
End
