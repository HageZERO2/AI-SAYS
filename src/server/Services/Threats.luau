-- Угрозы раунда. Каждая: start(ctx) -> stop(). ctx.word — слово победителя.
-- Новая угроза = новая функция здесь + строка в Config.Threats.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local PlayersService = game:GetService("Players")

local Arena = require(script.Parent.Arena)
local ModelCache = require(script.Parent.ModelCache)
local Roster = require(script.Parent.Players)

export type Ctx = { word: string, duration: number, rng: Random }

local Threats = {}

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return model and PlayersService:GetPlayerFromCharacter(model)
end

function Threats.lava(ctx: Ctx): () -> ()
	local lava = Instance.new("Part")
	lava.Name = "Lava"
	lava.Anchored = true
	lava.CanCollide = false
	lava.Material = Enum.Material.Neon
	lava.Color = Color3.fromRGB(255, 90, 20)
	lava.Size = Vector3.new(Arena.Size + 40, 4, Arena.Size + 40)
	local startY, endY = Arena.FloorY - 6, Arena.FloorY + 6
	lava.Position = Vector3.new(0, startY, 0)
	lava.Parent = Arena.folder()
	-- Лава поднимается выше пола: спастись можно только на столбах.
	local pillars = {}
	for i = 1, 6 do
		local pillar = Instance.new("Part")
		pillar.Name = "Pillar"
		pillar.Anchored = true
		pillar.Color = Color3.fromRGB(120, 110, 100)
		pillar.Size = Vector3.new(6, 6 + i * 2, 6)
		local pos = Arena.randomFloorPoint(ctx.rng)
		pillar.Position = Vector3.new(pos.X, Arena.FloorY + pillar.Size.Y / 2, pos.Z)
		pillar.Parent = Arena.folder()
		table.insert(pillars, pillar)
	end
	local active = true
	task.spawn(function()
		local t0 = os.clock()
		while active do
			local k = math.clamp((os.clock() - t0) / (ctx.duration * 0.8), 0, 1)
			local y = startY + (endY - startY) * k
			lava.Position = Vector3.new(0, y, 0)
			for _, p in Roster.alive() do
				local r = Roster.root(p)
				if r and r.Position.Y - 2 < y + 2 then
					Roster.eliminate(p, "lava")
				end
			end
			task.wait(0.1)
		end
	end)
	return function()
		active = false
		lava:Destroy()
		for _, pillar in pillars do
			pillar:Destroy()
		end
	end
end

