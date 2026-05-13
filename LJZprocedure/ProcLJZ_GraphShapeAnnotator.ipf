#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma DefaultTab={3,20,4}

// ============================================================================
//  LJZ Graph Shape Annotator v3
//
//  改动摘要：
//    1) 保留全部绘图逻辑函数，新增目标图锁定与 Undo 栈。
//    2) 重构面板为三行布局 + Tab 切换。
//    3) 新增线色/填充色预览刷新、独立填充色、回调逻辑。
//    4) 绘图对象自动登记，支持最多 20 步 Undo。
// ============================================================================

Menu "ARPES_LJZ"
    "Graph Shape Annotator v3", LJZ_GSA2_OpenPanel()
    "Clear Graph Shape Layer v3", LJZ_GSA2_ClearTopGraphDrawings()
End

// 返回数据文件夹路径
Function/S LJZ_GSA2_BaseDF()
    return "root:Packages:LJZ_GraphShapeAnnotatorV2"
End

// 返回面板窗口名
Function/S LJZ_GSA2_PanelName()
    return "LJZ_GraphShapeAnnotatorV3_Panel"
End

// 初始化全局状态变量与缓存波形
Function LJZ_GSA2_EnsureDF()
    NewDataFolder/O root:Packages
    NewDataFolder/O $(LJZ_GSA2_BaseDF())

    NVAR/Z x1 = $(LJZ_GSA2_BaseDF() + ":x1"); if (!NVAR_Exists(x1)); Variable/G $(LJZ_GSA2_BaseDF() + ":x1") = 0; endif
    NVAR/Z y1 = $(LJZ_GSA2_BaseDF() + ":y1"); if (!NVAR_Exists(y1)); Variable/G $(LJZ_GSA2_BaseDF() + ":y1") = 0; endif
    NVAR/Z x2 = $(LJZ_GSA2_BaseDF() + ":x2"); if (!NVAR_Exists(x2)); Variable/G $(LJZ_GSA2_BaseDF() + ":x2") = 1; endif
    NVAR/Z y2 = $(LJZ_GSA2_BaseDF() + ":y2"); if (!NVAR_Exists(y2)); Variable/G $(LJZ_GSA2_BaseDF() + ":y2") = 1; endif
    NVAR/Z cx = $(LJZ_GSA2_BaseDF() + ":cx"); if (!NVAR_Exists(cx)); Variable/G $(LJZ_GSA2_BaseDF() + ":cx") = 0; endif
    NVAR/Z cy = $(LJZ_GSA2_BaseDF() + ":cy"); if (!NVAR_Exists(cy)); Variable/G $(LJZ_GSA2_BaseDF() + ":cy") = 0; endif
    NVAR/Z rx = $(LJZ_GSA2_BaseDF() + ":rx"); if (!NVAR_Exists(rx)); Variable/G $(LJZ_GSA2_BaseDF() + ":rx") = 0.1; endif
    NVAR/Z ry = $(LJZ_GSA2_BaseDF() + ":ry"); if (!NVAR_Exists(ry)); Variable/G $(LJZ_GSA2_BaseDF() + ":ry") = 1; endif
    NVAR/Z radius = $(LJZ_GSA2_BaseDF() + ":radius"); if (!NVAR_Exists(radius)); Variable/G $(LJZ_GSA2_BaseDF() + ":radius") = 1; endif
    NVAR/Z tx1 = $(LJZ_GSA2_BaseDF() + ":tx1"); if (!NVAR_Exists(tx1)); Variable/G $(LJZ_GSA2_BaseDF() + ":tx1") = 0; endif
    NVAR/Z ty1 = $(LJZ_GSA2_BaseDF() + ":ty1"); if (!NVAR_Exists(ty1)); Variable/G $(LJZ_GSA2_BaseDF() + ":ty1") = 0; endif
    NVAR/Z tx2 = $(LJZ_GSA2_BaseDF() + ":tx2"); if (!NVAR_Exists(tx2)); Variable/G $(LJZ_GSA2_BaseDF() + ":tx2") = 1; endif
    NVAR/Z ty2 = $(LJZ_GSA2_BaseDF() + ":ty2"); if (!NVAR_Exists(ty2)); Variable/G $(LJZ_GSA2_BaseDF() + ":ty2") = 0; endif
    NVAR/Z tx3 = $(LJZ_GSA2_BaseDF() + ":tx3"); if (!NVAR_Exists(tx3)); Variable/G $(LJZ_GSA2_BaseDF() + ":tx3") = 0.5; endif
    NVAR/Z ty3 = $(LJZ_GSA2_BaseDF() + ":ty3"); if (!NVAR_Exists(ty3)); Variable/G $(LJZ_GSA2_BaseDF() + ":ty3") = 1; endif
    NVAR/Z triWidth = $(LJZ_GSA2_BaseDF() + ":triWidth"); if (!NVAR_Exists(triWidth)); Variable/G $(LJZ_GSA2_BaseDF() + ":triWidth") = 1; endif
    NVAR/Z triHeight = $(LJZ_GSA2_BaseDF() + ":triHeight"); if (!NVAR_Exists(triHeight)); Variable/G $(LJZ_GSA2_BaseDF() + ":triHeight") = 1; endif
    NVAR/Z triDir = $(LJZ_GSA2_BaseDF() + ":triDir"); if (!NVAR_Exists(triDir)); Variable/G $(LJZ_GSA2_BaseDF() + ":triDir") = 0; endif
    NVAR/Z red = $(LJZ_GSA2_BaseDF() + ":red"); if (!NVAR_Exists(red)); Variable/G $(LJZ_GSA2_BaseDF() + ":red") = 65535; endif
    NVAR/Z green = $(LJZ_GSA2_BaseDF() + ":green"); if (!NVAR_Exists(green)); Variable/G $(LJZ_GSA2_BaseDF() + ":green") = 0; endif
    NVAR/Z blue = $(LJZ_GSA2_BaseDF() + ":blue"); if (!NVAR_Exists(blue)); Variable/G $(LJZ_GSA2_BaseDF() + ":blue") = 0; endif
    NVAR/Z lineThick = $(LJZ_GSA2_BaseDF() + ":lineThick"); if (!NVAR_Exists(lineThick)); Variable/G $(LJZ_GSA2_BaseDF() + ":lineThick") = 2; endif
    NVAR/Z dash = $(LJZ_GSA2_BaseDF() + ":dash"); if (!NVAR_Exists(dash)); Variable/G $(LJZ_GSA2_BaseDF() + ":dash") = 0; endif
    NVAR/Z fillPat = $(LJZ_GSA2_BaseDF() + ":fillPat"); if (!NVAR_Exists(fillPat)); Variable/G $(LJZ_GSA2_BaseDF() + ":fillPat") = 0; endif
    NVAR/Z drawFront = $(LJZ_GSA2_BaseDF() + ":drawFront"); if (!NVAR_Exists(drawFront)); Variable/G $(LJZ_GSA2_BaseDF() + ":drawFront") = 1; endif

    SVAR/Z lockedGraph = $(LJZ_GSA2_BaseDF() + ":lockedGraph"); if (!SVAR_Exists(lockedGraph)); String/G $(LJZ_GSA2_BaseDF() + ":lockedGraph") = ""; endif
    NVAR/Z undoCount = $(LJZ_GSA2_BaseDF() + ":undoCount"); if (!NVAR_Exists(undoCount)); Variable/G $(LJZ_GSA2_BaseDF() + ":undoCount") = 0; endif
    SVAR/Z undoNames = $(LJZ_GSA2_BaseDF() + ":undoNames"); if (!SVAR_Exists(undoNames)); String/G $(LJZ_GSA2_BaseDF() + ":undoNames") = ""; endif
    NVAR/Z activeTab = $(LJZ_GSA2_BaseDF() + ":activeTab"); if (!NVAR_Exists(activeTab)); Variable/G $(LJZ_GSA2_BaseDF() + ":activeTab") = 0; endif
    NVAR/Z fillR = $(LJZ_GSA2_BaseDF() + ":fillR"); if (!NVAR_Exists(fillR)); Variable/G $(LJZ_GSA2_BaseDF() + ":fillR") = 65535; endif
    NVAR/Z fillG = $(LJZ_GSA2_BaseDF() + ":fillG"); if (!NVAR_Exists(fillG)); Variable/G $(LJZ_GSA2_BaseDF() + ":fillG") = 0; endif
    NVAR/Z fillB = $(LJZ_GSA2_BaseDF() + ":fillB"); if (!NVAR_Exists(fillB)); Variable/G $(LJZ_GSA2_BaseDF() + ":fillB") = 0; endif
    NVAR/Z useSepFill = $(LJZ_GSA2_BaseDF() + ":useSepFill"); if (!NVAR_Exists(useSepFill)); Variable/G $(LJZ_GSA2_BaseDF() + ":useSepFill") = 0; endif

    Make/O/D/N=4 $(LJZ_GSA2_BaseDF() + ":polyX")
    Make/O/D/N=4 $(LJZ_GSA2_BaseDF() + ":polyY")
    return 0
