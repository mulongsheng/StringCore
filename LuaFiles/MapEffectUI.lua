-- =============================================
-- MapEffectUI - 地图特效查看器
-- 使用 Argus API 获取并展示当前地图上的所有特效信息
-- =============================================

local M = StringGuide
if not M then return end

-- MapEffect UI 状态
M.MapEffectUI = {
    open = false,
    visible = false,
    -- 自动刷新
    autoRefresh = true,
    refreshInterval = 1.0, -- 秒
    lastRefreshTime = 0,
    -- 缓存数据
    cachedEffects = {},
    cachedCount = 0,
    -- 选中的特效索引（用于详情面板）
    selectedIndex = -1,
    -- 展开的脚本节点（key = "effectIdx_scriptIdx"）
    expandedScripts = {},
    -- 过滤
    filterText = "",
    filterType = 0, -- 0=全部, 2=Model, 4=VFX, 6=Script, 7=Sound
    -- 位置/缩放/朝向编辑
    editPos = { x = 0, y = 0, z = 0 },
    editScale = { x = 1, y = 1, z = 1 },
    editOrientDir = { x = 0, y = 0, z = 0 },
    editOrientUp = { x = 0, y = 1, z = 0 },
    editingEntry = -1, -- 当前正在编辑的特效索引，-1表示未编辑
    -- 脚本启动 time 参数
    scriptStartTime = 0,
    -- addPlayerMarker
    markerID = 0,
}

-- ResourceType 名称映射
local ResourceTypeNames = {
    [2] = "Model",
    [4] = "VFX",
    [6] = "Script",
    [7] = "Sound",
}

-- ResourceType 颜色映射
local ResourceTypeColors = {
    [2] = { 0.6, 0.8, 1.0, 1.0 },  -- 蓝色 Model
    [4] = { 1.0, 0.6, 0.2, 1.0 },  -- 橙色 VFX
    [6] = { 0.2, 1.0, 0.6, 1.0 },  -- 绿色 Script
    [7] = { 1.0, 0.8, 0.2, 1.0 },  -- 黄色 Sound
}

local function GetTypeName(typeId)
    return ResourceTypeNames[typeId] or ("Unknown(" .. tostring(typeId) .. ")")
end

local function GetTypeColor(typeId)
    return ResourceTypeColors[typeId] or { 0.7, 0.7, 0.7, 1.0 }
end

