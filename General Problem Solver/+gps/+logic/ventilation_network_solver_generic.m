function [Q, Results] = ventilation_network_solver_generic(Branches, Boundary, SolverOptions)
% 通用通风网络求解器（Hardy Cross），边界采用"入/回风节点"
%
% Branches（必需字段）：
%   .from_node (B×1) 起点节点（定义分支正方向）
%   .to_node   (B×1) 终点节点
%   .R         (B×1) 风阻系数（正数）
%   .id        (B×1, 可选) 分支编号/标签（建议唯一，用于展示与导出）
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
% 输出：
%   Q (B×1) 各分支风量（m^3/s），保留正负号（与输入 Branches 的正方向一致）
%
%   Results（结构体，常用字段）：
%     .converged      是否收敛（logical）
%     .iterations     迭代次数（double 标量）
%     .max_residual   最大回路残差（double 标量）
%     .residual_history 残差历史（iterations×1）
%     .LoopMatrix     基本回路矩阵（M×B）
%     .node_residual  节点守恒残差 A*Q-b（N×1）
%     .pressure_drop  各分支风压降（Pa，正值，B×1）
%     .network_info   网络规模信息（struct，含 N/B/M）
%     .LoopInfo       回路信息（可选，struct array）
%
%   Results（风向对齐字段，用于导出/可视化）：
%     .flow_reversed_mask        Q<0 的分支掩码（B×1 logical）
%     .Branches_flow_aligned     将 Q<0 分支起止点交换后的 Branches（struct）
%     .Q_flow_aligned            对齐后风量（B×1，非负）
%     .node_residual_flow_aligned 对齐后节点残差（N×1）
%
% 版本：
%   v1.1 (2025-12-20) - 增加风向对齐输出与正值压降
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

    if ~isfield(Branches, 'from_node') || ~isfield(Branches, 'to_node') || ~isfield(Branches, 'R')
        error('Branches 必须包含 from_node / to_node / R 字段');
    end

    from_node = Branches.from_node(:);
    to_node = Branches.to_node(:);
    R = Branches.R(:);

    B = numel(from_node);
    if numel(to_node) ~= B || numel(R) ~= B
        error('Branches 字段长度不一致：from_node/to_node/R 必须均为 B×1');
    end
    if B == 0
        error('网络分支数为 0');
    end

    if isfield(Branches, 'id')
        ids = Branches.id(:);
        if numel(ids) ~= B
            error('Branches.id 长度与分支数不一致');
        end
        if any(~isfinite(ids))
            error('Branches.id 必须为有限数值');
        end
        if numel(unique(ids)) ~= B
            error('Branches.id 必须唯一（存在重复分支编号/标签）');
        end
    end

    if any(~isfinite(R)) || any(R <= 0)
        error('风阻系数 R 必须为有限正数');
    end

    N = max([from_node; to_node]);
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
    edges = [from_node, to_node];
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

    % ========================================================================
    % 步骤 1：构造节点-分支关联矩阵 A (N×B)
    % ========================================================================
    % 物理含义：A 矩阵描述网络拓扑结构
    %   - A(i,j) = +1：分支 j 从节点 i 流出
    %   - A(i,j) = -1：分支 j 流入节点 i
    %   - A(i,j) = 0： 分支 j 与节点 i 无关
    % 基尔霍夫第一定律（节点流量守恒）表示为：A * Q = b
    A = incidence_matrix(Branches, N, B);

    % ========================================================================
    % 步骤 2：生成初始可行流
    % ========================================================================
    % 目标：找到一个满足节点守恒的初始风量分布 Q0，使得 A*Q0 = b
    % 方法：最小范数解（物理上相当于初始流场能量最小）
    % 注意：此时 Q0 不满足回路压力平衡，需要后续 Hardy Cross 迭代修正
    Q = feasible_initial_flow(A, b);

    % ========================================================================
    % 步骤 3：识别独立回路（基本回路）
    % ========================================================================
    % 物理背景：基尔霍夫第二定律要求每个回路的压力闭合（Σ ΔP = 0）
    % 数学原理：对于 N 节点、B 分支的连通图，独立回路数 M = B - N + 1
    % LoopMatrix (M×B)：每行代表一个回路，元素值为 +1/-1/0（表示分支在回路中的方向）
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
    M = size(LoopMatrix, 1);  % 独立回路数量

    % ========================================================================
    % 步骤 4：Hardy Cross 迭代求解
    % ========================================================================
    % 算法原理：
    %   通过逐回路修正风量，使得所有回路满足压力平衡（基尔霍夫第二定律）
    %   同时保持节点流量守恒（基尔霍夫第一定律）
    %
    % 修正公式推导：
    %   对于回路 k，压力闭合差为 F_k = Σ(s_i * R_i * Q_i * |Q_i|)
    %   设修正量为 ΔQ，则 F_k(Q + ΔQ*s_k) ≈ F_k(Q) + (∂F_k/∂Q)*ΔQ = 0
    %   求解得：ΔQ = -F_k / (∂F_k/∂Q) = -Σ(s_i*R_i*Q_i*|Q_i|) / Σ(2*R_i*|Q_i|)
    %
    max_iter = SolverOptions.max_iter;
    tol = SolverOptions.tolerance;
    omega = SolverOptions.relaxation;  % 欠松弛系数（提高稳定性）
    residual_history = zeros(max_iter, 1);
    converged = false;

    for iter = 1:max_iter
        Q_old = Q;  % 保存上一步风量（用于计算变化量）

        % ====================================================================
        % 4.1 逐回路修正（Gauss-Seidel 风格：立即使用更新后的 Q）
        % ====================================================================
        for k = 1:M
            % 提取回路 k 的拓扑向量
            s_k = LoopMatrix(k, :)';   % (B×1)：+1=顺回路方向, -1=逆回路方向, 0=不在回路中
            idx = find(s_k ~= 0);      % 回路 k 包含的分支索引

            % ----------------------------------------------------------------
            % 4.1.1 计算回路压力闭合差（基尔霍夫第二定律）
            % ----------------------------------------------------------------
            % Atkinson 阻力定律：Δp_i = R_i * Q_i * |Q_i|（带符号的压降）
            dp = R(idx) .* Q(idx) .* abs(Q(idx));

            % 回路压力闭合差（理想情况应为 0）
            % numerator = Σ(s_i * Δp_i)：顺回路方向累加压降
            numerator = sum(s_k(idx) .* dp);

            % ----------------------------------------------------------------
            % 4.1.2 计算修正量分母（雅可比矩阵对角项）
            % ----------------------------------------------------------------
            % 物理含义：∂(Δp_i)/∂Q_i = 2*R_i*|Q_i|（对 Q 的导数）
            % 注意：当 Q_i 接近 0 时需要加小量避免除零
            q_abs_safe = max(abs(Q(idx)), 1e-6);
            denominator = sum(2 * R(idx) .* q_abs_safe);

            % ----------------------------------------------------------------
            % 4.1.3 计算风量修正量（Newton-Raphson 公式）
            % ----------------------------------------------------------------
            if abs(denominator) > 1e-12
                delta_Q = -numerator / denominator;  % Hardy Cross 修正公式
            else
                delta_Q = 0.0;  % 回路退化（如所有分支 R→0），跳过修正
            end

            % ----------------------------------------------------------------
            % 4.1.4 更新回路中所有分支的风量
            % ----------------------------------------------------------------
            % 关键：s_k * delta_Q 确保顺回路方向的分支增加 delta_Q，逆向减少
            % omega 为欠松弛系数：< 1 提高稳定性，= 1 为标准 Hardy Cross
            Q = Q + omega * s_k * delta_Q;
        end

        % ====================================================================
        % 4.2 收敛性判断
        % ====================================================================
        % 用最新 Q 重新计算所有回路的压力残差（避免回路耦合导致"虚假收敛"）
        dp_all = R .* Q .* abs(Q);              % 所有分支的压力损失
        loop_residual = LoopMatrix * dp_all;    % 各回路的压力闭合差 (M×1)
        max_residual = max(abs(loop_residual)); % 最大回路残差（收敛指标1）

        max_change = max(abs(Q - Q_old));       % 最大风量变化（收敛指标2）
        residual_history(iter) = max_residual;

        % 双重收敛准则：
        %   1. 所有回路压力闭合（max_residual < tol）
        %   2. 风量不再显著变化（max_change < tol）
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
    Results.pressure_drop = R .* (abs(Q) .^ 2);

    % ====================================================================
    % 后处理：将“实际风向”统一为正向（Q >= 0），并同步修正起止点
    % ====================================================================
    % 约定：
    %   - 原始输出 Q 仍保留正负号（与输入 Branches 的正方向一致）
    %   - 额外提供对齐后的 Branches/Q（便于导出与可视化）
    flow_reversed_mask = (Q(:) < 0);
    Branches_flow_aligned = Branches;
    if any(flow_reversed_mask)
        tmp = Branches_flow_aligned.from_node(flow_reversed_mask);
        Branches_flow_aligned.from_node(flow_reversed_mask) = Branches_flow_aligned.to_node(flow_reversed_mask);
        Branches_flow_aligned.to_node(flow_reversed_mask) = tmp;
    end
    Q_flow_aligned = abs(Q(:));

    Results.flow_reversed_mask = flow_reversed_mask;
    Results.Branches_flow_aligned = Branches_flow_aligned;
    Results.Q_flow_aligned = Q_flow_aligned;
    Results.node_residual_flow_aligned = incidence_matrix(Branches_flow_aligned, N, B) * Q_flow_aligned - b;

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
% 构造节点-分支关联矩阵（Incidence Matrix）
%
% 输入：
%   Branches - 分支数据结构
%   N        - 节点总数
%   B        - 分支总数
%
% 输出：
%   A (N×B)  - 关联矩阵
%
% 物理含义：
%   A 矩阵将离散的通风网络拓扑结构编码为线性代数对象
%   基尔霍夫第一定律（节点流量守恒）可表示为：A * Q = b
%   其中 b 为节点注入向量（入风>0，回风<0，中间节点=0）
%
% 矩阵元素定义：
%   A(i,j) = +1 ：分支 j 从节点 i 流出（起点）
%   A(i,j) = -1 ：分支 j 流入节点 i（终点）
%   A(i,j) =  0 ：分支 j 与节点 i 无关

    A = zeros(N, B);
    for e = 1:B
        u = Branches.from_node(e);  % 分支 e 的起点节点
        v = Branches.to_node(e);    % 分支 e 的终点节点
        A(u, e) = A(u, e) + 1;      % 起点：流出 +1
        A(v, e) = A(v, e) - 1;      % 终点：流入 -1
    end
