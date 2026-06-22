-- PatientGenerator (ModuleScript) — ReplicatedStorage
-- Generates patient objects at runtime using ConditionPool data.
-- Output shape is identical to PatientPool entries so PatientSpawner
-- can consume generated patients WITHOUT any changes to spawn logic.
--
-- Usage:
--   local PatientGenerator = require(RS:WaitForChild("PatientGenerator"))
--   local patients = PatientGenerator.GenerateForScenario("food_poisoning", 11)

local PatientGenerator = {}

local ConditionPool = require(script.Parent:WaitForChild("ConditionPool"))

-- ── START Algorithm ────────────────────────────────────────────────────────────
-- Returns the correct triage category based on vitals
local function applySTART(rr, crt, gcs)
	if rr == 0 then
		return "BLACK"
	end
	if rr > 30 then
		return "RED"
	end
	if crt == "Terlambat" then
		return "RED"
	end
	if gcs < 13 then
		return "RED"
	end
	-- All parameters within normal range
	-- GREEN requires canWalk = true, handled at generation level
	return "YELLOW"
end

-- ── Random int in range ────────────────────────────────────────────────────────
local function randInt(min, max)
	if min == max then return min end
	return math.random(min, max)
end

-- ── Random gender ──────────────────────────────────────────────────────────────
local function randomGender()
	return math.random() > 0.5 and "Laki-laki" or "Perempuan"
end

-- ── Random name pools ──────────────────────────────────────────────────────────
local maleNames = {
	"Budi", "Andi", "Riko", "Hendra", "Fajar", "Dani", "Wahyu", "Rizky",
	"Arif", "Bagas", "Dimas", "Eko", "Fauzi", "Gilang", "Hamdan", "Ikhsan",
	"Joko", "Kevin", "Lukman", "Malik", "Nanda", "Okta", "Putra", "Reza",
	"Sandi", "Teguh", "Umar", "Vino", "Wawan", "Yoga", "Zaki", "Agus",
}

local femaleNames = {
	"Sari", "Dewi", "Rina", "Fitri", "Ayu", "Nisa", "Dian", "Wulan",
	"Rini", "Putri", "Mega", "Lina", "Indah", "Hani", "Gita", "Fira",
	"Elsa", "Desi", "Citra", "Bella", "Anita", "Yeni", "Zahra", "Tasya",
	"Sinta", "Rara", "Qori", "Pipit", "Okta", "Nuri", "Mila", "Lena",
}

local usedNames = {}  -- reset per GenerateForScenario call

