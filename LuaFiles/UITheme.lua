-- =============================================
-- UITheme - AIMWARE 风格共享主题模块
-- 半透明红色配色，所有 UI 文件共用
-- =============================================

local M = StringGuide
if not M then return end

M.UITheme = {}
local T = M.UITheme

-- =============================================
-- 色彩常量
-- =============================================
T.C = {
    -- 文字
    title    = { 0.40, 0.70, 1.00, 1.0 },   -- 蓝色标题
    accent   = { 0.40, 0.70, 1.00, 1.0 },   -- 蓝色强调
    success  = { 0.35, 0.85, 0.40, 1.0 },   -- 绿色(运行)
    danger   = { 0.95, 0.25, 0.25, 1.0 },   -- 红色(停止)
    muted    = { 0.50, 0.50, 0.50, 1.0 },   -- 暗灰
    white    = { 1.00, 1.00, 1.00, 1.0 },   -- 白色正文
    hint     = { 0.60, 0.60, 0.60, 1.0 },   -- 提示文字
    section  = { 0.45, 0.70, 0.95, 1.0 },   -- 区域小标题
    gold     = { 1.00, 0.80, 0.20, 1.0 },   -- 金色(高亮)
    link     = { 0.55, 0.65, 0.95, 1.0 },   -- 链接/可交互

    -- 按钮预设 (组合: normal/hovered/active)
    btnRun   = { { 0.18, 0.58, 0.30, 0.90 }, { 0.25, 0.72, 0.40, 0.95 }, { 0.12, 0.48, 0.22, 1.00 } },
    btnStop  = { { 0.72, 0.18, 0.18, 0.90 }, { 0.85, 0.25, 0.25, 1.00 }, { 0.58, 0.12, 0.12, 1.00 } },
    btnSend  = { { 0.20, 0.45, 0.68, 0.85 }, { 0.28, 0.55, 0.78, 0.95 }, { 0.15, 0.38, 0.60, 1.00 } },
    btnPrimary = { { 0.26, 0.52, 0.85, 0.85 }, { 0.32, 0.60, 0.92, 0.95 }, { 0.20, 0.46, 0.78, 1.00 } },
}

-- =============================================
-- 窗口级主题 Push/Pop
-- =============================================
local THEME_COLOR_COUNT = 0

T.PushTheme = function()
    -- 使用默认主题，不推送任何颜色
end

T.PopTheme = function()
    -- 无需弹出
end

-- =============================================
-- 按钮颜色快捷 Push/Pop
-- =============================================
T.PushBtn = function(preset)
    GUI:PushStyleColor(GUI.Col_Button,        preset[1][1], preset[1][2], preset[1][3], preset[1][4])
    GUI:PushStyleColor(GUI.Col_ButtonHovered,  preset[2][1], preset[2][2], preset[2][3], preset[2][4])
    GUI:PushStyleColor(GUI.Col_ButtonActive,   preset[3][1], preset[3][2], preset[3][3], preset[3][4])
end

T.PopBtn = function()
    GUI:PopStyleColor(3)
end

-- =============================================
-- 区域标题 (红色强调文字 + 分隔线)
-- =============================================
T.SectionHeader = function(text)
    GUI:Spacing()
    GUI:TextColored(T.C.section[1], T.C.section[2], T.C.section[3], T.C.section[4], text)
    GUI:Separator()
    GUI:Spacing()
end

-- 小节标题 (不带分隔线)
T.SubHeader = function(text)
    GUI:TextColored(T.C.accent[1], T.C.accent[2], T.C.accent[3], T.C.accent[4], text)
end

-- 提示文字
T.HintText = function(text)
    GUI:TextColored(T.C.hint[1], T.C.hint[2], T.C.hint[3], T.C.hint[4], text)
end

-- 状态文字 (成功/危险)
T.SuccessText = function(text)
    GUI:TextColored(T.C.success[1], T.C.success[2], T.C.success[3], T.C.success[4], text)
end

T.DangerText = function(text)
    GUI:TextColored(T.C.danger[1], T.C.danger[2], T.C.danger[3], T.C.danger[4], text)
end

-- ResourceType 配色 (红色主题下的区分色)
T.TypeConfig = {
    [2] = { name = "Model",  color = { 0.70, 0.80, 0.95, 1.0 } },
    [4] = { name = "VFX",    color = { 0.95, 0.65, 0.35, 1.0 } },
    [6] = { name = "Script", color = { 0.75, 0.90, 0.75, 1.0 } },
    [7] = { name = "Sound",  color = { 0.95, 0.85, 0.50, 1.0 } },
}

d("[StringCore] UITheme.lua 加载完成")
