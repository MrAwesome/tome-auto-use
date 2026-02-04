local _M = loadPrevious(...)

local Faction = require "engine.Faction"
local Dialog = require "engine.ui.Dialog"
local Map = require "engine.Map"
local DamageType = require "engine.DamageType"

--- Setups a talent automatic use
function _M:checkSetTalentAuto(tid, v, opt)
    local inventory = false
    local t = self:getTalentFromId(tid)
    if not t then
        local o = game.player:findInAllInventories(tid,{no_add_name=true,force_id=true,no_count=true})
        if o and o.use_talent and o.use_talent.id then
            local item_talent_id = o.use_talent.id
            --game.log(item_talent_id)
            t = game.player:getTalentFromId(item_talent_id)
        elseif o and o.use_power then
            --game.log("Actor:CheckSetTalentAuto: item is power based do something?")
            --NOTE not sure if all items require a turn, dont have a target, and use a warning but we are setting them to no for now.
            t = {name=tid, no_energy=false, requires_target=false,auto_use_warning=false}
        end
        inventory = true
    end

    if v then
        local doit = function()
            self:setTalentAuto(tid, true, opt)
            Dialog:simplePopup("Automatic use enabled", t.name:capitalize().." will now be used as often as possible automatically.")
        end

        local list = {}
        if not t then
            --game.log("Skipping t calls in Actor")
        end
        if t and t.no_energy ~= true then list[#list+1] = "- requires a turn to use" end
        if t and t.requires_target then list[#list+1] = "- requires a target, your last hostile one will be automatically used" end
        if t and t.auto_use_warning then list[#list+1] = t.auto_use_warning end
        if opt == 2 then
            list[#list+1] = "- will only trigger if no enemies are visible"
            list[#list+1] = "- will automatically target you if a target is required"
        end
        if opt == 3 then list[#list+1] = "- you are currently resting" end  
        if opt == 4 then list[#list+1] = "- you have a detrimental physical effect" end
        if opt == 5 then list[#list+1] = "- you have a detrimental mental effect" end
		if opt == 6 then list[#list+1] = "- you have a detrimental magical effect" end
		if opt == 7 then list[#list+1] = "- you have any detrimental effect" end
		if opt == 8 then list[#list+1] = "- enemies are not visible and will deactivate if enemies appear" end
		if opt == 9 then list[#list+1] = "- enemies are visible, and will deactivate if they are not" end
		if opt == 10 then list[#list+1] = "- enemies" end
		if opt == 11 then list[#list+1] = "- enemies and you are above 80% hp" end
		if opt == 12 then list[#list+1] = "- enemies and you are below 80% hp" end
		if opt == 13 then list[#list+1] = "- enemies and you are above 60% hp" end
		if opt == 14 then list[#list+1] = "- enemies and you are below 60% hp" end
		if opt == 15 then list[#list+1] = "- enemies and in range" end
		if opt == 16 then list[#list+1] = "- enemies and in range and you are above 80% hp" end
		if opt == 17 then list[#list+1] = "- enemies and in range and you are below 80% hp" end
		if opt == 18 then list[#list+1] = "- enemies and in range and you are above 60% hp" end
		if opt == 19 then list[#list+1] = "- enemies and in range and you are below 60% hp" end
		if opt == 20 then list[#list+1] = "- enemies and within two tiles" end
		if opt == 21 then list[#list+1] = "- enemies and within two tiles and you are above 80% hp" end
		if opt == 22 then list[#list+1] = "- enemies and within two tiles and you are below 80% hp" end
		if opt == 23 then list[#list+1] = "- enemies and within two tiles and you are above 60% hp" end
		if opt == 24 then list[#list+1] = "- enemies and within two tiles and you are below 60% hp" end
		if opt == 25 then list[#list+1] = "- enemies and adjacent" end
		if opt == 26 then list[#list+1] = "- enemies and adjacent and you are above 80% hp" end
		if opt == 27 then list[#list+1] = "- enemies and adjacent and you are below 80% hp" end
		if opt == 28 then list[#list+1] = "- enemies and adjacent and you are above 60% hp" end
		if opt == 29 then list[#list+1] = "- enemies and adjacent and you are below 60% hp" end
		if opt == 30 then list[#list+1] = "- enemies but no elites" end
		if opt == 31 then list[#list+1] = "- enemies but no elites and above 80% hp" end
		if opt == 32 then list[#list+1] = "- enemies but no elites and below 80% hp" end
		if opt == 33 then list[#list+1] = "- enemies but no elites and above 60% hp" end
		if opt == 34 then list[#list+1] = "- enemies but no elites and below 60% hp" end
		if opt == 35 then list[#list+1] = "- enemies but no elites and in range" end
		if opt == 36 then list[#list+1] = "- enemies but no elites and in range and above 80% hp" end
		if opt == 37 then list[#list+1] = "- enemies but no elites and in range and below 80% hp" end
		if opt == 38 then list[#list+1] = "- enemies but no elites and in range and above 60% hp" end
		if opt == 39 then list[#list+1] = "- enemies but no elites and in range and below 60% hp" end
		if opt == 40 then list[#list+1] = "- enemies but no elites and within two tiles" end
		if opt == 41 then list[#list+1] = "- enemies but no elites and within two tiles and above 80% hp" end
		if opt == 42 then list[#list+1] = "- enemies but no elites and within two tiles and below 80% hp" end
		if opt == 43 then list[#list+1] = "- enemies but no elites and within two tiles and above 60% hp" end
		if opt == 44 then list[#list+1] = "- enemies but no elites and within two tiles and below 60% hp" end
		if opt == 45 then list[#list+1] = "- enemies but no elites and adjacent" end
		if opt == 46 then list[#list+1] = "- enemies but no elites and adjacent and above 80% hp" end
		if opt == 47 then list[#list+1] = "- enemies but no elites and adjacent and below 80% hp" end
		if opt == 48 then list[#list+1] = "- enemies but no elites and adjacent and above 60% hp" end
		if opt == 49 then list[#list+1] = "- enemies but no elites and adjacent and below 60% hp" end
		if opt == 50 then list[#list+1] = "- any enemy can attack you this turn" end
		if opt == 51 then list[#list+1] = "- you are under 80% hp" end
		if opt == 52 then list[#list+1] = "- you are under 60% hp" end
		if opt == 53 then list[#list+1] = "- at least 2 tiles between you with no elites and hp>80%" end
		if opt == 54 then list[#list+1] = "- at least 2 tiles between you with no elites and hp>60%" end
		if opt == 55 then list[#list+1] = "- at least 2 tiles between you but in range with no elites and hp>80%" end
		if opt == 56 then list[#list+1] = "- at least 2 tiles between you but in range with no elites and hp>60%" end
		if opt == 57 then list[#list+1] = "- you left click a valid target" end
        if opt == 101 then list[#list+1] = "- you LEFT CLICK an enemy and its available" end  
        if opt == 102 then list[#list+1] = "- you LEFT CLICK an enemy and there are no enemies visible ??? lol delet this" end  
        if opt == 103 then list[#list+1] = "- you LEFT CLICK an enemy and you are currently resting? reallly" end  
        if opt == 104 then list[#list+1] = "- you LEFT CLICK an enemy and you have a detrimental physical effect" end
        if opt == 105 then list[#list+1] = "- you LEFT CLICK an enemy and you have a detrimental mental effect" end
		if opt == 106 then list[#list+1] = "- you LEFT CLICK an enemy and you have a detrimental magical effect" end
		if opt == 107 then list[#list+1] = "- you LEFT CLICK an enemy and you have any detrimental effect" end
		if opt == 108 then list[#list+1] = "- you LEFT CLICK an enemy and enemies are not visible and will deactivate if enemies appear" end
		if opt == 109 then list[#list+1] = "- you LEFT CLICK an enemy and enemies are visible, and will deactivate if they are not" end
		if opt == 110 then list[#list+1] = "- you LEFT CLICK an enemy and enemies" end
		if opt == 111 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and you are above 80% hp" end
		if opt == 112 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and you are below 80% hp" end
		if opt == 113 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and you are above 60% hp" end
		if opt == 114 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and you are below 60% hp" end
		if opt == 115 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and in range" end
		if opt == 116 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and in range and you are above 80% hp" end
		if opt == 117 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and in range and you are below 80% hp" end
		if opt == 118 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and in range and you are above 60% hp" end
		if opt == 119 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and in range and you are below 60% hp" end
		if opt == 120 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and within two tiles" end
		if opt == 121 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and within two tiles and you are above 80% hp" end
		if opt == 122 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and within two tiles and you are below 80% hp" end
		if opt == 123 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and within two tiles and you are above 60% hp" end
		if opt == 124 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and within two tiles and you are below 60% hp" end
		if opt == 125 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and adjacent" end
		if opt == 126 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and adjacent and you are above 80% hp" end
		if opt == 127 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and adjacent and you are below 80% hp" end
		if opt == 128 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and adjacent and you are above 60% hp" end
		if opt == 129 then list[#list+1] = "- you LEFT CLICK an enemy and enemies and adjacent and you are below 60% hp" end
		if opt == 130 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites" end
		if opt == 131 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and above 80% hp" end
		if opt == 132 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and below 80% hp" end
		if opt == 133 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and above 60% hp" end
		if opt == 134 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and below 60% hp" end
		if opt == 135 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and in range" end
		if opt == 136 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and in range and above 80% hp" end
		if opt == 137 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and in range and below 80% hp" end
		if opt == 138 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and in range and above 60% hp" end
		if opt == 139 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and in range and below 60% hp" end
		if opt == 140 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and within two tiles" end
		if opt == 141 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and within two tiles and above 80% hp" end
		if opt == 142 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and within two tiles and below 80% hp" end
		if opt == 143 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and within two tiles and above 60% hp" end
		if opt == 144 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and within two tiles and below 60% hp" end
		if opt == 145 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and adjacent" end
		if opt == 146 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and adjacent and above 80% hp" end
		if opt == 147 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and adjacent and below 80% hp" end
		if opt == 148 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and adjacent and above 60% hp" end
		if opt == 149 then list[#list+1] = "- you LEFT CLICK an enemy and enemies but no elites and adjacent and below 60% hp" end
		if opt == 150 then list[#list+1] = "- you LEFT CLICK an enemy and any enemy can attack you this turn" end
		if opt == 151 then list[#list+1] = "- you LEFT CLICK an enemy and you are under 80% hp" end
		if opt == 152 then list[#list+1] = "- you LEFT CLICK an enemy and you are under 60% hp" end
		if opt == 153 then list[#list+1] = "- you LEFT CLICK an enemy and at least 2 tiles between you with no elites and hp>80%" end
		if opt == 154 then list[#list+1] = "- you LEFT CLICK an enemy and at least 2 tiles between you with no elites and hp>60%" end
		if opt == 155 then list[#list+1] = "- you LEFT CLICK an enemy and at least 2 tiles between you but in range with no elites and hp>80%" end
		if opt == 156 then list[#list+1] = "- you LEFT CLICK an enemy and at least 2 tiles between you but in range with no elites and hp>60%" end
		if opt == 157 then list[#list+1] = "- you LEFT CLICK an enemy and you left click a valid target" end

        if #list == 0 then
            doit()
        else
            Dialog:yesnoLongPopup("Automatic use", t.name:capitalize()..":\n"..table.concat(list, "\n").."\n Are you sure?", 500, function(ret)
                if ret then doit() end
            end)
        end
    else
        self:setTalentAuto(tid, false)
        Dialog:simplePopup("Automatic use disabled", t.name:capitalize().." will not be automatically used.")
    end
end

return _M
