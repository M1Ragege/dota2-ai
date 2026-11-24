-- Dota 2 AI Team: Claude Radiant
-- Patch 7.42 | Lua 5.1 strict

local Talents = require("sdk/dota_base/talents")
local Team = {}
Team.name = "Claude"

-- Lane assignments: Pos1=bot(safe), Pos2=mid, Pos3=top(off), Pos4=top(off), Pos5=bot(safe)
Team.lanes = { "bot", "mid", "top", "top", "bot" }

-- Draft fallback
Team.draft = {
  { "npc_dota_hero_juggernaut",    "npc_dota_hero_phantom_assassin" },
  { "npc_dota_hero_storm_spirit",  "npc_dota_hero_dragon_knight" },
  { "npc_dota_hero_tidehunter",    "npc_dota_hero_axe" },
  { "npc_dota_hero_earth_spirit",  "npc_dota_hero_bounty_hunter" },
  { "npc_dota_hero_crystal_maiden","npc_dota_hero_witch_doctor" },
}

-- ============================================================
-- ITEM VALUE TABLE (higher = more important)
-- ============================================================
local ITEM_VALUE = {
  item_branches=10, item_clarity=10, item_tango=10, item_faerie_fire=15,
  item_enchanted_mango=15, item_magic_stick=25, item_quelling_blade=20,
  item_flask=20, item_wind_lace=30, item_boots=40, item_power_treads=120,
  item_phase_boots=120, item_arcane_boots=120, item_tranquil_boots=100,
  item_magic_wand=50, item_null_talisman=35, item_wraith_band=35,
  item_bracer=35, item_ring_of_basilius=50, item_soul_ring=70,
  item_bottle=90, item_urn_of_shadows=80, item_spirit_vessel=160,
  item_rod_of_atos=130, item_ancient_janggo=130, item_medallion_of_courage=100,
  item_solar_crest=160, item_mekansm=200, item_guardian_greaves=250,
  item_pipe=230, item_crimson_guard=200, item_vladmir=180,
  item_blink=200, item_force_staff=160, item_glimmer_cape=170,
  item_ghost=120, item_cyclone=160, item_aether_lens=130,
  item_aghanims_shard=130, item_aghanims_scepter=250,
  item_black_king_bar=240, item_manta=270, item_satanic=280,
  item_butterfly=300, item_monkey_king_bar=270, item_skadi=320,
  item_shivas_guard=280, item_sheepstick=350, item_refresher=380,
  item_bloodthorn=320, item_orchid=200, item_dagon=180,
  item_ethereal_blade=250, item_scythe_of_vyse=350,
  item_heart=320, item_assault=300, item_battlefury=270,
  item_mjollnir=280, item_abyssal_blade=290, item_desolator=240,
  item_silver_edge=270, item_invis_sword=200, item_diffusal_blade=220,
  item_basher=180, item_echo_sabre=150, item_maelstrom=160,
  item_dragon_lance=120, item_hurricane_pike=200,
  item_daedalus=330, item_rapier=500, item_aegis=600,
  item_cheese=400, item_refresher_shard=350, item_horn_of_battle_greater=350,
  item_ward_observer=30, item_ward_sentry=30, item_ward_dispenser=60,
  item_smoke_of_deceit=50, item_dust=30, item_gem=200,
  item_tpscroll=50, item_travel_boots=300, item_travel_boots_2=400,
  item_ultimate_scepter_roshan=250, item_roshans_banner=200,
}

local function itemValue(name)
  if not name then return 0 end
  return ITEM_VALUE[name] or 50
end

-- ============================================================
-- HERO DATA (builds, skills, talents)
-- ============================================================
local HERO_DATA = {}

-- JUGGERNAUT (Pos1)
HERO_DATA["npc_dota_hero_juggernaut"] = {
  role = "carry",
  skillBuild = {
    [1]="juggernaut_blade_fury", [2]="juggernaut_healing_ward",
    [3]="juggernaut_blade_fury", [4]="juggernaut_blade_dance",
    [5]="juggernaut_blade_fury", [6]="juggernaut_omni_slash",
    [7]="juggernaut_blade_fury", [8]="juggernaut_healing_ward",
    [9]="juggernaut_healing_ward", [10]="special_bonus_attack_speed_15",
    [11]="juggernaut_omni_slash", [12]="juggernaut_healing_ward",
    [13]="juggernaut_blade_dance", [14]="juggernaut_blade_dance",
    [15]="special_bonus_unique_juggernaut_3", [16]="juggernaut_blade_dance",
    [17]="juggernaut_omni_slash",
    [20]="special_bonus_unique_juggernaut_5",
    [25]="special_bonus_unique_juggernaut_2",
  },
  itemBuild = {
    start={"item_quelling_blade","item_faerie_fire","item_magic_stick","item_enchanted_mango"},
    early={"item_phase_boots","item_magic_wand","item_wraith_band"},
    mid={"item_battlefury","item_manta","item_blink"},
    late={"item_black_king_bar","item_butterfly","item_abyssal_blade","item_daedalus"},
  },
  inviz=false,
}

-- STORM SPIRIT (Pos2)
HERO_DATA["npc_dota_hero_storm_spirit"] = {
  role = "mid",
  skillBuild = {
    [1]="storm_spirit_static_remnant", [2]="storm_spirit_overload",
    [3]="storm_spirit_static_remnant", [4]="storm_spirit_electric_vortex",
    [5]="storm_spirit_static_remnant", [6]="storm_spirit_ball_lightning",
    [7]="storm_spirit_static_remnant", [8]="storm_spirit_electric_vortex",
    [9]="storm_spirit_electric_vortex", [10]="special_bonus_unique_storm_spirit_7",
    [11]="storm_spirit_ball_lightning", [12]="storm_spirit_electric_vortex",
    [13]="storm_spirit_overload", [14]="storm_spirit_overload",
    [15]="special_bonus_unique_storm_spirit_5", [16]="storm_spirit_overload",
    [17]="storm_spirit_ball_lightning",
    [20]="special_bonus_unique_storm_spirit_3",
    [25]="special_bonus_unique_storm_spirit_2",
  },
  itemBuild = {
    start={"item_null_talisman","item_faerie_fire","item_clarity","item_magic_stick"},
    early={"item_bottle","item_power_treads","item_magic_wand"},
    mid={"item_orchid","item_black_king_bar","item_blink"},
    late={"item_bloodthorn","item_shivas_guard","item_sheepstick","item_aghanims_scepter"},
  },
  inviz=false,
}

-- TIDEHUNTER (Pos3)
HERO_DATA["npc_dota_hero_tidehunter"] = {
  role = "offlane",
  skillBuild = {
    [1]="tidehunter_anchor_smash", [2]="tidehunter_kraken_shell",
    [3]="tidehunter_gush", [4]="tidehunter_kraken_shell",
    [5]="tidehunter_anchor_smash", [6]="tidehunter_ravage",
    [7]="tidehunter_anchor_smash", [8]="tidehunter_anchor_smash",
    [9]="tidehunter_gush", [10]="special_bonus_unique_tidehunter_2",
    [11]="tidehunter_ravage", [12]="tidehunter_gush",
    [13]="tidehunter_gush", [14]="tidehunter_kraken_shell",
    [15]="special_bonus_unique_tidehunter_5", [16]="tidehunter_kraken_shell",
    [17]="tidehunter_ravage",
    [20]="special_bonus_unique_tidehunter_4",
    [25]="special_bonus_unique_tidehunter_6",
  },
  itemBuild = {
    start={"item_bracer","item_faerie_fire","item_magic_stick"},
    early={"item_arcane_boots","item_magic_wand","item_bracer"},
    mid={"item_blink","item_aghanims_shard","item_pipe"},
    late={"item_black_king_bar","item_heart","item_shivas_guard","item_crimson_guard"},
  },
  inviz=false,
}

