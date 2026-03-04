-- =============================================
-- MitigationUI - 减伤配置界面 (AIMWARE 风格)
-- =============================================

local M = StringGuide
if not M then return end

local T = M.UITheme
local C = T.C

M.DrawMitigationUI = function()
    if not M.IsInSupportedRaid() then
        M.MitigationUI.open = false
        return
    end

    T.PushTheme()
    GUI:SetNextWindowSize(400, 500, GUI.SetCond_Appearing)

    local windowTitle = "减伤配置 - " .. (M.CurrentRaid or "未知副本") .. "###MitigationWindow"
    M.MitigationUI.visible, M.MitigationUI.open = GUI:Begin(windowTitle, M.MitigationUI.open)

    if M.MitigationUI.visible then

        -- 开发模式：副本选择
        if M.IgnoreMapCheck then
            GUI:TextColored(C.danger[1], C.danger[2], C.danger[3], C.danger[4], "[开发模式]")
            GUI:SameLine(0, 8)
            GUI:PushItemWidth(200)
            local raids = {}
            for mapId, raidName in pairs(M.RaidMap) do
                table.insert(raids, { mapId = mapId, name = raidName })
            end
            table.sort(raids, function(a, b) return a.mapId < b.mapId end)
            local raidNames = {}
            local currentIndex = 1
            for i, raid in ipairs(raids) do
                table.insert(raidNames, raid.name)
                if raid.name == M.CurrentRaid then currentIndex = i end
            end
            local newIndex = GUI:Combo("##RaidSelect", currentIndex, raidNames)
            GUI:PopItemWidth()
            if newIndex ~= currentIndex and raidNames[newIndex] then
                M.CurrentRaid = raidNames[newIndex]
                M.Mitigation.LoadRaidConfig(M.CurrentRaid)
            end
            GUI:Separator()
        end

        -- 头部信息 (紧凑单行)
        GUI:Text("副本:")
        GUI:SameLine(0, 4)
        T.SuccessText(M.CurrentRaid or "未知")
        if Player then
            GUI:SameLine(0, 15)
            GUI:Text("职业:")
            GUI:SameLine(0, 4)
            GUI:TextColored(C.link[1], C.link[2], C.link[3], C.link[4], M.GetJobName(Player.job))
        end

        GUI:Separator()
        T.HintText("勾选需要使用减伤的 AOE:")

        GUI:Spacing()

        -- AOE 时间线
        local timeline = M.Mitigation.GetAoeTimeline()
        local configChanged = false

        if not M.Config.Mitigation then
            M.Config.Mitigation = {}
        end

        if timeline and #timeline > 0 then
            for _, phaseData in ipairs(timeline) do
                T.SectionHeader(phaseData.name)

                if phaseData.aoes and #phaseData.aoes > 0 then
                    for _, aoe in ipairs(phaseData.aoes) do
                        local isEnabled = M.Mitigation.IsEnabled(aoe.key)
                        local newValue = GUI:Checkbox(aoe.name .. "##" .. aoe.key, isEnabled)
                        if newValue ~= isEnabled then
                            M.Mitigation.SetEnabled(aoe.key, newValue)
                            configChanged = true
                        end
                        if GUI:IsItemHovered() then
                            GUI:SetTooltip("Key: " .. aoe.key)
                        end
                    end
                else
                    T.HintText("  (暂无 AOE 数据)")
                end
            end
        else
            GUI:TextColored(C.title[1], C.title[2], C.title[3], C.title[4], "暂无 AOE 时间线数据")
            GUI:Spacing()
            T.HintText("请在 Mitigation.lua 中添加:")
            GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4],
                "M.Mitigation.AoeTimeline[\"" .. (M.CurrentRaid or "RAID") .. "\"]")
        end

        if configChanged then
            M.Mitigation.SaveConfig()
        end

        GUI:Spacing()
        GUI:Separator()

        -- 底部按钮
        if GUI:Button("全选", 80, 25) then
            if timeline then
                for _, pd in ipairs(timeline) do
                    if pd.aoes then
                        for _, aoe in ipairs(pd.aoes) do M.Mitigation.SetEnabled(aoe.key, true) end
                    end
                end
                M.Mitigation.SaveConfig()
            end
        end
        GUI:SameLine(0, 6)
        if GUI:Button("全不选", 80, 25) then
            if timeline then
                for _, pd in ipairs(timeline) do
                    if pd.aoes then
                        for _, aoe in ipairs(pd.aoes) do M.Mitigation.SetEnabled(aoe.key, false) end
                    end
                end
                M.Mitigation.SaveConfig()
            end
        end
        GUI:SameLine(0, 6)
        if GUI:Button("重新加载", 80, 25) then
            M.Mitigation.LoadRaidConfig(M.CurrentRaid)
        end

    end

    GUI:End()
    T.PopTheme()
end

d("[StringCore] MitigationUI.lua 加载完成")
