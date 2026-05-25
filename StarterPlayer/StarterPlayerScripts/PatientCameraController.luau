-- PatientCameraController (LocalScript)
-- StarterPlayerScripts

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player  = Players.LocalPlayer
local camera  = workspace.CurrentCamera

local focusRemote = RS:WaitForChild("FocusPatientCamera")
local resetRemote = RS:WaitForChild("ResetPatientCamera")

-- ── State ─────────────────────────────────────────────────────────────────────
local isFocused    = false
local targetHead   = nil
local yaw          = 0
local pitch        = 20
local distance     = 5
local sensitivity  = 0.35

-- Input tracking
local dragging     = false
local lastMousePos = nil
local activeTouch  = nil
local lastTouchPos = nil

-- ── Public reset (also called by UIController) ────────────────────────────────
local function resetCamera()
	isFocused  = false
	targetHead = nil
	dragging   = false
	lastMousePos = nil
	activeTouch  = nil
	lastTouchPos = nil

	local RS = game:GetService("ReplicatedStorage")
	local toggleRemote = RS:FindFirstChild("TogglePrompt")
	if toggleRemote then toggleRemote:FireServer(true) end

	camera.CameraType = Enum.CameraType.Custom
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then camera.CameraSubject = hum end
	end
end

-- ── Focus on patient ──────────────────────────────────────────────────────────
focusRemote.OnClientEvent:Connect(function(patientModel)
	-- Use Torso as center for lying patients, fall back to Head
	local torso = patientModel:FindFirstChild("Torso")
	local head  = patientModel:FindFirstChild("Head")
	targetHead  = torso or head  -- variable name kept same to avoid refactoring
	if not targetHead then return end

	isFocused  = true
	yaw        = 90
	pitch      = -50   -- looking down at patient from above
	distance   = 6

	camera.CameraType = Enum.CameraType.Scriptable
	
	local RS = game:GetService("ReplicatedStorage")
	local toggleRemote = RS:FindFirstChild("TogglePrompt")
	if toggleRemote then toggleRemote:FireServer(false) end
end)

-- ── Reset from server relay OR from UIController ──────────────────────────────
resetRemote.OnClientEvent:Connect(resetCamera)

-- Expose reset so PatientUIController can call it directly (no extra Remote needed)
_G.ResetPatientCamera = resetCamera

-- ── Mouse input ───────────────────────────────────────────────────────────────
UIS.InputBegan:Connect(function(input, gameProcessed)
	if not isFocused then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton2 then
		dragging     = true
		lastMousePos = UIS:GetMouseLocation()
	end
	if input.UserInputType == Enum.UserInputType.Touch and not activeTouch then
		activeTouch  = input
		lastTouchPos = input.Position
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton2 then
		dragging     = false
		lastMousePos = nil
	end
	if input.UserInputType == Enum.UserInputType.Touch
		and input == activeTouch then
		activeTouch  = nil
		lastTouchPos = nil
	end
end)

UIS.InputChanged:Connect(function(input)
	if not isFocused then return end

	if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
		local current = UIS:GetMouseLocation()
		local delta   = current - lastMousePos
		lastMousePos  = current
		yaw   = yaw   - delta.X * sensitivity
		pitch = math.clamp(pitch - delta.Y * sensitivity, -60, 60)
	end

	if input.UserInputType == Enum.UserInputType.Touch
		and input == activeTouch and lastTouchPos then
		local delta  = input.Position - lastTouchPos
		lastTouchPos = input.Position
		yaw   = yaw   - delta.X * sensitivity
		pitch = math.clamp(pitch - delta.Y * sensitivity, -60, 60)
	end
end)

-- ── Update camera every frame ─────────────────────────────────────────────────
RunService.RenderStepped:Connect(function()
	if _G.MenuCameraActive then return end  -- ← tambahin ini
	if not isFocused or not targetHead or not targetHead.Parent then return end
	
	local origin = targetHead.Position
	local camCF  = CFrame.new(origin)
		* CFrame.Angles(0, math.rad(yaw), 0)
		* CFrame.Angles(math.rad(pitch), 0, 0)
		* CFrame.new(0, 0, distance)

	camera.CFrame = camCF
end)