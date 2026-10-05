"""The native addon list must not leak our font to recycled addon rows."""
import unittest

from lupa.lua51 import LuaRuntime
from test_fonts import FONT_PATH, MOCKS, ROOT


class AddonListTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCKS)
        self.lua.execute('''
          C_AddOns = {
            GetNumAddOns = function() return 2 end,
            GetAddOnInfo = function(index)
              assert(index == 1 or index == 2, "Invalid addon index")
              return index == 1 and "AAzerothAuctionator" or "AnotherAddon"
            end,
          }
          function Entry(index)
            local entry = CreateFrame("Frame", nil, AddonList)
            entry.id = index
            entry.GetID = function(self) return self.id end
            entry.Title = Label(entry, "|Tlogo:20:20|t Azeroth česky: Auctionator")
            return entry
          end
          function MakeList()
            AddonList = CreateFrame("Frame", "AddonList")
            AddonList_InitAddon = function(entry, index)
              entry.id = index
              return 123
            end
            AddonList_Update = function() return 456 end
          end
        ''')
        load = self.lua.eval("function(source) assert(loadstring(source))('AAzerothAuctionator') end")
        load((ROOT / "addon/AAzerothAuctionator/AddonList.lua").read_text())

    def test_only_our_title_changes_and_native_text_color_size_stay_intact(self):
        self.lua.execute('''
          C_AddOns.GetAddOnName = C_AddOns.GetAddOnInfo
          C_AddOns.GetAddOnInfo = nil
          MakeList()
          own = Entry(1); other = Entry(2); own.Title.size = 13
          Event("PLAYER_LOGIN"); Flush()
          assert(AddonList_InitAddon(own, 1) == 123)
          assert(AddonList_Update() == 456); Flush()
        ''')
        self.assertEqual(self.lua.eval("own.Title.path"), FONT_PATH)
        self.assertEqual(self.lua.eval("own.Title.size"), 13)
        self.assertEqual(self.lua.eval("own.Title.color"), "gold")
        self.assertIn("česky", self.lua.eval("own.Title.text"))
        self.assertEqual(self.lua.eval("other.Title.writes"), 0)

    def test_reused_row_restores_original_font_and_preserves_newer_foreign_font(self):
        self.lua.execute('''
          MakeList(); own = Entry(1)
          original = own.Title.path
          Event("PLAYER_LOGIN"); Flush()
          AddonList_InitAddon(own, 2)
          assert(own.Title.path == original)
          AddonList_InitAddon(own, 1)
          own.Title:SetFont("OtherAddon.ttf", 15, "")
          AddonList_InitAddon(own, 2)
        ''')
        self.assertEqual(self.lua.eval("own.Title.path"), "OtherAddon.ttf")
        self.assertEqual(self.lua.eval("own.Title.size"), 15)

    def test_late_list_loading_legacy_refresh_and_invalid_indices(self):
        self.lua.execute('''
          Event("PLAYER_LOGIN"); Flush()
          MakeList(); AddonList_InitAddon = nil
          own = Entry(1); category = Entry(0); invalid = Entry(3)
          Event("ADDON_LOADED", "Blizzard_AddOnList"); Flush()
          assert(own.Title.writes == 1)
          own.id = 2; AddonList_Update(); Flush()
        ''')
        self.assertEqual(self.lua.eval("own.Title.path"), "Fonts\\FRIZQT__.TTF")
        self.assertEqual(self.lua.eval("category.Title.writes"), 0)
        self.assertEqual(self.lua.eval("invalid.Title.writes"), 0)

    def test_combat_and_protected_frames_are_skipped_until_safe(self):
        self.lua.execute('''
          MakeList(); own = Entry(1); protected = Entry(1)
          protected.protected = true
          combat = true; Event("PLAYER_LOGIN"); Flush()
          assert(own.Title.writes == 0)
          combat = false; Event("PLAYER_REGEN_ENABLED"); Flush()
        ''')
        self.assertEqual(self.lua.eval("own.Title.path"), FONT_PATH)
        self.assertEqual(self.lua.eval("protected.Title.writes"), 0)

    def test_scrolling_uses_separate_callback_owner_without_duplicate_hooks(self):
        self.lua.execute('''
          MakeList(); own = Entry(1)
          local callbacks = {}
          AddonList.ScrollBox = {
            RegisterCallback = function(self, event, callback, owner)
              assert(not callbacks[owner]); callbacks[owner] = callback
            end,
          }
          nativeCalls = 0
          AddonList.ScrollBox:RegisterCallback("OnDataRangeChanged", function()
            nativeCalls = nativeCalls + 1
          end, AddonList)
          Event("PLAYER_LOGIN"); Flush()
          Event("ADDON_LOADED", "Blizzard_AddOnList"); Flush()
          own.id = 2
          for _, callback in pairs(callbacks) do callback() end
          Flush()
          assert(#AddonList.scripts.OnShow == 1)
        ''')
        self.assertEqual(self.lua.eval("own.Title.path"), "Fonts\\FRIZQT__.TTF")
        self.assertEqual(self.lua.eval("nativeCalls"), 1)


if __name__ == "__main__":
    unittest.main()
