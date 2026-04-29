-- LocalScript (inside ScenarioScreen)
-- Controls the full intro flow:
--   1. TitleCardFrame fades in → shown for a moment → fades out
--   2. DialoguePanel + HUDTop fade in → briefing plays line by line
--   3. Continue advances dialogue, Skip jumps to end
-- After briefing ends, this script fires a signal so the game can begin.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ── References ────────────────────────────────────────────────────────────────

local ScenarioScreen   = script.Parent
local DialoguePanel    = ScenarioScreen:WaitForChild("DialoguePanel")
local HUDTop           = ScenarioScreen:WaitForChild("HUDTop")
local TitleCardFrame   = ScenarioScreen:WaitForChild("TitleCardFrame")

-- DialoguePanel children
local SpeakerRow       = DialoguePanel:WaitForChild("SpeakerRow")
local SpeakerInfo      = SpeakerRow:WaitForChild("SpeakerInfo")
local SpeakerName      = SpeakerInfo:WaitForChild("SpeakerName")
local SpeakerRole      = SpeakerInfo:WaitForChild("SpeakerRole")
local DialogueBubbleRow= DialoguePanel:WaitForChild("DialogueBubbleRow")
local DialogueText     = DialogueBubbleRow:WaitForChild("DialogueText")
local BottomRow        = DialoguePanel:WaitForChild("BottomRow")
local ButtonsContainer = BottomRow:WaitForChild("ButtonsContainer")
local ContinueButton   = ButtonsContainer:WaitForChild("TextButton")   -- "Continue"
local SkipButton       = ButtonsContainer:WaitForChild("SkipButton")   -- "Skip Briefing"
local ProgressDots     = BottomRow:WaitForChild("ProgressDots")
local Dot1             = ProgressDots:WaitForChild("Dot1")
local Dot2             = ProgressDots:WaitForChild("Dot2")
local Dot3             = ProgressDots:WaitForChild("Dot3")
local Dots             = { Dot1, Dot2, Dot3 }

-- TitleCardFrame children
local TitleCardLayout    = TitleCardFrame:WaitForChild("ThirdRowContainer")
local CasualtiesText     = TitleCardLayout:WaitForChild("CasualitiesPill"):WaitForChild("CasualitiesText")
local ModeText           = TitleCardLayout:WaitForChild("ModePill"):WaitForChild("ModeText")
local TimeText           = TitleCardLayout:WaitForChild("TimePill"):WaitForChild("TimeText")
local ScenarioDescText   = TitleCardFrame:WaitForChild("ScenarioDescText")
local ScenarioStartText  = TitleCardFrame:WaitForChild("ScenarioStartText")
local ScenarioTitleText  = TitleCardFrame:WaitForChild("ScenarioTitleText")

-- HUDTop children
local PillsLeft          = HUDTop:WaitForChild("PillsContainerLeft")
local ModeBadge          = PillsLeft:WaitForChild("ModeBadge")
local ModeBadgeText      = ModeBadge:WaitForChild("ModeText")
local PillsRight         = HUDTop:WaitForChild("PillsContainerRight")
local ScenarioTagRight   = PillsRight:WaitForChild("ScenarioTag")
local TagTextRight       = ScenarioTagRight:WaitForChild("TagText")

-- ScenarioData module (place in ReplicatedStorage)
local ScenarioData = require(ReplicatedStorage:WaitForChild("ScenarioData"))

-- RemoteEvent to signal briefing done (optional – for server communication)
-- If you haven't set this up yet, the script will skip it gracefully.
local BriefingDoneEvent = ReplicatedStorage:FindFirstChild("RemoteEvents")
	and ReplicatedStorage.RemoteEvents:FindFirstChild("BriefingDone")

-- ── Config ────────────────────────────────────────────────────────────────────

local FADE_TIME        = 0.5   -- seconds for fade tweens
local TITLE_HOLD_TIME  = 2.5   -- how long TitleCard stays fully visible
local TYPEWRITER_SPEED = 0.03  -- seconds per character (typewriter effect)

-- ── State ─────────────────────────────────────────────────────────────────────

local currentScenario  = nil
local dialogueLines    = {}
local currentLine      = 1
local isTyping         = false
local skipTyping       = false

-- ── Utility ───────────────────────────────────────────────────────────────────

