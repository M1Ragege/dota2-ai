local Talents = require("sdk/dota_base/talents")
local Team = {}

Team.name = "Gemini_742_Apex"

Team.draft = {
    { "npc_dota_hero_juggernaut", "npc_dota_hero_sven", "npc_dota_hero_luna", "npc_dota_hero_ursa" },
    { "npc_dota_hero_queenofpain", "npc_dota_hero_viper", "npc_dota_hero_dragon_knight", "npc_dota_hero_lina" },
    { "npc_dota_hero_tidehunter", "npc_dota_hero_centaur", "npc_dota_hero_axe", "npc_dota_hero_mars" },
    { "npc_dota_hero_jakiro", "npc_dota_hero_earthshaker", "npc_dota_hero_lion", "npc_dota_hero_skywrath_mage" },
    { "npc_dota_hero_witch_doctor", "npc_dota_hero_crystal_maiden", "npc_dota_hero_ogre_magi", "npc_dota_hero_lich" }
}

Team.const = {
    TOWER_RANGE = 700,
    TOWER_BUFFER = 845,
    TOWER_AGGRO_RANGE = 780,
    CREEP_TANK_MIN_HP = 135,
    SWAP_CD = 6.6,
    WARD_CD = 3.5,
    DUST_CD = 4.0,
    SMOKE_CD = 60.0,
    FOUNTAIN = {
        [2] = { x = -6750, y = -6750, z = 256 },
        [3] = { x = 6750, y = 6750, z = 256 }
    },
    ANCIENT = {
        [2] = { x = -5850, y = -5350, z = 256 },
        [3] = { x = 5800, y = 5250, z = 256 }
    },
    INVIS_HEROES = {
        npc_dota_hero_riki = true, npc_dota_hero_bounty_hunter = true, npc_dota_hero_clinkz = true,
        npc_dota_hero_nyx_assassin = true, npc_dota_hero_weaver = true, npc_dota_hero_invoker = true,
        npc_dota_hero_mirana = true, npc_dota_hero_sand_king = true, npc_dota_hero_slark = true,
        npc_dota_hero_treant = true, npc_dota_hero_hoodwink = true, npc_dota_hero_phantom_assassin = true
    },
    INVIS_ITEMS = {
        item_invis_sword = true, item_silver_edge = true, item_glimmer_cape = true, item_shadow_amulet = true
    },
    EVASION_HEROES = {
        npc_dota_hero_phantom_assassin = true, npc_dota_hero_windrunner = true,
        npc_dota_hero_brewmaster = true, npc_dota_hero_arc_warden = true
    },
    EVASION_ITEMS = {
        item_butterfly = true, item_radiance = true, item_heavens_halberd = true
    },
    HEAL_HEROES = {
        npc_dota_hero_necrolyte = true, npc_dota_hero_alchemist = true, npc_dota_hero_huskar = true,
        npc_dota_hero_bristleback = true, npc_dota_hero_morphling = true, npc_dota_hero_oracle = true,
        npc_dota_hero_abaddon = true, npc_dota_hero_dragon_knight = true
    },
    ILLUSION_HEROES = {
        npc_dota_hero_phantom_lancer = true, npc_dota_hero_naga_siren = true,
        npc_dota_hero_chaos_knight = true, npc_dota_hero_terrorblade = true
    },
    ITEM_VALUES = {
        item_branches = 50, item_clarity = 50, item_faerie_fire = 65, item_enchanted_mango = 65,
        item_flask = 110, item_smoke_of_deceit = 120, item_quelling_blade = 130,
        item_gauntlets = 140, item_slippers = 140, item_mantle = 140, item_circlet = 155,
        item_ring_of_protection = 175, item_magic_stick = 200, item_dust = 230,
        item_ward_sentry = 240, item_famango = 260, item_ward_observer = 290, item_ward_dispenser = 350,
        item_magic_wand = 460, item_great_famango = 480, item_boots = 500,
        item_wraith_band = 510, item_bracer = 510, item_null_talisman = 510,
        item_bottle = 675, item_greater_famango = 750, item_soul_ring = 805,
        item_tranquil_boots = 925, item_arcane_boots = 1300, item_power_treads = 1400,
        item_aghanims_shard = 1400, item_phase_boots = 1500, item_vanguard = 1700,
        item_mask_of_madness = 1900, item_blade_mail = 2100, item_glimmer_cape = 2150,
        item_force_staff = 2200, item_blink = 2250, item_aether_lens = 2275,
        item_gem = 2450, item_echo_sabre = 2500, item_cyclone = 2725, item_witch_blade = 2775,
        item_spirit_vessel = 2780, item_mage_slayer = 2825, item_maelstrom = 2950,
        item_aeon_disk = 3000, item_pipe = 3725, item_crimson_guard = 3725,
        item_lotus_orb = 3850, item_black_king_bar = 4050, item_kaya_and_sange = 4100,
        item_ultimate_scepter = 4200, item_hurricane_pike = 4450, item_manta = 4600,
        item_harpoon = 4700, item_monkey_king_bar = 4700, item_octarine_core = 4800,
        item_refresher = 5000, item_satanic = 5050, item_assault = 5125, item_daedalus = 5150,
        item_shivas_guard = 5175, item_heart = 5200, item_sheepstick = 5200,
        item_skadi = 5300, item_butterfly = 5450, item_mjollnir = 5500, item_parasma = 5975,
        item_abyssal_blade = 6250, item_bloodthorn = 6625, item_overwhelming_blink = 6800,
        item_rapier = 7500, item_cheese = 8000, item_roshans_banner = 8200,
        item_refresher_shard = 8500, item_horn_of_battle_greater = 8600, item_aegis = 9999
    },
    CONSUMABLES = {
        item_flask = true, item_clarity = true, item_faerie_fire = true, item_enchanted_mango = true,
        item_dust = true, item_ward_observer = true, item_ward_sentry = true, item_ward_dispenser = true,
        item_smoke_of_deceit = true, item_famango = true, item_great_famango = true, item_greater_famango = true
    }
}

