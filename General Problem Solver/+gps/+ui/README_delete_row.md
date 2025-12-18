# UITable 删除选中行功能使用说明

## 📦 文件信息

**文件名**：`delete_selected_rows_from_uitable.m`
**位置**：`General Problem Solver/+gps/+ui/`
**版本**：v1.0 (2025-12-18)
**作者**：MATLAB 通风工程专家助手

---

## 🎯 功能说明

删除 App Designer 的 UITable 中当前选中的行，支持以下功能：

- ✅ **删除单行或多行**（支持不连续选择）
- ✅ **自动检测选中状态**
- ✅ **可选：ID 重新排序**（删除后 ID 连续编号）
- ✅ **可选：确认对话框**
- ✅ **边界情况处理**（未选中、空表格）
- ✅ **返回删除行数**

---

## 🚀 快速使用

### 基本用法（最简单）

```matlab
% "删除行"按钮回调函数
function DeleteRowButtonPushed(app, event)
    % 调用删除函数（无确认，自动重排 ID）
    gps.ui.delete_selected_rows_from_uitable(app.UITable);
end
```

### 带确认对话框

```matlab
function DeleteRowButtonPushed(app, event)
    % 带确认对话框的删除
    gps.ui.delete_selected_rows_from_uitable(app.UITable, 'confirm', true);
end
```

### 删除后重排 ID

```matlab
function DeleteRowButtonPushed(app, event)
    % 删除后重新连续编号 ID
    gps.ui.delete_selected_rows_from_uitable(app.UITable, 'reindexID', true);
end
```

### 完整用法（所有选项）

```matlab
function DeleteRowButtonPushed(app, event)
    % 删除行，带确认对话框，并重排 ID
    deletedCount = gps.ui.delete_selected_rows_from_uitable(app.UITable, ...
        'confirm', true, ...
        'reindexID', true);

    % 显示结果
    if deletedCount > 0
        app.StatusLabel.Text = sprintf('已删除 %d 行', deletedCount);
    end
end
```

---

## 📋 参数说明

### 输入参数

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `uitableHandle` | `matlab.ui.control.Table` | 必需 | UITable 组件句柄 |
| `reindexID` | `logical` | `true` | 是否重新排列 ID（连续编号）|
| `confirm` | `logical` | `false` | 是否显示确认对话框 |
| `confirmMsg` | `string` | 自动生成 | 自定义确认消息 |

### 输出参数

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `deletedCount` | `double` | 删除的行数 |

---

## 🎨 使用场景示例

### 场景 1：基本删除（无确认）

```matlab
function DeleteRowButtonPushed(app, event)
    gps.ui.delete_selected_rows_from_uitable(app.UITable);
end
```

### 场景 2：安全删除（带确认）

```matlab
function DeleteRowButtonPushed(app, event)
    gps.ui.delete_selected_rows_from_uitable(app.UITable, 'confirm', true);
end
```

### 场景 3：删除后更新状态

```matlab
function DeleteRowButtonPushed(app, event)
    % 删除选中行
    deletedCount = gps.ui.delete_selected_rows_from_uitable(app.UITable);

    % 更新状态标签
    if deletedCount > 0
        app.StatusLabel.Text = sprintf('已删除 %d 行', deletedCount);
        app.StatusLabel.FontColor = [0 0.6 0];  % 绿色
    else
        app.StatusLabel.Text = '请先选中要删除的行';
        app.StatusLabel.FontColor = [1 0.5 0];  % 橙色
    end
end
```

### 场景 4：删除并重排 ID

```matlab
function DeleteRowButtonPushed(app, event)
    % 删除行并重新连续编号
    deletedCount = gps.ui.delete_selected_rows_from_uitable(app.UITable, ...
        'reindexID', true, ...
        'confirm', true);

    if deletedCount > 0
        uialert(app.UIFigure, ...
            sprintf('已删除 %d 行，ID 已重新排列', deletedCount), ...
            '完成', 'Icon', 'success');
    end
end
```

### 场景 5：自定义确认消息

```matlab
function DeleteRowButtonPushed(app, event)
    % 自定义确认消息
    gps.ui.delete_selected_rows_from_uitable(app.UITable, ...
        'confirm', true, ...
        'confirmMsg', '删除后无法恢复，确定要删除吗？');
end
```

### 场景 6：删除前验证

```matlab
function DeleteRowButtonPushed(app, event)
    % 检查是否有数据
    if isempty(app.UITable.Data)
        uialert(app.UIFigure, '表格为空', '提示');
        return;
    end

    % 检查是否有选中
    if isempty(app.UITable.Selection)
        uialert(app.UIFigure, '请先选中要删除的行', '提示');
        return;
    end

    % 执行删除
    deletedCount = gps.ui.delete_selected_rows_from_uitable(app.UITable, ...
        'confirm', true);
end
```

---

