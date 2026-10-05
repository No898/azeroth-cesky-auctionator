"""Font lifecycle regressions; these mocks do not prove WoW rendering."""
from pathlib import Path
import hashlib
import json
import struct
import unittest
import zipfile

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "addon/AAzerothAuctionator/Fonts/GentiumBook-Regular.ttf"
FONT_PATH = "Interface\\AddOns\\AAzerothAuctionator\\Fonts\\GentiumBook-Regular.ttf"

MOCKS = r'''
timers = {}
combat = false
frames = {}
function InCombatLockdown() return combat end
C_Timer = {After = function(_, callback) table.insert(timers, callback) end}
function Flush()
  local calls = 0
  while #timers > 0 do
    calls = calls + 1
    assert(calls < 30, "Font refresh must settle without polling")
    local batch = timers; timers = {}
    for _, callback in ipairs(batch) do callback() end
  end
end
function hooksecurefunc(object, method, callback)
  local original = object[method]
  object[method] = function(...)
    local result = original(...)
    callback(...)
    return result
  end
end
function NewFont(path, size, flags, color)
  return {
    path = path or "Fonts\\FRIZQT__.TTF", size = size or 12,
    flags = flags or "OUTLINE", color = color or "gold", writes = 0,
    GetFont = function(self) return self.path, self.size, self.flags end,
    SetFont = function(self, path, size, flags)
      self.path, self.size, self.flags = path, size, flags
      self.writes = self.writes + 1
      return true
    end,
    CopyFontObject = function(self, source)
      self.path, self.size, self.flags, self.color = source.path, source.size, source.flags, source.color
    end,
    IsObjectType = function(_, kind) return kind == "FontString" end,
    SetText = function(self, text) self.text = text end,
  }
end
function CreateFont(name)
  local font = NewFont()
  _G[name] = font
  return font
end
function CreateFrame(kind, name, parent)
  local frame = {
    kind = kind, children = {}, regions = {}, scripts = {}, events = {},
    GetChildren = function(self) return unpack(self.children) end,
    GetRegions = function(self) return unpack(self.regions) end,
    IsObjectType = function(self, kind) return self.kind == kind end,
    IsProtected = function(self) return self.protected == true end,
    IsForbidden = function(self) return self.forbidden == true end,
    HookScript = function(self, event, callback)
      self.scripts[event] = self.scripts[event] or {}
      table.insert(self.scripts[event], callback)
    end,
    SetScript = function(self, event, callback) self.scripts[event] = {callback} end,
    RegisterEvent = function(self, event) self.events[event] = true end,
    Fire = function(self, event, ...)
      for _, callback in ipairs(self.scripts[event] or {}) do callback(self, ...) end
    end,
  }
  if name then _G[name] = frame end
  if parent then table.insert(parent.children, frame) end
  table.insert(frames, frame)
  return frame
end
function Event(event, name)
  for _, frame in ipairs(frames) do
    if frame.events[event] then frame:Fire("OnEvent", event, name) end
  end
end
function Label(frame, text)
  local region = NewFont()
  region.text = text
  table.insert(frame.regions, region)
  return region
end
function Button(name, parent)
  local button = CreateFrame("Button", name, parent)
  for _, state in ipairs({"Normal", "Highlight", "Disabled"}) do
    button[state] = NewFont(nil, 12, "", state)
    button["Get" .. state .. "FontObject"] = function(self) return self[state] end
    button["Set" .. state .. "FontObject"] = function(self, font) self[state] = font end
  end
  return button
end
ScrollBoxListMixin = {Event = {OnDataRangeChanged = "OnDataRangeChanged"}}
Auctionator = {Config = {InternalInitializeFrames = function() end}, Dialogs = {
  ShowConfirm = function()
    local frame = CreateFrame("Frame", "AuctionatorDialog1")
    dialogText = Label(frame, "Opravdu zrušit?")
    return "unchanged"
  end,
}}
AUCTIONATOR_LOCALES_OVERRIDE = function() return {} end
'''


class FontRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCKS)
        self.lua.execute((ROOT / "addon/AAzerothAuctionator/Fonts.lua").read_text())

    def run_lua(self, text):
        self.lua.execute(text)

    def assert_font(self, expression):
        self.assertEqual(self.lua.eval(expression + ".path"), FONT_PATH)

    def test_owned_frames_only_preserve_style_and_skip_protected_and_scan_tooltips(self):
        self.run_lua('''
          native = CreateFrame("Frame", "AuctionFrame")
          nativeText = Label(native, "Auctions")
          root = CreateFrame("Frame", "AuctionatorShoppingFrame", native)
          title = Label(root, "Rozšířené hledání")
          title.size, title.flags = 14, ""
          child = CreateFrame("Frame", nil, root)
          childText = Label(child, "Úroveň předmětu")
          protected = CreateFrame("Frame", "AuctionatorProtected", root)
          protected.protected = true; protectedText = Label(protected, "Protected")
          forbidden = CreateFrame("Frame", "AuctionatorForbidden", root)
          forbidden.forbidden = true; forbiddenText = Label(forbidden, "Forbidden")
          scan = CreateFrame("GameTooltip", "AuctionatorUtilitiesScanTooltipTooltip")
          scanText = Label(scan, "Utility")
          Event("ADDON_LOADED", "Auctionator"); Flush()
        ''')
        self.assert_font("title")
        self.assert_font("childText")
        self.assertEqual(self.lua.eval("title.size"), 14)
        self.assertEqual(self.lua.eval("title.flags"), "")
        self.assertEqual(self.lua.eval("title.color"), "gold")
        for expression in ("nativeText", "protectedText", "forbiddenText", "scanText"):
            self.assertEqual(self.lua.eval(expression + ".writes"), 0)

    def test_button_state_fonts_are_private_and_keep_colors(self):
        self.run_lua('''
          button = Button("AuctionatorTestButton")
          original = button.Normal
          outside = Button("UnrelatedButton"); outside.Normal = original
          Event("ADDON_LOADED", "Auctionator"); Flush()
          Event("PLAYER_LOGIN"); button:Fire("OnShow"); Flush()
        ''')
        for state in ("Normal", "Highlight", "Disabled"):
            self.assert_font("button." + state)
            self.assertEqual(self.lua.eval("button." + state + ".color"), state)
        self.assertEqual(self.lua.eval("original.writes"), 0)
        self.assertEqual(self.lua.eval("outside.Normal == original"), True)
        self.assertEqual(self.lua.eval("#button.scripts.OnShow"), 1)

    def test_untranslated_translator_names_keep_the_native_font(self):
        self.run_lua('''
          root = CreateFrame("Frame", "AuctionatorConfigFrame")
          heading = Label(root, "Překladatelé")
          credit = CreateFrame("Frame", nil, root)
          credit.TranslatorsText = Label(credit, "sugymaylis, LvWind, 枫聖御雷")
          Event("ADDON_LOADED", "Auctionator"); Flush()
        ''')
        self.assert_font("heading")
        self.assertEqual(self.lua.eval("credit.TranslatorsText.writes"), 0)

    def test_direct_scroll_boxes_apply_fonts_to_new_rows_without_reopening(self):
        for name in ("ListsContainer", "RecentsContainer"):
            with self.subTest(name=name):
                self.lua.globals().containerName = name
                self.run_lua('''
                  root = CreateFrame("Frame", "AuctionatorShoppingFrame")
                  container = CreateFrame("Frame", nil, root)
                  root[containerName] = container
                  container.ScrollBox = CreateFrame("Frame", nil, container)
                  container.ScrollBox.RegisterCallback = function(self, event, callback, owner)
                    self.changed = function() callback(owner) end
                  end
                  Event("ADDON_LOADED", "Auctionator")
                  Event("AUCTION_HOUSE_SHOW"); Flush()
                  local row = CreateFrame("Frame", nil, container.ScrollBox)
                  newList = Label(row, "Český seznam")
                  container.ScrollBox.changed(); Flush()
                ''')
                self.assert_font("newList")

    def test_late_auction_windows_wrappers_and_pooled_rows(self):
        self.run_lua('''
          Event("ADDON_LOADED", "Auctionator"); Flush()
          tab = Button("AuctionatorTabs_Shopping")
          tab.wrapperFrame = CreateFrame("Frame")
          wrapperTitle = Label(tab.wrapperFrame, "Nákup")
          listing = CreateFrame("Frame", "AuctionatorResultsListing")
          scroll = CreateFrame("Frame", nil, listing)
          scroll.callbacks = {}
          scroll.RegisterCallback = function(self, event, callback, owner)
            assert(not self.callbacks[owner], "Do not replace Auctionator's callback owner")
            self.callbacks[owner] = function() callback(owner) end
          end
          nativeScrollCalls = 0
          scroll:RegisterCallback("OnDataRangeChanged", function()
            nativeScrollCalls = nativeScrollCalls + 1
          end, listing)
          listing.ScrollArea = {ScrollBox = scroll}
          listing.UpdateTable = function(self)
            local row = CreateFrame("Frame", nil, scroll)
            lateDate = Label(row, "neděle, říjen 4")
            return 451
          end
          Event("AUCTION_HOUSE_SHOW"); Flush()
          assert(listing:UpdateTable() == 451); Flush()
          newRow = CreateFrame("Frame", nil, scroll)
          scrolledDate = Label(newRow, "čtvrtek, říjen 1")
          for _, callback in pairs(scroll.callbacks) do callback() end
          Flush()
          assert(nativeScrollCalls == 1)
        ''')
        for expression in ("wrapperTitle", "lateDate", "scrolledDate"):
            self.assert_font(expression)

    def test_combat_defers_work_and_refreshes_do_not_accumulate_size_or_timers(self):
        self.run_lua('''
          root = CreateFrame("Frame", "AuctionatorShoppingFrame")
          label = Label(root, "Příhoz")
          combat = true
          Event("ADDON_LOADED", "Auctionator"); Flush()
          assert(label.writes == 0)
          combat = false; Event("PLAYER_REGEN_ENABLED"); Flush()
          for i = 1, 10 do root:Fire("OnShow") end
          assert(#timers == 1); Flush()
        ''')
        self.assert_font("label")
        self.assertEqual(self.lua.eval("label.size"), 12)
        self.assertEqual(self.lua.eval("label.writes"), 1)

    def test_lazy_dialog_factory_and_new_child_on_show(self):
        self.run_lua('''
          Event("ADDON_LOADED", "Auctionator"); Flush()
          assert(Auctionator.Dialogs.ShowConfirm() == "unchanged"); Flush()
          child = CreateFrame("Frame", nil, AuctionatorDialog1)
          childText = Label(child, "Úroveň")
          AuctionatorDialog1:Fire("OnShow"); Flush()
        ''')
        self.assert_font("dialogText")
        self.assert_font("childText")

    def test_no_auctionator_and_replaced_translation_are_inert(self):
        self.run_lua('''
          Auctionator = nil
          frame = CreateFrame("Frame", "AuctionatorFutureFrame")
          label = Label(frame, "Test")
          Event("PLAYER_LOGIN"); Flush()
          assert(label.writes == 0)
          Auctionator = {}
          AUCTIONATOR_LOCALES_OVERRIDE = function() return {} end
          Event("ADDON_LOADED", "Auctionator"); Flush()
        ''')
        self.assertEqual(self.lua.eval("label.writes"), 0)


