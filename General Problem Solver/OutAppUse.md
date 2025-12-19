# 不启用 App 主界面：如何使用 General Problem Solver

本文介绍在**不打开 App Designer 主界面**（`NetworkSolverApp.mlapp`）的情况下，如何在 MATLAB 命令行/脚本里直接使用本项目完成求解。提供两种方式：

1. 手动在 MATLAB 中输入原始数据（`Branches/Boundary/SolverOptions`）
2. 使用 `gps.data.load_network_data` 从 CSV 目录加载数据

***注***：[这里是更详细的函数说明文档](/General%20Problem%20Solver/Functions.md)

---

## 0. 准备工作：添加工程路径

在 MATLAB 当前工作目录为仓库根目录（或任意目录）时，先把工程加入路径：

```matlab
addpath('General Problem Solver');
```

之后即可通过包名调用（例如 `gps.logic.ventilation_network_solver_generic`）。

---

## 1) 方式一：手动输入原始数据（推荐用于快速试算/教学）

### 1.1 构造 `Branches`（分支/巷道数据）

需要 4 个字段（均为列向量）：

- `id`：分支编号，**必须是 `1..B` 连续整数**（求解器强制要求）
- `from_node`：起点节点（定义分支正方向）
- `to_node`：终点节点
- `R`：风阻（正数）

示例（自行替换成你的网络数据）：

```matlab
Branches = struct();
Branches.id        = (1:7)';                 % 1..B 连续
Branches.from_node = [1;2;3;4;5;6;2];
Branches.to_node   = [2;3;4;5;6;1;5];
Branches.R         = [0.12;0.08;0.10;0.06;0.09;0.11;0.07];
```

### 1.2 构造 `Boundary`（边界条件）

```matlab
Boundary = struct();
Boundary.Q_total    = 100;   % 系统总风量（>0）
Boundary.inlet_node = 1;     % 入风节点（可为向量，例如 [1 2]）
Boundary.outlet_node = 6;    % 回风节点（可为向量）
```

### 1.3（可选）设置 `SolverOptions`

```matlab
SolverOptions = struct();
SolverOptions.max_iter   = 1000;
SolverOptions.tolerance  = 1e-3;
SolverOptions.relaxation = 1.0;
SolverOptions.verbose    = true;
```

不提供 `SolverOptions` 也可以，求解器会使用默认值。

### 1.4 调用求解器

```matlab
[Q, Results] = gps.logic.ventilation_network_solver_generic(Branches, Boundary, SolverOptions);
disp(Q);                     % B×1，每条分支的风量
disp(Results.converged);      % 是否收敛
disp(Results.iterations);     % 迭代次数
```

> 提示：如果你从其他来源拿到的 `Branches.id` 不是 `1..B` 连续编号，请先重排/重编号，否则会报错。

---

## 2) 方式二：使用 `load_network_data` 从 CSV 加载（推荐用于批处理/复现）

### 2.1 目录结构要求

`gps.data.load_network_data(data_dir)` 会在 `data_dir` 目录下查找（文件名固定）：

- 必需：`branches.csv`
- 必需：`boundary.csv`
- 可选：`solver_config.csv`（不存在则使用默认求解参数）

调用示例：

```matlab
addpath('General Problem Solver');

[Branches, Boundary, SolverOptions] = gps.data.load_network_data('path/to/my_network/');
[Q, Results] = gps.logic.ventilation_network_solver_generic(Branches, Boundary, SolverOptions);
```

### 2.2 `branches.csv` 格式（必需）

要求：CSV 必须有表头，且至少包含以下 4 列（列名需严格匹配）：

- `branch_id`
- `from_node`
- `to_node`
- `resistance`

示例：

```csv
branch_id,from_node,to_node,resistance
1,1,2,0.12
2,2,3,0.08
3,3,4,0.10
```

约束建议：
- `branch_id` 建议为 `1..B` 连续整数（求解器强制要求连续）
- `from_node/to_node` 为正整数节点编号（≥1）
- `resistance` 必须为正数

### 2.3 `boundary.csv` 格式（必需）

格式：每行一个“键,值”，支持 `#` 注释行与空行。键名不区分大小写（内部会转为 `upper`）。

支持键：
- `Q_TOTAL`：系统总风量（正数）
- `INLET_NODE`：入风节点编号，**多个值用分号 `;` 分隔**
- `OUTLET_NODE`：回风节点编号，多个值用分号 `;` 分隔

示例：

```csv
# boundary.csv
Q_TOTAL,100
INLET_NODE,1;2
OUTLET_NODE,6
```

注意：
- `INLET_NODE/OUTLET_NODE` 必须落在网络节点范围 `1..max(from_node,to_node)` 内
- `INLET_BRANCH/OUTLET_BRANCH` 在该 loader 中会直接报错（已弃用）

### 2.4 `solver_config.csv` 格式（可选）

格式同 `boundary.csv`：每行 `键,值`，支持 `#` 注释与空行。

支持键：
- `MAX_ITER`（数值）
- `TOLERANCE`（数值）
- `METHOD`（字符串）
- `VERBOSE`（布尔，只接受 `true/false/1/0`）
- `RELAXATION`（数值）

示例：

```csv
MAX_ITER,1000
TOLERANCE,1e-3
RELAXATION,1.0
VERBOSE,true
METHOD,HardyCross
```

### 2.5 直接使用模板快速开始

项目已提供模板文件，可复制后改数据：

- `General Problem Solver/+gps/+data/branches_template.csv`
- `General Problem Solver/+gps/+data/boundary_template.csv`
- `General Problem Solver/+gps/+data/solver_config_template.csv`

---

## 3) 在现有函数基础上开发新用法

本项目鼓励开发新用法，现有函数组织已经按 `gps.data / gps.logic / gps.ui` 分层，你可以很容易基于现有能力扩展新流程，例如：

- 批量扫参：循环不同的 `Boundary.Q_total / inlet/outlet` 或 `SolverOptions.relaxation`，统计 `Results.converged` 与残差
- 命令行工具化：用一个脚本封装 `load_network_data → solver → export`
- 自定义导出：复用 `gps.ui.export_solution_to_csv` 的表结构，扩展更多字段（例如分支长度、风门系数等）
