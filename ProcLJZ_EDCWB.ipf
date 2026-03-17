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

#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

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

    // 至少有 dim0 dim1 dim2
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

    String runDF = LJZ_MakeRunDFName(w, kStart, kEnd, "EDC")
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
    LJZ_ApplySmoothing_All(runDF)

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
    DoWindow/F $p
    if (V_flag == 0)
        NewPanel/N=$p /W=(80,80,510,520)
    else
        DoWindow/F $p
        return 0
    endif

    SetVariable svBaseDF,pos={10,10},size={250,18},title="Base DF"
    SetVariable svBaseDF,variable=root:ARPES_LJZ:EDCFit:BaseDF,proc=EDCFIT_SetVarProc

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
    SetVariable svBaseName,variable=root:ARPES_LJZ:EDCFit:gBaseName,proc=EDCFIT_SetVarProc

    Button btShowEDC,pos={240,180},size={120,26},title="Show EDC",proc=EDCFIT_ButtonProc
    Button btOpenWB,pos={240,215},size={120,26},title="Open EDCWB",proc=EDCFIT_ButtonProc

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

Function EDCFIT_ButtonProc(ctrlName) : ButtonControl
    String ctrlName

    if (CmpStr(ctrlName, "btScan") == 0)
        EDCFIT_RebuildWaveList()
        EDCFIT_RefreshTitleBoxes()
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

Function EDCFIT_SetVarProc(ctrlName,varNum,varStr,varName) : SetVariableControl
    String ctrlName
    Variable varNum
    String varStr
    String varName

    if (CmpStr(ctrlName, "svBaseDF") == 0)
        EDCFIT_RebuildWaveList()
        EDCFIT_RefreshTitleBoxes()
        return 0
    endif

    if ((CmpStr(ctrlName, "svK0") == 0) || (CmpStr(ctrlName, "svK1") == 0) || (CmpStr(ctrlName, "svEvary") == 0) || (CmpStr(ctrlName, "svBaseName") == 0))
        EDCFIT_RefreshTitleBoxes()
        return 0
    endif

    return 0
End

Function EDCFIT_CheckProc(ctrlName,checked) : CheckBoxControl
    String ctrlName
    Variable checked

    if (CmpStr(ctrlName, "cbRecursive") == 0)
        EDCFIT_RebuildWaveList()
        EDCFIT_RefreshTitleBoxes()
        return 0
    endif

    return 0
End

Function EDCFIT_ListBoxProc(ctrlName,row,col,event) : ListBoxControl
    String ctrlName
    Variable row,col,event

    if ((event != 1) && (event != 4))
        return 0
    endif

    if (CmpStr(ctrlName, "lbWave") == 0)
        if (row >= 0)
            EDCFIT_SelectWaveRow(row)
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
    NewDataFolder/O $(LJZ_EDCWB_BaseDF())

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

    LJZ_EDCWB_EnsureNumWaveLen12(ePar, NaN)
    ePar = wCoef[p]

    if (numtype(wInfo[LJZ_EDCWB_FI_ModelID()]) == 0)
        eModel = wInfo[LJZ_EDCWB_FI_ModelID()]
    endif
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

    LJZ_EDCWB_MarkDirty(0)
    return 0
End


// ============================================================================
//  Section 8. small utilities for later parts
// ============================================================================

Function LJZ_EDCWB_HasFitRecord(srcWavePath)
    String srcWavePath

    Wave/Z wCoef = $(LJZ_EDCWB_ResultFitCoefPath(srcWavePath))
    Wave/Z wInfo = $(LJZ_EDCWB_ResultFitInfoPath(srcWavePath))

    if (!WaveExists(wCoef) || !WaveExists(wInfo))
        return 0
    endif

    if (numtype(wInfo[LJZ_EDCWB_FI_ModelID()]) != 0)
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

// ============================================================================
//  LJZ_EDCWB Part 2 : Model Bank + Param Layout
//  只负责：
//    1) model ids / names
//    2) parameter count / labels / enable flags
//    3) default hold policy
//
//  本部分不负责：
//    - 实际拟合公式计算
//    - auto guess 数值生成
//    - panel UI
// ============================================================================


// ============================================================================
//  Section 9. Model IDs
// ============================================================================

Function LJZ_EDCWB_Model_SinglePeakFDConv()
    return 1
End

Function LJZ_EDCWB_Model_EffectiveGap()
    return 2
End

Function LJZ_EDCWB_Model_SymGap()
    return 3
End

Function LJZ_EDCWB_Model_None()
    return 0
End


// ============================================================================
//  Section 10. Model meta
// ============================================================================

Function LJZ_EDCWB_ModelIsValid(modelID)
    Variable modelID

    if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
        return 1
    endif
    if (modelID == LJZ_EDCWB_Model_EffectiveGap())
        return 1
    endif
    if (modelID == LJZ_EDCWB_Model_SymGap())
        return 1
    endif

    return 0
End

Function/S LJZ_EDCWB_ModelName(modelID)
    Variable modelID

    if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
        return "SinglePeak*FD*GaussConv"
    endif

    if (modelID == LJZ_EDCWB_Model_EffectiveGap())
        return "EffectiveGap*FD*GaussConv"
    endif

    if (modelID == LJZ_EDCWB_Model_SymGap())
        return "SymmetrizedGap"
    endif

    return "Unknown"
End

Function/S LJZ_EDCWB_ModelPopupList()
    String s = ""

    s = AddListItem(LJZ_EDCWB_ModelName(LJZ_EDCWB_Model_SinglePeakFDConv()), s, ";", Inf)
    s = AddListItem(LJZ_EDCWB_ModelName(LJZ_EDCWB_Model_EffectiveGap()), s, ";", Inf)
    s = AddListItem(LJZ_EDCWB_ModelName(LJZ_EDCWB_Model_SymGap()), s, ";", Inf)

    return s
End

Function LJZ_EDCWB_ModelNPar(modelID)
    Variable modelID

    if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
        // bg0 bg1 A x0 w eta T EF res
        return 9
    endif

    if (modelID == LJZ_EDCWB_Model_EffectiveGap())
        // bg0 bg1 A Delta Gamma T EF res
        return 8
    endif

    if (modelID == LJZ_EDCWB_Model_SymGap())
        // bg0 bg1 A Delta Gamma x0
        return 6
    endif

    return 0
End

Function LJZ_EDCWB_ModelUsesFD(modelID)
    Variable modelID

    if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
        return 1
    endif
    if (modelID == LJZ_EDCWB_Model_EffectiveGap())
        return 1
    endif

    return 0
End

Function LJZ_EDCWB_ModelUsesResolution(modelID)
    Variable modelID

    if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
        return 1
    endif
    if (modelID == LJZ_EDCWB_Model_EffectiveGap())
        return 1
    endif

    return 0
End

Function LJZ_EDCWB_ModelSuggestSymMode(modelID)
    Variable modelID

    if (modelID == LJZ_EDCWB_Model_SymGap())
        return 1
    endif

    return 0
End


// ============================================================================
//  Section 11. Param slot meaning
// ============================================================================
//
// 统一规定：EditPar[0..11] 永远是“槽位”
// 不同 model 决定每个槽位的含义。
// 未使用槽位：name="", enable=0
//
// 对各模型的约定：
//
//  Model 1: SinglePeak*FD*GaussConv
//    0 bg0
//    1 bg1
//    2 A
//    3 x0
//    4 w
//    5 eta
//    6 T
//    7 EF
//    8 res
//
//  Model 2: EffectiveGap*FD*GaussConv
//    0 bg0
//    1 bg1
//    2 A
//    3 Delta
//    4 Gamma
//    5 T
//    6 EF
//    7 res
//
//  Model 3: SymmetrizedGap
//    0 bg0
//    1 bg1
//    2 A
//    3 Delta
//    4 Gamma
//    5 x0
// ============================================================================

Function/S LJZ_EDCWB_ParamName(modelID, idx)
    Variable modelID, idx

    if (idx < 0 || idx > 11)
        return ""
    endif

    if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
        if (idx == 0)
            return "bg0"
        endif
        if (idx == 1)
            return "bg1"
        endif
        if (idx == 2)
            return "A"
        endif
        if (idx == 3)
            return "x0"
        endif
        if (idx == 4)
            return "w"
        endif
        if (idx == 5)
            return "eta"
        endif
        if (idx == 6)
            return "T"
        endif
        if (idx == 7)
            return "EF"
        endif
        if (idx == 8)
            return "res"
        endif
        return ""
    endif

    if (modelID == LJZ_EDCWB_Model_EffectiveGap())
        if (idx == 0)
            return "bg0"
        endif
        if (idx == 1)
            return "bg1"
        endif
        if (idx == 2)
            return "A"
        endif
        if (idx == 3)
            return "Delta"
        endif
        if (idx == 4)
            return "Gamma"
        endif
        if (idx == 5)
            return "T"
        endif
        if (idx == 6)
            return "EF"
        endif
        if (idx == 7)
            return "res"
        endif
        return ""
    endif

    if (modelID == LJZ_EDCWB_Model_SymGap())
        if (idx == 0)
            return "bg0"
        endif
        if (idx == 1)
            return "bg1"
        endif
        if (idx == 2)
            return "A"
        endif
        if (idx == 3)
            return "Delta"
        endif
        if (idx == 4)
            return "Gamma"
        endif
        if (idx == 5)
            return "x0"
        endif
        return ""
    endif

    return ""
End

Function LJZ_EDCWB_ParamEnabled(modelID, idx)
    Variable modelID, idx

    if (strlen(LJZ_EDCWB_ParamName(modelID, idx)) > 0)
        return 1
    endif

    return 0
End


// ============================================================================
//  Section 12. Param lookup helpers
// ============================================================================

Function LJZ_EDCWB_ParamIndex(modelID, pName)
    Variable modelID
    String pName

    Variable i
    for (i = 0; i < 12; i += 1)
        if (CmpStr(LJZ_EDCWB_ParamName(modelID, i), pName) == 0)
            return i
        endif
    endfor

    return -1
End

Function LJZ_EDCWB_ModelHasParam(modelID, pName)
    Variable modelID
    String pName

    if (LJZ_EDCWB_ParamIndex(modelID, pName) >= 0)
        return 1
    endif

    return 0
End

Function LJZ_EDCWB_GetParValue(modelID, wPar, pName)
    Variable modelID
    Wave wPar
    String pName

    Variable idx = LJZ_EDCWB_ParamIndex(modelID, pName)
    if (idx < 0)
        return NaN
    endif
    if (idx >= numpnts(wPar))
        return NaN
    endif

    return wPar[idx]
End

Function LJZ_EDCWB_SetParValue(modelID, wPar, pName, val)
    Variable modelID, val
    Wave wPar
    String pName

    Variable idx = LJZ_EDCWB_ParamIndex(modelID, pName)
    if (idx < 0)
        return -1
    endif
    if (idx >= numpnts(wPar))
        return -1
    endif

    wPar[idx] = val
    return 0
End


// ============================================================================
//  Section 13. Default hold policy
// ============================================================================
//
// hold == 1 代表默认固定
// hold == 0 代表默认自由
//
// 设计原则：
//   - 第一版偏保守，让 T / EF / res 默认固定
//   - eta 默认也固定到 0.5，减少早期拟合漂移
// ============================================================================

Function LJZ_EDCWB_ParamDefaultHold(modelID, idx)
    Variable modelID, idx

    if (!LJZ_EDCWB_ParamEnabled(modelID, idx))
        return 0
    endif

    if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
        // bg0 bg1 A x0 w eta T EF res
        if (idx == 5)   // eta
            return 1
        endif
        if (idx == 6)   // T
            return 1
        endif
        if (idx == 7)   // EF
            return 1
        endif
        if (idx == 8)   // res
            return 1
        endif
        return 0
    endif

    if (modelID == LJZ_EDCWB_Model_EffectiveGap())
        // bg0 bg1 A Delta Gamma T EF res
        if (idx == 5)   // T
            return 1
        endif
        if (idx == 6)   // EF
            return 1
        endif
        if (idx == 7)   // res
            return 1
        endif
        return 0
    endif

    if (modelID == LJZ_EDCWB_Model_SymGap())
        // bg0 bg1 A Delta Gamma x0
        return 0
    endif

    return 0
End


// ============================================================================
//  Section 14. Default values
// ============================================================================
//
// 这里只放“软默认值”，真正更聪明的值由 AutoGuess 提供。
// 如果当前 EditPar 某槽位是 NaN，可先用这些默认值补齐。
// ============================================================================

Function LJZ_EDCWB_ParamDefaultValue(modelID, idx)
    Variable modelID, idx

    if (!LJZ_EDCWB_ParamEnabled(modelID, idx))
        return NaN
    endif

    if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
        if (idx == 0)   // bg0
            return 0
        endif
        if (idx == 1)   // bg1
            return 0
        endif
        if (idx == 2)   // A
            return 1
        endif
        if (idx == 3)   // x0
            return 0
        endif
        if (idx == 4)   // w
            return 0.02
        endif
        if (idx == 5)   // eta
            return 0.5
        endif
        if (idx == 6)   // T
            return 10
        endif
        if (idx == 7)   // EF
            return 0
        endif
        if (idx == 8)   // res
            return 0.01
        endif
    endif

    if (modelID == LJZ_EDCWB_Model_EffectiveGap())
        if (idx == 0)
            return 0
        endif
        if (idx == 1)
            return 0
        endif
        if (idx == 2)
            return 1
        endif
        if (idx == 3)   // Delta
            return 0.02
        endif
        if (idx == 4)   // Gamma
            return 0.01
        endif
        if (idx == 5)   // T
            return 10
        endif
        if (idx == 6)   // EF
            return 0
        endif
        if (idx == 7)   // res
            return 0.01
        endif
    endif

    if (modelID == LJZ_EDCWB_Model_SymGap())
        if (idx == 0)
            return 0
        endif
        if (idx == 1)
            return 0
        endif
        if (idx == 2)
            return 1
        endif
        if (idx == 3)
            return 0.02
        endif
        if (idx == 4)
            return 0.01
        endif
        if (idx == 5)
            return 0
        endif
    endif

    return NaN
End


// ============================================================================
//  Section 15. Runtime wave layout updater
// ============================================================================

Function LJZ_EDCWB_SetParamLayout(modelID)
    Variable modelID

    LJZ_EDCWB_EnsureDF()

    Wave/T wName = $(LJZ_EDCWB_BaseDF() + ":EditParName")
    Wave   wEn   = $(LJZ_EDCWB_BaseDF() + ":EditParEnable")
    Wave   wHold = $(LJZ_EDCWB_BaseDF() + ":EditHold")

    Variable i
    for (i = 0; i < 12; i += 1)
        wName[i] = LJZ_EDCWB_ParamName(modelID, i)
        wEn[i]   = LJZ_EDCWB_ParamEnabled(modelID, i)
        wHold[i] = LJZ_EDCWB_ParamDefaultHold(modelID, i)
    endfor

    return 0
End

