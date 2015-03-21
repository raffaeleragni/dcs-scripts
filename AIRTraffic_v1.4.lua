-- Requires LOADED BEFORE: mist (tested with v3.2)
--[[

AIRTraffic v1.4

DEFAULT configuration:

AIRTraffic_config = {
    -- How many aircrafts active at once, 4*airports is a good number
	craftCount = 12,
	-- seconds to rest after landed, before destroying and spawning a new one
	-- warning, this includes the taxi time
	restTime = 480,
	-- list of airports where to spawn/land (exact name)
	airports = {
		[1] = "Kobuleti",
		[2] = "Kutaisi",
		[3] = "Senaki-Kolkhi",
	},
	-- possible aircrafts to spawn (taken from the AIRTraffic_CraftsTable keys)
	aircrafts = {
		[1] = "USA:C-130",
		[2] = "USA:A-10C",
		[3] = "USA:F-15C",
		[4] = "USA:F-16C",
		[5] = "USA:F/A-18C",
	},
}

AVAILABLE AIRCRAFT NAMES:
"USA:C-130"
"USA:A-10C"
"USA:F-15C"
"USA:F-16C"
"USA:F/A-18C"
"Russia:MiG-29S"
"Russia:Su-27"
"Russia:Su-33"
"Russia:Su-25T"
"Russia:Yak-40"

]]--
if not mist then
  env.info(('AIRTraffic NOT loaded: mist not found.'))
