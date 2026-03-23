#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// 定义一个函数来反转 3D Wave 的 z 轴
Function ReverseZAxis(wave3D)
    Wave wave3D  // 传入的 3D Wave

    // 获取 Wave 的维度信息
    Variable numLayers = DimSize(wave3D, 2)  // z 轴的层数

    // 创建一个临时 Wave 来存储反转后的数据
    Make/O/N=(DimSize(wave3D, 0), DimSize(wave3D, 1), numLayers) tempWave

    // 反转 z 轴
    Variable i, j, k
    for(i = 0; i < DimSize(wave3D, 0); i += 1)
        for(j = 0; j < DimSize(wave3D, 1); j += 1)
            for(k = 0; k < numLayers; k += 1)
                tempWave[i][j][k] = wave3D[i][j][numLayers - 1 - k]
            endfor
        endfor
    endfor

    // 将反转后的数据复制回原 Wave
    Duplicate tempwave,$nameofWave(wave3D)+"reverse"
End



Function Show4Layers_LJZ250218(w, l1, l2, l3, l4,Ef)
    Wave w                 // 3D 输入 Wave
    Variable l1, l2, l3, l4,ef  // 需要显示的图层序号
    
    // [^1]
    if(WaveDims(w) != 3)
        Abort "输入 Wave 必须是 3D Wave"
    endif
    
    Variable maxLayer = DimSize(w,2)-1
    if(l1 > maxLayer || l2 > maxLayer || l3 > maxLayer || l4 > maxLayer)
        Abort "层数值超过 Wave 维度"
    endif
    
    // 创建布局窗口
    String windName = "LayerComparison"+nameofwave(w)
    DoWindow/K $windName
    NewLayout/N=$windName/P=LANDSCAPE/K=1
    
    // [^2]
    Variable minVal = WaveMin(w)
    Variable maxVal = WaveMax(w)
    newDataFolder/o $nameofwave(w)+"4show"
    SetDataFolder $nameofwave(w)+"4show"
    // 创建临时 2D Waves 并继承轴信息
    Make/O/N=(DimSize(w,0),DimSize(w,1)) layer0,layer1,layer2,layer3
    layer0[][]= w[p][q][l1]
    layer1[][]= w[p][q][l2]
    layer2[][]= w[p][q][l3]
    layer3[][]= w[p][q][l4]
    
    // 转置并调整轴信息
//    MatrixTranspose layer0; 
   SetScale/P x DimOffset(w,0), DimDelta(w,0), layer0
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer0
//    MatrixTranspose layer1; 
   SetScale/P x DimOffset(w,0), DimDelta(w,0), layer1
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer1
//    MatrixTranspose layer2; 
   SetScale/P x DimOffset(w,0), DimDelta(w,0), layer2
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer2
//    MatrixTranspose layer3; 
   SetScale/P x DimOffset(w,0), DimDelta(w,0), layer3
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer3
    
    // [^3]
    Variable graphWidth = 180
    Variable graphHeight = 200
    Variable spacing = 20
    
    // 创建四个并列显示的子图
    Variable i
    for(i=0; i<4; i+=1)
    String plotName = "plot"+num2str(i)+nameofWave(w)
    
    // [^1] 先创建独立显示器
    Display/W=(0,0,graphWidth,graphHeight)/N=$plotName 
    
    // [^2] 必须完成图像渲染后再加入布局
    AppendImage $("layer"+num2str(i))
    ModifyImage $("layer"+num2str(i)) ctab= {minVal,maxVal/2,BlueBlackRed,0}
// 左轴标签（带粗体符号）
Label left "E-E\\Bf \\M (eV)"  // 双反斜杠转义粗体指令[^1]

// 横轴标签（带单位上标）
Label bottom "k\\B// \\M(Å\\S-1\\M)"  // 符号字体+上标组合[^2]
ModifyGraph zero(left)=4
    Textbox/F=0/A=MT "Layer "+num2istr(GetLayerIndex(i, l1, l2, l3, l4))
    Variable xStart = i * (graphWidth + spacing)
//    // [^3] 添加已包含内容的子图到布局
    AppendLayoutObject/R=(xStart,0,xStart+graphWidth,graphHeight) /W=$windName/F=0 graph $plotName
endfor

    
    // 统一坐标轴设置
    SetWindow $windName hook(myscaler)=ScaleAllAxes
End

// [^4]
Static Function ScaleAllAxes(s)
    STRUCT WMWinHookStruct &s
    if(s.eventCode == 6)  
        Variable i
        for(i=0; i<4; i+=1)
            // [^1]
            String subWinPath = s.winName + "#plot" + num2str(i)
            
            // [^2] 自动缩放主坐标轴
            SetAxis/W=$subWinPath/A left
            SetAxis/W=$subWinPath/A bottom
        endfor
    endif
    return 0
End

Static Function GetLayerIndex(i, l1, l2, l3, l4)
    Variable i, l1, l2, l3, l4
    if(i == 0)
        return l1
    elseif(i == 1)
        return l2
    elseif(i == 2)
        return l3
    else
        return l4   // 当i=3时自动指向l4
    endif
End

Function onelor_ljz(w, x) : FitFunc
    Wave w  // 系数波结构：w[0]=const, w[1]=coef, w[2]=amp1, w[3]=peak1, w[4]=width1
    Variable x
    
    return w[0] + w[1]*x + w[5]*x^2 + w[2]/((x - w[3])^2 + w[4]^2)  // 组合线性项与洛伦兹峰[^1]
End

Function Show8Layers_LJZ250218(w, l1, l2, l3, l4,l5,l6,l7,l8)
    Wave w                 // 3D 输入 Wave
    Variable l1, l2, l3, l4,l5,l6,l7,l8 // 需要显示的图层序号
    DFREF saveDFR = GetDataFolderDFR()	
    // [^1]
    if(WaveDims(w) != 3)
        Abort "输入 Wave 必须是 3D Wave"
    endif
    
    Variable maxLayer = DimSize(w,2)-1
    if(l1 > maxLayer || l2 > maxLayer || l3 > maxLayer || l4 > maxLayer)
        Abort "层数值超过 Wave 维度"
    endif
    
    // 创建布局窗口
    String windName = "LayerComparison"+nameofwave(w)
    DoWindow/K $windName
    NewLayout/N=$windName/P=LANDSCAPE/K=1
    
    // [^2]
    Variable minVal = WaveMin(w)
    Variable maxVal = WaveMax(w)
    newDataFolder/o $nameofwave(w)+"8show"
    SetDataFolder $nameofwave(w)+"8show"
    // 创建临时 2D Waves 并继承轴信息
    Make/O/N=(DimSize(w,0),DimSize(w,1)) layer0,layer1,layer2,layer3,layer4,layer5,layer6,layer7
    layer0[][]= w[p][q][l1]
    layer1[][]= w[p][q][l2]
    layer2[][]= w[p][q][l3]
    layer3[][]= w[p][q][l4]
    layer4[][]= w[p][q][l5]
    layer5[][]= w[p][q][l6]
    layer6[][]= w[p][q][l7]
    layer7[][]= w[p][q][l8]
    
    // 转置并调整轴信息
//    MatrixTranspose layer0; 
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer0
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer0
//    MatrixTranspose layer1; 
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer1
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer1
//    MatrixTranspose layer2; 
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer2
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer2
//    MatrixTranspose layer3; 
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer3
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer3
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer4
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer4
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer5
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer5      
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer6
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer6
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer7
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer7    
    // [^3]
    Variable graphWidth = 180
    Variable graphHeight = 200
    Variable spacing = 5
    
    // 创建四个并列显示的子图
    Variable i,j
    for(j=0;j<2;j+=1)
    	for(i=0; i<4; i+=1)
    String plotName = "plot"+num2str(i+4*j)+nameofWave(w)
    
    // [^1] 先创建独立显示器
    Display/W=(0,0,graphWidth,graphHeight)/N=$plotName 
    
    // [^2] 必须完成图像渲染后再加入布局
    AppendImage $("layer"+num2str(i+4*j))
    ModifyImage $("layer"+num2str(i+4*j)) ctab= {minVal,maxVal/2,BlueBlackRed,0}
// 左轴标签（带粗体符号）
    Label left "E-E\\Bf \\M (eV)"  // 双反斜杠转义粗体指令[^1]

// 横轴标签（带单位上标）
    Label bottom "k\\B// \\M(Å\\S-1\\M)"  // 符号字体+上标组合[^2]
    ModifyGraph zero(left)=4
    Textbox/F=0/A=MT "Layer "+num2istr(i+4*j)
    Variable xStart = i * (graphWidth + spacing)
//    // [^3] 添加已包含内容的子图到布局
    AppendLayoutObject/R=(xStart,j*(graphHeight+spacing),xStart+graphWidth,j*(graphHeight+spacing)+graphHeight) /W=$windName/F=0 graph $plotName
    endfor
endfor

    
    // 统一坐标轴设置
    SetWindow $windName hook(myscaler)=ScaleAllAxes
    SetDataFolder saveDFR
End

Function Show8Layers_LJZ250218SP(w, l1, l2, l3, l4,l5,l6,l7,l8) //special for delay
    Wave w                 // 3D 输入 Wave
    Variable l1, l2, l3, l4,l5,l6,l7,l8 // 需要显示的图层序号
    DFREF saveDFR = GetDataFolderDFR()	
    // [^1]
    if(WaveDims(w) != 3)
        Abort "输入 Wave 必须是 3D Wave"
    endif
    
    Variable maxLayer = DimSize(w,2)-1
    if(l1 > maxLayer || l2 > maxLayer || l3 > maxLayer || l4 > maxLayer)
        Abort "层数值超过 Wave 维度"
    endif
    
    // 创建布局窗口
    String windName = "LayerComparison"+nameofwave(w)
    DoWindow/K $windName
    NewLayout/N=$windName/P=LANDSCAPE/K=1
    
    // [^2]
    Variable minVal = WaveMin(w)
    Variable maxVal = WaveMax(w)
    newDataFolder/o $nameofwave(w)+"8show"
    SetDataFolder $nameofwave(w)+"8show"
    // 创建临时 2D Waves 并继承轴信息
    Make/O/N=(DimSize(w,0),DimSize(w,1)) layer0,layer1,layer2,layer3,layer4,layer5,layer6,layer7
    layer0[][]= w[p][q][l1]
    layer1[][]= w[p][q][l2]
    layer2[][]= w[p][q][l3]
    layer3[][]= w[p][q][l4]
    layer4[][]= w[p][q][l5]
    layer5[][]= w[p][q][l6]
    layer6[][]= w[p][q][l7]
    layer7[][]= w[p][q][l8]
    
    // 转置并调整轴信息
//    MatrixTranspose layer0; 
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer0
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer0
//    MatrixTranspose layer1; 
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer1
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer1
//    MatrixTranspose layer2; 
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer2
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer2
//    MatrixTranspose layer3; 
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer3
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer3
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer4
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer4
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer5
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer5      
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer6
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer6
      SetScale/P x DimOffset(w,0), DimDelta(w,0), layer7
      SetScale/P y DimOffset(w,1), DimDelta(w,1), layer7    
    // [^3]
    Variable graphWidth = 180
    Variable graphHeight = 200
    Variable spacing = 20
    
    // 创建四个并列显示的子图
    Variable i,j
    for(j=0;j<2;j+=1)
    	for(i=0; i<4; i+=1)
    String plotName = "plot"+num2str(i+4*j)+nameofWave(w)
    
    // [^1] 先创建独立显示器
    Display/W=(0,0,graphWidth,graphHeight)/N=$plotName 
    
    // [^2] 必须完成图像渲染后再加入布局
    AppendImage $("layer"+num2str(i+4*j))
    ModifyImage $("layer"+num2str(i+4*j)) ctab= {minVal,maxVal/2,BlueBlackRed,0}
    ModifyGraph nticks(bottom)=3
    SetAxis bottom -0.3,*
    ModifyGraph zapTZ(bottom)=1,lowTrip=0.1
    ModifyGraph mirror=2
    ModifyGraph zero=4;DelayUpdate
    SetAxis bottom -0.3,-0.1
