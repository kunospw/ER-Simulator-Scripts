-- ServerScriptService > TriageManager (Script)

local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService  = game:GetService("TweenService")
local SS            = game:GetService("ServerStorage")

local submitRemote   = RS:WaitForChild("SubmitTriage")
local resultRemote   = RS:WaitForChild("TriageResult")
local sessionRemote  = RS:WaitForChild("SessionComplete")
local returnRemote   = RS:WaitForChild("ReturnToMenu")
local patientCleared = SS:WaitForChild("PatientCleared")
local sessionEvent   = ServerStorage:WaitForChild("PatientSessionStarted")
local HospitalRegistry = require(SS:WaitForChild("HospitalRegistry"))
local DataStoreManager = require(SS:WaitForChild("DataStoreManager"))

local triaged              = {}
local scenarioPatientCount = {}
local mistakes             = {}
local allSubmissions       = {}

local startMpRound = Instance.new("BindableEvent", SS)
startMpRound.Name = "StartMPRound"

local endMpRound = Instance.new("BindableEvent", SS)
endMpRound.Name = "EndMPRound"

-- Resets stats at the start of a round
startMpRound.Event:Connect(function(player)
	mistakes[player] = {}
	allSubmissions[player] = {}
	triaged[player] = {}
	player:SetAttribute("Score", 0)
	player:SetAttribute("CorrectCount", 0)
	player:SetAttribute("WrongCount", 0)
	player:SetAttribute("Streak", 0)
end)

-- Fires the SessionResult stats normally when a multiplayer round ends
endMpRound.Event:Connect(function(player)
	local totalAnswered = (player:GetAttribute("CorrectCount") or 0) + (player:GetAttribute("WrongCount") or 0)
	sessionRemote:FireClient(player, {
		totalScore     = player:GetAttribute("Score"),
		correctCount   = player:GetAttribute("CorrectCount"),
		wrongCount     = player:GetAttribute("WrongCount"),
		totalPatients  = totalAnswered,
		mistakes       = mistakes[player] or {},
		allSubmissions = allSubmissions[player] or {},
	})
end)

sessionEvent.Event:Connect(function(player, count)
	scenarioPatientCount[player] = count
	triaged[player]              = {}
	allSubmissions[player]       = {}
	mistakes[player]             = {}
	player:SetAttribute("Score",             0)
	player:SetAttribute("CorrectCount",      0)
	player:SetAttribute("WrongCount",        0)
	player:SetAttribute("PatientsRemaining", count)
	player:SetAttribute("Streak",            0)
	player:SetAttribute("BestStreak",        0)

	print("[TriageManager] Session started —", player.Name, "—", count, "patients")
end)


Players.PlayerAdded:Connect(function(player)
	triaged[player]              = {}
	scenarioPatientCount[player] = 0
	allSubmissions[player]       = {}
	mistakes[player]             = {}
	player:SetAttribute("Score",             0)
	player:SetAttribute("CorrectCount",      0)
	player:SetAttribute("WrongCount",        0)
	player:SetAttribute("PatientsRemaining", 0)
	player:SetAttribute("Streak",            0)
	player:SetAttribute("BestStreak",        0)
	DataStoreManager.InitPlayer(player)

end)

Players.PlayerRemoving:Connect(function(player)
	triaged[player]              = nil
	scenarioPatientCount[player] = nil
	mistakes[player]             = nil
	allSubmissions[player]       = nil

end)

