--[[
function table.val_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return "table" == type( v ) and table.tostring( v ) or
      tostring( v )
  end
end

function table.key_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. table.val_to_str( k ) .. "]"
  end
end

function table.tostring( tbl )
  if not tbl then
    return ""
  end
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, table.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
        table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
    end
  end
  return "{" .. table.concat( result, "," ) .. "}"
end]]--


-- War Operation Plan Response
-- v2
-- Acquire resource points, spend points to buy new troops

if not mist then
  env.info(('WOPR NOT loaded: mist not found.'))
else
	local WOPR = {
		-- Length in seconds for the messages to remain visible
		MSGLENGTH = 15,
		-- Coalitions
		COALITIONS = {coalition.side.RED, coalition.side.BLUE},
		-- Prefix for the groups database
		PREFIX = {
			[coalition.side.RED] = {["DB"] = "__DBRED__", ["SPAWN"] = "__SPAWNRED__", ["CARGO"] = "RED_CARGO"},
			[coalition.side.BLUE] = {["DB"] = "__DBBLUE__", ["SPAWN"] = "__SPAWNBLUE__", ["CARGO"] = "BLUE_CARGO"},
		},
		-- Target points to generate navigation info for the airborne units
		TARGETWAYPOINTS = {
			[coalition.side.RED] = {"__WPRED__TGT1", "__WPRED__TGT2"},
			[coalition.side.BLUE] = {"__WPBLUE__TGT1", "__WPBLUE__TGT2"},
		},
		-- Zones where to spawn cargo
		CARGOZONES = {
			[coalition.side.RED] = "RED_CARGO_SPAWN",
			[coalition.side.BLUE] = "BLUE_CARGO_SPAWN",
		},
		-- Zones where to drop cargo
		CARGOTARGETS = {
			[coalition.side.RED] = "RED_ADV_FARP",
			[coalition.side.BLUE] = "BLUE_ADV_FARP",
		},
		-- Template static units for cargo
		CARGOTEMPLATES = {
			[coalition.side.RED] = "RED_CARGO_TEMPLATE",
			[coalition.side.BLUE] = "BLUE_CARGO_TEMPLATE",
		},
		-- Airfields where to spawn airborne units
		AIRFIELDS = {
			[coalition.side.RED] = "Tbilisi-Lochini",
			[coalition.side.BLUE] = "Kutaisi",
		},
		-- Names of purchasable items (+ each coalition's DB- prefix).
		-- Final name is ex. "__DBRED__SAM-Radar-Medium" in mission
		ENTITIES = {
			["GROUND"] = {
				"SAM-Radar-Medium",
				"SAM-Radar-Short",
				"SAM-IR-Launcher",
				"AAA-Track",
				"AAA-NO Track",
				"UTILITY",
				"MBT",
				"APC",
				"IFV",
				"SPH",
			},
			["AIR"] = {
				"CAP",
				"CAS",
				"SEAD",
			},
		},
		-- How many cargo to keep spawned at a time
		CARGOCOUNT = 4,
		-- How much a delivered cargo gives in resources
		CARGOWORTH = 2500,
		-- Gain factor for a destroyed unit
		GAIN = 1.1,
		-- How much 'r' to gain for a unit remaining alive for 1 minute
		GAINPERMINUTE = 10,
		-- MAX resources that one faction can keep, any other gets discarded
		MAXRESOURCES = 10000,
		-- MAX number of unit groups that can generate resources. 100 == 100x10 = 1000r per minute
		MAXUNITGAIN = 100,
		-- Costs for units
		COSTS = {
			["SAM-Radar-Medium"] = 2500,
			["SAM-Radar-Short"] = 1250,
			["SAM-IR-Launcher"] = 750,
			["AAA-Track"] = 200,
			["AAA-NO Track"] = 100,
			["MBT"] = 250,
			["APC"] = 50,
			["IFV"] = 75,
			["SPH"] = 300,
			["UTILITY"] = 25,
			["CAP"] = 2500,
			["CAS"] = 2500,
			["SEAD"] = 2500,
		},
		TASKS = {
			["SEAD"] = {
				[1] = 
				{
					["enabled"] = true,
					["key"] = "SEAD",
					["id"] = "EngageTargets",
					["number"] = 1,
					["auto"] = true,
					["params"] = 
					{
						["targetTypes"] = 
						{
							[1] = "Air Defence",
						}, -- end of ["targetTypes"]
						["priority"] = 0,
					}, -- end of ["params"]
				}, -- end of [1]
				[2] = 
				{
					["enabled"] = true,
					["auto"] = true,
					["id"] = "WrappedAction",
					["number"] = 2,
					["params"] = 
					{
						["action"] = 
						{
							["id"] = "Option",
							["params"] = 
							{
								["value"] = 4,
								["name"] = 1,
							}, -- end of ["params"]
						}, -- end of ["action"]
					}, -- end of ["params"]
				}, -- end of [2]
				[3] = 
				{
					["enabled"] = true,
					["auto"] = true,
					["id"] = "WrappedAction",
					["number"] = 3,
					["params"] = 
					{
						["action"] = 
						{
							["id"] = "EPLRS",
							["params"] = 
							{
								["value"] = false,
								["groupId"] = 1,
							}, -- end of ["params"]
						}, -- end of ["action"]
					}, -- end of ["params"]
				}, -- end of [3]			
			},
			["CAS"] = {
				[1] = 
				{
					["enabled"] = true,
					["key"] = "CAS",
					["id"] = "EngageTargets",
					["number"] = 1,
					["auto"] = true,
					["params"] = 
					{
						["targetTypes"] = 
						{
							[1] = "Helicopters",
							[2] = "Ground Units",
							[3] = "Light armed ships",
						}, -- end of ["targetTypes"]
						["priority"] = 0,
					}, -- end of ["params"]
				}, -- end of [1]
				[2] = 
				{
					["enabled"] = true,
					["auto"] = true,
					["id"] = "WrappedAction",
					["number"] = 3,
					["params"] = 
					{
						["action"] = 
						{
							["id"] = "EPLRS",
							["params"] = 
							{
								["value"] = false,
								["groupId"] = 1,
							}, -- end of ["params"]
						}, -- end of ["action"]
					}, -- end of ["params"]
				}, -- end of [2]
			},
			["CAP"] = {
				[1] = 
				{
					["enabled"] = true,
					["key"] = "CAP",
					["id"] = "EngageTargets",
					["number"] = 1,
					["auto"] = true,
					["params"] = 
					{
						["targetTypes"] = 
						{
							[1] = "Air",
						}, -- end of ["targetTypes"]
						["priority"] = 0,
					}, -- end of ["params"]
				}, -- end of [1]
				[2] = 
				{
					["enabled"] = true,
					["auto"] = true,
					["id"] = "WrappedAction",
					["number"] = 2,
					["params"] = 
					{
						["action"] = 
						{
							["id"] = "EPLRS",
							["params"] = 
							{
								["value"] = false,
								["groupId"] = 1,
							}, -- end of ["params"]
						}, -- end of ["action"]
					}, -- end of ["params"]
				}, -- end of [2]
			},
		},
		-- Points to spend for new troops
		-- Starts at 5k
		resourcePoints = {
			[coalition.side.RED] = 5000,
			[coalition.side.BLUE] = 5000,
		},
		-- Unit groups divided by coalition
		groups = {
			[coalition.side.RED] = {},
			[coalition.side.BLUE] = {},
		},
		-- Spawn Zones
		spawnZones = {
			[coalition.side.RED] = {},
			[coalition.side.BLUE] = {},
		},
		-- Currently running cargo
		cargo = {
			[coalition.side.RED] = {},
			[coalition.side.BLUE] = {},
		},
		-- Gives the resources to a coalition and checks for the maximum
		giveResourcesToCoa = function(self, coa, amount)
			self.resourcePoints[coa] = self.resourcePoints[coa] + amount
			if self.resourcePoints[coa] > self.MAXRESOURCES then
				self.resourcePoints[coa] = self.MAXRESOURCES
			end
		end,
		-- Adds to the alive units
		addGroupToAliveUnits = function(self, coa, newGroup, strippedGroupName, airborne)
			local groupToInsert = {}
			groupToInsert.groupData = newGroup
			groupToInsert.WOPRID = strippedGroupName
			groupToInsert.airborne = airborne
			table.insert(self.groups[coa], groupToInsert)
		end,
		-- Parse through all saved groups and check if dead
		checkDead = function(self)
			for i,coa in pairs(self.COALITIONS) do
				for k, _v in pairs(self.groups[coa]) do
					if _v and _v.WOPRID then
						local v = _v.groupData
						local isDead = false
						isDead = self.__isGroupDead(v)
						if isDead then
							self:onDeadUnit(coa, k, _v)
						end
					end
				end
			end
		end,
		onDeadUnit = function(self, coa, k, _v)
			local WOPRID = _v.WOPRID
			table.remove(self.groups[coa], k)
			local ocoa = self.__otherCoalition(coa)
			-- Assign points to the other faction, multiplied for the GAIN
			local gain = math.floor((tonumber(self.COSTS[WOPRID]) * tonumber(self.GAIN)) + .5)
			self:giveResourcesToCoa(ocoa, gain)
			local msg = {}
			msg.text = "[Total="..self.resourcePoints[ocoa].."r] Gained new resources from a kill: "..gain.."r" 
			msg.displayTime = self.MSGLENGTH
			if ocoa == coalition.side.RED then
				msg.msgFor = {coa = {'red'}}
			elseif ocoa == coalition.side.BLUE then
				msg.msgFor = {coa = {'blue'}}
			end
			mist.message.add(msg)
			msg = {}
			msg.text = "Lost a unit: "..WOPRID
			msg.displayTime = self.MSGLENGTH
			if coa == coalition.side.RED then
				msg.msgFor = {coa = {'red'}}
			elseif coa == coalition.side.BLUE then
				msg.msgFor = {coa = {'blue'}}
			end
			mist.message.add(msg)
		end,
		__isGroupDead = function(groupobj)
			if not groupobj then
				return true
			end
			if not pcall(function() Group.getUnits(groupobj) end) then
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
		-- Checks if a group is dead
		__isGroupDead2 = function(groupobj)
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
		-- Gets the opposite coalition
		__otherCoalition = function(coa)
			if coa == coalition.side.RED then
				return coalition.side.BLUE
			elseif coa == coalition.side.BLUE then
				return coalition.side.RED
			end
		end,
		-- a function to strip all the tags from the names
		__stripAllTags = function (s)
			return string.gsub(s, "__.+__", "")
		end,
		-- Prints the status
		__status = function(pars)
			pars.self:checkDead()
			local msg = {}
			msg.text = "Amount of resources for you: "..pars.self.resourcePoints[pars.coa].."r"
			msg.displayTime = pars.self.MSGLENGTH
			if pars.coa == coalition.side.RED then
				msg.msgFor = {coa = {'red'}}
			elseif pars.coa == coalition.side.BLUE then
				msg.msgFor = {coa = {'blue'}}
			end
			mist.message.add(msg)
		end,
		-- Buys a ground group
		__buyGround = function(pars)
			local cost = pars.self.COSTS[pars.strippedGroupName]
			if pars.self.resourcePoints[pars.coa] < cost then
				local msg = {}
				msg.text = "Not enough resources"
				msg.displayTime = pars.self.MSGLENGTH
				if pars.coa == coalition.side.RED then
					msg.msgFor = {coa = {'red'}}
				elseif pars.coa == coalition.side.BLUE then
					msg.msgFor = {coa = {'blue'}}
				end
				mist.message.add(msg)
				return
			end
			
			local newGroup = mist.cloneInZone(pars.groupName, pars.spawnName, true, 50)
			if type(newGroup) == 'string' then
				newGroup = Group.getByName(newGroup)
			end
			pars.self:addGroupToAliveUnits(pars.coa, newGroup, pars.strippedGroupName, false)
			
			pars.self.resourcePoints[pars.coa] = pars.self.resourcePoints[pars.coa] - cost
			local msg = {}
			msg.text = "[Total="..pars.self.resourcePoints[pars.coa].."r] Bought '"..pars.strippedGroupName.."' in '"..pars.strippedSpawnName.."' for "..cost.."r"
			msg.displayTime = pars.self.MSGLENGTH
			if pars.coa == coalition.side.RED then
				msg.msgFor = {coa = {'red'}}
			elseif pars.coa == coalition.side.BLUE then
				msg.msgFor = {coa = {'blue'}}
			end
			mist.message.add(msg)
		end,
		-- Buys an air task
		__buyAir = function(pars)
			local cost = pars.self.COSTS[pars.strippedGroupName]
			if pars.self.resourcePoints[pars.coa] < cost then
				local msg = {}
				msg.text = "Not enough resources"
				msg.displayTime = pars.self.MSGLENGTH
				if pars.coa == coalition.side.RED then
					msg.msgFor = {coa = {'red'}}
				elseif pars.coa == coalition.side.BLUE then
					msg.msgFor = {coa = {'blue'}}
				end
				mist.message.add(msg)
				return
			end
			
			local airbase = Airbase.getByName(pars.self.AIRFIELDS[pars.coa])
			local airbasePosition = airbase:getPoint()
			local group = mist.DBs.groupsByName[pars.groupName]
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
						["params"] = {["tasks"] = pars.self.TASKS[pars.strippedGroupName]},
					},
				},
			}
		
			local zoneWaypoints = pars.self.TARGETWAYPOINTS[pars.coa]
			local ct = 2
			for i,name in ipairs(zoneWaypoints) do
				local zone = mist.DBs.zonesByName[name]
				if zone then
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
				end
			end
			
			-- Last point is the origin one
			route[ct] = {
				["alt"] = 7000,
				["type"] = "Turning Point",
				["action"] = "Turning Point",
				["alt_type"] = "BARO",
				["formation_template"] = "",
				["y"] = group.units[1].point.y,
				["x"] = group.units[1].point.x,
				["speed"] = 220,
				["ETA_locked"] = false,
				["speed_locked"] = true,
				["task"] = 
				{
					["id"] = "ComboTask",
					["params"] = {["tasks"] = {}}
				},
			}
			
			local newGroup = mist.teleportToPoint({
				gpName = pars.groupName,
				action = 'clone',
				route = route,
				--point = group.units[1].point,
			})
			if type(newGroup) == 'string' then
				newGroup = Group.getByName(newGroup)
			end
			pars.self:addGroupToAliveUnits(pars.coa, newGroup, pars.strippedGroupName, true)

			pars.self.resourcePoints[pars.coa] = pars.self.resourcePoints[pars.coa] - cost
			local msg = {}
			msg.text = "[Total="..pars.self.resourcePoints[pars.coa].."r] Bought '"..pars.strippedGroupName.."' for "..cost.."r"
			msg.displayTime = pars.self.MSGLENGTH
			if pars.coa == coalition.side.RED then
				msg.msgFor = {coa = {'red'}}
			elseif pars.coa == coalition.side.BLUE then
				msg.msgFor = {coa = {'blue'}}
			end
			mist.message.add(msg)
		end,
		-- Refills the cargo in the spawn zone up to reaching the maximum amount, happens when a cargo is dropped
		refillCargo = function(self)
			for i,coa in pairs(self.COALITIONS) do
				local count = 0
				while table.getn(self.cargo[coa]) < self.CARGOCOUNT and count < self.CARGOCOUNT do
					-- count is a safety measure to limit the while loop
					count = count + 1
					local newGroup = mist.cloneInZone(self.CARGOTEMPLATES[coa], self.CARGOZONES[coa], true, 20)
					if type(newGroup) == 'string' then
						env.info("NEW GROUP: "..newGroup)
						newGroup = Group.getByName(newGroup)
					end
					if newGroup then
						local group = {
							name = newGroup:getName(),
							pickedup = false,
							groupData = newGroup,
						}
						table.insert(self.cargo[coa], group)
					end
				end
			end
		end,
		-- Event when a cargo is dropped
		onDroppedCargo = function(self, coa, name)
			-- BUG generated cargo does not appear in the radio items
			--self:refillCargo()
			local zoneName = self.CARGOTARGETS[coa]
			local zone = trigger.misc.getZone(zoneName)
			local obj = StaticObject.getByName(name)
			local p = obj:getPosition()
			local isInside = (((p.p.x - zone.point.x)^2 + (p.p.z - zone.point.z)^2)^0.5 <= zone.radius)
			if isInside then
				self:giveResourcesToCoa(coa, self.CARGOWORTH)
				local msg = {}
				msg.text = "[Total="..self.resourcePoints[coa].."r] Cargo dropped, gained "..self.CARGOWORTH.."r"
				msg.displayTime = self.MSGLENGTH
				if coa == coalition.side.RED then
					msg.msgFor = {coa = {'red'}}
				elseif coa == coalition.side.BLUE then
					msg.msgFor = {coa = {'blue'}}
				end
				mist.message.add(msg)
			else
				local msg = {}
				msg.text = "Cargo dropped outside of zone"
				msg.displayTime = self.MSGLENGTH
				if coa == coalition.side.RED then
					msg.msgFor = {coa = {'red'}}
				elseif coa == coalition.side.BLUE then
					msg.msgFor = {coa = {'blue'}}
				end
				mist.message.add(msg)
			end
		end,
		-- Scans all the zones
		scanZones = function(self)
			for i,coa in pairs(self.COALITIONS) do
				for name, zone in pairs(mist.DBs.zonesByName) do
					local toFind = self.PREFIX[coa]["SPAWN"]
					if string.find(name, toFind) then
						table.insert(self.spawnZones[coa], name)
					end
				end
				-- sort tables
				table.sort(self.spawnZones[coa])
			end
		end,
		-- Load all radio items. They are static since the beginning of the mission.
		loadRadioItems = function(self)
			for i,coa in pairs(self.COALITIONS) do
				local mainSub = missionCommands.addSubMenuForCoalition(coa, "WOPR")
				local path = missionCommands.addCommandForCoalition(coa, "Status", mainSub, self.__status, {self = self, coa = coa})
				
				local airSub = missionCommands.addSubMenuForCoalition(coa, "Buy air", mainSub)
				for k,strippedGroupName in ipairs(self.ENTITIES["AIR"]) do
					local groupName = self.PREFIX[coa]["DB"]..strippedGroupName
					local cost = self.COSTS[strippedGroupName]
					local path = missionCommands.addCommandForCoalition(coa, strippedGroupName .. "("..cost.."r)", airSub, self.__buyAir, {self = self, coa = coa, groupName = groupName, strippedGroupName = strippedGroupName})
				end
				
				local groundSub = missionCommands.addSubMenuForCoalition(coa, "Buy ground", mainSub)
				for j,spawnName in ipairs(self.spawnZones[coa]) do
					local strippedSpawnName = self.__stripAllTags(spawnName)
					local mainSubSpawn = missionCommands.addSubMenuForCoalition(coa, "IN: "..strippedSpawnName, groundSub)
					for k,strippedGroupName in ipairs(self.ENTITIES["GROUND"]) do
						local groupName = self.PREFIX[coa]["DB"]..strippedGroupName
						local cost = self.COSTS[strippedGroupName]
						local path = missionCommands.addCommandForCoalition(coa, strippedGroupName .. "("..cost.."r)", mainSubSpawn, self.__buyGround, {self = self, coa = coa, spawnName = spawnName, strippedSpawnName = strippedSpawnName, groupName = groupName, strippedGroupName = strippedGroupName})
					end
				end
			end
		end,
		-- Hook to be triggered when any unit is dead
		addDeadHook = function(self)
			local function hook(event)
				-- Cargo events - when is dropped
				if 		event.id == world.event.S_EVENT_BIRTH and
						event.initiator then
					local name = event.initiator:getName()
					env.info("Unit Alive: "..name)
					for i,coa in pairs(self.COALITIONS) do
						if string.find(name, self.PREFIX[coa]["CARGO"]) then
							self:onDroppedCargo(coa, name)
						end
					end
				end
				if 	event.id == world.event.S_EVENT_CRASH or
						event.id == world.event.S_EVENT_EJECTION or
						event.id == world.event.S_EVENT_DEAD or
						event.id == world.event.S_EVENT_PILOT_DEAD then
					self:checkDead()
				end
				-- Airborne has landed
				if event and event.initiator and event.id == world.event.S_EVENT_LAND then
					-- AI (not player) has landed
					if not Unit.getPlayerName(event.initiator) then
						local group = Unit.getGroup(event.initiator)
						-- and contains the prefix in the name
						if group and pcall(function() group:getID() end) then
							for i,coa in pairs(self.COALITIONS) do
								for k, _v in pairs(self.groups[coa]) do
									if _v.groupData:getID() == group:getID() then
										-- detect if it's a bought plane and if it is, remove it from the table
										-- in this way it won't consider a kill when it's disposed
										table.remove(self.groups[coa], k)
										-- and if it is, return the cost to the owner
										local WOPRID = _v.WOPRID
										local gain = self.COSTS[WOPRID]
										self:giveResourcesToCoa(coa, gain)
										local msg = {}
										msg.text = "[Total="..self.resourcePoints[coa].."r] Flight returned to base, regained: "..gain.."r"
										msg.displayTime = self.MSGLENGTH
										if coa == coalition.side.RED then
											msg.msgFor = {coa = {'red'}}
										elseif coa == coalition.side.BLUE then
											msg.msgFor = {coa = {'blue'}}
										end
										mist.message.add(msg)
									end
								end
							end
						end
					end
				end
			end
			mist.addEventHandler(hook)
		end,
		-- Timer that counts for each minute the ground units and produces resources
		addTimerHook = function(self)
			mist.scheduleFunction(self.timerTick, {self}, timer.getTime() + 60, 60)
		end,
		-- Tick of the timer to generate resources on ground units
		timerTick = function(self)
			self:checkDead()
			for i,coa in pairs(self.COALITIONS) do
				local count = 0
				for k, _v in pairs(self.groups[coa]) do
					if not _v.airborne then
						count = count + 1
					end
				end
				if count > self.MAXUNITGAIN then
					count = self.MAXUNITGAIN
				end
				local gain = math.floor((tonumber(count) * tonumber(self.GAINPERMINUTE)) + .5)
				if gain > 0 then
					self:giveResourcesToCoa(coa, gain)
					local msg = {}
					msg.text = "[Total="..self.resourcePoints[coa].."r] Gained new resources from ground units: "..self.GAINPERMINUTE.."x"..count.."="..gain.."r"
					msg.displayTime = self.MSGLENGTH
					if coa == coalition.side.RED then
						msg.msgFor = {coa = {'red'}}
					elseif coa == coalition.side.BLUE then
						msg.msgFor = {coa = {'blue'}}
					end
					mist.message.add(msg)
				end
			end
		end,
		-- Entry point
		start = function(self)
			self:scanZones()
			self:loadRadioItems()
			self:addDeadHook()
			self:addTimerHook()
			-- BUG generated cargo does not appear in the radio items
			--self:refillCargo()
		end,
	}

	WOPR:start()
end
