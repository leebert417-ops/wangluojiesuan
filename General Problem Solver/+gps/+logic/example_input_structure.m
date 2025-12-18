% 示例：通用通风网络求解器输入数据结构
% ==========================================
% 本脚本演示如何构造通用求解器所需的输入数据结构
% 以教材图 5.2 网络（6节点8分支）为例
%
% 作者：MATLAB 通风工程专家助手
% 日期：2025-12-17

clear; clc;

%% ========== 示例1：图 5.2 网络（标准案例）==========

fprintf('========================================\n');
fprintf(' 示例1：图 5.2 网络数据结构\n');
fprintf('========================================\n\n');

% ---------- 分支数据结构 ----------
% 必需字段：id, from_node, to_node, R

Branches = struct();

% 分支编号（1到8）
Branches.id = (1:8)';

% 分支起点节点（from_node → to_node 定义正方向）
Branches.from_node = [
    1;  % 分支1: 节点1 → 节点2
    1;  % 分支2: 节点1 → 节点3
    3;  % 分支3: 节点3 → 节点2（下部对角巷道）
    2;  % 分支4: 节点2 → 节点4
    3;  % 分支5: 节点3 → 节点5
    5;  % 分支6: 节点5 → 节点4（中部对角巷道）
    4;  % 分支7: 节点4 → 节点6
    5;  % 分支8: 节点5 → 节点6
];

% 分支终点节点
Branches.to_node = [
    2;  % 分支1终点
    3;  % 分支2终点
    2;  % 分支3终点
    4;  % 分支4终点
    5;  % 分支5终点
    4;  % 分支6终点
    6;  % 分支7终点
    6;  % 分支8终点
];

% 各分支风阻（单位：N·s²/m⁸）
Branches.R = [
    0.1;   % 分支1风阻
    0.2;   % 分支2风阻
    0.15;  % 分支3风阻
    0.25;  % 分支4风阻
    0.18;  % 分支5风阻
    0.22;  % 分支6风阻
    0.2;   % 分支7风阻
    0.12;  % 分支8风阻
];

% 可选字段：分支名称（用于可视化）
Branches.name = {
    '下部右侧立井';
    '下部左侧立井';
    '下部对角巷道';
    '右侧中部立井';
    '左侧中部立井';
    '中部对角巷道';
    '右侧上部立井';
    '左侧上部立井';
};

% ---------- 边界条件结构 ----------

Boundary = struct();

% 入风节点：节点1
Boundary.inlet_node = 1;

% 回风节点：节点6
Boundary.outlet_node = 6;

% 系统总风量（单位：m³/s）
Boundary.Q_total = 100;

% ---------- 求解器参数（可选）----------

SolverOptions = struct();
SolverOptions.max_iter = 1000;       % 最大迭代次数
SolverOptions.tolerance = 1e-3;      % 收敛容差
SolverOptions.method = 'HardyCross'; % 求解方法
SolverOptions.verbose = true;        % 显示详细信息

% ---------- 显示数据结构 ----------

fprintf('分支数据结构（Branches）：\n');
disp(struct2table(Branches));

