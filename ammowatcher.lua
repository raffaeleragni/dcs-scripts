--[[
   Copyright 2020 Raffaele Ragni

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
]]--
do

  local logpref = "DCSWarehouse watcher /----------/ "
  env.info(logpref.."Included", false)
  
  -- fuel capacity for each vehicle in tons (not kg!)
  -- fuel types
  --   jet_fuel
  --   gasoline
  --   methanol_mixture
  --   diesel
  local fuelCapacity = {
    ["FA-18C_hornet"] = {
      ["type"] = "jet_fuel",
      ["capacity"] = 4.9
    },
    ["F-16C_50"] = {
      ["type"] = "jet_fuel",
      ["capacity"] = 3.249
    },
    ["F-15C"] = {
      ["type"] = "jet_fuel",
      ["capacity"] = 6.103
    },
    ["F-14B"] = {
      ["type"] = "jet_fuel",
      ["capacity"] = 7.348
    },
    ["Su-27"] = {
      ["type"] = "jet_fuel",
      ["capacity"] = 9.400
    },
    ["Su-33"] = {
      ["type"] = "jet_fuel",
      ["capacity"] = 9.500
    },
    ["MiG-29S"] = {
      ["type"] = "jet_fuel",
      ["capacity"] = 3.493
    },
    ["UH-1H"] = {
      ["type"] = "gasoline",
      ["capacity"] = 0.631
    },
    ["Ka-50"] = {
      ["type"] = "gasoline",
      ["capacity"] = 1.450
    },
    ["AV8BNA"] = {
      ["type"] = "jet_fuel",
      ["capacity"] = 3.519
    },
    ["M-2000C"] = {
      ["type"] = "jet_fuel",
      ["capacity"] = 3.165
    },
    ["JF-17"] = {
      ["type"] = "jet_fuel",
      ["capacity"] = 2.325
    },
    ["A-10C"] = {
      ["type"] = "jet_fuel",
      ["capacity"] = 5.029
    }
  }
  
  function dump(o)
    if type(o) == 'table' then
      local s = '{\n'
      for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. dump(v) .. ',\n'
      end
      return s .. '}'
    elseif type(o) == 'string' then
      return '"'..tostring(o)..'"'
    else
      return tostring(o)
    end
  end
  
  local airbaseDeltaAmmo = {}
  local airbaseDeltaFuel = {}
  
  function buildAirbaseDelta()
    local s = ""
    for airbaseName,ammo in pairs(airbaseDeltaAmmo) do
      for ammoType,deltaAmount in pairs(ammo) do
        if deltaAmount ~= 0 then
          if s ~= "" then
            s = s..","
          end
          s = s.."{\"airbase\":\""..airbaseName.."\",\"type\":\""..ammoType.."\",\"amount\":"..deltaAmount.."}\n"
        end
      end
    end
    for airbaseName,fuel in pairs(airbaseDeltaFuel) do
      for fuelType,deltaAmount in pairs(fuel) do
        if deltaAmount ~= 0 then
          if s ~= "" then
            s = s..","
          end
          s = s.."{\"airbase\":\""..airbaseName.."\",\"type\":\""..fuelType.."\",\"amount\":"..deltaAmount.."}\n"
        end
      end
    end
    return "{\"data\":["..s.."]}"
  end
  
  function sendAirbaseDelta()
    local s = buildAirbaseDelta()
    if s and s ~= "" then
      env.info(logpref.."\n\n"..s.."\n\n", false)
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
  
  function changeAirbaseDeltaFuel(airbaseKey, fuelType, tons)
    if not airbaseDeltaFuel[airbaseKey] then
      airbaseDeltaFuel[airbaseKey] = {}
    end
    if not airbaseDeltaFuel[airbaseKey][fuelType] then 
      airbaseDeltaFuel[airbaseKey][fuelType] = 0
    end
    airbaseDeltaFuel[airbaseKey][fuelType] = airbaseDeltaFuel[airbaseKey][fuelType] + tons
  end

  local Event_Handler = {}
  function Event_Handler:onEvent(event)
    if event.id == world.event.S_EVENT_MISSION_END then
      sendAirbaseDelta()
    elseif event.id == world.event.S_EVENT_TAKEOFF or event.id == world.event.S_EVENT_LAND then
      local unit = event.initiator
      if unit and event.place then
        local airbaseName = event.place:getName()
        local unitFuel = unit:getFuel()
        local unitAmmo = unit:getAmmo()
        local typeName = unit:getDesc().typeName
        if typeName then
          -- This is the plane itself
          if event.id == world.event.S_EVENT_TAKEOFF then
            changeAirbaseDeltaAmmo(airbaseName, typeName, -1)
          elseif event.id == world.event.S_EVENT_LAND then
            changeAirbaseDeltaAmmo(airbaseName, typeName, 1)
          end
          -- calculate the fuel
          if unitFuel ~= 0 and fuelCapacity[typeName] ~= nil then
            local fuelType = fuelCapacity[typeName].type
            local fuelTons = unitFuel * fuelCapacity[typeName].capacity
            if event.id == world.event.S_EVENT_TAKEOFF then
              changeAirbaseDeltaFuel(airbaseName, fuelType, -fuelTons)
            elseif event.id == world.event.S_EVENT_LAND then
              changeAirbaseDeltaFuel(airbaseName, fuelType, fuelTons)
            end
          end
        end
        if unitAmmo then
          -- This is for the ammo for the plane
          for k,v in pairs(unit:getAmmo()) do
            ammoType = tostring(v.desc.typeName)
            ammoAmount = v.count
            if event.id == world.event.S_EVENT_TAKEOFF then
              changeAirbaseDeltaAmmo(airbaseName, ammoType, -ammoAmount)
            elseif event.id == world.event.S_EVENT_LAND then
              changeAirbaseDeltaAmmo(airbaseName, ammoType, ammoAmount)
            end
          end
        end
      end
    end
  end
  world.addEventHandler(Event_Handler)

end
