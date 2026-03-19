#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  ProcLJZ_EDCWB_Panel.ipf
//  EDCWB panel / graph / callback / export 模块。
//
//  这里只负责：
//    - panel
//    - graph
//    - callback
//    - export
//
//  不负责：
//    - 正式入口菜单注册
//    - 模块 include 装配
//
//  EDCWB 相关菜单只能由 ProcLJZ_EDCWB.ipf 提供，禁止在此文件重新注册。
// ============================================================================


// ============================================================================
//  Section 0. names / panel state
// ============================================================================

Function/S LJZ_EDCWB_PanelName()
    return "LJZ_EDCWB_Panel"
End

Function/S LJZ_EDCWB_GraphName()
    return "LJZ_EDCWB_Graph"
End

Function/S LJZ_EDCWB_ParamTableName()
    return "LJZ_EDCWB_Params"
End

Static Function LJZ_EDCWB_UIBusy()
    NVAR uiBusy = $(LJZ_EDCWB_BaseDF() + ":UIBusy")
    return (uiBusy != 0)
End

Static Function LJZ_EDCWB_BeginUIBusy()
    NVAR uiBusy = $(LJZ_EDCWB_BaseDF() + ":UIBusy")
    if (uiBusy != 0)
        return -1
    endif

    uiBusy = 1
    return 0
End

Static Function LJZ_EDCWB_EndUIBusy()
    NVAR uiBusy = $(LJZ_EDCWB_BaseDF() + ":UIBusy")
    uiBusy = 0
    return 0
End

Static Function LJZ_EDCWB_IsSyncingControls()
    NVAR syncControls = $(LJZ_EDCWB_BaseDF() + ":SyncingControls")
    return (syncControls != 0)
End

Static Function LJZ_EDCWB_SetSyncingControls(flag)
    Variable flag

    NVAR syncControls = $(LJZ_EDCWB_BaseDF() + ":SyncingControls")
    syncControls = (flag != 0)
    return 0
End

Static Function LJZ_EDCWB_ReguessCurrentWave(curPath, modelID, refreshResultBox)
    String curPath
    Variable modelID, refreshResultBox

    if (!LJZ_EDCWB_SourceWaveExists(curPath))
        return -1
    endif

    LJZ_EDCWB_RebuildAllWorkWaves(curPath)
    LJZ_EDCWB_ClearStoredFitOutputs(curPath)
    LJZ_EDCWB_AutoGuessAndSave(curPath, modelID)
    LJZ_EDCWB_RefreshGraph()
    if (refreshResultBox)
        LJZ_EDCWB_RefreshResultBox()
    endif

    return 0
End

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

    Wave/T/Z wMetric = $(LJZ_EDCWB_BaseDF() + ":MetricDisp")
    if (!WaveExists(wMetric))
        Make/O/T/N=0 $(LJZ_EDCWB_BaseDF() + ":MetricDisp")
    endif

    Wave/Z wMetricSel = $(LJZ_EDCWB_BaseDF() + ":MetricSel")
    if (!WaveExists(wMetricSel))
        Make/O/N=0 $(LJZ_EDCWB_BaseDF() + ":MetricSel") = 0
    endif

    Wave/T/Z wResL = $(LJZ_EDCWB_BaseDF() + ":ResDispL")
    if (!WaveExists(wResL))
        Make/O/T/N=0 $(LJZ_EDCWB_BaseDF() + ":ResDispL")
    endif

    Wave/Z wResSelL = $(LJZ_EDCWB_BaseDF() + ":ResSelL")
    if (!WaveExists(wResSelL))
        Make/O/N=0 $(LJZ_EDCWB_BaseDF() + ":ResSelL") = 0
    endif

    Wave/T/Z wResR = $(LJZ_EDCWB_BaseDF() + ":ResDispR")
    if (!WaveExists(wResR))
        Make/O/T/N=0 $(LJZ_EDCWB_BaseDF() + ":ResDispR")
    endif

    Wave/Z wResSelR = $(LJZ_EDCWB_BaseDF() + ":ResSelR")
    if (!WaveExists(wResSelR))
        Make/O/N=0 $(LJZ_EDCWB_BaseDF() + ":ResSelR") = 0
    endif

    return 0
End


// ============================================================================
//  Section 1. helpers
// ============================================================================

Function/S LJZ_EDCWB_WaveNameFromPath_Panel(wPath)
    String wPath

    Variable p = strsearch(wPath, ":", Inf)
    if (p < 0)
        return ""
    endif

    return wPath[p + 1, Inf]
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

Function LJZ_EDCWB_CurrentListCount()
    String listStr = LJZ_EDCWB_CurrentListStr()
    return ItemsInList(listStr, ";")
End

Function/S LJZ_EDCWB_ListEDCWaves(dfPath)
    String dfPath

    dfPath = LJZ_EDCWB_NormDFPath(dfPath)
    if (strlen(dfPath) == 0)
        return ""
    endif

    String out = ""
    Wave/Z w0 = $(dfPath + "edc_show_0")
    if (WaveExists(w0))
        Variable nObj = CountObjects(dfPath, 1)
        Variable k = 0
        do
            Wave/Z wk = $(dfPath + "edc_show_" + num2str(k))
            if (!WaveExists(wk))
                break
            endif
            if (LJZ_EDCWB_Is1DWave(wk))
                out = AddListItem(dfPath + NameOfWave(wk), out, ";", Inf)
            endif
            k += 1
            if (k > nObj)
                break
            endif
        while (1)
        return out
    endif

    Variable iObj
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

