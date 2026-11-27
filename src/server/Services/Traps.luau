-- Ловушки: приказ БЕЗ «ИИ говорит». Каждая ловит одно действие: Traps.<kind>(players) -> stop().
-- Кто подчинился — вылетает (Roster.eliminate(p, "trap")). Новая ловушка = функция здесь + строки в Config.TrapLines.

local Arena = require(script.Parent.Arena)
local Roster = require(script.Parent.Players)

local Traps = {}

local function out(p: Player)
	Roster.eliminate(p, "trap")
end

local function humanoid(p: Player): Humanoid?
	return p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end

-- «Прыгайте!»
function Traps.jump(players: { Player }): () -> ()
	local conns = {}
	for _, p in players do
		local hum = humanoid(p)
		if hum then
			table.insert(
				conns,
				hum.StateChanged:Connect(function(_, new)
					if new == Enum.HumanoidStateType.Jumping then
						out(p)
					end
				end)
			)
		end
	end
	return function()
		for _, c in conns do
			c:Disconnect()
		end
	end
end

-- «Бегите!» — ловим ввод игрока (MoveDirection), а не скорость: толчок или скольжение не считаются.
function Traps.move(players: { Player }): () -> ()
	local active = true
	task.spawn(function()
		task.wait(0.4) -- время отпустить клавишу, если уже бежал
		while active do
			for _, p in players do
				local hum = humanoid(p)
				if hum and hum.MoveDirection.Magnitude > 0.5 then
					out(p)
				end
			end
			task.wait(0.1)
		end
	end)
	return function()
		active = false
	end
end

-- «Напишите в чат!» — Player.Chatted срабатывает и с TextChatService.
function Traps.chat(players: { Player }): () -> ()
	local conns = {}
	for _, p in players do
		table.insert(
			conns,
			p.Chatted:Connect(function()
				out(p)
			end)
		)
	end
	return function()
		for _, c in conns do
			c:Disconnect()
		end
	end
end

-- «Встаньте на красное!» — несколько плиток загораются; кто на них встал — вылет.
-- Плитки выбираем подальше от игроков, чтобы никто не стоял на красном заранее.
function Traps.tile(players: { Player }): () -> ()
	local roots = {}
	for _, p in players do
		table.insert(roots, Roster.root(p))
	end
	local free = {}
	for _, t in Arena.tiles() do
		local near = false
		for _, r in roots do
			if ((r.Position - t.Position) * Vector3.new(1, 0, 1)).Magnitude < 8 then
				near = true
			end
		end
		if not near and t.CanCollide then
			table.insert(free, t)
		end
	end
	local rng = Random.new()
	local lit: { [BasePart]: { Color3 | Enum.Material } } = {}
	for _ = 1, math.min(#free, 6 + #players * 2) do
		local t = table.remove(free, rng:NextInteger(1, #free)) :: BasePart
		lit[t] = { t.Color, t.Material }
		t.Color = Color3.fromRGB(255, 40, 40)
		t.Material = Enum.Material.Neon
	end
	local active = true
	task.spawn(function()
		while active do
			for _, p in players do
				local r = Roster.root(p)
				if r and Roster.isAlive(p) then
					for t in lit do
						local d = (r.Position - t.Position) * Vector3.new(1, 0, 1)
						if math.abs(d.X) < t.Size.X / 2 and math.abs(d.Z) < t.Size.Z / 2 then
							out(p)
						end
					end
				end
			end
			task.wait(0.1)
		end
	end)
	return function()
		active = false
		for t, saved in lit do
			t.Color = saved[1] :: Color3
			t.Material = saved[2] :: Enum.Material
		end
	end
end

return Traps
