-- MultiplayerManager (ModuleScript) — ServerStorage
local MultiplayerManager = {}

local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local HospitalRegistry = require(SS:WaitForChild("HospitalRegistry"))

local ROUND_TIME = 60

local matchStartedRemote = RS:FindFirstChild("MultiplayerMatchStarted") or Instance.new("RemoteEvent", RS)
matchStartedRemote.Name = "MultiplayerMatchStarted"

local matchEndedRemote = RS:FindFirstChild("MultiplayerMatchEnded") or Instance.new("RemoteEvent", RS)
matchEndedRemote.Name = "MultiplayerMatchEnded"

-- [NEW]: Bindable to safely command the PatientSpawner
local startMpSpawns = SS:FindFirstChild("StartMPSpawns") or Instance.new("BindableEvent", SS)
startMpSpawns.Name = "StartMPSpawns"

function MultiplayerManager.StartMatch(players, hostPlayer)
	local hospital = HospitalRegistry.Assign(hostPlayer)
	if not hospital then
		warn("[Multiplayer] No free hospitals available!")
		return
	end

	for i, player in ipairs(players) do
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local bedPos = hospital.beds[i].position
				hrp.CFrame = CFrame.new(bedPos + Vector3.new(0, 3, 0))
			end
		end

		player:SetAttribute("InMultiplayer", true)
		player:SetAttribute("Score", 0) 
		player:SetAttribute("AssignedBedIndex", i)

		-- [FIX]: Force the player to remember WHICH hospital they are in, regardless of ownership
		player:SetAttribute("AssignedHospitalId", hospital.id) 

		matchStartedRemote:FireClient(player, ROUND_TIME)

		-- [FIX]: Safely initialize this player's spawn tables and drop their first patient
		startMpSpawns:Fire(player, hospital.id, i)
	end

	print("[Multiplayer] Round started! 60 seconds on the clock.")
	task.spawn(function()
		task.wait(ROUND_TIME)
		MultiplayerManager.EndMatch(players, hostPlayer, hospital)
	end)
end

function MultiplayerManager.EndMatch(players, hostPlayer, hospital)
	print("[Multiplayer] Time's up! Tallying scores...")

	local leaderboard = {}
	for _, player in ipairs(players) do
		player:SetAttribute("InMultiplayer", false)
		table.insert(leaderboard, {
			name = player.Name,
			score = player:GetAttribute("Score") or 0
		})
	end

	table.sort(leaderboard, function(a, b) return a.score > b.score end)

	for _, player in ipairs(players) do
		matchEndedRemote:FireClient(player, leaderboard)
	end
	HospitalRegistry.Release(hostPlayer)
end

return MultiplayerManager