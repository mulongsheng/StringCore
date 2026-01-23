-- =============================================
-- StringGuide - 核心逻辑模块
-- 包含：配置管理、队伍管理、职业判断、工具方法
-- =============================================

local M = {}

-- =============================================
-- 基础配置
-- =============================================
M.VERSION = "1.0.0"
M.DevelopMode = false  -- 开发模式：热加载 UI 文件

-- UI 状态
M.UI = {
    open = false,
    visible = false
}

-- 减伤 UI 状态
M.MitigationUI = {
    open = false,
    visible = false
}

-- =============================================
-- 副本映射表
-- =============================================
M.RaidMap = {
    [1321] = "M9S",
    [1323] = "M10S",
    [1325] = "M11S",
    [1327] = "M12S"
}

-- 当前副本
M.CurrentRaid = nil

-- =============================================
-- 职业 ID 常量
-- =============================================
M.TankJobs = { 19, 21, 32, 37 }           -- 骑士、战士、黑骑、绝枪
M.HealerJobs = { 24, 28, 33, 40 }         -- 白魔、学者、占星、贤者
M.MeleeJobs = { 20, 22, 30, 34, 39, 41 }  -- 武僧、龙骑、忍者、武士、钐镰、蝰蛇
M.RangeJobs = { 23, 31, 38 }              -- 诗人、机工、舞者
M.MagicJobs = { 25, 27, 35, 42 }          -- 黑魔、召唤、赤魔、绘灵

-- 职业 ID 到名称映射
M.JobIds = { 19, 21, 32, 37, 24, 33, 40, 28, 34, 20, 22, 30, 39, 41, 31, 23, 38, 27, 42, 25, 35 }
M.JobNames = { 
    [19] = "骑士", [21] = "战士", [32] = "黑骑", [37] = "绝枪",
    [24] = "白魔", [28] = "学者", [33] = "占星", [40] = "贤者",
    [20] = "武僧", [22] = "龙骑", [30] = "忍者", [34] = "武士", [39] = "钐镰", [41] = "蝰蛇",
    [23] = "诗人", [31] = "机工", [38] = "舞者",
    [25] = "黑魔", [27] = "召唤", [35] = "赤魔", [42] = "绘灵"
}

-- 职能位置名称
M.JobPosName = { "MT", "ST", "H1", "H2", "D1", "D2", "D3", "D4" }

-- =============================================
-- 队伍管理
-- =============================================
M.Party = {}
M.SelfPos = nil

-- =============================================
-- 配置存储
-- =============================================
M.Config = {}
M.ConfigPath = nil

-- =============================================
-- 职业判断方法
-- =============================================
M.IsTank = function(jobId)
    for _, id in ipairs(M.TankJobs) do
        if id == jobId then return true end
    end
    return false
end

M.IsHealer = function(jobId)
    for _, id in ipairs(M.HealerJobs) do
        if id == jobId then return true end
    end
    return false
end

M.IsMelee = function(jobId)
    for _, id in ipairs(M.MeleeJobs) do
        if id == jobId then return true end
    end
    return false
end

M.IsRange = function(jobId)
    for _, id in ipairs(M.RangeJobs) do
        if id == jobId then return true end
    end
    return false
end

M.IsMagic = function(jobId)
    for _, id in ipairs(M.MagicJobs) do
        if id == jobId then return true end
    end
    return false
end

M.IsDPS = function(jobId)
    return M.IsMelee(jobId) or M.IsRange(jobId) or M.IsMagic(jobId)
end

-- =============================================
-- 工具方法
-- =============================================

-- 获取职业名称
M.GetJobNameById = function(jobId)
    return M.JobNames[jobId] or "未知"
end

