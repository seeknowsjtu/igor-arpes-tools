#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// ============================================================================
//  Pick-Then-Fit (PTF) Robust MDC 2-peak fitter (UCenter)
//  - 先稳健寻峰（seed 附近、噪声标度、sep 门槛）
//  - 再做受控 2P 拟合（只微调；强 gate 防跑飞/边缘吸走/背景上翘）
//  - 失败则回退 1P
//
//  依赖（需已存在）：
//    LJZ_EnsureMDCFitDF, LJZ_Clamp, LJZ_WfreeFromEff, LJZ_HWHM_eff, LJZ_PVArea_FromCoef
//    one_pv_ljz, two_pv_ljz
// ============================================================================


// ------------------------------
// Global gate reason helper
// ------------------------------
Function LJZ_PTF_SetGateReason(msg)
    String msg

    SVAR/Z gr = root:ARPES_LJZ:MDCFit:gLastGateReason
    if (!SVAR_Exists(gr))
        String/G root:ARPES_LJZ:MDCFit:gLastGateReason = ""
        SVAR gr = root:ARPES_LJZ:MDCFit:gLastGateReason
    endif

    gr = msg
    return 0
End


// ------------------------------
// STRUCT definitions
// ------------------------------
Structure LJZ_PTF_Cfg
    String   runDF
    String   outDF
    Variable ResH
    Variable bdta
    Variable fdta
    Variable ddta
    Variable WidRatio

    Variable SmoothN
    Variable WeakSNRThr
    Variable SepFrac

    Variable AlphaPos
    Variable AlphaWid

    Variable MaxShiftFrac
    Variable EdgeN
EndStructure

// ============================================================================
//  STRUCT: State (新增 Seed2Fix；seed2 永远固定)
// ============================================================================
Structure LJZ_PTF_State
    Variable Has2P
    Variable Seed1G
    Variable Seed2Fix         // <-- NEW: fixed seed2 (global coords), never updated

    Variable W1f
    Variable W2f
    Variable WSf

    Variable HasBG
    Variable C0
    Variable C1
    Variable C2
EndStructure


Structure LJZ_PTF_Pick
    Variable Ok
    Variable Is2P

    Variable X1u
    Variable X2u
    Variable Y1
    Variable Y2

    Variable Bg
    Variable Sig

    Variable Sep
    Variable SepNeed
    Variable SNRWeak

    Variable XStrongU
    Variable XWeakU
    Variable YStrong
    Variable YWeak
EndStructure

Structure LJZ_PTF_Out
    WAVE Peak1K, Peak2K, Peak3K
    WAVE SigmaP1K, SigmaP2K, SigmaP3K
    WAVE AreaP1K, AreaP2K, AreaP3K, AreaSum12K
    WAVE Sep12K
    WAVE WeffP1K, WeffP2K, WeffP3K
    WAVE BGc0, BGc1, BGc2
    WAVE FitMode
    WAVE FitChi2
    WAVE/T GateReasonT
EndStructure


// ============================================================================
//  Small helpers (no p/q/r var names, round+clamp, defensive)
// ============================================================================

Function LJZ_PTF_ClampIdx(npt, idxIn)
    Variable npt, idxIn
    Variable idx

    idx = round(idxIn)
    if (idx < 0)
        idx = 0
    endif
    if (idx > npt - 1)
        idx = npt - 1
    endif
    return idx
End

Function LJZ_PTF_X2IdxClamp(wv, xval)
    Wave wv
    Variable xval

    Variable npt
    Variable idxFloat

    npt = numpnts(wv)
    idxFloat = x2pnt(wv, xval)
    return LJZ_PTF_ClampIdx(npt, idxFloat)
End


Function LJZ_PTF_CopyROI(srcW, idxStart, idxEnd, dstW)
    Wave srcW
    Variable idxStart, idxEnd
    Wave dstW

    Variable nn
    Variable jj
    Variable idx0
    Variable idx1

    nn = numpnts(srcW)
    idx0 = max(0, min(nn-1, round(idxStart)))
    idx1 = max(0, min(nn-1, round(idxEnd)))
    if (idx1 < idx0)
        Variable tSwap
        tSwap = idx0
        idx0 = idx1
        idx1 = tSwap
    endif

    if (numpnts(dstW) != (idx1 - idx0 + 1))
        Redimension/N=(idx1 - idx0 + 1) dstW
    endif

    jj = 0
    do
        if (jj >= numpnts(dstW))
            break
        endif
        dstW[jj] = srcW[idx0 + jj]
        jj += 1
    while(1)

    return 0
End


Function LJZ_PTF_EdgeMeanSigma(wv, nEdge, meanOut, sigOut)
    Wave wv
    Variable nEdge
    Variable &meanOut, &sigOut

    Variable npt
    Variable nn
    Variable jj
    Variable v
    Variable sum1
    Variable sum2
    Variable cnt
    Variable var

    npt = numpnts(wv)
    nn = round(nEdge)
    nn = max(2, min(nn, floor(npt/3)))

    sum1 = 0
    sum2 = 0
    cnt = 0

    jj = 0
    do
        if (jj >= nn)
            break
        endif
        v = wv[jj]
        if (numtype(v) == 0)
            sum1 += v
            sum2 += v*v
            cnt += 1
        endif
        jj += 1
    while(1)

    jj = 0
    do
        if (jj >= nn)
            break
        endif
        v = wv[npt-1-jj]
        if (numtype(v) == 0)
            sum1 += v
            sum2 += v*v
            cnt += 1
        endif
        jj += 1
    while(1)

    if (cnt <= 2)
        meanOut = 0
        sigOut = 0
        return 0
    endif

    meanOut = sum1 / cnt
    var = max(0, sum2/cnt - meanOut*meanOut)
    sigOut = sqrt(var)
    return 0
End


// ============================================================================
//  (2) NoiseSigmaDiff (旧版最稳健：diff + WaveStats sdev / sqrt(2))
// ============================================================================
Function LJZ_PTF_NoiseSigmaDiff(w, sigOut)
    Wave w
    Variable &sigOut

    sigOut = 0

    Variable n = numpnts(w)
    if (n < 5)
        sigOut = 0
        return 0
    endif

    // d has length n-1
    Make/FREE/N=(n-1) d
    d = w[p+1] - w[p]

    WaveStats/Q d
    sigOut = V_sdev / sqrt(2)
    sigOut = max(sigOut, 1e-12)

    return 0
