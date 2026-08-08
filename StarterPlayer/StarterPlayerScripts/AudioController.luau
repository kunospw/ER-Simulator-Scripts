-- AudioController (LocalScript)
-- StarterPlayer > StarterPlayerScripts

local Players         = game:GetService("Players")
local RS              = game:GetService("ReplicatedStorage")
local SoundService    = game:GetService("SoundService")
local UIS             = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer

-- ═════════════════════════════════════════════════════════════
-- CONFIG — ID
-- ═════════════════════════════════════════════════════════════
local SOUND_IDS = {
	ambience   = "rbxassetid://9125446564",      
	menuMusic  = "rbxassetid://108828449206604",               
	correct    = "rbxassetid://109836938138193",
	wrong      = "rbxassetid://137327891291996",
	timeout    = "rbxassetid://2124207508",      
	tick       = "rbxassetid://134410911353980",
	sessionEnd = "rbxassetid://76943780441459",
	uiClick    = "rbxassetid://9083627113",               -- ← ISI INI (click pendek)
	uiOpen     = "rbxassetid://115916891254154",               -- ← opsional (panel muncul / whoosh)
	typewriter = "rbxassetid://9120299710",               -- ← opsional (blip dialog)
}

-- ═════════════════════════════════════════════════════════════
-- CONFIG — volume
-- ═════════════════════════════════════════════════════════════
local VOL = {
	ambience   = 0.25,
	menuMusic  = 0.20,
	sfx        = 0.45,
	tick       = 0.28,
	uiClick    = 0.35,
	uiOpen     = 0.30,
	typewriter = 0.12,
}

-- ═════════════════════════════════════════════════════════════
-- CONFIG — nama instance (benerin kalau di GUI kamu beda)
-- ═════════════════════════════════════════════════════════════
local MAIN_MENU_GUI   = "MainMenuGui"
local GAMEPLAY_GUI    = "GameplayScreenGui"
local TIMER_LABEL     = "TimeText"

-- Frame yang kalau muncul bakal bunyi "uiOpen"
local PANEL_NAMES = {
	"SessionResultFrame",
	"DialoguePanel",      
	"TitleCardFrame",
	"MainMenuFrame",
}

-- Label dialog briefing (buat blip typewriter)
local DIALOGUE_LABEL_NAMES = {
	"DialogueText",
	"LineText",
	"BriefingText",
}

local TICK_THRESHOLD  = 10
local PANIC_THRESHOLD = 3
local PANIC_PITCH     = 1.3
local MUTE_KEY        = Enum.KeyCode.M
local TYPEWRITER_GAP  = 0.045   -- jeda minimum antar blip
local DEBUG           = true    -- set false setelah semua beres

-- Tombol yang TIDAK dikasih click sound (isi nama kalau perlu)
local CLICK_EXCLUDE = {
	-- ["RedButton"] = true,
}

-- ═════════════════════════════════════════════════════════════

local function isValid(id)
	return typeof(id) == "string" and id ~= "" and id ~= "rbxassetid://0"
end

local function log(...)
	if DEBUG then print("[AudioController]", ...) end
end

-- ── Sound groups ─────────────────────────────────────────────
local function getGroup(name)
	local g = SoundService:FindFirstChild(name)
	if not g then
		g = Instance.new("SoundGroup")
		g.Name   = name
		g.Parent = SoundService
	end
	g.Volume = 1
	return g
end

local musicGroup = getGroup("ER_Music")
local sfxGroup   = getGroup("ER_SFX")

-- ── Factory ──────────────────────────────────────────────────
local created = {}

local function makeSound(key, id, volume, group, looped)
	if not isValid(id) then
		log("skip (ID kosong):", key)
		return nil
	end
	local s = Instance.new("Sound")
	s.Name       = "ER_" .. key
	s.SoundId    = id
	s.Volume     = volume
	s.Looped     = looped or false
	s.SoundGroup = group
	s.Parent     = SoundService
	created[key] = s
	return s
end

local ambience   = makeSound("ambience",   SOUND_IDS.ambience,   VOL.ambience,   musicGroup, true)
local menuMusic  = makeSound("menuMusic",  SOUND_IDS.menuMusic,  VOL.menuMusic,  musicGroup, true)
local sfxCorrect = makeSound("correct",    SOUND_IDS.correct,    VOL.sfx,        sfxGroup)
local sfxWrong   = makeSound("wrong",      SOUND_IDS.wrong,      VOL.sfx,        sfxGroup)
local sfxTimeout = makeSound("timeout",    SOUND_IDS.timeout,    VOL.sfx,        sfxGroup)
local sfxTick    = makeSound("tick",       SOUND_IDS.tick,       VOL.tick,       sfxGroup)
local sfxEnd     = makeSound("sessionEnd", SOUND_IDS.sessionEnd, VOL.sfx,        sfxGroup)
local sfxClick   = makeSound("uiClick",    SOUND_IDS.uiClick,    VOL.uiClick,    sfxGroup)
local sfxOpen    = makeSound("uiOpen",     SOUND_IDS.uiOpen,     VOL.uiOpen,     sfxGroup)
local sfxType    = makeSound("typewriter", SOUND_IDS.typewriter, VOL.typewriter, sfxGroup)

