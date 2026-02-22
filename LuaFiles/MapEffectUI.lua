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
    title    = { 0.95, 0.75, 0.20, 1.0 },
    accent   = { 0.40, 0.75, 1.00, 1.0 },
    success  = { 0.30, 0.90, 0.40, 1.0 },
    danger   = { 1.00, 0.40, 0.40, 1.0 },
    muted    = { 0.55, 0.55, 0.55, 1.0 },
    white    = { 0.90, 0.90, 0.90, 1.0 },
}

-- ResourceType 配置
local TypeConfig = {
    [2] = { name = "Model",  color = { 0.55, 0.80, 1.00, 1.0 } },
    [4] = { name = "VFX",    color = { 1.00, 0.55, 0.20, 1.0 } },
    [6] = { name = "Script", color = { 0.30, 1.00, 0.60, 1.0 } },
    [7] = { name = "Sound",  color = { 1.00, 0.85, 0.25, 1.0 } },
}

local function GetTypeName(t)
    local c = TypeConfig[t]
    return c and c.name or ("Unknown(" .. tostring(t) .. ")")
end

local function GetTypeColor(t)
    local c = TypeConfig[t]
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
}

-- =============================================
-- 右键复制
-- =============================================
local function CopyToClipboard(text)
    if GUI and GUI.SetClipboardText then
        GUI:SetClipboardText(tostring(text))
        d("[MapEffect] 已复制: " .. tostring(text))
    end
end

local function RightClickCopy(text)
    if GUI:IsItemClicked(1) then
        CopyToClipboard(text)
    end
    if GUI:IsItemHovered() then
        GUI:SetTooltip("右键复制")
    end
end