-- EARTH SPIRIT (Pos4)
HERO_DATA["npc_dota_hero_earth_spirit"] = {
  role = "soft_support",
  skillBuild = {
    [1]="earth_spirit_rolling_boulder", [2]="earth_spirit_boulder_smash",
    [3]="earth_spirit_rolling_boulder", [4]="earth_spirit_geomagnetic_grip",
    [5]="earth_spirit_rolling_boulder", [6]="earth_spirit_magnetize",
    [7]="earth_spirit_rolling_boulder", [8]="earth_spirit_boulder_smash",
    [9]="earth_spirit_boulder_smash", [10]="special_bonus_unique_earth_spirit_2",
    [11]="earth_spirit_magnetize", [12]="earth_spirit_boulder_smash",
    [13]="earth_spirit_geomagnetic_grip", [14]="earth_spirit_geomagnetic_grip",
    [15]="special_bonus_unique_earth_spirit_6", [16]="earth_spirit_geomagnetic_grip",
    [17]="earth_spirit_magnetize",
    [20]="special_bonus_unique_earth_spirit_4",
    [25]="special_bonus_unique_earth_spirit",
  },
  itemBuild = {
    start={"item_bracer","item_magic_stick","item_wind_lace"},
    early={"item_tranquil_boots","item_magic_wand","item_urn_of_shadows"},
    mid={"item_blink","item_force_staff","item_spirit_vessel"},
    late={"item_aghanims_shard","item_black_king_bar","item_glimmer_cape"},
  },
  inviz=false,
}

-- CRYSTAL MAIDEN (Pos5)
HERO_DATA["npc_dota_hero_crystal_maiden"] = {
  role = "hard_support",
  skillBuild = {
    [1]="crystal_maiden_crystal_nova", [2]="crystal_maiden_frostbite",
    [3]="crystal_maiden_brilliance_aura", [4]="crystal_maiden_crystal_nova",
    [5]="crystal_maiden_crystal_nova", [6]="crystal_maiden_freezing_field",
    [7]="crystal_maiden_crystal_nova", [8]="crystal_maiden_frostbite",
    [9]="crystal_maiden_frostbite", [10]="special_bonus_attack_range_75",
    [11]="crystal_maiden_freezing_field", [12]="crystal_maiden_frostbite",
    [13]="crystal_maiden_brilliance_aura", [14]="crystal_maiden_brilliance_aura",
    [15]="special_bonus_unique_crystal_maiden_3", [16]="crystal_maiden_brilliance_aura",
    [17]="crystal_maiden_freezing_field",
    [20]="special_bonus_unique_crystal_maiden_5",
    [25]="special_bonus_unique_crystal_maiden_1",
  },
  itemBuild = {
    start={"item_ward_observer","item_ward_sentry","item_magic_stick","item_clarity","item_faerie_fire"},
    early={"item_tranquil_boots","item_magic_wand","item_wind_lace"},
    mid={"item_glimmer_cape","item_force_staff","item_aether_lens"},
    late={"item_aghanims_shard","item_blink","item_black_king_bar"},
  },
  inviz=false,
}

-- Fallback: Dragon Knight
HERO_DATA["npc_dota_hero_dragon_knight"] = {
  role = "mid",
  skillBuild = {
    [1]="dragon_knight_breathe_fire",[2]="dragon_knight_wyrms_wrath",
    [3]="dragon_knight_breathe_fire",[4]="dragon_knight_dragon_tail",
    [5]="dragon_knight_breathe_fire",[6]="dragon_knight_elder_dragon_form",
    [7]="dragon_knight_breathe_fire",[8]="dragon_knight_wyrms_wrath",
    [9]="dragon_knight_wyrms_wrath",[10]="special_bonus_attack_damage_12",
    [11]="dragon_knight_wyrms_wrath",[12]="dragon_knight_elder_dragon_form",
    [13]="dragon_knight_dragon_tail",[14]="dragon_knight_dragon_tail",
    [15]="special_bonus_hp_300",[16]="dragon_knight_dragon_tail",
    [18]="dragon_knight_elder_dragon_form",
    [20]="special_bonus_unique_dragon_knight_7",
    [25]="special_bonus_unique_dragon_knight_wyrms_wrath_damage",
  },
  itemBuild = {
    start={"item_bracer","item_faerie_fire","item_magic_stick"},
    early={"item_power_treads","item_magic_wand","item_soul_ring"},
    mid={"item_blink","item_black_king_bar","item_assault"},
    late={"item_heart","item_butterfly","item_aghanims_scepter"},
  },
  inviz=false,
}
HERO_DATA["npc_dota_hero_axe"] = {
  role = "offlane",
  skillBuild = {
    [1]="axe_battle_hunger",[2]="axe_counter_helix",[3]="axe_counter_helix",
    [4]="axe_battle_hunger",[5]="axe_counter_helix",[6]="axe_culling_blade",
    [7]="axe_counter_helix",[8]="axe_battle_hunger",[9]="axe_battle_hunger",
    [10]="special_bonus_unique_axe_5",[11]="axe_culling_blade",
    [12]="axe_berserkers_call",[13]="axe_berserkers_call",
    [14]="axe_berserkers_call",[15]="special_bonus_unique_axe_4",
    [16]="axe_berserkers_call",[17]="axe_culling_blade",
    [20]="special_bonus_unique_axe_6",[25]="special_bonus_unique_axe_2",
  },
  itemBuild = {
    start={"item_bracer","item_faerie_fire","item_magic_stick"},
    early={"item_phase_boots","item_magic_wand","item_bracer"},
    mid={"item_blink","item_black_king_bar","item_crimson_guard"},
    late={"item_heart","item_assault","item_aghanims_scepter"},
  },
  inviz=false,
}
HERO_DATA["npc_dota_hero_bounty_hunter"] = {
  role = "soft_support",
  skillBuild = {
    [1]="bounty_hunter_shuriken_toss",[2]="bounty_hunter_jinada",
    [3]="bounty_hunter_shuriken_toss",[4]="bounty_hunter_wind_walk",
    [5]="bounty_hunter_shuriken_toss",[6]="bounty_hunter_track",
    [7]="bounty_hunter_shuriken_toss",[8]="bounty_hunter_jinada",
    [9]="bounty_hunter_jinada",[10]="special_bonus_unique_bounty_hunter_4",
    [11]="bounty_hunter_track",[12]="bounty_hunter_jinada",
    [13]="bounty_hunter_wind_walk",[14]="bounty_hunter_wind_walk",
    [15]="special_bonus_unique_bounty_hunter_5",[16]="bounty_hunter_wind_walk",
    [17]="bounty_hunter_track",
    [20]="special_bonus_unique_bounty_hunter_2",
    [25]="special_bonus_unique_bounty_hunter_3",
  },
  itemBuild = {
    start={"item_bracer","item_magic_stick","item_wind_lace"},
    early={"item_tranquil_boots","item_urn_of_shadows","item_magic_wand"},
    mid={"item_spirit_vessel","item_blink","item_aghanims_shard"},
    late={"item_black_king_bar","item_silver_edge","item_nullifier"},
  },
  inviz=true,
}
HERO_DATA["npc_dota_hero_witch_doctor"] = {
  role = "hard_support",
  skillBuild = {
    [1]="witch_doctor_paralyzing_cask",[2]="witch_doctor_voodoo_restoration",
    [3]="witch_doctor_paralyzing_cask",[4]="witch_doctor_maledict",
    [5]="witch_doctor_paralyzing_cask",[6]="witch_doctor_death_ward",
    [7]="witch_doctor_paralyzing_cask",[8]="witch_doctor_maledict",
    [9]="witch_doctor_maledict",[10]="special_bonus_unique_witch_doctor_1",
    [11]="witch_doctor_death_ward",[12]="witch_doctor_maledict",
    [13]="witch_doctor_voodoo_restoration",[14]="witch_doctor_voodoo_restoration",
    [15]="special_bonus_unique_witch_doctor_3",[16]="witch_doctor_voodoo_restoration",
    [17]="witch_doctor_death_ward",
    [20]="special_bonus_unique_witch_doctor_5",
    [25]="special_bonus_unique_witch_doctor_6",
  },
  itemBuild = {
    start={"item_ward_observer","item_ward_sentry","item_magic_stick","item_clarity"},
    early={"item_tranquil_boots","item_magic_wand","item_wind_lace"},
    mid={"item_glimmer_cape","item_force_staff","item_aether_lens"},
    late={"item_aghanims_shard","item_blink","item_sheepstick"},
  },
  inviz=false,
}
HERO_DATA["npc_dota_hero_phantom_assassin"] = {
  role = "carry",
  skillBuild = {
    [1]="phantom_assassin_stifling_dagger",[2]="phantom_assassin_phantom_strike",
    [3]="phantom_assassin_stifling_dagger",[4]="phantom_assassin_blur",
    [5]="phantom_assassin_stifling_dagger",[6]="phantom_assassin_coup_de_grace",
    [7]="phantom_assassin_stifling_dagger",[8]="phantom_assassin_phantom_strike",
    [9]="phantom_assassin_phantom_strike",[10]="special_bonus_unique_phantom_assassin_6",
    [11]="phantom_assassin_coup_de_grace",[12]="phantom_assassin_phantom_strike",
    [13]="phantom_assassin_blur",[14]="phantom_assassin_blur",
    [15]="special_bonus_unique_phantom_assassin_2",[16]="phantom_assassin_blur",
    [17]="phantom_assassin_coup_de_grace",
    [20]="special_bonus_unique_phantom_assassin_4",
    [25]="special_bonus_unique_phantom_assassin_3",
  },
  itemBuild = {
    start={"item_quelling_blade","item_faerie_fire","item_magic_stick","item_enchanted_mango"},
    early={"item_phase_boots","item_magic_wand","item_wraith_band"},
    mid={"item_battlefury","item_blink","item_black_king_bar"},
    late={"item_butterfly","item_abyssal_blade","item_daedalus","item_satanic"},
  },
  inviz=true,
}