End



// ============================================================================
//  (1) FindLocalMaxNearSeed  (最稳健版本：smooth + parabolic subpixel)
//      - 在平滑波 wSm 上找最大点
//      - 用 (yL,yC,yR) 做抛物线修正得到 xOut
//      - yOut 用抛物线顶点估计（不要 w(x) 插值）
// ============================================================================
Function LJZ_PTF_FindLocalMaxNearSeed(w, xSeed, win, nSmooth, xOut, yOut, ok)
    Wave w
    Variable xSeed, win, nSmooth
    Variable &xOut, &yOut, &ok

    ok  = 0
    xOut = xSeed
    yOut = NaN

    Variable n = numpnts(w)
    if (n < 5)
        return 0
    endif

    Variable dx = DimDelta(w, 0)
    if (numtype(dx) != 0 || dx == 0)
        return 0
    endif

    Duplicate/O w, wSm

    if (numtype(nSmooth) != 0)
        nSmooth = 1
    endif
    nSmooth = round(nSmooth)
    if (nSmooth >= 3)
        Smooth nSmooth, wSm
    endif

    Variable i0 = round(x2pnt(wSm, xSeed - abs(win)))
    Variable i1 = round(x2pnt(wSm, xSeed + abs(win)))

    // 防止访问 im-1, im+1 越界
    i0 = max(1, min(n-2, i0))
    i1 = max(1, min(n-2, i1))
    if (i1 < i0)
        Variable t = i0; i0 = i1; i1 = t
    endif

    Variable im = i0
    Variable vmax = -1e308
    Variable ii, v

    for (ii = i0; ii <= i1; ii += 1)
        v = wSm[ii]
        if (numtype(v) == 0 && v > vmax)
            vmax = v
            im = ii
        endif
    endfor

    if (vmax <= -1e300)
        KillWaves/Z wSm
        return 0
    endif

    Variable yL = wSm[im-1]
    Variable yC = wSm[im]
    Variable yR = wSm[im+1]

    Variable denom = (yL - 2*yC + yR)
    Variable delta = 0
    if (numtype(denom) == 0 && abs(denom) > 1e-30)
        delta = 0.5*(yL - yR)/denom
        delta = max(-0.5, min(0.5, delta))
    endif

    xOut = pnt2x(wSm, im) + delta*dx

    // 关键：不要用 wSm(xOut) 插值
    yOut = yC - 0.25*(yL - yR)*delta

    ok = 1
    KillWaves/Z wSm
    return 0
End



Function/S LJZ_PTF_HoldMaskFromIdxWave(nParam, idxWave)
    Variable nParam
    Wave idxWave

    Make/FREE/N=(nParam) holdFlag
    Variable jj
    Variable kk
    Variable idxVal
    String s

    holdFlag = 0

    kk = 0
    do
        if (kk >= numpnts(idxWave))
            break
        endif
        idxVal = round(idxWave[kk])
        if (numtype(idxVal) == 0)
            if (idxVal >= 0 && idxVal < nParam)
                holdFlag[idxVal] = 1
            endif
        endif
        kk += 1
    while(1)

    s = ""
    jj = 0
    do
        if (jj >= nParam)
            break
        endif
        if (holdFlag[jj] != 0)
            s += "1"
        else
            s += "0"
        endif
        jj += 1
    while(1)

    return s
End


// ============================================================================
//  Peak picking core (extractable): returns Pick struct in U coords
// ============================================================================

Function LJZ_PTF_Pick2PFromROI(cfg, st, wROI, seed1U, seed2U, pick)
    STRUCT LJZ_PTF_Cfg &cfg
    STRUCT LJZ_PTF_State &st
    Wave wROI
    Variable seed1U, seed2U
    STRUCT LJZ_PTF_Pick &pick

    Variable bg
    Variable sig1
    Variable sig2
    Variable sig
    Variable dx
    Variable dxA
    Variable seedSep
    Variable winPick
    Variable sepNeed
    Variable xA
    Variable yA
    Variable okA
    Variable xB
    Variable yB
    Variable okB
    Variable aA
    Variable aB
    Variable x1u
    Variable x2u
    Variable y1
    Variable y2
    Variable sep
    Variable weakAmp
    Variable snrWeak

    pick.Ok = 0
    pick.Is2P = 0

    dx = DimDelta(wROI, 0)
    if (numtype(dx) != 0 || dx == 0)
        return 0
    endif
    dxA = abs(dx)

    LJZ_PTF_EdgeMeanSigma(wROI, cfg.EdgeN, bg, sig1)
    LJZ_PTF_NoiseSigmaDiff(wROI, sig2)
    sig = max(sig1, sig2)
    sig = max(sig, 1e-12)

    seedSep = abs(seed2U - seed1U)
    seedSep = max(seedSep, 10*dxA)

    winPick = max(10*dxA, 3*cfg.ResH)
    winPick = min(winPick, 0.45*seedSep)

    sepNeed = max(3*dxA, cfg.SepFrac*seedSep)
    sepNeed = min(sepNeed, 0.80*seedSep)

    LJZ_PTF_FindLocalMaxNearSeed(wROI, seed1U, winPick, cfg.SmoothN, xA, yA, okA)
    LJZ_PTF_FindLocalMaxNearSeed(wROI, seed2U, winPick, cfg.SmoothN, xB, yB, okB)

    if (!(okA && okB))
        pick.Bg = bg
        pick.Sig = sig
        return 0
    endif

    // order by x (in U coords)
    x1u = xA
    y1 = yA
    x2u = xB
    y2 = yB
    if (x1u > x2u)
        Variable tX
        Variable tY
        tX = x1u
        x1u = x2u
        x2u = tX
        tY = y1
        y1 = y2
        y2 = tY
    endif

    aA = y1 - bg
    aB = y2 - bg

    sep = abs(x2u - x1u)
    weakAmp = min(aA, aB)
    snrWeak = weakAmp / sig

    pick.Bg = bg
    pick.Sig = sig
    pick.X1u = x1u
    pick.X2u = x2u
    pick.Y1 = y1
    pick.Y2 = y2
    pick.Sep = sep
    pick.SepNeed = sepNeed
    pick.SNRWeak = snrWeak

    // strong/weak
    pick.XStrongU = x1u
    pick.YStrong = y1
    pick.XWeakU = x2u
    pick.YWeak = y2
    if (aB > aA)
        pick.XStrongU = x2u
        pick.YStrong = y2
        pick.XWeakU = x1u
        pick.YWeak = y1
    endif

    // 2P decision
    if (sep < sepNeed)
        pick.Is2P = 0
    else
        if (snrWeak < cfg.WeakSNRThr)
            pick.Is2P = 0
        else
            pick.Is2P = 1
        endif
    endif

    pick.Ok = 1
    return 0
