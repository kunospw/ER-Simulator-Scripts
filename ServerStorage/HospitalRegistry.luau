-- HospitalRegistry (ModuleScript) — ServerStorage
local HospitalRegistry = {}

HospitalRegistry.Hospitals = {
	{
		id = 1,
		occupied = false,
		occupiedBy = nil,
		entranceCFrame = CFrame.new(611.873, 8.55, 111.662),
		spawnPosition = Vector3.new(514.13, 2.71, 108.79),
		beds = {
			{ position = Vector3.new(557.094, 5.1, 68.78),  yRot = 180, pose = "Lying" },
			{ position = Vector3.new(557.094, 5.1, 54.586), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(557.094, 5.1, 40.973), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(557.094, 5.1, 26.348), yRot = 180, pose = "Lying" },
		},
	},
	{
		id = 2,
		occupied = false,
		occupiedBy = nil,
		entranceCFrame = CFrame.new(-870.214, 8.55, 321.068),
		spawnPosition = Vector3.new(-967.976, 2.71, 318.16),
		beds = {
			{ position = Vector3.new(-923.032, 5.1, 279.644), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-923.032, 5.1, 265.412), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-923.032, 5.1, 251.842), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-923.032, 5.1, 237.174), yRot = 180, pose = "Lying" },
		},
	},
	{
		id = 3,
		occupied = false,
		occupiedBy = nil,
		entranceCFrame = CFrame.new(193.811, 7.069, -265.737),
		spawnPosition = Vector3.new(96.3, 1.229, -269.43),
		beds = {
			{ position = Vector3.new(139.769, 3.5, -308.644), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(139.769, 3.5, -322.813), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(139.769, 3.5, -336.426), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(139.769, 3.5, -351.093), yRot = 180, pose = "Lying" },
		},
	},
	{
		id = 4,
		occupied = false,
		occupiedBy = nil,
		entranceCFrame = CFrame.new(-580.189, 7.069, -265.737),
		spawnPosition = Vector3.new(-679.34, 1.229, -264.85),
		beds = {
			{ position = Vector3.new(-634.289, 3.5, -308.662), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-634.289, 3.5, -322.813), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-634.289, 3.5, -336.383), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-634.289, 3.5, -351.051), yRot = 180, pose = "Lying" },
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