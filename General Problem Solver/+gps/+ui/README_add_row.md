# UITable 添加新行功能使用说明

## 📦 文件信息

**文件名**：`add_new_row_to_uitable.m`
**位置**：`General Problem Solver/+gps/+ui/`
**版本**：v1.0 (2025-12-18)
**作者**：MATLAB 通风工程专家助手

---

## 🎯 功能说明

在 App Designer 的 UITable 末尾添加新的空白行，自动处理以下内容：

- ✅ **ID 自动递增**（基于当前最大 ID + 1）
- ✅ **其他列填充默认值**
  - 起点：0（需要用户编辑）
  - 终点：0（需要用户编辑）
  - 风阻：0.1（默认值，可修改）
- ✅ **自动设置可编辑性**（ID 不可编辑，其他列可编辑）
- ✅ **自动滚动到新行**（MATLAB R2021a+）
- ✅ **支持空表格和已有数据的表格**

---

## 🚀 快速使用

### 在 App Designer 按钮回调中调用

```matlab
% "添加行"或"新建"按钮回调函数
function AddRowButtonPushed(app, event)
    % 调用添加行函数
    gps.ui.add_new_row_to_uitable(app.UITable);
end
```

### 获取新行索引

```matlab
% 返回新添加行的索引（行号）
newRowIdx = gps.ui.add_new_row_to_uitable(app.UITable);

fprintf('新行位于第 %d 行\n', newRowIdx);
```

---

## 📋 功能详解

### 1. ID 自动递增逻辑

| 场景 | 当前最大 ID | 新行 ID |
|-----|------------|---------|
| 空表格 | - | 1 |
| 连续 ID (1,2,3) | 3 | 4 |
| 不连续 ID (1,3,7) | 7 | 8 |
| 单行 (5) | 5 | 6 |

**算法**：新 ID = max(现有 ID) + 1

### 2. 默认值设置

| 列名 | 默认值 | 说明 |
|-----|-------|------|
| ID | 自动计算 | 基于最大 ID + 1 |
| 起点 | 0 | 用户需要编辑为实际节点编号 |
| 终点 | 0 | 用户需要编辑为实际节点编号 |
| 风阻 | 0.1 | 常见风阻值，用户可修改 |

**提示**：起点和终点设为 0 是为了提醒用户必须修改（0 不是有效节点）。

### 3. 可编辑性设置

添加行后自动设置：
```matlab
app.UITable.ColumnEditable = [false, true, true, true];
```

- **ID 列（第1列）**：不可编辑（保证 ID 唯一性）
- **起点、终点、风阻（第2-4列）**：可编辑

---

## 🎨 使用场景示例

### 场景 1：基本用法

```matlab
% App Designer 按钮回调
function AddRowButtonPushed(app, event)
    gps.ui.add_new_row_to_uitable(app.UITable);
end
```

### 场景 2：批量添加多行

```matlab
function AddMultipleRowsButtonPushed(app, event)
    % 询问用户要添加多少行
    answer = inputdlg('要添加多少行？', '批量添加', 1, {'5'});

    if isempty(answer)
        return;
    end

    numRows = str2double(answer{1});

    if ~isfinite(numRows) || numRows <= 0
        uialert(app.UIFigure, '请输入有效的正整数', '错误');
        return;
    end

    % 批量添加
    for i = 1:numRows
        gps.ui.add_new_row_to_uitable(app.UITable);
    end

    uialert(app.UIFigure, sprintf('已添加 %d 行', numRows), '完成');
end
```

### 场景 3：添加后自动聚焦

```matlab
function AddRowButtonPushed(app, event)
    % 添加新行
    newRowIdx = gps.ui.add_new_row_to_uitable(app.UITable);

    % 提示用户编辑新行
    uialert(app.UIFigure, ...
        sprintf('已添加新行（ID=%d）\n请编辑起点、终点和风阻', ...
        app.UITable.Data{newRowIdx, 1}), ...
        '提示', 'Icon', 'info');
end
```

### 场景 4：添加带默认值的行

如果需要自定义默认值，可以修改函数或在添加后立即修改：

