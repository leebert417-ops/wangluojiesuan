# 通用通风网络求解器 (General Problem Solver)

## 简介

本项目是一款基于 MATLAB App Designer 开发的**通用通风网络求解器**，用于计算复杂矿井通风系统中各巷道的风量分配和风压损失。项目采用经典的 **Hardy Cross 迭代法**（哈迪-克罗斯法），能够自动识别网络拓扑结构中的独立回路，适用于任意规模、任意拓扑的通风网络。

**核心功能**：
- 支持任意节点数、分支数的通风网络
- 自动识别独立回路（基于生成树法）
- 多入风/回风节点边界条件
- 可视化网络拓扑图和求解结果
- CSV 数据导入/导出
- 详细的求解过程日志输出

---

## 数学物理原理

### 1. 通风阻力定律（Atkinson 定律）

矿井通风巷道中，空气流动的摩擦阻力与风量的平方成正比，满足 **Atkinson 阻力定律**：

$$
\Delta p = R \cdot Q^2
$$

其中：
- $\Delta p$：风压损失（Pa）
- $R$：通风阻力系数（N·s²/m⁸）
- $Q$：风量（m³/s）

在考虑风流方向的计算中，通常写为：

$$
\Delta p = R \cdot |Q| \cdot Q
$$

这样可以保证风压降的符号与风流方向一致（顺流为正，逆流为负）。

---

### 2. 基尔霍夫定律

通风网络求解的理论基础是类比电路的 **基尔霍夫定律**：

#### 2.1 节点流量平衡（基尔霍夫第一定律）

对于网络中的任意节点 $i$，流入该节点的风量总和等于流出的风量总和：

$$
\sum_{j \in \text{in}(i)} Q_j = \sum_{k \in \text{out}(i)} Q_k
$$

用关联矩阵 $\mathbf{A}$ 表示为：

$$
\mathbf{A} \cdot \mathbf{Q} = \mathbf{b}
$$

其中：
- $\mathbf{A} \in \mathbb{R}^{N \times B}$：节点-分支关联矩阵（$N$ 为节点数，$B$ 为分支数）
  - $A_{ij} = +1$：分支 $j$ 从节点 $i$ 流出
  - $A_{ij} = -1$：分支 $j$ 流入节点 $i$
  - $A_{ij} = 0$：分支 $j$ 与节点 $i$ 无关
- $\mathbf{Q} \in \mathbb{R}^B$：各分支风量向量
- $\mathbf{b} \in \mathbb{R}^N$：节点注入风量（入风节点为正，回风节点为负）

#### 2.2 回路压力平衡（基尔霍夫第二定律）

对于网络中的任意闭合回路 $k$，沿回路绕行一周，风压降的代数和为零：

$$
\sum_{i \in \text{loop}_k} s_{ki} \cdot \Delta p_i = 0
$$

其中：
- $s_{ki}$：分支 $i$ 在回路 $k$ 中的方向符号
  - $s_{ki} = +1$：分支方向与回路遍历方向一致
  - $s_{ki} = -1$：分支方向与回路遍历方向相反
  - $s_{ki} = 0$：分支不在该回路中

用回路矩阵 $\mathbf{S}$ 表示为：

$$
\mathbf{S} \cdot \Delta \mathbf{p} = \mathbf{0}
$$

其中：
- $\mathbf{S} \in \mathbb{R}^{M \times B}$：回路矩阵（$M$ 为独立回路数，$M = B - N + 1$）
- $\Delta \mathbf{p} \in \mathbb{R}^B$：各分支风压降向量

---

### 3. Hardy Cross 迭代法

Hardy Cross 法是一种经典的**逐回路迭代校正**方法，通过不断修正各回路的风量偏差，使得回路压力平衡方程逐步收敛。

#### 算法步骤：

**步骤 1**：假设初始风量分布 $\mathbf{Q}^{(0)}$，满足节点流量守恒（$\mathbf{A} \cdot \mathbf{Q}^{(0)} = \mathbf{b}$）

**步骤 2**：对每个独立回路 $k$，计算回路风压不平衡量（残差）：

$$
\varepsilon_k = \sum_{i=1}^B s_{ki} \cdot \Delta p_i = \sum_{i=1}^B s_{ki} \cdot R_i \cdot |Q_i| \cdot Q_i
$$

**步骤 3**：根据残差计算回路风量修正量 $\Delta Q_k$：

$$
\Delta Q_k = -\frac{\varepsilon_k}{\sum_{i=1}^B 2 R_i \cdot |Q_i|}
$$

其中分母为回路风压对风量的导数总和（线性化近似）。

