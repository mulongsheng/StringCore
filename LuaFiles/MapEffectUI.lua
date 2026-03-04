-- =============================================
-- MapEffectUI - 地图特效查看器 (AIMWARE 风格)
-- TabBar 布局: 特效列表 | 执行控制
-- =============================================

local M = StringGuide
if not M then return end

local T = M.UITheme
local C = T.C
local TC = T.TypeConfig

local function GetTypeName(t)
    local c = TC[t]
    return c and c.name or ("Unknown(" .. tostring(t) .. ")")
end

local function GetTypeColor(t)
    local c = TC[t]
    return c and c.color or C.muted
end

-- =============================================
-- UI 内部状态
-- =============================================
local State = {
    effects = {},
    selectedIndex = -1,
    filterText = "",
    filterType = 0,
    autoRefresh = true,
    refreshInterval = 1.0,
    lastRefreshTime = 0,
    -- runMapEffect 面板
    runIndex = 0,
    runA2 = 0,
    runFlags = 0,
    -- 编辑用临时值
    editPos = { x = 0, y = 0, z = 0 },
    editScale = { x = 1, y = 1, z = 1 },
    editOrientDir = { x = 0, y = 0, z = 0 },
    editOrientUp = { x = 0, y = 1, z = 0 },
    editingEntry = -1,
    -- addPlayerMarker
    markerID = 0,
    -- 正在执行的特效记录
    runningEffects = {},
    -- 当前标签页
    activeTab = 1,
}

-- =============================================
-- 工具函数
-- =============================================
local function CopyToClipboard(text)
    if GUI and GUI.SetClipboardText then
        GUI:SetClipboardText(tostring(text))
        d("[MapEffect] 已复制: " .. tostring(text))
    end
end

local function RightClickCopy(text)
    if GUI:IsItemClicked(1) then CopyToClipboard(text) end
    if GUI:IsItemHovered() then GUI:SetTooltip("右键复制") end
end

-- =============================================
-- 刷新特效数据
-- =============================================
local function RefreshEffects()
    State.effects = {}
    if not Argus or not Argus.getNumCurrentMapEffects or not Argus.getMapEffectResource then return end

    local numEffects = Argus.getNumCurrentMapEffects()
    if not numEffects or numEffects <= 0 then return end

    for i = 0, numEffects - 1 do
        local res = Argus.getMapEffectResource(i)
        if not res then
            table.insert(State.effects, {
                index = i, resource = nil, id = 0, path = "(资源不可用)",
                type = -1, isActive = false,
                position = { x = 0, y = 0, z = 0 },
                scale = { x = 1, y = 1, z = 1 },
                orientation = { dir = { x = 0, y = 0, z = 0 }, up = { x = 0, y = 1, z = 0 } },
                renderType = nil, renderState = nil,
                scripts = {}, subresources = {}, unavailable = true,
            })
        end
        if res then
            local resId, resPath, resType, isActive = Argus.getEffectResourceInfo(res)
            local px, py, pz = Argus.getEffectResourcePosition(res)
            local renderType, renderState = Argus.getEffectResourceRenderInfo(res)
            local sx, sy, sz = Argus.getEffectResourceScale(res)
            local dx, dy, dz, ux, uy, uz = Argus.getEffectResourceOrientation(res)

            local entry = {
                index = i, resource = res,
                id = resId or 0, path = resPath or "", type = resType or 0,
                isActive = isActive or false,
                position = { x = px or 0, y = py or 0, z = pz or 0 },
                scale = { x = sx or 1, y = sy or 1, z = sz or 1 },
                orientation = {
                    dir = { x = dx or 0, y = dy or 0, z = dz or 0 },
                    up = { x = ux or 0, y = uy or 1, z = uz or 0 },
                },
                renderType = renderType, renderState = renderState,
                scripts = {}, subresources = {},
            }

            if resType == 6 then
                local numScripts = Argus.getNumEffectResourceScripts(res)
                for si = 0, numScripts - 1 do
                    local sName, numSub, scriptRes, isRunning = Argus.getEffectResourceScriptInfo(res, si)
                    local scriptEntry = {
                        index = si, name = sName or "unknown",
                        numSubresources = numSub, scriptResource = scriptRes,
                        isRunning = isRunning, subresources = {},
                    }
                    if scriptRes and numSub and numSub > 0 then
                        for subi = 0, numSub - 1 do
                            local subRes = Argus.getEffectResourceScriptSubresource(scriptRes, subi)
                            if subRes then
                                local subId, subPath, subType, subActive = Argus.getEffectResourceInfo(subRes)
                                local spx, spy, spz = Argus.getEffectResourcePosition(subRes)
                                table.insert(scriptEntry.subresources, {
                                    index = subi, resource = subRes, id = subId,
                                    path = subPath or "", type = subType, isActive = subActive,
                                    position = { x = spx or 0, y = spy or 0, z = spz or 0 },
                                })
                            end
                        end
                    end
                    table.insert(entry.scripts, scriptEntry)
                end
                local numFullSub = Argus.getNumEffectSubresources(res)
                for fi = 0, numFullSub - 1 do
                    local fRes = Argus.getEffectSubresource(res, fi)
                    if fRes then
                        local fId, fPath, fType, fActive = Argus.getEffectResourceInfo(fRes)
                        local fpx, fpy, fpz = Argus.getEffectResourcePosition(fRes)
                        table.insert(entry.subresources, {
                            index = fi, resource = fRes, id = fId,
                            path = fPath or "", type = fType, isActive = fActive,
                            position = { x = fpx or 0, y = fpy or 0, z = fpz or 0 },
                        })
                    end
                end
            end
            table.insert(State.effects, entry)
        end
    end
