# 06 App 外用法（脚本/命令行）

本章说明如何在 **不打开 App 主界面** 的情况下使用 `General Problem Solver` 完成求解，并给出“基础/进阶”两类用法组织方式。

更贴近函数清单与细节的说明也在这里（可配合阅读）：
- [gps/OutAppUse.md](gps/OutAppUse.md)
- [gps/Functions.md](gps/Functions.md)

---

## 0. 准备：把工程加入 MATLAB 路径

```matlab
addpath('General Problem Solver');
```

之后即可通过包名调用，例如 `gps.logic.ventilation_network_solver_generic`。

---

## 1. 基础结构体与参数约定（最重要的接口）

### 1.1 `Branches`（分支/巷道）

`Branches` 是一个 struct，必须包含 4 个字段（推荐 `double` 列向量，大小 `B×1`）：
- `Branches.id`：分支编号，**求解器要求为 `1..B` 连续整数**
- `Branches.from_node`：起点节点编号（定义分支正方向）
- `Branches.to_node`：终点节点编号
- `Branches.R`：风阻系数（正数）

风量 `Q(i)` 的正负号约定：若 `Q(i) > 0`，表示风流方向与 `from_node(i) -> to_node(i)` 一致；反之为逆向。

### 1.2 `Boundary`（边界条件）

`Boundary` 也是 struct，必须包含：
- `Boundary.Q_total`：系统总风量（标量，>0）
- `Boundary.inlet_node`：入风节点（标量或向量）
- `Boundary.outlet_node`：回风节点（标量或向量）

当前通用求解器对多入风/多回风的处理方式为：将 `Q_total` 在入风节点上**平均注入**，在回风节点上**平均抽出**（实现位于 `General Problem Solver/+gps/+logic/ventilation_network_solver_generic.m`）。

### 1.3 `SolverOptions`（可选）

`SolverOptions` 可不提供；若提供，常用字段包括：
- `max_iter`：最大迭代次数（默认 `1000`）
- `tolerance`：收敛容差（默认 `1e-3`）
- `relaxation`：松弛因子 `ω`（默认 `1.0`，推荐 `0.8~1.2`；振荡时可取 `0.5~0.8`）
- `verbose`：是否输出过程信息（默认 `true`）

### 1.4 输出：`Q` 与 `Results`

调用 `gps.logic.ventilation_network_solver_generic` 返回：
- `Q (B×1)`：各分支风量
- `Results`：结构体，常用字段如 `converged/iterations/max_residual/node_residual/LoopMatrix/pressure_diff_signed` 等

---

## 2. 基础用法 A：手动构造结构体并求解

```matlab
addpath('General Problem Solver');

Branches = struct();
Branches.id        = (1:7)';
Branches.from_node = [1;2;3;4;5;6;2];
Branches.to_node   = [2;3;4;5;6;1;5];
Branches.R         = [0.12;0.08;0.10;0.06;0.09;0.11;0.07];

Boundary = struct();
Boundary.Q_total     = 100;
Boundary.inlet_node  = 1;
Boundary.outlet_node = 6;

SolverOptions = struct('max_iter', 1000, 'tolerance', 1e-3, 'relaxation', 1.0, 'verbose', true);

[Q, Results] = gps.logic.ventilation_network_solver_generic(Branches, Boundary, SolverOptions);
gps.ui.plot_solution_bars(Branches, Q, Results);
gps.ui.export_solution_to_csv(Branches, Q, Results, 'solution_results.csv');
```

---

## 3. 基础用法 B：用 `load_network_data` 从 CSV 目录加载

### 3.1 目录约定（推荐做法）

`gps.data.load_network_data(data_dir)` 读取一个目录下的三个文件：
- `branches.csv`（必需）
- `boundary.csv`（必需）
- `solver_config.csv`（可选）

模板可参考：
- `General Problem Solver/+gps/+data/branches_template.csv`
- `General Problem Solver/+gps/+data/boundary_template.csv`
- `General Problem Solver/+gps/+data/solver_config_template.csv`

### 3.2 CSV 格式要点（与 App 的“导入 CSV”不同）

1) `branches.csv`：要求表头字段名为（必须包含）：
- `branch_id,from_node,to_node,resistance`

并且建议 `branch_id` 为 `1..B` 连续整数（否则通用求解器会报错）。

2) `boundary.csv`：键值对格式（逗号分隔），节点列表使用 `;` 分隔，例如：

```text
Q_TOTAL,100
INLET_NODE,1;2
OUTLET_NODE,6
```

3) `solver_config.csv`：键值对格式（可选），例如：

```text
MAX_ITER,1000
TOLERANCE,1e-3
RELAXATION,1.0
VERBOSE,true
```

### 3.3 完整示例（直接跑项目自带案例）

```matlab
addpath('General Problem Solver');

[Branches, Boundary, SolverOptions] = gps.data.load_network_data('General Problem Solver/test_case_10x11');
[Q, Results] = gps.logic.ventilation_network_solver_generic(Branches, Boundary, SolverOptions);

gps.ui.plot_solution_bars(Branches, Q, Results);
gps.ui.export_solution_to_csv(Branches, Q, Results, 'test_case_10x11_solution.csv');
```

---

## 4. 进阶用法（基于现有函数做二次开发）

### 4.1 批量求解 / 参数扫描（最常见）

典型场景：
- 扫描不同 `Q_total`（不同生产工况）
- 对 `Branches.R` 做统一缩放或扰动（风阻敏感性分析）

做法：在循环中构造/修改 `Boundary` 或 `Branches`，反复调用 `gps.logic.ventilation_network_solver_generic`，再用 `gps.ui.export_solution_to_csv` 保存结果。

### 4.2 只做拓扑分析：回路识别

如果你只关心“网络有多少基本回路、每个回路包含哪些巷道”，可以直接调用：

```matlab
[LoopMatrix, LoopInfo] = gps.logic.identify_fundamental_loops(Branches, true);
```

### 4.3 自定义边界分配策略（需要改一点点求解器）

当前版本对多入风/多回风采用平均分配。如果你需要“按权重分配”（例如不同进风井口能力不同），可在二次开发时把
`ventilation_network_solver_generic.m` 中构造 `b` 的逻辑改为：
- `b(inlet_nodes) = +Q_total * w_in / sum(w_in)`
- `b(outlet_nodes) = -Q_total * w_out / sum(w_out)`

建议做成新的参数字段（例如 `Boundary.inlet_weight/outlet_weight`），而不是在脚本中到处硬改。

### 4.4 把求解器封装成你的“新入口”

项目的函数拆分已经较清晰，常见扩展方式包括：
- 写一个 `run_case.m`：读取 CSV → 求解 → 绘图 → 导出（适合交作业/批处理）
- 写一个 CLI/GUI 外壳：把 `Branches/Boundary/SolverOptions` 当成稳定 API
- 新增结果输出格式：JSON、MAT、Excel，或把 `Results` 画成你需要的图表

> 鼓励你基于现有函数开发新用法：只要保证 `Branches/Boundary/SolverOptions` 的结构约定不变，其他都可以自由组合扩展。
