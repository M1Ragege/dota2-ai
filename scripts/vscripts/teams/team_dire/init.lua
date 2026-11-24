local BaseBot = require("sdk/dota_base/init")

return BaseBot.Create({
    name = "Sample Dire",
    draft = {
        { "npc_dota_hero_sven", "npc_dota_hero_luna", "npc_dota_hero_juggernaut" },
        { "npc_dota_hero_viper", "npc_dota_hero_lina", "npc_dota_hero_dragon_knight" },
        { "npc_dota_hero_tidehunter", "npc_dota_hero_axe", "npc_dota_hero_centaur" },
        { "npc_dota_hero_shadow_shaman", "npc_dota_hero_lion", "npc_dota_hero_vengefulspirit" },
        { "npc_dota_hero_jakiro", "npc_dota_hero_witch_doctor", "npc_dota_hero_lich" },
    },
    style = {
        preGameMode = "smoke_invade",
        laningEndTime = 425,
        pushLaneOrder = { mid = 1, top = 2, bot = 3 },
        jungleSearchRange = 2400,
        farmWhileStaging = false,
        fightMinHp = 0.36,
        finishChaseRange = 300,
        commsFlame = 0,
    },
    PickFocus = function(ctx, snapshot)
        for _, enemy in ipairs(snapshot.enemies) do
            if ctx.U.isRealHero(enemy) and enemy.alive and enemy.channeling and not enemy.invulnerable
                and ctx.U.countNear(snapshot.heroes, enemy.pos, 800) >= 2 then
                return enemy
            end
        end
    end,
    heroProfiles = {
        npc_dota_hero_viper = {
            lane = "mid",
            draftWeight = 12,
            style = { laneDistanceOffset = -55, laneStrafeScale = 1.25, laneHarass = true },
        },
        npc_dota_hero_sven = {
            style = { jungleMinTime = 240, jungleSearchRange = 2900, finishMaxHits = 3 },
            ScoreFarmCamp = function(ctx, snapshot, actor, camp, score)
                if camp.count >= 3 then return score + 300 end
            end,
        },
    },
})