// 左轴标签（带粗体符号）
    Label left "E-E\\Bf \\M (eV)"  // 双反斜杠转义粗体指令[^1]

// 横轴标签（带单位上标）
    Label bottom "k\\B// \\M(Å\\S-1\\M)"  // 符号字体+上标组合[^2]
    ModifyGraph zero(left)=4
    Textbox/F=0/A=MT "Layer "+num2istr(i+4*j)
    Variable xStart = i * (graphWidth + spacing)
//    // [^3] 添加已包含内容的子图到布局
    AppendLayoutObject/R=(xStart,j*(graphHeight+spacing),xStart+graphWidth,j*(graphHeight+spacing)+graphHeight) /W=$windName/F=0 graph $plotName
    endfor
endfor

    
    // 统一坐标轴设置
    SetWindow $windName hook(myscaler)=ScaleAllAxes
    SetDataFolder saveDFR
End

Function NdSbTran1d_LJZ250218SP(inputwave)
// 输入：原始数据wave（1D）
// 输出：转换后的wave（自动创建后缀_Ang）
Wave inputWave

// 建立线性转换参数 (根据2.66→-0.17Å⁻¹，7→-0.2Å⁻¹)
Variable x1 = 2.66, y1 = -0.17
Variable x2 = 7.00, y2 = -0.20
Variable slope = (y2 - y1)/(x2 - x1)  // 斜率计算 [^1]
Variable intercept = y1 - slope*x1     // 截距计算 [^2]

// 创建输出wave并执行转换
Duplicate/O inputWave, $(NameOfWave(inputWave)+"_Ang")
Wave outputWave = $(NameOfWave(inputWave)+"_Ang")
outputWave = slope * inputWave[p] + intercept  // 逐点线性变换 [^3]
SetScale/p x dimOffset(inputwave,0),dimDelta(inputwave,0), outputWave               // 设置物理单位
duplicate/o outputwave,inputwave
end

Function EDC_NdSb_LJZ20241121(w, Epeak1, Epeak2, Mindex, Mxe, Res, bdta, fdta, kvary,ef,[, wi1, wi2, uz])
    // Show MDC tr-ARPES Spectral two-lorentz-peak-fit -3D
    // Special for Temperature case

    Wave w
    Variable Mindex, Mxe, Epeak1, Epeak2, wi1, wi2, Res, uz, bdta, fdta, kvary,ef
    Variable nx = DimSize(w, 0)
    Variable x0 = DimOffset(w, 0)
    Variable ny = DimSize(w, 1)
    Variable nt = DimSize(w, 2)
    Variable dx = DimDelta(w, 0)
    Variable dt = DimDelta(w, 2)
    Variable t0 = DimOffset(w, 2)

    // Set default values for wi1 and wi2 if not provided
    if (ParamIsDefault(wi1))
        wi1 = 0.01  // Default value for wi1
        wi2 = wi1    // Set wi2 to same value as wi1
    endif

    // Set default values for amp1 and amp2 if not provided
//    if (ParamIsDefault(amp1))
//        amp1 = 0.0005  // Default value for amp1
//        amp2 = amp1    // Set amp2 to same value as amp1
//    endif

//    // Adjust Kpeak1 and Kpeak2 to new scale
    Variable peakIdx1 = Round((Epeak1 - x0) / dx)
    Variable peakIdx2 = Round( (Epeak2 - x0) / dx)
//    Kpeak1 = y0 + peakIdx1 * dy
//    Kpeak2 = y0 + peakIdx2 * dy

    // Create new data folder for storing results
    NewDataFolder/O $(NameOfWave(w) + "_EDC_FF3D_f" + Num2Str(Mindex) + "2" + Num2Str(Mxe) + "_2L")
    SetDataFolder $(NameOfWave(w) + "_EDC_FF3D_f" + Num2Str(Mindex) + "2" + Num2Str(Mxe) + "_2L")

    Wave edc_wave
    make/o/n=9 W_sigma=0
    Make/O/N=9 coef_wave  // Create a 9-element wave for storing fit coefficients

    // Initialize coefficients for fitting
    coef_wave[0] = 100      // K0 initial guess
    coef_wave[1] = -40       // K1 initial guess
    coef_wave[3] = Epeak1  // K3 initial guess
    coef_wave[4] = wi1     // K4 initial guess
    coef_wave[6] = Epeak2  // K6 initial guess
    coef_wave[7] = wi2     // K7 initial guess
    coef_wave[8] = -30       // K8 initial guess

    Make/O/N=5 cfw  // Create wave for additional coefficients
    cfw[2] = 0.01

    cfw[4] = 0.02

    // Declare waves for storing peak positions and uncertainties
    Make/O/N=(nt) Peak1K
    Make/O/N=(nt) Peak2K
    Make/O/N=(nt) Peak3K
    Make/O/N=(nt) SigmaP1K
    Make/O/N=(nt) SigmaP2K
    Make/O/N=(nt) SigmaP3K

    Variable k, j, validPoints = 0, vp2 = 0

    // Loop through time points (nt)
    for (k = 0; k < nt; k += 1)
        Make/O/N=(nx) edc_wave
        SetScale/P x, x0, dx, edc_wave

        // Initialize mdc_wave at each time point
        edc_wave = 0  // Ensure mdc_wave is zeroed before accumulating
        for (j = Mindex; j <= Mxe; j += 1)
            edc_wave += w[p][j][k]
        endfor

        edc_wave /= (Mxe - Mindex + 1)
        Duplicate/O edc_wave, $("layer" + Num2Str(k) + "_at" + Num2Str(Mindex))
        Smooth 1, edc_wave

        // Calculate the peak indices
        peakIdx1 = Round(abs(coef_wave[3] - x0) / abs(dx))  // Find the closest index to Kpeak1
        peakIdx2 = Round(abs(coef_wave[6] - x0) / abs(dx))  // Find the closest index to Kpeak2

	  coef_wave[2] = edc_wave[peakIdx1]/10000
	  coef_wave[5] = edc_wave[peakIdx2]/10000
	  
        // Ensure index range to avoid out-of-bounds error
        if (peakIdx1 - fdta < 0)
            fdta = peakIdx1  // Adjust fdta to avoid negative index
        endif

        if (peakIdx2 + bdta >= nx)
            bdta = nx - peakIdx2 - 1  // Adjust bdta to avoid exceeding the limit
        endif

        if (Abs(coef_wave[3] - coef_wave[6]) > res &&Abs(coef_wave[6] - coef_wave[3]) < Abs(Epeak1 - epeak2) + 0.2 &&W_sigma[3]<0.2 &&W_sigma[6]<0.2 )
            // Perform Lorentzian fit
            Make/O/N=(fdta + bdta + peakIdx2 - peakIdx1 + 1) tpt
            tpt = edc_wave[peakIdx1 - fdta + p]

            // Ensure tpt has the same X-axis scale as mdc_wave
            SetScale/P x, x0 + (peakIdx1 - fdta) * dx, dx, tpt
		Duplicate/o tpt, $("fit_layer" + Num2Str(k) + "_at" + Num2Str(Mindex))
            FuncFit/H="000000000"/Q/N=1 two_lor, kwCWave=coef_wave, tpt/D= $("fit_layer" + Num2Str(k) + "_at" + Num2Str(Mindex))
    		
            // Save fit result to a new wave


            	if (Abs(coef_wave[3] - coef_wave[6]) > res && Abs(coef_wave[6] - coef_wave[3]) < Abs(Epeak1 - Epeak2)  +0.2&&W_sigma[3]<0.2 &&W_sigma[6]<0.2 &&coef_wave[6]<8)//最后一个硬凑的条件
                // Save fitted momentum if fitting is successful
                Peak1K[validPoints] = coef_wave[3]
                Peak2K[validPoints] = coef_wave[6]
                SigmaP1K[validPoints] =W_sigma[3]
                SigmaP2K[validPoints] =W_sigma[6]
                validPoints += 1
            	cfw[0] = coef_wave[0]
            	cfw[1] = coef_wave[1]
            	cfw[3] = coef_wave[3]
            	
        		else
            // Single Lorentzian fit
            Make/O/N=(fdta + bdta+ 11) tpt
            tpt = edc_wave[Round(abs(cfw[3] - x0) / abs(dx)) - fdta-5+ p]

            // Ensure tpt has the same X-axis scale as mdc_wave
            SetScale/P x, x0 + (Round(abs(cfw[3] - x0) / abs(dx)) - fdta-5) * dx, dx, tpt
		Duplicate/o tpt, $("fit_layer" + Num2Str(k) + "_at" + Num2Str(Mindex))
            FuncFit /Q/N=1 onelor_ljz, kwCWave=cfw, tpt/D=$("fit_layer" + Num2Str(k) + "_at" + Num2Str(Mindex))


            Peak3K[vp2] = cfw[3]
            SigmaP3K[vp2] = W_sigma[3]
            vp2 += 1
        		endif
        	 else
            // Single Lorentzian fit
            Make/O/N=(fdta + bdta+ 11) tpt
            tpt = edc_wave[Round(abs(cfw[3] - x0) / abs(dx)) - fdta-5+ p]

            // Ensure tpt has the same X-axis scale as mdc_wave
            SetScale/P x, x0 + (Round(abs(cfw[3] - x0) / abs(dx)) - fdta-5) * dx, dx, tpt
		Duplicate/o tpt, $("fit_layer" + Num2Str(k) + "_at" + Num2Str(Mindex))
            FuncFit /Q/N=1 onelor_ljz, kwCWave=cfw, tpt/D=$("fit_layer" + Num2Str(k) + "_at" + Num2Str(Mindex))

            Peak3K[vp2] = cfw[3]
            SigmaP3K[vp2] = W_sigma[3]
            vp2 += 1
     
        endif
        // Offset each layer's original curve and fitted curve
        Wave layer = $("layer" + Num2Str(k) + "_at" + Num2Str(Mindex))
        Wave fit_layer = $("fit_layer" + Num2Str(k) + "_at" + Num2Str(Mindex))

        if (k == 0)
        	DoWindow/K $(nameofwave(w)+"edc_overlapping")         // 强制关闭同名窗口 [^3]
        	setscale/P x, x0-ef, dx, layer
           Display/N=$(nameofwave(w)+"edc_overlapping") layer  // Display first layer
        else
        	setscale/P x, x0-ef, dx, layer
            AppendToGraph layer  // Append other layers
            ModifyGraph offset($("layer" + Num2Str(k) + "_at" + Num2Str(Mindex))) = {0, k * kvary}
        endif
	   setscale/P x, dimOffset(fit_layer,0)-ef, dimdelta(fit_layer,0), fit_layer
        AppendToGraph/C=(0, 65535, 65535) fit_layer  // Append fitted curve to the same graph
        ModifyGraph offset($("fit_layer" + Num2Str(k) + "_at" + Num2Str(Mindex))) = {0, k * kvary}
        Label left, "Intensity (a.u.)"
        Label bottom, "E-E\\B F \\M(eV)"
    endfor
    Peak1k-=ef
    peak2k-=ef
    // Set scale and dimensions for the results
    DoWindow/K $(NameOfWave(w) + "edc_tlf")
    Redimension/N=(validPoints) Peak1K
    Redimension/N=(validPoints) Peak2K
    SetScale/P x, t0, dt, Peak1K
    SetScale/P x, t0, dt, Peak2K
    Redimension/N=(validPoints) SigmaP1K
    Redimension/N=(validPoints) SigmaP2K
    SetScale/P x, t0, dt, SigmaP1K
    SetScale/P x, t0, dt, SigmaP2K

    Redimension/N=(vp2) Peak3K
    SetScale/P x, t0 + (validPoints ) * dt, dt, Peak3K
    Redimension/N=(vp2) SigmaP3K
    SetScale/P x, t0 + (validPoints ) * dt, dt, SigmaP3K

    // Plot Peak1K and Peak2K versus time
    Display/N=$(NameOfWave(w) + "tlf") Peak1K
    AppendToGraph Peak2K
    AppendToGraph Peak3K
    ErrorBars/RGB=(0, 0, 0) Peak1K Y, wave=(SigmaP1K, SigmaP1K)
    ErrorBars/RGB=(0, 0, 0) Peak2K Y, wave=(SigmaP2K, SigmaP2K)
    ErrorBars/RGB=(0, 65535, 65535) Peak3K Y, wave=(SigmaP3K, SigmaP3K)
    Label left, "E-E\\B F \\M(eV)"
    ModifyGraph lowTrip(left)=0.001,notation(left)=1    
    if (ParamIsDefault(uz))
        Label bottom, "Delay time (ps)"
    elseif (uz == 1)
        Label bottom, "Temperature (K)"
    elseif (uz == 2)
        Label bottom, "Fluence (mW)"
    endif

