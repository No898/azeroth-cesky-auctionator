"""Contract tests against the actual pinned Auctionator release, under Lua 5.1."""
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from lupa.lua51 import LuaRuntime

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import catalog

ROOT = catalog.ROOT


class CatalogueTests(unittest.TestCase):
    def test_catalogue_and_generated_files(self):
        catalog.check()

    def test_guards_reject_missing_empty_unknown_and_broken_format(self):
        original = catalog.translations()
        variants = []
        for value in ("", False, "Nákup za %d", "Nákup bez ceny", "Cena %s %s %s"):
            altered = original.copy()
            altered["BUYING_X_FOR_X"] = value
            variants.append(altered)
        altered = original.copy()
        del altered["BUY"]
        variants.append(altered)
        altered = original.copy()
        altered["NOT_AN_UPSTREAM_KEY"] = "Neznámé"
        variants.append(altered)
        for altered in variants:
            with self.subTest(altered=altered.get("BUYING_X_FOR_X")):
                self.assertTrue(catalog.validate(altered, catalog.metadata()))

    def test_guards_reject_broken_markup_newlines_and_percent(self):
        for key, value in {
            "TOTAL_ITEMS_COLORED": "Celkem %s",
            "LIST_SEARCH_STATUS": "Hledám %s/%s v %s",
            "EXTENDED_SEARCH_ACTIVE_TEXT": "rozšířené hledání",
            "TOO_BIG_PERCENTAGE": "% musí být <= 100 (zadáno %s)",
        }.items():
            altered = catalog.translations()
            altered[key] = value
            self.assertTrue(catalog.validate(altered, catalog.metadata()), key)

    def test_parser_uses_lua_last_assignment_and_rejects_code(self):
        self.assertEqual(catalog.parse_source('L["PRICE"] = "Price"\nL["PRICE"] = "Buyout"'), {"PRICE": "Buyout"})
        with self.assertRaises(ValueError):
            catalog.parse_source('L["X"] = os.execute("anything")')
        with self.assertRaises(ValueError):
            catalog.parse_source('L["X"] = "prefix" .. "suffix"')

    def test_duplicate_json_is_rejected(self):
        with self.assertRaises(ValueError):
            json.loads('{"BUY":"Koupit","BUY":"Jiné"}', object_pairs_hook=catalog.unique_object)

    def test_compare_detects_added_changed_and_removed_without_mutating_snapshot(self):
        snapshot = (ROOT / "locales/upstream.json").read_bytes()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "future.zip"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr(catalog.SOURCE, 'L["BUY"] = "Purchase"\nL["FUTURE_KEY"] = "New %s"')
            with patch("sys.stdout", new_callable=io.StringIO) as output:
                self.assertTrue(catalog.compare(path))
            result = json.loads(output.getvalue())
            self.assertEqual(result["added"], ["FUTURE_KEY"])
            self.assertEqual(result["changed"], ["BUY"])
            self.assertIn("SELLING_TAB", result["removed"])
        self.assertEqual(snapshot, (ROOT / "locales/upstream.json").read_bytes())

    def test_package_layout_contents_and_reproducibility(self):
        catalog.package()
        path = ROOT / "dist" / f"{catalog.ADDON}-{(ROOT / 'VERSION').read_text().strip()}.zip"
        first = path.read_bytes()
        catalog.package()
        self.assertEqual(first, path.read_bytes())
        with zipfile.ZipFile(path) as archive:
            self.assertEqual(set(archive.namelist()), {
                f"{catalog.ADDON}/{catalog.ADDON}.toc", f"{catalog.ADDON}/Translations.lua",
                f"{catalog.ADDON}/README.md", f"{catalog.ADDON}/CHANGELOG.md",
            })
            toc = archive.read(f"{catalog.ADDON}/{catalog.ADDON}.toc").decode()
            lua_files = [line for line in toc.splitlines() if line and not line.startswith("#")]
            self.assertEqual(lua_files, ["Translations.lua"])
            for filename in lua_files:
                self.assertEqual(archive.read(f"{catalog.ADDON}/{filename}"),
                                 (ROOT / "addon" / catalog.ADDON / filename).read_bytes())


class RuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.upstream = catalog.metadata()
        path = ROOT / ".cache" / f"Auctionator-{cls.upstream['version']}.zip"
        if not path.exists():
            raise RuntimeError("Run python3 scripts/catalog.py fetch before tests")
        if catalog.digest(path.read_bytes()) != cls.upstream["archive_sha256"]:
            raise RuntimeError("Upstream archive checksum mismatch")
        with zipfile.ZipFile(path) as archive:
            cls.source = {name: archive.read(name).decode("utf-8-sig") for name in archive.namelist()
                          if name.endswith(".lua") and (name.startswith("Auctionator/Locales/")
                                                       or name == "Auctionator/Source/Locales/Main.lua")}
        cls.translation = (ROOT / "addon" / catalog.ADDON / "Translations.lua").read_text(encoding="utf-8")
        cls.cs = catalog.translations()

    def runtime(self, locale="enUS", translation=True):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute("Auctionator = {Locales = {}}; AUCTIONATOR_CONFIG = {sentinel = 123}")
        lua.globals().GetLocale = lambda: locale
        if translation:
            lua.execute(self.translation)
        lua.execute(self.source["Auctionator/Locales/Main.lua"])
        for name in sorted(self.source):
            if name.startswith("Auctionator/Locales/") and not name.endswith("/Main.lua"):
                lua.execute(self.source[name])
        return lua

    def resolve(self, lua):
        lua.execute(self.source["Auctionator/Source/Locales/Main.lua"])

    def test_source_parser_matches_actual_lua_and_snapshot(self):
        lua = self.runtime()
        actual = dict(lua.globals().AUCTIONATOR_LOCALES.enUS().items())
        self.assertEqual(actual, catalog.parse_source(self.source[catalog.SOURCE]))
        self.assertEqual({k: catalog.signature(k, v) for k, v in actual.items()}, self.upstream["strings"])

    def test_only_override_is_written_without_auctionator_or_game_apis(self):
        lua = LuaRuntime()
        before = set(lua.globals().keys())
        lua.execute(self.translation)
        self.assertEqual(set(lua.globals().keys()) - before, {"AUCTIONATOR_LOCALES_OVERRIDE"})
        self.assertEqual(dict(lua.globals().AUCTIONATOR_LOCALES_OVERRIDE().items()), self.cs)

    def test_each_factory_call_returns_an_independent_table(self):
        lua = self.runtime()
        first = lua.globals().AUCTIONATOR_LOCALES_OVERRIDE()
        first["BUY"] = "mutated"
        self.assertEqual(lua.globals().AUCTIONATOR_LOCALES_OVERRIDE()["BUY"], "Koupit")

    def test_czech_wins_on_all_client_locales_before_first_consumer(self):
        for locale in ["enUS", "enGB", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW", "unknown"]:
            with self.subTest(locale=locale):
                lua = self.runtime(locale)
                self.resolve(lua)
                for key, text in self.cs.items():
                    self.assertEqual(lua.globals()["AUCTIONATOR_L_" + key], text.replace("\\n", "\n"), key)
                self.assertEqual(lua.eval("GetLocale()"), locale)
                self.assertEqual(lua.globals().AUCTIONATOR_CONFIG.sentinel, 123)
                self.assertEqual(lua.eval("Auctionator.Locales.Apply('SHOPPING_TAB')"), "Nákup")

    def test_english_fallback_for_missing_and_future_strings(self):
        lua = self.runtime("deDE")
        lua.execute('''
            local originalCzech = AUCTIONATOR_LOCALES_OVERRIDE
            AUCTIONATOR_LOCALES_OVERRIDE = function()
                local L = originalCzech(); L.BUY = nil; return L
            end
            local originalEnglish = AUCTIONATOR_LOCALES.enUS
            AUCTIONATOR_LOCALES.enUS = function()
                local L = originalEnglish(); L.FUTURE_KEY = "Future %s"; return L
            end
        ''')
        self.resolve(lua)
        self.assertEqual(lua.globals().AUCTIONATOR_L_BUY, "Buy")
        self.assertEqual(lua.eval("Auctionator.Locales.Apply('FUTURE_KEY', 'item')"), "Future item")
        self.assertEqual(lua.globals().AUCTIONATOR_L_SELLING_TAB, "Prodej")

    def test_disabling_translation_restores_client_language(self):
        for locale in ("enUS", "deDE", "frFR"):
            lua = self.runtime(locale, translation=False)
            expected = dict(lua.globals().AUCTIONATOR_LOCALES[locale]().items())
            english = dict(lua.globals().AUCTIONATOR_LOCALES.enUS().items())
            self.resolve(lua)
            for key in english:
                self.assertEqual(lua.globals()["AUCTIONATOR_L_" + key],
                                 expected.get(key, english[key]).replace("\\n", "\n"))

    def test_every_format_string_runs_and_preserves_argument_order(self):
        lua = self.runtime()
        self.resolve(lua)
        apply = lua.globals().Auctionator.Locales.Apply
        for key, record in self.upstream["strings"].items():
            if not record["format"]:
                continue
            args = [f"ARG{i}" for i, spec in enumerate(record["format"]) if spec != "%%"]
            rendered = apply(key, *args)
            positions = [rendered.index(arg) for arg in args]
            self.assertEqual(positions, sorted(positions), key)
        self.assertEqual(apply("BUYING_X_FOR_X", "Měděná ruda", "12 zl."), "Nákup: Měděná ruda za 12 zl.")
        self.assertEqual(apply("TOTAL_OF_X_FOR_UNIT_PRICE_OF_X", "20 zl.", "2 zl."),
                         "Celková cena: 20 zl., cena za kus: 2 zl.")
        self.assertEqual(lua.globals().AUCTIONATOR_L_LIST_SEARCH_STATUS.count("\n"), 1)


if __name__ == "__main__":
    unittest.main()
