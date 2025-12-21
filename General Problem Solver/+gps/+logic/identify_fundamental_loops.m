% 独立回路自动识别算法（基于生成树法）
% ==========================================
% 功能：从通风网络拓扑中自动提取独立回路（Fundamental Cycles）
% 算法：生成树法（Spanning Tree Method）
%
% 原理：
%   对于连通网络图 G(V, E)：
%   1. 生成树 T 包含 N-1 条边（N为节点数）
%   2. 非树边（弦）数量 = B - (N-1) = B - N + 1 = M（独立回路数）
%   3. 每条非树边与生成树形成一个基本回路
%
% 输入参数：
%   Branches - 分支数据结构体
%              .id         分支编号/标签 (B×1，可选但建议唯一)
%              .from_node  起点节点 (B×1)
%              .to_node    终点节点 (B×1)
%
% 输出参数：
%   LoopMatrix - 回路矩阵 (M×B)
%                元素为 {-1, 0, +1}
%                +1: 分支方向与回路遍历方向一致
%                -1: 分支方向与回路遍历方向相反
%                 0: 分支不在该回路中
%                注意：LoopMatrix 的列索引为“分支在 Branches 中的行索引 e=1..B”，
%                      与 Branches.id 的数值无关（Branches.id 仅作为标签使用）。
%
%   LoopInfo   - 回路详细信息结构体数组（长度为 M）
%                (k).branches      回路k包含的分支索引列表（行索引 1..B）
%                (k).signs         对应的方向符号列表
%                (k).chord_branch  形成该回路的非树边（弦，分支索引）
%                (k).branches_id / (k).chord_branch_id  若提供 Branches.id，则给出对应标签
%
% 示例：
%   Branches.id = (1:8)';
%   Branches.from_node = [1; 1; 3; 2; 3; 5; 4; 5];
%   Branches.to_node   = [2; 3; 2; 4; 5; 4; 6; 6];
%   [LoopMatrix, LoopInfo] = identify_fundamental_loops(Branches);
%
% 作者：东北大学 资源与土木工程学院 智采2201班 学生
% 日期：2025-12-17

