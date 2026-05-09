#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  LJZ_EDCWB Part 3 : Panel + Callbacks + Display + Export
//
//  Depends on:
//    - LJZ_EDCWB Part 1 : Core data model + Persistence
//    - LJZ_EDCWB Part 2 : Model + Fit Engine
//
//  Visual goals:
//    - Single panel `EDCIFit_LJZ_Panel`.
//    - Embedded preview and residual subwindows.
//    - Left-side EDC list, center model/parameter editor, right metrics/result.
//    - Buttons: Refresh / SaveEdit / AutoInit / Guess / Fit / Accept / Reject /
//               Clear / Prev / Next / Next Unchecked / Export.
//
//  Behavioral guarantees:
//    1) Switching selected EDC checks Dirty and prompts before discarding edits.
//    2) Building a preview never silently writes the edit-state to disk.
//    3) ListBox callbacks act only on eventCode == 4.
//    4) Manual SaveEdit and successful RunFit are the only routes that persist
//       the edit-state.
//    5) Export reads only clean fit records.
// ============================================================================


// ============================================================================
//  Section 0. Names, sizes, menu
// ============================================================================

Function/S LJZ_EDCWB_PanelName()
    return "EDCIFit_LJZ_Panel"
End

Function/S LJZ_EDCWB_PVGraphPath()
    return LJZ_EDCWB_PanelName() + "#pvGraph"
End

Function/S LJZ_EDCWB_RSGraphPath()
    return LJZ_EDCWB_PanelName() + "#rsGraph"
End

Function/S LJZ_EDCWB_WaveListBoxName()
    return "lbEDC"
End

Function/S LJZ_EDCWB_ParListBoxName()
    return "lbPar"
End

Menu "ARPES_LJZ"
    "EDC Workbench", LJZ_EDCWB_OpenPanel()
End


// ============================================================================
//  Section 1. UI runtime state
// ============================================================================

Function LJZ_EDCWB_EnsurePanelState()
    LJZ_EDCWB_EnsureBaseDF()

    String base = LJZ_EDCWB_BaseDF()

    Wave/T/Z waveDisp = $(base + ":UI_waveDisp")
    if (!WaveExists(waveDisp))
        Make/O/T/N=1 $(base + ":UI_waveDisp") = "(empty)"
    endif
    Wave/Z waveSel = $(base + ":UI_waveSel")
    if (!WaveExists(waveSel))
        Make/O/N=1 $(base + ":UI_waveSel") = 0
    endif
    Wave/T/Z wavePath = $(base + ":UI_wavePath")
    if (!WaveExists(wavePath))
        Make/O/T/N=1 $(base + ":UI_wavePath") = ""
    endif

    Wave/T/Z parDisp = $(base + ":UI_parDisp")
    if (!WaveExists(parDisp))
        Make/O/T/N=1 $(base + ":UI_parDisp") = ""
    endif
    Wave/Z parSel = $(base + ":UI_parSel")
    if (!WaveExists(parSel))
        Make/O/N=1 $(base + ":UI_parSel") = 0
    endif

    NVAR/Z selPar = $(base + ":UI_selectedPar")
    if (!NVAR_Exists(selPar))
        Variable/G $(base + ":UI_selectedPar") = 0
    endif

    Wave/T/Z metricDisp = $(base + ":UI_metricDisp")
    if (!WaveExists(metricDisp))
        Make/O/T/N=1 $(base + ":UI_metricDisp") = ""
    endif
    Wave/Z metricSel = $(base + ":UI_metricSel")
    if (!WaveExists(metricSel))
        Make/O/N=1 $(base + ":UI_metricSel") = 0
    endif

    Wave/T/Z resDispL = $(base + ":UI_resDispL")
    if (!WaveExists(resDispL))
        Make/O/T/N=1 $(base + ":UI_resDispL") = ""
    endif
    Wave/Z resSelL = $(base + ":UI_resSelL")
    if (!WaveExists(resSelL))
        Make/O/N=1 $(base + ":UI_resSelL") = 0
    endif
    Wave/T/Z resDispR = $(base + ":UI_resDispR")
    if (!WaveExists(resDispR))
        Make/O/T/N=1 $(base + ":UI_resDispR") = ""
    endif
    Wave/Z resSelR = $(base + ":UI_resSelR")
    if (!WaveExists(resSelR))
        Make/O/N=1 $(base + ":UI_resSelR") = 0
    endif

    NVAR/Z useCsr = $(base + ":UseCursors")
    if (!NVAR_Exists(useCsr))
        Variable/G $(base + ":UseCursors") = 1
    endif

    NVAR/Z autoPreview = $(base + ":UI_autoPreview")
    if (!NVAR_Exists(autoPreview))
        Variable/G $(base + ":UI_autoPreview") = 1
    endif

    return 0
End


// ============================================================================
//  Section 2. Small UI helpers
// ============================================================================

Function/S LJZ_EDCWB_StateMark(state)
    Variable state
    if (state > 0)
        return "✓ "
    elseif (state < 0)
        return "✗ "
    endif
    return "· "
End

Function/S LJZ_EDCWB_RowMark(state, isCurrent, isDirty)
    Variable state, isCurrent, isDirty
    String s = LJZ_EDCWB_StateMark(state)
    if (isCurrent && isDirty)
        return "~" + s
    endif
    return s
End

Function/S LJZ_EDCWB_FormatNum(v)
    Variable v
    if (numtype(v) != 0)
        return "NaN"
    endif
    return num2str(v)
End

Function/S LJZ_EDCWB_TrimTrailingCR(s)
    String s
    do
        if (strlen(s) <= 0)
            break
        endif
        if (cmpstr(s[strlen(s)-1, strlen(s)-1], "\r") == 0)
            s = s[0, strlen(s)-2]
        else
            break
        endif
    while (1)
    return s
End

Function LJZ_EDCWB_TextToListWave(textW, selW, src)
    Wave/T textW
    Wave selW
    String src

    src = LJZ_EDCWB_TrimTrailingCR(src)
    if (strlen(src) == 0)
        Redimension/N=1 textW, selW
        textW[0] = ""
        selW[0] = 0
        return 0
    endif

    String lst = ReplaceString("\r", src, ";")
    Variable n = ItemsInList(lst, ";")
    if (n <= 0)
        n = 1
    endif

    Redimension/N=(n) textW, selW
    Variable i
    for (i = 0; i < n; i += 1)
        textW[i] = StringFromList(i, lst, ";")
        selW[i] = 0
    endfor
    return 0
End

Function LJZ_EDCWB_HasChild(host, child)
    String host, child
    String kids = ChildWindowList(host)
    return WhichListItem(child, kids, ";", 0, 0) >= 0
End

Function LJZ_EDCWB_ClearGraphTraces(winPath)
    String winPath
    String tl = TraceNameList(winPath, ";", 1)
    Variable n = ItemsInList(tl, ";")
    Variable i
    for (i = 0; i < n; i += 1)
        String tr = StringFromList(i, tl, ";")
        if (strlen(tr) > 0)
            RemoveFromGraph/Z/W=$winPath $tr
        endif
    endfor
    return 0
End

Function LJZ_EDCWB_ConfirmLeaveIfDirty()
    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR curRow  = $(LJZ_EDCWB_BaseDF() + ":CurRow")

    if (strlen(curPath) == 0 || curRow < 0)
        return 1
    endif
    if (!LJZ_EDCWB_IsDirty())
        return 1
    endif

    DoAlert 1, "Current EDC has unsaved/stale edits. Discard them and continue?"
    if (V_flag == 1)
        return 1
    endif
    return 0