end

-- =============================================
-- 过滤
-- =============================================
local function MatchesFilter(entry)
    if entry.unavailable then
        if State.filterType ~= 0 then return false end
        if State.filterText ~= "" then
            if not string.find(tostring(entry.index), State.filterText, 1, true) then return false end
        end
        return true
    end
    if State.filterType ~= 0 and entry.type ~= State.filterType then return false end
    if State.filterText ~= "" then
        local kw = string.lower(State.filterText)
        if not string.find(string.lower(entry.path), kw, 1, true)
           and not string.find(tostring(entry.id), State.filterText, 1, true) then
            return false
        end
    end
    return true
end

-- =============================================
-- 构建摘要 (用于复制)
-- =============================================
local function BuildEntrySummary(entry)
    local lines = {}
    table.insert(lines, "Index: " .. tostring(entry.index))
    table.insert(lines, "ID: " .. tostring(entry.id))
    table.insert(lines, "Path: " .. entry.path)
    table.insert(lines, "Type: " .. GetTypeName(entry.type) .. " (" .. tostring(entry.type) .. ")")
    table.insert(lines, "Active: " .. tostring(entry.isActive))
    table.insert(lines, string.format("Position: %.3f, %.3f, %.3f", entry.position.x, entry.position.y, entry.position.z))
    table.insert(lines, string.format("Scale: %.3f, %.3f, %.3f", entry.scale.x, entry.scale.y, entry.scale.z))
    table.insert(lines, string.format("Orientation: Dir(%.3f,%.3f,%.3f) Up(%.3f,%.3f,%.3f)",
        entry.orientation.dir.x, entry.orientation.dir.y, entry.orientation.dir.z,
        entry.orientation.up.x, entry.orientation.up.y, entry.orientation.up.z))
    if Argus.getEffectResourceScriptFlagForIndex then
        local flag = Argus.getEffectResourceScriptFlagForIndex(entry.index)
        if flag then table.insert(lines, "ScriptFlag: " .. tostring(flag)) end
    end
    if entry.type == 6 then
        if #entry.scripts > 0 then
            table.insert(lines, "--- Scripts (" .. #entry.scripts .. ") ---")
            for _, s in ipairs(entry.scripts) do
                table.insert(lines, string.format("  Script[%d]: %s (%s, %d sub)",
                    s.index, s.name, s.isRunning and "Running" or "Stopped", s.numSubresources or 0))
                for _, sub in ipairs(s.subresources) do
                    table.insert(lines, string.format("    Sub[%d]: %s ID:%d %s Pos(%.1f,%.1f,%.1f)",
                        sub.index, GetTypeName(sub.type), sub.id or 0, sub.path,
                        sub.position.x, sub.position.y, sub.position.z))
                end
            end
        end
        if #entry.subresources > 0 then
            table.insert(lines, "--- Subresources (" .. #entry.subresources .. ") ---")
            for _, sub in ipairs(entry.subresources) do
                table.insert(lines, string.format("  Sub[%d]: %s ID:%d %s Pos(%.1f,%.1f,%.1f)",
                    sub.index, GetTypeName(sub.type), sub.id or 0, sub.path,
                    sub.position.x, sub.position.y, sub.position.z))
            end
        end
    end
    return table.concat(lines, "\n")
end

-- =============================================
-- 绘制子资源行
-- =============================================
local function DrawSubresourceRow(sub, prefix)
    local col = GetTypeColor(sub.type)
    GUI:TextColored(col[1], col[2], col[3], col[4], prefix .. GetTypeName(sub.type))
    GUI:SameLine(0, 5)
    GUI:TextColored(C.white[1], C.white[2], C.white[3], C.white[4],
        string.format("ID:%d  Pos:(%.1f, %.1f, %.1f)  %s",
            sub.id or 0, sub.position.x, sub.position.y, sub.position.z,
            sub.isActive and "Active" or "Inactive"))
    if sub.path ~= "" then
        local shortPath = string.match(sub.path, "[^/\\]+$") or sub.path
        GUI:SameLine(0, 5)
        GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4], shortPath)
        if GUI:IsItemHovered() then GUI:SetTooltip(sub.path) end
    end
    if GUI:IsItemClicked(1) then CopyToClipboard(sub.path) end
