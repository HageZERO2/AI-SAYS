-- Клиент: HUD (приказ ведущего, таймер, живые, монеты), озвучка через TTS, окно слова для победителя,
-- магазин за Robux и косметика за монеты. Клиент ничего не решает — только показывает State/Announce
-- и отправляет запросы. Вид — client/Ui (эталонный экран 1280×720, стопка глубины, одна обводка).

local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local Ui = require(script.Ui)
local Voice = require(script.Voice)
local Vfx = require(script.Vfx)
local C = Ui.C

local ROBUX = utf8.char(0xE002) -- значок Robux в шрифтах Roblox

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui") -- сначала в PlayerGui: холст меряет AbsoluteSize
local canvas = Ui.canvas(gui)

-- Приказ ведущего: золотая плашка — «ИИ говорит» (выполнять), фиолетовая — всё остальное (ловушки, итоги).
local commandWrap, commandFace = Ui.panel(canvas, {
	name = "Command",
	size = UDim2.fromOffset(900, 96),
	pos = UDim2.new(0.5, 0, 0, 8),
	anchor = Vector2.new(0.5, 0),
	color = C.panel,
	radius = 22,
})
commandWrap.Visible = false
local command = Ui.text(commandFace, {
	name = "Text",
	size = UDim2.new(1, -40, 1, -14),
	pos = UDim2.fromScale(0.5, 0.5),
	anchor = Vector2.new(0.5, 0.5),
	scaled = true,
	textSize = 44,
	stroke = 4,
})

-- Чипы под приказом: фаза и таймер, живые, раунд, серия.
local chips = Instance.new("Frame")
chips.Name = "Chips"
chips.BackgroundTransparency = 1
chips.Size = UDim2.fromOffset(900, 56)
chips.Position = UDim2.new(0.5, 0, 0, 122)
chips.AnchorPoint = Vector2.new(0.5, 0)
local chipList = Instance.new("UIListLayout")
chipList.FillDirection = Enum.FillDirection.Horizontal
chipList.HorizontalAlignment = Enum.HorizontalAlignment.Center
chipList.SortOrder = Enum.SortOrder.LayoutOrder
chipList.Padding = UDim.new(0, 12)
chipList.Parent = chips
chips.Parent = canvas
local function chip(name: string, width: number, color: Color3, order: number): TextLabel
	local _, face = Ui.panel(chips, {
		name = name,
		size = UDim2.fromOffset(width, 46),
		color = color,
		order = order,
		radius = 23,
	})
	return Ui.text(
		face,
		{ size = UDim2.new(1, -20, 1, -6), pos = UDim2.fromOffset(10, 3), scaled = true, textSize = 28 }
	)
end
local timerChip = chip("Timer", 380, C.panel, 1)
local aliveChip = chip("Alive", 120, C.blue, 2)
local roundChip = chip("Round", 150, C.panelAlt, 3)
local streakChip = chip("Streak", 120, C.red, 4)

-- Строка «что со мной»: прогресс цели, жизни, щиты, подвох. И кто купил голос ведущего.
local function pill(name: string, y: number, color: Color3): TextLabel
	local l = Ui.text(canvas, {
		name = name,
		size = UDim2.fromOffset(0, 36),
		pos = UDim2.new(0.5, 0, 0, y),
		anchor = Vector2.new(0.5, 0),
		textSize = 24,
		color = color,
	})
	l.AutomaticSize = Enum.AutomaticSize.X
	l.BackgroundColor3 = C.outline
	l.BackgroundTransparency = 0.35
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = l
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = l
	l.Visible = false
	return l
end
local status = pill("Status", 190, C.onDark)
local voiceBy = pill("VoiceBy", 232, C.gold)

