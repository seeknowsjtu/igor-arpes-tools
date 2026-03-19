#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  LJZ_EDCWB Browser
//  只负责：
//    1) list TargetDF under EDCExtract run folders
//    2) rebuild listbox waves
//    3) current row selection
//    4) load current wave basic record
//
//  不负责：
//    - panel creation
//    - model bank
//    - preprocess / auto guess / fit engine
//    - graph drawing
// ============================================================================


// ============================================================================
//  Section 0. small helpers
// ============================================================================

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


// ============================================================================
//  Section 1. list EDC waves from TargetDF
// ============================================================================

Function/S LJZ_EDCWB_ListEDCWaves(dfPath)
    String dfPath

    dfPath = LJZ_EDCWB_NormDFPath(dfPath)
    if (strlen(dfPath) == 0)
        return ""
    endif

    String out = ""

    // 优先按 edc_show_0,1,2,... 的顺序列出
    Wave/Z w0 = $(dfPath + "edc_show_0")
    if (WaveExists(w0))
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
        while (1)

        return out
    endif

    // 回退：扫描所有 1D wave，名字中含 edc
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
        if (!StringMatch(LowerStr(nm), "*edc*"))
            continue
        endif

        out = AddListItem(dfPath + nm, out, ";", Inf)
    endfor

    return out
End

Function/S LJZ_EDCWB_CurrentListStr()
    SVAR sTarget = $(LJZ_EDCWB_BaseDF() + ":TargetDF")
    return LJZ_EDCWB_ListEDCWaves(sTarget)
End


// ============================================================================
//  Section 2. status text helpers
// ============================================================================

Function/S LJZ_EDCWB_StatusTagForWave(wPath)
    String wPath

    Variable acc = LJZ_EDCWB_ReadAcceptState(wPath)
    String reviewTag = " "

    if (acc > 0)
        reviewTag = "A"
    elseif (acc < 0)
        reviewTag = "R"
    endif

    String stageTag = "New"

    Wave/Z wInfo = $(LJZ_EDCWB_ResultFitInfoPath(wPath))
    Wave/Z wGuess = $(LJZ_EDCWB_ResultGuessPath(wPath))

    if (WaveExists(wInfo))
        if (numtype(wInfo[LJZ_EDCWB_FI_FitOK()]) == 0)
            if (wInfo[LJZ_EDCWB_FI_FitOK()] > 0)
                stageTag = "Fit"
            else
                stageTag = "Fail"
            endif
        elseif (numtype(wInfo[LJZ_EDCWB_FI_ModelID()]) == 0)
            stageTag = "Edit"
        endif
    endif

    if (CmpStr(stageTag, "New") == 0 && WaveExists(wGuess))
        WaveStats/Q wGuess
        if (V_numNaNs < numpnts(wGuess))
            stageTag = "Guess"
        endif
    endif

    return "[" + reviewTag + "|" + stageTag + "]"
End

Function/S LJZ_EDCWB_RowDisplayText(wPath)
    String wPath

    String nm = LJZ_EDCWB_WaveNameFromPath(wPath)
    return LJZ_EDCWB_StatusTagForWave(wPath) + " " + nm
End


// ============================================================================
//  Section 3. rebuild listbox waves
// ============================================================================

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
    Wave   wSel  = $(LJZ_EDCWB_BaseDF() + ":LB_Sel")

    Variable i
    String wPath
    for (i = 0; i < n; i += 1)
        wPath = StringFromList(i, listStr, ";")
        wDisp[i] = LJZ_EDCWB_RowDisplayText(wPath)
    endfor

    if (n <= 0)
        curRow = -1
        curPath = ""
        return 0
    endif

    Variable targetRow = WhichListItem(curPath, listStr, ";", 0, 0)
    if (targetRow < 0 && curRow >= 0 && curRow < n)
        targetRow = curRow
    endif
    if (targetRow < 0)
        targetRow = 0
    endif

    targetRow = LJZ_EDCWB_ClampIndex(targetRow, n)

    curRow = targetRow
    curPath = StringFromList(targetRow, listStr, ";")
    wSel[targetRow] = 1

    return 0
End


// ============================================================================
//  Section 4. selection control
// ============================================================================

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
//  Section 5. current wave loading
// ============================================================================

Function LJZ_EDCWB_LoadCurrentWave()
    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsurePanelState()

    SVAR curPath = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR curRow  = $(LJZ_EDCWB_BaseDF() + ":CurRow")

    if (strlen(curPath) == 0)
        return -1
    endif

    Wave/Z src = $curPath
    if (!WaveExists(src))
        return -1
    endif
    if (!LJZ_EDCWB_Is1DWave(src))
        return -1
    endif

    // 确保标准记录存在
    LJZ_EDCWB_EnsureResultRecord(curPath)

    // 同步 current wave state
    LJZ_EDCWB_SetCurrentWave(curPath, curRow)

    // 若已有记录，则载入；否则清空 edit state，等待后续 model/guess 模块接管
    if (LJZ_EDCWB_HasFitRecord(curPath))
        LJZ_EDCWB_LoadFitRecordToEditState(curPath)
        LJZ_EDCWB_MarkDirty(0)
    else
        LJZ_EDCWB_ClearEditState()
        LJZ_EDCWB_MarkDirty(0)
    endif

    // 再同步 listbox 选中状态，避免外部改 TargetDF 后错位
    String listStr = LJZ_EDCWB_CurrentListStr()
    Variable n = ItemsInList(listStr, ";")
    if (n > 0)
        Wave wSel = $(LJZ_EDCWB_BaseDF() + ":LB_Sel")
        if (numpnts(wSel) != n)
            Redimension/N=(n) wSel
        endif
        wSel = 0

        Variable targetRow = WhichListItem(curPath, listStr, ";", 0, 0)
        if (targetRow < 0)
            targetRow = LJZ_EDCWB_ClampIndex(curRow, n)
        endif
        wSel[targetRow] = 1

        NVAR nCurRow = $(LJZ_EDCWB_BaseDF() + ":CurRow")
        nCurRow = targetRow
    endif

    return 0
End
