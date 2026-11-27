-- Клиент: HUD (приказ ведущего, таймер, живые), озвучка через TTS и поле ввода слова для победителя.
-- Клиент ничего не решает — только показывает State/Announce и отправляет слово.

local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local Voice = require(script.Voice)
local Vfx = require(script.Vfx)

-- UI ---------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.TextScaled = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = gui
	return l
end

local command = label({
	Name = "Command",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.06),
	Size = UDim2.fromScale(0.8, 0.12),
	Text = "",
})
local info = label({
	Name = "Info",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.19),
	Size = UDim2.fromScale(0.5, 0.05),
	TextColor3 = Color3.fromRGB(220, 220, 255),
	Text = "",
})

local wordBox = Instance.new("TextBox")
wordBox.Name = "WordBox"
wordBox.AnchorPoint = Vector2.new(0.5, 0.5)
wordBox.Position = UDim2.fromScale(0.5, 0.6)
wordBox.Size = UDim2.fromScale(0.4, 0.08)
wordBox.PlaceholderText = "Твоё слово для ИИ (акулы, бабушка...)"
wordBox.Text = ""
wordBox.TextScaled = true
wordBox.Font = Enum.Font.FredokaOne
wordBox.ClearTextOnFocus = false
wordBox.Visible = false
Instance.new("UICorner").Parent = wordBox
wordBox.Parent = gui