-- =============================================
-- 刷新特效数据（直接逐个获取，最兼容）
-- =============================================
local function RefreshEffects()
    State.effects = {}
    if not Argus or not Argus.getNumCurrentMapEffects or not Argus.getMapEffectResource then return end

    local numEffects = Argus.getNumCurrentMapEffects()
    if not numEffects or numEffects <= 0 then return end

    for i = 0, numEffects - 1 do
        local res = Argus.getMapEffectResource(i)
        if res then
            local resId, resPath, resType, isActive = Argus.getEffectResourceInfo(res)
            if resId then
                local px, py, pz = Argus.getEffectResourcePosition(res)
                local renderType, renderState = Argus.getEffectResourceRenderInfo(res)
                local sx, sy, sz = Argus.getEffectResourceScale(res)
                local dx, dy, dz, ux, uy, uz = Argus.getEffectResourceOrientation(res)

                local entry = {
                    index = i,
                    resource = res,
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

                -- Script 类型获取脚本和子资源
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
end

-- =============================================
-- 过滤
-- =============================================
local function MatchesFilter(entry)
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
-- 构建完整摘要（用于复制）
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
    table.insert(lines, "RenderType: " .. GetTypeName(entry.renderType or 0) .. " (" .. tostring(entry.renderType) .. ")")
    table.insert(lines, "RenderState: " .. tostring(entry.renderState))

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
    GUI:TextColored(0.7, 0.7, 0.7, 1.0,
        string.format("ID:%d  Pos:(%.1f, %.1f, %.1f)  %s",
            sub.id or 0, sub.position.x, sub.position.y, sub.position.z,
            sub.isActive and "Active" or "Inactive"))
    if sub.path ~= "" then
        local shortPath = string.match(sub.path, "[^/\\]+$") or sub.path
        GUI:SameLine(0, 5)
        GUI:TextColored(0.5, 0.5, 0.5, 1.0, shortPath)
        if GUI:IsItemHovered() then GUI:SetTooltip(sub.path) end
    end
    -- 右键复制子资源路径
    if GUI:IsItemClicked(1) then CopyToClipboard(sub.path) end
end

-- =============================================
-- 绘制详情面板（展开在条目下方）
-- =============================================
local function DrawDetailPanel(entry)
    GUI:Separator()
    GUI:Spacing()
    GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4], "===== 特效详情 =====")
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
        GUI:TextColored(C.success[1], C.success[2], C.success[3], C.success[4], "Active")
    else
        GUI:TextColored(C.danger[1], C.danger[2], C.danger[3], C.danger[4], "Inactive")
    end

    GUI:Text("渲染类型: " .. GetTypeName(entry.renderType or 0))
    GUI:Text("渲染状态: " .. tostring(entry.renderState or 0))

    -- Flag / Index 转换
    if Argus.getEffectResourceScriptFlagForIndex then
        local flag = Argus.getEffectResourceScriptFlagForIndex(entry.index)
        local idxFromFlag = Argus.getEffectResourceScriptIndexForFlag(flag)
        GUI:Text("Script Flag: " .. tostring(flag) .. "  (Flag→Index: " .. tostring(idxFromFlag) .. ")")
    end

    -- 路径
    GUI:Text("路径: ")
    GUI:SameLine(0, 0)
    GUI:TextColored(C.accent[1], C.accent[2], C.accent[3], C.accent[4], entry.path ~= "" and entry.path or "(无)")
    RightClickCopy(entry.path)

    GUI:Spacing()
    GUI:Separator()

    -- =============================================
    -- 位置编辑
    -- =============================================
    GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4], "位置:")
    GUI:Text(string.format("  当前: X=%.3f  Y=%.3f  Z=%.3f", entry.position.x, entry.position.y, entry.position.z))
    RightClickCopy(string.format("%.3f, %.3f, %.3f", entry.position.x, entry.position.y, entry.position.z))

    if State.editingEntry ~= entry.index then
        State.editingEntry = entry.index
        State.editPos = { x = entry.position.x, y = entry.position.y, z = entry.position.z }
        State.editScale = { x = entry.scale.x, y = entry.scale.y, z = entry.scale.z }
        State.editOrientDir = { x = entry.orientation.dir.x, y = entry.orientation.dir.y, z = entry.orientation.dir.z }
        State.editOrientUp = { x = entry.orientation.up.x, y = entry.orientation.up.y, z = entry.orientation.up.z }
    end

    GUI:PushItemWidth(80)
    State.editPos.x = GUI:InputFloat("X##pos", State.editPos.x, 0.1, 1.0)
    GUI:SameLine()
    State.editPos.y = GUI:InputFloat("Y##pos", State.editPos.y, 0.1, 1.0)
    GUI:SameLine()
    State.editPos.z = GUI:InputFloat("Z##pos", State.editPos.z, 0.1, 1.0)
    GUI:PopItemWidth()
    GUI:SameLine()
    if GUI:Button("应用位置##setpos") then
        Argus.setEffectResourcePosition(entry.resource, State.editPos.x, State.editPos.y, State.editPos.z)
    end

    GUI:Spacing()

    -- 缩放编辑
    GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4], "缩放:")
    GUI:Text(string.format("  当前: X=%.3f  Y=%.3f  Z=%.3f", entry.scale.x, entry.scale.y, entry.scale.z))
    RightClickCopy(string.format("%.3f, %.3f, %.3f", entry.scale.x, entry.scale.y, entry.scale.z))

    GUI:PushItemWidth(80)
    State.editScale.x = GUI:InputFloat("X##scale", State.editScale.x, 0.1, 1.0)
    GUI:SameLine()
    State.editScale.y = GUI:InputFloat("Y##scale", State.editScale.y, 0.1, 1.0)
    GUI:SameLine()
    State.editScale.z = GUI:InputFloat("Z##scale", State.editScale.z, 0.1, 1.0)
    GUI:PopItemWidth()
    GUI:SameLine()
    if GUI:Button("应用缩放##setscale") then
        Argus.setEffectResourceScale(entry.resource, State.editScale.x, State.editScale.y, State.editScale.z)
    end

    GUI:Spacing()

    -- 朝向编辑
    GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4], "朝向:")
    GUI:Text(string.format("  Dir: (%.3f, %.3f, %.3f)  Up: (%.3f, %.3f, %.3f)",
        entry.orientation.dir.x, entry.orientation.dir.y, entry.orientation.dir.z,
        entry.orientation.up.x, entry.orientation.up.y, entry.orientation.up.z))

    GUI:Text("  Direction:")
    GUI:PushItemWidth(70)
    State.editOrientDir.x = GUI:InputFloat("dX##ori", State.editOrientDir.x, 0.1, 1.0)
    GUI:SameLine()
    State.editOrientDir.y = GUI:InputFloat("dY##ori", State.editOrientDir.y, 0.1, 1.0)
    GUI:SameLine()
    State.editOrientDir.z = GUI:InputFloat("dZ##ori", State.editOrientDir.z, 0.1, 1.0)
    GUI:PopItemWidth()

    GUI:Text("  Up:")
    GUI:PushItemWidth(70)
    State.editOrientUp.x = GUI:InputFloat("uX##ori", State.editOrientUp.x, 0.1, 1.0)
    GUI:SameLine()
    State.editOrientUp.y = GUI:InputFloat("uY##ori", State.editOrientUp.y, 0.1, 1.0)
    GUI:SameLine()
    State.editOrientUp.z = GUI:InputFloat("uZ##ori", State.editOrientUp.z, 0.1, 1.0)
    GUI:PopItemWidth()
    GUI:SameLine()
    if GUI:Button("应用朝向##setori") then
        Argus.setEffectResourceOrientation(entry.resource,
            State.editOrientDir.x, State.editOrientDir.y, State.editOrientDir.z,
            State.editOrientUp.x, State.editOrientUp.y, State.editOrientUp.z)
    end

    -- =============================================
    -- 脚本信息（仅 Script 类型）
    -- =============================================
    if entry.type == 6 and #entry.scripts > 0 then
        GUI:Spacing()
        GUI:Separator()
        GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4],
            "脚本 (" .. #entry.scripts .. ")")
        GUI:Spacing()

        for _, script in ipairs(entry.scripts) do
            local statusCol = script.isRunning and C.success or C.danger
            local statusText = script.isRunning and "运行中" or "已停止"
            GUI:TextColored(statusCol[1], statusCol[2], statusCol[3], statusCol[4],
                string.format("  [%d] %s (%s, %d 子资源)", script.index, script.name, statusText, script.numSubresources or 0))

            -- 启动/停止按钮
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

            -- 脚本子资源
            for _, sub in ipairs(script.subresources) do
                DrawSubresourceRow(sub, "      ")
            end
        end
    end

    -- 全部子资源
    if entry.type == 6 and #entry.subresources > 0 then
        GUI:Spacing()
        GUI:Separator()
        GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4],
            "全部子资源 (" .. #entry.subresources .. ")")
        GUI:Spacing()

        for _, sub in ipairs(entry.subresources) do
            DrawSubresourceRow(sub, "    ")
        end
    end

    GUI:Spacing()
    GUI:Separator()

    -- 复制全部信息
    if GUI:Button("复制全部信息##detail", 140, 25) then
        CopyToClipboard(BuildEntrySummary(entry))
    end

    GUI:Spacing()
