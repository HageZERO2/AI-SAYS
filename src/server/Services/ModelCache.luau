-- 3D-объект из слова. Два источника:
--   WordBank — заранее запечённые слова (ассеты, tools/bake): грузятся при старте сервера, готовы сразу;
--   GenerationService:GenerateModelAsync — новое слово, ~18 с, живёт в памяти сервера до его закрытия.
--   request(word) — запускаем, как только победитель выбрал слово;
--   get(word)     — копия модели, если уже готова, иначе nil (угроза возьмёт шар с подписью).

local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

local WordBank = require(script.Parent.Parent.WordBank)

local ModelCache = {}

local okService, GenerationService = pcall(game.GetService, game, "GenerationService")
if not okService then
	warn("[ModelCache] GenerationService недоступен — объекты будут шарами")
end

local folder = Instance.new("Folder")
folder.Name = "WordModels"
folder.Parent = ServerStorage

local pending: { [string]: boolean } = {}

-- Запечённые слова грузим при старте, параллельно (по очереди — десятки секунд, первый раунд не дождётся).
-- Запись банка — либо assetId модели из одного слова, либо { pack, part }: пакет из многих слов,
-- MeshPart внутри назван ключом part. Каждый ассет грузим один раз.
local byAsset: { [number]: { [string]: string } } = {} -- assetId → имя MeshPart (или "" для одиночной) → слово
for word, entry in WordBank do
	local asset = if type(entry) == "number" then entry else entry.pack
	local part = if type(entry) == "number" then "" else entry.part
	byAsset[asset] = byAsset[asset] or {}
	byAsset[asset][part] = word
end
for asset, parts in byAsset do
	task.spawn(function()
		local ok, model = pcall(InsertService.LoadAsset, InsertService, asset)
		for part, word in parts do
			local mesh = ok
				and if part == ""
					then model:FindFirstChildWhichIsA("BasePart", true)
					else model:FindFirstChild(part, true)
			if mesh and mesh:IsA("BasePart") then
				mesh.Name = word
				mesh.Parent = folder
			else
				warn("[ModelCache] не загрузилось слово", word, asset, part, if ok then "" else model)
			end
		end
	end)
end

function ModelCache.request(word: string)
	if not okService or WordBank[word] or pending[word] or folder:FindFirstChild(word) then
		return
	end
	pending[word] = true
	task.spawn(function()
		-- GenerateMeshAsync не годится: его меш грузится только на клиенте и не реплицируется.
		-- GenerateModelAsync работает на сервере (~18 с), понимает русское слово, модель видна всем.
		local ok, model = pcall(function()
			return (GenerationService :: any):GenerateModelAsync(
				{ TextPrompt = word, MaxTriangles = 2000 },
				{ PredefinedSchema = "Body1" }
			)
		end)
		pending[word] = nil
		local mesh = ok and typeof(model) == "Instance" and model:FindFirstChildWhichIsA("BasePart", true)
		if mesh then
			mesh.Name = word
			mesh.Parent = folder
		else
			warn("[ModelCache] не удалось сгенерировать", word, model)
		end
	end)
end

-- Копия модели, отмасштабированная так, чтобы большая сторона = size.
function ModelCache.get(word: string, size: number): BasePart?
	local source = folder:FindFirstChild(word) :: BasePart?
	if not source then
		return nil
	end
	local part = source:Clone()
	local s = part.Size
	part.Size = s * (size / math.max(s.X, s.Y, s.Z))
	return part
end

return ModelCache
