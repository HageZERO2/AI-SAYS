-- Фоновая очередь запекания для больших партий: выполнить в Studio (Edit) через MCP, подставив QUEUE
-- (готовую строку печатает `python tools/bake/status.py 1000`). Возвращается сразу, работа идёт дальше сама.
-- Темп — волна из 6 слов не чаще раза в 36 с (~10/мин при лимите GenerationService ~12/мин).
-- Упавшее слово уходит в конец очереди, после 3 повторов — в _G.bake.fails. Прогресс: _G.bake; стоп: _G.bake.stop = true.

local QUEUE: { { string } } = {} -- {{"слово", "w083"}, ...}
local WAVE, PERIOD, RETRIES = 6, 36, 3

local run = require(game:GetService("ServerStorage").BakeTool)
_G.bake = { done = 0, fails = {}, retries = {}, stop = false, left = #QUEUE, running = true }
task.spawn(function()
	while #QUEUE > 0 and not _G.bake.stop do
		local wave = {}
		for _ = 1, math.min(WAVE, #QUEUE) do
			table.insert(wave, table.remove(QUEUE, 1))
		end
		local t0 = os.clock()
		local res = run(wave)
		for _, j in wave do
			if res:find(j[2] .. "%(") then
				_G.bake.retries[j[2]] = (_G.bake.retries[j[2]] or 0) + 1
				if _G.bake.retries[j[2]] <= RETRIES then
					table.insert(QUEUE, j)
				else
					_G.bake.fails[j[2]] = j[1] .. ": " .. (res:match(j[2] .. "%(.-%): ([^\n]*)") or "?")
				end
			else
				_G.bake.done += 1
			end
		end
		_G.bake.left = #QUEUE
		local spent = os.clock() - t0
		if spent < PERIOD then
			task.wait(PERIOD - spent)
		end
	end
	_G.bake.running = false
end)
return `queue started: {#QUEUE} jobs`
