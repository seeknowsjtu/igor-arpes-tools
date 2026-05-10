#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  LJZ_EDCWB Part 2 : Model + Fit Engine
//
//  Depends on:
//    - LJZ_EDCWB Part 1 : Core data model + Persistence
//
//  Responsibilities:
//    1) Sanitize Work_* edit-state (par, hold, T/EF/res/normMode, ROI).
//    2) Provide three FitFunc (SinglePeakFD, EffectiveGap, SymGap) and
//       the physical kernels they depend on.
//    3) Assemble Work_* -> flat coef vector + hold mask string for FuncFit.
//    4) Build guess curve, run FuncFit with try/catch, compute metrics,
//       save fit record (and only on success, the edit-state).
//    5) Provide semantic edit actions used by Part 3 callbacks.
//    6) Auto-init: estimate BG from ROI edges, set reasonable par defaults.
//    7) LoadCurrentToWork: load saved edit-state, sanitize, or auto-init.
//
//  Behavioral guarantees (DO NOT VIOLATE):
//    A. The edit-state on disk is touched ONLY by:
//         - LJZ_EDCWB_SaveWorkToDisk        (explicit user save)
//         - LJZ_EDCWB_RunFit on success     (post-fit canonical save)
//       BuildGuess, AutoInit, Sanitize, LoadCurrentToWork NEVER write
//       the edit-state. This prevents "preview silently overwrites
//       saved init" regressions.
//    B. After LoadCurrentToWork(), Dirty == 0 only if the loaded edit-state
//       survived sanitation unchanged AND a valid fit record exists.
//       Otherwise Dirty == 1.
//    C. AutoInit refreshes par defaults and ROI only when missing; it does
//       not clobber a non-NaN user ROI.
//    D. RunFit requires finiteCount >= max(2*P, P+10), where P = nPar.
//    E. FuncFit is always wrapped in try/catch + AbortOnRTE. If it throws,
//       old fit products remain intact and Dirty stays 1.
//    F. During FuncFit, Active_modelID is the frozen snapshot used by
//       the FitFuncs to look up physics. Nothing else may write it.
// ============================================================================


// ============================================================================
//  Section 0. Fit-engine active state
// ============================================================================

// Active_modelID is the model frozen during a FuncFit call.
// Written by CopyActiveModeFromWork() immediately before FuncFit; never
// changed while FuncFit is in flight.
Function LJZ_EDCWB_EnsureFitEngineState()
    LJZ_EDCWB_EnsureBaseDF()

    String base = LJZ_EDCWB_BaseDF()

    NVAR/Z activeMID = $(base + ":Active_modelID")
    if (!NVAR_Exists(activeMID))
        Variable/G $(base + ":Active_modelID") = LJZ_EDCWB_Model_SinglePeakFD()
    endif

    Wave/Z activeSigma = $(base + ":Active_lastSigma")
    if (!WaveExists(activeSigma))
        Make/O/N=0 $(base + ":Active_lastSigma") = NaN
    endif

    return 0
End

Function LJZ_EDCWB_CopyActiveModeFromWork()
    LJZ_EDCWB_EnsureFitEngineState()
    NVAR activeMID = $(LJZ_EDCWB_BaseDF() + ":Active_modelID")
    activeMID = LJZ_EDCWB_WorkGetModelID()
    return 0
End


// ============================================================================
//  Section 1. Physical constants and utility limits
// ============================================================================

Function LJZ_EDCWB_kB_eV()
    // Boltzmann constant in eV/K
    return 8.617333e-5
End

Function LJZ_EDCWB_MinRes()
    // Minimum energy resolution FWHM (eV)
    return 1e-5
End

Function LJZ_EDCWB_MinGamma()
    return 1e-5
End

Function LJZ_EDCWB_MinDelta()
    return 0
End

Function LJZ_EDCWB_MinWidth()
    // Minimum pseudo-Voigt FWHM (eV)
    return 1e-5
End

Function LJZ_EDCWB_UnitClampEps()
    // Epsilon for clamping asin argument to [-1, 1]
    return 1e-8
End

Function LJZ_EDCWB_NConvPts()
    // Number of convolution integration steps (odd integer for symmetry)
    return 201
End

Function LJZ_EDCWB_NConvSigma()
    // Half-width of Gaussian convolution kernel in units of sigma
    return 4.0
End

Function LJZ_EDCWB_ClampFiniteNonneg(x, fallback)
    Variable x, fallback
    if (numtype(x) != 0)
        return max(0, fallback)
    endif
    return max(0, x)
End

Function LJZ_EDCWB_ClampFinitePositive(x, fallback, minVal)
    Variable x, fallback, minVal
    Variable v = x
    if (numtype(v) != 0)
        v = fallback
    endif
    if (numtype(v) != 0)
        v = minVal
    endif
    if (v < minVal)
        v = minVal
    endif
    return v
End


// ============================================================================
//  Section 2. Kernel functions
// ============================================================================

// Fermi-Dirac distribution.  T in K, E and EF in eV.
// Returns value in [0, 1].
Function LJZ_EDCWB_FD(E, T, EF)
    Variable E, T, EF

    Variable kT = LJZ_EDCWB_kB_eV() * T
    if (numtype(kT) != 0 || kT <= 0)
        // T=0 limit: step function
        if (E <= EF)
            return 1
        endif
        return 0
    endif

    Variable arg = (E - EF) / kT
    // Clamp to avoid overflow; beyond ±700 the result is 0 or 1 exactly.
    if (arg > 700)
        return 0
    endif
    if (arg < -700)
        return 1
    endif
    return 1.0 / (exp(arg) + 1.0)
End

// Gaussian kernel, normalized so that integral = 1.
// sigma = FWHM / (2*sqrt(2*ln2))
Function LJZ_EDCWB_GaussKernel(E, sigma)
    Variable E, sigma

    if (numtype(sigma) != 0 || sigma <= 0)
        return 0
    endif
    return exp(-0.5 * (E / sigma)^2) / (sigma * sqrt(2 * pi))
End

// Pseudo-Voigt: eta * Lor + (1-eta) * Gau.  w is FWHM.
// Returns the value at position (E - x0).
Function LJZ_EDCWB_PVKernel(E, x0, w, eta)
    Variable E, x0, w, eta

    if (numtype(w) != 0 || w <= 0)
        w = LJZ_EDCWB_MinWidth()
    endif
    eta = min(1, max(0, eta))

    Variable u = (E - x0) / (w / 2)
    Variable lor = 1.0 / (1.0 + u * u)
    Variable gau = exp(-ln(2) * u * u)
    return eta * lor + (1.0 - eta) * gau
End

// 1D Gaussian convolution of a pre-evaluated curve array with a Gaussian of
// FWHM = res (eV).  The x-axis of the array is given by x0 + i*dx.
// Works in-place via a FREE output wave.  Writes result into outWave.
Function LJZ_EDCWB_ConvolveWithGauss(inWave, res, outWave)
    Wave inWave, outWave

    Variable n = numpnts(inWave)
    Redimension/N=(n) outWave
    outWave = 0
    CopyScales inWave, outWave

    Variable sigma = res / (2.0 * sqrt(2.0 * ln(2)))
    if (numtype(sigma) != 0 || sigma <= LJZ_EDCWB_MinRes())
        outWave = inWave
        return 0
    endif

    Variable dx = abs(DimDelta(inWave, 0))
    if (numtype(dx) != 0 || dx <= 0)
        dx = 1
    endif

    Variable halfW = LJZ_EDCWB_NConvSigma() * sigma
    Variable nKern = round(2.0 * halfW / dx)
    if (mod(nKern, 2) == 0)
        nKern += 1
    endif
    if (nKern < 3)
        nKern = 3
    endif

    Make/FREE/N=(nKern) kern
    Variable center = (nKern - 1) / 2
    Variable norm = 0
    Variable k
    for (k = 0; k < nKern; k += 1)
        Variable kE = (k - center) * dx
        kern[k] = exp(-0.5 * (kE / sigma)^2)
        norm += kern[k]
    endfor
    if (norm > 0)
        kern /= norm
    endif

    outWave = inWave
    Convolve/A kern, outWave

    return 0
End


