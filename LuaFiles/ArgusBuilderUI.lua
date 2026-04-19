-- =============================================
-- ArgusBuilderUI - Argus 绘图代码生成器
-- 可视化选择形状、颜色、参数，一键预览/生成代码/复制/测试
-- =============================================

local M = StringGuide
if not M then return end

local T = M.UITheme
local C = T.C

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

-- 形状名称列表（用于下拉菜单）
local ShapeDisplayNames = {}
for _, s in ipairs(ShapeDefinitions) do
    table.insert(ShapeDisplayNames, s.name)
end

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
-- 绘图模式定义
-- =============================================
local ApiLevelNames = { "ShapeDrawer (推荐)", "Argus2 底层", "StaticDrawer (OnFrame专用)" }
local TimingModeNames = { "Timed (持续时间)", "OnFrame (每帧瞬时)" }
local AttachModeNames = { "坐标固定", "OnEnt (附着实体)" }
local HeadingSourceNames = { "玩家朝向", "实体朝向 (OnEnt)", "目标朝向", "固定角度" }

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

--- 将 token 序列解析为代码生成字符串
local function BuildArgs(tokens, S, f, tgtStr)
    local parts = {}
    for _, token in ipairs(tokens) do
        if     token == "pos"     then table.insert(parts, "x, y, z")
        elseif token == "pos2"    then table.insert(parts, "x2, y2, z2")
        elseif token == "angle"   then table.insert(parts, "angle")
        elseif token == "heading" then table.insert(parts, "heading")
        elseif token == "target"  then table.insert(parts, tgtStr or "0")
        elseif token == "delay"   then table.insert(parts, f(S.delay or 0))
        else                           table.insert(parts, f(S[token]))
        end
    end
    return table.concat(parts, ", ")
end

--- 构建参数字符串（支持自定义位置/朝向/延迟变量名，用于组合机制）
local function BuildArgsCustom(tokens, step, f, posVar, headingVar, delayVal)
    local parts = {}
    for _, token in ipairs(tokens) do
        if     token == "pos"     then table.insert(parts, posVar)
        elseif token == "pos2"    then table.insert(parts, "x2, y2, z2")
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
    Cone         = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedConeOnEnt(t, e, S.radius, a, tgt, del, nil, nil, ho, hoAbs) end,
    Rect         = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedRectOnEnt(t, e, S.length, S.width, tgt, del, nil, nil, nil, ho, hoAbs) end,
    CenteredRect = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedCenteredRectOnEnt(t, e, S.length, S.width, tgt, del, nil, nil, nil, ho, hoAbs) end,
    Donut        = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedDonutOnEnt(t, e, S.radiusInner, S.radiusOuter, del) end,
    DonutCone    = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedDonutConeOnEnt(t, e, S.radiusInner, S.radiusOuter, a, tgt, del, nil, nil, ho, hoAbs) end,
    Cross        = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedCrossOnEnt(t, e, S.length, S.width, tgt, del, nil, nil, ho, hoAbs) end,
    Arrow        = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedArrowOnEnt(t, e, S.baseLength, S.baseWidth, S.tipLength, S.tipWidth, tgt, del, nil, ho, hoAbs) end,
    Chevron      = function(d, t, e, tgt, h, a, S, del, ho, hoAbs) return d:addTimedChevronOnEnt(t, e, S.length, S.thickness, tgt, del, nil, ho, hoAbs) end,
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

--- 绘制颜色选择区域（选择器 + 预设按钮）
local function DrawColorSection(label, rKey, gKey, bKey, aKey)
    DrawColorPicker(label, rKey, gKey, bKey, aKey)
    DrawPresetButtons(rKey, gKey, bKey, aKey)
end

