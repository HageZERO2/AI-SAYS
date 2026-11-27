# Запекание слов (3D-модели заранее)

Игра генерирует модель из слова за ~18 с (`GenerationService:GenerateModelAsync`), а пауза между раундами 5 с.
Поэтому частые слова генерируем заранее и загружаем как ассеты: игра берёт их из `src/server/WordBank.luau` сразу.

С сервера игры сохранить модель нельзя (она живёт только в памяти), загрузить ассет из Studio через MCP тоже
(`AssetService:CreateAssetAsync` — «not available yet»). Поэтому путь такой:

```
Studio (Edit, MCP) ──GenerateModelAsync──► EditableMesh + EditableImage
        │  HTTP POST кусками ≤1 МБ (base64)
        ▼
receiver.py (127.0.0.1:34900) → out/<key>.<pos|nrm|uv|tex>.<N>
        ▼
build_glb.py <key> → out/<key>.glb (меш + текстура 512², повёрнут на 180° под импорт Roblox)
        ▼
Open Cloud (MCP open_cloud_invoke, POST /assets/v1/assets, assetType Model) → assetId
        ▼
src/server/WordBank.luau: ["слово"] = assetId
```

## Один раз настроить (Studio → Assistant Settings → MCP Permissions)

- Publish & manage assets: `asset:read`, `asset:write`
- Папка загрузок: `tools/bake/out` (полный путь)
- Connect to the internet → HTTP domain allow list: `127.0.0.1:34900` (именно с портом)

## Шаги

1. `python tools/bake/receiver.py` (в фоне).
2. В Studio (Edit) через MCP `execute_luau`: создать `ServerStorage.BakeTool` (ModuleScript) с текстом `bake_word.luau`,
   затем `require(game.ServerStorage.BakeTool)("слово", "w31")`. Можно 5–6 слов параллельно через `task.spawn`.
   Если генерация упала (`Model generation failed`) — просто повторить.
3. `python tools/bake/build_glb.py w31 [w32 …]`
4. `open_cloud_invoke` POST `/assets/v1/assets` с `out/w31.glb`, creator — userId владельца игры; опросить
   `GET /assets/v1/operations/<id>` до `done`, взять `assetId` (moderationState должен быть `Approved`).
5. Дописать слово в `WordBank.luau` (ключ — как после `RoundLogic.cleanWord`: строчные буквы).
6. Удалить из места `ServerStorage.BakeTool` и `ServerStorage.Bake`.

`out/` в git не храним. Ассеты удаляются/архивируются только в Creator Dashboard.

## Много слов сразу (пакеты)

Одно слово = один ассет — это сотни загрузок. Поэтому слова пакуются по 20 в один ассет-модель:
GLB с 20 мешами, имя каждого меша — ключ слова (`w041`), импорт Roblox делает из них MeshPart с этими именами.
В `WordBank.luau` такое слово записано как `{ pack = assetId, part = "w041" }`; ModelCache грузит пакет один раз.

1. Дописать слова в `words.txt`, `python tools/bake/plan.py` → `out/plan.json` (ключи и пакеты; цель — `TARGET` слов в банке).
   План делать один раз перед партией: после `bank.py` слова уже в банке, и новый план их пропустит.
2. В Studio (Edit) — фоновая очередь: `BakeTool` (из `bake_word.luau`) запускается волнами по 6 слов раз в ~36 с.
   Лимит GenerationService — около 12 моделей в минуту, чаще — «Rate limit exceeded» (такие слова в конец очереди).
   Ответ MCP не нужен: очередь работает сама, вызов можно не ждать.
3. `python tools/bake/status.py` — какие пакеты выгружены полностью и сколько осталось.
4. `sh tools/bake/pack.sh p03` → `out/p03.glb` (~10 МБ) → загрузить как Model → строку «p03 <assetId>» в `out/packs.txt`.
5. `python tools/bake/bank.py` — пересобирает `WordBank.luau` с загруженными пакетами.
