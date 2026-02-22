-- =============================================
-- MapEffectUI - 地图特效查看器
-- 使用 Argus API 获取并展示当前地图上的所有特效信息
-- =============================================

local M = StringGuide
if not M then return end

-- =============================================
-- 主题色
-- =============================================
local C = {
    title    = { 0.95, 0.75, 0.20, 1.0 },  -- 金色标题
    accent   = { 0.40, 0.75, 1.00, 1.0 },  -- 蓝色强调
    success  = { 0.30, 0.90, 0.40, 1.0 },  -- 绿色
    danger   = { 1.00, 0.40, 0.40, 1.0 },  -- 红色
    muted    = { 0.55, 0.55, 0.55, 1.0 },  -- 灰色
    dim      = { 0.40, 0.40, 0.40, 1.0 },  -- 暗灰
    white    = { 0.90, 0.90, 0.90, 1.0 },  -- 白色
    bg       = { 0.18, 0.18, 0.22, 1.0 },  -- 背景色
}

-- ResourceType / RenderType 配置
local TypeConfig = {
    [2] = { name = "Model",  color = { 0.55, 0.80, 1.00, 1.0 }, icon = "[M]" },
    [4] = { name = "VFX",    color = { 1.00, 0.55, 0.20, 1.0 }, icon = "[V]" },
    [6] = { name = "Script", color = { 0.30, 1.00, 0.60, 1.0 }, icon = "[S]" },
    [7] = { name = "Sound",  color = { 1.00, 0.85, 0.25, 1.0 }, icon = "[A]" },
}

local function GetTypeName(typeId)
    local cfg = TypeConfig[typeId]
    return cfg and cfg.name or ("Unknown(" .. tostring(typeId) .. ")")
end

local function GetTypeColor(typeId)
    local cfg = TypeConfig[typeId]
    return cfg and cfg.color or C.muted
end

local function GetTypeIcon(typeId)
    local cfg = TypeConfig[typeId]
    return cfg and cfg.icon or "[?]"
end

-- =============================================
-- UI 内部状态
-- =============================================
local State = {
    effects = {},           -- 缓存的特效列表
    selectedIndex = -1,     -- 当前选中的特效索引
    selectedResource = nil, -- 当前选中的 EffectResource
    filterText = "",        -- 搜索过滤文本
    filterType = 0,         -- 类型过滤 (0=全部)
    autoRefresh = true,     -- 自动刷新
    refreshInterval = 1.0,  -- 刷新间隔（秒）
    lastRefreshTime = 0,    -- 上次刷新时间
    -- runMapEffect 面板
    runIndex = 0,
    runA2 = 0,
    runFlags = 0,
    -- 编辑用临时值
    editPos = { x = 0, y = 0, z = 0 },
    editScale = { x = 1, y = 1, z = 1 },
    editOri = { dx = 0, dy = 0, dz = 0, ux = 0, uy = 1, uz = 0 },
    -- addPlayerMarker
    markerID = 0,
}

-- =============================================
-- 右键复制到剪切板
-- =============================================
local function CopyToClipboard(text)
    if GUI and GUI.SetClipboardText then
        GUI:SetClipboardText(tostring(text))
        d("[MapEffect] 已复制: " .. tostring(text))
    end
end

-- 在 GUI 元素之后调用，检测右键点击并复制
local function RightClickCopy(text)
    if GUI:IsItemClicked(1) then
        CopyToClipboard(text)
    end
    if GUI:IsItemHovered() then
        GUI:SetTooltip("右键复制")
    end
end

