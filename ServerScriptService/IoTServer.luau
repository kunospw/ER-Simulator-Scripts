-- IoTServer.luau (ServerScriptService) (disabled, now using ble with IoTController.luau)
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SS = game:GetService("ServerStorage")

local event = RS:FindFirstChild("IoTEvent")
if not event then
	event = Instance.new("RemoteEvent")
	event.Name = "IoTEvent"
	event.Parent = RS
end

local iotNotifRemote = RS:FindFirstChild("IoTNotification")
if not iotNotifRemote then
	iotNotifRemote = Instance.new("RemoteEvent")
	iotNotifRemote.Name = "IoTNotification"
	iotNotifRemote.Parent = RS
end

local iotAdjustMP = SS:FindFirstChild("IoTTimerAdjustMP")
if not iotAdjustMP then
	iotAdjustMP = Instance.new("BindableEvent")
	iotAdjustMP.Name = "IoTTimerAdjustMP"
	iotAdjustMP.Parent = SS
end

local function getAllActivePlayers()
	local result = {}
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		table.insert(result, player)
	end
	return result
end

local function handleCommand(action)
	local players = getAllActivePlayers()
	if #players == 0 then
		print("[IoT] No active players, command ignored")
		return
	end

	print("[IoT] Command received:", action, "— affects", #players, "players")
local event = RS:FindFirstChild("IoTEvent")
if not event then
	event = Instance.new("RemoteEvent")
	event.Name = "IoTEvent"
	event.Parent = RS
end

local iotNotifRemote = RS:FindFirstChild("IoTNotification")
if not iotNotifRemote then
	iotNotifRemote = Instance.new("RemoteEvent")
	iotNotifRemote.Name = "IoTNotification"
	iotNotifRemote.Parent = RS
end

local iotAdjustMP = SS:FindFirstChild("IoTTimerAdjustMP")
if not iotAdjustMP then
	iotAdjustMP = Instance.new("BindableEvent")
	iotAdjustMP.Name = "IoTTimerAdjustMP"
	iotAdjustMP.Parent = SS
end

local function getAllActivePlayers()
	local result = {}
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		table.insert(result, player)
	end
	return result
end

local function handleCommand(action)
	local players = getAllActivePlayers()
	if #players == 0 then
		print("[IoT] No active players, command ignored")
		return
	end

	print("[IoT] Command received:", action, "— affects", #players, "players")

	if action == "ADD_PATIENT" then
		local iotAddPatient = SS:FindFirstChild("IoTAddPatient")
		if not iotAddPatient then
			iotAddPatient = Instance.new("BindableEvent")
			iotAddPatient.Name = "IoTAddPatient"
			iotAddPatient.Parent = SS
		end
		for _, player in ipairs(players) do
			iotAddPatient:Fire(player)
			iotNotifRemote:FireClient(player, "⚠️ Instruktur menambah pasien baru!", "YELLOW")
		end
		local iotAddPatient = SS:FindFirstChild("IoTAddPatient")
		if not iotAddPatient then
			iotAddPatient = Instance.new("BindableEvent")
			iotAddPatient.Name = "IoTAddPatient"
			iotAddPatient.Parent = SS
		end
		for _, player in ipairs(players) do
			iotAddPatient:Fire(player)
			iotNotifRemote:FireClient(player, "⚠️ Instruktur menambah pasien baru!", "YELLOW")
		end

	elseif action == "REMOVE_PATIENT" then
		for _, player in ipairs(players) do
			player:SetAttribute("IoTRemovePatient", true)
			iotNotifRemote:FireClient(player, "⚠️ Instruktur mengurangi pasien!", "YELLOW")
		end
		for _, player in ipairs(players) do
			player:SetAttribute("IoTRemovePatient", true)
			iotNotifRemote:FireClient(player, "⚠️ Instruktur mengurangi pasien!", "YELLOW")
		end

	elseif action == "ADD_TIME" then
		iotAdjustMP:Fire(30)
		for _, player in ipairs(players) do
			iotNotifRemote:FireClient(player, "⏱️ +30 detik ditambahkan!", "GREEN")
		end
		iotAdjustMP:Fire(30)
		for _, player in ipairs(players) do
			iotNotifRemote:FireClient(player, "⏱️ +30 detik ditambahkan!", "GREEN")
		end

	elseif action == "REMOVE_TIME" then
		iotAdjustMP:Fire(-30)
		for _, player in ipairs(players) do
			iotNotifRemote:FireClient(player, "⏱️ -30 detik dikurangi!", "RED")
		end
	end
end

event.OnServerEvent:Connect(function(player, action)
	print("[IoT] Received from", player.Name, ":", action)
	handleCommand(action)
		iotAdjustMP:Fire(-30)
		for _, player in ipairs(players) do
			iotNotifRemote:FireClient(player, "⏱️ -30 detik dikurangi!", "RED")
		end
	end
end

event.OnServerEvent:Connect(function(player, action)
	print("[IoT] Received from", player.Name, ":", action)
	handleCommand(action)
end)