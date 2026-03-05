-- =============================================
-- StringGuide - 核心逻辑模块
-- 包含：配置管理、队伍管理、职业判断、工具方法
-- =============================================

StringGuide = {}
local M = StringGuide  -- 本地别名，方便引用

-- =============================================
-- 基础配置
-- =============================================
M.VERSION = "1.2.8"
M.DevelopMode = false  -- 开发模式：热加载 UI 文件
M.IgnoreMapCheck = false  -- 开发者选项：无视地图ID检查

-- UI 状态
M.UI = {
    open = false,
    visible = false
}

-- 队伍悬浮窗 UI 状态
M.PartyOverlay = {
    open = true,
    visible = false
}

-- Map Effect 查看器 UI 状态
M.MapEffectUI = {
    open = false,
    visible = false
}

-- Argus 代码生成器 UI 状态
M.ArgusBuilderUI = {
    open = false,
    visible = false
}

-- 队伍列表（8人：MT,ST,H1,H2,D1,D2,D3,D4 | 4人：T,H,D1,D2）
M.PartyList = {}

-- 拖动状态
M.DragState = {
    pos = 0,       -- 当前拖动的位置
    selected = 0   -- 当前选中的位置
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
M.TankJobs = { 19, 21, 32, 37, 1, 3 }              -- 骑士、战士、黑骑、绝枪 + 剑术师、斧术师
M.HealerJobs = { 24, 28, 33, 40, 6 }               -- 白魔、学者、占星、贤者 + 幻术师
M.MeleeJobs = { 20, 22, 30, 34, 39, 41, 2, 4, 29 } -- 武僧、龙骑、忍者、武士、钐镰、蝰蛇 + 格斗家、枪术师、双剑师
M.RangeJobs = { 23, 31, 38, 5 }                     -- 诗人、机工、舞者 + 弓箭手
M.MagicJobs = { 25, 27, 35, 42, 7, 26, 36 }         -- 黑魔、召唤、赤魔、绘灵 + 咒术师、秘术师、青魔

-- 职业 ID 到名称映射 (XIVAPI ClassJob 完整表)
M.JobIds = { 19, 21, 32, 37, 24, 33, 40, 28, 34, 20, 22, 30, 39, 41, 31, 23, 38, 27, 42, 25, 35, 36, 1, 2, 3, 4, 5, 6, 7, 26, 29 }
M.JobNames = {
    -- 战斗职业
    [19] = "骑士", [21] = "战士", [32] = "黑骑", [37] = "绝枪",
    [24] = "白魔", [28] = "学者", [33] = "占星", [40] = "贤者",
    [20] = "武僧", [22] = "龙骑", [30] = "忍者", [34] = "武士", [39] = "钐镰", [41] = "蝰蛇",
    [23] = "诗人", [31] = "机工", [38] = "舞者",
    [25] = "黑魔", [27] = "召唤", [35] = "赤魔", [42] = "绘灵",
    [36] = "青魔",
    -- 基础职业
    [1] = "剑术师", [2] = "格斗家", [3] = "斧术师", [4] = "枪术师",
    [5] = "弓箭手", [6] = "幻术师", [7] = "咒术师",
    [26] = "秘术师", [29] = "双剑师",
}

-- 职能位置名称
M.JobPosName4 = { "T", "H", "D1", "D2" }
M.JobPosName8 = { "MT", "ST", "H1", "H2", "D1", "D2", "D3", "D4" }
M.JobPosName = M.JobPosName8  -- 默认 8 人，LoadParty 时动态切换

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
-- 实测结论 (2026-03-05):
--   TensorCore.isTank/isHealer: 仅接受 entity 对象，返回 true 或 nil
--   TensorCore.isMelee/isRanged/isCaster: 语义为「战斗方式」而非「职能」
--     (例: isMelee 对坦克也返回 true)，不可用于 DPS 子类分类
--   传入 number (entityId/jobId) 不报错但始终返回 false，不可用

-- 从参数中提取 jobId (支持 entity 对象和 number)
local function ResolveJobId(jobOrEntity)
    if type(jobOrEntity) == "number" then
        return jobOrEntity
    end
    if jobOrEntity and jobOrEntity.job then
        return jobOrEntity.job
    end
    return nil
end

-- 通过 jobId 列表匹配
local function MatchJobList(jobId, jobIdList)
    if not jobId then return false end
    for _, id in ipairs(jobIdList) do
        if id == jobId then return true end
    end
    return false
end

-- IsTank / IsHealer: 可安全使用 TensorCore API (entity 对象时)
-- 回退: jobId 列表匹配
M.IsTank = function(jobOrEntity)
    if type(jobOrEntity) ~= "number" and TensorCore and TensorCore.isTank then
        local ok, result = pcall(TensorCore.isTank, jobOrEntity)
        if ok and result == true then return true end
        if ok and result == nil then return false end
    end
    return MatchJobList(ResolveJobId(jobOrEntity), M.TankJobs)
end

M.IsHealer = function(jobOrEntity)
    if type(jobOrEntity) ~= "number" and TensorCore and TensorCore.isHealer then
        local ok, result = pcall(TensorCore.isHealer, jobOrEntity)
        if ok and result == true then return true end
        if ok and result == nil then return false end
    end
    return MatchJobList(ResolveJobId(jobOrEntity), M.HealerJobs)
end

-- IsMelee / IsRange / IsMagic: 仅用 jobId 列表
-- (TensorCore.isMelee 包含坦克，isRanged/isCaster 可能包含治疗，语义不匹配)
M.IsMelee = function(jobOrEntity)
    return MatchJobList(ResolveJobId(jobOrEntity), M.MeleeJobs)
end

M.IsRange = function(jobOrEntity)
    return MatchJobList(ResolveJobId(jobOrEntity), M.RangeJobs)
end

M.IsMagic = function(jobOrEntity)
    return MatchJobList(ResolveJobId(jobOrEntity), M.MagicJobs)
end

M.IsDPS = function(jobOrEntity)
    return M.IsMelee(jobOrEntity) or M.IsRange(jobOrEntity) or M.IsMagic(jobOrEntity)
end

M.IsFriendly = function(entity)
    if TensorCore and TensorCore.isFriendly then
        local ok, result = pcall(TensorCore.isFriendly, entity)
        if ok then return result == true end
    end
    return false
end

-- =============================================
-- 工具方法
-- =============================================

-- 获取职业名称
M.GetJobName = function(jobId)
    return M.JobNames[jobId] or ("未知(" .. tostring(jobId) .. ")")
end

-- 别名
M.GetJobNameById = M.GetJobName

-- 数组查找索引
M.IndexOf = function(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then return i end
    end
    return -1
end

-- 检查是否在支持的副本中
M.IsInSupportedRaid = function()
    if M.IgnoreMapCheck then return true end
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
    local addedIds = {}  -- 记录已添加的 ID，防止重复
    
    -- 使用 TensorCore API 获取队友
    if TensorCore and TensorCore.getEntityGroupList then
        for k, v in pairs(TensorCore.getEntityGroupList("Party")) do
            if not addedIds[v.id] then
                table.insert(members, {
                    id = v.id,
                    name = v.name,
                    job = v.job
                })
                addedIds[v.id] = true
            end
        end
    end
    
    -- 添加玩家自己（如果还没添加）
    if Player and not addedIds[Player.id] then
        table.insert(members, {
            id = Player.id,
            name = Player.name,
            job = Player.job
        })
    end
    
    d("[StringCore] 获取到 " .. #members .. " 名队伍成员")
    return members
end

-- 加载并分配队伍职能
M.LoadParty = function()
    M.Party = {}
    M.PartyList = {}
    local members = M.GetPartyPlayers()
    
    if #members == 0 then
        d("[StringCore] 未找到队伍成员")
        return
    end
    
    -- 按职业优先级排序
    table.sort(members, function(p1, p2)
        return M.IndexOf(M.JobIds, p1.job) < M.IndexOf(M.JobIds, p2.job)
    end)
    
    -- 4人小队处理（T, H, D1, D2）
    if #members <= 4 then
        M.JobPosName = M.JobPosName4
        for i = 1, #members do
            local member = members[i]
            if M.IsTank(member.job) then
                if M.Party.T == nil then
                    M.Party.T = member
                end
            elseif M.IsHealer(member.job) then
                if M.Party.H == nil then
                    M.Party.H = member
                end
            else
                if M.Party.D1 == nil then
                    M.Party.D1 = member
                elseif M.Party.D2 == nil then
                    M.Party.D2 = member
                end
            end
        end
        -- 同步 PartyList
        M.PartyList = {}
        for i, posName in ipairs(M.JobPosName) do
            M.PartyList[i] = M.Party[posName] or { id = 0, name = "空位", job = 0 }
        end
        M.GetSelfPos()
        -- 打印队伍信息
        local count = 0
        for i, member in ipairs(M.PartyList) do
            if member and member.id ~= 0 then
                count = count + 1
                d("[StringCore] " .. M.JobPosName[i] .. ": " .. tostring(member.name) .. " (" .. M.GetJobName(member.job) .. ")")
            end
        end
        d("[StringCore] 4人队伍已加载，共 " .. count .. " 人，自己位置: " .. tostring(M.SelfPos))
        return
    end
    
    -- 8人副本
    M.JobPosName = M.JobPosName8
    local memberHasSet = {}
    
    -- 第一轮：按职业类型分配标准职能
    for i = 1, #members do
        local member = members[i]
        if M.IsTank(member.job) then
            if M.Party.MT == nil then
                M.Party.MT = member
                table.insert(memberHasSet, member.id)
            elseif M.Party.ST == nil then
                M.Party.ST = member
                table.insert(memberHasSet, member.id)
            end
        elseif M.IsHealer(member.job) then
            if M.Party.H1 == nil then
                M.Party.H1 = member
                table.insert(memberHasSet, member.id)
            elseif M.Party.H2 == nil then
                M.Party.H2 = member
                table.insert(memberHasSet, member.id)
            end
        elseif M.IsMelee(member.job) then
            if M.Party.D1 == nil then
                M.Party.D1 = member
                table.insert(memberHasSet, member.id)
            elseif M.Party.D2 == nil then
                M.Party.D2 = member
                table.insert(memberHasSet, member.id)
            end
        elseif M.IsRange(member.job) then
            if M.Party.D3 == nil then
                M.Party.D3 = member
                table.insert(memberHasSet, member.id)
            end
        elseif M.IsMagic(member.job) then
            if M.Party.D4 == nil then
                M.Party.D4 = member
                table.insert(memberHasSet, member.id)
            end
        end
    end
    
    -- 第二轮：填充未分配的空位
    for i = 1, #members do
        local member = members[i]
        if not table.contains(memberHasSet, member.id) then
            if M.Party.MT == nil then
                M.Party.MT = member
            elseif M.Party.ST == nil then
                M.Party.ST = member
            elseif M.Party.H1 == nil then
                M.Party.H1 = member
            elseif M.Party.H2 == nil then
                M.Party.H2 = member
            elseif M.Party.D1 == nil then
                M.Party.D1 = member
            elseif M.Party.D2 == nil then
                M.Party.D2 = member
            elseif M.Party.D3 == nil then
                M.Party.D3 = member
            elseif M.Party.D4 == nil then
                M.Party.D4 = member
            end
        end
    end
    
    -- 确定自己的职能
    M.GetSelfPos()
    
    -- 同步到 PartyList 数组（按顺序：MT, ST, H1, H2, D1, D2, D3, D4）
    M.PartyList = {}
    for i, posName in ipairs(M.JobPosName) do
        M.PartyList[i] = M.Party[posName] or { id = 0, name = "空位", job = 0 }
    end
    
    -- 打印队伍信息
    local count = 0
    for i, member in ipairs(M.PartyList) do
        if member and member.id ~= 0 then
            count = count + 1
            d("[StringCore] " .. M.JobPosName[i] .. ": " .. tostring(member.name) .. " (" .. M.GetJobName(member.job) .. ", ID:" .. tostring(member.job) .. ")")
        end
    end
    d("[StringCore] 队伍已加载，共 " .. count .. " 人，自己位置: " .. tostring(M.SelfPos))
end

-- 从 PartyList 同步到 Party
M.SyncPartyFromList = function()
    M.Party = {}
    for i, member in ipairs(M.PartyList) do
        if member and member.id ~= 0 then
            M.Party[M.JobPosName[i]] = member
        end
    end
    M.GetSelfPos()
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
    
    -- 四人小队只有一个坦克，无搭档
    if M.SelfPos == "T" then return nil end
    
    if M.SelfPos == "MT" then
        return M.Party.ST
    elseif M.SelfPos == "ST" then
        return M.Party.MT
    end
    return nil
end

-- 模块加载完成
d("[StringCore] StringGuide.lua 加载完成")
