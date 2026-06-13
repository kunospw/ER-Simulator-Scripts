-- PatientUIController (LocalScript)
-- StarterPlayerScripts

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player       = Players.LocalPlayer
local showUIRemote = RS:WaitForChild("ShowPatientUI")
local resetCamRemote = RS:WaitForChild("ResetPatientCamera")

local submitTriageRemote = RS:WaitForChild("SubmitTriage")
local triageResultRemote = RS:WaitForChild("TriageResult")

local patientTimers = {}
local currentViewedPatientId = nil

local startRemote = RS:WaitForChild("StartCutscene")

startRemote.OnClientEvent:Connect(function()
	for _, state in pairs(patientTimers) do
		state.running = false
	end
	patientTimers = {}
	currentViewedPatientId = nil
end)

-- ── Tooltip data ──────────────────────────────────────────────────────────────
local TIPS = {
	Breathing = {
		param = "Pernapasan (RR)",
		text  = "Hitung napas per menit. Jika tidak bernapas, buka jalan napas terlebih dahulu.",
		rule  = "RR > 30 → Merah   ·   RR ≤ 30 → cek perfusi",
	},
	Perfusion = {
		param = "Perfusi (CRT)",
		text  = "Tekan kuku 2 detik, lepas. Hitung waktu hingga warna merah muda kembali.",
		rule  = "CRT > 2 detik → Merah   ·   CRT ≤ 2 detik → cek status mental",
	},
	Mental = {
		param = "Status Mental",
		text  = "Tanya: 'genggam tangan saya' atau 'buka mata'. Apakah bisa mengikuti perintah?",
		rule  = "Tidak bisa mengikuti → Merah   ·   Bisa mengikuti → Kuning",
	},
}

local function getGui()
	return player.PlayerGui:WaitForChild("GameplayScreenGui")
end

-- ── Toast (training tip) ──────────────────────────────────────────────────────
local toastTween = nil
local toastVisible = false

local function showToast(key)
	local gui = getGui()
	local toast = gui:FindFirstChild("ToastFrame")
	if not toast then return end

	local tip = TIPS[key]
	if not tip then return end

	local content = toast:FindFirstChild("ToastContent")
	if content then
		local paramLabel = content:FindFirstChild("ParamLabel")
		if paramLabel then paramLabel.Text = tip.param end
		if content:FindFirstChild("HintText") then content.HintText.Text = tip.text end
		if content:FindFirstChild("RuleText") then content.RuleText.Text = tip.rule end
	end

	if toastTween then toastTween:Cancel() end
	-- Slide in from left: off-screen is X = -210 (width 200 + margin)
	toast.Position = UDim2.new(0, -210, 0, 54)
	toast.Visible  = true
	toastTween = TweenService:Create(
		toast,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, 14, 0, 54) }
	)
	toastTween:Play()
	toastVisible = true
end

local function hideToast()
	local gui = getGui()
	local toast = gui:FindFirstChild("ToastFrame")
	if not toast or not toastVisible then return end
	if toastTween then toastTween:Cancel() end
	toastTween = TweenService:Create(
		toast,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0, -210, 0, 54) }
	)
	toastTween:Play()
	toastTween.Completed:Connect(function()
		toast.Visible = false
	end)
	toastVisible = false
end

-- ── Info panel collapse/expand ────────────────────────────────────────────────
local infoCollapsed = false
local collapseTween = nil

local EXPANDED_H  = 110
local COLLAPSED_H = 34

local function setInfoCollapsed(collapsed)
	local gui = getGui()
	local infoFrame = gui:FindFirstChild("PatientInfoFrame")
	if not infoFrame then return end

	infoCollapsed = collapsed
	local targetSize = UDim2.new(1, 0, 0, collapsed and COLLAPSED_H or EXPANDED_H)

	if collapseTween then collapseTween:Cancel() end
	local t1 = TweenService:Create(
		infoFrame,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = targetSize }
	)
	t1:Play()
	collapseTween = t1

	local toggle = infoFrame:FindFirstChild("ToggleButton")
	if toggle then
		toggle.Text = collapsed and "▲  Info Pasien" or "▼  Info Pasien"
	end

	local body = infoFrame:FindFirstChild("InfoBody")
	if body then body.Visible = not collapsed end
end

