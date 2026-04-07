--!strict

-------------------------< // >-------------------------
--< CONFIG
-------------------------< // >-------------------------

local AURA_TO_EQUIP = script:GetAttribute("EquipAura")
local DELAY = 1

-------------------------< // >-------------------------
--< MAIN CODE - CAN IGNORE
-------------------------< // >-------------------------

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local t_Aura = require("@game/ReplicatedStorage/Types/Aura")

export type t_AuraRegistry = {{
	["Animations"]: Configuration,
	["Chance"]: number,
	["Model"]: Model,
	["Name"]: string,
	["Scripts"]: Configuration
}}

local Serializer = require("@game/ServerScriptService/Modules/Serializer")
Serializer.Init { 
	Converters = {
		Serializer.SimpleConverterFromValueBase("IntValue"),
		Serializer.SimpleConverterFromValueBase("StringValue"),
		Serializer.SimpleConverterFromClass("Model"),
		Serializer.SimpleConverterFromClass("Configuration")
	} 
}

local auraSerializerParams: Serializer.t_Params<t_Aura.Prefab> = { 
	Keys = { "Name", "Chance", "Model", "Animations", "Scripts" },
	Converters = { "StringValue", "IntValue", "Model", "Configuration", "Configuration" }
}

local auraRegistry: t_AuraRegistry = Serializer.Batch<<t_Aura.Prefab>>(auraSerializerParams, ServerStorage:FindFirstChild("Auras"))
local auraHandler = require("@game/ReplicatedStorage/Modules/AuraHandler")

local foundAura: t_Aura.Prefab? = nil
for _, aura in auraRegistry do
	if aura.Name == AURA_TO_EQUIP then
		foundAura = aura
	end
end
if not foundAura then warn(`[{script.Name}] Aura: '{AURA_TO_EQUIP}' doesnt exist in Registry!`) return nil end

task.wait(DELAY)
for _, plr in Players:GetPlayers() do
	local ah = auraHandler.new(plr)

	task.defer(function()
		ah:SwapAura(foundAura :: t_Aura.Prefab)
	end)
end