---
name: leo-wrap-up
trigger: '"wrap up", "session speichern", "zusammenfassen und ablegen", "session beenden", "log this"'
zweck: Session zusammenfassen, ablegen, Lernschleife (Dauerwissen ins Repo zurückschreiben, notfalls neue Wissensdateien anlegen, sofort indexieren), Index leichtgewichtig aktuell halten, vollen System-Health-Check nur bei Bedarf anstossen
type: skill
version: 1.3
---

# Skill: Leo Wrap-Up

Fasst die aktuelle Session ausführlich zusammen und legt sie in `03_Sessionlogs` ab. Hält danach den Index leichtgewichtig aktuell und sichert per Commit + Push, ruft den vollen System-Health-Check aber nur dann auf, wenn er wirklich nötig ist (siehe Schritt 5). Voraussetzung: Datei-Schreibzugriff plus PowerShell (oder native Git-Fähigkeit des Harness).

## Wann ausführen
- Wenn ein Trigger-Wort genannt wird.
- Nach substanzieller Arbeit darf proaktiv angeboten werden: "Soll ich die Session für das Gedächtnis ablegen?"
- NICHT bei trivialen Kurz-Chats ohne Substanz.

## Schritte

### 1. Zeit holen (nie raten)
```powershell
Get-Date -Format "yyyy-MM-dd HH:mm"
```
Für Frontmatter, Dateiname und Header verwenden.

### 2. Zusammenfassung erstellen
Alle Entscheidungen, spezifisch, echte Formulierungen zitieren, so ausführlich, dass eine neue Session nahtlos anschliessen kann. Ein Log ist eine Zustandsaufnahme, keine Chronik: nicht was in welcher Reihenfolge passierte, sondern wo es steht. Beim Durchgehen der Session gezielt mitnehmen (sonst geht es verloren):
- **Sackgassen:** verworfene Ansätze und warum. Das Wertvollste und meist Vergessene, es verhindert, dass die nächste Session denselben Weg nochmal geht.
- **Korrekturen:** jedes "kürzer", "nicht dieser Ton", "Termin ist Freitag, nicht Montag". Einmal bezahlt, nie wieder bezahlen.
- **Einmal genannte Randbedingungen:** eine Vorgabe aus der Mitte der Session gilt weiter, auch wenn sie nie wiederholt wurde. Aktualität ist nicht Wichtigkeit.
- **Wörtliche Essentials:** Namen, Zahlen, Daten, exakt freigegebene Formulierungen. Die paraphrasiert man nicht.
```markdown
---
date: YYYY-MM-DD
time: HH:MM
topic: <eine Zeile>
context: <Themenbereich, z.B. System | Allgemein>
tags: [tag1, tag2, tag3]
type: session-summary
---

# Session — YYYY-MM-DD HH:MM

## Thema
<eine Zeile>

## Woran wir gearbeitet haben
- <konkrete Ergebnisse, berührte Dateien, Gründe für die Arbeit>

## Entscheidungen
- <echte Entscheidungen, keine Überlegungen>

## Erkenntnisse
- <Learnings, Signale>

## Offene Punkte / Nächste Schritte
- <was noch aussteht>
```

