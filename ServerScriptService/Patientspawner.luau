-- PatientSpawner (Script)
-- ServerScriptService

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")

local spawnRemote   = RS:WaitForChild("SpawnPatients")
local focusRemote   = RS:WaitForChild("FocusPatientCamera")
local showUIRemote  = RS:WaitForChild("ShowPatientUI")
local toggleRemote  = RS:WaitForChild("TogglePrompt")
local ScenarioData  = require(RS:WaitForChild("ScenarioData"))

-- ── Slot definitions ──────────────────────────────────────────────────────────
local PatientSlots = {
	{ position = Vector3.new(308.388, 3.47,  57.144), yRot = 180, pose = "Lying"    },
	{ position = Vector3.new(308.388, 3.47,  71.296), yRot = 180, pose = "Lying"    },
	{ position = Vector3.new(308.388, 3.47,  43.606), yRot = 180, pose = "Lying"    },
	{ position = Vector3.new(314.761, 3.009, 78.196), yRot = 180, pose = "Standing" },
	{ position = Vector3.new(337.527, 3.213, 65.754), yRot = -90, pose = "Standing" },
}

local ServerStorage  = game:GetService("ServerStorage")

local patientTemplate = workspace:FindFirstChild("Patient")
if not patientTemplate then error("[PatientSpawner] No Patient template found in Workspace!") end

-- Move to ServerStorage immediately — clients can never see ServerStorage
-- so the template becomes invisible without any transparency tricks
patientTemplate.Parent = ServerStorage

-- ── State ─────────────────────────────────────────────────────────────────────
local spawnedPatients   = {}  -- [player] = { npcModel, ... }
local promptConnections = {}  -- [player] = { RBXScriptConnection, ... }

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function applyPose(npc, pose, slotPosition)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local torso    = npc:FindFirstChild("Torso")
	if not humanoid or not torso then return end

	if pose == "Lying" then
		humanoid.PlatformStand = true
		-- Anchor all BaseParts so nothing drifts
		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		-- Move the whole model at once using PivotTo
		npc:PivotTo(
			CFrame.new(slotPosition) * CFrame.Angles(math.rad(90), 0, math.rad(90))
		)
	else
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
	end
end

local function cleanupPlayer(player)
	if promptConnections[player] then
		for _, conn in ipairs(promptConnections[player]) do
			conn:Disconnect()
		end
		promptConnections[player] = nil
	end
	if spawnedPatients[player] then
		for _, model in ipairs(spawnedPatients[player]) do
			if model and model.Parent then model:Destroy() end
		end
		spawnedPatients[player] = nil
	end
end

-- ── Core spawn function ───────────────────────────────────────────────────────
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

	for i, patientData in ipairs(patients) do
		local slot = PatientSlots[i]
		if not slot then
			warn("[PatientSpawner] No slot for index", i)
			break
		end

		-- Clone and place
		local npc  = patientTemplate:Clone()
		npc.Name   = patientData.name or ("Patient_" .. i)
		npc.Parent = workspace

		local cf = CFrame.new(slot.position) * CFrame.Angles(0, math.rad(slot.yRot), 0)
		npc:PivotTo(cf)

		-- Set attributes
		npc:SetAttribute("PatientID",     patientData.id or string.format("P%03d", i))
		npc:SetAttribute("CorrectTriage", patientData.correctTriage or "RED")
		npc:SetAttribute("TargetRoom",    patientData.targetRoom or "")
		npc:SetAttribute("Pose",          slot.pose)
		npc:SetAttribute("Diagnosis",     patientData.diagnosis or "")
		npc:SetAttribute("Complaint",     patientData.complaint or "Keluhan tidak tersedia.") -- tambah ini

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

		-- Apply pose after brief wait for the character rig to settle
		task.spawn(function()
			task.wait(0.5)
			applyPose(npc, slot.pose, slot.position)
		end)

		-- ── Create ProximityPrompt ────────────────────────────────────────────
		local head = npc:FindFirstChild("Head")
		if head then
			local prompt                 = Instance.new("ProximityPrompt")
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

		table.insert(spawnedPatients[player], npc)
	end

	print("[PatientSpawner] Spawned", #spawnedPatients[player], "patients for:", scenarioId)
	local totalSpawned = #spawnedPatients[player]
	local sessionEvent = ServerStorage:FindFirstChild("PatientSessionStarted")
	if sessionEvent then
		sessionEvent:Fire(player, totalSpawned)
	else
		warn("[PatientSpawner] PatientSessionStarted BindableEvent not found in ServerStorage")
	end
end

-- ── TogglePrompt handler ──────────────────────────────────────────────────────
toggleRemote.OnServerEvent:Connect(function(player, state)
	if not spawnedPatients[player] then return end
	for _, npc in ipairs(spawnedPatients[player]) do
		local head = npc:FindFirstChild("Head")
		if head then
			local prompt = head:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt.Enabled = state end
		end
	end
end)

-- ── Remote listeners ──────────────────────────────────────────────────────────
spawnRemote.OnServerEvent:Connect(function(player, scenarioId)
	spawnPatientsForScenario(player, scenarioId)
end)

Players.PlayerRemoving:Connect(function(player)
	cleanupPlayer(player)
end)