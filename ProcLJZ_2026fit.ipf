#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  MDC Interactive Fit Workbench v2.1 (Part 1)
//  Runtime state: root:Packages:ARPES_LJZ:MDCIFit
//  Results: saved into the SAME datafolder as the selected MDC wave
// ============================================================================
Menu "ARPES_LJZ"
    "MDC Interactive Fit Workbench", MDCIFit_LJZ()
End

// -------------------------
// Package state initializer
// -------------------------
Function LJZ_EnsureMDCIFitDF()
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:ARPES_LJZ
    NewDataFolder/O root:Packages:ARPES_LJZ:MDCIFit

    SVAR/Z sTarget = root:Packages:ARPES_LJZ:MDCIFit:TargetDF
    if (!SVAR_Exists(sTarget))
        String/G root:Packages:ARPES_LJZ:MDCIFit:TargetDF = ""
    endif

    Wave/T/Z wDisp = root:Packages:ARPES_LJZ:MDCIFit:LB_Disp
    if (!WaveExists(wDisp))
        Make/O/T/N=1 root:Packages:ARPES_LJZ:MDCIFit:LB_Disp = "(empty)"
    endif

    Wave/T/Z wPath = root:Packages:ARPES_LJZ:MDCIFit:LB_Path
    if (!WaveExists(wPath))
        Make/O/T/N=1 root:Packages:ARPES_LJZ:MDCIFit:LB_Path = ""
    endif

    Wave/Z wSel = root:Packages:ARPES_LJZ:MDCIFit:LB_Sel
    if (!WaveExists(wSel))
        Make/O/N=1 root:Packages:ARPES_LJZ:MDCIFit:LB_Sel = 0
    endif

    Wave/Z wState = root:Packages:ARPES_LJZ:MDCIFit:LB_State
    if (!WaveExists(wState))
        Make/O/N=1 root:Packages:ARPES_LJZ:MDCIFit:LB_State = 0
    endif

    NVAR/Z curRow = root:Packages:ARPES_LJZ:MDCIFit:CurRow
    if (!NVAR_Exists(curRow))
        Variable/G root:Packages:ARPES_LJZ:MDCIFit:CurRow = -1
    endif

    SVAR/Z curWavePath = root:Packages:ARPES_LJZ:MDCIFit:CurWavePath
    if (!SVAR_Exists(curWavePath))
        String/G root:Packages:ARPES_LJZ:MDCIFit:CurWavePath = ""
    endif

    NVAR/Z modelID = root:Packages:ARPES_LJZ:MDCIFit:ModelID
    if (!NVAR_Exists(modelID))
        Variable/G root:Packages:ARPES_LJZ:MDCIFit:ModelID = 1
    endif

    NVAR/Z bgOrder = root:Packages:ARPES_LJZ:MDCIFit:BGOrder
    if (!NVAR_Exists(bgOrder))
        Variable/G root:Packages:ARPES_LJZ:MDCIFit:BGOrder = 2
    endif

    NVAR/Z xLo = root:Packages:ARPES_LJZ:MDCIFit:XLo
    if (!NVAR_Exists(xLo))
        Variable/G root:Packages:ARPES_LJZ:MDCIFit:XLo = NaN
    endif

    NVAR/Z xHi = root:Packages:ARPES_LJZ:MDCIFit:XHi
    if (!NVAR_Exists(xHi))
        Variable/G root:Packages:ARPES_LJZ:MDCIFit:XHi = NaN
    endif

    NVAR/Z useCsr = root:Packages:ARPES_LJZ:MDCIFit:UseCursors
    if (!NVAR_Exists(useCsr))
        Variable/G root:Packages:ARPES_LJZ:MDCIFit:UseCursors = 1
    endif

    Wave/Z wPar = root:Packages:ARPES_LJZ:MDCIFit:Par
    if (!WaveExists(wPar))
        Make/O/N=12 root:Packages:ARPES_LJZ:MDCIFit:Par = NaN
    endif

    Wave/Z wHold = root:Packages:ARPES_LJZ:MDCIFit:Hold
    if (!WaveExists(wHold))
        Make/O/N=12 root:Packages:ARPES_LJZ:MDCIFit:Hold = 0
    endif

    Wave/T/Z wPName = root:Packages:ARPES_LJZ:MDCIFit:ParName
    if (!WaveExists(wPName))
        Make/O/T/N=12 root:Packages:ARPES_LJZ:MDCIFit:ParName = ""
    endif

    Wave/Z wEn = root:Packages:ARPES_LJZ:MDCIFit:ParEnable
    if (!WaveExists(wEn))
        Make/O/N=12 root:Packages:ARPES_LJZ:MDCIFit:ParEnable = 0
    endif

    SVAR/Z sGuessTr = root:Packages:ARPES_LJZ:MDCIFit:GuessTrace
    if (!SVAR_Exists(sGuessTr))
        String/G root:Packages:ARPES_LJZ:MDCIFit:GuessTrace = ""
    endif

    SVAR/Z sFitTr = root:Packages:ARPES_LJZ:MDCIFit:FitTrace
    if (!SVAR_Exists(sFitTr))
        String/G root:Packages:ARPES_LJZ:MDCIFit:FitTrace = ""
    endif

    SVAR/Z sRes = root:Packages:ARPES_LJZ:MDCIFit:ResultText
    if (!SVAR_Exists(sRes))
        String/G root:Packages:ARPES_LJZ:MDCIFit:ResultText = ""
    endif

    SVAR/Z sResL = root:Packages:ARPES_LJZ:MDCIFit:ResultTextL
    if (!SVAR_Exists(sResL))
        String/G root:Packages:ARPES_LJZ:MDCIFit:ResultTextL = ""
    endif

    SVAR/Z sResR = root:Packages:ARPES_LJZ:MDCIFit:ResultTextR
    if (!SVAR_Exists(sResR))
        String/G root:Packages:ARPES_LJZ:MDCIFit:ResultTextR = ""
    endif

    SVAR/Z sMetric = root:Packages:ARPES_LJZ:MDCIFit:MetricText
    if (!SVAR_Exists(sMetric))
        String/G root:Packages:ARPES_LJZ:MDCIFit:MetricText = ""
    endif

    NVAR/Z isDirty = root:Packages:ARPES_LJZ:MDCIFit:DirtyFitState
    if (!NVAR_Exists(isDirty))
        Variable/G root:Packages:ARPES_LJZ:MDCIFit:DirtyFitState = 1
    endif

    // ---------- right info listbox waves ----------
    Wave/T/Z wMetricDisp = root:Packages:ARPES_LJZ:MDCIFit:MetricDisp
    if (!WaveExists(wMetricDisp))
        Make/O/T/N=1 root:Packages:ARPES_LJZ:MDCIFit:MetricDisp = ""
    endif

    Wave/Z wMetricSel = root:Packages:ARPES_LJZ:MDCIFit:MetricSel
    if (!WaveExists(wMetricSel))
        Make/O/N=1 root:Packages:ARPES_LJZ:MDCIFit:MetricSel = 0
    endif

    Wave/T/Z wResDispL = root:Packages:ARPES_LJZ:MDCIFit:ResDispL
    if (!WaveExists(wResDispL))
        Make/O/T/N=1 root:Packages:ARPES_LJZ:MDCIFit:ResDispL = ""
    endif

    Wave/Z wResSelL = root:Packages:ARPES_LJZ:MDCIFit:ResSelL
    if (!WaveExists(wResSelL))
        Make/O/N=1 root:Packages:ARPES_LJZ:MDCIFit:ResSelL = 0
    endif

    Wave/T/Z wResDispR = root:Packages:ARPES_LJZ:MDCIFit:ResDispR
    if (!WaveExists(wResDispR))
        Make/O/T/N=1 root:Packages:ARPES_LJZ:MDCIFit:ResDispR = ""
    endif

    Wave/Z wResSelR = root:Packages:ARPES_LJZ:MDCIFit:ResSelR
    if (!WaveExists(wResSelR))
        Make/O/N=1 root:Packages:ARPES_LJZ:MDCIFit:ResSelR = 0
    endif

    return 0
End

// -------------------------
// Helper: normalize DF path
// -------------------------
Function/S LJZ_IFit_NormDFPath(df)
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


// -------------------------
// Helper: state symbol
// -------------------------
Function/S LJZ_IFit_StateMark(st)
    Variable st

    if (st > 0)
        return "✓ "
    elseif (st < 0)
        return "✗ "
    endif
    return "· "
End


// -------------------------
// Helper: parse AcceptState from fitmeta
// -------------------------
Function LJZ_IFit_ReadAcceptState(wData)
    Wave wData

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    Wave/T/Z meta = $(dfW + nm + "_fitmeta")
    if (!WaveExists(meta))
        return 0
    endif

    String txt = meta[0]
    if (strlen(txt) == 0)
        return 0
    endif

    Variable st = NumberByKey("AcceptState", txt, "=", "\n")
    if (numtype(st) != 0)
        return 0
    endif

    return st
End


// -------------------------
// Helper: whether saved fit for this wave is valid
// 1 = valid clean fit
// 0 = invalid / fail / no meta / missing products
// -------------------------
Function LJZ_IFit_ReadFitValidState(wData)
    Wave wData

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)

    Wave/T/Z meta = $(dfW + nm + "_fitmeta")
    if (!WaveExists(meta))
        return 0
    endif

    String txt = meta[0]
    if (strlen(txt) == 0)
        return 0
    endif

    String sStat = StringByKey("Status", txt, "=", "\n")
    if (!StringMatch(sStat, "OK*"))
        return 0
    endif

    Wave/Z coef = $(dfW + nm + "_coef")
    Wave/Z wFit = $(dfW + nm + "_fit")
    if (!WaveExists(coef) || !WaveExists(wFit))
        return 0
    endif

    return 1
End


// -------------------------
// Helper: list MDC waves under target DF
// Prefer mdc_show_k sequence if present
// -------------------------
Function/S LJZ_IFit_ListMDCWaves(dfPath)
    String dfPath
    dfPath = LJZ_IFit_NormDFPath(dfPath)
    if (strlen(dfPath) == 0)
        return ""
    endif

    String out = ""

    Wave/Z w0 = $(dfPath + "mdc_show_0")
    if (WaveExists(w0))
        Variable k = 0
        do
            Wave/Z wk = $(dfPath + "mdc_show_" + Num2Str(k))
            if (!WaveExists(wk))
                break
            endif
            out = AddListItem(dfPath + NameOfWave(wk), out, ";", Inf)
            k += 1
        while (1)
        return out
    endif

    Variable iObj, nObj
    nObj = CountObjects(dfPath, 1)
    for (iObj = 0; iObj < nObj; iObj += 1)
        String nm = GetIndexedObjName(dfPath, 1, iObj)
        Wave/Z w = $(dfPath + nm)
        if (!WaveExists(w))
            continue
        endif

        if (DimSize(w, 1) > 0 || DimSize(w, 2) > 0 || DimSize(w, 3) > 0)
            continue
        endif

        String nmL = LowerStr(nm)
        if (StringMatch(nmL, "*mdc*"))
            out = AddListItem(dfPath + nm, out, ";", Inf)
        endif
    endfor

    return out
End


// -------------------------
// Helper: parse index from name "mdc_show_k"
// -------------------------
Function LJZ_IFit_ParseMDCIndex(nm)
    String nm

    if (!StringMatch(nm, "mdc_show_*"))
        return -1
    endif

    String tail = ReplaceString("mdc_show_", nm, "")
    return str2num(tail)
End


// -------------------------
// Helper: parse integer suffix after prefix
// -------------------------
Function LJZ_IFit_ParseSuffixIndex(ctrlName, prefix)
    String ctrlName, prefix

    if (!StringMatch(ctrlName, prefix + "*"))
        return -1
    endif

    String tail = ctrlName[strlen(prefix), inf]
    return str2num(tail)
End


// -------------------------
// Helper: build hold mask string from wHold[0..n-1]
// -------------------------
Function/S LJZ_IFit_HoldMaskFromWave(wHold, n)
    Wave wHold
    Variable n

    String s = ""
    Variable i
    for (i = 0; i < n; i += 1)
        if (wHold[i] != 0)
            s += "1"
        else
            s += "0"
        endif
    endfor

    return s
End


// -------------------------
// Helper: number of parameters by model
// -------------------------
Function LJZ_IFit_NPar(modelID)
    Variable modelID

if (modelID == 2 || modelID == 5)
    return 12
endif

    return 8
End


// -------------------------
// Helper: model display name
// -------------------------
Function/S LJZ_IFit_ModelName(modelID)
    Variable modelID

    if (modelID == 1)
        return "1PV"
    elseif (modelID == 2)
        return "2PV"
    elseif (modelID == 3)
        return "1Lor"
    elseif (modelID == 4)
        return "1Gau"
    elseif (modelID == 5)
        return "AsymPV+PV"
    endif

    return "Unknown"
End


// -------------------------
// Helper: BG display name
// -------------------------
Function/S LJZ_IFit_BGName(bgOrder)
    Variable bgOrder

    if (bgOrder == 0)
        return "Const"
    elseif (bgOrder == 1)
        return "Linear"
    elseif (bgOrder == 2)
        return "Quad"
    endif

    return "Unknown"
End


// -------------------------
// Helper: mark fit state dirty/clean
// -------------------------
Function LJZ_IFit_SetDirty(flag)
    Variable flag
    NVAR isDirty = root:Packages:ARPES_LJZ:MDCIFit:DirtyFitState
    isDirty = flag
    return 0
End


// -------------------------
// Helper: whether current fit is stale
// -------------------------
Function LJZ_IFit_IsDirty()
    NVAR isDirty = root:Packages:ARPES_LJZ:MDCIFit:DirtyFitState
    return isDirty
End


// -------------------------
// Helper: restore listbox selection to current row
// -------------------------
Function LJZ_IFit_RestoreCurrentSelection()
    LJZ_EnsureMDCIFitDF()

    NVAR curRow = root:Packages:ARPES_LJZ:MDCIFit:CurRow
    Wave wSel   = root:Packages:ARPES_LJZ:MDCIFit:LB_Sel

    if (!WaveExists(wSel))
        return -1
    endif

    wSel = 0
    if (curRow >= 0 && curRow < numpnts(wSel))
        wSel[curRow] = 1
    endif

    return 0
