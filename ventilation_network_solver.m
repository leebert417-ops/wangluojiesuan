% 通风网络 Hardy Cross 迭代求解器
% --------------------------------
% 拓扑结构（与图 5.2 一致，6 个节点，8 条巷道）：
%   节点 1：底部入口
%   节点 2：右下
%   节点 3：左下
%   节点 4：右上
%   节点 5：左上
%   节点 6：顶部回风口
%
% 巷道方向约定（正向 = 预期进风方向）：
%   1: 1 → 2   （下部右侧立井）
%   2: 1 → 3   （下部左侧立井）
%   3: 3 → 2   （下部对角巷道 / 水平联络道）
%   4: 2 → 4   （右侧中部立井）
%   5: 3 → 5   （左侧中部立井）
%   6: 5 → 4   （中部对角巷道 / 水平联络道）
%   7: 4 → 6   （右侧上部立井）
%   8: 5 → 6   （左侧上部立井）
%
% 阻力定律（Atkinson 定律）：
%   H_i = R_i * Q_i * |Q_i|
%
% Hardy Cross 回路迭代公式：
%   ΔQ_k = - Σ(s_ki * H_i) / Σ(2 * R_i * |Q_i|)
%   Q_i(new) = Q_i(old) + s_ki * ΔQ_k
%   其中 s_ki 为巷道 i 在回路 k 中沿回路方向的符号（+1/-1）。
%
% 输入:
%   R        1×8 向量，各巷道风阻
%   Q_total  标准入口总风量（m³/s），由节点 1 经网络流向节点 6
%
% 输出:
%   Q           1×8 向量，各巷道体积风量（按上面约定方向取正）
%   iterations  实际迭代次数

function [Q, iterations] = ventilation_network_solver(R, Q_total)
    %-----------------------------
    % 0. 迭代控制参数
    %-----------------------------
    max_iterations = 1000;
    tolerance      = 1e-3;   % 回路压降残差和风量改变量的收敛阈值

    %-----------------------------
    % 1. 初始风量估计（满足节点守恒）
    %-----------------------------
    % 设入口总风量 Q_total 从节点 1 分成两股：
    %   Q1 沿巷道 1：1→2
    %   Q2 沿巷道 2：1→3
    % 底部对角巷道 3、中部对角巷道 6 初值取 0，
    % 其余巷道由节点流量守恒关系给出。
    Q = zeros(1, 8);

    % 节点 1：Q1 + Q2 = Q_total
    Q(1) = 0.5 * Q_total;
    Q(2) = 0.5 * Q_total;

    % 巷道 3 初始无风
    Q(3) = 0.0;

    % 节点 2：Q1 + Q3 = Q4  ⇒  在 Q3=0 时 Q4 = Q1
    Q(4) = Q(1);

    % 节点 3：Q2 = Q3 + Q5  ⇒  在 Q3=0 时 Q5 = Q2
    Q(5) = Q(2);

    % 巷道 6 初始无风
    Q(6) = 0.0;

    % 节点 4：Q4 + Q6 = Q7  ⇒  在 Q6=0 时 Q7 = Q4
    Q(7) = Q(4);

    % 节点 5：Q5 = Q6 + Q8  ⇒  在 Q6=0 时 Q8 = Q5
    Q(8) = Q(5);

    %-----------------------------
    % 2. 定义独立回路及其方向符号
    %-----------------------------
    % 回路 I  ：1-2-3-1  （下部矩形）
    %   1: 1→2  （与回路方向一致）
    %   3: 3→2  （沿回路 2→3，方向相反）
    %   2: 1→3  （沿回路 3→1，方向相反）
    loop_branches{1} = [1 3 2];
    loop_signs{1}    = [ 1 -1 -1];

    % 回路 II ：2-4-5-3-2（中部大回路）
    %   4: 2→4  （与回路方向一致）
    %   6: 5→4  （沿回路 4→5，方向相反）
    %   5: 3→5  （沿回路 5→3，方向相反）
    %   3: 3→2  （与回路方向一致）
    loop_branches{2} = [4 6 5 3];
    loop_signs{2}    = [ 1 -1 -1  1];

    % 回路 III：4-6-5-4（上部矩形）
    %   7: 4→6  （与回路方向一致）
    %   8: 5→6  （沿回路 6→5，方向相反）
    %   6: 5→4  （与回路方向一致）
    loop_branches{3} = [7 8 6];
    loop_signs{3}    = [ 1 -1  1];

    %-----------------------------
    % 3. Hardy Cross 迭代
    %-----------------------------
    for iter = 1:max_iterations
        Q_old = Q;
        max_residual = 0.0;  % 记录本轮最大回路压降闭合差

        % 依次对三个独立回路进行修正
        for k = 1:numel(loop_branches)
            idx = loop_branches{k};   % 本回路涉及的巷道编号
            s   = loop_signs{k};      % 对应符号（+1/-1）

            % 各巷道压降 H_i = R_i * Q_i * |Q_i|
            H = R(idx) .* Q(idx) .* abs(Q(idx));

            % 回路压降闭合差（带符号）：Σ s_i * H_i
            numerator = sum(s .* H);

            % 斜率项：Σ 2 * R_i * |Q_i|
            % 若某条巷道风量接近 0，用一个很小的“等效风量”避免除以 0。
            denom = sum(2 * R(idx) .* max(abs(Q(idx)), 1e-6));

            if abs(denom) < 1e-12
                delta_Q = 0.0;
            else
                delta_Q = -numerator / denom;
            end

            % 沿回路方向修正各巷道风量
            Q(idx) = Q(idx) + s .* delta_Q;

            % 更新本轮最大回路残差
            max_residual = max(max_residual, abs(numerator));
        end

        % 入口节点 1 的总风量约束：Q1 + Q2 = Q_total
        % 为避免数值漂移，对全网风量做一次比例归一化。
        scale = Q_total / (Q(1) + Q(2));
        Q = Q * scale;

        % 计算本轮最大巷道风量改变量
        max_change = max(abs(Q - Q_old));

        % 收敛判据：回路压降残差和风量变化均小于给定容差
        if max_residual < tolerance && max_change < tolerance
            iterations = iter;
            fprintf('迭代收敛：迭代次数 = %d，最大回路残差 = %.6f\n', iterations, max_residual);
            return;
        end
    end

    % 如未在最大迭代次数内收敛，给出警告信息
    iterations = max_iterations;
    warning('达到最大迭代次数 %d，可能未完全收敛（最大回路残差 = %.6f）。', max_iterations, max_residual);
end
