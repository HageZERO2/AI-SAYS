-- Короткие эффекты по событию Remotes.Vfx(kind, pos, color?) от сервера (server/Services/Vfx).
-- Всё создаётся только у этого клиента и удаляется само.
-- Правила (навык roblox-vfx): слои живут разное время — вспышка 1–4 кадра, искры, потом дым дольше всех;
-- пик в первой четверти жизни; LightEmission ≤ 0.6 — на светлых аренах (candy) единица выбеливает весь кадр;
-- ударная волна — плоское кольцо-флипбук, а не сплошной неоновый диск. Текстуры — Config.VfxTex.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local T = Config.VfxTex

local Vfx = {}

local WHITE = Color3.new(1, 1, 1)

-- Шаблоны грузим при входе: иначе первый эффект каждого вида рисуется пустым, пока текстура качается.
task.spawn(function()
	local warm = {}
	for _, id in T do
		local d = Instance.new("Decal")
		d.Texture = id
		table.insert(warm, d)
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, warm)
end)

local function anchor(pos: Vector3, life: number): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	Debris:AddItem(p, life)
	return p
end

local function emit(at: BasePart, count: number, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightInfluence = 0
	e.LightEmission = 0.5
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = at
	e:Emit(count)
end

-- Кривая «быстро вырос — медленно погас» вместо линейной.
local function burstSize(peak: number, start: number?): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, start or peak * 0.3),
		NumberSequenceKeypoint.new(0.25, peak),
		NumberSequenceKeypoint.new(1, peak * 1.1),
	})
end
local FADE_LATE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.6, 0.1),
	NumberSequenceKeypoint.new(1, 1),
})

-- Вспышка: одна звезда на 0.15 с (4–9 кадров), белая в центре, цветная к краю.
local function flash(at: BasePart, color: Color3, size: number)
	emit(at, 1, {
		Texture = T.flash,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
		FlipbookMode = Enum.ParticleFlipbookMode.Random,
		Color = ColorSequence.new(WHITE, color),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size * 0.4),
			NumberSequenceKeypoint.new(0.3, size),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.15),
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
		LightEmission = 0.6,
		ZOffset = 2,
	})
end

-- Ударная волна: плоское кольцо по полу (частица смотрит вдоль скорости вверх), расширяется и рассыпается.
local function ring(pos: Vector3, color: Color3, radius: number, time: number)
	local at = anchor(pos + Vector3.new(0, 0.3, 0), time + 0.2)
	emit(at, 1, {
		Texture = T.ring,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.zero,
		Speed = NumberRange.new(0.05),
		Color = ColorSequence.new(color),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.2),
			NumberSequenceKeypoint.new(0.35, radius * 0.8),
			NumberSequenceKeypoint.new(1, radius),
		}),
		Lifetime = NumberRange.new(time),
		LightEmission = 0.4,
	})
end

-- Искры-штрихи: летят от центра и быстро тормозят.
local function needles(at: BasePart, color: Color3, count: number, speed: number, spread: Vector2?)
	emit(at, count, {
		Texture = T.needle,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Color = ColorSequence.new(WHITE, color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.25, 0.55),
		Speed = NumberRange.new(speed * 0.6, speed),
		SpreadAngle = spread or Vector2.new(180, 180),
		Drag = 6,
		LightEmission = 0.6,
	})
end

-- Мультяшный дым: светлый (тёмный cel-дым читается как чёрные кляксы), живёт дольше всего остального.
local function smoke(at: BasePart, color: Color3, count: number, size: number, tex: string?)
	emit(at, count, {
		Texture = tex or T.smoke,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Color = ColorSequence.new(color:Lerp(WHITE, 0.55)),
		Size = burstSize(size),
		Transparency = FADE_LATE,
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		LightEmission = 0,
	})
end

local KINDS: { [string]: (pos: Vector3, color: Color3) -> () } = {
	-- Вылет: вспышка, искры, клуб дыма и кольцо по полу.
	poof = function(pos, color)
		local a = anchor(pos, 3)
		flash(a, color, 9)
		needles(a, color, 22, 40)
		smoke(a, color, 9, 5)
		ring(pos - Vector3.new(0, 2.8, 0), color, 12, 0.5)
	end,
	-- Предмет упал: пыль в стороны по полу, маленькое кольцо, пара искр.
	impact = function(pos, color)
		local a = anchor(pos, 2.5)
		emit(a, 12, {
			Texture = T.dust,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Color = ColorSequence.new(Color3.fromRGB(235, 228, 215)),
			Size = burstSize(4.5),
			Transparency = FADE_LATE,
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(12, 20),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(85, 85),
			Acceleration = Vector3.new(0, -6, 0),
			Drag = 5,
			Rotation = NumberRange.new(0, 360),
			LightEmission = 0,
		})
		needles(a, color, 8, 25, Vector2.new(70, 70))
		ring(pos, color, 7, 0.35)
	end,
	-- Толчок: вспышка, веер искр и кольцо.
	push = function(pos, color)
		local a = anchor(pos, 2)
		flash(a, color, 6)
		needles(a, color, 16, 45, Vector2.new(180, 25))
		ring(pos - Vector3.new(0, 2.8, 0), color, 9, 0.35)
	end,
	-- Подобрал звезду: вспышка и золотые блёстки вверх.
	sparkle = function(pos, color)
		local a = anchor(pos, 2)
		flash(a, color, 6)
		emit(a, 18, {
			Texture = T.star,
			Color = ColorSequence.new(WHITE, color),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(8, 16),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, -10, 0),
			Rotation = NumberRange.new(0, 360),
			LightEmission = 0.6,
		})
	end,
	-- Выжил в раунде: вспышка и конфетти фонтаном.
	confetti = function(pos, _color)
		local a = anchor(pos, 5)
		flash(a, Color3.fromRGB(255, 220, 80), 7)
		for _, c in
			{
				Color3.fromRGB(255, 80, 120),
				Color3.fromRGB(80, 200, 255),
				Color3.fromRGB(255, 220, 60),
				Color3.fromRGB(120, 255, 120),
				Color3.fromRGB(200, 120, 255),
			}
		do
			emit(a, 14, {
				Texture = "rbxasset://textures/particles/SquareParticle.png", -- проверено в Studio: рисуется
				Color = ColorSequence.new(c),
				Size = NumberSequence.new(0.35),
				Lifetime = NumberRange.new(2, 3.5),
				Speed = NumberRange.new(25, 40),
				SpreadAngle = Vector2.new(35, 35),
				EmissionDirection = Enum.NormalId.Top,
				Acceleration = Vector3.new(0, -35, 0),
				Drag = 1.5,
				RotSpeed = NumberRange.new(-300, 300),
				Rotation = NumberRange.new(0, 360),
				LightEmission = 0.2,
			})
		end
	end,
}

function Vfx.play(kind: string, pos: Vector3, color: Color3?)
	local f = KINDS[kind]
	if f and typeof(pos) == "Vector3" then
		f(pos, if typeof(color) == "Color3" then color else WHITE)
	end
end

return Vfx
