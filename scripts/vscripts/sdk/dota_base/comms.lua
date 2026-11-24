-- ============================================================================
-- SDK: Система командного общения с жёсткой проверкой фактов
-- Строгий Lua 5.1 | Без внешних зависимостей
-- ============================================================================

local Comms = {}

local LANE_ON = { top = "топе", mid = "миду", bot = "боте" }
local LANE_TO = { top = "топ", mid = "мид", bot = "бот" }

local ZONE_ON = {
    top = "на топе",
    mid = "на миду",
    bot = "на боте",
    river = "на реке",
    roshan = "у рошпита",
    own_jungle = "в нашем лесу",
    enemy_jungle = "во вражеском лесу",
    own_base = "на нашей базе",
    enemy_base = "у вражеской базы",
}

local HERO_RU = {
    npc_dota_hero_luna = "Луна", npc_dota_hero_sven = "Свен",
    npc_dota_hero_juggernaut = "Джаггер", npc_dota_hero_drow_ranger = "Дровка",
    npc_dota_hero_dragon_knight = "ДК", npc_dota_hero_lina = "Лина",
    npc_dota_hero_viper = "Вайпер", npc_dota_hero_death_prophet = "ДП",
    npc_dota_hero_tidehunter = "Тайд", npc_dota_hero_centaur = "Кентавр",
    npc_dota_hero_axe = "Акс", npc_dota_hero_slardar = "Слардар",
    npc_dota_hero_lion = "Лион", npc_dota_hero_shadow_shaman = "Шаман",
    npc_dota_hero_vengefulspirit = "Венга", npc_dota_hero_ogre_magi = "Огр",
    npc_dota_hero_jakiro = "Джакиро", npc_dota_hero_witch_doctor = "ВД",
    npc_dota_hero_lich = "Лич", npc_dota_hero_crystal_maiden = "ЦМка",
    npc_dota_hero_phantom_assassin = "ПА", npc_dota_hero_faceless_void = "Войд",
    npc_dota_hero_antimage = "АМ", npc_dota_hero_slark = "Сларк",
    npc_dota_hero_mars = "Марс", npc_dota_hero_enigma = "Энигма",
    npc_dota_hero_magnataur = "Магнус", npc_dota_hero_earthshaker = "Шейкер",
    npc_dota_hero_sniper = "Снайпер", npc_dota_hero_puck = "Пак",
    npc_dota_hero_storm_spirit = "Шторм", npc_dota_hero_queenofpain = "Квопа",
    npc_dota_hero_zuus = "Зевс", npc_dota_hero_invoker = "Инвокер",
    npc_dota_hero_disruptor = "Дизраптор", npc_dota_hero_warlock = "Варлок",
    npc_dota_hero_dazzle = "Даззл", npc_dota_hero_rubick = "Рубик",
    npc_dota_hero_pudge = "Пудж", npc_dota_hero_bristleback = "Бристл",
    npc_dota_hero_ursa = "Урса", npc_dota_hero_chaos_knight = "ЦК",
    npc_dota_hero_terrorblade = "ТБ", npc_dota_hero_gyrocopter = "Гиро",
    npc_dota_hero_leshrac = "Лешрак", npc_dota_hero_huskar = "Хускар",
    npc_dota_hero_windrunner = "ВРка", npc_dota_hero_kunkka = "Кунка",
    npc_dota_hero_razor = "Разор", npc_dota_hero_legion_commander = "Лега",
    npc_dota_hero_doom_bringer = "Дум", npc_dota_hero_necrolyte = "Некр",
    npc_dota_hero_night_stalker = "НС", npc_dota_hero_skywrath_mage = "Скай",
    npc_dota_hero_snapfire = "Снэпка", npc_dota_hero_hoodwink = "Белка",
    npc_dota_hero_spirit_breaker = "Бара", npc_dota_hero_venomancer = "Веник",
    npc_dota_hero_silencer = "Сайленсер", npc_dota_hero_undying = "Андаинг",
    npc_dota_hero_bane = "Бейн", npc_dota_hero_abaddon = "Абаддон",
    npc_dota_hero_grimstroke = "Грим", npc_dota_hero_pugna = "Пугна",
}

local KEY_ITEM_LABELS = {
    item_black_king_bar   = "БКБ",
    item_blink            = "Блинк",
    item_manta            = "Манту",
    item_pipe             = "Пайп",
    item_crimson_guard    = "Кримсон",
    item_guardian_greaves = "Гривсы",
    item_satanic          = "Сатаник",
    item_sheepstick       = "Хекс",
    item_butterfly        = "Бабочку",
    item_greater_crit     = "Даедалус",
    item_monkey_king_bar  = "МКБ",
    item_shivas_guard     = "Шиву",
    item_assault          = "Кирасу",
    item_orchid           = "Орчид",
    item_bloodthorn       = "Бладторн",
    item_skadi            = "Скади",
    item_heart            = "Тараску",
    item_hurricane_pike   = "Пику",
    item_blade_mail       = "БМ",
    item_echo_sabre       = "Саблю",
    item_desolator        = "Дезоль",
    item_ultimate_scepter = "Аганим",
    item_sange_and_yasha  = "СиЯ",
    item_kaya_and_sange   = "Каю-Сандж",
}

