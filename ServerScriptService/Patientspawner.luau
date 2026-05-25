-- PatientSpawner (Script) — ServerScriptService
local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local SS         = game:GetService("ServerStorage")

local spawnRemote   = RS:WaitForChild("SpawnPatients")
local focusRemote   = RS:WaitForChild("FocusPatientCamera")
local showUIRemote  = RS:WaitForChild("ShowPatientUI")
local toggleRemote  = RS:WaitForChild("TogglePrompt")
local ScenarioData  = require(RS:WaitForChild("ScenarioData"))

local patientCleared = SS:WaitForChild("PatientCleared")

local PatientSlots = {
	{ position = Vector3.new(308.388, 3.47,  57.144), yRot = 180, pose = "Lying" },
	{ position = Vector3.new(308.388, 3.47,  71.296), yRot = 180, pose = "Lying" },
	{ position = Vector3.new(308.388, 3.47,  43.606), yRot = 180, pose = "Lying" },
	{ position = Vector3.new(308.388, 4.197, 28.911), yRot = 180, pose = "Lying" },
}

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

	local animId
	if gcs <= 10 then
		animId = "rbxassetid://108659019409982"
	elseif gcs <= 14 then
		animId = "rbxassetid://114133933934433"
	else
		animId = "rbxassetid://108659019409982"
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
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

local function spawnOnePatient(player, patientData, slotIndex)
	local slot = PatientSlots[slotIndex]
	if not slot then return end

	local template = getTemplate(patientData.gender or "Laki-laki")
	local npc      = template:Clone()
	npc.Name       = patientData.name or ("Patient_" .. slotIndex)
	npc.Parent     = workspace

	npc:PivotTo(CFrame.new(slot.position) * CFrame.Angles(0, math.rad(slot.yRot), 0))

	npc:SetAttribute("PatientID",     patientData.id or string.format("P%03d", slotIndex))
	npc:SetAttribute("CorrectTriage", patientData.correctTriage or "RED")
	npc:SetAttribute("TargetRoom",    patientData.targetRoom or "")
	npc:SetAttribute("Pose",          slot.pose)
	npc:SetAttribute("Diagnosis",     patientData.diagnosis or "")
	npc:SetAttribute("Complaint",     patientData.complaint or "Keluhan tidak tersedia.")
	npc:SetAttribute("SlotIndex",     slotIndex)
	npc:SetAttribute("SpawnTime",     os.clock()) -- ← timestamp saat patient spawn

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
			focusRemote:FireClient(player, npc)
			showUIRemote:FireClient(player, npc)
		end)
		table.insert(promptConnections[player], conn)
	end

	spawnedPatients[player][slotIndex] = npc
end

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
	local maxSlots = #PatientSlots

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

	local totalSpawned = #patients
	local sessionEvent = SS:FindFirstChild("PatientSessionStarted")
	if sessionEvent then
		sessionEvent:Fire(player, totalSpawned)
	end

	print(string.format("[PatientSpawner] Spawned %d / %d patients (queue: %d)",
		#firstWave, totalSpawned, #queue))
end

patientCleared.Event:Connect(function(player, slotIndex)
	local queue = patientQueues[player]
	if not queue or #queue == 0 then return end
	task.wait(1.2)
	local nextPatient = table.remove(queue, 1)
	spawnOnePatient(player, nextPatient, slotIndex)
	print(string.format("[PatientSpawner] Spawned queued patient '%s' into slot %d (%d left in queue)",
		nextPatient.name or "?", slotIndex, #queue))
end)

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
	spawnPatientsForScenario(player, scenarioId)
end)

Players.PlayerRemoving:Connect(function(player)
	cleanupPlayer(player)
end)
