-- MainMenu LocalScript
-- Place inside: StarterGui → MainMenuGui → MainmenuLocalScript

local Players               = game:GetService("Players")
local TweenService         = game:GetService("TweenService")
local RS                    = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService            = game:GetService("RunService")

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
local RequestHistory = RS:WaitForChild("RequestHistory")
local RequestSessionDetail = RS:WaitForChild("RequestSessionDetail")
local TriggerCinematic = RS:WaitForChild("TriggerCinematic")
local ScenarioData     = require(RS:WaitForChild("ScenarioData"))

-- Lobby Remotes
local RequestLobbies = RS:WaitForChild("RequestLobbies")
local CreateLobby   = RS:WaitForChild("CreateLobby")
local JoinLobby     = RS:WaitForChild("JoinLobby")
local LeaveLobby    = RS:WaitForChild("LeaveLobby")
local UpdateLobbies = RS:WaitForChild("UpdateLobbies")

local cachedLobbies = {}
local includeAiContent = true -- Host preference (ticked by default)

local function getAvatarThumbnail(userId, imageLabel, size)
	size = size or Enum.ThumbnailSize.Size48x48
	task.spawn(function()
		local ok, img = pcall(function()
			return game:GetService("Players"):GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				size
			)
		end)
		if ok and imageLabel and imageLabel.Parent then
			imageLabel.Image = img
		end
	end)
end
local currentView = "scenario" -- "scenario" | "multiplayer" | "credits" | "history" | "historyDetail"

-- ── Menu Camera ───────────────────────────────────────────────────────────────
local function startMenuCamera()
	local menuCameraPart = workspace:WaitForChild("MenuCamera", 10)
	if not menuCameraPart then
		warn("[MenuCamera] MenuCamera Part not found in Workspace after waiting!")
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	task.wait(1)

	while not workspace.CurrentCamera do
		task.wait()
	end

	_G.MenuCameraActive = true

	local panAngle = 0
	local PAN_SPEED = 0.3

	RunService:BindToRenderStep("MenuCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not _G.MenuCameraActive then return end
		local cam = workspace.CurrentCamera
		if not cam then return end
		cam.CameraType = Enum.CameraType.Scriptable
		panAngle = panAngle + PAN_SPEED * dt
		cam.CFrame = menuCameraPart.CFrame * CFrame.Angles(0, math.rad(panAngle), 0)
	end)
end