End


// -------------------------
// Helper: confirm before leaving dirty item
// -------------------------
Function LJZ_IFit_ConfirmLeaveIfDirty()
    LJZ_EnsureMDCIFitDF()

    SVAR curPath = root:Packages:ARPES_LJZ:MDCIFit:CurWavePath
    NVAR curRow  = root:Packages:ARPES_LJZ:MDCIFit:CurRow

    if (strlen(curPath) == 0 || curRow < 0)
        return 1
    endif

    if (!LJZ_IFit_IsDirty())
        return 1
    endif

    DoAlert 1, "Current MDC has unsaved/stale parameter changes. Discard them and continue?"
    if (V_flag == 1)
        return 1
    endif

    return 0
End


// -------------------------
// Helper: determine overlapping graph name
// -------------------------
Function/S LJZ_IFit_OverlapGraphName()
    String bnTag = ""

    SVAR/Z bn = root:ARPES_LJZ:MDCFit:gBaseName
    if (SVAR_Exists(bn) && strlen(bn) > 0)
        bnTag = bn
    endif

    if (strlen(bnTag) == 0)
        SVAR/Z runDF = root:ARPES_LJZ:MDCFit:RunDF
        if (SVAR_Exists(runDF) && strlen(runDF) > 0)
            String s = runDF
            Variable p1 = StrSearch(s, "MDCFit:", 0)
            if (p1 >= 0)
                p1 += strlen("MDCFit:")
                Variable p2 = StrSearch(s, "_RUN_", p1)
                if (p2 > p1)
                    bnTag = s[p1, p2 - 1]
                endif
            endif
        endif
    endif

    if (strlen(bnTag) == 0)
        bnTag = "MDC"
    endif

    return "MDC_Overlapping_" + CleanupName(bnTag, 0)
End


// -------------------------
// Helper: set ParName/ParEnable according to model & background order
// -------------------------
Function LJZ_IFit_SetParamLayout()
    NVAR modelID = root:Packages:ARPES_LJZ:MDCIFit:ModelID
    NVAR bgOrder = root:Packages:ARPES_LJZ:MDCIFit:BGOrder
    Wave/T pName = root:Packages:ARPES_LJZ:MDCIFit:ParName
    Wave   pEn   = root:Packages:ARPES_LJZ:MDCIFit:ParEnable
    Wave   pHold = root:Packages:ARPES_LJZ:MDCIFit:Hold

    pName = ""
    pEn   = 0

    Variable npar = LJZ_IFit_NPar(modelID)

    pName[0] = "c0 (bg const)"
    pName[1] = "c1 (bg linear)"
    pName[2] = "c2 (bg quad)"
    pEn[0] = 1
    pEn[1] = 1
    pEn[2] = 1

    if (bgOrder == 0)
        pHold[1] = 1
        pHold[2] = 1
    elseif (bgOrder == 1)
        pHold[1] = 0
        pHold[2] = 1
    else
        pHold[1] = 0
        pHold[2] = 0
    endif

    if (npar == 8)
        pName[3] = "H1 (height)"
        pName[4] = "x1 (center)"
        pName[5] = "w1_free"
        pName[6] = "eta1 (0..1)"
        pName[7] = "resH"

        pEn[3] = 1
        pEn[4] = 1
        pEn[5] = 1
        pEn[6] = 1
        pEn[7] = 1

        if (modelID == 1)
            pHold[6] = 0
        elseif (modelID == 3)
            pHold[6] = 1
        elseif (modelID == 4)
            pHold[6] = 1
        endif
    else
    if (modelID == 2)
        pName[3]  = "H1"
        pName[4]  = "x1"
        pName[5]  = "w1_free"
        pName[6]  = "eta1"
        pName[7]  = "H2"
        pName[8]  = "x2"
        pName[9]  = "w2_free"
        pName[10] = "eta2"
        pName[11] = "resH"
    elseif (modelID == 5)
        pName[3]  = "H_asym"
        pName[4]  = "x_asym"
        pName[5]  = "wL_free"
        pName[6]  = "wR_free"
        pName[7]  = "H_sym"
        pName[8]  = "x_sym"
        pName[9]  = "w_sym_free"
        pName[10] = "eta(shared)"
        pName[11] = "resH"
    endif

    pEn[3] = 1
    pEn[4] = 1
    pEn[5] = 1
    pEn[6] = 1
    pEn[7] = 1
    pEn[8] = 1
    pEn[9] = 1
    pEn[10] = 1
    pEn[11] = 1
endif

    return 0
End


// -------------------------
// Helper: apply model-specific fixed eta value
// -------------------------
Function LJZ_IFit_ApplyModelSpecials()
    NVAR modelID = root:Packages:ARPES_LJZ:MDCIFit:ModelID
    Wave p = root:Packages:ARPES_LJZ:MDCIFit:Par

    if (modelID == 3)
        p[6] = 1
    elseif (modelID == 4)
        p[6] = 0
    endif
End

// -------------------------
// Helper: sanitize parameters (hard mapping helper for panel/state)
// Only strictly clamp w_free, resH, eta
// Also keep x2 > x1 for 2PV
// -------------------------
Function LJZ_IFit_SanitizePar(p, modelID)
    Wave p
    Variable modelID

    Variable epsW   = 1e-4
    Variable epsRes = 1e-4
    Variable epsSep = 1e-4

    if (modelID == 2)
        p[5]  = max(epsW, abs(p[5]))
        p[6]  = min(1, max(0, p[6]))
        p[9]  = max(epsW, abs(p[9]))
        p[10] = min(1, max(0, p[10]))
        p[11] = max(epsRes, abs(p[11]))

        if (numtype(p[4]) == 0 && numtype(p[8]) == 0)
            if (p[8] <= p[4] + epsSep)
                p[8] = p[4] + epsSep
            endif
        endif

    elseif (modelID == 5)
        p[5]  = max(epsW, abs(p[5]))     // wL
        p[6]  = max(epsW, abs(p[6]))     // wR
        p[9]  = max(epsW, abs(p[9]))     // w_sym
        p[10] = min(1, max(0, p[10]))    // shared eta
        p[11] = max(epsRes, abs(p[11]))  // resH

        // 对称峰在右侧，避免身份乱跳
        if (numtype(p[4]) == 0 && numtype(p[8]) == 0)
            if (p[8] <= p[4] + epsSep)
                p[8] = p[4] + epsSep
            endif
        endif

    else
        p[5] = max(epsW, abs(p[5]))
        p[6] = min(1, max(0, p[6]))
        p[7] = max(epsRes, abs(p[7]))

        if (modelID == 3)
            p[6] = 1
        elseif (modelID == 4)
            p[6] = 0
        endif
    endif

    return 0
End

// -------------------------
// Helper: default hold policy for resH
// default only, not a permanent hard lock
// -------------------------
Function LJZ_IFit_SetDefaultHoldForModel()
    NVAR modelID = root:Packages:ARPES_LJZ:MDCIFit:ModelID
    Wave h = root:Packages:ARPES_LJZ:MDCIFit:Hold

if (modelID == 2 || modelID == 5)
    h[11] = 1
else
    h[7] = 1
endif

    return 0
End
// -------------------------
// Helper: estimate simple defaults from selected wave & ROI
// -------------------------
Function LJZ_IFit_AutoInitFromData(w)
    Wave w

    NVAR xLo = root:Packages:ARPES_LJZ:MDCIFit:XLo
    NVAR xHi = root:Packages:ARPES_LJZ:MDCIFit:XHi
    NVAR modelID = root:Packages:ARPES_LJZ:MDCIFit:ModelID
    Wave p = root:Packages:ARPES_LJZ:MDCIFit:Par

    Variable res = 0
    NVAR/Z gRes = root:ARPES_LJZ:MDCFit:Res
    if (NVAR_Exists(gRes) && numtype(gRes) == 0)
        res = gRes
    endif

    Variable npts = numpnts(w)
    if (npts <= 5)
        return -1
    endif

    Variable x0 = DimOffset(w, 0)
    Variable dx = DimDelta(w, 0)
    if (numtype(dx) != 0 || dx == 0)
        dx = 1
    endif

    Variable xMin = x0
    Variable xMax = x0 + dx * (npts - 1)

    if (numtype(xLo) != 0)
        xLo = xMin
    endif
    if (numtype(xHi) != 0)
        xHi = xMax
    endif

    Variable pLo = round((min(xLo, xHi) - x0) / dx)
    Variable pHi = round((max(xLo, xHi) - x0) / dx)
    pLo = max(0, min(npts - 1, pLo))
    pHi = max(0, min(npts - 1, pHi))

    if (pHi < pLo)
        Variable tmp = pLo
        pLo = pHi
        pHi = tmp
    endif

    if ((pHi - pLo) < 6)
        pLo = max(0, pLo - 3)
        pHi = min(npts - 1, pHi + 3)
    endif

    Make/FREE/N=(pHi-pLo+1) LJZIF_wSeg = w[pLo+p]
    SetScale/P x, x0 + pLo * dx, dx, LJZIF_wSeg

    WaveStats/Q LJZIF_wSeg
    Variable mn  = V_min
    Variable mx  = V_max
    Variable xpk = V_maxLoc

    p[0] = (mn + w[pLo] + w[pHi]) / 3
    p[1] = 0
    p[2] = 0

    if (modelID == 2)
        Variable x1 = x0 + (pLo + round((pHi - pLo) * 0.33)) * dx
        Variable x2 = x0 + (pLo + round((pHi - pLo) * 0.67)) * dx

        p[3]  = max(1e-6, mx - mn)
        p[4]  = x1
        p[5]  = max(1e-6, 3 * abs(dx))
        p[6]  = 0.8

        p[7]  = max(1e-6, mx - mn)
        p[8]  = x2
        p[9]  = max(1e-6, 3 * abs(dx))
        p[10] = 0.8

        p[11] = max(res, 1e-6)
        elseif (modelID == 5)
    Variable xa = x0 + (pLo + round((pHi - pLo) * 0.40)) * dx
    Variable xb = x0 + (pLo + round((pHi - pLo) * 0.72)) * dx

    p[3]  = max(1e-6, 0.8*(mx - mn))   // H_asym
    p[4]  = xa                         // x_asym
    p[5]  = max(1e-6, 2 * abs(dx))     // wL
    p[6]  = max(1e-6, 4 * abs(dx))     // wR

    p[7]  = max(1e-6, 0.5*(mx - mn))   // H_sym
    p[8]  = xb                         // x_sym
    p[9]  = max(1e-6, 3 * abs(dx))     // w_sym

    p[10] = 0.8                        // shared eta
    p[11] = max(res, 1e-6)
    
    else
        p[3] = max(1e-6, mx - mn)
        p[4] = xpk
        p[5] = max(1e-6, 3 * abs(dx))
        p[6] = 0.8
        p[7] = max(res, 1e-6)
    endif

    LJZ_IFit_ApplyModelSpecials()
    LJZ_IFit_SanitizePar(p, modelID)
    LJZ_IFit_SetDefaultHoldForModel()
    return 0
End


// -------------------------
// Helper: clear all traces in CURRENT active graph/subwindow
// -------------------------
Function LJZ_IFit_ClearActiveGraphTraces()
    return 0
End

// -------------------------
// Helper: stats index range for x window
// return pLo/pHi by reference-like globals via arguments
// -------------------------
Function LJZ_IFit_GetIndexRangeForX(w, x1, x2, pLo, pHi)
    Wave w
    Variable x1, x2
    Variable &pLo, &pHi

    Variable n = numpnts(w)
    Variable x0 = DimOffset(w, 0)
    Variable dx = DimDelta(w, 0)
    if (numtype(dx) != 0 || dx == 0)
        dx = 1
    endif

    Variable xa = min(x1, x2)
    Variable xb = max(x1, x2)

    pLo = floor((xa - x0) / dx)
    pHi = ceil((xb - x0) / dx)

    pLo = max(0, min(n-1, pLo))
    pHi = max(0, min(n-1, pHi))

    if (pHi < pLo)
        Variable tmp = pLo
        pLo = pHi
        pHi = tmp
    endif

    return 0
End

// -------------------------
// Helper: compute y range from currently relevant traces
// mode = 0 : main graph (data/guess/fit)
// mode = 1 : residual graph
// outputs yMin/yMax
// -------------------------
Function LJZ_IFit_GetPreviewYRange(wData, wGuess, wFit, wRes, x1, x2, isDirty, mode, yMin, yMax)
    Wave wData
    Wave/Z wGuess, wFit, wRes
    Variable x1, x2, isDirty, mode
    Variable &yMin, &yMax

    Variable pLo, pHi
    LJZ_IFit_GetIndexRangeForX(wData, x1, x2, pLo, pHi)

    yMin = Inf
    yMax = -Inf

    if (mode == 0)
        // data
        WaveStats/Q/R=[pLo, pHi] wData
        yMin = min(yMin, V_min)
        yMax = max(yMax, V_max)

        // guess
        if (WaveExists(wGuess))
            WaveStats/Q/R=[pLo, pHi] wGuess
            yMin = min(yMin, V_min)
            yMax = max(yMax, V_max)
        endif

        // fit
        if ((!isDirty) && WaveExists(wFit))
            WaveStats/Q/R=[pLo, pHi] wFit
            yMin = min(yMin, V_min)
            yMax = max(yMax, V_max)
        endif

        if (numtype(yMin) != 0 || numtype(yMax) != 0 || yMax <= yMin)
            yMin = 0
            yMax = 1
        endif

    else
        // residual
        if ((!isDirty) && WaveExists(wRes))
            WaveStats/Q/R=[pLo, pHi] wRes
            Variable rmax = max(abs(V_min), abs(V_max))
            if (numtype(rmax) != 0 || rmax <= 0)
                rmax = 1
            endif
            yMin = -1.08 * rmax
            yMax =  1.08 * rmax
        else
            yMin = -1
            yMax = 1
        endif
    endif

    return 0