-- Монеты и победы: внизу по центру (слева вверху — чат, справа внизу — прыжок на телефоне).
local wallet = Instance.new("Frame")
wallet.Name = "Wallet"
wallet.BackgroundTransparency = 1
wallet.Size = UDim2.fromOffset(400, 64)
wallet.Position = UDim2.new(0.5, 0, 1, -16)
wallet.AnchorPoint = Vector2.new(0.5, 1)
local walletList = Instance.new("UIListLayout")
walletList.FillDirection = Enum.FillDirection.Horizontal
walletList.HorizontalAlignment = Enum.HorizontalAlignment.Center
walletList.Padding = UDim.new(0, 14)
walletList.SortOrder = Enum.SortOrder.LayoutOrder
walletList.Parent = wallet
wallet.Parent = canvas
local coinsWrap, coinsFace =
	Ui.panel(wallet, { name = "Coins", size = UDim2.fromOffset(190, 56), color = C.panel, radius = 28 })
Ui.coin(coinsFace, 40, UDim2.new(0, 10, 0.5, 0))
local coinsText = Ui.text(coinsFace, {
	size = UDim2.new(1, -66, 1, 0),
	pos = UDim2.fromOffset(58, 0),
	textSize = 32,
	align = Enum.TextXAlignment.Left,
})
local _, winsFace =
	Ui.panel(wallet, { name = "Wins", size = UDim2.fromOffset(150, 56), color = C.panel, radius = 28, order = 1 })
local winsText = Ui.text(winsFace, { size = UDim2.new(1, -20, 1, 0), pos = UDim2.fromOffset(10, 0), textSize = 30 })

local lastCoins = player:GetAttribute("Coins") or 0
local function refreshWallet()
	local coins = player:GetAttribute("Coins") or 0
	coinsText.Text = tostring(coins)
	winsText.Text = `🏆 {player:GetAttribute("Wins") or 0}`
	if coins > lastCoins then
		Ui.pop(coinsWrap, 1.25)
		local plus = Ui.text(canvas, {
			text = `+{coins - lastCoins}`,
			size = UDim2.fromOffset(160, 44),
			pos = UDim2.new(0.5, -82, 1, -90),
			anchor = Vector2.new(0.5, 1),
			textSize = 36,
			color = C.gold,
		})
		local t = TweenService:Create(plus, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0.5, -82, 1, -160),
			TextTransparency = 1,
		})
		t:Play()
		t.Completed:Connect(function()
			plus:Destroy()
		end)
	end
	lastCoins = coins
end
player:GetAttributeChangedSignal("Coins"):Connect(refreshWallet)
player:GetAttributeChangedSignal("Wins"):Connect(refreshWallet)
refreshWallet()

-- Окна (магазин, косметика): по центру, одно открыто за раз, крестик в углу. ------------------
local modals: { GuiObject } = {}
local function modal(name: string, title: string, w: number, h: number): (Frame, Frame)
	local wrap, face = Ui.panel(canvas, {
		name = name,
		size = UDim2.fromOffset(w, h),
		pos = UDim2.new(0.5, 0, 0.5, 34), -- ниже плашки приказа
		anchor = Vector2.new(0.5, 0.5),
		color = C.panel,
		radius = 24,
	})
	wrap.Visible = false
	Ui.text(face, {
		name = "Title",
		text = title,
		size = UDim2.new(1, -120, 0, 56),
		pos = UDim2.new(0.5, 0, 0, 10),
		anchor = Vector2.new(0.5, 0),
		scaled = true,
		textSize = 40,
		stroke = 4,
	})
	local close = Ui.button(face, {
		name = "Close",
		text = "X",
		size = UDim2.fromOffset(64, 64),
		pos = UDim2.new(1, 14, 0, -14),
		anchor = Vector2.new(1, 0),
		color = C.red,
		radius = 32,
	})
	close.Activated:Connect(function()
		wrap.Visible = false
	end)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(24, 76)
	body.Size = UDim2.new(1, -48, 1, -96)
	body.Parent = face
	table.insert(modals, wrap)
	return wrap, body
end
local function toggle(m: GuiObject)
	local open = not m.Visible
	for _, other in modals do
		other.Visible = false
	end
	m.Visible = open
	if open then
		Ui.pop(m, 0.9)
	end
end

