--!strict
-- Чистая логика без Roblox-сервисов: парсинг ответа ИИ, валидация, резерв. Тестируется в tests/RoundLogic.spec.luau.

local Config = require(script.Parent.Config)

export type Round = {
	goal: string,
	threat: string,
	arena: string,
	line: string, -- фраза ведущего без префикса
	word: string,
	fromAI: boolean,
}

local RoundLogic = {}

local function contains(list: { string }, value: any): boolean
	return type(value) == "string" and table.find(list, value) ~= nil
end

local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

local function allowedThreats(goal: string): { string }
	local banned = Config.Incompatible[goal] or {}
	local list = {}
	for _, t in Config.Threats do
		if not table.find(banned, t) then
			table.insert(list, t)
		end
	end
	return list
end

function RoundLogic.isFair(goal: string, threat: string): boolean
	return table.find(allowedThreats(goal), threat) ~= nil
end

-- Резерв: случайная комбинация + заготовленная фраза. Игра не ломается никогда.
function RoundLogic.fallback(word: string, rng: Random): Round
	local goal = pick(Config.Goals, rng)
	return {
		goal = goal,
		threat = pick(allowedThreats(goal), rng),
		arena = pick(Config.Arenas, rng),
		line = string.format(Config.FallbackLines[goal], word),
		word = word,
		fromAI = false,
	}
end

-- decoded: таблица из HttpService:JSONDecode ответа ИИ (или nil). Всё невалидное — в резерв.
function RoundLogic.fromAI(decoded: any, word: string, rng: Random): Round
	if
		type(decoded) ~= "table"
		or not contains(Config.Goals, decoded.goal)
		or not contains(Config.Threats, decoded.threat)
		or type(decoded.line) ~= "string"
		or #decoded.line == 0
		or utf8.len(decoded.line) == nil
		or (utf8.len(decoded.line) :: number) > 160
	then
		return RoundLogic.fallback(word, rng)
	end
	return {
		goal = decoded.goal,
		threat = if RoundLogic.isFair(decoded.goal, decoded.threat)
			then decoded.threat
			else pick(allowedThreats(decoded.goal), rng),
		arena = if contains(Config.Arenas, decoded.arena) then decoded.arena else pick(Config.Arenas, rng),
		line = decoded.line,
		word = word,
		fromAI = true,
	}
end

-- Достаёт первый {...} из текста модели: ИИ иногда оборачивает JSON в ```json.
function RoundLogic.extractJson(text: string): string?
	return string.match(text, "%b{}")
end

-- Слово игрока: обрезка, длина, только буквы/пробел/дефис. Фильтр Roblox — отдельно на сервере.
function RoundLogic.cleanWord(raw: any): string?
	if type(raw) ~= "string" then
		return nil
	end
	local word = string.lower(string.match(raw, "^%s*(.-)%s*$") :: string)
	local len = utf8.len(word)
	if len == nil or len < 2 or len > Config.MaxWordLength then
		return nil
	end
	if string.find(word, '[%c%d<>{}"\\]') then
		return nil
	end
	return word
end

return RoundLogic