end

-- =============================================
-- 主绘制函数
-- =============================================
M.DrawMapEffectUI = function()
    GUI:SetNextWindowSize(700, 550, GUI.SetCond_Appearing)
    M.MapEffectUI.visible, M.MapEffectUI.open = GUI:Begin("Map Effect 查看器###MapEffectWindow", M.MapEffectUI.open)

    if M.MapEffectUI.visible then

        -- 自动刷新逻辑（始终执行）
        if State.autoRefresh then
            local now = os.clock()
            if now - State.lastRefreshTime >= State.refreshInterval then
                State.lastRefreshTime = now
                RefreshEffects()
            end
        end

        -- =============================================
        -- 刷新控制
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

        -- 搜索和类型过滤
        GUI:PushItemWidth(200)
        State.filterText = GUI:InputText("搜索##MEFilter", State.filterText)
        GUI:PopItemWidth()
        GUI:SameLine(0, 15)
        GUI:PushItemWidth(120)
        local typeNames = { "全部", "Model(2)", "VFX(4)", "Script(6)", "Sound(7)" }
        local typeValues = { 0, 2, 4, 6, 7 }
        local currentTypeIdx = 1
        for idx, v in ipairs(typeValues) do
            if v == State.filterType then currentTypeIdx = idx break end
        end
        local newTypeIdx = GUI:Combo("类型##METype", currentTypeIdx, typeNames)
        if newTypeIdx ~= currentTypeIdx then
            State.filterType = typeValues[newTypeIdx] or 0
        end
        GUI:PopItemWidth()

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 正在执行的特效
        -- =============================================
        if #State.runningEffects > 0 then
            if GUI:CollapsingHeader("正在执行的特效 (" .. #State.runningEffects .. ")##MERunning") then
                GUI:Indent(8)
                local toRemove = {}
                for ri, re in ipairs(State.runningEffects) do
                    GUI:TextColored(C.success[1], C.success[2], C.success[3], C.success[4],
                        string.format("[%d] Index:%d  A2:%d  Flags:%d", ri, re.index, re.a2, re.flags))
                    GUI:SameLine()
                    if GUI:Button("停止##running" .. ri) then
                        -- runMapEffect 触发的特效不受 stopEffectResourceScript 控制
                        -- 需要找到对应的 _off 脚本并通过 runMapEffect 或 startEffectResourceScript 执行
                        d("[MapEffect] 尝试停止特效 Index=" .. re.index .. " Flags=" .. re.flags)
                        local res = Argus.getMapEffectResource(re.index)
                        if res then
                            local _, _, resType, _ = Argus.getEffectResourceInfo(res)
                            local stopped = false

                            if resType == 6 then
                                local numScripts = Argus.getNumEffectResourceScripts(res)
                                -- 策略1: 找 _off 脚本并启动它来关闭特效
                                for si = 0, numScripts - 1 do
                                    local sName, _, _, _ = Argus.getEffectResourceScriptInfo(res, si)
                                    if sName and string.find(sName, "_off") then
                                        d("[MapEffect] 找到 off 脚本: [" .. si .. "] " .. sName .. "，尝试启动")
                                        -- 方式A: 通过 startEffectResourceScript 直接启动 off 脚本
                                        local result = Argus.startEffectResourceScript(res, si, 0)
                                        d("[MapEffect]   startEffectResourceScript 结果: " .. tostring(result))
                                        -- 方式B: 获取该脚本的 flag 并通过 runMapEffect 执行
                                        local offFlag = Argus.getEffectResourceScriptFlagForIndex(re.index)
                                        -- flag 是按 index 对应的，尝试用脚本 index 转换
                                        d("[MapEffect]   off 脚本 index=" .. si)
                                        stopped = true
                                    end
                                end

                                -- 策略2: 如果没找到 _off，尝试停止所有正在运行的脚本
                                if not stopped then
                                    for si = 0, numScripts - 1 do
                                        local sName, _, _, isRunning = Argus.getEffectResourceScriptInfo(res, si)
                                        d("[MapEffect]   Script[" .. si .. "]: " .. tostring(sName) .. " running=" .. tostring(isRunning))
                                        -- 无论 isRunning 状态，都尝试 stop
                                        Argus.stopEffectResourceScript(res, si)
                                    end
                                    d("[MapEffect] 已尝试停止所有脚本")
                                end
                            end
                        end
                        table.insert(toRemove, ri)
                    end
                end
                -- 从后往前删除，避免索引偏移
                for i = #toRemove, 1, -1 do
                    table.remove(State.runningEffects, toRemove[i])
                end
                GUI:Unindent(8)
            end
            GUI:Spacing()
        end

        -- =============================================
        -- 手动执行 runMapEffect
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
                    Argus.runMapEffect(State.runIndex, State.runA2, State.runFlags)
                    d("[MapEffect] runMapEffect: " .. State.runIndex .. ", " .. State.runA2 .. ", " .. State.runFlags)
                    -- 记录到正在执行列表
                    table.insert(State.runningEffects, {
                        index = State.runIndex, a2 = State.runA2, flags = State.runFlags
                    })
                end
            end
            GUI:SameLine()
            if GUI:Button("自动Flag##runME", 90, 25) then
                if Argus and Argus.getEffectResourceScriptFlagForIndex then
                    local flag = Argus.getEffectResourceScriptFlagForIndex(State.runIndex)
                    if flag then
                        State.runFlags = flag
                        d("[MapEffect] 自动获取 Flag: " .. tostring(flag))
                    end
                end
            end
            if GUI:IsItemHovered() then
                GUI:SetTooltip("根据 Index 自动获取 Script Flag")
            end
            GUI:SameLine()
            if GUI:Button("Flag→Index##runME", 90, 25) then
                if Argus and Argus.getEffectResourceScriptIndexForFlag then
                    local idx = Argus.getEffectResourceScriptIndexForFlag(State.runFlags)
                    if idx then
                        State.runIndex = idx
                        d("[MapEffect] Flag→Index: " .. tostring(idx))
                    end
                end
            end
            if GUI:IsItemHovered() then
                GUI:SetTooltip("根据 Flag 反向查询 Index")
            end
            GUI:Unindent(8)
        end

        GUI:Spacing()

        -- =============================================
        -- addPlayerMarker
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
                    Argus.addPlayerMarker(State.markerID)
                    d("[MapEffect] addPlayerMarker: " .. tostring(State.markerID))
                end
            end
            GUI:Unindent(8)
        end

        GUI:Spacing()
        GUI:Separator()
        GUI:Spacing()

        -- =============================================
        -- 特效列表
        -- =============================================
        local numTotal = Argus and Argus.getNumCurrentMapEffects and Argus.getNumCurrentMapEffects() or 0
        local filteredCount = 0
        for _, e in ipairs(State.effects) do
            if MatchesFilter(e) then filteredCount = filteredCount + 1 end
        end

        GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4],
            "当前地图特效数量: " .. filteredCount .. " / " .. numTotal)
        GUI:Spacing()

        for _, entry in ipairs(State.effects) do
            if MatchesFilter(entry) then
                local col = GetTypeColor(entry.type)
                local shortName = string.match(entry.path, "[^/\\]+$") or entry.path
                local activeTag = entry.isActive and "" or " [Inactive]"
                local label = string.format("[%d] %s  ID:%d  %s%s",
                    entry.index, GetTypeName(entry.type), entry.id or 0, shortName, activeTag)

                GUI:TextColored(col[1], col[2], col[3], col[4], label)

                -- 左键展开/收起详情
                if GUI:IsItemClicked(0) then
                    if State.selectedIndex == entry.index then
                        State.selectedIndex = -1
                    else
                        State.selectedIndex = entry.index
                    end
                end

                -- 右键复制完整信息
                if GUI:IsItemClicked(1) then
                    CopyToClipboard(BuildEntrySummary(entry))
                end

                -- 悬停提示
                if GUI:IsItemHovered() then
                    GUI:SetTooltip(entry.path .. "\n左键展开详情 | 右键复制完整信息")
                end

                -- 展开详情
                if State.selectedIndex == entry.index then
                    GUI:Indent(16)
                    DrawDetailPanel(entry)
                    GUI:Unindent(16)
                end
            end
        end

    end

    GUI:End()
end

d("[StringCore] MapEffectUI.lua 加载完成")
