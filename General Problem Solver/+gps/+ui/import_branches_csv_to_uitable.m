function T = import_branches_csv_to_uitable(uitableHandle, filePath)
%IMPORT_BRANCHES_CSV_TO_UITABLE 读取分支 CSV 并填充到 UITable（优化版）
%
% 在 App Designer 的"导入"按钮回调里：
%   addpath('General Problem Solver');
%   gps.ui.import_branches_csv_to_uitable(app.UITable);
%
% 输入：
%   uitableHandle: matlab.ui.control.Table
%   filePath: 可选；不提供则弹出文件选择框
%
% 输出：
%   T: 规范化后的 table（变量名：id/from_node/to_node/R）
%
% 版本更新：
%   v1.1 (2025-12-18) - 优化焦点恢复逻辑，解决 App Designer 失焦问题

    arguments
        uitableHandle (1,1) matlab.ui.control.Table
        filePath (1,1) string = ""
    end

    % 1. 获取 UIFigure（App Designer 专用方法）
    uifig = [];
    try
        uifig = ancestor(uitableHandle, 'matlab.ui.Figure', 'toplevel');
    catch
        % 降级方案：尝试查找传统 figure
        try
            uifig = ancestor(uitableHandle, 'figure');
        catch
        end
    end

    % 2. 打开文件选择对话框
    if strlength(filePath) == 0
        [fname, fpath] = uigetfile({'*.csv', 'CSV 文件 (*.csv)'}, ...
            '选择分支数据文件');
        if isequal(fname, 0)
            T = table();
            % 用户取消时也要恢复焦点
            restoreFocus(uifig, uitableHandle);
            return;
        end
        filePath = string(fullfile(fpath, fname));
    end

    % 3. 导入数据
    T = gps.ui.import_branches_csv(filePath);

    % 4. 更新表格
    uitableHandle.ColumnName = {'ID', '起点', '终点', '风阻'};
    uitableHandle.Data = table(T.id, T.from_node, T.to_node, T.R, ...
        'VariableNames', {'ID', '起点', '终点', '风阻'});

    % 5. 成功提示弹窗
    if ~isempty(uifig)
        [~, fileName, fileExt] = fileparts(filePath);
        uialert(uifig, ...
            sprintf('成功导入 %d 条分支数据\n\n文件: %s%s', height(T), fileName, fileExt), ...
            '导入成功', 'Icon', 'success');
    end

    % 6. 恢复焦点（关键优化）
    restoreFocus(uifig, uitableHandle);
end


%% ========== 子函数：恢复焦点（多重保险策略）==========
function restoreFocus(uifig, targetControl)
%RESTOREFOCUS 恢复 App Designer 窗口和控件焦点
%
% 策略：
%   1. 将 UIFigure 提到前台
%   2. 等待系统窗口管理器完成切换（避免时序冲突）
%   3. 显式设置目标控件焦点
%   4. 刷新图形系统确保视觉反馈
%
% 适用场景：
%   - uigetfile/uiputfile 关闭后焦点丢失
%   - 模态对话框关闭后焦点未返回
%   - 多显示器环境窗口切换
%
% 参数：
%   uifig         - matlab.ui.Figure 对象（App Designer 窗口）
%   targetControl - 目标控件（如 UITable、EditField 等）

    try
        if ~isempty(uifig) && isvalid(uifig)
            % 步骤1：将 UIFigure 提到前台
            figure(uifig);

            % 步骤2：刷新图形系统（确保窗口状态同步）
            drawnow;

            % 步骤3：短暂延迟（等待系统窗口管理器完成切换）
            % 50ms 用户无感知，但足够让 Windows DWM 完成窗口合成
            pause(0.05);

            % 步骤4：显式设置控件焦点（App Designer 专用方法）
            if ~isempty(targetControl) && isvalid(targetControl)
                focus(targetControl);
            end

            % 步骤5：再次刷新（确保焦点视觉反馈生效）
            drawnow;
        end
    catch ME
        % 静默失败（不影响主功能）
        % 可选：记录警告日志
        % warning('焦点恢复失败: %s', ME.message);
    end
end
