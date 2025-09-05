--[[
--    Copyright (C) 2025  Fadestorm-Nightslayer (Discord: hatefiend)
--
--    This program is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]--

-- TODO: Allow for item links to be pasted into custom options
-- TOOD: Implement weapon stone checking for mainhand and offhand

local function main()
    ----------------------------------------------------------------------
    ---------------------------- INITIALIZING  ---------------------------
    ----------------------------------------------------------------------

	--[[ Avoid loading listeners twice. Otherwise opening or closing character
	frame causes multiple triggers of 'FCM_SHOW'/'FCM_HIDE', causing disaster]]--
	local AURA_LOADED = "FCM_WEAK_AURA_LOADED"
	if not _G[AURA_LOADED] then
		-- Convert WoW API events into WeakAura triggers
		CharacterFrame:HookScript("OnShow", function()
			WeakAuras.ScanEvents("FCM_SHOW") end)
		CharacterFrame:HookScript("OnHide", function()
			WeakAuras.ScanEvents("FCM_HIDE") end)
		_G[AURA_LOADED] = true
	end
	
	-- Imports
	local srep, lower, format, upper = string.rep, string.lower, string.format, string.upper
	local max, min, floor = math.max, math.min, math.floor
	local sort, insert, concat, remove = table.sort, table.insert, table.concat, table.remove

	local Palette, Log -- Forward declaration
	
	----------------------------------------------------------------------
	------------------------------- DEBUG --------------------------------
    ----------------------------------------------------------------------
	
	local AURA_NAME = "Fadestorm Consumable Manager"

	local function type_mismatch(expected, actual)
		Log.error(format("Type Mismatch | Expected=%s, Actual=%s", expected, actual)) end

	local function type_check_strict(expected, value)
		local actual = type(value)
		if actual ~= expected then type_mismatch(expected, actual) end
		return value
	end
	
	local function type_check_default(expected, value, producer)
		if value == nil then
			value = type_check_strict("function", producer)() end
		return type_check_strict(expected, value)
	end
	
	local function type_check_safe(expected, value)
		return type(value) == expected end

	-- @param [function] func __index function to be placed into the metatable
	-- @param (optional) [table] tbl Table to apply index to, or nil for new table
	-- @return [table] Table with attached __index metatable
	-- @return [table] Metatatble attached to the returned table
	local function index(func, tbl)
		type_check_strict("function", func)
		if tbl ~= nil then type_check_strict("table", tbl)
		else tbl = { } end
		local mt = { __index = func }
		return setmetatable(tbl, mt), mt
	end
	
	-- Creates a special table which translates indexing into strings.
	-- 		e.g. t.my_index => "my_index"
	-- The translated key is sent to a callback function for remapping.
	-- @param [function] -> [?] callback(type_str)
	--		Returned value is passed back as the return value of all __index calls
	local function stringify_keys_table(callback)
		type_check_strict("function", callback)
		return (index(function(_, key)
			return callback(type_check_strict("string", key)) end))
	end

	Log = (function(strategy)
		local MSG_FMT = "[%s] %s: %s"
		local function log_msg_color(level, msg)
			print(format(MSG_FMT, Palette.LIME(AURA_NAME), Palette.YELLOW(level), msg)) end
		local function log_msg_white(level, msg)
			print(format(MSG_FMT, AURA_NAME, level, msg)) end
		strategy = function(level, msg)
			if Palette == nil then -- May not be loaded in-time
				return log_msg_white(level, msg) end
			strategy = log_msg_color
			log_msg_color(level, msg)
		end

		return stringify_keys_table(function(level)
			return function(msg) strategy(upper(level), tostring(msg)) end end)
	end)()

	--[[
	-- Typechecking Usage:
	--
	-- Raises a Type Mismatch error if the value does not match the indexed type
	-- @param [?] value Value to be typechecked
	-- @return [?] Identity
	-- function Type.DATATYPE(value)
	--
	-- @param [?] value Value to be typechecked
	-- @return [boolean] True if the value's type matches the indexed type
	-- function check.DATATYPE(value)
	--
	-- Returns a value (or a fallback from producer) if types match, raises a Type Mismatch error
	-- @param [?] value Value to be typechecked
	-- @return [?] Identity, or produced default value if nil
	-- function default.DATATYPE(value, producer)
	]]--
	local Type, check, default = (function()
		local function make(checker)
			-- Hands back a typecheck function for the expected type
			local type_handlers = index(function(tbl, expected)
				local function handler(value, ...)
					return checker(expected, value, ...) end
				-- Cache function into the table
				rawset(tbl, expected, handler)
				return handler
			end)
			
			-- Type keys should be all uppercase to avoid 'function' keyword
			return stringify_keys_table(function(key)
				return type_handlers[lower(key)] end)
		end
		
		return make(type_check_strict), make(type_check_safe), make(type_check_default)
	end)()

    ----------------------------------------------------------------------
    -------------------------------- UTILS -------------------------------
    ----------------------------------------------------------------------

	local function factory(x) return x end
	local function table_fn() return { } end
	local function true_fn = factory(true)
	local function nil_fn = factory()
	local function identity_fn(...) return ... end
	local function is_empty(t) return next(Type.TABLE(t)) == nil end
	local function trim(s) return Type.STRING(s):match("^%s*(.-)%s*$") end

	local function clamp(x, a, b)
		return max(min(Type.NUMBER(x), Type.NUMBER(b)), Type.NUMBER(a)) end

	local function xor(a, b)
		Type.BOOLEAN(b)
		return (Type.BOOLEAN(a) and not b) or (b and not a)
	end

	-- Creates a table in which missing keys are assigned a value
	-- @param [function] [?] function(key)
	local function default_table(callback)
		Type.FUNCTION(callback)
		return index(function(tbl, key)
			local value = callback(key)
			if value ~= nil then
				rawset(tbl, key, value)
				return value
			end
		end)
	end
	
	local function sum(t)
		local s = 0
		for _, n in ipairs(Type.TABLE(t)) do
			s = s + Type.NUMBER(n) end
		return s
	end
	
	-- @param (optional) [table] static Existing static members of the class
	-- @param (optional) [table] proto Existing instance members of the class
	-- @return [table] Static table used for class methods/functions
	-- @return [table] Instance table used for instance methods
	-- @return [function] Constructor to create instances of the class
	-- @return [table] Instance metatable
	local function Class(static, proto)
		static = default.TABLE(static, table_fn)
		proto = default.TABLE(proto, table_fn)
		local mt = { 
			__index = proto,
			__metatable = false
		}
		
		-- Weak table, values can be garbage collected
		local instances = setmetatable({ }, { __mode = "k" })

		local function new(o)
			local obj = setmetatable(default.TABLE(o, table_fn), mt)
			instances[obj] = true -- Enable tracking of class instances
			return obj
		end
		
		-- @param [table] obj Object instance to check
		-- @return [boolean] True if the object is a class instance
		function static.is_instance(obj)
			return instances[Type.TABLE(obj)] end

		return static, proto, new, mt
	end
	
	-- @param [function] assigner [nil] function(e) where all enum pairs are put in param
	-- @param (optional) [table] static Class table to contain the constants, or nil to create
	-- @return [table] Enum table, or static param if originally provided
	local function Enum(assigner, static)
		static = default.TABLE(static, table_fn)
		local ordinal = 1
		local proxy = setmetatable({ }, {
			__newindex = function(_, key, value)
				rawset(static, key, value)
				rawset(static, ordinal, value)
				ordinal = ordinal + 1
			end
		})
		Type.FUNCTION(assigner)(proxy)
		return static
	end

	----------------------------------------------------------------------
    -------------------------------- COLOR -------------------------------
    ----------------------------------------------------------------------

	-- Color class for coloring text
	local Color = (function()
		local Color, proto, new, mt = Class()

		function mt:__tostring()
			return format("Color(%d, %d, %d, %d)", self.r, self.g, self.b, self.a)
		end
		
		function mt:__call(text)
			return format("|c%s%s|r", self:hex_code(), text)
		end
		
		local X, Y = 0, 255 -- min/max for color values
		local function default_alpha() return Y end

		local function to_hex(c)
			return format("%02x", clamp(c, X, Y))
		end

		-- @return [string] Hex code for the color
		function proto:hex_code()
			return format("ff%s%s%s", to_hex(self.r), to_hex(self.g), to_hex(self.b))
		end

		function Color.new(r, g, b, a)
			return new({
				r = clamp(floor(Type.NUMBER(r)), X, Y),
				g = clamp(floor(Type.NUMBER(g)), X, Y),
				b = clamp(floor(Type.NUMBER(b)), X, Y),
				a = clamp(floor(default.NUMBER(a, default_alpha)), X, Y),
			})
		end
		
		return Color
	end)()
	
	Palette = { -- Forward declare for 'Log' function
		RED = Color.new(255, 0, 0),
		GREEN = Color.new(0, 255, 0),
		TURQUOISE = Color.new(64, 224, 208),
		YELLOW = Color.new(255, 255, 0),
		WHITE = Color.new(255, 255, 255),
		SLATE = Color.new(198, 226, 255),
		GRAY = Color.new(170, 170, 170),
		ORANGE = Color.new(255, 165, 0),
		PURPLE = Color.new(160, 32, 240),
		PINK = Color.new(255, 105, 180),
		TAN = Color.new(210, 180, 140),
		GOLD = Color.new(255, 215, 0),
		SILVER = Color.new(192, 192, 192),
		CYAN = Color.new(0, 255, 255),
		LIME = Color.new(191, 255, 0),
		MAGENTA = Color.new(255, 0, 255),
		DODGER = Color.new(30, 144, 255),
		CRIMSON = Color.new(220, 20, 60),
		CHARTREUSE = Color.new(127, 255, 0),
		CORAL = Color.new(240, 128, 128),
		GOLDENROD = Color.new(250, 250, 210),
		--[[ Removed colors, poor display on black BG ]]--
		--BROWN = Color.new(139, 69, 19),
		--BLUE = Color.new(0, 0, 255),
		--BLACK = Color.new(0, 0, 0),
		--TEAL = Color.new(0, 128, 128),
		--NAVY = Color.new(0, 0, 128),
		--MAROON = Color.new(128, 0, 0),
		--OLIVE = Color.new(128, 128, 0),
	}

	----------------------------------------------------------------------
    ------------------------------- STREAM -------------------------------
    ----------------------------------------------------------------------

	local Stream = (function()
		local Stream, proto, new, mt = Class()

		-- @param [function] Iteration function, e.g. 'pairs', 'ipairs', etc
		-- @param (Optional) [?] state Table or variable passed into the iter
		-- @return [table] Stream instance
		function Stream:new(iter, state)
			return new({
				iter = Type.FUNCTION(iter),
				state = state,
				operations = { },
				callbacks = { }
			})
		end

		--[[ Stateless Stream Functions ]]--

		local function map(k, v, callback) k, v = callback(k, v); return k, v end
		local function peek(k, v, callback) callback(k, v); return k, v end

		local function filter(k, v, callback)
			if Type.BOOLEAN(callback(k, v)) == true then
				return k, v end end

		--[[ Stateful Stream Functions ]]--

		local function unique_factory()
			local distinct = setmetatable({ }, { __mode = "k" }) -- Weak Table
			return function(k, v, callback)
				local key = callback(k, v)
				if distinct[key] == nil then
					distinct[key] = true -- Mark that we've seen this mapping
					return k, v
				end
			end
		end
		
		--[[ Prebuilt Callback Functions ]]--

		local Mapping = (function()
			local function stateful(factory) return factory end
			local function stateless(func) 
				return function() return func end end
			local mappings = {
				invert = stateless(function(k, v) return v, k end),
				set = stateless(function(k, v) return v, true end),
				keys = stateful(function() local i = 0
					return function(k, v) i = i + 1; return i, k end end),
				values = stateful(function() local i = 0
					return function(k, v) i = i + 1; return i, v end end),
			}
			return stringify_keys_table(function(key)
				return mappings[key]() end) -- Call the factory to return the cb
		end)()

		-- Executes all operations on a pairing, short-circuiting if nil
		local function try_pair_ops(k, v, ops, cbs)
			for i, op in ipairs(ops) do
				k, v = op(k, v, cbs[i])
				if k == nil or v == nil then return end end
			return k, v
		end

		-- Returns an iterator that performs all operations and callbacks
		local function iterator(instance)
			local iter, state, last_key = instance.iter(instance.state)
			Type.FUNCTION(iter) -- Mandatory
			local ops, cbs, k, v = instance.operations, instance.callbacks
			return function()
				repeat last_key, v = iter(state, last_key) -- Move source
					if last_key == nil or v == nil then return end -- iter empty
					k, v = try_pair_ops(last_key, v, ops, cbs)
					if k ~= nil and v ~= nil then return k, v end
				until false
			end
		end

		local function inject_op(instance, op, cb)
			insert(instance.operations, op)
			insert(instance.callbacks, cb)
			return instance
		end

		local function operation_factory(op)
			return function(instance, callback)
				return inject_op(instance, op, Type.FUNCTION(callback)) end
		end

		--[[ Accessing Stream Functions ]]--

		-- Allows inspection of mappings during the stream
		-- @param [function] callback | function(k, v)
		-- @return [table] Instance
		proto.peek = operation_factory(peek)

		-- @return [function] iterator | [k, v] function()
		mt.__call = iterator -- Call instance for iterator

		--[[ Mutating Stream Functions ]]--

		-- Filters out mappings unless their callback returns true
		-- @param [function] callback | [boolean] function(k, v)
		-- @return [table] Instance
		proto.filter = operation_factory(filter)

		-- Mutates mappings into new pairs returned by the callback
		-- @param [function] callback | [?, ?] function(k, v)
		-- @return [table] Instance
		proto.map = operation_factory(map)

		-- Guarantees uniqueness of elements based on callback-defined identity
		-- @param [function] callback | [?] function(k, v)
		-- @return [table] Instance
		function proto:unique(callback)
			return inject_op(self, unique_factory(), Type.FUNCTION(callback)) end

		-- Inverts mappings, swapping keys with values
		-- @return [table] Instance
		function proto:invert() return inject_op(self, map, Mapping.invert) end
			
		-- Associates values in the stream with `true`, forming a set
		-- @return [table] Instance
		function proto:set() return inject_op(self, map, Mapping.set) end
			
		-- Converts the stream into an indexed stream of keys
		-- @return [table] Instance
		function proto:keys() return inject_op(self, map, Mapping.keys) end
			
		-- Converts the stream into an indexed stream of values
		-- @return [table] Instance
		function proto:values() return inject_op(self, map, Mapping.values) end

		-- Sorts the values in the stream using a custom comparator
		-- @param [function] callback | [boolean] function(a, b)
		-- @return [table] Instance
		function proto:sorted(callback)
			local values = self:collect()
			sort(values, Type.FUNCTION(callback))
			return Stream:new(ipairs, values) -- Return brand-new stream
		end

		--[[ Collect Stream Functions ]]--
		
		-- TODO: Groupby

		-- @return [table] Table of collected elements of the stream
		function proto:collect()
			local t = { }
			for k, v in iterator(self) do t[k] = v end
			return t
		end

		return Stream
	end)()
	
    ----------------------------------------------------------------------
    ----------------------------- COLLECTIONS ----------------------------
    ----------------------------------------------------------------------

	local LinkedMap = (function()
		local LinkedMap, proto, new, mt = Class()
		local HOLE_SENTINEL = proto -- Sentinel value used to designate empty array slots
		local proto_index = mt.__index -- Hook into the class' index, since we orverride

		local function init(iter, state)
			local keys, values, indexes = { }, { }
			if indexes == nil then
				indexes = Stream:new(Type.FUNCTION(iter), state)
					:peek(function(k, v) insert(keys, k); insert(values, v) end) -- Ordered
					:collect() -- Copy the initial values
			else indexes = { } end
			return keys, values, indexes
		end

		-- @param (Optional) [function] iter Iteration function for the parameter table
		-- @param (Optional) [?] state State passed into the iterator
		function LinkedMap:new(iter, state)
			local keys, values, indexes = init(iter, state)
			return new({ keys = keys, values = values, indexes = indexes, size = #keys })
		end

		-- Iterates over all pairings in the map
		-- @return [table] Stream instance
		function proto:stream()
			return Stream:new(ipairs, self.keys)
				:filter(function(k, v) return v ~= HOLE_SENTINEL end) -- Skip holes
				:map(function(k, v) v, self.values[self.indexes[v]] end)
		end

		function mt.__index(instance, key) -- Enable access by key
			if key == nil then return end
			local index = instance.indexes[key]
			return instance.values[index]
		end

		function mt.__newindex(_, key, value) -- Enable pairing
			local index = instance.indexes[key]
			if index == nil then -- New key/value pairing
				if value == nil then return end
				insert(instance.keys, key)
				insert(instance.values, value)
				local size = instance.size + 1
				instance.indexes[key] = size
				instance.size = size
			elseif value == nil then -- Pairing removal
				instance.indexes[key] = nil
				instance.keys[index] = HOLE_SENTINEL
				instance.size = instance.size - 1
			else instance.values[index] = value end -- Update value
		end
	end)
	
    ----------------------------------------------------------------------
    -------------------------------- ITEM --------------------------------
    ----------------------------------------------------------------------
	
	local Item = (function()
		local Item, proto, new, mt = Class()
		
		local by_id, by_name, by_category = { }
		local categories = { }
		
		-- Holds item IDs which have yet to be cached
		local pending_by_id = { }

		-- TODO: This needs to be a linked hash map
		-- TODO: allow for holes in the array during iteration
		-- TODO: highly consider making a database class
		-- TODO: Encapsulate the two lists together
		
		-- @param [string] item_name Name of the item, case-insensitive
		-- @return [table] Corresponding Item instance, or nil if DNE
		function Item.by_name(item_name)
			return by_name[lower(trim(Type.STRING(item_name)))] end
		
		-- @param [number] item_id In-game ID of the item
		-- @return [table] Corresponding Item instance, or nil if DNE
		function Item.by_id(item_id) return by_id[Type.NUMBER(item_id)] end

		-- @return [table] List of sorted category names
		function Item.categories() return categories end

		-- @param [string] category Category name
		-- @param [table] List of sorted items for the category, sorted by name
		function Item.by_category(category) 
			return by_category[Type.STRING(category)] end
		
		-- @param [number] item_id In-game ID of the item
		-- @param (optional) [number] spell_id In-game ID of the self-buff the item applies
		-- @return [table] Item instance
		function Item:new(item_id, spell_id)
			local obj = new({ item_id = Type.NUMBER(item_id) })
			if spell_id ~= nil then
				obj.spell_id = Type.NUMBER(spell_id) end
			by_id[item_id] = obj -- Allow reverse lookups
			if not item_cached(item_id) then
				pending_by_id[item_id] = true end
			return obj
		end

		-- TSM addon can provide information of items across your whole account
		local function get_all_item_counts_wow(item_id)
			return GetItemCount(item_id, true) end -- 2nd param includes bank
		local function get_all_item_counts_tsm(item_id)
			return sum({ TSM_API.GetPlayerTotals(format("i:%d", item_id)) }) end
		local get_all_item_counts = (function()
			return (TSM_API and TSM_API.GetPlayerTotals) 
				and get_all_item_counts_tsm or get_all_item_counts_wow
		end)()
		
		-- @return [number] Quantity of the item in the player's bags
		-- @return [number] Quantity of the item outside of the player's bags
		function proto:get_supply()
			local item_id = self.item_id
			local bag_count = GetItemCount(item_id)
			if select(4, proto:get_info()) then -- Soulbound?
				-- Don't count soulbound items from other characters
				return bag_count, get_all_item_counts_wow(item_id) - bag_count end
			return bag_count, get_all_item_counts(item_id) - bag_count
		end

		-- @param [number] size Size of the icon for the in-line string
		function proto:icon(size)
			local texture = select(3, self:get_info())
			return format("|T%d:%d:%d|t", texture, Type.NUMBER(size), size)
		end

		-- Collects names of all items in the database and alphabetizes items
		local function process_item_names()
			for _, items in pairs(by_category) do
				sort(items, function(a, b) return a:get_info() < b:get_info() end) end
		end

		local function query_item(item_id)
			local name, link, _, _, _, _, _, _, _, 
				texture, _, _, _, bound = GetItemInfo(Type.NUMBER(item_id))
			if name == nil then return end
			local item = by_id[item_id] -- Complete the item's internal data
			item.name, item.link, item.texture, item.bound = name, link, texture, bound
			by_name[lower(name)] = item
			pending_by_id[item_id] = nil
		end

		-- @return [boolean] True if the database has all items cached
		Item.ready = (function(strategy) -- Abusing param as a local
			strategy = function()
				-- TODO: Determine how to loop over and remove as we go.
				if is_empty(pending_by_id) then -- Client has all item data
					process_item_names() -- Signal item names are now accessible
					strategy = true_fn
					return true end
				return false
			end
			
			return function() return strategy() end
		end)()

		-- Accepts a query response and/or queries the server for item information
		-- @param [number] item_id Item ID of the response, or to query
		-- @param (Optional) [boolean] success False if the item failed to be cached
		function Item.cache(item_id, success)
			if pending_by_id[Type.NUMBER(item_id)] == nil then return end
			if success ~= false then query_item(item_id)
			else Log.info(format("server failed to yield item info for i:%d", item_id)) end
		end

		local function init_database() -- If only WeakAuras allowed JSON files
			

			categories = Stream:new(pairs, item_dump)
				:peek(function(k, v) 
					for i, e in ipairs(v) do
						category_by_item[e] = k end end)
				:keys()
				:sorted(function(a, b) return a < b end)
				:collect()
			by_category = item_dump -- Already in-form
		end
		
		init_database()
		return Item
	end)()
	
	local Database = (function()
		local Database = { }


		local ITEM_DUMP = { -- Item ID, Aura ID
			["Flask"] = {
				{ 13510, 17626 }, -- Flask of the Titans
				{ 13511, 17627 }, -- Flask of Distilled Wisdom
				{ 13512, 17628 }, -- Flask of Supreme Power
				{ 13513, 17629 }, -- Flask of Chromatic Resistance
				{ 13506 }, -- Flask of Petrification
			},
			["Protection"] = {
				{ 13461, 17549 }, -- Greater Arcane Protection Potion
				{ 13457, 17543 }, -- Greater Fire Protection Potion
				{ 13456, 17544 }, -- Greater Frost Protection Potion
				{ 13458, 17546 }, -- Greater Nature Protection Potion
				{ 13459, 17548 }, -- Greater Shadow Protetion Potion
				{ 13460, 17545 }, -- Greater Holy Protection Potion
				{ 6052 }, -- Nature Protection Potion
				{ 6050 }, -- Frost Protection Potion
				{ 6049 }, -- Fire Protection Potion
				{ 6048 }, -- Shadow Protection Potion
				{ 6051 }, -- Holy Protection Potion
				{ 4376 }, -- Flame Deflector
				{ 4386 }, -- Ice Deflector
			},
			["Elixir"] = {
				{ 13445, 11348 }, -- Elixir of Superior Defense
				{ 20004, 24361 }, -- Major Troll's Blood Potion
				{ 3825, 3593 }, -- Elixir of Fortitude
				{ 13452, 17538 }, -- Elixir of the Mongoose
				{ 20007, 24363 }, -- Mageblood Potion
				{ 9206, 11405 }, -- Elixir of Giants
				{ 12820, 17038 }, -- Winterfall Firewater
				{ 9088, 11371 }, -- Gift of Arthas
				{ 13454, 17539 }, -- Greater Arcane Elixir
				{ 9264, 11474 }, -- Elixir of Shadow Power
				{ 21546, 26276 }, -- Elixir of Greater Firepower
				{ 17708, 21920 }, -- Elixir of Frost Power
				{ 1177, 673 }, -- Oil of Olaf
				{ 23211, 29334 }, -- Toasted Smorc
				{ 23326, 29333 }, -- Midsummer Sausage
				{ 23435, 29335 }, -- Elderberry Pie
				{ 23327, 29332 }, -- Fire-toasted Bun
				{ 22239, 27722 }, -- Sweet Surprise
				{ 22237, 27723 }, -- Dark Desire
				{ 22236, 27720 }, -- Buttermilk Delight
				{ 22238, 27721 }, -- Very Berry Cream
			},
			["Juju"] = {
				{ 12457, 16325 }, -- Juju Chill
				{ 12460, 16329 }, -- Juju Might
				{ 12450 }, -- Juju Flurry
				{ 12459 }, -- Juju Escape
				{ 12455, 16326 }, -- Juju Ember
				{ 12458, 16327 }, -- Juju Guile
				{ 12451, 16323 }, -- Juju Power
			},
			["Combat"] = {
				{ 13446 }, -- Major Healing Potion
				{ 13444 }, -- Major Mana Potion
				{ 18253 }, -- Major Rejuvenation Potion
				{ 9144 }, -- Wildvine Potion
				{ 18841 }, -- Combat Mana Potion
				{ 13443 }, -- Superior Mana Potion
				{ 13442 }, -- Mighty Rage Potion
				{ 3387 }, -- Limited Invulnerability Potion
				{ 5634 }, -- Free Action Potion
				{ 20008 }, -- Living Action Potion
				{ 20520 }, -- Dark Rune
				{ 12662 }, -- Demonic Rune
				{ 11952 }, -- Night Dragon's Breath
				{ 11951 }, -- Whipper Root Tuber
				{ 7676 }, -- Thistle Tea
				{ 16023 }, -- Masterwork Target Dummy
				{ 4392 }, -- Advanced Target Dummy
				{ 14530 }, -- Heavy Runecloth Bandage
				{ 1322 }, -- Fishliver Oil
				{ 2459 }, -- Swiftness Potion
				{ 13455, 17540 }, -- Greater Stoneshield Potion
				{ 20002 }, -- Greater Dreamless Sleep Potion
				{ 12190 }, -- Dreamless Sleep Potion
			},
			["Cleanse"] = {
				{ 3386 }, -- Elixir of Poison Resistance
				{ 19440 }, -- Powerful Anti-Venom
				{ 2633 }, -- Jungle Remedy
				{ 6452 }, -- Anti-Venom
				{ 6453 }, -- Strong Anti-Venom
				{ 9030 }, -- Restorative Potion
				{ 9322 }, -- Undamaged Venom Sac
				{ 13462 }, -- Purification Potion
				{ 19183 }, -- Hourglass Sand
			},
			["Un'goro"] = {
				{ 11567, 15279 }, -- Crystal Spire
				{ 11563, 15231 }, -- Crystal Force
				{ 11566 }, -- Crystal Charge
				{ 11562 }, -- Crystal Restore
				{ 11564, 15233 }, -- Crystal Ward
				{ 11565 }, -- Crystal Yield
			},
			["Misc"] = {
				{ 5206, 5665 }, -- Bogling Root
				{ 18297 }, -- Thornling Seed
				{ 8529 }, -- Noggenfogger Elixir
				{ 9172 }, -- Invisibility Potion
				{ 3823 }, -- Lesser Invisibility Potion
				{ 6372 }, -- Swim Speed Potion
				{ 21519 }, -- Mistletoe
				{ 184937 }, -- Chronoboon Displacer
				{ 12384 }, -- Cache of Mau'ari
				{ 21321 }, -- Red Qiraji Resonating Crystal
				{ 21324 }, -- Yellow Qiraji Resonating Crystal
				{ 21323 }, -- Green Qiraji Resonating Crystal
				{ 21218 }, -- Blue Qiraji Resonating Crystal
				{ 22754 }, -- Eternal Quintessence
				{ 17333 }, -- Aqual Quintessence
			},
			["Enhancement"] = {
				{ 3829 }, -- Frost Oil
				{ 3824 }, -- Shadow Oil
				{ 20749 }, -- Brilliant Wizard Oil
				{ 20748 }, -- Brilliant Mana Oil
				{ 23123 }, -- Blessed Wizard Oil
				{ 23122 }, -- Consecrated Sharpening Stone
				{ 18262 }, -- Elemental Sharpening Stone
				{ 12404 }, -- Dense Sharpening Stone
				{ 12643 }, -- Dense Weightstone
			},
			["Explosive"] = {
				{ 8956 }, -- Oil of Immolation
				{ 13180 }, -- Stratholme Holy Water
				{ 10646 }, -- Goblin Sapper Charge
				{ 18641 }, -- Dense Dynamite
				{ 15993 }, -- Thorium Grenade
				{ 4390 }, -- Iron Grenade
				{ 16040 }, -- Arcane Bomb
			},
			["Unique"] = {
				{ 8410, 10667 }, -- R.O.I.D.S.
				{ 8412, 10669 }, -- Ground Scorpok Assay
				{ 8423, 10692 }, -- Cerebral Cortex Compound
				{ 8424, 10693 }, -- Gizzard Gum
				{ 8411, 10668 }, -- Lung Juice Cocktail
				{ 20079, 24382 }, -- Spirit of Zanza
				{ 20080, 24417 }, -- Sheen of Zanza
				{ 20081, 24383 }, -- Swiftness of Zanza
				{ 184938 }, -- Supercharged Chronoboon Displacer
			},
			["Ammo"] = {
				{ 12654 }, -- Doomshot
				{ 13377 }, -- Miniature Cannon Balls
				{ 11630 }, -- Rockshard Pellets
				{ 19316 }, -- Ice Threaded Arrow
				{ 19317 }, -- Ice Threaded Bullet
				{ 18042 }, -- Thorium Headed Arrow
				{ 15997 }, -- Thorium Shells
			},
			["Food"] = {
				{ 13928, 18192 }, -- Grilled Squid
				{ 20452, 24799 }, -- Smoked Desert Dumplings
				{ 13931, 18194 }, -- Nightfin Soup
				{ 18254, 22730 }, -- Runn Tum Tuber Surprise
				{ 21023, 25661 }, -- Dirge's Kickin' Chimaerok Chops
				{ 13813, 18141 }, -- Blessed Sunfruit Juice
				{ 13810, 18125 }, -- Blessed Sunfruit
				{ 18284, 22790 }, -- Kreeg's Stout Beatdown
				{ 18269, 22789 }, -- Gordok Green Grog
				{ 21151, 25804 }, -- Rumsey Rum Black Label
				{ 13724 }, -- Enriched Manna Biscuit
				{ 19301 }, -- Alterac Manna Biscuit
			},
			["Equipment"] = {
				{ 15138 }, -- Onyxia Scale Cloak
				{ 16309 }, -- Drakefire Amulet
				{ 810 }, -- Hammer of the Northern Wind
				{ 10761 }, -- Coldrage Dagger
			}
		}
	end)

    ----------------------------------------------------------------------
    -------------------------------- MODEL -------------------------------
    ----------------------------------------------------------------------
	
	local Severity = (function()
		local Symbol = (function()
			local function repr() return self.color(self.code) end
			local symbol_mt = { __call = repr, __tostring = repr }
			return function(code, color)
				return setmetatable({ code = code, color = color }, symbol_mt) end
		end)
		
		local function make_severity(status, marker)
			return { status = status, marker = marker } end
		
		local Severity = {
			STABLE = make_severity(Symbol("OK", Palette.GREEN), Symbol("--", Palette.WHITE)),
			WARNING = make_severity(Symbol("+?", Palette.YELLOW), Symbol("<<", Palette.CORAL)),
			CRITICAL = make_severity(Symbol("NO", Palette.RED), Symbol(">>", Palette.ORANGE))
		}
		
		local function severity_by_buff(aura_id, low_duration_thresh)
			local duration, expire_ts = select(5, WA_GetUnitBuff(PLAYER, aura_id))
			-- Aura could not be found on the player's buffs
			if duration == nil then return Severity.CRITICAL end
			local remaining = expire_ts - GetTime()
			if remaining / duration <= low_duration_thresh then
				return Severity.WARNING end
			return Severity.STABLE
		end
		
		-- Measures the severity of a consumable's remaining duration
		-- Items that yield no buff always report STABLE
		-- @param [table] item Item instance to check aura duration of
		-- @param [table] prefs Preferences instance for low duration thresh
		-- @return [table] Severity instance, based on remaining duration
		function Severity:of_duration(item, prefs)
			local aura_id = Type.TABLE(item).spell_id
			if aura_id == nil then return self.STABLE end -- No duration => stable
			return severity_by_buff(aura_id, Type.TABLE(prefs).low_duration)
		end
		
		-- Measures the severity of a consumable's remaining supply
		-- If TSM is installed, supply of all your realm characters are considered
		-- If TSM is not installed, supply of only bags and bank are considered
		-- @param [table] item Item instance to check quantity of
		-- @param [table] prefs Preferences instance for req quantities
		-- @return [table] Severity instance, based on available supply
		function Severity:of_quantity(item, prefs)
			local quantities = Type.TABLE(prefs).quantities
			local req_quantity = quantities[Type.TABLE(item)]
			local bags, elsewhere = item:get_supply()
			if bags >= req_quantity then return Severity.STABLE end
			if bags + elsewhere >= req_quantity then return Severity.WARNING end
			return Severity.CRITICAL
		end
		
		-- @param [table] status Severity to be applied to the status of the token
		-- @param [table] marker Severity to be applied to the marker of the token
		-- @return [string] Token signifying this severity combination
		function Severity.token(status, marker)
			marker = tostring(Type.TABLE(marker)) -- avoid double-calling tostring
			return format("%s %s %s", marker, Type.TABLE(status), marker)
		end
		
		return Severity
	end)()
	
	--[[
	Predicates
	[1] | IN_DUNGEON_RAID: Returns true if the player is in a dungeon/raid
	[2] | IN_RESTED_AREA: Returns true if the player is in a city/inn
	[3] | ITEM_YIELDS_BUFF: Returns true if the item can apply a buff
	[4] | ITEM_IN_INVENTORY: Returns true if at item is in the player's bags
	]]--
	local Predicate = Enum(function(e)
		-- Returns true if the player is inside of a dungeon or raid
		e.IN_DUNGEON_RAID = (function()
			local z_types = { party = true, raid = true, scenario = true }
			return function()
				return z_types[(select(2, GetInstanceInfo()))] ~= nil end
		end)()
		-- Returns true if the player is currently in a city or inn
		e.IN_RESTED_AREA = IsResting
		-- Returns true if the specified item has buffing capability
		e.ITEM_YIELDS_BUFF = function(item)
			return Type.TABLE(item).spell_id ~= nil end
		-- Returns true if at least one of the item is in the player's inventory
		e.ITEM_IN_INVENTORY = function(item)
			return GetItemCount(Type.TABLE(item).item_id) > 0 end
	end)
	
	-- Predicate wrapper
	local Condition = (function()
		local Condition, proto, new, mt = Class()
		-- Call predicate, pass in item param, negate output if applicable
		mt.__call = function(t, ...) return xor(t.pred(...), t.negate) end
		
		-- @param [function] pred Predicate callback
		-- @param [boolean] negate True to negate the predicate
		-- @return [table] Condition instance
		function Condition:new(pred, negate)
			return new({
				pred = Type.FUNCTION(pred),
				negate = Type.BOOLEAN(negate)
			})
		end
		
		return Condition
	end)()
	
	local Rule = (function()
		local Rule, proto, new, mt = Class()
		mt.__call = function(tbl, ...)
			-- Rules cannot be true if they have no conditions
			if is_empty(tbl.conditions) then return false end
			for _, cond in ipairs(tbl.conditions) do
				if cond(...) ~= true then return false end end
			return true
		end
		
		-- @param [table] List of conditions which are tested to all be true
		-- @return [table] Rule instance
		function Rule:new(conditions)
			return new({ conditions = Type.TABLE(conditions) }) end
		
		-- @param [table] rules List of rule instances to evaluate
		-- @param [varargs] ... Params to be passed into each rule
		-- @return [boolean] True if any rule is passing
		function Rule.any_passing(rules, ...)
			-- TODO: Add short circuit stream operation for 'anyMatch'/'firstMatch'
			for _, rule in ipairs(Type.TABLE(rules)) do
				if rule(...) == true then return true end end
			return false
		end
		
		return Rule
	end)()
	
	----------------------------------------------------------------------
    --------------------------- CUSTOM OPTIONS ---------------------------
    ----------------------------------------------------------------------
	
	local Preference = (function()
		local Preference, proto, new, mt = Class()

		local config = aura_env.config
		local options, profiles = config.options, config.profiles
		
		local function load_low_duration() 
			return options.low_duration_thresh / 100 end
		
		local function load_quantities()
			local _, active_profile = next(profiles) -- Always loads top profile
			if active_profile == nil then return { } end -- No profiles
			return Stream:new(ipairs, active_profile.consumes)
				:map(function(k, v)
					local item = Item.by_name(lower(trim(v.name)))
					if item == nil then Log.info("User Config | Unknown Item: " .. v.name) end
					return item, v.req_quantity end)
				:collect()
		end
		
		local function load_rules()
			return Stream:new(ipairs, options.rules)
				:filter(function(k, v) return v.enable end)
				:map(function(k, v)
					return k, Stream:new(ipairs, v.conditions)
						:map(function(k, v)
							local pred = Predicate[v.predicate] -- Dropdown index -> Predicate
							return k, Condition:new(pred, v.negate)
						end):collect()
				end)
				:values()
				:map(function(k, v) return k, Rule:new(v) end)
				:collect()
		end
		
		function Preference:new()
			return new({
				rules = load_rules(),
				quantities = load_quantities(),
				low_duration = load_low_duration(),
			})
		end
		
		-- Note: This function should not be called before `Item.ready`
		-- @return [table] Retrieves the singleton preference instance
		function Preference:get()
			local instance = self.instance
			if instance == nil then
				instance = self:new()
				self.instance = instance
			end
			return instance
		end
		
		-- @return [table] List of items which the user wants to display
		function proto:filter_items()
			local rules = self.rules
			return Stream:new(pairs, self.quantities)
				:filter(function(k) return not Rule.any_passing(rules, k) end)
				:keys()
				:sorted(function(a, b) return (a:get_info()) < (b:get_info()) end)
				:collect()
		end
		
		return Preference
	end)()

	-- @return [table] Sorted list of categories
	-- @return [table] Map sorted items by category
	local function get_relevant_items()
		local valid_items = Preference:get():filter_items()
		-- List of sorted categories and map of sorted items by category
		local categories = Stream:new(ipairs, valid_items)
			:map(function(k, v) return k, v:category() end)
			:unique(function(k, v) return v end)
			:values()
			:sorted(function(a, b) return a < b end)
			:collect()
		local by_category = Stream:new(ipairs, categories)
			:map(function(k, v) return v, { } end)
			:collect()
		for _, item in ipairs(valid_items) do
			insert(by_category[item:category()], item) end
		return categories, by_category
	end
	
    ----------------------------------------------------------------------
	------------------------------ DISPLAY -------------------------------
    ----------------------------------------------------------------------
	
	local function length_override(str, length)
		if length == nil then  return Type.STRING(str), #str end
		return Type.STRING(str), Type.NUMBER(length)
	end

	local Block = (function()
		local Block, proto, new, mt = Class()
		
		function Block:new(min_width)
			return new({
				headers = { }, -- Headers in-order
				header_widths = { }, -- Header widths in-order
				sections = default_table(table_fn), -- Lines in-order
				width = 0,
				min_width = Type.NUMBER(min_width),
			})
		end

		local function verify_length(instance, str, length) -- Updates block size
			str, length = length_override(str, length)
			instance.width = max(length, instance.width)
			return str, length
		end
		
		-- @param [string] title Centered text of the header section
		-- @param (optional) [number] length Text length override
		-- @return [table] Builder instance
		function proto:header(title, length)
			title, length = verify_length(self, title, length)
			insert(self.headers, title)
			insert(self.header_widths, length)
			return self
		end
		
		-- @param [string] line Text to be appended under the current header
		-- @param (optional) [number] length Text length override
		-- @return [table] Builder instance
		function proto:line(line, length)
			if next(self.headers) == nil then return self end -- Safety
			local lines = self.sections[#self.headers]
			insert(lines, (verify_length(self, line, length)))
			return self
		end

		-- Sorted list of colors, filtering out banned colors
		local function make_palette(banned_colors)
			banned_colors = Stream:new(ipairs, Type.TABLE(banned_colors))
				:set():collect()
			return Stream:new(pairs, Palette)
				:filter(function(k, v) return banned_colors[v] ~= true end)
				:keys() -- Filter can damage list, reform indexes
				-- Sort by color name for more consistent color patterns
				:sorted(function(a, b) return a < b end)
				:map(function(k, v) return k, Palette[v] end)
				:collect() -- Translate color strs to color objects
		end

		-- Ensures colors table corresponds to the headers table
		local function ensure_colors(instance, colors)
			local headers = instance.headers
			if next(colors) == nil then insert(colors, Palette.WHITE) end
			local num_colors = #colors
			local shortfall = #headers - num_colors
			for i = 1, shortfall do -- edge case: not enough colors
				local index = (i - 1) % num_colors + 1 -- Wrap-around
				insert(colors, colors[index])
			end
			return colors
		end

		-- Determines the exact formatting of the divider based on available space
		local function format_header(title, len, block_width, char)
			if len + 1 >= block_width then return title end -- No space
			local PART_FMT = "%s %s %s"
			local part_len_f = (block_width - len) / 2 - 1
			local part_len = floor(part_len_f)
			local part = srep(char, part_len)
			if part_len_f == part_len then
				return format(PART_FMT, part, title, part) end
			return format(PART_FMT, part, title, part) .. char
		end

		-- Constructs the header at the specified index
		local function make_header(instance, title, index, char)
			local block_width = max(instance.width, instance.min_width)
			if trim(title) == "" then return srep(divider_char, block_width) end
			local header_width = instance.header_widths[index]
			return format_header(title, header_width, block_width, char)
		end

		-- @param [table] color_filter List of header colors which should not be used
		-- @return [string] Built text block
		function proto:build(char, color_filter)
			Type.STRING(char)
			local colors = make_palette(default.TABLE(color_filter, table_fn))
			ensure_colors(self, colors) -- In case we filter too many colors
			return concat(Stream:new(ipairs, self.headers)
				:map(function(k, v) 
					local lines = concat(self.sections[k], "\n")
					local header = make_header(self, colors[k](v), k, char)
					return k, format("%s\n%s", header, lines)
				end)
				:collect(), "\n")
		end
		
		return Block
	end)()

	local StringBuilder = (function()
		local StringBuilder, proto, new, mt = Class()

		local function append(instance, str, length)
			str, length = length_override(str, length)
			insert(instance.sections, str)
			insert(instance.lengths, length)
		end

		-- @param (Optional) [string] initial Initial string value
		-- @param (Optiona) [number] length Override for string length
		-- @return Instance
		function StringBuilder:new(initial, length)
			local obj = new({sections = { }, lengths = { }})
			if initial ~= nil then append(obj, initial, length) end
			return obj
		end

		-- @param [string] str String to be appended to the builder
		-- @param (Optional) [number] length Override for string length
		-- @return Instance
		function proto:append(str, length) 
			append(self, str, length); return self end

		-- @return [string] Built concatenated string
		-- @return [number] Total length of each component
		function proto:build(delimeter)
			local sections = self.sections
			local length = sum(self.lengths)
			if delimeter ~= nil then
				local str = concat(sections, Type.STRING(delimeter))
				-- Delimeter adds to overall length
				return str, length + max(0, #delimeter * (#sections - 1))
			end
			return concat(sections), length
		end

		return StringBuilder
	end)()

    ----------------------------------------------------------------------
    --------------------------- EVENT HANDLERS  --------------------------
    ----------------------------------------------------------------------
	
	local function handle_fcm_show()
		if Item.ready() then -- Ensure all item are cached
			Log.debug("Loading preferences.")
			local prefs = Preference:new()
			local categories, by_category = get_relevant_items()
			Log.debug("Attempting to display.")
			if is_empty(by_category) then return end -- No valid items

			local display_block = Block:new(34)
			for _, category in ipairs(categories) do
				display_block:header(category)
				for _, item in ipairs(by_category[category]) do
					local status = Severity:of_quantity(item, prefs) -- Quantity health
					local marker = Severity:of_duration(item, prefs) -- Buff duration health
					local token = Severity.token(status, marker) -- Token to describe both
					local name, link = item:get_info()

					local line = StringBuilder:new(token, 8) -- +6 for token, +2 for spacing
					-- length: +2 for icon size (estimation), +2 for '[]' link brackets
					line:append(format("%s%s", item:icon(14), link), #name + 2 + 2)
					display_block:line(line:build(" "))
				end
			end
			
			aura_env.display = display_block:build("~", { Palette.GRAY })
			return true
		else Item.query(); Log.debug("Item db not ready.") end -- Server has to provide us all item data, retry
	end
	
	local function handle_fcm_hide() return false end
    
    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    
    local function DISABLED_SENTINEL() end -- Function for features which are disabled
    -- Event handler for in-game events
    local event_handler = {
        ["FCM_SHOW"] = handle_fcm_show,
		["FCM_HIDE"] = handle_fcm_hide,
		["ITEM_DATA_LOAD_RESULT"] = Item.cache, -- ITEM_DATA_LOAD_RESULT is inconsistent
		["GET_ITEM_INFO_RECEIVED"] = Item.cache,
    }
    
    -- Entry-point for triggers
    function aura_env.handle(event, ...)
        local handler = event_handler[event]
        if handler then return handler(...) end
    end

	Item.query() -- Begin querying all missing items from the database
end

main() -- Main method

