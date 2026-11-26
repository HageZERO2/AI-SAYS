-- Короткие эффекты по событию Remotes.Vfx(kind, pos, color?) от сервера (server/Services/Vfx).
-- Всё создаётся только у этого клиента и удаляется само. Текстуры встроенные — без загрузок.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local TEX = "rbxasset://textures/particles/"

local Vfx = {}

local function anchor(pos: Vector3, life: number): Attachment
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.CFrame = CFrame.new(pos)
	local a = Instance.new("Attachment")
	a.Parent = p
	p.Parent = workspace
	Debris:AddItem(p, life)
	return a
end

local function emit(at: Attachment, count: number, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.LightEmission = 1
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = at
	e:Emit(count)
end

-- Плоское светящееся кольцо, расходится и гаснет.
local function shockwave(pos: Vector3, color: Color3, radius: number, time: number)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.3, 1, 1)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, time)
end

local KINDS: { [string]: (pos: Vector3, color: Color3) -> () } = {
	-- Вылет: облако дыма, искры и кольцо.
	poof = function(pos, color)
		local a = anchor(pos, 3)
		emit(a, 25, {
			Texture = TEX .. "smoke_main.dds",
			Color = ColorSequence.new(color),
			Size = NumberSequence.new(2, 7),
			Transparency = NumberSequence.new(0.1, 1),
			Lifetime = NumberRange.new(0.8, 1.3),
			Speed = NumberRange.new(8, 16),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 4,
			LightEmission = 0.3,
		})
		emit(a, 40, {
			Texture = TEX .. "sparkles_main.dds",
			Color = ColorSequence.new(Color3.new(1, 1, 1), color),
			Size = NumberSequence.new(1, 0),
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(15, 30),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 3,
		})
		shockwave(pos - Vector3.new(0, 2.5, 0), color, 10, 0.45)
	end,
	-- Предмет упал: пыль по полу и маленькое кольцо.
	impact = function(pos, color)
		local a = anchor(pos, 2)
		emit(a, 18, {
			Texture = TEX .. "smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(230, 225, 215)),
			Size = NumberSequence.new(1.5, 5),
			Transparency = NumberSequence.new(0.3, 1),
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(10, 18),
			SpreadAngle = Vector2.new(180, 10),
			Acceleration = Vector3.new(0, 4, 0),
			Drag = 5,
			LightEmission = 0,
		})
		shockwave(pos, color, 6, 0.3)
	end,
	-- Толчок: кольцо и вспышка.
	push = function(pos, color)
		local a = anchor(pos, 2)
		emit(a, 20, {
			Texture = TEX .. "sparkles_main.dds",
			Color = ColorSequence.new(color),
			Size = NumberSequence.new(1.2, 0),
			Lifetime = NumberRange.new(0.3, 0.6),
			Speed = NumberRange.new(20, 35),
			SpreadAngle = Vector2.new(180, 30),
		})
		shockwave(pos, color, 8, 0.35)
	end,
	-- Подобрал звезду: золотые искры.
	sparkle = function(pos, color)
		local a = anchor(pos, 2)
		emit(a, 30, {
			Texture = TEX .. "sparkles_main.dds",
			Color = ColorSequence.new(color),
			Size = NumberSequence.new(1, 0),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(8, 16),
			SpreadAngle = Vector2.new(180, 180),
		})
	end,
	-- Выжил в раунде: конфетти фонтаном.
	confetti = function(pos, _color)
		local a = anchor(pos, 5)
		local colors = {
			Color3.fromRGB(255, 80, 120),
			Color3.fromRGB(80, 200, 255),
			Color3.fromRGB(255, 220, 60),
			Color3.fromRGB(120, 255, 120),
			Color3.fromRGB(200, 120, 255),
		}
		for _, c in colors do
			emit(a, 14, {
				Texture = TEX .. "SquareParticle.png",
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
		f(pos, if typeof(color) == "Color3" then color else Color3.new(1, 1, 1))
	end
end

return Vfx