```matlab
function AddRowButtonPushed(app, event)
    % 添加新行
    newRowIdx = gps.ui.add_new_row_to_uitable(app.UITable);

    % 自定义默认值（例如：起点=1，终点=2，风阻=0.2）
    app.UITable.Data{newRowIdx, 2} = 1;   % 起点
    app.UITable.Data{newRowIdx, 3} = 2;   % 终点
    app.UITable.Data{newRowIdx, 4} = 0.2; % 风阻
end
```

### 场景 5：添加前确认

```matlab
function AddRowButtonPushed(app, event)
    % 确认对话框
    choice = uiconfirm(app.UIFigure, ...
        '确定要添加新行吗？', ...
        '确认', ...
        'Options', {'确定', '取消'});

    if strcmp(choice, '确定')
        newRowIdx = gps.ui.add_new_row_to_uitable(app.UITable);

        % 更新状态标签
        if isfield(app, 'StatusLabel')
            app.StatusLabel.Text = sprintf('已添加新行（第 %d 行）', newRowIdx);
        end
    end
end
```

---

## 🧪 测试验证

### 运行完整测试

```matlab
% 在 MATLAB 命令窗口执行
cd 'General Problem Solver/+gps/+ui'
test_add_row
```

### 测试覆盖

测试脚本包含 7 个完整测试用例：

| 测试用例 | 测试内容 | 预期结果 |
|---------|---------|---------|
| 测试 1 | 空表格添加第一行 | ✓ ID=1 |
| 测试 2 | 已有数据添加新行 | ✓ ID 正确递增 |
| 测试 3 | 连续添加 5 行 | ✓ ID 1-5 连续 |
| 测试 4 | ID 不连续时处理 | ✓ 基于最大 ID |
| 测试 5 | 默认值验证 | ✓ 起点=0, 终点=0, 风阻=0.1 |
| 测试 6 | 可编辑性验证 | ✓ [false, true, true, true] |
| 测试 7 | 用户交互演示 | ✓ 带按钮的实时演示 |

---

## 🔧 在 App Designer 中配置

### 步骤 1：添加"添加行"按钮

1. 打开 App Designer
2. 从组件库拖入 `Button` 组件
3. 设置属性：
   - **Text**: "添加新行" 或 "新建"
   - **Tag**: "AddRowButton"
   - **Position**: 在表格附近合适位置

### 步骤 2：绑定回调函数

**方法 A：可视化绑定**
1. 右键点击按钮 → "回调" → "ButtonPushedFcn"
2. 在生成的回调中添加代码：

```matlab
function AddRowButtonPushed(app, event)
    gps.ui.add_new_row_to_uitable(app.UITable);
end
```

**方法 B：代码绑定**
在 `startupFcn` 中：
```matlab
function startupFcn(app)
    app.AddRowButton.ButtonPushedFcn = @(src, event) ...
        gps.ui.add_new_row_to_uitable(app.UITable);
end
```

### 步骤 3：测试

1. 保存并运行 App
2. 点击"添加新行"按钮
3. 验证：
   - ✅ 表格末尾添加了新行
   - ✅ ID 自动递增
   - ✅ 其他列可编辑
   - ✅ 可以手动修改起点、终点、风阻

---

## 📊 配套功能组合

### 完整的表格编辑工作流

```
┌───────────┐
│  导入数据  │
└─────┬─────┘
      │
      ▼
┌───────────┐      ┌───────────┐
│ 表格显示  │◄────▶│  添加新行  │  ← 本功能
└─────┬─────┘      └───────────┘
      │
      ▼
┌───────────┐
│ 手动编辑  │
└─────┬─────┘
      │
      ▼
┌───────────┐
│  导出数据  │
└───────────┘
```

### 推荐按钮布局

```
┌─────────────────────────────────────────┐
│  [导入]  [导出]  [添加新行]  [删除行]  │
├─────────────────────────────────────────┤
│                                         │
│              UITable                    │
│                                         │
└─────────────────────────────────────────┘
```

---

## 💡 高级用法

### 用法 1：添加行后自动填充相邻值

```matlab
function AddRowButtonPushed(app, event)
    newRowIdx = gps.ui.add_new_row_to_uitable(app.UITable);

    % 如果不是第一行，可以参考上一行的值
    if newRowIdx > 1
        prevRow = app.UITable.Data(newRowIdx-1, :);

        % 终点 = 上一行终点 + 1
        app.UITable.Data{newRowIdx, 3} = prevRow{1, 3} + 1;

        % 风阻 = 上一行风阻（相同）
        app.UITable.Data{newRowIdx, 4} = prevRow{1, 4};
    end
end
```

