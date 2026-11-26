-- Сохранение монет и побед (атрибуты Coins/Wins игрока ↔ DataStore) и чеков покупок.
-- Замок сессии: запись {Lock = {Job, Time}} — данные пишет только сервер, который их загрузил.
-- Не загрузились (нет доступа к DataStore, сбой) — играем с нулями и НЕ сохраняем, чтобы не затереть настоящие данные.

local DataStoreService = game:GetService("DataStoreService")
local PlayersService = game:GetService("Players")

local Data = {}

local store = DataStoreService:GetDataStore("PlayerData_v1")
local LOCK_TTL = 15 * 60 -- сек: замок упавшего сервера считается снятым
local AUTOSAVE = 60
local KEEP_RECEIPTS = 50 -- последние чеки покупок (защита от двойной выдачи)

type Record = { Coins: number, Wins: number, Receipts: { string }, Lock: { Job: string, Time: number }? }

local loaded: { [Player]: Record } = {}

local function key(p: Player): string
	return `u_{p.UserId}`
end

local function lockedByOther(rec: Record): boolean
	return rec.Lock ~= nil and rec.Lock.Job ~= game.JobId and os.time() - rec.Lock.Time < LOCK_TTL
end

-- nil, "locked" — данные открыты на другом сервере; nil, ошибка — DataStore недоступен.
local function load(p: Player): (Record?, string?)
	local err = "?"
	for attempt = 1, 4 do
		local wasLocked = false
		local ok, result = pcall(store.UpdateAsync, store, key(p), function(old: Record?): Record?
			local rec = old or { Coins = 0, Wins = 0, Receipts = {} }
			if lockedByOther(rec) then
				wasLocked = true
				return nil -- не трогаем
			end
			rec.Lock = { Job = game.JobId, Time = os.time() }
			return rec
		end)
		if ok and result then
			return result
		end
		err = if wasLocked then "locked" else tostring(result)
		task.wait(attempt * 2)
	end
	return nil, err
end

-- Пишет текущие атрибуты. release — снять замок (игрок ушёл). receipt — запомнить чек покупки.
local function save(p: Player, release: boolean, receipt: string?): boolean
	if not loaded[p] then
		return false
	end
	local ok, err = pcall(store.UpdateAsync, store, key(p), function(old: Record?): Record?
		if old and lockedByOther(old) then
			return nil -- данные уже у другого сервера — не перезаписываем
		end
		local rec = old or { Coins = 0, Wins = 0, Receipts = {} }
		rec.Coins = p:GetAttribute("Coins") or rec.Coins
		rec.Wins = p:GetAttribute("Wins") or rec.Wins
		if receipt and not table.find(rec.Receipts, receipt) then
			table.insert(rec.Receipts, receipt)
			while #rec.Receipts > KEEP_RECEIPTS do
				table.remove(rec.Receipts, 1)
			end
		end
		rec.Lock = if release then nil else { Job = game.JobId, Time = os.time() }
		loaded[p] = rec
		return rec
	end)
	if not ok then
		warn("[Data] не сохранилось", p.Name, err)
	end
	return ok
end

-- Чек уже выдан? (покупки: ProcessReceipt может прийти повторно)
function Data.hasReceipt(p: Player, receipt: string): boolean
	local rec = loaded[p]
	return rec ~= nil and table.find(rec.Receipts, receipt) ~= nil
end

-- Записать чек вместе с текущими монетами/победами; true — записано, можно подтверждать покупку.
function Data.recordReceipt(p: Player, receipt: string): boolean
	return save(p, false, receipt)
end

function Data.isLoaded(p: Player): boolean
	return loaded[p] ~= nil
end

local function leaderstats(p: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Wins", "Coins" } do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Value = p:GetAttribute(name) or 0
		p:GetAttributeChangedSignal(name):Connect(function()
			v.Value = p:GetAttribute(name) or 0
		end)
		v.Parent = stats
	end
	stats.Parent = p
end

local function onJoin(p: Player)
	p:SetAttribute("Coins", 0)
	leaderstats(p)
	local rec, err = load(p)
	if not p.Parent then
		return -- ушёл, пока грузили
	end
	if not rec then
		if err == "locked" then
			p:Kick(
				"Твои данные ещё сохраняются на другом сервере. Зайди через минуту!"
			)
		else
			warn("[Data] не загрузилось, играем без сохранения:", p.Name, err)
		end
		return
	end
	loaded[p] = rec
	p:SetAttribute("Coins", rec.Coins)
	p:SetAttribute("Wins", rec.Wins)
end

function Data.init()
	PlayersService.PlayerAdded:Connect(onJoin)
	for _, p in PlayersService:GetPlayers() do
		task.spawn(onJoin, p)
	end
	PlayersService.PlayerRemoving:Connect(function(p)
		save(p, true)
		loaded[p] = nil
	end)
	game:BindToClose(function()
		local left = 0
		for p in loaded do
			left += 1
			task.spawn(function()
				save(p, true)
				left -= 1
			end)
		end
		while left > 0 do
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for p in loaded do
				task.spawn(save, p, false)
			end
		end
	end)
end

return Data
