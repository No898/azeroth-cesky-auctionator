"""Profession-window panel: font and Azeroth česky flag. Mocks, not WoW proof."""
import unittest

from lupa.lua51 import LuaRuntime

from test_fonts import FONT_PATH, MOCKS, ROOT

PANEL = r'''
AUCTIONATOR_L_TO_CRAFT_COLON = "K výrobě:"
AUCTIONATOR_L_PROFIT_COLON = "Zisk:"
AUCTIONATOR_L_SEARCH = "Hledat"
AUCTIONATOR_LOCALES = {enUS = function()
  return {TO_CRAFT_COLON = "To Craft:", PROFIT_COLON = "Profit:", SEARCH = "Search",
    PROFIT_WARNING_AGE = "(old)", PROFIT_WARNING_MISSING = "(missing)",
    PROFIT_WARNING_NOT_EXACT_ITEM = "(not exact)"}
end}
TradeSkillFrame = CreateFrame("Frame", "TradeSkillFrame")
Auctionator.CraftingInfo = {
  GetInfoText = function() return AUCTIONATOR_L_TO_CRAFT_COLON .. " 85\n" .. AUCTIONATOR_L_PROFIT_COLON .. " 0" end,
  Initialize = function()
    local frame = CreateFrame("Frame", "AuctionatorCraftingInfo", TradeSkillFrame)
    frame.Total = Label(frame, "")
    frame.SearchButton = Button(nil, frame)
    frame.SearchButton.SetText = function(self, text) self.text = text end
    frame.SearchButton.text = AUCTIONATOR_L_SEARCH
    frame.shown = true
    frame.IsVisible = function(self) return self.shown end
    frame.UpdateTotal = function(self)
      self.Total:SetText(Auctionator.CraftingInfo.GetInfoText())
      self.updates = (self.updates or 0) + 1
    end
    frame:UpdateTotal()
  end,
}
'''

CORE = r'''
original = false
listeners = {}
AzerothCeskyAPI = {GetInterface = function(version)
  if version ~= 1 then return nil end
  return {
    IsWindowOriginal = function(frame)
      if frame == "boom" then error("unreadable") end
      local seen = frame
      while seen do
        if seen == TradeSkillFrame then return original end
        seen = seen.parent
      end
      return false
    end,
    Subscribe = function(callback) table.insert(listeners, callback); return function() end end,
  }
end}
function Notify(reason)
  for _, callback in ipairs(listeners) do callback({reasons = {[reason] = true}}) end
end
'''


class CraftingInfoTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCKS)
        # Parent links let the fake core walk to the native window.
        self.lua.execute('''
          local create = CreateFrame
          CreateFrame = function(kind, name, parent)
            local frame = create(kind, name, parent); frame.parent = parent; return frame
          end
        ''')
        self.lua.execute(PANEL)

    def load(self, core=True):
        if core:
            self.lua.execute(CORE)
        self.lua.execute((ROOT / "addon/AAzerothAuctionator/Fonts.lua").read_text())
        self.lua.execute((ROOT / "addon/AAzerothAuctionator/CraftingInfo.lua").read_text())
        self.lua.execute('Event("ADDON_LOADED", "Auctionator"); Flush()')

    def text(self):
        return self.lua.eval("AuctionatorCraftingInfo.Total.text")

    def test_panel_created_with_the_profession_window_gets_the_czech_font(self):
        self.load()
        self.lua.execute('Auctionator.CraftingInfo.Initialize(); Flush()')
        self.assertEqual(self.lua.eval("AuctionatorCraftingInfo.Total.path"), FONT_PATH)
        self.assertEqual(self.lua.eval("TradeSkillFrame.regions[1]"), None)

    def test_flag_on_keeps_czech_and_grey_flag_redraws_in_english(self):
        self.load()
        self.lua.execute('Auctionator.CraftingInfo.Initialize(); Flush()')
        self.assertEqual(self.text(), "K výrobě: 85\nZisk: 0")
        self.lua.execute('original = true; Notify("windows")')
        self.assertEqual(self.text(), "To Craft: 85\nProfit: 0")
        self.assertEqual(self.lua.eval("AuctionatorCraftingInfo.SearchButton.text"), "Search")
        # Czech globals are restored after the English redraw.
        self.assertEqual(self.lua.eval("AUCTIONATOR_L_TO_CRAFT_COLON"), "K výrobě:")
        self.lua.execute('AuctionatorCraftingInfo:UpdateTotal()')
        self.assertEqual(self.text(), "To Craft: 85\nProfit: 0")
        self.lua.execute('original = false; Notify("windows")')
        self.assertEqual(self.text(), "K výrobě: 85\nZisk: 0")
        self.assertEqual(self.lua.eval("AuctionatorCraftingInfo.SearchButton.text"), "Hledat")

    def test_hidden_panel_is_not_updated_and_unrelated_reasons_are_ignored(self):
        self.load()
        self.lua.execute('Auctionator.CraftingInfo.Initialize(); AuctionatorCraftingInfo.shown = false')
        before = self.lua.eval("AuctionatorCraftingInfo.updates")
        self.lua.execute('original = true; Notify("windows"); Notify("quests")')
        self.assertEqual(self.lua.eval("AuctionatorCraftingInfo.updates"), before)
        self.lua.execute('AuctionatorCraftingInfo.shown = true; Notify("quests")')
        self.assertEqual(self.lua.eval("AuctionatorCraftingInfo.updates"), before)
        self.lua.execute('Notify("preferences")')
        self.assertEqual(self.text(), "To Craft: 85\nProfit: 0")

    def test_without_the_main_addon_or_its_flag_api_the_panel_stays_czech(self):
        self.load(core=False)
        self.lua.execute('Auctionator.CraftingInfo.Initialize(); AuctionatorCraftingInfo:UpdateTotal()')
        self.assertEqual(self.text(), "K výrobě: 85\nZisk: 0")
        self.lua.execute('AzerothCeskyAPI = {GetInterface = function() return {Subscribe = function() end} end}')
        self.lua.execute('AuctionatorCraftingInfo:UpdateTotal()')
        self.assertEqual(self.text(), "K výrobě: 85\nZisk: 0")

    def test_another_translation_override_disables_the_redraw(self):
        self.load()
        self.lua.execute('''
          Auctionator.CraftingInfo.Initialize()
          AUCTIONATOR_LOCALES_OVERRIDE = function() return {} end
          original = true; Notify("windows")
        ''')
        self.assertEqual(self.text(), "K výrobě: 85\nZisk: 0")


if __name__ == "__main__":
    unittest.main()
