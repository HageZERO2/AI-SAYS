-- Запекание слова: модуль-функция (WORD, KEY). В Studio (Edit) через MCP: положить в ServerStorage.BakeTool,
-- вызвать require(...)(word, key). Можно звать параллельно через task.spawn.
-- Генерирует модель (GenerationService) — или берёт уже сгенерированную ServerStorage.Bake.<KEY> — и шлёт
-- на receiver.py потоки <KEY>.<pos|uv|nrm|tex>.<N>: base64 кусками ≤ ~700 КБ (лимит тела запроса в Studio 1 МБ).
--   pos/nrm/uv — float32 по углам треугольников; tex — RGBA пиксели текстуры построчно.
-- Дальше: python tools/bake/build_glb.py <KEY> → <KEY>.glb → загрузка в Open Cloud как Model.

local CHUNK = 512 * 1024 -- байт до base64

local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local EncodingService = game:GetService("EncodingService")
local GenerationService = game:GetService("GenerationService")
local ServerStorage = game:GetService("ServerStorage")

local function post(name: string, data: buffer)
	local len = buffer.len(data)
	for i = 0, math.ceil(len / CHUNK) - 1 do
		local n = math.min(CHUNK, len - i * CHUNK)
		local piece = buffer.create(n)
		buffer.copy(piece, 0, data, i * CHUNK, n)
		HttpService:PostAsync(
			`http://127.0.0.1:34900/{name}.{i}`,
			buffer.tostring(EncodingService:Base64Encode(piece)),
			Enum.HttpContentType.TextPlain
		)
	end
end

return function(WORD: string, KEY: string): string
	local bake = ServerStorage:FindFirstChild("Bake") or Instance.new("Folder")
	bake.Name = "Bake"
	bake.Parent = ServerStorage
	local model = bake:FindFirstChild(KEY)
	if not model then
		model = GenerationService:GenerateModelAsync(
			{ TextPrompt = WORD, MaxTriangles = 2000 },
			{ PredefinedSchema = "Body1" }
		)
		model.Name = KEY
		model.Parent = bake
	end
	local part = model:FindFirstChildWhichIsA("MeshPart", true)
	assert(part, "no MeshPart")
	local mesh = AssetService:CreateEditableMeshAsync(part.MeshContent)
	local image = AssetService:CreateEditableImageAsync(part.TextureContent)

	local faces = mesh:GetFaces()
	local corners = #faces * 3
	local pos, nrm, uv = buffer.create(corners * 12), buffer.create(corners * 12), buffer.create(corners * 8)
	local k = 0
	for i, face in faces do
		local vs, us, ns = mesh:GetFaceVertices(face), mesh:GetFaceUVs(face), mesh:GetFaceNormals(face)
		for c = 1, 3 do
			local p = mesh:GetPosition(vs[c])
			local n = if ns[c] then mesh:GetNormal(ns[c]) else Vector3.yAxis
			local t = if us[c] then mesh:GetUV(us[c]) else Vector2.zero
			buffer.writef32(pos, k * 12, p.X)
			buffer.writef32(pos, k * 12 + 4, p.Y)
			buffer.writef32(pos, k * 12 + 8, p.Z)
			buffer.writef32(nrm, k * 12, n.X)
			buffer.writef32(nrm, k * 12 + 4, n.Y)
			buffer.writef32(nrm, k * 12 + 8, n.Z)
			buffer.writef32(uv, k * 8, t.X)
			buffer.writef32(uv, k * 8 + 4, t.Y)
			k += 1
		end
		if i % 500 == 0 then
			task.wait()
		end
	end
	post(`{KEY}.pos`, pos)
	post(`{KEY}.nrm`, nrm)
	post(`{KEY}.uv`, uv)
	post(`{KEY}.tex`, image:ReadPixelsBuffer(Vector2.zero, image.Size))

	local w = image.Size.X
	mesh:Destroy()
	image:Destroy()
	return `{KEY} {WORD}: {#faces} tris, tex {w}`
end
