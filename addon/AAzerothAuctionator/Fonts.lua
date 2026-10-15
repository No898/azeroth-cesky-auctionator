-- Category-aware font ownership. The standalone branch below is retained for
-- older catalogue-only integrations; the controls renderer uses this branch.
local _, ns = ...
if type(ns) == "table" and ns.Presentation then
  local P = ns.Presentation
  local Fonts = {}
  ns.Fonts = Fonts
  local unpack = unpack or table.unpack
  local path = "Interface\\AddOns\\AAzerothAuctionator\\Fonts\\GentiumBook-Regular.ttf"
  local records = setmetatable({}, {__mode = "k"})
  local buttons = setmetatable({}, {__mode = "k"})
  local copies, count = {}, 0
  local states = {"Normal", "Highlight", "Disabled"}
  local function Safe(frame) return P.Safe(frame) end
  local function Current(region, state)
    if region.GetParent and region:GetParent() ~= state.parent then return false end
    if region.GetParent then return P.Category(region) == state.category end
    return P.Category(state.owner) == state.category
  end
  local function Same(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end
  local function Enabled(category) return P.Enabled(category) end
  local function RestoreRegion(region, state)
    if not Safe(region) then return false end
    if not Current(region, state) then records[region] = nil; return true end
    if Same({region:GetFont()}, state.applied) then region:SetFont(unpack(state.original)) end
    records[region] = nil
    return true
  end
  function Fonts.ApplyRegion(region, owner, category)
    if not Safe(region) or not region.GetFont or not region.SetFont then return false end
    local state = records[region]
    if not Enabled(category) then
      if state then RestoreRegion(region, state) end
      return false
    end
    local current = {region:GetFont()}
    if state and Same(current, state.applied) then
      if state.owner == owner and (not region.GetParent or region:GetParent() == state.parent) then state.category = category end
      return false
    end
    if current[1] and current[2] and current[1] ~= path then
      region:SetFont(path, current[2], current[3])
      local applied = {region:GetFont()}
      if applied[1] == path then
        records[region] = {owner = owner, category = category, original = current, applied = applied, parent = region.GetParent and region:GetParent()}
        return true
      end
    end
    return false
  end
  local function Copy(source)
    if type(source) == "string" then source = _G[source] end
    if not source or not source.GetFont then return end
    local face, size, flags = source:GetFont()
    if not face or not size or face == path then return end
    local copy = copies[source]
    if not copy then
      count = count + 1; copy = CreateFont("AAzerothAuctionatorFont" .. count); copies[source] = copy
    end
    copy:CopyFontObject(source)
    if copy:SetFont(path, size, flags) then return copy end
  end
  local function RestoreButton(frame, state)
    if not Safe(frame) then return false end
    if P.Category(frame) ~= state.category or (frame.GetParent and frame:GetParent() ~= state.parent) then buttons[frame] = nil; return true end
    for _, name in ipairs(states) do
      local record = state[name]
      if record then
        local get, set = frame["Get" .. name .. "FontObject"], frame["Set" .. name .. "FontObject"]
        if get and set and get(frame) == record.applied then set(frame, record.original) end
      end
    end
    buttons[frame] = nil
    return true
  end
  function Fonts.Apply(frame, category)
    if not Safe(frame) then return end
    local state = buttons[frame]
    if not Enabled(category) then
      if state then RestoreButton(frame, state) end
    else
      state = state or {category = category, parent = frame.GetParent and frame:GetParent()}
      for _, name in ipairs(states) do
        local get, set = frame["Get" .. name .. "FontObject"], frame["Set" .. name .. "FontObject"]
        if get and set then
          local original = get(frame)
          if not state[name] or original ~= state[name].applied then
            local copy = Copy(original)
            if copy then set(frame, copy); state[name] = {original = original, applied = copy} end
          end
        end
      end
      buttons[frame] = state
    end
    if frame.IsObjectType and frame:IsObjectType("EditBox") then Fonts.ApplyRegion(frame, frame, category) end
    if frame.GetRegions then
      for _, region in ipairs({frame:GetRegions()}) do
        if region ~= frame.TranslatorsText and region.IsObjectType and region:IsObjectType("FontString") then
          Fonts.ApplyRegion(region, frame, category)
        end
      end
    end
  end
  function Fonts.RestoreOwner(owner)
    local complete = true
    for region, state in pairs(records) do
      if state.owner == owner and not RestoreRegion(region, state) then complete = false end
    end
    if buttons[owner] and not RestoreButton(owner, buttons[owner]) then complete = false end
    return complete
  end
  function Fonts.ForgetOwner(owner)
    for region, state in pairs(records) do if state.owner == owner then records[region] = nil end end
    buttons[owner] = nil
  end
  function Fonts.RestoreCategory(category)
    local complete, pending = true, {}
    for region, state in pairs(records) do
      if state.category == category and not RestoreRegion(region, state) then complete = false end
    end
    for frame, state in pairs(buttons) do
      if state.category == category and not RestoreButton(frame, state) then complete = false end
    end
    return complete
  end
  function Fonts.Refresh(category)
    local complete, pending = true, {}
    for region, state in pairs(records) do
      if not category or state.category == category then
        local current = region.GetParent and P.Category(region) or P.Category(state.owner)
        if current ~= state.category or not Enabled(state.category) then
          if not RestoreRegion(region, state) then complete = false; pending[state.category] = true end
        end
      end
    end
    for frame, state in pairs(buttons) do
      if not category or state.category == category then
        if P.Category(frame) ~= state.category or not Enabled(state.category) then
          if not RestoreButton(frame, state) then complete = false; pending[state.category] = true end
        end
      end
    end
    return complete, pending
  end
  return
end

-- Czech glyph support for Auctionator-owned frames only. Shared Blizzard font
-- objects and the auction house's native tabs are never modified. Configuration
-- tooltips temporarily use the same face and restore their original fonts.
local fontPath = "Interface\\AddOns\\AAzerothAuctionator\\Fonts\\GentiumBook-Regular.ttf"
local translation = AUCTIONATOR_LOCALES_OVERRIDE
local watched = setmetatable({}, {__mode = "k"})
local pending = {}
local copies = {}
local fontCount = 0
local discoverPending = false
local scheduled = false
local installed = false
local Refresh
local Schedule
local tooltipFonts = setmetatable({}, {__mode = "k"})
local hookedTooltip
local refreshingTooltip = false

local function CanChange(frame)
  return frame and not (frame.IsForbidden and frame:IsForbidden())
    and not (frame.IsProtected and frame:IsProtected())
end

local function ApplyFont(region)
  if not CanChange(region) or not region.GetFont or not region.SetFont then return end
  local path, size, flags = region:GetFont()
  if path and size and path ~= fontPath then
    region:SetFont(fontPath, size, flags)
  end
end

local function SameFont(first, second)
  return first[1] == second[1] and first[2] == second[2] and first[3] == second[3]
end

local function RestoreTooltipFonts()
  if not CanChange(hookedTooltip) then return end
  for region, state in pairs(tooltipFonts) do
    if CanChange(region) then
      if SameFont({region:GetFont()}, state.applied) then
        region:SetFont(unpack(state.original))
      end
      tooltipFonts[region] = nil
    end
  end
end

local function InstallTooltipFonts()
  local tooltip = GameTooltip
  if not CanChange(tooltip) or hookedTooltip == tooltip then return end
  hookedTooltip = tooltip
  -- Clean up even during combat: these regions are unprotected, and retaining
  -- our font would otherwise leak it into the next owner's tooltip.
  hooksecurefunc(tooltip, "SetOwner", RestoreTooltipFonts)
  tooltip:HookScript("OnHide", RestoreTooltipFonts)
  hooksecurefunc(tooltip, "Show", function()
    if refreshingTooltip or not CanChange(tooltip) then return end
    local owner = tooltip:GetOwner()
    if InCombatLockdown() or not CanChange(owner)
      or AUCTIONATOR_LOCALES_OVERRIDE ~= translation or not watched[owner]
      or not (type(owner.tooltipText) == "string" or type(owner.tooltipTitleText) == "string"
        or type(owner.TooltipText) == "string") then
      RestoreTooltipFonts()
      return
    end
    local changed = false
    for _, region in ipairs({tooltip:GetRegions()}) do
      if CanChange(region) and region.IsObjectType and region:IsObjectType("FontString") then
        local original = {region:GetFont()}
        if original[1] and original[2] and original[1] ~= fontPath then
          ApplyFont(region)
          local applied = {region:GetFont()}
          if applied[1] == fontPath then
            tooltipFonts[region] = {original = original, applied = applied}
            changed = true
          end
        end
      end
    end
    -- Reflow wrapped text after changing metrics. Show is also called for an
    -- already-visible tooltip; OnShow alone would miss updates and new lines.
    if changed then
      refreshingTooltip = true
      tooltip:Show()
      refreshingTooltip = false
    end
  end)
end

-- Button state changes select their font objects again. Give each shared style
-- a private copy so hover/disabled states keep Czech glyphs and their own color.
local function FontCopy(source)
  if type(source) == "string" then source = _G[source] end
  if not source then return end
  local path, size, flags = source:GetFont()
  if not path or not size then return end
  if path == fontPath then return source end
  local copy = copies[source]
  if not copy then
    fontCount = fontCount + 1
    copy = CreateFont("AAzerothAuctionatorFont" .. fontCount)
    copies[source] = copy
  end
  copy:CopyFontObject(source)
  if copy:SetFont(fontPath, size, flags) then return copy end
end

local function ApplyButtonFonts(frame)
  for _, state in ipairs({"Normal", "Highlight", "Disabled"}) do
    local get = frame["Get" .. state .. "FontObject"]
    local set = frame["Set" .. state .. "FontObject"]
    if get and set then
      local original = get(frame)
      local copy = FontCopy(original)
      if copy and copy ~= original then set(frame, copy) end
    end
  end
end

local function Queue(frame)
  pending[frame] = true
  Schedule()
end

Refresh = function(frame, seen)
  if seen[frame] or not CanChange(frame) then return end
  seen[frame] = true
  -- Exclude Auctionator's hidden scanning tooltips as well as protected UI.
  if frame.IsObjectType and frame:IsObjectType("GameTooltip") then return end
  ApplyButtonFonts(frame)
  if frame.IsObjectType and frame:IsObjectType("EditBox") then ApplyFont(frame) end
  if frame.GetRegions then
    for _, region in ipairs({frame:GetRegions()}) do
      -- Credits contain untranslated CJK names outside Gentium's glyph set.
      if region ~= frame.TranslatorsText and region.IsObjectType
        and region:IsObjectType("FontString") then ApplyFont(region) end
    end
  end
  if not watched[frame] and frame.HookScript then
    watched[frame] = {}
    frame:HookScript("OnShow", function() Queue(frame) end)
    -- Result rows are pooled and may be created after opening the window or
    -- while scrolling. Observe this Auctionator listing's own scroll box.
    local scrollBox = (frame.ScrollArea and frame.ScrollArea.ScrollBox) or frame.ScrollBox
    if scrollBox and scrollBox.RegisterCallback and ScrollBoxListMixin and ScrollBoxListMixin.Event then
      scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnDataRangeChanged,
        function() Queue(frame) end, watched[frame])
    end
    if type(frame.UpdateTable) == "function" and scrollBox then
      hooksecurefunc(frame, "UpdateTable", function() Queue(frame) end)
    end
  end
  if frame.GetChildren then
    for _, child in ipairs({frame:GetChildren()}) do Refresh(child, seen) end
  end
