local _M = loadPrevious(...)

local Player = require "mod.class.Player"
local Actor = require "mod.class.Actor"
local Map = require "engine.Map"

local mlc = _M.mouseLeftClick
function _M:mouseLeftClick(mx, my)
	
	if not self.level then return end
	local tmx, tmy = self.level.map:getMouseTile(mx, my)
	local p = self.player
	local a = self.level.map(tmx, tmy, Map.ACTOR)
	if not p:canSee(a) then return end
	if p:enoughEnergy() and p:reactionToward(a) < 0 then
		p:iclicked(a)
		p:act(a)
	end
	return p:checktal()
	
end

return _M
