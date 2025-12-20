function DG = plot_network_digraph(uitableHandle, Q, Results, axesHandle, app)
%PLOT_NETWORK_DIGRAPH 使用求解结果绘制通风网络有向图（digraph）
%
% 在 App Designer 的按钮回调里：
%   % 已完成求解后（Q/Results 来自 gps.ui.solve_network_from_ui）
%   gps.ui.plot_network_digraph(app.UITable, Q, Results, app.UIAxes, app);
%
% 输入：
%   uitableHandle: matlab.ui.control.Table（包含 ID/起点/终点 等列）
%   Q: 各分支风量（B×1；允许为负，负值表示与起点->终点相反）
%   Results: 求解结果结构体（可选字段：pressure_drop）
%   axesHandle: matlab.ui.control.UIAxes 或 axes 句柄（可选）
%   app: App Designer app 对象（可选，用于自动读取入/回风节点）
%
% 输出：
%   DG: digraph 对象（有向图；边方向按实际风流方向修正）
%
% 功能：
%   - 从 UITable 读取分支 ID、起点(from)、终点(to)
%   - 根据 Q 的符号修正边方向：Q<0 则交换起止点，并以 |Q| 作为该边风量
%   - 使用 Edge Table 构建 digraph（可保留平行边）
%   - 按参考脚本风格绘制入风/回风“虚拟巷道”（绿色/红色）
%
% 版本：
%   v1.0 (2025-12-20) - 初始版本（仿照 plot_network_graph）

    arguments
        uitableHandle (1,1) matlab.ui.control.Table
        Q (:,1) double
        Results (1,1) struct = struct()
        axesHandle = []
        app = []
    end

    DG = [];

    % 1. 获取 UIFigure（用于弹窗，可选）
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

        if ~istable(branchData)
            error('表格数据必须为 table 类型');
        end
        if width(branchData) < 3
            error('表格必须至少包含 3 列（ID, 起点, 终点）');
        end
        if height(branchData) == 0
            error('表格无数据，请先添加分支');
        end

        % ========== 3. 提取 ID / 起点 / 终点 ==========
        colNames = branchData.Properties.VariableNames;

        idCol = find(contains(lower(colNames), {'id', '编号'}), 1);
        fromCol = find(contains(lower(colNames), {'起点', 'from', 'start'}), 1);
        toCol = find(contains(lower(colNames), {'终点', 'to', 'end'}), 1);

        if isempty(idCol), idCol = 1; end
        if isempty(fromCol), fromCol = 2; end
        if isempty(toCol), toCol = 3; end

        branch_ids = branchData{:, idCol};
        from_nodes = branchData{:, fromCol};
        to_nodes = branchData{:, toCol};

        B = length(branch_ids);
        if numel(Q) ~= B
            error('Q 的长度（%d）与分支数（%d）不匹配', numel(Q), B);
        end

        % ========== 4. 数据验证 ==========
        if any(~isfinite(from_nodes)) || any(~isfinite(to_nodes))
            error('节点编号必须为有限整数');
        end
        if any(from_nodes < 1) || any(to_nodes < 1)
            error('节点编号必须 >= 1');
        end
        if any(from_nodes == to_nodes)
            selfLoops = find(from_nodes == to_nodes);
            error('分支 %s 存在自环（起点=终点），无法绘图', mat2str(selfLoops'));
        end

        N = max([from_nodes(:); to_nodes(:)]);

        % ========== 5. 读取入风/回风节点（从 UI 自动获取，可选）==========
        inlet_nodes = [];
        outlet_nodes = [];
        if nargin >= 5 && ~isempty(app)
            [inlet_nodes, outlet_nodes] = readBoundaryNodesFromApp(app);
        elseif ~isempty(uifig)
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

        % ========== 6. 使用 Q 修正边方向（Q<0 则反向）==========
        Q = Q(:);
        start_nodes = from_nodes(:);
        end_nodes = to_nodes(:);

        neg = (Q < 0);
        tmp = start_nodes(neg);
        start_nodes(neg) = end_nodes(neg);
        end_nodes(neg) = tmp;

        Q_abs = abs(Q);

        % 压差（可选，用于边属性；正值压降）
        dp_abs = nan(B, 1);
        if isfield(Results, 'pressure_drop') && numel(Results.pressure_drop) == B
            dp_abs = Results.pressure_drop(:);
        end

        % ========== 7. 构造 Edge Table 并建立 digraph ==========
        EndNodes = [start_nodes, end_nodes];
        edgeLabel = string(branch_ids(:)) + " (Q=" + compose('%.3g', Q_abs) + ")";
        edgeType = repmat("branch", B, 1);
        edgeFlow = Q_abs;
        edgeDp = dp_abs;

        hasInlet = ~isempty(inlet_nodes);
        hasOutlet = ~isempty(outlet_nodes);
        sourceNode = [];
        sinkNode = [];

        if hasInlet
            sourceNode = N + 1;
            EndNodes = [EndNodes; [repmat(sourceNode, numel(inlet_nodes), 1), inlet_nodes(:)]];
            edgeLabel = [edgeLabel; repmat("入风巷道", numel(inlet_nodes), 1)];
            edgeType = [edgeType; repmat("inlet", numel(inlet_nodes), 1)];
            edgeFlow = [edgeFlow; nan(numel(inlet_nodes), 1)];
            edgeDp = [edgeDp; nan(numel(inlet_nodes), 1)];
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
            edgeFlow = [edgeFlow; nan(numel(outlet_nodes), 1)];
            edgeDp = [edgeDp; nan(numel(outlet_nodes), 1)];
        end

        edgeTable = table(EndNodes, edgeLabel, edgeType, edgeFlow, edgeDp, ...
            'VariableNames', {'EndNodes', 'Label', 'Type', 'Flow', 'PressureDrop'});
        DG = digraph(edgeTable);

        DG.Nodes.Name = arrayfun(@(i) sprintf('N%d', i), (1:numnodes(DG))', 'UniformOutput', false);

        % ========== 8. 绘制有向图 ==========
        if isempty(axesHandle)
            figure('Name', '通风网络有向图', 'NumberTitle', 'off');
            ax = gca;
        else
            ax = axesHandle;
            cla(ax);
        end

        h = plot(ax, DG, 'LineWidth', 2, 'MarkerSize', 8, ...
            'NodeColor', [0.2 0.4 0.8], ...
            'EdgeColor', [0.3 0.3 0.3]);
        try
            h.ArrowSize = 12;
        catch
        end

        nodeLabels = DG.Nodes.Name;
        if hasInlet
            nodeLabels{sourceNode} = '';
        end
        if hasOutlet
            nodeLabels{sinkNode} = '';
        end
        h.NodeLabel = nodeLabels;
        h.NodeFontSize = 10;
        h.NodeFontWeight = 'bold';

        h.EdgeLabel = DG.Edges.Label;
        h.EdgeFontSize = 8;
        h.EdgeColor = [0.4 0.4 0.4];

        % 入风/回风巷道高亮
        if hasInlet
            inletEdgeIdx = find(DG.Edges.Type == "inlet");
            highlight(h, 'Edges', inletEdgeIdx, 'EdgeColor', [0.0 0.6 0.0], 'LineWidth', 2.5);
            highlight(h, inlet_nodes, 'NodeColor', [0.0 0.6 0.0]);
            highlight(h, sourceNode, 'NodeColor', [1 1 1], 'MarkerSize', 1);
        end
        if hasOutlet
            outletEdgeIdx = find(DG.Edges.Type == "outlet");
            highlight(h, 'Edges', outletEdgeIdx, 'EdgeColor', [0.8 0.0 0.0], 'LineWidth', 2.5);
            highlight(h, outlet_nodes, 'NodeColor', [0.8 0.0 0.0]);
            highlight(h, sinkNode, 'NodeColor', [1 1 1], 'MarkerSize', 1);
        end

        title(ax, sprintf('通风网络有向图（按风向修正）\n节点数: %d | 分支数: %d', N, B), ...
            'FontSize', 12, 'FontWeight', 'bold');
        axis(ax, 'equal');
        axis(ax, 'off');

        text(ax, 0.02, 0.98, sprintf('○ 节点ID（N1, N2, ...）\n→ 边方向为实际风流方向（Q<0 自动反向）\n边标签：分支ID + |Q|\n绿色：入风巷道\n红色：回风巷道'), ...
            'Units', 'normalized', 'VerticalAlignment', 'top', ...
            'FontSize', 9, 'Color', [0.5 0.5 0.5], ...
            'BackgroundColor', 'white', 'EdgeColor', [0.7 0.7 0.7]);

    catch ME
        if ~isempty(uifig)
            try
                uialert(uifig, ...
                    sprintf('绘图失败\n\n错误: %s', ME.message), ...
                    '绘图失败', 'Icon', 'error');
                return;
            catch
            end
        end
        rethrow(ME);
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