local function stopMenuCamera()
	_G.MenuCameraActive = false
	RunService:UnbindFromRenderStep("MenuCamera")
	local cam = workspace.CurrentCamera
	if cam then cam.CameraType = Enum.CameraType.Custom end
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
		startBtn.Visible                 = true
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
	if headerLabel then headerLabel.Text = "Multiplayer Lobbies" end

	clearList()
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- Check if player is currently in a lobby
	local myLobby = nil
	local myHostId = nil
	for hostId, lobbyData in pairs(cachedLobbies) do
		if table.find(lobbyData.PlayerNames, player.Name) then
			myLobby = lobbyData
			myHostId = hostId
			break
		end
	end

	if myLobby then
		-- ── IN-LOBBY VIEW ──────────────────────────────────────────────────────
		local headerCard = Instance.new("Frame")
		headerCard.Size = UDim2.new(1, -16, 0, 50)
		headerCard.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		headerCard.BorderSizePixel = 0
		headerCard.LayoutOrder = 1
		headerCard.Parent = ScenarioList
		Instance.new("UICorner", headerCard).CornerRadius = UDim.new(0, 8)

		local lobbyTitle = Instance.new("TextLabel")
		lobbyTitle.Text = "👑 " .. myLobby.HostName .. "'s Lobby"
		lobbyTitle.TextSize = 14
		lobbyTitle.Font = Enum.Font.GothamBold
		lobbyTitle.TextColor3 = Color3.new(1, 1, 1)
		lobbyTitle.BackgroundTransparency = 1
		lobbyTitle.Size = UDim2.new(0.7, 0, 1, 0)
		lobbyTitle.Position = UDim2.new(0, 12, 0, 0)
		lobbyTitle.TextXAlignment = Enum.TextXAlignment.Left
		lobbyTitle.Parent = headerCard

		local countLabel = Instance.new("TextLabel")
		countLabel.Text = myLobby.PlayerCount .. "/" .. myLobby.MaxPlayers .. " players"
		countLabel.TextSize = 11
		countLabel.Font = Enum.Font.Gotham
		countLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
		countLabel.BackgroundTransparency = 1
		countLabel.Size = UDim2.new(0.3, -12, 1, 0)
		countLabel.Position = UDim2.new(0.7, 0, 0, 0)
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		countLabel.Parent = headerCard

		-- Player cards
		local pOrder = 2
		for _, pName in ipairs(myLobby.PlayerNames) do
			local isHost = (pName == myLobby.HostName)
			local isMe = (pName == player.Name)

			local pCard = Instance.new("Frame")
			pCard.Size = UDim2.new(1, -16, 0, 52)
			pCard.BackgroundColor3 = isMe
				and Color3.fromRGB(40, 45, 55)
				or  Color3.fromRGB(30, 30, 30)
			pCard.BorderSizePixel = 0
			pCard.LayoutOrder = pOrder
			pOrder += 1
			pCard.Parent = ScenarioList
			Instance.new("UICorner", pCard).CornerRadius = UDim.new(0, 8)

			local avatarFrame = Instance.new("Frame")
			avatarFrame.Size = UDim2.new(0, 36, 0, 36)
			avatarFrame.Position = UDim2.new(0, 8, 0.5, -18)
			avatarFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			avatarFrame.BorderSizePixel = 0
			avatarFrame.Parent = pCard
			Instance.new("UICorner", avatarFrame).CornerRadius = UDim.new(1, 0)

			local avatarImg = Instance.new("ImageLabel")
			avatarImg.Size = UDim2.fromScale(1, 1)
			avatarImg.BackgroundTransparency = 1
			avatarImg.Image = "rbxassetid://0"
			avatarImg.Parent = avatarFrame
			Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(1, 0)

			task.spawn(function()
				local ok, uid = pcall(function()
					return game:GetService("Players"):GetUserIdFromNameAsync(pName)
				end)
				if ok and uid then
					getAvatarThumbnail(uid, avatarImg)
				end
			end)

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Text = pName .. (isMe and " (You)" or "")
			nameLabel.TextSize = 13
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Size = UDim2.new(1, -100, 0, 20)
			nameLabel.Position = UDim2.new(0, 52, 0, 8)
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = pCard

			if isHost then
				local crownBadge = Instance.new("TextLabel")
				crownBadge.Text = "👑 Host"
				crownBadge.TextSize = 10
				crownBadge.Font = Enum.Font.GothamBold
				crownBadge.TextColor3 = Color3.fromRGB(234, 179, 8)
				crownBadge.BackgroundColor3 = Color3.fromRGB(50, 42, 20)
				crownBadge.Size = UDim2.new(0, 54, 0, 18)
				crownBadge.Position = UDim2.new(0, 52, 0, 28)
				crownBadge.BorderSizePixel = 0
				crownBadge.Parent = pCard
				Instance.new("UICorner", crownBadge).CornerRadius = UDim.new(1, 0)
				local bp = Instance.new("UIPadding", crownBadge)
				bp.PaddingLeft = UDim.new(0, 6)
				bp.PaddingRight = UDim.new(0, 6)
			else
				local readyLabel = Instance.new("TextLabel")
				readyLabel.Text = "Waiting..."
				readyLabel.TextSize = 10
				readyLabel.Font = Enum.Font.Gotham
				readyLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
				readyLabel.BackgroundTransparency = 1
				readyLabel.Size = UDim2.new(1, -60, 0, 18)
				readyLabel.Position = UDim2.new(0, 52, 0, 28)
				readyLabel.TextXAlignment = Enum.TextXAlignment.Left
				readyLabel.Parent = pCard
			end
		end

		-- Host controls: AI checkbox & Start Match
		if myLobby.HostName == player.Name then
			-- AI Generated Content Checkbox (Host only inside lobby)
			local toggleFrame = Instance.new("Frame")
			toggleFrame.Size = UDim2.new(1, -16, 0, 30)
			toggleFrame.BackgroundTransparency = 1
			toggleFrame.LayoutOrder = pOrder
			pOrder += 1
			toggleFrame.Parent = ScenarioList

			local checkBox = Instance.new("TextButton")
			checkBox.Size = UDim2.new(0, 22, 0, 22)
			checkBox.Position = UDim2.new(0, 4, 0.5, -11)
			checkBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			checkBox.Text = includeAiContent and "✓" or ""
			checkBox.TextColor3 = Color3.fromRGB(34, 197, 94)
			checkBox.TextSize = 14
			checkBox.Font = Enum.Font.GothamBold
			checkBox.BorderSizePixel = 0
			checkBox.Parent = toggleFrame
			Instance.new("UICorner", checkBox).CornerRadius = UDim.new(0, 4)

			local checkLabel = Instance.new("TextLabel")
			checkLabel.Size = UDim2.new(1, -36, 1, 0)
			checkLabel.Position = UDim2.new(0, 32, 0, 0)
			checkLabel.BackgroundTransparency = 1
			checkLabel.Text = "Include AI Generated Patients"
			checkLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			checkLabel.TextSize = 12
			checkLabel.Font = Enum.Font.Gotham
			checkLabel.TextXAlignment = Enum.TextXAlignment.Left
			checkLabel.Parent = toggleFrame

			checkBox.MouseButton1Click:Connect(function()
				includeAiContent = not includeAiContent
				checkBox.Text = includeAiContent and "✓" or ""
			end)

			local startBtn = Instance.new("TextButton")
			startBtn.Text = "▶  Start Match"
			startBtn.TextSize = 13
			startBtn.Font = Enum.Font.GothamBold
			startBtn.TextColor3 = Color3.new(1, 1, 1)
			startBtn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
			startBtn.Size = UDim2.new(1, -16, 0, 40)
			startBtn.BorderSizePixel = 0
			startBtn.LayoutOrder = pOrder
			pOrder += 1
			startBtn.Parent = ScenarioList
			Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 8)

			startBtn.MouseButton1Click:Connect(function()
				if myLobby.PlayerCount < 2 then
					local toast = Instance.new("ScreenGui")
					toast.ResetOnSpawn = false
					toast.Parent = player.PlayerGui
					local f = Instance.new("Frame")
					f.Size = UDim2.new(0, 260, 0, 40)
					f.Position = UDim2.new(0.5, -130, 0, 12)
					f.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
					f.BorderSizePixel = 0
					f.Parent = toast
					Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
					local l = Instance.new("TextLabel")
					l.Size = UDim2.new(1, -16, 1, 0)
					l.Position = UDim2.new(0, 8, 0, 0)
					l.BackgroundTransparency = 1
					l.TextColor3 = Color3.new(1,1,1)
					l.Font = Enum.Font.GothamBold
					l.TextSize = 13
					l.Text = "Need at least 2 players to start!"
					l.Parent = f
					task.delay(2.5, function() toast:Destroy() end)
					return
				end
				-- Sends preference to server when initiating start match
				RS:WaitForChild("StartMatch"):FireServer(includeAiContent)
			end)
		end

		-- Leave button
		local leaveBtn = Instance.new("TextButton")
		leaveBtn.Text = "Leave Lobby"
		leaveBtn.TextSize = 13
		leaveBtn.Font = Enum.Font.GothamBold
		leaveBtn.TextColor3 = Color3.new(1, 1, 1)
		leaveBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		leaveBtn.Size = UDim2.new(1, -16, 0, 36)
		leaveBtn.BorderSizePixel = 0
		leaveBtn.LayoutOrder = pOrder
		leaveBtn.Parent = ScenarioList
		Instance.new("UICorner", leaveBtn).CornerRadius = UDim.new(0, 8)
		leaveBtn.MouseButton1Click:Connect(function()
			LeaveLobby:FireServer()
		end)

	else
		-- ── LOBBY LIST VIEW ────────────────────────────────────────────────────
		local createBtn = Instance.new("TextButton")
		createBtn.Text = "+ Create Lobby"
		createBtn.TextSize = 13
		createBtn.Font = Enum.Font.GothamBold
		createBtn.TextColor3 = Color3.new(1, 1, 1)
		createBtn.BackgroundColor3 = Color3.fromRGB(229, 57, 53)
		createBtn.Size = UDim2.new(1, -16, 0, 40)
		createBtn.BorderSizePixel = 0
		createBtn.LayoutOrder = 1
		createBtn.Parent = ScenarioList
		Instance.new("UICorner", createBtn).CornerRadius = UDim.new(0, 8)

		createBtn.MouseButton1Click:Connect(function()
			CreateLobby:FireServer()
		end)

		local hasLobbies = false
		local cardOrder = 2
		for hostId, lobbyData in pairs(cachedLobbies) do
			hasLobbies = true

			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, -16, 0, 60)
			card.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			card.BorderSizePixel = 0
			card.LayoutOrder = cardOrder
			cardOrder += 1
			card.Parent = ScenarioList
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

			local avatarFrame = Instance.new("Frame")
			avatarFrame.Size = UDim2.new(0, 38, 0, 38)
			avatarFrame.Position = UDim2.new(0, 10, 0.5, -19)
			avatarFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			avatarFrame.BorderSizePixel = 0
			avatarFrame.Parent = card
			Instance.new("UICorner", avatarFrame).CornerRadius = UDim.new(1, 0)

			local avatarImg = Instance.new("ImageLabel")
			avatarImg.Size = UDim2.fromScale(1, 1)
			avatarImg.BackgroundTransparency = 1
			avatarImg.Image = "rbxassetid://0"
			avatarImg.Parent = avatarFrame
			Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(1, 0)

			task.spawn(function()
				local ok, uid = pcall(function()
					return game:GetService("Players"):GetUserIdFromNameAsync(lobbyData.HostName)
				end)
				if ok and uid then
					getAvatarThumbnail(uid, avatarImg)
				end
			end)

			local hostLabel = Instance.new("TextLabel")
			hostLabel.Text = "👑 " .. lobbyData.HostName .. "'s Lobby"
			hostLabel.TextSize = 13
			hostLabel.Font = Enum.Font.GothamBold
			hostLabel.TextColor3 = Color3.new(1, 1, 1)
			hostLabel.BackgroundTransparency = 1
			hostLabel.Size = UDim2.new(1, -120, 0, 20)
			hostLabel.Position = UDim2.new(0, 56, 0, 10)
			hostLabel.TextXAlignment = Enum.TextXAlignment.Left
			hostLabel.Parent = card

			local countLabel = Instance.new("TextLabel")
			countLabel.Text = lobbyData.PlayerCount .. "/" .. lobbyData.MaxPlayers .. " players"
			countLabel.TextSize = 11
			countLabel.Font = Enum.Font.Gotham
			countLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
			countLabel.BackgroundTransparency = 1
			countLabel.Size = UDim2.new(1, -120, 0, 16)
			countLabel.Position = UDim2.new(0, 56, 0, 32)
			countLabel.TextXAlignment = Enum.TextXAlignment.Left
			countLabel.Parent = card

			local joinBtn = Instance.new("TextButton")
			joinBtn.Text = "Join"
			joinBtn.TextSize = 12
			joinBtn.Font = Enum.Font.GothamBold
			joinBtn.TextColor3 = Color3.new(1, 1, 1)
			joinBtn.BackgroundColor3 = Color3.fromRGB(229, 57, 53)
			joinBtn.Size = UDim2.new(0, 52, 0, 28)
			joinBtn.Position = UDim2.new(1, -62, 0.5, -14)
			joinBtn.BorderSizePixel = 0
			joinBtn.Parent = card
			Instance.new("UICorner", joinBtn).CornerRadius = UDim.new(0, 6)
			joinBtn.MouseButton1Click:Connect(function()
				JoinLobby:FireServer(hostId)
			end)
		end

		if not hasLobbies then
			local noLobbyLabel = Instance.new("TextLabel")
			noLobbyLabel.Text = "No lobbies yet. Create one!"
			noLobbyLabel.TextSize = 12
			noLobbyLabel.Font = Enum.Font.Gotham
			noLobbyLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
			noLobbyLabel.BackgroundTransparency = 1
			noLobbyLabel.Size = UDim2.new(1, -16, 0, 40)
			noLobbyLabel.LayoutOrder = 2
			noLobbyLabel.TextXAlignment = Enum.TextXAlignment.Center
			noLobbyLabel.Parent = ScenarioList
		end
	end