Team.heroes = {
    npc_dota_hero_juggernaut = {
        skills = { "juggernaut_blade_fury", "juggernaut_blade_dance", "juggernaut_healing_ward", "juggernaut_omni_slash" },
        build = {
            "item_quelling_blade", "item_slippers", "item_circlet", "item_branches", "item_flask", "item_faerie_fire",
            "item_wraith_band", "item_magic_wand", "item_phase_boots", "item_maelstrom",
            "item_manta", "item_black_king_bar", "item_mjollnir", "item_aghanims_shard",
            "item_butterfly", "item_abyssal_blade", "item_satanic"
        },
        casts = {
            { name = "juggernaut_omni_slash", kind = "ult_single", range = 450, minHpPct = 0.0, maxTargetHpPct = 0.90 },
            { name = "juggernaut_blade_fury", kind = "aoe_self", range = 360 },
            { name = "juggernaut_healing_ward", kind = "heal_ward", range = 400 }
        }
    },
    npc_dota_hero_sven = {
        skills = { "sven_storm_bolt", "sven_great_cleave", "sven_warcry", "sven_gods_strength" },
        build = {
            "item_quelling_blade", "item_gauntlets", "item_circlet", "item_branches", "item_flask", "item_enchanted_mango",
            "item_bracer", "item_magic_wand", "item_power_treads", "item_echo_sabre",
            "item_blink", "item_black_king_bar", "item_harpoon", "item_daedalus",
            "item_satanic", "item_assault"
        },
        casts = {
            { name = "sven_gods_strength", kind = "self_buff", range = 800 },
            { name = "sven_storm_bolt", kind = "stun_target", range = 600 },
            { name = "sven_warcry", kind = "self_buff", range = 700 }
        }
    },
    npc_dota_hero_luna = {
        skills = { "luna_lucent_beam", "luna_lunar_blessing", "luna_moon_glaive", "luna_eclipse" },
        build = {
            "item_slippers", "item_circlet", "item_branches", "item_flask", "item_enchanted_mango", "item_faerie_fire",
            "item_wraith_band", "item_magic_wand", "item_power_treads", "item_mask_of_madness",
            "item_manta", "item_black_king_bar", "item_butterfly", "item_aghanims_shard",
            "item_satanic", "item_skadi"
        },
        casts = {
            { name = "luna_eclipse", kind = "ult_aoe", range = 675, minEnemies = 2 },
            { name = "luna_lucent_beam", kind = "nuke_target", range = 800 }
        }
    },
    npc_dota_hero_ursa = {
        skills = { "ursa_fury_swipes", "ursa_overpower", "ursa_earthshock", "ursa_enrage" },
        build = {
            "item_quelling_blade", "item_circlet", "item_branches", "item_flask", "item_enchanted_mango", "item_faerie_fire",
            "item_magic_wand", "item_phase_boots", "item_blink", "item_black_king_bar",
            "item_abyssal_blade", "item_aghanims_shard", "item_satanic", "item_swift_blink"
        },
        casts = {
            { name = "ursa_enrage", kind = "def_buff", range = 700 },
            { name = "ursa_overpower", kind = "self_buff", range = 600 },
            { name = "ursa_earthshock", kind = "aoe_self", range = 385 }
        }
    },
    npc_dota_hero_queenofpain = {
        skills = { "queenofpain_scream_of_pain", "queenofpain_shadow_strike", "queenofpain_blink", "queenofpain_sonic_wave" },
        build = {
            "item_mantle", "item_circlet", "item_branches", "item_flask", "item_faerie_fire", "item_enchanted_mango",
            "item_null_talisman", "item_bottle", "item_magic_wand", "item_power_treads",
            "item_witch_blade", "item_kaya_and_sange", "item_black_king_bar", "item_shivas_guard",
            "item_parasma", "item_sheepstick"
        },
        casts = {
            { name = "queenofpain_sonic_wave", kind = "ult_point", range = 850, minEnemies = 2 },
            { name = "queenofpain_scream_of_pain", kind = "aoe_self", range = 525 },
            { name = "queenofpain_shadow_strike", kind = "nuke_target", range = 550 },
            { name = "queenofpain_blink", kind = "mobility", range = 1050 }
        }
    },
    npc_dota_hero_viper = {
        skills = { "viper_poison_attack", "viper_nethertoxin", "viper_corrosive_skin", "viper_viper_strike" },
        build = {
            "item_circlet", "item_branches", "item_branches", "item_flask", "item_enchanted_mango", "item_faerie_fire",
            "item_wraith_band", "item_magic_wand", "item_power_treads", "item_mage_slayer",
            "item_hurricane_pike", "item_black_king_bar", "item_aghanims_shard", "item_shivas_guard",
            "item_butterfly", "item_skadi"
        },
        casts = {
            { name = "viper_viper_strike", kind = "ult_single", range = 550 },
            { name = "viper_nethertoxin", kind = "aoe_point", range = 850 },
            { name = "viper_poison_attack", kind = "orb", range = 575 }
        }
    },
    npc_dota_hero_dragon_knight = {
        skills = { "dragon_knight_breathe_fire", "dragon_knight_wyrms_wrath", "dragon_knight_dragon_tail", "dragon_knight_elder_dragon_form" },
        build = {
            "item_quelling_blade", "item_gauntlets", "item_circlet", "item_branches", "item_flask", "item_enchanted_mango",
            "item_bracer", "item_magic_wand", "item_power_treads", "item_mage_slayer",
            "item_blink", "item_black_king_bar", "item_assault", "item_daedalus", "item_satanic"
        },
        casts = {
            { name = "dragon_knight_elder_dragon_form", kind = "self_buff", range = 900 },
            { name = "dragon_knight_dragon_tail", kind = "stun_target", range = 400 },
            { name = "dragon_knight_breathe_fire", kind = "aoe_point", range = 650 }
        }
    },
    npc_dota_hero_lina = {
        skills = { "lina_dragon_slave", "lina_light_strike_array", "lina_fiery_soul", "lina_laguna_blade" },
        build = {
            "item_mantle", "item_circlet", "item_branches", "item_flask", "item_faerie_fire", "item_clarity",
            "item_null_talisman", "item_bottle", "item_magic_wand", "item_arcane_boots",
            "item_cyclone", "item_black_king_bar", "item_ultimate_scepter", "item_sheepstick", "item_daedalus"
        },
        casts = {
            { name = "lina_laguna_blade", kind = "ult_single", range = 600, maxTargetHpPct = 0.78 },
            { name = "lina_light_strike_array", kind = "stun_point", range = 625 },
            { name = "lina_dragon_slave", kind = "aoe_point", range = 950 }
        }
    },
    npc_dota_hero_tidehunter = {
        skills = { "tidehunter_anchor_smash", "tidehunter_kraken_shell", "tidehunter_gush", "tidehunter_ravage" },
        build = {
            "item_quelling_blade", "item_gauntlets", "item_circlet", "item_branches", "item_flask", "item_enchanted_mango",
            "item_bracer", "item_magic_wand", "item_arcane_boots", "item_blink",
            "item_pipe", "item_shivas_guard", "item_aghanims_shard", "item_refresher", "item_octarine_core"
        },
        casts = {
            { name = "tidehunter_ravage", kind = "ult_aoe", range = 950, minEnemies = 2 },
            { name = "tidehunter_gush", kind = "nuke_target", range = 700 },
            { name = "tidehunter_anchor_smash", kind = "aoe_self", range = 375 }
        }
    },
    npc_dota_hero_centaur = {
        skills = { "centaur_hoof_stomp", "centaur_double_edge", "centaur_return", "centaur_stampede" },
        build = {
            "item_quelling_blade", "item_ring_of_protection", "item_gauntlets", "item_branches", "item_flask", "item_faerie_fire",
            "item_bracer", "item_magic_wand", "item_phase_boots", "item_vanguard",
            "item_blink", "item_blade_mail", "item_crimson_guard", "item_pipe", "item_heart", "item_overwhelming_blink"
        },
        casts = {
            { name = "centaur_stampede", kind = "team_buff", range = 1200 },
            { name = "centaur_hoof_stomp", kind = "stun_self", range = 330 },
            { name = "centaur_double_edge", kind = "nuke_target", range = 220 }
        }
    },
    npc_dota_hero_axe = {
        skills = { "axe_counter_helix", "axe_berserkers_call", "axe_battle_hunger", "axe_culling_blade" },
        build = {
            "item_quelling_blade", "item_ring_of_protection", "item_gauntlets", "item_branches", "item_flask", "item_faerie_fire",
            "item_bracer", "item_magic_wand", "item_phase_boots", "item_vanguard",
            "item_blink", "item_blade_mail", "item_black_king_bar", "item_crimson_guard", "item_shivas_guard", "item_heart"
        },
        casts = {
            { name = "axe_culling_blade", kind = "execute", range = 225, thresh = 320 },
            { name = "axe_berserkers_call", kind = "stun_self", range = 310 },
            { name = "axe_battle_hunger", kind = "nuke_target", range = 700 }
        }
    },
    npc_dota_hero_mars = {
        skills = { "mars_spear", "mars_gods_rebuke", "mars_bulwark", "mars_arena_of_blood" },
        build = {
            "item_quelling_blade", "item_gauntlets", "item_circlet", "item_branches", "item_flask", "item_enchanted_mango",
            "item_bracer", "item_magic_wand", "item_phase_boots", "item_soul_ring",
            "item_blink", "item_black_king_bar", "item_pipe", "item_shivas_guard", "item_refresher"
        },
        casts = {
            { name = "mars_arena_of_blood", kind = "ult_point", range = 450, minEnemies = 2 },
            { name = "mars_spear", kind = "stun_point", range = 850 },
            { name = "mars_gods_rebuke", kind = "aoe_point", range = 500 }
        }
    },
    npc_dota_hero_jakiro = {
        skills = { "jakiro_dual_breath", "jakiro_liquid_fire", "jakiro_ice_path", "jakiro_macropyre" },
        build = {
            "item_ward_observer", "item_ward_sentry", "item_smoke_of_deceit", "item_branches", "item_branches", "item_flask", "item_enchanted_mango",
            "item_magic_wand", "item_arcane_boots", "item_glimmer_cape", "item_force_staff",
            "item_aether_lens", "item_aghanims_shard", "item_cyclone", "item_octarine_core"
        },
        casts = {
            { name = "jakiro_macropyre", kind = "ult_point", range = 1000, minEnemies = 2 },
            { name = "jakiro_ice_path", kind = "stun_point", range = 1100 },
            { name = "jakiro_dual_breath", kind = "aoe_point", range = 750 },
            { name = "jakiro_liquid_fire", kind = "orb", range = 600 }
        }
    },
    npc_dota_hero_earthshaker = {
        skills = { "earthshaker_fissure", "earthshaker_aftershock", "earthshaker_enchant_totem", "earthshaker_echo_slam" },
        build = {
            "item_ward_observer", "item_ward_sentry", "item_smoke_of_deceit", "item_branches", "item_flask", "item_enchanted_mango", "item_clarity",
            "item_magic_wand", "item_arcane_boots", "item_blink", "item_aghanims_shard",
            "item_force_staff", "item_octarine_core", "item_shivas_guard"
        },
        casts = {
            { name = "earthshaker_echo_slam", kind = "ult_aoe", range = 550, minEnemies = 2 },
            { name = "earthshaker_fissure", kind = "stun_point", range = 1250 },
            { name = "earthshaker_enchant_totem", kind = "aoe_self", range = 300 }
        }
    },
    npc_dota_hero_lion = {
        skills = { "lion_impale", "lion_voodoo", "lion_mana_drain", "lion_finger_of_death" },
        build = {
            "item_ward_observer", "item_ward_sentry", "item_smoke_of_deceit", "item_branches", "item_flask", "item_enchanted_mango", "item_clarity",
            "item_magic_wand", "item_tranquil_boots", "item_blink", "item_aether_lens",
            "item_glimmer_cape", "item_force_staff", "item_aghanims_shard", "item_ultimate_scepter"
        },
        casts = {
            { name = "lion_finger_of_death", kind = "ult_single", range = 900, maxTargetHpPct = 0.72 },
            { name = "lion_voodoo", kind = "stun_target", range = 550 },
            { name = "lion_impale", kind = "stun_target", range = 575 },
            { name = "lion_mana_drain", kind = "mana_drain", range = 800 }
        }
    },
    npc_dota_hero_skywrath_mage = {
        skills = { "skywrath_mage_arcane_bolt", "skywrath_mage_concussive_shot", "skywrath_mage_ancient_seal", "skywrath_mage_mystic_flare" },
        build = {
            "item_ward_observer", "item_ward_sentry", "item_smoke_of_deceit", "item_branches", "item_flask", "item_enchanted_mango", "item_clarity",
            "item_null_talisman", "item_magic_wand", "item_arcane_boots", "item_rod_of_atos",
            "item_force_staff", "item_glimmer_cape", "item_aghanims_shard", "item_sheepstick"
        },
        casts = {
            { name = "skywrath_mage_ancient_seal", kind = "silence_target", range = 750 },
            { name = "skywrath_mage_mystic_flare", kind = "ult_point", range = 1100, minEnemies = 1 },
            { name = "skywrath_mage_concussive_shot", kind = "aoe_self", range = 1400 },
            { name = "skywrath_mage_arcane_bolt", kind = "nuke_target", range = 875 }
        }
    },
    npc_dota_hero_witch_doctor = {
        skills = { "witch_doctor_paralyzing_cask", "witch_doctor_maledict", "witch_doctor_voodoo_restoration", "witch_doctor_death_ward" },
        build = {
            "item_ward_observer", "item_ward_sentry", "item_branches", "item_branches", "item_flask", "item_enchanted_mango", "item_clarity",
            "item_magic_wand", "item_arcane_boots", "item_glimmer_cape", "item_aghanims_shard",
            "item_force_staff", "item_ultimate_scepter", "item_black_king_bar"
        },
        casts = {
            { name = "witch_doctor_maledict", kind = "aoe_point", range = 575 },
            { name = "witch_doctor_paralyzing_cask", kind = "stun_target", range = 700 },
            { name = "witch_doctor_death_ward", kind = "ult_point", range = 600, minEnemies = 1 }
        }
    },
    npc_dota_hero_crystal_maiden = {
        skills = { "crystal_maiden_crystal_nova", "crystal_maiden_frostbite", "crystal_maiden_brilliance_aura", "crystal_maiden_freezing_field" },
        build = {
            "item_ward_observer", "item_ward_sentry", "item_branches", "item_branches", "item_flask", "item_enchanted_mango", "item_clarity",
            "item_magic_wand", "item_tranquil_boots", "item_glimmer_cape", "item_force_staff",
            "item_aghanims_shard", "item_blink", "item_black_king_bar"
        },
        casts = {
            { name = "crystal_maiden_frostbite", kind = "stun_target", range = 600 },
            { name = "crystal_maiden_crystal_nova", kind = "aoe_point", range = 700 },
            { name = "crystal_maiden_freezing_field", kind = "ult_aoe", range = 650, minEnemies = 2 }
        }
    },
    npc_dota_hero_ogre_magi = {
        skills = { "ogre_magi_ignite", "ogre_magi_fireblast", "ogre_magi_bloodlust", "ogre_magi_multicast" },
        build = {
            "item_ward_observer", "item_ward_sentry", "item_branches", "item_branches", "item_flask", "item_enchanted_mango", "item_faerie_fire",
            "item_magic_wand", "item_arcane_boots", "item_glimmer_cape", "item_force_staff",
            "item_aether_lens", "item_aghanims_shard", "item_sheepstick"
        },
        casts = {
            { name = "ogre_magi_fireblast", kind = "stun_target", range = 525 },
            { name = "ogre_magi_ignite", kind = "nuke_target", range = 750 },
            { name = "ogre_magi_bloodlust", kind = "ally_buff", range = 600 }
        }
    },
    npc_dota_hero_lich = {
        skills = { "lich_frost_nova", "lich_frost_shield", "lich_sinister_gaze", "lich_chain_frost" },
        build = {
            "item_ward_observer", "item_ward_sentry", "item_branches", "item_branches", "item_flask", "item_enchanted_mango", "item_clarity",
            "item_magic_wand", "item_tranquil_boots", "item_glimmer_cape", "item_force_staff",
            "item_aghanims_shard", "item_aether_lens", "item_sheepstick"
        },
        casts = {
            { name = "lich_chain_frost", kind = "ult_single", range = 750 },
            { name = "lich_frost_shield", kind = "ally_shield", range = 1000 },
            { name = "lich_frost_nova", kind = "nuke_target", range = 600 },
            { name = "lich_sinister_gaze", kind = "stun_target", range = 550 }
        }
    }
}

