-- Цели раунда. Каждая: start(ctx) -> finish(), finish() выбивает тех, кто цель не выполнил.
-- Новая цель = функция здесь + строка в Config.Goals + фраза в Config.FallbackLines.

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

return Goals