end

-- =============================================
-- 停止特效 (通用逻辑)
-- =============================================
local function StopEffect(index)
    local res = Argus.getMapEffectResource(index)
    if res then
        local _, _, resType, _ = Argus.getEffectResourceInfo(res)
        if resType == 6 then
            local numScripts = Argus.getNumEffectResourceScripts(res)
            local stopped = false
            for si = 0, numScripts - 1 do
                local sName, _, _, _ = Argus.getEffectResourceScriptInfo(res, si)
                if sName and string.find(sName, "_off") then
                    Argus.startEffectResourceScript(res, si, 0)
                    stopped = true
                end
            end
            if not stopped then
                for si = 0, numScripts - 1 do
                    Argus.stopEffectResourceScript(res, si)
                end
            end
        end
    end
end

-- =============================================
-- 详情面板 (展开在条目下方)
-- =============================================
local function DrawDetailPanel(entry)
    GUI:Indent(20)
    GUI:Separator()

    -- 基本信息
    T.SubHeader("基本信息")
    GUI:Text("索引: " .. tostring(entry.index) .. "  |  资源 ID: " .. tostring(entry.id))
    local col = GetTypeColor(entry.type)
    GUI:Text("类型: ")
    GUI:SameLine(0, 0)
    GUI:TextColored(col[1], col[2], col[3], col[4], GetTypeName(entry.type))
    GUI:SameLine(0, 10)
    GUI:Text("状态: ")
    GUI:SameLine(0, 0)
    if entry.isActive then T.SuccessText("Active") else T.DangerText("Inactive") end

    GUI:Text("渲染: " .. GetTypeName(entry.renderType or 0) .. " | State: " .. tostring(entry.renderState or 0))

    if Argus.getEffectResourceScriptFlagForIndex then
        local flag = Argus.getEffectResourceScriptFlagForIndex(entry.index)
        local idxFromFlag = Argus.getEffectResourceScriptIndexForFlag(flag)
        GUI:Text("Script Flag: " .. tostring(flag) .. "  (Flag>Index: " .. tostring(idxFromFlag) .. ")")
    end

    GUI:Text("路径: ")
    GUI:SameLine(0, 0)
    GUI:TextColored(C.accent[1], C.accent[2], C.accent[3], C.accent[4], entry.path ~= "" and entry.path or "(无)")
    RightClickCopy(entry.path)

    GUI:Spacing()

    -- 位置/缩放/朝向编辑
    T.SubHeader("位置 / 缩放 / 朝向")
    GUI:Text(string.format("Pos: %.3f, %.3f, %.3f", entry.position.x, entry.position.y, entry.position.z))
    RightClickCopy(string.format("%.3f, %.3f, %.3f", entry.position.x, entry.position.y, entry.position.z))

    if State.editingEntry ~= entry.index then
        State.editingEntry = entry.index
        State.editPos = { x = entry.position.x, y = entry.position.y, z = entry.position.z }
        State.editScale = { x = entry.scale.x, y = entry.scale.y, z = entry.scale.z }
        State.editOrientDir = { x = entry.orientation.dir.x, y = entry.orientation.dir.y, z = entry.orientation.dir.z }
        State.editOrientUp = { x = entry.orientation.up.x, y = entry.orientation.up.y, z = entry.orientation.up.z }
    end

    GUI:PushItemWidth(70)
    State.editPos.x = GUI:InputFloat("X##pos", State.editPos.x, 0.1, 1.0)
    GUI:SameLine()
    State.editPos.y = GUI:InputFloat("Y##pos", State.editPos.y, 0.1, 1.0)
    GUI:SameLine()
    State.editPos.z = GUI:InputFloat("Z##pos", State.editPos.z, 0.1, 1.0)
    GUI:SameLine()
    if GUI:Button("应用##setpos") then
        Argus.setEffectResourcePosition(entry.resource, State.editPos.x, State.editPos.y, State.editPos.z)
    end

    GUI:Text(string.format("Scale: %.3f, %.3f, %.3f", entry.scale.x, entry.scale.y, entry.scale.z))
    State.editScale.x = GUI:InputFloat("X##scale", State.editScale.x, 0.1, 1.0)
    GUI:SameLine()
    State.editScale.y = GUI:InputFloat("Y##scale", State.editScale.y, 0.1, 1.0)
    GUI:SameLine()
    State.editScale.z = GUI:InputFloat("Z##scale", State.editScale.z, 0.1, 1.0)
    GUI:SameLine()
    if GUI:Button("应用##setscale") then
        Argus.setEffectResourceScale(entry.resource, State.editScale.x, State.editScale.y, State.editScale.z)
    end

    GUI:Text(string.format("Dir: (%.3f,%.3f,%.3f) Up: (%.3f,%.3f,%.3f)",
        entry.orientation.dir.x, entry.orientation.dir.y, entry.orientation.dir.z,
        entry.orientation.up.x, entry.orientation.up.y, entry.orientation.up.z))
    State.editOrientDir.x = GUI:InputFloat("dX##ori", State.editOrientDir.x, 0.1, 1.0)
    GUI:SameLine()
    State.editOrientDir.y = GUI:InputFloat("dY##ori", State.editOrientDir.y, 0.1, 1.0)
    GUI:SameLine()
    State.editOrientDir.z = GUI:InputFloat("dZ##ori", State.editOrientDir.z, 0.1, 1.0)
    State.editOrientUp.x = GUI:InputFloat("uX##ori", State.editOrientUp.x, 0.1, 1.0)
    GUI:SameLine()
    State.editOrientUp.y = GUI:InputFloat("uY##ori", State.editOrientUp.y, 0.1, 1.0)
    GUI:SameLine()
    State.editOrientUp.z = GUI:InputFloat("uZ##ori", State.editOrientUp.z, 0.1, 1.0)
    GUI:SameLine()
    if GUI:Button("应用##setori") then
        Argus.setEffectResourceOrientation(entry.resource,
            State.editOrientDir.x, State.editOrientDir.y, State.editOrientDir.z,
            State.editOrientUp.x, State.editOrientUp.y, State.editOrientUp.z)
    end
    GUI:PopItemWidth()

    -- 脚本信息
    if entry.type == 6 and #entry.scripts > 0 then
        GUI:Spacing()
        T.SubHeader("脚本 (" .. #entry.scripts .. ")")
        for _, script in ipairs(entry.scripts) do
            local statusCol = script.isRunning and C.success or C.danger
            GUI:TextColored(statusCol[1], statusCol[2], statusCol[3], statusCol[4],
                string.format("  [%d] %s (%s, %d sub)", script.index, script.name,
                    script.isRunning and "运行中" or "已停止", script.numSubresources or 0))
            GUI:SameLine()
            if script.isRunning then
                if GUI:Button("停止##script" .. script.index) then
                    Argus.stopEffectResourceScript(entry.resource, script.index)
                end
            else
                if GUI:Button("启动##script" .. script.index) then
                    Argus.startEffectResourceScript(entry.resource, script.index, 0)
                end
            end
            for _, sub in ipairs(script.subresources) do
                DrawSubresourceRow(sub, "      ")
            end
        end
    end

    if entry.type == 6 and #entry.subresources > 0 then
        GUI:Spacing()
        T.SubHeader("全部子资源 (" .. #entry.subresources .. ")")
        for _, sub in ipairs(entry.subresources) do
            DrawSubresourceRow(sub, "    ")
        end
    end

    GUI:Spacing()

    -- 操作按钮
    if GUI:Button("复制全部##detail", 90, 22) then
        CopyToClipboard(BuildEntrySummary(entry))
    end
    GUI:SameLine(0, 6)
    T.PushBtn(C.btnSend)
    if GUI:Button("发送到生成器##send" .. tostring(entry.index), 110, 22) then
        M._mapEffectTransfer = {
            a1 = entry.index, a3 = nil,
            posX = entry.position.x, posY = entry.position.y, posZ = entry.position.z,
        }
        if Argus and Argus.getEffectResourceScriptFlagForIndex then
            M._mapEffectTransfer.a3 = Argus.getEffectResourceScriptFlagForIndex(entry.index)
        end
        if M.ArgusBuilderUI then M.ArgusBuilderUI.open = true end
        d("[MapEffect] 已发送到生成器: Index=" .. entry.index)
    end
    T.PopBtn()

    GUI:Separator()
    GUI:Unindent(20)
end
-- =============================================
-- 自动刷新 (被外部调用)
-- =============================================
M.MapEffectAutoRefresh = function()
    if State.autoRefresh then
        local now = os.clock()
        if now - State.lastRefreshTime >= State.refreshInterval then
            State.lastRefreshTime = now
            RefreshEffects()
        end
    end
end

-- =============================================
-- Tab: 特效列表 (被合并窗口调用)
-- =============================================
M.DrawEffectListTab = function()
    if GUI:Button("刷新##ME", 55, 22) then RefreshEffects() end
    GUI:SameLine(0, 6)
    State.autoRefresh = GUI:Checkbox("自动##ME", State.autoRefresh)
    if State.autoRefresh then
        GUI:SameLine(0, 4)
        GUI:PushItemWidth(60)
        State.refreshInterval = GUI:InputFloat("s##MEInt", State.refreshInterval, 0.5, 1.0)
        GUI:PopItemWidth()
        if State.refreshInterval < 0.1 then State.refreshInterval = 0.1 end
    end
    GUI:SameLine(0, 10)
    GUI:PushItemWidth(140)
    State.filterText = GUI:InputText("搜索##MEF", State.filterText)
    GUI:PopItemWidth()
    GUI:SameLine(0, 6)
    GUI:PushItemWidth(120)
    local typeCounts = {}
    for _, e in ipairs(State.effects) do
        if not e.unavailable then
            typeCounts[e.type] = (typeCounts[e.type] or 0) + 1
        end
    end
    local typeNames = { "全部" }
    local typeValues = { 0 }
    local sortedTypes = {}
    for t2, _ in pairs(typeCounts) do table.insert(sortedTypes, t2) end
    table.sort(sortedTypes)
    for _, t2 in ipairs(sortedTypes) do
        table.insert(typeNames, GetTypeName(t2) .. "(" .. t2 .. ") x" .. typeCounts[t2])
        table.insert(typeValues, t2)
    end
    local currentTypeIdx = 1
    for idx, v in ipairs(typeValues) do
        if v == State.filterType then currentTypeIdx = idx break end
    end
    local newTypeIdx = GUI:Combo("类型##MET", currentTypeIdx, typeNames)
    if newTypeIdx ~= currentTypeIdx then
        State.filterType = typeValues[newTypeIdx] or 0
    end
    GUI:PopItemWidth()

    local numTotal = Argus and Argus.getNumCurrentMapEffects and Argus.getNumCurrentMapEffects() or 0
    local filteredCount = 0
    for _, e in ipairs(State.effects) do
        if MatchesFilter(e) then filteredCount = filteredCount + 1 end
    end
    GUI:SameLine(0, 10)
    T.HintText(filteredCount .. "/" .. numTotal)

    GUI:Separator()
    GUI:BeginChild("MEList", 0, -220, false)

    for _, entry in ipairs(State.effects) do
        if MatchesFilter(entry) then
            if entry.unavailable then
                GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4],
                    string.format("[%d] (资源不可用)", entry.index))
            else
                local eCol = GetTypeColor(entry.type)
                local shortName = string.match(entry.path, "[^/\\]+$") or entry.path
                local activeTag = entry.isActive and "" or " [Inactive]"
                local label = string.format("[%d] %s  ID:%d  %s%s",
                    entry.index, GetTypeName(entry.type), entry.id or 0, shortName, activeTag)
                GUI:TextColored(eCol[1], eCol[2], eCol[3], eCol[4], label)

                GUI:SameLine(0, 5)
                local runningIdx = nil
                for ri, re in ipairs(State.runningEffects) do
                    if re.index == entry.index then runningIdx = ri break end
                end

                if runningIdx then
                    T.PushBtn(C.btnStop)
                    if GUI:Button("x##run" .. entry.index, 22, 18) then
                        StopEffect(entry.index)
                        table.remove(State.runningEffects, runningIdx)
                    end
                    T.PopBtn()
                else
                    T.PushBtn(C.btnRun)
                    if GUI:Button(">##run" .. entry.index, 22, 18) then
                        if Argus and Argus.runMapEffect then
                            local a2 = 0
                            local flags = Argus.getEffectResourceScriptFlagForIndex and Argus.getEffectResourceScriptFlagForIndex(entry.index) or 0
                            Argus.runMapEffect(entry.index, a2, flags)
                            table.insert(State.runningEffects, { index = entry.index, a2 = a2, flags = flags })
                        end
                    end
                    T.PopBtn()
                end

                GUI:SameLine(0, 3)
                local isExpanded = (State.editingEntry == entry.index)
                if GUI:Button((isExpanded and "v" or ">") .. "##det" .. entry.index, 18, 18) then
                    State.editingEntry = isExpanded and -1 or entry.index
                end
                if State.editingEntry == entry.index then
                    DrawDetailPanel(entry)
                end
            end
        end
    end
    GUI:EndChild()
