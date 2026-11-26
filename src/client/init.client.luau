-- Клиент: HUD (приказ ведущего, таймер, живые), озвучка через TTS и поле ввода слова для победителя.
-- Клиент ничего не решает — только показывает State/Announce и отправляет слово.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local Voice = require(script.Voice)

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

Remotes.State.OnClientEvent:Connect(function(s)
	local fmt = PHASE[s.phase] or ""
	local alive = player:GetAttribute("Alive")
	local me = if alive then "ты в игре" else "ты на трибунах"
	if s.goal == "collect" and alive then
		me = `звёзды {player:GetAttribute("Collected") or 0}/{Config.CollectTarget}`
	elseif s.goal == "push" and alive then
		me = if player:GetAttribute("Pushed") then "столкнул ✓" else "толкай: E"
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
