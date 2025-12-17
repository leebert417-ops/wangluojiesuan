# 通风网络 Hardy Cross 求解（图 5.2 对角巷道角联网路）

## 项目作用

本项目用于对教材图 5.2 所示的 6 节点、8 巷道通风网络进行数值解算：在给定各巷道风阻 `R` 与入口总风量 `Q_total` 的条件下，采用 **Hardy Cross 回路迭代法**求解各巷道风量 `Q(i)`，并输出压降与物理校核结果。

## 建模思路

### 1) 巷道方向与符号约定

风量 `Q(i)` 以预设巷道方向为正，若计算结果为负，表示实际风流方向与约定方向相反。

巷道方向约定如下（与 `ventilation_network_solver.m` 一致）：

1. 巷道 1：`1 → 2`
2. 巷道 2：`1 → 3`
3. 巷道 3：`3 → 2`（下部联络巷道）
4. 巷道 4：`2 → 4`
5. 巷道 5：`3 → 5`
6. 巷道 6：`5 → 4`（中部联络巷道）
7. 巷道 7：`4 → 6`
8. 巷道 8：`5 → 6`

节点含义：节点 1 为入口，节点 6 为回风口。

### 2) 物理方程

- **Atkinson 阻力定律（压降）**  
  `H_i = R_i * Q_i * |Q_i|`

- **节点流量守恒（质量守恒）**  
  对各节点满足“流入 = 流出”。本网络在脚本中用于校核的节点方程为：
  - 节点 1：`Q1 + Q2 = Q_total`
  - 节点 2：`Q1 + Q3 = Q4`
  - 节点 3：`Q2 = Q3 + Q5`
  - 节点 4：`Q4 + Q6 = Q7`
  - 节点 5：`Q5 = Q6 + Q8`
  - 节点 6：`Q7 + Q8 = Q_total`

- **回路压降平衡（能量守恒）**  
  独立回路满足 `Σ(±H_i) = 0`，符号由回路方向与巷道方向一致/相反决定。

### 3) 求解算法（Hardy Cross）

对每个独立回路 `k` 计算回路压降闭合差并修正风量：

- 回路风量修正量：  
  `ΔQ_k = - Σ(s_ki * H_i) / Σ(2 * R_i * |Q_i|)`

- 巷道风量修正：  
  `Q_i ← Q_i + s_ki * ΔQ_k`

其中 `s_ki` 为巷道 `i` 在回路 `k` 中的方向符号（+1/-1）。每轮回路修正后，脚本会按 `Q1 + Q2 = Q_total` 对全网风量做一次比例归一化，防止数值漂移。

## 文件说明

- `main_script.m`：主脚本，读取输入、调用求解器、输出 CSV、生成可视化并做节点/回路校核。
- `ventilation_network_solver.m`：Hardy Cross 求解器实现（含回路定义与方向符号）。
- `network_data.csv`：输入风阻数据。
- 输出文件：
  - `ventilation_results.csv`：各巷道风量结果表。
  - `ventilation_network_results.png`：风量/压降柱状图 + 拓扑示意图 + 求解摘要。

## 使用方法

1. 修改输入数据：
   - 编辑 `network_data.csv` 中各巷道的 `resistance`（风阻）；
   - 如需修改入口总风量，编辑 `main_script.m` 中的 `Q_total`。
2. 在 MATLAB 中运行：

   ```matlab
   main_script
   ```

3. 查看输出：
   - `ventilation_results.csv`
   - `ventilation_network_results.png`

## 输入数据格式

`network_data.csv` 为带表头的 CSV，示例：

```text
branch,resistance
1,0.1
2,0.2
...
8,0.12
```

> 当前工程默认该网络为 8 条巷道；若更改网络规模，需要同步修改 `ventilation_network_solver.m` 的回路与拓扑定义。
