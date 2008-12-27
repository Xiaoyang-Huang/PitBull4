local _G = _G
local PitBull4 = _G.PitBull4

-- dictionary of module type name to module type prototype
local module_types = {}

-- dictionary of module type name to layout defaults
local module_types_to_layout_defaults = {}

-- dictionary of script name to a dictionary of module to callback
local module_script_hooks = {}

-- dictionary of module to layout defaults
local module_to_layout_defaults = {}

-- dictionary of module to global defaults
local module_to_global_defaults = {}

--- Add a new module type.
-- @param name name of the module type
-- @param defaults a dictionary of default values that all modules will have that inherit from this module type
-- @usage MyModule:NewModuleType("mytype", { size = 50, verbosity = "lots" })
function PitBull4:NewModuleType(name, defaults)
	--@alpha@
	expect(name, 'typeof', "string")
	expect(name, 'not_inset', module_types)
	expect(defaults, 'typeof', "table")
	--@end-alpha@
	
	module_types[name] = {}
	module_types_to_layout_defaults[name] = defaults
	
	return module_types[name]
end

PitBull4:NewModuleType("custom", {})

local Module = {}
PitBull4:SetDefaultModulePrototype(Module)

local do_nothing = function() end

--- Iterate through all script hooks for a given script
-- @param script name of the script
-- @usage for module, func in PitBull4:IterateFrameScriptHooks("OnEnter") do
--     -- do stuff here
-- end
-- @return iterator that returns module and function
function PitBull4:IterateFrameScriptHooks(script)
	--@alpha@
	expect(script, 'typeof', 'string')
	expect(script, 'match', '^On[A-Z][A-Za-z]+$')
	--@end-alpha@
	
	if not module_script_hooks[script] then
		return do_nothing
	end
	return next, module_script_hooks[script]
end

--- Run all script hooks for a given script
-- @param script name of the script
-- @param frame current Unit Frame
-- @param ... any arguments to pass in
-- @usage PitBull4:RunFrameScriptHooks(script, ...)
function PitBull4:RunFrameScriptHooks(script, frame, ...)
	--@alpha@
	expect(script, 'typeof', 'string')
	expect(frame, 'typeof', 'frame')
	expect(frame, 'inset', PitBull4.all_frames)
	--@end-alpha@

	for module, func in self:IterateFrameScriptHooks(script) do
		func(frame, ...)
	end
end

function PitBull4:OnModuleCreated(module)
	module.id = module.moduleName
	self[module.moduleName] = module
end

--- Add a script hook for the unit frames.
-- outside of the standard script hooks, there is also OnPopulate and OnClear.
-- @name Module:AddFrameScriptHook
-- @param script name of the script
-- @param func function to call or method on the module to call
-- @usage MyModule:AddFrameScriptHook("OnEnter", function(frame)
--     -- do stuff here
-- end)
function Module:AddFrameScriptHook(script, method)
	--@alpha@
	expect(script, 'typeof', 'string')
	expect(script, 'match', '^On[A-Z][A-Za-z]+$')
	expect(method, 'typeof', 'function;string;nil')
	if module_script_hooks[script] then
		expect(self, 'not_inset', module_script_hooks[script])
	end
	--@end-alpha@
	
	if not method then
		method = script
	end
	
	if not module_script_hooks[script] then
		module_script_hooks[script] = {}
	end
	module_script_hooks[script][self] = PitBull4.Utils.ConvertMethodToFunction(self, method)
end

--- Set the localized name of the module.
-- @param name the localized name of the module, with proper spacing, and in Title Case.
-- @usage MyModule:SetName("My Module")
function Module:SetName(name)
	--@alpha@
	expect(name, 'typeof', 'string')
	--@end-alpha@
	
	self.name = name
end

--- Set the localized description of the module.
-- @param description the localized description of the module, as a full sentence, including a period at the end.
-- @usage MyModule:SetDescription("This does a lot of things.")
function Module:SetDescription(description)
	--@alpha@
	expect(description, 'typeof', 'string')
	--@end-alpha@
	
	self.description = description
end

--- Set the module type of the module.
-- This should be called right after creating the module.
-- @param type one of "custom", "statusbar", or "icon"
-- @usage MyModule:SetModuleType("statusbar")
function Module:SetModuleType(type)
	--@alpha@
	expect(type, 'typeof', 'string')
	expect(type, 'inset', module_types)
	--@end-alpha@
	
	self.module_type = type
	
	for k, v in pairs(module_types[type]) do
		self[k] = v
	end
end

