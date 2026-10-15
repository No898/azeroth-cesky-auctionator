# Ověření ve WoW: Forever

## Soukromý kandidát 0.1.2-preview.1: nezávislé přepínače

Nové UI/settings přepínače **dosud nemají skutečné herní ověření**. Dřívější
snímky a izolované testy níže je nepotvrzují. Lokální regrese, finální ZIP
a jeho instalaci eviduj odděleně v [záznamu kandidátu](COMPANION_CONTROLS.md).

Každý řádek proveď nejprve myší a potom gamepadem. U každého ulož verzi
klienta, identitu a SHA-256 instalovaných ZIPů, aktivní addony, způsob ovládání,
příkaz nebo použitý přepínač, `desired/effective/status`, snímek před/po a
Lua/taint log. Referenční nový core je `0.5.6-gamepad-controls.1`.

| `ui` | `settings` | Očekávání |
| --- | --- | --- |
| on | on | Překládané nákupní/prodejní UI i nastavení jsou české. |
| off | on | Běžné UI má původní text/font; nastavení dál české. |
| on | off | Běžné UI dál české; nastavení má původní text/font. |
| off | off | Obě kategorie mají původní text/font. |

- [ ] Projdi všechny čtyři kombinace přes `/azca ui on|off` a `/azca settings on|off`, bez core i s kompatibilním core ovládáním.
- [ ] Před přepnutím nech otevřené nastavení, jeho dropdown, vlastní tooltip a dialog; zvlášť běžný nákupní/prodejní dialog a nápovědu. Vypnutí obnoví pouze příslušnou kategorii bez nutnosti zavřít ostatní plochy. Nové otevření nesmí znovu přeložit vypnutou kategorii.
- [ ] Zkontroluj stejný lokalizační klíč použitý v běžném UI i nastavení. V kombinacích off/on a on/off se každá plocha řídí svou kategorií.
- [ ] Ověř producenty textu v záložkách, chatu, tooltipech a dialozích. Pokrytí 451 katalogových klíčů nenahrazuje tento kontextový průchod.
- [ ] Zopakuj změnu za boje a s chráněným/nečitelným rámcem: stav zůstane čekající, dokud je bezpečná obnova nemožná. Po bezpečném obnovení se dokončí bez starého textu, fontu a bez zápisu cizímu vlastníkovi.
- [ ] Před obnovou předej sdílený tooltip nebo pooled řádek jinému vlastníku. Jeho novější text/font se nesmí přepsat. Po zapnutí se překládá aktuální originál.
- [ ] V každé kombinaci proveď `/reload`, odhlášení/přihlášení a přechod na jinou postavu. Hodnoty první postavy zůstanou uložené; nová postava začíná on/on. Výslovné off nesmí zmizet migrací.
- [ ] Stejný příkaz nebo stejný core požadavek zopakuj vícekrát. Stav, revize a počet překreslení se nemají dále měnit; nevzniknou nové hooky ani Lua/taint chyby.
- [ ] Vypni či odeber core, použij starší core bez `GetCompanionControls`, potom otestuj jeho pozdější registraci. Příkazy a preference zůstanou funkční; po registraci se ukáže skutečný stav, nikoli výchozí on/on. Pokud loader vyžaduje reload, zaznamenej tuto hranici.
- [ ] Bez Auctionatoru se host nesmí hlásit jako připravený a nevznikají zásahy do cizího UI. S nekompatibilním core verzovaným kontraktem nevzniknou nefunkční přepínače.
- [ ] S Questie i dalšími companiony přepínej každou kategorii samostatně: žádná preference ani otevřená plocha druhého companionu či hlavního addonu se nezmění. Ověř zvlášť nezávislost UI/settings hlavního addonu a jeho quest/title/tracker voleb.
- [ ] Při přepnutí porovnej původní ceny, seznamy, profily, konfiguraci a callbackové argumenty/výsledky. Přepínače mění prezentaci; aukční akce a upstream hodnoty zůstávají stejné.

