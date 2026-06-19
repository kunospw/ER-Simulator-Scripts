-- PatientSpawner (Script) — ServerScriptService
-- CHANGE LOG (deterioration update):
--   - Added startDeteriorationLoop() per patient
--   - Vitals degrade over time based on DeteriorationRate attribute
--   - CorrectTriage re-evaluated via START on each tick
--   - Animation updated if GCS crosses threshold
--   - Client notified via VitalsUpdated remote if player is currently examining

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local SS         = game:GetService("ServerStorage")

local spawnRemote      = RS:WaitForChild("SpawnPatients")
local focusRemote      = RS:WaitForChild("FocusPatientCamera")
local showUIRemote     = RS:WaitForChild("ShowPatientUI")
local toggleRemote     = RS:WaitForChild("TogglePrompt")
local serverFullRemote = RS:WaitForChild("ServerFull")

-- NEW: notify client when vitals change while they're examining
local vitalsUpdatedRemote = RS:FindFirstChild("VitalsUpdated")
if not vitalsUpdatedRemote then
	vitalsUpdatedRemote = Instance.new("RemoteEvent")
	vitalsUpdatedRemote.Name = "VitalsUpdated"
	vitalsUpdatedRemote.Parent = RS
end

local ScenarioData     = require(RS:WaitForChild("ScenarioData"))
local PatientGenerator = require(RS:WaitForChild("PatientGenerator"))
local HospitalRegistry = require(SS:WaitForChild("HospitalRegistry"))

local patientCleared = SS:WaitForChild("PatientCleared")

-- ── Templates ─────────────────────────────────────────────────────────────────
local maleTemplates   = { SS:WaitForChild("PatientM1"),   SS:WaitForChild("PatientM2") }
local femaleTemplates = { SS:WaitForChild("PatientFem1"), SS:WaitForChild("PatientFem2") }

