-- $Id: WishListDialog.lua 405 2013-07-05 23:42:36Z dsb $
-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2012 Scott Bigham
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
-- Scott Bigham ("Zizzo")
-- dsb-tome@killerbunnies.org

--TODO
--REFRESH LIST BASED ON current skills everytime the view is opend
--Toggle sort order on and off

require 'engine.class'
local Dialog = require 'engine.ui.Dialog'
local ListColumns = require 'engine.ui.ListColumns'
local Textzone = require "engine.ui.Textzone"
local TextzoneList = require "engine.ui.TextzoneList"
local Separator = require 'engine.ui.Separator'

module(..., package.seeall, class.inherit(Dialog))

_M.block_notify = 0
_M.pending_notify = false

function _M:init(game)
  self.talents_auto = table.copy(game.player.talents_auto)
  self.talents_auto_order = game.player.talents_auto_order or {}
  if game.player.talents_auto_ordering_off == nil then game.player.talents_auto_ordering_off = False end

  -- game.log("")
  -- game.log("")
  -- game.log("Order Before")
  -- for index, talent in ipairs(self.talents_auto_order) do
  --   game.log(index..":"..talent)
  -- end

  -- game.log("Generating Order List!")
  local talents_auto_order_new = {}
  local talents_auto_temp = self.talents_auto
  for index, talent in ipairs(self.talents_auto_order) do
    local temp = talents_auto_temp[talent] or "false"
    -- game.log("Finding:"..talent.."+"..temp)
    if talents_auto_temp[talent] ~= nil then
      -- game.log("Matched")
      table.insert(talents_auto_order_new, talent)
      talents_auto_temp[talent] = nil
    end
  end
  for k,v in pairs(talents_auto_temp) do
    -- game.log("Did not find Tallent:"..k.." adding it to final list")
    table.insert(talents_auto_order_new, k) end
  self.talents_auto_order = talents_auto_order_new

  -- game.log("Order After")
  -- for index, talent in ipairs(self.talents_auto_order) do
  --   game.log(index..":"..talent)
  -- end

  -- if game.player.talents_auto and #self.talents_auto_order == 0 then
  --   for talent_id, use_type in pairs(game.player.talents_auto) do
  --     table.insert(self.talents_auto_order, talent_id)
  --   end
  -- end

  Dialog.init(self, 'Auto-use Talent Ordering', math.max(800, game.w*0.8), math.max(600, game.h*0.8))

  self.c_note = Textzone.new {
    width = math.floor(self.iw * 0.65 - 10),
    auto_height = true,
    text = string.toTString [[#SLATE#You can re-order items in your list using the #00FF00#Shift-Up#LAST# and #00FF00#Shift-Down#LAST# keys]]
  }
  self.talent_c_list = ListColumns.new {
    width = math.floor(self.iw * 0.65 - 10),
    height = self.ih - self.c_note.h - 20,
    columns = {
      { name = 'Talent', width = 30, display_prop = 'display_name', sort='idx' },
      -- TODO Maybe mimic Inventory Order's sort order for this column.
      { name = 'Type', width = 9, display_prop = 'type', sort = 'type' },
      { name = 'Range', width = 9, display_prop = 'range', sort = 'range' },
      { name = 'Radius', width = 9, display_prop = 'radius', sort = 'radius' },
      { name = 'Cooldown', width = 13, display_prop = 'cooldown', sort = 'cooldown' },
      { name = 'UsageSpeed', width = 15, display_prop = 'usage_speed', sort = 'usage_speed' },
    },
    sortable = false,
    scrollbar = true,
    list = {},
    fct = function(item) local menu = require("mod.dialogs.AutoUseOptions").new(item)
    game:registerDialog(menu) end,
    select = function(item, sel) self:selectItem(item) end,
  }
  self.c_desc = TextzoneList.new {
    width = math.floor(self.iw * 0.35 - 15),
    height = self.ih - 10,
    no_color_bleed = true,
  }

  self:generateList()

  local sep = Separator.new { dir = 'horizontal', size = self.ih - 10 }
  self:loadUI {
    { left = 0, top = 0, ui = self.c_note },
    { left = 0, top = self.c_note.h + 10, ui = self.talent_c_list },
    { right = 0, top = 0, ui = self.c_desc },
    { left = self.iw * 0.65 - 5, top = 0, ui = sep },
  }
  self:setFocus(self.talent_c_list)
  self:setupUI()

  self.key:addBinds {
    EXIT = function()
      game:unregisterDialog(self)
      --game.player.talents_auto = self.talents_auto
      game.player.talents_auto_order = self.talents_auto_order
    end
  }
  self.talent_c_list.key:addCommands {
    [{'_UP','shift'}] = function() self:moveItem(-1) end,
    [{'_DOWN','shift'}] = function() self:moveItem(1) end,
  }
 --  self.key.any_key = function(sym)
 --    -- Re-select when the <Ctrl> key is pressed, to toggle between normal
 --    -- and compare-with-equipment object descriptions.
 --    if sym == self.key._LCTRL or sym == self.key._RCTRL then
 --      local ctrl = core.key.modState('ctrl')
 --      if self.prev_ctrl ~= ctrl then
	-- local item = self.talent_c_list.list[self.talent_c_list.sel]
	-- self:selectItem(item)
 --      end
 --      self.prev_ctrl = ctrl
 --    end
 --  end
end

function _M:moveItem(delta)
  --game.log("moveItem("..delta..")")
  self.talent_c_list.last_input_was_keyboard = true
  if self.talent_c_list.sel < 1 or self.talent_c_list.sel > #self.talents_auto_order then return end
  local newpos = util.minBound(self.talent_c_list.sel + delta, 1, #self.talents_auto_order)
  if newpos == self.talent_c_list.sel then return end
  local item = table.remove(self.talents_auto_order, self.talent_c_list.sel)
  table.insert(self.talents_auto_order, newpos, item)
  -- self.talents_auto_order.by_name = {}
  -- for i = 1, #self.talents_auto_order do
  --   self.talents_auto_order.by_name[self.talents_auto_order[i].name] = i
  -- end
  self:generateList()
  self.talent_c_list.sel = newpos
  self:selectItem(self.talent_c_list.list[self.talent_c_list.sel])
end

-- function _M:removeItem(item)
--   local cb = function(f)
--     if f then
--       table.remove(self.talents_auto, item.idx)
--       self.talents_auto.by_name = {}
--       for i = 1, #self.talents_auto do
-- 	self.talents_auto.by_name[self.talents_auto[i].name] = i
--       end
--       self:generateList()
--       self:selectItem(self.talent_c_list.list[self.talent_c_list.sel])
--     end
--   end
--   Dialog:yesnoPopup('Remove Item', 'Remove item '..item.name..' from your wish list?', cb)
-- end

function _M:selectItem(item)
  if item then
    local talent = game.player.talents_def[item.name]
    local desc = game.player:getTalentFullDescription(talent)
    self.c_desc:switchItem(item, desc, true)
  else
    self.c_desc:switchItem('', '')
  end
end

function _M:generateList()
  local list = {}
  for index, talent_id in ipairs(self.talents_auto_order) do
    local talent = game.player.talents_def[talent_id]
    local entry = {}
    if talent then
      local usage = 1
      if talent.no_energy then usage = 0 end
      entry = {
        idx = index,
        display_name = game.player:getTalentDisplayName(talent),
        name = talent_id,
      type = self.talents_auto[talent_id],
        range = game.player:getTalentRange(talent),
        radius = game.player:getTalentRadius(talent),
        cooldown = game.player:getTalentCooldown(talent),
        usage_speed = usage,
      }
    else
      entry = {
        idx = index,
        display_name = talent_id,
        name = talent_id,
        range = 1,
        radius = 1,
        cooldown = "?",
        usage_speed = 1,
      }
    end
    table.insert(list, entry)
  end
  self.list = list
  self.talent_c_list:setList(self.list)
end

function table.copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end
