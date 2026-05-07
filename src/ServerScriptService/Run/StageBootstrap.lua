---
---   1) RunContext.initFromTeleportData(players)
---   3) MapService.GenerateMap(currentFloor)
---   5) WaveService.startSession(currentFloor)
---

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StageData = require(Shared:WaitForChild("StageData"))

local RunContext = require(script.Parent:WaitForChild("RunContext"))
local Teleport = require(script.Parent:WaitForChild("Teleport"))
local StageFlow = require(script.Parent:WaitForChild("StageFlow"))

local StageBootstrap = {}

local function disableWorkspaceSpawnLocations()
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("SpawnLocation") then
			inst.Enabled = false
		end
	end
end

--- deps = {
---   players          : Players service,
---   stageFlowRequest : Remotes.StageFlowRequest RemoteEvent,
---   mapService       : require("Map/MapService"),
---   waveService      : require("WaveService"),
--- }
function StageBootstrap.init(deps)
	assert(deps, "[StageBootstrap] deps required")
	assert(deps.players, "[StageBootstrap] deps.players required")
	assert(deps.stageFlowRequest, "[StageBootstrap] deps.stageFlowRequest required")
	assert(deps.mapService, "[StageBootstrap] deps.mapService required")
	assert(deps.waveService, "[StageBootstrap] deps.waveService required")
	assert(deps.gameConfig, "[StageBootstrap] deps.gameConfig required")

	RunContext.initFromTeleportData(deps.players)

	StageFlow.init({
		players = deps.players,
		stageFlowRequest = deps.stageFlowRequest,
		runContext = RunContext,
		teleport = Teleport,
	})

	deps.waveService.bindStageFlow(StageFlow)

	local floor = RunContext.getCurrentFloor()
	deps.mapService.GenerateMap(floor)
	disableWorkspaceSpawnLocations()

	local gc = deps.gameConfig
	local spawnCf = StageData.getPlayerSpawnCFrame(gc, floor)
	for _, p in ipairs(RunContext.getMembers()) do
		p:LoadCharacter()
		local character = p.Character or p.CharacterAdded:Wait()
		local hrp = character:WaitForChild("HumanoidRootPart", 10)
		if hrp and hrp:IsA("BasePart") then
			RunService.Heartbeat:Wait()
			hrp.AssemblyLinearVelocity = Vector3.zero
			local av = hrp.AssemblyAngularVelocity
			if typeof(av) == "Vector3" then
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
			hrp.CFrame = spawnCf
			task.defer(function()
				if hrp.Parent and hrp:IsA("BasePart") then
					hrp.AssemblyLinearVelocity = Vector3.zero
					local av2 = hrp.AssemblyAngularVelocity
					if typeof(av2) == "Vector3" then
						hrp.AssemblyAngularVelocity = Vector3.zero
					end
					hrp.CFrame = spawnCf
				end
			end)
		end
	end

	deps.waveService.startSession(floor)
end

return StageBootstrap