//    DoWindow/C $(NameOfWave(w) + "PP")  // Peak position plot

    // Remove temporary waves
    KillWaves edc_wave, tpt, coef_wave,cfw,W_sigma
    SetDataFolder root:
End



Function AI2gap_LJZ250302(wti, rw1, rw2)
    Wave wti, rw1, rw2
    
    // 创建交换坐标的临时波
    Make/O/N=(numpnts(wti)) tmpXWave = wti[p]          // 数值作为新X轴 [^5]
    Make/O/N=(numpnts(wti)) tmpYWave = leftx(wti) + p*deltax(wti)  // 原X坐标转为Y值 [^1]
    wave tmpYwave_cs    
    // 生成插值函数
    Interpolate2 tmpXWave,tmpYWave    // 显式指定X/Y映射 [^3]

    // 应用差值计算
    Make/O/N=(dimsize(rw1,0)) resultWave= tmpYwave_cs(rw2[p] - rw1[p])  
    setscale/p x,leftx(rw1),deltax(rw1),resultwave             // 通过新X值获取原X坐标 [^5]
End

Function AI2loc_LJZ250302(wti, rw1,rw2)
    Wave wti, rw1,rw2
    
    // 创建交换坐标的临时波
    Make/O/N=(numpnts(wti)) tmpXWave = wti[p]          // 数值作为新X轴 [^5]
    Make/O/N=(numpnts(wti)) tmpYWave = leftx(wti) + p*deltax(wti)  // 原X坐标转为Y值 [^1]
    wave tmpYwave_ss    
    // 生成插值函数
    Interpolate2/T=3 tmpXWave,tmpYWave    // 显式指定X/Y映射 [^3]
    make/o/N=(dimsize(rw1,0)) gap=abs(rw1[p]-rw2[p])
    Make/O/N=(dimsize(rw1,0)) resultWave= tmpYwave_ss(gap[p]/wavemax(gap))  
    setscale/p x,leftx(rw1),deltax(rw1),resultwave             // 通过新X值获取原X坐标 [^5]
    duplicate/o gap,$(nameofwave(rw1)+"minus"+nameofwave(rw2))
    duplicate/o resultwave,$(nameofwave(rw1)+"AI2loc"+nameofwave(rw2))
    killwaves gap,resultwave,tmpxwave,tmpywave
End

Function AI2loc_LJZ250303sp(wti, rw1,rw2,slide,per) // special for the case two peak-one peak
    Wave wti, rw1,rw2
    variable slide,per
    
    // 创建交换坐标的临时波
    Make/O/N=(numpnts(wti)) tmpXWave = wti[p]          // 数值作为新X轴 [^5]
    Make/O/N=(numpnts(wti)) tmpYWave = leftx(wti) + p*deltax(wti)  // 原X坐标转为Y值 [^1]
    wave tmpYwave_ss    
    // 生成插值函数
    Interpolate2/T=3 tmpXWave,tmpYWave    // 显式指定X/Y映射 [^3]
    wave sofrw
    killwaves sofrw
    concatenate/NP {rw1,rw2},Sofrw
    variable CT=wti(12)*per
    variable Minw = wavemin(sofrw)
    sofrw-=Minw
    variable ratio = CT/sofrw[numpnts(rw1)+slide]
    wave w_coef
    CurveFit/Q line tmpYWave_SS[numpnts(tmpYWave_SS)-7,numpnts(tmpYWave_SS)-1] /D 
    Make/O/N=(dimsize(Sofrw,0)) resultWave= Sofrw[p]*ratio<=1  ? tmpYwave_ss(Sofrw[p]*ratio)   : W_coef[0]+W_coef[1]*Sofrw[p]*ratio
    setscale/p x,leftx(Sofrw),deltax(Sofrw),resultwave             // 通过新X值获取原X坐标 [^5]
    duplicate/o sofrw,$(nameofwave(rw1)+"ap"+nameofwave(rw2))
    duplicate/o resultwave,$(nameofwave(rw1)+"AI3loc"+nameofwave(rw2))
    killwaves resultwave,tmpxwave,tmpywave
End

Function Dg2Wk_LJZ250310(w1,w2,w3,s1,s2,s3,k1,k2) //degree transform to wave vector
	wave w1,w2,w3,s1,s2,s3
	variable k1,k2
	variable deg1=w1[0],deg2=w2[0]
	variable ScaleF=(k1-k2)/(deg1-deg2),offset=k2-deg2*scaleF
	make/o/n=(numpnts(w1)) $(nameofwave(w1)+"Wvform")=w1[p]*scaleF+offset
	setscale/p x,leftx(w1),deltax(w1),$(nameofwave(w1)+"Wvform")
	make/o/n=(numpnts(w2)) $(nameofwave(w2)+"Wvform")=w2[p]*scaleF+offset
	setscale/p x,leftx(w2),deltax(w2),$(nameofwave(w2)+"Wvform")
	make/o/n=(numpnts(w3)) $(nameofwave(w3)+"Wvform")=w3[p]*scaleF+offset
	setscale/p x,leftx(w3),deltax(w3),$(nameofwave(w3)+"Wvform")
	
	make/o/n=(numpnts(s1)) $(nameofwave(s1)+"Wvform")=s1[p]*scaleF
	make/o/n=(numpnts(s2)) $(nameofwave(s2)+"Wvform")=s2[p]*scaleF
	make/o/n=(numpnts(s3)) $(nameofwave(s3)+"Wvform")=s3[p]*scaleF
	Display/N=$(nameofWave(w1)+"Peak_kform") $(nameofwave(w1)+"Wvform")
   	AppendToGraph $(nameofwave(w2)+"Wvform")
    	AppendToGraph $(nameofwave(w3)+"Wvform")
      ErrorBars/RGB=(0, 0, 0) $(nameofwave(w1)+"Wvform") Y, wave=($(nameofwave(s1)+"Wvform"), $(nameofwave(s1)+"Wvform"))
      ErrorBars/RGB=(0, 0, 0) $(nameofwave(w2)+"Wvform") Y, wave=($(nameofwave(s2)+"Wvform"), $(nameofwave(s2)+"Wvform"))
      ErrorBars/RGB=(0, 65535, 65535) $(nameofwave(w3)+"Wvform") Y, wave=($(nameofwave(s2)+"Wvform"), $(nameofwave(s2)+"Wvform"))
      Label left, "Position (Å\\S-1\\M)"
      Label bottom, "Delay time (ps)"
end

Function MDC_NdSb_LJZ20250316(w, Kpeak1, Kpeak2, Eindex, Exe, Res, bdta, fdta, kvary,alpha,ab,singleinterval[, wi1, wi2, uz])
    // Show MDC tr-ARPES Spectral two-lorentz-peak-fit -3D
    // Special for Certain Fit interval fixed

    Wave w
    Variable Eindex, Exe, Kpeak1, Kpeak2, wi1, wi2, Res, uz, bdta, fdta, kvary,alpha,singleinterval,ab
    // alpha predict the amplitude of the peak such an important parameter
    Variable nx = DimSize(w, 0)
    Variable ny = DimSize(w, 1)
    Variable nt = DimSize(w, 2)
    Variable dy = DimDelta(w, 1)
    Variable y0 = DimOffset(w, 1)
    Variable dt = DimDelta(w, 2)
    Variable t0 = DimOffset(w, 2)

    // Set default values for wi1 and wi2 if not provided
    if (ParamIsDefault(wi1))
        wi1 = 1  // Default value for wi1
        wi2 = wi1    // Set wi2 to same value as wi1
    endif

    // Set default values for amp1 and amp2 if not provided
//    if (ParamIsDefault(amp1))
//        amp1 = 0.0005  // Default value for amp1
//        amp2 = amp1    // Set amp2 to same value as amp1
//    endif

//    // Adjust Kpeak1 and Kpeak2 to new scale
    Variable peakIdx1 = Round((Kpeak1 - y0) / dy)
    Variable peakIdx2 = Round( (Kpeak2 - y0) / dy)
//    Kpeak1 = y0 + peakIdx1 * dy
//    Kpeak2 = y0 + peakIdx2 * dy
    Variable FixIdx1 = Round((Kpeak1 - y0) / dy)
    Variable FixIdx2 = Round( (Kpeak2 - y0) / dy)
    // Create new data folder for storing results
    NewDataFolder/O $(NameOfWave(w) + "_MDC_FF3D_f" + Num2Str(Eindex) + "2" + Num2Str(Exe) + "_2L")
    SetDataFolder $(NameOfWave(w) + "_MDC_FF3D_f" + Num2Str(Eindex) + "2" + Num2Str(Exe) + "_2L")

    Wave mdc_wave
    make/o/n=9 W_sigma=0
    Make/O/N=9 coef_wave  // Create a 9-element wave for storing fit coefficients

    // Initialize coefficients for fitting
    coef_wave[0] = 10      // K0 initial guess
    coef_wave[1] = 1       // K1 initial guess
    coef_wave[3] = Kpeak1  // K3 initial guess
    coef_wave[4] = wi1     // K4 initial guess
    coef_wave[6] = Kpeak2  // K6 initial guess
    coef_wave[7] = wi2     // K7 initial guess
    coef_wave[8] = 0       // K8 initial guess

    Make/O/N=5 cfw  // Create wave for additional coefficients
    cfw[2] = 10

    cfw[4] = 1

    // Declare waves for storing peak positions and uncertainties
    Make/O/N=(nt) Peak1K
    Make/O/N=(nt) Peak2K
    Make/O/N=(nt) Peak3K
    Make/O/N=(nt) SigmaP1K
    Make/O/N=(nt) SigmaP2K
    Make/O/N=(nt) SigmaP3K

    Variable k, j, validPoints = 0, vp2 = 0
    Variable doDoubleFit = 1,V_chisq 
    // Loop through time points (nt)
    for (k = 0; k < nt; k += 1)
        Make/O/N=(ny) mdc_wave
        SetScale/P x, y0, dy, mdc_wave

        // Initialize mdc_wave at each time point
        mdc_wave = 0  // Ensure mdc_wave is zeroed before accumulating

        for (j = Eindex; j <= Exe; j += 1)
            mdc_wave += w[j][p][k]
        endfor

        mdc_wave /= (Exe - Eindex + 1)
       Smooth 7, mdc_wave
        Duplicate/O mdc_wave, $("layer" + Num2Str(k) + "_at" + Num2Str(Eindex))
        

        // Calculate the peak indices
        peakIdx1 = Round(abs(coef_wave[3] - y0) / abs(dy))  // Find the closest index to Kpeak1
        peakIdx2 = Round(abs(coef_wave[6] - y0) / abs(dy))  // Find the closest index to Kpeak2

	  coef_wave[2] = mdc_wave[peakIdx1]*alpha
	  coef_wave[5] = mdc_wave[peakIdx2]*alpha*ab
	  //Coefficient here is significant because of determination of the amplitude

        // Ensure index range to avoid out-of-bounds error
        if (peakIdx1 - fdta < 0)
            fdta = peakIdx1  // Adjust fdta to avoid negative index
        endif

        if (peakIdx2 + bdta >= ny)
            bdta = ny - peakIdx2 - 1  // Adjust bdta to avoid exceeding the limit
        endif