end

local function Discover()
  -- Snapshot first: creating private font objects adds names to _G.
  for name, frame in pairs(_G) do
    if type(name) == "string" and name:match("^Auctionator")
      and type(frame) == "table" and type(frame.GetRegions) == "function"
      and type(frame.GetChildren) == "function" then
      pending[frame] = true
      -- Legacy Auctionator tab wrappers have no global name. Do not walk up
      -- arbitrary parents (that would reach the native AuctionFrame/UIParent).
      if frame.wrapperFrame then pending[frame.wrapperFrame] = true end
    end
  end
end

Schedule = function()
  if scheduled then return end
  scheduled = true
  C_Timer.After(0, function()
    scheduled = false
    if AUCTIONATOR_LOCALES_OVERRIDE ~= translation then
      pending = {}
      return
    end
    -- Keep pending work until leaving combat; never change protected frames.
    if InCombatLockdown() then return end
    if discoverPending then
      discoverPending = false
      Discover()
    end
    local batch = pending
    pending = {}
    local seen = {}
    for frame in pairs(batch) do Refresh(frame, seen) end
  end)
end

local function RequestDiscovery()
  discoverPending = true
  Schedule()
end

local function Install()
  if not Auctionator then return end
  InstallTooltipFonts()
  if installed then return end
  installed = true
  -- These factories can create settings/dialog frames after login. Post-hooks
  -- only schedule font work; their return values and behavior stay intact.
  if Auctionator.Config and Auctionator.Config.InternalInitializeFrames then
    hooksecurefunc(Auctionator.Config, "InternalInitializeFrames", RequestDiscovery)
  end
  for _, method in ipairs({"ShowEditBox", "ShowConfirm", "ShowConfirmAlt", "ShowMoney"}) do
    if Auctionator.Dialogs and Auctionator.Dialogs[method] then
      hooksecurefunc(Auctionator.Dialogs, method, RequestDiscovery)
    end
  end
  RequestDiscovery()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == "Auctionator" then
    Install()
  elseif event == "PLAYER_LOGIN" then
    Install()
  elseif installed and event == "AUCTION_HOUSE_SHOW" then
    RequestDiscovery()
  elseif installed and event == "PLAYER_REGEN_ENABLED" then
    Schedule()
  end
end)