-- Объект «из слова»: 3D-модель из кэша или цветной шар с подписью.
local function wordObject(ctx: Ctx, size: number): BasePart
	local cached = ModelCache.get(ctx.word, size)
	if cached then
		return cached
	end
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * size
	ball.Color = Color3.fromHSV(ctx.rng:NextNumber(), 0.7, 1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffset = Vector3.new(0, size / 2 + 1, 0)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = ctx.word
	label.Parent = gui
	gui.Parent = ball
	return ball
end

function Threats.falling(ctx: Ctx): () -> ()
	local active = true
	task.spawn(function()
		while active do
			local drop = wordObject(ctx, ctx.rng:NextNumber(3, 6))
			drop.Name = "Falling"
			drop.Anchored = false
			drop.Position = Arena.randomFloorPoint(ctx.rng) + Vector3.new(0, 45, 0)
			drop.Touched:Connect(function(hit)
				local p = playerFromHit(hit)
				if p then
					Roster.eliminate(p, "falling")
				end
			end)
			drop.Parent = Arena.folder()
			Debris:AddItem(drop, 6)
			task.wait(math.max(0.25, 0.8 - #Roster.alive() * 0.03)) -- больше игроков — гуще дождь
		end
	end)
	return function()
		active = false
	end
end

function Threats.shrink(ctx: Ctx): () -> ()
	local active = true
	task.spawn(function()
		local rings = 4 -- центральное кольцо (2×2) не трогаем
		local step = ctx.duration * 0.85 / rings
		for ring = 0, rings - 1 do
			task.wait(step - 1.5)
			if not active then
				return
			end
			for _, t in Arena.tiles() do
				if t:GetAttribute("Ring") == ring then
					t.Color = Color3.fromRGB(255, 60, 60) -- предупреждение
				end
			end
			task.wait(1.5)
			for _, t in Arena.tiles() do
				if t:GetAttribute("Ring") == ring and t.Parent then
					t.Transparency = 1
					t.CanCollide = false
				end
			end
		end
	end)
	return function()
		active = false
	end
end

-- Существо из слова гонится за ближайшим игроком; догнало — вылет. Чем больше игроков, тем больше существ.
function Threats.chaser(ctx: Ctx): () -> ()
	local active = true
	local SIZE = 5
	local chasers = {}
	for i = 1, 1 + math.floor(#Roster.alive() / 5) do
		local c = wordObject(ctx, SIZE)
		c.Name = "Chaser"
		c.Anchored = true
		c.CanCollide = false
		c.Position = Vector3.new((i % 2 * 2 - 1) * Arena.Size / 2, Arena.FloorY + SIZE / 2 + 0.5, 0)
		c.Parent = Arena.folder()
		table.insert(chasers, c)
	end
	task.spawn(function()
		local t0 = os.clock()
		local last = t0
		while active do
			local now = os.clock()
			local dt = now - last
			last = now
			local speed = 11 + 7 * math.clamp((now - t0) / ctx.duration, 0, 1) -- игрок бегает 16
			for _, c in chasers do
				local nearest, best = nil, math.huge
				for _, p in Roster.alive() do
					local r = Roster.root(p)
					local d = r and (r.Position - c.Position).Magnitude
					if d and d < best then
						nearest, best = r, d
					end
				end
				if nearest then
					local flat = (nearest.Position - c.Position) * Vector3.new(1, 0, 1)
					local victim = PlayersService:GetPlayerFromCharacter(nearest.Parent)
					if best < SIZE / 2 + 2.5 and victim then
						Roster.eliminate(victim, "chaser")
					elseif flat.Magnitude > 0.1 then
						c.CFrame = CFrame.lookAt(c.Position, c.Position + flat)
							+ flat.Unit * math.min(speed * dt, flat.Magnitude)
					end
				end
			end
			task.wait(0.05)
		end
	end)
	return function()
		active = false
		for _, c in chasers do
			c:Destroy()
		end
	end
end

-- Ветер толкает всех живых в одну сторону, каждые 4 с меняет направление. Сдуло с арены — вылет (проверяет RoundService).
function Threats.wind(ctx: Ctx): () -> ()
	local active = true
	local forces: { VectorForce } = {}
	local function clear()
		for _, f in forces do
			f:Destroy()
		end
		table.clear(forces)
	end
	task.spawn(function()
		while active do
			clear()
			local angle = ctx.rng:NextNumber(0, math.pi * 2)
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			for _, p in Roster.alive() do
				local r = Roster.root(p)
				local att = r and r:FindFirstChild("RootAttachment") :: Attachment?
				if r and att then
					-- Сила-констрейнт, а не ApplyImpulse: персонаж под сетевым владением клиента, импульс с сервера не сработает.
					local f = Instance.new("VectorForce")
					f.Attachment0 = att
					f.RelativeTo = Enum.ActuatorRelativeTo.World
					f.ApplyAtCenterOfMass = true
					f.Force = dir * r.AssemblyMass * 70
					f.Parent = r
					table.insert(forces, f)
				end
			end
			task.wait(4)
		end
	end)
	return function()
		active = false
		clear()
	end
end

-- Темнота: ночь и туман, у каждого игрока маленький фонарик. Опасность — в сочетании с целью (найти зону/звёзды).
function Threats.darkness(_ctx: Ctx): () -> ()
	local saved = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		FogEnd = Lighting.FogEnd,
		FogColor = Lighting.FogColor,
	}
	Lighting.ClockTime = 0
	Lighting.Brightness = 0
	Lighting.Ambient = Color3.new(0, 0, 0)
	Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
	Lighting.FogColor = Color3.new(0, 0, 0)
	Lighting.FogEnd = 40
	local lights = {}
	for _, p in Roster.alive() do
		local r = Roster.root(p)
		if r then
			local light = Instance.new("PointLight")
			light.Range = 14
			light.Brightness = 2
			light.Parent = r
			table.insert(lights, light)
		end
	end
	return function()
		for k, v in saved do
			(Lighting :: any)[k] = v
		end
		for _, light in lights do
			light:Destroy()
		end
	end
end

-- Гравитация скачет: то луна, то норма, то тяжесть. Высокие прыжки на низкой гравитации уносят за край.
function Threats.gravity(ctx: Ctx): () -> ()
	local original = workspace.Gravity
	local active = true
	task.spawn(function()
		local levels = { 35, original, 350 }
		while active do
			workspace.Gravity = levels[ctx.rng:NextInteger(1, #levels)]
			task.wait(5)
		end
	end)
	return function()
		active = false
		workspace.Gravity = original
	end
end

return Threats
