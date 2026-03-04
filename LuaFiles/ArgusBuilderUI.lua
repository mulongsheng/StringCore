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
local ApiLevelNames = { "ShapeDrawer (推荐)", "Argus2 底层" }
local TimingModeNames = { "Timed (持续时间)", "OnFrame (每帧瞬时)" }
local AttachModeNames = { "坐标固定", "OnEnt (附着实体)" }

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
    usePlayerHeading = true,  -- 默认使用玩家朝向

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
        if State.usePlayerHeading and Player.pos.h then
            State.heading = math.deg(Player.pos.h)
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
    local needsHeading = (sid == "Cone" or sid == "Rect" or sid == "CenteredRect"
        or sid == "DonutCone" or sid == "Cross" or sid == "Arrow" or sid == "Chevron")
    if needsHeading and not isOnEnt then
        if State.usePlayerHeading then
            table.insert(lines, "local heading = Player.pos.h")
        else
            table.insert(lines, string.format("local heading = math.rad(%s)  -- %s°", FormatNum(State.heading), FormatNum(State.heading)))
        end
        table.insert(lines, "")
    end

    -- 角度（扇形类）
    local needsAngle = (sid == "Cone" or sid == "DonutCone")
    if needsAngle then
        table.insert(lines, string.format("local angle = math.rad(%s)  -- %s°", FormatNum(State.angle), FormatNum(State.angle)))
        table.insert(lines, "")
    end

    if isShapeDrawer then
        -- === ShapeDrawer 模式 ===
        -- 创建 drawer
        if State.useMoogleDrawer then
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
                table.insert(lines, "-- 附着实体绘图")
                local entStr = State.useSelfAsEntity and "Player.id" or FormatNum(State.entityID)
                local tgtStr = State.useCurrentTarget and "Player.targetid" or FormatNum(State.targetID)
                local args = FormatNum(State.timeout) .. ", " .. entStr

                if sid == "Circle" then
                    args = args .. ", " .. FormatNum(State.radius)
                    args = args .. ", " .. FormatNum(State.delay)
                elseif sid == "Cone" then
                    args = args .. ", " .. FormatNum(State.radius) .. ", angle"
                    args = args .. ", " .. tgtStr .. ", " .. FormatNum(State.delay)
                elseif sid == "Rect" then
                    args = args .. ", " .. FormatNum(State.length) .. ", " .. FormatNum(State.width)
                    args = args .. ", " .. tgtStr .. ", " .. FormatNum(State.delay)
                elseif sid == "CenteredRect" then
                    args = args .. ", " .. FormatNum(State.length) .. ", " .. FormatNum(State.width)
                    args = args .. ", " .. tgtStr .. ", " .. FormatNum(State.delay)
                elseif sid == "Donut" then
                    args = args .. ", " .. FormatNum(State.radiusInner) .. ", " .. FormatNum(State.radiusOuter)
                    args = args .. ", " .. FormatNum(State.delay)
                elseif sid == "DonutCone" then
                    args = args .. ", " .. FormatNum(State.radiusInner) .. ", " .. FormatNum(State.radiusOuter) .. ", angle"
                    args = args .. ", " .. tgtStr .. ", " .. FormatNum(State.delay)
                elseif sid == "Cross" then
                    args = args .. ", " .. FormatNum(State.length) .. ", " .. FormatNum(State.width)
                    args = args .. ", " .. tgtStr .. ", " .. FormatNum(State.delay)
                elseif sid == "Arrow" then
                    args = args .. ", " .. FormatNum(State.baseLength) .. ", " .. FormatNum(State.baseWidth)
                    args = args .. ", " .. FormatNum(State.tipLength) .. ", " .. FormatNum(State.tipWidth)
                    args = args .. ", " .. tgtStr .. ", " .. FormatNum(State.delay)
                elseif sid == "Chevron" then
                    args = args .. ", " .. FormatNum(State.length) .. ", " .. FormatNum(State.thickness)
                    args = args .. ", " .. tgtStr .. ", " .. FormatNum(State.delay)
                end

                table.insert(lines, "local uuid = drawer:" .. methodName .. "(" .. args .. ")")
            else
                -- addTimedXxx (坐标版本)
                local methodName = "addTimed" .. sid
                table.insert(lines, "-- 持续绘图 (坐标)")
                local args = FormatNum(State.timeout)

                if sid == "Circle" then
                    args = args .. ", x, y, z, " .. FormatNum(State.radius)
                    args = args .. ", " .. FormatNum(State.delay)
                elseif sid == "Cone" then
                    args = args .. ", x, y, z, " .. FormatNum(State.radius) .. ", angle, heading"
                    args = args .. ", " .. FormatNum(State.delay)
                elseif sid == "Rect" then
                    args = args .. ", x, y, z, " .. FormatNum(State.length) .. ", " .. FormatNum(State.width) .. ", heading"
                    args = args .. ", " .. FormatNum(State.delay)
                elseif sid == "CenteredRect" then
                    args = args .. ", x, y, z, " .. FormatNum(State.length) .. ", " .. FormatNum(State.width) .. ", heading"
                    args = args .. ", " .. FormatNum(State.delay)
                elseif sid == "Donut" then
                    args = args .. ", x, y, z, " .. FormatNum(State.radiusInner) .. ", " .. FormatNum(State.radiusOuter)
                    args = args .. ", " .. FormatNum(State.delay)
                elseif sid == "DonutCone" then
                    args = args .. ", x, y, z, " .. FormatNum(State.radiusInner) .. ", " .. FormatNum(State.radiusOuter) .. ", angle, heading"
                    args = args .. ", " .. FormatNum(State.delay)
                elseif sid == "Cross" then
                    args = args .. ", x, y, z, " .. FormatNum(State.length) .. ", " .. FormatNum(State.width) .. ", heading"
                    args = args .. ", " .. FormatNum(State.delay)
                elseif sid == "Arrow" then
                    args = args .. ", x, y, z, heading, " .. FormatNum(State.baseLength) .. ", " .. FormatNum(State.baseWidth)
                    args = args .. ", " .. FormatNum(State.tipLength) .. ", " .. FormatNum(State.tipWidth)
                    args = args .. ", " .. FormatNum(State.delay)
                elseif sid == "Chevron" then
                    args = args .. ", x, y, z, " .. FormatNum(State.length) .. ", " .. FormatNum(State.thickness) .. ", heading"
                    args = args .. ", " .. FormatNum(State.delay)
                elseif sid == "Line" then
                    args = args .. ", x1, y1, z1, x2, y2, z2"
                    args = args .. ", " .. FormatNum(State.thickness)
                end

                table.insert(lines, "local uuid = drawer:" .. methodName .. "(" .. args .. ")")
            end
        else
            -- OnFrame 瞬时方法
            local methodName = "add" .. sid
            table.insert(lines, "-- 瞬时绘图 (仅在 OnFrame 事件中使用)")

            if sid == "Circle" then
                table.insert(lines, "drawer:addCircle(x, y, z, " .. FormatNum(State.radius) .. ")")
            elseif sid == "Cone" then
                table.insert(lines, "drawer:addCone(x, y, z, " .. FormatNum(State.radius) .. ", angle, heading)")
            elseif sid == "Rect" then
                table.insert(lines, "drawer:addRect(x, y, z, " .. FormatNum(State.length) .. ", " .. FormatNum(State.width) .. ", heading)")
            elseif sid == "CenteredRect" then
                table.insert(lines, "drawer:addCenteredRect(x, y, z, " .. FormatNum(State.length) .. ", " .. FormatNum(State.width) .. ", heading)")
            elseif sid == "Donut" then
                table.insert(lines, "drawer:addDonut(x, y, z, " .. FormatNum(State.radiusInner) .. ", " .. FormatNum(State.radiusOuter) .. ")")
            elseif sid == "DonutCone" then
                table.insert(lines, "drawer:addDonutCone(x, y, z, " .. FormatNum(State.radiusInner) .. ", " .. FormatNum(State.radiusOuter) .. ", angle, heading)")
            elseif sid == "Cross" then
                table.insert(lines, "drawer:addCross(x, y, z, " .. FormatNum(State.length) .. ", " .. FormatNum(State.width) .. ", heading)")
            elseif sid == "Arrow" then
                table.insert(lines, "drawer:addArrow(x, y, z, heading, " .. FormatNum(State.baseLength) .. ", " .. FormatNum(State.baseWidth) .. ", " .. FormatNum(State.tipLength) .. ", " .. FormatNum(State.tipWidth) .. ")")
            elseif sid == "Chevron" then
                table.insert(lines, "drawer:addChevron(x, y, z, " .. FormatNum(State.length) .. ", " .. FormatNum(State.thickness) .. ", heading)")
            elseif sid == "Line" then
                table.insert(lines, "drawer:addLine(x1, y1, z1, x2, y2, z2, " .. FormatNum(State.thickness) .. ")")
            end
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

    table.insert(lines, "")

    State.generatedCode = table.concat(lines, "\n")
    return State.generatedCode
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

    -- 清除之前的预览
    for _, uuid in ipairs(State.previewUUIDs) do
        if Argus and Argus.deleteTimedShape then
            Argus.deleteTimedShape(uuid)
        end
    end
    State.previewUUIDs = {}

    -- 创建 drawer
    local drawer
    if State.useMoogleDrawer and TensorCore and TensorCore.getMoogleDrawer then
        drawer = TensorCore.getMoogleDrawer()
    else
        -- 防御 nil 值
        local fR = State.fillR or 0.8
        local fG = State.fillG or 0.0
        local fB = State.fillB or 1.0
        local fA = State.fillA or 0.5
        local oR = State.outlineR or 1.0
        local oG = State.outlineG or 1.0
        local oB = State.outlineB or 1.0
        local oA = State.outlineA or 1.0

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

        drawer = Argus2.ShapeDrawer:new(
            startU32,
            midU32,
            fillU32,
            outlineU32,
            State.outlineThickness or 1.5
        )
    end

    local sid = shape.id
    local x, y, z = State.posX, State.posY, State.posZ
    local timeout = State.timeout
    local del = State.delay
    local headingRad = math.rad(State.heading)
    local angleRad = math.rad(State.angle)

    local isOnEnt = (State.attachMode == 2)
    local uuid

    if isOnEnt then
        local entID = State.useSelfAsEntity and Player.id or State.entityID
        local tgtID = State.useCurrentTarget and (Player.targetid or 0) or State.targetID

        if sid == "Circle" then
            uuid = drawer:addTimedCircleOnEnt(timeout, entID, State.radius, del)
        elseif sid == "Cone" then
            uuid = drawer:addTimedConeOnEnt(timeout, entID, State.radius, angleRad, tgtID, del)
        elseif sid == "Rect" then
            uuid = drawer:addTimedRectOnEnt(timeout, entID, State.length, State.width, tgtID, del)
        elseif sid == "CenteredRect" then
            uuid = drawer:addTimedCenteredRectOnEnt(timeout, entID, State.length, State.width, tgtID, del)
        elseif sid == "Donut" then
            uuid = drawer:addTimedDonutOnEnt(timeout, entID, State.radiusInner, State.radiusOuter, del)
        elseif sid == "DonutCone" then
            uuid = drawer:addTimedDonutConeOnEnt(timeout, entID, State.radiusInner, State.radiusOuter, angleRad, tgtID, del)
        elseif sid == "Cross" then
            uuid = drawer:addTimedCrossOnEnt(timeout, entID, State.length, State.width, tgtID, del)
        elseif sid == "Arrow" then
            uuid = drawer:addTimedArrowOnEnt(timeout, entID, State.baseLength, State.baseWidth, State.tipLength, State.tipWidth, tgtID, del)
        elseif sid == "Chevron" then
            uuid = drawer:addTimedChevronOnEnt(timeout, entID, State.length, State.thickness, tgtID, del)
        end
    else
        if sid == "Circle" then
            uuid = drawer:addTimedCircle(timeout, x, y, z, State.radius, del)
        elseif sid == "Cone" then
            uuid = drawer:addTimedCone(timeout, x, y, z, State.radius, angleRad, headingRad, del)
        elseif sid == "Rect" then
            uuid = drawer:addTimedRect(timeout, x, y, z, State.length, State.width, headingRad, del)
        elseif sid == "CenteredRect" then
            uuid = drawer:addTimedCenteredRect(timeout, x, y, z, State.length, State.width, headingRad, del)
        elseif sid == "Donut" then
            uuid = drawer:addTimedDonut(timeout, x, y, z, State.radiusInner, State.radiusOuter, del)
        elseif sid == "DonutCone" then
            uuid = drawer:addTimedDonutCone(timeout, x, y, z, State.radiusInner, State.radiusOuter, angleRad, headingRad, del)
        elseif sid == "Cross" then
            uuid = drawer:addTimedCross(timeout, x, y, z, State.length, State.width, headingRad, del)
        elseif sid == "Arrow" then
            uuid = drawer:addTimedArrow(timeout, x, y, z, headingRad, State.baseLength, State.baseWidth, State.tipLength, State.tipWidth, del)
        elseif sid == "Chevron" then
            uuid = drawer:addTimedChevron(timeout, x, y, z, State.length, State.thickness, headingRad, del)
        elseif sid == "Line" then
            uuid = drawer:addTimedLine(timeout, x, y, z, State.pos2X, State.pos2Y, State.pos2Z, State.thickness)
        end
    end

    if uuid then
        table.insert(State.previewUUIDs, uuid)
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
        usePlayerHeading = State.usePlayerHeading,
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
-- 生成单个形状的绘图调用字符串
-- =============================================
local function GenerateShapeCall(step, posVar, headingVar, delayVal)
    local sid = step.shapeId
    local del = FormatNum(delayVal)

    if sid == "Circle" then
        return string.format("drawer:addTimedCircle(timeout, %s, %s, %s)",
            posVar, FormatNum(step.radius), del)
    elseif sid == "Cone" then
        return string.format("drawer:addTimedCone(timeout, %s, %s, math.rad(%s), %s, %s)",
            posVar, FormatNum(step.radius), FormatNum(step.angle), headingVar, del)
    elseif sid == "Rect" then
        return string.format("drawer:addTimedRect(timeout, %s, %s, %s, %s, %s)",
            posVar, FormatNum(step.length), FormatNum(step.width), headingVar, del)
    elseif sid == "CenteredRect" then
        return string.format("drawer:addTimedCenteredRect(timeout, %s, %s, %s, %s, %s)",
            posVar, FormatNum(step.length), FormatNum(step.width), headingVar, del)
    elseif sid == "Donut" then
        return string.format("drawer:addTimedDonut(timeout, %s, %s, %s, %s)",
            posVar, FormatNum(step.radiusInner), FormatNum(step.radiusOuter), del)
    elseif sid == "DonutCone" then
        return string.format("drawer:addTimedDonutCone(timeout, %s, %s, %s, math.rad(%s), %s, %s)",
            posVar, FormatNum(step.radiusInner), FormatNum(step.radiusOuter),
            FormatNum(step.angle), headingVar, del)
    elseif sid == "Cross" then
        return string.format("drawer:addTimedCross(timeout, %s, %s, %s, %s, %s)",
            posVar, FormatNum(step.length), FormatNum(step.width), headingVar, del)
    elseif sid == "Arrow" then
        return string.format("drawer:addTimedArrow(timeout, %s, %s, %s, %s, %s, %s, %s)",
            posVar, headingVar, FormatNum(step.baseLength), FormatNum(step.baseWidth),
            FormatNum(step.tipLength), FormatNum(step.tipWidth), del)
    elseif sid == "Chevron" then
        return string.format("drawer:addTimedChevron(timeout, %s, %s, %s, %s, %s)",
            posVar, FormatNum(step.length), FormatNum(step.thickness), headingVar, del)
    end
    return "-- 不支持的形状: " .. sid
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
    if State.usePlayerHeading then
        table.insert(lines, "local heading = Player.pos.h")
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
        local needsHeading = (entry.shapeId == "Cone" or entry.shapeId == "Rect" or entry.shapeId == "CenteredRect"
            or entry.shapeId == "DonutCone" or entry.shapeId == "Cross" or entry.shapeId == "Arrow" or entry.shapeId == "Chevron")
        if needsHeading then
            if entry.usePlayerHeading then
                table.insert(lines, ii .. "local heading = Player.pos.h")
            else
                table.insert(lines, ii .. string.format("local heading = math.rad(%s)  -- %s°",
                    FormatNum(entry.heading), FormatNum(entry.heading)))
            end
        end

        table.insert(lines, ii .. string.format("local timeout = %s", FormatNum(entry.timeout or 5000)))

        -- 位置 + 绘图调用
        local headVar = needsHeading and "heading" or "0"
        if entry.posMode == 2 then
            -- 特效资源位置
            table.insert(lines, ii .. "local res = Argus.getMapEffectResource(a1)")
            table.insert(lines, ii .. "if res then")
            local di = ii .. "    "
            table.insert(lines, di .. "local x, y, z = Argus.getEffectResourcePosition(res)")
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

    -- 清除之前的预览
    for _, uuid in ipairs(State.previewUUIDs) do
        if Argus and Argus.deleteTimedShape then
            Argus.deleteTimedShape(uuid)
        end
    end
    State.previewUUIDs = {}

    -- 创建 drawer
    local drawer
    if State.useMoogleDrawer and TensorCore and TensorCore.getMoogleDrawer then
        drawer = TensorCore.getMoogleDrawer()
    else
        local fR, fG, fB, fA = State.fillR or 0.8, State.fillG or 0, State.fillB or 1, State.fillA or 0.5
        local oR, oG, oB, oA = State.outlineR or 1, State.outlineG or 1, State.outlineB or 1, State.outlineA or 1
        local fillU32 = GUI:ColorConvertFloat4ToU32(fR, fG, fB, fA)
        local outlineU32 = GUI:ColorConvertFloat4ToU32(oR, oG, oB, oA)
        local startU32, midU32 = fillU32, nil
        if State.useGradient then
            startU32 = GUI:ColorConvertFloat4ToU32(State.startR or 1, State.startG or 0, State.startB or 0, State.startA or 0.5)
            midU32 = GUI:ColorConvertFloat4ToU32(State.midR or 0.5, State.midG or 0, State.midB or 1, State.midA or 0.5)
            fillU32 = GUI:ColorConvertFloat4ToU32(State.endR or 0.8, State.endG or 0, State.endB or 1, State.endA or 0.5)
        end
        drawer = Argus2.ShapeDrawer:new(startU32, midU32, fillU32, outlineU32, State.outlineThickness or 1.5)
    end

    local x, y, z = State.posX, State.posY, State.posZ
    local headingRad = math.rad(State.heading)
    local timeout = State.timeout
    local mode = State.comboMode

    -- 执行单个步骤的预览绘图
    local function previewStep(step, px, py, pz, hRad, del)
        local sid = step.shapeId
        local angleRad = math.rad(step.angle or 90)
        local uuid

        if sid == "Circle" then
            uuid = drawer:addTimedCircle(timeout, px, py, pz, step.radius, del)
        elseif sid == "Cone" then
            uuid = drawer:addTimedCone(timeout, px, py, pz, step.radius, angleRad, hRad, del)
        elseif sid == "Rect" then
            uuid = drawer:addTimedRect(timeout, px, py, pz, step.length, step.width, hRad, del)
        elseif sid == "CenteredRect" then
            uuid = drawer:addTimedCenteredRect(timeout, px, py, pz, step.length, step.width, hRad, del)
        elseif sid == "Donut" then
            uuid = drawer:addTimedDonut(timeout, px, py, pz, step.radiusInner, step.radiusOuter, del)
        elseif sid == "DonutCone" then
            uuid = drawer:addTimedDonutCone(timeout, px, py, pz, step.radiusInner, step.radiusOuter, angleRad, hRad, del)
        elseif sid == "Cross" then
            uuid = drawer:addTimedCross(timeout, px, py, pz, step.length, step.width, hRad, del)
        elseif sid == "Arrow" then
            uuid = drawer:addTimedArrow(timeout, px, py, pz, hRad, step.baseLength, step.baseWidth, step.tipLength, step.tipWidth, del)
        elseif sid == "Chevron" then
            uuid = drawer:addTimedChevron(timeout, px, py, pz, step.length, step.thickness, hRad, del)
        end

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
    GUI:SetNextWindowSize(520, 700, GUI.SetCond_Appearing)
    M.ArgusBuilderUI.visible, M.ArgusBuilderUI.open = GUI:Begin("Argus 代码生成器###ArgusBuilderWindow", M.ArgusBuilderUI.open)

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

        -- ===== TabBar =====
        if GUI:BeginTabBar("ABTabBar") then

        -- ========================================
        -- Tab 1: 形状参数
        -- ========================================
        if GUI:BeginTabItem("形状参数") then

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
                State.entityID = GUI:InputInt("实体 ID##ArgusEntID", State.entityID)
                GUI:PopItemWidth()
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
        local needsHeading = (sid == "Cone" or sid == "Rect" or sid == "CenteredRect"
            or sid == "DonutCone" or sid == "Cross" or sid == "Arrow" or sid == "Chevron")
        if needsHeading then
            GUI:Spacing()
            State.usePlayerHeading = GUI:Checkbox("使用玩家朝向##ArgusPlayerH", State.usePlayerHeading)
            if State.usePlayerHeading then
                SyncPlayerPos()
                GUI:SameLine(0, 10)
                GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4],
                    string.format("朝向: %.1f°", State.heading))
            else
                State.heading = GUI:SliderFloat("朝向 (度)##ArgusHeading", State.heading, -180, 180)
            end

            -- 快捷方向按钮 (基于玩家当前面向)
            GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4], "快捷方向:")
            GUI:SameLine(0, 5)

            local playerH = 0
            if Player and Player.pos and Player.pos.h then
                playerH = math.deg(Player.pos.h)
            end

            -- 归一化角度到 [-180, 180]
            local function NormalizeAngle(deg)
                while deg > 180 do deg = deg - 360 end
                while deg < -180 do deg = deg + 360 end
                return deg
            end

            GUI:PushStyleColor(GUI.Col_Button, 0.25, 0.55, 0.80, 0.85)
            GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.35, 0.65, 0.90, 0.95)
            GUI:PushStyleColor(GUI.Col_ButtonActive, 0.20, 0.45, 0.70, 1.0)
            if GUI:Button("前##HDir", 30, 20) then
                State.heading = NormalizeAngle(playerH)
                State.usePlayerHeading = false
            end
            GUI:PopStyleColor(3)

            GUI:SameLine(0, 3)
            GUI:PushStyleColor(GUI.Col_Button, 0.25, 0.55, 0.80, 0.85)
            GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.35, 0.65, 0.90, 0.95)
            GUI:PushStyleColor(GUI.Col_ButtonActive, 0.20, 0.45, 0.70, 1.0)
            if GUI:Button("后##HDir", 30, 20) then
                State.heading = NormalizeAngle(playerH + 180)
                State.usePlayerHeading = false
            end
            GUI:PopStyleColor(3)

            GUI:SameLine(0, 3)
            GUI:PushStyleColor(GUI.Col_Button, 0.25, 0.55, 0.80, 0.85)
            GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.35, 0.65, 0.90, 0.95)
            GUI:PushStyleColor(GUI.Col_ButtonActive, 0.20, 0.45, 0.70, 1.0)
            if GUI:Button("左##HDir", 30, 20) then
                State.heading = NormalizeAngle(playerH - 90)
                State.usePlayerHeading = false
            end
            GUI:PopStyleColor(3)

            GUI:SameLine(0, 3)
            GUI:PushStyleColor(GUI.Col_Button, 0.25, 0.55, 0.80, 0.85)
            GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.35, 0.65, 0.90, 0.95)
            GUI:PushStyleColor(GUI.Col_ButtonActive, 0.20, 0.45, 0.70, 1.0)
            if GUI:Button("右##HDir", 30, 20) then
                State.heading = NormalizeAngle(playerH + 90)
                State.usePlayerHeading = false
            end
            GUI:PopStyleColor(3)

            -- 相对偏移输入 (正=右偏, 负=左偏)
            GUI:SameLine(0, 10)
            GUI:PushItemWidth(80)
            State._headingOffset = State._headingOffset or 0
            State._headingOffset = GUI:InputFloat("##HOffsetVal", State._headingOffset, 0, 0)
            GUI:PopItemWidth()
            GUI:SameLine(0, 3)
            GUI:PushStyleColor(GUI.Col_Button, 0.55, 0.40, 0.75, 0.85)
            GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.65, 0.50, 0.85, 0.95)
            GUI:PushStyleColor(GUI.Col_ButtonActive, 0.45, 0.30, 0.65, 1.0)
            if GUI:Button("偏移##HApply", 40, 20) then
                State.heading = NormalizeAngle(playerH + State._headingOffset)
                State.usePlayerHeading = false
            end
            GUI:PopStyleColor(3)
            GUI:SameLine(0, 5)
            GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4], "(+右 -左)")
        end

        GUI:PopItemWidth()

        GUI:EndTabItem()
        end -- Tab1

        -- ========================================
        -- Tab 2: 颜色设置
        -- ========================================
        if GUI:BeginTabItem("颜色") then

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
                    DrawColorPicker("起始", "startR", "startG", "startB", "startA")
                    DrawPresetButtons("startR", "startG", "startB", "startA")

                    GUI:Spacing()

                    GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "中间颜色:")
                    DrawColorPicker("中间", "midR", "midG", "midB", "midA")
                    DrawPresetButtons("midR", "midG", "midB", "midA")

                    GUI:Spacing()

                    GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "结束颜色:")
                    DrawColorPicker("结束", "endR", "endG", "endB", "endA")
                    DrawPresetButtons("endR", "endG", "endB", "endA")
                    GUI:Unindent(10)
                else
                    -- === 单一填充色模式 ===
                    GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "填充颜色:")
                    DrawColorPicker("填充", "fillR", "fillG", "fillB", "fillA")
                    DrawPresetButtons("fillR", "fillG", "fillB", "fillA")
                end

                GUI:Spacing()

                -- 描边颜色（始终显示）
                GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "描边颜色:")
                DrawColorPicker("描边", "outlineR", "outlineG", "outlineB", "outlineA")
                DrawPresetButtons("outlineR", "outlineG", "outlineB", "outlineA")
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

        GUI:EndTabItem()
        end -- Tab2

        -- ========================================
        -- Tab 3: 代码 / 组合
        -- ========================================
        if GUI:BeginTabItem("代码") then

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
        T.PushBtn(C.btnStop)
        if GUI:Button("清除##ArgusClear", 60, 26) then
            for _, uuid in ipairs(State.previewUUIDs) do
                if Argus and Argus.deleteTimedShape then Argus.deleteTimedShape(uuid) end
            end
            State.previewUUIDs = {}
            State.lastLog = "已清除所有预览"
        end
        T.PopBtn()

        if State.lastLog ~= "" then
            GUI:SameLine(0, 10)
            T.SuccessText(State.lastLog)
        end

        -- 代码展示
        if State.generatedCode ~= "" then
            GUI:Spacing()
            GUI:PushStyleColor(GUI.Col_FrameBg, 0.10, 0.08, 0.10, 0.95)
            GUI:PushItemWidth(-1)
            local lc = 1
            for _ in string.gmatch(State.generatedCode, "\n") do lc = lc + 1 end
            local th = math.min(math.max(lc * 16 + 10, 80), 250)
            GUI:InputTextMultiline("##ABCodeOut", State.generatedCode, -1, th, GUI.InputTextFlags_ReadOnly)
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
            T.PushBtn(C.btnStop)
            if GUI:Button("清除##ComboClearPrev", 55, 24) then
                for _, uuid in ipairs(State.previewUUIDs) do
                    if Argus and Argus.deleteTimedShape then Argus.deleteTimedShape(uuid) end
                end
                State.previewUUIDs = {}
            end
            T.PopBtn()

            -- 组合代码展示
            if State.comboGeneratedCode ~= "" then
                GUI:Spacing()
                GUI:PushStyleColor(GUI.Col_FrameBg, 0.10, 0.08, 0.10, 0.95)
                GUI:PushItemWidth(-1)
                local lc = 1
                for _ in string.gmatch(State.comboGeneratedCode, "\n") do lc = lc + 1 end
                local th = math.min(math.max(lc * 16 + 10, 80), 250)
                GUI:InputTextMultiline("##ComboCodeOut", State.comboGeneratedCode, -1, th, GUI.InputTextFlags_ReadOnly)
                GUI:PopItemWidth()
                GUI:PopStyleColor(1)
            end

            GUI:Unindent(5)
        end

        GUI:EndTabItem()
        end -- Tab3

        -- ========================================
        -- Tab 4: ME 触发器
        -- ========================================
        if GUI:BeginTabItem("ME触发器") then

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

            if State.meGeneratedCode ~= "" then
                GUI:Spacing()
                GUI:PushStyleColor(GUI.Col_FrameBg, 0.10, 0.08, 0.10, 0.95)
                GUI:PushItemWidth(-1)
                local lc = 1
                for _ in string.gmatch(State.meGeneratedCode, "\n") do lc = lc + 1 end
                local th = math.min(math.max(lc * 16 + 10, 80), 250)
                GUI:InputTextMultiline("##MECodeOut", State.meGeneratedCode, -1, th, GUI.InputTextFlags_ReadOnly)
                GUI:PopItemWidth()
                GUI:PopStyleColor(1)
            end

        GUI:EndTabItem()
        end -- Tab4

        GUI:EndTabBar()
        end -- TabBar

    end

    GUI:End()
    T.PopTheme()
end

d("[StringCore] ArgusBuilderUI.lua 加载完成")
