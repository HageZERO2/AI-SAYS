-- 3D-объект из слова (Cube 3D, GenerationService). Генерация идёт 20–40 с, поэтому:
--   request(word, player) — запускаем, как только победитель выбрал слово;
--   get(word)             — копия модели, если уже готова, иначе nil (угроза возьмёт шар с подписью).
-- API в бете: GenerateMeshAsync и его ответ сверять с create.roblox.com/docs/reference/engine/classes/GenerationService.
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

function ModelCache.request(word: string, player: Player?)
	if not okService or not player or pending[word] or folder:FindFirstChild(word) then
		return
	end
	pending[word] = true
	task.spawn(function()
		local ok, _generationId, mesh = pcall(function()
			return (GenerationService :: any):GenerateMeshAsync({ Prompt = word }, player, {})
		end)
		pending[word] = nil
		if ok and typeof(mesh) == "Instance" and mesh:IsA("BasePart") then
			mesh.Name = word
			mesh.Parent = folder
		else
			warn("[ModelCache] не удалось сгенерировать", word, _generationId)
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
