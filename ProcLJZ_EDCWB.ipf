#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  LJZ_EDCWB Part 1 : Core + Result Record
//  只负责：
//    1) package runtime state
//    2) per-wave standard fit record read/write
//    3) EDC listing helpers
//
//  本部分不负责：
//    - panel / callbacks
//    - fit engine
//    - export
//    - model bank
//    - fitmeta 文本主存储
// ============================================================================

Menu "ARPES_LJZ"
    "EDC Fit Panel", EDCFit_LJZ()
End


// ============================================================================
//  EDCFIT : panel + state + scan + show EDC
//  依赖：
//    1) LJZ_MakeRunDFName(w, start, end, tag)
//    2) LJZ_ApplySmoothing_All(runDF)
//    3) 若你已加入 EDCWB，则可用 Open EDCWB
// ============================================================================

// ============================================================================
//  Section 0. Shared path helpers
// ============================================================================

Function/S LJZ_EDCWB_BaseDF()
    return "root:Packages:ARPES_LJZ:EDCWB"
End

Function/S LJZ_EDCWB_NormDFPath(df)
    String df

    if (strlen(df) == 0)
        return ""
    endif

    df = RemoveEnding(df, ":") + ":"
    if (!DataFolderExists(df))
        return ""
    endif

    return df
End

Function/S LJZ_EDCWB_WaveNameFromPath(wPath)
    String wPath

    Variable n = ItemsInList(wPath, ":")
    if (n < 2)
        return ""
    endif

    return StringFromList(n - 1, wPath, ":")
End


Function/S EDCFIT_MakeRunDFName(w, kStart, kEnd, tag)
    Wave w
    Variable kStart, kEnd
    String tag

    String nm = CleanupName(NameOfWave(w), 0)
    return "root:ARPES_LJZ:EDCFit:" + nm + "_RUN_" + tag + "_k" + Num2Str(kStart) + "2" + Num2Str(kEnd) + ":"
End

Function/S LJZ_EDCWB_WaveDFFromPath(wPath)
    String wPath

    Variable n = ItemsInList(wPath, ":")
    if (n < 2)
        return ""
    endif

    Variable i
    String df = ""
    for (i = 0; i < n - 1; i += 1)
        df += StringFromList(i, wPath, ":") + ":"
    endfor

    return df
End

Function LJZ_EDCWB_Is1DWave(w)
    Wave/Z w

    if (!WaveExists(w))
        return 0
    endif

    return (WaveDims(w) == 1)
End

Function LJZ_EDCWB_EnsureNumWaveLen12(w, fillVal)
    Wave w
    Variable fillVal

    Variable oldN = numpnts(w)
    if (oldN != 12)
        Redimension/N=12 w
        if (oldN < 12)
            w[oldN, 11] = fillVal
        endif
    endif

    return 0
End

Function LJZ_EDCWB_EnsureTextWaveLen12(w, fillStr)
    Wave/T w
    String fillStr

    Variable oldN = numpnts(w)
    if (oldN != 12)
        Redimension/N=12 w
        if (oldN < 12)
            w[oldN, 11] = fillStr
        endif
    endif

    return 0
End

Function LJZ_EDCWB_EnsureNumWaveLen16(w, fillVal)
    Wave w
    Variable fillVal

    Variable oldN = numpnts(w)
    if (oldN != 16)
        Redimension/N=16 w
        if (oldN < 16)
            w[oldN, 15] = fillVal
        endif
    endif

    return 0
End
// ============================================================================
//  Section 0. Base state
// ============================================================================

Function LJZ_EnsureEDCFitDF()
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:EDCFit

    SVAR/Z sBase = root:ARPES_LJZ:EDCFit:BaseDF
    if (!SVAR_Exists(sBase))
        String/G root:ARPES_LJZ:EDCFit:BaseDF = "root:"
    endif

    NVAR/Z rec = root:ARPES_LJZ:EDCFit:Recursive
    if (!NVAR_Exists(rec))
        Variable/G root:ARPES_LJZ:EDCFit:Recursive = 0
    endif

    SVAR/Z sWave = root:ARPES_LJZ:EDCFit:EDCWaveSel
    if (!SVAR_Exists(sWave))
        String/G root:ARPES_LJZ:EDCFit:EDCWaveSel = ""
    endif

    NVAR/Z Kindex = root:ARPES_LJZ:EDCFit:Kindex
    if (!NVAR_Exists(Kindex))
        Variable/G root:ARPES_LJZ:EDCFit:Kindex = 0
    endif

    NVAR/Z Kxe = root:ARPES_LJZ:EDCFit:Kxe
    if (!NVAR_Exists(Kxe))
        Variable/G root:ARPES_LJZ:EDCFit:Kxe = 0
    endif

    NVAR/Z evary = root:ARPES_LJZ:EDCFit:evary
    if (!NVAR_Exists(evary))
        Variable/G root:ARPES_LJZ:EDCFit:evary = 0.2
    endif

    SVAR/Z bn = root:ARPES_LJZ:EDCFit:gBaseName
    if (!SVAR_Exists(bn))
        String/G root:ARPES_LJZ:EDCFit:gBaseName = ""
    endif

    SVAR/Z runDF = root:ARPES_LJZ:EDCFit:RunDF
    if (!SVAR_Exists(runDF))
        String/G root:ARPES_LJZ:EDCFit:RunDF = ""
    endif

    NVAR/Z Run_kStart = root:ARPES_LJZ:EDCFit:Run_kStart
    if (!NVAR_Exists(Run_kStart))
        Variable/G root:ARPES_LJZ:EDCFit:Run_kStart = NaN
    endif

    NVAR/Z Run_kEnd = root:ARPES_LJZ:EDCFit:Run_kEnd
    if (!NVAR_Exists(Run_kEnd))
        Variable/G root:ARPES_LJZ:EDCFit:Run_kEnd = NaN
    endif

    NVAR/Z Run_t0 = root:ARPES_LJZ:EDCFit:Run_t0
    if (!NVAR_Exists(Run_t0))
        Variable/G root:ARPES_LJZ:EDCFit:Run_t0 = NaN
    endif

    NVAR/Z Run_dt = root:ARPES_LJZ:EDCFit:Run_dt
    if (!NVAR_Exists(Run_dt))
        Variable/G root:ARPES_LJZ:EDCFit:Run_dt = NaN
    endif

    Wave/T/Z wDisp = root:ARPES_LJZ:EDCFit:LB_Disp
    if (!WaveExists(wDisp))
        Make/O/T/N=0 root:ARPES_LJZ:EDCFit:LB_Disp
    endif

    Wave/Z wSel = root:ARPES_LJZ:EDCFit:LB_Sel
    if (!WaveExists(wSel))
        Make/O/N=0 root:ARPES_LJZ:EDCFit:LB_Sel = 0
    endif
    NVAR/Z SmEnable = root:ARPES_LJZ:EDCFit:SmEnable
    if (!NVAR_Exists(SmEnable))
        Variable/G root:ARPES_LJZ:EDCFit:SmEnable = 1
    endif

    NVAR/Z SmMethod = root:ARPES_LJZ:EDCFit:SmMethod
    if (!NVAR_Exists(SmMethod))
        Variable/G root:ARPES_LJZ:EDCFit:SmMethod = 1
    endif

    NVAR/Z SmN = root:ARPES_LJZ:EDCFit:SmN
    if (!NVAR_Exists(SmN))
        Variable/G root:ARPES_LJZ:EDCFit:SmN = 11
    endif

    NVAR/Z SmN2 = root:ARPES_LJZ:EDCFit:SmN2
    if (!NVAR_Exists(SmN2))
        Variable/G root:ARPES_LJZ:EDCFit:SmN2 = 7
    endif

    NVAR/Z SmS = root:ARPES_LJZ:EDCFit:SmS
    if (!NVAR_Exists(SmS))
        Variable/G root:ARPES_LJZ:EDCFit:SmS = 4
    endif

    NVAR/Z SmCutoff = root:ARPES_LJZ:EDCFit:SmCutoff
    if (!NVAR_Exists(SmCutoff))
        Variable/G root:ARPES_LJZ:EDCFit:SmCutoff = 0.18
    endif
    return 0
