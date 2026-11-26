-- Арена строится кодом, чтобы проект собирался из одного Rojo без .rbxl-файла.
-- shortcut: одна серая арена "school"; когда художник сделает модели — грузить из ServerStorage.Arenas по имени.

local Arena = {}

local TILE = 6
local GRID = 10 -- 10×10 плиток = 60×60 стадов
local FLOOR_Y = 50

Arena.FloorY = FLOOR_Y
Arena.Size = TILE * GRID

local folder: Folder
local tiles: { BasePart } = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

function Arena.build()
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Arena"
	tiles = {}
	local origin = -Arena.Size / 2 + TILE / 2
	for x = 0, GRID - 1 do
		for z = 0, GRID - 1 do
			local t = part({
				Name = "Tile",
				Size = Vector3.new(TILE, 1, TILE),
				Position = Vector3.new(origin + x * TILE, FLOOR_Y, origin + z * TILE),
				Color = if (x + z) % 2 == 0 then Color3.fromRGB(230, 230, 235) else Color3.fromRGB(200, 205, 215),
				Material = Enum.Material.SmoothPlastic,
				Parent = folder,
			})
			t:SetAttribute("Ring", math.min(x, z, GRID - 1 - x, GRID - 1 - z)) -- 0 = край, для сжатия пола
			table.insert(tiles, t)
		end
	end
	-- Трибуны для выбывших
	part({
		Name = "Stands",
		Size = Vector3.new(Arena.Size, 1, 16),
		Position = Vector3.new(0, FLOOR_Y + 12, Arena.Size / 2 + 14),
		Color = Color3.fromRGB(70, 80, 110),
		Parent = folder,
	})
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