local function play(sound)
	if not sound then return end
	sound.TimePosition = 0
	sound:Play()
end

-- ── Preload + DIAGNOSTIC ─────────────────────────────────────
task.spawn(function()
	local list = {}
	for _, s in pairs(created) do table.insert(list, s) end

	if #list > 0 then
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
		if not ok then warn("[AudioController] Preload gagal:", err) end
	end

	if DEBUG then
		print("───── AUDIO DIAGNOSTIC ─────")
		for key, s in pairs(created) do
			local len = s.TimeLength
			print(string.format("%-12s | loaded=%s | length=%.2fs%s",
				key,
				tostring(s.IsLoaded),
				len,
				(len == 0) and "   ← ASSET BERMASALAH" or ""
				))
		end
		print("────────────────────────────")
	end

	if ambience then ambience:Play() end
end)

-- ── DEBUG: dump struktur PlayerGui ───────────────────────────
if DEBUG then
	task.spawn(function()
		task.wait(8)
		print("───── PLAYERGUI DUMP ─────")
		for _, sg in ipairs(player.PlayerGui:GetChildren()) do
			if sg:IsA("ScreenGui") then
				print(string.format("ScreenGui: %s  | Enabled=%s", sg.Name, tostring(sg.Enabled)))
				for _, child in ipairs(sg:GetChildren()) do
					if child:IsA("GuiObject") then
						print(string.format("      └ %s  (%s)  Visible=%s",
							child.Name, child.ClassName, tostring(child.Visible)))
					end
				end
			end
		end
		print("──────────────────────────")
	end)
end

-- ── Music switching: menu vs gameplay ────────────────────────
local function fadeTo(sound, target, dur)
	if not sound then return end
	TweenService:Create(sound, TweenInfo.new(dur or 0.8), { Volume = target }):Play()
end

local function normalize(s)
	return (s:lower():gsub("[^%a]", ""))
end

local function findMenuGui()
	-- 1. exact match
	local exact = player.PlayerGui:FindFirstChild(MAIN_MENU_GUI)
	if exact and exact:IsA("ScreenGui") then return exact end

	-- 2. keyword match (mainmenu / menu)
	for _, sg in ipairs(player.PlayerGui:GetChildren()) do
		if sg:IsA("ScreenGui") then
			local n = normalize(sg.Name)
			if n:find("mainmenu") then return sg end
		end
	end
	for _, sg in ipairs(player.PlayerGui:GetChildren()) do
		if sg:IsA("ScreenGui") and normalize(sg.Name):find("menu") then
			return sg
		end
	end

	return nil
end

task.spawn(function()
	if not menuMusic then
		warn("[AudioController] menuMusic nil — ID invalid")
		return
	end

	local boundGui, boundConn = nil, nil

	local function apply(inMenu)
		if inMenu then
			if not menuMusic.IsPlaying then menuMusic:Play() end
			fadeTo(menuMusic, VOL.menuMusic)
			if ambience then fadeTo(ambience, 0) end
		else
			fadeTo(menuMusic, 0)
			if ambience then
				if not ambience.IsPlaying then ambience:Play() end
				fadeTo(ambience, VOL.ambience)
			end
		end
		log("music →", inMenu and "MENU" or "GAMEPLAY")
	end

	local function bind(gui)
		if gui == boundGui then return end
		if boundConn then boundConn:Disconnect() end

		boundGui  = gui
		boundConn = gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			apply(gui.Enabled)
		end)

		log("menu GUI bound:", gui.Name, "| Enabled =", gui.Enabled)
		apply(gui.Enabled)
	end

	-- Polling 20 detik, jangan WaitForChild (nama belum pasti)
	local found = nil
	for _ = 1, 40 do
		found = findMenuGui()
		if found then break end
		task.wait(0.5)
	end

	if found then
		bind(found)
	else
		warn("[AudioController] Nggak nemu ScreenGui menu — cek PLAYERGUI DUMP")
		-- Fallback: musik nyala terus, biar nggak sunyi total
		menuMusic:Play()
		fadeTo(menuMusic, VOL.menuMusic * 0.6)
	end

	-- Re-bind kalau GUI dibuat ulang (ResetOnSpawn)
	player.PlayerGui.ChildAdded:Connect(function(child)
		if not child:IsA("ScreenGui") then return end
		task.wait(0.2)
		local g = findMenuGui()
		if g then bind(g) end
	end)
