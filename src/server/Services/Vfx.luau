-- Эффекты. Два вида:
--   burst(kind, pos, color?) — короткая вспышка; рисует клиент (client/Vfx) по событию Remotes.Vfx:
--     ParticleEmitter:Emit на сервере до клиентов не доходит, а клиентская отрисовка ещё и плавнее.
--   attach(part, kind) — постоянный эффект на объекте (искры лавы, блеск звезды, пламя охотника):
--     включённый эмиттер реплицируется как обычное свойство и исчезает вместе с объектом.
-- Текстуры встроенные (rbxasset://textures/particles/*) — без загрузок.

local Remotes = require(script.Parent.Remotes)

local Vfx = {}

local TEX = "rbxasset://textures/particles/"

function Vfx.burst(kind: string, pos: Vector3, color: Color3?)
	Remotes.Vfx:FireAllClients(kind, pos, color)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
end

local ATTACH: { [string]: (part: BasePart) -> () } = {
	-- Лава: искры и жар поднимаются со всей поверхности.
	lava = function(part)
		emitter(part, {
			Texture = TEX .. "fire_sparks_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 10)),
			Size = NumberSequence.new(0.6, 0.1),
			Lifetime = NumberRange.new(1.5, 3),
			Speed = NumberRange.new(6, 14),
			Rate = 120,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(15, 15),
		})
		emitter(part, {
			Texture = TEX .. "smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 120, 40)),
			Size = NumberSequence.new(4, 10),
			Transparency = NumberSequence.new(0.6, 1),
			Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(2, 5),
			Rate = 25,
			LightEmission = 0.5,
			EmissionDirection = Enum.NormalId.Top,
		})
	end,
	-- Звезда (цель collect): блёстки и тёплый свет, видно издалека.
	star = function(part)
		emitter(part, {
			Texture = TEX .. "sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 230, 90)),
			Size = NumberSequence.new(0.8, 0),
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(1, 3),
			Rate = 12,
			SpreadAngle = Vector2.new(180, 180),
		})
		light(part, Color3.fromRGB(255, 220, 80), 12, 2)
	end,
	-- Зона (reach_zone): зелёные искры вверх, как маяк.
	zone = function(part)
		emitter(part, {
			Texture = TEX .. "sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(120, 255, 160)),
			Size = NumberSequence.new(1, 0),
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(6, 10),
			Rate = 40,
			EmissionDirection = Enum.NormalId.Top,
		})
		light(part, Color3.fromRGB(80, 255, 140), 20, 3)
	end,
	-- Охотник (подвох leader): пламя и красный свет.
	flame = function(part)
		emitter(part, {
			Texture = TEX .. "fire_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 80, 60), Color3.fromRGB(120, 0, 30)),
			Size = NumberSequence.new(3, 0.5),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(2, 4),
			Rate = 50,
			EmissionDirection = Enum.NormalId.Top,
		})
		light(part, Color3.fromRGB(255, 40, 60), 16, 3)
	end,
	-- Преследователь из слова: шлейф дыма.
	smoke = function(part)
		emitter(part, {
			Texture = TEX .. "smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(90, 80, 110)),
			Size = NumberSequence.new(2, 6),
			Transparency = NumberSequence.new(0.4, 1),
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(1, 2),
			Rate = 20,
			LightEmission = 0,
		})
	end,
}
function Vfx.attach(part: BasePart, kind: string)
	ATTACH[kind](part)
end

return Vfx
