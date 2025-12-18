function newRowIndex = add_new_row_to_uitable(uitableHandle)
%ADD_NEW_ROW_TO_UITABLE 在 UITable 末尾添加新行
%
% 在 App Designer 的"添加行"/"新建"按钮回调里：
%   addpath('General Problem Solver');
%   gps.ui.add_new_row_to_uitable(app.UITable);
%
% 输入：
%   uitableHandle: matlab.ui.control.Table
%
% 输出：
%   newRowIndex: 新添加行的索引（行号）
%
% 功能：
%   - 在表格末尾添加新的空白行
%   - ID 自动递增（基于当前最大 ID + 1）
%   - 其他列（起点、终点、风阻）填充默认值
%   - 自动滚动到新行（可选）
%   - 设置表格可编辑状态
%
% 版本：
%   v1.0 (2025-12-18) - 初始版本
%
% 作者：东北大学 资源与土木工程学院 智采2201班 学生

    arguments
        uitableHandle (1,1) matlab.ui.control.Table
    end

    % 1. 获取当前表格数据
    currentData = uitableHandle.Data;

    % 2. 判断当前数据是否为空
    if isempty(currentData) || height(currentData) == 0
        % 空表格：创建第一行
        newID = 1;
        numRows = 0;
    else
        % 非空表格：计算新 ID
        % 检查数据类型
        if istable(currentData)
            % 数据为 table 类型
            existingIDs = currentData{:, 1};  % 第一列为 ID
        else
            % 数据为矩阵类型
            existingIDs = currentData(:, 1);
        end

        % 计算新 ID（最大值 + 1）
        if isempty(existingIDs)
            newID = 1;
        else
            newID = max(existingIDs) + 1;
        end

        numRows = height(currentData);
    end

    % 3. 创建新行数据
    % ID: 自动递增
    % 起点、终点: 0（用户需要编辑）
    % 风阻: 0.1（默认值，用户可以修改）
    newRow = table( ...
        newID, ...
        0, ...
        0, ...
        0.1, ...
        'VariableNames', {'ID', '起点', '终点', '风阻'} ...
    );

    % 4. 追加新行到表格
    if isempty(currentData) || height(currentData) == 0
        % 空表格：直接设置
        uitableHandle.Data = newRow;
    else
        % 非空表格：追加
        if istable(currentData)
            % 确保列名一致
            if width(currentData) >= 4
                % 提取前4列（避免额外列干扰）
                currentData4Col = currentData(:, 1:4);
                currentData4Col.Properties.VariableNames = {'ID', '起点', '终点', '风阻'};
                uitableHandle.Data = [currentData4Col; newRow];
            else
                % 列数不足，直接追加
                uitableHandle.Data = [currentData; newRow];
            end
        else
            % 矩阵类型：转换为 table 后追加
            existingTable = array2table(currentData(:, 1:4), ...
                'VariableNames', {'ID', '起点', '终点', '风阻'});
            uitableHandle.Data = [existingTable; newRow];
        end
    end

    % 5. 确保表格列可编辑（ID 不可编辑，其他可编辑）
    uitableHandle.ColumnEditable = [false, true, true, true];

    % 6. 返回新行索引
    newRowIndex = numRows + 1;

    % 7. 可选：滚动到新行（MATLAB R2021a 及以上支持）
    try
        % 尝试滚动到新行（如果支持）
        scroll(uitableHandle, 'row', newRowIndex);
    catch
        % 旧版本不支持滚动，忽略
    end

    % 8. 提示用户（可选，添加行操作无需弹窗）
    % uifig = ancestor(uitableHandle, 'matlab.ui.Figure', 'toplevel');
    % if ~isempty(uifig)
    %     uialert(uifig, sprintf('已添加新行: ID=%d', newID), '提示', 'Icon', 'info');
    % end
end
