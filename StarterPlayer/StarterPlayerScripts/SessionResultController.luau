-- SessionResultController (LocalScript)
-- StarterPlayerScripts

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player        = Players.LocalPlayer
local sessionRemote = RS:WaitForChild("SessionComplete")
local returnRemote  = RS:WaitForChild("ReturnToMenu")

local triggerRemote = RS:WaitForChild("TriggerCinematic")

local triageColors = {
	RED    = Color3.fromRGB(239, 68, 68),
	YELLOW = Color3.fromRGB(234, 179, 8),
	GREEN  = Color3.fromRGB(34, 197, 94),
	BLACK  = Color3.fromRGB(60, 60, 60),
}

local hasVotedLocally = false

local function getGui()
	return player.PlayerGui:WaitForChild("SessoinResult")
end

local function buildPerformanceRow(scrollFrame, rowTemplate, data, index)
	local row   = rowTemplate:Clone()
	row.Name    = "Row_" .. index

	row.Visible = true

	local caseIDText = row:FindFirstChild("CaseIDText")
	if caseIDText then caseIDText.Text = "P" .. string.format("%03d", index) end

	local yourTriage = row:FindFirstChild("YourTriage", true)
	if yourTriage then
		local label = yourTriage:FindFirstChild("YourTriageText")
		if label then
			label.Text       = data.chosen
			label.TextColor3 = Color3.new(1, 1, 1)
		end
		yourTriage.BackgroundColor3 = triageColors[data.chosen] or Color3.fromRGB(100, 100, 100)
	end

	local correctTriage = row:FindFirstChild("CorrectTriage", true)
	if correctTriage then
		local label = correctTriage:FindFirstChild("CorrectTriageText")
		if label then
			label.Text       = data.correct
			label.TextColor3 = Color3.new(1, 1, 1)
		end
		correctTriage.BackgroundColor3 = triageColors[data.correct] or Color3.fromRGB(100, 100, 100)

		local icon = correctTriage:FindFirstChild("ResultIcon")
		if icon then
			icon.ImageColor3 = data.isCorrect
				and Color3.fromRGB(34, 197, 94)
				or  Color3.fromRGB(239, 68, 68)
		end
	end

	local responseTimeText = row:FindFirstChild("ResponseTimeText")
	if responseTimeText then
		responseTimeText.Text = data.responseTime or "—"
	end

	local pointsText = row:FindFirstChild("PointsText")
	if pointsText then
		if data.isCorrect then
			pointsText.Text = "+" .. tostring(data.points)
			pointsText.TextColor3 = Color3.fromRGB(34, 197, 94)
		else
			pointsText.Text = tostring(data.points)
			pointsText.TextColor3 = Color3.fromRGB(239, 68, 68)
		end
	end
	row.Parent = scrollFrame
end

