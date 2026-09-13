---
name: leo-system-optimierung
trigger: '"system-optimierung", "system optimieren", "optimierungslauf", "pruefset fahren", "prüfset fahren", "messlauf", "regeltreue messen"'
zweck: Misst mit kalten Prüfset-Läufen, ob das System seine eigenen Regeln einhält, leitet aus Durchfallern gezielte Regel- oder Mechanik-Fixes ab und misst nach; Rollback bei sinkender Quote
type: skill
version: 2
---

# Skill: Leo System-Optimierung

Der wiederholbare Optimierungszyklus des Systems: Prüfset kalt fahren, Belege protokollieren, aus Durchfallern die richtige Sorte Fix ableiten, umbauen, nachmessen. Der Kern der Idee: Die Qualität eines Regelwerks wird gemessen, nicht behauptet, und zwar mit kalten Läufen, die nichts vom Gedächtnis der bauenden Session wissen. Voraussetzungen: eine Agent-CLI, die sich nicht-interaktiv aufrufen lässt (z.B. `claude -p`), PowerShell, Schreibzugriff aufs Repo.

**Beim ersten Lauf:** Es gibt noch kein Prüfset. Kopiere `10_System\Pruefset-Vorlage.md` im selben Ordner zur neuen Datei Pruefset.md und fülle die gekennzeichneten Platzhalter mit echten Fällen aus dem eigenen Repo (ein realer Fakt mit genau einer Fundstelle, eine echte Namens-Mehrdeutigkeit, ein realer Archiv-Wortlaut). Die generischen Fälle funktionieren unverändert.

## Wann ausführen

- Vor und nach jeder Kernänderung an Root-AGENTS.md, Basiskontext, Guard-Hook oder Skill-Mechanik: erst Ausgangswert, dann Umbau, dann Nachmessung. Sinkt die Quote, wird der Umbau zurückgerollt, nicht nachverhandelt.
- Als Stichprobe, wenn seit dem letzten Lauf mehr als 42 Tage vergangen sind.
- **Die Erinnerung ist mechanisiert:** Der System-Health-Check (Kategorie `Lean`, Messlauf-Wächter) warnt, wenn eine Kernänderung nach dem letzten protokollierten Messlauf liegt oder der letzte Lauf älter als 42 Tage ist. Der Lauf selbst startet bewusst, weil er je Fall eine kalte Session kostet.
- NICHT nach gewöhnlichen Wissens- oder Inhaltsänderungen. Über-Nutzung ist der teurere Fehler: Sie verbrennt Kontingent für unveränderte Regeln.

## Schritte

### 1. Frischecheck und Checkpoint
`git fetch origin`, `git status -sb`, `git log -1`. Bei `behind`/`diverged`: stoppen und fragen. Offene eigene Arbeit als Checkpoint committen (nur eigene Pfade), damit der Rollback jederzeit möglich ist.

### 2. Prüfset kalt fahren
Fälle und Messmechanik stehen in deinem Prüfset (Datei Pruefset.md in `10_System`). Jeder Fall ist ein eigener kalter Lauf:

```powershell
claude -p '<Eingabe im Wortlaut>' --permission-mode acceptEdits --output-format stream-json --verbose 2>&1 | Out-File "<scratchpad>\fall.jsonl" -Encoding utf8
```

Messhygiene (in der Prüfset-Datei gepflegt): Fantasienamen je Lauf wechseln, weil der Prüfling die Prüfset-Datei per Volltextsuche finden kann; Prompts mit Pfaden ausserhalb des Repos über eine Scratchpad-Datei übergeben (der eigene Guard-Hook blockiert sie sonst im Kommandotext); Fälle, die das Archiv lesen, mit `--add-dir`.

