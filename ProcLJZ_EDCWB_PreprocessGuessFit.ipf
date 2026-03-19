#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  LJZ_EDCWB Preprocess + Guess + Fit
//  只负责：
//    1) preprocess work waves
//    2) auto guess
//    3) guess curve preview
//    4) approximate fit engine
//    5) batch fit
//
//  默认兼容 EDCExtract 输出：
//    runDF: edc_raw_0, edc_show_0, ...
// ============================================================================


// ============================================================================
//  Section 0. TMP helpers
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

    String nm = ""
    Variable p

    p = strsearch(srcWavePath, ":", Inf)
    if (p >= 0)
        nm = srcWavePath[p + 1, Inf]
    endif
    if (strlen(nm) == 0)
        nm = "unnamed"
    endif

    nm = ReplaceString(" ", nm, "_")
    nm = ReplaceString("-", nm, "_")
    nm = ReplaceString(".", nm, "_")

    return "EDCWB_" + nm + "_" + suffix
End


// ============================================================================
//  Section 1. basic source / axis helpers
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

    if (DimSize(w, 1) > 0 || DimSize(w, 2) > 0 || DimSize(w, 3) > 0)
        return 0
    endif

    return 1
End

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

Function LJZ_EDCWB_IndexToX(w, idx)
    Wave w
    Variable idx

    return DimOffset(w, 0) + idx * DimDelta(w, 0)
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
//  Section 2. smoothing / normalization
// ============================================================================

Function LJZ_EDCWB_ApplySmoothInPlace(w, method, p1, p2)
    Wave w
    Variable method, p1, p2

    Variable npts = numpnts(w)
    if (npts <= 2)
        return 0
    endif

    Variable win = round(abs(p1))
    if (win < 1)
        win = 1
    endif

    if (method == 0)
        return 0
    endif

    if (method == 1)
        Smooth win, w
        return 0
    endif

    if (method == 2)
        Variable poly = round(abs(p2))
        if (poly < 2)
            poly = 2
        endif
        if (win < poly + 2)
            win = poly + 2
        endif
        Smooth/S=(poly) win, w
        return 0
    endif

    if (method == 3)
        Variable cutoff = abs(p1)
        cutoff = min(max(cutoff, 0.001), 0.499)
        Smooth/BLPF cutoff, w
        return 0
    endif

    return 0
End

Function LJZ_EDCWB_WaveAbsMax(w)
    Wave w

    if (numpnts(w) <= 0)
        return NaN
    endif

    WaveStats/Q w
    return max(abs(V_max), abs(V_min))
End

Function LJZ_EDCWB_WaveTailMeanAbs(w, frac)
    Wave w
    Variable frac

    Variable n = numpnts(w)
    if (n <= 0)
        return NaN
    endif

    LJZ_EDCWB_EnsureTmpDF()

    Variable nTail = round(n * frac)
    if (nTail < 3)
        nTail = min(3, n)
    endif

    Variable i0 = n - nTail
    if (i0 < 0)
        i0 = 0
    endif

    Duplicate/O/R=[i0, n - 1] w, $(LJZ_EDCWB_TmpDF() + ":__tail_tmp")
    Wave tmp = $(LJZ_EDCWB_TmpDF() + ":__tail_tmp")
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

    LJZ_EDCWB_EnsureTmpDF()

    Duplicate/O/R=[iLo, iHi] w, $(LJZ_EDCWB_TmpDF() + ":__roi_tmp")
    Wave tmp = $(LJZ_EDCWB_TmpDF() + ":__roi_tmp")

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


// ============================================================================
//  Section 3. work-wave builders
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

    if (doSmooth)
        NVAR smEn     = $(LJZ_EDCWB_BaseDF() + ":SmoothEnable")
        NVAR smMethod = $(LJZ_EDCWB_BaseDF() + ":SmoothMethod")
        NVAR smP1     = $(LJZ_EDCWB_BaseDF() + ":SmoothParam1")
        NVAR smP2     = $(LJZ_EDCWB_BaseDF() + ":SmoothParam2")

        if (smEn && smMethod > 0)
            LJZ_EDCWB_ApplySmoothInPlace(out, smMethod, smP1, smP2)
        endif
    endif

    if (doSym)
        NVAR eEF = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
        out = out(x) + out(2 * eEF - x)
    endif

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

    NVAR eModel  = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR smGuess = $(LJZ_EDCWB_BaseDF() + ":UseSmoothForGuess")

    Variable doSmooth = (smGuess != 0)
    Variable doSym    = LJZ_EDCWB_ModelSuggestSymMode(eModel)
    Variable doNorm   = 1

    return LJZ_EDCWB_BuildWorkWave(srcWavePath, doSmooth, doSym, doNorm, "guessInput")
