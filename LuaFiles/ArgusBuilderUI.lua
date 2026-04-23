-- =============================================
-- ArgusBuilderUI - Argus 绘图代码生成器
-- 可视化选择形状、颜色、参数，一键预览/生成代码/复制/测试
-- =============================================

local M = StringGuide
if not M then return end

local T = M.UITheme
local C = T.C
local TABS = M.ArgusBuilderTabs or {
    BUILDER = 1,
    CODE = 2,
    MAP_EFFECT = 3,
    ME_TRIGGER = 4,
}

-- =============================================
-- 形状定义
-- =============================================
local ShapeDefinitions = {
    { id = "Circle",       name = "圆形" },
    { id = "Cone",         name = "扇形" },
    { id = "Rect",         name = "矩形" },
    { id = "CenteredRect", name = "居中矩形" },
    { id = "Donut",        name = "月环(甜甜圈)" },
    { id = "DonutCone",    name = "月环扇形" },
    { id = "Cross",        name = "十字" },
    { id = "Arrow",        name = "箭头" },
    { id = "Chevron",      name = "V形" },
    { id = "Line",         name = "线条" },
}

-- 工具：从定义表提取名称列表
local function ExtractNames(defs)
    local names = {}
    for _, d in ipairs(defs) do names[#names + 1] = d.name end
    return names
end

-- 形状名称列表（用于下拉菜单）
local ShapeDisplayNames = ExtractNames(ShapeDefinitions)

-- =============================================
-- 预设颜色
-- =============================================
local PresetColors = {
    { name = "红色",   r = 1.0, g = 0.0, b = 0.0, a = 0.5 },
    { name = "绿色",   r = 0.0, g = 1.0, b = 0.0, a = 0.5 },
    { name = "蓝色",   r = 0.0, g = 0.5, b = 1.0, a = 0.5 },
    { name = "黄色",   r = 1.0, g = 1.0, b = 0.0, a = 0.5 },
    { name = "紫色",   r = 0.8, g = 0.0, b = 1.0, a = 0.5 },
    { name = "白色",   r = 1.0, g = 1.0, b = 1.0, a = 0.5 },
    { name = "橙色",   r = 1.0, g = 0.6, b = 0.0, a = 0.5 },
    { name = "青色",   r = 0.0, g = 1.0, b = 1.0, a = 0.5 },
    { name = "粉色",   r = 1.0, g = 0.4, b = 0.7, a = 0.5 },
    { name = "深红",   r = 0.8, g = 0.1, b = 0.1, a = 0.7 },
}

-- =============================================
-- 机制类型定义 (参考 Splatoon MechanicType)
-- =============================================
local MechanicTypes = {
    { id = "none",     name = "未指定",   fill = {0.8, 0.0, 1.0, 0.5},  outline = {1.0, 1.0, 1.0, 1.0} },
    { id = "danger",   name = "危险",     fill = {1.0, 0.0, 0.0, 0.45}, outline = {1.0, 0.3, 0.3, 1.0} },
    { id = "safe",     name = "安全",     fill = {0.0, 0.82, 0.08, 0.45}, outline = {0.3, 1.0, 0.3, 1.0} },
    { id = "soak",     name = "分摊",     fill = {1.0, 0.56, 0.0, 0.45}, outline = {1.0, 0.8, 0.3, 1.0} },
    { id = "gaze",     name = "凝视",     fill = {0.63, 0.0, 0.84, 0.45}, outline = {0.8, 0.4, 1.0, 1.0} },
    { id = "knockback",name = "击退",     fill = {0.0, 0.97, 1.0, 0.45}, outline = {0.5, 1.0, 1.0, 1.0} },
    { id = "info",     name = "信息",     fill = {0.0, 0.44, 1.0, 0.45}, outline = {0.4, 0.7, 1.0, 1.0} },
}
local MechanicTypeNames = ExtractNames(MechanicTypes)

-- 前置声明 State（供后面的 local function 引用）
local State

local function ApplyMechanicStyle(idx)
    local mt = MechanicTypes[idx]
    if not mt then return end
    State.mechanicType = idx
    if idx > 1 then
        State.useMoogleDrawer = false
        State.useGradient = false
        State.fillR, State.fillG, State.fillB, State.fillA = mt.fill[1], mt.fill[2], mt.fill[3], mt.fill[4]
        State.outlineR, State.outlineG, State.outlineB, State.outlineA = mt.outline[1], mt.outline[2], mt.outline[3], mt.outline[4]
    end
end

-- =============================================
-- 快速样式模板 (形状 + 尺寸 + 机制类型 一键填充)
-- =============================================
local QuickTemplates = {
    { name = "圆形AOE (小)",   shape = "Circle", mechanic = 2, params = { radius = 5 } },
    { name = "圆形AOE (中)",   shape = "Circle", mechanic = 2, params = { radius = 10 } },
    { name = "圆形AOE (大)",   shape = "Circle", mechanic = 2, params = { radius = 15 } },
    { name = "圆形AOE (超大)", shape = "Circle", mechanic = 2, params = { radius = 25 } },
    { name = "钢铁 (月环)",    shape = "Donut",  mechanic = 3, params = { radiusInner = 5, radiusOuter = 20 } },
    { name = "扇形 60°",       shape = "Cone",   mechanic = 2, params = { radius = 15, angle = 60 } },
    { name = "扇形 90°",       shape = "Cone",   mechanic = 2, params = { radius = 15, angle = 90 } },
    { name = "扇形 180°",      shape = "Cone",   mechanic = 2, params = { radius = 15, angle = 180 } },
    { name = "扇形 270°",      shape = "Cone",   mechanic = 2, params = { radius = 15, angle = 270 } },
    { name = "直线AOE",        shape = "Rect",   mechanic = 2, params = { length = 40, width = 6 } },
    { name = "十字AOE",        shape = "Cross",  mechanic = 2, params = { length = 40, width = 6 } },
    { name = "安全区 (圆)",    shape = "Circle", mechanic = 3, params = { radius = 5 } },
    { name = "分摊圈",         shape = "Circle", mechanic = 4, params = { radius = 6 } },
    { name = "凝视扇形",       shape = "Cone",   mechanic = 5, params = { radius = 50, angle = 90 } },
    { name = "击退箭头",       shape = "Arrow",  mechanic = 6, params = { baseLength = 12, baseWidth = 3, tipLength = 4, tipWidth = 5 } },
}

--- 应用快速模板到 State
local function ApplyQuickTemplate(tmpl)
    -- 找到形状索引
    for i, s in ipairs(ShapeDefinitions) do
        if s.id == tmpl.shape then State.shapeIndex = i; break end
    end
    -- 应用参数
    for k, v in pairs(tmpl.params) do
        State[k] = v
    end
    -- 应用机制类型
    State.mechanicType = tmpl.mechanic
    -- 应用机制配色
    ApplyMechanicStyle(tmpl.mechanic)
    State.generatedCode = ""
end

--- 应用机制类型配色 (仅改颜色，不改形状)
local function ApplyMechanicColor(idx)
    ApplyMechanicStyle(idx)
end

-- =============================================
-- 绘图模式定义
-- =============================================
local ApiLevelNames = { "ShapeDrawer (推荐)", "Argus2 底层", "StaticDrawer (OnFrame专用)" }
local TimingModeNames = { "Timed (持续时间)", "OnFrame (每帧瞬时)" }
local AttachModeNames = { "坐标固定", "OnEnt (附着实体)" }
local EntityResolveModeNames = { "自身", "ContentID", "名称", "自定义过滤串" }
local TargetResolveModeNames = { "无目标", "当前目标", "ContentID", "名称", "自定义过滤串" }
local HeadingSourceNames = {
    "玩家朝向",
    "实体/资源朝向",
    "目标朝向",
    "固定角度",
    "指向坐标点",
    "朝向玩家位置",
}

-- =============================================
-- 形状参数配置（消除 if/elseif 分派）
-- =============================================
-- 参数序列 token 说明:
--   "pos" -> "x, y, z"  |  "pos2" -> "x2, y2, z2"
--   "angle" -> angle 变量  |  "heading" -> heading 变量
--   "target" -> tgtStr  |  "delay" -> delay 值
--   其他 token 直接对应 State/step 字段名
local ShapeParams = {
    Circle       = { coord = {"pos", "radius", "delay"},
                     ent   = {"radius", "delay"},
                     frame = {"pos", "radius"} },
    Cone         = { coord = {"pos", "radius", "angle", "heading", "delay"},
                     ent   = {"radius", "angle", "target", "delay"},
                     frame = {"pos", "radius", "angle", "heading"},
                     entNilPad = 2 },
    Rect         = { coord = {"pos", "length", "width", "heading", "delay"},
                     ent   = {"length", "width", "target", "delay"},
                     frame = {"pos", "length", "width", "heading"},
                     entNilPad = 3 },
    CenteredRect = { coord = {"pos", "length", "width", "heading", "delay"},
                     ent   = {"length", "width", "target", "delay"},
                     frame = {"pos", "length", "width", "heading"},
                     entNilPad = 3 },
    Donut        = { coord = {"pos", "radiusInner", "radiusOuter", "delay"},
                     ent   = {"radiusInner", "radiusOuter", "delay"},
                     frame = {"pos", "radiusInner", "radiusOuter"} },
    DonutCone    = { coord = {"pos", "radiusInner", "radiusOuter", "angle", "heading", "delay"},
                     ent   = {"radiusInner", "radiusOuter", "angle", "target", "delay"},
                     frame = {"pos", "radiusInner", "radiusOuter", "angle", "heading"},
                     entNilPad = 2 },
    Cross        = { coord = {"pos", "length", "width", "heading", "delay"},
                     ent   = {"length", "width", "target", "delay"},
                     frame = {"pos", "length", "width", "heading"},
                     entNilPad = 2 },
    Arrow        = { coord = {"pos", "heading", "baseLength", "baseWidth", "tipLength", "tipWidth", "delay"},
                     ent   = {"baseLength", "baseWidth", "tipLength", "tipWidth", "target", "delay"},
                     frame = {"pos", "heading", "baseLength", "baseWidth", "tipLength", "tipWidth"},
                     entNilPad = 1 },
    Chevron      = { coord = {"pos", "length", "thickness", "heading", "delay"},
                     ent   = {"length", "thickness", "target", "delay"},
                     frame = {"pos", "length", "thickness", "heading"},
                     entNilPad = 1 },
    Line         = { coord = {"pos", "pos2", "thickness"},
                     frame = {"pos", "pos2", "thickness"} },
}

--- 检查形状是否需要朝向
local function ShapeNeedsHeading(sid)
    local p = ShapeParams[sid]
    if not p or not p.coord then return false end
    for _, t in ipairs(p.coord) do if t == "heading" then return true end end
    return false
end

--- 检查形状是否需要角度变量
local function ShapeNeedsAngle(sid)
    local p = ShapeParams[sid]
    if not p or not p.coord then return false end
    for _, t in ipairs(p.coord) do if t == "angle" then return true end end
    return false
end

local function ShapeUsesHitboxCompensation(sid)
    return sid == "Circle" or sid == "Cone" or sid == "Donut" or sid == "DonutCone"
end

--- 将 token 序列解析为代码生成字符串
local function BuildArgs(tokens, S, f, tgtStr, opts)
    opts = opts or {}
    local posVar = opts.posVar or "x, y, z"
    local pos2Var = opts.pos2Var or "x2, y2, z2"
    local useHitbox = opts.useHitbox
    local parts = {}
    for _, token in ipairs(tokens) do
        if     token == "pos"     then table.insert(parts, posVar)
        elseif token == "pos2"    then table.insert(parts, pos2Var)
        elseif token == "angle"   then table.insert(parts, "angle")
        elseif token == "heading" then table.insert(parts, "heading")
        elseif token == "target"  then table.insert(parts, tgtStr or "0")
        elseif token == "delay"   then table.insert(parts, f(S.delay or 0))
        elseif useHitbox and (token == "radius" or token == "radiusInner" or token == "radiusOuter") then
            table.insert(parts, "(" .. f(S[token]) .. " + _hitboxExtra)")
        else                           table.insert(parts, f(S[token]))
        end
    end
    return table.concat(parts, ", ")
end

--- 构建参数字符串（支持自定义位置/朝向/延迟变量名，用于组合机制）
local function BuildArgsCustom(tokens, step, f, posVar, headingVar, delayVal, pos2Var)
    pos2Var = pos2Var or string.format("%s, %s, %s",
        f(step.pos2X or 0), f(step.pos2Y or 0), f(step.pos2Z or 0))
    local parts = {}
    for _, token in ipairs(tokens) do
        if     token == "pos"     then table.insert(parts, posVar)
        elseif token == "pos2"    then table.insert(parts, pos2Var)
        elseif token == "angle"   then table.insert(parts, "math.rad(" .. f(step.angle) .. ")")
        elseif token == "heading" then table.insert(parts, headingVar)
        elseif token == "target"  then table.insert(parts, "0")
        elseif token == "delay"   then table.insert(parts, f(delayVal))
        else                           table.insert(parts, f(step[token]))
        end
    end
    return table.concat(parts, ", ")
end

-- =============================================
-- 预览绘图分派表
-- =============================================

--- Timed 坐标模式预览 (d=drawer, t=timeout, h=headingRad, a=angleRad, S=State/step, del=delay)
local PreviewTimedCoord = {
    Circle       = function(d, t, x, y, z, h, a, S, del) return d:addTimedCircle(t, x, y, z, S.radius, del) end,
    Cone         = function(d, t, x, y, z, h, a, S, del) return d:addTimedCone(t, x, y, z, S.radius, a, h, del) end,
    Rect         = function(d, t, x, y, z, h, a, S, del) return d:addTimedRect(t, x, y, z, S.length, S.width, h, del) end,
    CenteredRect = function(d, t, x, y, z, h, a, S, del) return d:addTimedCenteredRect(t, x, y, z, S.length, S.width, h, del) end,
    Donut        = function(d, t, x, y, z, h, a, S, del) return d:addTimedDonut(t, x, y, z, S.radiusInner, S.radiusOuter, del) end,
    DonutCone    = function(d, t, x, y, z, h, a, S, del) return d:addTimedDonutCone(t, x, y, z, S.radiusInner, S.radiusOuter, a, h, del) end,
    Cross        = function(d, t, x, y, z, h, a, S, del) return d:addTimedCross(t, x, y, z, S.length, S.width, h, del) end,
    Arrow        = function(d, t, x, y, z, h, a, S, del) return d:addTimedArrow(t, x, y, z, h, S.baseLength, S.baseWidth, S.tipLength, S.tipWidth, del) end,
    Chevron      = function(d, t, x, y, z, h, a, S, del) return d:addTimedChevron(t, x, y, z, S.length, S.thickness, h, del) end,
    Line         = function(d, t, x, y, z, h, a, S, del) return d:addTimedLine(t, x, y, z, S.pos2X, S.pos2Y, S.pos2Z, S.thickness) end,
}

--- Timed OnEnt 模式预览 (d=drawer, t=timeout, e=entID, tgt=tgtID, S=State, del=delay, ho/hoAbs=headingOffset)
local PreviewTimedEnt = {
    Circle       = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedCircleOnEnt(t, e, S.radius, del) end,
    Cone         = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedConeOnEnt(t, e, S.radius, a, tgt, del, S.oldDraw or nil, S.doNotDetect or nil, ho, hoAbs) end,
    Rect         = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedRectOnEnt(t, e, S.length, S.width, tgt, del, nil, S.oldDraw or nil, S.doNotDetect or nil, ho, hoAbs) end,
    CenteredRect = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedCenteredRectOnEnt(t, e, S.length, S.width, tgt, del, nil, S.oldDraw or nil, S.doNotDetect or nil, ho, hoAbs) end,
    Donut        = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedDonutOnEnt(t, e, S.radiusInner, S.radiusOuter, del) end,
    DonutCone    = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedDonutConeOnEnt(t, e, S.radiusInner, S.radiusOuter, a, tgt, del, S.oldDraw or nil, S.doNotDetect or nil, ho, hoAbs) end,
    Cross        = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedCrossOnEnt(t, e, S.length, S.width, tgt, del, S.oldDraw or nil, S.doNotDetect or nil, ho, hoAbs) end,
    Arrow        = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedArrowOnEnt(t, e, S.baseLength, S.baseWidth, S.tipLength, S.tipWidth, tgt, del, S.oldDraw or nil, ho, hoAbs) end,
    Chevron      = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedChevronOnEnt(t, e, S.length, S.thickness, tgt, del, S.oldDraw or nil, ho, hoAbs) end,
}

-- =============================================
-- 通用工具函数
-- =============================================

--- 创建预览用 ShapeDrawer
local function CreatePreviewDrawer()
    if State.useMoogleDrawer and TensorCore and TensorCore.getMoogleDrawer then
        return TensorCore.getMoogleDrawer()
    end
    local fR, fG, fB, fA = State.fillR or 0.8, State.fillG or 0, State.fillB or 1, State.fillA or 0.5
    local oR, oG, oB, oA = State.outlineR or 1, State.outlineG or 1, State.outlineB or 1, State.outlineA or 1
    local fillU32 = GUI:ColorConvertFloat4ToU32(fR, fG, fB, fA)
    local outlineU32 = GUI:ColorConvertFloat4ToU32(oR, oG, oB, oA)
    local startU32, midU32
    if State.useGradient then
        startU32 = GUI:ColorConvertFloat4ToU32(State.startR or 1, State.startG or 0, State.startB or 0, State.startA or 0.5)
        midU32 = GUI:ColorConvertFloat4ToU32(State.midR or 0.5, State.midG or 0, State.midB or 1, State.midA or 0.5)
        fillU32 = GUI:ColorConvertFloat4ToU32(State.endR or 0.8, State.endG or 0, State.endB or 1, State.endA or 0.5)
    else
        startU32 = fillU32
    end
    return Argus2.ShapeDrawer:new(startU32, midU32, fillU32, outlineU32, State.outlineThickness or 1.5)
end

--- 清除所有预览绘图
local function ClearPreviewShapes()
    for _, uuid in ipairs(State.previewUUIDs) do
        if Argus and Argus.deleteTimedShape then
            Argus.deleteTimedShape(uuid)
        end
    end
    State.previewUUIDs = {}
end

--- 绘制颜色选择区域（选择器 + 预设按钮）- 前置声明，实际实现在 DrawColorPicker/DrawPresetButtons 之后
local DrawColorSection

-- =============================================
-- 通用 UI 辅助函数
-- =============================================

--- 纯色色块按钮样式（三态同色，用于颜色预览）
local function PushSolidColor(r, g, b, a)
    GUI:PushStyleColor(GUI.Col_Button, r, g, b, a)
    GUI:PushStyleColor(GUI.Col_ButtonHovered, r, g, b, a)
    GUI:PushStyleColor(GUI.Col_ButtonActive, r, g, b, a)
end
local function PopSolidColor() GUI:PopStyleColor(3) end

--- 悬浮提示（在最近一个控件上触发）
local function ItemTooltip(text)
    if GUI:IsItemHovered() then GUI:SetTooltip(text) end
end

--- 代码编辑文本框（统一样式，返回 newCode, changed）
local function DrawCodeTextbox(id, code, maxHeight)
    maxHeight = maxHeight or 350
    GUI:PushStyleColor(GUI.Col_FrameBg, 0.10, 0.08, 0.10, 0.95)
    GUI:PushItemWidth(-1)
    local lc = 1
    for _ in string.gmatch(code, "\n") do lc = lc + 1 end
    local th = math.min(math.max(lc * 16 + 10, 80), maxHeight)
    local newCode, changed = GUI:InputTextMultiline(id, code, -1, th, GUI.InputTextFlags_AllowTabInput)
    GUI:PopItemWidth()
    GUI:PopStyleColor(1)
    if changed then return newCode, true end
    return code, false
end

--- 绿色「运行」按钮
local function DrawRunBtn(label, w, h)
    GUI:PushStyleColor(GUI.Col_Button, 0.15, 0.65, 0.15, 0.85)
    GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.20, 0.75, 0.20, 0.95)
    GUI:PushStyleColor(GUI.Col_ButtonActive, 0.10, 0.55, 0.10, 1.0)
    local clicked = GUI:Button(label, w or 0, h or 28)
    GUI:PopStyleColor(3)
    return clicked