-- ============================================================
-- DRAFT LOGIC
-- ============================================================
local ROLE_HEROES = {
  POS_1_CARRY = {
    "npc_dota_hero_juggernaut","npc_dota_hero_phantom_assassin",
    "npc_dota_hero_dragon_knight",
  },
  POS_2_MID = {
    "npc_dota_hero_storm_spirit","npc_dota_hero_dragon_knight",
  },
  POS_3_OFFLANE = {
    "npc_dota_hero_tidehunter","npc_dota_hero_axe",
  },
  POS_4_SOFT_SUPPORT = {
    "npc_dota_hero_earth_spirit","npc_dota_hero_bounty_hunter",
  },
  POS_5_HARD_SUPPORT = {
    "npc_dota_hero_crystal_maiden","npc_dota_hero_witch_doctor",
  },
}

function Team:PickHero(pos, role, available, allyPicks, enemyPicks)
  local candidates = ROLE_HEROES[role] or {}
  for _, h in ipairs(candidates) do
    if available[h] then return h end
  end
  -- fallback: any available
  for name, ok in pairs(available) do
    if ok then return name end
  end
  return "npc_dota_hero_crystal_maiden"
end

-- ============================================================
-- STATE
-- ============================================================
Team._state = {
  swapTimer   = {},   -- [heroId] = lastSwapTime
  towerHpLast = {},   -- [towerKind] = hp
  wardPlaced  = {},   -- [spotKey] = time
  focusTarget = nil,
  focusTime   = 0,
  glyphUsed   = 0,
}

-- ============================================================
-- HELPERS
-- ============================================================
local function dist2(a, b)
  if not a or not b then return 999999 end
  local dx = (a.x or 0)-(b.x or 0)
  local dy = (a.y or 0)-(b.y or 0)
  return math.sqrt(dx*dx + dy*dy)
end

local function hasItem(hero, name)
  if not hero or not hero.items then return false end
  for slot=0,16 do
    if hero.items[slot] == name then return true end
  end
  return false
end

local function hasItemAny(hero, names)
  for _, n in ipairs(names) do
    if hasItem(hero, n) then return true end
  end
  return false
end

local function findItemSlot(hero, name)
  if not hero or not hero.items then return nil end
  for slot=0,16 do
    if hero.items[slot] == name then return slot end
  end
  return nil
end

local function countSlots(hero)
  if not hero or not hero.items then return 0,0 end
  local main, bp = 0, 0
  for slot=0,5 do if hero.items[slot] then main=main+1 end end
  for slot=6,8 do if hero.items[slot] then bp=bp+1 end end
  return main, bp
end

local function lowestValueMainSlot(hero)
  local minVal, minSlot = 999999, nil
  for slot=0,5 do
    local it = hero.items[slot]
    local v = itemValue(it)
    if v < minVal then minVal=v; minSlot=slot end
  end
  return minSlot, minVal
end

local function allSlotsUsed(hero)
  local c=0
  for slot=0,8 do if hero.items[slot] then c=c+1 end end
  return c >= 9
end

local function heroData(hero)
  return HERO_DATA[hero.name] or {}
end

local function getHeroes(snapshot)
  return snapshot.heroes or {}
end

local function getAllies(snapshot)
  return snapshot.allies or {}
end

local function getEnemies(snapshot)
  return snapshot.enemies or {}
end

local function getPins(snapshot)
  return snapshot.pins or {}
end

local function getRunes(snapshot)
  return snapshot.runes or {}
end

local function getDrops(snapshot)
  return snapshot.drops or {}
end

local function getNeutrals(snapshot)
  return snapshot.neutrals or {}
end

local function getSchedule(snapshot)
  return snapshot.schedule or {}
end

local function findAllyCreepsNearTower(snapshot, towerPos, radius)
  local best, bestDist = nil, 999999
  for _, u in ipairs(getAllies(snapshot)) do
    if u.alive and (u.kind=="lane_creep" or u.kind=="siege_creep") then
      local d = dist2(u.pos, towerPos)
      if d < radius and d < bestDist then
        best = u; bestDist = d
      end
    end
  end
  return best