End

Function/S LJZ_GSA2_GetTopGraph(); String gName=WinName(0,1); if (strlen(gName)==0); DoAlert 0,"No graph window found. Please activate or open a graph first."; return ""; endif; return gName; End
Function/S LJZ_GSA2_GetTargetGraph(); LJZ_GSA2_EnsureDF(); SVAR lockedGraph=$(LJZ_GSA2_BaseDF()+":lockedGraph"); if(strlen(lockedGraph)>0); DoWindow/F $lockedGraph; if(V_flag==1); return lockedGraph; endif; endif; return LJZ_GSA2_GetTopGraph(); End
Function LJZ_GSA2_NormalizeColorValue(v); Variable v; if(numtype(v)!=0||v<0); return 0; endif; if(v>65535); return 65535; endif; return round(v); End
Function LJZ_GSA2_AbsValue(v); Variable v; if(numtype(v)!=0); return 0; endif; if(v<0); return -v; endif; return v; End

Function/S LJZ_GSA2_GetDrawObjList(gName); String gName; DrawAction/W=$gName/L=ProgFront getList; return S_value; End
Function/S LJZ_GSA2_DiffList(after,before); String after,before; Variable i,n=ItemsInList(after,";"); String it; for(i=0;i<n;i+=1); it=StringFromList(i,after,";"); if(WhichListItem(it,before,";",0,0)<0); return it; endif; endfor; return ""; End
Function LJZ_GSA2_RegisterUndo(gName,objName); String gName,objName; LJZ_GSA2_EnsureDF(); if(strlen(objName)==0); return 0; endif; NVAR undoCount=$(LJZ_GSA2_BaseDF()+":undoCount"); SVAR undoNames=$(LJZ_GSA2_BaseDF()+":undoNames"); undoNames=AddListItem(objName,undoNames,";",Inf); undoCount+=1; do; if(undoCount<=20); break; endif; undoNames=RemoveFromList(StringFromList(0,undoNames,";"),undoNames,";"); undoCount-=1; while(1); return 0; End
Function LJZ_GSA2_Undo(); LJZ_GSA2_EnsureDF(); NVAR undoCount=$(LJZ_GSA2_BaseDF()+":undoCount"); SVAR undoNames=$(LJZ_GSA2_BaseDF()+":undoNames"); String gName,objName; if(undoCount<=0); Beep; return -1; endif; objName=StringFromList(undoCount-1,undoNames,";"); undoNames=RemoveFromList(objName,undoNames,";"); undoCount-=1; gName=LJZ_GSA2_GetTargetGraph(); if(strlen(gName)==0); return -1; endif; DrawAction/W=$gName/L=ProgFront/N=$objName delete; return 0; End

