-- Кто в игре, а кто на трибунах. Единственное место, где меняется атрибут "Alive".

local PlayersService = game:GetService("Players")

local Arena = require(script.Parent.Arena)
local Vfx = require(script.Parent.Vfx)

local Roster = {}
local rng = Random.new()

local function root(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end
Roster.root = root

function Roster.isAlive(player: Player): boolean
	return player:GetAttribute("Alive") == true
end

function Roster.alive(): { Player }
	local list = {}
	for _, p in PlayersService:GetPlayers() do
		if Roster.isAlive(p) then
			table.insert(list, p)
		end
	end
	return list
end

function Roster.eliminate(player: Player, reason: string)
	if not Roster.isAlive(player) then
		return
	end
	player:SetAttribute("Alive", false)
	player:SetAttribute("LastOut", reason)
	local r = root(player)
	if r then
		Vfx.burst("poof", r.Position, Color3.fromRGB(255, 90, 90))
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = Arena.standsPoint(rng)
	end
end

function Roster.startRound()
	for _, p in PlayersService:GetPlayers() do
		p:SetAttribute("Alive", true)
		local r = root(p)
		if r then
			r.CFrame = CFrame.new(Arena.randomFloorPoint(rng))
		end
	end
end

-- Смерть = вылет. Респавн выбывших — на трибуны.
local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Connect(function()
		Roster.eliminate(player, "died")
	end)
	task.defer(function()
		local r = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		if r then
			r.CFrame = if Roster.isAlive(player)
				then CFrame.new(Arena.randomFloorPoint(rng))
				else Arena.standsPoint(rng)
		end
	end)
end

function Roster.init()
	local function onPlayer(p: Player)
		p:SetAttribute("Alive", false) -- зашёл посреди раунда — ждёт на трибунах
		p:SetAttribute("Wins", 0)
		p.CharacterAdded:Connect(function(c)
			onCharacter(p, c)
		end)
		if p.Character then
			onCharacter(p, p.Character)
		end
	end
	PlayersService.PlayerAdded:Connect(onPlayer)
	for _, p in PlayersService:GetPlayers() do
		onPlayer(p)
	end
end

return Roster
