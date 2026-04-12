--!strict
--!native

local Serializer = {}
Serializer.__index = Serializer

-------------------------< // >-------------------------
--< TYPES
-------------------------< // >-------------------------

type t_Converter = {
	Class: string?,
	Method: (inst: Instance) -> any?,
}

type t_Configuration = {
	read Converters: { t_Converter },
}

export type t_Params<T> = {
	read Keys: { keyof<T> },
	read Converters: { string },
}

type t_Weak = { [string]: any }
type t_Any = { [any]: any }

-------------------------< // >-------------------------
--< STATE
-------------------------< // >-------------------------

local _configuration: t_Configuration = { Converters = {} }

-------------------------< // >-------------------------
--< HELPER FUNCTIONS
-------------------------< // >-------------------------

local function ConvertSimple(params: t_Params<t_Any>, inst: Instance): any?
	local class: string? = nil
	for _, candidate in params.Converters do
		if inst:IsA(candidate) then
			class = candidate
			break
		end
	end
	if not class then return nil end

	for _, converter in _configuration.Converters do
		if converter.Class == class then
			return converter.Method(inst)
		end
	end

	return nil
end

local function ConvertCompound(params: t_Params<t_Any>, folder: Folder): any?
	for _, _class in params.Converters do
		for _, converter in _configuration.Converters do
			if converter.Class then continue end

			local converted = converter.Method(folder)
			if converted then return converted end
		end
	end

	return nil
end

local function Convert(params: t_Params<t_Any>, inst: Instance): any?
	if inst:IsA("Folder") then
		return ConvertCompound(params, inst :: Folder)
	end
	return ConvertSimple(params, inst)
end

local function WeakHasKeys<T>(params: t_Params<T>, weak: t_Weak): boolean
	for _, required in params.Keys :: { string } do
		local found = false
		for key in weak do
			if required == key then
				found = true
				break
			end
		end
		if not found then return false end
	end
	return true
end

-------------------------< // >-------------------------
--< CONVERTERS
-------------------------< // >-------------------------

function Serializer.SimpleConverterFromClass(className: string): t_Converter
	return {
		Class = className,
		Method = function(inst: Instance)
			return inst:IsA(className) and inst or nil
		end,
	}
end

function Serializer.SimpleConverterFromValueBase(className: string): t_Converter
	return {
		Class = className,
		Method = function(inst: Instance)
			return inst:IsA(className) and (inst :: ValueBase & { Value: any }).Value or nil
		end,
	}
end

-------------------------< // >-------------------------
--< SETUP
-------------------------< // >-------------------------

function Serializer.Init(config: t_Configuration): ()
	_configuration = config
	table.freeze(Serializer)
end

function Serializer.NewParams<T>(keys: { keyof<T> }, converters: { string }): t_Params<T>
	return { Keys = keys, Converters = converters }
end

-------------------------< // >-------------------------
--< MAIN FUNCTIONS
-------------------------< // >-------------------------

function Serializer.Validate<T>(params: t_Params<T>, inst: Instance): T?
	local weak: t_Weak = {}

	for _, child in inst:GetChildren() do
		if not table.find(params.Keys :: { string }, child.Name) then continue end

		local converted = Convert(params :: t_Params<t_Any>, child)
		if not converted then
			error(`Couldn't serialize {child.Name} of {inst:GetFullName()}!`)
		end

		weak[child.Name] = converted
	end

	if not WeakHasKeys(params, weak) then
		error(`Couldn't serialize instance {inst:GetFullName()}`)
	end

	return weak :: any
end

function Serializer.Batch<T>(params: t_Params<T>, folder: Folder): { T }
	local registry: { T } = {}

	for _, child in folder:GetChildren() do
		registry[#registry + 1] = Serializer.Validate(params, child)
	end

	return registry
end

return Serializer