-- Keep Auctionator's catalogue in the client language. Translate at owned
-- presentation seams so UI and configuration can be switched independently.
local _, ns = ...
local P = {}
ns.Presentation = P
local unpack = unpack or table.unpack
local czechFactory = AUCTIONATOR_LOCALES_OVERRIDE
local NativeCatalogue
local providerRetired = false
local native, czech, exact, patterns = {}, {}, {}, {}
local roots = setmetatable({}, {__mode = "k"})
local watched = setmetatable({}, {__mode = "k"})
local texts = setmetatable({}, {__mode = "k"})
local pendingSources = setmetatable({}, {__mode = "k"})
local menus = setmetatable({}, {__mode = "k"})
local tooltipEpoch = setmetatable({}, {__mode = "k"})
local leases = setmetatable({}, {__mode = "k"})
local tooltipHooks = setmetatable({}, {__mode = "k"})
local pendingTooltips = setmetatable({}, {__mode = "k"})
local rootProof = setmetatable({}, {__mode = "k"})
local resolvers = setmetatable({}, {__mode = "k"})
local categoryNames = setmetatable({}, {__mode = "k"})
local openMenus = setmetatable({}, {__mode = "k"})
local pendingMenus = setmetatable({}, {__mode = "k"})
local writing, scheduled, installed = false, false, false
local dialogContext
local blocked = {}
local Refresh, Queue, WatchTooltip, TooltipRegions, AdoptDropdown, WrappedInitAgain

local function Pack(...) return {n = select("#", ...), ...} end
local function InspectSafety(frame)
  if not frame then return false end
  local seen = {}
  for _ = 1, 64 do
    if not frame then return true end
    if seen[frame] or (frame.IsForbidden and frame:IsForbidden())
      or (frame.IsProtected and frame:IsProtected()) then return false end
    seen[frame] = true
    frame = frame.GetParent and frame:GetParent()
  end
  return false
end
local function Safe(frame)
  local ok, safe = pcall(InspectSafety, frame)
  if not ok then return false, "unreadable-widget" end
  if safe == true then return true end
  return false, "protected-widget"
end
P.Safe = Safe
local function ReadParent(frame)
  return pcall(function() return frame.GetParent and frame:GetParent() end)
end
local function InspectRoot(frame)
  local proof = rootProof[frame]
  if not proof then return false end
  if proof.menuContext then
    if proof.retiring then return true end
    local context, menu = proof.menuContext, proof.menuContext.menu
    if frame.GetParent and frame:GetParent() ~= proof.parent then return false end
    return menu and menu.GetOwnerRegion and menu.IsShown and menu:GetOwnerRegion() == context.owner and menu:IsShown()
  end
  if proof.alias and _G[proof.alias] ~= proof.owner then return false end
  if proof.owner ~= frame and proof.owner.wrapperFrame ~= frame then return false end
  if frame.GetParent and frame:GetParent() ~= proof.parent then return false end
  return true
end
local function RootValid(frame)
  local ok, valid = pcall(InspectRoot, frame)
  if not ok then return false, "unreadable-widget" end
  return valid
end
local function Combat() return InCombatLockdown and InCombatLockdown() end
local function ProviderActive() return AUCTIONATOR_LOCALES_OVERRIDE == NativeCatalogue end
local function Enabled(category)
  return ProviderActive() and (not ns.CategoryEnabled or ns.CategoryEnabled(category))
