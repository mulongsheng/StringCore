-- =============================================
-- MitigationUI - 减伤配置界面
-- 包含：AOE 复选框、配置自动保存
-- =============================================

local M = StringGuide
if not M then return end

M.DrawMitigationUI = function()
    
    -- 检查是否在支持的副本中
    if not M.IsInSupportedRaid() then
        M.MitigationUI.open = false
        return
    end
    
    -- 设置窗口初始大小和位置
    GUI:SetNextWindowSize(420, 0, GUI.SetCond_Appearing)
    
    -- 创建窗口
    local windowTitle = M.CurrentRaid .. " 减伤配置"
    M.MitigationUI.visible, M.MitigationUI.open = GUI:Begin(windowTitle, M.MitigationUI.open)
    
    if M.MitigationUI.visible then
        
        -- 获取当前职业的技能名称
        local skills = M.Mitigation.GetJobSkills()
        local targetSkill = skills[1]
        local fieldSkill = skills[2]
        
        -- =============================================
        -- 头部信息
        -- =============================================
        local jobName = M.GetJobNameById(Player.job)
        GUI:Text("职业: ")
        GUI:SameLine(0, 0)
        GUI:TextColored(0.5, 0.8, 1.0, 1.0, jobName)
        
        if targetSkill or fieldSkill then
            GUI:SameLine(0, 20)
            GUI:Text("技能: ")
            GUI:SameLine(0, 0)
            local skillText = ""
            if targetSkill then skillText = "[" .. targetSkill .. "]" end
            if fieldSkill then
                if skillText ~= "" then skillText = skillText .. " " end
                skillText = skillText .. "[" .. fieldSkill .. "]"
            end
            GUI:TextColored(0.8, 0.8, 0.8, 1.0, skillText)
        end
        
        GUI:Separator()
        
        -- =============================================
        -- 检查是否有 AOE 数据
        -- =============================================
        local aoeList = M.Mitigation.GetAoeNames()
        
        if #aoeList == 0 then
            GUI:Spacing()
            GUI:TextColored(1.0, 0.8, 0.2, 1.0, "当前副本暂无 AOE 数据")
            GUI:Text("请等待后续更新或手动添加 AOE 数据到:")
            GUI:TextColored(0.5, 0.8, 1.0, 1.0, "LuaFiles/Mitigation.lua")
            GUI:Spacing()
        else
            -- =============================================
            -- 按阶段显示 AOE 复选框
            -- =============================================
            local phaseCount = M.Mitigation.GetPhaseCount()
            
            for phase = 1, phaseCount do
                local phaseAoes = M.Mitigation.GetAoeNamesByPhase(phase)
                
                if #phaseAoes > 0 then
                    -- 阶段折叠标题
                    GUI:SetNextTreeNodeOpened(true, GUI.SetCond_Appearing)
                    if GUI:CollapsingHeader("P" .. phase) then
                        
                        -- 绘制表头
                        GUI:Columns(3, "MitigationTable_P" .. phase, false)
                        GUI:SetColumnWidth(0, 180)
                        GUI:SetColumnWidth(1, 100)
                        GUI:SetColumnWidth(2, 100)
                        
                        GUI:TextColored(0.7, 0.7, 0.7, 1.0, "AOE 技能")
                        GUI:NextColumn()
                        if targetSkill then
                            GUI:TextColored(0.7, 0.7, 0.7, 1.0, targetSkill)
                        end
                        GUI:NextColumn()
                        if fieldSkill then
                            GUI:TextColored(0.7, 0.7, 0.7, 1.0, fieldSkill)
                        end
                        GUI:NextColumn()
                        
                        GUI:Separator()
                        
                        -- 绘制每个 AOE 的复选框
                        for _, aoe in ipairs(phaseAoes) do
                            local key = aoe.key
                            
                            -- 确保配置项存在
                            if not M.Config.Mitigation[key] then
                                M.Config.Mitigation[key] = {
                                    p = aoe.p,
                                    Target = false,
                                    Field = false
                                }
                            end
                            
                            -- 第一列：AOE 名称
                            GUI:Dummy(5, 0)
                            GUI:SameLine(0, 0)
                            GUI:AlignTextToFramePadding()
                            GUI:BulletText(aoe.name)
                            
                            -- 添加 tooltip 显示 macroInfo
                            if aoe.macroInfo and GUI:IsItemHovered() then
                                GUI:SetTooltip(aoe.macroInfo)
                            end
                            GUI:NextColumn()
                            
                            -- 第二列：Target 技能复选框
                            if targetSkill and M.Config.Mitigation[key].Target ~= nil then
                                local newValue = GUI:Checkbox("##Target_" .. key, M.Config.Mitigation[key].Target)
                                if newValue ~= M.Config.Mitigation[key].Target then
                                    M.Config.Mitigation[key].Target = newValue
                                end
                            end
                            GUI:NextColumn()
                            
                            -- 第三列：Field 技能复选框
                            if fieldSkill and M.Config.Mitigation[key].Field ~= nil then
                                local newValue = GUI:Checkbox("##Field_" .. key, M.Config.Mitigation[key].Field)
                                if newValue ~= M.Config.Mitigation[key].Field then
                                    M.Config.Mitigation[key].Field = newValue
                                end
                            end
                            GUI:NextColumn()
                        end
                        
                        GUI:Columns(1)
                    end
                end
            end
        end
        
        GUI:Separator()
        
        -- =============================================
        -- 底部按钮
        -- =============================================
        GUI:Spacing()
        
        -- 全选/取消全选按钮
        if #aoeList > 0 then
            if GUI:Button("全选 Target", 100, 25) then
                if targetSkill then
                    for _, aoe in ipairs(aoeList) do
                        if M.Config.Mitigation[aoe.key] then
                            M.Config.Mitigation[aoe.key].Target = true
                        end
                    end
                end
            end
            
            GUI:SameLine(0, 10)
            
            if GUI:Button("取消 Target", 100, 25) then
                if targetSkill then
                    for _, aoe in ipairs(aoeList) do
                        if M.Config.Mitigation[aoe.key] then
                            M.Config.Mitigation[aoe.key].Target = false
                        end
                    end
                end
            end
            
            GUI:SameLine(0, 20)
            
            if GUI:Button("全选 Field", 100, 25) then
                if fieldSkill then
                    for _, aoe in ipairs(aoeList) do
                        if M.Config.Mitigation[aoe.key] then
                            M.Config.Mitigation[aoe.key].Field = true
                        end
                    end
                end
            end
            
            GUI:SameLine(0, 10)
            
            if GUI:Button("取消 Field", 100, 25) then
                if fieldSkill then
                    for _, aoe in ipairs(aoeList) do
                        if M.Config.Mitigation[aoe.key] then
                            M.Config.Mitigation[aoe.key].Field = false
                        end
                    end
                end
            end
        end
        
        GUI:Spacing()
        
        -- 手动保存按钮
        if GUI:Button("保存配置", 100, 25) then
            M.Mitigation.SaveConfig()
        end
        
        GUI:SameLine(0, 10)
        
        -- 重置为默认配置
        if GUI:Button("重置配置", 100, 25) then
            local jobDefault = M.Mitigation.LoadJobDefault(M.CurrentRaid)
            if jobDefault then
                M.Config.Mitigation = jobDefault
            else
                M.Config.Mitigation = M.Mitigation.LoadDefault(M.CurrentRaid)
            end
            d("[StringCore] 配置已重置")
        end
        
    end
    
    -- 窗口关闭时自动保存
    if not M.MitigationUI.open then
        M.Mitigation.SaveConfig()
    end
    
    GUI:End()
    
end

d("[StringCore] MitigationUI.lua 加载完成")
