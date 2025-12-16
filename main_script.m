% 主脚本：通风网络求解
%
% 功能：使用Hardy Cross迭代法求解通风网络各巷道风量

clear; clc;

%% 输入参数
% 各巷道风阻 (单位: N·s²/m⁸ 或其他一致单位)
% 巷道编号顺序: 1, 2, 3, 4, 5, 6, 7, 8
R = [0.1, 0.2, 0.15, 0.25, 0.18, 0.22, 0.20, 0.12];  % 示例风阻值

% 初始总风量 (单位: m³/s)
Q_total = 100;  % 示例总风量

%% 求解
fprintf('========================================\n');
fprintf('通风网络Hardy Cross迭代法求解\n');
fprintf('========================================\n');
fprintf('输入参数:\n');
fprintf('总风量 Q_total = %.2f m³/s\n', Q_total);
fprintf('各巷道风阻:\n');
for i = 1:length(R)
    fprintf('  R(%d) = %.4f\n', i, R(i));
end
fprintf('========================================\n\n');

% 调用求解器
[Q, iterations] = ventilation_network_solver(R, Q_total);

%% 输出结果
fprintf('\n========================================\n');
fprintf('求解结果:\n');
fprintf('========================================\n');
for i = 1:length(Q)
    fprintf('巷道 %d 风量: Q(%d) = %10.4f m³/s\n', i, i, Q(i));
end

% 验证节点流量守恒
fprintf('\n========================================\n');
fprintf('节点流量守恒验证:\n');
fprintf('========================================\n');
fprintf('节点1: Q(1) = %.4f (入口)\n', Q(1));
fprintf('节点2: Q(2) + Q(3) - Q(1) = %.6f (应为0)\n', Q(2) + Q(3) - Q(1));
fprintf('节点3: Q(5) - Q(2) - Q(3) = %.6f (应为0)\n', Q(5) - Q(2) - Q(3));
fprintf('节点4: Q(4) + Q(6) - Q(7) = %.6f (应为0)\n', Q(4) + Q(6) - Q(7));
fprintf('节点5: Q(5) - Q(6) = %.6f (应为0)\n', Q(5) - Q(6));
fprintf('节点6: Q(8) - Q(7) = %.6f (应为0)\n', Q(8) - Q(7));

% 计算各回路压降
fprintf('\n========================================\n');
fprintf('各回路压降验证:\n');
fprintf('========================================\n');

% 回路I: 1-2-3
h_loop1 = R(1)*Q(1)*abs(Q(1)) - R(2)*Q(2)*abs(Q(2)) - R(3)*Q(3)*abs(Q(3));
fprintf('回路I (1-2-3): Σh = %.6f Pa (应接近0)\n', h_loop1);

% 回路II: 3-4-6-5
h_loop2 = R(3)*Q(3)*abs(Q(3)) - R(4)*Q(4)*abs(Q(4)) + R(5)*Q(5)*abs(Q(5)) - R(6)*Q(6)*abs(Q(6));
fprintf('回路II (3-4-6-5): Σh = %.6f Pa (应接近0)\n', h_loop2);

% 回路III: 6-7-8
h_loop3 = R(6)*Q(6)*abs(Q(6)) - R(7)*Q(7)*abs(Q(7)) - R(8)*Q(8)*abs(Q(8));
fprintf('回路III (6-7-8): Σh = %.6f Pa (应接近0)\n', h_loop3);

%% 可视化结果
figure('Name', '通风网络风量分布');

% 绘制网络拓扑
subplot(2,1,1);
hold on; grid on;
title('通风网络拓扑图');
xlabel(''); ylabel('');
axis equal;
axis off;

% 节点坐标
nodes = [
    0.5, 0;      % 节点1
    0.25, 0.33;  % 节点2
    0.25, 0.67;  % 节点3
    0.75, 0.67;  % 节点4
    0.75, 0.33;  % 节点5
    0.5, 1;      % 节点6
];

% 绘制节点
plot(nodes(:,1), nodes(:,2), 'o', 'MarkerSize', 20, 'MarkerFaceColor', 'b');
for i = 1:size(nodes,1)
    text(nodes(i,1), nodes(i,2), sprintf('%d', i), ...
        'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
end

% 绘制巷道并标注风量
branches = [
    1, 2;  % 巷道1
    2, 3;  % 巷道2
    1, 3;  % 巷道3
    4, 5;  % 巷道4
    3, 5;  % 巷道5
    4, 6;  % 巷道6
    5, 6;  % 巷道7
    6, 1;  % 巷道8
];

for i = 1:size(branches,1)
    n1 = branches(i,1);
    n2 = branches(i,2);
    plot([nodes(n1,1), nodes(n2,1)], [nodes(n1,2), nodes(n2,2)], 'k-', 'LineWidth', 2);

    % 标注风量
    mid_x = (nodes(n1,1) + nodes(n2,1)) / 2;
    mid_y = (nodes(n1,2) + nodes(n2,2)) / 2;
    text(mid_x, mid_y, sprintf('%.1f', Q(i)), ...
        'BackgroundColor', 'y', 'EdgeColor', 'k', 'FontSize', 8);
end

% 绘制风量柱状图
subplot(2,1,2);
bar(1:8, Q);
xlabel('巷道编号');
ylabel('风量 (m³/s)');
title('各巷道风量分布');
grid on;
for i = 1:8
    text(i, Q(i), sprintf('%.2f', Q(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

fprintf('\n求解完成！\n');
