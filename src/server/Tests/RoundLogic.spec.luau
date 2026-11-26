-- Самопроверка чистой логики. Запускается автоматически при Play в Studio (см. init.server.luau), в проде — нет.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local RoundLogic = require(ReplicatedStorage.Shared.RoundLogic)

return function()
	local rng = Random.new(42)

	-- валидный ответ ИИ принимается
	local r = RoundLogic.fromAI(
		{ goal = "survive", threat = "lava", arena = "school", line = "акулы!" },
		"акулы",
		rng
	)
	assert(r.fromAI and r.goal == "survive" and r.threat == "lava", "valid AI round")
	assert(r.voice == Config.FallbackVoice.survive, "no voice → fallback voice")
	local v = RoundLogic.fromAI({ goal = "survive", threat = "lava", line = "a", voice = "Run!" }, "x", rng)
	assert(v.voice == "Run!", "AI voice kept")
	local dup = RoundLogic.fromAI(
		{ goal = "survive", threat = "lava", line = "ИИ говорит: беги!", voice = "AI says: run!" },
		"x",
		rng
	)
	assert(dup.line == "беги!" and dup.voice == "run!", "duplicate prefix stripped")
	local cyr = RoundLogic.fromAI({ goal = "survive", threat = "lava", line = "a", voice = "Беги!" }, "x", rng)
	assert(cyr.voice == Config.FallbackVoice.survive, "cyrillic voice → fallback")

	-- мусор и чужие значения → резерв
	assert(not RoundLogic.fromAI(nil, "x", rng).fromAI, "nil → fallback")
	assert(not RoundLogic.fromAI({ goal = "fly", threat = "lava", line = "a" }, "x", rng).fromAI, "unknown goal")
	assert(
		not RoundLogic.fromAI({ goal = "survive", threat = "lava", line = string.rep("а", 200) }, "x", rng).fromAI,
		"long line"
	)

	-- нечестная пара чинится, а не принимается
	for _ = 1, 20 do
		local f = RoundLogic.fromAI({ goal = "freeze", threat = "lava", line = "замри" }, "x", rng)
		assert(RoundLogic.isFair(f.goal, f.threat), "unfair pair fixed")
		local fb = RoundLogic.fallback("x", rng)
		assert(RoundLogic.isFair(fb.goal, fb.threat), "fallback is fair")
		assert(string.find(fb.line, "x", 1, true), "fallback line has word")
		assert(fb.twist == "none" or table.find(Config.Twists, fb.twist), "fallback twist valid")
	end

	-- JSON в обёртке
	assert(RoundLogic.extractJson('```json\n{"goal":"survive"}\n```') == '{"goal":"survive"}', "extract json")

	-- слово игрока
	assert(RoundLogic.cleanWord("  Sharks ") == "sharks", "trim+lower")
	assert(RoundLogic.cleanWord("бабушка") == "бабушка", "cyrillic ok")
	assert(RoundLogic.cleanWord("a") == nil, "too short")
	assert(RoundLogic.cleanWord(string.rep("я", Config.MaxWordLength + 1)) == nil, "too long")
	assert(RoundLogic.cleanWord("<b>x</b>") == nil, "markup")
	assert(RoundLogic.cleanWord("123") == nil, "digits")
	assert(RoundLogic.cleanWord(42) == nil, "non-string")

	-- формы слова сводятся к одной основе (поиск модели в банке)
	for _, pair in
		{
			{ "кот", "коты" },
			{ "кот", "котики" },
			{ "кот", "котов" },
			{ "кот", "котята" },
			{ "собака", "собаки" },
			{ "лошадь", "лошади" },
			{ "ёж", "ежи" },
			{ "яблоко", "яблоки" },
			{ "золотая рыбка", "золотые рыбки" },
		}
	do
		assert(RoundLogic.stem(pair[1]) == RoundLogic.stem(pair[2]), `stem: {pair[1]} vs {pair[2]}`)
	end
	assert(RoundLogic.stem("кот") ~= RoundLogic.stem("кит"), "stem keeps different words apart")

	-- Config согласован с обработчиками: забыть функцию или фразу = упасть при первом таком раунде
	local Services = script.Parent.Parent.Services
	local Goals = require(Services.Goals)
	local Threats = require(Services.Threats)
	for _, g in Config.Goals do
		assert(type(Goals[g]) == "function", "no Goals." .. g)
		assert(Config.FallbackLines[g], "no FallbackLines." .. g)
		assert(Config.FallbackVoice[g], "no FallbackVoice." .. g)
		local fair = 0
		for _, t in Config.Threats do
			fair += if RoundLogic.isFair(g, t) then 1 else 0
		end
		assert(fair > 0, "goal without fair threats: " .. g)
	end
	for _, t in Config.Threats do
		assert(type(Threats[t]) == "function", "no Threats." .. t)
	end
	local Traps = require(Services.Traps)
	for _, line in Config.TrapLines do
		assert(type(Traps[line.kind]) == "function", "no Traps." .. tostring(line.kind))
		assert(line.text and line.voice, "trap line without text/voice")
		assert(not string.find(line.text, Config.AI_PREFIX, 1, true), "trap must not say AI_PREFIX")
	end
	local Twists = require(Services.Twists)
	assert(type(Twists.none) == "function", "no Twists.none")
	for _, t in Config.Twists do
		assert(type(Twists[t]) == "function", "no Twists." .. t)
		assert(Config.TwistNames[t] and Config.TwistHints[t], "no TwistNames/TwistHints." .. t)
	end
	local Arena = require(Services.Arena)
	for _, a in Config.Arenas do
		assert(Arena.Themes[a], "no Arena theme: " .. a)
	end

	-- банк слов: ключи в том виде, в каком слово приходит от игрока; случайные слова всегда с моделью
	local WordBank = require(script.Parent.Parent.WordBank)
	for word in WordBank do
		assert(RoundLogic.cleanWord(word) == word, "WordBank key not clean: " .. word)
	end
	for _, word in Config.DefaultWords do
		assert(WordBank[word], "DefaultWords not baked: " .. word)
	end

	print("[Tests] RoundLogic OK")
end
