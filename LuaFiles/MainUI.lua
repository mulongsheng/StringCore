-- =============================================
-- MainUI - 主界面 (AIMWARE 风格)
-- =============================================

local M = StringGuide
if not M then return end

local T = M.UITheme
local C = T.C

M.DrawMainUI = function()
    T.PushTheme()
    GUI:SetNextWindowSize(300, 0, GUI.SetCond_Appearing)

    M.UI.visible, M.UI.open = GUI:Begin("StringCore v" .. M.VERSION, M.UI.open)

    if M.UI.visible then

        -- =============================================
        -- 状态信息 (始终展开紧凑显示)
        -- =============================================
        local raidName = M.GetCurrentRaidName()
        local inRaid = M.IsInSupportedRaid()

        -- 第一行: 副本 + 职业
        GUI:Text("副本:")
        GUI:SameLine(0, 4)
        if inRaid then
            T.SuccessText(raidName)
        else
            T.DangerText(raidName)
        end

        if Player then
            GUI:SameLine(0, 15)
            GUI:Text("职业:")
            GUI:SameLine(0, 4)
            GUI:TextColored(C.link[1], C.link[2], C.link[3], C.link[4], M.GetJobNameById(Player.job))

            if M.SelfPos then
                GUI:SameLine(0, 15)
                GUI:Text("位置:")
                GUI:SameLine(0, 4)
                GUI:TextColored(C.gold[1], C.gold[2], C.gold[3], C.gold[4], M.SelfPos)
            end
        end

        GUI:Separator()

        -- =============================================
        -- 功能按钮 (横排)
        -- =============================================
        local btnW = 90
        local btnH = 28

        if inRaid or M.IgnoreMapCheck then
            if GUI:Button("减伤配置", btnW, btnH) then
                M.MitigationUI.open = not M.MitigationUI.open
            end
            if M.MitigationUI.open then
                GUI:SameLine(0, 2)
                T.SuccessText("*")
            end
            GUI:SameLine(0, 6)
        end

        if GUI:Button("工具箱", btnW + 20, btnH) then
            M.ArgusBuilderUI.open = not M.ArgusBuilderUI.open
        end
        if M.ArgusBuilderUI.open then
            GUI:SameLine(0, 2)
            T.SuccessText("*")
        end

        GUI:Separator()

        -- =============================================
        -- 设置
        -- =============================================
        M.DevelopMode = GUI:Checkbox("开发模式##dev", M.DevelopMode)
        GUI:SameLine(0, 15)
        M.IgnoreMapCheck = GUI:Checkbox("无视地图##map", M.IgnoreMapCheck)
        if M.IgnoreMapCheck then
            GUI:SameLine(0, 4)
            GUI:TextColored(C.danger[1], C.danger[2], C.danger[3], C.danger[4], "!")
        end

        -- =============================================
        -- 队伍信息 (可折叠)
        -- =============================================
        if GUI:CollapsingHeader("队伍信息##StringCore") then
            GUI:Indent(6)

            if GUI:Button("刷新队伍", 80, 22) then
                M.LoadParty()
            end
            GUI:SameLine(0, 8)
            T.HintText("(拖动调整职能)")
            GUI:Spacing()

            if M.PartyList and #M.PartyList > 0 then
                for i = 1, #M.PartyList do
                    local member = M.PartyList[i]
                    local posName = M.JobPosName[i] or "??"
                    local jobName = M.GetJobName(member.job)
                    local displayName = member.name or "空位"
                    local isEmpty = (member.id == 0)

                    local isSelf = (Player and member.id == Player.id)
                    local posColor
                    if isSelf then
                        posColor = C.gold
                    elseif posName == "MT" or posName == "ST" then
                        posColor = { 0.55, 0.75, 1.0, 1.0 }
                    elseif posName == "H1" or posName == "H2" then
                        posColor = C.success
                    else
                        posColor = C.danger
                    end

                    GUI:TextColored(posColor[1], posColor[2], posColor[3], posColor[4], posName .. ":")
                    GUI:SameLine(50, 0)

                    local label = isEmpty and "[空位]" or ("[" .. jobName .. "] " .. displayName)
                    if isEmpty then
                        GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4], label)
                    else
                        local isSelected = (i == M.DragState.selected)
                        GUI:Selectable(label, isSelected)

                        local hoverFlags = GUI.HoveredFlags_AllowWhenBlockedByPopup + GUI.HoveredFlags_AllowWhenBlockedByActiveItem + GUI.HoveredFlags_AllowWhenOverlapped
                        if GUI:IsItemHovered(hoverFlags) then
                            if GUI:IsMouseDown(0) then
                                if M.DragState.pos == 0 then
                                    if M.DragState.pos ~= i then M.DragState.pos = i end
                                    if M.DragState.selected ~= i then M.DragState.selected = i end
                                elseif M.DragState.pos ~= i then
                                    local move = M.PartyList[M.DragState.pos]
                                    M.PartyList[M.DragState.pos] = M.PartyList[i]
                                    M.PartyList[i] = move
                                    M.DragState.pos = i
                                    if M.DragState.selected ~= i then M.DragState.selected = i end
                                    M.SyncPartyFromList()
                                end
                            end
                        end
                    end
                end

                if M.DragState.pos ~= 0 and (GUI:IsMouseReleased(0) or not GUI:IsMouseDown(0)) then
                    M.DragState.pos = 0
                end
            else
                T.HintText("未加载队伍信息")
            end

            GUI:Unindent(6)
        end

        -- =============================================
        -- 支持的副本 (可折叠)
        -- =============================================
        if GUI:CollapsingHeader("支持的副本##StringCore") then
            GUI:Indent(6)

            local sortedRaids = {}
            for mapId, rn in pairs(M.RaidMap) do
                table.insert(sortedRaids, { mapId = mapId, name = rn })
            end
            table.sort(sortedRaids, function(a, b) return a.mapId < b.mapId end)

            for _, raid in ipairs(sortedRaids) do
                local isCurrentRaid = Player and Player.localmapid == raid.mapId
                if isCurrentRaid then
                    T.SuccessText("> " .. raid.name .. " (当前)")
                else
                    GUI:Text("  " .. raid.name)
                end
            end

            GUI:Unindent(6)
        end

    end

    GUI:End()
    T.PopTheme()
end

d("[StringCore] MainUI.lua 加载完成")