Function LJZ_EDCWB_FillNaNParsWithDefaults(modelID)
    Variable modelID

    LJZ_EDCWB_EnsureDF()

    Wave wPar = $(LJZ_EDCWB_BaseDF() + ":EditPar")

    Variable i, dv
    for (i = 0; i < 12; i += 1)
        if (!LJZ_EDCWB_ParamEnabled(modelID, i))
            wPar[i] = NaN
            continue
        endif

        if (numtype(wPar[i]) != 0)
            dv = LJZ_EDCWB_ParamDefaultValue(modelID, i)
            wPar[i] = dv
        endif
    endfor

    return 0
End

Function LJZ_EDCWB_ApplyDefaultHoldPolicy(modelID)
    Variable modelID

    LJZ_EDCWB_EnsureDF()

    Wave wHold = $(LJZ_EDCWB_BaseDF() + ":EditHold")

    Variable i
    for (i = 0; i < 12; i += 1)
        wHold[i] = LJZ_EDCWB_ParamDefaultHold(modelID, i)
    endfor

    return 0
End

Function LJZ_EDCWB_SetModel(modelID)
    Variable modelID

    if (!LJZ_EDCWB_ModelIsValid(modelID))
        return -1
    endif

    LJZ_EDCWB_EnsureDF()

    NVAR eModel = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR eTemp  = $(LJZ_EDCWB_BaseDF() + ":EditTemperature")
    NVAR eEF    = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    NVAR eRes   = $(LJZ_EDCWB_BaseDF() + ":EditResolution")

    Wave wPar = $(LJZ_EDCWB_BaseDF() + ":EditPar")

    eModel = modelID

    LJZ_EDCWB_SetParamLayout(modelID)
    LJZ_EDCWB_FillNaNParsWithDefaults(modelID)

    // 将 runtime 中的物理辅助参数回填到参数槽位
    if (LJZ_EDCWB_ModelHasParam(modelID, "T"))
        LJZ_EDCWB_SetParValue(modelID, wPar, "T", eTemp)
    endif

    if (LJZ_EDCWB_ModelHasParam(modelID, "EF"))
        LJZ_EDCWB_SetParValue(modelID, wPar, "EF", eEF)
    endif

    if (LJZ_EDCWB_ModelHasParam(modelID, "res"))
        LJZ_EDCWB_SetParValue(modelID, wPar, "res", eRes)
    endif

    LJZ_EDCWB_MarkDirty(1)
    return 0
End


// ============================================================================
//  Section 16. Runtime -> auxiliary state sync
// ============================================================================
//
// 当参数槽位被编辑后，可把公共物理量同步回 runtime scalar，
// 方便 panel 中的温度 / EF / 分辨率输入框与参数槽位共存。
// ============================================================================

Function LJZ_EDCWB_SyncParToAuxState()
    LJZ_EDCWB_EnsureDF()

    NVAR eModel = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR eTemp  = $(LJZ_EDCWB_BaseDF() + ":EditTemperature")
    NVAR eEF    = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    NVAR eRes   = $(LJZ_EDCWB_BaseDF() + ":EditResolution")

    Wave wPar   = $(LJZ_EDCWB_BaseDF() + ":EditPar")

    Variable v

    if (LJZ_EDCWB_ModelHasParam(eModel, "T"))
        v = LJZ_EDCWB_GetParValue(eModel, wPar, "T")
        if (numtype(v) == 0)
            eTemp = v
        endif
    endif

    if (LJZ_EDCWB_ModelHasParam(eModel, "EF"))
        v = LJZ_EDCWB_GetParValue(eModel, wPar, "EF")
        if (numtype(v) == 0)
            eEF = v
        endif
    endif

    if (LJZ_EDCWB_ModelHasParam(eModel, "res"))
        v = LJZ_EDCWB_GetParValue(eModel, wPar, "res")
        if (numtype(v) == 0)
            eRes = v
        endif
    endif

    return 0
End

Function LJZ_EDCWB_SyncAuxStateToPar()
    LJZ_EDCWB_EnsureDF()

    NVAR eModel = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR eTemp  = $(LJZ_EDCWB_BaseDF() + ":EditTemperature")
    NVAR eEF    = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    NVAR eRes   = $(LJZ_EDCWB_BaseDF() + ":EditResolution")

    Wave wPar   = $(LJZ_EDCWB_BaseDF() + ":EditPar")

    if (LJZ_EDCWB_ModelHasParam(eModel, "T"))
        LJZ_EDCWB_SetParValue(eModel, wPar, "T", eTemp)
    endif

    if (LJZ_EDCWB_ModelHasParam(eModel, "EF"))
        LJZ_EDCWB_SetParValue(eModel, wPar, "EF", eEF)
    endif

    if (LJZ_EDCWB_ModelHasParam(eModel, "res"))
        LJZ_EDCWB_SetParValue(eModel, wPar, "res", eRes)
    endif

    return 0
End


// ============================================================================
//  Section 17. Bounds / sanitation helpers (light version)
// ============================================================================
//
// 这里只做最基础的“物理上别太离谱”限制，
// 真正更复杂的 bounds 留到 fit engine 再扩展。
// ============================================================================

Function LJZ_EDCWB_SanitizeParamWave(modelID, wPar)
    Variable modelID
    Wave wPar

    Variable idx

    // 通用：未启用槽位清成 NaN
    Variable i
    for (i = 0; i < 12; i += 1)
        if (!LJZ_EDCWB_ParamEnabled(modelID, i))
            wPar[i] = NaN
        endif
    endfor

    // A >= 0
    idx = LJZ_EDCWB_ParamIndex(modelID, "A")
    if (idx >= 0 && numtype(wPar[idx]) == 0)
        if (wPar[idx] < 0)
            wPar[idx] = abs(wPar[idx])
        endif
    endif

    // 宽度 / gap / gamma / res >= small positive
    idx = LJZ_EDCWB_ParamIndex(modelID, "w")
    if (idx >= 0 && numtype(wPar[idx]) == 0)
        if (wPar[idx] <= 0)
            wPar[idx] = 1e-4
        endif
    endif

    idx = LJZ_EDCWB_ParamIndex(modelID, "Delta")
    if (idx >= 0 && numtype(wPar[idx]) == 0)
        if (wPar[idx] < 0)
            wPar[idx] = abs(wPar[idx])
        endif
    endif

    idx = LJZ_EDCWB_ParamIndex(modelID, "Gamma")
    if (idx >= 0 && numtype(wPar[idx]) == 0)
        if (wPar[idx] <= 0)
            wPar[idx] = 1e-4
        endif
    endif

    idx = LJZ_EDCWB_ParamIndex(modelID, "res")
    if (idx >= 0 && numtype(wPar[idx]) == 0)
        if (wPar[idx] <= 0)
            wPar[idx] = 1e-4
        endif
    endif

    // eta 限制在 [0,1]
    idx = LJZ_EDCWB_ParamIndex(modelID, "eta")
    if (idx >= 0 && numtype(wPar[idx]) == 0)
        if (wPar[idx] < 0)
            wPar[idx] = 0
        endif
        if (wPar[idx] > 1)
            wPar[idx] = 1
        endif
    endif

    // 温度不许负
    idx = LJZ_EDCWB_ParamIndex(modelID, "T")
    if (idx >= 0 && numtype(wPar[idx]) == 0)
        if (wPar[idx] < 0)
            wPar[idx] = 0
        endif
    endif

    return 0
End

// ============================================================================
//  LJZ_EDCWB Part 3 : Data Preprocess
//  只负责：
//    1) source EDC -> temporary working waves
//    2) smooth / symmetrize / normalize
//    3) choose display input / fit input
//
//  本部分不负责：
//    - auto guess
//    - actual fit math
//    - panel callbacks
// ============================================================================


// ============================================================================
//  Section 18. Temporary workspace
// ============================================================================

Function/S LJZ_EDCWB_TmpDF()
    return LJZ_EDCWB_BaseDF() + ":TMP"
End

Function LJZ_EDCWB_EnsureTmpDF()
    NewDataFolder/O $(LJZ_EDCWB_TmpDF())
    return 0
End

Function/S LJZ_EDCWB_TmpWavePath(tag)
    String tag
    return LJZ_EDCWB_TmpDF() + ":" + tag
End

Function/S LJZ_EDCWB_SafeTmpTag(srcWavePath, suffix)
    String srcWavePath, suffix

    String nm = LJZ_EDCWB_WaveNameFromPath(srcWavePath)
    if (strlen(nm) == 0)
        nm = "unnamed"
    endif

    // Igor wave name 里不要保留奇怪字符
    nm = ReplaceString(" ", nm, "_")
    nm = ReplaceString("-", nm, "_")
    nm = ReplaceString(".", nm, "_")

    return "EDCWB_" + nm + "_" + suffix
End


// ============================================================================
//  Section 19. Basic source helpers
// ============================================================================

Function/WAVE LJZ_EDCWB_GetSourceWave(srcWavePath)
    String srcWavePath

    Wave/Z w = $srcWavePath
    return w
End

Function LJZ_EDCWB_SourceWaveExists(srcWavePath)
    String srcWavePath

    Wave/Z w = $srcWavePath
    if (!WaveExists(w))
        return 0
    endif
    return LJZ_EDCWB_Is1DWave(w)
End

Function LJZ_EDCWB_CopySourceToTmp(srcWavePath, suffix)
    String srcWavePath, suffix

    LJZ_EDCWB_EnsureTmpDF()

    Wave/Z src = $srcWavePath
    if (!WaveExists(src))
        return -1
    endif
    if (!LJZ_EDCWB_Is1DWave(src))
        return -1
    endif

    String outPath = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, suffix))
    Duplicate/O src, $outPath

    return 0
End

Function/WAVE LJZ_EDCWB_GetTmpWave(srcWavePath, suffix)
    String srcWavePath, suffix

    String outPath = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, suffix))
    Wave/Z w = $outPath
    return w
End


// ============================================================================
//  Section 20. X-scale / helper math
// ============================================================================

Function LJZ_EDCWB_WaveDX(w)
    Wave w

    Variable dx = DimDelta(w, 0)
    if (numtype(dx) != 0 || dx == 0)
        dx = 1
    endif

    return dx
End

Function LJZ_EDCWB_WaveX0(w)
    Wave w

    Variable x0 = DimOffset(w, 0)
    if (numtype(x0) != 0)
        x0 = 0
    endif

    return x0
End

Function LJZ_EDCWB_ClampIndex(i, n)
    Variable i, n

    if (n <= 0)
        return 0
    endif
    if (i < 0)
        return 0
    endif
    if (i > n - 1)
        return n - 1
    endif

    return i
End

Function LJZ_EDCWB_XToNearestIndex(w, xval)
    Wave w
    Variable xval

    Variable x0 = LJZ_EDCWB_WaveX0(w)
    Variable dx = LJZ_EDCWB_WaveDX(w)
    Variable n  = numpnts(w)

    Variable idx = round((xval - x0) / dx)
    idx = LJZ_EDCWB_ClampIndex(idx, n)

    return idx
End

Function LJZ_EDCWB_GetROIIndexPair(w, xLo, xHi, iLo, iHi)
    Wave w
    Variable xLo, xHi
    Variable &iLo, &iHi

    Variable n = numpnts(w)
    if (n <= 0)
        iLo = 0
        iHi = -1
        return -1
    endif

    if (numtype(xLo) != 0 || numtype(xHi) != 0)
        iLo = 0
        iHi = n - 1
        return 0
    endif

    iLo = LJZ_EDCWB_XToNearestIndex(w, min(xLo, xHi))
    iHi = LJZ_EDCWB_XToNearestIndex(w, max(xLo, xHi))

    if (iLo > iHi)
        Variable tmp = iLo
        iLo = iHi
        iHi = tmp
    endif

    return 0
End


// ============================================================================
//  Section 21. Smooth builders
// ============================================================================
//
// SmoothMethod 约定：
//   0 None
//   1 Smooth   (box/binomial default command style)
//   2 SmoothS  (Savitzky-Golay, using /S=polyOrder)
// ============================================================================
//
// SmoothParam1:
//   method 1: points
//   method 2: points
//
// SmoothParam2:
//   method 1: unused
//   method 2: polyOrder
// ============================================================================

Function LJZ_EDCWB_ApplySmoothInPlace(w, method, p1, p2)
    Wave w
    Variable method, p1, p2

    Variable npts = numpnts(w)
    if (npts <= 2)
        return 0
    endif

    // normalize window length to a sensible positive integer
    Variable win = round(abs(p1))
    if (win < 1)
        win = 1
    endif

    if (method == 0)
        return 0
    endif

    if (method == 1)
        // 普通 Smooth
        Smooth win, w
        return 0
    endif

    if (method == 2)
        // Savitzky-Golay
        Variable poly = round(abs(p2))
        if (poly < 2)
            poly = 2
        endif

        // 尽量避免过于离谱的设置
        if (win < poly + 2)
            win = poly + 2
        endif

        Smooth/S=(poly) win, w
        return 0
    endif

    // 未知方法，什么都不做
    return 0
End

Function/WAVE LJZ_EDCWB_BuildSmoothWave(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureTmpDF()

    NVAR smEn     = $(LJZ_EDCWB_BaseDF() + ":SmoothEnable")
    NVAR smMethod = $(LJZ_EDCWB_BaseDF() + ":SmoothMethod")
    NVAR smP1     = $(LJZ_EDCWB_BaseDF() + ":SmoothParam1")
    NVAR smP2     = $(LJZ_EDCWB_BaseDF() + ":SmoothParam2")

    Wave/Z src = $srcWavePath
    if (!WaveExists(src))
        Wave/Z bad
        return bad
    endif

    String outPath = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, "smooth"))
    Duplicate/O src, $outPath
    Wave out = $outPath

    if (smEn == 0 || smMethod == 0)
        return out
    endif

    LJZ_EDCWB_ApplySmoothInPlace(out, smMethod, smP1, smP2)
    return out
End


// ============================================================================
//  Section 22. Symmetrization
// ============================================================================
//
// 目标：构建 I_sym(E) = I(E) + I(2*x0 - E)
// 这里 x0 一般是 EF 或指定中心。
// 由于 Igor 1D wave 支持按 scaled x 取值：wave(x) 线性插值，
// 所以可以直接利用这一点构造镜像。手册也明确提到 1D wave
// 允许按缩放后的 x 值访问。:contentReference[oaicite:2]{index=2}
// ============================================================================

Function/WAVE LJZ_EDCWB_BuildSymmetrizedWaveFromCenter(srcWavePath, xCenter)
    String srcWavePath
    Variable xCenter

    LJZ_EDCWB_EnsureTmpDF()

    Wave/Z src = $srcWavePath
    if (!WaveExists(src))
        Wave/Z bad
        return bad
    endif

    String outPath = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, "sym"))
    Duplicate/O src, $outPath
    Wave out = $outPath

    out = src(x) + src(2 * xCenter - x)

    return out
End

