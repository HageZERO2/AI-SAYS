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

-- ID товаров (Creator Dashboard / Open Cloud). 0 — не создан: кнопки нет, Shop его не выдаёт.
Config.Shop = {
	Word = 3736645921, -- developer product «Моё слово»
	ExtraLife = 3736645937, -- developer product «Вторая жизнь»
	Shield = 3736645950, -- developer product «Щит от охотника»
	VipPass = 2100198687, -- game pass VIP
	Voice = 3737001392, -- developer product «Голос ведущего» (99): новый голос на сервере на VoiceMinutes
}
Config.Voices = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11" } -- VoiceId TTS (англ.); первый — обычный
Config.VoiceMinutes = 15
-- Косметика за монеты (Services/Cosmetics). id без запятых: купленные хранятся строкой "ice,fire".
Config.Trails = {
	{
		id = "mint",
		name = "Мята",
		price = 25,
		colors = { Color3.fromRGB(120, 255, 200), Color3.fromRGB(40, 160, 120) },
	},
	{
		id = "ice",
		name = "Лёд",
		price = 50,
		colors = { Color3.fromRGB(220, 250, 255), Color3.fromRGB(80, 170, 255) },
	},
	{
		id = "fire",
		name = "Огонь",
		price = 100,
		colors = { Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 60, 20) },
	},
	{
		id = "rainbow",
		name = "Радуга",
		price = 199,
		colors = {
			Color3.fromRGB(255, 60, 60),
			Color3.fromRGB(255, 200, 40),
			Color3.fromRGB(60, 220, 90),
			Color3.fromRGB(60, 140, 255),
			Color3.fromRGB(190, 80, 255),
		},
	},
}
-- Эмоция победителя: играет у выживших в конце раунда. Анимации R15 от Roblox (доступны любой игре).
Config.Emotes = {
	{ id = "wave", name = "Привет", price = 25, anim = "rbxassetid://507770239" },
	{ id = "cheer", name = "Ура", price = 50, anim = "rbxassetid://507770677" },
	{ id = "laugh", name = "Смех", price = 100, anim = "rbxassetid://507770818" },
	{ id = "dance", name = "Танец", price = 150, anim = "rbxassetid://507771019" },
}
Config.CoinsPerRound = 10 -- монеты за пережитый раунд (VIP ×2)
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
-- Ловушки: звучат БЕЗ «ИИ говорит», выполнять нельзя. kind — какое действие ловим (Services/Traps).
Config.TrapLines = {
	{ kind = "jump", text = "Прыгайте! Пол — это желе!", voice = "Jump! The floor is jelly!" },
	{
		kind = "jump",
		text = "Прыжок на счёт три! Раз, два, три!",
		voice = "Jump on three! One, two, three!",
	},
	{
		kind = "move",
		text = "Бегите! Быстро, все в угол!",
		voice = "Run! Everyone to the corner, quick!",
	},
	{
		kind = "move",
		text = "Шаг вперёд, кто самый смелый!",
		voice = "Step forward if you are brave!",
	},
	{
		kind = "chat",
		text = "Напишите в чат своё любимое слово!",
		voice = "Type your favourite word in the chat!",
	},
	{
		kind = "chat",
		text = "Кто меня слышит — напишите «я»!",
		voice = "If you can hear me, type me in the chat!",
	},
	{ kind = "tile", text = "Встаньте на красные плитки!", voice = "Stand on the red tiles!" },
	{
		kind = "tile",
		text = "Красное — безопасно! Бегом на красное!",
		voice = "Red is safe! Run to the red tiles!",
	},
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
