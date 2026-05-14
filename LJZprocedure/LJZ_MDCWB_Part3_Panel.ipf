#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  LJZ_MDCWB Part 3 (Revised) : Panel + Callbacks + Display + Export
//
//  Depends on:
//    - LJZ_MDCWB Part 1 : Core data model + Persistence
//    - LJZ_MDCWB Part 2 : Model + Fit Engine
//    - LJZ_MDCWB Part 2 (append) : LJZ_MDCWB_AutoDetectPeaks,
//                                  LJZ_MDCWB_EvaluatePeakComponent
//
//  Visual goals:
//    - Single panel `MDCIFit_LJZ_Panel` (820 x 590), like the old version.
//    - Embedded `pvGraph` (preview) and `rsGraph` (residual) subwindows.
//    - Right-side Metrics + Fit Result list boxes.
//    - Peaks ListBox replaces the old fixed P0..P11 grid.
//    - Selected-peak editor below the peaks list.
//    - Compact BG / ROI / resH controls.
//    - Buttons: Refresh / Graph-Reset / SaveEdit / AutoInit /
//               Guess / Fit / Accept / Reject / Clear / Prev / Next /
//               Next Unchecked / Export.
//
//  Behavioral guarantees (DO NOT VIOLATE):
//    1) Switching the selected MDC checks Dirty and prompts before discarding.
//    2) Building a guess never silently writes the edit-state to disk.
//    3) ListBox callbacks act only on eventCode == 4.
//    4) Peak editor controls re-enable correctly when peak type changes.
//    5) Lor/Gau force eta both in UI and during fit assembly.
//    6) Manual SaveEdit and successful RunFit are the only routes that
//       persist the edit-state.
//
//  Storage paths (unchanged from old code):
//    Panel runtime DF      : root:Packages:ARPES_LJZ:MDCWB:
//    Per-wave persistents  : <wname>_peaks_num/_peaks_hold/_bg/_resH/_roi
//                            <wname>_fit/_res/_fitcoef/_fitsigma/_fitinfo
//                            <wname>_guess/_accept/_peaksMeta
//    Export folder         : <runDF>:FIT_HP
// ============================================================================


// ============================================================================
//  Section 0. Names, sizes, menu
// ============================================================================

Function/S LJZ_MDCWB_PanelName()
    return "MDCIFit_LJZ_Panel"
End

Function/S LJZ_MDCWB_PVGraphPath()
    return LJZ_MDCWB_PanelName() + "#pvGraph"
End

Function/S LJZ_MDCWB_RSGraphPath()
    return LJZ_MDCWB_PanelName() + "#rsGraph"
End

Function/S LJZ_MDCWB_WaveListBoxName()
    return "lbMDC"
End

Function/S LJZ_MDCWB_PeakListBoxName()
    return "lbPeaks"
End

Menu "ARPES_LJZ"
    "MDC Workbench", LJZ_MDCWB_OpenPanel()
End


// ============================================================================
//  Section 1. UI runtime state
// ============================================================================

Function LJZ_MDCWB_EnsurePanelState()
    LJZ_MDCWB_EnsureBaseDF()

    String base = LJZ_MDCWB_BaseDF()

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

    Wave/T/Z peakDisp = $(base + ":UI_peakDisp")
    if (!WaveExists(peakDisp))
        Make/O/T/N=1 $(base + ":UI_peakDisp") = ""
    endif
    Wave/Z peakSel = $(base + ":UI_peakSel")
    if (!WaveExists(peakSel))
        Make/O/N=1 $(base + ":UI_peakSel") = 0
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

    NVAR/Z carryFit = $(base + ":UI_carryFitToNext")
    if (!NVAR_Exists(carryFit))
        Variable/G $(base + ":UI_carryFitToNext") = 1
    endif

    return 0
End


// ============================================================================
//  Section 2. Small UI helpers
// ============================================================================

Function/S LJZ_MDCWB_StateMark(state)
    Variable state
    if (state > 0)
        return "✓ "
    elseif (state < 0)
        return "✗ "
    endif
    return "· "
End

Function/S LJZ_MDCWB_RowMark(state, isCurrent, isDirty)
    Variable state, isCurrent, isDirty
    String s = LJZ_MDCWB_StateMark(state)
    if (isCurrent && isDirty)
        return "~" + s
    endif
    return s
End

Function/S LJZ_MDCWB_FormatNum(v)
    Variable v
    if (numtype(v) != 0)
        return "NaN"
    endif
    return num2str(v)
End

Function/S LJZ_MDCWB_TrimTrailingCR(s)
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

Function LJZ_MDCWB_TextToListWave(textW, selW, src)
    Wave/T textW
    Wave selW
    String src

    src = LJZ_MDCWB_TrimTrailingCR(src)
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

Function LJZ_MDCWB_HasChild(host, child)
    String host, child
    String kids = ChildWindowList(host)
    return WhichListItem(child, kids, ";", 0, 0) >= 0
End

Function LJZ_MDCWB_ClearGraphTraces(winPath)
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

Function LJZ_MDCWB_ConfirmLeaveIfDirty()
    SVAR curPath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
    NVAR curRow  = $(LJZ_MDCWB_BaseDF() + ":CurRow")

    if (strlen(curPath) == 0 || curRow < 0)
        return 1
    endif
    if (!LJZ_MDCWB_IsDirty())
        return 1
    endif

    DoAlert 1, "Current MDC has unsaved/stale edits. Discard them and continue?"
    if (V_flag == 1)
        return 1
    endif
    return 0
End


// ============================================================================
//  Section 3. Wave list rebuild and selection
// ============================================================================

Function LJZ_MDCWB_RebuildWaveList()
    LJZ_MDCWB_EnsurePanelState()

    String base = LJZ_MDCWB_BaseDF()
    SVAR target  = $(base + ":TargetDF")
    SVAR curPath = $(base + ":CurWavePath")
    NVAR curRow  = $(base + ":CurRow")

    String oldPath = curPath
    Variable oldDirty = LJZ_MDCWB_IsDirty()

    String df = LJZ_MDCWB_NormDFPath(target)
    String lst = ""
    if (strlen(df) > 0)
        lst = LJZ_MDCWB_ListMDCWaves(df)
    endif

    Variable n = ItemsInList(lst, ";")
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
    if (ItemsInList(lst, ";") <= 0)
        disp[0] = "(no MDC waves)"
        pathW[0] = ""
        curRow = -1
        curPath = ""
        return 0
    endif

    Variable i
    Variable foundOld = -1
    for (i = 0; i < ItemsInList(lst, ";"); i += 1)
        String full = StringFromList(i, lst, ";")
        Wave/Z w = $full
        if (!WaveExists(w))
            disp[i] = "(missing)"
            pathW[i] = ""
            continue
        endif
        Variable st = LJZ_MDCWB_ReadAcceptState(w)
        Variable isCur = (cmpstr(full, oldPath) == 0)
        disp[i] = LJZ_MDCWB_RowMark(st, isCur, oldDirty) + NameOfWave(w)
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
        LJZ_MDCWB_MarkDirty(1)
    endif

    return 0
End

Function LJZ_MDCWB_SelectWaveRow(row)
    Variable row

    LJZ_MDCWB_EnsurePanelState()

    Wave/T pathW = $(LJZ_MDCWB_BaseDF() + ":UI_wavePath")
    Wave   sel  = $(LJZ_MDCWB_BaseDF() + ":UI_waveSel")

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

    NVAR curRow  = $(LJZ_MDCWB_BaseDF() + ":CurRow")
    SVAR curPath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")

    curRow = row
    curPath = full

    sel = 0
    sel[row] = 1
    ListBox/Z $LJZ_MDCWB_WaveListBoxName(), win=$LJZ_MDCWB_PanelName(), selRow=row

    Variable hadState = LJZ_MDCWB_HasEditState(w)
    Variable loadRC = LJZ_MDCWB_LoadCurrentToWork(w)
    if (loadRC != 0)
        return loadRC
    endif

    NVAR/Z carryOn = $(LJZ_MDCWB_BaseDF() + ":UI_carryFitToNext")
    if (NVAR_Exists(carryOn) && carryOn)
        if (!hadState)
            if (LJZ_MDCWB_ApplyCarryTemplateToWork() == 0)
                LJZ_MDCWB_ClearLastError()
            endif
        endif
    endif
    return 0
End

Function LJZ_MDCWB_SaveCarryTemplateFromWork()
    String base = LJZ_MDCWB_BaseDF()
    Duplicate/O $(base + ":Work_peaks_num"),  $(base + ":Carry_peaks_num")
    Duplicate/O $(base + ":Work_peaks_hold"), $(base + ":Carry_peaks_hold")
    Duplicate/O $(base + ":Work_bg"),         $(base + ":Carry_bg")
    Duplicate/O $(base + ":Work_resH"),       $(base + ":Carry_resH")
    Duplicate/O $(base + ":Work_roi"),        $(base + ":Carry_roi")
    return 0
End

Function LJZ_MDCWB_ApplyCarryTemplateToWork()
    String base = LJZ_MDCWB_BaseDF()
    Wave/Z cPN = $(base + ":Carry_peaks_num")
    Wave/Z cPH = $(base + ":Carry_peaks_hold")
    Wave/Z cBG = $(base + ":Carry_bg")
    Wave/Z cRH = $(base + ":Carry_resH")
    Wave/Z cROI = $(base + ":Carry_roi")
    if (!WaveExists(cPN) || !WaveExists(cPH) || !WaveExists(cBG) || !WaveExists(cRH) || !WaveExists(cROI))
        return -1
    endif

    Duplicate/O cPN,  $(base + ":Work_peaks_num")
    Duplicate/O cPH,  $(base + ":Work_peaks_hold")
    Duplicate/O cBG,  $(base + ":Work_bg")
    Duplicate/O cRH,  $(base + ":Work_resH")
    Duplicate/O cROI, $(base + ":Work_roi")
    LJZ_MDCWB_SanitizeWorkState()
    LJZ_MDCWB_MarkDirty(1)
    return 0
End

Function LJZ_MDCWB_FindNextUnchecked(startRow)
    Variable startRow

    Wave/T pathW = $(LJZ_MDCWB_BaseDF() + ":UI_wavePath")
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
        if (LJZ_MDCWB_ReadAcceptState(w) == 0)
            return i
        endif
    endfor
    return -1
End


// ============================================================================
//  Section 4. Peak list rebuild
// ============================================================================

