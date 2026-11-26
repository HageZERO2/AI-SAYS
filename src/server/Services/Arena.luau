-- Арена строится кодом, чтобы проект собирался из одного Rojo без .rbxl-файла.
-- Все арены — одна и та же сетка плиток GRID×GRID на высоте FLOOR_Y (на неё опираются цели и угрозы:
-- сжатие пола по кольцам, лава, зона в центре). Арены отличаются темой: цвет/материал плиток, свет, декор вокруг.
-- Декор только для вида: CanCollide/CanTouch/CanQuery = false — он не должен ловить падающих (вылет и цель push).
-- Крупный реквизит — запечённые модели слов (ServerStorage.WordModels, грузит ModelCache); не загрузились — без них.

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local Arena = {}

local TILE = 6
local GRID = 16 -- 16×16 плиток = 96×96 стадов (чётное: в центре остаётся 2×2, которое сжатие не трогает)
local FLOOR_Y = 50
local HALF = TILE * GRID / 2
local TOP = FLOOR_Y + 0.5 -- верх плиток

Arena.FloorY = FLOOR_Y
Arena.Size = TILE * GRID
Arena.Rings = GRID / 2 - 1 -- колец плиток, которые может убрать сжатие (центр 2×2 остаётся)
Arena.AreaScale = (Arena.Size / 60) ^ 2 -- во сколько раз арена больше исходной 60×60: под неё плотность угроз

local folder: Folder
local tiles: { BasePart } = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- Декор: только вид, сквозь него падают.
local function deco(props: { [string]: any }): Part
	local p = part(props)
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Parent = folder
	return p
end

-- Реквизит из запечённого слова: большая сторона = size.
local function prop(word: string, size: number, cf: CFrame)
	local bank = ServerStorage:FindFirstChild("WordModels")
	local source = bank and bank:FindFirstChild(word) :: BasePart?
	if not source then
		return
	end
	local p = source:Clone()
	p.Size *= size / math.max(p.Size.X, p.Size.Y, p.Size.Z)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CFrame = cf
	p.Parent = folder
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Свет по умолчанию; тема может переопределить, каждая сборка сначала возвращает его.
local LIGHT = {
	ClockTime = Lighting.ClockTime,
	Brightness = Lighting.Brightness,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
}

-- Дымка и постобработка: создаются один раз, тема меняет только цвета/плотность дымки.
-- При Atmosphere туман Lighting.Fog* не работает — угроза darkness сгущает дымку сама.
local atmosphere = Instance.new("Atmosphere")
atmosphere.Parent = Lighting
local bloom = Instance.new("BloomEffect") -- неон светится: лава, зона, звёзды, охотник, рамка космоса
bloom.Intensity = 0.45 -- сильнее — красное предупреждение сжатия и лава заливают весь экран
bloom.Size = 20
bloom.Threshold = 0.95
bloom.Parent = Lighting
local grade = Instance.new("ColorCorrectionEffect")
grade.Saturation = 0.15
grade.Contrast = 0.08
grade.Parent = Lighting

type Theme = {
	tiles: { Color3 }, -- шахматка из двух цветов
	material: Enum.Material,
	stands: Color3,
	light: { [string]: any }?,
	atmo: { Color: Color3, Decay: Color3, Density: number, Haze: number, Glare: number },
	decor: () -> (),
}

