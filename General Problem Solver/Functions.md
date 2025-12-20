# General Problem Solver — 主要函数一览

本文整理项目 `General Problem Solver` 中对外最常用（或作为主流程入口）的 MATLAB 函数，便于快速定位“数据导入 → 绘图 → 求解 → 导出”的调用链。

这些函数不仅可以在 App 内（按钮回调）使用，也可以在 **App 外**（命令行/脚本）直接调用。更完整的“脱离 App 使用方法”（手动构造数据、按目录加载 CSV）请见：[OutAppUse.md](OutAppUse.md)。

---

## 典型调用链（从 App/界面出发）

1. 导入分支 CSV → `gps.ui.import_branches_csv_to_uitable` → 内部调用 `gps.ui.import_branches_csv`
2. 绘制拓扑图 → `gps.ui.plot_network_graph`
3. 从 UI 求解 → `gps.ui.solve_network_from_ui` → 内部调用 `gps.logic.ventilation_network_solver_generic`
4. 可视化/导出结果（可选）→ `gps.ui.plot_solution_bars` / `gps.ui.export_solution_to_csv`
5. 导出当前 UITable 分支数据 → `gps.ui.export_uitable_to_branches_csv`

---

## 数据结构约定（跨模块通用）

### 分支结构 `Branches`（struct）

字段与约束（均建议为 `double` 列向量，大小 `B×1`）：
- `Branches.id`：分支/巷道 ID（求解器要求必须为 `1..B` 连续整数）
- `Branches.from_node`：起点节点编号（正整数，≥1；定义分支正方向）
- `Branches.to_node`：终点节点编号（正整数，≥1）
- `Branches.R`：风阻系数（正数）

最小示例（手动构造）：
```matlab
Branches = struct();
Branches.id        = (1:3)';
Branches.from_node = [1;2;3];
Branches.to_node   = [2;3;1];
Branches.R         = [0.12;0.08;0.10];
```

### 边界条件 `Boundary`（struct）

字段与约束：
- `Boundary.Q_total`：系统总风量（`double` 标量，>0）
- `Boundary.inlet_node`：入风节点编号（`double` 标量或向量；正整数；建议 `unique`）
- `Boundary.outlet_node`：回风节点编号（`double` 标量或向量；正整数；建议 `unique`）

建议：`inlet_node` 与 `outlet_node` 不能重复，且必须落在网络节点范围 `1..max(from_node,to_node)` 内。

### 求解器参数 `SolverOptions`（struct）

常用字段（可不提供，求解器有默认值）：
- `SolverOptions.max_iter`：最大迭代次数（默认 1000）
- `SolverOptions.tolerance`：收敛容差（默认 `1e-3`）
- `SolverOptions.relaxation`：松弛因子（默认 1.0）
- `SolverOptions.verbose`：是否打印过程信息（默认 `true`）

### 求解结果 `Results`（struct）

`gps.logic.ventilation_network_solver_generic` 的第二个返回值，常用字段包括：
- `Results.converged`（logical）：是否收敛
- `Results.iterations`（double 标量）：迭代次数
- `Results.max_residual`（double 标量）：最大回路残差
- `Results.residual_history`（double 向量）：残差历史（长度为迭代次数）
- `Results.node_residual`（`N×1`）：节点守恒残差 `A*Q-b`
- `Results.LoopMatrix`（`M×B`）：基本回路矩阵
- `Results.pressure_drop`（`B×1`）：各分支压降（正值）
- `Results.network_info`（struct）：网络规模信息（`N/B/M`）

---

## `gps.logic`（核心算法）

### `gps.logic.ventilation_network_solver_generic`

文件：`General Problem Solver/+gps/+logic/ventilation_network_solver_generic.m`

签名：
```matlab
[Q, Results] = gps.logic.ventilation_network_solver_generic(Branches, Boundary, SolverOptions)
```

作用：
- 通用通风网络求解器（Hardy Cross）
- 从 `Boundary.Q_total + inlet/outlet` 构造节点注入向量 `b`，生成满足节点守恒的初始可行流 `Q0`，再进行回路迭代修正

输入/输出：
- 输入：`Branches`、`Boundary`、可选 `SolverOptions`
- 输出：
  - `Q`：各分支风量（`B×1`）
  - `Results`：迭代信息与残差等（例如 `converged/iterations/max_residual/node_residual/LoopMatrix` 等）