local function fadeFrame(frame, targetAlpha, duration)
	local tween = TweenService:Create(
		frame,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ GroupTransparency = targetAlpha }
	)
	tween:Play()
	return tween
end

-- Fallback: if the frame isn't a CanvasGroup, tween BackgroundTransparency
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

-- ── Typewriter Effect ─────────────────────────────────────────────────────────

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

-- ── Populate TitleCardFrame ───────────────────────────────────────────────────

local function populateTitleCard(scenario)
	ScenarioTitleText.Text  = scenario.title
	ScenarioDescText.Text   = scenario.description
	CasualtiesText.Text     = tostring(scenario.casualtyCount) .. " Korban"
	ModeText.Text           = scenario.mode
	TimeText.Text           = formatTime(scenario.estimatedTime)

	-- Also populate HUDTop
	ModeBadgeText.Text      = scenario.mode
	TagTextRight.Text       = scenario.title
end

-- ── Dialogue Logic ────────────────────────────────────────────────────────────

local function showDialogueLine(index)
	local line = dialogueLines[index]
	if not line then return end

	currentLine = index
	updateDots(index)

	SpeakerName.Text = line.speakerName
	SpeakerRole.Text = line.speakerRole

	-- Typewrite the dialogue text
	typewriteText(DialogueText, line.text)

	-- Update Continue button label on last line
	if index == #dialogueLines then
		ContinueButton.Text = "Mulai Triase →"
	else
		ContinueButton.Text = "Continue"
	end
end

local function onBriefingFinished()
	-- Hide DialoguePanel, keep HUDTop visible
	setVisible(DialoguePanel, false)
	setVisible(HUDTop, false)
	-- Fire server event if it exists
	if BriefingDoneEvent then
		BriefingDoneEvent:FireServer(currentScenario.id)
	end

	-- TODO: trigger your triage gameplay here
	-- e.g., show TriageFrame, spawn NPC patients, start timer
	print("[ScenarioScreen] Briefing done — scenario:", currentScenario.id)
end

-- ── Button Handlers ───────────────────────────────────────────────────────────

ContinueButton.MouseButton1Click:Connect(function()
	-- If still typing, skip to end of current line
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
	-- Jump straight past the briefing
	skipTyping = true
	onBriefingFinished()
end)

-- ── Main Flow ─────────────────────────────────────────────────────────────────

local function startScenario(scenario)
	currentScenario = scenario
	dialogueLines   = scenario.dialogue or {}
	currentLine     = 1

	-- Step 0: Hide everything initially
	setVisible(TitleCardFrame, false)
	setVisible(DialoguePanel,  false)
	setVisible(HUDTop,         false)

	-- Step 1: Populate and show TitleCardFrame
	populateTitleCard(scenario)
	setVisible(TitleCardFrame, true)

	-- Animate ScenarioStartText blinking (optional flair)
	task.spawn(function()
		local alpha = true
		for _ = 1, 6 do
			ScenarioStartText.TextTransparency = alpha and 0 or 0.6
			alpha = not alpha
			task.wait(0.35)
		end
		ScenarioStartText.TextTransparency = 0
	end)

	-- Hold for TITLE_HOLD_TIME, then fade out TitleCardFrame
	task.wait(TITLE_HOLD_TIME)
	setVisible(TitleCardFrame, false)
	task.wait(0.2)

	-- Step 2: Show HUDTop + DialoguePanel
	setVisible(HUDTop, true)
	setVisible(DialoguePanel, true)

	-- Start first dialogue line
	showDialogueLine(1)
end

-- ── Entry Point ───────────────────────────────────────────────────────────────

-- Get which scenario to load. 
-- Change "food_poisoning" to whichever scenario ID you want to test,
-- or pass it dynamically via a RemoteEvent / attribute.
local scenarioId = ScenarioScreen:GetAttribute("ScenarioId") or "food_poisoning"
local scenario   = ScenarioData.GetScenario(scenarioId)

if not scenario then
	warn("[ScenarioScreen] Scenario not found:", scenarioId)
	scenario = ScenarioData.GetDefault()
end

-- Small startup delay so the screen is ready
ScenarioScreen:GetAttributeChangedSignal("StartDialogue"):Connect(function()
	if ScenarioScreen:GetAttribute("StartDialogue") then
		startScenario(scenario) -- or whatever your entry function is
	end
end)