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

	print("[Tests] RoundLogic OK")
end
