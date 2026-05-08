# Igor ARPES Tools

一个面向 **ARPES（角分辨光电子能谱）** 数据处理的 Igor Pro 脚本工具仓库。  
本仓库包含一系列可独立加载、可组合使用的 `.ipf` 模块，覆盖从数据浏览、预处理到拟合分析与图形整理的常见研究流程。

---

## 仓库定位

- 这是一个 **研究工作流工具箱**，不是单一可执行程序。
- 模块设计以 Igor 的 **菜单（Menu）+ 面板（Panel）+ 回调函数** 为主。
- 部分功能为稳定主流程，部分文件是历史版本、实验脚本或阶段性工具。

---

## 功能概览

### 1) 数据浏览与可视化
- 多层切片查看（如 6 层联动预览）
- Slice Gallery 快速浏览
- 色表调整与图像渲染控制
- Layout 排版辅助

### 2) 数据处理与变换
- 3D FFT 滤波
- 3D 二阶导数计算
- 多边形 ROI 选区积分与时序追踪
- 角度空间到动量空间（k-space）转换

### 3) 谱线提取与拟合
- MDC 拟合与交互式 Workbench
- EDC 提取与 Workbench 拟合
- EDC 边沿宽度分析
- 与拟合流程配套的预处理与结果展示模块

---

## 目录说明

```text
.
├── LJZprocedure/        # 核心 Igor Pro 过程文件（主要功能模块）
├── CDHprocedure/        # 兼容/历史过程文件
├── docs/                # 附加文档（如错误记录）
├── ONBOARDING.md        # 上手说明（若存在）
└── IgorManual8.pdf      # Igor Pro 参考手册（本地副本）
```

---

## 关键模块（LJZprocedure）

- `ProcLJZ_MainMenu.ipf`：主菜单入口，聚合常用功能。
- `ProcLJZ_FFT3DFilter.ipf`：3D FFT 滤波处理。
- `ProcLJZ_SecondDerivative3D.ipf`：3D 二阶导算法。
- `ProcLJZ_ROIPolygonTrace.ipf`：ROI 选区、积分与分析流程。
- `ProcLJZ_AngleToKTransform.ipf`：角度到 k 空间转换。
- `ProcLJZ_EDCExtract.ipf`：从 3D 数据提取 EDC。
- `ProcLJZ_EDCWB*.ipf`：EDC Workbench 分模块实现。
- `ProcLJZ_EDCEdgeWidth.ipf`：EDC 边沿宽度分析。
- `LJZ_MDCWB_Part*.ipf`：MDC Workbench 核心、拟合引擎与面板。
- `ProcLJZ_ColorTablePanel.ipf`：色表面板与样式应用。
- `ProcLJZ_Show6LayerPanel.ipf` / `ProcLJZ_GallerySlice.ipf`：多层切片与图库浏览。
- `ProcLJZ_LayoutTools.ipf`：图版布局与对象整理工具。

---

## 建议阅读顺序

如果你第一次接触本仓库，建议按下面顺序理解代码结构：

1. 从主菜单入口开始：`ProcLJZ_MainMenu.ipf`。
2. 找到对应面板创建函数（`Panel`/`Window` 相关函数）。
3. 顺着按钮与控件回调进入数据处理或拟合核心函数。
4. 最后再阅读独立算法模块（FFT、二阶导、拟合引擎等）。

这种“从入口到实现”的路径，通常比直接通读单个大文件更高效。

---

## 使用建议

- 建议先在测试数据上跑通完整流程，再迁移到批量数据。
- 不同实验线站/数据格式可能需要做变量命名或数据组织层面的适配。
- 对历史脚本进行改动前，建议先备份或新建分支，避免影响既有分析流程。

---

## 免责声明

本仓库主要服务于科研分析场景，脚本可能随课题需求持续演进。  
如需长期维护，建议在你自己的分支中固定版本并补充实验室内部文档。