if(doDoublefit)
  //    if (Abs(coef_wave[3] - coef_wave[6]) > res &&Abs(coef_wave[6]-Kpeak2)<1&&Abs(coef_wave[6] - coef_wave[3]) < Abs(Kpeak1 - Kpeak2) + 0.2 &&SigmaP1K[validPoints-1]<0.2 && SigmaP2K[validPoints-1]<0.2 )
            // Perform Lorentzian fit
            Make/O/N=(fdta + bdta + FixIdx2 - FixIdx1 + 1) tpt
            tpt = mdc_wave[FixIdx1 - fdta + p]
            
//           coef_wave[2] = abs(coef_wave[2])  
//           coef_wave[3] = abs(coef_wave[3])  // K3 initial guess
//           coef_wave[4] = abs(coef_wave[4])  
//           coef_wave[5] = abs(coef_wave[5])  // K3 initial guess
//           coef_wave[6] = abs(coef_wave[6])  
//           coef_wave[7] = abs(coef_wave[7])  // K3 initial guess

            // Ensure tpt has the same X-axis scale as mdc_wave
            SetScale/P x, y0 + (FixIdx1 - fdta) * dy, dy, tpt
		Duplicate/o tpt, $("fit_layer" + Num2Str(k) + "_at" + Num2Str(Eindex))
            FuncFit/H="000000000"/Q/N=1 two_lor, kwCWave=coef_wave, tpt/D= $("fit_layer" + Num2Str(k) + "_at" + Num2Str(Eindex))
    		
            // Save fit result to a new wave
//if (Abs(coef_wave[3] - coef_wave[6]) > res &&Abs(coef_wave[6]-Kpeak2)<1&&Abs(coef_wave[6] - coef_wave[3]) < Abs(Kpeak1 - Kpeak2) + 0.2 &&SigmaP1K[validPoints-1]<0.2 && SigmaP2K[validPoints-1]<0.2 )
//if(1)
  if (Abs(coef_wave[3] - coef_wave[6]) > res && Abs(coef_wave[6]-Kpeak2)<1&&Abs(coef_wave[6] - coef_wave[3]) < Abs(Kpeak1 - Kpeak2)  +0.2&&W_sigma[3]<0.2 &&W_sigma[6]<0.2 &&coef_wave[6]<8)//最后一个硬凑的条件

                // Save fitted momentum if fitting is successful
                Peak1K[validPoints] = coef_wave[3]
                Peak2K[validPoints] = coef_wave[6]
                SigmaP1K[validPoints] =W_sigma[3]
                SigmaP2K[validPoints] =W_sigma[6]
                validPoints += 1
            	cfw[0] = coef_wave[0]
            	cfw[1] = coef_wave[1]
            	cfw[3] = coef_wave[3]     
        	else
        		dodoublefit=0
        		Make/O/N=(fdta + bdta+2* singleinterval+1) tpt
            	tpt = mdc_wave[Round(abs(Peak1K[validPoints-1] - y0) / abs(dy)) - fdta+singleinterval+ p]
            	Killwaves $("fit_layer" + Num2Str(k) + "_at" + Num2Str(Eindex))

            // Ensure tpt has the same X-axis scale as mdc_wave
           		SetScale/P x, y0 + (Round(abs(Peak1K[validPoints-1] - y0) / abs(dy)) - fdta+singleinterval) * dy, dy, tpt
			Duplicate/o tpt, $("fit_layer" + Num2Str(k) + "_at" + Num2Str(Eindex))
            	FuncFit /Q/N=1 onelor_ljz, kwCWave=cfw, tpt/D=$("fit_layer" + Num2Str(k) + "_at" + Num2Str(Eindex))
            	Peak3K[vp2] = cfw[3]
            	SigmaP3K[vp2] = W_sigma[3]
            	vp2 += 1            
        	endif
else
            // Single Lorentzian fit

            Make/O/N=(fdta + bdta+2* singleinterval+1) tpt
            tpt = mdc_wave[Round(abs(Peak1K[validPoints-1] - y0) / abs(dy)) - fdta+singleinterval+ p]
            Killwaves $("fit_layer" + Num2Str(k) + "_at" + Num2Str(Eindex))

            // Ensure tpt has the same X-axis scale as mdc_wave
            SetScale/P x, y0 + (Round(abs(Peak1K[validPoints-1] - y0) / abs(dy)) - fdta+singleinterval) * dy, dy, tpt
		Duplicate/o tpt, $("fit_layer" + Num2Str(k) + "_at" + Num2Str(Eindex))
            FuncFit /Q/N=1 onelor_ljz, kwCWave=cfw, tpt/D=$("fit_layer" + Num2Str(k) + "_at" + Num2Str(Eindex))


            Peak3K[vp2] = cfw[3]
            SigmaP3K[vp2] = W_sigma[3]
            vp2 += 1
//        		endif
//        	 else
//            // Single Lorentzian fit
//            Make/O/N=(fdta + bdta+ 2* singleinterval+1) tpt
//            tpt = mdc_wave[Round(abs(Peak1K[validPoints-1] - y0) / abs(dy)) - fdta-singleinterval+ p]
//
//            // Ensure tpt has the same X-axis scale as mdc_wave
//            SetScale/P x, y0 + (Round(abs(Peak1K[validPoints-1] - y0) / abs(dy)) - fdta-singleinterval) * dy, dy, tpt
//		Duplicate/o tpt, $("fit_layer" + Num2Str(k) + "_at" + Num2Str(Eindex))
//            FuncFit /Q/N=1 onelor_ljz, kwCWave=cfw, tpt/D=$("fit_layer" + Num2Str(k) + "_at" + Num2Str(Eindex))
//
//            Peak3K[vp2] = cfw[3]
//            SigmaP3K[vp2] = W_sigma[3]
//            vp2 += 1
     
endif
        // Offset each layer's original curve and fitted curve
        Wave layer = $("layer" + Num2Str(k) + "_at" + Num2Str(Eindex))
        Wave fit_layer = $("fit_layer" + Num2Str(k) + "_at" + Num2Str(Eindex))

        if (k == 0)
            DoWindow/K $(nameofwave(w)+"mdc_overlapping")
            Display/n=$(nameofwave(w)+"mdc_overlapping") layer  // Display first layer
        else
            AppendToGraph layer  // Append other layers
            ModifyGraph offset($("layer" + Num2Str(k) + "_at" + Num2Str(Eindex))) = {0, k * kvary}
        endif

        AppendToGraph/C=(0, 65535, 65535) fit_layer  // Append fitted curve to the same graph
        ModifyGraph offset($("fit_layer" + Num2Str(k) + "_at" + Num2Str(Eindex))) = {0, k * kvary}
        Label left, "Intensity (a.u.)"
        Label bottom, "Position (Å\\S-1\\M)"
    endfor

    // Set scale and dimensions for the results
    DoWindow/K $(NameOfWave(w) + "mdc_tlf")
    Redimension/N=(validPoints) Peak1K
    Redimension/N=(validPoints) Peak2K
    SetScale/P x, t0, dt, Peak1K
    SetScale/P x, t0, dt, Peak2K
    Redimension/N=(validPoints) SigmaP1K
    Redimension/N=(validPoints) SigmaP2K
    SetScale/P x, t0, dt, SigmaP1K
    SetScale/P x, t0, dt, SigmaP2K

    Redimension/N=(vp2) Peak3K
    SetScale/P x, t0 + (validPoints ) * dt, dt, Peak3K
    Redimension/N=(vp2) SigmaP3K
    SetScale/P x, t0 + (validPoints ) * dt, dt, SigmaP3K

    // Plot Peak1K and Peak2K versus time
    Display/N=$(NameOfWave(w) + "mdc_tlf") Peak1K
    AppendToGraph Peak2K
    AppendToGraph Peak3K
    ErrorBars/RGB=(0, 0, 0) Peak1K Y, wave=(SigmaP1K, SigmaP1K)
    ErrorBars/RGB=(0, 0, 0) Peak2K Y, wave=(SigmaP2K, SigmaP2K)
    ErrorBars/RGB=(0, 65535, 65535) Peak3K Y, wave=(SigmaP3K, SigmaP3K)
    Label left, "Position (Å\\S-1\\M)"
    
    if (ParamIsDefault(uz))
        Label bottom, "Delay time (ps)"
    elseif (uz == 1)
        Label bottom, "Temperature (K)"
    elseif (uz == 2)
        Label bottom, "Fluence (mW)"
    endif



    // Remove temporary waves
    KillWaves mdc_wave, tpt,cfw,W_sigma,coef_wave
    SetDataFolder root:
End

Function AI2gap_LJZ250317(wti, rw)
    Wave wti, rw
    // 创建交换坐标的临时波
    Make/O/N=(numpnts(wti)) tmpXWave = wti[p]          // 数值作为新X轴 [^5]
    Make/O/N=(numpnts(wti)) tmpYWave = leftx(wti) + p*deltax(wti)  // 原X坐标转为Y值 [^1]
    wave tmpYwave_cs    
    // 生成插值函数
    Interpolate2 tmpXWave,tmpYWave    // 显式指定X/Y映射 [^3]

    Make/O/N=(dimsize(rw,0)) resultWave= tmpYwave_cs(rw[p])  
    setscale/p x,leftx(rw),deltax(rw),resultwave             // 通过新X值获取原X坐标 [^5]
End

