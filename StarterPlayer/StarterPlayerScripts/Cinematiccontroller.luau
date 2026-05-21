-- CinematicController (LocalScript)
-- Place in: StarterPlayerScripts
-- Replace your existing Cinematiccontroller with this entire script.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local RS           = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ── Safe reference helper ─────────────────────────────────────────────────────
-- Prints a clear error instead of hanging forever if something is missing
local function safeGet(parent, name, timeout)
	timeout = timeout or 10
	local obj = parent:WaitForChild(name, timeout)
	if not obj then
		warn("[CinematicController] MISSING:", name, "in", parent.Name)
	end
	return obj
end

-- ── RemoteEvents ──────────────────────────────────────────────────────────────
-- These MUST exist in ReplicatedStorage. Create them if missing:
-- StartCutscene, TogglePrompt, SpawnPatients, TriageRoomEntered
local startRemote   = safeGet(RS, "StartCutscene")
local toggleRemote  = safeGet(RS, "TogglePrompt")
local spawnRemote   = safeGet(RS, "SpawnPatients")
local triageRemote  = safeGet(RS, "TriageRoomEntered")

-- ── World Parts ───────────────────────────────────────────────────────────────
-- These MUST exist directly in Workspace (not nested in a folder/model):
-- CutsceneCamera, CinematicCameraStart, EntrancePoint, EntrancePointTriage
-- AmbulanceMain (rename your parked ambulance to this)
local entrancePoint   = safeGet(workspace, "EntrancePoint")


-- ── Fade Overlay ──────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "CinematicFade"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Global
screenGui.DisplayOrder    = 99
screenGui.IgnoreGuiInset  = true
screenGui.Parent          = player.PlayerGui

local fadeFrame = Instance.new("Frame")
fadeFrame.Size                  = UDim2.fromScale(1, 1)
fadeFrame.BackgroundColor3      = Color3.new(0, 0, 0)
fadeFrame.BackgroundTransparency = 1
fadeFrame.BorderSizePixel       = 0
fadeFrame.ZIndex                = 99
fadeFrame.Parent                = screenGui

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
	local cinematicStart = workspace:FindFirstChild("CinematicCameraStart")
	local ambulance      = workspace:FindFirstChild("AmbulanceMain")
	local entranceTriage = workspace:FindFirstChild("EntrancePointTriage")
	local entrancePoint  = workspace:FindFirstChild("EntrancePoint")

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid  = character:WaitForChild("Humanoid")
	local root      = character:WaitForChild("HumanoidRootPart")

	if toggleRemote then toggleRemote:FireServer(false) end

	-- Lock player
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	camera.CameraType    = Enum.CameraType.Scriptable
	camera.CameraSubject = nil

	-- SHOT 1: Look at ambulance from outside
	if cinematicStart and ambulance then
		local ambulancePos = ambulance:GetPivot().Position
		local shot1 = CFrame.new(cinematicStart.Position, ambulancePos + Vector3.new(0, 1, 0))
		camera.CFrame = shot1

		fadeToBlack(0.6)  -- smooth 0.6s fade to black
		task.wait(0.3)
		fadeFromBlack(0.8) -- fade in on ambulance shot    -- hold on ambulance

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
		warn("[CinematicController] CinematicCameraStart or AmbulanceMain missing — skipping camera shots")
		task.wait(0.5)
	end

	-- Fade to black, spawn patients
	fadeToBlack(0.7)
	if spawnRemote then
		spawnRemote:FireServer(scenarioId or "food_poisoning")
	end
	task.wait(0.5)

	-- Restore player camera
	workspace.CurrentCamera.CameraType    = Enum.CameraType.Custom
	workspace.CurrentCamera.CameraSubject = humanoid

	-- [FIX]: Force the camera to point in the direction the player is facing
	if root then
		local lookDir = root.CFrame.LookVector
		local headPos = root.Position + Vector3.new(0, 1.5, 0) -- Target the head area

		-- Position the camera 10 studs behind and 2 studs above, looking at the head
		workspace.CurrentCamera.CFrame = CFrame.lookAt(
			headPos - (lookDir * 10) + Vector3.new(0, 2, 0), 
			headPos
		)
	end

	humanoid.WalkSpeed  = 16
	humanoid.JumpPower  = 50

	-- Signal ScenarioScreen to start dialogue
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