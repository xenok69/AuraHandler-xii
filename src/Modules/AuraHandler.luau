--!strict
--!native

local AuraHandler = {}
AuraHandler.__index = AuraHandler

-------------------------< // >-------------------------
--< TYPES
-------------------------< // >-------------------------

export type t_AuraHandler = typeof(setmetatable(
	{} :: {
		plr: Player,
		char: Model,
		_animator: Animator?,
		_config: Configuration?,
		_tracks: { AnimationTrack },
	},
	{} :: typeof(AuraHandler)
	))

local t_Aura = require("@game/ReplicatedStorage/Types/Aura")

-------------------------< // >-------------------------
--< CONSTANTS
-------------------------< // >-------------------------

local YIELD_BATCH_SIZE = 3

-------------------------< // >-------------------------
--< VALIDATIONS
-------------------------< // >-------------------------

local function _AuraModelSanityCheck(aura: t_Aura.Prefab): boolean
	return aura.Model ~= nil and aura.Model.ClassName == "Model"
end

-------------------------< // >-------------------------
--< HELPER FUNCTIONS
-------------------------< // >-------------------------

local function CloneTo(start: Instance, destination: Instance): Instance
	local clone = start:Clone()
	clone.Parent = destination
	return clone
end

local function GetActiveAnimations(aura: t_Aura.Prefab): { [string]: string }
	local active: { [string]: string } = {}
	for _, anim in aura.Animations:GetChildren() do
		local sv = anim :: StringValue
		if sv.Value ~= "" then
			active[sv.Name] = sv.Value
		end
	end
	return active
end

local function GetConfig(self: t_AuraHandler): Configuration
	if self._config and self._config.Parent then return self._config end

	local existing = self.char:FindFirstChild("AuraConfiguration")
	if existing then
		self._config = existing :: Configuration
		return self._config :: Configuration
	end

	local config = Instance.new("Configuration")
	config.Name = "AuraConfiguration"
	config.Parent = self.char
	self._config = config
	
	return config
end

local function GetAnimator(self: t_AuraHandler): Animator?
	if self._animator and self._animator.Parent then return self._animator end

	local humanoid = self.char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return nil end

	self._animator = animator
	return animator
end

local function GetOffsetsFromPart(part: BasePart): { ["C0"]: CFrame, ["C1"]: CFrame }?
	local parent = part.Parent
	if not parent then return nil end

	for _, inst in parent:GetChildren() do
		if inst:IsA("Motor6D") and (inst.Part0 == part or inst.Part1 == part) then
			return { C0 = inst.C0, C1 = inst.C1 }
		end
	end

	return nil
end

local function AddInstToConfig(self: t_AuraHandler, inst: Instance): ObjectValue
	local config = GetConfig(self)
	local obj = Instance.new("ObjectValue")
	obj.Name = inst.Name
	obj.Value = inst
	obj.Parent = config
	return obj
end

local function AddMotor6D(part: BasePart, oldPart: BasePart?): Motor6D?
	local parent = part.Parent
	if not parent then return nil end

	local motor = Instance.new("Motor6D")
	motor.Name = part.Name .. "_M6D"
	motor.Part0 = parent :: BasePart
	motor.Part1 = part
	motor.Parent = parent

	if oldPart then
		local offsets = GetOffsetsFromPart(oldPart)
		if offsets then
			motor.C0 = offsets.C0
			motor.C1 = offsets.C1
		end
	end

	return motor
end

local function YieldIfNeeded(counter: number): number
	counter += 1
	if counter >= YIELD_BATCH_SIZE then
		task.wait()
		return 0
	end
	return counter
end

-------------------------< // >-------------------------
--< EQUIP / UNEQUIP
-------------------------< // >-------------------------

local function CloneScriptsOver(self: t_AuraHandler, aura: t_Aura.Prefab): boolean
	local clone = CloneTo(aura.Scripts, self.char)
	if not clone then return false end
	
	AddInstToConfig(self, clone)
	
	return true
end

