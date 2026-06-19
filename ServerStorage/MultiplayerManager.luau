-- ServerStorage > MultiplayerManager (ModuleScript)

local MultiplayerManager = {}

local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local HospitalRegistry = require(SS:WaitForChild("HospitalRegistry"))

local ROUND_TIME = 60

local matchStartedRemote = RS:FindFirstChild("MultiplayerMatchStarted") or Instance.new("RemoteEvent", RS)
matchStartedRemote.Name = "MultiplayerMatchStarted"

local matchEndedRemote = RS:FindFirstChild("MultiplayerMatchEnded") or Instance.new("RemoteEvent", RS)
matchEndedRemote.Name = "MultiplayerMatchEnded"

local voteNextRemote = RS:FindFirstChild("VoteNextRound") or Instance.new("RemoteEvent", RS)
voteNextRemote.Name = "VoteNextRound"

local updateVotesRemote = RS:FindFirstChild("UpdateMPVotes") or Instance.new("RemoteEvent", RS)
updateVotesRemote.Name = "UpdateMPVotes"

local startMpSpawns = SS:FindFirstChild("StartMPSpawns") or Instance.new("BindableEvent", SS)
startMpSpawns.Name = "StartMPSpawns"

local cleanupMpSpawns = SS:FindFirstChild("CleanupMPSpawns") or Instance.new("BindableEvent", SS)
cleanupMpSpawns.Name = "CleanupMPSpawns"

local startMpRound = SS:WaitForChild("StartMPRound")
local endMpRound = SS:WaitForChild("EndMPRound")

local iotAdjustMP = SS:FindFirstChild("IoTTimerAdjustMP")
if not iotAdjustMP then
	iotAdjustMP = Instance.new("BindableEvent")
	iotAdjustMP.Name = "IoTTimerAdjustMP"
	iotAdjustMP.Parent = SS
end

-- [FIX]: Reverted to standard parameters
function MultiplayerManager.StartMatch(allPlayers, hostPlayer)
	local hospital = HospitalRegistry.AssignMulti(allPlayers)
	if not hospital then return end

	local activePlayers = {}
	for _, p in ipairs(allPlayers) do table.insert(activePlayers, p) end

	task.spawn(function()
		local roundNum = 1

		while #activePlayers > 1 do
			print("[Multiplayer] Starting Round " .. roundNum)

			-- 1. Setup Round
			for i, player in ipairs(activePlayers) do
				if player and player.Parent then
					player:SetAttribute("InMultiplayer", true)
					player:SetAttribute("AssignedHospitalId", hospital.id)
					player:SetAttribute("AssignedBedIndex", i)

					-- [FIX]: Apply a generic mode text for the UI
					player:SetAttribute("CurrentScenarioMode", "Multiplayer Mode")

					startMpRound:Fire(player)
					
					local character = player.Character
					if character and character:FindFirstChild("HumanoidRootPart") then
						character.HumanoidRootPart.CFrame = CFrame.new(hospital.beds[i].position + Vector3.new(0, 3, 0))
					end

					matchStartedRemote:FireClient(player, ROUND_TIME)
					startMpSpawns:Fire(player, hospital.id, i)
				end
			end

			local timeLeft = ROUND_TIME
			local adjustConn = iotAdjustMP.Event:Connect(function(delta)
				timeLeft = math.clamp(timeLeft + delta, 0, 600)
				print(string.format("[Multiplayer] IoT timer adjust: %+d → %ds remaining", delta, timeLeft))
				for _, player in ipairs(activePlayers) do
					if player and player.Parent then
						matchStartedRemote:FireClient(player, timeLeft)
					end
				end
			end)

			while timeLeft > 0 do
				task.wait(1)
				timeLeft -= 1
			end

			adjustConn:Disconnect()

			local leaderboard = {}
			for i = #activePlayers, 1, -1 do
				local player = activePlayers[i]
				if player and player.Parent then
					player:SetAttribute("InMultiplayer", false)
					cleanupMpSpawns:Fire(player)

					table.insert(leaderboard, {
						playerObj = player,
						name = player.Name,
						score = player:GetAttribute("Score") or 0
					})
				else
					table.remove(activePlayers, i)
				end
			end

			table.sort(leaderboard, function(a, b) return a.score > b.score end)

			local isDraw = (#leaderboard > 1) and (leaderboard[1].score == leaderboard[#leaderboard].score)
			local eliminatedIndex = nil

			if #leaderboard > 1 and not isDraw then
				eliminatedIndex = #leaderboard
				local eliminatedPlayer = leaderboard[eliminatedIndex].playerObj

				local indexToRemove = table.find(activePlayers, eliminatedPlayer)
				if indexToRemove then
					table.remove(activePlayers, indexToRemove)
				end

				eliminatedPlayer:SetAttribute("SkipMainMenu", true)
				task.spawn(function()
					if eliminatedPlayer and eliminatedPlayer.Parent then
						eliminatedPlayer:LoadCharacter()
					end
				end)
			elseif isDraw then
				print("[Multiplayer] Round ended in a DRAW. No one eliminated.")
			end

			local isFinal = (#activePlayers <= 1)
			if isFinal and activePlayers[1] then
				local winner = activePlayers[1]
				winner:SetAttribute("SkipMainMenu", true)
				task.spawn(function()
					if winner and winner.Parent then
						winner:LoadCharacter()
					end
				end)
			end

			local clientLeaderboard = {}
			for i, entry in ipairs(leaderboard) do
				table.insert(clientLeaderboard, {
					name = entry.name,
					score = entry.score,
					isEliminated = (i == eliminatedIndex),
					isDraw = isDraw
				})
			end

			for _, pData in ipairs(leaderboard) do
				endMpRound:Fire(pData.playerObj)
				matchEndedRemote:FireClient(pData.playerObj, clientLeaderboard, isFinal)
			end

			if not isFinal then
				local maxVotes = #activePlayers
				local votes = {}
				local voteCount = 0
				local roundReadyEvent = Instance.new("BindableEvent")

				local conn = voteNextRemote.OnServerEvent:Connect(function(plr)
					if table.find(activePlayers, plr) and not votes[plr] then
						votes[plr] = true
						voteCount += 1

						for _, p in ipairs(activePlayers) do
							updateVotesRemote:FireClient(p, voteCount, maxVotes)
						end

						if voteCount >= maxVotes then
							roundReadyEvent:Fire()
						end
					end
				end)

				roundReadyEvent.Event:Wait()
				conn:Disconnect()
				roundReadyEvent:Destroy()

				roundNum += 1
			end
		end

		print("[Multiplayer] Tournament Finished!")
	end)
end

return MultiplayerManager