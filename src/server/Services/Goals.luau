-- Цели раунда. Каждая: start(ctx) -> finish(), finish() выбивает тех, кто цель не выполнил.
-- Новая цель = функция здесь + строка в Config.Goals + фраза в Config.FallbackLines.

local Debris = game:GetService("Debris")
local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Arena = require(script.Parent.Arena)
local Roster = require(script.Parent.Players)
local Remotes = require(script.Parent.Remotes)

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

-- Навесы: их вдвое меньше, чем игроков. В конце вылетает каждый, над кем нет крыши.
function Goals.hide(ctx: Ctx): () -> ()
	local roofs = {}
	local count = math.max(1, math.floor(#Roster.alive() / 2))
	for _ = 1, count do
		local hut = Instance.new("Model")
		hut.Name = "Shelter"
		local base = Arena.randomFloorPoint(ctx.rng) * Vector3.new(1, 0, 1) + Vector3.new(0, Arena.FloorY + 0.5, 0)
		-- крыша выше прыжка (~7.2), чтобы на неё нельзя было запрыгнуть
		local roof = Instance.new("Part")
		roof.Name = "Roof"
		roof.Anchored = true
		roof.Size = Vector3.new(7, 1, 7)
		roof.Position = base + Vector3.new(0, 8.5, 0)
		roof.Color = Color3.fromRGB(150, 90, 50)
		roof.Material = Enum.Material.WoodPlanks
		roof.Parent = hut
		for _, c in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
			local post = Instance.new("Part")
			post.Anchored = true
			post.Size = Vector3.new(0.6, 8, 0.6)
			post.Position = base + c * 3.2 + Vector3.new(0, 4, 0)
			post.Color = roof.Color
			post.Material = Enum.Material.Wood
			post.Parent = hut
		end
		hut.Parent = Arena.folder()
		table.insert(roofs, roof)
	end
	return function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = roofs
		for _, p in Roster.alive() do
			local r = Roster.root(p)
			if not r or not workspace:Raycast(r.Position, Vector3.new(0, 20, 0), params) then
				Roster.eliminate(p, "hide")
			end
		end
		for _, roof in roofs do
			(roof.Parent :: Instance):Destroy()
		end
	end
end

-- Толчок: короткая сила-констрейнт (как в Threats.wind) — персонаж под сетевым владением клиента.
local PUSH_TIME = 0.2
local function knock(target: BasePart, dir: Vector3)
	local att = target:FindFirstChild("RootAttachment") :: Attachment?
	if not att then
		return
	end
	local f = Instance.new("VectorForce")
	f.Attachment0 = att
	f.RelativeTo = Enum.ActuatorRelativeTo.World
	f.ApplyAtCenterOfMass = true
	local up = workspace.Gravity + 30 / PUSH_TIME -- компенсировать вес + подбросить, чтобы трение не гасило толчок
	f.Force = target.AssemblyMass * (dir * (Config.Push.Speed / PUSH_TIME) + Vector3.yAxis * up)
	f.Parent = target
	Debris:AddItem(f, PUSH_TIME)
end

-- Столкнуть кого-нибудь с арены. Клиент шлёт Push без аргументов, цель (ближайший живой) выбирает сервер.
-- Кто никого не столкнул — вылетает. Если в начале раунда живой один — требования нет.
function Goals.push(_ctx: Ctx): () -> ()
	local required = #Roster.alive() >= 2
	local lastPush: { [Player]: number } = {}
	local knocked: { [Player]: { by: Player, t: number } } = {}
	for _, p in PlayersService:GetPlayers() do
		p:SetAttribute("Pushed", nil)
	end
	local conn = Remotes.Push.OnServerEvent:Connect(function(p: Player)
		local r = Roster.root(p)
		local now = os.clock()
		if not r or not Roster.isAlive(p) or now - (lastPush[p] or 0) < Config.Push.Cooldown then
			return
		end
		lastPush[p] = now
		local best, bestDist = nil, Config.Push.Range
		for _, other in Roster.alive() do
			local o = if other ~= p then Roster.root(other) else nil
			if o and (o.Position - r.Position).Magnitude < bestDist then
				best, bestDist = other, (o.Position - r.Position).Magnitude
			end
		end
		local o = best and Roster.root(best)
		if best and o then
			local flat = (o.Position - r.Position) * Vector3.new(1, 0, 1)
			knock(o, if flat.Magnitude > 0.1 then flat.Unit else r.CFrame.LookVector)
			knocked[best] = { by = p, t = now }
		end
	end)
	local function credit()
		for target, k in knocked do
			local fresh = os.clock() - k.t < Config.Push.Credit
			if not Roster.isAlive(target) and fresh then
				k.by:SetAttribute("Pushed", true)
			end
			if not Roster.isAlive(target) or not fresh then
				knocked[target] = nil
			end
		end
	end
	local active = true
	task.spawn(function()
		while active do
			credit()
			task.wait(0.2)
		end
	end)
	return function()
		active = false
		conn:Disconnect()
		credit()
		for _, p in Roster.alive() do
			if required and not p:GetAttribute("Pushed") then
				Roster.eliminate(p, "push")
			end
		end
	end
end

return Goals