-- =============================================
-- 刷新特效数据
-- =============================================
local function RefreshEffects()
    State.effects = {}
    if not Argus then return end

    -- 方式1: 尝试 getCurrentMapEffects（返回结构化数据）
    if Argus.getCurrentMapEffects then
        local ok, mapEffects = pcall(Argus.getCurrentMapEffects)
        if ok and mapEffects then
            -- 尝试 ipairs 遍历
            local success, _ = pcall(function()
                for i, effectInfo in ipairs(mapEffects) do
                    local entry = {
                        index = effectInfo.index,
                        info = effectInfo.resource_info,
                        resource = nil,
                    }
                    if Argus.getMapEffectResource then
                        local ok2, res = pcall(Argus.getMapEffectResource, effectInfo.index)
                        if ok2 and res then
                            entry.resource = res
                        end
                    end
                    table.insert(State.effects, entry)
                end
            end)
            -- 如果 ipairs 成功且有数据，直接返回
            if success and #State.effects > 0 then
                return
            end
        end
    end

    -- 方式2: 回退到逐个获取（更兼容）
    State.effects = {}
    if not Argus.getNumCurrentMapEffects or not Argus.getMapEffectResource then return end

    local okN, num = pcall(Argus.getNumCurrentMapEffects)
    if not okN or not num or num <= 0 then return end

    for i = 0, num - 1 do
        local okR, res = pcall(Argus.getMapEffectResource, i)
        if okR and res then
            -- 获取基本信息
            local okI, id, path, resType, isActive = pcall(Argus.getEffectResourceInfo, res)
            if okI and id then
                -- 获取位置
                local px, py, pz = 0, 0, 0
                local okP, rpx, rpy, rpz = pcall(Argus.getEffectResourcePosition, res)
                if okP and rpx then px, py, pz = rpx, rpy, rpz end

                -- 获取渲染信息
                local renderType, renderState = nil, nil
                if Argus.getEffectResourceRenderInfo then
                    local okRR, rt, rs = pcall(Argus.getEffectResourceRenderInfo, res)
                    if okRR and rt then renderType, renderState = rt, rs end
                end

                local entry = {
                    index = i,
                    resource = res,
                    info = {
                        id = id,
                        path = path,
                        type = resType,
                        is_active = isActive,
                        position = { x = px, y = py, z = pz },
                        render_type = renderType,
                        render_state = renderState,
                    },
                }
                table.insert(State.effects, entry)
            end
        end
    end
end

-- =============================================
-- 过滤匹配
-- =============================================
local function MatchesFilter(entry)
    -- 类型过滤
    if State.filterType > 0 then
        if entry.info and entry.info.type ~= State.filterType then
            return false
        end
    end
    -- 文本过滤
    if State.filterText ~= "" then
        local keyword = string.lower(State.filterText)
        local path = entry.info and entry.info.path or ""
        local id = entry.info and tostring(entry.info.id) or ""
        local idx = tostring(entry.index)
        if not string.find(string.lower(path), keyword, 1, true)
           and not string.find(id, keyword, 1, true)
           and not string.find(idx, keyword, 1, true) then
            return false
        end
    end
    return true
end

