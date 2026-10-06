# Změny

## 0.1.1 — 2026-10-06

- Popis a autor v metadatech addonu jsou bez diakritiky, aby se správně zobrazovaly původním herním fontem v seznamu addonů.

## 0.1.0 — 2026-10-06

- První vydání označené jako Release. Překlad i běhový kód odpovídají prověřené verzi alpha.6.
- Všech 451 textů Auctionatoru 340 v češtině, vlastní font s českou diakritikou, kratší popisky a logo Azeroth česky.
- Vyžaduje samostatný Auctionator; hlavní Azeroth česky je volitelný. Cílový klient je WoW: Forever 1.60.1.
- Automatické testy ověřují katalog, Lua 5.1, fontové regrese a balíček. Úplná herní kontrola posledních oprav fontů a rozložení zůstává otevřená.

## 0.1.0-alpha.6 — 2026-10-05

- Nepřekládaná jména překladatelů si ponechávají původní font, aby se neztratily čínské znaky. Český nadpis se nadále zobrazuje přibaleným fontem.
- České znaky fungují také v nových řádcích nákupních seznamů a nedávných hledání bez nutnosti znovu otevřít okno.
- Nápovědy nastavení dostávají český font dočasně. Po skrytí nebo změně vlastníka se původní font obnoví, aniž by přepsal pozdější změnu jiného addonu.
- Regresní testy pokrývají tyto případy včetně skutečného tooltip mixinu Auctionatoru 340, opakovaného zobrazení a obnovy za boje. Vykreslení a spolupráce s ostatními addony čekají na kontrolu ve hře.

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
