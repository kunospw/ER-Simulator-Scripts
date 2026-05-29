-- ServerScriptService > ScenarioManager (Script)
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local startRemote = RS:WaitForChild("StartCutscene")

local serverFullRemote = RS:FindFirstChild("ServerFull")
if not serverFullRemote then
	serverFullRemote = Instance.new("RemoteEvent")
	serverFullRemote.Name = "ServerFull"
	serverFullRemote.Parent = RS
end

local assignedHospitalRemote = RS:FindFirstChild("AssignedHospital")
if not assignedHospitalRemote then
	assignedHospitalRemote = Instance.new("RemoteEvent")
	assignedHospitalRemote.Name = "AssignedHospital"
	assignedHospitalRemote.Parent = RS
end

local HospitalRegistry = require(SS:WaitForChild("HospitalRegistry"))

local triggerRemote = RS:FindFirstChild("TriggerCinematic")
if not triggerRemote then
	triggerRemote = Instance.new("RemoteEvent")
	triggerRemote.Name = "TriggerCinematic"
	triggerRemote.Parent = RS
end

local hideNPCRemote = RS:FindFirstChild("HideCinematicNPCs")
if not hideNPCRemote then
	hideNPCRemote = Instance.new("RemoteEvent")
	hideNPCRemote.Name = "HideCinematicNPCs"
	hideNPCRemote.Parent = RS
end

-- ── Original CFrame recording ─────────────────────────────────────────────────
local originalCFrames = {}

local function recordOriginalCFrames()
	for i = 1, 4 do
		local folder = workspace:FindFirstChild("Hospital" .. i)
		if not folder then continue end

		originalCFrames[i] = {}
		local toRecord = {"StretcherCinematic", "Dummy", "Worker 1", "Worker 2"}
		for _, name in ipairs(toRecord) do
			local obj = folder:FindFirstChild(name)
			if not obj then continue end

			originalCFrames[i][name] = {}
			for _, part in ipairs(obj:GetDescendants()) do
				if part:IsA("BasePart") then
					originalCFrames[i][name][part.Name] = part.CFrame
				end
			end
			if obj:IsA("BasePart") then
				originalCFrames[i][name]["__root"] = obj.CFrame
			end
		end
	end
	print("[ScenarioManager] Recorded original CFrames for all hospitals")
end