Function LJZ_MDCWB_RebuildPeakList()
    LJZ_MDCWB_EnsurePanelState()

    String base = LJZ_MDCWB_BaseDF()
    Wave/T disp = $(base + ":UI_peakDisp")
    Wave   sel  = $(base + ":UI_peakSel")
    NVAR selPeak = $(base + ":Work_selectedPeak")

    Variable n = LJZ_MDCWB_WorkNumPeaks()
    Variable nDisp = max(1, n)
    Redimension/N=(nDisp) disp, sel
    sel = 0
    disp = ""

    if (n <= 0)
        disp[0] = "(no peaks)"
        return 0
    endif

    Wave wPN = $(base + ":Work_peaks_num")
    Wave wPH = $(base + ":Work_peaks_hold")

    Variable i
    String hold
    for (i = 0; i < n; i += 1)
        hold = ""
        if (wPH[i][0])
            hold += "x"
        endif
        if (wPH[i][1])
            hold += "w"
        endif
        if (wPH[i][2])
            hold += "r"
        endif
        if (wPH[i][3])
            hold += "H"
        endif
        if (wPH[i][4])
            hold += "e"
        endif
        if (strlen(hold) == 0)
            hold = "-"
        endif

        String row
        Variable t = round(wPN[i][0])
        sprintf row, "%d %-7s x0=%s w=%s", i, LJZ_MDCWB_PeakTypeName(t), LJZ_MDCWB_FormatNum(wPN[i][1]), LJZ_MDCWB_FormatNum(wPN[i][2])
        if (t == LJZ_MDCWB_PeakTypeAsymPV())
            row += " wR=" + LJZ_MDCWB_FormatNum(wPN[i][3])
        endif
        row += " H=" + LJZ_MDCWB_FormatNum(wPN[i][4])
        row += " eta=" + LJZ_MDCWB_FormatNum(wPN[i][5])
        row += " hold=" + hold
        disp[i] = row

        if (i == selPeak)
            sel[i] = 1
        endif
    endfor

    return 0
End


// ============================================================================
//  Section 5. Selected-peak editor
// ============================================================================

Function LJZ_MDCWB_RefreshPeakEditor()
    String panel = LJZ_MDCWB_PanelName()
    DoWindow $panel
    if (!V_flag)
        return 0
    endif

    LJZ_MDCWB_EnsureBaseDF()
    NVAR selPeak = $(LJZ_MDCWB_BaseDF() + ":Work_selectedPeak")
    Variable n = LJZ_MDCWB_WorkNumPeaks()
    Variable hasSel = (selPeak >= 0 && selPeak < n)

    // Always reset disable to (!hasSel) first, so previous specialization
    // does not stick when peak type changes back.
    SetVariable svPeakX0,  win=$panel, disable=(!hasSel)
    SetVariable svPeakW,   win=$panel, disable=(!hasSel)
    SetVariable svPeakWR,  win=$panel, disable=(!hasSel)
    SetVariable svPeakH,   win=$panel, disable=(!hasSel)
    SetVariable svPeakEta, win=$panel, disable=(!hasSel)
    PopupMenu pmPeakType,  win=$panel, disable=(!hasSel)
    CheckBox cbHoldX0,     win=$panel, disable=(!hasSel)
    CheckBox cbHoldW,      win=$panel, disable=(!hasSel)
    CheckBox cbHoldWR,     win=$panel, disable=(!hasSel)
    CheckBox cbHoldH,      win=$panel, disable=(!hasSel)
    CheckBox cbHoldEta,    win=$panel, disable=(!hasSel)

    if (!hasSel)
        SetVariable svPeakX0,  win=$panel, value=_NUM:NaN
        SetVariable svPeakW,   win=$panel, value=_NUM:NaN
        SetVariable svPeakWR,  win=$panel, value=_NUM:NaN
        SetVariable svPeakH,   win=$panel, value=_NUM:NaN
        SetVariable svPeakEta, win=$panel, value=_NUM:NaN
        return 0
    endif

    Wave wPN = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
    Wave wPH = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_hold")

    Variable t = round(wPN[selPeak][0])
    Variable mode = 1
    if (t == LJZ_MDCWB_PeakTypeLor())
        mode = 2
    elseif (t == LJZ_MDCWB_PeakTypeGau())
        mode = 3
    elseif (t == LJZ_MDCWB_PeakTypeAsymPV())
        mode = 4
    endif
    PopupMenu pmPeakType, win=$panel, mode=mode

    SetVariable svPeakX0,  win=$panel, value=_NUM:wPN[selPeak][1]
    SetVariable svPeakW,   win=$panel, value=_NUM:wPN[selPeak][2]
    SetVariable svPeakWR,  win=$panel, value=_NUM:wPN[selPeak][3]
    SetVariable svPeakH,   win=$panel, value=_NUM:wPN[selPeak][4]
    SetVariable svPeakEta, win=$panel, value=_NUM:wPN[selPeak][5]

    CheckBox cbHoldX0,  win=$panel, value=wPH[selPeak][0]
    CheckBox cbHoldW,   win=$panel, value=wPH[selPeak][1]
    CheckBox cbHoldWR,  win=$panel, value=wPH[selPeak][2]
    CheckBox cbHoldH,   win=$panel, value=wPH[selPeak][3]
    CheckBox cbHoldEta, win=$panel, value=wPH[selPeak][4]

    // Specializations: gray out controls that have no meaning for this type.
    if (t != LJZ_MDCWB_PeakTypeAsymPV())
        SetVariable svPeakWR, win=$panel, disable=2
        CheckBox cbHoldWR,    win=$panel, disable=2
    endif
    if (t == LJZ_MDCWB_PeakTypeLor() || t == LJZ_MDCWB_PeakTypeGau())
        SetVariable svPeakEta, win=$panel, disable=2
        CheckBox cbHoldEta,    win=$panel, disable=2
    endif

    return 0
End


// ============================================================================
//  Section 6. BG / ROI / resH controls refresh
// ============================================================================

Function LJZ_MDCWB_RefreshBGRoiResHControls()
    String panel = LJZ_MDCWB_PanelName()
    DoWindow $panel
    if (!V_flag)
        return 0
    endif

    LJZ_MDCWB_EnsureBaseDF()

    Variable bgOrder = LJZ_MDCWB_WorkGetBGOrder()
    PopupMenu pmBG, win=$panel, mode=(bgOrder + 1)

    Variable c0 = LJZ_MDCWB_WorkGetBGCoef(0)
    Variable c1 = LJZ_MDCWB_WorkGetBGCoef(1)
    Variable c2 = LJZ_MDCWB_WorkGetBGCoef(2)
    SetVariable svBG0, win=$panel, value=_NUM:c0
    SetVariable svBG1, win=$panel, value=_NUM:c1
    SetVariable svBG2, win=$panel, value=_NUM:c2

    CheckBox cbBGHold0, win=$panel, value=LJZ_MDCWB_WorkGetBGHold(0)
    CheckBox cbBGHold1, win=$panel, value=LJZ_MDCWB_WorkGetBGHold(1)
    CheckBox cbBGHold2, win=$panel, value=LJZ_MDCWB_WorkGetBGHold(2)

    // c1/c2 disabled when bgOrder makes them irrelevant.
    SetVariable svBG1, win=$panel, disable=(bgOrder < 1 ? 2 : 0)
    SetVariable svBG2, win=$panel, disable=(bgOrder < 2 ? 2 : 0)
    CheckBox cbBGHold1, win=$panel, disable=(bgOrder < 1 ? 2 : 0)
    CheckBox cbBGHold2, win=$panel, disable=(bgOrder < 2 ? 2 : 0)

    Variable xLo, xHi
    LJZ_MDCWB_WorkGetROI(xLo, xHi)
    SetVariable svXLo, win=$panel, value=_NUM:xLo
    SetVariable svXHi, win=$panel, value=_NUM:xHi

    SetVariable svResH, win=$panel, value=_NUM:LJZ_MDCWB_WorkGetResH()
    CheckBox cbResHHold, win=$panel, value=LJZ_MDCWB_WorkGetResHHold()

    NVAR useCsr = $(LJZ_MDCWB_BaseDF() + ":UseCursors")
    CheckBox cbCsr, win=$panel, value=useCsr

    SVAR target = $(LJZ_MDCWB_BaseDF() + ":TargetDF")
    SetVariable svTarget, win=$panel, value=_STR:target

    return 0
End


// ============================================================================
//  Section 7. Preview / residual graph
// ============================================================================

Function LJZ_MDCWB_CreatePreviewGraphs()
    String host = "MDCIFit_LJZ_Panel"

    String pvChild = "pvGraph"
    String rvChild = "rsGraph"

    String pvWin = host + "#" + pvChild
    String rvWin = host + "#" + rvChild

    // Check whether the subwindows already exist.
    String childList = ChildWindowList(host)

    if (WhichListItem(pvChild, childList, ";") < 0)
        Display /HOST=$host /N=pvGraph /W=(310,82,810,245)
    endif

    childList = ChildWindowList(host)

    if (WhichListItem(rvChild, childList, ";") < 0)
        Display /HOST=$host /N=rsGraph /W=(310,252,810,315)
    endif

    // Move them every time, but do not delete/recreate them.
    MoveSubwindow /W=$pvWin fnum=(310,82,810,245)
    MoveSubwindow /W=$rvWin fnum=(310,252,810,315)

    // --------------------------------------------------
    // Your original AppendToGraph code should go below.
    // Every AppendToGraph must explicitly specify /W.
    // --------------------------------------------------

    // Example:
    // AppendToGraph /W=$pvWin yRaw vs xWave
    // AppendToGraph /W=$pvWin yFit vs xWave
    // AppendToGraph /W=$rvWin yRes vs xWave

End



Function/S LJZ_MDCWB_PreviewGuessPath()
    return LJZ_MDCWB_BaseDF() + ":UI_guessPreview"
End

Function LJZ_MDCWB_BuildPreviewGuess(wData)
    Wave wData

    LJZ_MDCWB_EnsureBaseDF()

    if (LJZ_MDCWB_WorkNumPeaks() <= 0)
        KillWaves/Z $LJZ_MDCWB_PreviewGuessPath()
        return -1
    endif

    Make/FREE/N=1 fc, fh, sm
    String hm = ""
    LJZ_MDCWB_AssembleFitParams(fc, fh, sm, hm)
    LJZ_MDCWB_CopyActiveLayoutFromWork(sm)

    Duplicate/O wData, $LJZ_MDCWB_PreviewGuessPath()
    Wave gw = $LJZ_MDCWB_PreviewGuessPath()
    LJZ_MDCWB_EvaluateModelWave(wData, fc, gw)
    return 0
End

