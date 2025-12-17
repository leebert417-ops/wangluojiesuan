% 通用通风网络 Hardy Cross 迭代求解器
% ==========================================
% 功能：适用于任意拓扑结构的矿井通风网络风量解算
% 算法：Hardy Cross 回路迭代法（基于自动回路识别）
%
% 输入参数：
%   Branches      - 分支数据结构体（必需）
%                   .id         分支编号 (B×1 向量)
%                   .from_node  起点节点 (B×1 向量)
%                   .to_node    终点节点 (B×1 向量)
%                   .R          风阻系数 (B×1 向量, 单位：N·s²/m⁸)
%
%   Boundary      - 边界条件结构体（必需）
%                   .inlet_branch   入风分支编号（标量或向量）
%                   .outlet_branch  回风分支编号（标量或向量）
%                   .Q_total        总风量 (m³/s)
%
%   SolverOptions - 求解器参数结构体（可选）
%                   .max_iter   最大迭代次数（默认 1000）
%                   .tolerance  收敛容差（默认 1e-3）
%                   .method     求解方法（默认 'HardyCross'）
%                   .verbose    是否显示详细信息（默认 true）
%
% 输出参数：
%   Q             - 各分支风量 (B×1 向量, m³/s)
%                   正值表示实际流向与预设方向（from_node → to_node）一致
%
%   Results       - 求解详细信息结构体
%                   .iterations       实际迭代次数
%                   .converged        是否收敛（true/false）
%                   .LoopMatrix       回路矩阵 (M×B)，元素为 {-1, 0, +1}
%                   .pressure_loss    各分支压降 (B×1 向量, Pa)
%                   .max_residual     最终最大回路残差 (Pa)
%                   .residual_history 收敛历史（每次迭代的最大残差）
%
% 示例：
%   Branches.id = (1:8)';
%   Branches.from_node = [1; 1; 3; 2; 3; 5; 4; 5];
%   Branches.to_node   = [2; 3; 2; 4; 5; 4; 6; 6];
%   Branches.R = [0.1; 0.2; 0.15; 0.25; 0.18; 0.22; 0.2; 0.12];
%
%   Boundary.inlet_branch = [1; 2];
%   Boundary.outlet_branch = [7; 8];
%   Boundary.Q_total = 100;
%
%   [Q, Results] = ventilation_network_solver_generic(Branches, Boundary);
%
% 作者：MATLAB 通风工程专家助手
% 日期：2025-12-17

