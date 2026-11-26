-- Покупки за Robux. ID товаров — Config.Shop (0 — товар не создан, кнопки нет).
--   Word      — своё слово в следующий раунд (WordService.addPaid)
--   ExtraLife — один вылет не считается (атрибут ExtraLives, тратит Roster.eliminate)
--   Shield    — охота на лидера тебя не выберет (атрибут Shields, тратит Twists.leader)
--   VipPass   — геймпасс: атрибут VIP — монеты ×2, золотое имя, среди выживших слово даёт VIP
-- ProcessReceipt: сначала записываем чек в данные игрока (Data.recordReceipt), потом выдаём — повтор того же чека
-- от Roblox ничего не выдаст второй раз.

local MarketplaceService = game:GetService("MarketplaceService")
local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.Data)
local WordService = require(script.Parent.WordService)

local Shop = {}

local function add(p: Player, attr: string)
	p:SetAttribute(attr, (p:GetAttribute(attr) or 0) + 1)
end

local GRANT: { [number]: (Player) -> () } = {
	[Config.Shop.Word] = WordService.addPaid,
	[Config.Shop.ExtraLife] = function(p)
		add(p, "ExtraLives")
	end,
	[Config.Shop.Shield] = function(p)
		add(p, "Shields")
	end,
}

local function processReceipt(info): Enum.ProductPurchaseDecision
	local p = PlayersService:GetPlayerByUserId(info.PlayerId)
	local grant = GRANT[info.ProductId]
	if not p or not grant then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- вышел или неизвестный товар: Roblox повторит позже
	end
	if Data.hasReceipt(p, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- уже выдано
	end
	-- Без загруженных данных чек не запомнить; в Studio покупки тестовые — выдаём без записи.
	if not Data.recordReceipt(p, info.PurchaseId) and not RunService:IsStudio() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grant(p)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function golden(p: Player, char: Model)
	local head = char:WaitForChild("Head", 5)
	if not head then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "VipTag"
	tag.Size = UDim2.fromOffset(160, 30)
	tag.StudsOffset = Vector3.new(0, 2.5, 0)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 210, 60)
	label.TextStrokeTransparency = 0
	label.Text = `👑 {p.DisplayName}`
	label.Parent = tag
	tag.Parent = head
end

local function setVip(p: Player)
	if p:GetAttribute("VIP") then
		return
	end
	p:SetAttribute("VIP", true)
	if p.Character then
		task.spawn(golden, p, p.Character)
	end
	p.CharacterAdded:Connect(function(char)
		golden(p, char)
	end)
end

local function checkVip(p: Player)
	if Config.Shop.VipPass == 0 then
		return
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, p.UserId, Config.Shop.VipPass)
	if ok and owns then
		setVip(p)
	end
end

function Shop.init()
	MarketplaceService.ProcessReceipt = processReceipt
	PlayersService.PlayerAdded:Connect(checkVip)
	for _, p in PlayersService:GetPlayers() do
		task.spawn(checkVip, p)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p, passId, bought)
		if bought and passId == Config.Shop.VipPass then
			setVip(p)
		end
	end)
end

return Shop
