-- Proxy toggle menubar for Hammerspoon.
-- Requires scripts/proxyctl installed at /usr/local/bin/proxyctl — see the README.
-- Paste into ~/.hammerspoon/init.lua (or dofile() it from there).

local proxyBar = hs.menubar.new()

local function readState()
  local out = hs.execute("/usr/local/bin/proxyctl status") or ""
  local f = {}
  for v in out:gsub("%s+$", ""):gmatch("([^|]*)") do f[#f + 1] = v end
  return { svc = f[1], http = f[2], host = f[3], port = f[4],
           https = f[5], shost = f[6], sport = f[7] }
end

local function render(s, busy)
  if busy then
    proxyBar:setTitle(hs.styledtext.new("◌ PROXY",
      { font = { name = "Menlo", size = 13 }, color = { hex = "#8e8e93" } }))
    return
  end
  local on = (s.http == "Yes" and s.https == "Yes")
  local mixed = (s.http ~= s.https)
  local mark  = mixed and "◐" or (on and "●" or "○")
  local color = mixed and "#ff9f0a" or (on and "#30d158" or "#8e8e93")
  proxyBar:setTitle(hs.styledtext.new(mark .. " PROXY",
    { font = { name = "Menlo", size = 13 }, color = { hex = color } }))
  proxyBar:setTooltip(string.format("%s\nHTTP  %s:%s [%s]\nHTTPS %s:%s [%s]",
    s.svc, s.host, s.port, s.http, s.shost, s.sport, s.https))
end

local function refresh() render(readState()) end

local function toggle()
  render(nil, true)
  hs.task.new("/usr/bin/sudo", function()
    refresh()
    local s = readState()
    hs.notify.new({ title = "Proxy",
      informativeText = (s.http == "Yes" and "ON" or "OFF") .. "  (" .. s.svc .. ")",
      withdrawAfter = 3 }):send()
  end, { "-n", "/usr/local/bin/proxyctl", "toggle" }):start()
end

proxyBar:setClickCallback(function(mods)
  if mods.alt or mods.ctrl then
    hs.execute("/usr/bin/open x-apple.systempreferences:com.apple.Network-Settings.extension")
  else
    toggle()
  end
end)

refresh()
hs.timer.doEvery(5, refresh):start()
