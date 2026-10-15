-- Host lifecycle fixture. Real locale, dropdown and tooltip code is loaded by
-- the Python tests; the frame/menu APIs below are WoW host doubles only.
local OriginalNewFont = NewFont
function NewFont(...)
  local region = OriginalNewFont(...)
  region.GetText = function(self) return self.text end
  region.SetText = function(self, text)
    self.text = text
    self.textWrites = (self.textWrites or 0) + 1
  end
  region.SetFormattedText = function(self, format, ...)
    self:SetText(string.format(format, ...))
  end
  region.IsProtected = function(self) return self.protected == true end
  region.IsForbidden = function(self) return self.forbidden == true end
  region.GetParent = function(self) return self.parent end
  region.SetParent = function(self, parent)
    if self.parent == parent then return end
    if self.parent then
      for index = #self.parent.regions, 1, -1 do
        if self.parent.regions[index] == self then table.remove(self.parent.regions, index) end
      end
    end
    self.parent = parent
    if parent then table.insert(parent.regions, self) end
  end
  return region
end

local OriginalCreateFrame = CreateFrame
function CreateFrame(kind, name, parent, template)
  local frame = OriginalCreateFrame(kind, name, parent)
  -- Physical WoW identity is independent of script-owned self.name/self.parent
  -- fields, which PanelConfig uses for category names and logical grouping.
  frame._frameName, frame._frameParent, frame.template = name, parent, template
  frame.GetName = function(self) return self._frameName end
  frame.GetParent = function(self) return self._frameParent end
  frame.GetDebugName = function(self) return self._frameName or "anonymous" end
  frame.GetObjectType = function(self) return self.kind end
  frame.GetScript = function(self, event)
    return self.scripts[event] and self.scripts[event][1]
  end
  frame.IsShown = function(self) return self.shown ~= false end
  frame.IsVisible = frame.IsShown
  frame.Show = function(self) self.shown = true; self:Fire("OnShow") end
  frame.Hide = function(self) self.shown = false; self:Fire("OnHide") end
  frame.GetID = function(self) return self.id end
  frame.SetID = function(self, value) self.id = value end
  frame.SetWidth = function(self, value) self.width = value end
  frame.SetHeight = function(self, value) self.height = value end
  frame.GetHeight = function(self) return self.height end
  frame.SetPoint = function() end
  frame.SetText = function(self, value) self.text = value end
  frame.GetText = function(self) return self.text end
  frame.SetFormattedText = function(self, format, ...)
    self:SetText(string.format(format, ...))
  end
  frame.SetParent = function(self, parent)
    if self._frameParent == parent then return end
    if self._frameParent then
      for index = #self._frameParent.children, 1, -1 do
        if self._frameParent.children[index] == self then table.remove(self._frameParent.children, index) end
      end
    end
    self._frameParent = parent
    if parent then table.insert(parent.children, self) end
  end
  return frame
end

function Label(frame, text)
  local region = NewFont()
  region.parent = frame
  region:SetText(text)
  table.insert(frame.regions, region)
  return region
end

-- Preserve nils and every return value, as the native post-hook does.
function hooksecurefunc(object, method, callback)
  if type(object) == "string" then
    callback, method, object = method, object, _G
  end
  local original = assert(object[method], method)
  object[method] = function(...)
    local function finish(...)
      return {n = select("#", ...), ...}
    end
    local results = finish(original(...))
    callback(...)
    return unpack(results, 1, results.n)
  end
end

function strsplit(delimiter, value)
  local values = {}
  for token in (value .. delimiter):gmatch("(.-)" .. delimiter) do
    table.insert(values, token)
  end
  return unpack(values)
end
function CreateFromMixins(...)
  local value = {}
  for index = 1, select("#", ...) do
    for key, item in pairs(select(index, ...)) do value[key] = item end
  end
  return value
end
function Mixin(target, ...)
  for index = 1, select("#", ...) do
    for key, item in pairs(select(index, ...)) do target[key] = item end
  end
  return target
end

nativeFont = "Fonts\\FRIZQT__.TTF"
chatMessages = {}
function print(...)
  local parts = {}
  for index = 1, select("#", ...) do parts[index] = tostring(select(index, ...)) end
  table.insert(chatMessages, table.concat(parts, " "))
end
DEFAULT_CHAT_FRAME = {AddMessage = function(_, message)
  table.insert(chatMessages, tostring(message))
end}
function AzcaCommand(message)
  for name, callback in pairs(SlashCmdList) do
    if _G["SLASH_" .. name .. "1"] == "/azca" then return callback(message) end
  end
  error("Standalone /azca slash command must be registered")