-- 数组查找索引
M.IndexOf = function(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then return i end
    end
    return -1
end

-- 检查是否在支持的副本中
M.IsInSupportedRaid = function()
    if not Player then return false end
    return M.RaidMap[Player.localmapid] ~= nil
end

-- 获取当前副本名称
M.GetCurrentRaidName = function()
    if not Player then return "未知" end
    return M.RaidMap[Player.localmapid] or "不支持的副本"
end

-- =============================================
-- 配置管理
-- =============================================

-- 初始化配置
M.InitConfig = function()
    M.ConfigPath = GetLuaModsPath() .. "Configs\\StringCore\\"
    
    -- 确保配置目录存在
    if not FolderExists(M.ConfigPath) then
        FolderCreate(M.ConfigPath)
    end
    
    -- 初始化减伤配置
    M.Config.Mitigation = {}
    M.Config.MitigationPrevious = {}
end

-- 保存配置（带变更检测）
M.SaveConfig = function(path, fileName, configName)
    local curConfig = M.Config[configName]
    local preConfig = M.Config[configName .. "Previous"]
    
    if not curConfig then return end
    
    -- 深度比较检测变化
    if not table.deepcompare(curConfig, preConfig) then
        local saveFile = path .. "\\" .. fileName
        
        -- 确保目录存在
        if not FolderExists(path) then
            FolderCreate(path)
        end
        
        FileSave(saveFile, curConfig)
        M.Config[configName .. "Previous"] = table.deepcopy(curConfig)
        d("[StringCore] 配置已保存: " .. saveFile)
    end
end

-- 加载配置
M.LoadConfig = function(path, fileName)
    local filePath = path .. "\\" .. fileName
    if FileExists(filePath) then
        return FileLoad(filePath)
    end
    return nil
end

-- =============================================
-- 队伍管理
-- =============================================

-- 获取队伍成员列表
M.GetPartyPlayers = function()
    local members = {}
    local party = EntityList("myparty")
    
    if party then
        for _, entity in pairs(party) do
            if entity.job and entity.job > 0 then
                table.insert(members, {
                    id = entity.id,
                    name = entity.name,
                    job = entity.job
                })
            end
        end
    end
    
    -- 添加自己
    if Player and Player.job and Player.job > 0 then
        local selfInParty = false
        for _, m in ipairs(members) do
            if m.id == Player.id then
                selfInParty = true
                break
            end
        end
        if not selfInParty then
            table.insert(members, {
                id = Player.id,
                name = Player.name,
                job = Player.job
            })
        end
    end
    
    return members
end

-- 加载并分配队伍职能
M.LoadParty = function()
    M.Party = {}
    local members = M.GetPartyPlayers()
    
    if #members == 0 then
        d("[StringCore] 未找到队伍成员")
        return
    end
    
    -- 按职业优先级排序
    table.sort(members, function(p1, p2)
        return M.IndexOf(M.JobIds, p1.job) < M.IndexOf(M.JobIds, p2.job)
    end)
    
    -- 自动分配职能
    for _, member in ipairs(members) do
        if M.IsTank(member.job) then
            if M.Party.MT == nil then
                M.Party.MT = member
            elseif M.Party.ST == nil then
                M.Party.ST = member
            end
        elseif M.IsHealer(member.job) then
            if M.Party.H1 == nil then
                M.Party.H1 = member
            elseif M.Party.H2 == nil then
                M.Party.H2 = member
            end
        elseif M.IsMelee(member.job) then
            if M.Party.D1 == nil then
                M.Party.D1 = member
            elseif M.Party.D2 == nil then
                M.Party.D2 = member
            end
        elseif M.IsRange(member.job) or M.IsMagic(member.job) then
            if M.Party.D3 == nil then
                M.Party.D3 = member
            elseif M.Party.D4 == nil then
                M.Party.D4 = member
            end
        end
    end
    
    -- 确定自己的职能
    M.GetSelfPos()
    
    d("[StringCore] 队伍已加载，共 " .. #members .. " 人")
end

-- 获取自己的职能位置
M.GetSelfPos = function()
    if not Player then return end
    
    M.SelfPos = nil
    for _, posName in ipairs(M.JobPosName) do
        local member = M.Party[posName]
        if member and member.id == Player.id then
            M.SelfPos = posName
            break
        end
    end
    
    if M.SelfPos then
        d("[StringCore] 自己的职能: " .. M.SelfPos)
    end
end

-- 获取队伍指定位置的成员
M.GetPartyMember = function(posName)
    return M.Party[posName]
end

-- 获取队伍坦克搭档
M.GetTankPartner = function()
    if not Player then return nil end
    if not M.IsTank(Player.job) then return nil end
    
    if M.SelfPos == "MT" then
        return M.Party.ST
    elseif M.SelfPos == "ST" then
        return M.Party.MT
    end
    return nil
end

return M
