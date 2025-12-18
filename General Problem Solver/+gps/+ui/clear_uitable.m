function success = clear_uitable(uitableHandle, options)
%CLEAR_UITABLE 清空 UITable 中的所有数据
%
% 在 App Designer 的"清空"按钮回调里：
%   addpath('General Problem Solver');
%   gps.ui.clear_uitable(app.UITable, 'confirm', true);
%
% 输入：
%   uitableHandle: matlab.ui.control.Table
%   options: 可选参数结构体
%            .confirm      - 是否显示确认对话框 (默认 true)
%            .confirmMsg   - 自定义确认消息
%
% 输出：
%   success: 是否成功清空（true/false）
%
% 功能：
%   - 清空 UITable 中的所有数据
%   - 可选择是否显示确认对话框（默认显示）
%   - 自动处理边界情况（空表格）
%   - 清空后重置表格状态
%
% 示例：
%   % 带确认对话框（推荐）
%   success = gps.ui.clear_uitable(app.UITable, 'confirm', true);
%
%   % 不带确认对话框
%   success = gps.ui.clear_uitable(app.UITable, 'confirm', false);
%
% 版本：
%   v1.0 (2025-12-18) - 初始版本
%
% 作者：MATLAB 通风工程专家助手

    arguments
        uitableHandle (1,1) matlab.ui.control.Table
        options.confirm (1,1) logical = true
        options.confirmMsg (1,1) string = ""
    end

    % 初始化返回值
    success = false;

    % 1. 获取 UIFigure（用于对话框）
    uifig = [];
    try
        uifig = ancestor(uitableHandle, 'matlab.ui.Figure', 'toplevel');
    catch
        try
            uifig = ancestor(uitableHandle, 'figure');
        catch
        end
    end

    % 2. 获取当前表格数据
    currentData = uitableHandle.Data;

    % 3. 检查表格是否已经为空
    if isempty(currentData) || height(currentData) == 0
        if ~isempty(uifig)
            uialert(uifig, '表格已经为空', '提示');
        else
            warning('表格已经为空');
        end
        success = true;  % 已经是空的，算作成功
        return;
    end

    % 4. 记录当前行数（用于提示）
    numRows = height(currentData);

    % 5. 确认对话框（默认显示）
    if options.confirm
        % 构建确认消息
        if strlength(options.confirmMsg) > 0
            confirmMsg = options.confirmMsg;
        else
            confirmMsg = sprintf('确定要清空表格中的所有数据吗？\n\n当前共有 %d 行数据。\n此操作不可撤销！', numRows);
        end

        % 显示确认对话框
        if ~isempty(uifig)
            choice = uiconfirm(uifig, confirmMsg, '确认清空', ...
                'Options', {'清空', '取消'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2, ...
                'Icon', 'warning');

            if strcmp(choice, '取消')
                fprintf('用户取消清空操作\n');
                return;
            end
        else
            % 命令行环境，使用 questdlg
            choice = questdlg(confirmMsg, '确认清空', '清空', '取消', '取消');
            if ~strcmp(choice, '清空')
                fprintf('用户取消清空操作\n');
                return;
            end
        end
    end

    % 6. 执行清空操作
    try
        % 清空数据（保留列结构）
        if istable(currentData)
            % 如果是 table 类型，创建空的同类型 table
            emptyData = currentData([], :);
        else
            % 如果是矩阵或其他类型，直接清空
            emptyData = [];
        end

        % 更新表格数据
        uitableHandle.Data = emptyData;

        % 清空选择状态
        uitableHandle.Selection = [];

        % 标记成功
        success = true;

        % 输出提示
        fprintf('✓ 已清空表格（删除了 %d 行数据）\n', numRows);

        % 显示成功提示（可选）
        if ~isempty(uifig) && options.confirm
            uialert(uifig, sprintf('已成功清空 %d 行数据', numRows), '完成', 'Icon', 'success');
        end

    catch ME
        % 清空失败
        success = false;

        if ~isempty(uifig)
            uialert(uifig, sprintf('清空失败: %s', ME.message), '错误');
        else
            error('清空失败: %s', ME.message);
        end
    end
end