Function/S LJZ_EDCWB_CurrentListStr()
    SVAR sTarget = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
    return LJZ_EDCWB_ListEDCWaves(sTarget)
End

Function LJZ_EDCWB_SelectPrev()
    NVAR curRow = $(LJZ_EDCWB_BaseDF() + ":CurRow")
    return LJZ_EDCWB_SelectRow(max(0, curRow - 1))
End

Function LJZ_EDCWB_SelectNext()
    Variable n = LJZ_EDCWB_CurrentListCount()
    if (n <= 0)
        return -1
    endif

    NVAR curRow = $(LJZ_EDCWB_BaseDF() + ":CurRow")
    return LJZ_EDCWB_SelectRow(min(n - 1, curRow + 1))
End

Function LJZ_EDCWB_SelectNextUnchecked()
    String listStr = LJZ_EDCWB_CurrentListStr()
    Variable n = ItemsInList(listStr, ";")
    if (n <= 0)
        return -1
    endif

    NVAR curRow = $(LJZ_EDCWB_BaseDF() + ":CurRow")
    Variable i
    String wPath

    for (i = curRow + 1; i < n; i += 1)
        wPath = StringFromList(i, listStr, ";")
        if (LJZ_EDCWB_ReadAcceptState(wPath) == 0)
            return LJZ_EDCWB_SelectRow(i)
        endif
    endfor

    for (i = 0; i <= curRow && i < n; i += 1)
        wPath = StringFromList(i, listStr, ";")
        if (LJZ_EDCWB_ReadAcceptState(wPath) == 0)
            return LJZ_EDCWB_SelectRow(i)
        endif
    endfor

    return -1
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

    return LJZ_EDCWB_LoadCurrentWave()
End


// ============================================================================
//  Section 2. list / browser refresh
// ============================================================================

Function LJZ_EDCWB_RebuildListWaves()
    LJZ_EDCWB_EnsurePanelState()

    SVAR sTarget = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR curRow  = $(LJZ_EDCWB_BaseDF() + ":CurRow")

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
        nm = LJZ_EDCWB_WaveNameFromPath_Panel(wPath)
        wDisp[i] = LJZ_EDCWB_StatusTagForWave(wPath) + " " + nm
    endfor

    if (n <= 0)
        curRow = -1
        curPath = ""
        LJZ_EDCWB_RefreshMetricBox()
        LJZ_EDCWB_RefreshResultBox()
        return 0
    endif

    Variable hit = WhichListItem(curPath, listStr, ";", 0, 0)
    if (hit < 0)
        if (curRow < 0 || curRow >= n)
            curRow = 0
        endif
        hit = curRow
    endif

    curRow = hit
    curPath = StringFromList(hit, listStr, ";")
    wSel[hit] = 1

    return 0
End


// ============================================================================
//  Section 3. metrics / result box
// ============================================================================

Function LJZ_EDCWB_RefreshMetricBox()
    LJZ_EDCWB_EnsurePanelState()

    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")

    Make/O/T/N=0 $(LJZ_EDCWB_BaseDF() + ":MetricDisp")
    Make/O/N=0   $(LJZ_EDCWB_BaseDF() + ":MetricSel") = 0

    if (strlen(curPath) == 0)
        return 0
    endif

    Wave/Z fi = $(LJZ_EDCWB_ResultFitInfoPath(curPath))

    Variable n = 8
    Make/O/T/N=(n) $(LJZ_EDCWB_BaseDF() + ":MetricDisp")
    Make/O/N=(n)   $(LJZ_EDCWB_BaseDF() + ":MetricSel") = 0

    Wave/T wM = $(LJZ_EDCWB_BaseDF() + ":MetricDisp")

    Variable acc = LJZ_EDCWB_ReadAcceptState(curPath)

    wM[0] = "Wave = " + LJZ_EDCWB_WaveNameFromPath_Panel(curPath)
    wM[1] = "Accept = " + num2str(acc)

    if (WaveExists(fi))
        wM[2] = "ModelID = " + num2str(fi[LJZ_EDCWB_FI_ModelID()])
        wM[3] = "FitOK = " + num2str(fi[LJZ_EDCWB_FI_FitOK()])
        wM[4] = "FitRMSE = " + num2str(fi[LJZ_EDCWB_FI_FitRMSE()])
        wM[5] = "ChiSq = " + num2str(fi[LJZ_EDCWB_FI_ChiSq()])
        wM[6] = "MaxAbsRes = " + num2str(fi[LJZ_EDCWB_FI_MaxAbsRes()])
        wM[7] = "NROI = " + num2str(fi[LJZ_EDCWB_FI_NROI()])
    else
        wM[2] = "ModelID = NaN"
        wM[3] = "FitOK = NaN"
        wM[4] = "FitRMSE = NaN"
        wM[5] = "ChiSq = NaN"
        wM[6] = "MaxAbsRes = NaN"
        wM[7] = "NROI = NaN"
    endif

    return 0