End

Function/WAVE LJZ_EDCWB_GetFitInputWave(srcWavePath)
    String srcWavePath

    LJZ_EDCWB_EnsureDF()

    NVAR eModel  = $(LJZ_EDCWB_BaseDF() + ":EditModelID")
    NVAR fitOnSm = $(LJZ_EDCWB_BaseDF() + ":FitOnSmooth")

    Variable doSmooth = (fitOnSm != 0)
    Variable doSym    = LJZ_EDCWB_ModelSuggestSymMode(eModel)
    Variable doNorm   = 1

    return LJZ_EDCWB_BuildWorkWave(srcWavePath, doSmooth, doSym, doNorm, "fitInput")
End

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


// ============================================================================
//  Section 4. low-level stats helpers
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

    LJZ_EDCWB_EnsureTmpDF()

    Duplicate/O/R=[iLo, iHi] w, $(LJZ_EDCWB_TmpDF() + ":__mean_tmp")
    Wave tmp = $(LJZ_EDCWB_TmpDF() + ":__mean_tmp")
    WaveStats/Q tmp
    Variable v = V_avg
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
        bg0 = 0
        bg1 = 0
        return 0
    endif

    bg1 = (yR - yL) / (xR - xL)
    bg0 = yL - bg1 * xL

    return 0
End


// ============================================================================
//  Section 5. model-specific auto guess
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

    // SinglePeakFDConv stores w as FWHM; this half-height-width estimate yields FWHM.
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

    LJZ_EDCWB_SetModel(modelID)

    Wave/Z wIn = LJZ_EDCWB_GetGuessInputWave(srcWavePath)
    if (!WaveExists(wIn))
        return -1
    endif

    Wave wPar = $(LJZ_EDCWB_BaseDF() + ":EditPar")

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


// ============================================================================
//  Section 6. preview guess curve
// ============================================================================

Function LJZ_EDCWB_FDValue(x, T, EF)
    Variable x, T, EF

    Variable kB = 8.617333262e-5

    if (T <= 0)
        if (x < EF)
            return 1
        else
            return 0
        endif
    endif

    Variable arg = (x - EF) / (kB * T)

    if (arg > 80)
        return 0
    endif
    if (arg < -80)
        return 1
    endif

    return 1 / (exp(arg) + 1)
End

// SinglePeakFDConv chain convention:
//   w is always FWHM for both auto-guess, preview, and true fit function.
Function LJZ_EDCWB_LorentzValue(x, x0, w)
    Variable x, x0, w

    Variable gamma
    if (w <= 0)
        w = 1e-4
    endif

    gamma = max(0.5 * w, 1e-4)
    return 1 / (1 + ((x - x0) / gamma)^2)
End

// SinglePeakFDConv chain convention:
//   w is always FWHM for both auto-guess, preview, and true fit function.
Function LJZ_EDCWB_GaussValue(x, x0, w)
    Variable x, x0, w

    Variable sigma
    if (w <= 0)
        w = 1e-4
    endif

    sigma = max(w / (2 * sqrt(2 * ln(2))), 1e-4)
    return exp(-0.5 * ((x - x0) / sigma)^2)
End

// Gap models keep their Gaussian-width parameter as sigma to minimize behavior change.
Function LJZ_EDCWB_GaussValueSigma(x, x0, sigma)
    Variable x, x0, sigma

    if (sigma <= 0)
        sigma = 1e-4
    endif

    return exp(-0.5 * ((x - x0) / sigma)^2)
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

    Variable bg0, bg1, A, x0, w, eta, T, EF, Delta, Gamma

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
        eta = min(1, max(0, eta))

        out = (bg0 + bg1 * x) + A * (eta * LJZ_EDCWB_LorentzValue(x, x0, w) + (1 - eta) * LJZ_EDCWB_GaussValue(x, x0, w))
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

        out = (bg0 + bg1 * x) + A * (LJZ_EDCWB_GaussValueSigma(x, EF - Delta, Gamma) + 0.7 * LJZ_EDCWB_GaussValueSigma(x, EF + Delta, Gamma))
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

        out = (bg0 + bg1 * x) + A * (LJZ_EDCWB_GaussValueSigma(x, x0 - Delta, Gamma) + LJZ_EDCWB_GaussValueSigma(x, x0 + Delta, Gamma))
        return out
    endif

    out = NaN
    return out
