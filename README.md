# igor-arpes-tools

这是一个面向 **ARPES 数据处理与分析** 的 Igor Pro 脚本工具箱仓库。

仓库里的内容不是单一程序，而是一组可以按需加载、相互配合使用的 `.ipf` 模块，整体偏研究工作流工具，主要围绕数据浏览、预处理、拟合、结果展示和版面整理展开。

## 主要功能

- **数据浏览与展示**
  - 多层切片查看（如 6 层预览）
  - Slice Gallery 浏览
  - 自定义色表与图像配色
  - Layout 排版辅助

- **数据处理**
  - 3D FFT 滤波
  - 3D 二阶导处理
  - 多边形 ROI 积分与时序追踪
  - 角度到 `k` 空间的转换

- **拟合与谱线分析**
  - MDC 拟合与交互式 Workbench
  - EDC 提取
  - EDC Workbench 拟合
  - EDC 边沿宽度分析

- **辅助与历史脚本**
  - 一些通用 wave 工具函数
  - 部分实验性、测试性或历史兼容模块

## 仓库特点

- 以 **面板（Panel）+ 菜单（Menu）+ 回调函数** 的方式组织。
- 新旧流程并存，部分模块已经拆分成更清晰的 Workbench 结构。
- 更适合看作一个持续演化中的 **ARPES 研究工具箱**，而不是一个完整封装的软件产品。

## 主要模块一览

- `ProcLJZ_MainMenu.ipf`：较早期的主菜单入口，包含 FFT、MDC 拟合、ROI、色表和多层显示入口。
- `ProcLJZ_FFT3DFilter.ipf`：3D FFT 滤波。
- `ProcLJZ_SecondDerivative3D.ipf`：3D 二阶导计算。
- `ProcLJZ_ROIPolygonTrace.ipf`：多边形 ROI 积分、背景处理与 FFT 分析。
- `ProcLJZ_AngleToKTransform.ipf`：角度到动量空间转换及相关绘图。
- `ProcLJZ_EDCExtract.ipf`：从 3D 数据中提取 EDC。
- `ProcLJZ_EDCWB*.ipf`：模块化 EDC Workbench。
- `ProcLJZ_EDCEdgeWidth.ipf`：EDC 边沿宽度测量。
- `ProcLJZ_MDCInteractiveFitWorkbench.ipf` / `ProcLJZ_MDCWB.ipf`：MDC 拟合工作台。
- `ProcLJZ_ColorTablePanel.ipf`：色表编辑与应用。
- `ProcLJZ_Show6LayerPanel.ipf` / `ProcLJZ_GallerySlice.ipf`：切片浏览与展示。
- `ProcLJZ_LayoutTools.ipf`：Layout 排版与对象整理。

## 适合如何理解这个仓库

如果你第一次接触这个仓库，建议优先从菜单入口和面板型模块开始看：

1. 先看 `Menu "ARPES_LJZ"` 里有哪些入口。
2. 再看对应的 `Proc` / `Function` 如何打开面板。
3. 最后顺着按钮、列表框、弹窗回调进入具体算法。

这样会比从头到尾顺读单个大文件更容易理解。