### 用法 2：带数据验证的添加

```matlab
function AddRowButtonPushed(app, event)
    % 检查当前数据是否有效
    if ~isempty(app.UITable.Data)
        % 检查最后一行是否已填写完整
        lastRow = app.UITable.Data(end, :);
        if lastRow{1, 2} == 0 || lastRow{1, 3} == 0
            choice = uiconfirm(app.UIFigure, ...
                '上一行尚未填写完整，确定要添加新行吗？', ...
                '提示', 'Options', {'确定', '取消'});
            if strcmp(choice, '取消')
                return;
            end
        end
    end

    % 添加新行
    gps.ui.add_new_row_to_uitable(app.UITable);
end
```

### 用法 3：显示添加历史

```matlab
properties (Access = private)
    AddRowCount = 0;  % 记录添加次数
end

function AddRowButtonPushed(app, event)
    newRowIdx = gps.ui.add_new_row_to_uitable(app.UITable);

    % 更新计数器
    app.AddRowCount = app.AddRowCount + 1;

    % 更新状态标签
    app.StatusLabel.Text = sprintf('已添加 %d 行（最新行号：%d）', ...
        app.AddRowCount, newRowIdx);
end
```

---

## ⚙️ 自定义默认值

如果需要修改默认值（起点、终点、风阻），可以编辑函数第 **57-61** 行：

```matlab
% 原始代码
newRow = table( ...
    newID, ...
    0, ...      % 起点默认值
    0, ...      % 终点默认值
    0.1, ...    % 风阻默认值
    'VariableNames', {'ID', '起点', '终点', '风阻'} ...
);

% 自定义示例：起点=1, 终点=2, 风阻=0.2
newRow = table( ...
    newID, ...
    1, ...      % 起点默认值改为 1
    2, ...      % 终点默认值改为 2
    0.2, ...    # 风阻默认值改为 0.2
    'VariableNames', {'ID', '起点', '终点', '风阻'} ...
);
```

---

## ⚠️ 注意事项

### 1. ID 重复问题

函数会自动基于**最大 ID** 生成新 ID，但如果用户手动修改了 ID 列（虽然设为不可编辑），可能导致重复。

**预防措施**：
- 设置 `ColumnEditable = [false, true, true, true]`（ID 不可编辑）
- 导出前验证 ID 唯一性

### 2. 数据类型问题

确保表格数据为 `table` 类型，不支持普通矩阵。

### 3. 滚动功能

`scroll(uitableHandle, 'row', newRowIndex)` 仅在 **MATLAB R2021a** 及以上版本支持，旧版本会自动忽略。

### 4. 默认值提醒

起点和终点默认为 `0` 是为了提醒用户必须修改，因为 `0` 不是有效的节点编号（节点编号从 1 开始）。

---

## 🔗 相关功能

| 功能 | 函数 | 说明 |
|-----|------|------|
| 导入数据 | `import_branches_csv_to_uitable.m` | 从 CSV 导入到表格 |
| 导出数据 | `export_uitable_to_branches_csv.m` | 从表格导出到 CSV |
| **添加新行** | **`add_new_row_to_uitable.m`** | **在表格末尾添加行** |
| 删除行 | （待开发）| 删除选中的行 |

---

## 📝 常见问题

### Q1：能否在表格中间插入行？

**A**：当前版本仅支持在末尾追加。如需在中间插入，需要手动实现（通过 `app.UITable.Data` 数组操作）。

### Q2：能否自定义新行位置？

**A**：可以修改函数，在参数中指定插入位置（目前固定为末尾）。

### Q3：添加行后能否自动聚焦到某一列？

**A**：UITable 不支持单元格级别的焦点控制，只能聚焦到整个表格。

### Q4：如何一次添加多行？

**A**：在循环中调用函数（参见"批量添加"示例）。

---

## 📈 版本历史

- **v1.0** (2025-12-18) - 初始版本
  - ID 自动递增
  - 默认值填充
  - 可编辑性设置
  - 自动滚动（R2021a+）

---

## 👤 作者

MATLAB 通风工程专家助手

## 📄 许可

遵循项目主许可证