独立调用示例（App 外）：
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
disp(Q);
disp(Results.converged);
```

依赖：
- 调用 `gps.logic.identify_fundamental_loops` 自动识别基本回路

---

### `gps.logic.identify_fundamental_loops`

文件：`General Problem Solver/+gps/+logic/identify_fundamental_loops.m`

签名：
```matlab
[LoopMatrix, LoopInfo] = gps.logic.identify_fundamental_loops(Branches, verbose)
```

作用：
- 基于生成树（Spanning Tree）方法，从网络拓扑自动识别独立基本回路（Fundamental Cycles）
- 输出回路-分支矩阵 `LoopMatrix`（元素为 `-1/0/+1`，表示分支在回路中的方向关系）

输入/输出：
- 输入：`Branches`，可选 `verbose`
- 输出：
  - `LoopMatrix`：`M×B`（`M = B - N + 1`）
  - `LoopInfo`：每个回路的分支列表/方向/弦边等信息

输出结构补充：
- `LoopInfo` 为结构体数组（长度 `M`），常用字段：
  - `LoopInfo(k).branches`：回路 k 包含的分支 ID（列向量）
  - `LoopInfo(k).signs`：对应的方向符号（`+1/-1`）
  - `LoopInfo(k).chord_branch`：形成该回路的弦边分支 ID

独立调用示例：
```matlab
addpath('General Problem Solver');
Branches = struct();
Branches.id        = (1:7)';
Branches.from_node = [1;2;3;4;5;6;2];
Branches.to_node   = [2;3;4;5;6;1;5];
Branches.R         = [0.12;0.08;0.10;0.06;0.09;0.11;0.07];

[S, info] = gps.logic.identify_fundamental_loops(Branches, true);
disp(size(S));           % [M, B]
disp(info(1));           % 查看某个回路信息
```

---

## `gps.ui`（界面/交互辅助）

### `gps.ui.solve_network_from_ui`

文件：`General Problem Solver/+gps/+ui/solve_network_from_ui.m`

签名：
```matlab
[Q, Results, success] = gps.ui.solve_network_from_ui(app)
```

作用：
- 从 App Designer 的 UI 组件读取分支表格与边界/求解参数（`UITable/EditField/Slider/DropDown` 等）
- 校验输入合法性并调用 `gps.logic.ventilation_network_solver_generic`
- 将过程信息追加到 `TextArea`（如果存在），并在 `verbose` 模式下进行绘图/导出

输入/输出：
- 输入：`app`（App Designer 应用对象）
- 输出：`Q`、`Results`、`success`（是否收敛）

参数结构补充（`app` 需要的核心属性）：
- `app.UITable.Data`：分支表格数据（通常是 `table`，至少 4 列：ID/起点/终点/风阻）
- `app.EditField.Value`：总风量 `Q_total`
- `app.EditField_2.Value`：入风节点（字符串如 `"1,2"` 或数值）
- `app.EditField_3.Value`：回风节点（字符串如 `"5,6"` 或数值）
- `app.EditField_4.Value`：最大迭代次数（可选）
- `app.EditField_5.Value`：收敛容差（可选）
- `app.Slider.Value`：松弛因子（可选）

依赖（常见调用）：
- `gps.logic.ventilation_network_solver_generic`
- `gps.ui.append_to_textarea`（日志输出）
- `gps.ui.plot_solution_bars`（可选）
- `gps.ui.export_solution_to_csv`（可选）

---

### `gps.ui.plot_network_graph`

文件：`General Problem Solver/+gps/+ui/plot_network_graph.m`

签名：
```matlab
G = gps.ui.plot_network_graph(uitableHandle, axesHandle, app)
```

作用：
- 从 `UITable.Data` 中提取起点/终点列绘制网络拓扑图
- 支持（可选）从 `app.EditField_2/3` 读取入风/回风节点，并在图中补上边界巷道（用于更符合通风网络语义的展示）
- 内部按“边表（EndNodes）”构建 `graph`，可避免邻接矩阵方式对平行巷道的合并问题

输入/输出：
- 输入：
  - `uitableHandle`：`matlab.ui.control.Table`
  - `axesHandle`：可选 `UIAxes/axes`（空则新建 figure）
  - `app`：可选 App 对象（用于读取入/回风节点）
- 输出：`G`（`graph` 对象）

参数结构补充（`uitableHandle.Data`）：
- 通常为 `table`，至少包含 3 列：分支 ID、起点、终点
- 本函数会尝试根据 `VariableNames` 自动识别列；识别失败则回退到第 1/2/3 列

独立调用示例（不启用 App）：
```matlab
addpath('General Problem Solver');

