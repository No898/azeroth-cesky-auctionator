# Azeroth česky: Auctionator

Samostatný český překlad [Auctionatoru](https://www.curseforge.com/wow/addons/auctionator), spravovaný projektem [Azeroth česky](https://github.com/No898/azeroth-cesky).

**Verze `0.1.0` pro WoW: Forever 1.60.1 a Auctionator 340.** Přeloženo je všech **451 textů jeho lokalizačního katalogu**. Vydání obsahuje font s českými znaky a kratší popisky podle prvního testu ve hře. V seznamu addonů se modul jmenuje **Azeroth cesky: Auctionator**, používá původní herní font a stejné logo jako hlavní Azeroth česky. Kontroly katalogu a izolované testy v Lua 5.1 jsou součástí projektu; úplná herní kontrola posledních oprav fontů a rozložení ještě čeká.

## Instalace

1. Nainstaluj [Auctionator](https://www.curseforge.com/wow/addons/auctionator).
2. Stáhni instalační balíček `AAzerothAuctionator-<verze>.zip` z příloh v [Releases](https://github.com/No898/azeroth-cesky-auctionator/releases). GitHub tlačítko **Code → Download ZIP** stahuje vývojové zdroje, nikoli instalační balíček.
3. Při vypnuté hře rozbal složku `AAzerothAuctionator` do `Interface/AddOns` svého klienta WoW: Forever. Složku nepřejmenovávej.
4. Ve výběru addonů zapni **Auctionator** i **Azeroth cesky: Auctionator** a přihlas se do hry.

Výsledná struktura:

```text
Interface/AddOns/
├── Auctionator/
└── AAzerothAuctionator/
    ├── AAzerothAuctionator.toc
    ├── Translations.lua
    ├── Fonts.lua
    ├── Fonts/
    │   ├── GentiumBook-Regular.ttf
    │   └── OFL.txt
    └── Textures/
        └── AddonLogo.tga
```

Čeština se použije automaticky. Hlavní addon **Azeroth česky není potřeba**. Pro návrat k jazyku herního klienta vypni pouze **Azeroth cesky: Auctionator** a znovu načti rozhraní. Ostatní překladové moduly Auctionatoru nech vypnuté; sdílejí jeden přepis jazyka.

Při aktualizaci nahraď celou složku a úplně restartuj klienta, aby se načetla nová metadata a nezůstaly staré soubory. Rozhraní Auctionatoru používá přibalený Gentium Book se zachováním velikosti písma a barev. Seznam addonů a sdílené herní fonty se nemění; název bez diakritiky je čitelný i před přihlášením.

Nepřekládaná jména v seznamu překladatelů zachovávají původní font kvůli cizojazyčným znakům. Nápovědy nastavení Auctionatoru používají český font dočasně; při skrytí nebo přechodu k jinému vlastníkovi se obnoví původní font.

## Co se překládá

- Vlastní texty Auctionatoru: nákup, prodej, rušení aukcí, seznamy, nastavení a aukční nápovědy.
- Nové texty, pro které ještě nemáme překlad, Auctionator automaticky doplní anglicky.
- Názvy předmětů, kouzel a kategorií dodané hrou i některá tlačítka používající přímo texty Blizzardu zůstávají v jazyce klienta.
- Pořadí částí data určuje Auctionator; tento modul překládá názvy měsíců a dní, ale formát data nepřepisuje.

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

Překlady se upravují v [`locales/csCZ.json`](https://github.com/No898/azeroth-cesky-auctionator/blob/main/locales/csCZ.json). Po úpravě spusť:

```sh
python3 scripts/catalog.py build
```

Vygenerovaný `addon/AAzerothAuctionator/Translations.lua` se ukládá do repozitáře, ale neupravuje ručně. Po každé změně spusť kontroly a testy. CI navíc vytvoří instalační ZIP jako artefakt; nic automaticky nepublikuje na CurseForge.

Postup aktualizace: [CONTRIBUTING.md](https://github.com/No898/azeroth-cesky-auctionator/blob/main/CONTRIBUTING.md). Kontrola ve hře: [docs/GAME_TEST.md](https://github.com/No898/azeroth-cesky-auctionator/blob/main/docs/GAME_TEST.md). Architektura: [docs/ARCHITECTURE.md](https://github.com/No898/azeroth-cesky-auctionator/blob/main/docs/ARCHITECTURE.md).

## Autoři

Auctionator: **plusmouse, Borjamacare a přispěvatelé původního projektu**. Český překlad: **Azeroth česky / No898**. Původní autorské údaje a odkazy na podporu Auctionatoru zůstávají zachované.

Přibalený nezměněný **Gentium Book 7.000 Regular**: Copyright (c) 2003–2025 SIL Global. Licence SIL Open Font License 1.1 je v `Fonts/OFL.txt`; původ a kontrolní součty jsou v [dokumentaci](https://github.com/No898/azeroth-cesky-auctionator/blob/main/docs/ARCHITECTURE.md#font).

English: standalone Czech translation for Auctionator, using its supported `AUCTIONATOR_LOCALES_OVERRIDE` callback. Requires Auctionator, but not Azeroth česky. Version 0.1.0 targets WoW: Forever 1.60.1 and Auctionator 340. Full in-game verification of the latest font and layout fixes is pending.