local THEMES: { [string]: Theme } = {
	-- Класс: доска за ареной, шкафчики, парты, часы.
	school = {
		tiles = { rgb(230, 230, 235), rgb(200, 205, 215) },
		material = Enum.Material.SmoothPlastic,
		stands = rgb(70, 80, 110),
		atmo = { Color = rgb(200, 220, 255), Decay = rgb(110, 140, 190), Density = 0.3, Haze = 1, Glare = 0.3 },
		decor = function()
			local board = deco({
				Size = Vector3.new(54, 22, 1),
				Position = Vector3.new(0, TOP + 16, -HALF - 22),
				Color = rgb(35, 70, 50),
				Material = Enum.Material.Slate,
			})
			deco({
				Size = Vector3.new(58, 26, 0.8),
				Position = board.Position - Vector3.new(0, 0, 0.6),
				Color = rgb(140, 90, 50),
				Material = Enum.Material.Wood,
			})
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Back -- смотрит на арену (+Z)
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Text = "ИИ ГОВОРИТ:\n2 + 2 = 🦈"
			text.TextScaled = true
			text.Font = Enum.Font.PermanentMarker
			text.TextColor3 = Color3.new(1, 1, 1)
			text.Parent = gui
			gui.Parent = board
			deco({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1, 7, 7),
				CFrame = CFrame.new(0, TOP + 31, -HALF - 22) * CFrame.Angles(0, math.pi / 2, 0),
				Color = rgb(250, 250, 250),
			})
			for i = 0, 7 do -- шкафчики справа
				deco({
					Size = Vector3.new(4, 14, 4.5),
					Position = Vector3.new(HALF + 22, TOP + 4, -HALF + 6 + i * 6.5),
					Color = if i % 2 == 0 then rgb(60, 110, 200) else rgb(50, 95, 180),
					Material = Enum.Material.DiamondPlate,
				})
			end
			for i = 0, 2 do -- парты слева
				for j = 0, 1 do
					local c = Vector3.new(-HALF - 18 - j * 10, TOP - 2, -HALF + 10 + i * 18)
					deco({
						Size = Vector3.new(7, 0.6, 5),
						Position = c + Vector3.new(0, 3, 0),
						Color = rgb(190, 140, 80),
						Material = Enum.Material.Wood,
					})
					deco({
						Size = Vector3.new(6, 3, 0.4),
						Position = c + Vector3.new(0, 1.2, 2.2),
						Color = rgb(90, 90, 100),
						Material = Enum.Material.Metal,
					})
				end
			end
			prop("робот", 14, CFrame.new(-HALF - 10, TOP + 4, -HALF - 14) * CFrame.Angles(0, math.rad(30), 0))
		end,
	},
	-- Кухня: шахматный пол, холодильник, плита с конфорками, шкафы, еда.
	kitchen = {
		tiles = { rgb(245, 245, 245), rgb(40, 40, 45) },
		material = Enum.Material.Marble,
		stands = rgb(170, 70, 50),
		atmo = { Color = rgb(255, 225, 190), Decay = rgb(200, 140, 90), Density = 0.32, Haze = 1.5, Glare = 0.5 },
		decor = function()
			local fridge = deco({
				Size = Vector3.new(24, 44, 14),
				Position = Vector3.new(-14, TOP + 12, -HALF - 20),
				Color = rgb(225, 235, 240),
				Material = Enum.Material.Metal,
			})
			deco({
				Size = Vector3.new(1, 12, 1.5),
				Position = fridge.Position + Vector3.new(9, 8, 7.5),
				Color = rgb(160, 160, 170),
				Material = Enum.Material.Metal,
			})
			deco({
				Size = Vector3.new(24, 0.4, 0.4),
				Position = fridge.Position + Vector3.new(0, 4, 7.1),
				Color = rgb(170, 180, 190),
			})
			-- плита справа
			local stove = deco({
				Size = Vector3.new(16, 12, 46),
				Position = Vector3.new(HALF + 20, TOP - 4, 0),
				Color = rgb(60, 60, 65),
				Material = Enum.Material.Metal,
			})
			for _, z in { -14, -4, 6, 16 } do
				deco({
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.4, 8, 8),
					CFrame = CFrame.new(stove.Position + Vector3.new(0, 6.2, z)) * CFrame.Angles(0, 0, math.pi / 2),
					Color = rgb(255, 90, 30),
					Material = Enum.Material.Neon,
				})
			end
			-- шкафы слева
			for i = 0, 4 do
				deco({
					Size = Vector3.new(10, 14, 10),
					Position = Vector3.new(-HALF - 18, TOP - 6, -HALF + 6 + i * 11),
					Color = rgb(120, 170, 140),
					Material = Enum.Material.Wood,
				})
				deco({
					Size = Vector3.new(11, 1, 11),
					Position = Vector3.new(-HALF - 18, TOP + 1.5, -HALF + 6 + i * 11),
					Color = rgb(230, 225, 215),
					Material = Enum.Material.Marble,
				})
			end
			prop("пицца", 16, CFrame.new(HALF + 20, TOP + 5, -9))
			prop("арбузы", 12, CFrame.new(-HALF - 18, TOP + 7, -HALF + 17))
			prop("бананы", 9, CFrame.new(-HALF - 18, TOP + 6, -HALF + 39))
			prop("огурцы", 9, CFrame.new(-HALF - 18, TOP + 6, -HALF + 28))
		end,
	},
	-- Конфетная страна: розовый пол, леденцы, карамельные трости, сладости.
	candy = {
		tiles = { rgb(255, 175, 205), rgb(255, 240, 245) },
		material = Enum.Material.SmoothPlastic,
		stands = rgb(140, 90, 200),
		light = { Ambient = rgb(150, 120, 140), OutdoorAmbient = rgb(170, 140, 160) },
		atmo = { Color = rgb(255, 200, 230), Decay = rgb(220, 130, 200), Density = 0.35, Haze = 2, Glare = 0.6 },
		decor = function()
			local colors =
				{ rgb(255, 80, 120), rgb(90, 200, 255), rgb(255, 210, 60), rgb(130, 230, 120), rgb(200, 120, 255) }
			local spots = {
				Vector3.new(-HALF - 14, 0, -HALF - 10),
				Vector3.new(0, 0, -HALF - 18),
				Vector3.new(HALF + 14, 0, -HALF - 10),
				Vector3.new(-HALF - 18, 0, 8),
				Vector3.new(HALF + 18, 0, 8),
			}
			for i, s in spots do -- леденцы на палочке
				local base = s + Vector3.new(0, TOP - 10, 0)
				deco({
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(26, 1.2, 1.2),
					CFrame = CFrame.new(base + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.pi / 2),
					Color = rgb(250, 250, 250),
				})
				deco({
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(2, 14, 14),
					CFrame = CFrame.new(base + Vector3.new(0, 30, 0)) * CFrame.Angles(0, math.rad(i * 40), 0),
					Color = colors[i],
					Material = Enum.Material.Glass,
					Transparency = 0.1,
				})
			end
			for i, x in { -HALF - 8, HALF + 8 } do -- карамельные трости
				for k = 0, 7 do
					deco({
						Size = Vector3.new(2.4, 2.6, 2.4),
						Position = Vector3.new(x, TOP - 6 + k * 2.6, HALF + 6),
						Color = if k % 2 == 0 then rgb(230, 40, 50) else rgb(250, 250, 250),
					})
				end
				deco({
					Size = Vector3.new(6, 2.4, 2.4),
					Position = Vector3.new(x + (i * 2 - 3) * 2, TOP + 15, HALF + 6),
					Color = rgb(230, 40, 50),
				})
			end
			for _ = 1, 10 do -- мармеладки внизу, вокруг
				local a = math.random() * math.pi * 2
				local r = HALF + 14 + math.random() * 16
				deco({
					Shape = Enum.PartType.Ball,
					Size = Vector3.one * (4 + math.random() * 5),
					Position = Vector3.new(math.cos(a) * r, TOP - 12 + math.random() * 6, math.sin(a) * r),
					Color = colors[math.random(#colors)],
					Material = Enum.Material.Glass,
					Transparency = 0.15,
				})
			end
			prop("пончики", 14, CFrame.new(-HALF - 20, TOP + 2, -HALF + 14) * CFrame.Angles(math.rad(70), 0, 0))
			prop("мороженое", 16, CFrame.new(HALF + 20, TOP + 4, -HALF + 18))
			prop("торт", 18, CFrame.new(0, TOP - 2, -HALF - 26))
		end,
	},
	-- Космос: тёмный пол с неоновым краем, ночь со звёздами, планеты, ракета.
	space = {
		tiles = { rgb(70, 80, 150), rgb(95, 105, 185) }, -- светлее ночи: на полу должно быть видно игроков и красное предупреждение shrink
		material = Enum.Material.SmoothPlastic,
		stands = rgb(60, 60, 90),
		light = { ClockTime = 0, Ambient = rgb(140, 140, 170), OutdoorAmbient = rgb(140, 140, 170), Brightness = 2 },
		atmo = { Color = rgb(90, 70, 160), Decay = rgb(40, 20, 90), Density = 0.25, Haze = 0.5, Glare = 0 },
		decor = function()
			local S = Arena.Size
			for _, e in { { 0, -HALF, S, 0.4 }, { 0, HALF, S, 0.4 }, { -HALF, 0, 0.4, S }, { HALF, 0, 0.4, S } } do
				deco({
					Size = Vector3.new(e[3], 0.3, e[4]),
					Position = Vector3.new(e[1], TOP + 0.1, e[2]),
					Color = rgb(80, 240, 255),
					Material = Enum.Material.Neon,
				})
			end
			local planet = deco({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 50,
				Position = Vector3.new(-70, TOP + 30, -110),
				Color = rgb(230, 140, 70),
				Material = Enum.Material.Sand,
			})
			deco({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.5, 90, 90),
				CFrame = CFrame.new(planet.Position) * CFrame.Angles(math.rad(15), 0, math.rad(80)),
				Color = rgb(240, 210, 160),
				Transparency = 0.3,
			})
			deco({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 22,
				Position = Vector3.new(90, TOP + 45, -60),
				Color = rgb(90, 160, 255),
				Material = Enum.Material.Ice,
			})
			deco({
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 10,
				Position = Vector3.new(60, TOP + 20, -100),
				Color = rgb(200, 200, 210),
				Material = Enum.Material.Slate,
			})
			for _ = 1, 14 do -- астероиды под ареной
				local a = math.random() * math.pi * 2
				local r = HALF + 10 + math.random() * 30
				deco({
					Size = Vector3.one * (2 + math.random() * 4),
					CFrame = CFrame.new(math.cos(a) * r, TOP - 15 - math.random() * 20, math.sin(a) * r)
						* CFrame.Angles(math.random() * 6, math.random() * 6, 0),
					Color = rgb(110, 100, 95),
					Material = Enum.Material.Basalt,
				})
			end
			prop("ракета", 28, CFrame.new(HALF + 22, TOP + 8, -HALF - 6) * CFrame.Angles(0, 0, math.rad(-15)))
			prop("робот", 10, CFrame.new(-HALF - 16, TOP + 2, -HALF - 8))
		end,
	},
}
Arena.Themes = THEMES