Function Dg2Wk_LJZ250323(w1,w2,w3,s1,s2,s3,k1,k2) //degree transform to wave vector for uJ/cm2 form
	wave w1,w2,w3,s1,s2,s3
	variable k1,k2
	variable deg1=w1[0],deg2=w2[0]
	variable ScaleF=(k1-k2)/(deg1-deg2),offset=k2-deg2*scaleF
	make/o/n=(numpnts(w1)) $(nameofwave(w1)+"Wvform")=w1[p]*scaleF+offset
	setscale/p x,leftx(w1),deltax(w1)*60,$(nameofwave(w1)+"Wvform")
	make/o/n=(numpnts(w2)) $(nameofwave(w2)+"Wvform")=w2[p]*scaleF+offset
	setscale/p x,leftx(w2),deltax(w2)*60,$(nameofwave(w2)+"Wvform")
	make/o/n=(numpnts(w3)) $(nameofwave(w3)+"Wvform")=w3[p]*scaleF+offset
	setscale/p x,leftx(w3)+numpnts(w2)*12,deltax(w3)*60,$(nameofwave(w3)+"Wvform")
	
	make/o/n=(numpnts(s1)) $(nameofwave(s1)+"Wvform")=s1[p]*scaleF
	make/o/n=(numpnts(s2)) $(nameofwave(s2)+"Wvform")=s2[p]*scaleF
	make/o/n=(numpnts(s3)) $(nameofwave(s3)+"Wvform")=s3[p]*scaleF
	Display/N=$(nameofWave(w1)+"Peak_kform") $(nameofwave(w1)+"Wvform")
   	AppendToGraph $(nameofwave(w2)+"Wvform")
    	AppendToGraph $(nameofwave(w3)+"Wvform")
      ErrorBars/RGB=(0, 0, 0) $(nameofwave(w1)+"Wvform") Y, wave=($(nameofwave(s1)+"Wvform"), $(nameofwave(s1)+"Wvform"))
      ErrorBars/RGB=(0, 0, 0) $(nameofwave(w2)+"Wvform") Y, wave=($(nameofwave(s2)+"Wvform"), $(nameofwave(s2)+"Wvform"))
      ErrorBars/RGB=(0, 65535, 65535) $(nameofwave(w3)+"Wvform") Y, wave=($(nameofwave(s2)+"Wvform"), $(nameofwave(s2)+"Wvform"))
      Label left, "Position (Å\\S-1\\M)"
      Label bottom "Fluence (μJ/cm\\S2\\M)"
end

Function AI2gap_LJZ250323(wti, rw)
    Wave wti, rw
    // 创建交换坐标的临时波
    Make/O/N=(numpnts(wti)) tmpXWave = wti[p]          // 数值作为新X轴 [^5]
    Make/O/N=(numpnts(wti)) tmpYWave = leftx(wti) + p*deltax(wti)  // 原X坐标转为Y值 [^1]
    wave tmpYwave_cs    
    // 生成插值函数
    Interpolate2 tmpXWave,tmpYWave    // 显式指定X/Y映射 [^3]

    Make/O/N=(dimsize(rw,0)) resultWave= tmpYwave_cs(rw[p])  
    setscale/p x,leftx(rw),deltax(rw),resultwave             // 通过新X值获取原X坐标 [^5]
    duplicate/o resultwave,$(nameofwave(wti)+"RE")
    killwaves resultwave
End

Function AI2loc_LJZ250324(wti, rw1,rw2,sg1,sg2)
    Wave wti, rw1,rw2,sg1,sg2
    // 创建交换坐标的临时波
    Make/O/N=(numpnts(wti)) tmpXWave = wti[p]          // 数值作为新X轴 [^5]
    Make/O/N=(numpnts(wti)) tmpYWave = leftx(wti) + p*deltax(wti)  // 原X坐标转为Y值 [^1]
    wave tmpYwave_ss    
    // 生成插值函数
    Interpolate2/T=3 tmpXWave,tmpYWave    // 显式指定X/Y映射 [^3]
    make/o/N=(dimsize(rw1,0)) gap=abs(rw1[p]-rw2[p])
    Make/O/N=(dimsize(rw1,0)) resultWave= tmpYwave_ss(gap[p]/wavemax(gap))  
    setscale/p x,leftx(rw1),deltax(rw1),resultwave             // 通过新X值获取原X坐标 [^5]
    duplicate/o gap,$(nameofwave(rw1)+"minus"+nameofwave(rw2))
    duplicate/o resultwave,$(nameofwave(rw1)+"AI2loc"+nameofwave(rw2))
    
    make/o/N=(dimsize(rw1,0)) gapup=abs(rw1[p]-rw2[p])+sg1[p]+sg2[p]
    Make/O/N=(dimsize(rw1,0)) resultWaveup= tmpYwave_ss(gapup[p]/wavemax(gapup))  
    setscale/p x,leftx(rw1),deltax(rw1),resultwaveup             // 通过新X值获取原X坐标 [^5]
    duplicate/o gapup,$(nameofwave(rw1)+"minus"+nameofwave(rw2)+"up")
    duplicate/o resultwaveup,$(nameofwave(rw1)+"AI2loc"+nameofwave(rw2)+"up")
    
    make/o/N=(dimsize(rw1,0)) gapdn=abs(rw1[p]-rw2[p])-sg1[p]-sg2[p]
    Make/O/N=(dimsize(rw1,0)) resultWavedn= tmpYwave_ss(gapdn[p]/wavemax(gapdn))  
    setscale/p x,leftx(rw1),deltax(rw1),resultwavedn            // 通过新X值获取原X坐标 [^5]
    duplicate/o gapdn,$(nameofwave(rw1)+"minus"+nameofwave(rw2)+"dn")
    duplicate/o resultwavedn,$(nameofwave(rw1)+"AI2loc"+nameofwave(rw2)+"dn")
    
    make/o/n=(numpnts(gapup)) sigup=3*abs(gapup[p]-gap[p])
    make/o/n=(numpnts(gapdn)) sigdn=3*abs(gapdn[p]-gap[p])
    
    string path=getdataFolder(1)
    
    display/N=$("path"+"temp") $(nameofwave(rw1)+"AI2loc"+nameofwave(rw2))
    ErrorBars/RGB=(0, 0, 0) $(nameofwave(rw1)+"AI2loc"+nameofwave(rw2)) SHADE= {0,0,(0,0,0,0),(0,0,0,0)}, wave=(sigup,sigdn)

    ModifyGraph mode=3,marker=17
    Label left, "Temperature (K)"
    Label bottom, "Delay (ps)"
    killwaves gap,resultwave,tmpxwave,tmpywave,gapup,gapdn,resultwaveup,resultwavedn
End

Function AI2loc_LJZ250324sp(wti, rw1,rw2,sg1,sg2,slide,per) // special for the case two peak-one peak
    Wave wti, rw1,rw2,sg1,sg2
    variable slide,per
    
    make/o/n=(numpnts(rw1)) rw1up=rw1[p]+sg1[p]
    make/o/n=(numpnts(rw2)) rw2up=rw2[p]+sg2[p]
    make/o/n=(numpnts(rw1)) rw1dn=rw1[p]-sg1[p]
    make/o/n=(numpnts(rw2)) rw2dn=rw2[p]-sg2[p]
    AI2loc_LJZ250303sp(wti,rw1,rw2,slide,per)
    AI2loc_LJZ250303sp(wti,rw1up,rw2up,slide,per)
    AI2loc_LJZ250303sp(wti,rw1dn,rw2dn,slide,per)
    wave rw1dnAI3locrw2dn,rw1upAI3locrw2up,Peak1KAI3locPeak3K
    
    make/o/n=(numpnts(rw1upAI3locrw2up)) sigTup=3*abs(rw1upAI3locrw2up[p]-Peak1KAI3locPeak3K[p])
    make/o/n=(numpnts(rw1dnAI3locrw2dn)) sigTdn=3*abs(rw1dnAI3locrw2dn[p]-Peak1KAI3locPeak3K[p])
    
    string path=getdataFolder(1)
    
    display/N=$("temp") Peak1KAI3locPeak3K
    ErrorBars/RGB=(0, 0, 0) Peak1KAI3locPeak3K SHADE= {0,0,(0,0,0,0),(0,0,0,0)}, wave=(sigTup,sigTdn)
End

Function Show6Layers_LJZ250330tp(w, l1, l2, l3, l4, l5, l6[,mode])
    Wave w                 // 3D 输入 Wave
    Variable l1, l2, l3, l4, l5, l6,mode // 需要显示的图层序号
    if(paramIsDefault(mode))
        mode = 1
    endif    
    DFREF savedDF= GetDataFolderDFR()
    make/o lyorder={l1,l2,l3,l4,l5,l6}
    // 参数检查
    if(WaveDims(w) != 3)
        Abort "输入 Wave 必须是 3D Wave"
    endif
    
    Variable maxLayer = DimSize(w,2)-1
    if(l1 > maxLayer || l2 > maxLayer || l3 > maxLayer || l4 > maxLayer || l5 > maxLayer || l6 > maxLayer)
        Abort "层数值超过 Wave 维度"
    endif
    
    // 创建布局窗口
    String windName = "LayerComparison6_"+nameofwave(w)
    DoWindow/K $windName
    NewLayout/N=$windName/P=LANDSCAPE/K=1
    
    // 准备显示数据
    Variable minVal = WaveMin(w)
    Variable maxVal = WaveMax(w)
    newDataFolder/o/S $nameofwave(w)+"6show"
    
    // 创建6个临时2D Waves并继承轴信息
    Make/O/N=(DimSize(w,0),DimSize(w,1)) layer0,layer1,layer2,layer3,layer4,layer5
    layer0[][]= w[p][q][l1]
    layer1[][]= w[p][q][l2]
    layer2[][]= w[p][q][l3]
    layer3[][]= w[p][q][l4]
    layer4[][]= w[p][q][l5]
    layer5[][]= w[p][q][l6]
    
    // 设置轴信息
    SetScale/P x DimOffset(w,0), DimDelta(w,0), layer0,layer1,layer2,layer3,layer4,layer5
    SetScale/P y DimOffset(w,1), DimDelta(w,1), layer0,layer1,layer2,layer3,layer4,layer5
    
    
    // 修改布局参数部分
Variable graphWidth = 100      // 单图宽度保持150像素
Variable graphHeight = 200     // 高度保持不变
Variable hSpacing = 0          // 水平间距清零[^3]



    // 创建6个子图（两行三列）
    Variable i, xstart
   for(i=0; i<6; i+=1)
    xStart =(i+0.7)*graphWidth
    String plotName = "plot"+num2str(i)+"_"+nameofWave(w)
    Killwindow $plotName 
    Display/W=(0,0,graphWidth,graphHeight)/N=$plotName 
    AppendImage $("layer"+num2str(i))
    if(mode==1)
    ModifyImage $("layer"+num2str(i)) ctab= {minVal/100,maxVal/100,YellowHot256,0}
    elseif(mode==2)
    ModifyImage $("layer"+num2str(i)) ctab= {minVal,maxVal/2,BlueBlackRed,0}
    elseif(mode==3)
    ModifyImage $("layer"+num2str(i)) ctab= {minVal/2,0,root:ImageCT:Image_CT,1}
    elseif(mode==4)
    ModifyImage $("layer"+num2str(i)) ctab= {0,maxval,root:ImageCT:Image_CT,0}
    endif
    ModifyGraph mirror=2

    SetAxis bottom -0.27,-0.06
    setaxis left -0.1675,0.0875
    ModifyGraph zero(left)=4
    Textbox/F=0/B=1/A=MT num2istr(lyorder[i]+4)+"K"
    if(mode==1)
    TextBox/C/N=text0/X=20.00/Y=25.00
        else
    TextBox/C/N=text0/X=20.00/Y=20.00
    	endif
    // 坐标轴设置
    Label bottom "k\\B// \\M(Å\\S-1\\M)" 
    if (i==0)