-- ── Vital color coding ────────────────────────────────────────────────────────
local function vitalColor(value, paramType)
	if paramType == "rr" then
		if value > 30 or value == 0 then return Color3.fromHex("F09595")
		elseif value >= 24 then return Color3.fromHex("FAC775")
		else return Color3.fromHex("97C459") end
	elseif paramType == "crt" then
		if value == "Terlambat" then return Color3.fromHex("F09595")
		else return Color3.fromHex("97C459") end
	elseif paramType == "mental" then
		if value == "Terganggu" then return Color3.fromHex("F09595")
		else return Color3.fromHex("97C459") end
	end
	return Color3.fromHex("FFFFFF")
end

-- ── Triage Toast ──────────────────────────────────────────────────────────────
local activeTriageTweens = {}
local currentToastId = 0

local function showTriageToast(isCorrect, pointsDelta)
	local gui   = getGui()
	local toast = gui:FindFirstChild("TriageToast")
	if not toast then return end

	local icon     = toast:FindFirstChild("PillIcon")
	local pillText = toast:FindFirstChild("PillText")

	-- Increment the ID to invalidate any previous delayed tasks or tween callbacks
	currentToastId += 1
	local myToastId = currentToastId

	-- Cancel any currently running tweens
	for _, tween in ipairs(activeTriageTweens) do
		tween:Cancel()
	end
	activeTriageTweens = {}

	-- Setup colors and text
	if isCorrect then
		toast.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
		if icon     then icon.Text     = "✓" end
		if pillText then pillText.Text = "+" .. pointsDelta .. " · Benar!" end
	else
		toast.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
		if icon     then icon.Text     = "✗" end
		if pillText then pillText.Text = pointsDelta .. " · Salah" end
	end

	toast.Visible                = true
	toast.BackgroundTransparency = 1
	if icon     then icon.TextTransparency     = 1 end
	if pillText then pillText.TextTransparency = 1 end

	-- Play Fade In tweens
	local t1 = TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.15 })
	t1:Play()
	table.insert(activeTriageTweens, t1)

	if icon then
		local t2 = TweenService:Create(icon, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { TextTransparency = 0 })
		t2:Play()
		table.insert(activeTriageTweens, t2)
	end
	if pillText then
		local t3 = TweenService:Create(pillText, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { TextTransparency = 0 })
		t3:Play()
		table.insert(activeTriageTweens, t3)
	end

	-- Schedule Fade Out
	task.delay(2, function()
		-- If a new toast was triggered while we were waiting, abort this fade-out completely
		if currentToastId ~= myToastId then return end

		activeTriageTweens = {} -- Clear fade-in tweens from the table

		local fadeOut = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
		fadeOut:Play()
		table.insert(activeTriageTweens, fadeOut)

		if icon then
			local f2 = TweenService:Create(icon, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { TextTransparency = 1 })
			f2:Play()
			table.insert(activeTriageTweens, f2)
		end
		if pillText then
			local f3 = TweenService:Create(pillText, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { TextTransparency = 1 })
			f3:Play()
			table.insert(activeTriageTweens, f3)
		end

		fadeOut.Completed:Connect(function(playbackState)
			-- Only hide the UI if this is STILL the active toast AND it finished normally without being cancelled
			if currentToastId == myToastId and playbackState == Enum.PlaybackState.Completed then
				toast.Visible = false
			end
		end)
	end)
end

