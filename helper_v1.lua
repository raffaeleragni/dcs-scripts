
--[[
helper for missions
Author: RAF

This script takes some concepts from all my other scripts to a more targeted helper for missions
in a way that follows some conventions for missions style and editing.

Combinations:
[periodic] + [activable]: will not spawn at first, but wait for the user to activate it
[periodic] + [deactivable]: will spawn immediately, but will not respawn automatically (but still be destroyed automatically at landing time)

+ Feature 1: Spawnables
- Tag: [spawnable]
Templates: any non-static group with a late activation flag.
This feature manages a group of planes/helicopters or ground units (but not statics - also to be tested for naval units) to be
spawned as many times as desired, leaving the original template in the 'LATE ACTIVATION' state.
Differently than automan, this section will have its own way to determine coalition allowance to spawn some groups. Tag here is [spawnable].

+ Feature 2: Activable/Deactivable
- Tags: [activable], [deactivable]
Activates some either late activable groups or uncontrolled aircraft. Deactivation destroys the group instead. Radio item is removed after triggering.

+ Feature 3: Air Traffic/periodic spawns
- Tags: [periodic]
This kind of groups will be cloned/spawned at startup, and again immediately after their death. This way also they will not clutter the radio items. These flight crafts will be also destroyed automatically after 10 minutes of touchdown, which makes this feature perfect for air traffic: after their destroy they will spawn again because of the rule above.

]]--

-- MIST must be present and be at least 3.0
if not mist or mist.majorVersion < 3 then
  return
end