End

Function EDCFIT_ApplySmoothing_All(runDF)
    String runDF

    NVAR SmEnable = root:ARPES_LJZ:EDCFit:SmEnable
    NVAR SmMethod = root:ARPES_LJZ:EDCFit:SmMethod
    NVAR SmN      = root:ARPES_LJZ:EDCFit:SmN
    NVAR SmN2     = root:ARPES_LJZ:EDCFit:SmN2
    NVAR SmS      = root:ARPES_LJZ:EDCFit:SmS
    NVAR SmCutoff = root:ARPES_LJZ:EDCFit:SmCutoff

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
                if (SmN2 >= 3)
                    Smooth n2, sh
                endif
            elseif (SmMethod == 2)
                Variable sg = (SmS <= 2) ? 2 : 4
                Smooth/S=(sg) n1, sh
                if (SmN2 >= 3)
                    Smooth/S=(sg) n2, sh
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

Function/S EDCFIT_df_with_colon(inStr)
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

Function EDCFIT_df_exists(dfStr)
    String dfStr
    String s = EDCFIT_df_with_colon(dfStr)
    return DataFolderExists(s)
End

Function/S EDCFIT_PanelName()
    return "EDCFit_LJZ_Panel"
End


// ============================================================================
//  Section 1. 3D wave scan
// ============================================================================

Function EDCFIT_Is3DWave(w)
    Wave/Z w

    if (!WaveExists(w))
        return 0
    endif

    return (WaveDims(w) == 3)
End

Function/S EDCFIT_WaveShortLabel(wPath)
    String wPath

    String nm = NameOfWave($wPath)
    if (strlen(nm) == 0)
        nm = wPath
    endif

    return nm
End

Function/S EDCFIT_List3DWaves_OneDF(dfStr)
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
        if (!EDCFIT_Is3DWave(w))
            continue
        endif

        out = AddListItem(dfStr + nm, out, ";", Inf)
    endfor

    return out
End

Function/S EDCFIT_List3DWaves(dfStr, recursive)
    String dfStr
    Variable recursive

    dfStr = EDCFIT_df_with_colon(dfStr)
    if (!DataFolderExists(dfStr))
        return ""
    endif

    String out = ""
    out = EDCFIT_List3DWaves_OneDF(dfStr)

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

        out += EDCFIT_List3DWaves(dfStr + subDF + ":", 1)
    endfor

    return out
End

Function EDCFIT_RebuildWaveList()
    LJZ_EnsureEDCFitDF()

    SVAR sBase = root:ARPES_LJZ:EDCFit:BaseDF
    NVAR rec   = root:ARPES_LJZ:EDCFit:Recursive
    SVAR sWave = root:ARPES_LJZ:EDCFit:EDCWaveSel

    String dfStr = EDCFIT_df_with_colon(sBase)
    if (!DataFolderExists(dfStr))
        Make/O/T/N=0 root:ARPES_LJZ:EDCFit:LB_Disp
        Make/O/N=0 root:ARPES_LJZ:EDCFit:LB_Sel
        sWave = ""
        return -1
    endif

    String listStr = EDCFIT_List3DWaves(dfStr, rec)
    Variable n = ItemsInList(listStr, ";")

    Make/O/T/N=(n) root:ARPES_LJZ:EDCFit:LB_Disp
    Make/O/N=(n)   root:ARPES_LJZ:EDCFit:LB_Sel = 0

    Wave/T wDisp = root:ARPES_LJZ:EDCFit:LB_Disp
    Wave   wSel  = root:ARPES_LJZ:EDCFit:LB_Sel

    Variable i
    String wPath
    for (i = 0; i < n; i += 1)
        wPath = StringFromList(i, listStr, ";")
        wDisp[i] = EDCFIT_WaveShortLabel(wPath)
    endfor

    if (n > 0)
        wSel[0] = 1
        sWave = StringFromList(0, listStr, ";")
    else
        sWave = ""
    endif

    return 0
End

Function/S EDCFIT_CurrentWaveList()
    SVAR sBase = root:ARPES_LJZ:EDCFit:BaseDF
    NVAR rec   = root:ARPES_LJZ:EDCFit:Recursive
    return EDCFIT_List3DWaves(EDCFIT_df_with_colon(sBase), rec)
End

Function EDCFIT_SelectWaveRow(row)
    Variable row

    LJZ_EnsureEDCFitDF()

    String listStr = EDCFIT_CurrentWaveList()
    Variable n = ItemsInList(listStr, ";")
    if (n <= 0)
        return -1
    endif

    row = max(0, min(n - 1, row))

    Wave wSel = root:ARPES_LJZ:EDCFit:LB_Sel
    if (numpnts(wSel) != n)
        Redimension/N=(n) wSel
    endif
    wSel = 0
    wSel[row] = 1

    SVAR sWave = root:ARPES_LJZ:EDCFit:EDCWaveSel
    sWave = StringFromList(row, listStr, ";")

    return 0
