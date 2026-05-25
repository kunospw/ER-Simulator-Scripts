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
		pointsText.Text       = data.isCorrect and "+10" or "-5"
		pointsText.TextColor3 = data.isCorrect
			and Color3.fromRGB(34, 197, 94)
			or  Color3.fromRGB(239, 68, 68)
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
end)