% 通风网络Hardy Cross迭代法求解器
% 根据《矿井通风网络解算》讲义方法实现
%
% 网络拓扑（8巷道6节点）：
%   巷道1: 节点1→节点2
%   巷道2: 节点1→节点3
%   巷道3: 节点2→节点3 (对角巷道)
%   巷道4: 节点2→节点4
%   巷道5: 节点3→节点5
%   巷道6: 节点4→节点5
%   巷道7: 节点4→节点6
%   巷道8: 节点5→节点6
%   边界：入风处→节点1(Q_total), 节点6→回风处(Q_total)
%
% 独立回路数：M = N - J + 1 = 8 - 6 + 1 = 3
%
% 输入：
%   R: 各巷道风阻向量 (1x8)
%   Q_total: 总风量
% 输出：
%   Q: 各巷道风量 (1x8)
%   iterations: 实际迭代次数

function [Q, iterations] = ventilation_network_solver(R, Q_total)
    % 参数设置
    max_iterations = 1000;
    tolerance = 0.001;

    % 步骤1：初始假设 - 假设对角巷道3无风流
    Q = zeros(1, 8);
    Q(3) = 0;  % 对角巷道初始为0

    % 根据流量守恒初始化其他巷道
    Q(1) = Q_total * 0.5;
    Q(2) = Q_total * 0.5;
    Q(4) = Q(1);  % 节点2守恒
    Q(5) = Q(2);  % 节点3守恒
    Q(6) = Q(4) * 0.5;
    Q(7) = Q(4) * 0.5;
    Q(8) = Q(5) + Q(6);

    % 步骤2：确定独立回路和k系数
    % 对角巷道的方向系数k（根据风阻比判断）
    % 如果 R1/R4 > R2/R5，则k_I=1, k_II=-1 (风流3→2)
    % 如果 R1/R4 = R2/R5，则k_I=0, k_II=0  (无风流)
    % 如果 R1/R4 < R2/R5，则k_I=-1, k_II=1 (风流2→3)

    ratio1 = R(1) / R(4);
    ratio2 = R(2) / R(5);

    if abs(ratio1 - ratio2) < 1e-6
        k_I = 0;
        k_II = 0;
    elseif ratio1 > ratio2
        k_I = 1;   % 对角巷道在回路I中顺时针
        k_II = -1; % 对角巷道在回路II中逆时针
    else
        k_I = -1;  % 对角巷道在回路I中逆时针
        k_II = 1;  % 对角巷道在回路II中顺时针
    end

    % 定义三个独立回路
    % 回路I: 1-2-3 (包含对角巷道3)
    % 回路II: 3-4-5-6 (包含对角巷道3)
    % 回路III: 6-7-8 (不含对角巷道)

    % Hardy Cross 迭代
    for iter = 1:max_iterations
        % 保存旧值用于收敛判断
        Q_old = Q;

        % 回路I: 巷道1-巷道2-巷道3
        % 方程: -h1 + h2 + k_I*h3 = 0
        numerator_I = -R(1)*Q(1)*abs(Q(1)) + R(2)*Q(2)*abs(Q(2)) + k_I*R(3)*Q(3)*abs(Q(3));
        denominator_I = 2*R(1)*abs(Q(1)) + 2*R(2)*abs(Q(2)) + 2*R(3)*abs(Q(3));

        if abs(denominator_I) > 1e-10
            delta_Q_I = -numerator_I / denominator_I;
        else
            delta_Q_I = 0;
        end

        % 回路II: 巷道3-巷道4-巷道5-巷道6
        % 注意：这里需要考虑k_II和巷道连接关系
        numerator_II = k_II*R(3)*Q(3)*abs(Q(3)) - R(4)*Q(4)*abs(Q(4)) - R(5)*Q(5)*abs(Q(5)) + R(6)*Q(6)*abs(Q(6));
        denominator_II = 2*R(3)*abs(Q(3)) + 2*R(4)*abs(Q(4)) + 2*R(5)*abs(Q(5)) + 2*R(6)*abs(Q(6));

        if abs(denominator_II) > 1e-10
            delta_Q_II = -numerator_II / denominator_II;
        else
            delta_Q_II = 0;
        end

        % 回路III: 巷道6-巷道7-巷道8
        numerator_III = R(6)*Q(6)*abs(Q(6)) - R(7)*Q(7)*abs(Q(7)) - R(8)*Q(8)*abs(Q(8));
        denominator_III = 2*R(6)*abs(Q(6)) + 2*R(7)*abs(Q(7)) + 2*R(8)*abs(Q(8));

        if abs(denominator_III) > 1e-10
            delta_Q_III = -numerator_III / denominator_III;
        else
            delta_Q_III = 0;
        end

        % 修正风量（按照PDF的方法）
        Q(1) = Q(1) - delta_Q_I;
        Q(2) = Q(2) + delta_Q_I;
        Q(3) = Q(3) + k_I*delta_Q_I + k_II*delta_Q_II;
        Q(4) = Q(4) - delta_Q_II;
        Q(5) = Q(5) - delta_Q_II;
        Q(6) = Q(6) + delta_Q_II + delta_Q_III;
        Q(7) = Q(7) - delta_Q_III;
        Q(8) = Q(8) - delta_Q_III;

        % 归一化：确保 Q(1) + Q(2) = Q_total
        scale = Q_total / (Q(1) + Q(2));
        Q = Q * scale;

        % 检查收敛性
        max_residual = max([abs(numerator_I), abs(numerator_II), abs(numerator_III)]);
        max_change = max(abs(Q - Q_old));

        if max_residual < tolerance && max_change < tolerance
            iterations = iter;
            fprintf('迭代收敛！迭代次数: %d\n', iterations);
            fprintf('最大残差: %.6f\n', max_residual);
            fprintf('对角巷道系数: k_I=%d, k_II=%d\n', k_I, k_II);
            return;
        end
    end

    % 未收敛
    iterations = max_iterations;
    fprintf('警告: 达到最大迭代次数 %d，未完全收敛\n', max_iterations);
    fprintf('当前最大残差: %.6f\n', max_residual);
end
