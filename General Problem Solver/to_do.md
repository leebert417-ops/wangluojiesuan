# 通用通风网络求解器（General Problem Solver）实施计划

## 项目目标

将固定拓扑的 Hardy Cross 求解器扩展为**通用通风网络求解器**，支持任意规模、任意拓扑的矿井通风网络自动解算。

---

## 核心功能模块

### 模块 1：数据输入结构定义 ✅

**文件**：`example_input_structure.m`

**功能**：
- 定义标准化的网络数据结构（`Branches`、`Boundary`、`SolverOptions`）
- 提供示例数据（图 5.2 网络）
- 数据格式校验函数

**输出**：
- 标准化的 MATLAB 结构体
- 输入数据校验函数 `validate_input_data.m`

---

### 模块 2：独立回路自动识别 🔥 核心难点

**文件**：`identify_fundamental_loops.m`

**功能**：
- 基于生成树法（Fundamental Cycles）自动提取独立回路
- 输出回路矩阵 `LoopMatrix` (M×B)，元素为 {-1, 0, +1}
- 回路详细信息（经过的分支列表、方向符号）

**算法流程**：
```
输入：Branches (from_node, to_node)
步骤1：构建无向图 G
步骤2：生成生成树 T（DFS/BFS）
步骤3：识别非树边（Chords）
步骤4：对每条非树边 c：
       4.1 在生成树 T 中找到 c.from → c.to 的唯一路径 P
       4.2 形成基本回路：Loop_k = P ∪ {c}
       4.3 确定回路方向并填充 LoopMatrix(k, :)
输出：LoopMatrix (M×B), LoopInfo
```

**依赖**：
- MATLAB Graph 对象（`graph`, `dfsearch`, `shortestpath`）
- 或手动实现邻接表 + DFS

**优先级**：🔴 高（其他模块依赖此输出）

---

### 模块 3：初始风量估计

**文件**：`initialize_flow.m`

**功能**：
- 根据边界条件生成满足基本流量守恒的初始猜测值
- 策略1（简单）：入口分支平均分配 `Q_total / n_inlet`，其他分支取 0
- 策略2（智能）：基于最短路径启发式分配初始风量

**输入**：
- `Branches` 结构体
- `Boundary` 结构体

**输出**：
- `Q_init` (B×1 向量)

**优先级**：🟡 中（影响收敛速度，但不影响最终结果）

---

### 模块 4：通用 Hardy Cross 迭代求解器 🎯 主算法

**文件**：`ventilation_network_solver_generic.m`

**功能**：
- 通用 Hardy Cross 回路迭代法实现
- 支持任意规模网络（自动检测 N 节点、B 分支、M 回路）
- 边界条件归一化（保证入口总风量守恒）
- 收敛性监控与诊断

**输入**：
```matlab
Branches      % 分支数据结构
Boundary      % 边界条件
SolverOptions % 求解器参数（可选）
```

**输出**：
```matlab
Q       % 各分支风量 (B×1)
Results % 结果详细信息
        .iterations     迭代次数
        .converged      是否收敛
        .LoopMatrix     使用的回路矩阵
        .pressure_loss  各分支压降
        .max_residual   最终回路残差
```

**核心算法**：
```
初始化 Q = Q_init
for iter = 1:max_iter
    for k = 1:M  % 对每个独立回路
        获取回路方向符号 s_k = LoopMatrix(k, :)
        计算回路压降 H = R .* Q .* |Q|
        计算闭合差 Δh_k = s_k' * H
        计算斜率 D_k = sum(2 * R(i) * |Q(i)|)  对于回路中的分支
        修正量 ΔQ_k = -Δh_k / D_k
        更新风量 Q = Q + s_k * ΔQ_k
    end

    边界归一化：Q = Q * (Q_total / sum(Q(inlet_branches)))

    if 收敛判据满足
        跳出循环
    end
end
```