Function LJZ_MDCWB_RefreshPreviewGraph()
    String panel = LJZ_MDCWB_PanelName()
    DoWindow $panel
    if (!V_flag)
        return -1
    endif

    if (!LJZ_MDCWB_HasChild(panel, "pvGraph") || !LJZ_MDCWB_HasChild(panel, "rsGraph"))
        LJZ_MDCWB_CreatePreviewGraphs()
    endif

    String pvPath = LJZ_MDCWB_PVGraphPath()
    String rsPath = LJZ_MDCWB_RSGraphPath()

    SVAR curPath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
    if (strlen(curPath) == 0)
        LJZ_MDCWB_ClearGraphTraces(pvPath)
        LJZ_MDCWB_ClearGraphTraces(rsPath)
        TextBox/W=$pvPath/K/N=pvStatus
        return -1
    endif

    Wave/Z wData = $curPath
    if (!WaveExists(wData))
        LJZ_MDCWB_ClearGraphTraces(pvPath)
        LJZ_MDCWB_ClearGraphTraces(rsPath)
        TextBox/W=$pvPath/K/N=pvStatus
        return -1
    endif

    Variable previewOK = 0
    if (LJZ_MDCWB_WorkNumPeaks() > 0)
        if (LJZ_MDCWB_BuildPreviewGuess(wData) == 0)
            previewOK = 1
        endif
    endif
    if (!previewOK)
        KillWaves/Z $LJZ_MDCWB_PreviewGuessPath()
    endif

    Wave/Z guessW = $LJZ_MDCWB_PreviewGuessPath()
    Wave/Z fitW   = $LJZ_MDCWB_PathFit(wData)
    Wave/Z resW   = $LJZ_MDCWB_PathRes(wData)

    Variable dirty = LJZ_MDCWB_IsDirty()

    Variable xLo, xHi
    LJZ_MDCWB_WorkGetROI(xLo, xHi)
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
        showHi = showLo + dx * (numpnts(wData) - 1)
    endif

    // ---- main preview ----
    LJZ_MDCWB_ClearGraphTraces(pvPath)
    AppendToGraph/W=$pvPath wData/TN=rawData
    if (previewOK && WaveExists(guessW))
        AppendToGraph/W=$pvPath guessW/TN=guessData
    endif
    Variable hasCleanFit = 0
    if (LJZ_MDCWB_HasFitRecord(wData) && LJZ_MDCWB_ReadFitOK(wData))
        hasCleanFit = 1
    endif

    if (hasCleanFit && WaveExists(fitW))
        AppendToGraph/W=$pvPath fitW/TN=fitData
    endif

    ModifyGraph/W=$pvPath mode=0, lsize=1.5
    ModifyGraph/W=$pvPath rgb(rawData)=(0,0,0)
    if (previewOK && WaveExists(guessW))
        ModifyGraph/W=$pvPath rgb(guessData)=(0,0,65535), lstyle(guessData)=2
    endif
    if (hasCleanFit && WaveExists(fitW))
        ModifyGraph/W=$pvPath rgb(fitData)=(65535,0,0)
    endif

    SetAxis/W=$pvPath bottom showLo, showHi
    SetAxis/W=$pvPath/A=2 left

    if (!previewOK)
        TextBox/W=$pvPath/C/N=pvStatus/F=0/A=RT/X=-2/Y=2 "\\Z11Preview unavailable"
    elseif (dirty)
        TextBox/W=$pvPath/C/N=pvStatus/F=0/A=RT/X=-2/Y=2 "\\Z11Preview dirty"
    else
        TextBox/W=$pvPath/C/N=pvStatus/F=0/A=RT/X=-2/Y=2 "\\Z11Fit current"
    endif

    // ---- residual ----
    LJZ_MDCWB_ClearGraphTraces(rsPath)
    TextBox/W=$rsPath/K/N=rsStatus
    if (hasCleanFit && WaveExists(resW))
        AppendToGraph/W=$rsPath resW/TN=residualData
        ModifyGraph/W=$rsPath mode=0, lsize=1.2
        ModifyGraph/W=$rsPath rgb(residualData)=(30000,30000,30000)
    else
        TextBox/W=$rsPath/C/N=rsStatus/F=0/A=LT/X=2/Y=2 "\\Z10No clean residual"
    endif
    SetAxis/W=$rsPath bottom showLo, showHi
    if ((!dirty) && WaveExists(resW))
        SetAxis/W=$rsPath/A left
    else
        SetAxis/W=$rsPath left -1, 1
    endif

    return 0
End


// ============================================================================
//  Section 8. Metrics + Fit Result list boxes
// ============================================================================

Function LJZ_MDCWB_RefreshMetricBoxes()
    LJZ_MDCWB_EnsurePanelState()

    String base = LJZ_MDCWB_BaseDF()
    Wave/T mDisp = $(base + ":UI_metricDisp")
    Wave   mSel  = $(base + ":UI_metricSel")
    Wave/T rDispL = $(base + ":UI_resDispL")
    Wave   rSelL  = $(base + ":UI_resSelL")
    Wave/T rDispR = $(base + ":UI_resDispR")
    Wave   rSelR  = $(base + ":UI_resSelR")

    SVAR curPath = $(base + ":CurWavePath")
    if (strlen(curPath) == 0)
        LJZ_MDCWB_TextToListWave(mDisp, mSel, "No MDC selected.")
        LJZ_MDCWB_TextToListWave(rDispL, rSelL, "")
        LJZ_MDCWB_TextToListWave(rDispR, rSelR, "")
        return 0
    endif

    Wave/Z wData = $curPath
    if (!WaveExists(wData))
        LJZ_MDCWB_TextToListWave(mDisp, mSel, "Selected wave missing.")
        LJZ_MDCWB_TextToListWave(rDispL, rSelL, "")
        LJZ_MDCWB_TextToListWave(rDispR, rSelR, "")
        return 0
    endif

    Wave wPN = $(base + ":Work_peaks_num")
    Wave wPH = $(base + ":Work_peaks_hold")
    Wave/Z coefW  = $(LJZ_MDCWB_PathFitCoef(wData))
    Wave/Z sigmaW = $(LJZ_MDCWB_PathFitSigma(wData))
    Wave/Z infoW  = $(LJZ_MDCWB_PathFitInfo(wData))

    Variable xLo, xHi
    LJZ_MDCWB_WorkGetROI(xLo, xHi)
    Variable accept = LJZ_MDCWB_ReadAcceptState(wData)
    Variable dirty = LJZ_MDCWB_IsDirty()
    Variable nPeaks = LJZ_MDCWB_WorkNumPeaks()

    String mTxt = ""
    mTxt += "Wave: " + NameOfWave(wData) + "\r"
    mTxt += "Peaks: " + num2str(nPeaks) + "\r"
    mTxt += "BG: order=" + num2str(LJZ_MDCWB_WorkGetBGOrder()) + "\r"
    mTxt += "ROI: [" + LJZ_MDCWB_FormatNum(xLo) + ", " + LJZ_MDCWB_FormatNum(xHi) + "]\r"
    mTxt += "resH: " + LJZ_MDCWB_FormatNum(LJZ_MDCWB_WorkGetResH()) + "\r"
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
        if (WaveExists(infoW) && numpnts(infoW) >= 12)
            mTxt += "GuessRMSE: " + LJZ_MDCWB_FormatNum(infoW[5]) + "\r"
            mTxt += "FitRMSE: "   + LJZ_MDCWB_FormatNum(infoW[6]) + "\r"
            mTxt += "RSS(ROI): "  + LJZ_MDCWB_FormatNum(infoW[7]) + "\r"
            mTxt += "max|res|: "  + LJZ_MDCWB_FormatNum(infoW[8]) + "\r"
            mTxt += "N(ROI): "    + LJZ_MDCWB_FormatNum(infoW[9]) + "\r"
        else
            mTxt += "FitRMSE: --\r"
            mTxt += "RSS(ROI): --\r"
            mTxt += "max|res|: --\r"
            mTxt += "N(ROI): --\r"
        endif
    endif

    String err = LJZ_MDCWB_GetLastError()
    if (strlen(err) > 0)
        mTxt += "ERR: " + err + "\r"
    endif

    LJZ_MDCWB_TextToListWave(mDisp, mSel, mTxt)

    // ---- fit result panes (left = preview/current params; right = sigma) ----
    String lTxt = ""
    String rTxt = ""
    Variable hasCompleteFit = WaveExists(coefW) && WaveExists(sigmaW) && WaveExists(infoW)
    if (hasCompleteFit)
        hasCompleteFit = (numpnts(coefW) > 0 && numpnts(sigmaW) == numpnts(coefW) && numpnts(infoW) >= LJZ_MDCWB_FitInfoSize())
    endif

    if (dirty || !hasCompleteFit)
        lTxt = "Current preview\r"
        rTxt = "(no fitted sigma)\r"
        Variable i
        for (i = 0; i < nPeaks; i += 1)
            Variable t = round(wPN[i][0])
            String tn = LJZ_MDCWB_PeakTypeName(t)
            lTxt += "[" + num2str(i) + " " + tn + "]\r"
            lTxt += "  x0= " + LJZ_MDCWB_FormatNum(wPN[i][1]) + "\r"
            lTxt += "  w=  " + LJZ_MDCWB_FormatNum(wPN[i][2]) + "\r"
            if (t == LJZ_MDCWB_PeakTypeAsymPV())
                lTxt += "  wR= " + LJZ_MDCWB_FormatNum(wPN[i][3]) + "\r"
            endif
            lTxt += "  H=  " + LJZ_MDCWB_FormatNum(wPN[i][4]) + "\r"
            if (t != LJZ_MDCWB_PeakTypeLor() && t != LJZ_MDCWB_PeakTypeGau())
                lTxt += "  eta=" + LJZ_MDCWB_FormatNum(wPN[i][5]) + "\r"
            endif
        endfor
        lTxt += "[BG]\r"
        lTxt += "  c0= " + LJZ_MDCWB_FormatNum(LJZ_MDCWB_WorkGetBGCoef(0)) + "\r"
        Variable bo = LJZ_MDCWB_WorkGetBGOrder()
        if (bo >= 1)
            lTxt += "  c1= " + LJZ_MDCWB_FormatNum(LJZ_MDCWB_WorkGetBGCoef(1)) + "\r"
        endif
        if (bo >= 2)
            lTxt += "  c2= " + LJZ_MDCWB_FormatNum(LJZ_MDCWB_WorkGetBGCoef(2)) + "\r"
        endif
    else
        lTxt = "Fitted params\r"
        rTxt = "Sigma (1σ)\r"
        // Active_* is only a transient evaluator snapshot. For persisted fit
        // results, always re-derive layout from saved peaks_num.
        Make/FREE/N=(nPeaks) fitTypes
        Make/FREE/N=(nPeaks + 1) fitSlots
        if (LJZ_MDCWB_BuildLayoutFromPeaksNum(wPN, fitTypes, fitSlots) != 0)
            lTxt += "(layout invalid — re-fit needed)\r"
        else
            // BG / resH first
            lTxt += "[BG c0]= " + LJZ_MDCWB_FormatNum((0 < numpnts(coefW)) ? coefW[0] : NaN) + "\r"
            rTxt += "± " + LJZ_MDCWB_FormatNum((0 < numpnts(sigmaW)) ? sigmaW[0] : NaN) + "\r"
            if (LJZ_MDCWB_WorkGetBGOrder() >= 1)
                lTxt += "[BG c1]= " + LJZ_MDCWB_FormatNum((1 < numpnts(coefW)) ? coefW[1] : NaN) + "\r"
                rTxt += "± " + LJZ_MDCWB_FormatNum((1 < numpnts(sigmaW)) ? sigmaW[1] : NaN) + "\r"
            endif
            if (LJZ_MDCWB_WorkGetBGOrder() >= 2)
                lTxt += "[BG c2]= " + LJZ_MDCWB_FormatNum((2 < numpnts(coefW)) ? coefW[2] : NaN) + "\r"
                rTxt += "± " + LJZ_MDCWB_FormatNum((2 < numpnts(sigmaW)) ? sigmaW[2] : NaN) + "\r"
            endif
            lTxt += "[resH]= " + LJZ_MDCWB_FormatNum((3 < numpnts(coefW)) ? coefW[3] : NaN) + "\r"
            rTxt += "± " + LJZ_MDCWB_FormatNum((3 < numpnts(sigmaW)) ? sigmaW[3] : NaN) + "\r"

            Variable np = numpnts(fitTypes)
            Variable ip
            for (ip = 0; ip < np; ip += 1)
                Variable s = fitSlots[ip]
                Variable tt = fitTypes[ip]
                String tnFit = LJZ_MDCWB_PeakTypeName(tt)
                lTxt += "[" + num2str(ip) + " " + tnFit + "]\r"
                rTxt += "\r"
                lTxt += "  x0= " + LJZ_MDCWB_FormatNum((s + 0 < numpnts(coefW)) ? coefW[s + 0] : NaN) + "\r"
                rTxt += "± " + LJZ_MDCWB_FormatNum((s + 0 < numpnts(sigmaW)) ? sigmaW[s + 0] : NaN) + "\r"
                if (tt == LJZ_MDCWB_PeakTypeAsymPV())
                    lTxt += "  wL= " + LJZ_MDCWB_FormatNum((s + 1 < numpnts(coefW)) ? coefW[s + 1] : NaN) + "\r"
                    rTxt += "± " + LJZ_MDCWB_FormatNum((s + 1 < numpnts(sigmaW)) ? sigmaW[s + 1] : NaN) + "\r"
                    lTxt += "  wR= " + LJZ_MDCWB_FormatNum((s + 2 < numpnts(coefW)) ? coefW[s + 2] : NaN) + "\r"
                    rTxt += "± " + LJZ_MDCWB_FormatNum((s + 2 < numpnts(sigmaW)) ? sigmaW[s + 2] : NaN) + "\r"
                    lTxt += "  H=  " + LJZ_MDCWB_FormatNum((s + 3 < numpnts(coefW)) ? coefW[s + 3] : NaN) + "\r"
                    rTxt += "± " + LJZ_MDCWB_FormatNum((s + 3 < numpnts(sigmaW)) ? sigmaW[s + 3] : NaN) + "\r"
                    lTxt += "  eta=" + LJZ_MDCWB_FormatNum((s + 4 < numpnts(coefW)) ? coefW[s + 4] : NaN) + "\r"
                    rTxt += "± " + LJZ_MDCWB_FormatNum((s + 4 < numpnts(sigmaW)) ? sigmaW[s + 4] : NaN) + "\r"
                else
                    lTxt += "  w=  " + LJZ_MDCWB_FormatNum((s + 1 < numpnts(coefW)) ? coefW[s + 1] : NaN) + "\r"
                    rTxt += "± " + LJZ_MDCWB_FormatNum((s + 1 < numpnts(sigmaW)) ? sigmaW[s + 1] : NaN) + "\r"
                    lTxt += "  H=  " + LJZ_MDCWB_FormatNum((s + 2 < numpnts(coefW)) ? coefW[s + 2] : NaN) + "\r"
                    rTxt += "± " + LJZ_MDCWB_FormatNum((s + 2 < numpnts(sigmaW)) ? sigmaW[s + 2] : NaN) + "\r"
                    if (tt != LJZ_MDCWB_PeakTypeLor() && tt != LJZ_MDCWB_PeakTypeGau())
                        lTxt += "  eta=" + LJZ_MDCWB_FormatNum((s + 3 < numpnts(coefW)) ? coefW[s + 3] : NaN) + "\r"
                        rTxt += "± " + LJZ_MDCWB_FormatNum((s + 3 < numpnts(sigmaW)) ? sigmaW[s + 3] : NaN) + "\r"
                    endif
                endif
            endfor
        endif
    endif

    LJZ_MDCWB_TextToListWave(rDispL, rSelL, lTxt)
    LJZ_MDCWB_TextToListWave(rDispR, rSelR, rTxt)

    return 0