Team.state = {
    lastTime = -9999,
    lastSwapAt = {},
    lastWardAt = {},
    lastDustAt = {},
    lastSmokeAt = -999,
    prevHp = {},
    retreating = {},
    focusTargetId = nil,
    focusSetAt = -999,
    enemyHasInvis = false,
    enemyHasEvasion = false,
    enemyHasHeal = false
}

Team.util = {}

function Team.util.dist2d(a, b)
    if not a or not b or not a.x or not b.x then return 99999 end
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

function Team.util.lerpPos(a, b, distFromA)
    if not a or not b then return a or b end
    local d = Team.util.dist2d(a, b)
    if d < 1 then return { x = a.x, y = a.y, z = a.z or 128 } end
    local t = distFromA / d
    return {
        x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t,
        z = a.z or 128
    }
end

function Team.util.stepAway(fromPos, threatPos, dist)
    if not fromPos or not threatPos then return fromPos end
    local d = Team.util.dist2d(fromPos, threatPos)
    if d < 1 then
        return { x = fromPos.x - dist, y = fromPos.y - dist, z = fromPos.z or 128 }
    end
    local dx = (fromPos.x - threatPos.x) / d
    local dy = (fromPos.y - threatPos.y) / d
    return {
        x = fromPos.x + dx * dist,
        y = fromPos.y + dy * dist,
        z = fromPos.z or 128
    }
end

function Team.util.hasItem(hero, itemName)
    if not hero or not hero.items then return nil end
    for slot, name in pairs(hero.items) do
        if name == itemName then
            return slot
        end
    end
    return nil
end

function Team.util.hasActiveItem(hero, itemName)
    if not hero or not hero.items then return nil end
    for slot = 0, 5 do
        if hero.items[slot] == itemName then
            return slot
        end
    end
    return nil
end

function Team.util.itemReady(hero, itemName)
    local slot = Team.util.hasActiveItem(hero, itemName)
    if not slot then return nil end
    local cd = hero.itemCooldown and hero.itemCooldown[slot] or 0
    if cd and cd > 0 then return nil end
    return slot
end

function Team.util.countUsedMainSlots(hero)
    local c = 0
    if not hero or not hero.items then return 0 end
    for s = 0, 5 do
        if hero.items[s] then c = c + 1 end
    end
    return c
end

function Team.util.countUsedAllSlots(hero)
    local c = 0
    if not hero or not hero.items then return 0 end
    for s = 0, 8 do
        if hero.items[s] then c = c + 1 end
    end
    return c
end

function Team.util.isDisabled(unit)
    if not unit then return false end
    return (unit.stunned == true) or (unit.hexed == true) or (unit.rooted == true)
end

function Team.util.isHardCC(unit)
    if not unit then return false end
    return (unit.stunned == true) or (unit.hexed == true)
end

function Team.util.findAbility(hero, abName)
    if not hero or not hero.abilities then return nil end
    for _, ab in pairs(hero.abilities) do
        if ab and ab.name == abName then
            return ab
        end
    end
    return nil
end

function Team.util.getSafeLane(teamId)
    return (teamId == 2) and "bot" or "top"
end

function Team.util.getOffLane(teamId)
    return (teamId == 2) and "top" or "bot"
end

function Team.util.getHeroLane(hero, teamId)
    if hero.lane == "top" or hero.lane == "mid" or hero.lane == "bot" then
        return hero.lane
    end
    if hero.position == 2 then return "mid" end
    if hero.position == 1 or hero.position == 5 then
        return Team.util.getSafeLane(teamId)
    end
    return Team.util.getOffLane(teamId)
end

function Team.util.getRoshanPos(snapshot)
    if snapshot.pins then
        for _, p in ipairs(snapshot.pins) do
            if p.kind == "roshan" and p.pos then
                if snapshot.isDay and p.pos.y < 0 then return p.pos end
                if (not snapshot.isDay) and p.pos.y > 0 then return p.pos end
            end
        end
        for _, p in ipairs(snapshot.pins) do
            if p.kind == "roshan" and p.pos then return p.pos end
        end
    end
    if snapshot.isDay then
        return { x = 2350, y = -1950, z = 128 }
    end
    return { x = -2350, y = 1950, z = 128 }
end

function Team.util.getTormentorPos(snapshot)
    if snapshot.pins then
        for _, p in ipairs(snapshot.pins) do
            if p.kind == "tormentor" and p.pos then
                if snapshot.isDay and p.pos.y > 0 then return p.pos end
                if (not snapshot.isDay) and p.pos.y < 0 then return p.pos end
            end
        end
        for _, p in ipairs(snapshot.pins) do
            if p.kind == "tormentor" and p.pos then return p.pos end
        end
    end
    if snapshot.isDay then
        return { x = -7200, y = 6600, z = 256 }
    end
    return { x = 7200, y = -6600, z = 256 }
end

function Team:PickHero(pos, role, available, allyPicks, enemyPicks)
    if not available then
        return self.draft[pos] and self.draft[pos][1] or "npc_dota_hero_juggernaut"
    end
    local enemyIllu, enemyTank, enemyMobile, enemyMagic = false, false, false, false
    if enemyPicks then
        for _, ename in pairs(enemyPicks) do
            if self.const.ILLUSION_HEROES[ename] then enemyIllu = true end
            if self.const.HEAL_HEROES[ename] or ename == "npc_dota_hero_tidehunter" or ename == "npc_dota_hero_centaur" then
                enemyTank = true
            end
            if ename == "npc_dota_hero_antimage" or ename == "npc_dota_hero_queenofpain" or ename == "npc_dota_hero_slark" then
                enemyMobile = true
            end
            if ename == "npc_dota_hero_zeus" or ename == "npc_dota_hero_lina" or ename == "npc_dota_hero_skywrath_mage" then
                enemyMagic = true
            end
        end
    end

    local preferred = nil
    if pos == 1 then
        if enemyIllu and available["npc_dota_hero_sven"] then preferred = "npc_dota_hero_sven"
        elseif enemyTank and available["npc_dota_hero_ursa"] then preferred = "npc_dota_hero_ursa"
        elseif enemyMagic and available["npc_dota_hero_juggernaut"] then preferred = "npc_dota_hero_juggernaut" end
    elseif pos == 2 then
        if enemyTank and available["npc_dota_hero_viper"] then preferred = "npc_dota_hero_viper"
        elseif enemyMobile and available["npc_dota_hero_lina"] then preferred = "npc_dota_hero_lina" end
    elseif pos == 3 then
        if enemyIllu and available["npc_dota_hero_axe"] then preferred = "npc_dota_hero_axe"
        elseif enemyMobile and available["npc_dota_hero_centaur"] then preferred = "npc_dota_hero_centaur" end
    elseif pos == 4 then
        if enemyIllu and available["npc_dota_hero_earthshaker"] then preferred = "npc_dota_hero_earthshaker"
        elseif enemyMobile and available["npc_dota_hero_lion"] then preferred = "npc_dota_hero_lion" end
    elseif pos == 5 then
        if enemyTank and available["npc_dota_hero_witch_doctor"] then preferred = "npc_dota_hero_witch_doctor" end
    end

    if preferred and available[preferred] then
        return preferred
    end
    local pool = self.draft[pos] or self.draft[1]
    for _, hname in ipairs(pool) do
        if available[hname] then
            return hname
        end
    end
    for hname, ok in pairs(available) do
        if ok then return hname end
    end
    return "npc_dota_hero_juggernaut"
end

Team.inv = {}

function Team.inv.scanThreats(snapshot)
    local st = Team.state
    local function inspect(name, items)
        if name and Team.const.INVIS_HEROES[name] then st.enemyHasInvis = true end
        if name and Team.const.EVASION_HEROES[name] then st.enemyHasEvasion = true end
        if name and Team.const.HEAL_HEROES[name] then st.enemyHasHeal = true end
        if items then
            for _, it in pairs(items) do
                if Team.const.INVIS_ITEMS[it] then st.enemyHasInvis = true end
                if Team.const.EVASION_ITEMS[it] then st.enemyHasEvasion = true end
                if Team.const.HEAL_HEROES[it] then st.enemyHasHeal = true end
            end
        end
    end
    if snapshot.enemies then
        for _, e in ipairs(snapshot.enemies) do
            if e.kind == "hero" then inspect(e.name, e.items) end
        end
    end
    if snapshot.enemyLastSeen then
        for _, info in pairs(snapshot.enemyLastSeen) do
            inspect(info.name, info.items)
        end
    end
end

