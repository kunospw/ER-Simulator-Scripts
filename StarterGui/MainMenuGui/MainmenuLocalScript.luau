-- MainMenu LocalScript
-- Place inside: StarterGui → MainMenuGui → MainmenuLocalScript

local Players              = game:GetService("Players")
local TweenService         = game:GetService("TweenService")
local RS                   = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService           = game:GetService("RunService")

local player        = Players.LocalPlayer
local PlayerGui     = player.PlayerGui
local MainMenuGui   = script.Parent
local MainMenuFrame = MainMenuGui:WaitForChild("MainMenuFrame")

-- ── Intercept "Try Again" Restart ─────────────────────────────────────────────
if player:GetAttribute("SkipMainMenu") then
	player:SetAttribute("SkipMainMenu", false)
	MainMenuGui.Enabled = false
	MainMenuFrame.Visible = false
	return
end

-- ── Normal Initialization ─────────────────────────────────────────────────────
MainMenuGui.Enabled   = true
MainMenuFrame.Visible = true

-- ── References ────────────────────────────────────────────────────────────────
local ContentPanel         = MainMenuFrame:WaitForChild("ContentPanel")
local ScenarioChooserFrame = MainMenuFrame:WaitForChild("ScenarioChooserFrame")
local Header               = ScenarioChooserFrame:WaitForChild("Header")
local BackButton           = Header:WaitForChild("ImageButton")
local ScenarioList         = ScenarioChooserFrame:WaitForChild("ScenarioList")
local PlayButton           = ContentPanel:WaitForChild("PlayButton")
local SettingsButton       = ContentPanel:WaitForChild("SettingsButton")
local MultiplayerButton    = ContentPanel:WaitForChild("MultiplayerButton")

local TriggerCinematic = RS:WaitForChild("TriggerCinematic")
local ScenarioData     = require(RS:WaitForChild("ScenarioData"))

-- ── Menu Camera ───────────────────────────────────────────────────────────────
local camera         = workspace.CurrentCamera
local menuCameraPart = workspace:FindFirstChild("MenuCamera")

local function startMenuCamera()
	if not menuCameraPart then
		warn("[MenuCamera] MenuCamera Part not found in Workspace!")
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	task.wait(1)

	_G.MenuCameraActive = true

	local panAngle = 0
	local PAN_SPEED = 0.3

	RunService:BindToRenderStep("MenuCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not _G.MenuCameraActive then return end
		camera.CameraType = Enum.CameraType.Scriptable
		panAngle = panAngle + PAN_SPEED * dt
		camera.CFrame = menuCameraPart.CFrame * CFrame.Angles(0, math.rad(panAngle), 0)
	end)
end

local function stopMenuCamera()
	_G.MenuCameraActive = false
	RunService:UnbindFromRenderStep("MenuCamera")
	camera.CameraType = Enum.CameraType.Custom
end

task.spawn(startMenuCamera)

-- ── Disable player controls while menu is open ────────────────────────────────
local BLOCK_ACTION = "BlockMenuInput"
local function disableControls()
	local function block() return Enum.ContextActionResult.Sink end
	ContextActionService:BindActionAtPriority(BLOCK_ACTION, block, false,
		Enum.ContextActionPriority.High.Value,
		Enum.PlayerActions.CharacterForward,
		Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft,
		Enum.PlayerActions.CharacterRight,
		Enum.PlayerActions.CharacterJump
	)
end
local function enableControls()
	ContextActionService:UnbindAction(BLOCK_ACTION)
end
disableControls()

-- ── Positions ─────────────────────────────────────────────────────────────────
local CONTENT_START    = UDim2.new(0.5,  0, 0.2, 0)
local CONTENT_SLID     = UDim2.new(0.35, 0, 0.2, 0)
local SCENARIO_HIDDEN  = UDim2.new(1.35, 0, 0.2, 0)
local SCENARIO_VISIBLE = UDim2.new(0.7,  0, 0.2, 0)

