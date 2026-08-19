-- DataStoreManager (ModuleScript) — ServerStorage
local DataStoreService = game:GetService("DataStoreService")
local HttpService      = game:GetService("HttpService")

local DataStoreManager = {}

local playerStore  = DataStoreService:GetDataStore("Players_v1")
local sessionStore = DataStoreService:GetDataStore("Sessions_v1")

-- Jumlah sesi terakhir yang disimpan di index history per pemain.
local MAX_HISTORY = 50

-- Called on PlayerAdded — writes player profile if first time
function DataStoreManager.InitPlayer(player)
	local key = "player_" .. player.UserId
	local success, err = pcall(function()
		local existing = playerStore:GetAsync(key)
		if not existing then
			playerStore:SetAsync(key, {
				userId          = player.UserId,
				username        = player.Name,
				education_level = "undergraduate",
				created_at      = os.time(),
			})
		end
	end)
	if not success then
		warn("[DataStoreManager] InitPlayer failed:", err)
	end
end

-- [NEW]: Index per pemain. Sessions_v1 adalah key-value store, jadi record
-- session_<userId>_<timestamp> tidak bisa di-enumerate. Key history_<userId>
-- menyimpan array ringkasan supaya riwayat bisa dibaca kembali di main menu.
-- Detail lengkap (termasuk decisions) tetap ada di record sesi aslinya.
function DataStoreManager.SaveSession(player, sessionData)
	local timestamp  = os.time()
	-- Suffix acak: dua sesi bisa selesai pada detik yang sama dan saling menimpa.
	local suffix     = HttpService:GenerateGUID(false):sub(1, 6)
	local sessionKey = "session_" .. player.UserId .. "_" .. timestamp .. "_" .. suffix
	local historyKey = "history_" .. player.UserId

	local success, err = pcall(function()
		sessionStore:SetAsync(sessionKey, {
			player_id      = player.UserId,
			scenario_id    = sessionData.scenarioId,
			game_mode      = sessionData.gameMode or "Scenario",
			mode           = sessionData.mode,
			final_score    = sessionData.totalScore,
			accuracy       = sessionData.accuracy,
			correct_count  = sessionData.correctCount,
			wrong_count    = sessionData.wrongCount,
			total_patients = sessionData.totalPatients,
			best_streak    = sessionData.bestStreak,
			decisions      = sessionData.allSubmissions,
			saved_at       = timestamp,
		})
	end)
	if not success then
		warn("[DataStoreManager] SaveSession failed:", err)
		return
	end

	-- UpdateAsync (bukan SetAsync) supaya penulisan bersamaan tidak saling hilang.
	local okIndex, errIndex = pcall(function()
		sessionStore:UpdateAsync(historyKey, function(old)
			local list = old or {}
			table.insert(list, 1, {
				sessionKey    = sessionKey,
				scenarioId    = sessionData.scenarioId,
				gameMode      = sessionData.gameMode or "Scenario",
				mode          = sessionData.mode,
				score         = sessionData.totalScore,
				accuracy      = sessionData.accuracy,
				correctCount  = sessionData.correctCount,
				wrongCount    = sessionData.wrongCount,
				totalPatients = sessionData.totalPatients,
				bestStreak    = sessionData.bestStreak,
				playedAt      = timestamp,
			})
			while #list > MAX_HISTORY do
				table.remove(list)
			end
			return list
		end)
	end)
	if not okIndex then
		warn("[DataStoreManager] History index update failed:", errIndex)
	else
		print("[DataStoreManager] Session saved:", sessionKey, "| mode:", sessionData.gameMode)
	end
end

-- [NEW]: Dipakai handler RequestHistory untuk mengisi panel History di main menu.
-- Mengembalikan array ringkasan, terbaru lebih dulu.
function DataStoreManager.GetHistory(player)
	local historyKey = "history_" .. player.UserId
	local success, result = pcall(function()
		return sessionStore:GetAsync(historyKey)
	end)
	if not success then
		warn("[DataStoreManager] GetHistory failed:", result)
		return {}
	end
	return result or {}
end

-- [NEW]: Ambil satu record sesi lengkap (termasuk daftar keputusan triase).
-- Belum dipakai UI, disiapkan untuk tampilan detail per sesi.
function DataStoreManager.GetSession(sessionKey)
	local success, result = pcall(function()
		return sessionStore:GetAsync(sessionKey)
	end)
	if not success then
		warn("[DataStoreManager] GetSession failed:", result)
		return nil
	end
	return result
end

return DataStoreManager