function Team.inv.getAdaptiveBuild(hero)
    local cfg = Team.heroes[hero.name]
    local base = {}
    if cfg and cfg.build then
        for _, it in ipairs(cfg.build) do base[#base + 1] = it end
    else
        base = { "item_magic_wand", "item_boots", "item_glimmer_cape", "item_force_staff", "item_black_king_bar" }
    end
    local st = Team.state
    if hero.position == 1 or hero.position == 2 then
        if st.enemyHasEvasion then
            table.insert(base, math.min(#base + 1, 12), "item_monkey_king_bar")
        end
        if st.enemyHasHeal and hero.position == 1 then
            table.insert(base, math.min(#base + 1, 14), "item_skadi")
        end
    elseif hero.position == 3 then
        if st.enemyHasHeal then
            table.insert(base, math.min(#base + 1, 12), "item_shivas_guard")
        end
    elseif hero.position == 4 then
        if st.enemyHasHeal then
            table.insert(base, math.min(#base + 1, 10), "item_spirit_vessel")
        end
    end
    return base
end

function Team.inv.hasOrUpgraded(hero, itemName)
    if Team.util.hasItem(hero, itemName) then return true end
    local upgrades = {
        item_magic_stick = { "item_magic_wand" },
        item_gauntlets = { "item_bracer", "item_soul_ring" },
        item_slippers = { "item_wraith_band" },
        item_mantle = { "item_null_talisman" },
        item_circlet = { "item_bracer", "item_wraith_band", "item_null_talisman", "item_magic_wand" },
        item_branches = { "item_magic_wand" },
        item_ring_of_protection = { "item_vanguard", "item_crimson_guard", "item_pipe", "item_assault" },
        item_boots = { "item_phase_boots", "item_power_treads", "item_arcane_boots", "item_tranquil_boots" },
        item_vanguard = { "item_crimson_guard" },
        item_maelstrom = { "item_mjollnir" },
        item_echo_sabre = { "item_harpoon" },
        item_blink = { "item_overwhelming_blink", "item_swift_blink", "item_arcane_blink" },
        item_ward_observer = { "item_ward_dispenser" },
        item_ward_sentry = { "item_ward_dispenser" }
    }
    local list = upgrades[itemName]
    if list then
        for _, up in ipairs(list) do
            if Team.util.hasItem(hero, up) then return true end
        end
    end
    return false
end

function Team.inv.manageInventory(hero, snapshot, actions)
    local now = snapshot.time or 0
    local isSupport = (hero.position == 4 or hero.position == 5)
    local ftn = Team.const.FOUNTAIN[snapshot.team] or Team.const.FOUNTAIN[2]
    local nearBase = (not hero.alive) or (Team.util.dist2d(hero.pos, ftn) < 1100)

    -- 1. Backpack -> Main inventory auto-swap (respecting 6s CD)
    local lastSwap = Team.state.lastSwapAt[hero.id] or -999
    if now - lastSwap >= Team.const.SWAP_CD and hero.items then
        local bestBpSlot, bestBpVal = nil, -1
        for s = 6, 8 do
            local it = hero.items[s]
            if it then
                local v = Team.const.ITEM_VALUES[it] or 100
                if v > bestBpVal then
                    bestBpVal = v
                    bestBpSlot = s
                end
            end
        end
        if bestBpSlot then
            local emptyMain = nil
            local worstMainSlot, worstMainVal = nil, 999999
            for s = 0, 5 do
                local it = hero.items[s]
                if not it then
                    emptyMain = s
                    break
                else
                    local v = Team.const.ITEM_VALUES[it] or 100
                    if v < worstMainVal then
                        worstMainVal = v
                        worstMainSlot = s
                    end
                end
            end
            if emptyMain then
                actions[#actions + 1] = { kind = "swap", slot_a = bestBpSlot, slot_b = emptyMain, status = "Экипирую предмет" }
                Team.state.lastSwapAt[hero.id] = now
            elseif worstMainSlot and bestBpVal > worstMainVal + 40 then
                actions[#actions + 1] = { kind = "swap", slot_a = bestBpSlot, slot_b = worstMainSlot, status = "Меняю слот" }
                Team.state.lastSwapAt[hero.id] = now
            end
        end
    end

    -- 2. Auto-sell obsolete cheap items when dead or at fountain
    if nearBase and hero.items and Team.util.countUsedAllSlots(hero) >= 6 then
        local sellOrder = { "item_branches", "item_faerie_fire", "item_clarity", "item_enchanted_mango", "item_quelling_blade", "item_wraith_band", "item_bracer", "item_null_talisman" }
        for _, cand in ipairs(sellOrder) do
            if cand ~= "item_quelling_blade" or now > 900 then
                local s = Team.util.hasItem(hero, cand)
                if s and s <= 8 then
                    actions[#actions + 1] = { kind = "sell", slot = s, status = "Освобождаю слот" }
                    break
                end
            end
        end
    end

    -- 3. Auto-drop cheapest trash if all 9 slots full on map and valuable drop nearby
    if hero.alive and Team.util.countUsedAllSlots(hero) >= 9 and snapshot.drops then
        local needSpace = false
        for _, d in ipairs(snapshot.drops) do
            if Team.util.dist2d(hero.pos, d.pos) < 600 then
                needSpace = true
                break
            end
        end
        if needSpace then
            local cheapSlot, cheapVal = nil, 999999
            for s = 0, 8 do
                local it = hero.items[s]
                if it then
                    local v = Team.const.ITEM_VALUES[it] or 100
                    if v < cheapVal then
                        cheapVal = v
                        cheapSlot = s
                    end
                end
            end
            if cheapSlot and cheapVal <= 600 then
                actions[#actions + 1] = { kind = "drop", slot = cheapSlot, status = "Сброс под дроп" }
            end
        end
    end

    -- 4. Pre-death unreliable gold dump
    local hpPct = (hero.maxHp and hero.maxHp > 0) and (hero.hp / hero.maxHp) or 1
    local dangerEnemy = false
    if hero.alive and snapshot.enemies then
        for _, e in ipairs(snapshot.enemies) do
            if e.kind == "hero" and e.alive and Team.util.dist2d(hero.pos, e.pos) < 1100 then
                dangerEnemy = true
                break
            end
        end
    end
    if hero.alive and hpPct < 0.18 and dangerEnemy and (hero.gold or 0) >= 75 then
        if not Team.util.hasItem(hero, "item_tpscroll") and (hero.gold or 0) >= 100 then
            actions[#actions + 1] = { kind = "buy", item = "item_tpscroll", status = "Трачу золото перед смертью" }
        elseif (hero.gold or 0) >= 80 then
            actions[#actions + 1] = { kind = "buy", item = "item_dust", status = "Покупаю даст перед смертью" }
        end
        return
    end

    -- 5. Keep TP scroll stocked after 1:00
    if now > 60 and not Team.util.hasItem(hero, "item_tpscroll") and (hero.gold or 0) >= 100 then
        actions[#actions + 1] = { kind = "buy", item = "item_tpscroll", status = "Покупаю TP" }
        return
    end

    -- 6. Supports & Anti-invis consumables (wards, dust, smoke)
    if Team.util.countUsedAllSlots(hero) < 8 then
        if isSupport and now >= 0 then
            local hasObs = Team.util.hasItem(hero, "item_ward_observer") or Team.util.hasItem(hero, "item_ward_dispenser")
            if not hasObs and (hero.gold or 0) >= 50 then
                actions[#actions + 1] = { kind = "buy", item = "item_ward_observer", status = "Покупаю обсервер" }
            end
            local hasSen = Team.util.hasItem(hero, "item_ward_sentry") or Team.util.hasItem(hero, "item_ward_dispenser")
            if not hasSen and (Team.state.enemyHasInvis or now > 360) and (hero.gold or 0) >= 150 then
                actions[#actions + 1] = { kind = "buy", item = "item_ward_sentry", status = "Покупаю сентри" }
            end
            if hero.position == 4 and now > 240 and not Team.util.hasItem(hero, "item_smoke_of_deceit") and (hero.gold or 0) >= 200 then
                actions[#actions + 1] = { kind = "buy", item = "item_smoke_of_deceit", status = "Покупаю смок" }
            end
        end
        if Team.state.enemyHasInvis and (isSupport or hero.position == 3) and now > 120 then
            if not Team.util.hasItem(hero, "item_dust") and (hero.gold or 0) >= 160 then
                actions[#actions + 1] = { kind = "buy", item = "item_dust", status = "Покупаю даст против инвиза" }
            end
        end
    end

    -- 7. Main item build progression
    if Team.util.countUsedAllSlots(hero) < 8 then
        local build = Team.inv.getAdaptiveBuild(hero)
        for _, itemName in ipairs(build) do
            if now >= 0 and Team.const.CONSUMABLES[itemName] and itemName ~= "item_ward_observer" and itemName ~= "item_ward_sentry" then
                -- Skip pre-horn single consumables after horn
            elseif not Team.inv.hasOrUpgraded(hero, itemName) then
                local cost = Team.const.ITEM_VALUES[itemName] or 500
                local minStepGold = math.min(cost, 450)
                if now < 0 then minStepGold = cost end
                if (hero.gold or 0) >= minStepGold then
                    actions[#actions + 1] = { kind = "buy", item = itemName, status = "Покупаю " .. itemName:gsub("item_", "") }
                end
                break
            end
        end
    end
end

function Team.inv.learnAbilities(hero, actions)
    local talent = Talents.firstAvailable(hero.abilities)
    if talent then
        actions[#actions + 1] = { kind = "learn", ability = talent.name }
        return
    end
    if (hero.abilityPoints or 0) <= 0 or not hero.abilities then return end
    local cfg = Team.heroes[hero.name]
    if cfg and cfg.skills then
        -- Ultimate always first when available
        local ultName = cfg.skills[4]
        local ultAb = ultName and Team.util.findAbility(hero, ultName)
        if ultAb and ultAb.canUpgrade then
            actions[#actions + 1] = { kind = "learn", ability = ultName }
            return
        end
        -- First 3 levels: take one point in each basic skill
        if (hero.level or 1) <= 3 then
            for i = 1, 3 do
                local sname = cfg.skills[i]
                local ab = sname and Team.util.findAbility(hero, sname)
                if ab and ab.canUpgrade and (ab.level or 0) == 0 then
                    actions[#actions + 1] = { kind = "learn", ability = sname }
                    return
                end
            end
        end
        for _, sname in ipairs(cfg.skills) do
            local ab = Team.util.findAbility(hero, sname)
            if ab and ab.canUpgrade then
                actions[#actions + 1] = { kind = "learn", ability = sname }
                return
            end
        end
    end
    for _, ab in pairs(hero.abilities) do
        if ab and ab.canUpgrade and not ab.hidden then
            actions[#actions + 1] = { kind = "learn", ability = ab.name }
            return
        end
    end
end

Team.vision = {}

function Team.vision.findEnemyWard(hero, snapshot, maxRange)
    if not snapshot.enemies then return nil end
    local best, bestD = nil, maxRange or 900
    for _, e in ipairs(snapshot.enemies) do
        if (e.kind == "observer_ward" or e.kind == "sentry_ward") and e.alive then
            local d = Team.util.dist2d(hero.pos, e.pos)
            if d < bestD then
                bestD = d
                best = e
            end
        end
    end
    return best
end

function Team.vision.tryUseDust(hero, snapshot)
    local now = snapshot.time or 0
    if now - (Team.state.lastDustAt[hero.id] or -999) < Team.const.DUST_CD then return nil end
    if not Team.util.itemReady(hero, "item_dust") then return nil end

    -- 1. Visible enemy with invis capability not yet dusted
    if snapshot.enemies then
        for _, e in ipairs(snapshot.enemies) do
            if e.kind == "hero" and e.alive and not e.isIllusion and not e.dusted then
                local d = Team.util.dist2d(hero.pos, e.pos)
                if d <= 950 then
                    local hasInv = Team.const.INVIS_HEROES[e.name]
                    if not hasInv and e.items then
                        for _, it in pairs(e.items) do
                            if Team.const.INVIS_ITEMS[it] then hasInv = true break end
                        end
                    end
                    local eHpPct = (e.maxHp and e.maxHp > 0) and (e.hp / e.maxHp) or 1
                    if hasInv and (eHpPct < 0.72 or e.invisible) then
                        Team.state.lastDustAt[hero.id] = now
                        return { kind = "cast", item = "item_dust", status = "Даст по инвизеру!" }
                    end
                end
            end
        end
    end

    -- 2. Invis-capable enemy recently vanished into fog within 950 range
    if snapshot.enemyLastSeen then
        local visibleIds = {}
        if snapshot.enemies then
            for _, e in ipairs(snapshot.enemies) do
                if e.kind == "hero" and e.alive then visibleIds[e.id] = true end
            end
        end
        for eid, info in pairs(snapshot.enemyLastSeen) do
            if not visibleIds[eid] and info.at and (now - info.at) <= 2.5 and info.pos then
                if Team.util.dist2d(hero.pos, info.pos) <= 950 then
                    local hasInv = info.name and Team.const.INVIS_HEROES[info.name]
                    if not hasInv and info.items then
                        for _, it in pairs(info.items) do
                            if Team.const.INVIS_ITEMS[it] then hasInv = true break end
                        end
                    end
                    if hasInv then
                        Team.state.lastDustAt[hero.id] = now
                        return { kind = "cast", item = "item_dust", status = "Даст по ушедшему в инвиз!" }
                    end
                end
            end
        end
    end
    return nil
end

function Team.vision.tryPlaceWards(hero, snapshot)
    local now = snapshot.time or 0
    if now - (Team.state.lastWardAt[hero.id] or -999) < Team.const.WARD_CD then return nil end

    local hasObs = Team.util.itemReady(hero, "item_ward_observer") or Team.util.itemReady(hero, "item_ward_dispenser")
    local hasSen = Team.util.itemReady(hero, "item_ward_sentry")
    if not hasSen and Team.util.itemReady(hero, "item_ward_dispenser") then
        local dSlot = Team.util.hasActiveItem(hero, "item_ward_dispenser")
        local sec = dSlot and hero.itemSecondaryCharges and hero.itemSecondaryCharges[dSlot] or 0
        if sec and sec > 0 then hasSen = true end
    end

    if not hasObs and not hasSen then return nil end
    if not snapshot.pins then return nil end

    -- Place Observer Ward on uncovered ward_spot
    if hasObs then
        for _, p in ipairs(snapshot.pins) do
            if p.kind == "ward_spot" and p.pos then
                local d = Team.util.dist2d(hero.pos, p.pos)
                if d <= 520 then
                    local alreadyCovered = false
                    if snapshot.allies then
                        for _, a in ipairs(snapshot.allies) do
                            if a.kind == "observer_ward" and a.alive and Team.util.dist2d(a.pos, p.pos) < 1450 then
                                alreadyCovered = true
                                break
                            end
                        end
                    end
                    if not alreadyCovered then
                        Team.state.lastWardAt[hero.id] = now
                        return { kind = "cast", item = "item_ward_observer", position = p.pos, status = "Ставлю обсервер" }
                    end
                end
            end
        end
    end

    -- Place Sentry Ward near ward_spot or in fight/roshan against invis
    if hasSen then
        local nearRoshan = Team.util.dist2d(hero.pos, Team.util.getRoshanPos(snapshot)) < 900
        if nearRoshan or Team.state.enemyHasInvis then
            for _, p in ipairs(snapshot.pins) do
                if p.kind == "ward_spot" and p.pos and Team.util.dist2d(hero.pos, p.pos) <= 520 then
                    local alreadySen = false
                    if snapshot.allies then
                        for _, a in ipairs(snapshot.allies) do
                            if a.kind == "sentry_ward" and a.alive and Team.util.dist2d(a.pos, p.pos) < 1000 then
                                alreadySen = true
                                break
                            end
                        end
                    end
                    if not alreadySen then
                        Team.state.lastWardAt[hero.id] = now
                        return { kind = "cast", item = "item_ward_sentry", position = p.pos, status = "Ставлю сентри" }
                    end
                end
            end
        end
    end
    return nil
end

Team.combat = {}

function Team.combat.selectTeamFocus(snapshot)
    local bestId, bestScore = nil, -99999
    if not snapshot.enemies then return nil end
    for _, e in ipairs(snapshot.enemies) do
        if e.kind == "hero" and e.alive and not e.isIllusion and not e.invulnerable and not e.attackImmune then
            local alliesNear = 0
            if snapshot.heroes then
                for _, h in ipairs(snapshot.heroes) do
                    if h.alive and Team.util.dist2d(h.pos, e.pos) < 1400 then
                        alliesNear = alliesNear + 1
                    end
                end
            end
            if alliesNear > 0 then
                local hpPct = (e.maxHp and e.maxHp > 0) and (e.hp / e.maxHp) or 1
                local score = alliesNear * 450 + (1 - hpPct) * 600
                if e.channeling then score = score + 700 end
                if Team.util.isDisabled(e) then score = score + 250 end
                if e.magicImmune then score = score - 200 end
                if score > bestScore then
                    bestScore = score
                    bestId = e.id
                end
            end
        end
    end
    return bestId
end

function Team.combat.useActiveItems(hero, snapshot, target, nearbyEnemies)
    local hpPct = (hero.maxHp and hero.maxHp > 0) and (hero.hp / hero.maxHp) or 1
    local manaPct = (hero.maxMana and hero.maxMana > 0) and (hero.mana / hero.maxMana) or 1
    local inCombat = (#nearbyEnemies > 0)

    -- 1. Emergency heal/mana consumables
    if hpPct < 0.24 and inCombat and Team.util.itemReady(hero, "item_faerie_fire") then
        return { kind = "cast", item = "item_faerie_fire", status = "Faerie Fire!" }
    end
    if (hpPct < 0.52 or (manaPct < 0.25 and inCombat)) then
        local wandSlot = Team.util.itemReady(hero, "item_magic_wand") or Team.util.itemReady(hero, "item_magic_stick")
        if wandSlot then
            local charges = hero.itemCharges and hero.itemCharges[wandSlot] or 0
            if charges >= 5 then
                local wName = hero.items[wandSlot]
                return { kind = "cast", item = wName, status = "Прожимаю стики" }
            end
        end
    end
    for _, fam in ipairs({ "item_greater_famango", "item_great_famango", "item_famango" }) do
        if (hpPct < 0.55 or manaPct < 0.25) and Team.util.itemReady(hero, fam) then
            return { kind = "cast", item = fam, status = "Ем лотос" }
        end
    end
    if not inCombat and hpPct < 0.65 and Team.util.itemReady(hero, "item_flask") then
        return { kind = "cast", item = "item_flask", target_id = hero.id, status = "Хилюсь флаской" }
    end
    if not inCombat and manaPct < 0.45 and Team.util.itemReady(hero, "item_clarity") then
        return { kind = "cast", item = "item_clarity", target_id = hero.id, status = "Пью кларити" }
    end
    if (hero.mana or 0) < 110 and inCombat and Team.util.itemReady(hero, "item_enchanted_mango") then
        return { kind = "cast", item = "item_enchanted_mango", status = "Ем манго" }
    end
    if manaPct < 0.65 and Team.util.itemReady(hero, "item_arcane_boots") then
        return { kind = "cast", item = "item_arcane_boots", status = "Арканы" }
    end
    if hpPct > 0.45 and (hero.mana or 0) < 150 and inCombat and Team.util.itemReady(hero, "item_soul_ring") then
        return { kind = "cast", item = "item_soul_ring", status = "Soul Ring" }
    end

    -- 2. Defensive & Teamfight items
    if inCombat and (#nearbyEnemies >= 2 or hpPct < 0.65) and Team.util.itemReady(hero, "item_black_king_bar") then
        return { kind = "cast", item = "item_black_king_bar", status = "Жму BKB!" }
    end
    if inCombat and hpPct < 0.42 and target and Team.util.dist2d(hero.pos, target.pos) <= 350 and Team.util.itemReady(hero, "item_satanic") then
        return { kind = "cast", item = "item_satanic", status = "Жму Satanic!" }
    end
    if inCombat and hpPct < 0.75 and Team.util.itemReady(hero, "item_blade_mail") then
        return { kind = "cast", item = "item_blade_mail", status = "Обратка!" }
    end
    if inCombat and #nearbyEnemies >= 2 and Team.util.itemReady(hero, "item_pipe") then
        return { kind = "cast", item = "item_pipe", status = "Пайп на команду" }
    end
    if inCombat and #nearbyEnemies >= 2 and Team.util.itemReady(hero, "item_crimson_guard") then
        return { kind = "cast", item = "item_crimson_guard", status = "Кримсон на команду" }
    end
    if inCombat and (hero.silenced or hero.rooted or #nearbyEnemies >= 1) and Team.util.itemReady(hero, "item_manta") then
        return { kind = "cast", item = "item_manta", status = "Манта!" }
    end
    if inCombat and Team.util.itemReady(hero, "item_shivas_guard") then
        return { kind = "cast", item = "item_shivas_guard", status = "Шива!" }
    end
    if inCombat and hpPct < 0.80 and Team.util.itemReady(hero, "item_mask_of_madness") then
        return { kind = "cast", item = "item_mask_of_madness", status = "МоМ" }
    end

    -- 3. Ally save items (Glimmer / Force Staff / Lotus Orb)
    if snapshot.heroes then
        for _, ally in ipairs(snapshot.heroes) do
            if ally.alive and Team.util.dist2d(hero.pos, ally.pos) <= 650 then
                local aHp = (ally.maxHp and ally.maxHp > 0) and (ally.hp / ally.maxHp) or 1
                if aHp < 0.42 and Team.util.itemReady(hero, "item_glimmer_cape") then
                    return { kind = "cast", item = "item_glimmer_cape", target_id = ally.id, status = "Сейв Глиммером" }
                end
                if aHp < 0.35 and Team.util.itemReady(hero, "item_force_staff") then
                    return { kind = "cast", item = "item_force_staff", target_id = ally.id, status = "Форс Стафф сейв" }
                end
                if (aHp < 0.55 or Team.util.isDisabled(ally)) and Team.util.itemReady(hero, "item_lotus_orb") then
                    return { kind = "cast", item = "item_lotus_orb", target_id = ally.id, status = "Лотус Орб" }
                end
            end
        end
    end

    -- 4. Offensive target items (Blink, Hex, Abyssal, Bloodthorn, Vessel)
    if target and target.alive and not target.isIllusion then
        local d = Team.util.dist2d(hero.pos, target.pos)
        if not target.magicImmune then
            if d <= 800 and not Team.util.isHardCC(target) and Team.util.itemReady(hero, "item_sheepstick") then
                return { kind = "cast", item = "item_sheepstick", target_id = target.id, status = "Хекс в цель!" }
            end
            if d <= 900 and not target.silenced and Team.util.itemReady(hero, "item_bloodthorn") then
                return { kind = "cast", item = "item_bloodthorn", target_id = target.id, status = "Бладторн!" }
            end
            if d <= 950 and Team.util.itemReady(hero, "item_spirit_vessel") then
                return { kind = "cast", item = "item_spirit_vessel", target_id = target.id, status = "Вессел!" }
            end
        end
        if d <= 250 and not Team.util.isHardCC(target) and Team.util.itemReady(hero, "item_abyssal_blade") then
            return { kind = "cast", item = "item_abyssal_blade", target_id = target.id, status = "Абиссал!" }
        end
        if d > 420 and d <= 1150 and hpPct > 0.65 and Team.util.itemReady(hero, "item_blink") then
            return { kind = "cast", item = "item_blink", position = target.pos, status = "Блинк инициация!" }
        end
    end

    if target and Team.util.itemReady(hero, "item_phase_boots") then
        return { kind = "cast", item = "item_phase_boots", status = "Фейзы" }
    end

    return nil
end

function Team.combat.castHeroSpells(hero, snapshot, target, nearbyEnemies, actions)
    if hero.silenced or not target or not target.alive then return nil end
    local cfg = Team.heroes[hero.name]
    if not cfg or not cfg.casts then return nil end

    local d = Team.util.dist2d(hero.pos, target.pos)
    local tHpPct = (target.maxHp and target.maxHp > 0) and (target.hp / target.maxHp) or 1

    for _, spec in ipairs(cfg.casts) do
        local ab = Team.util.findAbility(hero, spec.name)
        if ab and ab.fullyCastable and (ab.level or 0) > 0 then
            local range = spec.range or ab.castRange or 600
            if spec.kind == "orb" then
                if ab.autoCast == false then
                    actions[#actions + 1] = { kind = "autocast", ability = spec.name }
                end
            elseif spec.kind == "stun_target" then
                if d <= range and not target.magicImmune and not Team.util.isHardCC(target) then
                    return { kind = "cast", ability = spec.name, target_id = target.id, status = "Стан в цель!" }
                end
            elseif spec.kind == "stun_point" then
                if d <= range and not target.magicImmune and not Team.util.isHardCC(target) then
                    return { kind = "cast", ability = spec.name, position = target.pos, status = "Контроль по области!" }
                end
            elseif spec.kind == "stun_self" then
                if d <= range and not target.magicImmune and not Team.util.isHardCC(target) then
                    return { kind = "cast", ability = spec.name, status = "Массовый стан!" }
                end
            elseif spec.kind == "silence_target" then
                if d <= range and not target.magicImmune and not target.silenced then
                    return { kind = "cast", ability = spec.name, target_id = target.id, status = "Сайленс!" }
                end
            elseif spec.kind == "nuke_target" then
                if d <= range and not target.magicImmune then
                    return { kind = "cast", ability = spec.name, target_id = target.id, status = "Каст " .. spec.name }
                end
            elseif spec.kind == "aoe_point" then
                if d <= range and not target.magicImmune then
                    return { kind = "cast", ability = spec.name, position = target.pos, status = "АоЕ нюк!" }
                end
            elseif spec.kind == "aoe_self" then
                if d <= range and not target.magicImmune then
                    return { kind = "cast", ability = spec.name, status = "АоЕ вокруг!" }
                end
            elseif spec.kind == "execute" then
                if d <= range and (target.hp or 9999) <= (spec.thresh or 300) then
                    return { kind = "cast", ability = spec.name, target_id = target.id, status = "Казнь ультой!" }
                end
            elseif spec.kind == "ult_single" then
                local maxP = spec.maxTargetHpPct or 0.95
                if d <= range and not target.isIllusion and tHpPct <= maxP then
                    return { kind = "cast", ability = spec.name, target_id = target.id, status = "Ультимейт!" }
                end
            elseif spec.kind == "ult_aoe" then
                local minE = spec.minEnemies or 2
                local countIn = 0
                for _, e in ipairs(nearbyEnemies) do
                    if not e.isIllusion and Team.util.dist2d(hero.pos, e.pos) <= range then
                        countIn = countIn + 1
                    end
                end
                if countIn >= minE or (countIn >= 1 and tHpPct < 0.45) then
                    return { kind = "cast", ability = spec.name, status = "Массовый ульт!" }
                end
            elseif spec.kind == "ult_point" then
                local minE = spec.minEnemies or 2
                local countIn = 0
                for _, e in ipairs(nearbyEnemies) do
                    if not e.isIllusion and Team.util.dist2d(target.pos, e.pos) <= 450 then
                        countIn = countIn + 1
                    end
                end
                if d <= range and (countIn >= minE or (countIn >= 1 and (Team.util.isDisabled(target) or tHpPct < 0.55))) then
                    return { kind = "cast", ability = spec.name, position = target.pos, status = "Ульт в файт!" }
                end
            elseif spec.kind == "self_buff" or spec.kind == "team_buff" then
                if d <= range then
                    return { kind = "cast", ability = spec.name, status = "Бафф в бой!" }
                end
            elseif spec.kind == "def_buff" then
                local hpPct = (hero.maxHp and hero.maxHp > 0) and (hero.hp / hero.maxHp) or 1
                if d <= range and hpPct < 0.55 then
                    return { kind = "cast", ability = spec.name, status = "Защитный ульт!" }
                end
            elseif spec.kind == "heal_ward" then
                local hpPct = (hero.maxHp and hero.maxHp > 0) and (hero.hp / hero.maxHp) or 1
                if hpPct < 0.72 then
                    return { kind = "cast", ability = spec.name, position = hero.pos, status = "Хил-вард!" }
                end
            elseif spec.kind == "ally_buff" or spec.kind == "ally_shield" then
                if snapshot.heroes then
                    for _, ally in ipairs(snapshot.heroes) do
                        if ally.alive and (ally.position == 1 or ally.position == 2) and Team.util.dist2d(hero.pos, ally.pos) <= range then
                            return { kind = "cast", ability = spec.name, target_id = ally.id, status = "Бафф на кора!" }
                        end
                    end
                end
            elseif spec.kind == "mobility" then
                local hpPct = (hero.maxHp and hero.maxHp > 0) and (hero.hp / hero.maxHp) or 1
                if d > 450 and d <= range and hpPct > 0.65 and tHpPct < 0.55 then
                    return { kind = "cast", ability = spec.name, position = target.pos, status = "Блинк за фрагом!" }
                end
            end
        end
    end
    return nil
end

Team.macro = {}

function Team.macro.checkTowerSafety(hero, snapshot, desiredMovePos)
    if not snapshot.enemies then return nil end
    local nearestTower, towerDist = nil, 99999
    for _, e in ipairs(snapshot.enemies) do
        if e.kind == "tower" and e.alive then
            local d = Team.util.dist2d(hero.pos, e.pos)
            if d < towerDist then
                towerDist = d
                nearestTower = e
            end
        end
    end
    if not nearestTower then return nil end

    -- Count healthy allied creeps inside tower attack radius (700)
    local tankingCreeps = 0
    local bestAllyCreep = nil
    if snapshot.allies then
        for _, a in ipairs(snapshot.allies) do
            if (a.kind == "lane_creep" or a.kind == "siege_creep") and a.alive then
                local cd = Team.util.dist2d(a.pos, nearestTower.pos)
                if cd < Team.const.TOWER_RANGE then
                    if not bestAllyCreep then bestAllyCreep = a end
                    if (a.hp or 0) >= Team.const.CREEP_TANK_MIN_HP then
                        tankingCreeps = tankingCreeps + 1
                    end
                end
            end
        end
    end

    -- Detect tower aggro on hero (took damage within 780 of enemy tower)
    local prevHp = Team.state.prevHp[hero.id]
    local tookDamage = prevHp and (hero.hp < prevHp - 15)
    if towerDist <= Team.const.TOWER_AGGRO_RANGE and tookDamage then
        if bestAllyCreep and tankingCreeps > 0 then
            return { kind = "deaggro", target_id = bestAllyCreep.id, status = "Сбрасываю агр башни!" }
        else
            local safePos = Team.util.stepAway(hero.pos, nearestTower.pos, Team.const.TOWER_BUFFER - towerDist + 140)
            return { kind = "move", position = safePos, status = "Отхожу из-под башни!" }
        end
    end

    -- Never dive under tower without healthy tanking creeps (unless guaranteed kill)
    if towerDist <= Team.const.TOWER_BUFFER and tankingCreeps == 0 then
        local canFinish = false
        if (nearestTower.hp or 9999) < 150 and not nearestTower.invulnerable and (hero.hp / math.max(1, hero.maxHp)) > 0.55 then
            canFinish = true
        end
        if not canFinish then
            local safePos = Team.util.stepAway(hero.pos, nearestTower.pos, Team.const.TOWER_BUFFER - towerDist + 120)
            return { kind = "move", position = safePos, status = "Жду пачку крипов у башни" }
        end
    end

    -- Prevent walking into tower buffer if destination is inside tower range without creeps
    if desiredMovePos and tankingCreeps == 0 then
        local destTowerDist = Team.util.dist2d(desiredMovePos, nearestTower.pos)
        if destTowerDist < Team.const.TOWER_BUFFER then
            local safePos = Team.util.stepAway(nearestTower.pos, nearestTower.pos, 0)
            safePos = Team.util.lerpPos(nearestTower.pos, hero.pos, Team.const.TOWER_BUFFER + 60)
            return { kind = "move", position = safePos, status = "Держу дистанцию от башни" }
        end
    end
    return nil
end

function Team.macro.findObjective(hero, snapshot)
    local now = snapshot.time or 0
    local sched = snapshot.schedule or {}

    -- 1. High-value drops (Aegis, Cheese, Refresher Shard, Tormentor Horn, Banner)
    if snapshot.drops then
        for _, dr in ipairs(snapshot.drops) do
            local d = Team.util.dist2d(hero.pos, dr.pos)
            if d < 1200 and Team.util.countUsedAllSlots(hero) < 9 then
                if dr.name ~= "item_aegis" or hero.position == 1 or hero.position == 2 or hero.position == 3 then
                    return { kind = "pickup", target_id = dr.id, status = "Подбираю " .. dr.name }
                end
            end
        end
    end

    -- 2. Visible Runes
    if snapshot.runes then
        for _, r in ipairs(snapshot.runes) do
            local d = Team.util.dist2d(hero.pos, r.pos)
            if d < 1300 then
                return { kind = "rune", target_id = r.id, status = "Беру руну!" }
            end
        end
    end

    -- 3. Pre-0:00 Bounty Rune Rally
    if now < 0 and snapshot.pins then
        local targetSide = (hero.position == 1 or hero.position == 5) and Team.util.getSafeLane(snapshot.team) or Team.util.getOffLane(snapshot.team)
        if hero.position == 2 then targetSide = Team.util.getSafeLane(snapshot.team) end
        local bestBounty, bestD = nil, 99999
        for _, p in ipairs(snapshot.pins) do
            if p.kind == "bounty" and p.pos then
                if p.side == targetSide or not bestBounty then
                    local d = Team.util.dist2d(hero.pos, p.pos)
                    if d < bestD then
                        bestD = d
                        bestBounty = p
                    end
                end
            end
        end
        if bestBounty then
            -- Check if outnumbered near rune
            local enemiesNear, alliesNear = 0, 1
            if snapshot.enemies then
                for _, e in ipairs(snapshot.enemies) do
                    if e.kind == "hero" and e.alive and Team.util.dist2d(e.pos, bestBounty.pos) < 1300 then
                        enemiesNear = enemiesNear + 1
                    end
                end
            end
            if snapshot.heroes then
                for _, h in ipairs(snapshot.heroes) do
                    if h.id ~= hero.id and h.alive and Team.util.dist2d(h.pos, bestBounty.pos) < 1400 then
                        alliesNear = alliesNear + 1
                    end
                end
            end
            if enemiesNear > alliesNear then
                local ftn = Team.const.FOUNTAIN[snapshot.team] or Team.const.FOUNTAIN[2]
                local safe = Team.util.lerpPos(bestBounty.pos, ftn, 1400)
                return { kind = "move", position = safe, status = "Не фижу на руне, отступаю" }
            end
            return { kind = "move", position = bestBounty.pos, status = "Выход на баунти-руну" }
        end
    end

    -- 4. Mid Water / Power Runes (Midlaner or Pos 4)
    if (hero.position == 2 or hero.position == 4) and now >= 110 and snapshot.pins then
        local nextRune = (now < 350 and sched.water and sched.water.nextAt) or (sched.power and sched.power.nextAt)
        if nextRune and (nextRune - now) <= 8 and (nextRune - now) >= -12 then
            local bestPin, bestD = nil, 99999
            for _, p in ipairs(snapshot.pins) do
                if (p.kind == "power" or p.kind == "water") and p.pos then
                    local d = Team.util.dist2d(hero.pos, p.pos)
                    if d < 2600 and d < bestD then
                        bestD = d
                        bestPin = p
                    end
                end
            end
            if bestPin then
                return { kind = "move", position = bestPin.pos, status = "Контролю руну на реке" }
            end
        end
    end

    -- 5. Lotus Pool (Side laners / supports)
    if hero.position ~= 2 and now >= 175 and snapshot.pins then
        local nextLotus = sched.lotus and sched.lotus.nextAt
        for _, p in ipairs(snapshot.pins) do
            if p.kind == "lotus" and p.pos then
                local d = Team.util.dist2d(hero.pos, p.pos)
                if d < 1600 and (p.active or (p.charges and p.charges > 0) or (nextLotus and nextLotus - now <= 6)) then
                    return { kind = "lotus", position = p.pos, status = "Собираю лотос" }
                end
            end
        end
    end

    -- 6. Wisdom Shrine (Supports around 7:00, 14:00, 21:00...)
    if (hero.position == 4 or hero.position == 5) and now >= 400 and snapshot.pins then
        local nextWis = sched.wisdom and sched.wisdom.nextAt
        if nextWis and (nextWis - now) <= 16 and (nextWis - now) >= -20 then
            for _, p in ipairs(snapshot.pins) do
                if p.kind == "wisdom" and p.pos and (p.mapTeam == snapshot.team or p.active) then
                    local d = Team.util.dist2d(hero.pos, p.pos)
                    if d < 3500 then
                        return { kind = "shrine", position = p.pos, status = "Забираю святилище мудрости" }
                    end
                end
            end
        end
    end

    return nil
end

function Team.macro.findLaneAnchor(hero, snapshot)
    local lane = Team.util.getHeroLane(hero, snapshot.team)
    local myAncient = Team.const.ANCIENT[snapshot.team] or Team.const.ANCIENT[2]
    local enemyAncient = Team.const.ANCIENT[snapshot.enemyTeam] or Team.const.ANCIENT[3]

    -- Find furthest allied creep wave on this lane
    local bestCreep, bestProg = nil, -1
    if snapshot.allies then
        for _, a in ipairs(snapshot.allies) do
            if (a.kind == "lane_creep" or a.kind == "siege_creep") and a.alive and a.lane == lane then
                local prog = Team.util.dist2d(a.pos, myAncient)
                if prog > bestProg then
                    bestProg = prog
                    bestCreep = a
                end
            end
        end
    end
    if bestCreep then
        return Team.util.lerpPos(bestCreep.pos, myAncient, hero.ranged and 320 or 160)
    end

    -- Fallback to lane pin or frontmost allied tower on lane
    local bestTower, bestTProg = nil, -1
    if snapshot.allies then
        for _, a in ipairs(snapshot.allies) do
            if a.kind == "tower" and a.alive and a.lane == lane then
                local prog = Team.util.dist2d(a.pos, myAncient)
                if prog > bestTProg then
                    bestTProg = prog
                    bestTower = a
                end
            end
        end
    end
    if bestTower then
        return Team.util.lerpPos(bestTower.pos, enemyAncient, 350)
    end

    if snapshot.pins then
        for _, p in ipairs(snapshot.pins) do
            if p.kind == "lane" and p.lane == lane and p.pos then
                return p.pos
            end
        end
    end
    return Team.util.lerpPos(myAncient, enemyAncient, 4500)
end

function Team.macro.laningAndPush(hero, snapshot)
    local isSupport = (hero.position == 4 or hero.position == 5)
    local dmg = hero.attackDamage or 55
    local range = hero.attackRange or 150
    local lhThreshold = dmg * 0.92 + (hero.ranged and 28 or 12)

    -- 1. Lasthit enemy creeps (Cores first; supports only if no allied core within 800)
    local coreNearby = false
    if isSupport and snapshot.heroes then
        for _, ally in ipairs(snapshot.heroes) do
            if ally.alive and ally.id ~= hero.id and ally.position <= 3 and Team.util.dist2d(hero.pos, ally.pos) < 850 then
                coreNearby = true
                break
            end
        end
    end

    if snapshot.enemies and (not isSupport or not coreNearby) then
        local bestCreep, bestScore = nil, -999
        for _, e in ipairs(snapshot.enemies) do
            if (e.kind == "lane_creep" or e.kind == "siege_creep") and e.alive and not e.invulnerable then
                local d = Team.util.dist2d(hero.pos, e.pos)
                if d <= range + 380 and (e.hp or 9999) <= lhThreshold then
                    local score = 100 - (e.hp or 0)
                    if e.kind == "siege_creep" then score = score + 80 end
                    if score > bestScore then
                        bestScore = score
                        bestCreep = e
                    end
                end
            end
        end
        if bestCreep then
            return { kind = "attack", target_id = bestCreep.id, status = "Добиваю крипа" }
        end
    end

    -- 2. Deny allied creeps
    if snapshot.allies then
        for _, a in ipairs(snapshot.allies) do
            if (a.kind == "lane_creep" or a.kind == "siege_creep") and a.alive and a.deniable then
                local d = Team.util.dist2d(hero.pos, a.pos)
                if d <= range + 320 and (a.hp or 9999) <= lhThreshold then
                    return { kind = "deny", target_id = a.id, status = "Денаю крипа" }
                end
            end
        end
    end

    -- 3. Attack valid enemy buildings (only when creeps are tanking & not invulnerable / backdoored)
    if snapshot.enemies then
        for _, e in ipairs(snapshot.enemies) do
            if (e.kind == "tower" or e.kind == "barracks" or e.kind == "ancient") and e.alive and not e.invulnerable and not e.attackImmune then
                local d = Team.util.dist2d(hero.pos, e.pos)
                if d <= range + 450 then
                    local alliesNearBuilding = 0
                    if snapshot.allies then
                        for _, a in ipairs(snapshot.allies) do
                            if (a.kind == "lane_creep" or a.kind == "siege_creep") and a.alive and Team.util.dist2d(a.pos, e.pos) < 750 then
                                alliesNearBuilding = alliesNearBuilding + 1
                            end
                        end
                    end
                    if alliesNearBuilding > 0 or (e.hp or 9999) < 160 then
                        return { kind = "attack", target_id = e.id, status = "Пушу постройку!" }
                    end
                end
            end
        end
    end

    -- 4. Push wave / attack enemy lane creeps (avoid early creep aggro for supports)
    if snapshot.enemies and (not isSupport or (snapshot.time or 0) > 420) then
        local bestWaveCreep, bestD = nil, range + 450
        for _, e in ipairs(snapshot.enemies) do
            if (e.kind == "lane_creep" or e.kind == "siege_creep") and e.alive and not e.invulnerable then
                local d = Team.util.dist2d(hero.pos, e.pos)
                if d < bestD then
                    bestD = d
                    bestWaveCreep = e
                end
            end
        end
        if bestWaveCreep then
            if isSupport or (snapshot.time or 0) > 360 then
                return { kind = "attack", target_id = bestWaveCreep.id, status = "Толкаю линию" }
            end
        end
    end

    return nil
end

function Team.macro.findMacroTarget(hero, snapshot)
    local now = snapshot.time or 0
    local enemyAncient = Team.const.ANCIENT[snapshot.enemyTeam] or Team.const.ANCIENT[3]
    local myAncient = Team.const.ANCIENT[snapshot.team] or Team.const.ANCIENT[2]

    -- Count dead enemies and alive allies
    local deadEnemies = 0
    if snapshot.enemies then
        for _, e in ipairs(snapshot.enemies) do
            if e.kind == "hero" and not e.alive and not e.isIllusion then
                deadEnemies = deadEnemies + 1
            end
        end
    end
    local aliveAllies = 0
    if snapshot.heroes then
        for _, h in ipairs(snapshot.heroes) do
            if h.alive then aliveAllies = aliveAllies + 1 end
        end
    end

    -- 1. Base Defense: if allied T3/Barracks/Ancient is underAttack
    if snapshot.allies then
        for _, a in ipairs(snapshot.allies) do
            if a.alive and a.underAttack and (a.kind == "ancient" or a.kind == "barracks" or (a.kind == "tower" and (a.tier or 1) >= 2)) then
                return a.pos, "Защита базы!"
            end
        end
    end

    -- 2. Roshan call after winning fight (2+ dead enemies) past 16 min
    if now > 960 and deadEnemies >= 2 and aliveAllies >= 3 then
        local roshPos = Team.util.getRoshanPos(snapshot)
        if Team.util.dist2d(hero.pos, roshPos) < 4200 then
            return roshPos, "Идём на Рошана!"
        end
    end

    -- 3. Tormentor call past 15 min when active and 3+ healthy allies nearby
    if now > 900 and snapshot.schedule and snapshot.schedule.tormentor and snapshot.schedule.tormentor.active and aliveAllies >= 3 then
        local tormPos = Team.util.getTormentorPos(snapshot)
        if Team.util.dist2d(hero.pos, tormPos) < 2800 then
            return tormPos, "Забираем Терзателя!"
        end
    end

    -- 4. Mid/Late Game Team Grouping & Highground Siege
    if now > 780 then
        -- Find strongest alive core (Pos 1 or Pos 2) to group around
        local anchorHero = nil
        if snapshot.heroes then
            for _, h in ipairs(snapshot.heroes) do
                if h.alive and (h.position == 1 or h.position == 2) then
                    anchorHero = h
                    break
                end
            end
        end
        if anchorHero and anchorHero.id ~= hero.id and (hero.position >= 3 or deadEnemies >= 1) then
            local d = Team.util.dist2d(hero.pos, anchorHero.pos)
            if d > 950 then
                return anchorHero.pos, "Стяжка к команде"
            end
        end
        -- Push nearest exposed enemy building on mid or winning lane
        if snapshot.enemies then
            local bestBldg, bestBD = nil, 99999
            for _, e in ipairs(snapshot.enemies) do
                if (e.kind == "tower" or e.kind == "barracks" or e.kind == "ancient") and e.alive and not e.invulnerable then
                    local d = Team.util.dist2d(hero.pos, e.pos)
                    if d < bestBD then
                        bestBD = d
                        bestBldg = e
                    end
                end
            end
            if bestBldg then
                return Team.util.lerpPos(bestBldg.pos, myAncient, 550), "Осада линии"
            end
        end
    end

    -- 5. Default: Laning / Push anchor
    return Team.macro.findLaneAnchor(hero, snapshot), "На линии"
end

function Team:DecideTeam(snapshot)
    local ok, result = pcall(function()
        return self:DecideTeamSafe(snapshot)
    end)
    if ok and result then
        return result
    end
    return {}
end

function Team:DecideTeamSafe(snapshot)
    if not snapshot or not snapshot.heroes then return {} end
    local now = snapshot.time or 0
    local st = self.state

    -- Reset persistent state if a new match started in the same VM
    if now < (st.lastTime or -9999) - 30 then
        st.lastSwapAt = {}
        st.lastWardAt = {}
        st.lastDustAt = {}
        st.lastSmokeAt = -999
        st.prevHp = {}
        st.retreating = {}
        st.focusTargetId = nil
        st.focusSetAt = -999
        st.enemyHasInvis = false
        st.enemyHasEvasion = false
        st.enemyHasHeal = false
    end
    st.lastTime = now

    self.inv.scanThreats(snapshot)

    -- Shared team focus target
    st.focusTargetId = self.combat.selectTeamFocus(snapshot)
    local focusEnemy = nil
    if st.focusTargetId and snapshot.enemies then
        for _, e in ipairs(snapshot.enemies) do
            if e.id == st.focusTargetId and e.alive then
                focusEnemy = e
                break
            end
        end
    end

    local orders = {}
    local glyphUsedThisTick = false
    local ftn = self.const.FOUNTAIN[snapshot.team] or self.const.FOUNTAIN[2]

    for _, hero in ipairs(snapshot.heroes) do
        local hActions = {}
        local hpPct = (hero.maxHp and hero.maxHp > 0) and (hero.hp / hero.maxHp) or 1

        -- Instant actions (work even while dead)
        self.inv.learnAbilities(hero, hActions)
        self.inv.manageInventory(hero, snapshot, hActions)

        -- Strategic Buyback check (critical late-game base defense)
        if not hero.alive and hero.buybackReady and now > 1500 and (hero.position == 1 or hero.position == 2 or hero.position == 3) then
            local baseThreatened = false
            if snapshot.allies then
                for _, a in ipairs(snapshot.allies) do
                    if a.alive and a.underAttack and (a.kind == "ancient" or a.kind == "barracks") then
                        baseThreatened = true
                        break
                    end
                end
            end
            if baseThreatened then
                hActions[#hActions + 1] = { kind = "buyback", status = "Байбэк на защиту Трона!" }
            end
        end

        -- Smart Glyph check (once per tick)
        if not glyphUsedThisTick and (snapshot.glyphCooldown or 99) == 0 and snapshot.allies then
            for _, a in ipairs(snapshot.allies) do
                if a.alive and a.underAttack then
                    local bHpPct = (a.maxHp and a.maxHp > 0) and (a.hp / a.maxHp) or 1
                    local tier = a.tier or 1
                    if a.kind == "ancient" or a.kind == "barracks" or (a.kind == "tower" and tier >= 2 and bHpPct < 0.65) or (a.kind == "tower" and tier == 1 and bHpPct < 0.34) then
                        hActions[#hActions + 1] = { kind = "glyph", status = "Глиф!" }
                        glyphUsedThisTick = true
                        break
                    end
                end
            end
        end

        -- Alive hero primary order
        if hero.alive and not hero.channeling then
            -- Hysteresis retreat logic (retreat < 28%, re-engage > 46%)
            if hpPct < 0.28 then
                st.retreating[hero.id] = true
            elseif hpPct > 0.46 then
                st.retreating[hero.id] = false
            end

            -- Gather nearby visible enemies
            local nearbyEnemies = {}
            local nearestEnemyHero, nearestEnemyDist = nil, 99999
            if snapshot.enemies then
                for _, e in ipairs(snapshot.enemies) do
                    if e.kind == "hero" and e.alive and not e.invulnerable then
                        local d = self.util.dist2d(hero.pos, e.pos)
                        if d < 1400 then
                            nearbyEnemies[#nearbyEnemies + 1] = e
                        end
                        if not e.isIllusion and d < nearestEnemyDist then
                            nearestEnemyDist = d
                            nearestEnemyHero = e
                        end
                    end
                end
            end

            local primaryOrder = nil

            -- 1. Anti-invis Dust check (highest tactical priority when invis enemy nearby/vanished)
            primaryOrder = self.vision.tryUseDust(hero, snapshot)

            -- 2. Retreat if low HP
            if not primaryOrder and st.retreating[hero.id] then
                local itemAct = self.combat.useActiveItems(hero, snapshot, nearestEnemyHero, nearbyEnemies)
                if itemAct then
                    primaryOrder = itemAct
                elseif nearestEnemyHero and nearestEnemyDist < 1200 then
                    local away = self.util.stepAway(hero.pos, nearestEnemyHero.pos, 900)
                    primaryOrder = { kind = "move", position = away, status = "Отступаю на лоу ХП" }
                else
                    primaryOrder = { kind = "move", position = ftn, status = "Отход на базу" }
                end
            end

            -- 3. Deward visible enemy wards immediately if safe
            if not primaryOrder and (not nearestEnemyHero or nearestEnemyDist > 650) then
                local eWard = self.vision.findEnemyWard(hero, snapshot, 950)
                if eWard then
                    primaryOrder = { kind = "ward_focus", target_id = eWard.id, status = "Ломаю вражеский вард" }
                end
            end

            -- 4. Combat engagement (shared focus target or nearest enemy hero)
            local combatTarget = nil
            if focusEnemy and self.util.dist2d(hero.pos, focusEnemy.pos) <= 1350 then
                combatTarget = focusEnemy
            elseif nearestEnemyHero and nearestEnemyDist <= 1050 then
                combatTarget = nearestEnemyHero
            end

            if not primaryOrder and combatTarget then
                local d = self.util.dist2d(hero.pos, combatTarget.pos)
                local safeToDive = true
                -- Check if combatTarget is deep under enemy tower without creeps
                local towerGuard = self.macro.checkTowerSafety(hero, snapshot, combatTarget.pos)
                if towerGuard and (combatTarget.hp or 9999) > 220 then
                    safeToDive = false
                    primaryOrder = towerGuard
                end

                if safeToDive then
                    local itemAct = self.combat.useActiveItems(hero, snapshot, combatTarget, nearbyEnemies)
                    if itemAct then
                        primaryOrder = itemAct
                    else
                        local spellAct = self.combat.castHeroSpells(hero, snapshot, combatTarget, nearbyEnemies, hActions)
                        if spellAct then
                            primaryOrder = spellAct
                        else
                            local atkRange = hero.attackRange or 150
                            if hero.ranged and d < atkRange * 0.65 and combatTarget.attackRange and combatTarget.attackRange < 250 then
                                local kitePos = self.util.stepAway(hero.pos, combatTarget.pos, 260)
                                primaryOrder = { kind = "move", position = kitePos, status = "Кайчу милишника" }
                            else
                                primaryOrder = { kind = "attack", target_id = combatTarget.id, status = "Фокус врага!" }
                            end
                        end
                    end
                end
            end

            -- 5. Place Observer / Sentry Wards
            if not primaryOrder and (hero.position == 4 or hero.position == 5) then
                primaryOrder = self.vision.tryPlaceWards(hero, snapshot)
            end

            -- 6. Smoke of Deceit gank trigger (when 3+ allies grouped out of enemy sight in midgame)
            if not primaryOrder and now > 360 and now - (st.lastSmokeAt or -999) > self.const.SMOKE_CD and not hero.smoked and #nearbyEnemies == 0 then
                if self.util.hasActiveItem(hero, "item_smoke_of_deceit") then
                    local alliesGrouped = 1
                    for _, h in ipairs(snapshot.heroes) do
                        if h.id ~= hero.id and h.alive and self.util.dist2d(hero.pos, h.pos) < 850 then
                            alliesGrouped = alliesGrouped + 1
                        end
                    end
                    if alliesGrouped >= 3 then
                        st.lastSmokeAt = now
                        primaryOrder = { kind = "smoke", status = "Жму смок на ганк!" }
                    end
                end
            end

            -- 7. Map Objectives (Drops, Runes, Bounty, Lotus, Wisdom)
            if not primaryOrder then
                primaryOrder = self.macro.findObjective(hero, snapshot)
            end

            -- 8. Laning lasthit / deny / building push
            if not primaryOrder then
                local towerGuard = self.macro.checkTowerSafety(hero, snapshot, nil)
                if towerGuard then
                    primaryOrder = towerGuard
                else
                    primaryOrder = self.macro.laningAndPush(hero, snapshot)
                end
            end

            -- 9. Macro Movement & TP Rotation
            if not primaryOrder then
                local destPos, statusText = self.macro.findMacroTarget(hero, snapshot)
                local towerGuard = self.macro.checkTowerSafety(hero, snapshot, destPos)
                if towerGuard then
                    primaryOrder = towerGuard
                else
                    local distToDest = self.util.dist2d(hero.pos, destPos)
                    local tpReady = (hero.items and hero.items[15] == "item_tpscroll") and ((hero.itemCooldown and hero.itemCooldown[15] or 0) <= 0)
                    if tpReady and distToDest > 3400 and (self.util.dist2d(hero.pos, ftn) < 1200 or statusText == "Защита базы!" or statusText == "Стяжка к команде") then
                        primaryOrder = { kind = "tp", position = destPos, status = "TP: " .. statusText }
                    else
                        primaryOrder = { kind = "move", position = destPos, status = statusText }
                    end
                end
            end

            if primaryOrder then
                hActions[#hActions + 1] = primaryOrder
            end
        end

        st.prevHp[hero.id] = hero.hp
        if #hActions > 0 then
            orders[hero.id] = hActions
        end
    end

    return orders
end

return Team