Následující checklist zachovává starší hlášení a dosavadní vizuální regrese;
není dokladem splnění nové matice.

## Dosavadní herní evidence

Stav: **první test alpha.2 odhalil chyby; úplné ověření oprav v 0.1.0 čeká**. Vydání 0.1.0 přebírá překlad i běhový kód alpha.6. Snímky od No898 z 5. 10. 2026 po místní instalaci do Forever 1.60.1 s Auctionatorem 340 potvrzují načtené české texty, ale také chybějící glyfy ř/ě/ň/č v popiscích a datech, překryv Nový seznam / Importovat a zkrácené dlouhé názvy filtrů a sloupců. Přesná zapnutá sada addonů a měřítko UI nejsou potvrzené.

Alpha.3 přidala vlastní font s českými glyfy a zkrátila problematické popisky. Izolované Lua testy neověřují herní rasterizaci ani rozložení. Při ověření 0.1.0 vyplň výsledek, datum, build klienta a verze obou addonů; označení Release samo o sobě neznamená splnění tohoto checklistu.

## Opakování nahlášených chyb v alpha.3

- [ ] Po úplném restartu otevři nastavení a rozšířené hledání: ř, ě, ň, č se zobrazují správně.
- [ ] Nový seznam, Import a Export se nepřekrývají; zkontroluj i najetí myší a vypnutá tlačítka.
- [ ] Cena odkupu, Úr. použití, Úroveň předm. a Úr. předm. se vejdou do filtrů a sloupců.
- [ ] V historii cen mají neděle / říjen / čtvrtek správné znaky i po posunu tabulky a novém hledání.
- [ ] Font funguje i při zapnutém samotném Auctionatoru a českém modulu, bez hlavního Azeroth česky.
- [ ] Nativní záložky a jiná okna hry mají původní fonty; po vypnutí modulu a `/reload` se vrátí i fonty Auctionatoru.

## Název a logo v alpha.5

No898 po nahlášení rozbitého `č` v názvu zvolil název bez diakritiky a původní font seznamu. Alpha.5 proto odstraňuje fontový zásah do seznamu z alpha.4 a zachovává původní logo hlavního addonu.

- [ ] Po úplném restartu má položka název „Azeroth cesky: Auctionator“, logo hlavního Azeroth česky a stejný font jako ostatní položky — u výběru postavy i přes Esc → AddOns ve hře.
- [ ] Posuň seznam mimo naši položku a zpět; název zůstává správný a fonty jiných addonů se nemění.
- [ ] Zopakuj kontrolu bez hlavního Azeroth česky, pouze s Auctionatorem a českým modulem.
- [ ] Změna stavu zapnutí a vyhledávání v seznamu fungují jako předtím; žádné nové Lua chyby.

Název bez diakritiky nevyžaduje zásah do fontu seznamu.

## Opravy z review v alpha.6

- [ ] V Informacích jsou čínské znaky ve jménech překladatelů čitelné a nadpis Překladatelé má českou diakritiku.
- [ ] Při otevřeném okně vytvoř a rozbal nákupní seznam s českými znaky; ověř nové řádky i po posouvání a přidání nedávného hledání.
- [ ] Najeď na nastavení automatického hledání seznamu: česká nápověda má správné znaky a zalomení i při opakovaném zobrazení.
- [ ] Po nápovědě nastavení otevři nápovědu předmětu a jiného addonu: mají původní font. Ověř také skrytí nápovědy při přechodu do boje a absenci Lua/taint chyb.

## Instalace a načtení

- [ ] Nainstaluj instalační ZIP do klienta Forever 1.60.1, vedle Auctionatoru 340.
- [ ] Ponech původní složku `AAzerothAuctionator`, vypni ostatní jazykové moduly Auctionatoru.
- [ ] Nejprve spusť pouze Auctionator a český modul, bez hlavního Azeroth česky. Proveď úplný restart klienta.
- [ ] V seznamu addonů je „Azeroth cesky: Auctionator“, bez chybné verze nebo chybějící závislosti.
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