-- =============================================
-- 构建条目摘要文本（用于复制全部信息）
-- =============================================
local function BuildEntrySummary(entry)
    local lines = {}
    local info = entry.info
    local res = entry.resource
    if not info then return "无数据" end

    table.insert(lines, "Index: " .. tostring(entry.index))
    table.insert(lines, "ID: " .. tostring(info.id))
    table.insert(lines, "Path: " .. tostring(info.path))
    table.insert(lines, "Type: " .. GetTypeName(info.type) .. " (" .. tostring(info.type) .. ")")
    table.insert(lines, "Active: " .. tostring(info.is_active))

    -- 位置（实时获取）
    if res and Argus.getEffectResourcePosition then
        local ok, px, py, pz = pcall(Argus.getEffectResourcePosition, res)
        if ok and px then
            table.insert(lines, string.format("Position: %.3f, %.3f, %.3f", px, py, pz))
        end
    elseif info.position then
        table.insert(lines, string.format("Position: %.3f, %.3f, %.3f",
            info.position.x or 0, info.position.y or 0, info.position.z or 0))
    end

    -- 缩放（实时获取）
    if res and Argus.getEffectResourceScale then
        local ok, sx, sy, sz = pcall(Argus.getEffectResourceScale, res)
        if ok and sx then
            table.insert(lines, string.format("Scale: %.3f, %.3f, %.3f", sx, sy, sz))
        end
    end

    -- 朝向（实时获取）
    if res and Argus.getEffectResourceOrientation then
        local ok, dx, dy, dz, ux, uy, uz = pcall(Argus.getEffectResourceOrientation, res)
        if ok and dx then
            table.insert(lines, string.format("Orientation: Dir(%.3f, %.3f, %.3f) Up(%.3f, %.3f, %.3f)",
                dx, dy, dz, ux, uy, uz))
        end
    end

    -- 渲染信息（实时获取）
    if res and Argus.getEffectResourceRenderInfo then
        local ok, rt, rs = pcall(Argus.getEffectResourceRenderInfo, res)
        if ok and rt then
            table.insert(lines, "RenderType: " .. GetTypeName(rt) .. " (" .. tostring(rt) .. ")")
            table.insert(lines, "RenderState: " .. tostring(rs))
        end
    elseif info.render_type then
        table.insert(lines, "RenderType: " .. GetTypeName(info.render_type) .. " (" .. tostring(info.render_type) .. ")")
        if info.render_state then
            table.insert(lines, "RenderState: " .. tostring(info.render_state))
        end
    end

    -- Flag 信息
    if Argus.getEffectResourceScriptFlagForIndex then
        local ok, flag = pcall(Argus.getEffectResourceScriptFlagForIndex, entry.index)
        if ok and flag then
            table.insert(lines, "ScriptFlag: " .. tostring(flag))
        end
    end

    -- 脚本信息（仅 Script 类型）
    if res and info.type == 6 then
        if Argus.getNumEffectResourceScripts then
            local ok, numScripts = pcall(Argus.getNumEffectResourceScripts, res)
            if ok and numScripts and numScripts > 0 then
                table.insert(lines, "--- Scripts (" .. numScripts .. ") ---")
                for si = 0, numScripts - 1 do
                    local okS, sName, numSub, scriptRes, isRunning =
                        pcall(Argus.getEffectResourceScriptInfo, res, si)
                    if okS and sName then
                        local status = isRunning and "Running" or "Stopped"
                        table.insert(lines, string.format("  Script[%d]: %s (%s, %d subresources)",
                            si, sName, status, numSub or 0))
                    end
                end
            end
        end

        -- 子资源
        if Argus.getNumEffectSubresources then
            local ok, numSub = pcall(Argus.getNumEffectSubresources, res)
            if ok and numSub and numSub > 0 then
                table.insert(lines, "--- Subresources (" .. numSub .. ") ---")
                for si = 0, numSub - 1 do
                    local okSR, subRes = pcall(Argus.getEffectSubresource, res, si)
                    if okSR and subRes then
                        local okI, sId, sPath, sType, sActive = pcall(Argus.getEffectResourceInfo, subRes)
                        if okI and sId then
                            local sTypeName = GetTypeName(sType)
                            local sActiveTag = sActive and "" or " [Inactive]"
                            table.insert(lines, string.format("  Sub[%d]: %s ID:%d %s%s",
                                si, sTypeName, sId, tostring(sPath), sActiveTag))
                            -- 子资源位置
                            local okP, spx, spy, spz = pcall(Argus.getEffectResourcePosition, subRes)
                            if okP and spx then
                                table.insert(lines, string.format("    Position: %.3f, %.3f, %.3f", spx, spy, spz))
                            end
                        end
                    end
                end
            end
        end
    end

    return table.concat(lines, "\n")
end