End
// -------------------------
// Rebuild listbox waves + state marks
// Preserve current selection if possible
// -------------------------
Function LJZ_IFit_RebuildLB()
    LJZ_EnsureMDCIFitDF()

    SVAR target  = root:Packages:ARPES_LJZ:MDCIFit:TargetDF
    SVAR curPath = root:Packages:ARPES_LJZ:MDCIFit:CurWavePath
    SVAR sMetric = root:Packages:ARPES_LJZ:MDCIFit:MetricText
    SVAR sRes    = root:Packages:ARPES_LJZ:MDCIFit:ResultText
    SVAR sResL   = root:Packages:ARPES_LJZ:MDCIFit:ResultTextL
    SVAR sResR   = root:Packages:ARPES_LJZ:MDCIFit:ResultTextR
    NVAR curRow  = root:Packages:ARPES_LJZ:MDCIFit:CurRow

    String oldPath = curPath
    Variable oldDirty = LJZ_IFit_IsDirty()

    String dfPath = LJZ_IFit_NormDFPath(target)
    if (strlen(dfPath) == 0)
        SVAR/Z runDF = root:ARPES_LJZ:MDCFit:RunDF
        if (SVAR_Exists(runDF))
            dfPath = LJZ_IFit_NormDFPath(runDF)
            if (strlen(dfPath) > 0)
                target = dfPath
            endif
        endif
    endif

    String lst = LJZ_IFit_ListMDCWaves(target)

    Variable nItems = ItemsInList(lst, ";")
    if (nItems <= 0)
        nItems = 1
    endif

    Make/O/T/N=(nItems) root:Packages:ARPES_LJZ:MDCIFit:LB_Disp
    Make/O/T/N=(nItems) root:Packages:ARPES_LJZ:MDCIFit:LB_Path
    Make/O/N=(nItems)   root:Packages:ARPES_LJZ:MDCIFit:LB_Sel
    Make/O/N=(nItems)   root:Packages:ARPES_LJZ:MDCIFit:LB_State

    Wave/T wDisp  = root:Packages:ARPES_LJZ:MDCIFit:LB_Disp
    Wave/T wPath  = root:Packages:ARPES_LJZ:MDCIFit:LB_Path
    Wave   wSel   = root:Packages:ARPES_LJZ:MDCIFit:LB_Sel
    Wave   wState = root:Packages:ARPES_LJZ:MDCIFit:LB_State

    wSel = 0
    wState = 0

    if (ItemsInList(lst, ";") <= 0)
        curRow = -1
        curPath = ""
   	  sMetric = "No MDC selected."
   	  sRes  = ""
   	  sResL = ""
   	  sResR = ""
        LJZ_IFit_SetDirty(1)

        wDisp[0] = "(no MDC waves)"
        wPath[0] = ""
        wState[0] = 0

        LJZ_IFit_RefreshPreviewGraph()
        LJZ_IFit_RefreshMetricBox()
        return 0
    endif

    Variable iList, nList
    nList = ItemsInList(lst, ";")
    Variable foundOld = -1

    for (iList = 0; iList < nList; iList += 1)
        String full = StringFromList(iList, lst, ";")
        Wave/Z w = $full
        if (!WaveExists(w))
            continue
        endif

        String nm  = NameOfWave(w)
        Variable st = LJZ_IFit_ReadAcceptState(w)

        wState[iList] = st
        wDisp[iList] = LJZ_IFit_StateMark(st) + nm
        wPath[iList] = full

        if (cmpstr(full, oldPath) == 0)
            foundOld = iList
        endif
    endfor

    if (foundOld >= 0)
        curRow = foundOld
        curPath = wPath[foundOld]
        wSel[foundOld] = 1
        LJZ_IFit_SetDirty(oldDirty)
    else
        curRow = -1
        curPath = ""
        sMetric = "No MDC selected."
        sRes  = ""
        sResL = ""
        sResR = ""
        LJZ_IFit_SetDirty(1)
    endif

    LJZ_IFit_RefreshPreviewGraph()
    LJZ_IFit_RefreshMetricBox()
    return 0
End

// -------------------------
// Preview graph helpers
// -------------------------
Function MDCIFit_CreatePreviewGraph()
    DoWindow MDCIFit_LJZ_Panel
    if (V_flag == 0)
        return -1
    endif

    KillWindow/Z MDCIFit_LJZ_Panel#pvGraph
    KillWindow/Z MDCIFit_LJZ_Panel#rsGraph

Display/HOST=MDCIFit_LJZ_Panel/N=pvGraph/W=(250,208,690,338)
ModifyGraph/W=$"MDCIFit_LJZ_Panel#pvGraph" margin(left)=40,margin(bottom)=20
ModifyGraph/W=$"MDCIFit_LJZ_Panel#pvGraph" mirror=1
Label/W=$"MDCIFit_LJZ_Panel#pvGraph" left "Intensity"

Display/HOST=MDCIFit_LJZ_Panel/N=rsGraph/W=(250,342,690,392)
ModifyGraph/W=$"MDCIFit_LJZ_Panel#rsGraph" margin(left)=40,margin(bottom)=28
ModifyGraph/W=$"MDCIFit_LJZ_Panel#rsGraph" mirror=1
Label/W=$"MDCIFit_LJZ_Panel#rsGraph" left "Res"
Label/W=$"MDCIFit_LJZ_Panel#rsGraph" bottom "k / x"

    return 0
End

Function LJZ_IFit_RefreshPreviewGraph()
    String hostWin = "MDCIFit_LJZ_Panel"
    String pvName  = "pvGraph"
    String rsName  = "rsGraph"
    String pvWin   = hostWin + "#" + pvName
    String rsWin   = hostWin + "#" + rsName

    DoWindow $hostWin
    if (V_flag == 0)
        return -1
    endif

    // 这里只检查 host 的 child subwindow，不能对 "panel#sub" 用 DoWindow
    if (!LJZ_IFit_HasChildSubwindow(hostWin, pvName) || !LJZ_IFit_HasChildSubwindow(hostWin, rsName))
        MDCIFit_CreatePreviewGraph()
    endif

    SVAR curPath = root:Packages:ARPES_LJZ:MDCIFit:CurWavePath
    NVAR xLo     = root:Packages:ARPES_LJZ:MDCIFit:XLo
    NVAR xHi     = root:Packages:ARPES_LJZ:MDCIFit:XHi

    if (strlen(curPath) == 0)
        LJZ_IFit_ClearGraphTracesByWin(pvWin)
        SetAxis/Z/W=$pvWin bottom, 0, 1
        SetAxis/Z/W=$pvWin left, 0, 1

        LJZ_IFit_ClearGraphTracesByWin(rsWin)
        SetAxis/Z/W=$rsWin bottom, 0, 1
        SetAxis/Z/W=$rsWin left, -1, 1
        return -1
    endif

    Wave/Z wData = $curPath
    if (!WaveExists(wData))
        LJZ_IFit_ClearGraphTracesByWin(pvWin)
        SetAxis/Z/W=$pvWin bottom, 0, 1
        SetAxis/Z/W=$pvWin left, 0, 1

        LJZ_IFit_ClearGraphTracesByWin(rsWin)
        SetAxis/Z/W=$rsWin bottom, 0, 1
        SetAxis/Z/W=$rsWin left, -1, 1
        return -1
    endif

    String nm  = NameOfWave(wData)
    String dfW = GetWavesDataFolder(wData, 1)

    Wave/Z wGuess = $(dfW + nm + "_guess")
    Wave/Z wFit   = $(dfW + nm + "_fit")
    Wave/Z wRes   = $(dfW + nm + "_res")

    Variable isDirty = LJZ_IFit_IsDirty()

    Variable useROI = 0
    Variable xA, xB, xPad, xShowLo, xShowHi
    Variable dx = DimDelta(wData, 0)
    if (numtype(dx) != 0 || dx == 0)
        dx = 1
    endif

    if (numtype(xLo) == 0 && numtype(xHi) == 0)
        xA = min(xLo, xHi)
        xB = max(xLo, xHi)
        if (xA != xB)
            useROI = 1
            xPad = max(0.08 * abs(xB - xA), 2 * abs(dx))
            xShowLo = xA - xPad
            xShowHi = xB + xPad
        endif
    endif

    if (!useROI)
        Variable x0 = DimOffset(wData, 0)
        Variable n  = numpnts(wData)
        xShowLo = x0
        xShowHi = x0 + dx * (n - 1)
    endif

    Variable yMinMain, yMaxMain
    Variable yMinRes, yMaxRes
    LJZ_IFit_GetPreviewYRange(wData, wGuess, wFit, wRes, xShowLo, xShowHi, isDirty, 0, yMinMain, yMaxMain)
    LJZ_IFit_GetPreviewYRange(wData, wGuess, wFit, wRes, xShowLo, xShowHi, isDirty, 1, yMinRes, yMaxRes)

    Variable yPadMain = 0.06 * (yMaxMain - yMinMain)
    if (numtype(yPadMain) != 0 || yPadMain <= 0)
        yPadMain = 1
    endif

    if (numtype(xShowLo) != 0 || numtype(xShowHi) != 0 || xShowLo == xShowHi)
        xShowLo = 0
        xShowHi = 1
    endif
    if (numtype(yMinMain) != 0 || numtype(yMaxMain) != 0 || yMinMain == yMaxMain)
        yMinMain = 0
        yMaxMain = 1
    endif
    if (numtype(yMinRes) != 0 || numtype(yMaxRes) != 0 || yMinRes == yMaxRes)
        yMinRes = -1
        yMaxRes = 1
    endif

    // -------- upper graph --------
    LJZ_IFit_ClearGraphTracesByWin(pvWin)

    AppendToGraph/W=$pvWin wData
    if (WaveExists(wGuess))
        AppendToGraph/W=$pvWin wGuess
    endif
    if ((!isDirty) && WaveExists(wFit))
        AppendToGraph/W=$pvWin wFit
    endif

    ModifyGraph/W=$pvWin mode=0
    ModifyGraph/W=$pvWin lsize=1.5
    ModifyGraph/W=$pvWin rgb($NameOfWave(wData))=(0,0,0)

    if (WaveExists(wGuess))
        ModifyGraph/W=$pvWin rgb($NameOfWave(wGuess))=(0,0,65535)
        ModifyGraph/W=$pvWin lstyle($NameOfWave(wGuess))=2
    endif

    if ((!isDirty) && WaveExists(wFit))
        ModifyGraph/W=$pvWin rgb($NameOfWave(wFit))=(65535,0,0)
    endif

    SetAxis/Z/W=$pvWin bottom, xShowLo, xShowHi
    SetAxis/Z/W=$pvWin left, yMinMain - 0.3*yPadMain, yMaxMain + yPadMain

    // 有 trace 时再加 legend，避免空图时多余报错/残留
    if (ItemsInList(TraceNameList(pvWin, ";", 1), ";") > 0)
        Legend/W=$pvWin/C/N=text0/J
    else
        Legend/W=$pvWin/K/N=text0
    endif

    // -------- residual graph --------
    LJZ_IFit_ClearGraphTracesByWin(rsWin)

    if ((!isDirty) && WaveExists(wRes))
        AppendToGraph/W=$rsWin wRes
        ModifyGraph/W=$rsWin mode=0
        ModifyGraph/W=$rsWin lsize=1.2
        ModifyGraph/W=$rsWin rgb($NameOfWave(wRes))=(30000,30000,30000)
    endif

    SetAxis/Z/W=$rsWin bottom, xShowLo, xShowHi
    SetAxis/Z/W=$rsWin left, yMinRes, yMaxRes

    return 0
End

Function LJZ_IFit_HasChildSubwindow(hostWin, childName)
    String hostWin, childName

    String kids = ChildWindowList(hostWin)
    return (WhichListItem(childName, kids, ";", 0, 0) >= 0)
