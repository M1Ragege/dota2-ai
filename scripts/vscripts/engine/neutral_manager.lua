local NeutralManager = {}
NeutralManager.__index = NeutralManager

local ACTIVE_SLOT  = DOTA_ITEM_NEUTRAL_ACTIVE_SLOT or DOTA_ITEM_NEUTRAL_SLOT or 16
local PASSIVE_SLOT = DOTA_ITEM_NEUTRAL_PASSIVE_SLOT or 17

local DEFAULT_START_TIMES = { 300, 900, 1500, 2100, 3600 }
local DEFAULT_COSTS       = { 5, 10, 10, 10, 10 }
local CHOICES_PER_TIER    = 4
local ATTRIBUTE_GROUPS = {
    DOTA_ATTRIBUTE_STRENGTH = "strength",
    DOTA_ATTRIBUTE_AGILITY = "agility",
    DOTA_ATTRIBUTE_INTELLECT = "intelligence",
    DOTA_ATTRIBUTE_ALL = "universal",
}

local function valid(ent)
    return ent ~= nil and not ent:IsNull()
end

local function parseTime(val, fallback)
    if type(val) == "number" then return val end
    if type(val) == "string" then
        local m, s = val:match("^(%d+):(%d+)$")
        if m and s then return tonumber(m) * 60 + tonumber(s) end
        local n = tonumber(val)
        if n then return n end
    end
    return fallback
end

local function parseStat(val, level)
    if type(val) == "number" then return val end
    if type(val) == "string" then
        local last
        for n in val:gmatch("[-+]?%d+%.?%d*") do
            last = tonumber(n)
            level = level - 1
            if level == 0 then break end
        end
        return last
    end
    if type(val) == "table" then
        return parseStat(val.value or val[tostring(level)] or val["1"], level)
    end
    return nil
end

local function readItemMeta(itemName, level)
    local kv = GetAbilityKeyValuesByName(itemName)
    local stats = {}
    local active = false
    local castRange = 0

    if type(kv) == "table" then
        local beh = tostring(kv.AbilityBehavior or "")
        if beh ~= "" and not beh:find("PASSIVE", 1, true) then
            active = true
        end
        castRange = parseStat(kv.AbilityCastRange, level) or 0

        if type(kv.AbilityValues) == "table" then
            for k, v in pairs(kv.AbilityValues) do
                local n = parseStat(v, level)
                if n and n ~= 0 then stats[tostring(k):lower()] = n end
            end
        end
        if type(kv.AbilitySpecial) == "table" then
            for _, block in pairs(kv.AbilitySpecial) do
                if type(block) == "table" then
                    for k, v in pairs(block) do
                        if k ~= "var_type" then
                            local n = parseStat(v, level)
                            if n and n ~= 0 then stats[tostring(k):lower()] = n end
                        end
                    end
                end
            end
        end
    end

    return {
        name = itemName,
        active = active,
        castRange = castRange,
        stats = stats,
    }
end

