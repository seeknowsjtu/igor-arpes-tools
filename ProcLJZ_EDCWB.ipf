#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  ProcLJZ_EDCWB.ipf
//
//  这是 EDCWB 的唯一正式入口文件。
//  这里仅允许：
//    1) 基础 pragma
//    2) 架构说明注释
//    3) 模块文件 #include
//    4) 唯一正式菜单入口
//
//  严禁在本文件内重新加入任何业务实现，包括但不限于：
//    - LJZ_EDCWB_* 函数体
//    - Window / callback / panel 实现
//    - model 实现
//    - preprocess / guess / fit 实现
//
//  EDCWB 模块装配顺序固定如下，后续不得随意改回 monolithic 混装：
//    1) ProcLJZ_EDCWB_Core
//    2) ProcLJZ_EDCWB_Model
//    3) ProcLJZ_EDCWB_PreprocessGuessFit
//    4) ProcLJZ_EDCWB_Panel
// ============================================================================

#include "ProcLJZ_EDCWB_Core"
#include "ProcLJZ_EDCWB_Model"
#include "ProcLJZ_EDCWB_PreprocessGuessFit"
#include "ProcLJZ_EDCWB_Panel"

Menu "ARPES_LJZ"
    "2026EDCWB_LJZ", LJZ_EDCWB()
End
