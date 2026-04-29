-- ScenarioData (ModuleScript)
-- Place this in ReplicatedStorage
-- Contains all scenario definitions based on the PKM document

local ScenarioData = {}

ScenarioData.Scenarios = {

	-- =============================================
	-- SCENARIO 1: KERACUNAN MAKANAN (Mass Casualty)
	-- =============================================
	{
		id = "food_poisoning",
		title = "Keracunan Makanan",
		description = "Sebanyak 11 orang datang ke IGD dengan keluhan mual, muntah, dan diare setelah makan siang di Perusahaan XYZ, Bekasi.",
		mode = "Challenge Mode",
		casualtyCount = 11,
		estimatedTime = 600, -- seconds (10 minutes)
		difficulty = "medium",

		-- Dialogue lines for the briefing (DialoguePanel)
		dialogue = {
			{
				speakerName = "dr. Hartono",
				speakerRole = "Kepala UGD — RS Harapan Sehat",
				text = "4 korban sudah dalam perjalanan ke UGD kita. Kondisi bervariasi — luka bakar, trauma mata dan telinga, serta penurunan kesadaran.",
				dot = 1,
			},
			{
				speakerName = "dr. Hartono",
				speakerRole = "Kepala UGD — RS Harapan Sehat",
				text = "Sebagian besar pekerja mulai mengalami gejala 3–5 jam setelah makan. Konsisten dengan foodborne intoxication dari acara katering.",
				dot = 2,
			},
			{
				speakerName = "dr. Hartono",
				speakerRole = "Kepala UGD — RS Harapan Sehat",
				text = "Prioritaskan yang menunjukkan tanda syok atau penurunan kesadaran. Gunakan sistem triase START. Siap?",
				dot = 3,
			},
		},

		-- Patients from the PDF
		patients = {
			{
				id = "patient_10",
				name = "Pasien 10",
				age = 35,
				gender = "Laki-laki",
				complaint = "Muntah hebat, diare >10x, nyeri perut kram sejak 4 jam. Mata cekung, akral pucat, tampak mengantuk.",
				vitals = {
					airway = "Terbuka, respons lambat",
					rr = 28,
					spo2 = nil,
					td = "70/45 mmHg",
					nadi = 138,
					crt = ">4 detik",
					gcs = 12,
				},
				diagnosis = "Gastroenteritis akut dengan syok hipovolemik",
				correctTriage = "RED",
				targetRoom = "Ruang Resusitasi",
				management = "2 akses IV, bolus RL 20–30 mL/kg, monitor hemodinamik, antiemetik IV (ondansetron), koreksi elektrolit.",
			},
			{
				id = "patient_11",
				name = "Pasien 11",
				age = 30, -- representative age for group
				gender = "Campuran",
				complaint = "Mual, muntah, diare berulang. Masih mampu minum, tidak ada tanda perfusi buruk.",
				vitals = {
					airway = "Bebas",
					rr = 22,
					spo2 = nil,
					td = "105/70 mmHg",
					nadi = 112,
					crt = "≤2 detik",
					gcs = 15,
				},
				diagnosis = "Gastroenteritis akut dengan dehidrasi ringan–sedang",
				correctTriage = "YELLOW",
				targetRoom = "Ruang Observasi",
				management = "Rehidrasi oral (ORS) atau IV RL/NS 100 mL/jam, antiemetik, observasi 2–4 jam.",
			},
			{
				id = "patient_12",
				name = "Pasien 12",
				age = 29,
				gender = "Perempuan",
				complaint = "Kelemahan progresif, bicara sengau, ptosis, penglihatan ganda, mulut kering, sulit menelan. Riwayat makan makanan kaleng.",
				vitals = {
					airway = "Parsial — suara melemah, risiko gagal napas",
					rr = 24,
					spo2 = nil,
					td = "95/60 mmHg",
					nadi = 118,
					crt = nil,
					gcs = 14,
				},
				diagnosis = "Kecurigaan botulisme — paralisis neuromuskular progresif",
				correctTriage = "RED",
				targetRoom = "Ruang Resusitasi",
				management = "Siapkan intubasi dini, O₂ 10–15 L/min, rehidrasi IV, Botulinum Antitoxin, observasi ketat fungsi pernapasan.",
			},
		},
	},

	-- =============================================
	-- SCENARIO 2: KECELAKAAN KERJA (Industrial Explosion)
	-- =============================================
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
				text = "Ledakan terjadi di laboratorium kimia pukul 09.45. Tim K3 merujuk beberapa pekerja ke sini dengan kondisi bervariasi.",
				dot = 1,
			},
			{
				speakerName = "dr. Sari",
				speakerRole = "Dokter Jaga UGD — RS Harapan Sehat",
				text = "Sebagian memakai APD lengkap, sebagian tidak. Ada yang mengalami luka bakar, trauma mata, dan trauma akustik.",
				dot = 2,
			},
			{
				speakerName = "dr. Sari",
				speakerRole = "Dokter Jaga UGD — RS Harapan Sehat",
				text = "Lakukan triase cepat. Tentukan zona yang tepat untuk setiap korban. Waktu adalah nyawa.",
				dot = 3,
			},
		},

		patients = {
			{
				id = "worker_1",
				name = "Pekerja 1",
				age = 28,
				gender = "Laki-laki",
				complaint = "Rasa perih di mata, kemerahan di wajah dengan bullae. Serpihan kaca di konjungtiva. Tidak memakai goggles.",
				vitals = {
					airway = "Bebas",
					rr = 23,
					spo2 = nil,
					td = "110/78 mmHg",
					nadi = 89,
					crt = "<2 detik",
					gcs = 15,
				},
				diagnosis = "Benda asing di konjungtiva, luka bakar ringan derajat 2",
				correctTriage = "GREEN",
				targetRoom = "Zona Hijau / Minor Treatment Room",
				management = "Irigasi mata, bilas wajah dengan air mengalir, antibiotik topikal, sterile dressing.",
			},
			{
				id = "worker_2",
				name = "Pekerja 2",
				age = 34,
				gender = "Laki-laki",
				complaint = "Telinga berdenging, nyeri, pendengaran berkurang. Daun telinga kanan robek. Pakai goggles tapi tidak pakai pelindung telinga.",
				vitals = {
					airway = "Bebas",
					rr = 18,
					spo2 = nil,
					td = "120/88 mmHg",
					nadi = 99,
					crt = "<2 detik",
					gcs = 15,
				},
				diagnosis = "Trauma akustik dan trauma aurikular",
				correctTriage = "YELLOW",
				targetRoom = "Ruang Observasi",
				management = "Pembersihan, penjahitan aurikular, kontrol Poli THT.",
			},
			{
				id = "worker_3",
				name = "Pekerja 3",
				age = 41,
				gender = "Laki-laki",
				complaint = "Luka parah di lengan dan wajah, kulit tampak dasar putih dikelilingi lepuhan. Penurunan kesadaran. Dekat titik ledakan.",
				vitals = {
					airway = "Bebas",
					rr = 33,
					spo2 = 93,
					td = "90/59 mmHg",
					nadi = 126,
					crt = "2 detik",
					gcs = 10,
				},
				diagnosis = "Luka bakar derajat 3 dan trauma akustik",
				correctTriage = "RED",
				targetRoom = "Ruang Resusitasi",
				management = "Airway dengan C-spine control, O₂ NRM 10 L/mnt, siapkan intubasi, 2 IV line besar, resusitasi Parkland Formula.",
			},
			{
				id = "worker_4",
				name = "Pekerja 4",
				age = 25,
				gender = "Laki-laki",
				complaint = "Nyeri hebat di mata, luka robek kecil di kelopak mata kanan. Percikan bahan kimia langsung mengenai wajah.",
				vitals = {
					airway = "Bebas",
					rr = 18,
					spo2 = nil,
					td = "Stabil",
					nadi = 90,
					crt = "<2 detik",
					gcs = 15,
				},
				diagnosis = "Laserasi kelopak mata dan luka akibat bahan kimia",
				correctTriage = "YELLOW",
				targetRoom = "Ruang Tindakan",
				management = "Irigasi segera dan terus-menerus, hecting kelopak mata, antibiotik topikal, analgesik sistemik, kontrol poli mata.",
			},
		},
	},

	-- =============================================
	-- SCENARIO 3: MIXED ACUTE (Multi-case ED)
	-- =============================================
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
				text = "Dokter, UGD kita sedang kewalahan. Lima pasien baru masuk bersamaan. Tolong lakukan triase sekarang.",
				dot = 1,
			},
			{
				speakerName = "Perawat Triase",
				speakerRole = "Koordinator Triase — UGD",
				text = "Ada pasien gagal ginjal, PPOK eksaserbasi, dengue dengan syok, dan korban kecelakaan motor dengan fraktur terbuka.",
				dot = 2,
			},
			{
				speakerName = "Perawat Triase",
				speakerRole = "Koordinator Triase — UGD",
				text = "Gunakan penilaian START. Identifikasi siapa yang paling membutuhkan penanganan segera.",
				dot = 3,
			},
		},

		patients = {
			{
				id = "patient_5",
				name = "Pasien 5",
				age = 58,
				gender = "Laki-laki",
				complaint = "Mengantuk, bicara mengigau, muntah sejak pagi. Riwayat hemodialisis rutin, tidak HD selama 5 hari.",
				vitals = {
					airway = "Terbuka",
					rr = 24,
					spo2 = nil,
					td = "150/92 mmHg",
					nadi = 98,
					crt = "<2 detik",
					gcs = 12,
				},
				diagnosis = "CKD — uremia akut",
				correctTriage = "YELLOW",
				targetRoom = "Ruang Observasi",
				management = "Pasang IV, cek elektrolit/ureum-kreatinin, EKG, pertimbangkan dialisis emergensi.",
			},
			{
				id = "patient_6",
				name = "Pasien 6",
				age = 64,
				gender = "Laki-laki",
				complaint = "Sesak napas tiba-tiba sejak 2 jam, batuk dahak kuning, gelisah. Perokok berat, PPOK tidak kontrol 6 bulan.",
				vitals = {
					airway = "Bebas",
					rr = 35,
					spo2 = 88,
					td = "140/86 mmHg",
					nadi = 112,
					crt = nil,
					gcs = 15,
				},
				diagnosis = "PPOK Eksaserbasi Akut",
				correctTriage = "RED",
				targetRoom = "Ruang Resusitasi",
				management = "O₂ nasal/venturi, nebulisasi salbutamol + ipratropium, steroid IV, foto thorax, analisis gas darah.",
			},
			{
				id = "patient_7",
				name = "Pasien 7",
				age = 20,
				gender = "Laki-laki",
				complaint = "Demam 6 hari, lemah, nyeri perut kanan atas, mimisan. Diagnosis dengue di klinik 2 hari lalu. Tidak BAK sejak kemarin.",
				vitals = {
					airway = "Bebas",
					rr = 30,
					spo2 = nil,
					td = "90/60 mmHg",
					nadi = 122,
					crt = "3 detik",
					gcs = 15,
				},
				diagnosis = "Demam Dengue dengan warning sign — syok",
				correctTriage = "RED",
				targetRoom = "Ruang Resusitasi",
				management = "2 IV line, cairan kristaloid bolus 10–20 mL/kg, cek Hb/Ht/trombosit, O₂, monitor ketat.",
			},
			{
				id = "patient_8",
				name = "Pasien 8",
				age = 50,
				gender = "Laki-laki",
				complaint = "Ditemukan tidak responsif di rumah. Tidak sadar, tidak bernapas, tidak ada nadi karotis.",
				vitals = {
					airway = "Tidak ada napas setelah dibuka",
					rr = 0,
					spo2 = nil,
					td = "Tidak terukur",
					nadi = 0,
					crt = nil,
					gcs = 3,
				},
				diagnosis = "Cardiac Arrest",
				correctTriage = "RED",
				targetRoom = "Ruang Resusitasi / Red Zone",
				management = "CPR kualitas tinggi, monitor/defibrilasi, IV adrenalin 1mg tiap 3–5 mnt, airway management.",
				note = "Langsung masuk protokol CPR — tidak dinilai dengan START biasa.",
			},
			{
				id = "patient_9",
				name = "Pasien 9",
				age = 32,
				gender = "Laki-laki",
				complaint = "Kecelakaan motor. Luka terbuka paha kanan, fragmen tulang terlihat, perdarahan aktif.",
				vitals = {
					airway = "Bebas",
					rr = 24,
					spo2 = nil,
					td = "98/60 mmHg",
					nadi = 125,
					crt = "3 detik",
					gcs = 15,
				},
				diagnosis = "Open Fraktur Femur Dextra — risiko syok hemoragik",
				correctTriage = "RED",
				targetRoom = "Zona Merah / Ruang Resusitasi",
				management = "2 IV line, pressure dressing, imobilisasi splint, analgesik IV, antibiotik IV, tetanus profilaksis, X-ray femur.",
			},
		},
	},
}

-- Helper: get scenario by ID
function ScenarioData.GetScenario(scenarioId)
	for _, scenario in ipairs(ScenarioData.Scenarios) do
		if scenario.id == scenarioId then
			return scenario
		end
	end
	return nil
end

-- Helper: get first scenario (default)
function ScenarioData.GetDefault()
	return ScenarioData.Scenarios[1]
end

return ScenarioData