-- Плитка: значок, название, подпись и кнопка внизу. Возвращает кнопку и её подпись.
local function tile(parent: Instance, order: number, color: Color3, icon: string, name: string, desc: string?)
	local _, face = Ui.panel(parent, { size = UDim2.fromOffset(170, 170), color = color, order = order })
	Ui.text(face, {
		text = icon,
		size = UDim2.new(1, 0, 0, 52),
		pos = UDim2.fromOffset(0, 8),
		textSize = 46,
		stroke = 0,
	})
	Ui.text(face, {
		text = name,
		size = UDim2.new(1, -16, 0, 30),
		pos = UDim2.new(0.5, 0, 0, 62),
		anchor = Vector2.new(0.5, 0),
		scaled = true,
		textSize = 26,
	})
	if desc then
		Ui.text(face, {
			text = desc,
			size = UDim2.new(1, -16, 0, 40),
			pos = UDim2.new(0.5, 0, 0, 92),
			anchor = Vector2.new(0.5, 0),
			scaled = true,
			textSize = 18,
			color = if color == C.gold then C.ink else C.soft,
			stroke = 0,
		})
	end
	return Ui.button(face, {
		size = UDim2.new(1, -20, 0, 48),
		pos = UDim2.new(0.5, 0, 1, -14),
		anchor = Vector2.new(0.5, 1),
		color = C.green,
		radius = 14,
		textSize = 28,
	})
end

-- Магазин за Robux: только созданные товары (Config.Shop ≠ 0). Цену берём у Roblox, а не из кода.
local shopModal, shopBody = modal("Shop", "Магазин", 820, 520)
local shopGrid = Instance.new("UIGridLayout")
shopGrid.CellSize = UDim2.fromOffset(236, 196)
shopGrid.CellPadding = UDim2.fromOffset(16, 22)
shopGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
shopGrid.SortOrder = Enum.SortOrder.LayoutOrder
shopGrid.Parent = shopBody
for i, item in
	{
		{
			Config.Shop.Word,
			"✍",
			"Моё слово",
			"твоё слово в следующем раунде",
			false,
		},
		{
			Config.Shop.ExtraLife,
			"❤",
			"Вторая жизнь",
			"один вылет не считается",
			false,
		},
		{ Config.Shop.Shield, "🛡", "Щит", "охотник тебя не выберет", false },
		{ Config.Shop.Voice, "🔊", "Голос ведущего", "новый голос на 15 минут", false },
		{ Config.Shop.VipPass, "👑", "VIP", "монеты ×2 и золотое имя", true },
	}
