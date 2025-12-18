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
%              .id         分支编号 (B×1)
%              .from_node  起点节点 (B×1)
%              .to_node    终点节点 (B×1)
%
% 输出参数：
%   LoopMatrix - 回路矩阵 (M×B)
%                元素为 {-1, 0, +1}
%                +1: 分支方向与回路遍历方向一致
%                -1: 分支方向与回路遍历方向相反
%                 0: 分支不在该回路中
%
%   LoopInfo   - 回路详细信息结构体数组（长度为 M）
%                (k).branches      回路k包含的分支编号列表
%                (k).signs         对应的方向符号列表
%                (k).chord_branch  形成该回路的非树边（弦）
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

    B = length(Branches.id);                              % 分支总数
    N = max([Branches.from_node; Branches.to_node]);      % 节点总数
    M = B - N + 1;                                        % 理论独立回路数

    % 检查网络连通性（简单检查）
    if M < 0
        error('网络分支数不足！无法形成连通图（B < N-1）');
    end

    if M == 0
        warning('网络无回路（树结构），返回空回路矩阵');
        LoopMatrix = zeros(0, B);
        LoopInfo = struct('branches', {}, 'signs', {}, 'chord_branch', {});
        return;
    end

    %% ========== 第2步：构建 MATLAB Graph 对象 ==========

    % 使用 MATLAB 内置 graph 对象（无向图）
    % 注意：此处忽略分支方向，仅用于生成树构建

    G = graph(Branches.from_node, Branches.to_node);

    % 检查图的连通性
    bins = conncomp(G);
    if max(bins) > 1
        error('网络不连通！存在 %d 个独立子图。', max(bins));
    end

    %% ========== 第3步：生成生成树（DFS 遍历）==========

    % 使用深度优先搜索（DFS）构建生成树
    % MATLAB 的 dfsearch 返回访问序列，需要手动提取树边

    root_node = 1;  % 从节点1开始（可选择任意节点）
    [tree_edges, is_tree_edge] = build_spanning_tree_dfs(G, root_node, Branches);

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

    %% ========== 第4步：对每条非树边构建基本回路 ==========

    LoopMatrix = zeros(M_actual, B);
    LoopInfo = struct('branches', {}, 'signs', {}, 'chord_branch', {});

    for k = 1:M_actual
        chord_id = chord_branches(k);  % 当前非树边（弦）的分支编号

        % 获取弦的端点
        u = Branches.from_node(chord_id);
        v = Branches.to_node(chord_id);

        % 在生成树中找到 u → v 的唯一路径
        % 使用 MATLAB shortestpath（在树中就是唯一路径）
        tree_graph = build_tree_graph(tree_edges, Branches, N);
        % 为保证回路方向与弦（chord）分支方向一致，取树路径 v -> u，然后再走弦 u -> v 闭合
        [tree_path_nodes, ~] = shortestpath(tree_graph, v, u);

        if isempty(tree_path_nodes)
            warning('回路 %d：在生成树中未找到节点 %d → %d 的路径！', k, u, v);
            continue;
        end

        % 将节点路径转换为分支路径
        tree_path_branches = nodes_to_branches(tree_path_nodes, tree_edges, Branches);

        % 基本回路 = 树路径 + 弦
        loop_branches = [tree_path_branches; chord_id];

        % 确定每条分支在回路中的方向符号
        loop_signs = determine_loop_signs(loop_branches, tree_path_nodes, chord_id, Branches);

        % 填充回路矩阵
        for i = 1:length(loop_branches)
            b_id = loop_branches(i);
            LoopMatrix(k, b_id) = loop_signs(i);
        end

        % 保存回路详细信息
        LoopInfo(k).branches = loop_branches;
        LoopInfo(k).signs = loop_signs;
        LoopInfo(k).chord_branch = chord_id;
    end

    if verbose
        fprintf('回路识别完成！共识别 %d 个独立回路\n\n', M_actual);
    end

end


%% ========== 辅助函数：构建生成树（DFS） ==========

