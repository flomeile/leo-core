---
name: leo-voice-check
trigger: '"voice check", "voice-check", "schleif das", "schleifen", "stil check", "stilcheck"'
zweck: Einen fertigen, ausgehenden Text (Mail, Präsentation, Post, Brief, Angebot) vor dem Versand gegen die eigene Voice-Datei prüfen und KI-Tells selbst korrigieren, statt dass der Besitzer sie von Hand nachbessert
type: skill
version: 1.0
---

# Skill: Leo Voice-Check

Der Kontroll-Skill für ausgehende Texte. `[NAME]` will Output, der sofort nach ihm klingt, und nicht jede zweite Mail nachbessern müssen. Dieser Skill ist die letzte Instanz vor dem Versand: Er nimmt einen Entwurf, prüft ihn mechanisch-diszipliniert gegen die eigene Stil-Datei und die generischen KI-Tells und gibt die bereinigte Fassung zurück.

Voraussetzung: eine gefüllte `01_Basiskontext\Voice and Style.md`. Ist sie noch die leere Vorlage, prüft der Skill nur gegen die generische KI-Tell-Liste darin und sagt das dazu.

## Wann ausführen
- Wenn `[NAME]` ein Trigger-Wort nennt, mit einem Entwurf (im Chat eingefügt oder als Datei) oder mit Bezug auf den zuletzt erzeugten Text.
- **Von selbst, ohne Trigger-Wort**, sobald in der Session ein ausgehender Text entsteht oder überarbeitet wird (Kurzliste in der `AGENTS.md`, Abschnitt 11: formt vorhandene Arbeit, also selbst ausführen; im ersten Satz sagen, dass der Check lief).
- NICHT für interne Repo-Dateien: System-Doku und Quelldokumente prüft der Skill nicht. Er prüft nur, was nach aussen geht.

## Grundlage lesen
Zuerst `01_Basiskontext\Voice and Style.md` vollständig lesen (die verbindliche Quelle; dort stehen die persönlichen Regeln des Besitzers UND die generische KI-Tell-Liste). Die folgende Liste ist die mechanische Kurzform der häufigsten Verstösse, nicht ihr Ersatz.

## Prüfpunkte (jeden einzeln durchgehen)
1. **Persönliche Stilregeln des Besitzers:** alles, was in Teil 2 seiner Voice-Datei steht (Satzzeichen-Vorlieben, verbotene Wörter, Orthografie-Vorgaben, Sprachvarianten). Diese Regeln schlagen jede generische Empfehlung.
2. **KI-Floskeln:** Wendungen wie "es ist wichtig zu beachten", "im heutigen schnelllebigen", "lass uns eintauchen", aufgeplusterte Übergänge. Streichen oder in den direkten Ton des Besitzers umschreiben.
3. **Pauschalaussagen:** Unbelegte Verallgemeinerungen ("alle", "immer", "jeder weiss") konkretisieren oder streichen.
4. **Reframe-Falle (negative Parallelität):** Keine "nicht X, sondern Y"-Konstruktion (auch ohne "nicht": "Vergiss X, hier ist Y", "Weniger X, mehr Y", rhetorische Frage-Reframes). Positive Aussage direkt hinschreiben. Kontrast nur zur Korrektur eines konkreten Fehlers.
5. **Verb-Aufblähung:** "dient als / stellt dar / fungiert als / spielt eine Rolle bei" durch schlichtes "ist / hat / nutzt" ersetzen.
6. **Weitere Tells:** erzwungene Dreierlisten auflösen; elegante Variation (denselben Gegenstand umbenennen, nur um Wiederholung zu vermeiden) durch Namenswiederholung ersetzen; Schein-Tiefe-Partizipien ("unterstreicht die Bedeutung", "ebnet den Weg für") streichen; dekorative Metaphern entfernen (Begriffe, die für den Besitzer echte Bedeutung tragen, bleiben); tote Eröffnungen und Engagement-Bait ("In der heutigen Zeit", "Lass das sacken") streichen.
7. **Ton und Haltung:** gegen die Ton-Regeln der eigenen Voice-Datei prüfen. Dieser Punkt ist der einzige, den man an einem sprachlich einwandfreien Text übersieht, und oft der teuerste: Ein Entwurf kann jede Regel oben bestehen und trotzdem fordernd, anbiedernd oder nach Marketing klingen. Braucht ein Fall einen härteren Ton als sonst, wird das mit dem Besitzer abgesprochen, nie selbst gewählt.
8. **Verständlichkeit:** Jeder Satz sagt, was konkret passiert. Drei Fragen je Satz: Steht ein repo-interner Begriff ohne den Sachverhalt daneben? Steht eine Nominalisierung, wo eine Handlung gemeint ist? Steht ein Befund ohne das Beispiel, an dem er sichtbar wird? Müsste jemand den Satz zweimal lesen, wird er umgeschrieben. Kürzen heisst weniger Text, nicht dichter verpackter Text.

## Ausgabe
1. Die **bereinigte Fassung** des Textes, versandfertig.
2. Darunter eine kurze Liste **was geändert wurde** (stichwortartig), damit der Besitzer die Eingriffe sieht.
3. Wenn inhaltlich etwas unklar ist (nicht nur stilistisch), kurz nachfragen statt raten.

## Regeln
- Nur Stil und Orthografie glätten, den Inhalt und die Aussagen des Besitzers nie verändern.
- Wiederkehrende Fehlerarten sind ein Hinweis, die eigene Voice-Datei zu schärfen; den Besitzer kurz darauf hinweisen (Änderung an `01_Basiskontext` nur mit seiner Bestätigung).

## Definition of Done
- [ ] `01_Basiskontext\Voice and Style.md` in dieser Session vollständig gelesen
- [ ] Alle acht Prüfpunkte einzeln durchgegangen; Punkt 7 (Haltung) und Punkt 8 (Verständlichkeit) ausdrücklich auch bei sprachlich sauberen Entwürfen
- [ ] Bereinigte Fassung verletzt keine persönliche Stilregel aus der Voice-Datei und keinen der generischen Tells
- [ ] Inhalt und Aussagen unverändert, nur Stil und Orthografie angefasst
- [ ] Änderungsliste geliefert
