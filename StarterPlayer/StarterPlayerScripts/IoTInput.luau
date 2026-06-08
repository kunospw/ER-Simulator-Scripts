-- IoTInput.lua (StarterPlayerScripts) (Disabled for now)
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Insert then
		RS.IoTEvent:FireServer("ADD_PATIENT")
		print("[IoT] F9 - ADD PATIENT")
	elseif input.KeyCode == Enum.KeyCode.Home then
		RS.IoTEvent:FireServer("REMOVE_PATIENT")
		print("[IoT] F10 - REMOVE PATIENT")
	elseif input.KeyCode == Enum.KeyCode.End then
		RS.IoTEvent:FireServer("ADD_TIME")
		print("[IoT] F11 - ADD TIME")
	elseif input.KeyCode == Enum.KeyCode.PageUp then
		RS.IoTEvent:FireServer("REMOVE_TIME")
		print("[IoT] F12 - REMOVE TIME")
	end
end)