ContentPanel.Position         = CONTENT_START
ScenarioChooserFrame.Position = SCENARIO_HIDDEN
ScenarioChooserFrame.Visible  = true

-- ── Tween config ──────────────────────────────────────────────────────────────
local SLIDE_TIME  = 0.45
local SLIDE_STYLE = Enum.EasingStyle.Quint
local SLIDE_DIR   = Enum.EasingDirection.Out

local function slideToScenarios()
	TweenService:Create(ContentPanel,
		TweenInfo.new(SLIDE_TIME, SLIDE_STYLE, SLIDE_DIR),
		{ Position = CONTENT_SLID }
	):Play()
	TweenService:Create(ScenarioChooserFrame,
		TweenInfo.new(SLIDE_TIME, SLIDE_STYLE, SLIDE_DIR),
		{ Position = SCENARIO_VISIBLE }
	):Play()
end

local function slideToMainMenu()
	TweenService:Create(ContentPanel,
		TweenInfo.new(SLIDE_TIME, SLIDE_STYLE, SLIDE_DIR),
		{ Position = CONTENT_START }
	):Play()
	TweenService:Create(ScenarioChooserFrame,
		TweenInfo.new(SLIDE_TIME, SLIDE_STYLE, SLIDE_DIR),
		{ Position = SCENARIO_HIDDEN }
	):Play()
end

-- ── Card expand/collapse ──────────────────────────────────────────────────────
local selectedCard       = nil
local selectedScenarioId = nil

local function collapseCard(card)
	TweenService:Create(card,
		TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Size = UDim2.new(1, -16, 0, 90) }
	):Play()
	local startBtn = card:FindFirstChild("StartButton")
	if startBtn then
		TweenService:Create(startBtn,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad),
			{ BackgroundTransparency = 1, TextTransparency = 1 }
		):Play()
		task.delay(0.2, function()
			if startBtn then startBtn.Visible = false end
		end)
	end
end

local function expandCard(card, scenarioId)
	if selectedCard and selectedCard ~= card then
		collapseCard(selectedCard)
	end
	selectedCard       = card
	selectedScenarioId = scenarioId

	TweenService:Create(card,
		TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Size = UDim2.new(1, -16, 0, 128) }
	):Play()

	local startBtn = card:FindFirstChild("StartButton")
	if startBtn then
		startBtn.Visible                = true
		startBtn.BackgroundTransparency = 1
		startBtn.TextTransparency       = 1
		task.delay(0.15, function()
			TweenService:Create(startBtn,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad),
				{ BackgroundTransparency = 0, TextTransparency = 0 }
			):Play()
		end)
	end
end

-- ── Launch scenario ───────────────────────────────────────────────────────────
local function launchScenario(scenarioId)
	TweenService:Create(MainMenuFrame,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad),
		{ BackgroundTransparency = 0 }
	):Play()
	task.wait(0.3)
	local scenarioScreen = PlayerGui:FindFirstChild("ScenarioScreen")
	if scenarioScreen then
		scenarioScreen:SetAttribute("StartDialogue", false)
		scenarioScreen:SetAttribute("ScenarioId", scenarioId)
	end
	MainMenuGui.Enabled = false
	enableControls()
	stopMenuCamera()
	TriggerCinematic:FireServer(scenarioId)
end

-- ── ScenarioList layout ───────────────────────────────────────────────────────
local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop    = UDim.new(0, 8)
listPadding.PaddingBottom = UDim.new(0, 8)
listPadding.Parent        = ScenarioList

local cardLayout = Instance.new("UIListLayout")
cardLayout.Padding   = UDim.new(0, 8)
cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
cardLayout.Parent    = ScenarioList

cardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	ScenarioList.CanvasSize = UDim2.new(0, 0, 0, cardLayout.AbsoluteContentSize.Y + 16)
end)

