-- Кит интерфейса: тема и «стопка глубины» — тень ниже лица (темнее и чуть к синему), лицо с градиентом
-- (светлее сверху, Rotation -90), одна толщина обводки на весь экран, текст с обводкой Bevel.
-- Числа — из навыка roblox-ui (references/ui-recipes.md). Всё в пикселях эталонного экрана 1280×720:
-- Ui.canvas подгоняет его под реальный экран одним UIScale, края экрана остаются краями.

local TweenService = game:GetService("TweenService")

local Ui = {}

Ui.C = {
	panel = Color3.fromRGB(58, 40, 112),
	panelAlt = Color3.fromRGB(82, 60, 150),
	tile = Color3.fromRGB(96, 74, 170),
	gold = Color3.fromRGB(247, 188, 46),
	green = Color3.fromRGB(89, 201, 60),
	red = Color3.fromRGB(236, 90, 76),
	blue = Color3.fromRGB(76, 166, 232),
	grey = Color3.fromRGB(150, 150, 170),
	cream = Color3.fromRGB(255, 248, 233),
	ink = Color3.fromRGB(42, 31, 69),
	inkSoft = Color3.fromRGB(122, 100, 64),
	onDark = Color3.new(1, 1, 1),
	soft = Color3.fromRGB(215, 205, 255),
	outline = Color3.fromRGB(26, 20, 48),
}
Ui.STROKE = 5 -- одна толщина на всё: разная толщина обводок — главный признак «самодельного» интерфейса
Ui.SHADOW = 7
Ui.FONT = Enum.Font.FredokaOne
Ui.REF = Vector2.new(1280, 720)

local function shade(c: Color3): Color3
	local h, s, v = c:ToHSV()
	h = (h + math.clamp(0.66 - h, -0.06, 0.06)) % 1
	return Color3.fromHSV(h, math.min(1, s * 1.05), v * 0.55)
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function outline(parent: Instance, thickness: number)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = Ui.C.outline
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

export type BoxOpts = {
	size: UDim2,
	color: Color3,
	pos: UDim2?,
	anchor: Vector2?,
	name: string?,
	order: number?,
	radius: number?,
	text: string?,
	textSize: number?,
	textColor: Color3?,
}

-- Обёртка (прозрачная, единственный элемент для раскладки) + Shadow + Face. Детей кладём в Face.
local function stack(wrapper: GuiObject, o: BoxOpts): Frame
	wrapper.Size = o.size
	wrapper.Position = o.pos or UDim2.new()
	wrapper.AnchorPoint = o.anchor or Vector2.zero
	wrapper.BackgroundTransparency = 1
	wrapper.LayoutOrder = o.order or 0
	if o.name then
		wrapper.Name = o.name
	end
	local radius = o.radius or 16
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromOffset(0, Ui.SHADOW)
	shadow.BorderSizePixel = 0
	corner(shadow, radius)
	outline(shadow, Ui.STROKE)
	shadow.Parent = wrapper
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	corner(face, radius)
	outline(face, Ui.STROKE)
	local g = Instance.new("UIGradient")
	g.Rotation = -90
	g.Parent = face
	face.Parent = wrapper
	Ui.recolor(wrapper, o.color)
	return face
end

function Ui.recolor(wrapper: Instance, color: Color3)
	local shadow = wrapper:FindFirstChild("Shadow") :: Frame
	local face = wrapper:FindFirstChild("Face") :: Frame
	shadow.BackgroundColor3 = shade(color)
	local g = face:FindFirstChildOfClass("UIGradient") :: UIGradient
	g.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.22))
end

export type TextOpts = {
	text: string?,
	size: UDim2?,
	pos: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	textSize: number?,
	scaled: boolean?,
	stroke: number?,
	align: Enum.TextXAlignment?,
	name: string?,
	order: number?,
}