end
UIParent = CreateFrame("Frame", "UIParent")
SettingsPanel = CreateFrame("Frame", "SettingsPanel", UIParent)
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
GameTooltip.Title = Label(GameTooltip, "")
function GameTooltip:GetOwner() return self.owner end
function GameTooltip:SetOwner(owner) self.owner = owner end
function GameTooltip:SetText(text) self.Title:SetText(text) end
function GameTooltip:AddLine(text)
  self.Body = self.Body or Label(self, "")
  self.Body:SetText(text)
end
function GameTooltip:Show()
  self.shows = (self.shows or 0) + 1
  assert(self.shows < 50, "Tooltip hooks must settle")
  self.shown = true
end

MenuUtil = {}
local NewMenuDescription, InitializeContextMenu, NewMenuProxy
function MenuUtil.CreateRadioMenu(dropdown, selected, setter, ...)
  dropdown.entries = {...}
  dropdown.selected, dropdown.setter = selected, setter
  if not dropdown.GenerateMenu then
    function dropdown:GetMenuDescription() return self.menuDescription end
    function dropdown:GetMenu() return self.menu end
    function dropdown:IsMenuOpen() return self.menu and self.menu:IsShown() or false end
    function dropdown:OnMenuClosed() end
    function dropdown:GenerateMenu()
      self.generations = (self.generations or 0) + 1
      local root = NewMenuDescription()
      for _, entry in ipairs(self.entries) do
        local value = entry[2]
        local child = root:CreateButton(entry[1], function() self.setter(value) end)
        child.data = value
      end
      self.menuDescription = root
      if self.menu and self.menu:IsShown() then self.menu:SetMenuDescription(root) end
      return "menu-result", nil, 83
    end
    function dropdown:OpenMenu()
      if self:IsMenuOpen() then return end
      self:GenerateMenu()
      self.menu = NewMenuProxy(self, self.menuDescription)
      self.visibleMenu = self.menu
      self.menu:SetClosedCallback(function(menu) self:OnMenuClosed(menu) end)
    end
    function dropdown:CloseMenu()
      if self.menu then self.menu:Close(); self.menu = nil end
    end
  end
  dropdown:GenerateMenu()
end
nativeCreateRadioMenu = MenuUtil.CreateRadioMenu

NewMenuDescription = function(text, callback)
  local description = {text = text, callback = callback, children = {}, initializers = {}, resetters = {}}
  function description:GetText() return self.text end
  function description:SetText(value) self.text = value end
  function description:AddInitializer(initializer)
    table.insert(self.initializers, initializer)
  end
  function description:AddResetter(resetter) table.insert(self.resetters, resetter) end
  function description:EnumerateElementDescriptions() return ipairs(self.children) end
  function description:CreateButton(label, action)
    local child = NewMenuDescription(label, action)
    table.insert(self.children, child)
    return child
  end
  function description:CreateTitle(label)
    return self:CreateButton(label)
  end
  for method in pairs(contextMissingDescriptionMethods or {}) do description[method] = nil end
  return description
end

InitializeContextMenu = function(menu)
  menu.initializations = (menu.initializations or 0) + 1
  for _, description in ipairs(menu.description.children) do
    local frame = description.frame
    if not frame then
      frame = CreateFrame("Button", nil, menu)
      frame.Label = Label(frame, "")
      frame.Text = frame.Label
      description.frame = frame
    end
    frame.Label:SetText(description.text)
    for _, initializer in ipairs(description.initializers) do
      initializer(frame, description, menu)
    end
  end
end

NewMenuProxy = function(owner, description, missing)
  local menu = CreateFrame("Frame", nil, UIParent)
  menu.owner, menu.description, menu.closeCalls = owner, description, 0
  function menu:GetOwnerRegion() return self.owner end
  function menu:SetClosedCallback(callback) self.closedCallback = callback end
  function menu:ReinitializeAll() InitializeContextMenu(self) end
  function menu:SetMenuDescription(root)
    for _, child in ipairs(self.description.children) do
      for _, resetter in ipairs(child.resetters) do resetter(child.frame) end
    end
    self.children = {}
    self.description = root
    InitializeContextMenu(self)
  end
  function menu:Close()
    self.closeCalls = self.closeCalls + 1
    self.closed = true
    if self.closedCallback then self.closedCallback(self) end
    self.shown = false
    -- Blizzard MenuMixin.Close calls OnClose, hides, then invokes description
    -- resetters before MenuElementFactory releases its pooled frame.
    self.fontsAtCleanup = {}
    for index, child in ipairs(self.description.children) do
      for _, resetter in ipairs(child.resetters) do resetter(child.frame) end
      self.fontsAtCleanup[index] = child.frame.Label.path
    end
  end
  for method in pairs(missing or {}) do menu[method] = nil end
  InitializeContextMenu(menu)
  return menu
