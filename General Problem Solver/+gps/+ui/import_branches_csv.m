function T = import_branches_csv(filePath)
%IMPORT_BRANCHES_CSV 读取分支数据 CSV（四列：id-起点-终点-风阻）
%
% 支持列名：
%   - 中文：id/ID，起点，终点，风阻
%   - 英文：branch_id/id，from_node/from，to_node/to，resistance/R
%
% 支持注释行：
%   - 以 # 开头的行将被自动忽略
%   - 可在 CSV 文件中添加说明性注释
%
% 输出：
%   T: table，变量名为 {'id','from_node','to_node','R'}
%
% 版本更新：
%   v1.1 (2025-12-18) - 支持 # 注释行，兼容 GPS 数据格式

    arguments
        filePath (1,1) string
    end

    if ~isfile(filePath)
        error('找不到文件: %s', filePath);
    end

    % 1) 优先按带表头 CSV 读取（支持 # 注释行）
    raw = table();
    try
        opts = detectImportOptions(filePath, 'FileType', 'text', ...
            'Delimiter', ',', 'CommentStyle', '#');
        opts = setvartype(opts, 'double');
        raw = readtable(filePath, opts, 'TextType', 'string', ...
            'VariableNamingRule', 'preserve');
    catch
    end

    if ~isempty(raw) && width(raw) >= 4
        T = normalize_table(raw);
        validate_table(T);
        return;
    end

    % 2) 无表头/读取失败时，按纯数值 4 列读取（跳过 # 注释）
    M = readmatrix(filePath, 'CommentStyle', '#');
    if size(M, 2) ~= 4
        error('CSV 需要 4 列数据（id, 起点, 终点, 风阻），当前列数=%d', size(M, 2));
    end
    T = table(M(:, 1), M(:, 2), M(:, 3), M(:, 4), ...
        'VariableNames', {'id', 'from_node', 'to_node', 'R'});
    validate_table(T);
end


function T = normalize_table(raw)
    names = string(raw.Properties.VariableNames);
    names_l = lower(strrep(names, ' ', ''));

    id_idx = find(ismember(names_l, ["id","branch_id","branchid"]), 1);
    if isempty(id_idx)
        id_idx = find(ismember(names, ["ID","id","编号"]), 1);
    end

    from_idx = find(ismember(names_l, ["from_node","fromnode","from","start","start_node"]), 1);
    if isempty(from_idx)
        from_idx = find(ismember(names, ["起点","from_node","from"]), 1);
    end

    to_idx = find(ismember(names_l, ["to_node","tonode","to","end","end_node"]), 1);
    if isempty(to_idx)
        to_idx = find(ismember(names, ["终点","to_node","to"]), 1);
    end

    r_idx = find(ismember(names_l, ["resistance","r","阻力","风阻"]), 1);
    if isempty(r_idx)
        r_idx = find(ismember(names, ["风阻","resistance","R"]), 1);
    end

    if any(cellfun(@isempty, {id_idx, from_idx, to_idx, r_idx}))
        error('CSV 表头不匹配：需要列 id/起点/终点/风阻（或等价英文列名）');
    end

    T = table( ...
        raw{:, id_idx}, ...
        raw{:, from_idx}, ...
        raw{:, to_idx}, ...
        raw{:, r_idx}, ...
        'VariableNames', {'id', 'from_node', 'to_node', 'R'} ...
    );
end


function validate_table(T)
    if any(~isfinite(T.id)) || any(~isfinite(T.from_node)) || any(~isfinite(T.to_node)) || any(~isfinite(T.R))
        error('CSV 中存在非数值/缺失值，请检查数据。');
    end
    if any(T.R <= 0)
        error('风阻必须为正数。');
    end
    if any(T.id <= 0) || any(mod(T.id, 1) ~= 0) || numel(unique(T.id)) ~= height(T)
        error('id 必须为正整数且不重复。');
    end
    if any(T.from_node <= 0) || any(mod(T.from_node, 1) ~= 0) || any(T.to_node <= 0) || any(mod(T.to_node, 1) ~= 0)
        error('起点/终点必须为正整数节点编号。');
    end
end