Function/WAVE LJZ_EDCWB_BuildSymmetrizedWave(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()

    NVAR eEF = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    return LJZ_EDCWB_BuildSymmetrizedWaveFromCenter(srcWavePath, eEF)
End


// ============================================================================
//  Section 23. Normalization
// ============================================================================
//
// NormMode 约定：
//   0 none
//   1 max abs normalize
//   2 tail mean normalize
//   3 ROI max normalize
//
// tail mean: 默认用最后 10% 点的平均绝对值
// ROI max:   用 EditXLo/EditXHi 范围内的 max(abs)
// ============================================================================

Function LJZ_EDCWB_WaveAbsMax(w)
    Wave w

    Variable n = numpnts(w)
    if (n <= 0)
        return NaN
    endif

    WaveStats/Q w
    Variable vmax = V_max
    Variable vmin = V_min

    if (numtype(vmax) != 0 || numtype(vmin) != 0)
        return NaN
    endif

    return max(abs(vmax), abs(vmin))
End

Function LJZ_EDCWB_WaveTailMeanAbs(w, frac)
    Wave w
    Variable frac

    Variable n = numpnts(w)
    if (n <= 0)
        return NaN
    endif

    Variable nTail = round(n * frac)
    if (nTail < 3)
        nTail = min(3, n)
    endif

    Variable i0 = n - nTail
    if (i0 < 0)
        i0 = 0
    endif

    Duplicate/O/R=[i0, n - 1] w, $(LJZ_EDCWB_TmpDF() + ":__edcwb_tail_tmp")
    Wave tmp = $(LJZ_EDCWB_TmpDF() + ":__edcwb_tail_tmp")
    tmp = abs(tmp[p])

    WaveStats/Q tmp
    Variable meanv = V_avg
    KillWaves/Z tmp

    return meanv
End

Function LJZ_EDCWB_WaveROIMaxAbs(w, xLo, xHi)
    Wave w
    Variable xLo, xHi

    Variable iLo, iHi
    LJZ_EDCWB_GetROIIndexPair(w, xLo, xHi, iLo, iHi)

    if (iHi < iLo)
        return NaN
    endif

    Duplicate/O/R=[iLo, iHi] w, $(LJZ_EDCWB_TmpDF() + ":__edcwb_roi_tmp")
    Wave tmp = $(LJZ_EDCWB_TmpDF() + ":__edcwb_roi_tmp")

    WaveStats/Q tmp
    Variable vmax = V_max
    Variable vmin = V_min
    KillWaves/Z tmp

    return max(abs(vmax), abs(vmin))
End

Function LJZ_EDCWB_NormalizeWaveInPlace(w, normMode)
    Wave w
    Variable normMode

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureTmpDF()

    Variable scaleVal = NaN

    if (normMode == 0)
        return 0
    endif

    if (normMode == 1)
        scaleVal = LJZ_EDCWB_WaveAbsMax(w)
    endif

    if (normMode == 2)
        scaleVal = LJZ_EDCWB_WaveTailMeanAbs(w, 0.10)
    endif

    if (normMode == 3)
        NVAR eXLo = $(LJZ_EDCWB_BaseDF() + ":EditXLo")
        NVAR eXHi = $(LJZ_EDCWB_BaseDF() + ":EditXHi")
        scaleVal = LJZ_EDCWB_WaveROIMaxAbs(w, eXLo, eXHi)
    endif

    if (numtype(scaleVal) != 0 || scaleVal == 0)
        return 0
    endif

    w /= scaleVal
    return 0
End

Function/WAVE LJZ_EDCWB_NormalizeWave(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureTmpDF()

    NVAR eNorm = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")

    Wave/Z src = $srcWavePath
    if (!WaveExists(src))
        Wave/Z bad
        return bad
    endif

    String outPath = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, "norm"))
    Duplicate/O src, $outPath
    Wave out = $outPath

    LJZ_EDCWB_NormalizeWaveInPlace(out, eNorm)
    return out
End


// ============================================================================
//  Section 24. Pipeline builders
// ============================================================================
//
// 这里定义几个常用逻辑：
//   - raw display
//   - smooth display
//   - fit input
//   - guess input
//
// 规则：
//   1) raw display = source
//   2) smooth display = source -> optional smooth
//   3) guess input   = source -> optional smooth -> optional sym -> optional norm
//   4) fit input     = source -> optional smooth(if FitOnSmooth) -> optional sym -> optional norm
//
// 注意：sym model 自带建议 sym，但是否真的对称化，统一由 modelID 判断。
// ============================================================================

Function/WAVE LJZ_EDCWB_BuildWorkWave(srcWavePath, doSmooth, doSym, doNorm, suffix)
    String srcWavePath, suffix
    Variable doSmooth, doSym, doNorm

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureTmpDF()

    Wave/Z src = $srcWavePath
    if (!WaveExists(src))
        Wave/Z bad
        return bad
    endif

    String outPath = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, suffix))
    Duplicate/O src, $outPath
    Wave out = $outPath

    // smooth
    if (doSmooth)
        NVAR smEn     = $(LJZ_EDCWB_BaseDF() + ":SmoothEnable")
        NVAR smMethod = $(LJZ_EDCWB_BaseDF() + ":SmoothMethod")
        NVAR smP1     = $(LJZ_EDCWB_BaseDF() + ":SmoothParam1")
        NVAR smP2     = $(LJZ_EDCWB_BaseDF() + ":SmoothParam2")

        if (smEn && smMethod > 0)
            LJZ_EDCWB_ApplySmoothInPlace(out, smMethod, smP1, smP2)
        endif
    endif

    // symmetrize
    if (doSym)
        NVAR eEF = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
        out = out(x) + out(2 * eEF - x)
    endif

    // normalize
    if (doNorm)
        NVAR eNorm = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")
        LJZ_EDCWB_NormalizeWaveInPlace(out, eNorm)
    endif

    return out
End

Function/WAVE LJZ_EDCWB_GetDisplayRawWave(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureTmpDF()

    String outPath = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, "displayRaw"))
    Wave/Z src = $srcWavePath
    if (!WaveExists(src))
        Wave/Z bad
        return bad
    endif

    Duplicate/O src, $outPath
    Wave out = $outPath
    return out
End

Function/WAVE LJZ_EDCWB_GetDisplaySmoothWave(srcWavePath)
    String srcWavePath
    return LJZ_EDCWB_BuildWorkWave(srcWavePath, 1, 0, 0, "displaySmooth")
End

Function/WAVE LJZ_EDCWB_GetGuessInputWave(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()

    NVAR eModel   = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR smGuess  = $(LJZ_EDCWB_BaseDF() + ":UseSmoothForGuess")

    Variable doSmooth = (smGuess != 0)
    Variable doSym    = LJZ_EDCWB_ModelSuggestSymMode(eModel)
    Variable doNorm   = 1

    return LJZ_EDCWB_BuildWorkWave(srcWavePath, doSmooth, doSym, doNorm, "guessInput")
End

Function/WAVE LJZ_EDCWB_GetFitInputWave(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()

    NVAR eModel    = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR fitOnSm   = $(LJZ_EDCWB_BaseDF() + ":FitOnSmooth")

    Variable doSmooth = (fitOnSm != 0)
    Variable doSym    = LJZ_EDCWB_ModelSuggestSymMode(eModel)
    Variable doNorm   = 1

    return LJZ_EDCWB_BuildWorkWave(srcWavePath, doSmooth, doSym, doNorm, "fitInput")
End

Function/WAVE LJZ_EDCWB_GetPrimaryDisplayWave(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()

    NVAR shSm = $(LJZ_EDCWB_BaseDF() + ":ShowSmooth")

    if (shSm)
        return LJZ_EDCWB_GetDisplaySmoothWave(srcWavePath)
    endif

    return LJZ_EDCWB_GetDisplayRawWave(srcWavePath)
End


// ============================================================================
//  Section 25. Source/temporary bookkeeping helpers
// ============================================================================

Function LJZ_EDCWB_RebuildAllWorkWaves(srcWavePath)
    String srcWavePath

    if (!LJZ_EDCWB_SourceWaveExists(srcWavePath))
        return -1
    endif

    Wave/Z w0 = LJZ_EDCWB_GetDisplayRawWave(srcWavePath)
    Wave/Z w1 = LJZ_EDCWB_GetDisplaySmoothWave(srcWavePath)
    Wave/Z w2 = LJZ_EDCWB_GetGuessInputWave(srcWavePath)
    Wave/Z w3 = LJZ_EDCWB_GetFitInputWave(srcWavePath)

    return 0
End

Function LJZ_EDCWB_KillTmpForWave(srcWavePath)
    String srcWavePath

    String tag

    tag = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, "smooth"))
    KillWaves/Z $tag

    tag = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, "sym"))
    KillWaves/Z $tag

    tag = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, "norm"))
    KillWaves/Z $tag

    tag = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, "displayRaw"))
    KillWaves/Z $tag

    tag = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, "displaySmooth"))
    KillWaves/Z $tag

    tag = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, "guessInput"))
    KillWaves/Z $tag

    tag = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, "fitInput"))
    KillWaves/Z $tag

    return 0
End

Function LJZ_EDCWB_KillAllTmp()
    LJZ_EDCWB_EnsureTmpDF()
    KillDataFolder/Z $(LJZ_EDCWB_TmpDF())
    LJZ_EDCWB_EnsureTmpDF()
    return 0
End


// ============================================================================
//  Section 26. Quick diagnostics
// ============================================================================

