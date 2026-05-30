-- IoTController (Script) — ServerScriptService
local HttpService   = game:GetService("HttpService")
local SS            = game:GetService("ServerStorage")
local RS            = game:GetService("ReplicatedStorage")

local POLL_URL      = "https://reproduce-seclusion-broadcast.ngrok-free.dev/"
local POLL_INTERVAL = 2

local HospitalRegistry = require(SS:WaitForChild("HospitalRegistry"))

-- ── RemoteEvents ──────────────────────────────────────────────────────────────
local iotTimerRemote = RS:FindFirstChild("IoTTimerAdjust")
if not iotTimerRemote then
	iotTimerRemote = Instance.new("RemoteEvent")
	iotTimerRemote.Name = "IoTTimerAdjust"
	iotTimerRemote.Parent = RS
end
local iotGlobalTimerRemote = RS:FindFirstChild("IoTGlobalTimer")
if not iotGlobalTimerRemote then
	iotGlobalTimerRemote = Instance.new("RemoteEvent")
	iotGlobalTimerRemote.Name = "IoTGlobalTimer"
	iotGlobalTimerRemote.Parent = RS
end
local iotNotifRemote = RS:FindFirstChild("IoTNotification")
if not iotNotifRemote then
	iotNotifRemote = Instance.new("RemoteEvent")
	iotNotifRemote.Name = "IoTNotification"
	iotNotifRemote.Parent = RS
end

local function getAllActivePlayers()
	local result = {}
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		table.insert(result, player)
	end
	print("[IoT] Total players found:", #result)
	return result
end

-- ── Handle command ────────────────────────────────────────────────────────────
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
			iotNotifRemote:FireClient(player, "⚠️ Instruktur menambah pasien baru!", "YELLOW")
		end

	elseif action == "REMOVE_PATIENT" then
		for _, player in ipairs(players) do
			player:SetAttribute("IoTRemovePatient", true)
			iotNotifRemote:FireClient(player, "⚠️ Instruktur mengurangi pasien!", "YELLOW")
		end

	elseif action == "ADD_TIME" then
		for _, player in ipairs(players) do
			iotGlobalTimerRemote:FireClient(player, 30)
			iotNotifRemote:FireClient(player, "⏱️ +30 detik ditambahkan!", "GREEN")
		end

	elseif action == "REMOVE_TIME" then
		for _, player in ipairs(players) do
			iotGlobalTimerRemote:FireClient(player, -30)
			iotNotifRemote:FireClient(player, "⏱️ -30 detik dikurangi!", "RED")
		end
	end
end

--task.spawn(function()
--	while true do
--		task.wait(POLL_INTERVAL)
--		local ok, result = pcall(function()
--			return HttpService:GetAsync(POLL_URL)
--		end)
--		if ok and result then
--			local ok2, data = pcall(function()
--				return HttpService:JSONDecode(result)
--			end)
--			if ok2 and data and data.action then
--				-- DEBUG: fire notif ke semua player buat confirm command diterima
--				for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
--					iotNotifRemote:FireClient(player, 
--						"DEBUG: Got " .. data.action, "YELLOW")
--				end
--				handleCommand(data.action)
--			end
--		else
--			if not ok then
--				for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
--					iotNotifRemote:FireClient(player, 
--						"DEBUG: Poll failed", "RED")
--				end
--			end
--		end
--	end
--end)

-- Debug remote
local iotDebugFire = RS:FindFirstChild("IoTDebugFire")
if not iotDebugFire then
	iotDebugFire = Instance.new("RemoteEvent")
	iotDebugFire.Name = "IoTDebugFire"
	iotDebugFire.Parent = RS
end

iotDebugFire.OnServerEvent:Connect(function(player, action)
	print("[IoTDebug] Fired by", player.Name, ":", action)
	handleCommand(action)
end)