End


// ============================================================================
//  Section 9. Cursor → ROI helper
// ============================================================================

Function LJZ_MDCWB_PullROIFromCursorsIfWanted()
    LJZ_MDCWB_EnsureBaseDF()
    NVAR useCsr = $(LJZ_MDCWB_BaseDF() + ":UseCursors")
    if (!useCsr)
        return 0
    endif

    String pvPath = LJZ_MDCWB_PVGraphPath()
    DoWindow $LJZ_MDCWB_PanelName()
    if (!V_flag)
        return 0
    endif
    if (!LJZ_MDCWB_HasChild(LJZ_MDCWB_PanelName(), "pvGraph"))
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

    LJZ_MDCWB_SetROI(min(xa, xb), max(xa, xb))
    return 1
End


// ============================================================================
//  Section 10. Master refresh
// ============================================================================

Function LJZ_MDCWB_RefreshAll()
    LJZ_MDCWB_RebuildPeakList()
    LJZ_MDCWB_RefreshPeakEditor()
    LJZ_MDCWB_RefreshBGRoiResHControls()
    LJZ_MDCWB_RefreshPreviewGraph()
    LJZ_MDCWB_RefreshMetricBoxes()
    return 0
End

Function LJZ_MDCWB_RefreshAfterEdit()
    NVAR autoPreview = $(LJZ_MDCWB_BaseDF() + ":UI_autoPreview")
    SVAR curPath = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
    // Note: BuildGuess used to also save edit state; we deliberately do NOT
    // call LJZ_MDCWB_BuildGuess here. Preview is rebuilt internally by
    // LJZ_MDCWB_RefreshPreviewGraph from current Work_*.
    LJZ_MDCWB_RefreshAll()
    return 0
End


// ============================================================================
//  Section 11. Panel construction
// ============================================================================

Proc LJZ_MDCWB_OpenPanel()
    LJZ_MDCWB_EnsurePanelState()
    LJZ_MDCWB_BootstrapTargetDF()
    LJZ_MDCWB_RebuildWaveList()

    DoWindow/F $LJZ_MDCWB_PanelName()
    if (V_flag == 0)
        LJZ_MDCWB_Panel()
    endif
    LJZ_MDCWB_RefreshAll()
End

Function LJZ_MDCWB_BootstrapTargetDF()
    LJZ_MDCWB_EnsureBaseDF()
    SVAR target = $(LJZ_MDCWB_BaseDF() + ":TargetDF")
    if (strlen(target) > 0)
        return 0
    endif

    SVAR/Z runDF = root:ARPES_LJZ:MDCFit:RunDF
    if (SVAR_Exists(runDF) && strlen(runDF) > 0)
        target = runDF
    endif
    return 0
End

Window LJZ_MDCWB_Panel() : Panel
    PauseUpdate; Silent 1

    // Compact panel height. Old version was /W=(70,40,1180,760).
    NewPanel /W=(70,40,1240,715) /N=MDCIFit_LJZ_Panel as "MDC Workbench"
    ModifyPanel frameStyle=1

    // ---- target DF ----
    TitleBox tbT, pos={12,8}, size={260,18}, title="Target DF (default: ShowMDC runDF)", frame=0, fSize=12
    SetVariable svTarget, pos={12,28}, size={500,20}, proc=LJZ_MDCWB_SetVarProc, title="DF:", fSize=11
    SetVariable svTarget, value=_STR:""
    Button btnRebuild, pos={522,27}, size={80,22}, proc=LJZ_MDCWB_ButtonProc, title="Refresh", fSize=11

    // ---- top buttons ----
Button btnPrev,           pos={628,27},  size={48,22}, proc=LJZ_MDCWB_ButtonProc, title="Prev", fSize=11
Button btnNext,           pos={680,27},  size={48,22}, proc=LJZ_MDCWB_ButtonProc, title="Next", fSize=11
Button btnNextUnchecked,  pos={732,27},  size={92,22}, proc=LJZ_MDCWB_ButtonProc, title="Next Unchecked", fSize=11
Button btnAccept,         pos={830,27},  size={54,22}, proc=LJZ_MDCWB_ButtonProc, title="Accept", fSize=11
Button btnReject,         pos={888,27},  size={54,22}, proc=LJZ_MDCWB_ButtonProc, title="Reject", fSize=11
Button btnClear,          pos={946,27},  size={54,22}, proc=LJZ_MDCWB_ButtonProc, title="Clear", fSize=11
Button btnExport,         pos={1004,27}, size={54,22}, proc=LJZ_MDCWB_ButtonProc, title="Export", fSize=11
Button btnExportATKT,     pos={1064,27}, size={82,22}, proc=LJZ_MDCWB_ButtonProc, title="Exp->ATKT", fSize=10

