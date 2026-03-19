#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Window TU_Sw6_dv4_11010375_combine_25TimesPP() : Graph
	PauseUpdate; Silent 1		// building window...
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:TU_Sw6_dv4_11010375_combine_25Times_MDC_FF3D_f58262_2L:
	Display /W=(18,79.1429,413.143,286.571) Peak1K,Peak2K,Peak3K
	SetDataFolder fldrSav0
	Label left "Position (Å\\S-1\\M)"
	ErrorBars/RGB=(0,0,0) Peak1K Y,wave=(:TU_Sw6_dv4_11010375_combine_25Times_MDC_FF3D_f58262_2L:SigmaP1K,:TU_Sw6_dv4_11010375_combine_25Times_MDC_FF3D_f58262_2L:SigmaP1K)
	ErrorBars/RGB=(0,0,0) Peak2K Y,wave=(:TU_Sw6_dv4_11010375_combine_25Times_MDC_FF3D_f58262_2L:SigmaP2K,:TU_Sw6_dv4_11010375_combine_25Times_MDC_FF3D_f58262_2L:SigmaP2K)
	ErrorBars/RGB=(0,65535,65535) Peak3K Y,wave=(:TU_Sw6_dv4_11010375_combine_25Times_MDC_FF3D_f58262_2L:SigmaP3K,:TU_Sw6_dv4_11010375_combine_25Times_MDC_FF3D_f58262_2L:SigmaP3K)
EndMacro

