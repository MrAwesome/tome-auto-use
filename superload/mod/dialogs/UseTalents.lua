-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2017 Nicolas Casalini
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

require "engine.class"
local Dialog = require "engine.ui.Dialog"
local TreeList = require "engine.ui.TreeList"
local ListColumns = require "engine.ui.ListColumns"
local Textzone = require "engine.ui.Textzone"
local TextzoneList = require "engine.ui.TextzoneList"
local Separator = require "engine.ui.Separator"
local GetQuantity = require "engine.dialogs.GetQuantity"

module(..., package.seeall, class.inherit(Dialog))
-- Could use better icons when available
local confirmMark = require("engine.Entity").new({ image = "ui/chat-icon.png" })
local autoMark = require("engine.Entity").new({ image = "ui/hotkeys/mainmenu.png" })

-- generate talent status separately to enable quicker refresh of Dialog
local function TalentStatus(who, t)
    local status = tstring { { "color", "LIGHT_GREEN" }, "Active" }
    if who:isTalentCoolingDown(t) then
        status = tstring { { "color", "LIGHT_RED" }, who:isTalentCoolingDown(t) .. " turns" }
    elseif not who:preUseTalent(t, true, true) then
        status = tstring { { "color", "GREY" }, "Unavailable" }
    elseif t.is_object_use then
        status = tstring { { "color", "SALMON" }, "Object" }
    elseif t.mode == "sustained" then
        status = who:isTalentActive(t.id) and tstring { { "color", "YELLOW" }, "Sustaining" } or
        tstring { { "color", "LIGHT_GREEN" }, "Sustain" }
    elseif t.mode == "passive" then
        status = tstring { { "color", "LIGHT_BLUE" }, "Passive" }
    end
    if who:isTalentAuto(t.id) then
        status:add(autoMark:getDisplayString())
    end
    if who:isTalentConfirmable(t.id) then
        status:add(confirmMark:getDisplayString())
    end
    return tostring(status)
end

function _M:init(actor)
    self.actor = actor
    actor.hotkey = actor.hotkey or {}
    Dialog.init(self, "Use Talents: " .. actor.name, game.w * 0.8, game.h * 0.8)

    local vsep = Separator.new { dir = "horizontal", size = self.ih - 10 }
    self.c_tut = Textzone.new { width = math.floor(self.iw / 2 - vsep.w / 2), height = 1, auto_height = true, no_color_bleed = true, text = [[
You can bind a non-passive talent to a hotkey by pressing the corresponding hotkey while selecting a talent or by right-clicking on the talent.
Check out the keybinding screen in the game menu to bind hotkeys to a key (default is 1-0 plus control, shift, or alt).
Right click or press '~' to configure talent confirmation and automatic use.
]] }
    self.c_desc = TextzoneList.new { width = math.floor(self.iw / 2 - vsep.w / 2), height = self.ih - self.c_tut.h - 20, scrollbar = true, no_color_bleed = true }

    self:generateList()

    local cols = {
        { name = "",     width = { 40, "fixed" }, display_prop = "char" },
        { name = "Talent", width = 80,       display_prop = "name" },
        {
            name = "Status",
            width = 20,
            display_prop = function(item)
                if item.talent then return TalentStatus(actor, actor:getTalentFromId(item.talent)) else return "" end
            end
        },
        { name = "Hotkey", width = { 75, "fixed" }, display_prop = "hotkey" },
        {
            name = "Mouse Click",
            width = { 60, "fixed" },
            display_prop = function(item)
                if item.talent and item.talent == self.actor.auto_shoot_talent then
                    return "LeftClick"
                elseif item.talent and item.talent == self.actor.auto_shoot_midclick_talent then
                    return "MiddleClick"
                else
                    return ""
                end
            end
        },
    }
    self.c_list = TreeList.new { width = math.floor(self.iw / 2 - vsep.w / 2), height = self.ih - 10, all_clicks = true, scrollbar = true, columns = cols, tree = self.list, fct = function(
        item, sel, button) self:use(item, button) end, select = function(item, sel) self:select(item) end, on_drag = function(
        item, sel) self:onDrag(item) end }
    self.c_list.cur_col = 2

    self:loadUI {
        { left = 0,  top = 0,               ui = self.c_list },
        { right = 0, top = self.c_tut.h + 20, ui = self.c_desc },
        { right = 0, top = 0,               ui = self.c_tut },
        { hcenter = 0, top = 5,             ui = vsep },
    }
    self:setFocus(self.c_list)
    self:setupUI()

    self.key:addCommands {
        __TEXTINPUT = function(c)
            if c == '~' then
                self:use(self.cur_item, "right")
            end
            if self.list and self.list.chars[c] then
                self:use(self.list.chars[c])
            end
        end,
    }
    engine.interface.PlayerHotkeys:bindAllHotkeys(self.key, function(i) self:defineHotkey(i) end)
    self.key:addBinds {
        EXIT = function() game:unregisterDialog(self) end,
    }
end

function _M:on_register()
    game:onTickEnd(function() self.key:unicodeInput(true) end)
end

function _M:defineHotkey(id)
    if not self.actor.hotkey then return end
    local item = self.cur_item
    if not item or not item.talent then return end

    local t = self.actor:getTalentFromId(item.talent)
    if t.mode == "passive" then return end

    for i = 1, 12 * self.actor.nb_hotkey_pages do
        if self.actor.hotkey[i] and self.actor.hotkey[i][1] == "talent" and self.actor.hotkey[i][2] == item.talent then self.actor.hotkey[i] = nil end
    end

    self.actor.hotkey[id] = { "talent", item.talent }
    self:simplePopup("Hotkey " .. id .. " assigned", t.name:capitalize() .. " assigned to hotkey " .. id)
    self.c_list:drawTree()
    self.actor.changed = true
end

