"""Independent categories against pinned Auctionator Lua; no live WoW proof."""
import hashlib
import json
from pathlib import Path
import unittest
import zipfile

from lupa.lua51 import LuaRuntime

from test_fonts import FONT_PATH, MOCKS


ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "addon/AAzerothAuctionator"
FIXTURE = (ROOT / "tests/fixtures/controls.lua").read_text()
NATIVE_FONT = "Fonts\\FRIZQT__.TTF"


class CompanionControlsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        metadata = json.loads((ROOT / "locales/upstream.json").read_text())
        path = ROOT / ".cache" / f"Auctionator-{metadata['version']}.zip"
        if not path.exists():
            raise RuntimeError("Fetch the pinned upstream archive before tests")
        if hashlib.sha256(path.read_bytes()).hexdigest() != metadata["archive_sha256"]:
            raise RuntimeError("Upstream archive checksum mismatch")
        with zipfile.ZipFile(path) as archive:
            cls.source = {name: archive.read(name).decode("utf-8-sig")
                          for name in archive.namelist() if name.endswith(".lua") and (
                              name.startswith("Auctionator/Locales/") or name in {
                                  "Auctionator/Source/Locales/Main.lua",
                                  "Auctionator/Source/Components/Mixins/Tooltip.lua",
                                  "Auctionator/Source/Components/Mixins/DropDown.lua",
                                  "Auctionator/Source/Config/Mixins/PanelConfig.lua",
                                  "Auctionator/Source/Config/Mixins/Configuration.lua",
                                  "Auctionator/Source_LegacyAH/Config/Mixins/BasicOptions.lua",
                                  "Auctionator/Source/Tabs/Selling/Mixins/BagUse.lua",
                                  "Auctionator/Source/Components/Mixins/CheckBox.lua",
                                  "Auctionator/Source/Tabs/Shopping/Mixins/ExportFrame.lua",
                              })}
        cls.cs = json.loads((ROOT / "locales/csCZ.json").read_text())

    def runtime(self, prefs=None, core="new", host=True, locale="enUS", observe_globals=False):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute(MOCKS)
        lua.execute(FIXTURE)
        lua.globals().companionVersion = (ROOT / "VERSION").read_text().strip()
        lua.execute('''
          Auctionator = nil
          CompanionNamespace = {}
          AUCTIONATOR_CONFIG = {sentinel = 123, DEFAULT_TAB = 17}
          configIdentity = AUCTIONATOR_CONFIG
          SlashCmdList = {}
          C_AddOns = {GetAddOnMetadata = function(name, field)
            if name == "Auctionator" and field == "Version" then return "340" end
            if name == "AAzerothAuctionator" and field == "Version" then return companionVersion end
          end}
          GetAddOnMetadata = C_AddOns.GetAddOnMetadata
          function IsAddOnLoaded(name) return name == "Auctionator" and Auctionator ~= nil end
          C_AddOns.IsAddOnLoaded = IsAddOnLoaded
        ''')
        lua.globals().GetLocale = lambda: locale
        if prefs is not None:
            lua.globals().AZCA_PREFS = lua.table_from(prefs)
        lua.globals().InstallCore(core)
        namespace = lua.globals().CompanionNamespace
        if observe_globals:
            lua.execute('''
              globalWrites={}
              nativeSlashRegistry=SlashCmdList
              nativeSlashHandler=function() end
              SlashCmdList.NATIVE_SENTINEL=nativeSlashHandler
              local globals=_G
              local environment=setmetatable({}, {__index=globals,
                __newindex=function(_,key,value)
                  globalWrites[key]=(globalWrites[key] or 0)+1
                  globals[key]=value
                end})
              function LoadObserved(source,namespace)
                local chunk=assert(loadstring(source))
                setfenv(chunk,environment)
                chunk("AAzerothAuctionator",namespace)
              end
            ''')
        for name in ("Controls.lua", "Translations.lua", "Presentation.lua", "Fonts.lua"):
            if observe_globals:
                lua.globals().LoadObserved((ADDON / name).read_text(), namespace)
            else:
                lua.execute((ADDON / name).read_text(), "AAzerothAuctionator", namespace)
        lua.execute('Event("ADDON_LOADED", "AAzerothAuctionator"); Flush()')
        if host:
            self.load_host(lua)
        return lua

    def load_host(self, lua):
        lua.execute('''
          Auctionator = {Locales = {}, Config = {
            InternalInitializeFrames = function()
              configFactoryCalls = (configFactoryCalls or 0) + 1
              return "config-result", nil, 451
            end,
            Set = function() error("Translation must never write upstream settings") end,
          }, Dialogs = {}, State = {}, Debug = {Message = function() end}}
        ''')
        lua.execute(self.source["Auctionator/Locales/Main.lua"])
        for name in sorted(self.source):
            if name.startswith("Auctionator/Locales/") and not name.endswith("/Main.lua"):
                lua.execute(self.source[name])
        lua.execute(self.source["Auctionator/Source/Locales/Main.lua"])
        lua.execute(self.source["Auctionator/Source/Components/Mixins/DropDown.lua"])
        lua.execute(self.source["Auctionator/Source/Components/Mixins/Tooltip.lua"])
        lua.execute(self.source["Auctionator/Source/Config/Mixins/PanelConfig.lua"])
        lua.execute(self.source["Auctionator/Source/Config/Mixins/Configuration.lua"])
        lua.execute(self.source["Auctionator/Source_LegacyAH/Config/Mixins/BasicOptions.lua"])
        lua.execute(self.source["Auctionator/Source/Tabs/Selling/Mixins/BagUse.lua"])
        lua.execute(self.source["Auctionator/Source/Components/Mixins/CheckBox.lua"])
        lua.execute(self.source["Auctionator/Source/Tabs/Shopping/Mixins/ExportFrame.lua"])
        lua.execute('MakeOwnedFrames(); Event("ADDON_LOADED", "Auctionator"); Event("PLAYER_LOGIN"); Flush()')

    def set_category(self, lua, category, value):
        result = lua.globals().CompanionNamespace.Controls.SetCategory(category, value)
        accepted = result[0] if isinstance(result, tuple) else result
        self.assertTrue(accepted)
        lua.execute("Flush()")

    def state(self, lua, category):
        return lua.globals().CompanionNamespace.Controls.GetSnapshot().categories[category]

    def assert_category(self, lua, category, desired, status="applied"):
        state = self.state(lua, category)
        self.assertEqual(state.desired, desired)
        self.assertEqual(state.status, status)
        if status == "applied":
            self.assertEqual(state.effective, desired)
        return state

    def text(self, lua, expression):
        return lua.eval(expression + ":GetText()")

    def test_registered_companion_version_matches_toc_and_release_version(self):
        version = (ROOT / "VERSION").read_text().strip()
        toc = (ADDON / "AAzerothAuctionator.toc").read_text()
        toc_version = next(line.removeprefix("## Version: ") for line in toc.splitlines()
                           if line.startswith("## Version: "))
        self.assertEqual(toc_version, version)
        lua = self.runtime(host=False)
        self.assertEqual(lua.globals().coreDescriptor.version, version)

    def test_host_absent_registration_never_assigns_the_shared_slash_registry(self):
        lua = self.runtime(host=False, observe_globals=True)
        lua.execute('''
          assert(Auctionator==nil)
          assert(globalWrites.SlashCmdList==nil,"companion reassigned the shared global registry")
          assert(SlashCmdList==nativeSlashRegistry and SlashCmdList.NATIVE_SENTINEL==nativeSlashHandler)
          assert(type(SlashCmdList.AAZEROTHAUCTIONATOR)=="function")
          assert(SLASH_AAZEROTHAUCTIONATOR1=="/azca")
        ''')

    def test_default_and_explicit_false_preferences_survive_reload(self):
        cases = (
            (None, (True, True)),
            ({"uiEnabled": False}, (False, True)),
            ({"settingsEnabled": False}, (True, False)),
            ({"uiEnabled": False, "settingsEnabled": False}, (False, False)),
        )
        for prefs, expected in cases:
            with self.subTest(prefs=prefs):
                lua = self.runtime(prefs)
                for category, value in zip(("ui", "settings"), expected):
                    self.assertEqual(lua.globals().AZCA_PREFS[category + "Enabled"], value)
                    self.assert_category(lua, category, value)
                saved = dict(lua.globals().AZCA_PREFS.items())
                reloaded = self.runtime(saved)
                self.assertEqual(reloaded.globals().AZCA_PREFS.uiEnabled, expected[0])
                self.assertEqual(reloaded.globals().AZCA_PREFS.settingsEnabled, expected[1])

    def test_all_four_combinations_restore_open_text_and_fonts_independently(self):
        for ui in (False, True):
            for settings in (False, True):
                with self.subTest(ui=ui, settings=settings):
                    lua = self.runtime()
                    self.set_category(lua, "ui", ui)
                    self.set_category(lua, "settings", settings)
                    self.assertEqual(self.text(lua, "shopping.Title"), self.cs["SHOPPING_TAB"] if ui else "Shopping")
                    self.assertEqual(self.text(lua, "settings.Title"), self.cs["CONFIG_BASIC_OPTIONS_CATEGORY"] if settings else "Basic Options")
                    self.assertEqual(lua.eval("shopping.Title.path"), FONT_PATH if ui else NATIVE_FONT)
                    self.assertEqual(lua.eval("settings.Title.path"), FONT_PATH if settings else NATIVE_FONT)
                    self.assertEqual(lua.eval("shopping.Button.Normal.path"), FONT_PATH if ui else NATIVE_FONT)
                    self.assertEqual(lua.eval("settings.Button.Normal.path"), FONT_PATH if settings else NATIVE_FONT)
                    if not ui:
                        self.assertTrue(lua.eval("shopping.Button.Normal == shopping.originalButtonFont"))
                    if not settings:
                        self.assertTrue(lua.eval("settings.Button.Normal == settings.originalButtonFont"))
                    self.assertEqual(self.text(lua, "foreign.Title"), "Shopping")
                    self.assertEqual(lua.eval("foreign.Title.path"), NATIVE_FONT)
                    self.assert_category(lua, "ui", ui)
                    self.assert_category(lua, "settings", settings)
                    self.assertTrue(lua.eval("configIdentity == AUCTIONATOR_CONFIG"))
                    self.assertEqual(lua.eval("AUCTIONATOR_CONFIG.DEFAULT_TAB"), 17)

    def test_settings_off_restores_already_open_dropdown_and_preserves_values_callbacks(self):
        lua = self.runtime()
        lua.execute('''
          originalSelected, originalSetter = dropdown.DropDown.selected, dropdown.DropDown.setter
          assert(dropdown:GetValue() == "17")
        ''')
        self.set_category(lua, "settings", False)
        self.assertEqual(lua.eval("dropdown.DropDown.entries[2][1]"), "Shopping")
        self.assertEqual(self.text(lua, "dropdown.DropDown.visibleMenu.children[2].Label"), "Shopping")
        self.assertEqual(lua.eval("dropdown.DropDown.entries[2][2]"), "17")
        self.assertEqual(lua.eval("dropdown:GetValue()"), "17")
        self.assertTrue(lua.eval('originalSelected("17") and dropdown.DropDown.selected("17")'))
        self.assertEqual(lua.eval("shopping:GetID()"), 1705)
        self.assertEqual(lua.eval("settings:GetID()"), 451)
        lua.execute('originalSetter("23"); assert(dropdown:GetValue() == "23"); dropdown.DropDown.setter("23")')
        self.set_category(lua, "settings", True)
        self.assertEqual(lua.eval("dropdown:GetValue()"), "23")
        self.assertEqual(lua.eval("dropdown.DropDown.entries[2][1]"), self.cs["SHOPPING_TAB"])
        self.assertEqual(lua.eval("dropdown.DropDown:GenerateMenu()"), ("menu-result", None, 83))

    def test_owned_mixins_keep_native_menu_and_settings_global_function_identities(self):
        lua = self.runtime()
        lua.execute('''
          AssertNativeGlobalFunctions()
          registeredRoot = CreateFrame("Frame", "AuctionatorConfigFrame", SettingsPanel)
          Mixin(registeredRoot, AuctionatorConfigFrameMixin)
          registeredRoot:OnLoad()
          registeredSettings = CreateFrame("Frame", "AuctionatorConfigLateBasicOptionsFrame", SettingsPanel)
          Mixin(registeredSettings, AuctionatorConfigBasicOptionsFrameMixin)
          registeredSettings:OnLoad()
          assert(Settings.categoriesByOwner[registeredRoot] == Auctionator.State.OptionsCategory)
          assert(Settings.categoriesByOwner[registeredSettings].parent == Auctionator.State.OptionsCategory)
          AssertNativeGlobalFunctions()
          Event("PLAYER_LOGIN"); Event("AUCTION_HOUSE_SHOW"); Flush()
          AssertNativeGlobalFunctions()
        ''')
        self.assertEqual(lua.eval("Settings.categoriesByOwner[registeredSettings]:GetName()"), self.cs["CONFIG_BASIC_OPTIONS_CATEGORY"])
        for enabled in (False, True, False):
            self.set_category(lua, "settings", enabled)
            self.assertEqual(lua.eval("Settings.categoriesByOwner[registeredSettings]:GetName()"),
                             self.cs["CONFIG_BASIC_OPTIONS_CATEGORY"] if enabled else "Basic Options")
            lua.execute('''
              dropdown.DropDown:GenerateMenu()
              dropdown.DropDown.setter("23")
              assert(dropdown:GetValue() == "23")
              AssertNativeGlobalFunctions()
            ''')
        lua.execute('''
          local foreignRoot = CreateFrame("Frame", "ForeignSettingsPanel")
          local foreignSub = CreateFrame("Frame", "ForeignSettingsChild")
          local category = Settings.RegisterCanvasLayoutCategory(foreignRoot, "Shopping")
          local subcategory = Settings.RegisterCanvasLayoutSubcategory(category, foreignSub, "Selling")
          assert(category:GetName() == "Shopping" and subcategory:GetName() == "Selling")
          AssertNativeGlobalFunctions()
        ''')

    def test_real_bag_context_menu_respects_ui_category_in_all_four_combinations(self):
        for ui in (False, True):
            for settings in (False, True):
                with self.subTest(ui=ui, settings=settings):
                    lua = self.runtime({"uiEnabled": ui, "settingsEnabled": settings})
                    lua.execute('MakeBagUse(); bag:BagItemClicked(bagButton, "RightButton"); Flush(); AssertNativeGlobalFunctions()')
                    expected_group = self.cs["FAVOURITES"] if ui else "Favourites"
                    expected_add = (self.cs["ADD_TO_X"] if ui else "Add to %s").replace("%s", expected_group)
                    self.assertEqual(lua.eval("lastContextMenu.description.children[1]:GetText()"), expected_add)
                    self.assertEqual(lua.eval("lastContextMenu.description.children[2]:GetText()"), self.cs["HIDE"] if ui else "Hide")
                    self.assertEqual(lua.eval("lastContextMenu.description.children[1].frame.Label.path"), FONT_PATH if ui else NATIVE_FONT)
                    self.assertEqual(lua.eval("contextMenuCreates"), 1)
                    self.assert_category(lua, "ui", ui)
                    self.assert_category(lua, "settings", settings)
                    lua.execute('''
                      lastContextMenu.description.children[1].callback()
                      assert(bagAction.method == "AddToDefaultGroup" and bagAction.owner == bag)
                      assert(bagAction.button == bagButton and bagAction.id == 1705)
                      lastContextMenu.description.children[2].callback()
                      assert(bagAction.method == "HideItem" and bagAction.owner == bag and bagAction.button == bagButton)
                      assert(bagButton.key.id == 451 and bagButton.itemInfo.sortKey == "sort-451")
                    ''')

    def test_real_bag_left_click_preserves_original_posting_payload_and_opens_no_menu(self):
        lua = self.runtime()
        lua.execute('MakeBagUse()')
        self.assertIsNone(lua.eval('bag:BagItemClicked(bagButton, "LeftButton")'))
        lua.execute('''
          assert(contextMenuCreates == nil)
          assert(postingInput == bagButton.itemInfo)
          assert(postingEvent.owner == bag and postingEvent.event == Auctionator.Selling.Events.BagItemClicked)
          assert(postingEvent.extra == 0 and postingEvent.info.itemID == 1705)
          assert(postingEvent.info.nextItem == bagButton.nextItem and postingEvent.info.prevItem == bagButton.prevItem)
          assert(postingEvent.info.key == bagButton.key and postingEvent.info.sortKey == bagButton.itemInfo.sortKey)
          AssertNativeGlobalFunctions()
        ''')

    def test_real_bag_remove_unhide_actions_and_custom_group_name_keep_source_identities(self):
        lua = self.runtime()
        lua.execute('''
          bagGroupName = "Shopping"
          MakeBagUse()
          bag.View.itemMap[bagGroupName][bagButton.itemInfo.sortKey] = {itemInfo = bagButton.itemInfo}
          bag.View.hiddenItems[bagButton.itemInfo.sortKey] = bagButton.itemInfo.itemLink
          bag:BagItemClicked(bagButton, "RightButton"); Flush()
        ''')
        self.assertEqual(lua.eval("lastContextMenu.description.children[1]:GetText()"),
                         self.cs["REMOVE_FROM_X"].replace("%s", "Shopping"))
        self.assertEqual(lua.eval("lastContextMenu.description.children[2]:GetText()"), self.cs["UNHIDE"])
        self.assertEqual(lua.eval("lastContextMenu.description.children[3]:GetText()"), self.cs["UNHIDE_ALL"])
        lua.execute('''
          lastContextMenu.description.children[1].callback()
          assert(bagAction.method == "RemoveFromDefaultGroup" and bagAction.owner == bag)
          assert(bagAction.button == bagButton and bagAction.id == 1705)
          lastContextMenu.description.children[2].callback()
          assert(bagAction.method == "UnhideItem" and bagAction.owner == bag and bagAction.button == bagButton)
          lastContextMenu.description.children[3].callback()
          assert(bagAction.method == "UnhideAll" and bagAction.owner == bag and bagAction.button == nil)
          assert(bagGroupName == "Shopping" and bagButton.itemInfo.itemLink == "item:1705")
          AssertNativeGlobalFunctions()
        ''')

    def test_ui_off_closes_owned_context_menu_and_restores_pooled_font_before_cleanup(self):
        lua = self.runtime()
        lua.execute('MakeBagUse(); bag:BagItemClicked(bagButton, "RightButton"); Flush()')
        self.assertEqual(lua.eval("lastContextMenu.description.children[1].frame.Label.path"), FONT_PATH)
        self.set_category(lua, "settings", False)
        self.assertEqual(lua.eval("lastContextMenu.closeCalls"), 0)
        self.set_category(lua, "ui", False)
        self.assertEqual(lua.eval("lastContextMenu.closeCalls"), 1)
        self.assertEqual(lua.eval("lastContextMenu.fontsAtCleanup[1]"), NATIVE_FONT)
        self.assertEqual(lua.eval("lastContextMenu.description.children[1].frame.Label.path"), NATIVE_FONT)
        self.assert_category(lua, "ui", False)
        lua.execute("AssertNativeGlobalFunctions()")

    def test_foreign_context_menu_takeover_keeps_same_text_font_and_receives_no_close(self):
        lua = self.runtime()
        lua.execute('''
          MakeBagUse(); bag:BagItemClicked(bagButton, "RightButton"); Flush()
          menuLabel = lastContextMenu.description.children[1].frame.Label
          lastContextMenu.owner = foreign
          beforeMenuText, beforeMenuFont = menuLabel.textWrites, menuLabel.writes
          beforeMenuContents, beforeMenuFontPath = menuLabel:GetText(), menuLabel.path
        ''')
        self.set_category(lua, "ui", False)
        self.assertEqual(lua.eval("lastContextMenu.closeCalls"), 0)
        self.assertEqual(self.text(lua, "menuLabel"), lua.eval("beforeMenuContents"))
        self.assertEqual(lua.eval("menuLabel.path"), lua.eval("beforeMenuFontPath"))
        self.assertEqual(lua.eval("menuLabel.textWrites"), lua.eval("beforeMenuText"))
        self.assertEqual(lua.eval("menuLabel.writes"), lua.eval("beforeMenuFont"))

    def test_missing_current_context_menu_api_never_claims_restored_ui(self):
        # Context menus close on category transitions. ReinitializeAll is used
        # only by the separate dropdown path, so it is not required here.
        for method in ("GetOwnerRegion", "IsShown", "Close", "SetClosedCallback", "AddResetter"):
            with self.subTest(method=method):
                lua = self.runtime()
                if method == "AddResetter":
                    lua.globals().contextMissingDescriptionMethods = lua.table_from({method: True})
                else:
                    lua.globals().contextMissingMethods = lua.table_from({method: True})
                lua.execute('MakeBagUse(); bag:BagItemClicked(bagButton, "RightButton"); Flush()')
                self.set_category(lua, "ui", False)
                state = self.state(lua, "ui")
                self.assertIn(state.status, ("pending-refresh", "reload-required"))
                self.assertIsNone(state.effective)
                self.assertTrue(state.reason)
                self.assert_category(lua, "settings", True)
                lua.execute("AssertNativeGlobalFunctions()")

    def test_real_settings_checkbox_translates_only_presentation_and_keeps_native_label_data(self):
        lua = self.runtime()
        lua.execute('''
          configCheckbox = MakeConfigCheckbox(settings, AUCTIONATOR_L_CONFIG_CRAFTING_INFO_SHOW)
          configCheckbox:SetChecked(true)
          Event("AUCTION_HOUSE_SHOW"); Flush()
        ''')
        self.assertEqual(lua.eval("configCheckbox.labelText"), lua.eval("AUCTIONATOR_L_CONFIG_CRAFTING_INFO_SHOW"))
        self.assertEqual(self.text(lua, "configCheckbox.CheckBox.Label"), self.cs["CONFIG_CRAFTING_INFO_SHOW"])
        self.assertTrue(lua.eval("configCheckbox:GetChecked()"))
        self.set_category(lua, "settings", False)
        self.assertEqual(lua.eval("configCheckbox.labelText"), lua.eval("AUCTIONATOR_L_CONFIG_CRAFTING_INFO_SHOW"))
        self.assertEqual(self.text(lua, "configCheckbox.CheckBox.Label"), lua.eval("AUCTIONATOR_L_CONFIG_CRAFTING_INFO_SHOW"))
        self.assertTrue(lua.eval("configCheckbox:GetChecked()"))
        self.set_category(lua, "settings", True)
        self.assertEqual(lua.eval("configCheckbox.labelText"), lua.eval("AUCTIONATOR_L_CONFIG_CRAFTING_INFO_SHOW"))
        self.assertEqual(self.text(lua, "configCheckbox.CheckBox.Label"), self.cs["CONFIG_CRAFTING_INFO_SHOW"])

    def test_real_export_checkbox_list_name_collisions_remain_raw_for_export_logic(self):
        for ui in (False, True):
            for settings in (False, True):
                with self.subTest(ui=ui, settings=settings):
                    lua = self.runtime({"uiEnabled": ui, "settingsEnabled": settings})
                    lua.execute('MakeExportLists(); Event("AUCTION_HOUSE_SHOW"); Flush()')
                    self.assertEqual(lua.eval("export.checkBoxPool.active[1].labelText"), "Shopping")
                    self.assertEqual(lua.eval("export.checkBoxPool.active[1]:GetText()"), "Shopping")
                    self.assertEqual(lua.eval("export.checkBoxPool.active[2]:GetText()"), "Selling")
                    lua.execute('export:OnSelectAllClicked(); export:OnExportClicked()')
                    self.assertEqual(lua.eval("exportedNames[1]"), "Shopping")
                    self.assertEqual(lua.eval("exportedNames[2]"), "Selling")
                    self.assertEqual(lua.eval("exportedText"), "export:Shopping\nexport:Selling\n")

    def test_visible_settings_tooltip_restores_text_and_fonts_without_hiding(self):
        lua = self.runtime()
        lua.execute('AuctionatorConfigTooltipMixin.OnEnter(settingsControl); Flush()')
        self.assertEqual(self.text(lua, "GameTooltip.Title"), self.cs["CONFIG_CRAFTING_INFO_SHOW_TOOLTIP_HEADER"])
        self.assertEqual(lua.eval("GameTooltip.Title.path"), FONT_PATH)
        self.set_category(lua, "settings", False)
        self.assertEqual(self.text(lua, "GameTooltip.Title"), lua.eval("AUCTIONATOR_L_CONFIG_CRAFTING_INFO_SHOW_TOOLTIP_HEADER"))
        self.assertEqual(lua.eval("GameTooltip.Title.path"), NATIVE_FONT)
        self.assertTrue(lua.eval("GameTooltip:IsShown()"))
        self.assertTrue(lua.eval("GameTooltip:GetOwner() == settingsControl"))
        self.assert_category(lua, "ui", True)

    def test_already_open_settings_tooltip_retranslates_on_off_on_without_host_redraw(self):
        lua = self.runtime()
        lua.execute('AuctionatorConfigTooltipMixin.OnEnter(settingsControl); Flush()')
        self.set_category(lua, "settings", False)
        self.assertEqual(self.text(lua, "GameTooltip.Title"), lua.eval("AUCTIONATOR_L_CONFIG_CRAFTING_INFO_SHOW_TOOLTIP_HEADER"))
        self.assertEqual(lua.eval("GameTooltip.Title.path"), NATIVE_FONT)
        # The host does not Show, SetText or OnEnter the tooltip again. The
        # accepted category transition must refresh its currently owned text.
        self.set_category(lua, "settings", True)
        self.assertEqual(self.text(lua, "GameTooltip.Title"), self.cs["CONFIG_CRAFTING_INFO_SHOW_TOOLTIP_HEADER"])
        self.assertEqual(self.text(lua, "GameTooltip.Body"), self.cs["CONFIG_CRAFTING_INFO_SHOW_TOOLTIP_TEXT"].replace("\\n", "\n"))
        self.assertEqual(lua.eval("GameTooltip.Title.path"), FONT_PATH)
        self.assertEqual(lua.eval("GameTooltip.Body.path"), FONT_PATH)
        self.assert_category(lua, "settings", True)

    def test_protected_tooltip_hide_keeps_source_lease_until_safe_restore(self):
        lua = self.runtime()
        lua.execute('''
          AuctionatorConfigTooltipMixin.OnEnter(settingsControl); Flush()
          beforeProtectedTextWrites, beforeProtectedFontWrites = GameTooltip.Title.textWrites, GameTooltip.Title.writes
          GameTooltip.protected = true
          GameTooltip:Hide(); Flush()
        ''')
        self.assertEqual(self.text(lua, "GameTooltip.Title"), self.cs["CONFIG_CRAFTING_INFO_SHOW_TOOLTIP_HEADER"])
        self.assertEqual(lua.eval("GameTooltip.Title.textWrites"), lua.eval("beforeProtectedTextWrites"))
        self.assertEqual(lua.eval("GameTooltip.Title.writes"), lua.eval("beforeProtectedFontWrites"))
        lua.execute('GameTooltip.protected = false; GameTooltip:Show(); Flush()')
        # Show reuses the same title/body bytes. No native SetText, ClearLines,
        # SetOwner or OnEnter redraw supplies the English source a second time.
        self.set_category(lua, "settings", False)
        state = self.state(lua, "settings")
        if state.status != "applied":
            self.assertIn(state.status, ("pending-refresh", "pending-combat"))
            self.assertIsNone(state.effective)
            lua.execute('Event("PLAYER_REGEN_ENABLED"); Flush()')
        self.assert_category(lua, "settings", False)
        self.assertEqual(self.text(lua, "GameTooltip.Title"), lua.eval("AUCTIONATOR_L_CONFIG_CRAFTING_INFO_SHOW_TOOLTIP_HEADER"))
        self.assertEqual(self.text(lua, "GameTooltip.Body"), lua.eval("AUCTIONATOR_L_CONFIG_CRAFTING_INFO_SHOW_TOOLTIP_TEXT"))
        self.assertEqual(lua.eval("GameTooltip.Title.path"), NATIVE_FONT)
        self.assertEqual(lua.eval("GameTooltip.Body.path"), NATIVE_FONT)

    def test_combat_pending_is_reported_until_regen_restores_open_frames(self):
        lua = self.runtime()
        lua.execute("combat = true")
        self.set_category(lua, "settings", False)
        self.assert_category(lua, "settings", False, "pending-combat")
        self.assertEqual(self.text(lua, "settings.Title"), self.cs["CONFIG_BASIC_OPTIONS_CATEGORY"])
        self.assertEqual(lua.eval("settings.Title.path"), FONT_PATH)
        lua.execute('combat = false; Event("PLAYER_REGEN_ENABLED"); Flush()')
        self.assert_category(lua, "settings", False)
        self.assertEqual(self.text(lua, "settings.Title"), "Basic Options")
        self.assertEqual(lua.eval("settings.Title.path"), NATIVE_FONT)

    def test_protected_and_forbidden_widgets_prevent_false_applied_state(self):
        for flag in ("protected", "forbidden"):
            with self.subTest(flag=flag):
                lua = self.runtime()
                lua.execute(f"settings.{flag} = true")
                self.set_category(lua, "settings", False)
                self.assertNotEqual(self.state(lua, "settings").status, "applied")
                self.assertEqual(self.text(lua, "settings.Title"), self.cs["CONFIG_BASIC_OPTIONS_CATEGORY"])
                lua.execute(f'settings.{flag} = false; Event("PLAYER_REGEN_ENABLED"); Flush()')
                self.assert_category(lua, "settings", False)
                self.assertEqual(self.text(lua, "settings.Title"), "Basic Options")

    def test_pooled_region_takeover_preserves_newer_text_and_font(self):
        lua = self.runtime()
        lua.execute('''
          taken = settings.Title
          taken:SetText("A different owner's live text")
          taken:SetFont("OtherAddon.ttf", 19, "THICKOUTLINE")
        ''')
        self.set_category(lua, "settings", False)
        self.assertEqual(self.text(lua, "taken"), "A different owner's live text")
        self.assertEqual(lua.eval("taken.path"), "OtherAddon.ttf")
        self.assertEqual(lua.eval("taken.size"), 19)
        self.assertEqual(lua.eval("taken.flags"), "THICKOUTLINE")

    def test_unreadable_owned_text_remains_pending_until_readable_refresh(self):
        lua = self.runtime()
        lua.execute('''
          originalGetText = settings.Title.GetText
          settings.Title.GetText = function() error("unreadable host region") end
        ''')
        self.set_category(lua, "settings", False)
        self.assertNotEqual(self.state(lua, "settings").status, "applied")
        lua.execute('settings.Title.GetText = originalGetText; Event("PLAYER_REGEN_ENABLED"); Flush()')
        self.assert_category(lua, "settings", False)
        self.assertEqual(self.text(lua, "settings.Title"), "Basic Options")

    def test_unreadable_owned_ancestry_does_not_escape_timer_or_drop_restoration_lease(self):
        for method in ("GetParent", "IsForbidden"):
            with self.subTest(method=method):
                lua = self.runtime()
                lua.globals().unreadableMethod = method
                lua.execute('''
                  beforeUnreadableTextWrites = settingsControl.Label.textWrites
                  beforeUnreadableFontWrites = settingsControl.Label.writes
                  originalAncestryRead = settingsControl[unreadableMethod]
                  settingsControl[unreadableMethod] = function() error("unreadable owned ancestry") end
                  Event("AUCTION_HOUSE_SHOW"); settings:Show(); Flush()
                ''')
                state = self.state(lua, "settings")
                self.assertIn(state.status, ("pending-refresh", "error"))
                self.assertIsNone(state.effective)
                self.assertEqual(self.text(lua, "settingsControl.Label"), self.cs["CONFIG_CRAFTING_INFO_SHOW"])
                self.assertEqual(lua.eval("settingsControl.Label.path"), FONT_PATH)
                self.assertEqual(lua.eval("settingsControl.Label.textWrites"), lua.eval("beforeUnreadableTextWrites"))
                self.assertEqual(lua.eval("settingsControl.Label.writes"), lua.eval("beforeUnreadableFontWrites"))
                lua.execute('''
                  settingsControl[unreadableMethod] = originalAncestryRead
                  Event("AUCTION_HOUSE_SHOW"); Flush()
                ''')
                self.set_category(lua, "settings", False)
                self.assert_category(lua, "settings", False)
                self.assertEqual(self.text(lua, "settingsControl.Label"), lua.eval("AUCTIONATOR_L_CONFIG_CRAFTING_INFO_SHOW"))
                self.assertEqual(lua.eval("settingsControl.Label.path"), NATIVE_FONT)

    def test_tooltip_owner_takeover_keeps_foreign_text_and_fonts(self):
        lua = self.runtime()
        lua.execute('''
          AuctionatorConfigTooltipMixin.OnEnter(settingsControl); Flush()
          GameTooltip:SetOwner(foreign)
          GameTooltip:SetText("Foreign owner live title")
          GameTooltip.Title:SetFont("ForeignTooltip.ttf", 18, "")
          GameTooltip:Show()
        ''')
        self.set_category(lua, "settings", False)
        self.assertEqual(self.text(lua, "GameTooltip.Title"), "Foreign owner live title")
        self.assertEqual(lua.eval("GameTooltip.Title.path"), "ForeignTooltip.ttf")
        self.assertTrue(lua.eval("GameTooltip:GetOwner() == foreign"))

    def test_reparented_pooled_widget_is_not_restored_for_a_foreign_owner(self):
        lua = self.runtime()
        lua.execute('''
          pooled = settingsControl
          pooled:SetParent(foreign)
          pooled.Label:SetText("Foreign pool contents")
          pooled.Label:SetFont("ForeignPool.ttf", 16, "")
        ''')
        self.set_category(lua, "settings", False)
        self.assertEqual(self.text(lua, "pooled.Label"), "Foreign pool contents")
        self.assertEqual(lua.eval("pooled.Label.path"), "ForeignPool.ttf")

    def test_foreign_reparented_watched_region_never_uses_the_old_owner_on_settext(self):
        lua = self.runtime()
        lua.execute('''
          foreignHost = CreateFrame("Frame", nil, UIParent)
          taken = settings.Title
          taken:SetParent(foreignHost)
          beforeForeignWrites = taken.textWrites
          taken:SetText("Search")
        ''')
        self.assertEqual(self.text(lua, "taken"), "Search")
        self.assertEqual(lua.eval("taken.textWrites"), lua.eval("beforeForeignWrites + 1"))

    def test_foreign_takeover_keeps_identical_applied_text_and_current_font_without_writes(self):
        for foreign_font in ("ForeignPool.ttf", FONT_PATH):
            with self.subTest(foreign_font=foreign_font):
                lua = self.runtime()
                lua.globals().foreignFontPath = foreign_font
                lua.execute('''
                  foreignHost = CreateFrame("Frame", nil, UIParent)
                  taken = settings.Title
                  taken:SetParent(foreignHost)
                  taken:SetFont(foreignFontPath, taken.size, taken.flags)
                  beforeTakeoverTextWrites, beforeTakeoverFontWrites = taken.textWrites, taken.writes
                ''')
                self.set_category(lua, "settings", False)
                self.assertEqual(self.text(lua, "taken"), self.cs["CONFIG_BASIC_OPTIONS_CATEGORY"])
                self.assertEqual(lua.eval("taken.path"), foreign_font)
                self.assertEqual(lua.eval("taken.textWrites"), lua.eval("beforeTakeoverTextWrites"))
                self.assertEqual(lua.eval("taken.writes"), lua.eval("beforeTakeoverFontWrites"))

    def test_current_source_on_reenable_and_format_arguments_are_preserved(self):
        lua = self.runtime()
        self.set_category(lua, "ui", False)
        lua.execute('''
          shopping.Title:SetText(AUCTIONATOR_L_SELLING_TAB)
          shopping.Status:SetText(Auctionator.Locales.Apply("BUYING_X_FOR_X", "|Hitem:1705|h[Buy]|h", "23g"))
        ''')
        self.set_category(lua, "ui", True)
        self.assertEqual(self.text(lua, "shopping.Title"), self.cs["SELLING_TAB"])
        self.assertEqual(self.text(lua, "shopping.Status"), "Nákup: |Hitem:1705|h[Buy]|h za 23g")
        self.assertEqual(lua.eval('Auctionator.Locales.Apply("BUYING_X_FOR_X", "id-1705", "23g")'), "Buying id-1705 for 23g")
        lua.execute('shopping.Status:SetFormattedText(AUCTIONATOR_L_BUYING_X_FOR_X, "item-451", "31g")')
        self.assertEqual(self.text(lua, "shopping.Status"), "Nákup: item-451 za 31g")

    def test_formatted_text_retains_entire_native_source_through_category_off_on(self):
        for category, target in (("ui", "shopping.Title"), ("settings", "settings.Title")):
            for argument in ("item-451", "Nákup |Hitem:1705|h[Český název]|h"):
                with self.subTest(category=category, argument=argument):
                    lua = self.runtime()
                    lua.globals().formattedTarget = lua.eval(target)
                    lua.globals().rawFormatArgument = argument
                    # The host fixture's SetFormattedText calls native SetText
                    # internally, so both post-hooks observe this single call.
                    lua.execute('formattedTarget:SetFormattedText(AUCTIONATOR_L_REMOVE_FROM_X, rawFormatArgument)')
                    translated = self.cs["REMOVE_FROM_X"].replace("%s", argument)
                    self.assertEqual(self.text(lua, "formattedTarget"), translated)
                    self.set_category(lua, category, False)
                    self.assertEqual(self.text(lua, "formattedTarget"), "Remove from " + argument)
                    self.set_category(lua, category, True)
                    self.assertEqual(self.text(lua, "formattedTarget"), translated)
                    self.assertEqual(lua.globals().rawFormatArgument, argument)

    def test_native_client_language_and_resolver_remain_available_when_category_off(self):
        lua = self.runtime(locale="deDE")
        native = lua.eval("AUCTIONATOR_L_SHOPPING_TAB")
        self.assertNotEqual(native, self.cs["SHOPPING_TAB"])
        self.assertEqual(self.text(lua, "shopping.Title"), self.cs["SHOPPING_TAB"])
        self.set_category(lua, "ui", False)
        self.assertEqual(self.text(lua, "shopping.Title"), native)
        self.assertEqual(lua.eval('Auctionator.Locales.Apply("SHOPPING_TAB")'), native)
        self.assertEqual(lua.eval("GetLocale()"), "deDE")
        self.assert_category(lua, "settings", True)

    def test_core_absence_old_core_and_late_core_keep_standalone_preferences(self):
        for core in ("none", "old"):
            with self.subTest(core=core):
                lua = self.runtime({"uiEnabled": False, "settingsEnabled": True}, core=core)
                self.assertEqual(self.text(lua, "shopping.Title"), "Shopping")
                self.assertEqual(self.text(lua, "settings.Title"), self.cs["CONFIG_BASIC_OPTIONS_CATEGORY"])
                self.assertEqual(lua.eval("v1Calls + v1Events"), 0)
                lua.execute('InstallCore("new"); Event("ADDON_LOADED", "AzerothCesky"); Flush()')
                self.assertEqual(lua.eval("coreRegisters"), 1)
                self.assertFalse(lua.eval("coreSnapshot.categories.ui.desired"))
                self.assertTrue(lua.eval("coreSnapshot.categories.settings.desired"))
                self.assertTrue(lua.eval("coreSnapshot.hostReady"))
                self.assertEqual(lua.eval("v1Calls + v1Events"), 0)

    def test_standalone_slash_command_controls_categories_and_persists_false_without_core(self):
        for core in ("none", "old"):
            with self.subTest(core=core):
                lua = self.runtime(core=core)
                lua.execute('AzcaCommand("ui off"); Flush()')
                self.assert_category(lua, "ui", False)
                self.assert_category(lua, "settings", True)
                self.assertFalse(lua.eval("AZCA_PREFS.uiEnabled"))
                self.assertEqual(self.text(lua, "shopping.Title"), "Shopping")
                self.assertEqual(self.text(lua, "settings.Title"), self.cs["CONFIG_BASIC_OPTIONS_CATEGORY"])
                lua.execute('AzcaCommand("settings off"); AzcaCommand("ui on"); Flush()')
                self.assert_category(lua, "ui", True)
                self.assert_category(lua, "settings", False)
                self.assertFalse(lua.eval("AZCA_PREFS.settingsEnabled"))
                saved = dict(lua.globals().AZCA_PREFS.items())
                reloaded = self.runtime(saved, core=core)
                self.assert_category(reloaded, "ui", True)
                self.assert_category(reloaded, "settings", False)
                self.assertEqual(lua.eval("v1Calls + v1Events"), 0)

    def test_standalone_slash_malformed_input_help_and_status_do_not_mutate_or_render(self):
        lua = self.runtime(core="none")
        lua.execute('''
          beforeCommandRevision = CompanionNamespace.Controls.GetSnapshot().revision
          beforeCommandUIWrites, beforeCommandSettingsWrites = shopping.Title.textWrites, settings.Title.textWrites
          beforeCommandUIFontWrites, beforeCommandSettingsFontWrites = shopping.Title.writes, settings.Title.writes
        ''')
        malformed = ("ui", "ui maybe", "settings off extra", "other off", "ui off now", None, False, 17, lua.table())
        for message in malformed:
            with self.subTest(message=message):
                lua.globals().AzcaCommand(message)
                lua.execute("Flush()")
                self.assertEqual(lua.eval("CompanionNamespace.Controls.GetSnapshot().revision"), lua.eval("beforeCommandRevision"))
                self.assertTrue(lua.eval("AZCA_PREFS.uiEnabled and AZCA_PREFS.settingsEnabled"))
                self.assertEqual(lua.eval("shopping.Title.textWrites"), lua.eval("beforeCommandUIWrites"))
                self.assertEqual(lua.eval("settings.Title.textWrites"), lua.eval("beforeCommandSettingsWrites"))
                self.assertEqual(lua.eval("shopping.Title.writes"), lua.eval("beforeCommandUIFontWrites"))
                self.assertEqual(lua.eval("settings.Title.writes"), lua.eval("beforeCommandSettingsFontWrites"))
        lua.execute('AzcaCommand("help"); AzcaCommand("status"); Flush()')
        self.assertEqual(lua.eval("CompanionNamespace.Controls.GetSnapshot().revision"), lua.eval("beforeCommandRevision"))
        self.assertTrue(lua.eval("#chatMessages > 0"))

    def test_standalone_slash_status_reports_actual_pending_combat_state(self):
        lua = self.runtime(core="old")
        lua.execute('combat = true; AzcaCommand("settings off"); Flush(); chatMessages = {}; AzcaCommand("status")')
        self.assert_category(lua, "settings", False, "pending-combat")
        self.assertFalse(lua.eval("AZCA_PREFS.settingsEnabled"))
        self.assertTrue(lua.eval('table.concat(chatMessages, "\\n"):find("pending-combat", 1, true) ~= nil'))
        lua.execute('combat = false; Event("PLAYER_REGEN_ENABLED"); Flush(); chatMessages = {}; AzcaCommand("status")')
        self.assert_category(lua, "settings", False)
        self.assertTrue(lua.eval('table.concat(chatMessages, "\\n"):find("applied", 1, true) ~= nil'))

    def test_unavailable_host_and_late_host_publish_real_readiness(self):
        lua = self.runtime(host=False)
        snapshot = lua.globals().CompanionNamespace.Controls.GetSnapshot()
        self.assertFalse(snapshot.hostReady)
        self.assertEqual(snapshot.categories.ui.status, "unavailable")
        self.assertEqual(snapshot.categories.settings.status, "unavailable")
        self.assertEqual(lua.eval("coreDescriptor.id"), "AAzerothAuctionator")
        self.assertEqual(lua.eval("coreDescriptor.version"), (ROOT / "VERSION").read_text().strip())
        self.assertTrue(lua.eval("coreDescriptor.categories.ui and coreDescriptor.categories.settings"))
        self.load_host(lua)
        self.assertTrue(lua.eval("coreSnapshot.hostReady"))
        self.assertEqual(lua.eval("coreSnapshot.hostVersion"), "340")
        self.assert_category(lua, "ui", True)
        self.assert_category(lua, "settings", True)

    def test_lost_locale_provider_stops_translation_and_restores_only_owned_values(self):
        lua = self.runtime()
        lua.execute('''
          settingsControl.Label:SetText("A newer addon's settings label")
          settingsControl.Label:SetFont("ForeignCurrent.ttf", 17, "THICKOUTLINE")
          foreignTextWrites, foreignFontWrites = settingsControl.Label.textWrites, settingsControl.Label.writes
          foreignFactory = function() return {SHOPPING_TAB = "Foreign Shopping"} end
          AUCTIONATOR_LOCALES_OVERRIDE = foreignFactory
          beforeLostProviderWrites = shopping.Title.textWrites
          shopping.Title:SetText(AUCTIONATOR_L_SELLING_TAB)
        ''')
        self.assertEqual(self.text(lua, "shopping.Title"), "Selling")
        self.assertEqual(lua.eval("shopping.Title.textWrites"), lua.eval("beforeLostProviderWrites + 1"))
        lua.execute('shopping:Show(); settings:Show(); Flush()')
        self.assertEqual(self.text(lua, "settings.Title"), "Basic Options")
        self.assertEqual(self.text(lua, "shopping.Status"), "Buying Item-1705 for 12g")
        self.assertEqual(lua.eval("shopping.Title.path"), NATIVE_FONT)
        self.assertEqual(lua.eval("settings.Title.path"), NATIVE_FONT)
        self.assertTrue(lua.eval("shopping.Button.Normal == shopping.originalButtonFont"))
        self.assertTrue(lua.eval("settings.Button.Normal == settings.originalButtonFont"))
        self.assertEqual(self.text(lua, "settingsControl.Label"), "A newer addon's settings label")
        self.assertEqual(lua.eval("settingsControl.Label.path"), "ForeignCurrent.ttf")
        self.assertEqual(lua.eval("settingsControl.Label.textWrites"), lua.eval("foreignTextWrites"))
        self.assertEqual(lua.eval("settingsControl.Label.writes"), lua.eval("foreignFontWrites"))
        lua.execute('''
          shopping.Status:SetFormattedText(AUCTIONATOR_L_BUYING_X_FOR_X, "item-451", "31g")
          assert(AUCTIONATOR_LOCALES_OVERRIDE == foreignFactory)
          assert(AZCA_PREFS.uiEnabled and AZCA_PREFS.settingsEnabled)
        ''')
        self.assertEqual(self.text(lua, "shopping.Status"), "Buying item-451 for 31g")
        host = lua.globals().CompanionNamespace.ControlsHost()
        self.assertFalse(host[0])
        self.assertEqual(host[2], "locale-owner-changed")
        for category in ("ui", "settings"):
            state = self.assert_category(lua, category, True, "unavailable")
            self.assertEqual(state.reason, "locale-owner-changed")

    def test_factory_posthooks_keep_all_return_values_and_call_original_once(self):
        lua = self.runtime()
        self.assertEqual(lua.eval("Auctionator.Config.InternalInitializeFrames()"), ("config-result", None, 451))
        self.assertEqual(lua.eval("configFactoryCalls"), 1)


    def test_same_value_is_noop_and_snapshots_are_detached(self):
        lua = self.runtime()
        lua.execute('''
          before = CompanionNamespace.Controls.GetSnapshot()
          beforeRevision, beforePublishes = before.revision, corePublishes
          beforeTextWrites, beforeFontWrites = settings.Title.textWrites, settings.Title.writes
          before.categories.settings.desired = false
        ''')
        self.set_category(lua, "settings", True)
        self.assertEqual(lua.eval("CompanionNamespace.Controls.GetSnapshot().revision"), lua.eval("beforeRevision"))
        self.assertEqual(lua.eval("corePublishes"), lua.eval("beforePublishes"))
        self.assertEqual(lua.eval("settings.Title.textWrites"), lua.eval("beforeTextWrites"))
        self.assertEqual(lua.eval("settings.Title.writes"), lua.eval("beforeFontWrites"))
        self.assertTrue(lua.eval("AZCA_PREFS.settingsEnabled"))
        self.assertEqual(lua.eval("v1Calls + v1Events"), 0)

    def test_malformed_setters_refuse_without_mutation(self):
        lua = self.runtime()
        before = lua.globals().CompanionNamespace.Controls.GetSnapshot().revision
        for category, value in (("other", False), ("ui", "false"), ("settings", None), (None, True)):
            with self.subTest(category=category, value=value):
                result = lua.globals().CompanionNamespace.Controls.SetCategory(category, value)
                self.assertFalse(result[0] if isinstance(result, tuple) else result)
                self.assertTrue(lua.eval("AZCA_PREFS.uiEnabled and AZCA_PREFS.settingsEnabled"))
                self.assertEqual(lua.globals().CompanionNamespace.Controls.GetSnapshot().revision, before)


if __name__ == "__main__":
    unittest.main()