end

-- =============================================
-- Tab: 执行控制 (被合并窗口调用)
-- =============================================
M.DrawExecControlTab = function()
    if #State.runningEffects > 0 then
        T.SubHeader("正在执行的特效")
        T.SuccessText("共 " .. #State.runningEffects .. " 个")
        GUI:SameLine(0, 10)
        T.PushBtn(C.btnStop)
        if GUI:Button("全部停止##stopAll", 80, 22) then
            for _, re in ipairs(State.runningEffects) do StopEffect(re.index) end
            State.runningEffects = {}
        end
        T.PopBtn()
        GUI:Spacing()
        local toRemove = {}
        for ri, re in ipairs(State.runningEffects) do
            T.SuccessText(string.format("[%d] Index:%d  A2:%d  Flags:%d", ri, re.index, re.a2, re.flags))
            GUI:SameLine()
            T.PushBtn(C.btnStop)
            if GUI:Button("停止##r" .. ri) then
                StopEffect(re.index)
                table.insert(toRemove, ri)
            end
            T.PopBtn()
        end
        for i = #toRemove, 1, -1 do table.remove(State.runningEffects, toRemove[i]) end
        GUI:Separator()
        GUI:Spacing()
    end

    T.SubHeader("手动执行 runMapEffect")
    T.HintText("Argus.runMapEffect(index, a2, flags)")
    GUI:Spacing()
    GUI:PushItemWidth(100)
    State.runIndex = GUI:InputInt("Index##run", State.runIndex)
    GUI:SameLine()
    State.runA2 = GUI:InputInt("A2##run", State.runA2)
    GUI:SameLine()
    State.runFlags = GUI:InputInt("Flags##run", State.runFlags)
    GUI:PopItemWidth()
    GUI:Spacing()

    if GUI:Button("执行##runME", 70, 24) then
        if Argus and Argus.runMapEffect then
            Argus.runMapEffect(State.runIndex, State.runA2, State.runFlags)
            table.insert(State.runningEffects, { index = State.runIndex, a2 = State.runA2, flags = State.runFlags })
        end
    end
    GUI:SameLine(0, 4)
    if GUI:Button("自动Flag##runME", 80, 24) then
        if Argus and Argus.getEffectResourceScriptFlagForIndex then
            local flag = Argus.getEffectResourceScriptFlagForIndex(State.runIndex)
            if flag then State.runFlags = flag end
        end
    end
    if GUI:IsItemHovered() then GUI:SetTooltip("根据 Index 自动获取 Flag") end
    GUI:SameLine(0, 4)
    if GUI:Button("Flag>Index##runME", 80, 24) then
        if Argus and Argus.getEffectResourceScriptIndexForFlag then
            local idx = Argus.getEffectResourceScriptIndexForFlag(State.runFlags)
            if idx then State.runIndex = idx end
        end
    end
    if GUI:IsItemHovered() then GUI:SetTooltip("根据 Flag 反向查询 Index") end

    GUI:Spacing()
    T.PushBtn(C.btnSend)
    if GUI:Button("发送到生成器##runSend", 120, 24) then
        M._mapEffectTransfer = { a1 = State.runIndex, a3 = State.runFlags }
        if Argus and Argus.getMapEffectResource then
            local res = Argus.getMapEffectResource(State.runIndex)
            if res then
                local px, py, pz = Argus.getEffectResourcePosition(res)
                if px then
                    M._mapEffectTransfer.posX = px
                    M._mapEffectTransfer.posY = py
                    M._mapEffectTransfer.posZ = pz
                end
            end
        end
    end
    T.PopBtn()

    GUI:Spacing()
    GUI:Separator()
    GUI:Spacing()
    T.SubHeader("添加玩家标记")
    T.HintText("Argus.addPlayerMarker(markerID)")
    GUI:Spacing()
    GUI:PushItemWidth(100)
    State.markerID = GUI:InputInt("MarkerID##marker", State.markerID)
    GUI:PopItemWidth()
    GUI:SameLine(0, 6)
    if GUI:Button("添加##marker", 70, 24) then
        if Argus and Argus.addPlayerMarker then
            Argus.addPlayerMarker(State.markerID)
        end
    end
end

d("[StringCore] MapEffectUI.lua 加载完成")