else

	-- Aircrafts database
	AIRTraffic_CraftsTable = {
		["USA:C-130"] = {
			model = "C-130",
			skin = "US Air Force",
			country = country.id.USA,
			payload = {
				["pylons"] = {},
				["fuel"] = 20830,
				["flare"] = 0,
				["chaff"] = 0,
				["gun"] = 0,
			}
		},
		["USA:A-10C"] = {
			model = "A-10C",
			skin = "23rd TFW England AFB (EL)",
			country = country.id.USA,
			payload = {
				["pylons"] = {},
				["fuel"] = 5029,
				["flare"] = 0,
				["chaff"] = 0,
				["gun"] = 0,
			}
		},
		["USA:F-15C"] = {
			model = "F-15C",
			skin = "58th Fighter SQN (EG)",
			country = country.id.USA,
			payload = {
				["pylons"] = {},
				["fuel"] = 6103,
				["flare"] = 0,
				["chaff"] = 0,
				["gun"] = 0,
			}
		},
		["USA:F-16C"] = {
			model = "F-16C bl.52d",
			skin = "usaf 412th tw (ed) edwards afb",
			country = country.id.USA,
			payload = {
				["pylons"] = {},
				["fuel"] = 3104,
				["flare"] = 0,
				["chaff"] = 0,
				["gun"] = 0,
			}
		},
		["USA:F/A-18C"] = {
			model = "F/A-18C",
			skin = "VFA-94",
			country = country.id.USA,
			payload = {
				["pylons"] = {},
				["fuel"] = 6531,
				["flare"] = 0,
				["chaff"] = 0,
				["gun"] = 0,
			}
		},
		["Russia:MiG-29S"] = {
			model = "MiG-29S",
			skin = "1038th guards ctc, mary ab",
			country = country.id.RUSSIA,
			payload = {
				["pylons"] = {},
				["fuel"] = 3500,
				["flare"] = 0,
				["chaff"] = 0,
				["gun"] = 0,
			}
		},
		["Russia:Su-27"] = {
			model = "Su-27",
			skin = "Air Force Standard",
			country = country.id.RUSSIA,
			payload = {
				["pylons"] = {},
				["fuel"] = 9400,
				["flare"] = 0,
				["chaff"] = 0,
				["gun"] = 0,
			}
		},
		["Russia:Su-33"] = {
			model = "Su-33",
			skin = "279th kiap 1st squad navy",
			country = country.id.RUSSIA,
			payload = {
				["pylons"] = {},
				["fuel"] = 9400,
				["flare"] = 0,
				["chaff"] = 0,
				["gun"] = 0,
			}
		},
		["Russia:Su-25T"] = {
			model = "Su-25T",
			skin = "af standard 1",
			country = country.id.RUSSIA,
			payload = {
				["pylons"] = {},
				["fuel"] = 3790,
				["flare"] = 0,
				["chaff"] = 0,
				["gun"] = 0,
			}
		},
		["Russia:Yak-40"] = {
			model = "MiG-Yak-40",
			skin = "Aeroflot",
			country = country.id.RUSSIA,
			payload = {
				["pylons"] = {},
				["fuel"] = 3080,
				["flare"] = 0,
				["chaff"] = 0,
				["gun"] = 0,
			}
		},
	}
	
    AIRTraffic = {
		
		PREFIX = "AIRTraffic",
		
	    config = {
			-- How many aircrafts active at once
			craftCount = 12,
		    -- seconds to rest after landed, before destroying and spawning a new one
			-- warning, this includes the taxi time
		    restTime = 480,
			-- list of airports where to spawn/land (exact name)
			airports = {
				[1] = "Kobuleti",
				[2] = "Kutaisi",
				[3] = "Senaki-Kolkhi",
			},
			-- possible aircrafts to spawn (taken from the AIRTraffic_CraftsTable keys)
			aircrafts = {
			    [1] = "USA:C-130",
				[2] = "USA:A-10C",
				[3] = "USA:F-15C",
				[4] = "USA:F-16C",
				[5] = "USA:F/A-18C",
			},
		    init = function(self, newConfig)
			    if newConfig then
				    if newConfig.craftCount then
					    self.craftCount = newConfig.craftCount
					end
				    if newConfig.restTime then
					    self.restTime = newConfig.restTime
					end
					if newConfig.airports then
					    self.airports = newConfig.airports
				    end
					if newConfig.aircrafts then
					    self.aircrafts = newConfig.aircrafts
				    end
				end
			end
		},
		
		groupCounter = 0,
		airportCounter = 1,
		
		-- Generates a list of crafts to start
		generateCrafts = function(self)
			for count = 1, self.config.craftCount do
				self:spawnNew()
			end
		end,
		
		-- Spawns a single craft, also used after one has landed and destroyed
		spawnNew = function(self)
			-- Take off and land on the same airport for now
			local startAirportNum = self.airportCounter
			local endAirportNum = startAirportNum
			self.airportCounter = self.airportCounter + 1
			if self.airportCounter > #self.config.airports then
				self.airportCounter = 1
			end
			-- random aircraft
			local aircraftNum = math.random(1, #self.config.aircrafts)
			-- Selected aircraft data
			local aircraft = AIRTraffic_CraftsTable[self.config.aircrafts[aircraftNum]]
			-- Airports objects
			local startAirbase = Airbase.getByName(self.config.airports[startAirportNum])
			local endAirbase = Airbase.getByName(self.config.airports[endAirportNum])
			-- Coordinates of the airports
			local startPosition = startAirbase:getPoint()
			local endPosition = endAirbase:getPoint()
			env.info("POS: ".. endPosition.x .."/".. endPosition.y .."/".. endPosition.z)
			-- Landing waypoint
			local route = {
				[1] = {
					["alt"] = 0,
					["alt_type"] = "RADIO",
					["type"] = "LAND",
					["action"] = "Landing",
					["formation_template"] = "",
					["ETA"] = 0,
					["airdromeId"] = endAirbase:getID(),
					["y"] = endPosition.z,
					["x"] = endPosition.x,
					["speed"] = 500, -- km/h?
					["ETA_locked"] = true,
					["speed_locked"] = true,
					["task"] = {
						["id"] = "ComboTask",
						["params"] = {
							["tasks"] = {},
						},
					},
				},
			}
			-- Spawn data
			self.groupCounter = self.groupCounter + 1
			local groupCounter = self.groupCounter
			local groupName = self.PREFIX.." G"..groupCounter
			local spawndata = {
				["groupId"] = groupCounter,
				["task"] = "Nothing",
				["tasks"] = {},
				["modulation"] = 0,
				["uncontrolled"] = false,
				["hidden"] = false,
				["y"] = startPosition.z,
				["x"] = startPosition.x,
				["name"] = groupName,
				["communication"] = true,
				["start_time"] = 0,
				["frequency"] = 124,
				["route"] = {
					["points"] = {
						-- START POINT
						[1] = {
							["alt"] = 0,
							["alt_type"] = "RADIO",
							["type"] = "TakeOffParking",
							["action"] = "From Parking Area",
							["formation_template"] = "",
							["ETA"] = 0,
							["airdromeId"] = startAirbase:getID(),
							["y"] = startPosition.z,
							["x"] = startPosition.x,
							["speed"] = 500, -- km/h?
							["ETA_locked"] = true,
							["speed_locked"] = true,
							["task"] = {
								["id"] = "ComboTask",
								["params"] = {
									["tasks"] = {
										-- EPLRS OFF (would cause conflict)
										[1] = 
										{
											["number"] = 1,
											["auto"] = true,
											["id"] = "WrappedAction",
											["enabled"] = true,
											["params"] = 
											{
												["action"] = 
												{
													["id"] = "EPLRS",
													["params"] = 
													{
														["value"] = false,
														["groupId"] = 2,
													},
												},
											},
										},
										-- NO RADAR USE
										[2] = 
										{
											["enabled"] = true,
											["auto"] = false,
											["id"] = "WrappedAction",
											["number"] = 2,
											["params"] = 
											{
												["action"] = 
												{
													["id"] = "Option",
													["params"] = 
													{
														["value"] = 0,
														["name"] = 3,
													},
												},
											},
										},
										-- RADIO SILENCE
										[3] = 
										{
											["number"] = 3,
											["auto"] = false,
											["id"] = "WrappedAction",
											["enabled"] = true,
											["params"] = 
											{
												["action"] = 
												{
													["id"] = "Option",
													["params"] = 
													{
														["value"] = true,
														["name"] = 7,
													},
												},
											},
										},
										-- NO REACTION TO THREATS
										[4] = 
										{
											["enabled"] = true,
											["auto"] = false,
											["id"] = "WrappedAction",
											["number"] = 4,
											["params"] = 
											{
												["action"] = 
												{
													["id"] = "Option",
													["params"] = 
													{
														["value"] = 0,
														["name"] = 1,
													},
												},
											},
										},
										-- INVISIBLE
										[5] = 
										{
											["number"] = 5,
											["auto"] = false,
											["id"] = "WrappedAction",
											["enabled"] = true,
											["params"] = 
											{
												["action"] = 
												{
													["id"] = "SetInvisible",
													["params"] = 
													{
														["value"] = true,
													},
												},
											},
										}
									},
								},
							},
						},
					}, -- end of ["points"]
				}, -- end of ["route"]
				["units"] = {
					[1] = {
						["alt"] = 0,
						["alt_type"] = "RADIO",
						["heading"] = 0,
						["livery_id"] = aircraft.skin,
						["type"] = aircraft.model,
						["psi"] = 0,
						["parking"] = 30, -- start from a high number, less likely being occupied
						["onboard_num"] = "10",
						["y"] = startPosition.z,
						["x"] = startPosition.x,
						["name"] = self.PREFIX.." U"..groupCounter,
						["payload"] = mist.utils.deepCopy(aircraft.payload),
						["speed"] = 500,
						["unitId"] = math.random(9999,99999),
						["skill"] = "High",
					},
				},
			}
			coalition.addGroup(aircraft.country, Group.Category.AIRPLANE, spawndata)
			-- wait for it to spawn before changing a route, 10 seconds
			mist.scheduleFunction(self.generateRoute, {self = self, groupName = groupName, route = route}, timer.getTime() + 10)
		end,
		
		-- Scheduled functon called after 3 seconds of a group spawn, to set route
		generateRoute = function(pars)
			local group = Group.getByName(pars.groupName) 
			mist.goRoute(group, pars.route)
		end,
		
		-- removes unit after a certain time, also spawns a new one
		scheduled_removeUnit = function(pars)
			pars.g:destroy()
			pars.s:spawnNew()
		end,
		
		landingHook = function(self)
			-- must be a function, non a variable
			local function hook(event)
				if event and event.initiator and event.id == world.event.S_EVENT_LAND then
					-- AI (not player) has landed
					if not Unit.getPlayerName(event.initiator) then
						local group = Unit.getGroup(event.initiator)
						-- and contains the prefix in the name
						if group and group:getName() and string.find(group:getName(), self.PREFIX) then
							timer.scheduleFunction(self.scheduled_removeUnit, {g = group, s = self}, timer.getTime() + self.config.restTime)
						end
					end
				end
			end
			mist.addEventHandler(hook)
		end,
	
	    start = function(self, newConfig)
			self.config:init(newConfig)
			self:landingHook()
			self:generateCrafts()
		end
    }
	
	if AIRTraffic_config then
		AIRTraffic:start(AIRTraffic_config)
	else	
		AIRTraffic:start()
	end
end

-- -285204.40625/45/682643.9375