End


// ============================================================================
//  Section 2. Show EDC
//  默认维度约定：w[E][K][T]
// ============================================================================

Function EDCPF_ShowEDC_LJZ(ctrlName) : ButtonControl
    String ctrlName

    LJZ_EnsureEDCFitDF()

    SVAR/Z sWave = root:ARPES_LJZ:EDCFit:EDCWaveSel
    if (!SVAR_Exists(sWave) || strlen(sWave) == 0)
        DoAlert 0, "请先选择一个 3D 波形。"
        return -1
    endif

    Wave/Z w = $sWave
    if (!WaveExists(w) || !EDCFIT_Is3DWave(w))
        DoAlert 0, "无效的 3D 波形: " + sWave
        return -1
    endif

    NVAR Kindex = root:ARPES_LJZ:EDCFit:Kindex
    NVAR Kxe    = root:ARPES_LJZ:EDCFit:Kxe
    NVAR evary  = root:ARPES_LJZ:EDCFit:evary

    Variable nE = DimSize(w, 0)
    Variable nK = DimSize(w, 1)
    Variable nT = DimSize(w, 2)

    Variable e0 = DimOffset(w, 0)
    Variable de = DimDelta(w, 0)

    Variable kStart = max(0, min(nK - 1, min(Kindex, Kxe)))
    Variable kEnd   = max(0, min(nK - 1, max(Kindex, Kxe)))
    Variable nAvg   = kEnd - kStart + 1

    String runDF = EDCFIT_MakeRunDFName(w, kStart, kEnd, "EDC")
    NewDataFolder/O $(RemoveEnding(runDF, ":"))
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

    SetDataFolder root:
    EDCFIT_ApplySmoothing_All(runDF)

    SVAR bn = root:ARPES_LJZ:EDCFit:gBaseName
    String bnTag = bn
    if (strlen(bnTag) == 0)
        bnTag = NameOfWave(w)
    endif

    String wNameBase = "EDC_Overlapping_" + CleanupName(bnTag, 0)
    KillWindow/Z $wNameBase
    String wOlap = wNameBase

    SetDataFolder $(RemoveEnding(runDF, ":"))
    for (t = 0; t < nT; t += 1)
        Wave/Z sh = $("edc_show_" + num2str(t))
        if (!WaveExists(sh))
            break
        endif

        if (t == 0)
            Display/N=$wOlap sh
            Label left, "Intensity (a.u.)"
            Label bottom, "Energy"
        else
            AppendToGraph sh
            ModifyGraph offset($NameOfWave(sh)) = {0, t * evary}
        endif
    endfor
    SetDataFolder root:

    String/G   root:ARPES_LJZ:EDCFit:RunDF      = runDF
    Variable/G root:ARPES_LJZ:EDCFit:Run_kStart = kStart
    Variable/G root:ARPES_LJZ:EDCFit:Run_kEnd   = kEnd
    Variable/G root:ARPES_LJZ:EDCFit:Run_t0     = DimOffset(w, 2)
    Variable/G root:ARPES_LJZ:EDCFit:Run_dt     = DimDelta(w, 2)

    // 自动把 EDCWB 指向这个 runDF
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:ARPES_LJZ
    NewDataFolder/O root:Packages:ARPES_LJZ:EDCWB
    String/G root:Packages:ARPES_LJZ:EDCWB:TargetDF = runDF

    return 0
End
Function EDCFIT_ReShowCurrentEDC()
    LJZ_EnsureEDCFitDF()

    SVAR runDF = root:ARPES_LJZ:EDCFit:RunDF
    NVAR evary = root:ARPES_LJZ:EDCFit:evary
    if (strlen(runDF) == 0)
        return -1
    endif

    EDCFIT_ApplySmoothing_All(runDF)

    SVAR bn = root:ARPES_LJZ:EDCFit:gBaseName
    String bnTag = bn
    if (strlen(bnTag) == 0)
        bnTag = runDF
    endif

    String wNameBase = "EDC_Overlapping_" + CleanupName(bnTag, 0)
    KillWindow/Z $wNameBase

    SetDataFolder $(RemoveEnding(runDF, ":"))

    Variable t = 0
    do
        Wave/Z sh = $("edc_show_" + num2str(t))
        if (!WaveExists(sh))
            break
        endif

        if (t == 0)
            Display/N=$wNameBase sh
            Label left, "Intensity (a.u.)"
            Label bottom, "Energy"
        else
            AppendToGraph sh
            ModifyGraph offset($NameOfWave(sh)) = {0, t * evary}
        endif

        t += 1
    while (1)

    SetDataFolder root:
    return 0
End

// ============================================================================
//  Section 3. Panel
// ============================================================================

Function EDCFit_LJZ()
    LJZ_EnsureEDCFitDF()
    EDCFIT_RebuildWaveList()
    EDCFit_OpenPanel()
    return 0
End