**步骤 4**：更新各分支风量（引入松弛因子 $\omega$ 防止振荡）：

$$
Q_i^{(\text{new})} = Q_i^{(\text{old})} + \omega \sum_{k=1}^M s_{ki} \cdot \Delta Q_k
$$

**步骤 5**：重复步骤 2-4，直至所有回路残差 $|\varepsilon_k|$ 小于收敛容差 $\epsilon$。

#### 收敛条件：

$$
\max_k |\varepsilon_k| < \epsilon \quad \text{且} \quad \max_i |Q_i^{(\text{new})} - Q_i^{(\text{old})}| < \epsilon
$$

---

## 算法实现

### 1. 独立回路自动识别（生成树法）

**原理**：对于连通网络图 $G(V, E)$，独立回路数为：

$$
M = B - N + 1
$$

其中 $B$ 为分支数（边数），$N$ 为节点数（顶点数）。

**算法流程**（`identify_fundamental_loops.m`）：

1. **构建无向图**：使用 MATLAB `graph` 对象表示网络拓扑
2. **生成树构建**：通过深度优先搜索（DFS）生成一棵生成树 $T$，包含 $N-1$ 条边
3. **识别非树边（弦）**：剩余 $M$ 条边为非树边（chord），每条非树边与生成树形成一个基本回路
4. **回路路径提取**：对于每条非树边 $(u, v)$，在生成树中找到 $v \to u$ 的唯一路径，加上非树边 $u \to v$ 形成闭合回路
5. **方向符号标记**：根据回路遍历方向与分支定义方向的关系，确定回路矩阵 $\mathbf{S}$ 中的 $+1/-1$ 符号

**输出**：
- `LoopMatrix` ($M \times B$)：回路矩阵，元素为 $\{-1, 0, +1\}$
- `LoopInfo`：回路详细信息（包含的分支、方向符号、对应的非树边）

---

### 2. Hardy Cross 迭代求解

**核心函数**：`ventilation_network_solver_generic.m`

**流程**：

1. **数据验证**：检查分支数据、边界条件、网络连通性
2. **构造关联矩阵** $\mathbf{A}$：根据分支的起点/终点节点构建
3. **生成初始可行流** $\mathbf{Q}^{(0)}$：求解 $\mathbf{A} \cdot \mathbf{Q} = \mathbf{b}$ 的最小范数解
4. **自动识别独立回路**：调用 `identify_fundamental_loops` 获取回路矩阵 $\mathbf{S}$
5. **Hardy Cross 迭代**：
   - 逐回路计算残差 $\varepsilon_k$
   - 计算修正量 $\Delta Q_k$
   - 更新风量 $\mathbf{Q}^{(\text{new})} = \mathbf{Q}^{(\text{old})} + \omega \mathbf{S}^\top \Delta \mathbf{Q}$
   - 检查收敛条件（回路残差 + 风量变化）
6. **输出结果**：风量分布、风压降、收敛信息、节点残差

**关键参数**：
- `max_iter`：最大迭代次数（默认 1000）
- `tolerance`：收敛容差（默认 1e-3）
- `relaxation`：松弛因子 $\omega$（默认 1.0，范围 0~2）

---

### 3. 初始可行流生成

为了保证 Hardy Cross 迭代从满足节点守恒的初始状态开始，需要求解线性方程组：

$$
\mathbf{A} \cdot \mathbf{Q}^{(0)} = \mathbf{b}
$$

由于关联矩阵 $\mathbf{A}$ 的行秩为 $N-1$（任意节点方程可由其他方程推导），需要删除一行（参考节点）以避免奇异：

$$
\mathbf{Q}^{(0)} = \mathbf{A}_{\text{red}}^\top (\mathbf{A}_{\text{red}} \mathbf{A}_{\text{red}}^\top)^{-1} \mathbf{b}_{\text{red}}
$$

这是满足节点守恒的**最小范数解**（对应欧几里得距离意义下的"最优"初始猜测）。

---

## 项目组成

### 文件结构

