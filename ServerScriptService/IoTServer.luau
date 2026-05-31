-- IoTServer.lua (ServerScriptService)
local RS = game:GetService("ReplicatedStorage")

local event = Instance.new("RemoteEvent")
event.Name = "IoTEvent"
event.Parent = RS

local npcs = {}

event.OnServerEvent:Connect(function(player, action)
	print("[IoT] Received:", action)

	if action == "ADD_PATIENT" then
		local part = Instance.new("Part")
		part.Size = Vector3.new(2, 4, 2)
		part.Position = Vector3.new(math.random(-20, 20), 5, math.random(-20, 20))
		part.BrickColor = BrickColor.new("Bright blue")
		part.Anchored = false
		part.Parent = workspace
		table.insert(npcs, part)
		print("[IoT] NPC spawned, total:", #npcs)

	elseif action == "REMOVE_PATIENT" then
		if #npcs == 0 then
			print("[IoT] No NPCs to remove")
			return
		end
		local npc = table.remove(npcs)
		npc:Destroy()
		print("[IoT] NPC removed, total:", #npcs)

	elseif action == "ADD_TIME" then
		print("[IoT] +10 seconds")
		-- hook into your timer here later

	elseif action == "REMOVE_TIME" then
		print("[IoT] -10 seconds")
		-- hook into your timer here later
	end
end)