submitRemote.OnServerEvent:Connect(function(player, patientId, chosenTriage)
	if not triaged[player] then triaged[player] = {} end

	if triaged[player][patientId] then
		warn("[TriageManager] Already triaged:", patientId)
		return
	end

	local targetNPC = nil
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:GetAttribute("PatientID") == patientId then
			targetNPC = obj
			break
		end
	end

	if not targetNPC then
		warn("[TriageManager] NPC not found:", patientId)
		return
	end

	-- Response time calculation
	local spawnTime   = targetNPC:GetAttribute("SpawnTime") or os.clock()
	local elapsed     = os.clock() - spawnTime
	local mm          = math.floor(elapsed / 60)
	local ss          = math.floor(elapsed % 60)
	local responseTime = string.format("%02d:%02d", mm, ss)

	local correctTriage = targetNPC:GetAttribute("CorrectTriage")
	local isTimeout     = (chosenTriage == "TIMEOUT")
	local isCorrect     = (not isTimeout) and (chosenTriage == correctTriage)

	-- Multiplayer Scoring Logic
	local pointsDelta = 0
	local TIME_LIMIT = 15
	print(string.format("[TriageManager] %s | patient: %s | chosen: %s | correct: %s | elapsed: %.1fs | points: %d",
		player.Name, patientId, chosenTriage, correctTriage, elapsed, pointsDelta))
	if player:GetAttribute("InMultiplayer") then
		if isCorrect then
			if elapsed <= TIME_LIMIT then
				pointsDelta = 15
			else
				pointsDelta = 7
			end
		else
			pointsDelta = -5
		end
	else
		-- Singleplayer Scoring
		if isTimeout then
			pointsDelta = -20
		elseif isCorrect then
			if elapsed <= TIME_LIMIT then
				pointsDelta = 15 
			else
				pointsDelta = 10
			end
		else
			pointsDelta = -5
		end
	end

	local currentScore = player:GetAttribute("Score") or 0
	player:SetAttribute("Score", currentScore + pointsDelta)

	-- Track all submissions
	if not allSubmissions[player] then allSubmissions[player] = {} end
	table.insert(allSubmissions[player], {
		patientId    = patientId,
		name         = targetNPC.Name,
		diagnosis    = targetNPC:GetAttribute("Diagnosis") or "",
		chosen       = chosenTriage,
		correct      = correctTriage,
		isCorrect    = isCorrect,
		points       = pointsDelta,
		responseTime = responseTime,
	})

	if isCorrect then
		player:SetAttribute("CorrectCount", (player:GetAttribute("CorrectCount") or 0) + 1)

		-- streak naik + simpen rekor
		local newStreak = (player:GetAttribute("Streak") or 0) + 1
		player:SetAttribute("Streak", newStreak)
		if newStreak > (player:GetAttribute("BestStreak") or 0) then
			player:SetAttribute("BestStreak", newStreak)
		end

		if not player:GetAttribute("InEndless") then
			player:SetAttribute("PatientsRemaining", (player:GetAttribute("PatientsRemaining") or 1) - 1)
		end
	else
		player:SetAttribute("WrongCount", (player:GetAttribute("WrongCount") or 0) + 1)
		player:SetAttribute("Streak", 0)   -- salah/timeout → streak putus

		table.insert(mistakes[player], {
			name         = targetNPC.Name,
			diagnosis    = targetNPC:GetAttribute("Diagnosis") or "Unknown",
			chosen       = chosenTriage,
			correct      = correctTriage,
			responseTime = responseTime,
		})
	end

	if isCorrect or isTimeout then
		triaged[player][patientId] = true
		targetNPC:SetAttribute("Triaged", true)
		local slotIndex = targetNPC:GetAttribute("SlotIndex")

		task.delay(1.5, function()
			if not targetNPC or not targetNPC.Parent then return end
			for _, part in ipairs(targetNPC:GetDescendants()) do
				if part:IsA("BasePart") then
					TweenService:Create(part,
						TweenInfo.new(0.6, Enum.EasingStyle.Quad),
						{ Transparency = 1 }
					):Play()
				end
			end
			task.wait(0.7)
			if targetNPC and targetNPC.Parent then targetNPC:Destroy() end
			if slotIndex then patientCleared:Fire(player, slotIndex) end
		end)
	end

	resultRemote:FireClient(player, {
		patientId    = patientId,
		chosen       = chosenTriage,
		correct      = correctTriage,
		isCorrect    = isCorrect,
		pointsDelta  = pointsDelta,
		totalScore   = player:GetAttribute("Score"),
		diagnosis    = targetNPC:GetAttribute("Diagnosis") or "",
		targetRoom   = targetNPC:GetAttribute("TargetRoom") or "",
		responseTime = responseTime,

	})

	local totalTriaged = 0
	for _ in pairs(triaged[player]) do totalTriaged += 1 end

	local totalPatients = scenarioPatientCount[player] or 0
	print(string.format("[TriageManager] %d/%d triaged", totalTriaged, totalPatients))

	-- [NEW]: Only trigger the single-player end screen if they aren't in multiplayer
	if not player:GetAttribute("InMultiplayer") and not player:GetAttribute("InEndless") then
		if totalPatients > 0 and totalTriaged >= totalPatients then
			print("[TriageManager] SCENARIO COMPLETE!")
			task.wait(2.5)
			local scenario = require(RS:WaitForChild("ScenarioData")).GetScenario(
				player:GetAttribute("CurrentScenarioId") or "food_poisoning")
			local totalAnswered = (player:GetAttribute("CorrectCount") or 0) 
				+ (player:GetAttribute("WrongCount") or 0)
			local accuracy = totalAnswered > 0 
				and ((player:GetAttribute("CorrectCount") or 0) / totalAnswered * 100) or 0
			task.spawn(function()
				DataStoreManager.SaveSession(player, {
					scenarioId     = player:GetAttribute("CurrentScenarioId") or "",
					mode           = scenario and scenario.mode or "",
					totalScore     = player:GetAttribute("Score"),
					accuracy       = accuracy,
					correctCount   = player:GetAttribute("CorrectCount"),
					wrongCount     = player:GetAttribute("WrongCount"),
					totalPatients  = totalPatients,
					allSubmissions = allSubmissions[player],
				})
			end)
			sessionRemote:FireClient(player, {
				totalScore     = player:GetAttribute("Score"),
				correctCount   = player:GetAttribute("CorrectCount"),
				wrongCount     = player:GetAttribute("WrongCount"),
				totalPatients  = totalPatients,
				mistakes       = mistakes[player],
				allSubmissions = allSubmissions[player],
				bestStreak     = player:GetAttribute("BestStreak") or 0, 
			})
		end
	end
end)
local endlessEndRemote = RS:FindFirstChild("EndlessEnd")
if not endlessEndRemote then
	endlessEndRemote = Instance.new("RemoteEvent")
	endlessEndRemote.Name = "EndlessEnd"
	endlessEndRemote.Parent = RS
