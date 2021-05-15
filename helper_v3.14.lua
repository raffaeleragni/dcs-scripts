--[[
helper for missions
Author: RAF

This script takes some concepts from all my other scripts to a more targeted helper for missions
in a way that follows some conventions for missions style and editing.

Tags are intended to be added inside the group names in mission editor, including square brackets.

+ Feature 1: Spawnables
- Tag: [spawnable]
Templates: any non-static group with a late activation flag.
This feature manages a group of planes/helicopters or ground units (but not statics - also to be tested for naval units) to be
spawned as many times as desired, leaving the original template in the 'LATE ACTIVATION' state.
Differently than automan, this section will have its own way to determine coalition allowance to spawn some groups. Tag here is [spawnable].
If it possible to changhe the spawn point of origin by creating a marker in map with the name "spawn". This needs to be enabled via configuration first.

+ Feature 2: Activable/Deactivable
- Tags: [activable], [deactivable]
Activates some either late activable groups or uncontrolled aircraft. Deactivation destroys the group instead. Radio item is removed after triggering.

+ Feature 3: Air Traffic/periodic spawns
- Tags: [periodic]
This kind of groups will be cloned/spawned at startup, and again immediately after their death. This way also they will not clutter the radio items. These flight crafts will be also destroyed automatically after 10 minutes of touchdown, which makes this feature perfect for air traffic: after their destroy they will spawn again because of the rule above.

+ Feature 4: Holdable groups
- Tags: [holdable]
This group will be stopped or resume its course when radio item is called. Airborne groups will orbit instead.

+ Feature 5: Managed spawnables
- Tags: [M:<number>]
This will spawn the group if enough funds per coalitions are available and funds will be subtracted. The number is the amount of cost for this group.
Marker spawn applies.

Possible configuration, add a helper_config object:

helperConfig = {
  autoCoalition = true|false -- default is false. when true only red players access to red units and so on, when false, everyone access everythng.
  markedSpawn = true -- enable market spawn
}

Load that as a SCRIPT snippet, BEFORE loading the helper!

]]--

-- MIST must be present and be at least 3.0
if not mist or mist.majorVersion < 3 then
  env.info('MIST v3+ not FOUND, helper init ABORTED!!!')
  return
end

-- declare the helper object
helper = {}

