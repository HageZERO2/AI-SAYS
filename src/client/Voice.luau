-- Голос ведущего через Text-to-Speech (AudioTextToSpeech → Wire → AudioDeviceOutput).
-- API новый: если на устройстве не поддерживается — молча работаем только текстом.

local Voice = {}

local VOICE_ID = "1" -- 10 голосов; смена голоса — платная фишка (см. docs/DESIGN.md)

local tts: Instance?
local warned = false
local ok = pcall(function()
	local t: any = Instance.new("AudioTextToSpeech" :: any)
	t.VoiceId = VOICE_ID
	local out = Instance.new("AudioDeviceOutput" :: any)
	local wire = Instance.new("Wire")
	wire.SourceInstance = t
	wire.TargetInstance = out
	out.Parent = t
	wire.Parent = t
	t.Parent = script
	tts = t
end)
if not ok then
	warn("[Voice] TTS недоступен, только текст")
end

function Voice.say(text: string)
	if not tts then
		return
	end
	-- У AudioTextToSpeech нет Stop(): Pause + сброс позиции. LoadAsync ждёт синтеза, поэтому в отдельном потоке.
	task.spawn(function()
		local said, err = pcall(function()
			local t = tts :: any
			t:Pause()
			t.Text = text
			t.TimePosition = 0
			-- Русский TTS Roblox не поддерживает: LoadAsync вернёт Failure, тогда только текст
			if t:LoadAsync() ~= Enum.AssetFetchStatus.Success then
				error("TTS не синтезировал фразу (язык не поддерживается?)")
			end
			t:Play()
		end)
		if not said and not warned then
			warned = true
			warn("[Voice] не удалось сказать:", err)
		end
	end)
end

return Voice
