-- Точка входа сервера. Вся логика — в Services/*, здесь только порядок запуска.

local RunService = game:GetService("RunService")

local Services = script.Services

if RunService:IsStudio() then
	require(script.Tests["RoundLogic.spec"])()
end

require(Services.Remotes) -- создать RemoteEvent до того, как клиенты их ждут
require(Services.Arena).build()
require(Services.Players).init()
require(Services.RoundService).run()