End


// ============================================================================
//  2P gate + store (U -> global) : strong constraints prevent "runaway fit"
// ============================================================================

Function LJZ_PTF_GateStore2P(cfg, st, out, wROI, coef2P, pick, frameIdx, xCenter, xminU, xmaxU, roiSpan, dxA)
    STRUCT LJZ_PTF_Cfg &cfg
    STRUCT LJZ_PTF_State &st
    STRUCT LJZ_PTF_Out &out
    Wave wROI
    Wave coef2P
    STRUCT LJZ_PTF_Pick &pick
    Variable frameIdx, xCenter, xminU, xmaxU, roiSpan, dxA

    Variable c0
    Variable c1
    Variable c2
    Variable H1
    Variable x1u
    Variable w1f
    Variable eta1
    Variable H2
    Variable x2u
    Variable w2f
    Variable eta2
    Variable resFit

    Variable s1
    Variable s2
    Variable sep
    Variable needSep
    Variable weakH
    Variable weakThr
    Variable maxShift
    Variable dShift1
    Variable dShift2

    Variable bgL
    Variable bgR
    Variable dL
    Variable dR
    Variable tol

    String reason

    reason = ""

    c0 = coef2P[0]
    c1 = coef2P[1]
    c2 = coef2P[2]

    H1 = coef2P[3]
    x1u = coef2P[4]
    w1f = max(0, coef2P[5])
    eta1 = coef2P[6]

    H2 = coef2P[7]
    x2u = coef2P[8]
    w2f = max(0, coef2P[9])
    eta2 = coef2P[10]

    resFit = coef2P[11]
    if (numtype(resFit) != 0 || resFit < 0)
        resFit = cfg.ResH
    endif

    if (!(numtype(x1u)==0 && numtype(x2u)==0 && numtype(H1)==0 && numtype(H2)==0))
        reason += "NAN_PARAM;"
        LJZ_PTF_SetGateReason(reason)
        return 0
    endif

    // reorder if needed
    if (x1u > x2u)
        Variable tmp
        tmp = coef2P[3]
        coef2P[3] = coef2P[7]
        coef2P[7] = tmp

        tmp = coef2P[4]
        coef2P[4] = coef2P[8]
        coef2P[8] = tmp

        tmp = coef2P[5]
        coef2P[5] = coef2P[9]
        coef2P[9] = tmp

        tmp = coef2P[6]
        coef2P[6] = coef2P[10]
        coef2P[10] = tmp

        H1 = coef2P[3]
        x1u = coef2P[4]
        w1f = max(0, coef2P[5])
        eta1 = coef2P[6]

        H2 = coef2P[7]
        x2u = coef2P[8]
        w2f = max(0, coef2P[9])
        eta2 = coef2P[10]
    endif

    if (!(x1u >= xminU && x1u <= xmaxU && x2u >= xminU && x2u <= xmaxU))
        reason += "OUTSIDE_ROI;"
        LJZ_PTF_SetGateReason(reason)
        return 0
    endif

    if (H1 <= 0 || H2 <= 0)
        reason += "NEG_HEIGHT;"
        LJZ_PTF_SetGateReason(reason)
        return 0
    endif

    s1 = LJZ_HWHM_eff(w1f, resFit)
    s2 = LJZ_HWHM_eff(w2f, resFit)

    if (s1 <= 0 || s2 <= 0)
        reason += "BAD_WIDTH;"
        LJZ_PTF_SetGateReason(reason)
        return 0
    endif

    if (s1 > 0.75*roiSpan || s2 > 0.75*roiSpan)
        reason += "WIDTH_TOO_BIG;"
        LJZ_PTF_SetGateReason(reason)
        return 0
    endif

    sep = abs(x2u - x1u)
    needSep = max(cfg.ResH, 2.5*dxA)
    if (sep < needSep)
        reason += "TOO_CLOSE;"
        LJZ_PTF_SetGateReason(reason)
        return 0
    endif

    // weak SNR threshold (use pick.Sig)
    weakH = min(H1, H2)
    weakThr = cfg.WeakSNRThr * max(pick.Sig, 1e-12)
    if (weakH < weakThr)
        reason += "WEAK_BELOW_NOISE;"
        LJZ_PTF_SetGateReason(reason)
        return 0
    endif

    // runaway position gate relative to Pick result
    maxShift = cfg.MaxShiftFrac * max(1e-12, pick.SepNeed)
    maxShift = max(maxShift, 6*dxA)
    maxShift = min(maxShift, 0.35*roiSpan)

    dShift1 = abs(x1u - pick.X1u)
    dShift2 = abs(x2u - pick.X2u)
    if (dShift1 > maxShift || dShift2 > maxShift)
        reason += "RUNAWAY_SHIFT;"
        LJZ_PTF_SetGateReason(reason)
        return 0
    endif

    // BG upturn gate (edges)
    bgL = c0 + c1*xminU + c2*xminU*xminU
    bgR = c0 + c1*xmaxU + c2*xmaxU*xmaxU

    dL = mean(wROI, xminU, xminU + 6*dxA)
    dR = mean(wROI, xmaxU - 6*dxA, xmaxU)

    tol = 3.0 * max(pick.Sig, 1e-12)
    if (bgL > dL + tol || bgR > dR + tol)
        reason += "BG_UPTURN;"
        LJZ_PTF_SetGateReason(reason)
        return 0
    endif

    // sigma check if exists
    Wave/Z sigW = $("W_sigma")
    if (WaveExists(sigW) && DimSize(sigW,0) >= 12)
        Variable sx1
        Variable sx2
        Variable sx1thr
        Variable sx2thr

        sx1 = sigW[4]
        sx2 = sigW[8]
        sx1thr = max(0.25*s1, 0.6*dxA)
        sx2thr = max(0.25*s2, 0.6*dxA)

        if (!(numtype(sx1)==0 && numtype(sx2)==0))
            reason += "SIGMA_NAN;"
            LJZ_PTF_SetGateReason(reason)
            return 0
        endif
        if (sx1 > sx1thr || sx2 > sx2thr)
            reason += "SIGMA_TOO_BIG;"
            LJZ_PTF_SetGateReason(reason)
            return 0
        endif

        out.SigmaP1K[frameIdx] = sx1
        out.SigmaP2K[frameIdx] = sx2
    else
        out.SigmaP1K[frameIdx] = NaN
        out.SigmaP2K[frameIdx] = NaN
        reason += "NO_SIGMA;"
    endif

    // store (global x)
    out.Peak1K[frameIdx] = x1u + xCenter
    out.Peak2K[frameIdx] = x2u + xCenter
    out.Peak3K[frameIdx] = NaN

    out.WeffP1K[frameIdx] = s1
    out.WeffP2K[frameIdx] = s2
    out.WeffP3K[frameIdx] = NaN

    out.Sep12K[frameIdx] = abs(out.Peak2K[frameIdx] - out.Peak1K[frameIdx])

    out.AreaP1K[frameIdx] = LJZ_PVArea_FromCoef(H1, w1f, eta1, resFit)
    out.AreaP2K[frameIdx] = LJZ_PVArea_FromCoef(H2, w2f, eta2, resFit)
    out.AreaSum12K[frameIdx] = out.AreaP1K[frameIdx] + out.AreaP2K[frameIdx]

    out.AreaP3K[frameIdx] = NaN

    out.BGc0[frameIdx] = c0
    out.BGc1[frameIdx] = c1
    out.BGc2[frameIdx] = c2

    NVAR/Z vchi = V_chisq
    if (NVAR_Exists(vchi))
        out.FitChi2[frameIdx] = vchi
    else
        out.FitChi2[frameIdx] = NaN
    endif

    out.FitMode[frameIdx] = 2

    LJZ_PTF_SetGateReason("OK2P")
    return 1