-- ── Main UI populate ──────────────────────────────────────────────────────────
showUIRemote.OnClientEvent:Connect(function(patient)
	local gui = getGui()
	if not gui then return end

	local head = patient:FindFirstChild("Head")

	-- ── Score & counter (your existing frames) ────────────────────────────────
	local scoreFrame   = gui:FindFirstChild("ScoreFrame")
	local counterFrame = gui:FindFirstChild("PatientCounterFrame")
	local timerFrame   = gui:FindFirstChild("TimerFrame")

	if scoreFrame then
		scoreFrame.Visible = true
		local s = scoreFrame:FindFirstChild("ScoreText")
		if s then s.Text = "Skor: " .. (player:GetAttribute("Score") or 0) end
	end
	if counterFrame then
		counterFrame.Visible = true
		local c = counterFrame:FindFirstChild("PatientCounterText")
		if c then c.Text = "Pasien: " .. (player:GetAttribute("PatientsRemaining") or "?") end
	end
	if timerFrame then timerFrame.Visible = true end

	-- ── PatientInfoFrame ──────────────────────────────────────────────────────
	local infoFrame = gui:FindFirstChild("PatientInfoFrame")
	if infoFrame then
		infoFrame.Visible = true

		-- Always start expanded when a new patient opens
		setInfoCollapsed(false)

		-- Toggle button wires up collapse
		local toggle = infoFrame:FindFirstChild("ToggleButton")
		if toggle then
			toggle.Text = "▼  Pasien info"
			toggle.MouseButton1Click:Connect(function()
				setInfoCollapsed(not infoCollapsed)
			end)
		end

		local body = infoFrame:FindFirstChild("InfoBody")
		if body then
			-- Complaint
			local complaint = body:FindFirstChild("ComplaintText")
			if complaint then
				complaint.Text = patient:GetAttribute("Complaint") or "Keluhan tidak tersedia."
			end

			-- START cards
			local cardRow = body:FindFirstChild("STARTCardRow")
			if cardRow then
				local rrVal       = patient:GetAttribute("Breathing") or "?"
				local perfVal     = patient:GetAttribute("Perfusion") or "?"
				local mentalVal   = patient:GetAttribute("Mental")    or "?"

				-- Parse RR number out of "28x/mnt"
				local rrNum = tonumber(rrVal:match("%d+")) or 0

				local bCard = cardRow:FindFirstChild("BreathingCard")
				local pCard = cardRow:FindFirstChild("PerfusionCard")
				local mCard = cardRow:FindFirstChild("MentalCard")

				-- Check if tooltips should be shown (Training Mode only)
				local ScenarioData = require(RS:WaitForChild("ScenarioData"))
				local scenarioScreen = player.PlayerGui:FindFirstChild("ScenarioScreen")
				local scenarioId = scenarioScreen and scenarioScreen:GetAttribute("ScenarioId") or ""
				local scenario = ScenarioData.GetScenario(scenarioId)
				local isTrainingMode = scenario and scenario.mode == "Training Mode"

				if bCard then
					bCard.Text = "Pernapasan\n" .. rrVal
					bCard.TextColor3 = vitalColor(rrNum, "rr")
					if isTrainingMode then
						bCard.MouseButton1Click:Connect(function() showToast("Breathing") end)
					end
				end
				if pCard then
					pCard.Text = "Perfusi\n" .. perfVal
					pCard.TextColor3 = vitalColor(perfVal, "crt")
					if isTrainingMode then
						pCard.MouseButton1Click:Connect(function() showToast("Perfusion") end)
					end
				end
				if mCard then
					mCard.Text = "Mental\n" .. mentalVal
					mCard.TextColor3 = vitalColor(mentalVal, "mental")
					if isTrainingMode then
						mCard.MouseButton1Click:Connect(function() showToast("Mental") end)
					end
				end
			end
		end
	end

	-- ── TriageFrame ───────────────────────────────────────────────────────────
	local triageFrame = gui:FindFirstChild("TriageFrame")
	if triageFrame then
		triageFrame.Visible = true

		local patientId = patient:GetAttribute("PatientID")

		-- Disconnect semua koneksi lama
		if not triageFrame:GetAttribute("ConnectionsCleared") then
			triageFrame:SetAttribute("ConnectionsCleared", true)
		end

		local buttons = {
			{ name = "RedButton",    value = "RED"    },
			{ name = "YellowButton", value = "YELLOW" },
			{ name = "GreenButton",  value = "GREEN"  },
			{ name = "BlackButton",  value = "BLACK"  },
		}

		-- Simpan koneksi di luar loop biar bisa di-disconnect
		if not _G.TriageConnections then _G.TriageConnections = {} end

		-- Disconnect semua koneksi lama
		for _, conn in ipairs(_G.TriageConnections) do
			conn:Disconnect()
		end
		_G.TriageConnections = {}

		for _, btn in ipairs(buttons) do
			local button = triageFrame:FindFirstChild(btn.name)
			if button then
				local conn = button.MouseButton1Click:Connect(function()
					submitTriageRemote:FireServer(patientId, btn.value)
				end)
				table.insert(_G.TriageConnections, conn)
			end
		end
	end

	-- ── Toast close button ────────────────────────────────────────────────────
	local toast = gui:FindFirstChild("ToastFrame")
	if toast then
		local closeBtn = toast:FindFirstChildWhichIsA("TextButton")
		if closeBtn then
			closeBtn.MouseButton1Click:Connect(hideToast)
		end
	end

	-- ── Timer — persistent per patient ───────────────────────────────────────
	local id = patient:GetAttribute("PatientID") or "???"
	local timerLabel = timerFrame and timerFrame:FindFirstChild("TimeText")

	-- Set this patient as the currently viewed one
	currentViewedPatientId = id 

	if not patientTimers[id] then
		patientTimers[id] = { timeLeft = 60, running = true }
		task.spawn(function()
			local state = patientTimers[id]
			while state.timeLeft >= 0 and state.running do
				-- [FIX]: Only update the UI text if this loop belongs to the patient currently being viewed
				if currentViewedPatientId == id and timerLabel and timerFrame and timerFrame.Visible then
					local m = math.floor(state.timeLeft / 60)
					local s = state.timeLeft % 60
					timerLabel.Text = string.format("%02d:%02d", m, s)
				end
				task.wait(1)
				state.timeLeft -= 1
			end
			if state.timeLeft < 0 then
				state.running = false
				-- Auto-submit timeout if patient not yet triaged
				local npc = workspace:FindFirstChild(id, true)
				local alreadyTriaged = npc and npc:GetAttribute("Triaged")
				if not alreadyTriaged then
					submitTriageRemote:FireServer(id, "TIMEOUT")
				end
			end
		end)
	end

	if timerLabel then
		local state = patientTimers[id]
		local m = math.floor(state.timeLeft / 60)
		local s = state.timeLeft % 60
		timerLabel.Text = string.format("%02d:%02d", m, s)
	end

	-- ── Distance & Movement check — hide UI but keep timer running ───────────────────────
	local character = player.Character or player.CharacterAdded:Wait()
	local root      = character:WaitForChild("HumanoidRootPart")
	local humanoid  = character:WaitForChild("Humanoid") -- Grab the humanoid

	task.spawn(function()
		local timeOpened = tick() -- Track exactly when the menu opened

		while infoFrame and infoFrame.Visible do
			task.wait(0.1) -- Lowered from 0.2 to 0.1 so it reacts faster

			if not root or not root.Parent then break end
			if not head or not head.Parent then break end
			if not humanoid or not humanoid.Parent then break end

			-- MoveDirection > 0 means the player is pushing a movement key/joystick
			local isTryingToMove = humanoid.MoveDirection.Magnitude > 0

			-- Wait 0.4 seconds before tracking movement so the menu doesn't instantly 
			-- close if the player was still holding 'W' while pressing 'E'
			local hasGracePeriodPassed = (tick() - timeOpened) > 0.4

			if (isTryingToMove and hasGracePeriodPassed) or (root.Position - head.Position).Magnitude > 15 then
				-- Hide patient-specific UI
				if infoFrame   then infoFrame.Visible   = false end
				if triageFrame then triageFrame.Visible = false end
				if timerFrame  then timerFrame.Visible  = false end
				hideToast()

				-- DO NOT hide scoreFrame or counterFrame here.

				-- Reset the camera and player controls
				if _G.ResetPatientCamera then
					_G.ResetPatientCamera()
				else
					resetCamRemote:FireServer()
				end
				break
			end
		end
	end)
end)

