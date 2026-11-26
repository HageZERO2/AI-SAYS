-- Цели раунда. Каждая: start(ctx) -> finish(), finish() выбивает тех, кто цель не выполнил.
-- Новая цель = функция здесь + строка в Config.Goals + фраза в Config.FallbackLines.

local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Arena = require(script.Parent.Arena)
local Roster = require(script.Parent.Players)

type Ctx = { word: string, duration: number, rng: Random }

local Goals = {}

function Goals.survive(_ctx: Ctx): () -> ()
	return function() end -- дожил до конца таймера = выполнил
end

function Goals.reach_zone(ctx: Ctx): () -> ()
	local zone = Instance.new("Part")
	zone.Name = "Zone"
	zone.Anchored = true
	zone.CanCollide = false
	zone.Material = Enum.Material.Neon
	zone.Color = Color3.fromRGB(60, 255, 120)
	zone.Transparency = 0.4
	zone.Size = Vector3.new(10, 1, 10)
	zone.Position = Vector3.new(0, Arena.FloorY + 0.6, 0) -- центр: не исчезает при сжатии пола
		+ Vector3.new(ctx.rng:NextNumber(-3, 3), 0, ctx.rng:NextNumber(-3, 3))
	zone.Parent = Arena.folder()
	return function()
		for _, p in Roster.alive() do
			local r = Roster.root(p)
			local d = r and (r.Position - zone.Position) * Vector3.new(1, 0, 1)
			if not d or math.abs(d.X) > 5 or math.abs(d.Z) > 5 then
				Roster.eliminate(p, "zone")
			end
		end
		zone:Destroy()
	end
end

function Goals.freeze(_ctx: Ctx): () -> ()
	local active = true
	task.spawn(function()
		task.wait(2.5) -- время остановиться
		while active do
			for _, p in Roster.alive() do
				local r = Roster.root(p)
				if r and r.AssemblyLinearVelocity.Magnitude > 2 then
					Roster.eliminate(p, "moved")
				end
			end
			task.wait(0.2)
		end
	end)
	return function()
		active = false
	end
end

function Goals.collect(ctx: Ctx): () -> ()
	local target = Config.CollectTarget
	local alive = Roster.alive()
	for _, p in alive do
		p:SetAttribute("Collected", 0)
	end
	-- Звёзд меньше, чем нужно всем: кто-то не успеет.
	local count = math.max(target, math.floor(#alive * target * 0.75))
	local stars = {}
	for _ = 1, count do
		local star = Instance.new("Part")
		star.Name = "Star"
		star.Anchored = true
		star.CanCollide = false
		star.Material = Enum.Material.Neon
		star.Color = Color3.fromRGB(255, 220, 40)
		star.Size = Vector3.new(2, 2, 2)
		star.Position = Arena.randomFloorPoint(ctx.rng)
		star.Touched:Connect(function(hit)
			local model = hit:FindFirstAncestorOfClass("Model")
			local p = model and PlayersService:GetPlayerFromCharacter(model)
			if p and Roster.isAlive(p) and star.Parent then
				star:Destroy()
				p:SetAttribute("Collected", (p:GetAttribute("Collected") or 0) + 1)
			end
		end)
		star.Parent = Arena.folder()
		table.insert(stars, star)
	end
	return function()
		for _, p in Roster.alive() do
			if (p:GetAttribute("Collected") or 0) < target then
				Roster.eliminate(p, "collect")
			end
		end
		for _, star in stars do
			star:Destroy()
		end
	end
end

return Goals