end

-- =============================================
-- UI 内部状态
-- =============================================
State = {
    -- 形状
    shapeIndex = 1,

    -- 通用参数
    timeout = 5000,
    posX = 0, posY = 0, posZ = 0,
    usePlayerPos = true,
    followPlayerPos = false,    -- 生成代码用 Player.pos.x/y/z
    headingSource = 1,      -- 1=玩家朝向, 2=实体/资源朝向, 3=目标朝向, 4=固定角度, 5=指向坐标点, 6=朝向玩家位置
    quickDirOffset = 0,     -- 快捷方向偏移量（度），前=0 后=180 左=-90 右=+90
    headingTargetX = 0,
    headingTargetY = 0,
    headingTargetZ = 0,

    -- 形状参数
    radius = 5,
    radiusInner = 3,
    radiusOuter = 8,
    length = 10,
    width = 4,
    angle = 90,        -- 度数，内部转弧度
    heading = 0,       -- 度数
    thickness = 2,
    baseLength = 8,
    baseWidth = 3,
    tipLength = 3,
    tipWidth = 1.5,
    -- Line 终点
    pos2X = 10, pos2Y = 0, pos2Z = 10,

    -- 颜色
    useMoogleDrawer = true,  -- 使用 TensorCore.getMoogleDrawer() 默认配色
    fillR = 0.8, fillG = 0.0, fillB = 1.0, fillA = 0.5,
    outlineR = 1.0, outlineG = 1.0, outlineB = 1.0, outlineA = 1.0,
    outlineThickness = 1.5,

    -- 绘图模式（索引从1开始）
    apiLevel = 1,      -- 1=ShapeDrawer, 2=Argus2
    timingMode = 1,    -- 1=Timed, 2=OnFrame
    attachMode = 1,    -- 1=坐标, 2=OnEnt

    -- OnEnt 参数
    entityResolveMode = 1,     -- 1=自身, 2=ContentID, 3=名称, 4=自定义过滤串
    entityID = 0,
    entityName = "",
    entityFilter = "",
    entityRequireVisible = false,
    entityRequireTargetable = false,
    targetResolveMode = 1,     -- 1=无目标, 2=当前目标, 3=ContentID, 4=名称, 5=自定义过滤串
    targetID = 0,
    targetName = "",
    targetFilter = "",
    targetRequireVisible = false,
    targetRequireTargetable = false,
    useCurrentTarget = false,
    useSelfAsEntity = true,
    renderAllEntities = true,   -- 渲染全部相同 ContentID 实体（默认启用）

    -- 高级参数
    delay = 0,
    oldDraw = false,
    doNotDetect = false,
    gradientIntensity = 3,
    gradientMinOpacity = 0.05,
    headingOffset = 0,
    offsetIsAbsolute = false,


    -- ShapeDrawer 颜色模式
    useGradient = false,
    startR = 1.0, startG = 0.0, startB = 0.0, startA = 0.5,
    midR = 0.5, midG = 0.0, midB = 1.0, midA = 0.5,
    endR = 0.8, endG = 0.0, endB = 1.0, endA = 0.5,

    -- 生成的代码
    generatedCode = "",

    -- 预览 UUID 列表（用于清理）
    previewUUIDs = {},

    -- 日志
    lastLog = "",
    lastRunError = "",

    -- 组合机制
    comboMode = 1,          -- 1=循环前进, 2=顺序执行, 3=同时执行
    comboSteps = {},        -- 步骤列表（顺序/同时模式）
    loopCount = 5,          -- 循环次数
    loopStepDist = 3,       -- 步进距离(米)
    loopInterval = 500,     -- 间隔延迟(毫秒)
    loopShapeIndex = 1,     -- 循环使用的形状索引
    comboGeneratedCode = "",

    -- MapEffect 触发器
    meEntries = {},         -- 触发条件列表
    meA1 = 0,
    meA3 = 0,
    meCheckA3 = true,       -- 是否检查 a3 (flags)
    meLabel = "",           -- 机制备注
    meCodeMode = 1,         -- 1=TensorReactions, 2=Argus.registerOnMapEffect
    mePosMode = 1,          -- 1=固定坐标, 2=特效位置, 3=玩家位置
    meResourcePath = "",
    meResourceType = 0,
    meResourceDirX = 0,
    meResourceDirY = 0,
    meResourceDirZ = 0,
    meGeneratedCode = "",

    -- 当前标签页
    activeTab = TABS.BUILDER,

    -- Phase 1: 机制类型
    mechanicType = 1,       -- 1=未指定, 2=危险, 3=安全, 4=分摊, 5=凝视, 6=击退, 7=信息

    -- Phase 3: 条件代码生成
    condEnabled = false,
    condBuffEnabled = false,
    condBuffIDs = "",           -- 逗号分隔的 Buff ID
    condBuffLogic = 1,          -- 1=OR, 2=AND
    condCastEnabled = false,
    condCastIDs = "",           -- 逗号分隔的 Cast ID
    condDistEnabled = false,
    condDistMin = 0,
    condDistMax = 30,
    condZoneEnabled = false,
    condZoneID = 0,
    condJobEnabled = false,
    condJobID = 0,

    -- Phase 5: 导入导出
    importExportText = "",

    -- Phase 5: 样式剪贴板
    styleClipboard = nil,

    -- Phase 2: Overlay Text
    overlayTextEnabled = false,
    overlayText = "",
    overlayVOffset = 2.0,
    overlayFontScale = 1.0,

    -- Phase 2: Tether
    tetherEnabled = false,
    tetherMode = 1,             -- 1=玩家到目标, 2=实体到实体
    tetherExtraLength = 0,

    -- Phase 6: Hitbox
    includeTargetHitbox = false,
    includeOwnHitbox = false,

    -- Phase 4: 坐标变换
    transformCenterX = 0,
    transformCenterZ = 0,
    transformAngle = 90,
}

-- =============================================
-- 工具函数
-- =============================================
local function CopyToClipboard(text)
    if GUI and GUI.SetClipboardText then
        GUI:SetClipboardText(tostring(text))
        State.lastLog = "代码已复制到剪贴板"
        d("[ArgusBuilder] 代码已复制到剪贴板")
    end
end

local function GetCurrentShape()
    return ShapeDefinitions[State.shapeIndex]
end

local function SyncPlayerPos()
    if Player and Player.pos then
        if State.usePlayerPos then
            State.posX = Player.pos.x
            State.posY = Player.pos.y
            State.posZ = Player.pos.z
        end
        if State.headingSource == 1 and Player.pos.h then
            State.heading = math.deg(Player.pos.h) + State.quickDirOffset
        end
    end
end

local function CopyCoordHeadingState(dst, src)
    dst.heading = src.heading
    dst.headingSource = src.headingSource
    dst.quickDirOffset = src.quickDirOffset
    dst.headingTargetX = src.headingTargetX
    dst.headingTargetY = src.headingTargetY
    dst.headingTargetZ = src.headingTargetZ
    return dst
end

local function NormalizeTargetSelectorState(schemaVersion)
    if schemaVersion and schemaVersion >= 3 then
        State.entityResolveMode = State.entityResolveMode or 1
        State.targetResolveMode = State.targetResolveMode or 1
        return
    end

    State.entityResolveMode = State.useSelfAsEntity and 1 or 2
    if State.useCurrentTarget then
        State.targetResolveMode = 2
    elseif (State.targetID or 0) ~= 0 then
        State.targetResolveMode = 3
    else
        State.targetResolveMode = 1
    end
end

local function SyncLegacyTargetSelectorFlags()
    State.useSelfAsEntity = (State.entityResolveMode == 1)
    State.useCurrentTarget = (State.targetResolveMode == 2)
end

local function GetSelectorSpec(S, kind)
    if kind == "entity" then
        local mode = S.entityResolveMode or (S.useSelfAsEntity and 1 or 2)
        local selector = ({ "self", "contentid", "name", "filter" })[mode] or "self"
        return {
            selector = selector,
            contentID = S.entityID,
            name = S.entityName,
            filter = S.entityFilter,
            requireVisible = S.entityRequireVisible,
            requireTargetable = S.entityRequireTargetable,
        }
    end

    local mode = S.targetResolveMode or (S.useCurrentTarget and 2 or ((S.targetID or 0) ~= 0 and 3 or 1))
    local selector = ({ "none", "current-target", "contentid", "name", "filter" })[mode] or "none"
    return {
        selector = selector,
        contentID = S.targetID,
        name = S.targetName,
        filter = S.targetFilter,
        requireVisible = S.targetRequireVisible,
        requireTargetable = S.targetRequireTargetable,
    }
end

local function DescribeSelectorSpec(spec)
    if spec.selector == "self" then
        return "自身"
    elseif spec.selector == "current-target" then
        return "当前目标"
    elseif spec.selector == "contentid" then
        return "ContentID=" .. tostring(spec.contentID or 0)
    elseif spec.selector == "name" then
        return "名称=" .. tostring(spec.name or "")
    elseif spec.selector == "filter" then
        return "过滤串=" .. tostring(spec.filter or "")
    end
    return "无目标"
end

local function EntityMatchesSelectorFilters(ent, spec)
    if not ent then return false end
    if spec.requireVisible and Argus and Argus.isEntityVisible and not Argus.isEntityVisible(ent) then
        return false
    end
    if spec.requireTargetable and not ent.targetable then
        return false
    end
    return true
end

local function ResolveSelectorEntities(spec)
    local results = {}

    local function push(ent)
        if EntityMatchesSelectorFilters(ent, spec) then
            table.insert(results, ent)
        end
    end

    local function pushEntityList(raw)
        if not raw then return end
        for _, ent in pairs(raw) do
            push(ent)
        end
    end

    if spec.selector == "none" then
        return results
    elseif spec.selector == "self" then
        push(Player)
    elseif spec.selector == "current-target" then
        local tgt = Player and Player.GetTarget and Player:GetTarget()
        push(tgt)
    elseif spec.selector == "contentid" then
        if (spec.contentID or 0) ~= 0 then
            if TensorCore and TensorCore.getEntityGroupList then
                pushEntityList(TensorCore.getEntityGroupList("ContentID", { contentid = spec.contentID }))
            else
                local el = EntityList("contentid=" .. tostring(spec.contentID))
                if el and TensorCore and TensorCore.mGetEntity then
                    for id, _ in pairs(el) do
                        push(TensorCore.mGetEntity(id))
                    end
                end
            end
        end
    elseif spec.selector == "name" then
        if spec.name and spec.name ~= "" and TensorCore and TensorCore.getEntityByGroup then
            local named = TensorCore.getEntityByGroup("Named Target", { name = spec.name, subgroup = "Number" })
            if named and named.id then
                push(named)
            else
                pushEntityList(named)
            end
        end
    elseif spec.selector == "filter" then
        if spec.filter and spec.filter ~= "" then
            if TensorCore and TensorCore.entityList then
                pushEntityList(TensorCore.entityList(spec.filter))
            else
                local el = EntityList(spec.filter)
                if el and TensorCore and TensorCore.mGetEntity then
                    for id, _ in pairs(el) do
                        push(TensorCore.mGetEntity(id))
                    end
                end
            end
        end
    end

    return results
end

local function BuildSelectorCodeCondition(spec, entVar)
    local conditions = { entVar }
    if spec.requireVisible then
        table.insert(conditions, "Argus.isEntityVisible(" .. entVar .. ")")
    end
    if spec.requireTargetable then
        table.insert(conditions, entVar .. ".targetable")
    end
    return table.concat(conditions, " and ")
end

local function AppendSelectorEntityListCode(lines, indent, listVar, spec)
    table.insert(lines, indent .. "local " .. listVar .. " = {}")
    local cond = BuildSelectorCodeCondition(spec, "_ent")

    if spec.selector == "none" then
        return listVar
    elseif spec.selector == "self" then
        table.insert(lines, indent .. "do")
        table.insert(lines, indent .. "    local _ent = Player")
        table.insert(lines, indent .. "    if " .. cond .. " then table.insert(" .. listVar .. ", _ent) end")
        table.insert(lines, indent .. "end")
    elseif spec.selector == "current-target" then
        table.insert(lines, indent .. "do")
        table.insert(lines, indent .. "    local _ent = Player:GetTarget()")
        table.insert(lines, indent .. "    if " .. cond .. " then table.insert(" .. listVar .. ", _ent) end")
        table.insert(lines, indent .. "end")
    elseif spec.selector == "contentid" then
        table.insert(lines, indent .. string.format("for _, _ent in pairs(TensorCore.getEntityGroupList(\"ContentID\", { contentid = %s }) or {}) do", FormatNum(spec.contentID or 0)))
        table.insert(lines, indent .. "    if " .. cond .. " then table.insert(" .. listVar .. ", _ent) end")
        table.insert(lines, indent .. "end")
    elseif spec.selector == "name" then
        table.insert(lines, indent .. "local _named = TensorCore.getEntityByGroup(\"Named Target\", { name = " .. string.format("%q", spec.name or "") .. ", subgroup = \"Number\" }) or {}")
        table.insert(lines, indent .. "if _named and _named.id then _named = { _named } end")
        table.insert(lines, indent .. "for _, _ent in pairs(_named) do")
        table.insert(lines, indent .. "    if " .. cond .. " then table.insert(" .. listVar .. ", _ent) end")
        table.insert(lines, indent .. "end")
    elseif spec.selector == "filter" then
        table.insert(lines, indent .. "for _, _ent in pairs(TensorCore.entityList(" .. string.format("%q", spec.filter or "") .. ") or {}) do")
        table.insert(lines, indent .. "    if " .. cond .. " then table.insert(" .. listVar .. ", _ent) end")
        table.insert(lines, indent .. "end")
    end

    return listVar
end

local function FormatColor(r, g, b, a)
    return string.format("GUI:ColorConvertFloat4ToU32(%.2f, %.2f, %.2f, %.2f)", r, g, b, a)
end

local function FormatNum(n)
    if n == math.floor(n) then
        return tostring(math.floor(n))
    end
    return string.format("%.2f", n)
end

--- 向 lines 表追加 drawer 创建代码（Combo / MapEffect 通用）
local function AppendDrawerCreation(lines, comment)
    if State.useMoogleDrawer then
        table.insert(lines, "local drawer = TensorCore.getMoogleDrawer()")
    else
        if comment then table.insert(lines, comment) end
        if State.useGradient then
            table.insert(lines, string.format("local drawer = Argus2.ShapeDrawer:new(%s, %s, %s, %s, %s)",
                FormatColor(State.startR, State.startG, State.startB, State.startA),
                FormatColor(State.midR, State.midG, State.midB, State.midA),
                FormatColor(State.endR, State.endG, State.endB, State.endA),
                FormatColor(State.outlineR, State.outlineG, State.outlineB, State.outlineA),
                FormatNum(State.outlineThickness)))
        else
            table.insert(lines, string.format("local drawer = Argus2.ShapeDrawer:new(nil, nil, %s, %s, %s)",
                FormatColor(State.fillR, State.fillG, State.fillB, State.fillA),
                FormatColor(State.outlineR, State.outlineG, State.outlineB, State.outlineA),
                FormatNum(State.outlineThickness)))
        end
    end
end

local OnEntOptionalFields = {
    Cone         = {"oldDraw", "doNotDetect"},
    Rect         = {"keepLength", "oldDraw", "doNotDetect"},
    CenteredRect = {"keepLength", "oldDraw", "doNotDetect"},
    DonutCone    = {"oldDraw", "doNotDetect"},
    Cross        = {"oldDraw", "doNotDetect"},
    Arrow        = {"oldDraw"},
    Chevron      = {"oldDraw"},
}

local function HasManualOnEntHeadingOverride(S)
    return (S.headingOffset or 0) ~= 0 or S.offsetIsAbsolute
end