end

endlessEndRemote.OnServerEvent:Connect(function(player)
	local EndlessMode = require(game:GetService("ServerScriptService"):WaitForChild("EndlessMode"))
	EndlessMode.Stop(player)

	local totalTriaged = player:GetAttribute("CorrectCount") or 0
	local totalAnswered = (player:GetAttribute("CorrectCount") or 0) + (player:GetAttribute("WrongCount") or 0)
	local accuracy = totalAnswered > 0
		and ((player:GetAttribute("CorrectCount") or 0) / totalAnswered * 100) or 0

	task.spawn(function()
		local DataStoreManager = require(game:GetService("ServerStorage"):WaitForChild("DataStoreManager"))
		DataStoreManager.SaveSession(player, {
			scenarioId     = "endless",
			mode           = "Endless Mode",
			totalScore     = player:GetAttribute("Score"),
			accuracy       = accuracy,
			correctCount   = player:GetAttribute("CorrectCount"),
			wrongCount     = player:GetAttribute("WrongCount"),
			totalPatients  = totalAnswered,
			allSubmissions = allSubmissions[player] or {},
		})
	end)

	sessionRemote:FireClient(player, {
		totalScore     = player:GetAttribute("Score"),
		correctCount   = player:GetAttribute("CorrectCount"),
		wrongCount     = player:GetAttribute("WrongCount"),
		totalPatients  = totalAnswered,
		mistakes       = mistakes[player] or {},
		allSubmissions = allSubmissions[player] or {},
	})
end)

returnRemote.OnServerEvent:Connect(function(player, skipRespawn)
	-- Stop endless mode dulu kalau masih jalan
	if player:GetAttribute("InEndless") then
		local ok, EndlessMode = pcall(function()
			return require(game:GetService("ServerScriptService"):WaitForChild("EndlessMode"))
		end)
		if ok and EndlessMode then
			EndlessMode.Stop(player)
		end
	end

	HospitalRegistry.Release(player)

	triaged[player]              = {}
	scenarioPatientCount[player] = 0
	mistakes[player]             = {}
	allSubmissions[player]       = {}
	player:SetAttribute("Score",             0)
	player:SetAttribute("CorrectCount",      0)
	player:SetAttribute("WrongCount",        0)
	player:SetAttribute("PatientsRemaining", 0)
	player:SetAttribute("Streak",            0)
	player:SetAttribute("BestStreak",        0)
	player:SetAttribute("InEndless",         false)
	player:SetAttribute("CurrentScenarioId", "")
	player:SetAttribute("CurrentScenarioMode", "")

	if not skipRespawn then
		player:LoadCharacterAsync()
	end
end)