Function LJZ_GSA2_SetDrawEnv(gName)
    String gName
    LJZ_GSA2_EnsureDF()
    NVAR red=$(LJZ_GSA2_BaseDF()+":red"); NVAR green=$(LJZ_GSA2_BaseDF()+":green"); NVAR blue=$(LJZ_GSA2_BaseDF()+":blue")
    NVAR fillR=$(LJZ_GSA2_BaseDF()+":fillR"); NVAR fillG=$(LJZ_GSA2_BaseDF()+":fillG"); NVAR fillB=$(LJZ_GSA2_BaseDF()+":fillB"); NVAR useSepFill=$(LJZ_GSA2_BaseDF()+":useSepFill")
    NVAR lineThick=$(LJZ_GSA2_BaseDF()+":lineThick"); NVAR dash=$(LJZ_GSA2_BaseDF()+":dash"); NVAR fillPat=$(LJZ_GSA2_BaseDF()+":fillPat"); NVAR drawFront=$(LJZ_GSA2_BaseDF()+":drawFront")
    Variable r=LJZ_GSA2_NormalizeColorValue(red),g=LJZ_GSA2_NormalizeColorValue(green),b=LJZ_GSA2_NormalizeColorValue(blue)
    Variable fr=LJZ_GSA2_NormalizeColorValue(fillR),fg=LJZ_GSA2_NormalizeColorValue(fillG),fb=LJZ_GSA2_NormalizeColorValue(fillB)
    Variable lt=lineThick,ds=round(dash),fp=round(fillPat)
    if(numtype(lt)!=0||lt<=0); lt=1; endif
    if(numtype(ds)!=0||ds<0); ds=0; endif
    if(numtype(fp)!=0||fp<0); fp=0; endif
    if(drawFront); SetDrawLayer/W=$gName ProgFront; else; SetDrawLayer/W=$gName UserFront; endif
    if(useSepFill==1)
        SetDrawEnv/W=$gName xcoord=bottom,ycoord=left,linefgc=(r,g,b),fillfgc=(fr,fg,fb),linethick=lt,dash=ds,fillpat=fp
    else
        SetDrawEnv/W=$gName xcoord=bottom,ycoord=left,linefgc=(r,g,b),fillfgc=(r,g,b),linethick=lt,dash=ds,fillpat=fp
    endif
    return 0
End

Function LJZ_GSA2_GetBox(xx1, yy1, xx2, yy2); Variable &xx1,&yy1,&xx2,&yy2; NVAR x1=$(LJZ_GSA2_BaseDF()+":x1");NVAR y1=$(LJZ_GSA2_BaseDF()+":y1");NVAR x2=$(LJZ_GSA2_BaseDF()+":x2");NVAR y2=$(LJZ_GSA2_BaseDF()+":y2"); xx1=min(x1,x2);xx2=max(x1,x2);yy1=min(y1,y2);yy2=max(y1,y2); return 0; End