// ============================================================================
//  Section 3. Model spectral functions (before convolution)
//
//  These return a spectrum over a wave's x-axis. Convolution is done outside.
//
//  Model 1 – SinglePeakFD:
//    A(E) = bg0 + bg1*(E-EF) + A * PV(E, x0, w, eta)
//    I(E) = A(E) * FD(E, T, EF)
//    convolved with Gaussian of FWHM=res.
//    Parameters: [0]=bg0 [1]=bg1 [2]=A [3]=x0 [4]=w [5]=eta [6]=T [7]=EF [8]=res
//
//  Model 2 – EffectiveGap:
//    A(E) = spectral function = bg0 + bg1*(E-EF) + A * Re[E / sqrt(E'^2 - Delta^2 + i*Gamma*E')]
//    where E' = E - EF
//    I(E) = A(E) * FD(E, T, EF)
//    convolved with Gaussian of FWHM=res.
//    Parameters: [0]=bg0 [1]=bg1 [2]=A [3]=Delta [4]=Gamma [5]=T [6]=EF [7]=res
//
//  Model 3 – SymGap:
//    Symmetrized (no FD):
//    S(E) = bg0 + bg1*E + A * [ Re[E'/sqrt(E'^2-Delta^2+i*Gamma*E')] + Re[-E'/sqrt(E'^2-Delta^2-i*Gamma*E')] ]
//    where E' = E - x0
//    Parameters: [0]=bg0 [1]=bg1 [2]=A [3]=Delta [4]=Gamma [5]=x0
// ============================================================================

// Effective-gap spectral weight at one energy point.
// Returns Re[ E' / sqrt(E'^2 - Delta^2 + i*Gamma*E') ]
// with clamping for numerical safety.
Function LJZ_EDCWB_EffGapWeight(Ep, Delta, Gamma)
    Variable Ep, Delta, Gamma

    if (numtype(Ep) != 0 || numtype(Delta) != 0 || numtype(Gamma) != 0)
        return 0
    endif

    Variable D2 = Delta * Delta
    Variable Gabs = abs(Gamma)
    if (Gabs < LJZ_EDCWB_MinGamma())
        Gabs = LJZ_EDCWB_MinGamma()
    endif

    // Complex argument z = Ep^2 - Delta^2 + i*Gamma*Ep
    // Re(z) = Ep^2 - Delta^2,  Im(z) = Gamma*Ep
    Variable reZ = Ep * Ep - D2
    Variable imZ = Gabs * Ep

    // sqrt(z): modulus and half-angle
    Variable modZ = sqrt(reZ * reZ + imZ * imZ)
    if (modZ < 1e-30)
        return 0
    endif
    Variable sqrtMod = sqrt(modZ)
    Variable halfArg = 0.5 * atan2(imZ, reZ)
    Variable reSqrtZ = sqrtMod * cos(halfArg)
    Variable imSqrtZ = sqrtMod * sin(halfArg)

    // w = Ep / sqrt(z)  =>  Re(w) = Ep * Re(1/sqrt(z))
    // 1/sqrt(z) = conj(sqrt(z)) / |sqrt(z)|^2 = conj(sqrt(z)) / |z|^(1/2)
    Variable denom = reSqrtZ * reSqrtZ + imSqrtZ * imSqrtZ
    if (denom < 1e-60)
        return 0
    endif
    Variable reW = Ep * reSqrtZ / denom

    return reW
End

// Evaluate spectral intensity curve for a given model over an entire wave.
// Writes unsmoothed spectrum into specWave; caller must then convolve.
Function LJZ_EDCWB_EvalSpectrumNoConv_ModelID(wData, coef, specWave, modelID)
    Wave wData, coef, specWave
    Variable modelID

    Variable nPts = numpnts(wData)
    if (numpnts(specWave) != nPts)
        Redimension/N=(nPts) specWave
    endif
    CopyScales wData, specWave

    Variable m = modelID

    Variable i, E, val
    Variable bg0, bg1, A, T, EF, res
    Variable x0, w, eta, Delta, Gamma, Ep, aw, Ep2, wPlus, wMinus

    if (m == LJZ_EDCWB_Model_SinglePeakFD())
        bg0  = coef[0]
        bg1  = coef[1]
        A    = coef[2]
        x0   = coef[3]
        w    = max(LJZ_EDCWB_MinWidth(), coef[4])
        eta  = min(1, max(0, coef[5]))
        T    = max(0, coef[6])
        EF   = coef[7]

        for (i = 0; i < nPts; i += 1)
            E = DimOffset(wData, 0) + i * DimDelta(wData, 0)
            val = (bg0 + bg1 * (E - EF) + A * LJZ_EDCWB_PVKernel(E, x0, w, eta)) * LJZ_EDCWB_FD(E, T, EF)
            specWave[i] = val
        endfor

    elseif (m == LJZ_EDCWB_Model_EffectiveGap())
        bg0   = coef[0]
        bg1   = coef[1]
        A     = max(0, coef[2])
        Delta = max(LJZ_EDCWB_MinDelta(), coef[3])
        Gamma = max(LJZ_EDCWB_MinGamma(), coef[4])
        T     = max(0, coef[5])
        EF    = coef[6]

        for (i = 0; i < nPts; i += 1)
            E = DimOffset(wData, 0) + i * DimDelta(wData, 0)
            Ep = E - EF
            aw = A * LJZ_EDCWB_EffGapWeight(Ep, Delta, Gamma)
            val = (bg0 + bg1 * Ep + aw) * LJZ_EDCWB_FD(E, T, EF)
            specWave[i] = val
        endfor

    elseif (m == LJZ_EDCWB_Model_SymGap())
        bg0   = coef[0]
        bg1   = coef[1]
        A     = max(0, coef[2])
        Delta = max(LJZ_EDCWB_MinDelta(), coef[3])
        Gamma = max(LJZ_EDCWB_MinGamma(), coef[4])
        x0    = coef[5]

        for (i = 0; i < nPts; i += 1)
            E = DimOffset(wData, 0) + i * DimDelta(wData, 0)
            Ep2 = E - x0
            wPlus  = LJZ_EDCWB_EffGapWeight( Ep2, Delta, Gamma)
            wMinus = LJZ_EDCWB_EffGapWeight(-Ep2, Delta, Gamma)
            val = bg0 + bg1 * E + A * (wPlus + wMinus)
            specWave[i] = val
        endfor

    else
        specWave = NaN
    endif

    return 0
End

Function LJZ_EDCWB_EvalSpectrumNoConv(wData, coef, specWave)
    Wave wData, coef, specWave
    return LJZ_EDCWB_EvalSpectrumNoConv_ModelID(wData, coef, specWave, LJZ_EDCWB_WorkGetModelID())
End

// Full model evaluation with convolution. Output written into outWave.
Function LJZ_EDCWB_EvalModelFull_ModelID(wData, coef, outWave, modelID)
    Wave wData, coef, outWave
    Variable modelID

    Variable nPts = numpnts(wData)
    if (numpnts(outWave) != nPts)
        Redimension/N=(nPts) outWave
    endif
    CopyScales wData, outWave

    Variable m = modelID
    Variable nPar = LJZ_EDCWB_ModelNPar(m)
    if (numpnts(coef) < nPar)
        outWave = NaN
        return -1
    endif

    // For SymGap there is no FD; Gaussian convolution still applies if res exists.
    // SinglePeakFD and EffectiveGap always have res as their last parameter.
    // SymGap has 6 params and no res slot; we skip convolution for it.
    Variable doConv = (m == LJZ_EDCWB_Model_SinglePeakFD() || m == LJZ_EDCWB_Model_EffectiveGap())
    Variable res = 0
    if (doConv)
        res = coef[nPar - 1]
        if (numtype(res) != 0 || res < LJZ_EDCWB_MinRes())
            res = LJZ_EDCWB_MinRes()
        endif
    endif

    Make/FREE/N=(nPts) specNoConv
    CopyScales wData, specNoConv

    LJZ_EDCWB_EvalSpectrumNoConv_ModelID(wData, coef, specNoConv, m)

    if (doConv && res > LJZ_EDCWB_MinRes())
        LJZ_EDCWB_ConvolveWithGauss(specNoConv, res, outWave)
    else
        outWave = specNoConv
    endif

    return 0
End

Function LJZ_EDCWB_EvalModelFull(wData, coef, outWave)
    Wave wData, coef, outWave
    return LJZ_EDCWB_EvalModelFull_ModelID(wData, coef, outWave, LJZ_EDCWB_WorkGetModelID())
