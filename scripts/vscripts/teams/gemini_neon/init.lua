local BaseBot = require("sdk/dota_base/init")

return BaseBot.Create({
    name = "Gemini Neon",
    lanes = { "safe", "mid", "off", "off", "safe" },

    style = {
        randomDraft       = true,
        laningEndTime     = 480,
        roshanMinTime     = 1020,
        tormentorMinTime  = 900,
        pushLaneOrder     = { mid = 1, bot = 2, top = 3 },
        pushMinAlive      = 3,
        hgMinAlive        = 4,
        retreatHp         = 0.26,
    },

    BanHero = function(ctx, available)
        for _, h in ipairs({
            "npc_dota_hero_phantom_lancer",
            "npc_dota_hero_huskar",
            "npc_dota_hero_riki",
            "npc_dota_hero_broodmother",
        }) do
            if available[h] then return h end
        end
    end,
})