Function LJZ_GSA2_AddLine(); String gName=LJZ_GSA2_GetTargetGraph(); if(strlen(gName)==0); return -1; endif; NVAR x1=$(LJZ_GSA2_BaseDF()+":x1");NVAR y1=$(LJZ_GSA2_BaseDF()+":y1");NVAR x2=$(LJZ_GSA2_BaseDF()+":x2");NVAR y2=$(LJZ_GSA2_BaseDF()+":y2"); LJZ_GSA2_SetDrawEnv(gName); String b=LJZ_GSA2_GetDrawObjList(gName),a,n; DrawLine/W=$gName x1,y1,x2,y2; a=LJZ_GSA2_GetDrawObjList(gName); n=LJZ_GSA2_DiffList(a,b); LJZ_GSA2_RegisterUndo(gName,n); return 0; End
Function LJZ_GSA2_AddRectangleByBox(); String gName=LJZ_GSA2_GetTargetGraph(); Variable xx1,yy1,xx2,yy2; if(strlen(gName)==0); return -1; endif; LJZ_GSA2_GetBox(xx1,yy1,xx2,yy2); LJZ_GSA2_SetDrawEnv(gName); String b=LJZ_GSA2_GetDrawObjList(gName),a,n; DrawRect/W=$gName xx1,yy1,xx2,yy2; a=LJZ_GSA2_GetDrawObjList(gName); n=LJZ_GSA2_DiffList(a,b); LJZ_GSA2_RegisterUndo(gName,n); return 0; End
Function LJZ_GSA2_AddEllipseByBox(); String gName=LJZ_GSA2_GetTargetGraph(); Variable xx1,yy1,xx2,yy2; if(strlen(gName)==0); return -1; endif; LJZ_GSA2_GetBox(xx1,yy1,xx2,yy2); LJZ_GSA2_SetDrawEnv(gName); String b=LJZ_GSA2_GetDrawObjList(gName),a,n; DrawOval/W=$gName xx1,yy1,xx2,yy2; a=LJZ_GSA2_GetDrawObjList(gName); n=LJZ_GSA2_DiffList(a,b); LJZ_GSA2_RegisterUndo(gName,n); return 0; End
Function LJZ_GSA2_AddEllipseByCenter(); String gName=LJZ_GSA2_GetTargetGraph(); Variable xx1,yy1,xx2,yy2,rxx,ryy; if(strlen(gName)==0); return -1; endif; NVAR cx=$(LJZ_GSA2_BaseDF()+":cx");NVAR cy=$(LJZ_GSA2_BaseDF()+":cy");NVAR rx=$(LJZ_GSA2_BaseDF()+":rx");NVAR ry=$(LJZ_GSA2_BaseDF()+":ry"); rxx=LJZ_GSA2_AbsValue(rx); ryy=LJZ_GSA2_AbsValue(ry); xx1=cx-rxx;xx2=cx+rxx;yy1=cy-ryy;yy2=cy+ryy; LJZ_GSA2_SetDrawEnv(gName); String b=LJZ_GSA2_GetDrawObjList(gName),a,n; DrawOval/W=$gName xx1,yy1,xx2,yy2; a=LJZ_GSA2_GetDrawObjList(gName); n=LJZ_GSA2_DiffList(a,b); LJZ_GSA2_RegisterUndo(gName,n); return 0; End
Function LJZ_GSA2_AddCircleByCenter(); String gName=LJZ_GSA2_GetTargetGraph(); Variable rr; if(strlen(gName)==0); return -1; endif; NVAR cx=$(LJZ_GSA2_BaseDF()+":cx");NVAR cy=$(LJZ_GSA2_BaseDF()+":cy");NVAR radius=$(LJZ_GSA2_BaseDF()+":radius"); rr=LJZ_GSA2_AbsValue(radius); LJZ_GSA2_SetDrawEnv(gName); String b=LJZ_GSA2_GetDrawObjList(gName),a,n; DrawOval/W=$gName cx-rr,cy-rr,cx+rr,cy+rr; a=LJZ_GSA2_GetDrawObjList(gName); n=LJZ_GSA2_DiffList(a,b); LJZ_GSA2_RegisterUndo(gName,n); return 0; End
Function LJZ_GSA2_AddTriangleByBox(); String gName=LJZ_GSA2_GetTargetGraph(); Variable xx1,yy1,xx2,yy2,width,height; if(strlen(gName)==0); return -1; endif; LJZ_GSA2_GetBox(xx1,yy1,xx2,yy2); width=xx2-xx1;height=yy2-yy1; Wave polyX=$(LJZ_GSA2_BaseDF()+":polyX");Wave polyY=$(LJZ_GSA2_BaseDF()+":polyY"); polyX={0,width,0.5*width,0}; polyY={0,0,height,0}; LJZ_GSA2_SetDrawEnv(gName); String uniqueName="GSA_"+num2str(ticks); DrawPoly/W=$gName/N=$uniqueName xx1,yy1,1,1,polyX,polyY; LJZ_GSA2_RegisterUndo(gName,uniqueName); return 0; End
Function LJZ_GSA2_AddTriangleBy3Points(); String gName=LJZ_GSA2_GetTargetGraph(); if(strlen(gName)==0); return -1; endif; NVAR tx1=$(LJZ_GSA2_BaseDF()+":tx1");NVAR ty1=$(LJZ_GSA2_BaseDF()+":ty1");NVAR tx2=$(LJZ_GSA2_BaseDF()+":tx2");NVAR ty2=$(LJZ_GSA2_BaseDF()+":ty2");NVAR tx3=$(LJZ_GSA2_BaseDF()+":tx3");NVAR ty3=$(LJZ_GSA2_BaseDF()+":ty3"); Wave polyX=$(LJZ_GSA2_BaseDF()+":polyX");Wave polyY=$(LJZ_GSA2_BaseDF()+":polyY"); polyX={0,tx2-tx1,tx3-tx1,0}; polyY={0,ty2-ty1,ty3-ty1,0}; LJZ_GSA2_SetDrawEnv(gName); String uniqueName="GSA_"+num2str(ticks); DrawPoly/W=$gName/N=$uniqueName tx1,ty1,1,1,polyX,polyY; LJZ_GSA2_RegisterUndo(gName,uniqueName); return 0; End
Function LJZ_GSA2_AddTriangleByCenter(); String gName=LJZ_GSA2_GetTargetGraph(); Variable halfW,halfH,dir; if(strlen(gName)==0); return -1; endif; NVAR cx=$(LJZ_GSA2_BaseDF()+":cx");NVAR cy=$(LJZ_GSA2_BaseDF()+":cy");NVAR triWidth=$(LJZ_GSA2_BaseDF()+":triWidth");NVAR triHeight=$(LJZ_GSA2_BaseDF()+":triHeight");NVAR triDir=$(LJZ_GSA2_BaseDF()+":triDir"); halfW=0.5*LJZ_GSA2_AbsValue(triWidth);halfH=0.5*LJZ_GSA2_AbsValue(triHeight);dir=round(triDir); Wave polyX=$(LJZ_GSA2_BaseDF()+":polyX");Wave polyY=$(LJZ_GSA2_BaseDF()+":polyY"); if(dir==1);polyX={-halfW,halfW,0,-halfW};polyY={halfH,halfH,-halfH,halfH}; elseif(dir==2);polyX={-halfW,-halfW,halfW,-halfW};polyY={-halfH,halfH,0,-halfH}; elseif(dir==3);polyX={halfW,halfW,-halfW,halfW};polyY={-halfH,halfH,0,-halfH}; else;polyX={-halfW,halfW,0,-halfW};polyY={-halfH,-halfH,halfH,-halfH}; endif; LJZ_GSA2_SetDrawEnv(gName); String uniqueName="GSA_"+num2str(ticks); DrawPoly/W=$gName/N=$uniqueName cx,cy,1,1,polyX,polyY; LJZ_GSA2_RegisterUndo(gName,uniqueName); return 0; End

