local Players = game:GetService("Players")

-- Shirt/Pants asset ID labcoat kamu
-- Upload dulu di Roblox, dapet ID-nya
local LABCOAT_SHIRT_ID = 71367274767842  -- ganti dengan ID shirt labcoat

local function applyLabcoat(player)
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	local desc = humanoid:GetAppliedDescription()
	desc.Shirt = LABCOAT_SHIRT_ID
	humanoid:ApplyDescription(desc)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		applyLabcoat(player)
	end)
	if player.Character then
		applyLabcoat(player)
	end
end)