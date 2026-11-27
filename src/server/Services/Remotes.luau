-- Все RemoteEvent создаёт сервер. Клиент ждёт их через ReplicatedStorage:WaitForChild("Remotes").
--   Announce   S→C  (text: string, isAISays: boolean, voice: string?) — фраза ведущего; voice (англ.) клиент озвучивает
--   State      S→C  (state: {phase, timeLeft, alive, round, goal?, threat?})
--   AskWord    S→C  (seconds: number) — только победителю
--   SubmitWord C→S  (word: string)    — валидируется в WordService
--   Push       C→S  ()                — толчок в цели push; цель выбирает сервер (Goals.push)
--   Vfx        S→C  (kind, pos, color?) — короткий эффект, рисует client/Vfx (Services/Vfx.burst)
--   BuyTrail   C→S  (id: string)      — купить/надеть/снять след за монеты (Services/Cosmetics)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	return r
end

local Remotes = {
	Announce = remote("Announce"),
	State = remote("State"),
	AskWord = remote("AskWord"),
	SubmitWord = remote("SubmitWord"),
	Push = remote("Push"),
	Vfx = remote("Vfx"),
	BuyTrail = remote("BuyTrail"),
}

folder.Parent = ReplicatedStorage

return Remotes