function [LoopMatrix, LoopInfo] = identify_fundamental_loops(Branches, verbose)

    if nargin < 2 || isempty(verbose)
        verbose = false;
    end

    %% ========== 第1步：提取网络拓扑参数 ==========

    if ~isstruct(Branches) || ~isfield(Branches, 'from_node') || ~isfield(Branches, 'to_node')
        error('Branches 必须为结构体，且包含 from_node 与 to_node 字段');
    end

    from_node = Branches.from_node(:);
    to_node = Branches.to_node(:);

    B = numel(from_node);                                 % 分支总数（行索引 e=1..B）
    if numel(to_node) ~= B
        error('Branches.from_node 与 Branches.to_node 长度不一致');
    end
    if B == 0
        error('网络分支数为 0，无法识别回路');
    end

    if any(~isfinite(from_node)) || any(~isfinite(to_node))
        error('节点编号必须为有限数值');
    end
    if any(from_node < 1) || any(to_node < 1) || any(mod(from_node, 1) ~= 0) || any(mod(to_node, 1) ~= 0)
        error('节点编号必须为从 1 开始的正整数');
    end

    N = max([from_node; to_node]);                        % 节点总数（按最大编号计）
    M = B - N + 1;                                        % 理论独立回路数

    % 检查网络连通性（简单检查）
    if M < 0
        error('网络分支数不足！无法形成连通图（B < N-1）');
    end

    if M == 0
        warning('网络无回路（树结构），返回空回路矩阵');
        LoopMatrix = zeros(0, B);
        LoopInfo = struct('branches', {}, 'signs', {}, 'chord_branch', {}, ...
            'branches_id', {}, 'chord_branch_id', {});
        return;
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
    else
        ids = (1:B)'; %#ok<NASGU>
    end

    %% ========== 第2步：构建无向邻接（以“分支索引”为一等公民） ==========

    incident_branches = cell(N, 1);
    for e = 1:B
        u = from_node(e);
        v = to_node(e);
        incident_branches{u}(end+1, 1) = e;
        if v ~= u
            incident_branches{v}(end+1, 1) = e;
        end
    end

    % 并联分支诊断（可选输出）
    if verbose
        uv = sort([from_node, to_node], 2);
        [~, ~, g] = unique(uv, 'rows');
        cnt = accumarray(g, 1);
        n_parallel_groups = sum(cnt > 1);
        if n_parallel_groups > 0
            fprintf('检测到并联分支：%d 组（同一对节点之间存在多条分支）\n', n_parallel_groups);
        end
    end

    %% ========== 第3步：连通性检查（无向） ==========

    root_node = 1;  % 与现有实现保持一致（节点编号从 1..N）
    visited_conn = false(N, 1);
    queue = zeros(N, 1);
    qh = 1;
    qt = 1;
    queue(qt) = root_node;
    visited_conn(root_node) = true;

    while qh <= qt
        node = queue(qh);
        qh = qh + 1;

        edges = incident_branches{node};
        for i = 1:numel(edges)
            e = edges(i);
            other = other_endpoint(from_node, to_node, e, node);
            if other == 0
                continue;
            end
            if ~visited_conn(other)
                visited_conn(other) = true;
                qt = qt + 1;
                queue(qt) = other;
            end
        end
    end

    if sum(visited_conn) < N
        error('网络不连通：存在不可达节点（数量=%d，根节点=%d）', sum(~visited_conn), root_node);
    end

    %% ========== 第4步：生成生成树（DFS 遍历，支持并联边） ==========

    visited = false(N, 1);
    parent_node = zeros(N, 1);
    parent_branch = zeros(N, 1);
    depth = zeros(N, 1);

    is_tree_edge = false(B, 1);

    stack = zeros(N, 1);
    sp = 1;
    stack(sp) = root_node;
    visited(root_node) = true;

    while sp > 0
        node = stack(sp);
        sp = sp - 1;

        edges = incident_branches{node};
        for i = 1:numel(edges)
            e = edges(i);
            other = other_endpoint(from_node, to_node, e, node);
            if other == 0 || other == node
                continue;
            end
            if ~visited(other)
                visited(other) = true;
                parent_node(other) = node;
                parent_branch(other) = e;
                depth(other) = depth(node) + 1;
                is_tree_edge(e) = true;

                sp = sp + 1;
                stack(sp) = other;
            end
        end
    end

    tree_edges = find(is_tree_edge);

    % 识别非树边（弦）
    chord_branches = find(~is_tree_edge);

    if verbose
        fprintf('生成树构建完成：\n');
        fprintf('  生成树包含 %d 条边\n', length(tree_edges));
        fprintf('  非树边（弦）数量 = %d\n', length(chord_branches));
        fprintf('  独立回路数 M = %d\n\n', length(chord_branches));
    end

    if length(chord_branches) ~= M
        warning('实际非树边数量（%d）与理论独立回路数（%d）不符！', ...
            length(chord_branches), M);
    end

    M_actual = length(chord_branches);

    %% ========== 第5步：对每条非树边构建基本回路 ==========

    LoopMatrix = zeros(M_actual, B);
    LoopInfo = repmat(struct( ...
        'branches', [], ...
        'signs', [], ...
        'chord_branch', [], ...
        'branches_id', [], ...
        'chord_branch_id', []), M_actual, 1);

    % 树边快速索引：tree_branch(u,v)=分支索引 e（树中同一对节点只有一条边）
    tree_branch = sparse(N, N);
    for node = 1:N
        p = parent_node(node);
        e = parent_branch(node);
        if p ~= 0 && e ~= 0
            tree_branch(node, p) = e;
            tree_branch(p, node) = e;
        end
    end

    for k = 1:M_actual
        chord_e = chord_branches(k);  % 当前非树边（弦）的分支索引

        % 获取弦的端点
        u = from_node(chord_e);
        v = to_node(chord_e);

        if u == v
            warning('检测到自环分支（from_node==to_node）：分支索引 e=%d，将作为长度为1的回路处理', chord_e);
            LoopMatrix(k, chord_e) = +1;
            LoopInfo(k).branches = chord_e;
            LoopInfo(k).signs = +1;
            LoopInfo(k).chord_branch = chord_e;
            if isfield(Branches, 'id')
                LoopInfo(k).branches_id = Branches.id(chord_e);
                LoopInfo(k).chord_branch_id = Branches.id(chord_e);
            else
                LoopInfo(k).branches_id = chord_e;
                LoopInfo(k).chord_branch_id = chord_e;
            end
            continue;
        end

        % 为保证回路方向与弦（chord）分支方向一致，取树路径 v -> u，然后再走弦 u -> v 闭合
        tree_path_nodes = tree_path_in_nodes(v, u, parent_node, depth);

        % 节点路径 -> 树边序列，并确定方向符号
        n_steps = numel(tree_path_nodes) - 1;
        tree_path_branches = zeros(n_steps, 1);
        tree_path_signs = zeros(n_steps, 1);

        for i = 1:n_steps
            n1 = tree_path_nodes(i);
            n2 = tree_path_nodes(i + 1);
            e = full(tree_branch(n1, n2));
            if e == 0
                error('生成树路径转换失败：未找到节点 %d → %d 的树边', n1, n2);
            end
            tree_path_branches(i) = e;
            if from_node(e) == n1 && to_node(e) == n2
                tree_path_signs(i) = +1;
            else
                tree_path_signs(i) = -1;
            end
        end

        loop_branches = [tree_path_branches; chord_e];
        loop_signs = [tree_path_signs; +1];

        LoopMatrix(k, loop_branches) = loop_signs(:).';

        LoopInfo(k).branches = loop_branches;
        LoopInfo(k).signs = loop_signs;
        LoopInfo(k).chord_branch = chord_e;
        if isfield(Branches, 'id')
            LoopInfo(k).branches_id = Branches.id(loop_branches);
            LoopInfo(k).chord_branch_id = Branches.id(chord_e);
        else
            LoopInfo(k).branches_id = loop_branches;
            LoopInfo(k).chord_branch_id = chord_e;
        end
    end

    if verbose
        fprintf('回路识别完成！共识别 %d 个独立回路\n\n', M_actual);
    end

