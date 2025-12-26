% 主脚本：通风网络 Hardy Cross 求解与结果输出
%

clear; clc;

%% 输入
data = readtable('network_data2.csv');
R = data.resistance(:)'; % 1×11
Q_total = 100;           % m^3/s

%% 求解
fprintf('开始使用 Hardy Cross 迭代求解...\n\n');
[Q, iterations] = ventilation_network_solver2(R, Q_total);

%% 结果派生量
num_branches = numel(R);
Q_abs = abs(Q);
pressure_diff_signed = R .* Q .* abs(Q);      % Δp（沿约定方向，带符号）
pressure_diff_abs    = R .* (abs(Q) .^ 2);    % |Δp|（损失幅值，非负）

% 巷道约定方向（与 ventilation_network_solver.m 一致）
branch_directions = {
    '1→2'; '1→3'; '3→2'; '2→4';
    '3→5'; '5→4'; '4→6'; '5→6'
};

% 实际风向
actual_directions = cell(num_branches, 1);
for i = 1:num_branches
    if Q(i) >= 0
        actual_directions{i} = branch_directions{i};
    else
        nodes = strsplit(branch_directions{i}, '→');
        actual_directions{i} = [nodes{2} '→' nodes{1}];
    end
end

%% 输出 CSV（中文表头）
header = {'巷道', '风量(m3/s)', '风向', '风压差(Pa)', '风压差幅值(Pa)'};
rows = cell(num_branches, numel(header));
for i = 1:num_branches
    rows{i,1} = i;
    rows{i,2} = Q(i);
    rows{i,3} = actual_directions{i};
    rows{i,4} = pressure_diff_signed(i);
    rows{i,5} = pressure_diff_abs(i);
end
writecell([header; rows], 'ventilation_results.csv', 'Encoding', 'UTF-8');
fprintf('结果已保存到 ventilation_results.csv\n\n');

%% 结果图（仅两张柱状图）
figure('Name', '通风网络求解结果', 'Position', [100, 100, 1000, 420]);

subplot(1,2,1);
bar(1:num_branches, Q_abs, 'FaceColor', [0.2 0.6 0.8]);
xlabel('巷道编号', 'FontSize', 11);
ylabel('风量 |Q| (m3/s)', 'FontSize', 11);
title('各巷道风量幅值', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
for i = 1:num_branches
    text(i, Q_abs(i), sprintf('%.2f', Q_abs(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
end

subplot(1,2,2);
bar(1:num_branches, pressure_diff_abs, 'FaceColor', [0.8 0.4 0.2]);
xlabel('巷道编号', 'FontSize', 11);
ylabel('风压差 |Δp| (Pa)', 'FontSize', 11);
title('各巷道风压差幅值', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
for i = 1:num_branches
    text(i, pressure_diff_abs(i), sprintf('%.2f', pressure_diff_abs(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
end

saveas(gcf, 'ventilation_network_results.png');
fprintf('结果图已保存到 ventilation_network_results.png\n');
fprintf('迭代次数: %d\n', iterations);