Function LJZ_GSA2_ClearTopGraphDrawings(); String gName=LJZ_GSA2_GetTargetGraph(); if(strlen(gName)==0); return -1; endif; SetDrawLayer/K/W=$gName ProgFront; Print "LJZ_GSA2: cleared ProgFront drawing layer in graph: "+gName; return 0; End
Function LJZ_GSA2_SetColor(newR,newG,newB); Variable newR,newG,newB; NVAR red=$(LJZ_GSA2_BaseDF()+":red");NVAR green=$(LJZ_GSA2_BaseDF()+":green");NVAR blue=$(LJZ_GSA2_BaseDF()+":blue"); red=LJZ_GSA2_NormalizeColorValue(newR); green=LJZ_GSA2_NormalizeColorValue(newG); blue=LJZ_GSA2_NormalizeColorValue(newB); LJZ_GSA2_RefreshColorPreview(); return 0; End
Function LJZ_GSA2_RedPreset(); LJZ_GSA2_SetColor(65535,0,0); return 0; End
Function LJZ_GSA2_BluePreset(); LJZ_GSA2_SetColor(0,20000,65535); return 0; End
Function LJZ_GSA2_WhitePreset(); LJZ_GSA2_SetColor(65535,65535,65535); return 0; End
Function LJZ_GSA2_BlackPreset(); LJZ_GSA2_SetColor(0,0,0); return 0; End
Function LJZ_GSA2_YellowPreset(); LJZ_GSA2_SetColor(65535,52000,0); return 0; End

