# AI SAYS («ИИ говорит»)

«Саймон говорит» для Roblox, где ведущий — нейросеть с голосом. Каждый раунд ИИ собирает испытание из готовых блоков, победитель раунда даёт ему слово для следующего. Если приказ прозвучал **без** «ИИ говорит» — выполнять нельзя.

Полный дизайн: [docs/DESIGN.md](docs/DESIGN.md) · Карта кода: [docs/GRAPH.md](docs/GRAPH.md) · Что сделано и что дальше: [docs/ROADMAP.md](docs/ROADMAP.md)

## Запуск

Нужны Roblox Studio и [Aftman](https://github.com/LPGhatguy/aftman) (ставит Rojo, Selene, StyLua нужных версий).

```bash
aftman install
```

```bash
rojo serve
```

В Studio: открыть пустой Baseplate → плагин Rojo → **Connect** → **Play**. Арена строится кодом, `.rbxl` в репо не храним.

Собрать place-файл без Studio: `rojo build -o AI-SAYS.rbxl` (то же делает CI и выкладывает файл в артефакты сборки).

Для ИИ и голоса: Game Settings → включить доступ к генеративным API (Text Generation / TTS в бете). Без них игра работает на резерве — случайные раунды и заготовленные фразы.

## Как устроено

```
src/
  shared/                       → ReplicatedStorage.Shared
    Config.luau                 все варианты целей/угроз/арен, тайминги, фразы
    RoundLogic.luau             чистая логика: валидация ответа ИИ, резерв, проверка слова
  server/                       → ServerScriptService.Server
    init.server.luau            точка входа: порядок запуска сервисов
    Services/
      RoundService.luau         главный цикл раунда
      AIHost.luau               запрос к Text Generation API → JSON → Round
      Goals.luau                цели: survive, reach_zone, freeze, collect
      Threats.luau              угрозы: lava, falling, shrink, chaser, wind, darkness, gravity
      ModelCache.luau           3D-модель из слова (GenerationService) + кэш в памяти
      Players.luau              кто жив, кто на трибунах (атрибут Alive)
      Arena.luau                строит арену из плиток + трибуны
      WordService.luau          слово победителя: проверка, фильтр Roblox
      Remotes.luau              список всех RemoteEvent и их аргументов
    Tests/RoundLogic.spec.luau  самопроверка, запускается при Play в Studio
  client/                       → StarterPlayerScripts.Client
    init.client.luau            HUD, ввод слова
    Voice.luau                  озвучка ведущего (AudioTextToSpeech)
```

### Цикл раунда

```
пауза 5с → ИИ собирает раунд (1 запрос) → арена сброшена, все на поле
  → 30%: ловушка «Прыгайте!» без «ИИ говорит» — прыгнул = вылетел
  → «ИИ говорит: …» → цель + угроза идут таймер (60с → ускоряется до 25с)
  → цель проверяет выживших → случайный выживший вводит слово → следующий раунд
```

### Правила кода

- **Сервер решает всё.** Клиент только показывает `State`/`Announce` и шлёт `SubmitWord`. Слово принимается только от спрошенного игрока, один раз, после `cleanWord` и `TextService`-фильтра.
- **ИИ не пишет код и не решает правила.** Он выбирает `goal/threat/arena` из списка в `Config` и пишет фразу. `RoundLogic.fromAI` отбрасывает всё лишнее, нечестные пары (`Config.Incompatible`) заменяет.
- **Резерв всегда.** Любая ошибка ИИ/TTS → `RoundLogic.fallback`, игра не останавливается.
- Вылет — только через `Roster.eliminate(player, reason)`.

### Как добавить…

- **Угрозу:** функция `Threats.<name>(ctx) -> stop()` + имя в `Config.Threats` (+ в `Config.Incompatible`, если с какой-то целью нечестно).
- **Цель:** функция `Goals.<name>(ctx) -> finish()` + имя в `Config.Goals` + фраза в `Config.FallbackLines`.
- **Ловушку:** строка в `Config.TrapLines` (сейчас все ловушки — «прыгайте»).

## Проверки

CI (`.github/workflows/ci.yml`) на каждый push: `selene src`, `stylua --check src`, `rojo build`. Перед коммитом локально: `stylua src && selene src`.

Ветки: работаем в feature-ветках, в `main` — через pull request.
