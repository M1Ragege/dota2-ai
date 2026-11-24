local MapObjectives = {}
MapObjectives.__index = MapObjectives

local MODIFIERS = {
    lotus = "modifier_passive_lotus_pool",
    wisdom = "modifier_xp_fountain_aura",
}

local function valid(entity)
    return entity and not entity:IsNull()
end

function MapObjectives.new()
    return setmetatable({
        thinkers = { lotus = {}, wisdom = {} },
        nextScanAt = -math.huge,
    }, MapObjectives)
end

function MapObjectives:Update()
    local now = GameRules:GetGameTime()
    if now < self.nextScanAt then return end
    self.nextScanAt = now + 1

    -- Награду и эффекты обрабатывает Dota. Заряд хранится в модификаторе
    -- скрытого npc_dota_thinker, а его caster указывает на объект карты.
    local thinkers = { lotus = {}, wisdom = {} }
    for _, entity in ipairs(Entities:FindAllByClassname("npc_dota_thinker")) do
        if valid(entity) then
            for kind, name in pairs(MODIFIERS) do
                local modifier = entity:FindModifierByName(name)
                if valid(modifier) then
                    local caster = modifier:GetCaster()
                    if valid(caster) then thinkers[kind][caster:entindex()] = entity end
                end
            end
        end
    end
    self.thinkers = thinkers
end

function MapObjectives:GetPinState(entIndex, kind)
    local byIndex = self.thinkers[kind]
    local thinker = byIndex and byIndex[entIndex]
    if not valid(thinker) then return nil, nil end
    local modifier = thinker:FindModifierByName(MODIFIERS[kind])
    if not valid(modifier) then return nil, nil end

    local count = modifier:GetStackCount()
    return count > 0, count
end

return MapObjectives