Function EDCFit_OpenPanel()
    LJZ_EnsureEDCFitDF()

    String p = EDCFIT_PanelName()
    if (WinType(p) != 0)
        DoWindow/F $p
        return 0
    endif
    KillWindow/Z $p
    NewPanel/N=$p /W=(80,80,510,520)

    SetVariable svBaseDF,pos={10,10},size={250,18},title="Base DF"
    SetVariable svBaseDF,value=_STR:"root:ARPES_LJZ:EDCFit:BaseDF",proc=EDCFIT_SetVarProc

    CheckBox cbRecursive,pos={270,10},title="Recursive"
    CheckBox cbRecursive,variable=root:ARPES_LJZ:EDCFit:Recursive,proc=EDCFIT_CheckProc

    Button btScan,pos={360,8},size={55,20},title="Scan",proc=EDCFIT_ButtonProc

    ListBox lbWave,pos={10,40},size={210,240},listWave=root:ARPES_LJZ:EDCFit:LB_Disp,selWave=root:ARPES_LJZ:EDCFit:LB_Sel,proc=EDCFIT_ListBoxProc

    SetVariable svK0,pos={240,50},size={150,18},title="Kindex"
    SetVariable svK0,variable=root:ARPES_LJZ:EDCFit:Kindex,proc=EDCFIT_SetVarProc

    SetVariable svK1,pos={240,80},size={150,18},title="Kxe"
    SetVariable svK1,variable=root:ARPES_LJZ:EDCFit:Kxe,proc=EDCFIT_SetVarProc

    SetVariable svEvary,pos={240,110},size={150,18},title="evary"
    SetVariable svEvary,variable=root:ARPES_LJZ:EDCFit:evary,proc=EDCFIT_SetVarProc

    SetVariable svBaseName,pos={240,140},size={170,18},title="BaseName"
    SetVariable svBaseName,value=_STR:"root:ARPES_LJZ:EDCFit:gBaseName",proc=EDCFIT_SetVarProc

    Button btShowEDC,pos={240,180},size={120,26},title="Show EDC",proc=EDCFIT_ButtonProc
    Button btOpenWB,pos={240,215},size={120,26},title="Open EDCWB",proc=EDCFIT_ButtonProc
    CheckBox cbSm,pos={240,255},title="Smooth",variable=root:ARPES_LJZ:EDCFit:SmEnable,proc=EDCFIT_CheckProc

    PopupMenu pmSm,pos={240,285},size={120,20},title="Method"
    PopupMenu pmSm,mode=2,popvalue="Smooth",value="0:None;1:Smooth;2:SmoothS;3:BLPF;",proc=EDCFIT_PopupProc

    SetVariable svSmN,pos={240,315},size={150,18},title="N1"
    SetVariable svSmN,variable=root:ARPES_LJZ:EDCFit:SmN,proc=EDCFIT_SetVarProc

    SetVariable svSmN2,pos={240,345},size={150,18},title="N2"
    SetVariable svSmN2,variable=root:ARPES_LJZ:EDCFit:SmN2,proc=EDCFIT_SetVarProc

    SetVariable svSmS,pos={240,375},size={150,18},title="S"
    SetVariable svSmS,variable=root:ARPES_LJZ:EDCFit:SmS,proc=EDCFIT_SetVarProc

    SetVariable svCut,pos={240,405},size={150,18},title="cutoff"
    SetVariable svCut,variable=root:ARPES_LJZ:EDCFit:SmCutoff,proc=EDCFIT_SetVarProc

    Button btReShowEDC,pos={240,445},size={120,24},title="ReShow EDC",proc=EDCFIT_ButtonProc
    TitleBox tbSel,pos={10,292},size={390,40},title="Selected Wave: "
    TitleBox tbRun,pos={10,342},size={390,60},title="RunDF: "

    EDCFIT_RefreshTitleBoxes()

    return 0
End

Function EDCFIT_RefreshTitleBoxes()
    SVAR sWave = root:ARPES_LJZ:EDCFit:EDCWaveSel
    SVAR runDF = root:ARPES_LJZ:EDCFit:RunDF

    String p = EDCFIT_PanelName()
    if (WinType(p) == 0)
        return 0
    endif

    TitleBox tbSel win=$p, title="Selected Wave: " + sWave
    TitleBox tbRun win=$p, title="RunDF: " + runDF

    return 0
End


// ============================================================================
//  Section 4. Panel callbacks
// ============================================================================

Function EDCFIT_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    String ctrlName = ba.ctrlName

    if (CmpStr(ctrlName, "btScan") == 0)
        EDCFIT_RebuildWaveList()
        EDCFIT_RefreshTitleBoxes()
        return 0
    endif
    if (CmpStr(ctrlName, "btReShowEDC") == 0)
        EDCFIT_ReShowCurrentEDC()
        return 0
    endif
    if (CmpStr(ctrlName, "btShowEDC") == 0)
        EDCPF_ShowEDC_LJZ(ctrlName)
        EDCFIT_RefreshTitleBoxes()
        return 0
    endif

    if (CmpStr(ctrlName, "btOpenWB") == 0)
        if (Exists("LJZ_EDCWB") == 6)
            Execute "LJZ_EDCWB()"
        else
            DoAlert 0, "还没有加载 LJZ_EDCWB。"
        endif
        return 0
    endif

    return 0
End