end)

-- ── UI click sound (auto-hook semua tombol) ──────────────────
task.spawn(function()
	if not sfxClick then return end

	local hooked = setmetatable({}, { __mode = "k" })

	local function hook(obj)
		if not obj:IsA("GuiButton") then return end
		if hooked[obj] then return end
		if CLICK_EXCLUDE[obj.Name] then return end
		hooked[obj] = true
		obj.Activated:Connect(function()
			play(sfxClick)
		end)
	end

	for _, v in ipairs(player.PlayerGui:GetDescendants()) do hook(v) end
	player.PlayerGui.DescendantAdded:Connect(hook)

	log("UI click hooked")
end)

-- ── Panel muncul (briefing, hasil sesi, dll) ─────────────────
task.spawn(function()
	if not sfxOpen then return end

	local watched = setmetatable({}, { __mode = "k" })
	local wanted  = {}
	for _, n in ipairs(PANEL_NAMES) do wanted[n] = true end

	local function watch(obj)
		if watched[obj] then return end
		if not obj:IsA("GuiObject") then return end
		if not wanted[obj.Name] then return end
		watched[obj] = true
		obj:GetPropertyChangedSignal("Visible"):Connect(function()
			if obj.Visible then play(sfxOpen) end
		end)
		log("panel watched:", obj.Name)
	end

	for _, v in ipairs(player.PlayerGui:GetDescendants()) do watch(v) end
	player.PlayerGui.DescendantAdded:Connect(watch)
end)

-- ── Typewriter blip ──────────────────────────────────────────
task.spawn(function()
	if not sfxType then return end

	local watched = setmetatable({}, { __mode = "k" })
	local wanted  = {}
	for _, n in ipairs(DIALOGUE_LABEL_NAMES) do wanted[n] = true end

	local lastPlay = 0

	local function watch(obj)
		if watched[obj] then return end
		if not obj:IsA("TextLabel") then return end
		if not wanted[obj.Name] then return end
		watched[obj] = true
		obj:GetPropertyChangedSignal("Text"):Connect(function()
			local now = os.clock()
			if now - lastPlay < TYPEWRITER_GAP then return end
			if obj.Text == "" then return end
			lastPlay = now
			play(sfxType)
		end)
		log("dialogue watched:", obj.Name)
	end

	for _, v in ipairs(player.PlayerGui:GetDescendants()) do watch(v) end
	player.PlayerGui.DescendantAdded:Connect(watch)
end)

-- ── Triage result SFX ────────────────────────────────────────
local triageResultRemote = RS:WaitForChild("TriageResult")

triageResultRemote.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then return end
	if data.chosen == "TIMEOUT" then
		play(sfxTimeout or sfxWrong)
	elseif data.isCorrect then
		play(sfxCorrect)
	else
		play(sfxWrong)
	end
end)

-- ── Session complete SFX ─────────────────────────────────────
local sessionRemote = RS:FindFirstChild("SessionComplete")
if sessionRemote and sessionRemote:IsA("RemoteEvent") then
	sessionRemote.OnClientEvent:Connect(function()
		play(sfxEnd)
	end)
end

-- ── Countdown tick ───────────────────────────────────────────
task.spawn(function()
	if not sfxTick then return end

	local gui = player.PlayerGui:WaitForChild(GAMEPLAY_GUI, 30)
	if not gui then
		warn("[AudioController] '" .. GAMEPLAY_GUI .. "' nggak ketemu — tick di-skip")
		return
	end

	local timeText = gui:FindFirstChild(TIMER_LABEL, true)
	if not timeText or not timeText:IsA("TextLabel") then
		warn("[AudioController] '" .. TIMER_LABEL .. "' nggak ketemu — tick di-skip")
		return
	end

	log("tick hooked ke", timeText:GetFullName())

	local lastTicked = nil

	timeText:GetPropertyChangedSignal("Text"):Connect(function()
		local parts = string.split(timeText.Text, ":")
		if #parts ~= 2 then return end

		local mins = tonumber(parts[1])
		local secs = tonumber(parts[2])
		if not mins or not secs then return end

		local total = mins * 60 + secs

		if total > 0 and total <= TICK_THRESHOLD and total ~= lastTicked then
			lastTicked = total
			sfxTick.PlaybackSpeed = (total <= PANIC_THRESHOLD) and PANIC_PITCH or 1
			play(sfxTick)
		elseif total > TICK_THRESHOLD then
			lastTicked = nil
		end
	end)
end)

-- ── Mute toggle (M) ──────────────────────────────────────────
local muted = false

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= MUTE_KEY then return end

	muted = not muted
	musicGroup.Volume = muted and 0 or 1
	sfxGroup.Volume   = muted and 0 or 1
	print("[AudioController] Audio", muted and "MUTED" or "ON")
end)