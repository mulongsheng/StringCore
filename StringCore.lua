-- =============================================
-- StringCore - TensorReaction 减伤规划系统
-- 支持 M9S/M10S/M11S/M12S 副本
-- =============================================

local StringCore = {}
local AddonName = "StringCore"
local core = StringCore

-- 热加载 UI 绘制器
local mainDrawer, mitigationDrawer

-- 上一次检测的状态
local lastMapId = 0
local lastJob = 0

-- =============================================
-- 初始化主模块
-- =============================================
core.InitStringGuide = function()
    StringCoreRoot = GetLuaModsPath() .. "StringCore\\LuaFiles\\"
    
    -- 加载核心模块
    StringGuide = FileLoad(StringCoreRoot .. "StringGuide.lua")
    
    -- 加载减伤数据定义模块
    local mitigationDef = FileLoad(StringCoreRoot .. "Mitigation.lua")
    mitigationDef(StringGuide)  -- 注入到 StringGuide
    
    -- 初始化配置
    StringGuide.InitConfig()
    
    -- 初始化当前副本和职业
    if Player then
        StringGuide.Mitigation.ChangeRaid(Player.localmapid)
        StringGuide.Mitigation.ChangeJob()
    end
end

-- =============================================
-- 模块初始化（注册菜单）
-- =============================================
core.Initialize = function()
    core.InitStringGuide()
    
    -- 注册到 FFXIVMinion 菜单栏
    local iconPath = GetLuaModsPath() .. "StringCore\\Image\\MainIcon.png"
    local tooltip = "StringCore 减伤规划系统"
    
    ml_gui.ui_mgr:AddMember({
        id = "StringCore",
        name = "StringCore",
        onClick = function()
            StringGuide.UI.open = not StringGuide.UI.open
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
    
    -- 检测副本切换
    local currentMapId = Player.localmapid
    if currentMapId ~= lastMapId then
        lastMapId = currentMapId
        StringGuide.Mitigation.ChangeRaid(currentMapId)
        d("[StringCore] 副本切换: " .. tostring(currentMapId))
    end
    
    -- 检测职业切换
    local currentJob = Player.job
    if currentJob ~= lastJob then
        lastJob = currentJob
        StringGuide.Mitigation.ChangeJob()
        d("[StringCore] 职业切换: " .. tostring(currentJob))
    end
end

-- =============================================
-- 绘制 UI
-- =============================================
core.Draw = function()
    if not StringGuide then return end
    
    -- 绘制主界面
    if StringGuide.UI.open then
        core.DrawMainUI()
    end
    
    -- 绘制减伤配置界面
    if StringGuide.MitigationUI and StringGuide.MitigationUI.open then
        core.DrawMitigationUI()
    end
end

-- =============================================
-- 绘制主界面
-- =============================================
core.DrawMainUI = function()
    -- 开发模式下每帧重新加载 UI 文件
    if StringGuide.DevelopMode then
        mainDrawer = FileLoad(StringCoreRoot .. "MainUI.lua")
    else
        if not mainDrawer then
            mainDrawer = FileLoad(StringCoreRoot .. "MainUI.lua")
        end
    end
    
    if mainDrawer then
        mainDrawer(StringGuide)
    end
end

-- =============================================
-- 绘制减伤配置界面
-- =============================================
core.DrawMitigationUI = function()
    -- 开发模式下每帧重新加载 UI 文件
    if StringGuide.DevelopMode then
        mitigationDrawer = FileLoad(StringCoreRoot .. "MitigationUI.lua")
    else
        if not mitigationDrawer then
            mitigationDrawer = FileLoad(StringCoreRoot .. "MitigationUI.lua")
        end
    end
    
    if mitigationDrawer then
        mitigationDrawer(StringGuide)
    end
end

-- =============================================
-- 注册事件
-- =============================================
RegisterEventHandler("Module.Initalize", core.Initialize, AddonName)
RegisterEventHandler("Gameloop.Update", core.Update, AddonName)
RegisterEventHandler("Gameloop.Draw", core.Draw, AddonName)

return StringCore
