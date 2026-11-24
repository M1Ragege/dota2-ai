-- ============================================================================
-- SDK: Расширенные профили способностей и билдов популярных героев (Pos 1..5)
-- Подключается автоматически из sdk/dota_base/init.lua
-- mode: "target" | "point" | "self" | "ally" | "orb" | "passive" | "toggle_heal" | "manual"
-- ("manual" — скилл качается по order, но база не кастует его сама, чтобы не суицидиться)
-- ============================================================================

local HeroPack = {}

HeroPack.SKILLS = {
    -- ======================== POS 1 (CARRY) ========================
    npc_dota_hero_phantom_assassin = {
        order = { 1, 2, 1, 3, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
        list = {
            { "phantom_assassin_stifling_dagger", "target", 1000, "nuke" },
            { "phantom_assassin_phantom_strike", "target", 1000, "finish" },
            { "phantom_assassin_blur", "self", 700, "def" },
            { "phantom_assassin_coup_de_grace", "passive", 0, "pass" },
        },
    },
    npc_dota_hero_faceless_void = {
        order = { 1, 3, 1, 2, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
        list = {
            { "faceless_void_time_walk", "manual", 650, "pass" },
            { "faceless_void_time_dilation", "self", 725, "nuke" },
            { "faceless_void_time_lock", "passive", 0, "pass" },
            { "faceless_void_chronosphere", "point", 600, "group" },
        },
    },
    npc_dota_hero_antimage = {
        order = { 1, 2, 1, 3, 2, 4, 2, 2, 1, 1, 3, 4, 3, 3, 4 },
        list = {
            { "antimage_mana_break", "passive", 0, "pass" },
            { "antimage_blink", "manual", 900, "pass" },
            { "antimage_counterspell", "self", 650, "def" },
            { "antimage_mana_void", "target", 600, "finish" },
        },
    },
    npc_dota_hero_slark = {
        order = { 3, 2, 1, 1, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
        list = {
            { "slark_dark_pact", "self", 325, "nuke" },
            { "slark_pounce", "manual", 600, "pass" },
            { "slark_essence_shift", "passive", 0, "pass" },
            { "slark_shadow_dance", "self", 550, "def" },
        },
    },
    npc_dota_hero_ursa = {
        order = { 3, 1, 3, 2, 3, 4, 3, 2, 2, 2, 1, 4, 1, 1, 4 },
        list = {
            { "ursa_earthshock", "self", 360, "nuke" },
            { "ursa_overpower", "self", 650, "def" },
            { "ursa_fury_swipes", "passive", 0, "pass" },
            { "ursa_enrage", "self", 500, "def" },
        },
    },
    npc_dota_hero_chaos_knight = {
        order = { 1, 3, 2, 3, 3, 4, 3, 2, 2, 2, 1, 4, 1, 1, 4 },
        list = {
            { "chaos_knight_chaos_bolt", "target", 500, "stun" },
            { "chaos_knight_reality_rift", "target", 650, "nuke" },
            { "chaos_knight_chaos_strike", "passive", 0, "pass" },
            { "chaos_knight_phantasm", "self", 750, "ult" },
        },
    },
    npc_dota_hero_gyrocopter = {
        order = { 1, 2, 1, 3, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
        list = {
            { "gyrocopter_rocket_barrage", "self", 400, "nuke" },
            { "gyrocopter_homing_missile", "target", 1050, "stun" },
            { "gyrocopter_flak_cannon", "self", 900, "nuke" },
            { "gyrocopter_call_down", "point", 1000, "group" },
        },
    },
    npc_dota_hero_terrorblade = {
        order = { 3, 2, 2, 1, 2, 4, 2, 3, 3, 3, 1, 4, 1, 1, 4 },
        list = {
            { "terrorblade_reflection", "point", 700, "nuke" },
            { "terrorblade_conjure_image", "self", 750, "nuke" },
            { "terrorblade_metamorphosis", "self", 850, "ult" },
            { "terrorblade_sunder", "target", 475, "sunder" },
        },
    },
    npc_dota_hero_phantom_lancer = {
        order = { 1, 2, 1, 3, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
        list = {
            { "phantom_lancer_spirit_lance", "target", 750, "nuke" },
            { "phantom_lancer_doppelwalk", "point", 575, "def" },
            { "phantom_lancer_phantom_edge", "passive", 0, "pass" },
            { "phantom_lancer_juxtapose", "passive", 0, "pass" },
        },
    },
    npc_dota_hero_bloodseeker = {
        order = { 1, 3, 2, 3, 3, 4, 3, 1, 1, 1, 2, 4, 2, 2, 4 },
        list = {
            { "bloodseeker_bloodrage", "self", 700, "def" },
            { "bloodseeker_blood_bath", "point", 1100, "silence" },
            { "bloodseeker_thirst", "passive", 0, "pass" },
            { "bloodseeker_rupture", "target", 800, "ult" },
        },
    },

    -- ======================== POS 2 (MID) ========================
    npc_dota_hero_queenofpain = {
        order = { 1, 2, 3, 3, 3, 4, 3, 2, 2, 2, 1, 4, 1, 1, 4 },
        list = {
            { "queenofpain_shadow_strike", "target", 600, "nuke" },
            { "queenofpain_blink", "manual", 900, "pass" },
            { "queenofpain_scream_of_pain", "self", 525, "nuke" },
            { "queenofpain_sonic_wave", "point", 900, "group" },
        },
    },
    npc_dota_hero_storm_spirit = {
        order = { 1, 3, 1, 2, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
        list = {
            { "storm_spirit_static_remnant", "self", 260, "nuke" },
            { "storm_spirit_electric_vortex", "target", 300, "stun" },
            { "storm_spirit_overload", "passive", 0, "pass" },
            { "storm_spirit_ball_lightning", "manual", 800, "pass" },
        },
    },
    npc_dota_hero_puck = {
        order = { 1, 3, 1, 2, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
        list = {
            { "puck_illusory_orb", "point", 1100, "nuke" },
            { "puck_waning_rift", "point", 400, "silence" },
            { "puck_phase_shift", "self", 450, "def" },
            { "puck_dream_coil", "point", 750, "group" },
        },
    },
    npc_dota_hero_zuus = {
        order = { 1, 2, 1, 3, 2, 4, 2, 2, 1, 1, 3, 4, 3, 3, 4 },
        list = {
            { "zuus_arc_lightning", "target", 850, "nuke" },
            { "zuus_lightning_bolt", "target", 700, "stun" },
            { "zuus_heavenly_jump", "self", 500, "def" },
            { "zuus_thundergods_wrath", "self", 1300, "finish" },
        },
    },
    npc_dota_hero_sniper = {
        order = { 1, 2, 1, 3, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
        list = {
            { "sniper_shrapnel", "point", 1200, "nuke" },
            { "sniper_headshot", "passive", 0, "pass" },
            { "sniper_take_aim", "self", 850, "def" },
            { "sniper_assassinate", "target", 1300, "finish" },
        },
    },
    npc_dota_hero_leshrac = {
        order = { 3, 1, 3, 2, 3, 4, 3, 2, 2, 2, 1, 4, 1, 1, 4 },
        list = {
            { "leshrac_split_earth", "point", 750, "stun" },
            { "leshrac_diabolic_edict", "self", 500, "push_ult" },
            { "leshrac_lightning_storm", "target", 700, "nuke" },
            { "leshrac_pulse_nova", "manual", 450, "pass" },
        },
    },
    npc_dota_hero_huskar = {
        order = { 2, 3, 2, 1, 2, 4, 2, 3, 3, 3, 1, 4, 1, 1, 4 },
        list = {
            { "huskar_inner_fire", "self", 450, "nuke" },
            { "huskar_burning_spear", "orb", 500, "nuke" },
            { "huskar_berserkers_blood", "passive", 0, "pass" },
            { "huskar_life_break", "target", 550, "ult" },
        },
    },
    npc_dota_hero_obsidian_destroyer = {
        order = { 2, 1, 3, 1, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
        list = {
            { "obsidian_destroyer_arcane_orb", "orb", 500, "nuke" },
            { "obsidian_destroyer_astral_imprisonment", "target", 650, "stun" },
            { "obsidian_destroyer_equilibrium", "passive", 0, "pass" },
            { "obsidian_destroyer_sanity_eclipse", "point", 700, "group" },
        },
    },
    npc_dota_hero_windrunner = {
        order = { 2, 3, 2, 1, 2, 4, 2, 3, 3, 3, 1, 4, 1, 1, 4 },
        list = {
            { "windrunner_shackleshot", "target", 800, "stun" },
            { "windrunner_powershot", "point", 1200, "nuke" },
            { "windrunner_windrun", "self", 700, "def" },
            { "windrunner_focusfire", "target", 650, "ult" },
        },
    },
    npc_dota_hero_kunkka = {
        order = { 2, 1, 2, 3, 2, 4, 2, 1, 1, 1, 3, 4, 3, 3, 4 },
        list = {
            { "kunkka_torrent", "point", 1100, "stun" },
            { "kunkka_tidebringer", "passive", 0, "pass" },
            { "kunkka_x_marks_the_spot", "target", 800, "nuke" },
            { "kunkka_ghostship", "point", 1000, "group" },
        },
    },
    npc_dota_hero_razor = {
        order = { 1, 2, 1, 3, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
        list = {
            { "razor_plasma_field", "self", 700, "nuke" },
            { "razor_static_link", "target", 550, "debuff" },
            { "razor_storm_surge", "passive", 0, "pass" },
            { "razor_eye_of_the_storm", "self", 550, "ult" },
        },
    },

    -- ======================== POS 3 (OFFLANE) ========================
    npc_dota_hero_mars = {
        order = { 1, 2, 1, 3, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
        list = {
            { "mars_spear", "point", 900, "stun" },
            { "mars_gods_rebuke", "point", 500, "nuke" },
            { "mars_bulwark", "passive", 0, "pass" },
            { "mars_arena_of_blood", "point", 400, "group" },
        },
    },
    npc_dota_hero_bristleback = {
        order = { 2, 3, 2, 1, 2, 4, 2, 3, 3, 3, 1, 4, 1, 1, 4 },
        list = {
            { "bristleback_viscous_nasal_goo", "target", 600, "debuff" },
            { "bristleback_quill_spray", "self", 625, "nuke" },
            { "bristleback_bristleback", "passive", 0, "pass" },
            { "bristleback_warpath", "passive", 0, "pass" },
        },
    },
    npc_dota_hero_legion_commander = {
        order = { 1, 3, 1, 2, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
        list = {
            { "legion_commander_overwhelming_odds", "self", 550, "nuke" },
            { "legion_commander_press_the_attack", "ally", 700, "buff" },
            { "legion_commander_moment_of_courage", "passive", 0, "pass" },
            { "legion_commander_duel", "manual", 260, "ult" },
        },
    },
    npc_dota_hero_abyssal_underlord = {
        order = { 1, 3, 1, 2, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
        list = {
            { "abyssal_underlord_firestorm", "point", 750, "nuke" },
            { "abyssal_underlord_pit_of_malice", "point", 750, "stun" },
            { "abyssal_underlord_atrophy_aura", "passive", 0, "pass" },
            { "abyssal_underlord_dark_portal", "manual", 900, "pass" },
        },
    },
    npc_dota_hero_magnataur = {
        order = { 1, 2, 3, 1, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
        list = {
            { "magnataur_shockwave", "point", 1000, "nuke" },
            { "magnataur_empower", "ally", 800, "buff" },
            { "magnataur_skewer", "manual", 800, "pass" },
            { "magnataur_reverse_polarity", "self", 410, "group" },
        },
    },
    npc_dota_hero_enigma = {
        order = { 2, 1, 2, 3, 2, 4, 2, 1, 1, 1, 3, 4, 3, 3, 4 },
        list = {
            { "enigma_malefice", "target", 600, "stun" },
            { "enigma_demonic_conversion", "point", 650, "nuke" },
            { "enigma_midnight_pulse", "point", 700, "nuke" },
            { "enigma_black_hole", "point", 350, "group" },
        },
    },
    npc_dota_hero_doom_bringer = {
        order = { 1, 2, 3, 2, 2, 4, 2, 3, 3, 3, 1, 4, 1, 1, 4 },
        list = {
            { "doom_bringer_devour", "manual", 300, "pass" },
            { "doom_bringer_scorched_earth", "self", 600, "def" },
            { "doom_bringer_infernal_blade", "target", 250, "stun" },
            { "doom_bringer_doom", "target", 550, "ult" },
        },
    },
    npc_dota_hero_necrolyte = {
        order = { 1, 3, 1, 2, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
        list = {
            { "necrolyte_death_pulse", "self", 500, "nuke" },
            { "necrolyte_ghost_shroud", "self", 450, "def" },
            { "necrolyte_heartstopper_aura", "passive", 0, "pass" },
            { "necrolyte_reapers_scythe", "target", 600, "finish" },
        },
    },
    npc_dota_hero_night_stalker = {
        order = { 1, 3, 1, 2, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
        list = {
            { "night_stalker_void", "target", 525, "stun" },
            { "night_stalker_crippling_fear", "self", 375, "silence" },
            { "night_stalker_hunter_in_the_night", "passive", 0, "pass" },
            { "night_stalker_darkness", "self", 900, "ult" },
        },
    },

    -- ======================== POS 4 (SOFT SUPPORT) ========================
    npc_dota_hero_earthshaker = {
        order = { 1, 3, 2, 1, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
        list = {
            { "earthshaker_fissure", "point", 1200, "stun" },
            { "earthshaker_enchant_totem", "self", 350, "nuke" },
            { "earthshaker_aftershock", "passive", 0, "pass" },
            { "earthshaker_echo_slam", "self", 550, "group" },
        },
    },
    npc_dota_hero_skywrath_mage = {
        order = { 1, 2, 1, 3, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
        list = {
            { "skywrath_mage_arcane_bolt", "target", 875, "nuke" },
            { "skywrath_mage_concussive_shot", "self", 1200, "nuke" },
            { "skywrath_mage_ancient_seal", "target", 700, "silence" },
            { "skywrath_mage_mystic_flare", "point", 1100, "ult" },
        },
    },
    npc_dota_hero_rubick = {
        order = { 2, 1, 2, 3, 2, 4, 2, 3, 3, 3, 1, 4, 1, 1, 4 },
        list = {
            { "rubick_telekinesis", "target", 625, "stun" },
            { "rubick_fade_bolt", "target", 800, "nuke" },
            { "rubick_arcane_supremacy", "passive", 0, "pass" },
            { "rubick_spell_steal", "target", 1000, "debuff" },
        },
    },
    npc_dota_hero_snapfire = {
        order = { 1, 2, 1, 3, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
        list = {
            { "snapfire_scatterblast", "point", 750, "nuke" },
            { "snapfire_firesnap_cookie", "ally", 700, "buff" },
            { "snapfire_lil_shredder", "self", 750, "nuke" },
            { "snapfire_mortimer_kisses", "point", 1200, "group" },
        },
    },
    npc_dota_hero_hoodwink = {
        order = { 1, 2, 1, 3, 1, 4, 1, 2, 2, 2, 3, 4, 3, 3, 4 },
        list = {
            { "hoodwink_acorn_shot", "point", 850, "nuke" },
            { "hoodwink_bushwhack", "point", 900, "stun" },
            { "hoodwink_scurry", "self", 650, "def" },
            { "hoodwink_sharpshooter", "point", 1300, "finish" },
        },
    },
    npc_dota_hero_spirit_breaker = {
        order = { 1, 3, 2, 3, 3, 4, 3, 1, 1, 1, 2, 4, 2, 2, 4 },
        list = {
            { "spirit_breaker_charge_of_darkness", "target", 1100, "stun" },
            { "spirit_breaker_bulldoze", "self", 700, "def" },
            { "spirit_breaker_greater_bash", "passive", 0, "pass" },
            { "spirit_breaker_nether_strike", "target", 700, "finish" },
        },
    },
    npc_dota_hero_venomancer = {
        order = { 1, 2, 3, 3, 3, 4, 3, 2, 2, 2, 1, 4, 1, 1, 4 },
        list = {
            { "venomancer_venomous_gale", "point", 850, "nuke" },
            { "venomancer_poison_sting", "passive", 0, "pass" },
            { "venomancer_plague_ward", "point", 800, "nuke" },
            { "venomancer_noxious_plague", "target", 800, "ult" },
        },
    },

    -- ======================== POS 5 (HARD SUPPORT) ========================
    npc_dota_hero_disruptor = {
        order = { 1, 2, 3, 2, 2, 4, 2, 3, 3, 3, 1, 4, 1, 1, 4 },
        list = {
            { "disruptor_thunder_strike", "target", 800, "nuke" },
            { "disruptor_glimpse", "target", 1000, "debuff" },
            { "disruptor_kinetic_field", "point", 900, "stun" },
            { "disruptor_static_storm", "point", 800, "group" },
        },
    },
    npc_dota_hero_warlock = {
        order = { 1, 2, 1, 3, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
        list = {
            { "warlock_fatal_bonds", "target", 900, "debuff" },
            { "warlock_shadow_word", "ally", 700, "heal" },
            { "warlock_upheaval", "point", 900, "group" },
            { "warlock_rain_of_chaos", "point", 1100, "group" },
        },
    },
    npc_dota_hero_dazzle = {
        order = { 1, 3, 1, 2, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
        list = {
            { "dazzle_poison_touch", "target", 700, "nuke" },
            { "dazzle_shallow_grave", "ally", 750, "save" },
            { "dazzle_shadow_wave", "ally", 800, "heal" },
            { "dazzle_bad_juju", "passive", 0, "pass" },
        },
    },
    npc_dota_hero_silencer = {
        order = { 1, 2, 1, 3, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
        list = {
            { "silencer_curse_of_the_silent", "point", 950, "nuke" },
            { "silencer_glaives_of_wisdom", "orb", 620, "nuke" },
            { "silencer_last_word", "target", 900, "silence" },
            { "silencer_global_silence", "self", 1200, "group" },
        },
    },
    npc_dota_hero_undying = {
        order = { 1, 3, 1, 2, 3, 4, 3, 3, 2, 2, 2, 4, 1, 1, 4 },
        list = {
            { "undying_decay", "point", 650, "nuke" },
            { "undying_soul_rip", "ally", 750, "heal" },
            { "undying_tombstone", "point", 600, "group" },
            { "undying_flesh_golem", "self", 650, "ult" },
        },
    },
    npc_dota_hero_bane = {
        order = { 2, 3, 2, 1, 2, 4, 2, 3, 3, 3, 1, 4, 1, 1, 4 },
        list = {
            { "bane_enfeeble", "target", 900, "debuff" },
            { "bane_brain_sap", "target", 625, "nuke" },
            { "bane_nightmare", "target", 550, "stun" },
            { "bane_fiends_grip", "target", 625, "ult" },
        },
    },
    npc_dota_hero_abaddon = {
        order = { 2, 1, 2, 3, 2, 4, 2, 1, 1, 1, 3, 4, 3, 3, 4 },
        list = {
            { "abaddon_death_coil", "ally", 625, "heal" },
            { "abaddon_aphotic_shield", "ally", 650, "buff" },
            { "abaddon_frostmourne", "passive", 0, "pass" },
            { "abaddon_borrowed_time", "passive", 0, "pass" },
        },
    },
    npc_dota_hero_grimstroke = {
        order = { 1, 3, 1, 2, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
        list = {
            { "grimstroke_dark_artistry", "point", 1150, "nuke" },
            { "grimstroke_ink_creature", "target", 850, "silence" },
            { "grimstroke_spirit_walk", "ally", 700, "buff" },
            { "grimstroke_soul_chain", "target", 750, "group" },
        },
    },
    npc_dota_hero_ancient_apparition = {
        order = { 3, 2, 1, 2, 2, 4, 2, 1, 1, 1, 3, 4, 3, 3, 4 },
        list = {
            { "ancient_apparition_cold_feet", "target", 800, "nuke" },
            { "ancient_apparition_ice_vortex", "point", 1300, "debuff" },
            { "ancient_apparition_chilling_touch", "target", 850, "nuke" },
            { "ancient_apparition_ice_blast", "manual", 0, "ult" },
        },
    },
    npc_dota_hero_pugna = {
        order = { 1, 2, 1, 3, 1, 4, 1, 3, 3, 3, 2, 4, 2, 2, 4 },
        list = {
            { "pugna_nether_blast", "point", 450, "nuke" },
            { "pugna_decrepify", "target", 550, "debuff" },
            { "pugna_nether_ward", "point", 400, "group" },
            { "pugna_life_drain", "target", 700, "ult" },
        },
    },
}

HeroPack.HERO_BUILDS = {
    -- Pos 1
    npc_dota_hero_phantom_assassin = { "item_magic_wand", "item_power_treads", "item_desolator", "item_black_king_bar", "item_satanic", "item_monkey_king_bar" },
    npc_dota_hero_faceless_void    = { "item_magic_wand", "item_power_treads", "item_maelstrom", "item_manta", "item_black_king_bar", "item_butterfly", "item_skadi" },
    npc_dota_hero_antimage         = { "item_magic_wand", "item_power_treads", "item_manta", "item_butterfly", "item_skadi", "item_heart" },
    npc_dota_hero_slark            = { "item_magic_wand", "item_power_treads", "item_echo_sabre", "item_black_king_bar", "item_skadi", "item_butterfly" },
    npc_dota_hero_ursa             = { "item_magic_wand", "item_phase_boots", "item_blink", "item_black_king_bar", "item_satanic", "item_skadi" },
    npc_dota_hero_chaos_knight     = { "item_bracer", "item_power_treads", "item_echo_sabre", "item_manta", "item_heart", "item_assault" },
    npc_dota_hero_gyrocopter       = { "item_magic_wand", "item_power_treads", "item_dragon_lance", "item_black_king_bar", "item_butterfly", "item_satanic" },
    npc_dota_hero_terrorblade      = { "item_wraith_band", "item_power_treads", "item_dragon_lance", "item_manta", "item_skadi", "item_butterfly" },
    npc_dota_hero_phantom_lancer   = { "item_magic_wand", "item_power_treads", "item_manta", "item_heart", "item_skadi", "item_butterfly" },
    npc_dota_hero_bloodseeker      = { "item_magic_wand", "item_phase_boots", "item_maelstrom", "item_black_king_bar", "item_sange_and_yasha", "item_butterfly" },

    -- Pos 2
    npc_dota_hero_queenofpain      = { "item_bottle", "item_power_treads", "item_orchid", "item_kaya_and_sange", "item_black_king_bar", "item_shivas_guard" },
    npc_dota_hero_storm_spirit     = { "item_bottle", "item_power_treads", "item_orchid", "item_kaya_and_sange", "item_black_king_bar", "item_sheepstick" },
    npc_dota_hero_puck             = { "item_bottle", "item_power_treads", "item_blink", "item_kaya", "item_sheepstick", "item_shivas_guard" },
    npc_dota_hero_zuus             = { "item_bottle", "item_arcane_boots", "item_aether_lens", "item_kaya_and_sange", "item_force_staff", "item_sheepstick" },
    npc_dota_hero_sniper           = { "item_wraith_band", "item_power_treads", "item_dragon_lance", "item_maelstrom", "item_hurricane_pike", "item_greater_crit" },
    npc_dota_hero_leshrac          = { "item_bottle", "item_arcane_boots", "item_kaya_and_sange", "item_black_king_bar", "item_shivas_guard", "item_sheepstick" },
    npc_dota_hero_huskar           = { "item_bracer", "item_phase_boots", "item_sange", "item_black_king_bar", "item_satanic", "item_heart" },
    npc_dota_hero_obsidian_destroyer = { "item_null_talisman", "item_power_treads", "item_dragon_lance", "item_hurricane_pike", "item_black_king_bar", "item_sheepstick" },
    npc_dota_hero_windrunner       = { "item_bottle", "item_power_treads", "item_maelstrom", "item_black_king_bar", "item_greater_crit", "item_sheepstick" },
    npc_dota_hero_kunkka           = { "item_bottle", "item_phase_boots", "item_blade_mail", "item_black_king_bar", "item_shivas_guard", "item_heart" },
    npc_dota_hero_razor            = { "item_wraith_band", "item_phase_boots", "item_sange_and_yasha", "item_black_king_bar", "item_shivas_guard", "item_satanic" },

    -- Pos 3
    npc_dota_hero_mars             = { "item_bracer", "item_phase_boots", "item_blink", "item_black_king_bar", "item_shivas_guard", "item_assault" },
    npc_dota_hero_bristleback      = { "item_bracer", "item_phase_boots", "item_blade_mail", "item_crimson_guard", "item_pipe", "item_heart" },
    npc_dota_hero_legion_commander = { "item_bracer", "item_phase_boots", "item_blade_mail", "item_blink", "item_black_king_bar", "item_assault" },
    npc_dota_hero_abyssal_underlord = { "item_bracer", "item_arcane_boots", "item_pipe", "item_crimson_guard", "item_guardian_greaves", "item_shivas_guard" },
    npc_dota_hero_magnataur        = { "item_bracer", "item_arcane_boots", "item_blink", "item_force_staff", "item_black_king_bar", "item_shivas_guard" },
    npc_dota_hero_enigma           = { "item_arcane_boots", "item_blink", "item_black_king_bar", "item_pipe", "item_shivas_guard" },
    npc_dota_hero_doom_bringer     = { "item_bracer", "item_phase_boots", "item_blink", "item_black_king_bar", "item_shivas_guard", "item_assault" },
    npc_dota_hero_necrolyte        = { "item_null_talisman", "item_arcane_boots", "item_kaya_and_sange", "item_shivas_guard", "item_pipe", "item_heart" },
    npc_dota_hero_night_stalker    = { "item_bracer", "item_phase_boots", "item_echo_sabre", "item_blink", "item_black_king_bar", "item_assault" },

    -- Pos 4 / 5
    npc_dota_hero_earthshaker      = { "item_arcane_boots", "item_blink", "item_force_staff", "item_black_king_bar", "item_shivas_guard" },
    npc_dota_hero_skywrath_mage    = { "item_null_talisman", "item_arcane_boots", "item_aether_lens", "item_force_staff", "item_sheepstick" },
    npc_dota_hero_rubick           = { "item_arcane_boots", "item_aether_lens", "item_blink", "item_force_staff", "item_glimmer_cape" },
    npc_dota_hero_snapfire         = { "item_arcane_boots", "item_force_staff", "item_glimmer_cape", "item_solar_crest", "item_guardian_greaves" },
    npc_dota_hero_hoodwink         = { "item_arcane_boots", "item_aether_lens", "item_maelstrom", "item_force_staff", "item_glimmer_cape" },
    npc_dota_hero_spirit_breaker   = { "item_bracer", "item_phase_boots", "item_blade_mail", "item_black_king_bar", "item_assault" },
    npc_dota_hero_venomancer       = { "item_arcane_boots", "item_force_staff", "item_glimmer_cape", "item_pipe", "item_shivas_guard" },
    npc_dota_hero_disruptor        = { "item_arcane_boots", "item_glimmer_cape", "item_force_staff", "item_aether_lens", "item_sheepstick" },
    npc_dota_hero_warlock          = { "item_arcane_boots", "item_glimmer_cape", "item_force_staff", "item_aether_lens", "item_guardian_greaves" },
    npc_dota_hero_dazzle           = { "item_arcane_boots", "item_glimmer_cape", "item_force_staff", "item_pavise", "item_solar_crest", "item_guardian_greaves" },
    npc_dota_hero_silencer         = { "item_null_talisman", "item_power_treads", "item_force_staff", "item_hurricane_pike", "item_sheepstick" },
    npc_dota_hero_undying          = { "item_bracer", "item_arcane_boots", "item_mekansm", "item_pipe", "item_guardian_greaves" },
    npc_dota_hero_bane             = { "item_arcane_boots", "item_aether_lens", "item_glimmer_cape", "item_force_staff", "item_sheepstick" },
    npc_dota_hero_abaddon          = { "item_arcane_boots", "item_mekansm", "item_pavise", "item_solar_crest", "item_pipe", "item_guardian_greaves" },
    npc_dota_hero_grimstroke       = { "item_arcane_boots", "item_aether_lens", "item_glimmer_cape", "item_force_staff", "item_sheepstick" },
    npc_dota_hero_pugna            = { "item_arcane_boots", "item_aether_lens", "item_glimmer_cape", "item_force_staff", "item_kaya" },
}

return HeroPack
