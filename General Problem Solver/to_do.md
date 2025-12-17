# 通用通风网络求解器（General Problem Solver）ToDo

目标：把当前“固定拓扑”的求解脚本扩展为**通用通风网络求解器**。用户通过可视化方式绘制网络（节点 + 分支），程序自动生成测试用输入文件，并为后续回路识别与通用迭代求解做好数据结构准备。

本阶段聚焦：**UI 输入页（网络绘制 + 参数录入 + 导出测试 v 文件）**。其余页面先做空白占位。

---

## 0) 约定：数据模型与文件输出

### 0.1 网络对象（内存结构 Net）

- `Net.Nodes`
  - `id`：节点编号（1..N）
  - `x, y`：画布坐标（用于可视化布局）
  - `name`：可选
- `Net.Branches`
  - `id`：分支编号（1..B）
  - `from`：起点节点 id
  - `to`：终点节点 id
  - `type`：分支类型（`internal` / `inlet` / `outlet`）
  - `R`：风阻（仅 `internal` 必填）
  - `Q_total`：总风量（仅 `inlet` 需要；建议作为**网络级参数**存储，避免多入口歧义）

> 说明：如果未来要支持多入口/多回风口，建议改为“边界节点/边界条件表”，此处先按单入口单回风的最小可用版本实现。

### 0.2 CSV 输出（用于后续算法与复现）

建议输出到 `General Problem Solver/output/`：

- `nodes.csv`
  - `node_id,x,y,name`
- `branches.csv`
  - `branch_id,from_node,to_node,type,R`
- `boundary.csv`（建议新增，避免在 branches 里混总风量）
  - `Q_total`

### 0.3 “测试 v 文件”（用于一键复现）

为避免歧义，建议把“测试 v 文件”定义为一个可直接运行的 MATLAB 脚本：

- `test_v_case.m`
  - 读取 `nodes.csv / branches.csv / boundary.csv`
  - 组装 `Net` 结构体
  -（后续阶段）调用通用求解器并绘图

---

## 1) UI 总体规划（先搭框架）

建议采用 MATLAB App Designer（`uifigure`）实现多页界面（`uitabgroup` 或侧边栏导航）：

- `输入页`（本阶段实现）
- `回路页`（占位）
- `求解页`（占位）
- `结果页`（占位）
- `设置页`（占位）

---

## 2) 输入页（核心）：可视化绘制网络 + 录入参数 + 导出

### 2.1 交互目标

- 用户在画布上“放置节点、连线成分支”以绘制网络图。
- 分支分三类：
  - **内部巷道（internal）**：选择/创建时必须输入风阻 `R`
  - **入风侧巷道（inlet）**：选择/创建时必须输入总风量 `Q_total`
  - **回风侧巷道（outlet）**：无额外输入
- 用户完成绘制后点击“导出”，自动生成：
  - `nodes.csv`、`branches.csv`、`boundary.csv`
  - `test_v_case.m`

### 2.2 页面布局建议

- 左侧：工具栏（模式切换）
  - `选择/移动`
  - `添加节点`
  - `添加分支`
  - `删除`
  - `撤销/重做`（可选）
- 中间：画布（网络绘制区域）
  - 节点：圆点 + 编号标签
  - 分支：连线 + 分支编号；可用颜色区分类型
    - internal：黑色
    - inlet：蓝色
    - outlet：红色
- 右侧：属性面板（Inspector）
  - 选中节点：显示 `id,name,x,y`
  - 选中分支：显示 `id,from,to,type`，并按类型显示/隐藏参数输入框

### 2.3 关键交互细节（建议明确成规则）

#### 2.3.1 添加节点

- 单击画布新增节点；自动分配 `id = max(id)+1`
- 支持拖拽移动节点（更新 `x,y`）
- 支持重命名（可选）

#### 2.3.2 添加分支

- 进入“添加分支”模式后：
  1. 点击起点节点
  2. 点击终点节点
  3. 弹出“分支类型选择”对话框：`internal / inlet / outlet`
  4. 按类型弹出参数输入：
     - internal：输入 `R`（正数）
     - inlet：输入 `Q_total`（正数；建议写入 `Net.Q_total`，并同步到 `boundary.csv`）
     - outlet：无输入

建议规则：
- 同一网络只允许 **1 条 inlet 分支**与 **1 条 outlet 分支**（MVP）。若用户尝试新增第二条：
  - 给出提示：请先删除已有 inlet/outlet 或升级到多边界版本
- 分支方向（from/to）由用户点击顺序决定；若未来需要自动方向，可再增加“翻转方向”按钮。

#### 2.3.3 编辑分支参数

- 选中分支后可在右侧属性栏编辑：
  - internal：`R`
  - inlet：`Q_total`
  - outlet：无
- 输入校验：
  - `R > 0`
  - `Q_total > 0`

#### 2.3.4 删除与校验

- 删除节点：同时删除与其相连的分支（并提示）
- 删除分支：直接删除
- 导出前校验（最小集）：
  - 至少 2 个节点、至少 1 条分支
  - 恰好 1 条 inlet 与 1 条 outlet（按 MVP 约束）
  - 网络连通（忽略方向）
  - internal 分支的 `R` 已填写
  - inlet 的 `Q_total` 已填写

### 2.4 导出行为（生成测试输入文件）

点击“导出/生成测试 v 文件”后：

1. 创建/覆盖目录：`General Problem Solver/output/`
2. 写出：
   - `nodes.csv`
   - `branches.csv`
   - `boundary.csv`
3. 写出 `test_v_case.m`，内容包括：
   - 读取 CSV
   - 组装 `Net`
   - 打印基本信息（节点数、分支数、Q_total）
   -（后续阶段）预留调用 `parse/solve/plot` 的入口

---

## 3) 后续阶段（先占位，不在本轮实现）

### 3.1 最小回路/独立回路检索

- 从 `branches.csv` 构建图
- 输出回路矩阵 `B (M×B)`，元素为 `{−1,0,+1}`
- 作为 Hardy Cross 通用回路迭代的输入

### 3.2 通用迭代算法

先实现通用 Hardy Cross（回路法），再扩展 Newton-Raphson（节点压法）。

### 3.3 主流程与可视化

- `main_generic.m`：端到端读取 → 回路 → 求解 → 导出 → 绘图

---

## 4) 输入页交付物清单（本阶段）

- `ui_input_page.mlapp`（或等价脚本版 `ui_input_page.m`）
- `export_network_to_csv.m`（导出工具）
- `write_test_v_case.m`（生成 `test_v_case.m`）
- `General Problem Solver/output/`（导出目录，运行时生成）