-- ── Helper: clear ScenarioList ────────────────────────────────────────────────
local function clearList()
	for _, child in ipairs(ScenarioList:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

-- ── Build scenario cards ──────────────────────────────────────────────────────
local diffColors = {
	easy   = Color3.fromRGB(34, 197, 94),
	medium = Color3.fromRGB(234, 179, 8),
	hard   = Color3.fromRGB(239, 68, 68),
}

local function populateScenarioCards()
	clearList()
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	selectedCard       = nil
	selectedScenarioId = nil

	for i, scenario in ipairs(ScenarioData.Scenarios) do
		local card = Instance.new("Frame")
		card.Name             = scenario.id
		card.Size             = UDim2.new(1, -16, 0, 90)
		card.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		card.BorderSizePixel  = 0
		card.LayoutOrder      = i
		card.ClipsDescendants = true
		card.Parent           = ScenarioList

		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

		local bar = Instance.new("Frame")
		bar.Size             = UDim2.new(0, 4, 1, -16)
		bar.Position         = UDim2.new(0, 8, 0, 8)
		bar.BackgroundColor3 = diffColors[scenario.difficulty] or diffColors.medium
		bar.BorderSizePixel  = 0
		bar.Parent           = card
		Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

		local title = Instance.new("TextLabel")
		title.Text                   = scenario.title
		title.TextSize               = 14
		title.Font                   = Enum.Font.GothamBold
		title.TextColor3             = Color3.new(1, 1, 1)
		title.BackgroundTransparency = 1
		title.Size                   = UDim2.new(1, -30, 0, 20)
		title.Position               = UDim2.new(0, 22, 0, 10)
		title.TextXAlignment         = Enum.TextXAlignment.Left
		title.Parent                 = card

		local desc = Instance.new("TextLabel")
		desc.Text                   = scenario.description
		desc.TextSize               = 11
		desc.Font                   = Enum.Font.Gotham
		desc.TextColor3             = Color3.fromRGB(160, 160, 160)
		desc.BackgroundTransparency = 1
		desc.Size                   = UDim2.new(1, -30, 0, 32)
		desc.Position               = UDim2.new(0, 22, 0, 32)
		desc.TextXAlignment         = Enum.TextXAlignment.Left
		desc.TextWrapped            = true
		desc.Parent                 = card

		local tagsRow = Instance.new("Frame")
		tagsRow.Size                   = UDim2.new(1, -30, 0, 20)
		tagsRow.Position               = UDim2.new(0, 22, 0, 66)
		tagsRow.BackgroundTransparency = 1
		tagsRow.Parent                 = card

		local tagLayout = Instance.new("UIListLayout")
		tagLayout.FillDirection = Enum.FillDirection.Horizontal
		tagLayout.Padding       = UDim.new(0, 6)
		tagLayout.Parent        = tagsRow

		for _, tagText in ipairs({ scenario.mode, tostring(scenario.casualtyCount) .. " Korban" }) do
			local tag = Instance.new("TextLabel")
			tag.Text              = tagText
			tag.TextSize          = 10
			tag.Font              = Enum.Font.Gotham
			tag.TextColor3        = Color3.fromRGB(140, 140, 140)
			tag.BackgroundColor3  = Color3.fromRGB(45, 45, 45)
			tag.AutomaticSize     = Enum.AutomaticSize.X
			tag.Size              = UDim2.new(0, 0, 1, 0)
			tag.BorderSizePixel   = 0
			tag.Parent            = tagsRow
			Instance.new("UICorner", tag).CornerRadius = UDim.new(1, 0)
			local tp = Instance.new("UIPadding", tag)
			tp.PaddingLeft  = UDim.new(0, 8)
			tp.PaddingRight = UDim.new(0, 8)
		end

		local startBtn = Instance.new("TextButton")
		startBtn.Name                     = "StartButton"
		startBtn.Text                     = "▶  Mulai Skenario"
		startBtn.TextSize                 = 12
		startBtn.Font                     = Enum.Font.GothamBold
		startBtn.TextColor3               = Color3.new(1, 1, 1)
		startBtn.BackgroundColor3         = Color3.fromRGB(229, 57, 53)
		startBtn.BackgroundTransparency   = 1
		startBtn.TextTransparency         = 1
		startBtn.Size                     = UDim2.new(1, -30, 0, 28)
		startBtn.Position                 = UDim2.new(0, 22, 0, 94)
		startBtn.BorderSizePixel          = 0
		startBtn.ZIndex                   = 6
		startBtn.Visible                  = false
		startBtn.Parent                   = card
		Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 6)

		startBtn.MouseButton1Click:Connect(function()
			launchScenario(scenario.id)
		end)

		local btn = Instance.new("TextButton")
		btn.Text                   = ""
		btn.Size                   = UDim2.fromScale(1, 1)
		btn.BackgroundTransparency = 1
		btn.ZIndex                 = 5
		btn.Parent                 = card

		btn.MouseButton1Click:Connect(function()
			if selectedCard == card then
				collapseCard(card)
				selectedCard       = nil
				selectedScenarioId = nil
			else
				expandCard(card, scenario.id)
			end
		end)
	end