Function LJZ_GSA2_RefreshColorPreview(); String p=LJZ_GSA2_PanelName(); DoWindow $p; if(!V_flag); return 0; endif; NVAR red=$(LJZ_GSA2_BaseDF()+":red");NVAR green=$(LJZ_GSA2_BaseDF()+":green");NVAR blue=$(LJZ_GSA2_BaseDF()+":blue");NVAR fillR=$(LJZ_GSA2_BaseDF()+":fillR");NVAR fillG=$(LJZ_GSA2_BaseDF()+":fillG");NVAR fillB=$(LJZ_GSA2_BaseDF()+":fillB");NVAR useSepFill=$(LJZ_GSA2_BaseDF()+":useSepFill"); Variable r=LJZ_GSA2_NormalizeColorValue(red),g=LJZ_GSA2_NormalizeColorValue(green),b=LJZ_GSA2_NormalizeColorValue(blue); Variable fr,fg,fb; if(useSepFill==1); fr=LJZ_GSA2_NormalizeColorValue(fillR);fg=LJZ_GSA2_NormalizeColorValue(fillG);fb=LJZ_GSA2_NormalizeColorValue(fillB); else; fr=r;fg=g;fb=b; endif; TitleBox tbColorPrev,win=$p,title=" ",fColor=(r,g,b); TitleBox tbFillPrev,win=$p,title=" ",fColor=(fr,fg,fb); return 0; End
Function LJZ_GSA2_SVProc(sva) : SetVariableControl; STRUCT WMSetVariableAction &sva; if (sva.eventCode != 1 && sva.eventCode != 2 && sva.eventCode != 8); return 0; endif; LJZ_GSA2_RefreshColorPreview(); return 0; End
Function LJZ_GSA2_CheckProc(cba) : CheckBoxControl; STRUCT WMCheckboxAction &cba; if(cba.eventCode!=2); return 0; endif; if(CmpStr(cba.ctrlName,"ckSepFill")!=0); return 0; endif; String p=LJZ_GSA2_PanelName(); Variable dis=!cba.checked ? 2 : 0; SetVariable svFillR,win=$p,disable=dis; SetVariable svFillG,win=$p,disable=dis; TitleBox tbFillPrev,win=$p,disable=dis; LJZ_GSA2_RefreshColorPreview(); return 0; End
Function LJZ_GSA2_PopupProc(pa) : PopupMenuControl; STRUCT WMPopupAction &pa; if(pa.eventCode!=2); return 0; endif; if(CmpStr(pa.ctrlName,"pmTriDir")!=0); return 0; endif; NVAR triDir=$(LJZ_GSA2_BaseDF()+":triDir"); triDir=pa.popNum-1; return 0; End
Function LJZ_GSA2_TabProc(tca) : TabControl; STRUCT WMTabControlAction &tca; if(tca.eventCode!=2); return 0; endif; NVAR activeTab=$(LJZ_GSA2_BaseDF()+":activeTab"); activeTab=tca.tab; LJZ_GSA2_UpdateTabVisibility(); return 0; End
Function LJZ_GSA2_OpenPanel(); LJZ_GSA2_EnsureDF(); String p=LJZ_GSA2_PanelName(); String base=LJZ_GSA2_BaseDF(); DoWindow/F $p; if(V_flag); return 0; endif; NewPanel/N=$p/W=(150,60,610,530); ModifyPanel cbRGB=(56000,56000,56000); TitleBox tbTitle,pos={8,10},size={180,18},title="GSA v3",frame=0,fStyle=1,fSize=13; Button btLock,pos={200,8},size={90,22},title="Lock Graph",proc=LJZ_GSA2_ButtonProc; TitleBox tbLockedName,pos={298,11},size={150,16},title="(unlocked)",frame=0,fSize=10; Button btUndo,pos={8,36},size={60,22},title="Undo",proc=LJZ_GSA2_ButtonProc; Button btClear,pos={76,36},size={60,22},title="Clear All",proc=LJZ_GSA2_ButtonProc; Button btClose,pos={390,8},size={60,22},title="Close",proc=LJZ_GSA2_ButtonProc; TabControl tcShape,pos={8,64},size={444,310},tabLabel(0)="Line / Box",tabLabel(1)="Circle / Ellipse",tabLabel(2)="Triangle",value=0,proc=LJZ_GSA2_TabProc;
SetVariable svX1,pos={30,100},size={200,20},title="x1",limits={-inf,inf,0.01},value=$(base+":x1"); SetVariable svY1,pos={30,126},size={200,20},title="y1",limits={-inf,inf,0.01},value=$(base+":y1"); SetVariable svX2,pos={30,152},size={200,20},title="x2",limits={-inf,inf,0.01},value=$(base+":x2"); SetVariable svY2,pos={30,178},size={200,20},title="y2",limits={-inf,inf,0.01},value=$(base+":y2"); Button btLine,pos={30,210},size={80,26},title="Line",proc=LJZ_GSA2_ButtonProc; Button btRect,pos={118,210},size={80,26},title="Rect",proc=LJZ_GSA2_ButtonProc; Button btEllipseBox,pos={206,210},size={80,26},title="OvalBox",proc=LJZ_GSA2_ButtonProc;
SetVariable svCX,pos={30,100},size={200,20},title="cx",limits={-inf,inf,0.01},value=$(base+":cx"); SetVariable svCY,pos={30,126},size={200,20},title="cy",limits={-inf,inf,0.01},value=$(base+":cy"); SetVariable svRX,pos={30,152},size={200,20},title="rx (ellipse)",limits={0,inf,0.01},value=$(base+":rx"); SetVariable svRY,pos={30,178},size={200,20},title="ry (ellipse)",limits={0,inf,0.01},value=$(base+":ry"); SetVariable svRad,pos={30,204},size={200,20},title="radius (circle)",limits={0,inf,0.01},value=$(base+":radius"); Button btEllipseCenter,pos={30,234},size={100,26},title="Ellipse",proc=LJZ_GSA2_ButtonProc; Button btCircleCenter,pos={138,234},size={100,26},title="Circle",proc=LJZ_GSA2_ButtonProc;
TitleBox tbT3,pos={30,96},size={120,16},title="3 Vertices",frame=0,fStyle=1; SetVariable svTX1,pos={30,116},size={190,20},title="tx1",limits={-inf,inf,0.01},value=$(base+":tx1"); SetVariable svTY1,pos={30,140},size={190,20},title="ty1",limits={-inf,inf,0.01},value=$(base+":ty1"); SetVariable svTX2,pos={240,116},size={190,20},title="tx2",limits={-inf,inf,0.01},value=$(base+":tx2"); SetVariable svTY2,pos={240,140},size={190,20},title="ty2",limits={-inf,inf,0.01},value=$(base+":ty2"); SetVariable svTX3,pos={30,164},size={190,20},title="tx3",limits={-inf,inf,0.01},value=$(base+":tx3"); SetVariable svTY3,pos={240,164},size={190,20},title="ty3",limits={-inf,inf,0.01},value=$(base+":ty3"); Button btTri3P,pos={30,196},size={90,26},title="Tri 3P",proc=LJZ_GSA2_ButtonProc; Button btTriBox,pos={130,196},size={90,26},title="Tri Box",proc=LJZ_GSA2_ButtonProc; TitleBox tbTC,pos={30,236},size={180,16},title="Center mode  (uses cx,cy above)",frame=0,fStyle=1; SetVariable svTriW,pos={30,256},size={190,20},title="width",limits={0,inf,0.01},value=$(base+":triWidth"); SetVariable svTriH,pos={240,256},size={190,20},title="height",limits={0,inf,0.01},value=$(base+":triHeight"); PopupMenu pmTriDir,pos={30,284},size={200,22},title="dir",value="↑ Up (0);↓ Down (1);→ Right (2);← Left (3)",proc=LJZ_GSA2_PopupProc; Button btTriCenter,pos={30,316},size={110,26},title="Tri Center",proc=LJZ_GSA2_ButtonProc;
GroupBox gbStyle,pos={8,384},size={444,118},title="Style"; TitleBox tbColorPrev,pos={18,402},size={36,36},title=" ",frame=1,fColor=(65535,0,0); SetVariable svR,pos={62,402},size={110,20},title="R",limits={0,65535,1000},value=$(base+":red"),proc=LJZ_GSA2_SVProc; SetVariable svG,pos={62,424},size={110,20},title="G",limits={0,65535,1000},value=$(base+":green"),proc=LJZ_GSA2_SVProc; SetVariable svB,pos={62,446},size={110,20},title="B",limits={0,65535,1000},value=$(base+":blue"),proc=LJZ_GSA2_SVProc; Button btRed,pos={180,402},size={40,20},title="R",fColor=(65535,0,0),proc=LJZ_GSA2_ButtonProc; Button btBlue,pos={224,402},size={40,20},title="B",fColor=(0,20000,65535),proc=LJZ_GSA2_ButtonProc; Button btYellow,pos={268,402},size={40,20},title="Y",fColor=(65535,52000,0),proc=LJZ_GSA2_ButtonProc; Button btWhite,pos={312,402},size={40,20},title="W",fColor=(65535,65535,65535),proc=LJZ_GSA2_ButtonProc; Button btBlack,pos={356,402},size={40,20},title="K",fColor=(0,0,0),proc=LJZ_GSA2_ButtonProc; CheckBox ckSepFill,pos={180,428},size={120,18},title="Sep. Fill Color",variable=$(base+":useSepFill"),proc=LJZ_GSA2_CheckProc; TitleBox tbFillPrev,pos={308,426},size={36,36},title=" ",frame=1,fColor=(65535,0,0); SetVariable svFillR,pos={350,428},size={96,20},title="fR",limits={0,65535,1000},value=$(base+":fillR"),proc=LJZ_GSA2_SVProc; SetVariable svFillG,pos={350,450},size={96,20},title="fG",limits={0,65535,1000},value=$(base+":fillG"),proc=LJZ_GSA2_SVProc; SetVariable svThick,pos={180,450},size={110,20},title="Thick",limits={0.1,30,0.5},value=$(base+":lineThick"); SetVariable svDash,pos={180,472},size={110,20},title="Dash (0=solid)",limits={0,17,1},value=$(base+":dash"); SetVariable svFill,pos={300,472},size={110,20},title="FillPat",limits={0,20,1},value=$(base+":fillPat"); CheckBox ckFront,pos={418,402},size={30,18},title="PF",variable=$(base+":drawFront");
LJZ_GSA2_UpdateTabVisibility(); LJZ_GSA2_RefreshColorPreview(); NVAR useSepFill=$(base+":useSepFill"); if(useSepFill==0); SetVariable svFillR,win=$p,disable=2; SetVariable svFillG,win=$p,disable=2; TitleBox tbFillPrev,win=$p,disable=2; endif; return 0; End
Function LJZ_GSA2_UpdateTabVisibility(); String p=LJZ_GSA2_PanelName(); NVAR activeTab=$(LJZ_GSA2_BaseDF()+":activeTab"); Variable d0=(activeTab==0)?0:1,d1=(activeTab==1)?0:1,d2=(activeTab==2)?0:1; SetVariable svX1,win=$p,disable=d0;SetVariable svY1,win=$p,disable=d0;SetVariable svX2,win=$p,disable=d0;SetVariable svY2,win=$p,disable=d0;Button btLine,win=$p,disable=d0;Button btRect,win=$p,disable=d0;Button btEllipseBox,win=$p,disable=d0; SetVariable svCX,win=$p,disable=d1;SetVariable svCY,win=$p,disable=d1;SetVariable svRX,win=$p,disable=d1;SetVariable svRY,win=$p,disable=d1;SetVariable svRad,win=$p,disable=d1;Button btEllipseCenter,win=$p,disable=d1;Button btCircleCenter,win=$p,disable=d1; TitleBox tbT3,win=$p,disable=d2;SetVariable svTX1,win=$p,disable=d2;SetVariable svTY1,win=$p,disable=d2;SetVariable svTX2,win=$p,disable=d2;SetVariable svTY2,win=$p,disable=d2;SetVariable svTX3,win=$p,disable=d2;SetVariable svTY3,win=$p,disable=d2;Button btTri3P,win=$p,disable=d2;Button btTriBox,win=$p,disable=d2;TitleBox tbTC,win=$p,disable=d2;SetVariable svTriW,win=$p,disable=d2;SetVariable svTriH,win=$p,disable=d2;PopupMenu pmTriDir,win=$p,disable=d2;Button btTriCenter,win=$p,disable=d2; return 0; End

