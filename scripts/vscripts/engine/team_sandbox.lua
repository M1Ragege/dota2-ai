local TeamSandbox = {}

local function loadChunk(modulePath)
    if package and package.loaders then
        for _, loader in ipairs(package.loaders) do
            local ok, chunk = pcall(loader, modulePath)
            if ok and type(chunk) == "function" then
                return chunk
            end
        end
    end
    if type(loadfile) == "function" then
        local candidates = {
            modulePath .. ".lua",
            "scripts/vscripts/" .. modulePath .. ".lua",
        }
        for _, path in ipairs(candidates) do
            local chunk = loadfile(path)
            if type(chunk) == "function" then
                return chunk
            end
        end
    end
    error("Не удалось загрузить Lua-модуль стратегии: " .. tostring(modulePath))
end

local function makeEnv(teamPrefix, cache, loaderFn)
    local env = {
        assert = assert,
        error = error,
        ipairs = ipairs,
        next = next,
        pairs = pairs,
        pcall = pcall,
        select = select,
        setmetatable = setmetatable,
        getmetatable = getmetatable,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        unpack = unpack,
        math = {
            abs = math.abs, acos = math.acos, asin = math.asin,
            atan = math.atan, atan2 = math.atan2, ceil = math.ceil,
            cos = math.cos, deg = math.deg, exp = math.exp,
            floor = math.floor, fmod = math.fmod, huge = math.huge,
            log = math.log, max = math.max, min = math.min,
            modf = math.modf, pi = math.pi, pow = math.pow,
            rad = math.rad, random = math.random, sin = math.sin,
            sqrt = math.sqrt, tan = math.tan,
        },
        string = {
            byte = string.byte, char = string.char, find = string.find,
            format = string.format, gmatch = string.gmatch, gsub = string.gsub,
            len = string.len, lower = string.lower, match = string.match,
            rep = string.rep, reverse = string.reverse, sub = string.sub,
            upper = string.upper,
        },
        table = {
            concat = table.concat, insert = table.insert,
            remove = table.remove, sort = table.sort,
        },
    }

    env.require = function(dep)
        assert(type(dep) == "string", "require ожидает строку")
        local normalized = dep:gsub("%.", "/"):gsub("^/+", "")
        assert(not dep:find("..", 1, true) and normalized:match("^[%w_/%-]+$")
            and not normalized:find("//", 1, true) and normalized:sub(-1) ~= "/",
            "Запрещённый путь в require: " .. dep)

        local fullPath
        if normalized:sub(1, #teamPrefix) == teamPrefix then
            fullPath = normalized
        elseif normalized:sub(1, 4) == "sdk/" or normalized == "teams/sample_ai_team" then
            fullPath = normalized
        else
            fullPath = teamPrefix .. normalized
        end

        if cache[fullPath] == nil then
            cache[fullPath] = loaderFn(fullPath)
        end
        return cache[fullPath]
    end

    return env
end

function TeamSandbox.Load(folderName)
    assert(type(folderName) == "string" and folderName:match("^[%w_%-]+$"),
        "Некорректное имя папки команды: '" .. tostring(folderName) .. "'. Папка должна содержать только английские буквы, цифры, дефис или подчёркивание (без пробелов и точек, например: 'gemini_neon')")

    local teamPrefix = "teams/" .. folderName .. "/"
    local entry = teamPrefix .. "init"
    local cache = {}

    local function loadModule(path)
        local chunk = loadChunk(path)
        local env = makeEnv(teamPrefix, cache, loadModule)
        setfenv(chunk, env)
        return chunk()
    end

    local strategy = loadModule(entry)
    assert(type(strategy) == "table", "Стратегия " .. folderName .. " должна вернуть таблицу")
    assert(type(strategy.DecideTeam) == "function" or type(strategy.Decide) == "function",
        "Стратегия " .. folderName .. " должна реализовать DecideTeam(snapshot) или Decide(snapshot, actor)")
    assert(type(strategy.PickHero) == "function" or type(strategy.draft) == "table",
        "Стратегия " .. folderName .. " должна задать draft или PickHero(...)")

    return strategy
end

return TeamSandbox
