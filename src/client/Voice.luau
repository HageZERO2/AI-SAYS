-- Голос ведущего через Text-to-Speech (AudioTextToSpeech → Wire → AudioDeviceOutput).
-- API новый: если на устройстве не поддерживается — молча работаем только текстом.

local Voice = {}

local VOICE_ID = "1" -- 10 голосов; смена голоса — платная фишка (см. docs/DESIGN.md)

local tts: Instance?
local ok = pcall(function()
	local t = Instance.new("AudioTextToSpeech" :: any)
	;(t :: any).VoiceId = VOICE_ID
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
	pcall(function()
		local t = tts :: any
		t:Stop()
		t.Text = text
		t:Play()
	end)
end

return Voice