End
// -------------------------
// Metrics / result text
// -------------------------
Function LJZ_IFit_RefreshMetricBox()
    LJZ_EnsureMDCIFitDF()

    SVAR curPath = root:Packages:ARPES_LJZ:MDCIFit:CurWavePath
    SVAR sMetric = root:Packages:ARPES_LJZ:MDCIFit:MetricText
    SVAR sRes    = root:Packages:ARPES_LJZ:MDCIFit:ResultText
    SVAR sResL   = root:Packages:ARPES_LJZ:MDCIFit:ResultTextL
    SVAR sResR   = root:Packages:ARPES_LJZ:MDCIFit:ResultTextR

    Wave/T wMetricDisp = root:Packages:ARPES_LJZ:MDCIFit:MetricDisp
    Wave   wMetricSel  = root:Packages:ARPES_LJZ:MDCIFit:MetricSel
    Wave/T wResDispL   = root:Packages:ARPES_LJZ:MDCIFit:ResDispL
    Wave   wResSelL    = root:Packages:ARPES_LJZ:MDCIFit:ResSelL
    Wave/T wResDispR   = root:Packages:ARPES_LJZ:MDCIFit:ResDispR
    Wave   wResSelR    = root:Packages:ARPES_LJZ:MDCIFit:ResSelR

    if (strlen(curPath) == 0)
        sMetric = "No MDC selected."
        sRes  = ""
        sResL = ""
        sResR = ""
        LJZ_IFit_TextToListWave(wMetricDisp, wMetricSel, sMetric)
        LJZ_IFit_TextToListWave(wResDispL, wResSelL, "")
        LJZ_IFit_TextToListWave(wResDispR, wResSelR, "")
        return 0
    endif

    Wave/Z wData = $curPath
    if (!WaveExists(wData))
        sMetric = "Selected wave not found."
        sRes  = ""
        sResL = ""
        sResR = ""
        LJZ_IFit_TextToListWave(wMetricDisp, wMetricSel, sMetric)
        LJZ_IFit_TextToListWave(wResDispL, wResSelL, "")
        LJZ_IFit_TextToListWave(wResDispR, wResSelR, "")
        return 0
    endif

    String nm  = NameOfWave(wData)
    String dfW = GetWavesDataFolder(wData, 1)

    NVAR modelID = root:Packages:ARPES_LJZ:MDCIFit:ModelID
    NVAR bgOrder = root:Packages:ARPES_LJZ:MDCIFit:BGOrder
    NVAR xLo     = root:Packages:ARPES_LJZ:MDCIFit:XLo
    NVAR xHi     = root:Packages:ARPES_LJZ:MDCIFit:XHi
    NVAR curRow  = root:Packages:ARPES_LJZ:MDCIFit:CurRow
    Wave wState  = root:Packages:ARPES_LJZ:MDCIFit:LB_State

    Variable st = 0
    if (curRow >= 0 && curRow < numpnts(wState))
        st = wState[curRow]
    endif

    String stStr = "Unchecked"
    if (st > 0)
        stStr = "Accepted"
    elseif (st < 0)
        stStr = "Rejected"
    endif

    if (LJZ_IFit_IsDirty() && st != 0)
        stStr += " (last clean fit)"
    endif

    sMetric = ""
    sMetric += "Wave: " + nm + "\r"
    sMetric += "Model: " + LJZ_IFit_ModelName(modelID) + "\r"
    sMetric += "BG: " + LJZ_IFit_BGName(bgOrder) + "\r"
    sMetric += "ROI: [" + Num2Str(xLo) + ", " + Num2Str(xHi) + "]\r"
    sMetric += "State: " + stStr + "\r"
    sMetric += "N(all): " + Num2Str(numpnts(wData)) + "\r"

    Wave/T/Z meta   = $(dfW + nm + "_fitmeta")
    Wave/Z   coef   = $(dfW + nm + "_coef")
    Wave/Z   sigma  = $(dfW + nm + "_sigma")
    Wave/Z   wGuess = $(dfW + nm + "_guess")
    Wave      pGuess = root:Packages:ARPES_LJZ:MDCIFit:Par
    Variable isDirty = LJZ_IFit_IsDirty()

    if (WaveExists(wGuess))
        Variable x0g = DimOffset(wData, 0)
        Variable dxg = DimDelta(wData, 0)
        if (numtype(dxg) != 0 || dxg == 0)
            dxg = 1
        endif

        Variable pLoG, pHiG
        if (numtype(xLo) == 0 && numtype(xHi) == 0)
            pLoG = round((min(xLo, xHi) - x0g) / dxg)
            pHiG = round((max(xLo, xHi) - x0g) / dxg)
            pLoG = max(0, min(numpnts(wData)-1, pLoG))
            pHiG = max(0, min(numpnts(wData)-1, pHiG))
            if (pHiG < pLoG)
                Variable tmpG = pLoG
                pLoG = pHiG
                pHiG = tmpG
            endif
        else
            pLoG = 0
            pHiG = numpnts(wData)-1
        endif

        Make/FREE/N=(pHiG-pLoG+1) LJZIF_guessSeg = wData[pLoG+p] - wGuess[pLoG+p]
        Make/FREE/N=(numpnts(LJZIF_guessSeg)) LJZIF_guessSegSq = LJZIF_guessSeg[p]^2
        WaveStats/Q LJZIF_guessSegSq
        Variable guessRMSE = sqrt(V_avg)
        sMetric += "GuessRMSE: " + Num2Str(guessRMSE) + "\r"
    else
        sMetric += "GuessRMSE: --\r"
    endif

    sRes  = ""
    sResL = ""
    sResR = ""

    if (isDirty)
        sMetric += "FitRMSE: stale\r"
        sMetric += "ChiSq: stale\r"
        sMetric += "max|res|: stale\r"
        sMetric += "N(ROI): stale\r"

        sResL = "Current guess\r"
        sResR = ""

        if (modelID == 2)
            sResL += "G.H1: " + Num2Str(pGuess[3]) + "\r"
            sResL += "G.x1: " + Num2Str(pGuess[4]) + "\r"
            sResL += "G.w1: " + Num2Str(pGuess[5]) + "\r"

            sResR += "G.H2: " + Num2Str(pGuess[7]) + "\r"
            sResR += "G.x2: " + Num2Str(pGuess[8]) + "\r"
            sResR += "G.w2: " + Num2Str(pGuess[9]) + "\r"
            elseif (modelID == 5)
    sResL += "G.HA: " + Num2Str(pGuess[3]) + "\r"
    sResL += "G.xA: " + Num2Str(pGuess[4]) + "\r"
    sResL += "G.wL: " + Num2Str(pGuess[5]) + "\r"
    sResL += "G.wR: " + Num2Str(pGuess[6]) + "\r"

    sResR += "G.HS: " + Num2Str(pGuess[7]) + "\r"
    sResR += "G.xS: " + Num2Str(pGuess[8]) + "\r"
    sResR += "G.wS: " + Num2Str(pGuess[9]) + "\r"
    sResR += "G.eta:" + Num2Str(pGuess[10]) + "\r"
        else
            sResL += "G.H1: " + Num2Str(pGuess[3]) + "\r"
            sResL += "G.x1: " + Num2Str(pGuess[4]) + "\r"
            sResL += "G.w1: " + Num2Str(pGuess[5]) + "\r"
        endif
    else
        if (WaveExists(meta))
            String txt = meta[0]

            Variable fitRMSE = NumberByKey("FitRMSE", txt, "=", "\n")
            Variable chiSq   = NumberByKey("ChiSq", txt, "=", "\n")
            Variable maxAbs  = NumberByKey("MaxAbsRes", txt, "=", "\n")
            Variable nroi    = NumberByKey("NROI", txt, "=", "\n")

            if (numtype(fitRMSE) == 0)
                sMetric += "FitRMSE: " + Num2Str(fitRMSE) + "\r"
            else
                sMetric += "FitRMSE: --\r"
            endif

            if (numtype(chiSq) == 0)
                sMetric += "ChiSq: " + Num2Str(chiSq) + "\r"
            else
                sMetric += "ChiSq: --\r"
            endif

            if (numtype(maxAbs) == 0)
                sMetric += "max|res|: " + Num2Str(maxAbs) + "\r"
            else
                sMetric += "max|res|: --\r"
            endif

            if (numtype(nroi) == 0)
                sMetric += "N(ROI): " + Num2Str(nroi) + "\r"
            else
                sMetric += "N(ROI): --\r"
            endif
        else
            sMetric += "FitRMSE: --\r"
            sMetric += "ChiSq: --\r"
            sMetric += "max|res|: --\r"
            sMetric += "N(ROI): --\r"
        endif

        sResL = "Fitted params\r"
        sResR = ""

        if (WaveExists(coef))
            Variable ncoef = numpnts(coef)
            String lineTxt
            Variable ii
            for (ii = 0; ii < ncoef; ii += 1)
                lineTxt = "p" + Num2Str(ii) + " = " + Num2Str(coef[ii])

                if (WaveExists(sigma) && ii < numpnts(sigma) && numtype(sigma[ii]) == 0)
                    lineTxt += " ± " + Num2Str(sigma[ii])
                endif

                if (mod(ii, 2) == 0)
                    sResL += lineTxt + "\r"
                else
                    sResR += lineTxt + "\r"
                endif
            endfor
        endif
    endif

    LJZ_IFit_TextToListWave(wMetricDisp, wMetricSel, sMetric)
    LJZ_IFit_TextToListWave(wResDispL, wResSelL, sResL)
    LJZ_IFit_TextToListWave(wResDispR, wResSelR, sResR)

    return 0
End


// -------------------------
// Overlay management for external graph (keep old behavior)
// -------------------------
Function LJZ_IFit_OverlayGuessFit(wData, wGuess, wFit)
    Wave wData
    Wave/Z wGuess, wFit

    String g = LJZ_IFit_OverlapGraphName()
    DoWindow $g
    if (V_flag == 0)
        return 0        // 不再创建 MDCIFit_View
    endif

    Variable offY = 0
    NVAR/Z kvary = root:ARPES_LJZ:MDCFit:kvary
    String nm = NameOfWave(wData)
    Variable k = LJZ_IFit_ParseMDCIndex(nm)

    if (NVAR_Exists(kvary) && numtype(kvary) == 0 && k >= 0)
        offY = k * kvary
    endif

    Variable isDirty = LJZ_IFit_IsDirty()

    SVAR sGuessTr = root:Packages:ARPES_LJZ:MDCIFit:GuessTrace
    SVAR sFitTr   = root:Packages:ARPES_LJZ:MDCIFit:FitTrace

    if (strlen(sGuessTr) > 0)
        RemoveFromGraph/Z/W=$g $sGuessTr
        sGuessTr = ""
    endif

    if (strlen(sFitTr) > 0)
        RemoveFromGraph/Z/W=$g $sFitTr
        sFitTr = ""
    endif

    if (WaveExists(wGuess))
        String trGuess = NameOfWave(wGuess)
        AppendToGraph/W=$g wGuess
        ModifyGraph/W=$g offset($trGuess)={0, offY}
        sGuessTr = trGuess
    endif

    if ((!isDirty) && WaveExists(wFit))
        String trFit = NameOfWave(wFit)
        AppendToGraph/W=$g wFit
        ModifyGraph/W=$g offset($trFit)={0, offY}
        sFitTr = trFit
    endif

    return 0
End


// -------------------------
// ROI helper: optionally read cursors A/B from preview subwindow
// -------------------------
Function LJZ_IFit_ReadCursorsIfWanted()
    NVAR useCsr = root:Packages:ARPES_LJZ:MDCIFit:UseCursors
    if (!useCsr)
        return 0
    endif

    DoWindow MDCIFit_LJZ_Panel
    if (V_flag == 0)
        return 0
    endif

    NVAR xLo = root:Packages:ARPES_LJZ:MDCIFit:XLo
    NVAR xHi = root:Packages:ARPES_LJZ:MDCIFit:XHi

    // 直接从 preview 子图读取 cursor
    Variable xa = xcsr(A, "MDCIFit_LJZ_Panel#pvGraph")
    Variable xb = xcsr(B, "MDCIFit_LJZ_Panel#pvGraph")

    // 只有 A/B 都存在时才更新 ROI
    if (numtype(xa) == 0 && numtype(xb) == 0)
        xLo = xa
        xHi = xb
        return 1
    endif

    return 0
End


// -------------------------
// Create/overwrite guess wave in same DF as data; overlay it
// -------------------------
Function LJZ_IFit_UpdateGuessAndOverlay()
    LJZ_EnsureMDCIFitDF()

    SVAR curPath = root:Packages:ARPES_LJZ:MDCIFit:CurWavePath
    if (strlen(curPath) == 0)
        return -1
    endif

    Wave/Z wData = $curPath
    if (!WaveExists(wData))
        return -1
    endif

    LJZ_IFit_ReadCursorsIfWanted()

    NVAR modelID = root:Packages:ARPES_LJZ:MDCIFit:ModelID
    Wave p = root:Packages:ARPES_LJZ:MDCIFit:Par

    LJZ_IFit_ApplyModelSpecials()
    LJZ_IFit_SanitizePar(p, modelID)

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    String dfLocal = RemoveEnding(dfW, ":")

    String df0 = GetDataFolder(1)
    SetDataFolder $dfLocal

    Duplicate/O wData, $(nm + "_guess")
    Wave wGuess = $(nm + "_guess")

if (modelID == 2)
    wGuess = two_pv_ljz(p, x)
elseif (modelID == 5)
    wGuess = asympv_plus_pv_ljz(p, x)
else
    wGuess = one_pv_ljz(p, x)
endif

    Wave/Z wFit = $(dfW + nm + "_fit")
    SetDataFolder $df0

    LJZ_IFit_OverlayGuessFit(wData, wGuess, wFit)
    LJZ_IFit_RefreshPreviewGraph()
    LJZ_IFit_RefreshMetricBox()
    return 0
End


Function LJZ_IFit_LoadMetaIfAny(wData)
    Wave wData

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)

    Wave/T/Z meta = $(dfW + nm + "_fitmeta")
    if (!WaveExists(meta))
        return 0
    endif

    String txt = meta[0]
    if (strlen(txt) == 0)
        return 0
    endif

    NVAR modelID = root:Packages:ARPES_LJZ:MDCIFit:ModelID
    NVAR bgOrder = root:Packages:ARPES_LJZ:MDCIFit:BGOrder
    NVAR xLo     = root:Packages:ARPES_LJZ:MDCIFit:XLo
    NVAR xHi     = root:Packages:ARPES_LJZ:MDCIFit:XHi

    Wave p = root:Packages:ARPES_LJZ:MDCIFit:Par
    // 注意：hold 不再从 meta 覆盖

    // 保留当前 panel 的 resH
    Variable keepResH_1PV = p[7]
    Variable keepResH_2PV = p[11]

    Variable tmpv

    tmpv = NumberByKey("ModelID", txt, "=", "\n")
    if (numtype(tmpv) == 0)
        modelID = tmpv
    endif

    tmpv = NumberByKey("BGOrder", txt, "=", "\n")
    if (numtype(tmpv) == 0)
        bgOrder = tmpv
    endif

    tmpv = NumberByKey("xLo", txt, "=", "\n")
    if (numtype(tmpv) == 0)
        xLo = tmpv
    endif

    tmpv = NumberByKey("xHi", txt, "=", "\n")
    if (numtype(tmpv) == 0)
        xHi = tmpv
    endif

    Variable ii
    for (ii = 0; ii < 12; ii += 1)
        String k1 = "Par" + Num2Str(ii)
        Variable v1 = NumberByKey(k1, txt, "=", "\n")

        if (numtype(v1) == 0)
            p[ii] = v1
        endif
    endfor

    // 恢复当前 panel 的 resH，不让切波形把它带跑
    p[7]  = keepResH_1PV
    p[11] = keepResH_2PV
    LJZ_IFit_ApplyModelSpecials()
    LJZ_IFit_SanitizePar(p, modelID)
    return 1
End


