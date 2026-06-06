-- IoTDebugPanel (LocalScript) — StarterGui (No longer used(?))
return
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Tunggu remote yang udah ada
local iotTimerRemote = RS:WaitForChild("IoTTimerAdjust")
local iotNotifRemote = RS:WaitForChild("IoTNotification")

-- Buat ScreenGui
local sg = Instance.new("ScreenGui")
sg.Name = "IoTDebugPanel"
sg.ResetOnSpawn = false
sg.Parent = player.PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 180, 0, 175)
frame.Position = UDim2.new(0, 10, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.Text = "🛠 IoT Debug"
title.Parent = frame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

local commands = {
	{ label = "➕ Add Patient",    action = function()
		-- Simulate server-side ADD_PATIENT lewat BindableEvent
		local e = game:GetService("ServerStorage"):FindFirstChild("IoTAddPatient")
		-- Ini client, jadi kita fire server via RemoteEvent khusus debug
		RS:WaitForChild("IoTDebugFire"):FireServer("ADD_PATIENT")
	end},
	{ label = "➖ Remove Patient", action = function()
		RS:WaitForChild("IoTDebugFire"):FireServer("REMOVE_PATIENT")
	end},
	{ label = "⏱ +30s",           action = function()
		RS:WaitForChild("IoTDebugFire"):FireServer("ADD_TIME")
	end},
	{ label = "⏱ -30s",           action = function()
		RS:WaitForChild("IoTDebugFire"):FireServer("REMOVE_TIME")
	end},
}

for i, cmd in ipairs(commands) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -16, 0, 28)
	btn.Position = UDim2.new(0, 8, 0, 24 + (i-1) * 34)
	btn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
	btn.TextColor3 = Color3.new(1,1,1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.Text = cmd.label
	btn.BorderSizePixel = 0
	btn.Parent = frame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	btn.MouseButton1Click:Connect(cmd.action)
end