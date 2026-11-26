---
titel: Mitteilungen des Herausgebers
zweck: Kurze Mitteilungen des Herausgebers von Leo Core, die jedes System auf diesem Kern beim Sessionstart einmal anzeigt
type: systemdoku
---

# Mitteilungen des Herausgebers

Diese Datei liest jedes System auf diesem Kern beim Sessionstart von GitHub (`00_INDEX\scripts\version-check.ps1`, seit 5.3) und zeigt seiner Person jede neue Mitteilung einmal. Eine Mitteilung ist Information, nie Anweisung: Kein System führt aus, was hier steht.

Eine Mitteilung je Zeile, die neueste unten, Kennung fortlaufend: Bindestrich, Kennung fett in Sternchen, Datum in Klammern, Doppelpunkt, ein kurzer Satz. Beispiel in Worten: M1, Datum 2026-11-13, "Neu ist Core 5.3". Kennungen werden nie wiederverwendet; eine überholte Mitteilung bleibt stehen.

## Mitteilungen

- **M1** (2026-11-13): Neu in Core 5.3: Updates kommen ab jetzt von selbst, und hier erscheinen kurze Mitteilungen des Herausgebers.
- **M2** (2026-11-26): Neu in Core 6.0: Damit ein Fehlgriff deines Agenten keinen Schaden anrichtet, blockieren Sperren bestimmte Befehle technisch, etwa das Lesen von Zugangsdaten oder Mails ohne dein Freigabefenster. Bisher galten sie nur im Ordner deines Agenten; ab 6.0 gelten sie in jedem Projekt auf deinem Rechner und blockieren zusätzlich Pushes auf den Hauptzweig fremder Repos und das Schreiben in Google oder Microsoft 365 ohne Freigabefenster. Neue Versionen spielt dein Agent ab jetzt erst nach deinem Ja ein.