Function EDCFIT_PopupProc(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa

    if (pa.eventCode != 2)
        return 0
    endif

    String ctrlName = pa.ctrlName
    String popStr   = pa.popStr

    if (CmpStr(ctrlName, "pmSm") == 0)
        NVAR SmMethod = root:ARPES_LJZ:EDCFit:SmMethod
        SmMethod = pa.popNum - 1
        EDCFIT_ReShowCurrentEDC()
        return 0
    endif

    return 0
End
Function EDCFIT_SetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    if ((sva.eventCode != 1) && (sva.eventCode != 2) && (sva.eventCode != 3))
        return 0
    endif

    String ctrlName = sva.ctrlName

    if (CmpStr(ctrlName, "svBaseDF") == 0)
        EDCFIT_RebuildWaveList()
        EDCFIT_RefreshTitleBoxes()
        return 0
    endif
    if ((CmpStr(ctrlName, "svSmN") == 0) || (CmpStr(ctrlName, "svSmN2") == 0) || (CmpStr(ctrlName, "svSmS") == 0) || (CmpStr(ctrlName, "svCut") == 0) || (CmpStr(ctrlName, "svEvary") == 0))
        EDCFIT_ReShowCurrentEDC()
        EDCFIT_RefreshTitleBoxes()
        return 0
    endif
    if ((CmpStr(ctrlName, "svK0") == 0) || (CmpStr(ctrlName, "svK1") == 0) || (CmpStr(ctrlName, "svBaseName") == 0))
        EDCFIT_RefreshTitleBoxes()
        return 0
    endif

    return 0
End

Function EDCFIT_CheckProc(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba

    if (cba.eventCode != 2)
        return 0
    endif

    String ctrlName = cba.ctrlName

    if (CmpStr(ctrlName, "cbRecursive") == 0)
        EDCFIT_RebuildWaveList()
        EDCFIT_RefreshTitleBoxes()
        return 0
    endif
    if (CmpStr(ctrlName, "cbSm") == 0)
        EDCFIT_ReShowCurrentEDC()
        return 0
    endif
    return 0
End

Function EDCFIT_ListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if ((lba.eventCode != 1) && (lba.eventCode != 4))
        return 0
    endif

    if (CmpStr(lba.ctrlName, "lbWave") == 0)
        if (lba.row >= 0)
            EDCFIT_SelectWaveRow(lba.row)
            EDCFIT_RefreshTitleBoxes()
        endif
    endif

    return 0
End


// ============================================================================
//  Section 1. fitinfo schema indices
// ============================================================================

Function LJZ_EDCWB_FI_ModelID()
    return 0
End

Function LJZ_EDCWB_FI_XLo()
    return 1
End

Function LJZ_EDCWB_FI_XHi()
    return 2
End

Function LJZ_EDCWB_FI_FitOK()
    return 3
End

Function LJZ_EDCWB_FI_GuessRMSE()
    return 4
End

Function LJZ_EDCWB_FI_FitRMSE()
    return 5
End

Function LJZ_EDCWB_FI_ChiSq()
    return 6
End

Function LJZ_EDCWB_FI_MaxAbsRes()
    return 7
End

Function LJZ_EDCWB_FI_NROI()
    return 8
End

Function LJZ_EDCWB_FI_Temperature()
    return 9
End

Function LJZ_EDCWB_FI_Resolution()
    return 10
End

Function LJZ_EDCWB_FI_EFermi()
    return 11
End

Function LJZ_EDCWB_FI_NormMode()
    return 12
End

Function LJZ_EDCWB_FI_SmoothUsed()
    return 13
End

Function LJZ_EDCWB_FI_Reserved14()
    return 14
End

Function LJZ_EDCWB_FI_Reserved15()
    return 15
End


// ============================================================================
//  Section 2. Package runtime state
// ============================================================================

Function LJZ_EDCWB_EnsureDF()
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:ARPES_LJZ
    NewDataFolder/O $(RemoveEnding(LJZ_EDCWB_BaseDF(), ":"))

    LJZ_EDCWB_EnsureRuntimeState()

    return 0
End

Function LJZ_EDCWB_EnsureRuntimeState()
    String base = LJZ_EDCWB_BaseDF()

    // ---------- current target / selection ----------
    SVAR/Z sTarget = $(base + ":TargetDF")
    if (!SVAR_Exists(sTarget))
        String/G $(base + ":TargetDF") = ""
    endif

    NVAR/Z curRow = $(base + ":CurRow")
    if (!NVAR_Exists(curRow))
        Variable/G $(base + ":CurRow") = -1
    endif

    SVAR/Z curWavePath = $(base + ":CurWavePath")
    if (!SVAR_Exists(curWavePath))
        String/G $(base + ":CurWavePath") = ""
    endif

    // ---------- current edit state ----------
    NVAR/Z eModel = $(base + ":EditModelID")
    if (!NVAR_Exists(eModel))
        Variable/G $(base + ":EditModelID") = 1
    endif

    NVAR/Z eXLo = $(base + ":EditXLo")
    if (!NVAR_Exists(eXLo))
        Variable/G $(base + ":EditXLo") = NaN
    endif

    NVAR/Z eXHi = $(base + ":EditXHi")
    if (!NVAR_Exists(eXHi))
        Variable/G $(base + ":EditXHi") = NaN
    endif

    NVAR/Z useCsr = $(base + ":UseCursors")
    if (!NVAR_Exists(useCsr))
        Variable/G $(base + ":UseCursors") = 1
    endif

    NVAR/Z isDirty = $(base + ":Dirty")
    if (!NVAR_Exists(isDirty))
        Variable/G $(base + ":Dirty") = 1
    endif

    // ---------- EDC display / preprocess state ----------
    NVAR/Z smEn = $(base + ":SmoothEnable")
    if (!NVAR_Exists(smEn))
        Variable/G $(base + ":SmoothEnable") = 0
    endif

    NVAR/Z smMethod = $(base + ":SmoothMethod")
    if (!NVAR_Exists(smMethod))
        Variable/G $(base + ":SmoothMethod") = 0
    endif

    NVAR/Z smP1 = $(base + ":SmoothParam1")
    if (!NVAR_Exists(smP1))
        Variable/G $(base + ":SmoothParam1") = 5
    endif

    NVAR/Z smP2 = $(base + ":SmoothParam2")
    if (!NVAR_Exists(smP2))
        Variable/G $(base + ":SmoothParam2") = 2
    endif

    NVAR/Z shRaw = $(base + ":ShowRaw")
    if (!NVAR_Exists(shRaw))
        Variable/G $(base + ":ShowRaw") = 1
    endif

    NVAR/Z shSm = $(base + ":ShowSmooth")
    if (!NVAR_Exists(shSm))
        Variable/G $(base + ":ShowSmooth") = 0
    endif

    NVAR/Z shGuess = $(base + ":ShowGuess")
    if (!NVAR_Exists(shGuess))
        Variable/G $(base + ":ShowGuess") = 1
    endif

    NVAR/Z shFit = $(base + ":ShowFit")
    if (!NVAR_Exists(shFit))
        Variable/G $(base + ":ShowFit") = 1
    endif

    NVAR/Z shRes = $(base + ":ShowResidual")
    if (!NVAR_Exists(shRes))
        Variable/G $(base + ":ShowResidual") = 1
    endif

    NVAR/Z smGuess = $(base + ":UseSmoothForGuess")
    if (!NVAR_Exists(smGuess))
        Variable/G $(base + ":UseSmoothForGuess") = 1
    endif

    NVAR/Z fitOnSm = $(base + ":FitOnSmooth")
    if (!NVAR_Exists(fitOnSm))
        Variable/G $(base + ":FitOnSmooth") = 0
    endif

    // ---------- physical aux state ----------
    NVAR/Z eTemp = $(base + ":EditTemperature")
    if (!NVAR_Exists(eTemp))
        Variable/G $(base + ":EditTemperature") = 10
    endif

    NVAR/Z eEF = $(base + ":EditEFermi")
    if (!NVAR_Exists(eEF))
        Variable/G $(base + ":EditEFermi") = 0
    endif

    NVAR/Z eRes = $(base + ":EditResolution")
    if (!NVAR_Exists(eRes))
        Variable/G $(base + ":EditResolution") = 0.01
    endif

    NVAR/Z eNorm = $(base + ":EditNormMode")
    if (!NVAR_Exists(eNorm))
        Variable/G $(base + ":EditNormMode") = 0
    endif

    // ---------- param edit waves ----------
    Wave/Z wPar = $(base + ":EditPar")
    if (!WaveExists(wPar))
        Make/O/N=12 $(base + ":EditPar") = NaN
    else
        LJZ_EDCWB_EnsureNumWaveLen12(wPar, NaN)
    endif

    Wave/Z wHold = $(base + ":EditHold")
    if (!WaveExists(wHold))
        Make/O/N=12 $(base + ":EditHold") = 0
    else
        LJZ_EDCWB_EnsureNumWaveLen12(wHold, 0)
    endif

    Wave/T/Z wPName = $(base + ":EditParName")
    if (!WaveExists(wPName))
        Make/O/T/N=12 $(base + ":EditParName") = ""
    else
        LJZ_EDCWB_EnsureTextWaveLen12(wPName, "")
    endif

    Wave/Z wPEn = $(base + ":EditParEnable")
    if (!WaveExists(wPEn))
        Make/O/N=12 $(base + ":EditParEnable") = 0
    else
        LJZ_EDCWB_EnsureNumWaveLen12(wPEn, 0)
    endif

    return 0
End


// ============================================================================
//  Section 3. Runtime state helpers
// ============================================================================

Function LJZ_EDCWB_MarkDirty(flag)
    Variable flag
    NVAR isDirty = $(LJZ_EDCWB_BaseDF() + ":Dirty")
    isDirty = flag
    return 0
End

Function LJZ_EDCWB_IsDirty()
    NVAR isDirty = $(LJZ_EDCWB_BaseDF() + ":Dirty")
    return isDirty
End

Function LJZ_EDCWB_ClearEditState()
    LJZ_EDCWB_EnsureDF()

    NVAR eModel = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR eXLo   = $(LJZ_EDCWB_BaseDF() + ":EditXLo")
    NVAR eXHi   = $(LJZ_EDCWB_BaseDF() + ":EditXHi")

    NVAR eTemp  = $(LJZ_EDCWB_BaseDF() + ":EditTemperature")
    NVAR eEF    = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    NVAR eRes   = $(LJZ_EDCWB_BaseDF() + ":EditResolution")
    NVAR eNorm  = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")

    Wave ePar   = $(LJZ_EDCWB_BaseDF() + ":EditPar")
    Wave eHold  = $(LJZ_EDCWB_BaseDF() + ":EditHold")
    Wave/T pName = $(LJZ_EDCWB_BaseDF() + ":EditParName")
    Wave pEn     = $(LJZ_EDCWB_BaseDF() + ":EditParEnable")

    eModel = 1
    eXLo   = NaN
    eXHi   = NaN

    eTemp  = 10
    eEF    = 0
    eRes   = 0.01
    eNorm  = 0

    ePar   = NaN
    eHold  = 0
    pName  = ""
    pEn    = 0

    LJZ_EDCWB_MarkDirty(1)
    return 0
End

Function LJZ_EDCWB_SetCurrentWave(wPath, row)
    String wPath
    Variable row

    LJZ_EDCWB_EnsureDF()

    SVAR sPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR nRow  = $(LJZ_EDCWB_BaseDF() + ":CurRow")

    sPath = wPath
    nRow  = row

    LJZ_EDCWB_MarkDirty(0)
    return 0
End


// ============================================================================
//  Section 4. EDC listing helpers
// ============================================================================

Function/S LJZ_EDCWB_ListEDCWaves(dfPath)
    String dfPath

    dfPath = LJZ_EDCWB_NormDFPath(dfPath)
    if (strlen(dfPath) == 0)
        return ""
    endif

    String out = ""

    // 优先按 edc_show_0,1,2,... 顺序列
    Wave/Z w0 = $(dfPath + "edc_show_0")
    if (WaveExists(w0))
        Variable k = 0
        do
            Wave/Z wk = $(dfPath + "edc_show_" + Num2Str(k))
            if (!WaveExists(wk))
                break
            endif
            if (LJZ_EDCWB_Is1DWave(wk))
                out = AddListItem(dfPath + NameOfWave(wk), out, ";", Inf)
            endif
            k += 1
        while (1)

        return out
    endif

    // 否则扫描 1D wave 名字里含 edc 的对象
    Variable iObj, nObj
    nObj = CountObjects(dfPath, 1)

    for (iObj = 0; iObj < nObj; iObj += 1)
        String nm = GetIndexedObjName(dfPath, 1, iObj)
        Wave/Z w = $(dfPath + nm)
        if (!WaveExists(w))
            continue
        endif

        if (!LJZ_EDCWB_Is1DWave(w))
            continue
        endif

        if (StringMatch(LowerStr(nm), "*edc*"))
            out = AddListItem(dfPath + nm, out, ";", Inf)
        endif
    endfor

    return out
End


// ============================================================================
//  Section 5. Result record naming helpers
// ============================================================================

Function/S LJZ_EDCWB_ResultBaseName(srcWavePath)
    String srcWavePath

    String nm = LJZ_EDCWB_WaveNameFromPath(srcWavePath)
    if (strlen(nm) == 0)
        return ""
    endif

    return nm
End

Function/S LJZ_EDCWB_ResultGuessPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_guess"
End

Function/S LJZ_EDCWB_ResultFitCoefPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_fitcoef"
End

Function/S LJZ_EDCWB_ResultFitSigmaPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_fitsigma"
End

Function/S LJZ_EDCWB_ResultFitInfoPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_fitinfo"
End

Function/S LJZ_EDCWB_ResultFitPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_fit"
End

Function/S LJZ_EDCWB_ResultResPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_res"
End

Function/S LJZ_EDCWB_ResultAcceptPath(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_WaveDFFromPath(srcWavePath) + LJZ_EDCWB_ResultBaseName(srcWavePath) + "_accept"
End

Function LJZ_EDCWB_EnsureResultRecord(srcWavePath)
    String srcWavePath

    Wave/Z src = $srcWavePath
    if (!WaveExists(src))
        return -1
    endif
    if (!LJZ_EDCWB_Is1DWave(src))
        return -1
    endif

    Wave/Z wGuess = $(LJZ_EDCWB_ResultGuessPath(srcWavePath))
    if (!WaveExists(wGuess))
        Duplicate/O src, $(LJZ_EDCWB_ResultGuessPath(srcWavePath))
        Wave wGuess2 = $(LJZ_EDCWB_ResultGuessPath(srcWavePath))
        wGuess2 = NaN
    endif

    Wave/Z wFit = $(LJZ_EDCWB_ResultFitPath(srcWavePath))
    if (!WaveExists(wFit))
        Duplicate/O src, $(LJZ_EDCWB_ResultFitPath(srcWavePath))
        Wave wFit2 = $(LJZ_EDCWB_ResultFitPath(srcWavePath))
        wFit2 = NaN
    endif

    Wave/Z wRes = $(LJZ_EDCWB_ResultResPath(srcWavePath))
    if (!WaveExists(wRes))
        Duplicate/O src, $(LJZ_EDCWB_ResultResPath(srcWavePath))
        Wave wRes2 = $(LJZ_EDCWB_ResultResPath(srcWavePath))
        wRes2 = NaN
    endif

    Wave/Z wCoef = $(LJZ_EDCWB_ResultFitCoefPath(srcWavePath))
    if (!WaveExists(wCoef))
        Make/O/N=12 $(LJZ_EDCWB_ResultFitCoefPath(srcWavePath)) = NaN
    else
        LJZ_EDCWB_EnsureNumWaveLen12(wCoef, NaN)
    endif

    Wave/Z wSig = $(LJZ_EDCWB_ResultFitSigmaPath(srcWavePath))
    if (!WaveExists(wSig))
        Make/O/N=12 $(LJZ_EDCWB_ResultFitSigmaPath(srcWavePath)) = NaN
    else
        LJZ_EDCWB_EnsureNumWaveLen12(wSig, NaN)
    endif

    Wave/Z wInfo = $(LJZ_EDCWB_ResultFitInfoPath(srcWavePath))
    if (!WaveExists(wInfo))
        Make/O/N=16 $(LJZ_EDCWB_ResultFitInfoPath(srcWavePath)) = NaN
    else
        LJZ_EDCWB_EnsureNumWaveLen16(wInfo, NaN)
    endif

    Wave/Z wAcc = $(LJZ_EDCWB_ResultAcceptPath(srcWavePath))
    if (!WaveExists(wAcc))
        Make/O/N=1 $(LJZ_EDCWB_ResultAcceptPath(srcWavePath)) = 0
    else
        Redimension/N=1 wAcc
    endif

    return 0
End


// ============================================================================
//  Section 6. Accept state read/write
// ============================================================================

Function LJZ_EDCWB_ReadAcceptState(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Wave/Z wAcc = $(LJZ_EDCWB_ResultAcceptPath(srcWavePath))
    if (!WaveExists(wAcc))
        return 0
    endif

    return wAcc[0]
End

Function LJZ_EDCWB_WriteAcceptState(srcWavePath, state)
    String srcWavePath
    Variable state

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Wave/Z wAcc = $(LJZ_EDCWB_ResultAcceptPath(srcWavePath))
    if (!WaveExists(wAcc))
        return -1
    endif

    wAcc[0] = state
    return 0
End


// ============================================================================
//  Section 7. Save / load standard fit record
// ============================================================================

Function LJZ_EDCWB_SaveGuessCurve(srcWavePath, wGuessIn)
    String srcWavePath
    Wave/Z wGuessIn

    if (!WaveExists(wGuessIn))
        return -1
    endif

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Wave wGuess = $(LJZ_EDCWB_ResultGuessPath(srcWavePath))
    if (numpnts(wGuess) != numpnts(wGuessIn))
        Duplicate/O wGuessIn, wGuess
    else
        wGuess = wGuessIn[p]
    endif

    return 0
End

Function LJZ_EDCWB_SaveFitCurve(srcWavePath, wFitIn, wResIn)
    String srcWavePath
    Wave/Z wFitIn, wResIn

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    if (WaveExists(wFitIn))
        Wave wFit = $(LJZ_EDCWB_ResultFitPath(srcWavePath))
        if (numpnts(wFit) != numpnts(wFitIn))
            Duplicate/O wFitIn, wFit
        else
            wFit = wFitIn[p]
        endif
    endif

    if (WaveExists(wResIn))
        Wave wRes = $(LJZ_EDCWB_ResultResPath(srcWavePath))
        if (numpnts(wRes) != numpnts(wResIn))
            Duplicate/O wResIn, wRes
        else
            wRes = wResIn[p]
        endif
    endif

    return 0
End

Function LJZ_EDCWB_SaveFitVectors(srcWavePath, wCoefIn, wSigmaIn, wInfoIn)
    String srcWavePath
    Wave/Z wCoefIn, wSigmaIn, wInfoIn

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    if (WaveExists(wCoefIn))
        Wave wCoef = $(LJZ_EDCWB_ResultFitCoefPath(srcWavePath))
        LJZ_EDCWB_EnsureNumWaveLen12(wCoef, NaN)
        wCoef = NaN
        Variable n0 = min(11, numpnts(wCoefIn) - 1)
        if (n0 >= 0)
            wCoef[0, n0] = wCoefIn[p]
        endif
    endif

    if (WaveExists(wSigmaIn))
        Wave wSig = $(LJZ_EDCWB_ResultFitSigmaPath(srcWavePath))
        LJZ_EDCWB_EnsureNumWaveLen12(wSig, NaN)
        wSig = NaN
        Variable n1 = min(11, numpnts(wSigmaIn) - 1)
        if (n1 >= 0)
            wSig[0, n1] = wSigmaIn[p]
        endif
    endif

    if (WaveExists(wInfoIn))
        Wave wInfo = $(LJZ_EDCWB_ResultFitInfoPath(srcWavePath))
        LJZ_EDCWB_EnsureNumWaveLen16(wInfo, NaN)
        wInfo = NaN
        Variable n2 = min(15, numpnts(wInfoIn) - 1)
        if (n2 >= 0)
            wInfo[0, n2] = wInfoIn[p]
        endif
    endif

    return 0
End

Function LJZ_EDCWB_ClearStoredFitOutputs(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Wave/Z wFit = $(LJZ_EDCWB_ResultFitPath(srcWavePath))
    if (WaveExists(wFit))
        wFit = NaN
    endif

    Wave/Z wRes = $(LJZ_EDCWB_ResultResPath(srcWavePath))
    if (WaveExists(wRes))
        wRes = NaN
    endif

    Wave/Z wSig = $(LJZ_EDCWB_ResultFitSigmaPath(srcWavePath))
    if (WaveExists(wSig))
        LJZ_EDCWB_EnsureNumWaveLen12(wSig, NaN)
        wSig = NaN
    endif

    return 0
End


Function LJZ_EDCWB_SaveCurrentEditToCoef(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    NVAR eModel = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR eXLo   = $(LJZ_EDCWB_BaseDF() + ":EditXLo")
    NVAR eXHi   = $(LJZ_EDCWB_BaseDF() + ":EditXHi")
    NVAR eTemp  = $(LJZ_EDCWB_BaseDF() + ":EditTemperature")
    NVAR eEF    = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    NVAR eRes   = $(LJZ_EDCWB_BaseDF() + ":EditResolution")
    NVAR eNorm  = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")
    NVAR fitOnSm = $(LJZ_EDCWB_BaseDF() + ":FitOnSmooth")

    Wave ePar   = $(LJZ_EDCWB_BaseDF() + ":EditPar")
    Wave wCoef  = $(LJZ_EDCWB_ResultFitCoefPath(srcWavePath))
    Wave wInfo  = $(LJZ_EDCWB_ResultFitInfoPath(srcWavePath))

    LJZ_EDCWB_EnsureNumWaveLen12(wCoef, NaN)
    LJZ_EDCWB_EnsureNumWaveLen16(wInfo, NaN)

    wCoef = ePar[p]

    wInfo[LJZ_EDCWB_FI_ModelID()]     = eModel
    wInfo[LJZ_EDCWB_FI_XLo()]         = eXLo
    wInfo[LJZ_EDCWB_FI_XHi()]         = eXHi
    wInfo[LJZ_EDCWB_FI_Temperature()] = eTemp
    wInfo[LJZ_EDCWB_FI_Resolution()]  = eRes
    wInfo[LJZ_EDCWB_FI_EFermi()]      = eEF
    wInfo[LJZ_EDCWB_FI_NormMode()]    = eNorm
    wInfo[LJZ_EDCWB_FI_SmoothUsed()]  = fitOnSm

    return 0
End

Function LJZ_EDCWB_LoadFitRecordToEditState(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Wave/Z wCoef = $(LJZ_EDCWB_ResultFitCoefPath(srcWavePath))
    Wave/Z wInfo = $(LJZ_EDCWB_ResultFitInfoPath(srcWavePath))
    if (!WaveExists(wCoef) || !WaveExists(wInfo))
        return -1
    endif

    NVAR eModel = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR eXLo   = $(LJZ_EDCWB_BaseDF() + ":EditXLo")
    NVAR eXHi   = $(LJZ_EDCWB_BaseDF() + ":EditXHi")
    NVAR eTemp  = $(LJZ_EDCWB_BaseDF() + ":EditTemperature")
    NVAR eEF    = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    NVAR eRes   = $(LJZ_EDCWB_BaseDF() + ":EditResolution")
    NVAR eNorm  = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")
    NVAR fitOnSm = $(LJZ_EDCWB_BaseDF() + ":FitOnSmooth")

    Wave ePar   = $(LJZ_EDCWB_BaseDF() + ":EditPar")

    if (numtype(wInfo[LJZ_EDCWB_FI_ModelID()]) == 0)
        eModel = wInfo[LJZ_EDCWB_FI_ModelID()]
    endif

    LJZ_EDCWB_SetParamLayout(eModel)
    LJZ_EDCWB_EnsureNumWaveLen12(ePar, NaN)
    ePar = wCoef[p]
    LJZ_EDCWB_FillNaNParsWithDefaults(eModel)
    LJZ_EDCWB_SanitizeParamWave(eModel, ePar)

    if (numtype(wInfo[LJZ_EDCWB_FI_XLo()]) == 0)
        eXLo = wInfo[LJZ_EDCWB_FI_XLo()]
    endif
    if (numtype(wInfo[LJZ_EDCWB_FI_XHi()]) == 0)
        eXHi = wInfo[LJZ_EDCWB_FI_XHi()]
    endif
    if (numtype(wInfo[LJZ_EDCWB_FI_Temperature()]) == 0)
        eTemp = wInfo[LJZ_EDCWB_FI_Temperature()]
    endif
    if (numtype(wInfo[LJZ_EDCWB_FI_EFermi()]) == 0)
        eEF = wInfo[LJZ_EDCWB_FI_EFermi()]
    endif
    if (numtype(wInfo[LJZ_EDCWB_FI_Resolution()]) == 0)
        eRes = wInfo[LJZ_EDCWB_FI_Resolution()]
    endif
    if (numtype(wInfo[LJZ_EDCWB_FI_NormMode()]) == 0)
        eNorm = wInfo[LJZ_EDCWB_FI_NormMode()]
    endif
    if (numtype(wInfo[LJZ_EDCWB_FI_SmoothUsed()]) == 0)
        fitOnSm = wInfo[LJZ_EDCWB_FI_SmoothUsed()]
    endif

    LJZ_EDCWB_SyncParToAuxState()
    LJZ_EDCWB_MarkDirty(0)
    return 0
End


// ============================================================================
//  Section 8. small utilities for later parts
// ============================================================================

Function LJZ_EDCWB_HasFitRecord(srcWavePath)
    String srcWavePath

    Wave/Z wInfo = $(LJZ_EDCWB_ResultFitInfoPath(srcWavePath))
    Wave/Z wCoef = $(LJZ_EDCWB_ResultFitCoefPath(srcWavePath))
    if (!WaveExists(wInfo) || !WaveExists(wCoef))
        return 0
    endif

    if (numtype(wInfo[LJZ_EDCWB_FI_ModelID()]) != 0)
        return 0
    endif

    if (numtype(wInfo[LJZ_EDCWB_FI_FitOK()]) != 0)
        return 0
    endif

    if (numpnts(wCoef) < 12)
        return 0
    endif

    WaveStats/Q wCoef
    if (V_numNaNs >= numpnts(wCoef))
        return 0
    endif

    return 1
End

Function LJZ_EDCWB_ClearFitRecord(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Wave wGuess = $(LJZ_EDCWB_ResultGuessPath(srcWavePath))
    Wave wCoef  = $(LJZ_EDCWB_ResultFitCoefPath(srcWavePath))
    Wave wSig   = $(LJZ_EDCWB_ResultFitSigmaPath(srcWavePath))
    Wave wInfo  = $(LJZ_EDCWB_ResultFitInfoPath(srcWavePath))
    Wave wFit   = $(LJZ_EDCWB_ResultFitPath(srcWavePath))
    Wave wRes   = $(LJZ_EDCWB_ResultResPath(srcWavePath))
    Wave wAcc   = $(LJZ_EDCWB_ResultAcceptPath(srcWavePath))

    wGuess = NaN
    wCoef  = NaN
    wSig   = NaN
    wInfo  = NaN
    wFit   = NaN
    wRes   = NaN
    wAcc[0] = 0

    return 0
End

