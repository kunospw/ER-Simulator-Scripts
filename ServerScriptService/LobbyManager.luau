-- ServerScriptService > LobbyManager (Script)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local function getOrCreateRemote(name)
	local remote = RS:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = RS
	end
	return remote
end

local createLobbyRemote = getOrCreateRemote("CreateLobby")
local joinLobbyRemote   = getOrCreateRemote("JoinLobby")
local leaveLobbyRemote  = getOrCreateRemote("LeaveLobby")
local updateLobbiesRemote = getOrCreateRemote("UpdateLobbies")
local requestLobbiesRemote = getOrCreateRemote("RequestLobbies")
local startMatchRemote = getOrCreateRemote("StartMatch")

-- Pre-create these so MainmenuLocalScript doesn't time out
getOrCreateRemote("MultiplayerMatchStarted")
getOrCreateRemote("MultiplayerMatchEnded")

local lobbies = {} 
local MAX_PLAYERS = 4

local function broadcastLobbies()
	local lobbyData = {}
	for hostId, lobby in pairs(lobbies) do
		local playerNames = {}
		for _, p in ipairs(lobby.Players) do
			table.insert(playerNames, p.Name)
		end
		lobbyData[tostring(hostId)] = {
			HostName = lobby.Host.Name,
			PlayerNames = playerNames,
			PlayerCount = #lobby.Players,
			MaxPlayers = MAX_PLAYERS
		}
	end
	updateLobbiesRemote:FireAllClients(lobbyData)
end

local function removePlayerFromLobbies(player)
	for hostId, lobby in pairs(lobbies) do
		if lobby.Host == player then
			lobbies[hostId] = nil 
			broadcastLobbies()
			return
		end

		local idx = table.find(lobby.Players, player)
		if idx then
			table.remove(lobby.Players, idx)
			broadcastLobbies()
			return
		end
	end
end

createLobbyRemote.OnServerEvent:Connect(function(player)
	removePlayerFromLobbies(player)
	lobbies[player.UserId] = {
		Host = player,
		Players = {player}
	}
	broadcastLobbies()
end)

joinLobbyRemote.OnServerEvent:Connect(function(player, targetHostId)
	local lobby = lobbies[tonumber(targetHostId)]
	if not lobby then return end
	if #lobby.Players >= MAX_PLAYERS then return end

	removePlayerFromLobbies(player)
	table.insert(lobby.Players, player)
	broadcastLobbies()
end)

leaveLobbyRemote.OnServerEvent:Connect(function(player)
	removePlayerFromLobbies(player)
end)

Players.PlayerRemoving:Connect(removePlayerFromLobbies)

requestLobbiesRemote.OnServerEvent:Connect(function(player)
	broadcastLobbies()
end)

startMatchRemote.OnServerEvent:Connect(function(player)
	local lobby = lobbies[player.UserId]

	if lobby and lobby.Host == player then
		if #lobby.Players >= 2 then
			print("[LobbyManager] Starting Multiplayer Match for " .. player.Name .. "'s Lobby!")

			lobbies[player.UserId] = nil 
			broadcastLobbies()

			local MultiplayerManager = require(SS:WaitForChild("MultiplayerManager"))
			-- [FIX]: Back to just passing players and host
			MultiplayerManager.StartMatch(lobby.Players, player)
		else
			warn("[LobbyManager] Not enough players to start match.")
		end
	end
end)