End


// ============================================================================
//  Section 4. FitFunc wrappers
//
//  Igor's FuncFit requires a specific signature:  f(coef, x)
//  But our models need a full-wave evaluation for correctness (because the
//  convolution couples neighboring points).  We work around this by calling
//  the full-wave evaluator inside the FitFunc via a cached wave reference,
//  updating it only when the coef pointer changes.
//
//  The approach:
//    - Before FuncFit, we call LJZ_EDCWB_PrepareConvCache(wData, coef)
//      which computes and stores a full model curve in a TMP wave.
//    - The FitFunc reads from the TMP wave by index.  Between FuncFit and the
//      cache, coef is the SAME wave reference, so the cache is always current.
//    - This is the standard approach for convolution-based FitFuncs in Igor.
//
//  Cache path: LJZ_EDCWB_BaseDF() + ":TMP_FitCache"
// ============================================================================


// Weighted coefficient fingerprint used by convolution-based FitFuncs.
// A plain sum(coef) can miss parameter changes that keep the total sum unchanged.
Function LJZ_EDCWB_ResetFitCacheState()
    String base = LJZ_EDCWB_BaseDF()
    KillWaves/Z $(base + ":TMP_LastCoef")
    return 0
End

Function LJZ_EDCWB_CoefChanged(coef)
    Wave coef
    Wave/Z lastCoef = $(LJZ_EDCWB_BaseDF() + ":TMP_LastCoef")
    Variable i, v
    if (!WaveExists(lastCoef) || numpnts(lastCoef) != numpnts(coef))
        return 1
    endif
    for (i = 0; i < numpnts(coef); i += 1)
        v = coef[i]
        if (numtype(v) != 0 || numtype(lastCoef[i]) != 0)
            return 1
        endif
        if (v != lastCoef[i])
            return 1
        endif
    endfor
    return 0
End

Function LJZ_EDCWB_SaveLastCoef(coef)
    Wave coef
    Duplicate/O coef, $(LJZ_EDCWB_BaseDF() + ":TMP_LastCoef")
    return 0
End

Function/S LJZ_EDCWB_FitCachePath()
    return LJZ_EDCWB_BaseDF() + ":TMP_FitCache"
End

// Call this once before FuncFit; it fills the cache and sets up Active_modelID.
Function LJZ_EDCWB_PrepareConvCache(wData, coefW)
    Wave wData, coefW

    LJZ_EDCWB_EnsureFitEngineState()
    LJZ_EDCWB_CopyActiveModeFromWork()
    LJZ_EDCWB_ResetFitCacheState()

    Variable nPts = numpnts(wData)
    Make/O/N=(nPts) $(LJZ_EDCWB_FitCachePath())
    Wave cache = $(LJZ_EDCWB_FitCachePath())
    CopyScales wData, cache

    NVAR activeMID = $(LJZ_EDCWB_BaseDF() + ":Active_modelID")
    LJZ_EDCWB_EvalModelFull_ModelID(wData, coefW, cache, activeMID)
    return 0
End

// FitFunc for SinglePeakFD and EffectiveGap (both use the same cache approach).
// Igor passes the coef wave and a single x value; we return cache[index(x)].
Function LJZ_EDCWB_FitFunc_Impl(coef, x)
    Wave coef
    Variable x

    Wave/Z cache = $(LJZ_EDCWB_BaseDF() + ":TMP_FitCache")
    if (!WaveExists(cache))
        return NaN
    endif

    if (LJZ_EDCWB_CoefChanged(coef))
        NVAR activeMID = $(LJZ_EDCWB_BaseDF() + ":Active_modelID")
        LJZ_EDCWB_EvalModelFull_ModelID(cache, coef, cache, activeMID)
        LJZ_EDCWB_SaveLastCoef(coef)
    endif

    // Return the cache value at x
    Variable dx = DimDelta(cache, 0)
    Variable x0ax = DimOffset(cache, 0)
    if (numtype(dx) != 0 || dx == 0)
        return NaN
    endif
    Variable idx = round((x - x0ax) / dx)
    idx = max(0, min(numpnts(cache) - 1, idx))
    return cache[idx]
End

Function LJZ_EDCWB_FitFunc_FDModels(coef, x) : FitFunc
    Wave coef
    Variable x
    return LJZ_EDCWB_FitFunc_Impl(coef, x)
End

// FitFunc for SymGap (no FD, just spectral function).
Function LJZ_EDCWB_FitFunc_SymGap(coef, x) : FitFunc
    Wave coef
    Variable x
    return LJZ_EDCWB_FitFunc_Impl(coef, x)
End


// ============================================================================
//  Section 5. Sanitation
// ============================================================================

// Sanitize Work_par and Work_hold for the current model.
// Returns 1 if any change was made, 0 otherwise.
Function LJZ_EDCWB_SanitizeWorkState()
    LJZ_EDCWB_EnsureBaseDF()

    String base = LJZ_EDCWB_BaseDF()
    Wave wPar  = $(base + ":Work_par")
    Wave wHold = $(base + ":Work_hold")
    Wave wEI   = $(base + ":Work_editinfo")
    Wave wROI  = $(base + ":Work_roi")

    Variable changed = 0
    Variable m = LJZ_EDCWB_WorkGetModelID()
    Variable nPar = LJZ_EDCWB_ModelNPar(m)

    // Resize par/hold if wrong length (e.g. after model switch race)
    if (numpnts(wPar) != nPar)
        Redimension/N=(nPar) wPar, wHold
        changed = 1
    endif

    // Clamp hold to {0, 1}
    Variable i
    for (i = 0; i < nPar; i += 1)
        Variable hv = (wHold[i] != 0) ? 1 : 0
        if (wHold[i] != hv)
            wHold[i] = hv
            changed = 1
        endif
    endfor

    // ---- per-model par sanitation ----
    // Common: bg0, bg1 can be any finite value (replace NaN with 0)
    if (numtype(wPar[0]) != 0)
        wPar[0] = 0
        changed = 1
    endif
    if (numtype(wPar[1]) != 0)
        wPar[1] = 0
        changed = 1
    endif
    // A >= 0
    if (numtype(wPar[2]) != 0 || wPar[2] < 0)
        wPar[2] = max(0, abs(wPar[2]))
        changed = 1
    endif

    if (m == LJZ_EDCWB_Model_SinglePeakFD())
        // x0: any finite
        if (numtype(wPar[3]) != 0)
            wPar[3] = 0
            changed = 1
        endif
        // w > 0
        if (numtype(wPar[4]) != 0 || wPar[4] <= 0)
            wPar[4] = LJZ_EDCWB_ClampFinitePositive(wPar[4], LJZ_EDCWB_MinWidth(), LJZ_EDCWB_MinWidth())
            changed = 1
        endif
        // eta in [0,1]
        if (numtype(wPar[5]) != 0)
            wPar[5] = 0.5
            changed = 1
        else
            Variable ec = min(1, max(0, wPar[5]))
            if (ec != wPar[5])
                wPar[5] = ec
                changed = 1
            endif
        endif
        // T >= 0 (held at physical value)
        if (numtype(wPar[6]) != 0 || wPar[6] < 0)
            wPar[6] = LJZ_EDCWB_ClampFiniteNonneg(wPar[6], 10)
            changed = 1
        endif
        // EF: any finite
        if (numtype(wPar[7]) != 0)
            wPar[7] = 0
            changed = 1
        endif
        // res > 0
        if (numtype(wPar[8]) != 0 || wPar[8] <= 0)
            wPar[8] = LJZ_EDCWB_ClampFinitePositive(wPar[8], LJZ_EDCWB_MinRes(), LJZ_EDCWB_MinRes())
            changed = 1
        endif

    elseif (m == LJZ_EDCWB_Model_EffectiveGap())
        // Delta >= 0
        if (numtype(wPar[3]) != 0 || wPar[3] < 0)
            wPar[3] = max(0, abs(wPar[3]))
            changed = 1
        endif
        // Gamma > 0
        if (numtype(wPar[4]) != 0 || wPar[4] <= 0)
            wPar[4] = LJZ_EDCWB_ClampFinitePositive(wPar[4], LJZ_EDCWB_MinGamma(), LJZ_EDCWB_MinGamma())
            changed = 1
        endif
        // T >= 0
        if (numtype(wPar[5]) != 0 || wPar[5] < 0)
            wPar[5] = LJZ_EDCWB_ClampFiniteNonneg(wPar[5], 10)
            changed = 1
        endif
        // EF: any finite
        if (numtype(wPar[6]) != 0)
            wPar[6] = 0
            changed = 1
        endif
        // res > 0
        if (numtype(wPar[7]) != 0 || wPar[7] <= 0)
            wPar[7] = LJZ_EDCWB_ClampFinitePositive(wPar[7], LJZ_EDCWB_MinRes(), LJZ_EDCWB_MinRes())
            changed = 1
        endif

    elseif (m == LJZ_EDCWB_Model_SymGap())
        // Delta >= 0
        if (numtype(wPar[3]) != 0 || wPar[3] < 0)
            wPar[3] = max(0, abs(wPar[3]))
            changed = 1
        endif
        // Gamma > 0
        if (numtype(wPar[4]) != 0 || wPar[4] <= 0)
            wPar[4] = LJZ_EDCWB_ClampFinitePositive(wPar[4], LJZ_EDCWB_MinGamma(), LJZ_EDCWB_MinGamma())
            changed = 1
        endif
        // x0: any finite
        if (numtype(wPar[5]) != 0)
            wPar[5] = 0
            changed = 1
        endif
    endif

    // ---- editinfo sanitation ----
    if (numpnts(wEI) != LJZ_EDCWB_EditInfoSize())
        Redimension/N=(LJZ_EDCWB_EditInfoSize()) wEI
        changed = 1
    endif

    // T >= 0
    if (numtype(wEI[LJZ_EDCWB_EI_T()]) != 0 || wEI[LJZ_EDCWB_EI_T()] < 0)
        wEI[LJZ_EDCWB_EI_T()] = LJZ_EDCWB_ClampFiniteNonneg(wEI[LJZ_EDCWB_EI_T()], 10)
        changed = 1
    endif
    // res > 0
    if (numtype(wEI[LJZ_EDCWB_EI_Res()]) != 0 || wEI[LJZ_EDCWB_EI_Res()] <= 0)
        wEI[LJZ_EDCWB_EI_Res()] = LJZ_EDCWB_ClampFinitePositive(wEI[LJZ_EDCWB_EI_Res()], LJZ_EDCWB_MinRes(), LJZ_EDCWB_MinRes())
        changed = 1
    endif
    // EF: any finite; replace NaN with 0
    if (numtype(wEI[LJZ_EDCWB_EI_EF()]) != 0)
        wEI[LJZ_EDCWB_EI_EF()] = 0
        changed = 1
    endif
    // normMode >= 0 integer
    if (numtype(wEI[LJZ_EDCWB_EI_NormMode()]) != 0)
        wEI[LJZ_EDCWB_EI_NormMode()] = 0
        changed = 1
    else
        Variable nmClamped = max(0, round(wEI[LJZ_EDCWB_EI_NormMode()]))
        if (nmClamped != wEI[LJZ_EDCWB_EI_NormMode()])
            wEI[LJZ_EDCWB_EI_NormMode()] = nmClamped
            changed = 1
        endif
    endif

    // ---- ROI ----
    if (numpnts(wROI) != 2)
        Redimension/N=2 wROI
        wROI = NaN
        changed = 1
    endif

    return changed
