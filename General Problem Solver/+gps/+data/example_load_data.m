% GPS 数据加载示例脚本
% ==========================================
% 演示如何使用 GPS 数据加载函数读取网络数据并调用求解器
%
% 作者：MATLAB 通风工程专家助手
% 日期：2025-12-17

clear; clc;

fprintf('========================================\n');
fprintf(' GPS 数据加载与求解示例\n');
fprintf('========================================\n\n');

%% ========== 示例 1：从模板文件加载（测试） ==========

fprintf('【示例 1】从模板文件加载图 5.2 网络\n');
fprintf('----------------------------------------\n');

% 模板文件位置
template_dir = '+gps/+data/';

% 将模板文件复制到临时目录
temp_dir = 'temp_network_data/';
if ~exist(temp_dir, 'dir')
    mkdir(temp_dir);
end

copyfile([template_dir, 'branches_template.csv'], [temp_dir, 'branches.csv']);
copyfile([template_dir, 'boundary_template.csv'], [temp_dir, 'boundary.csv']);
copyfile([template_dir, 'solver_config_template.csv'], [temp_dir, 'solver_config.csv']);

fprintf('已复制模板文件到临时目录: %s\n\n', temp_dir);

% 加载数据
try
    [Branches, Boundary, Options] = gps.data.load_network_data(temp_dir);

    fprintf('\n加载成功！数据摘要：\n');
    fprintf('  分支数: %d\n', length(Branches.id));
    fprintf('  节点数: %d\n', max([Branches.from_node; Branches.to_node]));
    fprintf('  总风量: %.2f m³/s\n', Boundary.Q_total);
    fprintf('  求解方法: %s\n', Options.method);
    fprintf('  最大迭代次数: %d\n', Options.max_iter);

catch ME
    fprintf('❌ 加载失败: %s\n', ME.message);
    fprintf('   请检查文件格式是否正确\n');
end

fprintf('\n========================================\n\n');

%% ========== 示例 2：调用通用求解器 ==========

fprintf('【示例 2】调用通用求解器\n');
fprintf('----------------------------------------\n');

if exist('Branches', 'var') && exist('Boundary', 'var')
    try
        % 注意：需要 identify_fundamental_loops.m 支持
        fprintf('正在求解...\n\n');

        [Q, Results] = ventilation_network_solver_generic(Branches, Boundary, Options);

        % 显示结果
        fprintf('\n========== 求解结果 ==========\n');
        if Results.converged
            fprintf('收敛状态: ✓ 收敛\n');
        else
            fprintf('收敛状态: ✗ 未收敛\n');
        end
        fprintf('迭代次数: %d\n', Results.iterations);
        fprintf('最大回路残差: %.6f Pa\n', Results.max_residual);

        fprintf('\n风量分布：\n');
        fprintf('  %-8s %-12s %-12s\n', '分支ID', '风量(m³/s)', '压降(Pa)');
        fprintf('  %s\n', repmat('-', 1, 40));
        for i = 1:length(Q)
            fprintf('  %-8d %-12.4f %-12.4f\n', ...
                Branches.id(i), Q(i), Results.pressure_loss(i));
        end
        fprintf('========================================\n');

    catch ME
        fprintf('❌ 求解失败: %s\n', ME.message);
        fprintf('   可能原因：回路识别模块未实现或数据有误\n');
    end
else
    fprintf('跳过求解（数据未加载）\n');
end

fprintf('\n========================================\n\n');

%% ========== 示例 3：创建自定义网络数据 ==========

fprintf('【示例 3】创建自定义网络数据文件\n');
fprintf('----------------------------------------\n');

custom_dir = 'my_custom_network/';
if ~exist(custom_dir, 'dir')
    mkdir(custom_dir);
end

% 创建简单并联网络数据
% 网络拓扑：
%        分支1
%   节点1 -----> 节点2
%    |             |
%    | 分支2       | 分支4
%    v             v
%   节点3 -----> 节点4
%        分支3

% 写入 branches.csv
fid = fopen([custom_dir, 'branches.csv'], 'w', 'n', 'UTF-8');
fprintf(fid, '# 简单并联网络\n');
fprintf(fid, 'branch_id,from_node,to_node,resistance\n');
fprintf(fid, '1,1,2,0.1\n');
fprintf(fid, '2,1,3,0.2\n');
fprintf(fid, '3,3,4,0.15\n');
fprintf(fid, '4,2,4,0.25\n');
fclose(fid);

% 写入 boundary.csv
fid = fopen([custom_dir, 'boundary.csv'], 'w', 'n', 'UTF-8');
fprintf(fid, '# 边界条件\n');
fprintf(fid, 'Q_TOTAL,50\n');
fprintf(fid, 'INLET_BRANCH,1;2\n');
fprintf(fid, 'OUTLET_BRANCH,3;4\n');
fclose(fid);

fprintf('已创建自定义网络数据: %s\n', custom_dir);
fprintf('  4 个节点，4 条分支\n');
fprintf('  1 个独立回路\n\n');

% 尝试加载
try
    [Branches2, Boundary2, Options2] = gps.data.load_network_data(custom_dir);
    fprintf('✓ 自定义网络数据加载成功\n');
catch ME
    fprintf('❌ 加载失败: %s\n', ME.message);
end

fprintf('\n========================================\n\n');

%% ========== 清理临时文件 ==========

fprintf('清理临时文件...\n');
if exist(temp_dir, 'dir')
    rmdir(temp_dir, 's');
    fprintf('  已删除: %s\n', temp_dir);
end

fprintf('\n========================================\n');
fprintf(' 示例演示完成\n');
fprintf('========================================\n\n');

fprintf('提示：\n');
fprintf('  1. 查看模板文件: +gps/+data/*_template.csv\n');
fprintf('  2. 阅读格式说明: +gps/+data/README.md\n');
fprintf('  3. 修改模板文件创建您自己的网络数据\n\n');