sessionRemote.OnClientEvent:Connect(function(data)
	local gui   = getGui()
	local frame = gui:WaitForChild("SessionResultFrame")

	local firstRow  = frame:WaitForChild("FirstRowContainer")
	local secondRow = frame:WaitForChild("SecondRowContainer")
	local thirdRow  = frame:WaitForChild("ThirdRowContainer")

	-- ── Score ──────────────────────────────────────────────────────────────────
	local scoreUserContainer = firstRow:WaitForChild("ScoreUserContainer")


	local finalScoreText = scoreUserContainer:FindFirstChild("FinalScoreText", true)
	if finalScoreText then finalScoreText.Text = tostring(data.totalScore) end

	local possiblePTS = scoreUserContainer:FindFirstChild("PossiblePTSText", true)
	if possiblePTS then
		possiblePTS.Text = "out of " .. (data.totalPatients * 10) .. " possible pts"
	end

	-- ── Stats ──────────────────────────────────────────────────────────────────
	local scoreUser      = firstRow:WaitForChild("ScoreUser")
	local statsContainer = scoreUser:FindFirstChild("StatsContainer")

	if statsContainer then
		local totalAnswered = data.correctCount + data.wrongCount

		local casesFrame   = statsContainer:FindFirstChild("CasesFrame")
		local correctFrame = statsContainer:FindFirstChild("CorrectFrame")
		local missedFrame  = statsContainer:FindFirstChild("MissedFrame")
		local avgTimeFrame = statsContainer:FindFirstChild("AvgTimeFrame")

		if casesFrame then
			local val = casesFrame:FindFirstChild("CasesNumberText")
			if val then val.Text = tostring(totalAnswered) end

		end
		if correctFrame then
			local val = correctFrame:FindFirstChild("CorrectNumberText")
			if val then val.Text = tostring(data.correctCount) end
		end
		if missedFrame then
			local val = missedFrame:FindFirstChild("MissedNumberText")
			if val then val.Text = tostring(data.wrongCount) end
		end
		if avgTimeFrame then
			local submissions = data.allSubmissions or {}
			local totalSecs   = 0
			local count       = 0
			for _, s in ipairs(submissions) do
				if s.responseTime and s.responseTime ~= "—" then
					local parts = string.split(s.responseTime, ":")
					if #parts == 2 then
						totalSecs = totalSecs + (tonumber(parts[1]) or 0) * 60 + (tonumber(parts[2]) or 0)
						count     = count + 1
					end
				end
			end
			local val = avgTimeFrame:FindFirstChild("AvgNumberText")
			if val then
				if count > 0 then
					local avg = totalSecs / count
					val.Text  = string.format("%02d:%02d", math.floor(avg / 60), math.floor(avg % 60))
				else
					val.Text = "—"
				end
			end
		end
	end

	-- ── Accuracy bar ───────────────────────────────────────────────────────────

	local totalAnswered = data.correctCount + data.wrongCount
	local accuracy = totalAnswered > 0
		and math.floor((data.correctCount / totalAnswered) * 100)
		or 0

	local textContainer = scoreUser:FindFirstChild("TextContainer")
	if textContainer then
		local innerTextContainer = textContainer:FindFirstChild("TextContainer")
		if innerTextContainer then
			local accuracyText = innerTextContainer:FindFirstChild("AccuracyText")
			if accuracyText then accuracyText.Text = accuracy .. "%" end

		end
		local canvasGroup = textContainer:FindFirstChild("CanvasGroup")
		if canvasGroup then
			local fill = canvasGroup:FindFirstChild("Fill")
			if fill then
				fill.Size = UDim2.new(0, 0, 1, 0)
				TweenService:Create(fill,
					TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = UDim2.new(accuracy / 100, 0, 1, 0) }
				):Play()
			end
		end
	end

	-- ── Performance Breakdown ──────────────────────────────────────────────────
	local pbContainer = secondRow:WaitForChild("PerformanceBreakdownContainer")
	local pb          = pbContainer:WaitForChild("PerformanceBreakdown")
	local table_      = pb:WaitForChild("Table")
	local scrollFrame = table_:WaitForChild("ScrollingFrame")
	local rowTemplate = scrollFrame:WaitForChild("RowTemplate")

	rowTemplate.Visible = false 


	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "RowTemplate" then
			child:Destroy()
		end
	end

	local submissions = data.allSubmissions or data.mistakes or {}
	for i, submission in ipairs(submissions) do
		buildPerformanceRow(scrollFrame, rowTemplate, submission, i)
	end

	-- ── Buttons ────────────────────────────────────────────────────────────────
	local mainMenuBtn, tryAgainBtn
	for _, btn in ipairs(thirdRow:GetChildren()) do
		if btn:IsA("TextButton") then
			if btn.Text == "Main Menu" then
				mainMenuBtn = btn
			elseif btn.Text == "Try Again" then
				tryAgainBtn = btn
			end
		end
	end


	gui.Enabled = true

	if mainMenuBtn then
		local conn
		conn = mainMenuBtn.MouseButton1Click:Connect(function()
			conn:Disconnect()
			gui.Enabled = false
			local mainMenuGui = player.PlayerGui:FindFirstChild("MainMenuGui")
			if mainMenuGui then mainMenuGui.Enabled = true end
			returnRemote:FireServer()
		end)
	end

	if tryAgainBtn then
		local isEndless = player:GetAttribute("InEndless") == false 
			and player:GetAttribute("CurrentScenarioId") == "endless"

		if isEndless then
			tryAgainBtn.Text = "Play Again"
			local conn
			conn = tryAgainBtn.MouseButton1Click:Connect(function()
				conn:Disconnect()
				gui.Enabled = false
				player:SetAttribute("SkipMainMenu", true)
				returnRemote:FireServer()
				player.CharacterAdded:Wait()
				task.wait(0.5)
				triggerRemote:FireServer("endless")
			end)
		else
			local conn
			conn = tryAgainBtn.MouseButton1Click:Connect(function()
				conn:Disconnect()
				gui.Enabled = false
				local scenarioId = player.PlayerGui:FindFirstChild("ScenarioScreen")
					and player.PlayerGui.ScenarioScreen:GetAttribute("ScenarioId")
					or "food_poisoning"
				player:SetAttribute("SkipMainMenu", true)
				returnRemote:FireServer()
				player.CharacterAdded:Wait()
				task.wait(0.5)
				triggerRemote:FireServer(scenarioId)
			end)
		end
	end
end)

-- ── Multiplayer Match Ended (True Leaderboard Integration) ──────────────────
local matchEndedRemote   = RS:WaitForChild("MultiplayerMatchEnded", 5) or Instance.new("RemoteEvent")
local matchStartedRemote = RS:WaitForChild("MultiplayerMatchStarted", 5) or Instance.new("RemoteEvent")
local updateVotesRemote = RS:WaitForChild("UpdateMPVotes", 5) or Instance.new("RemoteEvent")

-- [FIX]: Automatically hide the End Screen when the next round begins
matchStartedRemote.OnClientEvent:Connect(function()
	local gui = getGui()
	if gui then gui.Enabled = false end
end)

