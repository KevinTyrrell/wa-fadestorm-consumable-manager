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
		local function char_frame_show()
			WeakAuras.ScanEvents("FCM_SHOW")
		end
		
		local function char_frame_hide()
			WeakAuras.ScanEvents("FCM_HIDE")
		end
		
		CharacterFrame:HookScript("OnShow", char_frame_show)
		CharacterFrame:HookScript("OnHide", char_frame_hide)
		
		_G[AURA_LOADED] = true
	end
	
	-- TODO: Move these
	local item_cached, cache_item = C_Item.IsItemDataCachedByID, C_Item.RequestLoadItemDataByID
	
	----------------------------------------------------------------------
	------------------------------- DEBUG --------------------------------
    ----------------------------------------------------------------------
	
	local AURA_NAME = "Fadestorm Consumable Manager"
	
	local Log = (function()
		local function log_msg(level, msg)
			print(format("[%s] %s: %s",
				Palette.LIME(AURA_NAME), Palette.YELLOW(upper(level)), msg))
		end
		
		return setmetatable({ }, {
			__index = function(_, level)
				return function(msg) log_msg(level, msg) end
			end
		})
	end)()
	
	local Type = (function()
		local function type_mismatch(expected, actual)
			Log.error(format("Type Mismatch | Expected=%s, Actual=%s", expected, actual))
		end
	
		local checkers = setmetatable({ }, {
			__index = function(tbl, expected)
				local function f(T, log)
					local actual = type(T)
					if expected == actual then return true end
					if log then type_mismatch(expected, actual) end
					return false
				end
				rawset(tbl, expected, f)
				return f
			end
		})
		
		return setmetatable({ }, {
			__index = function(_, T)
				return checkers[T]
			end
		})
	end)()
	
	-- @param [?] value Value to be typechecked
	-- @param [function] typer Callback provided by Type
	-- @param (optional) [function] defaulter Generator for nil values
	local function check(value, typer, defaulter)
		if value == nil and defaulter ~= nil then			
			Type.function(defaulter, true)
			value = defaulter()
		end
		typer(value, true)
		return value
	end

    ----------------------------------------------------------------------
    -------------------------------- UTILS -------------------------------
    ----------------------------------------------------------------------
	
	local srep, lower, format, upper = string.rep, string.lower, string.format, string.upper
	local max, min, floor = math.max, math.min, math.floor
	local sort, insert, concat = table.sort, table.insert, table.concat
	
	local function empty_table() return { } end
	local function is_empty(t) 
		return next(check(t, Type.table)) == nil end
	
	local function trim(s) 
		check(s, Type.string):match("^%s*(.-)%s*$") end
		
	local function clamp(x, a, b)
		return max(min(check(x, Type.number), check(b, Type.number)), check(a, Type.number))
	end
	
	local function sum(t)
		local s = 0
		for _, n in ipairs(check(t, Type.table)) do
			s = s + check(n, Type.number) end
		return s
	end
	
	local function mapper(tbl, cb)
		Type.function(cb, true)
		local t = { }
		for k, v in pairs(check(tbl, Type.table)) do
			local a, b = cb(k, v)
			-- Allow nil key mappings to be skipped
			if a ~= nil then
				t[a] = b end
		end
		return t
	end
	
	--[[
	-- Tunnels into a table, allowing descending without repetiton
	--
	-- __call() -- Returns the table currently being explored
	-- __index(key) -- Returns the value for current depth, or tunnels if table
	]]--
	local function Tunneler(tbl)
		return setmetatable({ }, {
			__index = function(tunneler, key)
				local value = tbl[check(key, Type.string)]
				if Type.table(value) then
					tbl = value -- Dig one layer
					return tunneler
				end
				return value
			end,
			__call = function() return tbl end
		})
	end
	
	-- @param (optional) [table] static Existing static members of the class
	-- @param (optional) [table] proto Existing instance members of the class
	-- @return [table] Static table used for class methods/functions
	-- @return [table] Instance table used for instance methods
	-- @return [function] Constructor to create instances of the class
	-- @return [table] Instance metatable
	local function Class(static, proto)
		static = check(static, Type.table, empty_table)
		proto = check(proto, Type.table, empty_table)
		local proto_mt = { 
			__index = proto,
			__metatable = false
		}
		
		-- Weak table, values can be garbage collected
		local instances = setmetatable({ }, { __mode = "k" })

		local function new(o)
			local obj = setmetatable(check(o, Type.table, empty_table), mt)
			instances[obj] = true -- Enable tracking of class instances
			return obj
		end
		
		-- @param [table] obj Object instance to check
		-- @return [bool] True if the object is a class instance
		function static.is_instance(obj)
			return instances[check(obj, Type.table)]
		end

		return static, proto, new, mt
	end
	
	-- @param [function] assigner [nil] function(e) where all enum pairs are put in param
	-- @param (optional) [table] static Class table to contain the constants, or nil to create
	-- @return [table] Enum table, or static param if originally provided
	local function Enum(assigner, static)
		static = check(static, Type.table, empty_table)
		local ordinal = 1
		local proxy = setmetatable({ }, {
			__newindex = function(_, key, value)
				rawset(static, key, value)
				rawset(static, ordinal, value)
				ordinal = ordinal + 1
			end
		}
		
		check(assigner, Type.function)(proxy)
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
				r = clamp(floor(check(r, Type.number)), X, Y)
				g = clamp(floor(check(g, Type.number)), X, Y)
				b = clamp(floor(check(b, Type.number)), X, Y)
				a = clamp(floor(check(b, Type.number, default_alpha)), X, Y)
			})
		end
		
		return Color
	end)()
	
	local Palette = {
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
			
		-- Reverse maps to find item object instances
		local by_id, by_name, by_category = { }, { }, { }
		local category_by_item, categories = { }, { }
		
		-- Holds item IDs which have yet to be cached
		local pending_cache_ids = { }
		
		-- @param [table] item Implicit Item instance
		-- @return [string] Category in which the item is classified as
		local function category(item)
			return category_by_item[check(item, Type.table)] end
		
		-- @param [string] item_name Name of the item, case-insensitive
		-- @return [table] Corresponding Item instance, or nil if DNE
		function Item.by_name(item_name)
			return by_name[lower(trim(check(item_name, Type.item)))] end
		
		-- @param [number] item_id In-game ID of the item
		-- @return [table] Corresponding Item instance, or nil if DNE
		function Item.by_id(item_id)
			return by_id[check(item_id, Type.number)] end
		
		-- @param [number] item_id In-game ID of the item
		-- @param (optional) [number] spell_id In-game ID of the self-buff the item applies
		-- @return [table] Item instance
		function Item:new(item_id, spell_id)
			local obj = new({ item_id = check(item_id, Type.number) })
			if spell_id ~= nil then
				obj.spell_id = check(spell_id, Type.number) end
			by_id[item_id] = obj -- Allow reverse lookups
			if not item_cached(item_id) then
				pending_cache_ids[item_id] = true end
			return obj
		end
		
		-- @return [string] Name of the item
		-- @return [string] In-game item hyperlink
		-- @return [string] In-game item icon file path
		function proto:get_info()
			--[[
			-- 01: itemName, 02: itemLink, 03: itemQuality, 04: itemLevel, 05: itemMinLevel, 06: itemType
			-- 07: itemSubType, 08: itemStackCount, 09: itemEquipLoc, 10: itemTexture, 11: sellPrice, 
			-- 12: classID, 13: subclassID, 14: bindType, 15: expacID, 16: setID, 17: isCraftingReagent
			]]--
			local name, link, _, _, _, _, _, _, _, _, texture = GetItemInfo(self.item_id)
			return name, link, texture
		end
		
		-- Retrieves item counts for a specified item using TSM's API
		local function get_tsm_item_counts(item_id)
			local bag_count = GetItemCount(item_id)
			local bank_count = GetItemCount(item_id, true) - bag_count
			return bag_count, bank_count
		end
		
		-- Retrieves item counts for a specified item using WoW's API
		local function get_wow_item_counts(item_id)
			local bag_count = GetItemCount(item_id)
			local total = sum({ TSM_API.GetPlayerTotals("i:" .. tostring(item_id)) })
			return bag_count, total - bag_count
		end
		
		-- Ideally TSM is installed and we can get other character's info
		local get_item_counts = (TSM and TSM_API and TSM_API.GetPlayerTotals)
			and get_tsm_item_counts or get_wow_item_counts
		
		-- @return [number] Quantity of the item in the player's bags
		-- @return [number] Quantity of the item outside of the player's bags
		function proto:get_supply()
			return get_item_counts(self.item_id)
		end
		
		-- Override table for __index reference
		local index_override = {
			category = category
		}
		
		function mt.__index(tbl, key)
			local handler = index_override[key]
			if handler ~= nil then
				return handler(tbl)
			else return rawget(proto, key) end
		end
		
		-- Sorts each category by name & maps names->items
		local function organize_names(items)
			local names = mapper(items, function(_, item)
				local name = lower((GetItemInfo(item)))
				by_name[name] = item
				return item, name
			end)
			sort(items, function(a, b)
				return names[a] < names[b] end)
		end
		
		-- Groups items into categories & enables by_name lookups
		local function build_database()
			setmetatable(by_category, { __index = function() return { } end })
			for i, category in pairs(category_by_item) do
				insert(by_category[category], i)
				insert(categories, category)
			end
			for _, items in pairs(setmetatable(by_category, nil)) do
				organize_names(items) end
			sort(categories)
		end
		
		-- @param [number] item_id In-game Item ID to check if cached, or to cache
		-- @return [bool] true, if Item ID is cached
		function Item.cache(item_id)
			if item_cached(check(item_id, Type.number)) then
				pending_cache_ids[item_ids] = nil
				return true
			end
			cache_item(item_id)
			return false
		end
		
		-- Allows iteration over Item categories
		Item.categories = categories
		
		-- @return [bool] True if the database has all items cached
		Item.ready = (function(strategy)
			strategy = function()
				local iter, tbl, key = pairs(pending_cache_ids)
				local k, v = iter(tbl, nil)
				if k == nil then -- No items remain uncached
					build_database()
					strategy = function() return true end
					return true
				end
				
				repeat -- Loop manually from 2nd pairing
					k, v = iter(tbl, k)
					cache_item(k) -- Request item data from the server
				until k == nil
				return false
			end
			
			return function() return strategy() end
		end)()
		
		for category, items in pairs({ -- Init database
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
		}) do
			for _, item in ipairs(items) do
				category_by_item[category] = item end
		end
		
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
			local aura_id = check(item, Type.table).spell_id
			if aura_id == nil then return self.STABLE end -- No duration => stable
			return severity_by_buff(aura_id, check(prefs, Type.table).low_duration_thresh)
		end
		
		-- Measures the severity of a consumable's remaining supply
		-- If TSM is installed, supply of all your realm characters are considered
		-- If TSM is not installed, supply of only bags and bank are considered
		-- @param [table] item Item instance to check quantity of
		-- @param [table] prefs Preferences instance for req quantities
		-- @return [table] Severity instance, based on available supply
		function Severity:of_quantity(item, prefs)
			local req_quantity = check(prefs, Type.table)
				.quantity_by_item[check(item, Type.table)]
			local bags, elsewhere = item:get_supply()
			if bags >= req_quantity then
				return Severity.STABLE end
			if bags + elsewhere >= req_quantity then
				return Severity.WARNING end
			return Severity.CRITICAL
		end
		
		-- @param [table] status Severity to be applied to the status of the token
		-- @param [table] marker Severity to be applied to the marker of the token
		-- @return [string] Token signifying this severity combination
		function Severity.token(status, marker)
			marker = tostring(marker) -- avoid double-calling tostring
			return format("%s %s %s", marker, status, marker)
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
		-- @param [function] Peforms an evaluation, [bool] function(item)
		-- @return [table] Predicate instance
		function Predicate:new(repr, evaluate)
			return new({
				repr = check(repr, Type.string),
				evaluate = check(evaluate, Type.function)
			})
		end
		
		return Enum(function(e)
			-- Returns true if the player is inside of a dungeon or raid
			e.IN_DUNGEON_RAID = (function()
				local z_types = { party = true, raid = true, scenario = true }
				return function()
					return z_types[(select(2, GetInstanceInfo()))] ~= nil end
			end)(),
			-- Returns true if the player is currently in a city or inn
			e.IN_RESTED_AREA = IsResting,
			-- Returns true if the specified item has buffing capability
			e.ITEM_YIELDS_BUFF = function(item)
				return check(item, Type.table).spell_id ~= nil end,
			-- Returns true if at least one of the item is in the player's inventory
			e.ITEM_IN_INVENTORY = function(item)
				return GetItemCount(check(item, Type.table).item_id) > 0 end,
		end, Predicate)
	end)()
	
	-- Predicate wrapper
	local Condition = (function()
		local Condition, proto, new, mt = Class()
		-- Call predicate, pass in item param, negate output if applicable
		mt.__call = function(tbl, ...) return tbl.pred(...) ^ tbl.negate end
		
		-- @param [table] pred Predicate instance
		-- @param [bool] negate True to negate the predicate
		-- @return [table] Condition instance
		function Condition:new(pred, negate)
			return new({
				pred = check(pred, Type.table),
				negate = check(negate, Type.function)
			})
		
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
			return new({ conditions = check(conditions, Type.table) })
		
		-- @param [table] rules List of rule instances to evaluate
		-- @param [varargs] ... Params to be passed into each rule
		-- @return [bool] True if all rules are passing
		function Rule.all_passing(rules, ...)
			for _, rule in ipairs(check(rules, Type.table)) do
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
				lines_by_header = setmetatable({ }, {
					__index = empty_table
				}),
				longest = 0
			})
		end
		
		local function line_helper(tbl, str, length, dx, target)
			Type.string(str, true)
			if length == nil then
				length = #str
			else Type.number(length) end
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
			local header_colors = colors_by_header(self, check(color_filter, Type.table))
			local block_width = self.longest
			local block = { }
			for _, header in ipairs(self.header) do
				local lines = self.lines_by_header[header]
				header = header_colors[header](header)
				insert(block, build_header(header, block_width, "~"))
			end
			return concat(block, "\n")
		end
		
		function Text.inline_icon(texture, width)
			return format("|T%s:%d:%d|t", texture, width, width) end
		
		return Text
	end)()

    ----------------------------------------------------------------------
    --------------------------- EVENT HANDLERS  --------------------------
    ----------------------------------------------------------------------
	
	local function handle_fcm_show()
		if Item.ready() then -- Ensure all item are cached
			local prefs = Preference:get()
			local items = prefs:filter_items()
			if is_empty(items) then return end -- User has no items to display
			
			local block = Text:new()
			print("Testing Run.")
		end
	end
	
	local function handle_fcm_hide()
		return false
	end
	
	-- Receives cached item information
	local function handle_item_data(item_id, success)
		if success then 
			Item.cache(item_id)
		elseif not Item.cache(item_id) then
			Log.warn("failed to query item ID: " .. tostring(item_id))
		end
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

