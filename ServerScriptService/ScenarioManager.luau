-- ServerScriptService > ScenarioManager (Script)

local RS = game:GetService("ReplicatedStorage")

-- StartCutscene should already exist in ReplicatedStorage (create it manually in Studio)
local startRemote = RS:WaitForChild("StartCutscene")

-- TriggerCinematic: create only if it doesn't exist yet
local triggerRemote = RS:FindFirstChild("TriggerCinematic")
if not triggerRemote then
	triggerRemote = Instance.new("RemoteEvent")
	triggerRemote.Name = "TriggerCinematic"
	triggerRemote.Parent = RS
end

-- When a player picks a scenario from the menu, relay StartCutscene to that client
triggerRemote.OnServerEvent:Connect(function(player, scenarioId)
	print("[ScenarioManager] Starting scenario:", scenarioId, "for", player.Name)
	startRemote:FireClient(player, scenarioId)
end)

-- !! REMOVE the PlayerAdded test block entirely — do not leave it commented in !!