// -------------------------
// Write accept state into fitmeta
// -------------------------
Function LJZ_IFit_WriteCurrentAcceptStateToMeta()
    SVAR curPath = root:Packages:ARPES_LJZ:MDCIFit:CurWavePath
    if (strlen(curPath) == 0)
        return -1
    endif

    Wave/Z wData = $curPath
    if (!WaveExists(wData))
        return -1
    endif

    NVAR curRow = root:Packages:ARPES_LJZ:MDCIFit:CurRow
    Wave wState = root:Packages:ARPES_LJZ:MDCIFit:LB_State

    Variable st = 0
    if (curRow >= 0 && curRow < numpnts(wState))
        st = wState[curRow]
    endif

    Variable approved = 0
    if (st > 0)
        approved = 1
    endif

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)

    String df0 = GetDataFolder(1)
    SetDataFolder $RemoveEnding(dfW, ":")

    Make/O/N=1 $(nm + "_accepted")
    Wave wAcc = $(nm + "_accepted")
    wAcc[0] = st
    Note/K wAcc
    Note wAcc, "1=accepted;0=unchecked;-1=rejected"

    Wave/T/Z meta = $(nm + "_fitmeta")
    if (!WaveExists(meta))
        Make/O/T/N=1 $(nm + "_fitmeta")
        Wave/T meta2 = $(nm + "_fitmeta")
        meta2[0] = ""
    endif

    Wave/T metaRef = $(nm + "_fitmeta")
    String txt = metaRef[0]
    txt = ReplaceNumberByKey("AcceptState", txt, st, "=", "\n")
    txt = ReplaceNumberByKey("Approved", txt, approved, "=", "\n")
    metaRef[0] = txt

    Wave/Z cwv = $(nm + "_coef")
    if (WaveExists(cwv))
        Note/K cwv
        Note cwv, txt
    endif

    SetDataFolder $df0
    return 0
End


Function LJZ_IFit_AppendFitMetricsToMeta(wData, wGuess, wFit, wRes)
    Wave wData, wGuess, wFit, wRes

    NVAR xLo = root:Packages:ARPES_LJZ:MDCIFit:XLo
    NVAR xHi = root:Packages:ARPES_LJZ:MDCIFit:XHi

    Variable x0 = DimOffset(wData, 0)
    Variable dx = DimDelta(wData, 0)
    if (numtype(dx) != 0 || dx == 0)
        dx = 1
    endif

    Variable pLo, pHi
    if (numtype(xLo) == 0 && numtype(xHi) == 0)
        pLo = round((min(xLo, xHi) - x0) / dx)
        pHi = round((max(xLo, xHi) - x0) / dx)
        pLo = max(0, min(numpnts(wData)-1, pLo))
        pHi = max(0, min(numpnts(wData)-1, pHi))
        if (pHi < pLo)
            Variable tmp = pLo
            pLo = pHi
            pHi = tmp
        endif
    else
        pLo = 0
        pHi = numpnts(wData)-1
    endif

    Make/FREE/N=(pHi-pLo+1) LJZIF_guessSeg = wData[pLo+p] - wGuess[pLo+p]
    Make/FREE/N=(pHi-pLo+1) LJZIF_fitSeg   = wRes[pLo+p]
    Make/FREE/N=(pHi-pLo+1) LJZIF_absSeg   = abs(LJZIF_fitSeg)

    Make/FREE/N=(numpnts(LJZIF_guessSeg)) LJZIF_guessSegSq = LJZIF_guessSeg[p]^2
    WaveStats/Q LJZIF_guessSegSq
    Variable guessRMSE = sqrt(V_avg)

    Make/FREE/N=(numpnts(LJZIF_fitSeg)) LJZIF_fitSegSq = LJZIF_fitSeg[p]^2
    WaveStats/Q LJZIF_fitSegSq
    Variable chiSq = V_sum
    Variable fitRMSE = sqrt(V_avg)

    WaveStats/Q LJZIF_absSeg
    Variable maxAbsRes = V_max

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)

    String df0 = GetDataFolder(1)
    SetDataFolder $RemoveEnding(dfW, ":")

    Wave/T/Z meta = $(nm + "_fitmeta")
    if (WaveExists(meta))
        String txt = meta[0]
        txt = ReplaceNumberByKey("GuessRMSE", txt, guessRMSE, "=", "\n")
        txt = ReplaceNumberByKey("FitRMSE", txt, fitRMSE, "=", "\n")
        txt = ReplaceNumberByKey("ChiSq", txt, chiSq, "=", "\n")
        txt = ReplaceNumberByKey("MaxAbsRes", txt, maxAbsRes, "=", "\n")
        txt = ReplaceNumberByKey("NROI", txt, numpnts(LJZIF_fitSeg), "=", "\n")
        meta[0] = txt

        Wave/Z cwv = $(nm + "_coef")
        if (WaveExists(cwv))
            Note/K cwv
            Note cwv, txt
        endif
    endif

    SetDataFolder $df0
    return 0
End


// -------------------------
// Save meta into <nm>_fitmeta in same DF
// -------------------------
Function LJZ_IFit_SaveMeta(wData, coefW, holdW, sigmaW, statusStr)
    Wave wData, coefW, holdW
    Wave/Z sigmaW
    String statusStr

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)

    NVAR modelID = root:Packages:ARPES_LJZ:MDCIFit:ModelID
    NVAR bgOrder = root:Packages:ARPES_LJZ:MDCIFit:BGOrder
    NVAR xLo     = root:Packages:ARPES_LJZ:MDCIFit:XLo
    NVAR xHi     = root:Packages:ARPES_LJZ:MDCIFit:XHi
    NVAR curRow  = root:Packages:ARPES_LJZ:MDCIFit:CurRow
    Wave wState  = root:Packages:ARPES_LJZ:MDCIFit:LB_State

    Variable accState = 0
    if (curRow >= 0 && curRow < numpnts(wState))
        accState = wState[curRow]
    endif

    Variable approved = 0
    if (accState > 0)
        approved = 1
    endif

    String tstamp = Secs2Date(DateTime, -2) + " " + Secs2Time(DateTime, 3)

    String txt = ""
    txt += "ModelID=" + Num2Str(modelID) + "\n"
    txt += "BGOrder=" + Num2Str(bgOrder) + "\n"
    txt += "xLo=" + Num2Str(xLo) + "\n"
    txt += "xHi=" + Num2Str(xHi) + "\n"
    txt += "Status=" + statusStr + "\n"
    txt += "AcceptState=" + Num2Str(accState) + "\n"
    txt += "Timestamp=" + tstamp + "\n"
    txt += "Approved=" + Num2Str(approved) + "\n"

    Variable ii
    for (ii = 0; ii < DimSize(coefW, 0); ii += 1)
        txt += "Par" + Num2Str(ii) + "=" + Num2Str(coefW[ii]) + "\n"
    endfor

    for (ii = 0; ii < DimSize(holdW, 0); ii += 1)
        txt += "Hold" + Num2Str(ii) + "=" + Num2Str(holdW[ii]) + "\n"
    endfor

    if (WaveExists(sigmaW))
        for (ii = 0; ii < DimSize(sigmaW, 0); ii += 1)
            txt += "Sigma" + Num2Str(ii) + "=" + Num2Str(sigmaW[ii]) + "\n"
        endfor
    endif

    String df0 = GetDataFolder(1)
    String dfLocal = RemoveEnding(dfW, ":")
    SetDataFolder $dfLocal

    Make/O/T/N=1 $(nm + "_fitmeta")
    Wave/T meta = $(nm + "_fitmeta")
    meta[0] = txt

    Wave/Z cwv = $(nm + "_coef")
    if (WaveExists(cwv))
        Note/K cwv
        Note cwv, txt
    endif

    Wave/Z swv = $(nm + "_sigma")
    if (WaveExists(swv))
        Note/K swv
        Note swv, txt
    endif

    SetDataFolder $df0
    return 0
End

// -------------------------
// Fit current MDC, save outputs into same DF
// IMPORTANT: fail fit does NOT overwrite official _coef/_fit/_res
// -------------------------
Function LJZ_IFit_RunFitAndSave()
    LJZ_EnsureMDCIFitDF()

    SVAR curPath = root:Packages:ARPES_LJZ:MDCIFit:CurWavePath
    if (strlen(curPath) == 0)
        DoAlert 0, "No MDC selected."
        return -1
    endif

    Wave/Z wData = $curPath
    if (!WaveExists(wData))
        DoAlert 0, "Selected wave not found."
        return -1
    endif

    LJZ_IFit_ReadCursorsIfWanted()

    NVAR modelID = root:Packages:ARPES_LJZ:MDCIFit:ModelID
    Wave pAll    = root:Packages:ARPES_LJZ:MDCIFit:Par
    Wave hAll    = root:Packages:ARPES_LJZ:MDCIFit:Hold

    LJZ_IFit_SetParamLayout()
    LJZ_IFit_ApplyModelSpecials()

    Variable npar = LJZ_IFit_NPar(modelID)

    Make/FREE/N=(npar) LJZIF_coef = pAll[p]
    LJZ_IFit_SanitizePar(LJZIF_coef, modelID)

    Make/FREE/N=(npar) LJZIF_hold = hAll[p]
    String holdStr = LJZ_IFit_HoldMaskFromWave(LJZIF_hold, npar)

    Variable npts = numpnts(wData)
    Variable x0 = DimOffset(wData, 0)
    Variable dx = DimDelta(wData, 0)
    if (numtype(dx) != 0 || dx == 0)
        dx = 1
    endif

    NVAR xLo = root:Packages:ARPES_LJZ:MDCIFit:XLo
    NVAR xHi = root:Packages:ARPES_LJZ:MDCIFit:XHi
    if (numtype(xLo) != 0 || numtype(xHi) != 0)
        xLo = x0
        xHi = x0 + dx * (npts - 1)
    endif

    Variable pLo = round((min(xLo, xHi) - x0) / dx)
    Variable pHi = round((max(xLo, xHi) - x0) / dx)
    pLo = max(0, min(npts - 1, pLo))
    pHi = max(0, min(npts - 1, pHi))

    if (pHi < pLo)
        Variable tmp = pLo
        pLo = pHi
        pHi = tmp
    endif

    Variable nROI = pHi - pLo + 1

    if (modelID == 2 || modelID == 5)
        if (nROI < 25)
            DoAlert 0, "ROI too small for 2PV (<25 pts). Adjust xLo/xHi."
            return -1
        endif
    else
        if (nROI < 12)
            DoAlert 0, "ROI too small for 1-peak model (<12 pts). Adjust xLo/xHi."
            return -1
        endif
    endif

    Make/FREE/N=(pHi-pLo+1) LJZIF_tpt = wData[pLo+p]
    SetScale/P x, x0 + pLo * dx, dx, LJZIF_tpt

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)
    String dfLocal = RemoveEnding(dfW, ":")
    String df0 = GetDataFolder(1)

    SetDataFolder $dfLocal

    Duplicate/O wData, $(nm + "_guess")
    Wave wGuess = $(nm + "_guess")
if (modelID == 2)
    wGuess = two_pv_ljz(LJZIF_coef, x)
elseif (modelID == 5)
    wGuess = asympv_plus_pv_ljz(LJZIF_coef, x)
else
    wGuess = one_pv_ljz(LJZIF_coef, x)
endif

    KillWaves/Z W_sigma

    Variable fitOK = 1
    String statusStr = "OK"

if (modelID == 2)
    FuncFit/Q/H=holdStr two_pv_ljz, LJZIF_coef, LJZIF_tpt
elseif (modelID == 5)
    FuncFit/Q/H=holdStr asympv_plus_pv_ljz, LJZIF_coef, LJZIF_tpt
else
    FuncFit/Q/H=holdStr one_pv_ljz, LJZIF_coef, LJZIF_tpt
endif

    LJZ_IFit_SanitizePar(LJZIF_coef, modelID)

    Variable fitErr = 0
    Variable fitQuit = 0

    NVAR/Z nvFitErr  = V_FitError
    NVAR/Z nvFitQuit = V_FitQuitReason

    if (NVAR_Exists(nvFitErr))
        fitErr = nvFitErr
    endif
    if (NVAR_Exists(nvFitQuit))
        fitQuit = nvFitQuit
    endif

    if ((fitErr != 0) || (fitQuit != 0))
        fitOK = 0
        statusStr = "FAIL; V_FitError=" + Num2Str(fitErr) + "; V_FitQuitReason=" + Num2Str(fitQuit)
    endif

    Duplicate/O LJZIF_coef, $(nm + "_coef")
    Wave wCoef = $(nm + "_coef")

    Wave/Z wSigmaTmp = W_sigma
    if (WaveExists(wSigmaTmp))
        Duplicate/O wSigmaTmp, $(nm + "_sigma")
    else
        Make/O/N=(npar) $(nm + "_sigma") = NaN
    endif
    Wave wSigma = $(nm + "_sigma")

    Duplicate/O wData, $(nm + "_fit")
    Wave wFit = $(nm + "_fit")
if (modelID == 2)
    wFit = two_pv_ljz(wCoef, x)
elseif (modelID == 5)
    wFit = asympv_plus_pv_ljz(wCoef, x)
else
    wFit = one_pv_ljz(wCoef, x)
endif

    Duplicate/O wData, $(nm + "_res")
    Wave wRes = $(nm + "_res")
    wRes = wData - wFit

    LJZ_IFit_SaveMeta(wData, wCoef, LJZIF_hold, wSigma, statusStr)
    LJZ_IFit_AppendFitMetricsToMeta(wData, wGuess, wFit, wRes)
    LJZ_IFit_SaveStandardResultWaves(wData, wCoef, wSigma)

    if (fitOK)
        LJZ_IFit_SetDirty(0)
    else
        LJZ_IFit_SetDirty(1)
    endif

    pAll[0, npar-1] = wCoef[p]
    hAll[0, npar-1] = LJZIF_hold[p]

    SVAR sRes  = root:Packages:ARPES_LJZ:MDCIFit:ResultText
    SVAR sResL = root:Packages:ARPES_LJZ:MDCIFit:ResultTextL
    SVAR sResR = root:Packages:ARPES_LJZ:MDCIFit:ResultTextR

    sRes  = statusStr + "\r"
    sResL = statusStr + "\r"
    sResR = "\r"

    Variable ii
    String oneLine
    for (ii = 0; ii < npar; ii += 1)
        oneLine = "p" + Num2Str(ii) + "=" + Num2Str(wCoef[ii])

        if (WaveExists(wSigma) && ii < numpnts(wSigma) && numtype(wSigma[ii]) == 0)
            oneLine += " ± " + Num2Str(wSigma[ii])
        endif

        if (LJZIF_hold[ii] != 0)
            oneLine += " (H)"
        endif

        sRes += oneLine + "\r"

        if (mod(ii, 2) == 0)
            sResL += oneLine + "\r"
        else
            sResR += oneLine + "\r"
        endif
    endfor

    SetDataFolder $df0

    LJZ_IFit_OverlayGuessFit(wData, wGuess, wFit)
    LJZ_IFit_RebuildLB()

    Wave/T wPath = root:Packages:ARPES_LJZ:MDCIFit:LB_Path
    Variable kk
    for (kk = 0; kk < numpnts(wPath); kk += 1)
        if (cmpstr(wPath[kk], curPath) == 0)
            MDCIFit_SelectCurrentRow(kk)
            break
        endif
    endfor

    LJZ_IFit_RefreshParamControls()
    LJZ_IFit_RefreshPreviewGraph()
    LJZ_IFit_RefreshMetricBox()

    if (fitOK)
        return 0
    endif
    return -1
