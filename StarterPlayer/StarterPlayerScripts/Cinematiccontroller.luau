-- CinematicController (LocalScript)
-- Place in: StarterPlayerScripts

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local RS           = game:GetService("ReplicatedStorage")
local StarterGui   = game:GetService("StarterGui")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function safeGet(parent, name, timeout)
	timeout = timeout or 10
	local obj = parent:WaitForChild(name, timeout)
	if not obj then
		warn("[CinematicController] MISSING:", name, "in", parent.Name)
	end
	return obj
end

-- ── RemoteEvents ──────────────────────────────────────────────────────────────
local startRemote            = safeGet(RS, "StartCutscene")
local toggleRemote           = safeGet(RS, "TogglePrompt")
local spawnRemote            = safeGet(RS, "SpawnPatients")
local serverFullRemote       = safeGet(RS, "ServerFull")
local assignedHospitalRemote = safeGet(RS, "AssignedHospital")

-- ── Assigned hospital ID ──────────────────────────────────────────────────────
local assignedHospitalId = nil

assignedHospitalRemote.OnClientEvent:Connect(function(hospitalId)
	assignedHospitalId = hospitalId
	print("[CinematicController] Assigned to Hospital", hospitalId)
end)

-- ── Server Full Handler ───────────────────────────────────────────────────────
serverFullRemote.OnClientEvent:Connect(function()
	local gui = Instance.new("ScreenGui")
	gui.Name         = "ServerFullGui"
	gui.ResetOnSpawn = false
	gui.Parent       = player.PlayerGui

	local label = Instance.new("TextLabel")
	label.Size             = UDim2.new(0, 320, 0, 60)
	label.Position         = UDim2.new(0.5, -160, 0.5, -30)
	label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	label.TextColor3       = Color3.new(1, 1, 1)
	label.Font             = Enum.Font.GothamBold
	label.TextSize         = 16
	label.Text             = "Server penuh! Coba lagi nanti."
	label.BorderSizePixel  = 0
	label.Parent           = gui
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)

	local mainMenuGui = player.PlayerGui:FindFirstChild("MainMenuGui")
	if mainMenuGui then mainMenuGui.Enabled = true end

	task.delay(3, function()
		gui:Destroy()
	end)
end)

-- ── Fade Overlay ──────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name             = "CinematicFade"
screenGui.ResetOnSpawn     = false
screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Global
screenGui.DisplayOrder     = 99
screenGui.IgnoreGuiInset   = true
screenGui.Parent           = player.PlayerGui

local fadeFrame = Instance.new("Frame")
fadeFrame.Size                   = UDim2.fromScale(1, 1)
fadeFrame.BackgroundColor3       = Color3.new(0, 0, 0)
fadeFrame.BackgroundTransparency = 1
fadeFrame.BorderSizePixel        = 0
fadeFrame.ZIndex                 = 99
fadeFrame.Parent                 = screenGui

local function fadeToBlack(duration)
	local t = TweenService:Create(fadeFrame,
		TweenInfo.new(duration or 0.6, Enum.EasingStyle.Quad),
		{ BackgroundTransparency = 0 })
	t:Play(); t.Completed:Wait()
end

local function fadeFromBlack(duration)
	local t = TweenService:Create(fadeFrame,
		TweenInfo.new(duration or 0.6, Enum.EasingStyle.Quad),
		{ BackgroundTransparency = 1 })
	t:Play(); t.Completed:Wait()
end

local function tweenCamera(targetCF, duration)
	local t = TweenService:Create(camera,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = targetCF })
	t:Play(); t.Completed:Wait()
end

-- ── Free-look state ───────────────────────────────────────────────────────────
local yaw, pitch        = 0, 0
local sensitivity       = 0.3
local holdingRightClick = false
local lastMousePos      = Vector2.new()
local activeTouch, lastTouchPos = nil, nil

UIS.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		holdingRightClick = true
		lastMousePos = UIS:GetMouseLocation()
	end
	if input.UserInputType == Enum.UserInputType.Touch and not activeTouch then
		activeTouch  = input
		lastTouchPos = input.Position
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		holdingRightClick = false
	end
	if input.UserInputType == Enum.UserInputType.Touch and input == activeTouch then
		activeTouch, lastTouchPos = nil, nil
	end