local function ResolveOnEntHeadingCode(S)
    if HasManualOnEntHeadingOverride(S) then
        return FormatNum(math.rad(S.headingOffset or 0)), S.offsetIsAbsolute and "true" or nil
    end

    local offset = S.quickDirOffset or 0
    if S.headingSource == 1 then
        local oStr = offset ~= 0 and string.format(" + math.rad(%s)", FormatNum(offset)) or ""
        return "Player.pos.h" .. oStr, "true"
    elseif S.headingSource == 2 then
        if offset ~= 0 then
            return FormatNum(math.rad(offset)), nil
        end
    elseif S.headingSource == 3 then
        local oStr = offset ~= 0 and string.format(" + math.rad(%s)", FormatNum(offset)) or ""
        return "_tgt and _tgt.pos.h" .. oStr .. " or 0", "true"
    elseif S.headingSource == 4 then
        return FormatNum(math.rad(S.heading or 0)), "true"
    end
end

local function ResolveOnEntHeadingPreview(S)
    if HasManualOnEntHeadingOverride(S) then
        return math.rad(S.headingOffset or 0), S.offsetIsAbsolute or nil
    end

    local offsetRad = math.rad(S.quickDirOffset or 0)
    if S.headingSource == 1 then
        return (Player.pos and Player.pos.h or 0) + offsetRad, true
    elseif S.headingSource == 2 then
        if (S.quickDirOffset or 0) ~= 0 then
            return offsetRad, nil
        end
    elseif S.headingSource == 3 then
        local tgt = Player and Player.GetTarget and Player:GetTarget()
        return (tgt and tgt.pos and tgt.pos.h or 0) + offsetRad, true
    elseif S.headingSource == 4 then
        return math.rad(S.heading or 0), true
    end
end

local function BuildHeadingOffsetExpr(offset)
    if (offset or 0) ~= 0 then
        return string.format(" + math.rad(%s)", FormatNum(offset))
    end
    return ""
end

local function BuildLookAtHeadingExpr(targetXExpr, targetZExpr, originXExpr, originZExpr, offsetStr)
    return string.format(
        "math.atan2((%s) - (%s), (%s) - (%s))%s",
        targetXExpr,
        originXExpr,
        targetZExpr,
        originZExpr,
        offsetStr
    )
end

local function ResolveLookAtHeadingPreview(targetX, targetZ, originX, originZ, offsetRad)
    return math.atan2((targetX or 0) - (originX or 0), (targetZ or 0) - (originZ or 0)) + offsetRad
end

-- 坐标模式与 MapEffect 共用的朝向解析，避免预览/代码生成分叉。
local function AppendCoordHeadingCode(lines, indent, S, opts)
    opts = opts or {}
    local source = S.headingSource or opts.defaultSource or 1
    local headingVar = opts.headingVar or "heading"
    local posXVar = opts.posXVar or FormatNum(S.posX or 0)
    local posZVar = opts.posZVar or FormatNum(S.posZ or 0)

    if opts.resourceVar and source == 2 then
        local offsetStr = BuildHeadingOffsetExpr(S.quickDirOffset or 0)
        table.insert(lines, indent .. "local dx, dy, dz = Argus.getEffectResourceOrientation(" .. opts.resourceVar .. ")")
        table.insert(lines, indent .. "local " .. headingVar .. " = math.atan2(dx, dz)" .. offsetStr .. "  -- 从资源方向推导朝向")
        return headingVar
    end

    local offsetStr = BuildHeadingOffsetExpr(S.quickDirOffset or 0)
    if source == 1 then
        table.insert(lines, indent .. "local " .. headingVar .. " = Player.pos.h" .. offsetStr)
    elseif source == 3 then
        table.insert(lines, indent .. "local _tgt = Player:GetTarget()")
        table.insert(lines, indent .. "local " .. headingVar .. " = _tgt and (_tgt.pos.h" .. offsetStr .. ") or 0")
    elseif source == 5 then
        local expr = BuildLookAtHeadingExpr(
            FormatNum(S.headingTargetX or 0),
            FormatNum(S.headingTargetZ or 0),
            posXVar,
            posZVar,
            offsetStr
        )
        table.insert(lines, indent .. "local " .. headingVar .. " = " .. expr)
    elseif source == 6 then
        local expr = BuildLookAtHeadingExpr("Player.pos.x", "Player.pos.z", posXVar, posZVar, offsetStr)
        table.insert(lines, indent .. "local " .. headingVar .. " = " .. expr)
    else
        -- 固定角度，或坐标模式下无法直接解析的实体朝向回退。
        table.insert(lines, indent .. string.format("local %s = math.rad(%s)", headingVar, FormatNum(S.heading or 0)))
    end

    return headingVar
end

local function ResolveCoordHeadingPreview(S, pos, fallbackSource)
    local source = S.headingSource or fallbackSource or 1
    local offsetRad = math.rad(S.quickDirOffset or 0)
    local originX = (pos and pos.x) or S.posX or 0
    local originZ = (pos and pos.z) or S.posZ or 0

    if source == 1 then
        return (Player and Player.pos and Player.pos.h or 0) + offsetRad
    elseif source == 3 then
        local tgt = Player and Player.GetTarget and Player:GetTarget()
        return (tgt and tgt.pos and tgt.pos.h or 0) + offsetRad
    elseif source == 5 then
        return ResolveLookAtHeadingPreview(S.headingTargetX, S.headingTargetZ, originX, originZ, offsetRad)
    elseif source == 6 then
        return ResolveLookAtHeadingPreview(
            Player and Player.pos and Player.pos.x or 0,
            Player and Player.pos and Player.pos.z or 0,
            originX,
            originZ,
            offsetRad
        )
    end

    return math.rad(S.heading or 0)
end

local function BuildOnEntOptionalTail(sid, S, hoStr, absStr)
    local fields = OnEntOptionalFields[sid]
    if not fields then return "" end

    local parts = {}
    for _, field in ipairs(fields) do
        if field == "keepLength" then
            table.insert(parts, "nil")
        elseif field == "oldDraw" then
            table.insert(parts, S.oldDraw and "true" or "nil")
        elseif field == "doNotDetect" then
            table.insert(parts, S.doNotDetect and "true" or "nil")
        end
    end

    if hoStr ~= nil then
        table.insert(parts, hoStr)
        if absStr ~= nil then
            table.insert(parts, absStr)
        end
    end

    while #parts > 0 and parts[#parts] == "nil" do
        table.remove(parts)
    end

    if #parts == 0 then return "" end
    return ", " .. table.concat(parts, ", ")
end

-- =============================================
-- 导入/导出 (Phase 5)
-- =============================================
-- 需要序列化的字段列表 (排除临时 UI 状态)
local ExportableFields = {
    "shapeIndex", "timeout", "delay", "posX", "posY", "posZ", "heading",
    "radius", "radiusInner", "radiusOuter", "length", "width", "angle",
    "thickness", "baseLength", "baseWidth", "tipLength", "tipWidth",
    "pos2X", "pos2Y", "pos2Z",
    "useMoogleDrawer", "useGradient",
    "fillR", "fillG", "fillB", "fillA",
    "outlineR", "outlineG", "outlineB", "outlineA", "outlineThickness",
    "startR", "startG", "startB", "startA",
    "midR", "midG", "midB", "midA",
    "endR", "endG", "endB", "endA",
    "gradientIntensity", "gradientMinOpacity",
    "apiLevel", "timingMode", "attachMode", "headingSource", "quickDirOffset",
    "headingTargetX", "headingTargetY", "headingTargetZ",
    "entityResolveMode", "entityID", "entityName", "entityFilter",
    "entityRequireVisible", "entityRequireTargetable",
    "useSelfAsEntity", "renderAllEntities",
    "targetResolveMode", "useCurrentTarget", "targetID", "targetName", "targetFilter",
    "targetRequireVisible", "targetRequireTargetable",
    "followPlayerPos", "usePlayerPos", "renderOnTop", "doNotDetect",
    "headingOffset", "offsetIsAbsolute",
    "mechanicType",
    "condEnabled", "condBuffEnabled", "condBuffIDs", "condBuffLogic",
    "condCastEnabled", "condCastIDs",
    "condDistEnabled", "condDistMin", "condDistMax",
    "condZoneEnabled", "condZoneID", "condJobEnabled", "condJobID",
    "overlayTextEnabled", "overlayText", "overlayVOffset", "overlayFontScale",
    "tetherEnabled", "tetherMode", "tetherExtraLength",
    "includeTargetHitbox", "includeOwnHitbox",
}

--- 简易 Lua 值序列化 (不处理嵌套表)
local function SerializeValue(v)
    local t = type(v)
    if t == "string" then
        return string.format("%q", v)
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    end
    return "nil"
end

local ARGUS_EXPORT_SCHEMA_VERSION = 3
local ARGUS_STYLE_SCHEMA_VERSION = 1

local function ExportFieldSet(prefix, fields, schemaVersion)
    local parts = { prefix .. "{", "__schemaVersion=" .. tostring(schemaVersion) .. "," }
    for _, key in ipairs(fields) do
        local v = State[key]
        if v ~= nil then
            table.insert(parts, key .. "=" .. SerializeValue(v) .. ",")
        end
    end
    table.insert(parts, "}")
    return table.concat(parts, "")
end

local function ImportFieldSet(text, prefix, fields)
    if not text or text == "" then return false, "空文本" end
    local body = string.match(text, "^" .. prefix .. "(%b{})")
    if not body then return false, "格式错误 (需要 " .. prefix .. "{...})" end

    local fn, err = loadstring("return " .. body)
    if not fn then return false, "解析失败: " .. tostring(err) end
    if setfenv then setfenv(fn, {}) end

    local ok, data = pcall(fn)
    if not ok or type(data) ~= "table" then return false, "执行失败" end

    local allowed = {}
    for _, key in ipairs(fields) do allowed[key] = true end

    local count = 0
    for k, v in pairs(data) do
        if k ~= "__schemaVersion" and allowed[k] and type(v) == type(State[k]) then
            State[k] = v
            count = count + 1
        end
    end

    return true, count, tonumber(data.__schemaVersion) or 1
end

local function ExportState()
    SyncLegacyTargetSelectorFlags()
    return ExportFieldSet("ARGUS", ExportableFields, ARGUS_EXPORT_SCHEMA_VERSION)
end

local function ImportState(text)
    local ok, count, schemaVersion = ImportFieldSet(text, "ARGUS", ExportableFields)
    if not ok then return false, count end
    State.generatedCode = ""
    NormalizeTargetSelectorState(schemaVersion)
    SyncLegacyTargetSelectorFlags()

    local msg = string.format("%d 个字段已导入 (v%d)", count, schemaVersion)
    if schemaVersion > ARGUS_EXPORT_SCHEMA_VERSION then
        msg = msg .. "，包含更新版本字段，已按白名单忽略未知项"
    end
    return true, msg
end

--- 样式剪贴板 (仅颜色+drawer相关字段)
local StyleFields = {
    "useMoogleDrawer", "useGradient", "mechanicType",
    "fillR", "fillG", "fillB", "fillA",
    "outlineR", "outlineG", "outlineB", "outlineA", "outlineThickness",
    "startR", "startG", "startB", "startA",
    "midR", "midG", "midB", "midA",
    "endR", "endG", "endB", "endA",
    "gradientIntensity", "gradientMinOpacity",
}

local function ExportStyle()
    return ExportFieldSet("ARGUSSTYLE", StyleFields, ARGUS_STYLE_SCHEMA_VERSION)
end

local function ImportStyle(text)
    local ok, count, schemaVersion = ImportFieldSet(text, "ARGUSSTYLE", StyleFields)
    if not ok then return false, count end
    State.generatedCode = ""
    return true, string.format("%d 个样式字段已导入 (v%d)", count, schemaVersion)
end

local function CopyStyle()
    local clip = {}
    for _, k in ipairs(StyleFields) do
        clip[k] = State[k]
    end
    State.styleClipboard = clip
end

local function PasteStyle()
    if not State.styleClipboard then return end
    for _, k in ipairs(StyleFields) do
        if State.styleClipboard[k] ~= nil then
            State[k] = State.styleClipboard[k]
        end
    end
    State.generatedCode = ""
end

-- =============================================
-- 条件代码包装 (Phase 3)
-- =============================================
local function GenerateConditionWrapper(codeBody)
    if not State.condEnabled then return codeBody end

    local conditions = {}
    local preCode = {}

    -- Zone Lock
    if State.condZoneEnabled and State.condZoneID > 0 then
        table.insert(conditions, string.format("Player.localmapid == %d", State.condZoneID))
    end

    -- Job Lock
    if State.condJobEnabled and State.condJobID > 0 then
        table.insert(conditions, string.format("Player.job == %d", State.condJobID))
    end

    -- Buff Check
    if State.condBuffEnabled and State.condBuffIDs ~= "" then
        local ids = {}
        for id in string.gmatch(State.condBuffIDs, "%d+") do
            table.insert(ids, tonumber(id))
        end
        if #ids > 0 then
            table.insert(preCode, "local _hasBuff = function(entity, buffID)")
            table.insert(preCode, "    if entity and entity.buffs then")
            table.insert(preCode, "        for _, b in pairs(entity.buffs) do")
            table.insert(preCode, "            if b.id == buffID then return true end")
            table.insert(preCode, "        end")
            table.insert(preCode, "    end")
            table.insert(preCode, "    return false")
            table.insert(preCode, "end")
            if State.condBuffLogic == 2 then
                -- AND: 全部满足
                local checks = {}
                for _, id in ipairs(ids) do
                    table.insert(checks, string.format("_hasBuff(Player, %d)", id))
                end
                table.insert(conditions, "(" .. table.concat(checks, " and ") .. ")")
            else
                -- OR: 任一满足
                local checks = {}
                for _, id in ipairs(ids) do
                    table.insert(checks, string.format("_hasBuff(Player, %d)", id))
                end
                table.insert(conditions, "(" .. table.concat(checks, " or ") .. ")")
            end
        end
    end

    -- Cast Check
    if State.condCastEnabled and State.condCastIDs ~= "" then
        local ids = {}
        for id in string.gmatch(State.condCastIDs, "%d+") do
            table.insert(ids, tonumber(id))
        end
        if #ids > 0 then
            table.insert(preCode, "local _el = EntityList(\"alive,chartype=5,maxdistance=80\")")
            local checks = {}
            for _, id in ipairs(ids) do
                table.insert(checks, string.format("(e.castinginfo and e.castinginfo.castingid == %d)", id))
            end
            local castCondStr = table.concat(checks, " or ")
            table.insert(preCode, "local _castFound = false")
            table.insert(preCode, "if _el then for _, e in pairs(_el) do")
            table.insert(preCode, "    if " .. castCondStr .. " then _castFound = true; break end")
            table.insert(preCode, "end end")
            table.insert(conditions, "_castFound")
        end
    end

    -- Distance Check
    if State.condDistEnabled then
        table.insert(preCode, "local _tgt = Player:GetTarget()")
        table.insert(preCode, "local _dist = _tgt and _tgt.distance or 999")
        table.insert(conditions, string.format("(_dist >= %s and _dist <= %s)",
            FormatNum(State.condDistMin), FormatNum(State.condDistMax)))
    end

    if #conditions == 0 and #preCode == 0 then return codeBody end

    local result = {}
    table.insert(result, "-- 条件检查")
    for _, line in ipairs(preCode) do
        table.insert(result, line)
    end
    if #conditions > 0 then
        table.insert(result, "if " .. table.concat(conditions, " and ") .. " then")
        -- 缩进原始代码
        for line in string.gmatch(codeBody, "([^\n]*)\n?") do
            if line ~= "" then
                table.insert(result, "    " .. line)
            end
        end
        table.insert(result, "end")
    else
        table.insert(result, "")
        table.insert(result, codeBody)
    end

    return table.concat(result, "\n")
end

