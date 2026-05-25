-- EndScreenScontroller
-- StarterPlayerScripts

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local sessionRemote = RS:WaitForChild("SessionComplete")

-- GUI References
local function getEndScreen()
	return player.PlayerGui:WaitForChild("EndScreenGui")
end

local function buildMistakeCard(listParent, mistakeData)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -10, 0, 70) -- Increased height to 70
	card.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	card.Parent = listParent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -20, 0, 25) -- Increased height to 25
	nameLabel.Position = UDim2.new(0, 10, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextScaled = true -- Forces text to scale to the box size
	nameLabel.Text = mistakeData.name .. " — " .. mistakeData.diagnosis
	nameLabel.Parent = card

	local triageLabel = Instance.new("TextLabel")
	triageLabel.Size = UDim2.new(1, -20, 0, 25) -- Increased height to 25
	triageLabel.Position = UDim2.new(0, 10, 0, 35) -- Shifted down to accommodate new sizes
	triageLabel.BackgroundTransparency = 1
	triageLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	triageLabel.Font = Enum.Font.Gotham
	triageLabel.TextXAlignment = Enum.TextXAlignment.Left
	triageLabel.TextScaled = true -- Forces text to scale to the box size
	triageLabel.Text = "You chose: " .. mistakeData.chosen .. " | Correct: " .. mistakeData.correct
	triageLabel.Parent = card

	-- Optional: Add a constraint so TextScaled doesn't get ridiculously huge on 4K monitors
	local nameConstraint = Instance.new("UITextSizeConstraint")
	nameConstraint.MaxTextSize = 24
	nameConstraint.Parent = nameLabel

	local triageConstraint = Instance.new("UITextSizeConstraint")
	triageConstraint.MaxTextSize = 18
	triageConstraint.Parent = triageLabel
end

sessionRemote.OnClientEvent:Connect(function(data)
	local gui = getEndScreen()
	local mainFrame = gui:WaitForChild("MainFrame")
	local scoreText = mainFrame:WaitForChild("ScoreText")
	local statsText = mainFrame:WaitForChild("StatsText")
	local mistakesList = mainFrame:WaitForChild("MistakesList")
	local mainMenuBtn = mainFrame:WaitForChild("MainMenuButton")

	-- Populate Stats
	scoreText.Text = "Final Score: " .. data.totalScore
	statsText.Text = string.format("Correct: %d | Wrong: %d", data.correctCount, data.wrongCount)

	-- Destroys all previous text labels and frames, but leave the UIListLayout alone
	for _, child in ipairs(mistakesList:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then 
			child:Destroy() 
		end
	end

	-- Populate new mistakes
	if data.mistakes and #data.mistakes > 0 then
		for _, mistake in ipairs(data.mistakes) do
			buildMistakeCard(mistakesList, mistake)
		end
	else
		local perfectText = Instance.new("TextLabel")
		-- Uses a fixed height (100 pixels) instead of 100% scale so it doesn't break the scroll bar
		perfectText.Size = UDim2.new(1, 0, 0, 100) 
		perfectText.BackgroundTransparency = 1
		perfectText.TextColor3 = Color3.fromRGB(34, 197, 94)
		perfectText.Font = Enum.Font.GothamBold
		perfectText.Text = "Perfect Triage! No mistakes made."
		perfectText.Parent = mistakesList
	end

	-- Show GUI
	gui.Enabled = true

	-- Handle Return to Menu
	local conn
	conn = mainMenuBtn.MouseButton1Click:Connect(function()
		conn:Disconnect()
		gui.Enabled = false

		local returnRemote = RS:WaitForChild("ReturnToMenu")
		returnRemote:FireServer()
	end)
end)