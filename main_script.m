% 主脚本：通风网络 Hardy Cross 求解
%
% 功能：
%   - 从 CSV 文件读取 8 条巷道的风阻数据；
%   - 调用 ventilation_network_solver.m 使用 Hardy Cross 回路迭代法
%     计算各巷道风量；
%   - 按节点质量守恒和回路压降平衡进行物理检验；
%   - 将结果写入 ventilation_results.csv，并生成可视化图
%     ventilation_network_results.png。

clear; clc;

%% 输入参数
% 从 CSV 文件读取各巷道风阻（单位：N·s²/m⁸）
data = readtable('network_data.csv');
R = data.resistance(:)';          % 转成 1×8 行向量
num_branches = numel(R);

% 入口总风量（单位：m³/s）——可根据需要修改
Q_total = 100;

%% 显示输入信息
fprintf('========================================\n');
fprintf(' 通风网络 Hardy Cross 迭代求解\n');
fprintf('========================================\n');
fprintf('输入参数：\n');
fprintf('  数据来源 : network_data.csv\n');
fprintf('  总风量   Q_total = %.2f m^3/s\n', Q_total);
fprintf('  各巷道风阻 R(i):\n');
for i = 1:num_branches
    fprintf('    巷道 %d: R = %.4f\n', i, R(i));
end
fprintf('========================================\n\n');

%% 求解
fprintf('开始使用 Hardy Cross 迭代求解...\n\n');
[Q, iterations] = ventilation_network_solver(R, Q_total);

%% 输出结果到文件
results = table((1:num_branches)', Q', 'VariableNames', {'Branch', 'Flow_Rate'});
writetable(results, 'ventilation_results.csv');
fprintf('结果已保存到 ventilation_results.csv\n\n');

%% 在命令行显示结果
fprintf('========================================\n');
fprintf(' 求解结果：\n');
fprintf('========================================\n');
fprintf('迭代次数: %d\n', iterations);
fprintf('\n各巷道风量与压降：\n');
pressure_losses = R .* Q .* abs(Q);
for i = 1:num_branches
    fprintf('  巷道 %d: Q = %10.4f m^3/s, ΔP = %10.4f Pa\n', ...
        i, Q(i), pressure_losses(i));
end

%% 节点流量守恒验证
fprintf('\n========================================\n');
fprintf(' 节点流量守恒验证：\n');
fprintf('========================================\n');

% 节点编号及连接关系与 ventilation_network_solver.m 保持一致：
%   节点1：底部入口
%   节点2：右下
%   节点3：左下
%   节点4：右上
%   节点5：左上
%   节点6：顶部回风口
%
% 节点方程（正方向按 solver 中的巷道方向约定）：
%   节点1：Q1 + Q2 = Q_total
%   节点2：Q1 + Q3 = Q4
%   节点3：Q2 = Q3 + Q5
%   节点4：Q4 + Q6 = Q7
%   节点5：Q5 = Q6 + Q8
%   节点6：Q7 + Q8 = Q_total
node_errors = [
    Q(1) + Q(2) - Q_total;   % 节点1
    Q(1) + Q(3) - Q(4);      % 节点2
    Q(2) - Q(3) - Q(5);      % 节点3
    Q(4) + Q(6) - Q(7);      % 节点4
    Q(5) - Q(6) - Q(8);      % 节点5
    Q(7) + Q(8) - Q_total;   % 节点6
];

all_nodes_ok = true;
for i = 1:numel(node_errors)
    fprintf('  节点 %d 质量守恒误差: %+ .6f m^3/s\n', i, node_errors(i));
    if abs(node_errors(i)) > 1e-2
        all_nodes_ok = false;
    end
end

if all_nodes_ok
    fprintf('⇒ 所有节点的流量守恒满足工程精度要求。\n');
else
    fprintf('⇒ 注意：部分节点的流量守恒存在明显偏差。\n');
end

%% 回路压降平衡验证
fprintf('\n========================================\n');
fprintf(' 回路压降平衡验证：\n');
fprintf('========================================\n');

% 回路 I ：1-2-3-1  （巷道 1,3,2）
h_loop1 = R(1)*Q(1)*abs(Q(1)) ...
        - R(3)*Q(3)*abs(Q(3)) ...
        - R(2)*Q(2)*abs(Q(2));
fprintf('  回路 I   (1-2-3-1，对应巷道 1,3,2): Σh = %+10.6f Pa\n', h_loop1);

% 回路 II：2-4-5-3-2（巷道 4,6,5,3）
h_loop2 = R(4)*Q(4)*abs(Q(4)) ...
        - R(6)*Q(6)*abs(Q(6)) ...
        - R(5)*Q(5)*abs(Q(5)) ...
        + R(3)*Q(3)*abs(Q(3));
fprintf('  回路 II  (2-4-5-3-2，对应巷道 4,6,5,3): Σh = %+10.6f Pa\n', h_loop2);

