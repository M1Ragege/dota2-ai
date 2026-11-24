local BaseBot = require("sdk/dota_base/init")
local DK_ULT = "dragon_knight_elder_dragon_form"
local MAIDEN = "npc_dota_hero_crystal_maiden"

return BaseBot.Create({
    name = "Sample Radiant",
    draft = {
        { "npc_dota_hero_juggernaut", "npc_dota_hero_luna", "npc_dota_hero_sven" },
        { "npc_dota_hero_dragon_knight", "npc_dota_hero_lina", "npc_dota_hero_viper" },
        { "npc_dota_hero_centaur", "npc_dota_hero_tidehunter", "npc_dota_hero_axe" },
        { "npc_dota_hero_lion", "npc_dota_hero_vengefulspirit", "npc_dota_hero_shadow_shaman" },
        { "npc_dota_hero_crystal_maiden", "npc_dota_hero_jakiro", "npc_dota_hero_lich" },
    },
    style = {
        preGameMode = "safe_bounty",
        jungleMinTime = 240,
        jungleSearchRange = 3200,
        farmWaveRange = 1000,
        pushMinAlive = 4,
        commsFlame = 0,
    },
    ScoreFarmCamp = function(ctx, snapshot, actor, camp, score)
        if actor.position == 1 and camp.target and camp.count > 1 then
            return score + 250
        end
    end,
    heroProfiles = {
        npc_dota_hero_dragon_knight = {
            lane = "mid",
            draftWeight = 12,
            startItems = { "item_tango", "item_quelling_blade", "item_branches", "item_branches" },
            itemBuild = { "item_bottle", "item_power_treads", "item_blink", "item_black_king_bar", "item_assault" },
            skillBuild = { [2] = "dragon_knight_wyrms_wrath", [3] = "dragon_knight_dragon_tail" },
            style = { laneDistanceOffset = 120, laneStrafeScale = 0.45, laneHarass = false },
            manualAbilities = { [DK_ULT] = true },
            UseAbilities = function(ctx, snapshot, actor, env)
                if not ctx.U.canCast(actor, env.skills[DK_ULT]) then return nil end
                local tower = env.macro.phase == "PUSH" and env.macro.targetBuilding
                if env.enemyCount >= 2 or (tower and env.macro.targetId
                    and ctx.U.dist(actor.pos, tower.pos) <= 700) then
                    return { kind = "cast", ability = DK_ULT, status = "Форма на драку или осаду" }
                end
            end,
            OnComms = function(ctx, snapshot, actor, macro, directive)
                local now = snapshot.time
                if not actor.alive or directive or macro.phase ~= "LANING" or now < 240
                    or now < (ctx.heroMem.nextCall or 0) or ctx.U.ratio(actor.hp, actor.maxHp) < 0.60 then
                    return
                end
                local target = ctx.U.nearest(snapshot.enemies, actor.pos, 750, function(e)
                    return ctx.U.isRealHero(e) and not e.invulnerable and ctx.U.ratio(e.hp, e.maxHp) < 0.65
                end)
                if not target then return end
                local support = ctx.U.nearest(snapshot.heroes, actor.pos, 2300, function(h)
                    return h.name == MAIDEN and ctx.U.ratio(h.hp, h.maxHp) >= 0.55
                end)
                if not support then return end
                ctx.heroMem.nextCall = now + 45
                ctx.setDirective({
                    kind = "HELP_GANK", callerId = actor.id, pos = actor.pos,
                    assignedIds = { [support.id] = true }, expiresAt = now + 8,
                })
                ctx.say(actor, "ЦМ, подойди на мид. У цели мало здоровья.", "call")
            end,
        },
        [MAIDEN] = {
            lane = "safe",
            style = { laneDistanceOffset = 165, laneStrafeScale = 0.30 },
            LanePosition = function(ctx, snapshot, actor, lane)
                local core = ctx.U.nearest(snapshot.heroes, actor.pos, 800, function(h)
                    return h.position <= 3 and h.lane == actor.lane
                end)
                if core then return ctx.U.towards(core.pos, lane.basePos, 290) end
            end,
            OnComms = function(ctx, snapshot, actor, macro, directive)
                if actor.alive and directive and directive.kind == "HELP_GANK"
                    and directive.assignedIds and directive.assignedIds[actor.id]
                    and ctx.heroMem.repliedTo ~= directive.expiresAt then
                    ctx.heroMem.repliedTo = directive.expiresAt
                    ctx.say(actor, "Вижу колл, иду помогать.", "reply", 0.5)
                end
            end,
        },
    },
})
