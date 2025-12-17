# 通风网络 Hardy Cross 求解（图 5.2 对角巷道角联网路）

## 功能

- 读取 `network_data.csv` 的 8 条巷道风阻 `R`
- 使用 Hardy Cross 回路迭代求解巷道风量 `Q`
- 输出 `ventilation_results.csv`（中文表头）
- 生成 `ventilation_network_results.png`（两张柱状图：`|Q|` 与 `|Δp|`）

## 原理

- 风压差（沿巷道约定方向）：`Δp_i = R_i * Q_i * |Q_i|`
- 回路平衡：对每个独立回路满足 `Σ(s_i * Δp_i) = 0`，其中 `s_i ∈ {+1,-1}` 由回路遍历方向与巷道约定方向一致/相反决定
- Hardy Cross 修正量：

  $$\Delta Q_k = -\frac{\sum_i s_{ki}\,\Delta p_i}{\sum_i 2R_i\,\lvert Q_i\rvert}$$

  $$Q_i \leftarrow Q_i + s_{ki}\,\Delta Q_k$$

## 用法

1. 修改输入：编辑 `network_data.csv` 的 `resistance`；如需修改总风量，编辑 `main_script.m` 的 `Q_total`
2. 在 MATLAB 运行：

   ```matlab
   main_script
   ```

3. 查看输出：
   - `ventilation_results.csv`
   - `ventilation_network_results.png`