fprintf('\n边界条件（Boundary）：\n');
fprintf('  入风节点: %s\n', mat2str(Boundary.inlet_node'));
fprintf('  回风节点: %s\n', mat2str(Boundary.outlet_node'));
fprintf('  总风量: %.2f m³/s\n', Boundary.Q_total);

fprintf('\n求解器参数（SolverOptions）：\n');
disp(SolverOptions);

fprintf('========================================\n\n');

%% ========== 调用通用求解器（需要先实现回路识别模块）==========

% 注意：以下代码需要 identify_fundamental_loops.m 模块支持
% 如果该模块尚未实现，此处会报错

try
    fprintf('正在调用通用求解器...\n\n');

    [Q, Results] = ventilation_network_solver_generic(Branches, Boundary, SolverOptions);

    % 显示求解结果
    fprintf('\n========== 求解结果摘要 ==========\n');
    if Results.converged
        fprintf('收敛状态: ✓ 收敛\n');
    else
        fprintf('收敛状态: ✗ 未收敛\n');
    end
    fprintf('迭代次数: %d\n', Results.iterations);
    fprintf('最大回路残差: %.6f Pa\n', Results.max_residual);
    fprintf('\n风量分布：\n');
    for i = 1:length(Q)
        fprintf('  分支%d (%s): Q = %8.4f m³/s\n', ...
            Branches.id(i), Branches.name{i}, Q(i));
    end
    fprintf('========================================\n\n');

catch ME
    fprintf('⚠ 求解器调用失败：%s\n', ME.message);
    fprintf('   可能原因：回路识别模块 identify_fundamental_loops.m 尚未实现\n\n');
end

%% ========== 示例2：简单并联网络（用于测试）==========

fprintf('========================================\n');
fprintf(' 示例2：简单并联网络（2个回路）\n');
fprintf('========================================\n\n');

% 网络拓扑：
%        分支1
%   节点1 -----> 节点2
%    |             |
%    | 分支2       | 分支4
%    v             v
%   节点3 -----> 节点4
%        分支3

Branches2 = struct();
Branches2.id = (1:4)';
Branches2.from_node = [1; 1; 3; 2];
Branches2.to_node   = [2; 3; 4; 4];
Branches2.R = [0.1; 0.2; 0.15; 0.25];
Branches2.name = {'上部横巷'; '左侧立井'; '下部横巷'; '右侧立井'};

Boundary2 = struct();
Boundary2.inlet_node = 1;    % 节点1入风
Boundary2.outlet_node = 4;   % 节点4回风
Boundary2.Q_total = 50;

fprintf('分支数据：\n');
disp(struct2table(Branches2));

fprintf('\n边界条件：\n');
fprintf('  入风节点: %d\n', Boundary2.inlet_node);
fprintf('  回风节点: %d\n', Boundary2.outlet_node);
fprintf('  总风量: %.2f m³/s\n', Boundary2.Q_total);

fprintf('\n理论分析：\n');
fprintf('  节点数 N = 4\n');
fprintf('  分支数 B = 4\n');
fprintf('  独立回路数 M = B - N + 1 = 1\n');
fprintf('========================================\n\n');

%% ========== 示例3：从 CSV 文件读取网络数据 ==========

fprintf('========================================\n');
fprintf(' 示例3：从 CSV 读取网络数据\n');
fprintf('========================================\n\n');

% 假设 CSV 文件格式：
% branches.csv: branch_id, from_node, to_node, resistance
% boundary.csv: Q_total

csv_file = '../network_data.csv';  % 指向根目录的 CSV 文件

if exist(csv_file, 'file')
    fprintf('检测到 CSV 文件: %s\n', csv_file);

    % 读取 CSV（示例，需要根据实际格式调整）
    data = readtable(csv_file);

    Branches_CSV = struct();
    Branches_CSV.id = (1:height(data))';
    Branches_CSV.R = data.resistance;

    fprintf('  共读取 %d 条分支数据\n', height(data));
    fprintf('  风阻范围: [%.3f, %.3f]\n', min(data.resistance), max(data.resistance));

    fprintf('\n提示：需要额外提供 from_node 和 to_node 信息\n');
    fprintf('      建议创建完整的 branches.csv 文件包含以下列：\n');
    fprintf('      branch_id, from_node, to_node, resistance\n');
else
    fprintf('未找到 CSV 文件: %s\n', csv_file);
    fprintf('示例略过\n');
end

fprintf('========================================\n\n');

%% ========== 数据结构设计说明 ==========

fprintf('========================================\n');
fprintf(' 数据结构设计说明\n');
fprintf('========================================\n\n');

fprintf('【必需输入】\n\n');

fprintf('1. Branches（分支数据结构体）\n');
fprintf('   - 必需字段：\n');
fprintf('     • id         : 分支编号 (B×1 向量)\n');
fprintf('     • from_node  : 起点节点 (B×1 向量)\n');
fprintf('     • to_node    : 终点节点 (B×1 向量)\n');
fprintf('     • R          : 风阻系数 (B×1 向量, N·s²/m⁸)\n');
fprintf('   - 可选字段：\n');
fprintf('     • name       : 分支名称（用于可视化）\n\n');

fprintf('2. Boundary（边界条件结构体）\n');
fprintf('   - 必需字段：\n');
fprintf('     • inlet_node    : 入风节点编号（标量或向量）\n');
fprintf('     • outlet_node   : 回风节点编号（标量或向量）\n');
fprintf('     • Q_total       : 总风量 (m³/s)\n\n');

fprintf('【可选输入】\n\n');

fprintf('3. SolverOptions（求解器参数）\n');
fprintf('   - max_iter   : 最大迭代次数（默认 1000）\n');
fprintf('   - tolerance  : 收敛容差（默认 1e-3）\n');
fprintf('   - method     : 求解方法（默认 ''HardyCross''）\n');
fprintf('   - verbose    : 是否显示详细信息（默认 true）\n\n');

fprintf('========================================\n\n');

fprintf('提示：可将本脚本中的数据结构复制到您的项目中使用\n\n');
