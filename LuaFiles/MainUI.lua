-- =============================================
-- MainUI - 主界面 (AIMWARE 风格)
-- =============================================

local M = StringGuide
if not M then return end

local T = M.UITheme
local C = T.C

-- =============================================
-- 主窗口
-- =============================================
M.DrawMainUI = function()
    T.PushTheme()
    GUI:SetNextWindowSize(280, 0, GUI.SetCond_Appearing)

    M.UI.visible, M.UI.open = GUI:Begin("StringCore v" .. M.VERSION, M.UI.open)

    if M.UI.visible then

        -- 状态信息
        if Player then
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

        -- 功能按钮
        local btnH = 28

        if GUI:Button("工具箱", 110, btnH) then
            M.ArgusBuilderUI.open = not M.ArgusBuilderUI.open
        end
        if M.ArgusBuilderUI.open then
            GUI:SameLine(0, 2)
            T.SuccessText("*")
        end

        GUI:SameLine(0, 6)
        if GUI:Button("队伍窗口", 90, btnH) then
            M.PartyOverlay.open = not M.PartyOverlay.open
        end
        if M.PartyOverlay.open then
            GUI:SameLine(0, 2)
            T.SuccessText("*")
        end


    end

    GUI:End()
    T.PopTheme()
end

-- =============================================
-- 队伍悬浮窗 (独立小窗口，始终显示)
-- =============================================
M.DrawPartyOverlay = function()
    T.PushTheme()

    -- 紧凑窗口，无缩放限制
    GUI:SetNextWindowSize(200, 0, GUI.SetCond_Appearing)
    GUI:PushStyleVar(GUI.StyleVar_WindowPadding, 6, 4)
    GUI:PushStyleVar(GUI.StyleVar_ItemSpacing, 4, 2)

    M.PartyOverlay.visible, M.PartyOverlay.open = GUI:Begin(
        "队伍##PartyOverlay", M.PartyOverlay.open,
        GUI.WindowFlags_NoCollapse + GUI.WindowFlags_AlwaysAutoResize
    )

    if M.PartyOverlay.visible then

        -- 刷新按钮
        if GUI:Button("刷新##PORefresh", 45, 18) then
            M.LoadParty()
        end
        GUI:SameLine(0, 6)
        if M.SelfPos then
            GUI:TextColored(C.gold[1], C.gold[2], C.gold[3], C.gold[4], "我=" .. M.SelfPos)
        end

        GUI:Spacing()

        -- 队伍列表
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
                elseif posName == "MT" or posName == "ST" or posName == "T" then
                    posColor = { 0.55, 0.75, 1.0, 1.0 }
                elseif posName == "H1" or posName == "H2" or posName == "H" then
                    posColor = C.success
                else
                    posColor = C.danger
                end

                -- 职能标签
                GUI:TextColored(posColor[1], posColor[2], posColor[3], posColor[4], posName)
                GUI:SameLine(30, 0)

                if isEmpty then
                    GUI:TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4], "--")
                else
                    -- 拖动排序
                    local label = jobName .. " " .. displayName

                    local isSelected = (i == M.DragState.selected)
                    GUI:Selectable(label .. "##PO" .. i, isSelected)

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
            T.HintText("点刷新加载队伍")
        end

    end

    GUI:End()
    GUI:PopStyleVar(2)
    T.PopTheme()
end

d("[StringCore] MainUI.lua 加载完成")
