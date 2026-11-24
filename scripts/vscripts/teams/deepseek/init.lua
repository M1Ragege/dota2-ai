-- ===========================================================================
--  DOTA 2 CUSTOM BOT AI  --  TEAM "DeepSeek Flash"
--  Self-contained Lua 5.1 module for a 7.42 custom server bot engine.
--  No external modules, no placeholders: full draft, laning, fighting, macro play.
--
--  STRATEGY
--    Draft  : teamfight + push composition, picked by position with counters
--             POS1 Juggernaut (Luna/Sven)   -- safe-lane carry, spin-TP escape
--             POS2 Death Prophet (Puck/Lesh) -- mid, Exorcism push timing
--             POS3 Tidehunter (Axe/Centaur)  -- offlane initiator, Ravage setup
--             POS4 Lion (Earthshaker/Shaman) -- roaming stun/hex, blink setup
--             POS5 Crystal Maiden (Ogre/Shaman)-- babysit carry, vision, roots
--    Lanes  : default 2-1-2 (the engine maps safe/off lanes per side)
--    Style  : fight for the first bounty runes, win lanes with spell damage,
--             group after every kill window, take towers, Roshan and Tormentor,
--             then close the game with creeps in front of the high ground.
--
--  EVERYTHING below is organised as data (item values, hero builds, spell
--  rules) plus small behaviour functions.  All team memory lives in V/Team,
--  every snapshot field is nil-guarded, and DecideTeam is pcall-protected.
-- ===========================================================================

local Team = {}
local U = {}
local D = {}
local V = {}

Team.name = "DeepSeek Flash"
Team.version = 3

-- ===========================================================================
--  PART 1. PRIMITIVES
-- ===========================================================================

function U.num(v, d)
    if type(v) == "number" then return v end
    return d
end

function U.str(v, d)
    if type(v) == "string" then return v end
    return d
end

function U.tbl(v)
    if type(v) == "table" then return v end
    return {}
end

function U.clamp(v, lo, hi)
    v = U.num(v, 0)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function U.max(a, b)
    if U.num(a, 0) >= U.num(b, 0) then return U.num(a, 0) end
    return U.num(b, 0)
end

function U.min(a, b)
    if U.num(a, 0) <= U.num(b, 0) then return U.num(a, 0) end
    return U.num(b, 0)
end

function U.contains(arr, value)
    if type(arr) ~= "table" then return false end
    for i = 1, #arr do
        if arr[i] == value then return true end
    end
    return false
end