**Lernschleife (Pflichtteil dieses Schritts, Root-AGENTS.md Abschnitt 10):** Das Log allein ist Archiv; damit das System wirklich mitlernt, wird jede Korrektur und jede Erkenntnis aus der Session einer von drei Kategorien zugeordnet und die ersten beiden werden SOFORT zurückgeschrieben, nicht nur notiert:
1. **Dauerhaftes Verhalten** (Ton, Regel, Arbeitsweise, wiederkehrender Fehler): betroffenen Skill oder die zuständige AGENTS.md direkt nachziehen (Skill-Version hochzählen). **Dabei gilt die Trennlinie steuernd/begründend (Root-AGENTS.md, Abschnitt 10):** In die Root-AGENTS.md kommt nur der normative Satz mit Datum plus höchstens ein Halbsatz Anlass; die Erzählung dahinter gehört in die Begleitdatei `10_System\Detailregeln aus AGENTS.md.md`. Eine Regel samt Langgeschichte in die Root-Datei zu schreiben, macht den in jeder Session geladenen Kern wieder fett; genau das misst der Health-Check (Kategorie `Lean`). Änderungen an `01_Basiskontext` nur mit expliziter Bestätigung plus Changelog.
2. **Wissen mit Dauerwert** (Entscheidung, Fakt, Status): zuständige Wissensdatei im Themenordner fortschreiben (`stand:` aktualisieren), nicht nur ins Log. Dabei gilt:
   - **`geprueft: <Kürzel> <heute>` setzen, wo der Repo-Besitzer den Inhalt in dieser Session bestätigt hat** (Root-`AGENTS.md`, Abschnitt 6). Das ist der eine Ort im System, an dem das Feld regulär entsteht: Der Wrap-Up ist die einzige Stelle, die weiss, was in der Session wirklich gesagt und bestätigt wurde. Bestätigt heisst: Der Inhalt wurde gesehen und ihm wurde zugestimmt, nicht nur der Auftrag gegeben, ihn zu schreiben. Im Zweifel nicht setzen; ein fehlendes Feld ist harmlos, ein falsches behauptet eine Prüfung, die nie stattgefunden hat.
   - **Eigene Schlüsse im Satz markieren, bevor sie in eine Wissensdatei gelangen** (Root-`AGENTS.md`, Abschnitt 6). Der Wrap-Up ist der Übergang, an dem aus einer Überlegung des Modells eine Zeile im Gedächtnis wird, und danach ist die Grenze nicht mehr sichtbar. Für jede Aussage, die zurückgeschrieben wird, deshalb zuerst die Herkunftsfrage beantworten: Stammt sie vom Repo-Besitzer, aus einer benannten Quelle, oder ist sie die eigene Ableitung des Modells? Nur die ersten beiden werden als Aussage geschrieben. Die dritte bekommt die Markierung im Satz selbst ("Einordnung (nicht aus der Quelle): ...", "Ableitung: ...", "Vermutung, unbestätigt: ..."), nie ein eigenes Frontmatter-Feld und nie eine Fussnote am Dateiende. Im Zweifel markieren: Eine überflüssige Markierung kostet vier Wörter, eine fehlende macht eine Vermutung drei Sessions später zur zitierten Beschlusslage.
   - **Statustoken beim Anfassen von Agenda-Dokumenten nachziehen** (`offen`, `laufend`, `blockiert`, `erledigt`, `verworfen`, `historisch`; Root-`AGENTS.md` Abschnitt 7). `erledigt` nur mit Beleg im selben Satz. Nicht auf Vorrat umstellen, nur die Dokumente, die in dieser Session ohnehin bearbeitet werden.
   - **Fehlt eine passende Wissensdatei, wird sie ANGELEGT** (thematisch richtiger Ordner, sprechender Name nach Ablageregeln). Dauerwissen bleibt nie nur im Log. Nur wenn die thematische Zuordnung wirklich unklar ist, kurz nachfragen. Für jede so angelegte Datei gilt der volle Standard aus Root-`AGENTS.md` Abschnitt 5: Frontmatter mit `titel`, `zweck`, `type` aus der geschlossenen Liste, dazu `stand:` bei veränderlichem Inhalt, und Querverweise mit Begründung in beide Richtungen, wo eine belegbare Beziehung besteht. Eine neu angelegte Wissensdatei ohne Anknüpfung wird von der nächsten Session nur per Zufallstreffer gefunden.
   - **Fortschreiben heisst ersetzen, nicht anhängen:** Revidierte Entscheidungen und überholte Aussagen werden in der Wissensdatei überschrieben bzw. entfernt, so dass die Datei widerspruchsfrei nur den letzten Stand trägt. Die Freigabe dafür ist die Session selbst: Stammt die neue Information in dieser Session vom Repo-Besitzer, braucht das Überschreiben der überholten Passage keine separate Rückfrage (Root-AGENTS.md Abschnitt 12); die alte Fassung bleibt über Git und Log erhalten. Ganze Dateien löschen sowie alles in `01_Basiskontext` brauchen weiterhin die explizite Bestätigung.
   - **Verlaufswert vor dem Ersetzen prüfen:** Hat der alte Stand eigenen Wissenswert als Historie (z.B. ausgeschlossene Verdachtsdiagnosen, Roadmap-Verschiebungen, Preisentwicklungen, Strategiewechsel), bleibt er als datierte Verlaufszeile in der Datei stehen, klar als überholt gekennzeichnet. Ersatzlos entfernt wird nur, was als Historie nichts erklärt. Im Zweifel behalten und kennzeichnen.
   - **Konsistenz-Suche bei überholten Fakten (Pflicht):** Ein Fakt lebt oft in mehreren kuratierten Dateien. Für jeden überholten Fakt deshalb eine Synonym-Volltextsuche (Grep: Name, Begriff, Synonyme) über das Repo ausser `03_Sessionlogs` und `04_Changelog` laufen lassen und ALLE Fundstellen nachziehen: Wissensdateien und lokale AGENTS.md direkt, Fundstellen in `01_Basiskontext` per aktivem Vorschlag, Auto-Blöcke nie anfassen. Erst wenn keine kuratierte Datei den alten Stand mehr als aktuell ausgibt, ist der Fakt sauber fortgeschrieben.
   - **Neues über den Repo-Besitzer selbst** (Identität, Persönlichkeit/Muster, Stil, Ziele): passende Änderung an `01_Basiskontext` aktiv vorschlagen, nach Bestätigung sofort umsetzen plus Changelog-Eintrag. Nicht stillschweigend weglassen. Den Vorschlag im Chat stellen, BEVOR der Wrap-Up abschliesst; bleibt er unbeantwortet, im Log unter "Offene Punkte" explizit festhalten.