-- Магазин: кнопки только для созданных товаров (Config.Shop ≠ 0). Цену показывает окно покупки Roblox.
local shop = Instance.new("Frame")
shop.Name = "Shop"
shop.AnchorPoint = Vector2.new(1, 1)
shop.Position = UDim2.new(1, -12, 1, -12)
shop.Size = UDim2.fromOffset(170, 0)
shop.AutomaticSize = Enum.AutomaticSize.Y
shop.BackgroundTransparency = 1
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.Parent = shop
local function button(text: string, gold: boolean, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(170, 38)
	b.BackgroundColor3 = if gold then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(40, 40, 60)
	b.BackgroundTransparency = 0.15
	b.TextColor3 = if gold then Color3.fromRGB(40, 30, 0) else Color3.new(1, 1, 1)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Text = text
	Instance.new("UICorner").Parent = b
	b.Parent = parent
	return b
end
for _, item in
	{
		{ Config.Shop.Word, "✍ Моё слово", false },
		{ Config.Shop.ExtraLife, "❤ Вторая жизнь", false },
		{ Config.Shop.Shield, "🛡 Щит от охотника", false },
		{ Config.Shop.Voice, "🔊 Голос ведущего", false },
		{ Config.Shop.VipPass, "👑 VIP", true },
	}
do
	local id, text, isPass = item[1], item[2], item[3]
	if id ~= 0 then
		button(text, isPass, shop).Activated:Connect(function()
			if isPass then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
	end
end

-- Косметика за монеты: кнопка открывает список следов и эмоций победителя.
-- Цену, монеты и покупку проверяет сервер (Remotes.BuyCosmetic).
local cosmetics = Instance.new("Frame")
cosmetics.Name = "Cosmetics"
cosmetics.AnchorPoint = Vector2.new(1, 1)
cosmetics.Position = UDim2.new(1, -190, 1, -12)
cosmetics.Size = UDim2.fromOffset(170, 0)
cosmetics.AutomaticSize = Enum.AutomaticSize.Y
cosmetics.BackgroundTransparency = 1
cosmetics.Visible = false
local cosmeticList = Instance.new("UIListLayout")
cosmeticList.Padding = UDim.new(0, 6)
cosmeticList.SortOrder = Enum.SortOrder.LayoutOrder
cosmeticList.Parent = cosmetics
local refreshers: { () -> () } = {}
for _, kind in
	{
		{ kind = "Trail", owned = "Trails", list = Config.Trails, title = "✨ Следы" },
		{ kind = "Emote", owned = "Emotes", list = Config.Emotes, title = "🎉 Эмоция победителя" },
	}
do
	local title = label({ Size = UDim2.fromOffset(170, 26), LayoutOrder = #cosmetics:GetChildren(), Text = kind.title })
	title.Parent = cosmetics
	local buttons: { [string]: TextButton } = {}
	for _, t in kind.list do
		local b = button("", false, cosmetics)
		b.LayoutOrder = #cosmetics:GetChildren()
		b.Activated:Connect(function()
			Remotes.BuyCosmetic:FireServer(kind.kind, t.id)
		end)
		buttons[t.id] = b
	end
	table.insert(refreshers, function()
		local owned = string.split(player:GetAttribute(kind.owned) or "", ",")
		local coins = player:GetAttribute("Coins") or 0
		for _, t in kind.list do
			local has = table.find(owned, t.id) ~= nil
			buttons[t.id].Text = if player:GetAttribute(kind.kind) == t.id
				then `{t.name} ✓ снять`
				elseif has then `{t.name}: надеть`
				else `{t.name}: {t.price} монет`
			buttons[t.id].BackgroundTransparency = if has or coins >= t.price then 0.15 else 0.6
		end
	end)
end
local function refreshCosmetics()
	for _, f in refreshers do
		f()
	end
end
for _, attr in { "Trails", "Trail", "Emotes", "Emote", "Coins" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshCosmetics)
end
refreshCosmetics()
cosmetics.Parent = gui
button("✨ Косметика за монеты", false, shop).Activated:Connect(function()
	cosmetics.Visible = not cosmetics.Visible
end)
shop.Parent = gui

-- Купленный голос ведущего: все видят, кто сменил, и слышат новый голос сразу.
local voiceBy = label({
	Name = "VoiceBy",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.245),
	Size = UDim2.fromScale(0.4, 0.035),
	TextColor3 = Color3.fromRGB(255, 210, 60),
	Text = "",
})
workspace:GetAttributeChangedSignal("HostVoiceBy"):Connect(function()
	local by = workspace:GetAttribute("HostVoiceBy")
	voiceBy.Text = if by then `🔊 голос ведущего выбрал {by}` else ""
	if by then
		Voice.say("Ahem. Do you like my new voice?")
	end
end)
if workspace:GetAttribute("HostVoiceBy") then
	voiceBy.Text = `🔊 голос ведущего выбрал {workspace:GetAttribute("HostVoiceBy")}`
end

gui.Parent = player:WaitForChild("PlayerGui")

-- События ----------------------------------------------------------
Remotes.Announce.OnClientEvent:Connect(function(text: string, isAISays: boolean, voice: string?)
	command.Text = text
	command.TextColor3 = if isAISays then Color3.fromRGB(255, 230, 80) else Color3.new(1, 1, 1)
	command.Size = UDim2.fromScale(0.9, 0.14)
	TweenService:Create(command, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.8, 0.12) })
		:Play()
	if voice then
		Voice.say(voice)
	end
end)

local PHASE = {
	waiting = "Ждём игроков…",
	intermission = "Следующий раунд через %d",
	thinking = "ИИ придумывает раунд…",
	trap = "%d",
	round = "%d сек",
	word = "Победитель выбирает слово… %d",
}

-- Толчок (цель push): E / кнопка геймпада / экранная кнопка на телефоне. Кого толкнуть, решает сервер.
local pushBound = false
local function setPush(on: boolean)
	if on == pushBound then
		return
	end
	pushBound = on
	if on then
		ContextActionService:BindAction("Push", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				Remotes.Push:FireServer()
			end
			return Enum.ContextActionResult.Sink
		end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle("Push", "Толк!")
	else
		ContextActionService:UnbindAction("Push")
	end
end

-- Подвох reverse: сервер ставит атрибут Reversed, а мы подменяем функцию, которой стандартный ControlModule
-- применяет движение. (Второй Humanoid:Move за кадр не годится: проверено — вызовы складываются в ноль.)
local controls: any = nil
local originalMove: any = nil
local function setReversed(on: boolean)
	if not controls then
		local ok, playerModule = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
		end)
		controls = ok and playerModule:GetControls()
		originalMove = controls and controls.moveFunction
	end
	if not controls or type(originalMove) ~= "function" then
		return
	end
	controls.moveFunction = if on
		then function(p: Player, vector: Vector3, cameraRelative: boolean)
			originalMove(p, -vector, cameraRelative)
		end
		else originalMove
end
player:GetAttributeChangedSignal("Reversed"):Connect(function()
	setReversed(player:GetAttribute("Reversed") == true)
end)

Remotes.State.OnClientEvent:Connect(function(s)
	local fmt = PHASE[s.phase] or ""
	local alive = player:GetAttribute("Alive")
	local me = if alive then "ты в игре" else "ты на трибунах"
	if s.goal == "collect" and alive then
		me = `звёзды {player:GetAttribute("Collected") or 0}/{Config.CollectTarget}`
	elseif s.goal == "push" and alive then
		me = if player:GetAttribute("Pushed") then "столкнул ✓" else "толкай: E"
	end
	if player:GetAttribute("Hunted") then
		me = "за тобой охотник!"
	end
	local lives, shields = player:GetAttribute("ExtraLives") or 0, player:GetAttribute("Shields") or 0
	if lives > 0 then
		me ..= ` · ❤×{lives}`
	end
	if shields > 0 then
		me ..= ` · 🛡×{shields}`
	end
	if s.twist and s.twist ~= "none" then
		me ..= ` · подвох: {Config.TwistNames[s.twist]}`
	end
	setPush(s.phase == "round" and s.goal == "push" and alive == true)
	info.Text =
		`{string.format(fmt, s.timeLeft)} · живы: {s.alive} · раунд {s.round} · серия {s.streak} · {me}`
end)

Remotes.AskWord.OnClientEvent:Connect(function(seconds: number)
	wordBox.Text = ""
	wordBox.Visible = true
	wordBox:CaptureFocus()
	task.delay(seconds, function()
		wordBox.Visible = false
	end)
end)

wordBox.FocusLost:Connect(function(enter)
	if enter and wordBox.Text ~= "" then
		Remotes.SubmitWord:FireServer(wordBox.Text)
		wordBox.Visible = false
	end
end)

Remotes.Vfx.OnClientEvent:Connect(Vfx.play)
