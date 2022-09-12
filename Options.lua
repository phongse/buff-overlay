local GetSpellInfo = GetSpellInfo
local format = format
local next = next
local wipe = wipe
local Spell = Spell
local MAX_CLASSES = MAX_CLASSES
local CLASS_SORT_ORDER = CLASS_SORT_ORDER

local function GetSpells(class)
    local spells = {}
    local descr = {}

    if next(BuffOverlay.db.profile.buffs) ~= nil then
        for k, v in pairs(BuffOverlay.db.profile.buffs) do
            -- Check if spell is valid for new db structure. If not, likely from old profile. Reset needed.
            if type(v) ~= "table" or not v.prio or not v.class then
                wipe(BuffOverlay.db.profile.buffs)
                BuffOverlay.print("Corrupted buff database found. This is likely due to updating from an older version of Buff Overlay. Resetting buff database to default. Your other settings (including custom buffs) will be preserved.")
                return
            end

            if not v.parent and (v.class == class) then
                local spellName, _, icon = GetSpellInfo(k)
                local formattedName = spellName and format("|T%s:0|t %s", icon, spellName) or tostring(k)

                if spellName then
                    local s = Spell:CreateFromSpellID(k)
                    s:ContinueOnSpellLoad(function()
                        descr[k] = s:GetSpellDescription()
                    end)
                end

                spells[tostring(k)] = {
                    name = formattedName,
                    type = "toggle",
                    desc = descr[k] or "",
                    width = "full",
                    get = function()
                        return BuffOverlay.db.profile.buffs[k].enabled or false
                    end,
                    set = function(_, value)
                        BuffOverlay.db.profile.buffs[k].enabled = value
                        if BuffOverlay.db.profile.buffs[k].children then
                            for child in pairs(BuffOverlay.db.profile.buffs[k].children) do
                                BuffOverlay.db.profile.buffs[child].enabled = value
                            end
                        end
                        BuffOverlay:Refresh()
                    end,
                }
            end
        end
    end
    return spells
end

function BuffOverlay_GetClasses()
    local classes = {}
    classes["MISC"] = {
        name = "Miscellaneous",
        order = 1,
        type = "group",
        args = GetSpells("MISC"),
        icon = "Interface\\Icons\\Trade_Engineering",
        iconCoords = nil,
    }

    for i = 1, MAX_CLASSES do
        classes[CLASS_SORT_ORDER[i]] = {
            name = LOCALIZED_CLASS_NAMES_MALE[CLASS_SORT_ORDER[i]],
            order = 0,
            type = "group",
            args = GetSpells(CLASS_SORT_ORDER[i]),
            icon = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes",
            iconCoords = CLASS_ICON_TCOORDS[CLASS_SORT_ORDER[i]],
        }
    end
    return classes
end