### 3. Je Fall am Beleg urteilen, sofort protokollieren
Bestanden oder durchgefallen entscheidet der Beleg (Antworttext, Werkzeug-Log aus dem JSONL, Dateizustand danach), nie die eigene Erwartung; Grenzfälle zulasten des Systems, mit Begründung. Ergebnis nach JEDEM Fall in die Lauf-Tabelle der Prüfset-Datei schreiben (Unterbrechungsresistenz), Testartefakte desselben Falls sofort zurückbauen, **aber eng** (seit 3.3): nur die Pfade, die der Prüffall selbst benennt oder die im Werkzeug-Log des Laufs als vom Lauf geschrieben stehen; einen Test-Commit per `git reset --soft` nur auf den Hash, den der Lauf selbst erzeugt hat, nie auf "den Stand vor dem Lauf"; und `git checkout --` nie pauschal auf alles, was `git status` zeigt. Auf dem Repo arbeitet oft eine andere Session parallel, und ein pauschaler Rückbau verwirft deren offene Änderungen, ohne dass es jemand merkt. Was nach dem engen Rückbau noch offen ist, wird als fremd gemeldet und liegen gelassen.

### 4. Learnings in den richtigen Fix übersetzen
Für jeden Durchfaller die Wurzel bestimmen, denn sie entscheidet die Fix-Sorte:

- **Regel zu weich gegen einen konkreten Druck** (z.B. eine explizite Nutzerangabe überfährt sie): Regel in der AGENTS.md härten, als normativer Satz mit Datum.
- **Regel strenger als je gelebt:** prüfen, ob die Regel falsch zugeschnitten ist, und sie präzisieren, statt den Verstoss nur zu beklagen.
- **Textregel zweimal wirkungslos:** mechanisches Netz bauen (Health-Check-Prüfung, Hook), nicht dieselbe Regel ein drittes Mal umformulieren.
- **Einmaliger Ausrutscher ohne Muster:** protokollieren, nichts umbauen (kleinster Eingriff).

Jeder Fix folgt der Trennlinie steuernd/begründend (Root-AGENTS.md, Abschnitt 10): Normatives in die AGENTS.md, die Erzählung in `10_System\Detailregeln aus AGENTS.md.md`. Basiskontext-Änderungen nur mit expliziter Bestätigung plus Changelog. Regeln werden nie gelöscht oder verwässert, um Tokens zu sparen.

### 5. Nachmessen, proportional
Nach gezielten Fixes: Delta-Lauf nur über die betroffenen Fälle. Nach einem umfangreichen Umbau: volles Set erneut, und die Iteration wiederholt sich, bis die Quote hält. Sinkt die Quote gegenüber dem Ausgangswert, wird der Umbau zurückgerollt (Checkpoint aus Schritt 1).

### 6. Lean-Stand erheben
`pwsh -NoProfile -ExecutionPolicy Bypass -File "00_INDEX\scripts\health-check.ps1"` (im Repo-Root), Kategorie `Lean` ansehen. Bei WARN: Erzählungen nach der Trennlinie auslagern. Feste Schwellen gibt es nicht: Der Check misst AGENTS.md und Pflichtkontext gegen die eigene letzte Referenzgrösse in `00_INDEX\lean-baseline.txt`, meldet sich bei jedem Wachstumsschritt von 15 Prozent einmal und schreibt die Referenz danach selbst fort. Nach einem erfolgreichen Optimierungslauf sinkt sie beim nächsten Lauf von selbst auf den kleineren Stand; von Hand ist nichts nachzuführen.

### 6a. Modellstand des Systems prüfen (seit 3.3)
Ein System veraltet, wenn die Welt sich weiterdreht und niemand nachsieht. Drei Prüfungen, jede mit Beleg:

