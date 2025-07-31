local string_lower = string.lower
local tonumber = tonumber
local type = type
local pairs = pairs
local ipairs = ipairs
local next = next
local select = select
local math_random = math.random
local table_remove = table.remove
local table_insert = table.insert

local custom_fake_ids = {}

local custom_essential_fake_lookup = {}
local custom_utility_fake_lookup = {}
local custom_buff_fake_lookup = {}
local custom_buff_bar_fake_lookup = {}

local function get_custom_fake_id()
    local fake_id = 999900000 + math_random(1, 99999)

    while custom_fake_ids[fake_id] do
        fake_id = 999900000 + math_random(1, 99999)
    end

    return fake_id
end

local addon = LibStub("AceAddon-3.0"):NewAddon("cdm_extender", "AceConsole-3.0")
function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("CDME_DATA", {
        profile = {
            custom_essential_ids = {},
            custom_utility_ids = {},
            custom_buff_ids = {},
            custom_buff_bar_ids = {}
        }
    })

    -- convert old key based custom ids to indexed tables
    local function convert_to_indexed_table(custom_ids)
        local indexed_table = {}
        for _, v in pairs(custom_ids) do
            indexed_table[#indexed_table + 1] = v
        end
        return indexed_table
    end

    if (#self.db.profile.custom_essential_ids == 0 and next(self.db.profile.custom_essential_ids) and
        select(1, next(self.db.profile.custom_essential_ids)) > 0) or
        (#self.db.profile.custom_utility_ids == 0 and next(self.db.profile.custom_utility_ids) and
            select(1, next(self.db.profile.custom_utility_ids)) > 0) or
        (#self.db.profile.custom_buff_ids == 0 and next(self.db.profile.custom_buff_ids) and
            select(1, next(self.db.profile.custom_buff_ids)) > 0) or
        (#self.db.profile.custom_buff_bar_ids == 0 and next(self.db.profile.custom_buff_bar_ids) and
            select(1, next(self.db.profile.custom_buff_bar_ids)) > 0) then
        self.db.profile.custom_essential_ids = convert_to_indexed_table(self.db.profile.custom_essential_ids)
        self.db.profile.custom_utility_ids = convert_to_indexed_table(self.db.profile.custom_utility_ids)
        self.db.profile.custom_buff_ids = convert_to_indexed_table(self.db.profile.custom_buff_ids)
        self.db.profile.custom_buff_bar_ids = convert_to_indexed_table(self.db.profile.custom_buff_bar_ids)
    end

    local function generate_fake_ids(base_table, lookup)
        for _, v in ipairs(base_table) do
            local fake_id = get_custom_fake_id()
            custom_fake_ids[fake_id] = v
            lookup[v] = fake_id
        end
    end

    generate_fake_ids(self.db.profile.custom_essential_ids, custom_essential_fake_lookup)
    generate_fake_ids(self.db.profile.custom_utility_ids, custom_utility_fake_lookup)
    generate_fake_ids(self.db.profile.custom_buff_ids, custom_buff_fake_lookup)
    generate_fake_ids(self.db.profile.custom_buff_bar_ids, custom_buff_bar_fake_lookup)

    local og_get_cooldown_viewer_cooldown_info = C_CooldownViewer.GetCooldownViewerCooldownInfo
    C_CooldownViewer.GetCooldownViewerCooldownInfo = function(cooldown_id)
        local info = og_get_cooldown_viewer_cooldown_info(cooldown_id) or custom_fake_ids[cooldown_id]

        return info
    end
end

local function create_custom_cooldown_info(spell_id, self_aura, has_aura, has_charges)
    local info = {
        spellID = spell_id,
        overrideSpellID = nil,
        linkedSpellIDs = {},
        selfAura = self_aura,
        hasAura = has_aura,
        charges = has_charges,
        flags = 0
    }

    return info
end

local function add_custom_id(cdm_type, spell_id, self_aura, has_aura, has_charges)
    local custom_ids, lookup, refresh_func
    if cdm_type == "essential" then
        custom_ids = addon.db.profile.custom_essential_ids
        lookup = custom_essential_fake_lookup
        refresh_func = function()
            EssentialCooldownViewer:RefreshLayout()
        end
    elseif cdm_type == "utility" then
        custom_ids = addon.db.profile.custom_utility_ids
        lookup = custom_utility_fake_lookup
        refresh_func = function()
            UtilityCooldownViewer:RefreshLayout()
        end
    elseif cdm_type == "buff" then
        custom_ids = addon.db.profile.custom_buff_ids
        lookup = custom_buff_fake_lookup
        refresh_func = function()
            BuffIconCooldownViewer:RefreshLayout()
        end
    elseif cdm_type == "buff_bar" then
        custom_ids = addon.db.profile.custom_buff_bar_ids
        lookup = custom_buff_bar_fake_lookup
        refresh_func = function()
            BuffBarCooldownViewer:RefreshLayout()
        end
    end

    if not spell_id then
        if #custom_ids == 0 then
            addon:Print("No custom " .. cdm_type .. " IDs found.")
            return
        end

        for _, v in ipairs(custom_ids) do
            addon:Print("Custom:", cdm_type, "Spell ID:", v.spellID, "Self Aura:", v.selfAura, "Has Aura:", v.hasAura,
                "Has Charges:", v.charges)
        end
        return
    end

    for i, v in ipairs(custom_ids) do
        if v.spellID == spell_id then
            table_remove(custom_ids, i)
            local custom_fake_id = lookup[v]
            custom_fake_ids[custom_fake_id] = nil
            lookup[v] = nil
            addon:Print("Removed existing custom " .. cdm_type .. " ID for spell:", spell_id)
            if refresh_func then
                refresh_func()
            end
            return
        end
    end

    local cooldown_info = create_custom_cooldown_info(spell_id, self_aura, has_aura, has_charges)
    table_insert(custom_ids, cooldown_info)
    local custom_fake_id = get_custom_fake_id()
    custom_fake_ids[custom_fake_id] = cooldown_info
    lookup[cooldown_info] = custom_fake_id
    addon:Print("Added custom " .. cdm_type .. " ID for spell:", spell_id, "Self Aura:", self_aura, "Has Aura:",
        has_aura, "Has Charges:", has_charges)
    if refresh_func then
        refresh_func()
    end
end

local function str_to_bool(str)
    if str == nil or type(str) ~= "string" then
        return false
    end

    return string_lower(str) == 'true'
end

function addon:OnChatCommand(input)
    local cdm_type, spell_id, self_aura, has_aura, has_charges = self:GetArgs(input, 5)
    if cdm_type == nil then
        addon:Print("Usage: /cdme <essential|utility|buff|buff_bar> <spell_id> [self_aura] [has_aura] [has_charges]",
            "or /cdme <essential|utility|buff|buff_bar> to list custom cooldowns")
        return
    end

    cdm_type = string_lower(cdm_type)
    if cdm_type ~= "essential" and cdm_type ~= "utility" and cdm_type ~= "buff" and cdm_type ~= "buff_bar" then
        addon:Print("Invalid CDM type:", cdm_type)
        return
    end

    self_aura = str_to_bool(self_aura)
    has_aura = str_to_bool(has_aura)
    has_charges = str_to_bool(has_charges)

    add_custom_id(cdm_type, spell_id and tonumber(spell_id), self_aura, has_aura, has_charges)
end

addon:RegisterChatCommand("cdme", "OnChatCommand")
addon:RegisterChatCommand("cdm_extender", "OnChatCommand")

local og_essential_get_cooldown_ids = EssentialCooldownViewer.GetCooldownIDs
EssentialCooldownViewer.GetCooldownIDs = function(self)
    local ids = og_essential_get_cooldown_ids(self)

    if addon.db.profile and addon.db.profile.custom_essential_ids then
        for _, v in ipairs(addon.db.profile.custom_essential_ids) do
            local custom_cooldown_id = custom_essential_fake_lookup[v]
            ids[#ids + 1] = custom_cooldown_id
        end
    end

    return ids
end

local og_utility_get_cooldown_ids = UtilityCooldownViewer.GetCooldownIDs
UtilityCooldownViewer.GetCooldownIDs = function(self)
    local ids = og_utility_get_cooldown_ids(self)

    if addon.db.profile and addon.db.profile.custom_utility_ids then
        for _, v in ipairs(addon.db.profile.custom_utility_ids) do
            local custom_cooldown_id = custom_utility_fake_lookup[v]
            ids[#ids + 1] = custom_cooldown_id
        end
    end

    return ids
end

local og_buff_icon_get_cooldown_ids = BuffIconCooldownViewer.GetCooldownIDs
BuffIconCooldownViewer.GetCooldownIDs = function(self)
    local ids = og_buff_icon_get_cooldown_ids(self)

    if addon.db.profile and addon.db.profile.custom_buff_ids then
        for _, v in ipairs(addon.db.profile.custom_buff_ids) do
            local custom_buff_id = custom_buff_fake_lookup[v]
            ids[#ids + 1] = custom_buff_id
        end
    end

    return ids
end

local og_buff_bar_get_cooldown_ids = BuffBarCooldownViewer.GetCooldownIDs
BuffBarCooldownViewer.GetCooldownIDs = function(self)
    local ids = og_buff_bar_get_cooldown_ids(self)

    if addon.db.profile and addon.db.profile.custom_buff_bar_ids then
        for _, v in ipairs(addon.db.profile.custom_buff_bar_ids) do
            local custom_buff_bar_id = custom_buff_bar_fake_lookup[v]
            ids[#ids + 1] = custom_buff_bar_id
        end
    end

    return ids
end
