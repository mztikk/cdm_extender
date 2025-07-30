local string_lower = string.lower
local tonumber = tonumber
local type = type
local pairs = pairs

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
    local custom_ids, refresh_func
    if cdm_type == "essential" then
        custom_ids = addon.db.profile.custom_essential_ids
        refresh_func = function()
            EssentialCooldownViewer:RefreshLayout()
        end
    elseif cdm_type == "utility" then
        custom_ids = addon.db.profile.custom_utility_ids
        refresh_func = function()
            UtilityCooldownViewer:RefreshLayout()
        end
    elseif cdm_type == "buff" then
        custom_ids = addon.db.profile.custom_buff_ids
        refresh_func = function()
            BuffIconCooldownViewer:RefreshLayout()
        end
    elseif cdm_type == "buff_bar" then
        custom_ids = addon.db.profile.custom_buff_bar_ids
        refresh_func = function()
            BuffBarCooldownViewer:RefreshLayout()
        end
    end

    if not spell_id then
        for _, v in pairs(custom_ids) do
            addon:Print("Custom: ", cdm_type, "Spell ID:", v.spellID, "Self Aura:", v.selfAura, "Has Aura:", v.hasAura,
                "Has Charges:", v.charges)
        end
        return
    end

    for k, v in pairs(custom_ids) do
        if v.spellID == spell_id then
            custom_ids[k] = nil
            addon:Print("Removed existing custom " .. cdm_type .. " ID for spell:", spell_id)
            if refresh_func then
                refresh_func()
            end
            return
        end
    end

    local custom_id = 9999900 + #custom_ids + 1
    custom_ids[custom_id] = create_custom_cooldown_info(spell_id, self_aura, has_aura, has_charges)
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
        for custom_cooldown_id, _ in pairs(addon.db.profile.custom_essential_ids) do
            ids[#ids + 1] = custom_cooldown_id
        end
    end

    return ids
end

local og_utility_get_cooldown_ids = UtilityCooldownViewer.GetCooldownIDs
UtilityCooldownViewer.GetCooldownIDs = function(self)
    local ids = og_utility_get_cooldown_ids(self)

    if addon.db.profile and addon.db.profile.custom_utility_ids then
        for custom_cooldown_id, _ in pairs(addon.db.profile.custom_utility_ids) do
            ids[#ids + 1] = custom_cooldown_id
        end
    end

    return ids
end

local og_buff_icon_get_cooldown_ids = BuffIconCooldownViewer.GetCooldownIDs
BuffIconCooldownViewer.GetCooldownIDs = function(self)
    local ids = og_buff_icon_get_cooldown_ids(self)

    if addon.db.profile and addon.db.profile.custom_buff_ids then
        for custom_buff_id, _ in pairs(addon.db.profile.custom_buff_ids) do
            ids[#ids + 1] = custom_buff_id
        end
    end

    return ids
end

local og_buff_bar_get_cooldown_ids = BuffBarCooldownViewer.GetCooldownIDs
BuffBarCooldownViewer.GetCooldownIDs = function(self)
    local ids = og_buff_bar_get_cooldown_ids(self)

    if addon.db.profile and addon.db.profile.custom_buff_bar_ids then
        for custom_buff_bar_id, _ in pairs(addon.db.profile.custom_buff_bar_ids) do
            ids[#ids + 1] = custom_buff_bar_id
        end
    end

    return ids
end

local og_get_cooldown_viewer_cooldown_info = C_CooldownViewer.GetCooldownViewerCooldownInfo
C_CooldownViewer.GetCooldownViewerCooldownInfo = function(cooldown_id)
    local info = (addon.db.profile and addon.db.profile.custom_essential_ids and
                     addon.db.profile.custom_essential_ids[cooldown_id]) or
                     (addon.db.profile and addon.db.profile.custom_utility_ids and
                         addon.db.profile.custom_utility_ids[cooldown_id]) or
                     (addon.db.profile and addon.db.profile.custom_buff_ids and
                         addon.db.profile.custom_buff_ids[cooldown_id]) or
                     (addon.db.profile and addon.db.profile.custom_buff_bar_ids and
                         addon.db.profile.custom_buff_bar_ids[cooldown_id]) or
                     og_get_cooldown_viewer_cooldown_info(cooldown_id)

    return info
end
