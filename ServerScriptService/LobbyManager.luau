-- ServerScriptService > LobbyManager (Script)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

-- Dynamically create RemoteEvents if they don't exist
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

-- Data structure: lobbies[HostUserId] = { Host = Player, Players = {Player1, Player2...} }
local lobbies = {} 
local MAX_PLAYERS = 4

-- Packages the lobby data into a clean table and sends it to all clients
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

-- Force a player out of any existing lobbies they might be in
local function removePlayerFromLobbies(player)
	for hostId, lobby in pairs(lobbies) do
		if lobby.Host == player then
			lobbies[hostId] = nil -- Destroy the lobby entirely if the host leaves
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

local startMatchRemote = getOrCreateRemote("StartMatch")
local SS = game:GetService("ServerStorage")

startMatchRemote.OnServerEvent:Connect(function(player)
	local lobby = lobbies[player.UserId]

	-- Verify the player clicking start is actually the host of this lobby
	if lobby and lobby.Host == player then
		-- Enforce the 2-player minimum rule
		if #lobby.Players >= 2 then
			print("[LobbyManager] Starting Multiplayer Match for " .. player.Name .. "'s Lobby!")

			-- Remove the lobby from the public list so no one else joins mid-game
			lobbies[player.UserId] = nil 
			broadcastLobbies()

			-- Hand the lobby data off to the new Multiplayer module
			local MultiplayerManager = require(SS:WaitForChild("MultiplayerManager"))
			MultiplayerManager.StartMatch(lobby.Players, player)
		else
			-- Optional: Fire a remote here to show a toast UI saying "Need at least 2 players!"
			warn("[LobbyManager] Not enough players to start match.")
		end
	end
end)