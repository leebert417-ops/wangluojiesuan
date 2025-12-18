% 完整示例：从UI获取数据并求解通风网络
% ==========================================
% 本示例展示如何在 App Designer 按钮回调中使用求解功能
% ==========================================

%% 示例 1：基本求解（在"求解"按钮回调中）

function SolveButtonPushed(app, event)
    % 调用求解函数
    [Q, Results, success] = gps.ui.solve_network_from_ui(app);

    if success
        fprintf('✓ 求解成功！\n');
        fprintf('  迭代次数：%d\n', Results.iterations);
        fprintf('  最大残差：%.6e\n', Results.max_residual);
    end
end

%% 示例 2：求解后显示结果到表格

function SolveButtonPushed(app, event)
    % 调用求解函数
    [Q, Results, success] = gps.ui.solve_network_from_ui(app);

    if success
        % 将风量结果添加到 UITable 的新列
        app.UITable.Data.风量 = Q;

        % 添加压降列
        app.UITable.Data.压降 = Results.pressure_diff_signed;

        % 更新状态标签
        app.StatusLabel.Text = sprintf('求解成功（迭代 %d 次）', Results.iterations);
        app.StatusLabel.FontColor = [0 0.6 0];  % 绿色
    end
end

%% 示例 3：求解前禁用按钮，求解后启用

function SolveButtonPushed(app, event)
    % 禁用求解按钮
    app.SolveButton.Enable = 'off';
    app.SolveButton.Text = '求解中...';
    drawnow;

    try
        % 调用求解函数
        [Q, Results, success] = gps.ui.solve_network_from_ui(app);

        if success
            % 显示结果
            app.ResultsTextArea.Value = sprintf( ...
                '求解成功！\n\n' + ...
                '迭代次数：%d\n' + ...
                '最大回路残差：%.6e\n' + ...
                '最大节点残差：%.6e\n', ...
                Results.iterations, ...
                Results.max_residual, ...
                max(abs(Results.node_residual)));
        end

    catch ME
        % 错误处理
        uialert(app.UIFigure, ME.message, '错误');
    end

    % 恢复按钮
    app.SolveButton.Enable = 'on';
    app.SolveButton.Text = '求解';
end

%% 示例 4：求解后绘制收敛曲线

function SolveButtonPushed(app, event)
    % 调用求解函数
    [Q, Results, success] = gps.ui.solve_network_from_ui(app);

    if success
        % 绘制收敛曲线（如果有 UIAxes 组件）
        if isfield(app, 'UIAxes')
            semilogy(app.UIAxes, 1:Results.iterations, Results.residual_history);
            xlabel(app.UIAxes, '迭代次数');
            ylabel(app.UIAxes, '最大回路残差');
            title(app.UIAxes, 'Hardy Cross 收敛曲线');
            grid(app.UIAxes, 'on');
        end
    end
end

%% 示例 5：求解后保存结果

function SolveButtonPushed(app, event)
    % 调用求解函数
    [Q, Results, success] = gps.ui.solve_network_from_ui(app);

    if success
        % 自动保存结果
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        filename = sprintf('results_%s.mat', timestamp);
        save(filename, 'Q', 'Results');

        uialert(app.UIFigure, ...
            sprintf('结果已保存到：\n%s', filename), ...
            '保存成功', 'Icon', 'success');
    end
end

%% 示例 6：完整的 App Designer startupFcn 配置

function startupFcn(app)
    % 添加路径
    addpath('General Problem Solver');

    % 设置 UITable 属性
    app.UITable.ColumnName = {'ID', '起点', '终点', '风阻'};
    app.UITable.ColumnEditable = [false, true, true, true];
    app.UITable.ColumnWidth = {50, 80, 80, 100};
    app.UITable.SelectionType = 'row';

    % 设置默认求解参数
    app.EditField.Value = 100;                 % 初始风量 (m³/s)
    app.EditField_2.Value = '1';               % 入风节点
    app.EditField_3.Value = '10';              % 回风节点
    app.EditField_4.Value = 1000;              % 最大迭代数
    app.EditField_5.Value = 0.001;             % 收敛容差
    app.Slider.Value = 1.0;                    % 松弛因子
    app.DropDown.Value = '显示';               % 信息显示
    app.DropDown_2.Value = 'Hardy Cross';      % 求解方法

    % 配置 Slider 范围
    app.Slider.Limits = [0 2];
    app.Slider.MajorTicks = [0 0.5 1.0 1.5 2.0];

    % 配置 DropDown 选项
    app.DropDown.Items = {'显示', '隐藏'};
    app.DropDown_2.Items = {'Hardy Cross'};

    % 初始状态
    app.StatusLabel.Text = '就绪';
    app.SolveButton.Enable = 'off';  % 初始禁用求解按钮