end

-- ── Credits view ──────────────────────────────────────────────────────────────
local function showCreditsView()
	local headerLabel = Header:FindFirstChildWhichIsA("TextLabel")
	if headerLabel then headerLabel.Text = "Settings" end

	clearList()
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local titleCard = Instance.new("Frame")
	titleCard.Size            = UDim2.new(1, -16, 0, 72)
	titleCard.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	titleCard.BorderSizePixel = 0
	titleCard.Parent          = ScenarioList
	Instance.new("UICorner", titleCard).CornerRadius = UDim.new(0, 8)

	local accent = Instance.new("Frame")
	accent.Size             = UDim2.new(0, 4, 1, -16)
	accent.Position         = UDim2.new(0, 10, 0, 8)
	accent.BackgroundColor3 = Color3.fromRGB(229, 57, 53)
	accent.BorderSizePixel  = 0
	accent.Parent           = titleCard
	Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 4)

	local gameTitle = Instance.new("TextLabel")
	gameTitle.Text                   = "ER Simulator"
	gameTitle.TextSize               = 18
	gameTitle.Font                   = Enum.Font.GothamBold
	gameTitle.TextColor3             = Color3.new(1, 1, 1)
	gameTitle.BackgroundTransparency = 1
	gameTitle.Size                   = UDim2.new(1, -30, 0, 24)
	gameTitle.Position               = UDim2.new(0, 24, 0, 14)
	gameTitle.TextXAlignment         = Enum.TextXAlignment.Left
	gameTitle.Parent                 = titleCard

	local gameSub = Instance.new("TextLabel")
	gameSub.Text                   = "START Triage Simulation"
	gameSub.TextSize               = 11
	gameSub.Font                   = Enum.Font.Gotham
	gameSub.TextColor3             = Color3.fromRGB(160, 160, 160)
	gameSub.BackgroundTransparency = 1
	gameSub.Size                   = UDim2.new(1, -30, 0, 16)
	gameSub.Position               = UDim2.new(0, 24, 0, 42)
	gameSub.TextXAlignment         = Enum.TextXAlignment.Left
	gameSub.Parent                 = titleCard

	local sectionLabel = Instance.new("TextLabel")
	sectionLabel.Text                   = "DEVELOPED BY"
	sectionLabel.TextSize               = 10
	sectionLabel.Font                   = Enum.Font.GothamBold
	sectionLabel.TextColor3             = Color3.fromRGB(120, 120, 120)
	sectionLabel.BackgroundTransparency = 1
	sectionLabel.Size                   = UDim2.new(1, -16, 0, 20)
	sectionLabel.TextXAlignment         = Enum.TextXAlignment.Left
	sectionLabel.Parent                 = ScenarioList

	local team = {
		{ name = "Dyah Puspo Rini", role = "Game Design · UI · Environment" },
		{ name = "Denzel Huang",          role = "Multiplayer · Scripting" },
		{ name = "NAjla Aliya Syauqina",           role = "IoT Hardware · Endless" },
	}

	for _, member in ipairs(team) do
		local pCard = Instance.new("Frame")
		pCard.Size            = UDim2.new(1, -16, 0, 52)
		pCard.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		pCard.BorderSizePixel = 0
		pCard.Parent          = ScenarioList
		Instance.new("UICorner", pCard).CornerRadius = UDim.new(0, 8)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Text                   = member.name
		nameLabel.TextSize               = 13
		nameLabel.Font                   = Enum.Font.GothamBold
		nameLabel.TextColor3             = Color3.new(1, 1, 1)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size                   = UDim2.new(1, -24, 0, 20)
		nameLabel.Position               = UDim2.new(0, 12, 0, 8)
		nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
		nameLabel.Parent                 = pCard

		local roleLabel = Instance.new("TextLabel")
		roleLabel.Text                   = member.role
		roleLabel.TextSize               = 11
		roleLabel.Font                   = Enum.Font.Gotham
		roleLabel.TextColor3             = Color3.fromRGB(150, 150, 150)
		roleLabel.BackgroundTransparency = 1
		roleLabel.Size                   = UDim2.new(1, -24, 0, 16)
		roleLabel.Position               = UDim2.new(0, 12, 0, 28)
		roleLabel.TextXAlignment         = Enum.TextXAlignment.Left
		roleLabel.Parent                 = pCard
	end

	local footer = Instance.new("Frame")
	footer.Size            = UDim2.new(1, -16, 0, 44)
	footer.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	footer.BorderSizePixel = 0
	footer.Parent          = ScenarioList
	Instance.new("UICorner", footer).CornerRadius = UDim.new(0, 8)

	local footerLabel = Instance.new("TextLabel")
	footerLabel.Text                   = "President University · PKM-KC"
	footerLabel.TextSize               = 11
	footerLabel.Font                   = Enum.Font.Gotham
	footerLabel.TextColor3             = Color3.fromRGB(140, 140, 140)
	footerLabel.BackgroundTransparency = 1
	footerLabel.Size                   = UDim2.new(1, 0, 1, 0)
	footerLabel.TextXAlignment         = Enum.TextXAlignment.Center
	footerLabel.Parent                 = footer