//      ModifyGraph tick=0,noLabel=0
        Label left "E-E\\Bf \\M (eV)"
        ModifyGraph lblMargin(left)=10,lblLatPos(left)=5
        ModifyGraph margin(right)=1
        AppendLayoutObject/R=(0.2*graphWidth,0,1.7*graphWidth,graphHeight)/W=$windName/F=0 graph $plotName 
    else
        ModifyGraph tick(left)=3,noLabel(left)=2
        ModifyGraph margin(left)=1,margin(right)=1
        AppendLayoutObject/R=(xStart,0,xStart+graphWidth,graphHeight)/W=$windName/F=0 graph $plotName
     endif
    // 添加布局对象
endfor

    setdatafolder savedDF
    // 统一坐标轴设置
//    SetWindow $windName hook(myscaler)=ScaleAllAxes
End

Function Show6Layers_LJZ250330fd(w, l1, l2, l3, l4, l5, l6[,mode])
    Wave w                 // 3D 输入 Wave
    Variable l1, l2, l3, l4, l5, l6,mode // 需要显示的图层序号
    DFREF savedDF= GetDataFolderDFR()
    make/o lyorder={l1,l2,l3,l4,l5,l6}
    // 参数检查
    if(WaveDims(w) != 3)
        Abort "输入 Wave 必须是 3D Wave"
    endif
        if(paramIsDefault(mode))
        mode = 1
    endif    
    
    Variable maxLayer = DimSize(w,2)-1
    if(l1 > maxLayer || l2 > maxLayer || l3 > maxLayer || l4 > maxLayer || l5 > maxLayer || l6 > maxLayer)
        Abort "层数值超过 Wave 维度"
    endif
    
    // 创建布局窗口
    String windName = "LayerComparison6_"+nameofwave(w)
    DoWindow/K $windName
    NewLayout/N=$windName/P=LANDSCAPE/K=1
    
    // 准备显示数据
    Variable minVal = WaveMin(w)
    Variable maxVal = WaveMax(w)
    newDataFolder/o/S $nameofwave(w)+"6show"
    
    // 创建6个临时2D Waves并继承轴信息
    Make/O/N=(DimSize(w,0),DimSize(w,1)) layer0,layer1,layer2,layer3,layer4,layer5
    layer0[][]= w[p][q][l1]
    layer1[][]= w[p][q][l2]
    layer2[][]= w[p][q][l3]
    layer3[][]= w[p][q][l4]
    layer4[][]= w[p][q][l5]
    layer5[][]= w[p][q][l6]
    
    // 设置轴信息
    SetScale/P x DimOffset(w,0), DimDelta(w,0), layer0,layer1,layer2,layer3,layer4,layer5
    SetScale/P y DimOffset(w,1), DimDelta(w,1), layer0,layer1,layer2,layer3,layer4,layer5
    
    
    // 修改布局参数部分
Variable graphWidth = 100      // 单图宽度保持150像素
Variable graphHeight = 200     // 高度保持不变
Variable hSpacing = 0          // 水平间距清零[^3]



    // 创建6个子图（两行三列）
    Variable i, xstart
   for(i=0; i<6; i+=1)
    xStart =(i+0.7)*graphWidth
    String plotName = "plot"+num2str(i)+"_"+nameofWave(w)
    Killwindow $plotName 
    Display/W=(0,0,graphWidth,graphHeight)/N=$plotName 
    AppendImage $("layer"+num2str(i))
    if(mode==1)
    ModifyImage $("layer"+num2str(i)) ctab= {minVal/100,maxVal/100,YellowHot256,0}
    elseif(mode==2)
    ModifyImage $("layer"+num2str(i)) ctab= {minVal,maxVal/2,BlueBlackRed,0}
    elseif(mode==3)
    ModifyImage $("layer"+num2str(i)) ctab= {minVal/2,0,root:ImageCT:Image_CT,1}
    elseif(mode==4)
    ModifyImage $("layer"+num2str(i)) ctab= {0,maxval,root:ImageCT:Image_CT,0}
    endif
//    ModifyImage $("layer"+num2str(i)) ctab= {minVal,maxVal/2,BlueBlackRed,0}
    
    ModifyGraph mirror=2

    SetAxis bottom -0.27,-0.06

    ModifyGraph zero(left)=4
    Textbox/F=0/B=1/A=MT num2istr(lyorder[i]*12+12)+"μJ/cm\\S2\\M"
        if(mode==1)
    TextBox/C/N=text0/X=20.00/Y=25.00
        else
    TextBox/C/N=text0/X=20.00/Y=20.00
    	endif
    // 坐标轴设置
    Label bottom "k\\B// \\M(Å\\S-1\\M)" 
    if (i==0)
//      ModifyGraph tick=0,noLabel=0
        Label left "E-E\\Bf \\M (eV)"
        ModifyGraph lblMargin(left)=10,lblLatPos(left)=5
        ModifyGraph margin(right)=1
        AppendLayoutObject/R=(0.2*graphWidth,0,1.7*graphWidth,graphHeight)/W=$windName/F=0 graph $plotName 
    else
        ModifyGraph tick(left)=3,noLabel(left)=2
        ModifyGraph margin(left)=1,margin(right)=1
        AppendLayoutObject/R=(xStart,0,xStart+graphWidth,graphHeight)/W=$windName/F=0 graph $plotName
     endif
    // 添加布局对象
endfor

    setdatafolder savedDF
    // 统一坐标轴设置
//    SetWindow $windName hook(myscaler)=ScaleAllAxes
End

Function Show6Layers_LJZ250330ds(w, l1, l2, l3, l4, l5, l6[,mode])
    Wave w                 // 3D 输入 Wave
    Variable l1, l2, l3, l4, l5, l6,mode // 需要显示的图层序号
    DFREF savedDF= GetDataFolderDFR()
    make/o lyorder={l1,l2,l3,l4,l5,l6}
    // 参数检查
    if(paramIsDefault(mode))
        mode = 1
    endif    
    
    if(WaveDims(w) != 3)
        Abort "输入 Wave 必须是 3D Wave"
    endif
    
    Variable maxLayer = DimSize(w,2)-1
    if(l1 > maxLayer || l2 > maxLayer || l3 > maxLayer || l4 > maxLayer || l5 > maxLayer || l6 > maxLayer)
        Abort "层数值超过 Wave 维度"
    endif
    
    // 创建布局窗口
    String windName = "LayerComparison6_"+nameofwave(w)
    DoWindow/K $windName
    NewLayout/N=$windName/P=LANDSCAPE/K=1
    
    // 准备显示数据
    Variable minVal = WaveMin(w)
    Variable maxVal = WaveMax(w)
    newDataFolder/o/S $nameofwave(w)+"6show"
    
    // 创建6个临时2D Waves并继承轴信息
    Make/O/N=(DimSize(w,0),DimSize(w,1)) layer0,layer1,layer2,layer3,layer4,layer5
    layer0[][]= w[p][q][l1]
    layer1[][]= w[p][q][l2]
    layer2[][]= w[p][q][l3]
    layer3[][]= w[p][q][l4]
    layer4[][]= w[p][q][l5]
    layer5[][]= w[p][q][l6]
    
    // 设置轴信息
    SetScale/P x DimOffset(w,0), DimDelta(w,0), layer0,layer1,layer2,layer3,layer4,layer5
    SetScale/P y DimOffset(w,1), DimDelta(w,1), layer0,layer1,layer2,layer3,layer4,layer5
    
    
    // 修改布局参数部分
Variable graphWidth = 100      // 单图宽度保持150像素
Variable graphHeight = 200     // 高度保持不变
Variable hSpacing = 0          // 水平间距清零[^3]



    // 创建6个子图（两行三列）
    Variable i, xstart
   for(i=0; i<6; i+=1)
    xStart =(i+0.7)*graphWidth
    String plotName = "plot"+num2str(i)+"_"+nameofWave(w)
    Killwindow $plotName 
    Display/W=(0,0,graphWidth,graphHeight)/N=$plotName 
    AppendImage $("layer"+num2str(i))
    if(mode==1)
    ModifyImage $("layer"+num2str(i)) ctab= {minVal/100,maxVal/100,YellowHot256,0}
    elseif(mode==2)
    ModifyImage $("layer"+num2str(i)) ctab= {minVal,maxVal/2,BlueBlackRed,0}
    elseif(mode==3)
    ModifyImage $("layer"+num2str(i)) ctab= {minVal/2,0,root:ImageCT:Image_CT,1}
    elseif(mode==4)
    ModifyImage $("layer"+num2str(i)) ctab= {0,maxval,root:ImageCT:Image_CT,0}
    endif
    
    ModifyGraph mirror=2

    SetAxis bottom -0.27,-0.06

    ModifyGraph zero(left)=4
    Textbox/F=0/B=1/A=MT num2istr(lyorder[i]*5-1)+"ps"
            if(mode==1)
    TextBox/C/N=text0/X=20.00/Y=25.00
        else
    TextBox/C/N=text0/X=20.00/Y=20.00
    	endif
    
    // 坐标轴设置
    Label bottom "k\\B// \\M(Å\\S-1\\M)" 
    if (i==0)
//      ModifyGraph tick=0,noLabel=0
        Label left "E-E\\Bf \\M (eV)"
        ModifyGraph lblMargin(left)=10,lblLatPos(left)=5
        ModifyGraph margin(right)=1
        AppendLayoutObject/R=(0.2*graphWidth,0,1.7*graphWidth,graphHeight)/W=$windName/F=0 graph $plotName 
    else
        ModifyGraph tick(left)=3,noLabel(left)=2
        ModifyGraph margin(left)=1,margin(right)=1
        AppendLayoutObject/R=(xStart,0,xStart+graphWidth,graphHeight)/W=$windName/F=0 graph $plotName
     endif
    // 添加布局对象
endfor

    setdatafolder savedDF
    // 统一坐标轴设置
//    SetWindow $windName hook(myscaler)=ScaleAllAxes
End

Function Show6Layers_LJZ250414tp(w, l1, l2, l3, l4, l5, l6[,mode])
    Wave w                 // 3D 输入 Wave
    Variable l1, l2, l3, l4, l5, l6,mode // 需要显示的图层序号
    if(paramIsDefault(mode))
        mode = 1
    endif    
    DFREF savedDF= GetDataFolderDFR()
    make/o lyorder={l1,l2,l3,l4,l5,l6}
    // 参数检查
    if(WaveDims(w) != 3)
        Abort "输入 Wave 必须是 3D Wave"
    endif
    
    Variable maxLayer = DimSize(w,2)-1
    if(l1 > maxLayer || l2 > maxLayer || l3 > maxLayer || l4 > maxLayer || l5 > maxLayer || l6 > maxLayer)
        Abort "层数值超过 Wave 维度"
    endif
    
    // 创建布局窗口
    String windName = "LayerComparison6_"+nameofwave(w)
    DoWindow/K $windName
    NewLayout/N=$windName/P=LANDSCAPE/K=1
    
    // 准备显示数据
    Variable minVal = WaveMin(w)
    Variable maxVal = WaveMax(w)
    newDataFolder/o/S $nameofwave(w)+"6show"
    
    // 创建6个临时2D Waves并继承轴信息
    Make/O/N=(DimSize(w,0),DimSize(w,1)) layer0,layer1,layer2,layer3,layer4,layer5
    layer0[][]= w[p][q][l1]
    layer1[][]= w[p][q][l2]
    layer2[][]= w[p][q][l3]
    layer3[][]= w[p][q][l4]
    layer4[][]= w[p][q][l5]
    layer5[][]= w[p][q][l6]
    
    // 设置轴信息
    SetScale/P x DimOffset(w,0), DimDelta(w,0), layer0,layer1,layer2,layer3,layer4,layer5
    SetScale/P y DimOffset(w,1), DimDelta(w,1), layer0,layer1,layer2,layer3,layer4,layer5
    
    
    // 修改布局参数部分
