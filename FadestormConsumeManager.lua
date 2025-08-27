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
	local item_cached, cache_item = C_Item.IsItemDataCachedByID, C_Item.RequestLoadItemDataByID
		local srep, lower, format, upper = string.rep, string.lower, string.format, string.upper
	local max, min, floor = math.max, math.min, math.floor
	local sort, insert, concat = table.sort, table.insert, table.concat

	local Palette, Log -- Forward declaration
	
	----------------------------------------------------------------------
	------------------------------- DEBUG --------------------------------
    ----------------------------------------------------------------------
	
	local AURA_NAME = "Fadestorm Consumable Manager"

	local function type_mismatch(expected, actual)
		error(Log.error(format(
			"Type Mismatch | Expected=%s, Actual=%s", expected, actual)))
	end

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

	local function table_fn() return { } end
	local function true_fn() return true end
	local function nil_fn() return end
	local function is_empty(t) return next(Type.TABLE(t)) == nil end

	local function trim(s) 
		Type.STRING(s):match("^%s*(.-)%s*$") end

	local function clamp(x, a, b)
		return max(min(Type.NUMBER(x), Type.NUMBER(b)), Type.NUMBER(a)) end

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

	-- @param [...] return values from ipairs or pairs
	-- @param [function] callback: [boolean] function(key, value)
	-- @return [table] filtered table values
	local function filter(iter, state, key, callback)
		Type.FUNCTION(callback)
		local t = { }
		for k, v in iter, state, key do
			if callback(k, v) == true then
				t[k] = v end end
		return t
	end

	-- @param [...] return values from ipairs or pairs
	-- @param [function] callback: [k, v] function(key, value)
	-- @return [table] mapped table values
	local function mapper(iter, state, key, callback)
		Type.FUNCTION(callback)
		local t = { }
		for k, v in iter, state, key do
			local a, b = callback(k, v)
			if a ~= nil then t[a] = b end end
		return t
	end

	-- @param [...] return values from ipairs or pairs
	-- @param [function] callback: [?] function(key, value)
	-- @return [table] Map[group, Map[key, value]]
	local function grouper(iter, state, key, callback)
		Type.FUNCTION(callback)
		local groups = default_table(table_fn)
		for k, v in iter, state, key do
			local grp = callback(k, v)
			if grp ~= nil then -- Skip groups that evaluate to nil
				groups[grp][k] = v end
		end
		return setmetatable(groups)
	end
	
	-- Allows iteration over a table without exposing the underlying table
	local function iter(iter, state, key)
		if state == nil then return nil_fn end
		local function iterator(_, k)
			return iter(state, k) end
		return iterator, nil, key
	end
	
	local function sum(t)
		local s = 0
		for _, n in ipairs(Type.TABLE(t)) do
			s = s + Type.NUMBER(n) end
		return s
	end
	
	--[[
	-- Tunnels into a table, allowing descending without repetiton
	--
	-- __call() -- Returns the table currently being explored
	-- __index(key) -- Returns the value for current depth, or tunnels if table
	]]--
	local function Tunneler(tbl)
		local proxy = stringify_keys_table(function(key)
			local value = tbl[key]
			if check.TABLE(value) then
				tbl = value
				return proxy
			end
			return value
		end)
		getmetatable(proxy).__call = function() return tbl end
		return proxy
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
		local proxy = index(function(key, value)
			rawset(static, key, value)
			rawset(static, ordinal, value)
			ordinal = ordinal + 1
		end)
		Type.FUNCTION(assigner)(proxy)
		return static
	end

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
    -------------------------------- MODEL -------------------------------
    ----------------------------------------------------------------------
	
	local Item = (function()
		local Item, proto, new, mt = Class()
		
		local by_category = { } -- Map[Item, SortedList[Item]]
		local by_id = { } -- Map[item_id, Item]
		local by_name = { } -- Map[item_name, Item]
		local category_by_item = { } -- Map[Item, category]
		local categories = { } -- SortedList[category]
		
		-- Holds item IDs which have yet to be cached
		local pending_by_id = { }
		
		-- @param [string] item_name Name of the item, case-insensitive
		-- @return [table] Corresponding Item instance, or nil if DNE
		function Item.by_name(item_name)
			return by_name[lower(trim(Type.STRING(item_name)))] end
		
		-- @param [number] item_id In-game ID of the item
		-- @return [table] Corresponding Item instance, or nil if DNE
		function Item.by_id(item_id) return by_id[Type.NUMBER(item_id)] end

		-- @param [number] item_id In-game Item ID to ensure is cached
		function Item.cache(item_id)
			if item_cached(Type.NUMBER(item_id)) then
				pending_by_id[item_id] = nil
			else cache_item(item_id) end
		end

		-- Retrieves an iterator of all items for the category
		-- @param [string] category Category name
		function Item.by_category(category)
			return iter(ipairs(by_category[Type.STRING(category)])) end
		
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

		-- @return [string] Name of the item
		-- @return [string] In-game item hyperlink
		-- @return [string] In-game item icon file path
		-- @return [boolean] True if the item is soulbound
		function proto:get_info()
			--[[
			-- 01: itemName, 02: itemLink, 03: itemQuality, 04: itemLevel, 05: itemMinLevel, 06: itemType
			-- 07: itemSubType, 08: itemStackCount, 09: itemEquipLoc, 10: itemTexture, 11: sellPrice, 
			-- 12: classID, 13: subclassID, 14: bindType, 15: expacID, 16: setID, 17: isCraftingReagent
			]]--
			local name, link, _, _, _, _, _, _, _, _, texture, _, _, _, bound = GetItemInfo(self.item_id)
			return name, link, texture, bound
		end

		-- @return [string] Category in which classifies the item
		function proto:category() return category_by_item[self] end

		-- Collects names of all items in the database and alphabetizes items
		local function process_database()
			--[[for item in pairs(by_category) do
				by_name[lower((GetItemInfo(item.item_id)))] = item end]]--
			for _, item in pairs(by_id) do
				local name = (GetItemInfo(item.item_id))
				name = lower(name)
				by_name[name] = item
				
				--by_name[lower((GetItemInfo(item.item_id)))] = item 
			end
			for _, items in pairs(by_category) do
				sort(items, function(k, v)
					return (GetItemInfo(k.item_id)) < (GetItemInfo(v.item_id)) end) end
		end
		
		-- @return [boolean] True if the database has all items cached
		Item.ready = (function(strategy) -- Abusing param as a local
			strategy = function()
				-- All items are cached, complete database
				if is_empty(pending_by_id) then
					process_database()
					strategy = true_fn
					return true
				end

				for item_id in pairs(pending_by_id) do
					cache_item(item_id) end
				return false
			end
			
			return function() return strategy() end
		end)()

		local function init_database()
			local item_dump = {
				["Flask"] = {
					Item:new(13510, 17626), -- Flask of the Titans
					Item:new(13511, 17627), -- Flask of Distilled Wisdom
					Item:new(13512, 17628), -- Flask of Supreme Power
					Item:new(13513, 17629), -- Flask of Chromatic Resistance
					Item:new(13506), -- Flask of Petrification
				},
				["Protection"] = {
					Item:new(13461, 17549), -- Greater Arcane Protection Potion
					Item:new(13457, 17543), -- Greater Fire Protection Potion
					Item:new(13456, 17544), -- Greater Frost Protection Potion
					Item:new(13458, 17546), -- Greater Nature Protection Potion
					Item:new(13459, 17548), -- Greater Shadow Protetion Potion
					Item:new(13460, 17545), -- Greater Holy Protection Potion
					Item:new(6052), -- Nature Protection Potion
					Item:new(6050), -- Frost Protection Potion
					Item:new(6049), -- Fire Protection Potion
					Item:new(6048), -- Shadow Protection Potion
					Item:new(6051), -- Holy Protection Potion
					Item:new(4376), -- Flame Deflector
					Item:new(4386), -- Ice Deflector
				},
				["Elixir"] = {
					Item:new(13445, 11348), -- Elixir of Superior Defense
					Item:new(20004, 24361), -- Major Troll's Blood Potion
					Item:new(3825, 3593), -- Elixir of Fortitude
					Item:new(13452, 17538), -- Elixir of the Mongoose
					Item:new(20007, 24363), -- Mageblood Potion
					Item:new(9206, 11405), -- Elixir of Giants
					Item:new(12820, 17038), -- Winterfall Firewater
					Item:new(9088, 11371), -- Gift of Arthas
					Item:new(13454, 17539), -- Greater Arcane Elixir
					Item:new(9264, 11474), -- Elixir of Shadow Power
					Item:new(21546, 26276), -- Elixir of Greater Firepower
					Item:new(17708, 21920), -- Elixir of Frost Power
					Item:new(1177, 673), -- Oil of Olaf
					Item:new(23211, 29334), -- Toasted Smorc
					Item:new(23326, 29333), -- Midsummer Sausage
					Item:new(23435, 29335), -- Elderberry Pie
					Item:new(23327, 29332), -- Fire-toasted Bun
					Item:new(22239, 27722), -- Sweet Surprise
					Item:new(22237, 27723), -- Dark Desire
					Item:new(22236, 27720), -- Buttermilk Delight
					Item:new(22238, 27721), -- Very Berry Cream
				},
				["Juju"] = {
					Item:new(12457, 16325), -- Juju Chill
					Item:new(12460, 16329), -- Juju Might
					Item:new(12450), -- Juju Flurry
					Item:new(12459), -- Juju Escape
					Item:new(12455, 16326), -- Juju Ember
					Item:new(12458, 16327), -- Juju Guile
					Item:new(12451, 16323), -- Juju Power
				},
				["Combat"] = {
					Item:new(13446), -- Major Healing Potion
					Item:new(13444), -- Major Mana Potion
					Item:new(18253), -- Major Rejuvenation Potion
					Item:new(9144), -- Wildvine Potion
					Item:new(18841), -- Combat Mana Potion
					Item:new(13443), -- Superior Mana Potion
					Item:new(13442), -- Mighty Rage Potion
					Item:new(3387), -- Limited Invulnerability Potion
					Item:new(5634), -- Free Action Potion
					Item:new(20008), -- Living Action Potion
					Item:new(20520), -- Dark Rune
					Item:new(12662), -- Demonic Rune
					Item:new(11952), -- Night Dragon's Breath
					Item:new(11951), -- Whipper Root Tuber
					Item:new(7676), -- Thistle Tea
					Item:new(16023), -- Masterwork Target Dummy
					Item:new(4392), -- Advanced Target Dummy
					Item:new(14530), -- Heavy Runecloth Bandage
					Item:new(1322), -- Fishliver Oil
					Item:new(2459), -- Swiftness Potion
					Item:new(13455, 17540), -- Greater Stoneshield Potion
					Item:new(20002), -- Greater Dreamless Sleep Potion
					Item:new(12190), -- Dreamless Sleep Potion
				},
				["Cleanse"] = {
					Item:new(3386), -- Elixir of Poison Resistance
					Item:new(19440), -- Powerful Anti-Venom
					Item:new(2633), -- Jungle Remedy
					Item:new(6452), -- Anti-Venom
					Item:new(6453), -- Strong Anti-Venom
					Item:new(9030), -- Restorative Potion
					Item:new(9322), -- Undamaged Venom Sac
					Item:new(13462), -- Purification Potion
					Item:new(19183), -- Hourglass Sand
				},
				["Un'goro"] = {
					Item:new(11567, 15279), -- Crystal Spire
					Item:new(11563, 15231), -- Crystal Force
					Item:new(11566), -- Crystal Charge
					Item:new(11562), -- Crystal Restore
					Item:new(11564, 15233), -- Crystal Ward
					Item:new(11565), -- Crystal Yield
				},
				["Misc"] = {
					Item:new(5206, 5665), -- Bogling Root
					Item:new(18297), -- Thornling Seed
					Item:new(8529), -- Noggenfogger Elixir
					Item:new(9172), -- Invisibility Potion
					Item:new(3823), -- Lesser Invisibility Potion
					Item:new(6372), -- Swim Speed Potion
					Item:new(21519), -- Mistletoe
					Item:new(184937), -- Chronoboon Displacer
					Item:new(12384), -- Cache of Mau'ari
					Item:new(21321), -- Red Qiraji Resonating Crystal
					Item:new(21324), -- Yellow Qiraji Resonating Crystal
					Item:new(21323), -- Green Qiraji Resonating Crystal
					Item:new(21218), -- Blue Qiraji Resonating Crystal
					Item:new(22754), -- Eternal Quintessence
					Item:new(17333), -- Aqual Quintessence
				},
				["Enhancement"] = {
					Item:new(3829), -- Frost Oil
					Item:new(3824), -- Shadow Oil
					Item:new(20749), -- Brilliant Wizard Oil
					Item:new(20748), -- Brilliant Mana Oil
					Item:new(23123), -- Blessed Wizard Oil
					Item:new(23122), -- Consecrated Sharpening Stone
					Item:new(18262), -- Elemental Sharpening Stone
					Item:new(12404), -- Dense Sharpening Stone
					Item:new(12643), -- Dense Weightstone
				},
				["Explosive"] = {
					Item:new(8956), -- Oil of Immolation
					Item:new(13180), -- Stratholme Holy Water
					Item:new(10646), -- Goblin Sapper Charge
					Item:new(18641), -- Dense Dynamite
					Item:new(15993), -- Thorium Grenade
					Item:new(4390), -- Iron Grenade
					Item:new(16040), -- Arcane Bomb
				},
				["Unique"] = {
					Item:new(8410, 10667), -- R.O.I.D.S.
					Item:new(8412, 10669), -- Ground Scorpok Assay
					Item:new(8423, 10692), -- Cerebral Cortex Compound
					Item:new(8424, 10693), -- Gizzard Gum
					Item:new(8411, 10668), -- Lung Juice Cocktail
					Item:new(20079, 24382), -- Spirit of Zanza
					Item:new(20080, 24417), -- Sheen of Zanza
					Item:new(20081, 24383), -- Swiftness of Zanza
					Item:new(184938), -- Supercharged Chronoboon Displacer
				},
				["Ammo"] = {
					Item:new(12654), -- Doomshot
					Item:new(13377), -- Miniature Cannon Balls
					Item:new(11630), -- Rockshard Pellets
					Item:new(19316), -- Ice Threaded Arrow
					Item:new(19317), -- Ice Threaded Bullet
					Item:new(18042), -- Thorium Headed Arrow
					Item:new(15997), -- Thorium Shells
				},
				["Food"] = {
					Item:new(13928, 18192), -- Grilled Squid
					Item:new(20452, 24799), -- Smoked Desert Dumplings
					Item:new(13931, 18194), -- Nightfin Soup
					Item:new(18254, 22730), -- Runn Tum Tuber Surprise
					Item:new(21023, 25661), -- Dirge's Kickin' Chimaerok Chops
					Item:new(13813, 18141), -- Blessed Sunfruit Juice
					Item:new(13810, 18125), -- Blessed Sunfruit
					Item:new(18284, 22790), -- Kreeg's Stout Beatdown
					Item:new(18269, 22789), -- Gordok Green Grog
					Item:new(21151, 25804), -- Rumsey Rum Black Label
					Item:new(13724), -- Enriched Manna Biscuit
					Item:new(19301), -- Alterac Manna Biscuit
				},
				["Equipment"] = {
					Item:new(15138), -- Onyxia Scale Cloak
					Item:new(16309), -- Drakefire Amulet
					Item:new(810), -- Hammer of the Northern Wind
					Item:new(10761), -- Coldrage Dagger
				}
			}
			for category, items in pairs(item_dump) do
				by_category[category] = items
				for _, item in ipairs(items) do
					category_by_item[category] = item end
				insert(categories, category)
			end
			sort(categories, function(k, v) return k < v end)
		end
		
		init_database()
		return Item
	end)()
	
	local Severity = (function()
		local Symbol = (function()
			local function repr() return self.color(self.code) end
			local symbol_mt = { __call = repr, __tostring = repr }
			return function(code, color)
				return setmetatable({ code = code, color = color }, symbol_mt)
			end
		end)
		
		local function make_severity(status, marker)
			return { status = status, marker = marker } end
		
		local Severity = {
			STABLE = make_severity(Symbol("OK", Palette.GREEN), Symbol("--", Palette.WHITE)),
			WARNING = make_severity(Symbol("+?", Palette.YELLOW), Symbol("<<", Palette.CORAL)),
			CRITICAL = make_severity(Symbol("NO", Palette.RED), Symbol(">>", Palette.ORANGE))
		}
		
		local function severity_by_buff(aura_id, low_duration_thresh)
			local _, _, _, _, duration, expire_ts = WA_GetUnitBuff(PLAYER, aura_id)
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
			return severity_by_buff(aura_id, Type.TABLE(prefs).low_duration_thresh)
		end
		
		-- Measures the severity of a consumable's remaining supply
		-- If TSM is installed, supply of all your realm characters are considered
		-- If TSM is not installed, supply of only bags and bank are considered
		-- @param [table] item Item instance to check quantity of
		-- @param [table] prefs Preferences instance for req quantities
		-- @return [table] Severity instance, based on available supply
		function Severity:of_quantity(item, prefs)
			local quantities = Type.TABLE(prefs).quantity_by_item
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
	local Predicate = (function()
		local Predicate, proto, new, mt = Class()
		mt.__call = function(tbl, ...) return tbl.evaluate(...) end
		mt.__tostring = function(tbl) return tbl.repr end
		
		-- @param [string] repr String representation of the predicate
		-- @param [function] Peforms an evaluation, [boolean] function(item)
		-- @return [table] Predicate instance
		function Predicate:new(repr, evaluate)
			return new({
				repr = Type.STRING(repr),
				evaluate = Type.FUNCTION(evaluate)
			})
		end
		
		return Enum(function(e)
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
		end, Predicate)
	end)()
	
	-- Predicate wrapper
	local Condition = (function()
		local Condition, proto, new, mt = Class()
		-- Call predicate, pass in item param, negate output if applicable
		mt.__call = function(tbl, ...) return tbl.pred(...) ^ tbl.negate end
		
		-- @param [table] pred Predicate instance
		-- @param [boolean] negate True to negate the predicate
		-- @return [table] Condition instance
		function Condition:new(pred, negate)
			return new({
				pred = Type.TABLE(pred),
				negate = Type.BOOLEAN(negate)
			})
		end
		
		return Condition
	end)()
	
	local Rule = (function()
		local Rule, proto, new, mt = Class()
		mt.__call = function(tbl, ...)
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
		-- @return [boolean] True if all rules are passing
		function Rule.all_passing(rules, ...)
			for _, rule in ipairs(Type.TABLE(rules)) do
				if rule(...) ~= true then return false end end
			return true
		end
		
		return Rule
	end)()
	
	----------------------------------------------------------------------
    --------------------------- CUSTOM OPTIONS ---------------------------
    ----------------------------------------------------------------------
	
	local Preference = (function()
		local Preference, proto, new, mt = Class()
		
		local function load_low_duration()
			return aura_env.config.options.low_duration_thresh / 100 end
			
		local function load_item_quantities()
			local quantity_by_item = { }
			local profile = select(2, next(aura_env.config.profiles))
			if profile ~= nil then
				for _, grp in ipairs(profile.consumes) do
					local name = lower(trim(grp.consume_name))
					local item = Item.by_name(name)
					if item ~= nil then
						quantity_by_item[item] = grp.req_quantity
					else Log.info("User Config | Consumable DNE: " .. name) end
				end
			end
			return quantity_by_item
		end
		
		local function load_rules()
			local rules = { }
			local tunnel = Tunneler(aura_env.config.options.rules)
			for _, rule_grp in ipairs(tunnel()) do
				if rule_grp.enable then -- Rule is active
					local conds = { }
					for _, pred_grp in ipairs(tunnel.predicates()) do
						local dropdown = Predicate[pred_grp.condition]
						insert(conds, Condition:new(dropdown, pred_grp.negate))
					end
					insert(rules, Rule:new(conds))
				end
			end
			return rules
		end
		
		-- low_duration_thresh: %max duration to be considered 'low duration'
		function Preference:new()
			return new({
				low_duration = load_low_duration(),
				quantity_by_item = load_item_quantities(),
				rules = load_rules()
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
			local items = { }
			local rules = self.rules
			for item in pairs(self.quantity_by_item) do
				if Rule.all_passing(rules, item) then
					insert(items, item) end end -- Item is allowed by user
			sort(items, function(a, b) return a:info() < b:info() end)
			return items
		end
		
		return Preference
	end)()
	
    ----------------------------------------------------------------------
	------------------------------ DISPLAY -------------------------------
    ----------------------------------------------------------------------
	
	local Text = (function()
		local Text, proto, new, mt = Class()
		
		function Text:new()
			return new({
				headers = { },
				lines_by_header = default_table(table_fn),
				longest = 0
			})
		end
		
		local function line_helper(tbl, str, length, dx, target)
			Type.STRING(str)
			if length == nil then
				length = #str
			else Type.NUMBER(length) end
			tbl.longest = max(tbl.longest, length + dx)
			insert(target, str)
		end
		
		-- @param [string] title Centered text of this header
		-- @param (optional) [number] length Override for the text length
		-- @return [table] Builder instance
		function proto:header(title, length)
			line_helper(self, title, length, 2, self.headers)
			self.current = title
			return self
		end
		
		-- @param [string] line Text which is housed under the header
		-- @param (optional) [number] length Override for the text length
		-- @return [table] Builder instance
		function proto:line(line, length)
			line_helper(self, line, length, 0, self.lines_by_header[self.current])
			return self
		end
		
		-- TODO: flagged for refactoring
		-- Assigns a unique color to each header, with filter support
		local function colors_by_header(instance, color_filter)
			local filter = mapper(color_filter, function(_, c) return c, true end) -- Set
			local color_keys = { }
			for k, v in pairs(Palette) do
				if filter[v] == nil then -- Color is allowed
					insert(color_keys, k) end end
			local num_headers = #instance.headers
			-- Possible not enough colors left, failsafe protection
			for i = 1, num_headers - #color_keys do
				insert(color_keys, (next(Palette))) end
			sort(color_keys) -- Sorted colors gives output a more predictable look
			local color_map = { }
			for i = 1, num_headers do
				color_map[instance.headers[i]] = Palette[color_keys[i]] end
			return color_map
		end
		
		local function build_header(title, length, char)
			if title == nil then return srep(char, length) end
			title = trim(title)
			if title == "" then return srep(char, length) end
			local t_len = #title + 2
			local s_len = (length - t_len) / 2
			local s_lenf = floor(s_len)
			local section = srep(char, s_lenf)
			if s_len == s_lenf then
				return format("%s %s %s", section, title, section) end
			return format("%s %s %s%s", section, title, section, char)
		end
		
		-- @param [table] color_filter List of header colors which should not be used
		-- @return [string] Built text block
		function proto:build(color_filter)
			local header_colors = colors_by_header(self, Type.TABLE(color_filter))
			local block_width = self.longest
			local block = { }
			for _, header in ipairs(self.header) do
				local lines = self.lines_by_header[header]
				header = header_colors[header](header)
				insert(block, build_header(header, block_width, "~"))
			end
			return concat(block, "\n")
		end
		
		-- @param [string] texture Texture to be converted into an in-line string
		-- @param [number] width Width of the icon in the in-line string
		function Text.inline_icon(texture, width)
			return format("|T%s:%d:%d|t", Type.STRING(texture), Type.NUMBER(width), width)
		end
		
		return Text
	end)()

    ----------------------------------------------------------------------
    --------------------------- EVENT HANDLERS  --------------------------
    ----------------------------------------------------------------------
	
	local function handle_fcm_show()
		if Item.ready() then -- Ensure all item are cached
			local prefs = Preference:get()
			local items = prefs:filter_items()
			--if is_empty(items) then return end -- User has no items to display
			
			local block = Text:new()
			print("Testing Run.")
		end
	end
	
	local function handle_fcm_hide()
		return false
	end
	
	-- Receives cached item information
	local function handle_item_data(item_id, success)
		Item.cache(item_id)
		if success ~= true then
			Log.warn(format("server data failed for item ID: %d", item_id)) end
	end
    
    ----------------------------------------------------------------------
    ----------------------------------------------------------------------
    
    local function DISABLED_SENTINEL() end -- Function for features which are disabled
    -- Event handler for in-game events
    local event_handler = {
        ["FCM_SHOW"] = handle_fcm_show,
		["FCM_HIDE"] = handle_fcm_hide,
		["ITEM_DATA_LOAD_RESULT"] = handle_item_data,
    }
    
    -- Entry-point for triggers
    function aura_env.handle(event, ...)
        local handler = event_handler[event]
        if handler then return handler(...) end
    end
end

main() -- Main method

