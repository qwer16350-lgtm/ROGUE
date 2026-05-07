---
---

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RunConstants = require(Shared:WaitForChild("Run"):WaitForChild("RunConstants"))

local PartyService = {}

function PartyService.getMembersFor(player)
	return { player }, RunConstants.Mode.Solo
end

return PartyService