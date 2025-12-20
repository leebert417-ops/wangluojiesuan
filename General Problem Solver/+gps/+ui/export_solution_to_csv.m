function filePath = export_solution_to_csv(Branches, Q, Results, filePath)
%EXPORT_SOLUTION_TO_CSV 导出求解结果到 CSV 文件
%
% 用法：
%   % 自动弹出保存对话框
%   filePath = gps.ui.export_solution_to_csv(Branches, Q, Results);
%
%   % 指定文件路径
%   filePath = gps.ui.export_solution_to_csv(Branches, Q, Results, 'results.csv');
%
% 输入：
%   Branches: 分支结构体（包含 id, from_node, to_node, R）
%   Q: 各分支风量（B×1 向量，单位：m³/s）
%   Results: 求解结果结构体（包含 pressure_drop）
%   filePath: 可选，输出文件路径（不提供则弹出保存对话框）
%
% 输出：
%   filePath: 实际保存的文件路径（用户取消则返回空字符串）
%
% CSV 文件包含列：
%   - branch_id: 巷道ID
%   - from_node: 起点节点
%   - to_node: 终点节点
%   - resistance: 通风阻力（N·s²/m⁸）
%   - flow_rate: 风量（m³/s）
%   - pressure_drop: 风压降（Pa）
%
% 版本：
%   v1.0 (2025-12-18) - 初始版本
%
% 作者：东北大学 资源与土木工程学院 智采2201班 学生

    arguments
        Branches (1,1) struct
        Q (:,1) double
        Results (1,1) struct
        filePath (1,1) string = ""
    end

    % 初始化返回值
    if strlength(filePath) == 0
        filePath = "";
    end

    % 参数验证
    B = length(Branches.id);
    if length(Q) ~= B
        error('风量向量长度与分支数不匹配');
    end

    % 读取数据
    Branches_out = Branches;
    Q_out = Q(:);
    if isfield(Results, 'Branches_flow_aligned') && isfield(Results, 'Q_flow_aligned')
        Branches_out = Results.Branches_flow_aligned;
        Q_out = Results.Q_flow_aligned(:);
    else
        % 兼容：若未提供，则在导出阶段本地修正
        neg = (Q_out < 0);
        temp = Branches_out.from_node(neg);
        Branches_out.from_node(neg) = Branches_out.to_node(neg);
        Branches_out.to_node(neg) = temp;
        Q_out(neg) = -Q_out(neg);
    end

    % 计算风压降（正值）
    if isfield(Results, 'pressure_drop') && numel(Results.pressure_drop) == B
        deltaP = Results.pressure_drop(:);
    else
        deltaP = Branches_out.R(:) .* Q_out(:) .* abs(Q_out(:));
    end

    % 如果未指定文件路径，弹出保存对话框
    if strlength(filePath) == 0
        [fname, fpath] = uiputfile({'*.csv', 'CSV 文件 (*.csv)'}, ...
            '保存求解结果', 'solution_results.csv');

        if isequal(fname, 0)
            % 用户取消
            filePath = "";
            return;
        end

        filePath = string(fullfile(fpath, fname));
    end

    % 写入 CSV 文件（带注释头）
    try
        fid = fopen(filePath, 'w', 'n', 'UTF-8');
        if fid == -1
            error('无法创建文件: %s', filePath);
        end

        % 写入注释头
        fprintf(fid, '# 通风网络求解结果\n');
        fprintf(fid, '# ========================================\n');
        fprintf(fid, '# 导出时间: %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
        fprintf(fid, '# 分支数量: %d\n', B);
        fprintf(fid, '# ========================================\n');
        fprintf(fid, '#\n');
        fprintf(fid, '# 收敛信息:\n');
        fprintf(fid, '#   是否收敛: %s\n', iif(Results.converged, '是', '否'));
        fprintf(fid, '#   迭代次数: %d\n', Results.iterations);
        fprintf(fid, '#   最大回路残差: %.6e\n', Results.max_residual);
        if isfield(Results, 'node_residual')
            fprintf(fid, '#   最大节点残差: %.6e\n', max(abs(Results.node_residual)));
        end
        fprintf(fid, '# ========================================\n');
        fprintf(fid, '#\n');
        fprintf(fid, '# 列定义:\n');
        fprintf(fid, '#   - branch_id    : 巷道唯一标识符\n');
        fprintf(fid, '#   - from_node    : 起点节点编号\n');
        fprintf(fid, '#   - to_node      : 终点节点编号\n');
        fprintf(fid, '#   - resistance   : 通风阻力 (N·s²/m⁸)\n');
        fprintf(fid, '#   - flow_rate    : 风量 (m³/s，已按实际风向对齐为非负)\n');
        fprintf(fid, '#   - pressure_drop: 风压降 (Pa，沿风向定义为非负)\n');
        fprintf(fid, '# ========================================\n');
        fprintf(fid, '\n');

        % 写入表头
        fprintf(fid, 'branch_id,from_node,to_node,resistance,flow_rate,pressure_drop\n');

        % 创建结果表格
        T = table( ...
          Branches_out.id(:), ...
          Branches_out.from_node(:), ...
          Branches_out.to_node(:), ...
          Branches_out.R(:), ...
          Q_out(:), ...
          deltaP(:), ...
          'VariableNames', {'branch_id', 'from_node', 'to_node', 'resistance', 'flow_rate', 'pressure_drop'} ...
          );

        % 写入数据行  
        for i = 1:B
            fprintf(fid, '%d,%d,%d,%.6g,%.6g,%.6g\n', ...
                T.branch_id(i), ...
                T.from_node(i), ...
                T.to_node(i), ...
                T.resistance(i), ...
                T.flow_rate(i), ...
                T.pressure_drop(i));
        end

        fclose(fid);

    catch ME
        if fid ~= -1
            fclose(fid);
        end
        error('文件写入失败: %s', ME.message);
    end
end


%% ========== 辅助函数：三元运算符 ==========
function result = iif(condition, trueValue, falseValue)
%IIF 简单的三元运算符实现
    if condition
        result = trueValue;
    else
        result = falseValue;
    end
end