% 回路 III：4-6-5-4（巷道 7,8,6）
h_loop3 = R(7)*Q(7)*abs(Q(7)) ...
        - R(8)*Q(8)*abs(Q(8)) ...
        + R(6)*Q(6)*abs(Q(6));
fprintf('  回路 III (4-6-5-4，对应巷道 7,8,6): Σh = %+10.6f Pa\n', h_loop3);

max_loop_res = max(abs([h_loop1, h_loop2, h_loop3]));
if max_loop_res < 0.1
    fprintf('⇒ 所有回路的压降平衡满足工程精度要求（|Σh| < 0.1 Pa）。\n');
else
    fprintf('⇒ 注意：部分回路压降平衡存在偏差，最大 |Σh| = %.6f Pa。\n', max_loop_res);
end

%% 可视化结果
figure('Name', '通风网络求解结果', 'Position', [100, 100, 1000, 800]);

% 子图 1：风量柱状图
subplot(2,2,1);
bar(1:num_branches, Q, 'FaceColor', [0.2 0.6 0.8]);
xlabel('巷道编号', 'FontSize', 11);
ylabel('风量 Q (m^3/s)', 'FontSize', 11);
title('各巷道风量分布', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
for i = 1:num_branches
    text(i, Q(i), sprintf('%.2f', Q(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
end

% 子图 2：压降柱状图
subplot(2,2,2);
bar(1:num_branches, pressure_losses, 'FaceColor', [0.8 0.4 0.2]);
xlabel('巷道编号', 'FontSize', 11);
ylabel('压降 H (Pa)', 'FontSize', 11);
title('各巷道压降分布', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

% 子图 3：网络拓扑示意图
subplot(2,2,3);
hold on; grid on;
title('通风网络拓扑示意图', 'FontSize', 12, 'FontWeight', 'bold');

% 节点坐标（与 solver 中的节点编号一致）
% 1：底部入口；2：右下；3：左下；4：右上；5：左上；6：顶部回风口
node_pos = [
    0.5, 0.1;   % 节点1
    0.8, 0.35;  % 节点2
    0.2, 0.35;  % 节点3
    0.8, 0.65;  % 节点4
    0.2, 0.65;  % 节点5
    0.5, 0.9;   % 节点6
];

% 绘制节点
scatter(node_pos(:,1), node_pos(:,2), 300, 'filled', ...
    'MarkerFaceColor', [0.3 0.5 0.8]);
for i = 1:size(node_pos,1)
    text(node_pos(i,1), node_pos(i,2), sprintf('%d', i), ...
        'Color', 'w', 'FontWeight', 'bold', 'FontSize', 12, ...
        'HorizontalAlignment', 'center');
end

% 巷道连接关系（仅用于绘图，不区分方向）
% 1: 1-2；2: 1-3；3: 3-2；4: 2-4；5: 3-5；6: 5-4；7: 4-6；8: 5-6
edges = [
    1, 2;  % 巷道1
    1, 3;  % 巷道2
    3, 2;  % 巷道3
    2, 4;  % 巷道4
    3, 5;  % 巷道5
    5, 4;  % 巷道6
    4, 6;  % 巷道7
    5, 6;  % 巷道8
];

% 绘制巷道及风量标注
for i = 1:size(edges,1)
    n1 = edges(i,1);
    n2 = edges(i,2);
    plot([node_pos(n1,1), node_pos(n2,1)], ...
         [node_pos(n1,2), node_pos(n2,2)], ...
         'k-', 'LineWidth', 2.5);

    % 在巷道中点标注编号和风量
    mid_x = (node_pos(n1,1) + node_pos(n2,1)) / 2;
    mid_y = (node_pos(n1,2) + node_pos(n2,2)) / 2;
    text(mid_x, mid_y, sprintf('%d\n%.1f', i, Q(i)), ...
        'BackgroundColor', 'yellow', 'EdgeColor', 'k', ...
        'FontSize', 8, 'HorizontalAlignment', 'center', 'Margin', 2);
end

axis equal;
axis([0 1 0 1]);
xlabel(''); ylabel('');
set(gca, 'XTick', [], 'YTick', []);

% 子图 4：求解信息
subplot(2,2,4);
text(0.5, 0.6, sprintf(['求解信息\n\n', ...
    '迭代次数       : %d\n', ...
    '最大回路残差   : %.6f Pa\n', ...
    '节点守恒最大误差: %.6f m^3/s\n'], ...
    iterations, max_loop_res, max(abs(node_errors))), ...
    'HorizontalAlignment', 'center', 'FontSize', 11);

text(0.5, 0.2, '✓ 求解完成', ...
    'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold', ...
    'Color', [0 0.5 0]);
axis off;

% 保存图像
saveas(gcf, 'ventilation_network_results.png');
fprintf('\n结果图已保存到 ventilation_network_results.png\n');

fprintf('\n========================================\n');
fprintf(' 求解完成。\n');
fprintf('========================================\n');
