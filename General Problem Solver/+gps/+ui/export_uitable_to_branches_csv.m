function success = export_uitable_to_branches_csv(uitableHandle, filePath)
%EXPORT_UITABLE_TO_BRANCHES_CSV 将 UITable 数据导出为标准 GPS CSV 文件
%
% 在 App Designer 的"导出"按钮回调里：
%   addpath('General Problem Solver');
%   gps.ui.export_uitable_to_branches_csv(app.UITable);
%
% 输入：
%   uitableHandle: matlab.ui.control.Table
%   filePath: 可选；不提供则弹出文件保存对话框
%
% 输出：
%   success: 逻辑值，导出是否成功
%
% 功能：
%   - 自动验证数据完整性和合法性
%   - 生成带注释的 GPS 标准格式 CSV
%   - 保留原有数据的精度
%   - 支持自定义保存路径
%
% 版本：
%   v1.0 (2025-12-18) - 初始版本
%
% 作者：东北大学 资源与土木工程学院 智采2201班 学生

    arguments
        uitableHandle (1,1) matlab.ui.control.Table
        filePath (1,1) string = ""
    end

    % 初始化返回值
    success = false;

    % 1. 获取 UIFigure（用于后续焦点恢复和对话框）
    uifig = [];
    try
        uifig = ancestor(uitableHandle, 'matlab.ui.Figure', 'toplevel');
    catch
        try
            uifig = ancestor(uitableHandle, 'figure');
        catch
        end
    end

    % 2. 获取表格数据
    data = uitableHandle.Data;

    % 3. 数据验证
    [isValid, errorMsg] = validateTableData(data);
    if ~isValid
        error('数据验证失败: %s', errorMsg);
    end

    % 4. 打开文件保存对话框
    if strlength(filePath) == 0
        [fname, fpath] = uiputfile({'*.csv', 'CSV 文件 (*.csv)'}, ...
            '保存分支数据文件', 'branches.csv');
        if isequal(fname, 0)
            % 用户取消，恢复焦点后退出
            restoreFocus(uifig, uitableHandle);
            return;
        end
        filePath = string(fullfile(fpath, fname));
    end

    % 5. 转换为标准 table 格式（如果需要）
    T = normalizeTableData(data);

    % 6. 写入 CSV 文件
    try
        writeGPSCSV(filePath, T);
        success = true;

        % 成功提示弹窗
        if ~isempty(uifig)
            uialert(uifig, ...
                sprintf('成功导出 %d 条分支数据到:\n%s', height(T), filePath), ...
                '导出成功', 'Icon', 'success');
        end

    catch ME
        % 写入失败
        error('文件写入失败: %s', ME.message);
    end

    % 7. 恢复焦点
    restoreFocus(uifig, uitableHandle);
end


%% ========== 子函数：数据验证 ==========
function [isValid, errorMsg] = validateTableData(data)
%VALIDATETABLEDATA 验证表格数据的完整性和合法性
%
% 返回：
%   isValid   - 是否有效
%   errorMsg  - 错误信息（无错误时为空字符串）

    isValid = false;
    errorMsg = '';

    % 检查1：数据是否为空
    if isempty(data)
        errorMsg = '表格数据为空，无法导出';
        return;
    end

    % 检查2：数据类型（必须是 table）
    if ~istable(data)
        errorMsg = '数据格式错误：必须为 table 类型';
        return;
    end

    % 检查3：列数（必须为 4 列）
    if width(data) < 4
        errorMsg = sprintf('列数不足：需要 4 列（ID、起点、终点、风阻），当前 %d 列', width(data));
        return;
    end

    % 检查4：行数（至少 1 行）
    if height(data) == 0
        errorMsg = '表格无数据行，无法导出';
        return;
    end

    % 检查5：提取前4列数据
    col1 = data{:, 1};  % ID
    col2 = data{:, 2};  % 起点
    col3 = data{:, 3};  % 终点
    col4 = data{:, 4};  % 风阻

    % 检查6：ID 列（正整数、唯一）
    if any(~isfinite(col1)) || any(col1 <= 0) || any(mod(col1, 1) ~= 0)
        errorMsg = 'ID 列包含非法值（必须为正整数）';
        return;
    end
    if numel(unique(col1)) ~= numel(col1)
        errorMsg = 'ID 列存在重复值';
        return;
    end

    % 检查7：起点列（正整数）
    if any(~isfinite(col2)) || any(col2 <= 0) || any(mod(col2, 1) ~= 0)
        errorMsg = '起点列包含非法值（必须为正整数）';
        return;
    end

    % 检查8：终点列（正整数）
    if any(~isfinite(col3)) || any(col3 <= 0) || any(mod(col3, 1) ~= 0)
        errorMsg = '终点列包含非法值（必须为正整数）';
        return;
    end

    % 检查9：风阻列（正数）
    if any(~isfinite(col4)) || any(col4 <= 0)
        errorMsg = '风阻列包含非法值（必须为正数）';
        return;
    end

    % 检查10：起点和终点不能相同
    if any(col2 == col3)
        errorMsg = '存在起点和终点相同的分支（自环）';
        return;
    end

    % 所有检查通过
    isValid = true;
