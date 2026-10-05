# Ověření ve WoW: Forever

Stav: **první test alpha.2 odhalil chyby; opakované ověření alpha.3 čeká**. Snímky od No898 z 5. 10. 2026 po místní instalaci do Forever 1.60.1 s Auctionatorem 340 potvrzují načtené české texty, ale také chybějící glyfy ř/ě/ň/č v popiscích a datech, překryv Nový seznam / Importovat a zkrácené dlouhé názvy filtrů a sloupců. Přesná zapnutá sada addonů a měřítko UI nejsou potvrzené.

Alpha.3 přidává vlastní font s českými glyfy a zkracuje problematické popisky. Izolované Lua testy neověřují herní rasterizaci ani rozložení. Pro první stabilní verzi vyplň výsledek, datum, build klienta a verze obou addonů.

## Opakování nahlášených chyb v alpha.3

- [ ] Po úplném restartu otevři nastavení a rozšířené hledání: ř, ě, ň, č se zobrazují správně.
- [ ] Nový seznam, Import a Export se nepřekrývají; zkontroluj i najetí myší a vypnutá tlačítka.
- [ ] Cena odkupu, Úr. použití, Úroveň předm. a Úr. předm. se vejdou do filtrů a sloupců.
- [ ] V historii cen mají neděle / říjen / čtvrtek správné znaky i po posunu tabulky a novém hledání.
- [ ] Font funguje i při zapnutém samotném Auctionatoru a českém modulu, bez hlavního Azeroth česky.
- [ ] Nativní záložky a jiná okna hry mají původní fonty; po vypnutí modulu a `/reload` se vrátí i fonty Auctionatoru.

## Název a logo v alpha.4

No898 doplnil snímek rozbitého `č` v názvu a potvrdil, že seznam otevřel přes Esc už ve hře. Alpha.4 proto rozšiřuje fontovou opravu pouze na vlastní řádek v tomto seznamu a přidává požadované původní logo.

- [ ] Po úplném restartu a přihlášení otevři Esc → AddOns: naše položka má logo hlavního Azeroth česky a správné `č`.
- [ ] Posuň seznam mimo naši položku a zpět; název zůstává správný a fonty jiných addonů se nemění.
- [ ] Zopakuj kontrolu bez hlavního Azeroth česky, pouze s Auctionatorem a českým modulem.
- [ ] Změna stavu zapnutí a vyhledávání v seznamu fungují jako předtím; žádné nové Lua chyby.

Seznam před přihlášením používá font klienta; jeho diakritiku náš ještě nenačtený Lua modul nemůže opravit.

## Instalace a načtení

- [ ] Nainstaluj instalační ZIP do klienta Forever 1.60.1, vedle Auctionatoru 340.
- [ ] Ponech původní složku `AAzerothAuctionator`, vypni ostatní jazykové moduly Auctionatoru.
- [ ] Nejprve spusť pouze Auctionator a český modul, bez hlavního Azeroth česky. Proveď úplný restart klienta.
- [ ] V seznamu addonů je „Azeroth česky: Auctionator“, bez chybné verze nebo chybějící závislosti.
- [ ] Po přihlášení jsou záložky Nákup, Prodej a Rušení aukcí česky už při prvním otevření.
- [ ] `/reload` češtinu zachová. Vypnutí českého modulu a nové načtení obnoví jazyk klienta.
- [ ] Překlad nic nemění v uložených cenách, seznamech, profilech ani aukcích.

## Texty a funkce

- [ ] Nákupní seznam: vytvoření, přejmenování, hledání, rozšířené filtry, import a export.
- [ ] Dlouhé texty a diakritika v nastavení a nápovědách: č, ř, ě, š, ž, ů, ď, ť, ň, ú.
- [ ] Tlačítka a sloupce se vejdou při běžném i zmenšeném měřítku UI; texty se nepřekrývají.
- [ ] Nákupní dialog správně rozlišuje celkovou cenu, cenu za kus a množství.
- [ ] Prodejní dialog správně zobrazuje zálohu, příhoz, cenu za kus, velikost balíku a délku aukce.
- [ ] Kontrola podbízení a potvrzení zrušení aukce mají srozumitelný text.
- [ ] Úplný sken správně zobrazuje průběh, počet předmětů a prodlevu dalšího skenu.
- [ ] Nápovědy, historie cen, zalomení řádků a barvy zůstávají funkční.
- [ ] Bez nových Lua chyb; porovnej s kontrolním spuštěním pouze s Auctionatorem.
- [ ] Zopakuj základní kontrolu s hlavním Azeroth česky a běžnou sadou addonů.

Nákupy, vystavení ani rušení skutečných aukcí nejsou součástí automatických testů. Pokud je ověřuješ ručně, zvol své testovací předměty. Popisky převzaté z Blizzard UI a herní názvy nejsou součástí tohoto katalogu; při hlášení uveď konkrétní obrazovku.
