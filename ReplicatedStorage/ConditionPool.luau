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
				gcs         = { 13, 14 },
				crt         = "Normal",
				td_sys      = { 140, 165 },
				canWalk     = false,
				-- GCS 13-14: ensefalopati uremikum ringan, masih ikut perintah → YELLOW konsisten START.
				-- Bila deteriorate (rate 0.4) → GCS turun <13 → classifier re-label RED (mekanik intended).
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

	-- ══════════════════════════════════════════════════════════════════════════
	-- TRAFFIC ACCIDENT
	-- ══════════════════════════════════════════════════════════════════════════
	traffic_accident = {

		BLACK = {
			{
				name        = "Cedera Multipel — Henti Napas Pasca Trauma",
				complaint   = "Korban terlempar dari kendaraan, ditemukan tidak responsif. Tidak bernapas, tidak ada nadi.",
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
				name        = "Cedera Kepala Sedang–Berat",
				complaint   = "Benturan kepala, muntah, bicara kacau, makin mengantuk. Tidak dapat mengikuti perintah dengan benar.",
				rr          = { 24, 28 },
				nadi        = { 100, 115 },
				gcs         = { 9, 12 },
				crt         = "Normal",
				td_sys      = { 95, 110 },
				canWalk     = false,
				-- GCS < 13 → RED
				deteriorationRate = 0.6,
			},
			{
				name        = "Trauma Toraks — Suspek Tension Pneumothorax",
				complaint   = "Sesak berat setelah benturan dada ke setir. Napas cepat dan dangkal, bibir kebiruan.",
				rr          = { 32, 38 },
				nadi        = { 118, 130 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				spo2        = { 86, 92 },
				td_sys      = { 88, 100 },
				canWalk     = false,
				-- RR > 30 → RED
				deteriorationRate = 0.9,
			},
			{
				name        = "Fraktur Femur Terbuka — Syok Hemoragik",
				complaint   = "Luka terbuka paha, perdarahan aktif, fragmen tulang terlihat. Tampak pucat dan lemah.",
				rr          = { 24, 29 },
				nadi        = { 125, 138 },
				gcs         = { 13, 14 },
				crt         = "Terlambat",
				td_sys      = { 78, 92 },
				canWalk     = false,
				-- CRT Terlambat → RED
				deteriorationRate = 0.7,
			},
		},

		YELLOW = {
			{
				name        = "Fraktur Tertutup Ekstremitas",
				complaint   = "Nyeri hebat tungkai, tidak bisa berjalan. Tampak deformitas. Sadar penuh.",
				rr          = { 18, 22 },
				nadi        = { 90, 100 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 110, 125 },
				canWalk     = false,
				deteriorationRate = 0.1,
			},
			{
				name        = "Dislokasi Sendi Besar",
				complaint   = "Nyeri bahu, lengan sulit digerakkan, tampak benjolan di sendi. Sadar dan stabil.",
				rr          = { 18, 21 },
				nadi        = { 88, 98 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 112, 126 },
				canWalk     = false,
				deteriorationRate = 0.1,
			},
			{
				name        = "Vulnus Laceratum Luas — Perdarahan Terkontrol",
				complaint   = "Luka robek cukup luas di tungkai, perdarahan sudah ditekan dan terkontrol. Sadar, nyeri sedang.",
				rr          = { 18, 22 },
				nadi        = { 90, 104 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 108, 122 },
				canWalk     = false,
				deteriorationRate = 0.2,
			},
		},

		GREEN = {
			{
				name        = "Vulnus Excoriatum Multipel",
				complaint   = "Luka lecet di lengan dan lutut. Bisa berjalan keluar sendiri dari kendaraan. Cemas tapi kooperatif.",
				rr          = { 16, 20 },
				nadi        = { 82, 95 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 115, 128 },
				canWalk     = true,
				deteriorationRate = 0.0,
			},
			{
				name        = "Cedera Jaringan Lunak Minor",
				complaint   = "Memar dan nyeri ringan di bahu dan pinggang. Bisa berjalan, sadar penuh, tanda vital stabil.",
				rr          = { 15, 19 },
				nadi        = { 78, 92 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 112, 126 },
				canWalk     = true,
				deteriorationRate = 0.0,
			},
		},
	},

	-- ══════════════════════════════════════════════════════════════════════════
	-- EARTHQUAKE COLLAPSE
	-- ══════════════════════════════════════════════════════════════════════════
	earthquake_collapse = {

		BLACK = {
			{
				name        = "Asfiksia Traumatik — Tertimbun Lama",
				complaint   = "Korban tertimbun reruntuhan dalam waktu lama. Saat dievakuasi sudah tidak bernapas dan tidak ada nadi.",
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
				name        = "Crush Injury — Risiko Crush Syndrome",
				complaint   = "Tungkai lama tertimpa beton sebelum dievakuasi. Tampak bengkak, lemah, urin kemerahan.",
				rr          = { 22, 26 },
				nadi        = { 115, 128 },
				gcs         = { 13, 14 },
				crt         = "Terlambat",
				td_sys      = { 85, 98 },
				canWalk     = false,
				-- CRT Terlambat → RED
				deteriorationRate = 0.6,
			},
			{
				name        = "Cedera Inhalasi Debu — Distres Napas Akut",
				complaint   = "Sesak berat setelah terpapar debu reruntuhan dalam ruang tertutup. Napas cepat, batuk hebat.",
				rr          = { 32, 37 },
				nadi        = { 112, 125 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				spo2        = { 86, 92 },
				td_sys      = { 102, 118 },
				canWalk     = false,
				-- RR > 30 → RED
				deteriorationRate = 0.8,
			},
			{
				name        = "Cedera Kepala Berat",
				complaint   = "Tertimpa material di kepala. Tidak sadar penuh, hanya mengerang, tidak mengikuti perintah.",
				rr          = { 20, 25 },
				nadi        = { 100, 114 },
				gcs         = { 8, 11 },
				crt         = "Normal",
				td_sys      = { 98, 112 },
				canWalk     = false,
				-- GCS < 13 → RED
				deteriorationRate = 0.7,
			},
		},

		YELLOW = {
			{
				name        = "Fraktur Tertutup dengan Laserasi Kepala",
				complaint   = "Lengan nyeri dan bengkok, luka robek di kepala. Sadar penuh dan kooperatif.",
				rr          = { 19, 23 },
				nadi        = { 90, 102 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 112, 126 },
				canWalk     = false,
				deteriorationRate = 0.15,
			},
			{
				name        = "Vulnus Laceratum — Perdarahan Terkontrol",
				complaint   = "Luka robek di paha, perdarahan sudah ditekan dan terkontrol. Sadar, stabil, nyeri sedang.",
				rr          = { 18, 22 },
				nadi        = { 92, 104 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 110, 124 },
				canWalk     = false,
				deteriorationRate = 0.2,
			},
			{
				name        = "Cedera Kepala Ringan — Sadar Penuh",
				complaint   = "Terbentur material ringan di kepala, sempat pusing. Sadar penuh, ingat kejadian, tidak muntah.",
				rr          = { 18, 22 },
				nadi        = { 88, 100 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 115, 128 },
				canWalk     = false,
				deteriorationRate = 0.2,
			},
		},

		GREEN = {
			{
				name        = "Vulnus Excoriatum — Paparan Debu Ringan",
				complaint   = "Keluar sendiri dari reruntuhan. Luka lecet, berdebu, sedikit batuk. Bisa berjalan dan menjawab dengan jelas.",
				rr          = { 17, 21 },
				nadi        = { 84, 96 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 114, 128 },
				canWalk     = true,
				deteriorationRate = 0.0,
			},
			{
				name        = "Lecet dan Memar Minor",
				complaint   = "Lecet dan memar ringan akibat reruntuhan. Bisa berjalan keluar sendiri, sadar penuh, tanda vital stabil.",
				rr          = { 15, 19 },
				nadi        = { 78, 92 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				td_sys      = { 112, 126 },
				canWalk     = true,
				deteriorationRate = 0.0,
			},
		},
	},

	-- ══════════════════════════════════════════════════════════════════════════
	-- EARTHQUAKE JABABEKA 7,8 SR
	-- Sumber: Formulir Skenario ER Simulator — dr. Radite NS, Sp.OK, M.K.K.
	-- ══════════════════════════════════════════════════════════════════════════
	earthquake_jababeka = {

		BLACK = {
			{
				name        = "Luka Bakar Elektrik Grade 2 Luas 35% — Aritmia Fatal",
				complaint   = "Tersengat listrik dari panel mesin produksi yang rusak setelah gempa. Ditemukan tidak bernapas dan tetap tidak bernapas setelah jalan napas dibuka.",
				rr          = { 0, 0 },
				nadi        = { 0, 0 },
				gcs         = { 3, 3 },
				crt         = "Terlambat",
				spo2        = { 0, 0 },
				td_sys      = { 0, 0 },
				canWalk     = false,
				deteriorationRate = 0,
			},
		},

		RED = {
			{
				name        = "Tension Pneumothorax",
				complaint   = "Tertimpa reruntuhan ringan dan mengalami benturan keras pada dada kanan. Tampak sesak berat, napas cepat, gelisah, bibir kebiruan.",
				rr          = { 34, 42 },
				nadi        = { 124, 142 },
				gcs         = { 14, 15 },
				crt         = "Terlambat",
				spo2        = { 82, 89 },
				td_sys      = { 82, 96 },
				canWalk     = false,
				-- RR > 30 dan CRT Terlambat → RED
				deteriorationRate = 0.8,
			},
			{
				name        = "Suspek Fraktur Basis Cranii",
				complaint   = "Ditemukan setelah tertimpa material bangunan pada area kepala. Tampak bingung, terdapat perdarahan dari telinga, dan mengeluh nyeri kepala hebat.",
				rr          = { 18, 24 },
				nadi        = { 96, 112 },
				gcs         = { 11, 12 },
				crt         = "Normal",
				spo2        = { 94, 98 },
				td_sys      = { 112, 132 },
				canWalk     = false,
				-- GCS < 13 → RED
				deteriorationRate = 0.5,
			},
			{
				name        = "Epidural Hemorrhage",
				complaint   = "Sempat sadar setelah kepala terbentur mesin produksi, lalu menjadi mengantuk dan sulit diajak bicara. Tampak luka memar pada regio temporal.",
				rr          = { 16, 22 },
				nadi        = { 52, 64 },
				gcs         = { 10, 12 },
				crt         = "Normal",
				spo2        = { 94, 98 },
				td_sys      = { 150, 176 },
				canWalk     = false,
				-- GCS < 13 → RED
				deteriorationRate = 0.8,
			},
			{
				name        = "Open Fracture Cruris Dextra",
				complaint   = "Tertimpa material besi pada tungkai kanan. Tampak tulang keluar, perdarahan aktif, pasien pucat dan mengeluh nyeri hebat.",
				rr          = { 24, 30 },
				nadi        = { 122, 138 },
				gcs         = { 14, 15 },
				crt         = "Terlambat",
				spo2        = { 94, 98 },
				td_sys      = { 84, 100 },
				canWalk     = false,
				-- CRT Terlambat → RED
				deteriorationRate = 0.8,
			},
			{
				name        = "Closed Fracture Collum Femur Dextra dengan Subdural Hemorrhage",
				complaint   = "Jatuh dari tangga saat evakuasi dan tidak dapat menggerakkan tungkai kanan karena nyeri panggul hebat. Tampak mengantuk, menjawab lambat, dan memiliki riwayat benturan kepala.",
				rr          = { 20, 28 },
				nadi        = { 104, 122 },
				gcs         = { 8, 11 },
				crt         = "Normal",
				spo2        = { 93, 97 },
				td_sys      = { 138, 160 },
				canWalk     = false,
				-- GCS < 13 → RED
				deteriorationRate = 0.8,
			},
			{
				name        = "Fraktur Phalanx II–III Proximal dengan Flail Chest",
				complaint   = "Tertimpa rak logam dan mengalami nyeri dada hebat serta deformitas pada jari tangan. Dinding dada tampak bergerak tidak simetris, pasien sesak, dan sulit berbicara panjang.",
				rr          = { 32, 40 },
				nadi        = { 116, 134 },
				gcs         = { 14, 15 },
				crt         = "Normal",
				spo2        = { 86, 92 },
				td_sys      = { 96, 116 },
				canWalk     = false,
				-- RR > 30 → RED
				deteriorationRate = 0.8,
			},
		},

		YELLOW = {
			{
				name        = "Fraktur Kompresi Os Vertebra Torakal",
				complaint   = "Tertimpa balok ringan di punggung dan mengeluh nyeri hebat pada punggung bagian tengah. Sadar penuh, tetapi tidak mampu berdiri karena nyeri.",
				rr          = { 18, 24 },
				nadi        = { 92, 108 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				spo2        = { 96, 99 },
				td_sys      = { 118, 138 },
				canWalk     = false,
				deteriorationRate = 0.2,
			},
			{
				name        = "Fraktur Vertebra dengan Hipertensi Emergensi",
				complaint   = "Tertimpa runtuhan plafon dan mengeluh nyeri punggung berat serta sakit kepala hebat. Sadar penuh, tidak sesak, tetapi tidak bisa berdiri karena nyeri tulang belakang.",
				rr          = { 18, 24 },
				nadi        = { 96, 112 },
				gcs         = { 14, 15 },
				crt         = "Normal",
				spo2        = { 95, 98 },
				td_sys      = { 200, 226 },
				canWalk     = false,
				deteriorationRate = 0.5,
			},
		},

		GREEN = {
			{
				name        = "Vulnus Laceratum Regio Frontal",
				complaint   = "Berjalan sendiri ke area triase dengan luka robek pada dahi akibat pecahan kaca. Sadar penuh, perdarahan ringan, dan tidak tampak sesak.",
				rr          = { 16, 22 },
				nadi        = { 78, 96 },
				gcs         = { 15, 15 },
				crt         = "Normal",
				spo2        = { 97, 99 },
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