-- =============================================
-- 数据刷新
-- =============================================
local function RefreshEffects(ui)
    if not Argus then
        ui.cachedEffects = {}
        ui.cachedCount = 0
        return
    end

    local effects = {}
    local numEffects = Argus.getNumCurrentMapEffects()
    ui.cachedCount = numEffects

    -- 优先尝试 getCurrentMapEffects() 批量获取
    local bulkEffects = Argus.getCurrentMapEffects()

    for i = 0, numEffects - 1 do
        local effectRes = Argus.getMapEffectResource(i)
        if effectRes then
            local resId, resPath, resType, isActive = Argus.getEffectResourceInfo(effectRes)
            local px, py, pz = Argus.getEffectResourcePosition(effectRes)
            local renderType, renderState = Argus.getEffectResourceRenderInfo(effectRes)
            local sx, sy, sz = Argus.getEffectResourceScale(effectRes)
            local dx, dy, dz, ux, uy, uz = Argus.getEffectResourceOrientation(effectRes)

            -- 从批量数据中补充信息（如果可用）
            local bulkInfo = nil
            if bulkEffects then
                for _, be in ipairs(bulkEffects) do
                    if be.index == i then
                        bulkInfo = be
                        break
                    end
                end
            end

            local entry = {
                index = i,
                resource = effectRes,
                id = resId,
                path = resPath or "",
                type = resType,
                isActive = isActive,
                position = { x = px or 0, y = py or 0, z = pz or 0 },
                scale = { x = sx or 1, y = sy or 1, z = sz or 1 },
                orientation = {
                    dir = { x = dx or 0, y = dy or 0, z = dz or 0 },
                    up = { x = ux or 0, y = uy or 1, z = uz or 0 },
                },
                renderType = renderType,
                renderState = renderState,
                scripts = {},
                subresources = {},
            }

            -- 如果是 Script 类型 (6)，获取脚本和子资源信息
            if resType == 6 then
                local numScripts = Argus.getNumEffectResourceScripts(effectRes)
                for si = 0, numScripts - 1 do
                    local sName, numSub, scriptRes, isRunning = Argus.getEffectResourceScriptInfo(effectRes, si)
                    local scriptEntry = {
                        index = si,
                        name = sName or "unknown",
                        numSubresources = numSub,
                        scriptResource = scriptRes,
                        isRunning = isRunning,
                        subresources = {},
                    }
                    -- 获取脚本的子资源
                    if scriptRes and numSub > 0 then
                        for subi = 0, numSub - 1 do
                            local subRes = Argus.getEffectResourceScriptSubresource(scriptRes, subi)
                            if subRes then
                                local subId, subPath, subType, subActive = Argus.getEffectResourceInfo(subRes)
                                local spx, spy, spz = Argus.getEffectResourcePosition(subRes)
                                table.insert(scriptEntry.subresources, {
                                    index = subi,
                                    resource = subRes,
                                    id = subId,
                                    path = subPath or "",
                                    type = subType,
                                    isActive = subActive,
                                    position = { x = spx or 0, y = spy or 0, z = spz or 0 },
                                })
                            end
                        end
                    end
                    table.insert(entry.scripts, scriptEntry)
                end

                -- 获取完整子资源列表
                local numFullSub = Argus.getNumEffectSubresources(effectRes)
                for fi = 0, numFullSub - 1 do
                    local fRes = Argus.getEffectSubresource(effectRes, fi)
                    if fRes then
                        local fId, fPath, fType, fActive = Argus.getEffectResourceInfo(fRes)
                        local fpx, fpy, fpz = Argus.getEffectResourcePosition(fRes)
                        table.insert(entry.subresources, {
                            index = fi,
                            resource = fRes,
                            id = fId,
                            path = fPath or "",
                            type = fType,
                            isActive = fActive,
                            position = { x = fpx or 0, y = fpy or 0, z = fpz or 0 },
                        })
                    end
                end
            end

            table.insert(effects, entry)
        end
    end

    ui.cachedEffects = effects
end

-- =============================================
-- 过滤逻辑
-- =============================================
local function MatchesFilter(entry, filterText, filterType)
    -- 类型过滤
    if filterType ~= 0 and entry.type ~= filterType then
        return false
    end
    -- 文本过滤（路径或ID）
    if filterText ~= "" then
        local lower = string.lower(filterText)
        local pathMatch = string.find(string.lower(entry.path), lower, 1, true)
        local idMatch = string.find(tostring(entry.id), filterText, 1, true)
        if not pathMatch and not idMatch then
            return false
        end
    end
    return true
end

-- =============================================
-- 绘制子资源信息行
-- =============================================
local function DrawSubresourceRow(sub, prefix)
    local col = GetTypeColor(sub.type)
    GUI:TextColored(col[1], col[2], col[3], col[4], prefix .. GetTypeName(sub.type))
    GUI:SameLine(0, 5)
    GUI:TextColored(0.7, 0.7, 0.7, 1.0,
        string.format("ID:%d  Pos:(%.1f, %.1f, %.1f)  %s",
            sub.id or 0,
            sub.position.x, sub.position.y, sub.position.z,
            sub.isActive and "Active" or "Inactive"))
    -- 路径（悬停显示完整路径）
    if sub.path ~= "" then
        -- 只显示文件名部分
        local shortPath = string.match(sub.path, "[^/\\]+$") or sub.path
        GUI:SameLine(0, 5)
        GUI:TextColored(0.5, 0.5, 0.5, 1.0, shortPath)
        if GUI:IsItemHovered() then
            GUI:SetTooltip(sub.path)
        end
    end
end