-- name — тема из Config.Arenas (ИИ выбирает); неизвестная → school.
function Arena.build(name: string?)
	if folder then
		folder:Destroy()
	end
	local theme = THEMES[name or "school"] or THEMES.school
	for k, v in LIGHT do
		(Lighting :: any)[k] = if theme.light and theme.light[k] ~= nil then theme.light[k] else v
	end
	for k, v in theme.atmo do
		(atmosphere :: any)[k] = v
	end
	folder = Instance.new("Folder")
	folder.Name = "Arena"
	tiles = {}
	local origin = -HALF + TILE / 2
	for x = 0, GRID - 1 do
		for z = 0, GRID - 1 do
			local t = part({
				Name = "Tile",
				Size = Vector3.new(TILE, 1, TILE),
				Position = Vector3.new(origin + x * TILE, FLOOR_Y, origin + z * TILE),
				Color = theme.tiles[(x + z) % 2 + 1],
				Material = theme.material,
				Parent = folder,
			})
			t:SetAttribute("Ring", math.min(x, z, GRID - 1 - x, GRID - 1 - z)) -- 0 = край, для сжатия пола
			table.insert(tiles, t)
		end
	end
	-- Трибуны для выбывших (твёрдые — на них стоят)
	part({
		Name = "Stands",
		Size = Vector3.new(Arena.Size, 1, 16),
		Position = Vector3.new(0, FLOOR_Y + 12, HALF + 14),
		Color = theme.stands,
		Parent = folder,
	})
	theme.decor()
	folder.Parent = workspace
end

function Arena.tiles(): { BasePart }
	return tiles
end

function Arena.folder(): Folder
	return folder
end

function Arena.randomFloorPoint(rng: Random): Vector3
	local half = Arena.Size / 2 - TILE
	return Vector3.new(rng:NextNumber(-half, half), FLOOR_Y + 4, rng:NextNumber(-half, half))
end

function Arena.standsPoint(rng: Random): CFrame
	return CFrame.new(rng:NextNumber(-20, 20), FLOOR_Y + 16, Arena.Size / 2 + 14)
end

return Arena