1. **Was das System fest eingetragen hat.** `10_System\Modellwahl.md` lesen (dort `gueltig_bis`), dazu per Grep prüfen, ob ein Skript oder eine Konfiguration ein Modell an der Modellwahl vorbei fest einträgt (`grep -rn "claude-[a-z]*-[0-9]" 00_INDEX/scripts .claude`); jede zweite Fundstelle für dieselbe Information wird auf einen Ort zusammengezogen (eine Information hat genau einen Ort, `AGENTS.md` Abschnitt 5).
2. **Was der Anbieter heute hat.** Per Websuche die Modellübersicht und die Abkündigungsliste des Anbieters lesen und gegen den Eintrag halten: Gibt es ein neueres Modell derselben Klasse, ist das eingetragene abgekündigt oder mit Enddatum versehen, hat sich der Preis geändert (dann die Preistabelle in `00_INDEX\scripts\session-kosten.py` nachführen)? Die installierte CLI gegen die aktuelle Version prüft der Health-Check selbst (Kategorie `CLI`).
3. **Der Befund, immer ausdrücklich.** "Geprüft am <Datum>, aktuell" ist ein Ergebnis und wird in `Modellwahl.md` mit Datum nachgeführt. Gibt es Neueres oder eine Abkündigung: nicht selbst umstellen, sondern als offenen Punkt mit Wiedervorlage verankern (Skill `leo-notiz`), mit Preis, Erscheinungsdatum, Quelle und dem einen Handgriff für den Wechsel. Ein Modellwechsel ändert Preis, Berechtigungen und Verhalten und bleibt die Entscheidung von `[NAME]`.

### 6b. Token-Verbrauch analysieren (seit 3.3)
Grundlage ist der Bericht, der bei jedem Health-Check aus `00_INDEX\scripts\session-kosten.py` entsteht: `00_INDEX\session-kosten.md` (Verbrauch aller lokalen Transkripte des Werkzeugs der letzten 14 Tage zu API-Listenpreisen; längerer Zeitraum mit `--tage 30`, das Skript direkt aufgerufen). Der Health-Check meldet nur die Ausreisser (Session über 200 Aufrufe, Tag über der Kostenschwelle); dieser Schritt liest das Muster dahinter. Vier Fragen, jede mit Zahl und Beispiel beantwortet, keine davon mit "unauffällig" ohne Beleg:

1. **Rohmaterial.** Welche Dateiarten kamen im Zeitraum in `90_Inbox` und ins Belegarchiv, und welche davon wurden ungefiltert in den Kontext gelesen statt vorher per Skript eingedampft (Auszug statt Ganzes, Markup und Kopfzeilen entfernt)? Ergebnis: je Dateiart der Weg, der ab jetzt gilt, und wo ein Skript fehlt. `[NAME]` bereitet nichts vor; jede Eindampfung ist Arbeit des Systems (`AGENTS.md`, Abschnitt 1).
2. **Sessions ausserhalb des Systems.** Welche Sessions (Titel und Kosten in der Tabelle) hätten ohne den Pflichtkontext auskommen können: reine Websuche, Übersetzung, Zusammenfassung eines fremden Textes ohne Bezug zu den eigenen Dateien? Jede Session in diesem Repo lädt den ganzen Pflichtkontext je Aufruf. Ergebnis: eine Liste mit Empfehlung je Typ ("Chat ohne dieses Repo", "Agent in einem leeren Ordner", "bleibt hier, weil ...").
3. **Modell und Effort.** Spalte "Modell / Effort" gegen `10_System\Modellwahl.md` halten: Wo lief das teuerste Modell oder ein hoher Effort für mechanische Arbeit (Index, Skripte, Formatierung), wo ein grosses Modell für eine einfache Wissensfrage? Ergebnis: die drei teuersten Fehlbesetzungen mit dem Betrag, der beim passenden Modell angefallen wäre.
4. **Bündelungsregel.** Aufrufe je Session und Kontext je Aufruf (Spalten im Bericht) sowie die Zahl der Kaltstarts. Sinkt die Zahl der Aufrufe je Session bei vergleichbarer Arbeit? Wenn nicht: zwei Sessions stichprobenartig im Transkript ansehen (`<Benutzerordner>\.claude\projects\<Projektordner>\<id>.jsonl`), die Ketten benennen (vier und mehr aufeinanderfolgende Einzelaufrufe wie Read, Grep, Glob oder Bash mit `sed -n` auf dieselben Dateien) und den Wortlaut der Regel schärfen oder einen Prüffall anlegen. Eine Kennzahl dafür gibt es bewusst nicht: Eine Quote "Werkzeuge je Aufruf" sieht die Bündelung in ein Skript nicht (ein Skript mit zehn Schritten ist ein Werkzeug in einem Aufruf). Messhinweis: Ein Transkript trägt je Inhaltsblock eine eigene Zeile mit derselben `message.id`; wer nach Id entdoppelt, statt die Blöcke einer Id zusammenzuführen, verliert Werkzeugaufrufe.

