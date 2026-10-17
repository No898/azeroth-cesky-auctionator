# Soukromý kandidát 0.1.2-preview.2 — UI a nastavení

Tento záznam popisuje implementované přepínače a aktuální offline výsledky z
**17. 10. 2026**. Výsledky preview.1 z 15. října zůstávají níže jako historie.
Instalace a skutečný průchod WoW mají samostatné doklady mimo tento offline
protokol. Historické testy a snímky dřívějších verzí nejsou herním důkazem
nových přepínačů.

## Preference a rozsah

Companion vlastní dvě preference pro každou postavu. Chybějící hodnoty se
inicializují na `true/true`; výslovné `false` se zachová i přes `/reload`.
Stejné nastavení mění samostatné příkazy i kompatibilní hlavní addon:

| Kategorie | Samostatný příkaz | Rozsah |
| --- | --- | --- |
| `ui` | `/azca ui on` / `/azca ui off` | Běžné překládané plochy Auctionatoru, například nákup, prodej, rušení aukcí a jejich dialogy/nápovědy. |
| `settings` | `/azca settings on` / `/azca settings off` | Nastavení Auctionatoru a jeho vlastní dropdowny, tooltipy a dialogy. |

Podporované jsou všechny čtyři kombinace. `settings=false` nevypíná celý
doplněk a `ui=false` ponechává překlad nastavení. Přepnutí nemění
upstream konfiguraci, ceny, seznamy, profily, callbacky ani aukční funkce.
Případné samostatné vypnutí celého modulu ponechává obě uložené preference.
Sdílený lokalizační klíč není sám o sobě důkazem, do které kategorie patří
jeho konkrétní otevřený prvek; rozhoduje vlastněná plocha.

Úplný katalog 451 klíčů není dokladem úplného pokrytí kontextového rendereru.
Záložky, chat, tooltipy a dialogy mohou vytvářet text různými cestami; jejich
správnou kategorii a obnovu musí doložit aktuální regrese a herní matice.

Při vypnutí se zastaví překlady zvolené kategorie a obnovují jen její
aktuálně vlastněné texty a fonty, včetně již otevřených ploch. Novější zápis
Auctionatoru nebo jiného addonu se nepřepisuje. Boj, protected/forbidden
rámec nebo nečitelný stav může obnovu odložit. Znovuzapnutí překládá aktuální
originál; nepřevádí český text zpět na odhadnutou angličtinu.

## Volitelné ovládání přes hlavní addon

Podpora se zjišťuje přes `AzerothCeskyAPI.GetCompanionControls(1)`.
Companion používá identitu `AAzerothAuctionator` a publikuje obě podporované
kategorie. Hlavní addon drží ovládání, nikoli druhou kopii preferencí.
Aktuální replay používá controls protokol z core připravovaného pro 0.5.8,
revize `9e705ef4`; jeho přítomnost není podmínkou samostatného překladu
ani příkazů.

Bez core nebo se starším core bez nové operace preference dál fungují.
Pozdější registrace zveřejní skutečný uložený a účinný stav. Chybějící
Auctionator se nehlásí jako připravený host. Ovládání jiného companionu
ani kategorií hlavního addonu se přepnutím Auctionatoru nemění.

Stav rozlišuje uložené přání (`desired`) od známého výsledku (`effective`).
`applied` znamená dokončenou změnu; `pending-refresh`, `pending-combat`,
`reload-required`, `unavailable` a `error` označují příslušnou hranici.
Při neznámém či smíšeném výsledku se účinná hodnota netvrdí. Přijetí požadavku
tedy není potvrzení, že již otevřený český text zmizel. Opakovaný požadavek
na stejnou hodnotu nezpůsobí další zápis, revizi ani překreslení.

## Aktuální offline výsledky — 17. 10. 2026

Ověřený běhový kód má revizi `62e54ad`. Preview.2 zachovává předchozí
implementaci přepínačů, opravuje zápis do sdíleného registru příkazů a hlásí
stejnou verzi v registračním descriptoru jako VERSION a TOC.

| Brána | Výsledek a hranice důkazu |
| --- | --- |
| Kontrola závislostí, build, check a package | PASS; 451 klíčů, bez varování. |
| Plná jednotková sada | PASS; 67 testů, žádný přeskočený. |
| Cílené regrese | PASS; dvě regrese verze a zachování sdíleného registru příkazů. Nová regrese na původním kódu očekávaně selhala kvůli hlášené preview.1. |
| Přesný ZIP | PASS; 10 položek, CRC a všechny bajty shodné se zdroji; archivovaný descriptor hlásí `0.1.2-preview.2`. |
| Skutečný core controls protokol a přesné ZIPy tří companionů | PASS; čtyři kombinace, uložené preference, nezávislost companionů a pravdivé čekající stavy. Host/renderery jsou stuby, nikoli celé upstream UI nebo WoW. |
| Instalace a skutečný herní průchod | Samostatné brány. Hlášení po kliknutí na RestedXP Active Targets ani průchod myší, gamepadem a bojem tento protokol neuzavírá. |
| Veřejná publikace | Není součástí soukromého kandidáta. |

[Protokol ze 17. října](verification/2026-10-17-preview2-controls.json)
zachovává checksum ZIPu před touto následnou dokumentační úpravou.
Změna README nemění ověřený běhový kód, ale každé přebalení potřebuje nový
checksum, CRC a readback všech deseti souborů. Samotná úprava dokumentace
nevyžaduje opakování celé 67testové sady.

## Historické offline výsledky — 15. 10. 2026, preview.1

Následující výsledky a jejich protokol patří původnímu preview.1.

| Brána | Výsledek a hranice důkazu |
| --- | --- |
| Zdrojový katalog, build, check a package | PASS bez varování; 451 klíčů referenční verze. Katalogové pokrytí nepotvrzuje všechny výskyty textu v UI. |
| Plná jednotková sada | PASS; 65 testů, z toho 36 nových controls testů. Běží mimo klienta WoW. |
| Skutečný core controls kontrakt 1 + tři companion Controls moduly | PASS nad zdroji i přesnými ZIPy všech tří companionů; host a renderery jsou testovací stuby. Není to celé upstream UI ani hra. |
| Finální instalační ZIP a SHA-256/readback + controls replay z přesného ZIPu | PASS; 10 souborů odpovídá zdrojům. Otisk a hranice důkazu jsou v [protokolu](verification/2026-10-15-ui-settings-controls.json). |
| Instalace přesného ZIPu do klienta | Samostatný instalační doklad; tento offline protokol ji nepotvrzuje. |
| Myš, gamepad, boj a již otevřené plochy ve WoW | Neprovedeno; viz [GAME_TEST.md](GAME_TEST.md). |
| Veřejná publikace | Není součástí soukromého kandidáta. |

Dokud není zaznamenaný skutečný herní průchod, netvrdíme absenci taintu,
plynulost, správné pořadí klientských událostí ani úplné herní ověření.
