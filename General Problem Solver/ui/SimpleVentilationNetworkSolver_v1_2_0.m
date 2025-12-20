classdef SimpleVentilationNetworkSolver_v1_2_0 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure          matlab.ui.Figure
        TabGroup          matlab.ui.container.TabGroup
        Tab               matlab.ui.container.Tab
        GridLayout        matlab.ui.container.GridLayout
        GridLayout4       matlab.ui.container.GridLayout
        TextArea          matlab.ui.control.TextArea
        TextAreaLabel     matlab.ui.control.Label
        GridLayout3       matlab.ui.container.GridLayout
        GridLayout8       matlab.ui.container.GridLayout
        GridLayout10      matlab.ui.container.GridLayout
        Button_7          matlab.ui.control.Button
        Button_6          matlab.ui.control.Button
        GridLayout9       matlab.ui.container.GridLayout
        Slider            matlab.ui.control.Slider
        SliderLabel       matlab.ui.control.Label
        DropDown_2        matlab.ui.control.DropDown
        DropDown_2Label   matlab.ui.control.Label
        DropDown          matlab.ui.control.DropDown
        DropDownLabel     matlab.ui.control.Label
        EditField_5       matlab.ui.control.NumericEditField
        EditField_5Label  matlab.ui.control.Label
        EditField_4       matlab.ui.control.NumericEditField
        EditField_4Label  matlab.ui.control.Label
        EditField_3       matlab.ui.control.NumericEditField
        EditField_3Label  matlab.ui.control.Label
        EditField_2       matlab.ui.control.NumericEditField
        EditField_2Label  matlab.ui.control.Label
        EditField         matlab.ui.control.NumericEditField
        EditFieldLabel    matlab.ui.control.Label
        Panel             matlab.ui.container.Panel
        GridLayout5       matlab.ui.container.GridLayout
        GridLayout7       matlab.ui.container.GridLayout
        Button_5          matlab.ui.control.Button
        Button_4          matlab.ui.control.Button
        Button_3          matlab.ui.control.Button
        Button_2          matlab.ui.control.Button
        Button            matlab.ui.control.Button
        UITable           matlab.ui.control.Table
        Tab_2             matlab.ui.container.Tab
        GridLayout11      matlab.ui.container.GridLayout
        GridLayout12      matlab.ui.container.GridLayout
        Panel_2           matlab.ui.container.Panel
        GridLayout13      matlab.ui.container.GridLayout
        UITable2          matlab.ui.control.Table
        UIAxes            matlab.ui.control.UIAxes
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            axis(app.UIAxes, 'off')
        end

        % Button pushed function: Button
        function ButtonPushed(app, event)
           gps.ui.import_branches_csv_to_uitable(app.UITable);
        end

        % Button pushed function: Button_2
        function ButtonPushed2(app, event)
            gps.ui.export_uitable_to_branches_csv(app.UITable);
        end

        % Button pushed function: Button_3
        function ButtonPushed3(app, event)
            gps.ui.add_new_row_to_uitable(app.UITable);
        end

        % Button pushed function: Button_4
        function ButtonPushed4(app, event)
            % 删除后重新连续编号 ID
            gps.ui.delete_selected_rows_from_uitable(app.UITable, 'confirm', true);
        end

        % Button down function: UITable
        function UITableButtonDown(app, event)
            % 创建右键菜单
            cm = uicontextmenu(app.UIFigure);
            app.UITable.ContextMenu = cm;

            % 添加删除菜单项
            uimenu(cm, 'Text', '删除选中行', ...
                'MenuSelectedFcn', @(src, event) ...
            gps.ui.delete_selected_rows_from_uitable(app.UITable, 'confirm', true));

            % 添加不重排删除菜单项
            uimenu(cm, 'Text', '删除选中行（不重排）', ...
                'MenuSelectedFcn', @(src, event) ...
            gps.ui.delete_selected_rows_from_uitable(app.UITable, 'reindexID', false, 'confirm', true));
        end

        % Button pushed function: Button_5
        function ButtonPushed5(app, event)
            % 清空表格
            gps.ui.clear_uitable(app.UITable, 'confirm', true);
        end

        % Button pushed function: Button_6
        function ButtonPushed6(app, event)
            % 1. 禁用按钮
            app.Button_6.Enable = 'off';
            app.Button_6.Text = '求解中...';
            drawnow;

            % 2. 调用求解函数
            gps.ui.solve_network_from_ui(app);

            % 3. 恢复按钮
            app.Button_6.Enable = 'on';
            app.Button_6.Text = '开始解算';
        end

        % Button pushed function: Button_7
        function ButtonPushed7(app, event)
            % 直接读取 UITable 中的数据并绘图
            gps.ui.plot_network_graph(app.UITable, [],app);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 947 651];
            app.UIFigure.Name = 'MATLAB App';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [2 1 946 651];

            % Create Tab
            app.Tab = uitab(app.TabGroup);
            app.Tab.Title = '解算';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.Tab);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {'7x', '3x'};

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.GridLayout);
            app.GridLayout3.ColumnWidth = {'3x', '2x'};
            app.GridLayout3.RowHeight = {'1x'};
            app.GridLayout3.Layout.Row = 1;
            app.GridLayout3.Layout.Column = 1;

            % Create Panel
            app.Panel = uipanel(app.GridLayout3);
            app.Panel.TitlePosition = 'centertop';
            app.Panel.Title = '分支数据';
            app.Panel.Layout.Row = 1;
            app.Panel.Layout.Column = 1;

            % Create GridLayout5
            app.GridLayout5 = uigridlayout(app.Panel);
            app.GridLayout5.ColumnWidth = {'1x'};
            app.GridLayout5.RowHeight = {'5x', '1x'};

            % Create UITable
            app.UITable = uitable(app.GridLayout5);
            app.UITable.ColumnName = {'巷道ID'; '起点（节点ID）'; '终点（节点ID）'; '风阻'};
            app.UITable.RowName = {};
            app.UITable.SelectionType = 'row';
            app.UITable.ColumnEditable = true;
            app.UITable.ButtonDownFcn = createCallbackFcn(app, @UITableButtonDown, true);
            app.UITable.Layout.Row = 1;
            app.UITable.Layout.Column = 1;

            % Create GridLayout7
            app.GridLayout7 = uigridlayout(app.GridLayout5);
            app.GridLayout7.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
            app.GridLayout7.RowHeight = {'1x'};
            app.GridLayout7.Layout.Row = 2;
            app.GridLayout7.Layout.Column = 1;

            % Create Button
            app.Button = uibutton(app.GridLayout7, 'push');
            app.Button.ButtonPushedFcn = createCallbackFcn(app, @ButtonPushed, true);
            app.Button.Layout.Row = 1;
            app.Button.Layout.Column = 1;
            app.Button.Text = '导入';

            % Create Button_2
            app.Button_2 = uibutton(app.GridLayout7, 'push');
            app.Button_2.ButtonPushedFcn = createCallbackFcn(app, @ButtonPushed2, true);
            app.Button_2.Layout.Row = 1;
            app.Button_2.Layout.Column = 2;
            app.Button_2.Text = '导出';

            % Create Button_3
            app.Button_3 = uibutton(app.GridLayout7, 'push');
            app.Button_3.ButtonPushedFcn = createCallbackFcn(app, @ButtonPushed3, true);
            app.Button_3.Layout.Row = 1;
            app.Button_3.Layout.Column = 3;
            app.Button_3.Text = '新建';

            % Create Button_4
            app.Button_4 = uibutton(app.GridLayout7, 'push');
            app.Button_4.ButtonPushedFcn = createCallbackFcn(app, @ButtonPushed4, true);
            app.Button_4.Layout.Row = 1;
            app.Button_4.Layout.Column = 4;
            app.Button_4.Text = '删除';

            % Create Button_5
            app.Button_5 = uibutton(app.GridLayout7, 'push');
            app.Button_5.ButtonPushedFcn = createCallbackFcn(app, @ButtonPushed5, true);
            app.Button_5.Layout.Row = 1;
            app.Button_5.Layout.Column = 5;
            app.Button_5.Text = '清空';

            % Create GridLayout8
            app.GridLayout8 = uigridlayout(app.GridLayout3);
            app.GridLayout8.ColumnWidth = {'1x'};
            app.GridLayout8.RowHeight = {'6x', '1x'};
            app.GridLayout8.Layout.Row = 1;
            app.GridLayout8.Layout.Column = 2;

            % Create GridLayout9
            app.GridLayout9 = uigridlayout(app.GridLayout8);
            app.GridLayout9.ColumnWidth = {'1x', '5x'};
            app.GridLayout9.RowHeight = {'1x', '1x', '1x', '1x', '1x', '1x', '1x', '1.5x'};
            app.GridLayout9.Layout.Row = 1;
            app.GridLayout9.Layout.Column = 1;

            % Create EditFieldLabel
            app.EditFieldLabel = uilabel(app.GridLayout9);
            app.EditFieldLabel.HorizontalAlignment = 'right';
            app.EditFieldLabel.Layout.Row = 1;
            app.EditFieldLabel.Layout.Column = 1;
            app.EditFieldLabel.Text = '初始风量';

            % Create EditField
            app.EditField = uieditfield(app.GridLayout9, 'numeric');
            app.EditField.HorizontalAlignment = 'center';
            app.EditField.Layout.Row = 1;
            app.EditField.Layout.Column = 2;
            app.EditField.Value = 100;

            % Create EditField_2Label
            app.EditField_2Label = uilabel(app.GridLayout9);
            app.EditField_2Label.HorizontalAlignment = 'right';
            app.EditField_2Label.Layout.Row = 2;
            app.EditField_2Label.Layout.Column = 1;
            app.EditField_2Label.Text = '入风节点';

            % Create EditField_2
            app.EditField_2 = uieditfield(app.GridLayout9, 'numeric');
            app.EditField_2.AllowEmpty = 'on';
            app.EditField_2.HorizontalAlignment = 'center';
            app.EditField_2.Layout.Row = 2;
            app.EditField_2.Layout.Column = 2;
            app.EditField_2.Value = [];

            % Create EditField_3Label
            app.EditField_3Label = uilabel(app.GridLayout9);
            app.EditField_3Label.HorizontalAlignment = 'right';
            app.EditField_3Label.Layout.Row = 3;
            app.EditField_3Label.Layout.Column = 1;
            app.EditField_3Label.Text = '回风节点';

            % Create EditField_3
            app.EditField_3 = uieditfield(app.GridLayout9, 'numeric');
            app.EditField_3.AllowEmpty = 'on';
            app.EditField_3.HorizontalAlignment = 'center';
            app.EditField_3.Layout.Row = 3;
            app.EditField_3.Layout.Column = 2;
            app.EditField_3.Value = [];

            % Create EditField_4Label
            app.EditField_4Label = uilabel(app.GridLayout9);
            app.EditField_4Label.HorizontalAlignment = 'right';
            app.EditField_4Label.Layout.Row = 4;
            app.EditField_4Label.Layout.Column = 1;
            app.EditField_4Label.Text = '最大迭代';

            % Create EditField_4
            app.EditField_4 = uieditfield(app.GridLayout9, 'numeric');
            app.EditField_4.HorizontalAlignment = 'center';
            app.EditField_4.Tooltip = {'最大迭代次数'};
            app.EditField_4.Layout.Row = 4;
            app.EditField_4.Layout.Column = 2;
            app.EditField_4.Value = 1000;

            % Create EditField_5Label
            app.EditField_5Label = uilabel(app.GridLayout9);
            app.EditField_5Label.HorizontalAlignment = 'right';
            app.EditField_5Label.Layout.Row = 5;
            app.EditField_5Label.Layout.Column = 1;
            app.EditField_5Label.Text = '收敛容差';

            % Create EditField_5
            app.EditField_5 = uieditfield(app.GridLayout9, 'numeric');
            app.EditField_5.HorizontalAlignment = 'center';
            app.EditField_5.Tooltip = {'判断结果收敛的条件'};
            app.EditField_5.Layout.Row = 5;
            app.EditField_5.Layout.Column = 2;
            app.EditField_5.Value = 0.001;

            % Create DropDownLabel
            app.DropDownLabel = uilabel(app.GridLayout9);
            app.DropDownLabel.HorizontalAlignment = 'right';
            app.DropDownLabel.Layout.Row = 6;
            app.DropDownLabel.Layout.Column = 1;
            app.DropDownLabel.Text = '求解方法';

            % Create DropDown
            app.DropDown = uidropdown(app.GridLayout9);
            app.DropDown.Items = {'HardyCross', 'NewtonRaphson'};
            app.DropDown.Tooltip = {'使用的求解方法，目前只有HaedyCross迭代法可用。'; 'NewtonRaphson法作者还没看懂原理QwQ'};
            app.DropDown.Layout.Row = 6;
            app.DropDown.Layout.Column = 2;
            app.DropDown.Value = 'HardyCross';

            % Create DropDown_2Label
            app.DropDown_2Label = uilabel(app.GridLayout9);
            app.DropDown_2Label.HorizontalAlignment = 'right';
            app.DropDown_2Label.Layout.Row = 7;
            app.DropDown_2Label.Layout.Column = 1;
            app.DropDown_2Label.Text = '图表输出';

            % Create DropDown_2
            app.DropDown_2 = uidropdown(app.GridLayout9);
            app.DropDown_2.Items = {'true', 'false'};
            app.DropDown_2.Tooltip = {'是否输出可视化图表'};
            app.DropDown_2.Layout.Row = 7;
            app.DropDown_2.Layout.Column = 2;
            app.DropDown_2.Value = 'true';

            % Create SliderLabel
            app.SliderLabel = uilabel(app.GridLayout9);
            app.SliderLabel.HorizontalAlignment = 'right';
            app.SliderLabel.Layout.Row = 8;
            app.SliderLabel.Layout.Column = 1;
            app.SliderLabel.Text = '松弛因子';

            % Create Slider
            app.Slider = uislider(app.GridLayout9);
            app.Slider.Limits = [0 2];
            app.Slider.Tooltip = {'范围(0,2]，用于改善收敛性，值越小收敛越稳定但速度越慢'};
            app.Slider.Layout.Row = 8;
            app.Slider.Layout.Column = 2;
            app.Slider.Value = 1;

            % Create GridLayout10
            app.GridLayout10 = uigridlayout(app.GridLayout8);
            app.GridLayout10.RowHeight = {'1x'};
            app.GridLayout10.Layout.Row = 2;
            app.GridLayout10.Layout.Column = 1;

            % Create Button_6
            app.Button_6 = uibutton(app.GridLayout10, 'push');
            app.Button_6.ButtonPushedFcn = createCallbackFcn(app, @ButtonPushed6, true);
            app.Button_6.Layout.Row = 1;
            app.Button_6.Layout.Column = 2;
            app.Button_6.Text = '开始解算';

            % Create Button_7
            app.Button_7 = uibutton(app.GridLayout10, 'push');
            app.Button_7.ButtonPushedFcn = createCallbackFcn(app, @ButtonPushed7, true);
            app.Button_7.Layout.Row = 1;
            app.Button_7.Layout.Column = 1;
            app.Button_7.Text = '通风网络预览';

            % Create GridLayout4
            app.GridLayout4 = uigridlayout(app.GridLayout);
            app.GridLayout4.ColumnWidth = {'1x', '17x'};
            app.GridLayout4.RowHeight = {'1x'};
            app.GridLayout4.Layout.Row = 2;
            app.GridLayout4.Layout.Column = 1;

            % Create TextAreaLabel
            app.TextAreaLabel = uilabel(app.GridLayout4);
            app.TextAreaLabel.HorizontalAlignment = 'right';
            app.TextAreaLabel.Layout.Row = 1;
            app.TextAreaLabel.Layout.Column = 1;
            app.TextAreaLabel.Text = '信息栏';

            % Create TextArea
            app.TextArea = uitextarea(app.GridLayout4);
            app.TextArea.Editable = 'off';
            app.TextArea.Layout.Row = 1;
            app.TextArea.Layout.Column = 2;

            % Create Tab_2
            app.Tab_2 = uitab(app.TabGroup);
            app.Tab_2.Title = '分析';

            % Create GridLayout11
            app.GridLayout11 = uigridlayout(app.Tab_2);
            app.GridLayout11.ColumnWidth = {'1x'};
            app.GridLayout11.RowHeight = {'1x'};

            % Create GridLayout12
            app.GridLayout12 = uigridlayout(app.GridLayout11);
            app.GridLayout12.ColumnWidth = {'16x', '14x'};
            app.GridLayout12.RowHeight = {'1x'};
            app.GridLayout12.Layout.Row = 1;
            app.GridLayout12.Layout.Column = 1;

            % Create UIAxes
            app.UIAxes = uiaxes(app.GridLayout12);
            title(app.UIAxes, '通风网络图')
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.TitleFontWeight = 'bold';
            app.UIAxes.Layout.Row = 1;
            app.UIAxes.Layout.Column = 2;

            % Create Panel_2
            app.Panel_2 = uipanel(app.GridLayout12);
            app.Panel_2.TitlePosition = 'centertop';
            app.Panel_2.Title = '解算结果';
            app.Panel_2.Layout.Row = 1;
            app.Panel_2.Layout.Column = 1;

            % Create GridLayout13
            app.GridLayout13 = uigridlayout(app.Panel_2);
            app.GridLayout13.ColumnWidth = {'1x'};
            app.GridLayout13.RowHeight = {'1x'};

            % Create UITable2
            app.UITable2 = uitable(app.GridLayout13);
            app.UITable2.ColumnName = {'巷道ID'; '起点'; '终点'; '风阻'; '风量'; '风压降'};
            app.UITable2.RowName = {};
            app.UITable2.Layout.Row = 1;
            app.UITable2.Layout.Column = 1;

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = SimpleVentilationNetworkSolver_v1_2_0

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end