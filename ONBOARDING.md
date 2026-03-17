# igor-arpes-tools 新人上手指南

## 1. 代码库整体结构

本仓库是 **Igor Pro Procedure (`.ipf`) 脚本集合**，围绕 ARPES 数据处理构建。整体上不是“一个可编译工程”，而是多个可独立加载/组合使用的功能模块。

- `ProcLJZ_POPmenu.ipf`：早期主入口，包含菜单与 MDC/FFT/ROI 等功能。
- `ProcLJZ_2025*.ipf`：2025 年新增或重构模块（CT 面板、二阶导、FFT、ROIVARY 等）。
- `ProcLJZ_2026*.ipf`：2026 年方向模块（Angle→k、交互式拟合、双峰鲁棒拟合等）。
- `ProcLJZ_GallerySlice.ipf`：切片图库与预览工作流。
- `ProcLJZ_LayoutTools.ipf`：布局管理面板。
- `ProcLJZ_MDCWB.ipf`：MDC Workbench（更工程化的数据结构与状态管理）。
- `ProcLJZ_2025.ipf`：早期通用函数集合（含显示/辅助函数）。

## 2. 模块分层理解（建议顺序）

### A. 入口层（Menu/Proc）
先找到用户实际点击的入口：

- `Menu "ARPES_LJZ"` 定义菜单项。
- 对应 `Proc ..._LJZ()` 作为启动入口。

你可以把它理解为“路由层”：先看菜单，再追踪对应 Proc。

### B. 状态层（DataFolder 约定）
几乎每个模块都有 `*_ensure_folder()`，会在 `root:ARPES_LJZ:*` 或 `root:Packages:ARPES_LJZ:*` 下建运行时状态。

常见模式：

1. `ensure_folder` 建状态目录；
2. `init_defaults_if_needed` 初始化全局变量/Wave；
3. `rebuild_*` 重新扫描并刷新列表；
4. 打开或刷新 Panel。

### C. 计算层（核心算法）
常见能力包含：

- 3D FFT 去噪；
- 3D 数据二阶导（可选 SG）；
- ROI 轨迹积分；
- MDC 单峰/双峰拟合与结果记录；
- 角度到 k 空间变换。

### D. UI 层（Panel + 回调）
大量逻辑通过 Igor 面板控件回调实现（`ButtonControl` / `PopupMenuControl` / `ListBoxControl` / `SetVariableControl`）。

阅读时建议“从控件定义跳到回调函数”，而不是直接自顶向下通读整个文件。

## 3. 你必须先掌握的关键约定

1. **DataFolder 路径规范**
   - 代码中大量用 `root:...:` 字符串拼接路径。
   - 常配套 `*_df_with_colon()` 做路径规范化，避免尾冒号错误。

2. **Wave 作为状态与数据容器**
   - 不仅数据是 Wave，UI 列表状态也常放在 `Wave/T`、`Wave/U/B` 里。
   - 列表通常成对：`LB_Disp`（展示）+ `LB_Path`（真实路径）+ `LB_Sel`（选择状态）。

3. **模块之间有显式依赖**
   - 例如 SHOW6LAYER/SliceGallery 会依赖 CT 颜色库刷新。
   - 双峰拟合模块依赖 MDC 拟合基础函数。

4. **同类功能可能有“旧版 + 新版”并存**
   - 例如 `ProcLJZ_POPmenu.ipf` 的 MDCFit 与 `ProcLJZ_2026fit.ipf`/`ProcLJZ_MDCWB.ipf` 的工作台思路并存。
   - 维护时建议先确定“当前主用入口”，避免在旧路径修 bug 却被新路径绕开。

## 4. 实操学习路线（两周建议）

### 第 1-2 天：建立地图
- 逐个查找 `Menu "ARPES_LJZ"` 与对应 `Proc`。
- 画一张“菜单 -> Proc -> Panel -> 回调 -> 算法函数”的简单流程图。

### 第 3-5 天：精读一个轻量模块
建议从 `ProcLJZ_2025CT.ipf`（CT 面板）开始：
- 状态简单；
- UI-算法链路短；
- 能快速熟悉本仓库风格。

### 第 6-9 天：读一个典型中等复杂模块
推荐 `ProcLJZ_2025Differentiate.ipf` 或 `ProcLJZ_2025FFTfilter.ipf`：
- 有输入扫描；
- 有参数面板；
- 有输出目录与结果波形。

### 第 10-14 天：进入复杂模块
阅读 `ProcLJZ_2026fit.ipf` / `ProcLJZ_MDCWB.ipf` / `ProcLJZ_2026doublefit.ipf`：
- 关注结构体定义、拟合参数约束、失败回退策略；
- 把“状态管理”和“拟合引擎”分开理解。

## 5. 新人常见坑

- 把 DataFolder 留在模块内部目录没切回，导致后续函数找错波形。
- 路径末尾缺 `:` 导致 `$dfStr` 解析失败。
- 忽略 `Wave/T` 与数值 Wave 混用（展示名和真实路径分离）。
- 直接改复杂拟合参数默认值而不做回归验证。

## 6. 推荐工作方式

- **先做可视化调试**：在面板里走完整流程，再改代码。
- **先加日志再改算法**：先确认输入波形维度、路径、索引范围是否正确。
- **小步提交**：每次改动只覆盖一个模块，便于回滚。
- **保留兼容入口**：若新增版本，建议保持老入口可用，逐步迁移。