Function LJZ_GSA2_ButtonProc(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if (ba.eventCode != 2)
        return 0
    endif
    String base=LJZ_GSA2_BaseDF(),p=LJZ_GSA2_PanelName(),gn
    if(CmpStr(ba.ctrlName,"btLock")==0)
        gn=WinName(0,1); if(strlen(gn)==0); DoAlert 0,"No graph on top."; return 0; endif
        SVAR lockedGraph=$(base+":lockedGraph")
        if(cmpstr(lockedGraph,gn)==0); lockedGraph=""; TitleBox tbLockedName,win=$p,title="(unlocked)"; Button btLock,win=$p,title="Lock Graph"; else; lockedGraph=gn; TitleBox tbLockedName,win=$p,title=gn; Button btLock,win=$p,title="Unlock"; endif
        return 0
    endif
    if(CmpStr(ba.ctrlName,"btUndo")==0); LJZ_GSA2_Undo(); return 0; endif
    if(CmpStr(ba.ctrlName,"btLine")==0); LJZ_GSA2_AddLine(); return 0; endif
    if(CmpStr(ba.ctrlName,"btRect")==0); LJZ_GSA2_AddRectangleByBox(); return 0; endif
    if(CmpStr(ba.ctrlName,"btEllipseBox")==0); LJZ_GSA2_AddEllipseByBox(); return 0; endif
    if(CmpStr(ba.ctrlName,"btEllipseCenter")==0); LJZ_GSA2_AddEllipseByCenter(); return 0; endif
    if(CmpStr(ba.ctrlName,"btCircleCenter")==0); LJZ_GSA2_AddCircleByCenter(); return 0; endif
    if(CmpStr(ba.ctrlName,"btTri3P")==0); LJZ_GSA2_AddTriangleBy3Points(); return 0; endif
    if(CmpStr(ba.ctrlName,"btTriBox")==0); LJZ_GSA2_AddTriangleByBox(); return 0; endif
    if(CmpStr(ba.ctrlName,"btTriCenter")==0); LJZ_GSA2_AddTriangleByCenter(); return 0; endif
    if(CmpStr(ba.ctrlName,"btRed")==0); LJZ_GSA2_RedPreset(); return 0; endif
    if(CmpStr(ba.ctrlName,"btBlue")==0); LJZ_GSA2_BluePreset(); return 0; endif
    if(CmpStr(ba.ctrlName,"btYellow")==0); LJZ_GSA2_YellowPreset(); return 0; endif
    if(CmpStr(ba.ctrlName,"btWhite")==0); LJZ_GSA2_WhitePreset(); return 0; endif
    if(CmpStr(ba.ctrlName,"btBlack")==0); LJZ_GSA2_BlackPreset(); return 0; endif
    if(CmpStr(ba.ctrlName,"btClear")==0); LJZ_GSA2_ClearTopGraphDrawings(); NVAR undoCount=$(base+":undoCount"); SVAR undoNames=$(base+":undoNames"); undoCount=0; undoNames=""; return 0; endif
    if(CmpStr(ba.ctrlName,"btClose")==0); DoWindow/K $p; return 0; endif
    return 0
End

// 辅助设置函数（保留 v2 接口）
Function LJZ_GSA2_SetCoords(newX1, newY1, newX2, newY2)
    Variable newX1,newY1,newX2,newY2
    NVAR x1=$(LJZ_GSA2_BaseDF()+":x1");NVAR y1=$(LJZ_GSA2_BaseDF()+":y1");NVAR x2=$(LJZ_GSA2_BaseDF()+":x2");NVAR y2=$(LJZ_GSA2_BaseDF()+":y2")
    x1=newX1; y1=newY1; x2=newX2; y2=newY2
    return 0
End
Function LJZ_GSA2_SetCenter(newCX, newCY)
    Variable newCX,newCY
    NVAR cx=$(LJZ_GSA2_BaseDF()+":cx");NVAR cy=$(LJZ_GSA2_BaseDF()+":cy")
    cx=newCX; cy=newCY
    return 0
End
Function LJZ_GSA2_SetRadii(newRX, newRY)
    Variable newRX,newRY
    NVAR rx=$(LJZ_GSA2_BaseDF()+":rx");NVAR ry=$(LJZ_GSA2_BaseDF()+":ry")
    rx=newRX; ry=newRY
    return 0
End
Function LJZ_GSA2_SetTriangle3P(newTX1, newTY1, newTX2, newTY2, newTX3, newTY3)
    Variable newTX1,newTY1,newTX2,newTY2,newTX3,newTY3
    NVAR tx1=$(LJZ_GSA2_BaseDF()+":tx1");NVAR ty1=$(LJZ_GSA2_BaseDF()+":ty1");NVAR tx2=$(LJZ_GSA2_BaseDF()+":tx2");NVAR ty2=$(LJZ_GSA2_BaseDF()+":ty2");NVAR tx3=$(LJZ_GSA2_BaseDF()+":tx3");NVAR ty3=$(LJZ_GSA2_BaseDF()+":ty3")
    tx1=newTX1; ty1=newTY1; tx2=newTX2; ty2=newTY2; tx3=newTX3; ty3=newTY3
    return 0
End