local function AnimatePlayer(self: t_AuraHandler, aura: t_Aura.Prefab): boolean
	local active = GetActiveAnimations(aura)
	if next(active) == nil then return true end

	local animator = GetAnimator(self)
	if not animator then return false end

	for animType, animId in active do
		local animation = Instance.new("Animation")
		animation.Name = animType
		animation.AnimationId = animId

		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track:Play(0.1)

		table.insert(self._tracks, track)
	end

	return true
end

local function EquipModel(self: t_AuraHandler, aura: t_Aura.Prefab): boolean
	local model = aura.Model
	local counter = 0

	for _, bodyPart in model:GetChildren() do
		for _, child in bodyPart:GetChildren() do
			local match: (Model | Part)? = if bodyPart.ClassName ~= "Part"
				then self.char
				else self.char:FindFirstChild(bodyPart.Name) :: Part

			if not match then
				counter = YieldIfNeeded(counter)
				continue
			end

			local clone = CloneTo(child, match)

			if clone:IsA("BasePart") then
				local motor = AddMotor6D(clone :: BasePart, child :: BasePart)
				if motor then AddInstToConfig(self, motor :: Instance) end
			elseif clone:IsA("Motor6D") then
				clone:Destroy()
				continue
			end

			AddInstToConfig(self, clone)
			counter = YieldIfNeeded(counter)
		end
	end

	return true
end

local function UnequipModel(self: t_AuraHandler): boolean
	for _, track in self._tracks do
		track:Stop(0.1)
		track:Destroy()
	end
	table.clear(self._tracks)

	local config = GetConfig(self)
	local counter = 0

	for _, objVal: ObjectValue in config:GetChildren() do
		objVal = objVal :: ObjectValue
		local inst = objVal.Value
		if inst then inst:Destroy() end
		objVal:Destroy()
		counter = YieldIfNeeded(counter)
	end

	return true
end

-------------------------< // >-------------------------
--< SETUP
-------------------------< // >-------------------------

function AuraHandler.new(plr: Player): t_AuraHandler
	local self = setmetatable({}, AuraHandler)

	self.plr = plr
	self.char = plr.Character or plr.CharacterAdded:Wait() :: Model
	self._animator = nil
	self._config = nil
	self._tracks = {}

	print(`[{script.Name}] CREATED NEW AuraHandler FOR {plr.Name} ({plr.UserId})`)

	return self :: t_AuraHandler
end

function AuraHandler.GetPlayer(self: t_AuraHandler): Player
	return self.plr
end

function AuraHandler.GetCharacter(self: t_AuraHandler): Model
	return self.char
end

-------------------------< // >-------------------------
--< MAIN FUNCTIONS
-------------------------< // >-------------------------

function AuraHandler.EquipAura(self: t_AuraHandler, aura: t_Aura.Prefab): boolean
	if not _AuraModelSanityCheck(aura) then return false end

	if not EquipModel(self, aura) then
		warn(`[{script.Name}] Something went wrong when equipping the aura`)
		return false
	end

	if not CloneScriptsOver(self, aura) then
		warn(`[{script.Name}] Something went wrong when starting scripts`)
		return false
	end

	if not AnimatePlayer(self, aura) then
		warn(`[{script.Name}] Something went wrong whilst animating player`)
		return false
	end

	return true
end

function AuraHandler.UnequipAura(self: t_AuraHandler): boolean
	if not self.char then return false end

	if not UnequipModel(self) then
		warn(`[{script.Name}] Something went wrong whilst unequipping aura`)
		return false
	end

	return true
end

function AuraHandler.SwapAura(self: t_AuraHandler, newAura: t_Aura.Prefab): boolean
	if not self:UnequipAura() then return false end
	return self:EquipAura(newAura)
end

function AuraHandler.GetMotor(char: Model, instName: string): Motor6D?
	local inst = char:FindFirstChild(instName, true)
	if not inst or not inst.Parent then return nil end

	for _, motor in inst.Parent:GetChildren() do
		if motor:IsA("Motor6D") and motor.Part1 == inst then
			return motor
		end
	end

	return nil
end

function AuraHandler.GetMotors(char: Model, instNames: { string }): { [string]: Motor6D }
	local results: { [string]: Motor6D } = {}
	for _, name in instNames do
		local motor = AuraHandler.GetMotor(char, name)
		if motor then results[name] = motor end
	end
	return results
end

return AuraHandler