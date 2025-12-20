function plot_solution_bars(Branches, Q, Results)
%PLOT_SOLUTION_BARS 绘制求解结果的柱状图（风量和风压降）
%
% 用法：
%   gps.ui.plot_solution_bars(Branches, Q, Results);
%
% 输入：
%   Branches: 分支结构体（包含 id, from_node, to_node, R）
%   Q: 各分支风量（B×1 向量，单位：m³/s）
%   Results: 求解结果结构体（包含 pressure_drop）
%
% 功能：
%   - 创建两个子图：左侧为风量，右侧为风压降
%   - 使用柱状图展示各巷道数值
%   - 正值蓝色，负值红色
%   - X轴为分支ID，Y轴为对应数值
%
% 版本：
%   v1.0 (2025-12-18) - 初始版本
%
% 作者：东北大学 资源与土木工程学院 智采2201班 学生

    % 参数验证
    if nargin < 3
        error('需要提供 Branches, Q, Results 三个参数');
    end

    B = length(Branches.id);
    if length(Q) ~= B
        error('风量向量长度与分支数不匹配');
    end

    % 计算风压降（正值）
    if isfield(Results, 'pressure_drop')
        deltaP = Results.pressure_drop(:);
    else
        % 如果没有，重新计算
        deltaP = Branches.R(:) .* (abs(Q(:)) .^ 2);
    end

    % 创建新的 figure（增加高度以容纳下方图例）
    fig = figure('Name', '通风网络求解结果', 'NumberTitle', 'off', ...
                 'Position', [100 100 1200 550]);

    % ========== 子图 1：风量柱状图 ==========
    ax1 = subplot(1, 2, 1);

    % 绘制柱状图（增加间隔，BarWidth 默认 0.8，改为 0.6 增加间距）
    b1 = bar(Branches.id, Q, 'FaceColor', 'flat', 'BarWidth', 0.6);

    % 根据正负设置颜色
    colors = zeros(B, 3);
    colors(Q >= 0, :) = repmat([0.2 0.4 0.8], sum(Q >= 0), 1);  % 正值：蓝色
    colors(Q < 0, :) = repmat([0.8 0.2 0.2], sum(Q < 0), 1);   % 负值：红色
    b1.CData = colors;

    % 在柱顶标注数值
    hold on;
    for i = 1:B
        % 确定文本位置和对齐方式
        if Q(i) >= 0
            yPos = Q(i);
            vAlign = 'bottom';
            yOffset = max(abs(Q)) * 0.03;  % 向上偏移3%（增加偏移避免重叠）
        else
            yPos = Q(i);
            vAlign = 'top';
            yOffset = -max(abs(Q)) * 0.03;  % 向下偏移3%
        end

        % 标注数值（只在分支数较少时标注，避免拥挤）
        if B <= 25  % 从30降低到25，更保守
            text(Branches.id(i), yPos + yOffset, sprintf('%.2f', Q(i)), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', vAlign, ...
                'FontSize', 7.5, ...  % 字体稍微小一点，避免重叠
                'FontWeight', 'bold', ...
                'Color', [0.2 0.2 0.2]);  % 深灰色，更清晰
        end
    end

    % 设置标签和标题
    xlabel('分支 ID', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('风量 (m³/s)', 'FontSize', 11, 'FontWeight', 'bold');
    title(sprintf('各巷道通风量 (共 %d 条)', B), 'FontSize', 12, 'FontWeight', 'bold');

    % 添加网格
    grid on;
    grid minor;

    % 设置 X 轴刻度（如果分支太多，间隔显示）
    if B <= 20
        xticks(Branches.id);
    else
        xticks(Branches.id(1:max(1, floor(B/20)):end));
    end

    % 调整 Y 轴范围，为标注留出更多空间
    ylim_current = ylim;
    ylim_range = ylim_current(2) - ylim_current(1);
    ylim([ylim_current(1) - ylim_range*0.08, ylim_current(2) + ylim_range*0.15]);

    % 添加图例（放在图下方，靠近分支ID）
    h1 = bar(NaN, NaN, 'FaceColor', [0.2 0.4 0.8]);
    h2 = bar(NaN, NaN, 'FaceColor', [0.8 0.2 0.2]);
    lgd1 = legend([h1, h2], {'正向', '反向'}, ...
                  'Location', 'southoutside', ...
                  'Orientation', 'horizontal');
    lgd1.FontSize = 10;
    hold off;

    % ========== 子图 2：风压降柱状图 ==========
    ax2 = subplot(1, 2, 2);

    % 绘制柱状图（增加间隔，BarWidth 默认 0.8，改为 0.6 增加间距）
    bar(Branches.id, deltaP, 'FaceColor', [0.2 0.6 0.4], 'BarWidth', 0.6);

    % 在柱顶标注数值
    hold on;
    for i = 1:B
        % 确定文本位置和对齐方式
        if deltaP(i) >= 0
            yPos = deltaP(i);
            vAlign = 'bottom';
            yOffset = max(abs(deltaP)) * 0.03;  % 向上偏移3%（增加偏移避免重叠）
        else
            yPos = deltaP(i);
            vAlign = 'top';
            yOffset = -max(abs(deltaP)) * 0.03;  % 向下偏移3%
        end

        % 标注数值（只在分支数较少时标注，避免拥挤）
        if B <= 25  % 从30降低到25，更保守
            text(Branches.id(i), yPos + yOffset, sprintf('%.2f', deltaP(i)), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', vAlign, ...
                'FontSize', 7.5, ...  % 字体稍微小一点，避免重叠
                'FontWeight', 'bold', ...
                'Color', [0.2 0.2 0.2]);  % 深灰色，更清晰
        end
    end

    % 设置标签和标题
    xlabel('分支 ID', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('风压降 (Pa)', 'FontSize', 11, 'FontWeight', 'bold');
    title(sprintf('各巷道风压降 (共 %d 条)', B), 'FontSize', 12, 'FontWeight', 'bold');

    % 添加网格
    grid on;
    grid minor;

    % 设置 X 轴刻度
    if B <= 20
        xticks(Branches.id);
    else
        xticks(Branches.id(1:max(1, floor(B/20)):end));
    end

    % 调整 Y 轴范围，为标注留出更多空间
    ylim_current = ylim;
    ylim_range = ylim_current(2) - ylim_current(1);
    ylim([ylim_current(1) - ylim_range*0.08, ylim_current(2) + ylim_range*0.15]);

    % 添加图例（放在图下方，靠近分支ID）
    h3 = bar(NaN, NaN, 'FaceColor', [0.2 0.6 0.4]);
    lgd2 = legend(h3, {'风压降'}, ...
                  'Location', 'southoutside', ...
                  'Orientation', 'horizontal');
    lgd2.FontSize = 10;
    hold off;

    % 调整子图布局，为下方图例留出空间
    set(fig, 'Units', 'normalized');

    % 获取子图位置
    pos1 = get(ax1, 'Position');
    pos2 = get(ax2, 'Position');

    % 向上移动并略微缩小高度，为底部图例留出空间
    set(ax1, 'Position', [pos1(1), pos1(2)+0.08, pos1(3), pos1(4)-0.06]);
    set(ax2, 'Position', [pos2(1), pos2(2)+0.08, pos2(3), pos2(4)-0.06]);

    drawnow;
end