**优先级**：🔴 高

---

### 模块 5：节点流量守恒与回路压降验证

**文件**：`verify_solution.m`

**功能**：
- 验证节点流量守恒（基尔霍夫第一定律）
- 验证回路压降平衡（基尔霍夫第二定律）
- 输出校核报告

**输入**：
- `Branches`
- `Q` 求解结果
- `LoopMatrix`

**输出**：
- `node_balance_error` (N×1)：每个节点的流量平衡误差
- `loop_pressure_error` (M×1)：每个回路的压降闭合差
- 校核通过标志

**优先级**：🟢 低（用于结果验证，不影响求解过程）

---

### 模块 6：结果可视化

**文件**：`plot_network_solution.m`

**功能**：
- 绘制网络拓扑图（节点 + 分支 + 风量标注）
- 风量柱状图
- 压降柱状图
- 回路信息展示

**输入**：
- `Branches`
- `Q` 求解结果
- `Results` 求解详细信息

**输出**：
- 多子图综合可视化结果

**优先级**：🟢 低（用于结果展示）

---

## 实施顺序与里程碑

### 阶段 1：基础功能开发（MVP）

**目标**：实现通用求解器核心功能，能够处理任意拓扑网络

**任务清单**：
- [x] 设计数据输入结构
- [x] 实现 `identify_fundamental_loops.m`（核心）
- [x] 实现 `initialize_flow.m`（已集成在主算法中）
- [x] 实现 `ventilation_network_solver_generic.m`（主算法）
- [ ] 用图 5.2 网络验证：通用版本结果 ≈ 固定版本结果

**交付物**：
- 可运行的通用求解器
- `example_input_structure.m` 示例脚本
- 基本测试用例通过

**预计工作量**：3-5 天

---

### 阶段 2：完善与扩展

**任务清单**：
- [ ] 实现 `verify_solution.m` 校核模块
- [ ] 实现 `plot_network_solution.m` 可视化模块
- [ ] 增加输入数据校验（`validate_input_data.m`）
- [ ] 支持从 CSV 文件读取网络数据（`load_network_from_csv.m`）
- [ ] 测试更复杂网络（10 节点 15 分支、非平面图）

**交付物**：
- 完整功能的通用求解器工具箱
- CSV 输入/输出接口
- 完善的错误处理与用户提示

**预计工作量**：2-3 天

---

### 阶段 3：高级功能（可选）

**任务清单**：
- [ ] 支持多入口/多回风口
- [ ] 实现 Newton-Raphson 节点压力法（备选算法）
- [ ] 风机特性曲线支持
- [ ] 求解过程动画演示
- [ ] GUI 界面集成（与 `NetworkSolverApp.mlapp` 对接）

**预计工作量**：5-7 天

---

## 关键技术难点

### 1. 生成树构建算法

**挑战**：确保生成树覆盖所有节点且无环

**解决方案**：
- 使用 MATLAB `graph` 对象的 `dfsearch` 或 `bfsearch`
- 或手动实现 DFS（深度优先搜索）

**参考资源**：
- MATLAB Graph 官方文档：`doc graph`
- 图论教材：网络流基本理论

---

### 2. 回路方向一致性判断

**挑战**：确定每条分支在回路中的方向符号（+1 或 -1）

**解决方案**：
- 统一回路遍历方向（如顺时针）
- 比较分支实际方向与回路遍历方向
- 若一致取 +1，否则取 -1

---

### 3. 数值稳定性

**挑战**：某些网络可能收敛缓慢或振荡

**解决方案**：
- 增加松弛因子（Relaxation Factor）：`Q = Q + α * s_k * ΔQ_k`，其中 `α ∈ (0, 1]`
- 对初始猜测值做启发式优化
- 监控收敛历史，自动调整参数

---

## 测试用例设计

### 测试用例 1：图 5.2 网络（基准测试）