## 📊 ID 重排行为对比

### 不重排 ID `reindexID = false`

**操作前**：
| ID | 起点 | 终点 | 风阻 |
|----|------|------|------|
| 1 | 1 | 2 | 0.1 |
| 3 | 2 | 3 | 0.2 |
| 5 | 3 | 4 | 0.15 |
| 7 | 4 | 5 | 0.25 |

**选中第 2 行（ID=3）并删除**

**操作后**：
| ID | 起点 | 终点 | 风阻 |
|----|------|------|------|
| 1 | 1 | 2 | 0.1 |
| 5 | 3 | 4 | 0.15 |
| 7 | 4 | 5 | 0.25 |

✅ **保留原 ID 值**（ID 可能不连续）

---

### 重排 ID（默认）`reindexID = true`

**操作前**：
| ID | 起点 | 终点 | 风阻 |
|----|------|------|------|
| 1 | 1 | 2 | 0.1 |
| 3 | 2 | 3 | 0.2 |
| 5 | 3 | 4 | 0.15 |
| 7 | 4 | 5 | 0.25 |

**选中第 2 行（ID=3）并删除**

**操作后**：
| ID | 起点 | 终点 | 风阻 |
|----|------|------|------|
| **1** | 1 | 2 | 0.1 |
| **2** | 3 | 4 | 0.15 |
| **3** | 4 | 5 | 0.25 |

✅ **重新连续编号**（ID 始终为 1, 2, 3, ...）

---

## 🖱️ 如何选中行

### 方法 1：点击行号

```
┌────┬──────┬──────┬────────┐
│    │  ID  │ 起点 │ 终点   │
├────┼──────┼──────┼────────┤
│ 1  │  1   │  1   │  2     │  ← 点击左侧行号
│ 2  │  2   │  2   │  3     │  ← 点击左侧行号
│ 3  │  3   │  3   │  4     │
└────┴──────┴──────┴────────┘
```

### 方法 2：点击单元格

- 点击任意单元格会选中整行

### 方法 3：多选（按住 Ctrl 或 Shift）

- **Ctrl + 点击**：选中多个不连续的行
- **Shift + 点击**：选中连续的行范围

---

## 🔧 在 App Designer 中配置

### 步骤 1：确保 UITable 支持行选择

在 App Designer 设计视图中：
1. 选中 UITable 组件
2. 在属性面板中找到 **"Selection"** 部分
3. 设置 **`SelectionType`** 为 **`'row'`** 或 **`'cell'`**

```matlab
% 或在代码中设置
app.UITable.SelectionType = 'row';  % 整行选择
```

### 步骤 2：添加"删除行"按钮

1. 从组件库拖入 `Button` 组件
2. 设置属性：
   - **Text**: "删除选中行"
   - **Tag**: "DeleteRowButton"

### 步骤 3：绑定回调函数

**方法 A：可视化绑定**
1. 右键点击按钮 → "回调" → "ButtonPushedFcn"
2. 在生成的回调中添加代码：

```matlab
function DeleteRowButtonPushed(app, event)
    gps.ui.delete_selected_rows_from_uitable(app.UITable, 'confirm', true);
end
```

**方法 B：代码绑定**
```matlab
function startupFcn(app)
    app.DeleteRowButton.ButtonPushedFcn = @(src, event) ...
        gps.ui.delete_selected_rows_from_uitable(app.UITable, 'confirm', true);
end
```

### 步骤 4：测试

1. 保存并运行 App
2. 在表格中选中一行或多行（点击行号）
3. 点击"删除选中行"按钮
4. 验证：
   - ✅ 弹出确认对话框
   - ✅ 确认后成功删除选中行
   - ✅ 表格自动更新

---

## 🧪 测试验证

### 运行完整测试

```matlab
% 在 MATLAB 命令窗口执行
cd 'General Problem Solver/+gps/+ui'
test_delete_row
```

### 测试覆盖清单

- ✅ **测试 1**：删除单行
- ✅ **测试 2**：删除多行（不连续）
- ✅ **测试 3**：未选中时的处理
- ✅ **测试 4**：删除后 ID 重排（默认）
- ✅ **测试 5**：不重排 ID
- ✅ **测试 6**：删除所有行
- ✅ **测试 7**：用户交互演示（带确认）

---

## 💡 高级用法

### 用法 1：条件删除（根据内容验证）

```matlab
function DeleteRowButtonPushed(app, event)
    % 获取选中的行
    selection = app.UITable.Selection;

    if isempty(selection)
        uialert(app.UIFigure, '请先选中要删除的行', '提示');
        return;
    end

    % 获取选中行的 ID
    selectedRows = unique(selection(:, 1));
    selectedIDs = app.UITable.Data{selectedRows, 1};

    % 检查是否有重要数据（示例：ID=1 不能删除）
    if any(selectedIDs == 1)
        choice = uiconfirm(app.UIFigure, ...
            'ID=1 是主入风分支，确定要删除吗？', ...
            '警告', ...
            'Options', {'删除', '取消'}, ...
            'DefaultOption', 2, ...
            'Icon', 'warning');

        if strcmp(choice, '取消')
            return;
        end
    end

    % 执行删除
    gps.ui.delete_selected_rows_from_uitable(app.UITable);
end
```

