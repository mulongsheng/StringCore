-- =============================================
-- MainUI - 主界面
-- 包含：状态显示、功能按钮
-- =============================================

local M = StringGuide
if not M then return end

M.DrawMainUI = function()
    
    -- 设置窗口初始大小和位置
    GUI:SetNextWindowSize(280, 0, GUI.SetCond_Appearing)
    
    -- 创建主窗口
    M.UI.visible, M.UI.open = GUI:Begin("StringCore v" .. M.VERSION, M.UI.open)
    
    if M.UI.visible then
        
        -- =============================================
        -- 状态信息区域
        -- =============================================
        if GUI:CollapsingHeader("状态信息##StringCore") then
            GUI:Indent(10)
            
            -- 当前副本
            local raidName = M.GetCurrentRaidName()
            local raidColor = M.IsInSupportedRaid() and { 0.2, 1.0, 0.2, 1.0 } or { 1.0, 0.5, 0.5, 1.0 }
            GUI:Text("当前副本: ")
            GUI:SameLine(0, 0)
            GUI:TextColored(raidColor[1], raidColor[2], raidColor[3], raidColor[4], raidName)
            
            -- 当前职业
            if Player then
                local jobName = M.GetJobNameById(Player.job)
                GUI:Text("当前职业: ")
                GUI:SameLine(0, 0)
                GUI:TextColored(0.5, 0.8, 1.0, 1.0, jobName)
                
                -- 职能位置
                if M.SelfPos then
                    GUI:Text("职能位置: ")
                    GUI:SameLine(0, 0)
                    GUI:TextColored(1.0, 0.8, 0.2, 1.0, M.SelfPos)
                end
                
                -- 减伤技能
                local skills = M.Mitigation.GetJobSkills()
                if skills[1] or skills[2] then
                    GUI:Text("减伤技能: ")
                    GUI:SameLine(0, 0)
                    local skillText = ""
                    if skills[1] then skillText = skills[1] end
                    if skills[2] then
                        if skillText ~= "" then skillText = skillText .. " / " end
                        skillText = skillText .. skills[2]
                    end
                    GUI:TextColored(0.8, 0.8, 0.8, 1.0, skillText)
                end
            else
                GUI:TextColored(1.0, 0.5, 0.5, 1.0, "未检测到玩家")
            end
            
            GUI:Unindent(10)
        end
        
        GUI:Separator()
        
        -- =============================================
        -- 队伍信息区域（可拖动排序）
        -- =============================================
        if GUI:CollapsingHeader("队伍信息##StringCore") then
            GUI:Indent(10)
            
            -- 刷新队伍按钮
            if GUI:Button("刷新队伍", 120, 25) then
                M.LoadParty()
            end
            
            GUI:SameLine()
            GUI:TextColored(0.7, 0.7, 0.7, 1.0, "(拖动调整职能)")
            
            GUI:Spacing()
            
            -- 可拖动的队伍列表
            if M.PartyList and #M.PartyList > 0 then
                for i = 1, #M.PartyList do
                    local member = M.PartyList[i]
                    local posName = M.JobPosName[i] or "??"
                    local jobName = M.GetJobName(member.job)
                    local displayName = member.name or "空位"
                    local isEmpty = (member.id == 0)
                    
                    -- 职能标签颜色：自己=金色，坦克=蓝色，治疗=绿色，DPS=红色
                    local isSelf = (Player and member.id == Player.id)
                    local posColor
                    if isSelf then
                        posColor = {1.0, 0.8, 0.2, 1.0}  -- 金色（自己）
                    elseif posName == "MT" or posName == "ST" then
                        posColor = {0.6, 0.8, 1.0, 1.0}  -- 蓝色（坦克）
                    elseif posName == "H1" or posName == "H2" then
                        posColor = {0.2, 1.0, 0.4, 1.0}  -- 绿色（治疗）
                    else
                        posColor = {1.0, 0.4, 0.4, 1.0}  -- 红色（DPS）
                    end
                    
                    GUI:TextColored(posColor[1], posColor[2], posColor[3], posColor[4], posName .. ":")
                    GUI:SameLine(50, 0)
                    
                    -- 可选择/拖动的玩家名
                    local isSelected = (i == M.DragState.selected)
                    local label = isEmpty and "[空位]" or ("[" .. jobName .. "] " .. displayName)
                    
                    if isEmpty then
                        GUI:TextColored(0.5, 0.5, 0.5, 1.0, label)
                    else
                        GUI:Selectable(label, isSelected)
                        
                        -- 拖动逻辑
                        local hoverFlags = GUI.HoveredFlags_AllowWhenBlockedByPopup + GUI.HoveredFlags_AllowWhenBlockedByActiveItem + GUI.HoveredFlags_AllowWhenOverlapped
                        if GUI:IsItemHovered(hoverFlags) then
                            if GUI:IsMouseDown(0) then
                                if M.DragState.pos == 0 then
                                    -- 开始拖动
                                    if M.DragState.pos ~= i then M.DragState.pos = i end
                                    if M.DragState.selected ~= i then M.DragState.selected = i end
                                elseif M.DragState.pos ~= i then
                                    -- 交换位置
                                    local move = M.PartyList[M.DragState.pos]
                                    M.PartyList[M.DragState.pos] = M.PartyList[i]
                                    M.PartyList[i] = move
                                    M.DragState.pos = i
                                    if M.DragState.selected ~= i then M.DragState.selected = i end
                                    -- 同步到 Party
                                    M.SyncPartyFromList()
                                end
                            end
                        end
                    end
                end
                
                -- 释放鼠标时重置拖动状态
                if M.DragState.pos ~= 0 and (GUI:IsMouseReleased(0) or not GUI:IsMouseDown(0)) then
                    M.DragState.pos = 0
                end
            else
                GUI:TextColored(0.5, 0.5, 0.5, 1.0, "未加载队伍信息")
            end
            
            GUI:Unindent(10)
        end
        
        GUI:Separator()
        
        -- =============================================
        -- 功能按钮区域
        -- =============================================
        if GUI:CollapsingHeader("功能##StringCore") then
            GUI:Indent(10)
            
            -- 减伤配置按钮
            if M.IsInSupportedRaid() then
                -- 开发模式下确保有默认副本
                if M.IgnoreMapCheck and not M.CurrentRaid then
                    M.CurrentRaid = "M9S"
                    M.Mitigation.LoadRaidConfig(M.CurrentRaid)
                end
                
                if GUI:Button("减伤配置", 120, 30) then
                    M.MitigationUI.open = not M.MitigationUI.open
                end
                
                if M.MitigationUI.open then
                    GUI:SameLine(0, 10)
                    GUI:TextColored(0.2, 1.0, 0.2, 1.0, "(已打开)")
                end
            else
                GUI:TextColored(0.5, 0.5, 0.5, 1.0, "进入支持的副本后可配置减伤")
            end
            
            GUI:Spacing()
            
            -- 开发模式切换
            M.DevelopMode = GUI:Checkbox("开发模式 (热加载UI)", M.DevelopMode)
            
            -- 无视地图检查
            M.IgnoreMapCheck = GUI:Checkbox("无视地图ID (开发用)", M.IgnoreMapCheck)
            if M.IgnoreMapCheck then
                GUI:SameLine()
                GUI:TextColored(1.0, 0.5, 0.2, 1.0, "!")
            end
            
            GUI:Unindent(10)
        end
        
        GUI:Separator()
        
        -- =============================================
        -- 支持的副本列表
        -- =============================================
        if GUI:CollapsingHeader("支持的副本") then
            GUI:Indent(10)
            
            -- 按 mapId 排序
            local sortedRaids = {}
            for mapId, raidName in pairs(M.RaidMap) do
                table.insert(sortedRaids, {mapId = mapId, name = raidName})
            end
            table.sort(sortedRaids, function(a, b) return a.mapId < b.mapId end)
            
            for _, raid in ipairs(sortedRaids) do
                local isCurrentRaid = Player and Player.localmapid == raid.mapId
                if isCurrentRaid then
                    GUI:TextColored(0.2, 1.0, 0.2, 1.0, "► " .. raid.name .. " (当前)")
                else
                    GUI:Text("  " .. raid.name)
                end
            end
            
            GUI:Unindent(10)
        end
        
    end
    
    GUI:End()
    
end

d("[StringCore] MainUI.lua 加载完成")
