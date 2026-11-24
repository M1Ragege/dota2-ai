local Talents = {}

local FIRST_LEVELS = { 10, 15, 20, 25 }
local SECOND_LEVELS = { 27, 28, 29, 30 }

function Talents.isTalent(name)
    return type(name) == "string" and name:find("^special_bonus_") ~= nil
        and name ~= "special_bonus_attributes"
        and name ~= "special_bonus_undefined"
end

function Talents.requiredLevels(abilities)
    abilities = abilities or {}
    local slots = {}
    for slot, ability in pairs(abilities) do
        if ability and Talents.isTalent(ability.name)
            and (ability.maxLevel == nil or ability.maxLevel == 1) then
            slots[#slots + 1] = slot
        end
    end
    table.sort(slots)

    -- Дерево хранит таланты парами по возрастанию тира.
    local levels = {}
    for tier, firstLevel in ipairs(FIRST_LEVELS) do
        local left = abilities[slots[tier * 2 - 1]]
        local right = abilities[slots[tier * 2]]
        if left and right then
            levels[left.name] = (right.level or 0) > 0 and SECOND_LEVELS[tier] or firstLevel
            levels[right.name] = (left.level or 0) > 0 and SECOND_LEVELS[tier] or firstLevel
        end
    end
    return levels
end

function Talents.firstAvailable(abilities)
    local best, bestReq, bestSlot
    for slot, ability in pairs(abilities or {}) do
        if ability and ability.canUpgrade and (ability.level or 0) == 0
            and Talents.isTalent(ability.name) then
            local req = ability.talentRequiredLevel or 99
            if not best or req < bestReq or (req == bestReq and slot < bestSlot) then
                best, bestReq, bestSlot = ability, req, slot
            end
        end
    end
    return best
end

return Talents