End


// ============================================================================
//  Section 6. Flat parameter assembly / distribution
//
//  Flat layout for FuncFit is simply Work_par itself (length = nPar(modelID)).
//  No restructuring is needed because EDC models have a fixed parameter order.
//  The hold mask is built as a nPar-character "0"/"1" string.
// ============================================================================

Function/S LJZ_EDCWB_BuildHoldMask()
    LJZ_EDCWB_EnsureBaseDF()

    Variable m = LJZ_EDCWB_WorkGetModelID()
    Variable nPar = LJZ_EDCWB_ModelNPar(m)
    Wave wHold = $(LJZ_EDCWB_BaseDF() + ":Work_hold")

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

// Copy fit result back from flatCoef into Work_par, then sanitize.
Function LJZ_EDCWB_DistributeFitResult(flatCoef, flatSigma)
    Wave flatCoef
    Wave/Z flatSigma

    LJZ_EDCWB_EnsureBaseDF()

    String base = LJZ_EDCWB_BaseDF()
    Variable m    = LJZ_EDCWB_WorkGetModelID()
    Variable nPar = LJZ_EDCWB_ModelNPar(m)

    Wave wPar = $(base + ":Work_par")
    if (numpnts(flatCoef) < nPar)
        return -1
    endif

    Variable i
    for (i = 0; i < nPar; i += 1)
        wPar[i] = flatCoef[i]
    endfor

    if (m == LJZ_EDCWB_Model_SinglePeakFD())
        LJZ_EDCWB_WorkSetT(wPar[6]); LJZ_EDCWB_WorkSetEF(wPar[7]); LJZ_EDCWB_WorkSetRes(wPar[8])
    elseif (m == LJZ_EDCWB_Model_EffectiveGap())
        LJZ_EDCWB_WorkSetT(wPar[5]); LJZ_EDCWB_WorkSetEF(wPar[6]); LJZ_EDCWB_WorkSetRes(wPar[7])
    endif

    LJZ_EDCWB_SanitizeWorkState()

    if (WaveExists(flatSigma))
        Duplicate/O flatSigma, $(base + ":Active_lastSigma")
    else
        Make/O/N=(nPar) $(base + ":Active_lastSigma") = NaN
    endif

    return 0
End


// ============================================================================
//  Section 7. Semantic edit actions (called by Part 3 callbacks)
// ============================================================================

Function LJZ_EDCWB_SetPar(idx, val)
    Variable idx, val

    Variable rc = LJZ_EDCWB_WorkSetPar(idx, val)
    if (rc != 0)
        LJZ_EDCWB_SetLastError("Invalid parameter index.")
        return -1
    endif
    LJZ_EDCWB_SanitizeWorkState()
    Variable m = LJZ_EDCWB_WorkGetModelID()
    if (m == LJZ_EDCWB_Model_SinglePeakFD())
        if (idx == 6)
            LJZ_EDCWB_WorkSetT(val)
        elseif (idx == 7)
            LJZ_EDCWB_WorkSetEF(val)
        elseif (idx == 8)
            LJZ_EDCWB_WorkSetRes(val)
        endif
    elseif (m == LJZ_EDCWB_Model_EffectiveGap())
        if (idx == 5)
            LJZ_EDCWB_WorkSetT(val)
        elseif (idx == 6)
            LJZ_EDCWB_WorkSetEF(val)
        elseif (idx == 7)
            LJZ_EDCWB_WorkSetRes(val)
        endif
    endif
    LJZ_EDCWB_MarkDirty(1)
    LJZ_EDCWB_ClearLastError()
    return 0
End

Function LJZ_EDCWB_SetHold(idx, on)
    Variable idx, on

    Variable rc = LJZ_EDCWB_WorkSetHold(idx, on)
    if (rc != 0)
        LJZ_EDCWB_SetLastError("Invalid hold index.")
        return -1
    endif
    LJZ_EDCWB_MarkDirty(1)
    LJZ_EDCWB_ClearLastError()
    return 0
End

Function LJZ_EDCWB_SetT(val)
    Variable val

    LJZ_EDCWB_WorkSetT(val)
    // Mirror T into par slot if model uses T
    Variable m = LJZ_EDCWB_WorkGetModelID()
    if (m == LJZ_EDCWB_Model_SinglePeakFD())
        LJZ_EDCWB_WorkSetPar(6, val)
    elseif (m == LJZ_EDCWB_Model_EffectiveGap())
        LJZ_EDCWB_WorkSetPar(5, val)
    endif
    LJZ_EDCWB_SanitizeWorkState()
    LJZ_EDCWB_MarkDirty(1)
    LJZ_EDCWB_ClearLastError()
    return 0
End

Function LJZ_EDCWB_SetEF(val)
    Variable val

    LJZ_EDCWB_WorkSetEF(val)
    Variable m = LJZ_EDCWB_WorkGetModelID()
    if (m == LJZ_EDCWB_Model_SinglePeakFD())
        LJZ_EDCWB_WorkSetPar(7, val)
    elseif (m == LJZ_EDCWB_Model_EffectiveGap())
        LJZ_EDCWB_WorkSetPar(6, val)
    endif
    LJZ_EDCWB_SanitizeWorkState()
    LJZ_EDCWB_MarkDirty(1)
    LJZ_EDCWB_ClearLastError()
    return 0
