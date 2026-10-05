# Změny

## 0.1.0-alpha.5 — 2026-10-05

- Název v seznamu addonů je na přání autora „Azeroth cesky: Auctionator“, bez diakritiky a s původním herním fontem. Logo zůstává zachované.
- Odstraněn modul měnící font vlastního řádku v seznamu addonů. Font s českými znaky se nadále používá uvnitř Auctionatoru.

## 0.1.0-alpha.4 — 2026-10-05

- Stejné logo jako hlavní Azeroth česky, přibalené přímo v modulu a připojené přes `IconTexture` v TOC.
- Oprava českých znaků v názvu „Azeroth česky: Auctionator“ v seznamu addonů otevřeném přes Esc už ve hře. Název ani sdílené herní fonty se nemění.
- Při opětovném použití řádku pro jiný addon se náš font obnoví na původní; testy pokrývají posouvání, pozdní načtení seznamu a ochranu ostatních řádků.
- Vyžaduje úplný restart klienta kvůli novému Lua souboru a ikoně v metadatech. Ověření vzhledu ve hře čeká.

## 0.1.0-alpha.3 — 2026-10-05

- Přibalený Gentium Book doplňuje české glyfy do vlastních oken Auctionatoru včetně tlačítek, nastavení a dodatečně vytvořených řádků historie cen. Velikost písma, barvy a herní fonty mimo Auctionator zůstávají zachované.
- Kratší popisky Import, Export, Nastavení, Cena odkupu, Příhoz a úrovní pro omezený prostor tlačítek, filtrů a sloupců.
- Regresní testy fontů, stavů tlačítek, posouvání výsledků, rozsahu zásahů a odložení za boje; test českých glyfů přímo v přibaleném TTF. Licence fontu je součástí balíčku.
- Oprava reaguje na snímky z prvního testu alpha.2. Vzhled alpha.3 ve hře je ještě potřeba potvrdit.

## 0.1.0-alpha.2 — 2026-10-05

- Testy formátování používají správné typy argumentů pro číselné, znakové a textové značky Lua a kontrolují celý výsledný text včetně šířky, přesnosti a doslovného procenta.
- Odkazy na katalog a dokumentaci v README směřují na GitHub a fungují i po rozbalení instalačního ZIPu.
- Český katalog zůstává beze změn. Ověření ve hře stále čeká; jde o alpha verzi.

## 0.1.0-alpha.1 — 2026-10-05

- První samostatný český katalog: všech 451 lokalizačních klíčů Auctionatoru 340.
- Napojení přes `AUCTIONATOR_LOCALES_OVERRIDE` před načtením Auctionatoru.
- Zobrazovaný název „Azeroth česky: Auctionator“, technická složka `AAzerothAuctionator`.
- Anglický fallback zajišťuje Auctionator. Hlavní Azeroth česky není potřeba.
- Kontrola změn upstream textů, generování Lua, testy na Lua 5.1 a opakovatelné balení ZIPu.
- Cílový klient: WoW: Forever 1.60.1. Herní a jazyková revize komunity zatím čeká; jde o alpha verzi.
