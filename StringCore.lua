-- =============================================
-- StringCore - TensorReaction 减伤规划系统
-- 支持 M9S/M10S/M11S/M12S 副本
-- =============================================

local StringCore = {}
local AddonName = "StringCore"
local core = StringCore

-- 上一次检测的状态
local lastMapId = 0
local lastJob = 0

-- =============================================
-- 初始化主模块
-- =============================================
core.InitStringGuide = function()
    -- 设置根路径（其他模块可能需要）
    StringCoreRoot = GetLuaModsPath() .. "StringCore\\LuaFiles\\"
    
    -- 检查 StringGuide 是否已被框架加载
    if not StringGuide then
        d("[StringCore] 错误: StringGuide 模块未加载")
        return false
    end
    
    -- 检查 Mitigation 是否已加载
    if not StringGuide.Mitigation then
        d("[StringCore] 错误: Mitigation 模块未加载")
        return false
    end
    
    d("[StringCore] 所有模块加载成功")
    
    -- 初始化配置
    StringGuide.InitConfig()
    
    -- 初始化当前副本和职业
    if Player then
        StringGuide.Mitigation.ChangeRaid(Player.localmapid)
        StringGuide.Mitigation.ChangeJob()
    end
    
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
    local tooltip = "StringCore 减伤规划系统"
    
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
    if not StringGuide.Mitigation then return end
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
    if not StringGuide.UI then return end
    
    -- 绘制主界面
    if StringGuide.UI.open and StringGuide.DrawMainUI then
        StringGuide.DrawMainUI()
    end
    
    -- 绘制减伤配置界面
    if StringGuide.MitigationUI and StringGuide.MitigationUI.open and StringGuide.DrawMitigationUI then
        StringGuide.DrawMitigationUI()
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