End


// ============================================================================
//  Panel entry
// ============================================================================
Proc MDCIFit_LJZ()
    MDCIFit_InitFromMDCFit()

    DoWindow/F MDCIFit_LJZ_Panel
    if (V_flag == 0)
        MDCIFit_LJZ_P()
    endif
End


Function MDCIFit_InitFromMDCFit()
    LJZ_EnsureMDCIFitDF()

    DFREF dfrIF = root:Packages:ARPES_LJZ:MDCIFit
    SVAR/SDFR=dfrIF target = TargetDF

    DFREF dfrMF = root:ARPES_LJZ:MDCFit
    if (DataFolderRefStatus(dfrMF) != 0)
        SVAR/Z/SDFR=dfrMF runDF = RunDF
        if (SVAR_Exists(runDF))
            if (strlen(runDF) > 0)
                target = runDF
            endif
        endif
    endif

    LJZ_IFit_RebuildLB()
    return 0
End


// ============================================================================
//  Panel definition
// ============================================================================
Window MDCIFit_LJZ_P() : Panel
    PauseUpdate; Silent 1
    NewPanel /W=(120,60,940,650) /N=MDCIFit_LJZ_Panel as "MDC Interactive Fit Workbench"
    ModifyPanel frameStyle=1

    TitleBox tbT,pos={12,8},size={250,18},title="Target DF (default: ShowMDC runDF)",frame=0

    SetVariable svTarget,pos={12,28},size={500,20},proc=MDCIFit_SetVarProc,title="DF:"
    SetVariable svTarget,value=_STR:""

    Button btnRebuild,pos={525,27},size={95,22},proc=MDCIFit_ButtonProc,title="Refresh"

    ListBox lbMDC,pos={12,58},size={220,520},proc=MDCIFit_LBProc
    ListBox lbMDC,listWave=root:Packages:ARPES_LJZ:MDCIFit:LB_Disp
    ListBox lbMDC,selWave=root:Packages:ARPES_LJZ:MDCIFit:LB_Sel,mode=1

    PopupMenu pmModel,pos={250,62},size={145,20},proc=MDCIFit_ModelPopProc,title="Model:"
    PopupMenu pmModel,mode=1,popvalue="1PV",value=#"\"1PV;2PV;1Lor(eta=1 hold);1Gau(eta=0 hold);AsymPV+PV\""
    PopupMenu pmBG,pos={250,90},size={145,20},proc=MDCIFit_BGPopProc,title="BG:"
    PopupMenu pmBG,mode=3,popvalue="Quad",value=#"\"Const;Linear;Quad\""

    CheckBox cbCsr,pos={430,92},size={135,16},proc=MDCIFit_CheckProc,title="Read cursors A/B"
    CheckBox cbCsr,value=1

    SetVariable svXLo,pos={250,122},size={150,20},proc=MDCIFit_SetVarProc,title="xLo"
    SetVariable svXLo,value=_NUM:0

    SetVariable svXHi,pos={415,122},size={150,20},proc=MDCIFit_SetVarProc,title="xHi"
    SetVariable svXHi,value=_NUM:0

    Button btnExport,pos={580,122},size={100,20},proc=MDCIFit_ButtonProc,title="Summary"

    Button btnGuess,pos={250,154},size={78,24},proc=MDCIFit_ButtonProc,title="Guess"
    Button btnFit,pos={336,154},size={78,24},proc=MDCIFit_ButtonProc,title="Fit"

    Button btnAccept,pos={430,154},size={72,24},proc=MDCIFit_ButtonProc,title="Accept"
    Button btnReject,pos={508,154},size={72,24},proc=MDCIFit_ButtonProc,title="Reject"
    Button btnClearMark,pos={586,154},size={82,24},proc=MDCIFit_ButtonProc,title="Clear"

    Button btnPrev,pos={428,62},size={55,24},proc=MDCIFit_ButtonProc,title="Prev"
    Button btnNext,pos={499,62},size={55,24},proc=MDCIFit_ButtonProc,title="Next"
    Button btnNextUnchecked,pos={565,62},size={105,24},proc=MDCIFit_ButtonProc,title="Next Unchecked"

    TitleBox tbPreviewHead,pos={250,186},size={80,18},title="Preview",frame=0,fStyle=1
    TitleBox tbParamHead,pos={250,402},size={90,18},title="Parameters",frame=0,fStyle=1

// ---------------- right info area ----------------
TitleBox tbMetricHead,pos={740,12},size={70,20},title="Metrics",frame=0,fStyle=1
GroupBox gbMetric,pos={740,36},size={235,210},title=""
ListBox lbMetric,pos={750,48},size={215,190}
ListBox lbMetric,listWave=root:Packages:ARPES_LJZ:MDCIFit:MetricDisp
ListBox lbMetric,selWave=root:Packages:ARPES_LJZ:MDCIFit:MetricSel,mode=1

TitleBox tbResHead,pos={740,258},size={85,20},title="Fit Result",frame=0,fStyle=1
GroupBox gbRes,pos={740,282},size={235,300},title=""

ListBox lbResL,pos={750,294},size={102,278}
ListBox lbResL,listWave=root:Packages:ARPES_LJZ:MDCIFit:ResDispL
ListBox lbResL,selWave=root:Packages:ARPES_LJZ:MDCIFit:ResSelL,mode=1

ListBox lbResR,pos={862,294},size={102,278}
ListBox lbResR,listWave=root:Packages:ARPES_LJZ:MDCIFit:ResDispR
ListBox lbResR,selWave=root:Packages:ARPES_LJZ:MDCIFit:ResSelR,mode=1
    
    MDCIFit_CreatePreviewGraph()
    MDCIFit_BuildParamControls()
    LJZ_IFit_SetParamLayout()
    LJZ_IFit_RefreshParamControls()
    LJZ_IFit_RefreshMetricBox()
EndMacro


// -------------------------
// Parameter controls
// -------------------------
Function MDCIFit_BuildParamControls()
    DoWindow MDCIFit_LJZ_Panel
    if (V_flag == 0)
        return -1
    endif

    Variable ii
    for (ii = 0; ii < 12; ii += 1)
        String tb = "tbP" + Num2Str(ii)
        String sv = "svP" + Num2Str(ii)
        String cb = "cbH" + Num2Str(ii)

        KillControl/W=MDCIFit_LJZ_Panel $tb
        KillControl/W=MDCIFit_LJZ_Panel $sv
        KillControl/W=MDCIFit_LJZ_Panel $cb
    endfor

    Variable leftX_name  = 250
    Variable leftX_val   = 380
    Variable leftX_hold  = 485

    Variable rightX_name = 510
    Variable rightX_val  = 625
    Variable rightX_hold = 730

    Variable y0 = 428
    Variable dy = 24

    for (ii = 0; ii < 12; ii += 1)
        String tbName = "tbP" + Num2Str(ii)
        String svName = "svP" + Num2Str(ii)
        String cbName = "cbH" + Num2Str(ii)

        Variable col = trunc(ii/6)
        Variable row = mod(ii, 6)

        Variable xName, xVal, xHold, yNow
        yNow = y0 + row*dy

        if (col == 0)
            xName = leftX_name
            xVal  = leftX_val
            xHold = leftX_hold
        else
            xName = rightX_name
            xVal  = rightX_val
            xHold = rightX_hold
        endif

        Execute/Q ("TitleBox " + tbName + ",win=MDCIFit_LJZ_Panel,pos={" + Num2Str(xName) + "," + Num2Str(yNow) + "},size={120,16},title=\"P" + Num2Str(ii) + "\",frame=0\r")
        Execute/Q ("SetVariable " + svName + ",win=MDCIFit_LJZ_Panel,pos={" + Num2Str(xVal) + "," + Num2Str(yNow-2) + "},size={95,20},proc=MDCIFit_SetVarProc,title=\"\"\r")
        Execute/Q ("CheckBox " + cbName + ",win=MDCIFit_LJZ_Panel,pos={" + Num2Str(xHold) + "," + Num2Str(yNow) + "},size={34,16},proc=MDCIFit_CheckProc,title=\"H\"\r")
    endfor

    LJZ_IFit_SetParamLayout()
    LJZ_IFit_RefreshParamControls()
    return 0
End


// -------------------------
// Refresh all controls from package state
// -------------------------
Function LJZ_IFit_RefreshParamControls()
    DoWindow MDCIFit_LJZ_Panel
    if (V_flag == 0)
        return 0
    endif

    Wave/T pName = root:Packages:ARPES_LJZ:MDCIFit:ParName
    Wave   pEn   = root:Packages:ARPES_LJZ:MDCIFit:ParEnable
    Wave   p     = root:Packages:ARPES_LJZ:MDCIFit:Par
    Wave   h     = root:Packages:ARPES_LJZ:MDCIFit:Hold

    SVAR target  = root:Packages:ARPES_LJZ:MDCIFit:TargetDF
    NVAR modelID = root:Packages:ARPES_LJZ:MDCIFit:ModelID
    NVAR bgOrder = root:Packages:ARPES_LJZ:MDCIFit:BGOrder
    NVAR xLo     = root:Packages:ARPES_LJZ:MDCIFit:XLo
    NVAR xHi     = root:Packages:ARPES_LJZ:MDCIFit:XHi
    NVAR useCsr  = root:Packages:ARPES_LJZ:MDCIFit:UseCursors

    SetVariable/Z svTarget, win=MDCIFit_LJZ_Panel, value=_STR:target
    SetVariable/Z svXLo,    win=MDCIFit_LJZ_Panel, value=_NUM:xLo
    SetVariable/Z svXHi,    win=MDCIFit_LJZ_Panel, value=_NUM:xHi

    PopupMenu/Z pmModel, win=MDCIFit_LJZ_Panel, mode=modelID
    PopupMenu/Z pmBG,    win=MDCIFit_LJZ_Panel, mode=(bgOrder + 1)
    CheckBox/Z cbCsr,    win=MDCIFit_LJZ_Panel, value=useCsr

Variable leftX_name  = 250
Variable leftX_val   = 325
Variable leftX_hold  = 440

Variable rightX_name = 480
Variable rightX_val  = 555
Variable rightX_hold = 670

    Variable y0 = 428
    Variable dy = 24

    Variable visibleIdx = 0
    Variable ii

    for (ii = 0; ii < 12; ii += 1)
        String tb = "tbP" + Num2Str(ii)
        String sv = "svP" + Num2Str(ii)
        String cb = "cbH" + Num2Str(ii)

        Variable tmpVal = p[ii]
        Variable tmpChk = (h[ii] != 0)

        TitleBox/Z $tb, win=MDCIFit_LJZ_Panel, title=pName[ii]
        SetVariable/Z $sv, win=MDCIFit_LJZ_Panel, value=_NUM:tmpVal
        CheckBox/Z $cb, win=MDCIFit_LJZ_Panel, value=tmpChk

        if (pEn[ii])
            Variable col = trunc(visibleIdx/6)
            Variable row = mod(visibleIdx, 6)

            Variable xName, xVal, xHold, yNow
            yNow = y0 + row*dy

            if (col == 0)
                xName = leftX_name
                xVal  = leftX_val
                xHold = leftX_hold
            else
                xName = rightX_name
                xVal  = rightX_val
                xHold = rightX_hold
            endif

            TitleBox/Z $tb, win=MDCIFit_LJZ_Panel, pos={xName, yNow}
            SetVariable/Z $sv, win=MDCIFit_LJZ_Panel, pos={xVal, yNow-3}
            CheckBox/Z $cb, win=MDCIFit_LJZ_Panel, pos={xHold, yNow-1}

            ModifyControl/Z $tb, win=MDCIFit_LJZ_Panel, disable=0
            ModifyControl/Z $sv, win=MDCIFit_LJZ_Panel, disable=0
            ModifyControl/Z $cb, win=MDCIFit_LJZ_Panel, disable=0

            visibleIdx += 1
        else
            TitleBox/Z $tb, win=MDCIFit_LJZ_Panel, pos={-500, -500}
            SetVariable/Z $sv, win=MDCIFit_LJZ_Panel, pos={-500, -500}
            CheckBox/Z $cb, win=MDCIFit_LJZ_Panel, pos={-500, -500}

            ModifyControl/Z $tb, win=MDCIFit_LJZ_Panel, disable=2
            ModifyControl/Z $sv, win=MDCIFit_LJZ_Panel, disable=2
            ModifyControl/Z $cb, win=MDCIFit_LJZ_Panel, disable=2
        endif
    endfor

    return 0
End