do
	local id, icon, name, desc, isPass = item[1], item[2], item[3], item[4], item[5]
	if id ~= 0 then
		local buy, price = tile(shopBody, i, if isPass then C.gold else C.tile, icon, name, desc)
		price.Text = `{ROBUX} …`
		task.spawn(function()
			local ok, info = pcall(
				MarketplaceService.GetProductInfo,
				MarketplaceService,
				id,
				if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product
			)
			if ok and info.PriceInRobux then
				price.Text = `{ROBUX} {info.PriceInRobux}`
			end
		end)
		buy.Activated:Connect(function()
			if isPass then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
	end
end

-- Косметика за монеты: следы и эмоция победителя. Цену, монеты и покупку проверяет сервер (Remotes.BuyCosmetic).
local cosmeticsModal, cosmeticsBody = modal("Cosmetics", "Косметика за монеты", 820, 550)
local cosmeticsList = Instance.new("UIListLayout")
cosmeticsList.SortOrder = Enum.SortOrder.LayoutOrder
cosmeticsList.Padding = UDim.new(0, 6)
cosmeticsList.Parent = cosmeticsBody
local refreshers: { () -> () } = {}
for section, kind in
	{
		{ kind = "Trail", owned = "Trails", list = Config.Trails, title = "✨ Следы за тобой" },
		{ kind = "Emote", owned = "Emotes", list = Config.Emotes, title = "🎉 Эмоция, когда выжил" },
	}
do
	Ui.text(cosmeticsBody, {
		text = kind.title,
		size = UDim2.new(1, 0, 0, 34),
		textSize = 28,
		align = Enum.TextXAlignment.Left,
		order = section * 2,
	})
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 186)
	row.LayoutOrder = section * 2 + 1
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowList.Padding = UDim.new(0, 18)
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Parent = row
	row.Parent = cosmeticsBody
	local buttons: { [string]: { wrap: TextButton, label: TextLabel } } = {}
	for i, t in kind.list do
		local wrap, label = tile(row, i, C.tile, t.icon or "", t.name)
		if t.colors then -- след: полоса с его цветами вместо значка
			local face = wrap.Parent :: Frame
			local swatch = Instance.new("Frame")
			swatch.Size = UDim2.new(1, -36, 0, 30)
			swatch.Position = UDim2.new(0.5, 0, 0, 20)
			swatch.AnchorPoint = Vector2.new(0.5, 0)
			swatch.BackgroundColor3 = Color3.new(1, 1, 1)
			local keys = {}
			for k, c in t.colors do
				table.insert(keys, ColorSequenceKeypoint.new((k - 1) / (#t.colors - 1), c))
			end
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(keys)
			g.Parent = swatch
			local sc = Instance.new("UICorner")
			sc.CornerRadius = UDim.new(0.5, 0)
			sc.Parent = swatch
			local ss = Instance.new("UIStroke")
			ss.Thickness = 3
			ss.Color = C.outline
			ss.Parent = swatch
			swatch.Parent = face
		end
		wrap.Activated:Connect(function()
			Remotes.BuyCosmetic:FireServer(kind.kind, t.id)
		end)
		buttons[t.id] = { wrap = wrap, label = label }
	end
	table.insert(refreshers, function()
		local owned = string.split(player:GetAttribute(kind.owned) or "", ",")
		local coins = player:GetAttribute("Coins") or 0
		for _, t in kind.list do
			local b = buttons[t.id]
			local has = table.find(owned, t.id) ~= nil
			if player:GetAttribute(kind.kind) == t.id then
				b.label.Text = "✓ Снять"
				Ui.recolor(b.wrap, C.gold)
			elseif has then
				b.label.Text = "Надеть"
				Ui.recolor(b.wrap, C.blue)
			else
				b.label.Text = `{t.price} монет`
				Ui.recolor(b.wrap, if coins >= t.price then C.green else C.grey)
			end
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

-- Кнопки открытия: справа посередине (выше зоны прыжка на телефоне).
local menu = Instance.new("Frame")
menu.Name = "Menu"
menu.BackgroundTransparency = 1
menu.Size = UDim2.fromOffset(200, 190)
menu.Position = UDim2.new(1, -16, 0.45, 0)
menu.AnchorPoint = Vector2.new(1, 0.5)
local menuList = Instance.new("UIListLayout")
menuList.Padding = UDim.new(0, 18)
menuList.SortOrder = Enum.SortOrder.LayoutOrder
menuList.Parent = menu
menu.Parent = canvas
local shopButton =
	Ui.button(menu, { text = "🛒 Магазин", size = UDim2.fromOffset(200, 80), color = C.green, radius = 20 })
shopButton.Activated:Connect(function()
	toggle(shopModal)
end)
local cosmeticsButton = Ui.button(menu, {
	text = "✨ Косметика",
	size = UDim2.fromOffset(200, 80),
	color = C.panelAlt,
	radius = 20,
	order = 1,
})
cosmeticsButton.Activated:Connect(function()
	toggle(cosmeticsModal)
end)

-- Слово победителя: окно с полем и кнопкой (на телефоне Enter нет).
local wordModal, wordFace = Ui.panel(canvas, {
	name = "Word",
	size = UDim2.fromOffset(700, 280),
	pos = UDim2.fromScale(0.5, 0.55),
	anchor = Vector2.new(0.5, 0.5),
	color = C.panel,
	radius = 24,
})
wordModal.Visible = false
local wordTitle = Ui.text(wordFace, {
	text = "🏆 Ты выжил! Дай ИИ слово",
	size = UDim2.new(1, -40, 0, 50),
	pos = UDim2.new(0.5, 0, 0, 16),
	anchor = Vector2.new(0.5, 0),
	scaled = true,
	textSize = 40,
	stroke = 4,
})
local _, boxFace = Ui.panel(wordFace, {
	size = UDim2.new(1, -60, 0, 80),
	pos = UDim2.new(0.5, 0, 0, 82),
	anchor = Vector2.new(0.5, 0),
	color = C.cream,
	radius = 18,
})
local wordBox = Instance.new("TextBox")
wordBox.Name = "WordBox"
wordBox.Size = UDim2.new(1, -30, 1, -10)
wordBox.Position = UDim2.fromScale(0.5, 0.5)
wordBox.AnchorPoint = Vector2.new(0.5, 0.5)
wordBox.BackgroundTransparency = 1
wordBox.Font = Ui.FONT
wordBox.TextSize = 36
wordBox.TextColor3 = C.ink
wordBox.PlaceholderColor3 = C.inkSoft
wordBox.PlaceholderText = "акулы, бабушка, желе…"
wordBox.Text = ""
wordBox.ClearTextOnFocus = false
wordBox.Parent = boxFace
local sendButton = Ui.button(wordFace, {
	text = "Отправить",
	size = UDim2.fromOffset(260, 70),
	pos = UDim2.new(0.5, 0, 1, -24),
	anchor = Vector2.new(0.5, 1),
	color = C.green,
	radius = 18,
})

-- События ----------------------------------------------------------
local wantVoice = false
Remotes.Announce.OnClientEvent:Connect(function(text: string, isAISays: boolean, voice: string?)
	command.Text = text
	commandWrap.Visible = text ~= ""
	Ui.recolor(commandWrap, if isAISays then C.gold else C.panel)
	command.TextColor3 = if isAISays then C.ink else C.onDark
	local stroke = command:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Enabled = not isAISays
	end
	Ui.pop(commandWrap)
	if voice then
		Voice.say(voice)
	end
end)

workspace:GetAttributeChangedSignal("HostVoiceBy"):Connect(function()
	local by = workspace:GetAttribute("HostVoiceBy")
	voiceBy.Text = if by then `🔊 голос ведущего выбрал {by}` else ""
	voiceBy.Visible = by ~= nil
	if by and wantVoice then
		Voice.say("Ahem. Do you like my new voice?")
	end
end)
if workspace:GetAttribute("HostVoiceBy") then
	voiceBy.Text = `🔊 голос ведущего выбрал {workspace:GetAttribute("HostVoiceBy")}`
	voiceBy.Visible = true
end
wantVoice = true

local PHASE = {
	waiting = "Ждём игроков…",
	intermission = "Раунд через %d",
	thinking = "ИИ придумывает раунд…",
	trap = "%d",
	round = "⏱ %d сек",
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
		me = `⭐ {player:GetAttribute("Collected") or 0}/{Config.CollectTarget}`
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
	timerChip.Text = string.format(fmt, s.timeLeft)
	aliveChip.Text = `👥 {s.alive}`
	roundChip.Text = `Раунд {s.round}`
	streakChip.Text = `🔥 {s.streak}`
	status.Text = me
	status.Visible = true
end)

local wordToken = 0
local function submitWord()
	if wordBox.Text ~= "" then
		Remotes.SubmitWord:FireServer(wordBox.Text)
		wordModal.Visible = false
	end
end
Remotes.AskWord.OnClientEvent:Connect(function(seconds: number)
	wordToken += 1
	local token = wordToken
	wordBox.Text = ""
	wordModal.Visible = true
	Ui.pop(wordModal, 0.8)
	wordBox:CaptureFocus()
	task.spawn(function()
		for left = seconds, 1, -1 do
			if wordToken ~= token or not wordModal.Visible then
				return
			end
			wordTitle.Text = `🏆 Ты выжил! Дай ИИ слово · {left}`
			task.wait(1)
		end
		if wordToken == token then
			wordModal.Visible = false
		end
	end)
end)
wordBox.FocusLost:Connect(function(enter)
	if enter then
		submitWord()
	end
end)
sendButton.Activated:Connect(submitWord)

Remotes.Vfx.OnClientEvent:Connect(Vfx.play)