function _M:onDrag(item)
    if item and item.talent then
        local t = self.actor:getTalentFromId(item.talent)
        --		if t.mode == "passive" then return end
        local s = t.display_entity:getEntityFinalSurface(nil, 64, 64)
        local x, y = core.mouse.get()
        game.mouse:startDrag(x, y, s, { kind = "talent", id = t.id }, function(drag, used)
            local x, y = core.mouse.get()
            game.mouse:receiveMouse("drag-end", x, y, true, nil, { drag = drag })
            if drag.used then self.c_list:drawTree() end
        end)
    end
end

function _M:select(item)
    if item then
        self.c_desc:switchItem(item, item.desc)
        self.cur_item = item
    end
end

function _M:use(item, button)
    if not item then
        game.log("Not and Item")
        return
    end
    --game.log(item)
    if not item.talent then return end
    local is_item = false
    local t = self.actor:getTalentFromId(item.talent) or nil
    if not t then
        --game.log("this is an item")
        --game.log(item.name)
        local o = game.player:findInAllInventories(item.talent, { no_add_name = true, force_id = true, no_count = true })
        if o and o.use_talent and o.use_talent.id then
            local item_talent_id = o.use_talent.id
            --game.log(item_talent_id)
            t = self.actor:getTalentFromId(item_talent_id)
            is_item = true
        elseif o.use_power then
            --game.log("UseTalents: found power based item")
            is_item = true
        end
    end
    if t and t.mode == "passive" then return end
    if button == "right" then
        local list = {
            { name = "Unbind",                                 what = "unbind" },
            { name = "Bind to middle mouse click (on a target)", what = "middle" },
        }

        if self.actor:isTalentConfirmable(t) then
            table.insert(list, 1, { name = "#YELLOW#Disable talent confirmation", what = "unset-confirm" })
        else
            table.insert(list, 1,
                { name = confirmMark:getDisplayString() .. "Request confirmation before using this talent", what =
                "set-confirm" })
        end
        local automode = self.actor:isTalentAuto(t)
        if is_item then
            automode = self.actor:isTalentAuto(item.talent)
        end
        local ds = "#YELLOW#Disable "
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 57 and ds or "") .. "you left click (auto use tweaks)", what = (automode == 57 and "auto-dis" or "auto-en-57") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 115 and ds or "") .. "you left click (auto use tweaks) & are in range", what = (automode == 115 and "auto-dis" or "auto-en-115") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 1 and ds or "") .. "available", what = (automode == 1 and "auto-dis" or "auto-en-1") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 2 and ds or "") .. "no enemies visible", what = (automode == 2 and "auto-dis" or "auto-en-2") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 3 and ds or "") .. "you are currently resting", what = (automode == 3 and "auto-dis" or "auto-en-3") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 4 and ds or "") ..
            "you have a detrimental physical effect", what = (automode == 4 and "auto-dis" or "auto-en-4") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 5 and ds or "") ..
            "you have a detrimental mental effect", what = (automode == 5 and "auto-dis" or "auto-en-5") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 6 and ds or "") ..
            "you have a detrimental magical effect", what = (automode == 6 and "auto-dis" or "auto-en-6") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 7 and ds or "") .. "you have any detrimental effect", what = (automode == 7 and "auto-dis" or "auto-en-7") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 8 and ds or "") .. "enemies are not visible and will deactivate if enemies appear", what = (automode == 8 and "auto-dis" or "auto-en-8") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 9 and ds or "") .. "enemies visible, and will deactivate if they are not", what = (automode == 9 and "auto-dis" or "auto-en-9") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 10 and ds or "") .. "enemies visible", what = (automode == 10 and "auto-dis" or "auto-en-10") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 11 and ds or "") .. "enemies visible & own hp>80%", what = (automode == 11 and "auto-dis" or "auto-en-11") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 12 and ds or "") .. "enemies visible & own hp<80%", what = (automode == 12 and "auto-dis" or "auto-en-12") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 13 and ds or "") .. "enemies visible & own hp>60%", what = (automode == 13 and "auto-dis" or "auto-en-13") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 14 and ds or "") .. "enemies visible & own hp<60%", what = (automode == 14 and "auto-dis" or "auto-en-14") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 15 and ds or "") .. "enemies visible & in range", what = (automode == 15 and "auto-dis" or "auto-en-15") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 16 and ds or "") .. "enemies visible & in range & own hp>80%", what = (automode == 16 and "auto-dis" or "auto-en-16") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 17 and ds or "") .. "enemies visible & in range & own hp<80%", what = (automode == 17 and "auto-dis" or "auto-en-17") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 18 and ds or "") .. "enemies visible & in range & own hp>60%", what = (automode == 18 and "auto-dis" or "auto-en-18") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 19 and ds or "") .. "enemies visible & in range & own hp<60%", what = (automode == 19 and "auto-dis" or "auto-en-19") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 20 and ds or "") .. "enemies visible & within 2 tiles", what = (automode == 20 and "auto-dis" or "auto-en-20") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 21 and ds or "") .. "enemies visible & within 2 tiles & own hp>80%", what = (automode == 21 and "auto-dis" or "auto-en-21") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 22 and ds or "") .. "enemies visible & within 2 tiles & own hp<80%", what = (automode == 22 and "auto-dis" or "auto-en-22") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 23 and ds or "") .. "enemies visible & within 2 tiles & own hp>60%", what = (automode == 23 and "auto-dis" or "auto-en-23") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 24 and ds or "") .. "enemies visible & within 2 tiles & own hp<60%", what = (automode == 24 and "auto-dis" or "auto-en-24") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 25 and ds or "") .. "enemies visible and adjacent", what = (automode == 25 and "auto-dis" or "auto-en-25") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 26 and ds or "") .. "enemies visible and adjacent & own hp>80%", what = (automode == 26 and "auto-dis" or "auto-en-26") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 27 and ds or "") .. "enemies visible and adjacent & own hp<80%", what = (automode == 27 and "auto-dis" or "auto-en-27") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 28 and ds or "") .. "enemies visible and adjacent & own hp>60%", what = (automode == 28 and "auto-dis" or "auto-en-28") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 29 and ds or "") .. "enemies visible and adjacent & own hp<60%", what = (automode == 29 and "auto-dis" or "auto-en-29") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 30 and ds or "") .. "no elites+", what = (automode == 30 and "auto-dis" or "auto-en-30") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 31 and ds or "") .. "no elites+ & own hp>80%", what = (automode == 31 and "auto-dis" or "auto-en-31") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 32 and ds or "") .. "no elites+ & own hp<80%", what = (automode == 32 and "auto-dis" or "auto-en-32") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 33 and ds or "") .. "no elites+ & own hp>60%", what = (automode == 33 and "auto-dis" or "auto-en-33") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 34 and ds or "") .. "no elites+ & own hp<60%", what = (automode == 34 and "auto-dis" or "auto-en-34") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 35 and ds or "") .. "no elites+ visible & in range", what = (automode == 35 and "auto-dis" or "auto-en-35") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 36 and ds or "") .. "no elites+ & in range & own hp>80%", what = (automode == 36 and "auto-dis" or "auto-en-36") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 37 and ds or "") .. "no elites+ & in range & own hp<80%", what = (automode == 37 and "auto-dis" or "auto-en-37") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 38 and ds or "") .. "no elites+ & in range & own hp>60%", what = (automode == 38 and "auto-dis" or "auto-en-38") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 39 and ds or "") .. "no elites+ & in range & own hp<60%", what = (automode == 39 and "auto-dis" or "auto-en-39") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 40 and ds or "") .. "no elites+ & within 2 tiles", what = (automode == 40 and "auto-dis" or "auto-en-40") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 41 and ds or "") .. "no elites+ & within 2 tiles & own hp>80%", what = (automode == 41 and "auto-dis" or "auto-en-41") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 42 and ds or "") .. "no elites+ & within 2 tiles & own hp<80%", what = (automode == 42 and "auto-dis" or "auto-en-42") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 43 and ds or "") .. "no elites+ & within 2 tiles & own hp>60%", what = (automode == 43 and "auto-dis" or "auto-en-43") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 44 and ds or "") .. "no elites+ & within 2 tiles & own hp<60%", what = (automode == 44 and "auto-dis" or "auto-en-44") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 45 and ds or "") .. "no elites+ and adjacent", what = (automode == 45 and "auto-dis" or "auto-en-45") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 46 and ds or "") ..
            "no elites+ and adjacent & own hp>80%", what = (automode == 46 and "auto-dis" or "auto-en-46") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 47 and ds or "") ..
            "no elites+ and adjacent & own hp<80%", what = (automode == 47 and "auto-dis" or "auto-en-47") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 48 and ds or "") ..
            "no elites+ and adjacent & own hp>60%", what = (automode == 48 and "auto-dis" or "auto-en-48") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 49 and ds or "") ..
            "no elites+ and adjacent & own hp<60%", what = (automode == 49 and "auto-dis" or "auto-en-49") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 50 and ds or "") .. "enemy can attack you this turn", what = (automode == 50 and "auto-dis" or "auto-en-50") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 51 and ds or "") .. "you are hp<80%", what = (automode == 51 and "auto-dis" or "auto-en-51") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 52 and ds or "") .. "you are hp<60%", what = (automode == 52 and "auto-dis" or "auto-en-52") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 53 and ds or "") ..
            "no elites+ & min 2 tile space & hp>80%", what = (automode == 53 and "auto-dis" or "auto-en-53") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 54 and ds or "") ..
            "no elites+ & min 2 tile space & hp>60%", what = (automode == 54 and "auto-dis" or "auto-en-54") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 55 and ds or "") .. "no elites+ & min 2 tile space but in range & hp>80%", what = (automode == 55 and "auto-dis" or "auto-en-55") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 56 and ds or "") .. "no elites+ & min 2 tile space but in range & hp>60%", what = (automode == 56 and "auto-dis" or "auto-en-56") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 104 and ds or "") .. "LCLICK you have a detrimental physical effect", what = (automode == 104 and "auto-dis" or "auto-en-104") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 105 and ds or "") .. "LCLICK you have a detrimental mental effect", what = (automode == 105 and "auto-dis" or "auto-en-105") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 106 and ds or "") .. "LCLICK you have a detrimental magical effect", what = (automode == 106 and "auto-dis" or "auto-en-106") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 107 and ds or "") .. "LCLICK you have any detrimental effect", what = (automode == 107 and "auto-dis" or "auto-en-107") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 109 and ds or "") .. "LCLICK when enemies are visible and will deactivate if they are not", what = (automode == 109 and "auto-dis" or "auto-en-109") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 111 and ds or "") .. "LCLICK & own hp>80%", what = (automode == 111 and "auto-dis" or "auto-en-111") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 112 and ds or "") .. "LCLICK & own hp<80%", what = (automode == 112 and "auto-dis" or "auto-en-112") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 113 and ds or "") .. "LCLICK & own hp>60%", what = (automode == 113 and "auto-dis" or "auto-en-113") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 114 and ds or "") .. "LCLICK & own hp<60%", what = (automode == 114 and "auto-dis" or "auto-en-114") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 116 and ds or "") .. "LCLICK & in range & own hp>80%", what = (automode == 116 and "auto-dis" or "auto-en-116") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 117 and ds or "") .. "LCLICK & in range & own hp<80%", what = (automode == 117 and "auto-dis" or "auto-en-117") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 118 and ds or "") .. "LCLICK & in range & own hp>60%", what = (automode == 118 and "auto-dis" or "auto-en-118") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 119 and ds or "") .. "LCLICK & in range & own hp<60%", what = (automode == 119 and "auto-dis" or "auto-en-119") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 120 and ds or "") .. "LCLICK & within 2 tiles", what = (automode == 120 and "auto-dis" or "auto-en-120") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 121 and ds or "") ..
            "LCLICK & within 2 tiles & own hp>80%", what = (automode == 121 and "auto-dis" or "auto-en-121") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 122 and ds or "") ..
            "LCLICK & within 2 tiles & own hp<80%", what = (automode == 122 and "auto-dis" or "auto-en-122") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 123 and ds or "") ..
            "LCLICK & within 2 tiles & own hp>60%", what = (automode == 123 and "auto-dis" or "auto-en-123") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 124 and ds or "") ..
            "LCLICK & within 2 tiles & own hp<60%", what = (automode == 124 and "auto-dis" or "auto-en-124") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 125 and ds or "") .. "LCLICK and adjacent", what = (automode == 125 and "auto-dis" or "auto-en-125") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 126 and ds or "") .. "LCLICK and adjacent & own hp>80%", what = (automode == 126 and "auto-dis" or "auto-en-126") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 127 and ds or "") .. "LCLICK and adjacent & own hp<80%", what = (automode == 127 and "auto-dis" or "auto-en-127") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 128 and ds or "") .. "LCLICK and adjacent & own hp>60%", what = (automode == 128 and "auto-dis" or "auto-en-128") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 129 and ds or "") .. "LCLICK and adjacent & own hp<60%", what = (automode == 129 and "auto-dis" or "auto-en-129") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 130 and ds or "") .. "LCLICK no elites+", what = (automode == 130 and "auto-dis" or "auto-en-130") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 131 and ds or "") .. "LCLICK no elites+ & own hp>80%", what = (automode == 131 and "auto-dis" or "auto-en-131") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 132 and ds or "") .. "LCLICK no elites+ & own hp<80%", what = (automode == 132 and "auto-dis" or "auto-en-132") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 133 and ds or "") .. "LCLICK no elites+ & own hp>60%", what = (automode == 133 and "auto-dis" or "auto-en-133") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 134 and ds or "") .. "LCLICK no elites+ & own hp<60%", what = (automode == 134 and "auto-dis" or "auto-en-134") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 135 and ds or "") ..
            "LCLICK no elites+ visible & in range", what = (automode == 135 and "auto-dis" or "auto-en-135") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 136 and ds or "") .. "LCLICK no elites+ & in range & own hp>80%", what = (automode == 136 and "auto-dis" or "auto-en-136") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 137 and ds or "") .. "LCLICK no elites+ & in range & own hp<80%", what = (automode == 137 and "auto-dis" or "auto-en-137") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 138 and ds or "") .. "LCLICK no elites+ & in range & own hp>60%", what = (automode == 138 and "auto-dis" or "auto-en-138") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 139 and ds or "") .. "LCLICK no elites+ & in range & own hp<60%", what = (automode == 139 and "auto-dis" or "auto-en-139") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 140 and ds or "") ..
            "LCLICK no elites+ & within 2 tiles", what = (automode == 140 and "auto-dis" or "auto-en-140") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 141 and ds or "") .. "LCLICK no elites+ & within 2 tiles & own hp>80%", what = (automode == 141 and "auto-dis" or "auto-en-141") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 142 and ds or "") .. "LCLICK no elites+ & within 2 tiles & own hp<80%", what = (automode == 142 and "auto-dis" or "auto-en-142") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 143 and ds or "") .. "LCLICK no elites+ & within 2 tiles & own hp>60%", what = (automode == 143 and "auto-dis" or "auto-en-143") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 144 and ds or "") .. "LCLICK no elites+ & within 2 tiles & own hp<60%", what = (automode == 144 and "auto-dis" or "auto-en-144") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() .. (automode == 145 and ds or "") .. "LCLICK no elites+ and adjacent", what = (automode == 145 and "auto-dis" or "auto-en-145") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 146 and ds or "") .. "LCLICK no elites+ and adjacent & own hp>80%", what = (automode == 146 and "auto-dis" or "auto-en-146") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 147 and ds or "") .. "LCLICK no elites+ and adjacent & own hp<80%", what = (automode == 147 and "auto-dis" or "auto-en-147") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 148 and ds or "") .. "LCLICK no elites+ and adjacent & own hp>60%", what = (automode == 148 and "auto-dis" or "auto-en-148") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 149 and ds or "") .. "LCLICK no elites+ and adjacent & own hp<60%", what = (automode == 149 and "auto-dis" or "auto-en-149") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 150 and ds or "") .. "LCLICK when enemy can attack you this turn", what = (automode == 150 and "auto-dis" or "auto-en-150") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 153 and ds or "") .. "LCLICK no elites+ & min 2 tile space & hp>80%", what = (automode == 153 and "auto-dis" or "auto-en-153") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 154 and ds or "") .. "LCLICK no elites+ & min 2 tile space & hp>60%", what = (automode == 154 and "auto-dis" or "auto-en-154") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 155 and ds or "") .. "LCLICK no elites+ & min 2 tile space but in range & hp>80%", what = (automode == 155 and "auto-dis" or "auto-en-155") })
        table.insert(list, #list,
            { name = autoMark:getDisplayString() ..
            (automode == 156 and ds or "") .. "LCLICK no elites+ & min 2 tile space but in range & hp>60%", what = (automode == 156 and "auto-dis" or "auto-en-156") })
        self:triggerHook { "UseTalents:generate", actor = self.actor, talent = t, menu = list }

        for i = 1, 12 * self.actor.nb_hotkey_pages do list[#list + 1] = { name = "Hotkey " .. i, what = i } end
        Dialog:listPopup("Bind talent: " .. item.name:toString(), "How do you want to bind this talent?", list, 400, 500,
            function(b)
                if not b then return end
                if type(b.what) == "number" then
                    for i = 1, 12 * self.actor.nb_hotkey_pages do
                        if self.actor.hotkey[i] and self.actor.hotkey[i][1] == "talent" and self.actor.hotkey[i][2] == item.talent then self.actor.hotkey[i] = nil end
                    end
                    self.actor.hotkey[b.what] = { "talent", item.talent }
                    self:simplePopup("Hotkey " .. b.what .. " assigned",
                        self.actor:getTalentFromId(item.talent).name:capitalize() .. " assigned to hotkey " .. b.what)
                elseif b.what == "middle" then
                    self.actor.auto_shoot_midclick_talent = item.talent
                    self:simplePopup("Middle mouse click assigned",
                        self.actor:getTalentFromId(item.talent).name:capitalize() ..
                        " assigned to middle mouse click on an hostile target.")
                elseif b.what == "left" then
                    self.actor.auto_shoot_talent = item.talent
                    self:simplePopup("Left mouse click assigned",
                        self.actor:getTalentFromId(item.talent).name:capitalize() ..
                        " assigned to left mouse click on an hostile target.")
                elseif b.what == "unbind" then
                    if self.actor.auto_shoot_talent == item.talent then self.actor.auto_shoot_talent = nil end
                    if self.actor.auto_shoot_midclick_talent == item.talent then self.actor.auto_shoot_midclick_talent = nil end
                    for i = 1, 12 * self.actor.nb_hotkey_pages do
                        if self.actor.hotkey[i] and self.actor.hotkey[i][1] == "talent" and self.actor.hotkey[i][2] == item.talent then self.actor.hotkey[i] = nil end
                    end
                elseif b.what == "set-confirm" then
                    self.actor:setTalentConfirmable(item.talent, true)
                elseif b.what == "unset-confirm" then
                    self.actor:setTalentConfirmable(item.talent, false)
                elseif b.what == "auto-en-1" then
                    self.actor:checkSetTalentAuto(item.talent, true, 1)
                elseif b.what == "auto-en-2" then
                    self.actor:checkSetTalentAuto(item.talent, true, 2)
                elseif b.what == "auto-en-3" then
                    self.actor:checkSetTalentAuto(item.talent, true, 3)
                elseif b.what == "auto-en-4" then
                    self.actor:checkSetTalentAuto(item.talent, true, 4)
                elseif b.what == "auto-en-5" then
                    self.actor:checkSetTalentAuto(item.talent, true, 5)
                elseif b.what == "auto-en-6" then
                    self.actor:checkSetTalentAuto(item.talent, true, 6)
                elseif b.what == "auto-en-7" then
                    self.actor:checkSetTalentAuto(item.talent, true, 7)
                elseif b.what == "auto-en-8" then
                    self.actor:checkSetTalentAuto(item.talent, true, 8)
                elseif b.what == "auto-en-9" then
                    self.actor:checkSetTalentAuto(item.talent, true, 9)
                elseif b.what == "auto-en-10" then
                    self.actor:checkSetTalentAuto(item.talent, true, 10)
                elseif b.what == "auto-en-11" then
                    self.actor:checkSetTalentAuto(item.talent, true, 11)
                elseif b.what == "auto-en-12" then
                    self.actor:checkSetTalentAuto(item.talent, true, 12)
                elseif b.what == "auto-en-13" then
                    self.actor:checkSetTalentAuto(item.talent, true, 13)
                elseif b.what == "auto-en-14" then
                    self.actor:checkSetTalentAuto(item.talent, true, 14)
                elseif b.what == "auto-en-15" then
                    self.actor:checkSetTalentAuto(item.talent, true, 15)
                elseif b.what == "auto-en-16" then
                    self.actor:checkSetTalentAuto(item.talent, true, 16)
                elseif b.what == "auto-en-17" then
                    self.actor:checkSetTalentAuto(item.talent, true, 17)
                elseif b.what == "auto-en-18" then
                    self.actor:checkSetTalentAuto(item.talent, true, 18)
                elseif b.what == "auto-en-19" then
                    self.actor:checkSetTalentAuto(item.talent, true, 19)
                elseif b.what == "auto-en-20" then
                    self.actor:checkSetTalentAuto(item.talent, true, 20)
                elseif b.what == "auto-en-21" then
                    self.actor:checkSetTalentAuto(item.talent, true, 21)
                elseif b.what == "auto-en-22" then
                    self.actor:checkSetTalentAuto(item.talent, true, 22)
                elseif b.what == "auto-en-23" then
                    self.actor:checkSetTalentAuto(item.talent, true, 23)
                elseif b.what == "auto-en-24" then
                    self.actor:checkSetTalentAuto(item.talent, true, 24)
                elseif b.what == "auto-en-25" then
                    self.actor:checkSetTalentAuto(item.talent, true, 25)
                elseif b.what == "auto-en-26" then
                    self.actor:checkSetTalentAuto(item.talent, true, 26)
                elseif b.what == "auto-en-27" then
                    self.actor:checkSetTalentAuto(item.talent, true, 27)
                elseif b.what == "auto-en-28" then
                    self.actor:checkSetTalentAuto(item.talent, true, 28)
                elseif b.what == "auto-en-29" then
                    self.actor:checkSetTalentAuto(item.talent, true, 29)
                elseif b.what == "auto-en-30" then
                    self.actor:checkSetTalentAuto(item.talent, true, 30)
                elseif b.what == "auto-en-31" then
                    self.actor:checkSetTalentAuto(item.talent, true, 31)
                elseif b.what == "auto-en-32" then
                    self.actor:checkSetTalentAuto(item.talent, true, 32)
                elseif b.what == "auto-en-33" then
                    self.actor:checkSetTalentAuto(item.talent, true, 33)
                elseif b.what == "auto-en-34" then
                    self.actor:checkSetTalentAuto(item.talent, true, 34)
                elseif b.what == "auto-en-35" then
                    self.actor:checkSetTalentAuto(item.talent, true, 35)
                elseif b.what == "auto-en-36" then
                    self.actor:checkSetTalentAuto(item.talent, true, 36)
                elseif b.what == "auto-en-37" then
                    self.actor:checkSetTalentAuto(item.talent, true, 37)
                elseif b.what == "auto-en-38" then
                    self.actor:checkSetTalentAuto(item.talent, true, 38)
                elseif b.what == "auto-en-39" then
                    self.actor:checkSetTalentAuto(item.talent, true, 39)
                elseif b.what == "auto-en-40" then
                    self.actor:checkSetTalentAuto(item.talent, true, 40)
                elseif b.what == "auto-en-41" then
                    self.actor:checkSetTalentAuto(item.talent, true, 41)
                elseif b.what == "auto-en-42" then
                    self.actor:checkSetTalentAuto(item.talent, true, 42)
                elseif b.what == "auto-en-43" then
                    self.actor:checkSetTalentAuto(item.talent, true, 43)
                elseif b.what == "auto-en-44" then
                    self.actor:checkSetTalentAuto(item.talent, true, 44)
                elseif b.what == "auto-en-45" then
                    self.actor:checkSetTalentAuto(item.talent, true, 45)
                elseif b.what == "auto-en-46" then
                    self.actor:checkSetTalentAuto(item.talent, true, 46)
                elseif b.what == "auto-en-47" then
                    self.actor:checkSetTalentAuto(item.talent, true, 47)
                elseif b.what == "auto-en-48" then
                    self.actor:checkSetTalentAuto(item.talent, true, 48)
                elseif b.what == "auto-en-49" then
                    self.actor:checkSetTalentAuto(item.talent, true, 49)
                elseif b.what == "auto-en-50" then
                    self.actor:checkSetTalentAuto(item.talent, true, 50)
                elseif b.what == "auto-en-51" then
                    self.actor:checkSetTalentAuto(item.talent, true, 51)
                elseif b.what == "auto-en-52" then
                    self.actor:checkSetTalentAuto(item.talent, true, 52)
                elseif b.what == "auto-en-53" then
                    self.actor:checkSetTalentAuto(item.talent, true, 53)
                elseif b.what == "auto-en-54" then
                    self.actor:checkSetTalentAuto(item.talent, true, 54)
                elseif b.what == "auto-en-55" then
                    self.actor:checkSetTalentAuto(item.talent, true, 55)
                elseif b.what == "auto-en-56" then
                    self.actor:checkSetTalentAuto(item.talent, true, 56)
                elseif b.what == "auto-en-57" then
                    self.actor:checkSetTalentAuto(item.talent, true, 57)
                elseif b.what == "auto-en-101" then
                    self.actor:checkSetTalentAuto(item.talent, true, 101)
                elseif b.what == "auto-en-102" then
                    self.actor:checkSetTalentAuto(item.talent, true, 102)
                elseif b.what == "auto-en-103" then
                    self.actor:checkSetTalentAuto(item.talent, true, 103)
                elseif b.what == "auto-en-104" then
                    self.actor:checkSetTalentAuto(item.talent, true, 104)
                elseif b.what == "auto-en-105" then
                    self.actor:checkSetTalentAuto(item.talent, true, 105)
                elseif b.what == "auto-en-106" then
                    self.actor:checkSetTalentAuto(item.talent, true, 106)
                elseif b.what == "auto-en-107" then
                    self.actor:checkSetTalentAuto(item.talent, true, 107)
                elseif b.what == "auto-en-108" then
                    self.actor:checkSetTalentAuto(item.talent, true, 108)
                elseif b.what == "auto-en-109" then
                    self.actor:checkSetTalentAuto(item.talent, true, 109)
                elseif b.what == "auto-en-110" then
                    self.actor:checkSetTalentAuto(item.talent, true, 110)
                elseif b.what == "auto-en-111" then
                    self.actor:checkSetTalentAuto(item.talent, true, 111)
                elseif b.what == "auto-en-112" then
                    self.actor:checkSetTalentAuto(item.talent, true, 112)
                elseif b.what == "auto-en-113" then
                    self.actor:checkSetTalentAuto(item.talent, true, 113)
                elseif b.what == "auto-en-114" then
                    self.actor:checkSetTalentAuto(item.talent, true, 114)
                elseif b.what == "auto-en-115" then
                    self.actor:checkSetTalentAuto(item.talent, true, 115)
                elseif b.what == "auto-en-116" then
                    self.actor:checkSetTalentAuto(item.talent, true, 116)
                elseif b.what == "auto-en-117" then
                    self.actor:checkSetTalentAuto(item.talent, true, 117)
                elseif b.what == "auto-en-118" then
                    self.actor:checkSetTalentAuto(item.talent, true, 118)
                elseif b.what == "auto-en-119" then
                    self.actor:checkSetTalentAuto(item.talent, true, 119)
                elseif b.what == "auto-en-120" then
                    self.actor:checkSetTalentAuto(item.talent, true, 120)
                elseif b.what == "auto-en-121" then
                    self.actor:checkSetTalentAuto(item.talent, true, 121)
                elseif b.what == "auto-en-122" then
                    self.actor:checkSetTalentAuto(item.talent, true, 122)
                elseif b.what == "auto-en-123" then
                    self.actor:checkSetTalentAuto(item.talent, true, 123)
                elseif b.what == "auto-en-124" then
                    self.actor:checkSetTalentAuto(item.talent, true, 124)
                elseif b.what == "auto-en-125" then
                    self.actor:checkSetTalentAuto(item.talent, true, 125)
                elseif b.what == "auto-en-126" then
                    self.actor:checkSetTalentAuto(item.talent, true, 126)
                elseif b.what == "auto-en-127" then
                    self.actor:checkSetTalentAuto(item.talent, true, 127)
                elseif b.what == "auto-en-128" then
                    self.actor:checkSetTalentAuto(item.talent, true, 128)
                elseif b.what == "auto-en-129" then
                    self.actor:checkSetTalentAuto(item.talent, true, 129)
                elseif b.what == "auto-en-130" then
                    self.actor:checkSetTalentAuto(item.talent, true, 130)
                elseif b.what == "auto-en-131" then
                    self.actor:checkSetTalentAuto(item.talent, true, 131)
                elseif b.what == "auto-en-132" then
                    self.actor:checkSetTalentAuto(item.talent, true, 132)
                elseif b.what == "auto-en-133" then
                    self.actor:checkSetTalentAuto(item.talent, true, 133)
                elseif b.what == "auto-en-134" then
                    self.actor:checkSetTalentAuto(item.talent, true, 134)
                elseif b.what == "auto-en-135" then
                    self.actor:checkSetTalentAuto(item.talent, true, 135)
                elseif b.what == "auto-en-136" then
                    self.actor:checkSetTalentAuto(item.talent, true, 136)
                elseif b.what == "auto-en-137" then
                    self.actor:checkSetTalentAuto(item.talent, true, 137)
                elseif b.what == "auto-en-138" then
                    self.actor:checkSetTalentAuto(item.talent, true, 138)
                elseif b.what == "auto-en-139" then
                    self.actor:checkSetTalentAuto(item.talent, true, 139)
                elseif b.what == "auto-en-140" then
                    self.actor:checkSetTalentAuto(item.talent, true, 140)
                elseif b.what == "auto-en-141" then
                    self.actor:checkSetTalentAuto(item.talent, true, 141)
                elseif b.what == "auto-en-142" then
                    self.actor:checkSetTalentAuto(item.talent, true, 142)
                elseif b.what == "auto-en-143" then
                    self.actor:checkSetTalentAuto(item.talent, true, 143)
                elseif b.what == "auto-en-144" then
                    self.actor:checkSetTalentAuto(item.talent, true, 144)
                elseif b.what == "auto-en-145" then
                    self.actor:checkSetTalentAuto(item.talent, true, 145)
                elseif b.what == "auto-en-146" then
                    self.actor:checkSetTalentAuto(item.talent, true, 146)
                elseif b.what == "auto-en-147" then
                    self.actor:checkSetTalentAuto(item.talent, true, 147)
                elseif b.what == "auto-en-148" then
                    self.actor:checkSetTalentAuto(item.talent, true, 148)
                elseif b.what == "auto-en-149" then
                    self.actor:checkSetTalentAuto(item.talent, true, 149)
                elseif b.what == "auto-en-150" then
                    self.actor:checkSetTalentAuto(item.talent, true, 150)
                elseif b.what == "auto-en-151" then
                    self.actor:checkSetTalentAuto(item.talent, true, 151)
                elseif b.what == "auto-en-152" then
                    self.actor:checkSetTalentAuto(item.talent, true, 152)
                elseif b.what == "auto-en-153" then
                    self.actor:checkSetTalentAuto(item.talent, true, 153)
                elseif b.what == "auto-en-154" then
                    self.actor:checkSetTalentAuto(item.talent, true, 154)
                elseif b.what == "auto-en-155" then
                    self.actor:checkSetTalentAuto(item.talent, true, 155)
                elseif b.what == "auto-en-156" then
                    self.actor:checkSetTalentAuto(item.talent, true, 156)
                elseif b.what == "auto-en-157" then
                    self.actor:checkSetTalentAuto(item.talent, true, 157)
                elseif b.what == "auto-dis" then
                    self.actor:checkSetTalentAuto(item.talent, false)
                else
                    self:triggerHook { "UseTalents:use", what = b.what, actor = self.actor, talent = t, item = item }
                end
                self.c_list:drawTree()
                self.actor.changed = true
            end)
        self.c_list:drawTree()
        return
    end

    game:unregisterDialog(self)
    self.actor:useTalent(item.talent)
end

-- Display the player tile
function _M:innerDisplay(x, y, nb_keyframes)
    if self.cur_item and self.cur_item.entity then
        self.cur_item.entity:toScreen(game.uiset.hotkeys_display_icons.tiles, x + self.iw - 64,
            y + self.iy + self.c_tut.h - 32 + 10, 64, 64)
    end
end

function _M:generateList()
    -- Makes up the list
    local list = {}
    local letter = 1

    --[[
	for i, tt in ipairs(self.actor.talents_types_def) do
		local cat = tt.type:gsub("/.*", "")
		local where = #list
		local added = false
		local nodes = {}

		-- Find all talents of this school
		for j, t in ipairs(tt.talents) do
			if self.actor:knowTalent(t.id) and t.mode ~= "passive" then
				local typename = "talent"
				local status = tstring{{"color", "LIGHT_GREEN"}, "Active"}
				if self.actor:isTalentCoolingDown(t) then status = tstring{{"color", "LIGHT_RED"}, self.actor:isTalentCoolingDown(t).." turns"}
				elseif t.mode == "sustained" then status = self.actor:isTalentActive(t.id) and tstring{{"color", "YELLOW"}, "Sustaining"} or tstring{{"color", "LIGHT_GREEN"}, "Sustain"} end
				nodes[#nodes+1] = {
					char=self:makeKeyChar(letter),
					name=t.name.." ("..typename..")",
					status=status,
					talent=t.id,
					desc=self.actor:getTalentFullDescription(t),
					color=function() return {0xFF, 0xFF, 0xFF} end,
					hotkey=function(item)
						for i = 1, 12 * self.actor.nb_hotkey_pages do if self.actor.hotkey[i] and self.actor.hotkey[i][1] == "talent" and self.actor.hotkey[i][2] == item.talent then
							return "H.Key "..i..""
						end end
						return ""
					end,
				}
				list.chars[self:makeKeyChar(letter)] = nodes[#nodes]
				added = true
				letter = letter + 1
			end
		end

		if added then
			table.insert(list, where+1, {
				char="",
				name=tstring{{"font","bold"}, cat:capitalize().." / "..tt.name:capitalize(), {"font","normal"}},
				type=tt.type,
				color=function() return {0x80, 0x80, 0x80} end,
				status="",
				desc=tt.description,
				nodes=nodes,
				hotkey="",
				shown=true,
			})
		end
	end
]]

    local actives, sustains, sustained, objects, unavailables, cooldowns, passives = {}, {}, {}, {}, {}, {}, {}
    local chars = {}

    -- Generate lists of all talents by category
    for j, t in pairs(self.actor.talents_def) do
        if self.actor:knowTalent(t.id) and not (t.hide and t.mode == "passive") then
            local nodes = (t.mode == "sustained" and sustains) or (t.mode == "passive" and passives) or
            (t.is_object_use and objects) or actives
            if self.actor:isTalentCoolingDown(t) then
                nodes = cooldowns
            elseif not self.actor:preUseTalent(t, true, true) then
                nodes = unavailables
            elseif t.mode == "sustained" then
                if self.actor:isTalentActive(t.id) then nodes = sustained end
            elseif t.mode == "passive" then
                nodes = passives
            end
            local status = TalentStatus(self.actor, t)

            -- Pregenerate icon with the Tiles instance that allows images
            if t.display_entity then t.display_entity:getMapObjects(game.uiset.hotkeys_display_icons.tiles, {}, 1) end
            local tname = t.is_object_use and tostring(self.actor:getTalentDisplayName(t)) or t.name
            nodes[#nodes + 1] = {
                name = ((t.display_entity and t.display_entity:getDisplayString() or "") .. tname):toTString(),
                cname = tname,
                status = status,
                entity = t.display_entity,
                talent = t.id,
                desc = self.actor:getTalentFullDescription(t),
                color = function() return { 0xFF, 0xFF, 0xFF } end,
                hotkey = function(item)
                    if t.mode == "passive" then return "" end
                    for i = 1, 12 * self.actor.nb_hotkey_pages do
                        if self.actor.hotkey[i] and self.actor.hotkey[i][1] == "talent" and self.actor.hotkey[i][2] == item.talent then
                            return "H.Key " .. i .. ""
                        end
                    end
                    return ""
                end,
            }
        end
    end
    table.sort(actives, function(a, b) return a.cname < b.cname end)
    table.sort(sustains, function(a, b) return a.cname < b.cname end)
    table.sort(sustained, function(a, b) return a.cname < b.cname end)
    table.sort(objects, function(a, b) return a.cname < b.cname end)
    table.sort(cooldowns, function(a, b) return a.cname < b.cname end)
    table.sort(unavailables, function(a, b) return a.cname < b.cname end)
    table.sort(passives, function(a, b) return a.cname < b.cname end)
    for i, node in ipairs(actives) do
        node.char = self:makeKeyChar(letter)
        chars[node.char] = node
        letter = letter + 1
    end
    for i, node in ipairs(sustains) do
        node.char = self:makeKeyChar(letter)
        chars[node.char] = node
        letter = letter + 1
    end
    for i, node in ipairs(sustained) do
        node.char = self:makeKeyChar(letter)
        chars[node.char] = node
        letter = letter + 1
    end
    for i, node in ipairs(objects) do
        node.char = self:makeKeyChar(letter)
        chars[node.char] = node
        letter = letter + 1
    end
    for i, node in ipairs(cooldowns) do
        node.char = self:makeKeyChar(letter)
        chars[node.char] = node
        letter = letter + 1
    end
    for i, node in ipairs(unavailables) do
        node.char = self:makeKeyChar(letter)
        chars[node.char] = node
        letter = letter + 1
    end
    for i, node in ipairs(passives) do node.char = "" end

    list = {
        { char = '', name = ('#{bold}#Activable talents#{normal}#'):toTString(), status = '', hotkey = '', desc = "All activable talents you can currently use.",                                                                                           color = function() return
            colors.simple(colors.LIGHT_GREEN) end,                                                                                                                                                                                                                                                                         nodes = actives,    shown = true },
        { char = '', name = ('#{bold}#Object powers#{normal}#'):toTString(),    status = '', hotkey = '', desc = "Object powers that can be activated automatically.  Most usable objects will appear here unless they are on cooldown or have ai restrictions.", color = function() return
            colors.simple(colors.SALMON) end,                                                                                                                                                                                                                                                                              nodes = objects,    shown = true },
        { char = '', name = ('#{bold}#Sustainable talents#{normal}#'):toTString(), status = '', hotkey = '', desc = "All sustainable talents you can currently use.",                                                                                       color = function() return
            colors.simple(colors.LIGHT_GREEN) end,                                                                                                                                                                                                                                                                         nodes = sustains,   shown = true },
        { char = '', name = ('#{bold}#Sustained talents#{normal}#'):toTString(), status = '', hotkey = '', desc = "All sustainable talents you currently sustain, using them will de-activate them.",                                                       color = function() return
            colors.simple(colors.YELLOW) end,                                                                                                                                                                                                                                                                              nodes = sustained,  shown = true },
        { char = '', name = ('#{bold}#Cooling down talents#{normal}#'):toTString(), status = '', hotkey = '', desc = "All talents you have used that are still cooling down.",                                                                              color = function() return
            colors.simple(colors.LIGHT_RED) end,                                                                                                                                                                                                                                                                           nodes = cooldowns,  shown = true },
        { char = '', name = ('#{bold}#Unavailable talents#{normal}#'):toTString(), status = '', hotkey = '', desc = "All talents you have that do not have enough resources, or satisfy other dependencies.",                                               color = function() return
            colors.simple(colors.GREY) end,                                                                                                                                                                                                                                                                                nodes = unavailables, shown = true },
        { char = '', name = ('#{bold}#Passive talents#{normal}#'):toTString(),  status = '', hotkey = '', desc = "All your passive talents, they are always active.",                                                                                       color = function() return
            colors.simple(colors.WHITE) end,                                                                                                                                                                                                                                                                               nodes = passives,   shown = true },
        chars = chars,
    }
    self.list = list
end
