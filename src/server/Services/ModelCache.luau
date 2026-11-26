-- 3D-объект из слова (Cube 3D, GenerationService). Генерация идёт 20–40 с, поэтому:
--   request(word)         — запускаем, как только победитель выбрал слово;
--   get(word)             — копия модели, если уже готова, иначе nil (угроза возьмёт шар с подписью).
-- GenerationService:GenerateModelAsync(inputs, schema) — проверено живьём в Studio.
-- shortcut: кэш живёт только в памяти сервера; неделя 3 — сохранять ассеты слов в DataStore и сгенерировать 500 слов заранее.

local ServerStorage = game:GetService("ServerStorage")

local ModelCache = {}

local okService, GenerationService = pcall(game.GetService, game, "GenerationService")
if not okService then
	warn("[ModelCache] GenerationService недоступен — объекты будут шарами")
end

local folder = Instance.new("Folder")
folder.Name = "WordModels"
folder.Parent = ServerStorage

local pending: { [string]: boolean } = {}

function ModelCache.request(word: string)
	if not okService or pending[word] or folder:FindFirstChild(word) then
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