End

Function LJZ_EDCWB_SetRes(val)
    Variable val

    LJZ_EDCWB_WorkSetRes(val)
    Variable m = LJZ_EDCWB_WorkGetModelID()
    if (m == LJZ_EDCWB_Model_SinglePeakFD())
        LJZ_EDCWB_WorkSetPar(8, val)
    elseif (m == LJZ_EDCWB_Model_EffectiveGap())
        LJZ_EDCWB_WorkSetPar(7, val)
    endif
    LJZ_EDCWB_SanitizeWorkState()
    LJZ_EDCWB_MarkDirty(1)
    LJZ_EDCWB_ClearLastError()
    return 0
End

Function LJZ_EDCWB_SetROI(xLo, xHi)
    Variable xLo, xHi
    LJZ_EDCWB_WorkSetROI(xLo, xHi)
    LJZ_EDCWB_MarkDirty(1)
    LJZ_EDCWB_ClearLastError()
    return 0
End

Function LJZ_EDCWB_SetModel(m)
    Variable m

    if (!LJZ_EDCWB_IsValidModelID(m))
        LJZ_EDCWB_SetLastError("Invalid model ID.")
        return -1
    endif

    Variable oldM = LJZ_EDCWB_WorkGetModelID()
    if (m == oldM)
        return 0
    endif

    // Snapshot T/EF/res from old model before resize
    Variable T   = LJZ_EDCWB_WorkGetT()
    Variable EF  = LJZ_EDCWB_WorkGetEF()
    Variable res = LJZ_EDCWB_WorkGetRes()

    LJZ_EDCWB_WorkSetModelID(m)    // resizes Work_par / Work_hold
    Wave wHold = $(LJZ_EDCWB_BaseDF() + ":Work_hold")
    wHold = 0
    LJZ_EDCWB_SanitizeWorkState()

    // Re-inject T/EF/res into the new model's par slots
    if (m == LJZ_EDCWB_Model_SinglePeakFD())
        LJZ_EDCWB_WorkSetPar(6, T)
        LJZ_EDCWB_WorkSetPar(7, EF)
        LJZ_EDCWB_WorkSetPar(8, res)
        // Default hold: T, EF, res held
        LJZ_EDCWB_WorkSetHold(6, 1)
        LJZ_EDCWB_WorkSetHold(7, 1)
        LJZ_EDCWB_WorkSetHold(8, 1)
    elseif (m == LJZ_EDCWB_Model_EffectiveGap())
        LJZ_EDCWB_WorkSetPar(5, T)
        LJZ_EDCWB_WorkSetPar(6, EF)
        LJZ_EDCWB_WorkSetPar(7, res)
        LJZ_EDCWB_WorkSetHold(5, 1)
        LJZ_EDCWB_WorkSetHold(6, 1)
        LJZ_EDCWB_WorkSetHold(7, 1)
    endif
    // SymGap has no T/EF/res; all pars free by default

    LJZ_EDCWB_MarkDirty(1)
    LJZ_EDCWB_ClearLastError()
    return 0
End

Function LJZ_EDCWB_SetNormMode(mode)
    Variable mode
    LJZ_EDCWB_WorkSetNormMode(mode)
    LJZ_EDCWB_MarkDirty(1)
    return 0
End

// Explicit user save: ONE of two allowed edit-state write paths.
Function LJZ_EDCWB_SaveWorkToDisk(wData)
    Wave wData

    LJZ_EDCWB_SanitizeWorkState()
    Variable rc = LJZ_EDCWB_SaveEditStateFromWork(wData)
    if (rc != 0)
        LJZ_EDCWB_SetLastError("Saving edit state failed.")
        LJZ_EDCWB_MarkDirty(1)
        return -1
    endif
    LJZ_EDCWB_MarkDirty(0)
    LJZ_EDCWB_ClearLastError()
    return 0
End

Function LJZ_EDCWB_SetAccept(wData, state)
    Wave wData
    Variable state

    Variable rc = LJZ_EDCWB_WriteAcceptState(wData, state)
    if (rc != 0)
        LJZ_EDCWB_SetLastError("Accept-state write failed.")
        return -1
    endif
    return 0
End


// ============================================================================
//  Section 8. ROI helpers and metrics
// ============================================================================

Function LJZ_EDCWB_GetROIIndexRange(dataWave, xLo, xHi, iLo, iHi)
    Wave dataWave
    Variable xLo, xHi
    Variable &iLo, &iHi

    Variable n   = numpnts(dataWave)
    Variable x0  = DimOffset(dataWave, 0)
    Variable dx  = DimDelta(dataWave, 0)

    if (numtype(dx) != 0 || dx == 0)
        dx = 1
    endif
    if (n <= 0)
        iLo = 0; iHi = -1
        return -1
    endif

    if (numtype(xLo) != 0 || numtype(xHi) != 0)
        iLo = 0; iHi = n - 1
        return 0
    endif

    Variable xMin = min(xLo, xHi)
    Variable xMax = max(xLo, xHi)
    iLo = max(0, min(n - 1, round((xMin - x0) / dx)))
    iHi = max(0, min(n - 1, round((xMax - x0) / dx)))
    if (iHi < iLo)
        Variable tmp = iLo; iLo = iHi; iHi = tmp
    endif
    return 0
End

Function LJZ_EDCWB_CountFiniteInROI(dataWave, xLo, xHi)
    Wave dataWave
    Variable xLo, xHi

    Variable lo, hi
    if (LJZ_EDCWB_GetROIIndexRange(dataWave, xLo, xHi, lo, hi) != 0)
        return 0
    endif
    Variable cnt = 0, ip
    for (ip = lo; ip <= hi; ip += 1)
        if (numtype(dataWave[ip]) == 0)
            cnt += 1
        endif
    endfor
    return cnt
End

Function LJZ_EDCWB_MinFiniteForFit(nPar)
    Variable nPar
    return max(2 * nPar, nPar + 10)
End

Function LJZ_EDCWB_ComputeFitMetrics(dataWave, guessWave, fitWave, resWave, xLo, xHi, guessRMSEOut, fitRMSEOut, rssROIOut, maxAbsResOut, nROIOut)
    Wave dataWave, guessWave, fitWave, resWave
    Variable xLo, xHi
    Variable &guessRMSEOut, &fitRMSEOut, &rssROIOut, &maxAbsResOut, &nROIOut

    guessRMSEOut = NaN; fitRMSEOut = NaN
    rssROIOut = NaN; maxAbsResOut = NaN; nROIOut = 0

    Variable lo, hi
    if (LJZ_EDCWB_GetROIIndexRange(dataWave, xLo, xHi, lo, hi) != 0)
        return -1
    endif

    Variable gSq = 0, gCnt = 0, fSq = 0, fCnt = 0
    Variable maxAbs = NaN
    Variable ip, dv, gv, fv, rv, ar

    for (ip = lo; ip <= hi; ip += 1)
        dv = dataWave[ip]; gv = guessWave[ip]
        fv = fitWave[ip];  rv = resWave[ip]
        if (numtype(dv) == 0 && numtype(gv) == 0)
            gSq += (dv - gv)^2; gCnt += 1
        endif
        if (numtype(dv) == 0 && numtype(fv) == 0 && numtype(rv) == 0)
            fSq += rv^2; fCnt += 1
            ar = abs(rv)
            if (numtype(maxAbs) != 0 || ar > maxAbs)
                maxAbs = ar
            endif
        endif
    endfor

    if (gCnt <= 0 || fCnt <= 0)
        return -1
    endif

    guessRMSEOut = sqrt(gSq / gCnt)
    fitRMSEOut   = sqrt(fSq / fCnt)
    rssROIOut    = fSq
    maxAbsResOut = maxAbs
    nROIOut      = fCnt
    return 0
End