End

Function/S LJZ_EDCWB_ParName(modelID, idx)
    Variable modelID, idx

    if (modelID == LJZ_EDCWB_Model_SinglePeakFD())
        if (idx == 0)
            return "bg0"
        elseif (idx == 1)
            return "bg1"
        elseif (idx == 2)
            return "A"
        elseif (idx == 3)
            return "x0"
        elseif (idx == 4)
            return "w"
        elseif (idx == 5)
            return "eta"
        elseif (idx == 6)
            return "T"
        elseif (idx == 7)
            return "EF"
        elseif (idx == 8)
            return "res"
        endif
    elseif (modelID == LJZ_EDCWB_Model_EffectiveGap())
        if (idx == 0)
            return "bg0"
        elseif (idx == 1)
            return "bg1"
        elseif (idx == 2)
            return "A"
        elseif (idx == 3)
            return "Delta"
        elseif (idx == 4)
            return "Gamma"
        elseif (idx == 5)
            return "T"
        elseif (idx == 6)
            return "EF"
        elseif (idx == 7)
            return "res"
        endif
    elseif (modelID == LJZ_EDCWB_Model_SymGap())
        if (idx == 0)
            return "bg0"
        elseif (idx == 1)
            return "bg1"
        elseif (idx == 2)
            return "A"
        elseif (idx == 3)
            return "Delta"
        elseif (idx == 4)
            return "Gamma"
        elseif (idx == 5)
            return "x0"
        endif
    endif

    return "p" + num2str(idx)
End

Function LJZ_EDCWB_ModelToPopupMode(modelID)
    Variable modelID
    if (modelID == LJZ_EDCWB_Model_EffectiveGap())
        return 2
    elseif (modelID == LJZ_EDCWB_Model_SymGap())
        return 3
    endif
    return 1
End

Function LJZ_EDCWB_ModelFromPopupMode(popNum)
    Variable popNum
    if (popNum == 2)
        return LJZ_EDCWB_Model_EffectiveGap()
    elseif (popNum == 3)
        return LJZ_EDCWB_Model_SymGap()
    endif
    return LJZ_EDCWB_Model_SinglePeakFD()
End


// ============================================================================
//  Section 3. Wave list rebuild and selection
// ============================================================================

Function LJZ_EDCWB_RebuildWaveList()
    LJZ_EDCWB_EnsurePanelState()

    String base = LJZ_EDCWB_BaseDF()
    SVAR target  = $(base + ":TargetDF")
    SVAR curPath = $(base + ":CurWavePath")
    NVAR curRow  = $(base + ":CurRow")

    String oldPath = curPath
    Variable oldDirty = LJZ_EDCWB_IsDirty()

    String df = LJZ_EDCWB_NormDFPath(target)
    String lst = ""
    if (strlen(df) > 0)
        lst = LJZ_EDCWB_ListEDCWaves(df)
    endif

    Variable nReal = ItemsInList(lst, ";")
    Variable n = nReal
    if (n <= 0)
        n = 1
    endif

    Make/O/T/N=(n) $(base + ":UI_waveDisp")
    Make/O/N=(n)   $(base + ":UI_waveSel")
    Make/O/T/N=(n) $(base + ":UI_wavePath")

    Wave/T disp = $(base + ":UI_waveDisp")
    Wave/T pathW = $(base + ":UI_wavePath")
    Wave   sel  = $(base + ":UI_waveSel")

    sel = 0
    if (nReal <= 0)
        disp[0] = "(no EDC waves)"
        pathW[0] = ""
        curRow = -1
        curPath = ""
        return 0
    endif

    Variable i
    Variable foundOld = -1
    for (i = 0; i < nReal; i += 1)
        String full = StringFromList(i, lst, ";")
        Wave/Z w = $full
        if (!WaveExists(w))
            disp[i] = "(missing)"
            pathW[i] = ""
            continue
        endif
        Variable st = LJZ_EDCWB_ReadAcceptState(w)
        Variable isCur = (cmpstr(full, oldPath) == 0)
        disp[i] = LJZ_EDCWB_RowMark(st, isCur, oldDirty) + NameOfWave(w)
        pathW[i] = full
        if (isCur)
            foundOld = i
        endif
    endfor

    if (foundOld >= 0)
        curRow = foundOld
        curPath = pathW[foundOld]
        sel[foundOld] = 1
    else
        curRow = -1
        curPath = ""
        LJZ_EDCWB_MarkDirty(1)
    endif

    return 0
End

Function LJZ_EDCWB_SelectWaveRow(row)
    Variable row

    LJZ_EDCWB_EnsurePanelState()

    Wave/T pathW = $(LJZ_EDCWB_BaseDF() + ":UI_wavePath")
    Wave   sel  = $(LJZ_EDCWB_BaseDF() + ":UI_waveSel")

    if (row < 0 || row >= numpnts(pathW))
        return -1
    endif
    String full = pathW[row]
    if (strlen(full) == 0)
        return -1
    endif
    Wave/Z w = $full
    if (!WaveExists(w))
        return -1
    endif

    NVAR curRow  = $(LJZ_EDCWB_BaseDF() + ":CurRow")
    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")

    curRow = row
    curPath = full

    sel = 0
    sel[row] = 1
    ListBox/Z $LJZ_EDCWB_WaveListBoxName(), win=$LJZ_EDCWB_PanelName(), selRow=row

    LJZ_EDCWB_LoadCurrentToWork(w)
    return 0
End

Function LJZ_EDCWB_FindNextUnchecked(startRow)
    Variable startRow

    Wave/T pathW = $(LJZ_EDCWB_BaseDF() + ":UI_wavePath")
    Variable n = numpnts(pathW)
    Variable i
    for (i = startRow + 1; i < n; i += 1)
        String full = pathW[i]
        if (strlen(full) == 0)
            continue
        endif
        Wave/Z w = $full
        if (!WaveExists(w))
            continue
        endif
        if (LJZ_EDCWB_ReadAcceptState(w) == 0)
            return i
        endif
    endfor
    return -1
End


// ============================================================================
//  Section 4. Parameter list and editor
// ============================================================================

Function LJZ_EDCWB_RebuildParList()
    LJZ_EDCWB_EnsurePanelState()

    String base = LJZ_EDCWB_BaseDF()
    Wave/T disp = $(base + ":UI_parDisp")
    Wave   sel  = $(base + ":UI_parSel")
    NVAR selPar = $(base + ":UI_selectedPar")

    Variable m = LJZ_EDCWB_WorkGetModelID()
    Variable nPar = LJZ_EDCWB_ModelNPar(m)
    Wave wPar = $(base + ":Work_par")
    Wave wHold = $(base + ":Work_hold")

    Variable nDisp = max(1, nPar)
    Redimension/N=(nDisp) disp, sel
    sel = 0
    disp = ""

    if (nPar <= 0)
        disp[0] = "(no parameters)"
        return 0
    endif

    selPar = max(0, min(nPar - 1, selPar))

    Variable i
    for (i = 0; i < nPar; i += 1)
        String row
        sprintf row, "%02d %-7s = %s  hold=%d", i, LJZ_EDCWB_ParName(m, i), LJZ_EDCWB_FormatNum(wPar[i]), round(wHold[i] != 0)
        disp[i] = row
        if (i == selPar)
            sel[i] = 1
        endif
    endfor

    return 0