```
General Problem Solver/
├── README.md                          # 本文档
├── ui/
│   └── NetworkSolverApp.mlapp         # 主应用程序（App Designer GUI）
├── +gps/                              # 主命名空间包
│   ├── +data/                         # 数据处理模块
│   │   └── load_network_data.m        # 从CSV文件加载网络数据
│   ├── +logic/                        # 核心算法模块
│   │   ├── ventilation_network_solver_generic.m  # Hardy Cross 通用求解器
│   │   └── identify_fundamental_loops.m          # 独立回路自动识别算法
│   └── +ui/                           # UI 辅助函数模块
│       ├── solve_network_from_ui.m          # 从UI组件提取参数并调用求解器
│       ├── import_branches_csv.m            # CSV导入核心函数
│       ├── import_branches_csv_to_uitable.m # 导入CSV到UITable组件
│       ├── export_uitable_to_branches_csv.m # 导出UITable数据到CSV
│       ├── add_new_row_to_uitable.m         # 向UITable添加新行
│       ├── delete_selected_rows_from_uitable.m  # 删除UITable选中行
│       ├── clear_uitable.m                  # 清空UITable数据
│       ├── plot_network_graph.m             # 绘制网络拓扑图（无向图）
│       ├── plot_solution_bars.m             # 绘制求解结果柱状图（风量+风压降）
│       ├── export_solution_to_csv.m         # 导出求解结果到CSV
│       └── append_to_textarea.m             # 向TextArea组件追加日志消息
└── test_case_10x11/                   # 测试案例（10节点11分支网络）
    └── branches.csv                   # 示例网络数据
```

### 核心模块说明

#### 1. **主应用程序** (`NetworkSolverApp.mlapp`)

基于 MATLAB App Designer 开发的图形用户界面，包含以下组件：

- **UITable**：分支数据表格（ID、起点、终点、风阻）
- **EditField 1-5**：参数输入框（总风量、入风节点、回风节点、最大迭代数、收敛容差）
- **Slider**：松弛因子调节（0~2）
- **DropDown**：求解方法选择（当前仅 Hardy Cross）
- **DropDown 2**：信息显示模式（显示/隐藏详细日志和可视化）
- **TextArea**：求解日志输出区域
- **按钮组**：导入、导出、添加、删除、清空、求解、绘图

#### 2. **核心求解器** (`ventilation_network_solver_generic.m`)

通用 Hardy Cross 求解器，输入输出如下：

**输入**：
- `Branches`（结构体）：
  - `.id` (B×1)：分支编号（1~B）
  - `.from_node` (B×1)：起点节点
  - `.to_node` (B×1)：终点节点
  - `.R` (B×1)：风阻系数
- `Boundary`（结构体）：
  - `.inlet_node`：入风节点编号（标量或向量）
  - `.outlet_node`：回风节点编号（标量或向量）
  - `.Q_total`：系统总风量（m³/s）
- `SolverOptions`（结构体，可选）：
  - `.max_iter`：最大迭代次数
  - `.tolerance`：收敛容差
  - `.relaxation`：松弛因子
  - `.verbose`：是否输出详细信息

**输出**：
- `Q` (B×1)：各分支风量（m³/s）
- `Results`（结构体）：
  - `.converged`：是否收敛（布尔值）
  - `.iterations`：实际迭代次数
  - `.max_residual`：最大回路残差
  - `.pressure_diff_signed` (B×1)：各分支风压降（带符号，Pa）
  - `.LoopMatrix` (M×B)：回路矩阵
  - `.node_residual` (N×1)：节点流量守恒残差

#### 3. **回路识别算法** (`identify_fundamental_loops.m`)

基于**生成树法**自动识别网络中的 $M = B - N + 1$ 个独立回路：

**算法复杂度**：
- 时间复杂度：$O(B \log N)$（DFS 生成树 + 最短路径搜索）
- 空间复杂度：$O(M \times B)$（回路矩阵存储）

**输出**：
- `LoopMatrix` (M×B)：回路矩阵，元素为 {-1, 0, +1}
- `LoopInfo`（结构体数组）：
  - `.branches`：回路包含的分支编号列表
  - `.signs`：对应的方向符号列表
  - `.chord_branch`：形成该回路的非树边（弦）

#### 4. **UI 集成函数** (`solve_network_from_ui.m`)

从 App Designer 组件中提取所有参数，执行数据验证（10+ 项检查），调用求解器，并将结果和日志输出到 TextArea。

**数据验证项**：
- 分支 ID 连续性（1~B）
- 节点编号有效性（≥1，无自环）
- 风阻系数有效性（>0，有限数）
- 边界条件完整性（入/回风节点不重叠，在范围内）
- 网络连通性（无孤立子图）
- 参数合理性（总风量 >0，容差 >0，松弛因子 0~2）

#### 5. **可视化模块**

- **`plot_network_graph.m`**：使用 `sparse` + `graph` 构建无向图，显示节点编号和分支 ID
- **`plot_solution_bars.m`**：生成双子图柱状图（风量 + 风压降），正值/负值分色显示，柱顶标注数值

#### 6. **数据 I/O 模块**

