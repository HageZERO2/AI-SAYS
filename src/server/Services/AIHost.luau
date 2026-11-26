-- ИИ-ведущий: один запрос к Text Generation API на раунд. Любая ошибка → резерв из RoundLogic.fallback.
-- API в бете: имена TextGenerator / GenerateTextAsync сверять с create.roblox.com/docs/reference/engine/classes/TextGenerator.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RoundLogic = require(ReplicatedStorage.Shared.RoundLogic)

local AIHost = {}

local SYSTEM_PROMPT =
	[[Ты — ведущий детской игры "ИИ говорит" (как "Саймон говорит"). Ты дерзкий и смешной, без грубости.
Собери раунд ТОЛЬКО из разрешённых вариантов и ответь ОДНИМ JSON без пояснений:
{"goal": "<цель>", "threat": "<угроза>", "arena": "<арена>", "line": "<фраза ведущего до 120 символов, обязательно со словом игрока>"}
Цели: %s. Угрозы: %s. Арены: %s.
Не начинай line со слов "ИИ говорит" — сервер добавит их сам.]]

local generator: Instance? = nil
local okCreate = pcall(function()
	local g: any = Instance.new("TextGenerator" :: any)
	g.SystemPrompt = string.format(
		SYSTEM_PROMPT,
		table.concat(Config.Goals, ", "),
		table.concat(Config.Threats, ", "),
		table.concat(Config.Arenas, ", ")
	)
	g.Temperature = 0.9
	g.Parent = script
	generator = g
end)
if not okCreate then
	warn("[AIHost] TextGenerator недоступен — работаем на резерве")
end

local rng = Random.new()

-- Блокирует до ~нескольких секунд. Вызывать во время текущего раунда, чтобы следующий был готов заранее.
function AIHost.buildRound(word: string): RoundLogic.Round
	if not generator then
		return RoundLogic.fallback(word, rng)
	end
	-- Сама модель всегда выбирает collect+wind, поэтому кубики бросает сервер, а ИИ пишет фразу под них.
	local roll = RoundLogic.fallback(word, rng)
	-- UserPrompt целиком на кириллице API отвергает с HTTP 400, английская обёртка проходит.
	local prompt = string.format(
		"Player word for this round: %s. This round MUST use goal=%s, threat=%s, arena=%s.",
		word,
		roll.goal,
		roll.threat,
		roll.arena
	)
	local ok, result
	-- API в бете случайно отвечает HTTP 400 (тот же промпт через секунду проходит): повтор с паузой.
	for attempt = 1, 3 do
		ok, result = pcall(function()
			(generator :: any).Seed = rng:NextInteger(1, 2 ^ 30)
			return (generator :: any):GenerateTextAsync({ UserPrompt = prompt })
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	if not ok or type(result) ~= "table" or type(result.GeneratedText) ~= "string" then
		warn("[AIHost] генерация не удалась:", result)
		return RoundLogic.fallback(word, rng)
	end
	local json = RoundLogic.extractJson(result.GeneratedText)
	local decoded = json and select(2, pcall(HttpService.JSONDecode, HttpService, json))
	return RoundLogic.fromAI(decoded, word, rng)
end

function AIHost.trapLine(): string
	return Config.TrapLines[rng:NextInteger(1, #Config.TrapLines)]
end

return AIHost
