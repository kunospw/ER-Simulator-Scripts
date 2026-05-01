-- UIScaleController (LocalScript)
-- StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function getGui()
	return player.PlayerGui:WaitForChild("GameplayScreenGui")
end

local function updateScale()
	local gui = getGui()
	if not gui then return end

	local uiScale = gui:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = gui
	end

	local viewportSize = camera.ViewportSize
	local shortEdge = math.min(viewportSize.X, viewportSize.Y)

	-- 360 = baseline mobile height, scale up/down from there
	local scale = shortEdge / 360
	scale = math.clamp(scale, 0.8, 2.0)  -- min 0.8x, max 2x

	uiScale.Scale = scale
end

-- Update on viewport resize
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()