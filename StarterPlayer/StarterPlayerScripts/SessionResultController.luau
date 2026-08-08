-- SessionResultController (LocalScript)
-- StarterPlayerScripts

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player        = Players.LocalPlayer
local sessionRemote = RS:WaitForChild("SessionComplete")
local returnRemote  = RS:WaitForChild("ReturnToMenu")

local triggerRemote = RS:WaitForChild("TriggerCinematic")

-- ── Multiplayer match state ──────────────────────────────────────────────────
-- The Leaderboard panel is multiplayer-only. We track whether we're currently in
-- an MP match so singleplayer / endless results can hide any leftover MP rows.
local inMpMatch = false

local startCutsceneRemote = RS:WaitForChild("StartCutscene")
startCutsceneRemote.OnClientEvent:Connect(function()
	-- SP and Endless always run through the cinematic; MP never does.
	inMpMatch = false
end)

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

-- ── Button identity + connection management ─────────────────────────────────
-- The two action buttons in ThirdRowContainer are now identified by stable Name
-- (MainMenuButton / ActionButton) instead of their mutable .Text. ActionButton
-- is the shared slot that becomes "Try Again" (SP), "Play Again" (Endless), or
-- "Ready X/N" / "Waiting" (MP) depending on mode.
--
-- Every click connection we attach to these buttons is tracked here so we can
-- disconnect ALL of them before wiring a new results screen. This kills the old
-- bug where a leftover singleplayer "Try Again" connection stayed attached to the
-- button that MP later reused as its vote button, sending players into SP.
local activeButtonConns = {}

local function clearButtonConns()
	for _, c in ipairs(activeButtonConns) do
		if typeof(c) == "RBXScriptConnection" and c.Connected then
			c:Disconnect()
		end
	end
	table.clear(activeButtonConns)
end

local function trackConn(conn)
	table.insert(activeButtonConns, conn)
	return conn
end

local function getButtons(frame)
	local thirdRow = frame:WaitForChild("ThirdRowContainer")
	local mainMenuBtn = thirdRow:FindFirstChild("MainMenuButton")
	local actionBtn   = thirdRow:FindFirstChild("ActionButton")
	return mainMenuBtn, actionBtn
end

-- Disconnect any stale connections and put both buttons back to a known baseline
-- (visible, default text) before each results screen wires its own behavior.
local function resetButtons(frame)
	clearButtonConns()
	local mainMenuBtn, actionBtn = getButtons(frame)
	if mainMenuBtn then
		mainMenuBtn.Visible = true
		mainMenuBtn.Text     = "Main Menu"
	end
	if actionBtn then
		actionBtn.Visible         = true
		actionBtn.AutoButtonColor = true
		actionBtn.Text            = "Try Again"
	end
	return mainMenuBtn, actionBtn
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

	-- Leaderboard is multiplayer-only. For singleplayer / endless, hide it so
	-- leftover rows from a previous MP match don't linger on the results screen.
	if not inMpMatch then
		local lb = frame:FindFirstChild("Leaderboard", true)
		if lb then lb.Visible = false end
	end

	local firstRow  = frame:WaitForChild("FirstRowContainer")
	local secondRow = frame:WaitForChild("SecondRowContainer")

	-- ── Score ──────────────────────────────────────────────────────────────────
	local scoreUserContainer = firstRow:WaitForChild("ScoreUserContainer")


	local finalScoreText = scoreUserContainer:FindFirstChild("FinalScoreText", true)
	if finalScoreText then finalScoreText.Text = tostring(data.totalScore) end

	local possiblePTS = scoreUserContainer:FindFirstChild("PossiblePTSText", true)
	if possiblePTS then
		-- [NEW] Di endless, payload bawa bestStreak → tampilin rekor streak.
		-- Mode lain (normal/MP) gak ngirim bestStreak → teks "possible pts" seperti biasa.
		if data.bestStreak then
			possiblePTS.Text = "🔥 Streak terpanjang: " .. data.bestStreak
		else
			possiblePTS.Text = "out of " .. (data.totalPatients * 10) .. " possible pts"
		end
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
	-- In MP, TriageManager also fires SessionComplete (for the stats panel), but
	-- button wiring is matchEndedRemote's job. Skip SP button setup so we don't
	-- overwrite the vote button that matchEndedRemote will set up momentarily.
	if inMpMatch then
		gui.Enabled = true
		return
	end

	-- Reset to baseline + drop any leftover connections from a previous screen,
	-- then resolve the buttons by stable Name (not .Text).
	local mainMenuBtn, tryAgainBtn = resetButtons(frame)

	gui.Enabled = true

	if mainMenuBtn then
		local conn
		conn = mainMenuBtn.MouseButton1Click:Connect(function()
			if conn then conn:Disconnect() end
			gui.Enabled = false
			local mainMenuGui = player.PlayerGui:FindFirstChild("MainMenuGui")
			if mainMenuGui then mainMenuGui.Enabled = true end
			returnRemote:FireServer()
		end)
		trackConn(conn)
	end

	if tryAgainBtn then
		local isEndless = player:GetAttribute("InEndless") == false 
			and player:GetAttribute("CurrentScenarioId") == "endless"

		if isEndless then
			tryAgainBtn.Text = "Play Again"
			local conn
			conn = tryAgainBtn.MouseButton1Click:Connect(function()
				if conn then conn:Disconnect() end
				gui.Enabled = false
				player:SetAttribute("SkipMainMenu", true)
				returnRemote:FireServer()
				player.CharacterAdded:Wait()
				task.wait(0.5)
				triggerRemote:FireServer("endless")
			end)
			trackConn(conn)
		else
			local conn
			conn = tryAgainBtn.MouseButton1Click:Connect(function()
				if conn then conn:Disconnect() end
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
			trackConn(conn)
		end
	end
end)