End

Function LJZ_EDCWB_AutoGuessAndSave(srcWavePath, modelID)
    String srcWavePath
    Variable modelID

    Variable ok = LJZ_EDCWB_AutoInitGuess(srcWavePath, modelID)
    if (ok != 0)
        return ok
    endif

    Wave wPar = $(LJZ_EDCWB_BaseDF() + ":EditPar")
    Wave/Z wGuess = LJZ_EDCWB_BuildGuessCurveFromPar(srcWavePath, wPar)
    if (!WaveExists(wGuess))
        return -1
    endif

    LJZ_EDCWB_SaveCurrentEditSnapshot(srcWavePath)
    LJZ_EDCWB_SaveGuessCurve(srcWavePath, wGuess)
    return 0
End


// ============================================================================
//  Section 7. fit evaluators
// ============================================================================

Function LJZ_EDCWB_FitFDValue(x, T, EF)
    Variable x, T, EF

    Variable kB = 8.617333262e-5
    if (T <= 0)
        if (x < EF)
            return 1
        else
            return 0
        endif
    endif

    Variable arg = (x - EF) / (kB * T)
    if (arg > 80)
        return 0
    endif
    if (arg < -80)
        return 1
    endif

    return 1 / (exp(arg) + 1)
End

// SinglePeakFDConv chain convention:
//   w is always FWHM for both auto-guess, preview, and true fit function.
Function LJZ_EDCWB_FitLor(x, x0, w)
    Variable x, x0, w

    Variable gamma
    if (w <= 0)
        w = 1e-4
    endif

    gamma = max(0.5 * w, 1e-4)
    return 1 / (1 + ((x - x0) / gamma)^2)
End

// SinglePeakFDConv chain convention:
//   w is always FWHM for both auto-guess, preview, and true fit function.
Function LJZ_EDCWB_FitGau(x, x0, w)
    Variable x, x0, w

    Variable sigma
    if (w <= 0)
        w = 1e-4
    endif

    sigma = max(w / (2 * sqrt(2 * ln(2))), 1e-4)
    return exp(-0.5 * ((x - x0) / sigma)^2)
End

Function LJZ_EDCWB_FitGauSigma(x, x0, sigma)
    Variable x, x0, sigma

    if (sigma <= 0)
        sigma = 1e-4
    endif

    return exp(-0.5 * ((x - x0) / sigma)^2)
End

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

    Variable edge1 = LJZ_EDCWB_FitGauSigma(x, EF - Delta, Gamma)
    Variable edge2 = 0.7 * LJZ_EDCWB_FitGauSigma(x, EF + Delta, Gamma)
    Variable fd    = LJZ_EDCWB_FitFDValue(x, T, EF)

    return (bg0 + bg1 * x + A * (edge1 + edge2)) * fd
End

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

    Variable p1 = LJZ_EDCWB_FitGauSigma(x, x0 - Delta, Gamma)
    Variable p2 = LJZ_EDCWB_FitGauSigma(x, x0 + Delta, Gamma)

    return bg0 + bg1 * x + A * (p1 + p2)
End


// ============================================================================
//  Section 8. fit helpers
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

    Variable i, nPar = LJZ_EDCWB_ModelNPar(modelID)

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
    // fitX 是给 FuncFit /X= 使用的显式 x wave，不是仅靠 scaling 的占位波。
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

// 当传入显式 x wave 时，模型评估必须使用 wave values 本身。
// 不能假设 x 轴一定是等间距 scaling。
Function LJZ_EDCWB_EvalModelWave(modelID, wXRef, wCoef, wOut)
    Variable modelID
    Wave wXRef, wCoef, wOut

    Variable n = numpnts(wXRef)
    if (n != numpnts(wOut))
        return -1
    endif

    Variable i, xv
    for (i = 0; i < n; i += 1)
        if (i >= numpnts(wXRef))
            return -1
        endif
        xv = wXRef[i]

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

