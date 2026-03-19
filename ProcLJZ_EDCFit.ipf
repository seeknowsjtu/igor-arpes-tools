#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// ============================================================================
//  ProcLJZ_EDCFit.ipf
//  Legacy-compatible stub for the non-workbench EDCFit entry point.
//
//  The old monolithic ProcLJZ_EDCWB.ipf is intentionally retired to avoid
//  namespace collisions with the modular LJZ_EDCWB_* workbench files.
//  If the historical EDCFit_LJZ body is recovered later, it should live here
//  and must not reintroduce LJZ_EDCWB_* definitions.
// ============================================================================

Menu "ARPES_LJZ"
    "Legacy EDCFit_LJZ", EDCFit_LJZ()
End

Function EDCFit_LJZ()
    DoAlert 0, "Legacy EDCFit_LJZ() has been separated from EDCWB. Please restore its historical implementation in ProcLJZ_EDCFit.ipf if you need the old standalone workflow."
    return 0
End
