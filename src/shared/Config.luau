--!strict
-- Все «кубики» раунда и тайминги в одном месте. Добавил вариант сюда — добавь обработчик в Services/Goals или Services/Threats.

local Config = {}

Config.AI_PREFIX = "ИИ говорит:"

Config.Goals = { "survive", "reach_zone", "freeze", "collect" } -- из 6 в дизайне
-- все 7 угроз из дизайна
Config.Threats = { "lava", "falling", "shrink", "chaser", "wind", "darkness", "gravity" }
Config.Arenas = { "school" } -- одна арена в неделю 1

-- Нечестные или скучные пары цель+угроза (сервер не даст ИИ их собрать).
-- Лава заливает пол; замереть нельзя, если тебя сдувает, гонят или пол исчезает; темнота сама по себе не опасна.
Config.Incompatible = {
	freeze = { "lava", "shrink", "wind", "chaser" },
	reach_zone = { "lava" },
	collect = { "lava" },
	survive = { "darkness" },
}

Config.CollectTarget = 3 -- сколько предметов собрать в цели collect

-- Готовые фразы для резерва без ИИ. %s = слово победителя.
Config.FallbackLines = {
	survive = "выживите до конца таймера, пока %s пытаются вас достать!",
	reach_zone = "добегите до зелёной зоны, пока не поздно — %s уже идут!",
	freeze = "замрите! Кто шевельнётся — встретится с %s!",
	collect = "соберите 3 звезды, пока %s не собрали вас!",
}
Config.TrapLines = { -- ловушки: звучат БЕЗ «ИИ говорит», выполнять нельзя
	"Прыгайте! Пол — это желе!",
	"Все прыгаем, быстро!",
	"Прыжок на счёт три! Раз, два, три!",
}
Config.DefaultWords =
	{ "акулы", "бабушки", "желе", "кактусы", "пингвины", "арбузы" }

Config.Timing = {
	Intermission = 5, -- пауза между раундами (сек)
	RoundStart = 60, -- первый раунд
	RoundMin = 25, -- раунды ускоряются до этого минимума
	SpeedUp = 0.92, -- множитель длительности после каждого раунда
	TrapWindow = 4, -- сколько секунд действует ловушка
	TrapChance = 0.3, -- шанс ловушки перед раундом
	WordPrompt = 12, -- сколько у победителя времени на слово
}

Config.MinPlayers = 1 -- для теста в Studio; на проде поднять до 2
Config.MaxWordLength = 20

return Config