End

Function LJZ_EDCWB_RefreshResultBox()
    LJZ_EDCWB_EnsurePanelState()

    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")

    Make/O/T/N=0 $(LJZ_EDCWB_BaseDF() + ":ResDispL")
    Make/O/N=0   $(LJZ_EDCWB_BaseDF() + ":ResSelL") = 0
    Make/O/T/N=0 $(LJZ_EDCWB_BaseDF() + ":ResDispR")
    Make/O/N=0   $(LJZ_EDCWB_BaseDF() + ":ResSelR") = 0

    if (strlen(curPath) == 0)
        return 0
    endif

    NVAR eModel = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    Wave/Z wPar = $(LJZ_EDCWB_BaseDF() + ":EditPar")
    Wave/Z wSig = $(LJZ_EDCWB_ResultFitSigmaPath(curPath))

    Variable nPar = 0
    Variable i
    for (i = 0; i < 12; i += 1)
        if (strlen(LJZ_EDCWB_ParamName(eModel, i)) > 0)
            nPar += 1
        endif
    endfor

    Make/O/T/N=(nPar) $(LJZ_EDCWB_BaseDF() + ":ResDispL")
    Make/O/N=(nPar)   $(LJZ_EDCWB_BaseDF() + ":ResSelL") = 0
    Make/O/T/N=(nPar) $(LJZ_EDCWB_BaseDF() + ":ResDispR")
    Make/O/N=(nPar)   $(LJZ_EDCWB_BaseDF() + ":ResSelR") = 0

    Wave/T wL = $(LJZ_EDCWB_BaseDF() + ":ResDispL")
    Wave/T wR = $(LJZ_EDCWB_BaseDF() + ":ResDispR")

    Variable j = 0
    for (i = 0; i < 12; i += 1)
        String pname = LJZ_EDCWB_ParamName(eModel, i)
        if (strlen(pname) <= 0)
            continue
        endif

        wL[j] = pname
        if (WaveExists(wPar))
            wR[j] = num2str(wPar[i])
            if (WaveExists(wSig))
                wR[j] += " ± " + num2str(wSig[i])
            endif
        else
            wR[j] = "NaN"
        endif
        j += 1
    endfor

    return 0
End


// ============================================================================
//  Section 4. graph
// ============================================================================

Function LJZ_EDCWB_CreatePreviewGraph()
    String g = LJZ_EDCWB_GraphName()

    DoWindow/F $g
    if (V_flag == 0)
        Display/HOST=$(LJZ_EDCWB_PanelName())/N=$g/W=(250,206,720,390)
    endif

    ModifyGraph/W=$g mirror=2
    Label/W=$g left "Intensity"
    Label/W=$g bottom "Energy"
    return 0
End

Function LJZ_EDCWB_SyncPanelControls()
    LJZ_EDCWB_EnsureDF()

    String p = LJZ_EDCWB_PanelName()
    if (WinType(p) == 0)
        return 0
    endif

    SVAR sTarget = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
    NVAR eModel  = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR eNorm   = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")
    NVAR smMethod = $(LJZ_EDCWB_BaseDF() + ":SmoothMethod")

    LJZ_EDCWB_SetSyncingControls(1)
    SetVariable svTarget win=$p, value=_STR:sTarget

    PopupMenu pmModel win=$p, popvalue=LJZ_EDCWB_ModelName(eModel)
    PopupMenu pmNorm win=$p, mode=(eNorm + 1)
    PopupMenu pmSmMethod win=$p, mode=(smMethod + 1)
    LJZ_EDCWB_SetSyncingControls(0)

    return 0
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
        LJZ_EDCWB_CreatePreviewGraph()
    endif

    RemoveFromGraph/Z/W=$g /A

    if (shRaw)
        Wave/Z w0 = LJZ_EDCWB_GetDisplayRawWave(curPath)
        if (WaveExists(w0))
            AppendToGraph/W=$g w0
            ModifyGraph/W=$g rgb($NameOfWave(w0))=(0,0,0)
        endif
    endif

    if (shSm)
        Wave/Z w1 = LJZ_EDCWB_GetDisplaySmoothWave(curPath)
        if (WaveExists(w1))
            AppendToGraph/W=$g w1
            ModifyGraph/W=$g rgb($NameOfWave(w1))=(0,0,65535)
        endif
    endif

    if (shGuess)
        Wave/Z wGuess = $(LJZ_EDCWB_ResultGuessPath(curPath))
        if (WaveExists(wGuess))
            AppendToGraph/W=$g wGuess
            ModifyGraph/W=$g lstyle($NameOfWave(wGuess))=3
            ModifyGraph/W=$g rgb($NameOfWave(wGuess))=(0,45000,0)
        endif
    endif

    if (shFit)
        Wave/Z wFit = $(LJZ_EDCWB_ResultFitPath(curPath))
        if (WaveExists(wFit))
            AppendToGraph/W=$g wFit
            ModifyGraph/W=$g rgb($NameOfWave(wFit))=(65535,0,0)
            ModifyGraph/W=$g lsize($NameOfWave(wFit))=1.5
        endif
    endif

    if (shRes)
        Wave/Z wRes = $(LJZ_EDCWB_ResultResPath(curPath))
        if (WaveExists(wRes))
            AppendToGraph/R/W=$g wRes
            ModifyGraph/W=$g rgb($NameOfWave(wRes))=(30000,30000,30000)
        endif
    endif

    ModifyGraph/W=$g mirror=2
    Label/W=$g left "Intensity"
    Label/W=$g right "Residual"
    Label/W=$g bottom "Energy"

    DoWindow/T $g, "EDC Preview : " + LJZ_EDCWB_WaveNameFromPath_Panel(curPath)
    return 0