end

-- ── History view (List of past sessions) ─────────────────────────────────────
-- Mirrors showCreditsView(): reuses ScenarioChooserFrame + clearList() + cardLayout.
local gameModeLabels = {
	Scenario    = "Scenario",
	Endless     = "Endless",
	Multiplayer = "Multiplayer",
}

local gameModeColors = {
	Scenario    = Color3.fromRGB(59, 130, 246),
	Endless     = Color3.fromRGB(168, 85, 247),
	Multiplayer = Color3.fromRGB(229, 57, 53),
}

local function formatHistoryDate(timestamp)
	if not timestamp then return "" end
	local ok, result = pcall(function()
		return os.date("%d %b, %H:%M", timestamp)
	end)
	return ok and result or ""
end

local function getScenarioTitle(scenarioId)
	if scenarioId == "endless" or scenarioId == "" or not scenarioId then
		return nil
	end
	local scenario = ScenarioData.GetScenario(scenarioId)
	return scenario and scenario.title or scenarioId
end

-- Forward declaration: showHistoryView() memanggil showSessionDetailView() yang
-- didefinisikan di bawahnya. Local ini dideklarasi lebih dulu supaya closure di
-- showHistoryView() menangkapnya sebagai upvalue yang sah, bukan global.
local showSessionDetailView

