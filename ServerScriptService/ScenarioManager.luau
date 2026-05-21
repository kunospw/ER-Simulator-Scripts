-- ServerScriptService > ScenarioManager (Script)
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local startRemote = RS:WaitForChild("StartCutscene")

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

local walkAnimId = "rbxassetid://180426354"
local dummyAnimId = "rbxassetid://78271003977121"
local DURATION = 4

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
		track:Play()
		track.Looped = true  -- TAMBAH INI
		return track
	end
end

local function hideNameplate(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

triggerRemote.OnServerEvent:Connect(function(player, scenarioId)
	print("[ScenarioManager] Starting scenario:", scenarioId, "for", player.Name)
	startRemote:FireClient(player, scenarioId)

	task.spawn(function()
		local stretcher = workspace:FindFirstChild("StretcherCinematic")
		local dummy = workspace:FindFirstChild("Dummy")
		local worker1 = workspace:FindFirstChild("Worker 1")
		local worker2 = workspace:FindFirstChild("Worker 2")
		local entrancePoint = workspace:FindFirstChild("EntrancePoint")

		if not (stretcher and dummy and entrancePoint) then
			warn("[CinematicMover] Missing:", 
				not stretcher and "StretcherCinematic" or "OK:Stretcher",
				not dummy and "Dummy" or "OK:Dummy",
				not worker1 and "Worker1" or "OK:Worker1",
				not worker2 and "Worker2" or "OK:Worker2",
				not entrancePoint and "EntrancePoint" or "OK:Entrance")
			return
		end

		-- Hide nameplate dummy
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

		-- Play animasi
		local track1 = playWalkAnim(worker1)
		local track2 = playWalkAnim(worker2)
		local dummyTrack = playDummyAnim(dummy)

		task.delay(DURATION + 1, function()
			if track1 then track1:Stop() end
			if track2 then track2:Stop() end
			if dummyTrack then dummyTrack:Stop() end
		end)

		-- Heartbeat loop
		local startCF = stretcher.CFrame
		local stretcherY = stretcher.Position.Y
		local targetPos = Vector3.new(entrancePoint.Position.X, stretcherY, entrancePoint.Position.Z)
		local targetCF = CFrame.new(targetPos) * (stretcher.CFrame - stretcher.CFrame.Position)
		local elapsed = 0
		local connection

		connection = RunService.Heartbeat:Connect(function(dt)
			elapsed = elapsed + dt
			local alpha = math.min(elapsed / DURATION, 1)
			stretcher.CFrame = startCF:Lerp(targetCF, alpha)
			if alpha >= 1 then
				connection:Disconnect()
				print("[CinematicMover] Done!")
			end
		end)

		task.wait(DURATION + 2)
		hideNPCRemote:FireClient(player)
	end)
end)