-- =============================================
-- 代码生成引擎
-- =============================================
local function GenerateCode()
    local shape = GetCurrentShape()
    if not shape then return "" end

    local lines = {}
    local sid = shape.id
    local isTimed = (State.timingMode == 1)
    local isOnEnt = (State.attachMode == 2)
    local isShapeDrawer = (State.apiLevel == 1)

    -- 注释头
    table.insert(lines, "-- Argus 绘图代码 (由 StringCore 代码生成器生成)")
    table.insert(lines, "-- 形状: " .. shape.name .. "  模式: " .. (isTimed and "Timed" or "OnFrame"))
    table.insert(lines, "")

    -- 坐标变量
    if not isOnEnt then
        if State.followPlayerPos then
            -- 使用玩家动态位置
            if sid == "Line" then
                table.insert(lines, "local x, y, z = Player.pos.x, Player.pos.y, Player.pos.z")
                table.insert(lines, string.format("local x2, y2, z2 = %s, %s, %s",
                    FormatNum(State.pos2X), FormatNum(State.pos2Y), FormatNum(State.pos2Z)))
            else
                table.insert(lines, "local x, y, z = Player.pos.x, Player.pos.y, Player.pos.z")
            end
        else
            -- 使用固定坐标
            if sid == "Line" then
                table.insert(lines, string.format("local x, y, z = %s, %s, %s",
                    FormatNum(State.posX), FormatNum(State.posY), FormatNum(State.posZ)))
                table.insert(lines, string.format("local x2, y2, z2 = %s, %s, %s",
                    FormatNum(State.pos2X), FormatNum(State.pos2Y), FormatNum(State.pos2Z)))
            else
                table.insert(lines, string.format("local x, y, z = %s, %s, %s",
                    FormatNum(State.posX), FormatNum(State.posY), FormatNum(State.posZ)))
            end
        end
        table.insert(lines, "")
    end

    -- 朝向
    local needsHeading = ShapeNeedsHeading(sid)
    if needsHeading and not isOnEnt then
        AppendCoordHeadingCode(lines, "", State, { posXVar = "x", posZVar = "z" })
        table.insert(lines, "")
    end

    -- 角度（扇形类）
    local needsAngle = ShapeNeedsAngle(sid)
    if needsAngle then
        table.insert(lines, string.format("local angle = math.rad(%s)  -- %s°", FormatNum(State.angle), FormatNum(State.angle)))
        table.insert(lines, "")
    end

    -- Hitbox 半径补偿 (Phase 6)
    local useHitbox = (State.includeTargetHitbox or State.includeOwnHitbox) and ShapeUsesHitboxCompensation(sid)
    if useHitbox then
        table.insert(lines, "-- Hitbox 半径补偿")
        table.insert(lines, "local _hitboxExtra = 0")
        if State.includeTargetHitbox then
            table.insert(lines, "local _tgt = Player:GetTarget()")
            table.insert(lines, "if _tgt then _hitboxExtra = _hitboxExtra + (_tgt.hitradius or 0) end")
        end
        if State.includeOwnHitbox then
            table.insert(lines, "_hitboxExtra = _hitboxExtra + (Player.hitradius or 0)")
        end
        table.insert(lines, "")
    end

    if isShapeDrawer or State.apiLevel == 3 then
        -- === ShapeDrawer / StaticDrawer 模式 ===
        -- 创建 drawer
        if State.apiLevel == 3 then
            -- StaticDrawer (OnFrame 专用，不支持 Timed)
            local outlineColor = FormatColor(State.outlineR, State.outlineG, State.outlineB, State.outlineA)
            table.insert(lines, "-- StaticDrawer: 仅用于 OnFrame，无渐变")
            table.insert(lines, string.format("local drawer = TensorCore.getStaticDrawer(%s, %s)",
                outlineColor, FormatNum(State.outlineThickness)))
        elseif State.useMoogleDrawer then
            table.insert(lines, "-- 使用 TensorCore 默认配色")
            table.insert(lines, "local drawer = TensorCore.getMoogleDrawer()")
        elseif State.useGradient then
            local outlineColor = FormatColor(State.outlineR, State.outlineG, State.outlineB, State.outlineA)
            local startColor = FormatColor(State.startR, State.startG, State.startB, State.startA)
            local midColor = FormatColor(State.midR, State.midG, State.midB, State.midA)
            local endColor = FormatColor(State.endR, State.endG, State.endB, State.endA)
            table.insert(lines, "-- 创建渐变色绘图器")
            table.insert(lines, string.format("local drawer = Argus2.ShapeDrawer:new(\n    %s,  -- 起始颜色\n    %s,  -- 中间颜色\n    %s,  -- 结束颜色\n    %s,  -- 描边颜色\n    %s  -- 描边粗细\n)",
                startColor, midColor, endColor, outlineColor, FormatNum(State.outlineThickness)))
        else
            local fillColor = FormatColor(State.fillR, State.fillG, State.fillB, State.fillA)
            local outlineColor = FormatColor(State.outlineR, State.outlineG, State.outlineB, State.outlineA)
            table.insert(lines, "-- 创建绘图器")
            table.insert(lines, string.format("local drawer = Argus2.ShapeDrawer:new(\n    nil,  -- 起始颜色 (无渐变)\n    nil,  -- 中间颜色 (无渐变)\n    %s,  -- 填充颜色\n    %s,  -- 描边颜色\n    %s  -- 描边粗细\n)",
                fillColor, outlineColor, FormatNum(State.outlineThickness)))
        end
        table.insert(lines, "")

        -- 绘图调用
        if isTimed then
            if isOnEnt then
                -- addTimedXxxOnEnt
                local methodName = "addTimed" .. sid .. "OnEnt"
                local entitySpec = GetSelectorSpec(State, "entity")
                local targetSpec = GetSelectorSpec(State, "target")
                local renderAll = State.renderAllEntities and entitySpec.selector ~= "self"

                if renderAll then
                    table.insert(lines, "-- 附着实体绘图 (渲染全部匹配实体)")
                else
                    table.insert(lines, "-- 附着实体绘图: " .. DescribeSelectorSpec(entitySpec))
                end

                AppendSelectorEntityListCode(lines, "", "_entMatches", entitySpec)
                table.insert(lines, "if #_entMatches == 0 then return end")
                table.insert(lines, "")

                local tgtStr = "0"
                if targetSpec.selector ~= "none" then
                    AppendSelectorEntityListCode(lines, "", "_tgtMatches", targetSpec)
                    table.insert(lines, "local tgtID = _tgtMatches[1] and _tgtMatches[1].id or 0")
                    table.insert(lines, "")
                    tgtStr = "tgtID"
                end

                -- 缩进前缀：renderAll 模式下绘图调用在 for 循环内
                local ii = renderAll and "    " or ""
                local entStr = "entID"

                local args = FormatNum(State.timeout) .. ", " .. entStr .. ", " ..
                    BuildArgs(ShapeParams[sid].ent, State, FormatNum, tgtStr, { useHitbox = useHitbox })

                -- 附加 headingOffset / offsetIsAbsolute（基于朝向来源）
                local nilCount = (ShapeParams[sid] or {}).entNilPad
                if nilCount and needsHeading then
                    if State.headingSource == 3 and not HasManualOnEntHeadingOverride(State) then
                        table.insert(lines, "local _tgt = Player:GetTarget()")
                    end
                    local hoStr, absStr = ResolveOnEntHeadingCode(State)
                    args = args .. BuildOnEntOptionalTail(sid, State, hoStr, absStr)
                end

                -- 生成绘图调用
                if renderAll then
                    table.insert(lines, "for _, _selectedEnt in ipairs(_entMatches) do")
                    table.insert(lines, ii .. "local entID = _selectedEnt.id")
                    table.insert(lines, ii .. "drawer:" .. methodName .. "(" .. args .. ")")
                    table.insert(lines, "end")
                else
                    table.insert(lines, "local entID = _entMatches[1] and _entMatches[1].id or nil")
                    table.insert(lines, "if not entID then return end")
                    table.insert(lines, "local uuid = drawer:" .. methodName .. "(" .. args .. ")")
                end
            else
                -- addTimedXxx (坐标版本)
                local methodName = "addTimed" .. sid
                table.insert(lines, "-- 持续绘图 (坐标)")
                local args = FormatNum(State.timeout) .. ", " ..
                    BuildArgs(ShapeParams[sid].coord, State, FormatNum, nil, { useHitbox = useHitbox })

                table.insert(lines, "local uuid = drawer:" .. methodName .. "(" .. args .. ")")
            end
        else
            -- OnFrame 瞬时方法
            table.insert(lines, "-- 瞬时绘图 (仅在 OnFrame 事件中使用)")
            local frameArgs = BuildArgs(ShapeParams[sid].frame, State, FormatNum, nil, { useHitbox = useHitbox })
            table.insert(lines, "drawer:add" .. sid .. "(" .. frameArgs .. ")")
        end
    else
        -- === Argus2 底层模式 ===
        local fillColor = FormatColor(State.fillR, State.fillG, State.fillB, State.fillA)
        local outlineColor = FormatColor(State.outlineR, State.outlineG, State.outlineB, State.outlineA)

        table.insert(lines, "-- 颜色定义")
        table.insert(lines, "local colorFill = " .. fillColor)
        table.insert(lines, "local colorOutline = " .. outlineColor)
        if State.useGradient then
            table.insert(lines, "local colorStart = " .. FormatColor(State.startR, State.startG, State.startB, State.startA))
            table.insert(lines, "local colorMid = " .. FormatColor(State.midR, State.midG, State.midB, State.midA))
        end
        table.insert(lines, "")

        if isTimed then
            local methodName = "Argus2.addTimed" .. sid .. "Filled"
            if isOnEnt then
                -- OnEnt 版本暂不支持 Argus2 底层（参数太多，用 ShapeDrawer 代替）
                table.insert(lines, "-- 注意: Argus2 底层 OnEnt 版本参数复杂，建议使用 ShapeDrawer 模式")
            end
            table.insert(lines, "-- Argus2 底层 Timed 绘图")

            local colorArgs
            if State.useGradient then
                colorArgs = "colorStart, colorFill, colorMid"
            else
                colorArgs = "colorFill, colorFill, nil"
            end

            if sid == "Circle" then
                local radiusExpr = useHitbox and "(" .. FormatNum(State.radius) .. " + _hitboxExtra)" or FormatNum(State.radius)
                table.insert(lines, string.format("%s(\n    %s, %s, %s,  -- timeout, x, y, z\n    %s,  -- colorStart, colorEnd\n    %s,  -- radius\n    50,  -- segments\n    %s,  -- delay\n    nil,  -- entityAttachID\n    colorOutline,  -- 描边颜色\n    %s  -- 描边粗细\n)",
                    methodName, FormatNum(State.timeout), "x", "y, z",
                    colorArgs, radiusExpr,
                    FormatNum(State.delay), FormatNum(State.outlineThickness)))
            else
                table.insert(lines, "-- 请参考 TensorCore API Reference 了解 " .. methodName .. " 的完整参数列表")
            end
        end
    end

    -- Overlay Text (Phase 2)
    if State.overlayTextEnabled and State.overlayText ~= "" then
        table.insert(lines, "")
        table.insert(lines, "-- 悬浮文字 (AnyoneCore.addTimedWorldText)")
        table.insert(lines, string.format(
            "AnyoneCore.addTimedWorldText(%s, %q, {x=%s, y=%s, z=%s}, 0xFFFFFFFF, false, %.1f)",
            FormatNum(State.timeout),
            State.overlayText,
            FormatNum(State.posX), FormatNum(State.posY + State.overlayVOffset), FormatNum(State.posZ),
            State.overlayFontScale))
    end

    -- Tether (Phase 2)
    if State.tetherEnabled then
        table.insert(lines, "")
        table.insert(lines, "-- 连线 (drawer:addTimedLine)")
        if State.tetherMode == 1 then
            -- 玩家到坐标
            table.insert(lines, string.format(
                "drawer:addTimedLine(%s, Player.pos.x, Player.pos.y, Player.pos.z, %s, %s, %s, %s)",
                FormatNum(State.timeout),
                FormatNum(State.posX), FormatNum(State.posY), FormatNum(State.posZ),
                FormatNum(State.thickness > 0 and State.thickness or 2)))
        else
            -- 实体到实体 (模板代码)
            table.insert(lines, "-- [模板] 修改 entity1ID / entity2Pos 为实际值")
            table.insert(lines, "-- local ent = TensorCore.mGetEntity(entity1ID)")
            table.insert(lines, "-- if ent then")
            table.insert(lines, string.format(
                "--     drawer:addTimedLine(%s, ent.pos.x, ent.pos.y, ent.pos.z, targetX, targetY, targetZ, %s)",
                FormatNum(State.timeout),
                FormatNum(State.thickness > 0 and State.thickness or 2)))
            table.insert(lines, "-- end")
        end
    end

    -- 防止重复触发
    table.insert(lines, "self.used = true")

    -- updateTimed / deleteTimedShape 使用提示
    if isTimed then
        table.insert(lines, "")
        table.insert(lines, "-- [提示] 动态更新已创建的绘图:")
        table.insert(lines, "-- drawer:updateTimed" .. shape.id .. "(uuid, nil, newX, newY, newZ, newRadius)  -- 参数传 nil 保持原值")
        table.insert(lines, "-- Argus.deleteTimedShape(uuid)  -- 删除单个绘图")
        table.insert(lines, "-- Argus.deleteTimedShape()       -- 删除全部绘图")
    end

    table.insert(lines, "")

    local rawCode = table.concat(lines, "\n")
    State.generatedCode = GenerateConditionWrapper(rawCode)
    return State.generatedCode
end



-- =============================================
-- 动态执行代码字符串
-- =============================================
local function ExecuteCodeString(code)
    if not code or code == "" then
        State.lastLog = "没有代码可执行"
        State.lastRunError = ""
        return
    end

    ClearPreviewShapes()

    -- 在代码头部注入 self 变量，避免 self.used = true 报错
    local wrappedCode = "local self = {used = false}\n" .. code

    local fn, compileErr = loadstring(wrappedCode)
    if not fn then
        State.lastRunError = "编译错误: " .. tostring(compileErr)
        State.lastLog = "代码编译失败"
        d("[ArgusBuilder] " .. State.lastRunError)
        return
    end

    local ok, runErr = pcall(fn)
    if not ok then
        State.lastRunError = "运行错误: " .. tostring(runErr)
        State.lastLog = "代码运行失败"
        d("[ArgusBuilder] " .. State.lastRunError)
    else
        State.lastRunError = ""
        State.lastLog = "代码执行成功"
        d("[ArgusBuilder] 代码执行成功")
    end
end

-- =============================================
-- 预览执行
-- =============================================
local function ExecutePreview()
    if not Argus2 or not Argus2.ShapeDrawer then
        State.lastLog = "错误: Argus2 API 不可用"
        d("[ArgusBuilder] 错误: Argus2 不可用")
        return
    end

    SyncPlayerPos()

    local shape = GetCurrentShape()
    if not shape then return end

    ClearPreviewShapes()
    local drawer = CreatePreviewDrawer()

    local sid = shape.id
    local x, y, z = State.posX, State.posY, State.posZ
    local timeout = State.timeout
    local del = State.delay
    local headingRad = ShapeNeedsHeading(sid)
        and ResolveCoordHeadingPreview(State, { x = x, y = y, z = z }) or 0
    local angleRad = math.rad(State.angle)

    local isOnEnt = (State.attachMode == 2)
    local uuid

    if isOnEnt then
        local entitySpec = GetSelectorSpec(State, "entity")
        local targetSpec = GetSelectorSpec(State, "target")

        -- 收集实体 ID 列表
        local entIDs = {}
        local entMatches = ResolveSelectorEntities(entitySpec)
        if State.renderAllEntities and entitySpec.selector ~= "self" then
            for _, ent in ipairs(entMatches) do
                table.insert(entIDs, ent.id)
            end
        elseif entMatches[1] and entMatches[1].id then
            table.insert(entIDs, entMatches[1].id)
        end

        if #entIDs == 0 then
            State.lastLog = "错误: 未找到匹配实体 - " .. DescribeSelectorSpec(entitySpec)
            d("[ArgusBuilder] 错误: 未找到匹配实体 - " .. DescribeSelectorSpec(entitySpec))
            return
        end

        local tgtID
        local tgtMatches = ResolveSelectorEntities(targetSpec)
        tgtID = tgtMatches[1] and tgtMatches[1].id or 0

        -- 计算 headingOffset / offsetIsAbsolute (预览用)
        local ho, hoAbs
        if ShapeNeedsHeading(sid) then
            ho, hoAbs = ResolveOnEntHeadingPreview(State)
        end

        -- 对每个实体执行绘图（通过分派表）
        local entFn = PreviewTimedEnt[sid]
        if entFn then
            for _, entID in ipairs(entIDs) do
                uuid = entFn(drawer, timeout, entID, tgtID, headingRad, angleRad, State, del, ho, hoAbs)
                if uuid then table.insert(State.previewUUIDs, uuid) end
            end
        end
    else
        -- 坐标模式绘图（通过分派表）
        local coordFn = PreviewTimedCoord[sid]
        if coordFn then
            uuid = coordFn(drawer, timeout, x, y, z, headingRad, angleRad, State, del)
            if uuid then table.insert(State.previewUUIDs, uuid) end
        end
    end

    State.lastLog = "预览已执行: " .. shape.name .. " (" .. timeout .. "ms)"
    d("[ArgusBuilder] 预览: " .. shape.name)
end

-- =============================================
-- 绘制颜色选择器区域
-- =============================================
local function DrawColorPicker(label, rKey, gKey, bKey, aKey)
    -- 防御 nil 值
    if not State[rKey] then State[rKey] = 0.5 end
    if not State[gKey] then State[gKey] = 0.5 end
    if not State[bKey] then State[bKey] = 0.5 end
    if not State[aKey] then State[aKey] = 1.0 end

    local flags = (GUI.ColorEditMode_NoInputs or 0) + (GUI.ColorEditMode_AlphaBar or 0)
    
    -- 注意：不要要在 label 里拼接动态变化的数值！否则拖拽时数值一变，控件 ID 就变了，会导致鼠标瞬间丢失焦点无法拖拽。
    local r, g, b, a, changed = GUI:ColorEdit4(
        label .. "##Color" .. rKey, 
        State[rKey], State[gKey], State[bKey], State[aKey], 
        flags
    )
    
    GUI:SameLine()
    GUI:TextColored(0.7, 0.7, 0.7, 1.0, string.format("(%.0f, %.0f, %.0f)", State[rKey]*255, State[gKey]*255, State[bKey]*255))
    
    if changed then
        State[rKey] = r
        State[gKey] = g
        State[bKey] = b
        State[aKey] = a
    end

    GUI:PushItemWidth(120)
    State[rKey] = GUI:SliderFloat("R##" .. rKey, State[rKey], 0, 1)
    GUI:SameLine(0, 5)
    State[gKey] = GUI:SliderFloat("G##" .. rKey, State[gKey], 0, 1)
    State[bKey] = GUI:SliderFloat("B##" .. rKey, State[bKey], 0, 1)
    GUI:SameLine(0, 5)
    State[aKey] = GUI:SliderFloat("A##" .. rKey, State[aKey], 0, 1)
    GUI:PopItemWidth()
end

-- =============================================
-- 绘制预设颜色按钮
-- =============================================
local function DrawPresetButtons(rKey, gKey, bKey, aKey)
    for i, preset in ipairs(PresetColors) do
        if i > 1 then GUI:SameLine(0, 3) end
        -- 用颜色来渲染按钮文字
        GUI:PushStyleColor(GUI.Col_Button, preset.r * 0.6, preset.g * 0.6, preset.b * 0.6, 0.8)
        GUI:PushStyleColor(GUI.Col_ButtonHovered, preset.r * 0.8, preset.g * 0.8, preset.b * 0.8, 0.9)
        GUI:PushStyleColor(GUI.Col_ButtonActive, preset.r, preset.g, preset.b, 1.0)
        if GUI:Button(preset.name .. "##" .. rKey, 0, 20) then
            State[rKey] = preset.r
            State[gKey] = preset.g
            State[bKey] = preset.b
            State[aKey] = preset.a
        end
        GUI:PopStyleColor(3)
    end