Ergebnis des Schritts: ein Abschnitt "Token-Verbrauch" im Bericht mit den drei grössten Hebeln als entscheidungsreifer Zug (Datei, Änderung, erwartete Ersparnis). Was `[NAME]` entscheidet, wird im selben Zug in Skill, `AGENTS.md` oder Modellwahl geschrieben.

**Bündelung des Laufs selbst** (seit 3.3): Die kalten Fälle laufen parallel als PowerShell-Jobs aus einem Skript, die JSONL-Auswertung und die Analysen aus 6b je als ein Skript. Ein Lauf nacheinander kostet dieselben Tokens und ein Vielfaches der Zeit.

### 7. Abschliessen
Prüfset-Datei: Ergebnis als Zahl, Lauf-Datum, `stand:` aktualisieren. Eigene Pfade committen und pushen. Bericht: Quote vorher/nachher, jeder Durchfaller mit Wurzel und Fix, Lean-Stand in KB.

## Regeln

- Anti-Halluzination verschärft: Ein Fall gilt nur als gelaufen, wenn sein JSONL existiert; ein Urteil nennt immer den Beleg. Nie ein Ergebnis aus dem Gedächtnis der bauenden Session ableiten, die Läufe sind bewusst kalt.
- Kein Testartefakt überlebt den Lauf: Was ein Prüffall im Repo, im Archiv, im Memory-Pfad oder ausserhalb hinterlässt, wird noch im selben Schritt zurückgebaut und der Rückbau im Beleg vermerkt.
- Der Guard-Hook und seine Ausnahmeliste werden für keinen Prüffall angefasst; blockiert er die Messung selbst, wird der Prompt per Datei übergeben, nie die Sperre gelockert.
- Dieser Skill ändert Regeln, deshalb doppelt: Jede AGENTS.md-Änderung trägt Datum und Anlass, und die Nachmessung gehört zum selben Auftrag, nicht in eine spätere Session.

## Definition of Done

- [ ] Jeder gefahrene Fall hat ein JSONL im Scratchpad und eine Belegzeile in der Prüfset-Datei
- [ ] Ausgangswert und Nachmessung stehen als Zahlen im Prüfset, `stand:` aktualisiert
- [ ] Jeder Durchfaller hat eine benannte Wurzel und entweder einen umgesetzten Fix (mit Delta-Nachmessung) oder den begründeten Entscheid, nichts zu ändern
- [ ] Kein Testartefakt mehr im Repo oder ausserhalb (`git status` sauber bis auf eigene Arbeit)
- [ ] Health-Check-Kategorie `Lean` ist OK oder ihr WARN hat einen konkreten nächsten Zug
- [ ] Modellstand geprüft (Schritt 6a): Modellwahl gegen die Anbieterliste gehalten, Prüfdatum nachgeführt, bei Neuerem ein offener Punkt mit Wiedervorlage
- [ ] Token-Verbrauch analysiert (Schritt 6b): die drei grössten Hebel stehen als entscheidungsreifer Zug im Bericht
- [ ] Eigene Pfade committet und gepusht; Quote vorher/nachher berichtet