-- ── Multiplayer Match Ended (True Leaderboard Integration) ──────────────────
local matchEndedRemote   = RS:WaitForChild("MultiplayerMatchEnded", 5) or Instance.new("RemoteEvent")
local matchStartedRemote = RS:WaitForChild("MultiplayerMatchStarted", 5) or Instance.new("RemoteEvent")
local updateVotesRemote = RS:WaitForChild("UpdateMPVotes", 5) or Instance.new("RemoteEvent")

-- [FIX]: Automatically hide the End Screen when the next round begins
matchStartedRemote.OnClientEvent:Connect(function()
	inMpMatch = true -- we're in an MP match → leaderboard panel is valid
	clearButtonConns() -- old vote/menu connections from the previous round are now stale
	local gui = getGui()
	if gui then gui.Enabled = false end
end)

-- [NEW]: Handle live vote updates securely
updateVotesRemote.OnClientEvent:Connect(function(current, max)
	local gui = getGui()
	if not gui then return end
	local frame = gui:FindFirstChild("SessionResultFrame")
	if not frame then return end
	local thirdRow = frame:FindFirstChild("ThirdRowContainer", true)
	if not thirdRow then return end

	-- Resolve the vote button by stable Name instead of guessing from .Text.
	local actionBtn = thirdRow:FindFirstChild("ActionButton")
	if actionBtn then
		if hasVotedLocally then
			actionBtn.Text = "Waiting " .. current .. "/" .. max
		else
			actionBtn.Text = "Ready " .. current .. "/" .. max
		end
	end
end)

-- ── Leaderboard (multiplayer) helpers ───────────────────────────────────────
local function loadLeaderboardAvatar(imageLabel, userName)
	if not imageLabel then return end
	task.spawn(function()
		local ok, userId = pcall(function()
			return Players:GetUserIdFromNameAsync(userName)
		end)
		if not ok or not userId then return end
		local ok2, img = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		end)
		if ok2 and img and imageLabel.Parent then
			imageLabel.Image = img
		end
	end)
end

-- Fills one cloned RowTemplate.
-- Layout assumed (matches your template):
--   RowTemplate
--     ImageLabel            (avatar)
--     Frame                 (text column: name on top, @handle below)
--       LeaderboardLabel    (display name → top)
--       LeaderboardLabel    (@username + status → bottom)
--     LeaderboardLabel      (score, directly on the row)
-- Labels inside the Frame are resolved by vertical position, so if your top/bottom
-- come out swapped just flip labels[1] / labels[2] below.
local function fillLeaderboardRow(row, pData, rank, localName)
	row.Visible     = true
	row.Name        = "LBRow_" .. rank
	row.LayoutOrder = rank

	local isYou      = (pData.name == localName)
	local handle     = "@" .. (pData.name or "?")
	local shownName  = pData.displayName or pData.name or "?"

	-- Row tint by status.
	if pData.isEliminated then
		row.BackgroundColor3 = Color3.fromRGB(120, 38, 38)
	elseif isYou then
		row.BackgroundColor3 = Color3.fromRGB(40, 52, 70)
	else
		row.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
	end

	-- Avatar.
	loadLeaderboardAvatar(row:FindFirstChildWhichIsA("ImageLabel", true), pData.name)

	-- Score = the TextLabel sitting directly on the row (not inside the text column).
	local scoreLabel
	for _, c in ipairs(row:GetChildren()) do
		if c:IsA("TextLabel") then scoreLabel = c break end
	end

	-- Name + handle = the two labels inside the inner text-column Frame.
	local nameLabel, handleLabel
	local infoFrame = row:FindFirstChildWhichIsA("Frame")
	if infoFrame then
		local labels = {}
		for _, c in ipairs(infoFrame:GetChildren()) do
			if c:IsA("TextLabel") then table.insert(labels, c) end
		end
		table.sort(labels, function(a, b)
			if a.LayoutOrder ~= b.LayoutOrder then return a.LayoutOrder < b.LayoutOrder end
			return (a.Position.Y.Scale + a.Position.Y.Offset) < (b.Position.Y.Scale + b.Position.Y.Offset)
		end)
		nameLabel, handleLabel = labels[1], labels[2]
	end

	local medals = { "🥇", "🥈", "🥉" }
	local prefix = medals[rank] or (rank .. ".")

	if nameLabel then
		nameLabel.Text       = prefix .. " " .. shownName .. (isYou and " (You)" or "")
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
	end

	if handleLabel then
		-- Bottom line shows the @handle, with match status appended + colored.
		if pData.isEliminated then
			handleLabel.Text       = handle .. "  ·  Tersingkir"
			handleLabel.TextColor3 = Color3.fromRGB(239, 68, 68)
		elseif pData.isDraw then
			handleLabel.Text       = handle .. "  ·  Seri"
			handleLabel.TextColor3 = Color3.fromRGB(234, 179, 8)
		else
			handleLabel.Text       = handle .. "  ·  Aman"
			handleLabel.TextColor3 = Color3.fromRGB(34, 197, 94)
		end
	end

	if scoreLabel then
		scoreLabel.Text       = tostring(pData.score)
		scoreLabel.TextColor3 = Color3.new(1, 1, 1)
	end
