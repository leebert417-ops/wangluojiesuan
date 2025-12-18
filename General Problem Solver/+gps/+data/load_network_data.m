function [Branches, Boundary, SolverOptions] = load_network_data(data_dir)
% 从 GPS 数据目录加载通风网络数据
% ==========================================
% 功能：读取 GPS 专用格式的 CSV 数据文件并转换为 MATLAB 结构体
%
% 输入参数：
%   data_dir - 数据文件目录路径（可选）
%              如果不指定，默认在当前目录查找以下文件：
%              - branches.csv      分支数据（必需）
%              - boundary.csv      边界条件（必需）
%              - solver_config.csv 求解器配置（可选）
%
% 输出参数：
%   Branches      - 分支数据结构体
%                   .id         分支编号 (B×1)
%                   .from_node  起点节点 (B×1)
%                   .to_node    终点节点 (B×1)
%                   .R          风阻系数 (B×1)
%
%   Boundary      - 边界条件结构体
%                   .Q_total       总风量 (标量)
%                   .inlet_node    入风节点编号 (向量)
%                   .outlet_node   回风节点编号 (向量)
%
%   SolverOptions - 求解器参数结构体
%                   .max_iter   最大迭代次数
%                   .tolerance  收敛容差
%                   .method     求解方法
%                   .verbose    是否显示详细信息
%                   .relaxation 松弛因子
%
% 示例：
%   % 从当前目录加载
%   [Branches, Boundary, Options] = gps.data.load_network_data();
%
%   % 从指定目录加载
%   [Branches, Boundary, Options] = gps.data.load_network_data('./my_network/');
%
% 作者：东北大学 资源与土木工程学院 智采2201班 学生
% 日期：2025-12-17

    %% ========== 参数处理 ==========

    if nargin < 1 || isempty(data_dir)
        data_dir = '.';  % 默认当前目录
    end

    % 确保目录路径以分隔符结尾
    if ~endsWith(data_dir, filesep)
        data_dir = [data_dir, filesep];
    end

    % 定义文件路径
    branches_file = [data_dir, 'branches.csv'];
    boundary_file = [data_dir, 'boundary.csv'];
    config_file   = [data_dir, 'solver_config.csv'];

    %% ========== 读取分支数据（必需）==========

    fprintf('正在加载网络数据...\n');
    fprintf('  数据目录: %s\n', data_dir);

    if ~exist(branches_file, 'file')
        error('未找到分支数据文件: %s', branches_file);
    end

    fprintf('  读取分支数据: branches.csv ... ');
    Branches = load_branches(branches_file);
    fprintf('完成 (%d 条分支)\n', length(Branches.id));

    %% ========== 读取边界条件（必需）==========

    if ~exist(boundary_file, 'file')
        error('未找到边界条件文件: %s', boundary_file);
    end

    fprintf('  读取边界条件: boundary.csv ... ');
    Boundary = load_boundary(boundary_file);
    fprintf('完成 (Q_total = %.2f m³/s)\n', Boundary.Q_total);

    %% ========== 读取求解器配置（可选）==========

    if exist(config_file, 'file')
        fprintf('  读取求解器配置: solver_config.csv ... ');
        SolverOptions = load_solver_config(config_file);
        fprintf('完成\n');
    else
        fprintf('  未找到配置文件，使用默认参数\n');
        SolverOptions = get_default_solver_options();
    end

    %% ========== 数据校验 ==========

    fprintf('\n数据校验中...\n');
    validate_network_data(Branches, Boundary);
    fprintf('✓ 数据校验通过\n\n');

end


%% ========== 子函数：读取分支数据 ==========

function Branches = load_branches(filepath)
    % 读取 branches.csv 文件

    % 使用 readtable 读取 CSV（自动跳过注释行）
    opts = detectImportOptions(filepath, 'CommentStyle', '#');
    data = readtable(filepath, opts);

    % 检查必需列
    required_cols = {'branch_id', 'from_node', 'to_node', 'resistance'};
    for i = 1:length(required_cols)
        if ~ismember(required_cols{i}, data.Properties.VariableNames)
            error('branches.csv 缺少必需列: %s', required_cols{i});
        end
    end

    % 构建结构体（仅必需字段）
    Branches = struct();
    Branches.id = data.branch_id;
    Branches.from_node = data.from_node;
    Branches.to_node = data.to_node;
    Branches.R = data.resistance;
end


%% ========== 子函数：读取边界条件 ==========