-- =============================================
-- 绘制子资源行（递归）
-- =============================================
local function DrawSubresourceRow(subRes, depth)
    depth = depth or 0
    if not subRes then return end

    local ok, id, path, resType, isActive = pcall(Argus.getEffectResourceInfo, subRes)
    if not ok or not id then return end

    local indent = string.rep("  ", depth)
    local tc = GetTypeColor(resType)
    local icon = GetTypeIcon(resType)
    local label = string.format("%s%s %d: %s", indent, icon, id, tostring(path))

    GUI:TextColored(tc[1], tc[2], tc[3], tc[4], label)
    RightClickCopy(tostring(path))

    -- 位置信息
    local ok2, px, py, pz = pcall(Argus.getEffectResourcePosition, subRes)
    if ok2 and px then
        local posText = string.format("%s   位置: %.2f, %.2f, %.2f", indent, px, py, pz)
        GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4], posText)
        RightClickCopy(string.format("%.3f, %.3f, %.3f", px, py, pz))
    end

    -- 如果子资源本身也是 Script 类型，递归展示其子资源
    if resType == 6 and Argus.getNumEffectSubresources then
        local ok3, numSub = pcall(Argus.getNumEffectSubresources, subRes)
        if ok3 and numSub and numSub > 0 then
            for si = 0, numSub - 1 do
                local ok4, childRes = pcall(Argus.getEffectSubresource, subRes, si)
                if ok4 and childRes then
                    DrawSubresourceRow(childRes, depth + 1)
                end
            end
        end
    end
end

