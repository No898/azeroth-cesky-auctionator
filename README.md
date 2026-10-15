# Azeroth česky: Auctionator

Samostatný český překlad [Auctionatoru](https://www.curseforge.com/wow/addons/auctionator), spravovaný projektem [Azeroth česky](https://github.com/No898/azeroth-cesky).

**Soukromý kandidát `0.1.2-preview.1` pro WoW: Forever 1.60.1 a Auctionator 340.** Implementuje nezávislé přepínače překladu UI a nastavení. Katalog obsahuje všech **451 textů referenční verze**; addon přibaluje font s českými znaky. V seznamu addonů se modul jmenuje **Azeroth cesky: Auctionator**, používá původní herní font a stejné logo jako hlavní Azeroth česky. Lokální jednotkové testy a společný controls replay prošly 15. 10. 2026. Dřívější první test ve hře nové přepínače nepotvrzuje; skutečný herní průchod dál čeká.

## Instalace

1. Nainstaluj [Auctionator](https://www.curseforge.com/wow/addons/auctionator).
2. Stáhni instalační balíček `AAzerothAuctionator-<verze>.zip` z příloh v [Releases](https://github.com/No898/azeroth-cesky-auctionator/releases). GitHub tlačítko **Code → Download ZIP** stahuje vývojové zdroje, nikoli instalační balíček.
3. Při vypnuté hře rozbal složku `AAzerothAuctionator` do `Interface/AddOns` svého klienta WoW: Forever. Složku nepřejmenovávej.
4. Ve výběru addonů zapni **Auctionator** i **Azeroth cesky: Auctionator** a přihlas se do hry.

Instalační balíček soukromého kandidáta se jmenuje
`AAzerothAuctionator-0.1.2-preview.1.zip`. Konkrétní finální readback,
kontrolní součet a replay zabalených controls patří do
[záznamu kandidátu](docs/COMPANION_CONTROLS.md). Zdrojové testy samy nedokládají
obsah finálního ZIPu, jeho instalaci ani veřejnou dostupnost.

Základní struktura:

```text
Interface/AddOns/
├── Auctionator/
└── AAzerothAuctionator/
    ├── AAzerothAuctionator.toc
    ├── Controls.lua
    ├── Translations.lua
    ├── Fonts.lua
    ├── Fonts/
    │   ├── GentiumBook-Regular.ttf
    │   └── OFL.txt
    └── Textures/
        └── AddonLogo.tga
```

Při výchozích preferencích se čeština použije automaticky. Hlavní addon **Azeroth česky není potřeba**. Pro návrat k jazyku herního klienta vypni pouze **Azeroth cesky: Auctionator** a znovu načti rozhraní. Ostatní překladové moduly Auctionatoru nech vypnuté; sdílejí jeden přepis jazyka.

## Nezávislé přepínače v soukromém kandidátu

`/azca ui on|off` ovládá běžné překládané plochy Auctionatoru a
`/azca settings on|off` jeho nastavení včetně vlastních dropdownů, nápověd
a dialogů. Obě preference jsou uložené pro postavu, mají výchozí hodnotu
`on` a podporují všechny čtyři kombinace. Vypnutí nastavení nevypíná překlad
nákupu, prodeje či rušení aukcí; vypnutí UI ponechává překlad nastavení.

Vypnutí obnovuje text i font zvolené kategorie také v aktuálně vlastněných
otevřených plochách. Při boji či ochraně rámce může být obnova čekající;
novější zápis jiného vlastníka se nepřepisuje.
Přijetí preference samo nedokládá její dokončení. Znovuzapnutí vychází
z aktuálního originálu. Upstream ceny, seznamy, profily a aukční funkce
se přepnutím nemění.

Kompatibilní hlavní addon může stejné preference ovládat přes volitelné
`AzerothCeskyAPI.GetCompanionControls(1)` pod identitou `AAzerothAuctionator`.
Bez core nebo se starším core dál platí samostatné příkazy a uložené hodnoty.
Přepnutí nemění jiné companiony ani kategorie hlavního addonu.
[Podrobnosti](docs/COMPANION_CONTROLS.md) rozlišují požadovaný a účinný stav;
[herní plán](docs/GAME_TEST.md) obsahuje dosud neprovedený průchod myší i gamepadem.

Při aktualizaci nahraď celou složku a úplně restartuj klienta, aby se načetla nová metadata a nezůstaly staré soubory. Rozhraní Auctionatoru používá přibalený Gentium Book se zachováním velikosti písma a barev. Seznam addonů a sdílené herní fonty se nemění; název bez diakritiky je čitelný i před přihlášením.

Nepřekládaná jména v seznamu překladatelů zachovávají původní font kvůli cizojazyčným znakům. Nápovědy nastavení Auctionatoru používají český font dočasně; při skrytí nebo přechodu k jinému vlastníkovi se obnoví původní font.

## Co se překládá

- Vlastní texty Auctionatoru: nákup, prodej, rušení aukcí, seznamy, nastavení a aukční nápovědy.
- Nové texty, pro které ještě nemáme překlad, Auctionator automaticky doplní anglicky.
- Názvy předmětů, kouzel a kategorií dodané hrou i některá tlačítka používající přímo texty Blizzardu zůstávají v jazyce klienta.
- Pořadí částí data určuje Auctionator; tento modul překládá názvy měsíců a dní, ale formát data nepřepisuje.

Pokrytí 451 katalogových klíčů samo nepotvrzuje kontextové přepínání každého
jejich výskytu. Nový renderer vyžaduje zvlášť ověřit také producenty záložek,
chatových zpráv, tooltipů a dialogů v obou smíšených kombinacích.

Jde o komunitní překlad používající rozhraní doporučené autorem Auctionatoru. Balíček neobsahuje samotný Auctionator ani nemění jeho soubory, herní globální texty, ceny, vyhledávací údaje či uložená nastavení. Podpora dalších variant WoW zatím není ověřená; TOC cílí pouze na Forever (`16001`).

## Vývoj a kontrola

Potřebuješ Python 3.9 nebo novější. Při běžném hraní Python ani žádný nástroj nepotřebuješ.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python scripts/catalog.py fetch
.venv/bin/python scripts/catalog.py check
.venv/bin/python -m unittest discover -s tests -v
.venv/bin/python scripts/catalog.py package
```

`fetch` stáhne konkrétní oficiální vydání Auctionatoru a ověří SHA-256. Testy používají jeho skutečný lokalizační resolver; nepouštějí WoW. Instalační ZIP a jeho kontrolní součet vzniknou v `dist/`. Na Windows použij `.venv\Scripts\python.exe`.

**Offline ověření 15. 10. 2026:** prošla plná sada **65 jednotkových testů**,
z toho **36 testů nových controls**, nad katalogem 451 klíčů. Prošel také
společný replay skutečného core controls kontraktu 1 se třemi zdrojovými
moduly `Controls.lua` companionů. Host a renderery v replayi zastupují testovací
stuby; výsledek nedokládá celé upstream UI, finální ZIP, instalaci ani hru.

Překlady se upravují v [`locales/csCZ.json`](https://github.com/No898/azeroth-cesky-auctionator/blob/main/locales/csCZ.json). Po úpravě spusť:

```sh
python3 scripts/catalog.py build
```

Vygenerovaný `addon/AAzerothAuctionator/Translations.lua` se ukládá do repozitáře, ale neupravuje ručně. Po každé změně spusť kontroly a testy. CI navíc vytvoří instalační ZIP jako artefakt; nic automaticky nepublikuje na CurseForge.

Postup aktualizace: [CONTRIBUTING.md](https://github.com/No898/azeroth-cesky-auctionator/blob/main/CONTRIBUTING.md). Kontrola ve hře: [docs/GAME_TEST.md](https://github.com/No898/azeroth-cesky-auctionator/blob/main/docs/GAME_TEST.md). Architektura: [docs/ARCHITECTURE.md](https://github.com/No898/azeroth-cesky-auctionator/blob/main/docs/ARCHITECTURE.md).

## Autoři

Auctionator: **plusmouse, Borjamacare a přispěvatelé původního projektu**. Český překlad: **Azeroth česky / No898**. Původní autorské údaje a odkazy na podporu Auctionatoru zůstávají zachované.

Přibalený nezměněný **Gentium Book 7.000 Regular**: Copyright (c) 2003–2025 SIL Global. Licence SIL Open Font License 1.1 je v `Fonts/OFL.txt`; původ a kontrolní součty jsou v [dokumentaci](https://github.com/No898/azeroth-cesky-auctionator/blob/main/docs/ARCHITECTURE.md#font).

English: standalone Czech translation for Auctionator, using its supported `AUCTIONATOR_LOCALES_OVERRIDE` callback. Requires Auctionator, but not Azeroth česky. Private candidate 0.1.2-preview.1 implements separate UI and settings preferences for WoW: Forever 1.60.1 and Auctionator 340. All 65 unit tests and a shared source-level core controls replay passed on 15 October 2026. Those checks do not prove the final ZIP, installation or actual in-game behavior.