end


%% ========== 辅助函数：另一端节点 ==========

function other = other_endpoint(from_node, to_node, e, current)
    u = from_node(e);
    v = to_node(e);
    if current == u
        other = v;
    elseif current == v
        other = u;
    else
        other = 0;
    end
end


%% ========== 辅助函数：生成树中两点的唯一路径（节点序列）==========

function path_nodes = tree_path_in_nodes(start_node, goal_node, parent_node, depth)
    a = start_node;
    b = goal_node;

    path_a = a;
    path_b = b;

    while depth(a) > depth(b)
        a = parent_node(a);
        if a == 0
            error('生成树路径查找失败：start_node 无法回溯到根');
        end
        path_a(end+1, 1) = a; %#ok<AGROW>
    end

    while depth(b) > depth(a)
        b = parent_node(b);
        if b == 0
            error('生成树路径查找失败：goal_node 无法回溯到根');
        end
        path_b(end+1, 1) = b; %#ok<AGROW>
    end

    while a ~= b
        a = parent_node(a);
        b = parent_node(b);
        if a == 0 || b == 0
            error('生成树路径查找失败：无法找到公共祖先');
        end
        path_a(end+1, 1) = a; %#ok<AGROW>
        path_b(end+1, 1) = b; %#ok<AGROW>
    end

    % path_a 与 path_b 都以 LCA 结尾
    path_nodes = [path_a; flipud(path_b(1:end-1))];
end