class TooltipFontTests(unittest.TestCase):
    run_lua = FontRuntimeTests.run_lua
    assert_font = FontRuntimeTests.assert_font

    def setUp(self):
        FontRuntimeTests.setUp(self)
        self.run_lua('''
          GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
          GameTooltip.Title = Label(GameTooltip, "")
          GameTooltip.shows = 0
          function GameTooltip:GetOwner() return self.owner end
          function GameTooltip:SetOwner(owner) self.owner = owner end
          function GameTooltip:SetText(text) self.Title:SetText(text) end
          function GameTooltip:AddLine(text)
            self.Body = self.Body or Label(self, "")
            self.Body:SetText(text)
          end
          function GameTooltip:Show()
            self.shows = self.shows + 1
            assert(self.shows < 30, "Tooltip reflow must not recurse")
          end
          function GameTooltip:Hide() self:Fire("OnHide") end
          owner = CreateFrame("Frame", "AuctionatorConfigControl")
          owner.tooltipTitleText = "Automatické hledání"
          owner.tooltipText = "Po výběru seznamu vyhledej jeho položky."
          Event("ADDON_LOADED", "Auctionator"); Flush()
        ''')
        upstream = json.loads((ROOT / "locales/upstream.json").read_text())
        path = ROOT / ".cache" / f"Auctionator-{upstream['version']}.zip"
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), upstream["archive_sha256"])
        with zipfile.ZipFile(path) as archive:
            self.lua.execute(archive.read("Auctionator/Source/Components/Mixins/Tooltip.lua").decode())

    def test_real_config_tooltip_uses_czech_font_and_reflows_only_after_changes(self):
        self.run_lua("AuctionatorConfigTooltipMixin.OnEnter(owner)")
        self.assert_font("GameTooltip.Title")
        self.assert_font("GameTooltip.Body")
        self.assertEqual(self.lua.eval("GameTooltip.shows"), 2)
        self.run_lua('''
          GameTooltip:Show()
          assert(GameTooltip.shows == 3)
          extra = Label(GameTooltip, "Další řádek")
          GameTooltip:Show()
        ''')
        self.assert_font("extra")
        self.assertEqual(self.lua.eval("GameTooltip.shows"), 5)

    def test_hide_and_owner_change_restore_fonts_even_during_combat(self):
        self.run_lua('''
          AuctionatorConfigTooltipMixin.OnEnter(owner)
          foreign = CreateFrame("Frame", "AnotherAddon")
          GameTooltip:SetOwner(foreign)
          assert(GameTooltip.Title.path == "Fonts\\\\FRIZQT__.TTF")
          GameTooltip:Show()
          assert(GameTooltip.Title.path == "Fonts\\\\FRIZQT__.TTF")
          AuctionatorConfigTooltipMixin.OnEnter(owner)
          combat = true
          AuctionatorConfigTooltipMixin.OnLeave(owner)
          assert(GameTooltip.Body.path == "Fonts\\\\FRIZQT__.TTF")
          AuctionatorConfigTooltipMixin.OnEnter(owner)
        ''')
        self.assertEqual(self.lua.eval("GameTooltip.Title.path"), "Fonts\\FRIZQT__.TTF")

    def test_restoration_preserves_another_addons_newer_font(self):
        self.run_lua('''
          AuctionatorConfigTooltipMixin.OnEnter(owner)
          GameTooltip.Title:SetFont("OtherAddon.ttf", 15, "")
          GameTooltip:Hide()
          assert(GameTooltip.Title.path == "OtherAddon.ttf")
          AuctionatorConfigTooltipMixin.OnEnter(owner)
          GameTooltip:Hide()
          assert(GameTooltip.Title.path == "OtherAddon.ttf")
          GameTooltip:Show()
          GameTooltip.Title:SetFont("NewerFont.ttf", 16, "OUTLINE")
          GameTooltip:Show()
          GameTooltip:Hide()
        ''')
        self.assertEqual(self.lua.eval("GameTooltip.Title.path"), "NewerFont.ttf")
        self.assertEqual(self.lua.eval("GameTooltip.Title.size"), 16)

    def test_item_foreign_and_protected_tooltips_keep_original_fonts(self):
        self.run_lua('''
          item = CreateFrame("Frame", "AuctionatorItemRow")
          foreign = CreateFrame("Frame", "AnotherAddon")
          foreign.tooltipText = "Cizí nápověda"
          Event("AUCTION_HOUSE_SHOW"); Flush()
          GameTooltip:SetOwner(item); GameTooltip:Show()
          GameTooltip:SetOwner(foreign); GameTooltip:Show()
          owner.protected = true
          GameTooltip:SetOwner(owner); GameTooltip:Show()
          owner.protected = false
          GameTooltip.protected = true; GameTooltip:Show()
        ''')
        self.assertEqual(self.lua.eval("GameTooltip.Title.writes"), 0)


