-- Косметика за монеты: следы за персонажем. Купленные id — атрибут Trails ("ice,fire"), надетый — Trail; сохраняет Data.
-- Клиент шлёт только id (Remotes.BuyTrail); цену, монеты и что куплено проверяет сервер (RoundLogic.buyTrail).

local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RoundLogic = require(ReplicatedStorage.Shared.RoundLogic)
local Remotes = require(script.Parent.Remotes)

local Cosmetics = {}

local function find(id: string?)
	for _, t in Config.Trails do
		if t.id == id then
			return t
		end
	end
	return nil
end

local PARTS = { "TrailTop", "TrailBottom", "CosmeticTrail" }

local function apply(p: Player)
	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, name in PARTS do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local item = find(p:GetAttribute("Trail"))
	if not item then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 0.8, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -0.8, 0)
	bottom.Parent = root
	local keys = {}
	for i, c in item.colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#item.colors - 1), c))
	end
	local trail = Instance.new("Trail")
	trail.Name = "CosmeticTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(keys)
	trail.Lifetime = 0.5
	trail.LightEmission = 0.7
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Parent = root
end

local function watch(p: Player)
	p.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 5)
		apply(p)
	end)
	p:GetAttributeChangedSignal("Trail"):Connect(function()
		apply(p)
	end)
	task.spawn(apply, p)
end

function Cosmetics.init()
	PlayersService.PlayerAdded:Connect(watch)
	for _, p in PlayersService:GetPlayers() do
		watch(p)
	end
	Remotes.BuyTrail.OnServerEvent:Connect(function(p: Player, id: unknown)
		local item = find(if type(id) == "string" then id else nil)
		if not item then
			return
		end
		local owned, equipped, coins = RoundLogic.buyTrail(
			p:GetAttribute("Trails") or "",
			p:GetAttribute("Trail"),
			p:GetAttribute("Coins") or 0,
			item.id,
			item.price
		)
		if owned then
			p:SetAttribute("Coins", coins)
			p:SetAttribute("Trails", owned)
			p:SetAttribute("Trail", equipped)
		end
	end)
end

return Cosmetics
