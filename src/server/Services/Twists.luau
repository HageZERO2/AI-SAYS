-- Подвохи: меняют правила раунда поверх цели и угрозы. Каждый: start(ctx) -> stop().
-- Новый подвох = функция здесь + имя в Config.Twists + описание в Config.TwistNames/TwistHints.

local PlayersService = game:GetService("Players")

local Arena = require(script.Parent.Arena)
local Roster = require(script.Parent.Players)
local Vfx = require(script.Parent.Vfx)

type Ctx = { word: string, duration: number, rng: Random }

local Twists = {}

function Twists.none(_ctx: Ctx): () -> ()
	return function() end
end

-- Управление наоборот: сервер ставит атрибут, клиент (init.client) переворачивает направление движения.
-- shortcut: читер может игнорировать атрибут; вред только себе (подвох не наказывает напрямую).
function Twists.reverse(_ctx: Ctx): () -> ()
	for _, p in Roster.alive() do
		p:SetAttribute("Reversed", true)
	end
	return function()
		for _, p in PlayersService:GetPlayers() do
			p:SetAttribute("Reversed", nil)
		end
	end
end

-- Все крошечные: персонажи в 0.4 размера (прыжок и шаг меньше, предметы и угрозы — огромные).
local TINY = 0.4
function Twists.tiny(_ctx: Ctx): () -> ()
	local scaled: { Model } = {}
	for _, p in Roster.alive() do
		local char = p.Character
		if char then
			char:ScaleTo(TINY)
			table.insert(scaled, char)
		end
	end
	return function()
		for _, char in scaled do
			if char.Parent then
				char:ScaleTo(1)
			end
		end
	end
end

-- Личная угроза лидеру: охотник гонится только за игроком с наибольшим числом побед (ничья — случайный из лучших).
function Twists.leader(ctx: Ctx): () -> ()
	local best, top = -1, {}
	for _, p in Roster.alive() do
		local wins = p:GetAttribute("Wins") or 0
		if wins > best then
			best, top = wins, { p }
		elseif wins == best then
			table.insert(top, p)
		end
	end
	local target: Player? = top[ctx.rng:NextInteger(1, math.max(1, #top))]
	if not target then
		return function() end
	end
	local shields = target:GetAttribute("Shields") or 0
	if shields > 0 then -- купленный щит: охоты в этот раунд нет
		target:SetAttribute("Shields", shields - 1)
		return function() end
	end
	target:SetAttribute("Hunted", true)
	local hunter = Instance.new("Part")
	hunter.Name = "Hunter"
	hunter.Shape = Enum.PartType.Ball
	hunter.Size = Vector3.one * 4
	hunter.Anchored = true
	hunter.CanCollide = false
	hunter.Material = Enum.Material.Neon
	hunter.Color = Color3.fromRGB(255, 40, 60)
	hunter.Position = Vector3.new(0, Arena.FloorY + 3, -Arena.Size / 2)
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(200, 40)
	tag.StudsOffset = Vector3.new(0, 4, 0)
	tag.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = `охотится на {target.DisplayName}`
	label.Parent = tag
	tag.Parent = hunter
	Vfx.attach(hunter, "flame")
	hunter.Parent = Arena.folder()

	local active = true
	task.spawn(function()
		local last = os.clock()
		while active and Roster.isAlive(target) do
			local now = os.clock()
			local dt = now - last
			last = now
			local r = Roster.root(target)
			if r then
				local flat = (r.Position - hunter.Position) * Vector3.new(1, 0, 1)
				if flat.Magnitude < 4 then
					Roster.eliminate(target, "leader")
				elseif flat.Magnitude > 0.1 then
					hunter.Position += flat.Unit * math.min(13 * dt, flat.Magnitude) -- игрок бегает 16: можно убежать
				end
			end
			task.wait(0.05)
		end
	end)
	return function()
		active = false
		target:SetAttribute("Hunted", nil)
		hunter:Destroy()
	end
end

return Twists