End


// ============================================================================
//  (3) Do1P : 单峰回退时只更新 seed1；seed2Fix 永远不动
//      - 删除“单峰±epsSep”重置 seed2 的逻辑
// ============================================================================
Function LJZ_PTF_Do1P(cfg, st, out, wROI, pick, frameIdx, xCenter, xminU, xmaxU, roiSpan, dxA)
    STRUCT LJZ_PTF_Cfg &cfg
    STRUCT LJZ_PTF_State &st
    STRUCT LJZ_PTF_Out &out
    Wave wROI
    STRUCT LJZ_PTF_Pick &pick
    Variable frameIdx, xCenter, xminU, xmaxU, roiSpan, dxA

    Make/FREE/N=8 c1
    Make/FREE/N=2 hIdx
    String hold1
    Variable bg0
    Variable x0u, w0f, eta0, res0
    Variable okFit
    Variable vfeVal, vfqVal

    bg0 = pick.Bg

    // BG init
    if (st.HasBG)
        c1[0] = st.C0
        c1[1] = st.C1
        c1[2] = st.C2
    else
        c1[0] = bg0
        c1[1] = 0
        c1[2] = 0
    endif

    x0u = LJZ_Clamp(pick.XStrongU, xminU, xmaxU)

    w0f = st.WSf
    w0f = max(w0f, 3*dxA)
    w0f = max(w0f, 1e-12)

    eta0 = 0.8
    res0 = cfg.ResH

    c1[3] = max(1e-9, pick.YStrong - bg0)
    c1[4] = x0u
    c1[5] = w0f
    c1[6] = eta0
    c1[7] = res0

    // hold: eta + resH
    hIdx[0] = 6
    hIdx[1] = 7
    hold1 = LJZ_PTF_HoldMaskFromIdxWave(8, hIdx)

    KillWaves/Z W_sigma

    String fitName
    fitName = "fit_layer_" + Num2Str(frameIdx)
    Duplicate/O wROI, $fitName
    FuncFit/Q/H=hold1/NTHR=0 one_pv_ljz, c1, wROI /D=$fitName

    NVAR/Z vfe = V_FitError
    NVAR/Z vfq = V_FitQuitReason
    vfeVal = 0
    vfqVal = 0
    if (NVAR_Exists(vfe))
        vfeVal = vfe
    endif
    if (NVAR_Exists(vfq))
        vfqVal = vfq
    endif

    okFit = 1
    if (vfeVal != 0 || vfqVal != 0)
        okFit = 0
    endif

    if (!(numtype(c1[4])==0 && c1[4]>=xminU && c1[4]<=xmaxU))
        okFit = 0
    endif

    if (LJZ_HWHM_eff(max(0,c1[5]), cfg.ResH) > 0.8*roiSpan)
        okFit = 0
    endif

    if (!okFit)
        out.FitMode[frameIdx] = 0
        LJZ_PTF_SetGateReason("FAIL1P")
        return 0
    endif

    // store
    out.Peak1K[frameIdx] = NaN
    out.Peak2K[frameIdx] = NaN
    out.Peak3K[frameIdx] = c1[4] + xCenter

    Wave/Z sigW = $("W_sigma")
    if (WaveExists(sigW) && DimSize(sigW,0) >= 8)
        out.SigmaP3K[frameIdx] = sigW[4]
    else
        out.SigmaP3K[frameIdx] = NaN
    endif
    out.SigmaP1K[frameIdx] = NaN
    out.SigmaP2K[frameIdx] = NaN

    out.AreaP3K[frameIdx] = LJZ_PVArea_FromCoef(c1[3], max(0,c1[5]), c1[6], c1[7])
    out.WeffP3K[frameIdx] = LJZ_HWHM_eff(max(0,c1[5]), max(0,c1[7]))

    out.AreaP1K[frameIdx] = NaN
    out.AreaP2K[frameIdx] = NaN
    out.AreaSum12K[frameIdx] = NaN
    out.Sep12K[frameIdx] = NaN

    out.BGc0[frameIdx] = c1[0]
    out.BGc1[frameIdx] = c1[1]
    out.BGc2[frameIdx] = c1[2]

    NVAR/Z vchi = V_chisq
    if (NVAR_Exists(vchi))
        out.FitChi2[frameIdx] = vchi
    else
        out.FitChi2[frameIdx] = NaN
    endif

    out.FitMode[frameIdx] = 1
    LJZ_PTF_SetGateReason("OK1P")

    // update state (EMA)
    st.HasBG = 1
    st.C0 = c1[0]
    st.C1 = c1[1]
    st.C2 = c1[2]

    st.WSf = cfg.AlphaWid*max(0,c1[5]) + (1-cfg.AlphaWid)*st.WSf

    // 关键：只更新 seed1，seed2Fix 永远不动
    st.Seed1G = out.Peak3K[frameIdx]
    st.Has2P = 0

    return 1
