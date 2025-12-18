function [Q, iterations] = ventilation_network_solver(R, Q_total)
% 用 Hardy Cross 回路迭代解算固定 8 巷道网络
% 输入：R(1×8) 风阻系数（正），Q_total 总风量（正）
% 输出：Q(1×8) 风量（相对约定方向，可为负），iterations 迭代次数
%
% 版本：
%   v1.0 (2025-12-18) - 初始版本
%
% 作者：东北大学 资源与土木工程学院 智采2201班 学生

    % 输入校验
    R = R(:).'; % 统一为行向量

    if numel(R) ~= 8
        error('ventilation_network_solver:InvalidInput', ...
            '风阻向量 R 必须包含 8 个元素（当前: %d）', numel(R));
    end

    if any(~isfinite(R)) || any(R <= 0)
        error('ventilation_network_solver:InvalidInput', ...
            '所有风阻值必须为有限正数');
    end

    if ~isscalar(Q_total) || ~isfinite(Q_total) || Q_total <= 0
        error('ventilation_network_solver:InvalidInput', ...
            '入口总风量 Q_total 必须为有限正数（当前: %.6g）', Q_total);
    end

    % 迭代控制
    max_iterations = 1000;
    tol_pressure   = 0.1;   % 回路压降残差容差 (Pa)
    tol_flow       = 1e-4;  % 风量相对变化容差
    omega          = 0.85;  % 欠松弛因子（0.5~1.0 之间常用）

    % 初值（满足节点连续方程）
    sqrt_R1 = sqrt(R(1));
    sqrt_R2 = sqrt(R(2));

    Q = zeros(1, 8);
    Q(1) = Q_total * sqrt_R2 / (sqrt_R1 + sqrt_R2);
    Q(2) = Q_total * sqrt_R1 / (sqrt_R1 + sqrt_R2);

    % 其余回路支路初始给 0
    Q(3) = 0.0;
    Q(6) = 0.0;

    % 按节点连续方程传播得到其余支路
    Q(4) = Q(1) + Q(3);
    Q(5) = Q(2) - Q(3);
    Q(7) = Q(4) + Q(6);
    Q(8) = Q(5) - Q(6);

    % 回路定义（按顺时针遍历，s 为方向系数）
    loop_branches{1} = [2 3 1];
    loop_signs{1}    = [ 1  1 -1];

    loop_branches{2} = [3 5 6 4];
    loop_signs{2}    = [-1  1  1 -1];

    loop_branches{3} = [6 8 7];
    loop_signs{3}    = [-1  1 -1];

    % Hardy Cross 迭代
    for iter = 1:max_iterations
        Q_old = Q;

        % 逐回路修正
        for k = 1:numel(loop_branches)
            idx = loop_branches{k};
            s   = loop_signs{k};

            % Δp = R*Q*|Q|
            h = R(idx) .* Q(idx) .* abs(Q(idx));
            numerator = sum(s .* h);

            % d(Δp)/dQ = 2*R*|Q|（平滑避免除零）
            q_abs = abs(Q(idx));
            q_smooth = sqrt(q_abs.^2 + 1e-10);
            denom = sum(2 * R(idx) .* q_smooth);

            if denom < 1e-12
                delta_Q = 0.0;
            else
                delta_Q = -numerator / denom;
            end

            % Q <- Q + s*ΔQ（欠松弛）
            Q(idx) = Q(idx) + omega * s .* delta_Q;
        end

        % 用最新 Q 重新评估回路残差
        max_residual = 0.0;
        for k = 1:numel(loop_branches)
            idx = loop_branches{k};
            s   = loop_signs{k};
            h = R(idx) .* Q(idx) .* abs(Q(idx));
            residual_k = sum(s .* h);
            max_residual = max(max_residual, abs(residual_k));
        end

        max_change = max(abs(Q - Q_old));
        relative_change = max_change / (mean(abs(Q)) + 1e-12);

        if max_residual < tol_pressure && relative_change < tol_flow
            iterations = iter;
            return;
        end
    end

    iterations = max_iterations;
    warning('达到最大迭代次数 %d，可能未完全收敛', max_iterations);
end