end

%% 示例 7：导入数据后自动启用求解按钮

function ImportButtonPushed(app, event)
    % 导入数据
    T = gps.ui.import_branches_csv_to_uitable(app.UITable);

    if ~isempty(T)
        % 设置列可编辑性
        app.UITable.ColumnEditable = [false, true, true, true];

        % 启用求解按钮
        app.SolveButton.Enable = 'on';

        % 更新状态
        app.StatusLabel.Text = sprintf('已导入 %d 行数据', height(T));
    end
end

%% 示例 8：参数扫描（批量求解不同风量）

function ParameterScanButtonPushed(app, event)
    % 扫描不同的总风量
    Q_values = 50:10:150;  % 50, 60, ..., 150 m³/s
    results_all = cell(length(Q_values), 1);

    % 禁用其他按钮
    app.SolveButton.Enable = 'off';

    for i = 1:length(Q_values)
        % 设置风量
        app.EditField.Value = Q_values(i);

        % 更新进度
        app.StatusLabel.Text = sprintf('参数扫描：%d/%d', i, length(Q_values));
        drawnow;

        % 求解
        [Q, Results, success] = gps.ui.solve_network_from_ui(app);

        if success
            results_all{i} = Results;
        end
    end

    % 恢复按钮
    app.SolveButton.Enable = 'on';
    app.StatusLabel.Text = sprintf('参数扫描完成（%d 个案例）', length(Q_values));

    % 保存结果
    save('parameter_scan_results.mat', 'Q_values', 'results_all');
end

%% 示例 9：完整的按钮回调配置（推荐）

% 导入按钮
function ImportButtonPushed(app, event)
    T = gps.ui.import_branches_csv_to_uitable(app.UITable);
    if ~isempty(T)
        app.UITable.ColumnEditable = [false, true, true, true];
        app.SolveButton.Enable = 'on';
    end
end

% 添加新行按钮
function AddRowButtonPushed(app, event)
    gps.ui.add_new_row_to_uitable(app.UITable);
    app.SolveButton.Enable = 'on';
end

% 删除选中行按钮
function DeleteRowButtonPushed(app, event)
    gps.ui.delete_selected_rows_from_uitable(app.UITable, 'confirm', true);
    if isempty(app.UITable.Data)
        app.SolveButton.Enable = 'off';
    end
end

% 清空按钮
function ClearButtonPushed(app, event)
    gps.ui.clear_uitable(app.UITable, 'confirm', true);
    app.SolveButton.Enable = 'off';
end

% 导出按钮
function ExportButtonPushed(app, event)
    gps.ui.export_uitable_to_branches_csv(app.UITable);
end

% 求解按钮（完整版）
function SolveButtonPushed(app, event)
    % 禁用按钮
    app.SolveButton.Enable = 'off';
    app.SolveButton.Text = '求解中...';
    app.StatusLabel.Text = '正在求解...';
    drawnow;

    try
        % 调用求解函数
        [Q, Results, success] = gps.ui.solve_network_from_ui(app);

        if success
            % 更新 UITable（添加风量列）
            app.UITable.Data.风量 = Q;
            app.UITable.Data.压降 = Results.pressure_diff_signed;

            % 更新状态
            app.StatusLabel.Text = sprintf('求解成功（迭代 %d 次）', Results.iterations);
            app.StatusLabel.FontColor = [0 0.6 0];

            % 保存到 app 属性（供其他功能使用）
            app.LastResults = Results;
            app.LastQ = Q;
        else
            app.StatusLabel.Text = '求解未完全收敛';
            app.StatusLabel.FontColor = [1 0.5 0];
        end

    catch ME
        % 错误处理
        app.StatusLabel.Text = sprintf('求解失败：%s', ME.message);
        app.StatusLabel.FontColor = [1 0 0];
    end

    % 恢复按钮
    app.SolveButton.Enable = 'on';
    app.SolveButton.Text = '求解';
end
