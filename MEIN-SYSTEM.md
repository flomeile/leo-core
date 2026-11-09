---
titel: Mein System (persönliche Ebene)
zweck: Alles, was an diesem System dir gehört - Name, Pfad, eigene Regeln, eigene Bauten. Wird von Updates nie angefasst.
type: master-regeln
stand: 2026-11-09
---

# Mein System

Diese Datei gehört dir. **Ein Update des Grundgerüsts fasst sie nie an.** Alles, was du an diesem System persönlich einstellst, ergänzt oder anders haben willst, gehört hierher und nicht in die `AGENTS.md`.

Warum die Trennung: Die `AGENTS.md` und die Skills sind die Mechanik. Sie werden weiterentwickelt, und du kannst dir Verbesserungen jederzeit holen (Skill `leo-mechanik-update`). Das geht nur gefahrlos, solange deine eigenen Sachen nicht in denselben Dateien stehen. Steht deine Personalisierung hier, kann ein Update nichts von dir überschreiben.

**Für das LLM:** Lies diese Datei in jeder Session zusammen mit der `AGENTS.md`. Bei Widerspruch zwischen den beiden gilt, was hier steht. Diese Datei ist die Antwort auf die Frage, wer `[NAME]` ist und wie das System hier tatsächlich heisst.

---

## 1. Meine Werte

Diese Tabelle löst die Platzhalter auf, die in der `AGENTS.md` und in den Skills stehen. Fülle sie beim Einrichten einmal aus.

| Platzhalter | Bedeutung | Mein Wert |
|---|---|---|
| `[NAME]` | Die Person, der dieses Repo gehört | *(dein Name)* |
| Systemname | Wie das System heisst (im Gerüst durchgängig "Leo") | Leo |
| Skill-Präfix | Präfix der Skill-Dateien (im Gerüst `leo-`) | `leo-` |
| Repo-Pfad | Wo das Repo auf deinem Rechner liegt (im Gerüst `C:\Leo`) | `C:\Leo` |
| Kürzel | Dein Kürzel für das Feld `geprueft:` | *(z.B. deine Initialen)* |
| Arbeitssprache | Die Sprache, in der das System mit dir spricht (jede Antwort, jeder Bericht) | Deutsch |

**Wichtig:** Wenn du dein System umbenennst oder woanders ablegst, änderst du **nur diese Tabelle**, nicht die `AGENTS.md`. Dort stehen "Leo" und `C:\Leo` als generische Bezeichnung; das LLM liest hier nach, was bei dir tatsächlich gilt. Damit bleibt die `AGENTS.md` bei allen Nutzern identisch und ist gefahrlos aktualisierbar.

Die Dateinamen deiner Skills musst du beim Umbenennen allerdings selbst mitziehen, ebenso das Präfix in dieser Tabelle. Wer bei `leo-` bleibt, hat weniger Arbeit und verliert nichts.

---

## 2. Meine eigenen Regeln

Hier stehen deine Ergänzungen und Abweichungen zur `AGENTS.md`. Sie haben Vorrang. Schreibe sie hierher und nicht in die `AGENTS.md`, dann kann ein Update sie nicht anfassen.

Beispiele für das, was hierher gehört: eine Stilregel, die nur für dich gilt; ein Ablageort, den du anders handhabst; eine Regel, die du bewusst aussetzt; eine Konvention für deine Dateinamen. Zwei Beispiele aus echten Systemen auf diesem Kern, beide bewusst nicht im Kern, weil andere Besitzer das Gegenteil wollen: "Zahlen immer als Ziffern, auch kleine und am Satzanfang" (eine Stilregel) und "Jede Abschlussmeldung trägt sechs Pflichtangaben: Auftrag im Wortlaut, Zeitpunkte, Ausgeführtes, Ergebnis mit Zahlen, Belege, Offenes" (ein auditierbares Meldungsformat, das mit den Kürze-Regeln der `AGENTS.md`, Abschnitt 1 kollidiert und deshalb nur hier stehen kann).

*(Noch keine eigenen Regeln. Trag sie ein, sobald du welche hast.)*

---

## 3. Was ich selbst gebaut habe

> **Dieser Abschnitt und Abschnitt 4 werden mitgeführt, nicht umgebaut.** Der Skill `leo-mechanik-update` schreibt in beide: hier trägt er ein, welche Abweichungen an Kern-Dateien er bei dir gefunden hat, in Abschnitt 4 die eingespielte Version. Ergänze hier gerne, so viel du willst. Lösche aber nicht, was der Skill hinterlassen hat, und baue die Struktur nicht um. Beides liest er beim nächsten Update wieder, und was er nicht mehr findet, behandelt er als nicht vorhanden. Der Rest dieser Datei gehört dir allein, dort schreibt kein Update.

Die Liste dessen, was bei dir über das Grundgerüst hinausgeht. Sie hat einen konkreten Zweck: Beim Aktualisieren der Mechanik prüft das LLM, ob deine eigenen Bauten noch zur neuen Fassung passen. Ohne diese Liste müsste es raten.