end

function MenuUtil.CreateContextMenu(owner, generator)
  contextMenuCreates = (contextMenuCreates or 0) + 1
  local description = NewMenuDescription()
  generator(owner, description)
  local menu = NewMenuProxy(owner, description, contextMissingMethods)
  lastContextMenu = menu
  return menu
end
nativeCreateContextMenu = MenuUtil.CreateContextMenu

function MakeBagUse()
  bagGroupName = bagGroupName or "FAVOURITES"
  bag = CreateFrame("Frame", "AuctionatorSellingBagFrame", UIParent)
  Mixin(bag, AuctionatorBagUseMixin)
  bag.View = {itemMap = {[bagGroupName] = {}}, hiddenItems = {}}
  bagButton = CreateFrame("Button", nil, bag)
  bagButton:SetID(1705)
  bagButton.itemInfo = {sortKey = "sort-451", itemID = 1705, itemLink = "item:1705", isCustom = false}
  bagButton.key, bagButton.nextItem, bagButton.prevItem = {id = 451}, {id = 452}, {id = 450}
  for _, method in ipairs({"AddToDefaultGroup", "RemoveFromDefaultGroup", "HideItem", "UnhideItem", "UnhideAll"}) do
    local actionName = method
    bag[method] = function(self, button)
      bagAction = {method = actionName, owner = self, button = button, id = button and button:GetID()}
    end
  end
  Auctionator.Groups = {
    GetGroupNameByIndex = function(index) assert(index == 1); return bagGroupName end,
    Utilities = {ToPostingItem = function(info)
      postingInput = info
      return {itemID = info.itemID}
    end},
  }
  Auctionator.Selling = {Events = {BagItemClicked = "BagItemClicked"}}
  Auctionator.EventBus = {Fire = function(_, owner, event, info, ...)
    postingEvent = {owner = owner, event = event, info = info, extra = select("#", ...)}
  end}
  GRAY_FONT_COLOR = {WrapTextInColorCode = function(_, text) return "|cff808080" .. text .. "|r" end}
end

function MakeConfigCheckbox(parent, source)
  local frame = CreateFrame("Frame", nil, parent, "AuctionatorConfigurationCheckbox")
  frame.CheckBox = CreateFrame("CheckButton", nil, frame)
  frame.CheckBox.Label = Label(frame.CheckBox, "")
  frame.CheckBox.SetChecked = function(self, value) self.checked = value end
  frame.CheckBox.GetChecked = function(self) return self.checked end
  Mixin(frame, AuctionatorConfigCheckboxMixin)
  frame.labelText = source
  frame:OnLoad()
  return frame
end

function MakeExportLists()
  export = CreateFrame("Frame", "AuctionatorExportFrame", shopping)
  Mixin(export, AuctionatorListExportFrameMixin)
  export.ScrollBox = CreateFrame("Frame", nil, export)
  export.ScrollBox.ListListingFrame = CreateFrame("Frame", nil, export.ScrollBox)
  export.ScrollBox.ListListingFrame.MarkDirty = function() end
  export.checkBoxPool = {active = {}}
  function export.checkBoxPool:ReleaseAll()
    for _, checkbox in ipairs(self.active) do checkbox:Hide() end
    self.active = {}
  end
  function export.checkBoxPool:Acquire()
    local checkbox = MakeConfigCheckbox(export.ScrollBox.ListListingFrame)
    table.insert(self.active, checkbox)
    return checkbox
  end
  function export.checkBoxPool:EnumerateActive()
    local index = 0
    return function() index = index + 1; return self.active[index] end
  end
  local lists = {
    {GetName = function() return "Shopping" end},
    {GetName = function() return "Selling" end},
  }
  Auctionator.Shopping = {ListManager = {
    GetCount = function() return #lists end,
    GetByIndex = function(_, index) return lists[index] end,
  }, Lists = {GetBatchExportString = function(name)
    exportedNames = exportedNames or {}
    table.insert(exportedNames, name)
    return "export:" .. name
  end}}
  export.copyTextDialog = CreateFrame("Frame", nil, export)
  export.copyTextDialog.SetExportString = function(_, value) exportedText = value end
  export:RefreshLists()
end

Settings = {categoriesByOwner = {}, addonCategories = {}}
local function NewSettingsCategory(owner, name, parent)
  local category = {name = name, owner = owner, parent = parent}
  function category:SetName(value) self.name = value end
  function category:GetName() return self.name end
  Settings.categoriesByOwner[owner] = category
  return category
