-- ============================================================================
-- SDK: Общая база игры в Dota 2 (на базе Gemini Neon, патч 7.42)
-- Использование в teams/<model>/init.lua:
--   local BaseBot = require("sdk/dota_base/init")
--   return BaseBot.Create({ name = "...", draft = ..., style = ..., ... })
-- ============================================================================

local BaseBot = {}
local Comms = require("sdk/dota_base/comms")

local HeroPack = require("sdk/dota_base/hero_skills")
local Talents = require("sdk/dota_base/talents")

local function shallowCopy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

local function mergeTable(base, override)
    local out = shallowCopy(base)
    if type(override) == "table" then
        for k, v in pairs(override) do out[k] = v end
    end
    return out
end

local function hasBit(mask, flag)
    if not mask or mask <= 0 then return false end
    return math.floor(mask / flag) % 2 == 1
end

local B_PASSIVE     = 2
local B_NO_TARGET   = 4
local B_UNIT_TARGET = 8
local B_POINT       = 16
local B_CHANNELLED  = 128
local B_TOGGLE      = 512
local B_AUTOCAST    = 4096
local T_FRIENDLY    = 1
local T_BOTH        = 3

-- Скиллы перемещения, которые нельзя бездумно кастовать точкой во врага
local ESCAPE_OR_MOBILITY_SPELLS = {
    antimage_blink = true,
    queenofpain_blink = true,
    faceless_void_time_walk = true,
    mirana_leap = true,
    slark_pounce = true,
    weaver_shukuchi = true,
    morphling_waveform = true,
    puck_illusory_orb = true,
    phoenix_icarus_dive = true,
    furion_teleportation = true,
    underlord_dark_portal = true,
    void_spirit_astral_step = true,
    ember_spirit_fire_remnant = true,
    storm_spirit_ball_lightning = true,
}

local DEFAULT_DRAFT = {
    -- Pos 1: Carry (28)
    {
        "npc_dota_hero_luna", "npc_dota_hero_sven", "npc_dota_hero_juggernaut", "npc_dota_hero_drow_ranger",
        "npc_dota_hero_phantom_assassin", "npc_dota_hero_faceless_void", "npc_dota_hero_antimage", "npc_dota_hero_slark",
        "npc_dota_hero_medusa", "npc_dota_hero_spectre", "npc_dota_hero_ursa", "npc_dota_hero_life_stealer",
        "npc_dota_hero_skeleton_king", "npc_dota_hero_chaos_knight", "npc_dota_hero_terrorblade", "npc_dota_hero_morphling",
        "npc_dota_hero_phantom_lancer", "npc_dota_hero_naga_siren", "npc_dota_hero_troll_warlord", "npc_dota_hero_gyrocopter",
        "npc_dota_hero_weaver", "npc_dota_hero_monkey_king", "npc_dota_hero_clinkz", "npc_dota_hero_bloodseeker",
        "npc_dota_hero_alchemist", "npc_dota_hero_muerta", "npc_dota_hero_riki", "npc_dota_hero_kez",
    },
    -- Pos 2: Mid (28)
    {
        "npc_dota_hero_dragon_knight", "npc_dota_hero_lina", "npc_dota_hero_viper", "npc_dota_hero_death_prophet",
        "npc_dota_hero_queenofpain", "npc_dota_hero_storm_spirit", "npc_dota_hero_ember_spirit", "npc_dota_hero_void_spirit",
        "npc_dota_hero_puck", "npc_dota_hero_invoker", "npc_dota_hero_nevermore", "npc_dota_hero_zuus",
        "npc_dota_hero_sniper", "npc_dota_hero_templar_assassin", "npc_dota_hero_obsidian_destroyer", "npc_dota_hero_leshrac",
        "npc_dota_hero_huskar", "npc_dota_hero_kunkka", "npc_dota_hero_tiny", "npc_dota_hero_windrunner",
        "npc_dota_hero_tinker", "npc_dota_hero_arc_warden", "npc_dota_hero_meepo", "npc_dota_hero_lone_druid",
        "npc_dota_hero_broodmother", "npc_dota_hero_pangolier", "npc_dota_hero_razor", "npc_dota_hero_batrider",
    },
    -- Pos 3: Offlane (24)
    {
        "npc_dota_hero_tidehunter", "npc_dota_hero_centaur", "npc_dota_hero_axe", "npc_dota_hero_slardar",
        "npc_dota_hero_mars", "npc_dota_hero_bristleback", "npc_dota_hero_legion_commander", "npc_dota_hero_doom_bringer",
        "npc_dota_hero_sand_king", "npc_dota_hero_abyssal_underlord", "npc_dota_hero_shredder", "npc_dota_hero_night_stalker",
        "npc_dota_hero_beastmaster", "npc_dota_hero_dark_seer", "npc_dota_hero_brewmaster", "npc_dota_hero_magnataur",
        "npc_dota_hero_enigma", "npc_dota_hero_dawnbreaker", "npc_dota_hero_primal_beast", "npc_dota_hero_lycan",
        "npc_dota_hero_visage", "npc_dota_hero_necrolyte", "npc_dota_hero_pudge", "npc_dota_hero_furion",
    },
    -- Pos 4: Soft Support (22)
    {
        "npc_dota_hero_lion", "npc_dota_hero_shadow_shaman", "npc_dota_hero_vengefulspirit", "npc_dota_hero_ogre_magi",
        "npc_dota_hero_earthshaker", "npc_dota_hero_earth_spirit", "npc_dota_hero_rubick", "npc_dota_hero_tusk",
        "npc_dota_hero_spirit_breaker", "npc_dota_hero_nyx_assassin", "npc_dota_hero_bounty_hunter", "npc_dota_hero_mirana",
        "npc_dota_hero_hoodwink", "npc_dota_hero_snapfire", "npc_dota_hero_dark_willow", "npc_dota_hero_skywrath_mage",
        "npc_dota_hero_rattletrap", "npc_dota_hero_marci", "npc_dota_hero_phoenix", "npc_dota_hero_techies",
        "npc_dota_hero_venomancer", "npc_dota_hero_ringmaster",
    },
    -- Pos 5: Hard Support (24)
    {
        "npc_dota_hero_jakiro", "npc_dota_hero_witch_doctor", "npc_dota_hero_lich", "npc_dota_hero_crystal_maiden",
        "npc_dota_hero_dazzle", "npc_dota_hero_oracle", "npc_dota_hero_abaddon", "npc_dota_hero_omniknight",
        "npc_dota_hero_disruptor", "npc_dota_hero_warlock", "npc_dota_hero_undying", "npc_dota_hero_bane",
        "npc_dota_hero_shadow_demon", "npc_dota_hero_silencer", "npc_dota_hero_winter_wyvern", "npc_dota_hero_ancient_apparition",
        "npc_dota_hero_treant", "npc_dota_hero_chen", "npc_dota_hero_enchantress", "npc_dota_hero_keeper_of_the_light",
        "npc_dota_hero_wisp", "npc_dota_hero_grimstroke", "npc_dota_hero_pugna", "npc_dota_hero_elder_titan",
    },
}

local DEFAULT_STYLE = {
    laningEndTime     = 480,
    bountyFight       = true,
    roshanMinTime     = 900,
    roshanMinAlive    = 3,
    tormentorMinTime  = 900,
    tormentorMinAlive = 3,
    pushLaneOrder     = { mid = 1, bot = 2, top = 3 },
    pushMinAlive      = 3,
    hgMinAlive        = 4,
    hgAegisMinAlive   = 3,
    retreatHp         = 0.26,
    reengageHp        = 0.78,
    fightMinHp        = 0.38,
    smokeMinTime      = 420,
    smokeCooldown     = 120,
    jungleMinTime     = 270,
    jungleMinLevel    = 4,
    jungleMinHp       = 0.55,
    jungleSearchRange = 3000,
    jungleDangerRadius = 1100,
    farmWaveRange     = 1050,
    farmWhileStaging  = true,
    recoveryFarmSlots = 3,
    farmAbilities     = true,
    finishMaxHits     = 3,
    finishChaseRange  = 240,
    laneDistanceOffset = 0,
    laneStrafeScale   = 1,
    laneHarass        = true,
    wavePushTime      = 420,
    pushUnopposedWave = true,
    endgamePushTime   = 2700, -- после 45 мин снижаем порог сбора на ХГ
    preGameMode       = "auto", -- "auto" | "safe_bounty" | "smoke_invade"
    preGameSmokeChance = 0.45,  -- шанс инвейда под смоком в режиме "auto"
    respectCooldowns  = true,   -- учитывать КД скиллов и ультов союзников
    commsEnabled      = true,   -- вкл/выкл авто-чат команды
    commsFlame        = 0.7,    -- вероятность ругани на союзников за соло-смерти/фид (0 = спокойная команда, 1 = токсичный паб)
}

local FARM_SPELLS = {
    { "tidehunter_anchor_smash", "self", 400 },
    { "shadow_shaman_ether_shock", "target", 420 },
    { "viper_nethertoxin", "point", 375 },
    { "lina_dragon_slave", "line", 160, 1000 },
    { "dragon_knight_breathe_fire", "line", 180, 850 },
    { "axe_berserkers_call", "self", 300 },
    { "bristleback_quill_spray", "self", 650 },
    { "earthshaker_fissure", "line", 160, 1250 },
    { "gyrocopter_flak_cannon", "self", 700, nil, false },
    { "kunkka_torrent", "point", 225 },
    { "lina_light_strike_array", "point", 225 },
    { "mars_gods_rebuke", "point", 280 },
    { "nevermore_shadowraze1", "offset", 240, 200 },
    { "nevermore_shadowraze2", "offset", 240, 450 },
    { "nevermore_shadowraze3", "offset", 240, 700 },
    { "puck_illusory_orb", "line", 195, 1200 },
    { "razor_plasma_field", "self", 650 },
    { "sandking_sand_storm", "self", 400 },
    { "sven_storm_bolt", "target", 250 },
    { "tiny_avalanche", "point", 300 },
    { "ursa_earthshock", "self", 325 },
    { "windrunner_powershot", "line", 150, 1200 },
    { "zuus_arc_lightning", "target", 425 },
}

local BOSS_SPELLS = {
    { "dragon_knight_elder_dragon_form", "self", 780, nil, nil, true },
    { "sven_gods_strength", "self", 450, nil, nil, true },
    { "ursa_overpower", "self", 440, nil, nil, true },
    { "troll_warlord_battle_trance", "self", 400, nil, nil, true },
    { "shadow_shaman_mass_serpent_ward", "point", 350, nil, nil, true },
    { "slardar_amplify_damage", "target", 0 },
    { "luna_lucent_beam", "target", 0 },
    { "tidehunter_gush", "target", 0 },
    { "dazzle_poison_touch", "target", 0 },
    { "snapfire_lil_shredder", "self", 700 },
}

local RECOVERY_COMPONENTS = {
    item_sacred_relic = true, item_reaver = true, item_eagle = true, item_mystic_staff = true,
    item_demon_edge = true, item_ultimate_orb = true, item_travel_boots = true, item_travel_boots_2 = true,
}