Function LJZ_IFit_ExportSummary()
    LJZ_EnsureMDCIFitDF()

    SVAR target = root:Packages:ARPES_LJZ:MDCIFit:TargetDF
    String dfPath = LJZ_IFit_NormDFPath(target)
    if (strlen(dfPath) == 0)
        DoAlert 0, "Target DF is invalid."
        return -1
    endif

    String lst = LJZ_IFit_ListMDCWaves(dfPath)
    Variable nList = ItemsInList(lst, ";")
    if (nList <= 0)
        DoAlert 0, "No MDC waves found."
        return -1
    endif

    String df0 = GetDataFolder(1)

    // ------------------------------------------------
    // 输出到 runDF:FIT_HP:
    // ------------------------------------------------
    String fitHPPath = RemoveEnding(dfPath, ":") + ":FIT_HP"
    NewDataFolder/O $fitHPPath
    SetDataFolder $fitHPPath

    // ------------------------------------------------
    // 主结果波：名字严格按 RA 风格
    // ------------------------------------------------
    Make/O/N=(nList) Peak1K, Peak2K, Peak3K
    Make/O/N=(nList) SigmaP1K, SigmaP2K, SigmaP3K
    Make/O/N=(nList) AreaP1K, AreaP2K, AreaP3K
    Make/O/N=(nList) AreaSum12K, Sep12K
    Make/O/N=(nList) WeffP1K, WeffP2K, WeffP3K
    Make/O/N=(nList) BG_c0, BG_c1, BG_c2

    Peak1K    = NaN
    Peak2K    = NaN
    Peak3K    = NaN
    SigmaP1K  = NaN
    SigmaP2K  = NaN
    SigmaP3K  = NaN
    AreaP1K   = NaN
    AreaP2K   = NaN
    AreaP3K   = NaN
    AreaSum12K= NaN
    Sep12K    = NaN
    WeffP1K   = NaN
    WeffP2K   = NaN
    WeffP3K   = NaN
    BG_c0     = NaN
    BG_c1     = NaN
    BG_c2     = NaN

    Variable ii
    for (ii = 0; ii < nList; ii += 1)

        String full = StringFromList(ii, lst, ";")
        Wave/Z w = $full
        if (!WaveExists(w))
            continue
        endif

        String nm  = NameOfWave(w)
        String dfW = GetWavesDataFolder(w, 1)

        // --------------------------------------------
        // 优先读取单条拟合时已经存好的标准结果波
        // --------------------------------------------
        Wave/Z wp1   = $(dfW + nm + "_Peak1K")
        Wave/Z wp2   = $(dfW + nm + "_Peak2K")
        Wave/Z wp3   = $(dfW + nm + "_Peak3K")
        Wave/Z ws1   = $(dfW + nm + "_SigmaP1K")
        Wave/Z ws2   = $(dfW + nm + "_SigmaP2K")
        Wave/Z ws3   = $(dfW + nm + "_SigmaP3K")
        Wave/Z wa1   = $(dfW + nm + "_AreaP1K")
        Wave/Z wa2   = $(dfW + nm + "_AreaP2K")
        Wave/Z wa3   = $(dfW + nm + "_AreaP3K")
        Wave/Z wa12  = $(dfW + nm + "_AreaSum12K")
        Wave/Z wsep  = $(dfW + nm + "_Sep12K")
        Wave/Z ww1   = $(dfW + nm + "_WeffP1K")
        Wave/Z ww2   = $(dfW + nm + "_WeffP2K")
        Wave/Z ww3   = $(dfW + nm + "_WeffP3K")
        Wave/Z wbg0  = $(dfW + nm + "_BG_c0")
        Wave/Z wbg1  = $(dfW + nm + "_BG_c1")
        Wave/Z wbg2  = $(dfW + nm + "_BG_c2")

        if (WaveExists(wp1))
            Peak1K[ii] = wp1[0]
        endif
        if (WaveExists(wp2))
            Peak2K[ii] = wp2[0]
        endif
        if (WaveExists(wp3))
            Peak3K[ii] = wp3[0]
        endif

        if (WaveExists(ws1))
            SigmaP1K[ii] = ws1[0]
        endif
        if (WaveExists(ws2))
            SigmaP2K[ii] = ws2[0]
        endif
        if (WaveExists(ws3))
            SigmaP3K[ii] = ws3[0]
        endif

        if (WaveExists(wa1))
            AreaP1K[ii] = wa1[0]
        endif
        if (WaveExists(wa2))
            AreaP2K[ii] = wa2[0]
        endif
        if (WaveExists(wa3))
            AreaP3K[ii] = wa3[0]
        endif
        if (WaveExists(wa12))
            AreaSum12K[ii] = wa12[0]
        endif

        if (WaveExists(wsep))
            Sep12K[ii] = wsep[0]
        endif

        if (WaveExists(ww1))
            WeffP1K[ii] = ww1[0]
        endif
        if (WaveExists(ww2))
            WeffP2K[ii] = ww2[0]
        endif
        if (WaveExists(ww3))
            WeffP3K[ii] = ww3[0]
        endif

        if (WaveExists(wbg0))
            BG_c0[ii] = wbg0[0]
        endif
        if (WaveExists(wbg1))
            BG_c1[ii] = wbg1[0]
        endif
        if (WaveExists(wbg2))
            BG_c2[ii] = wbg2[0]
        endif

        // --------------------------------------------
        // 复制曲线，做成 FIT_RA 那种 layer_show_k / fit_layer_k
        // --------------------------------------------
        Variable k = LJZ_IFit_ParseMDCIndex(nm)
        if (k < 0)
            k = ii
        endif

        Duplicate/O w, $("layer_show_" + Num2Str(k))

        Wave/Z wf = $(dfW + nm + "_fit")
        if (WaveExists(wf))
            Duplicate/O wf, $("fit_layer_" + Num2Str(k))
        endif
    endfor

    SetDataFolder $df0
    DoAlert 0, "FIT_HP exported under: " + fitHPPath + ":"
    return 0
End


// ============================================================================
//  Selection helper
// ============================================================================
Function MDCIFit_SelectCurrentRow(newRow)
    Variable newRow

    LJZ_EnsureMDCIFitDF()

    Wave/T wPath = root:Packages:ARPES_LJZ:MDCIFit:LB_Path
    Wave   wSel  = root:Packages:ARPES_LJZ:MDCIFit:LB_Sel

    if (newRow < 0 || newRow >= numpnts(wPath))
        return -1
    endif

    NVAR curRow   = root:Packages:ARPES_LJZ:MDCIFit:CurRow
    SVAR curPath  = root:Packages:ARPES_LJZ:MDCIFit:CurWavePath

    curRow  = newRow
    curPath = wPath[newRow]

    wSel = 0
    wSel[newRow] = 1

    // 显式刷新 ListBox 选中高亮
	LJZ_IFit_RestoreCurrentSelectionUI()
	
    Wave/Z wData = $curPath
    if (!WaveExists(wData))
        return -1
    endif

    Variable loaded = LJZ_IFit_LoadMetaIfAny(wData)
    if (!loaded)
        LJZ_IFit_AutoInitFromData(wData)
        LJZ_IFit_SetDirty(1)
    else
        if (LJZ_IFit_ReadFitValidState(wData))
            LJZ_IFit_SetDirty(0)
        else
            LJZ_IFit_SetDirty(1)
        endif
    endif

    // 重新应用当前 panel 的 hold 规则（BG / Lor / Gau 特殊项）
    LJZ_IFit_SetParamLayout()
    LJZ_IFit_RefreshParamControls()
    LJZ_IFit_RefreshPreviewGraph()
    LJZ_IFit_RefreshMetricBox()

    return 0
End


// -------------------------
// Change current mark state
// -------------------------
Function LJZ_IFit_SetCurrentState(newState)
    Variable newState

    NVAR curRow = root:Packages:ARPES_LJZ:MDCIFit:CurRow
    Wave/T wDisp = root:Packages:ARPES_LJZ:MDCIFit:LB_Disp
    Wave/T wPath = root:Packages:ARPES_LJZ:MDCIFit:LB_Path
    Wave   wState = root:Packages:ARPES_LJZ:MDCIFit:LB_State

    if (curRow < 0 || curRow >= numpnts(wState))
        return -1
    endif

    wState[curRow] = newState

    Wave/Z wData = $(wPath[curRow])
    if (WaveExists(wData))
        wDisp[curRow] = LJZ_IFit_StateMark(newState) + NameOfWave(wData)
    endif

    LJZ_IFit_WriteCurrentAcceptStateToMeta()
    LJZ_IFit_RefreshMetricBox()
    return 0
End


// -------------------------
// Next unchecked row
// -------------------------
Function LJZ_IFit_FindNextUnchecked(startRow)
    Variable startRow

    Wave wState = root:Packages:ARPES_LJZ:MDCIFit:LB_State
    Variable ii
    for (ii = startRow + 1; ii < numpnts(wState); ii += 1)
        if (wState[ii] == 0)
            return ii
        endif
    endfor
    return -1
End


// ============================================================================
//  Callbacks
// ============================================================================
Function MDCIFit_LBProc(lba) : ListBoxControl
    STRUCT WMListboxAction &lba

    if (lba.eventCode != 4)
        return 0
    endif
    if (lba.row < 0)
        return 0
    endif

    NVAR curRow = root:Packages:ARPES_LJZ:MDCIFit:CurRow

    if (lba.row == curRow)
        return 0
    endif

    if (!LJZ_IFit_ConfirmLeaveIfDirty())
        LJZ_IFit_RestoreCurrentSelection()
        return 0
    endif

    MDCIFit_SelectCurrentRow(lba.row)
    return 0
End


Function MDCIFit_ModelPopProc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName
    Variable popNum
    String popStr

    LJZ_EnsureMDCIFitDF()

    NVAR modelID = root:Packages:ARPES_LJZ:MDCIFit:ModelID
    Wave p = root:Packages:ARPES_LJZ:MDCIFit:Par

    modelID = popNum

    LJZ_IFit_ApplyModelSpecials()
    LJZ_IFit_SanitizePar(p, modelID)
    LJZ_IFit_SetParamLayout()
    LJZ_IFit_SetDefaultHoldForModel()
    LJZ_IFit_SetDirty(1)
    LJZ_IFit_RefreshParamControls()
    LJZ_IFit_RefreshPreviewGraph()
    LJZ_IFit_RefreshMetricBox()

    return 0
End


Function MDCIFit_BGPopProc(ctrlName, popNum, popStr) : PopupMenuControl
    String ctrlName
    Variable popNum
    String popStr

    LJZ_EnsureMDCIFitDF()

    NVAR bg = root:Packages:ARPES_LJZ:MDCIFit:BGOrder
    bg = popNum - 1

    LJZ_IFit_SetParamLayout()
    LJZ_IFit_SetDirty(1)
    LJZ_IFit_RefreshParamControls()
    LJZ_IFit_RefreshPreviewGraph()
    LJZ_IFit_RefreshMetricBox()

    return 0
End


Function MDCIFit_SetVarProc(sva) : SetVariableControl
    STRUCT WMSetVariableAction &sva

    if (sva.eventCode == 0)
        return 0
    endif

    LJZ_EnsureMDCIFitDF()

    if (StringMatch(sva.ctrlName, "svTarget"))
        SVAR target = root:Packages:ARPES_LJZ:MDCIFit:TargetDF

        if (cmpstr(target, sva.sval) != 0)
            if (!LJZ_IFit_ConfirmLeaveIfDirty())
                LJZ_IFit_RefreshParamControls()
                return 0
            endif
        endif

        target = sva.sval
        LJZ_IFit_RebuildLB()
        LJZ_IFit_RefreshParamControls()
        LJZ_IFit_RefreshMetricBox()
        return 0
    endif

    if (StringMatch(sva.ctrlName, "svXLo"))
        NVAR xLo = root:Packages:ARPES_LJZ:MDCIFit:XLo
        xLo = sva.dval
        LJZ_IFit_SetDirty(1)
        LJZ_IFit_RefreshParamControls()
        LJZ_IFit_RefreshPreviewGraph()
        LJZ_IFit_RefreshMetricBox()
        return 0
    endif

    if (StringMatch(sva.ctrlName, "svXHi"))
        NVAR xHi = root:Packages:ARPES_LJZ:MDCIFit:XHi
        xHi = sva.dval
        LJZ_IFit_SetDirty(1)
        LJZ_IFit_RefreshParamControls()
        LJZ_IFit_RefreshPreviewGraph()
        LJZ_IFit_RefreshMetricBox()
        return 0
    endif

    Variable idx = LJZ_IFit_ParseSuffixIndex(sva.ctrlName, "svP")
    if (idx >= 0 && idx < 12)
        Wave p = root:Packages:ARPES_LJZ:MDCIFit:Par
        NVAR modelID = root:Packages:ARPES_LJZ:MDCIFit:ModelID

        p[idx] = sva.dval

        LJZ_IFit_ApplyModelSpecials()
        LJZ_IFit_SanitizePar(p, modelID)
        LJZ_IFit_SetParamLayout()
        LJZ_IFit_SetDirty(1)
        LJZ_IFit_RefreshParamControls()
        LJZ_IFit_RefreshPreviewGraph()
        LJZ_IFit_RefreshMetricBox()
        return 0
    endif

    return 0
End


Function MDCIFit_CheckProc(cba) : CheckBoxControl
    STRUCT WMCheckboxAction &cba

    if (cba.eventCode != 2)
        return 0
    endif

    LJZ_EnsureMDCIFitDF()

    if (StringMatch(cba.ctrlName, "cbCsr"))
        NVAR useCsr = root:Packages:ARPES_LJZ:MDCIFit:UseCursors
        useCsr = cba.checked
        LJZ_IFit_RefreshParamControls()
        LJZ_IFit_RefreshMetricBox()
        return 0
    endif

    Variable idx = LJZ_IFit_ParseSuffixIndex(cba.ctrlName, "cbH")
    if (idx >= 0 && idx < 12)
        Wave h = root:Packages:ARPES_LJZ:MDCIFit:Hold
        h[idx] = cba.checked

        LJZ_IFit_SetParamLayout()
        LJZ_IFit_SetDirty(1)
        LJZ_IFit_RefreshParamControls()
        LJZ_IFit_RefreshPreviewGraph()
        LJZ_IFit_RefreshMetricBox()
        return 0
    endif

    return 0
End