local function resetCinematicNPCs(hospitalId)
	local folder = workspace:FindFirstChild("Hospital" .. hospitalId)
	if not folder then return end

	local toReset = {"StretcherCinematic", "Dummy", "Worker 1", "Worker 2"}
	for _, name in ipairs(toReset) do
		local obj = folder:FindFirstChild(name)
		if not obj then continue end

		-- Hapus WeldConstraints dulu sebelum reset CFrame
		for _, part in ipairs(obj:GetDescendants()) do
			if part:IsA("WeldConstraint") then
				part:Destroy()
			end
		end

		-- Reset semua BasePart
		for _, part in ipairs(obj:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 0
				part.CanCollide   = true
				part.Anchored     = true
				part.AssemblyLinearVelocity  = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero

				if originalCFrames[hospitalId]
					and originalCFrames[hospitalId][name]
					and originalCFrames[hospitalId][name][part.Name] then
					part.CFrame = originalCFrames[hospitalId][name][part.Name]
				end
			end
			if part:IsA("Decal") or part:IsA("Texture") then
				part.Transparency = 0
			end
		end

		-- Reset root jika obj sendiri BasePart
		if obj:IsA("BasePart") then
			obj.Transparency = 0
			obj.CanCollide   = true
			obj.Anchored     = true
			if originalCFrames[hospitalId]
				and originalCFrames[hospitalId][name]
				and originalCFrames[hospitalId][name]["__root"] then
				obj.CFrame = originalCFrames[hospitalId][name]["__root"]
			end
		end

		-- Reset humanoid
		local hum = obj:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.PlatformStand = false
		end
	end

	print("[ScenarioManager] Reset cinematic NPCs for Hospital" .. hospitalId)
end

-- Record posisi awal saat server start
recordOriginalCFrames()

-- ── Cinematic helpers ─────────────────────────────────────────────────────────
local function weldModelToStretcher(model, stretcher)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then part.Anchored = false end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then hum.PlatformStand = true end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = stretcher
		weld.Part1 = hrp
		weld.Parent = stretcher
	end
end

local walkAnimId  = "rbxassetid://180426354"
local dummyAnimId = "rbxassetid://78271003977121"
local DURATION    = 4

local function playWalkAnim(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local anim = Instance.new("Animation")
		anim.AnimationId = walkAnimId
		local track = humanoid:LoadAnimation(anim)
		track:Play()
		track:AdjustSpeed(0.5)
		return track
	end
end

local function playDummyAnim(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local anim = Instance.new("Animation")
		anim.AnimationId = dummyAnimId
		local track = humanoid:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play()
		return track
	end
end

local function hideNameplate(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

-- ── Main trigger ──────────────────────────────────────────────────────────────
triggerRemote.OnServerEvent:Connect(function(player, scenarioId)
	print("[ScenarioManager] Starting scenario:", scenarioId, "for", player.Name)

	-- Assign hospital sekarang sebelum apapun
	local hospital = HospitalRegistry.Assign(player)
	if not hospital then
		warn("[ScenarioManager] No free hospital for", player.Name)
		serverFullRemote:FireClient(player)
		return
	end
	player:SetAttribute("CurrentScenarioId", scenarioId)
	-- Reset cinematic NPCs ke posisi awal sebelum cinematic jalan
	resetCinematicNPCs(hospital.id)

	print("[ScenarioManager] Assigned Hospital", hospital.id, "to", player.Name)

	-- Kasih tau client hospital berapa
	assignedHospitalRemote:FireClient(player, hospital.id)

	-- Fire cutscene ke client
	startRemote:FireClient(player, scenarioId)

	task.spawn(function()
		local hospitalFolder = workspace:FindFirstChild("Hospital" .. hospital.id)
		if not hospitalFolder then
			warn("[ScenarioManager] Hospital folder not found: Hospital" .. hospital.id)
			return
		end

		local stretcher     = hospitalFolder:FindFirstChild("StretcherCinematic")
		local dummy         = hospitalFolder:FindFirstChild("Dummy")
		local worker1       = hospitalFolder:FindFirstChild("Worker 1")
		local worker2       = hospitalFolder:FindFirstChild("Worker 2")
		local entrancePoint = hospitalFolder:FindFirstChild("EntrancePoint")

		if not (stretcher and dummy and entrancePoint) then
			warn("[CinematicMover] Missing objects in Hospital" .. hospital.id)
			return
		end

		hideNameplate(dummy)
		stretcher.Anchored = false

		local dummyHRP = dummy:FindFirstChild("HumanoidRootPart")
		if dummyHRP then
			for _, part in ipairs(dummy:GetDescendants()) do
				if part:IsA("BasePart") then part.Anchored = false end
			end
			local dummyHum = dummy:FindFirstChildOfClass("Humanoid")
			if dummyHum then dummyHum.PlatformStand = true end
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = stretcher
			weld.Part1 = dummyHRP
			weld.Parent = stretcher
		end

		if worker1 then weldModelToStretcher(worker1, stretcher) end
		if worker2 then weldModelToStretcher(worker2, stretcher) end

		local track1     = playWalkAnim(worker1)
		local track2     = playWalkAnim(worker2)
		local dummyTrack = playDummyAnim(dummy)

		task.delay(DURATION + 1, function()
			if track1     then track1:Stop() end
			if track2     then track2:Stop() end
			if dummyTrack then dummyTrack:Stop() end
		end)

		local startCF    = stretcher.CFrame
		local stretcherY = stretcher.Position.Y
		local targetPos  = Vector3.new(entrancePoint.Position.X, stretcherY, entrancePoint.Position.Z)
		local targetCF   = CFrame.new(targetPos) * (stretcher.CFrame - stretcher.CFrame.Position)
		local elapsed    = 0
		local connection

		connection = RunService.Heartbeat:Connect(function(dt)
			elapsed = elapsed + dt
			local alpha = math.min(elapsed / DURATION, 1)
			stretcher.CFrame = startCF:Lerp(targetCF, alpha)
			if alpha >= 1 then
				connection:Disconnect()
				print("[CinematicMover] Done for Hospital" .. hospital.id)
			end
		end)

		task.wait(DURATION + 2)
		hideNPCRemote:FireClient(player, hospital.id)
	end)
end)