local function randomName(gender)
	local pool = gender == "Perempuan" and femaleNames or maleNames
	-- Try to pick unused name first
	local attempts = 0
	local name
	repeat
		name = pool[math.random(#pool)]
		attempts += 1
	until not usedNames[name] or attempts > 10
	usedNames[name] = true
	return name
end

-- ── Random age by triage severity ─────────────────────────────────────────────
local function randomAge(triageCategory)
	if triageCategory == "RED" or triageCategory == "BLACK" then
		-- Wider range, skewed older (higher risk)
		return randInt(22, 68)
	elseif triageCategory == "YELLOW" then
		return randInt(18, 65)
	else
		return randInt(17, 55)
	end
end

-- ── Distribution generator (RNG / gacha-style) ────────────────────────────────
-- Each session rolls a random "weight" for RED/YELLOW/GREEN independently.
-- BLACK: 0 or 1, 50% chance (only if scenario has BLACK conditions & count >= 4)
-- RED:   always at least 1, weight randomized 15–50%
-- GREEN: always at least 1, weight randomized 10–35%
-- YELLOW: fills the remainder
--
-- This means every session feels different — sometimes RED-heavy,
-- sometimes YELLOW-heavy, occasionally almost all GREEN.
local function generateDistribution(scenarioId, count)
	local hasBlack = #ConditionPool.Get(scenarioId, "BLACK") > 0
	local distribution = {}

	-- BLACK: 50/50 per session (only if available and enough patients)
	local blackCount = 0
	if hasBlack and count >= 4 then
		blackCount = math.random() < 0.10 and 1 or 0
	end

	local remaining = count - blackCount

	-- Roll random weights for this session (gacha-style)
	local redWeight   = math.random(15, 50) / 100   -- 15% to 50%
	local greenWeight = math.random(10, 35) / 100   -- 10% to 35%

	-- Clamp so RED + GREEN don't exceed 80% (leave room for YELLOW)
	if redWeight + greenWeight > 0.80 then
		local scale = 0.80 / (redWeight + greenWeight)
		redWeight   = redWeight   * scale
		greenWeight = greenWeight * scale
	end

	-- Convert weights to counts, minimum 1 each
	local redCount   = math.max(1, math.floor(remaining * redWeight))
	local greenCount = math.max(1, math.floor(remaining * greenWeight))

	-- Make sure RED + GREEN doesn't eat all slots
	if redCount + greenCount >= remaining then
		redCount   = math.max(1, remaining - 2)
		greenCount = 1
	end

	-- YELLOW: remainder (minimum 0 — possible if count is small)
	local yellowCount = remaining - redCount - greenCount
	if yellowCount < 0 then
		-- Trim green first, then red
		greenCount = math.max(0, greenCount + yellowCount)
		yellowCount = 0
	end

	-- Log the rolled weights for this session
	print(string.format("[PatientGenerator] Session RNG → RED:%.0f%% GREEN:%.0f%% YELLOW:remainder",
		redWeight * 100, greenWeight * 100))

	-- Build flat list
	for _ = 1, blackCount  do table.insert(distribution, "BLACK")  end
	for _ = 1, redCount    do table.insert(distribution, "RED")    end
	for _ = 1, yellowCount do table.insert(distribution, "YELLOW") end
	for _ = 1, greenCount  do table.insert(distribution, "GREEN")  end

	-- Shuffle (Fisher-Yates)
	for i = #distribution, 2, -1 do
		local j = math.random(i)
		distribution[i], distribution[j] = distribution[j], distribution[i]
	end

	return distribution
end

-- ── Build vitals string (CRT format) ──────────────────────────────────────────
local function formatCRT(crtStatus)
	if crtStatus == "Terlambat" then
		return ">2 detik"
	else
		return "≤2 detik"
	end
end

-- ── Generate one patient from a condition ─────────────────────────────────────
local function generatePatient(index, scenarioId, targetTriage)
	local condition = ConditionPool.GetRandom(scenarioId, targetTriage)
	if not condition then
		warn("[PatientGenerator] No condition found for", scenarioId, targetTriage)
		-- Fallback: safe GREEN patient
		return {
			id          = string.format("gen_%s_%03d", scenarioId:sub(1,4), index),
			scenarioId  = scenarioId,
			name        = "Pasien " .. index,
			age         = randInt(20, 50),
			gender      = randomGender(),
			complaint   = "Keluhan tidak tersedia.",
			vitals      = { airway = "Bebas", rr = 16, td = "115/75 mmHg", nadi = 80, crt = "≤2 detik", gcs = 15 },
			diagnosis   = "Tidak diketahui",
			correctTriage = "GREEN",
			targetRoom  = "Zona Hijau / Minor Treatment Room",
			conditionName = "Tidak Diketahui",
		}
	end

	-- Generate vitals within condition ranges
	local rr   = randInt(condition.rr[1], condition.rr[2])
	local nadi = randInt(condition.nadi[1], condition.nadi[2])
	local gcs  = randInt(condition.gcs[1], condition.gcs[2])
	local crt  = condition.crt
	local tdSys = randInt(condition.td_sys[1], condition.td_sys[2])
	local tdDia = math.floor(tdSys * 0.62) -- approximate diastolic

	-- For BLACK patients keep everything at 0
	if targetTriage == "BLACK" then
		rr   = 0
		nadi = 0
		gcs  = 3
		tdSys = 0
		tdDia = 0
	end

	-- Re-verify with START (catches edge cases at range boundaries)
	local verifiedTriage = applySTART(rr, crt, gcs)
	-- If verifiedTriage conflicts with target, adjust gcs slightly
	if targetTriage == "RED" and verifiedTriage ~= "RED" then
		-- Force RED by pushing CRT to Terlambat
		crt = "Terlambat"
		verifiedTriage = "RED"
	elseif targetTriage == "GREEN" and condition.canWalk then
		verifiedTriage = "GREEN"
	elseif targetTriage == "YELLOW" and verifiedTriage == "GREEN" then
		verifiedTriage = "YELLOW" -- canWalk false keeps it YELLOW
	end

	-- Target room by triage
	local targetRoom
	if verifiedTriage == "RED" or verifiedTriage == "BLACK" then
		targetRoom = "Ruang Resusitasi"
	elseif verifiedTriage == "YELLOW" then
		targetRoom = "Ruang Observasi"
	else
		targetRoom = "Zona Hijau / Minor Treatment Room"
	end

	-- Airway string
	local airway
	if rr == 0 then
		airway = "Tidak ada napas setelah dibuka"
	elseif gcs <= 10 then
		airway = "Terbuka, perlu reposisi"
	elseif gcs <= 13 then
		airway = "Terbuka, respons lambat"
	else
		airway = "Bebas"
	end

	-- SpO2 (only if condition defines it)
	local spo2 = 0
	if condition.spo2 then
		spo2 = randInt(condition.spo2[1], condition.spo2[2])
	end

	local gender = randomGender()
	local pName  = randomName(gender)

	return {
		id            = string.format("gen_%s_%03d", scenarioId:sub(1,4), index),
		scenarioId    = scenarioId,
		name          = pName,
		age           = randomAge(verifiedTriage),
		gender        = gender,
		complaint     = condition.complaint,
		conditionName = condition.name,  -- revealed after triage submission
		vitals        = {
			airway = airway,
			rr     = rr,
			td     = string.format("%d/%d mmHg", tdSys, tdDia),
			nadi   = nadi,
			crt    = formatCRT(crt),
			gcs    = gcs,
			spo2   = spo2,
		},
		diagnosis     = condition.name,
		correctTriage = verifiedTriage,
		targetRoom    = targetRoom,
		deteriorationRate = condition.deteriorationRate or 0,
	}
end

-- ── Public API ─────────────────────────────────────────────────────────────────

-- Generate `count` patients for a scenario.
-- Returns array of patient objects in same shape as PatientPool.
function PatientGenerator.GenerateForScenario(scenarioId, count)
	usedNames = {}  -- reset per session so names don't carry over
	local distribution = generateDistribution(scenarioId, count)
	local patients = {}

	for i, triageCategory in ipairs(distribution) do
		local patient = generatePatient(i, scenarioId, triageCategory)
		table.insert(patients, patient)
	end

	print(string.format("[PatientGenerator] Generated %d patients for '%s'", #patients, scenarioId))

	-- Debug: log distribution summary
	local summary = { RED = 0, YELLOW = 0, GREEN = 0, BLACK = 0 }
	for _, p in ipairs(patients) do
		summary[p.correctTriage] = (summary[p.correctTriage] or 0) + 1
	end
	print(string.format("[PatientGenerator] Distribution → RED:%d YELLOW:%d GREEN:%d BLACK:%d",
		summary.RED, summary.YELLOW, summary.GREEN, summary.BLACK))

	return patients
end

-- ── Unique ID counter untuk pasien runtime (endless / MP / IoT) ───────────────
-- [FIX] Dulu pakai math.random(100, 999) → ID bisa BENTROK di endless run yang
-- panjang, bikin triase ditolak diam-diam ("Already triaged") + bed nyangkut.
-- Counter monotonic ini ngejamin ID selalu unik selama server hidup.
-- Offset 1000 supaya gak pernah nabrak ID dari GenerateForScenario (1..count).
local genOneCounter = 0

-- Generate a single random patient (used by IoT ADD_PATIENT and multiplayer)
-- This replaces the old `generateRandomPatient()` in PatientSpawner
function PatientGenerator.GenerateOne(scenarioId)
	scenarioId = scenarioId or "food_poisoning"
	-- Weighted random: 30% RED, 50% YELLOW, 20% GREEN
	local roll = math.random()
	local triage
	if roll < 0.30 then
		triage = "RED"
	elseif roll < 0.80 then
		triage = "YELLOW"
	else
		triage = "GREEN"
	end

	-- Fallback if no condition found for that triage
	local condition = ConditionPool.GetRandom(scenarioId, triage)
	if not condition then
		triage = "YELLOW"
	end

	genOneCounter += 1
	return generatePatient(1000 + genOneCounter, scenarioId, triage)
end

return PatientGenerator