end

-- ── Multiplayer view ──────────────────────────────────────────────────────────
local function showMultiplayerView()
	local headerLabel = Header:FindFirstChildWhichIsA("TextLabel")
	if headerLabel then headerLabel.Text = "Multiplayer" end

	clearList()
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local noLobbyLabel = Instance.new("TextLabel")
	noLobbyLabel.Text                   = "No multiplayer lobbies yet."
	noLobbyLabel.TextSize               = 13
	noLobbyLabel.Font                   = Enum.Font.Gotham
	noLobbyLabel.TextColor3             = Color3.fromRGB(140, 140, 140)
	noLobbyLabel.BackgroundTransparency = 1
	noLobbyLabel.Size                   = UDim2.new(1, -16, 0, 40)
	noLobbyLabel.TextXAlignment         = Enum.TextXAlignment.Center
	noLobbyLabel.Parent                 = ScenarioList

	local createBtn = Instance.new("TextButton")
	createBtn.Name                   = "CreateLobbyButton"
	createBtn.Text                   = "+ Create Lobby"
	createBtn.TextSize               = 13
	createBtn.Font                   = Enum.Font.GothamBold
	createBtn.TextColor3             = Color3.new(1, 1, 1)
	createBtn.BackgroundColor3       = Color3.fromRGB(229, 57, 53)
	createBtn.Size                   = UDim2.new(1, -16, 0, 40)
	createBtn.BorderSizePixel        = 0
	createBtn.Parent                 = ScenarioList
	Instance.new("UICorner", createBtn).CornerRadius = UDim.new(0, 8)

	createBtn.MouseButton1Click:Connect(function()
		print("[Multiplayer] Create Lobby clicked — backend belum ada")
	end)
end

local function showScenarioView()
	local headerLabel = Header:FindFirstChildWhichIsA("TextLabel")
	if headerLabel then headerLabel.Text = "Choose Scenario" end
	populateScenarioCards()
end

-- ── View state ────────────────────────────────────────────────────────────────
local currentView = "scenario"

-- ── Button connections ────────────────────────────────────────────────────────
PlayButton.MouseButton1Click:Connect(function()
	currentView = "scenario"
	showScenarioView()
	slideToScenarios()
end)

MultiplayerButton.MouseButton1Click:Connect(function()
	currentView = "multiplayer"
	showMultiplayerView()
	slideToScenarios()
end)

BackButton.MouseButton1Click:Connect(function()
	if selectedCard then
		collapseCard(selectedCard)
		selectedCard       = nil
		selectedScenarioId = nil
	end
	slideToMainMenu()
	currentView = "scenario"
end)

-- ── Entry animation ───────────────────────────────────────────────────────────
MainMenuFrame.BackgroundTransparency = 1
task.wait(0.3)
TweenService:Create(MainMenuFrame,
	TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{ BackgroundTransparency = 0.2 }
):Play()
