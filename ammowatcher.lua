
do



--[[function dump(o)
  if type(o) == 'table' then
    local s = '{'
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. '['..k..'] = ' .. dump(v) .. ','
    end
    return s .. '}\n'
  else
    return tostring(o)
  end
end]]--

local airbaseDeltaAmmo = {}
function printAirbaseDeltaAmmo()
  for airbaseName,ammo in pairs(airbaseDeltaAmmo) do
    for ammoType,deltaAmount in pairs(ammo) do
      if deltaAmount ~= 0 then
        local airbase = Airbase.getByName(airbaseName)
        local airbaseId = airbase:getID()
        env.info("----------     ["..airbaseName.."] "..ammoType.." = "..deltaAmount, false)
      end
    end
  end
end
function changeAirbaseDeltaAmmo(airbaseKey, typeKey, amount)
  if not airbaseDeltaAmmo[airbaseKey] then
    airbaseDeltaAmmo[airbaseKey] = {}
  end
  if not airbaseDeltaAmmo[airbaseKey][typeKey] then 
    airbaseDeltaAmmo[airbaseKey][typeKey] = 0
  end
  airbaseDeltaAmmo[airbaseKey][typeKey] = airbaseDeltaAmmo[airbaseKey][typeKey] + amount
end

local Event_Handler = {}
function Event_Handler:onEvent(event)
  if event.id == world.event.S_EVENT_MISSION_END then
    env.info("---------- AmmoWatch stopped, result:",false)
    printAirbaseDeltaAmmo()
  elseif event.id == world.event.S_EVENT_TAKEOFF or event.id == world.event.S_EVENT_LAND then
    local unit = event.initiator
    if unit and event.place then
      local airbaseName = event.place:getName()
      local unitAmmo = unit:getAmmo()
      local typeName = unit:getDesc().typeName
      if typeName then
        -- This is the plane itself
        if event.id == world.event.S_EVENT_TAKEOFF then
          changeAirbaseDeltaAmmo(airbaseName, typeName, -1)
        elseif event.id == world.event.S_EVENT_LAND then
          changeAirbaseDeltaAmmo(airbaseName, typeName, 1)
        end
      end
      if unitAmmo then
        -- This is for the ammp for the plane
        for k,v in pairs(unit:getAmmo()) do
          ammoType = tostring(v.desc.typeName)
          ammoAmount = v.count
          if event.id == world.event.S_EVENT_TAKEOFF then
            changeAirbaseDeltaAmmo(airbaseName, ammoType, -1)
          elseif event.id == world.event.S_EVENT_LAND then
            changeAirbaseDeltaAmmo(airbaseName, ammoType, 1)
          end
        end
      end
    end
  end
end
world.addEventHandler(Event_Handler)



end