End



// ============================================================================
//  (4) ProcessOneFrame : ROI/选点使用 Seed1G + Seed2Fix；只更新 seed1
//      - seed2Fix = st.Seed2Fix
//      - idx2 / seed2U 全部用 seed2Fix
//      - 2P 成功后：只 EMA 更新 st.Seed1G，不更新 seed2Fix
// ============================================================================
Function LJZ_PTF_ProcessOneFrame(cfg, st, out, frameIdx)
    STRUCT LJZ_PTF_Cfg &cfg
    STRUCT LJZ_PTF_State &st
    STRUCT LJZ_PTF_Out &out
    Variable frameIdx

    String df0
    df0 = GetDataFolder(1)

    if (strlen(cfg.outDF) == 0)
        SetDataFolder df0
        return 0
    endif
    SetDataFolder $cfg.outDF

    String wavePath
    wavePath = cfg.runDF + "mdc_show_" + Num2Str(frameIdx)

    Wave/Z mdc = $wavePath
    if (!WaveExists(mdc))
        LJZ_PTF_SetGateReason("NO_WAVE")
        out.FitMode[frameIdx] = 0
        SetDataFolder df0
        return 0
    endif

    // defense
    if (WaveDims(mdc) != 1)
        LJZ_PTF_SetGateReason("BAD_DIMS")
        out.FitMode[frameIdx] = 0
        SetDataFolder df0
        return 0
    endif
    if (DimSize(mdc,0) <= 1)
        LJZ_PTF_SetGateReason("TOO_SHORT")
        out.FitMode[frameIdx] = 0
        SetDataFolder df0
        return 0
    endif
    if (WaveType(mdc) == 0)
        LJZ_PTF_SetGateReason("TEXT_WAVE")
        out.FitMode[frameIdx] = 0
        SetDataFolder df0
        return 0
    endif

    Variable ny = numpnts(mdc)
    Variable y0 = DimOffset(mdc, 0)
    Variable dy = DimDelta(mdc, 0)
    if (numtype(dy) != 0 || dy == 0)
        LJZ_PTF_SetGateReason("BAD_DY")
        out.FitMode[frameIdx] = 0
        SetDataFolder df0
        return 0
    endif
    Variable dyA = abs(dy)

    // --- fixed seed2 ---
    Variable seed1G = st.Seed1G
    Variable seed2Fix = st.Seed2Fix

    Variable idx1 = LJZ_PTF_ClampIdx(ny, x2pnt(mdc, seed1G))
    Variable idx2 = LJZ_PTF_ClampIdx(ny, x2pnt(mdc, seed2Fix))

    Variable idxMin = min(idx1, idx2)
    Variable idxMax = max(idx1, idx2)

    Variable roiStart = max(0, idxMin - cfg.fdta - cfg.ddta)
    Variable roiEnd   = min(ny-1, idxMax + cfg.bdta + cfg.ddta)

    Variable npts = roiEnd - roiStart + 1
    if (npts < 9)
        LJZ_PTF_SetGateReason("ROI_SMALL")
        out.FitMode[frameIdx] = 0
        SetDataFolder df0
        return 0
    endif

    Make/O/N=(npts) wROI
    LJZ_PTF_CopyROI(mdc, roiStart, roiEnd, wROI)

    // center ROI to U
    Variable xROI0 = y0 + roiStart*dy
    Variable xminROI = min(xROI0, xROI0 + (npts-1)*dy)
    Variable xmaxROI = max(xROI0, xROI0 + (npts-1)*dy)
    Variable xCenter = 0.5*(xminROI + xmaxROI)

    SetScale/P x, (xROI0 - xCenter), dy, wROI

    Variable xminU = xminROI - xCenter
    Variable xmaxU = xmaxROI - xCenter
    Variable roiSpan = abs((npts-1)*dy)

    Variable seed1U = seed1G - xCenter
    Variable seed2U = seed2Fix - xCenter

    // pick
    STRUCT LJZ_PTF_Pick pick
    LJZ_PTF_Pick2PFromROI(cfg, st, wROI, seed1U, seed2U, pick)

    if (!pick.Ok)
        LJZ_PTF_SetGateReason("PICK_FAIL")
        out.FitMode[frameIdx] = 0
        KillWaves/Z wROI
        SetDataFolder df0
        return 0
    endif

    // fit
    Variable ok2p = 0

    if (pick.Is2P)
        Make/FREE/N=12 c2p
        Make/FREE/N=3 hIdx
        String hold2

        Variable bg0 = pick.Bg
        if (st.HasBG)
            c2p[0] = st.C0
            c2p[1] = st.C1
            c2p[2] = st.C2
        else
            c2p[0] = bg0
            c2p[1] = 0
            c2p[2] = 0
        endif

        Variable H10 = max(1e-9, pick.Y1 - bg0)
        Variable H20 = max(1e-9, pick.Y2 - bg0)

        Variable w1f0 = max(1e-12, max(st.W1f, 3*dyA))
        Variable w2f0 = max(1e-12, max(st.W2f, 3*dyA))

        c2p[3]  = H10
        c2p[4]  = LJZ_Clamp(pick.X1u, xminU, xmaxU)
        c2p[5]  = w1f0
        c2p[6]  = 0.8

        c2p[7]  = H20
        c2p[8]  = LJZ_Clamp(pick.X2u, xminU, xmaxU)
        c2p[9]  = w2f0
        c2p[10] = 0.8

        c2p[11] = cfg.ResH

        // hold: eta1, eta2, resH （不 hold c2）
        hIdx[0] = 6
        hIdx[1] = 10
        hIdx[2] = 11
        hold2 = LJZ_PTF_HoldMaskFromIdxWave(12, hIdx)

        KillWaves/Z W_sigma

        String fitName2 = "fit_layer_" + Num2Str(frameIdx)
        Duplicate/O wROI, $fitName2
        FuncFit/Q/H=hold2/NTHR=0 two_pv_ljz, c2p, wROI /D=$fitName2

        NVAR/Z vfe = V_FitError
        NVAR/Z vfq = V_FitQuitReason
        Variable vfeVal = 0
        Variable vfqVal = 0
        if (NVAR_Exists(vfe))
            vfeVal = vfe
        endif
        if (NVAR_Exists(vfq))
            vfqVal = vfq
        endif

        if (vfeVal == 0 && vfqVal == 0)
            ok2p = LJZ_PTF_GateStore2P(cfg, st, out, wROI, c2p, pick, frameIdx, xCenter, xminU, xmaxU, roiSpan, dyA)
            if (ok2p)
                // 关键：只更新 seed1（EMA），seed2Fix 永远不动
                st.Seed1G = cfg.AlphaPos*out.Peak1K[frameIdx] + (1-cfg.AlphaPos)*st.Seed1G

                st.W1f = cfg.AlphaWid*max(0, c2p[5]) + (1-cfg.AlphaWid)*st.W1f
                st.W2f = cfg.AlphaWid*max(0, c2p[9]) + (1-cfg.AlphaWid)*st.W2f
                st.WSf = max(st.W1f, st.W2f)

                st.Has2P = 1
                st.HasBG = 1
                st.C0 = c2p[0]
                st.C1 = c2p[1]
                st.C2 = c2p[2]
            endif
        endif
    endif

    // fallback 1P
    if (!ok2p)
        LJZ_PTF_Do1P(cfg, st, out, wROI, pick, frameIdx, xCenter, xminU, xmaxU, roiSpan, dyA)
    endif

    // restore fit wave x-scale to global
    String fitNameR = "fit_layer_" + Num2Str(frameIdx)
    Wave/Z fitW = $fitNameR
    if (WaveExists(fitW))
        Variable fx0u = DimOffset(fitW, 0)
        Variable fdx  = DimDelta(fitW, 0)
        if (numtype(fdx) == 0 && fdx != 0)
            SetScale/P x, (fx0u + xCenter), fdx, fitW
        endif
    endif

    // gate reason string
    SVAR/Z gr2 = root:ARPES_LJZ:MDCFit:gLastGateReason
    if (SVAR_Exists(gr2))
        out.GateReasonT[frameIdx] = gr2
    endif

    KillWaves/Z wROI
    SetDataFolder df0
    return 0