-- ── Triage Result ─────────────────────────────────────────────────────────────
triageResultRemote.OnClientEvent:Connect(function(feedback)
	local gui = getGui()
	if not gui then return end

	-- Update score
	local scoreFrame = gui:FindFirstChild("ScoreFrame")
	if scoreFrame then
		local s = scoreFrame:FindFirstChild("ScoreText")
		if s then s.Text = "Skor: " .. feedback.totalScore end
	end

	-- Show toast
	showTriageToast(feedback.isCorrect, feedback.pointsDelta)

	-- Hide patient UI
	local infoFrame   = gui:FindFirstChild("PatientInfoFrame")
	local triageFrame = gui:FindFirstChild("TriageFrame")
	local timerFrame  = gui:FindFirstChild("TimerFrame")
	if infoFrame   then infoFrame.Visible   = false end
	if triageFrame then triageFrame.Visible = false end
	if timerFrame  then timerFrame.Visible  = false end
	hideToast()

	-- Reset camera
	if _G.ResetPatientCamera then _G.ResetPatientCamera() end
end)

local vitalsUpdatedRemote = RS:WaitForChild("VitalsUpdated")

vitalsUpdatedRemote.OnClientEvent:Connect(function(patientId, newVitals)
	-- Cek apakah player lagi examine pasien ini
	if currentViewedPatientId ~= patientId then return end

	local gui = getGui()
	if not gui then return end

	local infoFrame = gui:FindFirstChild("PatientInfoFrame")
	if not infoFrame or not infoFrame.Visible then return end

	local body    = infoFrame:FindFirstChild("InfoBody")
	if not body then return end

	local cardRow = body:FindFirstChild("STARTCardRow")
	if not cardRow then return end

	local rrNum = tonumber((newVitals.breathing or "0"):match("%d+")) or 0

	local bCard = cardRow:FindFirstChild("BreathingCard")
	local pCard = cardRow:FindFirstChild("PerfusionCard")
	local mCard = cardRow:FindFirstChild("MentalCard")

	if bCard then
		bCard.Text       = "Pernapasan\n" .. (newVitals.breathing or "?")
		bCard.TextColor3 = vitalColor(rrNum, "rr")
	end
	if pCard then
		pCard.Text       = "Perfusi\n" .. (newVitals.perfusion or "?")
		pCard.TextColor3 = vitalColor(newVitals.perfusion or "Normal", "crt")
	end
	if mCard then
		mCard.Text       = "Mental\n" .. (newVitals.mental or "?")
		mCard.TextColor3 = vitalColor(newVitals.mental or "Sadar", "mental")
	end
end)

