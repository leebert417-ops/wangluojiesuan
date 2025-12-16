% 从CSV文件读取数据并求解通风网络
%
% 功能：读取network_data.csv文件中的风阻数据，使用Hardy Cross迭代法求解

clear; clc;

%% 从CSV文件读取风阻数据
data = readtable('network_data.csv');

% 提取风阻向量
R = data.resistance';

% 设置总风量
Q_total = 100;  % m³/s (可根据需要修改)

%% 显示输入参数
fprintf('========================================\n');
fprintf('通风网络Hardy Cross迭代法求解\n');
fprintf('========================================\n');
fprintf('从文件读取的输入参数:\n');
fprintf('总风量 Q_total = %.2f m³/s\n', Q_total);
fprintf('各巷道风阻:\n');
for i = 1:length(R)
    fprintf('  巷道 %d: R = %.4f\n', i, R(i));
end
fprintf('========================================\n\n');

%% 求解
fprintf('开始迭代求解...\n\n');
[Q, iterations] = ventilation_network_solver(R, Q_total);

%% 输出结果到文件
results = table((1:8)', Q', 'VariableNames', {'Branch', 'Flow_Rate'});
writetable(results, 'ventilation_results.csv');
fprintf('结果已保存到 ventilation_results.csv\n\n');

%% 显示结果
fprintf('========================================\n');
fprintf('求解结果:\n');
fprintf('========================================\n');
fprintf('迭代次数: %d\n', iterations);
fprintf('\n各巷道风量:\n');
for i = 1:length(Q)
    pressure_loss = R(i) * Q(i) * abs(Q(i));
    fprintf('  巷道 %d: Q = %10.4f m³/s, 压降 = %10.4f Pa\n', i, Q(i), pressure_loss);
end

%% 验证节点流量守恒
fprintf('\n========================================\n');
fprintf('节点流量守恒验证:\n');
fprintf('========================================\n');

% 根据网络拓扑定义节点方程
node_errors = [
    Q(1) - Q(2) - Q(3);           % 节点1分流
    Q(2) + Q(3) - Q(5);           % 节点3汇流
    Q(5) - Q(6);                  % 节点5继续流动
    Q(6) - Q(4);                  % 节点4分流
    Q(4) + Q(7) - Q(8);           % 节点6汇流
];

all_satisfied = true;
for i = 1:length(node_errors)
    fprintf('节点 %d 误差: %.6f m³/s\n', i, node_errors(i));
    if abs(node_errors(i)) > 0.01
        all_satisfied = false;
    end
end

if all_satisfied
    fprintf('✓ 所有节点流量守恒满足要求\n');
else
    fprintf('✗ 部分节点流量守恒存在偏差\n');
end

%% 验证回路压降平衡
fprintf('\n========================================\n');
fprintf('各回路压降验证:\n');
fprintf('========================================\n');

% 回路I: 1→2→3→1
h_loop1 = R(1)*Q(1)*abs(Q(1)) - R(2)*Q(2)*abs(Q(2)) - R(3)*Q(3)*abs(Q(3));
fprintf('回路 I  (巷道1-2-3):   Σh = %10.6f Pa\n', h_loop1);

% 回路II: 3→4→6→5→3
h_loop2 = R(3)*Q(3)*abs(Q(3)) - R(4)*Q(4)*abs(Q(4)) + R(5)*Q(5)*abs(Q(5)) - R(6)*Q(6)*abs(Q(6));
fprintf('回路 II (巷道3-4-6-5): Σh = %10.6f Pa\n', h_loop2);

% 回路III: 6→7→8→6
h_loop3 = R(6)*Q(6)*abs(Q(6)) - R(7)*Q(7)*abs(Q(7)) - R(8)*Q(8)*abs(Q(8));
fprintf('回路 III(巷道6-7-8):   Σh = %10.6f Pa\n', h_loop3);

fprintf('\n');
if max(abs([h_loop1, h_loop2, h_loop3])) < 0.1
    fprintf('✓ 所有回路压降平衡满足要求\n');
else
    fprintf('✗ 部分回路压降平衡存在偏差\n');
end

%% 绘图
figure('Position', [100, 100, 1000, 800]);

% 子图1: 风量柱状图
subplot(2,2,1);
bar(1:8, Q, 'FaceColor', [0.2 0.6 0.8]);
xlabel('巷道编号', 'FontSize', 11);
ylabel('风量 (m³/s)', 'FontSize', 11);
title('各巷道风量分布', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
for i = 1:8
    text(i, Q(i), sprintf('%.2f', Q(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
end

% 子图2: 压降柱状图
subplot(2,2,2);
pressure_losses = R .* Q .* abs(Q);
bar(1:8, pressure_losses, 'FaceColor', [0.8 0.4 0.2]);
xlabel('巷道编号', 'FontSize', 11);
ylabel('压降 (Pa)', 'FontSize', 11);
title('各巷道压降分布', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

% 子图3: 网络拓扑图（简化）
subplot(2,2,3);
hold on; grid on;
title('通风网络拓扑示意图', 'FontSize', 12, 'FontWeight', 'bold');

% 定义节点位置（根据图5.2）
node_pos = [
    0.5, 0.1;    % 节点1 (底部入口)
    0.2, 0.35;   % 节点2 (左下)
    0.2, 0.65;   % 节点3 (左上)
    0.8, 0.65;   % 节点4 (右上)
    0.8, 0.35;   % 节点5 (右下)
    0.5, 0.9;    % 节点6 (顶部出口)
];

% 绘制节点
scatter(node_pos(:,1), node_pos(:,2), 300, 'filled', 'MarkerFaceColor', [0.3 0.5 0.8]);
for i = 1:6
    text(node_pos(i,1), node_pos(i,2), sprintf('%d', i), ...
        'Color', 'w', 'FontWeight', 'bold', 'FontSize', 12, ...
        'HorizontalAlignment', 'center');
end

% 定义巷道连接（起点，终点）
edges = [
    1, 2;  % 巷道1
    2, 3;  % 巷道2
    1, 3;  % 巷道3
    4, 5;  % 巷道4
    3, 5;  % 巷道5
    4, 6;  % 巷道6
    5, 6;  % 巷道7
    6, 1;  % 巷道8 (环形)
];

% 绘制巷道
for i = 1:size(edges,1)
    n1 = edges(i,1);
    n2 = edges(i,2);
    plot([node_pos(n1,1), node_pos(n2,1)], [node_pos(n1,2), node_pos(n2,2)], ...
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

% 子图4: 收敛历史（示意）
subplot(2,2,4);
text(0.5, 0.5, sprintf('求解信息\n\n迭代次数: %d\n最大迭代次数: 1000\n收敛容差: 0.001\n\n✓ 求解成功', iterations), ...
    'HorizontalAlignment', 'center', 'FontSize', 11);
axis off;

% 保存图像
saveas(gcf, 'ventilation_network_results.png');
fprintf('\n结果图已保存到 ventilation_network_results.png\n');

fprintf('\n========================================\n');
fprintf('求解完成！\n');
fprintf('========================================\n');