end

-- 实现前置声明的 DrawColorSection
DrawColorSection = function(label, rKey, gKey, bKey, aKey)
    DrawColorPicker(label, rKey, gKey, bKey, aKey)
    DrawPresetButtons(rKey, gKey, bKey, aKey)
end

-- =============================================
-- 组合机制：模式名称
-- =============================================
local ComboModeNames = { "循环前进 (地火)", "顺序执行 (先后)", "同时执行 (并发)" }

-- =============================================
-- 快照当前形状参数为一个步骤
-- =============================================
local function SnapshotCurrentStep(stepDelay)
    local shape = GetCurrentShape()
    if not shape then return nil end
    local step = {
        shapeIndex = State.shapeIndex,
        shapeName  = shape.name,
        shapeId    = shape.id,
        delay      = stepDelay or 0,
        -- 复用当前参数
        radius      = State.radius,
        radiusInner = State.radiusInner,
        radiusOuter = State.radiusOuter,
        length      = State.length,
        width       = State.width,
        angle       = State.angle,
        heading     = State.heading,
        thickness   = State.thickness,
        baseLength  = State.baseLength,
        baseWidth   = State.baseWidth,
        tipLength   = State.tipLength,
        tipWidth    = State.tipWidth,
        pos2X       = State.pos2X,
        pos2Y       = State.pos2Y,
        pos2Z       = State.pos2Z,
    }
    return CopyCoordHeadingState(step, State)
end

-- =============================================
-- 快照当前参数为 MapEffect 触发步骤
-- =============================================
local function SnapshotMEStep()
    local shape = GetCurrentShape()
    if not shape then return nil end
    SyncPlayerPos()
    local step = {
        a1 = State.meA1,
        a3 = State.meA3,
        checkA3 = State.meCheckA3,
        label = State.meLabel,
        posMode = State.mePosMode,
        resourcePath = State.meResourcePath,
        resourceType = State.meResourceType,
        resourceDirX = State.meResourceDirX,
        resourceDirY = State.meResourceDirY,
        resourceDirZ = State.meResourceDirZ,
        shapeIndex = State.shapeIndex,
        shapeName  = shape.name,
        shapeId    = shape.id,
        timeout    = State.timeout,
        delay      = State.delay,
        radius      = State.radius,
        radiusInner = State.radiusInner,
        radiusOuter = State.radiusOuter,
        length      = State.length,
        width       = State.width,
        angle       = State.angle,
        thickness   = State.thickness,
        baseLength  = State.baseLength,
        baseWidth   = State.baseWidth,
        tipLength   = State.tipLength,
        tipWidth    = State.tipWidth,
        posX = State.posX,
        posY = State.posY,
        posZ = State.posZ,
        pos2X = State.pos2X,
        pos2Y = State.pos2Y,
        pos2Z = State.pos2Z,
    }
    return CopyCoordHeadingState(step, State)
end

-- =============================================
-- 生成单个形状的绘图调用字符串（通过 ShapeParams 配置）
-- =============================================
local function GenerateShapeCall(step, posVar, headingVar, delayVal)
    local sid = step.shapeId
    local params = ShapeParams[sid]
    if not params or not params.coord then return "-- 不支持的形状: " .. sid end
    local args = BuildArgsCustom(params.coord, step, FormatNum, posVar, headingVar, delayVal)
    return "drawer:addTimed" .. sid .. "(timeout, " .. args .. ")"
end