-- [NEW]: Handle live vote updates securely
updateVotesRemote.OnClientEvent:Connect(function(current, max)
	local gui = getGui()
	if not gui then return end
	local thirdRow = gui.SessionResultFrame:FindFirstChild("ThirdRowContainer", true)

	if thirdRow then
		for _, btn in ipairs(thirdRow:GetChildren()) do
			-- [FIX]: Ignore what the text currently says. If it's a TextButton and it's NOT the Main Menu button, it is the Vote button.
			if btn:IsA("TextButton") and not btn.Text:match("Menu") then
				if hasVotedLocally then
					btn.Text = "Waiting " .. current .. "/" .. max
				else
					btn.Text = "Ready " .. current .. "/" .. max
				end
			end
		end
	end
end)

matchEndedRemote.OnClientEvent:Connect(function(leaderboardData, isFinal)
	hasVotedLocally = false -- [FIX]: Reset vote state for the new round

	local gui = getGui()
	local frame = gui:WaitForChild("SessionResultFrame")
	local leaderboardFrame = frame:FindFirstChild("LeaderboardFrame", true) or frame:FindFirstChild("Leaderboard", true)
	local isLocallyEliminated = false

	if leaderboardFrame then
		local container = leaderboardFrame:FindFirstChildWhichIsA("ScrollingFrame") or leaderboardFrame

		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end

		for i, pData in ipairs(leaderboardData) do
			if pData.name == player.Name and pData.isEliminated then
				isLocallyEliminated = true
			end

			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -10, 0, 40)
			row.BackgroundColor3 = pData.isEliminated and Color3.fromRGB(150, 40, 40) or Color3.fromRGB(40, 40, 40)
			row.Parent = container
			Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0.7, 0, 1, 0)
			nameLabel.Position = UDim2.new(0, 10, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			nameLabel.TextSize = 14
			nameLabel.Text = pData.name .. (pData.name == player.Name and " (You)" or "")
			nameLabel.Parent = row

			local scoreLabel = Instance.new("TextLabel")
			scoreLabel.Size = UDim2.new(0.3, -10, 1, 0)
			scoreLabel.Position = UDim2.new(0.7, 0, 0, 0)
			scoreLabel.BackgroundTransparency = 1
			scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
			scoreLabel.Font = Enum.Font.GothamBold
			scoreLabel.TextColor3 = Color3.new(1, 1, 1)
			scoreLabel.TextSize = 14
			scoreLabel.Text = tostring(pData.score)
			scoreLabel.Parent = row

			local pointsText = row:FindFirstChild("PointsText")
			if pointsText then
				if pData.isEliminated then
					pointsText.Text = "ELIMINATED"
					pointsText.TextColor3 = Color3.fromRGB(239, 68, 68)
				elseif pData.isDraw then
					pointsText.Text = "DRAW"
					pointsText.TextColor3 = Color3.fromRGB(234, 179, 8)
				else
					pointsText.Text = "SAFE"
					pointsText.TextColor3 = Color3.fromRGB(34, 197, 94)
				end
			end
		end
	end

	-- [FIX]: Count how many players actually survived to set the correct max vote count
	local survivorCount = 0
	for _, p in ipairs(leaderboardData) do
		if not p.isEliminated then
			survivorCount += 1
		end
	end

	-- Buttons Handle
	local thirdRow = frame:WaitForChild("ThirdRowContainer")
	local mainMenuBtn, tryAgainBtn

	for _, btn in ipairs(thirdRow:GetChildren()) do
		if btn:IsA("TextButton") then
			if btn.Text:match("Menu") then
				mainMenuBtn = btn
			elseif btn.Text:match("Try") or btn.Text:match("Ready") or btn.Text:match("Waiting") then
				tryAgainBtn = btn
			end
		end
	end

	if tryAgainBtn then
		if isLocallyEliminated or isFinal then
			tryAgainBtn.Visible = false
		else
			tryAgainBtn.Visible = true
			-- [FIX]: Show the correct survivor count right away
			tryAgainBtn.Text = "Ready 0/" .. survivorCount
			tryAgainBtn.AutoButtonColor = true

			if _G.VoteConn then _G.VoteConn:Disconnect() end
			_G.VoteConn = tryAgainBtn.MouseButton1Click:Connect(function()
				hasVotedLocally = true
				tryAgainBtn.AutoButtonColor = false

				-- Set an optimistic temporary text; the server update will overwrite it instantly
				tryAgainBtn.Text = "Waiting..." 
				RS:WaitForChild("VoteNextRound"):FireServer()
			end)
		end
	end

	if mainMenuBtn then
		if _G.MainMenuConn then _G.MainMenuConn:Disconnect() end

		if not isLocallyEliminated and not isFinal then
			mainMenuBtn.Visible = false
		else
			mainMenuBtn.Visible = true
			mainMenuBtn.Text = "Main Menu"
		end

		_G.MainMenuConn = mainMenuBtn.MouseButton1Click:Connect(function()
			_G.MainMenuConn:Disconnect()
			gui.Enabled = false

			if tryAgainBtn then 
				tryAgainBtn.Visible = true 
				tryAgainBtn.Text = "Try Again"
			end
			mainMenuBtn.Visible = true

			local mainMenuGui = player.PlayerGui:FindFirstChild("MainMenuGui")
			if mainMenuGui then mainMenuGui.Enabled = true end

			returnRemote:FireServer(true)
		end)
	end

	gui.Enabled = true
end)