local function buildHistoryCard(entry, onOpen)
	local card = Instance.new("Frame")
	card.Size             = UDim2.new(1, -16, 0, 78)
	card.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	card.BorderSizePixel  = 0
	card.ClipsDescendants = true
	card.Parent           = ScenarioList
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

	local bar = Instance.new("Frame")
	bar.Size             = UDim2.new(0, 4, 1, -16)
	bar.Position          = UDim2.new(0, 8, 0, 8)
	bar.BackgroundColor3 = gameModeColors[entry.gameMode] or Color3.fromRGB(120, 120, 120)
	bar.BorderSizePixel  = 0
	bar.Parent           = card
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

	local titleText = getScenarioTitle(entry.scenarioId) or gameModeLabels[entry.gameMode] or "Sesi"
	local title = Instance.new("TextLabel")
	title.Text                   = titleText
	title.TextSize               = 14
	title.Font                   = Enum.Font.GothamBold
	title.TextColor3             = Color3.new(1, 1, 1)
	title.BackgroundTransparency = 1
	title.Size                   = UDim2.new(1, -90, 0, 20)
	title.Position               = UDim2.new(0, 22, 0, 10)
	title.TextXAlignment         = Enum.TextXAlignment.Left
	title.TextTruncate           = Enum.TextTruncate.AtEnd
	title.Parent                 = card

	local subtitle = Instance.new("TextLabel")
	subtitle.Text                   = (gameModeLabels[entry.gameMode] or "Sesi") .. " · " .. formatHistoryDate(entry.playedAt)
	subtitle.TextSize               = 11
	subtitle.Font                   = Enum.Font.Gotham
	subtitle.TextColor3             = Color3.fromRGB(150, 150, 150)
	subtitle.BackgroundTransparency = 1
	subtitle.Size                   = UDim2.new(1, -90, 0, 16)
	subtitle.Position               = UDim2.new(0, 22, 0, 32)
	subtitle.TextXAlignment         = Enum.TextXAlignment.Left
	subtitle.Parent                 = card

	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Text                   = tostring(entry.score or 0)
	scoreLabel.TextSize               = 18
	scoreLabel.Font                   = Enum.Font.GothamBold
	scoreLabel.TextColor3             = Color3.new(1, 1, 1)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Size                   = UDim2.new(0, 60, 0, 24)
	scoreLabel.Position               = UDim2.new(1, -76, 0, 10)
	scoreLabel.TextXAlignment         = Enum.TextXAlignment.Right
	scoreLabel.Parent                 = card

	local correctCount = entry.correctCount or 0
	local wrongCount    = entry.wrongCount or 0
	local statsText = string.format("✓ %d   ✗ %d   %d%%",
		correctCount, wrongCount, math.floor((entry.accuracy or 0) + 0.5))

	local stats = Instance.new("TextLabel")
	stats.Text                   = statsText
	stats.TextSize               = 11
	stats.Font                   = Enum.Font.Gotham
	stats.TextColor3             = Color3.fromRGB(160, 160, 160)
	stats.BackgroundTransparency = 1
	stats.Size                   = UDim2.new(1, -22, 0, 16)
	stats.Position               = UDim2.new(0, 22, 0, 54)
	stats.TextXAlignment         = Enum.TextXAlignment.Left
	stats.Parent                 = card

	-- [NEW]: Overlay klik supaya seluruh card bisa dipencet untuk buka detail.
	local clickOverlay = Instance.new("TextButton")
	clickOverlay.Text                   = ""
	clickOverlay.Size                   = UDim2.fromScale(1, 1)
	clickOverlay.BackgroundTransparency = 1
	clickOverlay.ZIndex                 = 5
	clickOverlay.Parent                 = card
	clickOverlay.MouseButton1Click:Connect(function()
		if onOpen then onOpen(entry) end
	end)
