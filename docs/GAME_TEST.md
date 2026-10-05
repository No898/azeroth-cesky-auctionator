# Ověření ve WoW: Forever

Stav: **neprovedeno**. Izolované Lua testy neověřují herní loader, fonty ani rozložení. Pro první stabilní verzi vyplň výsledek, datum, build klienta a verze obou addonů.

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