End

Function LJZ_EDCWB_SelectParRow(row)
    Variable row

    LJZ_EDCWB_EnsurePanelState()
    Variable m = LJZ_EDCWB_WorkGetModelID()
    Variable nPar = LJZ_EDCWB_ModelNPar(m)
    if (row < 0 || row >= nPar)
        return -1
    endif

    NVAR selPar = $(LJZ_EDCWB_BaseDF() + ":UI_selectedPar")
    Wave sel = $(LJZ_EDCWB_BaseDF() + ":UI_parSel")
    selPar = row
    sel = 0
    sel[row] = 1
    ListBox/Z $LJZ_EDCWB_ParListBoxName(), win=$LJZ_EDCWB_PanelName(), selRow=row
    return 0
End

Function LJZ_EDCWB_RefreshParEditor()
    String panel = LJZ_EDCWB_PanelName()
    DoWindow $panel
    if (!V_flag)
        return 0
    endif

    LJZ_EDCWB_EnsureBaseDF()
    NVAR selPar = $(LJZ_EDCWB_BaseDF() + ":UI_selectedPar")
    Variable m = LJZ_EDCWB_WorkGetModelID()
    Variable nPar = LJZ_EDCWB_ModelNPar(m)
    Variable hasSel = (selPar >= 0 && selPar < nPar)

    SetVariable svParValue, win=$panel, disable=(!hasSel)
    CheckBox cbParHold, win=$panel, disable=(!hasSel)
    TitleBox tbParName, win=$panel, title="Selected parameter: "

    if (!hasSel)
        SetVariable svParValue, win=$panel, value=_NUM:NaN
        CheckBox cbParHold, win=$panel, value=0
        return 0
    endif

    Wave wPar = $(LJZ_EDCWB_BaseDF() + ":Work_par")
    Wave wHold = $(LJZ_EDCWB_BaseDF() + ":Work_hold")

    TitleBox tbParName, win=$panel, title="Selected parameter: " + num2str(selPar) + "  " + LJZ_EDCWB_ParName(m, selPar)
    SetVariable svParValue, win=$panel, value=_NUM:wPar[selPar]
    CheckBox cbParHold, win=$panel, value=wHold[selPar]
    return 0
End

Function LJZ_EDCWB_RefreshModelRoiControls()
    String panel = LJZ_EDCWB_PanelName()
    DoWindow $panel
    if (!V_flag)
        return 0
    endif

    LJZ_EDCWB_EnsureBaseDF()

    Variable m = LJZ_EDCWB_WorkGetModelID()
    PopupMenu pmModel, win=$panel, mode=LJZ_EDCWB_ModelToPopupMode(m)

    Variable nm = LJZ_EDCWB_WorkGetNormMode()
    nm = max(0, min(2, round(nm)))
    PopupMenu pmNorm, win=$panel, mode=(nm + 1)

    SetVariable svT,   win=$panel, value=_NUM:LJZ_EDCWB_WorkGetT()
    SetVariable svEF,  win=$panel, value=_NUM:LJZ_EDCWB_WorkGetEF()
    SetVariable svRes, win=$panel, value=_NUM:LJZ_EDCWB_WorkGetRes()

    Variable disablePhys = (m == LJZ_EDCWB_Model_SymGap()) ? 2 : 0
    SetVariable svT,   win=$panel, disable=disablePhys
    SetVariable svRes, win=$panel, disable=disablePhys
    // EF still useful as a symmetry-center preset for SymGap auto-init, so keep it editable.
    SetVariable svEF,  win=$panel, disable=0

    Variable xLo, xHi
    LJZ_EDCWB_WorkGetROI(xLo, xHi)
    SetVariable svXLo, win=$panel, value=_NUM:xLo
    SetVariable svXHi, win=$panel, value=_NUM:xHi

    NVAR useCsr = $(LJZ_EDCWB_BaseDF() + ":UseCursors")
    CheckBox cbCsr, win=$panel, value=useCsr

    SVAR target = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
    SetVariable svTarget, win=$panel, value=_STR:target

    return 0
End


// ============================================================================
//  Section 5. Preview / residual graph
// ============================================================================

Function LJZ_EDCWB_CreatePreviewGraphs()
    String panel = LJZ_EDCWB_PanelName()
    DoWindow $panel
    if (!V_flag)
        return -1
    endif

    KillWindow/Z $LJZ_EDCWB_PVGraphPath()
    KillWindow/Z $LJZ_EDCWB_RSGraphPath()

    Display/HOST=$panel/N=pvGraph/W=(252, 36, 564, 236)
    ModifyGraph/W=$LJZ_EDCWB_PVGraphPath() margin(left)=44, margin(bottom)=18, mirror=1
    Label/W=$LJZ_EDCWB_PVGraphPath() left "Intensity"

    Display/HOST=$panel/N=rsGraph/W=(252, 240, 564, 310)
    ModifyGraph/W=$LJZ_EDCWB_RSGraphPath() margin(left)=44, margin(bottom)=28, mirror=1
    Label/W=$LJZ_EDCWB_RSGraphPath() left "Res"
    Label/W=$LJZ_EDCWB_RSGraphPath() bottom "Energy"

    return 0
End

Function/S LJZ_EDCWB_PreviewGuessPath()
    return LJZ_EDCWB_BaseDF() + ":UI_guessPreview"
End

Function LJZ_EDCWB_BuildPreviewGuess(wData)
    Wave wData

    LJZ_EDCWB_EnsureFitEngineState()
    LJZ_EDCWB_SanitizeWorkState()

    Wave wPar = $(LJZ_EDCWB_BaseDF() + ":Work_par")
    Duplicate/O wData, $LJZ_EDCWB_PreviewGuessPath()
    Wave gw = $LJZ_EDCWB_PreviewGuessPath()
    LJZ_EDCWB_EvalModelFull(wData, wPar, gw)
    return 0
End

