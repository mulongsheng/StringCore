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
        -- M9S (mapId: 1321)
        ["M9S"] = {
            { phase = "P1", name = "P1 开场", aoes = {
                { key = "M9S_00_10_魅亡之音", name = "[00:10] 魅亡之音 (AOE 160k)" },
                { key = "M9S_00_30_共振波", name = "[00:30] 共振波 (AOE 110k) 击退/钢铁/月环" },
                { key = "M9S_00_47_粗暴之雨_3连", name = "[00:47] 粗暴之雨 (分摊3连 110k×3)" },
                { key = "M9S_01_00_施虐的尖啸", name = "[01:00] 施虐的尖啸 (AOE 200k) 转场" },
            }},
            { phase = "P2", name = "P2 运动会", aoes = {
                { key = "M9S_02_17_施虐的尖啸", name = "[02:17] 施虐的尖啸 (AOE 200k) 转场" },
                { key = "M9S_02_32_全场杀伤", name = "[02:32] 全场杀伤 (AOE 210k) 运动会" },
                { key = "M9S_02_50_致命的闭幕曲", name = "[02:50] 致命的闭幕曲 (AOE 220k) ★重点" },
            }},
            { phase = "P3", name = "P3 中场", aoes = {
                { key = "M9S_03_50_共振波", name = "[03:50] 共振波 (AOE 120k) 击退/钢铁/月环" },
                { key = "M9S_04_17_粗暴之雨_4连", name = "[04:17] 粗暴之雨 (分摊4连 100k×4)" },
                { key = "M9S_04_31_贪欲无厌", name = "[04:31] 贪欲无厌 (AOE 160k) 转场" },
                { key = "M9S_04_42_施虐的尖啸", name = "[04:42] 施虐的尖啸 (AOE 200k)" },
                { key = "M9S_05_05_魅亡之音", name = "[05:05] 魅亡之音 (AOE 100k)" },
                { key = "M9S_05_23_魅亡之音", name = "[05:23] 魅亡之音 (AOE 180k)" },
            }},
            { phase = "P4", name = "P4 运动会2", aoes = {
                { key = "M9S_05_57_施虐的尖啸", name = "[05:57] 施虐的尖啸 (AOE 160k) 转场" },
                { key = "M9S_06_10_全场杀伤", name = "[06:10] 全场杀伤 (AOE 210k) 运动会" },
                { key = "M9S_06_28_致命的闭幕曲", name = "[06:28] 致命的闭幕曲 (AOE 230k) ★近乎致死" },
            }},
            { phase = "P5", name = "P5 音速", aoes = {
                { key = "M9S_06_49_音速集聚流散_1", name = "[06:49] 音速集聚/流散 (分摊/分散 160k) 第1轮" },
                { key = "M9S_06_54_音速流散集聚_1", name = "[06:54] 音速流散/集聚 (分摊/分散 140k) 第1轮" },
                { key = "M9S_07_11_音速集聚流散_2", name = "[07:11] 音速集聚/流散 (分摊/分散 160k) 第2轮" },
                { key = "M9S_07_18_音速流散集聚_2", name = "[07:18] 音速流散/集聚 (分摊/分散 140k) 第2轮" },
                { key = "M9S_07_32_血蝠死斗", name = "[07:32] 血蝠死斗 (分摊 160k) 塔判定" },
            }},
            { phase = "P6", name = "P6 狂暴前", aoes = {
                { key = "M9S_08_19_粗暴之雨_6连", name = "[08:19] 粗暴之雨 (分摊6连 100k×6) ★高压" },
                { key = "M9S_09_31_贪欲无厌", name = "[09:31] 贪欲无厌 (AOE 160k) 转场" },
                { key = "M9S_09_45_全场杀伤", name = "[09:45] 全场杀伤 (AOE 240k) ★狂暴前最高" },
            }},
        },
        
        -- M10S (mapId: 1323)
        ["M10S"] = {
            { phase = "P1", name = "P1 开场", aoes = {
                { key = "M10S_00_14_炽焰冲击", name = "[00:14] 炽焰冲击 (分摊死刑 400k) 单吃80w" },
                { key = "M10S_01_22_斗志昂扬", name = "[01:22] 斗志昂扬 (AOE 100k)" },
                { key = "M10S_01_57_浪花飞溅", name = "[01:57] 浪花飞溅/浪涛翻涌 (分摊 140k)" },
                { key = "M10S_02_16_深海冲击", name = "[02:16] 深海冲击 (AOE 400k) 击退死刑" },
                { key = "M10S_02_23_斗志昂扬", name = "[02:23] 斗志昂扬 (AOE 100k)" },
            }},
            { phase = "P2", name = "P2 极限炫技", aoes = {
                { key = "M10S_02_48_极限炫技", name = "[02:48] 极限炫技 (AOE 2连) 距离衰减+七段" },
                { key = "M10S_03_17_狂狼腾空_1", name = "[03:17] 狂狼腾空 (死刑 2连 100k) 分散/分摊/T死刑" },
                { key = "M10S_03_39_狂狼腾空_2", name = "[03:39] 狂狼腾空 (分摊 2连 100k)" },
                { key = "M10S_03_49_斗志昂扬_双体", name = "[03:49] 斗志昂扬 (双体AOE 100k×2)" },
            }},
            { phase = "P3", name = "P3 蛇", aoes = {
                { key = "M10S_04_04_蛇夺浪", name = "[04:04] 火蛇/水蛇夺浪 (AOE 200k)" },
                { key = "M10S_04_29_炽焰冲击", name = "[04:29] 炽焰冲击 (分摊死刑 400k) 单吃80w" },
                { key = "M10S_04_39_浪花飞溅_1", name = "[04:39] 浪花飞溅/浪涛翻涌 (分摊 150k) 第1次" },
                { key = "M10S_05_03_浪花飞溅_2", name = "[05:03] 浪花飞溅/浪涛翻涌 (分摊 150k) 第2次" },
                { key = "M10S_05_13_深海冲击", name = "[05:13] 深海冲击 (AOE 420k) 击退死刑" },
                { key = "M10S_05_20_斗志昂扬_双体", name = "[05:20] 斗志昂扬 (双体AOE 100k×2)" },
            }},
            { phase = "P4", name = "P4 水牢", aoes = {
                { key = "M10S_05_48_混合爆破_1", name = "[05:48] 混合爆破 (AOE 120k) 水牢1" },
                { key = "M10S_05_56_混合爆破_2", name = "[05:56] 混合爆破 (AOE 120k) 水牢2" },
                { key = "M10S_06_05_混合爆破_3", name = "[06:05] 混合爆破 (AOE 120k) 水牢3" },
                { key = "M10S_06_14_混合爆破_4", name = "[06:14] 混合爆破 (AOE 120k) 水牢4" },
                { key = "M10S_06_22_混合爆破_5", name = "[06:22] 混合爆破 (AOE 120k) 水牢5" },
                { key = "M10S_06_31_混合爆破_6", name = "[06:31] 混合爆破 (AOE 120k) 水牢6" },
                { key = "M10S_06_39_斗志昂扬", name = "[06:39] 斗志昂扬 (AOE 100k)" },
            }},
            { phase = "P5", name = "P5 火圈", aoes = {
                { key = "M10S_07_17_异常旋绕巨火", name = "[07:17] 异常旋绕巨火 (分摊 130k) 双人火圈" },
                { key = "M10S_07_28_浪涛翻涌", name = "[07:28] 浪涛翻涌 (分摊 150k) 四人分摊" },
                { key = "M10S_07_33_斗志昂扬_双体", name = "[07:33] 斗志昂扬 (双体AOE 100k×2)" },
                { key = "M10S_07_49_极限蛇夺浪", name = "[07:49] 极限火蛇/水蛇夺浪 (AOE 220k)" },
            }},
            { phase = "P6", name = "P6 狂狼2", aoes = {
                { key = "M10S_08_06_狂狼腾空_死刑", name = "[08:06] 狂狼腾空 (死刑 2连 100k) T死刑40w" },
                { key = "M10S_08_37_狂狼腾空_分摊", name = "[08:37] 狂狼腾空 (分摊 2连 100k)" },
                { key = "M10S_08_47_斗志昂扬_双体", name = "[08:47] 斗志昂扬 (双体AOE 100k×2)" },
            }},
            { phase = "P7", name = "P7 狂暴前", aoes = {
                { key = "M10S_09_16_深海冲击", name = "[09:16] 深海冲击 (AOE 400k) 击退死刑" },
                { key = "M10S_09_28_斗志昂扬_4连_1", name = "[09:28] 斗志昂扬 (4连AOE 100k×2) 第1波" },
                { key = "M10S_09_37_斗志昂扬_4连_2", name = "[09:37] 斗志昂扬 (4连AOE 100k×2) 第2波" },
            }},
        },
        
        -- M11S (mapId: 1325)
        ["M11S"] = {
            { phase = "P1", name = "P1 开场", aoes = {
                { key = "M11S_00_10_天顶的主宰", name = "[00:10] 天顶的主宰 (AOE 220k)" },
                { key = "M11S_00_23_铸兵轰击_死刑", name = "[00:23] 铸兵轰击·猛攻/轰击 (死刑 460k)" },
                { key = "M11S_00_24_重斩击", name = "[00:24] 重斩击/冲击 (分摊 160k)" },
                { key = "M11S_00_49_重斩波_3连_1", name = "[00:49] 重斩波/斩波/重打击 (3连 160k) 第1下" },
                { key = "M11S_00_54_重斩波_3连_2", name = "[00:54] 重斩波/斩波/重打击 (3连 160k) 第2下" },
                { key = "M11S_00_59_重斩波_3连_3", name = "[00:59] 重斩波/斩波/重打击 (3连 160k) 第3下" },
            }},
            { phase = "P2", name = "P2 彗星", aoes = {
                { key = "M11S_01_29_彗星", name = "[01:29] 彗星/重彗星 (分摊 120k)" },
                { key = "M11S_01_34_重斩波_3连_1", name = "[01:34] 重斩波/斩波/重打击 (3连 160k) 第1下" },
                { key = "M11S_01_39_重斩波_3连_2", name = "[01:39] 重斩波/斩波/重打击 (3连 160k) 第2下" },
                { key = "M11S_01_45_重斩波_3连_3", name = "[01:45] 重斩波/斩波/重打击 (3连 160k) 第3下" },
                { key = "M11S_01_56_彗星", name = "[01:56] 彗星/重彗星 (分摊 120k)" },
                { key = "M11S_02_02_天顶的主宰", name = "[02:02] 天顶的主宰 (AOE 220k)" },
            }},
            { phase = "P3", name = "P3 统治", aoes = {
                { key = "M11S_02_21_统治的战舞_7连", name = "[02:21] 统治的战舞 (7连AOE 100k×6+140k)" },
                { key = "M11S_02_30_霸王飓风", name = "[02:30] 霸王飓风 (分摊 160k) 双人分摊" },
                { key = "M11S_02_44_铸兵轰击_死刑", name = "[02:44] 铸兵轰击·猛攻/轰击 (死刑 460k)" },
                { key = "M11S_02_44_重斩击", name = "[02:44] 重斩击/冲击 (分摊 160k)" },
            }},
            { phase = "P4", name = "P4 六连斩", aoes = {
                { key = "M11S_03_15_重斩波_6连_1", name = "[03:15] 重斩波 (6连 160k) 第1下" },
                { key = "M11S_03_20_重斩波_6连_2", name = "[03:20] 重斩波 (6连 160k) 第2下" },
                { key = "M11S_03_25_重斩波_6连_3", name = "[03:25] 重斩波 (6连 160k) 第3下" },
                { key = "M11S_03_30_重斩波_6连_4", name = "[03:30] 重斩波 (6连 160k) 第4下" },
                { key = "M11S_03_35_重斩波_6连_5", name = "[03:35] 重斩波 (6连 160k) 第5下" },
                { key = "M11S_03_40_重斩波_6连_6", name = "[03:40] 重斩波 (6连 160k) 第6下" },
                { key = "M11S_04_01_举世无双的霸王", name = "[04:01] 举世无双的霸王 (AOE 240k)" },
            }},
            { phase = "P5", name = "P5 星轨链", aoes = {
                { key = "M11S_04_27_星轨链", name = "[04:27] 星轨链 (直线AOE 150k×4)" },
                { key = "M11S_05_01_大火_4连_1", name = "[05:01] 大火 (分摊 180k) 6人分摊" },
                { key = "M11S_05_11_大火_4连_2", name = "[05:11] 大火 (分摊 200k) 4人分摊" },
                { key = "M11S_05_21_大火_4连_3", name = "[05:21] 大火 (分摊 200k) 4人分摊" },
                { key = "M11S_05_31_大火_4连_4", name = "[05:31] 大火 (分摊 200k) 4人分摊" },
                { key = "M11S_06_03_绝命分断击", name = "[06:03] 绝命分断击 (AOE 240k) 击退" },
            }},
            { phase = "P6", name = "P6 陨石", aoes = {
                { key = "M11S_07_28_重陨石", name = "[07:28] 重陨石 (AOE 120k) 五连" },
                { key = "M11S_08_01_天顶的主宰", name = "[08:01] 天顶的主宰 (AOE 220k)" },
                { key = "M11S_08_26_星轨链", name = "[08:26] 星轨链 (直线AOE)" },
                { key = "M11S_08_44_天顶的主宰", name = "[08:44] 天顶的主宰 (AOE 220k)" },
            }},
            { phase = "P7", name = "P7 狂暴前", aoes = {
                { key = "M11S_09_04_遮天陨石", name = "[09:04] 遮天陨石 (AOE 80k) 距离衰减" },
                { key = "M11S_09_20_重轰击", name = "[09:20] 重轰击 (分摊 100k) 分摊塔" },
                { key = "M11S_09_33_回旋火", name = "[09:33] 二向/四向回旋火 (分摊 300k) 2/4人分摊" },
                { key = "M11S_09_42_天顶的主宰", name = "[09:42] 天顶的主宰 (AOE 220k)" },
                { key = "M11S_09_56_碎心踢_1", name = "[09:56] 碎心踢 (分摊 500k) 软狂暴5次" },
                { key = "M11S_10_15_碎心踢_2", name = "[10:15] 碎心踢 (分摊 500k) 软狂暴6次" },
                { key = "M11S_10_36_碎心踢_3", name = "[10:36] 碎心踢 (分摊 500k) 软狂暴7次" },
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
