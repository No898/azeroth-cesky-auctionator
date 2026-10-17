local addonName, ns = ...
local Controls = {version="0.1.2-preview.2"}
ns.Controls = Controls

local fields = {ui="uiEnabled", settings="settingsEnabled"}
local categories = {"ui", "settings"}
local statuses = {applied=true, ["pending-refresh"]=true, ["pending-combat"]=true,
  ["reload-required"]=true, unavailable=true, error=true}
local preferences, loaded, current, handle
local revision, lastReady, lastVersion, lastMaster = 0, nil, nil, true
local outcomes, values, requests = {}, {}, {ui=0, settings=0}

local function read(value, kind)
  -- Classic clients may not expose the secret-value API. When present, check
  -- it before any equality, length, conversion or field access.
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret ~= false then return nil, "unreadable" end
  end
  if type(value) ~= kind then return nil, "wrong-type" end
  if kind == "number" and (value ~= value or value == math.huge or value == -math.huge) then
    return nil, "invalid-number"
  end
  return value
end

local function combat()
  local getter = read(InCombatLockdown, "function")
  if not getter then return true end
  local ok, value = pcall(getter)
  return not ok or read(value, "boolean") ~= false
end

local function plain(value)
  if not read(value, "table") then return false end
  local ok, meta = pcall(getmetatable, value)
  if not ok then return false end
  local _, reason = read(meta, "nil")
  return reason == nil
end

local function text(value)
  value = read(value, "string")
  if value and #value > 0 and #value <= 128 then return value end
end

local function category(value)
  value = read(value, "string")
  if value and fields[value] then return value end
end

local function copy(state)
  local result = {schemaVersion=1, revision=state.revision, ready=state.ready,
    hostReady=state.hostReady, hostVersion=state.hostVersion, categories={}}
  for _, key in ipairs(categories) do
    local item = state.categories[key]
    result.categories[key] = {desired=item.desired, effective=item.effective,
      status=item.status, reason=item.reason}
  end
  return result
end

local function same(first, second)
  if not first or first.ready ~= second.ready or first.hostReady ~= second.hostReady
    or first.hostVersion ~= second.hostVersion then return false end
  for _, key in ipairs(categories) do
    local a, b = first.categories[key], second.categories[key]
    if a.desired ~= b.desired or a.effective ~= b.effective
      or a.status ~= b.status or a.reason ~= b.reason then return false end
  end
  return true
end

local function environment()
  local query = read(ns.ControlsHost, "function")
  local ready, version, reason = false, nil, "host-check-unavailable"
  if query then
    local ok, hostReady, hostVersion, hostReason = pcall(query)
    if not ok then reason = "host-check-error"
    else
      ready = read(hostReady, "boolean") == true
      version = ready and text(hostVersion) or nil
      reason = text(hostReason) or "host-not-ready"
    end
  end
  return {ready=ready, version=version, reason=reason,
    master=read(ns.enabled, "boolean") ~= false, combat=combat()}
end

local function syncEnvironment()
  local state = environment()
  if lastReady ~= state.ready or lastVersion ~= state.version
    or lastMaster and not state.master then
    for _, key in ipairs(categories) do outcomes[key] = {status="pending-refresh"} end
  end
  lastReady, lastVersion, lastMaster = state.ready, state.version, state.master
  return state
end

local function snapshot(env)
  local result = {schemaVersion=1, revision=revision, ready=loaded == true,
    hostReady=env.ready, hostVersion=env.version, categories={}}
  for _, key in ipairs(categories) do
    local desired = preferences and preferences[fields[key]] == true or false
    local outcome = outcomes[key] or {status="pending-refresh"}
    local status, reason = outcome.status, outcome.reason
    if not loaded then status, reason = "unavailable", "preferences-not-ready"
    elseif not env.ready then status, reason = "unavailable", env.reason
    elseif not env.master then
      status, reason = "unavailable", "session-disabled"
      if env.combat and outcome.status == "pending-combat" then
        status, reason = "pending-combat", "combat"
      end
    elseif status == "pending-combat" and not env.combat then
      status, reason = "pending-refresh", nil
    elseif status == "pending-refresh" and env.combat then
      status, reason = "pending-combat", "combat"
    end
    result.categories[key] = {desired=desired, status=status, reason=reason}
    if status == "applied" then result.categories[key].effective = desired end
  end
  return result
end

local function publish()
  if not handle then return end
  local callback = read(rawget(handle, "Publish"), "function")
  if not callback then handle = nil; return end
  local ok, accepted = pcall(callback, copy(current))
  if not ok or read(accepted, "boolean") ~= true then handle = nil end
end

function Controls.Changed()
  local nextState = snapshot(syncEnvironment())
  if same(current, nextState) then return false end
  revision = revision + 1
  nextState.revision, current = revision, nextState
  publish()
  return true
end

function Controls.GetSnapshot()
  return copy(current)
end

function Controls.Load()
  local saved = _G.AZCA_PREFS
  local valid = plain(saved)
  local schema = valid and rawget(saved, "schemaVersion")
  local _, schemaAbsent = read(schema, "nil")
  valid = valid and (schemaAbsent == nil or read(schema, "number") == 1)
  local ui, settings
  if valid then
    ui = read(rawget(saved, "uiEnabled"), "boolean")
    settings = read(rawget(saved, "settingsEnabled"), "boolean")
  end
  if not valid or read(schema, "number") ~= 1 or ui == nil or settings == nil then
    saved = {schemaVersion=1, uiEnabled=ui ~= false, settingsEnabled=settings ~= false}
    _G.AZCA_PREFS = saved
  end
  for _, key in ipairs(categories) do
    if not loaded or values[key] ~= saved[fields[key]] then
      outcomes[key] = {status="pending-refresh"}
      requests[key] = requests[key] + 1
    end
    values[key] = saved[fields[key]]
  end
  preferences, loaded = saved, true
  Controls.Changed()
  return true