Function LJZ_EDCWB_RefreshPreviewGraph()
    String panel = LJZ_EDCWB_PanelName()
    DoWindow $panel
    if (!V_flag)
        return -1
    endif

    if (!LJZ_EDCWB_HasChild(panel, "pvGraph") || !LJZ_EDCWB_HasChild(panel, "rsGraph"))
        LJZ_EDCWB_CreatePreviewGraphs()
    endif

    String pvPath = LJZ_EDCWB_PVGraphPath()
    String rsPath = LJZ_EDCWB_RSGraphPath()

    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    if (strlen(curPath) == 0)
        LJZ_EDCWB_ClearGraphTraces(pvPath)
        LJZ_EDCWB_ClearGraphTraces(rsPath)
        TextBox/W=$pvPath/K/N=pvStatus
        return -1
    endif

    Wave/Z wData = $curPath
    if (!WaveExists(wData))
        LJZ_EDCWB_ClearGraphTraces(pvPath)
        LJZ_EDCWB_ClearGraphTraces(rsPath)
        TextBox/W=$pvPath/K/N=pvStatus
        return -1
    endif

    Variable previewOK = 0
    if (LJZ_EDCWB_BuildPreviewGuess(wData) == 0)
        previewOK = 1
    endif
    if (!previewOK)
        KillWaves/Z $LJZ_EDCWB_PreviewGuessPath()
    endif

    Wave/Z guessW = $LJZ_EDCWB_PreviewGuessPath()
    Wave/Z fitW   = $LJZ_EDCWB_PathFit(wData)
    Wave/Z resW   = $LJZ_EDCWB_PathRes(wData)

    Variable dirty = LJZ_EDCWB_IsDirty()

    Variable xLo, xHi
    LJZ_EDCWB_WorkGetROI(xLo, xHi)
    Variable dx = abs(DimDelta(wData, 0))
    if (numtype(dx) != 0 || dx <= 0)
        dx = 1
    endif

    Variable showLo, showHi
    Variable useROI = 0
    if (numtype(xLo) == 0 && numtype(xHi) == 0 && xLo != xHi)
        Variable a = min(xLo, xHi)
        Variable b = max(xLo, xHi)
        Variable pad = max(0.08 * abs(b - a), 2 * dx)
        showLo = a - pad
        showHi = b + pad
        useROI = 1
    endif
    if (!useROI)
        showLo = DimOffset(wData, 0)
        showHi = showLo + DimDelta(wData, 0) * (numpnts(wData) - 1)
        if (showLo > showHi)
            Variable tmpX = showLo
            showLo = showHi
            showHi = tmpX
        endif
    endif

    LJZ_EDCWB_ClearGraphTraces(pvPath)
    AppendToGraph/W=$pvPath wData
    if (previewOK && WaveExists(guessW))
        AppendToGraph/W=$pvPath guessW
    endif
    if ((!dirty) && WaveExists(fitW))
        AppendToGraph/W=$pvPath fitW
    endif

    ModifyGraph/W=$pvPath mode=0, lsize=1.5
    ModifyGraph/W=$pvPath rgb($NameOfWave(wData))=(0,0,0)
    if (previewOK && WaveExists(guessW))
        ModifyGraph/W=$pvPath rgb($NameOfWave(guessW))=(0,0,65535), lstyle($NameOfWave(guessW))=2
    endif
    if ((!dirty) && WaveExists(fitW))
        ModifyGraph/W=$pvPath rgb($NameOfWave(fitW))=(65535,0,0)
    endif

    SetAxis/W=$pvPath bottom, showLo, showHi
    SetAxis/W=$pvPath/A=2 left

    if (!previewOK)
        TextBox/W=$pvPath/C/N=pvStatus/F=0/A=RT/X=-2/Y=2 "\\Z11Preview unavailable"
    elseif (dirty)
        TextBox/W=$pvPath/C/N=pvStatus/F=0/A=RT/X=-2/Y=2 "\\Z11Preview dirty"
    else
        TextBox/W=$pvPath/C/N=pvStatus/F=0/A=RT/X=-2/Y=2 "\\Z11Fit current"
    endif

    LJZ_EDCWB_ClearGraphTraces(rsPath)
    if ((!dirty) && WaveExists(resW))
        AppendToGraph/W=$rsPath resW
        ModifyGraph/W=$rsPath mode=0, lsize=1.2
        ModifyGraph/W=$rsPath rgb($NameOfWave(resW))=(30000,30000,30000)
    endif
    SetAxis/W=$rsPath bottom, showLo, showHi
    SetAxis/W=$rsPath/A=2 left

    return 0
End


// ============================================================================
//  Section 6. Metrics + Fit Result list boxes
// ============================================================================

Function LJZ_EDCWB_RefreshMetricBoxes()
    LJZ_EDCWB_EnsurePanelState()

    String base = LJZ_EDCWB_BaseDF()
    Wave/T mDisp = $(base + ":UI_metricDisp")
    Wave   mSel  = $(base + ":UI_metricSel")
    Wave/T rDispL = $(base + ":UI_resDispL")
    Wave   rSelL  = $(base + ":UI_resSelL")
    Wave/T rDispR = $(base + ":UI_resDispR")
    Wave   rSelR  = $(base + ":UI_resSelR")

    SVAR curPath = $(base + ":CurWavePath")
    if (strlen(curPath) == 0)
        LJZ_EDCWB_TextToListWave(mDisp, mSel, "No EDC selected.")
        LJZ_EDCWB_TextToListWave(rDispL, rSelL, "")
        LJZ_EDCWB_TextToListWave(rDispR, rSelR, "")
        return 0
    endif

    Wave/Z wData = $curPath
    if (!WaveExists(wData))
        LJZ_EDCWB_TextToListWave(mDisp, mSel, "Selected wave missing.")
        LJZ_EDCWB_TextToListWave(rDispL, rSelL, "")
        LJZ_EDCWB_TextToListWave(rDispR, rSelR, "")
        return 0
    endif

    Wave wPar = $(base + ":Work_par")
    Wave wHold = $(base + ":Work_hold")
    Wave/Z coefW  = $(LJZ_EDCWB_PathFitCoef(wData))
    Wave/Z sigmaW = $(LJZ_EDCWB_PathFitSigma(wData))
    Wave/Z infoW  = $(LJZ_EDCWB_PathFitInfo(wData))

    Variable xLo, xHi
    LJZ_EDCWB_WorkGetROI(xLo, xHi)
    Variable accept = LJZ_EDCWB_ReadAcceptState(wData)
    Variable dirty = LJZ_EDCWB_IsDirty()
    Variable m = LJZ_EDCWB_WorkGetModelID()
    Variable nPar = LJZ_EDCWB_ModelNPar(m)

    String mTxt = ""
    mTxt += "Wave: " + NameOfWave(wData) + "\r"
    mTxt += "Model: " + LJZ_EDCWB_ModelName(m) + "\r"
    mTxt += "ROI: [" + LJZ_EDCWB_FormatNum(xLo) + ", " + LJZ_EDCWB_FormatNum(xHi) + "]\r"
    mTxt += "T: " + LJZ_EDCWB_FormatNum(LJZ_EDCWB_WorkGetT()) + " K\r"
    mTxt += "EF: " + LJZ_EDCWB_FormatNum(LJZ_EDCWB_WorkGetEF()) + "\r"
    mTxt += "res: " + LJZ_EDCWB_FormatNum(LJZ_EDCWB_WorkGetRes()) + "\r"
    mTxt += "NormMode: " + num2str(LJZ_EDCWB_WorkGetNormMode()) + "\r"

    String stateTxt = "Unchecked"
    if (accept > 0)
        stateTxt = "Accepted"
    elseif (accept < 0)
        stateTxt = "Rejected"
    endif
    if (dirty && accept != 0)
        stateTxt += " (last clean fit)"
    endif
    mTxt += "State: " + stateTxt + "\r"
    mTxt += "N(all): " + num2str(numpnts(wData)) + "\r"

    if (dirty)
        mTxt += "Preview is dirty\r"
        mTxt += "FitRMSE: stale\r"
        mTxt += "RSS(ROI): stale\r"
        mTxt += "max|res|: stale\r"
        mTxt += "N(ROI): stale\r"
    else
        if (WaveExists(infoW) && numpnts(infoW) >= LJZ_EDCWB_FitInfoSize())
            mTxt += "GuessRMSE: " + LJZ_EDCWB_FormatNum(infoW[LJZ_EDCWB_FI_GuessRMSE()]) + "\r"
            mTxt += "FitRMSE: "   + LJZ_EDCWB_FormatNum(infoW[LJZ_EDCWB_FI_FitRMSE()]) + "\r"
            mTxt += "RSS(ROI): "  + LJZ_EDCWB_FormatNum(infoW[LJZ_EDCWB_FI_RssROI()]) + "\r"
            mTxt += "max|res|: "  + LJZ_EDCWB_FormatNum(infoW[LJZ_EDCWB_FI_MaxAbsRes()]) + "\r"
            mTxt += "N(ROI): "    + LJZ_EDCWB_FormatNum(infoW[LJZ_EDCWB_FI_NROI()]) + "\r"
        else
            mTxt += "FitRMSE: --\r"
            mTxt += "RSS(ROI): --\r"
            mTxt += "max|res|: --\r"
            mTxt += "N(ROI): --\r"
        endif
    endif

    String err = LJZ_EDCWB_GetLastError()
    if (strlen(err) > 0)
        mTxt += "ERR: " + err + "\r"
    endif

    LJZ_EDCWB_TextToListWave(mDisp, mSel, mTxt)

    String lTxt = ""
    String rTxt = ""
    Variable hasCompleteFit = WaveExists(coefW) && WaveExists(sigmaW) && WaveExists(infoW)
    if (hasCompleteFit)
        hasCompleteFit = (numpnts(coefW) > 0 && numpnts(sigmaW) == numpnts(coefW) && numpnts(infoW) >= LJZ_EDCWB_FitInfoSize())
    endif

    Variable i
    if (dirty || !hasCompleteFit)
        lTxt = "Current preview\r"
        rTxt = "Hold\r"
        for (i = 0; i < nPar; i += 1)
            lTxt += LJZ_EDCWB_ParName(m, i) + "= " + LJZ_EDCWB_FormatNum(wPar[i]) + "\r"
            rTxt += num2str(round(wHold[i] != 0)) + "\r"
        endfor
    else
        Variable mFit = round(infoW[LJZ_EDCWB_FI_ModelID()])
        lTxt = "Fitted params\r"
        rTxt = "Sigma (1σ)\r"
        Variable nf = numpnts(coefW)
        for (i = 0; i < nf; i += 1)
            lTxt += LJZ_EDCWB_ParName(mFit, i) + "= " + LJZ_EDCWB_FormatNum(coefW[i]) + "\r"
            rTxt += "± " + LJZ_EDCWB_FormatNum(sigmaW[i]) + "\r"
        endfor
    endif

    LJZ_EDCWB_TextToListWave(rDispL, rSelL, lTxt)
    LJZ_EDCWB_TextToListWave(rDispR, rSelR, rTxt)

    return 0
