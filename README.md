# igor-arpes-tools

A modular collection of Igor Pro procedure (`.ipf`) scripts for ARPES data processing, visualization, fitting, FFT filtering, ROI workflows, and MDC workbench development.

## Overview

This repository is not a single compiled software project. Instead, it contains a set of reusable and partially independent Igor Pro modules built around ARPES analysis workflows.

The codebase includes:

- menu-driven entry points and panel-based tools
- visualization and color-table utilities
- FFT filtering and differentiation workflows
- ROI-based trajectory integration tools
- MDC fitting and workbench-style fitting modules
- layout and slice-gallery utilities
- angle-to-k related analysis tools

## Main modules

- `ProcLJZ_POPmenu.ipf`  
  Early main entry point with menu-based access to multiple tools such as MDC, FFT, and ROI workflows.

- `ProcLJZ_2025*.ipf`  
  2025-generation modules, including CT panel tools, differentiation, FFT filtering, and ROIVARY-related functionality.

- `ProcLJZ_2026*.ipf`  
  2026-generation modules, including angle-to-k workflows, interactive fitting tools, and more robust double-peak fitting development.

- `ProcLJZ_GallerySlice.ipf`  
  Slice gallery and preview workflow utilities.

- `ProcLJZ_LayoutTools.ipf`  
  Layout and panel organization tools.

- `ProcLJZ_MDCWB.ipf`  
  MDC Workbench with a more structured engineering-style state-management approach.

- `ProcLJZ_EDCWB.ipf` + `ProcLJZ_EDCWB_Part2.ipf`  
  EDC Workbench is split into two procedure files: Part 1 (core/runtime state + result-record IO) and Part 2 (model bank, fit engine, panel callbacks, and summary export) to keep each file easier to maintain.

- `ProcLJZ_2025.ipf`  
  A broader collection of earlier utility and display-related functions.

## How to read this repository

A practical way to understand the codebase is to follow this order:

### 1. Entry layer
Start from:

- `Menu "ARPES_LJZ"`
- corresponding `Proc ..._LJZ()` functions

These act as the functional entry points of the toolbox.

### 2. State layer
Many modules use helper functions such as `*_ensure_folder()` to initialize runtime state under paths like:

- `root:ARPES_LJZ:*`
- `root:Packages:ARPES_LJZ:*`

Typical workflow:

1. create or ensure a state folder
2. initialize defaults if needed
3. rebuild or rescan runtime lists
4. open or refresh a panel

### 3. Core algorithm layer
Typical analysis capabilities include:

- 3D FFT filtering
- second-derivative processing (optionally with Savitzky-Golay support)
- ROI trajectory integration
- MDC single-peak and double-peak fitting
- angle-to-k conversion workflows

### 4. UI layer
A large portion of the logic is panel-driven, using Igor callbacks such as:

- `ButtonControl`
- `PopupMenuControl`
- `ListBoxControl`
- `SetVariableControl`

For reading the code, it is often more effective to jump from a UI control definition to its callback function rather than reading the entire file from top to bottom.

## Important conventions

### DataFolder paths
The repository heavily relies on `root:...:` style string paths.  
Helper functions are often used to normalize paths and ensure trailing colons are handled consistently.

### Waves as both data and state
Waves are used not only for numerical data, but also for UI state and list management, often with:

- `Wave/T` for display text
- path waves for real references
- selection waves for listbox state

### Old and new workflows may coexist
Some functionalities exist in both older and newer forms.  
For example, legacy menu-based fitting and newer workbench-style fitting may both be present. When maintaining code, it is important to determine which path is currently the primary one.

## Suggested onboarding path

### Days 1–2
Build a map of the repository:

- locate `Menu "ARPES_LJZ"`
- track each corresponding `Proc`
- sketch a flow such as  
  `Menu -> Proc -> Panel -> Callback -> Algorithm`

### Days 3–5
Start with a lightweight module, for example:

- `ProcLJZ_2025CT.ipf`

This module is relatively simple and is a good entry point for understanding the coding style.

### Days 6–9
Read a medium-complexity module, such as:

- `ProcLJZ_2025Differentiate.ipf`
- `ProcLJZ_2025FFTfilter.ipf`

These help illustrate input scanning, parameter panels, and output wave generation.

### Days 10–14
Move on to more complex fitting-related modules:

- `ProcLJZ_2026fit.ipf`
- `ProcLJZ_MDCWB.ipf`
- `ProcLJZ_2026doublefit.ipf`

Focus separately on:

- runtime state management
- fitting engine logic
- parameter constraints
- fallback and robustness strategies

## Common pitfalls

- forgetting to restore the original DataFolder after module-local operations
- missing trailing `:` in folder path strings
- confusing display-name text waves with real-path reference waves
- changing fitting defaults without regression testing

## Recommended development workflow

- test the panel workflow first before modifying the algorithm
- add logging before changing core computation
- make small commits so rollback stays easy
- preserve compatibility when introducing a newer version of an existing workflow

## Notes

This repository reflects an evolving research workflow, so historical and newer implementations may coexist. The structure is therefore best understood as a practical toolbox rather than a strictly unified software package.