-- ── Live UI Updates (Runs independently of the Patient Menu) ──────────────────
player:GetAttributeChangedSignal("PatientsRemaining"):Connect(function()
	local gui = getGui()
	if not gui then return end

	local counterFrame = gui:FindFirstChild("PatientCounterFrame")
	if counterFrame then
		local counterText = counterFrame:FindFirstChild("PatientCounterText")
		if counterText then
			local remaining = player:GetAttribute("PatientsRemaining") or 0
			counterText.Text = "Pasien: " .. remaining
			-- Note: Change "Pasien: " to "Patients: " if you want it in English
		end
	end
end)

-- ── Force Close UI on Round End ──────────────────────────────────────────────
local matchEndedRemote = RS:WaitForChild("MultiplayerMatchEnded", 5) or Instance.new("RemoteEvent")
matchEndedRemote.OnClientEvent:Connect(function()
	local gui = getGui()
	if not gui then return end

	local infoFrame   = gui:FindFirstChild("PatientInfoFrame")
	local triageFrame = gui:FindFirstChild("TriageFrame")
	local timerFrame  = gui:FindFirstChild("TimerFrame")

	if infoFrame   then infoFrame.Visible   = false end
	if triageFrame then triageFrame.Visible = false end
	if timerFrame  then timerFrame.Visible  = false end

	hideToast()
	if _G.ResetPatientCamera then _G.ResetPatientCamera() end
end)

-- ── IoT Timer Adjustment ──────────────────────────────────────────────────────
local iotTimerRemote = RS:WaitForChild("IoTTimerAdjust")

iotTimerRemote.OnClientEvent:Connect(function(delta)
	if not currentViewedPatientId then return end
	local state = patientTimers[currentViewedPatientId]
	if not state then return end

	state.timeLeft = math.clamp(state.timeLeft + delta, 0, 120)

	-- Update the UI immediately if timer is visible
	local gui = getGui()
	local timerFrame = gui and gui:FindFirstChild("TimerFrame")
	local timerLabel = timerFrame and timerFrame:FindFirstChild("TimeText")
	if timerLabel and timerFrame and timerFrame.Visible then
		local m = math.floor(state.timeLeft / 60)
		local s = state.timeLeft % 60
		timerLabel.Text = string.format("%02d:%02d", m, s)
	end

	print("[IoT] Timer adjusted by", delta, "→ new time:", state.timeLeft)
end)

-- ── IoT Notification ──────────────────────────────────────────────────────────
local iotNotifRemote = RS:WaitForChild("IoTNotification", 5) or Instance.new("RemoteEvent")

local notifColors = {
	RED    = Color3.fromRGB(239, 68, 68),
	GREEN  = Color3.fromRGB(34, 197, 94),
	YELLOW = Color3.fromRGB(234, 179, 8),
}

iotNotifRemote.OnClientEvent:Connect(function(message, colorKey)
	local gui = getGui()
	if not gui then return end

	local notif = Instance.new("Frame")
	notif.Size = UDim2.new(0, 280, 0, 44)
	notif.Position = UDim2.new(0.5, -140, 0, -50)
	notif.BackgroundColor3 = notifColors[colorKey] or notifColors.YELLOW
	notif.BorderSizePixel = 0
	notif.ZIndex = 10
	notif.Parent = gui
	Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 8)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.Text = message
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 11
	label.Parent = notif

	TweenService:Create(notif,
		TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -140, 0, 12) }
	):Play()

	task.delay(3, function()
		TweenService:Create(notif,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, -140, 0, -50) }
		):Play()
		task.wait(0.25)
		notif:Destroy()
	end)
end)