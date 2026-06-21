-- IoTController (Script) — ServerScriptService (used for BLE now)
local HttpService   = game:GetService("HttpService")
local SS            = game:GetService("ServerStorage")
local RS            = game:GetService("ReplicatedStorage")
local POLL_URL = "https://reproduce-seclusion-broadcast.ngrok-free.dev/data"
local POLL_INTERVAL = 2
local HospitalRegistry = require(SS:WaitForChild("HospitalRegistry"))

local function getAllActivePlayers()
	local result = {}
	for _, hospital in ipairs(HospitalRegistry.Hospitals) do
		if hospital.occupied and hospital.occupants then
			for player, _ in pairs(hospital.occupants) do
				if player and player.Parent then
					table.insert(result, player)
				end
			end
		end
	end
	return result
end

local patientCleared   = SS:WaitForChild("PatientCleared")

local iotTimerRemote   = RS:FindFirstChild("IoTTimerAdjust")
if not iotTimerRemote then
	iotTimerRemote = Instance.new("RemoteEvent")
	iotTimerRemote.Name = "IoTTimerAdjust"
	iotTimerRemote.Parent = RS
end

-- Notifikasi IoT (remote yang sama dipakai IoTServer + PatientUIController)
local iotNotifRemote = RS:FindFirstChild("IoTNotification")
if not iotNotifRemote then
	iotNotifRemote = Instance.new("RemoteEvent")
	iotNotifRemote.Name = "IoTNotification"
	iotNotifRemote.Parent = RS
end

local function notifyAll(players, message, colorKey)
	for _, player in ipairs(players) do
		iotNotifRemote:FireClient(player, message, colorKey)
	end
end

local function handleCommand(action)
	local players = getAllActivePlayers()
	if #players == 0 then
		print("[IoT] No active players, command ignored")
		return
	end
	print("[IoT] Command received:", action, "— affects", #players, "players")

	if action == "ADD_PATIENT" then
		for _, player in ipairs(players) do
			local queue = SS:FindFirstChild("IoTAddPatient")
			if not queue then
				queue = Instance.new("BindableEvent")
				queue.Name = "IoTAddPatient"
				queue.Parent = SS
			end
			queue:Fire(player)
		end
		notifyAll(players, "➕ Pasien baru ditambahkan!", "YELLOW")

	elseif action == "REMOVE_PATIENT" then
		for _, player in ipairs(players) do
			player:SetAttribute("IoTRemovePatient", true)
		end
		notifyAll(players, "⚠️ Kondisi semua pasien memburuk!", "RED")

	elseif action == "ADD_TIME" then
		for _, player in ipairs(players) do
			iotTimerRemote:FireClient(player, 30)
		end
		notifyAll(players, "⏱️ +30 detik ditambahkan!", "GREEN")

	elseif action == "SUBTRACT_TIME" then
		for _, player in ipairs(players) do
			iotTimerRemote:FireClient(player, -30)
		end
		notifyAll(players, "⏱️ -30 detik dikurangi!", "RED")
	end
end

-- Poll loop
task.spawn(function()
	while true do
		task.wait(POLL_INTERVAL)
		local ok, result = pcall(function()
			return HttpService:GetAsync(POLL_URL, true, {
				["ngrok-skip-browser-warning"] = "true"
			})
		end)
		if ok and result then
			local data = HttpService:JSONDecode(result)
			if data and data.button and data.button ~= "NONE" then  -- fixed key
				handleCommand(data.button)
			end
		end
	end
end)