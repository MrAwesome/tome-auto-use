local _M = loadPrevious(...)

local Map = require "engine.Map"
local Dialog = require "engine.ui.Dialog"
local ActorTalents = require "engine.interface.ActorTalents"

left_click_trigger = false
lc_target = nil

function _M:iclicked(a)
	left_click_trigger = true
	lc_target = a
	talents_ran_check = false
end
function _M:checktal()
	return talents_ran_check
end

local function spotHostiles(self)
	local seen = {}
	if not self.x then return seen end

	-- Check for visible monsters, only see LOS actors, so telepathy wont prevent resting
	core.fov.calc_circle(self.x, self.y, game.level.map.w, game.level.map.h, self.sight or 10, function(_, x, y) return game.level.map:opaque(x, y) end, function(_, x, y)
		local actor = game.level.map(x, y, game.level.map.ACTOR)
		if actor and self:reactionToward(actor) < 0 and self:canSee(actor) and game.level.map.seens(x, y) then
			seen[#seen + 1] = {x=x,y=y,actor=actor}
		end
	end, nil)
	return seen
end

local function useTalentOrItem(self, tid, inventory, item_name, forcedtarget)
	--game.log("UseTalentOrItem Activated")
	if inventory == true then
		--game.log("about to use inventory")
		--game.log(item_name)
		game.player:hotkeyInventory(item_name)
		--local o, item, inven = game.player:findInAllInventories(tid)
		--if not o then
			--Dialog:simplePopup("Item not found", "You do not have any "..tid..".")
		--	--game.log("item not found")
		--else
		--	game.player:playerUseItem(o, item, inven)
		--end
	else
		game.log("Player used:"..tid)
		if forcedtarget then
			game.player:useTalent(tid, nil, nil, nil, forcedtarget)
		else
			game.player:useTalent(tid)
		end
	end
end

local function itemReadyForUse(self, name)
	--TODO add checks for all the remaining types of items/cooldowns/powers
	--game.log("itemReadyForUse")
	local display_entity = nil
	local o = game.player:findInAllInventories(name, {no_add_name=true, force_id=true, no_count=true})
	local cnt = 0
	if o then cnt = o:getNumber() end
	if cnt == 0 then
		--game.log("itemReadyForUse:cnt=0")
		return false
	end
	if o and o.talent_cooldown then
		--game.log("itemReadyForUse:if1")
		local t = game.player:getTalentFromId(o.talent_cooldown)
		if game.player:isTalentCoolingDown(t) then
			return false
		end
	elseif o and (o.use_talent or o.use_power) then
		--game.log("itemReadyForUse:if2")
		local reduce = 1 - util.bound(game.player:attr("use_object_cooldown_reduce") or 0, 0, 100)/100
		local need = ((o.use_talent and o.use_talent.power) or (o.use_power and o.use_power.power) or 0)*reduce
		--game.log("itemReadyForUse:reduce="..reduce..":need:"..need..":power:"..o.power)
		if o.power < need then
			--game.log("itemReadyForUse:power<need")
			return false
		end
	end
	--game.log("itemReadyForUse:still ok?")
	if o and o.wielded then
		-- dont know what this is
		--game.log("What did you do to get into this state? is this a valid use case?")
		return true
		--frame = "sustain"
	end
	return true
end


--- Try to auto use listed talents
-- This should be called in your actors "act()" method
function _M:automaticTalents()
	--game.log("============================")
	--game.log("============================")
	--game.log("automaticTalentsCalled")
	if self.no_automatic_talents or self.talents_auto_off then return end

	self:attr("_forbid_sounds", 1)
	local uses = {}
	
	
	for tid, c in pairs(self.talents_auto) do
		local inventory = false
		local item_name = ""
		local t = self.talents_def[tid] or false
		--game.log("testing")
		--game.log(tid)
		local range
		if not t then
			local o = game.player:findInAllInventories(tid,{no_add_name=true,force_id=true,no_count=true})
			--item is talent based
			if o and o.use_talent and o.use_talent.id then
				local item_talent_id = o.use_talent.id
				--game.log("item found:")
				--game.log(item_talent_id)
				t = self.talents_def[item_talent_id]
				inventory = true
				item_name = tid
				tid = item_talent_id
			elseif o and o.use_power then
				--game.log("Player: it is a power")
				t = {name=tid,mode="activated", auto_use_check=false, no_energy=false}
				--It looks like its impossible to figure out what the range of a power based item would be. Setting to one.
				range = 1
				inventory = true
				item_name = tid
			else
				--game.log("item not found in inventory removing from auto-order list")
				game.player.talents_auto[tid] = nil
			end
		end
		if t then
			range = range or math.max(self:getTalentRange(t), self:getTalentRadius(t))
			--game.log("range="..range)
		local spotted = spotHostiles(self)
		local require_foes = 0
		local require_safe = 0
		local require_melee = 0
		local auto_use = 1
		local max_rank = 0
		local physical = 0
		local mental = 0
		local magical = 0
		local rangedmax = 0
		local rangedtwotiles = 0
		local haselites = 0
		local minimumtiles = 0

		
		for fid, foe in pairs(spotted) do
			if foe.actor.rank > max_rank then
				max_rank = foe.actor.rank
			end
		end
		for eff_id, p in pairs(self.tmp) do
			local e = self.tempeffect_def[eff_id]
			if e.status == "detrimental" and e.type == "physical" then
				physical = 1
			end
			if e.status == "detrimental" and e.type == "mental" then
				mental = 1
			end
			if e.status == "detrimental" and e.type == "magical" then
				magical = 1
			end
		end
				
		--------------------------------------------------------------
		-- CLICKING
		--------------------------------------------------------------
		if auto_use == 1 and left_click_trigger == false and ((c == 57 or c == 104 or c == 105 or c == 106 or c == 107 or c == 109 or c == 110 or c == 111 or c == 112 or c == 113 or c == 114 or c == 115 or c == 116 or c == 117 or c == 118 or c == 119 or c == 120 or c == 121 or c == 122 or c == 123 or c == 124 or c == 125 or c == 126 or c == 127 or c == 128 or c == 129 or c == 130 or c == 131 or c == 132 or c == 133 or c == 134 or c == 135 or c == 136 or c == 137 or c == 138 or c == 139 or c == 140 or c == 141 or c == 142 or c == 143 or c == 144 or c == 145 or c == 146 or c == 147 or c == 148 or c == 149 or c == 150 or c == 151 or c == 152 or c == 153 or c == 154 or c == 155 or c == 156)) then
			auto_use = 0
		end
		--------------------------------------------------------------
		-- ENEMIES
		--------------------------------------------------------------
		
		-- Require foes / Cast when there are enemies
		if auto_use == 1 and ((c == 10 or c == 11 or c == 12 or c == 13 or c == 14 or c == 15 or c == 16 or c == 17 or c == 18 or c == 19 or c == 20 or c == 21 or c == 22 or c == 23 or c == 24 or c == 25 or c == 26 or c == 27 or c == 28 or c == 29 or c == 30 or c == 31 or c == 32 or c == 33 or c == 34 or c == 35 or c == 36 or c == 37 or c == 38 or c == 39 or c == 40 or c == 41 or c == 42 or c == 43 or c == 44 or c == 45 or c == 46 or c == 47 or c == 48 or c == 49 or c == 50 or c == 53 or c == 54 or c == 55 or c == 56 or c == 110 or c == 111 or c == 112 or c == 113 or c == 114 or c == 115 or c == 116 or c == 117 or c == 118 or c == 119 or c == 120 or c == 121 or c == 122 or c == 123 or c == 124 or c == 125 or c == 126 or c == 127 or c == 128 or c == 129 or c == 130 or c == 131 or c == 132 or c == 133 or c == 134 or c == 135 or c == 136 or c == 137 or c == 138 or c == 139 or c == 140 or c == 141 or c == 142 or c == 143 or c == 144 or c == 145 or c == 146 or c == 147 or c == 148 or c == 149 or c == 150 or c == 153 or c == 154 or c == 155 or c == 156) or ((c == 8 or c == 108) and t.mode == "sustained" and self.sustain_talents[tid]) or ((c == 9 or c == 109) and t.mode == "sustained" and not self.sustain_talents[tid])) then
			require_foes = 1
		end
		
		-- Require safe / Cast where there are no enemies
		if auto_use == 1 and (c == 2 or c == 3 or c == 102 or c == 103 or ((c == 8 or c == 108) and t.mode == "sustained" and not self.sustain_talents[tid]) or ((c == 9 or c == 109) and t.mode == "sustained" and self.sustain_talents[tid])) then
			require_safe = 1
		end
	
		--------------------------------------------------------------
		-- PLAYER STATES
		--------------------------------------------------------------
		
		-- Player is resting
		if auto_use == 1 and (c == 3 or c == 103) and not self.resting then
			auto_use = 0
		end
		
		-- Player has a negative physical effect
		if auto_use == 1 and (c == 4 or c == 104) and physical == 0 then
			auto_use = 0
		end

		-- Player has a negative mental effect
		if auto_use == 1 and (c == 5 or c == 105) and mental == 0 then
			auto_use = 0
		end
		
		-- Player has a negative magical effect
		if auto_use == 1 and (c == 6 or c == 106) and magical == 0 then
			auto_use = 0
		end
		
		-- Player has any negative effect
		if auto_use == 1 and (c == 7 or c == 107) and physical == 0 and mental == 0 and magical == 0 then
			auto_use = 0
		end
		
		-- Player is > 80% HP
		if auto_use == 1 and (c == 11 or c == 16 or c == 21 or c == 26 or c == 31 or c == 36 or c == 41 or c == 46 or c == 53 or c == 55 or c == 111 or c == 116 or c == 121 or c == 126 or c == 131 or c == 136 or c == 141 or c == 146 or c == 153 or c == 155) and (self.life < (self.max_life / 1.2)) then
			auto_use = 0
		end
		
		-- Player is < 80% HP
		if auto_use == 1 and (c == 12 or c == 17 or c == 22 or c == 27 or c == 32 or c == 37 or c == 42 or c == 47 or c == 51 or c == 112 or c == 117 or c == 122 or c == 127 or c == 132 or c == 137 or c == 142 or c == 147 or c == 151) and (self.life > (self.max_life / 1.2)) then
			auto_use = 0
		end
		
		-- Player is > 60% HP
		if auto_use == 1 and (c == 13 or c == 18 or c == 23 or c == 28 or c == 33 or c == 38 or c == 43 or c == 48 or c == 54 or c == 56 or c == 113 or c == 118 or c == 123 or c == 128 or c == 133 or c == 138 or c == 143 or c == 148 or c == 154 or c == 156) and (self.life < (self.max_life / 1.65)) then
			auto_use = 0
		end
		
		-- Player is < 60% HP
		if auto_use == 1 and (c == 14 or c == 19 or c == 24 or c == 29 or c == 34 or c == 39 or c == 44 or c == 49 or c == 52 or c == 114 or c == 119 or c == 124 or c == 129 or c == 134 or c == 139 or c == 144 or c == 149 or c == 152) and (self.life > (self.max_life / 1.65)) then
			auto_use = 0
		end

		
		--------------------------------------------------------------
		-- DISTANCE
		--------------------------------------------------------------
		
		-- Melee // 1+ mob touches you
		if auto_use == 1 and (c == 25 or c == 26 or c == 27 or c == 28 or c == 29 or c == 45 or c == 46 or c == 47 or c == 48 or c == 49 or c == 125 or c == 126 or c == 127 or c == 128 or c == 129 or c == 145 or c == 146 or c == 147 or c == 148 or c == 149) then
			require_melee = 1
		end
		
		-- Ranged // max
		if auto_use == 1 and (c == 15 or c == 16 or c == 17 or c == 18 or c == 19 or c == 35 or c == 36 or c == 37 or c == 38 or c == 39 or c == 55 or c == 56 or c == 115 or c == 116 or c == 117 or c == 118 or c == 119 or c == 135 or c == 136 or c == 137 or c == 138 or c == 139 or c == 155 or c == 156) then
			rangedmax = 1
		end		
		
		-- Ranged // two tiles
		if auto_use == 1 and (c == 20 or c == 21 or c == 22 or c == 23 or c == 24 or c == 40 or c == 41 or c == 42 or c == 43 or c == 44 or c == 120 or c == 121 or c == 122 or c == 123 or c == 124 or c == 140 or c == 141 or c == 142 or c == 143 or c == 144) then
			rangedtwotiles = 1
		end		
		
		-- Ranged // at least two tiles
		if auto_use == 1 and (c == 53 or c == 54 or c == 55 or c == 56 or c == 153 or c == 154 or c == 155 or c == 156) then
			minimumtiles = 2
		end		
		
		-- Can attack
		if auto_use == 1 and ((c == 50 or c == 150)) and #spotted <= 0 then
			auto_use = 0
		end
		if auto_use == 1 and ((c == 50 or c == 150)) and #spotted >= 1 then
			auto_use = 0
			core.fov.calc_circle(self.x, self.y, game.level.map.w, game.level.map.h, self.sight or 10, function(_, x, y) return game.level.map:opaque(x, y) end, function(_, x, y)
			local proj = game.level.map(x, y, game.level.map.PROJECTILE)
			end, nil)
			for fid, foe in pairs(spotted) do
			if core.fov.distance(self.x,self.y,foe.x,foe.y) <= 3 then
				closingrange = 1
			end
			end
			if proj then
				game.log("Using because proj")
				auto_use = 1
			end
			if ai_state == PAI_STATE_FIGHT and closingrange == 1 then
				game.log("Using because fight")
				auto_use = 1
			closingrange = 0
			end
			if self.life <= self.max_life / 1.1 then
				game.log("Using because low life")
				auto_use = 1
			end
		end
		
		--Use stuff
		
		-- melee sanity checks
		if auto_use == 1 and require_melee == 1 and #spotted > 0 then
			auto_use = 0
			for fid, foe in pairs(spotted) do
				if foe.x >= self.x-1 and foe.x <= self.x+1 and foe.y >= self.y-1 and foe.y <= self.y+1 then
					auto_use = 1
				end
			end
		end	
		
		-- Ennemies sanity checks
		if auto_use == 1 and require_foes == 1 and ((self.mana < self.max_mana / 2) or (self.vim < self.max_vim / 4) or (self.stamina < self.max_stamina / 4)) and #spotted <= 0 then
			auto_use = 0
		end
		
		if auto_use == 1 and require_foes == 1 and #spotted <= 0 then
			auto_use = 0
		end
		
		if auto_use == 1 and require_safe == 1 and (#spotted > 0 or self:attr("blind")) then
			auto_use = 0
		end
		
		-- Foes max rank / Cast only against normal enemies
		if auto_use == 1 and (c == 30 or c == 31 or c == 32 or c == 33 or c == 34 or c == 35 or c == 36 or c == 37 or c == 38 or c == 39 or c == 40 or c == 41 or c == 42 or c == 43 or c == 44 or c == 45 or c == 46 or c == 47 or c == 48 or c == 49 or c == 53 or c == 54 or c == 55 or c == 56 or c == 130 or c == 131 or c == 132 or c == 133 or c == 134 or c == 135 or c == 136 or c == 137 or c == 138 or c == 139 or c == 140 or c == 141 or c == 142 or c == 143 or c == 144 or c == 145 or c == 146 or c == 147 or c == 148 or c == 149 or c == 153 or c == 154 or c == 155 or c == 156) and max_rank > 2 then
			auto_use = 0
			haselites = 1
		end
		
		-- ranged sanity checks
		if auto_use == 1 and (t.mode ~= "sustained" or not self.sustain_talents[tid]) and not self.talents_cd[tid] and self:preUseTalent(t, true, true) and (not t.auto_use_check or t.auto_use_check(self, t)) and haselites < 1 then
			local minty = 1
			if minimumtiles >= 1 and #spotted > 0 then
				for fid, foe in pairs(spotted) do
					if math.max(math.abs(self.x-foe.x),math.abs(self.y-foe.y)) <= minimumtiles then
						minty = 0
					end
				end
			end
			if minty == 1 and rangedmax == 0 and rangedtwotiles == 0 then
					uses[#uses+1] = {name=t.name, no_energy=t.no_energy == true and 0 or 1, cd=self:getTalentCooldown(t) or 0, tid=tid, is_item=inventory, item_name=item_name, ftarget=lc_target}
			end
			if minty == 1 and rangedmax == 1 and #spotted > 0 then
				for fid, foe in pairs(spotted) do
					if core.fov.distance(self.x,self.y,foe.x,foe.y) <= range then
						uses[#uses+1] = {name=t.name, no_energy=t.no_energy == true and 0 or 1, cd=self:getTalentCooldown(t) or 0, tid=tid, is_item=inventory, item_name=item_name, ftarget=lc_target}
					end
				end
			end
			if minty == 1 and rangedtwotiles == 1 and #spotted > 0 then
				for fid, foe in pairs(spotted) do
					if math.max(math.abs(self.x-foe.x),math.abs(self.y-foe.y)) <= 2 then
						uses[#uses+1] = {name=t.name, no_energy=t.no_energy == true and 0 or 1, cd=self:getTalentCooldown(t) or 0, tid=tid, is_item=inventory, item_name=item_name, ftarget=lc_target}
					end
				end
			end
		end
		
		
		if t.mode == "sustained" and self.sustain_talents[tid] and auto_use == 1 and ((c == 8 or c == 108) or (c == 9 or c == 109)) then
			--self:useTalentOrItem(tid, inventory, item_name)
			useTalentOrItem(self, tid)
		end
		
	end
	end


	--Use custom player set order. If its not on the list the player has not yet messed with the order and it will be place last
	if game.player.talents_auto_order and not game.player.talents_auto_ordering_off then
		--game.log("Cusomizing Order!")
		sorted_uses = {}
		temp_uses = uses
		for index, talent in ipairs(game.player.talents_auto_order) do
			local talent_obj = self.talents_def[talent]
			local talent_name = ""
			if talent_obj and talent_obj.name then
				talent_name = talent_obj.name
			else
				local o = game.player:findInAllInventories(talent, {no_add_name=true, force_id=true, no_count=true})
				if o and o.use_talent and o.use_talent.id then
					talent_obj = self.talents_def[o.use_talent.id]
					talent_name = talent_obj.name
				else
					talent_name = talent
				end
			end
			--game.log("searching for talent:"..talent_name)
			for i = table.getn(temp_uses), 1, -1 do
				local use = temp_uses[i]
				--game.log("matching against:"..use.name)
				if use.name == talent_name then
					--game.log("Adding Talent To List:"..use.name)
					table.insert(sorted_uses, use)
					table.remove(temp_uses, i)
					----game.log("#temp_uses="..#temp_uses)
				end
			end
		end

		--order remaining talents
		table.sort(temp_uses, function(a, b)
			if a.no_energy < b.no_energy then return true
			elseif a.no_energy > b.no_energy then return false
			else
				if a.cd > b.cd then return true
				else return false
				end
			end
		end)
		for k,v in ipairs(temp_uses) do table.insert(sorted_uses, v) end
		uses = sorted_uses
	-- Use the old default sorting method
	else
		----game.log("Using Default Sort Order")
		table.sort(uses, function(a, b)
			if a.no_energy < b.no_energy then return true
			elseif a.no_energy > b.no_energy then return false
			else
				if a.cd > b.cd then return true
				else return false
				end
			end
		end)
	end
	--table.print(uses)

	--game.log("After Sort Printing Table")
	for _, use in ipairs(uses) do
		--game.log("Triggered:"..use.name)
	end

	for _, use in ipairs(uses) do
		--game.log("Used:"..use.name)
		--game.log(use.tid)
		if use.is_item then
			--game.log("inventory item")
		end
		if left_click_trigger == true then
			local click_range_check = self.talents_def[use.tid]
			local range = math.max(self:getTalentRange(click_range_check), self:getTalentRadius(click_range_check))
			if core.fov.distance(self.x,self.y,use.ftarget.x,use.ftarget.y) <= range then
				useTalentOrItem(self, use.tid, use.is_item, use.item_name, use.ftarget)
				talents_ran_check = true
			end
		else
			useTalentOrItem(self, use.tid, use.is_item, use.item_name)
			talents_ran_check = true
		end
		if use.no_energy == 1 then break end
	end
	lc_target = nil
	left_click_trigger = false
	self:attr("_forbid_sounds", -1)
end

return _M


