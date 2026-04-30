local HUDClient = require(script.Parent:WaitForChild("HUDClient"))
local VFXClient = require(script.Parent:WaitForChild("VFXClient"))
local LevelUpClient = require(script.Parent:WaitForChild("LevelUpClient"))
local ResultClient = require(script.Parent:WaitForChild("ResultClient"))

HUDClient.init()
VFXClient.init()
LevelUpClient.init()
ResultClient.init()

print("[MainClient] Client started")
