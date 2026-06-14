-- EndlessMode (ModuleScript) — ServerScriptService
-- Compatible dengan PatientSpawner versi deterioration update

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local PatientGenerator = require(RS:WaitForChild("PatientGenerator"))
local HospitalRegistry = require(SS:WaitForChild("HospitalRegistry"))
local patientCleared   = SS:WaitForChild("PatientCleared")

local EndlessMode = {}

-- ── Difficulty tiers ──────────────────────────────────────────────────────────
local TIERS = {
	{ threshold = 0,  spawnDelay = 1.2 },
	{ threshold = 5,  spawnDelay = 0.8 },
	{ threshold = 10, spawnDelay = 0.5 },
}

local function getDelay(triageCount)
	local delay = TIERS[1].spawnDelay
	for _, tier in ipairs(TIERS) do
		if triageCount >= tier.threshold then
			delay = tier.spawnDelay
		end
	end
	return delay
end

-- ── State per player ──────────────────────────────────────────────────────────
local endlessState = {}  -- [player] = { running, triageCount, connection }

-- ── BindableFunction untuk expose spawnOnePatient ─────────────────────────────
-- Tambahkan ini di PatientSpawner (lihat catatan di bawah)
local spawnOneBF = SS:FindFirstChild("SpawnOnePatient", 5)

local function doSpawn(player, slotIndex)
	if not spawnOneBF then
		warn("[EndlessMode] SpawnOnePatient BindableFunction not found in SS")
		return
	end
	local hospital = HospitalRegistry.GetByPlayer(player)
	if not hospital then return end

	local SCENARIO_POOL = { "food_poisoning", "industrial_explosion", "mixed_acute" }
	local scenarioId = SCENARIO_POOL[math.random(#SCENARIO_POOL)]
	local scenarioMode = player:GetAttribute("CurrentScenarioMode") or ""
	local patientData = PatientGenerator.GenerateOne(scenarioId)

	spawnOneBF:Invoke(player, patientData, slotIndex, hospital.beds, scenarioMode)
end

function EndlessMode.Start(player)
	if endlessState[player] and endlessState[player].running then return end

	local hospital = HospitalRegistry.GetByPlayer(player)
	if not hospital then
		warn("[EndlessMode] No hospital assigned for", player.Name)
		return
	end

	player:SetAttribute("InEndless", true)

	local state = {
		running     = true,
		triageCount = 0,
		connection  = nil,
	}
	endlessState[player] = state

	-- Fill semua slot langsung saat start
	for i = 1, #hospital.beds do
		task.spawn(function()
			task.wait((i - 1) * 0.3)
			if state.running then
				doSpawn(player, i)
			end
		end)
	end

	-- Hook ke patientCleared yang sudah ada
	state.connection = patientCleared.Event:Connect(function(clearedPlayer, slotIndex)
		if clearedPlayer ~= player then return end
		if not state.running then return end
		-- Jangan jalan kalau bukan endless (biar nggak bentrok sama normal mode)
		if not player:GetAttribute("InEndless") then return end

		state.triageCount += 1
		local delay = getDelay(state.triageCount)
		task.wait(delay)

		if state.running then
			doSpawn(player, slotIndex)
		end
	end)

	print(string.format("[EndlessMode] Started for %s", player.Name))
end

function EndlessMode.Stop(player)
	local state = endlessState[player]
	if not state then return end

	state.running = false
	if state.connection then
		state.connection:Disconnect()
		state.connection = nil
	end
	player:SetAttribute("InEndless", false)

	print(string.format("[EndlessMode] Stopped for %s — total triaged: %d",
		player.Name, state.triageCount or 0))

	endlessState[player] = nil
end

function EndlessMode.GetTriageCount(player)
	local state = endlessState[player]
	return state and state.triageCount or 0
end

return EndlessMode