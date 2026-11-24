local publicLandmarks = require("engine/map_dota")
local Talents = require("sdk/dota_base/talents")

local FogFilter = {}
FogFilter.__index = FogFilter

local PIN_CLASSES = {
    power = "dota_item_rune_spawner_powerup",
    bounty = "dota_item_rune_spawner_bounty",
    lotus = "npc_dota_lotus_pool",
    wisdom = "npc_dota_xp_fountain",
    gate = "npc_dota_unit_twin_gate",
}

local OBJECT_KIND = {
    npc_dota_roshan = "roshan",
    npc_dota_miniboss = "tormentor",
    npc_dota_observer_wards = "observer_ward",
    npc_dota_sentry_wards = "sentry_ward",
    npc_dota_lotus_pool = "lotus",
    npc_dota_xp_fountain = "wisdom",
    npc_dota_unit_twin_gate = "gate",
}

local TRACKED_DROPS = {
    item_aegis = true,
    item_cheese = true,
    item_refresher_shard = true,
    item_ultimate_scepter_roshan = true,
    item_roshans_banner = true,
    item_gem = true,
    item_rapier = true,
    item_horn_of_battle_greater = true,
}

local NEUTRAL_CLASSES = { "npc_dota_creature", "npc_dota_miniboss", "npc_dota_roshan" }
local WARD_CLASSES = { "npc_dota_ward_base", "npc_dota_ward_base_truesight" }
local ancientCreeps = {}

local GLOBAL_AUDIBLE_SPELLS = {
    silencer_global_silence = true,
    zuus_thundergods_wrath = true,
    centaur_stampede = true,
    spectre_haunt = true,
    chen_hand_of_god = true,
    night_stalker_darkness = true,
    treant_overgrowth = true,
    invoker_sun_strike = true,
}

local TRACKED_ENEMY_ITEMS = {
    item_black_king_bar = 95,
    item_refresher = 180,
    item_refresher_shard = 180,
    item_sheepstick = 20,
    item_satanic = 35,
    item_guardian_greaves = 40,
    item_pipe = 60,
    item_crimson_guard = 46,
    item_shivas_guard = 27,
    item_manta = 34,
}
local LAST_STASH_SLOT = 14

local function valid(entity)
    return entity ~= nil and not entity:IsNull()
end

local function plainPosition(pos)
    return { x = pos.x, y = pos.y, z = pos.z }
end

local function isDeniable(unit)
    if unit:IsSpeciallyUndeniable() then return false end
    if unit:IsSpeciallyDeniable() then return true end
    if unit:IsBuilding() then return unit:GetHealth() * 10 < unit:GetMaxHealth() end
    local cname = unit:GetClassname()
    return (cname == "npc_dota_creep_lane" or cname == "npc_dota_creep_siege")
        and unit:GetHealth() * 2 < unit:GetMaxHealth()
end

local function classifyUnit(unit, name)
    if OBJECT_KIND[name] then return OBJECT_KIND[name] end
    if unit:IsHero() then
        return unit:IsIllusion() and "illusion" or "hero"
    end
    local cname = unit:GetClassname()
    if cname == "npc_dota_creep_siege" or name:find("_siege$") then return "siege_creep" end
    if cname == "npc_dota_creep_lane" or name:find("^npc_dota_creep_") then return "lane_creep" end
    if cname == "npc_dota_courier" or unit:IsCourier() then return "courier" end
    if unit:IsTower() then return "tower" end
    if cname == "npc_dota_barracks" then return "barracks" end
    if cname == "npc_dota_fort" then return "ancient" end
    if unit:IsBuilding() then return "building" end
    if unit:IsNeutralUnitType() or name:find("^npc_dota_neutral_") then return "neutral" end
    return "unit"
end

