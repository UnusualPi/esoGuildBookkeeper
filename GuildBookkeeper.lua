--[[
MIT License
Copyright (c) 2022 UnusualPi
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

local LGH = LibHistoire
local LAM = LibAddonMenu2

local GBK = {}
GBK.name = "GuildBookkeeper"
GBK.version = "0.0.5"
GBK.author = 'ArcHouse'
GBK.default = {guilds={}, ledger={}}
GBK.listeners = {}
GBK.defaultLookback = 90

function GBK.Msg(text, type)
  -- https://www.color-hex.com/color-palette/1015961
  if type == 'info' then
    d('[' .. GBK.name ..'] ' .. '|cfff85c' .. text .. '|r')
  elseif type == 'emph' then
    d('[' .. GBK.name ..'] ' .. '|c00b8ff' .. text .. '|r')
  elseif type == 'warn' then
    d('[' .. GBK.name ..'] ' .. '|cfb9e30' .. text .. '|r')
  elseif type == 'err' then
    d('[' .. GBK.name ..'] ' .. '|cff2f82' .. text .. '|r')
  end
end

function GBK.OnAddOnLoaded(event, addonName)
  if addonName == GBK.name then
    GBK:Initialize()
    EVENT_MANAGER:UnregisterForEvent(GBK.name, EVENT_ADD_ON_LOADED)
  end
end

function GBK.Initialize()
  EVENT_MANAGER:RegisterForEvent('GBK-initmsg', EVENT_PLAYER_ACTIVATED, GBK.InitMsg)
  EVENT_MANAGER:RegisterForEvent('GBK-ListenerState', EVENT_PLAYER_ACTIVATED, GBK.GetListenerState)

  GBK.GuildInfo()
  GBK.savedVariables=ZO_SavedVars:NewAccountWide("GBKVariables", 1, nil, GBK.default)
  GBK.SetupListeners()
  GBK.InitSettingMenu()
end

function GBK.InitMsg()
  GBK.Msg('v'..GBK.version..' add-on initializing...', 'info')
  EVENT_MANAGER:UnregisterForEvent('GBK-initmsg', EVENT_PLAYER_ACTIVATED)
end

function GBK.GuildInfo()
  for i=1, GetNumGuilds() do
    local guildId = GetGuildId(i)
    local guildName = GetGuildName(guildId)
    GBK.default['guilds'][guildId] = {guildName=guildName, enabled = false, lastEvent=nil}
    GBK.default['ledger'][guildName] = {}
  end
end

function GBK:GetTamrielTradeCentrePrice(itemLink)
  priceStats={}
  if not TamrielTradeCentrePrice then -- If TTC Addon is not installed
    priceStats['Avg'] = 'TTC not available'
    priceStats['SuggestedPrice'] = 'TTC not available'
    return priceStats
  end

  if not itemLink then -- if no item link is passed
    priceStats['Avg'] = 'No itemLink'
    priceStats['SuggestedPrice'] = 'No itemLink'
    return priceStats
  end

  ttcPrices = TamrielTradeCentrePrice:GetPriceInfo(itemLink)
  if not ttcPrices then
    priceStats['Avg'] = 'TTC has no pricing'
    priceStats['SuggestedPrice'] = 'TTC has no pricing'
    return priceStats
  end
  return ttcPrices
end

function GBK:GetMmPrice(itemLink) -- Prices pull from MM's "Default Days Range"
  local mmStats = MasterMerchant:itemStats(itemLink, false)
  priceStats={}
  if mmStats['numSales'] == nil then
    priceStats['numDays'] = ''
    priceStats['avgPrice'] = ''
    priceStats['numSales'] = 'No MM Sales'
  else
    priceStats['numDays'] = mmStats['numDays']
    priceStats['avgPrice'] = mmStats['avgPrice']
    priceStats['numSales'] = mmStats['numSales']
  end
  return priceStats
end

function GBK:CheckExists(eventId, guildId, guildName)
  local e = false
  for k,v in pairs(GBK.savedVariables['ledger'][guildName]) do
    if v.transactionId == Id64ToString(eventId) then
      e = true break
    end
  end
  return e
end

function GBK.SetupListeners()
  for guildId,v in pairs(GBK.default['guilds']) do
    guildName = GBK.default['guilds'][guildId]['guildName']
    GBK.SetupListener(guildId, guildName)
    if GBK.savedVariables['guilds'][guildId]['enabled'] == true then
      -- Guild needs to be enabled in settings.
      GBK.listeners[guildId]:Start()
    end
  end
end

function GBK.SetupListener(guildId, guildName)
    GBK.listeners[guildId] = LGH:CreateGuildHistoryListener(guildId, GUILD_HISTORY_BANK)
    local lastEvent
    if GBK.savedVariables['guilds'][guildId]['lastEvent'] ~= nil then
      GBK.listeners[guildId]:SetAfterEventId(StringToId64(lastEvent))
    end
    GBK.listeners[guildId]:SetNextEventCallback(function(eventType, eventId, eventTime, param1, param2, param3, param4, param5, param6)
      local ttc = GBK:GetTamrielTradeCentrePrice(param3)
      local mm = GBK:GetMmPrice(param3)
      local typeId = eventType
      -- need to find the eventType Ids for the other event types...s
      if typeId == 13 then typeName = 'Credit'
        elseif typeId == 14 then typeName = 'Debit'
        else typeName = 'Unknown'
      end
      t = {transactionId = Id64ToString(eventId)
            , transactionType = typeName
            , typeId = eventType
            , transactionTimestamp = eventTime
            , transactionDatetime = os.date('%Y-%m-%d %H:%M:%S', eventTime)
            , guildMember = param1
            , itemId = GetItemLinkItemId(param3)
            , transactionQuantity = param2
            , itemName = GetItemLinkName(param3)
            , itemQuality = GetItemLinkQuality(param3)
            , itemTrait = GetItemLinkTraitType(param3)
            , itemCp = GetItemLinkRequiredChampionPoints(param3)
            , itemLevel = GetItemLinkRequiredLevel(param3)
            , ttcAvg = ttc["Avg"]
            , ttcSuggested = ttc["SuggestedPrice"]
            , mmAvg = mm['avgPrice']
            , mmNumDays = mm['numDays']
            , mmNumSales = mm['numSales']
            , itemLink = param3
--            , key = GBK.listeners[guildId]:GetKey()
          }
      if GBK:CheckExists(eventId, guildId, guildName) == false then
        table.insert(GBK.savedVariables['ledger'][guildName], t)
      end
      GBK.savedVariables['guilds'][guildId]['lastEvent'] = Id64ToString(eventId)
    end)
end
-------------------
--- SETTINGS UI ---
-------------------
function GBK:GetListenerState()
  for guildId,v in pairs(GBK.savedVariables['guilds']) do
    local guildName = GBK.default['guilds'][guildId]['guildName']
    local state = 'Dormant.'
    if GBK.listeners[guildId]:IsRunning() == true then
      state = 'Active.'
      GBK.Msg(guildName .. ': ' .. state, 'emph')
    else
      GBK.Msg(guildName .. ': ' .. state, 'warn')
    end
  end
  EVENT_MANAGER:UnregisterForEvent('GBK-ListenerState', EVENT_PLAYER_ACTIVATED, GBK.GetListenerState)
end

function GBK:ToggleListenerState(guildId)
  if GBK.listeners[guildId]:IsRunning() == true then
    GBK.listeners[guildId]:Stop()
    GBK.savedVariables['guilds'][guildId]['enabled'] = false
  else
    GBK.listeners[guildId]:Start()
    GBK.savedVariables['guilds'][guildId]['enabled'] = true
  end
  GBK:GetListenerState()
end

function GBK:ClearGuildLedger(guildId, guildName)
  GBK.savedVariables['guilds'][guildId]['lastEvent'] = nil
  local tt = GBK.savedVariables['ledger'][guildName]
  for i=1, #tt do
    tt[i] = nil
  end
  GBK.Msg('Ledger for ' .. guildName .. ' cleared.', 'err')
end

function GBK:InitSettingMenu()
	local panelData = {
		type = "panel"
		, name = "Guild Bookkeeper"
		, author = GBK.author
		, version = GBK.version
    , registerForRefresh = true
    , registerForDefaults= false
	}

  local optionsTable = {
    [1] = {
      type = "header",
      name = "Utilities",
      width = "full"
    },
    [2] = {
      type = "button",
      name = "Show States",
      tooltip = "Display listener states in chat.",
      func = function() GBK:GetListenerState() end
    },
  }
  for guildId,v in pairs(GBK.default['guilds']) do
    local guildName = GBK.default['guilds'][guildId]['guildName']
    table.insert(optionsTable,
      {
        type = 'header',
        name = guildName .. ' Options',
        width = 'full'
      }
    )
    table.insert(optionsTable,
      {
        type = 'checkbox',
        name = 'Monitoring',
        tooltip = 'Enable monitoring for '.. guildName,
        getFunc = function() return GBK.listeners[guildId]:IsRunning() end,
        setFunc = function(v) GBK:ToggleListenerState(guildId) end
      }
    )
    table.insert(optionsTable,
      {
        type = 'button',
        name = 'Clear Ledger',
        warning = 'Clears all data for ' .. guildName,
        func = function() GBK:ClearGuildLedger(guildId, guildName) end
      }
    )
  end
  LAM:RegisterAddonPanel("Guild Bancair", panelData)
  LAM:RegisterOptionControls("Guild Bancair", optionsTable)
end
--------------------
--- /SETTINGS UI ---
--------------------
EVENT_MANAGER:RegisterForEvent(GBK.name, EVENT_ADD_ON_LOADED, GBK.OnAddOnLoaded)
