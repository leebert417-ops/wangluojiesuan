# GPS 通风网络数据文件格式说明

## 概述

GPS（General Problem Solver）通风网络求解器使用三个 CSV 文件定义完整的网络数据：

1. **`branches.csv`** - 分支（巷道）定义文件（必需）
2. **`boundary.csv`** - 边界条件文件（必需）
3. **`solver_config.csv`** - 求解器配置文件（可选）

所有文件必须使用 **UTF-8 编码**，以 `#` 开头的行为注释行。

---

## 文件 1：branches.csv（分支数据）

### 格式

标准 CSV 表格格式，逗号分隔，第一行为表头。

### 列定义

| 列名 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `branch_id` | 正整数 | 分支唯一标识符，建议从1开始连续编号 | 1, 2, 3, ... |
| `from_node` | 正整数 | 起点节点编号 | 1 |
| `to_node` | 正整数 | 终点节点编号 | 2 |
| `resistance` | 正实数 | 风阻系数（单位：N·s²/m⁸）<br>应包含巷道长度、断面等因素的综合值 | 0.1 |

**注意**：所有列都是必需的，缺少任何一列将导致加载失败。

### 示例

```csv
branch_id,from_node,to_node,resistance
1,1,2,0.1
2,1,3,0.2
3,3,2,0.15
```

### 注意事项

- **分支方向**：`from_node → to_node` 定义了分支的正方向
- 求解结果的风量正负号基于此方向判断
- **风阻系数**：必须为正数，应该是考虑了巷道长度、断面积、摩擦系数等因素的综合值
- 节点编号建议从 1 开始

---

## 文件 2：boundary.csv（边界条件）

### 格式

键值对格式，每行一个参数，格式为：`参数名,参数值`

参数名不区分大小写。

### 必需参数

| 参数名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| `Q_TOTAL` | 正实数 | 系统总风量（单位：m³/s） | 100 |
| `INLET_NODE` | 整数列表 | 入风节点编号，多个用分号分隔 | 1 |
| `OUTLET_NODE` | 整数列表 | 回风节点编号，多个用分号分隔 | 6 |

### 示例

```csv
# 系统总风量
Q_TOTAL,100

# 入风节点
INLET_NODE,1

# 回风节点
OUTLET_NODE,6
```

### 注意事项

- 多个节点编号用**分号(;)**分隔
- 节点编号必须在网络节点范围内
- 支持多入口和多出口网络

---

## 文件 3：solver_config.csv（求解器配置）

### 格式

键值对格式，每行一个参数，格式为：`参数名,参数值`

**此文件为可选**，未提供时使用默认值。

### 可选参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `MAX_ITER` | 正整数 | 1000 | 最大迭代次数 |
| `TOLERANCE` | 正实数 | 0.001 | 收敛容差（Pa 和 m³/s） |
| `METHOD` | 字符串 | HardyCross | 求解方法（HardyCross 或 NewtonRaphson） |
| `VERBOSE` | 布尔值 | true | 是否显示详细信息（true/false 或 1/0） |
| `RELAXATION` | 正实数 | 1.0 | 松弛因子，范围 (0, 1]，用于改善收敛性 |

### 示例

```csv
# 最大迭代次数
MAX_ITER,1000

# 收敛容差
TOLERANCE,0.001

# 求解方法
METHOD,HardyCross

# 显示详细信息
VERBOSE,true

# 松弛因子（1.0 = 不使用松弛）
RELAXATION,1.0
```

### 注意事项

- 布尔值支持：`true`/`false` 或 `1`/`0`
- 松弛因子 < 1 可改善收敛性，但会降低收敛速度
- 如果不需要修改默认配置，可以省略此文件

---

## 使用示例

### 1. 准备数据文件

在项目目录下创建三个文件：
```
my_network/
├── branches.csv
├── boundary.csv
└── solver_config.csv  (可选)
```

### 2. 加载数据

在 MATLAB 中：

```matlab
% 加载网络数据
[Branches, Boundary, Options] = gps.data.load_network_data('./my_network/');

% 调用求解器
[Q, Results] = ventilation_network_solver_generic(Branches, Boundary, Options);
```

### 3. 使用模板文件

系统提供了三个模板文件：
- `+gps/+data/branches_template.csv`
- `+gps/+data/boundary_template.csv`
- `+gps/+data/solver_config_template.csv`

复制模板文件并修改为您的网络参数：

```bash
cp +gps/+data/branches_template.csv my_network/branches.csv
cp +gps/+data/boundary_template.csv my_network/boundary.csv
# 编辑文件...
```

---

## 数据校验

加载数据时，系统会自动执行以下校验：

✅ **分支数据校验**
- 分支编号连续性检查（非强制）
- 风阻系数为正数
- 节点编号从 1 开始

✅ **边界条件校验**
- 总风量为正数
- 入口/出口分支在 branches.csv 中存在

✅ **求解器配置校验**
- 参数类型正确
- 参数值在合理范围内

---

## 常见问题

### Q1：如何定义分支方向？

分支方向由 `from_node → to_node` 定义。求解结果：
- `Q > 0`：实际风向与定义方向一致
- `Q < 0`：实际风向与定义方向相反

### Q2：能否有多个入口或出口？

可以！在 `boundary.csv` 中用分号分隔多个节点编号：
```csv
INLET_NODE,1;2;3
OUTLET_NODE,7;8;9
```

### Q3：节点编号必须连续吗？

不强制要求，但建议从 1 开始连续编号以避免混淆。

### Q4：如何添加注释？

所有 CSV 文件都支持 `#` 开头的注释行：
```csv
# 这是一行注释
branch_id,from_node,to_node,resistance
1,1,2,0.1  # 行尾注释会被当作数据的一部分，不推荐
```

### Q5：CSV 文件编码问题？

必须使用 **UTF-8 编码**保存文件，否则中文会乱码。在记事本/VS Code 中保存时选择 UTF-8 编码。

---

## 技术支持

如有问题，请查阅：
- 示例文件：`+gps/+data/*_template.csv`
- 加载函数：`+gps/+data/load_network_data.m`
- 项目文档：`to_do.md`

---

**版本**：1.0
**日期**：2025-12-17
**作者**：MATLAB 通风工程专家助手
