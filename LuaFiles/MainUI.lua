-- =============================================
-- MainUI - 主界面
-- 包含：状态显示、功能按钮
-- =============================================

local function DrawUI(M)
    
    -- 设置窗口初始大小和位置
    GUI:SetNextWindowSize(280, 0, GUI.SetCond_Appearing)
    
    -- 创建主窗口
    M.UI.visible, M.UI.open = GUI:Begin("StringCore v" .. M.VERSION, M.UI.open)
    
    if M.UI.visible then
        
        -- =============================================
        -- 状态信息区域
        -- =============================================
        if GUI:CollapsingHeader("状态信息", GUI.TreeNodeFlags_DefaultOpen) then
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
        -- 队伍信息区域
        -- =============================================
        if GUI:CollapsingHeader("队伍信息") then
            GUI:Indent(10)
            
            -- 刷新队伍按钮
            if GUI:Button("刷新队伍", 120, 25) then
                M.LoadParty()
            end
            
            GUI:Spacing()
            
            -- 显示队伍成员
            if M.Party and next(M.Party) then
                for _, posName in ipairs(M.JobPosName) do
                    local member = M.Party[posName]
                    if member then
                        local jobName = M.GetJobNameById(member.job)
                        local displayName = member.name or "未知"
                        
                        -- 高亮自己
                        if M.SelfPos == posName then
                            GUI:TextColored(1.0, 0.8, 0.2, 1.0, posName .. ": ")
                        else
                            GUI:Text(posName .. ": ")
                        end
                        GUI:SameLine(0, 0)
                        GUI:Text("[" .. jobName .. "] " .. displayName)
                    else
                        GUI:TextColored(0.5, 0.5, 0.5, 1.0, posName .. ": 空位")
                    end
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
        if GUI:CollapsingHeader("功能", GUI.TreeNodeFlags_DefaultOpen) then
            GUI:Indent(10)
            
            -- 减伤配置按钮
            if M.IsInSupportedRaid() then
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
            
            GUI:Unindent(10)
        end
        
        GUI:Separator()
        
        -- =============================================
        -- 支持的副本列表
        -- =============================================
        if GUI:CollapsingHeader("支持的副本") then
            GUI:Indent(10)
            
            for mapId, raidName in pairs(M.RaidMap) do
                local isCurrentRaid = Player and Player.localmapid == mapId
                if isCurrentRaid then
                    GUI:TextColored(0.2, 1.0, 0.2, 1.0, "► " .. raidName .. " (当前)")
                else
                    GUI:Text("  " .. raidName)
                end
            end
            
            GUI:Unindent(10)
        end
        
    end
    
    GUI:End()
    
end

return DrawUI