function [Q, Results] = ventilation_network_solver_generic(Branches, Boundary, SolverOptions)

    %% ========== 第1步：输入参数处理与默认值设置 ==========

    % 检查必需参数
    if nargin < 2
        error('至少需要提供 Branches 和 Boundary 两个输入参数！');
    end

    % 设置默认求解器参数
    if nargin < 3 || isempty(SolverOptions)
        SolverOptions = struct();
    end

    if ~isfield(SolverOptions, 'max_iter')
        SolverOptions.max_iter = 1000;
    end

    if ~isfield(SolverOptions, 'tolerance')
        SolverOptions.tolerance = 1e-3;
    end

    if ~isfield(SolverOptions, 'method')
        SolverOptions.method = 'HardyCross';
    end

    if ~isfield(SolverOptions, 'verbose')
        SolverOptions.verbose = true;
    end

    % 提取基本参数
    B = length(Branches.id);                              % 分支总数
    R = Branches.R(:);                                    % 风阻向量 (B×1)
    N = max([Branches.from_node; Branches.to_node]);      % 节点总数

    %% ========== 第2步：自动识别独立回路 ==========

    if SolverOptions.verbose
        fprintf('========================================\n');
        fprintf(' 通用通风网络求解器\n');
        fprintf('========================================\n');
        fprintf('网络拓扑：\n');
        fprintf('  节点数 N = %d\n', N);
        fprintf('  分支数 B = %d\n', B);
        fprintf('  理论独立回路数 M = B - N + 1 = %d\n', B - N + 1);
        fprintf('========================================\n\n');
    end

    % 调用回路识别函数（核心模块）
    [LoopMatrix, LoopInfo] = identify_fundamental_loops(Branches);
    M = size(LoopMatrix, 1);  % 实际识别出的独立回路数量

    if SolverOptions.verbose
        fprintf('回路识别完成：识别出 %d 个独立回路\n', M);
        for k = 1:M
            branches_in_loop = find(LoopMatrix(k, :) ~= 0);
            fprintf('  回路 %d: 分支 [%s]\n', k, num2str(branches_in_loop'));
        end
        fprintf('\n');
    end

    %% ========== 第3步：初始风量估计 ==========

    Q = initialize_flow(Branches, Boundary);

    if SolverOptions.verbose
        fprintf('初始风量估计完成\n');
        fprintf('  入口分支总风量: %.4f m³/s\n', sum(Q(Boundary.inlet_branch)));
        fprintf('========================================\n\n');
        fprintf('开始 Hardy Cross 迭代求解...\n\n');
    end

    %% ========== 第4步：Hardy Cross 迭代主循环 ==========

    max_iter = SolverOptions.max_iter;
    tol = SolverOptions.tolerance;
    residual_history = zeros(max_iter, 1);

    converged = false;

    for iter = 1:max_iter
        Q_old = Q;
        max_residual = 0.0;

        % 对每个独立回路进行修正
        for k = 1:M
            % 获取回路 k 的方向符号向量
            s_k = LoopMatrix(k, :)';  % (B×1)
            idx = find(s_k ~= 0);      % 回路中涉及的分支索引

            % 计算各分支压降（Atkinson 阻力定律）
            % H_i = R_i * Q_i * |Q_i|
            H = R .* Q .* abs(Q);

            % 计算回路压降闭合差（带符号求和）
            % Δh_k = Σ (s_ki * H_i)
            numerator = sum(s_k .* H);

            % 计算斜率项（分母）
            % D_k = Σ (2 * R_i * |Q_i|)  对于回路中的分支
            % 为避免除零，对接近0的风量使用最小等效值
            Q_abs_safe = max(abs(Q(idx)), 1e-6);
            denominator = sum(2 * R(idx) .* Q_abs_safe);

            % 计算回路风量修正量
            % ΔQ_k = - Δh_k / D_k
            if abs(denominator) > 1e-12
                delta_Q = -numerator / denominator;
            else
                delta_Q = 0.0;
            end

            % 沿回路方向修正各分支风量
            % Q_i(new) = Q_i(old) + s_ki * ΔQ_k
            Q = Q + s_k * delta_Q;

            % 更新本轮最大回路残差
            max_residual = max(max_residual, abs(numerator));
        end

        %% ========== 第5步：边界条件归一化 ==========
        % 保证入口总风量守恒：Q_total = Σ Q(inlet_branches)

        inlet_branches = Boundary.inlet_branch(:);
        Q_inlet_sum = sum(Q(inlet_branches));

        if abs(Q_inlet_sum) > 1e-6
            scale = Boundary.Q_total / Q_inlet_sum;
            Q = Q * scale;
        else
            warning('入口分支总风量接近零，归一化失败！请检查网络拓扑或初始猜测。');
        end

        %% ========== 第6步：收敛性检查 ==========

        max_change = max(abs(Q - Q_old));
        residual_history(iter) = max_residual;

        % 收敛判据：回路压降残差 AND 风量变化量均小于容差
        if max_residual < tol && max_change < tol
            converged = true;

            if SolverOptions.verbose
                fprintf('========================================\n');
                fprintf('✓ 迭代收敛！\n');
                fprintf('  迭代次数: %d\n', iter);
                fprintf('  最大回路残差: %.6f Pa\n', max_residual);
                fprintf('  最大风量变化: %.6f m³/s\n', max_change);
                fprintf('========================================\n');
            end

            break;
        end

        % 每10次迭代输出一次进度（可选）
        if SolverOptions.verbose && mod(iter, 10) == 0
            fprintf('  迭代 %4d | 最大残差 = %10.6f Pa | 最大变化 = %10.6f m³/s\n', ...
                iter, max_residual, max_change);
        end
    end

    %% ========== 第7步：未收敛处理 ==========

    if ~converged
        warning('未在 %d 次迭代内收敛！最大残差 = %.6f Pa', max_iter, max_residual);
        if SolverOptions.verbose
            fprintf('========================================\n');
            fprintf('⚠ 未收敛警告\n');
            fprintf('  已达最大迭代次数: %d\n', max_iter);
            fprintf('  最终回路残差: %.6f Pa\n', max_residual);
            fprintf('  建议：增加 max_iter 或调整初始猜测\n');
            fprintf('========================================\n');
        end
        iter = max_iter;
    end

    %% ========== 第8步：组装输出结果 ==========

    Results = struct();
    Results.iterations = iter;
    Results.converged = converged;
    Results.LoopMatrix = LoopMatrix;
    Results.pressure_loss = R .* Q .* abs(Q);
    Results.max_residual = max_residual;
    Results.residual_history = residual_history(1:iter);
    Results.network_info = struct('N', N, 'B', B, 'M', M);

    % 附加回路详细信息
    if exist('LoopInfo', 'var')
        Results.LoopInfo = LoopInfo;
    end

    if SolverOptions.verbose
        fprintf('\n');
        fprintf('各分支求解结果：\n');
        fprintf('  %-8s %-12s %-12s\n', '分支ID', '风量(m³/s)', '压降(Pa)');
        fprintf('  %s\n', repmat('-', 1, 40));
        for i = 1:B
            fprintf('  %-8d %-12.4f %-12.4f\n', Branches.id(i), Q(i), Results.pressure_loss(i));
        end
        fprintf('========================================\n\n');
    end

end


%% ========== 辅助函数：初始风量估计 ==========

function Q_init = initialize_flow(Branches, Boundary)
    % 简单策略：入口分支平均分配 Q_total，其他分支取 0
    % 后续可扩展为基于最短路径的启发式算法

    B = length(Branches.id);
    Q_init = zeros(B, 1);

    % 入口分支平均分配总风量
    inlet_branches = Boundary.inlet_branch(:);
    n_inlet = length(inlet_branches);

    if n_inlet > 0
        Q_init(inlet_branches) = Boundary.Q_total / n_inlet;
    end

    % 注意：此处的初始猜测非常简单，可能导致某些网络收敛较慢
    % 改进方向：使用网络拓扑信息做更智能的初始化
end