end


%% ========== 子函数：标准化表格数据 ==========
function T = normalizeTableData(data)
%NORMALIZETABLEDATA 将表格数据标准化为 GPS 格式
%
% 确保列名为 {'branch_id', 'from_node', 'to_node', 'resistance'}

    % 提取前4列数据
    T = table( ...
        data{:, 1}, ...
        data{:, 2}, ...
        data{:, 3}, ...
        data{:, 4}, ...
        'VariableNames', {'branch_id', 'from_node', 'to_node', 'resistance'} ...
    );
end


%% ========== 子函数：写入 GPS 格式 CSV ==========
function writeGPSCSV(filePath, T)
%WRITEGPSCSV 写入带注释头的 GPS 标准格式 CSV
%
% GPS 格式特点：
%   - UTF-8 编码
%   - 以 # 开头的注释行（包含元数据）
%   - 标准列名：branch_id, from_node, to_node, resistance
%   - 数值精度保留

    % 打开文件（UTF-8 编码）
    fid = fopen(filePath, 'w', 'n', 'UTF-8');
    if fid == -1
        error('无法创建文件: %s', filePath);
    end

    % 写入注释头
    fprintf(fid, '# GPS 通风网络数据 - 分支定义文件\n');
    fprintf(fid, '# ========================================\n');
    fprintf(fid, '# 导出时间: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '# 分支数量: %d\n', height(T));
    fprintf(fid, '# 节点范围: %d ~ %d\n', ...
        min([T.from_node; T.to_node]), ...
        max([T.from_node; T.to_node]));
    fprintf(fid, '# 风阻范围: %.4f ~ %.4f N·s²/m⁸\n', ...
        min(T.resistance), max(T.resistance));
    fprintf(fid, '# ========================================\n');
    fprintf(fid, '#\n');
    fprintf(fid, '# 列定义：\n');
    fprintf(fid, '# - branch_id    : 分支唯一标识符（正整数）\n');
    fprintf(fid, '# - from_node    : 起点节点编号（正整数）\n');
    fprintf(fid, '# - to_node      : 终点节点编号（正整数）\n');
    fprintf(fid, '# - resistance   : 风阻系数（正实数，单位：N·s²/m⁸）\n');
    fprintf(fid, '#\n');
    fprintf(fid, '# 注意事项：\n');
    fprintf(fid, '# 1. 分支方向由 from_node → to_node 定义\n');
    fprintf(fid, '# 2. 求解结果的风量正负号基于此方向判断\n');
    fprintf(fid, '# 3. 风阻系数必须为正数\n');
    fprintf(fid, '# 4. 由 NetworkSolverApp 自动导出\n');
    fprintf(fid, '#\n');
    fprintf(fid, '# ========================================\n');
    fprintf(fid, '\n');

    % 写入表头
    fprintf(fid, 'branch_id,from_node,to_node,resistance\n');

    % 写入数据行
    for i = 1:height(T)
        fprintf(fid, '%d,%d,%d,%.6g\n', ...
            T.branch_id(i), ...
            T.from_node(i), ...
            T.to_node(i), ...
            T.resistance(i));
    end

    fclose(fid);
end


%% ========== 子函数：恢复焦点 ==========
function restoreFocus(uifig, targetControl)
%RESTOREFOCUS 恢复 App Designer 窗口和控件焦点
%
% 与 import_branches_csv_to_uitable.m 中的实现一致

    try
        if ~isempty(uifig) && isvalid(uifig)
            % 步骤1：将 UIFigure 提到前台
            figure(uifig);

            % 步骤2：刷新图形系统
            drawnow;

            % 步骤3：短暂延迟（等待系统窗口管理器完成切换）
            pause(0.05);

            % 步骤4：显式设置控件焦点
            if ~isempty(targetControl) && isvalid(targetControl)
                focus(targetControl);
            end

            % 步骤5：再次刷新
            drawnow;
        end
    catch ME
        % 静默失败（不影响主功能）
    end
end
