-- Главный цикл: пауза → (ловушка?) → приказ «ИИ говорит» → цель+угроза → итог → слово победителя → следующий раунд быстрее.

local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RoundLogic = require(ReplicatedStorage.Shared.RoundLogic)
local AIHost = require(script.Parent.AIHost)
local Arena = require(script.Parent.Arena)
local Goals = require(script.Parent.Goals)
local ModelCache = require(script.Parent.ModelCache)
local Remotes = require(script.Parent.Remotes)
local Roster = require(script.Parent.Players)
local Threats = require(script.Parent.Threats)
local WordService = require(script.Parent.WordService)

local RoundService = {}

local rng = Random.new()
local roundNumber = 0
local streak = 0 -- сколько раундов подряд хоть кто-то выжил (рекорд серии сервера)

local function state(phase: string, timeLeft: number, extra: { [string]: any }?)
	local s = { phase = phase, timeLeft = timeLeft, alive = #Roster.alive(), round = roundNumber, streak = streak }
	for k, v in extra or {} do
		s[k] = v
	end
	Remotes.State:FireAllClients(s)
end

-- voice: английская версия для TTS (nil — молча)
local function announce(text: string, isAISays: boolean, voice: string?)
	Remotes.Announce:FireAllClients(text, isAISays, voice)
end

-- Ловушка: приказ БЕЗ «ИИ говорит». Кто подчинился (прыгнул) — вылетает.
local function trap()
	local line, voice = AIHost.trapLine()
	announce(line, false, voice)
	local conns = {}
	for _, p in Roster.alive() do
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			table.insert(
				conns,
				hum.StateChanged:Connect(function(_, new)
					if new == Enum.HumanoidStateType.Jumping then
						Roster.eliminate(p, "trap")
					end
				end)
			)
		end
	end
	for t = Config.Timing.TrapWindow, 1, -1 do
		state("trap", t)
		task.wait(1)
	end
	for _, c in conns do
		c:Disconnect()
	end
	local out = 0
	for _, p in PlayersService:GetPlayers() do
		if p:GetAttribute("LastOut") == "trap" then
			out += 1
		end
	end
	if out > 0 then
		announce(
			`Ха! Я не говорил «ИИ говорит». Минус {out}.`,
			false,
			`Ha! I never said AI says. Minus {out}.`
		)
	else
		announce("Хм, никто не попался. Умные...", false, "Hmm, nobody fell for it. Smart...")
	end
	task.wait(2)
end

local function playRound(word: string, duration: number, round: RoundLogic.Round): Player?
	roundNumber += 1
	print(`[Round {roundNumber}] {round.goal}+{round.threat} word={word} ai={round.fromAI}`)

	Arena.build()
	for _, p in PlayersService:GetPlayers() do
		p:SetAttribute("LastOut", nil)
	end
	Roster.startRound()
	task.wait(1)

	if rng:NextNumber() < Config.Timing.TrapChance then
		trap()
	end

	announce(`{Config.AI_PREFIX} {round.line}`, true, `{Config.AI_PREFIX_VOICE} {round.voice}`)
	local ctx = { word = word, duration = duration, rng = rng }
	local finishGoal = Goals[round.goal](ctx)
	local stopThreat = Threats[round.threat](ctx)

	local t0 = os.clock()
	while os.clock() - t0 < duration and #Roster.alive() > 0 do
		for _, p in Roster.alive() do -- упал с арены
			local r = Roster.root(p)
			if r and r.Position.Y < Arena.FloorY - 15 then
				Roster.eliminate(p, "fell")
			end
		end
		state("round", math.ceil(duration - (os.clock() - t0)), { goal = round.goal, threat = round.threat })
		task.wait(0.5)
	end

	stopThreat()
	finishGoal()

	local survivors = Roster.alive()
	for _, p in survivors do
		p:SetAttribute("Wins", (p:GetAttribute("Wins") or 0) + 1)
	end
	streak = if #survivors > 0 then streak + 1 else 0
	if #survivors == 0 then
		announce("Никто не выжил. Я непобедим!", false, "Nobody survived. I am unbeatable!")
		return nil
	end
	local winner = survivors[rng:NextInteger(1, #survivors)]
	announce(
		`Выжили: {#survivors}. {winner.DisplayName}, дай мне слово для следующего раунда!`,
		false,
		`{#survivors} survived. {winner.DisplayName}, give me a word for the next round!`
	)
	return winner
end

function RoundService.run()
	local duration = Config.Timing.RoundStart
	local word = WordService.randomWord()
	while true do
		while #PlayersService:GetPlayers() < Config.MinPlayers do
			state("waiting", 0)
			task.wait(1)
		end
		-- ИИ думает во время паузы, а не после неё
		local round: RoundLogic.Round? = nil
		task.spawn(function()
			local ok, built = pcall(AIHost.buildRound, word)
			round = if ok then built else RoundLogic.fallback(word, rng)
		end)
		for t = Config.Timing.Intermission, 1, -1 do
			state("intermission", t)
			task.wait(1)
		end
		while not round do
			state("thinking", 0)
			task.wait(0.2)
		end
		local winner = playRound(word, duration, round)
		state("word", Config.Timing.WordPrompt, { winner = winner and winner.DisplayName })
		word = WordService.ask(winner)
		-- 3D-модель готовится в фоне; пока не готова — шар с подписью
		ModelCache.request(word)
		duration = math.max(Config.Timing.RoundMin, duration * Config.Timing.SpeedUp)
	end
end

return RoundService