-- Keep the scope out with a block
do
  HELPER_LOG_PREFIX = 'MisisonHelper :: '
  local pathToString = function(path)
    local str = ''
    if path == nil then
      return str
    end
    for i, name in ipairs(path) do
      str = str..'/'..(name or '<nil>')
    end
    return str
  end

  helper.version = 2
  -- Here to keep all the data stuff
  helper.data = {}
  helper.data.spawnables = {}
  helper.data.activables = {}
  helper.data.deactivables = {}
  helper.data.periodics = {}
  helper.data.holdables = {}
  helper.data.managed = {}
  -- This is internal: keeps track of the menus to remove from radio items
  helper.data.menuToRemove = {}
  -- Keep track of what was spaened
  helper.data.spawnedNames = {}
  -- Keep track of holding or not holding groups
  helper.data.holdableHoldingFlags = {}
  -- funds
  helper.funds = {}
  helper.funds.global = 0
  helper.funds.red = 0
  helper.funds.blue = 0
  helper.print_funds = function(self, coa)
    if coa and coa == coalition.side.RED then
      env.info(HELPER_LOG_PREFIX..'FUNDS :: RED FUNDS NOW: '..helper.funds.red)
      trigger.action.outTextForCoalition(coalition.side.RED, "RED FUNDS: "..helper.funds.red, 10, false)
    elseif coa and coa == coalition.side.BLUE then
      env.info(HELPER_LOG_PREFIX..'FUNDS :: BLUE FUNDS NOW: '..helper.funds.blue)
      trigger.action.outTextForCoalition(coalition.side.BLUE, "BLUE FUNDS: "..helper.funds.blue, 10, false)
    else
      env.info(HELPER_LOG_PREFIX..'FUNDS :: GLOBAL FUNDS NOW: '..helper.funds.global)
      trigger.action.outText("FUNDS: "..helper.funds.global, 10, false)
    end
  end
  helper.add_funds = function(self, amount, coa)
    if amount < 0 then
      return
    end
    if coa and coa == coalition.side.RED then
      helper.funds.red = helper.funds.red + amount
      trigger.action.outTextForCoalition(coalition.side.RED, "RED FUNDS ADDED: +"..amount, 10, false)
    elseif coa and coa == coalition.side.BLUE then
      helper.funds.blue = helper.funds.blue + amount
      trigger.action.outTextForCoalition(coalition.side.BLUE, "BLUE FUNDS ADDED: +"..amount, 10, false)
    else
      helper.funds.global = helper.funds.global + amount
      trigger.action.outText("FUNDS ADDED: +"..amount, 10, false)
    end
    self:print_funds(coa)
  end
  -- Adds groups of radio items with their callback
  -- a nil groupId goes for all users.
  helper.addRadioItemsToTarget = function(self, target, menuTitle, groupNames, autoRemove, callback, menuToRemove)
    env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: adding radio items for "'..menuTitle..'"...')
    -- Exit if no items
    if #groupNames == 0 then
      env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: nothing to add for "'..menuTitle..'".')
      return
    end
    -- Actual group scanning now
    local scanAndAdd = function (groupNames, addSubMenu, addCommand, removeCommand, coa)
      env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: GROUPSCAN :: scanning groups for adding radio items...')
      local count = #groupNames
      if count == 0 then
        env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: GROUPSCAN :: nothing to add for radio items.')
        return
      end
      local groupCT = 1
      local submenu = addSubMenu(menuTitle, nil)
      local parentMenu = submenu
      for i, name in ipairs(groupNames) do
        env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: GROUPSCAN :: adding item "'..name..'"...')
        -- Can't manage more than 100 anyway, even if grouped.
        if i > 100 then break end
        -- if count was more than 10, then go with submenus.
        if count > 10 and (i-1) % 10 == 0 then
          env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: GROUPSCAN :: moving to next page...')
          parentMenu = addSubMenu("Group " .. groupCT, submenu)
          groupCT = groupCT + 1
        end
        -- Strip out the tags from the name so that they appear as 'clean' in the menu radio item
        local strippedName = string.gsub(name, '%[.+%]%s*', '')
        _, _, optionalCost = string.find(name, "%[M:([0-9]+)%]%s*")
        optionalCost = tonumber(optionalCost)
        if optionalCost and optionalCost > 0 then
          strippedName = strippedName..' (cost '..optionalCost..')'
        end
        if autoRemove then
          -- Auto removal means that once the menu is getting called, the same menu gets removed from the radio items
          -- This is accomplished by passing an extra removal function (removeFN) to the callback
          local key = menuTitle..'-'..name
          self.data.menuToRemove[key] = addCommand(strippedName, parentMenu, callback, {self = self, key = key, name = name, removeFN = removeCommand, coa = coa, cost = optionalCost, useMark = true})
          env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: GROUPSCAN :: added one time only radio item "'..name..'".')
        else
          addCommand(strippedName, parentMenu, callback, {self = self, name = name, coa = coa, cost = optionalCost, useMark = true})
          env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: GROUPSCAN :: added persistent radio item "'..name..'".')
        end
      end
    end
    -- Special block for autodetecting coalition
    -- the radio items of the groups will be available to users of the same coalition of those groups
    if target ~= nil and target.autoCoalition then
      env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: radio items mode selected: auto coalition.')
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
      env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: grouped items into coalitions.')
      for i, coa in ipairs(coalitionsList) do
        -- assign to all users of the respective coalition of the subject item
        addSubMenu = function (name, path)
          env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: adding sub-menu "'..(name or '<nil>')..'" to path "'..pathToString(path)..'".')
          return missionCommands.addSubMenuForCoalition(coa, name, path)
        end
        addCommand = function (name, path, fn, pars)
          env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: adding radio item "'..(name or '<nil>')..'" to path "'..pathToString(path)..'".')
          return missionCommands.addCommandForCoalition(coa, name, path, fn, pars)
        end
        removeCommand = function (path)
          env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: removing radio item with path "'..pathToString(path)..'".')
          return missionCommands.removeItemForCoalition(coa, path)
        end
        env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: adding radio items for coalition: "'..coa..'"...')
        scanAndAdd(groupNamesByCoalition[coa], addSubMenu, addCommand, removeCommand, coa)
        env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: coalition "'..coa..'" complete.')
      end
    else
      -- Functions overriding
      -- Depending on target, call the right function (and wrap them accordingly)
      local addSubMenu = nil
      local addCommand = nil
      local removeCommand = nil
      -- No target, means anyone gets to operate on everything
      if target == nil then
        env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: radio items mode selected: no coalition, open access.')
        addSubMenu = function (name, path)
          env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: adding sub-menu "'..(name or '<nil>')..'" to path "'..pathToString(path)..'".')
          return missionCommands.addSubMenu(name, path)
        end
        addCommand = function (name, path, fn, pars)
          env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: adding radio item "'..name..'" to path "'..pathToString(path)..'".')
          return missionCommands.addCommand(name, path, fn, pars)
        end
        removeCommand = function (path)
          env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: removing radio item with path "'..pathToString(path)..'".')
          return missionCommands.removeItem(path)
        end
      elseif target.groupId ~= nil then
        env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: radio items mode selected: group only. Group id: '..target.groupId)
        -- Adding them instead to a specific groupId only (ie. a single player)
        -- But all of them. This could be intended for example for game masters.
        -- Dynamic functions based on parameter, contextual with groupId, if present
        addSubMenu = function (name, path)
          env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: adding sub-menu "'..(name or '<nil>')..'" to path "'..pathToString(path)..'".')
          return missionCommands.addSubMenuForGroup(groupId, name, path)
        end
        addCommand = function (name, path, fn, pars)
          env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: adding radio item "'..(name or '<nil>')..'" to path "'..pathToString(path)..'".')
          return missionCommands.addCommandForGroup(groupId, name, path, fn, pars)
        end
        removeCommand = function (path)
          env.info(HELPER_LOG_PREFIX..'ADDRADIOITEM :: removing radio item with path "'..pathToString(path)..'".')
          return missionCommands.removeItemForGroup(groupId, path)
        end
      end
      scanAndAdd(groupNames, addSubMenu, addCommand, removeCommand, nil)
    end
  end
  -- (callback) Function to spawn/clone a gorup
  helper.spawn = function(pars)
    local s = pars.self
    local name = pars.name
    local coa = pars.coa
    env.info(HELPER_LOG_PREFIX..'SPAWN :: cloning group "'..name..'"...')
    -- Have to use this shortcut, otherwise the clone is not working properly (on mist 3.2)
    local newGroup = s:lowlevel_clonespawn(name, coa, pars.useMark)
    helper.data.spawnedNames[newGroup['name']] = name
    env.info(HELPER_LOG_PREFIX..'SPAWN :: cloned group "'..name..'".')
    return newGroup
  end
  -- (callback) activates a group
  -- it also works as a start command to the uncontrolled crafts
  -- pars = {self, name, key, removeFN}
  helper.activate = function (pars)
    local s = pars.self
    local group = pars.name
    local groupobj = Group.getByName(group)
    env.info(HELPER_LOG_PREFIX..'ACTIVATE :: activating group "'..group..'"...')
    -- Remove the radio item since it has been called
    if pars.removeFN then
      local key = pars.key
      local path = s.data.menuToRemove[pars.key]
      env.info(HELPER_LOG_PREFIX..'ACTIVATE :: removing radio item key "'..key..'" path "'..pathToString(path)..'".')
      pars.removeFN(path)
    end
    -- for the late activation ones, just activate it
    trigger.action.activateGroup(groupobj)
    -- set the command 'start' for the uncontrolled crafts
    groupobj:getController():setCommand({id = "Start", params = {}})
    env.info(HELPER_LOG_PREFIX..'ACTIVATE :: activated group "'..group..'".')
  end
  -- (callback) deactivates a group
  -- pars = {self, name, key, removeFN}
  helper.deactivate = function (pars)
    local s = pars.self
    local group = pars.name
    local groupobj = Group.getByName(group)
    env.info(HELPER_LOG_PREFIX..'DEACTIVATE :: deactivating group "'..group..'"...')
    -- Remove the radio item since it has been called
    if pars.removeFN then
      local key = pars.key
      local path = s.data.menuToRemove[pars.key]
      env.info(HELPER_LOG_PREFIX..'ACTIVATE :: removing radio item key "'..key..'" path "'..pathToString(path)..'".')
      pars.removeFN(path)
    end
    -- for the late activation ones, deactivation will destroy them anyway
    trigger.action.deactivateGroup(groupobj)
    env.info(HELPER_LOG_PREFIX..'DEACTIVATE :: deactivated group "'..group..'".')
  end
  -- (callback) hold or resume a group
  -- pars = {self, name, key, removeFN}
  helper.holdable = function (pars)
    local s = pars.self
    local group = pars.name
    local groupobj = Group.getByName(group)
    s.data.holdableHoldingFlags[group] = not s.data.holdableHoldingFlags[group]
    if not s.data.holdableHoldingFlags[group] then
      env.info(HELPER_LOG_PREFIX..'HOLDABLE :: holding group "'..group..'".')
      trigger.action.groupContinueMoving(groupobj)
    else
      env.info(HELPER_LOG_PREFIX..'HOLDABLE :: resuming group "'..group..'".')
      trigger.action.groupStopMoving(groupobj)
    end
  end
  helper.cb_print_funds = function(pars)
    local s = pars.self
    local coa = pars.coa
    s:print_funds(coa)
  end
  -- (callback) Function to manage a spawn with a cost
  helper.managed = function(pars)
    local s = pars.self
    local name = pars.name
    local coa = pars.coa
    local cost = pars.cost
    -- Check for funds and remove them or deny if not enough
    -- Either per coalition or use the global funds
    if coa and coa == coalition.side.RED then
      if helper.funds.red < cost then
        env.info(HELPER_LOG_PREFIX..'MANAGED SPAWN :: not enough funds for "'..name)
        trigger.action.outTextForCoalition(coalition.side.RED, "RED FUNDS: NOT ENOUGH", 5, false)
        s:print_funds(coa)
        return
      end
      helper.funds.red = helper.funds.red - cost
      trigger.action.outTextForCoalition(coalition.side.RED, "RED FUNDS SPENT: "..cost, 10, false)
    elseif coa and coa == coalition.side.BLUE then
      if helper.funds.blue < cost then
        env.info(HELPER_LOG_PREFIX..'MANAGED SPAWN :: not enough funds for "'..name)
        trigger.action.outTextForCoalition(coalition.side.BLUE, "BLUE FUNDS: NOT ENOUGH", 5, false)
        s:print_funds(coa)
        return
      end
      helper.funds.blue = helper.funds.blue - cost
      trigger.action.outTextForCoalition(coalition.side.BLUE, "BLUE FUNDS SPENT: "..cost, 10, false)
    else
      if helper.funds.global < cost then
        env.info(HELPER_LOG_PREFIX..'MANAGED SPAWN :: not enough funds for "'..name)
        trigger.action.outText("FUNDS: NOT ENOUGH, AVAILABLE IS: "..helper.funds.global, 5, false)
        s:print_funds(coa)
        return
      end
      helper.funds.global = helper.funds.global - cost
      trigger.action.outText("FUNDS SPENT: "..cost, 10, false)
    end
    s:print_funds(coa)
    env.info(HELPER_LOG_PREFIX..'MANAGED SPAWN :: cloning group "'..name..'"...')
    local newGroup = s:spawn({self = s, name = name, coa = coa, useMark = true})
    env.info(HELPER_LOG_PREFIX..'MANAGED SPAWN :: cloned group "'..name..'".')
  end
  helper.lowlevel_clonespawn = function(self, name, coa, useMark)
    local marks = world.getMarkPanels()
    local foundMark = nil
    for i, obj in ipairs(marks) do
      if ((coa and coa == obj.coalition) or (not coa)) and obj.text == 'spawn' then
        foundMark = obj
      end
    end
    if useMark and self.config.markedSpawn and foundMark then
      -- some fucked up conversion that I figured out via debugging...
      local newPoint = {}
      env.info(HELPER_LOG_PREFIX..'MARKPOINT :: x='..foundMark.pos.x..' y='..foundMark.pos.y..' z='..foundMark.pos.z)
      newPoint.x = foundMark.pos.x
      newPoint.y = foundMark.pos.y
      newPoint.z = foundMark.pos.z
      env.info(HELPER_LOG_PREFIX..'SPAWN :: x='..newPoint.x..' y='..newPoint.y)
      return mist.teleportToPoint({
        gpName = name,
        action = 'clone',
        route = mist.getGroupRoute(name, true),
        point = newPoint,
        disperse = true,
        radius = 200,
        maxDisp = 100,
        innerRadius = 10
      })
    else
      env.info(HELPER_LOG_PREFIX..'SPAWN :: cloning with no marker, original position')
      return mist.teleportToPoint({
        gpName = name,
        action = 'clone',
        route = mist.getGroupRoute(name, true),
      })
    end
  end
  -- inside (callback) called at any world event, filters for landing AIs with [periodic] tag, destroys them after 10 minutes of touchdown
  -- also, for the same conditions, but if the group is destroyed, immediately respawn it
  helper.initPeriodics = function(self)
    env.info(HELPER_LOG_PREFIX..'PERIODIC :: initializing periodic groups...')
	  -- Checks if a groups is dead
	  local is_group_dead = function(name)
      --env.info(HELPER_LOG_PREFIX..'PERIODIC :: checking if group "'..name..'" is dead...')
		  local groupobj = Group.getByName(name)
		  if not groupobj then
        --env.info(HELPER_LOG_PREFIX..'PERIODIC :: checking if group "'..name..'" is dead.')
			  return true
		  end
		  local units = Group.getUnits(groupobj)
		  if not units then
        --env.info(HELPER_LOG_PREFIX..'PERIODIC :: checking if group "'..name..'" is dead.')
			  return true
		  end
		  local alldead = true
		  for k,unit in pairs(units) do
			  if alldead and Unit.getLife(unit) > 1.0 then
				  alldead = false
			  end
		  end
      if alldead then
        --env.info(HELPER_LOG_PREFIX..'PERIODIC :: checking if group "'..name..'" is dead.')
      else
        --env.info(HELPER_LOG_PREFIX..'PERIODIC :: checking if group "'..name..'" is NOT dead.')
      end
		  return alldead
	  end
    -- must be a function, non a variable
    local function hook(event)
      -- If it is not a Player and the event is either LAND or DEAD...
      -- Filter first for event.id since a lot will come of different types.
      -- Then verify that it is not a player.
      if event and (
               event.id == world.event.S_EVENT_LAND
            or event.id == world.event.S_EVENT_DEAD
            or event.id == world.event.S_EVENT_HIT
            or event.id == world.event.S_EVENT_CRASH
            or event.id == world.event.S_EVENT_EJECTION
            or event.id == world.event.S_EVENT_PILOT_DEAD)
        and event.initiator
        and Unit.getPlayerName(event.initiator) == nil then
          local group = Unit.getGroup(event.initiator)
          -- and contains the tag in the name...
          if group and group:getName() and helper.data.spawnedNames[group:getName()] then
            local originalName = helper.data.spawnedNames[group:getName()]
            if string.find(originalName, '%[periodic%]') then
              if event.id == world.event.S_EVENT_LAND then
                helper.data.spawnedNames[group:getName()] = nil
                -- If is landed, trigger a destroy for after 10 minutes from now
                local function destroyGroup(pars)
                  if pars and pars.g and pars.g:isExist() then
                    pars.g:destroy()
                  end
                  self.spawn({self = self, name = originalName, useMark = false})
                end
                env.info(HELPER_LOG_PREFIX..'PERIODIC :: periodic group "'..originalName..'", landed. Scheduling clone in 10 minutes.')
                timer.scheduleFunction(destroyGroup, {g = group}, timer.getTime() + 600)
              else
                -- If it was not landed, then it is either dead or destroyed, just respawn it immediately
                -- But not deactivables, when they're destroyed by the user radio item, they must remain so.
                if originalName and string.find(originalName, '%[periodic%]') and is_group_dead(group:getName())  then
                  helper.data.spawnedNames[group:getName()] = nil
                  self.spawn({self = self, name = originalName, useMark = false})
                  env.info(HELPER_LOG_PREFIX..'PERIODIC :: periodic group "'..originalName..'", dead. Cloned a new one.')
                end
              end
            end
          end
      end
    end
    local eventHandler = {}
    eventHandler.onEvent = function(self, event)
      status, ret = pcall(hook, event)
      if not status then
        env.info(HELPER_LOG_PREFIX..'ERROR: '..ret)
      end
    end
    -- Add the hook
    world.addEventHandler(eventHandler)
    env.info(HELPER_LOG_PREFIX..'PERIODIC :: hook added.')
    -- Spawn the all the units for the first time at startup
    for i, name in ipairs(self.data.periodics) do
      -- But spawn it only if it doesn't have any other tags.
      -- This because maybe the user wants a periodic but to activate it manually the first time
      if name and string.find(name, '%[periodic%]') then
        env.info(HELPER_LOG_PREFIX..'PERIODIC :: spawning first instance of "'..name..'"...')
        self.spawn({self = self, name = name, useMark = false})
        env.info(HELPER_LOG_PREFIX..'PERIODIC :: spawned first instance of "'..name..'".')
      end
    end
  end
  -- Scanners, these will load data from the mission file.
  -- Since the mission file is static anyway, this must be done only once.
  helper.scan = function (self)
    local checkAndInsert = function(str, strCheck, t)
      if string.find(str, strCheck) then
        table.insert(t, str)
        env.info(HELPER_LOG_PREFIX..'SCAN :: added "'..str..'" to list.')
      end
    end
    env.info(HELPER_LOG_PREFIX..'SCAN :: unit scan starting...')
    for name, group in pairs(mist.DBs.groupsByName) do
      checkAndInsert(name, '%[M:[0-9]+%]', self.data.managed)
      checkAndInsert(name, '%[spawnable%]', self.data.spawnables)
      checkAndInsert(name, '%[activable%]', self.data.activables)
      checkAndInsert(name, '%[deactivable%]', self.data.deactivables)
      checkAndInsert(name, '%[periodic%]', self.data.periodics)
	    checkAndInsert(name, '%[holdable%]', self.data.holdables)
    end
    env.info(HELPER_LOG_PREFIX..'SCAN :: sorting tables...')
    table.sort(self.data.managed)
    table.sort(self.data.spawnables)
    table.sort(self.data.activables)
    table.sort(self.data.deactivables)
    table.sort(self.data.periodics)
    table.sort(self.data.holdables)
    env.info(HELPER_LOG_PREFIX..'SCAN :: unit scan complete.')
  end
  -- Init function makes everything initialize and actualize.
  helper.init = function(self, config)
    env.info(HELPER_LOG_PREFIX..'INIT :: initializing....')
    -- Scans all items from mission file to internal tables
    self:scan()
    -- add items for all types depending on target
    local addItems = function(target)
      env.info(HELPER_LOG_PREFIX..'INIT :: adding radio items...')
      -- this needs a special check as it is a static radio item
      if next(self.data.managed) ~= nil then
        missionCommands.addCommandForCoalition(coalition.side.RED, 'Print funds', nil, self.cb_print_funds, {self = self, coa = coalition.side.RED})
        missionCommands.addCommandForCoalition(coalition.side.BLUE, 'Print funds', nil, self.cb_print_funds, {self = self, coa = coalition.side.BLUE})
      end
      -- addRadioItemsToTarget automatically detects if table is empty and does not add radio items in such case
      self:addRadioItemsToTarget(target, 'Buy', self.data.managed, false, self.managed)
      self:addRadioItemsToTarget(target, 'Spawnables', self.data.spawnables, false, self.spawn)
      self:addRadioItemsToTarget(target, 'Activables', self.data.activables, true, self.activate)
      self:addRadioItemsToTarget(target, 'Deactivables', self.data.deactivables, true, self.deactivate)
      self:addRadioItemsToTarget(target, 'Holdables', self.data.holdables, true, self.holdable)
      env.info(HELPER_LOG_PREFIX..'INIT :: radio items added.')
    end
    self.config = {}
    self.config.markedSpawn = false
    if config and config.markedSpawn then
      self.config.markedSpawn = true
    end
    if config and config.autoCoalition then
      addItems({autoCoalition = true})
    else
      addItems()
    end
    -- initiate the periodic groups system
    self:initPeriodics()
    env.info(HELPER_LOG_PREFIX..'INIT :: initialized.')
  end
  -- Starting point
  env.info(HELPER_LOG_PREFIX..'starting...')
  if helperConfig then
    helper:init(helperConfig)
  else
    helper:init()
  end
  env.info(HELPER_LOG_PREFIX..'v'..helper.version..' loaded.')
end
