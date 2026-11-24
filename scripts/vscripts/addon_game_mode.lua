local FogFilter = require("engine/fog_filter")
local ActionExecutor = require("engine/action_executor")
local SpectatorHUD = require("engine/spectator_hud")
local TeamSandbox = require("engine/team_sandbox")
local Map = require("engine/map_dota")
local MapObjectives = require("engine/map_objectives")
local NeutralManager = require("engine/neutral_manager")

-- ============================================================
-- СПИСОК ВСЕХ ДОСТУПНЫХ КОМАНД (папки внутри scripts/vscripts/teams/)
-- Добавляй сюда новые ИИ-команды по мере появления
-- ============================================================
local AVAILABLE_TEAMS = {
    { folder = "deepseek",        label = "DeepSeek Flash" },
    { folder = "gemini_hydrogen", label = "Gemini Hydrogen" },
    { folder = "gemini_neon",     label = "Gemini Neon" },
    { folder = "opus_5_5",        label = "Opus 5.5"    },
    { folder = "team_radiant",    label = "Sample Radiant" },
    { folder = "team_dire",       label = "Sample Dire"    },
}

local TEAM_ALIASES = {
    ["deepseek_flash_v4_1"] = "deepseek",
    ["deepseek_flash"]      = "deepseek",
}

local DEFAULT_RADIANT = AVAILABLE_TEAMS[1] and AVAILABLE_TEAMS[1].folder or "gemini_neon"
local DEFAULT_DIRE    = AVAILABLE_TEAMS[2] and AVAILABLE_TEAMS[2].folder or DEFAULT_RADIANT

local TICK = 0.15
local HOST_PLAYER_ID = 0
local SPECTATOR_TEAM = DOTA_TEAM_SPECTATOR or 1
local BOT_SCRIPT = "engine/tournament_bot.lua"

local ROLES = {
    "POS_1_CARRY",
    "POS_2_MID",
    "POS_3_OFFLANE",
    "POS_4_SOFT_SUPPORT",
    "POS_5_HARD_SUPPORT",
}

local FALLBACK_POOL = {
    "npc_dota_hero_luna", "npc_dota_hero_juggernaut", "npc_dota_hero_sven",
    "npc_dota_hero_lina", "npc_dota_hero_viper", "npc_dota_hero_dragon_knight",
    "npc_dota_hero_centaur", "npc_dota_hero_tidehunter", "npc_dota_hero_axe",
    "npc_dota_hero_lion", "npc_dota_hero_crystal_maiden", "npc_dota_hero_lich",
    "npc_dota_hero_witch_doctor", "npc_dota_hero_vengefulspirit", "npc_dota_hero_ogre_magi",
}

local BAN_ORDER = { "radiant", "dire", "dire", "radiant" }

local DRAFT_ORDER = {
    { side = "radiant", pos = 5 },
    { side = "dire",    pos = 5 },
    { side = "dire",    pos = 4 },
    { side = "radiant", pos = 4 },
    { side = "radiant", pos = 3 },
    { side = "dire",    pos = 3 },
    { side = "dire",    pos = 1 },
    { side = "radiant", pos = 1 },
    { side = "radiant", pos = 2 },
    { side = "dire",    pos = 2 },
}

local Tournament = {}
Tournament.__index = Tournament

