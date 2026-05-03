-- PatientSpawner (Script) — ServerScriptService
-- CHANGES: queue system added, rest unchanged

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local SS         = game:GetService("ServerStorage")

local spawnRemote   = RS:WaitForChild("SpawnPatients")
local focusRemote   = RS:WaitForChild("FocusPatientCamera")
local showUIRemote  = RS:WaitForChild("ShowPatientUI")
local toggleRemote  = RS:WaitForChild("TogglePrompt")
local ScenarioData  = require(RS:WaitForChild("ScenarioData"))

-- NEW: BindableEvent from TriageManager telling us a slot just freed up
local patientCleared = SS:WaitForChild("PatientCleared")

local PatientSlots = {
	{ position = Vector3.new(308.388, 3.47,  57.144), yRot = 180, pose = "Lying"    },
	{ position = Vector3.new(308.388, 3.47,  71.296), yRot = 180, pose = "Lying"    },
	{ position = Vector3.new(308.388, 3.47,  43.606), yRot = 180, pose = "Lying"    }
}

local patientTemplate = workspace:FindFirstChild("Patient")
if not patientTemplate then error("[PatientSpawner] No Patient template in Workspace!") end
patientTemplate.Parent = SS

local spawnedPatients   = {}  -- [player] = { [slotIndex] = npcModel }
local patientQueues     = {}  -- [player] = { patientData, ... }  (remaining)
local promptConnections = {}  -- [player] = { RBXScriptConnection }

-- ── Helpers (unchanged) ───────────────────────────────────────────────────────
local function applyPose(npc, pose, slotPosition)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if pose == "Lying" then
		humanoid.PlatformStand = true
		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") then part.Anchored = true end
		end
		npc:PivotTo(CFrame.new(slotPosition) * CFrame.Angles(math.rad(90), 0, math.rad(90)))
	else
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") then part.Anchored = true end
		end
	end
end

local function cleanupPlayer(player)
	if promptConnections[player] then
		for _, conn in ipairs(promptConnections[player]) do conn:Disconnect() end
		promptConnections[player] = nil
	end
	if spawnedPatients[player] then
		for _, model in pairs(spawnedPatients[player]) do
			if model and model.Parent then model:Destroy() end
		end
		spawnedPatients[player] = nil
	end
	patientQueues[player] = nil
end

-- ── NEW: spawn a single patient into a specific slot ─────────────────────────
local function spawnOnePatient(player, patientData, slotIndex)
	local slot = PatientSlots[slotIndex]
	if not slot then return end

	local npc  = patientTemplate:Clone()
	npc.Name   = patientData.name or ("Patient_" .. slotIndex)
	npc.Parent = workspace

	npc:PivotTo(CFrame.new(slot.position) * CFrame.Angles(0, math.rad(slot.yRot), 0))

	npc:SetAttribute("PatientID",     patientData.id or string.format("P%03d", slotIndex))
	npc:SetAttribute("CorrectTriage", patientData.correctTriage or "RED")
	npc:SetAttribute("TargetRoom",    patientData.targetRoom or "")
	npc:SetAttribute("Pose",          slot.pose)
	npc:SetAttribute("Diagnosis",     patientData.diagnosis or "")
	npc:SetAttribute("Complaint",     patientData.complaint or "Keluhan tidak tersedia.")
	-- NEW: track which slot this NPC is in so TriageManager can report it back
	npc:SetAttribute("SlotIndex",     slotIndex)

	local vitals    = patientData.vitals or {}
	local crt       = vitals.crt or ""
	local normalCRT = (crt == "<2 detik" or crt == "≤2 detik")

	npc:SetAttribute("Breathing", tostring(vitals.rr  or 0) .. "x/mnt")
	npc:SetAttribute("Perfusion", normalCRT and "Normal" or "Terlambat")
	npc:SetAttribute("Mental",    (vitals.gcs or 15) >= 13 and "Sadar" or "Terganggu")
	npc:SetAttribute("GCS",       vitals.gcs  or 15)
	npc:SetAttribute("SpO2",      vitals.spo2 or 0)
	npc:SetAttribute("BP",        vitals.td   or "")
	npc:SetAttribute("HR",        vitals.nadi or 0)
	npc:SetAttribute("Triaged",   false)

	task.spawn(function()
		task.wait(0.5)
		applyPose(npc, slot.pose, slot.position)
	end)

	-- ProximityPrompt
	local head = npc:FindFirstChild("Head")
	if head then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText            = "Examine"
		prompt.ObjectText            = npc.Name
		prompt.HoldDuration          = 0
		prompt.MaxActivationDistance = 15
		prompt.RequiresLineOfSight   = false
		prompt.Parent                = head

		local conn = prompt.Triggered:Connect(function(triggeringPlayer)
			if triggeringPlayer ~= player then return end
			focusRemote:FireClient(player, npc)
			showUIRemote:FireClient(player, npc)
		end)
		table.insert(promptConnections[player], conn)
	end

	spawnedPatients[player][slotIndex] = npc
end

-- ── Core spawn (initial batch) ────────────────────────────────────────────────
local function spawnPatientsForScenario(player, scenarioId)
	local scenario = ScenarioData.GetScenario(scenarioId)
	if not scenario then
		warn("[PatientSpawner] Scenario not found:", scenarioId)
		return
	end

	cleanupPlayer(player)
	spawnedPatients[player]   = {}
	promptConnections[player] = {}

	local patients = scenario.patients or {}
	local maxSlots = #PatientSlots  -- 5

	-- Split into first wave vs queue
	local firstWave = {}
	local queue     = {}
	for i, pd in ipairs(patients) do
		if i <= maxSlots then
			table.insert(firstWave, { slotIndex = i, data = pd })
		else
			table.insert(queue, pd)
		end
	end
	patientQueues[player] = queue

	for _, entry in ipairs(firstWave) do
		spawnOnePatient(player, entry.data, entry.slotIndex)
	end

	-- Report total to TriageManager
	local totalSpawned = #patients  -- total in scenario, not just first wave
	local sessionEvent = SS:FindFirstChild("PatientSessionStarted")
	if sessionEvent then
		sessionEvent:Fire(player, totalSpawned)
	end

	print(string.format("[PatientSpawner] Spawned %d / %d patients (queue: %d)",
		#firstWave, totalSpawned, #queue))
end

-- ── NEW: slot freed — spawn next from queue ───────────────────────────────────
patientCleared.Event:Connect(function(player, slotIndex)
	local queue = patientQueues[player]
	if not queue or #queue == 0 then return end

	-- Small delay so the fade-out animation finishes before new patient appears
	task.wait(1.2)

	local nextPatient = table.remove(queue, 1)
	spawnOnePatient(player, nextPatient, slotIndex)
	print(string.format("[PatientSpawner] Spawned queued patient '%s' into slot %d (%d left in queue)",
		nextPatient.name or "?", slotIndex, #queue))
end)

-- ── TogglePrompt / remotes (unchanged) ───────────────────────────────────────
toggleRemote.OnServerEvent:Connect(function(player, state)
	if not spawnedPatients[player] then return end
	for _, npc in pairs(spawnedPatients[player]) do
		local head = npc and npc:FindFirstChild("Head")
		if head then
			local prompt = head:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt.Enabled = state end
		end
	end
end)

spawnRemote.OnServerEvent:Connect(function(player, scenarioId)
	spawnPatientsForScenario(player, scenarioId)
end)

Players.PlayerRemoving:Connect(function(player)
	cleanupPlayer(player)
end)