3. **Nur situativ:** bleibt allein im Log.

Im Log unter "Erkenntnisse" kurz vermerken, was wohin zurückgeschrieben wurde.

**Auffindbarkeit sichern:** Jede in dieser Session neu angelegte oder inhaltlich wesentlich geänderte Wissensdatei bekommt noch im selben Wrap-Up ihre kuratierte Beschreibung in der lokalen `_INDEX.md` des Themenordners (Systemdateien in der Root-`INDEX.md`). Grund: Die Agent-Search findet neues Wissen thematisch nur zuverlässig, wenn die Beschreibung sofort existiert.

### 3. Zielordner und Dateiname bestimmen
- Thematischer Unterordner in `03_Sessionlogs` je nach context (z.B. `03_Sessionlogs\System`). Wenn unklar, nachfragen. Wenn der Unterordner fehlt, anlegen.
- Dateiname: `YYYY-MM-DD-HHmm-<slug>.md`, slug = 2-4 Wörter aus dem Thema, kleingeschrieben, mit Bindestrichen, keine Sonderzeichen.
- Existiert heute schon eine Datei mit gleichem Slug: mit `---`-Trenner anhängen.

### 4. Ablegen (UTF-8)
Mit dem Schreibwerkzeug des Harness speichern (Chat-Harness: Filesystem-Tool oder `Set-Content -Encoding UTF8`).

### 5. Health-Check-Bedarf prüfen
Lies `10_System\health-check-last-run.txt` (falls vorhanden, ein Zeitstempel `yyyy-MM-dd HH:mm`). Der volle Health Check ist nötig, wenn **mindestens eine** Bedingung zutrifft:
- Datei fehlt, oder ihr Zeitstempel ist länger als 72 Stunden her (der volle Check mit LLM-Nacharbeit ist die Wochen-, nicht die Tageshygiene; die Index-Mechanik läuft ohnehin automatisch, und Pfad 6b deckt die Deltas jeder Session ab).
- Diese Session hat strukturell etwas verändert: Skill-Dateien angelegt/umbenannt/gelöscht, ein neuer Themenordner, Dateien zwischen Ordnern verschoben, oder Änderungen an Skripten in `00_INDEX\scripts`.

Trifft eine der beiden zu: weiter mit Schritt 6a. Trifft keine zu: weiter mit Schritt 6b.

### 6a. Voller Health-Check
Führe den Skill `02_Skills\leo-system-health-check.md` aus. Der erledigt: Index-Mechanik + Delta-Beschreibungen für neue/geänderte Dateien, `stand:`-Daten, Inbox-Befund, Aktualisierung von `10_System\health-check-last-run.txt`, Commit + Push. Commit-Message dabei: `Wrap-Up: <Thema>`.