Button btnAutoInit,       pos={628,55}, size={62,20}, proc=LJZ_MDCWB_ButtonProc, title="AutoInit", fSize=10
Button btnAutoDetect,     pos={696,55}, size={72,20}, proc=LJZ_MDCWB_ButtonProc, title="AutoDetect", fSize=10
Button btnSaveEdit,       pos={774,55}, size={68,20}, proc=LJZ_MDCWB_ButtonProc, title="SaveEdit", fSize=10
Button btnGuess,          pos={848,55}, size={58,20}, proc=LJZ_MDCWB_ButtonProc, title="Preview", fSize=10
Button btnFit,            pos={912,55}, size={50,20}, proc=LJZ_MDCWB_ButtonProc, title="Fit", fSize=10
CheckBox cbCsr,           pos={972,58}, size={82,16}, proc=LJZ_MDCWB_CheckProc, title="cursor ROI", fSize=10
CheckBox cbCsr,           value=1
CheckBox cbCarryFit,      pos={1060,58}, size={76,16}, proc=LJZ_MDCWB_CheckProc, title="Carry fit", fSize=10
CheckBox cbCarryFit,      variable=$(LJZ_MDCWB_BaseDF() + ":UI_carryFitToNext")

    // ---- left wave list ----
    ListBox lbMDC, pos={12,58}, size={280,590}, proc=LJZ_MDCWB_LBProc, fSize=11
    ListBox lbMDC, listWave=$(LJZ_MDCWB_BaseDF() + ":UI_waveDisp")
    ListBox lbMDC, selWave=$(LJZ_MDCWB_BaseDF() + ":UI_waveSel"), mode=1

    // ---- preview title ----
    TitleBox tbPV, pos={310,58}, size={70,16}, title="Preview", frame=0, fStyle=1, fSize=12

    // NOTE:
    // The actual PV/RV graph subwindow positions are controlled in
    // LJZ_MDCWB_CreatePreviewGraphs().
    // Suggested compact positions:
    // PV: /W=(310,82,810,245)
    // RV: /W=(310,252,810,315)

    // ---- BG / ROI / resH ----
    GroupBox gbBG, pos={310,324}, size={500,72}, title="Background / ROI / resH", fSize=11

    PopupMenu pmBG, pos={322,344}, size={92,18}, mode=3, popvalue="Quad", value=#"\"Const;Linear;Quad\"", proc=LJZ_MDCWB_PopupProc, title="BG", fSize=10

    SetVariable svXLo, pos={455,344}, size={96,18}, proc=LJZ_MDCWB_SetVarProc, title="xLo", fSize=10
    SetVariable svXLo, value=_NUM:0
    SetVariable svXHi, pos={560,344}, size={96,18}, proc=LJZ_MDCWB_SetVarProc, title="xHi", fSize=10
    SetVariable svXHi, value=_NUM:0
    SetVariable svResH, pos={665,344}, size={132,18}, proc=LJZ_MDCWB_SetVarProc, title="resH", fSize=10
    SetVariable svResH, value=_NUM:1e-4

    SetVariable svBG0, pos={322,368}, size={128,18}, proc=LJZ_MDCWB_SetVarProc, title="c0", fSize=10
    SetVariable svBG0, value=_NUM:0
    SetVariable svBG1, pos={470,368}, size={128,18}, proc=LJZ_MDCWB_SetVarProc, title="c1", fSize=10
    SetVariable svBG1, value=_NUM:0
    SetVariable svBG2, pos={618,368}, size={128,18}, proc=LJZ_MDCWB_SetVarProc, title="c2", fSize=10
    SetVariable svBG2, value=_NUM:0

    CheckBox cbBGHold0, pos={398,382}, size={22,14}, proc=LJZ_MDCWB_CheckProc, title="H", fSize=10
    CheckBox cbBGHold1, pos={546,382}, size={22,14}, proc=LJZ_MDCWB_CheckProc, title="H", fSize=10
    CheckBox cbBGHold2, pos={694,382}, size={22,14}, proc=LJZ_MDCWB_CheckProc, title="H", fSize=10
    CheckBox cbResHHold, pos={760,382}, size={46,14}, proc=LJZ_MDCWB_CheckProc, title="hold", fSize=10

    // ---- Peaks ----
    TitleBox tbPeaks, pos={310,404}, size={50,16}, title="Peaks", frame=0, fStyle=1, fSize=12

    ListBox lbPeaks, pos={310,424}, size={500,88}, proc=LJZ_MDCWB_LBProc, fSize=11
    ListBox lbPeaks, listWave=$(LJZ_MDCWB_BaseDF() + ":UI_peakDisp")
    ListBox lbPeaks, selWave=$(LJZ_MDCWB_BaseDF() + ":UI_peakSel"), mode=1

    PopupMenu pmDefaultPeakType, pos={310,520}, size={96,18}, mode=1, popvalue="PV", value=#"\"PV;Lor;Gau;AsymPV\"", proc=LJZ_MDCWB_PopupProc, title="New", fSize=10
    Button btnAddPeak, pos={430,518}, size={48,22}, proc=LJZ_MDCWB_ButtonProc, title="Add", fSize=10
    Button btnDelPeak, pos={484,518}, size={48,22}, proc=LJZ_MDCWB_ButtonProc, title="Del", fSize=10
    Button btnDupPeak, pos={538,518}, size={48,22}, proc=LJZ_MDCWB_ButtonProc, title="Dup", fSize=10

    // ---- selected peak editor ----
    GroupBox gbPeakEd, pos={310,548}, size={500,100}, title="Selected peak", fSize=11

    PopupMenu pmPeakType, pos={322,570}, size={68,18}, mode=1, popvalue="PV", value=#"\"PV;Lor;Gau;AsymPV\"", proc=LJZ_MDCWB_PopupProc, title="t", fSize=10

    SetVariable svPeakX0,  pos={408,570}, size={86,18}, proc=LJZ_MDCWB_SetVarProc, title="x0", fSize=10
    SetVariable svPeakX0, value=_NUM:NaN
    SetVariable svPeakW,   pos={508,570}, size={86,18}, proc=LJZ_MDCWB_SetVarProc, title="w", fSize=10
    SetVariable svPeakW, value=_NUM:NaN
    SetVariable svPeakWR,  pos={608,570}, size={86,18}, proc=LJZ_MDCWB_SetVarProc, title="wR", fSize=10
    SetVariable svPeakWR, value=_NUM:NaN

    SetVariable svPeakH,   pos={322,596}, size={86,18}, proc=LJZ_MDCWB_SetVarProc, title="H", fSize=10
    SetVariable svPeakH, value=_NUM:NaN
    SetVariable svPeakEta, pos={422,596}, size={86,18}, proc=LJZ_MDCWB_SetVarProc, title="eta", fSize=10
    SetVariable svPeakEta, value=_NUM:NaN

    CheckBox cbHoldX0,  pos={322,622}, size={22,14}, proc=LJZ_MDCWB_CheckProc, title="x", fSize=10
    CheckBox cbHoldW,   pos={360,622}, size={22,14}, proc=LJZ_MDCWB_CheckProc, title="w", fSize=10
    CheckBox cbHoldWR,  pos={400,622}, size={28,14}, proc=LJZ_MDCWB_CheckProc, title="wR", fSize=10
    CheckBox cbHoldH,   pos={446,622}, size={22,14}, proc=LJZ_MDCWB_CheckProc, title="H", fSize=10
    CheckBox cbHoldEta, pos={484,622}, size={34,14}, proc=LJZ_MDCWB_CheckProc, title="eta", fSize=10

    // ---- right-side metrics + result ----
    TitleBox tbMetric, pos={825,90}, size={70,16}, title="Metrics", frame=0, fStyle=1, fSize=12

    GroupBox gbMetric, pos={825,110}, size={270,240}, title=""
    ListBox lbMetric, pos={835,122}, size={250,216}, fSize=11
    ListBox lbMetric, listWave=$(LJZ_MDCWB_BaseDF() + ":UI_metricDisp")
    ListBox lbMetric, selWave=$(LJZ_MDCWB_BaseDF() + ":UI_metricSel"), mode=1

    TitleBox tbRes, pos={825,364}, size={80,16}, title="Fit Result", frame=0, fStyle=1, fSize=12

    GroupBox gbRes, pos={825,384}, size={270,264}, title=""
    ListBox lbResL, pos={835,396}, size={118,240}, fSize=11
    ListBox lbResL, listWave=$(LJZ_MDCWB_BaseDF() + ":UI_resDispL")
    ListBox lbResL, selWave=$(LJZ_MDCWB_BaseDF() + ":UI_resSelL"), mode=1

    ListBox lbResR, pos={963,396}, size={122,240}, fSize=11
    ListBox lbResR, listWave=$(LJZ_MDCWB_BaseDF() + ":UI_resDispR")
    ListBox lbResR, selWave=$(LJZ_MDCWB_BaseDF() + ":UI_resSelR"), mode=1

    LJZ_MDCWB_CreatePreviewGraphs()
EndMacro


// ============================================================================
//  Section 12. Callback adapters
// ============================================================================

Function LJZ_MDCWB_LBProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if (lba.eventCode != 4)
        return 0
    endif
    if (lba.row < 0)
        return 0
    endif

    if (StringMatch(lba.ctrlName, LJZ_MDCWB_WaveListBoxName()))
        NVAR curRow = $(LJZ_MDCWB_BaseDF() + ":CurRow")
        if (lba.row == curRow)
            return 0
        endif
        if (!LJZ_MDCWB_ConfirmLeaveIfDirty())
            // Restore old highlight
            Wave sel = $(LJZ_MDCWB_BaseDF() + ":UI_waveSel")
            sel = 0
            if (curRow >= 0 && curRow < numpnts(sel))
                sel[curRow] = 1
            endif
            ListBox/Z lbMDC, win=$LJZ_MDCWB_PanelName(), selRow=curRow
            return 0
        endif
        LJZ_MDCWB_SelectWaveRow(lba.row)
        LJZ_MDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(lba.ctrlName, LJZ_MDCWB_PeakListBoxName()))
        LJZ_MDCWB_SelectPeak(lba.row)
        LJZ_MDCWB_RefreshAll()
        return 0
    endif

    return 0
End

