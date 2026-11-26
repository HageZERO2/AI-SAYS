# AI SAYS — память проекта для Claude

Roblox-игра «Саймон говорит» с ИИ-ведущим. Дизайн — `docs/DESIGN.md`, что сделано/дальше — `docs/ROADMAP.md`, карта кода — `docs/GRAPH.md`, запуск и правила кода — `README.md`. Прочитай ROADMAP перед работой.

## Как работаем

- Язык общения с владельцем — русский. Владелец не программист: объясняй шаги просто, команды давай для Windows `cmd`.
- **Каждое законченное изменение: коммит и `git push` сразу**, без отдельной просьбы. Второй разработчик (друг владельца) следит за репо.
  Ветка работы: `claude/beautiful-euler-h9bec6` (PR https://github.com/HageZERO2/AI-SAYS/pull/1). В `main` не пушить, PR не мёржить без просьбы.
- В том же коммите: отметить пункт в `docs/ROADMAP.md`, обновить `README.md`/`docs/GRAPH.md`, если добавлен модуль или RemoteEvent.
- Перед push: `stylua src` и `selene src` (CI их проверяет и падает на любом warning).

## Studio

- Код живёт в `src/` и синхронизируется в Studio через Rojo (`rojo serve`, плагин Rojo → Connect). **Правь файлы в `src/`, не скрипты в Studio** — правки в Studio не попадут в git.
- Через Roblox Studio MCP: запускать Play, читать Output, смотреть иерархию, проверять поведение. Код через MCP запускать только для проверок, не для постоянных изменений.
- После Play в Output должно быть `[Tests] RoundLogic OK` и строки `[Round N] goal+threat word=… ai=true|false`.
- Арена строится кодом (`Services/Arena.luau`), `.rbxl` в git не храним.

## Открытые вопросы (проверить в Studio первым делом)

- Бета-API написаны по памяти и обёрнуты в pcall: `TextGenerator:GenerateTextAsync` (AIHost), `AudioTextToSpeech` (client/Voice), `GenerationService:GenerateMeshAsync` (ModelCache). При `warn` в Output — сверить с create.roblox.com/docs и починить.
- Сила ветра (`Threats.wind`, `* 70`) подобрана наугад.
- `rojo plugin install` у владельца падает с os error 3 (Rojo не находит Studio) — плагин ставить из Creator Store.

## Правила кода

Сервер решает всё, клиент только показывает. Вылет — только `Roster.eliminate`. Любая ошибка ИИ → резерв (`RoundLogic.fallback`), игра не останавливается. Новая цель/угроза: функция в `Goals`/`Threats` + имя в `Config` (самопроверка в `Tests/RoundLogic.spec` упадёт, если забыть).
