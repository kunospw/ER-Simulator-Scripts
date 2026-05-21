-- UIScaleController (LocalScript)
-- GameplayScreenGui

local camera = workspace.CurrentCamera
local gui = script.Parent -- Directly references GameplayScreenGui

local function updateScale()
	local uiScale = gui:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = gui
	end

	local viewportSize = camera.ViewportSize
	local shortEdge = math.min(viewportSize.X, viewportSize.Y)

	local scale = shortEdge / 360
	scale = math.clamp(scale, 0.8, 2.0) 

	uiScale.Scale = scale
end

-- Update on viewport resize
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()