- **`import_branches_csv.m`**：读取 CSV 文件（自动识别列名，支持中英文）
- **`export_solution_to_csv.m`**：导出求解结果（包含 6 列：ID、起点、终点、风阻、风量、风压降），带详细注释头

---

## 使用说明

### 前置条件

- MATLAB R2019b 或更高版本（需要 App Designer 和 Graph 工具箱）
- 已安装 Statistics and Machine Learning Toolbox（用于 `graph` 函数）

### 启动应用

1. 打开 MATLAB
2. 将工作目录切换到 `General Problem Solver` 文件夹
3. 在命令窗口输入：
   ```matlab
   NetworkSolverApp
   ```
4. 或者直接双击 `ui/NetworkSolverApp.mlapp` 文件

---

### 操作流程

#### 步骤 1：导入网络数据

**方式 A：从 CSV 文件导入**

1. 点击 **"导入 CSV"** 按钮
2. 选择包含分支数据的 CSV 文件（格式见下文）
3. 数据将自动填充到表格中

**CSV 格式要求**：

```csv
ID,起点,终点,风阻
1,1,2,0.05
2,1,3,0.08
3,2,3,0.03
...
```

列名可以是中文（ID/起点/终点/风阻）或英文（id/from_node/to_node/R/resistance），程序会自动识别。

**方式 B：手动添加分支**

1. 点击 **"添加行"** 按钮
2. 在弹出的对话框中输入：ID、起点、终点、风阻
3. 点击确定，新行将添加到表格末尾

**方式 C：直接编辑表格**

双击表格单元格即可直接修改数值。

---

#### 步骤 2：设置边界条件

在界面左侧的参数区域填写：

1. **初始风量（系统总风量）**：例如 `100`（单位：m³/s）
2. **入风节点**：例如 `1`（多个节点用逗号分隔：`1,2`）
3. **回风节点**：例如 `5`（多个节点用逗号分隔：`5,6`）

**注意**：
- 入风节点和回风节点不能重叠
- 节点编号必须在网络节点范围内（1~N）

---

#### 步骤 3：调整求解器参数（可选）

- **最大迭代数**：默认 1000（建议范围 500~5000）
- **收敛容差**：默认 0.001（建议范围 1e-4~1e-2）
- **松弛因子**：默认 1.0（拖动滑块调节 0~2，推荐 0.8~1.2）
  - $\omega < 1$：欠松弛，适用于振荡发散的情况
  - $\omega = 1$：标准 Hardy Cross 法
  - $\omega > 1$：超松弛，可加速收敛（但可能导致不稳定）
- **信息显示**：选择 **"显示"** 以启用 VERBOSE 模式（自动生成柱状图和 CSV 结果文件）

---

#### 步骤 4：求解

1. 点击 **"求解"** 按钮
2. 程序将执行以下操作：
   - 验证数据有效性（10+ 项检查）
   - 自动识别独立回路
   - 执行 Hardy Cross 迭代
   - 在 TextArea 区域输出详细日志
3. 求解完成后，日志中将显示：
   - 收敛状态（成功/未完全收敛）
   - 迭代次数
   - 最大回路残差和节点残差
   - 各分支风量（m³/s）

---

#### 步骤 5：查看结果

**方式 A：文本日志**

TextArea 区域实时显示求解过程，包括：
- 求解开始时间和参数摘要
- 回路识别信息（回路数、生成树边数）
- 收敛信息（迭代次数、残差）
- 各分支风量详细数值

**方式 B：可视化图表**

如果启用 **"信息显示：显示"**，求解成功后将自动生成：

1. **柱状图窗口**（双子图）：
   - 左图：各巷道通风量（正值蓝色，负值红色）
   - 右图：各巷道风压降（正值绿色，负值橙色）
   - 柱顶标注数值，图例位于底部

2. **网络拓扑图**：点击 **"绘制网络图"** 按钮，显示节点和分支的连接关系

**方式 C：导出 CSV 文件**

VERBOSE 模式下，程序会自动弹出保存对话框，导出包含以下列的 CSV 文件：
- `branch_id`：巷道 ID
- `from_node`：起点节点
- `to_node`：终点节点
- `resistance`：通风阻力（N·s²/m⁸）
- `flow_rate`：风量（m³/s，正值顺流，负值逆流）
- `pressure_drop`：风压降（Pa，正值压降，负值压升）

文件包含详细的注释头（导出时间、收敛信息、列定义）。

---

#### 步骤 6：数据管理

- **导出表格数据**：点击 **"导出 CSV"** 按钮，将当前表格数据保存为 CSV 文件（用于后续重用）
- **删除行**：选中表格中的一行或多行，点击 **"删除行"** 按钮
- **清空表格**：点击 **"清空表格"** 按钮，删除所有数据（需确认）