end

local function findEnemyTowers(snapshot)
  local towers = {}
  for _, u in ipairs(getAllies(snapshot)) do end -- skip
  -- enemies includes towers
  for _, e in ipairs(getEnemies(snapshot)) do
    if e.kind == "tower" and e.alive then
      towers[#towers+1] = e
    end
  end
  return towers
end

local function nearEnemyTower(snapshot, heroPos, radius)
  for _, e in ipairs(getEnemies(snapshot)) do
    if e.kind == "tower" and e.alive then
      if dist2(heroPos, e.pos) < (radius or 850) then
        return e
      end
    end
  end
  return nil
end

local function alliedTowerUnderAttack(snapshot)
  for _, u in ipairs(getAllies(snapshot)) do
    if u.kind == "tower" and u.alive and u.underAttack then
      return u
    end
  end
  return nil
end

local function pickBestEnemy(snapshot, myPos, state)
  local t = state.focusTarget
  local now = (snapshot.time or 0)
  -- refresh focus every 4 seconds or if target dead/gone
  if t and (now - state.focusTime) < 4 then
    for _, e in ipairs(getEnemies(snapshot)) do
      if e.id == t and e.alive and not e.invulnerable and e.kind == "hero" then
        return e
      end
    end
  end
  -- pick squishiest visible enemy hero
  local best, bestScore = nil, -999999
  for _, e in ipairs(getEnemies(snapshot)) do
    if e.alive and e.kind == "hero" and not e.isIllusion
       and not e.invulnerable and not e.attackImmune then
      local hpRatio = (e.maxHp and e.maxHp > 0) and (e.hp / e.maxHp) or 1
      local score = -hpRatio * 1000 + 1 / (dist2(myPos, e.pos) + 1) * 300
      if score > bestScore then bestScore=score; best=e end
    end
  end
  if best then
    state.focusTarget = best.id
    state.focusTime = now
  end
  return best
end

-- ============================================================
-- SKILL LEARNING
-- ============================================================
local function learnSkills(hero, snapshot)
  local hd = heroData(hero)
  local build = hd.skillBuild or {}
  local expected = build[hero.level] or build[hero.level+1]
  if expected and (Talents.isTalent(expected) or (hero.abilityPoints or 0) > 0) then
    for _, ab in pairs(hero.abilities or {}) do
      if ab.name == expected and ab.canUpgrade and not ab.hidden then
        return { { kind="learn", ability=expected, status="Learning "..expected } }
      end
    end
  end
  local talent = Talents.firstAvailable(hero.abilities)
  if talent then return { { kind="learn", ability=talent.name, status="Talent!" } } end
  return {}
end

-- ============================================================
-- BUY LOGIC
-- ============================================================
local function nextItemToBuy(hero, snapshot)
  local hd = heroData(hero)
  if not hd.itemBuild then return nil end
  local t = snapshot.time or 0
  local phase = "start"
  if t > 600 then phase = "late"
  elseif t > 180 then phase = "mid"
  elseif t > 30 then phase = "early"
  end
  local list = hd.itemBuild[phase] or hd.itemBuild.start or {}
  for _, item in ipairs(list) do
    if not hasItem(hero, item) then
      return item
    end
  end
  return nil
end

local function buyActions(hero, snapshot)
  local actions = {}
  local t = snapshot.time or 0
  -- Dying? buy something immediately
  if hero.hp and hero.maxHp and (hero.hp/hero.maxHp) < 0.18 then
    local item = nextItemToBuy(hero, snapshot)
    if item and hero.gold and hero.gold >= 50 then
      actions[#actions+1] = { kind="buy", item=item, status="Panic buy" }
      return actions
    end
  end
  -- Normal buy
  if hero.gold and hero.gold >= 100 then
    local item = nextItemToBuy(hero, snapshot)
    if item then
      actions[#actions+1] = { kind="buy", item=item, status="Buying "..item }
    end
  end
  -- Ensure TP
  if not hero.items or not hero.items[15] then
    if hero.gold and hero.gold >= 100 then
      actions[#actions+1] = { kind="buy", item="item_tpscroll", status="Buy TP" }
    end
  end
  return actions
end

-- ============================================================
-- INVENTORY MANAGER
-- ============================================================
local function inventoryActions(hero, snapshot, state)
  local actions = {}
  local now = snapshot.time or 0
  local lastSwap = state.swapTimer[hero.id] or -100
  -- Auto-swap backpack to main if more valuable
  if (now - lastSwap) >= 6 then
    for bp=6,8 do
      local bpItem = hero.items and hero.items[bp]
      if bpItem then
        local bpVal = itemValue(bpItem)
        for main=0,5 do
          local mainItem = hero.items and hero.items[main]
          local mainVal = itemValue(mainItem)
          if bpVal > mainVal + 20 then
            actions[#actions+1] = { kind="swap", slot_a=bp, slot_b=main, status="Swap to main" }
            state.swapTimer[hero.id] = now
            return actions
          end
        end
      end
    end
  end
  -- Auto-drop trash if slots full and valuable drop nearby
  if allSlotsUsed(hero) then
    for _, d in ipairs(getDrops(snapshot)) do
      if dist2(hero.pos, d.pos) < 300 then
        local slot, val = lowestValueMainSlot(hero)
        if slot and val < 60 then
          actions[#actions+1] = { kind="drop", slot=slot, status="Drop trash" }
          return actions
        end
      end
    end
  end
  return actions
end

-- ============================================================
-- ACTIVE ITEM USE
-- ============================================================
local function activeItemActions(hero, snapshot, state)
  local actions = {}
  local now = snapshot.time or 0
  local function tryCast(item, opts)
    local slot = findItemSlot(hero, item)
    if not slot then return false end
    local cd = hero.itemCooldown and hero.itemCooldown[slot] or 0
    if cd and cd > 0 then return false end
    local act = { kind="cast", item=item, status="Use "..item }
    if opts then for k,v in pairs(opts) do act[k]=v end end
    actions[#actions+1] = act
    return true
  end

  -- Healing items (out of combat or low hp)
  local hpR = (hero.maxHp and hero.maxHp>0) and (hero.hp/hero.maxHp) or 1
  local manaR = (hero.maxMana and hero.maxMana>0) and (hero.mana/hero.maxMana) or 1

  if hpR < 0.6 and not hero.casting then
    tryCast("item_flask")
  end
  if manaR < 0.3 then
    tryCast("item_enchanted_mango")
    tryCast("item_clarity")
  end
  if hero.itemCharges then
    for slot=0,5 do
      if hero.items and hero.items[slot] == "item_magic_wand" then
        local ch = hero.itemCharges[slot] or 0
        if ch >= 5 then
          actions[#actions+1] = { kind="cast", item="item_magic_wand", status="Wand burst" }
        end
      end
    end
  end

  -- BKB when in fight with spells incoming
  local nearEnemy = false
  for _, e in ipairs(getEnemies(snapshot)) do
    if e.kind=="hero" and not e.isIllusion and dist2(hero.pos, e.pos)<800 then
      nearEnemy=true; break
    end
  end
  if nearEnemy and not hero.magicImmune then
    tryCast("item_black_king_bar")
  end

  -- Manta vs disable
  if hero.stunned or hero.hexed or hero.rooted then
    tryCast("item_manta")
  end

  -- Satanic when low hp in fight
  if hpR < 0.3 and nearEnemy then
    tryCast("item_satanic")
  end

  return actions
end

-- ============================================================
-- ABILITY CASTING
-- ============================================================
local function abilityActions(hero, snapshot, state)
  local actions = {}
  if hero.silenced or hero.stunned or hero.casting or hero.channeling then return actions end
  local function tryAbility(name, opts)
    if not hero.abilities then return false end
    for _, ab in pairs(hero.abilities) do
      if ab.name == name and not ab.passive and not ab.hidden
         and ab.cooldown and ab.cooldown == 0
         and hero.mana and hero.mana >= (ab.manaCost or 0)
         and ab.fullyCastable then
        local act = { kind="cast", ability=name, status="Cast "..name }
        if opts then for k,v in pairs(opts) do act[k]=v end end
        actions[#actions+1] = act
        return true
      end
    end
    return false
  end

  local hpR = (hero.maxHp and hero.maxHp>0) and (hero.hp/hero.maxHp) or 1
  local hname = hero.name or ""

  -- Find nearest enemy hero
  local nearestEnemy, nearestDist = nil, 999999
  for _, e in ipairs(getEnemies(snapshot)) do
    if e.kind=="hero" and not e.isIllusion and e.alive and not e.invulnerable then
      local d = dist2(hero.pos, e.pos)
      if d < nearestDist then nearestDist=d; nearestEnemy=e end
    end
  end

  if hname == "npc_dota_hero_juggernaut" then
    -- Blade Fury for escape/trade, Healing Ward when hurt
    if nearestEnemy and nearestDist < 600 and hpR < 0.5 then
      tryAbility("juggernaut_blade_fury")
    end
    if nearestEnemy and nearestDist < 500 and hpR > 0.3 then
      tryAbility("juggernaut_omni_slash", {target_id=nearestEnemy.id})
    end
    if hpR < 0.4 then
      tryAbility("juggernaut_healing_ward", {position=hero.pos})
    end

  elseif hname == "npc_dota_hero_storm_spirit" then
    if nearestEnemy and nearestDist < 400 then
      tryAbility("storm_spirit_electric_vortex", {target_id=nearestEnemy.id})
      tryAbility("storm_spirit_static_remnant", {position=nearestEnemy.pos})
      tryAbility("storm_spirit_ball_lightning", {position=nearestEnemy.pos})
    elseif nearestEnemy and nearestDist < 1500 then
      tryAbility("storm_spirit_ball_lightning", {position=nearestEnemy.pos})
    end

  elseif hname == "npc_dota_hero_tidehunter" then
    local enemyCount = 0
    for _, e in ipairs(getEnemies(snapshot)) do
      if e.kind=="hero" and not e.isIllusion and dist2(hero.pos,e.pos)<800 then
        enemyCount=enemyCount+1
      end
    end
    if enemyCount >= 2 then
      tryAbility("tidehunter_ravage", {position=hero.pos})
    end
    if nearestEnemy and nearestDist < 700 then
      tryAbility("tidehunter_gush", {target_id=nearestEnemy.id})
      tryAbility("tidehunter_anchor_smash")
    end

  elseif hname == "npc_dota_hero_earth_spirit" then
    if nearestEnemy and nearestDist < 400 then
      tryAbility("earth_spirit_boulder_smash", {target_id=nearestEnemy.id})
      tryAbility("earth_spirit_rolling_boulder", {position=nearestEnemy.pos})
    end
    if nearestEnemy and nearestDist < 600 then
      tryAbility("earth_spirit_geomagnetic_grip", {target_id=nearestEnemy.id})
    end

  elseif hname == "npc_dota_hero_crystal_maiden" then
    if nearestEnemy and nearestDist < 700 and not (nearestEnemy.magicImmune) then
      tryAbility("crystal_maiden_frostbite", {target_id=nearestEnemy.id})
    end
    if nearestEnemy and nearestDist < 800 and not (nearestEnemy.magicImmune) then
      tryAbility("crystal_maiden_crystal_nova", {position=nearestEnemy.pos})
    end
    local enemyCount2 = 0
    for _, e in ipairs(getEnemies(snapshot)) do
      if e.kind=="hero" and not e.isIllusion and dist2(hero.pos,e.pos)<700 then
        enemyCount2=enemyCount2+1
      end
    end
    if enemyCount2 >= 2 then
      tryAbility("crystal_maiden_freezing_field")
    end

  elseif hname == "npc_dota_hero_dragon_knight" then
    if nearestEnemy and nearestDist < 500 then
      tryAbility("dragon_knight_dragon_tail", {target_id=nearestEnemy.id})
      tryAbility("dragon_knight_breathe_fire", {position=nearestEnemy.pos})
    end
    if nearestEnemy and nearestDist < 1000 then
      tryAbility("dragon_knight_elder_dragon_form")
    end

  elseif hname == "npc_dota_hero_axe" then
    if nearestEnemy and nearestDist < 300 then
      tryAbility("axe_berserkers_call")
    end
    -- Culling Blade on low HP
    for _, e in ipairs(getEnemies(snapshot)) do
      if e.kind=="hero" and not e.isIllusion and dist2(hero.pos,e.pos)<300 then
        local ehpR = (e.maxHp and e.maxHp>0) and (e.hp/e.maxHp) or 1
        if ehpR < 0.2 then
          tryAbility("axe_culling_blade", {target_id=e.id})
          break
        end
      end
    end

  elseif hname == "npc_dota_hero_bounty_hunter" then
    if nearestEnemy and nearestDist < 1000 then
      tryAbility("bounty_hunter_track", {target_id=nearestEnemy.id})
    end
    if nearestEnemy and nearestDist < 500 then
      tryAbility("bounty_hunter_shuriken_toss", {target_id=nearestEnemy.id})
    end

  elseif hname == "npc_dota_hero_witch_doctor" then
    if nearestEnemy and nearestDist < 700 and not (nearestEnemy.magicImmune) then
      tryAbility("witch_doctor_paralyzing_cask", {target_id=nearestEnemy.id})
      tryAbility("witch_doctor_maledict", {position=nearestEnemy.pos})
    end
    local enemyCount3 = 0
    for _, e in ipairs(getEnemies(snapshot)) do
      if e.kind=="hero" and not e.isIllusion and dist2(hero.pos,e.pos)<700 then
        enemyCount3=enemyCount3+1
      end
    end
    if enemyCount3 >= 1 then
      tryAbility("witch_doctor_death_ward", {position=nearestEnemy and nearestEnemy.pos or hero.pos})
    end

  elseif hname == "npc_dota_hero_phantom_assassin" then
    if nearestEnemy and nearestDist < 950 then
      tryAbility("phantom_assassin_phantom_strike", {target_id=nearestEnemy.id})
      tryAbility("phantom_assassin_stifling_dagger", {target_id=nearestEnemy.id})
    end
  end

  return actions
end

-- ============================================================
-- WARDING
-- ============================================================
local WARD_SPOTS = {
  {x=0,    y=2000, z=256},  -- mid river top
  {x=0,    y=-2000,z=256},  -- mid river bot
  {x=-3000,y=1000, z=256},  -- radiant top ward
  {x=3000, y=-1000,z=256},  -- dire bot ward
  {x=0,    y=0,    z=256},  -- roshan entrance
}

local function wardActions(hero, snapshot, state)
  local actions = {}
  local hd = heroData(hero)
  if not (hd.role == "hard_support" or hd.role == "soft_support") then return actions end
  if not hasItemAny(hero, {"item_ward_dispenser","item_ward_observer"}) then
    -- buy wards
    if hero.gold and hero.gold >= 0 then -- wards are free
      actions[#actions+1] = { kind="buy", item="item_ward_observer", status="Buy obs ward" }
    end
    return actions
  end
  -- Place ward if not placed recently
  local now = snapshot.time or 0
  for _, spot in ipairs(WARD_SPOTS) do
    local key = spot.x..","..spot.y
    local lastPlaced = state.wardPlaced[key] or -300
    if (now - lastPlaced) > 240 then
      -- Check no existing ward nearby
      local dup = false
      for _, u in ipairs(getAllies(snapshot)) do
        if u.kind=="observer_ward" and dist2(u.pos, spot) < 500 then dup=true; break end
      end
      if not dup and dist2(hero.pos, spot) < 200 then
        actions[#actions+1] = { kind="cast", item="item_ward_observer", position=spot, status="Place ward" }
        state.wardPlaced[key] = now
        return actions
      elseif not dup and dist2(hero.pos, spot) > 200 then
        -- Move toward ward spot
        actions[#actions+1] = { kind="move", position=spot, status="Go ward" }
        return actions
      end
    end
  end
  return actions
end

-- ============================================================
-- DEWARD
-- ============================================================
local function dewardActions(hero, snapshot)
  local actions = {}
  for _, e in ipairs(getEnemies(snapshot)) do
    if (e.kind=="observer_ward" or e.kind=="sentry_ward") and e.alive then
      if dist2(hero.pos, e.pos) < 600 then
        actions[#actions+1] = { kind="ward_focus", target_id=e.id, status="Deward!" }
        return actions
      end
    end
  end
  return actions
end

-- ============================================================
-- DUST / ANTI-INVIS
-- ============================================================
local function dustActions(hero, snapshot)
  local actions = {}
  -- Check if any enemy has invis
  local enemyHasInvis = false
  local invizHeroes = {
    riki=true, bounty_hunter=true, clinkz=true, nyx_assassin=true,
    weaver=true, invoker=true, mirana=true, sand_king=true, slark=true,
    treant=true, hoodwink=true, phantom_assassin=true,
  }
  for eid, es in pairs(snapshot.enemyLastSeen or {}) do
    local nm = es.name or ""
    for k,_ in pairs(invizHeroes) do
      if string.find(nm, k) then enemyHasInvis=true; break end
    end
    -- check items
    if es.items then
      for _, it in pairs(es.items) do
        if it=="item_invis_sword" or it=="item_silver_edge" or it=="item_glimmer_cape" then
          enemyHasInvis=true
        end
      end
    end
  end
  if enemyHasInvis and not hasItem(hero, "item_dust") then
    if hero.gold and hero.gold >= 80 then
      actions[#actions+1] = { kind="buy", item="item_dust", status="Buy dust" }
    end
  end
  -- Use dust if enemy near and recently disappeared
  local now = snapshot.time or 0
  if hasItem(hero, "item_dust") then
    for eid, es in pairs(snapshot.enemyLastSeen or {}) do
      if (now - (es.at or 0)) < 2.5 and dist2(hero.pos, es.pos or hero.pos) < 950 then
        -- check not currently visible
        local visible = false
        for _, e in ipairs(getEnemies(snapshot)) do
          if e.id == eid then visible=true; break end
        end
        if not visible then
          actions[#actions+1] = { kind="cast", item="item_dust", status="Dust invis!" }
          return actions
        end
      end
    end
  end
  return actions
end

-- ============================================================
-- RUNE COLLECTION
-- ============================================================
local function runeActions(hero, snapshot)
  local actions = {}
  local schedule = getSchedule(snapshot)
  local now = snapshot.time or 0
  local hd = heroData(hero)
  local isMid = (hd.role == "mid")
  local isSupport = (hd.role == "hard_support" or hd.role == "soft_support")

  -- Bounty runes: anyone
  local bounty = schedule.bounty
  if bounty and bounty.nextAt and (bounty.nextAt - now) < 8 then
    for _, r in ipairs(getRunes(snapshot)) do
      if r.runeType == "bounty" or r.spawnerKind == "bounty" then
        if dist2(hero.pos, r.pos) < 1500 then
          actions[#actions+1] = { kind="rune", target_id=r.id, status="Bounty rune!" }
          return actions
        end
      end
    end
  end

  -- Power runes: mid or support roamer
  if isMid or isSupport then
    local power = schedule.power
    if power and power.nextAt and (bounty and bounty.nextAt or power.nextAt) and (power.nextAt - now) < 8 then
      for _, r in ipairs(getRunes(snapshot)) do
        if r.runeType ~= "bounty" and r.spawnerKind ~= "bounty" then
          if dist2(hero.pos, r.pos) < 1200 then
            actions[#actions+1] = { kind="rune", target_id=r.id, status="Power rune!" }
            return actions
          end
        end
      end
    end
  end

  -- Pick up any visible bounty within reach
  for _, r in ipairs(getRunes(snapshot)) do
    if (r.runeType == "bounty" or r.spawnerKind == "bounty") and dist2(hero.pos, r.pos) < 300 then
      actions[#actions+1] = { kind="rune", target_id=r.id, status="Grab bounty" }
      return actions
    end
  end

  return actions
end

-- ============================================================
-- LOTUS / SHRINE
-- ============================================================
local function lotusActions(hero, snapshot)
  local actions = {}
  local schedule = getSchedule(snapshot)
  local now = snapshot.time or 0
  local lotus = schedule.lotus
  if lotus and lotus.nextAt and (lotus.nextAt - now) < 10 then
    for _, pin in ipairs(getPins(snapshot)) do
      if pin.kind == "lotus" and pin.visible and pin.active and pin.charges and pin.charges > 0 then
        if dist2(hero.pos, pin.pos) < 350 then
          -- check for enemies
          local safe = true
          for _, e in ipairs(getEnemies(snapshot)) do
            if e.kind=="hero" and dist2(hero.pos,e.pos)<600 then safe=false; break end
          end
          if safe then
            actions[#actions+1] = { kind="lotus", position=pin.pos, status="Grab lotus" }
            return actions
          end
        end
      end
    end
  end
  -- Use famango if have it
  if hasItemAny(hero, {"item_famango","item_great_famango","item_greater_famango"}) then
    local hpR = (hero.maxHp and hero.maxHp>0) and (hero.hp/hero.maxHp) or 1
    if hpR < 0.6 then
      local slot = findItemSlot(hero, "item_famango") or
                   findItemSlot(hero, "item_great_famango") or
                   findItemSlot(hero, "item_greater_famango")
      if slot then
        actions[#actions+1] = { kind="cast", item=hero.items[slot], status="Eat famango" }
        return actions
      end
    end
  end
  return actions
end

local function shrineActions(hero, snapshot)
  local actions = {}
  local schedule = getSchedule(snapshot)
  local now = snapshot.time or 0
  local wisdom = schedule.wisdom
  if wisdom and wisdom.nextAt and (wisdom.nextAt - now) < 15 then
    for _, pin in ipairs(getPins(snapshot)) do
      if pin.kind == "wisdom" and pin.visible and pin.mapTeam == snapshot.team then
        if dist2(hero.pos, pin.pos) < 300 then
          local safe = true
          for _, e in ipairs(getEnemies(snapshot)) do
            if e.kind=="hero" and dist2(hero.pos,e.pos)<600 then safe=false; break end
          end
          if safe then
            actions[#actions+1] = { kind="shrine", position=pin.pos, status="Shrine!" }
            return actions
          end
        end
      end
    end
  end
  return actions
end

-- ============================================================
-- ROSHAN / TORMENTOR
-- ============================================================
local function roshanActions(hero, snapshot, aliveAllies)
  local actions = {}
  if aliveAllies < 3 then return actions end
  -- Look for Roshan
  for _, n in ipairs(getNeutrals(snapshot)) do
    if n.kind == "roshan" and n.alive then
      local d = dist2(hero.pos, n.pos)
      if d < 1500 and aliveAllies >= 3 then
        actions[#actions+1] = { kind="attack", target_id=n.id, status="Kill Roshan!" }
        return actions
      end
    end
  end
  -- Tormentor (15 min+)
  local now = snapshot.time or 0
  local schedule = getSchedule(snapshot)
  local torm = schedule.tormentor
  if torm and torm.active and now >= 900 then
    for _, n in ipairs(getNeutrals(snapshot)) do
      if n.kind == "tormentor" and n.alive then
        if dist2(hero.pos, n.pos) < 1500 and aliveAllies >= 3 then
          actions[#actions+1] = { kind="attack", target_id=n.id, status="Kill Tormentor!" }
          return actions
        end
      end
    end
  end
  return actions
end

-- ============================================================
-- PICKUP DROPS
-- ============================================================
local function pickupDrops(hero, snapshot, pos)
  local actions = {}
  for _, d in ipairs(getDrops(snapshot)) do
    local dn = d.name or ""
    if dn=="item_aegis" or dn=="item_cheese" or dn=="item_refresher_shard"
       or dn=="item_horn_of_battle_greater" or dn=="item_roshans_banner" then
      if dist2(hero.pos, d.pos) < 300 then
        actions[#actions+1] = { kind="pickup", target_id=d.id, status="Pickup "..dn }
        return actions
      elseif dist2(hero.pos, d.pos) < 800 then
        actions[#actions+1] = { kind="move", position=d.pos, status="Go pickup" }
        return actions
      end
    end
  end
  return actions
end

-- ============================================================
-- TELEPORT / TOWER DEFENSE
-- ============================================================
local function tpActions(hero, snapshot)
  local actions = {}
  if not hero.items or not hero.items[15] then return actions end
  if hero.casting or hero.channeling then return actions end
  local atTower = alliedTowerUnderAttack(snapshot)
  if atTower and atTower.alive then
    if dist2(hero.pos, atTower.pos) > 2800 then
      actions[#actions+1] = { kind="tp", position=atTower.pos, status="TP defend!" }
      return actions
    end
  end
  return actions
end

-- ============================================================
-- LANE / CREEP FIGHTING
-- ============================================================
local function laneActions(hero, snapshot, state)
  local actions = {}
  local hd = heroData(hero)
  local now = snapshot.time or 0

  local hpR = (hero.maxHp and hero.maxHp>0) and (hero.hp/hero.maxHp) or 1

  -- Retreat if low HP
  if hpR < 0.28 then
    -- Move toward fountain
    local fountain = nil
    for _, pin in ipairs(getPins(snapshot)) do
      if pin.kind=="fountain" and pin.mapTeam == snapshot.team then
        fountain = pin; break
      end
    end
    if fountain then
      actions[#actions+1] = { kind="move", position=fountain.pos, status="Retreat!" }
      return actions
    end
  end

  -- Check if near enemy tower (avoid diving)
  local nearTower = nearEnemyTower(snapshot, hero.pos, 850)
  if nearTower then
    -- Deaggro if ally creep nearby
    local allyCreep = findAllyCreepsNearTower(snapshot, nearTower.pos, 900)
    if allyCreep then
      actions[#actions+1] = { kind="deaggro", target_id=allyCreep.id, status="Deaggro!" }
      return actions
    else
      -- Step back
      actions[#actions+1] = { kind="move", position={
        x=(hero.pos.x or 0) * 1.1,
        y=(hero.pos.y or 0) * 1.1,
        z=(hero.pos.z or 0)
      }, status="Step back" }
      return actions
    end
  end

  -- Attack enemy hero if in range
  local atRange = hero.attackRange or 150
  for _, e in ipairs(getEnemies(snapshot)) do
    if e.kind=="hero" and not e.isIllusion and e.alive and not e.invulnerable then
      local d = dist2(hero.pos, e.pos)
      if d < atRange + 100 then
        -- Don't attack if BKB on and magic hero
        actions[#actions+1] = { kind="attack", target_id=e.id, status="Attack hero" }
        return actions
      end
    end
  end

  -- Lasthit/deny creeps
  for _, e in ipairs(getEnemies(snapshot)) do
    if (e.kind=="lane_creep" or e.kind=="siege_creep") and e.alive then
      local d = dist2(hero.pos, e.pos)
      local atkD = hero.attackDamage or 50
      local ehpR2 = (e.maxHp and e.maxHp>0) and (e.hp/e.maxHp) or 1
      if d < atRange + 50 and e.hp and e.hp < atkD * 1.3 then
        -- Only carry/mid last hits; supports deny
        if hd.role=="carry" or hd.role=="mid" or hd.role=="offlane" then
          actions[#actions+1] = { kind="attack", target_id=e.id, status="Last hit" }
          return actions
        end
      end
    end
  end

  -- Deny ally creeps
  for _, u in ipairs(getAllies(snapshot)) do
    if (u.kind=="lane_creep" or u.kind=="siege_creep") and u.alive and u.deniable then
      local d = dist2(hero.pos, u.pos)
      local atkD = hero.attackDamage or 50
      if d < (hero.attackRange or 150)+50 and u.hp and u.hp < atkD*0.6 then
        local hdd = heroData(hero)
        if hdd.role=="hard_support" or hdd.role=="soft_support" then
          actions[#actions+1] = { kind="deny", target_id=u.id, status="Deny" }
          return actions
        end
      end
    end
  end

  -- Attack enemy towers (with creep cover)
  for _, e in ipairs(getEnemies(snapshot)) do
    if e.kind=="tower" and e.alive and not e.invulnerable and not e.attackImmune then
      local d = dist2(hero.pos, e.pos)
      if d < (hero.attackRange or 150)+200 then
        -- Check ally creep present
        local allyCreep = findAllyCreepsNearTower(snapshot, e.pos, 1000)
        if allyCreep then
          actions[#actions+1] = { kind="attack", target_id=e.id, status="Hit tower" }
          return actions
        end
      end
    end
  end

  -- Move to lane
  for _, pin in ipairs(getPins(snapshot)) do
    if pin.kind == "lane" and pin.lane == hero.lane then
      if dist2(hero.pos, pin.pos) > 300 then
        actions[#actions+1] = { kind="move", position=pin.pos, status="Lane push" }
        return actions
      end
    end
  end

  -- Default: move toward nearest enemy tower or ancient
  local bestTarget, bestDist2 = nil, 999999
  for _, e in ipairs(getEnemies(snapshot)) do
    if (e.kind=="tower" or e.kind=="ancient") and e.alive and not e.invulnerable then
      local d = dist2(hero.pos, e.pos)
      if d < bestDist2 then bestDist2=d; bestTarget=e end
    end
  end
  if bestTarget then
    actions[#actions+1] = { kind="move", position=bestTarget.pos, status="Push lanes" }
  end

  return actions
end

-- ============================================================
-- GLYPH
-- ============================================================
local function glyphAction(snapshot, state)
  if (snapshot.glyphCooldown or 1) > 0 then return nil end
  for _, u in ipairs(getAllies(snapshot)) do
    if u.kind=="tower" and u.alive and u.underAttack then
      local hpR = (u.maxHp and u.maxHp>0) and (u.hp/u.maxHp) or 1
      if hpR < 0.55 then
        return { kind="glyph", status="Glyph!" }
      end
    end
    if (u.kind=="barracks" or u.kind=="ancient") and u.alive and u.underAttack then
      return { kind="glyph", status="Glyph protect base!" }
    end
  end
  return nil
end

-- ============================================================
-- BUYBACK
-- ============================================================
local function buybackAction(hero, snapshot)
  if not hero.buybackReady then return nil end
  if not hero.alive then
    -- Only use in critical situations
    for _, u in ipairs(getAllies(snapshot)) do
      if (u.kind=="ancient" or u.kind=="barracks") and u.alive and u.underAttack then
        local hpR = (u.maxHp and u.maxHp>0) and (u.hp/u.maxHp) or 1
        if hpR < 0.4 then
          return { kind="buyback", status="Buyback critical!" }
        end
      end
    end
  end
  return nil
end

-- ============================================================
-- STARTING BUY
-- ============================================================
local function startBuyActions(hero, snapshot)
  local actions = {}
  local hd = heroData(hero)
  if not hd.itemBuild then return actions end
  local startItems = hd.itemBuild.start or {}
  for _, item in ipairs(startItems) do
    if not hasItem(hero, item) then
      actions[#actions+1] = { kind="buy", item=item, status="Start buy" }
      if #actions >= 3 then break end
    end
  end
  return actions
end

-- ============================================================
-- SMOKE / GROUP GANK
-- ============================================================
local function smokeAction(hero, snapshot)
  if not hasItem(hero, "item_smoke_of_deceit") then return nil end
  local now = snapshot.time or 0
  -- count nearby allies
  local nearAllies = 0
  for _, h in ipairs(getHeroes(snapshot)) do
    if h.alive and h.id ~= hero.id and dist2(hero.pos, h.pos) < 600 then
      nearAllies = nearAllies + 1
    end
  end
  if nearAllies >= 2 then
    -- not smoked already
    local allySmoked = false
    for _, h in ipairs(getHeroes(snapshot)) do
      if h.smoked then allySmoked=true; break end
    end
    if not allySmoked and not hero.smoked then
      return { kind="smoke", status="Smoke gank!" }
    end
  end
  return nil
end

-- ============================================================
-- MAIN DECIDE
-- ============================================================
function Team:DecideTeam(snapshot)
  local ok, result = pcall(function()
    return self:_DecideTeamInner(snapshot)
  end)
  if ok then return result else return {} end
end

function Team:_DecideTeamInner(snapshot)
  local decisions = {}
  local state = self._state
  local now = snapshot.time or 0

  -- Count alive heroes
  local aliveCount = 0
  for _, h in ipairs(getHeroes(snapshot)) do
    if h.alive then aliveCount=aliveCount+1 end
  end

  -- Global: glyph check (any hero can trigger)
  local glyphAct = glyphAction(snapshot, state)

  for _, hero in ipairs(getHeroes(snapshot)) do
    local actions = {}

    -- Buyback for dead heroes
    if not hero.alive then
      local bb = buybackAction(hero, snapshot)
      if bb then actions[#actions+1] = bb end
      decisions[hero.id] = actions
    else
      -- Learn skills first
      local learnActs = learnSkills(hero, snapshot)
      for _, a in ipairs(learnActs) do actions[#actions+1] = a end

      -- Inventory management (instant)
      local invActs = inventoryActions(hero, snapshot, state)
      for _, a in ipairs(invActs) do actions[#actions+1] = a end

      -- Buy items
      local buyActs = buyActions(hero, snapshot)
      for _, a in ipairs(buyActs) do actions[#actions+1] = a end

      -- Starting buy
      if now < 5 then
        local startActs = startBuyActions(hero, snapshot)
        for _, a in ipairs(startActs) do actions[#actions+1] = a end
      end

      -- Glyph (team captain = pos1 or first hero)
      if glyphAct and hero.position == 1 then
        actions[#actions+1] = glyphAct
        glyphAct = nil
      end

      -- Active items
      local itemActs = activeItemActions(hero, snapshot, state)
      for _, a in ipairs(itemActs) do actions[#actions+1] = a end

      -- Dust / anti-invis
      local dustActs = dustActions(hero, snapshot)
      for _, a in ipairs(dustActs) do actions[#actions+1] = a end

      -- Runes
      local runeActs = runeActions(hero, snapshot)
      if #runeActs > 0 then
        for _, a in ipairs(runeActs) do actions[#actions+1] = a end
      else
        -- Lotus
        local lotusActs = lotusActions(hero, snapshot)
        for _, a in ipairs(lotusActs) do actions[#actions+1] = a end

        -- Shrine
        local shrineActs = shrineActions(hero, snapshot)
        for _, a in ipairs(shrineActs) do actions[#actions+1] = a end

        -- Pickup valuable drops
        local pickupActs = pickupDrops(hero, snapshot, hero.pos)
        if #pickupActs > 0 then
          for _, a in ipairs(pickupActs) do actions[#actions+1] = a end
        else
          -- Deward
          local dewardActs = dewardActions(hero, snapshot)
          if #dewardActs > 0 then
            for _, a in ipairs(dewardActs) do actions[#actions+1] = a end
          else
            -- Warding (supports)
            local wardActs = wardActions(hero, snapshot, state)
            if #wardActs > 0 then
              for _, a in ipairs(wardActs) do actions[#actions+1] = a end
            else
              -- Roshan/Tormentor
              local roshanActs = roshanActions(hero, snapshot, aliveCount)
              if #roshanActs > 0 then
                for _, a in ipairs(roshanActs) do actions[#actions+1] = a end
              else
                -- Abilities
                local abilActs = abilityActions(hero, snapshot, state)
                for _, a in ipairs(abilActs) do actions[#actions+1] = a end

                -- TP defense
                local tpActs = tpActions(hero, snapshot)
                if #tpActs > 0 then
                  for _, a in ipairs(tpActs) do actions[#actions+1] = a end
                else
                  -- Smoke
                  local hd = heroData(hero)
                  if hd.role=="soft_support" or hd.role=="hard_support" then
                    local smokeAct = smokeAction(hero, snapshot)
                    if smokeAct then actions[#actions+1] = smokeAct end
                  end

                  -- Lane fighting
                  local laneActs = laneActions(hero, snapshot, state)
                  for _, a in ipairs(laneActs) do actions[#actions+1] = a end
                end
              end
            end
          end
        end
      end

      decisions[hero.id] = actions
    end
  end

  return decisions
end

return Team