Variable graphWidth = 100      // 单图宽度保持150像素
Variable graphHeight = 200     // 高度保持不变
Variable hSpacing = 0          // 水平间距清零[^3]



    // 创建6个子图（两行三列）
    Variable i, xstart
   for(i=0; i<6; i+=1)
    xStart =(i+0.7)*graphWidth
    String plotName = "plot"+num2str(i)+"_"+nameofWave(w)
    Killwindow $plotName 
    Display/W=(0,0,graphWidth,graphHeight)/N=$plotName 
    AppendImage $("layer"+num2str(i))
    if(mode==1)
    ModifyImage $("layer"+num2str(i)) ctab= {minVal/100,maxVal/100,YellowHot256,0}
    else
    ModifyImage $("layer"+num2str(i)) ctab= {minVal,maxVal/2,BlueBlackRed,0}
    endif
    ModifyGraph mirror=2

    SetAxis bottom -0.27,-0.06
    setaxis left -0.1675,0.0875
    ModifyGraph zero(left)=4
    Textbox/F=0/B=1/A=MT num2istr(lyorder[i]+4)+"K"
    if(mode==1)
    TextBox/C/N=text0/X=20.00/Y=25.00
        else
    TextBox/C/N=text0/X=20.00/Y=20.00
    	endif
    // 坐标轴设置
    Label bottom "k\\B// \\M(Å\\S-1\\M)" 
    if (i==0)
//      ModifyGraph tick=0,noLabel=0
        Label left "E-E\\Bf \\M (eV)"
        ModifyGraph lblMargin(left)=10,lblLatPos(left)=5
        ModifyGraph margin(right)=1
        AppendLayoutObject/R=(0.2*graphWidth,0,1.7*graphWidth,graphHeight)/W=$windName/F=0 graph $plotName 
    else
        ModifyGraph tick(left)=3,noLabel(left)=2
        ModifyGraph margin(left)=1,margin(right)=1
        AppendLayoutObject/R=(xStart,0,xStart+graphWidth,graphHeight)/W=$windName/F=0 graph $plotName
     endif
    // 添加布局对象
endfor

    setdatafolder savedDF
    // 统一坐标轴设置
//    SetWindow $windName hook(myscaler)=ScaleAllAxes
End


Function D2P_LJZ20250421(w, Kpeak1, Kpeak2, Res, bdta, fdta, kvary,alpha,ab,singleinterval[, wi1, wi2, uz])
    // Show MDC tr-ARPES Spectral two-lorentz-peak-fit -3D
    // Special for Certain Fit interval fixed

    Wave w
    Variable Kpeak1, Kpeak2, wi1, wi2, Res, uz, bdta, fdta, kvary,alpha,singleinterval,ab
    // alpha predict the amplitude of the peak such an important parameter
    Variable nx = DimSize(w, 0)
    Variable ny = DimSize(w, 1)
    Variable x0 = DimOffset(w, 0)
    Variable dy = DimDelta(w, 1)
    Variable dx = DimDelta(w, 0)
    Variable y0 = DimOffset(w, 1)

    // Set default values for wi1 and wi2 if not provided
    if (ParamIsDefault(wi1))
        wi1 = 0.01  // Default value for wi1
        wi2 = wi1    // Set wi2 to same value as wi1
    endif

    // Set default values for amp1 and amp2 if not provided
//    if (ParamIsDefault(amp1))
//        amp1 = 0.0005  // Default value for amp1
//        amp2 = amp1    // Set amp2 to same value as amp1
//    endif

//    // Adjust Kpeak1 and Kpeak2 to new scale
    Variable peakIdx1 = Round((Kpeak1 - x0) / dx)
    Variable peakIdx2 = Round( (Kpeak2 - x0) / dx)
//    Kpeak1 = y0 + peakIdx1 * dy
//    Kpeak2 = y0 + peakIdx2 * dy
    Variable FixIdx1 = Round((Kpeak1 - x0) / dx)
    Variable FixIdx2 = Round( (Kpeak2 - x0) / dx)
    // Create new data folder for storing results
    NewDataFolder/O $(NameOfWave(w) + "_MDC_HP")
    SetDataFolder $(NameOfWave(w) + "_MDC_HP")

    Wave mdc_wave
    make/o/n=9 W_sigma=0
    Make/O/N=9 coef_wave  // Create a 9-element wave for storing fit coefficients

    // Initialize coefficients for fitting
    coef_wave[0] = 0      // K0 initial guess
    coef_wave[1] = 0       // K1 initial guess
    coef_wave[3] = Kpeak1  // K3 initial guess
    coef_wave[4] = wi1     // K4 initial guess
    coef_wave[6] = Kpeak2  // K6 initial guess
    coef_wave[7] = wi2     // K7 initial guess
    coef_wave[8] = 0       // K8 initial guess
    coef_wave[2] = 0.01
    coef_wave[5] = 0.02
    Make/O/N=6 cfw  // Create wave for additional coefficients
    cfw[2] = 0.5

    cfw[4] = 0.05
    cfw[5] = 0
    // Declare waves for storing peak positions and uncertainties
    Make/O/N=(ny) Peak1K
    Make/O/N=(ny) Peak2K
    Make/O/N=(ny) Peak3K
    Make/O/N=(ny) SigmaP1K
    Make/O/N=(ny) SigmaP2K
    Make/O/N=(ny) SigmaP3K

    Variable j, validPoints = 0, vp2 = 0
    Variable doDoubleFit = 1,V_chisq 
    // Loop through time points (nt)
    for (j = 0; j < ny; j += 1)
        Make/O/N=(nx) mdc_wave
        SetScale/P x, x0, dx, mdc_wave
        mdc_wave = w[p][j]
       Smooth 5, mdc_wave
        Duplicate/O mdc_wave, $("trace" + Num2Str(j))
        

        // Calculate the peak indices
        peakIdx1 = Round(abs(coef_wave[3] - x0) / abs(dx))  // Find the closest index to Kpeak1
        peakIdx2 = Round(abs(coef_wave[6] - x0) / abs(dx))  // Find the closest index to Kpeak2


	  //Coefficient here is significant because of determination of the amplitude

        // Ensure index range to avoid out-of-bounds error
        if (peakIdx1 - fdta < 0)
            fdta = peakIdx1  // Adjust fdta to avoid negative index
        endif

        if (peakIdx2 + bdta >= nx)
            bdta = nx - peakIdx2 - 1  // Adjust bdta to avoid exceeding the limit
        endif
if(doDoublefit)
  //    if (Abs(coef_wave[3] - coef_wave[6]) > res &&Abs(coef_wave[6]-Kpeak2)<1&&Abs(coef_wave[6] - coef_wave[3]) < Abs(Kpeak1 - Kpeak2) + 0.2 &&SigmaP1K[validPoints-1]<0.2 && SigmaP2K[validPoints-1]<0.2 )
            // Perform Lorentzian fit
            Make/O/N=(fdta + bdta + FixIdx2 - FixIdx1 + 1) tpt
            tpt = mdc_wave[FixIdx1 - fdta + p]
            
//           coef_wave[2] = abs(coef_wave[2])  
//           coef_wave[3] = abs(coef_wave[3])  // K3 initial guess
//           coef_wave[4] = abs(coef_wave[4])  
//           coef_wave[5] = abs(coef_wave[5])  // K3 initial guess
//           coef_wave[6] = abs(coef_wave[6])  
//           coef_wave[7] = abs(coef_wave[7])  // K3 initial guess

            // Ensure tpt has the same X-axis scale as mdc_wave
            SetScale/P x, x0 + (FixIdx1 - fdta) * dx, dx, tpt
		Duplicate/o tpt, $("fit_trace" + Num2Str(j))
            FuncFit/H="000000001"/Q/N=1 two_lor, kwCWave=coef_wave, tpt/D=$("fit_trace" + Num2Str(j))
    		
            // Save fit result to a new wave
//if (Abs(coef_wave[3] - coef_wave[6]) > res &&Abs(coef_wave[6]-Kpeak2)<1&&Abs(coef_wave[6] - coef_wave[3]) < Abs(Kpeak1 - Kpeak2) + 0.2 &&SigmaP1K[validPoints-1]<0.2 && SigmaP2K[validPoints-1]<0.2 )
//if(1)
if(Abs(coef_wave[6]-Kpeak2)<1&&Abs(coef_wave[3]-Kpeak1)<1&&W_sigma[3]<0.2 &&W_sigma[6]<0.2 )
//  if (Abs(coef_wave[3] - coef_wave[6]) > res && Abs(coef_wave[6]-Kpeak2)<1&&Abs(coef_wave[6] - coef_wave[3]) < Abs(Kpeak1 - Kpeak2)  +0.2&&W_sigma[3]<0.2 &&W_sigma[6]<0.2 &&coef_wave[6]<8)//最后一个硬凑的条件

                // Save fitted momentum if fitting is successful
                Peak1K[validPoints] = coef_wave[3]
                Peak2K[validPoints] = coef_wave[6]
                SigmaP1K[validPoints] =W_sigma[3]
                SigmaP2K[validPoints] =W_sigma[6]
                validPoints += 1
//            	cfw[0] = coef_wave[0]
//            	cfw[1] = coef_wave[1]
            	cfw[3] = coef_wave[3]     
        	else
        		dodoublefit=0
        		Make/O/N=(fdta + bdta+2* singleinterval+1) tpt
            	tpt = mdc_wave[Round(abs(Peak1K[validPoints-1] - x0) / abs(dx)) - fdta+singleinterval+ p]
            	Killwaves $("fit_trace" + Num2Str(j))

            // Ensure tpt has the same X-axis scale as mdc_wave
           		SetScale/P x, x0 + (Round(abs(Peak1K[validPoints-1] - x0) / abs(dx)) - fdta+singleinterval) * dx, dx, tpt
			Duplicate/o tpt, $("fit_trace" + Num2Str(j))
            	FuncFit /Q/N=1 onelor_ljz, kwCWave=cfw, tpt/D=$("fit_trace" + Num2Str(j))
            	Peak3K[vp2] = cfw[3]
            	SigmaP3K[vp2] = W_sigma[3]
            	vp2 += 1            
        	endif
else
            // Single Lorentzian fit

            Make/O/N=(fdta + bdta+2* singleinterval+1) tpt
            tpt = mdc_wave[Round(abs(Peak1K[validPoints-1] - x0) / abs(dx)) - fdta+singleinterval+ p]
            Killwaves $("fit_trace" + Num2Str(j))

            // Ensure tpt has the same X-axis scale as mdc_wave
            SetScale/P x, x0 + (Round(abs(Peak1K[validPoints-1] - x0) / abs(dx)) - fdta+singleinterval) * dx, dx, tpt
		Duplicate/o tpt, $("fit_trace" + Num2Str(j))
            FuncFit /Q/N=1 onelor_ljz, kwCWave=cfw, tpt/D=$("fit_trace" + Num2Str(j))
            Peak3K[vp2] = cfw[3]
            SigmaP3K[vp2] = W_sigma[3]
            vp2 += 1