### 6b. Leichtes Update (kein voller Health-Check nötig)
Nur das Nötigste, ohne volle Diagnose:
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Leo\00_INDEX\scripts\build-index-geruest.ps1"
```
`stand:` der in dieser Session bearbeiteten Dateien auf das heutige Datum setzen, falls noch nicht geschehen. Kuratierte Beschreibungen für neu angelegte oder wesentlich geänderte Wissensdateien in der zuständigen `_INDEX.md` ergänzen (nur Delta). Dann committen und pushen:
```powershell
cd C:\Leo
git status                       # zuerst lesen: was ist offen, und was davon ist wirklich meins?
git add "<pfad1>" "<pfad2>"      # NUR die in dieser Session bearbeiteten Dateien, nie -A
git commit -m "Wrap-Up: <Thema>"
git pull --rebase
git push
```

**Die mechanischen Indexdateien gehören in denselben Commit.** Das Index-Skript oben ändert alle `_INDEX.md` sowie `00_INDEX\INDEX.md` und `00_INDEX\INDEX-Geruest.md`, auch in Themenordnern, die du inhaltlich nicht angefasst hast. Diese Änderungen sind Ergebnis deines eigenen Laufs und werden mitgestaged, per Pfad wie alles andere; das Verbot betrifft `git add -A`, nicht das Stagen von Skript-Output. Wer sie liegen lässt, läuft in `error: cannot pull with rebase: You have unstaged changes`. Fremde Änderungen, die nicht aus deinem Lauf stammen, bleiben liegen und werden im Bericht erwähnt.

### 7. Bestätigen
Bei 6a: "Abgelegt in 03_Sessionlogs\<Unterordner>\<Dateiname>. Voller System-Check gelaufen, Index aktualisiert, committet und gepusht."
Bei 6b: "Abgelegt in 03_Sessionlogs\<Unterordner>\<Dateiname>. Leichtes Update (Index + Commit/Push), voller Health-Check war nicht nötig."

## Regeln
- Nur substanzielle Sessions.
- 3-6 Tags (treiben die Volltextsuche).
- UTF-8 immer.
- Deterministischer Slug, keine Duplikate.
- Die Lernschleife ist Pflicht, kein Angebot: Dauerwissen wird zurückgeschrieben (bestehende Datei fortschreiben oder neue anlegen). Vorschlagen plus Bestätigung gilt nur für `01_Basiskontext` und fürs Löschen ganzer Dateien.
- Im Zweifel (unsicher, ob eine Änderung "strukturell" war): lieber Schritt 6a wählen als 6b.

## Definition of Done
- [ ] Zeitstempel per Werkzeug geholt, nicht geraten
- [ ] `geprueft:` in den Dateien gesetzt, deren Inhalt der Repo-Besitzer in dieser Session bestätigt hat; im Zweifel nicht gesetzt
- [ ] Herkunft jeder zurückgeschriebenen Aussage geklärt: was aus der Session eigene Ableitung des Modells ist, steht im Satz markiert und nicht als Tatsache
- [ ] Log enthält Sackgassen, Korrekturen, einmal genannte Randbedingungen und wörtliche Essentials, soweit in der Session vorhanden
- [ ] Lernschleife gelaufen: jede Korrektur/Erkenntnis kategorisiert; dauerhaftes Verhalten in Skill/AGENTS.md, Dauerwissen in Wissensdateien zurückgeschrieben (fehlende Zieldatei angelegt, Überholtes ersetzt, Verlaufswert geprüft), im Log vermerkt
- [ ] Konsistenz-Suche für jeden überholten Fakt gelaufen
- [ ] Neu angelegte oder wesentlich geänderte Wissensdateien haben ihre kuratierte Beschreibung im zuständigen Index
- [ ] Datei liegt im passenden Unterordner von `03_Sessionlogs` mit normgerechtem Namen (UTF-8)
- [ ] Health-Check-Entscheid (6a oder 6b) getroffen
- [ ] Committet und gepusht, oder der Konflikt ist gemeldet
- [ ] Bestätigung nennt Ablagepfad und welcher Pfad (6a/6b) gelaufen ist
