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

	-- Avoid loading the aura twice at all costs
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
	
	local item_cached, cache_item = C_Item.IsItemDataCachedByID, C_Item.RequestLoadItemDataByID

    ----------------------------------------------------------------------
    -------------------------------- UTILS -------------------------------
    ----------------------------------------------------------------------

	local s_duplicate, lower, format, upper = string.rep, string.lower, string.format, string.upper
	local max, min, floor = math.max, math.min, math.floor
	local sort, insert, concat = table.sort, table.insert, table.concat
	
	local function trim(s)
		return s:match("^%s*(.-)%s*$")
	end
	
	local function copy(tbl)
		local t = { }
		for k, v in pairs(tbl) do
			t[k] = v end
		return t
	end
	
	local function clamp(x, a, b)
		return max(min(x, b), a)
	end
	
	local function mapper(tbl, cb)
		local t = { }
		for k, v in pairs(tbl) do
			local a, b = cb(k, v)
			-- Allow nil key mappings to be skipped
			if a ~= nil then
				t[a] = b end
		end
		return t
	end
	
	local function grouper(tbl, cb)
		local buckets = { }
		for k, v in pairs(tbl) do
			local key = cb(k, v)
			local bucket = buckets[key]
			if bucket == nil then
				bucket = { }
				buckets[key] = bucket
			end
		
			bucket[k] = v
		end
		
		return buckets
	end
	
	local function sorter(tbl, cb)
		local relations = { }
		local keys = { }
		for k, v in pairs(tbl) do
			local key = cb(k, v)
			relations[key] = k
			insert(keys, key)
		end
		
		sort(keys)
		return mapper(keys, function(i, e)
			return i, relations[e]
		end)
	end
	
	local function sum(t)
		local s = 0
		for _, e in ipairs(t) do
			s = s + e
		end
		return s
	end
	
	local function Class()
		local cls = { }
		cls.__index = cls
		return setmetatable({ }, cls), cls
	end
	
	----------------------------------------------------------------------
	------------------------------- DEBUG --------------------------------
    ----------------------------------------------------------------------

	-- Color class for coloring text
	local Color = (function()
		local cls = { }
		cls.__index = cls

		local X, Y = 0, 255

		local function to_hex_code(c)
			return format("%02x", clamp(c, X, Y))
		end

		function cls:__tostring()
			return format("Color(%d, %d, %d, %d)", self.r, self.g, self.b, self.a)
		end

		function cls:HexCode()
			return "ff" .. to_hex_code(self.r) .. to_hex_code(self.g) .. to_hex_code(self.b)
		end

		function cls:__call(text)
			return "|c" .. self:HexCode() .. text .. "|r"
		end

		function cls.new(r, g, b, a)
			return setmetatable({
				r = r ~= nil and clamp(r, X, Y) or Y,
				g = g ~= nil and clamp(g, X, Y) or Y,
				b = b ~= nil and clamp(b, X, Y) or Y,
				a = a ~= nil and clamp(a, X, Y) or Y,
			}, cls)
		end

		return setmetatable({ }, cls)
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
		-- Removed colors, poor display on black BG
		--BROWN = Color.new(139, 69, 19),
		--BLUE = Color.new(0, 0, 255),
		--BLACK = Color.new(0, 0, 0),
		--TEAL = Color.new(0, 128, 128),
		--NAVY = Color.new(0, 0, 128),
		--MAROON = Color.new(128, 0, 0),
		--OLIVE = Color.new(128, 128, 0),
	}
	
	local AURA_NAME = "Fadestorm Consumable Manager"
	
	local Log = (function()
		local cls = { }
		
		local function log_msg(level, msg)
			print(format("[%s] %s: %s",
				Palette.LIME(AURA_NAME), Palette.YELLOW(upper(level)), msg))
		end
		
		return setmetatable(cls, {
			__index = function(_, level)
				return function(msg)
					log_msg(level, msg) end
			end
		})
	end)()
	
	----------------------------------------------------------------------
    --------------------------- CUSTOM OPTIONS ---------------------------
    ----------------------------------------------------------------------
	
	local function init_consume_config()
		local quantity_by_name = { }
		local _, active = next(aura_env.config.profiles)
		if active ~= nil then
			local consumes = active.consumes
			for _, e in ipairs(consumes) do
				local name = lower(trim(e.consume_name))
				local quantity = e.req_quantity
				quantity_by_name[name] = quantity
			end
		end
		return quantity_by_name
	end
	
	-- Map of [consume_name -> quantity_desired]
	local quantity_by_name = init_consume_config()
	
	-- Percentage of max duration in which auras are considered low duration
	local low_duration_thresh = aura_env.config.options.low_duration_thresh / 100
	
    ----------------------------------------------------------------------
    -------------------------------- MODEL -------------------------------
    ----------------------------------------------------------------------
	
	local Item = (function()
		local Item = { }
		local mt = { }
		
		-- Reverse maps to find item object instances
		local by_id, by_name, by_category = { }, { }, { }
		local category_by_item, categories = { }, { }
		
		-- Holds item IDs which have yet to be cached
		local pending_cache_ids = { }
		
		-- @param [table] self Implicit Item instance
		-- @return [str] Category in which the item is classified as
		local function category(self)
			return category_by_item[self]
		end
		
		-- @param [str] item_name Name of the item, case-insensitive
		-- @return [table] Corresponding Item instance, or nil
		function Item.by_name(item_name)
			return by_name[lower(trim(item_name))] end
		
		-- @param [int] item_id In-game ID of the item
		-- @return [table] Corresponding Item instance, or nil
		function Item.by_id(item_id)
			return by_id[item_id] end
		
		-- @param [int] item_id In-game ID of the item
		-- @param (optional) [int] spell_id In-game ID of the self-buff the item applies
		-- @return [table] Item instance
		function Item:new(item_id, spell_id)
			local obj = { item_id = item_id, spell_id = spell_id }
			by_id[item_id] = obj -- Allow reverse lookups
			if not item_cached(item_id) then
				pending_cache_ids[item_id] = true end
			return setmetatable(obj, mt)
		end
		
		-- @return [string] Name of the item
		-- @return [string] In-game item hyperlink
		-- @return [string] In-game item icon file path
		function Item:get_info()
			--[[
			-- 01: itemName, 02: itemLink, 03: itemQuality, 04: itemLevel, 05: itemMinLevel, 06: itemType
			-- 07: itemSubType, 08: itemStackCount, 09: itemEquipLoc, 10: itemTexture, 11: sellPrice, 
			-- 12: classID, 13: subclassID, 14: bindType, 15: expacID, 16: setID, 17: isCraftingReagent
			]]--
			local name, link, _, _, _, _, _, _, _, _, texture = GetItemInfo()
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
		
		-- @return [int] Quantity of the item in the player's bags
		-- @return [int] Quantity of the item outside of the player's bags
		function Item:get_counts()
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
			else return Item[key] end
		end
		
		-- Sorts each category by name & maps names->items
		local function organize_names(items)
			local names = mapper(items, function(_, i)
				local name = lower((GetItemInfo(i)))
				by_name[name] = i
				return i, name
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
		
		-- @param [int] item_id In-game Item ID to check if cached, or to cache
		-- @return [bool] true, if Item ID is cached
		function Item.cache(item_id)
			if item_cached(item_id) then
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
			for _, i in ipairs(items) do
				category_by_item[category] = i end
		end
		
		return Item
	end)()
	
	local Text = (function()
		local Text = { }
		
		-- @param [str] title Title of the header
		-- @param [int] length Total length of the header
		-- @param [str] char Border character to be repeated
		-- @return [str] Formatted header
		function Text.header(title, length, char)
			if title == nil then return s_duplicate(char, length) end
			title = trim(title)
			if title == "" then return s_duplicate(char, length) end
			local t_len = #title + 2
			local s_len = (length - t_len) / 2
			local s_lenf = floor(s_len)
			local section = s_duplicate(char, s_lenf)
			if s_len == s_lenf then
				return format("%s %s %s", section, title, section) end
			return format("%s %s %s%s", section, title, section, char)
		end
	end)()
	
	-- Display for when item information is pending from the server
	local PENDING_TEXT_DISPLAY = (function()
		local divider = build_header()
		local pending = build_header("\(Waiting for Item IDs\)")
		local refresh = build_header("Refresh Character Pane")
		return divider .. "\n" .. pending .. "\n" .. refresh .. "\n" .. divider
	end)()
	
	-- Map of [tag -> color]
	local colors_by_tag = (function()
		local c, keys, paired, i = copy(Palette), { }, { }, 0
		-- Colors which should never be used for tag colors
		local reserved = { "YELLOW", "CORAL", "GREEN", "WHITE", "RED", "ORANGE" }
		for _, e in ipairs(reserved) do c[reserved] = nil end
		
		for e in pairs(c) do
			insert(keys, e) end
		sort(keys)
		
		for tag in pairs(CONSUMABLE_IDS) do
			i = i + 1
			paired[tag] = c[keys[i]]
		end
		
		return paired
	end)()
	
	local function texture_to_icon(texture, width)
		return format("|T%s:%d:%d|t", texture, width, width)
	end
	
	-- Token string to represent different states of a conusmable
	local Token = (function()
		local Token = { }
	
		-- Colored component of a status marker
		local Symbol = (function()
			local Symbol = Class()

			function Symbol:new(code, color)
				local obj = setmetatable({ }, self)
				obj.code = code
				obj.color = color
				return obj
			end
			
			function Symbol:__call()
				return self.color(self.code)
			end
			
			function Symbol:__tostring()
				return self.color(self.code)
			end
			
			return Symbol
		end)()
		
		Token.Severity = {
			WARNING = {
				status = Symbol:new("+?", Palette.YELLOW),
				marker = Symbol:new("<<", Palette.CORAL),
			},
			STABLE = {
				status = Symbol:new("OK", Palette.GREEN),
				marker = Symbol:new("--", Palette.WHITE),
			},
			CRITICAL = {
				status = Symbol:new("NO", Palette.RED),
				marker = Symbol:new(">>", Palette.ORANGE),
			}
		}
		
		function Token.build(status, marker)
			local s = status.status()
			local m = marker.marker()
			return format("%s %s %s", m, s, m)
		end
		
		return Token
	end)()
	
	-- Determines a consumable aura's severity by remaining duration
	local function severity_by_buff(aura_id)
		local _, _, _, _, duration, expire_ts = WA_GetUnitBuff(PLAYER, aura_id)
		-- Aura could not be found on the player's buffs
		if duration == nil then return Token.Severity.CRITICAL end
		local remaining = expire_ts - GetTime()
		if remaining / duration <= low_duration_thresh then
			return Token.Severity.WARNING end
		return Token.Severity.STABLE
	end
	
	-- Determines a consume's severity by remaining duration, if relevant
	local function severity_by_duration(item_id)
		local aura_id = CONSUME_AURAS[item_id]
		-- If item has no concept of duration, then report stable
		if aura_id == nil then return Token.Severity.STABLE end
		return severity_by_buff(aura_id)
	end
	
	-- Determines a consumable's severity by count in bags / bank / elsewhere
	local function severity_by_quantity(item_id, req_quantity)
		local count_bag, count_mia = get_item_counts(item_id)
		if count_bag >= req_quantity then
			return Token.Severity.STABLE end
		if count_bag + count_mia >= req_quantity then
			return Token.Severity.WARNING end
		return Token.Severity.CRITICAL
	end
	
	-- Constructs multi-line string report of all relevant consumes of this tag
	local function build_tag_report(tag, consumes)
		local color = colors_by_tag[tag]
		local lines = { build_header(color(tag), #tag) }
		
		local sorted = sorter(consumes, function(k) return k.name end)
		for _, consume in ipairs(sorted) do
			local item_id = consume.id
			local req_quantity = consumes[consume]
			local qty_severity = severity_by_quantity(item_id, req_quantity)
			local dur_severity = severity_by_duration(item_id)
			local status = Token.build(qty_severity, dur_severity)
			local line = texture_to_icon(consume.texture) .. consume.link
			insert(lines, status .. line)
		end
		
		return concat(lines, "\n")
	end

    ----------------------------------------------------------------------
    --------------------------- EVENT HANDLERS  --------------------------
    ----------------------------------------------------------------------
    
	local function handle_fcm_show()
		local db = get_db()
		if db ~= nil then
			-- Convert consumable names into consumable objects
			local quantity_by_consume = mapper(quantity_by_name,
				function(k, v)
					local consume = db[k]
					if consume == nil then
						Log.info("user config, consumable DNE: " .. tostring(k)) end
					return consume, v
				end)
			
			-- Protection against empty/invalid consume list
			if next(quantity_by_consume) == nil then return end
			
			local consumes_by_tag = grouper(quantity_by_consume,
				function(k, v) return k.tag end)
			local sorted_tags = sorter(consumes_by_tag, function(k) return k end)
			
			local reports = { }
			for _, tag in ipairs(sorted_tags) do
				local tag_report = build_tag_report(tag, consumes_by_tag[tag])
				insert(reports, tag_report)
			end
			
			aura_env.display = concat(reports, "\n")
		else aura_env.display = PENDING_TEXT_DISPLAY end
		
		return true
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
		
		if success then
			pending_item_ids[item_id] = nil
		elseif pending_item_ids[item_id] ~= nil then
			Log.warn("failed to query item ID: " .. tostring(item_id))
			cache_item(item_id)
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