fig = uifigure('Name','Network');
uit = uitable(fig);
uit.Data = table((1:3)', [1;2;3], [2;3;1], ...
    'VariableNames', {'ID','起点','终点'});

G = gps.ui.plot_network_graph(uit);
```

---

### `gps.ui.import_branches_csv`

文件：`General Problem Solver/+gps/+ui/import_branches_csv.m`

签名：
```matlab
T = gps.ui.import_branches_csv(filePath)
```

作用：
- 读取分支 CSV（支持中英列名、支持 `#` 注释行）
- 输出规范化后的 `table`，列名固定为：`id/from_node/to_node/R`

输出结构：
- 返回 `T`（`table`），且 `T.Properties.VariableNames` 固定为：`{'id','from_node','to_node','R'}`

独立调用示例：
```matlab
addpath('General Problem Solver');
T = gps.ui.import_branches_csv("branches.csv");
disp(T(1:min(5,height(T)), :));
```

---

### `gps.ui.import_branches_csv_to_uitable`

文件：`General Problem Solver/+gps/+ui/import_branches_csv_to_uitable.m`

签名：
```matlab
T = gps.ui.import_branches_csv_to_uitable(uitableHandle, filePath)
```

作用：
- 通过文件选择框或指定路径读取分支 CSV
- 将规范化后的数据填充到 `UITable`，并设置列标题

依赖：
- `gps.ui.import_branches_csv`

独立调用示例（指定文件路径，避免弹窗）：
```matlab
addpath('General Problem Solver');
fig = uifigure;
uit = uitable(fig);
T = gps.ui.import_branches_csv_to_uitable(uit, "branches.csv");
```

---

### `gps.ui.export_uitable_to_branches_csv`

文件：`General Problem Solver/+gps/+ui/export_uitable_to_branches_csv.m`

签名：
```matlab
success = gps.ui.export_uitable_to_branches_csv(uitableHandle, filePath)
```

作用：
- 将 `UITable.Data` 导出为带注释头的 GPS 标准 CSV（默认列为 `branch_id,from_node,to_node,resistance`）
- 内置数据完整性/合法性校验，并支持保存对话框

独立调用示例（指定输出路径，避免弹窗）：
```matlab
addpath('General Problem Solver');
fig = uifigure;
uit = uitable(fig);
uit.Data = table((1:3)', [1;2;3], [2;3;1], [0.12;0.08;0.10], ...
    'VariableNames', {'ID','起点','终点','风阻'});

ok = gps.ui.export_uitable_to_branches_csv(uit, "branches_out.csv");
disp(ok);
```

---

### `gps.ui.export_solution_to_csv`

文件：`General Problem Solver/+gps/+ui/export_solution_to_csv.m`

签名：
```matlab
filePath = gps.ui.export_solution_to_csv(Branches, Q, Results, filePath)
```

作用：
- 将求解结果导出为 CSV（含风量、压降等），并在文件头写入注释形式的元数据/收敛信息

独立调用示例（先求解再导出）：
```matlab
addpath('General Problem Solver');

% 假设已得到 Branches/Boundary/SolverOptions
[Q, Results] = gps.logic.ventilation_network_solver_generic(Branches, Boundary, SolverOptions);
filePath = gps.ui.export_solution_to_csv(Branches, Q, Results, "solution_results.csv");
disp(filePath);
```

---

### `gps.ui.plot_solution_bars`

文件：`General Problem Solver/+gps/+ui/plot_solution_bars.m`

签名：
```matlab
gps.ui.plot_solution_bars(Branches, Q, Results)
```

作用：
- 绘制结果柱状图（风量、压降两幅子图）
- 适合在 `verbose` 模式下做快速检查与展示