local function unitRow(unit, name, kind, isAlly)
    local row = {
        id = unit:entindex(),
        name = name,
        kind = (not isAlly and kind == "illusion") and "hero" or kind,
        team = unit:GetTeamNumber(),
        pos = plainPosition(unit:GetAbsOrigin()),
        alive = unit:IsAlive(),
        hp = unit:GetHealth(),
        maxHp = unit:GetMaxHealth(),
        mana = unit:GetMana(),
        maxMana = unit:GetMaxMana(),
        invulnerable = unit:IsInvulnerable(),
        attackImmune = unit:IsAttackImmune(),
        level = unit:GetLevel(),
    }
    if isAlly then
        row.deniable = isDeniable(unit)
    end
    if kind == "hero" or kind == "illusion" then
        if isAlly then row.isIllusion = unit:IsIllusion() end
        row.teleporting = unit:HasModifier("modifier_teleporting")
        row.moveSpeed = unit:GetIdealSpeed()
        row.forward = plainPosition(unit:GetForwardVector())
        row.moving = unit.IsMoving and unit:IsMoving() or false
        row.manaRegen = unit.GetManaRegen and unit:GetManaRegen() or 0
        row.attackRange = unit:Script_GetAttackRange()
        row.attackDamage = unit:GetAverageTrueAttackDamage(nil)
        row.armor = unit:GetPhysicalArmorValue(false)
        row.ranged = unit:IsRangedAttacker()
        row.projectileSpeed = row.ranged and (unit.GetProjectileSpeed and unit:GetProjectileSpeed() or 900) or 0
        local okPt, basePt = pcall(function() return unit:GetAttackAnimationPoint() end)
        local okBat, bat = pcall(function() return unit:GetBaseAttackTime() end)
        local okSpa, spa = pcall(function() return unit:GetSecondsPerAttack(false) end)
        if not okSpa or type(spa) ~= "number" or spa <= 0 then
            okSpa, spa = pcall(function() return unit:GetSecondsPerAttack() end)
        end
        local bPt = (okPt and type(basePt) == "number" and basePt > 0) and basePt or 0.35
        local bBat = (okBat and type(bat) == "number" and bat > 0) and bat or 1.7
        local bSpa = (okSpa and type(spa) == "number" and spa > 0) and spa or bBat
        row.attackPoint = bPt * (bSpa / bBat)
        row.secondsPerAttack = bSpa
        row.stunned = unit:IsStunned()
        row.silenced = unit:IsSilenced()
        row.rooted = unit:IsRooted()
        row.hexed = unit:IsHexed()
        row.disarmed = unit:IsDisarmed()
        row.magicImmune = unit:IsMagicImmune()
        row.invisible = unit:IsInvisible()
        row.channeling = unit:IsChanneling() or row.teleporting
        row.dusted = unit:HasModifier("modifier_item_dustofappearance")
        row.hasBladeMail = unit:HasModifier("modifier_item_blade_mail_reflect")
        row.hasAegis = unit:HasModifier("modifier_aegis_regen")
        row.hasFlaskRegen = unit:HasModifier("modifier_flask_healing")
        row.hasClarity = unit:HasModifier("modifier_clarity_potion")
        row.hasTangoRegen = unit:HasModifier("modifier_tango_heal")
        row.ethereal = row.attackImmune and not row.invulnerable
    elseif kind == "roshan" or kind == "tormentor" then
        row.armor = unit:GetPhysicalArmorValue(false)
        row.magicImmune = unit:IsMagicImmune()
        row.attackDamage = unit.GetAverageTrueAttackDamage and unit:GetAverageTrueAttackDamage(nil)
            or (kind == "roshan" and 110 or 0)
        local okSpa, spa = pcall(function() return unit:GetSecondsPerAttack(false) end)
        if not okSpa or type(spa) ~= "number" or spa <= 0 then
            okSpa, spa = pcall(function() return unit:GetSecondsPerAttack() end)
        end
        row.secondsPerAttack = (okSpa and type(spa) == "number" and spa > 0) and spa or 1.0
        local aggro = unit.GetAggroTarget and unit:GetAggroTarget()
        if valid(aggro) then
            row.aggroTargetId = aggro:entindex()
        end
    elseif kind == "neutral" then
        if ancientCreeps[name] == nil then
            local kv = GetUnitKeyValuesByName and GetUnitKeyValuesByName(name)
            ancientCreeps[name] = type(kv) == "table" and tonumber(kv.IsAncient) == 1
        end
        row.ancient = ancientCreeps[name]
    elseif kind == "observer_ward" and isAlly and row.alive then
        row.visionRange = unit:GetCurrentVisionRange()
    elseif kind == "tower" or kind == "lane_creep" or kind == "siege_creep" then
        if kind == "tower" then
            local tier, lane = name:match("tower(%d)_(%a+)$")
            tier = tier or name:match("tower(%d)$")
            row.tier, row.lane = tonumber(tier), lane
        end
        row.armor = unit.GetPhysicalArmorValue and unit:GetPhysicalArmorValue(false) or 0
        row.attackDamage = unit.GetAverageTrueAttackDamage and unit:GetAverageTrueAttackDamage(nil)
            or (kind == "tower" and 90 or 21)
        local okSpa, spa = pcall(function() return unit:GetSecondsPerAttack(false) end)
        if not okSpa or type(spa) ~= "number" or spa <= 0 then
            okSpa, spa = pcall(function() return unit:GetSecondsPerAttack() end)
        end
        row.secondsPerAttack = (okSpa and type(spa) == "number" and spa > 0) and spa or 1.0
        local aggro = unit.GetAggroTarget and unit:GetAggroTarget()
        if valid(aggro) then
            row.aggroTargetId = aggro:entindex()
        end
    end
    if kind == "tower" or kind == "barracks" or kind == "ancient" then
        row.backdoorProtected = unit:HasModifier("modifier_backdoor_protection_active")
        row.fortified = unit:HasModifier("modifier_fountain_glyph")
        if kind == "barracks" then row.lane = name:match("_rax_(%a+)$") end
    end
    return row
end

