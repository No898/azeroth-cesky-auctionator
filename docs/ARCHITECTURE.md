# Napojení na Auctionator

Rozhodnutí z 5. 10. 2026: samostatný addon s českým katalogem. Maintainer plusmouse v komunikaci s No898 potvrdil použití `AUCTIONATOR_LOCALES_OVERRIDE` před načtením Auctionatoru a doporučil název řazený abecedně před ním. Přibalení k hlavnímu Azeroth česky je možnost pro budoucnost, nikoli technická závislost.

```text
AAzerothAuctionator.toc
  → Translations.lua nastaví AUCTIONATOR_LOCALES_OVERRIDE
Auctionator.toc
  → zaregistruje své jazykové katalogy
  → Source/Locales/Main.lua zavolá naši funkci
  → chybějící položky doplní z enUS
  → převede \\n a exportuje AUCTIONATOR_L_* pro svoje UI
```

Factory při každém zavolání vrací novou tabulku. Náš jediný zápis do globálního prostoru je zveřejněný callback. Modul nepotřebuje události, uložené proměnné, knihovny, síť, protected frames ani runtime přepisování UI. Bez Auctionatoru pouze vytvoří callback a dál nic nedělá.

Složka se nesmí přejmenovat: `AAzerothAuctionator` se řadí před `Auctionator`. Manifest se jmenuje stejně jako složka. `Title` obsahuje samostatný název zobrazený hráči. TOC nemá závislost na Auctionatoru a není LoadOnDemand. Skutečný loader hry je potřeba ověřit ve hře; Lua testy ho nesimulují jako důkaz kompatibility.

Jeden globální callback znamená jeden aktivní překladový modul. Při více modulech záleží na pořadí zápisů a poslední může předchozí překlad nahradit. Proto se podporuje zapnutý pouze tento modul. Vlastní nastavení jazyka není potřeba; zapnutí addonu zvolí češtinu, vypnutí a načtení rozhraní obnoví jazyk klienta.

## Referenční upstream

- [Auctionator 340](https://www.curseforge.com/wow/addons/auctionator/files/9037876), oficiální archiv a SHA-256 v `locales/upstream.json`.
- `Locales/enUS.lua`: 451 unikátních klíčů; opakované přiřazení např. `PRICE` přebírá poslední hodnotu, stejně jako Lua.
- `Source/Locales/Main.lua`: callback, anglický fallback při `nil`, newline normalizace, export globálů a `Auctionator.Locales.Apply`.
- `Source/Utilities/PrettyDate.lua`: pevné pořadí měsíc–den pro nekorejské klienty; samotné překlady jej nemění.
- [Existující turecký modul](https://github.com/Auctionator/AAuctionatorTurkish) používá stejné rozhraní.

Starší návrh vestavěného přepínače jazyků není součástí této implementace. Zdrojové soubory a knihovny Auctionatoru se nepřibalují. Tests používají ověřený archiv lokálně v ignorované `.cache/`.
