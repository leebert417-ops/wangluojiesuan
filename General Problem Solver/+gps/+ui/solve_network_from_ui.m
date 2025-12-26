function [Q, Results, success] = solve_network_from_ui(app)
%SOLVE_NETWORK_FROM_UI 从 App Designer UI 组件获取数据并求解通风网络
%
% 在 App Designer 的"求解"按钮回调里：
%   [Q, Results, success] = gps.ui.solve_network_from_ui(app);
%
% 输入：
%   app: App Designer 应用对象，需要包含以下组件：
%        - app.UITable          : 分支数据表格（ID, 起点, 终点, 风阻）
%        - app.EditField        : 初始风量（系统总风量）
%        - app.EditField_2      : 入风节点（逗号分隔，如 "1" 或 "1,2"）
%        - app.EditField_3      : 回风节点（逗号分隔）
%        - app.EditField_4      : 最大迭代数
%        - app.EditField_5      : 收敛容差
%        - app.DropDown       : 求解方法（'Hardy Cross' 等）
%        - app.DropDown_2         : 信息显示（'显示' 或 '隐藏'）
%        - app.Slider           : 松弛因子（0~2）
%        - app.UIFigure         : 主窗口（用于弹窗）
%
% 输出：
%   Q       : 各分支风量（B×1 向量）
%   Results : 求解结果结构体
%   success : 是否求解成功（true/false）
%
% 功能：
%   - 从 UI 组件提取所有求解参数
%   - 验证数据有效性（10+ 项检查）
%   - 调用通风网络求解器
%   - 自动显示结果和错误信息
%
% 版本：
%   v1.0 (2025-12-18) - 初始版本
%
% 作者：东北大学 资源与土木工程学院 智采2201班 学生

    % 初始化返回值
    Q = [];
    Results = struct();
    success = false;

    % ========== 1. 获取 UIFigure（用于弹窗） ==========
    uifig = [];
    if isprop(app, 'UIFigure') && isvalid(app.UIFigure)
        uifig = app.UIFigure;
    end

    try
        % ========== 2. 从 UITable 获取分支数据 ==========
        if ~isprop(app, 'UITable') || isempty(app.UITable.Data)
            error('UITable 为空，请先导入或添加分支数据');
        end

        branchData = app.UITable.Data;

        % 验证表格结构
        if ~istable(branchData)
            error('UITable 数据必须为 table 类型');
        end

        if width(branchData) < 4
            error('UITable 必须包含 4 列（ID, 起点, 终点, 风阻）');
        end

        if height(branchData) == 0
            error('UITable 无数据，请先添加分支');
        end

        % 提取分支数据（假设列名为 ID/起点/终点/风阻）
        colNames = branchData.Properties.VariableNames;

        % 自动识别列（支持不同列名）
        idCol = find(contains(lower(colNames), {'id', '编号'}), 1);
        fromCol = find(contains(lower(colNames), {'起点', 'from', 'start'}), 1);
        toCol = find(contains(lower(colNames), {'终点', 'to', 'end'}), 1);
        rCol = find(contains(lower(colNames), {'风阻', 'resistance', 'r'}), 1);

        if isempty(idCol), idCol = 1; end
        if isempty(fromCol), fromCol = 2; end
        if isempty(toCol), toCol = 3; end
        if isempty(rCol), rCol = 4; end

        % 构造 Branches 结构体
        Branches = struct();
        Branches.id = branchData{:, idCol};
        Branches.from_node = branchData{:, fromCol};
        Branches.to_node = branchData{:, toCol};
        Branches.R = branchData{:, rCol};

        % 验证分支数据
        B = length(Branches.id);

        % 检查 ID 连续性
        if ~isequal(sort(Branches.id(:)), (1:B)')
            error('分支 ID 必须为 1~%d 的连续编号（当前缺失或重复）', B);
        end

        % 检查节点编号有效性
        if any(Branches.from_node < 1) || any(Branches.to_node < 1)
            error('节点编号必须 >= 1');
        end

        if any(~isfinite(Branches.from_node)) || any(~isfinite(Branches.to_node))
            error('节点编号必须为有限整数');
        end

        % 检查自环
        if any(Branches.from_node == Branches.to_node)
            selfLoops = find(Branches.from_node == Branches.to_node);
            error('分支 %s 存在自环（起点=终点）', mat2str(selfLoops'));
        end

        % 检查风阻有效性
        if any(~isfinite(Branches.R)) || any(Branches.R <= 0)
            error('风阻必须为有限正数');
        end

        % ========== 3. 获取边界条件 ==========
        Boundary = struct();

        % 获取总风量
        if ~isprop(app, 'EditField') || isempty(app.EditField.Value)
            error('请输入初始风量（系统总风量）');
        end
        Boundary.Q_total = str2double(string(app.EditField.Value));
        if ~isfinite(Boundary.Q_total) || Boundary.Q_total <= 0
            error('初始风量必须为正数（当前值：%s）', string(app.EditField.Value));
        end

        % 获取入风节点
        if ~isprop(app, 'EditField_2') || isempty(app.EditField_2.Value)
            error('请输入入风节点（如 1 或 1,2）');
        end
        inletStr = strtrim(string(app.EditField_2.Value));
        inlet_nodes = str2double(split(inletStr, ','));
        if any(~isfinite(inlet_nodes)) || any(inlet_nodes < 1)
            error('入风节点格式错误（当前值：%s）\n格式：逗号分隔的整数，如 "1" 或 "1,2"', inletStr);
        end
        Boundary.inlet_node = inlet_nodes;

        % 获取回风节点
        if ~isprop(app, 'EditField_3') || isempty(app.EditField_3.Value)
            error('请输入回风节点（如 5 或 5,6）');
        end
        outletStr = strtrim(string(app.EditField_3.Value));
        outlet_nodes = str2double(split(outletStr, ','));
        if any(~isfinite(outlet_nodes)) || any(outlet_nodes < 1)
            error('回风节点格式错误（当前值：%s）\n格式：逗号分隔的整数，如 "5" 或 "5,6"', outletStr);
        end
        Boundary.outlet_node = outlet_nodes;

        % 验证入/回风节点不重叠
        if any(ismember(Boundary.inlet_node, Boundary.outlet_node))
            error('入风节点与回风节点不能重叠');
        end

        % 验证节点编号在范围内
        N = max([Branches.from_node(:); Branches.to_node(:)]);
        if any(Boundary.inlet_node > N) || any(Boundary.outlet_node > N)
            error('入/回风节点编号超出网络节点范围 1~%d', N);
        end

        % ========== 4. 获取求解器选项 ==========
        SolverOptions = struct();

        % 最大迭代数
        if isprop(app, 'EditField_4') && ~isempty(app.EditField_4.Value)
            maxIter = str2double(string(app.EditField_4.Value));
            if isfinite(maxIter) && maxIter > 0
                SolverOptions.max_iter = round(maxIter);
            else
                % 无效值，使用默认值（不输出警告到命令行）
                SolverOptions.max_iter = 1000;
            end
        else
            SolverOptions.max_iter = 1000;
        end

        % 收敛容差
        if isprop(app, 'EditField_5') && ~isempty(app.EditField_5.Value)
            tol = str2double(string(app.EditField_5.Value));
            if isfinite(tol) && tol > 0
                SolverOptions.tolerance = tol;
            else
                % 无效值，使用默认值（不输出警告到命令行）
                SolverOptions.tolerance = 1e-3;
            end
        else
            SolverOptions.tolerance = 1e-3;
        end

        % 松弛因子
        if isprop(app, 'Slider') && ~isempty(app.Slider.Value)
            relax = app.Slider.Value;
            if isfinite(relax) && relax > 0 && relax <= 2
                SolverOptions.relaxation = relax;
            else
                % 超出范围，使用默认值（不输出警告到命令行）
                SolverOptions.relaxation = 1.0;
            end
        else
            SolverOptions.relaxation = 1.0;
        end

        % 求解方法（预留，当前只有 Hardy Cross）
        method = "";
        if isprop(app, 'DropDown') && ~isempty(app.DropDown) && ~isempty(app.DropDown.Value)
            method = string(app.DropDown.Value);
            % 不再输出警告，静默处理
        end

        % 图表输出（VERBOSE）：决定是否输出柱状图和导出 CSV
        verboseOutput = false;  % 默认不输出
        if isprop(app, 'DropDown_2') && ~isempty(app.DropDown_2) && ~isempty(app.DropDown_2.Value)
            verboseStr = lower(strtrim(string(app.DropDown_2.Value)));
            verboseOutput = any(verboseStr == ["true", "1", "yes", "y"]) || contains(verboseStr, ["显示", "show"]);
        elseif isprop(app, 'DropDown') && ~isempty(app.DropDown) && ~isempty(app.DropDown.Value)
            % 兼容旧 UI：若没有 DropDown_2，则尝试从 DropDown 读取
            verboseStr = lower(strtrim(string(app.DropDown.Value)));
            verboseOutput = any(verboseStr == ["true", "1", "yes", "y"]) || contains(verboseStr, ["显示", "show"]);
        end

        SolverOptions.verbose = false;  % 禁止求解器在命令行输出（但保留 verboseOutput 用于后处理）

        % ========== 5. 调用求解器 ==========
        % 向 TextArea 输出求解开始信息
        if isprop(app, 'TextArea') && ~isempty(app.TextArea)
            msg = sprintf('[%s] 开始求解通风网络\n分支数：%d | 节点数：%d | 总风量：%.6g m³/s\n入风节点：%s | 回风节点：%s\n最大迭代数：%d | 收敛容差：%.2e | 松弛因子：%.2f\n', ...
                datetime('now', 'Format', 'HH:mm:ss'), B, N, Boundary.Q_total, ...
                mat2str(Boundary.inlet_node), mat2str(Boundary.outlet_node), ...
                SolverOptions.max_iter, SolverOptions.tolerance, SolverOptions.relaxation);
            gps.ui.append_to_textarea(app.TextArea, msg);
        end

        % 调用求解器
        [Q, Results] = gps.logic.ventilation_network_solver_generic( ...
            Branches, Boundary, SolverOptions);

        success = Results.converged;

        % ========== 6. 更新 UI 输出（结果表格 + 有向网络图） ==========
        try
            update_results_ui(app, Branches, Q, Results);
        catch ME_ui
            % UI 输出失败不影响求解结果
            if isprop(app, 'TextArea') && ~isempty(app.TextArea)
                msg = sprintf('[%s] ? 结果展示失败：%s\n', datetime('now', 'Format', 'HH:mm:ss'), ME_ui.message);
                gps.ui.append_to_textarea(app.TextArea, msg);
            end
        end

        % ========== 6. 显示结果 ==========
        if success
            % 向 TextArea 输出成功信息和详细结果
            if isprop(app, 'TextArea') && ~isempty(app.TextArea)
                % 构建详细结果消息
                msg = sprintf('[%s] ✓ 求解成功！\n迭代次数：%d | 最大回路残差：%.6e | 最大节点残差：%.6e\n', ...
                    datetime('now', 'Format', 'HH:mm:ss'), Results.iterations, Results.max_residual, max(abs(Results.node_residual)));

                % 添加分支风量信息（所有分支）
                msg = [msg, sprintf('各分支风量：\n')];
                for i = 1:B
                    msg = [msg, sprintf('  分支 %2d：Q = %10.6f m³/s\n', i, Results.Q_flow_aligned(i))];
                end

                gps.ui.append_to_textarea(app.TextArea, msg);
            end

            % ========== 7. VERBOSE 模式：输出详细结果 ==========
            if verboseOutput
                try
                    % 7.1 绘制柱状图（风量和风压降）
                    gps.ui.plot_solution_bars(Branches, abs(Q), Results);

                    % 7.2 导出结果到 CSV 文件
                    filePath = gps.ui.export_solution_to_csv(Branches, abs(Q), Results);

                    % 7.3 向 TextArea 输出 VERBOSE 信息
                    if isprop(app, 'TextArea') && ~isempty(app.TextArea) && strlength(filePath) > 0
                        msg = sprintf('[%s] ✓ VERBOSE 模式：已生成柱状图和结果文件\n文件路径：%s\n', ...
                            datetime('now', 'Format', 'HH:mm:ss'), filePath);
                        gps.ui.append_to_textarea(app.TextArea, msg);
                    end

                catch ME_verbose
                    % VERBOSE 输出失败不影响求解结果
                    if isprop(app, 'TextArea') && ~isempty(app.TextArea)
                        msg = sprintf('[%s] ⚠ VERBOSE 模式输出失败：%s\n', ...
                            datetime('now', 'Format', 'HH:mm:ss'), ME_verbose.message);
                        gps.ui.append_to_textarea(app.TextArea, msg);
                    end
                end
            end
        else
            % 向 TextArea 输出警告信息
            if isprop(app, 'TextArea') && ~isempty(app.TextArea)
                msg = sprintf('[%s] ⚠ 求解未完全收敛\n迭代次数：%d | 最大残差：%.6e\n建议：增加最大迭代数或调整松弛因子\n', ...
                    datetime('now', 'Format', 'HH:mm:ss'), Results.iterations, Results.max_residual);
                gps.ui.append_to_textarea(app.TextArea, msg);
            end
        end

    catch ME
        % ========== 错误处理 ==========
        success = false;

        % 向 TextArea 输出错误信息
        if isprop(app, 'TextArea') && ~isempty(app.TextArea)
            msg = sprintf('[%s] ✗ 求解失败\n错误：%s\n', datetime('now', 'Format', 'HH:mm:ss'), ME.message);
            gps.ui.append_to_textarea(app.TextArea, msg);
        end

        % 重新抛出错误（可选，便于调试）
        % rethrow(ME);
    end
end


function update_results_ui(app, Branches, Q, Results)
    % 1) 在 UITable2 中展示求解结果（如存在）
    if isprop(app, 'UITable2') && ~isempty(app.UITable2)
        T = build_results_table(Branches, Q, Results);
        app.UITable2.Data = T;
        if isprop(app.UITable2, 'ColumnName')
            app.UITable2.ColumnName = {'巷道ID', '起点', '终点', '风阻', '风量', '风压降'};
        end
        if isprop(app.UITable2, 'ColumnEditable')
            app.UITable2.ColumnEditable = false;
        end
    end

    % 2) 在 UIAxes 中绘制有向通风网络图（如存在）
    if isprop(app, 'UIAxes') && ~isempty(app.UIAxes) && isprop(app, 'UITable') && ~isempty(app.UITable)
        gps.ui.plot_network_digraph(app.UITable, Q, Results, app.UIAxes, app);
    end
end


function T = build_results_table(Branches, Q, Results)
    % 优先使用求解器提供的“风向对齐”结果（Q>=0 且起止点已同步修正）
    Branches_out = Branches;
    Q_out = Q(:);
    if isfield(Results, 'Branches_flow_aligned') && isfield(Results, 'Q_flow_aligned')
        Branches_out = Results.Branches_flow_aligned;
        Q_out = Results.Q_flow_aligned(:);
    else
        neg = (Q_out < 0);
        tmp = Branches_out.from_node(neg);
        Branches_out.from_node(neg) = Branches_out.to_node(neg);
        Branches_out.to_node(neg) = tmp;
        Q_out(neg) = -Q_out(neg);
    end

    % 风压降（正值）
    B = numel(Branches_out.id);
    if isfield(Results, 'pressure_drop') && numel(Results.pressure_drop) == B
        deltaP = Results.pressure_drop(:);
    else
        deltaP = Branches_out.R(:) .* (abs(Q_out(:)) .^ 2);
    end

    T = table( ...
        Branches_out.id(:), ...
        Branches_out.from_node(:), ...
        Branches_out.to_node(:), ...
        Branches_out.R(:), ...
        Q_out(:), ...
        deltaP(:), ...
        'VariableNames', {'branch_id', 'from_node', 'to_node', 'resistance', 'flow_rate', 'pressure_drop'} ...
    );
end
