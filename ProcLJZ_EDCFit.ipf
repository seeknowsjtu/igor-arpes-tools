#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  ProcLJZ_EDCFit.ipf
//
//  这是未恢复的 legacy stub，不是正式入口。
//  在历史 EDCFit 工作流未恢复之前，禁止将本文件重新挂入任何正式菜单。
//  若未来恢复旧 EDCFit 工作流，只允许恢复 EDCFit_* 旧链路，
//  不得在此文件中重新引入任何 LJZ_EDCWB_* 函数或实现。
// ============================================================================

Function EDCFit_LegacyStub_LJZ()
    DoAlert 0, "Legacy EDCFit workflow is not restored yet. ProcLJZ_EDCFit.ipf is only a stub and must not be exposed as a formal menu entry until the historical EDCFit_* chain is recovered."
    return 0
End
