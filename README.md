# 通风网络解算系统 (Ventilation Network Solver Suite)

## 项目简介

本项目是一套完整的**矿井通风网络解算系统**，基于 MATLAB 开发，用于计算复杂通风系统中各巷道的风量分配和风压损失。项目采用经典的 **Hardy Cross 迭代法**（哈迪-克罗斯法），包含通用求解器和专用求解器两个子系统。

**核心特性**：

- 支持任意拓扑结构的通风网络解算
- 自动识别独立回路（基于生成树算法）
- 图形化用户界面（App Designer）
- 数据可视化（网络拓扑图、柱状图）
- CSV 数据导入/导出
- 教学演示友好

---

## 项目结构

### 1. [通用求解器 (General Problem Solver)](./General%20Problem%20Solver/)

**适用场景**：任意规模、任意拓扑的通风网络

**核心功能**：

- 自动识别网络拓扑中的独立回路（生成树法）
- 支持多入风/回风节点边界条件
- 图形化界面（App Designer），操作简便
- 实时求解日志输出（TextArea 组件）
- 可视化功能：
  - 网络拓扑图（无向图）
  - 求解结果柱状图（风量 + 风压降）
- CSV 数据管理（导入/导出/添加/删除）

**技术亮点**：

- 独立回路自动识别算法（$`M = B - N + 1`$）
- 初始可行流生成（最小范数解）
- 松弛因子控制（防止振荡）
- 双重收敛判据（回路残差 + 风量变化）

📖 **[查看详细文档 →](./General%20Problem%20Solver/README.md)**

---

### 2. [专用求解器 - 图5.2网络 (Solver for fig5.2)](./Solver%20for%20fig5.2/)

**适用场景**：固定 8 分支对角巷道角联网路（教材图 5.2）

**核心功能**：

- 硬编码回路矩阵（无需自动识别，效率更高）
- 快速求解（< 0.01 秒）
- 批量计算支持（参数扫描）
- 结果可视化（双子图柱状图）
- CSV 输入/输出

**技术亮点**：

- 智能初始化策略（基于风阻比例）
- 平滑绝对值处理（避免除零）
- 欠松弛控制（$`\omega = 0.85`$）
- 执行效率是通用求解器的 6 倍以上

**适用对象**：

- 需要交作业的各位同学

📖 **[查看详细文档 →](./Solver%20for%20fig5.2/README.md)**

---

## 快速开始

### 选择合适的求解器

| 需求 | 推荐求解器 | 原因 |
|------|----------|------|
| 任意通风网络 | 通用求解器 | 自动识别拓扑，无需手工编写回路矩阵 |
| 图 5.2 网络（8 分支） | 专用求解器 | 执行效率高，代码简洁，适合教学 |
| 可视化要求高 | 通用求解器 | 支持网络拓扑图和结果柱状图 |
| 批量计算（参数扫描） | 专用求解器 | 单次求解 < 0.01 秒，适合循环调用 |
| 学习通风网络理论 | 通用求解器 | 算法完整，注释详细，易于理解 |

---

### 通用求解器使用流程

```matlab
% 1. 启动图形界面
cd 'D:\MATLAB\wangluojiesuan\General Problem Solver'
NetworkSolverApp

% 2. 导入 CSV 数据或手动添加分支
% 3. 设置边界条件（入风节点、回风节点、总风量）
% 4. 点击"求解"按钮
% 5. 查看结果（文本日志 + 可视化图表）
```

**或通过命令行调用**：

```matlab
% 加载网络数据
Branches.id = (1:8)';
Branches.from_node = [1; 1; 3; 2; 3; 5; 4; 5];
Branches.to_node   = [2; 3; 2; 4; 5; 4; 6; 6];
Branches.R = [0.05; 0.08; 0.03; 0.06; 0.07; 0.04; 0.05; 0.06];

% 设置边界条件
Boundary.inlet_node = 1;
Boundary.outlet_node = 6;
Boundary.Q_total = 100;

% 求解
SolverOptions.verbose = true;
[Q, Results] = gps.logic.ventilation_network_solver_generic(...
    Branches, Boundary, SolverOptions);
```

---

### 专用求解器使用流程