Function/S LJZ_EDCWB_PreprocessSummary(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()

    NVAR eModel    = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR smEn      = $(LJZ_EDCWB_BaseDF() + ":SmoothEnable")
    NVAR smMethod  = $(LJZ_EDCWB_BaseDF() + ":SmoothMethod")
    NVAR smP1      = $(LJZ_EDCWB_BaseDF() + ":SmoothParam1")
    NVAR smP2      = $(LJZ_EDCWB_BaseDF() + ":SmoothParam2")
    NVAR smGuess   = $(LJZ_EDCWB_BaseDF() + ":UseSmoothForGuess")
    NVAR fitOnSm   = $(LJZ_EDCWB_BaseDF() + ":FitOnSmooth")
    NVAR eNorm     = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")
    NVAR eEF       = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")

    String s = ""
    s += "wave=" + srcWavePath
    s += ";model=" + LJZ_EDCWB_ModelName(eModel)
    s += ";smoothEnable=" + num2str(smEn)
    s += ";smoothMethod=" + num2str(smMethod)
    s += ";smoothP1=" + num2str(smP1)
    s += ";smoothP2=" + num2str(smP2)
    s += ";useSmoothForGuess=" + num2str(smGuess)
    s += ";fitOnSmooth=" + num2str(fitOnSm)
    s += ";normMode=" + num2str(eNorm)
    s += ";EF=" + num2str(eEF)
    s += ";modelSuggestSym=" + num2str(LJZ_EDCWB_ModelSuggestSymMode(eModel))

    return s
End

// ============================================================================
//  LJZ_EDCWB Part 4 : Auto Guess
//  只负责：
//    1) 从 guess input wave 提取粗特征
//    2) 为不同 model 生成稳定初值
//    3) 构造简单 guess curve 供预览
//
//  本部分不负责：
//    - 真正的 nonlinear fitting
//    - panel callbacks
// ============================================================================


// ============================================================================
//  Section 27. Low-level stats helpers
// ============================================================================

Function LJZ_EDCWB_WaveMeanRange(w, iLo, iHi)
    Wave w
    Variable iLo, iHi

    Variable n = numpnts(w)
    if (n <= 0)
        return NaN
    endif

    iLo = LJZ_EDCWB_ClampIndex(iLo, n)
    iHi = LJZ_EDCWB_ClampIndex(iHi, n)
    if (iLo > iHi)
        return NaN
    endif

    Duplicate/O/R=[iLo, iHi] w, $(LJZ_EDCWB_TmpDF() + ":__edcwb_mean_tmp")
    Wave tmp = $(LJZ_EDCWB_TmpDF() + ":__edcwb_mean_tmp")
    WaveStats/Q tmp
    Variable v = V_avg
    KillWaves/Z tmp

    return v
End

Function LJZ_EDCWB_WaveStdRange(w, iLo, iHi)
    Wave w
    Variable iLo, iHi

    Variable n = numpnts(w)
    if (n <= 1)
        return NaN
    endif

    iLo = LJZ_EDCWB_ClampIndex(iLo, n)
    iHi = LJZ_EDCWB_ClampIndex(iHi, n)
    if (iLo > iHi)
        return NaN
    endif

    Duplicate/O/R=[iLo, iHi] w, $(LJZ_EDCWB_TmpDF() + ":__edcwb_std_tmp")
    Wave tmp = $(LJZ_EDCWB_TmpDF() + ":__edcwb_std_tmp")
    WaveStats/Q tmp
    Variable v = V_sdev
    KillWaves/Z tmp

    return v
End

Function LJZ_EDCWB_WaveArgMaxRange(w, iLo, iHi)
    Wave w
    Variable iLo, iHi

    Variable n = numpnts(w)
    if (n <= 0)
        return -1
    endif

    iLo = LJZ_EDCWB_ClampIndex(iLo, n)
    iHi = LJZ_EDCWB_ClampIndex(iHi, n)
    if (iLo > iHi)
        return -1
    endif

    Variable i, imax = iLo
    Variable vmax = w[iLo]

    for (i = iLo + 1; i <= iHi; i += 1)
        if (w[i] > vmax)
            vmax = w[i]
            imax = i
        endif
    endfor

    return imax
End

Function LJZ_EDCWB_WaveArgMinRange(w, iLo, iHi)
    Wave w
    Variable iLo, iHi

    Variable n = numpnts(w)
    if (n <= 0)
        return -1
    endif

    iLo = LJZ_EDCWB_ClampIndex(iLo, n)
    iHi = LJZ_EDCWB_ClampIndex(iHi, n)
    if (iLo > iHi)
        return -1
    endif

    Variable i, imin = iLo
    Variable vmin = w[iLo]

    for (i = iLo + 1; i <= iHi; i += 1)
        if (w[i] < vmin)
            vmin = w[i]
            imin = i
        endif
    endfor

    return imin
End

Function LJZ_EDCWB_IndexToX(w, idx)
    Wave w
    Variable idx

    return DimOffset(w, 0) + idx * DimDelta(w, 0)
End

Function LJZ_EDCWB_HalfHeightWidth(w, iPeak, bgVal)
    Wave w
    Variable iPeak, bgVal

    Variable n = numpnts(w)
    if (n < 3)
        return NaN
    endif

    iPeak = LJZ_EDCWB_ClampIndex(iPeak, n)

    Variable yPeak = w[iPeak]
    Variable level = bgVal + 0.5 * (yPeak - bgVal)

    Variable iL = iPeak
    do
        if (iL <= 0)
            break
        endif
        if (w[iL] <= level)
            break
        endif
        iL -= 1
    while (1)

    Variable iR = iPeak
    do
        if (iR >= n - 1)
            break
        endif
        if (w[iR] <= level)
            break
        endif
        iR += 1
    while (1)

    Variable xL = LJZ_EDCWB_IndexToX(w, iL)
    Variable xR = LJZ_EDCWB_IndexToX(w, iR)

    return abs(xR - xL)
End


// ============================================================================
//  Section 28. ROI-aware helpers
// ============================================================================

Function LJZ_EDCWB_GetGuessROIPair(w, iLo, iHi)
    Wave w
    Variable &iLo, &iHi

    LJZ_EDCWB_EnsureDF()

    NVAR eXLo = $(LJZ_EDCWB_BaseDF() + ":EditXLo")
    NVAR eXHi = $(LJZ_EDCWB_BaseDF() + ":EditXHi")

    LJZ_EDCWB_GetROIIndexPair(w, eXLo, eXHi, iLo, iHi)

    if (iHi < iLo)
        iLo = 0
        iHi = numpnts(w) - 1
    endif

    return 0
End

Function LJZ_EDCWB_EstimateLinearBG(w, iLo, iHi, bg0, bg1)
    Wave w
    Variable iLo, iHi
    Variable &bg0, &bg1

    Variable n = numpnts(w)
    if (n < 4)
        bg0 = 0
        bg1 = 0
        return 0
    endif

    iLo = LJZ_EDCWB_ClampIndex(iLo, n)
    iHi = LJZ_EDCWB_ClampIndex(iHi, n)
    if (iLo > iHi)
        bg0 = 0
        bg1 = 0
        return 0
    endif

    Variable span = iHi - iLo + 1
    Variable nEdge = round(span * 0.12)
    if (nEdge < 2)
        nEdge = 2
    endif
    if (nEdge > span / 2)
        nEdge = floor(span / 2)
    endif
    if (nEdge < 1)
        nEdge = 1
    endif

    Variable l0 = iLo
    Variable l1 = min(iLo + nEdge - 1, iHi)
    Variable r0 = max(iHi - nEdge + 1, iLo)
    Variable r1 = iHi

    Variable yL = LJZ_EDCWB_WaveMeanRange(w, l0, l1)
    Variable yR = LJZ_EDCWB_WaveMeanRange(w, r0, r1)

    Variable xL = 0.5 * (LJZ_EDCWB_IndexToX(w, l0) + LJZ_EDCWB_IndexToX(w, l1))
    Variable xR = 0.5 * (LJZ_EDCWB_IndexToX(w, r0) + LJZ_EDCWB_IndexToX(w, r1))

    if (numtype(yL) != 0 || numtype(yR) != 0 || xR == xL)
        bg0 = yL
        bg1 = 0
        return 0
    endif

    bg1 = (yR - yL) / (xR - xL)
    bg0 = yL - bg1 * xL

    return 0
End


// ============================================================================
//  Section 29. Model-specific guess helpers
// ============================================================================

Function LJZ_EDCWB_Guess_SinglePeakFDConv(w, wPar)
    Wave w, wPar

    Variable iLo, iHi
    LJZ_EDCWB_GetGuessROIPair(w, iLo, iHi)

    Variable bg0, bg1
    LJZ_EDCWB_EstimateLinearBG(w, iLo, iHi, bg0, bg1)

    Variable iPeak = LJZ_EDCWB_WaveArgMaxRange(w, iLo, iHi)
    if (iPeak < 0)
        iPeak = round(0.5 * (iLo + iHi))
    endif

    Variable xPeak = LJZ_EDCWB_IndexToX(w, iPeak)
    Variable yPeak = w[iPeak]
    Variable bgAtPeak = bg0 + bg1 * xPeak
    Variable amp = yPeak - bgAtPeak

    if (numtype(amp) != 0 || amp <= 0)
        amp = max(1e-3, abs(yPeak))
    endif

    Variable fwhm = LJZ_EDCWB_HalfHeightWidth(w, iPeak, bgAtPeak)
    if (numtype(fwhm) != 0 || fwhm <= 0)
        fwhm = abs(DimDelta(w, 0)) * 6
    endif

    if (fwhm <= 0)
        fwhm = 0.02
    endif

    Variable modelID = LJZ_EDCWB_Model_SinglePeakFDConv()

    LJZ_EDCWB_SetParValue(modelID, wPar, "bg0", bg0)
    LJZ_EDCWB_SetParValue(modelID, wPar, "bg1", bg1)
    LJZ_EDCWB_SetParValue(modelID, wPar, "A",   amp)
    LJZ_EDCWB_SetParValue(modelID, wPar, "x0",  xPeak)
    LJZ_EDCWB_SetParValue(modelID, wPar, "w",   max(fwhm, 1e-4))
    LJZ_EDCWB_SetParValue(modelID, wPar, "eta", 0.5)

    // T / EF / res 走 runtime 当前值
    NVAR eTemp = $(LJZ_EDCWB_BaseDF() + ":EditTemperature")
    NVAR eEF   = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    NVAR eRes  = $(LJZ_EDCWB_BaseDF() + ":EditResolution")

    LJZ_EDCWB_SetParValue(modelID, wPar, "T",   eTemp)
    LJZ_EDCWB_SetParValue(modelID, wPar, "EF",  eEF)
    LJZ_EDCWB_SetParValue(modelID, wPar, "res", eRes)

    return 0
End

Function LJZ_EDCWB_Guess_EffectiveGap(w, wPar)
    Wave w, wPar

    LJZ_EDCWB_EnsureDF()

    Variable iLo, iHi
    LJZ_EDCWB_GetGuessROIPair(w, iLo, iHi)

    Variable bg0, bg1
    LJZ_EDCWB_EstimateLinearBG(w, iLo, iHi, bg0, bg1)

    Variable iPeak = LJZ_EDCWB_WaveArgMaxRange(w, iLo, iHi)
    if (iPeak < 0)
        iPeak = round(0.5 * (iLo + iHi))
    endif

    NVAR eEF = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    Variable xPeak = LJZ_EDCWB_IndexToX(w, iPeak)
    Variable yPeak = w[iPeak]
    Variable bgAtPeak = bg0 + bg1 * xPeak
    Variable amp = yPeak - bgAtPeak
    if (numtype(amp) != 0 || amp <= 0)
        amp = max(1e-3, abs(yPeak))
    endif

    Variable delta0 = abs(xPeak - eEF)

    // 若 peak 恰好贴 EF，给一个保守的小 gap 初值
    if (numtype(delta0) != 0 || delta0 < 2 * abs(DimDelta(w, 0)))
        delta0 = max(4 * abs(DimDelta(w, 0)), 0.01)
    endif

    Variable gamma0 = 0.5 * delta0
    if (gamma0 < abs(DimDelta(w, 0)))
        gamma0 = max(abs(DimDelta(w, 0)), 0.005)
    endif

    Variable modelID = LJZ_EDCWB_Model_EffectiveGap()

    LJZ_EDCWB_SetParValue(modelID, wPar, "bg0",   bg0)
    LJZ_EDCWB_SetParValue(modelID, wPar, "bg1",   bg1)
    LJZ_EDCWB_SetParValue(modelID, wPar, "A",     amp)
    LJZ_EDCWB_SetParValue(modelID, wPar, "Delta", delta0)
    LJZ_EDCWB_SetParValue(modelID, wPar, "Gamma", gamma0)

    NVAR eTemp = $(LJZ_EDCWB_BaseDF() + ":EditTemperature")
    NVAR eRes  = $(LJZ_EDCWB_BaseDF() + ":EditResolution")

    LJZ_EDCWB_SetParValue(modelID, wPar, "T",   eTemp)
    LJZ_EDCWB_SetParValue(modelID, wPar, "EF",  eEF)
    LJZ_EDCWB_SetParValue(modelID, wPar, "res", eRes)

    return 0
End

Function LJZ_EDCWB_Guess_SymGap(w, wPar)
    Wave w, wPar

    Variable iLo, iHi
    LJZ_EDCWB_GetGuessROIPair(w, iLo, iHi)

    Variable bg0, bg1
    LJZ_EDCWB_EstimateLinearBG(w, iLo, iHi, bg0, bg1)

    Variable iPeak = LJZ_EDCWB_WaveArgMaxRange(w, iLo, iHi)
    if (iPeak < 0)
        iPeak = round(0.5 * (iLo + iHi))
    endif

    Variable xPeak = LJZ_EDCWB_IndexToX(w, iPeak)
    Variable yPeak = w[iPeak]
    Variable bgAtPeak = bg0 + bg1 * xPeak
    Variable amp = yPeak - bgAtPeak
    if (numtype(amp) != 0 || amp <= 0)
        amp = max(1e-3, abs(yPeak))
    endif

    // 对称化后中心一般在 0（如果之前用 EF 做中心）
    // 但为了稳妥，仍允许 x0 浮动一点
    Variable delta0 = abs(xPeak)
    if (numtype(delta0) != 0 || delta0 < 2 * abs(DimDelta(w, 0)))
        delta0 = max(4 * abs(DimDelta(w, 0)), 0.01)
    endif

    Variable gamma0 = 0.5 * delta0
    if (gamma0 < abs(DimDelta(w, 0)))
        gamma0 = max(abs(DimDelta(w, 0)), 0.005)
    endif

    Variable modelID = LJZ_EDCWB_Model_SymGap()

    LJZ_EDCWB_SetParValue(modelID, wPar, "bg0",   bg0)
    LJZ_EDCWB_SetParValue(modelID, wPar, "bg1",   bg1)
    LJZ_EDCWB_SetParValue(modelID, wPar, "A",     amp)
    LJZ_EDCWB_SetParValue(modelID, wPar, "Delta", delta0)
    LJZ_EDCWB_SetParValue(modelID, wPar, "Gamma", gamma0)
    LJZ_EDCWB_SetParValue(modelID, wPar, "x0",    0)

    return 0
End


// ============================================================================
//  Section 30. Guess curve builders (light preview version)
// ============================================================================
//
// 这里只构造“可视化 preview 用的近似 guess curve”，
// 不追求和最终 fit engine 完全同一公式。
// 真正拟合时再换成更严格的 model evaluator。
// ============================================================================

Function LJZ_EDCWB_FDValue(x, T, EF)
    Variable x, T, EF

    Variable kB = 8.617333262e-5    // eV/K
    Variable betaArg

    if (T <= 0)
        if (x < EF)
            return 1
        else
            return 0
        endif
    endif

    betaArg = (x - EF) / (kB * T)

    // 防止 exp 溢出
    if (betaArg > 80)
        return 0
    endif
    if (betaArg < -80)
        return 1
    endif

    return 1 / (exp(betaArg) + 1)
End

Function LJZ_EDCWB_LorentzValue(x, x0, w)
    Variable x, x0, w

    if (w <= 0)
        w = 1e-4
    endif

    return 1 / (1 + ((x - x0) / w)^2)
End

Function LJZ_EDCWB_GaussValue(x, x0, s)
    Variable x, x0, s

    if (s <= 0)
        s = 1e-4
    endif

    return exp(-0.5 * ((x - x0) / s)^2)
End

Function/WAVE LJZ_EDCWB_BuildGuessCurveFromPar(srcWavePath, wPar)
    String srcWavePath
    Wave wPar

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureTmpDF()

    NVAR eModel = $(LJZ_EDCWB_BaseDF() + ":EditModelID")

    Wave/Z wRef = LJZ_EDCWB_GetGuessInputWave(srcWavePath)
    if (!WaveExists(wRef))
        Wave/Z bad
        return bad
    endif

    String outPath = LJZ_EDCWB_TmpWavePath(LJZ_EDCWB_SafeTmpTag(srcWavePath, "guessCurve"))
    Duplicate/O wRef, $outPath
    Wave out = $outPath

    Variable bg0, bg1, A, x0, w, eta, T, EF, res, Delta, Gamma
    Variable i

    if (eModel == LJZ_EDCWB_Model_SinglePeakFDConv())
        bg0 = LJZ_EDCWB_GetParValue(eModel, wPar, "bg0")
        bg1 = LJZ_EDCWB_GetParValue(eModel, wPar, "bg1")
        A   = LJZ_EDCWB_GetParValue(eModel, wPar, "A")
        x0  = LJZ_EDCWB_GetParValue(eModel, wPar, "x0")
        w   = LJZ_EDCWB_GetParValue(eModel, wPar, "w")
        eta = LJZ_EDCWB_GetParValue(eModel, wPar, "eta")
        T   = LJZ_EDCWB_GetParValue(eModel, wPar, "T")
        EF  = LJZ_EDCWB_GetParValue(eModel, wPar, "EF")

        if (numtype(eta) != 0)
            eta = 0.5
        endif

        // 这里先用 pseudo-Voigt 的简化预览，不做严格 resolution convolution
        out = (bg0 + bg1 * x) + A * (eta * LJZ_EDCWB_LorentzValue(x, x0, w) + (1 - eta) * LJZ_EDCWB_GaussValue(x, x0, max(w, 1e-4)))
        out *= LJZ_EDCWB_FDValue(x, T, EF)
        return out
    endif

    if (eModel == LJZ_EDCWB_Model_EffectiveGap())
        bg0   = LJZ_EDCWB_GetParValue(eModel, wPar, "bg0")
        bg1   = LJZ_EDCWB_GetParValue(eModel, wPar, "bg1")
        A     = LJZ_EDCWB_GetParValue(eModel, wPar, "A")
        Delta = LJZ_EDCWB_GetParValue(eModel, wPar, "Delta")
        Gamma = LJZ_EDCWB_GetParValue(eModel, wPar, "Gamma")
        T     = LJZ_EDCWB_GetParValue(eModel, wPar, "T")
        EF    = LJZ_EDCWB_GetParValue(eModel, wPar, "EF")

        if (numtype(Delta) != 0 || Delta <= 0)
            Delta = 0.01
        endif
        if (numtype(Gamma) != 0 || Gamma <= 0)
            Gamma = 0.005
        endif

        // 这里先用一个“gap-edge 双峰包络”的预览近似
        out = (bg0 + bg1 * x) + A * (LJZ_EDCWB_GaussValue(x, EF - Delta, Gamma) + 0.7 * LJZ_EDCWB_GaussValue(x, EF + Delta, Gamma))
        out *= LJZ_EDCWB_FDValue(x, T, EF)
        return out
    endif

    if (eModel == LJZ_EDCWB_Model_SymGap())
        bg0   = LJZ_EDCWB_GetParValue(eModel, wPar, "bg0")
        bg1   = LJZ_EDCWB_GetParValue(eModel, wPar, "bg1")
        A     = LJZ_EDCWB_GetParValue(eModel, wPar, "A")
        Delta = LJZ_EDCWB_GetParValue(eModel, wPar, "Delta")
        Gamma = LJZ_EDCWB_GetParValue(eModel, wPar, "Gamma")
        x0    = LJZ_EDCWB_GetParValue(eModel, wPar, "x0")

        if (numtype(x0) != 0)
            x0 = 0
        endif
        if (numtype(Delta) != 0 || Delta <= 0)
            Delta = 0.01
        endif
        if (numtype(Gamma) != 0 || Gamma <= 0)
            Gamma = 0.005
        endif

        out = (bg0 + bg1 * x) + A * (LJZ_EDCWB_GaussValue(x, x0 - Delta, Gamma) + LJZ_EDCWB_GaussValue(x, x0 + Delta, Gamma))
        return out
    endif

    out = NaN
    return out
End


// ============================================================================
//  Section 31. Main AutoGuess entry
// ============================================================================

Function LJZ_EDCWB_AutoInitGuess(srcWavePath, modelID)
    String srcWavePath
    Variable modelID

    LJZ_EDCWB_EnsureDF()

    if (!LJZ_EDCWB_SourceWaveExists(srcWavePath))
        return -1
    endif
    if (!LJZ_EDCWB_ModelIsValid(modelID))
        return -1
    endif

    // 切 model，更新参数布局与默认 hold
    LJZ_EDCWB_SetModel(modelID)

    Wave/Z wIn = LJZ_EDCWB_GetGuessInputWave(srcWavePath)
    if (!WaveExists(wIn))
        return -1
    endif

    Wave wPar = $(LJZ_EDCWB_BaseDF() + ":EditPar")

    // 先用默认值打底
    LJZ_EDCWB_FillNaNParsWithDefaults(modelID)

    if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
        LJZ_EDCWB_Guess_SinglePeakFDConv(wIn, wPar)
    elseif (modelID == LJZ_EDCWB_Model_EffectiveGap())
        LJZ_EDCWB_Guess_EffectiveGap(wIn, wPar)
    elseif (modelID == LJZ_EDCWB_Model_SymGap())
        LJZ_EDCWB_Guess_SymGap(wIn, wPar)
    else
        return -1
    endif

    LJZ_EDCWB_SanitizeParamWave(modelID, wPar)
    LJZ_EDCWB_SyncParToAuxState()
    LJZ_EDCWB_MarkDirty(1)

    return 0
End

Function LJZ_EDCWB_AutoGuessCurrent()
    LJZ_EDCWB_EnsureDF()

    SVAR sPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR eModel = $(LJZ_EDCWB_BaseDF() + ":EditModelID")

    if (strlen(sPath) == 0)
        return -1
    endif

    return LJZ_EDCWB_AutoInitGuess(sPath, eModel)
End


// ============================================================================
//  Section 32. Save preview guess curve
// ============================================================================

Function LJZ_EDCWB_BuildAndSaveGuessCurve(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()

    Wave wPar = $(LJZ_EDCWB_BaseDF() + ":EditPar")
    Wave/Z wGuess = LJZ_EDCWB_BuildGuessCurveFromPar(srcWavePath, wPar)
    if (!WaveExists(wGuess))
        return -1
    endif

    LJZ_EDCWB_SaveGuessCurve(srcWavePath, wGuess)
    return 0
End

Function LJZ_EDCWB_AutoGuessAndSave(srcWavePath, modelID)
    String srcWavePath
    Variable modelID

    Variable ok = LJZ_EDCWB_AutoInitGuess(srcWavePath, modelID)
    if (ok != 0)
        return ok
    endif

    ok = LJZ_EDCWB_BuildAndSaveGuessCurve(srcWavePath)
    if (ok != 0)
        return ok
    endif

    // 同时把当前 edit 参数写入 fitcoef / fitinfo，方便 panel 直接载入
    LJZ_EDCWB_SaveCurrentEditToCoef(srcWavePath)
    LJZ_EDCWB_ClearStoredFitOutputs(srcWavePath)

    return 0
End


// ============================================================================
//  Section 33. Simple diagnostics
// ============================================================================

Function/S LJZ_EDCWB_AutoGuessSummary(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()

    Wave wPar = $(LJZ_EDCWB_BaseDF() + ":EditPar")
    NVAR eModel = $(LJZ_EDCWB_BaseDF() + ":EditModelID")

    String s = ""
    Variable i

    s += "model=" + LJZ_EDCWB_ModelName(eModel)

    for (i = 0; i < 12; i += 1)
        if (LJZ_EDCWB_ParamEnabled(eModel, i))
            s += ";" + LJZ_EDCWB_ParamName(eModel, i) + "=" + num2str(wPar[i])
        endif
    endfor

    return s
End

// ============================================================================
//  LJZ_EDCWB Part 5 : Fit Engine (v1)
//  只负责：
//    1) fit-engine skeleton
//    2) single peak model fitting with FuncFit
//    3) save fit curve / residual / sigma / fitinfo
//
//  本部分当前只完整实现：
//    - SinglePeak*FD*GaussConv  --> first-pass runnable approximation
//
//  预留：
//    - EffectiveGap
//    - SymGap
// ============================================================================


// ============================================================================
//  Section 34. Fit-function evaluators
// ============================================================================

Function LJZ_EDCWB_FitFDValue(x, T, EF)
    Variable x, T, EF

    Variable kB = 8.617333262e-5    // eV/K
    Variable arg

    if (T <= 0)
        if (x < EF)
            return 1
        else
            return 0
        endif
    endif

    arg = (x - EF) / (kB * T)

    if (arg > 80)
        return 0
    endif
    if (arg < -80)
        return 1
    endif

    return 1 / (exp(arg) + 1)
End

Function LJZ_EDCWB_FitLor(x, x0, w)
    Variable x, x0, w

    if (w <= 0)
        w = 1e-4
    endif

    return 1 / (1 + ((x - x0) / w)^2)
End

Function LJZ_EDCWB_FitGau(x, x0, w)
    Variable x, x0, w

    if (w <= 0)
        w = 1e-4
    endif

    return exp(-0.5 * ((x - x0) / w)^2)
End

// --------------------------------------------------------------------------
// SinglePeak*FD*GaussConv : first-pass runnable approximation
// coef layout:
//   0 bg0
//   1 bg1
//   2 A
//   3 x0
//   4 w
//   5 eta
//   6 T
//   7 EF
//   8 res   (currently reserved, not explicitly convolved in v1)
// --------------------------------------------------------------------------
Function LJZ_EDCWB_FitFunc_SinglePeakFDConv(coef, x) : FitFunc
    Wave coef
    Variable x

    Variable bg0 = coef[0]
    Variable bg1 = coef[1]
    Variable A   = coef[2]
    Variable x0  = coef[3]
    Variable w   = coef[4]
    Variable eta = coef[5]
    Variable T   = coef[6]
    Variable EF  = coef[7]

    if (eta < 0)
        eta = 0
    endif
    if (eta > 1)
        eta = 1
    endif
    if (w <= 0)
        w = 1e-4
    endif

    Variable peak = eta * LJZ_EDCWB_FitLor(x, x0, w) + (1 - eta) * LJZ_EDCWB_FitGau(x, x0, w)
    Variable fd   = LJZ_EDCWB_FitFDValue(x, T, EF)

    return (bg0 + bg1 * x + A * peak) * fd
End


// ============================================================================
//  Section 35. Coefficient / hold helpers
// ============================================================================

Function/S LJZ_EDCWB_BuildHoldStringForModel(modelID, wHold)
    Variable modelID
    Wave wHold

    Variable nPar = LJZ_EDCWB_ModelNPar(modelID)
    String s = ""
    Variable i

    for (i = 0; i < nPar; i += 1)
        if (i < numpnts(wHold) && wHold[i] != 0)
            s += "1"
        else
            s += "0"
        endif
    endfor

    return s
End

Function LJZ_EDCWB_MakeActiveCoefWave(modelID, wEditPar, outPath)
    Variable modelID
    Wave wEditPar
    String outPath

    Variable nPar = LJZ_EDCWB_ModelNPar(modelID)
    if (nPar <= 0)
        return -1
    endif

    Make/D/O/N=(nPar) $outPath
    Wave wOut = $outPath

    Variable i
    for (i = 0; i < nPar; i += 1)
        if (i < numpnts(wEditPar) && numtype(wEditPar[i]) == 0)
            wOut[i] = wEditPar[i]
        else
            wOut[i] = LJZ_EDCWB_ParamDefaultValue(modelID, i)
        endif
    endfor

    return 0
End

Function LJZ_EDCWB_CopyActiveCoefToEditPar(modelID, wCoef, wEditPar)
    Variable modelID
    Wave wCoef, wEditPar

    Variable nPar = LJZ_EDCWB_ModelNPar(modelID)
    Variable i

    for (i = 0; i < 12; i += 1)
        if (!LJZ_EDCWB_ParamEnabled(modelID, i))
            wEditPar[i] = NaN
            continue
        endif

        if (i < nPar && i < numpnts(wCoef))
            wEditPar[i] = wCoef[i]
        endif
    endfor

    return 0
End

Function LJZ_EDCWB_CopySigmaToLen12(modelID, wSigmaIn, wSigmaOut12)
    Variable modelID
    Wave wSigmaIn, wSigmaOut12

    Variable i, nPar = LJZ_EDCWB_ModelNPar(modelID)

    wSigmaOut12 = NaN
    for (i = 0; i < 12; i += 1)
        if (!LJZ_EDCWB_ParamEnabled(modelID, i))
            continue
        endif

        if (i < nPar && i < numpnts(wSigmaIn))
            wSigmaOut12[i] = wSigmaIn[i]
        endif
    endfor

    return 0
End


// ============================================================================
//  Section 36. ROI build helpers for fitting
// ============================================================================

Function LJZ_EDCWB_BuildFitROIWaves(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureTmpDF()

    Wave/Z wFitIn = LJZ_EDCWB_GetFitInputWave(srcWavePath)
    if (!WaveExists(wFitIn))
        return -1
    endif

    Variable iLo, iHi
    NVAR eXLo = $(LJZ_EDCWB_BaseDF() + ":EditXLo")
    NVAR eXHi = $(LJZ_EDCWB_BaseDF() + ":EditXHi")
    LJZ_EDCWB_GetROIIndexPair(wFitIn, eXLo, eXHi, iLo, iHi)

    if (iHi < iLo)
        iLo = 0
        iHi = numpnts(wFitIn) - 1
    endif

    Duplicate/O/R=[iLo, iHi] wFitIn, $(LJZ_EDCWB_TmpDF() + ":fitY")
    Wave fitY = $(LJZ_EDCWB_TmpDF() + ":fitY")

    Make/D/O/N=(numpnts(fitY)) $(LJZ_EDCWB_TmpDF() + ":fitX")
    Wave fitX = $(LJZ_EDCWB_TmpDF() + ":fitX")
    fitX = DimOffset(wFitIn, 0) + (p + iLo) * DimDelta(wFitIn, 0)

    Variable/G $(LJZ_EDCWB_TmpDF() + ":Fit_iLo") = iLo
    Variable/G $(LJZ_EDCWB_TmpDF() + ":Fit_iHi") = iHi

    return 0
End

Function LJZ_EDCWB_GetLastFitROIRange(iLo, iHi)
    Variable &iLo, &iHi

    NVAR/Z vLo = $(LJZ_EDCWB_TmpDF() + ":Fit_iLo")
    NVAR/Z vHi = $(LJZ_EDCWB_TmpDF() + ":Fit_iHi")

    if (!NVAR_Exists(vLo) || !NVAR_Exists(vHi))
        iLo = 0
        iHi = -1
        return -1
    endif

    iLo = vLo
    iHi = vHi
    return 0
End


// ============================================================================
//  Section 37. Full-wave evaluation helpers
// ============================================================================

Function LJZ_EDCWB_EvalSinglePeakWave(wXRef, wCoef, wOut)
    Wave wXRef, wCoef, wOut

    Variable n = numpnts(wXRef)
    if (n != numpnts(wOut))
        return -1
    endif

    Variable i, xv
    for (i = 0; i < n; i += 1)
        xv = DimOffset(wXRef, 0) + i * DimDelta(wXRef, 0)
        wOut[i] = LJZ_EDCWB_FitFunc_SinglePeakFDConv(wCoef, xv)
    endfor

    return 0
End


// ============================================================================
//  Section 38. Metrics helpers
// ============================================================================

Function LJZ_EDCWB_RMSEBetweenWaves(wA, wB)
    Wave wA, wB

    Variable n = min(numpnts(wA), numpnts(wB))
    if (n <= 0)
        return NaN
    endif

    Make/D/O/N=(n) $(LJZ_EDCWB_TmpDF() + ":__edcwb_rmse_tmp")
    Wave tmp = $(LJZ_EDCWB_TmpDF() + ":__edcwb_rmse_tmp")
    tmp = (wA[p] - wB[p])^2

    WaveStats/Q tmp
    Variable v = sqrt(V_avg)
    KillWaves/Z tmp

    return v
End

Function LJZ_EDCWB_MaxAbsWave(w)
    Wave w

    if (numpnts(w) <= 0)
        return NaN
    endif

    WaveStats/Q w
    return max(abs(V_max), abs(V_min))
End


// ============================================================================
//  Section 39. Save fit result helpers
// ============================================================================

Function LJZ_EDCWB_SaveFitResultSinglePeak(srcWavePath, wCoefActive, wSigmaActive, fitOK)
    String srcWavePath
    Wave wCoefActive, wSigmaActive
    Variable fitOK

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Variable modelID = LJZ_EDCWB_Model_SinglePeakFDConv()

    Wave wEditPar = $(LJZ_EDCWB_BaseDF() + ":EditPar")
    Wave wEditHold = $(LJZ_EDCWB_BaseDF() + ":EditHold")

    // 1) active coef -> edit par
    LJZ_EDCWB_CopyActiveCoefToEditPar(modelID, wCoefActive, wEditPar)
    LJZ_EDCWB_SanitizeParamWave(modelID, wEditPar)
    LJZ_EDCWB_SyncParToAuxState()

    // 2) save coef/sigma/info
    Make/D/O/N=12 $(LJZ_EDCWB_TmpDF() + ":fitcoef12")
    Make/D/O/N=12 $(LJZ_EDCWB_TmpDF() + ":fitsigma12")
    Make/D/O/N=16 $(LJZ_EDCWB_TmpDF() + ":fitinfo16")
    Wave fitcoef12 = $(LJZ_EDCWB_TmpDF() + ":fitcoef12")
    Wave fitsigma12 = $(LJZ_EDCWB_TmpDF() + ":fitsigma12")
    Wave fitinfo16 = $(LJZ_EDCWB_TmpDF() + ":fitinfo16")

    fitcoef12 = NaN
    fitcoef12 = wEditPar[p]

    LJZ_EDCWB_CopySigmaToLen12(modelID, wSigmaActive, fitsigma12)

    fitinfo16 = NaN

    NVAR eXLo   = $(LJZ_EDCWB_BaseDF() + ":EditXLo")
    NVAR eXHi   = $(LJZ_EDCWB_BaseDF() + ":EditXHi")
    NVAR eTemp  = $(LJZ_EDCWB_BaseDF() + ":EditTemperature")
    NVAR eEF    = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    NVAR eRes   = $(LJZ_EDCWB_BaseDF() + ":EditResolution")
    NVAR eNorm  = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")
    NVAR fitOnSm = $(LJZ_EDCWB_BaseDF() + ":FitOnSmooth")

    fitinfo16[LJZ_EDCWB_FI_ModelID()]     = modelID
    fitinfo16[LJZ_EDCWB_FI_XLo()]         = eXLo
    fitinfo16[LJZ_EDCWB_FI_XHi()]         = eXHi
    fitinfo16[LJZ_EDCWB_FI_FitOK()]       = fitOK
    fitinfo16[LJZ_EDCWB_FI_Temperature()] = eTemp
    fitinfo16[LJZ_EDCWB_FI_Resolution()]  = eRes
    fitinfo16[LJZ_EDCWB_FI_EFermi()]      = eEF
    fitinfo16[LJZ_EDCWB_FI_NormMode()]    = eNorm
    fitinfo16[LJZ_EDCWB_FI_SmoothUsed()]  = fitOnSm

    // 3) build full fit/res wave on fitInput scale
    Wave wFitIn = LJZ_EDCWB_GetFitInputWave(srcWavePath)
    Duplicate/O wFitIn, $(LJZ_EDCWB_TmpDF() + ":fitFull")
    Duplicate/O wFitIn, $(LJZ_EDCWB_TmpDF() + ":resFull")
    Wave fitFull = $(LJZ_EDCWB_TmpDF() + ":fitFull")
    Wave resFull = $(LJZ_EDCWB_TmpDF() + ":resFull")

    LJZ_EDCWB_EvalSinglePeakWave(wFitIn, wCoefActive, fitFull)
    resFull = wFitIn[p] - fitFull[p]

    fitinfo16[LJZ_EDCWB_FI_FitRMSE()]   = LJZ_EDCWB_RMSEBetweenWaves(wFitIn, fitFull)
    fitinfo16[LJZ_EDCWB_FI_MaxAbsRes()] = LJZ_EDCWB_MaxAbsWave(resFull)

    Variable iLo, iHi
    if (LJZ_EDCWB_GetLastFitROIRange(iLo, iHi) == 0)
        fitinfo16[LJZ_EDCWB_FI_NROI()] = iHi - iLo + 1
    endif

    NVAR/Z vChi = V_chisq
    if (NVAR_Exists(vChi))
        fitinfo16[LJZ_EDCWB_FI_ChiSq()] = vChi
    endif

    LJZ_EDCWB_SaveFitCurve(srcWavePath, fitFull, resFull)
    LJZ_EDCWB_SaveFitVectors(srcWavePath, fitcoef12, fitsigma12, fitinfo16)

    return 0
End


// ============================================================================
//  Section 40. Main fitting entry (single peak implemented)
// ============================================================================

Function LJZ_EDCWB_DoFitSinglePeak(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureTmpDF()

    if (!LJZ_EDCWB_SourceWaveExists(srcWavePath))
        return -1
    endif

    // build ROI waves
    Variable ok = LJZ_EDCWB_BuildFitROIWaves(srcWavePath)
    if (ok != 0)
        return -1
    endif

    Wave fitY = $(LJZ_EDCWB_TmpDF() + ":fitY")
    Wave fitX = $(LJZ_EDCWB_TmpDF() + ":fitX")
    if (!WaveExists(fitY) || !WaveExists(fitX))
        return -1
    endif
    if (numpnts(fitY) < 5)
        return -1
    endif

    Variable modelID = LJZ_EDCWB_Model_SinglePeakFDConv()

    // make active coefficient wave
    Wave wEditPar  = $(LJZ_EDCWB_BaseDF() + ":EditPar")
    Wave wEditHold = $(LJZ_EDCWB_BaseDF() + ":EditHold")

    ok = LJZ_EDCWB_MakeActiveCoefWave(modelID, wEditPar, LJZ_EDCWB_TmpDF() + ":coefActive")
    if (ok != 0)
        return -1
    endif

    Wave coefActive = $(LJZ_EDCWB_TmpDF() + ":coefActive")
    LJZ_EDCWB_SanitizeParamWave(modelID, coefActive)

    String holdStr = LJZ_EDCWB_BuildHoldStringForModel(modelID, wEditHold)

    // 先做一条 guess curve 方便比较
    LJZ_EDCWB_BuildAndSaveGuessCurve(srcWavePath)

    // do fit
    // Curve fitting on XY data with explicit X wave is standard Igor usage. Manual examples
    // show /X=... with /D and /R residual output. :contentReference[oaicite:0]{index=0}
    FuncFit/H=holdStr/Q LJZ_EDCWB_FitFunc_SinglePeakFDConv coefActive fitY /X=fitX

    // sigma
    Wave/Z W_sigma
    if (!WaveExists(W_sigma))
        Make/D/O/N=(numpnts(coefActive)) $(LJZ_EDCWB_TmpDF() + ":sigmaActive") = NaN
    else
        Duplicate/O W_sigma, $(LJZ_EDCWB_TmpDF() + ":sigmaActive")
    endif
    Wave sigmaActive = $(LJZ_EDCWB_TmpDF() + ":sigmaActive")

    Variable fitOK = 1
    NVAR/Z vFitError = V_FitError
    if (NVAR_Exists(vFitError) && vFitError != 0)
        fitOK = 0
    endif

    LJZ_EDCWB_SaveFitResultSinglePeak(srcWavePath, coefActive, sigmaActive, fitOK)
    if (!fitOK)
        return -2
    endif

    LJZ_EDCWB_MarkDirty(0)
    return 0
End


// ============================================================================
//  Section 41-42 removed (legacy dispatcher/refit/batch)
//  Keep Part 5B implementations as the single source of truth.
// ============================================================================

// ============================================================================
//  LJZ_EDCWB Part 5B : Fit Engine extensions
//  替换旧的 dispatcher / save helpers / single-peak-only engine
// ============================================================================


// ============================================================================
//  Section 43. Additional fit evaluators (approx v1)
// ============================================================================

// --------------------------------------------------------------------------
// EffectiveGap*FD*GaussConv : first-pass approximate evaluator
// coef layout:
//   0 bg0
//   1 bg1
//   2 A
//   3 Delta
//   4 Gamma
//   5 T
//   6 EF
//   7 res   (reserved in v1)
// --------------------------------------------------------------------------
Function LJZ_EDCWB_FitFunc_EffectiveGap(coef, x) : FitFunc
    Wave coef
    Variable x

    Variable bg0   = coef[0]
    Variable bg1   = coef[1]
    Variable A     = coef[2]
    Variable Delta = coef[3]
    Variable Gamma = coef[4]
    Variable T     = coef[5]
    Variable EF    = coef[6]

    if (Delta < 0)
        Delta = abs(Delta)
    endif
    if (Gamma <= 0)
        Gamma = 1e-4
    endif

    Variable edge1 = LJZ_EDCWB_FitGau(x, EF - Delta, Gamma)
    Variable edge2 = 0.7 * LJZ_EDCWB_FitGau(x, EF + Delta, Gamma)
    Variable fd    = LJZ_EDCWB_FitFDValue(x, T, EF)

    return (bg0 + bg1 * x + A * (edge1 + edge2)) * fd
End

// --------------------------------------------------------------------------
// SymmetrizedGap : first-pass approximate evaluator
// coef layout:
//   0 bg0
//   1 bg1
//   2 A
//   3 Delta
//   4 Gamma
//   5 x0
// --------------------------------------------------------------------------
Function LJZ_EDCWB_FitFunc_SymGap(coef, x) : FitFunc
    Wave coef
    Variable x

    Variable bg0   = coef[0]
    Variable bg1   = coef[1]
    Variable A     = coef[2]
    Variable Delta = coef[3]
    Variable Gamma = coef[4]
    Variable x0    = coef[5]

    if (Delta < 0)
        Delta = abs(Delta)
    endif
    if (Gamma <= 0)
        Gamma = 1e-4
    endif

    Variable peak1 = LJZ_EDCWB_FitGau(x, x0 - Delta, Gamma)
    Variable peak2 = LJZ_EDCWB_FitGau(x, x0 + Delta, Gamma)

    return bg0 + bg1 * x + A * (peak1 + peak2)
End


// ============================================================================
//  Section 44. Generic full-wave evaluators
// ============================================================================

Function LJZ_EDCWB_EvalModelWave(modelID, wXRef, wCoef, wOut)
    Variable modelID
    Wave wXRef, wCoef, wOut

    Variable n = numpnts(wXRef)
    if (n != numpnts(wOut))
        return -1
    endif

    Variable i, xv
    for (i = 0; i < n; i += 1)
        xv = DimOffset(wXRef, 0) + i * DimDelta(wXRef, 0)

        if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
            wOut[i] = LJZ_EDCWB_FitFunc_SinglePeakFDConv(wCoef, xv)
        elseif (modelID == LJZ_EDCWB_Model_EffectiveGap())
            wOut[i] = LJZ_EDCWB_FitFunc_EffectiveGap(wCoef, xv)
        elseif (modelID == LJZ_EDCWB_Model_SymGap())
            wOut[i] = LJZ_EDCWB_FitFunc_SymGap(wCoef, xv)
        else
            wOut[i] = NaN
        endif
    endfor

    return 0
End


// ============================================================================
//  Section 45. Generic result saver
// ============================================================================

Function LJZ_EDCWB_SaveFitResultGeneric(srcWavePath, modelID, wCoefActive, wSigmaActive, fitOK)
    String srcWavePath
    Variable modelID, fitOK
    Wave wCoefActive, wSigmaActive

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureResultRecord(srcWavePath)

    Wave wEditPar  = $(LJZ_EDCWB_BaseDF() + ":EditPar")

    LJZ_EDCWB_CopyActiveCoefToEditPar(modelID, wCoefActive, wEditPar)
    LJZ_EDCWB_SanitizeParamWave(modelID, wEditPar)
    LJZ_EDCWB_SyncParToAuxState()

    Make/D/O/N=12 $(LJZ_EDCWB_TmpDF() + ":fitcoef12")
    Make/D/O/N=12 $(LJZ_EDCWB_TmpDF() + ":fitsigma12")
    Make/D/O/N=16 $(LJZ_EDCWB_TmpDF() + ":fitinfo16")
    Wave fitcoef12 = $(LJZ_EDCWB_TmpDF() + ":fitcoef12")
    Wave fitsigma12 = $(LJZ_EDCWB_TmpDF() + ":fitsigma12")
    Wave fitinfo16 = $(LJZ_EDCWB_TmpDF() + ":fitinfo16")

    fitcoef12 = NaN
    fitcoef12 = wEditPar[p]

    LJZ_EDCWB_CopySigmaToLen12(modelID, wSigmaActive, fitsigma12)

    fitinfo16 = NaN

    NVAR eXLo   = $(LJZ_EDCWB_BaseDF() + ":EditXLo")
    NVAR eXHi   = $(LJZ_EDCWB_BaseDF() + ":EditXHi")
    NVAR eTemp  = $(LJZ_EDCWB_BaseDF() + ":EditTemperature")
    NVAR eEF    = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    NVAR eRes   = $(LJZ_EDCWB_BaseDF() + ":EditResolution")
    NVAR eNorm  = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")
    NVAR fitOnSm = $(LJZ_EDCWB_BaseDF() + ":FitOnSmooth")

    fitinfo16[LJZ_EDCWB_FI_ModelID()]     = modelID
    fitinfo16[LJZ_EDCWB_FI_XLo()]         = eXLo
    fitinfo16[LJZ_EDCWB_FI_XHi()]         = eXHi
    fitinfo16[LJZ_EDCWB_FI_FitOK()]       = fitOK
    fitinfo16[LJZ_EDCWB_FI_Temperature()] = eTemp
    fitinfo16[LJZ_EDCWB_FI_Resolution()]  = eRes
    fitinfo16[LJZ_EDCWB_FI_EFermi()]      = eEF
    fitinfo16[LJZ_EDCWB_FI_NormMode()]    = eNorm
    fitinfo16[LJZ_EDCWB_FI_SmoothUsed()]  = fitOnSm

    Wave wFitIn = LJZ_EDCWB_GetFitInputWave(srcWavePath)
    Duplicate/O wFitIn, $(LJZ_EDCWB_TmpDF() + ":fitFull")
    Duplicate/O wFitIn, $(LJZ_EDCWB_TmpDF() + ":resFull")
    Wave fitFull = $(LJZ_EDCWB_TmpDF() + ":fitFull")
    Wave resFull = $(LJZ_EDCWB_TmpDF() + ":resFull")

    LJZ_EDCWB_EvalModelWave(modelID, wFitIn, wCoefActive, fitFull)
    resFull = wFitIn[p] - fitFull[p]

    fitinfo16[LJZ_EDCWB_FI_FitRMSE()]   = LJZ_EDCWB_RMSEBetweenWaves(wFitIn, fitFull)
    fitinfo16[LJZ_EDCWB_FI_MaxAbsRes()] = LJZ_EDCWB_MaxAbsWave(resFull)

    Variable iLo, iHi
    if (LJZ_EDCWB_GetLastFitROIRange(iLo, iHi) == 0)
        fitinfo16[LJZ_EDCWB_FI_NROI()] = iHi - iLo + 1
    endif

    NVAR/Z vChi = V_chisq
    if (NVAR_Exists(vChi))
        fitinfo16[LJZ_EDCWB_FI_ChiSq()] = vChi
    endif

    LJZ_EDCWB_SaveFitCurve(srcWavePath, fitFull, resFull)
    LJZ_EDCWB_SaveFitVectors(srcWavePath, fitcoef12, fitsigma12, fitinfo16)

    return 0
End


// ============================================================================
//  Section 46. Generic fit runner
// ============================================================================

Function LJZ_EDCWB_DoFitModelApprox(srcWavePath, modelID)
    String srcWavePath
    Variable modelID

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureTmpDF()

    if (!LJZ_EDCWB_SourceWaveExists(srcWavePath))
        return -1
    endif
    if (!LJZ_EDCWB_ModelIsValid(modelID))
        return -1
    endif

    Variable ok = LJZ_EDCWB_BuildFitROIWaves(srcWavePath)
    if (ok != 0)
        return -1
    endif

    Wave fitY = $(LJZ_EDCWB_TmpDF() + ":fitY")
    Wave fitX = $(LJZ_EDCWB_TmpDF() + ":fitX")
    if (!WaveExists(fitY) || !WaveExists(fitX))
        return -1
    endif
    if (numpnts(fitY) < 5)
        return -1
    endif

    Wave wEditPar  = $(LJZ_EDCWB_BaseDF() + ":EditPar")
    Wave wEditHold = $(LJZ_EDCWB_BaseDF() + ":EditHold")

    ok = LJZ_EDCWB_MakeActiveCoefWave(modelID, wEditPar, LJZ_EDCWB_TmpDF() + ":coefActive")
    if (ok != 0)
        return -1
    endif

    Wave coefActive = $(LJZ_EDCWB_TmpDF() + ":coefActive")
    LJZ_EDCWB_SanitizeParamWave(modelID, coefActive)

    String holdStr = LJZ_EDCWB_BuildHoldStringForModel(modelID, wEditHold)

    LJZ_EDCWB_BuildAndSaveGuessCurve(srcWavePath)

    if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
        FuncFit/H=holdStr/Q LJZ_EDCWB_FitFunc_SinglePeakFDConv coefActive fitY /X=fitX
    elseif (modelID == LJZ_EDCWB_Model_EffectiveGap())
        FuncFit/H=holdStr/Q LJZ_EDCWB_FitFunc_EffectiveGap coefActive fitY /X=fitX
    elseif (modelID == LJZ_EDCWB_Model_SymGap())
        FuncFit/H=holdStr/Q LJZ_EDCWB_FitFunc_SymGap coefActive fitY /X=fitX
    else
        return -1
    endif

    Wave/Z W_sigma
    if (!WaveExists(W_sigma))
        Make/D/O/N=(numpnts(coefActive)) $(LJZ_EDCWB_TmpDF() + ":sigmaActive") = NaN
    else
        Duplicate/O W_sigma, $(LJZ_EDCWB_TmpDF() + ":sigmaActive")
    endif
    Wave sigmaActive = $(LJZ_EDCWB_TmpDF() + ":sigmaActive")

    Variable fitOK = 1
    NVAR/Z vFitError = V_FitError
    if (NVAR_Exists(vFitError) && vFitError != 0)
        fitOK = 0
    endif

    LJZ_EDCWB_SaveFitResultGeneric(srcWavePath, modelID, coefActive, sigmaActive, fitOK)
    if (!fitOK)
        return -2
    endif

    LJZ_EDCWB_MarkDirty(0)
    return 0
End


// ============================================================================
//  Section 47. Replace old dispatchers with these
// ============================================================================

Function LJZ_EDCWB_DoFitCurrent()
    LJZ_EDCWB_EnsureDF()

    SVAR sPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR eModel = $(LJZ_EDCWB_BaseDF() + ":EditModelID")

    if (strlen(sPath) == 0)
        return -1
    endif

    return LJZ_EDCWB_DoFitWave(sPath, eModel)
End

Function LJZ_EDCWB_DoFitWave(srcWavePath, modelID)
    String srcWavePath
    Variable modelID

    if (!LJZ_EDCWB_SourceWaveExists(srcWavePath))
        return -1
    endif
    if (!LJZ_EDCWB_ModelIsValid(modelID))
        return -1
    endif

    return LJZ_EDCWB_DoFitModelApprox(srcWavePath, modelID)
End

Function LJZ_EDCWB_RefitCurrent()
    return LJZ_EDCWB_DoFitCurrent()
End

Function LJZ_EDCWB_BatchFitList(listStr, modelID, onlyUnchecked)
    String listStr
    Variable modelID, onlyUnchecked

    Variable n = ItemsInList(listStr, ";")
    Variable i, ok, nDone = 0
    String wPath

    for (i = 0; i < n; i += 1)
        wPath = StringFromList(i, listStr, ";")
        if (strlen(wPath) == 0)
            continue
        endif

        if (onlyUnchecked)
            if (LJZ_EDCWB_ReadAcceptState(wPath) != 0)
                continue
            endif
        endif

        ok = LJZ_EDCWB_AutoInitGuess(wPath, modelID)
        if (ok != 0)
            continue
        endif

        ok = LJZ_EDCWB_DoFitWave(wPath, modelID)
        if (ok == 0)
            nDone += 1
        endif
    endfor

    return nDone
End

// ============================================================================
//  LJZ_EDCWB Part 6 : Panel + callbacks + export helpers
// ============================================================================


// ============================================================================
//  Section 48. Extra runtime waves for panel list
// ============================================================================

Function LJZ_EDCWB_EnsurePanelState()
    LJZ_EDCWB_EnsureDF()

    Wave/T/Z wDisp = $(LJZ_EDCWB_BaseDF() + ":LB_Disp")
    if (!WaveExists(wDisp))
        Make/O/T/N=0 $(LJZ_EDCWB_BaseDF() + ":LB_Disp")
    endif

    Wave/Z wSel = $(LJZ_EDCWB_BaseDF() + ":LB_Sel")
    if (!WaveExists(wSel))
        Make/O/N=0 $(LJZ_EDCWB_BaseDF() + ":LB_Sel") = 0
    endif

    return 0
End

Function/S LJZ_EDCWB_StatusTagForWave(wPath)
    String wPath

    Variable acc = LJZ_EDCWB_ReadAcceptState(wPath)
    if (acc > 0)
        return "[A]"
    endif
    if (acc < 0)
        return "[R]"
    endif
    return "[ ]"
End

Function LJZ_EDCWB_RebuildListWaves()
    LJZ_EDCWB_EnsurePanelState()

    SVAR sTarget = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
    NVAR curRow  = $(LJZ_EDCWB_BaseDF() + ":CurRow")
    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")

    String listStr = LJZ_EDCWB_ListEDCWaves(sTarget)
    Variable n = ItemsInList(listStr, ";")

    Make/O/T/N=(n) $(LJZ_EDCWB_BaseDF() + ":LB_Disp")
    Make/O/N=(n)   $(LJZ_EDCWB_BaseDF() + ":LB_Sel") = 0

    Wave/T wDisp = $(LJZ_EDCWB_BaseDF() + ":LB_Disp")
    Wave wSel    = $(LJZ_EDCWB_BaseDF() + ":LB_Sel")

    Variable i
    String wPath, nm
    for (i = 0; i < n; i += 1)
        wPath = StringFromList(i, listStr, ";")
        nm = LJZ_EDCWB_WaveNameFromPath(wPath)
        wDisp[i] = LJZ_EDCWB_StatusTagForWave(wPath) + " " + nm
        wSel[i] = 0
    endfor

    if (n <= 0)
        curRow = -1
        curPath = ""
        return 0
    endif

    if (curRow < 0 || curRow >= n)
        curRow = 0
        curPath = StringFromList(0, listStr, ";")
    endif

    if (curRow >= 0 && curRow < n)
        wSel[curRow] = 1
    endif

    return 0
End

Function/S LJZ_EDCWB_CurrentListStr()
    SVAR sTarget = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
    return LJZ_EDCWB_ListEDCWaves(sTarget)
End

Function LJZ_EDCWB_SelectRow(row)
    Variable row

    LJZ_EDCWB_EnsurePanelState()

    String listStr = LJZ_EDCWB_CurrentListStr()
    Variable n = ItemsInList(listStr, ";")
    if (n <= 0)
        return -1
    endif

    row = LJZ_EDCWB_ClampIndex(row, n)

    NVAR curRow  = $(LJZ_EDCWB_BaseDF() + ":CurRow")
    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")

    Wave wSel = $(LJZ_EDCWB_BaseDF() + ":LB_Sel")
    if (numpnts(wSel) != n)
        Redimension/N=(n) wSel
    endif
    wSel = 0
    wSel[row] = 1

    curRow = row
    curPath = StringFromList(row, listStr, ";")

    LJZ_EDCWB_LoadCurrentWave()
    return 0
End

Function LJZ_EDCWB_SelectPrev()
    NVAR curRow = $(LJZ_EDCWB_BaseDF() + ":CurRow")
    return LJZ_EDCWB_SelectRow(max(0, curRow - 1))
End

Function LJZ_EDCWB_SelectNext()
    String listStr = LJZ_EDCWB_CurrentListStr()
    Variable n = ItemsInList(listStr, ";")
    if (n <= 0)
        return -1
    endif

    NVAR curRow = $(LJZ_EDCWB_BaseDF() + ":CurRow")
    return LJZ_EDCWB_SelectRow(min(n - 1, curRow + 1))
End


// ============================================================================
//  Section 49. Load current wave / graph refresh
// ============================================================================

Function LJZ_EDCWB_LoadCurrentWave()
    LJZ_EDCWB_EnsureDF()

    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR eModel  = $(LJZ_EDCWB_BaseDF() + ":EditModelID")

    if (strlen(curPath) == 0)
        return -1
    endif
    if (!LJZ_EDCWB_SourceWaveExists(curPath))
        return -1
    endif

    LJZ_EDCWB_EnsureResultRecord(curPath)

    if (LJZ_EDCWB_HasFitRecord(curPath))
        LJZ_EDCWB_LoadFitRecordToEditState(curPath)
    else
        LJZ_EDCWB_SetModel(eModel)
        LJZ_EDCWB_AutoInitGuess(curPath, eModel)
        LJZ_EDCWB_BuildAndSaveGuessCurve(curPath)
    endif

    LJZ_EDCWB_RebuildAllWorkWaves(curPath)
    LJZ_EDCWB_RefreshGraph()
    LJZ_EDCWB_RefreshPanelTitles()

    return 0
End

Function/S LJZ_EDCWB_GraphName()
    return "LJZ_EDCWB_Graph"
End

Function/S LJZ_EDCWB_PanelName()
    return "LJZ_EDCWB_Panel"
End

Function/S LJZ_EDCWB_ParamTableName()
    return "LJZ_EDCWB_Params"
End

Function LJZ_EDCWB_RefreshGraph()
    LJZ_EDCWB_EnsureDF()

    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    if (strlen(curPath) == 0)
        return -1
    endif

    NVAR shRaw   = $(LJZ_EDCWB_BaseDF() + ":ShowRaw")
    NVAR shSm    = $(LJZ_EDCWB_BaseDF() + ":ShowSmooth")
    NVAR shGuess = $(LJZ_EDCWB_BaseDF() + ":ShowGuess")
    NVAR shFit   = $(LJZ_EDCWB_BaseDF() + ":ShowFit")
    NVAR shRes   = $(LJZ_EDCWB_BaseDF() + ":ShowResidual")

    String g = LJZ_EDCWB_GraphName()
    DoWindow/F $g
    if (V_flag == 0)
        Display/N=$g
    else
        DoWindow/F $g
    endif

    RemoveFromGraph/Z /W=$g /A

    if (shRaw)
        Wave/Z w0 = LJZ_EDCWB_GetDisplayRawWave(curPath)
        if (WaveExists(w0))
            AppendToGraph/W=$g w0
        endif
    endif

    if (shSm)
        Wave/Z w1 = LJZ_EDCWB_GetDisplaySmoothWave(curPath)
        if (WaveExists(w1))
            AppendToGraph/W=$g w1
        endif
    endif

    if (shGuess)
        Wave/Z wGuess = $(LJZ_EDCWB_ResultGuessPath(curPath))
        if (WaveExists(wGuess))
            AppendToGraph/W=$g wGuess
        endif
    endif

    if (shFit)
        Wave/Z wFit = $(LJZ_EDCWB_ResultFitPath(curPath))
        if (WaveExists(wFit))
            AppendToGraph/W=$g wFit
        endif
    endif

    if (shRes)
        Wave/Z wRes = $(LJZ_EDCWB_ResultResPath(curPath))
        if (WaveExists(wRes))
            AppendToGraph/R/W=$g wRes
        endif
    endif

    ModifyGraph/W=$g mirror=1
    Label/W=$g left "Intensity"
    Label/W=$g right "Residual"
    Label/W=$g bottom "Energy"

    return 0
End

Function LJZ_EDCWB_RefreshPanelTitles()
    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    String p = LJZ_EDCWB_PanelName()
    String g = LJZ_EDCWB_GraphName()

    if (strlen(curPath) > 0)
        DoWindow/T $p, "EDC Workbench : " + LJZ_EDCWB_WaveNameFromPath(curPath)
        DoWindow/T $g, "EDC Graph : " + LJZ_EDCWB_WaveNameFromPath(curPath)
    else
        DoWindow/T $p, "EDC Workbench"
        DoWindow/T $g, "EDC Graph"
    endif

    return 0
End

Function LJZ_EDCWB_OpenParamTable()
    LJZ_EDCWB_EnsureDF()

    String t = LJZ_EDCWB_ParamTableName()
    DoWindow/F $t
    if (V_flag == 0)
        Edit/N=$t/K=1 $(LJZ_EDCWB_BaseDF() + ":EditParName"), $(LJZ_EDCWB_BaseDF() + ":EditParEnable"), $(LJZ_EDCWB_BaseDF() + ":EditHold"), $(LJZ_EDCWB_BaseDF() + ":EditPar")
        ModifyTable/W=$t width(Point)=40
    endif

    return 0
End


// ============================================================================
//  Section 50. Panel creation
// ============================================================================

Function LJZ_EDCWB()
    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsurePanelState()

    SVAR sTarget = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
    if (strlen(sTarget) == 0)
        sTarget = "root:"
    endif

    LJZ_EDCWB_RebuildListWaves()
    LJZ_EDCWB_OpenPanel()
    LJZ_EDCWB_OpenParamTable()
    LJZ_EDCWB_LoadCurrentWave()

    return 0
End

Function LJZ_EDCWB_OpenPanel()
    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsurePanelState()

    String p = LJZ_EDCWB_PanelName()
    DoWindow/F $p
    if (V_flag == 0)
        NewPanel/N=$p /W=(40,60,520,690)
    else
        DoWindow/F $p
        return 0
    endif

    SetVariable svTarget,pos={10,10},size={240,18},title="Base DF"
    SetVariable svTarget,variable=$(LJZ_EDCWB_BaseDF() + ":TargetDF"),proc=LJZ_EDCWB_SetVarProc

    Button btScan,pos={260,8},size={60,20},title="Scan",proc=LJZ_EDCWB_ButtonProc
    Button btParam,pos={330,8},size={70,20},title="Params",proc=LJZ_EDCWB_ButtonProc
    Button btGraph,pos={410,8},size={60,20},title="Graph",proc=LJZ_EDCWB_ButtonProc

    ListBox lbWave,pos={10,40},size={210,260},listWave=$(LJZ_EDCWB_BaseDF() + ":LB_Disp"),selWave=$(LJZ_EDCWB_BaseDF() + ":LB_Sel"),proc=LJZ_EDCWB_ListBoxProc

    Button btPrev,pos={10,310},size={45,20},title="<",proc=LJZ_EDCWB_ButtonProc
    Button btNext,pos={60,310},size={45,20},title=">",proc=LJZ_EDCWB_ButtonProc
    Button btAccept,pos={115,310},size={50,20},title="Accept",proc=LJZ_EDCWB_ButtonProc
    Button btReject,pos={170,310},size={50,20},title="Reject",proc=LJZ_EDCWB_ButtonProc

    Button btClearRec,pos={10,340},size={80,20},title="ClearRec",proc=LJZ_EDCWB_ButtonProc
    Button btReload,pos={100,340},size={60,20},title="Reload",proc=LJZ_EDCWB_ButtonProc
    Button btSummary,pos={170,340},size={50,20},title="Sum",proc=LJZ_EDCWB_ButtonProc

    PopupMenu pmModel,pos={240,40},size={220,20},title="Model"
    NVAR eModelOpen = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    PopupMenu pmModel,mode=1,popvalue=LJZ_EDCWB_ModelName(eModelOpen),value=#"LJZ_EDCWB_ModelPopupList()",proc=LJZ_EDCWB_PopupProc

    SetVariable svXLo,pos={240,75},size={105,18},title="XLo"
    SetVariable svXLo,variable=$(LJZ_EDCWB_BaseDF() + ":EditXLo"),proc=LJZ_EDCWB_SetVarProc
    SetVariable svXHi,pos={355,75},size={105,18},title="XHi"
    SetVariable svXHi,variable=$(LJZ_EDCWB_BaseDF() + ":EditXHi"),proc=LJZ_EDCWB_SetVarProc

    SetVariable svTemp,pos={240,105},size={105,18},title="T"
    SetVariable svTemp,variable=$(LJZ_EDCWB_BaseDF() + ":EditTemperature"),proc=LJZ_EDCWB_SetVarProc
    SetVariable svEF,pos={355,105},size={105,18},title="EF"
    SetVariable svEF,variable=$(LJZ_EDCWB_BaseDF() + ":EditEFermi"),proc=LJZ_EDCWB_SetVarProc

    SetVariable svRes,pos={240,135},size={105,18},title="Res"
    SetVariable svRes,variable=$(LJZ_EDCWB_BaseDF() + ":EditResolution"),proc=LJZ_EDCWB_SetVarProc

    PopupMenu pmNorm,pos={240,165},size={220,20},title="Norm"
    PopupMenu pmNorm,mode=1,popvalue="0",value="0:none;1:maxAbs;2:tailMean;3:ROIMax;",proc=LJZ_EDCWB_PopupProc

    CheckBox cbSmEnable,pos={240,200},title="Smooth",variable=$(LJZ_EDCWB_BaseDF() + ":SmoothEnable"),proc=LJZ_EDCWB_CheckProc
    PopupMenu pmSmMethod,pos={320,198},size={140,20},title=""
    PopupMenu pmSmMethod,mode=1,popvalue="0",value="0:none;1:Smooth;2:SavGol;",proc=LJZ_EDCWB_PopupProc

    SetVariable svSmP1,pos={240,228},size={105,18},title="SmP1"
    SetVariable svSmP1,variable=$(LJZ_EDCWB_BaseDF() + ":SmoothParam1"),proc=LJZ_EDCWB_SetVarProc
    SetVariable svSmP2,pos={355,228},size={105,18},title="SmP2"
    SetVariable svSmP2,variable=$(LJZ_EDCWB_BaseDF() + ":SmoothParam2"),proc=LJZ_EDCWB_SetVarProc

    CheckBox cbUseSmGuess,pos={240,258},title="UseSmGuess",variable=$(LJZ_EDCWB_BaseDF() + ":UseSmoothForGuess"),proc=LJZ_EDCWB_CheckProc
    CheckBox cbFitOnSm,pos={355,258},title="FitOnSm",variable=$(LJZ_EDCWB_BaseDF() + ":FitOnSmooth"),proc=LJZ_EDCWB_CheckProc

    CheckBox cbShowRaw,pos={240,290},title="Raw",variable=$(LJZ_EDCWB_BaseDF() + ":ShowRaw"),proc=LJZ_EDCWB_CheckProc
    CheckBox cbShowSm,pos={300,290},title="Smooth",variable=$(LJZ_EDCWB_BaseDF() + ":ShowSmooth"),proc=LJZ_EDCWB_CheckProc
    CheckBox cbShowGuess,pos={380,290},title="Guess",variable=$(LJZ_EDCWB_BaseDF() + ":ShowGuess"),proc=LJZ_EDCWB_CheckProc

    CheckBox cbShowFit,pos={240,318},title="Fit",variable=$(LJZ_EDCWB_BaseDF() + ":ShowFit"),proc=LJZ_EDCWB_CheckProc
    CheckBox cbShowRes,pos={300,318},title="Residual",variable=$(LJZ_EDCWB_BaseDF() + ":ShowResidual"),proc=LJZ_EDCWB_CheckProc

    Button btGuess,pos={240,360},size={70,24},title="Guess",proc=LJZ_EDCWB_ButtonProc
    Button btFit,pos={320,360},size={70,24},title="Fit",proc=LJZ_EDCWB_ButtonProc
    Button btRefit,pos={400,360},size={70,24},title="Refit",proc=LJZ_EDCWB_ButtonProc

    Button btBatchAll,pos={240,395},size={110,24},title="Batch All",proc=LJZ_EDCWB_ButtonProc
    Button btBatchUnchecked,pos={360,395},size={110,24},title="Batch Unchecked",proc=LJZ_EDCWB_ButtonProc

    Button btExport,pos={240,430},size={110,24},title="ExportSummary",proc=LJZ_EDCWB_ButtonProc
    Button btRebuild,pos={360,430},size={110,24},title="RebuildGraph",proc=LJZ_EDCWB_ButtonProc

    return 0
End


// ============================================================================
//  Section 51. Control callbacks
// ============================================================================

Function LJZ_EDCWB_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    String name = ba.ctrlName
    SVAR sTarget = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR eModel  = $(LJZ_EDCWB_BaseDF() + ":EditModelID")

    if (CmpStr(name, "btScan") == 0)
        LJZ_EDCWB_RebuildListWaves()
        LJZ_EDCWB_LoadCurrentWave()
        return 0
    endif

    if (CmpStr(name, "btParam") == 0)
        LJZ_EDCWB_OpenParamTable()
        return 0
    endif

    if (CmpStr(name, "btGraph") == 0)
        LJZ_EDCWB_RefreshGraph()
        return 0
    endif

    if (CmpStr(name, "btPrev") == 0)
        LJZ_EDCWB_SelectPrev()
        return 0
    endif

    if (CmpStr(name, "btNext") == 0)
        LJZ_EDCWB_SelectNext()
        return 0
    endif

    if (CmpStr(name, "btAccept") == 0)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_WriteAcceptState(curPath, 1)
            LJZ_EDCWB_RebuildListWaves()
        endif
        return 0
    endif

    if (CmpStr(name, "btReject") == 0)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_WriteAcceptState(curPath, -1)
            LJZ_EDCWB_RebuildListWaves()
        endif
        return 0
    endif

    if (CmpStr(name, "btClearRec") == 0)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_ClearFitRecord(curPath)
            LJZ_EDCWB_LoadCurrentWave()
        endif
        return 0
    endif

    if (CmpStr(name, "btReload") == 0)
        LJZ_EDCWB_LoadCurrentWave()
        return 0
    endif

    if (CmpStr(name, "btSummary") == 0)
        if (strlen(curPath) > 0)
            Print LJZ_EDCWB_AutoGuessSummary(curPath)
        endif
        return 0
    endif

    if (CmpStr(name, "btGuess") == 0)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_SyncAuxStateToPar()
            LJZ_EDCWB_AutoGuessAndSave(curPath, eModel)
            LJZ_EDCWB_RefreshGraph()
        endif
        return 0
    endif

    if (CmpStr(name, "btFit") == 0)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_SyncAuxStateToPar()
            LJZ_EDCWB_DoFitWave(curPath, eModel)
            LJZ_EDCWB_RefreshGraph()
        endif
        return 0
    endif

    if (CmpStr(name, "btRefit") == 0)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_SyncAuxStateToPar()
            LJZ_EDCWB_RefitCurrent()
            LJZ_EDCWB_RefreshGraph()
        endif
        return 0
    endif

    if (CmpStr(name, "btBatchAll") == 0)
        Print "EDCWB batch done = ", LJZ_EDCWB_BatchFitList(LJZ_EDCWB_CurrentListStr(), eModel, 0)
        LJZ_EDCWB_RebuildListWaves()
        LJZ_EDCWB_LoadCurrentWave()
        return 0
    endif

    if (CmpStr(name, "btBatchUnchecked") == 0)
        Print "EDCWB batch unchecked done = ", LJZ_EDCWB_BatchFitList(LJZ_EDCWB_CurrentListStr(), eModel, 1)
        LJZ_EDCWB_RebuildListWaves()
        LJZ_EDCWB_LoadCurrentWave()
        return 0
    endif

    if (CmpStr(name, "btExport") == 0)
        LJZ_EDCWB_ExportSummaryToTargetDF()
        return 0
    endif

    if (CmpStr(name, "btRebuild") == 0)
        LJZ_EDCWB_RebuildAllWorkWaves(curPath)
        LJZ_EDCWB_RefreshGraph()
        return 0
    endif

    return 0
End

Function LJZ_EDCWB_SetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    if ((sva.eventCode != 1) && (sva.eventCode != 2) && (sva.eventCode != 3))
        return 0
    endif

    String name = sva.ctrlName
    SVAR sTarget = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")

    if (CmpStr(name, "svTarget") == 0)
        LJZ_EDCWB_RebuildListWaves()
        LJZ_EDCWB_LoadCurrentWave()
        return 0
    endif

    if ((CmpStr(name, "svTemp") == 0) || (CmpStr(name, "svEF") == 0) || (CmpStr(name, "svRes") == 0))
        LJZ_EDCWB_SyncAuxStateToPar()
        LJZ_EDCWB_BuildAndSaveGuessCurve(curPath)
        LJZ_EDCWB_RefreshGraph()
        return 0
    endif

    if ((CmpStr(name, "svXLo") == 0) || (CmpStr(name, "svXHi") == 0) || (CmpStr(name, "svSmP1") == 0) || (CmpStr(name, "svSmP2") == 0))
        LJZ_EDCWB_RebuildAllWorkWaves(curPath)
        LJZ_EDCWB_BuildAndSaveGuessCurve(curPath)
        LJZ_EDCWB_RefreshGraph()
        return 0
    endif

    return 0
End

Function LJZ_EDCWB_PopupProc(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa

    if (pa.eventCode != 2)
        return 0
    endif

    String name = pa.ctrlName
    String ps = pa.popStr
    NVAR eModel   = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR smMethod = $(LJZ_EDCWB_BaseDF() + ":SmoothMethod")
    NVAR eNorm    = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")
    SVAR curPath  = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")

    if (CmpStr(name, "pmModel") == 0)
        if (CmpStr(ps, LJZ_EDCWB_ModelName(LJZ_EDCWB_Model_SinglePeakFDConv())) == 0)
            eModel = LJZ_EDCWB_Model_SinglePeakFDConv()
        elseif (CmpStr(ps, LJZ_EDCWB_ModelName(LJZ_EDCWB_Model_EffectiveGap())) == 0)
            eModel = LJZ_EDCWB_Model_EffectiveGap()
        elseif (CmpStr(ps, LJZ_EDCWB_ModelName(LJZ_EDCWB_Model_SymGap())) == 0)
            eModel = LJZ_EDCWB_Model_SymGap()
        endif

        LJZ_EDCWB_SetModel(eModel)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_AutoGuessAndSave(curPath, eModel)
        endif
        LJZ_EDCWB_RefreshGraph()
        return 0
    endif

    if (CmpStr(name, "pmSmMethod") == 0)
        smMethod = str2num(StringFromList(0, ps, ":"))
        LJZ_EDCWB_RebuildAllWorkWaves(curPath)
        LJZ_EDCWB_BuildAndSaveGuessCurve(curPath)
        LJZ_EDCWB_RefreshGraph()
        return 0
    endif

    if (CmpStr(name, "pmNorm") == 0)
        eNorm = str2num(StringFromList(0, ps, ":"))
        LJZ_EDCWB_RebuildAllWorkWaves(curPath)
        LJZ_EDCWB_AutoGuessAndSave(curPath, eModel)
        LJZ_EDCWB_RefreshGraph()
        return 0
    endif

    return 0
End

Function LJZ_EDCWB_CheckProc(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba

    if (cba.eventCode != 2)
        return 0
    endif

    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR eModel  = $(LJZ_EDCWB_BaseDF() + ":EditModelID")

    if (strlen(curPath) <= 0)
        return 0
    endif

    // display toggles only refresh graph
    if ((CmpStr(cba.ctrlName, "cbShowRaw") == 0) || (CmpStr(cba.ctrlName, "cbShowSm") == 0) || (CmpStr(cba.ctrlName, "cbShowGuess") == 0) || (CmpStr(cba.ctrlName, "cbShowFit") == 0) || (CmpStr(cba.ctrlName, "cbShowRes") == 0))
        LJZ_EDCWB_RefreshGraph()
        return 0
    endif

    // preprocess toggles rebuild waves + guess
    LJZ_EDCWB_RebuildAllWorkWaves(curPath)
    LJZ_EDCWB_AutoGuessAndSave(curPath, eModel)
    LJZ_EDCWB_RefreshGraph()

    return 0
End

Function LJZ_EDCWB_ListBoxProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if ((lba.eventCode != 1) && (lba.eventCode != 4))
        return 0
    endif

    if (CmpStr(lba.ctrlName, "lbWave") == 0)
        if (lba.row >= 0)
            LJZ_EDCWB_SelectRow(lba.row)
        endif
    endif

    return 0
End


// ============================================================================
//  Section 52. Summary export
// ============================================================================

Function/S LJZ_EDCWB_SummaryPrefix()
    return "edcwb_summary_"
End

Function LJZ_EDCWB_ExportSummaryToTargetDF()
    LJZ_EDCWB_EnsureDF()

    SVAR sTarget = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
    sTarget = LJZ_EDCWB_NormDFPath(sTarget)
    if (strlen(sTarget) == 0)
        Print "EDCWB export: invalid target DF."
        return -1
    endif

    String listStr = LJZ_EDCWB_ListEDCWaves(sTarget)
    Variable n = ItemsInList(listStr, ";")
    if (n <= 0)
        Print "EDCWB export: no EDC waves."
        return -1
    endif

    Make/O/T/N=(n) $(sTarget + LJZ_EDCWB_SummaryPrefix() + "name")
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "accept") = 0
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "modelID") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "fitOK") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "fitRMSE") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "chiSq") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "x0") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "w") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "Delta") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "Gamma") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "A") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "EF") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "T") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "res") = NaN

    Wave/T wName   = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "name")
    Wave wAcc      = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "accept")
    Wave wModel    = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "modelID")
    Wave wFitOK    = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "fitOK")
    Wave wFitRMSE  = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "fitRMSE")
    Wave wChiSq    = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "chiSq")
    Wave wx0       = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "x0")
    Wave ww        = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "w")
    Wave wDelta    = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "Delta")
    Wave wGamma    = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "Gamma")
    Wave wA        = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "A")
    Wave wEF       = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "EF")
    Wave wT        = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "T")
    Wave wRes      = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "res")

    Variable i, modelID
    String wPath
    for (i = 0; i < n; i += 1)
        wPath = StringFromList(i, listStr, ";")
        wName[i] = LJZ_EDCWB_WaveNameFromPath(wPath)
        wAcc[i] = LJZ_EDCWB_ReadAcceptState(wPath)

        Wave/Z fi = $(LJZ_EDCWB_ResultFitInfoPath(wPath))
        Wave/Z fc = $(LJZ_EDCWB_ResultFitCoefPath(wPath))
        if (!WaveExists(fi) || !WaveExists(fc))
            continue
        endif

        modelID = fi[LJZ_EDCWB_FI_ModelID()]
        wModel[i] = modelID
        wFitOK[i] = fi[LJZ_EDCWB_FI_FitOK()]
        wFitRMSE[i] = fi[LJZ_EDCWB_FI_FitRMSE()]
        wChiSq[i] = fi[LJZ_EDCWB_FI_ChiSq()]

        if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
            wx0[i]    = fc[LJZ_EDCWB_ParamIndex(modelID, "x0")]
            ww[i]     = fc[LJZ_EDCWB_ParamIndex(modelID, "w")]
            wA[i]     = fc[LJZ_EDCWB_ParamIndex(modelID, "A")]
            wEF[i]    = fc[LJZ_EDCWB_ParamIndex(modelID, "EF")]
            wT[i]     = fc[LJZ_EDCWB_ParamIndex(modelID, "T")]
            wRes[i]   = fc[LJZ_EDCWB_ParamIndex(modelID, "res")]
        elseif (modelID == LJZ_EDCWB_Model_EffectiveGap())
            wDelta[i] = fc[LJZ_EDCWB_ParamIndex(modelID, "Delta")]
            wGamma[i] = fc[LJZ_EDCWB_ParamIndex(modelID, "Gamma")]
            wA[i]     = fc[LJZ_EDCWB_ParamIndex(modelID, "A")]
            wEF[i]    = fc[LJZ_EDCWB_ParamIndex(modelID, "EF")]
            wT[i]     = fc[LJZ_EDCWB_ParamIndex(modelID, "T")]
            wRes[i]   = fc[LJZ_EDCWB_ParamIndex(modelID, "res")]
        elseif (modelID == LJZ_EDCWB_Model_SymGap())
            wDelta[i] = fc[LJZ_EDCWB_ParamIndex(modelID, "Delta")]
            wGamma[i] = fc[LJZ_EDCWB_ParamIndex(modelID, "Gamma")]
            wx0[i]    = fc[LJZ_EDCWB_ParamIndex(modelID, "x0")]
            wA[i]     = fc[LJZ_EDCWB_ParamIndex(modelID, "A")]
        endif
    endfor

    Print "EDCWB summary exported to: ", sTarget
    return 0
End