end


function Q0 = feasible_initial_flow(A, b)
% 生成满足节点守恒的初始可行流（最小范数解）
%
% 输入：
%   A (N×B) - 节点-分支关联矩阵
%   b (N×1) - 节点注入向量（入风>0，回风<0，中间节点=0）
%
% 输出：
%   Q0 (B×1) - 初始风量分布
%
% 算法原理：
%   目标：求解欠定方程组 A * Q = b 的一个特解
%   方法：最小范数解 Q0 = A^T * (A*A^T)^(-1) * b
%
% 物理意义：
%   - Q0 满足节点流量守恒（基尔霍夫第一定律）
%   - Q0 对应的流场"能量"最小（||Q0||^2 最小）
%   - Q0 一般不满足回路压力平衡，需后续 Hardy Cross 迭代修正
%
% 技术细节：
%   - A 的行向量线性相关（Σ行 = 0），需去掉一行避免奇异
%   - 去掉节点 1（参考节点），相当于固定其电势为 0

    if size(A, 1) ~= numel(b)
        error('A 与 b 尺寸不匹配');
    end

    % 去掉第一行（参考节点）以避免 A*A' 奇异
    % 数学原理：A 的行向量满足 Σ(row_i) = 0，秩为 N-1
    A_red = A(2:end, :);  % (N-1)×B 降秩矩阵
    b_red = b(2:end);     % (N-1)×1 降维向量

    % 构造法方程：A_red * A_red^T * λ = b_red
    M = A_red * A_red';   % (N-1)×(N-1) Gram 矩阵
    if rcond(M) < 1e-12
        error('网络关联矩阵奇异，无法生成可行初始流');
    end

    % 最小范数解：Q0 = A_red^T * λ，其中 λ = (A_red*A_red^T)^(-1) * b_red
    Q0 = A_red' * (M \ b_red);

    % 验证解的有效性（用完整的 A 检查节点守恒）
    if norm(A * Q0 - b, inf) > 1e-6 * max(1, norm(b, inf))
        error('无法构造满足节点守恒的初始流（请检查网络连通性与边界条件）');
    end
end
