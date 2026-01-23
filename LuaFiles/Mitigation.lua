-- =============================================
-- Mitigation - 减伤数据定义模块
-- 包含：AoeNames、JobMap、配置加载/保存
-- 直接操作全局变量 StringGuide
-- =============================================

-- 等待 StringGuide 加载（由 module.def 顺序保证）
local M = StringGuide
if not M then
    d("[StringCore] 警告: Mitigation.lua 加载时 StringGuide 不存在，跳过")
    return
end

M.Mitigation = {}
    
    -- =============================================
    -- 职业技能映射
    -- [职业ID] = { "Target技能名", "Field技能名" }
    -- Target: 针对目标的减伤（如牵制、雪仇）
    -- Field: 场地/团队减伤（如真言、桑巴）
    -- nil 表示该职业没有对应技能
    -- =============================================
    M.Mitigation.JobMap = {
        --- TANK (目标减伤, 场地减伤)
        [19] = { "雪仇", "幕帘" },      -- 骑士
        [21] = { "雪仇", "摆脱" },      -- 战士
        [32] = { "雪仇", "步道" },      -- 黑骑
        [37] = { "雪仇", "光心" },      -- 绝枪
        
        --- Healer (无目标减伤, 团队减伤)
        [24] = { nil, "节制" },         -- 白魔
        [28] = { nil, "炽天" },         -- 学者
        [33] = { nil, "大宇宙" },       -- 占星
        [40] = { nil, "泛输" },         -- 贤者
        
        --- Melee (牵制, 可选第二技能)
        [34] = { "牵制", nil },         -- 武士
        [20] = { "牵制", "真言" },      -- 武僧
        [22] = { "牵制", nil },         -- 龙骑
        [30] = { "牵制", nil },         -- 忍者
        [39] = { "牵制", nil },         -- 钐镰
        [41] = { "牵制", nil },         -- 蝰蛇
        
        --- Range (昏乱/大地神, 团队减伤)
        [31] = { "扳手", "策动" },      -- 机工
        [23] = { "大地神", "行吟" },    -- 诗人
        [38] = { nil, "桑巴" },         -- 舞者
        
        --- Magic (昏乱, 可选第二技能)
        [27] = { "昏乱", nil },         -- 召唤
        [42] = { "昏乱", "画盾" },      -- 绘灵
        [25] = { "昏乱", nil },         -- 黑魔
        [35] = { "昏乱", "抗死" },      -- 赤魔
    }
    
    -- =============================================
    -- AOE 技能列表（按副本分组）
    -- 格式：{ key = "唯一标识", p = 阶段, name = "显示名称", macroInfo = "宏简称" }
    -- =============================================
    -- =============================================
    -- AOE 时间线数据（按副本和阶段组织）
    -- 格式：{ phase = "P1", name = "阶段名", aoes = { {key, name}, ... } }
    -- =============================================
    M.Mitigation.AoeTimeline = {
        -- 永远之暗歼灭战 (mapId: 1295)
        ["永远之暗歼灭战"] = {
            { phase = "P1", name = "P1 阶段", aoes = {
                -- TODO: 由用户提供 AOE 数据
            }},
        },
        
        -- M9S (mapId: 1321)
        ["M9S"] = {
            { phase = "P1", name = "P1 阶段", aoes = {
                { key = "P1_AOE1", name = "示例AOE1" },
                { key = "P1_AOE2", name = "示例AOE2" },
            }},
            { phase = "P2", name = "P2 阶段", aoes = {
                { key = "P2_AOE1", name = "示例AOE3" },
            }},
            -- TODO: 由用户补充完整 AOE 数据
        },
        
        -- M10S (mapId: 1323)
        ["M10S"] = {
            { phase = "P1", name = "P1 阶段", aoes = {
                -- TODO: 由用户提供 AOE 数据
            }},
        },
        
        -- M11S (mapId: 1325)
        ["M11S"] = {
            { phase = "P1", name = "P1 阶段", aoes = {
                -- TODO: 由用户提供 AOE 数据
            }},
        },
        
        -- M12S (mapId: 1327)
        ["M12S"] = {
            { phase = "P1", name = "P1 阶段", aoes = {
                -- TODO: 由用户提供 AOE 数据
            }},
        },
    }
    
    -- =============================================
    -- 获取当前副本的 AOE 时间线
    -- =============================================
    M.Mitigation.GetAoeTimeline = function(raidId)
        local raid = raidId or M.CurrentRaid
        if raid then
            return M.Mitigation.AoeTimeline[raid] or {}
        end
        return {}
    end
    
    -- =============================================
    -- 加载默认配置
    -- =============================================
    M.Mitigation.LoadDefault = function(raidId)
        local defaultConfig = {}
        local timeline = M.Mitigation.AoeTimeline[raidId] or {}
        
        -- 遍历时间线中所有阶段的 AOE
        for _, phaseData in ipairs(timeline) do
            if phaseData.aoes then
                for _, aoe in ipairs(phaseData.aoes) do
                    if aoe.key then
                        defaultConfig[aoe.key] = false
                    end
                end
            end
        end
        
        return defaultConfig
    end
    
    -- =============================================
    -- 加载职业默认配置模板
    -- =============================================
    M.Mitigation.LoadJobDefault = function(raidId)
        if not Player then return nil end
        
        local jobName = M.GetJobNameById(Player.job)
        local defaultPath = StringCoreRoot .. "MitigationDefault\\" .. raidId .. "\\"
        
        -- 尝试加载职业特定默认配置
        local defaultFile = defaultPath .. jobName .. "_default.lua"
        if FileExists(defaultFile) then
            return FileLoad(defaultFile)
        end
        
        -- 尝试加载职能默认配置
        local roleName = nil
        if M.IsTank(Player.job) then
            roleName = "tank"
        elseif M.IsHealer(Player.job) then
            roleName = "healer"
        elseif M.IsMelee(Player.job) then
            roleName = "melee"
        elseif M.IsRange(Player.job) then
            roleName = "range"
        elseif M.IsMagic(Player.job) then
            roleName = "magic"
        end
        
        if roleName then
            defaultFile = defaultPath .. roleName .. "_default.lua"
            if FileExists(defaultFile) then
                return FileLoad(defaultFile)
            end
        end
        
        return nil
    end
    
    -- =============================================
    -- 副本切换处理
    -- =============================================
    M.Mitigation.ChangeRaid = function(mapId)
        local raidId = M.RaidMap[mapId]
        
        if raidId then
            M.CurrentRaid = raidId
            d("[StringCore] 当前副本: " .. raidId)
            
            -- 加载该副本的配置
            M.Mitigation.LoadRaidConfig(raidId)
        else
            M.CurrentRaid = nil
        end
    end
    
    -- =============================================
    -- 加载副本配置
    -- =============================================
    M.Mitigation.LoadRaidConfig = function(raidId)
        if not Player then return end
        
        local jobName = M.GetJobNameById(Player.job)
        local configPath = M.ConfigPath .. raidId .. "\\" .. jobName
        local configFile = "Mitigation.lua"
        
        -- 尝试加载已保存的配置
        local savedConfig = M.LoadConfig(configPath, configFile)
        
        if savedConfig then
            M.Config.Mitigation = savedConfig
            d("[StringCore] 已加载配置: " .. configPath .. "\\" .. configFile)
        else
            -- 尝试加载职业默认配置
            local jobDefault = M.Mitigation.LoadJobDefault(raidId)
            if jobDefault then
                M.Config.Mitigation = jobDefault
                d("[StringCore] 已加载职业默认配置")
            else
                -- 使用空白默认配置
                M.Config.Mitigation = M.Mitigation.LoadDefault(raidId)
                d("[StringCore] 已加载空白默认配置")
            end
        end
        
        -- 保存副本用于配置保存
        M.Config.MitigationRaid = raidId
        M.Config.MitigationPath = configPath
        M.Config.MitigationFile = configFile
        
        -- 深拷贝用于变更检测
        M.Config.MitigationPrevious = table.deepcopy(M.Config.Mitigation)
    end
    
    -- =============================================
    -- 职业切换处理
    -- =============================================
    M.Mitigation.ChangeJob = function()
        -- 如果在支持的副本中，重新加载配置
        if M.CurrentRaid then
            M.Mitigation.LoadRaidConfig(M.CurrentRaid)
        end
    end
    
    -- =============================================
    -- 保存减伤配置
    -- =============================================
    M.Mitigation.SaveConfig = function()
        if not M.Config.MitigationPath then return end
        M.SaveConfig(M.Config.MitigationPath, M.Config.MitigationFile, "Mitigation")
    end
    
    -- =============================================
    -- 获取当前职业的技能名称
    -- =============================================
    M.Mitigation.GetJobSkills = function()
        if not Player then return { nil, nil } end
        return M.Mitigation.JobMap[Player.job] or { nil, nil }
    end
    
    -- =============================================
    -- 检查配置项是否启用
    -- 用于时间轴 conditionLua 调用
    -- 用法: StringGuide.Mitigation.IsEnabled("P1_AOE1")
    -- =============================================
    M.Mitigation.IsEnabled = function(aoeKey)
        if not M.Config.Mitigation then return false end
        return M.Config.Mitigation[aoeKey] == true
    end
    
    -- =============================================
    -- 设置配置项
    -- =============================================
    M.Mitigation.SetEnabled = function(aoeKey, enabled)
        if not M.Config.Mitigation then
            M.Config.Mitigation = {}
        end
        M.Config.Mitigation[aoeKey] = enabled
    end
    
-- 初始化完成标记
M.MitigationLoaded = true
d("[StringCore] Mitigation.lua 加载完成")
