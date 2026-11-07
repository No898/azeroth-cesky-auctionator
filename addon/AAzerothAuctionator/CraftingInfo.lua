-- Auctionator draws its cost/profit panel inside the native profession windows
-- (TradeSkillFrame, CraftFrame). Those windows carry the Azeroth česky flag;
-- a grey flag means the player wants the original text there. When the main
-- addon is present and reports the window as original, the panel is redrawn
-- with Auctionator's own enUS strings. Without the main addon (or with an
-- older one lacking IsWindowOriginal) nothing changes: the panel stays Czech.
local translation = AUCTIONATOR_LOCALES_OVERRIDE
local KEYS = {"TO_CRAFT_COLON", "PROFIT_COLON", "PROFIT_WARNING_NOT_EXACT_ITEM",
  "PROFIT_WARNING_MISSING", "PROFIT_WARNING_AGE"}
local PANELS = {
  {name = "AuctionatorCraftingInfo", owner = "CraftingInfo"},
  {name = "AuctionatorEnchantInfoFrame", owner = "EnchantInfo"},
}
local api, english, subscribed
local hooked = {}
local englishPanels = setmetatable({}, {__mode = "k"})

local function Ours()
  return AUCTIONATOR_LOCALES_OVERRIDE == translation
end

local function Core()
  if api then return api end
  local portal = type(AzerothCeskyAPI) == "table" and AzerothCeskyAPI
  if not portal or type(portal.GetInterface) ~= "function" then return end
  local ok, value = pcall(portal.GetInterface, 1)
  if ok and type(value) == "table" and type(value.IsWindowOriginal) == "function" then
    api = value
    return api
  end
end

local function Original(frame)
  local core = Core()
  if not core then return false end
  local ok, value = pcall(core.IsWindowOriginal, frame)
  return ok and value == true
end

local function English()
  if english then return english end
  local factory = type(AUCTIONATOR_LOCALES) == "table" and AUCTIONATOR_LOCALES.enUS
  if type(factory) ~= "function" then return end
  local ok, values = pcall(factory)
  if not ok or type(values) ~= "table" then return end
  english = {}
  for _, key in ipairs(KEYS) do
    if type(values[key]) == "string" then english[key] = values[key]:gsub("\\n", "\n") end
  end
  english.SEARCH = type(values.SEARCH) == "string" and values.SEARCH or nil
  return english
end

-- Auctionator builds the text from AUCTIONATOR_L_* globals. Point the few
-- panel keys at enUS for one synchronous call, then restore the Czech values.
local function InfoText(owner)
  local strings = English()
  local module = Auctionator and Auctionator[owner]
  if not strings or type(module) ~= "table" or type(module.GetInfoText) ~= "function" then return end
  local saved = {}
  for _, key in ipairs(KEYS) do
    saved[key] = _G["AUCTIONATOR_L_" .. key]
    if strings[key] then _G["AUCTIONATOR_L_" .. key] = strings[key] end
  end
  local ok, text = pcall(module.GetInfoText)
  for _, key in ipairs(KEYS) do _G["AUCTIONATOR_L_" .. key] = saved[key] end
  if ok and type(text) == "string" then return text end
end

local function SetSearch(frame, text)
  local button = frame.SearchButton
  if type(text) == "string" and button and button.SetText then
    button:SetText(text)
    if button.FitToText then button:FitToText() end
  end
end

local function Repaint(frame, owner)
  if not Ours() then return end
  if Original(frame) then
    local text = InfoText(owner)
    if text and frame.Total and frame.Total.SetText then
      frame.Total:SetText(text)
      englishPanels[frame] = true
      SetSearch(frame, English() and English().SEARCH)
    end
  elseif englishPanels[frame] then
    -- Back to Czech: Auctionator already drew its Czech total; restore the button.
    englishPanels[frame] = nil
    SetSearch(frame, AUCTIONATOR_L_SEARCH)
  end
end

local function Attach()
  for _, panel in ipairs(PANELS) do
    local frame = _G[panel.name]
    if not hooked[panel.name] and type(frame) == "table" and type(frame.UpdateTotal) == "function" then
      hooked[panel.name] = true
      local owner = panel.owner
      hooksecurefunc(frame, "UpdateTotal", function(self) Repaint(self, owner) end)
      Repaint(frame, owner)
    end
  end
end

-- A flag change redraws only a visible panel through Auctionator's own update.
local function Changed(event)
  local reasons = type(event) == "table" and event.reasons
  if type(reasons) ~= "table" or not (reasons.windows or reasons.preferences or reasons.ready) then return end
  for _, panel in ipairs(PANELS) do
    local frame = hooked[panel.name] and _G[panel.name]
    if frame and frame.IsVisible and frame:IsVisible() then pcall(frame.UpdateTotal, frame) end
  end
end

local function Subscribe()
  if subscribed then return end
  local core = Core()
  if core and type(core.Subscribe) == "function" then
    local ok, unsubscribe = pcall(core.Subscribe, Changed)
    subscribed = ok and unsubscribe ~= nil
  end
end

local function Install()
  if not Auctionator then return end
  for _, panel in ipairs(PANELS) do
    local module = Auctionator[panel.owner]
    if type(module) == "table" and type(module.Initialize) == "function" and not hooked[panel.owner] then
      hooked[panel.owner] = true
      hooksecurefunc(module, "Initialize", Attach)
    end
  end
  Attach()
  Subscribe()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, name)
  if (event == "ADDON_LOADED" and name == "Auctionator") or event == "PLAYER_LOGIN" then Install() end
end)
