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

local triaged              = {}
local scenarioPatientCount = {}
local mistakes             = {}
local allSubmissions       = {}

sessionEvent.Event:Connect(function(player, count)
	scenarioPatientCount[player] = count
	triaged[player]              = {}
	allSubmissions[player]       = {}
	mistakes[player]             = {}
	player:SetAttribute("Score",             0)
	player:SetAttribute("CorrectCount",      0)
	player:SetAttribute("WrongCount",        0)
	player:SetAttribute("PatientsRemaining", count)

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
	local isCorrect     = (chosenTriage == correctTriage)
	local pointsDelta   = isCorrect and 10 or -5

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
		player:SetAttribute("PatientsRemaining", (player:GetAttribute("PatientsRemaining") or 1) - 1)
	else
		player:SetAttribute("WrongCount", (player:GetAttribute("WrongCount") or 0) + 1)
		table.insert(mistakes[player], {
			name         = targetNPC.Name,
			diagnosis    = targetNPC:GetAttribute("Diagnosis") or "Unknown",
			chosen       = chosenTriage,
			correct      = correctTriage,
			responseTime = responseTime,

		})
	end

	if isCorrect then
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

	if totalPatients > 0 and totalTriaged >= totalPatients then
		print("[TriageManager] SCENARIO COMPLETE!")
		task.wait(2.5)
		sessionRemote:FireClient(player, {
			totalScore     = player:GetAttribute("Score"),
			correctCount   = player:GetAttribute("CorrectCount"),
			wrongCount     = player:GetAttribute("WrongCount"),
			totalPatients  = totalPatients,
			mistakes       = mistakes[player],
			allSubmissions = allSubmissions[player],
		})
	end
end)

returnRemote.OnServerEvent:Connect(function(player)
	HospitalRegistry.Release(player)

	triaged[player]              = {}
	scenarioPatientCount[player] = 0
	mistakes[player]             = {}
	allSubmissions[player]       = {}
	player:SetAttribute("Score",             0)
	player:SetAttribute("CorrectCount",      0)
	player:SetAttribute("WrongCount",        0)
	player:SetAttribute("PatientsRemaining", 0)
	player:LoadCharacterAsync()

end)