-- =============================================
-- 组合机制代码生成
-- =============================================
local function GenerateComboCode()
    local lines = {}
    local mode = State.comboMode

    table.insert(lines, "-- 组合机制代码 (由 StringCore 代码生成器生成)")

    -- 坐标和 drawer
    if State.followPlayerPos then
        table.insert(lines, "local x, y, z = Player.pos.x, Player.pos.y, Player.pos.z")
    else
        if Player and Player.pos then SyncPlayerPos() end
        table.insert(lines, string.format("local x, y, z = %s, %s, %s",
            FormatNum(State.posX), FormatNum(State.posY), FormatNum(State.posZ)))
    end
    AppendCoordHeadingCode(lines, "", State, { posXVar = "x", posZVar = "z" })
    table.insert(lines, string.format("local timeout = %s", FormatNum(State.timeout)))
    table.insert(lines, "")

    AppendDrawerCreation(lines, "-- 创建绘图器 (请根据需要调整颜色)")
    table.insert(lines, "")

    if mode == 1 then
        -- === 循环前进 (地火) ===
        local loopShape = ShapeDefinitions[State.loopShapeIndex]
        if not loopShape then
            State.comboGeneratedCode = "-- 错误: 无效的形状索引"
            return
        end
        local step = {
            shapeId     = loopShape.id,
            shapeName   = loopShape.name,
            radius      = State.radius,
            radiusInner = State.radiusInner,
            radiusOuter = State.radiusOuter,
            length      = State.length,
            width       = State.width,
            angle       = State.angle,
            heading     = State.heading,
            thickness   = State.thickness,
            baseLength  = State.baseLength,
            baseWidth   = State.baseWidth,
            tipLength   = State.tipLength,
            tipWidth    = State.tipWidth,
        }
        CopyCoordHeadingState(step, State)

        table.insert(lines, string.format("-- 循环前进 (地火): %s × %d  步进 %s米  间隔 %sms",
            loopShape.name, State.loopCount, FormatNum(State.loopStepDist), FormatNum(State.loopInterval)))
        table.insert(lines, string.format("for i = 0, %d do", State.loopCount - 1))
        table.insert(lines, string.format("    local pos = TensorCore.getPosInDirection({x=x, y=y, z=z}, heading, i * %s)",
            FormatNum(State.loopStepDist)))
        local loopHeadingVar = ShapeNeedsHeading(step.shapeId) and "heading" or "0"
        if ShapeNeedsHeading(step.shapeId) then
            loopHeadingVar = AppendCoordHeadingCode(lines, "    ", step, {
                posXVar = "pos.x",
                posZVar = "pos.z",
                headingVar = "stepHeading",
            })
        end
        local call = GenerateShapeCall(step, "pos.x, pos.y, pos.z", loopHeadingVar, 0)
        -- 替换 delay 0 为 i * interval
        call = string.gsub(call, ", 0%)$", string.format(", i * %s)", FormatNum(State.loopInterval)))
        table.insert(lines, "    " .. call)
        table.insert(lines, "end")

    elseif mode == 2 then
        -- === 顺序执行 ===
        if #State.comboSteps == 0 then
            table.insert(lines, "-- 没有步骤，请先添加步骤")
        else
            table.insert(lines, "-- 顺序执行: " .. #State.comboSteps .. " 个步骤")
            for i, step in ipairs(State.comboSteps) do
                table.insert(lines, "")
                table.insert(lines, string.format("-- 步骤 %d: %s (延迟 %dms)", i, step.shapeName, step.delay))
                local headVar = ShapeNeedsHeading(step.shapeId) and "heading" or "0"
                if ShapeNeedsHeading(step.shapeId) then
                    headVar = AppendCoordHeadingCode(lines, "", step, {
                        posXVar = "x",
                        posZVar = "z",
                        headingVar = "stepHeading" .. tostring(i),
                        defaultSource = 4,
                    })
                end
                local call = GenerateShapeCall(step, "x, y, z", headVar, step.delay)
                table.insert(lines, call)
            end
        end

    elseif mode == 3 then
        -- === 同时执行 ===
        if #State.comboSteps == 0 then
            table.insert(lines, "-- 没有步骤，请先添加步骤")
        else
            table.insert(lines, "-- 同时执行: " .. #State.comboSteps .. " 个步骤")
            for i, step in ipairs(State.comboSteps) do
                table.insert(lines, "")
                table.insert(lines, string.format("-- 步骤 %d: %s", i, step.shapeName))
                local headVar = ShapeNeedsHeading(step.shapeId) and "heading" or "0"
                if ShapeNeedsHeading(step.shapeId) then
                    headVar = AppendCoordHeadingCode(lines, "", step, {
                        posXVar = "x",
                        posZVar = "z",
                        headingVar = "stepHeading" .. tostring(i),
                        defaultSource = 4,
                    })
                end
                local call = GenerateShapeCall(step, "x, y, z", headVar, 0)
                table.insert(lines, call)
            end
        end
    end

    table.insert(lines, "")
    State.comboGeneratedCode = table.concat(lines, "\n")
end

-- =============================================
-- MapEffect 触发器代码生成
-- =============================================
local function GenerateMapEffectCode()
    local entries = State.meEntries
    if #entries == 0 then
        State.meGeneratedCode = "-- 没有 MapEffect 触发条件，请先添加"
        return
    end

    local lines = {}
    local isRegister = (State.meCodeMode == 2)

    table.insert(lines, "-- MapEffect 触发绘图代码 (由 StringCore 代码生成器生成)")
    if isRegister then
        table.insert(lines, "-- 模式: Argus.registerOnMapEffect (独立注册)")
    else
        table.insert(lines, "-- 模式: TensorReactions OnMapEffect 事件")
        table.insert(lines, "-- 在 TensorReactions 中创建触发器，事件类型选择 OnMapEffect")
    end
    table.insert(lines, "")

    -- Drawer
    AppendDrawerCreation(lines)
    table.insert(lines, "")

    local bi = ""  -- base indent
    if isRegister then
        table.insert(lines, "Argus.registerOnMapEffect(function(a1, a2, a3)")
        bi = "    "
    end

    for i, entry in ipairs(entries) do
        if i > 1 then table.insert(lines, "") end

        -- 条件
        local cond = "a1 == " .. FormatNum(entry.a1)
        if entry.checkA3 then
            cond = cond .. " and a3 == " .. FormatNum(entry.a3)
        end

        if entry.label and entry.label ~= "" then
            table.insert(lines, bi .. "-- " .. entry.label)
        end
        if entry.resourcePath and entry.resourcePath ~= "" then
            table.insert(lines, bi .. "-- 资源: " .. entry.resourcePath .. "  type=" .. tostring(entry.resourceType or 0))
        end
        table.insert(lines, bi .. "if " .. cond .. " then")

        local ii = bi .. "    "  -- inner indent

        local needsHeading = ShapeNeedsHeading(entry.shapeId)
        local headVar = needsHeading and "heading" or "0"

        -- 位置 + 绘图调用
        if entry.posMode == 2 then
            -- 特效资源位置（可选获取朝向）
            table.insert(lines, ii .. "local res = Argus.getMapEffectResource(a1)")
            table.insert(lines, ii .. "if res then")
            local di = ii .. "    "
            table.insert(lines, di .. "local x, y, z = Argus.getEffectResourcePosition(res)")
            if needsHeading then
                headVar = AppendCoordHeadingCode(lines, di, entry, {
                    resourceVar = "res",
                    posXVar = "x",
                    posZVar = "z",
                })
            end
            table.insert(lines, di .. string.format("local timeout = %s", FormatNum(entry.timeout or 5000)))
            table.insert(lines, di .. GenerateShapeCall(entry, "x, y, z", headVar, entry.delay or 0))
            table.insert(lines, ii .. "end")
        elseif entry.posMode == 3 then
            -- 玩家位置
            table.insert(lines, ii .. "local x, y, z = Player.pos.x, Player.pos.y, Player.pos.z")
            if needsHeading then
                headVar = AppendCoordHeadingCode(lines, ii, entry, { posXVar = "x", posZVar = "z" })
            end
            table.insert(lines, ii .. string.format("local timeout = %s", FormatNum(entry.timeout or 5000)))
            table.insert(lines, ii .. GenerateShapeCall(entry, "x, y, z", headVar, entry.delay or 0))
        else
            -- 固定坐标
            table.insert(lines, ii .. string.format("local x, y, z = %s, %s, %s",
                FormatNum(entry.posX), FormatNum(entry.posY), FormatNum(entry.posZ)))
            if needsHeading then
                headVar = AppendCoordHeadingCode(lines, ii, entry, { posXVar = "x", posZVar = "z" })
            end
            table.insert(lines, ii .. string.format("local timeout = %s", FormatNum(entry.timeout or 5000)))
            table.insert(lines, ii .. GenerateShapeCall(entry, "x, y, z", headVar, entry.delay or 0))
        end

        table.insert(lines, bi .. "end")
    end

    if isRegister then
        table.insert(lines, "end)")
    end

    table.insert(lines, "")
    State.meGeneratedCode = table.concat(lines, "\n")
end

-- =============================================
-- 组合机制预览执行
-- =============================================
local function ExecuteComboPreview()
    if not Argus2 or not Argus2.ShapeDrawer then
        State.lastLog = "错误: Argus2 API 不可用"
        return
    end

    SyncPlayerPos()
    ClearPreviewShapes()
    local drawer = CreatePreviewDrawer()

    local x, y, z = State.posX, State.posY, State.posZ
    local headingRad = ResolveCoordHeadingPreview(State, { x = x, y = y, z = z })
    local timeout = State.timeout
    local mode = State.comboMode

    -- 执行单个步骤的预览绘图（通过分派表）
    local function previewStep(step, px, py, pz, hRad, del)
        local fn = PreviewTimedCoord[step.shapeId]
        if not fn then return end
        local uuid = fn(drawer, timeout, px, py, pz, hRad, math.rad(step.angle or 90), step, del)
        if uuid then table.insert(State.previewUUIDs, uuid) end
    end

    if mode == 1 then
        -- 循环前进
        local loopShape = ShapeDefinitions[State.loopShapeIndex]
        if loopShape and TensorCore and TensorCore.getPosInDirection then
            local step = {
                shapeId = loopShape.id, radius = State.radius,
                radiusInner = State.radiusInner, radiusOuter = State.radiusOuter,
                length = State.length, width = State.width, angle = State.angle,
                thickness = State.thickness, baseLength = State.baseLength,
                baseWidth = State.baseWidth, tipLength = State.tipLength, tipWidth = State.tipWidth,
                pos2X = State.pos2X, pos2Y = State.pos2Y, pos2Z = State.pos2Z
            }
            CopyCoordHeadingState(step, State)
            for i = 0, State.loopCount - 1 do
                local pos = TensorCore.getPosInDirection({x=x, y=y, z=z}, headingRad, i * State.loopStepDist)
                local stepHeading = ShapeNeedsHeading(step.shapeId)
                    and ResolveCoordHeadingPreview(step, { x = pos.x, y = pos.y, z = pos.z }) or 0
                previewStep(step, pos.x, pos.y, pos.z, stepHeading, i * State.loopInterval)
            end
        end
    else
        -- 顺序 / 同时
        for _, step in ipairs(State.comboSteps) do
            local hRad = ShapeNeedsHeading(step.shapeId)
                and ResolveCoordHeadingPreview(step, { x = x, y = y, z = z }, 4) or 0
            local del = (mode == 2) and step.delay or 0
            previewStep(step, x, y, z, hRad, del)
        end
    end

    State.lastLog = "组合机制预览已执行"
    d("[ArgusBuilder] 组合机制预览")
end

-- =============================================
-- 主绘制函数
-- =============================================
M.DrawArgusBuilderUI = function()
    T.PushTheme()
    GUI:SetNextWindowSize(720, 700, GUI.SetCond_Appearing)
    M.ArgusBuilderUI.visible, M.ArgusBuilderUI.open = GUI:Begin("Argus Builder###ArgusBuilderWindow", M.ArgusBuilderUI.open)

    if M.ArgusBuilderUI.visible then

        if M.ArgusBuilderUI.requestedTab then
            State.activeTab = M.ArgusBuilderUI.requestedTab
            M.ArgusBuilderUI.requestedTab = nil
        end

        -- 接收 MapEffectUI 传递的数据
        if M._mapEffectTransfer then
            State.meA1 = M._mapEffectTransfer.a1 or 0
            if M._mapEffectTransfer.a3 then
                State.meA3 = M._mapEffectTransfer.a3
                State.meCheckA3 = true
            end
            if M._mapEffectTransfer.posX then
                State.posX = M._mapEffectTransfer.posX
                State.posY = M._mapEffectTransfer.posY
                State.posZ = M._mapEffectTransfer.posZ
                State.usePlayerPos = false
            end
            State.meResourcePath = M._mapEffectTransfer.resourcePath or ""
            State.meResourceType = M._mapEffectTransfer.resourceType or 0
            State.meResourceDirX = M._mapEffectTransfer.resourceDirX or 0
            State.meResourceDirY = M._mapEffectTransfer.resourceDirY or 0
            State.meResourceDirZ = M._mapEffectTransfer.resourceDirZ or 0
            if State.meResourcePath ~= "" then
                State.mePosMode = 2
            end
            State.lastLog = "已从 MapEffect 查看器接收: Index=" .. State.meA1
            M._mapEffectTransfer = nil
        end

        -- ===== 配置概览栏 =====
        do
            local shape = GetCurrentShape()
            local mt = MechanicTypes[State.mechanicType]
            local shapeName = shape and shape.name or "?"

            GUI:PushStyleColor(GUI.Col_ChildBg, 0.10, 0.10, 0.14, 0.95)
            GUI:BeginChild("##ABSummary", -1, 56, true)

            -- 第一行: [填充色块] 形状名  机制类型  尺寸参数
            local fR, fG, fB, fA = State.fillR, State.fillG, State.fillB, State.fillA
            if mt and State.mechanicType > 1 then
                fR, fG, fB, fA = mt.fill[1], mt.fill[2], mt.fill[3], mt.fill[4]
            end
            PushSolidColor(fR, fG, fB, fA)
            GUI:Button("  ##SumFill", 16, 16)
            PopSolidColor()
            GUI:SameLine(0, 6)

            GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], shapeName)
            if mt and State.mechanicType > 1 then
                GUI:SameLine(0, 8)
                GUI:TextColored(mt.fill[1], mt.fill[2], mt.fill[3], 1.0, mt.name)
            end

            -- 尺寸参数
            if shape then
                local sid = shape.id
                local p = ""
                if sid == "Circle" then p = "R=" .. FormatNum(State.radius)
                elseif sid == "Cone" then p = "R=" .. FormatNum(State.radius) .. " " .. FormatNum(State.angle) .. "°"
                elseif sid == "Rect" or sid == "CenteredRect" or sid == "Cross" then p = FormatNum(State.length) .. "x" .. FormatNum(State.width)
                elseif sid == "Donut" then p = FormatNum(State.radiusInner) .. "~" .. FormatNum(State.radiusOuter)
                elseif sid == "DonutCone" then p = FormatNum(State.radiusInner) .. "~" .. FormatNum(State.radiusOuter) .. " " .. FormatNum(State.angle) .. "°"
                elseif sid == "Arrow" then p = "L=" .. FormatNum(State.baseLength)
                elseif sid == "Chevron" then p = "L=" .. FormatNum(State.length)
                elseif sid == "Line" then p = "T=" .. FormatNum(State.thickness)
                end
                if p ~= "" then
                    GUI:SameLine(0, 12)
                    GUI:TextColored(C.accent[1], C.accent[2], C.accent[3], C.accent[4], p)
                end
            end

            -- 第二行: 模式 | 位置 | [描边色块] | 附加功能标签
            local modeStr = (State.timingMode == 1 and "Timed" or "OnFrame") .. " / " .. (State.attachMode == 1 and "坐标" or "实体")
            GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4], modeStr)
            GUI:SameLine(0, 10)

            if State.attachMode == 1 then
                GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4],
                    string.format("(%.1f, %.1f, %.1f)", State.posX, State.posY, State.posZ))
            else
                local entStr = DescribeSelectorSpec(GetSelectorSpec(State, "entity"))
                GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4], entStr)
            end

            GUI:SameLine(0, 10)
            PushSolidColor(State.outlineR, State.outlineG, State.outlineB, State.outlineA)
            GUI:Button("##SumOL", 12, 12)
            PopSolidColor()

            -- 附加功能标签
            local tags = {}
            if State.condEnabled then table.insert(tags, "条件") end
            if State.overlayTextEnabled then table.insert(tags, "文字") end
            if State.tetherEnabled then table.insert(tags, "连线") end
            if State.includeTargetHitbox or State.includeOwnHitbox then table.insert(tags, "Hitbox") end
            if #tags > 0 then
                GUI:SameLine(0, 8)
                GUI:TextColored(C.gold[1], C.gold[2], C.gold[3], C.gold[4],
                    table.concat(tags, " | "))
            end

            GUI:EndChild()
            GUI:PopStyleColor(1)
        end
        GUI:Spacing()

        -- ===== 标签页按钮 =====
        do
            local tabDefs = {
                { id = TABS.BUILDER, label = "Argus Builder" },
                { id = TABS.CODE, label = "代码" },
                { id = TABS.MAP_EFFECT, label = "MapEffect" },
                { id = TABS.ME_TRIGGER, label = "ME触发器" },
            }
            for i, tab in ipairs(tabDefs) do
                if i > 1 then GUI:SameLine(0, 2) end
                local isActive = (State.activeTab == tab.id)
                if isActive then
                    GUI:PushStyleColor(GUI.Col_Button, 0.20, 0.45, 0.80, 0.90)
                    GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.25, 0.52, 0.88, 0.95)
                    GUI:PushStyleColor(GUI.Col_ButtonActive, 0.15, 0.40, 0.75, 1.00)
                    GUI:PushStyleColor(GUI.Col_Text, 1.0, 1.0, 1.0, 1.0)
                else
                    GUI:PushStyleColor(GUI.Col_Button, 0.15, 0.15, 0.18, 0.80)
                    GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.22, 0.22, 0.28, 0.90)
                    GUI:PushStyleColor(GUI.Col_ButtonActive, 0.18, 0.18, 0.22, 1.00)
                    GUI:PushStyleColor(GUI.Col_Text, 0.6, 0.6, 0.6, 1.0)
                end
                if GUI:Button(tab.label .. "##ABTab" .. tab.id, 0, 26) then
                    State.activeTab = tab.id
                end
                GUI:PopStyleColor(4)
            end
        end
        GUI:Separator()
        GUI:Spacing()

        -- MapEffect 自动刷新
        if M.MapEffectAutoRefresh then M.MapEffectAutoRefresh() end

        -- Tab: Argus Builder
        if State.activeTab == TABS.BUILDER then
        -- =============================================
        -- 形状选择器
        -- =============================================
        T.SectionHeader("形状选择")
        T.HintText("选择要绘制的 AOE 形状类型")
        do
            local shapesPerRow = 5
            for i, sd in ipairs(ShapeDefinitions) do
                if (i - 1) % shapesPerRow ~= 0 then GUI:SameLine(0, 3) end
                local isSelected = (State.shapeIndex == i)
                if isSelected then
                    GUI:PushStyleColor(GUI.Col_Button, 0.20, 0.45, 0.80, 0.90)
                    GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.25, 0.52, 0.88, 0.95)
                    GUI:PushStyleColor(GUI.Col_ButtonActive, 0.15, 0.40, 0.75, 1.00)
                else
                    GUI:PushStyleColor(GUI.Col_Button, 0.18, 0.18, 0.22, 0.80)
                    GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.25, 0.25, 0.32, 0.90)
                    GUI:PushStyleColor(GUI.Col_ButtonActive, 0.20, 0.20, 0.25, 1.00)
                end
                if GUI:Button(sd.name .. "##ShpBtn" .. i, 0, 24) then
                    State.shapeIndex = i
                    State.generatedCode = ""
                end
                GUI:PopStyleColor(3)
            end
        end

        local shape = GetCurrentShape()

        -- =============================================
        -- 机制类型 - 自动设置对应颜色
        -- =============================================
        GUI:Spacing()
        GUI:PushItemWidth(160)
        local newMT = GUI:Combo("机制类型##ArgusMT", State.mechanicType, MechanicTypeNames)
        GUI:PopItemWidth()
        ItemTooltip("选择机制语义类型，自动应用对应的填充和描边颜色\n危险=红 安全=绿 分摊=橙 凝视=紫 击退=青 信息=蓝")
        if newMT ~= State.mechanicType then
            ApplyMechanicColor(newMT)
        end
        -- 机制类型颜色预览色块
        if State.mechanicType > 1 then
            local mt = MechanicTypes[State.mechanicType]
            if mt then
                GUI:SameLine(0, 8)
                PushSolidColor(mt.fill[1], mt.fill[2], mt.fill[3], mt.fill[4])
                GUI:Button("  ##MTPreview", 20, 20)
                PopSolidColor()
                GUI:SameLine(0, 4)
                GUI:TextColored(mt.fill[1], mt.fill[2], mt.fill[3], 1.0, mt.name)
            end
        end

        -- =============================================
        -- 快速样式模板 (Phase 1.2)
        -- =============================================
        if GUI:CollapsingHeader("快速模板 - 一键填充常用配置##ArgusQuickTmpl") then
            GUI:Indent(5)
            local tmplPerRow = 4
            for i, tmpl in ipairs(QuickTemplates) do
                if (i - 1) % tmplPerRow ~= 0 then GUI:SameLine(0, 3) end
                local mtc = MechanicTypes[tmpl.mechanic]
                if mtc then
                    GUI:PushStyleColor(GUI.Col_Button, mtc.fill[1] * 0.7, mtc.fill[2] * 0.7, mtc.fill[3] * 0.7, 0.85)
                    GUI:PushStyleColor(GUI.Col_ButtonHovered, mtc.fill[1] * 0.9, mtc.fill[2] * 0.9, mtc.fill[3] * 0.9, 0.95)
                    GUI:PushStyleColor(GUI.Col_ButtonActive, mtc.fill[1], mtc.fill[2], mtc.fill[3], 1.0)
                end
                if GUI:Button(tmpl.name .. "##QT" .. i, 0, 22) then
                    ApplyQuickTemplate(tmpl)
                    State.lastLog = "已应用模板: " .. tmpl.name
                end
                if mtc then GUI:PopStyleColor(3) end
            end
            GUI:Unindent(5)
        end

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 绘图模式
        -- =============================================
        T.SectionHeader("绘图模式")

        GUI:PushItemWidth(200)
        State.apiLevel = GUI:Combo("API 层级##ArgusApi", State.apiLevel, ApiLevelNames)
        ItemTooltip("Argus2: 推荐，功能最全\nShapeDrawer: 基础绘图\nStaticDrawer: 仅支持 OnFrame 瞬时绘图")
        if State.apiLevel == 3 then
            T.HintText("  StaticDrawer 仅支持 OnFrame，不支持 Timed")
            State.timingMode = 2
        end
        State.timingMode = GUI:Combo("时机类型##ArgusTiming", State.timingMode, TimingModeNames)
        ItemTooltip("Timed: 绘制持续指定毫秒后消失\nOnFrame: 每帧绘制，需放在循环中")
        State.attachMode = GUI:Combo("附着方式##ArgusAttach", State.attachMode, AttachModeNames)
        ItemTooltip("坐标: 在固定世界坐标绘制\nOnEnt: 跟随指定实体移动")
        GUI:PopItemWidth()

        -- OnEnt 参数
        if State.attachMode == 2 then
            GUI:Indent(10)
            GUI:Spacing()
            GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "实体附着参数")

            GUI:PushItemWidth(180)
            State.entityResolveMode = GUI:Combo("附着实体来源##ArgusEntityMode", State.entityResolveMode, EntityResolveModeNames, #EntityResolveModeNames)
            GUI:PopItemWidth()
            if State.entityResolveMode == 2 then
                GUI:PushItemWidth(150)
                State.entityID = GUI:InputInt("实体 ContentID##ArgusEntID", State.entityID)
                GUI:PopItemWidth()
                ItemTooltip("通过 ContentID 查找附着实体")
            elseif State.entityResolveMode == 3 then
                State.entityName = GUI:InputText("实体名称##ArgusEntName", State.entityName)
                ItemTooltip("通过名称查找附着实体，底层使用 Named Target")
            elseif State.entityResolveMode == 4 then
                State.entityFilter = GUI:InputText("实体过滤串##ArgusEntFilter", State.entityFilter)
                ItemTooltip("直接传给 TensorCore.entityList / EntityList，例如 alive,contentid=14383")
            else
                T.HintText("附着到玩家自身")
            end

            if State.entityResolveMode ~= 1 then
                State.renderAllEntities = GUI:Checkbox("所有匹配实体都绘制##ArgusRenderAll", State.renderAllEntities)
                ItemTooltip("勾选后会对所有匹配实体绘制，否则只取第一个匹配实体")
                State.entityRequireVisible = GUI:Checkbox("仅可见实体##ArgusEntVisible", State.entityRequireVisible)
                GUI:SameLine(0, 10)
                State.entityRequireTargetable = GUI:Checkbox("仅可选中实体##ArgusEntTargetable", State.entityRequireTargetable)
            end

            GUI:Spacing()
            GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "目标引用参数")
            GUI:PushItemWidth(180)
            State.targetResolveMode = GUI:Combo("目标来源##ArgusTargetMode", State.targetResolveMode, TargetResolveModeNames, #TargetResolveModeNames)
            GUI:PopItemWidth()

            if State.targetResolveMode == 3 then
                GUI:PushItemWidth(150)
                State.targetID = GUI:InputInt("目标 ContentID##ArgusTgtID", State.targetID)
                GUI:PopItemWidth()
            elseif State.targetResolveMode == 4 then
                State.targetName = GUI:InputText("目标名称##ArgusTgtName", State.targetName)
            elseif State.targetResolveMode == 5 then
                State.targetFilter = GUI:InputText("目标过滤串##ArgusTgtFilter", State.targetFilter)
            end

            if State.targetResolveMode ~= 1 then
                State.targetRequireVisible = GUI:Checkbox("目标仅可见##ArgusTgtVisible", State.targetRequireVisible)
                GUI:SameLine(0, 10)
                State.targetRequireTargetable = GUI:Checkbox("目标仅可选中##ArgusTgtTargetable", State.targetRequireTargetable)
            end

            SyncLegacyTargetSelectorFlags()

            GUI:Unindent(10)
        end

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 位置与时间
        -- =============================================
        T.SectionHeader("位置与时间")

        if State.timingMode == 1 then
            GUI:PushItemWidth(150)
            State.timeout = GUI:InputInt("持续时间 (毫秒)##ArgusTimeout", State.timeout)
            GUI:PopItemWidth()
            if State.timeout < 100 then State.timeout = 100 end
        end

        if State.attachMode == 1 then
            State.usePlayerPos = GUI:Checkbox("使用玩家当前位置##ArgusPlayerPos", State.usePlayerPos)
            ItemTooltip("自动读取角色当前坐标填入")
            GUI:SameLine(0, 10)
            State.followPlayerPos = GUI:Checkbox("跟随玩家##ArgusFollowPos", State.followPlayerPos)
            ItemTooltip("生成代码使用 Player.pos 动态坐标，绘图跟随角色移动")
            if State.usePlayerPos then
                SyncPlayerPos()
                GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4],
                    string.format("  坐标: X=%.1f  Y=%.1f  Z=%.1f", State.posX, State.posY, State.posZ))
            else
                GUI:PushItemWidth(100)
                State.posX = GUI:InputFloat("X##ArgusX", State.posX, 1, 10)
                GUI:SameLine()
                State.posY = GUI:InputFloat("Y##ArgusY", State.posY, 1, 10)
                GUI:SameLine()
                State.posZ = GUI:InputFloat("Z##ArgusZ", State.posZ, 1, 10)
                GUI:PopItemWidth()
            end

            -- Line 终点
            if shape.id == "Line" then
                GUI:Spacing()
                GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "线条终点:")
                GUI:PushItemWidth(100)
                State.pos2X = GUI:InputFloat("X2##ArgusX2", State.pos2X, 1, 10)
                GUI:SameLine()
                State.pos2Y = GUI:InputFloat("Y2##ArgusY2", State.pos2Y, 1, 10)
                GUI:SameLine()
                State.pos2Z = GUI:InputFloat("Z2##ArgusZ2", State.pos2Z, 1, 10)
                GUI:PopItemWidth()
            end
        end

        -- 坐标变换工具 (Phase 4)
        if GUI:CollapsingHeader("坐标变换 - 旋转/镜像当前坐标##ArgusTransform") then
            GUI:Indent(5)
            GUI:PushItemWidth(100)
            State.transformCenterX = GUI:InputFloat("旋转中心X##ArgusTCX", State.transformCenterX, 1, 10)
            GUI:SameLine()
            State.transformCenterZ = GUI:InputFloat("旋转中心Z##ArgusTCZ", State.transformCenterZ, 1, 10)
            GUI:PopItemWidth()
            GUI:SameLine(0, 5)
            if GUI:Button("场地中心##ArgusTCReset", 0, 20) then
                State.transformCenterX = 100
                State.transformCenterZ = 100
            end
            GUI:PushItemWidth(120)
            State.transformAngle = GUI:SliderFloat("旋转角度##ArgusTAngle", State.transformAngle, -360, 360)
            GUI:PopItemWidth()

            -- 快捷角度按钮
            local angles = { 45, 90, 135, 180 }
            for i, a in ipairs(angles) do
                if i > 1 then GUI:SameLine(0, 3) end
                if GUI:Button(a .. "°##TRA" .. i, 40, 20) then
                    State.transformAngle = a
                end
            end

            GUI:Spacing()
            T.PushBtn(C.btnPrimary)
            if GUI:Button("应用旋转##ArgusTApply", 0, 24) then
                local rad = math.rad(State.transformAngle)
                local cx, cz = State.transformCenterX, State.transformCenterZ
                local dx, dz = State.posX - cx, State.posZ - cz
                State.posX = cx + dx * math.cos(rad) - dz * math.sin(rad)
                State.posZ = cz + dx * math.sin(rad) + dz * math.cos(rad)
                -- 同时旋转朝向
                if State.headingSource == 4 then
                    State.heading = State.heading + State.transformAngle
                end
                State.generatedCode = ""
                State.lastLog = string.format("坐标已旋转 %s°", FormatNum(State.transformAngle))
            end
            T.PopBtn()
            GUI:SameLine(0, 5)
            if GUI:Button("镜像X##ArgusTMirrorX", 0, 24) then
                State.posX = 2 * State.transformCenterX - State.posX
                if State.headingSource == 4 then
                    State.heading = -State.heading
                end
                State.generatedCode = ""
                State.lastLog = "坐标已X轴镜像"
            end
            GUI:SameLine(0, 3)
            if GUI:Button("镜像Z##ArgusTMirrorZ", 0, 24) then
                State.posZ = 2 * State.transformCenterZ - State.posZ
                if State.headingSource == 4 then
                    State.heading = 180 - State.heading
                end
                State.generatedCode = ""
                State.lastLog = "坐标已Z轴镜像"
            end

            T.HintText("旋转/镜像当前坐标，用于生成对称机制的多个位置")
            GUI:Unindent(5)
        end

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 形状参数（动态）
        -- =============================================
        T.SectionHeader("形状参数")

        local sid = shape.id
        GUI:PushItemWidth(150)

        if sid == "Circle" then
            State.radius = GUI:SliderFloat("半径##ArgusR", State.radius, 0.5, 50)
        elseif sid == "Cone" then
            State.radius = GUI:SliderFloat("半径##ArgusR", State.radius, 0.5, 50)
            State.angle = GUI:SliderFloat("扇形角度 (度)##ArgusAngle", State.angle, 1, 360)
            GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4], "  提示: 角度为扇形的半角宽度")
        elseif sid == "Rect" then
            State.length = GUI:SliderFloat("长度##ArgusLen", State.length, 0.5, 60)
            State.width = GUI:SliderFloat("宽度##ArgusWid", State.width, 0.5, 30)
        elseif sid == "CenteredRect" then
            State.length = GUI:SliderFloat("长度##ArgusLen", State.length, 0.5, 60)
            State.width = GUI:SliderFloat("宽度##ArgusWid", State.width, 0.5, 30)
            GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4], "  提示: 与普通矩形不同，居中矩形以中心为原点")
        elseif sid == "Donut" then
            State.radiusInner = GUI:SliderFloat("内径##ArgusRI", State.radiusInner, 0.5, 40)
            State.radiusOuter = GUI:SliderFloat("外径##ArgusRO", State.radiusOuter, 1, 50)
            if State.radiusOuter <= State.radiusInner then
                State.radiusOuter = State.radiusInner + 1
            end
        elseif sid == "DonutCone" then
            State.radiusInner = GUI:SliderFloat("内径##ArgusRI", State.radiusInner, 0.5, 40)
            State.radiusOuter = GUI:SliderFloat("外径##ArgusRO", State.radiusOuter, 1, 50)
            State.angle = GUI:SliderFloat("扇形角度 (度)##ArgusAngle", State.angle, 1, 360)
            if State.radiusOuter <= State.radiusInner then
                State.radiusOuter = State.radiusInner + 1
            end
        elseif sid == "Cross" then
            State.length = GUI:SliderFloat("长度##ArgusLen", State.length, 0.5, 60)
            State.width = GUI:SliderFloat("宽度##ArgusWid", State.width, 0.5, 15)
        elseif sid == "Arrow" then
            State.baseLength = GUI:SliderFloat("箭身长度##ArgusBL", State.baseLength, 0.5, 30)
            State.baseWidth = GUI:SliderFloat("箭身宽度##ArgusBW", State.baseWidth, 0.5, 15)
            State.tipLength = GUI:SliderFloat("箭头长度##ArgusTL", State.tipLength, 0.5, 15)
            State.tipWidth = GUI:SliderFloat("箭头宽度##ArgusTW", State.tipWidth, 0.5, 10)
        elseif sid == "Chevron" then
            State.length = GUI:SliderFloat("长度##ArgusLen", State.length, 0.5, 30)
            State.thickness = GUI:SliderFloat("厚度##ArgusThick", State.thickness, 0.5, 10)
        elseif sid == "Line" then
            State.thickness = GUI:SliderFloat("线条粗细##ArgusThick", State.thickness, 0.5, 10)
        end

        -- 朝向设置（Circle, Donut, Line 不需要朝向）
        local needsHeading = ShapeNeedsHeading(sid)
        if needsHeading then
            GUI:Spacing()

            -- 朝向来源下拉菜单
            GUI:PushItemWidth(180)
            local hsChanged
            State.headingSource, hsChanged = GUI:Combo("朝向来源##ArgusHS", State.headingSource, HeadingSourceNames, #HeadingSourceNames)
            GUI:PopItemWidth()

            -- "实体/资源朝向" 仅 OnEnt / MapEffect 资源可用，普通坐标模式自动回退
            if State.headingSource == 2 and State.attachMode ~= 2 then
                GUI:SameLine(0, 5)
                GUI:TextColored(1, 0.8, 0.2, 1, "(普通坐标下回退固定角度；MapEffect 特效位置可用资源朝向)")
            end

            -- 固定角度：显示角度滑条
            if State.headingSource == 4 then
                State.heading = GUI:SliderFloat("固定朝向 (度)##ArgusHeading", State.heading, -180, 180)
            else
                -- 非固定角度模式：显示当前朝向来源的实时角度
                SyncPlayerPos()
                GUI:SameLine(0, 10)
                local srcLabel = HeadingSourceNames[State.headingSource] or "?"
                local previewHeadingDeg = math.deg(ResolveCoordHeadingPreview(State, {
                    x = State.posX,
                    y = State.posY,
                    z = State.posZ,
                }, 1))
                GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4],
                    string.format("(%s  当前: %s°  偏移: %s°)", srcLabel, FormatNum(previewHeadingDeg), FormatNum(State.quickDirOffset)))
            end

            if State.headingSource == 5 then
                GUI:Spacing()
                GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4], "朝向目标点")
                GUI:PushItemWidth(110)
                State.headingTargetX = GUI:InputFloat("目标 X##HeadingTargetX", State.headingTargetX, 0, 0)
                GUI:SameLine(0, 6)
                State.headingTargetY = GUI:InputFloat("Y##HeadingTargetY", State.headingTargetY, 0, 0)
                GUI:SameLine(0, 6)
                State.headingTargetZ = GUI:InputFloat("Z##HeadingTargetZ", State.headingTargetZ, 0, 0)
                GUI:PopItemWidth()

                if GUI:Button("用当前位置##HeadingTargetCurrent", 96, 20) then
                    State.headingTargetX = State.posX
                    State.headingTargetY = State.posY
                    State.headingTargetZ = State.posZ
                end
                GUI:SameLine(0, 6)
                if GUI:Button("用当前目标##HeadingTargetTarget", 96, 20) then
                    local tgt = Player and Player.GetTarget and Player:GetTarget()
                    if tgt and tgt.pos then
                        State.headingTargetX = tgt.pos.x or 0
                        State.headingTargetY = tgt.pos.y or 0
                        State.headingTargetZ = tgt.pos.z or 0
                    end
                end
            end

            -- 快捷方向按钮 (设置相对偏移，不改变朝向来源)
            GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4], "快捷方向:")
            GUI:SameLine(0, 5)

            local dirBtnStyle = function()
                GUI:PushStyleColor(GUI.Col_Button, 0.25, 0.55, 0.80, 0.85)
                GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.35, 0.65, 0.90, 0.95)
                GUI:PushStyleColor(GUI.Col_ButtonActive, 0.20, 0.45, 0.70, 1.0)
            end

            dirBtnStyle()
            if GUI:Button("前##HDir", 30, 20) then State.quickDirOffset = 0 end
            GUI:PopStyleColor(3)

            GUI:SameLine(0, 3)
            dirBtnStyle()
            if GUI:Button("后##HDir", 30, 20) then State.quickDirOffset = 180 end
            GUI:PopStyleColor(3)

            GUI:SameLine(0, 3)
            dirBtnStyle()
            if GUI:Button("左##HDir", 30, 20) then State.quickDirOffset = -90 end
            GUI:PopStyleColor(3)

            GUI:SameLine(0, 3)
            dirBtnStyle()
            if GUI:Button("右##HDir", 30, 20) then State.quickDirOffset = 90 end
            GUI:PopStyleColor(3)

            -- 自定义偏移输入 (正=右偏, 负=左偏)
            GUI:SameLine(0, 10)
            GUI:PushItemWidth(80)
            State.quickDirOffset = GUI:InputFloat("偏移##HOffsetVal", State.quickDirOffset, 0, 0)
            GUI:PopItemWidth()
            GUI:SameLine(0, 5)
            GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4], "(+右 -左)")
        end

        GUI:PopItemWidth()

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 颜色设置
        -- =============================================
        do
            T.SectionHeader("颜色设置")
            -- 当前颜色预览 (填充+描边色块)
            GUI:SameLine(0, 10)
            -- 填充色块
            PushSolidColor(State.fillR, State.fillG, State.fillB, State.fillA)
            GUI:Button("  ##FillPrev", 30, 14)
            PopSolidColor()
            GUI:SameLine(0, 2)
            GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4], "填充")
            GUI:SameLine(0, 6)
            -- 描边色块
            PushSolidColor(State.outlineR, State.outlineG, State.outlineB, State.outlineA)
            GUI:Button("  ##OLPrev", 30, 14)
            PopSolidColor()
            GUI:SameLine(0, 2)
            GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4], "描边")
            if State.useMoogleDrawer then
                GUI:SameLine(0, 10)
                GUI:TextColored(C.gold[1], C.gold[2], C.gold[3], C.gold[4], "(MoogleDrawer)")
            elseif State.useGradient then
                GUI:SameLine(0, 10)
                GUI:TextColored(C.gold[1], C.gold[2], C.gold[3], C.gold[4], "(渐变)")
            end
        end
        GUI:Spacing()

            State.useMoogleDrawer = GUI:Checkbox("使用预设配色 (MoogleDrawer)##ArgusMoogle", State.useMoogleDrawer)
            ItemTooltip("使用 TensorCore 内置的蓝紫渐变配色方案\n勾选后忽略下方手动颜色设置")

            if not State.useMoogleDrawer then
                GUI:Spacing()

                -- 机制类型快速配色按钮
                GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "机制配色:")
                GUI:SameLine(0, 5)
                for mi = 2, #MechanicTypes do
                    local mtd = MechanicTypes[mi]
                    if mi > 2 then GUI:SameLine(0, 2) end
                    GUI:PushStyleColor(GUI.Col_Button, mtd.fill[1], mtd.fill[2], mtd.fill[3], 0.85)
                    GUI:PushStyleColor(GUI.Col_ButtonHovered, mtd.outline[1], mtd.outline[2], mtd.outline[3], 0.95)
                    GUI:PushStyleColor(GUI.Col_ButtonActive, mtd.outline[1], mtd.outline[2], mtd.outline[3], 1.0)
                    if GUI:Button(mtd.name .. "##MCBtn" .. mi, 0, 20) then
                        ApplyMechanicColor(mi)
                    end
                    GUI:PopStyleColor(3)
                end
                GUI:Spacing()

                State.useGradient = GUI:Checkbox("启用渐变色##ArgusGrad", State.useGradient)
                ItemTooltip("开启后可设置起始/中间/结束三色渐变\n仅 Argus2 API 支持")

                if State.useGradient then
                    -- === 渐变色模式 ===
                    GUI:Indent(10)
                    GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "起始颜色:")
                    DrawColorSection("起始", "startR", "startG", "startB", "startA")

                    GUI:Spacing()

                    GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "中间颜色:")
                    DrawColorSection("中间", "midR", "midG", "midB", "midA")

                    GUI:Spacing()

                    GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "结束颜色:")
                    DrawColorSection("结束", "endR", "endG", "endB", "endA")
                    GUI:Unindent(10)
                else
                    -- === 单一填充色模式 ===
                    GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "填充颜色:")
                    DrawColorSection("填充", "fillR", "fillG", "fillB", "fillA")
                end

                GUI:Spacing()

                -- 描边颜色（始终显示）
                GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "描边颜色:")
                DrawColorSection("描边", "outlineR", "outlineG", "outlineB", "outlineA")
                GUI:PushItemWidth(150)
                State.outlineThickness = GUI:SliderFloat("描边粗细##ArgusOT", State.outlineThickness, 0.5, 5)
                GUI:PopItemWidth()
            else
                T.HintText("当前使用 TensorCore 预设蓝紫渐变配色")
            end

        GUI:Spacing()
        GUI:Separator()

        -- 高级参数
        if GUI:CollapsingHeader("高级参数 - 延迟/旧绘图/AOE检测/Hitbox##ArgusAdvanced") then
            GUI:Indent(5)

            GUI:PushItemWidth(150)
            State.delay = GUI:InputInt("延迟显示 (毫秒)##ArgusDelay", State.delay)
            if State.delay < 0 then State.delay = 0 end
            GUI:PopItemWidth()

            State.oldDraw = GUI:Checkbox("旧绘图模式 (oldDraw)##ArgusOld", State.oldDraw)
            ItemTooltip("启用后绘图会覆盖在模型之上")

            State.doNotDetect = GUI:Checkbox("不参与 AOE 检测 (doNotDetect)##ArgusDND", State.doNotDetect)
            ItemTooltip("启用后此绘图不会被 Argus 的 AOE 检测系统识别")

            if State.apiLevel == 1 and State.useGradient then
                GUI:PushItemWidth(150)
                State.gradientIntensity = GUI:SliderInt("渐变强度##ArgusGI", State.gradientIntensity, 0, 10)
                State.gradientMinOpacity = GUI:SliderFloat("最小不透明度##ArgusGMO", State.gradientMinOpacity, 0, 1)
                GUI:PopItemWidth()
            end

            if State.attachMode == 2 then
                GUI:Spacing()
                GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "OnEnt 高级:")
                GUI:PushItemWidth(150)
                State.headingOffset = GUI:SliderFloat("朝向偏移 (度)##ArgusHO", State.headingOffset, -180, 180)
                GUI:PopItemWidth()
                State.offsetIsAbsolute = GUI:Checkbox("偏移为绝对值##ArgusOIA", State.offsetIsAbsolute)
            end

            -- Hitbox (Phase 6)
            GUI:Spacing()
            GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "Hitbox 补偿:")
            State.includeTargetHitbox = GUI:Checkbox("加算目标 Hitbox 半径##ArgusHTgt", State.includeTargetHitbox)
            ItemTooltip("生成代码时在半径上加入目标实体的 hitbox 半径\n(类似 Splatoon 的 includeHitbox)")
            State.includeOwnHitbox = GUI:Checkbox("加算自身 Hitbox 半径##ArgusHOwn", State.includeOwnHitbox)
            ItemTooltip("生成代码时在半径上加入自身的 hitbox 半径")

            GUI:Unindent(5)
        end

        -- Overlay Text (Phase 2)
        if GUI:CollapsingHeader("悬浮文字 - 在坐标上方显示提示文字##ArgusOverlay") then
            GUI:Indent(5)
            State.overlayTextEnabled = GUI:Checkbox("启用悬浮文字##ArgusOTEn", State.overlayTextEnabled)
            if State.overlayTextEnabled then
                GUI:PushItemWidth(200)
                State.overlayText = GUI:InputText("文字内容##ArgusOTText", State.overlayText)
                GUI:PopItemWidth()
                GUI:PushItemWidth(120)
                State.overlayVOffset = GUI:SliderFloat("垂直偏移##ArgusOTVOff", State.overlayVOffset, 0, 10)
                State.overlayFontScale = GUI:SliderFloat("字体缩放##ArgusOTFont", State.overlayFontScale, 0.5, 3.0)
                GUI:PopItemWidth()
                T.HintText("使用 AnyoneCore.addTimedWorldText 在坐标上方显示文字")
                T.HintText("颜色固定为白色 (0xFFFFFFFF)，可在生成代码中手动修改")
            end
            GUI:Unindent(5)
        end

        -- Tether (Phase 2)
        if GUI:CollapsingHeader("连线 - 两点之间画线##ArgusTether") then
            GUI:Indent(5)
            State.tetherEnabled = GUI:Checkbox("启用连线##ArgusTEn", State.tetherEnabled)
            if State.tetherEnabled then
                local tetherModeNames = { "玩家 -> 坐标", "实体 -> 实体 (模板)" }
                GUI:PushItemWidth(160)
                State.tetherMode = GUI:Combo("连线模式##ArgusTMode", State.tetherMode, tetherModeNames)
                GUI:PopItemWidth()
                if State.tetherMode == 1 then
                    T.HintText("使用 drawer:addTimedLine 从玩家位置连线到当前坐标")
                else
                    T.HintText("生成模板代码，需手动修改实体ID和目标坐标")
                end
                T.HintText("连线粗细使用上方 Line 形状的「线条粗细」参数，当前: " .. FormatNum(State.thickness > 0 and State.thickness or 2))
            end
            GUI:Unindent(5)
        end

        elseif State.activeTab == TABS.CODE then

        -- =============================================
        -- 代码生成工具栏
        -- =============================================
        T.SubHeader("代码操作")
        GUI:Spacing()
        do
            -- 生成 + 复制 + 预览 + 运行 + 清除
            T.PushBtn(C.btnPrimary)
            if GUI:Button("生成##ArgusGen", 60, 28) then
                SyncPlayerPos()
                GenerateCode()
                State.lastLog = "代码已生成"
            end
            T.PopBtn()
            GUI:SameLine(0, 3)
            T.PushBtn(C.btnRun)
            if GUI:Button("复制##ArgusCopy", 50, 28) then
                if State.generatedCode == "" then SyncPlayerPos(); GenerateCode() end
                CopyToClipboard(State.generatedCode)
            end
            T.PopBtn()
            GUI:SameLine(0, 3)
            T.PushBtn(C.btnSend)
            if GUI:Button("预览##ArgusPreview", 50, 28) then
                SyncPlayerPos()
                ExecutePreview()
            end
            T.PopBtn()
            GUI:SameLine(0, 3)
            if DrawRunBtn("运行##ArgusRun", 50, 28) then
                if State.generatedCode == "" then SyncPlayerPos(); GenerateCode() end
                ExecuteCodeString(State.generatedCode)
            end
            GUI:SameLine(0, 3)
            T.PushBtn(C.btnStop)
            if GUI:Button("清除##ArgusClear", 50, 28) then
                ClearPreviewShapes()
                if Argus and Argus.deleteTimedShape then Argus.deleteTimedShape() end
                State.lastLog = "已清除所有绘图"
            end
            T.PopBtn()

            -- 状态显示 (同行)
            if State.lastLog ~= "" then
                GUI:SameLine(0, 10)
                T.SuccessText(State.lastLog)
            end
        end

        -- 运行错误信息
        if State.lastRunError ~= "" then
            GUI:TextColored(1.0, 0.3, 0.3, 1.0, State.lastRunError)
        end

        -- 代码编辑器
        if State.generatedCode ~= "" then
            GUI:Spacing()
            local newCode, changed = DrawCodeTextbox("##ABCodeOut", State.generatedCode)
            if changed then State.generatedCode = newCode end
        else
            T.HintText("点击「生成代码」按钮生成 Lua 代码")
        end

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 触发条件
        -- =============================================
        if GUI:CollapsingHeader("触发条件 - 用 if 包裹生成代码##ArgusCond") then
            GUI:Indent(5)

            State.condEnabled = GUI:Checkbox("启用条件包装##ArgusCondEn", State.condEnabled)
            ItemTooltip("启用后生成的绘图代码会被 if 条件语句包裹\n只有满足条件时才执行绘图")

            if State.condEnabled then
                GUI:Spacing()

                -- Zone Lock
                State.condZoneEnabled = GUI:Checkbox("副本锁定 (ZoneID)##ArgusCondZone", State.condZoneEnabled)
                if State.condZoneEnabled then
                    GUI:SameLine(0, 10)
                    GUI:PushItemWidth(100)
                    State.condZoneID = GUI:InputInt("##ArgusCondZoneID", State.condZoneID)
                    GUI:PopItemWidth()
                    GUI:SameLine(0, 5)
                    if Player and Player.localmapid then
                        if GUI:Button("当前副本##ArgusCondZoneCur", 0, 20) then
                            State.condZoneID = Player.localmapid
                        end
                    end
                end

                -- Job Lock
                State.condJobEnabled = GUI:Checkbox("职业锁定 (JobID)##ArgusCondJob", State.condJobEnabled)
                if State.condJobEnabled then
                    GUI:SameLine(0, 10)
                    GUI:PushItemWidth(100)
                    State.condJobID = GUI:InputInt("##ArgusCondJobID", State.condJobID)
                    GUI:PopItemWidth()
                    GUI:SameLine(0, 5)
                    if Player and Player.job then
                        if GUI:Button("当前职业##ArgusCondJobCur", 0, 20) then
                            State.condJobID = Player.job
                        end
                    end
                end

                GUI:Spacing()

                -- Buff Check
                State.condBuffEnabled = GUI:Checkbox("Buff 条件##ArgusCondBuff", State.condBuffEnabled)
                if State.condBuffEnabled then
                    GUI:Indent(10)
                    GUI:PushItemWidth(200)
                    State.condBuffIDs = GUI:InputText("Buff IDs (逗号分隔)##ArgusCondBuffIDs", State.condBuffIDs)
                    GUI:PopItemWidth()
                    local logicNames = { "OR (任一)", "AND (全部)" }
                    GUI:PushItemWidth(120)
                    State.condBuffLogic = GUI:Combo("逻辑##ArgusCondBuffLogic", State.condBuffLogic, logicNames)
                    GUI:PopItemWidth()
                    GUI:Unindent(10)
                end

                -- Cast Check
                State.condCastEnabled = GUI:Checkbox("读条检测 (CastID)##ArgusCondCast", State.condCastEnabled)
                if State.condCastEnabled then
                    GUI:Indent(10)
                    GUI:PushItemWidth(200)
                    State.condCastIDs = GUI:InputText("Cast IDs (逗号分隔)##ArgusCondCastIDs", State.condCastIDs)
                    GUI:PopItemWidth()
                    T.HintText("检测 80 米内是否有怪物正在读此技能")
                    GUI:Unindent(10)
                end

                -- Distance Check
                State.condDistEnabled = GUI:Checkbox("距离条件##ArgusCondDist", State.condDistEnabled)
                if State.condDistEnabled then
                    GUI:Indent(10)
                    GUI:PushItemWidth(100)
                    State.condDistMin = GUI:InputFloat("最小距离##ArgusCondDistMin", State.condDistMin, 0, 0)
                    State.condDistMax = GUI:InputFloat("最大距离##ArgusCondDistMax", State.condDistMax, 0, 0)
                    GUI:PopItemWidth()
                    T.HintText("与当前目标的距离范围")
                    GUI:Unindent(10)
                end
            end

            GUI:Unindent(5)
        end

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- 组合机制 - 多形状组合绘制
        if GUI:CollapsingHeader("组合机制 - 多形状批量绘制##ArgusCombo") then
            GUI:Indent(5)

            -- 模式选择
            GUI:PushItemWidth(200)
            State.comboMode = GUI:Combo("组合模式##ArgusComboMode", State.comboMode, ComboModeNames)
            GUI:PopItemWidth()

            GUI:Spacing()

            if State.comboMode == 1 then
                -- === 循环前进 (地火) ===
                GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "循环前进参数:")
                GUI:Spacing()

                GUI:PushItemWidth(200)
                State.loopShapeIndex = GUI:Combo("循环形状##ArgusLoopShape", State.loopShapeIndex, ShapeDisplayNames)
                GUI:PopItemWidth()

                GUI:PushItemWidth(150)
                State.loopCount = GUI:SliderInt("循环次数##ArgusLoopCount", State.loopCount, 1, 20)
                State.loopStepDist = GUI:SliderFloat("步进距离 (米)##ArgusLoopDist", State.loopStepDist, 0.5, 30)
                State.loopInterval = GUI:InputInt("间隔延迟 (毫秒)##ArgusLoopInterval", State.loopInterval)
                if State.loopInterval < 0 then State.loopInterval = 0 end
                GUI:PopItemWidth()

                GUI:Spacing()
                GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4],
                    "  以当前位置和朝向为起点，沿朝向方向每隔指定距离绘制")
                GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4],
                    "  形状参数使用上方「形状参数」区域的当前值")

            else
                -- === 顺序执行 / 同时执行 ===
                local modeName = (State.comboMode == 2) and "顺序执行" or "同时执行"
                GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], modeName .. " 步骤列表:")
                GUI:Spacing()

                -- 添加步骤按钮
                T.PushBtn(C.btnRun)
                if GUI:Button("添加当前形状##ArgusComboAdd", 130, 22) then
                    local step = SnapshotCurrentStep(0)
                    if step then
                        table.insert(State.comboSteps, step)
                        State.lastLog = "已添加步骤: " .. step.shapeName
                    end
                end
                T.PopBtn()
                GUI:SameLine(0, 6)
                T.PushBtn(C.btnStop)
                if GUI:Button("清空##ArgusComboClear", 55, 22) then
                    State.comboSteps = {}
                    State.lastLog = "已清空所有步骤"
                end
                T.PopBtn()

                GUI:Spacing()

                -- 步骤列表显示
                if #State.comboSteps == 0 then
                    GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4],
                        "  还没有步骤。在上方设置好形状参数后点「添加当前形状为步骤」")
                else
                    local removeIdx = nil
                    for i, step in ipairs(State.comboSteps) do
                        -- 步骤摘要
                        local summary = string.format("%d. %s", i, step.shapeName)
                        local sid = step.shapeId
                        if sid == "Circle" then
                            summary = summary .. string.format(" R=%.1f", step.radius)
                        elseif sid == "Cone" then
                            summary = summary .. string.format(" R=%.1f A=%.0f°", step.radius, step.angle)
                        elseif sid == "Rect" or sid == "CenteredRect" or sid == "Cross" then
                            summary = summary .. string.format(" L=%.1f W=%.1f", step.length, step.width)
                        elseif sid == "Donut" then
                            summary = summary .. string.format(" Ri=%.1f Ro=%.1f", step.radiusInner, step.radiusOuter)
                        elseif sid == "DonutCone" then
                            summary = summary .. string.format(" Ri=%.1f Ro=%.1f A=%.0f°", step.radiusInner, step.radiusOuter, step.angle)
                        end

                        -- 顺序模式显示延迟
                        if State.comboMode == 2 then
                            summary = summary .. string.format("  延迟=%dms", step.delay)
                        end

                        -- 朝向如果不同于主朝向则显示
                        if step.heading ~= State.heading then
                            summary = summary .. string.format("  朝向=%.0f°", step.heading)
                        end

                        GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], "  " .. summary)

                        -- 顺序模式：延迟编辑
                        if State.comboMode == 2 then
                            GUI:SameLine(0, 10)
                            GUI:PushItemWidth(80)
                            local newDelay = GUI:InputInt("##ComboDelay" .. i, step.delay)
                            if newDelay ~= step.delay then
                                step.delay = math.max(0, newDelay)
                            end
                            GUI:PopItemWidth()
                        end

                        GUI:SameLine(0, 5)
                        T.PushBtn(C.btnStop)
                        if GUI:Button("x##ComboRm" .. i, 22, 18) then
                            removeIdx = i
                        end
                        T.PopBtn()
                    end

                    if removeIdx then
                        table.remove(State.comboSteps, removeIdx)
                        State.lastLog = "已删除步骤 " .. removeIdx
                    end
                end
            end

            GUI:Spacing()
            GUI:Separator()
            GUI:Spacing()

            -- 组合操作按钮
            T.PushBtn(C.btnPrimary)
            if GUI:Button("生成##ComboGen", 65, 24) then
                SyncPlayerPos()
                GenerateComboCode()
            end
            T.PopBtn()
            GUI:SameLine(0, 4)
            T.PushBtn(C.btnRun)
            if GUI:Button("复制##ComboCopy", 55, 24) then
                if State.comboGeneratedCode == "" then SyncPlayerPos(); GenerateComboCode() end
                CopyToClipboard(State.comboGeneratedCode)
            end
            T.PopBtn()
            GUI:SameLine(0, 4)
            T.PushBtn(C.btnSend)
            if GUI:Button("预览##ComboPreview", 55, 24) then
                SyncPlayerPos()
                ExecuteComboPreview()
            end
            T.PopBtn()
            GUI:SameLine(0, 4)
            if DrawRunBtn("运行##ComboRun", 55, 24) then
                if State.comboGeneratedCode == "" then SyncPlayerPos(); GenerateComboCode() end
                ExecuteCodeString(State.comboGeneratedCode)
            end
            GUI:SameLine(0, 4)
            T.PushBtn(C.btnStop)
            if GUI:Button("清除##ComboClearPrev", 55, 24) then
                ClearPreviewShapes()
                if Argus and Argus.deleteTimedShape then Argus.deleteTimedShape() end
            end
            T.PopBtn()

            -- 运行错误信息
            if State.lastRunError ~= "" then
                GUI:TextColored(1.0, 0.3, 0.3, 1.0, State.lastRunError)
            end

            -- 组合代码编辑器
            if State.comboGeneratedCode ~= "" then
                GUI:Spacing()
                local newCode, changed = DrawCodeTextbox("##ComboCodeOut", State.comboGeneratedCode)
                if changed then State.comboGeneratedCode = newCode end
            end

            GUI:Unindent(5)
        end

        -- =============================================
        -- 导入/导出 (Phase 5)
        -- =============================================
        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()
        if GUI:CollapsingHeader("导入/导出 - 保存和分享配置##ArgusImportExport") then
            GUI:Indent(5)

            -- 导出
            T.PushBtn(C.btnPrimary)
            if GUI:Button("导出配置##ArgusExport", 0, 24) then
                State.importExportText = ExportState()
                State.lastLog = "配置已导出到下方文本框"
            end
            T.PopBtn()
            GUI:SameLine(0, 5)
            T.PushBtn(C.btnRun)
            if GUI:Button("复制导出##ArgusExportCopy", 0, 24) then
                if State.importExportText == "" then
                    State.importExportText = ExportState()
                end
                CopyToClipboard(State.importExportText)
            end
            T.PopBtn()
            GUI:SameLine(0, 5)
            T.PushBtn(C.btnSend)
            if GUI:Button("导入配置##ArgusImport", 0, 24) then
                local ok, msg = ImportState(State.importExportText)
                if ok then
                    State.lastLog = msg
                else
                    State.lastRunError = "导入失败: " .. msg
                end
            end
            T.PopBtn()

            GUI:Spacing()
            GUI:PushItemWidth(-1)
            local newIE, ieChanged = GUI:InputTextMultiline("##ArgusIEText", State.importExportText, -1, 80, GUI.InputTextFlags_AllowTabInput)
            if ieChanged then State.importExportText = newIE end
            GUI:PopItemWidth()
            T.HintText("支持两种文本格式: ARGUS{...} 配置，ARGUSSTYLE{...} 样式")

            GUI:Spacing()
            GUI:Separator()
            GUI:Spacing()

            -- 样式剪贴板
            GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "样式剪贴板 (仅颜色)")
            T.PushBtn(C.btnPrimary)
            if GUI:Button("复制样式##ArgusStyleCopy", 0, 22) then
                CopyStyle()
                State.lastLog = "样式已复制"
            end
            T.PopBtn()
            GUI:SameLine(0, 5)
            T.PushBtn(C.btnSend)
            if GUI:Button("粘贴样式##ArgusStylePaste", 0, 22) then
                PasteStyle()
                State.lastLog = "样式已粘贴"
            end
            T.PopBtn()
            GUI:SameLine(0, 5)
            T.PushBtn(C.btnPrimary)
            if GUI:Button("导出样式文本##ArgusStyleExportText", 0, 22) then
                State.importExportText = ExportStyle()
                State.lastLog = "样式文本已导出到上方文本框"
            end
            T.PopBtn()
            GUI:SameLine(0, 5)
            T.PushBtn(C.btnSend)
            if GUI:Button("导入样式文本##ArgusStyleImportText", 0, 22) then
                local ok, msg = ImportStyle(State.importExportText)
                if ok then
                    State.lastLog = msg
                else
                    State.lastRunError = "样式导入失败: " .. msg
                end
            end
            T.PopBtn()
            if State.styleClipboard then
                GUI:SameLine(0, 10)
                GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4], "(已有样式)")
            end

            GUI:Unindent(5)
        end

        -- Tab: MapEffect (特效列表 + 执行控制)
        elseif State.activeTab == TABS.MAP_EFFECT then
            if M.DrawEffectListTab then
                M.DrawEffectListTab()
            end
            GUI:Spacing()
            GUI:Separator()
            GUI:Spacing()
            if M.DrawExecControlTab then
                M.DrawExecControlTab()
            end

        elseif State.activeTab == TABS.ME_TRIGGER then

            -- 代码模式
            local meModeNames = { "TensorReactions OnMapEffect", "Argus.registerOnMapEffect" }
            GUI:PushItemWidth(280)
            State.meCodeMode = GUI:Combo("代码模式##MECodeMode", State.meCodeMode, meModeNames)
            GUI:PopItemWidth()
            if State.meCodeMode == 1 then
                T.HintText("在 TensorReactions 中新建触发器，事件类型选 OnMapEffect")
            else
                T.HintText("生成独立的 Argus.registerOnMapEffect() 注册代码")
            end

            GUI:Spacing()
            GUI:Separator()
            GUI:Spacing()

            -- 触发条件输入
            T.SubHeader("触发条件")
            GUI:PushItemWidth(100)
            State.meA1 = GUI:InputInt("Index (a1)##MEA1", State.meA1)
            GUI:SameLine(0, 10)
            State.meA3 = GUI:InputInt("Flags (a3)##MEA3", State.meA3)
            GUI:PopItemWidth()

            State.meCheckA3 = GUI:Checkbox("检查 Flags##MECheckA3", State.meCheckA3)
            ItemTooltip("不勾选则只判断 Index(a1)，忽略 Flags(a3)")

            local posModeNames = { "固定坐标", "特效资源位置", "玩家实时位置" }
            GUI:PushItemWidth(200)
            State.mePosMode = GUI:Combo("位置来源##MEPosMode", State.mePosMode, posModeNames)
            GUI:PopItemWidth()

            GUI:PushItemWidth(200)
            State.meLabel = GUI:InputText("备注##MELabel", State.meLabel)
            GUI:PopItemWidth()
            if State.meResourcePath ~= "" then
                local shortPath = string.match(State.meResourcePath, "[^/\\]+$") or State.meResourcePath
                T.HintText("当前资源: " .. shortPath .. " | type=" .. tostring(State.meResourceType or 0))
                T.HintText(string.format("方向摘要: (%.2f, %.2f, %.2f)", State.meResourceDirX or 0, State.meResourceDirY or 0, State.meResourceDirZ or 0))
            end
            GUI:Spacing()

            -- 添加/清空按钮
            T.PushBtn(C.btnRun)
            if GUI:Button("添加当前形状##MEAdd", 130, 22) then
                local entry = SnapshotMEStep()
                if entry then
                    table.insert(State.meEntries, entry)
                    State.lastLog = "已添加: a1=" .. entry.a1
                end
            end
            T.PopBtn()
            GUI:SameLine(0, 6)
            T.PushBtn(C.btnStop)
            if GUI:Button("清空##MEClear", 55, 22) then
                State.meEntries = {}
                State.meGeneratedCode = ""
            end
            T.PopBtn()
            GUI:Spacing()

            -- 条件列表
            if #State.meEntries == 0 then
                T.HintText("还没有触发条件")
                T.HintText("可在 MapEffect 查看器中点「发送到生成器」")
            else
                local removeIdx = nil
                for i, entry in ipairs(State.meEntries) do
                    local posDesc = ({"固定", "特效", "玩家"})[entry.posMode] or "?"
                    local summary = string.format("%d. [a1=%d", i, entry.a1)
                    if entry.checkA3 then summary = summary .. " a3=" .. entry.a3 end
                    summary = summary .. "] " .. entry.shapeName .. " (" .. posDesc .. ")"
                    if entry.label and entry.label ~= "" then
                        summary = summary .. " - " .. entry.label
                    end
                    if entry.resourcePath and entry.resourcePath ~= "" then
                        local shortPath = string.match(entry.resourcePath, "[^/\\]+$") or entry.resourcePath
                        summary = summary .. " <" .. shortPath .. ">"
                    end
                    GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], summary)
                    GUI:SameLine(0, 5)
                    T.PushBtn(C.btnStop)
                    if GUI:Button("x##MEDel" .. i, 22, 18) then removeIdx = i end
                    T.PopBtn()
                end
                if removeIdx then table.remove(State.meEntries, removeIdx) end
            end

            GUI:Spacing()
            GUI:Separator()
            GUI:Spacing()

            -- 生成/复制
            T.PushBtn(C.btnPrimary)
            if GUI:Button("生成代码##MEGen", 90, 24) then
                SyncPlayerPos()
                GenerateMapEffectCode()
            end
            T.PopBtn()
            GUI:SameLine(0, 6)
            T.PushBtn(C.btnRun)
            if GUI:Button("复制##MECopy", 65, 24) then
                if State.meGeneratedCode == "" then SyncPlayerPos(); GenerateMapEffectCode() end
                CopyToClipboard(State.meGeneratedCode)
            end
            T.PopBtn()
            GUI:SameLine(0, 6)
            if DrawRunBtn("运行##MERun", 55, 24) then
                if State.meGeneratedCode == "" then SyncPlayerPos(); GenerateMapEffectCode() end
                ExecuteCodeString(State.meGeneratedCode)
            end

            -- 运行错误信息
            if State.lastRunError ~= "" then
                GUI:TextColored(1.0, 0.3, 0.3, 1.0, State.lastRunError)
            end

            if State.meGeneratedCode ~= "" then
                GUI:Spacing()
                local newCode, changed = DrawCodeTextbox("##MECodeOut", State.meGeneratedCode)
                if changed then State.meGeneratedCode = newCode end
            end

        end -- activeTab

    end

    GUI:End()
    T.PopTheme()
end

d("[StringCore] ArgusBuilderUI.lua 加载完成")
