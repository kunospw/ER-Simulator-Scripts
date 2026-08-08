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

-- [NEW]: Server-authoritative round timer untuk multiplayer.
-- MultiplayerManager mendengarkan event ini dan mengubah `timeLeft` ronde,
-- lalu resync ke semua klien lewat MultiplayerMatchStarted.
local iotAdjustMP = SS:FindFirstChild("IoTTimerAdjustMP")
if not iotAdjustMP then
	iotAdjustMP = Instance.new("BindableEvent")
	iotAdjustMP.Name = "IoTTimerAdjustMP"
	iotAdjustMP.Parent = SS
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

-- [NEW]: Pisahkan pemain multiplayer dari pemain scenario/endless.
-- Timer keduanya beda: MP pakai timer ronde (server), sisanya pakai
-- timer pemeriksaan per-pasien (klien).
local function splitByMode(players)
	local mpPlayers, soloPlayers = {}, {}
	for _, player in ipairs(players) do
		if player:GetAttribute("InMultiplayer") then
			table.insert(mpPlayers, player)
		else
			table.insert(soloPlayers, player)
		end
	end
	return mpPlayers, soloPlayers
end

-- [NEW]: Terapkan penyesuaian waktu sesuai mode masing-masing pemain.
-- Mengembalikan daftar pemain MP, dipakai untuk membatasi notifikasi.
local function applyTimeAdjust(players, delta)
	local mpPlayers, soloPlayers = splitByMode(players)

	-- PENTING: fire SEKALI saja, bukan per pemain.
	-- Listener di MultiplayerManager langsung menambah `timeLeft` ronde,
	-- jadi memanggilnya per pemain akan melipatgandakan efeknya.
	if #mpPlayers > 0 then
		iotAdjustMP:Fire(delta)
	end

	for _, player in ipairs(soloPlayers) do
		iotTimerRemote:FireClient(player, delta)
	end

	return mpPlayers
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

		-- [NEW]: Toast hanya untuk pemain non-multiplayer.
		-- Di MP tiap pemain hanya punya satu bed yang selalu terisi, sehingga
		-- perintah ini tidak pernah menghasilkan pasien baru — menampilkan
		-- notifikasi di sana menjanjikan sesuatu yang tidak terjadi.
		local _, soloPlayers = splitByMode(players)
		notifyAll(soloPlayers, "➕ Pasien baru ditambahkan!", "YELLOW")

	elseif action == "REMOVE_PATIENT" then
		for _, player in ipairs(players) do
			player:SetAttribute("IoTRemovePatient", true)
		end
		notifyAll(players, "⚠️ Kondisi semua pasien memburuk!", "RED")

	elseif action == "ADD_TIME" then
		-- Notifikasi hanya untuk pemain MP: di scenario/endless perubahan
		-- waktu berlaku pada timer pemeriksaan pasien yang sedang dibuka,
		-- sehingga toast global justru membingungkan.
		local mpPlayers = applyTimeAdjust(players, 10)
		notifyAll(mpPlayers, "⏱️ +10 detik ditambahkan!", "GREEN")

		-- [NEW]: Terima "REMOVE_TIME" juga, karena middleware Python lama
		-- mengirim nama itu sementara script ini hanya mengenal "SUBTRACT_TIME".
	elseif action == "SUBTRACT_TIME" or action == "REMOVE_TIME" then
		local mpPlayers = applyTimeAdjust(players, -10)
		notifyAll(mpPlayers, "⏱️ -10 detik dikurangi!", "RED")
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
