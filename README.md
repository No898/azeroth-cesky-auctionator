# Azeroth česky: Auctionator

Samostatný český překlad [Auctionatoru](https://www.curseforge.com/wow/addons/auctionator), spravovaný projektem [Azeroth česky](https://github.com/No898/azeroth-cesky).

**První testovací verze `0.1.0-alpha.1` pro WoW: Forever 1.60.1 a Auctionator 340.** Přeloženo je všech **451 textů jeho lokalizačního katalogu**. Kontroly katalogu a izolované testy v Lua 5.1 jsou součástí projektu. Vzhled, diakritiku, délku popisků a skutečné pořadí načtení je před stabilním vydáním potřeba ověřit ve hře.

## Instalace

1. Nainstaluj [Auctionator](https://www.curseforge.com/wow/addons/auctionator).
2. Stáhni instalační balíček `AAzerothAuctionator-<verze>.zip`, až bude přiložený v [Releases](https://github.com/No898/azeroth-cesky-auctionator/releases). GitHub tlačítko **Code → Download ZIP** stahuje vývojové zdroje, nikoli instalační balíček.
3. Při vypnuté hře rozbal složku `AAzerothAuctionator` do `Interface/AddOns` svého klienta WoW: Forever. Složku nepřejmenovávej.
4. Ve výběru addonů zapni **Auctionator** i **Azeroth česky: Auctionator** a přihlas se do hry.

Výsledná struktura:

```text
Interface/AddOns/
├── Auctionator/
└── AAzerothAuctionator/
    ├── AAzerothAuctionator.toc
    └── Translations.lua
```

Čeština se použije automaticky. Hlavní addon **Azeroth česky není potřeba**. Pro návrat k jazyku herního klienta vypni pouze **Azeroth česky: Auctionator** a znovu načti rozhraní. Ostatní překladové moduly Auctionatoru nech vypnuté; sdílejí jeden přepis jazyka.

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

Překlady se upravují v [`locales/csCZ.json`](locales/csCZ.json). Po úpravě spusť:

```sh
python3 scripts/catalog.py build
```

Vygenerovaný `addon/AAzerothAuctionator/Translations.lua` se ukládá do repozitáře, ale neupravuje ručně. Po každé změně spusť kontroly a testy. CI navíc vytvoří instalační ZIP jako artefakt; nic automaticky nepublikuje na CurseForge.

Postup aktualizace: [CONTRIBUTING.md](CONTRIBUTING.md). Kontrola ve hře: [docs/GAME_TEST.md](docs/GAME_TEST.md). Architektura: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Autoři

Auctionator: **plusmouse, Borjamacare a přispěvatelé původního projektu**. Český překlad: **Azeroth česky / No898**. Původní autorské údaje a odkazy na podporu Auctionatoru zůstávají zachované.

English: standalone Czech translation for Auctionator, using its supported `AUCTIONATOR_LOCALES_OVERRIDE` callback. Requires Auctionator, but not Azeroth česky. Initial alpha targets WoW: Forever. In-game verification is pending.