function [tree_edges, is_tree_edge] = build_spanning_tree_dfs(G, root, Branches)
    % 使用深度优先搜索构建生成树
    % 输出：
    %   tree_edges   : 树边的分支编号列表
    %   is_tree_edge : 布尔向量 (B×1)，标记每条分支是否为树边

    B = length(Branches.id);
    N = numnodes(G);

    visited = false(N, 1);
    tree_edges = [];
    is_tree_edge = false(B, 1);

    % DFS 递归函数
    function dfs(node)
        visited(node) = true;

        neighbors = G.neighbors(node);
        for i = 1:length(neighbors)
            next_node = neighbors(i);

            if ~visited(next_node)
                % 找到对应的分支编号
                branch_id = find_branch_id(node, next_node, Branches);

                if ~isempty(branch_id)
                    tree_edges = [tree_edges; branch_id];
                    is_tree_edge(branch_id) = true;
                end

                % 递归访问
                dfs(next_node);
            end
        end
    end

    % 从根节点开始 DFS
    dfs(root);

    % 检查是否遍历了所有节点
    if sum(visited) < N
        warning('DFS 未能遍历所有节点！网络可能不连通。');
    end
end


%% ========== 辅助函数：查找分支编号 ==========

function branch_id = find_branch_id(node1, node2, Branches)
    % 在 Branches 中查找连接 node1 和 node2 的分支编号
    % 注意：分支可能是 node1→node2 或 node2→node1

    idx1 = find(Branches.from_node == node1 & Branches.to_node == node2);
    idx2 = find(Branches.from_node == node2 & Branches.to_node == node1);

    if ~isempty(idx1)
        branch_id = Branches.id(idx1(1));
    elseif ~isempty(idx2)
        branch_id = Branches.id(idx2(1));
    else
        branch_id = [];
    end
end


%% ========== 辅助函数：构建生成树 Graph 对象 ==========

function tree_graph = build_tree_graph(tree_edges, Branches, N)
    % 根据树边列表构建生成树的 Graph 对象

    if isempty(tree_edges)
        tree_graph = graph([], [], N);
        return;
    end

    from_nodes = zeros(length(tree_edges), 1);
    to_nodes = zeros(length(tree_edges), 1);

    for i = 1:length(tree_edges)
        b_id = tree_edges(i);
        idx = find(Branches.id == b_id, 1);
        from_nodes(i) = Branches.from_node(idx);
        to_nodes(i) = Branches.to_node(idx);
    end

    tree_graph = graph(from_nodes, to_nodes);
end


%% ========== 辅助函数：节点路径转分支路径 ==========

function branch_path = nodes_to_branches(node_path, tree_edges, Branches)
    % 将节点序列转换为分支编号序列

    branch_path = [];

    for i = 1:(length(node_path) - 1)
        n1 = node_path(i);
        n2 = node_path(i+1);

        % 查找连接 n1 和 n2 的树边
        b_id = find_branch_id(n1, n2, Branches);

        if isempty(b_id)
            warning('节点路径转换失败：未找到节点 %d → %d 的分支', n1, n2);
        else
            branch_path = [branch_path; b_id];
        end
    end
end


%% ========== 辅助函数：确定回路方向符号 ==========

function loop_signs = determine_loop_signs(loop_branches, node_path, chord_id, Branches)
    % 确定回路中每条分支的方向符号（+1 或 -1）
    % 策略：统一按照回路遍历方向（节点路径方向 + 弦方向）

    loop_signs = zeros(length(loop_branches), 1);

    % 处理树路径上的分支
    for i = 1:(length(node_path) - 1)
        n1 = node_path(i);
        n2 = node_path(i+1);

        % 找到对应的分支
        b_id = find_branch_id(n1, n2, Branches);
        idx_in_loop = find(loop_branches == b_id, 1);

        if isempty(idx_in_loop)
            continue;
        end

        % 获取分支实际方向
        b_idx = find(Branches.id == b_id, 1);
        actual_from = Branches.from_node(b_idx);
        actual_to = Branches.to_node(b_idx);

        % 判断分支方向是否与遍历方向一致
        if actual_from == n1 && actual_to == n2
            loop_signs(idx_in_loop) = +1;  % 方向一致
        else
            loop_signs(idx_in_loop) = -1;  % 方向相反
        end
    end

    % 处理弦（闭合边）
    chord_idx_in_loop = find(loop_branches == chord_id, 1);
    if ~isempty(chord_idx_in_loop)
        % 弦的方向按照其定义方向取正
        loop_signs(chord_idx_in_loop) = +1;
    end
end
