local Talents = require("sdk/dota_base/talents")

local ActionExecutor = {}
ActionExecutor.__index = ActionExecutor

local UNIT_LISTS = { "heroes", "allies", "enemies", "neutrals" }
local WARDS = {
    npc_dota_observer_wards = true,
    npc_dota_sentry_wards = true,
}
local PIN_TYPES = { lotus = "lotus", shrine = "wisdom", gate = "gate" }
local OBJECT_RADIUS = { lotus = 350, shrine = 300 }
local OBJECT_INTERACT = "npc_dota_unit_twin_gate"
local STASH_FIRST, STASH_LAST = 9, 14
local TELEPORT_ITEMS = { item_tpscroll = true, item_travel_boots = true, item_travel_boots_2 = true }
local ICE_RELEASE = "ancient_apparition_ice_blast_release"

local INSTANT_KINDS = {
    buy = true, learn = true, swap = true, sell = true,
    buyback = true, glyph = true, autocast = true,
    courier_burst = true, courier_shield = true,
    choose_neutral = true,
}

local function valid(entity)
    return entity and not entity:IsNull()
end

local function number(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function position(value)
    if type(value) ~= "table" or not number(value.x) or not number(value.y)
        or (value.z ~= nil and not number(value.z)) then
        return nil
    end
    if value.x < GetWorldMinX() or value.x > GetWorldMaxX()
        or value.y < GetWorldMinY() or value.y > GetWorldMaxY() then
        return nil
    end
    return GetGroundPosition(Vector(value.x, value.y, 0), nil)
end

local function findById(rows, id)
    for _, row in ipairs(rows or {}) do
        if row.id == id then return row end
    end
end

local function unitTarget(snapshot, hero, id)
    if not number(id) or id <= 0 or id % 1 ~= 0 then return nil end
    for _, key in ipairs(UNIT_LISTS) do
        local row = findById(snapshot[key], id)
        if row then
            local unit = EntIndexToHScript(id)
            if valid(unit) and unit:IsDOTANPC() and unit:IsAlive()
                and unit:GetTeamNumber() == row.team and unit:GetUnitName() == row.name
                and (row.team == snapshot.team or hero:CanEntityBeSeenByMyTeam(unit)) then
                return unit
            end
            return nil
        end
    end
end

local function mapTarget(snapshot, field, classname, id)
    if not number(id) or id <= 0 or id % 1 ~= 0 then return nil end
    local row = findById(snapshot[field], id)
    if not row then return nil end
    local entity = EntIndexToHScript(id)
    if not valid(entity) or entity:GetClassname() ~= classname then return nil end
    local origin = entity:GetAbsOrigin()
    local dx, dy = origin.x - row.pos.x, origin.y - row.pos.y
    if dx * dx + dy * dy <= 128 * 128 and IsLocationVisible(snapshot.team, origin) then
        return entity
    end
end

local function mapPin(snapshot, kind, intent)
    local destination = position(intent.position)
    for _, pin in ipairs(snapshot.pins or {}) do
        if pin.kind == PIN_TYPES[kind] then
            local point = Vector(pin.pos.x, pin.pos.y, pin.pos.z)
            if (intent.target_id and intent.target_id == pin.targetId)
                or (destination and (destination - point):Length2D() <= 160) then
                return pin, point
            end
        end
    end
end

local function equippedItem(hero, name)
    local lastMainSlot = DOTA_ITEM_SLOT_6 or 5
    for slot = 0, lastMainSlot do
        local item = hero:GetItemInSlot(slot)
        if valid(item) and item:GetAbilityName() == name then return item end
    end
    for _, slot in pairs({ DOTA_ITEM_TP_SCROLL, DOTA_ITEM_NEUTRAL_ACTIVE_SLOT or DOTA_ITEM_NEUTRAL_SLOT }) do
        local item = hero:GetItemInSlot(slot)
        if valid(item) and item:GetAbilityName() == name then return item end
    end
end

local function isItemName(name)
    return type(name) == "string" and #name <= 128 and name:match("^item_[%w_]+$")
end

local function deniable(unit)
    if unit:IsSpeciallyUndeniable() then return false end
    if unit:IsSpeciallyDeniable() then return true end
    if unit:IsBuilding() then return unit:GetHealth() * 10 < unit:GetMaxHealth() end
    local classname = unit:GetClassname()
    return (classname == "npc_dota_creep_lane" or classname == "npc_dota_creep_siege")
        and unit:GetHealth() * 2 < unit:GetMaxHealth()
end

local function wardHits(hero, ward)
    local melee = not hero:IsRangedAttacker()
        and hero:GetUnitName() ~= "npc_dota_hero_vengefulspirit"
    local pipsPerAttack = melee and ward:HasModifier("modifier_fragile_pips") and 2 or 1
    return math.ceil(ward:GetHealth() / (4 * pipsPerAttack))
end

local function isToggleAbility(ability)
    if not bit or not bit.band or not DOTA_ABILITY_BEHAVIOR_TOGGLE then return false end
    return bit.band(ability:GetBehaviorInt(), DOTA_ABILITY_BEHAVIOR_TOGGLE) ~= 0
end

local function isCompositeItem(itemName)
    if type(itemName) ~= "string" or itemName:find("^item_recipe_") then return false end
    local recipeName = itemName:gsub("^item_", "item_recipe_")
    local rkv = GetAbilityKeyValuesByName(recipeName)
    return type(rkv) == "table" and type(rkv.ItemRequirements) == "table"
end

local function resolveNextComponent(itemName, owned, depth)
    if (depth or 0) > 6 or itemName:find("^item_recipe_") then
        return itemName
    end

    local recipeName = itemName:gsub("^item_", "item_recipe_")
    local rkv = GetAbilityKeyValuesByName(recipeName)
    if type(rkv) ~= "table" or type(rkv.ItemRequirements) ~= "table" then
        return itemName
    end

    local reqString = rkv.ItemRequirements["01"]
    if type(reqString) ~= "string" or reqString == "" then
        for _, str in pairs(rkv.ItemRequirements) do
            if type(str) == "string" and str ~= "" then
                reqString = str
                break
            end
        end
    end
    if not reqString then return itemName end

    -- Сначала дособираем составные подпредметы (например, Pavise перед Wind Lace для Solar Crest)
    local composites, basics = {}, {}
    for comp in reqString:gmatch("[^;]+") do
        local name = comp:gsub("%*$", "")
        if isCompositeItem(name) then
            composites[#composites + 1] = name
        else
            basics[#basics + 1] = name
        end
    end
    local components = {}
    for _, name in ipairs(composites) do components[#components + 1] = name end
    for _, name in ipairs(basics) do components[#components + 1] = name end
    if tonumber(rkv.ItemCost or 0) > 0 then
        components[#components + 1] = recipeName
    end

    for _, comp in ipairs(components) do
        if (owned[comp] or 0) > 0 then
            owned[comp] = owned[comp] - 1
        else
            return resolveNextComponent(comp, owned, (depth or 0) + 1)
        end
    end
    return nil
end

function ActionExecutor.new(roster, neutrals)
    local definitions = LoadKeyValues("scripts/npc/npc_ability_ids.txt") or {}
    local categories = definitions.ItemAbilities or {}
    local self = setmetatable({
        roster = roster,
        neutrals = neutrals,
        lastOrder = {},
        teleports = {},
        lastBuy = {},
        stock = {},
        courierWarned = {},
        secretQueue = {},
        itemIds = categories.Locked or {},
        floatingItemIds = categories.Floating or {},
    }, ActionExecutor)
    GameRules:GetGameModeEntity():SetExecuteOrderFilter(function(_, order)
        return self:FilterOrder(order)
    end, self)
    return self
end

function ActionExecutor:CourierFor(hero, member)
    if member and valid(member.courier) then
        return member.courier
    end
    local team = hero:GetTeamNumber()
    if not member then
        for _, candidate in ipairs(self.roster[team] or {}) do
            if candidate.hero == hero then
                member = candidate
                if valid(candidate.courier) then return candidate.courier end
                break
            end
        end
    end

    local playerId = hero:GetPlayerOwnerID()
    local found

    -- 1. Надёжный поиск среди всех курьеров на карте по владельцу-герою или playerId
    for _, courier in ipairs(Entities:FindAllByClassname("npc_dota_courier")) do
        if valid(courier) and courier:GetTeamNumber() == team then
            if courier:GetOwner() == hero or courier:GetPlayerOwnerID() == playerId then
                found = courier
                break
            end
        end
    end

    -- 2. Резервный поиск через PlayerResource (GetNthPlayerIDOnTeam 1-based!)
    if not found then
        local count = PlayerResource:GetNumCouriersForTeam(team)
        for index = 0, count - 1 do
            local courier = PlayerResource:GetNthCourierForTeam(index, team)
            if valid(courier) and courier:GetTeamNumber() == team then
                if courier:GetOwner() == hero or courier:GetPlayerOwnerID() == playerId
                    or PlayerResource:GetNthPlayerIDOnTeam(team, index + 1) == playerId then
                    found = courier
                    break
                end
            end
        end
    end

    if found and member then
        member.courier = found
    end
    return found
end

function ActionExecutor:WarnCourier(playerId, reason)
    if self.courierWarned[playerId] then return end
    self.courierWarned[playerId] = true
    local msg = string.format("Курьер недоступен (slot %d): %s", playerId, tostring(reason))
    if GameRules.Tournament and GameRules.Tournament.NotifyChat then
        GameRules.Tournament:NotifyChat("warn", "COURIER", msg, "courier_" .. tostring(playerId))
    else
        print("[Tournament] " .. msg)
    end
end

function ActionExecutor:FountainPos(team)
    self.fountains = self.fountains or {}
    if self.fountains[team] then return self.fountains[team] end
    for _, ent in ipairs(Entities:FindAllByClassname("ent_dota_fountain")) do
        if valid(ent) and ent:GetTeamNumber() == team then
            self.fountains[team] = ent:GetAbsOrigin()
            return self.fountains[team]
        end
    end
    return team == DOTA_TEAM_GOODGUYS and Vector(-7456, -6938, 393) or Vector(7152, 6592, 377)
end

function ActionExecutor:SecretShopPos(team)
    self.secretShops = self.secretShops or {}
    if self.secretShops[team] then return self.secretShops[team] end

    local fallback = team == DOTA_TEAM_GOODGUYS
        and Vector(-4736, 1344, 128)
        or Vector(4736, -1408, 128)

    local best, bestDist
    for _, ent in ipairs(Entities:FindAllByClassname("ent_dota_shop")) do
        if valid(ent) and ent:GetName():lower():find("secret") then
            local pos = ent:GetAbsOrigin()
            local d = (pos - fallback):Length2D()
            if not bestDist or d < bestDist then
                best, bestDist = pos, d
            end
        end
    end
    self.secretShops[team] = best or fallback
    return self.secretShops[team]
end

local function hasFreeSlot(unit, firstSlot, lastSlot)
    for slot = firstSlot, lastSlot do
        if not valid(unit:GetItemInSlot(slot)) then return true end
    end
    return false
end

local function heroHasItemInSlots(hero, name, firstSlot, lastSlot)
    for slot = firstSlot, lastSlot do
        local it = hero:GetItemInSlot(slot)
        if valid(it) and it:GetAbilityName() == name then return true end
    end
    return false
end

local function canHeroAcceptItem(hero, item)
    if not valid(item) then return false end
    if hasFreeSlot(hero, 0, 8) then return true end
    local name = item:GetAbilityName()
    if name == "item_tpscroll" then return true end
    if item.IsRecipe and item:IsRecipe() then return true end
    if (name == "item_ward_observer" or name == "item_ward_sentry")
        and (heroHasItemInSlots(hero, "item_ward_dispenser", 0, 8)
            or heroHasItemInSlots(hero, "item_ward_observer", 0, 8)
            or heroHasItemInSlots(hero, "item_ward_sentry", 0, 8)) then
        return true
    end
    if item.IsStackable and item:IsStackable() and heroHasItemInSlots(hero, name, 0, 8) then
        return true
    end
    return false
end

function ActionExecutor:DeliverFromStash(member)
    if GameRules.Tournament and not GameRules.Tournament.couriersReady then
        return false
    end
    local hero = member and member.hero
    if not valid(hero) or not hero:IsHero() then return false end

    local courier = self:CourierFor(hero, member)
    if not valid(courier) then
        self:WarnCourier(hero:GetPlayerOwnerID(), "no owned courier entity")
        return false
    end
    if not courier:IsAlive() then return false end

    local team = hero:GetTeamNumber()
    local fountain = self:FountainPos(team)
    local atHome = courier:IsInRangeOfShop(DOTA_SHOP_HOME, true)
        or (courier:GetAbsOrigin() - fountain):Length2D() <= 750

    -- 1. Если герой мёртв — возвращаем курьера на фонтан, чтобы не фидил на линии
    if not hero:IsAlive() then
        if not atHome then
            return self:Issue(courier, DOTA_UNIT_ORDER_MOVE_TO_POSITION, { Position = fountain }, 1.5)
        end
        return false
    end

    local playerId = hero:GetPlayerOwnerID()
    local secretReq = self.secretQueue[playerId]
    if secretReq and hasFreeSlot(courier, 0, 8) then
        local shopPos = self:SecretShopPos(team)
        if PlayerResource:GetGold(playerId) < secretReq.cost then
            self.secretQueue[playerId] = nil
        elseif courier:IsInRangeOfShop(DOTA_SHOP_SECRET, true)
            or (courier:GetAbsOrigin() - shopPos):Length2D() <= 450 then
            local item = CreateItem(secretReq.name, hero, hero)
            if valid(item) and courier:AddItem(item) then
                PlayerResource:SpendGold(playerId, secretReq.cost, DOTA_ModifyGold_PurchaseItem)
                self.secretQueue[playerId] = nil
            elseif valid(item) then
                UTIL_Remove(item)
            end
        else
            return self:Issue(courier, DOTA_UNIT_ORDER_MOVE_TO_POSITION, { Position = shopPos }, 1.2)
        end
    end

    -- 2. Если курьер на базе — перегружаем вещи из тайника героя (9..14) в курьера (0..8)
    if atHome then
        for slot = STASH_FIRST, STASH_LAST do
            local stashItem = hero:GetItemInSlot(slot)
            if valid(stashItem) and hasFreeSlot(courier, 0, 8) then
                local taken = hero:TakeItem(stashItem)
                if valid(taken) then
                    courier:AddItem(taken)
                end
            end
        end
    end

    -- Проверяем, есть ли груз в курьере, который герой РЕАЛЬНО может принять, и груз в тайнике
    local hasDeliverableItem = false
    for slot = 0, 8 do
        local item = courier:GetItemInSlot(slot)
        if valid(item) and canHeroAcceptItem(hero, item) then
            hasDeliverableItem = true
            break
        end
    end
    local hasStashItem = false
    for slot = STASH_FIRST, STASH_LAST do
        if valid(hero:GetItemInSlot(slot)) then hasStashItem = true; break end
    end

    -- 3. Доставка груза к герою (только если есть хотя бы один предмет, который влезет или стакнется/соберётся)
    if hasDeliverableItem then
        local dist = (courier:GetAbsOrigin() - hero:GetAbsOrigin()):Length2D()
        if dist <= 260 then
            for slot = 0, 8 do
                local item = courier:GetItemInSlot(slot)
                if valid(item) and canHeroAcceptItem(hero, item) then
                    local taken = courier:TakeItem(item)
                    if valid(taken) then
                        hero:AddItem(taken)
                    end
                end
            end
            -- Если больше ничего нельзя передать (всё отдали или слоты забиты), улетаем на базу
            local stillDeliverable = false
            for slot = 0, 8 do
                local item = courier:GetItemInSlot(slot)
                if valid(item) and canHeroAcceptItem(hero, item) then
                    stillDeliverable = true
                    break
                end
            end
            if not stillDeliverable then
                return self:Issue(courier, DOTA_UNIT_ORDER_MOVE_TO_POSITION, { Position = fountain }, 1.5)
            end
            return true
        end
        -- Летим за героем
        return self:Issue(courier, DOTA_UNIT_ORDER_MOVE_TO_TARGET, { TargetIndex = hero:entindex() }, 0.8)
    end

    -- 4. Курьер пустой или герой забит 9/9 — возвращаем на фонтан, чтобы забрать рецепты/тайник и не зависать
    if not atHome and (hasStashItem or (not hasDeliverableItem) or (courier:GetAbsOrigin() - fountain):Length2D() > 900) then
        return self:Issue(courier, DOTA_UNIT_ORDER_MOVE_TO_POSITION, { Position = fountain }, 1.5)
    end
    return false
end

function ActionExecutor:CourierAbility(hero, abilityName)
    local courier = self:CourierFor(hero)
    if not valid(courier) or not courier:IsAlive() then
        return false, "courier unavailable"
    end
    local ab = courier:FindAbilityByName(abilityName)
    if not valid(ab) or ab:GetLevel() == 0 or not ab:IsFullyCastable() then
        return false, "courier ability not ready"
    end
    return self:Issue(courier, DOTA_UNIT_ORDER_CAST_NO_TARGET, { AbilityIndex = ab:entindex() }, 1.0)
end

function ActionExecutor:Issue(hero, orderType, fields, repeatDelay)
    local id = hero:entindex()
    local previous = self.lastOrder[id]
    local now = GameRules:GetGameTime()
    local order = fields or {}
    local samePoint = previous and (
        (not order.Position and not previous.position)
        or (order.Position and previous.position
            and (order.Position - previous.position):Length2D() < 28))
    if samePoint and previous.kind == orderType and previous.target == order.TargetIndex
        and previous.ability == order.AbilityIndex and now - previous.at < repeatDelay then
        return true, "continuing"
    end

    order.UnitIndex = id
    order.OrderType = orderType
    order.Queue = false
    ExecuteOrderFromTable(order)
    self.lastOrder[id] = {
        kind = orderType, target = order.TargetIndex,
        ability = order.AbilityIndex, position = order.Position, at = now,
    }
    return true, "issued"
end

function ActionExecutor:StockFor(team, itemName, kv)
    local maximum = tonumber(kv.ItemStockMax)
    local period = tonumber(kv.ItemStockTime)
    if not maximum or maximum <= 0 or not period or period <= 0 then return nil end

    local byName = self.stock[team] or {}
    self.stock[team] = byName
    local stock = byName[itemName]
    local now = math.max(0, GameRules:GetDOTATime(false, true))
    if not stock then
        local initial = tonumber(kv.ItemStockInitial) or maximum
        local first = tonumber(kv.ItemInitialStockTime) or period
        stock = { left = initial, time = initial < maximum and first or nil }
        byName[itemName] = stock
    end
    if stock.time and now >= stock.time then
        local replenished = 1 + math.floor((now - stock.time) / period)
        stock.left = math.min(maximum, stock.left + replenished)
        stock.time = stock.left < maximum and stock.time + replenished * period or nil
    end
    return stock, period, now
end

function ActionExecutor:CompletePurchase(request)
    local hero = request.hero
    local stock, period, now = self:StockFor(hero:GetTeamNumber(), request.name, request.kv)
    if stock and stock.left <= 0 then return false, "out of stock" end

    local atShopDirectly = hero:IsInRangeOfShop(DOTA_SHOP_HOME, true)
        or hero:IsInRangeOfShop(DOTA_SHOP_SECRET, true)
        or not hero:IsAlive()

    local stashSlot
    for slot = STASH_FIRST, STASH_LAST do
        if not valid(hero:GetItemInSlot(slot)) then stashSlot = slot; break end
    end
    if not atShopDirectly and not stashSlot then
        return false, "stash full"
    end

    -- Если герой не в лавке и у него заняты все слоты 0..8, hero:AddItem выбросит вещь на землю на линии!
    -- Пробуем положить напрямую в курьера на базе или отклоняем покупку до появления места.
    if not atShopDirectly and not hasFreeSlot(hero, 0, 8) then
        local courier = self:CourierFor(hero)
        local fountain = self:FountainPos(hero:GetTeamNumber())
        local courierAtHome = valid(courier) and courier:IsAlive() and (
            courier:IsInRangeOfShop(DOTA_SHOP_HOME, true)
            or (courier:GetAbsOrigin() - fountain):Length2D() <= 750
        )
        if courierAtHome and hasFreeSlot(courier, 0, 8) then
            local item = CreateItem(request.name, hero, hero)
            if not valid(item) then return false, "item creation failed" end
            local added = courier:AddItem(item)
            if added then
                if request.cost > 0 then
                    PlayerResource:SpendGold(hero:GetPlayerOwnerID(), request.cost, DOTA_ModifyGold_PurchaseItem)
                end
                if stock then
                    stock.left = stock.left - 1
                    stock.time = stock.time or (now + period)
                end
                return true, "purchased directly to courier"
            else
                UTIL_Remove(item)
            end
        end
        return false, "inventory full for transfer"
    end

    local item = CreateItem(request.name, hero, hero)
    if not valid(item) then return false, "item creation failed" end

    -- Блокируем сборку на линии, чтобы предмет не собрался до доставки курьером
    if not atShopDirectly and item.SetCombineLocked then
        item:SetCombineLocked(true)
    end

    local added = hero:AddItem(item)
    if not added then
        if valid(item) then UTIL_Remove(item) end
        return false, "inventory rejected item"
    end

    if not atShopDirectly then
        local itemSlot
        for slot = 0, STASH_LAST do
            local carried = hero:GetItemInSlot(slot)
            if valid(carried) and carried == item then
                itemSlot = slot
                break
            end
        end
        -- Перемещаем в тайник ТОЛЬКО новый предмет (не трогаем стаки героя на линии)
        if itemSlot and itemSlot < STASH_FIRST and stashSlot then
            hero:SwapItems(itemSlot, stashSlot)
        end
        if valid(item) and item.SetCombineLocked then
            item:SetCombineLocked(false)
        end
    end

    if request.cost > 0 then
        PlayerResource:SpendGold(hero:GetPlayerOwnerID(), request.cost, DOTA_ModifyGold_PurchaseItem)
    end
    if stock then
        stock.left = stock.left - 1
        stock.time = stock.time or (now + period)
    end
    return true, "purchased"
end

function ActionExecutor:FilterOrder(order)
    local request = self.pendingPurchase
    if request and order.order_type == DOTA_UNIT_ORDER_PURCHASE_ITEM
        and order.issuer_player_id_const == -1 and order.entindex_ability == request.id then
        self.pendingPurchase = nil
        request.success, request.reason = self:CompletePurchase(request)
        return false
    end
    return true
end

function ActionExecutor:OwnedItemCounts(hero)
    local counts = {}
    for slot = 0, STASH_LAST do
        local item = hero:GetItemInSlot(slot)
        if valid(item) then
            local name = item:GetAbilityName()
            counts[name] = (counts[name] or 0) + 1
        end
    end
    local courier = self:CourierFor(hero)
    if valid(courier) then
        for slot = 0, 8 do
            local item = courier:GetItemInSlot(slot)
            if valid(item) then
                local name = item:GetAbilityName()
                counts[name] = (counts[name] or 0) + 1
            end
        end
    end
    local req = self.secretQueue and self.secretQueue[hero:GetPlayerOwnerID()]
    if req and req.name then
        counts[req.name] = (counts[req.name] or 0) + 1
    end
    return counts
end

function ActionExecutor:Buy(hero, requestedName)
    if not isItemName(requestedName) then return false, "invalid item" end

    -- Автоматически покупаем следующий недостающий компонент рецепта
    local owned = self:OwnedItemCounts(hero)
    if requestedName == "item_assault" and (owned[requestedName] or 0) > 0 then
        return false, "assault cuirass already owned"
    end
    local itemName = resolveNextComponent(requestedName, owned, 0)
    if not itemName then return false, "recipe components already acquired" end

    local kv = GetAbilityKeyValuesByName(itemName)
    local itemId = type(kv) == "table"
        and tonumber(kv.ID or self.itemIds[itemName] or self.floatingItemIds[itemName])
    if not itemId or itemId <= 0 or tonumber(kv.ItemPurchasable) == 0
        or tonumber(kv.ItemIsNeutralDrop) == 1 or tonumber(kv.IsObsolete) == 1 then
        return false, "item unavailable in shops"
    end

    local playerId = hero:GetPlayerOwnerID()
    local cost = GetItemCost(itemName)
    if PlayerResource:GetGold(playerId) < cost then
        return false, "insufficient gold"
    end

    local secretShop = tonumber(kv.SecretShop) == 1
    if secretShop then
        local nearHero = hero:IsInRangeOfShop(DOTA_SHOP_SECRET, true)
        if not nearHero then
            local existing = self.secretQueue[playerId]
            if not existing then
                self.secretQueue[playerId] = { name = itemName, cost = cost, kv = kv }
            end
            return true, "courier sent to secret shop"
        end
    end

    local now = GameRules:GetGameTime()
    if self.lastBuy[playerId] and now - self.lastBuy[playerId] < 0.20 then
        return false, "purchase pending"
    end
    self.lastBuy[playerId] = now

    local request = { hero = hero, name = itemName, cost = cost, id = itemId, kv = kv }
    self.pendingPurchase = request
    ExecuteOrderFromTable({
        UnitIndex = hero:entindex(),
        OrderType = DOTA_UNIT_ORDER_PURCHASE_ITEM,
        AbilityIndex = itemId,
        Queue = false,
    })
    self.pendingPurchase = nil
    if request.success ~= nil then return request.success, request.reason end
    return true, "issued"
end

function ActionExecutor:Cast(snapshot, hero, name, intent, forceMode)
    if type(name) ~= "string" or #name > 128 or not name:match("^[%w_]+$") then
        return false, "invalid ability"
    end
    local isItem = isItemName(name)
    local ability = isItem and equippedItem(hero, name) or hero:FindAbilityByName(name)

    if not valid(ability) and (name == "item_ward_observer" or name == "item_ward_sentry") then
        ability = equippedItem(hero, "item_ward_dispenser")
        if valid(ability) then
            local wantObserver = name == "item_ward_observer"
            local charges = wantObserver and ability:GetCurrentCharges()
                or (ability.GetSecondaryCharges and ability:GetSecondaryCharges() or 0)
            if charges < 1 then return false, "no charges for requested wards" end
            -- В Dota 2 у item_ward_dispenser: GetToggleState() == false -> Observer, true -> Sentry
            local sentrySelected = ability:GetToggleState() == true
            if sentrySelected == wantObserver then
                return self:Issue(hero, DOTA_UNIT_ORDER_CAST_TARGET,
                    { AbilityIndex = ability:entindex(), TargetIndex = hero:entindex() }, 0.45)
            end
        end
    end

    if not valid(ability) or ability:IsPassive()
        or (not isItem and ability:GetLevel() == 0) then
        return false, "ability unavailable"
    end

    local fields = { AbilityIndex = ability:entindex() }
    if forceMode == "autocast" then
        return self:Issue(hero, DOTA_UNIT_ORDER_CAST_TOGGLE_AUTO, fields, 0.45)
    end
    if forceMode == "toggle" or (isToggleAbility(ability) and ability:GetAbilityName() ~= "item_ward_dispenser") then
        if not ability:IsFullyCastable() and not ability:GetToggleState() then
            return false, "ability not castable"
        end
        return self:Issue(hero, DOTA_UNIT_ORDER_CAST_TOGGLE, fields, 0.45)
    end
    if not ability:IsFullyCastable() then
        return false, "ability unavailable"
    end

    if (name == "item_tango" or name == "item_tango_single") and intent.target_id == nil then
        local trees = GridNav:GetAllTreesAroundPoint(hero:GetAbsOrigin(), 450, true)
        local tree = trees and trees[1]
        if not tree then return false, "no tree nearby for tango" end
        local treeIdx = tree.GetEntityIndex and tree:GetEntityIndex() or tree:entindex()
        fields.TargetIndex = GetTreeIdForEntityIndex and GetTreeIdForEntityIndex(treeIdx) or treeIdx
        return self:Issue(hero, DOTA_UNIT_ORDER_CAST_TARGET_TREE, fields, 0.45)
    end

    if intent.target_id ~= nil and intent.position ~= nil then
        return false, "choose a unit or point target"
    elseif intent.target_id ~= nil then
        local target = unitTarget(snapshot, hero, intent.target_id)
        if not target then return false, "invalid or hidden target" end
        if TELEPORT_ITEMS[name] then
            self.teleports[hero:entindex()] = { pos = target:GetAbsOrigin(), at = GameRules:GetGameTime() }
        end
        fields.TargetIndex = target:entindex()
        return self:Issue(hero, DOTA_UNIT_ORDER_CAST_TARGET, fields, 0.45)
    elseif intent.position ~= nil then
        fields.Position = position(intent.position)
        if not fields.Position then return false, "invalid position" end
        if TELEPORT_ITEMS[name] then
            self.teleports[hero:entindex()] = { pos = fields.Position, at = GameRules:GetGameTime() }
        end
        return self:Issue(hero, DOTA_UNIT_ORDER_CAST_POSITION, fields, 0.45)
    end
    return self:Issue(hero, DOTA_UNIT_ORDER_CAST_NO_TARGET, fields, 0.45)
end

function ActionExecutor:WardFocus(snapshot, hero, intent)
    local target
    if intent.target_id ~= nil then
        target = unitTarget(snapshot, hero, intent.target_id)
    else
        local best
        local from = hero:GetAbsOrigin()
        for _, row in ipairs(snapshot.enemies or {}) do
            if WARDS[row.name] then
                local ward = unitTarget(snapshot, hero, row.id)
                if ward and not ward:IsAttackImmune() and not ward:IsInvulnerable() then
                    local dist = (ward:GetAbsOrigin() - from):Length2D()
                    local score = wardHits(hero, ward) + dist / 600
                    if dist <= 1200 and (not best or score < best) then
                        best, target = score, ward
                    end
                end
            end
        end
    end
    if not target or target:GetTeamNumber() == snapshot.team or not WARDS[target:GetUnitName()]
        or target:IsAttackImmune() or target:IsInvulnerable() then
        return false, "no attackable ward in vision"
    end
    return self:Issue(hero, DOTA_UNIT_ORDER_ATTACK_TARGET, { TargetIndex = target:entindex() }, 1.2)
end

local function isDeaggroAlly(team, hero, unit)
    return valid(unit)
        and unit ~= hero
        and unit:GetTeamNumber() == team
        and unit:IsAlive()
        and not unit:IsBuilding()
        and not unit:IsCourier()
        and not WARDS[unit:GetUnitName()]
        and not unit:IsAttackImmune()
        and not unit:IsInvulnerable()
end

function ActionExecutor:Deaggro(snapshot, hero, intent)
    local team = snapshot.team
    local target
    if intent.target_id ~= nil then
        local candidate = unitTarget(snapshot, hero, intent.target_id)
        if isDeaggroAlly(team, hero, candidate) then
            target = candidate
        end
    else
        local bestDist
        local from = hero:GetAbsOrigin()
        for _, row in ipairs(snapshot.allies or {}) do
            if row.kind == "lane_creep" or row.kind == "siege_creep" or row.kind == "unit" then
                local unit = unitTarget(snapshot, hero, row.id)
                if isDeaggroAlly(team, hero, unit) then
                    local dist = (unit:GetAbsOrigin() - from):Length2D()
                    if dist <= 1200 and (not bestDist or dist < bestDist) then
                        bestDist, target = dist, unit
                    end
                end
            end
        end
    end

    if not target then
        return false, "no valid allied unit for deaggro"
    end
    return self:Issue(hero, DOTA_UNIT_ORDER_ATTACK_TARGET, { TargetIndex = target:entindex() }, 0.45)
end

function ActionExecutor:Objective(snapshot, hero, kind, intent)
    local pin, point = mapPin(snapshot, kind, intent)
    if not pin then return false, "unknown map objective" end

    if kind == "gate" and pin.targetId and IsLocationVisible(snapshot.team, point) then
        local gate = EntIndexToHScript(pin.targetId)
        if valid(gate) and gate:GetClassname() == OBJECT_INTERACT then
            return self:Issue(hero, DOTA_UNIT_ORDER_INTERACT_WITH_TARGET,
                { TargetIndex = gate:entindex() }, 1.5)
        end
    end

    local dist = (hero:GetAbsOrigin() - point):Length2D()
    local radius = OBJECT_RADIUS[kind]
    if radius and dist < radius then
        if pin.visible and pin.active == false then return false, "objective depleted" end
        return self:Issue(hero, DOTA_UNIT_ORDER_HOLD_POSITION, nil, 1.0)
    end

    return self:Issue(hero, DOTA_UNIT_ORDER_MOVE_TO_POSITION, { Position = point }, 0.8)
end

function ActionExecutor:ExecuteSingle(team, snapshot, hero, intent)
    local kind = intent.kind
    if type(kind) ~= "string" then return false, "missing kind" end

    -- Действия, доступные даже мёртвому герою
    if kind == "buy" then
        return self:Buy(hero, intent.item)
    elseif kind == "learn" then
        local ability = type(intent.ability) == "string" and hero:FindAbilityByName(intent.ability)
        if not valid(ability) or ability:GetLevel() >= ability:GetMaxLevel() then
            return false, "ability unavailable to learn"
        end
        local oldLevel = ability:GetLevel()
        if Talents.isTalent(intent.ability) then
            if oldLevel > 0 then return false, "talent already learned" end
            local tree = {}
            for slot = 0, hero:GetAbilityCount() - 1 do
                local entry = hero:GetAbilityByIndex(slot)
                if valid(entry) and Talents.isTalent(entry:GetAbilityName()) then
                    tree[slot] = {
                        name = entry:GetAbilityName(),
                        level = entry:GetLevel(),
                        maxLevel = entry:GetMaxLevel(),
                    }
                end
            end
            local required = Talents.requiredLevels(tree)[intent.ability]
            if not required or hero:GetLevel() < required then return false, "talent still locked" end

            self.talentTries = self.talentTries or {}
            local key = hero:entindex() .. ":" .. intent.ability
            local now = GameRules:GetGameTime()
            local rec = self.talentTries[key]
            if rec and now - rec.at < 0.35 then
                return true, "talent train pending"
            end
            local attempts = rec and (rec.attempts + 1) or 1
            self.talentTries[key] = { at = now, attempts = attempts }

            -- Штатный приказ движка: корректно тратит очко таланта и обновляет дерево в HUD зрителя
            ExecuteOrderFromTable({
                UnitIndex = hero:entindex(),
                OrderType = DOTA_UNIT_ORDER_TRAIN_ABILITY,
                AbilityIndex = ability:entindex(),
                Queue = false,
            })
            if ability:GetLevel() > oldLevel then
                self.talentTries[key] = nil
                return true, "talent upgraded"
            end

            -- Даём время на обработку приказа; резерв через hero:UpgradeAbility без траты обычного очка скилла
            if attempts >= 3 then
                local pts = hero:GetAbilityPoints()
                hero:UpgradeAbility(ability)
                if ability:GetLevel() <= oldLevel and pts == 0 then
                    hero:SetAbilityPoints(1)
                    hero:UpgradeAbility(ability)
                    hero:SetAbilityPoints(0)
                elseif hero:GetAbilityPoints() < pts then
                    hero:SetAbilityPoints(pts)
                end
                if ability:GetLevel() <= oldLevel then
                    ability:UpgradeAbility(false)
                end
                if ability:GetLevel() > oldLevel then
                    self.talentTries[key] = nil
                    return true, "talent upgraded fallback"
                end
                return false, "talent did not upgrade"
            end
            return true, "talent train issued"
        else
            if ability:IsHidden() or ability:CanAbilityBeUpgraded() ~= ABILITY_CAN_BE_UPGRADED then
                return false, "ability unavailable to learn"
            end
            if hero:GetAbilityPoints() < 1 then return false, "no ability points" end
            hero:UpgradeAbility(ability)
            if ability:GetLevel() <= oldLevel then return false, "ability did not upgrade" end
            return true, "ability upgraded"
        end
    elseif kind == "buyback" then
        if hero:IsAlive() then return false, "already alive" end
        return self:Issue(hero, DOTA_UNIT_ORDER_BUYBACK, nil, 1.0)
    elseif kind == "glyph" then
        local cd = GameRules.GetGlyphCooldown and GameRules:GetGlyphCooldown(team) or 0
        if cd > 0 then return false, "glyph on cooldown" end
        return self:Issue(hero, DOTA_UNIT_ORDER_GLYPH, nil, 2.0)
    elseif kind == "swap" then
        local a, b = intent.slot_a, intent.slot_b
        if not number(a) or not number(b) or a < 0 or b < 0 or a > STASH_LAST or b > STASH_LAST then
            return false, "invalid slots"
        end
        if (a >= STASH_FIRST or b >= STASH_FIRST) and hero:IsAlive()
            and not hero:IsInRangeOfShop(DOTA_SHOP_HOME, true) then
            return false, "stash swap requires fountain"
        end
        hero:SwapItems(a, b)
        return true, "swapped"
    elseif kind == "sell" then
        if hero:IsAlive() and not hero:IsInRangeOfShop(DOTA_SHOP_HOME, true)
            and not hero:IsInRangeOfShop(DOTA_SHOP_SECRET, true) then
            return false, "must be at shop to sell"
        end
        local item = number(intent.slot) and hero:GetItemInSlot(intent.slot)
            or (isItemName(intent.item) and equippedItem(hero, intent.item))
        if not valid(item) or (intent.expectedItem and item:GetAbilityName() ~= intent.expectedItem) then
            return false, "item not found"
        end
        hero:SellItem(item)
        return true, "sold"
    elseif kind == "autocast" then
        return self:Cast(snapshot, hero, intent.item or intent.ability, intent, "autocast")
    elseif kind == "courier_burst" then
        return self:CourierAbility(hero, "courier_burst")
    elseif kind == "courier_shield" then
        return self:CourierAbility(hero, "courier_shield")
    elseif kind == "choose_neutral" then
        if not self.neutrals then return false, "neutral manager unavailable" end
        return self.neutrals:ChooseForHero(hero, intent.artifact, intent.enchantment)
    end

    if not hero:IsAlive() then
        return false, "hero is dead"
    end

    if kind == "cast" and intent.ability == ICE_RELEASE then
        local release = hero:FindAbilityByName(ICE_RELEASE)
        if not valid(release) or release:IsHidden() then return false, "ice blast tracer inactive" end
        return self:Cast(snapshot, hero, ICE_RELEASE, {})
    end

    local casting = hero:GetCurrentActiveAbility()
    if hero:IsChanneling() or hero:HasModifier("modifier_twin_gate_warp_channel")
        or (valid(casting) and casting:IsInAbilityPhase()) then
        return false, "casting in progress"
    end

    if kind == "move" or kind == "attack_move" then
        local point = position(intent.position)
        if not point then return false, "invalid position" end
        local order = kind == "move" and DOTA_UNIT_ORDER_MOVE_TO_POSITION or DOTA_UNIT_ORDER_ATTACK_MOVE
        return self:Issue(hero, order, { Position = point }, 0.30)
    elseif kind == "hold" or kind == "stop" then
        local order = kind == "hold" and DOTA_UNIT_ORDER_HOLD_POSITION or DOTA_UNIT_ORDER_STOP
        return self:Issue(hero, order, nil, 1.0)
    elseif kind == "attack" or kind == "deny" then
        local target = unitTarget(snapshot, hero, intent.target_id)
        if not target or target:IsAttackImmune() or target:IsInvulnerable() then
            return false, "invalid or hidden target"
        end
        local allied = target:GetTeamNumber() == team
        if allied ~= (kind == "deny") or (allied and (target == hero or not deniable(target))) then
            return false, "invalid attack or deny"
        end
        local previous = self.lastOrder[hero:entindex()]
        if previous and previous.kind == DOTA_UNIT_ORDER_ATTACK_TARGET and previous.target == intent.target_id
            and hero.IsAttackingEntity and hero:IsAttackingEntity(target) then
            return true, "attack in progress"
        end
        return self:Issue(hero, DOTA_UNIT_ORDER_ATTACK_TARGET, { TargetIndex = target:entindex() }, 1.0)
    elseif kind == "ward_focus" then
        return self:WardFocus(snapshot, hero, intent)
    elseif kind == "deaggro" then
        return self:Deaggro(snapshot, hero, intent)
    elseif kind == "cast" then
        return self:Cast(snapshot, hero, intent.item or intent.ability, intent)
    elseif kind == "toggle" then
        return self:Cast(snapshot, hero, intent.item or intent.ability, intent, "toggle")
    elseif kind == "tp" then
        local tpItem = hero:GetItemInSlot(DOTA_ITEM_TP_SCROLL or 15)
        if not valid(tpItem) or tpItem:GetAbilityName() ~= "item_tpscroll"
            or not tpItem:IsFullyCastable() or hero:IsRooted() then
            return false, "no tp available"
        end
        return self:Cast(snapshot, hero, "item_tpscroll", intent)
    elseif kind == "smoke" then
        return self:Cast(snapshot, hero, "item_smoke_of_deceit", {})
    elseif kind == "drop" then
        local item = number(intent.slot) and hero:GetItemInSlot(intent.slot)
            or (isItemName(intent.item) and equippedItem(hero, intent.item))
        if not valid(item) then return false, "item not found" end
        local point = position(intent.position) or hero:GetAbsOrigin()
        return self:Issue(hero, DOTA_UNIT_ORDER_DROP_ITEM,
            { AbilityIndex = item:entindex(), Position = point }, 1.0)
    elseif kind == "rune" or kind == "pickup" then
        local isRune = kind == "rune"
        local object = mapTarget(snapshot, isRune and "runes" or "drops",
            isRune and "dota_item_rune" or "dota_item_drop", intent.target_id)
        if not object then return false, "pickup no longer visible" end
        if isRune and (hero:GetAbsOrigin() - object:GetAbsOrigin()):Length2D() <= 180 then
            if hero.PickupRune then
                local ok = pcall(hero.PickupRune, hero, object)
                if ok then return true, "rune picked up" end
            end
        end
        local order = isRune and DOTA_UNIT_ORDER_PICKUP_RUNE or DOTA_UNIT_ORDER_PICKUP_ITEM
        return self:Issue(hero, order, { TargetIndex = object:entindex() }, 0.8)
    elseif PIN_TYPES[kind] then
        return self:Objective(snapshot, hero, kind, intent)
    end
    return false, "unsupported action"
end

function ActionExecutor:Execute(team, snapshot, member, intentOrList)
    if type(snapshot) ~= "table" or snapshot.team ~= team or type(member) ~= "table"
        or type(intentOrList) ~= "table" then
        return false, "invalid order"
    end
    local hero = member.hero
    if not valid(hero) or hero:GetTeamNumber() ~= team
        or not PlayerResource:IsFakeClient(hero:GetPlayerOwnerID()) then
        return false, "invalid bot actor"
    end

    -- Поддержка как одиночного действия { kind = ... }, так и списка { {kind="buy",...}, {kind="move",...} }
    local list = intentOrList.kind and { intentOrList } or intentOrList
    local usedMainOrder = false
    local lastStatus

    for _, intent in ipairs(list) do
        if type(intent) == "table" and type(intent.kind) == "string" then
            if intent.status and intent.status ~= "" then
                lastStatus = intent.status
            end
            if INSTANT_KINDS[intent.kind] or (intent.kind == "cast" and intent.ability == ICE_RELEASE) then
                self:ExecuteSingle(team, snapshot, hero, intent)
            elseif not usedMainOrder then
                usedMainOrder = true
                self:ExecuteSingle(team, snapshot, hero, intent)
            end
        end
    end
    return true, lastStatus
end

return ActionExecutor