end)
UIS.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch
		and input == activeTouch and lastTouchPos then
		local delta  = input.Position - lastTouchPos
		lastTouchPos = input.Position
		yaw   -= delta.X * sensitivity
		pitch  = math.clamp(pitch - delta.Y * sensitivity, -80, 80)
	end
end)

-- ── Main cinematic ────────────────────────────────────────────────────────────
if not startRemote then
	warn("[CinematicController] StartCutscene RemoteEvent missing — cinematic won't play.")
	return
end

startRemote.OnClientEvent:Connect(function(scenarioId)
	StarterGui:SetCore("ResetButtonCallback", false)
	-- Hospital ID harusnya udah diterima sebelum StartCutscene
	if not assignedHospitalId then
		warn("[CinematicController] No assigned hospital ID — aborting cinematic")
		return
	end

	local hospitalFolder = workspace:FindFirstChild("Hospital" .. assignedHospitalId)
	if not hospitalFolder then
		warn("[CinematicController] Hospital folder not found: Hospital" .. assignedHospitalId)
		return
	end
	
	local toShow = {"StretcherCinematic", "Dummy", "Worker 1", "Worker 2"}
	for _, name in ipairs(toShow) do
		local obj = hospitalFolder:FindFirstChild(name)
		if obj then
			for _, part in ipairs(obj:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 0
					part.CanCollide = false
					part.AssemblyLinearVelocity = Vector3.zero   -- add this
					part.AssemblyAngularVelocity = Vector3.zero  -- add this
				end
				if part:IsA("Decal") or part:IsA("Texture") then
					part.Transparency = 0
				end
			end
			if obj:IsA("BasePart") then
				obj.Transparency = 0
				obj.CanCollide = false
			end
		end
	end
	
	local cinematicStart = hospitalFolder:FindFirstChild("CinematicCameraStart")
	local ambulance      = hospitalFolder:FindFirstChild("AmbulanceMain")
	local entrancePoint  = hospitalFolder:FindFirstChild("EntrancePoint")

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid  = character:WaitForChild("Humanoid")
	local root      = character:WaitForChild("HumanoidRootPart")

	if toggleRemote then toggleRemote:FireServer(false) end

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	camera.CameraType    = Enum.CameraType.Scriptable
	camera.CameraSubject = nil

	-- SHOT 1: Look at ambulance
	if cinematicStart and ambulance then
		local ambulancePos = ambulance:GetPivot().Position
		local shot1 = CFrame.new(cinematicStart.Position, ambulancePos + Vector3.new(0, 1, 0))
		camera.CFrame = shot1

		fadeToBlack(0.6)
		task.wait(0.3)
		fadeFromBlack(0.8)

		-- SHOT 2: Pan toward ER entrance
		if entrancePoint then
			local shot2 = CFrame.new(
				cinematicStart.Position + Vector3.new(0, 2, -6),
				entrancePoint.Position + Vector3.new(0, 2, 0)
			)
			tweenCamera(shot2, 2.5)
			task.wait(1)
		end
	else
		warn("[CinematicController] CinematicCameraStart or AmbulanceMain missing in Hospital" .. assignedHospitalId)
		task.wait(0.5)
	end

	-- Fade to black, spawn patients
	fadeToBlack(0.7)
	if spawnRemote then
		spawnRemote:FireServer(scenarioId or "food_poisoning")
	end
	task.wait(0.5)

	-- Reset hospital ID untuk session berikutnya
	assignedHospitalId = nil

	-- Restore player camera
	workspace.CurrentCamera.CameraType    = Enum.CameraType.Custom
	workspace.CurrentCamera.CameraSubject = humanoid

	if root then
		local lookDir = root.CFrame.LookVector
		local headPos = root.Position + Vector3.new(0, 1.5, 0)
		workspace.CurrentCamera.CFrame = CFrame.lookAt(
			headPos - (lookDir * 10) + Vector3.new(0, 2, 0),
			headPos
		)
	end

	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50

	local scenarioScreen = player.PlayerGui:FindFirstChild("ScenarioScreen")
	if scenarioScreen then
		fadeFromBlack(0.8)
		scenarioScreen:SetAttribute("StartDialogue", true)
	else
		warn("[CinematicController] ScenarioScreen not found in PlayerGui")
		fadeFromBlack(0.8)
	end

	if toggleRemote then toggleRemote:FireServer(true) end
end)