-- Точные коридоры линий по башням и точкам стычки карты 7.42
local LANE_CORRIDORS = {
    top = {
        { -6592, -3408 }, { -6501, -872 }, { -6336, 1856 },
        { -5800, 3860 }, { -5275, 6036 }, { -128, 6016 }, { 3552, 5776 },
    },
    mid = {
        { -4640, -4144 }, { -3008, -2744 }, { -1234, -1232 },
        { -190, -190 }, { 832, 848 }, { 2704, 2272 }, { 4272, 3759 },
    },
    bot = {
        { -3952, -6112 }, { -360, -6256 }, { 4860, -6379 },
        { 5600, -4280 }, { 6269, -2240 }, { 6400, 384 }, { 6336, 3032 },
    },
}

local function pick(list)
    return list[math.random(1, #list)]
end

local function dist(a, b)
    if not a or not b then return math.huge end
    local dx, dy = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local function ratio(a, b)
    return (a or 0) / math.max(1, b or 1)
end

local function ptSegDist(px, py, ax, ay, bx, by)
    local vx, vy = bx - ax, by - ay
    local wx, wy = px - ax, py - ay
    local l2 = vx * vx + vy * vy
    if l2 <= 1 then
        return math.sqrt(wx * wx + wy * wy)
    end
    local t = math.max(0, math.min(1, (wx * vx + vy * vy) / l2))
    local cx, cy = ax + t * vx, ay + t * vy
    local dx, dy = px - cx, py - cy
    return math.sqrt(dx * dx + dy * dy)
end

local function laneCorridorDist(pos, lane)
    local pts = LANE_CORRIDORS[lane]
    local px, py = pos.x or 0, pos.y or 0
    local best = math.huge
    for i = 1, #pts - 1 do
        local d = ptSegDist(px, py, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2])
        if d < best then best = d end
    end
    return best
end

-- Определяет РЕАЛЬНОЕ физическое место героя на карте (не по стартовой роли!)
function Comms.resolveLocation(snapshot, pos)
    if not pos then return "river", nil end
    local ownAnc, enemyAnc, ownFnt, enemyFnt
    for _, pin in ipairs(snapshot.pins or {}) do
        if pin.kind == "ancient" then
            if pin.mapTeam == snapshot.team then ownAnc = pin.pos else enemyAnc = pin.pos end
        elseif pin.kind == "fountain" then
            if pin.mapTeam == snapshot.team then ownFnt = pin.pos else enemyFnt = pin.pos end
        elseif pin.kind == "roshan" and dist(pos, pin.pos) <= 1350 then
            return "roshan", nil
        end
    end
    if (ownAnc and dist(pos, ownAnc) <= 2350) or (ownFnt and dist(pos, ownFnt) <= 2200) then
        return "own_base", nil
    end
    if (enemyAnc and dist(pos, enemyAnc) <= 2350) or (enemyFnt and dist(pos, enemyFnt) <= 2200) then
        return "enemy_base", nil
    end

    local bestLane, bestDist = nil, math.huge
    for _, ln in ipairs({ "top", "mid", "bot" }) do
        local d = laneCorridorDist(pos, ln)
        if d < bestDist then bestLane, bestDist = ln, d end
    end
    if bestDist <= 1250 then
        return bestLane, bestLane
    end

    local diag = (pos.x or 0) + (pos.y or 0)
    if math.abs(diag) <= 1200 then
        return "river", nil
    end
    local onRadiantHalf = diag < 0
    local isRadiant = (snapshot.team == 2) or (ownAnc and ((ownAnc.x or 0) + (ownAnc.y or 0)) < 0)
    if onRadiantHalf == isRadiant then
        return "own_jungle", nil
    end
    return "enemy_jungle", nil
end

local function heroLabel(hero)
    if not hero then return "Союзник" end
    local ru = HERO_RU[hero.name]
    if ru then return ru end
    local raw = tostring(hero.name or "hero"):gsub("^npc_dota_hero_", ""):gsub("_", " ")
    return raw:sub(1, 1):upper() .. raw:sub(2)
end

local function senderName(hero)
    return string.format("%s (Pos %d)", heroLabel(hero), hero.position or 0)
end

local function copyCounts(src)
    local out = {}
    for k, v in pairs(src or {}) do out[k] = v end
    return out
end

local function remainingCostForNode(node, owned)
    if not node then return 0 end
    if (owned[node.name] or 0) > 0 then
        owned[node.name] = owned[node.name] - 1
        return 0
    end
    if not node.reqs or #node.reqs == 0 then
        return node.cost or 0
    end
    local sum = 0
    for _, child in ipairs(node.reqs) do
        sum = sum + remainingCostForNode(child, owned)
    end
    return sum
end

local function countObsInAllSlots(hero)
    local total = 0
    local charges = hero.itemCharges or {}
    for slot, name in pairs(hero.items or {}) do
        if slot <= 8 then
            if name == "item_ward_observer" then
                total = total + math.max(1, charges[slot] or 1)
            elseif name == "item_ward_dispenser" then
                total = total + (charges[slot] or 0)
            end
        end
    end
    return total
end

local function countObsOnMap(snapshot, center, radius)
    local n = 0
    for _, a in ipairs(snapshot.allies or {}) do
        if a.kind == "observer_ward" and a.alive then
            if not center or not radius or dist(a.pos, center) <= radius then
                n = n + 1
            end
        end
    end
    return n
end

local function countVisibleEnemiesNear(snapshot, pos, radius)
    local n = 0
    for _, e in ipairs(snapshot.enemies or {}) do
        if e.kind == "hero" and not e.isIllusion and e.alive ~= false and dist(e.pos, pos) <= radius then
            n = n + 1
        end
    end
    return n
end

local function nearOwnTower(snapshot, pos, radius)
    for _, a in ipairs(snapshot.allies or {}) do
        if a.kind == "tower" and a.alive ~= false and dist(a.pos, pos) <= radius then
            return true
        end
    end
    return false
end

local function hasReadyTp(hero)
    local slot = (hero.items or {})[15]
    if slot ~= "item_tpscroll" then return false end
    return ((hero.itemCooldown or {})[15] or 0) <= 0
end

local function findAliveResponder(snapshot, excludeId, pred)
    local pool = {}
    for _, h in ipairs(snapshot.heroes or {}) do
        if h.id ~= excludeId and h.alive and (not pred or pred(h)) then
            pool[#pool + 1] = h
        end
    end
    return #pool > 0 and pick(pool) or nil
end

function Comms.newState()
    return {
        queue = {},
        outbox = {},
        cooldowns = {},
        lastTopicAt = -999,
        track = {},        -- подробная 8-сек история каждого союзника
        directive = nil,   -- активная директива команды
    }
end

function Comms.say(state, now, hero, text, tone, delay, allowDead)
    if not state or not hero or type(text) ~= "string" or text == "" then return end
    local msg = {
        sender = senderName(hero),
        heroId = hero.id,
        text = text,
        tone = tone or "call",
        sendAt = now + (delay or 0),
        allowDead = allowDead == true,
    }
    if not delay or delay <= 0 then
        state.outbox[#state.outbox + 1] = msg
    else
        state.queue[#state.queue + 1] = msg
    end
end

local function canTopic(state, now, key, cd, ignoreGlobal)
    if (state.cooldowns[key] or -999) > now then return false end
    if not ignoreGlobal and (now - (state.lastTopicAt or -999)) < 11 then return false end
    return true
end

local function markTopic(state, now, key, cd)
    state.cooldowns[key] = now + cd
    state.lastTopicAt = now
end

-- Точный расчёт недостающей голды и доставки курьером по реальному дереву рецептов 7.42
local function inspectKeyItemTiming(snapshot, hero, build)
    local recipes = snapshot.keyItemRecipes
    if not build or type(recipes) ~= "table" then return nil end

    local ownedMain, ownedAll = {}, {}
    for slot, name in pairs(hero.items or {}) do
        if slot <= 8 then
            ownedMain[name] = (ownedMain[name] or 0) + 1
            ownedAll[name] = (ownedAll[name] or 0) + 1
        elseif slot >= 9 and slot <= 14 then
            ownedAll[name] = (ownedAll[name] or 0) + 1
        end
    end
    local courierCarrying = false
    if hero.courier and hero.courier.alive then
        for _, name in ipairs(hero.courier.carrying or {}) do
            ownedAll[name] = (ownedAll[name] or 0) + 1
            courierCarrying = true
        end
    end

    for _, target in ipairs(build) do
        local label = KEY_ITEM_LABELS[target]
        local recipe = recipes[target]
        if label and recipe and (ownedMain[target] or 0) == 0 then
            local remMain = remainingCostForNode(recipe, copyCounts(ownedMain))
            local remAll = remainingCostForNode(recipe, copyCounts(ownedAll))
            if remMain > 0 then
                -- Все компоненты уже куплены и лежат в курьере/тайнике!
                if remAll == 0 and courierCarrying then
                    local eta = (hero.courier and hero.courier.distToHero)
                        and math.max(3, math.ceil(hero.courier.distToHero / 420)) or 6
                    return { item = target, label = label, mode = "COURIER", eta = eta, goldNeeded = 0 }
                end
                local goldNeeded = remAll - (hero.gold or 0)
                if goldNeeded >= 60 and goldNeeded <= 450 then
                    return {
                        item = target,
                        label = label,
                        mode = "GOLD",
                        goldNeeded = math.ceil(goldNeeded / 10) * 10,
                    }
                end
            end
            break
        end
    end
    return nil
end

-- ============================================================================
-- ШАГ 1 (ДО MACRO.build): обновляем 8-сек историю и проверяем статус директивы
-- ============================================================================
function Comms.updateHistory(snapshot, state, observerOrders, COMBAT, allowDefaultChat)
    local now = snapshot.time
    local heroes = snapshot.heroes or {}

    -- Сброс истёкшей или выполненной директивы
    local dir = state.directive
    if dir then
        if now >= (dir.expiresAt or 0) then
            state.directive = nil
            dir = nil
        elseif dir.kind == "WAIT_ITEM" then
            for _, h in ipairs(heroes) do
                if h.id == dir.callerId then
                    if not h.alive then
                        state.directive = nil
                        dir = nil
                        break
                    end
                    for slot = 0, 5 do
                        if (h.items or {})[slot] == dir.item then
                            if allowDefaultChat ~= false then
                                Comms.say(state, now, h, pick({
                                    string.format("всё, %s в инвентаре! го соберёмся и выйдем в драку!", dir.itemLabel),
                                    string.format("%s прилетел, можно выходить на файт!", dir.itemLabel),
                                }), "praise", 0)
                                local ally = findAliveResponder(snapshot, h.id)
                                if ally then
                                    Comms.say(state, now, ally, pick({
                                        "найс, выдвигаюсь!",
                                        "принял, погнали давить",
                                    }), "reply", 1.5)
                                end
                            end
                            state.directive = {
                                kind = "GO_FIGHT",
                                callerId = h.id,
                                label = "TIMING: " .. dir.itemLabel .. " READY!",
                                expiresAt = now + 22,
                            }
                            dir = state.directive
                            break
                        end
                    end
                    break
                end
            end
        elseif dir.kind == "WAIT_ULT" and COMBAT and COMBAT.teamFightReadiness then
            local ready = COMBAT.teamFightReadiness(snapshot)
            if not ready.ultsMissing or ready.minUltCd <= 5 then
                if allowDefaultChat ~= false then
                    for _, h in ipairs(heroes) do
                        if h.id == dir.callerId and h.alive then
                            Comms.say(state, now, h, "ульт откатился, можно собираться в драку!", "call", 0)
                            break
                        end
                    end
                end
                state.directive = nil
                dir = nil
            end
        elseif dir.kind == "NEED_WARDS" then
            if countObsOnMap(snapshot) >= 1 then
                state.directive = nil
                dir = nil
            end
        end
    end

    -- Обновляем rolling-историю по каждому союзнику
    for _, h in ipairs(heroes) do
        local tr = state.track[h.id]
        if not tr then
            tr = {
                alive = h.alive,
                kills = h.kills or 0,
                deaths = h.deaths or 0,
                assists = h.assists or 0,
                lastAlivePos = h.pos,
                lastAllyNearAt = -999,
                lastAllyNearCount = 0,
                lastEnemyNearAt = -999,
                lastEnemyNearCount = 0,
                lastDiedAt = -999,
                lastDeathPos = nil,
                lastKillOrAssistAt = -999,
                wasWardingAt = -999,
                justDied = false,
                justGotKill = false,
            }
            state.track[h.id] = tr
        end

        tr.justDied = (tr.alive and not h.alive)
        tr.justGotKill = ((h.kills or 0) > (tr.kills or 0))
        if tr.justGotKill or (h.assists or 0) > (tr.assists or 0) then
            tr.lastKillOrAssistAt = now
        end

        if h.alive then
            tr.lastAlivePos = h.pos
            local aNear = 0
            for _, other in ipairs(heroes) do
                if other.id ~= h.id and other.alive and dist(other.pos, h.pos) <= 1950 then
                    aNear = aNear + 1
                end
            end
            local prevAllyAt = tr.lastAllyNearAt or -999
            if aNear > 0 then
                tr.lastAllyNearAt = now
                tr.lastAllyNearCount = math.max(aNear, (now - prevAllyAt <= 4) and tr.lastAllyNearCount or 0)
            elseif now - (tr.lastAllyNearAt or -999) > 6.5 then
                tr.lastAllyNearCount = 0
            end

            local prevEnemyAt = tr.lastEnemyNearAt or -999
            local eNear = countVisibleEnemiesNear(snapshot, h.pos, 1350)
            if eNear > 0 then
                tr.lastEnemyNearAt = now
                tr.lastEnemyNearCount = math.max(eNear, (now - prevEnemyAt <= 4) and tr.lastEnemyNearCount or 0)
            elseif now - (tr.lastEnemyNearAt or -999) > 5.0 then
                tr.lastEnemyNearCount = 0
            end

            if observerOrders and observerOrders[h.id] and not observerOrders[h.id].finished then
                tr.wasWardingAt = now
            end
        elseif tr.justDied then
            tr.lastDiedAt = now
            tr.lastDeathPos = tr.lastAlivePos or h.pos
        end

        tr.alive = h.alive
        tr.kills = h.kills or 0
        tr.deaths = h.deaths or 0
        tr.assists = h.assists or 0
    end
end

-- ============================================================================
-- ШАГ 2 (ПОСЛЕ MACRO.build): генерация правдивых коллов и диалогов
-- ============================================================================
function Comms.processEvents(snapshot, state, macro, threats, getBuildFn, COMBAT, STYLE, LANES)
    if STYLE.commsEnabled == false then return end
    local now = snapshot.time
    local heroes = snapshot.heroes or {}
    if #heroes == 0 or not macro then return end

    local dir = state.directive
    local sit = macro.situation
    local isDefending = (macro.phase == "DEFEND")
    local obsOnMap = countObsOnMap(snapshot)

    -- Вспомогательная проверка: умер ли кто-то ещё из союзников рядом в последние 10 сек
    local function otherAllyDiedNearby(victimId, deathPos)
        for id, tr in pairs(state.track) do
            if id ~= victimId and tr.lastDeathPos and (now - (tr.lastDiedAt or -999)) <= 10.0
                and dist(tr.lastDeathPos, deathPos) <= 2250 then
                return true
            end
        end
        return false
    end

    -- ------------------------------------------------------------------------
    -- 1. ОБРАБОТКА СМЕРТЕЙ: строгая проверка «соло-смерть vs тимфайт»
    -- ------------------------------------------------------------------------
    for _, h in ipairs(heroes) do
        local tr = state.track[h.id]
        if tr and tr.justDied and now > 25 then
            local deathPos = tr.lastDeathPos or h.pos
            local zone, physLane = Comms.resolveLocation(snapshot, deathPos)
            local zoneText = ZONE_ON[zone] or "там"

            -- Определяем, был ли это тимфайт / командная смерть
            local allyWasNear = (now - (tr.lastAllyNearAt or -999)) <= 6.5
            local allyDiedNear = otherAllyDiedNearby(h.id, deathPos)
            local contributedToFight = (now - (tr.lastKillOrAssistAt or -999)) <= 6.0
            local diedOnTeamObj = (zone == "own_base")
                or (macro.phase == "DEFEND" and macro.pos and dist(deathPos, macro.pos) <= 2000)
                or ((macro.phase == "ROSHAN" or macro.phase == "TORMENTOR") and macro.pos and dist(deathPos, macro.pos) <= 1800)
            local isTeamfightDeath = allyWasNear or allyDiedNear or contributedToFight or diedOnTeamObj

            local underOwnTower = nearOwnTower(snapshot, deathPos, 980)
            local wasWarding = (h.position >= 4) and ((now - (tr.wasWardingAt or -999)) <= 8.0)

            -- 1A. РУГАНЬ: СТРОГО только за чистую соло-смерть далеко от команды и вышек!
            local isTrueSoloDeath = (not isTeamfightDeath) and (not underOwnTower)
                and (not wasWarding) and (now >= 330)
            if isTrueSoloDeath and math.random() <= (STYLE.commsFlame or 0.75)
                and canTopic(state, now, "flame_" .. h.id, 60, false) then

                local deaths = h.deaths or 0
                local kills = h.kills or 0
                local assists = h.assists or 0
                local isCoreFeeder = (h.position <= 3 and deaths >= 3 and deaths >= kills + 2)
                local isSupFeeder = (h.position >= 4 and deaths >= 5 and (kills + assists * 0.5) < deaths)

                -- Ругается только ЖИВОЙ союзник, который сам умирает не больше жертвы
                local flamer = findAliveResponder(snapshot, h.id, function(a)
                    return (a.deaths or 0) <= deaths and a.position <= 3
                end) or findAliveResponder(snapshot, h.id, function(a)
                    return (a.deaths or 0) <= deaths
                end)

                if flamer then
                    markTopic(state, now, "flame_" .. h.id, 60)
                    local vName = heroLabel(h)
                    local flameText
                    if isCoreFeeder or isSupFeeder then
                        flameText = pick({
                            string.format("%s, ну куда ты опять один %s пошёл?! (%d смертей), держись команды!", vName, zoneText, deaths),
                            string.format("хватит в соло отлетать %s, %s! ты уже %d раз умер без нас", zoneText, vName, deaths),
                        })
                    else
                        flameText = pick({
                            string.format("ну как ты так умер, адун?! %s, зачем ты один %s зашёл?", vName, zoneText),
                            string.format("%s, ты карту смотришь? никого рядом нет, а ты %s гуляешь в соло", vName, zoneText),
                            string.format("боже, %s, зачем один %s полез без команды?!", vName, zoneText),
                        })
                    end
                    Comms.say(state, now, flamer, flameText, "flame", 0.6)

                    -- Ответ жертвы — ТОЛЬКО по реальным фактам!
                    local obsNearDeath = countObsOnMap(snapshot, deathPos, 2200)
                    local replies = {
                        "сорян, затупил, далеко зашёл один",
                        "моя ошибка, не успел отойти — больше в соло не полезу",
                        "ладно-ладно, щас буду держаться с вами",
                    }
                    if obsNearDeath == 0 and obsOnMap <= 1 and zone ~= "own_base" then
                        replies[#replies + 1] = "а где варды были?! там вообще темно было, я их не видел!"
                    end
                    if (tr.lastEnemyNearCount or 0) >= 2 then
                        replies[#replies + 1] = "да на меня там толпой вышли, я физически не мог уйти"
                    end
                    Comms.say(state, now, h, pick(replies), "reply", 2.2, true)
                end

            -- 1B. ПРОСЬБА ПОМОЧЬ НА ЛИНИИ после смерти на лайнинге (НЕ после командной драки!)
            elseif now >= 180 and now <= 660 and macro.phase == "LANING"
                and h.position <= 3 and physLane ~= nil
                and (tr.lastAllyNearCount or 0) <= 1 and (not allyDiedNear)
                and (h.deaths or 0) >= 2
                and canTopic(state, now, "gank_" .. physLane, 75, false) then

                local lanePos = LANES[physLane] or deathPos
                local enemiesOnLane = countVisibleEnemiesNear(snapshot, lanePos, 1800)
                if enemiesOnLane >= 1 then
                    local ganker = findAliveResponder(snapshot, h.id, function(a)
                        local _, aLane = Comms.resolveLocation(snapshot, a.pos)
                        return (a.position == 4 or (a.position == 2 and (a.level or 1) >= 6))
                            and aLane ~= physLane
                            and ratio(a.hp, a.maxHp) >= 0.72 and ratio(a.mana, a.maxMana) >= 0.35
                            and (dist(a.pos, lanePos) <= 3800 or hasReadyTp(a))
                    end)
                    if ganker then
                        markTopic(state, now, "gank_" .. physLane, 75)
                        Comms.say(state, now, h, pick({
                            string.format("на %s тяжело стоять, зайдите на ганг когда я реснусь!", LANE_ON[physLane]),
                            string.format("меня на %s переезжают, помогите сместитесь туда!", LANE_ON[physLane]),
                        }), "call", 0.8, true)
                        Comms.say(state, now, ganker, pick({
                            string.format("понял, щас зайду на %s", LANE_TO[physLane]),
                            string.format("принял, выдвигаюсь на %s помогать", LANE_TO[physLane]),
                        }), "reply", 2.2)
                        state.directive = {
                            kind = "HELP_GANK",
                            callerId = h.id,
                            lane = physLane,
                            pos = lanePos,
                            assignedIds = { [ganker.id] = true },
                            label = "GANK CALL -> " .. string.upper(physLane),
                            expiresAt = now + 22,
                        }
                        dir = state.directive
                    end
                end
            end
        end

        -- 1C. ПОХВАЛА за килл (только если убийца выжил и рядом был живой союзник)
        if tr and tr.justGotKill and h.alive and ratio(h.hp, h.maxHp) >= 0.25 and now > 90
            and canTopic(state, now, "praise_global", 80, false) and math.random() < 0.30 then
            local ally = findAliveResponder(snapshot, h.id, function(a)
                return dist(a.pos, h.pos) <= 1650
            end)
            if ally then
                markTopic(state, now, "praise_global", 80)
                local lines = {
                    string.format("красава, %s! чёткий фраг", heroLabel(h)),
                    "хорош! отлично сработали",
                }
                if not isDefending and (((snapshot.scoreboard and snapshot.scoreboard.allyDeadCount) or 0) == 0) then
                    lines[#lines + 1] = "найс килл, можно поддавить пока он в таверне"
                end
                Comms.say(state, now, ally, pick(lines), "praise", 0.9)
            end
        end
    end

    -- ------------------------------------------------------------------------
    -- 2. ПРОСЬБА О ПОМОЩИ ОТ ЖИВОГО КОРА НА ЛИНИИ (строго по реальной линии!)
    -- ------------------------------------------------------------------------
    if now >= 180 and now <= 660 and macro.phase == "LANING" and not dir then
        for _, h in ipairs(heroes) do
            if h.alive and h.position <= 3 and ratio(h.hp, h.maxHp) < 0.50 then
                local _, physLane = Comms.resolveLocation(snapshot, h.pos)
                if physLane and canTopic(state, now, "hardlane_" .. physLane, 80, false) then
                    local eNear = countVisibleEnemiesNear(snapshot, h.pos, 1150)
                    local aNear = 0
                    for _, other in ipairs(heroes) do
                        if other.id ~= h.id and other.alive and dist(other.pos, h.pos) <= 1500 then
                            aNear = aNear + 1
                        end
                    end
                    -- Действительно численный перевес врагов на ЭТОЙ линии (например 1v2 или 2v3)
                    if eNear >= 2 and eNear > aNear + 1 then
                        local ganker = findAliveResponder(snapshot, h.id, function(a)
                            local _, aLane = Comms.resolveLocation(snapshot, a.pos)
                            return (a.position == 4 or (a.position == 2 and (a.level or 1) >= 6))
                                and aLane ~= physLane
                                and ratio(a.hp, a.maxHp) >= 0.72 and ratio(a.mana, a.maxMana) >= 0.35
                                and (dist(a.pos, h.pos) <= 3800 or hasReadyTp(a))
                        end)
                        if ganker then
                            markTopic(state, now, "hardlane_" .. physLane, 80)
                            Comms.say(state, now, h, pick({
                                string.format("на %s меня в %d лица жмут, помогите придите на ганг!", LANE_ON[physLane], eNear),
                                string.format("ребят, на %s очень тяжело (%d врага), сместитесь кто-нибудь!", LANE_ON[physLane], eNear),
                            }), "call", 0)
                            Comms.say(state, now, ganker, pick({
                                string.format("уже иду на %s, не умирай до меня!", LANE_TO[physLane]),
                                string.format("принял, бегу на %s помогать", LANE_TO[physLane]),
                            }), "reply", 1.7)
                            state.directive = {
                                kind = "HELP_GANK",
                                callerId = h.id,
                                lane = physLane,
                                pos = h.pos,
                                assignedIds = { [ganker.id] = true },
                                label = "HELP " .. string.upper(physLane),
                                expiresAt = now + 22,
                            }
                            dir = state.directive
                            break
                        end
                    end
                end
            end
        end
    end

    -- ------------------------------------------------------------------------
    -- 3. ТАЙМИНГ КЛЮЧЕВОГО ПРЕДМЕТА (100% точная голда / реальный курьер)
    -- ------------------------------------------------------------------------
    if now >= 360 and not isDefending and (not sit or (sit.enemyDead or 0) < 2)
        and (not dir or dir.kind == "NEED_WARDS") then
        for _, h in ipairs(heroes) do
            if h.alive and h.position <= 3 and countVisibleEnemiesNear(snapshot, h.pos, 1050) == 0 then
                local build = getBuildFn(h, threats, snapshot)
                local timing = inspectKeyItemTiming(snapshot, h, build)
                if timing and canTopic(state, now, "item_" .. h.id .. "_" .. timing.item, 55, false) then
                    markTopic(state, now, "item_" .. h.id .. "_" .. timing.item, 55)
                    if timing.mode == "COURIER" then
                        Comms.say(state, now, h, pick({
                            string.format("ребят, мне %s курьер везёт (~%d сек), давайте чуть подождём и пойдём драться!", timing.label, timing.eta),
                            string.format("не лезьте пару секунд, %s уже летит в курьере — прилетит и заходим!", timing.label),
                        }), "call", 0)
                    else
                        Comms.say(state, now, h, pick({
                            string.format("у меня %d голды до %s, давайте чуть пофармим, прилетит и пойдём в драку", timing.goldNeeded, timing.label),
                            string.format("не форсите файт! мне %d голды до %s осталось, дофармлю и идём", timing.goldNeeded, timing.label),
                        }), "call", 0)
                    end

                    local ally = findAliveResponder(snapshot, h.id)
                    if ally then
                        Comms.say(state, now, ally, pick({
                            string.format("ок, ждём твой %s, пока спокойно пофармим", timing.label),
                            "принял, не лезу, пингуй как прилетит",
                        }), "reply", 1.8)
                    end

                    state.directive = {
                        kind = "WAIT_ITEM",
                        callerId = h.id,
                        item = timing.item,
                        itemLabel = timing.label,
                        label = "WAIT " .. timing.label .. " (" .. heroLabel(h) .. ")",
                        expiresAt = now + (timing.mode == "COURIER" and 16 or 28),
                    }
                    dir = state.directive
                    break
                end
            end
        end
    end

    -- ------------------------------------------------------------------------
    -- 4. КД УЛЬТИМЕЙТОВ («у меня ульт в КД — давайте пофармим»)
    -- ------------------------------------------------------------------------
    if now >= 480 and not isDefending and not dir
        and (not sit or (sit.enemyDead or 0) < 2)
        and COMBAT and COMBAT.teamFightReadiness then
        local ready = COMBAT.teamFightReadiness(snapshot)
        if ready.ultsMissing and ready.minUltCd >= 25 and canTopic(state, now, "ult_cd", 60, false) then
            local caller
            for _, h in ipairs(heroes) do
                if h.alive and countVisibleEnemiesNear(snapshot, h.pos, 1100) == 0 then
                    local r = COMBAT.heroCombatReadiness(h)
                    if r.hasActiveUlt and not r.ultReady and r.ultCd >= 25 then
                        caller = h; break
                    end
                end
            end
            if caller then
                markTopic(state, now, "ult_cd", 60)
                local sec = math.ceil(ready.minUltCd)
                Comms.say(state, now, caller, pick({
                    string.format("у меня ульт в кд ещё %d сек, давайте пока пофармим", sec),
                    string.format("парни, у нас ультов нет (%d сек кд) — не деритесь, фармим!", sec),
                }), "call", 0)
                local ally = findAliveResponder(snapshot, caller.id)
                if ally then
                    Comms.say(state, now, ally, pick({
                        "окей, пока лес и линии побью",
                        "понял, играем аккуратно до отката",
                    }), "reply", 1.8)
                end
                state.directive = {
                    kind = "WAIT_ULT",
                    callerId = caller.id,
                    label = string.format("FARM: WAIT ULT (%ds)", sec),
                    expiresAt = now + math.min(26, sec),
                }
                dir = state.directive
            end
        end
    end

    -- 4B. КОЛЛ ПО СВОЕЙ МАНЕ (если ключевой герой сухой и не может жать кнопки)
    if now >= 300 and not isDefending and not dir and COMBAT and COMBAT.heroCombatReadiness then
        for _, h in ipairs(heroes) do
            if h.alive and (h.maxMana or 0) >= 250 then
                local r = COMBAT.heroCombatReadiness(h)
                if (r.isOom or r.ultNeedsManaOnly) and not h.hasClarity
                    and countVisibleEnemiesNear(snapshot, h.pos, 950) == 0
                    and canTopic(state, now, "oom_" .. h.id, 70, false) then
                    local arcaner = findAliveResponder(snapshot, h.id, function(a)
                        for slot = 0, 5 do
                            local it = (a.items or {})[slot]
                            if (it == "item_arcane_boots" or it == "item_guardian_greaves")
                                and ((a.itemCooldown or {})[slot] or 0) <= 2
                                and dist(a.pos, h.pos) <= 1800 then
                                return true
                            end
                        end
                        return false
                    end)
                    markTopic(state, now, "oom_" .. h.id, 70)
                    if arcaner then
                        Comms.say(state, now, h, string.format("маны вообще ноль (%d/%d), залей арканы пожалуйста!",
                            math.floor(h.mana or 0), math.floor(h.maxMana or 0)), "call", 0)
                        Comms.say(state, now, arcaner, "щас подойду, залью ману!", "reply", 1.5)
                    else
                        Comms.say(state, now, h, string.format("у меня нет маны на кнопки (%d/%d), дайте порегениться перед дракой",
                            math.floor(h.mana or 0), math.floor(h.maxMana or 0)), "call", 0)
                    end
                    break
                end
            end
        end
    end

    -- 4C. КОЛЛ ПО ВРАГУ БЕЗ МАНЫ (когда рядом со стычкой виден сухой враг)
    if now >= 240 and COMBAT and COMBAT.analyzeEnemyMana and canTopic(state, now, "enemy_oom", 65, false) then
        for _, e in ipairs(snapshot.enemies or {}) do
            if e.kind == "hero" and not e.isIllusion and e.alive ~= false then
                local em = COMBAT.analyzeEnemyMana(e)
                if em.noEscapeMana or em.isMedusaLow or (em.isOom and (e.maxMana or 0) >= 350) then
                    local caller = findAliveResponder(snapshot, -1, function(a)
                        return dist(a.pos, e.pos) <= 1250 and ratio(a.hp, a.maxHp) >= 0.50
                    end)
                    if caller then
                        markTopic(state, now, "enemy_oom", 65)
                        local eName = heroLabel(e)
                        local text = em.noEscapeMana
                            and string.format("у %s нет маны на эскейп (%d), душим его!", eName, math.floor(e.mana or 0))
                            or string.format("у %s вообще нет маны (%d), можно смело давить!", eName, math.floor(e.mana or 0))
                        Comms.say(state, now, caller, text, "call", 0)
                        break
                    end
                end
            end
        end
    end

    -- ------------------------------------------------------------------------
    -- 5. ПРОСЬБА О ВАРДАХ (проверяем, есть ли обсы у саппортов на самом деле!)
    -- ------------------------------------------------------------------------
    if now >= 210 and not isDefending and obsOnMap == 0
        and canTopic(state, now, "need_wards", 85, false) then
        local core = findAliveResponder(snapshot, -1, function(a) return a.position <= 3 end)
        local supWithObs = findAliveResponder(snapshot, -1, function(a)
            return a.position >= 4 and countObsInAllSlots(a) > 0
                and countVisibleEnemiesNear(snapshot, a.pos, 900) == 0
        end)
        if core and supWithObs then
            markTopic(state, now, "need_wards", 85)
            Comms.say(state, now, core, pick({
                "саппорты, на карте 0 вардов, поставьте обсы пожалуйста!",
                "карта вообще чёрная, расставьте вижен!",
            }), "call", 0)
            Comms.say(state, now, supWithObs, pick({
                "понял, у меня есть обс — уже иду ставить!",
                "принял, щас поставлю вижен, не подставляйся пока",
            }), "reply", 1.7)
            if not dir then
                state.directive = {
                    kind = "NEED_WARDS",
                    callerId = core.id,
                    assignedWardId = supWithObs.id,
                    expiresAt = now + 20,
                }
                dir = state.directive
            else
                dir.forceWard = true
            end
        elseif core then
            -- Ни у одного живого саппорта нет обса в руках -> честный ответ вместо вранья
            local anySup = findAliveResponder(snapshot, -1, function(a) return a.position >= 4 end)
            if anySup and now >= 300 then
                markTopic(state, now, "need_wards", 95)
                Comms.say(state, now, core, "саппорты, нужен вижен на карте, обсов вообще нет!", "call", 0)
                Comms.say(state, now, anySup, "обсов пока нет в инвентаре, как появятся — сразу привезу и поставлю", "reply", 1.8)
            end
        end
    end

    -- ------------------------------------------------------------------------
    -- 6. КОЛЛ НА РОШАНА (говорят только те, кто реально идёт в рошпит!)
    -- ------------------------------------------------------------------------
    if macro.phase == "ROSHAN" and macro.pos and canTopic(state, now, "call_roshan", 70, true) then
        local rRange = macro.rallyRange or 3400
        local caller = findAliveResponder(snapshot, -1, function(a)
            return a.position <= 3 and dist(a.pos, macro.pos) <= rRange
        end) or findAliveResponder(snapshot, -1, function(a)
            return dist(a.pos, macro.pos) <= rRange
        end)
        if caller then
            markTopic(state, now, "call_roshan", 70)
            Comms.say(state, now, caller, pick({
                "давай соберёмся вместе и заберём Рошана!",
                "ребят, го в рошпит, забираем Рошана пока есть окно!",
            }), "call", 0)
            local ally = findAliveResponder(snapshot, caller.id, function(a)
                return dist(a.pos, macro.pos) <= rRange
            end)
            if ally then
                Comms.say(state, now, ally, pick({
                    "уже иду на Рошана!",
                    "бегу, прикрою вход в рошпит",
                }), "reply", 1.5)
            end
        end
    end
end

-- ============================================================================
-- ШАГ 3: выпуск созревших сообщений (отменяем ложные ответы, если герой умер)
-- ============================================================================
function Comms.flushChat(snapshot, state)
    local now = snapshot.time
    local aliveById = {}
    for _, h in ipairs(snapshot.heroes or {}) do
        aliveById[h.id] = h.alive
    end

    local remaining = {}
    for _, msg in ipairs(state.queue) do
        if now >= (msg.sendAt or 0) then
            if msg.allowDead or aliveById[msg.heroId] then
                state.outbox[#state.outbox + 1] = msg
            end
        else
            remaining[#remaining + 1] = msg
        end
    end
    state.queue = remaining

    if #state.outbox == 0 then return nil end
    local emitted = state.outbox
    state.outbox = {}
    return emitted
end

return Comms
