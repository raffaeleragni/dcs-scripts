
--
-- automan
-- Author: RAF
--

-- Requires LOADED BEFORE: mist (tested with v3.2)
if not mist then
  env.info(('automan NOT loaded: mist not found.'))
else

  automan = {



VERSION = "4.0",
--[[

 - 4.0: added __SPAWNABLE__ to spawn airbornes dynamically
 - 3.6: added __WP__ feature: automatically adds waypoints to groups at mission start
 - 3.5: change of default: radio items now for all coalitions
 - 3.4: don't load automan if mist is not present
 - 3.3: added __AITOGGLE__ tag: turns on/off by toggling the AI of the group
 - 3.2: added __HOLDABLE__ tag: stops or starts the ground units navigation depending on their state
 - 3.1: added __DEACTIVABLE__ tag
 - 3.0: refactoring to use a single object (automan)
 - 2.2: added __SAM__ tag
 - 2.1: Dynamic spawn does not appear if there are either no zones or groups

----------------------------------------------------------------------------

Hot to use TAGS:

Create a group in the mission editor, and write the wanted tag inside its name.
Automan works best with ground units, but some features can go with airborne ones too (ex. activables).
Example: a group named "__HOLDABLE__Convoy" will appear in the radio items as "Convoy" (stripped of tags)
and can be stopped/resumed via radio items automatically. No triggering required.
__SPAWNZONE__: ZONES (not groups) named with this tag will be available for places where to spawn the groups
__SPAWNGROUP__: groups to be spawned, generally best to leave them as 'late activable', since they're only working as templates
__SPAWNAIR__: groups to be spawned, leave them as late activable, they're templates.
__ACTIVABLE__: activates the group via radio item
__DEACTIVABLE__: deactivates the group via radio item
__HOLDABLE__: group can be stopped/resumed via radio item, but AI remains active (can fire back) great for convoys.
__AITOGGLE__: group can be stopped/resumed by shutting down its AI, meaning it will act as a STATIC GROUP when shut off.
__RESPAWN__: automatically respawn the group after its death, and a timeout in seconds to be configured in the
             automan_config parameters (default 120secs). To disperse it, create a zone named exactly like the group
             (inclusive of all tags) where to respawn.
__SAM__: add the group to the IADS network, with default values (if iads is loaded)

LOOKS UP FOR A VARIABLE NAMED 'automan_config' at startup, if existing, will overwrite the default settings.
If you're wanting to change configuration, this block of code must be loaded with a 'DO SCRIPT' BEFORE loading automan.

automan_config = {
  debugmode = false, -- enables debug strings via in-game messages
  spawn_disperse = true, -- disperses the spawning groups
  spawn_disperse_radius = 50, -- radius of dispersal, meters (if enabled)
  respawn_seconds = 120, -- seconds to auto-respawn after group death
  respawn_disperse = true, -- disperses the auto-respawning groups
  respawn_disperse_radius = 50, -- radius of dispersal, meters (if enabled)
  menu_coalitions = {coalition.side.RED, coalition.side.BLUE}, -- coalitions that have access to the radio items
}

----------------------------------------------------------------------------
]]--


	  -- Constants
	  SPAWNZONE_TAG = "__SPAWNZONE__",
	  SPAWNGROUP_TAG = "__SPAWNGROUP__",
	  SPAWNABLE_TAG = "__SPAWNABLE__",
	  ACTIVABLE_TAG = "__ACTIVABLE__",
	  DEACTIVABLE_TAG = "__DEACTIVABLE__",
	  HOLDABLE_TAG = "__HOLDABLE__",
	  AITOGGLE_TAG = "__AITOGGLE__",
	  AIOFF_TAG = "__AIOFF__",
	  RESPAWN_TAG = "__RESPAWN__",
	  SAM_TAG = "__SAM__",
	  WPZONE_TAG = "__WP__",
	  
	  -- Configuration
	  config = {
		  debugmode = false, -- enables debug strings via in-game messages
		  spawn_disperse = true, -- disperses the spawning groups
		  spawn_disperse_radius = 50, -- radius of dispersal, meters (if enabled)
		  respawn_seconds = 120, -- seconds to auto-respawn after group death
		  respawn_disperse = true, -- disperses the auto-respawning groups
		  respawn_disperse_radius = 50, -- radius of dispersal, meters (if enabled)
		  menu_coalitions = {coalition.side.RED, coalition.side.BLUE}, -- coalitions that have access to the radio items
		  init = function(self, newconfig)
			  if newconfig and newconfig.debugmode ~= self.debugmode then
				  self.debugmode = newconfig.debugmode
			  end
			  if newconfig and newconfig.spawn_disperse then
				  self.spawn_disperse = newconfig.spawn_disperse
			  end
			  if newconfig and newconfig.spawn_disperse_radius then
				  self.spawn_disperse_radius = newconfig.spawn_disperse_radius
			  end
			  if newconfig and newconfig.respawn_seconds then
				  self.respawn_seconds = newconfig.respawn_seconds
			  end
			  if newconfig and newconfig.respawn_disperse ~= self.respawn_disperse then
				  self.respawn_disperse = newconfig.respawn_disperse
			  end
			  if newconfig and newconfig.respawn_disperse_radius then
				  self.respawn_disperse_radius = newconfig.respawn_disperse_radius
			  end
			  if newconfig and newconfig.menu_coalitions then
				  self.menu_coalitions = newconfig.menu_coalitions
			  end
		  end
	  },
	  
	  
	  
	  -- Holding zone and group names
	  zone_names = {}, -- zones for the spawn feature
	  group_names = {}, -- groups for the spawn feature
	  air_names = {}, -- groups for the spawn feature
	  activable_names = {}, -- list of activable groups
	  deactivable_names = {}, -- list of deactivable groups
	  respawn_names = {}, -- list of the respawnable groups
	  spawnable_clear_commands_table = {}, -- keep a table to clear radio items out after being called the 'activables'
	  activable_clear_commands_table = {}, -- keep a table to clear radio items out after being called the 'activables'
	  deactivable_clear_commands_table = {}, -- keep a table to clear radio items out after being called the 'deactivables'
	  holdable_names = {}, -- list of the 'holdable' groups
	  holdable_holding_flags = {}, -- list of groups that are in holding
	  aitoggle_names = {}, -- list of the 'holdable' groups
	  aitoggle_active_flags = {}, -- list of groups having AI to on
	  wpzones_names = {}, -- list of the zone names for the __WP__ feature
	  wpgroups_names = {}, -- list of the group names for the __WP__ feature
	  
	  
	  
	  -- A function to print debug info
	  debugmsg = function(self, s)
	    if self.config.debugmode then
			env.info(('AUTOMAN: '..s))
		end
	  end,
	  -- a function to strip all the tags from the names
	  stripalltags = function (s)
		  return string.gsub(s, "__.+__", "")
	  end,
	  
	  
	  
	  -- Scans all the zones
	  scanzones = function(self)
		  for name, zone in pairs(mist.DBs.zonesByName) do
			  -- Scan all zones containing "__SPAWNZONE__"
			  if string.find(name, self.SPAWNZONE_TAG) then
				  table.insert(self.zone_names, name)
				  self:debugmsg('Found Spawn Zone: '..name)
			  end
			  -- Scan all zones containing "__WP__"
			  if string.find(name, self.WPZONE_TAG) then
				  table.insert(self.wpzones_names, name)
				  self:debugmsg('Found WP Zone: '..name)
			  end
		  end
		  -- sort tables
		  table.sort(self.zone_names)
		  table.sort(self.wpzones_names)
	  end,
	  
	  
	  
	  -- Scans all the groups
	  scangroups = function(self)
		  for name, group in pairs(mist.DBs.groupsByName) do
			  -- Scan all groups containing "__SPAWNGROUP__"
			  if string.find(name, self.SPAWNGROUP_TAG) then
				  table.insert(self.group_names, name)
				  self:debugmsg('Found Spawn Group: '..name)
			  end
			  -- Scan all groups containing "__SPAWNAIR__"
			  if string.find(name, self.SPAWNABLE_TAG) then
				  table.insert(self.air_names, name)
				  self:debugmsg('Found Spawnable: '..name)
			  end
			  -- Scan all groups containing "__ACTIVABLE__"
			  if string.find(name, self.ACTIVABLE_TAG) then
				  table.insert(self.activable_names, name)
				  self:debugmsg('Found Activable: '..name)
			  end
			  -- Scan all groups containing "__DEACTIVABLE__"
			  if string.find(name, self.DEACTIVABLE_TAG) then
				  table.insert(self.deactivable_names, name)
				  self:debugmsg('Found DeActivable: '..name)
			  end
			  -- Scan all groups containing "__RESPAWN__"
			  if string.find(name, self.RESPAWN_TAG) then
				  table.insert(self.respawn_names, name)
				  self:debugmsg('Found Respawnable: '..name)
			  end
			  -- Scan all groups containing "__HOLDABLE__"
			  if string.find(name, self.HOLDABLE_TAG) then
				  table.insert(self.holdable_names, name)
				  -- hold the group at start
				  trigger.action.groupStopMoving(Group.getByName(name))
				  self.holdable_holding_flags[name] = true
				  self:debugmsg('Found Holdable: '..name)
			  end
			  -- Scan all groups containing "__AITOGGLE__"
			  if string.find(name, self.AITOGGLE_TAG) then
				  table.insert(self.aitoggle_names, name)
				  -- put it to off at start
				  trigger.action.setGroupAIOff(Group.getByName(name))
				  self.aitoggle_active_flags[name] = false
				  self:debugmsg('Found AI Toggleable: '..name)
			  end
			  -- Scan all groups containing "__AIOFF__"
			  if string.find(name, self.AIOFF_TAG) then
				  trigger.action.setGroupAIOff(Group.getByName(name))
				  self:debugmsg('AI OFF: '..name)
			  end
			  -- Scan all groups containing "__SAM__"
			  -- Link them with default values to the iads script (if present and loaded)
			  if iads and string.find(name, self.SAM_TAG) then
				  iads.add(name)
				  self:debugmsg('Added SAM to IADS: '..name)
			  end
			  -- Scan all groups containing "__WP__"
			  if string.find(name, self.WPZONE_TAG) then
				  table.insert(self.wpgroups_names, name)
				  self:debugmsg('Found WP Group: '..name)
			  end
		  end
		  -- sort tables
		  table.sort(self.group_names)
		  table.sort(self.air_names)
		  table.sort(self.activable_names)
		  table.sort(self.deactivable_names)
		  table.sort(self.holdable_names)
		  table.sort(self.aitoggle_names)
		  table.sort(self.respawn_names)
		  table.sort(self.wpgroups_names)
	  end,
	  
	  
	  
	  -- Adds groups of radio items with their callback, optionally fills a notification list with their paths to be cleared afterwards
	  add_grouped_radioitems = function(self, menu_name, group_names, callback, notification_list)
		  for i,coa in ipairs(self.config.menu_coalitions) do
			  -- Create the activable menu list
			  local names_count = table.getn(group_names)
			  if names_count > 0 then
				  local submenu = missionCommands.addSubMenuForCoalition(coa, menu_name)
				  if names_count > 10 then
					  -- Create more submenus up to 100 items
					  local ct = 1
					  local i = 0
					  local sub2 = nil
					  for gidx, gname in ipairs(group_names) do
						  local strippedname = self.stripalltags(gname)
						  if i < 100 then
							  if i % 10 == 0 then
								  sub2 = missionCommands.addSubMenuForCoalition(coa, "Group " .. ct, submenu)
								  ct = ct + 1
							  end
							  local path = missionCommands.addCommandForCoalition(coa, strippedname, sub2, callback, {self = self, group = gname})
							  if notification_list then
								  notification_list[gname] = path
							  end
						  end
						  i = i + 1
					  end
				  else
					  local i = 0
					  for gidx, gname in ipairs(group_names) do
						  local strippedname = self.stripalltags(gname)
						  if i < 10 then
						  local path = missionCommands.addCommandForCoalition(coa, strippedname, submenu, callback, {self = self, group = gname})
						  if notification_list then
							  notification_list[gname] = path
						  end
					  end
					  i = i + 1
					  end
				  end
			  end
		  end
	  end,
	  
	  
	  
	  --- SPAWN PART
	  add_spawn_radioitems = function(self)
		  if table.getn(self.zone_names) > 0 and table.getn(self.group_names) > 0 then
			  for i,coa in ipairs(self.config.menu_coalitions) do
				  -- For each Spawn Zone, add a radio submenu
				  -- For each Group, permutated with Zone, add the spawn command radio item
				  local spawn_submenu = missionCommands.addSubMenuForCoalition(coa, "Dynamic spawn in zone")
				  for zidx, zname in ipairs(self.zone_names) do
					  local szname = self.stripalltags(zname)
					  local zone_submenu = missionCommands.addSubMenuForCoalition(coa, "In zone: " .. szname, spawn_submenu)
					  for gidx, gname in ipairs(self.group_names) do
						  local sgname = self.stripalltags(gname)
						  missionCommands.addCommandForCoalition(coa, sgname, zone_submenu, self.spawn, {self = self, zone = zname, group = gname})
					  end
				  end
			  end
		  end
	  end,
	  
	  
	  
	  -- Adds the activables
	  add_spawnable_radioitems = function(self)
		  self:add_grouped_radioitems("Dynamic spawnable", self.air_names, self.airspawn, self.spawnable_clear_commands_table)
	  end,
	  
	  
	  
	  -- Adds the activables
	  add_activable_radioitems = function(self)
		  self:add_grouped_radioitems("Dynamic activate", self.activable_names, self.myactivate, self.activable_clear_commands_table)
	  end,
	  
	  
	  
	  -- Adds the deactivables
	  add_deactivable_radioitems = function(self)
		  self:add_grouped_radioitems("Dynamic destroy", self.deactivable_names, self.mydeactivate, self.deactivable_clear_commands_table)
	  end,
	  
	  
	  
	  -- Adds the holdables
	  add_holdable_radioitems = function(self)
		  self:add_grouped_radioitems("Dynamic HOLD/START", self.holdable_names, self.myholdable)
	  end,
	  
	  
	  
	  -- Adds the aitoggle groups
	  add_aitoggle_radioitems = function(self)
		  self:add_grouped_radioitems("Dynamic AI Toggle", self.aitoggle_names, self.myaitoggle)
	  end,
	  
	  
	  
	  -- Connects the hooks for respawning
	  add_respawnable_hooks = function(self)
		  -- Auto-respawning groups, but don't register any callback if none are present
		  if table.getn(self.respawn_names) > 0 then
			  local function groupDead(event)
				  if event.id == world.event.S_EVENT_DEAD then
					  local found = false
					  for k, v in pairs(self.respawn_names) do
						  if not found and v and self.is_group_dead(v) then
							  self:debugmsg('Group dead: '..v)
							  -- Remove form the respawn table, since it's dead
							  table.remove(self.respawn_names, k)
							  found = true
							  -- schedule respawn function
							  mist.scheduleFunction(self.respawn_group, {self, v}, timer.getTime() + self.config.respawn_seconds)
						  end
					  end
				  end
			  end
			  mist.addEventHandler(groupDead)
		  end
	  end,
	  
	  
	  
	  -- adds the waypoint areas to the groups
	  add_wp_to_groups = function (self)
		  for k, v in pairs(self.wpgroups_names) do
			  local cat = string.gsub(v, ".*%[(.+)%].*", "%1")
			  self:debugmsg('found WP CAT: '..cat)
			  local group = mist.DBs.groupsByName[v]
			  local route = {
					-- WP1 is start point
					[1] = 
					{
						["alt"] = 7000,
						--["type"] = "TakeOffParkingHot",
						--["action"] = "From Parking Area Hot",
						["type"] = "Turning Point",
						["action"] = "Turning Point",
						["alt_type"] = "BARO",
						["formation_template"] = "",
						["ETA"] = 0,
						--["airdromeId"] = airbase:getID(),
						["y"] = group.units[1].point.y,
						["x"] = group.units[1].point.x,
						["speed"] = 220,
						["ETA_locked"] = true,
						["speed_locked"] = true,
						["task"] = 
						{
							["id"] = "ComboTask",
							["params"] = {["tasks"] = {}},
						},
					},
				}
			  local wp_idx = 1
			  local ct = 2
			  local found = true
			  while found do
				  local tofind = '%['..cat..'-'..wp_idx..'%]'
				  found = false
				  for kz, vz in pairs(self.wpzones_names) do
				      self:debugmsg('searching WP POINT: '..tofind)
					  if string.find(vz, tofind) then
						  -- Add WP to group
						  self:debugmsg('found WP POINT: '..vz)
						  local zone = mist.DBs.zonesByName[vz]
						  route[ct] = {
							  ["alt"] = 7000,
							  ["type"] = "Turning Point",
							  ["action"] = "Turning Point",
							  ["alt_type"] = "BARO",
							  ["formation_template"] = "",
							  ["y"] = zone.y,
							  ["x"] = zone.x,
							  ["speed"] = 220,
							  ["ETA_locked"] = false,
							  ["speed_locked"] = true,
								["task"] = 
								{
								  ["id"] = "ComboTask",
								  ["params"] = {["tasks"] = {}}
							  },
						  }
						  ct = ct + 1
						  wp_idx = wp_idx + 1
						  found = true
					  end
				  end
			  end
			  mist.goRoute(v, route)
		  end
	  end,
	  
	  
	  
	  -- This function is called when a command is called at the most granular level (group name)
	  spawn = function (pars)
	    local s = pars.self
		  local groupname = pars.group
		  local zonename = pars.zone
		  s:debugmsg('Cloning "'..groupname..'" in "'..zonename..'"')
		  mist.cloneInZone(groupname, zonename, s.config.spawn_disperse, s.config.spawn_disperse_radius)
	  end,
	  
	  
	  
	  -- This function is called when a command is called at the most granular level (group name)
	  airspawn = function (pars)
	    local s = pars.self
		local groupname = pars.group
		s:debugmsg('Cloning AIR "'..groupname..'"')
		mist.teleportToPoint({gpName = groupname, action = 'clone', route = mist.getGroupRoute(groupname, true)})
	  end,
	  
	  
	  
	  
	  -- activates a group
	  myactivate = function (pars)
		  local s = pars.self
		  local group = pars.group
		  local groupobj = Group.getByName(group)
		  local path = s.activable_clear_commands_table[group]
		  s:debugmsg('Activating group: '..group)
		  -- Remove the radio item since it has been called
		  if path then
			  for i,coa in ipairs(s.config.menu_coalitions) do
				  missionCommands.removeItemForCoalition(coa, path)
			  end
		  end
		  -- for the late activation ones, just activate it
		  trigger.action.activateGroup(groupobj)
		  -- set the command 'start' for the uncontrolled crafts
		  groupobj:getController():setCommand({id = "Start", params = {}})
	  end,
	  
	  
	  
	  -- deactivates a group
	  mydeactivate = function (pars)
		  local s = pars.self
		  local group = pars.group
		  local groupobj = Group.getByName(group)
		  local ac_path = s.activable_clear_commands_table[group]
		  local path = s.deactivable_clear_commands_table[group]
		  s:debugmsg('Destroying group: '..group)
		  -- Remove the radio item since it has been called
		  if path then
			  for i,coa in ipairs(s.config.menu_coalitions) do
				  missionCommands.removeItemForCoalition(coa, path)
			  end
		  end
		  -- Also remove the activable radio item: since the group is going to be DESTROYED anyway
		  if ac_path then
			  for i,coa in ipairs(s.config.menu_coalitions) do
				  missionCommands.removeItemForCoalition(coa, ac_path)
			  end
		  end
		  -- for the late activation ones, just activate it
		  trigger.action.deactivateGroup(groupobj)
	  end,
	  
	  
	  
	  -- hold/start for a group
	  myholdable = function (pars)
		  local s = pars.self
		  local group = pars.group
		  local groupobj = Group.getByName(group)
		  s.holdable_holding_flags[group] = not s.holdable_holding_flags[group]
		  if not s.holdable_holding_flags[group] then
			  trigger.action.groupContinueMoving(groupobj)
			  s:debugmsg('Start moving: '..group)
		  else
			  trigger.action.groupStopMoving(groupobj)
			  s:debugmsg('Stop moving: '..group)
		  end
	  end,
	  
	  
	  
	  -- ai toggle for a group
	  myaitoggle = function (pars)
		  local s = pars.self
		  local group = pars.group
		  local groupobj = Group.getByName(group)
		  s.aitoggle_active_flags[group] = not s.aitoggle_active_flags[group]
		  if s.aitoggle_active_flags[group] then
			  trigger.action.setGroupAIOn(groupobj)
			  s:debugmsg('AI ON: '..group)
		  else
			  trigger.action.setGroupAIOff(groupobj)
			  s:debugmsg('AI OFF: '..group)
		  end
	  end,
	  
	  
	  
	  -- Checks if a groups is dead
	  is_group_dead = function(name)
		  local groupobj = Group.getByName(name)
		  if not groupobj then
			  return true
		  end
		  local units = Group.getUnits(groupobj)
		  if not units then
			  return true
		  end
		  local alldead = true
		  for k,unit in pairs(units) do
			  if alldead and Unit.getLife(unit) > 1.0 then
				  alldead = false
			  end
		  end
		  return alldead
	  end,
	  
	  
	  
	  -- Respawns a group
	  respawn_group = function(self, name)
		  -- if exists a zone with the same name, use that for disperse
		  if mist.DBs.zonesByName[name] ~= nil then
			  self:debugmsg('Respawning : '..name..' (in zone)')
			  mist.respawnInZone(name, name, self.config.respawn_disperse, self.config.respawn_disperse_radius)
		  else
			  self:debugmsg('Respawning : '..name)
			  mist.respawnGroup(name, true)
		  end
		  -- Since it's respawned now, add it again to the list of units to be respawned when they're dead
		  table.insert(self.respawn_names, name)
	  end,
	  
	  
	  
	  -- Start point
	  start = function (self, newconfig)
		  self.config:init(newconfig)
		  self:scanzones()
		  self:scangroups()
		  self:add_spawnable_radioitems()
		  self:add_activable_radioitems()
		  self:add_deactivable_radioitems()
		  self:add_holdable_radioitems()
		  self:add_aitoggle_radioitems()
		  self:add_respawnable_hooks()
		  self:add_spawn_radioitems()
		  self:add_wp_to_groups()
		  env.info(('automan '..self.VERSION..' loaded'))
	  end
  }


  --- Start the stuff
  if automan_config then
	  automan:start(automan_config)
  else
	  automan:start()
  end
end
