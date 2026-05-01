-- PatientUIController (LocalScript)
-- StarterPlayerScripts

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player       = Players.LocalPlayer
local showUIRemote = RS:WaitForChild("ShowPatientUI")
local resetCamRemote = RS:WaitForChild("ResetPatientCamera")

local patientTimers = {}

-- ── Tooltip data ──────────────────────────────────────────────────────────────
local TIPS = {
	Breathing = {
		param = "Breathing (RR)",
		text  = "Count breaths per minute. If not breathing, open airway first.",
		rule  = "RR > 30 → Red   ·   RR ≤ 30 → check perfusion",
	},
	Perfusion = {
		param = "Perfusion (CRT)",
		text  = "Press fingernail 2 sec, release. Time until pink returns.",
		rule  = "CRT > 2s → Red   ·   CRT ≤ 2s → check mental status",
	},
	Mental = {
		param = "Mental status",
		text  = "Ask: 'squeeze my hand' or 'open your eyes'. Can they follow?",
		rule  = "Cannot follow → Red   ·   Can follow → Yellow",
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
		toggle.Text = collapsed and "▲  Pasien info" or "▼  Pasien info"
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
		-- Delayed = red, Normal = green
		if value == "Delayed" then return Color3.fromHex("F09595")
		else return Color3.fromHex("97C459") end
	elseif paramType == "mental" then
		if value == "Impaired" then return Color3.fromHex("F09595")
		else return Color3.fromHex("97C459") end
	end
	return Color3.fromHex("FFFFFF")
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
		if s then s.Text = "Score: " .. (player:GetAttribute("Score") or 0) end
	end
	if counterFrame then
		counterFrame.Visible = true
		local c = counterFrame:FindFirstChild("PatientCounterText")
		if c then c.Text = "Patients: " .. (player:GetAttribute("PatientsRemaining") or "?") end
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

				if bCard then
					bCard.Text = "Breathing\n" .. rrVal
					bCard.TextColor3 = vitalColor(rrNum, "rr")
					bCard.MouseButton1Click:Connect(function() showToast("Breathing") end)
				end
				if pCard then
					pCard.Text = "Perfusion\n" .. perfVal
					pCard.TextColor3 = vitalColor(perfVal, "crt")
					pCard.MouseButton1Click:Connect(function() showToast("Perfusion") end)
				end
				if mCard then
					mCard.Text = "Mental\n" .. mentalVal
					mCard.TextColor3 = vitalColor(mentalVal, "mental")
					mCard.MouseButton1Click:Connect(function() showToast("Mental") end)
				end
			end
		end
	end

	-- ── TriageFrame ───────────────────────────────────────────────────────────
	local triageFrame = gui:FindFirstChild("TriageFrame")
	if triageFrame then triageFrame.Visible = true end

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

	if not patientTimers[id] then
		patientTimers[id] = { timeLeft = 60, running = true }
		task.spawn(function()
			local state = patientTimers[id]
			while state.timeLeft >= 0 and state.running do
				if timerLabel and timerFrame and timerFrame.Visible then
					local m = math.floor(state.timeLeft / 60)
					local s = state.timeLeft % 60
					timerLabel.Text = string.format("%02d:%02d", m, s)
				end
				task.wait(1)
				state.timeLeft -= 1
			end
			if state.timeLeft < 0 then
				state.running = false
				print("[Timer] Patient", id, "timer expired")
			end
		end)
	end

	if timerLabel then
		local state = patientTimers[id]
		local m = math.floor(state.timeLeft / 60)
		local s = state.timeLeft % 60
		timerLabel.Text = string.format("%02d:%02d", m, s)
	end

	-- ── Distance check — hide UI but keep timer running ───────────────────────
	local character = player.Character or player.CharacterAdded:Wait()
	local root      = character:WaitForChild("HumanoidRootPart")

	task.spawn(function()
		while infoFrame and infoFrame.Visible do
			task.wait(0.2)
			if not root or not root.Parent then break end
			if not head or not head.Parent  then break end
			if (root.Position - head.Position).Magnitude > 15 then
				-- Hide everything
				if infoFrame  then infoFrame.Visible  = false end
				if triageFrame then triageFrame.Visible = false end
				if timerFrame  then timerFrame.Visible  = false end
				if scoreFrame  then scoreFrame.Visible  = false end
				if counterFrame then counterFrame.Visible = false end
				hideToast()
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