end

matchEndedRemote.OnClientEvent:Connect(function(leaderboardData, isFinal)
	hasVotedLocally = false -- [FIX]: Reset vote state for the new round

	local gui = getGui()
	local frame = gui:WaitForChild("SessionResultFrame")
	local leaderboardFrame = frame:FindFirstChild("LeaderboardFrame", true) or frame:FindFirstChild("Leaderboard", true)
	local isLocallyEliminated = false

	if leaderboardFrame then
		leaderboardFrame.Visible = true

		local container   = leaderboardFrame:FindFirstChildWhichIsA("ScrollingFrame", true) or leaderboardFrame
		local rowTemplate = container:FindFirstChild("RowTemplate", true)

		-- Clear previous clones, but DO NOT destroy the template.
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Frame") and child ~= rowTemplate then
				child:Destroy()
			elseif child:IsA("TextLabel") then
				child:Destroy()  -- stray labels from old hand-built rows
			end
		end

		if rowTemplate then
			rowTemplate.Visible = false
			container.AutomaticCanvasSize = Enum.AutomaticSize.Y
			container.CanvasSize = UDim2.new(0, 0, 0, 0)
		end

		for i, pData in ipairs(leaderboardData) do
			if pData.name == player.Name and pData.isEliminated then
				isLocallyEliminated = true
			end

			if rowTemplate then
				local row = rowTemplate:Clone()
				row.Parent = container
				fillLeaderboardRow(row, pData, i, player.Name)
			else
				-- Fallback if the template is missing.
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, -10, 0, 40)
				row.BackgroundColor3 = pData.isEliminated and Color3.fromRGB(120, 38, 38) or Color3.fromRGB(40, 40, 40)
				row.LayoutOrder = i
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
				nameLabel.Text = i .. ". " .. (pData.displayName or pData.name)
					.. (pData.name == player.Name and " (You)" or "")
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

	-- ── Buttons ────────────────────────────────────────────────────────────────
	-- Reset to baseline + drop any leftover connections (including a stale SP
	-- "Try Again" connection on ActionButton) before wiring MP behavior. Buttons
	-- are resolved by stable Name, never by .Text.
	local mainMenuBtn, actionBtn = resetButtons(frame)

	if actionBtn then
		if isLocallyEliminated or isFinal then
			actionBtn.Visible = false
		else
			actionBtn.Visible = true
			-- [FIX]: Show the correct survivor count right away
			actionBtn.Text = "Ready 0/" .. survivorCount
			actionBtn.AutoButtonColor = true

			trackConn(actionBtn.MouseButton1Click:Connect(function()
				hasVotedLocally = true
				actionBtn.AutoButtonColor = false

				-- Set an optimistic temporary text; the server update will overwrite it instantly
				actionBtn.Text = "Waiting..."
				RS:WaitForChild("VoteNextRound"):FireServer()
			end))
		end
	end

	if mainMenuBtn then
		if not isLocallyEliminated and not isFinal then
			mainMenuBtn.Visible = false
		else
			mainMenuBtn.Visible = true
			mainMenuBtn.Text = "Main Menu"
		end

		local conn
		conn = mainMenuBtn.MouseButton1Click:Connect(function()
			if conn then conn:Disconnect() end
			gui.Enabled = false

			local mainMenuGui = player.PlayerGui:FindFirstChild("MainMenuGui")
			if mainMenuGui then mainMenuGui.Enabled = true end

			-- No skipRespawn arg: the server respawns the player back to the menu
			-- spawn. Passing true here skips that respawn and leaves the character
			-- stranded in the match world, so the menu never properly opens.
			returnRemote:FireServer()
		end)
		trackConn(conn)
	end

	gui.Enabled = true
end)
