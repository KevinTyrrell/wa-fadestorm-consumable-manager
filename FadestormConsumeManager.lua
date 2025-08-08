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
		local by_id = { }
		local by_name = { }
		local by_category = { }
		
		-- @param [table] self Implicit Item instance
		-- @return [str] Category in which the item is classified as
		local function category(self)
			return by_category[self]
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
			return setmetatable(obj, mt)
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
		
		local function init_item_db()
			-- Clever workaround 
			setmetatable(by_category, { __index = function() return { } end })
		end
	end)()
	
	local CONSUMABLE_IDS = {
		
	}
	
	local CONSUME_AURAS = {
		[13510] = 17626, -- Flask of the Titans
		[13511] = 17627, -- Flask of Distilled Wisdom
		[13512] = 17628, -- Flask of Supreme Power
		[13513] = 17629, -- Flask of Chromatic Resistance
		[13461] = 17549, -- Greater Arcane Protection Potion
		[13457] = 17543, -- Greater Fire Protection Potion
		[13456] = 17544, -- Greater Frost Protection Potion
		[13458] = 17546, -- Greater Nature Protection Potion
		[13459] = 17548, -- Greater Shadow Protetion Potion
		[13460] = 17545, -- Greater Holy Protection Potion
		[13445] = 11348, -- Elixir of Superior Defense
		[20004] = 24361, -- Major Troll's Blood Potion
		[3825] = 3593, -- Elixir of Fortitude
		[13452] = 17538, -- Elixir of the Mongoose
		[20007] = 24363, -- Mageblood Potion
		[9206] = 11405, -- Elixir of Giants
		[12820] = 17038, -- Winterfall Firewater
		[9088] = 11371, -- Gift of Arthas
		[13454] = 17539, -- Greater Arcane Elixir
		[9264] = 11474, -- Elixir of Shadow Power
		[21546] = 26276, -- Elixir of Greater Firepower
		[17708] = 21920, -- Elixir of Frost Power
		[1177] = 673, -- Oil of Olaf
		[23211] = 29334, -- Toasted Smorc
		[23326] = 29333, -- Midsummer Sausage
		[23435] = 29335, -- Elderberry Pie
		[23327] = 29332, -- Fire-toasted Bun
		[22239] = 27722, -- Sweet Surprise
		[22237] = 27723, -- Dark Desire
		[22236] = 27720, -- Buttermilk Delight
		[22238] = 27721, -- Very Berry Cream
		[12457] = 16325, -- Juju Chill
		[12460] = 16329, -- Juju Might
		[12455] = 16326, -- Juju Ember
		[12458] = 16327, -- Juju Guile
		[12451] = 16323, -- Juju Power
		[13455] = 17540, -- Greater Stoneshield Potion
		[11567] = 15279, -- Crystal Spire
		[11563] = 15231, -- Crystal Force
		[11564] = 15233, -- Crystal Ward
		[5206] = 5665, -- Bogling Root
		[8410] = 10667, -- R.O.I.D.S.
		[8412] = 10669, -- Ground Scorpok Assay
		[8423] = 10692, -- Cerebral Cortex Compound
		[8424] = 10693, -- Gizzard Gum
		[8411] = 10668, -- Lung Juice Cocktail
		[20079] = 24382, -- Spirit of Zanza
		[20080] = 24417, -- Sheen of Zanza
		[20081] = 24383, -- Swiftness of Zanza
		[13928] = 18192, -- Grilled Squid
		[20452] = 24799, -- Smoked Desert Dumplings
		[13931] = 18194, -- Nightfin Soup
		[18254] = 22730, -- Runn Tum Tuber Surprise
		[21023] = 25661, -- Dirge's Kickin' Chimaerok Chops
		[13813] = 18141, -- Blessed Sunfruit Juice
		[13810] = 18125, -- Blessed Sunfruit
		[18284] = 22790, -- Kreeg's Stout Beatdown
		[18269] = 22789, -- Gordok Green Grog
		[21151] = 25804, -- Rumsey Rum Black Label
	}
	
	-- Map of [item_id -> tag]
	local tag_by_item_id = (function()
		local mapped = { }
		for tag, t in pairs(CONSUMABLE_IDS) do
			for _, item_id in ipairs(t) do
				mapped[item_id] = tag end
		end
		return mapped
	end)()
	
	-- Items which have not been cached from the item server
	local pending_item_ids = (function()
		local pending = { }
		for item_id in pairs(tag_by_item_id) do
			if not item_cached(item_id) then
				pending[item_id] = true end
		end
		return pending
	end)()
	
	-- Requests all pending item information from the item server
	local function query_pending_items()
		for item_id in pairs(pending_item_ids) do
			cache_item(item_id) end
	end
	
	query_pending_items() -- Start initial item cache
	
	-- Constructs the item database, call only when all items are queried
	local function build_database()
		local db = { }
		for item_id, tag in pairs(tag_by_item_id) do
			-- 01 itemName
			-- 02 itemLink
			-- 03 itemQuality
			-- 04 itemLevel
			-- 05 itemMinLevel
			-- 06 itemType
			-- 07 itemSubType
			-- 08 itemStackCount
			-- 09 itemEquipLoc
			-- 10 itemTexture
			-- 11 sellPrice
			-- 12 classID
			-- 13 subclassID
			-- 14 bindType
			-- 15 expacID
			-- 16 setID
			-- 17 isCraftingReagent
			local info = { GetItemInfo(item_id) }
			local _, name = next(info)
			db[lower(name)] = {
				name = name,
				link = info[2],
				tag = tag,
				texture = info[10],
				id = item_id,
			}
		end
		return db
	end
	
	-- Retrieves the database, if all queried items are loaded
	local get_db = (function()
		local db, strategy
		
		local function identity() return db end
		strategy = function()
			-- No more pending network calls, package db
			if next(pending_item_ids) == nil then
				db = build_database()
				strategy = identity
				return db
			-- Request missing items again
			else query_pending_items() end
		end
		
		return function() return strategy() end
	end)()
	
	-- Creates a centered header divider with a title
	local build_header = (function()
		local HEADER_LENGTH, HEADER_CHAR = 45, "~"
		return function(title, len)
			if title == nil or title == "" then
				return s_duplicate(HEADER_CHAR, HEADER_LENGTH) end
			len = len ~= nil and len or #title
			local width = (HEADER_LENGTH - len - 2) / 2
			local widthf = floor(width)
			local section = s_duplicate(HEADER_CHAR, widthf)
			if width == widthf then
				return section .. " " .. title .. " " .. section
			else
				-- Append a header character in the case of odd sized headers
				return section .. " " .. title .. " " .. section .. HEADER_CHAR
			end
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
	
	-- return quantity of item_id in the user's bags
	-- return quantity of item_id outside of the user's bags
	local get_item_counts = (function()
		-- If TSM lib not available, use WoW API route
		if not TSM_API or not TSM_API.GetPlayerTotals then
			return function(item_id)
				local bag_count = GetItemCount(item_id)
				local bank_count = GetItemCount(item_id, true) - bag_count
				return bag_count, bank_count
			end
		end
		
		local GetPlayerTotals = TSM_API.GetPlayerTotals
		return function(item_id)
			local bag_count = GetItemCount(item_id)
			local total = sum({ GetPlayerTotals("i:" .. tostring(item_id)) })
			return bag_count, total - bag_count
		end
	end)()
	
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

