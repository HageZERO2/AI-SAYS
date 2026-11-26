--!strict
-- Все «кубики» раунда и тайминги в одном месте. Добавил вариант сюда — добавь обработчик в Services/Goals или Services/Threats.

local Config = {}

Config.AI_PREFIX = "ИИ говорит:"
Config.AI_PREFIX_VOICE = "AI says:" -- голос английский: Roblox TTS не умеет русский

Config.Goals = { "survive", "reach_zone", "freeze", "collect", "hide", "push" } -- все 6 из дизайна
-- все 7 угроз из дизайна
Config.Threats = { "lava", "falling", "shrink", "chaser", "wind", "darkness", "gravity" }
-- Подвохи (Services/Twists): бывают не каждый раунд. Имя → подпись в HUD и подсказка ИИ (англ.).
Config.Twists = { "reverse", "tiny", "leader" }
Config.TwistChance = 0.35
Config.TwistNames = {
	reverse = "управление наоборот",
	tiny = "все крошечные",
	leader = "охота на лидера",
}
Config.TwistHints = {
	reverse = "controls are reversed",
	tiny = "everyone is tiny",
	leader = "a hunter chases only the leader",
}
Config.Arenas = { "school", "kitchen", "candy", "space" } -- темы в Services/Arena (THEMES)

-- Нечестные или скучные пары цель+угроза (сервер не даст ИИ их собрать).
-- Лава заливает пол; замереть нельзя, если тебя сдувает, гонят или пол исчезает; темнота сама по себе не опасна.
Config.Incompatible = {
	freeze = { "lava", "shrink", "wind", "chaser" },
	reach_zone = { "lava" },
	collect = { "lava" },
	survive = { "darkness" },
	hide = { "lava", "shrink" }, -- навесы стоят на полу: лава и исчезающие плитки делают цель невыполнимой
}

Config.CollectTarget = 3 -- сколько предметов собрать в цели collect
Config.Push = {
	Range = 8, -- толкаем ближайшего живого в этом радиусе (стады)
	Cooldown = 1, -- сек между толчками
	Speed = 90, -- горизонтальная скорость, которую получает толкнутый
	Credit = 4, -- сек: вылетел за это время после толчка — засчитано толкнувшему
}

-- Готовые фразы для резерва без ИИ. %s = слово победителя.
Config.FallbackLines = {
	survive = "выживите до конца таймера, пока %s пытаются вас достать!",
	reach_zone = "добегите до зелёной зоны, пока не поздно — %s уже идут!",
	freeze = "замрите! Кто шевельнётся — встретится с %s!",
	collect = "соберите 3 звезды, пока %s не собрали вас!",
	hide = "спрячьтесь под навесом! Кто останется снаружи — достанется %s!",
	push = "столкните кого-нибудь с арены! Кто никого не столкнёт — отдам его %s!",
}
-- Голос резерва (английский, без слова: русское слово TTS пропускает).
Config.FallbackVoice = {
	survive = "Survive until the timer runs out!",
	reach_zone = "Run to the green zone before it is too late!",
	freeze = "Freeze! Whoever moves is out!",
	collect = "Collect three stars before time runs out!",
	hide = "Hide under a shelter! Whoever stays outside is out!",
	push = "Push someone off the arena! Whoever pushes nobody is out!",
}
Config.TrapLines =
	{ -- ловушки: звучат БЕЗ «ИИ говорит», выполнять нельзя. { текст, голос }
		{ "Прыгайте! Пол — это желе!", "Jump! The floor is jelly!" },
		{ "Все прыгаем, быстро!", "Everybody jump, quick!" },
		{ "Прыжок на счёт три! Раз, два, три!", "Jump on three! One, two, three!" },
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
