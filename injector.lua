
local injector = {
  
  PORT = 3399

  socket = nil,
  clients = {},
  
  start = function(self)
    local socket = require("socket")
    self.socket, err = socket.bind("*", self.PORT)
    self.socket:settimeout(0)
    self.socket:setoption("linger", {on = true, timeout = 5})
  end,

  close = function(self)
    self.socket:close()
  end,

  newClientsAccept = function(self)
    if self.socket ~= nil then
      local connection, err = self.socket:accept()
      if connection ~= nil then
        --new connection - non-blocking
        connection:settimeout(0)
        connection:setoption("linger", {on = true, timeout = 5})
        table.insert(self.clients, connection)
      end
    end
  end,

  allClientsRead = function(self)
    for k, c in ipairs(self.clients) do
      local s, status = c:receive(2^10)
      if s ~= nil then
        resp = self:processCommand(s)
        if resp ~= nil then
          c:send(resp.."\n")
        end
      end
      if err == "closed" then
        table.remove(self.clients, k)
      end
    end
  end,

  processCommand = function(self, command)
  end,

  beforeFrame = function(self)
    self:newClientsAccept()
    self:allClientsRead()
  end,

  afterFrame = function(self)
  end,

}

do
  local __LuaExportStart = LuaExportStart
  local __LuaExportBeforeNextFrame = LuaExportBeforeNextFrame
  local __LuaExportAfterNextFrame = LuaExportAfterNextFrame
  local __LuaExportStop = LuaExportStop
  LuaExportStart = function ()
    if __LuaExportStart then
      __LuaExportStart()
    end
    injector:start()
  end
  LuaExportBeforeNextFrame = function ()
    if __LuaExportBeforeNextFrame then
      __LuaExportBeforeNextFrame()
    end
    injector:beforeFrame()
  end
  LuaExportAfterNextFrame = function ()
    if __LuaExportAfterNextFrame then
      __LuaExportAfterNextFrame()
    end
    injector:afterFrame()
  end
  LuaExportStop = function ()
    if __LuaExportStop then
      __LuaExportStop()
    end
    injector:stop()
  end
end
