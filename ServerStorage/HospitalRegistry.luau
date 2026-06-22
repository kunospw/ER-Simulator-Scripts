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
			{ position = Vector3.new(569.949, 5.157, 11.975),  yRot = 180, pose = "Lying" },
			{ position = Vector3.new(569.946, 5.157, -2.247), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(569.946, 5.157, -15.764), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(569.946, 5.157, -30.432), yRot = 180, pose = "Lying" },
		},
	},
	{
		id = 2,
		occupied = false,
		occupiedBy = nil,
		entranceCFrame = CFrame.new(-955.971, 11.036, 291.032),
		spawnPosition = Vector3.new(-968, 2.71, 318),
		beds = {
			{ position = Vector3.new(-925.126, 5, 278.161), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-925.126, 5, 263.949), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-925.126, 5, 250.449), yRot = 180, pose = "Lying" },
			{ position = Vector3.new(-925.126, 5, 235.7111), yRot = 180, pose = "Lying" },
		},
	},
	{
		id = 3,
		occupied = false,
		occupiedBy = nil,
		entranceCFrame = CFrame.new(108.054, 9.555, -295.773),
		spawnPosition = Vector3.new(96, 1.229, -269),
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