//        		endif
//        	 else
//            // Single Lorentzian fit
//            Make/O/N=(fdta + bdta+ 2* singleinterval+1) tpt
//            tpt = mdc_wave[Round(abs(Peak1K[validPoints-1] - y0) / abs(dy)) - fdta-singleinterval+ p]
//
//            // Ensure tpt has the same X-axis scale as mdc_wave
//            SetScale/P x, y0 + (Round(abs(Peak1K[validPoints-1] - y0) / abs(dy)) - fdta-singleinterval) * dy, dy, tpt
//		Duplicate/o tpt, $("fit_layer" + Num2Str(k) + "_at" + Num2Str(Eindex))
//            FuncFit /Q/N=1 onelor_ljz, kwCWave=cfw, tpt/D=$("fit_layer" + Num2Str(k) + "_at" + Num2Str(Eindex))
//
//            Peak3K[vp2] = cfw[3]
//            SigmaP3K[vp2] = W_sigma[3]
//            vp2 += 1
     
endif
        // Offset each layer's original curve and fitted curve
        Wave layer = $("trace" + Num2Str(j))
        Wave fit_layer = $("fit_trace" + Num2Str(j))

        if (j == 0)
            DoWindow/K $("mdc_olap"+nameofwave(w))
            Display/n=$("mdc_olap"+nameofwave(w)) layer  // Display first layer
        else
            AppendToGraph layer  // Append other layers
            ModifyGraph offset($("trace" + Num2Str(j))) = {0, j * kvary}
        endif

        AppendToGraph/C=(0, 65535, 65535) fit_layer  // Append fitted curve to the same graph
        ModifyGraph offset($("fit_trace" + Num2Str(j))) = {0, j * kvary}
        Label left, "Intensity (a.u.)"
        Label bottom, "Position (Å\\S-1\\M)"
    endfor

    // Set scale and dimensions for the results
    Killwindow/Z $("mdc_tlf"+NameOfWave(w))
    Redimension/N=(validPoints) Peak1K
    Redimension/N=(validPoints) Peak2K
    SetScale/P x, y0, dy, Peak1K
    SetScale/P x, y0, dy, Peak2K
    Redimension/N=(validPoints) SigmaP1K
    Redimension/N=(validPoints) SigmaP2K
    SetScale/P x, y0, dy, SigmaP1K
    SetScale/P x, y0, dy, SigmaP2K

    Redimension/N=(vp2) Peak3K
    SetScale/P x, y0 + (validPoints ) * dy, dy, Peak3K
    Redimension/N=(vp2) SigmaP3K
    SetScale/P x, y0 + (validPoints ) * dy, dy, SigmaP3K

    // Plot Peak1K and Peak2K versus time
    Display/N=$("mdc_tlf"+NameOfWave(w)) Peak1K
    AppendToGraph Peak2K
    AppendToGraph Peak3K
    ErrorBars/RGB=(0, 0, 0) Peak1K Y, wave=(SigmaP1K, SigmaP1K)
    ErrorBars/RGB=(0, 0, 0) Peak2K Y, wave=(SigmaP2K, SigmaP2K)
    ErrorBars/RGB=(0, 65535, 65535) Peak3K Y, wave=(SigmaP3K, SigmaP3K)
    Label left, "Position (Å\\S-1\\M)"
    
    if (ParamIsDefault(uz))
        Label bottom, "Delay time (ps)"
    elseif (uz == 1)
        Label bottom, "Temperature (K)"
    elseif (uz == 2)
        Label bottom, "Fluence (mW)"
    endif


    // Remove temporary waves
    KillWaves mdc_wave, tpt,cfw,W_sigma,coef_wave
    SetDataFolder root:
End

Function Hmap_LJZ20250421(w,x1,x2)
     wave w
     variable x1,x2      
    // 新增：交互式标签选择
    String yLabelList = "Delay time (ps);Temperature (K);Fluence (μJ/cm\\S2\\M)"
    Variable selection
    Prompt selection, "选择纵轴标签", popup yLabelList
    DoPrompt "标签配置", selection
    if(V_flag)  // 用户取消操作
        return -1
    endif
    String yLabel = StringFromList(selection-1, yLabelList)
     setscale/p x,dimOffset(w,0),dimdelta(w,0),"",w
     Dowindow/K $("heatmap"+nameofWave(w))
	display/K=1/N=$("heatmap"+nameofWave(w))
	appendimage/W=$("heatmap"+nameofWave(w)) w
	variable maxval=wavemax(w)
	ModifyImage $nameOfWave(w) ctab= {0,maxval,root:ImageCT:Image_CT,0}
	ModifyGraph mirror=2
	ModifyGraph standoff(bottom)=0
	ModifyGraph standoff(left)=0
	setaxis bottom,x1,x2
	if(selection==1)
	variable tune=1
	ModifyGraph manTick(left)={0,20,0,0},manMinor(left)={1,50}
	elseif(selection==3)
	setscale/p y,12,12,w
	ModifyGraph manTick(left)={0,40,0,0},manMinor(left)={1,50}
	endif
	ModifyGraph manTick(bottom)={0,0.1,0,1},manMinor(bottom)={1,50}
	variable vp1=numpnts(root:$(NameOfWave(w) + "_MDC_HP"):peak1k)
	make/o/n=(numpnts(root:$(NameOfWave(w) + "_MDC_HP"):peak1k)) root:$(NameOfWave(w) + "_MDC_HP"):ylist=dimOffset(w,1)+p*dimDelta(w,1)
	make/o/n=(numpnts(root:$(NameOfWave(w) + "_MDC_HP"):peak3k)) root:$(NameOfWave(w) + "_MDC_HP"):ylist2=dimOffset(w,1)+(p+vp1)*dimDelta(w,1)
	appendtoGraph/B root:$(NameOfWave(w) + "_MDC_HP"):ylist vs root:$(NameOfWave(w) + "_MDC_HP"):peak1k
	appendtoGraph/B root:$(NameOfWave(w) + "_MDC_HP"):ylist vs root:$(NameOfWave(w) + "_MDC_HP"):peak2k
	appendtoGraph/B root:$(NameOfWave(w) + "_MDC_HP"):ylist2 vs root:$(NameOfWave(w) + "_MDC_HP"):peak3k
	ModifyGraph mode(ylist)=4,marker(ylist)=19,rgb(ylist)=(65535,21845,0)
	ModifyGraph mode(ylist#1)=4,marker(ylist#1)=16,rgb(ylist#1)=(65535,0,0)
	ModifyGraph mode(ylist2)=4,marker(ylist2)=19,rgb(ylist2)=(65535,21845,0)
	Label bottom "k\\B// \\M(Å\\S-1\\M)" 
	Label left yLabel
	ModifyGraph lblMargin(left)=10
end

Function T3WV_LJZ20251209()
    // 默认使用全局波：
    //   Peak1K, Peak2K, Peak3K (3 可选)
    //   SigmaP1K, SigmaP2K (必有), SigmaP3K (可选)

    Wave/Z Peak1K, Peak2K, Peak3K
    Wave/Z SigmaP1K, SigmaP2K, SigmaP3K

    // ------ 检查必要波是否存在 ------
    if (!WaveExists(Peak1K) || !WaveExists(Peak2K))
        Print "T3WV_LJZ20251209: Peak1K 或 Peak2K 不存在，无法执行变换。"
        return -1
    endif
    if (!WaveExists(SigmaP1K) || !WaveExists(SigmaP2K))
        Print "T3WV_LJZ20251209: SigmaP1K 或 SigmaP2K 不存在，无法画误差棒。"
        return -1
    endif
    // Peak3K 和 SigmaP3K 是可选的

    // ---------- 1. 计算线性变换系数 a, b (y = a*x + b) ----------
    Variable xA = -1.15
    Variable yA = -0.165
    Variable xB = 12.3
    Variable yB = 0

    Variable a = (yA - yB) / (xA - xB)
    Variable b = yB - a * xB
    // 满足：-1.14 -> -0.15673, -12.3 -> 0

    // ---------- 2. 为 Peak?K 创建变换后的副本 ----------
    Duplicate/O Peak1K, Peak1K_tr
    Duplicate/O Peak2K, Peak2K_tr
    if (WaveExists(Peak3K))
        Duplicate/O Peak3K, Peak3K_tr
    endif

    // ---------- 3. 为 Sigma?K 创建变换后的副本 ----------
    Duplicate/O SigmaP1K, SigmaP1K_tr
    Duplicate/O SigmaP2K, SigmaP2K_tr
    if (WaveExists(SigmaP3K))
        Duplicate/O SigmaP3K, SigmaP3K_tr
    endif

    // ---------- 4. 对数据做线性变换 ----------
    Peak1K_tr = a * Peak1K_tr + b
    Peak2K_tr = a * Peak2K_tr + b
    if (WaveExists(Peak3K_tr))
        Peak3K_tr = a * Peak3K_tr + b
    endif

    // ---------- 5. 对 sigma 做对应的缩放变换 (σ_new = |a| * σ_old) ----------
    SigmaP1K_tr = abs(a) * SigmaP1K_tr
    SigmaP2K_tr = abs(a) * SigmaP2K_tr
    if (WaveExists(SigmaP3K_tr))
        SigmaP3K_tr = abs(a) * SigmaP3K_tr
    endif

    // ---------- 6. 将变换后的波追加到当前 top 图窗口（只追加一次） ----------
    String gName = WinName(0, 1)    // 当前最上层 graph 名字

    if (strlen(gName) == 0)
        // 当前没有图：新建一个，画上变换后的曲线
        Display Peak1K_tr
        AppendToGraph Peak2K_tr
        if (WaveExists(Peak3K_tr))
            AppendToGraph Peak3K_tr
        endif
    else
        // 已有图：激活并只在不存在时 Append
        DoWindow/F $gName
        String traces = TraceNameList("", ";", 1)

        if (WhichListItem("Peak1K_tr", traces, ";", 0) < 0)
            AppendToGraph/W=$gName Peak1K_tr
            ModifyGraph/W=$gName mode(Peak1K_tr)=2,lsize(Peak1K_tr)=4,rgb(Peak1K_tr)=(1,16019,65535)
        endif

        if (WhichListItem("Peak2K_tr", traces, ";", 0) < 0)
            AppendToGraph/W=$gName Peak2K_tr
            ModifyGraph/W=$gName mode(Peak2K_tr)=2,lsize(Peak2K_tr)=4,rgb(Peak2K_tr)=(52428,1,1)
        endif

        if (WaveExists(Peak3K_tr))
            if (WhichListItem("Peak3K_tr", traces, ";", 0) < 0)
                AppendToGraph/W=$gName Peak3K_tr
                ModifyGraph/W=$gName mode(Peak3K_tr)=2,lsize(Peak3K_tr)=8,rgb(Peak3K_tr)=(1,52428,52428)
            endif
        endif
    endif

    // ---------- 7. 给 top graph 中已有的 *_tr trace 加误差条 ----------
    // 再取一次当前前台 graph 的 trace 列表（可能刚刚 append 过）
    String traces2 = TraceNameList("", ";", 1)

    if (WhichListItem("Peak1K_tr", traces2, ";", 0) >= 0 && WaveExists(SigmaP1K_tr))
        ErrorBars Peak1K_tr Y, wave=(SigmaP1K_tr, SigmaP1K_tr)
    endif

    if (WhichListItem("Peak2K_tr", traces2, ";", 0) >= 0 && WaveExists(SigmaP2K_tr))
        ErrorBars Peak2K_tr Y, wave=(SigmaP2K_tr, SigmaP2K_tr)
    endif

    if (WaveExists(Peak3K_tr) && WaveExists(SigmaP3K_tr))
        if (WhichListItem("Peak3K_tr", traces2, ";", 0) >= 0)
            ErrorBars Peak3K_tr Y, wave=(SigmaP3K_tr, SigmaP3K_tr)
        endif
    endif

    return 0
End





