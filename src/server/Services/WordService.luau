-- Победитель раунда даёт ИИ слово. Сервер принимает слово только от того, кого спросил, один раз, и фильтрует.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local RoundLogic = require(ReplicatedStorage.Shared.RoundLogic)
local Remotes = require(script.Parent.Remotes)

local WordService = {}

local waitingFor: Player? = nil
local received: string? = nil

local function filter(word: string, player: Player): string?
	local ok, result = pcall(function()
		local r = TextService:FilterStringAsync(word, player.UserId, Enum.TextFilterContext.PublicChat)
		return r:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or result ~= word then -- фильтр что-то заменил на ### — слово не берём
		return nil
	end
	return result
end

Remotes.SubmitWord.OnServerEvent:Connect(function(player, raw)
	if player ~= waitingFor or received then
		return
	end
	local word = RoundLogic.cleanWord(raw)
	if not word then
		return
	end
	waitingFor = nil -- одна попытка: дальше фильтр, повторные события игнорируются
	received = filter(word, player) or ""
end)

local rng = Random.new()

function WordService.randomWord(): string
	return Config.DefaultWords[rng:NextInteger(1, #Config.DefaultWords)]
end

-- Ждёт слово от победителя до Config.Timing.WordPrompt сек. Нет ответа / плохое слово → случайное из списка.
function WordService.ask(winner: Player?): string
	if not winner then
		return WordService.randomWord()
	end
	waitingFor, received = winner, nil
	Remotes.AskWord:FireClient(winner, Config.Timing.WordPrompt)
	local deadline = os.clock() + Config.Timing.WordPrompt
	while received == nil and os.clock() < deadline and winner.Parent do
		task.wait(0.2)
	end
	waitingFor = nil
	local word = received
	received = nil
	return if word and word ~= "" then word else WordService.randomWord()
end

return WordService
