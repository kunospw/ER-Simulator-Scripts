-- LocalScript (inside ScenarioScreen)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScenarioScreen   = script.Parent
local DialoguePanel    = ScenarioScreen:WaitForChild("DialoguePanel")
local HUDTop           = ScenarioScreen:WaitForChild("HUDTop")
local TitleCardFrame   = ScenarioScreen:WaitForChild("TitleCardFrame")

local SpeakerRow       = DialoguePanel:WaitForChild("SpeakerRow")
local SpeakerInfo      = SpeakerRow:WaitForChild("SpeakerInfo")
local SpeakerName      = SpeakerInfo:WaitForChild("SpeakerName")
local SpeakerRole      = SpeakerInfo:WaitForChild("SpeakerRole")
local DialogueBubbleRow= DialoguePanel:WaitForChild("DialogueBubbleRow")
local DialogueText     = DialogueBubbleRow:WaitForChild("DialogueText")
local BottomRow        = DialoguePanel:WaitForChild("BottomRow")
local ButtonsContainer = BottomRow:WaitForChild("ButtonsContainer")
local ContinueButton   = ButtonsContainer:WaitForChild("TextButton")
local SkipButton       = ButtonsContainer:WaitForChild("SkipButton")
local ProgressDots     = BottomRow:WaitForChild("ProgressDots")
local Dot1             = ProgressDots:WaitForChild("Dot1")
local Dot2             = ProgressDots:WaitForChild("Dot2")
local Dot3             = ProgressDots:WaitForChild("Dot3")
local Dots             = { Dot1, Dot2, Dot3 }

local TitleCardLayout    = TitleCardFrame:WaitForChild("ThirdRowContainer")
local CasualtiesText     = TitleCardLayout:WaitForChild("CasualitiesPill"):WaitForChild("CasualitiesText")
local ModeText           = TitleCardLayout:WaitForChild("ModePill"):WaitForChild("ModeText")
local TimeText           = TitleCardLayout:WaitForChild("TimePill"):WaitForChild("TimeText")
local ScenarioDescText   = TitleCardFrame:WaitForChild("ScenarioDescText")
local ScenarioStartText  = TitleCardFrame:WaitForChild("ScenarioStartText")
local ScenarioTitleText  = TitleCardFrame:WaitForChild("ScenarioTitleText")

local PillsLeft          = HUDTop:WaitForChild("PillsContainerLeft")
local ModeBadge          = PillsLeft:WaitForChild("ModeBadge")
local ModeBadgeText      = ModeBadge:WaitForChild("ModeText")
local PillsRight         = HUDTop:WaitForChild("PillsContainerRight")
local ScenarioTagRight   = PillsRight:WaitForChild("ScenarioTag")
local TagTextRight       = ScenarioTagRight:WaitForChild("TagText")

local ScenarioData = require(ReplicatedStorage:WaitForChild("ScenarioData"))

local BriefingDoneEvent = ReplicatedStorage:FindFirstChild("RemoteEvents")
	and ReplicatedStorage.RemoteEvents:FindFirstChild("BriefingDone")

-- HideCinematicNPCs remote
local hideNPCRemote = ReplicatedStorage:WaitForChild("HideCinematicNPCs")

local FADE_TIME        = 0.5
local TITLE_HOLD_TIME  = 2.5
local TYPEWRITER_SPEED = 0.03

local currentScenario  = nil
local dialogueLines    = {}
local currentLine      = 1
local isTyping         = false
local skipTyping       = false

local function setVisible(frame, visible)
	frame.Visible = visible
end

local function formatTime(seconds)
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

local function updateDots(activeDot)
	local activeColor   = Color3.fromRGB(255, 255, 255)
	local inactiveColor = Color3.fromRGB(100, 100, 100)
	for i, dot in ipairs(Dots) do
		dot.BackgroundColor3 = (i == activeDot) and activeColor or inactiveColor
	end
end