Function LJZ_EDCWB_BuildFitInfoWave(infoW, m, xLo, xHi, fitOK, gRMSE, fRMSE, rss, maxR, nROI, quitReason, numIters)
    Wave infoW
    Variable m, xLo, xHi, fitOK, gRMSE, fRMSE, rss, maxR, nROI, quitReason, numIters

    LJZ_EDCWB_InitFitInfoWave(infoW)
    infoW[LJZ_EDCWB_FI_ModelID()]       = m
    infoW[LJZ_EDCWB_FI_XLo()]           = xLo
    infoW[LJZ_EDCWB_FI_XHi()]           = xHi
    infoW[LJZ_EDCWB_FI_FitOK()]         = (fitOK > 0.5) ? 1 : 0
    infoW[LJZ_EDCWB_FI_GuessRMSE()]     = gRMSE
    infoW[LJZ_EDCWB_FI_FitRMSE()]       = fRMSE
    infoW[LJZ_EDCWB_FI_RssROI()]        = rss
    infoW[LJZ_EDCWB_FI_MaxAbsRes()]     = maxR
    infoW[LJZ_EDCWB_FI_NROI()]          = nROI
    infoW[LJZ_EDCWB_FI_FitQuitReason()] = quitReason
    infoW[LJZ_EDCWB_FI_FitNumIters()]   = numIters
    return 0
End


// ============================================================================
//  Section 9. Auto-init
//
//  Estimates BG from ROI edges, sets reasonable par defaults for the current
//  model. Never writes edit-state to disk (Contract A).
// ============================================================================

Function LJZ_EDCWB_EstimateBGFromEdges(dataWave, xLo, xHi)
    Wave dataWave
    Variable xLo, xHi

    Variable lo, hi
    if (LJZ_EDCWB_GetROIIndexRange(dataWave, xLo, xHi, lo, hi) != 0)
        return 0
    endif
    Variable n = hi - lo + 1
    if (n <= 0)
        return 0
    endif

    Variable edgeN = max(1, min(5, floor(n / 5)))
    Variable s = 0, cnt = 0, i, v
    for (i = 0; i < edgeN; i += 1)
        v = dataWave[lo + i]
        if (numtype(v) == 0)
            s += v; cnt += 1
        endif
        v = dataWave[hi - i]
        if (numtype(v) == 0)
            s += v; cnt += 1
        endif
    endfor
    if (cnt <= 0)
        return 0
    endif
    return s / cnt
End

Function LJZ_EDCWB_AutoInitFromData(wData)
    Wave wData

    LJZ_EDCWB_EnsureBaseDF()

    Variable nPts = numpnts(wData)
    if (nPts < 10)
        LJZ_EDCWB_SetLastError("Too few data points for auto init.")
        return -1
    endif

    Variable x0ax = DimOffset(wData, 0)
    Variable dx   = DimDelta(wData, 0)
    if (numtype(dx) != 0 || dx == 0)
        dx = 1
    endif
    Variable fullLo = x0ax
    Variable fullHi = x0ax + dx * (nPts - 1)

    // Preserve user-set ROI; only fill if missing.
    Variable xLo, xHi
    LJZ_EDCWB_WorkGetROI(xLo, xHi)
    if (numtype(xLo) != 0 || numtype(xHi) != 0)
        xLo = fullLo
        xHi = fullHi
        LJZ_EDCWB_WorkSetROI(xLo, xHi)
    endif

    Variable lo, hi
    if (LJZ_EDCWB_GetROIIndexRange(wData, xLo, xHi, lo, hi) != 0 || hi - lo + 1 < 5)
        LJZ_EDCWB_SetLastError("ROI too small for auto init.")
        return -1
    endif

    WaveStats/Q/M=1/R=[lo,hi] wData
    if (numtype(V_max) != 0 || numtype(V_min) != 0)
        LJZ_EDCWB_SetLastError("Non-finite ROI statistics.")
        return -1
    endif

    Variable bg = LJZ_EDCWB_EstimateBGFromEdges(wData, xLo, xHi)
    Variable amp = max(V_max - bg, 1e-6)
    Variable xRangeFull = abs(xHi - xLo)
    Variable T   = LJZ_EDCWB_WorkGetT()
    Variable EF  = LJZ_EDCWB_WorkGetEF()
    Variable res = LJZ_EDCWB_WorkGetRes()

    // Clamp T/res from editinfo if stored
    Wave wEI = $(LJZ_EDCWB_BaseDF() + ":Work_editinfo")
    Variable Tfrominfo = wEI[LJZ_EDCWB_EI_T()]
    if (numtype(Tfrominfo) == 0 && Tfrominfo >= 0)
        T = Tfrominfo
    endif
    if (T <= 0)
        T = 10
    endif
    Variable resfrominfo = wEI[LJZ_EDCWB_EI_Res()]
    if (numtype(resfrominfo) == 0 && resfrominfo > 0)
        res = resfrominfo
    endif
    if (res <= 0)
        res = max(LJZ_EDCWB_MinRes(), abs(dx) * 3)
    endif
    Variable EFfrominfo = wEI[LJZ_EDCWB_EI_EF()]
    if (numtype(EFfrominfo) == 0)
        EF = EFfrominfo
    endif

    Variable m = LJZ_EDCWB_WorkGetModelID()
    Wave wPar  = $(LJZ_EDCWB_BaseDF() + ":Work_par")
    Wave wHold = $(LJZ_EDCWB_BaseDF() + ":Work_hold")
    Variable nPar = LJZ_EDCWB_ModelNPar(m)
    Redimension/N=(nPar) wPar, wHold
    wPar  = NaN
    wHold = 0

    if (m == LJZ_EDCWB_Model_SinglePeakFD())
        wPar[0] = bg
        wPar[1] = 0
        wPar[2] = amp
        wPar[3] = EF - 0.1 * xRangeFull     // x0: slightly below EF
        wPar[4] = max(LJZ_EDCWB_MinWidth(), xRangeFull / 10)
        wPar[5] = 0.5                         // eta
        wPar[6] = T
        wPar[7] = EF
        wPar[8] = res
        // T, EF, res held by default
        wHold[6] = 1; wHold[7] = 1; wHold[8] = 1

    elseif (m == LJZ_EDCWB_Model_EffectiveGap())
        wPar[0] = bg
        wPar[1] = 0
        wPar[2] = amp
        wPar[3] = max(0, xRangeFull / 20)    // Delta
        wPar[4] = max(LJZ_EDCWB_MinGamma(), xRangeFull / 40)  // Gamma
        wPar[5] = T
        wPar[6] = EF
        wPar[7] = res
        wHold[5] = 1; wHold[6] = 1; wHold[7] = 1

    elseif (m == LJZ_EDCWB_Model_SymGap())
        wPar[0] = bg
        wPar[1] = 0
        wPar[2] = amp
        wPar[3] = max(0, xRangeFull / 20)
        wPar[4] = max(LJZ_EDCWB_MinGamma(), xRangeFull / 40)
        wPar[5] = EF                          // x0 center of symmetry
    endif

    LJZ_EDCWB_SanitizeWorkState()
    LJZ_EDCWB_MarkDirty(1)
    LJZ_EDCWB_ClearLastError()
    return 0
End


// ============================================================================
//  Section 10. LoadCurrentToWork
// ============================================================================

// Pull saved edit-state into Work_*. If sanitation changes anything,
// Dirty == 1. If no saved state, falls back to AutoInit.
// Returns: 1 = loaded from disk,  0 = fell back to AutoInit,  -1 = error.
Function LJZ_EDCWB_LoadCurrentToWork(wData)
    Wave wData

    LJZ_EDCWB_EnsureBaseDF()

    if (LJZ_EDCWB_HasEditState(wData))
        if (LJZ_EDCWB_LoadEditStateToWork(wData))
            Variable changed = LJZ_EDCWB_SanitizeWorkState()
            if (changed)
                LJZ_EDCWB_MarkDirty(1)
            else
                if (LJZ_EDCWB_HasFitRecord(wData) && LJZ_EDCWB_ReadFitOK(wData))
                    LJZ_EDCWB_MarkDirty(0)
                else
                    LJZ_EDCWB_MarkDirty(1)
                endif
            endif
            LJZ_EDCWB_ClearLastError()
            return 1
        endif
    endif

    Variable rc = LJZ_EDCWB_AutoInitFromData(wData)
    if (rc != 0)
        LJZ_EDCWB_ResetWorkState()
        LJZ_EDCWB_MarkDirty(1)
        return -1
    endif

    LJZ_EDCWB_MarkDirty(1)
    return 0
End


