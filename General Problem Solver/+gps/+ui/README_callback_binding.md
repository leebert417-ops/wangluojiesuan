# MATLAB App Designer 按钮回调函数绑定教程

## 📋 目录

1. [方法 A：可视化绑定（推荐）](#方法-a可视化绑定推荐)
2. [方法 B：代码绑定](#方法-b代码绑定)
3. [方法 C：在 startupFcn 中绑定](#方法-c在-startupfcn-中绑定)
4. [常见问题](#常见问题)

---

## 方法 A：可视化绑定（推荐）

### 适用场景
- 初学者友好
- 快速创建简单回调
- MATLAB 自动管理代码

### 操作步骤

#### 步骤 1：打开 App Designer

```matlab
% 在命令窗口输入
appdesigner
```

或者双击已有的 `.mlapp` 文件。

#### 步骤 2：选择按钮组件

1. 在设计视图中，**点击选中**你要绑定的按钮
2. 确保按钮被选中（周围有蓝色边框）

#### 步骤 3：打开回调设置

**方法 1：右键菜单**
1. 右键点击按钮
2. 选择 **"回调"** → **"ButtonPushedFcn"**

**方法 2：属性面板**
1. 选中按钮后，查看右侧的 **"属性"** 面板
2. 找到 **"回调"** 部分
3. 点击 **"ButtonPushedFcn"** 旁边的下拉箭头
4. 选择 **"生成回调函数"**

```
属性面板示意：
┌─────────────────────────────┐
│ 属性                        │
├─────────────────────────────┤
│ 文本                        │
│   Text: 求解                │
├─────────────────────────────┤
│ 回调                        │
│   ButtonPushedFcn: [▼]      │ ← 点击这里
│     → 生成回调函数          │
│     → 编辑现有回调          │
└─────────────────────────────┘
```

#### 步骤 4：编写回调函数

MATLAB 会自动切换到代码视图，并生成如下代码框架：

```matlab
% Button pushed function: SolveButton
function SolveButtonPushed(app, event)
    % 在这里编写你的代码
end
```

#### 步骤 5：添加功能代码

在函数内部添加你需要的功能：

```matlab
% Button pushed function: SolveButton
function SolveButtonPushed(app, event)
    % 调用求解函数
    [Q, Results, success] = gps.ui.solve_network_from_ui(app);

    if success
        uialert(app.UIFigure, '求解成功！', '完成', 'Icon', 'success');
    end
end
```

#### 步骤 6：保存并测试

1. 保存 App（Ctrl+S）
2. 点击 **"运行"** 按钮（绿色三角）
3. 测试按钮功能

---

## 方法 B：代码绑定

### 适用场景
- 需要动态绑定回调
- 批量绑定多个按钮
- 更灵活的控制

### 操作步骤

#### 步骤 1：手动创建回调函数

在代码视图的 `methods (Access = private)` 部分添加函数：

```matlab
methods (Access = private)

    % 自定义的回调函数
    function mySolveCallback(app, src, event)
        [Q, Results, success] = gps.ui.solve_network_from_ui(app);
    end

end
```

#### 步骤 2：在 startupFcn 中绑定

在 `startupFcn` 中使用赋值语句绑定：

```matlab
function startupFcn(app)
    % 添加路径
    addpath('General Problem Solver');

    % 手动绑定回调函数
    app.SolveButton.ButtonPushedFcn = @app.mySolveCallback;
end
```

---

## 方法 C：在 startupFcn 中绑定

### 适用场景
- 简单的回调逻辑
- 使用匿名函数
- 快速原型开发

### 使用匿名函数

```matlab
function startupFcn(app)
    % 方式 1：简单匿名函数
    app.SolveButton.ButtonPushedFcn = @(src, event) ...
        gps.ui.solve_network_from_ui(app);

    % 方式 2：多行匿名函数（使用圆括号）
    app.ImportButton.ButtonPushedFcn = @(src, event) ( ...
        gps.ui.import_branches_csv_to_uitable(app.UITable), ...
        disp('导入完成') ...
    );
end
```

### 使用函数句柄

```matlab
function startupFcn(app)
    % 绑定到已有的回调函数
    app.SolveButton.ButtonPushedFcn = @app.SolveButtonPushed;
    app.ImportButton.ButtonPushedFcn = @app.ImportButtonPushed;
    app.ExportButton.ButtonPushedFcn = @app.ExportButtonPushed;
end
```

---

## 完整示例：通风网络求解器按钮绑定

### 示例 1：基本按钮绑定

```matlab
function startupFcn(app)
    % 添加路径
    addpath('General Problem Solver');

    % 设置 UITable 属性
    app.UITable.ColumnName = {'ID', '起点', '终点', '风阻'};
    app.UITable.ColumnEditable = [false, true, true, true];

    % 设置默认值
    app.EditField.Value = 100;           % 初始风量
    app.EditField_2.Value = '1';         % 入风节点
    app.EditField_3.Value = '10';        % 回风节点
end

% 导入按钮回调
function ImportButtonPushed(app, event)
    T = gps.ui.import_branches_csv_to_uitable(app.UITable);
    if ~isempty(T)
        app.UITable.ColumnEditable = [false, true, true, true];
        app.SolveButton.Enable = 'on';
    end
end

% 添加新行按钮回调
function AddRowButtonPushed(app, event)
    gps.ui.add_new_row_to_uitable(app.UITable);
end

% 删除选中行按钮回调
function DeleteRowButtonPushed(app, event)
    gps.ui.delete_selected_rows_from_uitable(app.UITable, 'confirm', true);
end

% 清空按钮回调
function ClearButtonPushed(app, event)
    gps.ui.clear_uitable(app.UITable, 'confirm', true);
end

% 求解按钮回调
function SolveButtonPushed(app, event)
    [Q, Results, success] = gps.ui.solve_network_from_ui(app);

    if success
        % 将风量结果添加到表格
        app.UITable.Data.风量 = Q;
        app.StatusLabel.Text = sprintf('求解成功（迭代 %d 次）', Results.iterations);
    end
end

% 导出按钮回调
function ExportButtonPushed(app, event)
    gps.ui.export_uitable_to_branches_csv(app.UITable);
end
```

### 示例 2：使用 startupFcn 批量绑定

```matlab
function startupFcn(app)
    % 添加路径
    addpath('General Problem Solver');

    % 批量绑定（使用匿名函数）
    app.ImportButton.ButtonPushedFcn = @(~,~) ...
        gps.ui.import_branches_csv_to_uitable(app.UITable);

    app.AddRowButton.ButtonPushedFcn = @(~,~) ...
        gps.ui.add_new_row_to_uitable(app.UITable);

    app.DeleteRowButton.ButtonPushedFcn = @(~,~) ...
        gps.ui.delete_selected_rows_from_uitable(app.UITable, 'confirm', true);

    app.ClearButton.ButtonPushedFcn = @(~,~) ...
        gps.ui.clear_uitable(app.UITable, 'confirm', true);

    app.SolveButton.ButtonPushedFcn = @(~,~) ...
        gps.ui.solve_network_from_ui(app);

    app.ExportButton.ButtonPushedFcn = @(~,~) ...
        gps.ui.export_uitable_to_branches_csv(app.UITable);
end
```

---

## 按钮回调函数的参数说明

### 标准回调函数格式

```matlab
function ButtonPushed(app, event)
    % app   - App Designer 应用对象（包含所有组件）
    % event - 事件对象（包含事件相关信息）
end
```

### 参数详解

| 参数 | 类型 | 说明 | 用途 |
|------|------|------|------|
| `app` | `matlab.apps.AppBase` | 应用对象 | 访问所有 UI 组件（app.UITable, app.EditField 等） |
| `event` | `matlab.ui.eventdata.ButtonPushedData` | 事件数据 | 包含事件源、时间戳等信息（通常不用） |

### 使用 app 对象访问组件

```matlab
function SolveButtonPushed(app, event)
    % 访问 UITable
    data = app.UITable.Data;

    % 访问 EditField
    Q_total = app.EditField.Value;

    % 修改按钮状态
    app.SolveButton.Enable = 'off';
    app.SolveButton.Text = '求解中...';

    % 更新标签
    app.StatusLabel.Text = '正在求解...';

    % 调用函数
    [Q, Results, success] = gps.ui.solve_network_from_ui(app);

    % 恢复按钮
    app.SolveButton.Enable = 'on';
    app.SolveButton.Text = '求解';
end
```

---

## 常见问题

### Q1：如何查看按钮是否已绑定回调？

**方法 1：属性面板**
1. 选中按钮
2. 查看属性面板的"回调"部分
3. 如果 `ButtonPushedFcn` 显示函数名（如 `@SolveButtonPushed`），说明已绑定

**方法 2：代码视图**
1. 切换到代码视图
2. 搜索按钮的回调函数名（如 `SolveButtonPushed`）
3. 如果存在该函数，说明已绑定

**方法 3：命令行查询**
```matlab
% 在 App 运行时查询（假设 app 是应用对象）
app.SolveButton.ButtonPushedFcn
% 输出：@(source,event)SolveButtonPushed(app,event)
```

### Q2：如何修改已有的回调函数？

**方法 1：直接在代码视图中修改**
1. 切换到代码视图
2. 找到回调函数
3. 直接修改代码

**方法 2：通过属性面板**
1. 选中按钮
2. 在属性面板的"回调"中点击 `ButtonPushedFcn`
3. 选择"编辑现有回调"

### Q3：如何删除回调绑定？

**方法 1：通过代码**
```matlab
function startupFcn(app)
    % 清除回调绑定
    app.SolveButton.ButtonPushedFcn = [];
end
```

**方法 2：删除回调函数**
1. 在代码视图中删除整个回调函数
2. 保存 App
3. MATLAB 会自动解除绑定

### Q4：回调函数中出现错误怎么办？

**调试方法**

```matlab
function SolveButtonPushed(app, event)
    try
        % 你的代码
        [Q, Results, success] = gps.ui.solve_network_from_ui(app);

    catch ME
        % 捕获并显示错误
        uialert(app.UIFigure, ...
            sprintf('错误：%s', ME.message), ...
            '错误', 'Icon', 'error');

        % 打印详细错误信息到命令窗口
        fprintf('错误详情：\n');
        fprintf('  消息：%s\n', ME.message);
        fprintf('  标识符：%s\n', ME.identifier);
        fprintf('  堆栈：\n');
        for i = 1:length(ME.stack)
            fprintf('    %s (第 %d 行)\n', ...
                ME.stack(i).name, ME.stack(i).line);
        end
    end
end
```

### Q5：如何给一个按钮绑定多个功能？

**方法 1：在回调函数中顺序执行**

```matlab
function ProcessButtonPushed(app, event)
    % 功能 1：导入数据
    T = gps.ui.import_branches_csv_to_uitable(app.UITable);

    % 功能 2：自动添加一行
    gps.ui.add_new_row_to_uitable(app.UITable);

    % 功能 3：提示用户
    uialert(app.UIFigure, '数据已导入并添加新行', '完成');
end
```

**方法 2：调用多个子函数**

```matlab
function ProcessButtonPushed(app, event)
    importData(app);
    processData(app);
    displayResults(app);
end

function importData(app)
    % 导入逻辑
end

function processData(app)
    % 处理逻辑
end

function displayResults(app)
    % 显示逻辑
end
```

### Q6：如何禁用/启用按钮？

```matlab
% 禁用按钮
app.SolveButton.Enable = 'off';

% 启用按钮
app.SolveButton.Enable = 'on';

% 在回调中临时禁用
function SolveButtonPushed(app, event)
    % 禁用按钮（防止重复点击）
    app.SolveButton.Enable = 'off';

    try
        % 执行耗时操作
        [Q, Results, success] = gps.ui.solve_network_from_ui(app);
    catch ME
        % 错误处理
    end

    % 恢复按钮
    app.SolveButton.Enable = 'on';
end
```

### Q7：如何在按钮回调中传递额外参数？

**方法：使用 app 的自定义属性**

1. 在设计视图中，右键点击空白区域 → "编辑应用程序" → "添加属性"
2. 添加自定义属性（如 `CustomParam`）

```matlab
properties (Access = public)
    CustomParam = 100;  % 自定义参数
end

function startupFcn(app)
    % 设置自定义参数
    app.CustomParam = 200;
end

function SolveButtonPushed(app, event)
    % 使用自定义参数
    fprintf('使用参数：%d\n', app.CustomParam);
end
```

---

## 快速参考表

| 绑定方法 | 难度 | 灵活性 | 适用场景 |
|---------|------|--------|---------|
| **方法 A：可视化** | ⭐ | ⭐⭐ | 初学者、简单回调 |
| **方法 B：代码绑定** | ⭐⭐ | ⭐⭐⭐ | 动态绑定、批量操作 |
| **方法 C：匿名函数** | ⭐⭐⭐ | ⭐⭐⭐⭐ | 高级用户、快速原型 |

---

## 推荐的项目结构

```matlab
classdef NetworkSolverApp < matlab.apps.AppBase

    properties (Access = public)
        UIFigure
        UITable
        SolveButton
        % ... 其他组件
    end

    methods (Access = private)

        % 启动函数
        function startupFcn(app)
            addpath('General Problem Solver');
            setupUI(app);
            setDefaultValues(app);
        end

        % UI 初始化
        function setupUI(app)
            app.UITable.ColumnName = {'ID', '起点', '终点', '风阻'};
            app.UITable.ColumnEditable = [false, true, true, true];
        end

        % 设置默认值
        function setDefaultValues(app)
            app.EditField.Value = 100;
            app.EditField_2.Value = '1';
            app.EditField_3.Value = '10';
        end

        % 按钮回调
        function SolveButtonPushed(app, event)
            [Q, Results, success] = gps.ui.solve_network_from_ui(app);
        end

        function ImportButtonPushed(app, event)
            gps.ui.import_branches_csv_to_uitable(app.UITable);
        end

        % ... 其他回调

    end
end
```

---

## 总结

### ✅ 推荐做法
1. **初学者**：使用方法 A（可视化绑定）
2. **有经验用户**：使用方法 A + 在 `startupFcn` 中设置默认值
3. **高级用户**：根据需要混合使用三种方法

### ⚠️ 注意事项
- 回调函数必须是 `app` 对象的方法
- 回调函数签名必须为 `function name(app, event)`
- 避免在回调中执行过长时间的操作（会阻塞 UI）
- 使用 `try-catch` 捕获错误，避免 App 崩溃

### 📖 相关文档
- [MATLAB App Designer 官方文档](https://www.mathworks.com/help/matlab/app-designer.html)
- [回调函数编写指南](https://www.mathworks.com/help/matlab/creating_guis/write-callbacks-in-app-designer.html)
