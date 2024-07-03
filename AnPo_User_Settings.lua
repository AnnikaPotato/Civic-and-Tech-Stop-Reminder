-- The default setting of the reminder. Change true to false if you DON'T want the button to be active by default.
-- 提示器初始状态。当值为true，开时新游戏时始终打开提示。值为false，开始新游戏时始终关闭提示。
AnPo_user_techActiveByDefault = true;
AnPo_user_civicActiveByDefault = true;

-- Special case for Babylon. false means the tech reminder will be disabled for Babylon by default.
-- 特殊情况：巴比伦科技提醒。当值为true，开时新游戏时始终打开提示。值为false，开始新游戏时始终关闭提示。
AnPo_user_defaultBabylonTechReminder = false;

-- Below you can define where in the top panel you want the buttons to be displayed.
-- Replace the content in the double quote to the following options (Note: No spaces inside the quote!):
-- InfoStack: buttons will be displayed on the left, after the trade route button.
-- RightContents: buttons will be displayed on the right.
-- 开关按钮在顶部面板的位置。 可将双引号里的值更改为下列选项（注意：引号里不能有空格）：
-- InfoStack：按钮向左与使者等按钮对齐。
-- RightContents：按钮向右与时间等元素对齐。
AnPo_ButtonPosition = "RightContents";

-- Control the order of apprearance of the buttons. 
-- Enter an integer value.
-- The smaller the value is, the closer the buttons are to the boundary. 
-- 调整按钮的具体位置。值必须为整数。值越小越靠近对应边界。
AnPo_ChildIndex = 3;