local BASE_DATA = {
    LANES = {
        top = { x = -5800, y = 3860, z = 128 },
        mid = { x = -190, y = -190, z = 0 },
        bot = { x = 5600, y = -4280, z = 128 },
    },
    INVIS_HEROES = {
        npc_dota_hero_riki = true, npc_dota_hero_bounty_hunter = true,
        npc_dota_hero_clinkz = true, npc_dota_hero_weaver = true,
        npc_dota_hero_nyx_assassin = true, npc_dota_hero_slark = true,
        npc_dota_hero_sand_king = true, npc_dota_hero_mirana = true,
        npc_dota_hero_treant = true, npc_dota_hero_invoker = true,
        npc_dota_hero_hoodwink = true, npc_dota_hero_templar_assassin = true,
    },
    INVIS_ITEMS = {
        item_invis_sword = true, item_silver_edge = true, item_glimmer_cape = true,
    },
    EVASION_HEROES = {
        npc_dota_hero_phantom_assassin = true, npc_dota_hero_windrunner = true,
        npc_dota_hero_brewmaster = true, npc_dota_hero_arc_warden = true,
    },
    EVASION_ITEMS = {
        item_butterfly = true, item_radiance = true, item_talisman_of_evasion = true,
    },
    HEAL_HEROES = {
        npc_dota_hero_necrolyte = true, npc_dota_hero_huskar = true,
        npc_dota_hero_alchemist = true, npc_dota_hero_dazzle = true,
        npc_dota_hero_abaddon = true, npc_dota_hero_oracle = true,
        npc_dota_hero_witch_doctor = true, npc_dota_hero_pugna = true,
        npc_dota_hero_wisp = true, npc_dota_hero_bristleback = true,
    },
    ILLUSION_HEROES = {
        npc_dota_hero_phantom_lancer = true, npc_dota_hero_naga_siren = true,
        npc_dota_hero_chaos_knight = true, npc_dota_hero_terrorblade = true,
        npc_dota_hero_meepo = true, npc_dota_hero_broodmother = true,
    },
    TANK_HEROES = {
        npc_dota_hero_centaur = true, npc_dota_hero_tidehunter = true,
        npc_dota_hero_axe = true, npc_dota_hero_dragon_knight = true,
        npc_dota_hero_bristleback = true, npc_dota_hero_pudge = true,
        npc_dota_hero_abyssal_underlord = true, npc_dota_hero_shredder = true,
    },
    ELUSIVE_HEROES = {
        npc_dota_hero_antimage = true, npc_dota_hero_queenofpain = true,
        npc_dota_hero_storm_spirit = true, npc_dota_hero_puck = true,
        npc_dota_hero_ember_spirit = true, npc_dota_hero_void_spirit = true,
        npc_dota_hero_slark = true, npc_dota_hero_weaver = true,
    },
    ITEM_VALUE = {
        item_aegis = 1000, item_rapier = 990, item_refresher_shard = 950,
        item_cheese = 920, item_gem = 900, item_horn_of_battle_greater = 860,
        item_roshans_banner = 840,
        item_black_king_bar = 820, item_satanic = 810, item_butterfly = 805,
        item_monkey_king_bar = 800, item_skadi = 795, item_sheepstick = 790,
        item_bloodthorn = 785, item_heart = 780, item_shivas_guard = 775,
        item_assault = 770, item_manta = 760, item_ultimate_scepter = 755,
        item_harpoon = 740, item_abyssal_blade = 800,
        item_guardian_greaves = 750, item_pipe = 740, item_crimson_guard = 735,
        item_greater_crit = 730, item_hurricane_pike = 720, item_desolator = 710,
        item_blink = 700, item_blade_mail = 680, item_orchid = 670,
        item_kaya_and_sange = 665, item_sange_and_yasha = 665,
        item_glimmer_cape = 650, item_force_staff = 640, item_solar_crest = 630, item_pavise = 550,
        item_spirit_vessel = 620, item_aether_lens = 600, item_dragon_lance = 590,
        item_kaya = 570, item_yasha = 570, item_sange = 570,
        item_mekansm = 560, item_echo_sabre = 560, item_maelstrom = 560,
        item_power_treads = 520, item_phase_boots = 520, item_arcane_boots = 520,
        item_boots = 400, item_bottle = 390, item_magic_wand = 380,
        item_bracer = 340, item_wraith_band = 340, item_null_talisman = 340,
        item_urn_of_shadows = 330, item_buckler = 310, item_headdress = 310,
        item_dust = 305, item_ward_dispenser = 545, item_ward_observer = 540,
        item_ward_sentry = 415, item_greater_famango = 285, item_great_famango = 270,
        item_smoke_of_deceit = 260, item_magic_stick = 240, item_famango = 220,
        item_flask = 160, item_tango = 150, item_tango_single = 145,
        item_blood_grenade = 140, item_enchanted_mango = 130,
        item_quelling_blade = 110, item_clarity = 100, item_circlet = 80,
        item_slippers = 70, item_gauntlets = 70, item_mantle = 70,
        item_faerie_fire = 60, item_branches = 20,
    },
    SELLABLE_OBSOLETE = {
        item_branches = true, item_faerie_fire = true, item_clarity = true,
        item_quelling_blade = true, item_blood_grenade = true,
        item_circlet = true, item_slippers = true, item_gauntlets = true,
        item_mantle = true, item_enchanted_mango = true, item_magic_stick = true,
        item_tango = true, item_tango_single = true,
    },
    SKILLS = {
        npc_dota_hero_luna = {
            order = { 1, 3, 1, 2, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
            list = {
                { "luna_lucent_beam", "target", 800, "stun" },
                { "luna_lunar_orbit", "self", 360, "def" },
                { "luna_moon_glaive", "passive", 0, "pass" },
                { "luna_eclipse", "self", 650, "ult" },
            },
        },
        npc_dota_hero_sven = {
            order = { 1, 2, 3, 2, 2, 4, 2, 1, 1, 1, 3, 4, 3, 3, 4 },
            list = {
                { "sven_storm_bolt", "target", 600, "stun" },
                { "sven_great_cleave", "passive", 0, "pass" },
                { "sven_warcry", "self", 650, "def" },
                { "sven_gods_strength", "self", 680, "ult" },
            },
        },
        npc_dota_hero_juggernaut = {
            order = { 1, 3, 1, 2, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
            list = {
                { "juggernaut_blade_fury", "self", 280, "nuke" },
                { "juggernaut_healing_ward", "point", 420, "heal" },
                { "juggernaut_blade_dance", "passive", 0, "pass" },
                { "juggernaut_omni_slash", "target", 350, "ult" },
            },
        },
        npc_dota_hero_drow_ranger = {
            order = { 1, 3, 1, 2, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
            list = {
                { "drow_ranger_frost_arrows", "orb", 640, "nuke" },
                { "drow_ranger_wave_of_silence", "point", 750, "silence" },
                { "drow_ranger_multishot", "point", 900, "nuke" },
                { "drow_ranger_marksmanship", "passive", 0, "pass" },
            },
        },
        npc_dota_hero_dragon_knight = {
            order = { 1, 3, 2, 1, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
            list = {
                { "dragon_knight_breathe_fire", "point", 650, "nuke" },
                { "dragon_knight_dragon_tail", "target", 400, "stun" },
                { "dragon_knight_wyrms_wrath", "passive", 0, "pass" },
                { "dragon_knight_elder_dragon_form", "self", 850, "push_ult" },
            },
        },
        npc_dota_hero_lina = {
            order = { 1, 2, 3, 1, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
            list = {
                { "lina_dragon_slave", "point", 850, "nuke" },
                { "lina_light_strike_array", "point", 625, "stun" },
                { "lina_fiery_soul", "passive", 0, "pass" },
                { "lina_laguna_blade", "target", 600, "finish" },
            },
        },
        npc_dota_hero_viper = {
            order = { 1, 3, 1, 2, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
            list = {
                { "viper_poison_attack", "orb", 620, "nuke" },
                { "viper_nethertoxin", "point", 850, "nuke" },
                { "viper_corrosive_skin", "passive", 0, "pass" },
                { "viper_viper_strike", "target", 550, "ult" },
            },
        },
        npc_dota_hero_death_prophet = {
            order = { 1, 3, 1, 2, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
            list = {
                { "death_prophet_carrion_swarm", "point", 800, "nuke" },
                { "death_prophet_silence", "point", 850, "silence" },
                { "death_prophet_spirit_siphon", "target", 500, "nuke" },
                { "death_prophet_exorcism", "self", 850, "push_ult" },
            },
        },
        npc_dota_hero_tidehunter = {
            order = { 3, 2, 1, 3, 3, 4, 3, 2, 2, 2, 1, 4, 1, 1, 4 },
            list = {
                { "tidehunter_gush", "target", 700, "nuke" },
                { "tidehunter_kraken_shell", "passive", 0, "pass" },
                { "tidehunter_anchor_smash", "self", 350, "nuke" },
                { "tidehunter_ravage", "self", 900, "group" },
            },
        },
        npc_dota_hero_centaur = {
            order = { 1, 3, 2, 2, 2, 4, 2, 1, 1, 1, 3, 4, 3, 3, 4 },
            list = {
                { "centaur_hoof_stomp", "self", 315, "stun" },
                { "centaur_double_edge", "target", 220, "nuke" },
                { "centaur_return", "passive", 0, "pass" },
                { "centaur_stampede", "self", 950, "group" },
            },
        },
        npc_dota_hero_axe = {
            order = { 3, 2, 1, 3, 3, 4, 3, 1, 1, 1, 2, 4, 2, 2, 4 },
            list = {
                { "axe_berserkers_call", "self", 300, "stun" },
                { "axe_battle_hunger", "target", 700, "nuke" },
                { "axe_counter_helix", "passive", 0, "pass" },
                { "axe_culling_blade", "target", 220, "execute" },
            },
        },
        npc_dota_hero_slardar = {
            order = { 2, 3, 1, 2, 2, 4, 2, 3, 3, 3, 1, 4, 1, 1, 4 },
            list = {
                { "slardar_sprint", "self", 700, "def" },
                { "slardar_slithereen_crush", "self", 325, "stun" },
                { "slardar_bash", "passive", 0, "pass" },
                { "slardar_amplify_damage", "target", 700, "debuff" },
            },
        },
        npc_dota_hero_lion = {
            order = { 1, 2, 3, 1, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
            list = {
                { "lion_impale", "target", 575, "stun" },
                { "lion_voodoo", "target", 525, "stun" },
                { "lion_mana_drain", "target", 600, "mana" },
                { "lion_finger_of_death", "target", 600, "finish" },
            },
        },
        npc_dota_hero_shadow_shaman = {
            order = { 1, 3, 2, 1, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
            list = {
                { "shadow_shaman_ether_shock", "target", 600, "nuke" },
                { "shadow_shaman_voodoo", "target", 500, "stun" },
                { "shadow_shaman_shackles", "target", 450, "stun" },
                { "shadow_shaman_mass_serpent_ward", "point", 600, "push_ult" },
            },
        },
        npc_dota_hero_vengefulspirit = {
            order = { 1, 2, 3, 1, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
            list = {
                { "vengefulspirit_magic_missile", "target", 600, "stun" },
                { "vengefulspirit_wave_of_terror", "point", 850, "nuke" },
                { "vengefulspirit_command_aura", "passive", 0, "pass" },
                { "vengefulspirit_nether_swap", "target", 750, "finish" },
            },
        },
        npc_dota_hero_ogre_magi = {
            order = { 2, 1, 3, 2, 2, 4, 2, 1, 1, 1, 3, 4, 3, 3, 4 },
            list = {
                { "ogre_magi_fireblast", "target", 475, "stun" },
                { "ogre_magi_ignite", "target", 700, "nuke" },
                { "ogre_magi_bloodlust", "ally", 600, "buff" },
                { "ogre_magi_multicast", "passive", 0, "pass" },
            },
        },
        npc_dota_hero_jakiro = {
            order = { 1, 3, 2, 1, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
            list = {
                { "jakiro_dual_breath", "point", 750, "nuke" },
                { "jakiro_ice_path", "point", 900, "stun" },
                { "jakiro_liquid_fire", "orb", 600, "nuke" },
                { "jakiro_macropyre", "point", 850, "group" },
            },
        },
        npc_dota_hero_witch_doctor = {
            order = { 1, 3, 1, 2, 3, 4, 3, 3, 1, 1, 2, 4, 2, 2, 4 },
            list = {
                { "witch_doctor_paralyzing_cask", "target", 700, "stun" },
                { "witch_doctor_voodoo_restoration", "toggle_heal", 500, "heal" },
                { "witch_doctor_maledict", "point", 575, "nuke" },
                { "witch_doctor_death_ward", "point", 600, "group" },
            },
        },
        npc_dota_hero_lich = {
            order = { 1, 2, 3, 1, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
            list = {
                { "lich_frost_nova", "target", 600, "nuke" },
                { "lich_frost_shield", "ally", 800, "buff" },
                { "lich_sinister_gaze", "target", 525, "stun" },
                { "lich_chain_frost", "target", 650, "group" },
            },
        },
        npc_dota_hero_crystal_maiden = {
            order = { 1, 2, 3, 1, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
            list = {
                { "crystal_maiden_crystal_nova", "point", 700, "nuke" },
                { "crystal_maiden_frostbite", "target", 550, "stun" },
                { "crystal_maiden_brilliance_aura", "passive", 0, "pass" },
                { "crystal_maiden_freezing_field", "self", 500, "group" },
            },
        },
    },
    START_ITEMS = {
        [1] = { "item_quelling_blade", "item_slippers", "item_circlet", "item_branches", "item_branches", "item_flask" },
        [2] = { "item_circlet", "item_branches", "item_branches", "item_faerie_fire", "item_flask", "item_magic_stick" },
        [3] = { "item_quelling_blade", "item_gauntlets", "item_circlet", "item_branches", "item_flask", "item_faerie_fire" },
        [4] = { "item_ward_observer", "item_ward_sentry", "item_smoke_of_deceit", "item_blood_grenade", "item_magic_stick", "item_flask", "item_enchanted_mango" },
        [5] = { "item_ward_observer", "item_ward_sentry", "item_blood_grenade", "item_magic_stick", "item_flask", "item_enchanted_mango", "item_clarity" },
    },
    HERO_BUILDS = {
        npc_dota_hero_luna = { "item_magic_wand", "item_power_treads", "item_dragon_lance", "item_manta", "item_black_king_bar", "item_butterfly", "item_satanic" },
        npc_dota_hero_sven = { "item_magic_wand", "item_power_treads", "item_echo_sabre", "item_blink", "item_black_king_bar", "item_greater_crit", "item_satanic" },
        npc_dota_hero_juggernaut = { "item_magic_wand", "item_phase_boots", "item_maelstrom", "item_manta", "item_black_king_bar", "item_butterfly", "item_satanic" },
        npc_dota_hero_drow_ranger = { "item_magic_wand", "item_power_treads", "item_dragon_lance", "item_manta", "item_hurricane_pike", "item_black_king_bar", "item_butterfly" },
        npc_dota_hero_dragon_knight = { "item_bottle", "item_power_treads", "item_blink", "item_black_king_bar", "item_assault", "item_satanic" },
        npc_dota_hero_lina = { "item_bottle", "item_power_treads", "item_kaya", "item_black_king_bar", "item_greater_crit", "item_satanic" },
        npc_dota_hero_viper = { "item_bottle", "item_power_treads", "item_dragon_lance", "item_black_king_bar", "item_hurricane_pike", "item_skadi" },
        npc_dota_hero_death_prophet = { "item_bottle", "item_phase_boots", "item_kaya_and_sange", "item_black_king_bar", "item_shivas_guard", "item_heart" },
        npc_dota_hero_tidehunter = { "item_bracer", "item_arcane_boots", "item_blink", "item_pipe", "item_shivas_guard", "item_guardian_greaves" },
        npc_dota_hero_centaur = { "item_bracer", "item_phase_boots", "item_blink", "item_blade_mail", "item_pipe", "item_heart" },
        npc_dota_hero_axe = { "item_bracer", "item_phase_boots", "item_blink", "item_blade_mail", "item_black_king_bar", "item_crimson_guard" },
        npc_dota_hero_slardar = { "item_bracer", "item_power_treads", "item_blink", "item_black_king_bar", "item_assault", "item_satanic" },
    },
    ROLE_BUILDS = {
        [1] = { "item_magic_wand", "item_power_treads", "item_manta", "item_black_king_bar", "item_butterfly", "item_satanic" },
        [2] = { "item_bottle", "item_power_treads", "item_kaya", "item_black_king_bar", "item_blink", "item_shivas_guard" },
        [3] = { "item_bracer", "item_phase_boots", "item_blink", "item_blade_mail", "item_pipe", "item_crimson_guard" },
        [4] = { "item_arcane_boots", "item_glimmer_cape", "item_blink", "item_force_staff", "item_sheepstick" },
        [5] = { "item_arcane_boots", "item_glimmer_cape", "item_force_staff", "item_pavise", "item_solar_crest", "item_guardian_greaves" },
    },
}

-- ============================================================================
-- U: Публичные утилиты (доступны тактике через ctx.U)
-- ============================================================================
local U = {}

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function mapPosition(pos)
    return type(pos) == "table" and finite(pos.x) and finite(pos.y)
        and (pos.z == nil or finite(pos.z))
end

function U.dist(a, b)
    if not a or not b then return math.huge end
    local dx, dy = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

function U.towards(a, b, len)
    local d = U.dist(a, b)
    if d <= 1 then return { x = a.x, y = a.y, z = a.z or 0 } end
    local k = math.min(1, len / d)
    return { x = a.x + (b.x - a.x) * k, y = a.y + (b.y - a.y) * k, z = b.z or a.z or 0 }
end

function U.away(a, threat, len)
    local d = U.dist(a, threat)
    if d <= 1 then return { x = a.x + len, y = a.y, z = a.z or 0 } end
    local k = len / d
    return { x = a.x + (a.x - threat.x) * k, y = a.y + (a.y - threat.y) * k, z = a.z or 0 }
end

function U.ratio(a, b)
    return (a or 0) / math.max(1, b or 1)
end

function U.armorMult(armor)
    local a = armor or 0
    return 1 - (0.06 * a) / (1 + 0.06 * math.abs(a))
end

function U.hasItem(actor, name, onlyMain)
    for slot, item in pairs(actor.items or {}) do
        if item == name then
            if not onlyMain or slot <= 5 or slot == 15 or slot == 16 then
                return slot
            end
        end
    end
    return nil
end

function U.itemCd(actor, slot)
    return (actor.itemCooldown or {})[slot] or 0
end

function U.itemCharges(actor, slot)
    return (actor.itemCharges or {})[slot] or 0
end

function U.itemSecCharges(actor, slot)
    return (actor.itemSecondaryCharges or {})[slot] or 0
end

function U.findPin(snapshot, kind, pred)
    for _, pin in ipairs(snapshot.pins or {}) do
        if pin.kind == kind and (not pred or pred(pin)) then return pin end
    end
    return nil
end

function U.nearest(list, origin, maxDist, pred)
    local best, bestD = nil, maxDist or math.huge
    for _, row in ipairs(list or {}) do
        if row and row.pos and row.alive ~= false and (not pred or pred(row)) then
            local d = U.dist(row.pos, origin)
            if d < bestD then best, bestD = row, d end
        end
    end
    return best, bestD
end

function U.countNear(list, origin, radius, pred)
    local n = 0
    for _, row in ipairs(list or {}) do
        if row and row.pos and row.alive ~= false and U.dist(row.pos, origin) <= radius
            and (not pred or pred(row)) then
            n = n + 1
        end
    end
    return n
end

function U.isLaneCreep(u)
    return u and (u.kind == "lane_creep" or u.kind == "siege_creep")
end

function U.isRealHero(u)
    return u and u.kind == "hero" and not u.isIllusion
end

function U.isBuilding(u)
    return u and (u.kind == "tower" or u.kind == "barracks" or u.kind == "ancient" or u.kind == "building")
end

function U.skillMap(actor)
    local m = {}
    for _, ab in pairs(actor.abilities or {}) do
        if ab and ab.name then m[ab.name] = ab end
    end
    return m
end

function U.canCast(actor, ability)
    return ability and not actor.stunned and not actor.hexed and not actor.silenced
        and not ability.passive and not ability.hidden and (ability.level or 0) > 0
        and ability.fullyCastable and (ability.cooldown or 0) <= 0
end

local VALID_LANES = { safe = true, mid = true, off = true, top = true, bot = true }

-- ============================================================================
-- BaseBot.Create(tactic): фабрика независимой команды на общей базе
-- ============================================================================
function BaseBot.Create(tactic)
    tactic = type(tactic) == "table" and tactic or {}

    local STYLE = mergeTable(DEFAULT_STYLE, tactic.style)
    local PROFILES, HERO_STYLES = {}, {}
    local farmStartsAt = STYLE.jungleMinTime
    if type(tactic.heroProfiles) == "table" then
        for name, profile in pairs(tactic.heroProfiles) do
            if type(name) == "string" and type(profile) == "table" then
                profile = shallowCopy(profile)
                for _, key in ipairs({ "style", "startItems", "itemBuild", "skillBuild", "skills", "manualItems", "manualAbilities" }) do
                    if type(profile[key]) ~= "table" then profile[key] = nil end
                end
                PROFILES[name] = profile
                local style = shallowCopy(STYLE)
                if type(profile.style) == "table" then
                    for key, value in pairs(profile.style) do
                        if type(value) == type(DEFAULT_STYLE[key])
                            and (type(value) ~= "number" or finite(value)) then
                            style[key] = value
                        end
                    end
                end
                HERO_STYLES[name] = style
                farmStartsAt = math.min(farmStartsAt, HERO_STYLES[name].jungleMinTime)
            end
        end
    end
    local function heroStyle(actor)
        return HERO_STYLES[actor.name] or STYLE
    end
    local DATA = {
        LANES             = BASE_DATA.LANES,
        INVIS_HEROES      = BASE_DATA.INVIS_HEROES,
        INVIS_ITEMS       = BASE_DATA.INVIS_ITEMS,
        EVASION_HEROES    = BASE_DATA.EVASION_HEROES,
        EVASION_ITEMS     = BASE_DATA.EVASION_ITEMS,
        HEAL_HEROES       = BASE_DATA.HEAL_HEROES,
        ILLUSION_HEROES   = BASE_DATA.ILLUSION_HEROES,
        TANK_HEROES       = BASE_DATA.TANK_HEROES,
        ELUSIVE_HEROES    = BASE_DATA.ELUSIVE_HEROES,
        ITEM_VALUE        = mergeTable(BASE_DATA.ITEM_VALUE, tactic.itemValues),
        SELLABLE_OBSOLETE = BASE_DATA.SELLABLE_OBSOLETE,
        SKILLS            = mergeTable(mergeTable(BASE_DATA.SKILLS, HeroPack.SKILLS), tactic.skills),
        START_ITEMS       = mergeTable(BASE_DATA.START_ITEMS, tactic.startItems),
        HERO_BUILDS       = mergeTable(mergeTable(BASE_DATA.HERO_BUILDS, HeroPack.HERO_BUILDS), tactic.heroBuilds),
        ROLE_BUILDS       = mergeTable(BASE_DATA.ROLE_BUILDS, tactic.roleBuilds),
    }
    for name, profile in pairs(PROFILES) do
        if type(profile.skills) == "table" and type(profile.skills.list) == "table" then
            DATA.SKILLS[name] = profile.skills
        end
    end

    -- Изолированная память конкретного экземпляра команды
    local MEM = {
        heroes = {},
        bossScoutAfter = { roshan = {}, tormentor = {} },
        clearedTowers = {},
        stunCastAt = {},
        observerOrders = {},
        lastSmokeAt = -999,
        comms = Comms.newState(),
        lastPushLane = nil,
        lastPushAt = -999,
        waveArrived = { top = false, mid = false, bot = false },
        preGamePlan = nil,
        preGameDone = {},
        creepHp = {},
        emptyCamps = {},
        custom = {},
        heroContexts = {},
        customChatAt = {},
    }

    local Team = {
        name  = tactic.name or "BaseBot Team",
        draft = type(tactic.draft) == "table" and tactic.draft or DEFAULT_DRAFT,
        lanes = type(tactic.lanes) == "table" and tactic.lanes or { "safe", "mid", "off", "off", "safe" },
    }

    local ctx = {
        U = U,
        style = STYLE,
        data = DATA,
        mem = MEM.custom,
        team = Team,
        comms = MEM.comms,
        say = function(actor, text, tone, delay)
            if not (actor and actor.id) or type(text) ~= "string" or text == "" then return end
            local now = MEM.lastTime or 0
            if now < (MEM.customChatAt[actor.id] or -math.huge) then return end
            MEM.customChatAt[actor.id] = now + 3
            Comms.say(MEM.comms, now, actor, text, type(tone) == "string" and tone or nil,
                finite(delay) and math.max(0, delay) or nil)
        end,
        setDirective = function(dir)
            if type(dir) ~= "table" or type(dir.kind) ~= "string" then return end
            if dir.kind == "HELP_GANK" and (not mapPosition(dir.pos) or type(dir.assignedIds) ~= "table") then return end
            if dir.kind == "WAIT_ITEM" and (not finite(dir.callerId) or type(dir.item) ~= "string") then return end
            local call = shallowCopy(dir)
            call.expiresAt = finite(dir.expiresAt) and dir.expiresAt or (MEM.lastTime or 0) + 10
            if call.expiresAt <= (MEM.lastTime or 0) then return end
            if call.kind == "WAIT_ITEM" and type(call.itemLabel) ~= "string" then call.itemLabel = call.item end
            MEM.comms.directive = call
        end,
    }

    local function itemVal(name)
        if not name then return 0 end
        return DATA.ITEM_VALUE[name] or 250
    end

    local function callHook(fn, context, ...)
        if type(fn) ~= "function" then return nil end
        local ok, res = pcall(fn, context, ...)
        if ok then return res end
        MEM.lastHookError = tostring(res)
        return nil
    end

    local function safeHook(fn, ...)
        return callHook(fn, ctx, ...)
    end

    local function heroHook(actor, name, ...)
        local profile = PROFILES[actor.name]
        local fn = profile and profile[name]
        if type(fn) ~= "function" then return nil end
        local heroContext = MEM.heroContexts[actor.id]
        if not heroContext then
            heroContext = setmetatable({ heroMem = {}, profile = profile, style = heroStyle(actor) }, { __index = ctx })
            MEM.heroContexts[actor.id] = heroContext
        end
        return callHook(fn, heroContext, ...)
    end

    -- ========================================================================
    -- Драфт и баны
    -- ========================================================================
    if type(tactic.BanHero) == "function" then
        function Team:BanHero(available, allyPicks, enemyPicks, bans)
            return safeHook(tactic.BanHero, available, allyPicks, enemyPicks, bans)
        end
    end

    function Team:GetLanes(side, allyPicks, enemyPicks)
        local chosen = safeHook(tactic.GetLanes, side, allyPicks, enemyPicks)
        local lanes = {}
        for pos = 1, 5 do
            local profile = allyPicks and PROFILES[allyPicks[pos]]
            local custom = type(chosen) == "table" and chosen[pos]
            local preferred = profile and profile.lane
            lanes[pos] = (VALID_LANES[custom] and custom)
                or (VALID_LANES[preferred] and preferred) or self.lanes[pos]
        end
        return lanes
    end

    function Team:PickHero(pos, role, available, allyPicks, enemyPicks, bans)
        local customPick = safeHook(tactic.PickHero, pos, role, available, allyPicks, enemyPicks, bans)
        if type(customPick) == "string" and available and available[customPick] then
            return customPick
        end

        local pool = self.draft[pos] or {}
        if type(pool) == "string" then
            if available and available[pool] then return pool end
            pool = {}
        end

        local enemyStats = { illus = 0, tanks = 0, elusive = 0, invis = 0, heal = 0 }
        for _, ename in pairs(enemyPicks or {}) do
            if DATA.ILLUSION_HEROES[ename] then enemyStats.illus = enemyStats.illus + 1 end
            if DATA.TANK_HEROES[ename] then enemyStats.tanks = enemyStats.tanks + 1 end
            if DATA.ELUSIVE_HEROES[ename] then enemyStats.elusive = enemyStats.elusive + 1 end
            if DATA.INVIS_HEROES[ename] then enemyStats.invis = enemyStats.invis + 1 end
            if DATA.HEAL_HEROES[ename] then enemyStats.heal = enemyStats.heal + 1 end
        end

        local bestHero, bestScore = nil, -math.huge
        for idx, heroName in ipairs(pool) do
            if available[heroName] then
                local score = STYLE.randomDraft and math.random(0, 20) or math.max(0, 30 - (idx - 1) * 1.2)
                if enemyStats.illus > 0 and (heroName == "npc_dota_hero_sven" or heroName == "npc_dota_hero_axe"
                    or heroName == "npc_dota_hero_jakiro" or heroName == "npc_dota_hero_tidehunter") then
                    score = score + 28
                end
                if enemyStats.tanks > 0 and (heroName == "npc_dota_hero_viper" or heroName == "npc_dota_hero_slardar"
                    or heroName == "npc_dota_hero_witch_doctor" or heroName == "npc_dota_hero_drow_ranger") then
                    score = score + 24
                end
                if (enemyStats.elusive > 0 or enemyStats.invis > 0) and (heroName == "npc_dota_hero_lion"
                    or heroName == "npc_dota_hero_shadow_shaman" or heroName == "npc_dota_hero_axe"
                    or heroName == "npc_dota_hero_dragon_knight") then
                    score = score + 26
                end
                if enemyStats.heal > 0 and (heroName == "npc_dota_hero_viper" or heroName == "npc_dota_hero_lina") then
                    score = score + 18
                end
                local profile = PROFILES[heroName]
                if profile and finite(profile.draftWeight) then score = score + profile.draftWeight end
                if score > bestScore then
                    bestHero, bestScore = heroName, score
                end
            end
        end
        if bestHero then return bestHero end

        for _, rolePool in ipairs(self.draft) do
            if type(rolePool) == "table" then
                for _, heroName in ipairs(rolePool) do
                    if available[heroName] then return heroName end
                end
            elseif type(rolePool) == "string" and available[rolePool] then
                return rolePool
            end
        end
        for heroName in pairs(available or {}) do
            return heroName
        end
        return "npc_dota_hero_luna"
    end

    -- ========================================================================
    -- INV: Прокачка, менеджер слотов, адаптивные закупы
    -- ========================================================================
    local INV = {}

    function INV.pickSkillToLearn(snapshot, actor, byName)
        local hasPoints = (actor.abilityPoints or 0) > 0
        local talent = Talents.firstAvailable(actor.abilities)
        if not hasPoints and not talent then return nil end

        local function availableSkill(name)
            local ab = type(name) == "string" and byName[name]
            if ab and ab.canUpgrade and (not ab.hidden or Talents.isTalent(name))
                and (hasPoints or Talents.isTalent(name)) then
                return { kind = "learn", ability = name, status = "Качаю скилл" }
            end
        end

        local picked = availableSkill(heroHook(actor, "PickSkill", snapshot, actor, byName))
        local profile = PROFILES[actor.name]
        if not picked and profile and type(profile.skillBuild) == "table" then
            picked = availableSkill(profile.skillBuild[actor.level])
        end
        picked = picked or availableSkill(safeHook(tactic.PickSkill, snapshot, actor, byName))
        if picked then return picked end
        if not hasPoints then return { kind = "learn", ability = talent.name, status = "Беру талант" } end
        local cfg = DATA.SKILLS[actor.name]

        if cfg and type(cfg.list) == "table" then
            local ultSpec = cfg.list[4]
            local ult = ultSpec and byName[ultSpec[1]]
            if ult and ult.canUpgrade and not ult.hidden and (ult.level or 0) < 3 then
                return { kind = "learn", ability = ult.name, status = "Качаю ульт" }
            end

            if talent then return { kind = "learn", ability = talent.name, status = "Беру талант" } end

            local spent = 0
            for i = 1, 4 do
                local ab = cfg.list[i] and byName[cfg.list[i][1]]
                spent = spent + (ab and ab.level or 0)
            end
            local targetSlot = cfg.order and cfg.order[spent + 1]
            if targetSlot and cfg.list[targetSlot] then
                local ab = byName[cfg.list[targetSlot][1]]
                if ab and ab.canUpgrade and not ab.hidden then
                    return { kind = "learn", ability = ab.name, status = "Качаю скилл" }
                end
            end
            for i = 1, 4 do
                local ab = cfg.list[i] and byName[cfg.list[i][1]]
                if ab and ab.canUpgrade and not ab.hidden then
                    return { kind = "learn", ability = ab.name, status = "Качаю скилл" }
                end
            end
        end

        -- Универсальная прокачка для любого героя (сначала ульт/базовые слоты 0..5, затем таланты)
        local candidates = {}
        for slot, ab in pairs(actor.abilities or {}) do
            if ab and ab.canUpgrade and ab.name
                and (not ab.hidden or Talents.isTalent(ab.name))
                and ab.name ~= "special_bonus_attributes" then
                local isTalent = Talents.isTalent(ab.name)
                local isUlt = ab.isUltimate or (not isTalent and ab.maxLevel == 3)
                local prio = isUlt and 1 or (isTalent and 50 or (slot + 10))
                candidates[#candidates + 1] = { name = ab.name, prio = prio, slot = slot }
            end
        end
        table.sort(candidates, function(a, b)
            if a.prio == b.prio then return a.slot < b.slot end
            return a.prio < b.prio
        end)
        if candidates[1] then
            return { kind = "learn", ability = candidates[1].name, status = "Качаю скилл" }
        end
        return nil
    end

    function INV.analyzeThreats(snapshot)
        local th = { invis = false, evasion = false, heal = false }
        local function scanHero(name, items, isInvis)
            if isInvis or DATA.INVIS_HEROES[name] then th.invis = true end
            if DATA.EVASION_HEROES[name] then th.evasion = true end
            if DATA.HEAL_HEROES[name] then th.heal = true end
            for _, it in pairs(items or {}) do
                if DATA.INVIS_ITEMS[it] then th.invis = true end
                if DATA.EVASION_ITEMS[it] then th.evasion = true end
            end
        end
        for _, e in ipairs(snapshot.enemies or {}) do
            if U.isRealHero(e) then scanHero(e.name, e.items, e.invisible) end
        end
        for _, rec in pairs(snapshot.enemyLastSeen or {}) do
            scanHero(rec.name, rec.items, false)
        end
        return th
    end

    function INV.lateSellable(actor, name)
        return name == "item_bracer" or name == "item_wraith_band" or name == "item_null_talisman"
            or name == "item_magic_wand" or name == "item_bottle" or DATA.SELLABLE_OBSOLETE[name]
            or (name == "item_buckler" and U.hasItem(actor, "item_assault") ~= nil)
    end

    function INV.manageSlots(snapshot, actor, basePos, st, dropNearby)
        local out = {}
        local now = snapshot.time
        local items = actor.items or {}

        local earlyComponents = {
            item_magic_stick = { "item_magic_wand" },
            item_branches    = { "item_magic_wand", "item_headdress", "item_buckler" },
            item_circlet     = { "item_bracer", "item_wraith_band", "item_null_talisman" },
            item_gauntlets   = { "item_bracer" },
            item_slippers    = { "item_wraith_band" },
            item_mantle      = { "item_null_talisman" },
        }
        local function isNeededComponent(itemName)
            local targets = earlyComponents[itemName]
            if not targets or not st.activeBuildSet then return false end
            for _, target in ipairs(targets) do
                if st.activeBuildSet[target] and U.hasItem(actor, target, true) == nil then
                    return true
                end
            end
            return false
        end

        if now - (st.lastSwapAt or -99) >= 1.5 then
            local bestBpSlot, bestBpVal = nil, -1
            for s = 6, 8 do
                local name = items[s]
                if name then
                    local v = itemVal(name)
                    if v > bestBpVal then bestBpSlot, bestBpVal = s, v end
                end
            end

            if bestBpSlot then
                local lockWard = st.wardSwapUntil and now < st.wardSwapUntil
                local worstMainSlot, worstMainVal = nil, math.huge
                for s = 0, 5 do
                    local name = items[s]
                    if not name then
                        worstMainSlot, worstMainVal = s, -1
                        break
                    elseif not (lockWard and (name == "item_ward_observer" or name == "item_ward_dispenser")) then
                        local v = itemVal(name)
                        if v < worstMainVal then worstMainSlot, worstMainVal = s, v end
                    end
                end
                if worstMainSlot and bestBpVal > worstMainVal + 15 then
                    st.lastSwapAt = now
                    out[#out + 1] = { kind = "swap", slot_a = bestBpSlot, slot_b = worstMainSlot }
                end
            end
        end

        local occupied, cheapestUpgradeSlot = 0, nil
        local lowestSlot, lowestVal = nil, math.huge
        for s = 0, 8 do
            local name = items[s]
            if name then
                occupied = occupied + 1
                local v = itemVal(name)
                if v < lowestVal then lowestSlot, lowestVal = s, v end
                if INV.lateSellable(actor, name)
                    and (not cheapestUpgradeSlot or v < itemVal(items[cheapestUpgradeSlot])) then
                    cheapestUpgradeSlot = s
                end
            end
        end

        local atShop = not actor.alive or actor.atHomeShop == true
            or (actor.atHomeShop == nil and U.dist(actor.pos, basePos) < 450)
        if atShop and now >= 1500 and occupied >= 6 and cheapestUpgradeSlot then
            local canReplace = (st.shopItem and st.lastShopSale ~= st.shopItem)
                or (occupied >= 8 and (actor.gold or 0) >= 2600)
            if canReplace then
                st.lastShopSale = st.shopItem
                return { { kind = "sell", slot = cheapestUpgradeSlot, expectedItem = items[cheapestUpgradeSlot],
                    status = "Продаю стартовый предмет под апгрейд" } }
            end
        end
        if atShop and occupied >= 6 and lowestSlot and now > 360 then
            local name = items[lowestSlot]
            local canSell = (DATA.SELLABLE_OBSOLETE[name] and not isNeededComponent(name))
                or (occupied >= 8 and lowestVal <= 350 and now > 900)
            if canSell and not isNeededComponent(name) and not (name == "item_quelling_blade" and now < 720 and actor.position <= 3) then
                return { { kind = "sell", slot = lowestSlot, expectedItem = name } }
            end
        end

        local needSpaceForDrop = dropNearby and occupied >= 8
        local fullForCourier = occupied >= 9
        if actor.alive and not atShop and (fullForCourier or needSpaceForDrop) then
            local dropSlot, dropVal = nil, math.huge
            for s = 0, 8 do
                local name = items[s]
                if name then
                    local v = itemVal(name)
                    local obsoleteOrCheap = DATA.SELLABLE_OBSOLETE[name] or name == "item_flask" or v <= 150
                    local allowed = needSpaceForDrop and (v <= 340) or (obsoleteOrCheap and v <= 245)
                    if allowed and v < dropVal then
                        dropSlot, dropVal = s, v
                    end
                end
            end
            if dropSlot and now - (st.lastDropAt or -99) >= 2.0 then
                st.lastDropAt = now
                out[#out + 1] = { kind = "drop", slot = dropSlot, status = "Освобождаю слот" }
            end
        end

        return out
    end

    function INV.getBuildForHero(actor, threats, snapshot)
        local profile = PROFILES[actor.name]
        local base = (profile and profile.itemBuild) or DATA.HERO_BUILDS[actor.name]
            or DATA.ROLE_BUILDS[actor.position] or DATA.ROLE_BUILDS[1]
        local list = {}
        for i = 1, #base do list[i] = base[i] end

        if snapshot and snapshot.time >= 1440 and not (profile and profile.itemBuild) then
            local planned = {}
            for _, item in ipairs(list) do planned[item] = true end
            if planned.item_echo_sabre and not planned.item_harpoon then
                list[#list + 1] = "item_harpoon"
            end
            if actor.position <= 3 and not planned.item_black_king_bar then
                list[#list + 1] = "item_black_king_bar"
            end
            if actor.name == "npc_dota_hero_chaos_knight" then
                list[#list + 1] = "item_abyssal_blade"
            end
        end

        if threats.evasion and (actor.position == 1 or actor.position == 2) then
            local hasMkb = false
            for _, it in ipairs(list) do if it == "item_monkey_king_bar" then hasMkb = true end end
            if not hasMkb then table.insert(list, math.min(5, #list + 1), "item_monkey_king_bar") end
        end
        if threats.heal and actor.position == 4 then
            local hasVes = false
            for _, it in ipairs(list) do if it == "item_spirit_vessel" then hasVes = true end end
            if not hasVes then table.insert(list, 2, "item_spirit_vessel") end
        end

        local custom = heroHook(actor, "GetItemBuild", actor, threats, list, snapshot)
        if type(custom) ~= "table" or #custom == 0 then
            custom = safeHook(tactic.GetItemBuild, actor, threats, list, snapshot)
        end
        if type(custom) == "table" and #custom > 0 then
            return custom
        end
        return list
    end

    function INV.getTpState(actor)
        -- Boots of Travel меняют свойства свитка. Каст по-прежнему идёт из TP-слота.
        local isTravel = U.hasItem(actor, "item_travel_boots_2", true) ~= nil
            or U.hasItem(actor, "item_travel_boots", true) ~= nil
        local tpName = (actor.items or {})[15]
        local charges = (tpName == "item_tpscroll") and math.max(0, U.itemCharges(actor, 15)) or 0
        local cd = (tpName == "item_tpscroll") and U.itemCd(actor, 15) or 999
        return {
            hasTp = charges > 0,
            charges = charges,
            ready = charges > 0 and cd <= 0 and ((actor.maxMana or 0) <= 0 or (actor.mana or 0) >= 75)
                and actor.tpCastable ~= false and not actor.rooted and not actor.muted and not actor.stunned and not actor.hexed,
            cd = cd,
            isTravel = isTravel,
        }
    end

    function INV.hasCourierItem(actor, item)
        for _, name in ipairs(actor.courier and actor.courier.carrying or {}) do
            if name == item then return true end
        end
        return false
    end

    -- Умное ускорение и щит курьера (мгновенные команды, не мешают герою)
    function INV.decideCourier(snapshot, actor, st)
        local c = actor.courier
        if not c or not c.alive then return {} end
        local now = snapshot.time
        local out = {}

        -- 1. Вражеский герой рядом с курьером — сразу жмём щит и ускорение!
        local danger = c.pos and U.countNear(snapshot.enemies, c.pos, 1050, U.isRealHero) > 0
        if danger then
            if c.shieldReady then
                out[#out + 1] = { kind = "courier_shield" }
            end
            if c.burstReady then
                out[#out + 1] = { kind = "courier_burst" }
                st.lastCourierBurstAt = now
            end
            return out
        end

        if not c.burstReady or (now - (st.lastCourierBurstAt or -99)) < 3.0 then
            return out
        end

        -- 2. Курьер везёт груз издалека (>= 1200) или ключевой предмет/хил/TP/вард (>= 750)
        if c.hasCargo and actor.alive then
            local urgentCargo = false
            for _, it in ipairs(c.carrying or {}) do
                if it == "item_tpscroll" or it == "item_flask" or it == "item_ward_observer"
                    or it == "item_dust" or it == "item_smoke_of_deceit"
                    or (DATA.ITEM_VALUE[it] or 0) >= 520 then
                    urgentCargo = true
                    break
                end
            end
            if (urgentCargo and (c.distToHero or 0) >= 750) or (c.distToHero or 0) >= 1350 then
                st.lastCourierBurstAt = now
                out[#out + 1] = { kind = "courier_burst" }
                return out
            end
        end

        -- 3. Курьер летит обратно на базу за вещами в тайнике
        if (not c.hasCargo) and (not c.atHome) and c.hasStash then
            st.lastCourierBurstAt = now
            out[#out + 1] = { kind = "courier_burst" }
        end

        return out
    end

    function INV.decideShopping(snapshot, actor, st, threats, nearEnemy, basePos, macro)
        local now = snapshot.time
        local gold = actor.gold or 0

        local dying = actor.alive and U.ratio(actor.hp, actor.maxHp) < 0.18 and nearEnemy ~= nil
        if not dying and now < (st.nextBuy or -9999) then return nil end

        if now < 0 then
            local profile = PROFILES[actor.name]
            local startList = (profile and profile.startItems) or DATA.START_ITEMS[actor.position] or {}
            st.startIdx = st.startIdx or 1
            if startList[st.startIdx] then
                local item = startList[st.startIdx]
                st.startIdx = st.startIdx + 1
                st.nextBuy = now + 0.25
                return { kind = "buy", item = item, status = "Стартовый закуп" }
            end
            return nil
        end

        local pos = actor.position

        local occupiedSlots = 0
        for s = 0, 8 do
            if (actor.items or {})[s] then occupiedSlots = occupiedSlots + 1 end
        end
        local hasWardStack = U.hasItem(actor, "item_ward_dispenser") ~= nil
            or U.hasItem(actor, "item_ward_observer") ~= nil
            or U.hasItem(actor, "item_ward_sentry") ~= nil

        local tp = INV.getTpState(actor)
        if gold >= 100 then
            local atBase = (not actor.alive) or actor.atHomeShop == true
            local pending = INV.hasCourierItem(actor, "item_tpscroll")
            for slot = 9, 14 do
                if actor.items and actor.items[slot] == "item_tpscroll" then pending = true; break end
            end
            local needUrgentTp = macro and macro.pos and U.dist(actor.pos, macro.pos) > 2500
                and (macro.phase == "DEFEND" or macro.phase == "PUSH" or macro.phase == "ROSHAN" or macro.phase == "TORMENTOR")
            local wantFirstTp = (not tp.hasTp) and (
                (atBase and now >= 40)
                or needUrgentTp
                or (now >= 120)
            )
            -- В мид/лейт-гейме держим 2 заряда TP при выходе с фонтана, чтобы после TP на линию остался запас на деф
            local wantSecondTp = not tp.isTravel and atBase and tp.charges == 1 and now >= 420 and gold >= 350

            if (wantFirstTp or wantSecondTp) and (atBase or not pending) and now >= (st.nextTpBuy or 0) then
                st.nextTpBuy = now + (atBase and 2.5 or 8.0)
                st.nextBuy = now + 0.4
                return { kind = "buy", item = "item_tpscroll", status = "Покупаю TP" }
            end
        end

        if threats.invis and pos >= 3 and not U.hasItem(actor, "item_dust") and gold >= 80
            and occupiedSlots < 9 and not INV.hasCourierItem(actor, "item_dust")
            and now >= (st.nextDustBuy or 0) then
            st.nextDustBuy = now + 20
            st.nextBuy = now + 0.8
            return { kind = "buy", item = "item_dust", status = "Покупаю Dust" }
        end

        if pos >= 4 then
            local dSlot = U.hasItem(actor, "item_ward_dispenser")
            local obsCount = (U.hasItem(actor, "item_ward_observer") and 1 or 0) + (dSlot and U.itemCharges(actor, dSlot) or 0)
            local senCount = (U.hasItem(actor, "item_ward_sentry") and 1 or 0) + (dSlot and U.itemSecCharges(actor, dSlot) or 0)

            if obsCount == 0 and (occupiedSlots < 9 or hasWardStack) and not INV.hasCourierItem(actor, "item_ward_observer") and now >= (st.nextObsBuy or 75) then
                st.nextObsBuy = now + 70
                st.nextBuy = now + 0.8
                return { kind = "buy", item = "item_ward_observer", status = "Покупаю Observer" }
            end
            if senCount == 0 and gold >= 50 and (occupiedSlots < 9 or hasWardStack) and not INV.hasCourierItem(actor, "item_ward_sentry")
                and now >= (st.nextSenBuy or 100) and (pos == 5 or threats.invis) then
                st.nextSenBuy = now + (threats.invis and 55 or 85)
                st.nextBuy = now + 0.8
                return { kind = "buy", item = "item_ward_sentry", status = "Покупаю Sentry" }
            end
            if pos == 4 and gold >= 50 and occupiedSlots < 9 and not INV.hasCourierItem(actor, "item_smoke_of_deceit")
                and now >= (st.nextSmokeBuy or STYLE.smokeMinTime)
                and not U.hasItem(actor, "item_smoke_of_deceit") then
                st.nextSmokeBuy = now + 110
                st.nextBuy = now + 0.8
                return { kind = "buy", item = "item_smoke_of_deceit", status = "Покупаю Smoke" }
            end
        end

        if now > 45 and now < 420 and actor.alive and U.ratio(actor.hp, actor.maxHp) < 0.48
            and not U.hasItem(actor, "item_flask") and gold >= 110 and now >= (st.nextSalveBuy or 0) then
            st.nextSalveBuy = now + 90
            st.nextBuy = now + 0.8
            return { kind = "buy", item = "item_flask", status = "Везу Salve курьером" }
        end

        if now > 90 and now < 900 and actor.alive and pos >= 2
            and U.ratio(actor.mana, actor.maxMana) < 0.32
            and not actor.hasClarity and not U.hasItem(actor, "item_clarity")
            and not U.hasItem(actor, "item_bottle") and not U.hasItem(actor, "item_arcane_boots")
            and gold >= 50 and now >= (st.nextClarityBuy or 0) then
            st.nextClarityBuy = now + 95
            st.nextBuy = now + 0.8
            return { kind = "buy", item = "item_clarity", status = "Везу Clarity курьером" }
        end

        local build = INV.getBuildForHero(actor, threats, snapshot)
        st.activeBuildSet = {}
        for _, it in ipairs(build) do st.activeBuildSet[it] = true end
        st.boughtItems = st.boughtItems or {}
        local courierCargo = {}
        for _, name in ipairs(actor.courier and actor.courier.carrying or {}) do
            courierCargo[name] = true
        end
        for _, it in ipairs(build) do
            if U.hasItem(actor, it)
                or (it == "item_echo_sabre" and U.hasItem(actor, "item_harpoon"))
                or (it == "item_pavise" and U.hasItem(actor, "item_solar_crest")) then
                st.boughtItems[it] = true
            end
        end
        local targetItem
        st.shopItem = nil
        for _, it in ipairs(build) do
            if not st.boughtItems[it] and not U.hasItem(actor, it) then
                targetItem = it
                break
            end
        end
        if now >= 1500 then
            local occupied, obsolete, cargoUpgrade = 0, false, false
            for slot = 0, 8 do
                local item = (actor.items or {})[slot]
                if item then
                    occupied = occupied + 1
                    obsolete = obsolete or INV.lateSellable(actor, item)
                    cargoUpgrade = cargoUpgrade or (slot >= 6 and itemVal(item) >= 590)
                end
            end
            local replacement = targetItem and (targetItem ~= "item_harpoon" or occupied >= 9)
                and ((gold >= 3000 and itemVal(targetItem) >= 590) or courierCargo[targetItem])
            if occupied >= 6 and obsolete and (replacement or cargoUpgrade) then
                st.shopItem = replacement and targetItem or "backpack"
            end
        end
        if not st.shopItem then st.lastShopSale = nil end
        if targetItem and courierCargo[targetItem] then return nil end
        if targetItem and (gold >= 300 or (dying and gold >= 150)) then
            st.nextBuy = now + 1.4
            return { kind = "buy", item = targetItem, status = dying and "Трачу золото" or "Закупаюсь курьером" }
        end

        return nil
    end

    function INV.scoreNeutralStats(actor, stats, isActive)
        local pos = actor.position or 1
        local score = isActive and 8 or 0
        for k, v in pairs(stats or {}) do
            local val = math.abs(v or 0)
            if k:find("attack_range") then
                score = score + (actor.ranged and (pos <= 2 and 45 or 20) or 4)
            elseif k:find("cast_range") then
                score = score + (pos >= 4 and 48 or (pos == 2 and 34 or 12))
            elseif k:find("mana_regen") or k:find("bonus_mana") then
                score = score + (pos >= 4 and 28 or (pos == 2 and 24 or 10))
            elseif k:find("cooldown") then
                score = score + (pos >= 2 and 36 or 18)
            elseif k:find("spell_amp") or k:find("spell_lifesteal") then
                score = score + (pos == 2 and 34 or (pos >= 4 and 22 or 8))
            elseif k:find("attack_speed") or k:find("bonus_damage") or k:find("crit") or k:find("agility") then
                score = score + (pos == 1 and 36 or (pos == 2 and 24 or (pos == 3 and 14 or 4)))
            elseif k:find("lifesteal") then
                score = score + (pos == 1 and 32 or (pos == 3 and 16 or 4))
            elseif k:find("armor") or k:find("magic_resist") or k:find("status_resist") or k:find("damage_block") then
                score = score + (pos == 3 and 36 or (pos <= 2 and 20 or 16))
            elseif k:find("health") or k:find("strength") or k:find("hp_regen") then
                score = score + (pos == 3 and 32 or (pos >= 4 and 22 or 18))
            elseif k:find("movement_speed") or k:find("movespeed") then
                score = score + 18
            elseif k:find("gold") or k:find("xp") or k:find("gpm") then
                score = score + (pos >= 4 and 42 or 14)
            elseif k:find("all_stats") or k:find("primary") then
                score = score + 22 + math.min(12, val)
            end
        end
        return score
    end

    function INV.decideNeutralChoice(snapshot, actor, threats)
        local n = actor.neutral
        if not n or not n.readyTier or not n.options then return nil end

        local opts = n.options
        local bestArt, bestArtScore = nil, -9999
        for _, a in ipairs(opts.artifacts or {}) do
            local s = INV.scoreNeutralStats(actor, a.stats, a.active)
            -- Небольшой штраф за сохранение старого тира, чтобы герои чаще апались на новый тир
            if a.keepCurrent then s = s - 12 end
            if s > bestArtScore then bestArt, bestArtScore = a.name, s end
        end

        local bestEnh, bestEnhScore = nil, -9999
        for _, e in ipairs(opts.enchantments or {}) do
            local s = INV.scoreNeutralStats(actor, e.stats, false) + (e.level or 1) * 5
            if s > bestEnhScore then bestEnh, bestEnhScore = e.name, s end
        end

        local defaultChoice = {
            artifact = bestArt,
            enchantment = bestEnh,
        }
        local function applyChoice(custom)
            if type(custom) ~= "table" then return end
            for _, option in ipairs(opts.artifacts or {}) do
                if option.name == custom.artifact then defaultChoice.artifact = option.name; break end
            end
            for _, option in ipairs(opts.enchantments or {}) do
                if option.name == custom.enchantment then defaultChoice.enchantment = option.name; break end
            end
        end
        applyChoice(safeHook(tactic.ChooseNeutral, actor, opts, shallowCopy(defaultChoice), snapshot))
        applyChoice(heroHook(actor, "ChooseNeutral", actor, opts, shallowCopy(defaultChoice), snapshot))

        if defaultChoice.artifact or defaultChoice.enchantment then
            return {
                kind = "choose_neutral",
                artifact = defaultChoice.artifact,
                enchantment = defaultChoice.enchantment,
                status = "Выбираю нейтралку T" .. tostring(n.readyTier),
            }
        end
        return nil
    end

    -- ========================================================================
    -- COMBAT: Башни, отагр, командный фокус, активные предметы и скиллы
    -- ========================================================================
    local COMBAT = {}

    function COMBAT.profileCast(actor, byName, intent, field)
        if intent == false then return false end
        if type(intent) ~= "table" or (intent.kind ~= "cast" and intent.kind ~= "toggle")
            or type(intent[field]) ~= "string" or actor.stunned or actor.hexed
            or (intent.position ~= nil and (intent.target_id ~= nil or not mapPosition(intent.position)))
            or (intent.target_id ~= nil and not finite(intent.target_id)) then
            return nil
        end
        if field == "item" then
            if intent.ability ~= nil then return nil end
            local slot = U.hasItem(actor, intent.item, true)
            if slot and U.itemCd(actor, slot) <= 0 then return intent end
        else
            if intent.item ~= nil then return nil end
            local ab = byName[intent.ability]
            if U.canCast(actor, ab)
                or (intent.kind == "toggle" and ab and ab.toggle and not ab.hidden and not actor.silenced) then
                return intent
            end
        end
    end
    local TOWER_DANGER_RADIUS = 830
    local TOWER_SAFE_EXIT_RADIUS = TOWER_DANGER_RADIUS + 130

    function COMBAT.enemyTowersNear(snapshot, origin, maxDist)
        local towers, seen = {}, {}
        for _, u in ipairs(snapshot.enemies or {}) do
            if u.kind == "tower" and u.alive ~= false and U.dist(origin, u.pos) <= maxDist then
                towers[#towers + 1] = u
                if u.lane and u.tier then seen[tostring(u.lane) .. tostring(u.tier)] = true end
            end
        end
        for _, pin in ipairs(snapshot.pins or {}) do
            if pin.kind == "tower" and pin.mapTeam == snapshot.enemyTeam then
                local key = tostring(pin.lane) .. tostring(pin.tier)
                if not MEM.clearedTowers[key] and not seen[key] and U.dist(origin, pin.pos) <= maxDist then
                    towers[#towers + 1] = {
                        pos = pin.pos, tier = pin.tier, lane = pin.lane,
                        invulnerable = true, attackDamage = 110, secondsPerAttack = 1.0,
                    }
                end
            end
        end
        return towers
    end

    function COMBAT.nearestEnemyTower(snapshot, origin, maxDist)
        local best, bestD = nil, maxDist or math.huge
        for _, t in ipairs(COMBAT.enemyTowersNear(snapshot, origin, bestD)) do
            local d = U.dist(origin, t.pos)
            if d < bestD then best, bestD = t, d end
        end
        return best, bestD
    end

    function COMBAT.allyCreepsAtTower(snapshot, towerPos)
        local count, closest, closestD = 0, nil, math.huge
        for _, u in ipairs(snapshot.allies or {}) do
            if U.isLaneCreep(u) and u.alive ~= false and (u.hp or 0) > 75 then
                local d = U.dist(u.pos, towerPos)
                if d <= 780 then
                    count = count + 1
                    if d < closestD then closest, closestD = u, d end
                end
            end
        end
        return count, closest, closestD
    end

    function COMBAT.isSafeFromTower(snapshot, actor, targetPos, allowDive)
        local tower = COMBAT.nearestEnemyTower(snapshot, targetPos, TOWER_DANGER_RADIUS)
        if not tower then return true, nil end
        if allowDive then return true, tower end
        local creeps, _, creepDist = COMBAT.allyCreepsAtTower(snapshot, tower.pos)
        if creeps >= 1 and creepDist < U.dist(targetPos, tower.pos) + 40 then
            return true, tower
        end
        return false, tower
    end

    function COMBAT.siegeRally(snapshot, actor, towerPos, lane, tier, basePos)
        local previousTower = tier and tier > 1 and U.findPin(snapshot, "tower", function(pin)
            return pin.mapTeam == snapshot.enemyTeam and pin.lane == lane and pin.tier == tier - 1
        end)
        local approach = previousTower and previousTower.pos or DATA.LANES[lane] or basePos
        local staging = U.towards(towerPos, approach, TOWER_SAFE_EXIT_RADIUS)
        local wave = U.nearest(snapshot.allies, staging, 850, function(u)
            return U.isLaneCreep(u) and U.dist(u.pos, actor.pos) <= 1350
                and U.dist(u.pos, staging) < U.dist(u.pos, towerPos)
        end)
        if wave then
            local follow = U.away(wave.pos, towerPos, actor.ranged and 280 or 180)
            if not COMBAT.nearestEnemyTower(snapshot, follow, TOWER_DANGER_RADIUS) then
                return follow
            end
        end
        if U.dist(staging, towerPos) >= TOWER_DANGER_RADIUS
            and not COMBAT.nearestEnemyTower(snapshot, staging, TOWER_DANGER_RADIUS) then
            return staging
        end
        return nil
    end

    function COMBAT.isSafeCreepAttack(snapshot, actor, creep)
        if creep.invulnerable or creep.attackImmune then return false end
        local range = math.max(0, (actor.attackRange or 200) - 45)
        local attackPos = U.towards(creep.pos, actor.pos, range)
        return COMBAT.isSafeFromTower(snapshot, actor, attackPos, false)
    end

    function COMBAT.canFightUnderTower(snapshot, actor, enemy, tower, allies, enemies, hp)
        if not tower then return true end
        if allies == 0 or allies + 1 < enemies or hp < 0.40 then return false end
        if tower.aggroTargetId == actor.id then return false end
        if COMBAT.allyCreepsAtTower(snapshot, tower.pos) > 0 then return true end
        return allies >= 2 and hp >= 0.56
            and U.countNear(snapshot.heroes, tower.pos, 900, function(h)
                return h.alive and h.id ~= actor.id and U.ratio(h.hp, h.maxHp) >= 0.45
                    and U.dist(h.pos, enemy.pos) <= 900
            end) >= 1
    end

    -- Оценка: может ли герой безопасно танковать вышку и доламывать её вместо отхода
    function COMBAT.canTankTower(snapshot, actor, tower, st, enemyCount, allyCount, macro, towersInRange)
        if not tower or actor.disarmed or (st and st.retreat) then return false end
        if st and st.tankCooldownUntil and snapshot.time < st.tankCooldownUntil then return false end

        local target = (macro and macro.phase == "PUSH" and macro.targetBuilding
            and U.dist(actor.pos, macro.targetBuilding.pos) <= 1250) and macro.targetBuilding or tower
        if not target or target.invulnerable or target.attackImmune
            or target.fortified or target.backdoorProtected then
            return false
        end

        enemyCount = enemyCount or 0
        allyCount = allyCount or 0
        local safeEnemies = (enemyCount == 0)
            or (allyCount + 1 >= enemyCount and (actor.position <= 3 or actor.bkbActive or actor.satanicActive))
        if not safeEnemies then return false end

        local hp = U.ratio(actor.hp, actor.maxHp)
        local towerDmg = (tower.attackDamage or 110) * U.armorMult(actor.armor)
        local hitsLeft = (actor.hp or 0) / math.max(1, towerDmg)
        local lowBuilding = (target.hp or 9999) <= 480 or U.ratio(target.hp, target.maxHp) <= 0.22
        local already = st and st.tankingTower == true

        local minHp = already and 0.34 or 0.46
        local minHits = already and 5 or 7
        if (towersInRange or 1) >= 2 then
            minHp = already and 0.40 or 0.52
            minHits = already and 8 or 11
        end
        if lowBuilding then
            minHp = already and 0.28 or 0.36
            minHits = already and 4 or 5
        end
        if actor.hasAegis then
            minHp, minHits = 0.22, 3
        end
        if hp < minHp or hitsLeft < minHits then return false end

        local creeps = COMBAT.allyCreepsAtTower(snapshot, tower.pos)
        local isPushing = macro and macro.phase == "PUSH" and macro.pos
            and U.dist(actor.pos, macro.pos) <= 1350
        return lowBuilding
            or creeps >= 1
            or (isPushing and ((actor.level or 1) >= 11 or allyCount >= 2
                or actor.bkbActive or actor.satanicActive or actor.hasAegis))
    end

    -- Поиск лучшего вектора выхода сразу из-под ВСЕХ ближайших вышек (решает застревание между T4 / T1-T2)
    function COMBAT.safeExitFromTowers(snapshot, actor, desiredPos)
        local allTowers = COMBAT.enemyTowersNear(snapshot, actor.pos, 2200)
        if #allTowers == 0 then return desiredPos end

        local step = 580
        local bestPos, bestScore = nil, -math.huge
        for i = 0, 15 do
            local ang = i * (math.pi / 8)
            local px = actor.pos.x + math.cos(ang) * step
            local py = actor.pos.y + math.sin(ang) * step
            local cand = { x = px, y = py, z = actor.pos.z or 0 }
            local mid = { x = (actor.pos.x + px) * 0.5, y = (actor.pos.y + py) * 0.5, z = actor.pos.z or 0 }

            local minDist, progressSum, midPenalty = math.huge, 0, 0
            for _, t in ipairs(allTowers) do
                local dNow = U.dist(actor.pos, t.pos)
                local dNew = U.dist(cand, t.pos)
                local dMid = U.dist(mid, t.pos)
                if dNew < minDist then minDist = dNew end
                if dNow <= TOWER_SAFE_EXIT_RADIUS then
                    progressSum = progressSum + (dNew - dNow)
                end
                if dMid < dNow - 20 and dMid < TOWER_DANGER_RADIUS then
                    midPenalty = midPenalty + 220
                end
            end

            local score = progressSum * 1.6 + math.min(minDist, TOWER_SAFE_EXIT_RADIUS + 200) * 2.2 - midPenalty
            if minDist >= TOWER_SAFE_EXIT_RADIUS then score = score + 1800 end
            if desiredPos then score = score - U.dist(cand, desiredPos) * 0.22 end
            score = score - U.countNear(snapshot.enemies, cand, 700, U.isRealHero) * 260
            if math.abs(px) > 7800 or math.abs(py) > 7800 then score = score - 1500 end

            if score > bestScore then bestPos, bestScore = cand, score end
        end
        return bestPos or desiredPos
    end

    -- Касательный обход вражеской вышки, если прямой маршрут до targetPos режет её радиус
    function COMBAT.detourAroundTowers(snapshot, actor, targetPos, st)
        if not targetPos then return nil end
        local dx = (targetPos.x or 0) - (actor.pos.x or 0)
        local dy = (targetPos.y or 0) - (actor.pos.y or 0)
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 180 then return nil end

        local ux, uy = dx / len, dy / len
        local allTowers = COMBAT.enemyTowersNear(snapshot, actor.pos, math.min(len + 900, 2800))
        local blocker, blockerProj = nil, math.huge

        for _, t in ipairs(allTowers) do
            local dHero = U.dist(actor.pos, t.pos)
            local dGoal = U.dist(targetPos, t.pos)
            if dHero > TOWER_DANGER_RADIUS and dGoal > 450
                and COMBAT.allyCreepsAtTower(snapshot, t.pos) == 0 then
                local proj = ((t.pos.x - actor.pos.x) * ux + (t.pos.y - actor.pos.y) * uy)
                if proj > 40 and proj < len - 40 then
                    local cx = actor.pos.x + ux * proj
                    local cy = actor.pos.y + uy * proj
                    local segDist = U.dist(t.pos, { x = cx, y = cy })
                    if segDist < TOWER_DANGER_RADIUS + 40 and proj < blockerProj then
                        blocker, blockerProj = t, proj
                    end
                end
            end
        end
        if not blocker then return nil end

        local bypassR = TOWER_SAFE_EXIT_RADIUS + 40
        local bestPt, bestSide, bestScore = nil, 1, -math.huge
        local prevSide = st and st.towerDetourUntil and snapshot.time < st.towerDetourUntil and st.towerDetourSide
        for _, side in ipairs({ 1, -1 }) do
            local px = blocker.pos.x + (-uy * side) * bypassR
            local py = blocker.pos.y + (ux * side) * bypassR
            local pt = { x = px, y = py, z = actor.pos.z or 0 }
            local minOther = math.huge
            for _, t in ipairs(allTowers) do
                if t ~= blocker then
                    local d = U.dist(pt, t.pos)
                    if d < minOther then minOther = d end
                end
            end
            local score = -U.dist(actor.pos, pt) - U.dist(pt, targetPos) * 0.5
            if minOther < TOWER_DANGER_RADIUS then score = score - 2500 end
            score = score - U.countNear(snapshot.enemies, pt, 750, U.isRealHero) * 350
            if math.abs(px) > 7800 or math.abs(py) > 7800 then score = score - 3000 end
            if prevSide == side then score = score + 240 end
            if score > bestScore then bestPt, bestSide, bestScore = pt, side, score end
        end

        if st then
            st.towerDetourSide = bestSide
            st.towerDetourUntil = snapshot.time + 2.0
        end
        return bestPt
    end

    function COMBAT.siegeHasWave(snapshot, macro)
        if macro.targetBuilding and macro.targetBuilding.kind == "tower" then
            if COMBAT.allyCreepsAtTower(snapshot, macro.targetBuilding.pos) > 0 then
                return true
            end
            return (macro.tier or 0) >= 4 and macro.ancientPos
                and U.countNear(snapshot.allies, macro.ancientPos, 1300, function(u)
                    return U.isLaneCreep(u) and (u.hp or 0) > 75
                end) > 0
        end
        local creeps = macro.laneCreeps or snapshot.allies
        if U.countNear(creeps, macro.pos, 780, function(u)
            return U.isLaneCreep(u) and (u.hp or 0) > 75
        end) > 0 then return true end
        return (macro.tier or 0) >= 4 and macro.ancientPos
            and U.countNear(snapshot.allies, macro.ancientPos, 1300, function(u)
                return U.isLaneCreep(u) and (u.hp or 0) > 75
            end) > 0
    end

    function COMBAT.siegeReady(snapshot, macro)
        if macro.phase ~= "PUSH" or not macro.pos or not macro.targetId then return false end
        local target = macro.targetBuilding or U.nearest(snapshot.enemies, macro.pos, 750, function(u)
            return u.id == macro.targetId and U.isBuilding(u)
        end)
        return target and target.alive ~= false and not target.invulnerable and not target.attackImmune
            and not target.fortified and not target.backdoorProtected and COMBAT.siegeHasWave(snapshot, macro)
    end

    function COMBAT.checkTowerSafety(snapshot, actor, basePos, st, stayInFight, enemyCount, allyCount, macro)
        local now = snapshot.time
        local nearbyTowers = COMBAT.enemyTowersNear(snapshot, actor.pos, TOWER_SAFE_EXIT_RADIUS)
        if #nearbyTowers == 0 then
            st.towerBackUntil = nil
            st.tankingTower = false
            return nil
        end

        local hpDrop = (st.lastHp or actor.hp) - actor.hp
        local tower, td, hittingTower = nil, math.huge, nil
        local inDangerCount = 0
        for _, t in ipairs(nearbyTowers) do
            local d = U.dist(actor.pos, t.pos)
            if d <= TOWER_DANGER_RADIUS then inDangerCount = inDangerCount + 1 end
            if d < td then tower, td = t, d end
            if (t.aggroTargetId ~= nil and t.aggroTargetId == actor.id)
                or (t.aggroTargetId == nil and d <= 770 and hpDrop >= 35) then
                hittingTower = t
            end
        end
        if hittingTower then
            tower = hittingTower
            td = U.dist(actor.pos, tower.pos)
        end

        local function exitPos()
            local rally = COMBAT.siegeRally(snapshot, actor, tower.pos, tower.lane, tower.tier, basePos)
            return COMBAT.safeExitFromTowers(snapshot, actor, rally or basePos)
        end

        -- Гистерезис: доводим отход до безопасной границы 960, не сбрасывая таймер на 831
        if st.towerBackUntil and now < st.towerBackUntil then
            if td >= TOWER_SAFE_EXIT_RADIUS and not hittingTower then
                st.towerBackUntil = nil
                return nil
            end
            return { kind = "move", position = exitPos(), status = "Выхожу из-под вышки" }
        end

        if not hittingTower and td > TOWER_DANGER_RADIUS then
            st.tankingTower = false
            return nil
        end

        local creeps, allyCreep, creepDist = COMBAT.allyCreepsAtTower(snapshot, tower.pos)
        local canTank = COMBAT.canTankTower(snapshot, actor, tower, st, enemyCount, allyCount, macro, inDangerCount)

        if stayInFight and not hittingTower then
            st.towerBackUntil = nil
            return nil
        end

        if creeps == 0 then
            if canTank then
                st.tankingTower = true
                st.towerBackUntil = nil
                return nil
            end
            if st.tankingTower then st.tankCooldownUntil = now + 5.0 end
            st.tankingTower = false
            st.towerBackUntil = now + 1.6
            return { kind = "move", position = exitPos(), status = "Выход из радиуса вышки" }
        end

        if hittingTower then
            if st.tankingTower then
                if canTank then return nil end
                st.tankingTower = false
                st.tankCooldownUntil = now + 5.0
                st.towerBackUntil = now + 1.8
                return { kind = "move", position = exitPos(), status = "Хватит танковать — отход" }
            end

            local triedRecently = st.lastDeaggroAt and (now - st.lastDeaggroAt) < 1.2
            if not triedRecently and allyCreep and creeps >= 1 then
                st.lastDeaggroAt = now
                st.deaggroHp = actor.hp
                return { kind = "deaggro", target_id = allyCreep.id, status = "Отагриваю вышку" }
            elseif (triedRecently and (now - st.lastDeaggroAt) >= 0.25
                and ((tower.aggroTargetId == actor.id) or actor.hp < (st.deaggroHp or 99999) - 30))
                or td < creepDist - 50 then
                if canTank then
                    st.tankingTower = true
                    st.towerBackUntil = nil
                    return nil
                end
                st.towerBackUntil = now + 1.8
                return { kind = "move", position = exitPos(), status = "Сбрасываю агр отходом" }
            end
        else
            st.tankingTower = false
        end

        return nil
    end

    function COMBAT.checkLaneCreepAggro(snapshot, actor, basePos)
        local function attackingMe(u)
            return U.isLaneCreep(u) and u.aggroTargetId == actor.id
        end
        local creep = U.nearest(snapshot.enemies, actor.pos, 650, attackingMe)
        if not creep or (U.ratio(actor.hp, actor.maxHp) > 0.45
            and U.countNear(snapshot.enemies, actor.pos, 650, attackingMe) < 2) then return nil end

        local tower = U.nearest(snapshot.allies, actor.pos, 3000, function(u)
            return u.kind == "tower" and u.lane == actor.lane
        end)
        local shelter = tower and tower.pos or basePos
        local creepDist = U.dist(actor.pos, creep.pos)
        local ally = U.nearest(snapshot.allies, actor.pos, 850, U.isLaneCreep)
        local back = ally and U.towards(ally.pos, shelter, actor.ranged and 340 or 260)
        if not back or U.dist(back, creep.pos) < creepDist + 160
            or not COMBAT.isSafeFromTower(snapshot, actor, back, false) then
            back = U.towards(actor.pos, shelter, 560)
            if U.dist(back, creep.pos) < creepDist + 100
                or not COMBAT.isSafeFromTower(snapshot, actor, back, false) then
                back = U.away(actor.pos, creep.pos, 520)
            end
        end
        return { kind = "move", position = back, status = "Отхожу от крипов" }
    end

    -- Сколько маны герой может мгновенно долить кнопками (Wand/Mango/Lotus/Arcanes)
    function COMBAT.instantManaReserve(actor)
        local extra = 0
        local wSlot = U.hasItem(actor, "item_magic_wand", true) or U.hasItem(actor, "item_magic_stick", true)
        if wSlot and U.itemCd(actor, wSlot) <= 0 then
            extra = extra + U.itemCharges(actor, wSlot) * 15
        end
        local mSlot = U.hasItem(actor, "item_enchanted_mango", true)
        if mSlot and U.itemCd(actor, mSlot) <= 0 then extra = extra + 100 end
        local aSlot = U.hasItem(actor, "item_arcane_boots", true) or U.hasItem(actor, "item_guardian_greaves", true)
        if aSlot and U.itemCd(actor, aSlot) <= 0 then extra = extra + 175 end
        for _, lName in ipairs({ "item_greater_famango", "item_great_famango", "item_famango" }) do
            local lSlot = U.hasItem(actor, lName, true)
            if lSlot and U.itemCd(actor, lSlot) <= 0 then
                extra = extra + (lName == "item_famango" and 125 or (lName == "item_great_famango" and 400 or 900))
                break
            end
        end
        return extra
    end

    -- Анализ маны вражеского героя (может ли он кастовать / сбежать / танковать щитом)
    function COMBAT.analyzeEnemyMana(enemy)
        if not enemy then
            return { mana = 0, maxMana = 1, ratio = 1, isOom = false, lowMana = false, noEscapeMana = false, isMedusaLow = false }
        end
        local m = enemy.mana or 0
        local maxM = math.max(1, enemy.maxMana or 1)
        local r = m / maxM
        local isOom = maxM >= 150 and (m < 85 or r < 0.14)
        local lowMana = maxM >= 150 and (m < 155 or r < 0.25)
        local noEscapeMana = (DATA.ELUSIVE_HEROES[enemy.name] or enemy.name == "npc_dota_hero_faceless_void"
            or enemy.name == "npc_dota_hero_mirana" or enemy.name == "npc_dota_hero_morphling")
            and maxM >= 150 and m < 95
        local isMedusaLow = (enemy.name == "npc_dota_hero_medusa") and r < 0.30
        return {
            mana = m,
            maxMana = maxM,
            ratio = r,
            isOom = isOom,
            lowMana = lowMana,
            noEscapeMana = noEscapeMana,
            isMedusaLow = isMedusaLow,
        }
    end

    -- Обновлённая готовность героя: КД + реальная мана + реген маны + долив кнопками
    function COMBAT.heroCombatReadiness(hero)
        local spellsReady, spellsSoon, spellsTotal = 0, 0, 0
        local hasActiveUlt, ultReady, ultSoon, ultCd, ultManaCost = false, false, false, 0, 0
        local ultNeedsManaOnly = false
        local minSpellMana, comboManaCost = math.huge, 0
        local soonestReadyIn = math.huge

        local curMana = hero.mana or 0
        local maxMana = math.max(1, hero.maxMana or 1)
        local manaRatio = curMana / maxMana
        local regen = math.max(0.5, hero.manaRegen or 1.5)
        local burstMana = COMBAT.instantManaReserve(hero)
        local effectiveMana = curMana + burstMana

        local cfg = DATA.SKILLS[hero.name]
        local ultName = cfg and cfg.list and cfg.list[4] and cfg.list[4][1] or nil

        for _, ab in pairs(hero.abilities or {}) do
            if ab and ab.name and not ab.hidden and not ab.passive
                and (ab.level or 0) > 0
                and not ab.name:find("^special_bonus_")
                and not hasBit(ab.behavior, B_PASSIVE)
                and not hasBit(ab.behavior, B_AUTOCAST) then

                local isUlt = ab.isUltimate or (ab.name == ultName) or (ab.maxLevel == 3)
                local cd = ab.cooldown or 0
                local mCost = ab.manaCost or 0
                if mCost > 0 and mCost < minSpellMana then minSpellMana = mCost end

                local manaMissing = math.max(0, mCost - effectiveMana)
                local manaWaitSec = manaMissing > 0 and (manaMissing / regen) or 0
                local timeUntilReady = math.max(cd, manaWaitSec)

                local ready = (cd <= 1.2) and (effectiveMana >= mCost)
                local soonLimit = isUlt and 4.5 or 3.2
                local soon = (not ready) and (timeUntilReady <= soonLimit)

                if (cd <= 6.0) then
                    comboManaCost = comboManaCost + mCost
                end
                if soon and timeUntilReady < soonestReadyIn then
                    soonestReadyIn = timeUntilReady
                end

                if isUlt then
                    hasActiveUlt = true
                    ultManaCost = math.max(ultManaCost, mCost)
                    if ready then
                        ultReady, ultSoon, ultCd = true, false, 0
                    elseif soon and not ultReady then
                        ultSoon = true
                        ultCd = (ultCd == 0) and timeUntilReady or math.min(ultCd, timeUntilReady)
                        if cd <= 1.2 and curMana < mCost then ultNeedsManaOnly = true end
                    elseif not ultReady and not ultSoon then
                        ultCd = math.max(ultCd, timeUntilReady)
                        if cd <= 1.2 and curMana < mCost then ultNeedsManaOnly = true end
                    end
                else
                    spellsTotal = spellsTotal + 1
                    if ready then
                        spellsReady = spellsReady + 1
                    elseif soon then
                        spellsSoon = spellsSoon + 1
                    end
                end
            end
        end

        minSpellMana = (minSpellMana < math.huge) and minSpellMana or 0
        local isOom = (minSpellMana > 0) and (effectiveMana < minSpellMana)
        local lowMana = (comboManaCost > 0) and (effectiveMana < comboManaCost * 0.60) and (manaRatio < 0.32)

        return {
            spellsReady = spellsReady,
            spellsSoon = spellsSoon,
            spellsTotal = spellsTotal,
            hasActiveUlt = hasActiveUlt,
            ultReady = ultReady,
            ultSoon = ultSoon,
            ultCd = ultCd,
            ultManaCost = ultManaCost,
            ultNeedsManaOnly = ultNeedsManaOnly,
            minSpellMana = minSpellMana,
            comboManaCost = comboManaCost,
            manaRatio = manaRatio,
            burstMana = burstMana,
            isOom = isOom,
            lowMana = lowMana,
            soonestReadyIn = (soonestReadyIn < math.huge) and soonestReadyIn or 0,
            noSpells = (spellsTotal >= 1 and spellsReady == 0 and not ultReady),
            spellsAlmostReady = (spellsSoon > 0 or ultSoon),
        }
    end

    -- Обновлённая готовность команды: КД + суммарная мана команды + число сухих союзников
    function COMBAT.teamFightReadiness(snapshot, origin, radius)
        local readyUlts, soonUlts, downUlts, totalActiveUlts = 0, 0, 0, 0
        local totalSpellsReady, totalSpellsSoon, totalSpells = 0, 0, 0
        local minUltCd, soonestIn = math.huge, math.huge
        local manaSum, manaCnt, oomCount = 0, 0, 0
        local hasTeamArcanes = false

        for _, h in ipairs(snapshot.heroes or {}) do
            if h.alive and U.ratio(h.hp, h.maxHp) >= 0.35
                and (not origin or not radius or U.dist(h.pos, origin) <= radius) then
                local r = COMBAT.heroCombatReadiness(h)
                totalSpellsReady = totalSpellsReady + r.spellsReady
                totalSpellsSoon = totalSpellsSoon + r.spellsSoon
                totalSpells = totalSpells + r.spellsTotal
                manaSum = manaSum + r.manaRatio
                manaCnt = manaCnt + 1
                if r.isOom then oomCount = oomCount + 1 end

                local aSlot = U.hasItem(h, "item_arcane_boots", true) or U.hasItem(h, "item_guardian_greaves", true)
                if aSlot and U.itemCd(h, aSlot) <= 0 then hasTeamArcanes = true end

                if r.soonestReadyIn > 0 and r.soonestReadyIn < soonestIn then
                    soonestIn = r.soonestReadyIn
                end
                if r.hasActiveUlt then
                    totalActiveUlts = totalActiveUlts + 1
                    if r.ultReady then
                        readyUlts = readyUlts + 1
                    elseif r.ultSoon then
                        soonUlts = soonUlts + 1
                        if r.ultCd > 0 and r.ultCd < minUltCd then minUltCd = r.ultCd end
                    else
                        downUlts = downUlts + 1
                        if r.ultCd > 0 and r.ultCd < minUltCd then minUltCd = r.ultCd end
                    end
                end
            end
        end

        local spellRatio = totalSpells > 0 and (totalSpellsReady / totalSpells) or 1.0
        local teamManaRatio = manaCnt > 0 and (manaSum / manaCnt) or 1.0
        local teamOom = (manaCnt >= 2) and (not hasTeamArcanes)
            and ((teamManaRatio < 0.24) or (oomCount >= math.ceil(manaCnt * 0.5)))
        local ultsMissing = (totalActiveUlts >= 2 and readyUlts == 0)
        local almostReady = (soonUlts >= 1) or (readyUlts == 0 and minUltCd <= 4.5) or (totalSpellsSoon >= 2)

        return {
            readyUlts = readyUlts,
            soonUlts = soonUlts,
            downUlts = downUlts,
            totalActiveUlts = totalActiveUlts,
            spellRatio = spellRatio,
            teamManaRatio = teamManaRatio,
            oomCount = oomCount,
            teamOom = teamOom,
            minUltCd = (minUltCd < math.huge) and minUltCd or 0,
            soonestIn = (soonestIn < math.huge) and soonestIn or 0,
            ultsMissing = ultsMissing,
            almostReady = almostReady,
            shouldAvoidBigFight = STYLE.respectCooldowns ~= false
                and (ultsMissing or teamOom or (totalSpells >= 4 and spellRatio < 0.25)),
        }
    end

    function COMBAT.visibleHero(snapshot, id)
        for _, enemy in ipairs(snapshot.enemies or {}) do
            if enemy.id == id and U.isRealHero(enemy) and enemy.alive ~= false and not enemy.invulnerable then
                return enemy
            end
        end
    end

    function COMBAT.pickTeamFocus(snapshot)
        local best, bestScore = nil, -999
        for _, e in ipairs(snapshot.enemies or {}) do
            if U.isRealHero(e) and e.alive ~= false and not e.invulnerable then
                local alliesNear = U.countNear(snapshot.heroes, e.pos, 1100, function(h) return h.alive end)
                if alliesNear >= 1 then
                    local hpR = U.ratio(e.hp, e.maxHp)
                    local score = (1 - hpR) * 110 + alliesNear * 24
                    if e.channeling then score = score + 110 end
                    if e.stunned or e.hexed or e.rooted then score = score + 25 end
                    if (e.maxHp or 1500) < 1300 then score = score + 25 end
                    if e.magicImmune then score = score - 15 end
                    if e.hasBladeMail and hpR > 0.18 then score = score - 80 end
                    local em = COMBAT.analyzeEnemyMana(e)
                    if em.noEscapeMana then score = score + 45 end
                    if em.isMedusaLow then score = score + 65 end
                    if em.isOom then score = score + 18 end
                    if score > bestScore then best, bestScore = e, score end
                end
            end
        end
        local custom = safeHook(tactic.PickFocus, snapshot, best)
        if type(custom) == "table" and custom.id then return COMBAT.visibleHero(snapshot, custom.id) or best end
        return best
    end

    function COMBAT.pickEnemyForActor(snapshot, actor, teamFocus)
        if teamFocus and U.dist(actor.pos, teamFocus.pos) <= (actor.attackRange or 200) + 250
            and not (teamFocus.hasBladeMail and not actor.magicImmune and U.ratio(teamFocus.hp, teamFocus.maxHp) > 0.18) then
            return teamFocus
        end
        local best, bestScore = nil, -999
        for _, e in ipairs(snapshot.enemies or {}) do
            if U.isRealHero(e) and e.alive ~= false and not e.invulnerable then
                local d = U.dist(actor.pos, e.pos)
                if d <= 1350 then
                    local hpR = U.ratio(e.hp, e.maxHp)
                    local score = (1 - hpR) * 100 - d * 0.06
                    if d <= (actor.attackRange or 200) + 70 and not e.attackImmune then score = score + 70 end
                    if teamFocus and e.id == teamFocus.id then score = score + 30 end
                    if e.channeling then score = score + 90 end
                    if e.hasBladeMail and not actor.magicImmune and hpR > 0.18 then score = score - 95 end
                    if e.ethereal then score = score - 40 end
                    local em = COMBAT.analyzeEnemyMana(e)
                    if em.noEscapeMana then score = score + 40 end
                    if em.isMedusaLow then score = score + 60 end
                    if em.isOom then score = score + 15 end
                    if score > bestScore then best, bestScore = e, score end
                end
            end
        end
        return best
    end

    function COMBAT.canRightClick(enemy)
        return U.isRealHero(enemy) and enemy.alive ~= false and not enemy.invulnerable and not enemy.attackImmune
    end

    local ICE_BLAST = "ancient_apparition_ice_blast"
    local ICE_RELEASE = "ancient_apparition_ice_blast_release"
    local ICE_TRACER_SPEED = 1500

    function COMBAT.iceBlastAim(enemy, seconds)
        if not enemy.moving or not enemy.forward or enemy.rooted or enemy.stunned
            or enemy.hexed or enemy.channeling then return enemy.pos end
        local lead = math.min(seconds, 2) * (enemy.moveSpeed or 300)
        return {
            x = enemy.pos.x + enemy.forward.x * lead,
            y = enemy.pos.y + enemy.forward.y * lead,
            z = enemy.pos.z,
        }
    end

    function COMBAT.startIceBlast(snapshot, actor, skills, st)
        if actor.name ~= "npc_dota_hero_ancient_apparition" or actor.smoked
            or st.iceBlast or not U.canCast(actor, skills[ICE_BLAST]) then return nil end
        local profile = PROFILES[actor.name]
        local manual = profile and profile.manualAbilities
        if manual and (manual[ICE_BLAST] or manual[ICE_RELEASE]) then return nil end

        local best, bestScore
        for _, enemy in ipairs(snapshot.enemies or {}) do
            if U.isRealHero(enemy) and enemy.alive ~= false and not enemy.invulnerable then
                local distance = U.dist(actor.pos, enemy.pos)
                local radius = math.min(1000, 300 + distance / 30)
                local nearby = U.countNear(snapshot.enemies, enemy.pos, radius, U.isRealHero)
                local allies = U.countNear(snapshot.heroes, enemy.pos, 1000)
                local hp = U.ratio(enemy.hp, enemy.maxHp)
                if nearby >= 2 or (allies > 0 and hp < 0.78) or hp < 0.22 then
                    local score = nearby * 35 + allies * 12 + (1 - hp) * 40 - distance / 300
                    if not bestScore or score > bestScore then best, bestScore = enemy, score end
                end
            end
        end
        if not best then return nil end

        local distance = U.dist(actor.pos, best.pos)
        local aim = COMBAT.iceBlastAim(best, distance / ICE_TRACER_SPEED + math.min(1.75, distance / 750))
        local length = U.dist(actor.pos, aim)
        if length < 1 then return nil end
        st.iceBlast = {
            targetId = best.id, origin = actor.pos, distance = length, orderedAt = snapshot.time,
            dx = (aim.x - actor.pos.x) / length, dy = (aim.y - actor.pos.y) / length,
        }
        return { kind = "cast", ability = ICE_BLAST, position = aim, status = "Направляю метку Ice Blast" }
    end

    function COMBAT.releaseIceBlast(snapshot, actor, skills, st)
        local shot = st.iceBlast
        if not shot then return nil end
        local release = skills[ICE_RELEASE]
        local now = snapshot.time
        if not actor.alive or not release or release.hidden then
            if not actor.alive or shot.startedAt or now - shot.orderedAt > 1.2 then st.iceBlast = nil end
            return nil
        end
        shot.startedAt = shot.startedAt or math.max(shot.orderedAt, now - 0.075)
        local destination = shot.distance
        local enemy = COMBAT.visibleHero(snapshot, shot.targetId)
        if enemy then
            local aim = COMBAT.iceBlastAim(enemy, math.min(1.75, shot.distance / 750))
            local x, y = aim.x - shot.origin.x, aim.y - shot.origin.y
            local along = x * shot.dx + y * shot.dy
            local across = math.abs(x * shot.dy - y * shot.dx)
            if along > 0 and across <= math.min(1000, 300 + along / 30) then
                destination = math.min(shot.distance + 750, along)
            end
        end
        if release.fullyCastable and (release.cooldown or 0) <= 0 and not actor.stunned and not actor.hexed
            and now - shot.startedAt + 0.075 >= destination / ICE_TRACER_SPEED then
            return { kind = "cast", ability = ICE_RELEASE, status = "Выпускаю снаряд Ice Blast" }
        end
    end

    function COMBAT.readyItem(actor, name)
        local profile = PROFILES[actor.name]
        local manual = profile and profile.manualItems
        local slot = not (manual and manual[name]) and U.hasItem(actor, name, true)
        return slot and not actor.muted and not actor.stunned and not actor.hexed
            and U.itemCd(actor, slot) <= 0
    end

    function COMBAT.defensiveFight(actor, enemy, hp, now, st)
        local attempt = st.defensiveItem
        if attempt then
            local slot = U.hasItem(actor, attempt.name, true)
            if slot and U.itemCd(actor, slot) > 1 then
                st.lastStand, st.defensiveItem = true, nil
            elseif now - attempt.at > 0.6 then
                st.defensiveItem = nil
            end
        end
        if not COMBAT.canRightClick(enemy) or U.dist(actor.pos, enemy.pos) > math.max(650, (actor.attackRange or 200) + 220) then
            st.lastStand, st.defensiveItem = nil, nil
            return nil
        end
        if hp > 0.52 and not st.lastStand then return nil end
        local canHit = not actor.disarmed and U.dist(actor.pos, enemy.pos) <= (actor.attackRange or 200) + 160
        if hp <= 0.43 and canHit and not actor.satanicActive and COMBAT.readyItem(actor, "item_satanic") then
            st.defensiveItem = { name = "item_satanic", at = now }
            return { kind = "cast", item = "item_satanic", status = "Жму Satanic для драки" }
        end
        if hp <= 0.52 and not actor.bkbActive and ((actor.maxMana or 0) <= 0 or (actor.mana or 0) >= 50)
            and COMBAT.readyItem(actor, "item_black_king_bar") then
            st.defensiveItem = { name = "item_black_king_bar", at = now }
            return { kind = "cast", item = "item_black_king_bar", status = "Жму BKB для драки" }
        end
        local profile = PROFILES[actor.name]
        local manual = profile and profile.manualItems or {}
        if (actor.bkbActive and not manual.item_black_king_bar) or (actor.satanicActive and not manual.item_satanic) then
            st.lastStand = true
        end
        if st.lastStand and not actor.disarmed then
            st.retreat, st.kiteUntil = false, nil
            return { kind = "attack", target_id = enemy.id, status = "Продолжаю драться с руки" }
        end
    end

    function COMBAT.legionDuel(snapshot, actor, skills, enemy, allyCount, st)
        if actor.name ~= "npc_dota_hero_legion_commander" then return nil end
        local name = "legion_commander_duel"
        local profile = PROFILES[actor.name]
        local duel = skills[name]
        if not U.canCast(actor, duel) or (profile and profile.manualAbilities and profile.manualAbilities[name]) then
            st.duelTarget = nil
            return nil
        end
        local locked = st.duelTarget and snapshot.time < st.duelTarget.untilAt
            and COMBAT.visibleHero(snapshot, st.duelTarget.id)
        enemy = locked or enemy
        if not COMBAT.canRightClick(enemy) or enemy.hasBladeMail or actor.disarmed then return nil end
        local distance = U.dist(actor.pos, enemy.pos)
        local range = math.max(150, duel.castRange or 150)
        local hp = U.ratio(actor.hp, actor.maxHp)
        local enemyHp = U.ratio(enemy.hp, enemy.maxHp)
        if hp < 0.38 or (not locked and enemyHp > 0.75 and allyCount == 0) then return nil end

        local blink
        if distance > range and distance <= 1190 and not actor.rooted then
            for _, item in ipairs({ "item_blink", "item_overwhelming_blink", "item_swift_blink", "item_arcane_blink" }) do
                if COMBAT.readyItem(actor, item) then blink = item; break end
            end
        end
        if distance > range and not blink then return nil end
        if not COMBAT.isSafeFromTower(snapshot, actor, enemy.pos, false) and allyCount < 2 then return nil end

        if COMBAT.readyItem(actor, "item_blade_mail") and (actor.mana or 0) >= (duel.manaCost or 0) + 25 then
            st.duelTarget = { id = enemy.id, untilAt = snapshot.time + 2 }
            return { kind = "cast", item = "item_blade_mail", status = "Blade Mail перед Duel" }
        end
        if blink then
            st.duelTarget = { id = enemy.id, untilAt = snapshot.time + 2 }
            return { kind = "cast", item = blink, position = U.towards(enemy.pos, actor.pos, range * 0.5),
                status = "Blink под Duel" }
        end
        return { kind = "cast", ability = name, target_id = enemy.id, status = "Вызываю на Duel" }
    end

    function COMBAT.pickFinishTarget(snapshot, actor, hp, allyCount, enemyCount)
        local style = heroStyle(actor)
        if style.finishMaxHits <= 0 or actor.stunned or actor.hexed or actor.disarmed or hp < 0.23 then
            return nil
        end

        local best, bestTime = nil, math.huge
        local range = actor.attackRange or 200
        for _, enemy in ipairs(snapshot.enemies or {}) do
            if COMBAT.canRightClick(enemy) and not enemy.hasBladeMail then
                local distance = U.dist(actor.pos, enemy.pos)
                local gap = math.max(0, distance - range)
                local damage = (actor.attackDamage or 0) * U.armorMult(enemy.armor)
                local hits = math.ceil((enemy.hp or math.huge) / math.max(1, damage))
                local immediate = hits == 1 and gap <= 30
                local tower = COMBAT.nearestEnemyTower(snapshot, enemy.pos, TOWER_DANGER_RADIUS)
                local safe = not tower or COMBAT.isSafeFromTower(snapshot, actor, enemy.pos, false)
                    or COMBAT.canFightUnderTower(snapshot, actor, enemy, tower, allyCount, enemyCount, hp)
                    or (immediate and hp >= 0.55)
                if damage > 0 and hits <= style.finishMaxHits and gap <= style.finishChaseRange
                    and (immediate or hp >= style.fightMinHp)
                    and (gap <= 30 or not actor.rooted) and safe then
                    local disabled = enemy.stunned or enemy.hexed or enemy.rooted
                    local closingSpeed = math.max(100, actor.moveSpeed or 300)
                    if gap > 30 and not disabled and not enemy.channeling then
                        closingSpeed = math.max(hits == 1 and 105 or 1, closingSpeed - (enemy.moveSpeed or 300))
                    end
                    local time = (gap <= 30 and 0 or gap / math.max(1, closingSpeed))
                        + (actor.attackPoint or 0.35) + (hits - 1) * (actor.secondsPerAttack or 1.7)
                    if actor.ranged then time = time + distance / math.max(1, actor.projectileSpeed or 900) end
                    if time <= 3.5 and time < bestTime
                        and (immediate or U.countNear(snapshot.enemies, enemy.pos, 1000, U.isRealHero) <= allyCount + 1) then
                        best, bestTime = enemy, time
                    end
                end
            end
        end
        return best
    end

    function COMBAT.incomingTeleports(snapshot, actor)
        local allies, enemies, nearest = 0, 0, nil
        local nearestDistance = math.huge
        for _, arrival in ipairs(snapshot.teleports or {}) do
            local distance = U.dist(actor.pos, arrival.pos)
            if arrival.heroId ~= actor.id and distance <= 1300 then
                if arrival.team == snapshot.team then
                    allies = allies + 1
                else
                    enemies = enemies + 1
                    if distance < nearestDistance then nearest, nearestDistance = arrival, distance end
                end
            end
        end
        return allies, enemies, nearest
    end

    function COMBAT.areaCast(actor, ability, spell, target)
        local mode, radius, reach = spell[2], spell[3], spell[4]
        local distance = U.dist(actor.pos, target.pos)
        local range = (ability.castRange or 0) + 25
        if mode == "self" and distance <= radius and hasBit(ability.behavior, B_NO_TARGET) then
            return {}
        elseif mode == "target" and distance <= range and hasBit(ability.behavior, B_UNIT_TARGET) then
            return { target_id = target.id }
        elseif mode == "offset" and actor.forward and distance >= reach - radius and distance <= reach + radius
            and hasBit(ability.behavior, B_NO_TARGET) then
            local center = { x = actor.pos.x + actor.forward.x * reach, y = actor.pos.y + actor.forward.y * reach }
            if U.dist(center, target.pos) <= radius then return {}, center end
        elseif (mode == "point" or mode == "line") and distance <= (reach or range)
            and hasBit(ability.behavior, B_POINT) then
            local pos = distance > range and U.towards(actor.pos, target.pos, range) or target.pos
            return { position = pos }
        end
    end

    function COMBAT.areaHits(actor, spell, target, units, offsetCenter)
        local mode, radius, reach = spell[2], spell[3], spell[4]
        local function isFarmCreep(u)
            return not u.invulnerable and (u.kind == "neutral" or U.isLaneCreep(u))
        end
        if mode ~= "line" then
            local center = offsetCenter or (mode == "self" and actor.pos or target.pos)
            return U.countNear(units, center, radius, isFarmCreep)
        end
        local distance = U.dist(actor.pos, target.pos)
        if distance < 1 then return 0 end
        local x = (target.pos.x - actor.pos.x) / distance
        local y = (target.pos.y - actor.pos.y) / distance
        return U.countNear(units, actor.pos, reach + radius, function(u)
            local dx, dy = u.pos.x - actor.pos.x, u.pos.y - actor.pos.y
            local along = dx * x + dy * y
            return isFarmCreep(u) and along >= 0 and along <= reach and math.abs(dx * y - dy * x) <= radius
        end)
    end

    function COMBAT.farmCast(actor, target, units, minHits)
        if heroStyle(actor).farmAbilities == false or target.invulnerable then return nil end
        local skills = U.skillMap(actor)
        local profile = PROFILES[actor.name]
        local manual = profile and profile.manualAbilities
        local reserve = (actor.maxMana or 0) * 0.26
        for _, spell in ipairs(FARM_SPELLS) do
            local name = spell[1]
            local ability = skills[name]
            if spell[3] > 0 and not (manual and manual[name]) and U.canCast(actor, ability)
                and (actor.mana or 0) >= (ability.manaCost or 0) + reserve then
                local act, center = COMBAT.areaCast(actor, ability, spell, target)
                if act and COMBAT.areaHits(actor, spell, target, units, center) >= minHits then
                    act.kind, act.ability, act.status = "cast", name, "Зачищаю крипов способностью"
                    return act
                end
            end
        end
    end

    local ROSHAN_PIT_RADIUS = 330

    local function bossName(kind, form)
        local isRosh = (kind == "roshan" or kind == "ROSHAN")
        if form == "dat" then return isRosh and "Рошану" or "Терзателю" end
        if form == "gen" then return isRosh and "Рошана" or "Терзателя" end
        if form == "nom" then return isRosh and "Рошан" or "Терзатель" end
        return isRosh and "Рошана" or "Терзателя" -- acc (кого/на кого)
    end

    function COMBAT.roshanTankScore(hero)
        local hp = hero.hp or 0
        local hpR = U.ratio(hp, hero.maxHp)
        local effHp = hp * (1 + 0.06 * math.max(0, hero.armor or 0))
        local score = effHp
        if not hero.ranged then score = score + 850 end
        if hero.position == 3 then
            score = score + 700
        elseif hero.position == 1 then
            score = score + 450
        elseif hero.position == 2 then
            score = score + 250
        else
            score = score - 1400 -- саппорты не должны танковать первыми
        end
        if DATA.TANK_HEROES[hero.name] then score = score + 500 end
        if hero.hasAegis then score = score + 1200 end
        if U.hasItem(hero, "item_satanic", true) or U.hasItem(hero, "item_heart", true)
            or U.hasItem(hero, "item_crimson_guard", true) or U.hasItem(hero, "item_shivas_guard", true)
            or U.hasItem(hero, "item_assault", true) then
            score = score + 650
        end
        if hpR < 0.42 then score = score - 2200 end
        if hpR < 0.30 then score = score - 4000 end
        return score
    end

    function COMBAT.bossCast(snapshot, actor, macro, st, nearby)
        local target = macro and macro.targetUnit
        if not target or target.invulnerable or U.ratio(actor.hp, actor.maxHp) < 0.38 then return nil end

        if macro.phase == "ROSHAN" then
            local pitPos = macro.pitPos or macro.pos
            if U.dist(actor.pos, pitPos) > ROSHAN_PIT_RADIUS
                or U.dist(target.pos, pitPos) > ROSHAN_PIT_RADIUS + 40 then
                return nil
            end
            if actor.id ~= macro.tankId and (not macro.tankEngaged or target.aggroTargetId == actor.id) then
                return nil
            end
        elseif macro.phase == "TORMENTOR" then
            if U.dist(actor.pos, target.pos) > 1050 then return nil end
        end

        local distance = U.dist(actor.pos, target.pos)
        if distance > 1200 then return nil end
        local profile = PROFILES[actor.name]
        local manualAbilities = profile and profile.manualAbilities
        local manualItems = profile and profile.manualItems
        local skills = U.skillMap(actor)
        local health = U.ratio(target.hp, target.maxHp)
        local now = snapshot.time
        local targetDat = bossName(macro.kind or target.kind, "dat")
        st.bossCastAt = st.bossCastAt or {}
        for _, spells in ipairs({ BOSS_SPELLS, FARM_SPELLS }) do
            for _, spell in ipairs(spells) do
                local name = spell[1]
                if spell[5] ~= false and (not spell[6] or target.kind == "tormentor" or health > 0.25)
                    and not (manualAbilities and manualAbilities[name])
                    and now >= (st.bossCastAt[name] or 0) and U.canCast(actor, skills[name]) then
                    local act = COMBAT.areaCast(actor, skills[name], spell, target)
                    if act then
                        st.bossCastAt[name] = now + 2.5
                        act.kind, act.ability, act.status = "cast", name, "Применяю способность по " .. targetDat
                        return act
                    end
                end
            end
        end
        if actor.muted or distance > (actor.attackRange or 200) + 110 then return nil end
        local sustain = U.ratio(actor.hp, actor.maxHp) <= 0.68
        local items = {
            { "item_satanic", sustain },
            { "item_mjollnir", nearby >= 1, actor.id },
            { "item_bloodthorn", health > 0.25, target.id },
            { "item_orchid", health > 0.25, target.id },
            { "item_mask_of_madness", not sustain and not actor.silenced },
            { "item_harpoon", health > 0.15, target.id },
        }
        for _, item in ipairs(items) do
            local name = item[1]
            local slot = item[2] and not (manualItems and manualItems[name]) and U.hasItem(actor, name, true)
            if slot and U.itemCd(actor, slot) <= 0 and now >= (st.bossCastAt[name] or 0) then
                st.bossCastAt[name] = now + 2.5
                return { kind = "cast", item = name, target_id = item[3], status = "Использую предмет по " .. targetDat }
            end
        end
    end

    function COMBAT.decideActiveItem(snapshot, actor, enemy, enemyCount, allyCount, threats, macro, prioritizeFarm)
        local hp = U.ratio(actor.hp, actor.maxHp)
        local mana = U.ratio(actor.mana, actor.maxMana)
        local now = snapshot.time

        local profile = PROFILES[actor.name]
        local manual = profile and profile.manualItems
        local function activeSlot(name)
            if not (manual and manual[name]) then return U.hasItem(actor, name, true) end
        end
        local function tryItem(name, status, targetId, pos)
            local slot = activeSlot(name)
            if not slot or U.itemCd(actor, slot) > 0 then return nil end
            return { kind = "cast", item = name, target_id = targetId, position = pos, status = status }
        end

        if threats.invis and U.hasItem(actor, "item_dust", true) then
            local needDust = false
            for _, e in ipairs(snapshot.enemies or {}) do
                if U.isRealHero(e) and U.dist(actor.pos, e.pos) <= 950 and not e.dusted then
                    local isInvHero = e.invisible or DATA.INVIS_HEROES[e.name]
                    if not isInvHero then
                        for _, it in pairs(e.items or {}) do
                            if DATA.INVIS_ITEMS[it] then isInvHero = true; break end
                        end
                    end
                    if isInvHero and (e.invisible or U.ratio(e.hp, e.maxHp) < 0.65) then
                        needDust = true; break
                    end
                end
            end
            if not needDust then
                local vis = {}
                for _, e in ipairs(snapshot.enemies or {}) do vis[e.id] = true end
                for eid, rec in pairs(snapshot.enemyLastSeen or {}) do
                    if not vis[eid] and (now - rec.at) <= 2.5 and U.dist(actor.pos, rec.pos) <= 950 then
                        local hasInv = DATA.INVIS_HEROES[rec.name] == true
                        if not hasInv then
                            for _, it in pairs(rec.items or {}) do
                                if DATA.INVIS_ITEMS[it] then hasInv = true; break end
                            end
                        end
                        if hasInv then needDust = true; break end
                    end
                end
            end
            if needDust then
                local o = tryItem("item_dust", "Жму Dust по инвизу")
                if o then return o end
            end
        end

        if hp < 0.36 then
            local o = tryItem("item_cheese", "Ем Cheese")
                or tryItem("item_faerie_fire", "Жму Faerie Fire")
            if o then return o end
        end
        if hp < 0.52 or mana < 0.22 then
            local wandSlot = activeSlot("item_magic_wand") or activeSlot("item_magic_stick")
            if wandSlot and U.itemCd(actor, wandSlot) <= 0 and U.itemCharges(actor, wandSlot) >= 4 then
                return { kind = "cast", item = actor.items[wandSlot], status = "Жму стики" }
            end
            for _, lotus in ipairs({ "item_greater_famango", "item_great_famango", "item_famango" }) do
                local o = tryItem(lotus, "Ем лотос")
                if o then return o end
            end
        end
        if hp < 0.78 and not actor.hasTangoRegen and actor.hasTangoTree ~= false then
            local o = tryItem("item_tango", "Ем Tango") or tryItem("item_tango_single", "Ем Tango")
            if o then return o end
        end
        if hp < 0.66 and not actor.hasFlaskRegen and not enemy and enemyCount == 0 then
            local o = tryItem("item_flask", "Лечусь Salve", actor.id)
            if o then return o end
        end
        -- 1) Заливка Arcane Boots / Guardian Greaves себе ИЛИ любому просевшему по мане союзнику рядом
        local dryAlly = U.nearest(snapshot.heroes, actor.pos, 1180, function(h)
            return h.alive and h.id ~= actor.id and (h.maxMana or 0) >= 200
                and U.ratio(h.mana, h.maxMana) < 0.52
        end)
        if mana < 0.48 or (dryAlly and (mana < 0.85 or U.ratio(dryAlly.mana, dryAlly.maxMana) < 0.35)) then
            local o = tryItem("item_arcane_boots", dryAlly and "Заливаю ману союзнику" or "Заливаю ману")
                or (mana < 0.35 and tryItem("item_guardian_greaves", "Жму Greaves на ману"))
            if o then return o end
        end

        -- 2) Проактивный долив маны (Mango/Wand/Lotus) в бою, если не хватает чуть-чуть именно на откатившийся ульт/кнопку
        if enemy and enemyCount >= 1 then
            local myR = COMBAT.heroCombatReadiness(actor)
            if myR.ultNeedsManaOnly or (myR.minSpellMana > 0 and (actor.mana or 0) < myR.minSpellMana) then
                local o = tryItem("item_enchanted_mango", "Ем манго под каст!")
                if o then return o end
                local wSlot = activeSlot("item_magic_wand") or activeSlot("item_magic_stick")
                if wSlot and U.itemCd(actor, wSlot) <= 0 and U.itemCharges(actor, wSlot) >= 3 then
                    return { kind = "cast", item = actor.items[wSlot], status = "Стики на ману!" }
                end
                for _, lotus in ipairs({ "item_famango", "item_great_famango", "item_greater_famango" }) do
                    local lo = tryItem(lotus, "Лотос на ману!")
                    if lo then return lo end
                end
            end
        end

        if mana < 0.45 and not actor.hasClarity and not enemy and enemyCount == 0 then
            local o = tryItem("item_clarity", "Пью Clarity", actor.id)
            if o then return o end
        end
        if mana < 0.28 then
            local o = tryItem("item_enchanted_mango", "Ем манго")
            if o then return o end
        end
        if not enemy and (hp < 0.72 or mana < 0.45) then
            local bSlot = activeSlot("item_bottle")
            if bSlot and U.itemCd(actor, bSlot) <= 0 and U.itemCharges(actor, bSlot) > 0 then
                return { kind = "cast", item = "item_bottle", status = "Пью Bottle" }
            end
        end

        local hurtAlly = U.nearest(snapshot.heroes, actor.pos, 750, function(h)
            return h.alive and h.id ~= actor.id and U.ratio(h.hp, h.maxHp) < 0.45
        end)
        if hurtAlly and enemyCount >= 1 then
            local o = tryItem("item_glimmer_cape", "Сейвлю союзника", hurtAlly.id)
                or tryItem("item_guardian_greaves", "Жму Greaves")
                or tryItem("item_mekansm", "Жму Mekansm")
                or tryItem("item_solar_crest", "Щит союзнику", hurtAlly.id)
                or tryItem("item_pavise", "Щит Pavise союзнику", hurtAlly.id)
            if o then return o end
        end

        if enemy then
            local d = U.dist(actor.pos, enemy.pos)
            if (enemyCount >= 2 and hp < 0.80) or (hp < 0.55 and enemyCount >= 1) then
                local o = (((actor.maxMana or 0) <= 0 or (actor.mana or 0) >= 50) and not actor.muted and tryItem("item_black_king_bar", "Жму BKB"))
                    or tryItem("item_pipe", "Жму Pipe")
                    or tryItem("item_crimson_guard", "Жму Crimson")
                    or tryItem("item_blade_mail", "Жму Blade Mail")
                    or tryItem("item_shivas_guard", "Жму Shiva")
                    or tryItem("item_guardian_greaves", "Жму Greaves")
                if o then return o end
            end
            if hp < 0.42 then
                local o = tryItem("item_glimmer_cape", "Сейвлюсь Glimmer", actor.id)
                    or tryItem("item_manta", "Жму Manta")
                if o then return o end
            end
            if prioritizeFarm then return nil end
            if d <= 250 and not enemy.stunned and not enemy.hexed then
                local o = tryItem("item_abyssal_blade", "Даю Abyssal", enemy.id)
                if o then MEM.stunCastAt[enemy.id] = now; return o end
            end
            if not enemy.magicImmune then
                if d <= 800 and not enemy.stunned and not enemy.hexed then
                    local o = tryItem("item_sheepstick", "Даю Hex", enemy.id)
                    if o then MEM.stunCastAt[enemy.id] = now; return o end
                end
                if d <= 900 and not enemy.silenced then
                    local o = tryItem("item_bloodthorn", "Даю Bloodthorn", enemy.id)
                        or tryItem("item_orchid", "Даю Orchid", enemy.id)
                    if o then return o end
                end
                if d >= 220 and d <= 700 then
                    local o = tryItem("item_harpoon", "Притягиваю Harpoon", enemy.id)
                    if o then return o end
                end
                if d <= 950 then
                    local vSlot = activeSlot("item_spirit_vessel")
                    if vSlot and U.itemCd(actor, vSlot) <= 0 and U.itemCharges(actor, vSlot) > 0 then
                        return { kind = "cast", item = "item_spirit_vessel", target_id = enemy.id, status = "Кидаю Vessel" }
                    end
                end
            end
            if hp < 0.45 or (actor.ranged and d <= 400) then
                local o = tryItem("item_hurricane_pike", "Толкаю Pike", (d <= 400 and not enemy.magicImmune) and enemy.id or actor.id)
                    or (hp < 0.45 and tryItem("item_force_staff", "Форсстафф сейв", actor.id))
                if o then return o end
            end
            if d > (actor.attackRange or 200) + 120 and d <= 850 then
                local o = tryItem("item_force_staff", "Форсстафф догон", actor.id)
                if o then return o end
            end
            if d <= 850 and U.ratio(enemy.hp, enemy.maxHp) < 0.80 then
                local o = tryItem("item_blood_grenade", "Кидаю гранату", nil, enemy.pos)
                if o then return o end
            end
            if (actor.position == 3 or actor.name == "npc_dota_hero_dragon_knight" or actor.name == "npc_dota_hero_sven")
                and allyCount >= 1 and hp > 0.62 and d >= 450 and d <= 1150 then
                local myR = COMBAT.heroCombatReadiness(actor)
                local nearR = COMBAT.teamFightReadiness(snapshot, actor.pos, 1300)
                local readyToInit = (not myR.noSpells) and (not nearR.shouldAvoidBigFight or allyCount >= enemyCount + 1)
                local safeT = COMBAT.isSafeFromTower(snapshot, actor, enemy.pos, macro.phase ~= "PUSH" and allyCount >= 3)
                if safeT and readyToInit then
                    local o = tryItem("item_blink", "Инициирую с Blink", nil, enemy.pos)
                    if o then return o end
                end
            end
            if d > (actor.attackRange or 200) + 100 and d < 900 then
                local o = tryItem("item_phase_boots", "Ускоряюсь Phase")
                if o then return o end
            end

            -- Активный нейтральный артефакт (слот 16)
            local neu = actor.neutral
            if neu and neu.artifact and not (manual and manual[neu.artifact])
                and neu.artifactActive and neu.artifactCastable
                and (neu.artifactCd or 0) <= 0 then
                local beh = neu.artifactBehavior or 0
                local nRange = (neu.artifactCastRange and neu.artifactCastRange > 0) and math.min(neu.artifactCastRange, 1100) or 600
                if hasBit(beh, B_UNIT_TARGET) and neu.artifactTargetTeam == T_FRIENDLY then
                    if hp < 0.72 then
                        return { kind = "cast", item = neu.artifact, target_id = actor.id, status = "Жму нейтралку!" }
                    end
                elseif hasBit(beh, B_NO_TARGET) and d <= math.min(nRange, 650) then
                    return { kind = "cast", item = neu.artifact, status = "Жму нейтралку!" }
                elseif not enemy.magicImmune and d <= nRange + 30 then
                    if hasBit(beh, B_UNIT_TARGET) and neu.artifactTargetTeam ~= T_FRIENDLY then
                        return { kind = "cast", item = neu.artifact, target_id = enemy.id, status = "Жму нейтралку!" }
                    elseif hasBit(beh, B_POINT) then
                        return { kind = "cast", item = neu.artifact, position = enemy.pos, status = "Жму нейтралку!" }
                    end
                end
            end
        end

        if actor.position >= 4 and not actor.smoked and now > STYLE.smokeMinTime
            and now - MEM.lastSmokeAt > STYLE.smokeCooldown
            and enemyCount == 0 and allyCount >= 2
            and (macro.phase == "PUSH" or macro.phase == "ROSHAN" or macro.phase == "SMOKE_GANK") then
            local sSlot = activeSlot("item_smoke_of_deceit")
            if sSlot and U.itemCd(actor, sSlot) <= 0 then
                MEM.lastSmokeAt = now
                return { kind = "smoke", status = "Жму Smoke!" }
            end
        end

        if macro.phase == "PUSH" and allyCount >= 2 then
            local o = tryItem("item_horn_of_battle_greater", "Жму Greater Horn")
                or tryItem("item_roshans_banner", "Ставлю Banner", nil, actor.pos)
            if o then return o end
        end

        return nil
    end

    -- Универсальный фоллбэк-каст для любых героев, не описанных в DATA.SKILLS
    function COMBAT.decideGenericSkill(snapshot, actor, enemy, enemyCount, allyCount, manual)
        if not enemy then return nil end
        local d = U.dist(actor.pos, enemy.pos)
        local hp = U.ratio(actor.hp, actor.maxHp)
        local enemyHp = U.ratio(enemy.hp, enemy.maxHp)

        for _, ab in pairs(actor.abilities or {}) do
            if ab and ab.name and not ab.hidden and not ab.passive
                and not (manual and manual[ab.name])
                and (ab.level or 0) > 0 and ab.fullyCastable and (ab.cooldown or 0) <= 0
                and not ab.name:find("^special_bonus_")
                and not ESCAPE_OR_MOBILITY_SPELLS[ab.name]
                and not hasBit(ab.behavior, B_PASSIVE)
                and not hasBit(ab.behavior, B_TOGGLE)
                and not hasBit(ab.behavior, B_AUTOCAST) then

                local isUlt = ab.isUltimate or (ab.maxLevel == 3)
                local allowUlt = (not isUlt) or enemyHp < 0.72 or (enemyCount or 1) >= 2 or (allyCount or 0) >= 1
                local range = (ab.castRange and ab.castRange > 0) and math.min(ab.castRange, 1300) or 550

                -- 1. Союзные баффы/хилы (включая самого себя)
                if hasBit(ab.behavior, B_UNIT_TARGET) and ab.targetTeam == T_FRIENDLY then
                    local ally = U.nearest(snapshot.heroes, actor.pos, range, function(h)
                        return h.alive and U.ratio(h.hp, h.maxHp) < 0.78
                    end)
                    if ally and allowUlt then
                        return { kind = "cast", ability = ab.name, target_id = ally.id, status = "Бафаю союзника" }
                    end

                -- 2. Селф-скиллы и AoE вокруг себя (работают даже если враг в BKB)
                elseif hasBit(ab.behavior, B_NO_TARGET) and allowUlt and d <= math.min(range, 620) then
                    if not hasBit(ab.behavior, B_CHANNELLED) or (enemyCount or 1) >= 2 or hp > 0.55 then
                        return { kind = "cast", ability = ab.name, status = isUlt and "Жму ульт!" or "Кастую скилл" }
                    end

                -- 3. Атакующие скиллы по цели или точке
                elseif not enemy.magicImmune and allowUlt and d <= range + 40 then
                    if hasBit(ab.behavior, B_UNIT_TARGET) and ab.targetTeam ~= T_FRIENDLY then
                        return { kind = "cast", ability = ab.name, target_id = enemy.id, status = isUlt and "Жму ульт!" or "Кастую скилл" }
                    elseif hasBit(ab.behavior, B_POINT) then
                        if not hasBit(ab.behavior, B_CHANNELLED) or d <= range - 60 then
                            return { kind = "cast", ability = ab.name, position = enemy.pos, status = isUlt and "Жму ульт!" or "Кастую скилл" }
                        end
                    end
                end
            end
        end
        return nil
    end

    function COMBAT.decideSkillCast(snapshot, actor, byName, enemy, enemyCount, allyCount, macro, prioritizeFarm)
        local cfg = DATA.SKILLS[actor.name]
        local profile = PROFILES[actor.name]
        local manual = profile and profile.manualAbilities
        if not cfg then
            if not prioritizeFarm then
                return COMBAT.decideGenericSkill(snapshot, actor, enemy, enemyCount, allyCount, manual)
            end
            return nil
        end

        local now = snapshot.time
        local hp = U.ratio(actor.hp, actor.maxHp)
        local mana = U.ratio(actor.mana, actor.maxMana)

        for _, spec in ipairs(cfg.list) do
            if spec[2] == "toggle_heal" and not (manual and manual[spec[1]]) then
                local ab = byName[spec[1]]
                if ab and (ab.level or 0) > 0 then
                    local injuredNearby = U.countNear(snapshot.heroes, actor.pos, 520, function(h)
                        return h.alive and U.ratio(h.hp, h.maxHp) < 0.72
                    end)
                    local wantOn = injuredNearby >= 1 and mana > 0.25
                    if ab.toggle and (not wantOn or mana < 0.14) then
                        return { kind = "toggle", ability = spec[1], status = "Выключаю хил" }
                    elseif not ab.toggle and wantOn and ab.fullyCastable then
                        return { kind = "toggle", ability = spec[1], status = "Включаю хил" }
                    end
                end
            end
        end

        if prioritizeFarm then return nil end

        if not enemy and macro.phase == "PUSH" and macro.targetBuilding
            and U.dist(actor.pos, macro.targetBuilding.pos) <= 700 then
            for _, spec in ipairs(cfg.list) do
                if spec[4] == "push_ult" and not (manual and manual[spec[1]]) then
                    local ab = byName[spec[1]]
                    if ab and (ab.level or 0) > 0 and ab.fullyCastable and (ab.cooldown or 0) <= 0 then
                        if spec[2] == "point" then
                            return { kind = "cast", ability = spec[1], position = macro.targetBuilding.pos, status = "Ульт в вышку!" }
                        else
                            return { kind = "cast", ability = spec[1], status = "Ульт на пуш!" }
                        end
                    end
                end
            end
        end

        if not enemy then return nil end
        local d = U.dist(actor.pos, enemy.pos)
        local enemyHp = U.ratio(enemy.hp, enemy.maxHp)
        local recentlyStunned = MEM.stunCastAt[enemy.id] and (now - MEM.stunCastAt[enemy.id]) < 0.8

        for _, spec in ipairs(cfg.list) do
            local name, mode, range, tag = spec[1], spec[2], spec[3], spec[4]
            local ab = byName[name]
            if ab and mode ~= "passive" and mode ~= "orb" and mode ~= "toggle_heal" and mode ~= "manual"
                and not (manual and manual[name])
                and (ab.level or 0) > 0 and ab.fullyCastable and (ab.cooldown or 0) <= 0 then
                local cap = (ab.castRange and ab.castRange > 0) and math.min(range, ab.castRange + 30) or range
                if d <= cap then
                    local isStun = (tag == "stun")
                    local skipStun = isStun and (enemy.stunned or enemy.hexed or recentlyStunned) and not enemy.channeling
                    local skipSilence = (tag == "silence") and enemy.silenced and not enemy.channeling
                    local skipBkb = enemy.magicImmune and mode ~= "self" and mode ~= "ally" and tag ~= "debuff" and tag ~= "execute"
                    local allow = not skipStun and not skipSilence and not skipBkb

                    -- Резерв маны под ультимейт (не тратим последнюю ману на обычный нюк, если враг не умирает)
                    local ultSpec = cfg.list[4]
                    local ultAb = ultSpec and byName[ultSpec[1]]
                    if ultAb and name ~= ultSpec[1] and not ultAb.passive and (ultAb.level or 0) > 0
                        and (ultAb.cooldown or 0) <= 5.0 and (ultAb.manaCost or 0) > 0 then
                        local manaAfter = (actor.mana or 0) - (ab.manaCost or 0)
                        local urgentCast = (enemyHp < 0.35) or enemy.channeling or (tag == "heal") or (tag == "def")
                        if manaAfter < ultAb.manaCost and not urgentCast then
                            allow = false
                        end
                    end

                    if tag == "ult" or tag == "push_ult" then
                        allow = allow and (enemyHp < 0.75 or enemyCount >= 2 or allyCount >= 1)
                    elseif tag == "group" then
                        allow = allow and (enemyCount >= 2 or (allyCount >= 2 and enemyHp < 0.60))
                    elseif tag == "finish" then
                        allow = allow and (enemyHp < 0.48 or enemy.channeling)
                    elseif tag == "execute" then
                        allow = allow and (enemy.hp or 9999) <= (240 + (ab.level or 1) * 100)
                    elseif tag == "heal" then
                        allow = hp < 0.68 or (mode == "ally" and U.nearest(snapshot.heroes, actor.pos, cap, function(h)
                            return h.alive and U.ratio(h.hp, h.maxHp) < 0.68
                        end) ~= nil)
                    elseif tag == "save" then
                        allow = U.nearest(snapshot.heroes, actor.pos, cap, function(h)
                            return h.alive and U.ratio(h.hp, h.maxHp) < 0.24
                        end) ~= nil
                    elseif tag == "sunder" then
                        allow = hp < 0.30 and enemyHp > hp + 0.32
                    elseif tag == "def" then
                        allow = hp < 0.75 or enemyCount >= 2 or d > 350
                    elseif tag == "mana" then
                        allow = mana < 0.45 and (enemy.mana or 0) >= 80 and enemyCount <= 1 and d <= 520
                    end

                    if allow then
                        if isStun then MEM.stunCastAt[enemy.id] = now end
                        if mode == "point" then
                            local pt = (tag == "heal") and actor.pos or enemy.pos
                            return { kind = "cast", ability = name, position = pt, status = "Кастую скилл" }
                        elseif mode == "target" then
                            return { kind = "cast", ability = name, target_id = enemy.id, status = "Кастую скилл" }
                        elseif mode == "ally" then
                            local ally
                            local noSelf = (name == "abaddon_death_coil")
                            if tag == "save" or tag == "heal" then
                                local bestHp = (tag == "save") and 0.24 or 0.72
                                for _, h in ipairs(snapshot.heroes or {}) do
                                    if h.alive and (not noSelf or h.id ~= actor.id) and U.dist(actor.pos, h.pos) <= cap then
                                        local r = U.ratio(h.hp, h.maxHp)
                                        if r < bestHp then bestHp, ally = r, h end
                                    end
                                end
                            else
                                ally = U.nearest(snapshot.heroes, actor.pos, cap, function(h)
                                    return h.alive and (not noSelf or h.id ~= actor.id) and (h.position <= 2 or U.ratio(h.hp, h.maxHp) < 0.85)
                                end)
                            end
                            if not ally and not noSelf then ally = actor end
                            if not ally then return nil end
                            local statusText = (tag == "save" or tag == "heal") and "Сейвлю союзника" or "Бафаю союзника"
                            return { kind = "cast", ability = name, target_id = ally.id, status = statusText }
                        else
                            return { kind = "cast", ability = name, status = "Кастую скилл" }
                        end
                    end
                end
            end
        end
        return nil
    end

    -- ========================================================================
    -- MACRO: Командные фазы + подключение tactic.PlanMacro
    -- ========================================================================
    local MACRO = {}

    function MACRO.pickWardGank(snapshot)
        if snapshot.time < math.max(STYLE.laningEndTime, 600) then return nil end

        local observers = {}
        for _, ally in ipairs(snapshot.allies or {}) do
            if ally.kind == "observer_ward" and ally.alive and (ally.visionRange or 0) > 0 then
                observers[#observers + 1] = ally
            end
        end
        if #observers == 0 then return nil end

        local function underObserver(enemy)
            for _, ward in ipairs(observers) do
                if U.dist(ward.pos, enemy.pos) < ward.visionRange then return true end
            end
            return false
        end

        local function canJoin(hero)
            local r = COMBAT.heroCombatReadiness(hero)
            return hero.alive and U.ratio(hero.hp, hero.maxHp) >= 0.65
                and (not r.isOom or hero.position == 1)
                and U.countNear(snapshot.enemies, hero.pos, 950, U.isRealHero) <= 1
        end

        local bestPlan, bestScore = nil, math.huge
        for _, enemy in ipairs(snapshot.enemies or {}) do
            if U.isRealHero(enemy) and enemy.alive and not enemy.invulnerable
                and not enemy.attackImmune and not enemy.hasBladeMail and underObserver(enemy)
                and U.countNear(snapshot.enemies, enemy.pos, 1350, U.isRealHero) == 1
                and not COMBAT.nearestEnemyTower(snapshot, enemy.pos, 1050) then
                local core, coreDist = U.nearest(snapshot.heroes, enemy.pos, 1550, function(hero)
                    return hero.position >= 2 and hero.position <= 3 and canJoin(hero)
                end)
                local support, supportDist = U.nearest(snapshot.heroes, enemy.pos, 1550, function(hero)
                    return hero.position >= 4 and canJoin(hero)
                end)
                if core and support and math.min(coreDist, supportDist) <= 1000 then
                    local enemyHp = U.ratio(enemy.hp, enemy.maxHp)
                    local extra, extraDist = U.nearest(snapshot.heroes, enemy.pos, 1250, function(hero)
                        return hero.position >= 4 and hero.id ~= support.id and canJoin(hero)
                    end)
                    local em = COMBAT.analyzeEnemyMana(enemy)
                    local need = (enemyHp > 0.80 and not em.isOom and not em.noEscapeMana) and 3 or 2
                    if need == 2 or extra then
                        local nearer = coreDist <= supportDist and core or support
                        local rendezvous = U.towards(enemy.pos, nearer.pos, 820)
                        local score = coreDist + supportDist + enemyHp * 1000
                        if bestScore > score and not COMBAT.nearestEnemyTower(snapshot, rendezvous, TOWER_DANGER_RADIUS) then
                            local members = { [core.id] = true, [support.id] = true }
                            if need == 3 then members[extra.id] = true end
                            bestPlan = {
                                target = enemy,
                                members = members,
                                rendezvous = rendezvous,
                                ready = coreDist <= 1000 and supportDist <= 1000
                                    and (need == 2 or extraDist <= 1000),
                            }
                            bestScore = score
                        end
                    end
                end
            end
        end
        return bestPlan
    end

    function MACRO.updateTowerMemory(snapshot, aliveGroup)
        local aliveMap = snapshot.scoreboard and snapshot.scoreboard.enemyAliveTowers
        for _, pin in ipairs(snapshot.pins or {}) do
            if pin.kind == "tower" and pin.mapTeam == snapshot.enemyTeam then
                local key = tostring(pin.lane) .. tostring(pin.tier)
                if aliveMap then
                    -- Точная синхронизация с публичной миникартой
                    MEM.clearedTowers[key] = (not aliveMap[key]) and true or nil
                else
                    local seen = U.nearest(snapshot.enemies, pin.pos, 320, function(u) return u.kind == "tower" end)
                    if seen then
                        MEM.clearedTowers[key] = nil
                    elseif pin.visible and U.countNear(aliveGroup, pin.pos, 950) > 0 then
                        MEM.clearedTowers[key] = true
                    end
                end
            end
        end
    end

    -- Оценка перевеса команды, мёртвых врагов и запомненных КД вражеских кнопок
    function MACRO.assessSituation(snapshot, aliveGroup)
        local sb = snapshot.scoreboard or {}
        local enemyUltsDown, enemyBkbDown, enemyBigSpellsDown = 0, 0, 0
        for _, rec in ipairs(snapshot.enemyCooldowns or {}) do
            if (rec.remaining or 0) >= 8 then
                if rec.isUlt then
                    enemyUltsDown = enemyUltsDown + 1
                elseif rec.ability == "item_black_king_bar" then
                    enemyBkbDown = enemyBkbDown + 1
                else
                    enemyBigSpellsDown = enemyBigSpellsDown + 1
                end
            end
        end

        local killDiff = (sb.allyKills or 0) - (sb.enemyKills or 0)
        local towerDiff = (sb.allyTowersLeft or 0) - (sb.enemyTowersLeft or 0)
        local lvlDiff = (sb.allyAvgLevel or 1) - (sb.enemyAvgLevel or 1)
        local enemyDead = sb.enemyDeadCount or 0
        local enemyOomCount = 0
        for _, e in ipairs(snapshot.enemies or {}) do
            if U.isRealHero(e) and COMBAT.analyzeEnemyMana(e).isOom then
                enemyOomCount = enemyOomCount + 1
            end
        end
        local advScore = killDiff * 2 + towerDiff * 7 + lvlDiff * 4

        local posture = "EVEN"
        if advScore >= 6 then
            posture = "WINNING"
        elseif advScore <= -6 then
            posture = "LOSING"
        end

        local teamReady = COMBAT.teamFightReadiness(snapshot)
        -- Учитываем ульты, которые откатятся за ближайшие 10 сек (пока команда дойдёт до вышки)
        local ultsReadyOrComing = (teamReady.readyUlts > 0) or (teamReady.minUltCd > 0 and teamReady.minUltCd <= 10)
            or (teamReady.totalActiveUlts < 2)

        -- Окно для агрессивного пуша/атаки: враги мертвы ИЛИ слили важные ульты/BKB
        local attackWindow = (enemyDead >= 2)
            or (enemyDead >= 1 and (enemyUltsDown >= 1 or enemyBkbDown >= 1 or enemyOomCount >= 1) and #aliveGroup >= 3)
            or ((enemyUltsDown >= 2 or enemyOomCount >= 2 or (enemyUltsDown >= 1 and enemyBkbDown >= 1)) and ultsReadyOrComing)

        -- Окно для фарма и расстановки вижена: мы отстаём ИЛИ у нас нет ультов, а у врагов все кнопки целы
        local shouldFarm = (not attackWindow) and (
            teamReady.teamOom
            or (teamReady.ultsMissing and not ultsReadyOrComing)
            or (posture == "LOSING" and enemyDead == 0 and enemyUltsDown == 0 and enemyBkbDown == 0 and enemyOomCount == 0)
        )

        return {
            posture = posture,
            advScore = advScore,
            enemyDead = enemyDead,
            enemyOomCount = enemyOomCount,
            enemyUltsDown = enemyUltsDown,
            enemyBkbDown = enemyBkbDown,
            enemyBigSpellsDown = enemyBigSpellsDown,
            teamReady = teamReady,
            ultsReadyOrComing = ultsReadyOrComing,
            attackWindow = attackWindow,
            shouldFarm = shouldFarm,
        }
    end

    function MACRO.siegeLanes(snapshot, ownAncient, enemyAncient)
        local lanes = {
            { name = "top", ours = {}, theirs = {}, route = {}, allies = {}, enemies = {} },
            { name = "mid", ours = {}, theirs = {}, route = {}, allies = {}, enemies = {} },
            { name = "bot", ours = {}, theirs = {}, route = {}, allies = {}, enemies = {} },
        }
        for _, lane in ipairs(lanes) do
            for _, pin in ipairs(snapshot.pins or {}) do
                if pin.kind == "tower" and pin.lane == lane.name and pin.tier and pin.tier <= 3 then
                    local towers = pin.mapTeam == snapshot.team and lane.ours or lane.theirs
                    towers[pin.tier] = pin.pos
                end
            end
            local route = lane.route
            route[#route + 1] = ownAncient
            for tier = 3, 1, -1 do route[#route + 1] = lane.ours[tier] end
            local first, across = lane.ours[1], lane.theirs[1]
            if first and across and lane.name == "top" then
                route[#route + 1] = { x = math.min(first.x, across.x), y = math.max(first.y, across.y) }
            elseif first and across and lane.name == "bot" then
                route[#route + 1] = { x = math.max(first.x, across.x), y = math.min(first.y, across.y) }
            end
            if lane.name == "mid" or not first or not across then route[#route + 1] = DATA.LANES[lane.name] end
            for tier = 1, 3 do route[#route + 1] = lane.theirs[tier] end
            route[#route + 1] = enemyAncient
        end
        local function assign(rows, friendly)
            for _, u in ipairs(rows or {}) do
                if U.isLaneCreep(u) and u.alive ~= false then
                    local bestLane, closest, progress = nil, 1150, 0
                    for _, lane in ipairs(lanes) do
                        local walked = 0
                        for i = 2, #lane.route do
                            local a, b = lane.route[i - 1], lane.route[i]
                            local dx, dy = b.x - a.x, b.y - a.y
                            local length = math.sqrt(dx * dx + dy * dy)
                            if length > 1 then
                                local along = math.max(0, math.min(length, ((u.pos.x - a.x) * dx + (u.pos.y - a.y) * dy) / length))
                                local distance = U.dist(u.pos, { x = a.x + dx * along / length, y = a.y + dy * along / length })
                                if distance < closest then bestLane, closest, progress = lane, distance, walked + along end
                            end
                            walked = walked + length
                        end
                    end
                    if bestLane then
                        local wave = friendly and bestLane.allies or bestLane.enemies
                        wave[#wave + 1] = u
                        if friendly and (not bestLane.front or progress > bestLane.frontAt) then
                            bestLane.front, bestLane.frontAt = u, progress
                        end
                    end
                end
            end
        end
        assign(snapshot.allies, true)
        assign(snapshot.enemies, false)
        return lanes
    end

    function MACRO.siegeTarget(snapshot, lane, ancient)
        local function findBuilding(pos, radius, pred)
            return U.nearest(snapshot.enemies, pos, radius, pred)
        end
        for tier = 1, 3 do
            local pos = lane.theirs[tier]
            if pos and not MEM.clearedTowers[lane.name .. tier] then
                return pos, tier, findBuilding(pos, 450, function(u)
                    return u.kind == "tower" and u.tier == tier and u.lane == lane.name
                end)
            end
        end

        local entrance = lane.theirs[3] or ancient
        local barracks = findBuilding(entrance, 1050, function(u)
            return u.kind == "barracks" and u.lane == lane.name
        end)
        if barracks then return barracks.pos, 3, barracks end
        local tierFour = findBuilding(entrance, 2600, function(u) return u.kind == "tower" and u.tier == 4 end)
        if tierFour then return tierFour.pos, 4, tierFour end
        local throne = findBuilding(ancient, 600, function(u) return u.kind == "ancient" end)
        if throne and not throne.invulnerable then return throne.pos, 5, throne end
        if (snapshot.scoreboard or {}).enemyTierFours == 0 then return ancient, 5, throne end
        return U.towards(entrance, ancient, 650), 4
    end

    function MACRO.pickNextPushTarget(snapshot, aliveGroup, situation, cleanPush)
        local own = U.findPin(snapshot, "ancient", function(p) return p.mapTeam == snapshot.team end)
        local enemy = U.findPin(snapshot, "ancient", function(p) return p.mapTeam == snapshot.enemyTeam end)
        if not own or not enemy then return nil end

        local best, bestScore = nil, math.huge
        for _, lane in ipairs(MACRO.siegeLanes(snapshot, own.pos, enemy.pos)) do
            if not cleanPush or not MEM.cleanPushLane or lane.name == MEM.cleanPushLane then
                local pos, tier, building = MACRO.siegeTarget(snapshot, lane, enemy.pos)
                local waveDistance = lane.front and U.dist(lane.front.pos, pos) or 7500
                local joinDistance = 0
                for _, hero in ipairs(aliveGroup) do
                    joinDistance = joinDistance + U.dist(hero.pos, lane.front and lane.front.pos or pos)
                end
                local laneOrder = (STYLE.pushLaneOrder or {})[lane.name] or 2
                local score = waveDistance / (cleanPush and 130 or 220)
                    + joinDistance / math.max(1, #aliveGroup) / 270 + laneOrder * 3
                score = score - U.countNear(aliveGroup, pos, 2400) * 14
                if cleanPush then
                    score = score - tier * 12
                elseif tier >= 3 and not situation.attackWindow then
                    score = score + 28
                end
                if MEM.lastPushLane == lane.name and snapshot.time - (MEM.lastPushAt or -999) <= 12 then
                    score = score - 18
                end
                if score < bestScore then
                    bestScore = score
                    best = {
                        phase = "PUSH", lane = lane.name, tier = tier, pos = pos,
                        isHighGround = tier >= 3, targetBuilding = building,
                        approach = (tier >= 4 and lane.theirs[3]) or lane.theirs[tier - 1] or lane.ours[1] or own.pos,
                        pushWave = lane.front, laneCreeps = lane.allies, enemyLaneCreeps = lane.enemies,
                        cleanPush = cleanPush, ancientPos = enemy.pos,
                    }
                    if building and not building.invulnerable and not building.attackImmune then
                        best.targetId = building.id
                    end
                end
            end
        end
        return best
    end

    local BOSS_RALLY_RANGE = 3200
    local BOSS_SCOUT_RANGE = 4500
    local BOSS_SCOUT_LEAD = 90

    function MACRO.pickBossScout(snapshot, aliveGroup, kind, pin, readyAt)
        local scout, bestScore = nil, math.huge
        for _, hero in ipairs(aliveGroup) do
            local distance = U.dist(hero.pos, pin.pos)
            if hero.position >= 4 and distance < BOSS_SCOUT_RANGE
                and U.ratio(hero.hp, hero.maxHp) >= 0.60 and not hero.channeling
                and COMBAT.isSafeFromTower(snapshot, hero, pin.pos, false)
                and U.countNear(snapshot.enemies, hero.pos, 1000, U.isRealHero) == 0 then
                local ward = U.hasItem(hero, "item_ward_observer", true)
                    or U.hasItem(hero, "item_ward_dispenser", true)
                local score = distance
                if kind == "tormentor" and ward and U.itemCharges(hero, ward) > 0 and U.itemCd(hero, ward) <= 0 then
                    score = score - BOSS_SCOUT_RANGE
                end
                if score < bestScore then scout, bestScore = hero, score end
            end
        end
        if scout then
            return { kind = kind, pos = pin.pos, side = pin.side, readyAt = readyAt, scoutId = scout.id }
        end
    end

    function MACRO.canKillBoss(snapshot, kind, unit, participants, committed)
        if not unit or #participants < 2 then return false, 999 end

        local armorMult = U.armorMult(unit.armor or (kind == "roshan" and 25 or 20))
        local teamDps, tankPool, squadSafeHp = 0, 0, 0
        local coreCount, hasViableTank = 0, false

        for _, h in ipairs(participants) do
            local spa = (h.secondsPerAttack and h.secondsPerAttack > 0.15) and h.secondsPerAttack or 1.4
            local rawDps = ((h.attackDamage or 60) / spa) * armorMult
            local roleMult = (h.position == 1 and 1.38) or (h.position <= 3 and 1.25) or 1.10
            teamDps = teamDps + rawDps * roleMult

            local hp = h.hp or 0
            local maxHp = math.max(1, h.maxHp or 1)
            local armorFactor = 1 + 0.06 * math.max(0, h.armor or 0)
            local spareHp = math.max(0, hp - maxHp * 0.28)
            squadSafeHp = squadSafeHp + spareHp

            if h.position <= 3 then coreCount = coreCount + 1 end
            if h.position <= 3 or (maxHp * armorFactor >= 2200) then
                tankPool = tankPool + spareHp * armorFactor
                if hp / maxHp >= (committed and 0.34 or 0.50) and maxHp >= 1300 then
                    hasViableTank = true
                end
            end
            if U.hasItem(h, "item_satanic", true) or U.hasItem(h, "item_heart", true)
                or U.hasItem(h, "item_crimson_guard", true) or U.hasItem(h, "item_mask_of_madness", true)
                or h.name == "npc_dota_hero_ursa" or h.name == "npc_dota_hero_huskar"
                or h.name == "npc_dota_hero_life_stealer" or h.name == "npc_dota_hero_troll_warlord" then
                tankPool = tankPool + 2200
                if hp / maxHp >= 0.35 then hasViableTank = true end
            end
        end

        if coreCount == 0 then return false, 999 end

        if kind == "roshan" then
            if not hasViableTank then return false, 999 end
            local remHp = unit.hp or 8000
            local ttk = remHp / math.max(1, teamDps)
            local maxTtk = committed and 85 or 68
            if ttk > maxTtk then return false, ttk end

            local roshSpa = (unit.secondsPerAttack and unit.secondsPerAttack > 0.3) and unit.secondsPerAttack or 1.0
            local roshRawDps = ((unit.attackDamage or 115) / roshSpa) * 1.15
            local expectedDmg = roshRawDps * ttk
            local surviveMult = committed and (U.ratio(remHp, unit.maxHp) <= 0.30 and 0.35 or 0.48) or 0.65
            return tankPool >= expectedDmg * surviveMult, ttk
        else
            -- Терзатель: реген щита + магический рефлект-урон делится поровну между всеми бьющими рядом
            local sched = snapshot.schedule and snapshot.schedule.tormentor
            local tKills = (sched and sched.lastKilledAt) and 1 or 0
            local shieldRegen = 100 + tKills * 35
            local netDps = teamDps - shieldRegen
            local minNetDps = committed and 110 or 165
            if netDps < minNetDps then return false, 999 end

            local hpRatio = U.ratio(unit.hp, unit.maxHp)
            local effBossHp = (unit.hp or 2500) + (2500 + tKills * 500) * math.max(0.25, hpRatio)
            local ttk = effBossHp / netDps
            if ttk > (committed and 45 or 32) then return false, ttk end

            -- Отражённый магический урон после базового 25% маг. резиста делится на число участников
            local totalReflected = effBossHp * 0.68
            local perHeroDmg = totalReflected / math.max(1, #participants)
            local avgSafeHp = squadSafeHp / math.max(1, #participants)
            local needPerHero = committed and 0.65 or 0.90
            return avgSafeHp >= perHeroDmg * needPerHero, ttk
        end
    end

    function MACRO.pickBoss(snapshot, aliveGroup, hasAegis)
        local now = snapshot.time
        local sched = snapshot.schedule or {}
        MEM.bossAbortUntil = MEM.bossAbortUntil or {}

        -- При активном убийстве босса учитываем всех живых героев с ХП >= 28%, чтобы не бросать из-за просадки до 44%
        local allAlive = {}
        for _, h in ipairs(snapshot.heroes or {}) do
            if h.alive then allAlive[#allAlive + 1] = h end
        end

        local bosses = {
            {
                kind = "tormentor",
                minTime = STYLE.tormentorMinTime,
                spawnAt = (sched.tormentor and sched.tormentor.nextAt) or 900,
                need = STYLE.tormentorMinAlive,
            },
            {
                kind = "roshan",
                minTime = STYLE.roshanMinTime,
                spawnAt = (sched.roshan and (sched.roshan.minRespawnAt or sched.roshan.maxRespawnAt)) or 0,
                need = STYLE.roshanMinAlive,
            },
        }

        local scoutPlan
        for _, boss in ipairs(bosses) do
            local commit = MEM.bossCommit
            local isCommitted = commit and commit.kind == boss.kind and now < commit.untilAt
            local pool = isCommitted and allAlive or aliveGroup

            if #pool >= boss.need and (boss.kind ~= "roshan" or not hasAegis)
                and (isCommitted or now >= (MEM.bossAbortUntil[boss.kind] or 0)) then
                local readyAt = math.max(boss.minTime, boss.spawnAt)
                local unit = U.nearest(snapshot.neutrals, DATA.LANES.mid, nil, function(row)
                    return row.kind == boss.kind
                end)

                -- Для Рошана привязываем его к ближайшему логову (не бьём, если он идёт между логовами)
                local pitPin = unit and boss.kind == "roshan" and U.nearest(snapshot.pins, unit.pos, 1400, function(p)
                    return p.kind == "roshan"
                end)
                local pitPos = (pitPin and pitPin.pos) or (unit and unit.pos)
                local roshInArea = (boss.kind ~= "roshan") or (pitPin ~= nil and U.dist(unit.pos, pitPos) <= 950)

                if unit and roshInArea and now >= boss.minTime and not unit.invulnerable and not unit.attackImmune then
                    local minHpJoin = isCommitted and 0.28 or 0.52
                    local function ready(h)
                        return h.alive and U.ratio(h.hp, h.maxHp) >= minHpJoin
                            and (not (MEM.heroes[h.position] and MEM.heroes[h.position].recoveryFarm)
                                or (h.level or 1) >= 12 or isCommitted)
                    end

                    local rallyRange = isCommitted and (BOSS_RALLY_RANGE + 800) or BOSS_RALLY_RANGE
                    local participants, onSiteList = {}, {}
                    local onSiteDist = boss.kind == "tormentor" and 950 or 1250
                    for _, h in ipairs(pool) do
                        if ready(h) then
                            local d = U.dist(h.pos, pitPos)
                            if d <= rallyRange then
                                participants[#participants + 1] = h
                                if d <= onSiteDist then onSiteList[#onSiteList + 1] = h end
                            end
                        end
                    end

                    local enemies = U.countNear(snapshot.enemies, pitPos, 1800, U.isRealHero)
                    -- Для Терзателя стараемся собрать максимум доступных рядом (4+ если есть), чтобы делить рефлект
                    local needTotal = boss.kind == "tormentor" and math.max(boss.need, math.min(4, #pool)) or boss.need
                    local needOnSite = boss.kind == "tormentor"
                        and math.min(#participants, math.max(boss.need, math.min(4, #pool)))
                        or boss.need

                    local killable = (#participants >= needTotal)
                        and MACRO.canKillBoss(snapshot, boss.kind, unit, participants, isCommitted)

                    local holding = isCommitted and commit.id == unit.id and #onSiteList >= math.max(2, boss.need - 1)
                    local assembling = #participants >= needTotal and (#onSiteList >= 1 or holding)

                    if enemies == 0 and killable and (assembling or holding) then
                        -- Выбираем и ротируем танка для Рошана
                        local tank, tankEngaged = nil, false
                        if boss.kind == "roshan" then
                            local curTank
                            if commit and commit.id == unit.id and commit.tankId then
                                for _, h in ipairs(participants) do
                                    if h.id == commit.tankId and U.dist(h.pos, pitPos) <= 750 then
                                        curTank = h; break
                                    end
                                end
                            end

                            local curTankHp = curTank and U.ratio(curTank.hp, curTank.maxHp) or 0
                            local keepThreshold = (curTank and (curTank.hasAegis or curTank.satanicActive)) and 0.26 or 0.38
                            if curTank and curTank.position <= 3 and curTankHp >= keepThreshold then
                                tank = curTank
                            else
                                local bestScore = -math.huge
                                for _, h in ipairs(participants) do
                                    local hHp = U.ratio(h.hp, h.maxHp)
                                    local swapBonus = (curTank and h.id ~= curTank.id and hHp >= 0.50) and 900 or 0
                                    local nearBonus = (U.dist(h.pos, pitPos) <= 750) and 400 or 0
                                    local s = COMBAT.roshanTankScore(h) + swapBonus + nearBonus
                                    if s > bestScore then tank, bestScore = h, s end
                                end
                            end

                            if tank then
                                local tankInPit = U.dist(tank.pos, pitPos) <= ROSHAN_PIT_RADIUS
                                    and U.dist(tank.pos, unit.pos) <= math.max(260, (tank.attackRange or 150) + 70)
                                tankEngaged = (unit.aggroTargetId == tank.id)
                                    or (tankInPit and U.ratio(unit.hp, unit.maxHp) < 0.995
                                        and (unit.aggroTargetId == nil or unit.aggroTargetId == tank.id))
                            end
                        end

                        local readyToAttack = (#onSiteList >= needOnSite)
                            or (holding and (boss.kind == "roshan" or #onSiteList >= math.max(3, boss.need)))
                        if readyToAttack or holding then
                            -- Обновляем окно коммита, пока босс бьётся (Рошана можно бить ~1 минуту)
                            MEM.bossCommit = {
                                id = unit.id,
                                kind = boss.kind,
                                tankId = tank and tank.id or nil,
                                startedAt = (commit and commit.id == unit.id and commit.startedAt) or now,
                                untilAt = now + 25,
                            }
                        end

                        local phase = string.upper(boss.kind)
                        return {
                            phase = phase,
                            label = phase,
                            kind = boss.kind,
                            pos = pitPos,
                            pitPos = pitPos,
                            targetId = unit.id,
                            targetUnit = unit,
                            tankId = tank and tank.id or nil,
                            tankEngaged = tankEngaged,
                            readyToAttack = readyToAttack,
                            rallyRange = rallyRange,
                            aliveCount = #pool,
                        }
                    else
                        if isCommitted and commit.id == unit.id then
                            -- Команда не осилила или пришли враги — сбрасываем коммит и ставим паузу 40 сек
                            MEM.bossCommit = nil
                            MEM.bossAbortUntil[boss.kind] = now + 40
                        end
                        local unitSide = unit.pos.y > 0 and "top" or "bot"
                        MEM.bossScoutAfter[boss.kind][unitSide] = now + 75
                    end
                elseif not unit and not scoutPlan and now >= readyAt - BOSS_SCOUT_LEAD then
                    local isDay = snapshot.isDay == true
                    if now < readyAt and isDay == (math.floor(now / 300) % 2 == 0) then
                        isDay = math.floor(readyAt / 300) % 2 == 0
                    end
                    local side = isDay and "bot" or "top"
                    if boss.kind == "roshan" then
                        side = isDay and "top" or "bot"
                    end
                    local pin = U.findPin(snapshot, boss.kind, function(p) return p.side == side end)
                    local scoutAfter = MEM.bossScoutAfter[boss.kind]
                    if pin and pin.visible then
                        scoutAfter[side] = math.max(readyAt, now + 60)
                    elseif pin and not pin.visible and now >= (scoutAfter[side] or 0)
                        and U.countNear(aliveGroup, pin.pos, BOSS_RALLY_RANGE + 1200) >= boss.need
                        and U.countNear(snapshot.enemies, pin.pos, 1800, U.isRealHero) == 0 then
                        scoutPlan = MACRO.pickBossScout(snapshot, aliveGroup, boss.kind, pin, readyAt)
                    end
                end
            end
        end
        return nil, scoutPlan
    end

    function MACRO.recoveryFarm(snapshot, actor, st)
        local goal = heroStyle(actor).recoveryFarmSlots
        if actor.position ~= 1 or type(goal) ~= "number" or goal < 1 then
            st.recoveryFarm = false
            return false
        end
        local majorItems = 0
        for slot, cost in pairs(actor.itemCosts or {}) do
            local name = actor.items and actor.items[slot]
            if name and cost >= 2200 and not RECOVERY_COMPONENTS[name] and not name:find("^item_recipe_") then
                majorItems = majorItems + 1
            end
        end

        local hasBkb = U.hasItem(actor, "item_black_king_bar", true) ~= nil
        local hasAegis = U.hasItem(actor, "item_aegis", true) ~= nil or actor.hasAegis == true
        local readyByItems = majorItems >= goal
            or (hasBkb and majorItems >= 2)
            or (snapshot.time >= 2100 and majorItems >= 2)
            or hasAegis

        local score = snapshot.scoreboard or {}
        local killGap = (score.enemyKills or 0) - (score.allyKills or 0)
        local levelGap = (score.enemyAvgLevel or 0) - (score.allyAvgLevel or 0)
        local towerGap = (score.enemyTowersLeft or 0) - (score.allyTowersLeft or 0)

        local caughtUp = (killGap <= 2 and levelGap < 0.5 and towerGap < 2)
            or (levelGap <= 0 and killGap <= 4)

        if readyByItems or caughtUp then
            st.recoveryFarm = false
        elseif snapshot.time >= 720 and (killGap >= 7 or (killGap >= 4 and (levelGap >= 0.75 or towerGap >= 2))) then
            st.recoveryFarm = true
        end
        return st.recoveryFarm == true
    end

    function MACRO.pickRecoveryFight(snapshot, actor, st, basePos)
        if not actor.alive or actor.disarmed or st.retreat then return nil end

        local style = heroStyle(actor)
        local hp = U.ratio(actor.hp, actor.maxHp)
        local onFountain = U.dist(actor.pos, basePos) <= 1050
        local minHp = onFountain and 0.72 or math.max(0.55, style.fightMinHp + 0.15)
        if hp < minHp then return nil end

        local now = snapshot.time
        local enemyDead = (snapshot.scoreboard and snapshot.scoreboard.enemyDeadCount) or 0
        local enemiesAlive = math.max(0, 5 - enemyDead)
        local tp = INV.getTpState(actor)
        local canTp = enemyDead >= 1 and tp.ready and (st.tpRetryAt or 0) <= now
            and U.countNear(snapshot.enemies, actor.pos, 950, U.isRealHero) == 0

        local visibleIds = {}
        for _, e in ipairs(snapshot.enemies or {}) do
            if U.isRealHero(e) and e.alive ~= false then visibleIds[e.id] = true end
        end

        local best, bestScore = nil, -math.huge
        for _, enemy in ipairs(snapshot.enemies or {}) do
            if COMBAT.canRightClick(enemy) then
                -- Считаем видимых врагов, недавно скрывшихся в тумане и прилетающие вражеские ТП
                local visibleHostiles = U.countNear(snapshot.enemies, enemy.pos, 1550, U.isRealHero)
                local hiddenHostiles = 0
                for eid, rec in pairs(snapshot.enemyLastSeen or {}) do
                    if not visibleIds[eid] and (now - rec.at) <= 5.0
                        and U.ratio(rec.hp, rec.maxHp) >= 0.18
                        and U.dist(rec.pos, enemy.pos) <= 1650 then
                        hiddenHostiles = hiddenHostiles + 1
                    end
                end
                local incomingEnemyTps = 0
                local incomingAllyTps = 0
                for _, arrival in ipairs(snapshot.teleports or {}) do
                    if arrival.heroId ~= actor.id and U.dist(arrival.pos, enemy.pos) <= 1450 then
                        if arrival.team == snapshot.team then
                            incomingAllyTps = incomingAllyTps + 1
                        else
                            incomingEnemyTps = incomingEnemyTps + 1
                        end
                    end
                end
                local totalHostiles = math.min(enemiesAlive, visibleHostiles + hiddenHostiles + incomingEnemyTps)
                totalHostiles = math.max(visibleHostiles, totalHostiles)

                -- Считаем только живых и боеспособных союзников (HP >= 40%), реально участвующих в драке
                local readyAllies, healthySingleAlly, engagedAlly = 0, false, false
                local allyDamaged = false
                for _, h in ipairs(snapshot.heroes or {}) do
                    if h.alive and h.id ~= actor.id then
                        local d = U.dist(h.pos, enemy.pos)
                        local aHp = U.ratio(h.hp, h.maxHp)
                        if d <= 1350 and aHp >= 0.40 then
                            readyAllies = readyAllies + 1
                            if aHp >= 0.50 then healthySingleAlly = true end
                        end
                        if d <= 1050 then
                            engagedAlly = true
                            if aHp < 0.90 then allyDamaged = true end
                        end
                    end
                end
                readyAllies = readyAllies + incomingAllyTps

                -- Анти-1v4: в бою есть боеспособные союзники, и с учётом керри мы не в меньшинстве
                local safeNumbers = readyAllies >= 1
                    and (readyAllies + 1 >= totalHostiles)
                    and (totalHostiles <= 2 or readyAllies >= 2)
                    and (totalHostiles ~= 2 or readyAllies >= 2 or healthySingleAlly)

                if engagedAlly and safeNumbers then
                    local distToFight = U.dist(actor.pos, enemy.pos)
                    local tower = U.nearest(snapshot.allies, enemy.pos, 1600, function(u)
                        return u.kind == "tower" and u.alive ~= false
                    end)
                    local activeSkirmish = allyDamaged or U.ratio(enemy.hp, enemy.maxHp) < 0.90
                        or (tower ~= nil and U.dist(tower.pos, enemy.pos) <= 1100)

                    if activeSkirmish then
                        -- Вариант 1: бой рядом (добегаем пешком)
                        local nearbyOk = distToFight <= 2200
                            and (enemyDead >= 1 or (distToFight <= 1650 and readyAllies + 1 > totalHostiles))
                            and (COMBAT.isSafeFromTower(snapshot, actor, enemy.pos, false) or readyAllies >= 2)

                        -- Вариант 2: бой у союзной вышки + мёртв >= 1 враг (прилетаем на ТП за вышку)
                        local tpOk = not nearbyOk and canTp and tower ~= nil
                            and distToFight > 2000 and U.dist(actor.pos, tower.pos) > 2000

                        if nearbyOk or tpOk then
                            local score = (readyAllies + 1 - totalHostiles) * 80
                                + (1 - U.ratio(enemy.hp, enemy.maxHp)) * 60
                                + (nearbyOk and 120 or 0)
                                - distToFight * 0.02
                            if score > bestScore then
                                bestScore = score
                                best = {
                                    mode = nearbyOk and "nearby" or "tp",
                                    target = enemy,
                                    pos = enemy.pos,
                                    tpPos = tpOk and U.towards(tower.pos, basePos, 240) or nil,
                                }
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    function MACRO.applyDirective(macro, dir)
        if not dir or macro.phase == "DEFEND" or macro.cleanPush or macro.regroup then return macro end

        if dir.kind == "WAIT_ITEM" or dir.kind == "WAIT_ULT" then
            if macro.phase == "PUSH" and not (macro.situation and (macro.situation.enemyDead or 0) >= 3) then
                macro = {
                    phase = "LANING",
                    label = dir.label,
                    aliveCount = macro.aliveCount,
                    situation = macro.situation,
                    bossPlan = macro.bossPlan,
                    heroGoals = macro.heroGoals,
                }
            end
        elseif dir.kind == "HELP_GANK" and dir.pos and dir.assignedIds then
            macro.heroGoals = macro.heroGoals or {}
            for id, assigned in pairs(dir.assignedIds) do
                if assigned then
                    macro.heroGoals[id] = { mode = "gank", pos = dir.pos, status = "Иду на ганг (по коллу)" }
                end
            end
            if not macro.label then macro.label = dir.label end
        elseif dir.kind == "GO_FIGHT" and not macro.label then
            macro.label = dir.label
        end
        if dir.kind == "NEED_WARDS" or dir.forceWard then macro.forceWard = true end
        return macro
    end

    function MACRO.build(snapshot)
        local now = snapshot.time
        local aliveGroup = {}
        local hasAegis = false
        local aliveCount = 0
        for _, h in ipairs(snapshot.heroes or {}) do
            if h.alive then
                aliveCount = aliveCount + 1
                if U.ratio(h.hp, h.maxHp) >= 0.45 then
                    aliveGroup[#aliveGroup + 1] = h
                end
                if U.hasItem(h, "item_aegis") or h.hasAegis then hasAegis = true end
            end
        end

        MACRO.updateTowerMemory(snapshot, aliveGroup)

        local enemyDead = (snapshot.scoreboard or {}).enemyDeadCount or 0
        local cleanPush = enemyDead >= 4 and #aliveGroup >= 1
        local regroup = aliveCount <= 3 and (5 - enemyDead) >= aliveCount + 2
        if not cleanPush then MEM.cleanPushLane = nil end
        local defaultMacro

        if now < 8 then
            defaultMacro = { phase = "BOUNTY_START", aliveCount = #aliveGroup }
        else
            local threatened, bestPrio, urgent, localOnly = nil, -1, false, false
            for _, ally in ipairs(snapshot.allies or {}) do
                if ally.underAttack and U.isBuilding(ally) then
                    local enemyHeroesNear = U.countNear(snapshot.enemies, ally.pos, 1400, U.isRealHero)
                    local enemyCreepsNear = U.countNear(snapshot.enemies, ally.pos, 1000, U.isLaneCreep)
                    if enemyHeroesNear > 0 or enemyCreepsNear >= 2 or ally.kind == "ancient" or ally.kind == "barracks" then
                        local tier = ally.tier or 1
                        local hp = U.ratio(ally.hp, ally.maxHp)
                        local baseThreat = ally.kind == "ancient" or ally.kind == "barracks" or tier >= 3
                        local committedPush = enemyHeroesNear >= 3 and (enemyCreepsNear >= 2 or hp <= 0.55)
                        local threatenedTierTwo = tier == 2 and enemyHeroesNear >= 2 and hp <= 0.45
                        local fullDefense = now >= 600 or baseThreat or committedPush or threatenedTierTwo
                        local prio = (ally.kind == "ancient" and 100)
                            or (ally.kind == "barracks" and 80)
                            or (tier * 20)
                        prio = prio + enemyHeroesNear * 15 + (fullDefense and 100 or 0)
                        if prio > bestPrio then
                            threatened, bestPrio = ally, prio
                            urgent, localOnly = baseThreat, not fullDefense
                        end
                    end
                end
            end

            if threatened and (urgent or (not cleanPush and not regroup)) then
                local enemyNear = not localOnly and U.nearest(snapshot.enemies, threatened.pos, 1500, U.isRealHero)
                defaultMacro = {
                    phase = "DEFEND",
                    label = urgent and "DEFEND BASE!" or (localOnly and "DEFEND TOWER (LOCAL)" or "DEFEND TOWER"),
                    pos = enemyNear and enemyNear.pos or threatened.pos,
                    building = threatened,
                    urgent = urgent,
                    localOnly = localOnly,
                    aliveCount = #aliveGroup,
                    regroup = regroup,
                }
            elseif regroup then
                defaultMacro = { phase = "LANING", label = "FARM / WAIT RESPAWNS", aliveCount = aliveCount, regroup = true }
            elseif now < STYLE.laningEndTime then
                defaultMacro = { phase = "LANING", aliveCount = #aliveGroup }
            else
                local bossMacro, scoutPlan
                if not cleanPush then bossMacro, scoutPlan = MACRO.pickBoss(snapshot, aliveGroup, hasAegis) end
                defaultMacro = bossMacro

                local situation = MACRO.assessSituation(snapshot, aliveGroup)
                if not defaultMacro then
                    local push = MACRO.pickNextPushTarget(snapshot, aliveGroup, situation, cleanPush)
                    local isHighGround = push and push.isHighGround
                    local endgame = now >= STYLE.endgamePushTime
                    local needForPush = isHighGround
                        and ((hasAegis or endgame or situation.enemyDead >= 2) and STYLE.hgAegisMinAlive or STYLE.hgMinAlive)
                        or (situation.attackWindow and math.max(2, STYLE.pushMinAlive - 1) or STYLE.pushMinAlive)

                    -- Проверяем, стоит ли сейчас пушить или лучше пофармить и поставить вижен
                    local nearTargetNow = push and U.countNear(aliveGroup, push.pos, 2200) or 0
                    local freeLocalPush = push and not isHighGround and nearTargetNow >= 2
                        and U.countNear(push.laneCreeps, push.pos, 1100, U.isLaneCreep) >= 2
                        and U.countNear(snapshot.enemies, push.pos, 1500, U.isRealHero) <= nearTargetNow

                    local allowPush = push and (cleanPush or freeLocalPush
                        or (#aliveGroup >= needForPush and (not situation.shouldFarm or endgame)))
                    if allowPush then
                        local reason = ""
                        if situation.enemyDead >= 2 then
                            reason = " (ENEMIES DEAD)"
                        elseif situation.enemyUltsDown >= 2 or situation.enemyBkbDown >= 1 then
                            reason = " (ENEMY CD DOWN)"
                        elseif freeLocalPush then
                            reason = " (NEAREST)"
                        end
                        push.label = "PUSH " .. string.upper(push.lane) .. reason
                        push.aliveCount, push.situation = #aliveGroup, situation
                        if MEM.lastPushLane ~= push.lane then
                            MEM.lastPushLane, MEM.lastPushAt = push.lane, now
                        end
                        if cleanPush then MEM.cleanPushLane = push.lane end
                        defaultMacro = push
                    else
                        local farmLabel
                        if situation.teamReady.ultsMissing and not situation.ultsReadyOrComing then
                            farmLabel = string.format("FARM / WAIT ULTS (%ds)", math.ceil(situation.teamReady.minUltCd))
                        elseif situation.posture == "LOSING" then
                            farmLabel = "FARM & DEF VISION"
                        else
                            farmLabel = "FARM & MAP VISION"
                        end
                        defaultMacro = {
                            phase = "LANING",
                            label = farmLabel,
                            aliveCount = #aliveGroup,
                            situation = situation,
                        }
                    end
                else
                    defaultMacro.situation = situation
                end
                defaultMacro.bossPlan = scoutPlan
            end
        end

        defaultMacro = MACRO.applyDirective(defaultMacro, MEM.comms.directive)

        local customMacro = safeHook(tactic.PlanMacro, snapshot, defaultMacro)
        if type(customMacro) == "table" and type(customMacro.phase) == "string" then
            return customMacro
        end
        return defaultMacro
    end

    -- ========================================================================
    -- LANE: Баунти, варды, объекты, макро-движение, лайнинг и фарм
    -- ========================================================================
    local LANE = {}

    function LANE.getPreGamePlan(snapshot, basePos)
        if MEM.preGamePlan then return MEM.preGamePlan end
        -- Выбираем план один раз за матч: инвейд под смоком или безопасный разбор баунти
        local mode = STYLE.preGameMode or "auto"
        local hasSmoke = false
        for _, h in ipairs(snapshot.heroes or {}) do
            if U.hasItem(h, "item_smoke_of_deceit", true) then hasSmoke = true; break end
        end
        local doInvade = false
        if mode == "smoke_invade" then
            doInvade = true
        elseif mode == "auto" and hasSmoke and STYLE.bountyFight ~= false then
            doInvade = (math.random() < (STYLE.preGameSmokeChance or 0.45))
        end

        local enemyBounty = U.findPin(snapshot, "bounty", function(p) return p.mapTeam == snapshot.enemyTeam end)
        local ownBounty = U.findPin(snapshot, "bounty", function(p) return p.mapTeam == snapshot.team end)
        local invadePos = enemyBounty and enemyBounty.pos or DATA.LANES.mid
        local rallyPos = U.towards(invadePos, basePos, 2100)

        -- Кто идёт в инвейд: оффлейн-дуо (3, 4) + 5-ка + керри (если он не слишком далеко)
        local invadePosSet = { [1] = true, [3] = true, [4] = true, [5] = true }

        MEM.preGamePlan = {
            kind = (doInvade and enemyBounty) and "SMOKE_INVADE" or "SAFE_BOUNTY",
            invadePos = invadePos,
            rallyPos = rallyPos,
            ownBountyPos = ownBounty and ownBounty.pos or nil,
            invadeMembers = invadePosSet,
            smokePopped = false,
            aborted = false,
        }
        return MEM.preGamePlan
    end

    -- Возврат под свою T1 и ожидание/сопровождение первой волны крипов на ЛЮБОЙ линии
    function LANE.waitForFirstWave(snapshot, actor, basePos)
        local lane = actor.lane or "mid"
        local laneCenter = DATA.LANES[lane] or DATA.LANES.mid

        -- Если наши крипы уже вышли на эту линию (после 0:00) — идём за передним крипом на линию
        local t1Pin = U.findPin(snapshot, "tower", function(p)
            return p.mapTeam == snapshot.team and p.lane == lane and p.tier == 1
        end)
        local frontAlly = U.nearest(snapshot.allies, laneCenter, 5200, function(u)
            if not U.isLaneCreep(u) then return false end
            if t1Pin then
                return U.dist(u.pos, t1Pin.pos) <= 3200 or U.dist(u.pos, laneCenter) <= 2800
            end
            return U.dist(u.pos, laneCenter) <= 3500
        end)
        if frontAlly and snapshot.time >= 0 then
            local followPos = U.towards(frontAlly.pos, basePos, actor.ranged and 280 or 180)
            if COMBAT.isSafeFromTower(snapshot, actor, followPos, false) then
                return { kind = "move", position = followPos, status = "Иду с первой волной" }
            end
        end

        -- Иначе ждём безопасно за своей T1 башней
        local waitPos = t1Pin and U.towards(t1Pin.pos, basePos, 260) or U.towards(laneCenter, basePos, 1100)
        if U.countNear(snapshot.enemies, waitPos, 700, U.isRealHero) > 0 then
            waitPos = U.towards(waitPos, basePos, 420)
        end
        if U.dist(actor.pos, waitPos) > 150 then
            return { kind = "move", position = waitPos, status = "Жду первую волну у T1" }
        end
        return { kind = "hold", status = "Жду первую волну у T1" }
    end

    function LANE.decidePreGame(snapshot, actor, enemy, enemyCount, allyCount, basePos)
        local now = snapshot.time
        local hp = U.ratio(actor.hp, actor.maxHp)
        local plan = LANE.getPreGamePlan(snapshot, basePos)

        -- Даём героям 4 секунды в самом начале на стартовый закуп у фонтана
        if now < -75 and U.dist(actor.pos, basePos) < 900 then
            return { kind = "hold", status = "Закупаюсь на старт" }
        end

        -- Если герой уже завершил пре-гейм (или наступила 0:06 без драки) — возвращаемся под T1 к крипам
        if MEM.preGameDone[actor.id] or (now >= 6 and (not enemy or U.dist(actor.pos, enemy.pos) > 850)) then
            MEM.preGameDone[actor.id] = true
            return LANE.waitForFirstWave(snapshot, actor, basePos)
        end

        -- Мидер всегда играет осторожно: берёт безопасную свою баунти, если рядом, иначе ждёт у Mid T1
        if actor.position == 2 and actor.lane == "mid" then
            if now >= -0.3 and now < 5 then
                local rune = U.nearest(snapshot.runes, actor.pos, 1150, function(r)
                    return U.countNear(snapshot.enemies, r.pos, 1000, U.isRealHero) == 0
                end)
                if rune then return { kind = "rune", target_id = rune.id, status = "Беру безопасную Баунти" } end
            end
            if now >= -25 and now < 2 and plan.ownBountyPos
                and U.dist(plan.ownBountyPos, DATA.LANES.mid) <= 2400
                and U.countNear(snapshot.enemies, plan.ownBountyPos, 1100, U.isRealHero) == 0 then
                return { kind = "move", position = plan.ownBountyPos, status = "Контролю свою Баунти" }
            end
            MEM.preGameDone[actor.id] = (now >= 2)
            return LANE.waitForFirstWave(snapshot, actor, basePos)
        end

        -- 1. Проверка драки / First Blood в пре-гейме
        if STYLE.bountyFight ~= false and enemy and U.dist(actor.pos, enemy.pos) <= 1050 then
            local safeT = COMBAT.isSafeFromTower(snapshot, actor, enemy.pos, false)
            if allyCount + 1 >= enemyCount and hp > 0.35 and safeT then
                return { kind = "attack", target_id = enemy.id, status = "Ганг за First Blood!" }
            else
                MEM.preGameDone[actor.id] = true
                return { kind = "move", position = U.towards(actor.pos, basePos, 650), status = "Отход от невыгодной драки" }
            end
        end

        -- 2. Подбор любой видимой руны после 0:00
        if now >= -0.3 then
            local rune = U.nearest(snapshot.runes, actor.pos, 1250, function(r)
                return COMBAT.isSafeFromTower(snapshot, actor, r.pos, false)
            end)
            if rune then
                return { kind = "rune", target_id = rune.id, status = "Забираю Баунти!" }
            end
        end

        -- 3. Сценарий A: Командный SMOKE INVADE на вражескую баунти-руну
        if plan.kind == "SMOKE_INVADE" and not plan.aborted and plan.invadeMembers[actor.position] then
            if actor.smoked then plan.smokePopped = true end

            -- Если пришли на вражескую баунти после 0:01, а там пусто и врагов нет — сразу отходим на свою линию
            if now >= 1.5 and U.dist(actor.pos, plan.invadePos) <= 650 and enemyCount == 0 then
                plan.aborted = true
                MEM.preGameDone[actor.id] = true
                return LANE.waitForFirstWave(snapshot, actor, basePos)
            end

            -- Сбор на точке и прожатие Smoke of Deceit (Pos 4)
            if not plan.smokePopped and now < -12 then
                local squadNear = U.countNear(snapshot.heroes, plan.rallyPos, 850, function(h)
                    return h.alive and plan.invadeMembers[h.position]
                end)
                local sSlot = U.hasItem(actor, "item_smoke_of_deceit", true)
                if sSlot and U.itemCd(actor, sSlot) <= 0 and squadNear >= 3
                    and U.dist(actor.pos, plan.rallyPos) <= 600 then
                    plan.smokePopped = true
                    MEM.lastSmokeAt = now
                    return { kind = "smoke", status = "Жму Smoke на инвейд!" }
                end
                if squadNear < 3 and now < -25 then
                    return { kind = "move", position = plan.rallyPos, status = "Собираюсь под Smoke" }
                end
            end

            return { kind = "move", position = plan.invadePos, status = "Инвейд на вражескую Баунти!" }
        end

        -- 4. Сценарий B: SAFE_BOUNTY — разбор своей лесной баунти и речной руны своей стороны
        local targetPin
        local isRadiant = (basePos.x + basePos.y) < 0
        local isSafeLane = (isRadiant and actor.lane == "bot")
            or ((not isRadiant) and actor.lane == "top")
        if isSafeLane then
            targetPin = U.findPin(snapshot, "bounty", function(p) return p.mapTeam == snapshot.team end)
        else
            targetPin = U.findPin(snapshot, "power", function(p) return p.side == actor.lane end)
                or U.findPin(snapshot, "bounty", function(p) return p.mapTeam == snapshot.team end)
        end

        if targetPin then
            -- Если после 0:01 точка видна, а руны уже нет — возвращаемся под башню ждать волну
            if now >= 1.2 and targetPin.visible and not U.nearest(snapshot.runes, targetPin.pos, 450) then
                MEM.preGameDone[actor.id] = true
                return LANE.waitForFirstWave(snapshot, actor, basePos)
            end
            if U.dist(actor.pos, targetPin.pos) > 220 then
                return { kind = "move", position = targetPin.pos, status = "Иду на Баунти руну" }
            end
            return { kind = "hold", status = "Жду спавн Баунти" }
        end

        return LANE.waitForFirstWave(snapshot, actor, basePos)
    end

    function LANE.decideObserver(snapshot, actor, st, macro, scoutPlan, stock)
        local now = snapshot.time
        local early = now < STYLE.laningEndTime
        local situation = macro.situation
        local posture = situation and situation.posture or "EVEN"
        local roamingVision = (not early) and (not scoutPlan) and (macro.phase == "LANING" or macro.phase == "PUSH")
        -- При проигрыше ставим деф-вижен на своей половине; при преимуществе или окне атаки — глубокий на вражеской
        local wantAggressiveWard = roamingVision and (posture == "WINNING" or (situation and situation.attackWindow) or macro.phase == "PUSH")
        local wantDefensiveWard = roamingVision and (posture == "LOSING")

        local lane = U.findPin(snapshot, "lane", function(pin)
            return pin.mapTeam == snapshot.team and pin.lane == actor.lane
        end)
        local anchor = scoutPlan and scoutPlan.pos or (macro.phase == "PUSH" and macro.pos)
            or (lane and lane.pos) or DATA.LANES[actor.lane]
        if not anchor then return nil end

        local purpose = scoutPlan and ("tormentor_" .. tostring(scoutPlan.side))
            or (wantDefensiveWard and "def_vision")
            or (wantAggressiveWard and "agg_vision")
            or "lane"
        local pending = MEM.observerOrders[actor.id]
        if pending and pending.purpose ~= purpose then
            MEM.observerOrders[actor.id], pending = nil, nil
        end
        if pending and pending.castAt and not pending.finished then
            local planted = stock < pending.stock or U.nearest(snapshot.allies, pending.spot.pos, 260, function(u)
                return u.kind == "observer_ward"
            end)
            if planted then
                st.nextObserverAt, st.lastObserverPurpose = now + 35, purpose
                pending.finished, pending.expiresAt = true, now + 2
                return nil
            end
        end
        if pending and now >= pending.expiresAt then
            MEM.observerOrders[actor.id], pending = nil, nil
            if not (now < (st.nextObserverAt or 0)) then
                st.nextObserverAt, st.lastObserverPurpose = now + 8, purpose
            end
        end
        if pending and pending.finished then return nil end
        local forceWard = macro.forceWard == true
        if now < (st.nextObserverAt or 15) and not forceWard
            and (not scoutPlan or st.lastObserverPurpose == purpose) then
            return nil
        end
        if stock <= 0 then return nil end

        local function covered(point)
            return U.nearest(snapshot.allies, point, 1250, function(u)
                return u.kind == "observer_ward" and U.dist(u.pos, point) < (u.visionRange or 1600) * 0.72
            end) ~= nil
        end
        if scoutPlan and not pending and covered(anchor) then return nil end

        local situation = macro.situation
        local posture = situation and situation.posture or "EVEN"
        local roamingVision = (not early) and (not scoutPlan) and (macro.phase == "LANING" or macro.phase == "PUSH")
        local wantAggressiveWard = roamingVision and (posture == "WINNING" or (situation and situation.attackWindow) or macro.phase == "PUSH")
        local wantDefensiveWard = roamingVision and (posture == "LOSING")

        -- Достаточный радиус для всех сайдлайнов на ранней игре и для роуминга по коллу коров
        local maxTravel = scoutPlan and 3400 or (forceWard and 4800 or (early and 2600 or 3800))
        local maxAnchorDistance = scoutPlan and 1350 or (forceWard and 7500 or (early and 2800 or 6500))
        local enemySafeRadius = forceWard and 850 or 1050

        local function eligible(spot)
            if spot.kind ~= "ward_spot" or U.dist(spot.pos, actor.pos) > maxTravel
                or U.dist(spot.pos, anchor) > maxAnchorDistance
                or (scoutPlan and spot.side ~= nil and spot.side ~= scoutPlan.side)
                or (not scoutPlan and spot.objective == "tormentor")
                or covered(spot.pos) then
                return false
            end
            if wantDefensiveWard and not forceWard and spot.mapTeam and spot.mapTeam ~= snapshot.team then
                return false
            end
            local approach = U.towards(actor.pos, spot.pos, 650)
            if COMBAT.nearestEnemyTower(snapshot, spot.pos, 930)
                or COMBAT.nearestEnemyTower(snapshot, approach, 870)
                or U.countNear(snapshot.enemies, spot.pos, enemySafeRadius, U.isRealHero) > 0
                or U.countNear(snapshot.enemies, approach, 800, U.isRealHero) > 0 then
                return false
            end
            for owner, order in pairs(MEM.observerOrders) do
                if owner ~= actor.id and now < order.expiresAt and U.dist(order.spot.pos, spot.pos) < 1250 then
                    return false
                end
            end
            return true
        end

        if pending and not eligible(pending.spot) then
            MEM.observerOrders[actor.id], pending = nil, nil
        end
        if not pending then
            local best, bestScore = nil, math.huge
            for _, spot in ipairs(snapshot.pins or {}) do
                if eligible(spot) then
                    local score = U.dist(spot.pos, actor.pos) * 0.65 + U.dist(spot.pos, anchor) * 0.35
                    if spot.visible then score = score + 100 end
                    if scoutPlan and spot.objective == "tormentor" then score = score - 220 end
                    if not early and spot.objective == "roshan" then score = score - 180 end
                    if wantAggressiveWard and spot.mapTeam == snapshot.enemyTeam then
                        score = score - 900
                    elseif wantDefensiveWard and spot.mapTeam == snapshot.team then
                        score = score - 650
                    end
                    if score < bestScore then best, bestScore = spot, score end
                end
            end
            if not best then return nil end
            local travelTime = U.dist(actor.pos, best.pos) / math.max(220, actor.moveSpeed or 300)
            pending = { spot = best, purpose = purpose, stock = stock, expiresAt = now + travelTime + 9 }
            MEM.observerOrders[actor.id] = pending
        end

        -- 490 юнитов хватает, чтобы достать клифы (z = 544) от подножия без застревания
        if U.dist(actor.pos, pending.spot.pos) > 490 then
            local moveStatus = scoutPlan and "Иду за обзором у Терзателя"
                or (forceWard and "Несу вард по коллу!")
                or (wantAggressiveWard and "Ставлю агрессивный вижен")
                or (wantDefensiveWard and "Ставлю деф-вижен")
                or "Иду ставить Observer"
            return { kind = "move", position = pending.spot.pos, status = moveStatus }
        end

        -- Если вард ещё на 6-сек КД рюкзака — ждём на месте, а не уходим
        local oMain = U.hasItem(actor, "item_ward_observer", true)
        local dMain = U.hasItem(actor, "item_ward_dispenser", true)
        local activeSlot = oMain or dMain
        if activeSlot and U.itemCd(actor, activeSlot) > 0 then
            pending.expiresAt = math.max(pending.expiresAt, now + 2.0)
            return { kind = "hold", status = "Жду КД варда" }
        end

        if not pending.castAt then pending.expiresAt = now + 4.5 end
        -- Ждём 0.45 сек между переключением dispenser и реальной установкой, удерживая позицию!
        if pending.castAt and now - pending.castAt < 0.45 then
            return { kind = "hold", status = "Ставлю Observer" }
        end
        pending.castAt = now
        return { kind = "cast", item = "item_ward_observer", position = pending.spot.pos,
            status = scoutPlan and "Ставлю Observer у Терзателя" or "Ставлю Observer" }
    end

    function LANE.decideWarding(snapshot, actor, st, threats, enemyCount, macro, defendHere)
        if enemyCount == 0 or U.ratio(actor.hp, actor.maxHp) > 0.65 then
            local eWard = U.nearest(snapshot.enemies, actor.pos, 900, function(u)
                return (u.kind == "observer_ward" or u.kind == "sentry_ward")
                    and not u.invulnerable and not u.attackImmune
            end)
            if eWard and COMBAT.isSafeFromTower(snapshot, actor, eWard.pos, false) then
                return { kind = "ward_focus", target_id = eWard.id, status = "Ломаю вард" }
            end
        end

        if actor.position < 4 or defendHere or actor.smoked then return nil end

        local forceWard = macro.forceWard == true
        local closeThreat = U.countNear(snapshot.enemies, actor.pos, forceWard and 650 or 800, U.isRealHero)
        if closeThreat > 0 then return nil end

        local now = snapshot.time
        -- Проверяем варды в основе (0..5), а если их там нет — перетаскиваем из рюкзака (6..8)
        local oSlot = U.hasItem(actor, "item_ward_observer", true)
        local dSlot = U.hasItem(actor, "item_ward_dispenser", true)
        if not oSlot and not dSlot then
            local bpWard = U.hasItem(actor, "item_ward_dispenser", false) or U.hasItem(actor, "item_ward_observer", false)
            if bpWard and bpWard >= 6 and bpWard <= 8 then
                local swapTarget, lowestVal = 5, math.huge
                for s = 0, 5 do
                    local name = (actor.items or {})[s]
                    if not name then
                        swapTarget = s
                        break
                    else
                        local v = itemVal(name)
                        if v < lowestVal then swapTarget, lowestVal = s, v end
                    end
                end
                st.wardSwapUntil = now + 12
                return { kind = "swap", slot_a = bpWard, slot_b = swapTarget, status = "Достаю вард из рюкзака" }
            end
        end

        local stock = (oSlot and math.max(1, U.itemCharges(actor, oSlot)) or 0)
            + (dSlot and U.itemCharges(actor, dSlot) or 0)
        local canSen = U.hasItem(actor, "item_ward_sentry", true) ~= nil
            or (dSlot ~= nil and U.itemSecCharges(actor, dSlot) > 0)
        local hp = U.ratio(actor.hp, actor.maxHp)
        local minHp = forceWard and 0.45 or 0.55

        local plan = macro.bossPlan
        local scoutPlan = plan and plan.kind == "tormentor" and plan.scoutId == actor.id and plan.pos
            and now >= (plan.readyAt or now) - 80 and plan
        if scoutPlan and hp >= minHp and stock > 0 then
            return LANE.decideObserver(snapshot, actor, st, macro, scoutPlan, stock)
        end

        -- Observer всегда в приоритете, если он есть в руках и нет срочной нужды именно в Sentry
        local obsOnMap = U.countNear(snapshot.allies, actor.pos, 20000, function(u)
            return u.kind == "observer_ward" and u.alive
        end)
        local wantObsFirst = stock > 0 and (forceWard or obsOnMap < 2 or not threats.invis or not canSen)
        if wantObsFirst and hp >= minHp and (macro.phase == "LANING" or macro.phase == "PUSH" or macro.localOnly or forceWard) then
            local obsAct = LANE.decideObserver(snapshot, actor, st, macro, nil, stock)
            if obsAct then return obsAct end
        end

        -- Если Observer ставить некуда/нет зарядов — ставим Sentry
        if not canSen or hp < minHp or now < (st.nextWardPlace or 15) then return nil end

        local spot = U.nearest(snapshot.pins, actor.pos, 2600, function(p)
            return p.kind == "ward_spot" and p.objective ~= "tormentor"
                and U.countNear(snapshot.allies, p.pos, 950, function(u) return u.kind == "sentry_ward" end) == 0
                and U.countNear(snapshot.enemies, p.pos, 900, U.isRealHero) == 0
        end)
        if not spot then return nil end

        if U.dist(actor.pos, spot.pos) <= 490 then
            st.wardAttemptStart = st.wardAttemptStart or now
            if now - st.wardAttemptStart >= 2.2 then
                st.nextWardPlace = now + 35
                st.wardAttemptStart = nil
            end
            return { kind = "cast", item = "item_ward_sentry", position = spot.pos, status = "Ставлю Sentry" }
        end
        st.wardAttemptStart = nil
        return { kind = "move", position = spot.pos, status = "Иду ставить Sentry" }
    end

    function LANE.decideObjectives(snapshot, actor, enemyCount, nearbyOnly)
        local now = snapshot.time
        local hp = U.ratio(actor.hp, actor.maxHp)
        if hp < 0.42 or enemyCount > 0 then return nil end

        local drop = U.nearest(snapshot.drops, actor.pos, 1100)
        if drop then
            local isAegis = drop.name == "item_aegis"
            if not isAegis or actor.position <= 2 then
                return { kind = "pickup", target_id = drop.id, status = "Подбираю дроп" }
            end
        end

        local rune = U.nearest(snapshot.runes, actor.pos, 850)
        if rune then
            return { kind = "rune", target_id = rune.id, status = "Беру руну" }
        end
        if nearbyOnly then return nil end

        if actor.position == 2 and now >= 105 then
            local pClk = snapshot.schedule.power
            local wClk = snapshot.schedule.water
            local nearPower = pClk and ((pClk.nextAt - now <= 12) or (pClk.lastAt and now - pClk.lastAt <= 16))
            local nearWater = wClk and ((wClk.nextAt and wClk.nextAt - now <= 10) or (wClk.lastAt and now - wClk.lastAt <= 14))
            if nearPower or nearWater then
                local r = U.nearest(snapshot.runes, actor.pos, 2600, function(x) return x.spawnerKind == "power" end)
                if r then return { kind = "rune", target_id = r.id, status = "Беру руну на реке" } end
                local spawner = U.nearest(snapshot.pins, actor.pos, 3000, function(p)
                    return p.kind == "power" and not p.visible
                end)
                if spawner then return { kind = "move", position = spawner.pos, status = "Иду на руну" } end
            end
        end

        if actor.position >= 4 then
            local wClk = snapshot.schedule.wisdom
            local lClk = snapshot.schedule.lotus
            local bClk = snapshot.schedule.bounty

            if wClk and ((wClk.nextAt - now <= 18) or (wClk.lastAt and now - wClk.lastAt <= 24)) then
                local pin = U.findPin(snapshot, "wisdom", function(p) return p.mapTeam == snapshot.team end)
                    or U.findPin(snapshot, "wisdom", function(p) return p.side == actor.lane end)
                if pin and not (pin.visible and pin.active == false) and U.dist(actor.pos, pin.pos) < 4200 then
                    return { kind = "shrine", position = pin.pos, target_id = pin.targetId, status = "Захватываю опыт" }
                end
            end

            if (actor.lane == "top" or actor.lane == "bot")
                and lClk and ((lClk.nextAt - now <= 12) or (lClk.lastAt and now - lClk.lastAt <= 16)) then
                local pin = U.findPin(snapshot, "lotus", function(p) return p.side == actor.lane end)
                if pin and not (pin.visible and pin.active == false) and U.dist(actor.pos, pin.pos) < 2600 then
                    return { kind = "lotus", position = pin.pos, target_id = pin.targetId, status = "Собираю лотос" }
                end
            end

            if bClk and now > 220 and ((bClk.nextAt - now <= 10) or (bClk.lastAt and now - bClk.lastAt <= 15)) then
                local pin = U.findPin(snapshot, "bounty", function(p) return p.mapTeam == snapshot.team end)
                if pin and U.dist(actor.pos, pin.pos) < 2800 then
                    local r = U.nearest(snapshot.runes, pin.pos, 400)
                    if r then return { kind = "rune", target_id = r.id, status = "Беру Баунти" } end
                    if not pin.visible then
                        return { kind = "move", position = pin.pos, status = "Иду за Баунти" }
                    end
                end
            end
        end

        return nil
    end

    function LANE.executeHeroGoal(snapshot, actor, goal, enemy, allyCount, basePos)
        if type(goal) ~= "table" then return nil end
        if goal.mode == "laning" then return "FORCE_LANING" end
        if type(goal.intent) == "table" then return goal.intent end

        local stText = goal.status or "Выполняю план"
        if goal.mode == "attack" and goal.targetId then
            return { kind = "attack", target_id = goal.targetId, status = stText }
        end

        if goal.pos then
            if (goal.mode == "gank" or goal.mode == "split_push") and COMBAT.canRightClick(enemy)
                and U.dist(actor.pos, enemy.pos) <= (actor.attackRange or 200) + 380
                and COMBAT.isSafeFromTower(snapshot, actor, enemy.pos, allyCount >= 2) then
                return { kind = "attack", target_id = enemy.id, status = stText }
            end
            if goal.mode == "split_push" then
                local eCreep = U.nearest(snapshot.enemies, actor.pos, 850, U.isLaneCreep)
                if eCreep and COMBAT.isSafeFromTower(snapshot, actor, eCreep.pos, false) then
                    return { kind = "attack", target_id = eCreep.id, status = stText }
                end
            end
            local kind = (goal.mode == "attack_move" or goal.mode == "split_push") and "attack_move" or "move"
            return { kind = kind, position = goal.pos, status = stText }
        end
        return nil
    end

    function LANE.findBestAllyTowerNear(snapshot, targetPos, maxDistFromTarget, minDistFromBase, basePos)
        local best, bestD = nil, maxDistFromTarget or 3600
        for _, u in ipairs(snapshot.allies or {}) do
            if u.kind == "tower" and u.alive ~= false then
                local dBase = basePos and U.dist(basePos, u.pos) or 9999
                if dBase >= (minDistFromBase or 2200) then
                    local d = U.dist(u.pos, targetPos)
                    if d < bestD then best, bestD = u, d end
                end
            end
        end
        return best, bestD
    end

    -- Умный выход с фонтана: TP на деф/команду / TP на линию под пуш / выход пешком в лес
    function LANE.decideFountainExit(snapshot, actor, st, macro, basePos)
        local now = snapshot.time
        if now < 45 or U.dist(actor.pos, basePos) > 1050 then return nil end

        local hp = U.ratio(actor.hp, actor.maxHp)
        local mana = U.ratio(actor.mana, actor.maxMana)
        local urgentDef = macro and macro.phase == "DEFEND" and macro.urgent

        -- Не уходим с фонтана недорегененными
        if urgentDef then
            if hp < 0.72 or ((actor.maxMana or 0) >= 150 and mana < 0.42) then return nil end
        else
            if hp < 0.88 or ((actor.maxMana or 0) >= 150 and mana < 0.65) then return nil end
        end

        local tp = INV.getTpState(actor)
        -- Если нет TP, но хватает 100 золота и он нужен — ждём 1 тик на фонтане, пока сработает buy
        if not tp.hasTp and (actor.gold or 0) >= 100 and (now < 480 or urgentDef or (macro and macro.phase == "PUSH")) then
            if not st.waitTpAt or now - st.waitTpAt < 1.2 then
                st.waitTpAt = st.waitTpAt or now
                return { kind = "hold", status = "Покупаю TP на базе" }
            end
        else
            st.waitTpAt = nil
        end

        -- 1. Срочный TP к макро-цели (DEFEND / PUSH / ROSHAN / TORMENTOR / HELP_GANK)
        if tp.ready and macro then
            local goalPos, tpStatus
            if macro.phase == "DEFEND" and macro.pos and U.dist(actor.pos, macro.pos) > 2500 then
                goalPos, tpStatus = macro.building and macro.building.pos or macro.pos, "ТП на защиту!"
            elseif (macro.phase == "PUSH" or macro.phase == "ROSHAN" or macro.phase == "TORMENTOR")
                and macro.pos and U.dist(actor.pos, macro.pos) > 3200 then
                goalPos = macro.phase == "PUSH" and macro.pushWave and macro.pushWave.pos or macro.pos
                tpStatus = (macro.phase == "PUSH") and "ТП на пуш к команде" or ("ТП на " .. bossName(macro.kind or macro.phase, "acc"))
            elseif macro.heroGoals and (macro.heroGoals[actor.id] or macro.heroGoals[actor.position]) then
                local g = macro.heroGoals[actor.id] or macro.heroGoals[actor.position]
                if g.pos and U.dist(actor.pos, g.pos) > 3000 then
                    goalPos, tpStatus = g.pos, "ТП на ганг!"
                end
            end
            if goalPos then
                local tower = LANE.findBestAllyTowerNear(snapshot, goalPos, 3800, 2200, basePos)
                if tower then
                    return { kind = "tp", position = tower.pos, fallbackPosition = goalPos, status = tpStatus }
                end
            end
        end

        -- 2. Выбор между TP на линию (фарм/отпуш) и выходом пешком в лес
        local bestTower, bestScore, bestReason = nil, -999, nil
        for _, u in ipairs(snapshot.allies or {}) do
            if u.kind == "tower" and u.alive ~= false and u.lane then
                local dBase = U.dist(basePos, u.pos)
                if dBase >= 2300 then
                    local enemyCreeps = U.countNear(snapshot.enemies, u.pos, 1800, U.isLaneCreep)
                    local enemyHeroes = U.countNear(snapshot.enemies, u.pos, 1500, U.isRealHero)
                    local allyCores = U.countNear(snapshot.heroes, u.pos, 1800, function(h)
                        return h.alive and h.id ~= actor.id and h.position <= 3
                    end)
                    local allyAll = U.countNear(snapshot.heroes, u.pos, 1800, function(h)
                        return h.alive and h.id ~= actor.id
                    end)

                    -- Считаем выгоду телепорта к этой вышке
                    local score = (dBase / 400) + enemyCreeps * 14
                    if u.lane == actor.lane and now < 540 then
                        score = score + 38 -- на лайнинге приоритет — своя линия
                    end
                    if enemyCreeps >= 3 and enemyHeroes <= allyAll then
                        score = score + 28 -- отличная волна под пуш/фарм
                    end
                    if allyCores > 0 and actor.position <= 3 and now >= 480 then
                        score = score - 26 -- не мешаем другому кору, ищем свободную линию
                    end
                    if enemyHeroes >= 2 and allyAll == 0 then
                        score = score - 60 -- не летим в одиночку на толпу врагов
                    end
                    if (u.tier or 1) == 1 then score = score + 10 end

                    if score > bestScore then
                        bestScore = score
                        bestTower = u
                        if enemyCreeps >= 3 then
                            bestReason = "ТП пушить " .. u.lane
                        elseif u.lane == actor.lane then
                            bestReason = "ТП на линию"
                        else
                            bestReason = "ТП на " .. u.lane
                        end
                    end
                end
            end
        end

        -- На лайнинге (< 8 мин) почти всегда жмём TP на линию, если башня далеко; позже — только если выгода высокая
        local tpThreshold = (now < 480) and 12 or 34
        if tp.ready and bestTower and bestScore >= tpThreshold then
            return { kind = "tp", position = bestTower.pos, status = bestReason or "ТП на линию" }
        end

        return nil
    end

    function LANE.decideMacroMove(snapshot, actor, macro, enemy, enemyCount, allyCount, basePos, prioritizeFarm, st)
        local tpReady = INV.getTpState(actor).ready

        if macro.phase == "DEFEND" then
            local goal = macro.building and macro.building.pos or macro.pos
            if COMBAT.canRightClick(enemy) and U.dist(actor.pos, enemy.pos) <= (actor.attackRange or 200) + 380 then
                return { kind = "attack", target_id = enemy.id, status = "Защищаю базу" }
            end
            local eCreep = U.nearest(snapshot.enemies, actor.pos, math.max((actor.attackRange or 200) + 260, 520), function(u)
                local canClearOnFoot = not tpReady and U.dist(actor.pos, u.pos) <= (actor.attackRange or 200) + 140
                return U.isLaneCreep(u) and COMBAT.isSafeCreepAttack(snapshot, actor, u)
                    and (U.dist(u.pos, goal) <= 1500 or (not macro.urgent and (u.aggroTargetId == actor.id or canClearOnFoot)))
            end)
            if eCreep then
                return COMBAT.farmCast(actor, eCreep, snapshot.enemies, 2)
                    or { kind = "attack", target_id = eCreep.id, status = "Чищу крипов у базы" }
            end
            if not macro.localOnly and tpReady and U.dist(actor.pos, goal) > 2600 then
                local tower = LANE.findBestAllyTowerNear(snapshot, goal, 2000, 0, basePos)
                if tower and U.dist(actor.pos, tower.pos) > U.dist(goal, tower.pos) + 1400 then
                    return { kind = "tp", position = tower.pos, fallbackPosition = goal, status = "ТП на защиту!" }
                end
            end
            return { kind = "attack_move", position = goal, status = "Бегу на защиту" }

        elseif macro.phase == "ROSHAN" or macro.phase == "TORMENTOR" then
            local bAcc = bossName(macro.kind or macro.phase, "acc")
            local bGen = bossName(macro.kind or macro.phase, "gen")
            local pitPos = macro.pitPos or macro.pos

            if tpReady and U.dist(actor.pos, pitPos) > 3400 and U.ratio(actor.hp, actor.maxHp) > 0.72 then
                local allyTower = LANE.findBestAllyTowerNear(snapshot, pitPos, 3400, 2200, basePos)
                if allyTower and U.dist(actor.pos, allyTower.pos) > 2200 then
                    return { kind = "tp", position = allyTower.pos, status = "ТП на " .. bAcc }
                end
            end
            if macro.rallyRange and (U.dist(actor.pos, pitPos) > macro.rallyRange
                or U.ratio(actor.hp, actor.maxHp) < 0.28) then
                return nil
            end

            local drop = U.nearest(snapshot.drops, actor.pos, 1000)
            if drop and ((macro.phase == "ROSHAN" and actor.position <= 2) or macro.phase == "TORMENTOR") then
                return { kind = "pickup", target_id = drop.id, status = "Беру дроп с " .. bGen }
            end
            if COMBAT.canRightClick(enemy) and U.dist(actor.pos, enemy.pos) <= 900 and allyCount >= 2 then
                return { kind = "attack", target_id = enemy.id, status = "Дерусь за " .. bAcc }
            end

            -- 1. Ожидание сбора команды перед началом атаки (особенно важно для деления урона Терзателя)
            if not macro.readyToAttack and macro.targetUnit then
                local rallyDist = macro.phase == "TORMENTOR" and 720 or 800
                local distance = U.dist(actor.pos, pitPos)
                local rally = U.towards(pitPos, actor.pos, rallyDist)
                return distance > rallyDist + 90
                    and { kind = "move", position = rally, status = "Собираемся на " .. bAcc }
                    or { kind = "hold", status = "Жду союзников у " .. bGen }
            end

            -- 2. Отдельная логика логова Рошана: вход внутрь (включая дальников), заманивание, танк и переагр
            if macro.phase == "ROSHAN" and macro.targetUnit and macro.targetId then
                local unit = macro.targetUnit
                local now = snapshot.time
                local distToPit = U.dist(actor.pos, pitPos)
                local roshOutsidePit = U.dist(unit.pos, pitPos) > ROSHAN_PIT_RADIUS + 30
                local isTank = (macro.tankId == actor.id)
                local hpDrop = (st and st.lastHp or actor.hp) - actor.hp
                local roshHittingMe = (unit.aggroTargetId == actor.id)
                    or (unit.aggroTargetId == nil and U.dist(actor.pos, unit.pos) <= 230 and hpDrop >= 45)

                -- Если Рошан вышел из логова — заманиваем его обратно в центр логова
                if roshOutsidePit then
                    if distToPit > 180 then
                        return { kind = "move", position = pitPos, status = "Заманиваю Рошана в логово" }
                    end
                    return { kind = "hold", status = "Заманиваю Рошана в логово" }
                end

                -- Переагр: если Рошан бьёт саппорта или просевшего старого танка — сбрасываем агр на нового танка
                if roshHittingMe and not isTank and macro.tankId then
                    local triedRecently = st and st.lastRoshDeaggroAt and (now - st.lastRoshDeaggroAt) < 1.2
                    if not triedRecently then
                        if st then st.lastRoshDeaggroAt = now end
                        return { kind = "deaggro", target_id = macro.tankId, status = "Переагриваю Рошана на танка" }
                    end
                    local stepBack = U.towards(pitPos, U.away(pitPos, unit.pos, 290), 290)
                    if U.dist(actor.pos, unit.pos) < 300 then
                        stepBack = U.away(actor.pos, unit.pos, 260)
                    end
                    return { kind = "move", position = stepBack, status = "Отхожу, переагриваю Рошана" }
                end

                -- Обязательно заходим ВНУТРЬ логова (даже герои с дальней атакой!)
                if distToPit > ROSHAN_PIT_RADIUS then
                    local enterPos = isTank
                        and U.towards(pitPos, unit.pos, 110)
                        or U.away(pitPos, unit.pos, 220)
                    return {
                        kind = "move",
                        position = enterPos,
                        status = isTank and "Захожу в логово танковать Рошана" or "Захожу в логово Рошана",
                    }
                end

                -- Не-танки (особенно саппорты) ждут внутри логова, пока танк не примет первый удар Рошана
                if not isTank and not macro.tankEngaged then
                    local safePitSpot = U.away(pitPos, unit.pos, 230)
                    if U.dist(actor.pos, safePitSpot) > 130 then
                        return { kind = "move", position = safePitSpot, status = "Жду, пока танк начнёт Рошана" }
                    end
                    return { kind = "hold", status = "Жду, пока танк начнёт Рошана" }
                end

                -- Новый танк подходит вплотную к Рошану, чтобы гарантированно забрать агр
                if isTank and unit.aggroTargetId ~= actor.id and not actor.ranged
                    and U.dist(actor.pos, unit.pos) > 190 then
                    return { kind = "move", position = U.towards(unit.pos, pitPos, 110), status = "Забираю агр Рошана" }
                end

                return {
                    kind = "attack",
                    target_id = macro.targetId,
                    status = isTank and "Танкую Рошана" or "Бью Рошана",
                }
            end

            -- 3. Логика Терзателя: стоим внутри радиуса 950 (делим урон на всех) и бьём вместе
            if macro.targetId and U.dist(actor.pos, pitPos) <= 1050 then
                if U.dist(actor.pos, pitPos) > 900 then
                    return { kind = "move", position = U.towards(pitPos, actor.pos, 550), status = "Подхожу делить урон Терзателя" }
                end
                return { kind = "attack", target_id = macro.targetId, status = "Бью Терзателя" }
            end
            return { kind = "move", position = pitPos, status = "Иду на " .. bAcc }

        elseif macro.phase == "SMOKE_GANK" and macro.pos then
            if COMBAT.canRightClick(enemy) and U.dist(actor.pos, enemy.pos) <= 900 then
                return { kind = "attack", target_id = enemy.id, status = "Смок-ганг!" }
            end
            return { kind = "move", position = macro.pos, status = macro.label or "Иду в смок-ганг" }

        elseif macro.phase == "PUSH" and macro.pos then
            local wave = macro.pushWave
            local destination = wave and wave.pos or macro.approach or macro.pos
            if tpReady and U.dist(actor.pos, destination) > 3600 and U.ratio(actor.hp, actor.maxHp) > 0.70 then
                local allyTower = U.nearest(snapshot.allies, destination, 2500, function(u)
                    return u.kind == "tower"
                end)
                if allyTower and U.dist(actor.pos, allyTower.pos) > 2500 then
                    return { kind = "tp", position = allyTower.pos, fallbackPosition = destination, status = "ТП к волне" }
                end
            end

            if not prioritizeFarm and COMBAT.canRightClick(enemy) and U.dist(actor.pos, enemy.pos) <= (actor.attackRange or 200) + 340 then
                local safeT = COMBAT.isSafeFromTower(snapshot, actor, enemy.pos, false)
                if safeT then
                    return { kind = "attack", target_id = enemy.id, status = "Тимфайт на пуше" }
                end
            end

            local canAttackBuilding = COMBAT.siegeReady(snapshot, macro)
                or (macro.targetId and macro.targetBuilding
                    and not macro.targetBuilding.invulnerable
                    and not macro.targetBuilding.attackImmune
                    and not macro.targetBuilding.fortified
                    and not macro.targetBuilding.backdoorProtected
                    and U.dist(actor.pos, macro.targetBuilding.pos) <= 1250
                    and COMBAT.canTankTower(snapshot, actor, macro.targetBuilding, st, enemyCount, allyCount, macro, 1))
            if canAttackBuilding then
                return { kind = "attack", target_id = macro.targetId,
                    status = (st and st.tankingTower) and "Танкую и ломаю постройку" or "Ломаю постройку" }
            end

            local eCreep = U.nearest(macro.enemyLaneCreeps or snapshot.enemies, actor.pos, 1250, function(u)
                return U.isLaneCreep(u) and COMBAT.isSafeCreepAttack(snapshot, actor, u)
                    and (not wave or U.dist(wave.pos, u.pos) <= 1600 or U.dist(u.pos, macro.pos) <= 1400)
            end)
            if eCreep then
                return (enemyCount == 0 and COMBAT.farmCast(actor, eCreep, snapshot.enemies, 2))
                    or { kind = "attack", target_id = eCreep.id, status = "Толкаю волну" }
            end

            if wave then
                if not macro.targetBuilding and COMBAT.siegeHasWave(snapshot, macro) then
                    return { kind = "attack_move", position = macro.pos, status = "Вхожу за волной" }
                end
                local follow = U.towards(wave.pos, macro.approach or basePos, actor.ranged and 260 or 150)
                if U.dist(actor.pos, follow) > 125 and COMBAT.isSafeFromTower(snapshot, actor, follow, false) then
                    return { kind = "move", position = follow, status = "Сопровождаю волну" }
                elseif U.dist(actor.pos, follow) <= 125 then
                    return { kind = "hold", status = "Иду с волной" }
                end
            end

            local rally = (not wave and macro.approach and COMBAT.isSafeFromTower(snapshot, actor, macro.approach, false))
                and macro.approach or COMBAT.siegeRally(snapshot, actor, macro.pos, macro.lane, macro.tier, basePos)
            if rally and U.dist(actor.pos, rally) > 110 then
                return { kind = "move", position = rally, status = "Прикрываю свою волну" }
            end
            return { kind = "hold", status = "Прикрываю свою волну" }
        end

        return nil
    end

    local TICK_COMP = 0.08 -- компенсация половины тика движка (TICK = 0.15)

    function LANE.updateCreepTracker(snapshot)
        local now = snapshot.time
        local track = MEM.creepHp
        local seen = {}
        local function scan(list)
            for _, u in ipairs(list or {}) do
                if U.isLaneCreep(u) and u.alive ~= false then
                    seen[u.id] = true
                    local rec = track[u.id]
                    if not rec then
                        track[u.id] = { hp = u.hp, at = now, dps = 0 }
                    else
                        local dt = now - rec.at
                        if dt >= 0.05 then
                            local instDps = math.max(0, (rec.hp - u.hp) / dt)
                            -- Отсекаем спайки от нюков, чтобы бот не бил крипа с 300 ХП
                            instDps = math.min(instDps, 180)
                            rec.dps = rec.dps * 0.65 + instDps * 0.35
                            rec.hp = u.hp
                            rec.at = now
                        end
                    end
                end
            end
        end
        scan(snapshot.enemies)
        scan(snapshot.allies)
        for id in pairs(track) do
            if not seen[id] then track[id] = nil end
        end
    end

    -- Оценка входящего ДПС по крипу: сумма всех бьющих его крипов/вышек + сглаженная потеря ХП
    function LANE.estimateCreepDps(snapshot, creep, isEnemyCreep)
        local aMult = U.armorMult(creep.armor)
        local attackers = isEnemyCreep and snapshot.allies or snapshot.enemies
        local structuralDps, attackerCount = 0, 0
        for _, u in ipairs(attackers or {}) do
            if u.alive ~= false and u.aggroTargetId == creep.id then
                attackerCount = attackerCount + 1
                local uDmg = u.attackDamage or (u.kind == "tower" and 90 or 21)
                local uSpa = (u.secondsPerAttack and u.secondsPerAttack > 0.1) and u.secondsPerAttack or 1.0
                structuralDps = structuralDps + (uDmg * aMult) / uSpa
            end
        end
        local rec = MEM.creepHp[creep.id]
        local measuredDps = (rec and rec.dps) or 0
        if attackerCount > 0 then
            return math.min(structuralDps + 45, math.max(structuralDps, measuredDps * 0.85)), attackerCount
        end
        return math.min(measuredDps, 95), 0
    end

    -- Расчёт эффективного урона героя, времени долета тычки и предсказанного ХП крипа в момент удара
    function LANE.predictCreepHit(snapshot, actor, creep, isEnemyCreep)
        local baseDmg = (actor.attackDamage or 55)
        -- Бонус Quelling Blade по вражеским крипам (на денай не работает)
        if isEnemyCreep and U.hasItem(actor, "item_quelling_blade", true) then
            baseDmg = baseDmg + (actor.ranged and 4 or 8)
        end
        local effDmg = baseDmg * U.armorMult(creep.armor) * (actor.ranged and 0.96 or 0.99)
        local dist = U.dist(actor.pos, creep.pos)
        local atkRange = actor.attackRange or 150
        local ms = math.max(150, actor.moveSpeed or 300)

        local moveTime = math.max(0, (dist - atkRange) / ms)
        local attackPoint = actor.attackPoint or (actor.ranged and 0.40 or 0.35)
        local projTime = 0
        if actor.ranged then
            local projSpeed = (actor.projectileSpeed and actor.projectileSpeed > 100) and actor.projectileSpeed or 900
            -- Если нужно подойти на радиус атаки, снаряд полетит уже с дистанции atkRange
            local fireDist = math.min(dist, atkRange)
            projTime = fireDist / projSpeed
        end

        local impactTime = moveTime + attackPoint + projTime + TICK_COMP
        local dps, attackers = LANE.estimateCreepDps(snapshot, creep, isEnemyCreep)
        local leadDmg = math.min(effDmg * 1.65, dps * impactTime)
        local predictedHp = creep.hp - leadDmg
        local triggerHp = effDmg + leadDmg
        local ttk = dps > 5 and (creep.hp / dps) or 99

        return {
            effDmg = effDmg,
            dist = dist,
            impactTime = impactTime,
            dps = dps,
            attackers = attackers,
            predictedHp = predictedHp,
            triggerHp = triggerHp,
            ttk = ttk,
            canHitNow = (creep.hp <= effDmg * 1.02)
                or (dps > 6 and predictedHp <= effDmg * 1.03 and creep.hp <= triggerHp),
        }
    end

    -- Выбирает главного крипа, к которому герой должен заранее стягиваться
    function LANE.pickWatchCreep(snapshot, actor, coreNearby, farmOnly)
        local best, bestScore, bestIsEnemy = nil, math.huge, true
        local limit = farmOnly and heroStyle(actor).farmWaveRange or 1250
        if not coreNearby then
            for _, u in ipairs(snapshot.enemies or {}) do
                if U.isLaneCreep(u) and u.alive ~= false then
                    local d = U.dist(actor.pos, u.pos)
                    if d <= limit and (not farmOnly or COMBAT.isSafeCreepAttack(snapshot, actor, u)) then
                        local info = LANE.predictCreepHit(snapshot, actor, u, true)
                        local prioBonus = (u.kind == "siege_creep" and -1.0) or (u.name:find("ranged") and -0.6) or 0
                        -- Чем меньше ХП и быстрее умирает крип, тем ниже (лучше) score
                        local score = (u.hp / math.max(1, info.effDmg)) + math.min(info.ttk, 8) * 0.45 + prioBonus + d * 0.0012
                        if score < bestScore then
                            best, bestScore, bestIsEnemy = u, score, true
                        end
                    end
                end
            end
        end
        if farmOnly then return best, bestIsEnemy end
        -- Если вражеских крипов под ластхит ещё нет, следим за своим пробитым крипом под денай
        for _, u in ipairs(snapshot.allies or {}) do
            if U.isLaneCreep(u) and u.alive ~= false and U.ratio(u.hp, u.maxHp) < 0.62 then
                local d = U.dist(actor.pos, u.pos)
                if d <= 1100 then
                    local info = LANE.predictCreepHit(snapshot, actor, u, false)
                    local score = (u.hp / math.max(1, info.effDmg)) + math.min(info.ttk, 8) * 0.45 + 0.8 + d * 0.0012
                    if score < bestScore then
                        best, bestScore, bestIsEnemy = u, score, false
                    end
                end
            end
        end
        return best, bestIsEnemy
    end

    -- Очеловеченное движение: бег туда-сюда (стрейф) + плавный подход по мере падения ХП крипа
    function LANE.humanPacePos(snapshot, actor, st, creep, isEnemyCreep, enemy, enemyCount, allyCount, basePos)
        local now = snapshot.time
        local atkRange = actor.attackRange or 150
        local info = LANE.predictCreepHit(snapshot, actor, creep, isEnemyCreep)
        local style = heroStyle(actor)

        -- urgency: 0 (крип здоровый) -> 1 (крип вот-вот упадёт в окно ластхита)
        local hpMultiple = creep.hp / math.max(1, info.effDmg)
        local hpUrgency = math.max(0, math.min(1, (4.0 - hpMultiple) / 2.7))
        local ttkUrgency = math.max(0, math.min(1, (3.2 - info.ttk) / 2.2))
        local urgency = math.max(hpUrgency, ttkUrgency)

        -- Целевая дистанция: чем ближе ластхит, тем ближе герой подходит к крипу
        local idealDist
        if actor.ranged then
            -- Дальники подходят ближе к умирающему крипу, чтобы сократить время полёта снаряда
            local farDist = math.max(360, atkRange - 45)
            local closeDist = math.max(250, math.min(atkRange - 90, atkRange * 0.62))
            idealDist = farDist - (farDist - closeDist) * urgency
        else
            -- Милишники стоят безопасно (~330), а перед ластхитом вплотную подходят к крипу (~155)
            local farDist = 330
            local closeDist = math.max(145, atkRange + 10)
            idealDist = farDist - (farDist - closeDist) * urgency
        end

        -- Вектор «от крипа к нашей базе» + перпендикуляр для бокового стрейфа
        local dx = (basePos.x or 0) - (creep.pos.x or 0)
        local dy = (basePos.y or 0) - (creep.pos.y or 0)
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 1 then dx, dy, len = -1, 0, 1 end
        local bx, by = dx / len, dy / len
        local px, py = -by, bx -- перпендикуляр (влево/вправо по линии)

        -- Меняем направление стрейфа каждые 0.45..0.80 сек (у каждого героя свой ритм)
        if not st.paceSwitchAt or now >= st.paceSwitchAt then
            st.paceDir = (st.paceDir == 1) and -1 or 1
            local period = 0.48 + ((actor.position * 17 + math.floor(now * 3)) % 7) * 0.05
            st.paceSwitchAt = now + period
            st.paceDepth = ((math.floor(now * 2) + actor.position) % 2 == 0) and 1 or -1
        end

        -- Если вражеский герой близко, слегка смещаем базу стрейфа в безопасную сторону от врага
        local lateralBias = 0
        if enemy and U.dist(creep.pos, enemy.pos) < 850 then
            local ex = (enemy.pos.x or 0) - (creep.pos.x or 0)
            local ey = (enemy.pos.y or 0) - (creep.pos.y or 0)
            local sideDot = ex * px + ey * py
            lateralBias = sideDot >= 0 and -75 or 75
            -- Дальник не подходит в упор к врагу, если враг рядом с крипом и это опасно
            if actor.ranged and (U.ratio(actor.hp, actor.maxHp) < 0.75 or enemyCount > allyCount) then
                local minSafe = math.max(340, (enemy.attackRange or 150) + 120)
                if U.dist(creep.pos, enemy.pos) < minSafe then
                    idealDist = math.max(idealDist, math.min(atkRange - 35, minSafe))
                end
            end
        end

        -- Когда крип почти умирает (urgency > 0.75), гасим боковой разброс, чтобы герой смотрел на крипа
        local lateralAmp = (1 - urgency * 0.72) * (actor.ranged and 130 or 105) * style.laneStrafeScale
        local depthJitter = (1 - urgency * 0.80) * 42 * (st.paceDepth or 1) * style.laneStrafeScale
        local sideShift = lateralBias + (st.paceDir or 1) * lateralAmp
        local finalDist = math.max(135, idealDist + depthJitter + style.laneDistanceOffset * (1 - urgency))

        local candidate = {
            x = creep.pos.x + bx * finalDist + px * sideShift,
            y = creep.pos.y + by * finalDist + py * sideShift,
            z = creep.pos.z or 0,
        }

        -- Если стрейф заводит под вышку — откатываемся к прямой точке на линии к базе
        if not COMBAT.isSafeFromTower(snapshot, actor, candidate, false) then
            candidate = U.towards(creep.pos, basePos, math.max(finalDist, 420))
        end

        local status
        if urgency >= 0.60 then
            status = isEnemyCreep and "Готовлю ластхит" or "Готовлю денай"
        else
            status = "Мансую на линии"
        end
        return candidate, urgency, status
    end

    function LANE.customPosition(snapshot, actor, lane)
        local pos = heroHook(actor, "LanePosition", snapshot, actor, lane)
        if mapPosition(pos) and COMBAT.isSafeFromTower(snapshot, actor, pos, false) then return pos end
    end

    function LANE.readFarmCamps(snapshot)
        local camps = {}
        for _, pin in ipairs(snapshot.pins or {}) do
            if pin.kind == "camp" then
                local key = string.format("%.0f:%.0f", pin.pos.x, pin.pos.y)
                camps[#camps + 1] = { key = key, pin = pin, creeps = {} }
            end
        end
        local landmarks = #camps
        for _, creep in ipairs(snapshot.neutrals or {}) do
            if creep.kind == "neutral" and creep.alive ~= false and not creep.invulnerable and not creep.attackImmune then
                local nearest, distance = nil, 650
                for i = 1, landmarks do
                    local camp = camps[i]
                    local d = U.dist(camp.pin.pos, creep.pos)
                    if d < distance then nearest, distance = camp, d end
                end
                if nearest then
                    nearest.creeps[#nearest.creeps + 1] = creep
                else
                    camps[#camps + 1] = { key = creep.id, creeps = { creep } }
                end
            end
        end
        for _, camp in ipairs(camps) do
            if camp.pin and camp.pin.visible then
                MEM.emptyCamps[camp.key] = #camp.creeps == 0
                    and (math.floor(snapshot.time / 60) + 1) * 60 + 1 or nil
            end
        end
        return camps
    end

    function LANE.decideJungle(snapshot, actor, st, farm, shelter, maxRange)
        local style = heroStyle(actor)
        if snapshot.time < style.jungleMinTime or (actor.level or 1) < style.jungleMinLevel
            or U.ratio(actor.hp, actor.maxHp) < style.jungleMinHp or actor.disarmed or actor.rooted then
            return nil
        end
        local searchRange = maxRange or style.jungleSearchRange
        local best, bestScore, bestTarget, bestPos
        for _, camp in ipairs(farm.camps) do
            if not farm.claimed[camp.key] then
                local pin = camp.pin
                local target = U.nearest(camp.creeps, actor.pos, searchRange, function(u)
                    return (not u.ancient or actor.level >= 8) and COMBAT.isSafeCreepAttack(snapshot, actor, u)
                end)
                local canScout = pin and #camp.creeps == 0 and pin.mapTeam == snapshot.team and not pin.visible
                    and snapshot.time >= (MEM.emptyCamps[camp.key] or 0) and U.dist(actor.pos, pin.pos) > 240
                local pos = (target and target.pos) or (canScout and pin.pos)
                if pos then
                    local distance = U.dist(actor.pos, pos)
                    local ownCamp = pin and pin.mapTeam == snapshot.team
                    if distance <= searchRange
                        and (distance <= style.jungleSearchRange or ownCamp)
                        and (not shelter or (U.dist(pos, shelter) <= 2200 and (not pin or ownCamp)))
                        and (target or COMBAT.isSafeFromTower(snapshot, actor, pos, false))
                        and not U.nearest(snapshot.enemies, pos, style.jungleDangerRadius, U.isRealHero) then
                        local score = -distance + (target and 450 or 0)
                            + (st.farmCamp == camp.key and 550 or 0)
                        local info = {
                            pin = pin, target = target, pos = pos, distance = distance, count = #camp.creeps,
                        }
                        local custom = heroHook(actor, "ScoreFarmCamp", snapshot, actor, info, score)
                        if custom == nil then custom = safeHook(tactic.ScoreFarmCamp, snapshot, actor, info, score) end
                        if finite(custom) then score = custom end
                        if custom ~= false and (not bestScore or score > bestScore) then
                            best, bestScore, bestTarget, bestPos = camp, score, target, pos
                        end
                    end
                end
            end
        end
        if not best then st.farmCamp = nil; return nil end
        st.farmCamp = best.key
        farm.claimed[best.key] = actor.id
        if bestTarget then
            return COMBAT.farmCast(actor, bestTarget, best.creeps, 2)
                or { kind = "attack", target_id = bestTarget.id, status = "Фармлю лес" }
        end
        return { kind = "move", position = bestPos, status = "Иду на кемп" }
    end

    function LANE.waitForAllies(snapshot, actor, st, farm, enemy, basePos, defendBase)
        local shelter = U.nearest(snapshot.allies, actor.pos, nil, function(u)
            return u.kind == "tower" and not U.nearest(snapshot.enemies, u.pos, 1100, U.isRealHero)
                and (not defendBase or U.dist(u.pos, basePos) <= 2400)
                and (not enemy or U.dist(u.pos, enemy.pos) > math.max(1100, U.dist(actor.pos, enemy.pos)))
        end)
        local safePos = shelter and shelter.pos or basePos
        if enemy and U.dist(actor.pos, enemy.pos) <= 1450 then
            if U.dist(actor.pos, safePos) < 180 then safePos = basePos end
            if (actor.mana or 0) >= 50 and U.dist(actor.pos, enemy.pos) < 650
                and COMBAT.readyItem(actor, "item_black_king_bar") then
                return { kind = "cast", item = "item_black_king_bar", status = "Прикрываю отход BKB" }
            end
            return { kind = "move", position = safePos, status = "Отхожу и жду команду" }
        end
        if U.ratio(actor.hp, actor.maxHp) < 0.32 then
            if U.dist(actor.pos, basePos) > 350 then
                return { kind = "move", position = basePos, status = "Возвращаюсь за здоровьем" }
            end
            return { kind = "hold", status = "Регенюсь перед перегруппировкой" }
        end
        if defendBase and U.dist(actor.pos, safePos) > 1600 then
            return { kind = "move", position = safePos, status = "Собираюсь на защиту базы" }
        end
        local creep = U.nearest(snapshot.enemies, actor.pos, 850, function(u)
            return U.isLaneCreep(u) and U.dist(u.pos, safePos) <= (defendBase and 1400 or 950)
                and COMBAT.isSafeCreepAttack(snapshot, actor, u)
        end)
        if creep then
            return COMBAT.farmCast(actor, creep, snapshot.enemies, 2)
                or { kind = "attack", target_id = creep.id, status = "Чищу волну, жду союзников" }
        end
        local camp = LANE.decideJungle(snapshot, actor, st, farm, safePos)
        if camp then return camp end
        if U.dist(actor.pos, safePos) > 350 then
            return { kind = "move", position = safePos, status = "Собираюсь с командой" }
        end
        return { kind = "hold", status = "Жду возрождения союзников" }
    end

    function LANE.decideLaning(snapshot, actor, st, enemy, enemyCount, allyCount, basePos, prioritizeFarm, farm)
        local now = snapshot.time
        local hp = U.ratio(actor.hp, actor.maxHp)
        local atkRange = actor.attackRange or 200
        local hitRange = atkRange + (actor.ranged and 180 or 260)
        local style = heroStyle(actor)

        local coreNearby = actor.position >= 4 and U.countNear(snapshot.heroes, actor.pos, 950, function(h)
            return h.alive and h.position <= 3
        end) > 0

        -- 1. Предиктивный ластхит (учитывает скорость снаряда, замах, дистанцию и ДПС по крипу)
        if not coreNearby then
            local bestLh, bestScore = nil, -999
            for _, u in ipairs(snapshot.enemies or {}) do
                if U.isLaneCreep(u) and u.alive ~= false and U.dist(actor.pos, u.pos) <= hitRange
                    and COMBAT.isSafeCreepAttack(snapshot, actor, u) then
                    local info = LANE.predictCreepHit(snapshot, actor, u, true)
                    local locked = st and st.lhTargetId == u.id and now < (st.lhUntil or 0)
                        and u.hp <= info.triggerHp * 1.12
                    if info.canHitNow or locked then
                        local prio = (u.kind == "siege_creep" and 300) or (u.name:find("ranged") and 200) or 100
                        local score = prio - info.predictedHp - info.dist * 0.05
                        if score > bestScore then
                            bestLh, bestScore = u, score
                        end
                    end
                end
            end
            if bestLh then
                if st then
                    st.lhTargetId = bestLh.id
                    st.lhUntil = now + 0.35
                end
                return { kind = "attack", target_id = bestLh.id, status = "Ластхит" }
            end
        end

        -- 2. Предиктивный денай (дальники также выпускают снаряд заранее)
        local bestDn, bestDnScore = nil, -999
        for _, u in ipairs(snapshot.allies or {}) do
            if U.isLaneCreep(u) and u.alive ~= false and u.deniable
                and U.dist(actor.pos, u.pos) <= (farm and atkRange + 100 or hitRange)
                and COMBAT.isSafeFromTower(snapshot, actor, u.pos, false) then
                local info = LANE.predictCreepHit(snapshot, actor, u, false)
                if info.canHitNow then
                    local prio = (u.kind == "siege_creep" and 300) or (u.name:find("ranged") and 200) or 100
                    local score = prio - info.predictedHp - info.dist * 0.05
                    if score > bestDnScore then
                        bestDn, bestDnScore = u, score
                    end
                end
            end
        end
        if bestDn then
            return { kind = "deny", target_id = bestDn.id, status = "Денай" }
        end

        -- 3. Харасс и размен на линии (не бросаем почти умирающего крипа ради одной тычки по врагу)
        local watchCreep, watchIsEnemy = LANE.pickWatchCreep(snapshot, actor, coreNearby, farm)
        local watchInfo = watchCreep and LANE.predictCreepHit(snapshot, actor, watchCreep, watchIsEnemy)
        local creepAboutToDie = watchInfo and (watchCreep.hp <= watchInfo.effDmg * 1.75 or watchInfo.ttk <= watchInfo.impactTime + 0.55)

        local profile = PROFILES[actor.name]
        if profile and type(profile.LaneAction) == "function" then
            local custom = heroHook(actor, "LaneAction", snapshot, actor, {
                creep = watchCreep, isEnemyCreep = watchIsEnemy, creepAboutToDie = creepAboutToDie,
                enemy = enemy, enemyCount = enemyCount, allyCount = allyCount, basePos = basePos,
                coreNearby = coreNearby, prioritizeFarm = prioritizeFarm,
            })
            if type(custom) == "table" and type(custom.kind) == "string" then
                local moving = custom.kind == "move" or custom.kind == "attack_move"
                if not moving or (mapPosition(custom.position)
                    and COMBAT.isSafeFromTower(snapshot, actor, custom.position, false)) then
                    return custom
                end
            end
        end

        local soloMid = actor.position == 2 and actor.lane == "mid" and now < 600
            and hp >= 0.65 and enemyCount == 1 and allyCount == 0
            and U.dist(actor.pos, DATA.LANES.mid) <= 2200
        local riskyLinaTrade = enemy and actor.name == "npc_dota_hero_lina" and enemy.name == "npc_dota_hero_viper"
            and hp < U.ratio(enemy.hp, enemy.maxHp) + 0.18
        local midTrade = soloMid and enemy and not enemy.invulnerable and not enemy.attackImmune
            and not riskyLinaTrade and COMBAT.isSafeFromTower(snapshot, actor, enemy.pos, false)
        if style.laneHarass and COMBAT.canRightClick(enemy) and not creepAboutToDie and (not prioritizeFarm or midTrade)
            and U.dist(actor.pos, enemy.pos) <= atkRange + (midTrade and 220 or 150) then
            local enemyCreepsAround = U.countNear(snapshot.enemies, actor.pos, 500, U.isLaneCreep)
            local nearEnemyTower = COMBAT.nearestEnemyTower(snapshot, actor.pos, 580) ~= nil
            local badCreepAggro = now < 420 and (actor.level or 1) <= 4 and enemyCreepsAround >= 3 and U.ratio(enemy.hp, enemy.maxHp) > 0.35
            if not nearEnemyTower and not badCreepAggro and enemyCount <= allyCount + 1 then
                if actor.ranged and U.dist(actor.pos, enemy.pos) < atkRange * 0.55 and hp < 0.60 then
                    return { kind = "move", position = U.away(actor.pos, enemy.pos, 260), status = "Кайчу врага" }
                end
                return { kind = "attack", target_id = enemy.id, status = midTrade and "Давлю на миду" or "Харасс" }
            end
        end

        if not coreNearby and enemyCount == 0 and now >= style.wavePushTime then
            local wave = U.nearest(snapshot.enemies, actor.pos, 1100, function(u)
                return U.isLaneCreep(u) and COMBAT.isSafeFromTower(snapshot, actor, u.pos, false)
            end)
            local farmAct = wave and COMBAT.farmCast(actor, wave, snapshot.enemies, 2)
            if farmAct then return farmAct end
        end

        -- 4. Урон по вражеской вышке, если есть союзные крипы
        local eTower = U.nearest(snapshot.enemies, actor.pos, 1000, function(u)
            return u.kind == "tower" and not u.invulnerable and not u.attackImmune
        end)
        if eTower and not eTower.fortified and not eTower.backdoorProtected and enemyCount <= allyCount
            and (COMBAT.allyCreepsAtTower(snapshot, eTower.pos) >= 2
                or COMBAT.canTankTower(snapshot, actor, eTower, st, enemyCount, allyCount, nil, 1)) then
            return { kind = "attack", target_id = eTower.id,
                status = (st and st.tankingTower) and "Танкую и добиваю вышку" or "Бью вышку" }
        end

        -- 5. Очеловеченное позиционирование: стрейф туда-сюда + плавный подход к умирающему крипу
        local focusCreep = watchCreep or (not farm and U.nearest(snapshot.enemies, actor.pos, 2400, U.isLaneCreep))
        if focusCreep then
            local creepDistance = U.dist(actor.pos, focusCreep.pos)
            local unopposedWave = style.pushUnopposedWave and prioritizeFarm and hp > 0.60 and watchIsEnemy
                and U.countNear(snapshot.allies, focusCreep.pos, 550, U.isLaneCreep) == 0
            -- После 7-й минуты (или если пачка без наших крипов) толкаем волну, не ломая ластхит
            if watchIsEnemy and creepDistance <= atkRange + 200 and (now > style.wavePushTime or unopposedWave) and not coreNearby
                and not creepAboutToDie and COMBAT.isSafeCreepAttack(snapshot, actor, focusCreep) then
                return { kind = "attack", target_id = focusCreep.id, status = "Фармлю волну" }
            end

            local pacePos, urgency, paceStatus = LANE.humanPacePos(
                snapshot, actor, st or {}, focusCreep, watchIsEnemy, enemy, enemyCount, allyCount, basePos)
            local customPos = LANE.customPosition(snapshot, actor, {
                defaultPos = pacePos, creep = focusCreep, isEnemyCreep = watchIsEnemy, urgency = urgency,
                enemy = enemy, enemyCount = enemyCount, allyCount = allyCount, basePos = basePos,
                coreNearby = coreNearby, prioritizeFarm = prioritizeFarm,
            })
            if customPos then pacePos, paceStatus = customPos, "Занимаю позицию на линии" end
            local safe, tower = COMBAT.isSafeFromTower(snapshot, actor, pacePos, false)
            if not safe then
                if farm then return LANE.decideJungle(snapshot, actor, st, farm) end
                local rally = COMBAT.siegeRally(snapshot, actor, tower.pos, tower.lane, tower.tier, basePos)
                if rally and U.dist(actor.pos, rally) > 110 then
                    return { kind = "move", position = rally, status = "Прикрываю свою волну" }
                end
                return { kind = "hold", status = "Прикрываю свою волну" }
            end

            -- Если уже стоим почти вплотную в точке удара перед самым ластхитом — не сбиваем поворот
            if (customPos or urgency >= 0.85) and U.dist(actor.pos, pacePos) <= 45 then
                return { kind = "hold", status = paceStatus }
            end
            return { kind = "move", position = pacePos, status = paceStatus }
        end

        if farm then
            return LANE.decideJungle(snapshot, actor, st, farm)
        end

        local eTowerPin = U.findPin(snapshot, "tower", function(p)
            return p.mapTeam == snapshot.enemyTeam and p.lane == actor.lane and p.tier == 1
        end)
        local frontAlly = eTowerPin and U.nearest(snapshot.allies, eTowerPin.pos, 3200, U.isLaneCreep)
        local lanePos = DATA.LANES[actor.lane] or DATA.LANES.mid
        local status = "Выхожу на линию"
        if frontAlly then
            local followPos = U.towards(frontAlly.pos, basePos, actor.ranged and 360 or 220)
            if COMBAT.isSafeFromTower(snapshot, actor, followPos, false) then
                lanePos, status = followPos, "Иду с волной"
            end
        end
        local customPos = LANE.customPosition(snapshot, actor, {
            defaultPos = lanePos, enemy = enemy, enemyCount = enemyCount, allyCount = allyCount,
            basePos = basePos, coreNearby = coreNearby, prioritizeFarm = prioritizeFarm, urgency = 0,
        })
        if customPos then
            if U.dist(actor.pos, customPos) <= 45 then return { kind = "hold", status = "Держу позицию на линии" } end
            lanePos, status = customPos, "Занимаю позицию на линии"
        end
        return { kind = "move", position = lanePos, status = status }
    end

    -- ========================================================================
    -- Главный цикл команды: Team:DecideTeam(snapshot)
    -- ========================================================================
    function Team:DecideTeam(snapshot)
        local now = snapshot.time
        local actions = {}
        local basePin = U.findPin(snapshot, "fountain", function(p) return p.mapTeam == snapshot.team end)
        local basePos = basePin and basePin.pos or { x = 0, y = 0, z = 0 }
        for _, ln in ipairs({ "top", "mid", "bot" }) do
            if not MEM.waveArrived[ln] then
                MEM.waveArrived[ln] = now >= 55
                    or U.nearest(snapshot.allies, DATA.LANES[ln], 1250, U.isLaneCreep) ~= nil
                    or U.nearest(snapshot.enemies, DATA.LANES[ln], 1250, U.isLaneCreep) ~= nil
            end
        end
        LANE.updateCreepTracker(snapshot)

        MEM.lastTime = now
        local threats = INV.analyzeThreats(snapshot)
        -- 1. Обновляем 8-сек историю боёв/позиций и чистим завершённые директивы
        Comms.updateHistory(snapshot, MEM.comms, MEM.observerOrders, COMBAT, STYLE.commsEnabled ~= false)
        -- 2. Строим макро (оно уже учитывает активную директиву из MEM.comms.directive)
        local macro = MACRO.build(snapshot)
        local previousDir = MEM.comms.directive
        local hadForceWard = previousDir and previousDir.forceWard
        -- 3. Анализируем события уже зная точный macro (DEFEND/ROSHAN/LANING/PUSH)
        Comms.processEvents(snapshot, MEM.comms, macro, threats, INV.getBuildForHero, COMBAT, STYLE, DATA.LANES)
        safeHook(tactic.OnComms, snapshot, macro, MEM.comms.directive)
        for _, actor in ipairs(snapshot.heroes or {}) do
            heroHook(actor, "OnComms", snapshot, actor, macro, MEM.comms.directive)
        end
        local newDir = MEM.comms.directive
        if newDir and (newDir ~= previousDir or newDir.kind == "HELP_GANK" or newDir.kind == "NEED_WARDS"
            or (newDir.forceWard and not hadForceWard)) then
            macro = MACRO.applyDirective(macro, newDir)
        end
        local siegeReady = COMBAT.siegeReady(snapshot, macro)
        local stagingPush = macro.phase == "PUSH" and macro.pos
            and not macro.pushWave and not macro.cleanPush and not COMBAT.siegeHasWave(snapshot, macro)
            and not (macro.situation and (macro.situation.enemyDead or 0) >= 2)
        local farm = {
            camps = now >= farmStartsAt and LANE.readFarmCamps(snapshot) or {},
            claimed = {},
        }
        local wardGank
        if not macro.regroup and not macro.heroGoals and (macro.phase == "LANING" or stagingPush) then
            wardGank = MACRO.pickWardGank(snapshot)
        end
        local teamFocus = COMBAT.pickTeamFocus(snapshot)
        local glyphUsed = false

        if wardGank then
            local heroName = wardGank.target.name:gsub("^npc_dota_hero_", ""):gsub("_", " ")
            actions._macro = "WARD GANK | " .. heroName
        elseif macro.label then
            actions._macro = macro.label
        elseif macro.phase == "BOUNTY_START" and MEM.preGamePlan then
            actions._macro = "PREGAME: " .. MEM.preGamePlan.kind
        elseif macro.phase ~= "LANING" and macro.phase ~= "BOUNTY_START" then
            actions._macro = macro.phase
        end
        local wantGlyph = false
        if (snapshot.glyphCooldown or 0) <= 0 and macro.phase == "DEFEND" and macro.building then
            local b = macro.building
            local bHp = U.ratio(b.hp, b.maxHp)
            local eHeroes = U.countNear(snapshot.enemies, b.pos, 1300, U.isRealHero)
            local eCreeps = U.countNear(snapshot.enemies, b.pos, 900, U.isLaneCreep)
            if macro.urgent and (eHeroes > 0 or eCreeps >= 2) and bHp < 0.85 then
                wantGlyph = true
            elseif b.tier == 2 and bHp < 0.55 and (eHeroes > 0 or eCreeps >= 3) then
                wantGlyph = true
            elseif b.tier == 1 and bHp < 0.35 and eHeroes > 0 then
                wantGlyph = true
            end
        end

        for _, actor in ipairs(snapshot.heroes or {}) do
            local profile = PROFILES[actor.name]
            local style = heroStyle(actor)
            local st = MEM.heroes[actor.position]
            if not st then
                st = {}
                MEM.heroes[actor.position] = st
            end

            local enemyDead = (snapshot.scoreboard and snapshot.scoreboard.enemyDeadCount) or 0
            local freeBossWindow = (macro.phase == "ROSHAN" or macro.phase == "TORMENTOR")
                and ((actor.level or 1) >= 12 or enemyDead >= 2)
            local rawRecovery = MACRO.recoveryFarm(snapshot, actor, st)
                and not macro.cleanPush
                and enemyDead < 3
                and not freeBossWindow
                and not (macro.phase == "DEFEND" and macro.urgent)
            local joinFight = rawRecovery and MACRO.pickRecoveryFight(snapshot, actor, st, basePos) or nil
            local recoveryFarm = rawRecovery and not joinFight
            local list = {}
            local byName = U.skillMap(actor)
            local gankTarget = not recoveryFarm and wardGank and wardGank.members[actor.id] and wardGank.target
            local nearEnemy = actor.alive and COMBAT.pickEnemyForActor(snapshot, actor, teamFocus) or nil
            if gankTarget and wardGank.ready then nearEnemy = gankTarget end
            if actor.alive then
                local custom = heroHook(actor, "PickTarget", snapshot, actor, nearEnemy)
                local target = type(custom) == "table" and COMBAT.visibleHero(snapshot, custom.id)
                if target and U.dist(actor.pos, target.pos) <= 1350 then nearEnemy = target end
            end
            local dropNearby = actor.alive and (U.nearest(snapshot.drops, actor.pos, 1000) ~= nil)

            local learn = INV.pickSkillToLearn(snapshot, actor, byName)
            if learn then list[#list + 1] = learn end

            for _, invAct in ipairs(INV.manageSlots(snapshot, actor, basePos, st, dropNearby)) do
                list[#list + 1] = invAct
            end

            local buy = INV.decideShopping(snapshot, actor, st, threats, nearEnemy, basePos, macro)
            if buy then list[#list + 1] = buy end

            local neutralAct = INV.decideNeutralChoice(snapshot, actor, threats)
            if neutralAct then list[#list + 1] = neutralAct end

            local iceRelease = COMBAT.releaseIceBlast(snapshot, actor, byName, st)
            if iceRelease then list[#list + 1] = iceRelease end
            if not actor.alive then
                st.lastStand, st.defensiveItem, st.duelTarget = nil, nil, nil
            end

            for _, cAct in ipairs(INV.decideCourier(snapshot, actor, st)) do
                list[#list + 1] = cAct
            end

            if wantGlyph and not glyphUsed then
                glyphUsed = true
                list[#list + 1] = { kind = "glyph", status = "Жму Glyph!" }
            end

            if not actor.alive and actor.buybackReady and macro.phase == "DEFEND" and macro.urgent
                and (actor.respawnTime or 0) > 12 and (actor.position <= 3 or (macro.building and macro.building.kind == "ancient")) then
                list[#list + 1] = { kind = "buyback", status = "Байбэк на базу!" }
            end

            if actor.alive and not actor.channeling and not actor.casting then
                local hp = U.ratio(actor.hp, actor.maxHp)
                local enemyCount = U.countNear(snapshot.enemies, actor.pos, 1000, U.isRealHero)
                local allyCount = U.countNear(snapshot.heroes, actor.pos, 1150, function(h)
                    return h.alive and h.id ~= actor.id
                end)
                local incomingAllies, incomingEnemies, landing = COMBAT.incomingTeleports(snapshot, actor)
                local supportedCount = allyCount + incomingAllies
                local hostileCount = enemyCount + incomingEnemies
                local tpThreat = landing and hostileCount > supportedCount + 1
                local heroGoal = macro.heroGoals and (macro.heroGoals[actor.id] or macro.heroGoals[actor.position])
                if recoveryFarm or macro.cleanPush then heroGoal = nil end
                local defendHere = not recoveryFarm and macro.phase == "DEFEND" and (not macro.localOnly
                    or (macro.building and U.dist(actor.pos, macro.building.pos) <= 1500))
                if not defendHere and not recoveryFarm and not macro.cleanPush then
                    local goal = heroHook(actor, "PlanHero", snapshot, actor, macro, heroGoal)
                    if goal == false then
                        heroGoal = nil
                    elseif type(goal) == "table" and (goal.mode == "laning" or mapPosition(goal.pos)
                        or (goal.mode == "attack" and finite(goal.targetId))
                        or (type(goal.intent) == "table" and type(goal.intent.kind) == "string")) then
                        heroGoal = goal
                    end
                end
                if joinFight then
                    if joinFight.mode == "tp" then
                        heroGoal = {
                            intent = {
                                kind = "tp",
                                position = joinFight.tpPos,
                                noWalkFallback = true,
                                status = "ТП на выгодный файт!",
                            },
                        }
                    else
                        heroGoal = {
                            mode = "gank",
                            pos = joinFight.pos,
                            status = "Подключаюсь к выгодному файту!",
                        }
                    end
                end
                local isLaning = recoveryFarm or macro.phase == "LANING" or (macro.localOnly and not defendHere)
                    or (heroGoal and heroGoal.mode == "laning")
                local atkRange = actor.attackRange or 200
                local dEnemy = nearEnemy and U.dist(actor.pos, nearEnemy.pos) or math.huge
                local damageTaken = (st.lastHp or actor.hp) - actor.hp
                local nearTargetEnemies = nearEnemy and U.countNear(snapshot.enemies, nearEnemy.pos, 1100, U.isRealHero) or 0
                local outnumbered = math.max(hostileCount, nearTargetEnemies) >= supportedCount + 3
                if outnumbered then st.regroupUntil = now + 3 end
                local waitForTeam = macro.regroup or outnumbered
                    or (st.regroupUntil and now < st.regroupUntil and supportedCount == 0)
                local underPressure = dEnemy <= 780 and (hp <= 0.55 or enemyCount > allyCount + 1
                    or (hp < 0.80 and damageTaken >= math.max(35, (actor.maxHp or 0) * 0.06)))
                local finishTarget = not actor.smoked and macro.phase ~= "BOUNTY_START"
                    and COMBAT.pickFinishTarget(snapshot, actor, hp, allyCount, hostileCount)
                local urgentTarget = finishTarget or (nearEnemy and dEnemy <= math.max(550, atkRange + 130)
                    and (nearEnemy.channeling or U.ratio(nearEnemy.hp, nearEnemy.maxHp) <= 0.23)
                    and COMBAT.isSafeFromTower(snapshot, actor, nearEnemy.pos, false))
                local fightingTower = nearEnemy and COMBAT.nearestEnemyTower(snapshot, nearEnemy.pos, TOWER_DANGER_RADIUS)
                local safeFight = nearEnemy and COMBAT.canFightUnderTower(snapshot, actor, nearEnemy, fightingTower,
                    allyCount, hostileCount, hp)
                local groupFight = not tpThreat and safeFight and supportedCount >= 1 and supportedCount + 1 >= hostileCount
                    and hp >= style.fightMinHp and dEnemy <= math.max(780, atkRange + 160)
                local followUp = st.followUpUntil and now < st.followUpUntil
                    and COMBAT.visibleHero(snapshot, st.followUpId)
                local canFollowUp = not tpThreat and COMBAT.canRightClick(followUp) and not actor.disarmed
                    and hp >= math.max(0.32, style.retreatHp) and hostileCount <= supportedCount + 1
                    and U.dist(actor.pos, followUp.pos) <= atkRange + 85
                    and (safeFight and nearEnemy.id == followUp.id
                        or COMBAT.isSafeFromTower(snapshot, actor, followUp.pos, false))
                local attackThrough = st.attackThrough and now < st.attackThrough
                    and COMBAT.visibleHero(snapshot, st.followUpId)
                local kiting = not groupFight and not canFollowUp and st.kiteUntil and now < st.kiteUntil and dEnemy < 900
                local prioritizeFarm = actor.position <= 3 and (isLaning or stagingPush) and not defendHere
                    and (not heroGoal or heroGoal.mode == "laning")
                    and not gankTarget and not underPressure and not urgentTarget and not kiting and not groupFight
                local assemblingGank = gankTarget and not wardGank.ready
                    and not underPressure and not urgentTarget and not kiting
                local waitingForWave = not MEM.waveArrived[actor.lane or "mid"]
                local waitingForMidWave = waitingForWave

                local dmgLh = (actor.attackDamage or 55) * 1.15
                local immediateLastHit = U.nearest(snapshot.enemies, actor.pos, atkRange + 220, function(u)
                    return U.isLaneCreep(u) and u.hp <= dmgLh and COMBAT.isSafeCreepAttack(snapshot, actor, u)
                end) ~= nil
                local blockSkillsForFarm = prioritizeFarm and (immediateLastHit or U.ratio(actor.mana, actor.maxMana) < 0.40)

                local manual = profile and profile.manualAbilities
                for _, ab in pairs(actor.abilities or {}) do
                    if ab and ab.name and not ab.hidden and (ab.level or 0) > 0
                        and not (manual and manual[ab.name])
                        and ab.autoCast ~= nil and hasBit(ab.behavior, B_AUTOCAST) then
                        local wantOrb = not waitingForMidWave and not immediateLastHit and not assemblingGank
                            and nearEnemy ~= nil and ((actor.maxMana or 0) <= 0 or U.ratio(actor.mana, actor.maxMana) > 0.20)
                        if wantOrb ~= ab.autoCast then
                            list[#list + 1] = { kind = "autocast", ability = ab.name }
                        end
                    end
                end
                local main
                if waitForTeam then
                    st.lastStand, st.defensiveItem = nil, nil
                    main = LANE.waitForAllies(snapshot, actor, st, farm, nearEnemy, basePos, defendHere and macro.urgent)
                else
                    main = COMBAT.defensiveFight(actor, finishTarget or nearEnemy, hp, now, st)
                end

                if not main and tpThreat then
                    local homeward = U.towards(actor.pos, basePos, 700)
                    local ally = U.nearest(snapshot.heroes, actor.pos, 2300, function(h)
                        return h.id ~= actor.id and U.dist(h.pos, landing.pos) > U.dist(actor.pos, landing.pos) + 200
                    end)
                    local back = ally and U.towards(actor.pos, ally.pos, 700)
                        or (U.dist(homeward, landing.pos) > U.dist(actor.pos, landing.pos) and homeward
                            or U.away(actor.pos, landing.pos, 700))
                    main = { kind = "move", position = back, status = "Отхожу от вражеских ТП" }
                end
                local fromTowerSafety = false
                if not main and not finishTarget then
                    local coveredSiege = dEnemy > math.max(700, atkRange + 120) and siegeReady
                        and U.dist(actor.pos, macro.pos) <= 1250
                    main = COMBAT.checkTowerSafety(snapshot, actor, basePos, st,
                        groupFight or canFollowUp or coveredSiege, enemyCount, allyCount, macro)
                    fromTowerSafety = main ~= nil
                end
                if not main and not finishTarget and not groupFight and not canFollowUp
                    and (isLaning or (now >= 8 and now < 600)) then
                    main = COMBAT.checkLaneCreepAggro(snapshot, actor, basePos)
                end

                local env
                if not main and (type(tactic.OverrideHero) == "function" or (profile
                    and (profile.OverrideHero or profile.UseItems or profile.UseAbilities))) then
                    env = {
                        macro = macro,
                        goal = heroGoal,
                        enemy = nearEnemy,
                        enemyCount = enemyCount,
                        allyCount = allyCount,
                        threats = threats,
                        basePos = basePos,
                        skills = byName,
                        situation = macro.situation,
                        readiness = COMBAT.teamFightReadiness(snapshot, actor.pos, 1450),
                        myReadiness = COMBAT.heroCombatReadiness(actor),
                        directive = MEM.comms.directive,
                        finishTarget = finishTarget or nil,
                        prioritizeFarm = prioritizeFarm,
                        isLaning = isLaning,
                        defending = defendHere,
                        waitingForWave = waitingForWave,
                        immediateLastHit = immediateLastHit,
                        underPressure = underPressure,
                        recoveryFarm = recoveryFarm,
                        incomingAllies = incomingAllies,
                        incomingEnemies = incomingEnemies,
                    }
                    local customAct = heroHook(actor, "OverrideHero", snapshot, actor, env)
                    if type(customAct) ~= "table" or type(customAct.kind) ~= "string" then
                        customAct = safeHook(tactic.OverrideHero, snapshot, actor, env)
                    end
                    if type(customAct) == "table" and type(customAct.kind) == "string" then
                        main = customAct
                    end
                end

                if not main and not finishTarget and not canFollowUp and not groupFight
                    and (macro.phase == "BOUNTY_START" or waitingForWave) then
                    main = LANE.decidePreGame(snapshot, actor, nearEnemy, enemyCount, allyCount, basePos)
                end

                -- Надёжное добивание с руки не откладываем ради ещё одной способности.
                if not main and finishTarget then
                    main = { kind = "attack", target_id = finishTarget.id, status = "Добиваю с руки" }
                end
                if not main and not assemblingGank then
                    main = COMBAT.legionDuel(snapshot, actor, byName, nearEnemy, allyCount, st)
                end
                if not main and canFollowUp then
                    st.followUpUntil = nil
                    st.attackThrough = now + (actor.attackPoint or 0.35) + 0.25
                    main = { kind = "attack", target_id = followUp.id, status = "Бью после способности" }
                end
                if not main and COMBAT.canRightClick(attackThrough) and not actor.disarmed
                    and U.dist(actor.pos, attackThrough.pos) <= atkRange + 125 then
                    main = { kind = "attack", target_id = attackThrough.id, status = "Бью после способности" }
                end

                -- 3. Базовые активные предметы и скиллы
                if not main then
                    local custom = COMBAT.profileCast(actor, byName,
                        heroHook(actor, "UseItems", snapshot, actor, env), "item")
                    if custom == nil then
                        main = COMBAT.decideActiveItem(snapshot, actor, nearEnemy, enemyCount, allyCount, threats,
                            not recoveryFarm and macro or { phase = "LANING" },
                            blockSkillsForFarm or assemblingGank)
                    elseif custom then
                        main = custom
                    end
                end
                if not main then
                    local custom = COMBAT.profileCast(actor, byName,
                        heroHook(actor, "UseAbilities", snapshot, actor, env), "ability")
                    if custom == nil then
                        main = (not assemblingGank and COMBAT.startIceBlast(snapshot, actor, byName, st))
                            or COMBAT.decideSkillCast(snapshot, actor, byName, nearEnemy, enemyCount, allyCount,
                                not recoveryFarm and macro or { phase = "LANING" },
                                blockSkillsForFarm or assemblingGank)
                    elseif custom then
                        main = custom
                    end
                end

                -- 4. Отступление с гистерезисом
                if not main then
                    local myR = COMBAT.heroCombatReadiness(actor)
                    local distBase = U.dist(actor.pos, basePos)
                    local nearBaseOom = myR.isOom and (actor.position >= 4 or actor.position == 2)
                        and not actor.hasClarity and not U.hasItem(actor, "item_clarity", true)
                        and not U.hasItem(actor, "item_bottle", true)
                        and distBase < 2800 and enemyCount == 0 and not defendHere
                    local dangerLow = hp < style.retreatHp
                        or (hp < style.retreatHp + 0.14 and enemyCount > allyCount + 1)
                        or nearBaseOom
                    if dangerLow then st.retreat = true end
                    if st.retreat then
                        local atFountain = distBase <= 900
                        local manaOk = (not atFountain) or (actor.maxMana or 0) < 150 or U.ratio(actor.mana, actor.maxMana) >= 0.65
                        if groupFight or canFollowUp or (hp >= style.reengageHp and manaOk)
                            or (hp >= 0.52 and not myR.isOom and enemyCount == 0 and distBase > 2500) then
                            st.retreat = false
                        else
                            main = distBase > 450
                                and { kind = "move", position = basePos, status = nearBaseOom and "На базу за маной" or "Отступаю" }
                                or { kind = "hold", status = "Регенюсь на базе" }
                        end
                    end
                end

                if not main and not macro.cleanPush and not defendHere and not nearEnemy then
                    local courier = actor.courier
                    local delayed = courier and not courier.alive and (courier.hasCargo or courier.hasStash)
                    local importantCargo = false
                    for _, item in ipairs(delayed and courier.carrying or {}) do
                        if itemVal(item) >= 590 then importantCargo = true; break end
                    end
                    if st.shopItem and st.lastShopSale ~= st.shopItem and actor.atHomeShop == false then
                        main = { kind = "move", position = basePos, status = "Возвращаюсь в магазин за апгрейдом" }
                    elseif delayed and not actor.atHomeShop and (not INV.getTpState(actor).hasTp
                        or (importantCargo and macro.phase == "LANING")) then
                        main = LANE.waitForAllies(snapshot, actor, st, farm, nil, basePos, false)
                        if main.kind == "hold" then main.status = "В безопасном месте жду курьера" end
                    end
                end

                if not main and not st.retreat and not groupFight and not joinFight then
                    main = LANE.decideFountainExit(snapshot, actor, st, not recoveryFarm and macro or nil, basePos)
                end

                if not main and gankTarget and not underPressure and not kiting then
                    if wardGank.ready and COMBAT.canRightClick(gankTarget) then
                        main = { kind = "attack", target_id = gankTarget.id, status = "Ганг по обзору" }
                    elseif assemblingGank then
                        main = U.dist(actor.pos, wardGank.rendezvous) > 140
                            and { kind = "move", position = wardGank.rendezvous, status = "Собираюсь на ганг" }
                            or { kind = "hold", status = "Жду союзников для ганга" }
                    end
                end

                -- 5. Приоритет драки с гистерезисом и учётом КД скиллов/ультов команды
                if not main and COMBAT.canRightClick(nearEnemy) and not actor.disarmed
                    and (not prioritizeFarm or canFollowUp) then
                    local tookHit = damageTaken >= 20 and dEnemy <= 750
                    local myReady = COMBAT.heroCombatReadiness(actor)
                    local teamReady = COMBAT.teamFightReadiness(snapshot, actor.pos, 1450)

                    local engageDist = isLaning and math.max(460, atkRange + 160) or 900
                    local canFinish = U.ratio(nearEnemy.hp, nearEnemy.maxHp) < 0.35 and hp >= 0.28 and dEnemy <= 720
                    local enemyMana = COMBAT.analyzeEnemyMana(nearEnemy)
                    local effFightHp = (enemyMana.isOom or enemyMana.noEscapeMana or enemyMana.isMedusaLow)
                        and math.max(0.26, style.fightMinHp - 0.08) or style.fightMinHp
                    local canFight = groupFight or ((supportedCount + 1 >= hostileCount) and hp >= effFightHp)

                    -- Если враг-эскейпер или кастер без маны — добираем его смелее
                    if (enemyMana.noEscapeMana or enemyMana.isMedusaLow) and hp >= 0.35 and (allyCount + 1 >= enemyCount) then
                        canFight = true
                    end

                    local activeDir = MEM.comms.directive
                    if activeDir and (activeDir.kind == "WAIT_ITEM" or activeDir.kind == "WAIT_ULT")
                        and not groupFight and not canFinish and not defendHere and (supportedCount + 1 <= hostileCount) then
                        canFight = false
                    end

                    local cdDisengageReason = nil
                    if style.respectCooldowns ~= false and not groupFight and not canFinish and not defendHere then
                        if hostileCount >= 2 and teamReady.shouldAvoidBigFight and (supportedCount + 1 <= hostileCount)
                            and not enemyMana.isOom then
                            canFight = false
                            cdDisengageReason = teamReady.teamOom and "Нет маны у команды" or "Жду КД ультов"
                        elseif (myReady.noSpells or myReady.isOom) and (actor.position >= 4 or hp < 0.65)
                            and (supportedCount + 1 <= hostileCount) and not enemyMana.isOom then
                            canFight = false
                            cdDisengageReason = myReady.isOom and "Нет маны — отход" or "Жду КД скиллов"
                        end
                    end

                    local safeFromTower = safeFight or COMBAT.isSafeFromTower(snapshot, actor, nearEnemy.pos, false)

                    local sit = macro.situation
                    local enemySpentButtons = sit and ((sit.enemyUltsDown or 0) >= 2 or (sit.enemyBkbDown or 0) >= 1)
                    if enemySpentButtons and hp >= style.fightMinHp - 0.05 and (allyCount + 1 >= enemyCount) then
                        canFight = true
                    end

                    -- Если свои/союзные кнопки в КД, но откатятся через <= 4.5 сек — НЕ убегаем на базу, а держим безопасную дистанцию ~760
                    local waitingShortCd = false
                    if not canFight and not canFinish and not defendHere and hp >= 0.45
                        and (myReady.spellsAlmostReady or teamReady.almostReady) then
                        waitingShortCd = true
                    end

                    if waitingShortCd then
                        local waitSec = math.max(1, math.ceil(
                            (myReady.soonestReadyIn > 0 and myReady.soonestReadyIn) or teamReady.soonestIn or 2
                        ))
                        local holdDist = math.max(680, atkRange + 160)
                        if dEnemy < holdDist - 60 then
                            main = { kind = "move", position = U.towards(actor.pos, basePos, 320),
                                status = string.format("Кайчу под откат (%dс)", waitSec) }
                        elseif dEnemy > holdDist + 220 then
                            main = { kind = "move", position = U.towards(actor.pos, nearEnemy.pos, 260),
                                status = string.format("Жду откат (%dс)", waitSec) }
                        else
                            main = { kind = "hold", status = string.format("Жду откат (%dс)", waitSec) }
                        end
                    elseif kiting then
                        main = { kind = "move", position = U.towards(actor.pos, basePos, 500), status = cdDisengageReason or "Отхожу из невыгодной драки" }
                    elseif (not canFight and not canFinish) and (tookHit or dEnemy <= 620) then
                        st.kiteUntil = now + 1.5
                        st.fightUntil = nil
                        main = { kind = "move", position = U.towards(actor.pos, basePos, 500), status = cdDisengageReason or "Отхожу из невыгодной драки" }
                    elseif safeFromTower and (canFight or canFinish) then
                        local lockedFight = st.fightUntil and now < st.fightUntil and dEnemy <= engageDist + 160
                        if dEnemy <= engageDist or canFinish or tookHit or lockedFight then
                            if not lockedFight then st.fightUntil = now + 1.0 end
                            main = { kind = "attack", target_id = nearEnemy.id, status = "Дерусь с врагом!" }
                        end
                    end
                elseif not nearEnemy then
                    st.kiteUntil = nil
                    st.fightUntil = nil
                end

                if not main and (siegeReady or (st.tankingTower and macro.phase == "PUSH" and macro.targetId))
                    and not recoveryFarm and dEnemy > 850 and U.dist(actor.pos, macro.pos) <= 1400 then
                    main = { kind = "attack", target_id = macro.targetId,
                        status = st.tankingTower and "Танкую и ломаю постройку" or "Ломаю постройку" }
                end

                -- 6. Персональная цель из tactic.PlanMacro (heroGoals)
                local forceLaning = false
                if not main and heroGoal and not macro.cleanPush then
                    local gAct = LANE.executeHeroGoal(snapshot, actor, heroGoal, nearEnemy, allyCount, basePos)
                    if gAct == "FORCE_LANING" then
                        forceLaning = true
                    elseif gAct then
                        main = gAct
                    end
                end

                if not main and not forceLaning and not recoveryFarm and macro.targetUnit and macro.readyToAttack
                    and enemyCount == 0 and incomingEnemies == 0
                    and (macro.phase == "ROSHAN" or macro.phase == "TORMENTOR") then
                    main = COMBAT.bossCast(snapshot, actor, macro, st, allyCount)
                end

                -- 7. Вардинг и девардинг
                if not main and not recoveryFarm and not macro.cleanPush then
                    main = LANE.decideWarding(snapshot, actor, st, threats, enemyCount, macro, defendHere)
                end

                local bossPlan = macro.bossPlan
                if not main and not recoveryFarm and not forceLaning and bossPlan
                    and bossPlan.scoutId == actor.id and enemyCount == 0 then
                    if U.dist(actor.pos, bossPlan.pos) <= 650 then
                        MEM.bossScoutAfter[bossPlan.kind][bossPlan.side] = now + 75
                    else
                        local walkTime = U.dist(actor.pos, bossPlan.pos) / math.max(actor.moveSpeed or 300, 200)
                        if bossPlan.readyAt - now <= walkTime + 6 then
                            main = { kind = "move", position = bossPlan.pos,
                                status = "Проверяю " .. bossName(bossPlan.kind, "acc") }
                        end
                    end
                end

                -- Пока нет драки или волны для осады, коры выбирают доступную волну или кемп.
                if not main and prioritizeFarm and enemyCount == 0 and (isLaning or style.farmWhileStaging)
                    and (recoveryFarm or not (bossPlan and bossPlan.scoutId == actor.id)) then
                    main = LANE.decideObjectives(snapshot, actor, enemyCount, true)
                        or LANE.decideLaning(snapshot, actor, st, nearEnemy, enemyCount, allyCount, basePos, true, farm)
                end
                if not main and recoveryFarm and enemyCount == 0 then
                    -- 1. Ищем доступный кемп в своём лесу по всей своей половине карты
                    main = LANE.decideJungle(snapshot, actor, st, farm, nil, 9000)

                    -- 2. Если лес зачищен — идём на безопасную вражескую волну на нашей половине
                    if not main then
                        local isRadiant = (basePos.x + basePos.y) < 0
                        local safeWave = U.nearest(snapshot.enemies, actor.pos, 9000, function(u)
                            local onOwnSide = isRadiant and ((u.pos.x + u.pos.y) <= 1200)
                                or ((u.pos.x + u.pos.y) >= -1200)
                            return U.isLaneCreep(u) and onOwnSide
                                and COMBAT.isSafeCreepAttack(snapshot, actor, u)
                                and not U.nearest(snapshot.enemies, u.pos, 1500, U.isRealHero)
                        end)
                        if safeWave then
                            main = { kind = "move", position = safeWave.pos, status = "Иду на безопасную волну" }
                        end
                    end

                    -- 3. Если ХП ниже порога леса (55%) и нет волн — дохиливаемся на фонтане, чтобы открыть лес
                    if not main and U.ratio(actor.hp, actor.maxHp) < style.jungleMinHp then
                        main = U.dist(actor.pos, basePos) > 450
                            and { kind = "move", position = basePos, status = "Лечусь перед фармом леса" }
                            or { kind = "hold", status = "Регенюсь перед фармом" }
                    end

                    -- 4. Ждём только у внешних башен T1–T3 (исключаем T4 через u.tier <= 3)
                    if not main then
                        local shelter, bestRank
                        for _, u in ipairs(snapshot.allies or {}) do
                            if u.kind == "tower" and u.alive ~= false and u.tier and u.tier <= 3
                                and not U.nearest(snapshot.enemies, u.pos, 1500, U.isRealHero) then
                                local rank = u.tier * 10000 + U.dist(actor.pos, u.pos)
                                if not bestRank or rank < bestRank then
                                    shelter, bestRank = u, rank
                                end
                            end
                        end
                        if shelter then
                            main = U.dist(actor.pos, shelter.pos) > 500
                                and { kind = "move", position = shelter.pos, status = "Ищу безопасный фарм" }
                                or { kind = "hold", status = "Жду безопасную волну или кемп" }
                        end
                    end
                end

                -- 9. Объекты карты (руны, лотосы, святилища, дропы)
                if not main and not recoveryFarm and not macro.cleanPush and not defendHere
                    and macro.phase ~= "ROSHAN" and macro.phase ~= "TORMENTOR" then
                    main = LANE.decideObjectives(snapshot, actor, enemyCount)
                end

                -- 10. Командное макро
                if not main and not recoveryFarm and not forceLaning and (defendHere or macro.phase == "ROSHAN"
                    or macro.phase == "TORMENTOR" or macro.phase == "PUSH" or macro.phase == "SMOKE_GANK") then
                    main = LANE.decideMacroMove(snapshot, actor, macro, nearEnemy, enemyCount, allyCount, basePos, prioritizeFarm, st)
                end

                -- 11. Лайнинг, ластхит, денай и позиционирование
                if not main then
                    main = LANE.decideLaning(snapshot, actor, st, nearEnemy, enemyCount, allyCount, basePos, prioritizeFarm,
                        recoveryFarm and farm or nil)
                end

                if main and not fromTowerSafety and not st.tankingTower
                    and (main.kind == "move" or main.kind == "attack_move") and main.position then
                    local detour = COMBAT.detourAroundTowers(snapshot, actor, main.position, st)
                    if detour then
                        main = { kind = "move", position = detour, status = "Обхожу вышку" }
                    end
                end

                if main and main.kind == "tp" then
                    local pending = st.tpAttempt
                    if not pending or U.dist(pending.pos, main.position) > 100 then
                        pending = { pos = main.position, at = now }
                        st.tpAttempt = pending
                    end
                    if not INV.getTpState(actor).ready or (st.tpRetryAt or 0) > now
                        or now - pending.at >= 0.6 then
                        if (st.tpRetryAt or 0) <= now then st.tpRetryAt = now + 6 end
                        st.tpAttempt = nil
                        local walk = not main.noWalkFallback and (main.fallbackPosition or main.position) or nil
                        if mapPosition(walk) then
                            main = { kind = "attack_move", position = walk, status = "Иду пешком, ТП недоступен" }
                        else
                            main = nil
                        end
                    end
                else
                    st.tpAttempt = nil
                end

                if main then
                    if main.kind == "cast" and nearEnemy and COMBAT.canRightClick(nearEnemy)
                        and (main.target_id == nearEnemy.id
                            or (main.position and U.dist(main.position, nearEnemy.pos) <= 320)
                            or (main.ability and not main.target_id and not main.position and dEnemy <= atkRange + 85)) then
                        st.followUpId = nearEnemy.id
                        st.followUpUntil = now + 2.8
                    end
                    list[#list + 1] = main
                end
            end
            if not actor.alive or actor.channeling then st.tpAttempt = nil end

            st.lastHp = actor.alive and actor.hp or actor.maxHp
            if #list > 0 then
                actions[actor.id] = list
            end
        end

        local chat = Comms.flushChat(snapshot, MEM.comms)
        if chat then
            local actors, lines = {}, {}
            for _, actor in ipairs(snapshot.heroes or {}) do actors[actor.id] = actor end
            for _, msg in ipairs(chat) do
                local actor = actors[msg.heroId]
                local profile = actor and PROFILES[actor.name]
                if not profile or profile.chat ~= false then
                    local text = actor and heroHook(actor, "FormatChat", snapshot, actor, shallowCopy(msg))
                    if text == nil then text = safeHook(tactic.FormatChat, snapshot, actor, shallowCopy(msg)) end
                    if text ~= false then
                        if type(text) == "string" and text ~= "" then msg.text = text end
                        lines[#lines + 1] = msg
                    end
                end
            end
            if #lines > 0 then actions._chat = lines end
        end

        if MEM.lastHookError then
            actions._hookError = MEM.lastHookError
            MEM.lastHookError = nil
        end

        return actions
    end

    return Team
end

return BaseBot