End


// ============================================================================
//  Section 7. Cursor → ROI helper
// ============================================================================

Function LJZ_EDCWB_PullROIFromCursorsIfWanted()
    LJZ_EDCWB_EnsureBaseDF()
    NVAR useCsr = $(LJZ_EDCWB_BaseDF() + ":UseCursors")
    if (!useCsr)
        return 0
    endif

    String pvPath = LJZ_EDCWB_PVGraphPath()
    DoWindow $LJZ_EDCWB_PanelName()
    if (!V_flag)
        return 0
    endif
    if (!LJZ_EDCWB_HasChild(LJZ_EDCWB_PanelName(), "pvGraph"))
        return 0
    endif

    String iA = CsrInfo(A, pvPath)
    String iB = CsrInfo(B, pvPath)
    if (strlen(iA) == 0 || strlen(iB) == 0)
        return 0
    endif

    Variable xa = xcsr(A, pvPath)
    Variable xb = xcsr(B, pvPath)
    if (numtype(xa) != 0 || numtype(xb) != 0)
        return 0
    endif

    LJZ_EDCWB_SetROI(min(xa, xb), max(xa, xb))
    return 1
End


// ============================================================================
//  Section 8. Master refresh
// ============================================================================

Function LJZ_EDCWB_RefreshAll()
    LJZ_EDCWB_RebuildParList()
    LJZ_EDCWB_RefreshParEditor()
    LJZ_EDCWB_RefreshModelRoiControls()
    LJZ_EDCWB_RefreshPreviewGraph()
    LJZ_EDCWB_RefreshMetricBoxes()
    return 0
End

Function LJZ_EDCWB_RefreshAfterEdit()
    LJZ_EDCWB_RefreshAll()
    return 0
End


// ============================================================================
//  Section 9. Panel construction
// ============================================================================

Proc LJZ_EDCWB_OpenPanel()
    LJZ_EDCWB_EnsurePanelState()
    LJZ_EDCWB_BootstrapTargetDF()
    LJZ_EDCWB_RebuildWaveList()

    DoWindow/F $LJZ_EDCWB_PanelName()
    if (V_flag == 0)
        LJZ_EDCWB_Panel()
    endif
    LJZ_EDCWB_RefreshAll()
End

Function LJZ_EDCWB_BootstrapTargetDF()
    LJZ_EDCWB_EnsureBaseDF()
    SVAR target = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
    if (strlen(target) > 0)
        return 0
    endif

    // Preferred: EDCWB TargetDF (already bound to base:TargetDF above).
    SVAR/Z runDF = root:ARPES_LJZ:EDCExtract:RunDF
    if (SVAR_Exists(runDF) && strlen(runDF) > 0)
        target = runDF
        return 0
    endif

    SVAR/Z oldRunDF = root:ARPES_LJZ:EDCFit:RunDF
    if (SVAR_Exists(oldRunDF) && strlen(oldRunDF) > 0)
        target = oldRunDF
    endif
    return 0
End

