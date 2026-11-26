-- Угрозы раунда. Каждая: start(ctx) -> stop(). ctx.word — слово победителя.
-- Новая угроза = новая функция здесь + строка в Config.Threats.

local Debris = game:GetService("Debris")
local PlayersService = game:GetService("Players")

local Arena = require(script.Parent.Arena)
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

function Threats.falling(ctx: Ctx): () -> ()
	local active = true
	task.spawn(function()
		while active do
			local drop = Instance.new("Part")
			drop.Name = "Falling_" .. ctx.word
			drop.Shape = Enum.PartType.Ball
			drop.Size = Vector3.one * ctx.rng:NextNumber(3, 6)
			drop.Color = Color3.fromHSV(ctx.rng:NextNumber(), 0.7, 1)
			drop.Position = Arena.randomFloorPoint(ctx.rng) + Vector3.new(0, 45, 0)
			-- shortcut: шар с подписью вместо 3D-модели из слова; неделя 2 — GenerationService + кэш
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(160, 40)
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
			gui.Parent = drop
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

return Threats