### 用法 2：快捷键删除（Delete 键）

```matlab
function UITableKeyPress(app, event)
    % 按 Delete 键删除选中行
    if strcmp(event.Key, 'delete')
        gps.ui.delete_selected_rows_from_uitable(app.UITable, 'confirm', true);
    end
end
```

在 App Designer 中绑定：
1. 选中 UITable
2. 在回调中添加 **`KeyPressFcn`**

### 用法 3：右键菜单删除

```matlab
function startupFcn(app)
    % 创建右键菜单
    cm = uicontextmenu(app.UIFigure);
    app.UITable.ContextMenu = cm;

    % 添加删除菜单项
    uimenu(cm, 'Text', '删除选中行', 'MenuSelectedFcn', ...
        @(src, event) gps.ui.delete_selected_rows_from_uitable(app.UITable, 'confirm', true));
end
```

---

## 📈 配套功能组合

### 完整的表格编辑工作流

```
┌──────────┐
│ 导入 CSV │
└────┬─────┘
     │
     ▼
┌──────────┐      ┌──────────┐      ┌──────────┐
│ 表格显示 │◄────▶│ 添加新行 │◄────▶│ 删除选中行│ ← 本功能
└────┬─────┘      └──────────┘      └──────────┘
     │
     ▼
┌──────────┐
│ 手动编辑 │
└────┬─────┘
     │
     ▼
┌──────────┐
│ 导出 CSV │
└──────────┘
```

### 推荐按钮布局

```
┌───────────────────────────────────────────────┐
│ [导入]  [导出]  [添加新行]  [删除选中行]     │
├───────────────────────────────────────────────┤
│                   UITable                     │
└───────────────────────────────────────────────┘
```

---

## ⚠️ 注意事项

### 1. 确保表格支持行选择

```matlab
% 在 startupFcn 中设置
function startupFcn(app)
    app.UITable.SelectionType = 'row';  % 或 'cell'
end
```

### 2. ID 重排的影响

- **重排 ID**（默认）：适合需要连续编号的场景，删除后 ID 自动重新排列为 1, 2, 3, ...
- **保留原 ID**：适合导出后重新导入，保持 ID 一致性，但 ID 可能不连续

### 3. 删除后无法撤销

- 建议使用 `confirm = true` 防止误删
- 或实现撤销功能（保存删除前的状态）

### 4. 多行删除的顺序

函数会从选中的行中提取唯一行号并自动排序，确保正确删除。

---

## 🔗 相关功能

| 功能 | 函数 | 说明 |
|-----|------|------|
| 导入数据 | `import_branches_csv_to_uitable.m` | 从 CSV 导入到表格 |
| 导出数据 | `export_uitable_to_branches_csv.m` | 从表格导出到 CSV |
| 添加新行 | `add_new_row_to_uitable.m` | 在表格末尾添加行 |
| **删除选中行** | **`delete_selected_rows_from_uitable.m`** | **删除选中的行** |

---

## 📝 常见问题

### Q1：为什么点击删除按钮没反应？

**A**：检查以下几点：
1. 是否选中了行（点击行号或单元格）
2. 查看命令窗口是否有提示信息
3. 确保 `UITable.SelectionType` 已设置

### Q2：能否撤销删除操作？

**A**：当前版本不支持撤销。建议：
- 使用 `confirm = true` 防止误删
- 或在删除前保存数据：`backupData = app.UITable.Data;`

### Q3：删除后 ID 应该重排吗？

**A**：取决于使用场景：
- **重排**（默认）：适合需要连续编号的场景（如导出后作为临时数据）
- **不重排**：适合需要保持 ID 固定的场景（如对应实际分支编号），使用 `'reindexID', false`

### Q4：如何实现批量删除（不选中）？

**A**：可以通过代码直接设置选择：

```matlab
% 删除 ID = 3, 5, 7 的行
rowsToDelete = find(ismember(app.UITable.Data.ID, [3, 5, 7]));
app.UITable.Selection = [rowsToDelete, ones(length(rowsToDelete), 1)];
gps.ui.delete_selected_rows_from_uitable(app.UITable);
```

---

## 📈 版本历史

- **v1.0** (2025-12-18) - 初始版本
  - 单行和多行删除
  - 可选 ID 重排
  - 可选确认对话框
  - 完整的错误处理

---

## 👤 作者

MATLAB 通风工程专家助手

## 📄 许可

遵循项目主许可证