Window LJZ_EDCWB_Panel() : Panel
    PauseUpdate; Silent 1
    NewPanel /W=(120,60,940,690) /N=EDCIFit_LJZ_Panel as "EDC Workbench"
    ModifyPanel frameStyle=1

    // ---- target DF ----
    TitleBox tbT, pos={12,8}, size={250,18}, title="Target DF (default: EDCExtract runDF)", frame=0
    SetVariable svTarget, pos={12,28}, size={500,20}, proc=LJZ_EDCWB_SetVarProc, title="DF:"
    SetVariable svTarget, value=_STR:""
    Button btnRebuild, pos={525,27}, size={95,22}, proc=LJZ_EDCWB_ButtonProc, title="Refresh"

    // ---- left wave list ----
    ListBox lbEDC, pos={12,58}, size={228,560}, proc=LJZ_EDCWB_LBProc
    ListBox lbEDC, listWave=$(LJZ_EDCWB_BaseDF() + ":UI_waveDisp")
    ListBox lbEDC, selWave=$(LJZ_EDCWB_BaseDF() + ":UI_waveSel"), mode=1

    Button btnPrev,           pos={245,58},  size={55,22}, proc=LJZ_EDCWB_ButtonProc, title="Prev"
    Button btnNext,           pos={302,58},  size={55,22}, proc=LJZ_EDCWB_ButtonProc, title="Next"
    Button btnNextUnchecked,  pos={362,58},  size={110,22}, proc=LJZ_EDCWB_ButtonProc, title="Next Unchecked"
    Button btnAccept,         pos={478,58},  size={62,22}, proc=LJZ_EDCWB_ButtonProc, title="Accept"
    Button btnReject,         pos={544,58},  size={62,22}, proc=LJZ_EDCWB_ButtonProc, title="Reject"
    Button btnClear,          pos={610,58},  size={62,22}, proc=LJZ_EDCWB_ButtonProc, title="Clear"
    Button btnExport,         pos={676,58},  size={62,22}, proc=LJZ_EDCWB_ButtonProc, title="Export"

    Button btnAutoInit,       pos={245,86}, size={68,22}, proc=LJZ_EDCWB_ButtonProc, title="AutoInit"
    Button btnSaveEdit,       pos={315,86}, size={75,22}, proc=LJZ_EDCWB_ButtonProc, title="SaveEdit"
    Button btnGuess,          pos={392,86}, size={60,22}, proc=LJZ_EDCWB_ButtonProc, title="Guess"
    Button btnFit,            pos={454,86}, size={60,22}, proc=LJZ_EDCWB_ButtonProc, title="Fit"
    CheckBox cbCsr,           pos={520,90}, size={70,16}, proc=LJZ_EDCWB_CheckProc, title="cursor ROI"
    CheckBox cbCsr,           value=1

    // ---- preview / residual subgraphs are created in code below ----
    TitleBox tbPV, pos={252,18}, size={70,16}, title="Preview", frame=0, fStyle=1

    // ---- model / ROI compact strip ----
    GroupBox gbModel, pos={245,314}, size={325,92}, title="Model / ROI / Physics"
    PopupMenu pmModel, pos={252,334}, size={190,20}, mode=1, value=#"LJZ_EDCWB_ModelPopupList()", proc=LJZ_EDCWB_PopupProc, title="Model"
    PopupMenu pmNorm,  pos={452,334}, size={110,20}, mode=1, value=#"\"None;Peak;Tail\"", proc=LJZ_EDCWB_PopupProc, title="Norm"

    SetVariable svXLo, pos={252,360}, size={85,18}, proc=LJZ_EDCWB_SetVarProc, title="xLo"
    SetVariable svXLo, value=_NUM:0
    SetVariable svXHi, pos={340,360}, size={85,18}, proc=LJZ_EDCWB_SetVarProc, title="xHi"
    SetVariable svXHi, value=_NUM:0

    SetVariable svT,   pos={430,360}, size={70,18}, proc=LJZ_EDCWB_SetVarProc, title="T"
    SetVariable svT, value=_NUM:10
    SetVariable svEF,  pos={502,360}, size={70,18}, proc=LJZ_EDCWB_SetVarProc, title="EF"
    SetVariable svEF, value=_NUM:0
    SetVariable svRes, pos={502,382}, size={70,18}, proc=LJZ_EDCWB_SetVarProc, title="res"
    SetVariable svRes, value=_NUM:0.01

    // ---- parameters ----
    TitleBox tbPars, pos={252,414}, size={80,16}, title="Parameters", frame=0, fStyle=1
    ListBox lbPar, pos={252,434}, size={320,124}, proc=LJZ_EDCWB_LBProc
    ListBox lbPar, listWave=$(LJZ_EDCWB_BaseDF() + ":UI_parDisp")
    ListBox lbPar, selWave=$(LJZ_EDCWB_BaseDF() + ":UI_parSel"), mode=1

    GroupBox gbParEd, pos={252,562}, size={320,58}, title="Selected parameter"
    TitleBox tbParName, pos={258,580}, size={180,16}, title="Selected parameter:", frame=0
    SetVariable svParValue, pos={258,600}, size={170,18}, proc=LJZ_EDCWB_SetVarProc, title="value"
    SetVariable svParValue, value=_NUM:NaN
    CheckBox cbParHold, pos={438,602}, size={60,16}, proc=LJZ_EDCWB_CheckProc, title="hold"

    // ---- right-side metrics + result ----
    TitleBox tbMetric, pos={585,18}, size={70,16}, title="Metrics", frame=0, fStyle=1
    GroupBox gbMetric, pos={585,36}, size={222,230}, title=""
    ListBox lbMetric, pos={593,46}, size={206,212}
    ListBox lbMetric, listWave=$(LJZ_EDCWB_BaseDF() + ":UI_metricDisp")
    ListBox lbMetric, selWave=$(LJZ_EDCWB_BaseDF() + ":UI_metricSel"), mode=1

    TitleBox tbRes, pos={585,270}, size={70,16}, title="Fit Result", frame=0, fStyle=1
    GroupBox gbRes, pos={585,288}, size={222,330}, title=""
    ListBox lbResL, pos={593,298}, size={102,314}
    ListBox lbResL, listWave=$(LJZ_EDCWB_BaseDF() + ":UI_resDispL")
    ListBox lbResL, selWave=$(LJZ_EDCWB_BaseDF() + ":UI_resSelL"), mode=1
    ListBox lbResR, pos={697,298}, size={102,314}
    ListBox lbResR, listWave=$(LJZ_EDCWB_BaseDF() + ":UI_resDispR")
    ListBox lbResR, selWave=$(LJZ_EDCWB_BaseDF() + ":UI_resSelR"), mode=1

    LJZ_EDCWB_CreatePreviewGraphs()
EndMacro


// ============================================================================
//  Section 10. Callback adapters
// ============================================================================

Function LJZ_EDCWB_LBProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if (lba.eventCode != 4)
        return 0
    endif
    if (lba.row < 0)
        return 0
    endif

    if (StringMatch(lba.ctrlName, LJZ_EDCWB_WaveListBoxName()))
        NVAR curRow = $(LJZ_EDCWB_BaseDF() + ":CurRow")
        if (lba.row == curRow)
            return 0
        endif
        if (!LJZ_EDCWB_ConfirmLeaveIfDirty())
            Wave sel = $(LJZ_EDCWB_BaseDF() + ":UI_waveSel")
            sel = 0
            if (curRow >= 0 && curRow < numpnts(sel))
                sel[curRow] = 1
            endif
            ListBox/Z lbEDC, win=$LJZ_EDCWB_PanelName(), selRow=curRow
            return 0
        endif
        LJZ_EDCWB_SelectWaveRow(lba.row)
        LJZ_EDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(lba.ctrlName, LJZ_EDCWB_ParListBoxName()))
        LJZ_EDCWB_SelectParRow(lba.row)
        LJZ_EDCWB_RefreshAll()
        return 0
    endif

    return 0
End