Function MDCIFit_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba

    if (ba.eventCode != 2)
        return 0
    endif

    ba.blockReentry = 1

    if (StringMatch(ba.ctrlName, "btnRebuild"))
        if (!LJZ_IFit_ConfirmLeaveIfDirty())
            return 0
        endif
        LJZ_IFit_RebuildLB()
        LJZ_IFit_RefreshParamControls()
        LJZ_IFit_RefreshMetricBox()
        return 0
    endif

    if (StringMatch(ba.ctrlName, "btnGuess"))
        LJZ_IFit_SetDirty(1)
        LJZ_IFit_UpdateGuessAndOverlay()
        return 0
    endif

    if (StringMatch(ba.ctrlName, "btnFit"))
        LJZ_IFit_RunFitAndSave()
        return 0
    endif

    if (StringMatch(ba.ctrlName, "btnExport"))
        LJZ_IFit_ExportSummary()
        return 0
    endif

    if (StringMatch(ba.ctrlName, "btnAccept"))
        if (LJZ_IFit_IsDirty())
            Beep
            DoAlert 0, "Current fit is stale. Please fit again before Accept."
            return 0
        endif
        LJZ_IFit_SetCurrentState(1)
        return 0
    endif

    if (StringMatch(ba.ctrlName, "btnReject"))
        if (LJZ_IFit_IsDirty())
            Beep
            DoAlert 0, "Current fit is stale. Please fit again before Reject."
            return 0
        endif
        LJZ_IFit_SetCurrentState(-1)
        return 0
    endif

    if (StringMatch(ba.ctrlName, "btnClearMark"))
        if (LJZ_IFit_IsDirty())
            Beep
            DoAlert 0, "Current fit is stale. Please fit again before changing mark."
            return 0
        endif
        LJZ_IFit_SetCurrentState(0)
        return 0
    endif

    if (StringMatch(ba.ctrlName, "btnPrev") || StringMatch(ba.ctrlName, "btnNext"))
        Wave/T wPath = root:Packages:ARPES_LJZ:MDCIFit:LB_Path
        if (numpnts(wPath) <= 0)
            return 0
        endif

        NVAR curRow = root:Packages:ARPES_LJZ:MDCIFit:CurRow

        Variable step = -1
        if (StringMatch(ba.ctrlName, "btnNext"))
            step = 1
        endif

        Variable newRow = curRow + step
        newRow = max(0, min(numpnts(wPath) - 1, newRow))

        if (newRow == curRow)
            return 0
        endif

        if (!LJZ_IFit_ConfirmLeaveIfDirty())
            return 0
        endif

        MDCIFit_SelectCurrentRow(newRow)
        return 0
    endif

    if (StringMatch(ba.ctrlName, "btnNextUnchecked"))
        NVAR curRow2 = root:Packages:ARPES_LJZ:MDCIFit:CurRow
        Variable nextRow = LJZ_IFit_FindNextUnchecked(curRow2)
        if (nextRow >= 0)
            if (!LJZ_IFit_ConfirmLeaveIfDirty())
                return 0
            endif
            MDCIFit_SelectCurrentRow(nextRow)
        else
            Beep
            DoAlert 0, "No unchecked MDC after current row."
        endif
        return 0
    endif

    return 0
End

Function LJZ_IFit_RestoreCurrentSelectionUI()
    NVAR curRow = root:Packages:ARPES_LJZ:MDCIFit:CurRow
    Wave/Z wSel = root:Packages:ARPES_LJZ:MDCIFit:LB_Sel

    if (!WaveExists(wSel))
        return -1
    endif

    wSel = 0
    if (curRow >= 0 && curRow < numpnts(wSel))
        wSel[curRow] = 1
        ListBox/Z lbMDC, win=MDCIFit_LJZ_Panel, selRow=curRow
    else
        ListBox/Z lbMDC, win=MDCIFit_LJZ_Panel, selRow=-1
    endif

    ControlUpdate/W=MDCIFit_LJZ_Panel lbMDC
    return 0
End

Function/S LJZ_IFit_TrimTrailingCR(txt)
    String txt

    do
        if (strlen(txt) <= 0)
            break
        endif
        if (cmpstr(txt[strlen(txt)-1, strlen(txt)-1], "\r") == 0)
            txt = txt[0, strlen(txt)-2]
        else
            break
        endif
    while (1)

    return txt
End

Function LJZ_IFit_TextToListWave(wTxt, wSel, txt)
    Wave/T wTxt
    Wave   wSel
    String txt

    txt = LJZ_IFit_TrimTrailingCR(txt)

    if (strlen(txt) == 0)
        Redimension/N=(1) wTxt, wSel
        wTxt[0] = ""
        wSel[0] = 0
        return 0
    endif

    String lst = ReplaceString("\r", txt, ";")
    Variable n = ItemsInList(lst, ";")
    if (n <= 0)
        n = 1
    endif

    Redimension/N=(n) wTxt, wSel
    Variable i
    for (i = 0; i < n; i += 1)
        wTxt[i] = StringFromList(i, lst, ";")
        wSel[i] = 0
    endfor

    return 0
End

Function LJZ_IFit_SaveStandardResultWaves(wData, coefW, sigmaW)
    Wave wData, coefW
    Wave/Z sigmaW

    String dfW = GetWavesDataFolder(wData, 1)
    String nm  = NameOfWave(wData)

    NVAR modelID = root:Packages:ARPES_LJZ:MDCIFit:ModelID

    String df0 = GetDataFolder(1)
    SetDataFolder $RemoveEnding(dfW, ":")

    // ---------- create scalar result waves ----------
    Make/O/N=1 $(nm + "_Peak1K")=NaN
    Make/O/N=1 $(nm + "_Peak2K")=NaN
    Make/O/N=1 $(nm + "_Peak3K")=NaN

    Make/O/N=1 $(nm + "_SigmaP1K")=NaN
    Make/O/N=1 $(nm + "_SigmaP2K")=NaN
    Make/O/N=1 $(nm + "_SigmaP3K")=NaN

    Make/O/N=1 $(nm + "_AreaP1K")=NaN
    Make/O/N=1 $(nm + "_AreaP2K")=NaN
    Make/O/N=1 $(nm + "_AreaP3K")=NaN
    Make/O/N=1 $(nm + "_AreaSum12K")=NaN

    Make/O/N=1 $(nm + "_Sep12K")=NaN

    Make/O/N=1 $(nm + "_WeffP1K")=NaN
    Make/O/N=1 $(nm + "_WeffP2K")=NaN
    Make/O/N=1 $(nm + "_WeffP3K")=NaN

    Make/O/N=1 $(nm + "_BG_c0")=NaN
    Make/O/N=1 $(nm + "_BG_c1")=NaN
    Make/O/N=1 $(nm + "_BG_c2")=NaN

    Wave wPeak1   = $(nm + "_Peak1K")
    Wave wPeak2   = $(nm + "_Peak2K")
    Wave wPeak3   = $(nm + "_Peak3K")
    Wave wSP1     = $(nm + "_SigmaP1K")
    Wave wSP2     = $(nm + "_SigmaP2K")
    Wave wSP3     = $(nm + "_SigmaP3K")
    Wave wArea1   = $(nm + "_AreaP1K")
    Wave wArea2   = $(nm + "_AreaP2K")
    Wave wArea3   = $(nm + "_AreaP3K")
    Wave wArea12  = $(nm + "_AreaSum12K")
    Wave wSep12   = $(nm + "_Sep12K")
    Wave wWeff1   = $(nm + "_WeffP1K")
    Wave wWeff2   = $(nm + "_WeffP2K")
    Wave wWeff3   = $(nm + "_WeffP3K")
    Wave wBG0     = $(nm + "_BG_c0")
    Wave wBG1     = $(nm + "_BG_c1")
    Wave wBG2     = $(nm + "_BG_c2")

    // ---------- background ----------
    if (numpnts(coefW) >= 3)
        wBG0[0] = coefW[0]
        wBG1[0] = coefW[1]
        wBG2[0] = coefW[2]
    endif

    if (modelID == 5 && numpnts(coefW) >= 12)

        Variable HA    = coefW[3]
        Variable xA    = coefW[4]
        Variable wL    = max(0, coefW[5])
        Variable wR    = max(0, coefW[6])

        Variable HS    = coefW[7]
        Variable xS    = coefW[8]
        Variable wS    = max(0, coefW[9])

        Variable etaA  = coefW[10]
        Variable resHA = max(0, coefW[11])

        Variable sL, sR, aL, aR

        wPeak1[0] = xA
        wPeak2[0] = xS

        // 非对称峰有效宽度：取左右 effective HWHM 的平均
        sL = LJZ_HWHM_eff(wL, resHA)
        sR = LJZ_HWHM_eff(wR, resHA)
        wWeff1[0] = 0.5 * (sL + sR)
        wWeff2[0] = LJZ_HWHM_eff(wS, resHA)

        // 非对称峰面积：左右各半边近似平均
        aL = LJZ_PVArea_FromCoef(HA, wL, etaA, resHA)
        aR = LJZ_PVArea_FromCoef(HA, wR, etaA, resHA)
        wArea1[0] = 0.5 * (aL + aR)

        wArea2[0] = LJZ_PVArea_FromCoef(HS, wS, etaA, resHA)

        wArea12[0] = wArea1[0] + wArea2[0]
        wSep12[0]  = abs(xS - xA)

        if (WaveExists(sigmaW) && numpnts(sigmaW) >= 12)
            wSP1[0] = sigmaW[4]
            wSP2[0] = sigmaW[8]
        endif

    elseif (modelID == 2 && numpnts(coefW) >= 12)

        Variable H1    = coefW[3]
        Variable x1    = coefW[4]
        Variable w1f   = max(0, coefW[5])
        Variable eta1  = coefW[6]

        Variable H2    = coefW[7]
        Variable x2    = coefW[8]
        Variable w2f   = max(0, coefW[9])
        Variable eta2  = coefW[10]

        Variable resH2 = max(0, coefW[11])

        wPeak1[0] = min(x1, x2)
        wPeak2[0] = max(x1, x2)

        if (x1 <= x2)
            wWeff1[0] = LJZ_HWHM_eff(w1f, resH2)
            wWeff2[0] = LJZ_HWHM_eff(w2f, resH2)
            wArea1[0] = LJZ_PVArea_FromCoef(H1, w1f, eta1, resH2)
            wArea2[0] = LJZ_PVArea_FromCoef(H2, w2f, eta2, resH2)

            if (WaveExists(sigmaW) && numpnts(sigmaW) >= 12)
                wSP1[0] = sigmaW[4]
                wSP2[0] = sigmaW[8]
            endif
        else
            wWeff1[0] = LJZ_HWHM_eff(w2f, resH2)
            wWeff2[0] = LJZ_HWHM_eff(w1f, resH2)
            wArea1[0] = LJZ_PVArea_FromCoef(H2, w2f, eta2, resH2)
            wArea2[0] = LJZ_PVArea_FromCoef(H1, w1f, eta1, resH2)

            if (WaveExists(sigmaW) && numpnts(sigmaW) >= 12)
                wSP1[0] = sigmaW[8]
                wSP2[0] = sigmaW[4]
            endif
        endif

        wArea12[0] = wArea1[0] + wArea2[0]
        wSep12[0]  = abs(wPeak2[0] - wPeak1[0])

    else
        // 1PV / 1Lor / 1Gau 都统一写到 Peak3K 系列
        if (numpnts(coefW) >= 8)
            Variable H3    = coefW[3]
            Variable x3    = coefW[4]
            Variable w3f   = max(0, coefW[5])
            Variable eta3  = coefW[6]
            Variable res3  = max(0, coefW[7])

            wPeak3[0] = x3
            wWeff3[0] = LJZ_HWHM_eff(w3f, res3)
            wArea3[0] = LJZ_PVArea_FromCoef(H3, w3f, eta3, res3)

            if (WaveExists(sigmaW) && numpnts(sigmaW) >= 8)
                wSP3[0] = sigmaW[4]
            endif
        endif
    endif

    SetDataFolder $df0
    return 0
End

// 非对称 pseudo-Voigt：左右两侧使用不同 HWHM
Function LJZ_AsymPseudoVoigtH(H, x, x0, sL, sR, eta)
    Variable H, x, x0, sL, sR, eta

    if (sL <= 0)
        sL = 1e-12
    endif
    if (sR <= 0)
        sR = 1e-12
    endif
    if (eta < 0)
        eta = 0
    elseif (eta > 1)
        eta = 1
    endif

    if (x <= x0)
        return LJZ_PseudoVoigtH(H, x, x0, sL, eta)
    else
        return LJZ_PseudoVoigtH(H, x, x0, sR, eta)
    endif
End

// 非对称峰 + 对称峰，共用 eta 和 resH
// p0 c0
// p1 c1
// p2 c2
// p3 H1
// p4 x1
// p5 wL1_free
// p6 wR1_free
// p7 H2
// p8 x2
// p9 w2_free
// p10 eta
// p11 resH
Function asympv_plus_pv_ljz(w, x) : FitFunc
    Wave w
    Variable x

    Variable c0   = w[0]
    Variable c1   = w[1]
    Variable c2   = w[2]

    Variable H1   = w[3]
    Variable x1   = w[4]
    Variable wL1f = max(1e-4, abs(w[5]))
    Variable wR1f = max(1e-4, abs(w[6]))

    Variable H2   = w[7]
    Variable x2   = w[8]
    Variable w2f  = max(1e-4, abs(w[9]))

    Variable eta  = min(1, max(0, w[10]))
    Variable resH = max(1e-4, abs(w[11]))

    Variable sL1 = LJZ_HWHM_eff(wL1f, resH)
    Variable sR1 = LJZ_HWHM_eff(wR1f, resH)
    Variable s2  = LJZ_HWHM_eff(w2f,  resH)

    Variable bg = c0 + c1*x + c2*x*x

    return bg \
        + LJZ_AsymPseudoVoigtH(H1, x, x1, sL1, sR1, eta) \
        + LJZ_PseudoVoigtH(H2, x, x2, s2, eta)
End

Function LJZ_IFit_ClearGraphTracesByWin(winPath)
    String winPath

    String trList = TraceNameList(winPath, ";", 1)
    Variable i, n
    n = ItemsInList(trList, ";")

    for (i = 0; i < n; i += 1)
        String tr = StringFromList(i, trList, ";")
        if (strlen(tr) > 0)
            RemoveFromGraph/Z/W=$winPath $tr
        endif
    endfor

    return 0
End