-- =============================================
-- 绘制详情面板
-- =============================================
local function DrawDetailPanel(entry)
    if not entry or not entry.info then
        GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4], "选择一个特效查看详情")
        return
    end

    local info = entry.info
    local res = entry.resource

    -- 标题
    GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4],
        "特效详情 #" .. tostring(entry.index))
    GUI:Separator()
    GUI:Spacing()

    -- 基本信息
    local defaultOpenFlag = GUI.TreeNodeFlags_DefaultOpen or 32
    if GUI:CollapsingHeader("基本信息##Detail", defaultOpenFlag) then
        GUI:Indent(8)

        GUI:Text("Index: ")
        GUI:SameLine(0, 0)
        GUI:TextColored(C.accent[1], C.accent[2], C.accent[3], C.accent[4], tostring(entry.index))

        GUI:Text("ID: ")
        GUI:SameLine(0, 0)
        GUI:TextColored(C.accent[1], C.accent[2], C.accent[3], C.accent[4], tostring(info.id))
        RightClickCopy(tostring(info.id))

        GUI:Text("Path: ")
        GUI:SameLine(0, 0)
        GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4], tostring(info.path))
        RightClickCopy(tostring(info.path))

        local tc = GetTypeColor(info.type)
        GUI:Text("Type: ")
        GUI:SameLine(0, 0)
        GUI:TextColored(tc[1], tc[2], tc[3], tc[4],
            GetTypeIcon(info.type) .. " " .. GetTypeName(info.type) .. " (" .. tostring(info.type) .. ")")

        GUI:Text("Active: ")
        GUI:SameLine(0, 0)
        if info.is_active then
            GUI:TextColored(C.success[1], C.success[2], C.success[3], C.success[4], "是")
        else
            GUI:TextColored(C.danger[1], C.danger[2], C.danger[3], C.danger[4], "否")
        end

        -- RenderInfo（直接从 resource 实时获取）
        if res and Argus.getEffectResourceRenderInfo then
            local okR, renderType, renderState = pcall(Argus.getEffectResourceRenderInfo, res)
            if okR and renderType then
                local rtc = GetTypeColor(renderType)
                GUI:Text("RenderType: ")
                GUI:SameLine(0, 0)
                GUI:TextColored(rtc[1], rtc[2], rtc[3], rtc[4],
                    GetTypeName(renderType) .. " (" .. tostring(renderType) .. ")")
                GUI:Text("RenderState: ")
                GUI:SameLine(0, 0)
                GUI:TextColored(C.accent[1], C.accent[2], C.accent[3], C.accent[4], tostring(renderState))
            end
        elseif info.render_type then
            local rtc = GetTypeColor(info.render_type)
            GUI:Text("RenderType: ")
            GUI:SameLine(0, 0)
            GUI:TextColored(rtc[1], rtc[2], rtc[3], rtc[4],
                GetTypeName(info.render_type) .. " (" .. tostring(info.render_type) .. ")")
            if info.render_state then
                GUI:Text("RenderState: ")
                GUI:SameLine(0, 0)
                GUI:TextColored(C.accent[1], C.accent[2], C.accent[3], C.accent[4], tostring(info.render_state))
            end
        end

        GUI:Unindent(8)
    end

    GUI:Spacing()

    -- =============================================
    -- 位置 / 缩放 / 朝向 编辑
    -- =============================================
    if res then
        if GUI:CollapsingHeader("变换 (Position / Scale / Orientation)##Detail", defaultOpenFlag) then
            GUI:Indent(8)

            -- 位置
            local ok1, px, py, pz = pcall(Argus.getEffectResourcePosition, res)
            if ok1 and px then
                GUI:TextColored(C.accent[1], C.accent[2], C.accent[3], C.accent[4], "位置:")
                local posStr = string.format("%.3f, %.3f, %.3f", px, py, pz)
                GUI:Text("  " .. posStr)
                RightClickCopy(posStr)

                State.editPos.x = px
                State.editPos.y = py
                State.editPos.z = pz

                GUI:PushItemWidth(80)
                State.editPos.x = GUI:InputFloat("X##pos", State.editPos.x, 0.1, 1.0)
                GUI:SameLine()
                State.editPos.y = GUI:InputFloat("Y##pos", State.editPos.y, 0.1, 1.0)
                GUI:SameLine()
                State.editPos.z = GUI:InputFloat("Z##pos", State.editPos.z, 0.1, 1.0)
                GUI:PopItemWidth()

                GUI:SameLine()
                if GUI:Button("应用##pos") then
                    pcall(Argus.setEffectResourcePosition, res,
                        State.editPos.x, State.editPos.y, State.editPos.z)
                end
            end

            GUI:Spacing()

            -- 缩放
            local ok2, sx, sy, sz = pcall(Argus.getEffectResourceScale, res)
            if ok2 and sx then
                GUI:TextColored(C.accent[1], C.accent[2], C.accent[3], C.accent[4], "缩放:")
                local scaleStr = string.format("%.3f, %.3f, %.3f", sx, sy, sz)
                GUI:Text("  " .. scaleStr)
                RightClickCopy(scaleStr)

                State.editScale.x = sx
                State.editScale.y = sy
                State.editScale.z = sz

                GUI:PushItemWidth(80)
                State.editScale.x = GUI:InputFloat("X##scale", State.editScale.x, 0.1, 1.0)
                GUI:SameLine()
                State.editScale.y = GUI:InputFloat("Y##scale", State.editScale.y, 0.1, 1.0)
                GUI:SameLine()
                State.editScale.z = GUI:InputFloat("Z##scale", State.editScale.z, 0.1, 1.0)
                GUI:PopItemWidth()

                GUI:SameLine()
                if GUI:Button("应用##scale") then
                    pcall(Argus.setEffectResourceScale, res,
                        State.editScale.x, State.editScale.y, State.editScale.z)
                end
            end

            GUI:Spacing()

            -- 朝向
            local ok3, dx, dy, dz, ux, uy, uz = pcall(Argus.getEffectResourceOrientation, res)
            if ok3 and dx then
                GUI:TextColored(C.accent[1], C.accent[2], C.accent[3], C.accent[4], "朝向:")
                local oriStr = string.format("Dir(%.2f,%.2f,%.2f) Up(%.2f,%.2f,%.2f)", dx, dy, dz, ux, uy, uz)
                GUI:Text("  " .. oriStr)
                RightClickCopy(oriStr)

                State.editOri.dx = dx
                State.editOri.dy = dy
                State.editOri.dz = dz
                State.editOri.ux = ux
                State.editOri.uy = uy
                State.editOri.uz = uz

                GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4], "  Direction:")
                GUI:PushItemWidth(70)
                State.editOri.dx = GUI:InputFloat("dX##ori", State.editOri.dx, 0.1, 1.0)
                GUI:SameLine()
                State.editOri.dy = GUI:InputFloat("dY##ori", State.editOri.dy, 0.1, 1.0)
                GUI:SameLine()
                State.editOri.dz = GUI:InputFloat("dZ##ori", State.editOri.dz, 0.1, 1.0)
                GUI:PopItemWidth()

                GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4], "  Up:")
                GUI:PushItemWidth(70)
                State.editOri.ux = GUI:InputFloat("uX##ori", State.editOri.ux, 0.1, 1.0)
                GUI:SameLine()
                State.editOri.uy = GUI:InputFloat("uY##ori", State.editOri.uy, 0.1, 1.0)
                GUI:SameLine()
                State.editOri.uz = GUI:InputFloat("uZ##ori", State.editOri.uz, 0.1, 1.0)
                GUI:PopItemWidth()

                GUI:SameLine()
                if GUI:Button("应用##ori") then
                    pcall(Argus.setEffectResourceOrientation, res,
                        State.editOri.dx, State.editOri.dy, State.editOri.dz,
                        State.editOri.ux, State.editOri.uy, State.editOri.uz)
                end
            end

            GUI:Unindent(8)
        end

        GUI:Spacing()

        -- =============================================
        -- 脚本信息（仅 Script 类型 = 6）
        -- =============================================
        if info.type == 6 then
            if GUI:CollapsingHeader("脚本 (Scripts)##Detail") then
                GUI:Indent(8)

                local okN, numScripts = pcall(Argus.getNumEffectResourceScripts, res)
                if okN and numScripts and numScripts > 0 then
                    GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4],
                        "共 " .. numScripts .. " 个脚本")
                    GUI:Spacing()

                    for si = 0, numScripts - 1 do
                        local okS, sName, numSub, scriptRes, isRunning =
                            pcall(Argus.getEffectResourceScriptInfo, res, si)
                        if okS and sName then
                            -- 脚本标题行
                            local statusColor = isRunning and C.success or C.danger
                            local statusText = isRunning and "运行中" or "已停止"
                            local scriptLabel = string.format("[%d] %s (%s, %d 子资源)",
                                si, sName, statusText, numSub or 0)

                            GUI:TextColored(statusColor[1], statusColor[2], statusColor[3], statusColor[4], scriptLabel)
                            RightClickCopy(sName)

                            -- 启动/停止按钮
                            GUI:SameLine()
                            if isRunning then
                                if GUI:Button("停止##script" .. si) then
                                    pcall(Argus.stopEffectResourceScript, res, si)
                                end
                            else
                                if GUI:Button("启动##script" .. si) then
                                    pcall(Argus.startEffectResourceScript, res, si, 0)
                                end
                            end

                            -- 脚本子资源
                            if scriptRes and numSub and numSub > 0 then
                                for subI = 0, numSub - 1 do
                                    local okSub, subRes =
                                        pcall(Argus.getEffectResourceScriptSubresource, scriptRes, subI)
                                    if okSub and subRes then
                                        DrawSubresourceRow(subRes, 1)
                                    end
                                end
                            end
                            GUI:Spacing()
                        end
                    end
                else
                    GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4], "无脚本")
                end

                GUI:Unindent(8)
            end

            GUI:Spacing()

            -- =============================================
            -- 全部子资源列表
            -- =============================================
            if GUI:CollapsingHeader("全部子资源 (Subresources)##Detail") then
                GUI:Indent(8)

                local okNS, numAllSub = pcall(Argus.getNumEffectSubresources, res)
                if okNS and numAllSub and numAllSub > 0 then
                    GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4],
                        "共 " .. numAllSub .. " 个子资源")
                    GUI:Spacing()

                    for si = 0, numAllSub - 1 do
                        local okSR, subRes = pcall(Argus.getEffectSubresource, res, si)
                        if okSR and subRes then
                            DrawSubresourceRow(subRes, 0)
                        end
                    end
                else
                    GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4], "无子资源")
                end

                GUI:Unindent(8)
            end
        end -- type == 6
    end -- res

    GUI:Spacing()
    GUI:Separator()

    -- 复制全部信息按钮
    if GUI:Button("复制全部信息##detail", 140, 25) then
        CopyToClipboard(BuildEntrySummary(entry))
    end