-- =============================================
-- UI 内部状态
-- =============================================
local State = {
    -- 形状
    shapeIndex = 1,

    -- 通用参数
    timeout = 5000,
    posX = 0, posY = 0, posZ = 0,
    usePlayerPos = true,
    followPlayerPos = false,    -- 生成代码用 Player.pos.x/y/z
    headingSource = 1,      -- 1=玩家朝向, 2=实体朝向(OnEnt), 3=目标朝向, 4=固定角度
    quickDirOffset = 0,     -- 快捷方向偏移量（度），前=0 后=180 左=-90 右=+90

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
    entityID = 0,
    targetID = 0,
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
    meGeneratedCode = "",

    -- 当前标签页
    activeTab = 1,
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

local function FormatColor(r, g, b, a)
    return string.format("GUI:ColorConvertFloat4ToU32(%.2f, %.2f, %.2f, %.2f)", r, g, b, a)
end

local function FormatNum(n)
    if n == math.floor(n) then
        return tostring(math.floor(n))
    end
    return string.format("%.2f", n)
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
                table.insert(lines, "local x1, y1, z1 = Player.pos.x, Player.pos.y, Player.pos.z")
                table.insert(lines, string.format("local x2, y2, z2 = %s, %s, %s",
                    FormatNum(State.pos2X), FormatNum(State.pos2Y), FormatNum(State.pos2Z)))
            else
                table.insert(lines, "local x, y, z = Player.pos.x, Player.pos.y, Player.pos.z")
            end
        else
            -- 使用固定坐标
            if sid == "Line" then
                table.insert(lines, string.format("local x1, y1, z1 = %s, %s, %s",
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
        local offsetStr = State.quickDirOffset ~= 0
            and string.format(" + math.rad(%s)", FormatNum(State.quickDirOffset)) or ""
        if State.headingSource == 1 then
            table.insert(lines, "local heading = Player.pos.h" .. offsetStr)
        elseif State.headingSource == 3 then
            table.insert(lines, "local _tgt = Player:GetTarget()")
            table.insert(lines, "local heading = _tgt and (_tgt.pos.h" .. offsetStr .. ") or 0")
        else
            -- 固定角度（headingSource==4 或坐标模式下的实体朝向回退）
            table.insert(lines, string.format("local heading = math.rad(%s)", FormatNum(State.heading)))
        end
        table.insert(lines, "")
    end

    -- 角度（扇形类）
    local needsAngle = ShapeNeedsAngle(sid)
    if needsAngle then
        table.insert(lines, string.format("local angle = math.rad(%s)  -- %s°", FormatNum(State.angle), FormatNum(State.angle)))
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
                -- 判断是否渲染全部相同 ContentID 实体
                local renderAll = State.renderAllEntities and not State.useSelfAsEntity

                if renderAll then
                    table.insert(lines, "-- 附着实体绘图 (渲染全部相同 ContentID 实体)")
                else
                    table.insert(lines, "-- 附着实体绘图")
                end

                local entStr
                if State.useSelfAsEntity then
                    entStr = "Player.id"
                elseif renderAll then
                    -- 遍历全部实体，不 break
                    table.insert(lines, string.format("local _el = EntityList(\"contentid=%s\")", FormatNum(State.entityID)))
                    table.insert(lines, "if not _el then return end")
                    table.insert(lines, "")
                    entStr = "entID"
                else
                    -- 只取第一个实体
                    table.insert(lines, string.format("local _el = EntityList(\"contentid=%s\")", FormatNum(State.entityID)))
                    table.insert(lines, "local entID; if _el then for id, _ in pairs(_el) do entID = id; break end end")
                    table.insert(lines, "if not entID then return end")
                    table.insert(lines, "")
                    entStr = "entID"
                end

                local tgtStr
                if State.useCurrentTarget then
                    tgtStr = "Player.targetid"
                elseif State.targetID ~= 0 then
                    table.insert(lines, string.format("local _tEl = EntityList(\"contentid=%s\")", FormatNum(State.targetID)))
                    table.insert(lines, "local tgtID; if _tEl then for id, _ in pairs(_tEl) do tgtID = id; break end end")
                    table.insert(lines, "")
                    tgtStr = "tgtID or 0"
                else
                    tgtStr = "0"
                end

                -- 缩进前缀：renderAll 模式下绘图调用在 for 循环内
                local ii = renderAll and "    " or ""

                local args = FormatNum(State.timeout) .. ", " .. entStr .. ", " .. BuildArgs(ShapeParams[sid].ent, State, FormatNum, tgtStr)

                -- 附加 headingOffset / offsetIsAbsolute（基于朝向来源）
                local nilCount = (ShapeParams[sid] or {}).entNilPad
                if nilCount and needsHeading then
                    local offsetRad = math.rad(State.quickDirOffset)
                    local needsOffset = false
                    local hoStr, absStr

                    if State.headingSource == 1 then
                        -- 玩家朝向: offsetIsAbsolute=true, headingOffset=Player.pos.h+偏移
                        local oStr = State.quickDirOffset ~= 0
                            and string.format(" + math.rad(%s)", FormatNum(State.quickDirOffset)) or ""
                        hoStr = "Player.pos.h" .. oStr
                        absStr = "true"
                        needsOffset = true
                    elseif State.headingSource == 2 then
                        -- 实体朝向: offsetIsAbsolute=false (默认), headingOffset=偏移
                        if State.quickDirOffset ~= 0 then
                            hoStr = FormatNum(offsetRad)
                            needsOffset = true
                        end
                    elseif State.headingSource == 3 then
                        -- 目标朝向: 需要在前面获取目标朝向
                        table.insert(lines, "local _tgt = Player:GetTarget()")
                        local oStr = State.quickDirOffset ~= 0
                            and string.format(" + math.rad(%s)", FormatNum(State.quickDirOffset)) or ""
                        hoStr = "_tgt and _tgt.pos.h" .. oStr .. " or 0"
                        absStr = "true"
                        needsOffset = true
                    elseif State.headingSource == 4 then
                        -- 固定角度
                        hoStr = FormatNum(math.rad(State.heading))
                        absStr = "true"
                        needsOffset = true
                    end

                    if needsOffset and hoStr then
                        local nils = string.rep(", nil", nilCount)
                        args = args .. nils .. ", " .. hoStr
                        if absStr then
                            args = args .. ", " .. absStr
                        end
                    end
                end

                -- 生成绘图调用
                if renderAll then
                    table.insert(lines, "for entID, _ in pairs(_el) do")
                    table.insert(lines, ii .. "drawer:" .. methodName .. "(" .. args .. ")")
                    table.insert(lines, "end")
                else
                    table.insert(lines, "local uuid = drawer:" .. methodName .. "(" .. args .. ")")
                end
            else
                -- addTimedXxx (坐标版本)
                local methodName = "addTimed" .. sid
                table.insert(lines, "-- 持续绘图 (坐标)")
                local args = FormatNum(State.timeout) .. ", " .. BuildArgs(ShapeParams[sid].coord, State, FormatNum)

                table.insert(lines, "local uuid = drawer:" .. methodName .. "(" .. args .. ")")
            end
        else
            -- OnFrame 瞬时方法
            table.insert(lines, "-- 瞬时绘图 (仅在 OnFrame 事件中使用)")
            local frameArgs = BuildArgs(ShapeParams[sid].frame, State, FormatNum)
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
                table.insert(lines, string.format("%s(\n    %s, %s, %s,  -- timeout, x, y, z\n    %s,  -- colorStart, colorEnd\n    %s,  -- radius\n    50,  -- segments\n    %s,  -- delay\n    nil,  -- entityAttachID\n    colorOutline,  -- 描边颜色\n    %s  -- 描边粗细\n)",
                    methodName, FormatNum(State.timeout), "x", "y, z",
                    colorArgs, FormatNum(State.radius),
                    FormatNum(State.delay), FormatNum(State.outlineThickness)))
            else
                table.insert(lines, "-- 请参考 TensorCore API Reference 了解 " .. methodName .. " 的完整参数列表")
            end
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

    State.generatedCode = table.concat(lines, "\n")
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
    local headingRad = math.rad(State.heading)
    local angleRad = math.rad(State.angle)

    local isOnEnt = (State.attachMode == 2)
    local uuid

    if isOnEnt then
        -- 收集实体 ID 列表
        local entIDs = {}
        if State.useSelfAsEntity then
            table.insert(entIDs, Player.id)
        else
            local el = EntityList("contentid=" .. tostring(State.entityID))
            if el then
                if State.renderAllEntities then
                    for id, _ in pairs(el) do table.insert(entIDs, id) end
                else
                    for id, _ in pairs(el) do table.insert(entIDs, id); break end
                end
            end
            if #entIDs == 0 then
                State.lastLog = "错误: 未找到 ContentID=" .. tostring(State.entityID) .. " 的实体"
                d("[ArgusBuilder] 错误: 未找到 ContentID=" .. tostring(State.entityID))
                return
            end
        end
        local tgtID
        if State.useCurrentTarget then
            tgtID = Player.targetid or 0
        elseif State.targetID ~= 0 then
            local tEl = EntityList("contentid=" .. tostring(State.targetID))
            if tEl then for id, _ in pairs(tEl) do tgtID = id; break end end
            tgtID = tgtID or 0
        else
            tgtID = 0
        end

        -- 计算 headingOffset / offsetIsAbsolute (预览用)
        local ho, hoAbs
        local offsetRad = math.rad(State.quickDirOffset)
        if ShapeNeedsHeading(sid) then
            if State.headingSource == 1 then
                ho = (Player.pos and Player.pos.h or 0) + offsetRad
                hoAbs = true
            elseif State.headingSource == 2 then
                if State.quickDirOffset ~= 0 then ho = offsetRad end
            elseif State.headingSource == 3 then
                local tgt = Player and Player.GetTarget and Player:GetTarget()
                ho = (tgt and tgt.pos and tgt.pos.h or 0) + offsetRad
                hoAbs = true
            elseif State.headingSource == 4 then
                ho = headingRad
                hoAbs = true
            end
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

        -- 每行5个换行
        if i == 5 then
            -- 下一行会自动换行
        end
    end
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
    }
    return step
end

-- =============================================
-- 快照当前参数为 MapEffect 触发步骤
-- =============================================
local function SnapshotMEStep()
    local shape = GetCurrentShape()
    if not shape then return nil end
    SyncPlayerPos()
    return {
        a1 = State.meA1,
        a3 = State.meA3,
        checkA3 = State.meCheckA3,
        label = State.meLabel,
        posMode = State.mePosMode,
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
        heading     = State.heading,
        headingSource = State.headingSource,
        quickDirOffset = State.quickDirOffset,
        thickness   = State.thickness,
        baseLength  = State.baseLength,
        baseWidth   = State.baseWidth,
        tipLength   = State.tipLength,
        tipWidth    = State.tipWidth,
        posX = State.posX,
        posY = State.posY,
        posZ = State.posZ,
    }
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
    local offsetStr = State.quickDirOffset ~= 0
        and string.format(" + math.rad(%s)", FormatNum(State.quickDirOffset)) or ""
    if State.headingSource == 1 then
        table.insert(lines, "local heading = Player.pos.h" .. offsetStr)
    elseif State.headingSource == 3 then
        table.insert(lines, "local _tgt = Player:GetTarget()")
        table.insert(lines, "local heading = _tgt and (_tgt.pos.h" .. offsetStr .. ") or 0")
    else
        table.insert(lines, string.format("local heading = math.rad(%s)", FormatNum(State.heading)))
    end
    table.insert(lines, string.format("local timeout = %s", FormatNum(State.timeout)))
    table.insert(lines, "")

    if State.useMoogleDrawer then
        table.insert(lines, "local drawer = TensorCore.getMoogleDrawer()")
    else
        table.insert(lines, "-- 创建绘图器 (请根据需要调整颜色)")
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

        table.insert(lines, string.format("-- 循环前进 (地火): %s × %d  步进 %s米  间隔 %sms",
            loopShape.name, State.loopCount, FormatNum(State.loopStepDist), FormatNum(State.loopInterval)))
        table.insert(lines, string.format("for i = 0, %d do", State.loopCount - 1))
        table.insert(lines, string.format("    local pos = TensorCore.getPosInDirection({x=x, y=y, z=z}, heading, i * %s)",
            FormatNum(State.loopStepDist)))
        local call = GenerateShapeCall(step, "pos.x, pos.y, pos.z", "heading", 0)
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
                local headVar = "heading"
                -- 如果步骤有独立朝向且不同于主朝向，使用步骤朝向
                if step.heading ~= State.heading then
                    headVar = string.format("math.rad(%s)", FormatNum(step.heading))
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
                local headVar = "heading"
                if step.heading ~= State.heading then
                    headVar = string.format("math.rad(%s)", FormatNum(step.heading))
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
    if State.useMoogleDrawer then
        table.insert(lines, "local drawer = TensorCore.getMoogleDrawer()")
    elseif State.useGradient then
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
        table.insert(lines, bi .. "if " .. cond .. " then")

        local ii = bi .. "    "  -- inner indent

        -- Heading
        local needsHeading = ShapeNeedsHeading(entry.shapeId)
        if needsHeading then
            local oStr = (entry.quickDirOffset or 0) ~= 0
                and string.format(" + math.rad(%s)", FormatNum(entry.quickDirOffset or 0)) or ""
            if (entry.headingSource or 1) == 1 then
                table.insert(lines, ii .. "local heading = Player.pos.h" .. oStr)
            elseif (entry.headingSource or 1) == 3 then
                table.insert(lines, ii .. "local _tgt = Player:GetTarget()")
                table.insert(lines, ii .. "local heading = _tgt and (_tgt.pos.h" .. oStr .. ") or 0")
            else
                table.insert(lines, ii .. string.format("local heading = math.rad(%s)",
                    FormatNum(entry.heading)))
            end
        end

        table.insert(lines, ii .. string.format("local timeout = %s", FormatNum(entry.timeout or 5000)))

        -- 位置 + 绘图调用
        local headVar = needsHeading and "heading" or "0"
        if entry.posMode == 2 then
            -- 特效资源位置（可选获取朝向）
            table.insert(lines, ii .. "local res = Argus.getMapEffectResource(a1)")
            table.insert(lines, ii .. "if res then")
            local di = ii .. "    "
            table.insert(lines, di .. "local x, y, z = Argus.getEffectResourcePosition(res)")
            if needsHeading and (entry.headingSource or 1) == 4 then
                -- 从特效资源的方向向量推导朝向
                table.insert(lines, di .. "local dx, dy, dz = Argus.getEffectResourceOrientation(res)")
                table.insert(lines, di .. "local heading = math.atan2(dx, dz)  -- 从资源方向推导朝向")
                headVar = "heading"
            end
            table.insert(lines, di .. GenerateShapeCall(entry, "x, y, z", headVar, entry.delay or 0))
            table.insert(lines, ii .. "end")
        elseif entry.posMode == 3 then
            -- 玩家位置
            table.insert(lines, ii .. "local x, y, z = Player.pos.x, Player.pos.y, Player.pos.z")
            table.insert(lines, ii .. GenerateShapeCall(entry, "x, y, z", headVar, entry.delay or 0))
        else
            -- 固定坐标
            table.insert(lines, ii .. string.format("local x, y, z = %s, %s, %s",
                FormatNum(entry.posX), FormatNum(entry.posY), FormatNum(entry.posZ)))
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
    local headingRad = math.rad(State.heading)
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
            for i = 0, State.loopCount - 1 do
                local pos = TensorCore.getPosInDirection({x=x, y=y, z=z}, headingRad, i * State.loopStepDist)
                previewStep(step, pos.x, pos.y, pos.z, headingRad, i * State.loopInterval)
            end
        end
    else
        -- 顺序 / 同时
        for _, step in ipairs(State.comboSteps) do
            local hRad = math.rad(step.heading or State.heading)
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
    M.ArgusBuilderUI.visible, M.ArgusBuilderUI.open = GUI:Begin("StringCore 工具箱###ArgusBuilderWindow", M.ArgusBuilderUI.open)

    if M.ArgusBuilderUI.visible then

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
            State.lastLog = "已从 MapEffect 查看器接收: Index=" .. State.meA1
            M._mapEffectTransfer = nil
        end

        -- ===== 标签页按钮 =====
        do
            local tabs = { "MapEffect", "形状/颜色", "代码", "ME触发器" }
            for i, name in ipairs(tabs) do
                if i > 1 then GUI:SameLine(0, 2) end
                local isActive = (State.activeTab == i)
                if isActive then
                    GUI:PushStyleColor(GUI.Col_Button, 0.26, 0.59, 0.98, 0.80)
                    GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.26, 0.59, 0.98, 0.90)
                    GUI:PushStyleColor(GUI.Col_ButtonActive, 0.06, 0.53, 0.98, 1.00)
                end
                if GUI:Button(name .. "##ABTab" .. i, 0, 24) then
                    State.activeTab = i
                end
                if isActive then
                    GUI:PopStyleColor(3)
                end
            end
        end
        GUI:Separator()
        GUI:Spacing()

        -- MapEffect 自动刷新
        if M.MapEffectAutoRefresh then M.MapEffectAutoRefresh() end

        -- Tab 1: MapEffect (特效列表 + 执行控制)
        if State.activeTab == 1 then
            if M.DrawEffectListTab then
                M.DrawEffectListTab()
            end
            GUI:Spacing()
            GUI:Separator()
            GUI:Spacing()
            if M.DrawExecControlTab then
                M.DrawExecControlTab()
            end




        -- Tab 2: 形状/颜色
        elseif State.activeTab == 2 then

        T.SubHeader("形状选择")
        GUI:PushItemWidth(250)
        local newShapeIdx = GUI:Combo("形状##ArgusShape", State.shapeIndex, ShapeDisplayNames)
        GUI:PopItemWidth()
        if newShapeIdx ~= State.shapeIndex then
            State.shapeIndex = newShapeIdx
            State.generatedCode = ""
        end

        local shape = GetCurrentShape()
        GUI:SameLine(0, 10)
        GUI:TextColored(C.accent[1], C.accent[2], C.accent[3], C.accent[4], shape.name)

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 2. 绘图模式
        -- =============================================
        GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4], "绘图模式")
        GUI:Spacing()

        GUI:PushItemWidth(200)
        State.apiLevel = GUI:Combo("API 层级##ArgusApi", State.apiLevel, ApiLevelNames)
        if State.apiLevel == 3 then
            T.HintText("StaticDrawer 仅支持 OnFrame 瞬时绘图，不支持 Timed 模式")
            State.timingMode = 2  -- 强制切换为 OnFrame
        end
        State.timingMode = GUI:Combo("时机类型##ArgusTiming", State.timingMode, TimingModeNames)
        State.attachMode = GUI:Combo("附着方式##ArgusAttach", State.attachMode, AttachModeNames)
        GUI:PopItemWidth()

        -- OnEnt 参数
        if State.attachMode == 2 then
            GUI:Indent(10)
            GUI:Spacing()
            GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "附着实体参数:")

            State.useSelfAsEntity = GUI:Checkbox("使用自己 (Player.id)##ArgusEntSelf", State.useSelfAsEntity)
            if not State.useSelfAsEntity then
                GUI:PushItemWidth(150)
                State.entityID = GUI:InputInt("实体 ContentID##ArgusEntID", State.entityID)
                GUI:PopItemWidth()

                State.renderAllEntities = GUI:Checkbox("渲染全部相同 ContentID 实体##ArgusRenderAll", State.renderAllEntities)
                if GUI:IsItemHovered() then
                    GUI:SetTooltip("启用后会为场上所有匹配 ContentID 的实体都画图，而不是只取第一个")
                end
            end

            State.useCurrentTarget = GUI:Checkbox("朝向当前目标 (Player.targetid)##ArgusTgt", State.useCurrentTarget)
            if not State.useCurrentTarget then
                GUI:PushItemWidth(150)
                State.targetID = GUI:InputInt("目标 ID##ArgusTgtID", State.targetID)
                GUI:PopItemWidth()
            end

            GUI:Unindent(10)
        end

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 3. 坐标与通用参数
        -- =============================================
        GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4], "位置与时间")
        GUI:Spacing()

        if State.timingMode == 1 then
            GUI:PushItemWidth(150)
            State.timeout = GUI:InputInt("持续时间 (毫秒)##ArgusTimeout", State.timeout)
            GUI:PopItemWidth()
            if State.timeout < 100 then State.timeout = 100 end
        end

        if State.attachMode == 1 then
            State.usePlayerPos = GUI:Checkbox("使用玩家当前位置##ArgusPlayerPos", State.usePlayerPos)
            GUI:SameLine(0, 10)
            State.followPlayerPos = GUI:Checkbox("跟随玩家##ArgusFollowPos", State.followPlayerPos)
            if GUI:IsItemHovered() then
                GUI:SetTooltip("勾选后生成的代码使用 Player.pos.x/y/z 动态位置")
            end
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

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 4. 形状参数（动态）
        -- =============================================
        GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4], "形状参数")
        GUI:Spacing()

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

            -- "实体朝向" 仅 OnEnt 可用，坐标模式自动回退
            if State.headingSource == 2 and State.attachMode ~= 2 then
                GUI:SameLine(0, 5)
                GUI:TextColored(1, 0.8, 0.2, 1, "(坐标模式下回退为固定角度)")
            end

            -- 固定角度：显示角度滑条
            if State.headingSource == 4 then
                State.heading = GUI:SliderFloat("固定朝向 (度)##ArgusHeading", State.heading, -180, 180)
            else
                -- 非固定角度模式：显示当前朝向来源的实时角度
                SyncPlayerPos()
                GUI:SameLine(0, 10)
                local srcLabel = HeadingSourceNames[State.headingSource] or "?"
                GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4],
                    string.format("(%s  偏移: %s°)", srcLabel, FormatNum(State.quickDirOffset)))
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

        -- 颜色设置 (同 Tab 2)

            State.useMoogleDrawer = GUI:Checkbox("使用默认配色 (MoogleDrawer)##ArgusMoogle", State.useMoogleDrawer)
            if GUI:IsItemHovered() then
                GUI:SetTooltip("勾选后使用 TensorCore.getMoogleDrawer() 的蓝紫渐变配色")
            end

            if not State.useMoogleDrawer then
                GUI:Spacing()

                -- 渐变色开关（填充色和渐变色互斥）
                State.useGradient = GUI:Checkbox("启用渐变色##ArgusGrad", State.useGradient)

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
        if GUI:CollapsingHeader("高级参数##ArgusAdvanced") then
            GUI:Indent(5)

            GUI:PushItemWidth(150)
            State.delay = GUI:InputInt("延迟显示 (毫秒)##ArgusDelay", State.delay)
            if State.delay < 0 then State.delay = 0 end
            GUI:PopItemWidth()

            State.oldDraw = GUI:Checkbox("旧绘图模式 (oldDraw)##ArgusOld", State.oldDraw)
            if GUI:IsItemHovered() then
                GUI:SetTooltip("启用后绘图会覆盖在模型之上")
            end

            State.doNotDetect = GUI:Checkbox("不参与 AOE 检测 (doNotDetect)##ArgusDND", State.doNotDetect)
            if GUI:IsItemHovered() then
                GUI:SetTooltip("启用后此绘图不会被 Argus 的 AOE 检测系统识别")
            end

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

            GUI:Unindent(5)
        end

        elseif State.activeTab == 3 then

        -- 操作按钮 (单体生成)
        T.SubHeader("单体绘图")
        T.PushBtn(C.btnPrimary)
        if GUI:Button("生成代码##ArgusGen", 90, 26) then
            SyncPlayerPos()
            GenerateCode()
            State.lastLog = "代码已生成"
        end
        T.PopBtn()
        GUI:SameLine(0, 6)
        T.PushBtn(C.btnRun)
        if GUI:Button("复制##ArgusCopy", 70, 26) then
            if State.generatedCode == "" then SyncPlayerPos(); GenerateCode() end
            CopyToClipboard(State.generatedCode)
        end
        T.PopBtn()
        GUI:SameLine(0, 6)
        T.PushBtn(C.btnSend)
        if GUI:Button("预览##ArgusPreview", 70, 26) then
            SyncPlayerPos()
            ExecutePreview()
        end
        T.PopBtn()
        GUI:SameLine(0, 6)
        GUI:PushStyleColor(GUI.Col_Button, 0.15, 0.65, 0.15, 0.85)
        GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.20, 0.75, 0.20, 0.95)
        GUI:PushStyleColor(GUI.Col_ButtonActive, 0.10, 0.55, 0.10, 1.0)
        if GUI:Button("运行##ArgusRun", 60, 26) then
            ExecuteCodeString(State.generatedCode)
        end
        GUI:PopStyleColor(3)
        GUI:SameLine(0, 6)
        T.PushBtn(C.btnStop)
        if GUI:Button("清除##ArgusClear", 60, 26) then
            ClearPreviewShapes()
            -- 清除通过「运行」创建的绘图（UUID 未被追踪）
            if Argus and Argus.deleteTimedShape then Argus.deleteTimedShape() end
            State.lastLog = "已清除所有绘图"
        end
        T.PopBtn()

        if State.lastLog ~= "" then
            GUI:SameLine(0, 10)
            T.SuccessText(State.lastLog)
        end

        -- 运行错误信息
        if State.lastRunError ~= "" then
            GUI:TextColored(1.0, 0.3, 0.3, 1.0, State.lastRunError)
        end

        -- 代码编辑器
        if State.generatedCode ~= "" then
            GUI:Spacing()
            GUI:PushStyleColor(GUI.Col_FrameBg, 0.10, 0.08, 0.10, 0.95)
            GUI:PushItemWidth(-1)
            local lc = 1
            for _ in string.gmatch(State.generatedCode, "\n") do lc = lc + 1 end
            local th = math.min(math.max(lc * 16 + 10, 80), 350)
            local newCode, changed = GUI:InputTextMultiline("##ABCodeOut", State.generatedCode, -1, th, GUI.InputTextFlags_AllowTabInput)
            if changed then
                State.generatedCode = newCode
            end
            GUI:PopItemWidth()
            GUI:PopStyleColor(1)
        else
            T.HintText("点击「生成代码」按钮生成 Lua 代码")
        end

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- 组合机制
        if GUI:CollapsingHeader("组合机制##ArgusCombo") then
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
            GUI:PushStyleColor(GUI.Col_Button, 0.15, 0.65, 0.15, 0.85)
            GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.20, 0.75, 0.20, 0.95)
            GUI:PushStyleColor(GUI.Col_ButtonActive, 0.10, 0.55, 0.10, 1.0)
            if GUI:Button("运行##ComboRun", 55, 24) then
                ExecuteCodeString(State.comboGeneratedCode)
            end
            GUI:PopStyleColor(3)
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
                GUI:PushStyleColor(GUI.Col_FrameBg, 0.10, 0.08, 0.10, 0.95)
                GUI:PushItemWidth(-1)
                local lc = 1
                for _ in string.gmatch(State.comboGeneratedCode, "\n") do lc = lc + 1 end
                local th = math.min(math.max(lc * 16 + 10, 80), 350)
                local newCode, changed = GUI:InputTextMultiline("##ComboCodeOut", State.comboGeneratedCode, -1, th, GUI.InputTextFlags_AllowTabInput)
                if changed then
                    State.comboGeneratedCode = newCode
                end
                GUI:PopItemWidth()
                GUI:PopStyleColor(1)
            end

            GUI:Unindent(5)
        end

        elseif State.activeTab == 4 then

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
            if GUI:IsItemHovered() then
                GUI:SetTooltip("不勾选则只判断 Index(a1)，忽略 Flags(a3)")
            end

            local posModeNames = { "固定坐标", "特效资源位置", "玩家实时位置" }
            GUI:PushItemWidth(200)
            State.mePosMode = GUI:Combo("位置来源##MEPosMode", State.mePosMode, posModeNames)
            GUI:PopItemWidth()

            GUI:PushItemWidth(200)
            State.meLabel = GUI:InputText("备注##MELabel", State.meLabel)
            GUI:PopItemWidth()
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
            GUI:PushStyleColor(GUI.Col_Button, 0.15, 0.65, 0.15, 0.85)
            GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.20, 0.75, 0.20, 0.95)
            GUI:PushStyleColor(GUI.Col_ButtonActive, 0.10, 0.55, 0.10, 1.0)
            if GUI:Button("运行##MERun", 55, 24) then
                ExecuteCodeString(State.meGeneratedCode)
            end
            GUI:PopStyleColor(3)

            -- 运行错误信息
            if State.lastRunError ~= "" then
                GUI:TextColored(1.0, 0.3, 0.3, 1.0, State.lastRunError)
            end

            if State.meGeneratedCode ~= "" then
                GUI:Spacing()
                GUI:PushStyleColor(GUI.Col_FrameBg, 0.10, 0.08, 0.10, 0.95)
                GUI:PushItemWidth(-1)
                local lc = 1
                for _ in string.gmatch(State.meGeneratedCode, "\n") do lc = lc + 1 end
                local th = math.min(math.max(lc * 16 + 10, 80), 350)
                local newCode, changed = GUI:InputTextMultiline("##MECodeOut", State.meGeneratedCode, -1, th, GUI.InputTextFlags_AllowTabInput)
                if changed then
                    State.meGeneratedCode = newCode
                end
                GUI:PopItemWidth()
                GUI:PopStyleColor(1)
            end

        end -- activeTab

    end

    GUI:End()
    T.PopTheme()
end

d("[StringCore] ArgusBuilderUI.lua 加载完成")