function Boundary = load_boundary(filepath)
    % 读取 boundary.csv 文件（键值对格式）

    fid = fopen(filepath, 'r', 'n', 'UTF-8');
    if fid == -1
        error('无法打开文件: %s', filepath);
    end

    Boundary = struct();

    while ~feof(fid)
        line = fgetl(fid);

        % 跳过注释和空行
        if isempty(line) || startsWith(strtrim(line), '#')
            continue;
        end

        % 解析键值对
        parts = strsplit(line, ',');
        if length(parts) < 2
            continue;
        end

        key = upper(strtrim(parts{1}));
        value = strtrim(parts{2});

        % 根据键名解析
        switch key
            case 'Q_TOTAL'
                Boundary.Q_total = str2double(value);

            case 'INLET_NODE'
                node_strs = strsplit(value, ';');
                Boundary.inlet_node = zeros(length(node_strs), 1);
                for i = 1:length(node_strs)
                    Boundary.inlet_node(i) = str2double(node_strs{i});
                end

            case 'OUTLET_NODE'
                node_strs = strsplit(value, ';');
                Boundary.outlet_node = zeros(length(node_strs), 1);
                for i = 1:length(node_strs)
                    Boundary.outlet_node(i) = str2double(node_strs{i});
                end

            case 'INLET_BRANCH'
                error('boundary.csv 参数 INLET_BRANCH 已弃用，请改用 INLET_NODE（入风节点）');

            case 'OUTLET_BRANCH'
                error('boundary.csv 参数 OUTLET_BRANCH 已弃用，请改用 OUTLET_NODE（回风节点）');
        end
    end

    fclose(fid);

    % 检查必需字段
    if ~isfield(Boundary, 'Q_total')
        error('boundary.csv 缺少必需参数: Q_TOTAL');
    end
    if ~isfield(Boundary, 'inlet_node')
        error('boundary.csv 缺少必需参数: INLET_NODE');
    end
    if ~isfield(Boundary, 'outlet_node')
        error('boundary.csv 缺少必需参数: OUTLET_NODE');
    end
end


%% ========== 子函数：读取求解器配置 ==========

function Options = load_solver_config(filepath)
    % 读取 solver_config.csv 文件（键值对格式）

    fid = fopen(filepath, 'r', 'n', 'UTF-8');
    if fid == -1
        error('无法打开文件: %s', filepath);
    end

    Options = get_default_solver_options();  % 先设置默认值

    while ~feof(fid)
        line = fgetl(fid);

        % 跳过注释和空行
        if isempty(line) || startsWith(strtrim(line), '#')
            continue;
        end

        % 解析键值对
        parts = strsplit(line, ',');
        if length(parts) < 2
            continue;
        end

        key = upper(strtrim(parts{1}));
        value = strtrim(parts{2});

        % 根据键名解析
        switch key
            case 'MAX_ITER'
                Options.max_iter = str2double(value);

            case 'TOLERANCE'
                Options.tolerance = str2double(value);

            case 'METHOD'
                Options.method = value;

            case 'VERBOSE'
                Options.verbose = parse_boolean(value);

            case 'RELAXATION'
                Options.relaxation = str2double(value);
        end
    end

    fclose(fid);
end


%% ========== 子函数：默认求解器选项 ==========

function Options = get_default_solver_options()
    Options = struct();
    Options.max_iter = 1000;
    Options.tolerance = 1e-3;
    Options.method = 'HardyCross';
    Options.verbose = true;
    Options.relaxation = 1.0;
end


%% ========== 子函数：解析布尔值 ==========

function bool_val = parse_boolean(str)
    str = lower(str);
    if strcmp(str, 'true') || strcmp(str, '1')
        bool_val = true;
    elseif strcmp(str, 'false') || strcmp(str, '0')
        bool_val = false;
    else
        error('无效的布尔值: %s', str);
    end
end


%% ========== 子函数：数据校验 ==========

function validate_network_data(Branches, Boundary)
    % 校验网络数据的合法性

    % 1. 检查分支编号是否连续
    if ~isequal(sort(Branches.id), (1:length(Branches.id))')
        warning('分支编号不连续！建议从1开始连续编号。');
    end

    % 2. 检查风阻是否为正数
    if any(Branches.R <= 0)
        error('风阻系数必须为正数！');
    end

    % 3. 检查总风量是否为正数
    if Boundary.Q_total <= 0
        error('总风量必须为正数！');
    end

    % 4. 检查节点编号
    max_node = max([Branches.from_node; Branches.to_node]);
    min_node = min([Branches.from_node; Branches.to_node]);
    if min_node < 1
        error('节点编号必须从1开始！');
    end
    inlet_invalid = Boundary.inlet_node < 1 | Boundary.inlet_node > max_node;
    if any(inlet_invalid)
        error('入风节点编号 %d 不存在！', Boundary.inlet_node(find(inlet_invalid, 1)));
    end
    outlet_invalid = Boundary.outlet_node < 1 | Boundary.outlet_node > max_node;
    if any(outlet_invalid)
        error('回风节点编号 %d 不存在！', Boundary.outlet_node(find(outlet_invalid, 1)));
    end

    fprintf('  分支数: %d\n', length(Branches.id));
    fprintf('  节点数: %d\n', max_node);
    fprintf('  入风节点: [%s]\n', num2str(Boundary.inlet_node'));
    fprintf('  回风节点: [%s]\n', num2str(Boundary.outlet_node'));
end