local function readItems(list, enhancement)
    local items = {}
    for name, value in pairs(list or {}) do
        local level = tonumber(value)
        if type(name) == "string" and name:find("^item_") and type(value) ~= "table"
            and (not level or level > 0) then
            items[#items + 1] = { name = name, level = enhancement and (level or 1) or nil }
        end
    end
    table.sort(items, function(a, b) return a.name < b.name end)
    return items
end

local function sampleKeys(list, count, excludeName)
    local pool = {}
    for _, entry in ipairs(list or {}) do
        if entry.name ~= excludeName then
            pool[#pool + 1] = entry
        end
    end
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local out = {}
    for i = 1, math.min(count, #pool) do
        out[i] = pool[i]
    end
    return out
end

function NeutralManager.new(roster)
    local self = setmetatable({
        roster = roster,
        tiers = {},
        meta = {},
        heroes = {},
        attributes = {},
    }, NeutralManager)
    self:LoadDefinitions()
    return self
end

function NeutralManager:GetMeta(itemName, level)
    level = level or 1
    local key = itemName .. ":" .. level
    if not self.meta[key] then
        self.meta[key] = readItemMeta(itemName, level)
    end
    return self.meta[key]
end

function NeutralManager:EnhancementGroup(hero)
    local name = hero:GetUnitName()
    if self.attributes[name] == nil then
        local kv = GetUnitKeyValuesByName and GetUnitKeyValuesByName(name)
        self.attributes[name] = (type(kv) == "table" and ATTRIBUTE_GROUPS[kv.AttributePrimary]) or false
    end
    return self.attributes[name]
end

function NeutralManager:LoadDefinitions()
    local raw = LoadKeyValues("scripts/npc/neutral_items.txt") or {}
    local root = type(raw.neutral_items) == "table" and raw.neutral_items or raw
    root = root.neutral_tiers or root

    for tier = 1, 5 do
        local data = root[tostring(tier)] or root[tier]
        if type(data) ~= "table" then break end

        local artifacts = readItems(data.items)
        local pools, poolNames = {}, {}
        for name in pairs(data.item_pools or {}) do poolNames[#poolNames + 1] = name end
        table.sort(poolNames)
        for _, name in ipairs(poolNames) do
            local pool = data.item_pools[name]
            local items = readItems(pool.items)
            pools[#pools + 1] = { items = items, count = tonumber(pool.options) or 1 }
            for _, item in ipairs(items) do artifacts[#artifacts + 1] = item end
        end
        local enhancements = readItems(data.enhancements, true)
        local groups = {}
        for name, list in pairs(data.enhancements or {}) do
            if type(list) == "table" then
                groups[name] = readItems(list, true)
            end
        end

        if #artifacts == 0 and #enhancements == 0 and next(groups) == nil then break end
        self.tiers[tier] = {
            startTime = parseTime(data.start_time or data.drop_rates_start_time, DEFAULT_START_TIMES[tier]),
            craftCost = tonumber(data.craft_cost) or DEFAULT_COSTS[tier],
            artifacts = artifacts,
            pools = pools,
            artifactCount = tonumber(data.trinket_options) or CHOICES_PER_TIER,
            enhancements = enhancements,
            enhancementGroups = groups,
            enhancementCount = tonumber(data.enhancement_options) or CHOICES_PER_TIER,
        }
    end

    local summary = {}
    for tier, def in ipairs(self.tiers) do
        local count = #def.enhancements
        for _, list in pairs(def.enhancementGroups) do count = count + #list end
        summary[#summary + 1] = string.format("T%d=%d/%d", tier, #def.artifacts, count)
    end
    print("[Tournament] NeutralManager loaded: " .. (#summary > 0 and table.concat(summary, " ") or "no tiers"))
end

function NeutralManager:HeroState(hero)
    local id = hero:entindex()
    local st = self.heroes[id]
    if not st then
        st = {
            tier = 0,
            madstones = 0,
            artifact = nil,
            enchantment = nil,
            pendingTier = nil,
            pendingOptions = nil,
            lastPassiveAt = 0,
        }
        self.heroes[id] = st
    end
    return st
end

function NeutralManager:UnlockedTier(now)
    local unlocked = 0
    for tier, def in ipairs(self.tiers) do
        if now >= def.startTime then
            unlocked = tier
        end
    end
    return unlocked
end

function NeutralManager:AddMadstones(hero, amount, now)
    if not valid(hero) or amount <= 0 then return end
    local unlocked = self:UnlockedTier(now)
    if unlocked <= 0 then return end
    local st = self:HeroState(hero)
    local nextTier = st.tier + 1
    if nextTier > unlocked then return end
    local cap = self.tiers[nextTier].craftCost
    st.madstones = math.min(cap, st.madstones + amount)
end

-- Вызывается из entity_killed при смерти нейтрального крипа
function NeutralManager:OnNeutralKilled(killer, killedUnit, now)
    if not valid(killedUnit) then return end
    if not killer or killer:IsNull() then return end

    local hero = killer
    if not hero:IsHero() and hero.GetOwner then
        local owner = hero:GetOwner()
        if valid(owner) and owner:IsHero() then hero = owner end
    end
    if valid(hero) and hero:IsHero() and hero:IsIllusion() and hero.GetPlayerOwnerID then
        local realHero = PlayerResource:GetSelectedHeroEntity(hero:GetPlayerOwnerID())
        if valid(realHero) then hero = realHero end
    end
    if not valid(hero) or not hero:IsHero() or hero:IsIllusion() then return end

    local team = hero:GetTeamNumber()
    local unlocked = self:UnlockedTier(now)
    if unlocked <= 0 then return end

    -- 1. Киллер получает +1 безумруд (если ещё не достиг капа текущего тира)
    local kSt = self:HeroState(hero)
    local kNeed = (kSt.tier < unlocked) and (kSt.madstones < self.tiers[kSt.tier + 1].craftCost)
    if kNeed then
        self:AddMadstones(hero, 1, now)
    end

    -- 2. Делимся с союзником, у которого меньше всего прогресса (чтобы саппорты не отставали)
    local bestAlly, bestScore
    for _, member in ipairs(self.roster[team] or {}) do
        local h = member.hero
        if valid(h) and h ~= hero then
            local s = self:HeroState(h)
            if s.tier < unlocked and s.madstones < self.tiers[s.tier + 1].craftCost then
                local sc = s.tier * 100 + s.madstones
                if not bestScore or sc < bestScore then
                    bestAlly, bestScore = h, sc
                end
            end
        end
    end
    if valid(bestAlly) then
        self:AddMadstones(bestAlly, 1, now)
    end
end

function NeutralManager:EnsureOptions(hero, st, targetTier)
    if st.pendingTier == targetTier and st.pendingOptions then
        return st.pendingOptions
    end
    local def = self.tiers[targetTier]
    if not def then return nil end

    local keep = st.artifact and targetTier > 1
    local limit = def.artifactCount - (keep and #def.pools > 0 and 1 or 0)
    local names, artPicks = {}, {}
    local function addPicks(list)
        for _, entry in ipairs(list) do
            if #artPicks >= limit then break end
            if not names[entry.name] then
                names[entry.name] = true
                artPicks[#artPicks + 1] = entry
            end
        end
    end
    for _, pool in ipairs(def.pools) do
        addPicks(sampleKeys(pool.items, pool.count, st.artifact))
    end
    addPicks(sampleKeys(def.artifacts, #def.artifacts, st.artifact))
    local artifacts = {}
    for _, entry in ipairs(artPicks) do
        local m = self:GetMeta(entry.name)
        artifacts[#artifacts + 1] = {
            name = m.name,
            active = m.active,
            castRange = m.castRange,
            stats = m.stats,
            keepCurrent = false,
        }
    end
    -- Как в реальной Dota 2: на T2-T5 можно оставить текущий артефакт и взять новое зачарование
    if keep then
        local m = self:GetMeta(st.artifact)
        artifacts[#artifacts + 1] = {
            name = m.name,
            active = m.active,
            castRange = m.castRange,
            stats = m.stats,
            keepCurrent = true,
        }
    end

    local enhPool, added = {}, {}
    local function addEnhancements(list)
        for _, entry in ipairs(list or {}) do
            if not added[entry.name] then
                added[entry.name] = true
                enhPool[#enhPool + 1] = entry
            end
        end
    end
    addEnhancements(def.enhancements)
    addEnhancements(def.enhancementGroups.global)
    addEnhancements(def.enhancementGroups[self:EnhancementGroup(hero)])
    local enhPicks = sampleKeys(enhPool, def.enhancementCount)
    local enchantments = {}
    for _, entry in ipairs(enhPicks) do
        local m = self:GetMeta(entry.name, entry.level)
        enchantments[#enchantments + 1] = {
            name = m.name,
            level = entry.level or 1,
            stats = m.stats,
        }
    end

    if #artifacts == 0 and #enchantments == 0 then return nil end
    st.pendingTier = targetTier
    st.pendingOptions = {
        tier = targetTier,
        artifacts = artifacts,
        enchantments = enchantments,
    }
    return st.pendingOptions
end

function NeutralManager:Update(dt)
    local now = GameRules:GetDOTATime(false, true)
    local unlocked = self:UnlockedTier(now)
    if unlocked == 0 then return end

    for _, members in pairs(self.roster) do
        for _, member in ipairs(members or {}) do
            local hero = member.hero
            if valid(hero) then
                local st = self:HeroState(hero)
                local nextTier = st.tier + 1
                if nextTier <= unlocked then
                    local def = self.tiers[nextTier]
                    -- Мягкий догон, если тир открыт уже больше 90 сек, а команда мало била лес
                    if now >= def.startTime + 90 and now - (st.lastPassiveAt or 0) >= 30 then
                        st.lastPassiveAt = now
                        self:AddMadstones(hero, 1, now)
                    end
                    if st.madstones >= def.craftCost then
                        self:EnsureOptions(hero, st, nextTier)
                    end
                end
            end
        end
    end
end

local function itemSlot(hero, item)
    for slot = 0, math.max(ACTIVE_SLOT, PASSIVE_SLOT) do
        if hero:GetItemInSlot(slot) == item then return slot end
    end
end

local function equipIntoNeutralSlot(hero, item, slot)
    hero:AddItem(item)
    if hero:GetItemInSlot(slot) == item then return true end
    local found = itemSlot(hero, item)
    if found and not valid(hero:GetItemInSlot(slot)) then
        hero:SwapItems(found, slot)
    end
    return hero:GetItemInSlot(slot) == item
end

local function discardNewItem(hero, item)
    if not valid(item) then return end
    local container = item.GetContainer and item:GetContainer()
    if itemSlot(hero, item) then hero:TakeItem(item) end
    if valid(container) then UTIL_Remove(container) end
    if valid(item) then UTIL_Remove(item) end
end

local function equipChoices(hero, artifact, enchantment)
    local changes = {}
    local function prepare(choice, slot)
        if not choice then return true end
        local old = hero:GetItemInSlot(slot)
        if valid(old) and old:GetAbilityName() == choice.name
            and (not choice.level or old:GetLevel() == choice.level) then
            return true
        end
        local item = CreateItem(choice.name, hero, hero)
        if not valid(item) then return false end
        changes[#changes + 1] = { old = old, new = item, slot = slot }
        if choice.level and item:GetLevel() ~= choice.level then item:SetLevel(choice.level) end
        return not choice.level or item:GetLevel() == choice.level
    end

    local success = prepare(artifact, ACTIVE_SLOT) and prepare(enchantment, PASSIVE_SLOT)
    if success then
        for _, change in ipairs(changes) do
            if valid(change.old) then hero:TakeItem(change.old) end
            if not equipIntoNeutralSlot(hero, change.new, change.slot) then
                success = false
                break
            end
        end
    end
    if success then
        for _, change in ipairs(changes) do
            if valid(change.old) then UTIL_Remove(change.old) end
        end
        return true
    end

    for _, change in ipairs(changes) do discardNewItem(hero, change.new) end
    for _, change in ipairs(changes) do
        if valid(change.old) and hero:GetItemInSlot(change.slot) ~= change.old then
            if not equipIntoNeutralSlot(hero, change.old, change.slot) then
                return false, "failed to restore the previous neutral item"
            end
        end
    end
    return false, "failed to equip neutral choices"
end

function NeutralManager:ChooseForHero(hero, artifactName, enchantmentName)
    if not valid(hero) then return false, "invalid hero" end
    local st = self:HeroState(hero)
    local opts = st.pendingOptions
    if not opts or not st.pendingTier then
        return false, "no neutral tier ready"
    end
    local now = GameRules:GetDOTATime(false, true)
    if now < (st.retryAt or 0) then return false, st.craftError end

    local chosenArt
    if #opts.artifacts > 0 then
        for _, a in ipairs(opts.artifacts) do
            if a.name == artifactName then chosenArt = a; break end
        end
        if not chosenArt then return false, "artifact not in offered options" end
    end

    local chosenEnh
    if #opts.enchantments > 0 then
        for _, e in ipairs(opts.enchantments) do
            if e.name == enchantmentName then chosenEnh = e; break end
        end
        if not chosenEnh then
            -- Если модель выбрала только артефакт, берём первое предложенное зачарование
            chosenEnh = opts.enchantments[1]
        end
    end

    local ok, reason = equipChoices(hero, chosenArt, chosenEnh)
    if not ok then
        st.craftError, st.retryAt = reason, now + 1
        return false, reason
    end
    if chosenArt then st.artifact = chosenArt.name end
    if chosenEnh then st.enchantment = chosenEnh.name end

    st.tier = st.pendingTier
    st.madstones = 0
    st.pendingTier = nil
    st.pendingOptions = nil
    st.craftError, st.retryAt = nil, nil
    return true, "neutral crafted T" .. tostring(st.tier)
end

-- Данные для FogFilter -> snapshot.heroes[i].neutral
function NeutralManager:GetHeroSnapshot(hero, now)
    local st = self:HeroState(hero)
    local unlocked = self:UnlockedTier(now)
    local activeItem = hero:GetItemInSlot(ACTIVE_SLOT)
    local passiveItem = hero:GetItemInSlot(PASSIVE_SLOT)

    local artName = valid(activeItem) and activeItem:GetAbilityName() or st.artifact
    local enhName = valid(passiveItem) and passiveItem:GetAbilityName() or st.enchantment
    local nextTier = self.tiers[st.tier + 1]
    local nextCost = nextTier and nextTier.craftCost or 0

    local info = {
        currentTier = st.tier,
        unlockedTier = unlocked,
        madstones = st.madstones,
        madstonesNeeded = nextCost,
        artifact = artName,
        enchantment = enhName,
        artifactActive = valid(activeItem) and (not activeItem:IsPassive()) or false,
        artifactCd = valid(activeItem) and activeItem:GetCooldownTimeRemaining() or 0,
        artifactBehavior = valid(activeItem) and activeItem:GetBehaviorInt() or 0,
        artifactCastRange = valid(activeItem) and activeItem:GetCastRange(hero:GetAbsOrigin(), nil) or 0,
        artifactTargetTeam = valid(activeItem) and activeItem.GetAbilityTargetTeam and activeItem:GetAbilityTargetTeam() or nil,
        artifactCastable = valid(activeItem) and (not activeItem:IsPassive()) and activeItem:IsFullyCastable() or false,
        readyTier = st.pendingTier,
        options = st.pendingOptions,
        craftError = st.craftError,
    }
    return info
end

return NeutralManager