end
P.Enabled = Enabled
local function Normalize(value) return value:gsub("\\n", "\n") end
local function Escape(value) return (value:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end

local function IndexCatalogue()
  exact, patterns = {}, {}
  for key, source in pairs(native) do
    local target = czech[key]
    if type(source) == "string" and type(target) == "string" then
      target = Normalize(target)
      czech[key] = target
      if exact[source] == nil then exact[source] = target
      elseif exact[source] ~= target then exact[source] = false end
      -- Upstream's display formats use %s. Captures are kept byte-for-byte;
      -- they are never interpreted as locale keys, IDs, or search expressions.
      if source:find("%%s") then
        local chunks, cursor, count = {}, 1, 0
        while true do
          local start, finish = source:find("%%[%%s]", cursor)
          if not start then break end
          chunks[#chunks + 1] = Escape(source:sub(cursor, start - 1))
          if source:sub(start, finish) == "%s" then
            chunks[#chunks + 1] = "(.-)"; count = count + 1
          else chunks[#chunks + 1] = "%%" end
          cursor = finish + 1
        end
        chunks[#chunks + 1] = Escape(source:sub(cursor))
        -- A bare %s is data, not a label. Require literal source context.
        if #source > count * 2 then
          patterns[#patterns + 1] = {"^" .. table.concat(chunks) .. "$", target, #source}
        end
      end
    end
  end
  table.sort(patterns, function(a, b) return a[3] > b[3] end)
end

NativeCatalogue = function()
  local locales = AUCTIONATOR_LOCALES or {}
  local fallback = locales.enUS and locales.enUS() or {}
  local locale = GetLocale and GetLocale() or "enUS"
  local source = locales[locale] and locales[locale]() or fallback
  native = {}
  for key, value in pairs(fallback) do native[key] = Normalize(value) end
  for key, value in pairs(source) do native[key] = Normalize(value) end
  local catalogue = ns.Translations or (czechFactory and czechFactory()) or {}
  if type(catalogue) == "function" then catalogue = catalogue() end
  czech = {}; for key, value in pairs(catalogue) do czech[key] = value end
  IndexCatalogue()
  local result = {}
  for key, value in pairs(native) do result[key] = value end
  return result
end
AUCTIONATOR_LOCALES_OVERRIDE = NativeCatalogue

function P.Resolve(source, category)
  if type(source) ~= "string" or not Enabled(category) then return source end
  local target = exact[source]
  if target then return target end
  for _, format in ipairs(patterns) do
    local args = {source:match(format[1])}
    if #args > 0 then
      local ok, translated = pcall(string.format, format[2], unpack(args))
      if ok then return translated end
    end
  end
  return source
end

-- This lookup follows real parents. A pooled widget moved to another owner
-- cannot retain a cached Auctionator category.
local function InspectCategory(frame)
  local lease = leases[frame]
  if lease and tooltipEpoch[lease.tooltip] == lease.epoch and not (frame.IsForbidden and frame:IsForbidden())
    and (lease.retiring or not lease.tooltip.GetOwner or lease.tooltip:GetOwner() == lease.owner) then return lease.category end
  local seen = {}
  for _ = 1, 64 do
    if not frame or seen[frame] or (frame.IsForbidden and frame:IsForbidden()) then return nil end
    seen[frame] = true
    if roots[frame] then
      local valid, reason = RootValid(frame)
      if valid then return roots[frame] end
      return nil, reason
    end
    local name = frame.GetName and frame:GetName()
    if type(name) == "string" and name:match("^Auctionator") and _G[name] == frame then
      if name:match("^AuctionatorConfig") then return "settings" end
      return "ui"
    end
    frame = frame.GetParent and frame:GetParent()
  end
end
function P.Category(frame)
  local ok, category, reason = pcall(InspectCategory, frame)
  if not ok then return nil, "unreadable-widget" end
  return category, reason
end

local function DataText(owner, region)
  if owner.IsObjectType and owner:IsObjectType("EditBox") then return true end
  if region == owner.TranslatorsText then return true end
  if owner.rowData and region == owner.Text then
    return owner.rowData.itemName ~= nil or owner.rowData.sellers ~= nil
  end
  if owner.elementData and region == owner.Text then return true end
  if owner.TitleArea and region == owner.TitleArea.Text then return true end
  if owner.GetParent then
    local parent = owner:GetParent()
    if parent and parent.TitleArea == owner and region == owner.Text then return true end
    if parent and parent.list and parent.CheckBox == owner then return true end
    if parent and parent.CheckBox == owner and region == owner.Label then
      local listing = parent.GetParent and parent:GetParent()
      local ancestor = listing
      for _ = 1, 8 do
        if not ancestor then break end
        if ancestor.checkBoxPool and ancestor.ScrollBox and ancestor.ScrollBox.ListListingFrame == listing then return true end
        ancestor = ancestor.GetParent and ancestor:GetParent()
      end
    end
    if parent and parent.DropDown == owner and parent.InitAgain and not parent.textString and parent.value ~= "" then return true end
  end
  return false
end

local function SameTextOwner(region, state)
  if region.GetParent and region:GetParent() ~= state.parent then return false end
  return P.Category(region) == state.category or (not region.GetParent and P.Category(state.owner) == state.category)
end
local function TextOwner(region, owner)
  if region == owner then return region end
  return region.GetParent and region:GetParent() or owner
end
local function TextCategory(region, owner)
  if region.GetParent then return P.Category(region) end
  return P.Category(owner)
end
local function TextContext(region, owner, fallbackCategory)
  local ok, live, category, reason = pcall(function()
    local currentOwner = TextOwner(region, owner)
    local currentCategory, why = TextCategory(region, currentOwner)
    return currentOwner, currentCategory, why
  end)
  if not ok or reason then
    category = (texts[region] and texts[region].category) or fallbackCategory
    if category then
      blocked[category] = "unreadable-widget"
      if ns.Controls then ns.Controls.Pending(category, "pending-refresh", "unreadable-widget") end
    end
    return nil
  end
  return live, category
end
local function PlainValue(value)
  if type(issecretvalue) ~= "function" then return true end
  local ok, secret = pcall(issecretvalue, value)
  return ok and secret == false
end
local function PendingSource(region, category)
  if not category then return end
  pendingSources[region] = category
  blocked[category] = "unreadable-source"
  if ns.Controls then ns.Controls.Pending(category, "pending-refresh", "unreadable-source") end
end
local function FormattedSource(format, ...)
  if not PlainValue(format) or type(format) ~= "string" then return false end
  for index = 1, select("#", ...) do if not PlainValue(select(index, ...)) then return false end end
  -- Pass the original varargs directly. Nil positions and Czech user data are
  -- never copied into a sparse array or interpreted as locale keys.
  return pcall(string.format, format, ...)
end
local function ReadText(region, category)
  local ok, value = pcall(region.GetText, region)
  if ok and type(issecretvalue) == "function" then
    local checked, secret = pcall(issecretvalue, value)
    ok = checked and secret == false
  end
  if not ok or (value ~= nil and type(value) ~= "string") then
    category = category or (texts[region] and texts[region].category)
    if category then blocked[category] = "unreadable-widget" end
    return false
  end
  return true, value
end
local function WriteText(region, value, category)
  writing = true
  local ok = pcall(region.SetText, region, value)
  writing = false
  if not ok then blocked[category] = "unreadable-widget" end
  return ok
end
local function RestoreText(region, state)
  if not Safe(region) or not region.GetText or not region.SetText then
    blocked[state.category] = "unreadable-widget"; return false
  end
  if not SameTextOwner(region, state) then texts[region] = nil; return true end
  if pendingSources[region] then blocked[state.category] = "unreadable-source"; return false end
  local readable, current = ReadText(region, state.category)
  if not readable then return false end
  if current == state.applied and state.applied ~= state.source then
    if not WriteText(region, state.source, state.category) then return false end
  end
  state.applied = state.source
  return true
end

local function Render(region, owner, source, category)
  if writing or type(source) ~= "string" or not region.GetText or not region.SetText then return end
  local state = texts[region]
  if not category then
    if state then texts[region] = nil end
    return
  end
  if not Safe(region) or not Safe(owner) then blocked[category] = "protected-widget"; return end
  if DataText(owner, region) then
    if state and RestoreText(region, state) then texts[region] = nil end
    return
  end
  if ProviderActive() then providerRetired = false
  else
    if ns.Fonts and not Combat() then ns.Fonts.RestoreOwner(owner) end
    if not providerRetired then providerRetired = true; Queue() end
  end
  if Combat() then blocked[category] = "combat"; return end
  local readable, current = ReadText(region, category)
  if not readable then return false end
  local translated = resolvers[region] and resolvers[region](source, category) or P.Resolve(source, category)
  if current ~= translated and not WriteText(region, translated, category) then return false end
  texts[region] = {source = source, applied = translated, owner = owner, category = category, parent = region.GetParent and region:GetParent()}
  return true
end

local function WatchText(region, owner, category)
  if not region.GetText or not region.SetText or DataText(owner, region) then return end
  local watch = watched[region] or {}; watched[region] = watch
  if not watch.text then
    watch.text = true
    hooksecurefunc(region, "SetText", function(self, source)
      if not writing then
        local live, category = TextContext(self, owner, category)
        if not live then return end
        if PlainValue(source) and (source == nil or type(source) == "string") then
          pendingSources[self] = nil
          Render(self, live, source, category)
        else PendingSource(self, category) end
      end
    end)
    if region.SetFormattedText then
      hooksecurefunc(region, "SetFormattedText", function(self, format, ...)
        if not writing then
          local live, category = TextContext(self, owner, category)
          if not live or not category then return end
          local readable, source = FormattedSource(format, ...)
          if readable then
            pendingSources[self] = nil
            Render(self, live, source, category)
          else PendingSource(self, category) end
        end
      end)
    end
  end
  if pendingSources[region] then blocked[category] = "unreadable-source"; return end
  local readable, current = ReadText(region, category)
  if not readable then return end
  local state = texts[region]
  local source = state and current == state.applied and state.source or current
  Render(region, owner, source, category)
end

local function Scan(frame, category, seen)
  if not frame or seen[frame] then return end
  seen[frame] = true
  local safe, reason = Safe(frame)
  if not safe then blocked[category] = reason; return end
  if frame.IsObjectType and frame:IsObjectType("GameTooltip") then return end
  if AdoptDropdown then AdoptDropdown(frame, category) end
  -- Custom configuration Frames expose GetText/SetText for business values
  -- (export-list names, for example). Their FontStrings are presentation; the
  -- Frame methods themselves must never be used as a translation seam.
  if frame.IsObjectType and (frame:IsObjectType("Button") or frame:IsObjectType("CheckButton")) then
    WatchText(frame, frame, category)
  end
  if frame.GetRegions then
    for _, region in ipairs({frame:GetRegions()}) do
      if Safe(region) and region.IsObjectType and region:IsObjectType("FontString") then
        WatchText(region, frame, category)
      end
    end
  end
  if ns.Fonts then ns.Fonts.Apply(frame, category) end
  local watch = watched[frame]
  if not watch or not watch.frame then
    watch = watch or {}; watched[frame] = watch; watch.frame = true
    if frame.HookScript then frame:HookScript("OnShow", Queue) end
    local scroll = (frame.ScrollArea and frame.ScrollArea.ScrollBox) or frame.ScrollBox
    if scroll and scroll.RegisterCallback and ScrollBoxListMixin and ScrollBoxListMixin.Event then
      scroll:RegisterCallback(ScrollBoxListMixin.Event.OnDataRangeChanged, function() Queue(frame) end, watch)
    end
    if scroll and type(frame.UpdateTable) == "function" then hooksecurefunc(frame, "UpdateTable", Queue) end
  end
  if frame.GetChildren then
    for _, child in ipairs({frame:GetChildren()}) do Scan(child, P.Category(child) or category, seen) end
  end
end

local function Discover()
  for name, frame in pairs(_G) do
    if type(name) == "string" and name:match("^Auctionator") and type(frame) == "table"
      and type(frame.GetRegions) == "function" and type(frame.GetChildren) == "function" then
      if not name:match("^AuctionatorDialog") or not roots[frame] then
        roots[frame] = name:match("^AuctionatorConfig") and "settings" or "ui"
      end
      if not rootProof[frame] or rootProof[frame].alias ~= name then
        local readable, parent = ReadParent(frame)
        if readable then rootProof[frame] = {alias = name, owner = frame, parent = parent}
        else blocked[roots[frame]] = "unreadable-widget" end
      end
      if frame.wrapperFrame then
        roots[frame.wrapperFrame] = roots[frame]
        local readable, parent = ReadParent(frame.wrapperFrame)
        if readable then rootProof[frame.wrapperFrame] = {alias = name, owner = frame, parent = parent}
        else blocked[roots[frame]] = "unreadable-widget" end
      end
    end
  end
end

local function PendingTooltip(tooltip, discard)
  local first = not pendingTooltips[tooltip]
  pendingTooltips[tooltip] = {discard = discard or (pendingTooltips[tooltip] and pendingTooltips[tooltip].discard)}
  for region, lease in pairs(leases) do
    if lease.tooltip == tooltip then lease.retiring = false; blocked[lease.category] = "unreadable-widget" end
  end
  if first then Queue() end
  return false
end
local function ForgetTooltip(tooltip)
  for region, state in pairs(texts) do
    if state.owner == tooltip then texts[region], resolvers[region] = nil, nil end
  end
  for region, lease in pairs(leases) do if lease.tooltip == tooltip then leases[region] = nil end end
  pendingTooltips[tooltip] = nil
  tooltipEpoch[tooltip] = (tooltipEpoch[tooltip] or 0) + 1
end
local function ReleaseTooltip(tooltip, discard, allowHandoff)
  if not Safe(tooltip) then return PendingTooltip(tooltip, discard) end
  local readable, owner = true, nil
  if tooltip.GetOwner then readable, owner = pcall(tooltip.GetOwner, tooltip) end
  if not readable then return PendingTooltip(tooltip, discard) end
  local handedOff = false
  for _, lease in pairs(leases) do
    if lease.tooltip == tooltip and lease.owner ~= owner then handedOff = true end
  end
  if handedOff and not allowHandoff then
    -- An unsafe earlier cleanup can be followed by a new owner. This is a
    -- proven handoff, not permission to restore values into that owner's UI.
    if ns.Fonts then ns.Fonts.ForgetOwner(tooltip) end
    ForgetTooltip(tooltip)
    return true
  end
  local complete = true
  for region, lease in pairs(leases) do
    if lease.tooltip == tooltip then lease.retiring = Safe(region) end
  end
  for region, state in pairs(texts) do
    if state.owner == tooltip and not discard and not RestoreText(region, state) then complete = false end
  end
  if ns.Fonts and not ns.Fonts.RestoreOwner(tooltip) then complete = false end
  if not complete then return PendingTooltip(tooltip, discard) end
  ForgetTooltip(tooltip)
  return true
end

local function ResolveTip(source, category)
  local translated = P.Resolve(source, category)
  if translated ~= source or not Enabled(category) then return translated end
  local color, body, reset = source:match("^(|c%x%x%x%x%x%x%x%x)(.-)(|r)$")
  if body then return color .. P.Resolve(body, category) .. reset end
  -- Only pricing-line producers use this resolver. Their suffix is a count or
  -- reagent quality markup; no arbitrary item name is passed to this seam.
  for _, key in ipairs({"VENDOR", "AUCTION", "AUCTION_MEAN", "DISENCHANT", "PROSPECT", "MILL"}) do
    local prefix = native[key]
    if prefix and source:sub(1, #prefix) == prefix then
      local suffix = source:sub(#prefix + 1)
      if suffix == "" or suffix:match("^%s*%(") or suffix:match("^%s*|A") then
        return (czech[key] or prefix) .. suffix
      end
    end
  end
  return source
end
TooltipRegions = function(tooltip, category, before, pricing)
  if not Safe(tooltip) or Combat() then if category then blocked[category] = "combat" end; return end
  tooltipEpoch[tooltip] = tooltipEpoch[tooltip] or 1
  for _, region in ipairs({tooltip:GetRegions()}) do
    if Safe(region) and region.IsObjectType and region:IsObjectType("FontString") and region.GetText then
      local readable, current = ReadText(region, category)
      if readable and (not before or before[region] ~= current) then
        leases[region] = {tooltip = tooltip, epoch = tooltipEpoch[tooltip], category = category, owner = tooltip.GetOwner and tooltip:GetOwner()}
        if pricing then resolvers[region] = ResolveTip end
        WatchText(region, tooltip, category)
        if ns.Fonts then ns.Fonts.ApplyRegion(region, tooltip, category) end
      end
    end
  end
end

WatchTooltip = function(tooltip)
  if not Safe(tooltip) or tooltipHooks[tooltip] then return end
  tooltipHooks[tooltip] = true
  if tooltip.SetOwner then hooksecurefunc(tooltip, "SetOwner", function() ReleaseTooltip(tooltip, false, true) end) end
  if tooltip.ClearLines then hooksecurefunc(tooltip, "ClearLines", function() ReleaseTooltip(tooltip, true) end) end
  if tooltip.HookScript then tooltip:HookScript("OnHide", function() ReleaseTooltip(tooltip) end) end
  if tooltip.Show then hooksecurefunc(tooltip, "Show", function()
    local pending = pendingTooltips[tooltip]
    if pending and not ReleaseTooltip(tooltip, pending.discard) then return end
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    local category = P.Category(owner)
    if category and (owner.tooltipText or owner.tooltipTitleText or owner.TooltipText) then
      TooltipRegions(tooltip, category)
    end
  end) end
end

local function ResolveMenuSource(source, category)
  local color, body, reset = source:match("^(|c%x%x%x%x%x%x%x%x)(.-)(|r)$")
  if body then return color .. P.Resolve(body, category) .. reset end
  return P.Resolve(source, category)
end

local function RetireMenuRow(frame, context, description)
  local proof = rootProof[frame]
  if not proof or proof.menuContext ~= context or proof.description ~= description then return true end
  if not Safe(frame) then pendingMenus[context] = true; context.reason = "protected-menu"; return false end
  -- Native description resetters run before the pool hands this row over. The
  -- generation is retired only inside this callback; newer descriptions win.
  proof.retiring = true
  for region, state in pairs(texts) do
    if state.owner == frame then RestoreText(region, state); texts[region], resolvers[region] = nil, nil end
  end
  if ns.Fonts then ns.Fonts.RestoreOwner(frame) end
  roots[frame], rootProof[frame] = nil, nil
  if context.rows then context.rows[frame] = nil end
  return true
end

local function ReleaseMenu(context)
  if not context or not context.rows then return true end
  local complete = true
  for frame, description in pairs(context.rows) do
    if not RetireMenuRow(frame, context, description) then complete = false end
  end
  if complete then pendingMenus[context] = nil end
  return complete
end

local function MenuDescription(description, context, source, resolver)
  if not description or not description.AddInitializer or not description.AddResetter then
    context.reason = "menu-lifecycle-unavailable"; return
  end
  resolver = resolver or ResolveMenuSource
  description:AddInitializer(function(frame, currentDescription, menu)
    context.menu = menu
    if not menu or not menu.GetOwnerRegion or not menu.IsShown or not menu.Close
      or menu:GetOwnerRegion() ~= context.owner then context.reason = "menu-owner-unavailable"; return end
    openMenus[menu] = context
    roots[frame] = context.category
    context.rows = context.rows or setmetatable({}, {__mode = "k"})
    context.rows[frame] = description
    rootProof[frame] = {menuContext = context, description = description, parent = frame.GetParent and frame:GetParent()}
    local displayed = resolver(source, context.category)
    -- The initializer knows exactly which source produced this label. It does
    -- not infer a source from Czech or touch description data/callbacks.
    local regions = frame.GetRegions and {frame:GetRegions()} or {}
    if frame.GetFontString then regions[#regions + 1] = frame:GetFontString() end
    for _, region in ipairs(regions) do
      local readable, current = false, nil
      if region and region.GetText and region.SetText then readable, current = ReadText(region, context.category) end
      if readable and (current == displayed or current == source) then
        resolvers[region] = resolver
        texts[region] = {source = source, applied = current, owner = frame, category = context.category,
          parent = region.GetParent and region:GetParent()}
      end
    end
    Queue()
  end)
  description:AddResetter(function(frame) RetireMenuRow(frame, context, description) end)
end

local function CloseOwnedMenus(category)
  for menu, context in pairs(openMenus) do
    if not category or context.category == category then
      if not menu.GetOwnerRegion or not menu.IsShown or not menu.Close then
        blocked[context.category] = "menu-owner-unavailable"
      elseif menu:GetOwnerRegion() ~= context.owner or not menu:IsShown() then
        openMenus[menu] = nil
      elseif context.reason then blocked[context.category] = context.reason
      elseif context.enabled ~= Enabled(context.category) then
        if Safe(context.owner) and ReleaseMenu(context) then menu:Close()
        else blocked[context.category] = "protected-menu" end
      end
    end
  end
  for context in pairs(pendingMenus) do
    if not category or context.category == category then blocked[context.category] = "protected-menu" end
  end
end

local function InstallBagMenu()
  if not AuctionatorBagUseMixin or not AuctionatorBagUseMixin.BagItemClicked then return end
  local original = AuctionatorBagUseMixin.BagItemClicked
  AuctionatorBagUseMixin.BagItemClicked = function(self, button, mouseButton, ...)
    if mouseButton ~= "RightButton" or not P.Category(self) then return original(self, button, mouseButton, ...) end
    -- Source-bound right-click presentation from 340/341 BagUse.lua. The
    -- original left-click auction/event path is called with its exact tuple.
    local defaultName = Auctionator.Groups.GetGroupNameByIndex(1)
    local isInDefaultGroup = self.View.itemMap[defaultName][button.itemInfo.sortKey] ~= nil
    local defaultPrintName = _G["AUCTIONATOR_L_" .. defaultName] or defaultName
    local context = {owner = self, category = "ui", enabled = Enabled("ui")}
    local menu = MenuUtil.CreateContextMenu(self, function(_, root)
      local function Add(kind, source, callback, resolver)
        local description = root[kind](root, (resolver or ResolveMenuSource)(source, "ui"), callback)
        MenuDescription(description, context, source, resolver)
      end
      local function GroupLabel(key)
        local source = string.format(native[key], defaultPrintName)
        local function ResolveGroup(value, category)
          if not Enabled(category) then return value end
          local label = _G["AUCTIONATOR_L_" .. defaultName] and P.Resolve(defaultPrintName, category) or defaultPrintName
          return string.format(czech[key] or native[key], label)
        end
        return source, ResolveGroup
      end
      if isInDefaultGroup then
        local source, resolver = GroupLabel("REMOVE_FROM_X")
        Add("CreateButton", source, function() self:RemoveFromDefaultGroup(button) end, resolver)
      else
        local source, resolver = GroupLabel("ADD_TO_X")
        Add("CreateButton", source, function() self:AddToDefaultGroup(button) end, resolver)
      end
      if not button.itemInfo.isCustom then
        if not self.View.hiddenItems[button.itemInfo.sortKey] then
          Add("CreateButton", native.HIDE, function() self:HideItem(button) end)
        else Add("CreateButton", native.UNHIDE, function() self:UnhideItem(button) end) end
        if next(self.View.hiddenItems) == nil then
          Add("CreateTitle", GRAY_FONT_COLOR:WrapTextInColorCode(native.UNHIDE_ALL))
        else Add("CreateButton", native.UNHIDE_ALL, function() self:UnhideAll() end) end
      end
    end)
    if menu then
      context.menu = menu; openMenus[menu] = context
      -- CreateContextMenu installs no caller close callback. This callback is
      -- confined to the newly returned menu; dropdown callbacks stay native.
      if menu.SetClosedCallback and menu.GetOwnerRegion and menu:GetOwnerRegion() == self then menu:SetClosedCallback(function(closed)
        ReleaseMenu(context); openMenus[closed or menu] = nil
      end) else context.reason = "menu-close-unavailable" end
    end
    Queue()
  end
end

local originalInitAgain
local rebuilding = false
local function MenuLabels(state)
  local labels = {}
  for index, label in ipairs(state.labels) do
    -- A dropdown with XML textString contains locale keys. Dynamic shopping
    -- lists contain user names; only the explicit empty-list sentinel is ours.
    if state.owner.textString or (index == 1 and state.values[index] == "" and label == native.NONE) then
      labels[index] = P.Resolve(label, state.category)
    else labels[index] = label end
  end
  return labels
end
local function DropdownLive(dropdown)
  if not Safe(dropdown) then return false end
  local menu = dropdown.GetMenu and dropdown:GetMenu() or dropdown.menu
  if menu and menu.GetOwnerRegion and menu:GetOwnerRegion() ~= dropdown then return false end
  if menu and menu.IsShown then return menu:IsShown() end
  return dropdown.IsMenuOpen and dropdown:IsMenuOpen() == true or false
end
local function AttachDropdownMenu(owner)
  local state, dropdown = menus[owner], owner.DropDown
  if not state or not dropdown then return end
  if not dropdown.GetMenuDescription then state.menuReason = "menu-description-unavailable"; return end
  local root = dropdown:GetMenuDescription()
  if not root or not root.EnumerateElementDescriptions then state.menuReason = "menu-description-unavailable"; return end
  state.menuReason = nil
  if state.descriptionRoot == root then return end
  state.descriptionRoot = root
  local context = {owner = dropdown, category = state.category, enabled = Enabled(state.category)}
  state.context = context
  local index = 0
  for _, description in root:EnumerateElementDescriptions() do
    index = index + 1
    local source = state.labels[index]
    if source ~= nil then
      local translate = owner.textString or (index == 1 and state.values[index] == "" and source == native.NONE)
      MenuDescription(description, context, source, translate and ResolveMenuSource or function(value) return value end)
    end
  end
  if index ~= #state.labels then context.reason = "menu-description-mismatch" end
  local menu = dropdown.GetMenu and dropdown:GetMenu() or dropdown.menu
  if menu then
    context.menu = menu; openMenus[menu] = context
    if menu.GetOwnerRegion and menu.IsShown and menu:GetOwnerRegion() == dropdown and menu:IsShown() then
      if menu.ReinitializeAll then menu:ReinitializeAll() else context.reason = "menu-refresh-unavailable" end
    end
  end
end

local function WatchDropdown(owner)
  local dropdown = owner.DropDown
  if not dropdown then return end
  local watch = watched[dropdown] or {}; watched[dropdown] = watch
  if not watch.dropdown and dropdown.OnMenuClosed then hooksecurefunc(dropdown, "OnMenuClosed", function(_, menu)
    ReleaseMenu(openMenus[menu]); openMenus[menu] = nil
    Queue()
  end) end
  if dropdown.GenerateMenu and dropdown.GenerateMenu ~= watch.generate then
    hooksecurefunc(dropdown, "GenerateMenu", function() AttachDropdownMenu(owner) end)
    watch.generate = dropdown.GenerateMenu
  end
  if not watch.dropdown and dropdown.OpenMenu then hooksecurefunc(dropdown, "OpenMenu", function()
    AttachDropdownMenu(owner)
    local state = menus[owner]
    local menu = dropdown.GetMenu and dropdown:GetMenu() or dropdown.menu
    if state and state.context and menu then state.context.menu = menu; openMenus[menu] = state.context end
    Queue()
  end) end
  watch.dropdown = true
end

local function RebuildMenu(owner, state, close)
  if not Safe(owner) or Combat() then blocked[state.category] = "combat"; return end
  if P.Category(owner) ~= state.category then menus[owner] = nil; return end
  local dropdown = owner.DropDown
  if close and dropdown and dropdown.CloseMenu then dropdown:CloseMenu() end
  local value = owner.value
  state.enabled = Enabled(state.category)
  rebuilding = true
  originalInitAgain(owner, MenuLabels(state), state.values)
  rebuilding = false
  WatchDropdown(owner)
  -- InitAgain selects the first option; restore the current unsaved selection.
  owner.value = value
  if dropdown and dropdown.GenerateMenu then dropdown:GenerateMenu() end
end

AdoptDropdown = function(owner, category)
  if not originalInitAgain or not WrappedInitAgain or not owner.DropDown
    or owner.InitAgain ~= originalInitAgain then return end
  owner.InitAgain = WrappedInitAgain
  -- Already-created XML dropdowns still have their original locale keys and
  -- values. Resolve those authoritative keys, never their visible Czech text.
  if type(owner.textString) ~= "string" or type(owner.valuesString) ~= "string" then return end
  local labels, values = {}, {}
  for key in (owner.textString .. ";"):gmatch("(.-);") do labels[#labels + 1] = Auctionator.Locales.Apply(key) end
  for value in (owner.valuesString .. ";"):gmatch("(.-);") do values[#values + 1] = value end
  local state = {owner = owner, category = category, labels = labels, values = values}
  menus[owner] = state
  WatchDropdown(owner)
  RebuildMenu(owner, state, false)
  WatchDropdown(owner)
  AttachDropdownMenu(owner)
end

Refresh = function(frame, onlyCategory)
  blocked = {}
  if Combat() then return "pending-combat", "combat" end
  Discover()
  for tooltip, pending in pairs(pendingTooltips) do
    if ReleaseTooltip(tooltip, pending.discard) and tooltip.IsShown and tooltip:IsShown() then
      local owner = tooltip.GetOwner and tooltip:GetOwner()
      local category = P.Category(owner)
      if category and (owner.tooltipText or owner.tooltipTitleText or owner.TooltipText) then TooltipRegions(tooltip, category) end
    end
  end
  CloseOwnedMenus(onlyCategory)
  local seen = {}
  if frame then
    local category = P.Category(frame)
    if category then Scan(frame, category, seen) end
  else
    for root, category in pairs(roots) do
      if not onlyCategory or category == onlyCategory then
        local valid, reason = RootValid(root)
        if reason then blocked[category] = reason
        elseif valid then Scan(root, category, seen) end
      end
    end
  end
  for region, state in pairs(texts) do
    if not onlyCategory or state.category == onlyCategory then
      local safe, why = Safe(region)
      local category, reason
      if safe then category, reason = TextCategory(region, state.owner) end
      if not safe or reason then blocked[state.category] = reason or why
      elseif category ~= state.category or not SameTextOwner(region, state) then
        texts[region], leases[region], resolvers[region], pendingSources[region] = nil, nil, nil, nil
      elseif pendingSources[region] then blocked[state.category] = "unreadable-source"
      else
        local readable, current = ReadText(region, category)
        if readable then
          Render(region, state.owner, current == state.applied and state.source or current, category)
          if leases[region] and ns.Fonts then ns.Fonts.ApplyRegion(region, state.owner, category) end
        end
      end
    end
  end
  for region, category in pairs(pendingSources) do
    if not onlyCategory or category == onlyCategory then
      if not Safe(region) or P.Category(region) == category then blocked[category] = "unreadable-source"
      else pendingSources[region] = nil end
    end
  end
  for owner, state in pairs(menus) do
    if not onlyCategory or state.category == onlyCategory then
      if state.menuReason and P.Category(owner) == state.category and DropdownLive(owner.DropDown)
        and (Enabled(state.category) or state.enabled ~= Enabled(state.category)) then
        -- The menu really opened, but its pooled rows cannot be inspected or
        -- restored through this client's APIs. Closed/unused dropdowns do not
        -- block a category, and a menu created while already off stays native.
        blocked[state.category] = state.menuReason
      elseif state.enabled ~= Enabled(state.category) then RebuildMenu(owner, state, true) end
    end
  end
  if not onlyCategory or onlyCategory == "settings" then
    for category, state in pairs(categoryNames) do
      local target = P.Resolve(state.source, "settings")
      if target ~= state.applied then
        local current = category.GetName and category:GetName() or category.name
        if current ~= state.applied then categoryNames[category] = nil
        elseif category.SetName then category:SetName(target); state.applied = target
        else blocked.settings = "settings-category-name" end
      end
    end
  end
  if ns.Fonts then
    local _, fontBlocked = ns.Fonts.Refresh(onlyCategory)
    for category in pairs(fontBlocked or {}) do blocked[category] = blocked[category] or "protected-font" end
  end
  local reason = blocked[onlyCategory] or (not onlyCategory and (blocked.ui or blocked.settings))
  if not ProviderActive() then return "unavailable", "locale-owner-changed" end
  if reason then return "pending-refresh", reason end
  return "applied"
end
P.Refresh = Refresh
Queue = function()
  if scheduled then return end
  scheduled = true
  C_Timer.After(0, function()
    scheduled = false
    if not installed then return end
    local ok, status, reason = pcall(Refresh)
    if not ok then
      -- A host getter can become unreadable between the guarded checks. A
      -- failed batch is incomplete; never leave its old applied snapshot.
      if ns.Controls then
        for _, category in ipairs({"ui", "settings"}) do ns.Controls.Pending(category, "error", "renderer-error") end
      end
      return
    end
    if ns.Controls then
      for _, category in ipairs({"ui", "settings"}) do
        local categoryReason = blocked[category]
        if status == "pending-combat" or status == "unavailable" then ns.Controls.Pending(category, status, reason)
        elseif categoryReason then ns.Controls.Pending(category, "pending-refresh", categoryReason)
        else ns.Controls.Applied(category, Enabled(category)) end
      end
    end
  end)
end

local function CallerCategory()
  if dialogContext then return dialogContext end
  local stack = debugstack and debugstack(3, 12, 0) or ""
  if stack:find("[/\\]Config[/\\]") or stack:find("[/\\]Config[/\\]Mixins[/\\]") then return "settings" end
  return "ui"
end

local function Install()
  if installed or not Auctionator or not Auctionator.Locales then return end
  if AUCTIONATOR_LOCALES_OVERRIDE ~= NativeCatalogue then return end
  installed = true
  WatchTooltip(GameTooltip)
  InstallBagMenu()
  if AuctionatorDropDownMixin and AuctionatorDropDownMixin.InitAgain then
    originalInitAgain = AuctionatorDropDownMixin.InitAgain
    WrappedInitAgain = function(owner, labels, values, ...)
      local category = P.Category(owner)
      if not category or rebuilding then return originalInitAgain(owner, labels, values, ...) end
      local sourceLabels, sourceValues = {}, {}
      for index, value in ipairs(labels) do sourceLabels[index] = value end
      for index, value in ipairs(values) do sourceValues[index] = value end
      local state = {owner = owner, category = category, labels = sourceLabels, values = sourceValues, enabled = Enabled(category)}
      menus[owner] = state
      WatchDropdown(owner)
      local result = Pack(originalInitAgain(owner, MenuLabels(state), values, ...))
      WatchDropdown(owner)
      AttachDropdownMenu(owner)
      return unpack(result, 1, result.n)
    end
    AuctionatorDropDownMixin.InitAgain = WrappedInitAgain
  end
  if AuctionatorPanelConfigMixin and AuctionatorPanelConfigMixin.SetupPanel and Settings then
    local originalSetup = AuctionatorPanelConfigMixin.SetupPanel
    -- Source-bound copy of 340/341 PanelConfig.SetupPanel. Registration returns
    -- the only handle for subcategories, so capture it at this owned seam;
    -- shared Blizzard functions and native self.name remain untouched.
    local function SetupPanel(self)
      self.cancel = function() self:Cancel() end
      self.okay = function() if self.shownSettings then self:Save() end end
      self.shownSettings = false
      self.OnCommit = self.okay
      self.OnDefault = function() end
      self.OnRefresh = function() end
      local source = self.name
      local label = P.Resolve(source, "settings")
      local category
      if self.parent == nil then
        category = Settings.RegisterCanvasLayoutCategory(self, label)
        Settings.RegisterAddOnCategory(category)
        Auctionator.State.OptionsCategory = category
      else
        category = Settings.RegisterCanvasLayoutSubcategory(Auctionator.State.OptionsCategory, self, label)
        Settings.RegisterAddOnCategory(category)
      end
      if category then categoryNames[category] = {source = source, applied = label} end
    end
    -- Derived configuration mixins were copied while the host loaded. Replace
    -- only copies of this exact inherited method before panels are created.
    for name, mixin in pairs(_G) do
      if type(name) == "string" and name:match("^Auctionator.*Mixin$") and type(mixin) == "table"
        and mixin.SetupPanel == originalSetup then mixin.SetupPanel = SetupPanel end
    end
  end
  if Auctionator.Config and Auctionator.Config.InternalInitializeFrames then
    hooksecurefunc(Auctionator.Config, "InternalInitializeFrames", function() Refresh() end)
  end
  if Auctionator.Dialogs then
    for _, method in ipairs({"ShowEditBox", "ShowConfirm", "ShowConfirmAlt", "ShowMoney"}) do
      local original = Auctionator.Dialogs[method]
      if original then Auctionator.Dialogs[method] = function(...)
        local category = CallerCategory()
        local known = {}; for root in pairs(roots) do known[root] = true end
        -- A reused dialog receives fresh native text before its next render.
        local result = Pack(original(...))
        Discover()
        for root in pairs(roots) do
          local name = root.GetName and root:GetName()
          if (name and name:match("^AuctionatorDialog")) and (not known[root] or (root.IsShown and root:IsShown())) then roots[root] = category end
        end
        Refresh()
        return unpack(result, 1, result.n)
      end end
    end
  end
  if Auctionator.Tooltip then
    for method, original in pairs(Auctionator.Tooltip) do
      if type(original) == "function" and method:match("^Add.*Tip$") then
        local pet = method == "AddPetTip"
        Auctionator.Tooltip[method] = function(first, ...)
          local tooltip = pet and BattlePetTooltip or first
          if not tooltip or not tooltip.GetRegions then return original(first, ...) end
          WatchTooltip(tooltip)
          local before = {}
          for _, region in ipairs({tooltip:GetRegions()}) do
            if region.GetText then local readable, current = ReadText(region, "ui"); if readable then before[region] = current end end
          end
          local result = Pack(original(first, ...))
          TooltipRegions(tooltip, "ui", before, true)
          return unpack(result, 1, result.n)
        end
      end
    end
  end
  if Auctionator.Utilities and Auctionator.Utilities.Message then
    local original = Auctionator.Utilities.Message
    Auctionator.Utilities.Message = function(message, ...) return original(P.Resolve(message, "ui"), ...) end
  end
  Refresh()
end

function ns.ControlsHost()
  if not Auctionator or not Auctionator.Locales then return false, nil, "host-not-loaded" end
  if AUCTIONATOR_LOCALES_OVERRIDE ~= NativeCatalogue then return false, nil, "locale-owner-changed" end
  local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  return installed and next(native) ~= nil, get and get("Auctionator", "Version") or nil, installed and nil or "renderer-not-ready"
end
function ns.ApplyCategory(category)
  local ready, _, reason = ns.ControlsHost()
  if not ready then return "unavailable", reason end
  return Refresh(nil, category)
end

local function CommandHelp()
  print("Auctionator: /azca ui on|off; /azca settings on|off; /azca status")
end
local function CommandStatus()
  local snapshot = ns.Controls and ns.Controls.GetSnapshot()
  if not snapshot then return end
  local parts = {}
  for _, category in ipairs({"ui", "settings"}) do
    local state = snapshot.categories[category]
    parts[#parts + 1] = category .. "=" .. (state.desired and "on" or "off") .. " [" .. state.status .. "]"
  end
  print("Auctionator: " .. table.concat(parts, ", "))
end
local function Command(input)
  -- A secret/unreadable command is rejected before string inspection.
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, input)
    if not ok or secret ~= false then CommandHelp(); return end
  end
  if type(input) ~= "string" or #input > 128 then CommandHelp(); return end
  local text = input:lower():match("^%s*(.-)%s*$")
  if text == "" or text == "status" then CommandStatus(); CommandHelp(); return end
  if text == "help" then CommandHelp(); return end
  local category, value = text:match("^(%a+)%s+(%a+)$")
  if (category ~= "ui" and category ~= "settings") or (value ~= "on" and value ~= "off") then
    CommandHelp(); return
  end
  local accepted, reason = ns.Controls.SetCategory(category, value == "on")
  if accepted then CommandStatus()
  else print("Auctionator: " .. (type(reason) == "string" and reason or "unavailable")) end
end
SLASH_AAZEROTHAUCTIONATOR1 = "/azca"
SlashCmdList.AAZEROTHAUCTIONATOR = Command

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == "Auctionator" then Install(); Queue()
  elseif event == "ADDON_LOADED" and name == "AAzerothAuctionator" then Queue()
  elseif event == "PLAYER_LOGIN" then Install(); Queue()
  elseif installed then Queue() end
end)