```matlab
% 1. 编辑输入数据
cd 'D:\MATLAB\wangluojiesuan\Solver for fig5.2'
% 修改 network_data.csv 中的风阻系数

% 2. 运行主脚本
main_script

% 3. 查看输出
% - ventilation_results.csv（数据表格）
% - ventilation_network_results.png（柱状图）
```

**或直接调用求解函数**：

```matlab
R = [0.05 0.08 0.03 0.06 0.07 0.04 0.05 0.06];
[Q, iterations] = ventilation_network_solver(R, 100);
```

---

## 数学物理基础

### 1. Atkinson 阻力定律

矿井巷道中，风流阻力与风量的平方成正比：

$$
\Delta p = R \cdot |Q| \cdot Q
$$

其中：

- $\Delta p$：风压损失（Pa）
- $R$：通风阻力系数（N·s²/m⁸）
- $Q$：风量（m³/s）

---

### 2. 基尔霍夫定律

#### 节点流量平衡（第一定律）

$$
\mathbf{A} \cdot \mathbf{Q} = \mathbf{b}
$$

其中 $\mathbf{A}$ 为节点-分支关联矩阵，$\mathbf{b}$ 为节点注入风量。

#### 回路压力平衡（第二定律）

$$
\mathbf{S} \cdot \Delta \mathbf{p} = \mathbf{0}
$$

其中 $\mathbf{S}$ 为回路矩阵，$\Delta \mathbf{p}$ 为各分支风压降。

---

### 3. Hardy Cross 迭代法

核心思想：逐回路修正风量，直至所有回路压力平衡。

**修正公式**：

$$
\Delta Q_k = -\frac{\sum_{i} s_{ki} \cdot R_i \cdot |Q_i| \cdot Q_i}{\sum_{i} 2 R_i \cdot |Q_i|}
$$

**更新公式**：

$$
Q_i^{(\text{new})} = Q_i^{(\text{old})} + \omega \sum_{k} s_{ki} \cdot \Delta Q_k
$$

其中 $\omega$ 为松弛因子（$0 < \omega \leq 2$）。

---

## 系统要求

### 软件环境

- **MATLAB 版本**：
  - 通用求解器：R2019b 或更高版本
  - 专用求解器：R2016b 或更高版本
- **必需工具箱**：
  - Statistics and Machine Learning Toolbox（通用求解器，用于 `graph` 函数）
  - 无额外工具箱要求（专用求解器）
- **操作系统**：Windows / macOS / Linux

### 硬件要求

- **内存**：4 GB 以上（推荐 8 GB）
- **存储空间**：50 MB（含测试数据）
- **处理器**：现代多核 CPU（Intel i5 或同等性能）

---

## 算法性能对比

| 指标 | 通用求解器 | 专用求解器（图5.2） |
|------|----------|------------------|
| 适用网络 | 任意拓扑 | 仅8分支固定网络 |
| 回路识别 | 自动（$O(B \log N)$） | 无需（硬编码） |
| 单次求解时间 | ~0.02 秒 | ~0.003 秒 |
| 内存占用 | 中等（动态矩阵） | 极小（固定数组） |
| 代码可读性 | 中（复杂） | 高（直观） |
| 扩展性 | 高（通用） | 低（固定） |
| 图形界面 | 有（App Designer） | 无（脚本） |

**结论**：

- 通用场景 → 使用通用求解器
- 图 5.2 网络 + 批量计算 → 使用专用求解器

---

## 测试案例

### 案例 1：简单三回路网络（10节点11分支）

```text
位置：General Problem Solver/test_case_10x11/branches.csv
节点数：10
分支数：11
独立回路数：2
预期迭代次数：10~20
```

### 案例 2：图 5.2 对角巷道角联网路（6节点8分支）

```text
位置：Solver for fig5.2/network_data.csv
节点数：6
分支数：8
独立回路数：3
预期迭代次数：10~15
```

---

## 常见问题

### Q1：求解未收敛怎么办？

**原因**：网络拓扑复杂，初始猜测离真解太远，或风阻系数差异过大。

**解决方案**：

1. 增加最大迭代数（例如 2000~5000）
2. 减小松弛因子（例如 0.5~0.8）
3. 检查数据有效性（风阻必须 >0）

---

### Q2：如何验证结果正确性？

**方法 1**：检查节点流量守恒

```matlab
node_residual = A * Q - b;
max(abs(node_residual))  % 应 < 1e-6
```

