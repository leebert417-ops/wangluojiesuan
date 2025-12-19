function G = plot_network_graph(uitableHandle, axesHandle, app)
%PLOT_NETWORK_GRAPH 读取表格数据并绘制通风网络无向图
%
% 在 App Designer 的"显示网络图"按钮回调里：
%   addpath('General Problem Solver');
%   gps.ui.plot_network_graph(app.UITable, app.UIAxes, app);  % 推荐（可从 EditField_2/3 读取边界）
%   gps.ui.plot_network_graph(app.UITable, app.UIAxes);       % 也可（会尝试从 UIFigure 子组件自动定位）
%
% 输入：
%   uitableHandle: matlab.ui.control.Table（包含起点、终点列）
%   axesHandle: matlab.ui.control.UIAxes 或 axes 句柄（可选）
%   app: App Designer app 对象（可选，用于自动读取 EditField_2/3 的入/回风节点）
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
        app = []
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

        % ========== 5. 读取入风/回风节点（从 UI 的 EditField_2/3 自动获取，可选）==========
        inlet_nodes = [];
        outlet_nodes = [];
        if nargin >= 3 && ~isempty(app)
            [inlet_nodes, outlet_nodes] = readBoundaryNodesFromApp(app);
        elseif ~isempty(uifig)
            % 不传 app 时，尝试直接从 UIFigure 的子组件中定位“入风节点/回风节点”输入框
            [inlet_nodes, outlet_nodes] = readBoundaryNodesFromUIFigure(uifig);
        end
        inlet_nodes = unique(inlet_nodes(:), 'stable');
        outlet_nodes = unique(outlet_nodes(:), 'stable');

        if ~isempty(inlet_nodes)
            if any(~isfinite(inlet_nodes)) || any(inlet_nodes < 1) || any(mod(inlet_nodes, 1) ~= 0) || any(inlet_nodes > N)
                error('入风节点必须为 1..%d 的正整数（当前：%s）', N, mat2str(inlet_nodes'));
            end
        end
        if ~isempty(outlet_nodes)
            if any(~isfinite(outlet_nodes)) || any(outlet_nodes < 1) || any(mod(outlet_nodes, 1) ~= 0) || any(outlet_nodes > N)
                error('回风节点必须为 1..%d 的正整数（当前：%s）', N, mat2str(outlet_nodes'));
            end
        end
        if ~isempty(inlet_nodes) && ~isempty(outlet_nodes) && any(ismember(inlet_nodes, outlet_nodes))
            error('入风节点与回风节点不能重复');
        end

        % ========== 6. 使用 Edge Table 构建无向图（避免 sparse 合并平行边）==========
        EndNodes = [from_nodes(:), to_nodes(:)];
        edgeLabel = string(branch_ids(:));
        edgeType = repmat("branch", B, 1);

        hasInlet = ~isempty(inlet_nodes);
        hasOutlet = ~isempty(outlet_nodes);
        sourceNode = [];
        sinkNode = [];

        if hasInlet
            sourceNode = N + 1;
            EndNodes = [EndNodes; [repmat(sourceNode, numel(inlet_nodes), 1), inlet_nodes(:)]];
            edgeLabel = [edgeLabel; repmat("入风巷道", numel(inlet_nodes), 1)];
            edgeType = [edgeType; repmat("inlet", numel(inlet_nodes), 1)];
        end
        if hasOutlet
            if hasInlet
                sinkNode = N + 2;
            else
                sinkNode = N + 1;
            end
            EndNodes = [EndNodes; [outlet_nodes(:), repmat(sinkNode, numel(outlet_nodes), 1)]];
            edgeLabel = [edgeLabel; repmat("回风巷道", numel(outlet_nodes), 1)];
            edgeType = [edgeType; repmat("outlet", numel(outlet_nodes), 1)];
        end

        edgeTable = table(EndNodes, edgeLabel, edgeType, ...
            'VariableNames', {'EndNodes', 'Label', 'Type'});
        G = graph(edgeTable);

        % 节点名字用于内部标识即可；节点标签单独控制（可隐藏虚拟节点标签）
        % 约定显示格式：N1, N2, ...
        G.Nodes.Name = arrayfun(@(i) sprintf('N%d', i), (1:numnodes(G))', 'UniformOutput', false);

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

        % 设置节点标签（隐藏 Inlet/Outlet 虚拟节点）
        nodeLabels = G.Nodes.Name;
        if hasInlet
            nodeLabels{sourceNode} = '';
        end
        if hasOutlet
            nodeLabels{sinkNode} = '';
        end
        h.NodeLabel = nodeLabels;
        h.NodeFontSize = 10;
        h.NodeFontWeight = 'bold';

        % 设置边标签
        h.EdgeLabel = G.Edges.Label;
        h.EdgeFontSize = 9;
        h.EdgeColor = [0.4 0.4 0.4];

        % 入风/回风“虚拟巷道”高亮显示
        if hasInlet
            inletEdgeIdx = find(G.Edges.Type == "inlet");
            highlight(h, 'Edges', inletEdgeIdx, 'EdgeColor', [0.0 0.6 0.0], 'LineWidth', 2.5);
            highlight(h, inlet_nodes, 'NodeColor', [0.0 0.6 0.0]);
            % 虚拟节点不强调显示（避免出现 Inlet/Outlet）
            highlight(h, sourceNode, 'NodeColor', [1 1 1], 'MarkerSize', 1);
        end
        if hasOutlet
            outletEdgeIdx = find(G.Edges.Type == "outlet");
            highlight(h, 'Edges', outletEdgeIdx, 'EdgeColor', [0.8 0.0 0.0], 'LineWidth', 2.5);
            highlight(h, outlet_nodes, 'NodeColor', [0.8 0.0 0.0]);
            highlight(h, sinkNode, 'NodeColor', [1 1 1], 'MarkerSize', 1);
        end

        % 设置标题和坐标轴
        title(ax, sprintf('通风网络拓扑图\n节点数: %d | 分支数: %d', N, B), ...
              'FontSize', 12, 'FontWeight', 'bold');
        axis(ax, 'equal');
        axis(ax, 'off');

        % 添加图例说明
        text(ax, 0.02, 0.98, sprintf('○ 节点ID（N1, N2, ...）\n━ 分支ID\n━ 绿色：入风巷道\n━ 红色：回风巷道'), ...
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


function [inlet_nodes, outlet_nodes] = readBoundaryNodesFromApp(app)
    inlet_nodes = [];
    outlet_nodes = [];

    try
        if isprop(app, 'EditField_2') && ~isempty(app.EditField_2)
            inlet_nodes = parseNodeList(app.EditField_2.Value);
        end
    catch
        inlet_nodes = [];
    end

    try
        if isprop(app, 'EditField_3') && ~isempty(app.EditField_3)
            outlet_nodes = parseNodeList(app.EditField_3.Value);
        end
    catch
        outlet_nodes = [];
    end
end


function [inlet_nodes, outlet_nodes] = readBoundaryNodesFromUIFigure(uifig)
    inlet_nodes = [];
    outlet_nodes = [];

    try
        inlet_nodes = readNodesByLabelText(uifig, ["入风节点", "入风"]);
    catch
        inlet_nodes = [];
    end

    try
        outlet_nodes = readNodesByLabelText(uifig, ["回风节点", "回风"]);
    catch
        outlet_nodes = [];
    end
end


function nodes = readNodesByLabelText(uifig, keywords)
    nodes = [];
    labels = findall(uifig, '-isa', 'matlab.ui.control.Label');
    if isempty(labels)
        return;
    end

    targetLabel = [];
    for i = 1:numel(labels)
        txt = "";
        try
            txt = string(labels(i).Text);
        catch
        end
        if strlength(txt) == 0
            continue;
        end
        if any(contains(txt, keywords))
            targetLabel = labels(i);
            break;
        end
    end

    if isempty(targetLabel) || ~isprop(targetLabel, 'Layout')
        return;
    end

    parent = targetLabel.Parent;
    if isempty(parent)
        return;
    end

    row = [];
    try
        row = targetLabel.Layout.Row;
    catch
        row = [];
    end
    if isempty(row)
        return;
    end

    fields = findall(parent, '-isa', 'matlab.ui.control.NumericEditField');
    for i = 1:numel(fields)
        try
            if isprop(fields(i), 'Layout') && isequal(fields(i).Layout.Row, row) && isequal(fields(i).Layout.Column, 2)
                nodes = parseNodeList(fields(i).Value);
                return;
            end
        catch
        end
    end
end


function nodes = parseNodeList(value)
    nodes = [];
    if isempty(value)
        return;
    end

    if isnumeric(value)
        nodes = value(:);
        nodes = nodes(isfinite(nodes));
        return;
    end

    str = strtrim(string(value));
    if strlength(str) == 0
        return;
    end

    nodes = str2double(split(str, ','));
    nodes = nodes(:);
    nodes = nodes(isfinite(nodes));
end
