# Změny

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
