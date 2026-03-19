#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  LJZ_EDCWB Model
//  只负责：
//    1) model ids / names / popup list
//    2) parameter slot mapping
//    3) default values / default hold
//    4) layout update for EditPar / EditHold / EditParName / EditParEnable
//    5) sanitize / sync helpers
//
//  不负责：
//    - auto guess
//    - fit engine
//    - graph / panel callbacks
// ============================================================================


// ============================================================================
//  Section 0. model ids
// ============================================================================

Function LJZ_EDCWB_Model_None()
    return 0
End

Function LJZ_EDCWB_Model_SinglePeakFDConv()
    return 1
End

Function LJZ_EDCWB_Model_EffectiveGap()
    return 2
End

Function LJZ_EDCWB_Model_SymGap()
    return 3
End


// ============================================================================
//  Section 1. model meta
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
//  Section 2. param slot meaning
// ============================================================================
//
// EditPar[0..11] 永远是固定槽位。
// 不同 model 决定槽位含义。
// 未使用槽位：name="", enable=0
//
// Model 1: SinglePeak*FD*GaussConv
//   0 bg0
//   1 bg1
//   2 A
//   3 x0
//   4 w
//   5 eta
//   6 T
//   7 EF
//   8 res
//
// Model 2: EffectiveGap*FD*GaussConv
//   0 bg0
//   1 bg1
//   2 A
//   3 Delta
//   4 Gamma
//   5 T
//   6 EF
//   7 res
//
// Model 3: SymmetrizedGap
//   0 bg0
//   1 bg1
//   2 A
//   3 Delta
//   4 Gamma
//   5 x0
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
//  Section 3. param lookup helpers
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
//  Section 4. default hold policy
// ============================================================================
//
// hold == 1 -> 默认固定
// hold == 0 -> 默认自由
// ============================================================================

Function LJZ_EDCWB_ParamDefaultHold(modelID, idx)
    Variable modelID, idx

    if (!LJZ_EDCWB_ParamEnabled(modelID, idx))
        return 0
    endif

    if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
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
        return 0
    endif

    return 0
End


// ============================================================================
//  Section 5. default values
// ============================================================================

Function LJZ_EDCWB_ParamDefaultValue(modelID, idx)
    Variable modelID, idx

    if (!LJZ_EDCWB_ParamEnabled(modelID, idx))
        return NaN
    endif

    if (modelID == LJZ_EDCWB_Model_SinglePeakFDConv())
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
            return 0
        endif
        if (idx == 4)
            return 0.02
        endif
        if (idx == 5)
            return 0.5
        endif
        if (idx == 6)
            return 10
        endif
        if (idx == 7)
            return 0
        endif
        if (idx == 8)
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
        if (idx == 3)
            return 0.02
        endif
        if (idx == 4)
            return 0.01
        endif
        if (idx == 5)
            return 10
        endif
        if (idx == 6)
            return 0
        endif
        if (idx == 7)
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
//  Section 6. runtime wave layout updater
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


// ============================================================================
//  Section 7. model switch
// ============================================================================

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
//  Section 8. aux state sync
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

    LJZ_EDCWB_MarkDirty(1)
    return 0
End


// ============================================================================
//  Section 9. sanitation
// ============================================================================

Function LJZ_EDCWB_SanitizeParamWave(modelID, wPar)
    Variable modelID
    Wave wPar

    Variable i
    Variable idx

    // 未启用槽位统一清 NaN
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

    // w > 0
    idx = LJZ_EDCWB_ParamIndex(modelID, "w")
    if (idx >= 0 && numtype(wPar[idx]) == 0)
        if (wPar[idx] <= 0)
            wPar[idx] = 1e-4
        endif
    endif

    // Delta >= 0
    idx = LJZ_EDCWB_ParamIndex(modelID, "Delta")
    if (idx >= 0 && numtype(wPar[idx]) == 0)
        if (wPar[idx] < 0)
            wPar[idx] = abs(wPar[idx])
        endif
    endif

    // Gamma > 0
    idx = LJZ_EDCWB_ParamIndex(modelID, "Gamma")
    if (idx >= 0 && numtype(wPar[idx]) == 0)
        if (wPar[idx] <= 0)
            wPar[idx] = 1e-4
        endif
    endif

    // res > 0
    idx = LJZ_EDCWB_ParamIndex(modelID, "res")
    if (idx >= 0 && numtype(wPar[idx]) == 0)
        if (wPar[idx] <= 0)
            wPar[idx] = 1e-4
        endif
    endif

    // eta in [0,1]
    idx = LJZ_EDCWB_ParamIndex(modelID, "eta")
    if (idx >= 0 && numtype(wPar[idx]) == 0)
        if (wPar[idx] < 0)
            wPar[idx] = 0
        endif
        if (wPar[idx] > 1)
            wPar[idx] = 1
        endif
    endif

    // T >= 0
    idx = LJZ_EDCWB_ParamIndex(modelID, "T")
    if (idx >= 0 && numtype(wPar[idx]) == 0)
        if (wPar[idx] < 0)
            wPar[idx] = 0
        endif
    endif

    return 0
End