end

function ns.CategoryEnabled(key)
  key = category(key)
  return key ~= nil and loaded == true and read(ns.enabled, "boolean") ~= false
    and preferences[fields[key]] == true
end

function Controls.Pending(key, status, reason)
  key, status = category(key), read(status, "string")
  if not key or not status or not statuses[status] or status == "applied" then
    return false, "invalid-state"
  end
  syncEnvironment()
  outcomes[key] = {status=status, reason=text(reason)}
  Controls.Changed()
  return true
end

function Controls.Applied(key, expected)
  key = category(key)
  if not key then return false, "invalid-category" end
  local expectedValue = read(expected, "boolean")
  local _, expectedAbsent = read(expected, "nil")
  if expectedAbsent ~= nil and (expectedValue == nil
    or expectedValue ~= preferences[fields[key]]) then return false, "stale-state" end
  local env = syncEnvironment()
  if env.combat then outcomes[key] = {status="pending-combat", reason="combat"}
  elseif not env.master or not env.ready then outcomes[key] = {status="pending-refresh"}
  else outcomes[key] = {status="applied"} end
  Controls.Changed()
  return true
end

function Controls.SetCategory(key, enabled)
  key, enabled = category(key), read(enabled, "boolean")
  if not key or enabled == nil then return false, "invalid-request" end
  if preferences[fields[key]] == enabled then return true, Controls.GetSnapshot() end
  local env = syncEnvironment()
  preferences[fields[key]] = enabled
  values[key] = enabled
  requests[key] = requests[key] + 1
  local request = requests[key]
  outcomes[key] = {status="pending-refresh"}
  if env.combat then outcomes[key] = {status="pending-combat", reason="combat"}
  elseif env.master and env.ready then
    local callback = read(ns.ApplyCategory, "function")
    if callback then
      local ok, status, reason = pcall(callback, key, enabled)
      -- A nested setter may have accepted a newer request for this domain.
      if requests[key] == request then
        if not ok then status, reason = "error", "renderer-error"
        else
          local booleanStatus = read(status, "boolean")
          local _, statusAbsent = read(status, "nil")
          if booleanStatus == true then status = "applied"
          elseif booleanStatus == false or statusAbsent == nil then status = "pending-refresh"
          else status = read(status, "string") end
          if not status or not statuses[status] then
            status, reason = "error", "invalid-renderer-state"
          end
        end
        if status == "applied" then
          local settled = environment()
          if settled.combat then status, reason = "pending-combat", "combat"
          elseif not settled.master or not settled.ready or settled.version ~= env.version then
            status, reason = "pending-refresh", nil
          end
        end
        outcomes[key] = {status=status, reason=text(reason)}
      end
    else outcomes[key].reason = "renderer-unavailable" end
  end
  Controls.Changed()
  return true, Controls.GetSnapshot()
end

function Controls.Attach()
  if handle then return true end
  local portal = _G.AzerothCeskyAPI
  if not plain(portal) then return false, "controls-unavailable" end
  local getControls = read(rawget(portal, "GetCompanionControls"), "function")
  if not getControls then return false, "controls-unavailable" end
  local ok, api = pcall(getControls, 1)
  if not ok or not plain(api) then return false, "controls-unavailable" end
  local register = read(rawget(api, "Register"), "function")
  if not register then return false, "controls-unavailable" end
  Controls.Changed()
  local descriptor = {schemaVersion=1, id="AAzerothAuctionator", name="Auctionator", version=Controls.version,
    hosts={"Auctionator"}, categories={ui=true, settings=true}}
  local registeredRevision = revision
  local accepted, registration, reason = pcall(register, descriptor,
    Controls.GetSnapshot(), Controls.SetCategory)
  if not accepted or not plain(registration)
    or not read(rawget(registration, "Publish"), "function") then
    return false, accepted and (text(reason) or "registration-failed") or "registration-failed"
  end
  handle = registration
  if revision ~= registeredRevision then publish() end
  return true
end

-- Core support is optional. These lifecycle events are sufficient for late
-- registration; rendering and pending work remain owned by the runtime.
local function onEvent(_, event, name)
  event, name = read(event, "string"), read(name, "string")
  if event == "ADDON_LOADED" then
    if name == addonName then Controls.Load() end
    if name == "AzerothCesky" or name == addonName then Controls.Attach() end
  else
    if event == "PLAYER_LOGIN" then Controls.Load() else Controls.Changed() end
    if event == "PLAYER_LOGIN" then Controls.Attach() end
  end
end

Controls.Load()
Controls.Attach()

local create = read(CreateFrame, "function")
if create then
  local ok, frame = pcall(create, "Frame")
  if ok and read(frame, "table") then
    local register = read(frame.RegisterEvent, "function")
    local setScript = read(frame.SetScript, "function")
    if register and setScript then
      for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
        pcall(register, frame, event)
      end
      pcall(setScript, frame, "OnEvent", onEvent)
    end
  end
end