-- Текст: scaled — сжимается под рамку, но не больше textSize (UITextSizeConstraint), иначе фиксированный размер.
-- stroke: 3–4 для светлого текста на тёмном, 0 — для тёмного текста на светлом.
function Ui.text(parent: Instance, o: TextOpts): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Ui.FONT
	l.Text = o.text or ""
	l.TextColor3 = o.color or Ui.C.onDark
	l.Size = o.size or UDim2.fromScale(1, 1)
	l.Position = o.pos or UDim2.new()
	l.AnchorPoint = o.anchor or Vector2.zero
	l.TextXAlignment = o.align or Enum.TextXAlignment.Center
	l.LayoutOrder = o.order or 0
	if o.name then
		l.Name = o.name
	end
	if o.scaled then
		l.TextScaled = true
		l.TextWrapped = true
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = o.textSize or 40
		c.MinTextSize = 12
		c.Parent = l
	else
		l.TextSize = o.textSize or 28
	end
	local stroke = o.stroke or 3
	if stroke > 0 then
		local s = Instance.new("UIStroke")
		s.Thickness = stroke
		s.Color = Ui.C.outline
		s.LineJoinMode = Enum.LineJoinMode.Bevel
		s.Parent = l
	end
	l.Parent = parent
	return l
end

function Ui.panel(parent: Instance, o: BoxOpts): (Frame, Frame)
	local wrapper = Instance.new("Frame")
	local face = stack(wrapper, o)
	wrapper.Parent = parent
	return wrapper, face
end

-- Кнопка: вся обёртка нажимается; при нажатии лицо проседает к тени, при наведении кнопка чуть растёт.
function Ui.button(parent: Instance, o: BoxOpts): (TextButton, TextLabel)
	local wrapper = Instance.new("TextButton")
	wrapper.Text = ""
	wrapper.AutoButtonColor = false
	local face = stack(wrapper, o)
	local label = Ui.text(face, {
		name = "Label",
		text = o.text,
		size = UDim2.new(1, -16, 1, -8),
		pos = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		scaled = true,
		textSize = o.textSize or 30,
		color = o.textColor,
		stroke = if o.textColor == Ui.C.ink then 0 else 3,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = wrapper
	local function tween(s: number)
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = s }):Play()
	end
	local function up()
		face.Position = UDim2.new()
	end
	wrapper.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, Ui.SHADOW - 2)
	end)
	wrapper.MouseButton1Up:Connect(up)
	wrapper.MouseEnter:Connect(function()
		tween(1.05)
	end)
	wrapper.MouseLeave:Connect(function()
		up()
		tween(1)
	end)
	wrapper.Parent = parent
	return wrapper, label
end

-- Монета: золотой круг с тёмным внутренним кольцом (эмодзи 🪙 шрифт Roblox не рисует).
function Ui.coin(parent: Instance, size: number, pos: UDim2?): Frame
	local c = Instance.new("Frame")
	c.Name = "Coin"
	c.Size = UDim2.fromOffset(size, size)
	c.Position = pos or UDim2.new()
	c.AnchorPoint = Vector2.new(0, 0.5)
	c.BackgroundColor3 = Color3.new(1, 1, 1)
	corner(c, size)
	outline(c, 3)
	local g = Instance.new("UIGradient")
	g.Rotation = -90
	g.Color = ColorSequence.new(Color3.fromRGB(230, 150, 20), Color3.fromRGB(255, 225, 90))
	g.Parent = c
	local inner = Instance.new("Frame")
	inner.Size = UDim2.fromScale(0.58, 0.58)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.BackgroundTransparency = 1
	corner(inner, size)
	local ring = Instance.new("UIStroke")
	ring.Thickness = 3
	ring.Color = Color3.fromRGB(190, 110, 10)
	ring.Parent = inner
	inner.Parent = c
	c.Parent = parent
	return c
end

-- Эталонный холст на весь экран: размер = экран / масштаб, UIScale = min(ширина/1280, высота/720).
function Ui.canvas(gui: ScreenGui): Frame
	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	local scale = Instance.new("UIScale")
	scale.Parent = canvas
	local function fit()
		local v = gui.AbsoluteSize
		if v.X < 1 or v.Y < 1 then
			return
		end
		local s = math.min(v.X / Ui.REF.X, v.Y / Ui.REF.Y)
		scale.Scale = s
		canvas.Size = UDim2.fromOffset(v.X / s, v.Y / s)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	canvas.Parent = gui
	fit()
	return canvas
end

-- Короткий «пульс» элемента (новый приказ, новые монеты).
function Ui.pop(obj: GuiObject, from: number?)
	local scale = obj:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = obj
	scale.Scale = from or 1.15
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

return Ui
