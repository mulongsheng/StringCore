-- =============================================
-- StringCore - 工具箱 & 队伍管理系统
-- =============================================

local StringCore = {}
local AddonName = "StringCore"
local core = StringCore

-- 上一次检测的状态
local lastMapId = 0
local lastJob = 0

-- 队伍自动刷新状态
local pendingPartyRefresh = false
local partyRefreshRequestTime = 0
local PARTY_REFRESH_TIMEOUT = 5000  -- 超时 5 秒

-- =============================================
-- 初始化主模块
-- =============================================
core.InitStringGuide = function()
    StringCoreRoot = GetLuaModsPath() .. "StringCore\\LuaFiles\\"
    
    if not StringGuide then
        d("[StringCore] 错误: StringGuide 模块未加载")
        return false
    end
    
    d("[StringCore] 所有模块加载成功")
    
    -- 初始化配置
    StringGuide.InitConfig()
    
    return true
end

-- =============================================
-- 模块初始化（注册菜单）
-- =============================================
core.Initialize = function()
    local success = core.InitStringGuide()
    
    if not success then
        d("[StringCore] 初始化失败")
        return
    end
    
    -- 注册到 FFXIVMinion 菜单栏
    local iconPath = GetLuaModsPath() .. "StringCore\\Image\\MainIcon.png"
    local tooltip = "String的时尚小垃圾"
    
    ml_gui.ui_mgr:AddMember({
        id = "StringCore",
        name = "StringCore",
        onClick = function()
            if StringGuide and StringGuide.UI then
                StringGuide.UI.open = not StringGuide.UI.open
            end
        end,
        tooltip = tooltip,
        texture = iconPath
    }, "FFXIVMINION##MENU_HEADER")
    
    d("[StringCore] 初始化完成")
end

-- =============================================
-- 游戏循环更新
-- =============================================
core.Update = function()
    if not StringGuide then return end
    if not Player then return end
    
    -- 检测地图切换 → mapid 不为 0 时标记待刷新队伍
    local currentMapId = Player.localmapid
    if currentMapId ~= lastMapId then
        lastMapId = currentMapId
        d("[StringCore] 地图切换: " .. tostring(currentMapId))
        if currentMapId ~= 0 then
            pendingPartyRefresh = true
            partyRefreshRequestTime = Now()
            d("[StringCore] 将在 5 秒后自动刷新队伍")
        end
    end
    
    -- 检测职业切换
    local currentJob = Player.job
    if currentJob ~= lastJob then
        lastJob = currentJob
        d("[StringCore] 职业切换: " .. tostring(currentJob))
    end
    
    -- 延迟刷新队伍：等待队友实体加载完毕
    if pendingPartyRefresh then
        local elapsed = TimeSince(partyRefreshRequestTime)
        -- 超时放弃
        if elapsed > PARTY_REFRESH_TIMEOUT then
            pendingPartyRefresh = false
            d("[StringCore] 队伍刷新超时，未检测到队友")
            return
        end
        -- 检测队友是否已加载
        if TensorCore and TensorCore.getEntityGroupList then
            local partyList = TensorCore.getEntityGroupList("Party")
            local count = 0
            for _ in pairs(partyList) do count = count + 1 end
            if count > 0 then
                pendingPartyRefresh = false
                StringGuide.LoadParty()
                d("[StringCore] 地图切换后自动刷新队伍完成")
            end
        end
    end
end

-- =============================================
-- 绘制 UI
-- =============================================
core.Draw = function()
    if not StringGuide then return end
    if not StringGuide.UI then return end
    
    -- 绘制主界面
    if StringGuide.UI.open and StringGuide.DrawMainUI then
        StringGuide.DrawMainUI()
    end
    
    -- 绘制队伍悬浮窗
    if StringGuide.PartyOverlay and StringGuide.PartyOverlay.open and StringGuide.DrawPartyOverlay then
        StringGuide.DrawPartyOverlay()
    end
    
    -- 绘制合并工具箱 (MapEffect + Argus)
    if StringGuide.ArgusBuilderUI and StringGuide.ArgusBuilderUI.open and StringGuide.DrawArgusBuilderUI then
        StringGuide.DrawArgusBuilderUI()
    end
end

-- =============================================
-- 注册事件
-- =============================================
if core.Initialize and core.Update and core.Draw then
    RegisterEventHandler("Module.Initalize", core.Initialize, AddonName)
    RegisterEventHandler("Gameloop.Update", core.Update, AddonName)
    RegisterEventHandler("Gameloop.Draw", core.Draw, AddonName)
else
    d("[StringCore] 警告: 部分函数未定义，事件注册失败")
end

d("[StringCore] StringCore.lua 加载完成")

return StringCore