Function LJZ_MDCWB_PopupProc(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa

    if (pa.eventCode != 2)
        return 0
    endif

    if (StringMatch(pa.ctrlName, "pmDefaultPeakType"))
        NVAR defType = $(LJZ_MDCWB_BaseDF() + ":DefaultPeakType")
        defType = LJZ_MDCWB_PeakTypeFromPopup(pa.popNum)
        return 0
    endif

    if (StringMatch(pa.ctrlName, "pmPeakType"))
        NVAR selPeak = $(LJZ_MDCWB_BaseDF() + ":Work_selectedPeak")
        Variable t = LJZ_MDCWB_PeakTypeFromPopup(pa.popNum)
        LJZ_MDCWB_SetPeakType(selPeak, t)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif

    if (StringMatch(pa.ctrlName, "pmBG"))
        LJZ_MDCWB_SetBGOrder(pa.popNum - 1)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif

    return 0
End

Function LJZ_MDCWB_PeakTypeFromPopup(popNum)
    Variable popNum
    if (popNum == 2)
        return LJZ_MDCWB_PeakTypeLor()
    elseif (popNum == 3)
        return LJZ_MDCWB_PeakTypeGau()
    elseif (popNum == 4)
        return LJZ_MDCWB_PeakTypeAsymPV()
    endif
    return LJZ_MDCWB_PeakTypePV()
End

Function LJZ_MDCWB_SetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    // Only react on commit/end-edit events (mouse-up = 1, enter = 2, end-edit = 8). Live typing (3) is ignored.
    if (sva.eventCode != 1 && sva.eventCode != 2 && sva.eventCode != 8)
        return 0
    endif

    String c = sva.ctrlName

    if (StringMatch(c, "svTarget"))
        if (!LJZ_MDCWB_ConfirmLeaveIfDirty())
            LJZ_MDCWB_RefreshBGRoiResHControls()
            return 0
        endif
        SVAR target = $(LJZ_MDCWB_BaseDF() + ":TargetDF")
        target = sva.sval
        LJZ_MDCWB_RebuildWaveList()
        LJZ_MDCWB_RefreshAll()
        return 0
    endif

    if (numtype(sva.dval) != 0)
        return 0
    endif

    if (StringMatch(c, "svXLo"))
        Variable xLo, xHi
        LJZ_MDCWB_WorkGetROI(xLo, xHi)
        LJZ_MDCWB_SetROI(sva.dval, xHi)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif
    if (StringMatch(c, "svXHi"))
        Variable xLo2, xHi2
        LJZ_MDCWB_WorkGetROI(xLo2, xHi2)
        LJZ_MDCWB_SetROI(xLo2, sva.dval)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif

    if (StringMatch(c, "svBG0"))
        LJZ_MDCWB_SetBGCoef(0, sva.dval)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif
    if (StringMatch(c, "svBG1"))
        LJZ_MDCWB_SetBGCoef(1, sva.dval)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif
    if (StringMatch(c, "svBG2"))
        LJZ_MDCWB_SetBGCoef(2, sva.dval)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif

    if (StringMatch(c, "svResH"))
        LJZ_MDCWB_SetResH(sva.dval)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif

    NVAR selPeak = $(LJZ_MDCWB_BaseDF() + ":Work_selectedPeak")
    if (StringMatch(c, "svPeakX0"))
        LJZ_MDCWB_SetPeakField(selPeak, LJZ_MDCWB_FieldX0(), sva.dval)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif
    if (StringMatch(c, "svPeakW"))
        LJZ_MDCWB_SetPeakField(selPeak, LJZ_MDCWB_FieldW(), sva.dval)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif
    if (StringMatch(c, "svPeakWR"))
        LJZ_MDCWB_SetPeakField(selPeak, LJZ_MDCWB_FieldWR(), sva.dval)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif
    if (StringMatch(c, "svPeakH"))
        LJZ_MDCWB_SetPeakField(selPeak, LJZ_MDCWB_FieldH(), sva.dval)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif
    if (StringMatch(c, "svPeakEta"))
        LJZ_MDCWB_SetPeakField(selPeak, LJZ_MDCWB_FieldEta(), sva.dval)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif

    return 0
End

Function LJZ_MDCWB_CheckProc(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba

    if (cba.eventCode != 2)
        return 0
    endif

    String c = cba.ctrlName
    Variable on = cba.checked

    if (StringMatch(c, "cbCsr"))
        NVAR useCsr = $(LJZ_MDCWB_BaseDF() + ":UseCursors")
        useCsr = on
        return 0
    endif
    if (StringMatch(c, "cbCarryFit"))
        NVAR carryOn = $(LJZ_MDCWB_BaseDF() + ":UI_carryFitToNext")
        carryOn = on
        return 0
    endif

    if (StringMatch(c, "cbBGHold0"))
        LJZ_MDCWB_SetBGHold(0, on)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif
    if (StringMatch(c, "cbBGHold1"))
        LJZ_MDCWB_SetBGHold(1, on)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif
    if (StringMatch(c, "cbBGHold2"))
        LJZ_MDCWB_SetBGHold(2, on)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif
    if (StringMatch(c, "cbResHHold"))
        LJZ_MDCWB_SetResHHold(on)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif

    NVAR selPeak = $(LJZ_MDCWB_BaseDF() + ":Work_selectedPeak")
    if (StringMatch(c, "cbHoldX0"))
        LJZ_MDCWB_SetPeakHold(selPeak, LJZ_MDCWB_HoldFieldX0(), on)
    elseif (StringMatch(c, "cbHoldW"))
        LJZ_MDCWB_SetPeakHold(selPeak, LJZ_MDCWB_HoldFieldW(), on)
    elseif (StringMatch(c, "cbHoldWR"))
        LJZ_MDCWB_SetPeakHold(selPeak, LJZ_MDCWB_HoldFieldWR(), on)
    elseif (StringMatch(c, "cbHoldH"))
        LJZ_MDCWB_SetPeakHold(selPeak, LJZ_MDCWB_HoldFieldH(), on)
    elseif (StringMatch(c, "cbHoldEta"))
        LJZ_MDCWB_SetPeakHold(selPeak, LJZ_MDCWB_HoldFieldEta(), on)
    else
        return 0
    endif

    LJZ_MDCWB_RefreshAfterEdit()
    return 0
End

Function LJZ_MDCWB_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif
    ba.blockReentry = 1

    String c = ba.ctrlName

    if (StringMatch(c, "btnRebuild"))
        if (!LJZ_MDCWB_ConfirmLeaveIfDirty())
            return 0
        endif
        LJZ_MDCWB_RebuildWaveList()
        LJZ_MDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnPrev") || StringMatch(c, "btnNext"))
        Wave/T pathW = $(LJZ_MDCWB_BaseDF() + ":UI_wavePath")
        NVAR curRow = $(LJZ_MDCWB_BaseDF() + ":CurRow")
        Variable step = StringMatch(c, "btnNext") ? 1 : -1
        Variable newRow = curRow + step
        newRow = max(0, min(numpnts(pathW) - 1, newRow))
        if (newRow == curRow)
            return 0
        endif
        if (!LJZ_MDCWB_ConfirmLeaveIfDirty())
            return 0
        endif
        LJZ_MDCWB_SelectWaveRow(newRow)
        LJZ_MDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnNextUnchecked"))
        NVAR curRow2 = $(LJZ_MDCWB_BaseDF() + ":CurRow")
        Variable nextRow = LJZ_MDCWB_FindNextUnchecked(curRow2)
        if (nextRow < 0)
            Beep
            DoAlert 0, "No unchecked MDC after current row."
            return 0
        endif
        if (!LJZ_MDCWB_ConfirmLeaveIfDirty())
            return 0
        endif
        LJZ_MDCWB_SelectWaveRow(nextRow)
        LJZ_MDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnAccept") || StringMatch(c, "btnReject") || StringMatch(c, "btnClear"))
        if (LJZ_MDCWB_IsDirty())
            Beep
            DoAlert 0, "Current fit is stale. Please run Fit again before changing the mark."
            return 0
        endif
        SVAR cp = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
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
        LJZ_MDCWB_SetAccept(cw, st)
        LJZ_MDCWB_RebuildWaveList()
        LJZ_MDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnAutoInit"))
        SVAR cp2 = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
        Wave/Z cw2 = $cp2
        if (!WaveExists(cw2))
            return 0
        endif
        if (LJZ_MDCWB_AutoInitFromData(cw2) == 0)
            LJZ_MDCWB_SetLastError("AutoInit: one peak initialized from ROI.")
        endif
        LJZ_MDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnAutoDetect"))
        SVAR cp3 = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
        Wave/Z cw3 = $cp3
        if (!WaveExists(cw3))
            return 0
        endif
        LJZ_MDCWB_PullROIFromCursorsIfWanted()
        if (LJZ_MDCWB_AutoDetectPeaks(cw3, 4) == 0)
            String adMsg
            sprintf adMsg, "AutoDetect: %d peaks initialized from ROI.", LJZ_MDCWB_WorkNumPeaks()
            LJZ_MDCWB_SetLastError(adMsg)
        endif
        LJZ_MDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnSaveEdit"))
        SVAR cp4 = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
        Wave/Z cw4 = $cp4
        if (!WaveExists(cw4))
            return 0
        endif
        LJZ_MDCWB_SaveWorkToDisk(cw4)
        LJZ_MDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnGuess"))
        SVAR cp5 = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
        Wave/Z cw5 = $cp5
        if (!WaveExists(cw5))
            return 0
        endif
        LJZ_MDCWB_PullROIFromCursorsIfWanted()
        LJZ_MDCWB_SanitizeWorkState()
        LJZ_MDCWB_MarkDirty(1)
        LJZ_MDCWB_RefreshPreviewGraph()
        LJZ_MDCWB_SetLastError("Preview rebuilt from current Work parameters.")
        LJZ_MDCWB_RefreshMetricBoxes()
        return 0
    endif

    if (StringMatch(c, "btnFit"))
        SVAR cp6 = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
        Wave/Z cw6 = $cp6
        if (!WaveExists(cw6))
            return 0
        endif
        LJZ_MDCWB_PullROIFromCursorsIfWanted()
        Variable rc = LJZ_MDCWB_RunFit(cw6)
        if (rc == 0)
            LJZ_MDCWB_SaveCarryTemplateFromWork()
        endif
        if (rc != 0)
            String err = LJZ_MDCWB_GetLastError()
            if (strlen(err) <= 0)
                err = "Fit failed."
            endif
            Beep
            DoAlert 0, err
        endif
        LJZ_MDCWB_RebuildWaveList()
        LJZ_MDCWB_RefreshAll()
        return 0
    endif

    if (StringMatch(c, "btnAddPeak"))
        SVAR cp7 = $(LJZ_MDCWB_BaseDF() + ":CurWavePath")
        Wave/Z cw7 = $cp7
        if (!WaveExists(cw7))
            return 0
        endif
        LJZ_MDCWB_ActionAddPeak(cw7)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif

    if (StringMatch(c, "btnDelPeak"))
        NVAR sp = $(LJZ_MDCWB_BaseDF() + ":Work_selectedPeak")
        LJZ_MDCWB_DeletePeak(sp)
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif

    if (StringMatch(c, "btnDupPeak"))
        LJZ_MDCWB_ActionDuplicatePeak()
        LJZ_MDCWB_RefreshAfterEdit()
        return 0
    endif

    if (StringMatch(c, "btnExport"))
        if (LJZ_MDCWB_IsDirty())
            DoAlert 1, "Preview is dirty. Export uses the last clean saved fit records, not the dirty preview. Continue?"
            if (V_flag != 1)
                return 0
            endif
        endif
        LJZ_MDCWB_ExportSummary()
        return 0
    endif

    if (StringMatch(c, "btnExportATKT"))
        if (LJZ_MDCWB_IsDirty())
            DoAlert 1, "Preview is dirty. Export uses the last clean saved fit records, not the dirty preview. Continue?"
            if (V_flag != 1)
                return 0
            endif
        endif
        Variable exRc = LJZ_MDCWB_ExportSummary()
        if (exRc == 0)
            LJZ_MDCWB_NotifyATKT()
        endif
        return 0
    endif

    return 0
End


// ============================================================================
//  Section 13. AddPeak / Duplicate seeding helpers
// ============================================================================

Function LJZ_MDCWB_ActionAddPeak(wData)
    Wave wData

    LJZ_MDCWB_EnsureBaseDF()
    NVAR defType = $(LJZ_MDCWB_BaseDF() + ":DefaultPeakType")

    Variable xLo, xHi
    LJZ_MDCWB_WorkGetROI(xLo, xHi)
    Variable lo, hi
    LJZ_MDCWB_GetROIIndexRange(wData, xLo, xHi, lo, hi)

    Variable cx, H
    if (hi >= lo)
        Make/FREE/N=(hi - lo + 1) seg = wData[lo + p]
        SetScale/P x, DimOffset(wData, 0) + lo * DimDelta(wData, 0), DimDelta(wData, 0), seg
        WaveStats/Q/M=1 seg
        cx = (numtype(V_maxLoc) == 0) ? V_maxLoc : (DimOffset(wData, 0) + 0.5 * DimDelta(wData, 0) * (numpnts(wData) - 1))
        H  = (numtype(V_max) == 0 && numtype(V_min) == 0) ? max(1e-6, V_max - V_min) : 1
    else
        cx = DimOffset(wData, 0) + 0.5 * DimDelta(wData, 0) * (numpnts(wData) - 1)
        H  = 1
    endif

    Variable wWidth = LJZ_MDCWB_DefaultPeakWidthFromData(wData)
    LJZ_MDCWB_AddPeak(defType, cx, wWidth, H)
    return 0
End

Function LJZ_MDCWB_NotifyATKT()
    LJZ_MDCWB_EnsurePanelState()

    SVAR target = $(LJZ_MDCWB_BaseDF() + ":TargetDF")
    String df = LJZ_MDCWB_NormDFPath(target)
    if (strlen(df) == 0)
        DoAlert 0, "NotifyATKT: Target DF is invalid."
        return -1
    endif
    String fitHP = RemoveEnding(df, ":") + ":FIT_HP:"

    if (!DataFolderExists(fitHP))
        DoAlert 0, "FIT_HP folder was not found. Please run Export first."
        return -1
    endif

    Wave/Z wPeak = $(fitHP + "Long_PeakAngle")
    if (!WaveExists(wPeak))
        DoAlert 0, "FIT_HP is missing Long_PeakAngle. Please rerun Export."
        return -1
    endif

    a2k1d_ensure_folder()
    SVAR a2kBase = root:ARPES_LJZ:A2K1D:a2k1d_baseDF
    a2kBase = fitHP
    a2k1d_rebuild_lb()

    Print "LJZ MDCWB Export->ATKT: FIT_HP ready at " + fitHP
    Print "LJZ MDCWB Export->ATKT: ATKT list refreshed via a2k1d_rebuild_lb()"
    DoAlert 0, "Export done. ATKT baseDF -> FIT_HP. Set parameters and click Table Peak->K."
    return 0
End

Function LJZ_MDCWB_ActionDuplicatePeak()
    LJZ_MDCWB_EnsureBaseDF()
    NVAR sp = $(LJZ_MDCWB_BaseDF() + ":Work_selectedPeak")
    Variable n = LJZ_MDCWB_WorkNumPeaks()
    if (sp < 0 || sp >= n)
        return -1
    endif

    Wave wPN = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_num")
    Wave wPH = $(LJZ_MDCWB_BaseDF() + ":Work_peaks_hold")

    Variable t  = wPN[sp][0]
    Variable x0 = wPN[sp][1]
    Variable w  = wPN[sp][2]
    Variable H  = wPN[sp][4]

    Variable idx = LJZ_MDCWB_AddPeak(t, x0 + w, w, H)
    if (idx >= 0)
        wPN[idx][3] = wPN[sp][3]
        wPN[idx][5] = wPN[sp][5]
        wPN[idx][6] = wPN[sp][6]
        Variable ih
        for (ih = 0; ih < LJZ_MDCWB_PeaksHoldCols(); ih += 1)
            wPH[idx][ih] = wPH[sp][ih]
        endfor
        LJZ_MDCWB_SanitizeWorkState()
        sp = idx
    endif
    return idx
End


// ============================================================================
//  Section 14. Export to FIT_HP
//
//  Output:
//    Same targetDF subfolder: FIT_HP
//
//  Compatibility summary:
//      MDCIndex
//      Peak1K, Peak2K, Peak3K
//      WeffP1K, WeffP2K, WeffP3K
//      AreaP1K, AreaP2K, AreaP3K, AreaSum123K
//      SigmaP1K, SigmaP2K, SigmaP3K
//      Sep12K, Sep13K, Sep23K
//      BG_c0, BG_c1, BG_c2
//      layer_show_<k>
//      fit_layer_<k>
//
//  New all-peak export:
//      NPeaksK
//      AreaSumAllK
//
//      PeakK_All[row][rank]
//      WeffP_All[row][rank]
//      AreaP_All[row][rank]
//      SigmaAngle_All[row][rank]
//      SigmaK_All[row][rank]
//      H_All[row][rank]
//      Eta_All[row][rank]
//      WidthL_All[row][rank]
//      WidthR_All[row][rank]
//      Type_All[row][rank]
//      SourcePeakIndex_All[row][rank]
//
//  New long-table export:
//      Long_MDCRow
//      Long_MDCIndex
//      Long_PeakRank
//      Long_SourcePeakIndex
//      Long_PeakAngle
//      Long_PeakK
//      Long_Weff
//      Long_Area
//      Long_SigmaAngle
//      Long_SigmaK
//      Long_H
//      Long_Eta
//      Long_WidthL
//      Long_WidthR
//      Long_Type
//      Long_WaveName
//      Long_PeakTypeName
//
//  Meaning:
//      rank means peak order after sorting by fitted x0.
//      SourcePeakIndex means the original peak index before sorting.
// ============================================================================

Function LJZ_MDCWB_ExportSummary()
    LJZ_MDCWB_EnsurePanelState()

    SVAR target = $(LJZ_MDCWB_BaseDF() + ":TargetDF")
    String df = LJZ_MDCWB_NormDFPath(target)
    if (strlen(df) == 0)
        DoAlert 0, "Target DF is invalid."
        return -1
    endif

    String lst = LJZ_MDCWB_ListMDCWaves(df)
    Variable n = ItemsInList(lst, ";")
    if (n <= 0)
        DoAlert 0, "No MDC waves found."
        return -1
    endif

    // ------------------------------------------------------------------------
    // First pass: find maximum number of peaks and total long-table rows.
    // ------------------------------------------------------------------------
    Variable maxPeaks = 0
    Variable totalPeakRows = 0

    Variable i
    for (i = 0; i < n; i += 1)
        String full0 = StringFromList(i, lst, ";")
        Wave/Z w0 = $full0
        if (!WaveExists(w0))
            continue
        endif
        if (!LJZ_MDCWB_HasFitRecord(w0))
            continue
        endif
        if (!LJZ_MDCWB_ReadFitOK(w0))
            continue
        endif

        Wave/Z pn0 = $(LJZ_MDCWB_PathPeaksNum(w0))
        if (!WaveExists(pn0))
            continue
        endif

        Variable np0 = DimSize(pn0, 0)
        if (np0 <= 0)
            continue
        endif

        maxPeaks = max(maxPeaks, np0)
        totalPeakRows += np0
    endfor

    Variable nPeakCols = max(1, maxPeaks)
    Variable nLongRows = max(1, totalPeakRows)

    String oldDF = GetDataFolder(1)
    String exDF = RemoveEnding(df, ":") + ":FIT_HP"
    NewDataFolder/O $exDF
    SetDataFolder $exDF

    // ------------------------------------------------------------------------
    // Compatibility waves: old 3-peak style.
    // ------------------------------------------------------------------------
    Make/O/N=(n) MDCIndex = NaN
    Make/O/N=(n) NPeaksK = NaN

    Make/O/N=(n) Peak1K = NaN, Peak2K = NaN, Peak3K = NaN
    Make/O/N=(n) WeffP1K = NaN, WeffP2K = NaN, WeffP3K = NaN
    Make/O/N=(n) AreaP1K = NaN, AreaP2K = NaN, AreaP3K = NaN
    Make/O/N=(n) AreaSum123K = NaN, AreaSumAllK = NaN
    Make/O/N=(n) SigmaP1K = NaN, SigmaP2K = NaN, SigmaP3K = NaN
    Make/O/N=(n) Sep12K = NaN, Sep13K = NaN, Sep23K = NaN
    Make/O/N=(n) BG_c0 = NaN, BG_c1 = NaN, BG_c2 = NaN

    // ------------------------------------------------------------------------
    // New wide all-peak waves.
    // Rows correspond to MDC waves. Columns correspond to sorted peak rank.
    // ------------------------------------------------------------------------
    Make/O/N=(n, nPeakCols) PeakAngle_All = NaN
    Make/O/N=(n, nPeakCols) PeakK_All = NaN
    Make/O/N=(n, nPeakCols) SigmaAngle_All = NaN
    Make/O/N=(n, nPeakCols) SigmaK_All = NaN
    Make/O/N=(n, nPeakCols) WeffP_All = NaN
    Make/O/N=(n, nPeakCols) AreaP_All = NaN
    Make/O/N=(n, nPeakCols) H_All = NaN
    Make/O/N=(n, nPeakCols) Eta_All = NaN
    Make/O/N=(n, nPeakCols) WidthL_All = NaN
    Make/O/N=(n, nPeakCols) WidthR_All = NaN
    Make/O/N=(n, nPeakCols) Type_All = NaN
    Make/O/N=(n, nPeakCols) SourcePeakIndex_All = NaN
    Make/O/T/N=(n, nPeakCols) PeakTypeName_All = ""

    // ------------------------------------------------------------------------
    // New long table.
    // One row = one fitted peak.
    // This is the safest format for more than 3 peaks.
    // ------------------------------------------------------------------------
    Make/O/N=(nLongRows) Long_MDCRow = NaN
    Make/O/N=(nLongRows) Long_MDCIndex = NaN
    Make/O/N=(nLongRows) Long_PeakRank = NaN
    Make/O/N=(nLongRows) Long_SourcePeakIndex = NaN
    Make/O/N=(nLongRows) Long_PeakAngle = NaN
    Make/O/N=(nLongRows) Long_PeakK = NaN
    Make/O/N=(nLongRows) Long_SigmaAngle = NaN
    Make/O/N=(nLongRows) Long_SigmaK = NaN
    Make/O/N=(nLongRows) Long_Weff = NaN
    Make/O/N=(nLongRows) Long_Area = NaN
    Make/O/N=(nLongRows) Long_H = NaN
    Make/O/N=(nLongRows) Long_Eta = NaN
    Make/O/N=(nLongRows) Long_WidthL = NaN
    Make/O/N=(nLongRows) Long_WidthR = NaN
    Make/O/N=(nLongRows) Long_Type = NaN
    Make/O/T/N=(nLongRows) Long_WaveName = ""
    Make/O/T/N=(nLongRows) Long_PeakTypeName = ""

    Note/K Long_PeakAngle, "source=LJZ_MDCWB_ExportSummary;meaning=raw fitted angle values (x0)"
    Note/K Long_PeakK, "source=LJZ_MDCWB_ExportSummary;meaning=ATKT output placeholders (converted k), initially NaN"
    Note/K Long_SigmaAngle, "source=LJZ_MDCWB_ExportSummary;meaning=raw fitted x uncertainty (sigma in angle/raw units)"
    Note/K Long_SigmaK, "source=LJZ_MDCWB_ExportSummary;meaning=ATKT propagated uncertainty placeholders (sigma_k), initially NaN"
    Note/K PeakAngle_All, "source=LJZ_MDCWB_ExportSummary;meaning=raw fitted angle values (x0)"
    Note/K PeakK_All, "source=LJZ_MDCWB_ExportSummary;meaning=ATKT output placeholders (converted k), initially NaN"
    Note/K SigmaAngle_All, "source=LJZ_MDCWB_ExportSummary;meaning=raw fitted x uncertainty (sigma in angle/raw units)"
    Note/K SigmaK_All, "source=LJZ_MDCWB_ExportSummary;meaning=ATKT propagated uncertainty placeholders (sigma_k), initially NaN"

    Variable skipped = 0
    Variable longRow = 0

    for (i = 0; i < n; i += 1)
        String full = StringFromList(i, lst, ";")
        Wave/Z w = $full
        if (!WaveExists(w))
            skipped += 1
            continue
        endif

        Variable kIdx = LJZ_MDCWB_ParseMDCIndex(NameOfWave(w))
        if (kIdx < 0)
            kIdx = i
        endif
        MDCIndex[i] = kIdx

        Duplicate/O w, $("layer_show_" + num2str(kIdx))

        if (!LJZ_MDCWB_HasFitRecord(w))
            skipped += 1
            continue
        endif
        if (!LJZ_MDCWB_ReadFitOK(w))
            skipped += 1
            continue
        endif

        Wave/Z pn = $(LJZ_MDCWB_PathPeaksNum(w))
        if (!WaveExists(pn))
            skipped += 1
            continue
        endif

        Variable np = DimSize(pn, 0)
        if (np <= 0)
            skipped += 1
            continue
        endif

        Make/FREE/N=(np) tLocal
        Make/FREE/N=(np + 1) sm
        if (LJZ_MDCWB_BuildLayoutFromPeaksNum(pn, tLocal, sm) != 0)
            skipped += 1
            continue
        endif

        Wave/Z coefW  = $(LJZ_MDCWB_PathFitCoef(w))
        Wave/Z sigmaW = $(LJZ_MDCWB_PathFitSigma(w))
        Wave/Z infoW  = $(LJZ_MDCWB_PathFitInfo(w))
        Wave/Z fitW   = $(LJZ_MDCWB_PathFit(w))

        if (!WaveExists(coefW) || !WaveExists(sigmaW) || !WaveExists(infoW) || !WaveExists(fitW))
            skipped += 1
            continue
        endif

        Variable nCoef = numpnts(coefW)
        Variable nSigma = numpnts(sigmaW)
        if (nCoef < sm[np])
            skipped += 1
            continue
        endif

        Duplicate/O fitW, $("fit_layer_" + num2str(kIdx))

        BG_c0[i] = coefW[0]
        BG_c1[i] = coefW[1]
        BG_c2[i] = coefW[2]

        Variable resH = abs(coefW[3])
        NPeaksK[i] = np

        Make/FREE/N=(np) cx, cwid, carea, csigX
        Make/FREE/N=(np) cH, cEta, cwL, cwR, cType

        Variable ip
        for (ip = 0; ip < np; ip += 1)
            Variable t = tLocal[ip]
            Variable s = sm[ip]

            cType[ip] = t
            cx[ip] = (s + 0 < nCoef) ? coefW[s + 0] : NaN
            csigX[ip] = (s + 0 < nSigma) ? sigmaW[s + 0] : NaN

            Variable wid, ar
            Variable hVal, etaVal, wLeft, wRight

            if (t == LJZ_MDCWB_PeakTypeAsymPV())
                Variable wL = abs((s + 1 < nCoef) ? coefW[s + 1] : NaN)
                Variable wR = abs((s + 2 < nCoef) ? coefW[s + 2] : NaN)
                Variable HA = (s + 3 < nCoef) ? coefW[s + 3] : NaN
                Variable etaA = (s + 4 < nCoef) ? coefW[s + 4] : NaN

                Variable wEff = sqrt(0.5 * (wL*wL + wR*wR) + resH*resH)
                Variable lor = pi * abs(HA) * wEff
                Variable gau = sqrt(pi / ln(2)) * abs(HA) * wEff

                wid = wEff
                ar = etaA * lor + (1 - etaA) * gau

                hVal = HA
                etaVal = etaA
                wLeft = wL
                wRight = wR
            else
			Variable wBase = abs((s + 1 < nCoef) ? coefW[s + 1] : NaN)
			Variable HP = (s + 2 < nCoef) ? coefW[s + 2] : NaN
			Variable etaP = (s + 3 < nCoef) ? coefW[s + 3] : NaN

			if (t == LJZ_MDCWB_PeakTypeLor())
    				etaP = 1
			elseif (t == LJZ_MDCWB_PeakTypeGau())
    				etaP = 0
			endif

			Variable wEffP = sqrt(wBase*wBase + resH*resH)
			Variable lorP = pi * abs(HP) * wEffP
			Variable gauP = sqrt(pi / ln(2)) * abs(HP) * wEffP

			wid = wEffP
			ar = etaP * lorP + (1 - etaP) * gauP

			hVal = HP
			etaVal = etaP
			wLeft = wBase
			wRight = wBase
            endif

            cwid[ip] = wid
            carea[ip] = ar
            cH[ip] = hVal
            cEta[ip] = etaVal
            cwL[ip] = wLeft
            cwR[ip] = wRight
        endfor

        // Sort peaks by x ascending.
        Make/FREE/N=(np) ord = p
        Sort cx, ord, cx

        Variable areaAll = 0
        Variable hasArea = 0

        Variable j
        for (j = 0; j < np; j += 1)
            Variable srcIdx = ord[j]
            Variable rank = j + 1
            Variable xSorted = cx[j]

            PeakAngle_All[i][j] = xSorted
            PeakK_All[i][j] = NaN
            WeffP_All[i][j] = cwid[srcIdx]
            AreaP_All[i][j] = carea[srcIdx]
            SigmaAngle_All[i][j] = csigX[srcIdx]
            SigmaK_All[i][j] = NaN
            H_All[i][j] = cH[srcIdx]
            Eta_All[i][j] = cEta[srcIdx]
            WidthL_All[i][j] = cwL[srcIdx]
            WidthR_All[i][j] = cwR[srcIdx]
            Type_All[i][j] = cType[srcIdx]
            SourcePeakIndex_All[i][j] = srcIdx
            PeakTypeName_All[i][j] = LJZ_MDCWB_PeakTypeName(cType[srcIdx])

            if (numtype(carea[srcIdx]) == 0)
                areaAll += carea[srcIdx]
                hasArea = 1
            endif

            // Keep old first-three export for backward compatibility.
            if (j == 0)
                Peak1K[i] = xSorted
                WeffP1K[i] = cwid[srcIdx]
                AreaP1K[i] = carea[srcIdx]
                SigmaP1K[i] = csigX[srcIdx]
            elseif (j == 1)
                Peak2K[i] = xSorted
                WeffP2K[i] = cwid[srcIdx]
                AreaP2K[i] = carea[srcIdx]
                SigmaP2K[i] = csigX[srcIdx]
            elseif (j == 2)
                Peak3K[i] = xSorted
                WeffP3K[i] = cwid[srcIdx]
                AreaP3K[i] = carea[srcIdx]
                SigmaP3K[i] = csigX[srcIdx]
            endif

            // Long-table export.
            if (longRow < nLongRows)
                Long_MDCRow[longRow] = i
                Long_MDCIndex[longRow] = kIdx
                Long_PeakRank[longRow] = rank
                Long_SourcePeakIndex[longRow] = srcIdx
                Long_PeakAngle[longRow] = xSorted
                Long_PeakK[longRow] = NaN
                Long_Weff[longRow] = cwid[srcIdx]
                Long_Area[longRow] = carea[srcIdx]
                Long_SigmaAngle[longRow] = csigX[srcIdx]
                Long_SigmaK[longRow] = NaN
                Long_H[longRow] = cH[srcIdx]
                Long_Eta[longRow] = cEta[srcIdx]
                Long_WidthL[longRow] = cwL[srcIdx]
                Long_WidthR[longRow] = cwR[srcIdx]
                Long_Type[longRow] = cType[srcIdx]
                Long_WaveName[longRow] = NameOfWave(w)
                Long_PeakTypeName[longRow] = LJZ_MDCWB_PeakTypeName(cType[srcIdx])
                longRow += 1
            endif
        endfor

        AreaSumAllK[i] = hasArea ? areaAll : NaN

        Variable s12 = NaN, s13 = NaN, s23 = NaN
        if (np >= 2)
            s12 = abs(cx[1] - cx[0])
        endif
        if (np >= 3)
            s13 = abs(cx[2] - cx[0])
            s23 = abs(cx[2] - cx[1])
        endif
        Sep12K[i] = s12
        Sep13K[i] = s13
        Sep23K[i] = s23

        Variable a1 = AreaP1K[i], a2 = AreaP2K[i], a3 = AreaP3K[i]
        Variable asum123 = 0
        Variable any123 = 0

        if (numtype(a1) == 0)
            asum123 += a1
            any123 = 1
        endif
        if (numtype(a2) == 0)
            asum123 += a2
            any123 = 1
        endif
        if (numtype(a3) == 0)
            asum123 += a3
            any123 = 1
        endif

        AreaSum123K[i] = any123 ? asum123 : NaN
    endfor

    SetDataFolder $oldDF

    DoAlert 0, "FIT_HP exported under: " + exDF + ":\rSkipped (no clean fit): " + num2str(skipped) + "\rMax peaks exported: " + num2str(maxPeaks) + "\rLong-table rows: " + num2str(totalPeakRows)

    return 0
End
