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

-- ── Cinematic tunables ────────────────────────────────────────────────────────
-- FOLLOW_TIME: how long the camera tracks the stretcher as it's wheeled in.
-- Keep this roughly equal to the server's stretcher-move DURATION (currently 4s
-- in ScenarioManager). Bump it slightly if the shot cuts before the stretcher
-- fully settles.
local CINEMATIC_FOLLOW_TIME = 4
-- LOOK_OFFSET: nudges the aim point up off the stretcher base so the camera
-- frames the patient's body instead of the floor. Tune the Y after seeing it.
local CINEMATIC_LOOK_OFFSET = Vector3.new(0, 1.5, 0)

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
	local stretcher      = hospitalFolder:FindFirstChild("StretcherCinematic")

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid  = character:WaitForChild("Humanoid")
	local root      = character:WaitForChild("HumanoidRootPart")

	if toggleRemote then toggleRemote:FireServer(false) end

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	camera.CameraType    = Enum.CameraType.Scriptable
	camera.CameraSubject = nil

	-- Camera holds at CinematicCameraStart and keeps re-aiming at the stretcher
	-- as it's wheeled straight in toward the camera.
	if cinematicStart and stretcher then
		local camPos = cinematicStart.Position

		local function stretcherTarget()
			local pos = stretcher:IsA("Model")
				and stretcher:GetPivot().Position
				or  stretcher.Position
			return pos + CINEMATIC_LOOK_OFFSET
		end

		-- Snap to the tracked shot, then fade in on it.
		camera.CFrame = CFrame.lookAt(camPos, stretcherTarget())
		fadeToBlack(0.6)
		task.wait(0.3)
		fadeFromBlack(0.8)

		-- Hold the position, follow the stretcher for the move-in window.
		local followConn = RunService.RenderStepped:Connect(function()
			camera.CFrame = CFrame.lookAt(camPos, stretcherTarget())
		end)
		task.wait(CINEMATIC_FOLLOW_TIME)
		followConn:Disconnect()
	else
		warn("[CinematicController] CinematicCameraStart or StretcherCinematic missing in Hospital" .. assignedHospitalId)
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
