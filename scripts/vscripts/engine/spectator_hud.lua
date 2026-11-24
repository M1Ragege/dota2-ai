local SpectatorHUD = {}
SpectatorHUD.__index = SpectatorHUD

local LANES = { top = "Top", mid = "Mid", bot = "Bot" }
local RADIANT_COLOR = { 123, 236, 208 }
local DIRE_COLOR = { 255, 190, 121 }
local RADIANT_HEX = "#7beed0"
local DIRE_HEX = "#ffbe79"
local TONE_HEX = {
    call   = "#ffe57f", -- колл команды
    reply  = "#e6edf3", -- ответ союзника
    flame  = "#ff7a7a", -- ругань / тильт
    praise = "#98fb98", -- похвала
}

local function escapeHtml(text)
    return tostring(text or "")
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
end

function SpectatorHUD.new()
    return setmetatable({ labels = {}, lastMacro = {} }, SpectatorHUD)
end

local function extractStatus(action)
    if type(action) ~= "table" then return nil end
    if type(action.status) == "string" and action.status ~= "" then
        return action.status
    end
    for i = #action, 1, -1 do
        local item = action[i]
        if type(item) == "table" and type(item.status) == "string" and item.status ~= "" then
            return item.status
        end
    end
    return nil
end

function SpectatorHUD:Update(teamLabel, snapshot, actions)
    if type(actions._chat) == "table" then
        local teamHex = snapshot.team == DOTA_TEAM_GOODGUYS and RADIANT_HEX or DIRE_HEX
        for _, msg in ipairs(actions._chat) do
            if type(msg) == "table" and type(msg.text) == "string" and msg.text ~= "" then
                local sender = msg.sender or teamLabel
                local textHex = TONE_HEX[msg.tone] or "#ffffff"
                local html = string.format(
                    "<font color='%s'><b>[%s | %s]</b></font> <font color='%s'>%s</font>",
                    teamHex,
                    escapeHtml(teamLabel),
                    escapeHtml(sender),
                    textHex,
                    escapeHtml(msg.text)
                )
                print(string.format("[Comms][%s | %s]: %s", teamLabel, sender, msg.text))
                pcall(GameRules.SendCustomMessage, GameRules, html, 0, 0)
            end
        end
    end

    if type(actions._macro) == "string" and actions._macro ~= "" then
        local previous = self.lastMacro[teamLabel]
        if (not previous or previous.text ~= actions._macro)
            and (not previous or snapshot.time - previous.at >= 15) then
            self.lastMacro[teamLabel] = { text = actions._macro, at = snapshot.time }
            if GameRules.Tournament and GameRules.Tournament.NotifyChat then
                GameRules.Tournament:NotifyChat(
                    "info",
                    teamLabel .. " | MACRO",
                    actions._macro,
                    "macro_" .. teamLabel .. "_" .. tostring(math.floor(snapshot.time / 15))
                )
            end
        end
    end

    local color = snapshot.team == DOTA_TEAM_GOODGUYS and RADIANT_COLOR or DIRE_COLOR
    for _, actor in ipairs(snapshot.heroes) do
        if actor.alive then
            local status = extractStatus(actions[actor.id]) or "Играю"
            local label = string.format("[%s Pos %d | %s] %s",
                teamLabel, actor.position, LANES[actor.lane] or actor.lane, status)
            local previous = self.labels[actor.id]
            if not previous or (previous.text ~= label and snapshot.time - previous.at >= 0.65) then
                local hero = EntIndexToHScript(actor.id)
                if hero and not hero:IsNull() then
                    hero:SetCustomHealthLabel(label, color[1], color[2], color[3])
                    self.labels[actor.id] = { text = label, at = snapshot.time }
                end
            end
        else
            self.labels[actor.id] = nil
        end
    end
end

return SpectatorHUD
