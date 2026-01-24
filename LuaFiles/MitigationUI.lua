-- =============================================
-- MitigationUI - 减伤配置界面
-- 按时间线显示 AOE 列表，勾选框控制是否启用
-- =============================================

local M = StringGuide
if not M then return end

M.DrawMitigationUI = function()
    
    -- 检查是否在支持的副本中
    if not M.IsInSupportedRaid() then
        M.MitigationUI.open = false
        return
    end
    
    -- 设置窗口大小（使用固定ID保持位置）
    GUI:SetNextWindowSize(400, 500, GUI.SetCond_Appearing)
    
    -- 创建窗口（使用固定ID，标题动态显示副本名）
    local windowTitle = "减伤配置 - " .. (M.CurrentRaid or "未知副本") .. "###MitigationWindow"
    M.MitigationUI.visible, M.MitigationUI.open = GUI:Begin(windowTitle, M.MitigationUI.open)
    
    if M.MitigationUI.visible then
        
        -- =============================================
        -- 开发者模式：副本选择
        -- =============================================
        if M.IgnoreMapCheck then
            GUI:TextColored(1.0, 0.5, 0.2, 1.0, "[开发模式] 手动选择副本:")
            
            -- 获取所有副本名称并排序
            local raidNames = {}
            for mapId, raidName in pairs(M.RaidMap) do
                table.insert(raidNames, raidName)
            end
            table.sort(raidNames)
            
            -- 查找当前副本索引
            local currentIndex = 1
            for i, name in ipairs(raidNames) do
                if name == M.CurrentRaid then
                    currentIndex = i
                    break
                end
            end
            
            -- 副本下拉选择
            GUI:PushItemWidth(200)
            local newIndex = GUI:Combo("##RaidSelect", currentIndex, raidNames)
            GUI:PopItemWidth()
            
            if newIndex ~= currentIndex and raidNames[newIndex] then
                M.CurrentRaid = raidNames[newIndex]
                M.Mitigation.LoadRaidConfig(M.CurrentRaid)
                d("[StringCore] 手动切换副本: " .. M.CurrentRaid)
            end
            
            GUI:Separator()
        end
        
        -- =============================================
        -- 头部信息
        -- =============================================
        GUI:Text("当前副本: ")
        GUI:SameLine(0, 0)
        GUI:TextColored(0.2, 1.0, 0.2, 1.0, M.CurrentRaid or "未知")
        
        GUI:Text("职业: ")
        GUI:SameLine(0, 0)
        if Player then
            local jobName = M.GetJobName(Player.job)
            GUI:TextColored(0.5, 0.8, 1.0, 1.0, jobName)
        end
        
        GUI:Separator()
        
        -- =============================================
        -- 使用说明
        -- =============================================
        GUI:TextColored(0.7, 0.7, 0.7, 1.0, "勾选需要使用减伤的 AOE:")
        GUI:TextColored(0.5, 0.5, 0.5, 1.0, "条件: return StringGuide.Mitigation.IsEnabled(\"KEY\")")
        
        GUI:Spacing()
        GUI:Separator()
        
        -- =============================================
        -- AOE 时间线列表
        -- =============================================
        local timeline = M.Mitigation.GetAoeTimeline()
        local configChanged = false
        
        -- 确保配置表存在
        if not M.Config.Mitigation then
            M.Config.Mitigation = {}
        end
        
        if timeline and #timeline > 0 then
            for _, phaseData in ipairs(timeline) do
                -- 阶段标题
                GUI:Spacing()
                GUI:TextColored(1.0, 0.8, 0.2, 1.0, "===== " .. phaseData.name .. " =====")
                GUI:Spacing()
                
                -- 该阶段的 AOE 列表
                if phaseData.aoes and #phaseData.aoes > 0 then
                    for _, aoe in ipairs(phaseData.aoes) do
                        -- 获取当前配置状态
                        local isEnabled = M.Mitigation.IsEnabled(aoe.key)
                        
                        -- 勾选框
                        local newValue = GUI:Checkbox(aoe.name .. "##" .. aoe.key, isEnabled)
                        
                        -- 如果值改变了
                        if newValue ~= isEnabled then
                            M.Mitigation.SetEnabled(aoe.key, newValue)
                            configChanged = true
                        end
                        
                        -- 鼠标悬停时显示 key（用于复制到条件）
                        if GUI:IsItemHovered() then
                            GUI:SetTooltip("Key: " .. aoe.key)
                        end
                    end
                else
                    GUI:TextColored(0.5, 0.5, 0.5, 1.0, "  (暂无 AOE 数据)")
                end
            end
        else
            GUI:TextColored(1.0, 0.8, 0.2, 1.0, "暂无 AOE 时间线数据")
            GUI:Spacing()
            GUI:TextColored(0.7, 0.7, 0.7, 1.0, "请在 Mitigation.lua 中添加:")
            GUI:TextColored(0.6, 0.6, 0.6, 1.0, "M.Mitigation.AoeTimeline[\"" .. (M.CurrentRaid or "RAID") .. "\"]")
        end
        
        -- 自动保存配置
        if configChanged then
            M.Mitigation.SaveConfig()
        end
        
        GUI:Spacing()
        GUI:Separator()
        
        -- =============================================
        -- 底部按钮
        -- =============================================
        if GUI:Button("全选", 80, 25) then
            for _, phaseData in ipairs(timeline) do
                if phaseData.aoes then
                    for _, aoe in ipairs(phaseData.aoes) do
                        M.Mitigation.SetEnabled(aoe.key, true)
                    end
                end
            end
            M.Mitigation.SaveConfig()
        end
        
        GUI:SameLine()
        
        if GUI:Button("全不选", 80, 25) then
            for _, phaseData in ipairs(timeline) do
                if phaseData.aoes then
                    for _, aoe in ipairs(phaseData.aoes) do
                        M.Mitigation.SetEnabled(aoe.key, false)
                    end
                end
            end
            M.Mitigation.SaveConfig()
        end
        
        GUI:SameLine()
        
        if GUI:Button("重新加载", 80, 25) then
            M.Mitigation.LoadRaidConfig(M.CurrentRaid)
            d("[StringCore] 配置已重新加载")
        end
        
    end
    
    GUI:End()
    
end

d("[StringCore] MitigationUI.lua 加载完成")