end
function Settings.RegisterCanvasLayoutCategory(owner, name)
  return NewSettingsCategory(owner, name)
end
function Settings.RegisterCanvasLayoutSubcategory(parent, owner, name)
  return NewSettingsCategory(owner, name, parent)
end
function Settings.RegisterAddOnCategory(category)
  table.insert(Settings.addonCategories, category)
end
nativeRegisterCanvasLayoutCategory = Settings.RegisterCanvasLayoutCategory
nativeRegisterCanvasLayoutSubcategory = Settings.RegisterCanvasLayoutSubcategory

function AssertNativeGlobalFunctions()
  assert(MenuUtil.CreateRadioMenu == nativeCreateRadioMenu,
    "Companion must preserve the native MenuUtil.CreateRadioMenu identity")
  assert(MenuUtil.CreateContextMenu == nativeCreateContextMenu,
    "Companion must preserve the native MenuUtil.CreateContextMenu identity")
  assert(Settings.RegisterCanvasLayoutCategory == nativeRegisterCanvasLayoutCategory,
    "Companion must preserve the native Settings category registration identity")
  assert(Settings.RegisterCanvasLayoutSubcategory == nativeRegisterCanvasLayoutSubcategory,
    "Companion must preserve the native Settings subcategory registration identity")
end

function DeepCopy(source)
  if type(source) ~= "table" then return source end
  local result = {}
  for key, value in pairs(source) do result[key] = DeepCopy(value) end
  return result
end

function InstallCore(mode)
  coreRegisters, corePublishes, v1Calls, v1Events = 0, 0, 0, 0
  if mode == "none" then AzerothCeskyAPI = nil; return end
  AzerothCeskyAPI = {
    GetInterface = function() v1Calls = v1Calls + 1; return {} end,
    Subscribe = function() v1Events = v1Events + 1 end,
  }
  if mode == "old" then return end
  AzerothCeskyAPI.GetCompanionControls = function(version)
    assert(version == 1)
    return {
      Register = function(descriptor, snapshot, setter)
        coreRegisters = coreRegisters + 1
        coreDescriptor, coreSnapshot, coreSetter = DeepCopy(descriptor), DeepCopy(snapshot), setter
        return {
          Publish = function(value)
            corePublishes = corePublishes + 1
            coreSnapshot = DeepCopy(value)
            return true
          end,
          Unregister = function() return true end,
        }
      end,
    }
  end
end

function MakeOwnedFrames()
  shopping = CreateFrame("Frame", "AuctionatorShoppingFrame", UIParent)
  shopping.Title = Label(shopping, AUCTIONATOR_L_SHOPPING_TAB)
  shopping.Status = Label(shopping, Auctionator.Locales.Apply("BUYING_X_FOR_X", "Item-1705", "12g"))
  shopping.Button = Button(nil, shopping)
  shopping.originalButtonFont = shopping.Button.Normal
  settings = CreateFrame("Frame", "AuctionatorConfigBasicOptionsFrame", SettingsPanel)
  settings.Title = Label(settings, AUCTIONATOR_L_CONFIG_BASIC_OPTIONS_CATEGORY)
  settings.Button = Button(nil, settings)
  settings.originalButtonFont = settings.Button.Normal
  settingsControl = CreateFrame("Frame", nil, settings)
  settingsControl.Label = Label(settingsControl, AUCTIONATOR_L_CONFIG_CRAFTING_INFO_SHOW)
  settingsControl.tooltipTitleText = AUCTIONATOR_L_CONFIG_CRAFTING_INFO_SHOW_TOOLTIP_HEADER
  settingsControl.tooltipText = AUCTIONATOR_L_CONFIG_CRAFTING_INFO_SHOW_TOOLTIP_TEXT
  dropdown = CreateFrame("Frame", nil, settings)
  dropdown.Label = Label(dropdown, "")
  dropdown.DropDown = CreateFrame("DropdownButton", nil, dropdown)
  dropdown.textString = "NONE;SHOPPING_TAB;SELLING_TAB"
  dropdown.valuesString = "0;17;23"
  dropdown.labelText = AUCTIONATOR_L_DEFAULT_TAB_TEXT
  Mixin(dropdown, AuctionatorDropDownMixin)
  dropdown:OnLoad()
  dropdown:SetValue("17")
  dropdown.DropDown:OpenMenu()
  settings.DefaultTab = dropdown
  shopping:SetID(1705)
  settings:SetID(451)
  foreign = CreateFrame("Frame", "AnotherAddon", UIParent)
  foreign.Title = Label(foreign, "Shopping")
end