Function LJZ_EDCWB_PopupProc(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa

    if (pa.eventCode != 2)
        return 0
    endif

    if (StringMatch(pa.ctrlName, "pmModel"))
        Variable m = LJZ_EDCWB_ModelFromPopupMode(pa.popNum)
        LJZ_EDCWB_SetModel(m)
        LJZ_EDCWB_RefreshAfterEdit()
        return 0
    endif

    if (StringMatch(pa.ctrlName, "pmNorm"))
        LJZ_EDCWB_SetNormMode(pa.popNum - 1)
        LJZ_EDCWB_RefreshAfterEdit()
        return 0
    endif

    return 0
End

Function LJZ_EDCWB_SetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    if (sva.eventCode != 1 && sva.eventCode != 2 && sva.eventCode != 8)
        return 0
    endif

    String c = sva.ctrlName

    if (StringMatch(c, "svTarget"))
        if (!LJZ_EDCWB_ConfirmLeaveIfDirty())
            LJZ_EDCWB_RefreshModelRoiControls()
            return 0
        endif
        SVAR target = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
        target = sva.sval
        LJZ_EDCWB_RebuildWaveList()
        LJZ_EDCWB_RefreshAll()
        return 0
    endif

    if (numtype(sva.dval) != 0)
        return 0
    endif

    if (StringMatch(c, "svXLo"))
        Variable xLo, xHi
        LJZ_EDCWB_WorkGetROI(xLo, xHi)
        LJZ_EDCWB_SetROI(sva.dval, xHi)
        LJZ_EDCWB_RefreshAfterEdit()
        return 0
    endif
    if (StringMatch(c, "svXHi"))
        Variable xLo2, xHi2
        LJZ_EDCWB_WorkGetROI(xLo2, xHi2)
        LJZ_EDCWB_SetROI(xLo2, sva.dval)
        LJZ_EDCWB_RefreshAfterEdit()
        return 0
    endif

    if (StringMatch(c, "svT"))
        LJZ_EDCWB_SetT(sva.dval)
        LJZ_EDCWB_RefreshAfterEdit()
        return 0
    endif
    if (StringMatch(c, "svEF"))
        LJZ_EDCWB_SetEF(sva.dval)
        LJZ_EDCWB_RefreshAfterEdit()
        return 0
    endif
    if (StringMatch(c, "svRes"))
        LJZ_EDCWB_SetRes(sva.dval)
        LJZ_EDCWB_RefreshAfterEdit()
        return 0
    endif

    if (StringMatch(c, "svParValue"))
        NVAR selPar = $(LJZ_EDCWB_BaseDF() + ":UI_selectedPar")
        LJZ_EDCWB_SetPar(selPar, sva.dval)
        LJZ_EDCWB_RefreshAfterEdit()
        return 0
    endif

    return 0
End

Function LJZ_EDCWB_CheckProc(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba

    if (cba.eventCode != 2)
        return 0
    endif

    String c = cba.ctrlName
    Variable on = cba.checked

    if (StringMatch(c, "cbCsr"))
        NVAR useCsr = $(LJZ_EDCWB_BaseDF() + ":UseCursors")
        useCsr = on
        return 0
    endif

    if (StringMatch(c, "cbParHold"))
        NVAR selPar = $(LJZ_EDCWB_BaseDF() + ":UI_selectedPar")
        LJZ_EDCWB_SetHold(selPar, on)
        LJZ_EDCWB_RefreshAfterEdit()
        return 0
    endif

    return 0
End

Function LJZ_EDCWB_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif
    ba.blockReentry = 1

    String c = ba.ctrlName

    if (StringMatch(c, "btnRebuild"))
        if (!LJZ_EDCWB_ConfirmLeaveIfDirty())
            return 0
        endif
        LJZ_EDCWB_RebuildWaveList()
        LJZ_EDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnPrev") || StringMatch(c, "btnNext"))
        Wave/T pathW = $(LJZ_EDCWB_BaseDF() + ":UI_wavePath")
        NVAR curRow = $(LJZ_EDCWB_BaseDF() + ":CurRow")
        Variable step = StringMatch(c, "btnNext") ? 1 : -1
        Variable newRow = curRow + step
        newRow = max(0, min(numpnts(pathW) - 1, newRow))
        if (newRow == curRow)
            return 0
        endif
        if (!LJZ_EDCWB_ConfirmLeaveIfDirty())
            return 0
        endif
        LJZ_EDCWB_SelectWaveRow(newRow)
        LJZ_EDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnNextUnchecked"))
        NVAR curRow2 = $(LJZ_EDCWB_BaseDF() + ":CurRow")
        Variable nextRow = LJZ_EDCWB_FindNextUnchecked(curRow2)
        if (nextRow < 0)
            Beep
            DoAlert 0, "No unchecked EDC after current row."
            return 0
        endif
        if (!LJZ_EDCWB_ConfirmLeaveIfDirty())
            return 0
        endif
        LJZ_EDCWB_SelectWaveRow(nextRow)
        LJZ_EDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnAccept") || StringMatch(c, "btnReject") || StringMatch(c, "btnClear"))
        if (LJZ_EDCWB_IsDirty())
            Beep
            DoAlert 0, "Current fit is stale. Please run Fit again before changing the mark."
            return 0
        endif
        SVAR cp = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
        Wave/Z cw = $cp
        if (!WaveExists(cw))
            return 0
        endif
        Variable st = 0
        if (StringMatch(c, "btnAccept"))
            st = 1
        elseif (StringMatch(c, "btnReject"))
            st = -1
        endif
        LJZ_EDCWB_SetAccept(cw, st)
        LJZ_EDCWB_RebuildWaveList()
        LJZ_EDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnAutoInit"))
        SVAR cp2 = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
        Wave/Z cw2 = $cp2
        if (!WaveExists(cw2))
            return 0
        endif
        LJZ_EDCWB_AutoInitFromData(cw2)
        LJZ_EDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnSaveEdit"))
        SVAR cp4 = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
        Wave/Z cw4 = $cp4
        if (!WaveExists(cw4))
            return 0
        endif
        LJZ_EDCWB_SaveWorkToDisk(cw4)
        LJZ_EDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnGuess"))
        SVAR cp5 = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
        Wave/Z cw5 = $cp5
        if (!WaveExists(cw5))
            return 0
        endif
        LJZ_EDCWB_PullROIFromCursorsIfWanted()
        LJZ_EDCWB_BuildGuess(cw5)
        LJZ_EDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnFit"))
        SVAR cp6 = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
        Wave/Z cw6 = $cp6
        if (!WaveExists(cw6))
            return 0
        endif
        LJZ_EDCWB_PullROIFromCursorsIfWanted()
        Variable rc = LJZ_EDCWB_RunFit(cw6)
        if (rc != 0)
            String err = LJZ_EDCWB_GetLastError()
            if (strlen(err) <= 0)
                err = "Fit failed."
            endif
            Beep
            DoAlert 0, err
        endif
        LJZ_EDCWB_RebuildWaveList()
        LJZ_EDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnExport"))
        if (LJZ_EDCWB_IsDirty())
            DoAlert 1, "Preview is dirty. Export uses the last clean saved fit records, not the dirty preview. Continue?"
            if (V_flag != 1)
                return 0
            endif
        endif
        LJZ_EDCWB_ExportSummary()
        return 0
    endif

    return 0
End


// ============================================================================
//  Section 11. Export to FIT_EDC
// ============================================================================

Function LJZ_EDCWB_WriteConvenienceColumns(row, m, coefW, sigmaW)
    Variable row, m
    Wave coefW, sigmaW

    Wave wBG0 = $("BG_c0")
    Wave wBG1 = $("BG_c1")
    Wave wAmp = $("Amp")
    Wave wPeakX0 = $("PeakX0")
    Wave wPeakWidth = $("PeakWidth")
    Wave wEta = $("Eta")
    Wave wDelta = $("Delta")
    Wave wGamma = $("Gamma")
    Wave wTfit = $("T_fit")
    Wave wEFfit = $("EF_fit")
    Wave wResfit = $("Res_fit")
    Wave wX0Sym = $("X0_sym")
    Wave wSigPeakX0 = $("SigmaPeakX0")
    Wave wSigDelta = $("SigmaDelta")

    wBG0[row] = (0 < numpnts(coefW)) ? coefW[0] : NaN
    wBG1[row] = (1 < numpnts(coefW)) ? coefW[1] : NaN
    wAmp[row] = (2 < numpnts(coefW)) ? coefW[2] : NaN

    if (m == LJZ_EDCWB_Model_SinglePeakFD())
        wPeakX0[row]    = (3 < numpnts(coefW)) ? coefW[3] : NaN
        wPeakWidth[row] = (4 < numpnts(coefW)) ? coefW[4] : NaN
        wEta[row]       = (5 < numpnts(coefW)) ? coefW[5] : NaN
        wTfit[row]      = (6 < numpnts(coefW)) ? coefW[6] : NaN
        wEFfit[row]     = (7 < numpnts(coefW)) ? coefW[7] : NaN
        wResfit[row]    = (8 < numpnts(coefW)) ? coefW[8] : NaN
        wSigPeakX0[row] = (3 < numpnts(sigmaW)) ? sigmaW[3] : NaN
    elseif (m == LJZ_EDCWB_Model_EffectiveGap())
        wDelta[row]     = (3 < numpnts(coefW)) ? coefW[3] : NaN
        wGamma[row]     = (4 < numpnts(coefW)) ? coefW[4] : NaN
        wTfit[row]      = (5 < numpnts(coefW)) ? coefW[5] : NaN
        wEFfit[row]     = (6 < numpnts(coefW)) ? coefW[6] : NaN
        wResfit[row]    = (7 < numpnts(coefW)) ? coefW[7] : NaN
        wSigDelta[row]  = (3 < numpnts(sigmaW)) ? sigmaW[3] : NaN
    elseif (m == LJZ_EDCWB_Model_SymGap())
        wDelta[row]     = (3 < numpnts(coefW)) ? coefW[3] : NaN
        wGamma[row]     = (4 < numpnts(coefW)) ? coefW[4] : NaN
        wX0Sym[row]     = (5 < numpnts(coefW)) ? coefW[5] : NaN
        wSigDelta[row]  = (3 < numpnts(sigmaW)) ? sigmaW[3] : NaN
        wSigPeakX0[row] = (5 < numpnts(sigmaW)) ? sigmaW[5] : NaN
    endif

    return 0
End

Function LJZ_EDCWB_ExportSummary()
    LJZ_EDCWB_EnsurePanelState()

    SVAR target = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
    String df = LJZ_EDCWB_NormDFPath(target)
    if (strlen(df) == 0)
        DoAlert 0, "Target DF is invalid."
        return -1
    endif

    String lst = LJZ_EDCWB_ListEDCWaves(df)
    Variable n = ItemsInList(lst, ";")
    if (n <= 0)
        DoAlert 0, "No EDC waves found."
        return -1
    endif

    String oldDF = GetDataFolder(1)
    String exDF = RemoveEnding(df, ":") + ":FIT_EDC"
    NewDataFolder/O $exDF
    SetDataFolder $exDF

    Make/O/N=(n) EDCIndex = NaN
    Make/O/N=(n) ModelID = NaN, FitOK = NaN
    Make/O/T/N=(n) ModelName = ""
    Make/O/N=(n) XLo = NaN, XHi = NaN, GuessRMSE = NaN, FitRMSE = NaN, RSS_ROI = NaN, MaxAbsRes = NaN, N_ROI = NaN
    Make/O/N=(n) FitQuitReason = NaN, FitNumIters = NaN
    Make/O/N=(n) BG_c0 = NaN, BG_c1 = NaN, Amp = NaN
    Make/O/N=(n) PeakX0 = NaN, PeakWidth = NaN, Eta = NaN
    Make/O/N=(n) Delta = NaN, Gamma = NaN, T_fit = NaN, EF_fit = NaN, Res_fit = NaN, X0_sym = NaN
    Make/O/N=(n) SigmaPeakX0 = NaN, SigmaDelta = NaN

    Make/O/N=(n) Par0 = NaN, Par1 = NaN, Par2 = NaN, Par3 = NaN, Par4 = NaN, Par5 = NaN, Par6 = NaN, Par7 = NaN, Par8 = NaN
    Make/O/N=(n) Sigma0 = NaN, Sigma1 = NaN, Sigma2 = NaN, Sigma3 = NaN, Sigma4 = NaN, Sigma5 = NaN, Sigma6 = NaN, Sigma7 = NaN, Sigma8 = NaN

    Variable skipped = 0
    Variable i
    for (i = 0; i < n; i += 1)
        String full = StringFromList(i, lst, ";")
        Wave/Z w = $full
        if (!WaveExists(w))
            skipped += 1
            continue
        endif

        Variable edcIdx = LJZ_EDCWB_ParseEDCIndex(NameOfWave(w))
        if (edcIdx < 0)
            edcIdx = i
        endif
        EDCIndex[i] = edcIdx

        Duplicate/O w, $("layer_show_" + num2str(edcIdx))

        if (!LJZ_EDCWB_HasFitRecord(w))
            skipped += 1
            continue
        endif
        if (!LJZ_EDCWB_ReadFitOK(w))
            skipped += 1
            continue
        endif

        Wave/Z coefW  = $(LJZ_EDCWB_PathFitCoef(w))
        Wave/Z sigmaW = $(LJZ_EDCWB_PathFitSigma(w))
        Wave/Z infoW  = $(LJZ_EDCWB_PathFitInfo(w))
        Wave/Z fitW   = $(LJZ_EDCWB_PathFit(w))
        Wave/Z resW   = $(LJZ_EDCWB_PathRes(w))
        if (!WaveExists(coefW) || !WaveExists(sigmaW) || !WaveExists(infoW) || !WaveExists(fitW) || !WaveExists(resW))
            skipped += 1
            continue
        endif

        Variable m = round(infoW[LJZ_EDCWB_FI_ModelID()])
        ModelID[i] = m
        ModelName[i] = LJZ_EDCWB_ModelName(m)
        FitOK[i] = infoW[LJZ_EDCWB_FI_FitOK()]
        XLo[i] = infoW[LJZ_EDCWB_FI_XLo()]
        XHi[i] = infoW[LJZ_EDCWB_FI_XHi()]
        GuessRMSE[i] = infoW[LJZ_EDCWB_FI_GuessRMSE()]
        FitRMSE[i] = infoW[LJZ_EDCWB_FI_FitRMSE()]
        RSS_ROI[i] = infoW[LJZ_EDCWB_FI_RssROI()]
        MaxAbsRes[i] = infoW[LJZ_EDCWB_FI_MaxAbsRes()]
        N_ROI[i] = infoW[LJZ_EDCWB_FI_NROI()]
        FitQuitReason[i] = infoW[LJZ_EDCWB_FI_FitQuitReason()]
        FitNumIters[i] = infoW[LJZ_EDCWB_FI_FitNumIters()]

        Duplicate/O fitW, $("fit_layer_" + num2str(edcIdx))
        Duplicate/O resW, $("res_layer_" + num2str(edcIdx))

        Variable j, nv
        nv = min(numpnts(coefW), 9)
        for (j = 0; j < nv; j += 1)
            Wave targetPar = $("Par" + num2str(j))
            targetPar[i] = coefW[j]
        endfor
        nv = min(numpnts(sigmaW), 9)
        for (j = 0; j < nv; j += 1)
            Wave targetSig = $("Sigma" + num2str(j))
            targetSig[i] = sigmaW[j]
        endfor

        LJZ_EDCWB_WriteConvenienceColumns(i, m, coefW, sigmaW)
    endfor

    SetDataFolder $oldDF
    DoAlert 0, "FIT_EDC exported under: " + exDF + ":\rSkipped (no clean fit): " + num2str(skipped)
    return 0
End