End


// ============================================================================
//  (5) Main entry: RobustFit_UC
//      - 初始化 st.Seed2Fix = Kpeak2
//      - backward pass 也保持 Seed2Fix 固定
//      - FitMode==2 时 backward 只更新 seed1，不更新 seed2Fix
// ============================================================================
Function MDC_NdSb_LJZ_PTF_RobustFit_UC(runDF, Kpeak1, Kpeak2, ResH, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio)
    String   runDF
    Variable Kpeak1, Kpeak2, ResH, bdta, fdta, kvary, wi1, wi2, uz, ddta, WidRatio

    String df0
    df0 = GetDataFolder(1)

    if (strlen(runDF) == 0)
        DoAlert 0, "PTF_RobustFit_UC: runDF 为空"
        SetDataFolder df0
        return -1
    endif

    LJZ_EnsureMDCFitDF()
    runDF = RemoveEnding(runDF, ":") + ":"

    LJZ_PTF_SetGateReason("")

    // count frames
    Variable nt = 0
    do
        Wave/Z wTest = $(runDF + "mdc_show_" + Num2Str(nt))
        if (!WaveExists(wTest))
            break
        endif
        nt += 1
    while(1)

    if (nt <= 0)
        DoAlert 0, "PTF_RobustFit_UC: runDF 下找不到 mdc_show_0"
        SetDataFolder df0
        return -1
    endif

    Wave w0 = $(runDF + "mdc_show_0")
    if (!WaveExists(w0))
        DoAlert 0, "PTF_RobustFit_UC: mdc_show_0 不存在"
        SetDataFolder df0
        return -1
    endif

    Variable dy = DimDelta(w0, 0)
    if (numtype(dy) != 0 || dy == 0)
        DoAlert 0, "PTF_RobustFit_UC: DimDelta 非法"
        SetDataFolder df0
        return -1
    endif

    // sanitize params
    if (numtype(ddta) != 0 || ddta < 0)
        ddta = 10
    endif
    if (numtype(WidRatio) != 0 || WidRatio <= 0)
        WidRatio = 1
    endif
    if (numtype(ResH) != 0 || ResH < 0)
        ResH = 0.002
    endif

    // time axis
    Variable t0 = 0
    Variable dt = 1
    NVAR/Z g_t0 = root:ARPES_LJZ:MDCFit:Run_t0
    NVAR/Z g_dt = root:ARPES_LJZ:MDCFit:Run_dt
    if (NVAR_Exists(g_t0) && numtype(g_t0) == 0)
        t0 = g_t0
    endif
    if (NVAR_Exists(g_dt) && numtype(g_dt) == 0 && g_dt != 0)
        dt = g_dt
    endif

    // output folder
    String outDF = runDF + "FIT_PTF_Robust_UCenter:"
    String outDF0 = RemoveEnding(outDF, ":")
    NewDataFolder/O $outDF0
    SetDataFolder $outDF0

    // outputs
    Make/O/N=(nt) Peak1K, Peak2K, Peak3K
    Make/O/N=(nt) SigmaP1K, SigmaP2K, SigmaP3K
    Make/O/N=(nt) AreaP1K, AreaP2K, AreaP3K, AreaSum12K, Sep12K
    Make/O/N=(nt) WeffP1K, WeffP2K, WeffP3K
    Make/O/N=(nt) BGc0, BGc1, BGc2
    Make/O/N=(nt) FitMode, FitChi2
    Make/T/O/N=(nt) GateReasonT

    Peak1K = NaN; Peak2K = NaN; Peak3K = NaN
    SigmaP1K = NaN; SigmaP2K = NaN; SigmaP3K = NaN
    AreaP1K = NaN; AreaP2K = NaN; AreaP3K = NaN; AreaSum12K = NaN; Sep12K = NaN
    WeffP1K = NaN; WeffP2K = NaN; WeffP3K = NaN
    BGc0 = NaN; BGc1 = NaN; BGc2 = NaN
    FitMode = 0
    FitChi2 = NaN
    GateReasonT = ""

    SetScale/P x, t0, dt, Peak1K, Peak2K, Peak3K
    SetScale/P x, t0, dt, SigmaP1K, SigmaP2K, SigmaP3K
    SetScale/P x, t0, dt, AreaP1K, AreaP2K, AreaP3K, AreaSum12K, Sep12K
    SetScale/P x, t0, dt, WeffP1K, WeffP2K, WeffP3K
    SetScale/P x, t0, dt, BGc0, BGc1, BGc2
    SetScale/P x, t0, dt, FitMode, FitChi2

    // cfg
    STRUCT LJZ_PTF_Cfg cfg
    cfg.runDF = runDF
    cfg.outDF = outDF0
    cfg.ResH  = ResH
    cfg.bdta  = bdta
    cfg.fdta  = fdta
    cfg.ddta  = ddta
    cfg.WidRatio = WidRatio

    cfg.SmoothN = 7
    cfg.WeakSNRThr = 1.0
    cfg.SepFrac = 0.20

    cfg.AlphaPos = 0.85
    cfg.AlphaWid = 0.90

    cfg.MaxShiftFrac = 0.60
    cfg.EdgeN = 8

    // state
    STRUCT LJZ_PTF_State st
    st.Has2P  = 0
    st.Seed1G = Kpeak1
    st.Seed2Fix = Kpeak2     // <-- fixed forever

    st.W1f = LJZ_WfreeFromEff(max(wi1,1), ResH)
    st.W2f = LJZ_WfreeFromEff(max(wi2,1), ResH)
    st.WSf = max(st.W1f, st.W2f)

    st.HasBG = 0
    st.C0 = 0
    st.C1 = 0
    st.C2 = 0

    // out mapping
    STRUCT LJZ_PTF_Out out
    WAVE out.Peak1K = Peak1K
    WAVE out.Peak2K = Peak2K
    WAVE out.Peak3K = Peak3K
    WAVE out.SigmaP1K = SigmaP1K
    WAVE out.SigmaP2K = SigmaP2K
    WAVE out.SigmaP3K = SigmaP3K
    WAVE out.AreaP1K = AreaP1K
    WAVE out.AreaP2K = AreaP2K
    WAVE out.AreaP3K = AreaP3K
    WAVE out.AreaSum12K = AreaSum12K
    WAVE out.Sep12K = Sep12K
    WAVE out.WeffP1K = WeffP1K
    WAVE out.WeffP2K = WeffP2K
    WAVE out.WeffP3K = WeffP3K
    WAVE out.BGc0 = BGc0
    WAVE out.BGc1 = BGc1
    WAVE out.BGc2 = BGc2
    WAVE out.FitMode = FitMode
    WAVE out.FitChi2 = FitChi2
    WAVE/T out.GateReasonT = GateReasonT

    // forward
    Variable idxFrame
    for (idxFrame = 0; idxFrame < nt; idxFrame += 1)
        LJZ_PTF_ProcessOneFrame(cfg, st, out, idxFrame)
    endfor

    // backward pass (only redo frames not OK2P)
    STRUCT LJZ_PTF_State stB
    stB = st
    stB.Has2P = 0
    stB.Seed1G = Kpeak1
    stB.Seed2Fix = Kpeak2   // <-- fixed forever
    stB.HasBG = 0
    stB.C0 = 0
    stB.C1 = 0
    stB.C2 = 0
    stB.W1f = st.W1f
    stB.W2f = st.W2f
    stB.WSf = max(stB.W1f, stB.W2f)

    for (idxFrame = nt-1; idxFrame >= 0; idxFrame -= 1)

        if (FitMode[idxFrame] == 2)
            // 只更新 seed1（用 Peak1K），seed2Fix 不动
            stB.Has2P = 1
            stB.Seed1G = Peak1K[idxFrame]

            stB.HasBG = 1
            stB.C0 = BGc0[idxFrame]
            stB.C1 = BGc1[idxFrame]
            stB.C2 = BGc2[idxFrame]
        else
            LJZ_PTF_ProcessOneFrame(cfg, stB, out, idxFrame)
        endif

    endfor

    // plotting
    String bnTag = runDF
    SVAR/Z bn = root:ARPES_LJZ:MDCFit:gBaseName
    if (SVAR_Exists(bn))
        if (strlen(bn) > 0)
            bnTag = bn
        endif
    endif
    bnTag = CleanupName(bnTag, 0)

    LJZ_PTF_BuildOlapWithMarkers(runDF, bnTag, nt, kvary, Peak1K, Peak2K, Peak3K)

    String wTraj = "MDC_Traj_PTF_" + bnTag
    KillWindow/Z $wTraj
    Display/N=$wTraj Peak1K
    AppendToGraph Peak2K
    AppendToGraph Peak3K
    ModifyGraph mode=3
    ModifyGraph marker=19
    ModifyGraph msize=2
    ModifyGraph rgb(Peak1K)=(65535,0,0)
    ModifyGraph rgb(Peak2K)=(0,0,65535)
    ModifyGraph rgb(Peak3K)=(0,0,0)

    Label left, "Momentum / Angle"
    if (uz == 0)
        Label bottom, "Delay Time (ps)"
    elseif (uz == 1)
        Label bottom, "Temperature (K)"
    elseif (uz == 2)
        Label bottom, "Fluence (uJ/cm\\S2\\M)"
    else
        Label bottom, "Frame Index"
    endif

    SetDataFolder df0
    return 0