End


// ============================================================================
//  Section 5. param table
// ============================================================================

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
//  Section 6. panel title refresh
// ============================================================================

Function LJZ_EDCWB_RefreshPanelTitles()
    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")

    String p = LJZ_EDCWB_PanelName()
    String suffix = ""

    if (LJZ_EDCWB_IsDirty())
        suffix = " *"
    endif

    if (strlen(curPath) > 0)
        DoWindow/T $p, "EDC Workbench" + suffix + " : " + LJZ_EDCWB_StatusTagForWave(curPath) + " " + LJZ_EDCWB_WaveNameFromPath_Panel(curPath)
    else
        DoWindow/T $p, "EDC Workbench" + suffix
    endif

    return 0
End


// ============================================================================
//  Section 7. load current wave
// ============================================================================

Function LJZ_EDCWB_LoadCurrentWave()
    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsurePanelState()

    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR eModel  = $(LJZ_EDCWB_BaseDF() + ":EditModelID")

    if (strlen(curPath) == 0)
        LJZ_EDCWB_SyncPanelControls()
        LJZ_EDCWB_RefreshMetricBox()
        LJZ_EDCWB_RefreshResultBox()
        LJZ_EDCWB_RefreshPanelTitles()
        return -1
    endif

    if (!LJZ_EDCWB_SourceWaveExists(curPath))
        LJZ_EDCWB_SyncPanelControls()
        LJZ_EDCWB_RefreshMetricBox()
        LJZ_EDCWB_RefreshResultBox()
        LJZ_EDCWB_RefreshPanelTitles()
        return -1
    endif

    LJZ_EDCWB_EnsureResultRecord(curPath)

    Variable ok = 0
    if (LJZ_EDCWB_HasFitRecord(curPath))
        ok = LJZ_EDCWB_LoadFitRecordToEditState(curPath)
        if (ok != 0)
            return -1
        endif
    elseif (LJZ_EDCWB_HasEditSnapshot(curPath))
        ok = LJZ_EDCWB_LoadEditSnapshotToEditState(curPath)
        if (ok != 0)
            return -1
        endif
    else
        LJZ_EDCWB_SetModel(eModel)
        LJZ_EDCWB_AutoGuessAndSave(curPath, eModel)
    endif

    LJZ_EDCWB_SyncPanelControls()
    LJZ_EDCWB_RebuildAllWorkWaves(curPath)
    LJZ_EDCWB_RefreshGraph()
    LJZ_EDCWB_RefreshMetricBox()
    LJZ_EDCWB_RefreshResultBox()
    LJZ_EDCWB_RefreshPanelTitles()

    return 0
End


// ============================================================================
//  Section 8. export
// ============================================================================

Function/S LJZ_EDCWB_SummaryPrefix()
    return "edcwb_summary_"
End

