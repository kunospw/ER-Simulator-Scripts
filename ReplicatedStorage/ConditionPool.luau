-- ConditionPool (ModuleScript) — ReplicatedStorage
-- Pure data: semua health conditions per scenario per triage category
-- Vitals ranges dipakai PatientGenerator untuk generate realistic values
-- START algorithm rules:
--   RR = 0              → BLACK
--   RR > 30             → RED
--   CRT = "Terlambat"   → RED
--   GCS < 13            → RED
--   Semua normal        → YELLOW / GREEN

local ConditionPool = {}

-- ── Vital range helpers ────────────────────────────────────────────────────────
-- rr      : { min, max }   breaths/min
-- nadi    : { min, max }   bpm
-- gcs     : { min, max }   3–15
-- crt     : "Normal" | "Terlambat"
-- spo2    : { min, max }   % (nil = tidak diukur)
-- td_sys  : { min, max }   systolic mmHg
-- canWalk : bool           true = pasien bisa jalan → kandidat GREEN

ConditionPool.Conditions = {

	-- ══════════════════════════════════════════════════════════════════════════
	-- FOOD POISONING
	-- ══════════════════════════════════════════════════════════════════════════
	food_poisoning = {

		BLACK = {
			{
				name        = "Syok Hipovolemik Terminal",
				complaint   = "Tidak sadar tiba-tiba. Sebelumnya diare berat dan keringat dingin.",
				rr          = { 0, 0 },        -- tidak bernapas
				nadi        = { 0, 0 },
				gcs         = { 3, 3 },
				crt         = "Terlambat",
				td_sys      = { 0, 50 },
				canWalk     = false,
				deteriorationRate = 0,         -- sudah tidak bisa deteriorate
			},
		},

		RED = {
			{
				name        = "Syok Hipovolemik",
				complaint   = "Muntah hebat, diare >10x, nyeri perut kram. Mata cekung, akral pucat, tampak mengantuk.",
				rr          = { 26, 32 },
				nadi        = { 125, 145 },
				gcs         = { 9, 12 },
				crt         = "Terlambat",
				td_sys      = { 60, 85 },
				canWalk     = false,
				deteriorationRate = 0.8,
			},
			{
				name        = "Botulisme — Paralisis Neuromuskular",
				complaint   = "Kelemahan progresif, bicara sengau, ptosis, penglihatan ganda, mulut kering, sulit menelan. Riwayat makan makanan kaleng.",
				rr          = { 23, 28 },
				nadi        = { 110, 130 },
				gcs         = { 10, 13 },
				crt         = "Terlambat",
				td_sys      = { 85, 100 },
				canWalk     = false,
				deteriorationRate = 1.0,       -- cepat memburuk
			},
			{
				name        = "Dehidrasi Berat — Pre-syok",
				complaint   = "Diare >10x, muntah, nyeri perut hebat. Akral dingin, nadi teraba lemah, tampak sangat pucat.",
				rr          = { 24, 30 },
				nadi        = { 120, 135 },
				gcs         = { 11, 13 },
				crt         = "Terlambat",
				td_sys      = { 75, 95 },
				canWalk     = false,
				deteriorationRate = 0.7,
			},
		},

		YELLOW = {
			{
				name        = "Dehidrasi Sedang",
				complaint   = "Mual, muntah, diare berulang. Masih mampu minum, tidak ada tanda perfusi buruk.",
				rr          = { 20, 24 },
				nadi        = { 100, 118 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 95, 115 },
				canWalk     = false,
				deteriorationRate = 0.3,
			},
			{
				name        = "Dehidrasi Sedang — Riwayat DM",
				complaint   = "Muntah dan diare sejak 3 jam. Riwayat DM tipe 2. Tampak lemas tapi masih responsif.",
				rr          = { 21, 25 },
				nadi        = { 105, 118 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 100, 118 },
				canWalk     = false,
				deteriorationRate = 0.4,       -- lebih berisiko karena DM
			},
			{
				name        = "Dehidrasi Ringan — Riwayat Hipertensi",
				complaint   = "Muntah 5x, pusing, lemas. Riwayat hipertensi. Masih responsif dan kooperatif.",
				rr          = { 19, 23 },
				nadi        = { 92, 105 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 120, 145 },
				canWalk     = false,
				deteriorationRate = 0.2,
			},
			{
				name        = "Dehidrasi Ringan",
				complaint   = "Diare 8x, mual, kram perut. Masih sadar dan bisa berjalan sendiri masuk UGD.",
				rr          = { 17, 22 },
				nadi        = { 98, 112 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 100, 120 },
				canWalk     = false,
				deteriorationRate = 0.2,
			},
			{
				name        = "Gastroenteritis — Dehidrasi Ringan dengan Ortostatik",
				complaint   = "Diare 6x, kram perut, tidak muntah. Masih bisa minum. Sedikit pusing saat berdiri.",
				rr          = { 18, 22 },
				nadi        = { 95, 108 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 100, 115 },
				canWalk     = false,
				deteriorationRate = 0.2,
			},
		},

		GREEN = {
			{
				name        = "Gastroenteritis Ringan",
				complaint   = "Mual ringan, belum muntah, sedikit kram perut. Makan siang yang sama. Merasa khawatir.",
				rr          = { 15, 19 },
				nadi        = { 78, 95 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 108, 125 },
				canWalk     = true,
				deteriorationRate = 0.0,
			},
			{
				name        = "Gastroenteritis Gejala Minimal",
				complaint   = "Mual dan muntah 3x, sedikit lemas. Masih makan dan minum siang ini. Berjalan masuk sendiri.",
				rr          = { 16, 20 },
				nadi        = { 82, 98 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 110, 125 },
				canWalk     = true,
				deteriorationRate = 0.0,
			},
		},
	},

	-- ══════════════════════════════════════════════════════════════════════════
	-- INDUSTRIAL EXPLOSION
	-- ══════════════════════════════════════════════════════════════════════════
	industrial_explosion = {

		BLACK = {
			{
				name        = "Luka Bakar Derajat 3 — Full Thickness Luas",
				complaint   = "Tidak responsif. Luka bakar luas menutupi dada dan kedua lengan. Tidak ada reflek nyeri.",
				rr          = { 0, 0 },
				nadi        = { 0, 0 },
				gcs         = { 3, 3 },
				crt         = "Terlambat",
				td_sys      = { 0, 0 },
				canWalk     = false,
				deteriorationRate = 0,
			},
		},

		RED = {
			{
				name        = "Luka Bakar Derajat 3 dengan Penurunan Kesadaran",
				complaint   = "Luka parah di lengan dan wajah, kulit tampak dasar putih dikelilingi lepuhan. Penurunan kesadaran.",
				rr          = { 30, 36 },
				nadi        = { 118, 135 },
				gcs         = { 8, 12 },
				crt         = "Terlambat",
				spo2        = { 88, 94 },
				td_sys      = { 82, 98 },
				canWalk     = false,
				deteriorationRate = 0.9,
			},
			{
				name        = "Trauma Inhalasi — Sumbatan Jalan Napas Parsial",
				complaint   = "Suara serak progresif, stridor, sesak napas. Terpapar asap ledakan langsung di ruangan tertutup.",
				rr          = { 28, 35 },
				nadi        = { 112, 130 },
				gcs         = { 11, 14 },
				crt         = "Terlambat",
				spo2        = { 86, 92 },
				td_sys      = { 88, 105 },
				canWalk     = false,
				deteriorationRate = 1.0,
			},
		},

		YELLOW = {
			{
				name        = "Trauma Akustik dan Laserasi Aurikular",
				complaint   = "Telinga berdenging, nyeri, pendengaran berkurang. Daun telinga kanan robek.",
				rr          = { 16, 20 },
				nadi        = { 90, 108 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 110, 132 },
				canWalk     = false,
				deteriorationRate = 0.1,
			},
			{
				name        = "Laserasi Kelopak Mata — Paparan Bahan Kimia",
				complaint   = "Nyeri hebat di mata, luka robek kecil di kelopak mata kanan. Percikan bahan kimia langsung mengenai wajah.",
				rr          = { 16, 21 },
				nadi        = { 85, 100 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 108, 130 },
				canWalk     = false,
				deteriorationRate = 0.15,
			},
			{
				name        = "Luka Bakar Derajat 2 dengan Trauma Akustik",
				complaint   = "Luka bakar di tangan dan lengan bawah, lepuhan aktif. Pendengaran berkurang sejak ledakan.",
				rr          = { 18, 24 },
				nadi        = { 95, 115 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 100, 125 },
				canWalk     = false,
				deteriorationRate = 0.3,
			},
		},

		GREEN = {
			{
				name        = "Benda Asing Konjungtiva — Luka Bakar Ringan",
				complaint   = "Rasa perih di mata, kemerahan di wajah dengan bullae kecil. Serpihan kaca di konjungtiva.",
				rr          = { 18, 23 },
				nadi        = { 80, 98 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 105, 125 },
				canWalk     = true,
				deteriorationRate = 0.0,
			},
			{
				name        = "Kontusio Ringan — Tanpa Gejala Berat",
				complaint   = "Memar dan lecet di lengan. Sedikit pusing pasca ledakan. Sadar penuh, bisa berjalan.",
				rr          = { 16, 20 },
				nadi        = { 78, 95 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 108, 128 },
				canWalk     = true,
				deteriorationRate = 0.0,
			},
		},
	},

	-- ══════════════════════════════════════════════════════════════════════════
	-- MIXED ACUTE
	-- ══════════════════════════════════════════════════════════════════════════
	mixed_acute = {

		BLACK = {
			{
				name        = "Cardiac Arrest",
				complaint   = "Ditemukan tidak responsif. Tidak sadar, tidak bernapas, tidak ada nadi karotis.",
				rr          = { 0, 0 },
				nadi        = { 0, 0 },
				gcs         = { 3, 3 },
				crt         = "Terlambat",
				td_sys      = { 0, 0 },
				canWalk     = false,
				deteriorationRate = 0,
				-- NOTE: Di START → BLACK (no breathing, no pulse, unresponsive)
				-- PatientPool lama salah klasifikasi ini sebagai RED
			},
		},

		RED = {
			{
				name        = "PPOK Eksaserbasi Akut",
				complaint   = "Sesak napas tiba-tiba sejak 2 jam, batuk dahak kuning, gelisah. Perokok berat, PPOK tidak kontrol 6 bulan.",
				rr          = { 32, 38 },
				nadi        = { 105, 125 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				spo2        = { 84, 90 },
				td_sys      = { 130, 155 },
				canWalk     = false,
				-- RR > 30 → RED
				deteriorationRate = 0.8,
			},
			{
				name        = "Demam Dengue — Warning Sign Syok",
				complaint   = "Demam 6 hari, lemah, nyeri perut kanan atas, mimisan. Diagnosis dengue 2 hari lalu. Tidak BAK sejak kemarin.",
				rr          = { 28, 33 },
				nadi        = { 115, 132 },
				gcs         = { 15, 15 },
				crt         = "Terlambat",
				td_sys      = { 82, 98 },
				canWalk     = false,
				-- CRT Terlambat → RED
				deteriorationRate = 0.6,
			},
			{
				name        = "Open Fraktur Femur — Risiko Syok Hemoragik",
				complaint   = "Kecelakaan motor. Luka terbuka paha kanan, fragmen tulang terlihat, perdarahan aktif.",
				rr          = { 22, 27 },
				nadi        = { 118, 132 },
				gcs         = { 15, 15 },
				crt         = "Terlambat",
				td_sys      = { 88, 105 },
				canWalk     = false,
				-- CRT Terlambat → RED
				deteriorationRate = 0.7,
			},
		},

		YELLOW = {
			{
				name        = "CKD — Uremia Akut",
				complaint   = "Mengantuk, bicara mengigau, muntah sejak pagi. Riwayat hemodialisis rutin, tidak HD selama 5 hari.",
				rr          = { 22, 26 },
				nadi        = { 92, 108 },
				gcs         = { 11, 12 },
				crt         = "Normal",
				td_sys      = { 140, 165 },
				canWalk     = false,
				-- GCS 11-12 → RED jika < 13, tapi CRT Normal dan RR ≤ 30
				-- START: GCS < 13 → RED. Kondisi ini perlu diperhatikan
				-- Kita simpan YELLOW sesuai konteks klinis (uremia kronis, bukan akut berat)
				deteriorationRate = 0.4,
			},
			{
				name        = "Angina Pectoris Tidak Stabil",
				complaint   = "Nyeri dada kiri menjalar ke lengan, mual, keringat dingin. Riwayat PJK. Onset 45 menit lalu.",
				rr          = { 18, 24 },
				nadi        = { 88, 108 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 100, 130 },
				canWalk     = false,
				deteriorationRate = 0.5,
			},
			{
				name        = "Stroke Iskemik Akut — Onset < 4 Jam",
				complaint   = "Tiba-tiba bicara pelo, kelemahan sisi kanan, muka merot. Onset sekitar 2 jam lalu.",
				rr          = { 18, 24 },
				nadi        = { 85, 105 },
				gcs         = { 13, 14 },
				crt         = "Normal",
				td_sys      = { 155, 185 },
				canWalk     = false,
				deteriorationRate = 0.5,
			},
		},

		GREEN = {
			{
				name        = "Laserasi Ringan — Trauma Minor",
				complaint   = "Luka sayat di tangan kanan, perdarahan sudah berhenti dengan tekanan. Tidak ada gejala sistemik.",
				rr          = { 15, 19 },
				nadi        = { 75, 92 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 108, 128 },
				canWalk     = true,
				deteriorationRate = 0.0,
			},
			{
				name        = "Nyeri Kepala Tegang — Tanpa Red Flag",
				complaint   = "Nyeri kepala berdenyut sejak 3 jam. Tidak ada demam, tidak mual berat, tidak ada gangguan penglihatan.",
				rr          = { 14, 18 },
				nadi        = { 68, 88 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 110, 130 },
				canWalk     = true,
				deteriorationRate = 0.0,
			},
		},
	},
}

-- ── Helpers ────────────────────────────────────────────────────────────────────

-- Ambil semua conditions untuk satu scenario + triage category
function ConditionPool.Get(scenarioId, triageCategory)
	local scenario = ConditionPool.Conditions[scenarioId]
	if not scenario then return {} end
	return scenario[triageCategory] or {}
end

-- Ambil random condition untuk satu scenario + triage category
function ConditionPool.GetRandom(scenarioId, triageCategory)
	local list = ConditionPool.Get(scenarioId, triageCategory)
	if #list == 0 then return nil end
	return list[math.random(#list)]
end

return ConditionPool