**方法 2**：检查回路压力平衡

```matlab
loop_residual = LoopMatrix * (R .* Q .* abs(Q));
max(abs(loop_residual))  % 应 < 0.1 Pa
```

---

### Q3：可以处理风机吗？

**当前版本**：仅支持自然通风网络（无风机）。

**未来扩展**：可在回路平衡方程中加入风机风压项 $H_f(Q)$。

---

### Q4：两个求解器结果一致吗？

**一致性测试**：

```matlab
% 使用两个求解器求解相同网络
[Q_generic, ~] = gps.logic.ventilation_network_solver_generic(...);
[Q_specific, ~] = ventilation_network_solver(R, Q_total);

% 比较结果
max(abs(Q_generic - Q_specific'))  % 应 < 1e-6
```

---

## 开发路线图

### 已完成 ✅

- [x] Hardy Cross 通用求解器
- [x] 独立回路自动识别（生成树法）
- [x] App Designer 图形界面
- [x] 网络拓扑可视化
- [x] 结果柱状图可视化
- [x] CSV 数据管理
- [x] 专用求解器（图5.2网络）
- [x] 详细技术文档

#### *下面的当没有就可以了，作者懒得搞了*😵

### 开发中 🚧

- [ ] 牛顿-拉夫逊法（Newton-Raphson）
- [ ] 节点压力法（Node Pressure Method）

### 计划中 📋

- [ ] 风机特性曲线支持
- [ ] 多风机协同调节
- [ ] 不确定性分析（蒙特卡洛模拟）
- [ ] 并行计算加速（MATLAB Parallel Computing Toolbox）
- [ ] 三维可视化（网络空间布局）

---

## 贡献指南

欢迎贡献代码、报告问题或提出改进建议！

### 如何贡献

1. **Fork 本仓库**到您的 GitHub 账户
2. **创建特性分支**：`git checkout -b feature/your-feature-name`
3. **提交更改**：`git commit -m "Add: your feature description"`
4. **推送到分支**：`git push origin feature/your-feature-name`
5. **创建 Pull Request**

### 代码规范

- 遵循 MATLAB 编码风格指南
- 所有函数必须包含完整的中文注释
- 提交前运行测试案例确保无回归
- 新增功能需更新对应的 README 文档

---

## 作者

### 东北大学 资源与土木工程学院 智采2201班 学生

---

## 许可证

本项目基于 **GNU General Public License v3.0 (GPL-3.0)** 开源。

**主要条款**：

- ✅ 允许自由使用、修改和分发本软件
- ✅ 修改后的代码必须以相同的 GPL-3.0 许可证发布（Copyleft）
- ✅ 必须公开修改后的源代码
- ⚠️ 不提供任何担保

详见项目根目录下的 [`LICENSE`](./LICENSE) 文件，或访问 <https://www.gnu.org/licenses/gpl-3.0.html>。

---

## 参考文献

1. Cross, H. (1936). "Analysis of Flow in Networks of Conduits or Conductors". *University of Illinois Bulletin*, 34(22), 286-289.
2. Atkinson, J. J. (1862). "On the Theory of the Ventilation of Mines". *Transactions of the North of England Institute of Mining and Mechanical Engineers*, 11, 118-140.
3. Scott, J. A., & Hinsley, F. B. (1953). "Ventilation network analysis by digital computer". *Colliery Guardian*, 187, 555-559.
4. 王德明, 魏连江. (2007). 《矿井通风与空气调节》（第二版）. 中国矿业大学出版社, 第 5 章.
5. MATLAB Documentation: [Graph and Network Algorithms](https://www.mathworks.com/help/matlab/graph-and-network-algorithms.html)

---

## 联系方式

如有问题或建议，请通过以下方式联系：

- 📧 **邮箱**：`leebert417@gmail.com`
- 🌐 **项目仓库**：[GitHub仓库](https://github.com/leebert417-ops/wangluojiesuan) 或 [GitLab仓库](https://gitlab.com/leebert417-group/wangluojiesuan.git)
- 🐛 **问题反馈**：[GitHub Issues](https://github.com/leebert417-ops/wangluojiesuan/issues)

---

**版本**：v1.0 (2025-12-18)

**更新日志**：

- 2025-12-18：首次发布，包含通用求解器和专用求解器（图5.2）