Function LJZ_EDCWB_ExportSummaryToTargetDF()
    LJZ_EDCWB_EnsureDF()

    SVAR sTarget = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
    if (strlen(sTarget) == 0)
        Print "EDCWB export: empty target DF."
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
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "bg0") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "bg1") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "x0") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "w") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "eta") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "Delta") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "Gamma") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "A") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "EF") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "T") = NaN
    Make/O/N=(n)   $(sTarget + LJZ_EDCWB_SummaryPrefix() + "res") = NaN

    Wave/T wName = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "name")
    Wave wAcc    = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "accept")
    Wave wModel  = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "modelID")
    Wave wFitOK  = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "fitOK")
    Wave wRMSE   = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "fitRMSE")
    Wave wChiSq  = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "chiSq")
    Wave wbg0    = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "bg0")
    Wave wbg1    = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "bg1")
    Wave wx0     = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "x0")
    Wave ww      = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "w")
    Wave wEta    = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "eta")
    Wave wDelta  = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "Delta")
    Wave wGamma  = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "Gamma")
    Wave wA      = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "A")
    Wave wEF     = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "EF")
    Wave wT      = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "T")
    Wave wRes    = $(sTarget + LJZ_EDCWB_SummaryPrefix() + "res")

    Variable i, modelID
    String wPath

    for (i = 0; i < n; i += 1)
        wPath = StringFromList(i, listStr, ";")
        wName[i] = LJZ_EDCWB_WaveNameFromPath_Panel(wPath)
        wAcc[i]  = LJZ_EDCWB_ReadAcceptState(wPath)

        Wave/Z fi = $(LJZ_EDCWB_ResultFitInfoPath(wPath))
        Wave/Z fc = $(LJZ_EDCWB_ResultFitCoefPath(wPath))
        if (!WaveExists(fi) || !WaveExists(fc))
            continue
        endif

        modelID   = fi[LJZ_EDCWB_FI_ModelID()]
        wModel[i] = modelID
        wFitOK[i] = fi[LJZ_EDCWB_FI_FitOK()]
        wRMSE[i]  = fi[LJZ_EDCWB_FI_FitRMSE()]
        wChiSq[i] = fi[LJZ_EDCWB_FI_ChiSq()]

        if (LJZ_EDCWB_ModelHasParam(modelID, "bg0"))
            wbg0[i] = fc[LJZ_EDCWB_ParamIndex(modelID, "bg0")]
        endif
        if (LJZ_EDCWB_ModelHasParam(modelID, "bg1"))
            wbg1[i] = fc[LJZ_EDCWB_ParamIndex(modelID, "bg1")]
        endif

        if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
            wx0[i]   = fc[LJZ_EDCWB_ParamIndex(modelID, "x0")]
            ww[i]    = fc[LJZ_EDCWB_ParamIndex(modelID, "w")]
            wEta[i]  = fc[LJZ_EDCWB_ParamIndex(modelID, "eta")]
            wA[i]    = fc[LJZ_EDCWB_ParamIndex(modelID, "A")]
            wEF[i]   = fc[LJZ_EDCWB_ParamIndex(modelID, "EF")]
            wT[i]    = fc[LJZ_EDCWB_ParamIndex(modelID, "T")]
            wRes[i]  = fc[LJZ_EDCWB_ParamIndex(modelID, "res")]
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


// ============================================================================
//  Section 9. panel creation
// ============================================================================

