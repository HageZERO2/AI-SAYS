-- Косметика за монеты: следы за персонажем и эмоция победителя (играет у выживших в конце раунда).
-- Купленные id — атрибут Trails/Emotes ("ice,fire"), надетый — Trail/Emote; сохраняет Data.
-- Клиент шлёт только (вид, id) через Remotes.BuyCosmetic; цену, монеты и что куплено проверяет сервер (RoundLogic.buyItem).

local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RoundLogic = require(ReplicatedStorage.Shared.RoundLogic)
local Remotes = require(script.Parent.Remotes)

local Cosmetics = {}

-- вид → список в Config и атрибут купленных; атрибут надетого = имя вида
local KINDS = {
	Trail = { list = Config.Trails, owned = "Trails" },
	Emote = { list = Config.Emotes, owned = "Emotes" },
}

local function find(list: { any }, id: unknown)
	for _, t in list do
		if t.id == id then
			return t
		end
	end
	return nil
end

local PARTS = { "TrailTop", "TrailBottom", "CosmeticTrail" }

local function applyTrail(p: Player)
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
	local item = find(Config.Trails, p:GetAttribute("Trail"))
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

-- Эмоция победителя: надетая анимация на 4 с (танцы зациклены — останавливаем сами).
function Cosmetics.celebrate(p: Player)
	local item = find(Config.Emotes, p:GetAttribute("Emote"))
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not item or not animator then
		return
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = item.anim
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	if not ok then
		return
	end
	track.Priority = Enum.AnimationPriority.Action
	track:Play()
	task.delay(4, function()
		track:Stop()
	end)
end

local function watch(p: Player)
	p.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 5)
		applyTrail(p)
	end)
	p:GetAttributeChangedSignal("Trail"):Connect(function()
		applyTrail(p)
	end)
	task.spawn(applyTrail, p)
end

function Cosmetics.init()
	PlayersService.PlayerAdded:Connect(watch)
	for _, p in PlayersService:GetPlayers() do
		watch(p)
	end
	Remotes.BuyCosmetic.OnServerEvent:Connect(function(p: Player, kind: unknown, id: unknown)
		local k = if type(kind) == "string" then (KINDS :: any)[kind] else nil
		local item = k and find(k.list, id)
		if not item then
			return
		end
		local owned, equipped, coins = RoundLogic.buyItem(
			p:GetAttribute(k.owned) or "",
			p:GetAttribute(kind :: string),
			p:GetAttribute("Coins") or 0,
			item.id,
			item.price
		)
		if owned then
			p:SetAttribute("Coins", coins)
			p:SetAttribute(k.owned, owned)
			p:SetAttribute(kind :: string, equipped)
		end
	end)
end

return Cosmetics