End



Function LJZ_PTF_EvalAtX(wv, xval, yOut)
    Wave wv
    Variable xval
    Variable &yOut

    Variable dx
    Variable x0
    Variable npt
    Variable idx

    yOut = NaN

    if (!WaveExists(wv))
        return 0
    endif
    if (WaveDims(wv) != 1)
        return 0
    endif
    if (WaveType(wv) == 0) // text wave
        return 0
    endif

    npt = numpnts(wv)
    if (npt < 2)
        return 0
    endif

    dx = DimDelta(wv, 0)
    x0 = DimOffset(wv, 0)

    // If scaling seems valid, use Igor interpolation wv(x)
    if (numtype(dx) == 0 && dx != 0 && numtype(x0) == 0)
        yOut = wv(xval)
        return 1
    endif

    // fallback: index-based nearest sample
    idx = round(x2pnt(wv, xval))
    idx = max(0, min(npt - 1, idx))
    yOut = wv[idx]
    return 1
End


// ---- Build olap window: raw + fit (offset by kvary) + peak markers ----
Function LJZ_PTF_BuildOlapWithMarkers(runDF, bnTag, nt, kvary, Peak1K, Peak2K, Peak3K)
    String runDF
    String bnTag
    Variable nt, kvary
    Wave Peak1K, Peak2K, Peak3K

    String df0
    df0 = GetDataFolder(1)

    Variable offY
    offY = kvary
    if (numtype(offY) != 0)
        offY = 0
    endif

    // window name
    String wOlap
    wOlap = "MDC_Olap_PTF_U_" + bnTag
    KillWindow/Z $wOlap

    // marker waves (XY pairs)
    String x1n, y1n, x2n, y2n, x3n, y3n
    x1n = "OlapPk1X_" + bnTag
    y1n = "OlapPk1Y_" + bnTag
    x2n = "OlapPk2X_" + bnTag
    y2n = "OlapPk2Y_" + bnTag
    x3n = "OlapPk3X_" + bnTag
    y3n = "OlapPk3Y_" + bnTag

    KillWaves/Z $x1n, $y1n, $x2n, $y2n, $x3n, $y3n

    Make/O/N=(nt) $x1n, $y1n, $x2n, $y2n, $x3n, $y3n
    Wave pk1x = $x1n
    Wave pk1y = $y1n
    Wave pk2x = $x2n
    Wave pk2y = $y2n
    Wave pk3x = $x3n
    Wave pk3y = $y3n

    pk1x = NaN; pk1y = NaN
    pk2x = NaN; pk2y = NaN
    pk3x = NaN; pk3y = NaN

    Variable hasFirst
    hasFirst = 0

    Variable ii
    for (ii = 0; ii < nt; ii += 1)

        String rawPath
        rawPath = runDF + "mdc_show_" + Num2Str(ii)
        Wave/Z mdcW = $rawPath
        if (!WaveExists(mdcW))
            continue
        endif

        // raw overlay
        if (hasFirst == 0)
            Display/N=$wOlap mdcW
            hasFirst = 1
            Label/W=$wOlap left, "Intensity (a.u.)"
            Label/W=$wOlap bottom, "Angle (degree)"
        else
            AppendToGraph/W=$wOlap mdcW
        endif
        ModifyGraph/W=$wOlap offset($NameOfWave(mdcW)) = {0, ii * offY}

        // fit overlay (optional)
        Wave/Z fitW = $("fit_layer_" + Num2Str(ii))
        if (WaveExists(fitW))
            AppendToGraph/W=$wOlap/C=(0,65535,0) fitW
            ModifyGraph/W=$wOlap offset($NameOfWave(fitW)) = {0, ii * offY}
        endif

        // ---- peak markers: y = raw(mdcW) at peak x + offset ----
        Variable xval, yval
        Variable okEval

        // Peak1
        xval = Peak1K[ii]
        if (numtype(xval) == 0)
            okEval = LJZ_PTF_EvalAtX(mdcW, xval, yval)
            if (okEval && numtype(yval) == 0)
                pk1x[ii] = xval
                pk1y[ii] = yval + ii * offY
            endif
        endif

        // Peak2
        xval = Peak2K[ii]
        if (numtype(xval) == 0)
            okEval = LJZ_PTF_EvalAtX(mdcW, xval, yval)
            if (okEval && numtype(yval) == 0)
                pk2x[ii] = xval
                pk2y[ii] = yval + ii * offY
            endif
        endif

        // Peak3 (single peak fallback)
        xval = Peak3K[ii]
        if (numtype(xval) == 0)
            okEval = LJZ_PTF_EvalAtX(mdcW, xval, yval)
            if (okEval && numtype(yval) == 0)
                pk3x[ii] = xval
                pk3y[ii] = yval + ii * offY
            endif
        endif

    endfor

    if (hasFirst == 0)
        SetDataFolder df0
        return 0
    endif

    // ---- append marker XY traces ----
    AppendToGraph/W=$wOlap pk1y vs pk1x
    AppendToGraph/W=$wOlap pk2y vs pk2x
    AppendToGraph/W=$wOlap pk3y vs pk3x

    // IMPORTANT: ModifyGraph takes TRACE NAMES, not wave variables
    String tr1, tr2, tr3
    tr1 = NameOfWave(pk1y)
    tr2 = NameOfWave(pk2y)
    tr3 = NameOfWave(pk3y)

    // marker-only, no lines
    ModifyGraph/W=$wOlap mode($tr1)=3, mode($tr2)=3, mode($tr3)=3
    ModifyGraph/W=$wOlap lsize($tr1)=0, lsize($tr2)=0, lsize($tr3)=0
    ModifyGraph/W=$wOlap marker($tr1)=19, marker($tr2)=19, marker($tr3)=19
    ModifyGraph/W=$wOlap msize($tr1)=2, msize($tr2)=2, msize($tr3)=2
    ModifyGraph/W=$wOlap rgb($tr1)=(65535,0,0)
    ModifyGraph/W=$wOlap rgb($tr2)=(0,0,65535)
    ModifyGraph/W=$wOlap rgb($tr3)=(0,0,0)
	ModifyGraph/W=$wOlap msize($tr1)=2, msize($tr2)=2, msize($tr3)=2
    SetDataFolder df0
    return 1
End
