function deletedCount = delete_selected_rows_from_uitable(uitableHandle, options)
%DELETE_SELECTED_ROWS_FROM_UITABLE 删除 UITable 中选中的行
%
% 在 App Designer 的"删除行"按钮回调里：
%   addpath('General Problem Solver');
%   gps.ui.delete_selected_rows_from_uitable(app.UITable);
%
% 输入：
%   uitableHandle: matlab.ui.control.Table
%   options: 可选参数结构体
%            .reindexID    - 是否重新排列 ID (默认 true)
%            .confirm      - 是否显示确认对话框 (默认 false)
%            .confirmMsg   - 自定义确认消息
%
% 输出：
%   deletedCount: 删除的行数
%
% 功能：
%   - 删除 UITable 中当前选中的行
%   - 支持单行或多行删除
%   - 可选择是否重新排列 ID（连续编号）
%   - 可选择是否显示确认对话框
%   - 自动处理边界情况（无选中、空表格）
%
% 版本：
%   v1.0 (2025-12-18) - 初始版本
%
% 作者：MATLAB 通风工程专家助手

    arguments
        uitableHandle (1,1) matlab.ui.control.Table
        options.reindexID (1,1) logical = true
        options.confirm (1,1) logical = false
        options.confirmMsg (1,1) string = ""
    end

    % 初始化返回值
    deletedCount = 0;

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

    % 3. 检查表格是否为空
    if isempty(currentData) || height(currentData) == 0
        if ~isempty(uifig)
            uialert(uifig, '表格为空，无法删除', '提示');
        else
            warning('表格为空，无法删除');
        end
        return;
    end

    % 4. 获取选中的行
    selectedRows = getSelectedRows(uitableHandle);

    % 5. 检查是否有选中行
    if isempty(selectedRows)
        if ~isempty(uifig)
            uialert(uifig, '请先选中要删除的行\n（点击行号或单元格）', '提示');
        else
            warning('未选中任何行');
        end
        return;
    end

    % 6. 确认对话框（可选）
    if options.confirm
        numRows = length(selectedRows);

        % 构建确认消息
        if strlength(options.confirmMsg) > 0
            confirmMsg = options.confirmMsg;
        else
            if numRows == 1
                rowIDs = currentData{selectedRows, 1};  % 第一列为 ID
                confirmMsg = sprintf('确定要删除第 %d 行（ID=%d）吗？', ...
                    selectedRows, rowIDs);
            else
                confirmMsg = sprintf('确定要删除选中的 %d 行吗？', numRows);
            end
        end

        % 显示确认对话框
        if ~isempty(uifig)
            choice = uiconfirm(uifig, confirmMsg, '确认删除', ...
                'Options', {'删除', '取消'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2, ...
                'Icon', 'warning');

            if strcmp(choice, '取消')
                fprintf('用户取消删除操作\n');
                return;
            end
        end
    end

    % 7. 执行删除
    try
        % 删除选中的行
        currentData(selectedRows, :) = [];

        % 8. 是否重新排列 ID
        if options.reindexID && ~isempty(currentData)
            % 重新分配 ID（1, 2, 3, ...）
            if istable(currentData)
                currentData{:, 1} = (1:height(currentData))';
            else
                currentData(:, 1) = (1:size(currentData, 1))';
            end
        end

        % 9. 更新表格数据
        uitableHandle.Data = currentData;

        deletedCount = length(selectedRows);

        % 10. 清空选择状态
        uitableHandle.Selection = [];

        % 11. 输出提示
        fprintf('✓ 已删除 %d 行\n', deletedCount);

    catch ME
        % 删除失败
        if ~isempty(uifig)
            uialert(uifig, sprintf('删除失败: %s', ME.message), '错误');
        else
            error('删除失败: %s', ME.message);
        end
    end
end


%% ========== 子函数：获取选中的行号 ==========
function selectedRows = getSelectedRows(uitableHandle)
%GETSELECTEDROWS 获取 UITable 中选中的行号（去重）
%
% UITable 的 Selection 属性返回 [行, 列] 矩阵
% 需要提取唯一的行号

    selectedRows = [];

    % 获取选中的单元格
    selection = uitableHandle.Selection;

    if isempty(selection)
        return;
    end

    % 提取行号（第一列）
    rowIndices = selection(:, 1);

    % 去重并排序
    selectedRows = unique(rowIndices);
end
