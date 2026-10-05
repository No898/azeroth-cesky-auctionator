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

Factory při každém zavolání vrací novou tabulku. Překladový soubor zapisuje pouze zveřejněný callback. Od `alpha.3` samostatný `Fonts.lua` doplňuje font s českými znaky do vlastních oken Auctionatoru; chybějící glyfy v klientském fontu samotný katalog nevyřeší. Modul nemá uložené proměnné, síť ani závislost na hlavním Azeroth česky. Bez Auctionatoru fontová část neprovádí žádné změny.

## Font

Distribuujeme původní nezměněný `GentiumBook-Regular.ttf` z Gentium Book 7.000, Copyright (c) 2003–2025 SIL Global, pod SIL Open Font License 1.1. Celá licence je součástí ZIPu v `Fonts/OFL.txt`. Zdroj: [oficiální archiv SIL](https://software.sil.org/downloads/r/gentium/GentiumBook-7.000.zip). Stejný soubor používá hlavní Azeroth česky, ale tento modul obsahuje vlastní kopii a funguje samostatně.

| Soubor | SHA-256 |
| --- | --- |
| GentiumBook-Regular.ttf | `2027f6a864e5a9907c113438969d1d03fa91dfdd1a3885fa0fdeb496f0f682e4` |
| OFL.txt | `dcae5818b104b6cb24334bb4c92f7896d1ac988529ca4654ff21361a7b5b94ee` |

Fontová část hledá pouze pojmenované rámce `Auctionator*` a jejich potomky, včetně vlastních anonymních obalů záložek. Nemění sdílené objekty `GameFont*`, rodičovský AuctionFrame ani herní globální texty. Zachovává velikost, styl a barvu; tlačítka dostávají soukromé kopie fontů pro normální, zvýrazněný i vypnutý stav. Skenovací tooltipy, protected a forbidden rámce vynechává. Za boje se změny odkládají do `PLAYER_REGEN_ENABLED`.

Po načtení Auctionatoru a otevření aukce proběhne jednorázové vyhledání jeho oken. `OnShow`, vlastní továrny nastavení/dialogů a události výsledkových tabulek zachytí dodatečně vytvořené texty i řádky při posouvání. Obnovy se slučují do následujícího snímku; neběží žádná periodická kontrola ani globální hook vytváření rámců. Callbacky posouvání používají samostatného vlastníka, aby nenahradily registrace Auctionatoru. Post-hooky nemění návratové hodnoty ani aukční funkce. Při vypnutí modulu a novém načtení rozhraní se původní fonty obnoví vytvořením původního UI.

Lua testy kontrolují rozsah zásahů, stavy tlačítek, pozdní vytvoření a posouvání řádků, odložení za boje a opakované otevření. Kontrola skutečné cmap tabulky fontu ověřuje české glyfy. Herní rasterizaci a spolupráci s ostatními addony musejí ověřit herní testy.

### Vlastní položka v seznamu addonů

Od `alpha.4` doplňuje `AddonList.lua` jedinou cílenou výjimku mimo okna Auctionatoru: font vlastního názvu v nativním seznamu otevřeném přes Esc. Identitu řádku ověřuje podle jeho indexu a názvu `AAzerothAuctionator` přes API klienta. Text názvu, ikonu, barvy a stav zapnutí ponechává klientovi. Při recyklaci řádku obnoví původní font, pokud ho mezitím nezměnil jiný addon. Neplatné indexy a protected/forbidden rámce vynechá, změny odloží za boje. Fontové objekty ostatních addonů se nepřepisují.

Post-hook řádkového inicializátoru a obnovy seznamu doplňují `OnShow` a vlastní callback posouvání. Referencí pro názvy funkcí je [zdroj nativního AddonList](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_AddOnList/AddonList.lua); dostupnost se kontroluje za běhu a starší seznam může využít samotný `AddonList_Update`. Protože addon Lua před vstupem do hry neběží, oprava fontu se nevztahuje na výběr postavy.

Logo v `Textures/AddonLogo.tga` je nezměněná kopie loga hlavního Azeroth česky z místní instalace, převzatá na výslovné přání autora. SHA-256: `3560d56d094cdb2948bdeb3f53aecd140193c34283c28195e8bb43f72dd8d929`. TOC odkazuje na vlastní kopii přes `IconTexture`; hlavní addon není potřeba.

Složka se nesmí přejmenovat: `AAzerothAuctionator` se řadí před `Auctionator`. Manifest se jmenuje stejně jako složka. `Title` obsahuje samostatný název zobrazený hráči. TOC nemá závislost na Auctionatoru a není LoadOnDemand. Skutečný loader hry je potřeba ověřit ve hře; Lua testy ho nesimulují jako důkaz kompatibility.

Jeden globální callback znamená jeden aktivní překladový modul. Při více modulech záleží na pořadí zápisů a poslední může předchozí překlad nahradit. Proto se podporuje zapnutý pouze tento modul. Vlastní nastavení jazyka není potřeba; zapnutí addonu zvolí češtinu, vypnutí a načtení rozhraní obnoví jazyk klienta.

## Referenční upstream

- [Auctionator 340](https://www.curseforge.com/wow/addons/auctionator/files/9037876), oficiální archiv a SHA-256 v `locales/upstream.json`.
- `Locales/enUS.lua`: 451 unikátních klíčů; opakované přiřazení např. `PRICE` přebírá poslední hodnotu, stejně jako Lua.
- `Source/Locales/Main.lua`: callback, anglický fallback při `nil`, newline normalizace, export globálů a `Auctionator.Locales.Apply`.
- `Source/Utilities/PrettyDate.lua`: pevné pořadí měsíc–den pro nekorejské klienty; samotné překlady jej nemění.
- [Existující turecký modul](https://github.com/Auctionator/AAuctionatorTurkish) používá stejné rozhraní.

Starší návrh vestavěného přepínače jazyků není součástí této implementace. Zdrojové soubory a knihovny Auctionatoru se nepřibalují. Tests používají ověřený archiv lokálně v ignorované `.cache/`.