end

local function showHistoryView()
	local headerLabel = Header:FindFirstChildWhichIsA("TextLabel")
	if headerLabel then headerLabel.Text = "History" end

	clearList()
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	-- Loading placeholder while InvokeServer resolves
	local loadingLabel = Instance.new("TextLabel")
	loadingLabel.Name                   = "LoadingLabel"
	loadingLabel.Text                   = "Memuat riwayat..."
	loadingLabel.TextSize               = 13
	loadingLabel.Font                   = Enum.Font.Gotham
	loadingLabel.TextColor3             = Color3.fromRGB(140, 140, 140)
	loadingLabel.BackgroundTransparency = 1
	loadingLabel.Size                   = UDim2.new(1, -16, 0, 40)
	loadingLabel.Parent                 = ScenarioList

	task.spawn(function()
		local ok, history = pcall(function()
			return RequestHistory:InvokeServer()
		end)

		-- Bail if the player already navigated away before the invoke returned.
		if currentView ~= "history" then return end

		clearList()

		if not ok or not history or #history == 0 then
			local emptyLabel = Instance.new("TextLabel")
			emptyLabel.Text                   = "Belum ada riwayat sesi.\nMainkan skenario untuk mulai mencatat."
			emptyLabel.TextSize               = 13
			emptyLabel.Font                   = Enum.Font.Gotham
			emptyLabel.TextColor3             = Color3.fromRGB(130, 130, 130)
			emptyLabel.BackgroundTransparency = 1
			emptyLabel.Size                   = UDim2.new(1, -16, 0, 60)
			emptyLabel.TextXAlignment         = Enum.TextXAlignment.Center
			emptyLabel.TextYAlignment         = Enum.TextYAlignment.Center
			emptyLabel.TextWrapped            = true
			emptyLabel.Parent                 = ScenarioList
			return
		end

		for _, entry in ipairs(history) do
			buildHistoryCard(entry, function(clickedEntry)
				currentView = "historyDetail"
				showSessionDetailView(clickedEntry)
			end)
		end
	end)
end

-- ── Session Detail view (per-patient breakdown) ──────────────────────────────
local triageColors = {
	RED    = Color3.fromRGB(239, 68, 68),
	YELLOW = Color3.fromRGB(234, 179, 8),
	GREEN  = Color3.fromRGB(34, 197, 94),
	BLACK  = Color3.fromRGB(90, 90, 90),
	TIMEOUT = Color3.fromRGB(120, 120, 120),
}