Window LJZ_EDCWB_P() : Panel
    PauseUpdate; Silent 1
    NewPanel /W=(120,60,980,650) /N=LJZ_EDCWB_Panel as "EDC Workbench"
    ModifyPanel frameStyle=1

    TitleBox tbT,pos={12,8},size={240,18},title="Target DF (default: EDCExtract runDF)",frame=0

    SetVariable svTarget,pos={12,28},size={500,20},proc=LJZ_EDCWB_SetVarProc,title="DF:"
    SetVariable svTarget,value=_STR:"root:Packages:ARPES_LJZ:EDCWB:TargetDF"

    Button btnRebuild,pos={525,27},size={95,22},proc=LJZ_EDCWB_ButtonProc,title="Refresh"

    ListBox lbWave,pos={12,58},size={220,520},proc=LJZ_EDCWB_ListBoxProc
    ListBox lbWave,listWave=$(LJZ_EDCWB_BaseDF() + ":LB_Disp")
    ListBox lbWave,selWave=$(LJZ_EDCWB_BaseDF() + ":LB_Sel"),mode=1

    PopupMenu pmModel,pos={250,62},size={170,20},proc=LJZ_EDCWB_PopupProc,title="Model:"
    PopupMenu pmModel,mode=1,popvalue="SinglePeak*FD*GaussConv",value=#"LJZ_EDCWB_ModelPopupList()"

    CheckBox cbUseSmGuess,pos={435,64},size={120,16},proc=LJZ_EDCWB_CheckProc,title="Use Sm Guess"
    CheckBox cbUseSmGuess,variable=$(LJZ_EDCWB_BaseDF() + ":UseSmoothForGuess")

    CheckBox cbFitOnSm,pos={560,64},size={90,16},proc=LJZ_EDCWB_CheckProc,title="Fit On Sm"
    CheckBox cbFitOnSm,variable=$(LJZ_EDCWB_BaseDF() + ":FitOnSmooth")

    Button btnPrev,pos={250,92},size={55,24},proc=LJZ_EDCWB_ButtonProc,title="Prev"
    Button btnNext,pos={315,92},size={55,24},proc=LJZ_EDCWB_ButtonProc,title="Next"
    Button btnNextUnchecked,pos={380,92},size={110,24},proc=LJZ_EDCWB_ButtonProc,title="Next Unchecked"

    SetVariable svXLo,pos={250,126},size={150,20},proc=LJZ_EDCWB_SetVarProc,title="xLo"
    SetVariable svXLo,variable=$(LJZ_EDCWB_BaseDF() + ":EditXLo")

    SetVariable svXHi,pos={415,126},size={150,20},proc=LJZ_EDCWB_SetVarProc,title="xHi"
    SetVariable svXHi,variable=$(LJZ_EDCWB_BaseDF() + ":EditXHi")

    SetVariable svTemp,pos={250,156},size={150,20},proc=LJZ_EDCWB_SetVarProc,title="T"
    SetVariable svTemp,variable=$(LJZ_EDCWB_BaseDF() + ":EditTemperature")

    SetVariable svEF,pos={415,156},size={150,20},proc=LJZ_EDCWB_SetVarProc,title="EF"
    SetVariable svEF,variable=$(LJZ_EDCWB_BaseDF() + ":EditEFermi")

    SetVariable svRes,pos={580,156},size={120,20},proc=LJZ_EDCWB_SetVarProc,title="Res"
    SetVariable svRes,variable=$(LJZ_EDCWB_BaseDF() + ":EditResolution")

    PopupMenu pmNorm,pos={250,186},size={160,20},proc=LJZ_EDCWB_PopupProc,title="Norm:"
    PopupMenu pmNorm,mode=1,popvalue="0:none",value="0:none;1:maxAbs;2:tailMean;3:ROIMax;"

    CheckBox cbSmEnable,pos={435,188},size={70,16},proc=LJZ_EDCWB_CheckProc,title="Smooth"
    CheckBox cbSmEnable,variable=$(LJZ_EDCWB_BaseDF() + ":SmoothEnable")

    PopupMenu pmSmMethod,pos={520,186},size={150,20},proc=LJZ_EDCWB_PopupProc,title=""
    PopupMenu pmSmMethod,mode=1,popvalue="0:none",value="0:none;1:Smooth;2:SmoothS;3:BLPF;"

    TitleBox tbPreviewHead,pos={250,214},size={80,18},title="Preview",frame=0,fStyle=1
    TitleBox tbParamHead,pos={250,402},size={90,18},title="Parameters",frame=0,fStyle=1

    GroupBox gbPreview,pos={244,234},size={470,160},title=""
    GroupBox gbParam,pos={244,424},size={470,154},title=""

    SetVariable svSmP1,pos={260,432},size={140,20},proc=LJZ_EDCWB_SetVarProc,title="SmP1"
    SetVariable svSmP1,variable=$(LJZ_EDCWB_BaseDF() + ":SmoothParam1")

    SetVariable svSmP2,pos={420,432},size={140,20},proc=LJZ_EDCWB_SetVarProc,title="SmP2"
    SetVariable svSmP2,variable=$(LJZ_EDCWB_BaseDF() + ":SmoothParam2")

    CheckBox cbShowRaw,pos={260,466},size={55,16},proc=LJZ_EDCWB_CheckProc,title="Raw"
    CheckBox cbShowRaw,variable=$(LJZ_EDCWB_BaseDF() + ":ShowRaw")
    CheckBox cbShowSm,pos={320,466},size={70,16},proc=LJZ_EDCWB_CheckProc,title="Smooth"
    CheckBox cbShowSm,variable=$(LJZ_EDCWB_BaseDF() + ":ShowSmooth")
    CheckBox cbShowGuess,pos={400,466},size={70,16},proc=LJZ_EDCWB_CheckProc,title="Guess"
    CheckBox cbShowGuess,variable=$(LJZ_EDCWB_BaseDF() + ":ShowGuess")
    CheckBox cbShowFit,pos={480,466},size={55,16},proc=LJZ_EDCWB_CheckProc,title="Fit"
    CheckBox cbShowFit,variable=$(LJZ_EDCWB_BaseDF() + ":ShowFit")
    CheckBox cbShowRes,pos={540,466},size={80,16},proc=LJZ_EDCWB_CheckProc,title="Residual"
    CheckBox cbShowRes,variable=$(LJZ_EDCWB_BaseDF() + ":ShowResidual")

    Button btnGuess,pos={260,504},size={78,24},proc=LJZ_EDCWB_ButtonProc,title="Guess"
    Button btnFit,pos={346,504},size={78,24},proc=LJZ_EDCWB_ButtonProc,title="Fit"
    Button btnRefit,pos={432,504},size={78,24},proc=LJZ_EDCWB_ButtonProc,title="Refit"

    Button btnAccept,pos={520,504},size={72,24},proc=LJZ_EDCWB_ButtonProc,title="Accept"
    Button btnReject,pos={598,504},size={72,24},proc=LJZ_EDCWB_ButtonProc,title="Reject"

    Button btnClearRec,pos={260,542},size={78,24},proc=LJZ_EDCWB_ButtonProc,title="ClearRec"
    Button btnReload,pos={346,542},size={78,24},proc=LJZ_EDCWB_ButtonProc,title="Reload"
    Button btnParam,pos={432,542},size={78,24},proc=LJZ_EDCWB_ButtonProc,title="Params"
    Button btnExport,pos={520,542},size={78,24},proc=LJZ_EDCWB_ButtonProc,title="Summary"
    Button btnGraph,pos={606,542},size={78,24},proc=LJZ_EDCWB_ButtonProc,title="Graph"

    TitleBox tbMetricHead,pos={740,12},size={70,20},title="Metrics",frame=0,fStyle=1
    GroupBox gbMetric,pos={740,36},size={220,210},title=""
    ListBox lbMetric,pos={750,48},size={200,190}
    ListBox lbMetric,listWave=$(LJZ_EDCWB_BaseDF() + ":MetricDisp")
    ListBox lbMetric,selWave=$(LJZ_EDCWB_BaseDF() + ":MetricSel"),mode=1

    TitleBox tbResHead,pos={740,258},size={85,20},title="Fit Result",frame=0,fStyle=1
    GroupBox gbRes,pos={740,282},size={220,300},title=""

    ListBox lbResL,pos={750,294},size={92,278}
    ListBox lbResL,listWave=$(LJZ_EDCWB_BaseDF() + ":ResDispL")
    ListBox lbResL,selWave=$(LJZ_EDCWB_BaseDF() + ":ResSelL"),mode=1

    ListBox lbResR,pos={852,294},size={98,278}
    ListBox lbResR,listWave=$(LJZ_EDCWB_BaseDF() + ":ResDispR")
    ListBox lbResR,selWave=$(LJZ_EDCWB_BaseDF() + ":ResSelR"),mode=1