Function LJZ_EDCWB_RMSEBetweenWaves(wA, wB)
    Wave wA, wB

    Variable n = min(numpnts(wA), numpnts(wB))
    if (n <= 0)
        return NaN
    endif

    LJZ_EDCWB_EnsureTmpDF()

    Make/D/O/N=(n) $(LJZ_EDCWB_TmpDF() + ":__rmse_tmp")
    Wave tmp = $(LJZ_EDCWB_TmpDF() + ":__rmse_tmp")
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

Function LJZ_EDCWB_SaveFitResultGeneric(srcWavePath, modelID, wCoefActive, wSigmaActive, fitOK, chiSq)
    String srcWavePath
    Variable modelID, fitOK, chiSq
    Wave wCoefActive, wSigmaActive

    LJZ_EDCWB_EnsureDF()
    LJZ_EDCWB_EnsureTmpDF()

    Wave wEditPar = $(LJZ_EDCWB_BaseDF() + ":EditPar")

    LJZ_EDCWB_CopyActiveCoefToEditPar(modelID, wCoefActive, wEditPar)
    LJZ_EDCWB_SanitizeParamWave(modelID, wEditPar)
    LJZ_EDCWB_SyncParToAuxState()

    Make/D/O/N=12 $(LJZ_EDCWB_TmpDF() + ":fitcoef12")
    Make/D/O/N=12 $(LJZ_EDCWB_TmpDF() + ":fitsigma12")
    Make/D/O/N=16 $(LJZ_EDCWB_TmpDF() + ":fitinfo16")
    Wave fitcoef12  = $(LJZ_EDCWB_TmpDF() + ":fitcoef12")
    Wave fitsigma12 = $(LJZ_EDCWB_TmpDF() + ":fitsigma12")
    Wave fitinfo16  = $(LJZ_EDCWB_TmpDF() + ":fitinfo16")

    fitcoef12 = NaN
    fitcoef12 = wEditPar[p]

    LJZ_EDCWB_CopySigmaToLen12(modelID, wSigmaActive, fitsigma12)
    fitinfo16 = NaN

    NVAR eXLo    = $(LJZ_EDCWB_BaseDF() + ":EditXLo")
    NVAR eXHi    = $(LJZ_EDCWB_BaseDF() + ":EditXHi")
    NVAR eTemp   = $(LJZ_EDCWB_BaseDF() + ":EditTemperature")
    NVAR eEF     = $(LJZ_EDCWB_BaseDF() + ":EditEFermi")
    NVAR eRes    = $(LJZ_EDCWB_BaseDF() + ":EditResolution")
    NVAR eNorm   = $(LJZ_EDCWB_BaseDF() + ":EditNormMode")
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

    fitinfo16[LJZ_EDCWB_FI_ChiSq()] = chiSq

    LJZ_EDCWB_SaveFitCurve(srcWavePath, fitFull, resFull)
    LJZ_EDCWB_SaveFitVectors(srcWavePath, fitcoef12, fitsigma12, fitinfo16)

    return 0
End


// ============================================================================
//  Section 9. main fitting entry
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

    Wave/Z wGuess = LJZ_EDCWB_BuildGuessCurveFromPar(srcWavePath, wEditPar)
    if (WaveExists(wGuess))
        LJZ_EDCWB_SaveCurrentEditSnapshot(srcWavePath)
        LJZ_EDCWB_SaveGuessCurve(srcWavePath, wGuess)
    endif

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
    if (V_FitError != 0)
        fitOK = 0
    endif

    Variable chiSq = NaN
    if (fitOK)
        chiSq = V_chisq
    endif

    LJZ_EDCWB_SaveFitResultGeneric(srcWavePath, modelID, coefActive, sigmaActive, fitOK, chiSq)

    if (!fitOK)
        return -2
    endif

    LJZ_EDCWB_MarkDirty(0)
    return 0
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

    LJZ_EDCWB_ClearStoredFitOutputs(srcWavePath)
    return LJZ_EDCWB_DoFitModelApprox(srcWavePath, modelID)
End

Function LJZ_EDCWB_DoFitCurrent()
    LJZ_EDCWB_EnsureDF()

    SVAR sPath  = $(LJZ_EDCWB_BaseDF() + ":CurWavePath")
    NVAR eModel = $(LJZ_EDCWB_BaseDF() + ":EditModelID")

    if (strlen(sPath) == 0)
        return -1
    endif

    return LJZ_EDCWB_DoFitWave(sPath, eModel)
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