local function buildDecisionRow(decision, index)
	local row = Instance.new("Frame")
	row.Size             = UDim2.new(1, -16, 0, 56)
	row.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
	row.BorderSizePixel  = 0
	row.Parent            = ScenarioList
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

	local idLabel = Instance.new("TextLabel")
	idLabel.Text                   = "P" .. string.format("%02d", index)
	idLabel.TextSize               = 11
	idLabel.Font                   = Enum.Font.GothamBold
	idLabel.TextColor3             = Color3.fromRGB(130, 130, 130)
	idLabel.BackgroundTransparency = 1
	idLabel.Size                   = UDim2.new(0, 32, 1, 0)
	idLabel.Position               = UDim2.new(0, 10, 0, 0)
	idLabel.TextXAlignment         = Enum.TextXAlignment.Left
	idLabel.Parent                 = row

	local chosenText = decision.chosen or "-"
	local chosenBadge = Instance.new("TextLabel")
	chosenBadge.Text                   = chosenText
	chosenBadge.TextSize               = 10
	chosenBadge.Font                   = Enum.Font.GothamBold
	chosenBadge.TextColor3             = Color3.new(1, 1, 1)
	chosenBadge.BackgroundColor3       = triageColors[chosenText] or Color3.fromRGB(80, 80, 80)
	chosenBadge.Size                   = UDim2.new(0, 62, 0, 20)
	chosenBadge.Position               = UDim2.new(0, 48, 0, 8)
	chosenBadge.BorderSizePixel        = 0
	chosenBadge.Parent                 = row
	Instance.new("UICorner", chosenBadge).CornerRadius = UDim.new(0, 4)

	local arrow = Instance.new("TextLabel")
	arrow.Text                   = "→"
	arrow.TextSize               = 12
	arrow.Font                   = Enum.Font.Gotham
	arrow.TextColor3             = Color3.fromRGB(100, 100, 100)
	arrow.BackgroundTransparency = 1
	arrow.Size                   = UDim2.new(0, 16, 0, 20)
	arrow.Position               = UDim2.new(0, 116, 0, 8)
	arrow.Parent                 = row

	local correctBadge = Instance.new("TextLabel")
	correctBadge.Text                   = decision.correct or "-"
	correctBadge.TextSize               = 10
	correctBadge.Font                   = Enum.Font.GothamBold
	correctBadge.TextColor3             = Color3.new(1, 1, 1)
	correctBadge.BackgroundColor3       = triageColors[decision.correct] or Color3.fromRGB(80, 80, 80)
	correctBadge.Size                   = UDim2.new(0, 62, 0, 20)
	correctBadge.Position               = UDim2.new(0, 138, 0, 8)
	correctBadge.BorderSizePixel        = 0
	correctBadge.Parent                 = row
	Instance.new("UICorner", correctBadge).CornerRadius = UDim.new(0, 4)

	local diagLabel = Instance.new("TextLabel")
	diagLabel.Text                   = decision.diagnosis or ""
	diagLabel.TextSize               = 10
	diagLabel.Font                   = Enum.Font.Gotham
	diagLabel.TextColor3             = Color3.fromRGB(130, 130, 130)
	diagLabel.BackgroundTransparency = 1
	diagLabel.Size                   = UDim2.new(1, -220, 0, 16)
	diagLabel.Position               = UDim2.new(0, 48, 0, 32)
	diagLabel.TextXAlignment         = Enum.TextXAlignment.Left
	diagLabel.TextTruncate           = Enum.TextTruncate.AtEnd
	diagLabel.Parent                 = row

	local pointsLabel = Instance.new("TextLabel")
	local points = decision.points or 0
	pointsLabel.Text                   = (decision.isCorrect and "+" or "") .. tostring(points)
	pointsLabel.TextSize               = 13
	pointsLabel.Font                   = Enum.Font.GothamBold
	pointsLabel.TextColor3             = decision.isCorrect
		and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(239, 68, 68)
	pointsLabel.BackgroundTransparency = 1
	pointsLabel.Size                   = UDim2.new(0, 50, 0, 20)
	pointsLabel.Position               = UDim2.new(1, -60, 0, 8)
	pointsLabel.TextXAlignment         = Enum.TextXAlignment.Right
	pointsLabel.Parent                 = row

	local timeLabel = Instance.new("TextLabel")
	timeLabel.Text                   = decision.responseTime or ""
	timeLabel.TextSize               = 10
	timeLabel.Font                   = Enum.Font.Gotham
	timeLabel.TextColor3             = Color3.fromRGB(110, 110, 110)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Size                   = UDim2.new(0, 50, 0, 16)
	timeLabel.Position               = UDim2.new(1, -60, 0, 30)
	timeLabel.TextXAlignment         = Enum.TextXAlignment.Right
	timeLabel.Parent                 = row
end

showSessionDetailView = function(entry)
	local headerLabel = Header:FindFirstChildWhichIsA("TextLabel")
	local titleText = getScenarioTitle(entry.scenarioId) or gameModeLabels[entry.gameMode] or "Detail"
	if headerLabel then headerLabel.Text = titleText end

	clearList()
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	local loadingLabel = Instance.new("TextLabel")
	loadingLabel.Text                   = "Memuat detail..."
	loadingLabel.TextSize               = 13
	loadingLabel.Font                   = Enum.Font.Gotham
	loadingLabel.TextColor3             = Color3.fromRGB(140, 140, 140)
	loadingLabel.BackgroundTransparency = 1
	loadingLabel.Size                   = UDim2.new(1, -16, 0, 40)
	loadingLabel.Parent                 = ScenarioList

	task.spawn(function()
		local ok, session = pcall(function()
			return RequestSessionDetail:InvokeServer(entry.sessionKey)
		end)

		if currentView ~= "historyDetail" then return end

		clearList()

		local decisions = ok and session and session.decisions or nil

		if not decisions or #decisions == 0 then
			local emptyLabel = Instance.new("TextLabel")
			emptyLabel.Text                   = "Tidak ada data breakdown untuk sesi ini."
			emptyLabel.TextSize               = 13
			emptyLabel.Font                   = Enum.Font.Gotham
			emptyLabel.TextColor3             = Color3.fromRGB(130, 130, 130)
			emptyLabel.BackgroundTransparency = 1
			emptyLabel.Size                   = UDim2.new(1, -16, 0, 60)
			emptyLabel.TextXAlignment         = Enum.TextXAlignment.Center
			emptyLabel.TextWrapped            = true
			emptyLabel.Parent                 = ScenarioList
			return
		end

		for i, decision in ipairs(decisions) do
			buildDecisionRow(decision, i)
		end
	end)
