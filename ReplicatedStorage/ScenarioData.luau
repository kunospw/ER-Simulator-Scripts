-- ScenarioData (ModuleScript) — ReplicatedStorage
local PatientPool = require(script.Parent:WaitForChild("PatientPool"))

local ScenarioData = {}

ScenarioData.Scenarios = {
	{
		id = "food_poisoning",
		title = "Keracunan Makanan",
		description = "Sebanyak 11 orang datang ke IGD dengan keluhan mual, muntah, dan diare setelah makan siang di Perusahaan XYZ, Bekasi.",
		mode = "Challenge Mode",
		casualtyCount = 11,
		estimatedTime = 600,
		difficulty = "medium",
		dialogue = {
			{ speakerName = "dr. Hartono", speakerRole = "Kepala UGD — RS Harapan Sehat", text = "4 korban sudah dalam perjalanan ke UGD kita. Kondisi bervariasi — luka bakar, trauma mata dan telinga, serta penurunan kesadaran.", dot = 1 },
			{ speakerName = "dr. Hartono", speakerRole = "Kepala UGD — RS Harapan Sehat", text = "Sebagian besar pekerja mulai mengalami gejala 3–5 jam setelah makan. Konsisten dengan foodborne intoxication dari acara katering.", dot = 2 },
			{ speakerName = "dr. Hartono", speakerRole = "Kepala UGD — RS Harapan Sehat", text = "Prioritaskan yang menunjukkan tanda syok atau penurunan kesadaran. Gunakan sistem triase START. Siap?", dot = 3 },
		},
	},
	{
		id = "industrial_explosion",
		title = "Kecelakaan Kerja — Ledakan Laboratorium",
		description = "Pukul 09.45, terjadi ledakan di laboratorium kimia industri. Beberapa pekerja dirujuk ke UGD RS dengan kondisi bervariasi.",
		mode = "Exam Mode",
		casualtyCount = 4,
		estimatedTime = 480,
		difficulty = "hard",
		dialogue = {
			{ speakerName = "dr. Sari", speakerRole = "Dokter Jaga UGD — RS Harapan Sehat", text = "Ledakan terjadi di laboratorium kimia pukul 09.45. Tim K3 merujuk beberapa pekerja ke sini dengan kondisi bervariasi.", dot = 1 },
			{ speakerName = "dr. Sari", speakerRole = "Dokter Jaga UGD — RS Harapan Sehat", text = "Sebagian memakai APD lengkap, sebagian tidak. Ada yang mengalami luka bakar, trauma mata, dan trauma akustik.", dot = 2 },
			{ speakerName = "dr. Sari", speakerRole = "Dokter Jaga UGD — RS Harapan Sehat", text = "Lakukan triase cepat. Tentukan zona yang tepat untuk setiap korban. Waktu adalah nyawa.", dot = 3 },
		},
	},
	{
		id = "mixed_acute",
		title = "UGD Overcrowded — Kasus Campuran",
		description = "UGD dalam kondisi penuh. Beberapa pasien datang bersamaan dengan penyakit kronis eksaserbasi, akut, dan trauma.",
		mode = "Training Mode",
		casualtyCount = 5,
		estimatedTime = 720,
		difficulty = "hard",
		dialogue = {
			{ speakerName = "Perawat Triase", speakerRole = "Koordinator Triase — UGD", text = "Dokter, UGD kita sedang kewalahan. Lima pasien baru masuk bersamaan. Tolong lakukan triase sekarang.", dot = 1 },
			{ speakerName = "Perawat Triase", speakerRole = "Koordinator Triase — UGD", text = "Ada pasien gagal ginjal, PPOK eksaserbasi, dengue dengan syok, dan korban kecelakaan motor dengan fraktur terbuka.", dot = 2 },
			{ speakerName = "Perawat Triase", speakerRole = "Koordinator Triase — UGD", text = "Gunakan penilaian START. Identifikasi siapa yang paling membutuhkan penanganan segera.", dot = 3 },
		},
	},
}

-- patients di-inject dari PatientPool saat runtime
for _, scenario in ipairs(ScenarioData.Scenarios) do
	scenario.patients = PatientPool.GetByScenario(scenario.id)
end

function ScenarioData.GetScenario(scenarioId)
	for _, scenario in ipairs(ScenarioData.Scenarios) do
		if scenario.id == scenarioId then return scenario end
	end
	return nil
end

function ScenarioData.GetDefault()
	return ScenarioData.Scenarios[1]
end

return ScenarioData