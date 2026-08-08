-- ScenarioData (ModuleScript) — ReplicatedStorage
-- Patients are now generated at runtime by PatientGenerator.
-- PatientPool is no longer used here.

local PatientGenerator = require(script.Parent:WaitForChild("PatientGenerator"))

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
			{
				speakerName = "dr. Hartono",
				speakerRole = "Kepala UGD — RS Harapan Sehat",
				text = "Sebelas pekerja sedang dalam perjalanan ke UGD. Keluhannya mual, muntah, dan diare setelah makan siang bersama.",
				dot = 1
			},
			{
				speakerName = "dr. Hartono",
				speakerRole = "Kepala UGD — RS Harapan Sehat",
				text = "Mayoritas mulai bergejala sekitar 3 sampai 5 jam setelah makan. Ada yang masih bisa berjalan sendiri, tapi beberapa tampak dehidrasi dan lemas.",
				dot = 2
			},
			{
				speakerName = "dr. Hartono",
				speakerRole = "Kepala UGD — RS Harapan Sehat",
				text = "Prioritaskan pasien dengan tanda syok, penurunan kesadaran, atau perfusi yang buruk. Gunakan sistem triase START untuk menentukan prioritas.",
				dot = 3
			},
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
			{
				speakerName = "dr. Sari",
				speakerRole = "Dokter Jaga UGD — RS Harapan Sehat",
				text = "Terjadi ledakan di laboratorium kimia sekitar pukul 09.45. Beberapa pekerja sedang dirujuk ke UGD dengan berbagai jenis cedera.",
				dot = 1
			},
			{
				speakerName = "dr. Sari",
				speakerRole = "Dokter Jaga UGD — RS Harapan Sehat",
				text = "Laporan awal menyebutkan ada luka bakar, cedera mata akibat serpihan, dan trauma akibat gelombang ledakan.",
				dot = 2
			},
			{
				speakerName = "dr. Sari",
				speakerRole = "Dokter Jaga UGD — RS Harapan Sehat",
				text = "Lakukan triase cepat dan tentukan siapa yang harus masuk zona resusitasi lebih dulu.",
				dot = 3
			},
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
			{
				speakerName = "Perawat Triase",
				speakerRole = "Koordinator Triase — UGD",
				text = "Dokter, UGD sedang penuh dan beberapa pasien baru datang hampir bersamaan. Tolong lakukan triase sekarang.",
				dot = 1
			},
			{
				speakerName = "Perawat Triase",
				speakerRole = "Koordinator Triase — UGD",
				text = "Kasusnya beragam, mulai dari penyakit kronis yang memburuk sampai trauma akibat kecelakaan.",
				dot = 2
			},
			{
				speakerName = "Perawat Triase",
				speakerRole = "Koordinator Triase — UGD",
				text = "Gunakan penilaian START. Identifikasi siapa yang paling membutuhkan penanganan segera.",
				dot = 3
			},
		},
	},
	{
		id = "traffic_accident",
		title = "Kecelakaan Lalu Lintas Beruntun",
		description = "Tabrakan beruntun di jalan tol pagi hari melibatkan bus dan beberapa kendaraan. Korban dengan derajat cedera bervariasi dirujuk ke UGD.",
		mode = "Challenge Mode",
		casualtyCount = 6,
		estimatedTime = 600,
		difficulty = "medium",
		dialogue = {
			{
				speakerName = "dr. Anwar",
				speakerRole = "Kepala UGD — RS Harapan Sehat",
				text = "Terjadi tabrakan beruntun di jalan tol pagi ini. Korban mulai berdatangan dari lokasi kejadian.",
				dot = 1
			},
			{
				speakerName = "dr. Anwar",
				speakerRole = "Kepala UGD — RS Harapan Sehat",
				text = "Cedera yang dilaporkan bervariasi, mulai dari luka ringan sampai trauma kepala dan trauma dada berat.",
				dot = 2
			},
			{
				speakerName = "dr. Anwar",
				speakerRole = "Kepala UGD — RS Harapan Sehat",
				text = "Lakukan triase cepat. Prioritaskan pasien dengan gangguan napas, perfusi buruk, atau penurunan kesadaran.",
				dot = 3
			},
		},
	},
	{
		id = "earthquake_collapse",
		title = "Gempa Bumi — Bangunan Runtuh",
		description = "Gempa berkekuatan besar menyebabkan sebuah gedung runtuh. Tim SAR mengevakuasi korban secara bertahap ke UGD dengan cedera akibat reruntuhan.",
		mode = "Exam Mode",
		casualtyCount = 6,
		estimatedTime = 600,
		difficulty = "hard",
		dialogue = {
			{
				speakerName = "dr. Sari",
				speakerRole = "Dokter Jaga UGD — RS Harapan Sehat",
				text = "Gempa menyebabkan runtuhnya sebuah gedung perkantoran. Tim SAR masih terus mengevakuasi korban ke sini.",
				dot = 1
			},
			{
				speakerName = "dr. Sari",
				speakerRole = "Dokter Jaga UGD — RS Harapan Sehat",
				text = "Korban yang datang mengalami berbagai cedera, termasuk fraktur, crush injury, trauma kepala, dan gangguan napas akibat debu reruntuhan.",
				dot = 2
			},
			{
				speakerName = "dr. Sari",
				speakerRole = "Dokter Jaga UGD — RS Harapan Sehat",
				text = "Sumber daya terbatas dan korban akan terus berdatangan. Gunakan triase START untuk menentukan prioritas penanganan.",
				dot = 3
			},
		},
	},
	{
		id = "earthquake_jababeka",
		title = "Bencana Gempa Bumi 7,8 SR",
		description = "Gempa berkekuatan 7,8 SR mengguncang Jababeka selama 5 menit. Banyak korban tertimpa bangunan yang runtuh dan mengalami kecelakaan kerja akibat mesin produksi yang mengalami malfungsi.",
		mode = "Challenge Mode",
		casualtyCount = 10,
		estimatedTime = 300,
		difficulty = "hard",
		dialogue = {
			{
				speakerName = "dr. Radite NS, Sp.OK, M.K.K.",
				speakerRole = "Kepala UGD — Klinik Utama Universitas Presiden",
				text = "Lakukan segera triase menggunakan pendekatan START.",
				dot = 1
			},
			{
				speakerName = "dr. Ridwansyah",
				speakerRole = "Dokter Umum — Klinik Utama Universitas Presiden",
				text = "Baik, kami lakukan segera.",
				dot = 2
			},
			{
				speakerName = "dr. Radite NS, Sp.OK, M.K.K.",
				speakerRole = "Kepala UGD — Klinik Utama Universitas Presiden",
				text = "Ayo lekas bekerja!",
				dot = 3
			},
		},
	},
}

-- Patients are generated fresh each time GetScenario is called.
-- This means every session has a different patient mix.
function ScenarioData.GetScenario(scenarioId)
	for _, scenario in ipairs(ScenarioData.Scenarios) do
		if scenario.id == scenarioId then
			local scenarioCopy = table.clone(scenario)
			scenarioCopy.patients = PatientGenerator.GenerateForScenario(scenarioId, scenario.casualtyCount)
			return scenarioCopy
		end
	end
	return nil
end

function ScenarioData.GetDefault()
	return ScenarioData.GetScenario("food_poisoning")
end

return ScenarioData