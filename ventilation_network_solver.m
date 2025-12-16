% 通风网络Hardy Cross迭代法求解器
% 根据图5.2所示的通风网络，求解各巷道风量
%
% 输入：
%   R: 各巷道风阻向量 (1x8)
%   Q_total: 总风量
% 输出：
%   Q: 各巷道风量 (1x8)
%   iterations: 实际迭代次数

function [Q, iterations] = ventilation_network_solver(R, Q_total)
    % 参数设置
    max_iterations = 1000;  % 最大迭代次数
    tolerance = 0.001;       % 残差容许值

    % 初始化巷道风量 (根据网络拓扑结构初始估计)
    % 巷道编号: 1, 2, 3, 4, 5, 6, 7, 8
    Q = zeros(1, 8);

    % 初始风量估计 (简单平均分配)
    Q(1) = Q_total;      % 巷道1：入口
    Q(2) = Q_total/2;    % 巷道2
    Q(3) = Q_total/2;    % 巷道3
    Q(4) = Q_total/2;    % 巷道4
    Q(5) = Q_total/2;    % 巷道5
    Q(6) = Q_total/2;    % 巷道6
    Q(7) = Q_total/2;    % 巷道7
    Q(8) = Q_total;      % 巷道8：出口

    % 定义回路 (根据网络图)
    % 回路I: 巷道 1-2-3
    % 回路II: 巷道 3-4-6-5
    % 回路III: 巷道 6-7-8

    % 回路定义矩阵 (正值表示顺时针，负值表示逆时针)
    % 每行代表一个回路，列代表巷道编号
    loops = [
        1, -2, -3, 0,  0,  0,  0,  0;  % 回路I
        0,  0,  3, -4, 5,  -6, 0,  0;  % 回路II
        0,  0,  0, 0,  0,  6,  -7, -8  % 回路III
    ];

    num_loops = size(loops, 1);

    % Hardy Cross 迭代
    for iter = 1:max_iterations
        delta_Q = zeros(num_loops, 1);  % 各回路的修正量
        max_residual = 0;                % 最大残差

        % 对每个回路计算修正量
        for loop = 1:num_loops
            numerator = 0;      % 分子: sum(R*Q*|Q|)
            denominator = 0;    % 分母: sum(2*R*|Q|)

            for branch = 1:8
                if loops(loop, branch) ~= 0
                    % 获取该巷道在回路中的方向
                    direction = sign(loops(loop, branch));
                    Q_branch = Q(branch) * direction;

                    % 计算压降和阻力项
                    pressure_drop = R(branch) * Q_branch * abs(Q_branch);
                    resistance_term = 2 * R(branch) * abs(Q_branch);

                    numerator = numerator + pressure_drop;
                    denominator = denominator + resistance_term;
                end
            end

            % 计算修正量
            if denominator ~= 0
                delta_Q(loop) = -numerator / denominator;
            else
                delta_Q(loop) = 0;
            end

            % 更新最大残差
            max_residual = max(max_residual, abs(numerator));
        end

        % 修正各巷道风量
        for loop = 1:num_loops
            for branch = 1:8
                if loops(loop, branch) ~= 0
                    direction = sign(loops(loop, branch));
                    Q(branch) = Q(branch) + direction * delta_Q(loop);
                end
            end
        end

        % 检查收敛性
        if max_residual < tolerance
            iterations = iter;
            fprintf('迭代收敛！迭代次数: %d\n', iterations);
            fprintf('最大残差: %.6f\n', max_residual);
            return;
        end
    end

    % 未收敛
    iterations = max_iterations;
    fprintf('警告: 达到最大迭代次数 %d，未完全收敛\n', max_iterations);
    fprintf('当前最大残差: %.6f\n', max_residual);
end
