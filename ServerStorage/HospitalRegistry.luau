-- HospitalRegistry (ModuleScript) — ServerStorage
local HospitalRegistry = {}

HospitalRegistry.Hospitals = {
	{
		id = 1,
		occupied = false,
		occupiedBy = nil,
		entranceCFrame = CFrame.new(541.287, 11.036, 31.56),
		spawnPosition = Vector3.new(528, 2.71, 54),
		beds = {
			{ position = Vector3.new(573.064, 5.157, 9.933),  yRot = 180, pose = "Lying" },
			{ position = Vector3.new(573.064, 5.157, -4.205), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(573.064, 5.157, -17.798), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(573.064, 5.157, -32.396), yRot = 180, pose = "Lying" },
		},
	},
	{
		id = 2,
		occupied = false,
		occupiedBy = nil,
		entranceCFrame = CFrame.new(-955.971, 11.036, 291.032),
		spawnPosition = Vector3.new(-968, 2.71, 318),
		beds = {
			{ position = Vector3.new(-925.05, 5, 278.085), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-925.05, 5, 264.006), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-925.05, 5, 250.451), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-925.05, 5, 235.837), yRot = 180, pose = "Lying" },
		},
	},
	{
		id = 3,
		occupied = false,
		occupiedBy = nil,
		entranceCFrame = CFrame.new(108.054, 9.555, -295.773),
		spawnPosition = Vector3.new(96, 1.229, -269),
		beds = {
			{ position = Vector3.new(138.192, 5, -303.883), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(138.192, 5, -318.114), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(138.192, 5, -331.915), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(138.192, 5, -346.322), yRot = 180, pose = "Lying" },
		},
	},
	{
		id = 4,
		occupied = false,
		occupiedBy = nil,
		entranceCFrame = CFrame.new(-580.189, 7.069, -265.737),
		spawnPosition = Vector3.new(-679.34, 1.229, -264.85),
		beds = {
			{ position = Vector3.new(-635.43, 3.635, -308.644), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-635.43, 3.635, -322.742), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-635.43, 3.635, -336.422), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-635.43, 3.635, -351.185), yRot = 180, pose = "Lying" },
		},
	},
}

-- [NEW]: Assign multiple players for a Tournament
function HospitalRegistry.AssignMulti(players)
	for _, hospital in ipairs(HospitalRegistry.Hospitals) do
		if not hospital.occupied then
			hospital.occupied = true
			hospital.occupants = {}
			for _, p in ipairs(players) do
				hospital.occupants[p] = true
			end
			return hospital
		end
	end
	return nil
end

function HospitalRegistry.Assign(player)
	return HospitalRegistry.AssignMulti({player})
end

-- [FIX]: Only free the hospital if NO ONE is left inside
function HospitalRegistry.Release(player)
	for _, hospital in ipairs(HospitalRegistry.Hospitals) do
		if hospital.occupied and hospital.occupants and hospital.occupants[player] then
			hospital.occupants[player] = nil

			if next(hospital.occupants) == nil then
				hospital.occupied = false
				print("[HospitalRegistry] Hospital " .. hospital.id .. " is fully empty and released.")
			end
			return
		end
	end
end

function HospitalRegistry.GetByPlayer(player)
	for _, hospital in ipairs(HospitalRegistry.Hospitals) do
		if hospital.occupied and hospital.occupants and hospital.occupants[player] then
			return hospital
		end
	end
	return nil
end

return HospitalRegistry