class FontAssetTests(unittest.TestCase):
    def test_bundled_font_contains_czech_glyphs(self):
        # Read the font's Unicode BMP cmap (format 4), not its name/filename.
        data = FONT.read_bytes()
        u16 = lambda offset: struct.unpack_from(">H", data, offset)[0]
        u32 = lambda offset: struct.unpack_from(">I", data, offset)[0]
        tables = {data[pos:pos + 4]: u32(pos + 8)
                  for pos in range(12, 12 + u16(4) * 16, 16)}
        cmap = tables[b"cmap"]
        offsets = [cmap + u32(pos + 4)
                   for pos in range(cmap + 4, cmap + 4 + u16(cmap + 2) * 8, 8)
                   if u16(pos) == 0 or (u16(pos) == 3 and u16(pos + 2) == 1)]
        table = next(offset for offset in offsets if u16(offset) == 4)
        count = u16(table + 6) // 2
        ends = table + 14
        starts = ends + count * 2 + 2
        deltas = starts + count * 2
        ranges = deltas + count * 2
        for char in "áčďéěíňóřšťúůýžÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ":
            code = ord(char)
            index = next(i for i in range(count) if u16(starts + i * 2) <= code <= u16(ends + i * 2))
            delta = u16(deltas + index * 2)
            location = ranges + index * 2
            offset = u16(location)
            glyph = u16(location + offset + (code - u16(starts + index * 2)) * 2) if offset else code
            glyph = (glyph + delta) % 65536 if glyph else 0
            self.assertNotEqual(glyph, 0, char)
        self.assertIn("SIL OPEN FONT LICENSE Version 1.1", (FONT.parent / "OFL.txt").read_text())


if __name__ == "__main__":
    unittest.main()