**目的**：验证通用求解器与固定版本结果一致性

**输入**：6 节点、8 分支（与现有 `network_data.csv` 相同）

**预期输出**：
- 风量向量 `Q` 与 `ventilation_network_solver.m` 结果误差 < 0.1%
- 迭代次数相近（±5 次）

---

### 测试用例 2：简单串联网络

**目的**：测试最简单拓扑（无回路）

**输入**：
- 节点：1 → 2 → 3
- 分支：2 条（1-2, 2-3）
- 风阻：R1=0.1, R2=0.2

**预期输出**：
- Q1 = Q2 = 100 m³/s（串联风量相等）
- 迭代次数 = 1（无回路，初始猜测即为解）

---

### 测试用例 3：简单并联网络

**目的**：测试基本并联结构（1 个回路）

**输入**：
- 节点：1 → [2, 3] → 4
- 分支：4 条（1-2, 1-3, 2-4, 3-4）
- 风阻：R1=0.1, R2=0.2, R3=0.1, R4=0.2

**预期输出**：
- Q1 = Q3（风阻相等的并联分支风量相等）
- 回路压降平衡误差 < 0.01 Pa

---

### 测试用例 4：复杂网络（10 节点 15 分支）

**目的**：测试规模扩展性

**输入**：随机生成的连通网络（确保 M = B - N + 1 ≥ 3）

**预期输出**：
- 能够在合理迭代次数内收敛（< 500 次）
- 所有节点流量守恒误差 < 0.1 m³/s
- 所有回路压降平衡误差 < 0.1 Pa

---

## 文件组织结构

```
General Problem Solver/
├── to_do.md                               【本文档】
├── example_input_structure.m              【示例数据结构】
├── ventilation_network_solver_generic.m   【主算法】
├── identify_fundamental_loops.m           【回路识别模块】
├── initialize_flow.m                      【初始风量估计】
├── verify_solution.m                      【结果校核】
├── plot_network_solution.m                【可视化】
├── validate_input_data.m                  【输入校验】
├── load_network_from_csv.m                【CSV 读取】
├── test_cases/                            【测试用例目录】
│   ├── test_case_fig52.m                  测试图 5.2 网络
│   ├── test_case_simple_series.m          测试串联网络
│   ├── test_case_simple_parallel.m        测试并联网络
│   └── test_case_complex.m                测试复杂网络
├── output/                                【输出目录】
│   ├── nodes.csv                          节点数据（用于 UI 导出）
│   ├── branches.csv                       分支数据
│   └── boundary.csv                       边界条件
└── ui/                                    【UI 应用目录】
    └── NetworkSolverApp.mlapp             GUI 应用（已创建）
```

---

## 开发约定

1. **注释规范**：所有函数必须包含详细的中文注释，解释物理含义
2. **命名规范**：
   - 函数名：小写字母 + 下划线（如 `identify_fundamental_loops`）
   - 变量名：驼峰命名法（如 `LoopMatrix`）
   - 常量：大写字母 + 下划线（如 `MAX_ITER`）
3. **单元测试**：每个模块函数应包含测试代码（可放在函数末尾的 `%% Test` 部分）
4. **错误处理**：所有输入参数必须校验，并给出清晰的错误提示

---

## 参考资料

### 学术文献
- Scott-Hinsley 方法：Hardy Cross 原始论文（1936）
- 通风网络理论：《矿井通风与安全》教材

### MATLAB 工具箱
- `graph` 对象：用于网络拓扑操作
- `sparse` 矩阵：高效存储回路矩阵

### 相关代码
- 固定拓扑版本：`ventilation_network_solver.m`（参考回路迭代逻辑）
- 主脚本：`main_script.m`（参考结果输出格式）

---

## 更新日志

- **2025-12-17**：创建项目规划文档，定义模块结构与实施计划
- **2025-12-17**：完成核心模块开发（主算法、回路识别、示例结构）
