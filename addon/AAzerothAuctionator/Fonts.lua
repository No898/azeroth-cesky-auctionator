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