local function typewriteText(label, fullText)
	isTyping   = true
	skipTyping = false
	label.Text = ""
	for i = 1, #fullText do
		if skipTyping then
			label.Text = fullText
			break
		end
		label.Text = string.sub(fullText, 1, i)
		task.wait(TYPEWRITER_SPEED)
	end
	isTyping = false
end

local function populateTitleCard(scenario)
	ScenarioTitleText.Text  = scenario.title
	ScenarioDescText.Text   = scenario.description
	CasualtiesText.Text     = tostring(scenario.casualtyCount) .. " Korban"
	ModeText.Text           = scenario.mode
	TimeText.Text           = formatTime(scenario.estimatedTime)
	ModeBadgeText.Text      = scenario.mode
	TagTextRight.Text       = scenario.title
end

-- Sembunyikan NPC cinematic (stretcher, dummy, workers)
local function hideCinematicNPCs()
	local toHide = {"StretcherCinematic", "Dummy", "Worker 1", "Worker 2"}
	for _, name in ipairs(toHide) do
		local obj = workspace:FindFirstChild(name)
		if obj then
			-- Sembunyikan semua parts
			for _, part in ipairs(obj:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 1
				end
				if part:IsA("Decal") or part:IsA("Texture") then
					part.Transparency = 1
				end
			end
			-- Kalau obj sendiri BasePart
			if obj:IsA("BasePart") then
				obj.Transparency = 1
			end
		end
	end
end

-- Listen ke server signal untuk hide NPC
hideNPCRemote.OnClientEvent:Connect(function()
	hideCinematicNPCs()
end)

local function showDialogueLine(index)
	local line = dialogueLines[index]
	if not line then return end
	currentLine = index
	updateDots(index)
	SpeakerName.Text = line.speakerName
	SpeakerRole.Text = line.speakerRole
	typewriteText(DialogueText, line.text)
	if index == #dialogueLines then
		ContinueButton.Text = "Mulai Triase →"
	else
		ContinueButton.Text = "Continue"
	end
end

local function onBriefingFinished()
	setVisible(DialoguePanel, false)
	setVisible(HUDTop, false)
	if BriefingDoneEvent then
		BriefingDoneEvent:FireServer(currentScenario.id)
	end
	print("[ScenarioScreen] Briefing done — scenario:", currentScenario.id)
end

ContinueButton.MouseButton1Click:Connect(function()
	if isTyping then
		skipTyping = true
		return
	end
	if currentLine < #dialogueLines then
		showDialogueLine(currentLine + 1)
	else
		onBriefingFinished()
	end
end)

SkipButton.MouseButton1Click:Connect(function()
	skipTyping = true
	onBriefingFinished()
end)

local function startScenario(scenario)
	currentScenario = scenario
	dialogueLines   = scenario.dialogue or {}
	currentLine     = 1

	setVisible(TitleCardFrame, false)
	setVisible(DialoguePanel,  false)
	setVisible(HUDTop,         false)

	populateTitleCard(scenario)
	setVisible(TitleCardFrame, true)

	task.spawn(function()
		local alpha = true
		for _ = 1, 6 do
			ScenarioStartText.TextTransparency = alpha and 0 or 0.6
			alpha = not alpha
			task.wait(0.35)
		end
		ScenarioStartText.TextTransparency = 0
	end)

	task.wait(TITLE_HOLD_TIME)
	setVisible(TitleCardFrame, false)
	task.wait(0.2)

	-- NPC disembunyikan saat briefing mau mulai
	hideCinematicNPCs()

	setVisible(HUDTop, true)
	setVisible(DialoguePanel, true)
	showDialogueLine(1)
end

ScenarioScreen:GetAttributeChangedSignal("StartDialogue"):Connect(function()
	if ScenarioScreen:GetAttribute("StartDialogue") then
		local scenarioId = ScenarioScreen:GetAttribute("ScenarioId") or "food_poisoning"
		local scenario = ScenarioData.GetScenario(scenarioId) or ScenarioData.GetDefault()
		startScenario(scenario)
	end
end)