-- =============================================
-- 绘制详情面板
-- =============================================
local function DrawDetailPanel(entry, ui)
    GUI:Separator()
    GUI:Spacing()
    GUI:TextColored(1.0, 0.8, 0.2, 1.0, "===== 特效详情 =====")
    GUI:Spacing()

    -- 基本信息
    GUI:Text("索引: " .. tostring(entry.index))
    GUI:Text("资源 ID: " .. tostring(entry.id))

    local col = GetTypeColor(entry.type)
    GUI:Text("类型: ")
    GUI:SameLine(0, 0)
    GUI:TextColored(col[1], col[2], col[3], col[4], GetTypeName(entry.type))

    GUI:Text("状态: ")
    GUI:SameLine(0, 0)
    if entry.isActive then
        GUI:TextColored(0.2, 1.0, 0.2, 1.0, "Active")
    else
        GUI:TextColored(1.0, 0.4, 0.4, 1.0, "Inactive")
    end

    GUI:Text("渲染类型: " .. GetTypeName(entry.renderType or 0))
    GUI:Text("渲染状态: " .. tostring(entry.renderState or 0))

    -- Flag / Index 转换信息
    local flag = Argus.getEffectResourceScriptFlagForIndex(entry.index)
    local idxFromFlag = Argus.getEffectResourceScriptIndexForFlag(flag)
    GUI:Text("Script Flag: " .. tostring(flag) .. "  (Flag→Index: " .. tostring(idxFromFlag) .. ")")

    -- 路径
    GUI:Text("路径: ")
    GUI:SameLine(0, 0)
    GUI:TextColored(0.5, 0.8, 1.0, 1.0, entry.path ~= "" and entry.path or "(无)")

    GUI:Spacing()
    GUI:Separator()

    -- =============================================
    -- 位置编辑
    -- =============================================
    GUI:TextColored(1.0, 0.8, 0.2, 1.0, "位置:")
    GUI:Text(string.format("  当前: X=%.3f  Y=%.3f  Z=%.3f", entry.position.x, entry.position.y, entry.position.z))

    -- 如果刚选中或切换了特效，同步编辑值
    if ui.editingEntry ~= entry.index then
        ui.editingEntry = entry.index
        ui.editPos = { x = entry.position.x, y = entry.position.y, z = entry.position.z }
        ui.editScale = { x = entry.scale.x, y = entry.scale.y, z = entry.scale.z }
        ui.editOrientDir = { x = entry.orientation.dir.x, y = entry.orientation.dir.y, z = entry.orientation.dir.z }
        ui.editOrientUp = { x = entry.orientation.up.x, y = entry.orientation.up.y, z = entry.orientation.up.z }
    end

    GUI:PushItemWidth(80)
    ui.editPos.x = GUI:InputFloat("X##pos", ui.editPos.x, 0.1, 1.0)
    GUI:SameLine()
    ui.editPos.y = GUI:InputFloat("Y##pos", ui.editPos.y, 0.1, 1.0)
    GUI:SameLine()
    ui.editPos.z = GUI:InputFloat("Z##pos", ui.editPos.z, 0.1, 1.0)
    GUI:PopItemWidth()

    GUI:SameLine()
    if GUI:SmallButton("应用位置##setpos") then
        local ok = Argus.setEffectResourcePosition(entry.resource, ui.editPos.x, ui.editPos.y, ui.editPos.z)
        d("[MapEffect] setPosition: " .. tostring(ok))
    end

    GUI:Spacing()

    -- =============================================
    -- 缩放编辑
    -- =============================================
    GUI:TextColored(1.0, 0.8, 0.2, 1.0, "缩放:")
    GUI:Text(string.format("  当前: X=%.3f  Y=%.3f  Z=%.3f", entry.scale.x, entry.scale.y, entry.scale.z))

    GUI:PushItemWidth(80)
    ui.editScale.x = GUI:InputFloat("X##scale", ui.editScale.x, 0.1, 1.0)
    GUI:SameLine()
    ui.editScale.y = GUI:InputFloat("Y##scale", ui.editScale.y, 0.1, 1.0)
    GUI:SameLine()
    ui.editScale.z = GUI:InputFloat("Z##scale", ui.editScale.z, 0.1, 1.0)
    GUI:PopItemWidth()

    GUI:SameLine()
    if GUI:SmallButton("应用缩放##setscale") then
        local ok = Argus.setEffectResourceScale(entry.resource, ui.editScale.x, ui.editScale.y, ui.editScale.z)
        d("[MapEffect] setScale: " .. tostring(ok))
    end

    GUI:Spacing()

    -- =============================================
    -- 朝向编辑
    -- =============================================
    GUI:TextColored(1.0, 0.8, 0.2, 1.0, "朝向:")
    GUI:Text(string.format("  Dir: (%.3f, %.3f, %.3f)", entry.orientation.dir.x, entry.orientation.dir.y, entry.orientation.dir.z))
    GUI:Text(string.format("  Up:  (%.3f, %.3f, %.3f)", entry.orientation.up.x, entry.orientation.up.y, entry.orientation.up.z))

    GUI:Text("Direction:")
    GUI:PushItemWidth(80)
    ui.editOrientDir.x = GUI:InputFloat("dX##orient", ui.editOrientDir.x, 0.1, 1.0)
    GUI:SameLine()
    ui.editOrientDir.y = GUI:InputFloat("dY##orient", ui.editOrientDir.y, 0.1, 1.0)
    GUI:SameLine()
    ui.editOrientDir.z = GUI:InputFloat("dZ##orient", ui.editOrientDir.z, 0.1, 1.0)
    GUI:PopItemWidth()

    GUI:Text("Up:")
    GUI:PushItemWidth(80)
    ui.editOrientUp.x = GUI:InputFloat("uX##orient", ui.editOrientUp.x, 0.1, 1.0)
    GUI:SameLine()
    ui.editOrientUp.y = GUI:InputFloat("uY##orient", ui.editOrientUp.y, 0.1, 1.0)
    GUI:SameLine()
    ui.editOrientUp.z = GUI:InputFloat("uZ##orient", ui.editOrientUp.z, 0.1, 1.0)
    GUI:PopItemWidth()

    if GUI:SmallButton("应用朝向##setorient") then
        local ok = Argus.setEffectResourceOrientation(entry.resource,
            ui.editOrientDir.x, ui.editOrientDir.y, ui.editOrientDir.z,
            ui.editOrientUp.x, ui.editOrientUp.y, ui.editOrientUp.z)
        d("[MapEffect] setOrientation: " .. tostring(ok))
    end

    GUI:Spacing()
    GUI:Separator()

    -- =============================================
    -- Script 类型的额外信息
    -- =============================================
    if entry.type == 6 then
        -- 脚本启动 time 参数
        GUI:Text("脚本启动延迟:")
        GUI:SameLine()
        GUI:PushItemWidth(80)
        ui.scriptStartTime = GUI:InputInt("time##scripttime", ui.scriptStartTime)
        GUI:PopItemWidth()
        if ui.scriptStartTime < 0 then ui.scriptStartTime = 0 end

        GUI:Spacing()

        -- 脚本列表
        if #entry.scripts > 0 then
            GUI:TextColored(1.0, 0.8, 0.2, 1.0, "脚本列表 (" .. #entry.scripts .. "):")
            GUI:Spacing()
            for _, script in ipairs(entry.scripts) do
                local scriptKey = tostring(entry.index) .. "_" .. tostring(script.index)
                local isExpanded = ui.expandedScripts[scriptKey]

                -- 脚本行：可展开
                local runColor = script.isRunning and { 0.2, 1.0, 0.2, 1.0 } or { 0.6, 0.6, 0.6, 1.0 }
                local arrow = isExpanded and "▼ " or "► "
                local scriptLabel = arrow .. "[" .. script.index .. "] " .. script.name
                    .. " (子资源:" .. script.numSubresources .. ")"
                    .. (script.isRunning and " [运行中]" or " [停止]")

                GUI:TextColored(runColor[1], runColor[2], runColor[3], runColor[4], scriptLabel)

                if GUI:IsItemClicked() then
                    ui.expandedScripts[scriptKey] = not isExpanded
                end

                -- 脚本控制按钮
                GUI:SameLine(0, 10)
                if script.isRunning then
                    if GUI:SmallButton("停止##script" .. scriptKey) then
                        Argus.stopEffectResourceScript(entry.resource, script.index)
                        d("[MapEffect] 停止脚本: " .. script.name)
                    end
                else
                    if GUI:SmallButton("启动##script" .. scriptKey) then
                        -- 使用用户设置的 time 参数
                        Argus.startEffectResourceScript(entry.resource, script.index, ui.scriptStartTime)
                        d("[MapEffect] 启动脚本: " .. script.name .. " time=" .. tostring(ui.scriptStartTime))
                    end
                end

                -- 展开时显示子资源
                if isExpanded and #script.subresources > 0 then
                    GUI:Indent(20)
                    for _, sub in ipairs(script.subresources) do
                        DrawSubresourceRow(sub, "  [" .. sub.index .. "] ")
                    end
                    GUI:Unindent(20)
                end
            end
        end

        GUI:Spacing()

        -- 完整子资源列表
        if #entry.subresources > 0 then
            GUI:TextColored(1.0, 0.8, 0.2, 1.0, "全部子资源 (" .. #entry.subresources .. "):")
            GUI:Spacing()
            GUI:Indent(10)
            for _, sub in ipairs(entry.subresources) do
                DrawSubresourceRow(sub, "[" .. sub.index .. "] ")
            end
            GUI:Unindent(10)
        end
    end

    GUI:Spacing()
    GUI:Separator()

    -- =============================================
    -- runMapEffect 按钮
    -- =============================================
    if GUI:Button("runMapEffect##" .. entry.index, 140, 25) then
        Argus.runMapEffect(entry.index, 0, flag)
        d("[MapEffect] runMapEffect: index=" .. entry.index .. " flag=" .. tostring(flag))
    end
    if GUI:IsItemHovered() then
        GUI:SetTooltip("调用 Argus.runMapEffect(" .. entry.index .. ", 0, " .. tostring(flag) .. ")")
    end
end

-- =============================================
-- 主绘制函数
-- =============================================
M.DrawMapEffectUI = function()
    local ui = M.MapEffectUI

    GUI:SetNextWindowSize(520, 600, GUI.SetCond_Appearing)

    local windowTitle = "Map Effect 查看器###MapEffectWindow"
    ui.visible, ui.open = GUI:Begin(windowTitle, ui.open)

    if ui.visible then

        -- =============================================
        -- 工具栏
        -- =============================================

        -- 手动刷新
        if GUI:Button("刷新", 60, 25) then
            RefreshEffects(ui)
        end

        GUI:SameLine()

        -- 自动刷新开关
        ui.autoRefresh = GUI:Checkbox("自动刷新##mapeffect", ui.autoRefresh)

        if ui.autoRefresh then
            GUI:SameLine()
            GUI:PushItemWidth(80)
            local newInterval = GUI:InputFloat("间隔(秒)##refreshInterval", ui.refreshInterval, 0.1, 1.0)
            GUI:PopItemWidth()
            if newInterval >= 0.1 and newInterval <= 10.0 then
                ui.refreshInterval = newInterval
            end
        end

        -- 自动刷新逻辑
        if ui.autoRefresh then
            local now = os.clock()
            if now - ui.lastRefreshTime >= ui.refreshInterval then
                ui.lastRefreshTime = now
                RefreshEffects(ui)
            end
        end

        GUI:Spacing()

        -- 过滤栏
        GUI:PushItemWidth(200)
        ui.filterText = GUI:InputText("搜索##mapeffect_filter", ui.filterText)
        GUI:PopItemWidth()

        GUI:SameLine()

        GUI:PushItemWidth(100)
        local typeOptions = { "全部", "Model", "VFX", "Script", "Sound" }
        local typeValues = { 0, 2, 4, 6, 7 }
        local currentTypeIdx = 1
        for i, v in ipairs(typeValues) do
            if v == ui.filterType then currentTypeIdx = i end
        end
        local newTypeIdx = GUI:Combo("类型##mapeffect_type", currentTypeIdx, typeOptions)
        if newTypeIdx ~= currentTypeIdx then
            ui.filterType = typeValues[newTypeIdx] or 0
        end
        GUI:PopItemWidth()

        GUI:Separator()

        -- =============================================
        -- Argus 检测
        -- =============================================
        if not Argus then
            GUI:Spacing()
            GUI:TextColored(1.0, 0.4, 0.4, 1.0, "Argus API 不可用")
            GUI:TextColored(0.7, 0.7, 0.7, 1.0, "请确认 Argus 模块已加载。")
            GUI:End()
            return
        end

        -- =============================================
        -- 特效总数
        -- =============================================
        GUI:Text("当前地图特效数量: ")
        GUI:SameLine(0, 0)
        GUI:TextColored(0.5, 0.8, 1.0, 1.0, tostring(ui.cachedCount))

        GUI:Spacing()

        -- =============================================
        -- addPlayerMarker 工具
        -- =============================================
        GUI:PushItemWidth(80)
        ui.markerID = GUI:InputInt("Marker ID##markerid", ui.markerID)
        GUI:PopItemWidth()
        GUI:SameLine()
        if GUI:SmallButton("添加标记##addmarker") then
            Argus.addPlayerMarker(ui.markerID)
            d("[MapEffect] addPlayerMarker: " .. tostring(ui.markerID))
        end
        if GUI:IsItemHovered() then
            GUI:SetTooltip("调用 Argus.addPlayerMarker(markerID)\n与 onMarkerAdd 事件中的 markerID 相同")
        end

        GUI:Separator()

        -- =============================================
        -- 特效列表
        -- =============================================
        -- 使用子窗口实现滚动
        local detailHeight = (ui.selectedIndex >= 0) and 300 or 0
        local availH = GUI:GetContentRegionAvail()
        local listHeight = availH - detailHeight - 10
        if listHeight < 100 then listHeight = 100 end

        GUI:BeginChild("##effectList", 0, listHeight, true)

        local visibleCount = 0
        for _, entry in ipairs(ui.cachedEffects) do
            if MatchesFilter(entry, ui.filterText, ui.filterType) then
                visibleCount = visibleCount + 1

                local isSelected = (ui.selectedIndex == entry.index)
                local col = GetTypeColor(entry.type)
                local activeTag = entry.isActive and "" or " [Inactive]"
                local shortPath = string.match(entry.path, "[^/\\]+$") or entry.path

                -- 列表项
                local label = string.format("[%d] %s  ID:%d  %s%s##effect_%d",
                    entry.index,
                    GetTypeName(entry.type),
                    entry.id or 0,
                    shortPath,
                    activeTag,
                    entry.index)

                GUI:PushStyleColor(GUI.Col_Text, col[1], col[2], col[3], col[4])
                if GUI:Selectable(label, isSelected) then
                    if ui.selectedIndex == entry.index then
                        ui.selectedIndex = -1 -- 取消选中
                    else
                        ui.selectedIndex = entry.index
                    end
                end
                GUI:PopStyleColor()

                -- 悬停提示
                if GUI:IsItemHovered() then
                    GUI:SetTooltip(string.format(
                        "路径: %s\n位置: (%.1f, %.1f, %.1f)\n类型: %s\n状态: %s",
                        entry.path,
                        entry.position.x, entry.position.y, entry.position.z,
                        GetTypeName(entry.type),
                        entry.isActive and "Active" or "Inactive"))
                end
            end
        end

        if visibleCount == 0 then
            GUI:TextColored(0.5, 0.5, 0.5, 1.0, "无匹配的特效")
        end

        GUI:EndChild()

        -- =============================================
        -- 详情面板
        -- =============================================
        if ui.selectedIndex >= 0 then
            -- 查找选中的 entry
            local selectedEntry = nil
            for _, entry in ipairs(ui.cachedEffects) do
                if entry.index == ui.selectedIndex then
                    selectedEntry = entry
                    break
                end
            end

            if selectedEntry then
                GUI:BeginChild("##effectDetail", 0, 0, true)
                DrawDetailPanel(selectedEntry, ui)
                GUI:EndChild()
            else
                -- 选中的特效已不存在
                ui.selectedIndex = -1
            end
        end

    end

    GUI:End()
end

d("[StringCore] MapEffectUI.lua 加载完成")