EndMacro


// ============================================================================
//  Section 10. open panel
// ============================================================================

Function LJZ_EDCWB_OpenPanel()
    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsurePanelState()

    String p = LJZ_EDCWB_PanelName()
    if (WinType(p) != 0)
        DoWindow/F $p
        return 0
    endif

    Execute "LJZ_EDCWB_P()"
    LJZ_EDCWB_CreatePreviewGraph()
    LJZ_EDCWB_SyncPanelControls()

    return 0
End

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
    LJZ_EDCWB_SyncPanelControls()
    LJZ_EDCWB_RefreshMetricBox()
    LJZ_EDCWB_RefreshResultBox()
    LJZ_EDCWB_RefreshPanelTitles()

    return 0
End


// ============================================================================
//  Section 11. callbacks
// ============================================================================

Function LJZ_EDCWB_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    if (LJZ_EDCWB_IsSyncingControls() || LJZ_EDCWB_UIBusy())
        return 0
    endif

    String name = ba.ctrlName
    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR eModel  = $(LJZ_EDCWB_BaseDF() + ":EditModelID")

    if (CmpStr(name, "btnRebuild") == 0)
        LJZ_EDCWB_RebuildListWaves()
        LJZ_EDCWB_LoadCurrentWave()
        return 0
    endif

    if (CmpStr(name, "btnPrev") == 0)
        LJZ_EDCWB_SelectPrev()
        return 0
    endif

    if (CmpStr(name, "btnNext") == 0)
        LJZ_EDCWB_SelectNext()
        return 0
    endif

    if (CmpStr(name, "btnNextUnchecked") == 0)
        LJZ_EDCWB_SelectNextUnchecked()
        return 0
    endif

    if (CmpStr(name, "btnGuess") == 0)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_SyncAuxStateToPar()
            LJZ_EDCWB_ClearStoredFitOutputs(curPath)
            LJZ_EDCWB_AutoGuessAndSave(curPath, eModel)
            LJZ_EDCWB_RefreshGraph()
            LJZ_EDCWB_SyncPanelControls()
            LJZ_EDCWB_RefreshMetricBox()
            LJZ_EDCWB_RefreshResultBox()
            LJZ_EDCWB_RefreshPanelTitles()
        endif
        return 0
    endif

    if (CmpStr(name, "btnFit") == 0)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_SyncAuxStateToPar()
            LJZ_EDCWB_DoFitWave(curPath, eModel)
            LJZ_EDCWB_RefreshGraph()
            LJZ_EDCWB_SyncPanelControls()
            LJZ_EDCWB_RefreshMetricBox()
            LJZ_EDCWB_RefreshResultBox()
            LJZ_EDCWB_RefreshPanelTitles()
        endif
        return 0
    endif

    if (CmpStr(name, "btnRefit") == 0)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_SyncAuxStateToPar()
            LJZ_EDCWB_RefitCurrent()
            LJZ_EDCWB_RefreshGraph()
            LJZ_EDCWB_SyncPanelControls()
            LJZ_EDCWB_RefreshMetricBox()
            LJZ_EDCWB_RefreshResultBox()
            LJZ_EDCWB_RefreshPanelTitles()
        endif
        return 0
    endif

    if (CmpStr(name, "btnAccept") == 0)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_WriteAcceptState(curPath, 1)
            LJZ_EDCWB_RebuildListWaves()
            LJZ_EDCWB_RefreshMetricBox()
            LJZ_EDCWB_RefreshResultBox()
            LJZ_EDCWB_RefreshPanelTitles()
        endif
        return 0
    endif

    if (CmpStr(name, "btnReject") == 0)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_WriteAcceptState(curPath, -1)
            LJZ_EDCWB_RebuildListWaves()
            LJZ_EDCWB_RefreshMetricBox()
            LJZ_EDCWB_RefreshResultBox()
            LJZ_EDCWB_RefreshPanelTitles()
        endif
        return 0
    endif

    if (CmpStr(name, "btnClearRec") == 0)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_ClearFitRecord(curPath)
            LJZ_EDCWB_LoadCurrentWave()
        endif
        return 0
    endif

    if (CmpStr(name, "btnReload") == 0)
        LJZ_EDCWB_LoadCurrentWave()
        return 0
    endif

    if (CmpStr(name, "btnParam") == 0)
        LJZ_EDCWB_OpenParamTable()
        return 0
    endif

    if (CmpStr(name, "btnExport") == 0)
        LJZ_EDCWB_ExportSummaryToTargetDF()
        return 0
    endif

    if (CmpStr(name, "btnGraph") == 0)
        DoWindow/F $(LJZ_EDCWB_GraphName())
        return 0
    endif

    return 0