end

-- =============================================
-- 主绘制函数
-- =============================================
M.DrawMapEffectUI = function()
    GUI:SetNextWindowSize(700, 550, GUI.SetCond_Appearing)

    local windowTitle = "Map Effect 查看器###MapEffectWindow"
    M.MapEffectUI.visible, M.MapEffectUI.open = GUI:Begin(windowTitle, M.MapEffectUI.open)

    if M.MapEffectUI.visible then

        -- =============================================
        -- 自动刷新逻辑（必须在 UI 控件外部，确保始终执行）
        -- =============================================
        if State.autoRefresh then
            local now = os.clock()
            if now - State.lastRefreshTime >= State.refreshInterval then
                State.lastRefreshTime = now
                RefreshEffects()
            end
        end

        -- =============================================
        -- 刷新控制（始终显示，不放在 CollapsingHeader 内）
        -- =============================================
        if GUI:Button("刷新##ME", 70, 22) then
            RefreshEffects()
        end
        GUI:SameLine()
        State.autoRefresh = GUI:Checkbox("自动刷新##ME", State.autoRefresh)

        if State.autoRefresh then
            GUI:SameLine()
            GUI:PushItemWidth(80)
            State.refreshInterval = GUI:InputFloat("间隔(秒)##ME", State.refreshInterval, 0.5, 1.0)
            GUI:PopItemWidth()
            if State.refreshInterval < 0.1 then State.refreshInterval = 0.1 end
        end

        GUI:Spacing()

        -- =============================================
        -- 搜索和类型过滤（始终显示）
        -- =============================================
        GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4], "搜索:")
        GUI:SameLine()
        GUI:PushItemWidth(200)
        State.filterText = GUI:InputText("##MEFilter", State.filterText)
        GUI:PopItemWidth()

        GUI:SameLine(0, 15)
        GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4], "类型:")
        GUI:SameLine()
        GUI:PushItemWidth(120)
        local typeNames = { "全部", "Model(2)", "VFX(4)", "Script(6)", "Sound(7)" }
        local typeValues = { 0, 2, 4, 6, 7 }
        local currentTypeIdx = 1
        for i, v in ipairs(typeValues) do
            if v == State.filterType then currentTypeIdx = i break end
        end
        local newTypeIdx = GUI:Combo("##METypeFilter", currentTypeIdx, typeNames)
        if newTypeIdx ~= currentTypeIdx then
            State.filterType = typeValues[newTypeIdx] or 0
        end
        GUI:PopItemWidth()

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- runMapEffect 手动执行面板
        -- =============================================
        if GUI:CollapsingHeader("手动执行 runMapEffect##MERunPanel") then
            GUI:Indent(8)

            GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4],
                "Argus.runMapEffect(index, a2, flags)")
            GUI:Spacing()

            GUI:PushItemWidth(100)
            State.runIndex = GUI:InputInt("Index##run", State.runIndex)
            GUI:SameLine()
            State.runA2 = GUI:InputInt("A2##run", State.runA2)
            GUI:SameLine()
            State.runFlags = GUI:InputInt("Flags##run", State.runFlags)
            GUI:PopItemWidth()

            GUI:Spacing()

            if GUI:Button("执行##runME", 80, 25) then
                if Argus and Argus.runMapEffect then
                    local ok, err = pcall(Argus.runMapEffect, State.runIndex, State.runA2, State.runFlags)
                    if ok then
                        d("[MapEffect] runMapEffect 执行成功: " .. State.runIndex .. ", " .. State.runA2 .. ", " .. State.runFlags)
                    else
                        d("[MapEffect] runMapEffect 执行失败: " .. tostring(err))
                    end
                end
            end

            GUI:SameLine()
            if GUI:Button("自动Flag##runME", 90, 25) then
                if Argus and Argus.getEffectResourceScriptFlagForIndex then
                    local ok, flag = pcall(Argus.getEffectResourceScriptFlagForIndex, State.runIndex)
                    if ok and flag then
                        State.runFlags = flag
                        d("[MapEffect] 自动获取 Flag: " .. tostring(flag))
                    end
                end
            end
            if GUI:IsItemHovered() then
                GUI:SetTooltip("根据 Index 自动获取对应的 Script Flag\n(getEffectResourceScriptFlagForIndex)")
            end

            GUI:SameLine()
            if GUI:Button("Flag→Index##runME", 90, 25) then
                if Argus and Argus.getEffectResourceScriptIndexForFlag then
                    local ok, idx = pcall(Argus.getEffectResourceScriptIndexForFlag, State.runFlags)
                    if ok and idx then
                        State.runIndex = idx
                        d("[MapEffect] Flag→Index: " .. tostring(idx))
                    end
                end
            end
            if GUI:IsItemHovered() then
                GUI:SetTooltip("根据 Flag 反向查询对应的 Index\n(getEffectResourceScriptIndexForFlag)")
            end

            GUI:Unindent(8)
        end

        GUI:Spacing()

        -- =============================================
        -- addPlayerMarker 面板
        -- =============================================
        if GUI:CollapsingHeader("添加玩家标记 addPlayerMarker##MEMarker") then
            GUI:Indent(8)

            GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4],
                "Argus.addPlayerMarker(markerID)")
            GUI:Spacing()

            GUI:PushItemWidth(100)
            State.markerID = GUI:InputInt("MarkerID##marker", State.markerID)
            GUI:PopItemWidth()

            GUI:SameLine()
            if GUI:Button("添加标记##marker", 90, 25) then
                if Argus and Argus.addPlayerMarker then
                    local ok, err = pcall(Argus.addPlayerMarker, State.markerID)
                    if ok then
                        d("[MapEffect] addPlayerMarker 成功: " .. tostring(State.markerID))
                    else
                        d("[MapEffect] addPlayerMarker 失败: " .. tostring(err))
                    end
                end
            end

            GUI:Unindent(8)
        end

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 特效列表 + 详情面板（左右分栏）
        -- =============================================
        local numTotal = Argus and Argus.getNumCurrentMapEffects and Argus.getNumCurrentMapEffects() or 0
        local filteredCount = 0
        for _, e in ipairs(State.effects) do
            if MatchesFilter(e) then filteredCount = filteredCount + 1 end
        end

        GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4],
            "当前特效: " .. filteredCount .. " / " .. numTotal)
        GUI:Spacing()

        -- =============================================
        -- 特效列表（平铺显示，点击展开详情）
        -- =============================================
        GUI:BeginChild("##MEListAll", 0, 0, true)

        for i, entry in ipairs(State.effects) do
            if MatchesFilter(entry) then
                local info = entry.info
                local tc = GetTypeColor(info and info.type or 0)
                local icon = GetTypeIcon(info and info.type or 0)
                local typeName = GetTypeName(info and info.type or 0)
                local activeTag = (info and info.is_active) and "" or " [Inactive]"
                -- 提取文件名
                local fileName = info and info.path or ""
                local shortName = string.match(fileName, "[^/\\]+$") or fileName

                local label = string.format("[%d] %s  ID:%d  %s%s",
                    entry.index, typeName, info and info.id or 0, shortName, activeTag)

                -- 用 Selectable 实现选中高亮
                local isSelected = (State.selectedIndex == entry.index)
                GUI:TextColored(tc[1], tc[2], tc[3], tc[4], label)

                -- 左键选中/取消
                if GUI:IsItemClicked(0) then
                    if State.selectedIndex == entry.index then
                        State.selectedIndex = -1
                        State.selectedResource = nil
                    else
                        State.selectedIndex = entry.index
                        State.selectedResource = entry.resource
                    end
                end

                -- 右键复制完整信息
                if GUI:IsItemClicked(1) then
                    CopyToClipboard(BuildEntrySummary(entry))
                end

                -- 悬停提示
                if GUI:IsItemHovered() then
                    GUI:SetTooltip(fileName .. "\n右键复制完整信息")
                end

                -- 选中时展开详情
                if isSelected then
                    GUI:Indent(16)
                    DrawDetailPanel(entry)
                    GUI:Unindent(16)
                    GUI:Spacing()
                end
            end
        end

        GUI:EndChild()

    end

    GUI:End()
end

d("[StringCore] MapEffectUI.lua 加载完成")