**Eigene Skills:**

*(z.B. `leo-angebot-schreiben.md`, gebaut am ..., nutzt das Frontmatter-Schema aus AGENTS.md Abschnitt 5)*

**Eigene Themenordner:**

*(werden ohnehin über die Rollen-Tabelle in der AGENTS.md sichtbar, hier nur, was dazu erwähnenswert ist)*

**Eigene Änderungen an Kern-Dateien:**

Trage hier ein, wenn du doch einmal eine Kern-Datei angepasst hast (siehe `10_System\Kern-Dateien.md`). Das ist erlaubt, aber das Update muss davon wissen, sonst geht deine Änderung verloren oder blockiert das Update unnötig.

*(Noch keine.)*

---

## 4. Stand meines Grundgerüsts

> **Diese Tabelle führt der Update-Skill, nicht du.** Ändere weder die Zeilen noch die Spalten noch die Schreibweise, auch nicht kosmetisch, und schreib die Version nicht von Hand um. Die Zeile "Eingespielte Version" wird maschinell gelesen, vom Skill `leo-mechanik-update` und vom System-Health-Check. Passt das Format nicht mehr, findet keiner von beiden die Version: Das Update vergleicht dann gegen die falsche Ausgangslage und kann dir eigene Anpassungen überschreiben, und der Health-Check meldet nie wieder, dass eine neue Version bereitsteht. Stimmt der Wert hier nicht, sag es dem LLM, statt ihn selbst zu korrigieren; es trägt ihn richtig ein.

Welche Version des Grundgerüsts bei dir eingespielt ist. Der Skill `leo-mechanik-update` liest diesen Wert, um zu wissen, was sich seither geändert hat, und schreibt ihn danach fort.

| | |
|---|---|
| Eingespielte Version | 2.4 |
| Eingespielt am | *(Datum deiner Einrichtung)* |
| Quelle | https://github.com/flomeile/leo-core |

---

## 5. Mein Setup

Kurznotizen zu deiner Umgebung, damit das LLM nicht jedes Mal nachfragt. Was hier nicht steht, ist auch nicht schlimm.

- **Nutzungsmodus:** *(`mitbauen` oder `benutzen`. `mitbauen` heisst: Du löst Wartung selbst aus, mit Trigger-Worten wie "health check" und "wrap up". `benutzen` heisst: Du arbeitest nur inhaltlich mit dem System, und das LLM fährt fällige Wartung ungefragt selbst; die Regel dazu steht in der AGENTS.md, Abschnitt 1. Wenn du das hier liest und nicht weisst, was ein Trigger-Wort ist, bist du `benutzen`.)*
- **Git-Modus:** *(`alleinarbeiter` oder `zweige`. `alleinarbeiter` heisst: Du bist die einzige Person auf diesem Repo, alles wird direkt auf `main` committet und gepusht; das ist der Standard, und er gilt auch, wenn hier nichts steht. `zweige` heisst: Mehrere Personen schreiben auf dem Repo oder du willst jede Änderung vor dem Merge freigeben; dann gilt das Zweig-Modell aus der AGENTS.md, Abschnitt 12, der Agent arbeitet nur auf `feature`-Zweigen, und der Merge gehört dir.)*
- **Antwortstil bei Dateien:** *(`zusammenfassen` oder `nur nennen`. `zusammenfassen` heisst: Was der Agent in eine Datei geschrieben hat, fasst er in der Antwort zusammen, weil du im Chat arbeitest und Dateien selten öffnest. `nur nennen` heisst: Er nennt die Datei mit Pfad und einem Satz, was drin ist, und du öffnest sie selbst. Fehlt der Eintrag, gilt `zusammenfassen`; die Regel dazu steht in der AGENTS.md, Abschnitt 1, "Kurz und prüfbar".)*
- **Werkzeug:** *(z.B. Claude Code auf dem eigenen Rechner, oder ein Chat-Harness mit Dateizugriff)*
- **Fernsicherung:** *(privates GitHub-Repo? nur lokal? Wenn nur lokal: es gibt kein Netz unter dir, siehe ANLEITUNG Teil 5)*
- **Automatik:** *(läuft der tägliche Index-Sync als geplante Aufgabe? Hook aktiv?)*
- **Ordner ausserhalb des Repos:** *(stehen nicht hier. Ab Werk sieht dein Agent nur dein Repo, `<Repo> Archiv`, `<Repo> Artifacts` und sein Scratchpad; was du ihm darüber hinaus öffnest, steht in `00_INDEX\freigegebene-pfade.txt`, und freigeben kannst nur du, mit `00_INDEX\scripts\freigeben.ps1` in deinem eigenen PowerShell-Fenster. Erklärung: ANLEITUNG Teil 5, Schritt 7c.)*
- **Besonderheiten:** *(alles, was bei dir anders ist als in der Anleitung beschrieben)*
