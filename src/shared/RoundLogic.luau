--!strict
-- Чистая логика без Roblox-сервисов: парсинг ответа ИИ, валидация, резерв. Тестируется в tests/RoundLogic.spec.luau.

local Config = require(script.Parent.Config)

export type Round = {
	goal: string,
	threat: string,
	arena: string,
	twist: string, -- имя из Config.Twists или "none"
	line: string, -- фраза ведущего без префикса
	voice: string, -- та же фраза по-английски для TTS
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
		twist = if rng:NextNumber() < Config.TwistChance then pick(Config.Twists, rng) else "none",
		line = string.format(Config.FallbackLines[goal], word),
		voice = Config.FallbackVoice[goal],
		word = word,
		fromAI = false,
	}
end

-- decoded: таблица из HttpService:JSONDecode ответа ИИ (или nil). Всё невалидное — в резерв.
function RoundLogic.fromAI(decoded: any, word: string, rng: Random): Round
	-- ИИ иногда сам пишет «ИИ говорит:», а сервер добавляет префикс ещё раз
	if type(decoded) == "table" and type(decoded.line) == "string" then
		decoded.line = string.gsub(decoded.line, "^%s*ИИ говорит%s*[:,!]?%s*", "")
		if type(decoded.voice) == "string" then
			decoded.voice = string.gsub(decoded.voice, "^%s*[Aa][Ii] [Ss]ays%s*[:,!]?%s*", "")
		end
	end
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
		twist = "none", -- подвох бросает сервер (AIHost), ИИ его только озвучивает
		line = decoded.line,
		-- кириллицу TTS не читает, длиннее 300 символов не принимает
		voice = if type(decoded.voice) == "string"
				and #decoded.voice > 0
				and #decoded.voice <= 250
				and not string.find(decoded.voice, "[\208\209]")
			then decoded.voice
			else Config.FallbackVoice[decoded.goal],
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

-- Окончания для основы: длинные раньше коротких (отрезаем одно, самое длинное подходящее).
-- shortcut: грубый стеммер без словаря — «собачка» не сведётся к «собака»; нужен словарь форм, если промахов много.
local ENDINGS = {
	"иками",
	"ятами",
	"ами",
	"ями",
	"иков",
	"иках",
	"ики",
	"ика",
	"ику",
	"иком",
	"ике",
	"ята",
	"ят",
	"ёнок",
	"енок",
	"онок",
	"ок",
	"ек",
	"ик",
	"ая",
	"яя",
	"ое",
	"ее",
	"ые",
	"ие",
	"ый",
	"ий",
	"ой",
	"ую",
	"юю",
	"ых",
	"их",
	"ым",
	"им",
	"ов",
	"ев",
	"ей",
	"ах",
	"ях",
	"ом",
	"ем",
	"ою",
	"ею",
	"ию",
	"ия",
	"ья",
	"ье",
	"ы",
	"и",
	"а",
	"я",
	"у",
	"ю",
	"е",
	"о",
	"ь",
	"й",
}

-- Основа слова для поиска в банке моделей: «коты», «котики», «котов» → «кот». Каждое слово фразы отдельно.
-- Одна и та же функция для слова игрока и для ключей банка — важна согласованность, а не грамматика.
function RoundLogic.stem(word: string): string
	local parts = {}
	for token in string.gmatch((string.gsub(word, "ё", "е")), "[^%s]+") do
		for _, ending in ENDINGS do
			local cut = #token - #ending
			if cut > 0 and string.sub(token, cut + 1) == ending and (utf8.len(string.sub(token, 1, cut)) or 0) >= 2 then
				token = string.sub(token, 1, cut)
				break
			end
		end
		table.insert(parts, token)
	end
	return table.concat(parts, " ")
end

-- Косметика за монеты (следы, эмоции): не куплен — купить (если хватает) и надеть; куплен — надеть/снять.
-- owned — id через запятую (атрибут игрока не хранит таблицы). Нельзя купить — первым вернётся nil.
function RoundLogic.buyItem(
	owned: string,
	equipped: string?,
	coins: number,
	id: string,
	price: number
): (string?, string?, number)
	if table.find(string.split(owned, ","), id) then
		return owned, if equipped == id then nil else id, coins
	end
	if coins < price then
		return nil, equipped, coins
	end
	return if owned == "" then id else `{owned},{id}`, id, coins - price
end

return RoundLogic
