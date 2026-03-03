-- =============================================
-- ArgusBuilderUI - Argus 绘图代码生成器
-- 可视化选择形状、颜色、参数，一键预览/生成代码/复制/测试
-- =============================================

local M = StringGuide
if not M then return end

-- =============================================
-- 主题色
-- =============================================
local C = {
    title    = { 0.95, 0.75, 0.20, 1.0 },
    accent   = { 0.40, 0.75, 1.00, 1.0 },
    success  = { 0.30, 0.90, 0.40, 1.0 },
    danger   = { 1.00, 0.40, 0.40, 1.0 },
    muted    = { 0.55, 0.55, 0.55, 1.0 },
    white    = { 0.90, 0.90, 0.90, 1.0 },
    hint     = { 0.70, 0.70, 0.70, 1.0 },
    section  = { 0.65, 0.85, 1.00, 1.0 },
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

    -- 生成的代码
    generatedCode = "",

    -- 预览 UUID 列表（用于清理）
    previewUUIDs = {},

    -- 日志
    lastLog = "",
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
        if sid == "Line" then
            table.insert(lines, string.format("local x1, y1, z1 = %s, %s, %s",
                FormatNum(State.posX), FormatNum(State.posY), FormatNum(State.posZ)))
            table.insert(lines, string.format("local x2, y2, z2 = %s, %s, %s",
                FormatNum(State.pos2X), FormatNum(State.pos2Y), FormatNum(State.pos2Z)))
        else
            table.insert(lines, string.format("local x, y, z = %s, %s, %s",
                FormatNum(State.posX), FormatNum(State.posY), FormatNum(State.posZ)))
        end
        table.insert(lines, "")
    end

    -- 朝向
    local needsHeading = (sid == "Cone" or sid == "Rect" or sid == "CenteredRect"
        or sid == "DonutCone" or sid == "Cross" or sid == "Arrow" or sid == "Chevron")
    if needsHeading and not isOnEnt then
        table.insert(lines, string.format("local heading = math.rad(%s)  -- %s°", FormatNum(State.heading), FormatNum(State.heading)))
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
            local fillColor = FormatColor(State.fillR, State.fillG, State.fillB, State.fillA)
            local outlineColor = FormatColor(State.outlineR, State.outlineG, State.outlineB, State.outlineA)
            local startColor = FormatColor(State.startR, State.startG, State.startB, State.startA)
            local midColor = FormatColor(State.midR, State.midG, State.midB, State.midA)
            table.insert(lines, "-- 创建渐变色绘图器")
            table.insert(lines, string.format("local drawer = Argus2.ShapeDrawer:new(\n    %s,  -- 起始颜色\n    %s,  -- 中间颜色\n    %s,  -- 结束颜色\n    %s,  -- 描边颜色\n    %s  -- 描边粗细\n)",
                startColor, midColor, fillColor, outlineColor, FormatNum(State.outlineThickness)))
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
-- 主绘制函数
-- =============================================
M.DrawArgusBuilderUI = function()

    GUI:SetNextWindowSize(520, 700, GUI.SetCond_Appearing)
    M.ArgusBuilderUI.visible, M.ArgusBuilderUI.open = GUI:Begin("Argus 绘图代码生成器###ArgusBuilderWindow", M.ArgusBuilderUI.open)

    if M.ArgusBuilderUI.visible then

        -- =============================================
        -- 1. 形状选择
        -- =============================================
        GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4], "形状选择")
        GUI:Spacing()

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
                    string.format("朝向: %.1f", State.heading))
            else
                State.heading = GUI:SliderFloat("朝向 (度)##ArgusHeading", State.heading, -180, 180)
            end
        end

        GUI:PopItemWidth()

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 5. 颜色设置
        -- =============================================
        if GUI:CollapsingHeader("颜色设置##ArgusColors") then
            GUI:Indent(5)

            State.useMoogleDrawer = GUI:Checkbox("使用默认配色 (MoogleDrawer)##ArgusMoogle", State.useMoogleDrawer)
            if GUI:IsItemHovered() then
                GUI:SetTooltip("勾选后使用 TensorCore.getMoogleDrawer() 的蓝紫渐变配色")
            end

            if not State.useMoogleDrawer then
                GUI:Spacing()

                -- 填充颜色
                GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "填充颜色:")
                DrawColorPicker("填充", "fillR", "fillG", "fillB", "fillA")
                DrawPresetButtons("fillR", "fillG", "fillB", "fillA")

                GUI:Spacing()

                -- 描边颜色
                GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "描边颜色:")
                DrawColorPicker("描边", "outlineR", "outlineG", "outlineB", "outlineA")
                GUI:PushItemWidth(150)
                State.outlineThickness = GUI:SliderFloat("描边粗细##ArgusOT", State.outlineThickness, 0.5, 5)
                GUI:PopItemWidth()

                GUI:Spacing()

                -- 渐变色选项
                State.useGradient = GUI:Checkbox("启用渐变色##ArgusGrad", State.useGradient)
                if State.useGradient then
                    GUI:Indent(10)
                    GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "起始颜色:")
                    DrawColorPicker("起始", "startR", "startG", "startB", "startA")
                    DrawPresetButtons("startR", "startG", "startB", "startA")

                    GUI:Spacing()

                    GUI:TextColored(C.section[1], C.section[2], C.section[3], C.section[4], "中间颜色:")
                    DrawColorPicker("中间", "midR", "midG", "midB", "midA")
                    DrawPresetButtons("midR", "midG", "midB", "midA")
                    GUI:Unindent(10)
                end
            else
                GUI:TextColored(C.hint[1], C.hint[2], C.hint[3], C.hint[4], "  当前使用 TensorCore 预设蓝紫渐变配色")
            end

            GUI:Unindent(5)
        end

        GUI:Spacing()

        -- =============================================
        -- 6. 高级参数（折叠）
        -- =============================================
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

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 7. 操作按钮
        -- =============================================
        GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4], "操作")
        GUI:Spacing()

        -- 生成代码按钮
        GUI:PushStyleColor(GUI.Col_Button, 0.2, 0.5, 0.8, 0.9)
        GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.3, 0.6, 0.9, 1.0)
        GUI:PushStyleColor(GUI.Col_ButtonActive, 0.15, 0.4, 0.7, 1.0)
        if GUI:Button("生成代码##ArgusGen", 100, 30) then
            SyncPlayerPos()
            GenerateCode()
            State.lastLog = "代码已生成"
        end
        GUI:PopStyleColor(3)

        GUI:SameLine(0, 8)

        -- 复制代码按钮
        GUI:PushStyleColor(GUI.Col_Button, 0.2, 0.7, 0.3, 0.9)
        GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.3, 0.8, 0.4, 1.0)
        GUI:PushStyleColor(GUI.Col_ButtonActive, 0.15, 0.6, 0.25, 1.0)
        if GUI:Button("复制代码##ArgusCopy", 100, 30) then
            if State.generatedCode == "" then
                SyncPlayerPos()
                GenerateCode()
            end
            CopyToClipboard(State.generatedCode)
        end
        GUI:PopStyleColor(3)

        GUI:SameLine(0, 8)

        -- 预览按钮
        GUI:PushStyleColor(GUI.Col_Button, 0.7, 0.5, 0.1, 0.9)
        GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.8, 0.6, 0.2, 1.0)
        GUI:PushStyleColor(GUI.Col_ButtonActive, 0.6, 0.4, 0.05, 1.0)
        if GUI:Button("预览绘图##ArgusPreview", 100, 30) then
            SyncPlayerPos()
            ExecutePreview()
        end
        GUI:PopStyleColor(3)

        GUI:SameLine(0, 8)

        -- 清除预览按钮
        GUI:PushStyleColor(GUI.Col_Button, 0.7, 0.2, 0.2, 0.9)
        GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.8, 0.3, 0.3, 1.0)
        GUI:PushStyleColor(GUI.Col_ButtonActive, 0.6, 0.15, 0.15, 1.0)
        if GUI:Button("清除##ArgusClear", 70, 30) then
            for _, uuid in ipairs(State.previewUUIDs) do
                if Argus and Argus.deleteTimedShape then
                    Argus.deleteTimedShape(uuid)
                end
            end
            State.previewUUIDs = {}
            State.lastLog = "已清除所有预览"
        end
        GUI:PopStyleColor(3)

        -- 日志
        if State.lastLog ~= "" then
            GUI:Spacing()
            GUI:TextColored(C.success[1], C.success[2], C.success[3], C.success[4], State.lastLog)
        end

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 8. 生成的代码展示
        -- =============================================
        GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4], "生成的代码")
        GUI:Spacing()

        if State.generatedCode ~= "" then
            -- 代码展示区
            GUI:PushStyleColor(GUI.Col_FrameBg, 0.1, 0.1, 0.15, 0.95)
            GUI:PushItemWidth(-1)  -- 填满宽度

            -- 计算文本行数来设置高度
            local lineCount = 1
            for _ in string.gmatch(State.generatedCode, "\n") do
                lineCount = lineCount + 1
            end
            local textHeight = math.max(lineCount * 16 + 10, 100)
            if textHeight > 300 then textHeight = 300 end

            GUI:InputTextMultiline("##ArgusCodeOutput", State.generatedCode, -1, textHeight, GUI.InputTextFlags_ReadOnly)

            GUI:PopItemWidth()
            GUI:PopStyleColor(1)

            GUI:Spacing()

            -- 快速操作
            if GUI:Button("复制全部##ArgusCopyAll", 100, 24) then
                CopyToClipboard(State.generatedCode)
            end
            GUI:SameLine(0, 8)
            if GUI:Button("重新生成##ArgusRegen", 100, 24) then
                SyncPlayerPos()
                GenerateCode()
                State.lastLog = "代码已重新生成"
            end
        else
            GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4], "点击「生成代码」按钮生成 Lua 代码")
        end

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 9. 使用说明（折叠）
        -- =============================================
        if GUI:CollapsingHeader("使用说明##ArgusHelp") then
            GUI:Indent(5)

            GUI:TextColored(C.accent[1], C.accent[2], C.accent[3], C.accent[4], "基本流程:")
            GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], "  1. 选择形状和绘图模式")
            GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], "  2. 调整形状参数和颜色")
            GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], "  3. 点击「预览绘图」查看效果")
            GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], "  4. 满意后「生成代码」→「复制代码」")
            GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], "  5. 粘贴到 TensorReactions 触发器中使用")

            GUI:Spacing()

            GUI:TextColored(C.accent[1], C.accent[2], C.accent[3], C.accent[4], "模式说明:")
            GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], "  ShapeDrawer: 推荐，封装颜色和渐变，接口简洁")
            GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], "  Argus2 底层: 更灵活但参数更多")
            GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], "  Timed: 绘图持续指定时间，用于单次触发器")
            GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], "  OnFrame: 每帧绘制，用于 OnFrame 事件")
            GUI:TextColored(C.danger[1], C.danger[2], C.danger[3], C.danger[4], "  禁止在 OnFrame 中使用 Timed 方法!")

            GUI:Spacing()

            GUI:TextColored(C.accent[1], C.accent[2], C.accent[3], C.accent[4], "附着方式:")
            GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], "  坐标: 图形固定在指定位置")
            GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], "  OnEnt: 图形跟随实体移动")

            GUI:Unindent(5)
        end

    end

    GUI:End()
end

d("[StringCore] ArgusBuilderUI.lua 加载完成")
