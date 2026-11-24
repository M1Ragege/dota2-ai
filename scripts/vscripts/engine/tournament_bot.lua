function Spawn()
    if IsServer() then
        thisEntity:Attribute_SetIntValue("ai_tournament_bot", 1)
    end
end
