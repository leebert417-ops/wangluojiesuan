function G = plot_network_graph(uitableHandle, axesHandle)
%PLOT_NETWORK_GRAPH 读取表格数据并绘制通风网络无向图
%
% 在 App Designer 的"显示网络图"按钮回调里：
%   addpath('General Problem Solver');
%   gps.ui.plot_network_graph(app.UITable, app.UIAxes);
%
% 输入：
%   uitableHandle: matlab.ui.control.Table（包含起点、终点列）
%   axesHandle: matlab.ui.control.UIAxes 或 axes 句柄（可选）
%
% 输出：
%   G: graph 对象（无向图）
%
% 功能：
%   - 从 UITable 读取"起点"和"终点"列
%   - 使用 sparse 函数建立邻接矩阵
%   - 使用 graph 构建无向图
%   - 使用 plot 函数在指定 axes 上绘制网络图
%   - 自动标注节点编号和分支 ID
%
% 版本：
%   v1.0 (2025-12-18) - 初始版本
%
% 作者：东北大学 资源与土木工程学院 智采2201班 学生

    arguments
        uitableHandle (1,1) matlab.ui.control.Table
        axesHandle = []
    end

    % 初始化返回值
    G = [];

    % 1. 获取 UIFigure（用于弹窗）
    uifig = [];
    try
        uifig = ancestor(uitableHandle, 'matlab.ui.Figure', 'toplevel');
    catch
        try
            uifig = ancestor(uitableHandle, 'figure');
        catch
        end
    end

    try
        % ========== 2. 获取表格数据 ==========
        if isempty(uitableHandle.Data)
            error('表格为空，请先导入或添加分支数据');
        end

        branchData = uitableHandle.Data;

        % 验证表格结构
        if ~istable(branchData)
            error('表格数据必须为 table 类型');
        end

        if width(branchData) < 3
            error('表格必须至少包含 3 列（ID, 起点, 终点）');
        end

        if height(branchData) == 0
            error('表格无数据，请先添加分支');
        end

        % ========== 3. 提取起点和终点数据 ==========
        colNames = branchData.Properties.VariableNames;

        % 自动识别列（支持不同列名）
        idCol = find(contains(lower(colNames), {'id', '编号'}), 1);
        fromCol = find(contains(lower(colNames), {'起点', 'from', 'start'}), 1);
        toCol = find(contains(lower(colNames), {'终点', 'to', 'end'}), 1);

        if isempty(idCol), idCol = 1; end
        if isempty(fromCol), fromCol = 2; end
        if isempty(toCol), toCol = 3; end

        % 提取数据
        branch_ids = branchData{:, idCol};
        from_nodes = branchData{:, fromCol};
        to_nodes = branchData{:, toCol};

        B = length(branch_ids);  % 分支数

        % ========== 4. 数据验证 ==========
        % 检查节点编号有效性
        if any(~isfinite(from_nodes)) || any(~isfinite(to_nodes))
            error('节点编号必须为有限整数');
        end

        if any(from_nodes < 1) || any(to_nodes < 1)
            error('节点编号必须 >= 1');
        end

        % 检查自环
        if any(from_nodes == to_nodes)
            selfLoops = find(from_nodes == to_nodes);
            error('分支 %s 存在自环（起点=终点），无法绘图', mat2str(selfLoops'));
        end

        % 计算节点总数
        N = max([from_nodes(:); to_nodes(:)]);

        % ========== 5. 使用 sparse 建立邻接矩阵 ==========
        % 创建对称的邻接矩阵（无向图）
        A = sparse([from_nodes; to_nodes], [to_nodes; from_nodes], ...
                   [ones(B, 1); ones(B, 1)], N, N);

        % ========== 6. 使用 graph 构建无向图 ==========
        G = graph(A);

        % 为图添加边的标签（分支 ID）
        edgeIDs = cell(numedges(G), 1);
        edgeTable = G.Edges;
        for i = 1:numedges(G)
            u = edgeTable.EndNodes(i, 1);
            v = edgeTable.EndNodes(i, 2);

            % 查找对应的分支 ID
            idx = find((from_nodes == u & to_nodes == v) | ...
                       (from_nodes == v & to_nodes == u), 1);
            if ~isempty(idx)
                edgeIDs{i} = sprintf('%d', branch_ids(idx));
            else
                edgeIDs{i} = '';
            end
        end
        G.Edges.BranchID = edgeIDs;

        % ========== 7. 绘制无向图 ==========
        % 确定绘图目标
        if isempty(axesHandle)
            % 创建新的 figure
            figure('Name', '通风网络拓扑图', 'NumberTitle', 'off');
            ax = gca;
        else
            % 使用指定的 axes
            ax = axesHandle;
            cla(ax);  % 清空当前 axes
        end

        % 绘制图形
        h = plot(ax, G, 'LineWidth', 2, 'MarkerSize', 8, ...
                 'NodeColor', [0.2 0.4 0.8], ...
                 'EdgeColor', [0.3 0.3 0.3]);

        % 设置节点标签（节点编号）
        h.NodeLabel = arrayfun(@num2str, (1:numnodes(G))', 'UniformOutput', false);
        h.NodeFontSize = 10;
        h.NodeFontWeight = 'bold';

        % 设置边标签（分支 ID）
        h.EdgeLabel = G.Edges.BranchID;
        h.EdgeFontSize = 9;
        h.EdgeColor = [0.4 0.4 0.4];

        % 设置标题和坐标轴
        title(ax, sprintf('通风网络拓扑图\n节点数: %d | 分支数: %d', N, B), ...
              'FontSize', 12, 'FontWeight', 'bold');
        axis(ax, 'equal');
        axis(ax, 'off');

        % 添加图例说明
        text(ax, 0.02, 0.98, sprintf('○ 节点编号\n━ 分支 ID'), ...
             'Units', 'normalized', 'VerticalAlignment', 'top', ...
             'FontSize', 9, 'Color', [0.5 0.5 0.5], ...
             'BackgroundColor', 'white', 'EdgeColor', [0.7 0.7 0.7]);

        % ========== 8. 成功提示 ==========
        if ~isempty(uifig)
            uialert(uifig, ...
                sprintf('成功绘制网络图\n\n节点数: %d\n分支数: %d', N, B), ...
                '绘图成功', 'Icon', 'success');
        end

    catch ME
        % ========== 错误处理 ==========
        if ~isempty(uifig)
            uialert(uifig, ...
                sprintf('绘图失败\n\n错误: %s', ME.message), ...
                '绘图失败', 'Icon', 'error');
        else
            rethrow(ME);
        end
    end
end
