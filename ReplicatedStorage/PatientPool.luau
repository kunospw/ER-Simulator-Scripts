-- PatientPool (ModuleScript) — ReplicatedStorage

local PatientPool = {}

PatientPool.Patients = {

	-- ══════════════════════════════════════════
	-- FOOD POISONING POOL
	-- ══════════════════════════════════════════
	{
		id = "patient_10", scenarioId = "food_poisoning",
		name = "Pasien 10", age = 35, gender = "Laki-laki",
		complaint = "Muntah hebat, diare >10x, nyeri perut kram sejak 4 jam. Mata cekung, akral pucat, tampak mengantuk.",
		vitals = { airway = "Terbuka, respons lambat", rr = 28, td = "70/45 mmHg", nadi = 138, crt = ">4 detik", gcs = 12 },
		diagnosis = "Gastroenteritis akut dengan syok hipovolemik",
		correctTriage = "RED", targetRoom = "Ruang Resusitasi",
		management = "2 akses IV, bolus RL 20–30 mL/kg, antiemetik IV, koreksi elektrolit.",
	},
	{
		id = "patient_11", scenarioId = "food_poisoning",
		name = "Pasien 11", age = 30, gender = "Perempuan",
		complaint = "Mual, muntah, diare berulang. Masih mampu minum, tidak ada tanda perfusi buruk.",
		vitals = { airway = "Bebas", rr = 22, td = "105/70 mmHg", nadi = 112, crt = "≤2 detik", gcs = 15 },
		diagnosis = "Gastroenteritis akut dengan dehidrasi ringan–sedang",
		correctTriage = "YELLOW", targetRoom = "Ruang Observasi",
		management = "Rehidrasi oral atau IV RL 100 mL/jam, antiemetik, observasi 2–4 jam.",
	},
	{
		id = "patient_12", scenarioId = "food_poisoning",
		name = "Pasien 12", age = 29, gender = "Perempuan",
		complaint = "Kelemahan progresif, bicara sengau, ptosis, penglihatan ganda, mulut kering, sulit menelan. Riwayat makan makanan kaleng.",
		vitals = { airway = "Parsial — suara melemah, risiko gagal napas", rr = 24, td = "95/60 mmHg", nadi = 118, crt = ">2 detik", gcs = 14 },
		diagnosis = "Kecurigaan botulisme — paralisis neuromuskular progresif",
		correctTriage = "RED", targetRoom = "Ruang Resusitasi",
		management = "Siapkan intubasi dini, O₂ 10–15 L/min, rehidrasi IV, Botulinum Antitoxin.",
	},
	{
		id = "patient_13", scenarioId = "food_poisoning",
		name = "Pasien 13", age = 22, gender = "Laki-laki",
		complaint = "Diare 8x, mual, kram perut. Masih sadar dan bisa berjalan sendiri masuk UGD.",
		vitals = { airway = "Bebas", rr = 19, td = "112/74 mmHg", nadi = 104, crt = "≤2 detik", gcs = 15 },
		diagnosis = "Gastroenteritis akut dengan dehidrasi ringan",
		correctTriage = "YELLOW", targetRoom = "Ruang Observasi",
		management = "Rehidrasi oral, antiemetik, observasi.",
	},
	{
		id = "patient_14", scenarioId = "food_poisoning",
		name = "Pasien 14", age = 45, gender = "Laki-laki",
		complaint = "Muntah 5x, pusing, lemas. Riwayat hipertensi. Masih responsif dan kooperatif.",
		vitals = { airway = "Bebas", rr = 21, td = "130/85 mmHg", nadi = 98, crt = "≤2 detik", gcs = 15 },
		diagnosis = "Gastroenteritis akut dengan dehidrasi ringan, riwayat hipertensi",
		correctTriage = "YELLOW", targetRoom = "Ruang Observasi",
		management = "Rehidrasi IV, monitor tekanan darah, antiemetik.",
	},
	{
		id = "patient_15", scenarioId = "food_poisoning",
		name = "Pasien 15", age = 38, gender = "Perempuan",
		complaint = "Diare >10x, muntah, nyeri perut hebat. Akral dingin, nadi teraba lemah, tampak sangat pucat.",
		vitals = { airway = "Bebas", rr = 26, td = "82/55 mmHg", nadi = 128, crt = "3 detik", gcs = 13 },
		diagnosis = "Gastroenteritis akut dengan dehidrasi berat, pre-syok",
		correctTriage = "RED", targetRoom = "Ruang Resusitasi",
		management = "2 IV line, bolus RL agresif, monitor ketat, antiemetik IV.",
	},
	{
		id = "patient_16", scenarioId = "food_poisoning",
		name = "Pasien 16", age = 27, gender = "Laki-laki",
		complaint = "Mual dan muntah 3x, sedikit lemas. Masih makan dan minum siang ini. Berjalan masuk sendiri.",
		vitals = { airway = "Bebas", rr = 18, td = "118/76 mmHg", nadi = 92, crt = "≤2 detik", gcs = 15 },
		diagnosis = "Gastroenteritis akut ringan",
		correctTriage = "YELLOW", targetRoom = "Ruang Observasi",
		management = "Rehidrasi oral, antiemetik oral, edukasi tanda bahaya.",
	},
	{
		id = "patient_17", scenarioId = "food_poisoning",
		name = "Pasien 17", age = 52, gender = "Laki-laki",
		complaint = "Muntah dan diare sejak 3 jam. Riwayat DM tipe 2. Tampak lemas tapi masih responsif.",
		vitals = { airway = "Bebas", rr = 23, td = "110/70 mmHg", nadi = 110, crt = "2 detik", gcs = 15 },
		diagnosis = "Gastroenteritis akut dengan dehidrasi sedang, riwayat DM",
		correctTriage = "YELLOW", targetRoom = "Ruang Observasi",
		management = "Rehidrasi IV, cek GDS serial, antiemetik, monitor ketat.",
	},
	{
		id = "patient_18", scenarioId = "food_poisoning",
		name = "Pasien 18", age = 33, gender = "Perempuan",
		complaint = "Diare 6x, kram perut, tidak muntah. Masih bisa minum. Sedikit pusing saat berdiri.",
		vitals = { airway = "Bebas", rr = 20, td = "108/68 mmHg", nadi = 100, crt = "≤2 detik", gcs = 15 },
		diagnosis = "Gastroenteritis akut dengan dehidrasi ringan",
		correctTriage = "YELLOW", targetRoom = "Ruang Observasi",
		management = "Rehidrasi oral, observasi, antiemetik bila perlu.",
	},
	{
		id = "patient_19", scenarioId = "food_poisoning",
		name = "Pasien 19", age = 41, gender = "Laki-laki",
		complaint = "Tidak sadar tiba-tiba di ruang tunggu. Sebelumnya mengeluh pusing dan diare berat. Keringat dingin.",
		vitals = { airway = "Terbuka, perlu reposisi", rr = 30, td = "68/40 mmHg", nadi = 142, crt = ">4 detik", gcs = 9 },
		diagnosis = "Syok hipovolemik berat akibat gastroenteritis",
		correctTriage = "RED", targetRoom = "Ruang Resusitasi",
		management = "Airway positioning, 2 IV line besar, bolus RL 30 mL/kg, pertimbangkan vasopresor.",
	},
	{
		id = "patient_20", scenarioId = "food_poisoning",
		name = "Pasien 20", age = 19, gender = "Perempuan",
		complaint = "Mual ringan, belum muntah, sedikit kram perut. Makan siang yang sama. Merasa khawatir.",
		vitals = { airway = "Bebas", rr = 17, td = "115/75 mmHg", nadi = 88, crt = "≤2 detik", gcs = 15 },
		diagnosis = "Gastroenteritis akut gejala minimal",
		correctTriage = "GREEN", targetRoom = "Zona Hijau / Minor Treatment Room",
		management = "Observasi, rehidrasi oral, edukasi, pulang dengan instruksi tanda bahaya.",
	},

	-- ══════════════════════════════════════════
	-- INDUSTRIAL EXPLOSION POOL
	-- ══════════════════════════════════════════
	{
		id = "worker_1", scenarioId = "industrial_explosion",
		name = "Pekerja 1", age = 28, gender = "Laki-laki",
		complaint = "Rasa perih di mata, kemerahan di wajah dengan bullae. Serpihan kaca di konjungtiva.",
		vitals = { airway = "Bebas", rr = 23, td = "110/78 mmHg", nadi = 89, crt = "<2 detik", gcs = 15 },
		diagnosis = "Benda asing di konjungtiva, luka bakar ringan derajat 2",
		correctTriage = "GREEN", targetRoom = "Zona Hijau / Minor Treatment Room",
		management = "Irigasi mata, bilas wajah dengan air mengalir, antibiotik topikal, sterile dressing.",
	},
	{
		id = "worker_2", scenarioId = "industrial_explosion",
		name = "Pekerja 2", age = 34, gender = "Laki-laki",
		complaint = "Telinga berdenging, nyeri, pendengaran berkurang. Daun telinga kanan robek.",
		vitals = { airway = "Bebas", rr = 18, td = "120/88 mmHg", nadi = 99, crt = "<2 detik", gcs = 15 },
		diagnosis = "Trauma akustik dan trauma aurikular",
		correctTriage = "YELLOW", targetRoom = "Ruang Observasi",
		management = "Pembersihan, penjahitan aurikular, kontrol Poli THT.",
	},
	{
		id = "worker_3", scenarioId = "industrial_explosion",
		name = "Pekerja 3", age = 41, gender = "Laki-laki",
		complaint = "Luka parah di lengan dan wajah, kulit tampak dasar putih dikelilingi lepuhan. Penurunan kesadaran.",
		vitals = { airway = "Bebas", rr = 33, spo2 = 93, td = "90/59 mmHg", nadi = 126, crt = "2 detik", gcs = 10 },
		diagnosis = "Luka bakar derajat 3 dan trauma akustik",
		correctTriage = "RED", targetRoom = "Ruang Resusitasi",
		management = "Airway dengan C-spine control, O₂ NRM 10 L/mnt, siapkan intubasi, 2 IV line besar, resusitasi Parkland Formula.",
	},
	{
		id = "worker_4", scenarioId = "industrial_explosion",
		name = "Pekerja 4", age = 25, gender = "Laki-laki",
		complaint = "Nyeri hebat di mata, luka robek kecil di kelopak mata kanan. Percikan bahan kimia langsung mengenai wajah.",
		vitals = { airway = "Bebas", rr = 18, td = "Stabil", nadi = 90, crt = "<2 detik", gcs = 15 },
		diagnosis = "Laserasi kelopak mata dan luka akibat bahan kimia",
		correctTriage = "YELLOW", targetRoom = "Ruang Tindakan",
		management = "Irigasi segera dan terus-menerus, hecting kelopak mata, antibiotik topikal, analgesik sistemik.",
	},

	-- ══════════════════════════════════════════
	-- MIXED ACUTE POOL
	-- ══════════════════════════════════════════
	{
		id = "patient_5", scenarioId = "mixed_acute",
		name = "Pasien 5", age = 58, gender = "Laki-laki",
		complaint = "Mengantuk, bicara mengigau, muntah sejak pagi. Riwayat hemodialisis rutin, tidak HD selama 5 hari.",
		vitals = { airway = "Terbuka", rr = 24, td = "150/92 mmHg", nadi = 98, crt = "<2 detik", gcs = 12 },
		diagnosis = "CKD — uremia akut",
		correctTriage = "YELLOW", targetRoom = "Ruang Observasi",
		management = "Pasang IV, cek elektrolit/ureum-kreatinin, EKG, pertimbangkan dialisis emergensi.",
	},
	{
		id = "patient_6", scenarioId = "mixed_acute",
		name = "Pasien 6", age = 64, gender = "Laki-laki",
		complaint = "Sesak napas tiba-tiba sejak 2 jam, batuk dahak kuning, gelisah. Perokok berat, PPOK tidak kontrol 6 bulan.",
		vitals = { airway = "Bebas", rr = 35, spo2 = 88, td = "140/86 mmHg", nadi = 112, gcs = 15 },
		diagnosis = "PPOK Eksaserbasi Akut",
		correctTriage = "RED", targetRoom = "Ruang Resusitasi",
		management = "O₂ nasal/venturi, nebulisasi salbutamol + ipratropium, steroid IV, foto thorax.",
	},
	{
		id = "patient_7", scenarioId = "mixed_acute",
		name = "Pasien 7", age = 20, gender = "Laki-laki",
		complaint = "Demam 6 hari, lemah, nyeri perut kanan atas, mimisan. Diagnosis dengue 2 hari lalu. Tidak BAK sejak kemarin.",
		vitals = { airway = "Bebas", rr = 30, td = "90/60 mmHg", nadi = 122, crt = "3 detik", gcs = 15 },
		diagnosis = "Demam Dengue dengan warning sign — syok",
		correctTriage = "RED", targetRoom = "Ruang Resusitasi",
		management = "2 IV line, cairan kristaloid bolus 10–20 mL/kg, cek Hb/Ht/trombosit, O₂, monitor ketat.",
	},
	{
		id = "patient_8", scenarioId = "mixed_acute",
		name = "Pasien 8", age = 50, gender = "Laki-laki",
		complaint = "Ditemukan tidak responsif di rumah. Tidak sadar, tidak bernapas, tidak ada nadi karotis.",
		vitals = { airway = "Tidak ada napas setelah dibuka", rr = 0, td = "Tidak terukur", nadi = 0, gcs = 3 },
		diagnosis = "Cardiac Arrest",
		correctTriage = "RED", targetRoom = "Ruang Resusitasi / Red Zone",
		management = "CPR kualitas tinggi, monitor/defibrilasi, IV adrenalin 1mg tiap 3–5 mnt, airway management.",
	},
	{
		id = "patient_9", scenarioId = "mixed_acute",
		name = "Pasien 9", age = 32, gender = "Laki-laki",
		complaint = "Kecelakaan motor. Luka terbuka paha kanan, fragmen tulang terlihat, perdarahan aktif.",
		vitals = { airway = "Bebas", rr = 24, td = "98/60 mmHg", nadi = 125, crt = "3 detik", gcs = 15 },
		diagnosis = "Open Fraktur Femur Dextra — risiko syok hemoragik",
		correctTriage = "RED", targetRoom = "Zona Merah / Ruang Resusitasi",
		management = "2 IV line, pressure dressing, imobilisasi splint, analgesik IV, antibiotik IV, tetanus profilaksis.",
	},
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Ambil semua pasien untuk satu scenario, urut sesuai urutan di array
function PatientPool.GetByScenario(scenarioId)
	local result = {}
	for _, p in ipairs(PatientPool.Patients) do
		if p.scenarioId == scenarioId then
			table.insert(result, p)
		end
	end
	return result
end

-- Ambil satu pasien by ID
function PatientPool.GetById(patientId)
	for _, p in ipairs(PatientPool.Patients) do
		if p.id == patientId then return p end
	end
	return nil
end

return PatientPool