// ============================================================================
//  Section 11. BuildGuess
//
//  Writes <wname>_guess to disk. Does NOT write edit-state (Contract A).
// ============================================================================

Function LJZ_EDCWB_BuildGuess(wData)
    Wave wData

    LJZ_EDCWB_EnsureFitEngineState()
    LJZ_EDCWB_SanitizeWorkState()

    Variable m    = LJZ_EDCWB_WorkGetModelID()
    Variable nPar = LJZ_EDCWB_ModelNPar(m)
    Wave wPar = $(LJZ_EDCWB_BaseDF() + ":Work_par")

    Duplicate/FREE wData, guessW
    LJZ_EDCWB_EvalModelFull(wData, wPar, guessW)

    if (LJZ_EDCWB_SaveGuessWave(wData, guessW) != 0)
        LJZ_EDCWB_SetLastError("Guess save failed.")
        LJZ_EDCWB_MarkDirty(1)
        return -1
    endif

    // INTENTIONAL: do NOT call SaveEditStateFromWork here. See Contract A.
    LJZ_EDCWB_ClearLastError()
    return 0
End


// ============================================================================
//  Section 12. RunFit
// ============================================================================

Function LJZ_EDCWB_ValidateFlatCoef(coefW)
    Wave coefW
    Variable i
    for (i = 0; i < numpnts(coefW); i += 1)
        if (numtype(coefW[i]) != 0)
            return 0
        endif
    endfor
    return 1
End

Function LJZ_EDCWB_RunFit(wData)
    Wave wData

    LJZ_EDCWB_EnsureFitEngineState()
    LJZ_EDCWB_SanitizeWorkState()

    Variable m    = LJZ_EDCWB_WorkGetModelID()
    Variable nPar = LJZ_EDCWB_ModelNPar(m)

    Variable xLo, xHi
    LJZ_EDCWB_WorkGetROI(xLo, xHi)

    Variable roiLo, roiHi
    if (LJZ_EDCWB_GetROIIndexRange(wData, xLo, xHi, roiLo, roiHi) != 0)
        LJZ_EDCWB_SetLastError("Invalid ROI.")
        LJZ_EDCWB_MarkDirty(1)
        return -1
    endif

    Variable finiteCount = LJZ_EDCWB_CountFiniteInROI(wData, xLo, xHi)
    Variable required    = LJZ_EDCWB_MinFiniteForFit(nPar)
    if (finiteCount < required)
        String msg
        sprintf msg, "ROI has %d finite points; need >= %d for %d parameters.", finiteCount, required, nPar
        LJZ_EDCWB_SetLastError(msg)
        LJZ_EDCWB_MarkDirty(1)
        return -1
    endif

    // Make a working copy of coef for FuncFit (it will be modified in place)
    Wave wPar = $(LJZ_EDCWB_BaseDF() + ":Work_par")
    Duplicate/FREE wPar, coefActive
    String holdMask = LJZ_EDCWB_BuildHoldMask()

    // Build and cache the guess BEFORE fitting (Contract A: does not write disk)
    Duplicate/FREE wData, guessFull
    LJZ_EDCWB_EvalModelFull(wData, coefActive, guessFull)
    // Save the guess cache (only the _guess wave, not edit-state)
    LJZ_EDCWB_SaveGuessWave(wData, guessFull)

    // Extract ROI sub-wave for FuncFit
    Variable roiN  = roiHi - roiLo + 1
    Make/FREE/N=(roiN) roiData = wData[roiLo + p]
    SetScale/P x, DimOffset(wData, 0) + roiLo * DimDelta(wData, 0), DimDelta(wData, 0), roiData

    // Prepare convolution cache and freeze Active_modelID
    LJZ_EDCWB_PrepareConvCache(wData, coefActive)

    Variable fitCaughtError  = 0
    Variable runtimeErrCode  = 0
    Variable fitFailed       = 0
    Variable fitQuitReason   = NaN
    Variable fitNumIters     = NaN
    String   oldDF = GetDataFolder(1)

    KillWaves/Z W_sigma

    try
        if (m == LJZ_EDCWB_Model_SinglePeakFD() || m == LJZ_EDCWB_Model_EffectiveGap())
            FuncFit/H=holdMask/Q LJZ_EDCWB_FitFunc_FDModels, coefActive, roiData
        elseif (m == LJZ_EDCWB_Model_SymGap())
            FuncFit/H=holdMask/Q LJZ_EDCWB_FitFunc_SymGap, coefActive, roiData
        else
            LJZ_EDCWB_SetLastError("Unknown model ID in RunFit.")
            LJZ_EDCWB_MarkDirty(1)
            return -1
        endif
        AbortOnRTE
    catch
        fitCaughtError = 1
    endtry

    SetDataFolder $oldDF
    runtimeErrCode = GetRTError(1)

    if (fitCaughtError || runtimeErrCode != 0)
        fitFailed = 1
        String emsg
        sprintf emsg, "FuncFit runtime failure (RTE=%d).", runtimeErrCode
        LJZ_EDCWB_SetLastError(emsg)
    else
        if (V_FitError != 0)
            fitFailed = 1
            LJZ_EDCWB_SetLastError("FuncFit reported fit error.")
        endif
        fitQuitReason = V_FitQuitReason
        fitNumIters = V_FitNumIters
    endif

    if (!LJZ_EDCWB_ValidateFlatCoef(coefActive))
        fitFailed = 1
        LJZ_EDCWB_SetLastError("Fit coefficients became non-finite.")
    endif

    if (fitFailed)
        LJZ_EDCWB_ResetFitCacheState()
        LJZ_EDCWB_MarkDirty(1)
        return -1
    endif

    // Snapshot sigma before anything can overwrite W_sigma
    Wave/Z ws = W_sigma
    Make/FREE/N=(nPar) sigmaLocal = NaN
    if (WaveExists(ws) && numpnts(ws) == nPar)
        sigmaLocal = ws[p]
    endif

    LJZ_EDCWB_DistributeFitResult(coefActive, sigmaLocal)

    // Full-wave fit curve and residual
    Duplicate/FREE wData, fitFull, resFull
    LJZ_EDCWB_EvalModelFull(wData, coefActive, fitFull)
    resFull = wData[p] - fitFull[p]

    Variable gRMSE, fRMSE, rss, maxR, nROI
    if (LJZ_EDCWB_ComputeFitMetrics(wData, guessFull, fitFull, resFull, xLo, xHi, gRMSE, fRMSE, rss, maxR, nROI) != 0)
        LJZ_EDCWB_SetLastError("Metric computation failed.")
        LJZ_EDCWB_MarkDirty(1)
        return -1
    endif

    Make/FREE/N=(LJZ_EDCWB_FitInfoSize()) infoW = NaN
    LJZ_EDCWB_BuildFitInfoWave(infoW, m, xLo, xHi, 1, gRMSE, fRMSE, rss, maxR, nROI, fitQuitReason, fitNumIters)

    if (LJZ_EDCWB_SaveFitRecord(wData, coefActive, sigmaLocal, infoW, fitFull, resFull) != 0)
        LJZ_EDCWB_SetLastError("Fit record save failed.")
        LJZ_EDCWB_MarkDirty(1)
        return -1
    endif

    // Second allowed edit-state write path (Contract A).
    if (LJZ_EDCWB_SaveEditStateFromWork(wData) != 0)
        LJZ_EDCWB_SetLastError("Fit succeeded but edit-state save failed.")
        LJZ_EDCWB_MarkDirty(1)
        return -1
    endif

    LJZ_EDCWB_MarkDirty(0)
    LJZ_EDCWB_ResetFitCacheState()
    LJZ_EDCWB_ClearLastError()
    return 0
End


// ============================================================================
//  Section 13. Self-test
//
//  Run:  LJZ_EDCWB_Part2_SelfTest()
//
//  Asserts:
//    - Sanitize clamps w, Gamma, res to positive; T to non-negative
//    - BuildHoldMask has correct length for each model
//    - BuildGuess writes _guess but NOT _editpar (no edit save)
//    - RunFit converges on synthetic SinglePeakFD data
//    - RunFit converges on synthetic EffectiveGap data
//    - Tight finite-point check rejects tiny ROI
//    - SetModel preserves T/EF/res across model switch
// ============================================================================

