# Přispívání a aktualizace

## Překlady

Upravuj `locales/csCZ.json`, UTF-8, dva mezerníky. Používej stručnou češtinu, v návodech tykání. Zachovej pořadí a počet `%s` a dalších formátovacích značek, `%%`, barevné kódy a `\n`. Názvy addonů, Discord a technické identifikátory se nepřekládají.

Základní slovník:

| Originál | Překlad |
| --- | --- |
| Shopping / Selling / Cancelling | Nákup / Prodej / Rušení aukcí |
| Stack | Balík |
| Post | Vystavit |
| Buyout | Okamžitý nákup |
| Bid | Příhoz |
| Undercut | Podbízení |
| Shopping list | Nákupní seznam |
| Tooltip | Nápověda |
| Reagent | Materiál |

Prázdné překlady se nepoužívají. Release vyžaduje úplný katalog vůči připnuté verzi. Když se později aktualizuje samotný Auctionator, jeho anglický fallback zajistí zobrazení nových chybějících klíčů. Názvy předmětů v parametrech se neskloňují automaticky; používej formulace, které nepotřebují měnit jejich tvar.

Po změně spusť `build`, `check` a testy podle README. Přidej záznam do CHANGELOG. Při hlášení chyby uveď verzi překladu, Auctionatoru a klienta, jazyk klienta, původní text a ideálně snímek konkrétního místa.

## Nová verze Auctionatoru

1. Stáhni nové oficiální vydání z CurseForge.
2. Spusť `python3 scripts/catalog.py compare --zip /cesta/Auctionator-NOVA_VERZE.zip`. Příkaz vypíše nové, změněné a odstraněné klíče i nové anglické znění. Návratový kód 1 znamená změny k revizi, 0 shodu. Současné překlady ani referenční otisky se tím nemění.
3. Reviduj význam změněných položek a uprav `locales/csCZ.json`. Originály pro porovnání získáš z `Locales/enUS.lua` v oficiálním ZIPu. Úplný anglický katalog ani cizí zdrojové soubory v tomto repozitáři nespravujeme.
4. Po revizi aktualizuj verzi, oficiální URL, datum a SHA-256 archivu v `locales/upstream.json`. Potom spusť `snapshot --zip /cesta/Auctionator-NOVA_VERZE.zip`. Tím přijmeš nové otisky a formátovací kontrakt; nejde o automatické schválení překladů.
5. Spusť `build`, `fetch`, testy a `package`. Zkontroluj změny TOC a upstream resolveru, jestli stále platí pořadí načtení a fallback. Pokud se syntaktický formát enUS změní, parser má selhat, nikoli texty potichu vynechat.
6. Zkontroluj checklist ve hře. Aktualizuj `VERSION`, `## Version` v TOC, changelog a údaje v README. Verzi kompatibility klienta měň pouze na základě ověřeného klienta.

V repozitáři jsou otisky každé anglické hodnoty, formátovací značky a odkazy na konkrétní vydání. Zachytí se tak i změna anglického významu při zachování stejného klíče. Kontrola nových vydání je ruční; není nastavený pravidelný monitor.

## Distribuce

Balíček vytvoří `python3 scripts/catalog.py package`. Obsahuje pouze složku `AAzerothAuctionator` a sedm povolených souborů: TOC, katalog Lua, fontový modul Lua, font TTF s licencí OFL, README a changelog. Publikuj připravený ZIP, ne zdrojový archiv GitHubu. Alpha verze označ jako předběžné vydání a uveď neověřené kontroly.

Pro budoucí distribuci přes CurseForge založ samostatný projekt a v jeho vztazích uveď Auctionator jako požadovaný addon. **Nepřidávej `Dependencies: Auctionator` ani `OptionalDeps: Auctionator` do našeho TOC:** tyto direktivy by vynutily opačné pořadí načtení. Vydávání na CurseForge zatím není nakonfigurované.

Překlad používá podporované lokalizační rozhraní. Fontový modul navíc řeší ověřené nedostatky českých glyfů ve vlastních oknech Auctionatoru; nesmí měnit sdílené herní fonty nebo funkce aukcí. Další zásahy do rozhraní, překlad herních textů a integraci s hlavním Azeroth česky navrhuj odděleně.