-- set the db instance on the module with defaults handled
local function fix_db_for_module(module, layout_defaults, global_defaults)
	module.db = PitBull4.db:RegisterNamespace(module.id, {
		profile = {
			layouts = {
				['*'] = layout_defaults,
			},
			global = global_defaults
		}
	})
end

-- return the union of two dictionaries
local function merge(alpha, bravo)
	local x = {}
	for k, v in pairs(alpha) do
		x[k] = v
	end
	for k, v in pairs(bravo) do
		x[k] = v
	end
	return x
end

--- Set the module's database defaults.
-- This will cause module.db to be set.
-- @param layout_defaults defaults on a per-layout basis. can be nil.
-- @param global_defaults defaults on a per-profile basis. can be nil.
-- @usage MyModule:SetDefaults({ color = { 1, 0, 0, 1 } })
-- @usage MyModule:SetDefaults({ color = { 1, 0, 0, 1 } }, {})
function Module:SetDefaults(layout_defaults, global_defaults)
	--@alpha@
	expect(layout_defaults, 'typeof', 'table;nil')
	expect(global_defaults, 'typeof', 'table;nil')
	expect(self.module_type, 'typeof', 'string')
	--@end-alpha@
	
	local better_layout_defaults = merge(module_types_to_layout_defaults[self.module_type], layout_defaults or {})
	
	if not PitBull4.db then
		-- full addon not loaded yet
		module_to_layout_defaults[self] = better_layout_defaults
		module_to_global_defaults[self] = global_defaults
	else
		fix_db_for_module(self, better_layout_defaults, global_defaults)
	end
end

--- Get the database table for the given layout relating to the current module.
-- @param layout either the frame currently being worked on or the name of the layout.
-- @usage local color = MyModule:GetLayoutDB(frame).color
-- @return the database table
function Module:GetLayoutDB(layout)
	--@alpha@
	expect(layout, 'typeof', 'string;table;frame')
	if type(layout) == "table" then
		expect(layout.layout, 'typeof', 'string')
	end
	--@end-alpha@
	
	if type(layout) == "table" then
		-- we're dealing with a unit frame that has the layout key on it.
		layout = layout.layout
	end
	
	return self.db.profile.layouts[layout]
end

local function enabled_iter(modules, id)
	local id, module = next(modules, id)
	if not id then
		-- we're out of modules
		return nil
	end
	if not module:IsEnabled() then
		-- skip disabled modules
		return enabled_iter(modules, id)
	end
	return id, module
end

--- Iterate over all enabled modules
-- @usage for id, module in PitBull4:IterateEnabledModules() do
--     doSomethingWith(module)
-- end
-- @return iterator which returns the id and module
function PitBull4:IterateEnabledModules()
	return enabled_iter, self.modules, nil
end

local function module_type_iter(module_type, id)
	local id, module = next(PitBull4.modules, id)
	if not id then
		-- we're out of modules
		return nil
	end
	if module.module_type ~= module_type then
		-- wrong type, try again
		return module_type_iter(module_type, id)
	end
	return id, module
end

local function module_type_enabled_iter(module_type, id)
	local id, module = next(PitBull4.modules, id)
	if not id then
		-- we're out of modules
		return nil
	end
	if module.module_type ~= module_type then
		-- wrong type, try again
		return module_type_enabled_iter(module_type, id)
	end
	if not module:IsEnabled() then
		-- skip disabled modules
		return module_type_enabled_iter(module_type, id)
	end
	return id, module
end

--- Iterate over all modules of a given type
-- @param module_type one of "statusbar", "icon", "custom"
-- @param enabled_only whether to iterate over only enabled modules
-- @usage for id, module in PitBull4:IterateModulesOfType("statusbar") do
--     doSomethingWith(module)
-- end
-- @return iterator which returns the id and module
function PitBull4:IterateModulesOfType(module_type, enabled_only)
	--@alpha@
	expect(module_type, 'typeof', 'string')
	expect(module_type, 'inset', module_types)
	expect(enabled_only, 'typeof', 'boolean;nil')
	--@end-alpha@
	
	return enabled_only and module_type_enabled_iter or module_type_iter, module_type, nil
end

do
	-- we need to hook OnInitialize so that we can handle the database stuff for modules
	local old_PitBull4_OnInitialize = PitBull4.OnInitialize
	PitBull4.OnInitialize = function(self)
		if old_PitBull4_OnInitialize then
			old_PitBull4_OnInitialize(self)
		end
		
		for module, layout_defaults in pairs(module_to_layout_defaults) do
			fix_db_for_module(module, layout_defaults, module_to_global_defaults[module])
		end
		-- no longer need these
		module_to_layout_defaults = nil
		module_to_global_defaults = nil
	end
end