-- snapshot collections may arrive as arrays or as id-keyed dictionaries
function U.asArray(t)
    if type(t) ~= "table" then return {} end
    if #t > 0 then return t end
    local out = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            out[#out + 1] = v
        end
    end
    return out
end

-- ===========================================================================
--  PART 2. GEOMETRY
-- ===========================================================================

function U.coord(p, k)
    if type(p) ~= "table" then return 0 end
    local v = p[k]
    if type(v) == "number" then return v end
    if k == "x" then
        v = p[1]
    elseif k == "y" then
        v = p[2]
    else
        v = p[3]
    end
    if type(v) == "number" then return v end
    return 0
end

function U.pos(x, y, z)
    return { x = U.num(x, 0), y = U.num(y, 0), z = U.num(z, 0) }
end

function U.copyPos(p)
    if type(p) ~= "table" then return nil end
    return U.pos(U.coord(p, "x"), U.coord(p, "y"), U.coord(p, "z"))
end

function U.unitPos(u)
    if type(u) ~= "table" then return nil end
    if type(u.pos) == "table" then return u.pos end
    return nil
end

function U.dist(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return 999999 end
    local dx = U.coord(a, "x") - U.coord(b, "x")
    local dy = U.coord(a, "y") - U.coord(b, "y")
    local dz = U.coord(a, "z") - U.coord(b, "z")
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function U.dist2d(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return 999999 end
    local dx = U.coord(a, "x") - U.coord(b, "x")
    local dy = U.coord(a, "y") - U.coord(b, "y")
    return math.sqrt(dx * dx + dy * dy)
end

function U.mid(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return nil end
    return U.pos((U.coord(a, "x") + U.coord(b, "x")) / 2,
                 (U.coord(a, "y") + U.coord(b, "y")) / 2,
                 (U.coord(a, "z") + U.coord(b, "z")) / 2)
end

function U.toward(from, to, step)
    if type(from) ~= "table" or type(to) ~= "table" then return nil end
    local dx = U.coord(to, "x") - U.coord(from, "x")
    local dy = U.coord(to, "y") - U.coord(from, "y")
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 1 then return U.copyPos(to) end
    local s = U.clamp(U.num(step, 0), 0, d)
    return U.pos(U.coord(from, "x") + dx / d * s,
                 U.coord(from, "y") + dy / d * s,
                 U.coord(from, "z"))
end

function U.pointAway(from, threat, step)
    if type(from) ~= "table" or type(threat) ~= "table" then return nil end
    local dx = U.coord(from, "x") - U.coord(threat, "x")
    local dy = U.coord(from, "y") - U.coord(threat, "y")
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 1 then return nil end
    return U.pos(U.coord(from, "x") + dx / d * step,
                 U.coord(from, "y") + dy / d * step,
                 U.coord(threat, "z"))
end

-- ===========================================================================
--  PART 3. UNIT ACCESSORS
-- ===========================================================================

function U.hp(u)
    if type(u) ~= "table" then return 0 end
    return U.num(u.hp, 0)
end

function U.maxHp(u)
    if type(u) ~= "table" then return 0 end
    return U.num(u.maxHp, 0)
end

function U.hpPct(u)
    local m = U.maxHp(u)
    if m <= 0 then return 0 end
    return U.hp(u) / m * 100
end

function U.mana(u)
    if type(u) ~= "table" then return 0 end
    return U.num(u.mana, 0)
end

function U.maxMana(u)
    if type(u) ~= "table" then return 0 end
    return U.num(u.maxMana, 0)
end

function U.manaPct(u)
    local m = U.maxMana(u)
    if m <= 0 then return 100 end
    return U.mana(u) / m * 100
end

function U.alive(u)
    if type(u) ~= "table" then return false end
    if u.alive == false then return false end
    if U.hp(u) <= 0 and type(u.hp) == "number" then return false end
    return true
end

function U.unitLevel(u)
    return U.num(type(u) == "table" and u.level or nil, 1)
end

function U.kind(u)
    return U.str(type(u) == "table" and u.kind or nil, "")
end

function U.isKind(u, k)
    return U.kind(u) == k
end

function U.isBuilding(u)
    local k = U.kind(u)
    return k == "tower" or k == "barracks" or k == "ancient" or k == "building"
end

function U.isTower(u)
    return U.kind(u) == "tower"
end

function U.isWard(u)
    local k = U.kind(u)
    return k == "observer_ward" or k == "sentry_ward"
end

function U.isRealHero(u)
    if type(u) ~= "table" then return false end
    if U.kind(u) ~= "hero" then return false end
    if u.isIllusion == true then return false end
    return true
end

function U.isCreep(u)
    local k = U.kind(u)
    return k == "lane_creep" or k == "siege_creep" or k == "unit"
end

function U.isStunned(u)
    if type(u) ~= "table" then return false end
    return u.stunned == true or u.hexed == true
end

function U.isPhysicalDisabled(u)
    if type(u) ~= "table" then return false end
    return u.stunned == true or u.hexed == true or u.disarmed == true
end

function U.canAct(u)
    if not U.alive(u) then return false end
    if U.isStunned(u) then return false end
    return true
end

function U.canMoveUnit(u)
    if not U.canAct(u) then return false end
    if type(u) == "table" and u.rooted == true then return false end
    return true
end

-- ---------------------------------------------------------------------------
--  ITEMS
-- ---------------------------------------------------------------------------

function U.items(u)
    if type(u) ~= "table" then return {} end
    return U.tbl(u.items)
end

function U.itemAt(u, slot)
    local it = U.items(u)
    local v = it[slot]
    if type(v) == "string" and v ~= "" then return v end
    return nil
end

function U.charges(u, name)
    local slot = U.itemSlot(u, name, 0, 5)
    if not slot then return 0 end
    local ch = U.tbl(u.itemCharges)
    return U.num(ch[slot], 1)
end

function U.itemSlot(u, name, lo, hi)
    if type(u) ~= "table" or type(name) ~= "string" then return nil end
    lo = U.num(lo, 0)
    hi = U.num(hi, 16)
    local it = U.items(u)
    for s = lo, hi do
        if it[s] == name then return s end
    end
    return nil
end

function U.hasItem(u, name)
    return U.itemSlot(u, name, 0, 16) ~= nil
end

function U.hasActiveItem(u, name)
    return U.itemSlot(u, name, 0, 5) ~= nil
end

function U.itemReady(u, name)
    local slot = U.itemSlot(u, name, 0, 5)
    if not slot then return false end
    local cd = U.tbl(u.itemCooldown)
    if U.num(cd[slot], 0) > 0.05 then return false end
    return true
end

-- ---------------------------------------------------------------------------
--  ABILITIES
-- ---------------------------------------------------------------------------

function U.abil(hero, name)
    if type(hero) ~= "table" or type(name) ~= "string" then return nil end
    local ab = U.tbl(hero.abilities)
    for k, a in pairs(ab) do
        if type(a) == "table" and a.name == name then
            return a, k
        end
    end
    return nil
end

function U.abilLevel(hero, name)
    local a = U.abil(hero, name)
    if type(a) ~= "table" then return 0 end
    return U.num(a.level, 0)
end

function U.abilReady(hero, name)
    local a = U.abil(hero, name)
    if type(a) ~= "table" then return false end
    if U.num(a.level, 0) <= 0 then return false end
    if a.passive == true or a.hidden == true then return false end
    if U.num(a.cooldown, 0) > 0.05 then return false end
    if U.num(a.manaCost, 0) > U.mana(hero) then return false end
    return true
end

function U.abilRange(hero, name, def)
    local a = U.abil(hero, name)
    if type(a) ~= "table" then return U.num(def, 0) end
    local r = U.num(a.castRange, 0)
    if r <= 0 then r = U.num(def, 0) end
    return r
end

-- ===========================================================================
--  PART 4. ACTION BUILDERS
-- ===========================================================================

function U.move(pos, status)
    local p = U.copyPos(pos)
    if not p then return nil end
    return { kind = "move", position = p, status = status or "move" }
end

function U.attackMove(pos, status)
    local p = U.copyPos(pos)
    if not p then return nil end
    return { kind = "attack_move", position = p, status = status or "push" }
end

function U.attack(id, status)
    if id == nil then return nil end
    return { kind = "attack", target_id = id, status = status or "attack" }
end

function U.deny(id, status)
    if id == nil then return nil end
    return { kind = "deny", target_id = id, status = status or "deny" }
end

function U.deaggro(id, status)
    local a = { kind = "deaggro", status = status or "deaggro" }
    if id ~= nil then a.target_id = id end
    return a
end

function U.cast(abil, targetId, pos, status)
    local a = { kind = "cast", ability = abil, status = status or ("cast " .. tostring(abil)) }
    if targetId ~= nil then
        a.target_id = targetId
    elseif pos ~= nil then
        a.position = U.copyPos(pos)
    end
    return a
end

function U.buy(item)
    return { kind = "buy", item = item, status = "buy" }
end

function U.learn(ability)
    return { kind = "learn", ability = ability, status = "learn" }
end

function U.swap(a, b)
    return { kind = "swap", slot_a = a, slot_b = b, status = "swap" }
end

function U.sellSlot(slot)
    return { kind = "sell", slot = slot, status = "sell" }
end

function U.sellItem(item)
    return { kind = "sell", item = item, status = "sell" }
end

function U.dropSlot(slot)
    return { kind = "drop", slot = slot, status = "drop" }
end

function U.tp(pos, status)
    local p = U.copyPos(pos)
    if not p then return nil end
    return { kind = "tp", position = p, status = status or "tp" }
end

function U.rune(id, status)
    return { kind = "rune", target_id = id, status = status or "rune" }
end

function U.pickup(id, status)
    return { kind = "pickup", target_id = id, status = status or "pickup" }
end

function U.lotus(pos, status)
    local p = U.copyPos(pos)
    if not p then return nil end
    return { kind = "lotus", position = p, status = status or "lotus" }
end

function U.shrine(pos, status)
    local p = U.copyPos(pos)
    if not p then return nil end
    return { kind = "shrine", position = p, status = status or "shrine" }
end

function U.gate(targetId, pos, status)
    local a = { kind = "gate", status = status or "gate" }
    if targetId ~= nil then a.target_id = targetId end
    if pos ~= nil then a.position = U.copyPos(pos) end
    return a
end

function U.wardFocus(id, status)
    local a = { kind = "ward_focus", status = status or "deward" }
    if id ~= nil then a.target_id = id end
    return a
end

function U.smoke()
    return { kind = "smoke", status = "smoke" }
end

function U.glyph()
    return { kind = "glyph", status = "glyph" }
end

function U.buyback()
    return { kind = "buyback", status = "buyback" }
end

function U.hold(status)
    return { kind = "hold", status = status or "hold" }
end

function U.autocast(abil)
    return { kind = "autocast", ability = abil, status = "autocast" }
end

-- ===========================================================================
--  PART 5. CONSTANTS
-- ===========================================================================

U.TOWER_RANGE = 700          -- tower attack range
U.TOWER_SAFE = 860           -- safe distance from an enemy tower
U.TOWER_AGGRO_HERO = 500     -- hero auto-attack range that pulls tower aggro
U.FOUNTAIN_SAFE = 900        -- "at base" radius
U.CREEP_SAFE = 180           -- how far behind our creeps we stand

-- ===========================================================================
--  PART 6. ITEM KNOWLEDGE
-- ===========================================================================

D.ITEM_VALUE = {
    ["item_tango"] = 90, ["item_branches"] = 50, ["item_faerie_fire"] = 70,
    ["item_enchanted_mango"] = 70, ["item_clarity"] = 50, ["item_flask"] = 110,
    ["item_quelling_blade"] = 130, ["item_magic_stick"] = 200, ["item_magic_wand"] = 450,
    ["item_wind_lace"] = 250, ["item_circlet"] = 155, ["item_slippers"] = 150,
    ["item_gauntlets"] = 150, ["item_mantle"] = 140, ["item_ring_of_protection"] = 175,
    ["item_stout_shield"] = 200, ["item_boots"] = 500, ["item_phase_boots"] = 1500,
    ["item_power_treads"] = 1400, ["item_arcane_boots"] = 1400, ["item_tranquil_boots"] = 925,
    ["item_guardian_greaves"] = 4950, ["item_travel_boots"] = 2500, ["item_travel_boots_2"] = 4500,
    ["item_soul_ring"] = 775, ["item_bottle"] = 675, ["item_hand_of_midas"] = 2200,
    ["item_bfury"] = 4100, ["item_manta"] = 4750, ["item_black_king_bar"] = 4050,
    ["item_abyssal_blade"] = 6400, ["item_butterfly"] = 4975, ["item_satanic"] = 5050,
    ["item_skadi"] = 5300, ["item_heart"] = 5000, ["item_assault"] = 5250,
    ["item_shivas_guard"] = 4850, ["item_sheepstick"] = 5675, ["item_orchid"] = 3275,
    ["item_bloodthorn"] = 6475, ["item_cyclone"] = 2725, ["item_wind_waker"] = 6825,
    ["item_force_staff"] = 2200, ["item_glimmer_cape"] = 2150, ["item_ghost"] = 1500,
    ["item_blink"] = 2250, ["item_blade_mail"] = 2100, ["item_pipe"] = 3475,
    ["item_crimson_guard"] = 3700, ["item_mekansm"] = 1875, ["item_lotus_orb"] = 3850,
    ["item_solar_crest"] = 2725, ["item_heavens_halberd"] = 3975, ["item_monkey_king_bar"] = 4700,
    ["item_desolator"] = 3500, ["item_daedalus"] = 5150, ["item_mjollnir"] = 5600,
    ["item_radiance"] = 4700, ["item_armlet"] = 2500, ["item_echo_sabre"] = 2500,
    ["item_sange_and_yasha"] = 4100, ["item_kaya_and_sange"] = 4100, ["item_yasha_and_kaya"] = 4100,
    ["item_ultimate_scepter"] = 4200, ["item_aghanims_shard"] = 1400, ["item_refresher"] = 5000,
    ["item_octarine_core"] = 5000, ["item_spirit_vessel"] = 2975, ["item_urn_of_shadows"] = 840,
    ["item_ring_of_basilius"] = 425, ["item_ring_of_aquila"] = 1000, ["item_vladmir"] = 2400,
    ["item_drum_of_endurance"] = 1650, ["item_helm_of_the_dominator"] = 2575,
    ["item_hurricane_pike"] = 4300, ["item_null_talisman"] = 480, ["item_wraith_band"] = 500,
    ["item_bracer"] = 500, ["item_soul_booster"] = 3000, ["item_vanguard"] = 1700,
    ["item_blade_of_alacrity"] = 1000, ["item_ogre_axe"] = 1000, ["item_staff_of_wizardry"] = 1000,
    ["item_ultimate_orb"] = 2100, ["item_energy_booster"] = 800, ["item_void_stone"] = 825,
    ["item_mystic_staff"] = 1000, ["item_reaver"] = 2800, ["item_eaglesong"] = 2800,
    ["item_hyperstone"] = 2000, ["item_demon_edge"] = 2200, ["item_platemail"] = 1400,
    ["item_chainmail"] = 550, ["item_blades_of_attack"] = 450, ["item_broadsword"] = 1200,
    ["item_claymore"] = 1350, ["item_mithril_hammer"] = 1600, ["item_quarterstaff"] = 875,
    ["item_gloves"] = 500, ["item_robe"] = 450, ["item_sobi_mask"] = 325,
    ["item_ring_of_regen"] = 175, ["item_headdress"] = 425, ["item_buckler"] = 425,
    ["item_tpscroll"] = 100, ["item_ward_observer"] = 0, ["item_ward_sentry"] = 0,
    ["item_ward_dispenser"] = 0, ["item_dust"] = 80, ["item_smoke_of_deceit"] = 50,
    ["item_gem"] = 900, ["item_aegis"] = 0, ["item_cheese"] = 0, ["item_refresher_shard"] = 0,
    ["item_horn_of_battle_greater"] = 0, ["item_famango"] = 0, ["item_great_famango"] = 0,
    ["item_greater_famango"] = 0, ["item_roshans_banner"] = 0, ["item_ultimate_scepter_roshan"] = 0,
    ["item_tombstone"] = 0, ["item_necronomicon"] = 2400,
}
D.ITEM_VALUE_DEFAULT = 600

-- Items that are never worth keeping once better gear appears (only sold/dropped
-- while safely at the shop, never from the main build path).
D.TRASH = {
    ["item_tango"] = true, ["item_quelling_blade"] = true, ["item_faerie_fire"] = true,
    ["item_branches"] = true, ["item_clarity"] = true, ["item_flask"] = true,
    ["item_enchanted_mango"] = true, ["item_wind_lace"] = true, ["item_circlet"] = true,
    ["item_slippers"] = true, ["item_gauntlets"] = true, ["item_mantle"] = true,
    ["item_ring_of_protection"] = true, ["item_stout_shield"] = true, ["item_sobi_mask"] = true,
    ["item_ring_of_regen"] = true, ["item_ring_of_basilius"] = true, ["item_null_talisman"] = true,
    ["item_bracer"] = true, ["item_wraith_band"] = true, ["item_urn_of_shadows"] = true,
    ["item_gloves"] = true, ["item_chainmail"] = true, ["item_robe"] = true,
    ["item_blades_of_attack"] = true, ["item_buckler"] = true,
}
-- Never sell/drop these, whatever happens.
D.KEEP = {
    ["item_magic_stick"] = true, ["item_magic_wand"] = true, ["item_boots"] = true,
    ["item_phase_boots"] = true, ["item_power_treads"] = true, ["item_arcane_boots"] = true,
    ["item_tranquil_boots"] = true, ["item_travel_boots"] = true, ["item_travel_boots_2"] = true,
    ["item_soul_ring"] = true, ["item_bottle"] = true, ["item_ward_observer"] = true,
    ["item_ward_sentry"] = true, ["item_ward_dispenser"] = true, ["item_dust"] = true,
    ["item_gem"] = true, ["item_tpscroll"] = true, ["item_aegis"] = true, ["item_cheese"] = true,
    ["item_refresher_shard"] = true, ["item_aghanims_shard"] = true,
    ["item_ultimate_scepter"] = true, ["item_ultimate_scepter_roshan"] = true,
    ["item_famango"] = true, ["item_great_famango"] = true, ["item_greater_famango"] = true,
    ["item_horn_of_battle_greater"] = true, ["item_roshans_banner"] = true, ["item_smoke_of_deceit"] = true,
}

D.INVIS_HEROES = {
    ["npc_dota_hero_riki"] = true, ["npc_dota_hero_bounty_hunter"] = true,
    ["npc_dota_hero_clinkz"] = true, ["npc_dota_hero_nyx_assassin"] = true,
    ["npc_dota_hero_weaver"] = true, ["npc_dota_hero_invoker"] = true,
    ["npc_dota_hero_mirana"] = true, ["npc_dota_hero_sand_king"] = true,
    ["npc_dota_hero_slark"] = true, ["npc_dota_hero_treant"] = true,
    ["npc_dota_hero_hoodwink"] = true, ["npc_dota_hero_templar_assassin"] = true,
    ["npc_dota_hero_broodmother"] = true, ["npc_dota_hero_phantom_lancer"] = true,
    ["npc_dota_hero_meepo"] = true, ["npc_dota_hero_snapfire"] = true,
    ["npc_dota_hero_grimstroke"] = true, ["npc_dota_hero_spectre"] = true,
}

D.INVIS_ITEMS = {
    ["item_invis_sword"] = true, ["item_silver_edge"] = true, ["item_glimmer_cape"] = true,
    ["item_shadow_blade"] = true,
}

D.MAGIC_HEROES = {
    ["npc_dota_hero_lina"] = true, ["npc_dota_hero_zeus"] = true, ["npc_dota_hero_invoker"] = true,
    ["npc_dota_hero_storm_spirit"] = true, ["npc_dota_hero_puck"] = true,
    ["npc_dota_hero_death_prophet"] = true, ["npc_dota_hero_leshrac"] = true,
    ["npc_dota_hero_disruptor"] = true, ["npc_dota_hero_witch_doctor"] = true,
    ["npc_dota_hero_shadow_demon"] = true, ["npc_dota_hero_warlock"] = true,
    ["npc_dota_hero_queenofpain"] = true, ["npc_dota_hero_tinker"] = true,
    ["npc_dota_hero_necrophos"] = true, ["npc_dota_hero_outworld_destroyer"] = true,
    ["npc_dota_hero_pugna"] = true, ["npc_dota_hero_jakiro"] = true,
    ["npc_dota_hero_skywrath_mage"] = true, ["npc_dota_hero_obsidian_destroyer"] = true,
    ["npc_dota_hero_zuus"] = true, ["npc_dota_hero_bane"] = true,
    ["npc_dota_hero_dark_willow"] = true, ["npc_dota_hero_grimstroke"] = true,
    ["npc_dota_hero_visage"] = true, ["npc_dota_hero_silencer"] = true,
    ["npc_dota_hero_crystal_maiden"] = true, ["npc_dota_hero_winter_wyvern"] = true,
    ["npc_dota_hero_lion"] = true, ["npc_dota_hero_shadow_shaman"] = true,
    ["npc_dota_hero_sand_king"] = true, ["npc_dota_hero_rubick"] = true,
    ["npc_dota_hero_keeper_of_the_light"] = true, ["npc_dota_hero_oracle"] = true,
}

D.PHYS_HEROES = {
    ["npc_dota_hero_phantom_assassin"] = true, ["npc_dota_hero_ursa"] = true,
    ["npc_dota_hero_slark"] = true, ["npc_dota_hero_templar_assassin"] = true,
    ["npc_dota_hero_drow_ranger"] = true, ["npc_dota_hero_sniper"] = true,
    ["npc_dota_hero_luna"] = true, ["npc_dota_hero_sven"] = true,
    ["npc_dota_hero_skeleton_king"] = true, ["npc_dota_hero_chaos_knight"] = true,
    ["npc_dota_hero_life_stealer"] = true, ["npc_dota_hero_faceless_void"] = true,
    ["npc_dota_hero_troll_warlord"] = true, ["npc_dota_hero_antimage"] = true,
    ["npc_dota_hero_legion_commander"] = true, ["npc_dota_hero_monkey_king"] = true,
    ["npc_dota_hero_medusa"] = true, ["npc_dota_hero_terrorblade"] = true,
    ["npc_dota_hero_naga_siren"] = true, ["npc_dota_hero_phantom_lancer"] = true,
    ["npc_dota_hero_riki"] = true, ["npc_dota_hero_bounty_hunter"] = true,
    ["npc_dota_hero_bloodseeker"] = true, ["npc_dota_hero_clinkz"] = true,
    ["npc_dota_hero_weaver"] = true, ["npc_dota_hero_spectre"] = true,
    ["npc_dota_hero_morphling"] = true, ["npc_dota_hero_juggernaut"] = true,
    ["npc_dota_hero_wraith_king"] = true, ["npc_dota_hero_dragon_knight"] = true,
    ["npc_dota_hero_huskar"] = true, ["npc_dota_hero_razor"] = true,
    ["npc_dota_hero_tidehunter"] = true, ["npc_dota_hero_doom_bringer"] = true,
    ["npc_dota_hero_gyrocopter"] = true, ["npc_dota_hero_arc_warden"] = true,
    ["npc_dota_hero_terrorblade"] = true, ["npc_dota_hero_axe"] = true,
}

D.HEAL_HEROES = {
    ["npc_dota_hero_necrophos"] = true, ["npc_dota_hero_oracle"] = true,
    ["npc_dota_hero_dazzle"] = true, ["npc_dota_hero_warlock"] = true,
    ["npc_dota_hero_treant"] = true, ["npc_dota_hero_omniknight"] = true,
    ["npc_dota_hero_io"] = true, ["npc_dota_hero_chen"] = true,
    ["npc_dota_hero_legion_commander"] = true, ["npc_dota_hero_life_stealer"] = true,
    ["npc_dota_hero_huskar"] = true, ["npc_dota_hero_alchemist"] = true,
    ["npc_dota_hero_abaddon"] = true, ["npc_dota_hero_witch_doctor"] = true,
    ["npc_dota_hero_enchantress"] = true, ["npc_dota_hero_winter_wyvern"] = true,
    ["npc_dota_hero_bane"] = true, ["npc_dota_hero_juggernaut"] = true,
    ["npc_dota_hero_tidehunter"] = true, ["npc_dota_hero_dark_seer"] = true,
    ["npc_dota_hero_wisp"] = true, ["npc_dota_hero_elder_titan"] = true,
}

D.EVASION_HEROES = {
    ["npc_dota_hero_phantom_assassin"] = true, ["npc_dota_hero_windrunner"] = true,
    ["npc_dota_hero_brewmaster"] = true, ["npc_dota_hero_void_spirit"] = true,
    ["npc_dota_hero_faceless_void"] = true, ["npc_dota_hero_ember_spirit"] = true,
}

-- spells that are primarily disables: do not waste them on an already disabled target
D.DISABLE_SPELLS = {
    ["lion_voodoo"] = true, ["lion_impale"] = true, ["tidehunter_ravage"] = true,
    ["axe_berserkers_call"] = true, ["centaur_hoof_stomp"] = true,
    ["shadow_shaman_voodoo"] = true, ["shadow_shaman_shackles"] = true,
    ["earthshaker_fissure"] = true, ["sven_storm_bolt"] = true,
    ["ogre_magi_fireblast"] = true, ["puck_dream_coil"] = true,
    ["death_prophet_silence"] = true, ["crystal_maiden_frostbite"] = true,
    ["ogre_magi_ignite"] = true, ["axe_battle_hunger"] = true,
}

-- physical / pure damage that still works through magic immunity
D.PHYSICAL_SPELLS = {
    ["axe_culling_blade"] = true, ["juggernaut_omni_slash"] = true,
    ["tidehunter_anchor_smash"] = true, ["centaur_double_edge"] = true,
}

-- abilities that are worth toggling to auto-cast
D.AUTOCAST_ABILITIES = {
    ["drow_ranger_frost_arrows"] = true, ["silencer_glaives_of_wisdom"] = true,
    ["huskar_burning_spear"] = true, ["viper_poison_attack"] = true,
    ["clinkz_searing_arrows"] = true, ["obsidian_destroyer_arcane_orb"] = true,
    ["enchantress_impetus"] = true, ["jakiro_liquid_fire"] = true,
    ["invoker_forge_spirit_va"] = true,
}

-- channelled disables are only worth starting on a target that cannot run away
D.CHANNEL_TARGETED = {
    ["lion_mana_drain"] = true,
    ["shadow_shaman_shackles"] = true,
}

-- ===========================================================================
--  PART 7. HERO DRAFT POOL
-- ===========================================================================

-- Every hero the AI can realistically draft. The first hero of each role is
-- the primary plan, the rest are alternates and counter-picks.
-- Format: { primary, alternate1, alternate2 }
Team.draft = {
    { "npc_dota_hero_juggernaut", "npc_dota_hero_luna", "npc_dota_hero_sven" },       -- pos 1
    { "npc_dota_hero_death_prophet", "npc_dota_hero_puck", "npc_dota_hero_leshrac" },  -- pos 2
    { "npc_dota_hero_tidehunter", "npc_dota_hero_axe", "npc_dota_hero_centaur" },      -- pos 3
    { "npc_dota_hero_lion", "npc_dota_hero_earthshaker", "npc_dota_hero_shadow_shaman" }, -- pos 4
    { "npc_dota_hero_crystal_maiden", "npc_dota_hero_ogre_magi", "npc_dota_hero_shadow_shaman" }, -- pos 5
}

-- ===========================================================================
--  PART 8. HERO BUILDS AND SPELL LOGIC
-- ===========================================================================

D.HEROES = {}

-- ---------------------------------------------------------------------------
--  POSITION 1 CARRIES
-- ---------------------------------------------------------------------------

D.HEROES["npc_dota_hero_juggernaut"] = {
    role = 1,
    start = { "item_flask", "item_magic_stick", "item_branches", "item_faerie_fire", "item_clarity" },
    skills = { "juggernaut_blade_fury", "juggernaut_healing_ward", "juggernaut_blade_dance" },
    ult = "juggernaut_omni_slash",
    build = { "item_phase_boots", "item_magic_wand", "item_bfury", "item_manta",
              "item_black_king_bar", "item_abyssal_blade", "item_butterfly", "item_satanic" },
    spells = {
        { a = "juggernaut_blade_fury", mode = "danger", target = "self", hpBelow = 70, range = 700, prio = 1 },
        { a = "juggernaut_healing_ward", mode = "always", target = "selfpos", allyHpBelow = 72, hpBelow = 85, prio = 2 },
        { a = "juggernaut_blade_fury", mode = "kill", target = "self", tHpBelow = 35, range = 320, prio = 3 },
        { a = "juggernaut_omni_slash", mode = "fight", target = "focus", maxEnemies = 2, hpAbove = 45, prio = 4 },
    },
}

D.HEROES["npc_dota_hero_luna"] = {
    role = 1,
    start = { "item_flask", "item_magic_stick", "item_branches", "item_faerie_fire", "item_slippers" },
    skills = { "luna_lucent_beam", "luna_lunar_blessing", "luna_moon_glaive" },
    ult = "luna_eclipse",
    build = { "item_power_treads", "item_magic_wand", "item_manta", "item_black_king_bar",
              "item_butterfly", "item_satanic", "item_skadi", "item_hurricane_pike" },
    spells = {
        { a = "luna_lucent_beam", mode = "fight", target = "focus", prio = 1 },
        { a = "luna_eclipse", mode = "fight", target = "selfpos", radius = 700, minEnemies = 2, hpAbove = 40, prio = 2 },
    },
}

D.HEROES["npc_dota_hero_sven"] = {
    role = 1,
    start = { "item_flask", "item_magic_stick", "item_branches", "item_faerie_fire", "item_slippers" },
    skills = { "sven_storm_bolt", "sven_great_cleave", "sven_warcry" },
    ult = "sven_gods_strength",
    build = { "item_power_treads", "item_magic_wand", "item_echo_sabre", "item_black_king_bar",
              "item_armlet", "item_abyssal_blade", "item_daedalus", "item_satanic" },
    spells = {
        { a = "sven_storm_bolt", mode = "fight", target = "focus", prio = 1 },
        { a = "sven_gods_strength", mode = "fight", target = "self", hpAbove = 50, prio = 2 },
        { a = "sven_warcry", mode = "fight", target = "self", prio = 3 },
    },
}

-- ---------------------------------------------------------------------------
--  POSITION 2 MIDS
-- ---------------------------------------------------------------------------

D.HEROES["npc_dota_hero_death_prophet"] = {
    role = 2,
    start = { "item_flask", "item_faerie_fire", "item_branches", "item_clarity", "item_magic_stick" },
    skills = { "death_prophet_crypt_swarm", "death_prophet_silence", "death_prophet_spirit_siphon" },
    ult = "death_prophet_exorcism",
    build = { "item_arcane_boots", "item_magic_wand", "item_kaya_and_sange", "item_black_king_bar",
              "item_shivas_guard", "item_ultimate_scepter", "item_octarine_core", "item_refresher" },
    spells = {
        { a = "death_prophet_silence", mode = "fight", target = "focus", prio = 1 },
        { a = "death_prophet_spirit_siphon", mode = "fight", target = "focus", hpBelow = 85, prio = 2 },
        { a = "death_prophet_crypt_swarm", mode = "fight", target = "focus", prio = 3 },
        { a = "death_prophet_exorcism", mode = "fight", target = "self", hpAbove = 35, radius = 900, minEnemies = 2, prio = 4 },
        { a = "death_prophet_exorcism", mode = "push", target = "self", prio = 5 },
    },
}

D.HEROES["npc_dota_hero_puck"] = {
    role = 2,
    start = { "item_flask", "item_faerie_fire", "item_branches", "item_clarity", "item_magic_stick" },
    skills = { "puck_illusory_orb", "puck_waning_rift", "puck_phase_shift" },
    ult = "puck_dream_coil",
    build = { "item_arcane_boots", "item_magic_wand", "item_blink", "item_cyclone",
              "item_black_king_bar", "item_shivas_guard", "item_ultimate_scepter" },
    spells = {
        { a = "puck_phase_shift", mode = "danger", target = "self", hpBelow = 45, range = 900, prio = 1 },
        { a = "puck_dream_coil", mode = "fight", target = "focus", maxEnemies = 3, prio = 2 },
        { a = "puck_waning_rift", mode = "fight", target = "selfpos", radius = 420, minEnemies = 1, prio = 3 },
        { a = "puck_illusory_orb", mode = "fight", target = "focus", prio = 4 },
    },
}

D.HEROES["npc_dota_hero_leshrac"] = {
    role = 2,
    start = { "item_flask", "item_faerie_fire", "item_branches", "item_clarity", "item_magic_stick" },
    skills = { "leshrac_split_earth", "leshrac_lightning_storm", "leshrac_diabolic_edict" },
    ult = "leshrac_pulse_nova",
    build = { "item_arcane_boots", "item_magic_wand", "item_black_king_bar", "item_kaya_and_sange",
              "item_shivas_guard", "item_ultimate_scepter", "item_octarine_core" },
    spells = {
        { a = "leshrac_split_earth", mode = "fight", target = "focuspos", prio = 1 },
        { a = "leshrac_lightning_storm", mode = "fight", target = "focus", prio = 2 },
        { a = "leshrac_diabolic_edict", mode = "fight", target = "self", hpAbove = 50, prio = 3 },
        { a = "leshrac_pulse_nova", mode = "fight", target = "self", hpAbove = 50, radius = 500, minEnemies = 1, prio = 4 },
    },
}

-- ---------------------------------------------------------------------------
--  POSITION 3 OFFLANERS
-- ---------------------------------------------------------------------------

D.HEROES["npc_dota_hero_tidehunter"] = {
    role = 3,
    start = { "item_flask", "item_magic_stick", "item_branches", "item_faerie_fire", "item_enchanted_mango" },
    skills = { "tidehunter_gush", "tidehunter_kraken_shell", "tidehunter_anchor_smash" },
    ult = "tidehunter_ravage",
    build = { "item_arcane_boots", "item_blink", "item_pipe", "item_shivas_guard",
              "item_refresher", "item_ultimate_scepter", "item_guardian_greaves" },
    spells = {
        { a = "tidehunter_kraken_shell", mode = "always", target = "self", hpBelow = 60, prio = 1 },
        { a = "tidehunter_ravage", mode = "fight", target = "selfpos", radius = 900, minEnemies = 2, prio = 2 },
        { a = "tidehunter_anchor_smash", mode = "fight", target = "selfpos", radius = 420, minEnemies = 2, prio = 3 },
        { a = "tidehunter_gush", mode = "fight", target = "focus", prio = 4 },
    },
}

D.HEROES["npc_dota_hero_axe"] = {
    role = 3,
    start = { "item_flask", "item_magic_stick", "item_branches", "item_faerie_fire", "item_enchanted_mango" },
    skills = { "axe_berserkers_call", "axe_counter_helix", "axe_battle_hunger" },
    ult = "axe_culling_blade",
    build = { "item_phase_boots", "item_blade_mail", "item_blink", "item_crimson_guard",
              "item_heart", "item_ultimate_scepter", "item_shivas_guard" },
    spells = {
        { a = "axe_berserkers_call", mode = "fight", target = "selfpos", radius = 400, minEnemies = 1, prio = 1 },
        { a = "axe_battle_hunger", mode = "fight", target = "focus", prio = 2 },
        { a = "axe_culling_blade", mode = "kill", target = "focus", tHpBelow = 45, prio = 3 },
    },
}

D.HEROES["npc_dota_hero_centaur"] = {
    role = 3,
    start = { "item_flask", "item_magic_stick", "item_branches", "item_faerie_fire", "item_enchanted_mango" },
    skills = { "centaur_hoof_stomp", "centaur_double_edge", "centaur_return" },
    ult = "centaur_stampede",
    build = { "item_power_treads", "item_blink", "item_crimson_guard", "item_pipe",
              "item_heart", "item_shivas_guard", "item_assault" },
    spells = {
        { a = "centaur_hoof_stomp", mode = "fight", target = "selfpos", radius = 350, minEnemies = 1, prio = 1 },
        { a = "centaur_double_edge", mode = "fight", target = "focus", hpBelow = 80, prio = 2 },
        { a = "centaur_stampede", mode = "fight", target = "self", minEnemies = 2, prio = 3 },
    },
}

-- ---------------------------------------------------------------------------
--  POSITION 4 SOFT SUPPORTS
-- ---------------------------------------------------------------------------

D.HEROES["npc_dota_hero_lion"] = {
    role = 4,
    start = { "item_ward_observer", "item_ward_sentry", "item_flask", "item_faerie_fire",
              "item_enchanted_mango", "item_clarity" },
    skills = { "lion_impale", "lion_voodoo", "lion_mana_drain" },
    ult = "lion_finger_of_death",
    build = { "item_arcane_boots", "item_magic_wand", "item_blink", "item_force_staff",
              "item_ultimate_scepter", "item_glimmer_cape", "item_aghanims_shard" },
    spells = {
        { a = "lion_voodoo", mode = "fight", target = "focus", prio = 1 },
        { a = "lion_impale", mode = "fight", target = "focus", prio = 2 },
        { a = "lion_finger_of_death", mode = "kill", target = "focus", tHpBelow = 55, prio = 3 },
        { a = "lion_mana_drain", mode = "fight", target = "focus", hpAbove = 60, manaAbove = 15, prio = 4 },
    },
}

D.HEROES["npc_dota_hero_earthshaker"] = {
    role = 4,
    start = { "item_ward_observer", "item_ward_sentry", "item_flask", "item_faerie_fire",
              "item_enchanted_mango", "item_clarity" },
    skills = { "earthshaker_fissure", "earthshaker_enchant_totem", "earthshaker_aftershock" },
    ult = "earthshaker_echo_slam",
    build = { "item_arcane_boots", "item_magic_wand", "item_blink", "item_force_staff",
              "item_ultimate_scepter", "item_shivas_guard", "item_refresher" },
    spells = {
        { a = "earthshaker_fissure", mode = "fight", target = "focus", prio = 1 },
        { a = "earthshaker_echo_slam", mode = "fight", target = "selfpos", radius = 900, minEnemies = 2, prio = 2 },
        { a = "earthshaker_enchant_totem", mode = "fight", target = "self", hpAbove = 50, prio = 3 },
    },
}

D.HEROES["npc_dota_hero_shadow_shaman"] = {
    role = 4,
    start = { "item_ward_observer", "item_ward_sentry", "item_flask", "item_faerie_fire",
              "item_enchanted_mango", "item_clarity" },
    skills = { "shadow_shaman_ether_shock", "shadow_shaman_voodoo", "shadow_shaman_shackles" },
    ult = "shadow_shaman_mass_serpent_ward",
    build = { "item_arcane_boots", "item_magic_wand", "item_blink", "item_force_staff",
              "item_ultimate_scepter", "item_aghanims_shard", "item_glimmer_cape" },
    spells = {
        { a = "shadow_shaman_voodoo", mode = "fight", target = "focus", prio = 1 },
        { a = "shadow_shaman_ether_shock", mode = "fight", target = "focus", prio = 2 },
        { a = "shadow_shaman_shackles", mode = "fight", target = "focus", hpAbove = 45, minEnemies = 1, prio = 3 },
        { a = "shadow_shaman_mass_serpent_ward", mode = "fight", target = "selfpos", hpAbove = 30, prio = 4 },
        { a = "shadow_shaman_mass_serpent_ward", mode = "push", target = "selfpos", prio = 5 },
    },
}

-- ---------------------------------------------------------------------------
--  POSITION 5 HARD SUPPORTS
-- ---------------------------------------------------------------------------

D.HEROES["npc_dota_hero_crystal_maiden"] = {
    role = 5,
    start = { "item_ward_observer", "item_ward_sentry", "item_smoke_of_deceit", "item_clarity",
              "item_enchanted_mango", "item_branches" },
    skills = { "crystal_maiden_frostbite", "crystal_maiden_crystal_nova", "crystal_maiden_brilliance_aura" },
    ult = "crystal_maiden_freezing_field",
    build = { "item_magic_wand", "item_tranquil_boots", "item_glimmer_cape", "item_force_staff",
              "item_black_king_bar", "item_ultimate_scepter", "item_aghanims_shard" },
    spells = {
        { a = "crystal_maiden_frostbite", mode = "fight", target = "focus", prio = 1 },
        { a = "crystal_maiden_crystal_nova", mode = "fight", target = "focuspos", radius = 400, minEnemies = 1, prio = 2 },
        { a = "crystal_maiden_freezing_field", mode = "fight", target = "self", hpAbove = 55, radius = 700, minEnemies = 2, prio = 3 },
    },
}

D.HEROES["npc_dota_hero_ogre_magi"] = {
    role = 5,
    start = { "item_ward_observer", "item_ward_sentry", "item_smoke_of_deceit", "item_clarity",
              "item_enchanted_mango", "item_branches" },
    skills = { "ogre_magi_fireblast", "ogre_magi_ignite", "ogre_magi_bloodlust" },
    ult = "ogre_magi_multicast",
    build = { "item_magic_wand", "item_arcane_boots", "item_glimmer_cape", "item_force_staff",
              "item_pipe", "item_ultimate_scepter", "item_aghanims_shard" },
    spells = {
        { a = "ogre_magi_fireblast", mode = "fight", target = "focus", prio = 1 },
        { a = "ogre_magi_ignite", mode = "fight", target = "focus", prio = 2 },
        { a = "ogre_magi_bloodlust", mode = "always", target = "self", hpAbove = 20, prio = 3 },
    },
}

-- ===========================================================================
--  PART 9. TEAM MEMORY
-- ===========================================================================

V.hero = {}

V.team = {
    lastGlyph = -1000,
    lastSmoke = -1000,
    lastBuyback = -1000,
    enemyTrack = {},
}

function Team:State(hero)
    local id = hero and hero.id
    if id == nil then return {} end
    local st = V.hero[id]
    if not st then
        st = {
            lastSwap = -1000, lastBuy = -1000, lastTp = -1000, lastLearn = -1000,
            startBought = {}, startDone = false, lastStart = -1000,
            build = nil, panicUntil = -1000, retreatUntil = -1000,
            wardAt = -1000, dustAt = -1000, sentryAt = -1000, smokeAt = -1000,
            talentTried = {}, badLearn = {}, talentAt = -1000,
            buybackAt = -1000, lastDrop = -1000, salveAt = -1000, clarityAt = -1000,
            lastAttack = -1000, lastMove = -1000, lastTarget = nil,
            glyphAsk = false, role = 0, lane = nil, task = nil,
        }
        V.hero[id] = st
    end
    return st
end

-- ===========================================================================
--  PART 10. TICK CONTEXT
-- ===========================================================================

function Team:Context(snapshot)
    local t = {}
    t.snap = snapshot
    t.time = U.num(snapshot.time, 0)
    t.myTeam = U.num(snapshot.team, 2)
    t.enemyTeam = U.num(snapshot.enemyTeam, 5 - t.myTeam)
    if t.enemyTeam == t.myTeam then
        t.enemyTeam = (t.myTeam == 2) and 3 or 2
    end
    t.isDay = snapshot.isDay == true
    t.glyphCd = U.num(snapshot.glyphCooldown, 0)
    t.heroes = U.asArray(snapshot.heroes)
    t.allies = U.asArray(snapshot.allies)
    t.enemies = U.asArray(snapshot.enemies)
    t.lastSeen = U.tbl(snapshot.enemyLastSeen)
    t.pins = U.asArray(snapshot.pins)
    t.runes = U.asArray(snapshot.runes)
    t.drops = U.asArray(snapshot.drops)
    t.neutrals = U.asArray(snapshot.neutrals)
    t.schedule = U.tbl(snapshot.schedule)

    t.mine = {}
    t.heroById = {}
    t.allyById = {}
    t.enemyById = {}
    t.allyUnits = {}
    t.allyBuildings = {}
    t.allyWards = {}
    t.allyCreeps = {}
    t.enemyUnits = {}
    t.enemyBuildings = {}
    t.enemyWards = {}
    t.enemyCreeps = {}
    t.enemyHeroes = {}
    t.enemyIllusions = {}
    t.neutralsList = {}
    t.focus = nil

    -- my heroes (5), sorted by position
    local heroes = t.heroes
    local seen = {}
    for i = 1, #heroes do
        local h = heroes[i]
        if type(h) == "table" and h.id ~= nil and not seen[h.id] then
            seen[h.id] = true
            t.mine[#t.mine + 1] = h
            t.heroById[h.id] = h
        end
    end
    if #t.mine == 0 then
        for k, h in pairs(heroes) do
            if type(h) == "table" and h.id ~= nil and not seen[h.id] then
                seen[h.id] = true
                h.position = U.num(h.position, U.num(k, #t.mine + 1))
                t.mine[#t.mine + 1] = h
                t.heroById[h.id] = h
            end
        end
    end
    for i = 1, #t.mine do
        t.mine[i].position = U.num(t.mine[i].position, i)
    end
    table.sort(t.mine, function(a, b)
        return U.num(a.position, 1) < U.num(b.position, 1)
    end)

    -- allied units
    local allies = t.allies
    for i = 1, #allies do
        local u = allies[i]
        if type(u) == "table" and u.id ~= nil then
            t.allyById[u.id] = u
            t.allyUnits[#t.allyUnits + 1] = u
            local k = U.kind(u)
            if k == "tower" or k == "barracks" or k == "ancient" or k == "building" then
                t.allyBuildings[#t.allyBuildings + 1] = u
            elseif k == "observer_ward" or k == "sentry_ward" then
                t.allyWards[#t.allyWards + 1] = u
            elseif k == "lane_creep" or k == "siege_creep" or k == "unit" then
                t.allyCreeps[#t.allyCreeps + 1] = u
            end
        end
    end

    -- enemy units
    local enemies = t.enemies
    for i = 1, #enemies do
        local u = enemies[i]
        if type(u) == "table" and u.id ~= nil then
            t.enemyById[u.id] = u
            t.enemyUnits[#t.enemyUnits + 1] = u
            local k = U.kind(u)
            if k == "hero" then
                if u.isIllusion == true then
                    t.enemyIllusions[#t.enemyIllusions + 1] = u
                else
                    t.enemyHeroes[#t.enemyHeroes + 1] = u
                end
            elseif k == "tower" or k == "barracks" or k == "ancient" or k == "building" then
                t.enemyBuildings[#t.enemyBuildings + 1] = u
            elseif k == "observer_ward" or k == "sentry_ward" then
                t.enemyWards[#t.enemyWards + 1] = u
            elseif k == "lane_creep" or k == "siege_creep" or k == "unit" then
                t.enemyCreeps[#t.enemyCreeps + 1] = u
            end
        end
    end

    -- neutrals
    local ne = t.neutrals
    for i = 1, #ne do
        local u = ne[i]
        if type(u) == "table" and u.id ~= nil and U.alive(u) then
            t.neutralsList[#t.neutralsList + 1] = u
        end
    end

    -- fountains / base anchors
    t.fountain = nil
    t.enemyFountain = nil
    for i = 1, #t.pins do
        local p = t.pins[i]
        if type(p) == "table" then
            local k = U.kind(p)
            if k == "fountain" then
                local mt = U.num(p.mapTeam, 0)
                if mt == t.myTeam then t.fountain = p.pos
                elseif mt == t.enemyTeam then t.enemyFountain = p.pos end
            end
        end
    end
    if not t.fountain then
        -- fallback: our ancient position
        for i = 1, #t.allyBuildings do
            if U.kind(t.allyBuildings[i]) == "ancient" then
                t.fountain = U.unitPos(t.allyBuildings[i])
                break
            end
        end
    end
    if not t.enemyFountain then
        for i = 1, #t.enemyBuildings do
            if U.kind(t.enemyBuildings[i]) == "ancient" then
                t.enemyFountain = U.unitPos(t.enemyBuildings[i])
                break
            end
        end
    end

    -- aggregate enemy knowledge
    t.enemyInvis = false
    t.enemyInvisIds = {}
    t.enemyItems = {}
    t.enemyNames = {}
    for i = 1, #t.enemyHeroes do
        local e = t.enemyHeroes[i]
        if type(e.name) == "string" then t.enemyNames[e.name] = true end
        local it = U.items(e)
        for s = 0, 16 do
            local nm = it[s]
            if type(nm) == "string" then t.enemyItems[nm] = true end
        end
        if D.INVIS_HEROES[e.name] == true then
            t.enemyInvis = true
            t.enemyInvisIds[e.id] = true
        end
    end
    for i = 1, #t.enemyIllusions do
        local e = t.enemyIllusions[i]
        if type(e.name) == "string" then t.enemyNames[e.name] = true end
    end
    for id, e in pairs(t.lastSeen) do
        if type(e) == "table" then
            if D.INVIS_HEROES[e.name] == true then
                t.enemyInvis = true
                t.enemyInvisIds[id] = true
            end
            local it = U.tbl(e.items)
            for s = 0, 16 do
                local nm = it[s]
                if type(nm) == "string" then
                    t.enemyItems[nm] = true
                    if D.INVIS_ITEMS[nm] == true then
                        t.enemyInvis = true
                        t.enemyInvisIds[id] = true
                    end
                end
            end
        end
    end

    -- combat / strength metrics
    t.aliveMine = 0
    t.hpSumMine = 0
    t.levelSumMine = 0
    t.aliveEnemies = 0
    t.hpSumEnemies = 0
    for i = 1, #t.mine do
        local h = t.mine[i]
        if U.alive(h) then
            t.aliveMine = t.aliveMine + 1
            t.hpSumMine = t.hpSumMine + U.hpPct(h)
        end
        t.levelSumMine = t.levelSumMine + U.unitLevel(h)
    end
    for i = 1, #t.enemyHeroes do
        local h = t.enemyHeroes[i]
        if U.alive(h) then
            t.aliveEnemies = t.aliveEnemies + 1
            t.hpSumEnemies = t.hpSumEnemies + U.hpPct(h)
        end
    end
    t.avgHpMine = 0
    if t.aliveMine > 0 then t.avgHpMine = t.hpSumMine / t.aliveMine end
    t.avgHpEnemies = 0
    if t.aliveEnemies > 0 then t.avgHpEnemies = t.hpSumEnemies / t.aliveEnemies end

    -- remember who we saw (soft death detection for enemy heroes)
    for i = 1, #t.enemyHeroes do
        local e = t.enemyHeroes[i]
        V.team.enemyTrack[e.id] = { at = t.time, hp = U.hp(e), max = U.maxHp(e), pos = U.unitPos(e), name = e.name }
    end

    t.tormentorActive = false
    local tor = t.schedule.tormentor
    if type(tor) == "table" then
        t.tormentorActive = tor.active == true
    end

    U.ctx = t
    return t
end

-- ===========================================================================
--  PART 11. SNAPSHOT QUERIES
-- ===========================================================================

function Team:EnemyHero(t, id)
    if id == nil then return nil end
    return t.enemyById[id]
end

function Team:CountEnemiesNear(t, pos, radius, heroesOnly)
    local n = 0
    if type(pos) ~= "table" then return 0 end
    if heroesOnly then
        for i = 1, #t.enemyHeroes do
            local e = t.enemyHeroes[i]
            if U.alive(e) and U.dist(U.unitPos(e), pos) <= radius then n = n + 1 end
        end
        return n
    end
    for i = 1, #t.enemyUnits do
        local e = t.enemyUnits[i]
        if U.alive(e) and U.dist(U.unitPos(e), pos) <= radius then n = n + 1 end
    end
    return n
end

function Team:CountEnemyCreepsNear(t, pos, radius)
    local n = 0
    for i = 1, #t.enemyCreeps do
        local e = t.enemyCreeps[i]
        if U.alive(e) and U.dist(U.unitPos(e), pos) <= radius then n = n + 1 end
    end
    return n
end

function Team:CountAllyCreepsNear(t, pos, radius)
    local n = 0
    for i = 1, #t.allyCreeps do
        local e = t.allyCreeps[i]
        if U.alive(e) and U.dist(U.unitPos(e), pos) <= radius then n = n + 1 end
    end
    return n
end

function Team:CountAllyHeroesNear(t, pos, radius, excludeId)
    local n = 0
    for i = 1, #t.mine do
        local h = t.mine[i]
        if U.alive(h) and h.id ~= excludeId and U.dist(U.unitPos(h), pos) <= radius then
            n = n + 1
        end
    end
    return n
end

function Team:NearestEnemy(t, pos, maxDist, heroesOnly)
    if type(pos) ~= "table" then return nil end
    local best, bestD = nil, U.num(maxDist, 100000)
    local list = heroesOnly and t.enemyHeroes or t.enemyUnits
    for i = 1, #list do
        local e = list[i]
        if U.alive(e) and e.invulnerable ~= true then
            local d = U.dist(U.unitPos(e), pos)
            if d < bestD then
                best, bestD = e, d
            end
        end
    end
    return best, bestD
end

function Team:NearestEnemyHero(t, pos, maxDist, skipIllusion)
    if type(pos) ~= "table" then return nil, 0 end
    local best, bestD = nil, U.num(maxDist, 100000)
    for i = 1, #t.enemyHeroes do
        local e = t.enemyHeroes[i]
        if U.alive(e) and e.invulnerable ~= true then
            local d = U.dist(U.unitPos(e), pos)
            if d < bestD then
                best, bestD = e, d
            end
        end
    end
    if not best and not skipIllusion then
        for i = 1, #t.enemyIllusions do
            local e = t.enemyIllusions[i]
            if U.alive(e) then
                local d = U.dist(U.unitPos(e), pos)
                if d < bestD then
                    best, bestD = e, d
                end
            end
        end
    end
    return best, bestD
end

function Team:LowestHpAlly(t, pos, radius, maxHpPct)
    local best, bestHp = nil, U.num(maxHpPct, 100)
    for i = 1, #t.mine do
        local h = t.mine[i]
        if U.alive(h) then
            local d = 0
            if type(pos) == "table" then d = U.dist(U.unitPos(h), pos) end
            if d <= radius then
                local pct = U.hpPct(h)
                if pct < bestHp then
                    best, bestHp = h, pct
                end
            end
        end
    end
    return best, bestHp
end

function Team:MyNearestBuilding(t, pos)
    if type(pos) ~= "table" then return nil end
    local best, bestD = nil, 1000000
    for i = 1, #t.allyBuildings do
        local b = t.allyBuildings[i]
        if U.alive(b) then
            local d = U.dist(U.unitPos(b), pos)
            if d < bestD then
                best, bestD = b, d
            end
        end
    end
    return best, bestD
end

function Team:FindPin(t, kind, mapTeam)
    local best = nil
    for i = 1, #t.pins do
        local p = t.pins[i]
        if type(p) == "table" then
            if U.kind(p) == kind then
                local mt = U.num(p.mapTeam, 0)
                if mapTeam == nil or mt == mapTeam then
                    return p
                end
                if not best then best = p end
            end
        end
    end
    return best
end

function Team:PinsOf(t, kind)
    local res = {}
    for i = 1, #t.pins do
        local p = t.pins[i]
        if type(p) == "table" and U.kind(p) == kind then
            res[#res + 1] = p
        end
    end
    return res
end

function Team:NearestPin(t, kind, pos, mapTeam)
    local best, bestD = nil, 1000000
    for i = 1, #t.pins do
        local p = t.pins[i]
        if type(p) == "table" and U.kind(p) == kind then
            if mapTeam == nil or U.num(p.mapTeam, 0) == mapTeam then
                local d = U.dist(p.pos, pos)
                if d < bestD then
                    best, bestD = p, d
                end
            end
        end
    end
    return best, bestD
end

function Team:IsAtBase(t, hero)
    local p = U.unitPos(hero)
    if not p or not t.fountain then return false end
    return U.dist(p, t.fountain) <= U.FOUNTAIN_SAFE
end

function Team:ScheduleNext(t, name)
    local s = t.schedule[name]
    if type(s) ~= "table" then return nil, nil end
    return U.num(s.nextAt, nil), U.num(s.firstAt, nil)
end

function Team:EnemyHasItem(t, itemName)
    return t.enemyItems[itemName] == true
end

function Team:EnemyHasAny(t, dict)
    for name in pairs(dict) do
        if t.enemyNames[name] == true then return true end
    end
    return false
end

function Team:CountEnemyMatching(t, dict)
    local n = 0
    for name in pairs(dict) do
        if t.enemyNames[name] == true then n = n + 1 end
    end
    return n
end

function Team:EnemyHasEvasion(t)
    if self:CountEnemyMatching(t, D.EVASION_HEROES) > 0 then return true end
    if t.enemyItems["item_butterfly"] == true then return true end
    if t.enemyItems["item_heavens_halberd"] == true then return true end
    return false
end

-- nearest visible enemy tower to pos, optionally filtered to tier
function Team:EnemyTowers(t)
    local res = {}
    for i = 1, #t.enemyBuildings do
        local b = t.enemyBuildings[i]
        if U.kind(b) == "tower" then res[#res + 1] = b end
    end
    return res
end

function Team:NearestEnemyTower(t, pos)
    local best, bestD = nil, 1000000
    for i = 1, #t.enemyBuildings do
        local b = t.enemyBuildings[i]
        if U.alive(b) and U.isTower(b) then
            local d = U.dist(U.unitPos(b), pos)
            if d < bestD then best, bestD = b, d end
        end
    end
    return best, bestD
end

function Team:UnderEnemyTower(t, pos, extra)
    local tower, d = self:NearestEnemyTower(t, pos)
    if not tower then return false, nil, 0 end
    local safe = U.TOWER_SAFE + U.num(extra, 0)
    return d <= safe, tower, d
end

-- is the enemy tower currently busy with our creeps? (means safe-ish to dive)
function Team:TowerHasCreeps(t, towerPos)
    if type(towerPos) ~= "table" then return false end
    local n = self:CountAllyCreepsNear(t, towerPos, 950)
    return n > 0, n
end

-- ===========================================================================
--  PART 12. SCHEDULE / OBJECTIVE HELPERS
-- ===========================================================================

function Team:RuneList(t, wantedType)
    local res = {}
    for i = 1, #t.runes do
        local r = t.runes[i]
        if type(r) == "table" and r.id ~= nil then
            if wantedType == nil or r.runeType == wantedType or r.spawnerKind == wantedType then
                res[#res + 1] = r
            end
        end
    end
    return res
end

function Team:NearestRune(t, pos, wantedType)
    local best, bestD = nil, 1000000
    local list = self:RuneList(t, wantedType)
    for i = 1, #list do
        local r = list[i]
        local d = U.dist(r.pos, pos)
        if d < bestD then best, bestD = r, d end
    end
    return best, bestD
end

function Team:NearestDrop(t, pos, maxDist, wanted)
    local best, bestD = nil, U.num(maxDist, 1000000)
    for i = 1, #t.drops do
        local d = t.drops[i]
        if type(d) == "table" and d.id ~= nil then
            if wanted == nil or d.name == wanted then
                local dd = U.dist(d.pos, pos)
                if dd < bestD then best, bestD = d, dd end
            end
        end
    end
    return best, bestD
end

function Team:NearestNeutral(t, pos, kindName)
    local best, bestD = nil, 1000000
    for i = 1, #t.neutralsList do
        local u = t.neutralsList[i]
        if kindName == nil or U.kind(u) == kindName then
            local d = U.dist(U.unitPos(u), pos)
            if d < bestD then best, bestD = u, d end
        end
    end
    return best, bestD
end

-- ===========================================================================
--  PART 13. SKILL AND TALENT PROGRESSION
-- ===========================================================================

D.ORDER = {}
D.MAX_BASIC = 4
D.ULT_LEVELS = { [6] = true, [12] = true, [18] = true }
D.TALENT_LEVELS = { [10] = true, [15] = true, [20] = true, [25] = true }

D.TALENT_PREF = {
    "attack_speed", "attack_damage", "all_stats", "stats", "health", "hp_regen",
    "mana_regen", "mana", "cast_range", "movement_speed", "cooldown", "spell_amplification",
    "magic_resistance", "armor", "strength", "agility", "intelligence", "evasion",
    "gold", "xp", "lifesteal", "damage",
}

function Team:IsTalentName(name)
    if type(name) ~= "string" then return false end
    return string.sub(name, 1, 13) == "special_bonus"
end

function Team:BuildOrder(heroName)
    if D.ORDER[heroName] then return D.ORDER[heroName] end
    local hd = D.HEROES[heroName]
    if type(hd) ~= "table" then return nil end
    local order = {}
    local learned = {}
    local skills = U.tbl(hd.skills)
    local ult = hd.ult
    for lvl = 1, 30 do
        if D.TALENT_LEVELS[lvl] then
            order[lvl] = "TALENT"
        elseif D.ULT_LEVELS[lvl] and type(ult) == "string" then
            order[lvl] = ult
            learned[ult] = (learned[ult] or 0) + 1
        else
            local pick = nil
            for i = 1, #skills do
                local s = skills[i]
                if (learned[s] or 0) < D.MAX_BASIC then
                    pick = s
                    break
                end
            end
            if not pick and type(ult) == "string" and (learned[ult] or 0) < 3 then
                pick = ult
            end
            if pick then
                learned[pick] = (learned[pick] or 0) + 1
                order[lvl] = pick
            else
                order[lvl] = "TALENT"
            end
        end
    end
    D.ORDER[heroName] = order
    return order
end

function Team:LearnedPoints(hero)
    local spent = 0
    local ab = U.tbl(hero.abilities)
    for k, a in pairs(ab) do
        if type(a) == "table" then
            local lv = U.num(a.level, 0)
            if lv > 0 then
                spent = spent + lv
            end
        end
    end
    return spent
end

function Team:UpgradableSkills(hero)
    local res = {}
    local ab = U.tbl(hero.abilities)
    for k, a in pairs(ab) do
        if type(a) == "table" and type(a.name) == "string" then
            if not self:IsTalentName(a.name) and a.passive ~= true and a.hidden ~= true then
                local lv = U.num(a.level, 0)
                local mx = U.num(a.maxLevel, 4)
                if a.canUpgrade == true or (a.canUpgrade == nil and lv < mx) then
                    res[#res + 1] = a.name
                end
            end
        end
    end
    return res
end

function Team:FallbackSkill(hero, st, avoidName)
    local hd = D.HEROES[hero.name]
    local skills = (type(hd) == "table" and U.tbl(hd.skills)) or {}
    local up = self:UpgradableSkills(hero)
    for i = 1, #skills do
        local nm = skills[i]
        if nm ~= avoidName and st.badLearn[nm] ~= true and U.contains(up, nm) then
            return nm
        end
    end
    for i = 1, #up do
        local nm = up[i]
        if nm ~= avoidName and st.badLearn[nm] ~= true then
            return nm
        end
    end
    return nil
end

function Team:PickTalent(t, hero, st)
    local cands = {}
    local ab = U.tbl(hero.abilities)
    for k, a in pairs(ab) do
        if type(a) == "table" and self:IsTalentName(a.name)
            and a.name ~= "special_bonus_attributes" and not a.hidden then
            local lv = U.num(a.level, 0)
            local mx = U.num(a.maxLevel, 1)
            if lv < mx and a.canUpgrade ~= false then
                local triedAt = U.num(st.talentTried[a.name], -1000)
                if t.time - triedAt > 5 then
                    local score = 0
                    for i = 1, #D.TALENT_PREF do
                        if string.find(a.name, D.TALENT_PREF[i], 1, true) then
                            score = 200 - i * 5
                            break
                        end
                    end
                    cands[#cands + 1] = { name = a.name, score = score }
                end
            end
        end
    end
    if #cands == 0 then return nil end
    table.sort(cands, function(a, b) return a.score > b.score end)
    local pick = cands[1].name
    st.talentTried[pick] = t.time
    return pick
end

function Team:LearnStep(t, hero, st, acts)
    if t.time - U.num(st.lastLearn, -1000) < 0.55 then return end
    local talent = self:PickTalent(t, hero, st)
    if talent then
        acts[#acts + 1] = U.learn(talent)
        st.lastLearn = t.time
        return
    end
    if U.num(hero.abilityPoints, 0) <= 0 then return end
    local order = self:BuildOrder(hero.name)
    if not order then return end
    local spent = self:LearnedPoints(hero)
    local lvl = U.num(hero.level, 1)
    local idx = spent + 1
    if idx > lvl then idx = lvl end
    if idx < 1 then idx = 1 end
    local want = order[idx]
    if want == "TALENT" then
        want = self:FallbackSkill(hero, st)
        if not want then
            local attributes = U.abil(hero, "special_bonus_attributes")
            if attributes and attributes.canUpgrade then want = attributes.name end
        end
    end
    if type(want) ~= "string" then return end
    local a = U.abil(hero, want)
    local usable = type(a) == "table" and a.canUpgrade ~= false
    if not usable or st.badLearn[want] == true then
        local alt = self:FallbackSkill(hero, st, want)
        if not alt then
            st.badLearn[want] = true
            return
        end
        want = alt
    end
    acts[#acts + 1] = U.learn(want)
    st.lastLearn = t.time
end

-- ===========================================================================
--  PART 14. PURCHASING
-- ===========================================================================

function Team:GoldOf(hero)
    return U.num(type(hero) == "table" and hero.gold or nil, 0)
end

function Team:BuildFor(t, hero, st)
    local hd = D.HEROES[hero.name]
    local build = {}
    if st.build and t.time - U.num(st.buildAt, -1000) < 25 then
        return st.build
    end
    if type(hd) == "table" and type(hd.build) == "table" then
        for i = 1, #hd.build do build[#build + 1] = hd.build[i] end
    else
        local pos = U.num(hero.position, 5)
        if pos <= 2 then
            build = { "item_power_treads", "item_magic_wand", "item_black_king_bar",
                      "item_ultimate_scepter", "item_shivas_guard", "item_sheepstick" }
        elseif pos == 3 then
            build = { "item_phase_boots", "item_blade_mail", "item_blink", "item_crimson_guard",
                      "item_pipe", "item_heart" }
        else
            build = { "item_magic_wand", "item_arcane_boots", "item_glimmer_cape",
                      "item_force_staff", "item_ultimate_scepter", "item_sheepstick" }
        end
    end

    local pos = U.num(hero.position, 5)
    local magicN = self:CountEnemyMatching(t, D.MAGIC_HEROES)
    local physN = self:CountEnemyMatching(t, D.PHYS_HEROES)
    local healN = self:CountEnemyMatching(t, D.HEAL_HEROES)
    local insertAt = U.min(#build + 1, 5)

    local function insertItem(name, at)
        if type(name) ~= "string" then return end
        if U.contains(build, name) then return end
        at = U.clamp(U.num(at, insertAt), 1, #build + 1)
        table.insert(build, at, name)
    end

    if self:EnemyHasEvasion(t) and pos <= 2 then
        insertItem("item_monkey_king_bar", 5)
    end
    if magicN >= 2 or (self:EnemyHasItem(t, "item_black_king_bar") and magicN >= 1) then
        if pos <= 3 then insertItem("item_black_king_bar", 3) end
        if pos >= 4 then insertItem("item_pipe", 4) end
    end
    if physN >= 3 then
        if pos == 3 then insertItem("item_crimson_guard", 4) end
        if pos <= 2 then insertItem("item_assault", 6) end
        if pos >= 4 then insertItem("item_ghost", 5) end
    end
    if healN >= 2 then
        if pos >= 4 then insertItem("item_spirit_vessel", 4) end
        if pos <= 2 then insertItem("item_skadi", 7) end
    end
    if t.enemyInvis then
        if pos >= 4 and t.time > 1200 then insertItem("item_gem", 7) end
        if pos <= 3 then insertItem("item_dust", 4) end
    end

    st.build = build
    st.buildAt = t.time
    return build
end

-- buy the starting items once, optimistically counting every requested piece
function Team:BuyStart(t, hero, st, acts)
    if st.startDone then return end
    local hd = D.HEROES[hero.name]
    if type(hd) ~= "table" or type(hd.start) ~= "table" then
        st.startDone = true
        return
    end
    if t.time - U.num(st.lastStart, -1000) < 0.7 then return end
    st.lastStart = t.time
    local need, order = {}, {}
    local list = hd.start
    for i = 1, #list do
        local nm = list[i]
        if need[nm] == nil then
            need[nm] = 0
            order[#order + 1] = nm
        end
        need[nm] = need[nm] + 1
    end
    local sent = 0
    local all = true
    for i = 1, #order do
        local nm = order[i]
        if U.num(st.startBought[nm], 0) < need[nm] then
            all = false
            if sent < 2 then
                acts[#acts + 1] = U.buy(nm)
                st.startBought[nm] = U.num(st.startBought[nm], 0) + 1
                sent = sent + 1
            end
        end
    end
    if all then st.startDone = true end
end

function Team:NeedsDeward(t)
    if t.enemyInvis then return true end
    if U.num(t.time, 0) > 240 then return true end
    return false
end

-- immediate "spend it before dying" behaviour
function Team:BuyEmergency(t, hero, st, acts, build)
    local gold = self:GoldOf(hero)
    if gold < 50 then return end
    local pos = U.num(hero.position, 5)
    if pos >= 4 then
        if not U.hasItem(hero, "item_dust") and gold >= 80 then
            acts[#acts + 1] = U.buy("item_dust")
            return
        end
        if not U.hasItem(hero, "item_ward_sentry") and gold >= 50 then
            acts[#acts + 1] = U.buy("item_ward_sentry")
            return
        end
    end
    if not U.hasItem(hero, "item_tpscroll") and gold >= 100 then
        acts[#acts + 1] = U.buy("item_tpscroll")
        return
    end
    for i = 1, #build do
        local nm = build[i]
        if not U.hasItem(hero, nm) then
            if gold >= U.num(D.ITEM_VALUE[nm], 600) * 0.15 then
                acts[#acts + 1] = U.buy(nm)
            end
            return
        end
    end
end

function Team:BuyBuild(t, hero, st, acts, urgent)
    if not urgent and t.time - U.num(st.lastBuy, -1000) < 0.9 then return end
    local gold = self:GoldOf(hero)
    local pos = U.num(hero.position, 5)
    local build = self:BuildFor(t, hero, st)

    if urgent then
        self:BuyEmergency(t, hero, st, acts, build)
        return
    end

    -- 1) TP scroll is never negotiable
    if not U.hasItem(hero, "item_tpscroll") and gold >= 100 then
        acts[#acts + 1] = U.buy("item_tpscroll")
        st.lastBuy = t.time
        return
    end

    -- 2) support consumables
    if pos >= 4 then
        if not U.hasItem(hero, "item_ward_observer") and not U.hasItem(hero, "item_ward_dispenser")
            and gold >= 50 then
            acts[#acts + 1] = U.buy("item_ward_observer")
            st.lastBuy = t.time
            return
        end
        if t.enemyInvis and gold >= 80 and not U.hasItem(hero, "item_dust") then
            acts[#acts + 1] = U.buy("item_dust")
            st.lastBuy = t.time
            return
        end
        if gold >= 50 and not U.hasItem(hero, "item_smoke_of_deceit")
            and t.time - U.num(st.smokeAt, -1000) > 75 and t.time > 150 then
            acts[#acts + 1] = U.buy("item_smoke_of_deceit")
            st.smokeAt = t.time
            st.lastBuy = t.time
            return
        end
        if (t.enemyInvis or self:NeedsDeward(t)) and gold >= 50
            and not U.hasItem(hero, "item_ward_sentry") and not U.hasItem(hero, "item_ward_dispenser") then
            acts[#acts + 1] = U.buy("item_ward_sentry")
            st.lastBuy = t.time
            return
        end
    end

    -- 3) main item progression (keep a buyback reserve for cores in the late game)
    local reserve = 0
    if t.time > 1000 and pos <= 3 then
        reserve = U.num(hero.buybackCost, 0)
    end
    for i = 1, #build do
        local nm = build[i]
        if not U.hasItem(hero, nm) then
            local cost = U.num(D.ITEM_VALUE[nm], 600)
            local need = cost * 0.22
            if i <= 2 then need = U.min(need, 150) end
            if gold >= need + reserve then
                acts[#acts + 1] = U.buy(nm)
                st.lastBuy = t.time
            end
            return
        end
    end
end

-- ===========================================================================
--  PART 15. INVENTORY MANAGER
-- ===========================================================================

function Team:ItemValue(hero, name)
    if type(name) ~= "string" then return 0 end
    return U.num(D.ITEM_VALUE[name], D.ITEM_VALUE_DEFAULT)
end

function Team:CountOccupied(u, lo, hi)
    local it = U.items(u)
    local n = 0
    for s = lo, hi do
        if type(it[s]) == "string" and it[s] ~= "" then n = n + 1 end
    end
    return n
end

function Team:FindWeakMainSlot(u, hero)
    local it = U.items(u)
    local slot, val = nil, nil
    for s = 0, 5 do
        local nm = it[s]
        if type(nm) ~= "string" then
            return s, -1
        end
        local v = self:ItemValue(hero, nm)
        if D.KEEP[nm] then v = v + 5000 end
        if not val or v < val then slot, val = s, v end
    end
    return slot, val
end

function Team:InventoryManager(t, hero, st, acts)
    local items = U.items(hero)
    local atBase = self:IsAtBase(t, hero)
    local dead = not U.alive(hero)

    -- 1) retrieve items abandoned in the stash
    if (atBase or dead) and t.time - U.num(st.lastSwap, -1000) > 0.4 then
        for s = 9, 14 do
            local nm = items[s]
            if type(nm) == "string" then
                local free = nil
                for m = 0, 5 do
                    if type(items[m]) ~= "string" then free = m break end
                end
                if free then
                    acts[#acts + 1] = U.swap(s, free)
                    st.lastSwap = t.time
                    return
                end
            end
        end
    end

    -- 2) bring strong backpack items into the active inventory
    if t.time - U.num(st.lastSwap, -1000) > 6.3 then
        local weakestSlot, weakestVal = nil, nil
        local freeMain = nil
        for s = 0, 5 do
            local nm = items[s]
            if type(nm) ~= "string" then
                if not freeMain then freeMain = s end
            else
                local v = self:ItemValue(hero, nm)
                if D.KEEP[nm] then v = v + 5000 end
                if not weakestVal or v < weakestVal then
                    weakestSlot, weakestVal = s, v
                end
            end
        end
        for s = 6, 8 do
            local nm = items[s]
            if type(nm) == "string" then
                local v = self:ItemValue(hero, nm)
                if freeMain then
                    acts[#acts + 1] = U.swap(s, freeMain)
                    st.lastSwap = t.time
                    return
                elseif weakestSlot and v > (weakestVal or 0) + 400 and (weakestVal or 0) < 2000 then
                    acts[#acts + 1] = U.swap(s, weakestSlot)
                    st.lastSwap = t.time
                    return
                end
            end
        end
    end

    -- 3) sell outdated junk while at the shop / dead
    if (atBase or dead) and t.time - U.num(st.lastSell, -1000) > 1.2 then
        local occupied = self:CountOccupied(hero, 0, 8)
        if occupied >= 6 then
            for s = 0, 8 do
                local nm = items[s]
                if type(nm) == "string" and D.TRASH[nm] and not D.KEEP[nm] then
                    acts[#acts + 1] = U.sellSlot(s)
                    st.lastSell = t.time
                    return
                end
            end
        end
    end

    -- 4) drop junk when the courier needs a slot far from the base
    if not atBase and not dead and t.time - U.num(st.lastDrop, -1000) > 4 then
        local occupied = self:CountOccupied(hero, 0, 8)
        if occupied >= 9 then
            local build = self:BuildFor(t, hero, st)
            local want = nil
            for i = 1, #build do
                if not U.hasItem(hero, build[i]) then
                    want = build[i]
                    break
                end
            end
            if want then
                local worstSlot, worstVal = nil, nil
                for s = 0, 5 do
                    local nm = items[s]
                    if type(nm) == "string" and D.TRASH[nm] and not D.KEEP[nm] then
                        local v = self:ItemValue(hero, nm)
                        if not worstVal or v < worstVal then worstSlot, worstVal = s, v end
                    end
                end
                if worstSlot then
                    st.forceDrop = worstSlot
                    st.lastDrop = t.time
                end
            end
        end
    end
end

-- ===========================================================================
--  PART 16. SPELL RULE ENGINE
-- ===========================================================================

function Team:FocusUnit(t)
    local u = t.focus
    if type(u) == "table" and U.alive(u) and t.enemyById[u.id] ~= nil
        and u.invulnerable ~= true then
        return u
    end
    return nil
end

function Team:BestKillTarget(t, hero, range)
    local myPos = U.unitPos(hero)
    if not myPos then return nil end
    local best, bestScore = nil, -1
    for i = 1, #t.enemyHeroes do
        local e = t.enemyHeroes[i]
        local ep = U.unitPos(e)
        if U.alive(e) and ep then
            local d = U.dist(myPos, ep)
            if d <= range + 100 then
                local score = (100 - U.hpPct(e)) * 2
                if e.magicImmune == true then score = score - 80 end
                if U.isStunned(e) then score = score + 30 end
                if U.isKind(e, "hero") and e.channeling == true then score = score + 60 end
                score = score - d / 100
                if score > bestScore then best, bestScore = e, score end
            end
        end
    end
    return best
end

function Team:SpellAction(t, hero, st, r)
    if not U.abilReady(hero, r.a) then return nil end
    if U.num(r.minLevel, 0) > U.abilLevel(hero, r.a) then return nil end
    local myPos = U.unitPos(hero)
    if not myPos then return nil end
    local hpPct = U.hpPct(hero)
    if r.hpBelow and hpPct >= r.hpBelow then return nil end
    if r.hpAbove and hpPct <= r.hpAbove then return nil end
    if r.manaAbove and U.manaPct(hero) < r.manaAbove then return nil end

    local targetMode = U.str(r.target, "focus")
    local range = U.num(r.range, U.abilRange(hero, r.a, 700))
    local tgt = nil

    if targetMode == "focus" or targetMode == "focuspos" then
        tgt = self:FocusUnit(t)
        if tgt and U.dist(myPos, U.unitPos(tgt)) > range + 120 then tgt = nil end
        if not tgt then tgt = self:NearestEnemyHero(t, myPos, range + 100) end
        if not tgt then return nil end
    elseif targetMode == "nearest" or targetMode == "nearestpos" then
        tgt = self:NearestEnemyHero(t, myPos, range + 60)
        if not tgt then return nil end
    elseif targetMode == "enemylow" then
        tgt = self:BestKillTarget(t, hero, range)
        if not tgt then return nil end
    elseif targetMode == "allylow" then
        tgt = self:LowestHpAlly(t, myPos, range, U.num(r.allyHpBelow, 65))
        if not tgt then return nil end
    elseif targetMode == "self" then
        if r.range then
            local e = self:NearestEnemyHero(t, myPos, r.range)
            if not e then return nil end
        end
        tgt = hero
    elseif targetMode == "selfpos" then
        tgt = hero
    else
        return nil
    end

    local center = myPos
    if (targetMode == "focuspos" or targetMode == "focus" or targetMode == "enemylow") and tgt then
        center = U.unitPos(tgt) or myPos
    end
    if r.minEnemies and self:CountEnemiesNear(t, center, U.num(r.radius, 800), true) < r.minEnemies then
        return nil
    end
    if r.maxEnemies and tgt and self:CountEnemiesNear(t, U.unitPos(tgt), 700, true) > r.maxEnemies then
        return nil
    end
    if r.tHpBelow and tgt and U.hpPct(tgt) > r.tHpBelow then return nil end
    if r.allyHpBelow then
        local ally = self:LowestHpAlly(t, myPos, U.num(r.radius, 900), r.allyHpBelow)
        if not ally and hpPct >= r.allyHpBelow then return nil end
    end

    -- never waste magic on BKB targets, never stack a disable on a disabled target
    local enemyTarget = targetMode == "focus" or targetMode == "focuspos"
        or targetMode == "nearest" or targetMode == "nearestpos" or targetMode == "enemylow"
    if enemyTarget and type(tgt) == "table" and tgt.id ~= hero.id then
        if tgt.invulnerable == true then return nil end
        if tgt.magicImmune == true and D.PHYSICAL_SPELLS[r.a] ~= true then return nil end
        if U.isStunned(tgt) and D.DISABLE_SPELLS[r.a] == true then return nil end
        if D.CHANNEL_TARGETED[r.a] == true and not U.isStunned(tgt) then return nil end
    end

    if targetMode == "selfpos" or targetMode == "focuspos" then
        return U.cast(r.a, nil, U.unitPos(tgt) or myPos, "cast " .. r.a)
    elseif targetMode == "self" then
        return U.cast(r.a, nil, nil, "cast " .. r.a)
    else
        return U.cast(r.a, tgt.id, nil, "cast " .. r.a)
    end
end

-- try all programmed spells for the hero; returns one main action or nil
function Team:TrySpells(t, hero, st, modeSet)
    local hd = D.HEROES[hero.name]
    if type(hd) ~= "table" or type(hd.spells) ~= "table" then
        return self:GenericSpell(t, hero, st, modeSet)
    end
    local rules = hd.spells
    for i = 1, #rules do
        local r = rules[i]
        if type(r) == "table" and type(r.a) == "string" then
            if modeSet[U.str(r.mode, "fight")] == true then
                local act = self:SpellAction(t, hero, st, r)
                if act then return act end
            end
        end
    end
    return nil
end

function Team:GenericSpell(t, hero, st, modeSet)
    if not modeSet["fight"] and not modeSet["kill"] then return nil end
    local myPos = U.unitPos(hero)
    if not myPos then return nil end
    local tgt = self:FocusUnit(t)
    if not tgt or U.dist(myPos, U.unitPos(tgt)) > 900 then
        tgt = self:NearestEnemyHero(t, myPos, 900)
    end
    if not tgt then return nil end
    local ab = U.tbl(hero.abilities)
    for k, a in pairs(ab) do
        if type(a) == "table" and type(a.name) == "string" and not self:IsTalentName(a.name) then
            if U.abilReady(hero, a.name) and a.passive ~= true then
                local cr = U.num(a.castRange, 0)
                local mx = U.num(a.maxLevel, 4)
                if cr > 0 and cr <= 2000 and mx >= 1 then
                    if U.num(a.cooldown, 0) > 25 then
                        if self:CountEnemiesNear(t, U.unitPos(tgt), 700, true) >= 2 then
                            return U.cast(a.name, tgt.id, nil, "cast " .. a.name)
                        end
                    else
                        return U.cast(a.name, tgt.id, nil, "cast " .. a.name)
                    end
                end
            end
        end
    end
    return nil
end

-- ===========================================================================
--  PART 17. ITEM ACTIVE LOGIC
-- ===========================================================================

function Team:EnemyThreatNear(t, pos, radius)
    local magic, phys = 0, 0
    for i = 1, #t.enemyHeroes do
        local e = t.enemyHeroes[i]
        if U.alive(e) and U.dist(U.unitPos(e), pos) <= radius then
            local known = false
            if D.MAGIC_HEROES[e.name] == true then
                magic = magic + 1
                known = true
            end
            if D.PHYS_HEROES[e.name] == true then
                phys = phys + 1
                known = true
            end
            if not known then
                magic = magic + 1
                phys = phys + 1
            end
        end
    end
    return magic, phys
end

function Team:NearestEnemyPos(t, pos)
    local e = self:NearestEnemyHero(t, pos, 3000)
    return e and U.unitPos(e) or nil
end

function Team:ActiveItemAction(t, hero, st, ctx)
    local myPos = U.unitPos(hero)
    if not myPos then return nil end
    local hpPct = U.hpPct(hero)
    local mpPct = U.manaPct(hero)
    local fight = ctx.fight == true
    local danger = ctx.danger == true
    local safe = ctx.safe == true
    local noTarget, onSelf, onUnit = U.castItemNoTarget, U.castItemSelf, U.castItemOnUnit
    noTarget = function(item)
        return { kind = "cast", item = item, status = "use " .. item }
    end
    onSelf = function(item)
        return { kind = "cast", item = item, target_id = hero.id, status = "use " .. item }
    end
    onUnit = function(item, u)
        if type(u) ~= "table" or u.id == nil then return nil end
        return { kind = "cast", item = item, target_id = u.id, status = "use " .. item }
    end

    -- emergency consumables
    if U.itemReady(hero, "item_cheese") and hpPct < 35 then return noTarget("item_cheese") end
    if U.itemReady(hero, "item_famango") and (hpPct < 50 or mpPct < 35) then
        return onSelf("item_famango")
    end
    if U.itemReady(hero, "item_greater_famango") and (hpPct < 55 or mpPct < 45) then
        return onSelf("item_greater_famango")
    end
    if U.itemReady(hero, "item_great_famango") and (hpPct < 55 or mpPct < 45) then
        return onSelf("item_great_famango")
    end

    if fight or danger then
        if U.itemReady(hero, "item_satanic") and hpPct < 55 then return noTarget("item_satanic") end
        if U.itemReady(hero, "item_black_king_bar") and hpPct < 70 then
            local m = self:EnemyThreatNear(t, myPos, 950)
            if m >= 1 then return noTarget("item_black_king_bar") end
        end
        if U.itemReady(hero, "item_blade_mail") and hpPct < 75 then return noTarget("item_blade_mail") end
        if U.itemReady(hero, "item_ghost") and hpPct < 50 then
            local m, p = self:EnemyThreatNear(t, myPos, 900)
            if p >= 1 then return noTarget("item_ghost") end
        end
        if U.itemReady(hero, "item_wind_waker") and hpPct < 35 then return onSelf("item_wind_waker") end
        if U.itemReady(hero, "item_cyclone") and hpPct < 30 then return onSelf("item_cyclone") end
        if U.itemReady(hero, "item_glimmer_cape") and hpPct < 55 then return onSelf("item_glimmer_cape") end
        if U.itemReady(hero, "item_force_staff") and hpPct < 35 then return onSelf("item_force_staff") end
        if U.itemReady(hero, "item_blink") and hpPct < 25 then
            local awayFrom = self:NearestEnemyPos(t, myPos)
            if awayFrom then
                local away = U.pointAway(myPos, awayFrom, 900)
                if away then
                    return { kind = "cast", item = "item_blink", position = away, status = "blink out" }
                end
            end
        end
        if U.itemReady(hero, "item_manta") then
            if hero.stunned == true or hero.silenced == true or hero.hexed == true then
                return noTarget("item_manta")
            end
        end
        if U.itemReady(hero, "item_lotus_orb") then
            if hero.stunned == true or hero.silenced == true or hero.hexed == true then
                return onSelf("item_lotus_orb")
            end
        end
    end

    -- sustain out of combat
    if safe or not fight then
        if U.itemReady(hero, "item_magic_wand") and U.charges(hero, "item_magic_wand") >= 5 then
            if hpPct < 65 or mpPct < 45 then return noTarget("item_magic_wand") end
        end
        if U.itemReady(hero, "item_magic_stick") and U.charges(hero, "item_magic_stick") >= 7 then
            if hpPct < 60 or mpPct < 40 then return noTarget("item_magic_stick") end
        end
        if U.itemReady(hero, "item_flask") and hpPct < 68 and safe then return onSelf("item_flask") end
        if U.itemReady(hero, "item_clarity") and mpPct < 55 and safe then return onSelf("item_clarity") end
        if U.itemReady(hero, "item_bottle") and (hpPct < 75 or mpPct < 65) then return onSelf("item_bottle") end
        if U.itemReady(hero, "item_enchanted_mango") and mpPct < 40 then return onSelf("item_enchanted_mango") end
        if U.itemReady(hero, "item_soul_ring") and mpPct < 40 and hpPct > 55 then return noTarget("item_soul_ring") end
        if U.itemReady(hero, "item_arcane_boots") and mpPct < 50 then return noTarget("item_arcane_boots") end
        if U.itemReady(hero, "item_guardian_greaves") and hpPct < 60 then return noTarget("item_guardian_greaves") end
        if U.itemReady(hero, "item_mekansm") and hpPct < 60 then return noTarget("item_mekansm") end
        if U.itemReady(hero, "item_pipe") and hpPct < 70 then
            if self:CountAllyHeroesNear(t, myPos, 900, hero.id) >= 1 then return noTarget("item_pipe") end
        end
        if U.itemReady(hero, "item_crimson_guard") and hpPct < 70 then
            if self:CountAllyHeroesNear(t, myPos, 900, hero.id) >= 1 then return noTarget("item_crimson_guard") end
        end
        if U.itemReady(hero, "item_heavens_halberd") then
            local tgt = self:FocusUnit(t) or self:NearestEnemyHero(t, myPos, 600)
            if tgt and fight and tgt.disarmed ~= true then return onUnit("item_heavens_halberd", tgt) end
        end
    end

    -- combat actives
    if fight then
        local tgt = self:FocusUnit(t) or self:NearestEnemyHero(t, myPos, 800)
        if tgt and U.alive(tgt) then
            local inRange = U.dist(myPos, U.unitPos(tgt))
            if U.itemReady(hero, "item_sheepstick") and inRange <= 800 and U.isStunned(tgt) == false then
                return onUnit("item_sheepstick", tgt)
            end
            if U.itemReady(hero, "item_orchid") and inRange <= 900 and tgt.silenced ~= true then
                return onUnit("item_orchid", tgt)
            end
            if U.itemReady(hero, "item_bloodthorn") and inRange <= 900 and tgt.silenced ~= true then
                return onUnit("item_bloodthorn", tgt)
            end
            if U.itemReady(hero, "item_spirit_vessel") and inRange <= 950 then
                return onUnit("item_spirit_vessel", tgt)
            end
            if U.itemReady(hero, "item_urn_of_shadows") and inRange <= 950 then
                return onUnit("item_urn_of_shadows", tgt)
            end
            if U.itemReady(hero, "item_solar_crest") and inRange <= 700 then
                return onUnit("item_solar_crest", tgt)
            end
            if U.itemReady(hero, "item_dagon_5") and inRange <= 700 then
                return onUnit("item_dagon_5", tgt)
            end
        end
        if U.itemReady(hero, "item_shivas_guard") then
            if self:CountEnemiesNear(t, myPos, 700, true) >= 2 then return noTarget("item_shivas_guard") end
        end
        if U.itemReady(hero, "item_phase_boots") and hpPct > 30 then
            return noTarget("item_phase_boots")
        end
        if U.itemReady(hero, "item_refresher") and self:CountEnemiesNear(t, myPos, 800, true) >= 3 then
            return noTarget("item_refresher")
        end
        if U.itemReady(hero, "item_refresher_shard") and self:CountEnemiesNear(t, myPos, 800, true) >= 3 then
            return noTarget("item_refresher_shard")
        end
        if U.itemReady(hero, "item_veil_of_discord") then
            if self:CountEnemiesNear(t, myPos, 700, true) >= 2 then return noTarget("item_veil_of_discord") end
        end
        if U.itemReady(hero, "item_cyclone") then
            local tgt = self:FocusUnit(t)
            if tgt and U.dist(myPos, U.unitPos(tgt)) <= 600 and U.alive(tgt) then
                return onUnit("item_cyclone", tgt)
            end
        end
    end

    -- assist allies in danger
    if not fight and not safe then
        local ally = self:LowestHpAlly(t, myPos, 800, 45)
        if ally then
            if U.itemReady(hero, "item_glimmer_cape") then return onUnit("item_glimmer_cape", ally) end
            if U.itemReady(hero, "item_lotus_orb") then return onUnit("item_lotus_orb", ally) end
            if U.itemReady(hero, "item_force_staff") then return onUnit("item_force_staff", ally) end
        end
    end
    return nil
end

-- ===========================================================================
--  PART 18. VISION, DEWARD, INVISIBILITY COUNTERPLAY
-- ===========================================================================

function Team:TryDust(t, hero, st)
    if not t.enemyInvis then return nil end
    if not U.itemReady(hero, "item_dust") then return nil end
    local myPos = U.unitPos(hero)
    if not myPos then return nil end
    -- 1) invisible enemy hero vanished very recently nearby
    for id, e in pairs(t.lastSeen) do
        if type(e) == "table" and type(e.name) == "string" then
            local isInvis = D.INVIS_HEROES[e.name] == true
            if not isInvis then
                local it = U.tbl(e.items)
                for s = 0, 16 do
                    if D.INVIS_ITEMS[it[s]] == true then isInvis = true break end
                end
            end
            local at = U.num(e.at, -1000)
            local visibleNow = t.enemyById[id] ~= nil
            if isInvis and not visibleNow and t.time - at <= 2.6 then
                local d = U.dist(myPos, e.pos)
                if d <= 950 then
                    return { kind = "cast", item = "item_dust", status = "dust" }
                end
            end
        end
    end
    -- 2) invisible-capable enemy fighter right next to us
    for i = 1, #t.enemyHeroes do
        local e = t.enemyHeroes[i]
        if U.alive(e) and U.dist(myPos, U.unitPos(e)) <= 650 then
            local it = U.items(e)
            local hasInvisItem = false
            for s = 0, 5 do
                if D.INVIS_ITEMS[it[s]] == true then hasInvisItem = true break end
            end
            if hasInvisItem or D.INVIS_HEROES[e.name] == true then
                if U.hpPct(e) < 80 then
                    return { kind = "cast", item = "item_dust", status = "dust" }
                end
            end
        end
    end
    return nil
end

function Team:TrySentry(t, hero, st)
    local hasSentry = U.itemReady(hero, "item_ward_sentry") or U.itemReady(hero, "item_ward_dispenser")
    if not hasSentry then return nil end
    local myPos = U.unitPos(hero)
    if not myPos then return nil end
    local spot = nil
    for id, e in pairs(t.lastSeen) do
        if type(e) == "table" and D.INVIS_HEROES[e.name] == true then
            local at = U.num(e.at, -1000)
            if t.time - at <= 3 and t.enemyById[id] == nil then
                if U.dist(myPos, e.pos) <= 700 then
                    spot = e.pos
                end
            end
        end
    end
    if spot and self:CountEnemiesNear(t, myPos, 600, false) == 0 then
        return { kind = "cast", item = "item_ward_sentry", position = U.copyPos(spot), status = "sentry" }
    end
    return nil
end

function Team:ChooseWardSpot(t, hero)
    local myPos = U.unitPos(hero)
    if not myPos then return nil end
    local enemySide = self:PinsOf(t, "ward_spot")
    local mine, others = {}, {}
    for i = 1, #enemySide do
        local p = enemySide[i]
        if U.num(p.mapTeam, 0) == t.enemyTeam then mine[#mine + 1] = p
        else others[#others + 1] = p end
    end

    local target, bestD = nil, 1000000
    if t.siegeTarget then
        local siegePos = U.unitPos(t.siegeTarget)
        for i = 1, #mine do
            local d = U.dist(mine[i].pos, siegePos)
            if d < bestD then target, bestD = mine[i], d end
        end
    end
    if not target and t.defendBuilding then
        local dp = U.unitPos(t.defendBuilding)
        for i = 1, #others do
            local d = U.dist(others[i].pos, dp)
            if d < bestD then target, bestD = others[i], d end
        end
    end
    if not target and t.roshanPos then
        for i = 1, #others do
            local d = U.dist(others[i].pos, t.roshanPos)
            if d < bestD then target, bestD = others[i], d end
        end
    end
    if not target then
        -- default: our side of the river near the mid lane
        for i = 1, #others do
            local d = U.dist(others[i].pos, myPos)
            if d < bestD then target, bestD = others[i], d end
        end
    end
    if not target then
        for i = 1, #mine do
            local d = U.dist(mine[i].pos, myPos)
            if d < bestD then target, bestD = mine[i], d end
        end
    end
    return target
end

-- returns a main action (ward placement / deward attack) or nil
function Team:VisionAction(t, hero, st)
    local myPos = U.unitPos(hero)
    if not myPos then return nil end
    local pos5 = U.num(hero.position, 5)
    if pos5 < 4 then
        -- cores still break visible enemy wards they are standing next to
        for i = 1, #t.enemyWards do
            local w = t.enemyWards[i]
            if U.alive(w) and U.dist(myPos, U.unitPos(w)) <= 500 then
                return U.wardFocus(w.id, "deward")
            end
        end
        return nil
    end

    -- break visible enemy wards first
    local enemyClose = self:CountEnemiesNear(t, myPos, 700, true)
    for i = 1, #t.enemyWards do
        local w = t.enemyWards[i]
        if U.alive(w) then
            local d = U.dist(myPos, U.unitPos(w))
            if d <= 900 and (enemyClose == 0 or d <= 400) then
                return U.wardFocus(w.id, "deward")
            end
        end
    end

    -- anti-invis dust / sentry
    local dust = self:TryDust(t, hero, st)
    if dust then return dust end
    if t.enemyInvis then
        local sentry = self:TrySentry(t, hero, st)
        if sentry and self:CountEnemiesNear(t, myPos, 800, true) == 0 then return sentry end
    end

    -- reveal enemy vision around the objective we are playing
    if U.itemReady(hero, "item_ward_sentry") and t.enemyInvis
        and (t.siegeTarget or t.roshanActive or t.defendBuilding) then
        local spot = self:ChooseWardSpot(t, hero)
        if spot and type(spot.pos) == "table" and U.dist(myPos, spot.pos) <= 650
            and self:CountEnemiesNear(t, myPos, 900, true) == 0 then
            return { kind = "cast", item = "item_ward_sentry", position = U.copyPos(spot.pos), status = "sentry" }
        end
    end

    -- ward placement
    local hasObs = U.itemReady(hero, "item_ward_observer") or U.itemReady(hero, "item_ward_dispenser")
    if hasObs and self:CountEnemiesNear(t, myPos, 850, true) == 0 then
        local spot = self:ChooseWardSpot(t, hero)
        if spot and type(spot.pos) == "table" and U.dist(myPos, spot.pos) <= 600 then
            local existing = false
            for i = 1, #t.allyWards do
                local w = t.allyWards[i]
                if U.kind(w) == "observer_ward" and U.alive(w)
                    and U.dist(U.unitPos(w), spot.pos) <= 600 then
                    existing = true
                end
            end
            if not existing then
                return { kind = "cast", item = "item_ward_observer", position = U.copyPos(spot.pos), status = "ward" }
            end
        end
    end
    return nil
end

-- ===========================================================================
--  PART 19. MACRO BRAIN
-- ===========================================================================

function Team:TeamCentroid(t)
    local sx, sy, sz, n = 0, 0, 0, 0
    for i = 1, #t.mine do
        local h = t.mine[i]
        if U.alive(h) then
            local p = U.unitPos(h)
            if p then
                sx = sx + U.coord(p, "x")
                sy = sy + U.coord(p, "y")
                sz = sz + U.coord(p, "z")
                n = n + 1
            end
        end
    end
    if n == 0 then return nil end
    return U.pos(sx / n, sy / n, sz / n)
end

function Team:CarryHero(t)
    for i = 1, #t.mine do
        if U.num(t.mine[i].position, 9) == 1 then return t.mine[i] end
    end
    return t.mine[1]
end

function Team:RetreatPoint(t, hero)
    local pos = U.unitPos(hero)
    if not pos then return t.fountain end
    local fountain = t.fountain or U.pos(0, 0, 0)
    local best, bestD = fountain, 1000000
    for i = 1, #t.allyBuildings do
        local b = t.allyBuildings[i]
        if U.alive(b) then
            local bp = U.unitPos(b)
            if bp then
                local dHero = U.dist(bp, pos)
                local dFountain = U.dist(bp, fountain)
                if dFountain < U.dist(pos, fountain) and dHero < 3000 then
                    if dHero < bestD then best, bestD = bp, dHero end
                end
            end
        end
    end
    return best
end

function Team:BuildingUrgency(b)
    local k = U.kind(b)
    local tier = U.num(b.tier, 0)
    local w = 20
    if k == "ancient" then
        w = 140
    elseif k == "building" then
        w = 120
    elseif k == "barracks" then
        w = 100
    elseif k == "tower" then
        if tier >= 4 then w = 95
        elseif tier == 3 then w = 85
        elseif tier == 2 then w = 60
        else w = 35 end
    end
    w = w + (100 - U.hpPct(b)) * 0.6
    return w
end

function Team:FindThreats(t)
    local list = {}
    for i = 1, #t.allyBuildings do
        local b = t.allyBuildings[i]
        if U.alive(b) then
            local bp = U.unitPos(b)
            local attacked = b.underAttack == true
            local hp = U.hpPct(b)
            local enemies = self:CountEnemiesNear(t, bp, 1400, true)
            if attacked or (hp < 45 and enemies > 0) then
                list[#list + 1] = {
                    b = b, enemies = enemies, hp = hp, pos = bp,
                    score = self:BuildingUrgency(b) + enemies * 6,
                }
            end
        end
    end
    table.sort(list, function(a, b) return a.score > b.score end)
    return list
end

function Team:DetectFight(t)
    local best, bestScore = nil, -1
    for i = 1, #t.enemyHeroes do
        local e = t.enemyHeroes[i]
        local ep = U.unitPos(e)
        if U.alive(e) and ep then
            local allies = self:CountAllyHeroesNear(t, ep, 1500)
            if allies >= 1 then
                local enemies = self:CountEnemiesNear(t, ep, 1700, true)
                local score = allies * 12 + enemies * 8 + (100 - U.hpPct(e)) * 0.4
                if score > bestScore then
                    best, bestScore = e, score
                end
            end
        end
    end
    if not best then return false, nil, 0, 0 end
    local pos = U.unitPos(best)
    local enemies = self:CountEnemiesNear(t, pos, 1700, true)
    local allies = self:CountAllyHeroesNear(t, pos, 1900)
    return true, pos, enemies, allies
end

function Team:ChooseFocus(t)
    local best, bestScore = nil, -1
    local center = (t.fightActive and t.fightPos) or t.teamCentroid
    for i = 1, #t.enemyHeroes do
        local e = t.enemyHeroes[i]
        if U.alive(e) and e.invulnerable ~= true then
            local ep = U.unitPos(e)
            if ep then
                local s = (100 - U.hpPct(e)) * 1.6
                if e.channeling == true then s = s + 75 end
                if U.isStunned(e) then s = s + 22 end
                if e.magicImmune == true then s = s - 35 end
                if U.hp(e) < 450 then s = s + 30 end
                if U.maxHp(e) < 1300 then s = s + 14 end
                if center then s = s - U.dist(ep, center) / 60 end
                if t.fightPos and U.dist(ep, t.fightPos) < 700 then s = s + 20 end
                if s > bestScore then best, bestScore = e, s end
            end
        end
    end
    return best
end

function Team:ChooseSiegeTarget(t)
    local best, bestScore = nil, -1
    local center = t.teamCentroid
    for i = 1, #t.enemyBuildings do
        local b = t.enemyBuildings[i]
        if U.alive(b) and b.invulnerable ~= true and b.attackImmune ~= true then
            local bp = U.unitPos(b)
            if bp and center then
                local k = U.kind(b)
                local tier = U.num(b.tier, 0)
                local w = 0
                local dist = U.dist(bp, center)
                if k == "ancient" then
                    w = w + 300
                    if dist > 4200 then w = -2000 end
                elseif k == "building" then
                    w = w + 260
                    if dist > 4200 then w = -2000 end
                elseif k == "barracks" then
                    w = w + 220
                    if dist > 4200 then w = -2000 end
                elseif k == "tower" then
                    if tier >= 4 then w = w + 190
                    elseif tier == 3 then w = w + 160
                    elseif tier == 2 then w = w + 100
                    else w = w + 55 end
                    if tier >= 2 and dist > 7000 then w = -2000 end
                end
                if dist > 9000 then w = -2000 end
                if w > -500 then
                    local creeps = self:CountAllyCreepsNear(t, bp, 1300)
                    local enemies = self:CountEnemiesNear(t, bp, 1600, true)
                    w = w + creeps * 8 - enemies * 22
                    w = w - dist / 160
                    if k == "tower" and tier <= 2 and U.hpPct(b) < 40 then w = w + 25 end
                    if w > bestScore then best, bestScore = b, w end
                end
            end
        end
    end
    return best
end

function Team:FindRoshan(t)
    local unit = nil
    for i = 1, #t.neutralsList do
        if U.kind(t.neutralsList[i]) == "roshan" then
            unit = t.neutralsList[i]
            break
        end
    end
    local pos = unit and U.unitPos(unit) or nil
    if not pos then
        local pin = self:FindPin(t, "roshan")
        if pin and type(pin.pos) == "table" then pos = pin.pos end
    end
    return unit, pos
end

function Team:FindTormentor(t)
    local unit = nil
    for i = 1, #t.neutralsList do
        if U.kind(t.neutralsList[i]) == "tormentor" then
            unit = t.neutralsList[i]
            break
        end
    end
    local pos = unit and U.unitPos(unit) or nil
    if not pos then
        local pin = self:FindPin(t, "tormentor")
        if pin and type(pin.pos) == "table" then pos = pin.pos end
    end
    return unit, pos
end

function Team:RoshanDecision(t)
    local unit, pos = self:FindRoshan(t)
    if not pos then return false, nil, nil end
    if t.time < 600 then return false, nil, nil end
    if V.team.roshanDeadUntil and t.time < V.team.roshanDeadUntil then
        return false, nil, nil
    end
    -- keep track of Roshan's life to detect a kill / respawn window
    if type(unit) == "table" and U.alive(unit) then
        V.team.roshanSeenAt = t.time
        V.team.roshanHp = U.hp(unit)
    elseif V.team.roshanSeenAt and t.time - V.team.roshanSeenAt > 2.5 then
        local nearPit = self:CountAllyHeroesNear(t, pos, 2800) >= 1
        if nearPit then
            local rs = type(t.schedule) == "table" and t.schedule.roshan or nil
            local respawn = 300
            if type(rs) == "table" then respawn = U.num(rs.respawnMin, 300) end
            V.team.roshanDeadUntil = t.time + respawn
            V.team.roshanSeenAt = nil
            return false, nil, nil
        end
    end
    if t.aliveMine < 4 then return false, nil, nil end
    if t.avgHpMine < 60 then return false, nil, nil end
    local enemiesNear = self:CountEnemiesNear(t, pos, 2600, true)
    if enemiesNear >= 2 then return false, nil, nil end
    local oursNear = self:CountAllyHeroesNear(t, pos, 3200)
    local strong = (t.aliveEnemies <= 2) or (t.avgHpMine > 75 and t.aliveEnemies <= 3)
    if oursNear >= 2 and strong then
        return true, unit, pos
    end
    if unit and U.alive(unit) and U.hpPct(unit) < 65 and oursNear >= 2 then
        return true, unit, pos
    end
    -- proactive grouping for Roshan only with a clear safety margin
    if t.time > 1200 and t.aliveMine >= 4 and t.avgHpMine > 70 and t.aliveEnemies == 0
        and enemiesNear == 0 then
        return true, unit, pos
    end
    return false, nil, nil
end

function Team:TormentorDecision(t)
    if t.time < 900 then return false, nil, nil end
    if not t.tormentorActive then return false, nil, nil end
    local unit, pos = self:FindTormentor(t)
    if not pos then return false, nil, nil end
    if t.aliveMine < 3 or t.avgHpMine < 58 then return false, nil, nil end
    if t.aliveEnemies > 2 then return false, nil, nil end
    if V.team.tormentorDone and t.time < V.team.tormentorDone then return false, nil, nil end
    if self:CountEnemiesNear(t, pos, 2400, true) >= 2 then return false, nil, nil end
    if type(unit) == "table" and U.alive(unit) then
        V.team.tormentorSeenAt = t.time
    elseif V.team.tormentorSeenAt and t.time - V.team.tormentorSeenAt > 2.5
        and self:CountAllyHeroesNear(t, pos, 2600) >= 1 then
        V.team.tormentorDone = t.time + 600
        V.team.tormentorSeenAt = nil
        return false, nil, nil
    end
    return true, unit, pos
end

function Team:NearestOwnTower(t, pos, lane)
    local best, bestD = nil, 1000000
    for i = 1, #t.allyBuildings do
        local b = t.allyBuildings[i]
        if U.isTower(b) and U.alive(b) then
            if lane == nil or b.lane == lane or b.lane == nil then
                local d = U.dist(U.unitPos(b), pos)
                if d < bestD then best, bestD = b, d end
            end
        end
    end
    return best, bestD
end

-- where a hero should stand in his lane
function Team:LaneAnchor(t, hero)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    local lane = hero.lane
    local best, bestD = nil, 2600
    for i = 1, #t.allyCreeps do
        local c = t.allyCreeps[i]
        if U.alive(c) then
            local cp = U.unitPos(c)
            if cp then
                local same = true
                if lane ~= nil and c.lane ~= nil and c.lane ~= lane then same = false end
                if same then
                    local d = U.dist(cp, pos)
                    if d < bestD then best, bestD = c, d end
                end
            end
        end
    end
    if best then
        local fountain = t.fountain or pos
        return U.toward(U.unitPos(best), fountain, 300)
    end
    -- enemy creeps visible in lane: stand behind our side of them
    local ec, ecD = nil, 2000
    for i = 1, #t.enemyCreeps do
        local c = t.enemyCreeps[i]
        if U.alive(c) then
            local cp = U.unitPos(c)
            if cp then
                local same = true
                if lane ~= nil and c.lane ~= nil and c.lane ~= lane then same = false end
                if same then
                    local d = U.dist(cp, pos)
                    if d < ecD then ec, ecD = c, d end
                end
            end
        end
    end
    if ec then
        local fountain = t.fountain or pos
        return U.toward(U.unitPos(ec), fountain, 450)
    end
    local tower = self:NearestOwnTower(t, pos, lane)
    if tower then
        local to = U.unitPos(tower)
        local enemySide = t.enemyFountain or to
        return U.toward(to, enemySide, 750)
    end
    return nil
end

-- lane of a position/role for rotations
function Team:RoleLane(t, hero)
    local lane = hero.lane
    if type(lane) == "string" and lane ~= "" then return lane end
    local role = U.num(hero.position, 5)
    if role == 2 then return "mid" end
    local safe = (t.myTeam == 2) and "bot" or "top"
    local off = (t.myTeam == 2) and "top" or "bot"
    if role == 1 or role == 5 then return safe end
    return off
end

function Team:GlyphDecision(t)
    if t.glyphCd > 0 then return false end
    if t.time - U.num(V.team.lastGlyph, -1000) < 4 then return false end
    for i = 1, #t.threats do
        local th = t.threats[i]
        local b = th.b
        local k = U.kind(b)
        local tier = U.num(b.tier, 0)
        if th.enemies >= 1 then
            if k == "ancient" or k == "building" or k == "barracks" then return true end
            if k == "tower" and tier >= 3 then return true end
            if k == "tower" and tier == 2 and (th.hp < 80 or th.enemies >= 2) then return true end
            if k == "tower" and tier == 1 and th.hp < 40 and th.enemies >= 2 then return true end
        end
    end
    return false
end

function Team:BuybackDecision(t)
    if t.time - U.num(V.team.lastBuyback, -1000) < 45 then return nil end
    local candidates = {}
    for i = 1, #t.mine do
        local h = t.mine[i]
        if not U.alive(h) and h.buybackReady == true then
            local cost = U.num(h.buybackCost, 0)
            if cost > 0 and self:GoldOf(h) >= cost then
                candidates[#candidates + 1] = h
            end
        end
    end
    if #candidates == 0 then return nil end
    local critical = false
    for i = 1, #t.threats do
        local th = t.threats[i]
        local b = th.b
        local k = U.kind(b)
        local tier = U.num(b.tier, 0)
        if k == "ancient" or k == "building" or k == "barracks" then critical = true end
        if k == "tower" and tier >= 3 then critical = true end
    end
    if not critical and t.time > 1500 and t.fightActive and t.fightEnemies >= 2 then
        local myNear = self:CountAllyHeroesNear(t, t.fightPos, 1600)
        if myNear >= 2 then critical = true end
    end
    if not critical then return nil end
    return candidates[1]
end

-- special scheduled objectives: runes / lotus / wisdom
function Team:SpecialTasks(t)
    local special = {}
    local function assignFirst(heroList, task)
        for i = 1, #heroList do
            local h = heroList[i]
            if U.alive(h) and special[h.id] == nil then
                special[h.id] = task
                return true
            end
        end
        return false
    end

    -- bounty runes
    local bnext = self:ScheduleNext(t, "bounty")
    if bnext and bnext - t.time < 10 and bnext - t.time > -8 then
        local bountyPins = self:PinsOf(t, "bounty")
        if #bountyPins > 0 then
            for i = 1, #bountyPins do
                local p = bountyPins[i]
                if U.num(p.mapTeam, 0) == t.myTeam then
                    local task = { kind = "rune", pos = p.pos, what = "bounty" }
                    local pick = nil
                    local bestD = 4000
                    for j = 1, #t.mine do
                        local h = t.mine[j]
                        local role = U.num(h.position, 5)
                        if role >= 4 and U.alive(h) and special[h.id] == nil then
                            local d = U.dist(U.unitPos(h), p.pos)
                            if d < bestD then pick, bestD = h, d end
                        end
                    end
                    if pick then special[pick.id] = task end
                end
            end
        end
    end

    -- water / power runes for the mid player
    local wnext = self:ScheduleNext(t, "water")
    local pnext = self:ScheduleNext(t, "power")
    local nextRune = nil
    if wnext then nextRune = wnext end
    if pnext and (nextRune == nil or pnext < nextRune) then nextRune = pnext end
    if nextRune and nextRune - t.time < 10 and nextRune - t.time > -10 then
        local mid = nil
        for i = 1, #t.mine do
            if U.num(t.mine[i].position, 5) == 2 then mid = t.mine[i] end
        end
        if mid and U.alive(mid) then
            local rune = self:NearestRune(t, U.unitPos(mid), nil)
            local pos = rune and rune.pos or nil
            if not pos then
                local pin = self:NearestPin(t, "power", U.unitPos(mid))
                pos = pin and pin.pos or nil
            end
            if not pos and t.fountain and t.enemyFountain then
                pos = U.mid(t.fountain, t.enemyFountain)
            end
            if pos then special[mid.id] = { kind = "rune", pos = pos, what = "power" } end
        end
    end

    -- lotus pools for hard support
    local lnext = self:ScheduleNext(t, "lotus")
    if lnext and lnext - t.time < 9 and lnext - t.time > -12 then
        local pins = self:PinsOf(t, "lotus")
        local best, bestD = nil, 3200
        for i = 1, #t.mine do
            local h = t.mine[i]
            local role = U.num(h.position, 5)
            if role >= 4 and U.alive(h) then
                for j = 1, #pins do
                    if pins[j].active ~= false then
                        local d = U.dist(U.unitPos(h), pins[j].pos)
                        if d < bestD then best, bestD = h, d end
                    end
                end
            end
        end
        if best then
            local nearest = nil
            local nd = 100000
            for j = 1, #pins do
                local d = U.dist(U.unitPos(best), pins[j].pos)
                if d < nd then nearest, nd = pins[j], d end
            end
            if nearest then
                special[best.id] = { kind = "lotus", pos = nearest.pos, targetId = nearest.targetId }
            end
        end
    end

    -- wisdom shrines: send the support with the lowest level
    local wdnext = self:ScheduleNext(t, "wisdom")
    if wdnext and wdnext - t.time < 16 and wdnext - t.time > -20 then
        local shrine = nil
        local pins = self:PinsOf(t, "wisdom")
        local low = nil
        for i = 1, #t.mine do
            local h = t.mine[i]
            if U.alive(h) and U.num(h.position, 5) >= 4 then
                if not low or U.unitLevel(h) < U.unitLevel(low) then low = h end
            end
        end
        if low then
            local bestD = 6000
            for j = 1, #pins do
                if U.num(pins[j].mapTeam, 0) == t.myTeam or U.num(pins[j].mapTeam, 0) == 0 then
                    local d = U.dist(U.unitPos(low), pins[j].pos)
                    if d < bestD then shrine, bestD = pins[j], d end
                end
            end
            if shrine then
                special[low.id] = { kind = "wisdom", pos = shrine.pos, targetId = shrine.targetId }
            end
        end
    end

    t.taskSpecial = special
end

function Team:TeamThink(t)
    t.threats = self:FindThreats(t)
    t.defendBuilding = t.threats[1] and t.threats[1].b or nil
    t.defendPos = t.threats[1] and t.threats[1].pos or nil
    t.teamCentroid = self:TeamCentroid(t)

    local fightActive, fightPos, fightEnemies, fightAllies = self:DetectFight(t)
    t.fightActive = false
    t.fightPos = nil
    t.fightEnemies = 0
    -- a fight is a team fight when enough bodies are involved
    if fightActive and fightPos then
        local take = false
        if fightEnemies >= 2 and fightAllies >= 2 then take = true end
        if fightEnemies >= 1 and fightAllies >= 3 then take = true end
        if t.defendBuilding and self:CountEnemiesNear(t, U.unitPos(t.defendBuilding), 1400, true) >= 1 then
            take = true
        end
        if t.time < 240 and fightEnemies >= 2 and fightAllies >= 2 then take = true end
        if take then
            t.fightActive = true
            t.fightPos = fightPos
            t.fightEnemies = fightEnemies
        end
    end
    t.focus = self:ChooseFocus(t)
    t.focusPos = t.focus and U.unitPos(t.focus) or nil

    -- siege target only with a real advantage
    t.siegeTarget = nil
    t.siegePos = nil
    local adv = false
    if t.aliveMine >= 3 and t.aliveEnemies <= 1 then adv = true end
    if t.aliveMine >= 4 and t.aliveEnemies <= 2 and t.avgHpMine > 55 then adv = true end
    if t.aliveMine >= 3 and t.aliveEnemies == 0 then adv = true end
    if t.fightActive and t.fightEnemies > 0 and t.aliveMine > t.aliveEnemies + 1 and t.avgHpMine > 60 then
        adv = true
    end
    local siege = self:ChooseSiegeTarget(t)
    if siege and adv and t.time > 150 then
        local sp = U.unitPos(siege)
        local enemiesNear = self:CountEnemiesNear(t, sp, 1800, true)
        if enemiesNear <= 1 then
            t.siegeTarget = siege
            t.siegePos = sp
        end
    end

    -- roshan / tormentor
    local roshActive, roshUnit, roshPos = self:RoshanDecision(t)
    t.roshanActive = roshActive
    t.roshanUnit = roshUnit
    t.roshanPos = roshPos
    local torActive, torUnit, torPos = self:TormentorDecision(t)
    t.tormentorActive = torActive
    t.tormentorUnit = torUnit
    t.tormentorPos = torPos
    if torActive then t.tormentorActive = true end

    -- global retreat
    t.retreatGlobal = false
    if t.aliveMine <= 2 and t.aliveEnemies >= 3 and t.time > 300 then t.retreatGlobal = true end

    -- glyph / buyback / smoke
    t.glyphNeeded = self:GlyphDecision(t)
    t.buybackHero = self:BuybackDecision(t)

    t.smokeReady = false
    if t.time - U.num(V.team.lastSmoke, -1000) > 100 and t.aliveMine >= 3 then
        local smokeCarrier = nil
        for i = 1, #t.mine do
            local h = t.mine[i]
            if U.alive(h) and U.num(h.position, 5) >= 4 and U.itemReady(h, "item_smoke_of_deceit") then
                smokeCarrier = h
                break
            end
        end
        if smokeCarrier then
            local grouped = self:CountAllyHeroesNear(t, U.unitPos(smokeCarrier), 900, smokeCarrier.id)
            if grouped >= 2 and self:CountEnemiesNear(t, U.unitPos(smokeCarrier), 1300, true) == 0 then
                t.smokeReady = true
                t.smokeHero = smokeCarrier
            end
        end
    end

    self:SpecialTasks(t)
    self:AssignTasks(t)
end

-- ===========================================================================
--  PART 20. TASK ASSIGNMENT
-- ===========================================================================

function Team:AssignTasks(t)
    t.task = {}
    local special = t.taskSpecial or {}
    for i = 1, #t.mine do
        local hero = t.mine[i]
        if U.alive(hero) then
            local pos = U.unitPos(hero)
            local hp = U.hpPct(hero)
            local task = nil
            if hp < 27 and pos and self:CountEnemiesNear(t, pos, 1000, true) > 0 then
                task = { kind = "retreat", pos = self:RetreatPoint(t, hero) }
            elseif special[hero.id] and pos
                and self:CountEnemiesNear(t, pos, 850, true) == 0 then
                task = special[hero.id]
            else
                task = self:ChooseTask(t, hero)
            end
            t.task[hero.id] = task
            local st = self:State(hero)
            st.task = task
            st.role = U.num(hero.position, 5)
        end
    end
end

function Team:ChooseTask(t, hero)
    local role = U.num(hero.position, 5)
    local pos = U.unitPos(hero)
    if not pos then return { kind = "lane" } end
    local hp = U.hpPct(hero)

    -- pre-game: contest bounty runes, look for first blood, otherwise retreat
    if t.time < 45 then
        local firstEnemy = self:NearestEnemyHero(t, pos, 950)
        if firstEnemy then
            local ep = U.unitPos(firstEnemy)
            local myNear = self:CountAllyHeroesNear(t, ep, 1100)
            local theirNear = self:CountEnemiesNear(t, ep, 1100, true)
            if myNear >= theirNear and myNear >= 2 then
                return { kind = "fight", pos = ep, target = firstEnemy }
            end
            if theirNear > myNear and t.time < 5 then
                return { kind = "retreat", pos = self:RetreatPoint(t, hero) }
            end
        end
    end
    if t.time < 14 then
        local bountyPins = self:PinsOf(t, "bounty")
        local owned = {}
        for i = 1, #bountyPins do
            if U.num(bountyPins[i].mapTeam, 0) == t.myTeam and type(bountyPins[i].pos) == "table" then
                owned[#owned + 1] = bountyPins[i]
            end
        end
        if #owned > 0 then
            local idx = 1
            if role == 3 or role == 4 then idx = 2 end
            if idx > #owned then idx = #owned end
            return { kind = "rune", pos = owned[idx].pos, what = "bounty" }
        end
    end
    if role >= 4 and t.time >= 14 and t.time < 70 then
        local hasObs = U.itemReady(hero, "item_ward_observer") or U.itemReady(hero, "item_ward_dispenser")
        if hasObs then
            local spot = self:ChooseWardSpot(t, hero)
            if spot and type(spot.pos) == "table" then
                return { kind = "ward", pos = spot.pos }
            end
        end
    end

    if hp < 27 and self:CountEnemiesNear(t, pos, 1000, true) > 0 then
        return { kind = "retreat", pos = self:RetreatPoint(t, hero) }
    end
    if t.retreatGlobal and role <= 3 and hp < 65 then
        return { kind = "retreat", pos = self:RetreatPoint(t, hero) }
    end

    -- defend our buildings
    if t.defendBuilding then
        local bp = U.unitPos(t.defendBuilding)
        if bp then
            local d = U.dist(pos, bp)
            local urg = self:BuildingUrgency(t.defendBuilding)
            local should = false
            local tier = U.num(t.defendBuilding.tier, 0)
            if U.isTower(t.defendBuilding) and tier <= 1 then
                -- a tier 1 is not worth abandoning the whole map for
                if d < 2000 then should = true end
                if role >= 4 and d < 4800 then should = true end
            else
                if d < 3000 then should = true end
                if urg >= 85 then should = true end
                if urg >= 60 and role >= 3 and d < 6000 then should = true end
            end
            if should then
                return { kind = "defend", target = t.defendBuilding, pos = bp }
            end
        end
    end

    -- team fight
    if t.fightActive and t.fightPos then
        local d = U.dist(pos, t.fightPos)
        local limit = 2600
        if role >= 4 then limit = 3400 end
        if t.fightEnemies >= 2 then limit = limit + 900 end
        if d <= limit then
            return { kind = "fight", pos = t.fightPos, target = t.focus }
        end
        if d > 2800 and role <= 2 and t.fightEnemies >= 2
            and self:CountAllyHeroesNear(t, t.fightPos, 1500) >= 2
            and U.hasItem(hero, "item_tpscroll")
            and self:CountEnemiesNear(t, pos, 1200, true) == 0 then
            return { kind = "fight", pos = t.fightPos, target = t.focus, joinByTp = true }
        end
    end

    -- roshan
    if t.roshanActive and t.roshanPos then
        local d = U.dist(pos, t.roshanPos)
        if d < 6000 then
            return { kind = "objective", target = t.roshanUnit, pos = t.roshanPos, what = "roshan" }
        end
    end
    if t.tormentorActive and t.tormentorPos then
        local d = U.dist(pos, t.tormentorPos)
        if d < 2800 then
            return { kind = "objective", target = t.tormentorUnit, pos = t.tormentorPos, what = "tormentor" }
        end
    end

    -- push
    if t.siegeTarget and t.siegePos then
        local d = U.dist(pos, t.siegePos)
        local creeps = self:CountAllyCreepsNear(t, t.siegePos, 1300)
        local limit = 9000
        if role >= 4 then limit = 6500 end
        if d < limit then
            if role <= 3 or creeps >= 1 or d < 3000 then
                return { kind = "push", target = t.siegeTarget, pos = t.siegePos }
            end
        end
    end

    -- default: lane / farm / follow
    if role == 5 then
        local carry = self:CarryHero(t)
        if carry and U.alive(carry) and carry.id ~= hero.id then
            local cp = U.unitPos(carry)
            if cp and U.dist(pos, cp) > 1500 and self:CountEnemiesNear(t, pos, 1000, true) == 0 then
                return { kind = "follow", pos = cp, target = carry }
            end
        end
    end
    if role == 4 then
        local anchor = self:LaneAnchor(t, hero)
        return { kind = "roam", pos = anchor }
    end
    local lane = self:LaneAnchor(t, hero)
    return { kind = "lane", pos = lane }
end

-- ===========================================================================
--  PART 21. HERO BEHAVIOURS
-- ===========================================================================

function Team:BestLastHit(t, hero, dmg, maxDist)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    local ranged = hero.ranged == true
    local limit = dmg * (ranged and 0.88 or 1.0)
    local best, bestHp = nil, nil
    local tower = self:NearestEnemyTower(t, pos)
    for i = 1, #t.enemyCreeps do
        local c = t.enemyCreeps[i]
        if U.alive(c) and U.hp(c) <= limit then
            local cp = U.unitPos(c)
            if cp then
                local d = U.dist(pos, cp)
                if d <= maxDist then
                    local safeFromTower = true
                    if tower then
                        local tp = U.unitPos(tower)
                        if U.dist(cp, tp) < U.TOWER_SAFE and self:CountAllyCreepsNear(t, tp, 700) == 0 then
                            safeFromTower = false
                        end
                    end
                    if safeFromTower then
                        if not bestHp or U.hp(c) < bestHp then
                            best, bestHp = c, U.hp(c)
                        end
                    end
                end
            end
        end
    end
    return best
end

function Team:BestDeny(t, hero, dmg, maxDist)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    local best, bestHp = nil, nil
    for i = 1, #t.allyCreeps do
        local c = t.allyCreeps[i]
        if U.alive(c) and c.deniable == true and U.hp(c) <= dmg * 0.95 then
            local cp = U.unitPos(c)
            if cp and U.dist(pos, cp) <= maxDist then
                if not bestHp or U.hp(c) < bestHp then
                    best, bestHp = c, U.hp(c)
                end
            end
        end
    end
    return best
end

function Team:HasSafeKill(t, hero)
    local pos = U.unitPos(hero)
    if not pos then return false end
    local enemy = self:NearestEnemyHero(t, pos, 700)
    if not enemy then return false end
    local myAllies = self:CountAllyHeroesNear(t, U.unitPos(enemy), 1200)
    local theirAllies = self:CountEnemiesNear(t, U.unitPos(enemy), 1200, true)
    if U.hpPct(enemy) < 35 and myAllies >= theirAllies then return true end
    return false
end

-- ---------------------------------------------------------------------------
--  lane
-- ---------------------------------------------------------------------------
function Team:LaneBehavior(t, hero, st, task)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    local hp = U.hpPct(hero)
    local role = U.num(hero.position, 5)
    local range = U.num(hero.attackRange, 150)
    local dmg = U.num(hero.attackDamage, 50)
    local enemiesNear = self:CountEnemiesNear(t, pos, 950, true)
    local enemyHero = self:NearestEnemyHero(t, pos, 1050)

    -- 1) survive
    if hp < 30 and enemiesNear >= 1 then
        local act = self:ActiveItemAction(t, hero, st, { danger = true, fight = true })
        if act then return act end
        return U.move(self:RetreatPoint(t, hero), "retreat")
    end

    -- 2) never stand under a hostile tower that has nothing to tank it
    local underTower, tower = self:UnderEnemyTower(t, pos)
    if underTower and tower then
        local busy = self:TowerHasCreeps(t, U.unitPos(tower))
        if not busy then
            local away = U.pointAway(pos, U.unitPos(tower), 450)
            if away then return U.move(away, "leave tower") end
        end
    end

    -- 3) fight the enemy laner when it makes sense
    if enemyHero then
        local ep = U.unitPos(enemyHero)
        local ed = U.dist(pos, ep)
        local myNear = self:CountAllyHeroesNear(t, ep, 1100)
        local theirNear = self:CountEnemiesNear(t, ep, 1100, true)
        local creepAggro = self:CountEnemyCreepsNear(t, pos, 500)
        local want = (hp > 45 and myNear >= theirNear and ed < range + 350
            and (creepAggro < 3 or U.unitLevel(hero) >= 5))
            or self:HasSafeKill(t, hero)
        if want and ed < range + 400 then
            local act = self:TrySpells(t, hero, st, { fight = true, kill = true, teamfight = true, always = true })
            if act then return act end
            local act2 = self:ActiveItemAction(t, hero, st, { fight = true })
            if act2 then return act2 end
            if ed <= range + 60 then return U.attack(enemyHero.id, "hit hero") end
            local chaseSafe = true
            local tw = self:NearestEnemyTower(t, ep)
            if tw and U.dist(ep, U.unitPos(tw)) < 950 then
                local busy = self:TowerHasCreeps(t, U.unitPos(tw))
                if not busy then chaseSafe = false end
            end
            if chaseSafe then return U.attackMove(ep, "chase") end
            return U.hold("no dive")
        end
    end

    -- 4) sustain out of combat
    local act3 = self:ActiveItemAction(t, hero, st, {
        fight = (enemyHero ~= nil and U.dist(pos, U.unitPos(enemyHero)) < 700),
        safe = (enemiesNear == 0),
    })
    if act3 then return act3 end

    -- 5) spells: harass and sustain
    if enemyHero then
        local act5 = self:TrySpells(t, hero, st, { fight = true, kill = true, always = true })
        if act5 then return act5 end
    else
        local act6 = self:TrySpells(t, hero, st, { always = true })
        if act6 and U.hpPct(hero) < 88 then return act6 end
    end

    -- 6) last hits and denies
    local carry = self:CarryHero(t)
    local carryNear = carry and U.alive(carry) and carry.id ~= hero.id
        and U.dist(U.unitPos(carry), pos) < 1300
    local allowFarm = (role <= 3) or not carryNear
    if allowFarm then
        local creep = self:BestLastHit(t, hero, dmg, range + 700)
        if creep then return U.attack(creep.id, "last hit") end
    end
    local deny = self:BestDeny(t, hero, dmg, range + 300)
    if deny then return U.deny(deny.id, "deny") end

    -- 7) harass
    if enemyHero then
        local ep = U.unitPos(enemyHero)
        local ed = U.dist(pos, ep)
        local safeHarass = ed <= range + 220
        if safeHarass and (role >= 4 or U.hpPct(enemyHero) < 60) then
            local under = self:UnderEnemyTower(t, ep, 250)
            local creepShield = self:CountEnemyCreepsNear(t, ep, 500) < 2
            if not under and (creepShield or role >= 4) then
                return U.attack(enemyHero.id, "harass")
            end
        end
    end

    -- 8) chip an exposed enemy building
    local tower2 = self:NearestEnemyTower(t, pos)
    if tower2 and U.alive(tower2) and tower2.invulnerable ~= true
        and tower2.attackImmune ~= true then
        local tp = U.unitPos(tower2)
        local d = U.dist(pos, tp)
        local creeps = self:CountAllyCreepsNear(t, tp, 950)
        local enemies = self:CountEnemiesNear(t, tp, 1100, true)
        if d < 1600 and creeps >= 2 and enemies == 0 then
            if d <= range + 400 then return U.attack(tower2.id, "hit tower") end
            return U.attackMove(tp, "push wave")
        end
    end

    -- 9) farm neutral camps when the lane is empty
    local anchor = task.pos or self:LaneAnchor(t, hero)
    if not anchor then anchor = self:LaneAnchor(t, hero) end
    local laneCreeps = self:CountAllyCreepsNear(t, pos, 1600) + self:CountEnemyCreepsNear(t, pos, 1600)
    if laneCreeps == 0 and role <= 3 then
        local camp = self:NearestPin(t, "camp", pos, t.myTeam)
        if camp and U.dist(pos, camp.pos) < 2600 then
            local neut = self:NearestNeutral(t, pos, nil)
            if neut and U.dist(pos, U.unitPos(neut)) < 700 then
                return U.attack(neut.id, "jungle")
            end
            return U.move(camp.pos, "to jungle")
        end
    end

    if anchor then
        if U.dist(pos, anchor) > 250 then
            return U.attackMove(anchor, "lane")
        end
        -- stand still and keep hitting whatever is closest
        local c = self:NearestEnemy(t, pos, 600, false)
        if c and U.alive(c) and not U.isBuilding(c) then
            return U.attack(c.id, "farm")
        end
        return U.hold("hold lane")
    end
    return U.move(t.fountain or pos, "base")
end

-- ---------------------------------------------------------------------------
--  team fight
-- ---------------------------------------------------------------------------
function Team:FightBehavior(t, hero, st, task)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    local fightPos = task.pos or t.fightPos
    if not fightPos then return self:LaneBehavior(t, hero, st, task) end
    local d = U.dist(pos, fightPos)
    local hp = U.hpPct(hero)

    if task.joinByTp and d > 2600 then
        if self:CountEnemiesNear(t, pos, 1300, true) == 0 then
            return U.tp(fightPos, "tp fight")
        end
    end
    if d > 3600 then return self:LaneBehavior(t, hero, st, task) end

    if hp < 24 then
        local act = self:ActiveItemAction(t, hero, st, { danger = true, fight = true })
        if act then return act end
        return U.move(self:RetreatPoint(t, hero), "retreat")
    end

    -- blink initiation on a clustered enemy group
    if U.itemReady(hero, "item_blink") and U.isStunned(hero) == false then
        local initTgt = self:FocusUnit(t) or self:NearestEnemyHero(t, pos, 1300)
        if initTgt then
            local ip = U.unitPos(initTgt)
            local idist = U.dist(pos, ip)
            if idist > 550 and idist < 1200 then
                local clump = self:CountEnemiesNear(t, ip, 550, true)
                local myNear = self:CountAllyHeroesNear(t, ip, 1400)
                if clump >= 2 and myNear >= 1 then
                    local land = U.toward(ip, pos, 300)
                    if land then
                        return { kind = "cast", item = "item_blink", position = land, status = "blink in" }
                    end
                end
            end
        end
    end

    -- safe ranged heroes keep their distance while casting
    local act = self:TrySpells(t, hero, st, {
        fight = true, kill = true, teamfight = true, always = true,
        danger = (hp < 45), push = false,
    })
    if act then return act end
    act = self:ActiveItemAction(t, hero, st, { fight = true, danger = (hp < 45), safe = false })
    if act then return act end

    local target = self:FocusUnit(t)
    if not target or not U.alive(target) then target = self:BestKillTarget(t, hero, 1300) end
    if not target then target = self:NearestEnemyHero(t, pos, 1200) end
    if target then
        local tp = U.unitPos(target)
        local range = U.num(hero.attackRange, 150)
        local dist = U.dist(pos, tp)
        if dist <= range + 80 then
            return U.attack(target.id, "fight")
        end
        -- melee: go in; ranged: attack move
        return U.attackMove(tp, "engage")
    end
    -- no hero nearby: hit creeps or the closest damage dealer
    local creep = self:NearestEnemy(t, pos, 900, false)
    if creep and U.alive(creep) then return U.attack(creep.id, "fight creeps") end
    return U.attackMove(fightPos, "advance")
end

-- ---------------------------------------------------------------------------
--  defense
-- ---------------------------------------------------------------------------
function Team:DefendBehavior(t, hero, st, task)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    local b = task.target
    local bpos = task.pos
    if not bpos then return self:FightBehavior(t, hero, st, task) end
    local d = U.dist(pos, bpos)
    local hp = U.hpPct(hero)

    if hp < 25 then
        local act = self:ActiveItemAction(t, hero, st, { danger = true, fight = true })
        if act then return act end
        return U.move(self:RetreatPoint(t, hero), "retreat")
    end

    -- TP home if far away and the building matters
    if d > 3000 and U.hasItem(hero, "item_tpscroll") and self:CountEnemiesNear(t, pos, 1300, true) == 0 then
        return U.tp(bpos, "tp defend")
    end

    local act = self:TrySpells(t, hero, st, { fight = true, kill = true, teamfight = true, always = true })
    if act then return act end
    act = self:ActiveItemAction(t, hero, st, { fight = true, danger = (hp < 45), safe = false })
    if act then return act end

    -- attack the closest enemy actually threatening the building
    local target = self:NearestEnemyHero(t, bpos, 1400)
    if not target then target = self:NearestEnemyHero(t, pos, 1000) end
    if target then
        local tp = U.unitPos(target)
        local range = U.num(hero.attackRange, 150)
        if U.dist(pos, tp) <= range + 80 then return U.attack(target.id, "defend") end
        return U.attackMove(tp, "defend")
    end
    local creep = self:NearestEnemy(t, bpos, 900, false)
    if creep and U.alive(creep) then return U.attack(creep.id, "clear wave") end

    -- stand between the threat and the building
    local f = t.fountain or bpos
    local standPoint = U.toward(bpos, f, 550)
    if standPoint then return U.move(standPoint, "hold tower") end
    return nil
end

-- ---------------------------------------------------------------------------
--  push / siege
-- ---------------------------------------------------------------------------
function Team:PushBehavior(t, hero, st, task)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    local b = task.target
    local bpos = task.pos
    if not bpos then return self:LaneBehavior(t, hero, st, task) end
    local hp = U.hpPct(hero)
    local range = U.num(hero.attackRange, 150)

    if hp < 28 and self:CountEnemiesNear(t, pos, 950, true) >= 1 then
        local act = self:ActiveItemAction(t, hero, st, { danger = true, fight = true })
        if act then return act end
        return U.move(self:RetreatPoint(t, hero), "retreat")
    end

    local act = self:TrySpells(t, hero, st, { push = true, fight = true, kill = true, always = true })
    if act then return act end
    act = self:ActiveItemAction(t, hero, st, {
        fight = (self:CountEnemiesNear(t, pos, 1100, true) >= 1),
        safe = (self:CountEnemiesNear(t, pos, 1100, true) == 0),
    })
    if act then return act end

    if not b or not U.alive(b) then return self:LaneBehavior(t, hero, st, task) end
    if b.invulnerable == true or b.attackImmune == true then
        return self:LaneBehavior(t, hero, st, task)
    end

    local creeps = self:CountAllyCreepsNear(t, bpos, 1100)
    local enemies = self:CountEnemiesNear(t, bpos, 1300, true)
    local dist = U.dist(pos, bpos)
    local f = t.fountain or pos

    -- enemy heroes defending: fight them first
    if enemies >= 1 and U.alive(b) then
        local target = self:NearestEnemyHero(t, bpos, 1200)
        if target then
            local tp = U.unitPos(target)
            if U.dist(pos, tp) <= range + 80 then return U.attack(target.id, "fight def") end
            return U.attackMove(tp, "fight def")
        end
    end

    local needCreeps = true
    if U.isTower(b) and U.num(b.tier, 0) <= 1 then needCreeps = false end
    if (not needCreeps) or creeps >= 1 or U.hpPct(b) < 10 then
        -- do not tank the tower ourselves: step back while the wave is dying
        if U.isTower(b) then
            local tankHp = 100000
            for i = 1, #t.allyCreeps do
                local c = t.allyCreeps[i]
                if U.alive(c) and U.dist(U.unitPos(c), bpos) <= 900 then
                    tankHp = U.min(tankHp, U.hp(c))
                end
            end
            if tankHp < 130 and dist <= U.TOWER_SAFE + 60 then
                local back = U.toward(pos, f, 350)
                if back then return U.move(back, "step back") end
            end
        end
        if dist <= range + 260 then return U.attack(b.id, "siege") end
        return U.attackMove(bpos, "siege")
    end

    -- wait for the creep wave at a safe distance
    local waitPos = U.toward(bpos, f, U.TOWER_SAFE + 150)
    if waitPos and dist > U.TOWER_SAFE + 60 then
        return U.attackMove(waitPos, "wait wave")
    end
    if waitPos then return U.move(waitPos, "wait wave") end
    return nil
end

-- ---------------------------------------------------------------------------
--  roshan / tormentor
-- ---------------------------------------------------------------------------
function Team:ObjectiveBehavior(t, hero, st, task)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    local target = task.target
    local op = task.pos
    if not op then return self:LaneBehavior(t, hero, st, task) end
    local hp = U.hpPct(hero)
    local range = U.num(hero.attackRange, 150)

    if hp < 30 then
        local act = self:ActiveItemAction(t, hero, st, { danger = true, safe = true })
        if act then return act end
        return U.move(self:RetreatPoint(t, hero), "retreat")
    end

    local act = self:ActiveItemAction(t, hero, st, {
        fight = (self:CountEnemiesNear(t, pos, 1200, true) >= 1),
        safe = (self:CountEnemiesNear(t, pos, 1200, true) == 0),
    })
    if act then return act end

    if target and U.alive(target) then
        local tp = U.unitPos(target)
        if U.dist(pos, tp) <= range + 400 then return U.attack(target.id, task.what or "objective") end
        return U.attackMove(tp, task.what or "objective")
    end
    if U.dist(pos, op) > 400 then return U.attackMove(op, task.what or "objective") end
    -- objective not up yet: farm nearby
    return self:LaneBehavior(t, hero, st, task)
end

-- ---------------------------------------------------------------------------
--  runes, lotus, wisdom, drops
-- ---------------------------------------------------------------------------
function Team:RuneBehavior(t, hero, st, task)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    local rune, rd = self:NearestRune(t, pos, nil)
    if rune and rd <= 500 then
        return U.rune(rune.id, "rune")
    end
    if task.pos then
        if U.dist(pos, task.pos) > 150 then return U.move(task.pos, "go rune") end
        return U.hold("wait rune")
    end
    return self:LaneBehavior(t, hero, st, task)
end

function Team:WardBehavior(t, hero, st, task)
    local pos = U.unitPos(hero)
    if not pos or type(task.pos) ~= "table" then
        return self:LaneBehavior(t, hero, st, task)
    end
    if self:CountEnemiesNear(t, pos, 850, true) >= 1 then
        return self:LaneBehavior(t, hero, st, task)
    end
    local d = U.dist(pos, task.pos)
    if d > 400 then return U.move(task.pos, "go ward") end
    local hasObs = U.itemReady(hero, "item_ward_observer") or U.itemReady(hero, "item_ward_dispenser")
    if hasObs then
        return { kind = "cast", item = "item_ward_observer", position = U.copyPos(task.pos), status = "ward" }
    end
    return self:LaneBehavior(t, hero, st, task)
end

function Team:LotusBehavior(t, hero, st, task)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    if self:CountEnemiesNear(t, pos, 900, true) >= 2 then
        return self:FightBehavior(t, hero, st, { pos = pos })
    end
    if U.dist(pos, task.pos) <= 320 then
        return U.lotus(task.pos, "lotus")
    end
    return U.move(task.pos, "to lotus")
end

function Team:WisdomBehavior(t, hero, st, task)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    if self:CountEnemiesNear(t, pos, 800, true) >= 1 then
        return U.move(self:RetreatPoint(t, hero), "wisdom unsafe")
    end
    if U.dist(pos, task.pos) <= 280 then
        return U.shrine(task.pos, "wisdom")
    end
    return U.move(task.pos, "to wisdom")
end

function Team:DropAction(t, hero, st)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    local drop, d = self:NearestDrop(t, pos, 650)
    if drop then
        local role = U.num(hero.position, 5)
        local name = U.str(drop.name, "")
        if name == "item_aegis" or name == "item_cheese" then
            local allies = self:CountAllyHeroesNear(t, pos, 900)
            if role <= 2 or allies == 0 then
                return U.pickup(drop.id, "pickup")
            end
            return nil
        end
        return U.pickup(drop.id, "pickup")
    end
    return nil
end

-- ---------------------------------------------------------------------------
--  follow / roam / retreat
-- ---------------------------------------------------------------------------
function Team:FollowBehavior(t, hero, st, task)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    local carry = task.target
    if not carry or not U.alive(carry) then
        return self:LaneBehavior(t, hero, st, task)
    end
    local cp = U.unitPos(carry)
    if not cp then return self:LaneBehavior(t, hero, st, task) end
    local near = self:CountEnemiesNear(t, cp, 1300, true)
    if near >= 1 then
        return self:FightBehavior(t, hero, st, { pos = cp })
    end
    local hp = U.hpPct(hero)
    if hp < 45 then
        local act = self:ActiveItemAction(t, hero, st, { safe = true })
        if act then return act end
    end
    local d = U.dist(pos, cp)
    if d > 800 then return U.move(U.toward(cp, pos, 350), "follow") end
    if d < 350 then
        local back = U.toward(cp, pos, 500)
        if back then return U.move(back, "keep distance") end
    end
    return self:LaneBehavior(t, hero, st, task)
end

function Team:RoamBehavior(t, hero, st, task)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    local enemy = self:NearestEnemyHero(t, pos, 1200)
    if enemy then
        local ep = U.unitPos(enemy)
        local myNear = self:CountAllyHeroesNear(t, ep, 1200)
        local theirNear = self:CountEnemiesNear(t, ep, 1200, true)
        if U.hpPct(hero) > 40 and (myNear >= theirNear or U.hpPct(enemy) < 40) then
            return self:FightBehavior(t, hero, st, { pos = ep })
        end
    end
    local anchor = task.pos or self:LaneAnchor(t, hero)
    if anchor and U.dist(pos, anchor) > 300 then
        return U.move(anchor, "roam")
    end
    return self:LaneBehavior(t, hero, st, task)
end

-- if the enemy tower just switched to us, A-click a friendly creep to drop aggro
function Team:DeaggroAction(t, hero, st)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    local hp = U.hp(hero)
    local prevHp = U.num(st.trackHp, hp)
    local prevT = U.num(st.trackTime, t.time)
    local dt = t.time - prevT
    st.trackHp = hp
    st.trackTime = t.time
    if dt <= 0 or dt > 0.9 then return nil end
    local drop = prevHp - hp
    if drop < 45 then return nil end
    local tower, td = self:NearestEnemyTower(t, pos)
    if not tower or td > 820 then return nil end
    local best, bestD = nil, 100000
    for i = 1, #t.allyCreeps do
        local c = t.allyCreeps[i]
        if U.alive(c) then
            local cp = U.unitPos(c)
            if cp then
                local towerD = U.dist(cp, U.unitPos(tower))
                if towerD <= 720 then
                    local d2 = U.dist(cp, pos)
                    if d2 < bestD then best, bestD = c, d2 end
                end
            end
        end
    end
    if best then return U.deaggro(best.id, "deaggro") end
    if td <= 900 then
        local away = U.pointAway(pos, U.unitPos(tower), 380)
        if away then return U.move(away, "leave tower") end
    end
    return nil
end

function Team:WorthGateTask(kind)
    if kind == "objective" or kind == "push" or kind == "rune" or kind == "lotus"
        or kind == "wisdom" or kind == "follow" then
        return true
    end
    return false
end

-- paired portals are a cheap way to rotate across the map
function Team:GateAction(t, hero, st, dest, taskKind)
    local pos = U.unitPos(hero)
    if not pos or type(dest) ~= "table" then return nil end
    if t.time < 240 then return nil end
    if t.time - U.num(st.lastGate, -1000) < 18 then return nil end
    if not self:WorthGateTask(taskKind) then return nil end
    if self:CountEnemiesNear(t, pos, 900, true) > 0 then return nil end
    local gates = self:PinsOf(t, "gate")
    if #gates < 2 then return nil end
    for i = 1, #gates do
        local g = gates[i]
        if type(g.pos) == "table" then
            local exitPos, exitD = nil, 1000000
            for j = 1, #gates do
                if j ~= i and type(gates[j].pos) == "table" then
                    local d = U.dist(g.pos, gates[j].pos)
                    if d < exitD then exitPos, exitD = gates[j].pos, d end
                end
            end
            if exitPos then
                local before = U.dist(pos, dest)
                local after = U.dist(exitPos, dest) + U.dist(pos, g.pos)
                if before - after > 1800 then
                    local gd = U.dist(pos, g.pos)
                    if gd <= 300 then
                        st.lastGate = t.time
                        return U.gate(g.targetId, g.pos, "gate")
                    end
                    local step = U.toward(pos, g.pos, gd - 250)
                    if step then return U.move(step, "to gate") end
                end
            end
        end
    end
    return nil
end

function Team:RetreatBehavior(t, hero, st, task)
    local pos = U.unitPos(hero)
    if not pos then return nil end
    local dest = task.pos or self:RetreatPoint(t, hero) or t.fountain
    if not dest then return nil end
    local enemiesNear = self:CountEnemiesNear(t, pos, 1200, true)
    local act = self:ActiveItemAction(t, hero, st, { danger = true })
    if act then return act end
    if enemiesNear == 0 then
        if U.dist(pos, dest) > 3500 and U.hasItem(hero, "item_tpscroll") then
            return U.tp(t.fountain or dest, "tp home")
        end
        local act2 = self:ActiveItemAction(t, hero, st, { safe = true })
        if act2 then return act2 end
    end
    return U.move(dest, "retreat")
end

-- ---------------------------------------------------------------------------
--  auto-cast orbs
-- ---------------------------------------------------------------------------
function Team:AutoCast(t, hero, st, acts)
    local ab = U.tbl(hero.abilities)
    for k, a in pairs(ab) do
        if type(a) == "table" and type(a.name) == "string" then
            if a.autoCast == false and U.num(a.level, 0) > 0
                and D.AUTOCAST_ABILITIES[a.name] == true then
                if st.autocast == nil then st.autocast = {} end
                local at = U.num(st.autocast[a.name], -1000)
                if t.time - at > 20 then
                    st.autocast[a.name] = t.time
                    acts[#acts + 1] = U.autocast(a.name)
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
--  dead hero
-- ---------------------------------------------------------------------------
function Team:DeadHero(t, hero, st, acts)
    self:BuyBuild(t, hero, st, acts)
    self:InventoryManager(t, hero, st, acts)
    self:LearnStep(t, hero, st, acts)
    if t.buybackHero and t.buybackHero.id == hero.id then
        acts[#acts + 1] = U.buyback()
        V.team.lastBuyback = t.time
        t.buybackHero = nil
    end
end

-- ---------------------------------------------------------------------------
--  team-level instant actions
-- ---------------------------------------------------------------------------
function Team:AttachTeamActions(t, hero, st, acts)
    if t.glyphNeeded and t.glyphOwner == nil then
        acts[#acts + 1] = U.glyph()
        V.team.lastGlyph = t.time
        t.glyphNeeded = false
        t.glyphOwner = hero.id
    end
    if t.buybackHero and t.buybackHero.id == hero.id then
        acts[#acts + 1] = U.buyback()
        V.team.lastBuyback = t.time
        t.buybackHero = nil
    end
end

-- ---------------------------------------------------------------------------
--  main action pipeline
-- ---------------------------------------------------------------------------
function Team:MainAction(t, hero, st)
    local task = st.task or { kind = "lane" }
    local pos = U.unitPos(hero)
    if not pos then return nil end

    if t.smokeReady and t.smokeHero and t.smokeHero.id == hero.id then
        V.team.lastSmoke = t.time
        t.smokeReady = false
        return U.smoke()
    end

    local dg = self:DeaggroAction(t, hero, st)
    if dg then return dg end

    if st.forceDrop then
        local slot = st.forceDrop
        st.forceDrop = nil
        if U.itemAt(hero, slot) then return U.dropSlot(slot) end
    end

    -- teleport straight back to the action when we are at the fountain
    if t.time > 30 and task.kind ~= "retreat" and U.hasItem(hero, "item_tpscroll")
        and self:IsAtBase(t, hero) then
        local dest = task.pos
        if type(dest) == "table" and U.dist(pos, dest) > 3000
            and self:CountEnemiesNear(t, dest, 1300, true) == 0 then
            return U.tp(dest, "tp lane")
        end
    end

    if task.kind == "retreat" then
        return self:RetreatBehavior(t, hero, st, task)
    end

    if task.kind ~= "fight" and task.kind ~= "defend" then
        local gate = self:GateAction(t, hero, st, task.pos, task.kind)
        if gate then return gate end
    end

    local vis = self:VisionAction(t, hero, st)
    if vis then return vis end

    local drop = self:DropAction(t, hero, st)
    if drop then return drop end

    local kind = U.str(task.kind, "lane")
    if kind == "fight" then return self:FightBehavior(t, hero, st, task) end
    if kind == "defend" then return self:DefendBehavior(t, hero, st, task) end
    if kind == "push" then return self:PushBehavior(t, hero, st, task) end
    if kind == "objective" then return self:ObjectiveBehavior(t, hero, st, task) end
    if kind == "rune" then return self:RuneBehavior(t, hero, st, task) end
    if kind == "ward" then return self:WardBehavior(t, hero, st, task) end
    if kind == "lotus" then return self:LotusBehavior(t, hero, st, task) end
    if kind == "wisdom" then return self:WisdomBehavior(t, hero, st, task) end
    if kind == "follow" then return self:FollowBehavior(t, hero, st, task) end
    if kind == "roam" then return self:RoamBehavior(t, hero, st, task) end
    return self:LaneBehavior(t, hero, st, task)
end

-- ---------------------------------------------------------------------------
--  hero tick
-- ---------------------------------------------------------------------------
function Team:HeroThink(t, hero)
    local acts = {}
    local st = self:State(hero)
    if not U.alive(hero) then
        self:DeadHero(t, hero, st, acts)
        return acts
    end

    self:LearnStep(t, hero, st, acts)
    self:BuyBuild(t, hero, st, acts)
    self:InventoryManager(t, hero, st, acts)
    self:AutoCast(t, hero, st, acts)
    self:AttachTeamActions(t, hero, st, acts)

    if U.hpPct(hero) < 20 and self:CountEnemiesNear(t, U.unitPos(hero), 950, true) >= 1 then
        self:BuyBuild(t, hero, st, acts, true)
    end

    if hero.casting == true or hero.channeling == true then
        return acts
    end

    local action = self:MainAction(t, hero, st)
    if action then
        acts[#acts + 1] = action
    end
    return acts
end

-- ===========================================================================
--  PART 22. DRAFT
-- ===========================================================================

D.FALLBACK_PICK = {
    "npc_dota_hero_juggernaut", "npc_dota_hero_tidehunter", "npc_dota_hero_lion",
    "npc_dota_hero_crystal_maiden", "npc_dota_hero_death_prophet", "npc_dota_hero_axe",
    "npc_dota_hero_luna", "npc_dota_hero_sven", "npc_dota_hero_puck",
    "npc_dota_hero_earthshaker", "npc_dota_hero_shadow_shaman", "npc_dota_hero_ogre_magi",
    "npc_dota_hero_centaur", "npc_dota_hero_leshrac",
}

function U.hasHeroValue(dict, name)
    if type(dict) ~= "table" or type(name) ~= "string" then return false end
    for k, v in pairs(dict) do
        if v == name then return true end
    end
    return false
end

function Team:CountEnemyPicksMatching(enemyNames, dict)
    local n = 0
    if type(dict) ~= "table" then return 0 end
    for nm in pairs(dict) do
        if enemyNames[nm] == true then n = n + 1 end
    end
    return n
end

function Team:CounterCandidates(pos, enemyNames)
    local base = Team.draft[pos] or {}
    local list = {}
    local function push(nm)
        if type(nm) == "string" and not U.contains(list, nm) then list[#list + 1] = nm end
    end

    local magicN = self:CountEnemyPicksMatching(enemyNames, D.MAGIC_HEROES)
    local physN = self:CountEnemyPicksMatching(enemyNames, D.PHYS_HEROES)
    local invisN = self:CountEnemyPicksMatching(enemyNames, D.INVIS_HEROES)
    local illusionN = 0
    local illusionHeroes = {
        "npc_dota_hero_phantom_lancer", "npc_dota_hero_naga_siren", "npc_dota_hero_chaos_knight",
        "npc_dota_hero_terrorblade", "npc_dota_hero_arc_warden", "npc_dota_hero_meepo",
        "npc_dota_hero_phantom_assassin",
    }
    for i = 1, #illusionHeroes do
        if enemyNames[illusionHeroes[i]] == true then illusionN = illusionN + 1 end
    end

    if pos == 4 then
        if illusionN >= 1 then push("npc_dota_hero_earthshaker") end
        if invisN >= 1 then push("npc_dota_hero_lion") end
    elseif pos == 5 then
        if physN >= 3 then push("npc_dota_hero_ogre_magi") end
        if invisN >= 1 then push("npc_dota_hero_shadow_shaman") end
    elseif pos == 3 then
        if physN >= 2 then push("npc_dota_hero_axe") end
        if magicN >= 2 then push("npc_dota_hero_tidehunter") end
        if invisN >= 2 then push("npc_dota_hero_centaur") end
    elseif pos == 2 then
        if magicN >= 2 then push("npc_dota_hero_death_prophet") end
        if physN >= 3 then push("npc_dota_hero_puck") end
    elseif pos == 1 then
        if invisN >= 1 then push("npc_dota_hero_juggernaut") end
        if physN >= 3 then push("npc_dota_hero_sven") end
    end

    for i = 1, #base do push(base[i]) end
    push("npc_dota_hero_juggernaut")
    push("npc_dota_hero_tidehunter")
    push("npc_dota_hero_lion")
    push("npc_dota_hero_crystal_maiden")
    push("npc_dota_hero_death_prophet")
    push("npc_dota_hero_axe")
    push("npc_dota_hero_earthshaker")
    push("npc_dota_hero_shadow_shaman")
    push("npc_dota_hero_ogre_magi")
    push("npc_dota_hero_luna")
    push("npc_dota_hero_sven")
    push("npc_dota_hero_puck")
    push("npc_dota_hero_centaur")
    push("npc_dota_hero_leshrac")
    return list
end

function Team:PickHero(pos, role, available, allyPicks, enemyPicks)
    pos = U.num(pos, 1)
    if pos < 1 then pos = 1 end
    if pos > 5 then pos = 5 end
    available = U.tbl(available)
    allyPicks = U.tbl(allyPicks)
    enemyPicks = U.tbl(enemyPicks)

    local enemyNames = {}
    for k, v in pairs(enemyPicks) do
        if type(v) == "string" then enemyNames[v] = true end
    end

    local candidates = self:CounterCandidates(pos, enemyNames)
    for i = 1, #candidates do
        local nm = candidates[i]
        if available[nm] == true and not U.hasHeroValue(allyPicks, nm) then
            return nm
        end
    end

    for i = 1, #D.FALLBACK_PICK do
        local nm = D.FALLBACK_PICK[i]
        if available[nm] == true and not U.hasHeroValue(allyPicks, nm) then
            return nm
        end
    end

    for nm, v in pairs(available) do
        if v == true and type(nm) == "string" and not U.hasHeroValue(allyPicks, nm) then
            return nm
        end
    end

    return "npc_dota_hero_juggernaut"
end

-- ===========================================================================
--  PART 23. ENTRY POINT
-- ===========================================================================

function Team:FallbackActions(snapshot)
    local out = {}
    local heroes = U.tbl(snapshot.heroes)
    local pins = U.tbl(snapshot.pins)
    local myTeam = U.num(snapshot.team, 2)
    local fountain = nil
    for i = 1, #pins do
        local p = pins[i]
        if type(p) == "table" and U.kind(p) == "fountain" and U.num(p.mapTeam, 0) == myTeam then
            fountain = p.pos
        end
    end
    for i = 1, #heroes do
        local h = heroes[i]
        if type(h) == "table" and h.id ~= nil then
            local list = {}
            local hp = U.hpPct(h)
            if U.alive(h) and hp < 25 and fountain then
                list[#list + 1] = U.move(fountain, "safe")
            else
                list[#list + 1] = U.hold("idle")
            end
            out[h.id] = list
        end
    end
    return out
end

function Team:DecideTeam(snapshot)
    local out = {}
    if type(snapshot) ~= "table" then return out end
    local ok, err = pcall(function()
        local t = self:Context(snapshot)
        self:TeamThink(t)
        for i = 1, #t.mine do
            local hero = t.mine[i]
            local okH, list = pcall(function()
                return self:HeroThink(t, hero)
            end)
            if okH and type(list) == "table" then
                local clean = {}
                for j = 1, #list do
                    if type(list[j]) == "table" then clean[#clean + 1] = list[j] end
                end
                if #clean > 0 then out[hero.id] = clean end
            elseif not okH then
                self.lastError = tostring(list)
                self.errorCount = U.num(self.errorCount, 0) + 1
            end
        end
    end)
    if not ok then
        self.lastError = tostring(err)
        self.errorCount = U.num(self.errorCount, 0) + 1
        local safe = self:FallbackActions(snapshot)
        for id, list in pairs(safe) do
            if out[id] == nil then out[id] = list end
        end
    end
    return out
end

return Team