local function inventory(unit, includeDetails)
    local items, cooldown, charges, secondary, toggle = {}, {}, {}, {}, {}
    local slots = {}
    for s = 0, LAST_STASH_SLOT do slots[#slots + 1] = s end
    if DOTA_ITEM_TP_SCROLL then slots[#slots + 1] = DOTA_ITEM_TP_SCROLL end
    local nActive = DOTA_ITEM_NEUTRAL_ACTIVE_SLOT or DOTA_ITEM_NEUTRAL_SLOT
    local nPassive = DOTA_ITEM_NEUTRAL_PASSIVE_SLOT
    if nActive then slots[#slots + 1] = nActive end
    if nPassive and nPassive ~= nActive then slots[#slots + 1] = nPassive end

    for _, slot in ipairs(slots) do
        local item = unit:GetItemInSlot(slot)
        if valid(item) then
            items[slot] = item:GetAbilityName()
            if includeDetails then
                cooldown[slot] = item:GetCooldownTimeRemaining()
                charges[slot] = item:GetCurrentCharges()
                secondary[slot] = item.GetSecondaryCharges and item:GetSecondaryCharges() or 0
                toggle[slot] = item:GetToggleState()
            end
        end
    end
    return items, cooldown, charges, secondary, toggle
end

local function periodic(now, firstAt, interval)
    local cycle = math.floor((now - firstAt) / interval)
    local lastAt = cycle >= 0 and firstAt + cycle * interval or nil
    return { firstAt = firstAt, lastAt = lastAt, nextAt = lastAt and lastAt + interval or firstAt }
end

local function schedule(now, bossKilledAt, bossKills)
    local killed = bossKilledAt or {}
    local water = { firstAt = 120, secondAt = 240 }
    if now < 120 then
        water.nextAt = 120
    elseif now < 240 then
        water.lastAt, water.nextAt = 120, 240
    else
        water.lastAt = 240
    end
    local nextTormentor = killed.tormentor and (killed.tormentor + 600) or 900
    return {
        water = water,
        power = periodic(now, 360, 120),
        bounty = periodic(now, 0, 240),
        lotus = periodic(now, 180, 180),
        wisdom = periodic(now, 420, 420),
        tormentor = {
            firstAt = 900,
            respawn = 600,
            drops = "item_horn_of_battle_greater",
            lastKilledAt = killed.tormentor,
            nextAt = nextTormentor,
            active = now >= nextTormentor,
        },
        roshan = (function()
            local rKills = (bossKills and bossKills.roshan) or 0
            local rMin = math.max(300, 480 - math.max(0, rKills - 1) * 60)
            local rMax = math.max(480, 660 - math.max(0, rKills - 1) * 60)
            return {
                firstAt = 0,
                kills = rKills,
                respawnMin = rMin,
                respawnMax = rMax,
                lastKilledAt = killed.roshan,
                minRespawnAt = killed.roshan and (killed.roshan + rMin) or 0,
                maxRespawnAt = killed.roshan and (killed.roshan + rMax) or 0,
            }
        end)(),
    }
end

local function findUnits(team, relation, flags)
    local types = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
        + DOTA_UNIT_TARGET_BUILDING + DOTA_UNIT_TARGET_OTHER
        + (DOTA_UNIT_TARGET_COURIER or 0)
    return FindUnitsInRadius(team, Vector(0, 0, 0), nil, FIND_UNITS_EVERYWHERE,
        relation, types, flags, FIND_ANY_ORDER, false)
end

local KEY_TIMING_ITEMS = {
    "item_black_king_bar", "item_blink", "item_manta", "item_pipe",
    "item_crimson_guard", "item_guardian_greaves", "item_satanic", "item_sheepstick",
    "item_butterfly", "item_greater_crit", "item_monkey_king_bar", "item_shivas_guard",
    "item_assault", "item_orchid", "item_bloodthorn", "item_skadi",
    "item_heart", "item_hurricane_pike", "item_blade_mail", "item_echo_sabre",
    "item_desolator", "item_ultimate_scepter", "item_sange_and_yasha", "item_kaya_and_sange",
}

local function buildRecipeNode(itemName, depth)
    local cost = GetItemCost(itemName) or 0
    if (depth or 0) > 5 or itemName:find("^item_recipe_") then
        return { name = itemName, cost = cost }
    end
    local recipeName = itemName:gsub("^item_", "item_recipe_")
    local rkv = GetAbilityKeyValuesByName(recipeName)
    if type(rkv) ~= "table" or type(rkv.ItemRequirements) ~= "table" then
        return { name = itemName, cost = cost }
    end
    local reqString = rkv.ItemRequirements["01"]
    if type(reqString) ~= "string" or reqString == "" then
        for _, str in pairs(rkv.ItemRequirements) do
            if type(str) == "string" and str ~= "" then reqString = str; break end
        end
    end
    if not reqString then
        return { name = itemName, cost = cost }
    end
    local reqs = {}
    for comp in reqString:gmatch("[^;]+") do
        reqs[#reqs + 1] = buildRecipeNode(comp:gsub("%*$", ""), (depth or 0) + 1)
    end
    local rCost = tonumber(rkv.ItemCost or 0) or 0
    if rCost > 0 then
        reqs[#reqs + 1] = { name = recipeName, cost = rCost }
    end
    return { name = itemName, cost = cost, reqs = reqs }
end

function FogFilter.new(roster, objectives, neutrals, teleportOrders)
    local self = setmetatable({
        roster = roster,
        objectives = objectives,
        neutrals = neutrals,
        teleportOrders = teleportOrders or {},
        memory = {},
        buildingHp = {},
        runeTypes = {},
        pins = {},
        runeSpawners = {},
        runes = {},
        drops = {},
        neutralUnits = {},
        wards = {},
        bossKilledAt = {},
        bossKills = { roshan = 0, tormentor = 0 },
        enemyCooldowns = {
            [DOTA_TEAM_GOODGUYS] = {},
            [DOTA_TEAM_BADGUYS] = {},
        },
        pinsReads = 0,
    }, FogFilter)
    GameRules:GetGameModeEntity():SetRuneSpawnFilter(function(_, event)
        if event.spawner_entindex_const and event.rune_type then
            self.runeTypes[event.spawner_entindex_const] = event.rune_type
        end
        return true
    end, self)
    self.keyItemRecipes = {}
    for _, name in ipairs(KEY_TIMING_ITEMS) do
        self.keyItemRecipes[name] = buildRecipeNode(name, 0)
    end
    return self
end

function FogFilter:AddTeleports(snapshot, visibleIds)
    local now = GameRules:GetGameTime()
    local orders = self.teleportOrders or {}
    for team, members in pairs(self.roster) do
        for _, member in ipairs(members) do
            local hero = member.hero
            if valid(hero) and hero:IsAlive() then
                local modifier = hero:FindModifierByName("modifier_teleporting")
                if valid(modifier) then
                    local id = hero:entindex()
                    local order = orders[id]
                    local pos = order and now - order.at <= 12 and order.pos
                    if not pos then
                        local ability = modifier:GetAbility()
                        if valid(ability) and ability.GetCursorPosition then
                            pos = ability:GetCursorPosition()
                        end
                    end
                    if pos and (pos.x ~= 0 or pos.y ~= 0)
                        and (team == snapshot.team or IsLocationVisible(snapshot.team, pos)) then
                        snapshot.teleports[#snapshot.teleports + 1] = {
                            team = team, pos = plainPosition(pos),
                            heroId = (team == snapshot.team or visibleIds[id]) and id or nil,
                        }
                    end
                end
            end
        end
    end
end

function FogFilter:OnBossKilled(kind, now)
    if kind == "roshan" or kind == "tormentor" then
        self.bossKilledAt[kind] = now
        self.bossKills[kind] = (self.bossKills[kind] or 0) + 1
    end
end

function FogFilter:CanTeamObserve(observerTeam, unit)
    if not valid(unit) then return false end
    local pos = unit:GetAbsOrigin()
    if IsLocationVisible(observerTeam, pos) then return true end
    for _, member in ipairs(self.roster[observerTeam] or {}) do
        local h = member.hero
        if valid(h) and h:CanEntityBeSeenByMyTeam(unit) then
            return true
        end
    end
    return false
end

function FogFilter:RecordEnemyCooldown(observerTeam, caster, abilityName, cd, isUlt, isItem, now)
    if not cd or cd < 14 then return end
    local teamTrack = self.enemyCooldowns[observerTeam]
    if not teamTrack then
        teamTrack = {}
        self.enemyCooldowns[observerTeam] = teamTrack
    end
    local cid = caster:entindex()
    teamTrack[cid] = teamTrack[cid] or {}
    teamTrack[cid][abilityName] = {
        heroId = cid,
        heroName = caster:GetUnitName(),
        ability = abilityName,
        isUlt = isUlt == true,
        isItem = isItem == true,
        castAt = now,
        cd = cd,
        readyAt = now + cd,
    }
end

function FogFilter:OnAbilityUsed(caster, abilityName)
    local casterTeam = caster:GetTeamNumber()
    if casterTeam ~= DOTA_TEAM_GOODGUYS and casterTeam ~= DOTA_TEAM_BADGUYS then return end
    local observerTeam = (casterTeam == DOTA_TEAM_GOODGUYS) and DOTA_TEAM_BADGUYS or DOTA_TEAM_GOODGUYS
    if not GLOBAL_AUDIBLE_SPELLS[abilityName] and not self:CanTeamObserve(observerTeam, caster) then
        return
    end

    local now = GameRules:GetDOTATime(false, true)
    if abilityName == "item_refresher" or abilityName == "item_refresher_shard" then
        local teamTrack = self.enemyCooldowns[observerTeam]
        if teamTrack then teamTrack[caster:entindex()] = nil end
        self:RecordEnemyCooldown(observerTeam, caster, abilityName, 180, false, true, now)
        return
    end

    local isItem = abilityName:find("^item_") ~= nil
    if isItem then
        local fallbackCd = TRACKED_ENEMY_ITEMS[abilityName]
        if not fallbackCd then return end
        local cd = fallbackCd
        for slot = 0, 5 do
            local it = caster:GetItemInSlot(slot)
            if valid(it) and it:GetAbilityName() == abilityName then
                local rem = it:GetCooldownTimeRemaining()
                local base = it.GetCooldown and it:GetCooldown(0) or 0
                if rem and rem > 1 then cd = rem elseif base and base > 1 then cd = base end
                break
            end
        end
        self:RecordEnemyCooldown(observerTeam, caster, abilityName, cd, false, true, now)
        return
    end

    local ab = caster:FindAbilityByName(abilityName)
    if not valid(ab) then return end
    local lvl = math.max(0, (ab:GetLevel() or 1) - 1)
    local rem = ab:GetCooldownTimeRemaining() or 0
    local base = (ab.GetCooldown and ab:GetCooldown(lvl)) or 0
    local cd = (rem > 1) and rem or base
    local isUlt = (ab.GetAbilityType and ab:GetAbilityType() == (ABILITY_TYPE_ULTIMATE or 1))
        or (ab:GetMaxLevel() == 3)
    -- Запоминаем все ультимейты и важные обычные кнопки с большим КД (>= 24 сек)
    if isUlt or cd >= 24 then
        self:RecordEnemyCooldown(observerTeam, caster, abilityName, cd, isUlt, false, now)
    end
end

function FogFilter:ReadPins()
    local pins, spawners = {}, {}
    local counts = {}
    local function add(kind, marker)
        local pos = marker:GetAbsOrigin()
        local pin = {
            kind = kind,
            side = pos.y > 0 and "top" or "bot",
            pos = pos,
            marker = marker,
        }
        if kind == "wisdom" then
            pin.mapTeam = pos.x < 0 and DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
        elseif kind == "lotus" or kind == "bounty" then
            pin.mapTeam = pos.y < 0 and DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
        end
        pins[#pins + 1] = pin
        counts[kind] = (counts[kind] or 0) + 1
        if kind == "power" or kind == "bounty" then
            spawners[#spawners + 1] = pin
        end
    end

    local function addTormentorWardSpots(marker)
        local center = marker:GetAbsOrigin()
        local inwardX = center.x > 0 and -1 or 1
        local inwardY = center.y > 0 and -1 or 1
        local offsets = { { 860, 0 }, { 0, 860 }, { 760, 530 }, { 900, -420 }, { -420, 900 } }
        for _, offset in ipairs(offsets) do
            local point = GetGroundPosition(Vector(center.x + inwardX * offset[1],
                center.y + inwardY * offset[2], center.z), nil)
            if GridNav:IsTraversable(point) and not GridNav:IsBlocked(point) then
                pins[#pins + 1] = {
                    kind = "ward_spot",
                    objective = "tormentor",
                    side = center.y > 0 and "top" or "bot",
                    pos = point,
                }
            end
        end
    end

    local function addObjectiveWardSpots(marker, objKind, offsets)
        local center = marker:GetAbsOrigin()
        local inwardX = center.x > 0 and -1 or 1
        local inwardY = center.y > 0 and -1 or 1
        local side = center.y > 0 and "top" or "bot"
        local mapTeam = (center.x + center.y < 0) and DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
        for _, offset in ipairs(offsets) do
            local point = GetGroundPosition(Vector(center.x + inwardX * offset[1],
                center.y + inwardY * offset[2], center.z), nil)
            if GridNav:IsTraversable(point) and not GridNav:IsBlocked(point) then
                pins[#pins + 1] = {
                    kind = "ward_spot",
                    objective = objKind,
                    side = side,
                    mapTeam = mapTeam,
                    pos = point,
                }
            end
        end
    end

    for kind, classname in pairs(PIN_CLASSES) do
        for _, marker in ipairs(Entities:FindAllByClassname(classname)) do
            add(kind, marker)
        end
    end
    for _, marker in ipairs(Entities:FindAllByClassname("info_player_start_dota")) do
        local name = marker:GetName()
        if name:match("roshan_location_[12]$") then
            add("roshan", marker)
            addObjectiveWardSpots(marker, "roshan", { { 920, 0 }, { 0, 920 }, { 780, 780 } })
        elseif name:match("miniboss_location_[12]$") then
            add("tormentor", marker)
            addTormentorWardSpots(marker)
        end
    end

    for _, marker in ipairs(Entities:FindAllByClassname("npc_dota_neutral_spawner")) do
        local pos = marker:GetAbsOrigin()
        local closest
        local distance = 700
        for _, landmark in ipairs(publicLandmarks) do
            if landmark.kind == "camp" then
                local d = (landmark.pos - pos):Length2D()
                if d < distance then closest, distance = landmark, d end
            end
        end
        local mapTeam = closest and closest.mapTeam
            or ((pos.x + pos.y < 0) and DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS)
        pins[#pins + 1] = {
            kind = "camp", pos = pos, mapTeam = mapTeam,
            lane = closest and closest.lane, side = pos.y > 0 and "top" or "bot",
        }
        counts.camp = (counts.camp or 0) + 1
    end
    self.hasCampSpawners = (counts.camp or 0) > 0

    table.sort(pins, function(a, b)
        if a.kind == b.kind then return a.side < b.side end
        return a.kind < b.kind
    end)

    self.pins, self.runeSpawners = pins, spawners
    self.pinsReads = self.pinsReads + 1
    if (counts.power or 0) >= 2 and (counts.lotus or 0) >= 2 then
        self.pinsReady = true
        print(string.format("[Tournament] Map pins ready: total=%d (power=%d, bounty=%d, lotus=%d, wisdom=%d, gate=%d)",
            #pins, counts.power or 0, counts.bounty or 0, counts.lotus or 0, counts.wisdom or 0, counts.gate or 0))
    elseif self.pinsReads >= 20 then
        self.pinsReady = true
        print(string.format("[Tournament] Map pins finalized after fallback: total=%d", #pins))
    end
end

function FogFilter:RefreshWorld()
    if not self.pinsReady then self:ReadPins() end
    self.runes = Entities:FindAllByClassname("dota_item_rune")
    self.drops = Entities:FindAllByClassname("dota_item_drop")
    local units, seen = {}, {}
    for _, classname in ipairs(NEUTRAL_CLASSES) do
        for _, unit in ipairs(Entities:FindAllByClassname(classname)) do
            if valid(unit) and not seen[unit:entindex()] then
                seen[unit:entindex()] = true
                units[#units + 1] = unit
            end
        end
    end
    self.neutralUnits = units
    self.wards = {}
    for _, classname in ipairs(WARD_CLASSES) do
        for _, ward in ipairs(Entities:FindAllByClassname(classname)) do
            self.wards[#self.wards + 1] = ward
        end
    end
end

function FogFilter:AddVisibleMapObjects(snapshot)
    local team = snapshot.team
    for _, pin in ipairs(self.pins) do
        local visible = IsLocationVisible(team, pin.pos)
        local row = {
            kind = pin.kind, side = pin.side, mapTeam = pin.mapTeam, objective = pin.objective,
            lane = pin.lane, pos = plainPosition(pin.pos), visible = visible,
        }
        if visible and (pin.kind == "gate" or pin.kind == "lotus" or pin.kind == "wisdom")
            and valid(pin.marker) then
            row.targetId = pin.marker:entindex()
        end
        if visible and (pin.kind == "lotus" or pin.kind == "wisdom")
            and valid(pin.marker) and self.objectives then
            local isActive, charges = self.objectives:GetPinState(pin.marker:entindex(), pin.kind)
            row.active = isActive
            row.charges = charges
        end
        snapshot.pins[#snapshot.pins + 1] = row
    end
    for _, pin in ipairs(publicLandmarks) do
        if pin.kind ~= "camp" or not self.hasCampSpawners then
            snapshot.pins[#snapshot.pins + 1] = {
                kind = pin.kind, mapTeam = pin.mapTeam, lane = pin.lane, tier = pin.tier,
                pos = plainPosition(pin.pos), visible = IsLocationVisible(team, pin.pos),
            }
        end
    end

    for _, rune in ipairs(self.runes) do
        if valid(rune) then
            local pos = rune:GetAbsOrigin()
            if IsLocationVisible(team, pos) then
                local closest, best = nil, 300 * 300
                for _, pin in ipairs(self.runeSpawners) do
                    local dx, dy = pin.pos.x - pos.x, pin.pos.y - pos.y
                    local dist2 = dx * dx + dy * dy
                    if dist2 < best then closest, best = pin, dist2 end
                end
                snapshot.runes[#snapshot.runes + 1] = {
                    id = rune:entindex(), pos = plainPosition(pos),
                    spawnerKind = closest and closest.kind,
                    runeType = closest and self.runeTypes[closest.marker:entindex()],
                }
            end
        end
    end

    for _, drop in ipairs(self.drops) do
        if valid(drop) then
            local pos = drop:GetAbsOrigin()
            if IsLocationVisible(team, pos) then
                local item = drop:GetContainedItem()
                if valid(item) and TRACKED_DROPS[item:GetAbilityName()] then
                    snapshot.drops[#snapshot.drops + 1] = {
                        id = drop:entindex(), pos = plainPosition(pos), name = item:GetAbilityName(),
                    }
                end
            end
        end
    end
end

function FogFilter:BuildTeamState(team)
    assert(team == DOTA_TEAM_GOODGUYS or team == DOTA_TEAM_BADGUYS)
    local opponent = team == DOTA_TEAM_GOODGUYS and DOTA_TEAM_BADGUYS or DOTA_TEAM_GOODGUYS
    local now = GameRules:GetDOTATime(false, true)
    local memory = self.memory[team] or {}
    self.memory[team] = memory
    local hpTrack = self.buildingHp[team] or {}
    self.buildingHp[team] = hpTrack

    local glyphCd = GameRules.GetGlyphCooldown and GameRules:GetGlyphCooldown(team) or 0
    local snapshot = {
        team = team,
        enemyTeam = opponent,
        time = now,
        isDay = GameRules:IsDaytime(),
        glyphCooldown = glyphCd,
        schedule = schedule(now, self.bossKilledAt, self.bossKills),
        heroes = {},
        allies = {},
        enemies = {},
        neutrals = {},
        enemyLastSeen = {},
        enemyCooldowns = {},
        scoreboard = {},
        pins = {},
        runes = {},
        drops = {},
        teleports = {},
        keyItemRecipes = self.keyItemRecipes,
    }

    local viewer
    local visibleIds = {}
    for _, member in ipairs(self.roster[team] or {}) do
        local hero = member.hero
        if valid(hero) and hero:GetTeamNumber() == team then
            if not viewer or (not viewer:IsAlive() and hero:IsAlive()) then
                viewer = hero
            end
            local row = unitRow(hero, hero:GetUnitName(), "hero", true)
            row.muted = hero:IsMuted()
            row.bkbActive = hero:HasModifier("modifier_black_king_bar_immune")
            row.satanicActive = hero:HasModifier("modifier_item_satanic_unholy")
            row.role, row.position, row.lane = member.role, member.position, member.lane
            row.atHomeShop = hero:IsInRangeOfShop(DOTA_SHOP_HOME, true)
            row.playerId = hero:GetPlayerOwnerID()
            row.items, row.itemCooldown, row.itemCharges, row.itemSecondaryCharges, row.itemToggle = inventory(hero, true)
            local tp = hero:GetItemInSlot(DOTA_ITEM_TP_SCROLL or 15)
            row.tpCastable = valid(tp) and tp:GetAbilityName() == "item_tpscroll" and tp:IsFullyCastable()
            if row.position == 1 then
                row.itemCosts = {}
                for slot = 0, 5 do
                    local item = hero:GetItemInSlot(slot)
                    if valid(item) then
                        row.itemCosts[slot] = (item.GetCost and item:GetCost()) or GetItemCost(row.items[slot]) or 0
                    end
                end
            end
            if row.alive and row.hp < row.maxHp and not row.hasTangoRegen then
                for slot = 0, DOTA_ITEM_SLOT_6 or 5 do
                    local itemName = row.items[slot]
                    if (itemName == "item_tango" or itemName == "item_tango_single")
                        and row.itemCharges[slot] > 0 then
                        row.hasTangoTree = GridNav:IsNearbyTree(hero:GetAbsOrigin(), 450, true)
                        break
                    end
                end
            end
            row.gold = PlayerResource:GetGold(row.playerId)
            row.abilityPoints = hero:GetAbilityPoints()
            row.kills = PlayerResource:GetKills(row.playerId) or 0
            row.deaths = PlayerResource:GetDeaths(row.playerId) or 0
            row.assists = PlayerResource:GetAssists(row.playerId) or 0

            local courier = member.courier
            if valid(courier) then
                local carrying = {}
                for cSlot = 0, 8 do
                    local cItem = courier:GetItemInSlot(cSlot)
                    if valid(cItem) then
                        carrying[#carrying + 1] = cItem:GetAbilityName()
                    end
                end
                local hasStash = false
                for sSlot = 9, 14 do
                    if valid(hero:GetItemInSlot(sSlot)) then hasStash = true; break end
                end
                local burstAb = courier:FindAbilityByName("courier_burst")
                local shieldAb = courier:FindAbilityByName("courier_shield")
                local cPos = courier:GetAbsOrigin()
                row.courier = {
                    alive = courier:IsAlive(),
                    pos = plainPosition(cPos),
                    carrying = carrying,
                    hasCargo = #carrying > 0,
                    hasStash = hasStash,
                    atHome = courier:IsInRangeOfShop(DOTA_SHOP_HOME, true),
                    distToHero = (cPos - hero:GetAbsOrigin()):Length2D(),
                    burstReady = valid(burstAb) and burstAb:GetLevel() > 0 and burstAb:IsFullyCastable(),
                    burstCd = valid(burstAb) and burstAb:GetCooldownTimeRemaining() or 999,
                    shieldReady = valid(shieldAb) and shieldAb:GetLevel() > 0 and shieldAb:IsFullyCastable(),
                }
            end
            row.respawnTime = hero:IsAlive() and 0 or (hero:GetTimeUntilRespawn() or 0)
            local okCost, bbCost = pcall(function()
                return hero.GetBuybackCost and hero:GetBuybackCost() or 99999
            end)
            local okCd, bbCd = pcall(function()
                return hero.GetBuybackCooldownTime and hero:GetBuybackCooldownTime() or 999
            end)
            row.buybackCost = (okCost and type(bbCost) == "number") and bbCost or 99999
            row.buybackCooldown = (okCd and type(bbCd) == "number") and bbCd or 999
            row.buybackReady = (not hero:IsAlive()) and row.buybackCooldown <= 0 and row.gold >= row.buybackCost

            local activeAbility = hero:GetCurrentActiveAbility()
            row.casting = valid(activeAbility) and activeAbility:IsInAbilityPhase()
            row.smoked = hero:HasModifier("modifier_smoke_of_deceit")
            if self.neutrals then
                row.neutral = self.neutrals:GetHeroSnapshot(hero, now)
            end
            row.abilities = {}
            for slot = 0, hero:GetAbilityCount() - 1 do
                local ability = hero:GetAbilityByIndex(slot)
                if valid(ability) then
                    row.abilities[slot] = {
                        name = ability:GetAbilityName(),
                        level = ability:GetLevel(),
                        maxLevel = ability:GetMaxLevel(),
                        cooldown = ability:GetCooldownTimeRemaining(),
                        manaCost = ability:GetManaCost(math.max(0, ability:GetLevel() - 1)),
                        castRange = ability:GetCastRange(hero:GetAbsOrigin(), nil),
                        passive = ability:IsPassive(),
                        hidden = ability:IsHidden(),
                        behavior = ability:GetBehaviorInt(),
                        targetTeam = ability.GetAbilityTargetTeam and ability:GetAbilityTargetTeam() or nil,
                        isUltimate = ability.GetAbilityType and (ability:GetAbilityType() == (ABILITY_TYPE_ULTIMATE or 1)) or false,
                        toggle = ability:GetToggleState(),
                        autoCast = ability:GetAutoCastState(),
                        fullyCastable = ability:IsFullyCastable(),
                        canUpgrade = ability:CanAbilityBeUpgraded() == ABILITY_CAN_BE_UPGRADED,
                    }
                end
            end
            local talentLevels = Talents.requiredLevels(row.abilities)
            for _, ability in pairs(row.abilities) do
                if Talents.isTalent(ability.name) then
                    local required = talentLevels[ability.name]
                    ability.talentRequiredLevel = required
                    ability.canUpgrade = (ability.level or 0) == 0
                        and (ability.maxLevel or 1) == 1
                        and required ~= nil and row.level >= required
                end
            end
            visibleIds[row.id] = true
            snapshot.heroes[#snapshot.heroes + 1] = row
        end
    end

    local flags = DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES
    for _, unit in ipairs(findUnits(team, DOTA_UNIT_TARGET_TEAM_FRIENDLY, flags)) do
        if valid(unit) and not visibleIds[unit:entindex()] then
            local name = unit:GetUnitName()
            local kind = classifyUnit(unit, name)
            local row = unitRow(unit, name, kind, true)
            if kind == "tower" or kind == "barracks" or kind == "ancient" then
                local prev = hpTrack[row.id]
                if prev and row.hp < prev.hp then
                    hpTrack[row.id] = { hp = row.hp, hitAt = now }
                elseif not prev then
                    hpTrack[row.id] = { hp = row.hp, hitAt = -999 }
                else
                    prev.hp = row.hp
                end
                row.underAttack = (now - hpTrack[row.id].hitAt) <= 4.0
            end
            snapshot.allies[#snapshot.allies + 1] = row
            visibleIds[row.id] = true
        end
    end

    -- Ward entities can be omitted by FindUnitsInRadius even with TARGET_OTHER.
    for _, ward in ipairs(self.wards) do
        if valid(ward) and ward:IsAlive() and ward:GetTeamNumber() == team and not visibleIds[ward:entindex()] then
            local name = ward:GetUnitName()
            local kind = OBJECT_KIND[name]
            if kind == "observer_ward" or kind == "sentry_ward" then
                local row = unitRow(ward, name, kind, true)
                snapshot.allies[#snapshot.allies + 1] = row
                visibleIds[row.id] = true
            end
        end
    end

    if viewer then
        local enemyFlags = flags + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS
        for _, unit in ipairs(findUnits(team, DOTA_UNIT_TARGET_TEAM_ENEMY, enemyFlags)) do
            if valid(unit) and viewer:CanEntityBeSeenByMyTeam(unit) then
                local name = unit:GetUnitName()
                local kind = classifyUnit(unit, name)
                local row = unitRow(unit, name, kind, false)
                visibleIds[row.id] = true
                if row.team == opponent then
                    snapshot.enemies[#snapshot.enemies + 1] = row
                    if row.kind == "hero" then
                        local items = inventory(unit, false)
                        row.items = items
                        memory[row.id] = {
                            name = row.name, at = now, items = items, pos = row.pos,
                            hp = row.hp, maxHp = row.maxHp,
                            mana = row.mana, maxMana = row.maxMana,
                            level = row.level,
                        }
                        if row.magicImmune then
                            for _, itName in pairs(items) do
                                if itName == "item_black_king_bar" then
                                    local teamTrack = self.enemyCooldowns[team]
                                    local existing = teamTrack and teamTrack[row.id] and teamTrack[row.id]["item_black_king_bar"]
                                    if not existing or now >= existing.readyAt - 10 then
                                        self:RecordEnemyCooldown(team, unit, "item_black_king_bar", 95, false, true, now)
                                    end
                                    break
                                end
                            end
                        end
                    end
                else
                    snapshot.neutrals[#snapshot.neutrals + 1] = row
                end
            end
        end

        for _, unit in ipairs(self.neutralUnits) do
            if valid(unit) and unit:IsAlive() and not visibleIds[unit:entindex()]
                and viewer:CanEntityBeSeenByMyTeam(unit) then
                local name = unit:GetUnitName()
                local kind = classifyUnit(unit, name)
                if kind == "neutral" or kind == "roshan" or kind == "tormentor" then
                    snapshot.neutrals[#snapshot.neutrals + 1] = unitRow(unit, name, kind, false)
                    visibleIds[unit:entindex()] = true
                end
            end
        end

        for _, ward in ipairs(self.wards) do
            if valid(ward) and ward:IsAlive() and ward:GetTeamNumber() == opponent
                and not visibleIds[ward:entindex()] and viewer:CanEntityBeSeenByMyTeam(ward) then
                local name = ward:GetUnitName()
                local kind = OBJECT_KIND[name]
                if kind == "observer_ward" or kind == "sentry_ward" then
                    snapshot.enemies[#snapshot.enemies + 1] = unitRow(ward, name, kind, false)
                    visibleIds[ward:entindex()] = true
                end
            end
        end
    end

    for _, rows in ipairs({ snapshot.allies, snapshot.enemies, snapshot.neutrals }) do
        for _, row in ipairs(rows) do
            if row.aggroTargetId and not visibleIds[row.aggroTargetId] then
                row.aggroTargetId = nil
            end
        end
    end

    for id, record in pairs(memory) do
        if now - record.at > 600 then
            memory[id] = nil
        else
            local items = {}
            for slot, name in pairs(record.items) do items[slot] = name end
            snapshot.enemyLastSeen[id] = {
                name = record.name, at = record.at, items = items,
                pos = plainPosition(record.pos), hp = record.hp,
                maxHp = record.maxHp, mana = record.mana, maxMana = record.maxMana,
                level = record.level,
            }
        end
    end

    -- Выгружаем запомненные КД врагов (очищая истёкшие)
    local tracked = self.enemyCooldowns[team] or {}
    for cid, spells in pairs(tracked) do
        local anyLeft = false
        for abName, rec in pairs(spells) do
            local rem = rec.readyAt - now
            if rem > 0.5 then
                anyLeft = true
                snapshot.enemyCooldowns[#snapshot.enemyCooldowns + 1] = {
                    heroId = rec.heroId,
                    heroName = rec.heroName,
                    ability = rec.ability,
                    isUlt = rec.isUlt,
                    isItem = rec.isItem,
                    castAt = rec.castAt,
                    readyAt = rec.readyAt,
                    remaining = rem,
                }
            else
                spells[abName] = nil
            end
        end
        if not anyLeft then tracked[cid] = nil end
    end

    -- Публичный скорборд (верхняя панель и миникарта: K/D, респауны, уровни, живые вышки)
    local allyKills, enemyKills = 0, 0
    local allyDead, enemyDead = 0, 0
    local enemyMinRespawn = 999
    local allyLvlSum, allyCnt = 0, 0
    local enemyLvlSum, enemyCnt = 0, 0

    for _, member in ipairs(self.roster[team] or {}) do
        local h = member.hero
        if valid(h) then
            allyCnt = allyCnt + 1
            allyLvlSum = allyLvlSum + (h:GetLevel() or 1)
            allyKills = allyKills + (PlayerResource:GetKills(h:GetPlayerOwnerID()) or 0)
            if not h:IsAlive() then allyDead = allyDead + 1 end
        end
    end
    for _, member in ipairs(self.roster[opponent] or {}) do
        local h = member.hero
        if valid(h) then
            enemyCnt = enemyCnt + 1
            enemyLvlSum = enemyLvlSum + (h:GetLevel() or 1)
            enemyKills = enemyKills + (PlayerResource:GetKills(h:GetPlayerOwnerID()) or 0)
            if not h:IsAlive() then
                memory[h:entindex()] = nil
                snapshot.enemyLastSeen[h:entindex()] = nil
                enemyDead = enemyDead + 1
                local r = h:GetTimeUntilRespawn() or 0
                if r > 0 and r < enemyMinRespawn then enemyMinRespawn = r end
            end
        end
    end

    local allyTowersLeft, enemyTowersLeft, enemyTierFours = 0, 0, 0
    local enemyAliveTowers = {}
    for _, t in ipairs(Entities:FindAllByClassname("npc_dota_tower")) do
        if valid(t) and t:IsAlive() then
            local tTeam = t:GetTeamNumber()
            if tTeam == team then
                allyTowersLeft = allyTowersLeft + 1
            elseif tTeam == opponent then
                enemyTowersLeft = enemyTowersLeft + 1
                local tier, lane = t:GetUnitName():match("tower(%d)_(%a+)$")
                if tier and lane then
                    enemyAliveTowers[lane .. tostring(tier)] = true
                elseif t:GetUnitName():match("tower4$") then
                    enemyTierFours = enemyTierFours + 1
                end
            end
        end
    end

    snapshot.scoreboard = {
        allyKills = allyKills,
        enemyKills = enemyKills,
        allyDeadCount = allyDead,
        enemyDeadCount = enemyDead,
        enemyMinRespawn = (enemyMinRespawn < 999) and enemyMinRespawn or 0,
        allyAvgLevel = allyCnt > 0 and (allyLvlSum / allyCnt) or 1,
        enemyAvgLevel = enemyCnt > 0 and (enemyLvlSum / enemyCnt) or 1,
        allyTowersLeft = allyTowersLeft,
        enemyTowersLeft = enemyTowersLeft,
        enemyAliveTowers = enemyAliveTowers,
        enemyTierFours = enemyTierFours,
    }

    self:AddTeleports(snapshot, visibleIds)
    self:AddVisibleMapObjects(snapshot)
    return snapshot
end

return FogFilter