Function LJZ_EDCWB_Part2_SelfTest()
    NewDataFolder/O root:TEST_EDCWB_PART2
    String oldDF = GetDataFolder(1)
    SetDataFolder root:TEST_EDCWB_PART2

    Variable nPass = 0, nFail = 0
    String name

    LJZ_EDCWB_EnsureBaseDF()

    // ---- synthetic edc_show_0 for SinglePeakFD ----
    Make/O/N=401 edc_show_0
    SetScale/P x, -1.0, 0.005, edc_show_0
    Variable T0 = 20, EF0 = 0.0, res0 = 0.025
    Variable ii, E0
    for (ii = 0; ii < 401; ii += 1)
        E0 = -1.0 + ii * 0.005
        edc_show_0[ii] = (0.05 + 1.2 * LJZ_EDCWB_PVKernel(E0, -0.12, 0.06, 0.6)) * LJZ_EDCWB_FD(E0, T0, EF0) + 0.005 * gnoise(1)
    endfor

    Wave w = edc_show_0

    // ---- Setup: SinglePeakFD ----
    LJZ_EDCWB_ResetWorkState()
    LJZ_EDCWB_SetModel(LJZ_EDCWB_Model_SinglePeakFD())
    LJZ_EDCWB_WorkSetT(T0);  LJZ_EDCWB_WorkSetEF(EF0);  LJZ_EDCWB_WorkSetRes(res0)
    LJZ_EDCWB_WorkSetROI(-0.6, 0.1)

    // Auto-init
    LJZ_EDCWB_AutoInitFromData(w)

    // ---- Sanitize tests ----
    LJZ_EDCWB_WorkSetPar(4, -0.001)   // w negative → sanitize should clamp
    LJZ_EDCWB_SanitizeWorkState()
    name = "Sanitize_w_positive"
    if (LJZ_EDCWB_WorkGetPar(4) >= LJZ_EDCWB_MinWidth())
        Print name, "PASS"; nPass += 1
    else
        Print name, "FAIL:", LJZ_EDCWB_WorkGetPar(4); nFail += 1
    endif

    LJZ_EDCWB_WorkSetPar(6, -5)       // T negative → clamp to 0
    LJZ_EDCWB_SanitizeWorkState()
    name = "Sanitize_T_nonneg"
    if (LJZ_EDCWB_WorkGetPar(6) >= 0)
        Print name, "PASS"; nPass += 1
    else
        Print name, "FAIL"; nFail += 1
    endif

    LJZ_EDCWB_WorkSetPar(8, -0.01)    // res negative → clamp
    LJZ_EDCWB_SanitizeWorkState()
    name = "Sanitize_res_positive"
    if (LJZ_EDCWB_WorkGetPar(8) >= LJZ_EDCWB_MinRes())
        Print name, "PASS"; nPass += 1
    else
        Print name, "FAIL"; nFail += 1
    endif

    // ---- HoldMask length ----
    LJZ_EDCWB_AutoInitFromData(w)
    String hm = LJZ_EDCWB_BuildHoldMask()
    name = "HoldMask_length_SinglePeakFD"
    if (strlen(hm) == LJZ_EDCWB_ModelNPar(LJZ_EDCWB_Model_SinglePeakFD()))
        Print name, "PASS"; nPass += 1
    else
        Print name, "FAIL: len=", strlen(hm); nFail += 1
    endif

    // ---- BuildGuess does NOT write edit state ----
    KillWaves/Z $(LJZ_EDCWB_PathEditPar(w))
    Variable rcGuess = LJZ_EDCWB_BuildGuess(w)
    Wave/Z afterEP = $(LJZ_EDCWB_PathEditPar(w))
    name = "BuildGuess_doesNotWriteEditState"
    if (rcGuess == 0 && !WaveExists(afterEP))
        Print name, "PASS"; nPass += 1
    else
        Print name, "FAIL: rc=", rcGuess, "editpar exists=", WaveExists(afterEP); nFail += 1
    endif

    // ---- RunFit SinglePeakFD ----
    LJZ_EDCWB_AutoInitFromData(w)
    name = "RunFit_SinglePeakFD"
    if (LJZ_EDCWB_RunFit(w) == 0 && LJZ_EDCWB_HasFitRecord(w) && LJZ_EDCWB_ReadFitOK(w))
        Print name, "PASS"; nPass += 1
    else
        Print name, "FAIL:", LJZ_EDCWB_GetLastError(); nFail += 1
    endif

    // ---- Reject tiny ROI ----
    LJZ_EDCWB_WorkSetROI(-0.005, 0.005)
    Variable rcTiny = LJZ_EDCWB_RunFit(w)
    LJZ_EDCWB_WorkSetROI(-0.6, 0.1)
    name = "RunFit_rejectsTinyROI"
    if (rcTiny != 0)
        Print name, "PASS"; nPass += 1
    else
        Print name, "FAIL: tiny ROI was accepted"; nFail += 1
    endif

    // ---- SetModel preserves T/EF/res ----
    LJZ_EDCWB_WorkSetT(25); LJZ_EDCWB_WorkSetEF(0.003); LJZ_EDCWB_WorkSetRes(0.030)
    LJZ_EDCWB_SetModel(LJZ_EDCWB_Model_EffectiveGap())
    name = "SetModel_preservesT"
    if (LJZ_EDCWB_WorkGetT() == 25)
        Print name, "PASS"; nPass += 1
    else
        Print name, "FAIL: T=", LJZ_EDCWB_WorkGetT(); nFail += 1
    endif
    name = "SetModel_preservesRes"
    if (abs(LJZ_EDCWB_WorkGetRes() - 0.030) < 1e-8)
        Print name, "PASS"; nPass += 1
    else
        Print name, "FAIL: res=", LJZ_EDCWB_WorkGetRes(); nFail += 1
    endif

    // ---- HoldMask length for EffectiveGap ----
    LJZ_EDCWB_AutoInitFromData(w)
    String hm2 = LJZ_EDCWB_BuildHoldMask()
    name = "HoldMask_length_EffectiveGap"
    if (strlen(hm2) == LJZ_EDCWB_ModelNPar(LJZ_EDCWB_Model_EffectiveGap()))
        Print name, "PASS"; nPass += 1
    else
        Print name, "FAIL: len=", strlen(hm2); nFail += 1
    endif

    // ---- RunFit EffectiveGap ----
    // Synthesize data with small gap
    Make/O/N=401 edc_show_1
    SetScale/P x, -1.0, 0.005, edc_show_1
    Variable Delta0 = 0.05, Gamma0 = 0.03
    for (ii = 0; ii < 401; ii += 1)
        E0 = -1.0 + ii * 0.005
        Variable Ep = E0 - EF0
        Variable aw = 1.2 * LJZ_EDCWB_EffGapWeight(Ep, Delta0, Gamma0)
        edc_show_1[ii] = (0.05 + aw) * LJZ_EDCWB_FD(E0, T0, EF0) + 0.005 * gnoise(1)
    endfor
    Wave w2 = edc_show_1
    LJZ_EDCWB_SetModel(LJZ_EDCWB_Model_EffectiveGap())
    LJZ_EDCWB_WorkSetT(T0); LJZ_EDCWB_WorkSetEF(EF0); LJZ_EDCWB_WorkSetRes(res0)
    LJZ_EDCWB_WorkSetROI(-0.6, 0.1)
    LJZ_EDCWB_AutoInitFromData(w2)
    name = "RunFit_EffectiveGap"
    if (LJZ_EDCWB_RunFit(w2) == 0 && LJZ_EDCWB_HasFitRecord(w2))
        Print name, "PASS"; nPass += 1
    else
        Print name, "FAIL:", LJZ_EDCWB_GetLastError(); nFail += 1
    endif

    // ---- SymGap model: HoldMask length ----
    LJZ_EDCWB_SetModel(LJZ_EDCWB_Model_SymGap())
    String hm3 = LJZ_EDCWB_BuildHoldMask()
    name = "HoldMask_length_SymGap"
    if (strlen(hm3) == LJZ_EDCWB_ModelNPar(LJZ_EDCWB_Model_SymGap()))
        Print name, "PASS"; nPass += 1
    else
        Print name, "FAIL: len=", strlen(hm3); nFail += 1
    endif

    Print "----"
    Print "Part 2 self-test summary:", nPass, "passed,", nFail, "failed"

    SetDataFolder $oldDF
    return nFail
End