local customSpellInfo = {
    spellId = {
        order = 1,
        type = "description",
        name = function(info)
            local spellId = info[#info - 1]
            return "|cffffd700 " .. "Spell ID" .. "|r " .. spellId .. "\n"
        end,
    },
    delete = {
        order = 2,
        type = "execute",
        name = "Delete",
        confirm = true,
        confirmText = "Are you sure you want to delete this spell?",
        func = function(info)
            local spellId = info[#info - 1]
            spellId = tonumber(spellId)
            BuffOverlay.db.global.customBuffs[spellId] = nil
            if not BuffOverlay.defaultSpells[spellId] then
                BuffOverlay.db.profile.buffs[spellId] = nil
            end
            info.options.args.customSpells.args[info[#info - 1]] = nil
            BuffOverlay.options.args.spells.args = BuffOverlay_GetClasses()
        end,
    },
    class = {
        order = 3,
        type = "select",
        name = "Class",
        values = function()
            local classes = {}
            classes["MISC"] = "Miscellaneous"
            for i = 1, MAX_CLASSES do
                classes[CLASS_SORT_ORDER[i]] = LOCALIZED_CLASS_NAMES_MALE[CLASS_SORT_ORDER[i]]
            end
            return classes
        end,
        set = function(info, state)
            local option = info[#info]
            local spellId = info[#info - 1]
            spellId = tonumber(spellId)
            BuffOverlay.db.global.customBuffs[spellId][option] = state
            BuffOverlay.db.profile.buffs[spellId][option] = state
            BuffOverlay.options.args.spells.args = BuffOverlay_GetClasses()
        end,
    },
    prio = {
        order = 4,
        type = "range",
        name = "Priority (Lower is Higher Prio)",
        min = 1,
        max = 100,
        step = 1,
        set = function(info, state)
            local option = info[#info]
            local spellId = info[#info - 1]
            spellId = tonumber(spellId)
            BuffOverlay.db.global.customBuffs[spellId][option] = state
            BuffOverlay.db.profile.buffs[spellId][option] = state
        end,
        get = function(info)
            local option = info[#info]
            local spellId = info[#info - 1]
            spellId = tonumber(spellId)
            local value = BuffOverlay.db.global.customBuffs[spellId][option]
            if not value then return 100 end
            return BuffOverlay.db.global.customBuffs[spellId][option]
        end,
    },
}

local customSpells = {
    spellId_info = {
        order = 1,
        type = "description",
        name = "Note: anything you add here will persist through addon updates and profile resets.",
    },
    spellId = {
        order = 2,
        name = "Spell ID",
        desc = "Enter the spell ID of the spell you want to keep track of.",
        type = "input",
        set = function(_, state)
            local spellId = tonumber(state)
            local name = GetSpellInfo(spellId)
            local custom = BuffOverlay.db.global.customBuffs
            if custom[spellId] then return end

            if spellId and name then
                if BuffOverlay:InsertBuff(spellId) then
                    BuffOverlay.options.args.customSpells.args[tostring(spellId)] = {
                        name = name,
                        type = "group",
                        childGroups = "tab",
                        args = customSpellInfo,
                        icon = GetSpellTexture(spellId),
                    }
                    BuffOverlay:UpdateCustomBuffs()
                end
            end
        end,
    }
}

function BuffOverlay:Options()
    for spellId in pairs(BuffOverlay.db.global.customBuffs) do
        if not BuffOverlay.defaultSpells[spellId] then
            customSpells[tostring(spellId)] = {
                name = GetSpellInfo(spellId),
                type = "group",
                childGroups = "tab",
                args = customSpellInfo,
                icon = GetSpellTexture(spellId),
            }
        end
    end
    self.options = {
        name = "BuffOverlay",
        descStyle = "inline",
        type = "group",
        plugins = { profiles = { profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db) } },
        childGroups = "tab",
        args = {
            author = {
                order = 1,
                name = "|cffffd700" .. "Author:" .. "|r " .. GetAddOnMetadata("BuffOverlay", "Author") .. "\n",
                type = "description",
                cmdHidden = true
            },
            vers = {
                order = 2,
                name = "|cffffd700" .. "Version:" .. "|r " .. GetAddOnMetadata("BuffOverlay", "Version") .. "\n\n",
                type = "description",
                cmdHidden = true
            },
            test = {
                order = 3,
                name = "Toggle Test Buffs",
                type = "execute",
                func = "Test",
                handler = BuffOverlay
            },
            welcomeMessage = {
                order = 4,
                name = "Welcome Message",
                type = "toggle",
                width = "full",
                desc = "Toggle showing of the welcome message on login.",
                get = function(info) return self.db.profile[info[#info]] end,
                set = function(info, val)
                    self.db.profile[info[#info]] = val
                    self:Refresh()
                end,
            },
            layout = {
                order = 5,
                name = "Settings",
                type = "group",
                get = function(info) return self.db.profile[info[#info]] end,
                set = function(info, val)
                    if InCombatLockdown() then
                        self.print("Cannot change settings in combat.")
                        return
                    end
                    self.db.profile[info[#info]] = val
                    self:Refresh()
                end,
                args = {
                    iconCount = {
                        order = 1,
                        name = "Icon Count",
                        type = "range",
                        width = 1.5,
                        desc = "Number of icons you want to display (per frame).",
                        min = 0,
                        max = 40,
                        softMax = 10,
                        step = 1,
                    },
                    iconAlpha = {
                        order = 2,
                        name = "Icon Alpha",
                        type = "range",
                        width = 1.5,
                        desc = "Icon transparency.",
                        min = 0,
                        max = 1,
                        step = 0.01,
                    },
                    iconScale = {
                        order = 3,
                        name = "Icon Scale",
                        type = "range",
                        width = 1,
                        desc = "The scale of the icon based on the size of the default icons on raidframe.",
                        min = 0.01,
                        max = 99,
                        softMax = 3,
                        step = 0.01,
                    },
                    cooldownNumberScale = {
                        order = 4,
                        name = "Cooldown Text Scale",
                        type = "range",
                        width = 1,
                        desc = "Scale the icon's cooldown text size.",
                        min = 0.01,
                        max = 10,
                        softMax = 2,
                        step = 0.01,
                    },
                    iconSpacing = {
                        order = 5,
                        name = "Icon Spacing",
                        type = "range",
                        width = 1,
                        desc = "Spacing between icons.",
                        min = 0,
                        max = 200,
                        softMax = 20,
                        step = 1,
                    },
                    iconAnchor = {
                        order = 6,
                        name = "Icon Anchor",
                        type = "select",
                        style = "dropdown",
                        width = 1,
                        desc = "Where the anchor is on the icon.",
                        values = {
                            ["TOPLEFT"] = "TOPLEFT",
                            ["TOPRIGHT"] = "TOPRIGHT",
                            ["BOTTOMLEFT"] = "BOTTOMLEFT",
                            ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                            ["TOP"] = "TOP",
                            ["BOTTOM"] = "BOTTOM",
                            ["RIGHT"] = "RIGHT",
                            ["LEFT"] = "LEFT",
                            ["CENTER"] = "CENTER",
                        },
                    },
                    iconRelativePoint = {
                        order = 7,
                        name = "Frame Attachment Point",
                        type = "select",
                        style = "dropdown",
                        width = 1,
                        desc = "Icon position relative to its parent frame.",
                        values = {
                            ["TOPLEFT"] = "TOPLEFT",
                            ["TOPRIGHT"] = "TOPRIGHT",
                            ["BOTTOMLEFT"] = "BOTTOMLEFT",
                            ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                            ["TOP"] = "TOP",
                            ["BOTTOM"] = "BOTTOM",
                            ["RIGHT"] = "RIGHT",
                            ["LEFT"] = "LEFT",
                            ["CENTER"] = "CENTER",
                        },
                    },
                    growDirection = {
                        order = 8,
                        name = "Grow Direction",
                        type = "select",
                        style = "dropdown",
                        width = 1,
                        desc = "Where the icons will grow from the first icon.",
                        values = {
                            ["DOWN"] = "DOWN",
                            ["UP"] = "UP",
                            ["LEFT"] = "LEFT",
                            ["RIGHT"] = "RIGHT",
                            ["HORIZONTAL"] = "HORIZONTAL",
                            ["VERTICAL"] = "VERTICAL",
                        },
                    },
                    iconXOff = {
                        order = 9,
                        name = "X-Offset",
                        type = "range",
                        width = 1.5,
                        desc = "Change the icon group's X-Offset.",
                        min = -100,
                        max = 100,
                        step = 1,
                    },
                    iconYOff = {
                        order = 10,
                        name = "Y-Offset",
                        type = "range",
                        width = 1.5,
                        desc = "Change the icon group's Y-Offset.",
                        min = -100,
                        max = 100,
                        step = 1,
                    },
                    iconBorder = {
                        order = 11,
                        name = "Icon Border",
                        type = "toggle",
                        width = 0.75,
                        desc = "Adds a pixel border around the icon. This will also zoom the icon in slightly to remove any default borders that may be present.",
                    },
                    iconBorderColor = {
                        order = 12,
                        name = "Icon Border Color",
                        type = "color",
                        width = 0.75,
                        desc = "Change the icon border color.",
                        hasAlpha = true,
                        get = function(info)
                            local t = self.db.profile[info[#info]]
                            return t.r, t.g, t.b, t.a
                        end,
                        set = function(info, r, g, b, a)
                            local t = self.db.profile[info[#info]]
                            t.r, t.g, t.b, t.a = r, g, b, a
                            self:Refresh()
                        end,
                    },
                    iconBorderSize = {
                        order = 13,
                        name = "Icon Border Size",
                        type = "range",
                        width = 1.5,
                        desc = "Change the icon border size (in pixels).",
                        min = 1,
                        max = 10,
                        softMax = 5,
                        step = 1,
                    },
                    showCooldownSpiral = {
                        order = 14,
                        name = "Cooldown Spiral",
                        type = "toggle",
                        width = "full",
                        desc = "Toggle showing of the cooldown spiral.",
                    },
                    showCooldownNumbers = {
                        order = 15,
                        name = "Show Blizzard Cooldown Text",
                        type = "toggle",
                        width = "full",
                        desc = "Toggle showing of the cooldown text. Note that you must also enable the 'Show Numbers for Cooldown' in Blizzard settings."
                    },
                }
            },
            spells = {
                order = 6,
                name = "Spells",
                type = "group",
                args = BuffOverlay_GetClasses(),
            },
            customSpells = {
                order = 7,
                name = "Custom Spells",
                type = "group",
                args = customSpells,
                set = function(info, state)
                    local option = info[#info]
                    local spellId = info[#info - 1]
                    spellId = tonumber(spellId)
                    BuffOverlay.db.global.customBuffs[spellId][option] = state
                    BuffOverlay:UpdateCustomBuffs()
                end,
                get = function(info)
                    local option = info[#info]
                    local spellId = info[#info - 1]
                    spellId = tonumber(spellId)
                    if not spellId then return end
                    return BuffOverlay.db.global.customBuffs[spellId][option]
                end,
            },
        }
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable("BuffOverlay", self.options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("BuffOverlay", "BuffOverlay")
end