---

### 测试案例

项目自带一个 10 节点 11 分支的测试案例（`test_case_10x11/branches.csv`），可用于验证程序功能：

```matlab
% 在 MATLAB 命令窗口测试
cd('test_case_10x11')
Branches = gps.data.load_network_data('branches.csv');

Boundary.inlet_node = 1;
Boundary.outlet_node = 6;
Boundary.Q_total = 100;

SolverOptions.tolerance = 1e-6;
SolverOptions.verbose = true;

[Q, Results] = gps.logic.ventilation_network_solver_generic(Branches, Boundary, SolverOptions);
```

---

## 常见问题

### Q1：求解未收敛怎么办？

**原因**：
- 初始猜测离真解太远
- 网络拓扑过于复杂（强耦合回路）
- 参数设置不当

**解决方案**：
1. 增加**最大迭代数**（例如 2000~5000）
2. 减小**松弛因子**（例如 0.5~0.8），使用欠松弛防止振荡
3. 减小**收敛容差**（例如 1e-2），降低精度要求
4. 检查网络数据是否合理（风阻系数不能为 0 或负数）

---

### Q2：节点残差较大但回路残差已收敛？

**原因**：数值误差累积导致节点守恒略有偏差（通常 <1e-6）。

**解决方案**：这是正常现象，只要节点残差在可接受范围内（例如 <1e-4），结果仍然可信。可通过减小容差和增加迭代次数进一步降低残差。

---

### Q3：如何处理风机？

**当前版本**：仅支持自然通风网络（无风机）。

**未来扩展**：可在 `ventilation_network_solver_generic.m` 中添加风机特性曲线 $H = f(Q)$，在回路平衡方程中加入风机风压项：

$$
\sum_{i \in \text{loop}_k} s_{ki} \cdot \Delta p_i - \sum_{f \in \text{fans}_k} H_f(Q_f) = 0
$$

---

### Q4：程序报错"网络不连通"？

**原因**：存在孤立的节点或子图，无法从入风节点到达回风节点。

**解决方案**：
1. 检查分支数据，确保所有节点通过分支相连
2. 使用 **"绘制网络图"** 功能可视化拓扑，查找孤立区域
3. 补充缺失的分支连接

---

## 算法性能

### 时间复杂度

- **回路识别**：$O(B \log N)$（DFS + 最短路径）
- **单次 Hardy Cross 迭代**：$O(M \times B)$（$M$ 个回路，每个回路遍历部分分支）
- **总复杂度**：$O(K \times M \times B)$，其中 $K$ 为迭代次数（通常 10~100）

### 适用规模

- **小型网络**（$B < 50$）：实时求解（<1 秒）
- **中型网络**（$B = 50\sim200$）：数秒内完成
- **大型网络**（$B > 200$）：可能需要数十秒，建议调整松弛因子加速收敛

---

## 未来扩展方向

1. **牛顿-拉夫逊法**：全局收敛性更好，适用于强耦合网络
2. **风机特性曲线**：支持带风机的通风系统
3. **多风机协同调节**：优化风机工况点
4. **节点压力法**：以节点压力为未知量，减少方程数（$N$ 个方程 vs $B$ 个方程）
5. **并行计算**：利用 MATLAB 并行工具箱加速大规模网络求解
6. **不确定性分析**：考虑风阻系数的测量误差，进行蒙特卡洛模拟

---

## 参考文献

1. Cross, H. (1936). "Analysis of Flow in Networks of Conduits or Conductors". *University of Illinois Bulletin*, 34(22).
2. Scott, J. A., & Hinsley, F. B. (1953). "A Modified Hardy Cross Method for the Solution of Pipe Network Problems". *Journal of the Institution of Water Engineers*, 7(3), 229-242.
3. Atkinson, J. J. (1862). "On the Theory of the Ventilation of Mines". *Transactions of the North of England Institute of Mining and Mechanical Engineers*, 11, 118-140.
4. 王兆丰, 魏连江. (2015). 《矿井通风与空气调节》（第三版）. 中国矿业大学出版社.
5. MATLAB Documentation: [Graph and Network Algorithms](https://www.mathworks.com/help/matlab/graph-and-network-algorithms.html)

---

## 许可证与联系方式

本项目基于 **GNU General Public License v3.0 (GPL-3.0)** 开源。

详见[项目主页 README](../README.md) 了解完整的许可证条款、作者信息和联系方式。

---

**版本**：v1.0 (2025-12-18)