-- Keep the scope out with a block
do
  -- declare the helper object
  helper = {}
  helper.version = 1

  -- Here to keep all the data stuff
  helper.data = {}
  helper.data.spawnables = {}
  helper.data.activables = {}
  helper.data.deactivables = {}
  helper.data.periodics = {}
  -- This is internal: keeps track of the menus to remove from radio items
  helper.data.menuToRemove = {}
  -- Keep track of what was spaened
  helper.data.spawnedNames = {}
  
  -- Adds groups of radio items with their callback
  -- a nil groupId goes for all users.
  helper.addRadioItemsToTarget = function(self, target, menuTitle, groupNames, autoRemove, callback, menuToRemove)
    
    -- Exit if no items
    if #groupNames == 0 then
      return
    end
    
    -- Actual group scanning now
    local scanAndAdd = function (groupNames, addSubMenu, addCommand, removeCommand)
      local count = #groupNames
      if count == 0 then
        return
      end
      local groupCT = 1
      local submenu = addSubMenu(menuTitle, nil)
      local parentMenu = submenu
      for i, name in ipairs(groupNames) do
        -- Can't manage more than 100 anyway, even if grouped.
        if i > 100 then break end
        -- if count was more than 10, then go with submenus.
        if count > 10 and (i-1) % 10 == 0 then
          parentMenu = addSubMenu("Group " .. groupCT, submenu)
          groupCT = groupCT + 1
        end
        local strippedName = string.gsub(string.gsub(name, '%[.+%]', ''), '%s+', '')
        if autoRemove then
          local key = menuTitle..'-'..name
          local path = addCommand(strippedName, parentMenu, callback, {self = self, key = key, name = name, removeFN = removeCommand})
          self.data.menuToRemove[key] = path
        else
          addCommand(strippedName, parentMenu, callback, {self = self, name = name})
        end
      end
    end
    
    if target.autoCoalition then
      local addSubMenu = nil
      local addCommand = nil
      local removeCommand = nil
      -- put groups in two different coaliton groups and call scanAndAdd separately
      local coalitionsList = {}
      table.insert(coalitionsList, coalition.side.RED)
      table.insert(coalitionsList, coalition.side.BLUE)
      local groupNamesByCoalition = {}
      groupNamesByCoalition[coalition.side.RED] = {}
      groupNamesByCoalition[coalition.side.BLUE] = {}
      for i, name in ipairs(groupNames) do
        local group = mist.DBs.groupsByName[name]
        local coa = nil
        if group.coalition == 'red' then coa = coalition.side.RED end
        if group.coalition == 'blue' then coa = coalition.side.BLUE end
        if coa then
          table.insert(groupNamesByCoalition[coa], name)
        end
      end
      for i, coa in ipairs(coalitionsList) do
        -- assign to all users of the respective coalition of the subject item
        addSubMenu = function (name, path) 
          return missionCommands.addSubMenuForCoalition(coa, name, path) 
        end
        addCommand = function (name, path, fn, pars) 
          return missionCommands.addCommandForCoalition(coa, name, path, fn, pars) 
        end
        removeCommand = function (path) 
          return missionCommands.removeItemForCoalition(coa, path) 
        end
        scanAndAdd(groupNamesByCoalition[coa], addSubMenu, addCommand, removeCommand)
      end
    else
      -- Functions overriding
      -- Depending on target, call the right function (and wrap them accordingly)
      local addSubMenu = nil
      local addCommand = nil
      local removeCommand = nil
      if target == nil then
        addSubMenu = missionCommands.addSubMenu(name, path)
        addCommand = missionCommands.addCommand(name, path, fn, pars)
        removeCommand = missionCommands.removeItem(path)
      elseif target.groupId ~= nil then
        -- Dynamic functions based on parameter, contextual with groupId, if present
        addSubMenu = function (name, path) return missionCommands.addSubMenuForGroup(groupId, name, path) end
        addCommand = function (name, path, fn, pars) return missionCommands.addCommandForGroup(groupId, name, path, fn, pars) end
        removeCommand = function (path) return missionCommands.removeItemForGroup(groupId, path) end
      end
      scanAndAdd(groupNames, addSubMenu, addCommand, removeCommand)
    end
    
  end

  -- (callback) Function to spawn/clone a gorup
  helper.spawn = function(pars)
    local s = pars.self
    local name = pars.name
    -- Have to use this shortcut, otherwise the clone is not working properly (on mist 3.2)
    local newGroup = mist.teleportToPoint({gpName = name, action = 'clone', route = mist.getGroupRoute(name, true)})
    helper.data.spawnedNames[newGroup['name']] = name
  end

  -- (callback) activates a group
  -- it also works as a start command to the uncontrolled crafts
  -- pars = {self, name, key, removeFN}
  helper.activate = function (pars)
    local group = pars.name
    local groupobj = Group.getByName(group)
    -- Remove the radio item since it has been called
    if pars.removeFN then pars.removeFN(s.data.menuToRemove[pars.key]) end
    -- for the late activation ones, just activate it
    trigger.action.activateGroup(groupobj)
    -- set the command 'start' for the uncontrolled crafts
    groupobj:getController():setCommand({id = "Start", params = {}})
  end

  -- (callback) deactivates a group
  -- pars = {self, name, key, removeFN}
  helper.deactivate = function (pars)
    local s = pars.self
    local group = pars.name
    local groupobj = Group.getByName(group)
    -- Remove the radio item since it has been called
    if pars.removeFN then pars.removeFN(s.data.menuToRemove[pars.key]) end
    -- for the late activation ones, deactivation will destroy them anyway
    trigger.action.deactivateGroup(groupobj)
  end
  
  -- inside (callback) called at any world event, filters for landing AIs with [periodic] tag, destroys them after 10 minutes of touchdown
  -- also, for the same conditions, but if the group is destroyed, immediately respawn it
  helper.initPeriodics = function(self)
    -- must be a function, non a variable
    local function hook(event)
      -- If it is not a Player and the event is either LAND or DEAD...
      if event and event.initiator and not Unit.getPlayerName(event.initiator) and (event.id == world.event.S_EVENT_LAND or event.id == world.event.S_EVENT_DEAD) then
          local group = Unit.getGroup(event.initiator)
          -- and contains the tag in the name...
          if group and group:getName() and helper.data.spawnedNames[group:getName()] then
            local originalName = helper.data.spawnedNames[group:getName()]
            helper.data.spawnedNames[group:getName()] = nil
            if event.id == world.event.S_EVENT_LAND then
              -- If is landed, trigger a destroy for after 10 minutes from now
              local function destroyGroup(pars)
                pars.g:destroy()
                self.spawn({name = originalName})
              end
              timer.scheduleFunction(destroyGroup, {g = group}, timer.getTime() + 600)
            elseif event.id == world.event.S_EVENT_DEAD then
              -- If it was destroyed, just respawn it immediately
              -- But not deactivables, when they're destroyed by the user radio item, they must reamin so.
              self.spawn({name = group:getName()})
            end
          end
      end
    end
    -- Add the hook
    mist.addEventHandler(hook)
    -- Spawn the all the units for the first time at startup
    for i, name in ipairs(self.data.periodics) do
      -- But spawn it only if it doesn't have any other tags.
      -- This because maybe the user wants a periodic but to activate it manually the first time
      if not string.find(name, '%[spawnable%]|%[activable%]|%[deactivable%]') then
        self.spawn({name = name})
      end
    end
  end
  
  -- Scanners, these will load data from the mission file.
  -- Since the mission file is static anyway, this must be done only once.
  helper.scan = function (self)
    local checkAndInsert = function(str, strCheck, t)
      if string.find(str, strCheck) then
        table.insert(t, str)
      end
    end
    for name, group in pairs(mist.DBs.groupsByName) do
      checkAndInsert(name, '%[spawnable%]', self.data.spawnables)
      checkAndInsert(name, '%[activable%]', self.data.activables)
      checkAndInsert(name, '%[deactivable%]', self.data.deactivables)
      checkAndInsert(name, '%[periodic%]', self.data.periodics)
    end
    table.sort(self.data.spawnables)
    table.sort(self.data.activables)
    table.sort(self.data.deactivables)
    table.sort(self.data.periodics)
  end

  -- Init function makes everything initialize and actualize.
  helper.init = function(self)
    -- Scans all items from mission file to internal tables
    self:scan()
    -- add items for all types depending on target
    local addItems = function(target)
      self:addRadioItemsToTarget(target, 'Spawnables', self.data.spawnables, false, self.spawn)
      self:addRadioItemsToTarget(target, 'Activables', self.data.activables, true, self.activate)
      self:addRadioItemsToTarget(target, 'Deactivables', self.data.deactivables, true, self.deactivate)
    end
    -- Add items to their respective coalition owners
    addItems({autoCoalition = true})
    -- initiate the periodic groups system
    self:initPeriodics()
  end

  -- Starting point
  helper:init()
  env.info('Mission helper v'..helper.version..' loaded.')
  
end