Function Plot_SW6_All_Delta12K()
    String outDF = "root:ARPES_LJZ:OUTPUT:A2K1D:"
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:OUTPUT
    NewDataFolder/O root:ARPES_LJZ:OUTPUT:A2K1D

    String wname = "SW6_All_Delta12K"
    DoWindow/K $wname

    // ---------- 6 条 delta 路径 ----------
    String p1 = "root:ARPES_LJZ:MDCFit:DS_Sw6_dv4_1mW_10272024_Combine0To23_RUN_MDC_f31235:FIT_TwinORSingle_GPT_BGFree_UCenter:deltak12_k"
    String p2 = "root:ARPES_LJZ:MDCFit:DS_Sw6_dv4_2mW_10271056_Combine0To24_RUN_MDC_f30234:FIT_TwinORSingle_GPT_BGFree_UCenter:deltak12_k"
    String p3 = "root:ARPES_LJZ:MDCFit:DS_Sw6_dv4_2d5mW_10291150_Combine0To23_RUN_MDC_f32236:FIT_RA:deltak12_k"
    String p4 = "root:ARPES_LJZ:MDCFit:DS_Sw6_dv4_3mW_10270484_Combine0To21_RUN_MDC_f31236:FIT_RA:deltak12_k"
    String p5 = "root:ARPES_LJZ:MDCFit:DS_Sw6_dv4_3d5mW_10291062_Combine0To24_RUN_MDC_f32235:FIT_RA:deltak12_k"
    String p6 = "root:ARPES_LJZ:MDCFit:DS_Sw6_dv4_4mW_10271496_Combine0To19_RUN_MDC_f31234:FIT_RA:deltak12_k"

    Variable first = 1

    // ===== 1 mW =====
    Wave/Z w1 = $p1
    Wave/Z ws1
    if (WaveExists(w1))
        Duplicate/O w1, $(outDF + "sw6_1mW_de12")
        Wave w1p = $(outDF + "sw6_1mW_de12")
        w1p *= 1.233

        if (first)
            Display/N=$wname w1p
            first = 0
        else
            AppendToGraph/W=$wname w1p
        endif

        String s1 = ReplaceString("deltak12_k", p1, "sigmadeltak12_k")
        Wave/Z ws1tmp = $s1
        if (WaveExists(ws1tmp))
            Duplicate/O ws1tmp, $(outDF + "sw6_1mW_sde12")
            Wave ws1p = $(outDF + "sw6_1mW_sde12")
            ws1p *= 1.233
            ErrorBars/W=$wname sw6_1mW_de12 Y,wave=(ws1p,ws1p)
        endif
    else
        Print "Missing: " + p1
    endif

    // ===== 2 mW =====
    Wave/Z w2 = $p2
    if (WaveExists(w2))
        Duplicate/O w2, $(outDF + "sw6_2mW_de12")
        Wave w2p = $(outDF + "sw6_2mW_de12")
        w2p *= 1.233
        AppendToGraph/W=$wname w2p

        String s2 = ReplaceString("deltak12_k", p2, "sigmadeltak12_k")
        Wave/Z ws2tmp = $s2
        if (WaveExists(ws2tmp))
            Duplicate/O ws2tmp, $(outDF + "sw6_2mW_sde12")
            Wave ws2p = $(outDF + "sw6_2mW_sde12")
            ws2p *= 1.233
            ErrorBars/W=$wname sw6_2mW_de12 Y,wave=(ws2p,ws2p)
        endif
    else
        Print "Missing: " + p2
    endif

    // ===== 2.5 mW =====
    Wave/Z w3 = $p3
    if (WaveExists(w3))
        Duplicate/O w3, $(outDF + "sw6_2d5mW_de12")
        Wave w3p = $(outDF + "sw6_2d5mW_de12")
        w3p *= 1.233
        AppendToGraph/W=$wname w3p

        String s3 = ReplaceString("deltak12_k", p3, "sigmadeltak12_k")
        Wave/Z ws3tmp = $s3
        if (WaveExists(ws3tmp))
            Duplicate/O ws3tmp, $(outDF + "sw6_2d5mW_sde12")
            Wave ws3p = $(outDF + "sw6_2d5mW_sde12")
            ws3p *= 1.233
            ErrorBars/W=$wname sw6_2d5mW_de12 Y,wave=(ws3p,ws3p)
        endif
    else
        Print "Missing: " + p3
    endif

    // ===== 3 mW =====
    Wave/Z w4 = $p4
    if (WaveExists(w4))
        Duplicate/O w4, $(outDF + "sw6_3mW_de12")
        Wave w4p = $(outDF + "sw6_3mW_de12")
        w4p *= 1.233
        AppendToGraph/W=$wname w4p

        String s4 = ReplaceString("deltak12_k", p4, "sigmadeltak12_k")
        Wave/Z ws4tmp = $s4
        if (WaveExists(ws4tmp))
            Duplicate/O ws4tmp, $(outDF + "sw6_3mW_sde12")
            Wave ws4p = $(outDF + "sw6_3mW_sde12")
            ws4p *= 1.233
            ErrorBars/W=$wname sw6_3mW_de12 Y,wave=(ws4p,ws4p)
        endif
    else
        Print "Missing: " + p4
    endif

    // ===== 3.5 mW =====
    Wave/Z w5 = $p5
    if (WaveExists(w5))
        Duplicate/O w5, $(outDF + "sw6_3d5mW_de12")
        Wave w5p = $(outDF + "sw6_3d5mW_de12")
        w5p *= 1.233
        AppendToGraph/W=$wname w5p

        String s5 = ReplaceString("deltak12_k", p5, "sigmadeltak12_k")
        Wave/Z ws5tmp = $s5
        if (WaveExists(ws5tmp))
            Duplicate/O ws5tmp, $(outDF + "sw6_3d5mW_sde12")
            Wave ws5p = $(outDF + "sw6_3d5mW_sde12")
            ws5p *= 1.233
            ErrorBars/W=$wname sw6_3d5mW_de12 Y,wave=(ws5p,ws5p)
        endif
    else
        Print "Missing: " + p5
    endif

    // ===== 4 mW =====
    Wave/Z w6 = $p6
    if (WaveExists(w6))
        Duplicate/O w6, $(outDF + "sw6_4mW_de12")
        Wave w6p = $(outDF + "sw6_4mW_de12")
        w6p *= 1.233
        AppendToGraph/W=$wname w6p

        String s6 = ReplaceString("deltak12_k", p6, "sigmadeltak12_k")
        Wave/Z ws6tmp = $s6
        if (WaveExists(ws6tmp))
            Duplicate/O ws6tmp, $(outDF + "sw6_4mW_sde12")
            Wave ws6p = $(outDF + "sw6_4mW_sde12")
            ws6p *= 1.233
            ErrorBars/W=$wname sw6_4mW_de12 Y,wave=(ws6p,ws6p)
        endif
    else
        Print "Missing: " + p6
    endif

    // ========================
    // 1) 整体画布与坐标轴
    // ========================
    ModifyGraph/W=$wname gbRGB=(65535,65535,65535)
    ModifyGraph/W=$wname mirror=2,standoff=0
    ModifyGraph/W=$wname axThick=1.2
    ModifyGraph/W=$wname tick=2,btLen=6
    ModifyGraph/W=$wname minor=1
    ModifyGraph/W=$wname tickUnit(left)=1,tickUnit(bottom)=1
    ModifyGraph/W=$wname fSize=16
    SetAxis/W=$wname left 0,*
    Label/W=$wname left "ΔE\\B12\\M (eV)"
    Label/W=$wname bottom "Delay Time (ps)"

    // ========================
    // 2) 各条曲线的 marker / size / color
    // ========================
    ModifyGraph/W=$wname mode(sw6_1mW_de12)=3
    ModifyGraph/W=$wname marker(sw6_1mW_de12)=19
    ModifyGraph/W=$wname msize(sw6_1mW_de12)=4
    ModifyGraph/W=$wname rgb(sw6_1mW_de12)=(0,0,0)

    ModifyGraph/W=$wname mode(sw6_2mW_de12)=3
    ModifyGraph/W=$wname marker(sw6_2mW_de12)=17
    ModifyGraph/W=$wname msize(sw6_2mW_de12)=4
    ModifyGraph/W=$wname rgb(sw6_2mW_de12)=(56000,0,0)

    ModifyGraph/W=$wname mode(sw6_2d5mW_de12)=3
    ModifyGraph/W=$wname marker(sw6_2d5mW_de12)=16
    ModifyGraph/W=$wname msize(sw6_2d5mW_de12)=4
    ModifyGraph/W=$wname rgb(sw6_2d5mW_de12)=(0,0,50000)

    ModifyGraph/W=$wname mode(sw6_3mW_de12)=3
    ModifyGraph/W=$wname marker(sw6_3mW_de12)=18
    ModifyGraph/W=$wname msize(sw6_3mW_de12)=4
    ModifyGraph/W=$wname rgb(sw6_3mW_de12)=(0,42000,12000)

    ModifyGraph/W=$wname mode(sw6_3d5mW_de12)=3
    ModifyGraph/W=$wname marker(sw6_3d5mW_de12)=8
    ModifyGraph/W=$wname msize(sw6_3d5mW_de12)=4
    ModifyGraph/W=$wname rgb(sw6_3d5mW_de12)=(42000,0,48000)

    ModifyGraph/W=$wname mode(sw6_4mW_de12)=3
    ModifyGraph/W=$wname marker(sw6_4mW_de12)=10
    ModifyGraph/W=$wname msize(sw6_4mW_de12)=4
    ModifyGraph/W=$wname rgb(sw6_4mW_de12)=(32000,18000,0)

    // ========================
    // 3) reference line
    // ========================
    Make/O/N=2 $(outDF + "ref15_x") = {-1, 104}
    Make/O/N=2 $(outDF + "ref15_y") = {0.020961, 0.020961}
    AppendToGraph/W=$wname $(outDF + "ref15_y") vs $(outDF + "ref15_x")
    ModifyGraph/W=$wname lstyle(ref15_y)=3,rgb(ref15_y)=(35000,35000,35000),lsize(ref15_y)=1.2

    // ========================
    // 4) disappearance lines + end markers
    //    从最后一个有效点垂直到 y=0
    //    空心点放在最后一个有效点本身
    // ========================
    Variable iLast, nTmp
    Variable xEnd, yEnd

    // ---- 1 mW ----
    if (WaveExists(w1p))
        iLast = -1
        if (WaveExists($(outDF + "sw6_1mW_sde12")))
            Wave ws1p2 = $(outDF + "sw6_1mW_sde12")
            nTmp = min(numpnts(w1p), numpnts(ws1p2))
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w1p[nTmp]) == 0 && numtype(ws1p2[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        else
            nTmp = numpnts(w1p)
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w1p[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        endif

        if (iLast >= 0)
            xEnd = pnt2x(w1p, iLast)
            yEnd = w1p[iLast]

            Make/O/N=2 $(outDF + "v1_x") = {xEnd, xEnd}
            Make/O/N=2 $(outDF + "v1_y") = {0, yEnd}
            AppendToGraph/W=$wname $(outDF + "v1_y") vs $(outDF + "v1_x")
            ModifyGraph/W=$wname lstyle(v1_y)=3,lsize(v1_y)=1.2,rgb(v1_y)=(0,0,0)

            Make/O/N=1 $(outDF + "m1_x") = {xEnd}
            Make/O/N=1 $(outDF + "m1_y") = {yEnd}
            AppendToGraph/W=$wname $(outDF + "m1_y") vs $(outDF + "m1_x")
            ModifyGraph/W=$wname mode(m1_y)=3,marker(m1_y)=8,msize(m1_y)=4,rgb(m1_y)=(0,0,0)
        endif
    endif

    // ---- 2 mW ----
    if (WaveExists(w2p))
        iLast = -1
        if (WaveExists($(outDF + "sw6_2mW_sde12")))
            Wave ws2p2 = $(outDF + "sw6_2mW_sde12")
            nTmp = min(numpnts(w2p), numpnts(ws2p2))
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w2p[nTmp]) == 0 && numtype(ws2p2[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        else
            nTmp = numpnts(w2p)
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w2p[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        endif

        if (iLast >= 0)
            xEnd = pnt2x(w2p, iLast)
            yEnd = w2p[iLast]

            Make/O/N=2 $(outDF + "v2_x") = {xEnd, xEnd}
            Make/O/N=2 $(outDF + "v2_y") = {0, yEnd}
            AppendToGraph/W=$wname $(outDF + "v2_y") vs $(outDF + "v2_x")
            ModifyGraph/W=$wname lstyle(v2_y)=3,lsize(v2_y)=1.2,rgb(v2_y)=(56000,0,0)

            Make/O/N=1 $(outDF + "m2_x") = {xEnd}
            Make/O/N=1 $(outDF + "m2_y") = {yEnd}
            AppendToGraph/W=$wname $(outDF + "m2_y") vs $(outDF + "m2_x")
            ModifyGraph/W=$wname mode(m2_y)=3,marker(m2_y)=8,msize(m2_y)=4,rgb(m2_y)=(56000,0,0)
        endif
    endif

    // ---- 2.5 mW ----
    if (WaveExists(w3p))
        iLast = -1
        if (WaveExists($(outDF + "sw6_2d5mW_sde12")))
            Wave ws3p2 = $(outDF + "sw6_2d5mW_sde12")
            nTmp = min(numpnts(w3p), numpnts(ws3p2))
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w3p[nTmp]) == 0 && numtype(ws3p2[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        else
            nTmp = numpnts(w3p)
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w3p[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        endif

        if (iLast >= 0)
            xEnd = pnt2x(w3p, iLast)
            yEnd = w3p[iLast]

            Make/O/N=2 $(outDF + "v3_x") = {xEnd, xEnd}
            Make/O/N=2 $(outDF + "v3_y") = {0, yEnd}
            AppendToGraph/W=$wname $(outDF + "v3_y") vs $(outDF + "v3_x")
            ModifyGraph/W=$wname lstyle(v3_y)=3,lsize(v3_y)=1.2,rgb(v3_y)=(0,0,50000)

            Make/O/N=1 $(outDF + "m3_x") = {xEnd}
            Make/O/N=1 $(outDF + "m3_y") = {yEnd}
            AppendToGraph/W=$wname $(outDF + "m3_y") vs $(outDF + "m3_x")
            ModifyGraph/W=$wname mode(m3_y)=3,marker(m3_y)=8,msize(m3_y)=4,rgb(m3_y)=(0,0,50000)
        endif
    endif

    // ---- 3 mW ----
    if (WaveExists(w4p))
        iLast = -1
        if (WaveExists($(outDF + "sw6_3mW_sde12")))
            Wave ws4p2 = $(outDF + "sw6_3mW_sde12")
            nTmp = min(numpnts(w4p), numpnts(ws4p2))
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w4p[nTmp]) == 0 && numtype(ws4p2[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        else
            nTmp = numpnts(w4p)
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w4p[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        endif

        if (iLast >= 0)
            xEnd = pnt2x(w4p, iLast)
            yEnd = w4p[iLast]

            Make/O/N=2 $(outDF + "v4_x") = {xEnd, xEnd}
            Make/O/N=2 $(outDF + "v4_y") = {0, yEnd}
            AppendToGraph/W=$wname $(outDF + "v4_y") vs $(outDF + "v4_x")
            ModifyGraph/W=$wname lstyle(v4_y)=3,lsize(v4_y)=1.2,rgb(v4_y)=(0,42000,12000)

            Make/O/N=1 $(outDF + "m4_x") = {xEnd}
            Make/O/N=1 $(outDF + "m4_y") = {yEnd}
            AppendToGraph/W=$wname $(outDF + "m4_y") vs $(outDF + "m4_x")
            ModifyGraph/W=$wname mode(m4_y)=3,marker(m4_y)=8,msize(m4_y)=4,rgb(m4_y)=(0,42000,12000)
        endif
    endif

    // ---- 3.5 mW ----
    if (WaveExists(w5p))
        iLast = -1
        if (WaveExists($(outDF + "sw6_3d5mW_sde12")))
            Wave ws5p2 = $(outDF + "sw6_3d5mW_sde12")
            nTmp = min(numpnts(w5p), numpnts(ws5p2))
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w5p[nTmp]) == 0 && numtype(ws5p2[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        else
            nTmp = numpnts(w5p)
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w5p[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        endif

        if (iLast >= 0)
            xEnd = pnt2x(w5p, iLast)
            yEnd = w5p[iLast]

            Make/O/N=2 $(outDF + "v5_x") = {xEnd, xEnd}
            Make/O/N=2 $(outDF + "v5_y") = {0, yEnd}
            AppendToGraph/W=$wname $(outDF + "v5_y") vs $(outDF + "v5_x")
            ModifyGraph/W=$wname lstyle(v5_y)=3,lsize(v5_y)=1.2,rgb(v5_y)=(42000,0,48000)

            Make/O/N=1 $(outDF + "m5_x") = {xEnd}
            Make/O/N=1 $(outDF + "m5_y") = {yEnd}
            AppendToGraph/W=$wname $(outDF + "m5_y") vs $(outDF + "m5_x")
            ModifyGraph/W=$wname mode(m5_y)=3,marker(m5_y)=8,msize(m5_y)=4,rgb(m5_y)=(42000,0,48000)
        endif
    endif

    // ---- 4 mW ----
    if (WaveExists(w6p))
        iLast = -1
        if (WaveExists($(outDF + "sw6_4mW_sde12")))
            Wave ws6p2 = $(outDF + "sw6_4mW_sde12")
            nTmp = min(numpnts(w6p), numpnts(ws6p2))
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w6p[nTmp]) == 0 && numtype(ws6p2[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        else
            nTmp = numpnts(w6p)
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w6p[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        endif

        if (iLast >= 0)
            xEnd = pnt2x(w6p, iLast)
            yEnd = w6p[iLast]

            Make/O/N=2 $(outDF + "v6_x") = {xEnd, xEnd}
            Make/O/N=2 $(outDF + "v6_y") = {0, yEnd}
            AppendToGraph/W=$wname $(outDF + "v6_y") vs $(outDF + "v6_x")
            ModifyGraph/W=$wname lstyle(v6_y)=3,lsize(v6_y)=1.2,rgb(v6_y)=(32000,18000,0)

            Make/O/N=1 $(outDF + "m6_x") = {xEnd}
            Make/O/N=1 $(outDF + "m6_y") = {yEnd}
            AppendToGraph/W=$wname $(outDF + "m6_y") vs $(outDF + "m6_x")
            ModifyGraph/W=$wname mode(m6_y)=3,marker(m6_y)=8,msize(m6_y)=4,rgb(m6_y)=(32000,18000,0)
        endif
    endif

    // ========================
    // 5) 图例
    // ========================
    Legend/W=$wname/K/N=text0
    Legend/W=$wname/C/N=text0/J/F=0/A=RT/X=2/Y=2 "\\s(sw6_1mW_de12) 60 μJ/cm\\S2\\M\r\\s(sw6_2mW_de12) 120 μJ/cm\\S2\\M\r\\s(sw6_2d5mW_de12) 150 μJ/cm\\S2\\M\r\\s(sw6_3mW_de12) 180 μJ/cm\\S2\\M\r\\s(sw6_3d5mW_de12) 210 μJ/cm\\S2\\M\r\\s(sw6_4mW_de12) 240 μJ/cm\\S2\\M"
End


Function Plot_SW6_Time_All_Delta12K()
    String outDF = "root:ARPES_LJZ:OUTPUT:A2K1D:"
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:OUTPUT
    NewDataFolder/O root:ARPES_LJZ:OUTPUT:A2K1D

    String wname = "SW6_All_Delta12K"
    DoWindow/K $wname

    Variable yMul = 1.25

    // =========================================================
    // 1) source paths
    // =========================================================
    String p60  = "root:ARPES_LJZ:MDCFit:FD_Sw6_dv4_t60_10240382_Combine0To14_RUN_MDC_f30234:FIT_DTS:deltak12_k"
    String x60  = "root:ARPES_LJZ:OUTPUT:A2K1D:t60_AxisX"

    String p100 = "root:ARPES_LJZ:MDCFit:FD_Sw6_dv4_t100_10240334_Combine0To19_RUN_MDC_f32235:FIT_RA:deltak12_k"
    String x100 = "root:ARPES_LJZ:OUTPUT:A2K1D:t100_AxisX"

    String p300 = "root:ARPES_LJZ:MDCFit:FD_Sw6_dv4_t300_10240690_Combine0To13_RUN_MDC_f30234:FIT_RA:deltak12_k"
    String x300 = "root:ARPES_LJZ:OUTPUT:A2K1D:t300_AxisX"

    String p600 = "root:ARPES_LJZ:MDCFit:FD_Sw6_dv4_t600_10251663_Combine0To19_RUN_MDC_f30234:FIT_DTS:deltak12_k"
    String x600 = "root:ARPES_LJZ:OUTPUT:A2K1D:t600_AxisX"

    String p900 = "root:ARPES_LJZ:MDCFit:FD_Sw6_dv4_t900_10252103_Combine0To19_RUN_MDC_f30234:FIT_DTS:deltak12_k"
    String x900 = "root:ARPES_LJZ:OUTPUT:A2K1D:t900_AxisX"

    Variable first = 1

    // =========================================================
    // 2) 60 ps
    // =========================================================
    Wave/Z w60src = $p60
    Wave/Z x60src = $x60
    if (WaveExists(w60src) && WaveExists(x60src))
        Duplicate/O w60src, $(outDF + "sw6_60ps_de12")
        Duplicate/O x60src, $(outDF + "sw6_60ps_x")
        Wave w60p = $(outDF + "sw6_60ps_de12")
        w60p *= 1.233
        Wave x60p = $(outDF + "sw6_60ps_x")
        w60p *= yMul

        if (first)
            Display/N=$wname w60p vs x60p
            first = 0
        else
            AppendToGraph/W=$wname w60p vs x60p
        endif

        String s60 = ReplaceString("deltak12_k", p60, "sigmadeltak12_k")
        Wave/Z ws60 = $s60
        if (WaveExists(ws60))
            Duplicate/O ws60, $(outDF + "sw6_60ps_sde12")
            Wave ws60p = $(outDF + "sw6_60ps_sde12")
            ws60p *= 1.233
            ws60p *= yMul
            ErrorBars/W=$wname sw6_60ps_de12 Y,wave=(ws60p,ws60p)
        endif
    else
        Print "Missing 60 ps: " + p60 + " or " + x60
    endif

    // =========================================================
    // 3) 100 ps
    // =========================================================
    Wave/Z w100src = $p100
    Wave/Z x100src = $x100
    if (WaveExists(w100src) && WaveExists(x100src))
        Duplicate/O w100src, $(outDF + "sw6_100ps_de12")
        Duplicate/O x100src, $(outDF + "sw6_100ps_x")
        Wave w100p = $(outDF + "sw6_100ps_de12")
        w100p *= 1.233
        Wave x100p = $(outDF + "sw6_100ps_x")
        w100p *= yMul

        AppendToGraph/W=$wname w100p vs x100p

        String s100 = ReplaceString("deltak12_k", p100, "sigmadeltak12_k")
        Wave/Z ws100 = $s100
        if (WaveExists(ws100))
            Duplicate/O ws100, $(outDF + "sw6_100ps_sde12")
            Wave ws100p = $(outDF + "sw6_100ps_sde12")
            ws100p *= 1.233
            ws100p *= yMul
            ErrorBars/W=$wname sw6_100ps_de12 Y,wave=(ws100p,ws100p)
        endif
    else
        Print "Missing 100 ps: " + p100 + " or " + x100
    endif

    // =========================================================
    // 4) 300 ps
    // =========================================================
    Wave/Z w300src = $p300
    Wave/Z x300src = $x300
    if (WaveExists(w300src) && WaveExists(x300src))
        Duplicate/O w300src, $(outDF + "sw6_300ps_de12")
        Duplicate/O x300src, $(outDF + "sw6_300ps_x")
        Wave w300p = $(outDF + "sw6_300ps_de12")
        w300p *= 1.233
        Wave x300p = $(outDF + "sw6_300ps_x")
        w300p *= yMul

        AppendToGraph/W=$wname w300p vs x300p

        String s300 = ReplaceString("deltak12_k", p300, "sigmadeltak12_k")
        Wave/Z ws300 = $s300
        if (WaveExists(ws300))
            Duplicate/O ws300, $(outDF + "sw6_300ps_sde12")
            Wave ws300p = $(outDF + "sw6_300ps_sde12")
            ws300p *= 1.233
            ws300p *= yMul
            ErrorBars/W=$wname sw6_300ps_de12 Y,wave=(ws300p,ws300p)
        endif
    else
        Print "Missing 300 ps: " + p300 + " or " + x300
    endif

    // =========================================================
    // 5) 600 ps
    // =========================================================
    Wave/Z w600src = $p600
    Wave/Z x600src = $x600
    if (WaveExists(w600src) && WaveExists(x600src))
        Duplicate/O w600src, $(outDF + "sw6_600ps_de12")
        Duplicate/O x600src, $(outDF + "sw6_600ps_x")
        Wave w600p = $(outDF + "sw6_600ps_de12")
        w600p *= 1.233
        Wave x600p = $(outDF + "sw6_600ps_x")
        w600p *= yMul

        AppendToGraph/W=$wname w600p vs x600p

        String s600 = ReplaceString("deltak12_k", p600, "sigmadeltak12_k")
        Wave/Z ws600 = $s600
        if (WaveExists(ws600))
            Duplicate/O ws600, $(outDF + "sw6_600ps_sde12")
            Wave ws600p = $(outDF + "sw6_600ps_sde12")
            ws600p *= 1.233
            ws600p *= yMul
            ErrorBars/W=$wname sw6_600ps_de12 Y,wave=(ws600p,ws600p)
        endif
    else
        Print "Missing 600 ps: " + p600 + " or " + x600
    endif

    // =========================================================
    // 6) 900 ps
    // =========================================================
    Wave/Z w900src = $p900
    Wave/Z x900src = $x900
    if (WaveExists(w900src) && WaveExists(x900src))
        Duplicate/O w900src, $(outDF + "sw6_900ps_de12")
        Duplicate/O x900src, $(outDF + "sw6_900ps_x")
        Wave w900p = $(outDF + "sw6_900ps_de12")
        w900p *= 1.233
        Wave x900p = $(outDF + "sw6_900ps_x")
        w900p *= yMul

        AppendToGraph/W=$wname w900p vs x900p

        String s900 = ReplaceString("deltak12_k", p900, "sigmadeltak12_k")
        Wave/Z ws900 = $s900
        if (WaveExists(ws900))
            Duplicate/O ws900, $(outDF + "sw6_900ps_sde12")
            Wave ws900p = $(outDF + "sw6_900ps_sde12")
            ws900p *= 1.233
            ws900p *= yMul
            ErrorBars/W=$wname sw6_900ps_de12 Y,wave=(ws900p,ws900p)
        endif
    else
        Print "Missing 900 ps: " + p900 + " or " + x900
    endif

    // ========================
    // 7) 整体画布与坐标轴
    // ========================
    ModifyGraph/W=$wname gbRGB=(65535,65535,65535)
    ModifyGraph/W=$wname mirror=2,standoff=0
    ModifyGraph/W=$wname axThick=1.2
    ModifyGraph/W=$wname tick=2,btLen=6
    ModifyGraph/W=$wname minor=1
    ModifyGraph/W=$wname tickUnit(left)=1,tickUnit(bottom)=1
    ModifyGraph/W=$wname fSize=16

    SetAxis/W=$wname left 0,*
    SetAxis/W=$wname bottom 0,252
    Label/W=$wname left "ΔE\\B12\\M (eV)"
    Label/W=$wname bottom "Fluence (μJ/cm\\S2\\M)"

    // ========================
    // 8) marker / color
    // ========================
    // 60 ps
    ModifyGraph/W=$wname mode(sw6_60ps_de12)=3
    ModifyGraph/W=$wname marker(sw6_60ps_de12)=19
    ModifyGraph/W=$wname msize(sw6_60ps_de12)=4
    ModifyGraph/W=$wname rgb(sw6_60ps_de12)=(0,0,0)

    // 100 ps
    ModifyGraph/W=$wname mode(sw6_100ps_de12)=3
    ModifyGraph/W=$wname marker(sw6_100ps_de12)=17
    ModifyGraph/W=$wname msize(sw6_100ps_de12)=4
    ModifyGraph/W=$wname rgb(sw6_100ps_de12)=(56000,0,0)

    // 300 ps
    ModifyGraph/W=$wname mode(sw6_300ps_de12)=3
    ModifyGraph/W=$wname marker(sw6_300ps_de12)=16
    ModifyGraph/W=$wname msize(sw6_300ps_de12)=4
    ModifyGraph/W=$wname rgb(sw6_300ps_de12)=(0,0,50000)

    // 600 ps
    ModifyGraph/W=$wname mode(sw6_600ps_de12)=3
    ModifyGraph/W=$wname marker(sw6_600ps_de12)=18
    ModifyGraph/W=$wname msize(sw6_600ps_de12)=4
    ModifyGraph/W=$wname rgb(sw6_600ps_de12)=(0,42000,12000)

    // 900 ps
    ModifyGraph/W=$wname mode(sw6_900ps_de12)=3
    ModifyGraph/W=$wname marker(sw6_900ps_de12)=10
    ModifyGraph/W=$wname msize(sw6_900ps_de12)=4
    ModifyGraph/W=$wname rgb(sw6_900ps_de12)=(32000,18000,0)

    // ========================
    // 9) reference line
    // ========================
    Make/O/N=2 $(outDF + "ref15_x") = {0, 260}
    Make/O/N=2 $(outDF + "ref15_y") = {0.020961*yMul, 0.020961*yMul}

    AppendToGraph/W=$wname $(outDF + "ref15_y") vs $(outDF + "ref15_x")
    ModifyGraph/W=$wname lstyle(ref15_y)=3,rgb(ref15_y)=(35000,35000,35000),lsize(ref15_y)=1.2

      // ========================
    // 10) disappearance lines + end markers
    //     竖虚线：从最后一个有效点往下到 y=0
    //     空心点：放在最后一个有效点本身
    //     判定“最后有效点”时，用 sigmadeltak12_k 是否为数值来判断
    // ========================
    Variable iLast
    Variable xEnd, yEnd

    // -------- 60 ps --------
    if (WaveExists(w60p) && WaveExists(x60p) && WaveExists(ws60p))
        iLast = -1
        Variable n60 = min(numpnts(w60p), min(numpnts(x60p), numpnts(ws60p)))
        do
            n60 -= 1
            if (n60 < 0)
                break
            endif
            if (numtype(ws60p[n60]) == 0 && numtype(w60p[n60]) == 0 && numtype(x60p[n60]) == 0)
                iLast = n60
                break
            endif
        while(1)

        if (iLast >= 0)
            xEnd = x60p[iLast]
            yEnd = w60p[iLast]

            Make/O/N=2 $(outDF + "v60_x") = {xEnd, xEnd}
            Make/O/N=2 $(outDF + "v60_y") = {0, yEnd}
            AppendToGraph/W=$wname $(outDF + "v60_y") vs $(outDF + "v60_x")
            ModifyGraph/W=$wname lstyle(v60_y)=3,lsize(v60_y)=1.2,rgb(v60_y)=(0,0,0)

            Make/O/N=1 $(outDF + "m60_x") = {xEnd}
            Make/O/N=1 $(outDF + "m60_y") = {yEnd}
            AppendToGraph/W=$wname $(outDF + "m60_y") vs $(outDF + "m60_x")
            ModifyGraph/W=$wname mode(m60_y)=3,marker(m60_y)=8,msize(m60_y)=4,rgb(m60_y)=(0,0,0)
        endif
    endif

    // -------- 100 ps --------
    if (WaveExists(w100p) && WaveExists(x100p) && WaveExists(ws100p))
        iLast = -1
        Variable n100 = min(numpnts(w100p), min(numpnts(x100p), numpnts(ws100p)))
        do
            n100 -= 1
            if (n100 < 0)
                break
            endif
            if (numtype(ws100p[n100]) == 0 && numtype(w100p[n100]) == 0 && numtype(x100p[n100]) == 0)
                iLast = n100
                break
            endif
        while(1)

        if (iLast >= 0)
            xEnd = x100p[iLast]
            yEnd = w100p[iLast]

            Make/O/N=2 $(outDF + "v100_x") = {xEnd, xEnd}
            Make/O/N=2 $(outDF + "v100_y") = {0, yEnd}
            AppendToGraph/W=$wname $(outDF + "v100_y") vs $(outDF + "v100_x")
            ModifyGraph/W=$wname lstyle(v100_y)=3,lsize(v100_y)=1.2,rgb(v100_y)=(56000,0,0)

            Make/O/N=1 $(outDF + "m100_x") = {xEnd}
            Make/O/N=1 $(outDF + "m100_y") = {yEnd}
            AppendToGraph/W=$wname $(outDF + "m100_y") vs $(outDF + "m100_x")
            ModifyGraph/W=$wname mode(m100_y)=3,marker(m100_y)=8,msize(m100_y)=4,rgb(m100_y)=(56000,0,0)
        endif
    endif

    // -------- 300 ps --------
    if (WaveExists(w300p) && WaveExists(x300p) && WaveExists(ws300p))
        iLast = -1
        Variable n300 = min(numpnts(w300p), min(numpnts(x300p), numpnts(ws300p)))
        do
            n300 -= 1
            if (n300 < 0)
                break
            endif
            if (numtype(ws300p[n300]) == 0 && numtype(w300p[n300]) == 0 && numtype(x300p[n300]) == 0)
                iLast = n300
                break
            endif
        while(1)

        if (iLast >= 0)
            xEnd = x300p[iLast]
            yEnd = w300p[iLast]

            Make/O/N=2 $(outDF + "v300_x") = {xEnd, xEnd}
            Make/O/N=2 $(outDF + "v300_y") = {0, yEnd}
            AppendToGraph/W=$wname $(outDF + "v300_y") vs $(outDF + "v300_x")
            ModifyGraph/W=$wname lstyle(v300_y)=3,lsize(v300_y)=1.2,rgb(v300_y)=(0,0,50000)

            Make/O/N=1 $(outDF + "m300_x") = {xEnd}
            Make/O/N=1 $(outDF + "m300_y") = {yEnd}
            AppendToGraph/W=$wname $(outDF + "m300_y") vs $(outDF + "m300_x")
            ModifyGraph/W=$wname mode(m300_y)=3,marker(m300_y)=8,msize(m300_y)=4,rgb(m300_y)=(0,0,50000)
        endif
    endif

    // -------- 600 ps --------
    if (WaveExists(w600p) && WaveExists(x600p) && WaveExists(ws600p))
        iLast = -1
        Variable n600 = min(numpnts(w600p), min(numpnts(x600p), numpnts(ws600p)))
        do
            n600 -= 1
            if (n600 < 0)
                break
            endif
            if (numtype(ws600p[n600]) == 0 && numtype(w600p[n600]) == 0 && numtype(x600p[n600]) == 0)
                iLast = n600
                break
            endif
        while(1)

        if (iLast >= 0)
            xEnd = x600p[iLast]
            yEnd = w600p[iLast]

            Make/O/N=2 $(outDF + "v600_x") = {xEnd, xEnd}
            Make/O/N=2 $(outDF + "v600_y") = {0, yEnd}
            AppendToGraph/W=$wname $(outDF + "v600_y") vs $(outDF + "v600_x")
            ModifyGraph/W=$wname lstyle(v600_y)=3,lsize(v600_y)=1.2,rgb(v600_y)=(0,42000,12000)

            Make/O/N=1 $(outDF + "m600_x") = {xEnd}
            Make/O/N=1 $(outDF + "m600_y") = {yEnd}
            AppendToGraph/W=$wname $(outDF + "m600_y") vs $(outDF + "m600_x")
            ModifyGraph/W=$wname mode(m600_y)=3,marker(m600_y)=8,msize(m600_y)=4,rgb(m600_y)=(0,42000,12000)
        endif
    endif

    // -------- 900 ps --------
    if (WaveExists(w900p) && WaveExists(x900p) && WaveExists(ws900p))
        iLast = -1
        Variable n900 = min(numpnts(w900p), min(numpnts(x900p), numpnts(ws900p)))
        do
            n900 -= 1
            if (n900 < 0)
                break
            endif
            if (numtype(ws900p[n900]) == 0 && numtype(w900p[n900]) == 0 && numtype(x900p[n900]) == 0)
                iLast = n900
                break
            endif
        while(1)

        if (iLast >= 0)
            xEnd = x900p[iLast]
            yEnd = w900p[iLast]

            Make/O/N=2 $(outDF + "v900_x") = {xEnd, xEnd}
            Make/O/N=2 $(outDF + "v900_y") = {0, yEnd}
            AppendToGraph/W=$wname $(outDF + "v900_y") vs $(outDF + "v900_x")
            ModifyGraph/W=$wname lstyle(v900_y)=3,lsize(v900_y)=1.2,rgb(v900_y)=(32000,18000,0)

            Make/O/N=1 $(outDF + "m900_x") = {xEnd}
            Make/O/N=1 $(outDF + "m900_y") = {yEnd}
            AppendToGraph/W=$wname $(outDF + "m900_y") vs $(outDF + "m900_x")
            ModifyGraph/W=$wname mode(m900_y)=3,marker(m900_y)=8,msize(m900_y)=4,rgb(m900_y)=(32000,18000,0)
        endif
    endif
    // ========================
    // 11) legend
    // ========================
    Legend/W=$wname/K/N=text0
    Legend/W=$wname/C/N=text0/J/F=0/A=RT/X=2/Y=2 "\\s(sw6_60ps_de12) 60 ps\r\\s(sw6_100ps_de12) 100 ps\r\\s(sw6_300ps_de12) 300 ps\r\\s(sw6_600ps_de12) 600 ps\r\\s(sw6_900ps_de12) 900 ps"
End



Function Plot_SW6_All_Delta12KwithTp()
    String outDF = "root:ARPES_LJZ:OUTPUT:A2K1D:"
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:OUTPUT
    NewDataFolder/O root:ARPES_LJZ:OUTPUT:A2K1D

    String wname = "SW6_All_Delta12K"
    DoWindow/K $wname

    // ---------- 6 条 fluence 路径 ----------
    String p1 = "root:ARPES_LJZ:MDCFit:DS_Sw6_dv4_1mW_10272024_Combine0To23_RUN_MDC_f31235:FIT_TwinORSingle_GPT_BGFree_UCenter:deltak12_k"
    String p2 = "root:ARPES_LJZ:MDCFit:DS_Sw6_dv4_2mW_10271056_Combine0To24_RUN_MDC_f30234:FIT_TwinORSingle_GPT_BGFree_UCenter:deltak12_k"
    String p3 = "root:ARPES_LJZ:MDCFit:DS_Sw6_dv4_2d5mW_10291150_Combine0To23_RUN_MDC_f32236:FIT_RA:deltak12_k"
    String p4 = "root:ARPES_LJZ:MDCFit:DS_Sw6_dv4_3mW_10270484_Combine0To21_RUN_MDC_f31236:FIT_RA:deltak12_k"
    String p5 = "root:ARPES_LJZ:MDCFit:DS_Sw6_dv4_3d5mW_10291062_Combine0To24_RUN_MDC_f32235:FIT_RA:deltak12_k"
    String p6 = "root:ARPES_LJZ:MDCFit:DS_Sw6_dv4_4mW_10271496_Combine0To19_RUN_MDC_f31234:FIT_RA:deltak12_k"

    // ---------- 温度路径（top axis 灰色背景参照） ----------
    String pT = "root:ARPES_LJZ:MDCFit:TU_Sw6_dv4_11010375_combine_25Times_RUN_MDC_f61265:FIT_RA:deltak12_k"
    String xT = "root:ARPES_LJZ:OUTPUT:A2K1D:TUSw6_AxisX"

    //============================================================
    // 0) 先建立空图窗口
    //============================================================
    Display/N=$wname

    //============================================================
    // 1) 温度数据：先加 fill，再加灰色参考线
    //    起点抬到 ~0.04，末端保持原值不变
    //============================================================
    Wave/Z wTsrc = $pT
    Wave/Z xTsrc = $xT
    if (WaveExists(wTsrc) && WaveExists(xTsrc))
        Duplicate/O wTsrc, $(outDF + "sw6_temp_de12")
        Duplicate/O xTsrc, $(outDF + "sw6_temp_x")
        Wave wTp = $(outDF + "sw6_temp_de12")
        wTp *= 1.233
        Wave xTp = $(outDF + "sw6_temp_x")

        Variable nT = numpnts(wTp)
        Variable iStart = -1, iEnd = -1
        Variable ii

        // 找第一个有效点
        for (ii=0; ii<nT; ii+=1)
            if (numtype(wTp[ii]) == 0)
                iStart = ii
                break
            endif
        endfor

        // 找最后一个有效点
        for (ii=nT-1; ii>=0; ii-=1)
            if (numtype(wTp[ii]) == 0)
                iEnd = ii
                break
            endif
        endfor

        Variable aT = 1
        Variable bT = 0

        if (iStart >= 0 && iEnd >= 0 && iStart != iEnd)
            Variable yStartRaw = wTp[iStart]
            Variable yEndRaw   = wTp[iEnd]
            Variable yStartTar = 0.041

            if (abs(yStartRaw - yEndRaw) > 1e-12)
                aT = (yStartTar - yEndRaw) / (yStartRaw - yEndRaw)
                bT = yEndRaw - aT * yEndRaw
                wTp = (numtype(wTp[p]) == 0) ? (aT*wTp[p] + bT) : NaN
            endif
        endif

        String sT = ReplaceString("deltak12_k", pT, "sigmadeltak12_k")
        Wave/Z wsTtmp = $sT
        if (WaveExists(wsTtmp))
            Duplicate/O wsTtmp, $(outDF + "sw6_temp_sde12")
            Wave wsTpErr = $(outDF + "sw6_temp_sde12")
            wsTpErr *= 1.233
            wsTpErr *= abs(aT)
        endif

        // fill 副本
        Duplicate/O wTp, $(outDF + "sw6_temp_fill")
        Wave wTfill = $(outDF + "sw6_temp_fill")

        // 先加 fill（放最底层）
        AppendToGraph/T=top/W=$wname wTfill vs xTp
        ModifyGraph/W=$wname mode(sw6_temp_fill)=7
        ModifyGraph/W=$wname rgb(sw6_temp_fill)=(62000,62000,62000)
        ModifyGraph/W=$wname lsize(sw6_temp_fill)=0.5

        // 再加灰色参考线
        AppendToGraph/T=top/W=$wname wTp vs xTp
        if (WaveExists($(outDF + "sw6_temp_sde12")))
            Wave wsTpErr2 = $(outDF + "sw6_temp_sde12")
            ErrorBars/W=$wname sw6_temp_de12 Y,wave=(wsTpErr2,wsTpErr2)
        endif
    else
        Print "Missing temperature trace: " + pT + " or " + xT
    endif

    //============================================================
    // 2) 6 条 fluence 曲线
    //============================================================

    // ===== 1 mW =====
    Wave/Z w1 = $p1
    if (WaveExists(w1))
        Duplicate/O w1, $(outDF + "sw6_1mW_de12")
        Wave w1p = $(outDF + "sw6_1mW_de12")
        w1p *= 1.233
        AppendToGraph/W=$wname w1p

        String s1 = ReplaceString("deltak12_k", p1, "sigmadeltak12_k")
        Wave/Z ws1tmp = $s1
        if (WaveExists(ws1tmp))
            Duplicate/O ws1tmp, $(outDF + "sw6_1mW_sde12")
            Wave ws1p = $(outDF + "sw6_1mW_sde12")
            ws1p *= 1.233
            ErrorBars/W=$wname sw6_1mW_de12 Y,wave=(ws1p,ws1p)
        endif
    else
        Print "Missing: " + p1
    endif

    // ===== 2 mW =====
    Wave/Z w2 = $p2
    if (WaveExists(w2))
        Duplicate/O w2, $(outDF + "sw6_2mW_de12")
        Wave w2p = $(outDF + "sw6_2mW_de12")
        w2p *= 1.233
        AppendToGraph/W=$wname w2p

        String s2 = ReplaceString("deltak12_k", p2, "sigmadeltak12_k")
        Wave/Z ws2tmp = $s2
        if (WaveExists(ws2tmp))
            Duplicate/O ws2tmp, $(outDF + "sw6_2mW_sde12")
            Wave ws2p = $(outDF + "sw6_2mW_sde12")
            ws2p *= 1.233
            ErrorBars/W=$wname sw6_2mW_de12 Y,wave=(ws2p,ws2p)
        endif
    else
        Print "Missing: " + p2
    endif

    // ===== 2.5 mW =====
    Wave/Z w3 = $p3
    if (WaveExists(w3))
        Duplicate/O w3, $(outDF + "sw6_2d5mW_de12")
        Wave w3p = $(outDF + "sw6_2d5mW_de12")
        w3p *= 1.233
        AppendToGraph/W=$wname w3p

        String s3 = ReplaceString("deltak12_k", p3, "sigmadeltak12_k")
        Wave/Z ws3tmp = $s3
        if (WaveExists(ws3tmp))
            Duplicate/O ws3tmp, $(outDF + "sw6_2d5mW_sde12")
            Wave ws3p = $(outDF + "sw6_2d5mW_sde12")
            ws3p *= 1.233
            ErrorBars/W=$wname sw6_2d5mW_de12 Y,wave=(ws3p,ws3p)
        endif
    else
        Print "Missing: " + p3
    endif

    // ===== 3 mW =====
    Wave/Z w4 = $p4
    if (WaveExists(w4))
        Duplicate/O w4, $(outDF + "sw6_3mW_de12")
        Wave w4p = $(outDF + "sw6_3mW_de12")
        w4p *= 1.233
        AppendToGraph/W=$wname w4p

        String s4 = ReplaceString("deltak12_k", p4, "sigmadeltak12_k")
        Wave/Z ws4tmp = $s4
        if (WaveExists(ws4tmp))
            Duplicate/O ws4tmp, $(outDF + "sw6_3mW_sde12")
            Wave ws4p = $(outDF + "sw6_3mW_sde12")
            ws4p *= 1.233
            ErrorBars/W=$wname sw6_3mW_de12 Y,wave=(ws4p,ws4p)
        endif
    else
        Print "Missing: " + p4
    endif

    // ===== 3.5 mW =====
    Wave/Z w5 = $p5
    if (WaveExists(w5))
        Duplicate/O w5, $(outDF + "sw6_3d5mW_de12")
        Wave w5p = $(outDF + "sw6_3d5mW_de12")
        w5p *= 1.233
        AppendToGraph/W=$wname w5p

        String s5 = ReplaceString("deltak12_k", p5, "sigmadeltak12_k")
        Wave/Z ws5tmp = $s5
        if (WaveExists(ws5tmp))
            Duplicate/O ws5tmp, $(outDF + "sw6_3d5mW_sde12")
            Wave ws5p = $(outDF + "sw6_3d5mW_sde12")
            ws5p *= 1.233
            ErrorBars/W=$wname sw6_3d5mW_de12 Y,wave=(ws5p,ws5p)
        endif
    else
        Print "Missing: " + p5
    endif

    // ===== 4 mW =====
    Wave/Z w6 = $p6
    if (WaveExists(w6))
        Duplicate/O w6, $(outDF + "sw6_4mW_de12")
        Wave w6p = $(outDF + "sw6_4mW_de12")
        w6p *= 1.233
        AppendToGraph/W=$wname w6p

        String s6 = ReplaceString("deltak12_k", p6, "sigmadeltak12_k")
        Wave/Z ws6tmp = $s6
        if (WaveExists(ws6tmp))
            Duplicate/O ws6tmp, $(outDF + "sw6_4mW_sde12")
            Wave ws6p = $(outDF + "sw6_4mW_sde12")
            ws6p *= 1.233
            ErrorBars/W=$wname sw6_4mW_de12 Y,wave=(ws6p,ws6p)
        endif
    else
        Print "Missing: " + p6
    endif



    //============================================================
    // 4) fluence 曲线样式
    //============================================================
    ModifyGraph/W=$wname mode(sw6_1mW_de12)=3
    ModifyGraph/W=$wname marker(sw6_1mW_de12)=19
    ModifyGraph/W=$wname msize(sw6_1mW_de12)=4
    ModifyGraph/W=$wname rgb(sw6_1mW_de12)=(0,0,0)

    ModifyGraph/W=$wname mode(sw6_2mW_de12)=3
    ModifyGraph/W=$wname marker(sw6_2mW_de12)=17
    ModifyGraph/W=$wname msize(sw6_2mW_de12)=4
    ModifyGraph/W=$wname rgb(sw6_2mW_de12)=(56000,0,0)

    ModifyGraph/W=$wname mode(sw6_2d5mW_de12)=3
    ModifyGraph/W=$wname marker(sw6_2d5mW_de12)=16
    ModifyGraph/W=$wname msize(sw6_2d5mW_de12)=4
    ModifyGraph/W=$wname rgb(sw6_2d5mW_de12)=(0,0,50000)

    ModifyGraph/W=$wname mode(sw6_3mW_de12)=3
    ModifyGraph/W=$wname marker(sw6_3mW_de12)=18
    ModifyGraph/W=$wname msize(sw6_3mW_de12)=4
    ModifyGraph/W=$wname rgb(sw6_3mW_de12)=(0,42000,12000)

    ModifyGraph/W=$wname mode(sw6_3d5mW_de12)=3
    ModifyGraph/W=$wname marker(sw6_3d5mW_de12)=8
    ModifyGraph/W=$wname msize(sw6_3d5mW_de12)=4
    ModifyGraph/W=$wname rgb(sw6_3d5mW_de12)=(42000,0,48000)

    ModifyGraph/W=$wname mode(sw6_4mW_de12)=3
    ModifyGraph/W=$wname marker(sw6_4mW_de12)=10
    ModifyGraph/W=$wname msize(sw6_4mW_de12)=4
    ModifyGraph/W=$wname rgb(sw6_4mW_de12)=(32000,18000,0)

    // 温度 fill 与参考线样式
    if (WaveExists($(outDF + "sw6_temp_fill")))
        ModifyGraph/W=$wname mode(sw6_temp_fill)=7
        ModifyGraph/W=$wname rgb(sw6_temp_fill)=(48059,48059,48059)
        ModifyGraph/W=$wname lsize(sw6_temp_fill)=0.5
        ModifyGraph hbFill(sw6_temp_fill)=5
    endif

    if (WaveExists($(outDF + "sw6_temp_de12")))
        ModifyGraph/W=$wname mode(sw6_temp_de12)=4
        ModifyGraph/W=$wname marker(sw6_temp_de12)=8
        ModifyGraph/W=$wname msize(sw6_temp_de12)=3
        ModifyGraph/W=$wname lstyle(sw6_temp_de12)=3
        ModifyGraph/W=$wname lsize(sw6_temp_de12)=1.2
        ModifyGraph/W=$wname rgb(sw6_temp_de12)=(30000,30000,30000)
    endif
    //============================================================
    // 3) 整体画布与坐标轴
    //============================================================
    ModifyGraph/W=$wname gbRGB=(65535,65535,65535)
    ModifyGraph/W=$wname mirror=2
    ModifyGraph/W=$wname axThick=1.2
    ModifyGraph/W=$wname tick=2
    ModifyGraph/W=$wname btLen=6
    ModifyGraph/W=$wname minor=1
    ModifyGraph/W=$wname tickUnit(left)=1,tickUnit(bottom)=1
    ModifyGraph/W=$wname fSize=16

    SetAxis/W=$wname left 0,*
    Label/W=$wname left "ΔE\\B12\\M (eV)"
    Label/W=$wname bottom "Delay Time (ps)"

    // top 轴给温度
    Label/W=$wname top "Temperature (K)"
    ModifyGraph/W=$wname freePos(top)=0
    if (WaveExists($(outDF + "sw6_temp_x")))
        Wave xTp2 = $(outDF + "sw6_temp_x")
        WaveStats/Q xTp2
        if (numtype(V_min) == 0 && numtype(V_max) == 0)
            SetAxis/W=$wname top V_min, V_max
        endif
    endif
    //============================================================
    // 5) reference line
    //============================================================
    Make/O/N=2 $(outDF + "ref15_x") = {-1, 104}
    Make/O/N=2 $(outDF + "ref15_y") = {0.020961, 0.020961}
    AppendToGraph/W=$wname $(outDF + "ref15_y") vs $(outDF + "ref15_x")
    ModifyGraph/W=$wname lstyle(ref15_y)=3,rgb(ref15_y)=(35000,35000,35000),lsize(ref15_y)=1.2

    //============================================================
    // 6) disappearance lines + end markers
    //    从最后一个有效点垂直到 y=0
    //    空心点放在最后一个有效点本身
    //============================================================
    Variable iLast, nTmp
    Variable xEnd, yEnd

    // ---- 3 mW ----
    if (WaveExists(w4p))
        iLast = -1
        if (WaveExists($(outDF + "sw6_3mW_sde12")))
            Wave ws4p2 = $(outDF + "sw6_3mW_sde12")
            nTmp = min(numpnts(w4p), numpnts(ws4p2))
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w4p[nTmp]) == 0 && numtype(ws4p2[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        else
            nTmp = numpnts(w4p)
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w4p[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        endif

        if (iLast >= 0)
            xEnd = pnt2x(w4p, iLast)
            yEnd = w4p[iLast]

            Make/O/N=2 $(outDF + "v4_x") = {xEnd, xEnd}
            Make/O/N=2 $(outDF + "v4_y") = {0, yEnd}
            AppendToGraph/W=$wname $(outDF + "v4_y") vs $(outDF + "v4_x")
            ModifyGraph/W=$wname lstyle(v4_y)=3,lsize(v4_y)=1.2,rgb(v4_y)=(0,42000,12000)

            Make/O/N=1 $(outDF + "m4_x") = {xEnd}
            Make/O/N=1 $(outDF + "m4_y") = {yEnd}
            AppendToGraph/W=$wname $(outDF + "m4_y") vs $(outDF + "m4_x")
            ModifyGraph/W=$wname mode(m4_y)=3,marker(m4_y)=8,msize(m4_y)=4,rgb(m4_y)=(0,42000,12000)
        endif
    endif

    // ---- 3.5 mW ----
    if (WaveExists(w5p))
        iLast = -1
        if (WaveExists($(outDF + "sw6_3d5mW_sde12")))
            Wave ws5p2 = $(outDF + "sw6_3d5mW_sde12")
            nTmp = min(numpnts(w5p), numpnts(ws5p2))
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w5p[nTmp]) == 0 && numtype(ws5p2[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        else
            nTmp = numpnts(w5p)
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w5p[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        endif

        if (iLast >= 0)
            xEnd = pnt2x(w5p, iLast)
            yEnd = w5p[iLast]

            Make/O/N=2 $(outDF + "v5_x") = {xEnd, xEnd}
            Make/O/N=2 $(outDF + "v5_y") = {0, yEnd}
            AppendToGraph/W=$wname $(outDF + "v5_y") vs $(outDF + "v5_x")
            ModifyGraph/W=$wname lstyle(v5_y)=3,lsize(v5_y)=1.2,rgb(v5_y)=(42000,0,48000)

            Make/O/N=1 $(outDF + "m5_x") = {xEnd}
            Make/O/N=1 $(outDF + "m5_y") = {yEnd}
            AppendToGraph/W=$wname $(outDF + "m5_y") vs $(outDF + "m5_x")
            ModifyGraph/W=$wname mode(m5_y)=3,marker(m5_y)=8,msize(m5_y)=4,rgb(m5_y)=(42000,0,48000)
        endif
    endif

    // ---- 4 mW ----
    if (WaveExists(w6p))
        iLast = -1
        if (WaveExists($(outDF + "sw6_4mW_sde12")))
            Wave ws6p2 = $(outDF + "sw6_4mW_sde12")
            nTmp = min(numpnts(w6p), numpnts(ws6p2))
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w6p[nTmp]) == 0 && numtype(ws6p2[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        else
            nTmp = numpnts(w6p)
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w6p[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
        endif

        if (iLast >= 0)
            xEnd = pnt2x(w6p, iLast)
            yEnd = w6p[iLast]

            Make/O/N=2 $(outDF + "v6_x") = {xEnd, xEnd}
            Make/O/N=2 $(outDF + "v6_y") = {0, yEnd}
            AppendToGraph/W=$wname $(outDF + "v6_y") vs $(outDF + "v6_x")
            ModifyGraph/W=$wname lstyle(v6_y)=3,lsize(v6_y)=1.2,rgb(v6_y)=(32000,18000,0)

            Make/O/N=1 $(outDF + "m6_x") = {xEnd}
            Make/O/N=1 $(outDF + "m6_y") = {yEnd}
            AppendToGraph/W=$wname $(outDF + "m6_y") vs $(outDF + "m6_x")
            ModifyGraph/W=$wname mode(m6_y)=3,marker(m6_y)=8,msize(m6_y)=4,rgb(m6_y)=(32000,18000,0)
            ModifyGraph/W=$wname standoff(left)=0,standoff(bottom)=0
            ModifyGraph tick(left)=0,tick(bottom)=0
        endif
    endif

    //============================================================
    // 7) 图例
    //============================================================
    Legend/W=$wname/K/N=text0
Legend/W=$wname/C/N=text0/J/F=0/A=RT/X=2/Y=2 "\\Zr080\\s(sw6_1mW_de12) 60 μJ/cm\\S2\\M\\Zr080\r" + \
    "\s(sw6_2mW_de12) 120 μJ/cm\\S2\\M\\Zr080\r" + \
    "\s(sw6_2d5mW_de12) 150 μJ/cm\\S2\\M\\Zr080\r" + \
    "\s(sw6_3mW_de12) 180 μJ/cm\\S2\\M\\Zr080\r" + \
    "\s(sw6_3d5mW_de12) 210 μJ/cm\\S2\\M\\Zr080\r" + \
    "\s(sw6_4mW_de12) 240 μJ/cm\\S2\\M\\Zr080\r" + \
    "\s(sw6_temp_de12) Temperature reference"
End

Function Plot_SW6_Time_All_Delta12KwithTp()
    String outDF = "root:ARPES_LJZ:OUTPUT:A2K1D:"
    NewDataFolder/O root:ARPES_LJZ
    NewDataFolder/O root:ARPES_LJZ:OUTPUT
    NewDataFolder/O root:ARPES_LJZ:OUTPUT:A2K1D

    String wname = "SW6_Time_All_Delta12K"
    DoWindow/K $wname

    Variable yMul = 1.25

    // ---------- 5 条 time 路径 ----------
    String p60  = "root:ARPES_LJZ:MDCFit:FD_Sw6_dv4_t60_10240382_Combine0To14_RUN_MDC_f30234:FIT_DTS:deltak12_k"
    String x60  = "root:ARPES_LJZ:OUTPUT:A2K1D:t60_AxisX"

    String p100 = "root:ARPES_LJZ:MDCFit:FD_Sw6_dv4_t100_10240334_Combine0To19_RUN_MDC_f32235:FIT_RA:deltak12_k"
    String x100 = "root:ARPES_LJZ:OUTPUT:A2K1D:t100_AxisX"

    String p300 = "root:ARPES_LJZ:MDCFit:FD_Sw6_dv4_t300_10240690_Combine0To13_RUN_MDC_f30234:FIT_RA:deltak12_k"
    String x300 = "root:ARPES_LJZ:OUTPUT:A2K1D:t300_AxisX"

    String p600 = "root:ARPES_LJZ:MDCFit:FD_Sw6_dv4_t600_10251663_Combine0To19_RUN_MDC_f30234:FIT_DTS:deltak12_k"
    String x600 = "root:ARPES_LJZ:OUTPUT:A2K1D:t600_AxisX"

    String p900 = "root:ARPES_LJZ:MDCFit:FD_Sw6_dv4_t900_10252103_Combine0To19_RUN_MDC_f30234:FIT_DTS:deltak12_k"
    String x900 = "root:ARPES_LJZ:OUTPUT:A2K1D:t900_AxisX"

    // ---------- 温度路径（top axis 灰色背景参照） ----------
    String pT = "root:ARPES_LJZ:MDCFit:TU_Sw6_dv4_11010375_combine_25Times_RUN_MDC_f61265:FIT_RA:deltak12_k"
    String xT = "root:ARPES_LJZ:OUTPUT:A2K1D:TUSw6_AxisX"

    //============================================================
    // 0) 先建立空图窗口
    //============================================================
    Display/N=$wname

    //============================================================
    // 1) 温度数据：先加 fill，再加灰色参考线
    //    起点抬到 ~0.041，末端保持原值不变
    //============================================================
    Wave/Z wTsrc = $pT
    Wave/Z xTsrc = $xT
    if (WaveExists(wTsrc) && WaveExists(xTsrc))
        Duplicate/O wTsrc, $(outDF + "sw6_temp_de12")
        Duplicate/O xTsrc, $(outDF + "sw6_temp_x")
        Wave wTp = $(outDF + "sw6_temp_de12")
        wTp *= 1.233
        Wave xTp = $(outDF + "sw6_temp_x")

        Variable nT = numpnts(wTp)
        Variable iStart = -1, iEnd = -1
        Variable ii

        // 找第一个有效点
        for (ii=0; ii<nT; ii+=1)
            if (numtype(wTp[ii]) == 0)
                iStart = ii
                break
            endif
        endfor

        // 找最后一个有效点
        for (ii=nT-1; ii>=0; ii-=1)
            if (numtype(wTp[ii]) == 0)
                iEnd = ii
                break
            endif
        endfor

        Variable aT = 1
        Variable bT = 0

        if (iStart >= 0 && iEnd >= 0 && iStart != iEnd)
            Variable yStartRaw = wTp[iStart]
            Variable yEndRaw   = wTp[iEnd]
            Variable yStartTar = 0.041

            if (abs(yStartRaw - yEndRaw) > 1e-12)
                aT = (yStartTar - yEndRaw) / (yStartRaw - yEndRaw)
                bT = yEndRaw - aT * yEndRaw
                wTp = (numtype(wTp[p]) == 0) ? (aT*wTp[p] + bT) : NaN
            endif
        endif

        String sT = ReplaceString("deltak12_k", pT, "sigmadeltak12_k")
        Wave/Z wsTtmp = $sT
        if (WaveExists(wsTtmp))
            Duplicate/O wsTtmp, $(outDF + "sw6_temp_sde12")
            Wave wsTpErr = $(outDF + "sw6_temp_sde12")
            wsTpErr *= 1.233
            wsTpErr *= abs(aT)
        endif

        // fill 副本
        Duplicate/O wTp, $(outDF + "sw6_temp_fill")
        Wave wTfill = $(outDF + "sw6_temp_fill")

        // 先加 fill（最底层）
        AppendToGraph/T=top/W=$wname wTfill vs xTp

        // 再加灰色参考线
        AppendToGraph/T=top/W=$wname wTp vs xTp

        if (WaveExists($(outDF + "sw6_temp_sde12")))
            Wave wsTpErr2 = $(outDF + "sw6_temp_sde12")
            ErrorBars/W=$wname sw6_temp_de12 Y,wave=(wsTpErr2, wsTpErr2)
        endif
    else
        Print "Missing temperature trace: " + pT + " or " + xT
    endif

    //============================================================
    // 2) 5 条 time 曲线
    //============================================================

    // ===== 60 ps =====
    Wave/Z w60src = $p60
    Wave/Z x60src = $x60
    if (WaveExists(w60src) && WaveExists(x60src))
        Duplicate/O w60src, $(outDF + "sw6_60ps_de12")
        Duplicate/O x60src, $(outDF + "sw6_60ps_x")
        Wave w60p = $(outDF + "sw6_60ps_de12")
        w60p *= 1.233
        Wave x60p = $(outDF + "sw6_60ps_x")
        w60p *= yMul
        AppendToGraph/W=$wname w60p vs x60p

        String s60 = ReplaceString("deltak12_k", p60, "sigmadeltak12_k")
        Wave/Z ws60tmp = $s60
        if (WaveExists(ws60tmp))
            Duplicate/O ws60tmp, $(outDF + "sw6_60ps_sde12")
            Wave ws60p = $(outDF + "sw6_60ps_sde12")
            ws60p *= 1.233
            ws60p *= yMul
            ErrorBars/W=$wname sw6_60ps_de12 Y,wave=(ws60p, ws60p)
        endif
    else
        Print "Missing 60 ps: " + p60 + " or " + x60
    endif

    // ===== 100 ps =====
    Wave/Z w100src = $p100
    Wave/Z x100src = $x100
    if (WaveExists(w100src) && WaveExists(x100src))
        Duplicate/O w100src, $(outDF + "sw6_100ps_de12")
        Duplicate/O x100src, $(outDF + "sw6_100ps_x")
        Wave w100p = $(outDF + "sw6_100ps_de12")
        w100p *= 1.233
        Wave x100p = $(outDF + "sw6_100ps_x")
        w100p *= yMul
        AppendToGraph/W=$wname w100p vs x100p

        String s100 = ReplaceString("deltak12_k", p100, "sigmadeltak12_k")
        Wave/Z ws100tmp = $s100
        if (WaveExists(ws100tmp))
            Duplicate/O ws100tmp, $(outDF + "sw6_100ps_sde12")
            Wave ws100p = $(outDF + "sw6_100ps_sde12")
            ws100p *= 1.233
            ws100p *= yMul
            ErrorBars/W=$wname sw6_100ps_de12 Y,wave=(ws100p, ws100p)
        endif
    else
        Print "Missing 100 ps: " + p100 + " or " + x100
    endif

    // ===== 300 ps =====
    Wave/Z w300src = $p300
    Wave/Z x300src = $x300
    if (WaveExists(w300src) && WaveExists(x300src))
        Duplicate/O w300src, $(outDF + "sw6_300ps_de12")
        Duplicate/O x300src, $(outDF + "sw6_300ps_x")
        Wave w300p = $(outDF + "sw6_300ps_de12")
        w300p *= 1.233
        Wave x300p = $(outDF + "sw6_300ps_x")
        w300p *= yMul
        AppendToGraph/W=$wname w300p vs x300p

        String s300 = ReplaceString("deltak12_k", p300, "sigmadeltak12_k")
        Wave/Z ws300tmp = $s300
        if (WaveExists(ws300tmp))
            Duplicate/O ws300tmp, $(outDF + "sw6_300ps_sde12")
            Wave ws300p = $(outDF + "sw6_300ps_sde12")
            ws300p *= 1.233
            ws300p *= yMul
            ErrorBars/W=$wname sw6_300ps_de12 Y,wave=(ws300p, ws300p)
        endif
    else
        Print "Missing 300 ps: " + p300 + " or " + x300
    endif

    // ===== 600 ps =====
    Wave/Z w600src = $p600
    Wave/Z x600src = $x600
    if (WaveExists(w600src) && WaveExists(x600src))
        Duplicate/O w600src, $(outDF + "sw6_600ps_de12")
        Duplicate/O x600src, $(outDF + "sw6_600ps_x")
        Wave w600p = $(outDF + "sw6_600ps_de12")
        w600p *= 1.233
        Wave x600p = $(outDF + "sw6_600ps_x")
        w600p *= yMul
        AppendToGraph/W=$wname w600p vs x600p

        String s600 = ReplaceString("deltak12_k", p600, "sigmadeltak12_k")
        Wave/Z ws600tmp = $s600
        if (WaveExists(ws600tmp))
            Duplicate/O ws600tmp, $(outDF + "sw6_600ps_sde12")
            Wave ws600p = $(outDF + "sw6_600ps_sde12")
            ws600p *= 1.233
            ws600p *= yMul
            ErrorBars/W=$wname sw6_600ps_de12 Y,wave=(ws600p, ws600p)
        endif
    else
        Print "Missing 600 ps: " + p600 + " or " + x600
    endif

    // ===== 900 ps =====
    Wave/Z w900src = $p900
    Wave/Z x900src = $x900
    if (WaveExists(w900src) && WaveExists(x900src))
        Duplicate/O w900src, $(outDF + "sw6_900ps_de12")
        Duplicate/O x900src, $(outDF + "sw6_900ps_x")
        Wave w900p = $(outDF + "sw6_900ps_de12")
        w900p *= 1.233
        Wave x900p = $(outDF + "sw6_900ps_x")
        w900p *= yMul
        AppendToGraph/W=$wname w900p vs x900p

        String s900 = ReplaceString("deltak12_k", p900, "sigmadeltak12_k")
        Wave/Z ws900tmp = $s900
        if (WaveExists(ws900tmp))
            Duplicate/O ws900tmp, $(outDF + "sw6_900ps_sde12")
            Wave ws900p = $(outDF + "sw6_900ps_sde12")
            ws900p *= 1.233
            ws900p *= yMul
            ErrorBars/W=$wname sw6_900ps_de12 Y,wave=(ws900p, ws900p)
        endif
    else
        Print "Missing 900 ps: " + p900 + " or " + x900
    endif

    //============================================================
    // 3) 曲线样式
    //============================================================

    // 温度 fill 与参考线
    if (WaveExists($(outDF + "sw6_temp_fill")))
        ModifyGraph/W=$wname mode(sw6_temp_fill)=7
        ModifyGraph/W=$wname rgb(sw6_temp_fill)=(48059,48059,48059)
        ModifyGraph/W=$wname lsize(sw6_temp_fill)=0.5
        ModifyGraph hbFill(sw6_temp_fill)=5
    endif

    if (WaveExists($(outDF + "sw6_temp_de12")))
        ModifyGraph/W=$wname mode(sw6_temp_de12)=4
        ModifyGraph/W=$wname marker(sw6_temp_de12)=8
        ModifyGraph/W=$wname msize(sw6_temp_de12)=3
        ModifyGraph/W=$wname lstyle(sw6_temp_de12)=3
        ModifyGraph/W=$wname lsize(sw6_temp_de12)=1.2
        ModifyGraph/W=$wname rgb(sw6_temp_de12)=(30000,30000,30000)
    endif

    // 60 ps
    ModifyGraph/W=$wname mode(sw6_60ps_de12)=3
    ModifyGraph/W=$wname marker(sw6_60ps_de12)=19
    ModifyGraph/W=$wname msize(sw6_60ps_de12)=4
    ModifyGraph/W=$wname rgb(sw6_60ps_de12)=(0,0,0)

    // 100 ps
    ModifyGraph/W=$wname mode(sw6_100ps_de12)=3
    ModifyGraph/W=$wname marker(sw6_100ps_de12)=17
    ModifyGraph/W=$wname msize(sw6_100ps_de12)=4
    ModifyGraph/W=$wname rgb(sw6_100ps_de12)=(56000,0,0)

    // 300 ps
    ModifyGraph/W=$wname mode(sw6_300ps_de12)=3
    ModifyGraph/W=$wname marker(sw6_300ps_de12)=16
    ModifyGraph/W=$wname msize(sw6_300ps_de12)=4
    ModifyGraph/W=$wname rgb(sw6_300ps_de12)=(0,0,50000)

    // 600 ps
    ModifyGraph/W=$wname mode(sw6_600ps_de12)=3
    ModifyGraph/W=$wname marker(sw6_600ps_de12)=18
    ModifyGraph/W=$wname msize(sw6_600ps_de12)=4
    ModifyGraph/W=$wname rgb(sw6_600ps_de12)=(0,42000,12000)

    // 900 ps
    ModifyGraph/W=$wname mode(sw6_900ps_de12)=3
    ModifyGraph/W=$wname marker(sw6_900ps_de12)=10
    ModifyGraph/W=$wname msize(sw6_900ps_de12)=4
    ModifyGraph/W=$wname rgb(sw6_900ps_de12)=(32000,18000,0)

    //============================================================
    // 4) 整体画布与坐标轴
    //============================================================
    ModifyGraph/W=$wname gbRGB=(65535,65535,65535)
    ModifyGraph/W=$wname mirror=2
    ModifyGraph/W=$wname axThick=1.2
    ModifyGraph/W=$wname tick=2
    ModifyGraph/W=$wname btLen=6
    ModifyGraph/W=$wname minor=1
    ModifyGraph/W=$wname tickUnit(left)=1,tickUnit(bottom)=1
    ModifyGraph/W=$wname fSize=16
    ModifyGraph/W=$wname standoff(left)=0,standoff(bottom)=0

    SetAxis/W=$wname left 0,*
    SetAxis/W=$wname bottom 0,252
    Label/W=$wname left "ΔE\\B12\\M (eV)"
    Label/W=$wname bottom "Fluence (μJ/cm\\S2\\M)"

    // top 轴给温度
    Label/W=$wname top "Temperature (K)"
    ModifyGraph/W=$wname freePos(top)=0
    if (WaveExists($(outDF + "sw6_temp_x")))
        Wave xTp2 = $(outDF + "sw6_temp_x")
        WaveStats/Q xTp2
        if (numtype(V_min) == 0 && numtype(V_max) == 0)
            SetAxis/W=$wname top V_min, V_max
        endif
    endif

    //============================================================
    // 5) reference line
    //============================================================
    Make/O/N=2 $(outDF + "ref15_x") = {0, 260}
    Make/O/N=2 $(outDF + "ref15_y") = {0.020961, 0.020961}
    AppendToGraph/W=$wname $(outDF + "ref15_y") vs $(outDF + "ref15_x")
    ModifyGraph/W=$wname lstyle(ref15_y)=3
    ModifyGraph/W=$wname rgb(ref15_y)=(35000,35000,35000)
    ModifyGraph/W=$wname lsize(ref15_y)=1.2

    //============================================================
    // 6) disappearance lines + end markers
    //    从最后一个有效点垂直到 y=0
    //    空心点放在最后一个有效点本身
    //============================================================
    Variable iLast, nTmp
    Variable xEnd, yEnd

    // ---- 60 ps ----
    if (WaveExists($(outDF + "sw6_60ps_de12")))
        Wave w60p2 = $(outDF + "sw6_60ps_de12")
        iLast = -1
        if (WaveExists($(outDF + "sw6_60ps_sde12")) && WaveExists($(outDF + "sw6_60ps_x")))
            Wave ws60p2 = $(outDF + "sw6_60ps_sde12")
            Wave x60p2  = $(outDF + "sw6_60ps_x")
            nTmp = min(numpnts(w60p2), min(numpnts(ws60p2), numpnts(x60p2)))
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w60p2[nTmp]) == 0 && numtype(ws60p2[nTmp]) == 0 && numtype(x60p2[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
            if (iLast >= 0)
                xEnd = x60p2[iLast]
                yEnd = w60p2[iLast]

                Make/O/N=2 $(outDF + "v60_x") = {xEnd, xEnd}
                Make/O/N=2 $(outDF + "v60_y") = {0, yEnd}
                AppendToGraph/W=$wname $(outDF + "v60_y") vs $(outDF + "v60_x")
                ModifyGraph/W=$wname lstyle(v60_y)=3,lsize(v60_y)=1.2,rgb(v60_y)=(0,0,0)

                Make/O/N=1 $(outDF + "m60_x") = {xEnd}
                Make/O/N=1 $(outDF + "m60_y") = {yEnd}
                AppendToGraph/W=$wname $(outDF + "m60_y") vs $(outDF + "m60_x")
                ModifyGraph/W=$wname mode(m60_y)=3,marker(m60_y)=8,msize(m60_y)=4,rgb(m60_y)=(0,0,0)
            endif
        endif
    endif

    // ---- 100 ps ----
    if (WaveExists($(outDF + "sw6_100ps_de12")))
        Wave w100p2 = $(outDF + "sw6_100ps_de12")
        iLast = -1
        if (WaveExists($(outDF + "sw6_100ps_sde12")) && WaveExists($(outDF + "sw6_100ps_x")))
            Wave ws100p2 = $(outDF + "sw6_100ps_sde12")
            Wave x100p2  = $(outDF + "sw6_100ps_x")
            nTmp = min(numpnts(w100p2), min(numpnts(ws100p2), numpnts(x100p2)))
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w100p2[nTmp]) == 0 && numtype(ws100p2[nTmp]) == 0 && numtype(x100p2[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
            if (iLast >= 0)
                xEnd = x100p2[iLast]
                yEnd = w100p2[iLast]

                Make/O/N=2 $(outDF + "v100_x") = {xEnd, xEnd}
                Make/O/N=2 $(outDF + "v100_y") = {0, yEnd}
                AppendToGraph/W=$wname $(outDF + "v100_y") vs $(outDF + "v100_x")
                ModifyGraph/W=$wname lstyle(v100_y)=3,lsize(v100_y)=1.2,rgb(v100_y)=(56000,0,0)

                Make/O/N=1 $(outDF + "m100_x") = {xEnd}
                Make/O/N=1 $(outDF + "m100_y") = {yEnd}
                AppendToGraph/W=$wname $(outDF + "m100_y") vs $(outDF + "m100_x")
                ModifyGraph/W=$wname mode(m100_y)=3,marker(m100_y)=8,msize(m100_y)=4,rgb(m100_y)=(56000,0,0)
            endif
        endif
    endif

    // ---- 300 ps ----
    if (WaveExists($(outDF + "sw6_300ps_de12")))
        Wave w300p2 = $(outDF + "sw6_300ps_de12")
        iLast = -1
        if (WaveExists($(outDF + "sw6_300ps_sde12")) && WaveExists($(outDF + "sw6_300ps_x")))
            Wave ws300p2 = $(outDF + "sw6_300ps_sde12")
            Wave x300p2  = $(outDF + "sw6_300ps_x")
            nTmp = min(numpnts(w300p2), min(numpnts(ws300p2), numpnts(x300p2)))
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w300p2[nTmp]) == 0 && numtype(ws300p2[nTmp]) == 0 && numtype(x300p2[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
            if (iLast >= 0)
                xEnd = x300p2[iLast]
                yEnd = w300p2[iLast]

                Make/O/N=2 $(outDF + "v300_x") = {xEnd, xEnd}
                Make/O/N=2 $(outDF + "v300_y") = {0, yEnd}
                AppendToGraph/W=$wname $(outDF + "v300_y") vs $(outDF + "v300_x")
                ModifyGraph/W=$wname lstyle(v300_y)=3,lsize(v300_y)=1.2,rgb(v300_y)=(0,0,50000)

                Make/O/N=1 $(outDF + "m300_x") = {xEnd}
                Make/O/N=1 $(outDF + "m300_y") = {yEnd}
                AppendToGraph/W=$wname $(outDF + "m300_y") vs $(outDF + "m300_x")
                ModifyGraph/W=$wname mode(m300_y)=3,marker(m300_y)=8,msize(m300_y)=4,rgb(m300_y)=(0,0,50000)
            endif
        endif
    endif

    // ---- 600 ps ----
    if (WaveExists($(outDF + "sw6_600ps_de12")))
        Wave w600p2 = $(outDF + "sw6_600ps_de12")
        iLast = -1
        if (WaveExists($(outDF + "sw6_600ps_sde12")) && WaveExists($(outDF + "sw6_600ps_x")))
            Wave ws600p2 = $(outDF + "sw6_600ps_sde12")
            Wave x600p2  = $(outDF + "sw6_600ps_x")
            nTmp = min(numpnts(w600p2), min(numpnts(ws600p2), numpnts(x600p2)))
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w600p2[nTmp]) == 0 && numtype(ws600p2[nTmp]) == 0 && numtype(x600p2[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
            if (iLast >= 0)
                xEnd = x600p2[iLast]
                yEnd = w600p2[iLast]

                Make/O/N=2 $(outDF + "v600_x") = {xEnd, xEnd}
                Make/O/N=2 $(outDF + "v600_y") = {0, yEnd}
                AppendToGraph/W=$wname $(outDF + "v600_y") vs $(outDF + "v600_x")
                ModifyGraph/W=$wname lstyle(v600_y)=3,lsize(v600_y)=1.2,rgb(v600_y)=(0,42000,12000)

                Make/O/N=1 $(outDF + "m600_x") = {xEnd}
                Make/O/N=1 $(outDF + "m600_y") = {yEnd}
                AppendToGraph/W=$wname $(outDF + "m600_y") vs $(outDF + "m600_x")
                ModifyGraph/W=$wname mode(m600_y)=3,marker(m600_y)=8,msize(m600_y)=4,rgb(m600_y)=(0,42000,12000)
            endif
        endif
    endif

    // ---- 900 ps ----
    if (WaveExists($(outDF + "sw6_900ps_de12")))
        Wave w900p2 = $(outDF + "sw6_900ps_de12")
        iLast = -1
        if (WaveExists($(outDF + "sw6_900ps_sde12")) && WaveExists($(outDF + "sw6_900ps_x")))
            Wave ws900p2 = $(outDF + "sw6_900ps_sde12")
            Wave x900p2  = $(outDF + "sw6_900ps_x")
            nTmp = min(numpnts(w900p2), min(numpnts(ws900p2), numpnts(x900p2)))
            do
                nTmp -= 1
                if (nTmp < 0)
                    break
                endif
                if (numtype(w900p2[nTmp]) == 0 && numtype(ws900p2[nTmp]) == 0 && numtype(x900p2[nTmp]) == 0)
                    iLast = nTmp
                    break
                endif
            while(1)
            if (iLast >= 0)
                xEnd = x900p2[iLast]
                yEnd = w900p2[iLast]

                Make/O/N=2 $(outDF + "v900_x") = {xEnd, xEnd}
                Make/O/N=2 $(outDF + "v900_y") = {0, yEnd}
                AppendToGraph/W=$wname $(outDF + "v900_y") vs $(outDF + "v900_x")
                ModifyGraph/W=$wname lstyle(v900_y)=3,lsize(v900_y)=1.2,rgb(v900_y)=(32000,18000,0)

                Make/O/N=1 $(outDF + "m900_x") = {xEnd}
                Make/O/N=1 $(outDF + "m900_y") = {yEnd}
                AppendToGraph/W=$wname $(outDF + "m900_y") vs $(outDF + "m900_x")
                ModifyGraph/W=$wname mode(m900_y)=3,marker(m900_y)=8,msize(m900_y)=4,rgb(m900_y)=(32000,18000,0)
            endif
        endif
    endif
    ModifyGraph tick(left)=0,tick(bottom)=0
    //============================================================
    // 7) 图例
    //============================================================
    Legend/W=$wname/K/N=text0
    Legend/W=$wname/C/N=text0/J/F=0/A=RT/X=2/Y=2 "\\Zr080\\s(sw6_60ps_de12) 60 ps\r" + \
        "\s(sw6_100ps_de12) 100 ps\r" + \
        "\s(sw6_300ps_de12) 300 ps\r" + \
        "\s(sw6_600ps_de12) 600 ps\r" + \
        "\s(sw6_900ps_de12) 900 ps\r" + \
        "\s(sw6_temp_de12) Temperature reference"
End
