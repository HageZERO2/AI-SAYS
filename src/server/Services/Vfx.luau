-- Эффекты. Два вида:
--   burst(kind, pos, color?) — короткая вспышка; рисует клиент (client/Vfx) по событию Remotes.Vfx:
--     ParticleEmitter:Emit на сервере до клиентов не доходит, а клиентская отрисовка ещё и плавнее.
--   attach(part, kind) — постоянный эффект на объекте (искры лавы, блеск звезды, пламя охотника):
--     включённый эмиттер реплицируется как обычное свойство и исчезает вместе с объектом.
-- Текстуры — Config.VfxTex (свои, сгенерированы навыком roblox-vfx). LightEmission ≤ 0.6: на светлых аренах больше выбеливает.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)

local Vfx = {}

local T = Config.VfxTex

function Vfx.burst(kind: string, pos: Vector3, color: Color3?)
	Remotes.Vfx:FireAllClients(kind, pos, color)
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 0.5
	e.LightInfluence = 0
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

local FLIP = {
	FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
	FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
}
local function flip(props: { [string]: any }): { [string]: any }
	for k, v in FLIP do
		props[k] = v
	end
	return props
end

local ATTACH: { [string]: (part: BasePart) -> () } = {
	-- Лава: языки пламени по поверхности, искры-штрихи вверх, тёплый дым.
	lava = function(part)
		emitter(
			part,
			flip({
				Texture = T.fire,
				Color = ColorSequence.new(Color3.fromRGB(255, 210, 80), Color3.fromRGB(255, 70, 20)),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 2),
					NumberSequenceKeypoint.new(0.3, 4.5),
					NumberSequenceKeypoint.new(1, 3),
				}),
				Lifetime = NumberRange.new(0.7, 1.1),
				Speed = NumberRange.new(3, 6),
				Rate = 45,
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(10, 10),
				LightEmission = 0.5,
			})
		)
		emitter(part, {
			Texture = T.needle,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 80, 20)),
			Size = NumberSequence.new(0.8, 0),
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(8, 16),
			Rate = 50,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(15, 15),
			LightEmission = 0.6,
		})
		emitter(
			part,
			flip({
				Texture = T.smoke,
				Color = ColorSequence.new(Color3.fromRGB(255, 170, 120)),
				Size = NumberSequence.new(5, 10),
				Transparency = NumberSequence.new(0.55, 1),
				Lifetime = NumberRange.new(2, 3),
				Speed = NumberRange.new(2, 5),
				Rate = 10,
				LightEmission = 0,
				EmissionDirection = Enum.NormalId.Top,
			})
		)
	end,
	-- Звезда (цель collect): блёстки и тёплый свет, видно издалека.
	star = function(part)
		emitter(part, {
			Texture = T.star,
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 200, 60)),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 1.6),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(1, 3),
			Rate = 8,
			Rotation = NumberRange.new(0, 360),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 0.6,
		})
		light(part, Color3.fromRGB(255, 220, 80), 12, 2)
	end,
	-- Зона (reach_zone): зелёные штрихи вверх — маяк, видно с любого края арены.
	zone = function(part)
		emitter(part, {
			Texture = T.needle,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Color = ColorSequence.new(Color3.fromRGB(220, 255, 230), Color3.fromRGB(80, 255, 140)),
			Size = NumberSequence.new(1.6, 0.4),
			Lifetime = NumberRange.new(1, 1.8),
			Speed = NumberRange.new(10, 18),
			Rate = 35,
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(4, 4),
			LightEmission = 0.6,
		})
		light(part, Color3.fromRGB(80, 255, 140), 20, 3)
	end,
	-- Охотник (подвох leader): мультяшное пламя и красный свет.
	flame = function(part)
		emitter(
			part,
			flip({
				Texture = T.fire,
				Color = ColorSequence.new(Color3.fromRGB(255, 120, 80), Color3.fromRGB(200, 0, 40)),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 2.5),
					NumberSequenceKeypoint.new(0.3, 4),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(0.5, 0.8),
				Speed = NumberRange.new(3, 6),
				Rate = 35,
				EmissionDirection = Enum.NormalId.Top,
				LightEmission = 0.5,
				ZOffset = 1,
			})
		)
		light(part, Color3.fromRGB(255, 40, 60), 16, 3)
	end,
	-- Преследователь из слова: шлейф светлого cel-дыма (тёмный читается как чёрные кляксы).
	smoke = function(part)
		emitter(
			part,
			flip({
				Texture = T.smoke,
				Color = ColorSequence.new(Color3.fromRGB(170, 160, 190)),
				Size = NumberSequence.new(2.5, 6),
				Transparency = NumberSequence.new(0.3, 1),
				Lifetime = NumberRange.new(1, 1.6),
				Speed = NumberRange.new(1, 2),
				Rate = 14,
				Rotation = NumberRange.new(0, 360),
				LightEmission = 0,
			})
		)
	end,
}
function Vfx.attach(part: BasePart, kind: string)
	ATTACH[kind](part)
end

return Vfx