End

Function LJZ_EDCWB_SetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    if ((sva.eventCode != 1) && (sva.eventCode != 2))
        return 0
    endif

    if (LJZ_EDCWB_IsSyncingControls() || LJZ_EDCWB_UIBusy())
        return 0
    endif

    if (LJZ_EDCWB_BeginUIBusy() != 0)
        return 0
    endif

    String name = sva.ctrlName
    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR eModel  = $(LJZ_EDCWB_BaseDF() + ":EditModelID")

    if (CmpStr(name, "svTarget") == 0)
        LJZ_EDCWB_RebuildListWaves()
        LJZ_EDCWB_LoadCurrentWave()
        LJZ_EDCWB_EndUIBusy()
        return 0
    endif

    if ((CmpStr(name, "svTemp") == 0) || (CmpStr(name, "svEF") == 0) || (CmpStr(name, "svRes") == 0))
        LJZ_EDCWB_SyncAuxStateToPar()
        if (strlen(curPath) > 0)
            LJZ_EDCWB_ReguessCurrentWave(curPath, eModel, 1)
        endif
        LJZ_EDCWB_SyncPanelControls()
        LJZ_EDCWB_RefreshPanelTitles()
        LJZ_EDCWB_EndUIBusy()
        return 0
    endif

    if ((CmpStr(name, "svXLo") == 0) || (CmpStr(name, "svXHi") == 0) || (CmpStr(name, "svSmP1") == 0) || (CmpStr(name, "svSmP2") == 0))
        LJZ_EDCWB_MarkDirty(1)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_ReguessCurrentWave(curPath, eModel, 1)
        endif
        LJZ_EDCWB_SyncPanelControls()
        LJZ_EDCWB_RefreshPanelTitles()
        LJZ_EDCWB_EndUIBusy()
        return 0
    endif

    LJZ_EDCWB_EndUIBusy()
    return 0
End

Function LJZ_EDCWB_PopupProc(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa

    if (pa.eventCode != 2)
        return 0
    endif

    if (LJZ_EDCWB_IsSyncingControls() || LJZ_EDCWB_UIBusy())
        return 0
    endif

    if (LJZ_EDCWB_BeginUIBusy() != 0)
        return 0
    endif

    String name = pa.ctrlName
    String ps   = pa.popStr
    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR eModel  = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR smMethod = $(LJZ_EDCWB_BaseDF() + ":SmoothMethod")
    NVAR eNorm    = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")

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
            LJZ_EDCWB_ReguessCurrentWave(curPath, eModel, 1)
        endif
        LJZ_EDCWB_SyncPanelControls()
        LJZ_EDCWB_RefreshPanelTitles()
        LJZ_EDCWB_EndUIBusy()
        return 0
    endif

    if (CmpStr(name, "pmSmMethod") == 0)
        smMethod = str2num(StringFromList(0, ps, ":"))
        LJZ_EDCWB_MarkDirty(1)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_ReguessCurrentWave(curPath, eModel, 0)
        endif
        LJZ_EDCWB_SyncPanelControls()
        LJZ_EDCWB_RefreshPanelTitles()
        LJZ_EDCWB_EndUIBusy()
        return 0
    endif

    if (CmpStr(name, "pmNorm") == 0)
        eNorm = str2num(StringFromList(0, ps, ":"))
        LJZ_EDCWB_MarkDirty(1)
        if (strlen(curPath) > 0)
            LJZ_EDCWB_ReguessCurrentWave(curPath, eModel, 1)
        endif
        LJZ_EDCWB_SyncPanelControls()
        LJZ_EDCWB_RefreshPanelTitles()
        LJZ_EDCWB_EndUIBusy()
        return 0
    endif

    LJZ_EDCWB_EndUIBusy()
    return 0
End

Function LJZ_EDCWB_CheckProc(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba

    if (cba.eventCode != 2)
        return 0
    endif

    if (LJZ_EDCWB_IsSyncingControls() || LJZ_EDCWB_UIBusy())
        return 0
    endif

    if (LJZ_EDCWB_BeginUIBusy() != 0)
        return 0
    endif

    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR eModel  = $(LJZ_EDCWB_BaseDF() + ":EditModelID")

    if ((CmpStr(cba.ctrlName, "cbShowRaw") == 0) || (CmpStr(cba.ctrlName, "cbShowSm") == 0) || (CmpStr(cba.ctrlName, "cbShowGuess") == 0) || (CmpStr(cba.ctrlName, "cbShowFit") == 0) || (CmpStr(cba.ctrlName, "cbShowRes") == 0))
        if (strlen(curPath) > 0)
            LJZ_EDCWB_RefreshGraph()
        endif
        LJZ_EDCWB_EndUIBusy()
        return 0
    endif

    LJZ_EDCWB_MarkDirty(1)
    if (strlen(curPath) > 0)
        LJZ_EDCWB_ReguessCurrentWave(curPath, eModel, 1)
    endif
    LJZ_EDCWB_RefreshPanelTitles()
    LJZ_EDCWB_EndUIBusy()

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