end

UpdateLobbies.OnClientEvent:Connect(function(lobbiesDict)
	cachedLobbies = lobbiesDict
	if currentView == "multiplayer" then
		showMultiplayerView()
	end
end)

-- ── Scenario View Helper ──────────────────────────────────────────────────────
local function showScenarioView()
	local headerLabel = Header:FindFirstChildWhichIsA("TextLabel")
	if headerLabel then headerLabel.Text = "Choose Scenario" end
	populateScenarioCards()
end

-- ── Button connections ────────────────────────────────────────────────────────
PlayButton.MouseButton1Click:Connect(function()
	currentView = "scenario"
	showScenarioView()
	slideToScenarios()
end)

local EndlessButton = ContentPanel:WaitForChild("EndlessButton")

EndlessButton.MouseButton1Click:Connect(function()
	MainMenuGui.Enabled = false
	enableControls()
	stopMenuCamera()
	TriggerCinematic:FireServer("endless")
end)

MultiplayerButton.MouseButton1Click:Connect(function()
	currentView = "multiplayer"
	RequestLobbies:FireServer()
	showMultiplayerView()
	slideToScenarios()
end)

SettingsButton.MouseButton1Click:Connect(function()
	currentView = "credits"
	showCreditsView()
	slideToScenarios()
end)

local HistoryButton = ContentPanel:WaitForChild("HistoryButton")

HistoryButton.MouseButton1Click:Connect(function()
	currentView = "history"
	showHistoryView()
	slideToScenarios()
end)

BackButton.MouseButton1Click:Connect(function()
	if currentView == "historyDetail" then
		currentView = "history"
		showHistoryView()
		return
	end

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
RequestLobbies:FireServer()
task.wait(0.3)
TweenService:Create(MainMenuFrame,
	TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{ BackgroundTransparency = 0.2 }
):Play()

-- ── Multiplayer Match Start Intercept & Timer HUD ─────────────────────────────
local MatchStarted = RS:WaitForChild("MultiplayerMatchStarted", 5) or Instance.new("RemoteEvent")
local MatchEnded   = RS:WaitForChild("MultiplayerMatchEnded", 5) or Instance.new("RemoteEvent")

local timerGui = Instance.new("ScreenGui")
timerGui.Name = "MultiplayerTimerHUD"
timerGui.ResetOnSpawn = false
timerGui.Parent = PlayerGui

local timerFrame = Instance.new("Frame")
timerFrame.Size = UDim2.new(0, 150, 0, 40)
timerFrame.Position = UDim2.new(0.5, -75, 0, 20) 
timerFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
timerFrame.Visible = false
timerFrame.Parent = timerGui
Instance.new("UICorner", timerFrame).CornerRadius = UDim.new(0, 8)

local timerText = Instance.new("TextLabel")
timerText.Size = UDim2.new(1, 0, 1, 0)
timerText.BackgroundTransparency = 1
timerText.Font = Enum.Font.GothamBold
timerText.TextColor3 = Color3.new(1, 1, 1)
timerText.TextSize = 18
timerText.Text = "01:00"
timerText.Parent = timerFrame

local currentTimerSequence = 0

MatchStarted.OnClientEvent:Connect(function(duration)
	MainMenuGui.Enabled = false
	enableControls()
	if stopMenuCamera then stopMenuCamera() end

	currentTimerSequence += 1
	local mySequence = currentTimerSequence

	player:SetAttribute("MPTimerDelta", 0)

	timerFrame.Visible = true
	local timeLeft = duration

	while timeLeft >= 0 and currentTimerSequence == mySequence do
		local delta = player:GetAttribute("MPTimerDelta") or 0
		if delta ~= 0 then
			timeLeft = math.clamp(timeLeft + delta, 0, 600)
			player:SetAttribute("MPTimerDelta", 0)
		end

		local m = math.floor(timeLeft / 60)
		local s = timeLeft % 60
		timerText.Text = string.format("%02d:%02d", m, s)

		if timeLeft <= 10 then
			timerText.TextColor3 = Color3.fromRGB(239, 68, 68)
		else
			timerText.TextColor3 = Color3.new(1, 1, 1)
		end

		task.wait(1)
		timeLeft -= 1
	end

	if currentTimerSequence == mySequence then
		timerFrame.Visible = false
	end
end)

local iotGlobalTimerRemote = RS:WaitForChild("IoTGlobalTimer", 5) or Instance.new("RemoteEvent")
iotGlobalTimerRemote.OnClientEvent:Connect(function(delta)
	player:SetAttribute("MPTimerDelta", (player:GetAttribute("MPTimerDelta") or 0) + delta)
end)

MatchEnded.OnClientEvent:Connect(function()
	currentTimerSequence += 1 
	timerFrame.Visible = false
end)