local function getTemplate(gender)
	if gender == "Perempuan" then
		return femaleTemplates[math.random(#femaleTemplates)]
	else
		return maleTemplates[math.random(#maleTemplates)]
	end
end

local spawnedPatients   = {}
local patientQueues     = {}
local promptConnections = {}

-- ── START re-evaluation ───────────────────────────────────────────────────────
local function applySTART(rr, crt, gcs)
	if rr == 0 then return "BLACK" end
	if rr > 30 then return "RED" end
	if crt == "Terlambat" then return "RED" end
	if gcs < 13 then return "RED" end
	return "YELLOW"
end

-- ── Animation ─────────────────────────────────────────────────────────────────
local function getAnimIdForGCS(gcs)
	if gcs <= 10 then
		return "rbxassetid://108659019409982"
	elseif gcs <= 14 then
		return "rbxassetid://114133933934433"
	else
		return "rbxassetid://108659019409982"
	end
end

local function applyPose(npc, pose, slotPosition)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid.PlatformStand = true
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then part.Anchored = false end
	end

	if pose == "Lying" then
		npc:PivotTo(CFrame.new(slotPosition) * CFrame.Angles(math.rad(90), 0, math.rad(90)))
	else
		npc:PivotTo(CFrame.new(slotPosition))
	end

	local anchor = Instance.new("Part")
	anchor.Size         = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.CanCollide   = false
	anchor.Anchored     = true
	anchor.CFrame       = npc:FindFirstChild("HumanoidRootPart").CFrame
	anchor.Parent       = workspace

	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if hrp then
		local weld = Instance.new("WeldConstraint")
		weld.Part0  = anchor
		weld.Part1  = hrp
		weld.Parent = anchor
	end
end

local function playPatientAnim(npc, gcs)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animId = getAnimIdForGCS(gcs)
	local anim = Instance.new("Animation")
	anim.AnimationId = animId

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Stop existing tracks first
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop()
	end

	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped   = true
	track:Play()
	return track
end

local function hideNameplate(npc)
	local hum = npc:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

-- ── Deterioration loop ────────────────────────────────────────────────────────
-- Called once per patient after spawn. Runs until triaged or destroyed.
-- interval = 60 / deteriorationRate (faster rate = shorter interval)
local function startDeteriorationLoop(npc, owner, scenarioMode)
	local rate = npc:GetAttribute("DeteriorationRate") or 0
	if rate <= 0 then return end                          -- GREEN / BLACK: skip
	if scenarioMode == "Training Mode" then return end    -- Training: skip

	local interval = math.floor(60 / rate)               -- seconds between ticks
	interval = math.clamp(interval, 30, 300)             -- floor 30s, cap 5min

	print(string.format("[Deterioration] Starting for %s | rate=%.1f | interval=%ds",
		npc.Name, rate, interval))

	task.spawn(function()
		while true do
			task.wait(interval)

			-- Stop if patient gone or already triaged
			if not npc or not npc.Parent then break end
			if npc:GetAttribute("Triaged") then break end

			-- Read current vitals from attributes
			local rrStr = npc:GetAttribute("Breathing") or "0x/mnt"
			local rr    = tonumber(rrStr:match("%d+")) or 0
			local gcs   = npc:GetAttribute("GCS") or 15
			local perf  = npc:GetAttribute("Perfusion") or "Normal"
			local hr    = npc:GetAttribute("HR") or 80
			local crt   = (perf == "Terlambat") and "Terlambat" or "Normal"

			-- Already BLACK: stop
			if rr == 0 and gcs <= 3 then break end

			-- Degrade vitals
			-- RR: +1 to +3 per tick
			local rrDelta = math.random(1, 3)
			rr = math.min(rr + rrDelta, 40)

			-- GCS: -1 per tick (sometimes -2 for high rate patients)
			local gcsDelta = rate >= 0.8 and math.random(1, 2) or 1
			gcs = math.max(gcs - gcsDelta, 3)

			-- HR: +3 to +8 per tick
			hr = math.min(hr + math.random(3, 8), 160)

			-- CRT: becomes Terlambat when GCS drops below 12 or RR > 28
			if gcs < 12 or rr > 28 then
				crt = "Terlambat"
			end

			-- Re-run START
			local newTriage = applySTART(rr, crt, gcs)

			-- Update NPC attributes
			npc:SetAttribute("Breathing", tostring(rr) .. "x/mnt")
			npc:SetAttribute("GCS",       gcs)
			npc:SetAttribute("HR",        hr)
			npc:SetAttribute("Perfusion", crt == "Terlambat" and "Terlambat" or "Normal")
			npc:SetAttribute("Mental",    gcs >= 13 and "Sadar" or "Terganggu")
			npc:SetAttribute("CorrectTriage", newTriage)

			-- Update animation if GCS crossed a threshold
			local prevAnimId = getAnimIdForGCS(gcs + gcsDelta) -- what it was before
			local newAnimId  = getAnimIdForGCS(gcs)
			if newAnimId ~= prevAnimId then
				playPatientAnim(npc, gcs)
			end

			-- Notify client if they're currently examining this patient
			if owner and owner.Parent then
				local patientId = npc:GetAttribute("PatientID")
				vitalsUpdatedRemote:FireClient(owner, patientId, {
					breathing = tostring(rr) .. "x/mnt",
					perfusion = crt == "Terlambat" and "Terlambat" or "Normal",
					mental    = gcs >= 13 and "Sadar" or "Terganggu",
					gcs       = gcs,
					hr        = hr,
				})
			end

			print(string.format("[Deterioration] %s → RR:%d GCS:%d CRT:%s Triage:%s",
				npc.Name, rr, gcs, crt, newTriage))
		end
	end)
end

-- ── Cleanup ───────────────────────────────────────────────────────────────────
local function cleanupPatients(player)
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

local function cleanupPlayer(player)
	HospitalRegistry.Release(player)
	cleanupPatients(player)
end

-- ── Spawn one patient ─────────────────────────────────────────────────────────
local function spawnOnePatient(player, patientData, slotIndex, beds, scenarioMode)
	local slot = beds[slotIndex]
	if not slot then return end

	local template = getTemplate(patientData.gender or "Laki-laki")
	local npc      = template:Clone()
	npc.Name       = patientData.name or ("Patient_" .. slotIndex)
	npc.Parent     = workspace

	npc:PivotTo(CFrame.new(slot.position) * CFrame.Angles(0, math.rad(slot.yRot), 0))

	npc:SetAttribute("PatientID",         patientData.id or string.format("P%03d", slotIndex))
	npc:SetAttribute("CorrectTriage",     patientData.correctTriage or "RED")
	npc:SetAttribute("TargetRoom",        patientData.targetRoom or "")
	npc:SetAttribute("Pose",              slot.pose)
	npc:SetAttribute("Diagnosis",         patientData.diagnosis or "")
	npc:SetAttribute("ConditionName",     patientData.conditionName or "")
	npc:SetAttribute("Complaint",         patientData.complaint or "Keluhan tidak tersedia.")
	npc:SetAttribute("SlotIndex",         slotIndex)
	npc:SetAttribute("SpawnTime",         os.clock())
	npc:SetAttribute("DeteriorationRate", patientData.deteriorationRate or 0)

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

	hideNameplate(npc)

	task.spawn(function()
		task.wait(0.5)
		applyPose(npc, slot.pose, slot.position)
		task.wait(0.2)

		local hrp = npc:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Anchored = false end

		local gcs = patientData.vitals and patientData.vitals.gcs or 15
		playPatientAnim(npc, gcs)

		task.wait(0.1)
		if hrp then hrp.Anchored = true end

		-- Start deterioration after pose + anim settled
		task.wait(1)
		startDeteriorationLoop(npc, player, scenarioMode or "")
	end)

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

			if not npc:GetAttribute("ExamineStarted") then
				npc:SetAttribute("ExamineStarted", true)
				npc:SetAttribute("SpawnTime", os.clock())
			end

			focusRemote:FireClient(player, npc)
			showUIRemote:FireClient(player, npc)
		end)
		table.insert(promptConnections[player], conn)
	end

	spawnedPatients[player][slotIndex] = npc
end

-- ── Expose spawnOnePatient untuk EndlessMode ──────────────────────────────────
local spawnOneBF = Instance.new("BindableFunction")
spawnOneBF.Name   = "SpawnOnePatient"
spawnOneBF.Parent = SS

spawnOneBF.OnInvoke = function(player, patientData, slotIndex, beds, scenarioMode)
	if not spawnedPatients[player] then
		spawnedPatients[player]   = {}
		promptConnections[player] = {}
	end
	spawnOnePatient(player, patientData, slotIndex, beds, scenarioMode)
end

-- ── Scenario spawn ────────────────────────────────────────────────────────────
local function spawnPatientsForScenario(player, scenarioId)
	local scenario = ScenarioData.GetScenario(scenarioId)
	if not scenario then
		warn("[PatientSpawner] Scenario not found:", scenarioId)
		return
	end

	local hospital = HospitalRegistry.GetByPlayer(player)
	if not hospital then
		warn("[PatientSpawner] No hospital found for", player.Name)
		serverFullRemote:FireClient(player)
		return
	end

	cleanupPatients(player)

	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(hospital.spawnPosition + Vector3.new(0, 3, 0))
		end
	end

	spawnedPatients[player]   = {}
	promptConnections[player] = {}

	local patients   = scenario.patients or {}
	local beds       = hospital.beds
	local maxSlots   = #beds
	local mode       = scenario.mode or ""

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
		spawnOnePatient(player, entry.data, entry.slotIndex, beds, mode)
	end

	local totalSpawned = #patients
	local sessionEvent = SS:FindFirstChild("PatientSessionStarted")
	if sessionEvent then
		sessionEvent:Fire(player, totalSpawned)
	end

	print(string.format("[PatientSpawner] Player %s → Hospital %d | Spawned %d/%d patients (queue: %d) | Mode: %s",
		player.Name, hospital.id, #firstWave, totalSpawned, #queue, mode))
end

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function getScenarioIdForPlayer(player)
	-- [FIX]: If they are in Multiplayer, randomly pull from the Endless Pool!
	if player:GetAttribute("InMultiplayer") then
		local SCENARIO_POOL = { "food_poisoning", "industrial_explosion", "mixed_acute" }
		return SCENARIO_POOL[math.random(#SCENARIO_POOL)]
	end

	return player:GetAttribute("CurrentScenarioId") or "food_poisoning"
end

local function getScenarioModeForPlayer(player)
	local sid = getScenarioIdForPlayer(player)
	local scenario = ScenarioData.GetScenario and nil -- don't re-generate
	-- Read mode from attribute set at session start
	return player:GetAttribute("CurrentScenarioMode") or ""
end

-- ── startMpSpawns ─────────────────────────────────────────────────────────────
local startMpSpawns = SS:FindFirstChild("StartMPSpawns")
if not startMpSpawns then
	startMpSpawns = Instance.new("BindableEvent")
	startMpSpawns.Name = "StartMPSpawns"
	startMpSpawns.Parent = SS
end

startMpSpawns.Event:Connect(function(player, hospitalId, slotIndex)
	if not spawnedPatients[player] then spawnedPatients[player] = {} end
	if not promptConnections[player] then promptConnections[player] = {} end

	local hospital = HospitalRegistry.Hospitals[hospitalId]
	if hospital then
		local randomPatient = PatientGenerator.GenerateOne(getScenarioIdForPlayer(player))
		spawnOnePatient(player, randomPatient, slotIndex, hospital.beds, getScenarioModeForPlayer(player))
		player:SetAttribute("PatientsRemaining",
			(player:GetAttribute("PatientsRemaining") or 0) + 1)
	else
		warn("[PatientSpawner] Invalid Hospital ID:", hospitalId)
	end
end)

-- ── cleanupMpSpawns ───────────────────────────────────────────────────────────
local cleanupMpSpawns = SS:FindFirstChild("CleanupMPSpawns")
if not cleanupMpSpawns then
	cleanupMpSpawns = Instance.new("BindableEvent")
	cleanupMpSpawns.Name = "CleanupMPSpawns"
	cleanupMpSpawns.Parent = SS
end

cleanupMpSpawns.Event:Connect(function(player)
	cleanupPatients(player)
end)

-- ── IoT Add Patient ───────────────────────────────────────────────────────────
local iotAddPatient = SS:FindFirstChild("IoTAddPatient")
if not iotAddPatient then
	iotAddPatient = Instance.new("BindableEvent")
	iotAddPatient.Name = "IoTAddPatient"
	iotAddPatient.Parent = SS
end

iotAddPatient.Event:Connect(function(player)
	if not spawnedPatients[player] then return end

	local hId = player:GetAttribute("AssignedHospitalId")
	local hospital = HospitalRegistry.Hospitals[hId]
	if not hospital then return end

	local emptySlot = nil
	for i = 1, #hospital.beds do
		if not spawnedPatients[player][i] then
			emptySlot = i
			break
		end
	end

	if emptySlot then
		local randomPatient = PatientGenerator.GenerateOne(getScenarioIdForPlayer(player))
		spawnOnePatient(player, randomPatient, emptySlot, hospital.beds, getScenarioModeForPlayer(player))
		player:SetAttribute("PatientsRemaining",
			(player:GetAttribute("PatientsRemaining") or 0) + 1)
		print("[IoT] Added patient to slot", emptySlot, "for", player.Name)
	else
		if not patientQueues[player] then patientQueues[player] = {} end
		table.insert(patientQueues[player], PatientGenerator.GenerateOne(getScenarioIdForPlayer(player)))
		player:SetAttribute("PatientsRemaining",
			(player:GetAttribute("PatientsRemaining") or 0) + 1)
		print("[IoT] All slots full, queued patient for", player.Name)
	end
end)

-- ── IoT Remove Patient ────────────────────────────────────────────────────────
game:GetService("Players").PlayerAdded:Connect(function() end)

local function handleRemovePatient(player)
	local hId = player:GetAttribute("AssignedHospitalId")
	local hospital = hId and HospitalRegistry.Hospitals[hId]
	if not hospital then return end

	if patientQueues[player] and #patientQueues[player] > 0 then
		table.remove(patientQueues[player], #patientQueues[player])
		player:SetAttribute("PatientsRemaining",
			math.max(0, (player:GetAttribute("PatientsRemaining") or 1) - 1))
		print("[IoT] Removed last queued patient for", player.Name)
		return
	end

	if not spawnedPatients[player] then return end

	for i = #hospital.beds, 1, -1 do
		local npc = spawnedPatients[player][i]
		if npc and npc.Parent and not npc:GetAttribute("Triaged") then
			npc:Destroy()
			spawnedPatients[player][i] = nil
			player:SetAttribute("PatientsRemaining",
				math.max(0, (player:GetAttribute("PatientsRemaining") or 1) - 1))
			print("[IoT] Removed spawned patient from slot", i, "for", player.Name)
			return
		end
	end

	print("[IoT] No removable patient found for", player.Name)
end

game:GetService("Players").PlayerAdded:Connect(function(player)
	player:GetAttributeChangedSignal("IoTRemovePatient"):Connect(function()
		if player:GetAttribute("IoTRemovePatient") then
			player:SetAttribute("IoTRemovePatient", false)
			handleRemovePatient(player)
		end
	end)
end)

-- ── patientCleared ────────────────────────────────────────────────────────────
patientCleared.Event:Connect(function(player, slotIndex)
	if player:GetAttribute("InEndless") then return end
	if player:GetAttribute("InMultiplayer") then
		task.wait(1.2)
		local hId = player:GetAttribute("AssignedHospitalId")
		local hospital = HospitalRegistry.Hospitals[hId]
		if hospital then
			local randomPatient = PatientGenerator.GenerateOne(getScenarioIdForPlayer(player))
			spawnOnePatient(player, randomPatient, slotIndex, hospital.beds, getScenarioModeForPlayer(player))
		end
		return
	end

	local hospital = HospitalRegistry.GetByPlayer(player)
	if not hospital then return end

	local queue = patientQueues[player]
	if not queue or #queue == 0 then return end

	task.wait(1.2)
	local nextPatient = table.remove(queue, 1)
	spawnOnePatient(player, nextPatient, slotIndex, hospital.beds, getScenarioModeForPlayer(player))
end)

-- ── toggleRemote ──────────────────────────────────────────────────────────────
toggleRemote.OnServerEvent:Connect(function(player, state)
	if not spawnedPatients[player] then return end
	for _, npc in pairs(spawnedPatients[player]) do
		local head = npc and npc:FindFirstChild("Head")
		if head then
			local prompt = head:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				local isTriaged = npc:GetAttribute("Triaged")
				if isTriaged then
					prompt.Enabled = false
				else
					prompt.Enabled = state
				end
			end
		end
	end
end)

spawnRemote.OnServerEvent:Connect(function(player, scenarioId)
	if scenarioId == "endless" then
		local hospital = HospitalRegistry.GetByPlayer(player)
		if not hospital then return end
		spawnedPatients[player]   = {}
		promptConnections[player] = {}
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.CFrame = CFrame.new(hospital.spawnPosition + Vector3.new(0, 3, 0))
			end
		end
		local EndlessMode = require(game:GetService("ServerScriptService"):WaitForChild("EndlessMode"))
		EndlessMode.Start(player)
		return
	end
	spawnPatientsForScenario(player, scenarioId)
end)

Players.PlayerRemoving:Connect(function(player)
	cleanupPlayer(player)
end)