独立调用示例：
```matlab
gps.ui.plot_solution_bars(Branches, Q, Results);
```

---

### `gps.ui.append_to_textarea`

文件：`General Problem Solver/+gps/+ui/append_to_textarea.m`

签名：
```matlab
gps.ui.append_to_textarea(textarea, msg)
```

作用：
- 向 `TextArea` 追加多行文本并自动滚动到底部（用于日志输出）

独立调用示例：
```matlab
fig = uifigure;
ta = uitextarea(fig);
gps.ui.append_to_textarea(ta, sprintf("Hello\\nWorld\\n"));
```

---

### `gps.ui.add_new_row_to_uitable`

文件：`General Problem Solver/+gps/+ui/add_new_row_to_uitable.m`

签名：
```matlab
newRowIndex = gps.ui.add_new_row_to_uitable(uitableHandle)
```

作用：
- 在 `UITable` 末尾追加一行新分支数据
- 自动生成连续 ID，并设置默认值

独立调用示例：
```matlab
fig = uifigure;
uit = uitable(fig);
uit.Data = table((1:2)', [1;2], [2;3], [0.1;0.2], 'VariableNames', {'ID','起点','终点','风阻'});
idx = gps.ui.add_new_row_to_uitable(uit);
disp(idx);
```

---

### `gps.ui.delete_selected_rows_from_uitable`

文件：`General Problem Solver/+gps/+ui/delete_selected_rows_from_uitable.m`

签名：
```matlab
deletedCount = gps.ui.delete_selected_rows_from_uitable(uitableHandle, options)
```

作用：
- 删除 `UITable` 当前选中行
- 支持可选：删除后是否重新连续编号（reindex）、是否确认对话框

独立调用示例（手动指定选择并删除）：
```matlab
fig = uifigure;
uit = uitable(fig);
uit.Data = table((1:3)', [1;2;3], [2;3;1], [0.1;0.2;0.3], 'VariableNames', {'ID','起点','终点','风阻'});
uit.Selection = [2 1]; % 选中第2行某单元格
deleted = gps.ui.delete_selected_rows_from_uitable(uit, 'reindexID', true, 'confirm', false);
disp(deleted);
```

---

### `gps.ui.clear_uitable`

文件：`General Problem Solver/+gps/+ui/clear_uitable.m`

签名：
```matlab
success = gps.ui.clear_uitable(uitableHandle, options)
```

作用：
- 清空 `UITable` 数据（保留列结构），可选确认弹窗

独立调用示例：
```matlab
fig = uifigure;
uit = uitable(fig);
uit.Data = table((1:2)', [1;2], [2;3], [0.1;0.2], 'VariableNames', {'ID','起点','终点','风阻'});
ok = gps.ui.clear_uitable(uit, 'confirm', false);
disp(ok);
```

---

## `gps.data`（离线数据加载）

### `gps.data.load_network_data`

文件：`General Problem Solver/+gps/+data/load_network_data.m`

签名：
```matlab
[Branches, Boundary, SolverOptions] = gps.data.load_network_data(data_dir)
```

作用：
- 从一个数据目录读取 `branches.csv`、`boundary.csv`（必需）以及 `solver_config.csv`（可选）
- 解析后输出 `Branches/Boundary/SolverOptions` 结构，便于命令行/脚本方式直接调用求解器

相关模板文件：
- `General Problem Solver/+gps/+data/branches_template.csv`
- `General Problem Solver/+gps/+data/boundary_template.csv`
- `General Problem Solver/+gps/+data/solver_config_template.csv`

CSV 格式摘要与示例请优先参考：[OutAppUse.md](OutAppUse.md)。

独立调用示例：
```matlab
addpath('General Problem Solver');
[Branches, Boundary, SolverOptions] = gps.data.load_network_data("my_network_dir/");
[Q, Results] = gps.logic.ventilation_network_solver_generic(Branches, Boundary, SolverOptions);
```

---

## App（入口）

- 主界面：`General Problem Solver/ui/NetworkSolverApp.mlapp`
- 导出的类文件（自动生成/便于版本管理）：`General Problem Solver/ui/NetworkSolverApp_exported.m`、`General Problem Solver/ui/NetworkSolverApp_exported_v1_1_0.m`
