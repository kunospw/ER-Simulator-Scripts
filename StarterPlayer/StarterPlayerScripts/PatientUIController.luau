-- PatientUIController (LocalScript)
-- StarterPlayerScripts

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player       = Players.LocalPlayer
local showUIRemote = RS:WaitForChild("ShowPatientUI")
local resetCamRemote = RS:WaitForChild("ResetPatientCamera")

-- Per-patient timer state stored locally
-- key: PatientID string → { timeLeft, running }
local patientTimers = {}

local function getGui()
	return player.PlayerGui:WaitForChild("GameplayScreenGui")
end

local function hideAll(gui)
	for _, name in ipairs({
		"ScoreFrame", "PatientCounterFrame",
		"VitalsFrame", "TimerFrame", "TriageFrame"
		}) do
		local f = gui:FindFirstChild(name)
		if f then f.Visible = false end
	end
end

showUIRemote.OnClientEvent:Connect(function(patient)
	local gui = getGui()
	if not gui then return end

	local head = patient:FindFirstChild("Head")
	if not head then return end

	-- ── Frames ────────────────────────────────────────────────────────────────
	local scoreFrame   = gui:WaitForChild("ScoreFrame")
	local counterFrame = gui:WaitForChild("PatientCounterFrame")
	local vitalsFrame  = gui:WaitForChild("VitalsFrame")
	local timerFrame   = gui:WaitForChild("TimerFrame")
	local triageFrame  = gui:WaitForChild("TriageFrame")

	scoreFrame.Visible   = true
	counterFrame.Visible = true
	vitalsFrame.Visible  = true
	timerFrame.Visible   = true
	triageFrame.Visible  = true

	-- ── Score ─────────────────────────────────────────────────────────────────
	if not player:GetAttribute("Score") then
		player:SetAttribute("Score", 0)
	end
	scoreFrame:WaitForChild("ScoreText").Text =
		"Score: " .. player:GetAttribute("Score")

	-- ── Patient counter ───────────────────────────────────────────────────────
	if not player:GetAttribute("PatientsRemaining") then
		player:SetAttribute("PatientsRemaining", 3)
	end
	counterFrame:WaitForChild("PatientCounterText").Text =
		"Patients Remaining: " .. player:GetAttribute("PatientsRemaining")

	-- ── Vitals ────────────────────────────────────────────────────────────────
	local id        = patient:GetAttribute("PatientID") or "???"
	local breathing = patient:GetAttribute("Breathing") or "?"
	local perfusion = patient:GetAttribute("Perfusion") or "?"
	local mental    = patient:GetAttribute("Mental")    or "?"
	local crtText   = (perfusion == "Delayed") and "> 2s" or "< 2s"

	vitalsFrame:WaitForChild("PatientIDText").Text = "Patient " .. id
	vitalsFrame:WaitForChild("RRText").Text        = "RR: "     .. breathing
	vitalsFrame:WaitForChild("CRTText").Text       = "CRT: "    .. crtText
	vitalsFrame:WaitForChild("MentalText").Text    = "Mental: " .. mental

	-- ── Timer — persistent per patient ────────────────────────────────────────
	local timerLabel = timerFrame:WaitForChild("TimeText")

	-- Start a new timer only if this patient hasn't been clicked before
	if not patientTimers[id] then
		patientTimers[id] = { timeLeft = 60, running = true }

		task.spawn(function()
			local state = patientTimers[id]
			while state.timeLeft >= 0 and state.running do
				-- Update label only when UI is open for this patient
				if vitalsFrame.Visible and vitalsFrame:GetAttribute("ActivePatient") == id then
					local m = math.floor(state.timeLeft / 60)
					local s = state.timeLeft % 60
					timerLabel.Text = string.format("%02d:%02d", m, s)
				end
				task.wait(1)
				state.timeLeft -= 1
			end
			-- Timer ran out
			if state.timeLeft < 0 then
				state.running = false
				-- Optionally: auto-fail this patient's triage here
				print("[Timer] Patient", id, "timer expired!")
			end
		end)
	end

	-- Tag the vitals frame so the timer thread knows which patient is active
	vitalsFrame:SetAttribute("ActivePatient", id)

	-- Refresh displayed time immediately
	local state = patientTimers[id]
	local m = math.floor(state.timeLeft / 60)
	local s = state.timeLeft % 60
	timerLabel.Text = string.format("%02d:%02d", m, s)

	-- ── Distance check — hides UI but keeps timer running ────────────────────
	local character = player.Character or player.CharacterAdded:Wait()
	local root      = character:WaitForChild("HumanoidRootPart")
	local uiOpen    = true  -- local flag for this particular open-event

	task.spawn(function()
		while uiOpen do
			task.wait(0.2)
			if not root or not root.Parent then break end
			if not head or not head.Parent  then break end

			local dist = (root.Position - head.Position).Magnitude
			if dist > 15 then
				uiOpen = false
				hideAll(gui)

				-- Reset camera locally — no server round-trip needed
				if _G.ResetPatientCamera then
					_G.ResetPatientCamera()
				else
					resetCamRemote:FireServer()  -- fallback
				end
			end
		end
	end)
end)