-- The native in-game addon list is outside Auctionator's own frame tree.
-- Change only our title, and restore its font when a pooled row is reused.
local addonName = ...
local fontPath = "Interface\\AddOns\\AAzerothAuctionator\\Fonts\\GentiumBook-Regular.ttf"
local originals = setmetatable({}, {__mode = "k"})
local roots = setmetatable({}, {__mode = "k"})
local hooks = {}
local scheduled = false

local function CanChange(region)
  return region and not (region.IsForbidden and region:IsForbidden())
    and not (region.IsProtected and region:IsProtected())
end

local function ApplyEntry(entry)
  if InCombatLockdown() or not CanChange(entry) then return end
  local title = entry.Title
  if not CanChange(title) or not title.GetFont or not title.SetFont or not entry.GetID then return end
  local index = entry:GetID()
  local getInfo = C_AddOns and (C_AddOns.GetAddOnName or C_AddOns.GetAddOnInfo) or GetAddOnInfo
  local getCount = C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns
  if not getInfo or not getCount or type(index) ~= "number"
    or index < 1 or index > getCount() then return end
  local name = getInfo(index)
  local path, size, flags = title:GetFont()
  if not path or not size then return end
  if name == addonName then
    if path ~= fontPath then
      originals[title] = {path, size, flags}
      title:SetFont(fontPath, size, flags)
    end
  elseif originals[title] then
    local original = originals[title]
    -- Another addon may have applied a newer font or changed its scale.
    if path == fontPath and size == original[2] and flags == original[3] then
      title:SetFont(unpack(original))
    end
    originals[title] = nil
  end
end

local function Refresh(frame)
  if not CanChange(frame) then return end
  ApplyEntry(frame)
  if frame.GetChildren then
    for _, child in ipairs({frame:GetChildren()}) do Refresh(child) end
  end
end

local function Schedule()
  if scheduled then return end
  scheduled = true
  C_Timer.After(0, function()
    scheduled = false
    if not InCombatLockdown() and AddonList then Refresh(AddonList) end
  end)
end

local function Install()
  -- Support both the row initializer and older clients which refresh all rows
  -- in AddonList_Update. Do not replace either implementation.
  for method, callback in pairs({AddonList_InitAddon = ApplyEntry, AddonList_Update = Schedule}) do
    if not hooks[method] and type(_G[method]) == "function" then
      hooks[method] = true
      hooksecurefunc(_G, method, callback)
    end
  end
  if AddonList and not roots[AddonList] and CanChange(AddonList) then
    local owner = {}
    roots[AddonList] = owner
    AddonList:HookScript("OnShow", Schedule)
    local scroll = AddonList.ScrollBox
    if scroll and scroll.RegisterCallback and ScrollBoxListMixin and ScrollBoxListMixin.Event then
      scroll:RegisterCallback(ScrollBoxListMixin.Event.OnDataRangeChanged, Schedule, owner)
    end
    Schedule()
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, name)
  if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED"
    and (name == addonName or name == "Blizzard_AddOnList")) then
    Install()
  elseif event == "PLAYER_REGEN_ENABLED" and AddonList then
    Schedule()
  end
end)
