
--
-- DCAS
-- Author: RAF
--

-- Requires LOADED BEFORE: mist (tested with v3.2)
if not mist then
  env.info(('DCAS NOT loaded: mist not found.'))
else

  DCAS = {



VERSION = "1.2",
--[[

Create zones with name prefix "SPAWN_CAS_" and grid, ex. SPAWN_CAS_GG60 in the grids to spawn enemies.
Create enemy groups, late activated with same prefix ex. SPAWN_CAS_APCx4


 - 1.1: Added BRA coordinates
 - 1.0: Dynamic tasking: CAS & OCA based on placed trigger zones

]]--


	  -- Constants
	  SPAWN_CAS_PREFIX = "SPAWN_CAS_",
	  MENU_COALITIONS = {coalition.side.RED, coalition.side.BLUE},
	  
	  
	  -- zones list
	  cas_zones = {},
	  cas_groups = {},
	  
	  
	  
	  -- current tasks:
	  active_cas = {},

	  
	  
	  -- Scans all the zones
	  scanzones = function(self)
		  -- Scan all zones
		  for name, zone in pairs(mist.DBs.zonesByName) do
			  if string.find(name, self.SPAWN_CAS_PREFIX) then
				  table.insert(self.cas_zones, name)
			  end
		  end
		  -- sort tables
		  table.sort(self.cas_zones)
	  end,
	  
	  
	  
	  -- Scans all the zones
	  scangroups = function(self)
		  -- Scan all groups
		  for name, group in pairs(mist.DBs.groupsByName) do
			  if string.find(name, self.SPAWN_CAS_PREFIX) then
				  table.insert(self.cas_groups, name)
			  end
		  end
		  -- sort tables
		  table.sort(self.cas_groups)
	  end,
	  
	  
	  
	  create_radioitems = function(self)
		  for i,coa in ipairs(self.MENU_COALITIONS) do
			  missionCommands.addCommandForCoalition(coa, "DCAS: Request new", nil, self.reqcas, {self = self})
			  missionCommands.addCommandForCoalition(coa, "DCAS: Refresh status", nil, self.reqstat, {self = self})
		  end
	  end,
	  
	  
	  
	  create_new_cas_task = function(self, zonename)
		  local nmax = table.getn(self.cas_groups)
		  local idx = math.random(1, nmax)
		  if idx > nmax then
		    idx = nmax
		  end
		  if idx < 1 then
		    idx = 1
		  end
		  local groupname = self.cas_groups[idx]
		  local group1 = mist.cloneInZone(groupname, zonename, true, 100)
		  group1.casname = string.gsub(groupname, self.SPAWN_CAS_PREFIX, "")
		  group1.zonename = string.gsub(zonename, self.SPAWN_CAS_PREFIX, "")
		  table.insert(self.active_cas, group1)
	      -- show the information of the new one
	      self:showstat(group1)
	  end,
	  
	  
	  
	  reqcas = function(pars)
	      local self = pars.self
		  self:checkdead()
          -- pick a new zone
	      local nmax = table.getn(self.cas_zones)
		  local idx = math.random(1, nmax)
		  if idx > nmax then
		    idx = nmax
		  end
		  if idx < 1 then
		    idx = 1
		  end
		  local zonename = self.cas_zones[idx]
		  env.info('zone:'..zonename)
		  -- create the task
	      self:create_new_cas_task(zonename)
	  end,
	  
	  
	  
	  reqstat = function(pars)
	      local self = pars.self
		  self:checkdead()
		  if table.getn(self.active_cas) == 0 then
		      local msg = {}
		      msg.text = "Picture clean"
		      msg.displayTime = 30
		      msg.msgFor = {coa = {'all'}}
		      mist.message.add(msg)
		  end
	      for i,group in ipairs(self.active_cas) do
		      self:showstat(group)
	      end
	  end,
	  
	  
	  
	  showstat = function(self, group)
	      local message = "Requesting attack.\n ON: "..group.zonename.."\n Target type: "..group.casname
		  -- vec2 = 2D point, vec3 = 3D point with land's height
		  local vec2 = {x = group.units[1].x, y = group.units[1].y}
		  local vec3 = {x = group.units[1].x, y = land.getHeight(vec2), z = group.units[1].y} 
		  -- BRA vars.
		  -- BE2 = bullseye 2D,
		  -- BE3 = bullseye 3D,
		  -- vec3 = point. dir = direction, dist = distance, alt = altitude
		  local BE2 = env.mission.coalition.blue.bullseye
		  local BE3 = {x = BE2.x, y = 0, z = BE2.y}
		  local dvec3 = {x = vec3.x - BE3.x, y = vec3.y - BE3.y, z = vec3.z - BE3.z}
		  local BRA = {dir = mist.utils.getDir(dvec3, BE3), dist = mist.utils.get2DDist(vec2, BE2), alt = vec3.y}
		  -- L/L coordinates from point vec3
		  local lat, lon = coord.LOtoLL(vec3)
		  -- Print all known coordinates format
		  message = message .. "\n\nFrom bullseye"
		  message = message .. "\n    Metric BRA: " .. mist.tostringBR(BRA.dir, BRA.dist, BRA.alt, true)
		  message = message .. "\n    Imperial BRA: " .. mist.tostringBR(BRA.dir, BRA.dist, BRA.alt, false)
		  message = message .. "\n\nCoordinates"
		  message = message .. "\n    GRID MGRS: " .. mist.tostringMGRS(coord.LLtoMGRS(lat, lon), 5)
		  message = message .. "\n    L/L decimal: " .. mist.tostringLL(lat, lon, 3, false)
		  message = message .. "\n    L/L degrees: " .. mist.tostringLL(lat, lon, 0, true)
		  -- Output the message
		  local msg = {}
		  msg.text = message
		  msg.displayTime = 60
		  msg.msgFor = {coa = {'all'}}
		  mist.message.add(msg)
	  end,
	  
	  
	  
	  checkdead = function(self)
	      for k, v in pairs(self.active_cas) do
			  if self.is_group_dead(v) then
				  local msg = {}
				  msg.text = "Group destroyed in "..v.zonename..": "..v.casname
				  msg.displayTime = 30
				  msg.msgFor = {coa = {'all'}}
				  mist.message.add(msg)
				  table.remove(self.active_cas, k)
			  end
		  end
	  end,
	  
	  
	  
	  -- Checks if a group is dead
	  is_group_dead = function(groupobj)
		  if not groupobj then
			  return true
		  end
		  local units = groupobj.units
		  if not units then
			  return true
		  end
		  local numunits = table.getn(units)
		  local count = 0
		  for k,tunit in pairs(units) do
	          local id = tunit.unitId
		      for k,v in pairs(mist.DBs.deadObjects) do
			      if v.objectData.unitId then
		              if v.objectData.unitId == id then
			              count = count + 1
		              end
			      end
		      end
		  end
		  if count >= numunits then
			  return true
		  else
			  return false
	      end
	  end,
	  
	  
	  
	  -- Start point
	  start = function (self)
		  self:scanzones()
		  self:scangroups()
		  self:create_radioitems()
		  env.info(('DCAS '..self.VERSION..' loaded'))
	  end
  }
  
  -- Activate the script
  DCAS:start()
  
  
end


