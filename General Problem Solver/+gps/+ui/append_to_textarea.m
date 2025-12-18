function append_to_textarea(textarea, msg)
%APPEND_TO_TEXTAREA 向 TextArea 追加文本信息
%
% 用法：
%   append_to_textarea(app.TextArea, '消息内容');
%
% 输入：
%   textarea: TextArea 组件句柄
%   msg: 要追加的消息文本
%
% 功能：
%   - 向 TextArea 追加新文本
%   - 自动添加时间戳
%   - 保留历史记录
%   - 自动滚动到底部

    if nargin < 2 || isempty(textarea) || ~isvalid(textarea)
        return;
    end

    % 获取当前内容
    currentText = textarea.Value;

    % 如果是字符数组，转换为字符串数组
    if ischar(currentText)
        currentText = {currentText};
    end

    % 分割新消息为行
    newLines = strsplit(msg, '\n', 'CollapseDelimiters', false);
    newLines = newLines(1:end-1);  % 移除最后的空行（如果有）

    % 追加新内容
    textarea.Value = [currentText; newLines'];

    % 自动滚动到底部（R2020b+）
    try
        scroll(textarea, 'bottom');
    catch
        % 旧版本不支持 scroll，忽略
    end
end
