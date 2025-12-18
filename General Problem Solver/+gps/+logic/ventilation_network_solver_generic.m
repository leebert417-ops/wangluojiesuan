function [Q, Results] = ventilation_network_solver_generic(Branches, Boundary, SolverOptions)
% 通用通风网络求解器（Hardy Cross），边界采用"入/回风节点"
%
% Branches（必需字段）：
%   .id        (B×1) 分支编号（要求为 1..B）
%   .from_node (B×1) 起点节点（定义分支正方向）
%   .to_node   (B×1) 终点节点
%   .R         (B×1) 风阻系数（正数）
%
% Boundary（必需字段）：
%   .inlet_node  (标量或向量) 入风节点编号
%   .outlet_node (标量或向量) 回风节点编号
%   .Q_total     (标量) 系统总风量（m^3/s）
%
% SolverOptions（可选字段）：
%   .max_iter    最大迭代次数（默认 1000）
%   .tolerance   收敛容差（默认 1e-3）
%   .relaxation  欠松弛系数（默认 1.0）
%   .verbose     是否打印信息（默认 true）
%
% 版本：
%   v1.0 (2025-12-18) - 初始版本
%
% 作者：东北大学 资源与土木工程学院 智采2201班 学生

    if nargin < 2
        error('至少需要提供 Branches 和 Boundary');
    end

    if nargin < 3 || isempty(SolverOptions)
        SolverOptions = struct();
    end
    if ~isfield(SolverOptions, 'max_iter');   SolverOptions.max_iter = 1000; end
    if ~isfield(SolverOptions, 'tolerance');  SolverOptions.tolerance = 1e-3; end
    if ~isfield(SolverOptions, 'relaxation'); SolverOptions.relaxation = 1.0; end
    if ~isfield(SolverOptions, 'verbose');    SolverOptions.verbose = true; end

    B = length(Branches.id);
    if ~isequal(sort(Branches.id(:)), (1:B)')
        error('Branches.id 必须为 1..B 的连续编号');
    end

    R = Branches.R(:);
    if any(~isfinite(R)) || any(R <= 0)
        error('风阻系数 R 必须为有限正数');
    end

    N = max([Branches.from_node(:); Branches.to_node(:)]);
    if N < 2
        error('节点数过少');
    end

    if ~isfield(Boundary, 'Q_total') || ~isscalar(Boundary.Q_total) || ~isfinite(Boundary.Q_total) || Boundary.Q_total <= 0
        error('Boundary.Q_total 必须为有限正数');
    end

    if ~isfield(Boundary, 'inlet_node') || ~isfield(Boundary, 'outlet_node')
        error('Boundary 必须包含 inlet_node 与 outlet_node');
    end
    inlet_node  = unique(Boundary.inlet_node(:));
    outlet_node = unique(Boundary.outlet_node(:));
    if any(inlet_node < 1) || any(inlet_node > N) || any(outlet_node < 1) || any(outlet_node > N)
        error('入/回风节点编号超出范围 1..%d', N);
    end
    if any(ismember(inlet_node, outlet_node))
        error('入风节点与回风节点不能重叠');
    end

    % 连通性检查（无向）
    edges = [Branches.from_node(:), Branches.to_node(:)];
    G = graph(edges(:, 1), edges(:, 2));
    bins = conncomp(G);
    if max(bins) > 1
        error('网络不连通：存在 %d 个连通分量', max(bins));
    end

    % 构造节点注入向量 b：A*Q = b（A 为节点-分支关联矩阵）
    b = zeros(N, 1);
    b(inlet_node)  = +Boundary.Q_total / numel(inlet_node);
    b(outlet_node) = -Boundary.Q_total / numel(outlet_node);
    if abs(sum(b)) > 1e-9 * max(1, Boundary.Q_total)
        error('边界条件不守恒：sum(b) != 0');
    end

    A = incidence_matrix(Branches, N, B);

    % 初始可行流：求一个满足 A*Q=b 的最小范数解（删去一行避免奇异）
    Q = feasible_initial_flow(A, b);

    % 自动识别独立回路
    if SolverOptions.verbose
        fprintf('========================================\n');
        fprintf(' 通用通风网络求解器（Hardy Cross）\n');
        fprintf('========================================\n');
        fprintf('  节点数 N = %d\n', N);
        fprintf('  分支数 B = %d\n', B);
        fprintf('  总风量 Q_total = %.6g\n', Boundary.Q_total);
        fprintf('========================================\n\n');
    end

    [LoopMatrix, LoopInfo] = gps.logic.identify_fundamental_loops(Branches, SolverOptions.verbose);
    M = size(LoopMatrix, 1);

    max_iter = SolverOptions.max_iter;
    tol = SolverOptions.tolerance;
    omega = SolverOptions.relaxation;
    residual_history = zeros(max_iter, 1);
    converged = false;

    for iter = 1:max_iter
        Q_old = Q;

        for k = 1:M
            s_k = LoopMatrix(k, :)';   % (B×1)
            idx = find(s_k ~= 0);

            dp = R(idx) .* Q(idx) .* abs(Q(idx));         % Δp_i = R_i*Q_i*|Q_i|
            numerator = sum(s_k(idx) .* dp);              % Σ(s_i*Δp_i)

            q_abs_safe = max(abs(Q(idx)), 1e-6);
            denominator = sum(2 * R(idx) .* q_abs_safe);  % Σ(2R|Q|)

            if abs(denominator) > 1e-12
                delta_Q = -numerator / denominator;
            else
                delta_Q = 0.0;
            end

            Q = Q + omega * s_k * delta_Q;
        end

        % 用最新 Q 计算回路残差（避免耦合导致“虚假收敛”）
        dp_all = R .* Q .* abs(Q);
        loop_residual = LoopMatrix * dp_all;
        max_residual = max(abs(loop_residual));

        max_change = max(abs(Q - Q_old));
        residual_history(iter) = max_residual;

        if max_residual < tol && max_change < tol
            converged = true;
            break;
        end

        if SolverOptions.verbose && mod(iter, 10) == 0
            fprintf('  迭代 %4d | 最大回路残差= %10.6f | 最大风量变化= %10.6f\n', iter, max_residual, max_change);
        end
    end

    if ~converged
        warning('未在 %d 次迭代内收敛（最大回路残差= %.6f）', max_iter, max_residual);
        iter = max_iter;
    end

    Results = struct();
    Results.iterations = iter;
    Results.converged = converged;
    Results.LoopMatrix = LoopMatrix;
    Results.pressure_diff_signed = R .* Q .* abs(Q);
    Results.pressure_diff_abs = R .* (abs(Q) .^ 2);
    Results.max_residual = max_residual;
    Results.residual_history = residual_history(1:iter);
    Results.node_residual = A * Q - b;
    Results.network_info = struct('N', N, 'B', B, 'M', M);
    if exist('LoopInfo', 'var')
        Results.LoopInfo = LoopInfo;
    end

    if SolverOptions.verbose
        fprintf('========================================\n');
        fprintf('  收敛状态: %d\n', converged);
        fprintf('  迭代次数: %d\n', iter);
        fprintf('  最大回路残差: %.6f\n', max_residual);
        fprintf('  最大节点残差: %.6e\n', max(abs(Results.node_residual)));
        fprintf('========================================\n\n');
    end
end


function A = incidence_matrix(Branches, N, B)
    A = zeros(N, B);
    for e = 1:B
        u = Branches.from_node(e);
        v = Branches.to_node(e);
        A(u, e) = A(u, e) + 1;
        A(v, e) = A(v, e) - 1;
    end
end


function Q0 = feasible_initial_flow(A, b)
    if size(A, 1) ~= numel(b)
        error('A 与 b 尺寸不匹配');
    end

    % 去掉一行（参考节点）以避免 A*A' 奇异
    A_red = A(2:end, :);
    b_red = b(2:end);
    M = A_red * A_red';
    if rcond(M) < 1e-12
        error('网络关联矩阵奇异，无法生成可行初始流');
    end
    Q0 = A_red' * (M \ b_red);

    if norm(A * Q0 - b, inf) > 1e-6 * max(1, norm(b, inf))
        error('无法构造满足节点守恒的初始流（请检查网络连通性与边界条件）');
    end
end