local function copyTable(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, val in pairs(v) do t[k] = copyTable(val) end
    return t
end

local function findTeamMeta(folder)
    folder = TEAM_ALIASES[folder] or folder
    for _, entry in ipairs(AVAILABLE_TEAMS) do
        if entry.folder == folder then
            return entry
        end
    end
    return nil
end

local function loadValidHeroSet()
    local raw = assert(LoadKeyValues("scripts/npc/npc_heroes.txt"), "Не найден npc_heroes.txt")
    local validHeroes = {}
    for name, data in pairs(raw) do
        if type(name) == "string" and name:find("^npc_dota_hero_")
            and name ~= "npc_dota_hero_base" and name ~= "npc_dota_hero_target_dummy"
            and type(data) == "table" and tonumber(data.HeroID or 0) > 0 then
            validHeroes[name] = true
        end
    end
    return validHeroes
end

local function runAlternatingDraft(teamsBySide, tournament)
    local validHeroes = loadValidHeroSet()
    local taken = {}
    local bans = {}
    local picks = { radiant = {}, dire = {} }

    local function availableHeroes()
        local available = {}
        for heroName in pairs(validHeroes) do
            if not taken[heroName] then available[heroName] = true end
        end
        return available
    end

    for _, side in ipairs(BAN_ORDER) do
        local team = teamsBySide[side]
        local enemySide = side == "radiant" and "dire" or "radiant"
        local strategy = team.strategy
        if type(strategy.BanHero) == "function" then
            local ok, res = pcall(strategy.BanHero, strategy, availableHeroes(),
                copyTable(picks[side]), copyTable(picks[enemySide]), copyTable(bans))
            if ok and type(res) == "string" and validHeroes[res] and not taken[res] then
                taken[res] = true
                bans[#bans + 1] = res
                team.bans = team.bans or {}
                team.bans[#team.bans + 1] = res
                print(string.format("[Tournament] Ban: %s -> %s", team.label, res))
            elseif not ok then
                local errMsg = tostring(res)
                print(string.format("[Tournament] %s BanHero error: %s", team.label, errMsg))
                if tournament and tournament.NotifyChat then
                    tournament:NotifyChat("warn", team.label .. " | Draft", "BanHero: " .. errMsg)
                end
                if tournament and tournament.errorCount then
                    tournament.errorCount[team.id] = (tournament.errorCount[team.id] or 0) + 1
                end
            end
        end
    end

    local function pickCandidate(side, pos)
        local team = teamsBySide[side]
        local enemySide = side == "radiant" and "dire" or "radiant"
        local strategy = team.strategy
        local chosen

        if type(strategy.PickHero) == "function" then
            local ok, res = pcall(strategy.PickHero, strategy, pos, ROLES[pos],
                availableHeroes(), copyTable(picks[side]), copyTable(picks[enemySide]), copyTable(bans))
            if ok and type(res) == "string" and validHeroes[res] and not taken[res] then
                chosen = res
            elseif not ok then
                local errMsg = tostring(res)
                print(string.format("[Tournament] %s PickHero error: %s", team.label, errMsg))
                if tournament and tournament.NotifyChat then
                    tournament:NotifyChat("warn", team.label .. " | Draft", "PickHero Pos " .. pos .. ": " .. errMsg)
                end
                if tournament and tournament.errorCount then
                    tournament.errorCount[team.id] = (tournament.errorCount[team.id] or 0) + 1
                end
            end
        end

        if not chosen and type(strategy.draft) == "table" then
            local entry = strategy.draft[pos]
            if type(entry) == "string" and validHeroes[entry] and not taken[entry] then
                chosen = entry
            elseif type(entry) == "table" then
                for _, alt in ipairs(entry) do
                    if type(alt) == "string" and validHeroes[alt] and not taken[alt] then
                        chosen = alt
                        break
                    end
                end
            end
        end

        if not chosen then
            for _, fb in ipairs(FALLBACK_POOL) do
                if validHeroes[fb] and not taken[fb] then
                    chosen = fb
                    print(string.format("[Tournament] WARNING: %s Pos %d duplicate/invalid pick -> fallback %s",
                        team.label, pos, fb))
                    break
                end
            end
        end

        if not chosen then
            for heroName in pairs(validHeroes) do
                if not taken[heroName] then
                    chosen = heroName
                    print(string.format("[Tournament] WARNING: %s Pos %d -> global fallback %s",
                        team.label, pos, heroName))
                    break
                end
            end
        end

        assert(chosen, "Не удалось выбрать героя для " .. team.label .. " Pos " .. pos)
        taken[chosen] = true
        picks[side][pos] = chosen
        print(string.format("[Tournament] Draft: %s Pos %d (%s) -> %s",
            team.label, pos, ROLES[pos], chosen))
    end

    for _, step in ipairs(DRAFT_ORDER) do
        pickCandidate(step.side, step.pos)
    end

    teamsBySide.radiant.picks = picks.radiant
    teamsBySide.dire.picks = picks.dire
end

local function fountainPosition(teamId)
    for _, pin in ipairs(Map) do
        if pin.kind == "fountain" and pin.mapTeam == teamId then return pin.pos end
    end
    error("Missing fountain for team " .. tostring(teamId))
end

function Precache(context)
    -- Герои подгружаются асинхронно после выбора команд на экране старта
    PrecacheUnitByNameSync("npc_dota_courier", context)
end

function Activate()
    local roster = {}
    local objectives = MapObjectives.new()
    local neutrals = NeutralManager.new(roster)
    local executor = ActionExecutor.new(roster, neutrals)
    local game = setmetatable({
        teams = nil,
        roster = roster,
        states = {},
        errors = {},
        errorCount = {},
        tickCount = 0,
        bossKills = { roshan = 0, tormentor = 0 },
        matchupLocked = false,
        readyToLaunch = false,
        objectives = objectives,
        neutrals = neutrals,
        fog = FogFilter.new(roster, objectives, neutrals, executor.teleports),
        executor = executor,
        hud = SpectatorHUD.new(),
    }, Tournament)
    GameRules.Tournament = game
    game:Init()
end

function Tournament:SendSetupStatus(state, message)
    CustomGameEventManager:Send_ServerToAllClients("tournament_setup_status", {
        state = state, -- "idle" | "loading" | "error" | "launching"
        message = tostring(message or ""),
    })
end

function Tournament:BroadcastTeamsList()
    local list = {}
    for i, entry in ipairs(AVAILABLE_TEAMS) do
        list[i] = {
            folder = entry.folder,
            label = entry.label or entry.folder,
        }
    end
    CustomGameEventManager:Send_ServerToAllClients("tournament_teams_list", {
        teams = list,
        defaultRadiant = DEFAULT_RADIANT,
        defaultDire = DEFAULT_DIRE,
    })
end

function Tournament:SelectMatchup(radiantFolder, direFolder)
    if self.matchupLocked then return end
    if type(radiantFolder) ~= "string" or radiantFolder == ""
        or type(direFolder) ~= "string" or direFolder == "" then
        self:SendSetupStatus("error", "Выберите команды для обеих сторон")
        return
    end

    radiantFolder = TEAM_ALIASES[radiantFolder] or radiantFolder
    direFolder = TEAM_ALIASES[direFolder] or direFolder

    self.matchupLocked = true
    self:SendSetupStatus("loading", "Загрузка стратегий: " .. radiantFolder .. " vs " .. direFolder .. "...")

    local okRad, radStrat = pcall(TeamSandbox.Load, radiantFolder)
    if not okRad then
        self.matchupLocked = false
        local msg = "Ошибка загрузки Radiant (" .. radiantFolder .. "): " .. tostring(radStrat)
        print("[Tournament] " .. msg)
        self:SendSetupStatus("error", msg)
        return
    end

    local okDir, dirStrat = pcall(TeamSandbox.Load, direFolder)
    if not okDir then
        self.matchupLocked = false
        local msg = "Ошибка загрузки Dire (" .. direFolder .. "): " .. tostring(dirStrat)
        print("[Tournament] " .. msg)
        self:SendSetupStatus("error", msg)
        return
    end

    local radMeta = findTeamMeta(radiantFolder)
    local dirMeta = findTeamMeta(direFolder)
    local radLabel = (radMeta and radMeta.label) or radStrat.name or radiantFolder
    local dirLabel = (dirMeta and dirMeta.label) or dirStrat.name or direFolder
    if radiantFolder == direFolder then
        radLabel = radLabel .. " (R)"
        dirLabel = dirLabel .. " (D)"
    end

    local teams = {
        {
            side = "radiant",
            id = DOTA_TEAM_GOODGUYS,
            folder = radiantFolder,
            label = radLabel,
            safe = "bot", off = "top",
            strategy = radStrat,
        },
        {
            side = "dire",
            id = DOTA_TEAM_BADGUYS,
            folder = direFolder,
            label = dirLabel,
            safe = "top", off = "bot",
            strategy = dirStrat,
        },
    }

    local bySide = { radiant = teams[1], dire = teams[2] }
    local okDraft, draftErr = pcall(runAlternatingDraft, bySide, self)
    if not okDraft then
        self.matchupLocked = false
        local msg = "Ошибка драфта: " .. tostring(draftErr)
        print("[Tournament] " .. msg)
        self:SendSetupStatus("error", msg)
        return
    end

    -- Собираем уникальный список всех 10 выбранных героев и прекешим их
    local heroesToPrecache, seen = {}, {}
    for _, team in ipairs(teams) do
        for _, heroName in ipairs(team.picks) do
            if not seen[heroName] then
                seen[heroName] = true
                heroesToPrecache[#heroesToPrecache + 1] = heroName
            end
        end
    end

    local total = #heroesToPrecache
    local loaded = 0
    self.teams = teams

    print(string.format("[Tournament] Matchup locked: %s (Radiant) vs %s (Dire). Precaching %d heroes...",
        teams[1].label, teams[2].label, total))
    self:SendSetupStatus("loading", string.format("Подготовка героев: 0/%d...", total))

    for _, heroName in ipairs(heroesToPrecache) do
        PrecacheUnitByNameAsync(heroName, function()
            loaded = loaded + 1
            self:SendSetupStatus("loading", string.format("Подготовка героев: %d/%d...", loaded, total))
            if loaded >= total and not self.readyToLaunch then
                self.readyToLaunch = true
                self:SendSetupStatus("launching",
                    string.format("Запуск: %s vs %s!", teams[1].label, teams[2].label))
                print("[Tournament] All heroes precached -> ready to launch")
            end
        end)
    end
end

function Tournament:Init()
    print("[Tournament] Init " .. GetMapName() .. " | Waiting for team selection...")

    GameRules:EnableCustomGameSetupAutoLaunch(false)
    GameRules:SetCustomGameSetupTimeout(-1)
    GameRules:SetHeroSelectionTime(0)
    GameRules:SetStrategyTime(0)
    GameRules:SetShowcaseTime(0)

    for _, teamId in ipairs({ DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS }) do
        GameRules:SetCustomGameTeamMaxPlayers(teamId, #ROLES)
        self.errors[teamId] = {}
        self.errorCount[teamId] = 0
    end

    local mode = GameRules:GetGameModeEntity()
    mode:SetBotThinkingEnabled(false)

    -- Включаем стандартные правила оригинальной Dota 2
    local defaultFlags = {
        "SetUseDefaultDOTARuneSpawnLogic",
        "SetFreeCourierModeEnabled",
        "SetTowerBackdoorProtectionEnabled",
        "SetGiveFreeTPOnDeath",
        "SetAllowNeutralItemDrops",
        "SetNeutralStashEnabled",
    }
    for _, method in ipairs(defaultFlags) do
        if mode[method] then
            mode[method](mode, true)
        end
    end

    -- Слушатели событий от Panorama UI выбора команд
    CustomGameEventManager:RegisterListener("tournament_ui_ready", function()
        self:BroadcastTeamsList()
    end)

    CustomGameEventManager:RegisterListener("tournament_select_matchup", function(_, data)
        if type(data) == "table" then
            self:SelectMatchup(data.radiant, data.dire)
        end
    end)

    ListenToGameEvent("game_rules_state_change", function()
        local st = GameRules:State_Get()
        if (st == DOTA_GAMERULES_STATE_HERO_SELECTION or st == DOTA_GAMERULES_STATE_PRE_GAME)
            and not self.spawned and self.teams then
            self.spawned = true
            self:SpawnRoster()
        elseif st == DOTA_GAMERULES_STATE_POST_GAME then
            self:PrintMatchSummary()
        end
    end, nil)

    ListenToGameEvent("dota_match_done", function(ev)
        self:PrintMatchSummary(tonumber(ev.winningteam))
    end, nil)

    ListenToGameEvent("entity_killed", function(ev)
        local ent = ev.entindex_killed and EntIndexToHScript(ev.entindex_killed)
        if ent and not ent:IsNull() and ent.GetUnitName then
            local name = ent:GetUnitName()
            local now = GameRules:GetDOTATime(false, true)
            if name == "npc_dota_roshan" then
                if now >= 0 then
                    self.bossKills.roshan = (self.bossKills.roshan or 0) + 1
                    self.fog:OnBossKilled("roshan", now)
                    self:NotifyChat("info", "ROSHAN",
                        string.format("Рошан убит (#%d) на %d мин", self.bossKills.roshan, math.floor(now / 60)),
                        "rosh_" .. math.floor(now))
                end
            elseif name == "npc_dota_miniboss" then
                if now >= 0 then
                    self.bossKills.tormentor = (self.bossKills.tormentor or 0) + 1
                    self.fog:OnBossKilled("tormentor", now)
                    self:NotifyChat("info", "TORMENTOR",
                        string.format("Терзатель убит (#%d) на %d мин", self.bossKills.tormentor, math.floor(now / 60)),
                        "torm_" .. math.floor(now))
                end
            elseif (ent.IsFort and ent:IsFort()) or ent:GetClassname() == "npc_dota_fort" then
                local losingTeam = ent:GetTeamNumber()
                if losingTeam == DOTA_TEAM_GOODGUYS then
                    self:PrintMatchSummary(DOTA_TEAM_BADGUYS)
                elseif losingTeam == DOTA_TEAM_BADGUYS then
                    self:PrintMatchSummary(DOTA_TEAM_GOODGUYS)
                end
            elseif ent:GetTeamNumber() == DOTA_TEAM_NEUTRALS
                and ((ent.IsNeutralUnitType and ent:IsNeutralUnitType()) or name:find("^npc_dota_neutral_")) then
                local attacker = ev.entindex_attacker and EntIndexToHScript(ev.entindex_attacker)
                if self.neutrals then
                    self.neutrals:OnNeutralKilled(attacker, ent, now)
                end
            end
        end
    end, nil)

    ListenToGameEvent("dota_player_used_ability", function(ev)
        local abilityName = ev.abilityname
        if type(abilityName) ~= "string" or abilityName == "" then return end
        local caster = ev.caster_entindex and EntIndexToHScript(ev.caster_entindex)
        if (not caster or caster:IsNull()) and ev.PlayerID and ev.PlayerID >= 0 then
            caster = PlayerResource:GetSelectedHeroEntity(ev.PlayerID)
        end
        if caster and not caster:IsNull() and caster:IsHero() and not caster:IsIllusion() then
            self.fog:OnAbilityUsed(caster, abilityName)
        end
    end, nil)

    Convars:RegisterCommand("tournament_teams", function()
        print("[Tournament] Available teams:")
        for i, entry in ipairs(AVAILABLE_TEAMS) do
            print(string.format("  %d. %s (folder: %s)", i, entry.label or entry.folder, entry.folder))
        end
    end, "Показать список доступных команд", 0)

    Convars:RegisterCommand("tournament_matchup", function(_, rad, dir)
        if not rad or not dir then
            print("[Tournament] Использование: tournament_matchup <radiant_folder> <dire_folder>")
            return
        end
        self:SelectMatchup(rad, dir)
    end, "Выбрать команды и запустить матч: tournament_matchup <rad> <dir>", 0)

    Convars:RegisterCommand("tournament_start", function()
        if not self.matchupLocked then
            self:SelectMatchup(DEFAULT_RADIANT, DEFAULT_DIRE)
            return
        end
        if self.readyToLaunch and not self.setupFinished then
            self.setupFinished = true
            GameRules:LockCustomGameSetupTeamAssignment(true)
            GameRules:FinishCustomGameSetup()
            print("[Tournament] Force started via tournament_start")
        end
    end, "Принудительно запустить матч турнира", 0)

    Convars:RegisterCommand("tournament_speed", function(_, mult)
        local n = math.max(0.25, math.min(8, tonumber(mult) or 1))
        SendToServerConsole("sv_cheats 1")
        SendToServerConsole("host_timescale " .. tostring(n))
        print("[Tournament] Timescale set to x" .. tostring(n))
    end, "Ускорение матча турнира", 0)

    Convars:RegisterCommand("tournament_chat_alerts", function(_, val)
        self.chatAlertsEnabled = (val ~= "0")
        print("[Tournament] Chat alerts: " .. tostring(self.chatAlertsEnabled))
    end, "Вкл/выкл вывод ошибок в чат (1/0)", 0)

    local function printObjectiveState(kind, classname)
        self.objectives:Update()
        for _, entity in ipairs(Entities:FindAllByClassname(classname)) do
            local pos = entity:GetAbsOrigin()
            local active, charges = self.objectives:GetPinState(entity:entindex(), kind)
            print(string.format("[Objective] %s pos=(%.0f,%.0f) active=%s charges=%s",
                kind, pos.x, pos.y, tostring(active), tostring(charges)))
        end
    end

    Convars:RegisterCommand("tournament_check_lotus", function()
        printObjectiveState("lotus", "npc_dota_lotus_pool")
    end, "Проверка прудов лотосов", 0)

    Convars:RegisterCommand("tournament_check_wisdom", function()
        printObjectiveState("wisdom", "npc_dota_xp_fountain")
    end, "Проверка святилищ опыта", 0)

    Convars:RegisterCommand("tournament_check_neutrals", function()
        local now = GameRules:GetDOTATime(false, true)
        print(string.format("[Neutrals] DOTATime=%.0f | UnlockedTier=%d",
            now, self.neutrals and self.neutrals:UnlockedTier(now) or 0))
        for _, team in ipairs(self.teams or {}) do
            for _, member in ipairs(self.roster[team.id] or {}) do
                local h = member.hero
                if h and not h:IsNull() then
                    local info = self.neutrals:GetHeroSnapshot(h, now)
                    local opts = info.options
                    print(string.format("  %s: T%d | mad=%d/%d | ready=%s | options=%d/%d | art=%s | enh=%s%s",
                        member.botName, info.currentTier, info.madstones, info.madstonesNeeded,
                        tostring(info.readyTier), opts and #opts.artifacts or 0, opts and #opts.enchantments or 0,
                        tostring(info.artifact), tostring(info.enchantment),
                        info.craftError and (" | error=" .. info.craftError) or ""))
                end
            end
        end
    end, "Показать статус нейтральных предметов всех ботов", 0)

    Convars:RegisterCommand("tournament_check_bosses", function()
        local dotaTime = GameRules:GetDOTATime(false, true)
        print(string.format("[Bosses] DOTATime=%.1f | GameTime=%.1f | Kills: roshan=%d, tormentor=%d",
            dotaTime, GameRules:GetGameTime(),
            self.bossKills.roshan or 0, self.bossKills.tormentor or 0))
        for _, cname in ipairs({ "npc_dota_roshan", "npc_dota_miniboss" }) do
            for _, ent in ipairs(Entities:FindAllByClassname(cname)) do
                if ent and not ent:IsNull() then
                    local abs, mods = {}, {}
                    for i = 0, ent:GetAbilityCount() - 1 do
                        local ab = ent:GetAbilityByIndex(i)
                        if ab and not ab:IsNull() then
                            abs[#abs + 1] = ab:GetAbilityName() .. "(lvl " .. tostring(ab:GetLevel()) .. ")"
                        end
                    end
                    for _, m in ipairs(ent:FindAllModifiers()) do
                        mods[#mods + 1] = m:GetName() .. "(" .. tostring(m:GetStackCount()) .. ")"
                    end
                    print(string.format("  [%s] alive=%s unitLvl=%d HP=%d/%d Armor=%.1f",
                        cname, tostring(ent:IsAlive()), ent:GetLevel(),
                        ent:GetHealth(), ent:GetMaxHealth(),
                        ent.GetPhysicalArmorValue and ent:GetPhysicalArmorValue(false) or 0))
                    print("    Abilities: " .. table.concat(abs, ", "))
                    print("    Modifiers: " .. table.concat(mods, ", "))
                end
            end
        end
    end, "Показать реальные уровни, способности и стаки Рошана и Терзателя", 0)

    mode:SetContextThink("TournamentThink", function() return self:Think() end, TICK)
end

function Tournament:TryFinishSetup()
    if not self.readyToLaunch then return end

    local player = PlayerResource:GetPlayer(HOST_PLAYER_ID)
    local host = player or GetListenServerHost() or self.host
    if not host or host:IsNull() or self.setupFinished then return end
    self.host = host

    if host:GetTeamNumber() == SPECTATOR_TEAM
        and not PlayerResource:GetSelectedHeroEntity(HOST_PLAYER_ID) then
        self.setupFinished = true
        SendToConsole("dota_spectator_fog_of_war -1")
        GameRules:LockCustomGameSetupTeamAssignment(true)
        print("[Tournament] Spectator ready -> launching match")
        GameRules:FinishCustomGameSetup()
        return
    end

    local now = Time()
    self.spectatorAttempts = self.spectatorAttempts or 0
    if not self.lastSpectatorReq or (now - self.lastSpectatorReq >= 2.0 and self.spectatorAttempts < 3) then
        self.lastSpectatorReq = now
        self.spectatorAttempts = self.spectatorAttempts + 1
        if player then
            PlayerResource:SetCustomTeamAssignment(HOST_PLAYER_ID, SPECTATOR_TEAM)
        end
        SendToConsole("jointeam spectator")
        print(string.format("[Tournament] Requesting spectator slot (attempt %d/3)...", self.spectatorAttempts))
    elseif self.spectatorAttempts >= 3 and now - self.lastSpectatorReq >= 4.0 and not self.setupWarned then
        self.setupWarned = true
        print("[Tournament] Spectator slot did not attach automatically. Type 'tournament_start' in console to start.")
    end
end

function Tournament:SpawnRoster()
    if not self.teams then return end
    local playerIds = {}
    for _, team in ipairs(self.teams) do
        local roster = {}
        self.roster[team.id] = roster
        local fountain = fountainPosition(team.id)
        local defaultLanes = { team.safe, "mid", team.off, team.off, team.safe }
        local customLanes = defaultLanes
        if type(team.strategy.GetLanes) == "function" then
            local enemyTeam = team.side == "radiant" and self.teams[2] or self.teams[1]
            local ok, res = pcall(team.strategy.GetLanes, team.strategy, team.side,
                copyTable(team.picks), copyTable(enemyTeam.picks))
            if ok and type(res) == "table" then
                customLanes = res
            elseif not ok then
                local errMsg = tostring(res)
                print(string.format("[Tournament] %s GetLanes error: %s", team.label, errMsg))
                self:NotifyChat("warn", team.label .. " | Draft", "GetLanes: " .. errMsg)
                self.errorCount[team.id] = (self.errorCount[team.id] or 0) + 1
            end
        elseif type(team.strategy.lanes) == "table" then
            customLanes = team.strategy.lanes
        end

        for position, heroName in ipairs(team.picks) do
            local botName = string.format("%s Pos %d", team.label, position)
            local hero = GameRules:AddBotPlayerWithEntityScript(
                heroName, botName, team.id, BOT_SCRIPT, true)
            assert(hero and not hero:IsNull() and hero:GetUnitName() == heroName
                and hero:GetTeamNumber() == team.id,
                "Could not spawn " .. botName .. " as " .. heroName)
            local playerId = hero:GetPlayerOwnerID()
            assert(playerId >= 0 and PlayerResource:IsFakeClient(playerId) and not playerIds[playerId],
                "Invalid fake client for " .. botName)
            playerIds[playerId] = true
            -- Штатные пруды и святилища учитывают только управляемых игроком героев.
            hero:SetControllableByPlayer(playerId, true)

            local spawn = fountain + Vector((position - 3) * 80, 0, 0)
            FindClearSpaceForUnit(hero, spawn, true)
            hero:SetRespawnPosition(hero:GetAbsOrigin())

            local lane = customLanes[position]
            if lane == "safe" then
                lane = team.safe
            elseif lane == "off" then
                lane = team.off
            elseif lane ~= "top" and lane ~= "mid" and lane ~= "bot" then
                lane = defaultLanes[position]
            end

            roster[position] = {
                hero = hero,
                role = ROLES[position],
                position = position,
                lane = lane,
                botName = botName,
            }
            print(string.format("[Tournament] Spawned %s (%s) on %s, slot %d",
                botName, heroName, lane, playerId))
        end
    end
    self.spawnedAt = Time()
end

function Tournament:EnsureCouriers()
    if not self.teams then return end
    local allReady = true
    for _, team in ipairs(self.teams) do
        local fountain = fountainPosition(team.id)
        for _, member in ipairs(self.roster[team.id] or {}) do
            local hero = member.hero
            if hero and not hero:IsNull() then
                local courier = self.executor:CourierFor(hero, member)
                if not courier or courier:IsNull() then
                    local playerId = hero:GetPlayerOwnerID()
                    local spawnPos = fountain + Vector((member.position - 3) * 70, -140, 0)
                    local player = hero:GetPlayerOwner() or PlayerResource:GetPlayer(playerId)

                    if player and not player:IsNull() and player.SpawnCourierAtPosition then
                        local ok, spawned = pcall(player.SpawnCourierAtPosition, player, spawnPos)
                        if ok and spawned and not spawned:IsNull() then
                            courier = spawned
                        end
                    end

                    if not courier or courier:IsNull() then
                        courier = self.executor:CourierFor(hero, member)
                    end

                    if not courier or courier:IsNull() then
                        courier = CreateUnitByName("npc_dota_courier", spawnPos, true, hero, hero, team.id)
                        if courier and not courier:IsNull() then
                            courier:SetOwner(hero)
                            courier:SetControllableByPlayer(playerId, true)
                            for i = 0, courier:GetAbilityCount() - 1 do
                                local ab = courier:GetAbilityByIndex(i)
                                if ab and not ab:IsNull() and ab:GetLevel() == 0 then
                                    ab:SetLevel(1)
                                end
                            end
                        end
                    end

                    if courier and not courier:IsNull() then
                        member.courier = courier
                        print(string.format("[Tournament] Courier ready for %s", member.botName))
                    else
                        allReady = false
                    end
                else
                    member.courier = courier
                end
            end
        end
    end
    self.couriersReady = allReady
end

local CHAT_COLORS = {
    error = "#ff5555",
    warn  = "#ffcc44",
    info  = "#7be8ff",
}

local function escapeHtml(text)
    return tostring(text or "")
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
end

local function firstLine(text, maxLen)
    local line = tostring(text or ""):match("^[^\r\n]+") or tostring(text or "")
    line = line:gsub("^.-scripts[/\\]vscripts[/\\]", "")
    if #line > (maxLen or 180) then
        line = line:sub(1, (maxLen or 180) - 3) .. "..."
    end
    return line
end

function Tournament:NotifyChat(level, title, message, dedupKey)
    local fullText = string.format("[%s] %s: %s", string.upper(level), tostring(title), tostring(message))
    print("[Tournament]" .. fullText)

    if self.chatAlertsEnabled == false then return end

    self.chatSeen = self.chatSeen or {}
    local key = dedupKey or (level .. ":" .. tostring(title) .. ":" .. firstLine(message, 80))
    local now = Time()
    if self.chatSeen[key] and now - self.chatSeen[key] < 30 then
        return
    end
    self.chatSeen[key] = now

    local color = CHAT_COLORS[level] or "#ffffff"
    local html = string.format(
        "<font color='%s'><b>[%s]</b></font> %s",
        color,
        escapeHtml(title),
        escapeHtml(firstLine(message, 190))
    )
    pcall(GameRules.SendCustomMessage, GameRules, html, 0, 0)
end

function Tournament:LogStrategyError(team, contextLabel, err)
    self.errorCount[team.id] = (self.errorCount[team.id] or 0) + 1
    local key = team.label .. ":" .. contextLabel .. ":" .. firstLine(err, 80)
    self:NotifyChat("error", team.label .. " | " .. contextLabel, err, key)
end

function Tournament:RunStrategy(team, snapshot)
    local strat = team.strategy
    local actions = {}
    if type(strat.DecideTeam) == "function" then
        local ok, result = pcall(strat.DecideTeam, strat, copyTable(snapshot))
        if ok and type(result) == "table" then
            actions = result
        elseif not ok then
            self:LogStrategyError(team, "DecideTeam", result)
        end
    else
        local view = copyTable(snapshot)
        for _, actor in ipairs(snapshot.heroes) do
            local ok, res = pcall(strat.Decide, strat, view, copyTable(actor))
            if ok and type(res) == "table" then
                actions[actor.id] = res
            elseif not ok then
                self:LogStrategyError(team, "Pos " .. actor.position, res)
            end
        end
    end
    return actions
end

function Tournament:ThinkTeams()
    if not self.teams then return end
    if self.objectives then self.objectives:Update() end
    if self.neutrals then self.neutrals:Update(TICK) end
    if not self.couriersReady and self.spawnedAt and Time() - self.spawnedAt >= 1.5 then
        self:EnsureCouriers()
    end

    self.tickCount = self.tickCount + 1
    self.fog:RefreshWorld()

    for _, team in ipairs(self.teams) do
        self.states[team.id] = self.fog:BuildTeamState(team.id)
    end

    local order = (self.tickCount % 2 == 1)
        and { self.teams[1], self.teams[2] }
        or { self.teams[2], self.teams[1] }

    for _, team in ipairs(order) do
        local snapshot = self.states[team.id]
        local actions = self:RunStrategy(team, snapshot)
        if type(actions._hookError) == "string" and actions._hookError ~= "" then
            self:LogStrategyError(team, "Hook", actions._hookError)
        end
        for _, member in ipairs(self.roster[team.id] or {}) do
            local hero = member.hero
            if hero and not hero:IsNull() then
                local action = actions[hero:entindex()]
                if action then
                    self.executor:Execute(team.id, snapshot, member, action)
                end
                self.executor:DeliverFromStash(member)
            end
        end
        self.hud:Update(team.label, snapshot, actions)
    end
end

function Tournament:PrintMatchSummary(winnerTeam)
    if not self.teams or self.summaryPrinted then return end

    if winnerTeam ~= DOTA_TEAM_GOODGUYS and winnerTeam ~= DOTA_TEAM_BADGUYS then
        local fortAlive = {}
        for _, fort in ipairs(Entities:FindAllByClassname("npc_dota_fort")) do
            if fort and not fort:IsNull() and fort:IsAlive() then
                fortAlive[fort:GetTeamNumber()] = true
            end
        end
        local radiantAlive, direAlive = fortAlive[DOTA_TEAM_GOODGUYS], fortAlive[DOTA_TEAM_BADGUYS]
        if radiantAlive == direAlive then return end
        winnerTeam = radiantAlive and DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
    end

    local winner
    for _, team in ipairs(self.teams) do
        if team.id == winnerTeam then
            winner = team.label
            break
        end
    end
    if not winner then return end

    self.summaryPrinted = true
    local duration = GameRules:GetDOTATime(false, true)
    self:NotifyChat("info", "MATCH FINISHED", "Победитель: " .. winner, "match_winner")

    for _, team in ipairs(self.teams) do
        local totalNw, totalKills = 0, 0
        for _, member in ipairs(self.roster[team.id] or {}) do
            local h = member.hero
            if h and not h:IsNull() then
                local pid = h:GetPlayerOwnerID()
                totalKills = totalKills + (PlayerResource:GetKills(pid) or 0)
                totalNw = totalNw + (PlayerResource.GetNetWorth and PlayerResource:GetNetWorth(pid) or 0)
            end
        end
        self:NotifyChat("info", team.label, string.format("Score: %d | NW: %d | Errors: %d",
            totalKills, totalNw, self.errorCount[team.id] or 0), "score_" .. team.side)
    end

    print("============================================================")
    print(string.format("[Tournament] MATCH FINISHED | Winner: %s | Duration: %d:%02d",
        winner, math.floor(duration / 60), math.floor(duration % 60)))
    for _, team in ipairs(self.teams) do
        local totalNw, totalKills, totalDeaths = 0, 0, 0
        for _, member in ipairs(self.roster[team.id] or {}) do
            local h = member.hero
            if h and not h:IsNull() then
                local pid = h:GetPlayerOwnerID()
                totalKills = totalKills + (PlayerResource:GetKills(pid) or 0)
                totalDeaths = totalDeaths + (PlayerResource:GetDeaths(pid) or 0)
                totalNw = totalNw + (PlayerResource.GetNetWorth and PlayerResource:GetNetWorth(pid) or 0)
            end
        end
        local bansList = {}
        for _, b in ipairs(team.bans or {}) do
            bansList[#bansList + 1] = b:gsub("^npc_dota_hero_", "")
        end
        local picksList = {}
        for pos = 1, 5 do
            local p = team.picks and team.picks[pos]
            if p then picksList[#picksList + 1] = string.format("P%d:%s", pos, p:gsub("^npc_dota_hero_", "")) end
        end
        local bansStr = #bansList > 0 and table.concat(bansList, ", ") or "нет"
        local picksStr = #picksList > 0 and table.concat(picksList, ", ") or "нет"

        print(string.format("--- %s (K/D: %d/%d | Total NW: %d | Errors: %d) ---",
            team.label, totalKills, totalDeaths, totalNw, self.errorCount[team.id] or 0))
        print("  Bans: " .. bansStr)
        print("  Picks: " .. picksStr)
        for _, member in ipairs(self.roster[team.id] or {}) do
            local h = member.hero
            if h and not h:IsNull() then
                local pid = h:GetPlayerOwnerID()
                local k = PlayerResource:GetKills(pid) or 0
                local d = PlayerResource:GetDeaths(pid) or 0
                local a = PlayerResource:GetAssists(pid) or 0
                local nw = PlayerResource.GetNetWorth and PlayerResource:GetNetWorth(pid) or 0
                print(string.format("  %s (%s): %d/%d/%d | NW: %d | Lvl %d",
                    member.botName, h:GetUnitName(), k, d, a, nw, h:GetLevel()))
            end
        end
    end
    print("============================================================")
end

function Tournament:Think()
    local ok, result = xpcall(function()
        local state = GameRules:State_Get()
        if state == DOTA_GAMERULES_STATE_POST_GAME then
            self:PrintMatchSummary()
            return nil
        elseif state == DOTA_GAMERULES_STATE_DISCONNECT then
            return nil
        end

        if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
            self:TryFinishSetup()
        elseif state == DOTA_GAMERULES_STATE_HERO_SELECTION
            or state == DOTA_GAMERULES_STATE_PRE_GAME
            or state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
            if not self.spawned and self.teams then
                self.spawned = true
                self:SpawnRoster()
            end
            if state ~= DOTA_GAMERULES_STATE_HERO_SELECTION and not GameRules:IsGamePaused() then
                self:ThinkTeams()
            end
        end
        return TICK
    end, function(err)
        if debug and debug.traceback then
            return debug.traceback(err, 2)
        end
        return tostring(err)
    end)

    if not ok then
        self:NotifyChat("error", "ENGINE CRASH", result, "engine_think_crash")
        return TICK
    end
    return result
end
