-- DataStoreManager (ModuleScript) — ServerStorage
local DataStoreService = game:GetService("DataStoreService")

local DataStoreManager = {}

local playerStore  = DataStoreService:GetDataStore("Players_v1")
local sessionStore = DataStoreService:GetDataStore("Sessions_v1")

-- Called on PlayerAdded — writes player profile if first time
function DataStoreManager.InitPlayer(player)
	local key = "player_" .. player.UserId
	local success, err = pcall(function()
		local existing = playerStore:GetAsync(key)
		if not existing then
			playerStore:SetAsync(key, {
				userId         = player.UserId,
				username       = player.Name,
				education_level = "undergraduate",
				created_at     = os.time(),
			})
		end
	end)
	if not success then
		warn("[DataStoreManager] InitPlayer failed:", err)
	end
end

-- Called at session end — saves full session result
function DataStoreManager.SaveSession(player, sessionData)
	local key = "session_" .. player.UserId .. "_" .. os.time()
	local success, err = pcall(function()
		sessionStore:SetAsync(key, {
			player_id      = player.UserId,
			scenario_id    = sessionData.scenarioId,
			mode           = sessionData.mode,
			final_score    = sessionData.totalScore,
			accuracy       = sessionData.accuracy,
			correct_count  = sessionData.correctCount,
			wrong_count    = sessionData.wrongCount,
			total_patients = sessionData.totalPatients,
			decisions      = sessionData.allSubmissions,
			saved_at       = os.time(),
		})
	end)
	if not success then
		warn("[DataStoreManager] SaveSession failed:", err)
	end
end

return DataStoreManager