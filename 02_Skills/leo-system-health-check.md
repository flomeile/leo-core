---
name: leo-system-health-check
trigger: '"system health check", "health check", "system prüfen", "systemcheck", "ist alles gesund", "gesundheitscheck system", "alles aktuell", "system aktualisieren", "auf vordermann bringen", "index aktualisieren", "index neu bauen", "inbox aufraeumen", "ablage aufraeumen", "hygiene"'
zweck: One-Button-Wartung des Gesamtsystems - prüft alles, behebt sicher Behebbares selbst (Index-Beschreibungen, stand-Daten, Register), behandelt die Inbox, schreibt den Health-Check-Zeitstempel und schliesst mit Commit + Push ab
type: skill
version: 1.8
---

# Skill: System Health Check

Der EINE Wartungs-Skill des Systems. Prüft das gesamte Repo (Index-Mechanik, Beschreibungen, dynamische Dokumente, Git, Automatisierung, Skill-Registry, Inbox), behebt alles sicher Behebbare direkt und committet + pusht am Ende. Nach einem Lauf gilt: Indizes aktuell, Beschreibungen vollständig, dynamische Dokumente gekennzeichnet und frisch, Inbox behandelt, alles auf GitHub. Voraussetzung: Datei-Schreibzugriff plus PowerShell.

## Wann ausführen
- Wenn ein Trigger-Wort genannt wird oder Unsicherheit besteht, ob alles aktuell ist.
- Von `leo-wrap-up` aus, aber NICHT bei jedem Wrap-Up automatisch: nur wenn dessen Schritt 5 das verlangt (letzter Lauf > 24h, oder diese Session war strukturell). Sonst macht Wrap-Up ein leichtes Update ohne diesen Skill.
- Sinnvoll nach grösseren strukturellen Änderungen (neuer Themenordner, viele verschobene/gelöschte Dateien) oder nach Änderungen an Skripten/Skills.

## Schritte

### 1. Mechanik frisch machen
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Leo\00_INDEX\scripts\build-index-geruest.ps1"
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Leo\00_INDEX\scripts\build-skill-wrapper.ps1"
```
Das zweite Skript zieht die Skill-Zeiger in allen sechs Werkzeug-Pfaden gegen das Register nach (neue Skills bekommen einen, gelöschte verlieren ihn). Es ist rein mechanisch und schreibt nur in die Punkt-Verzeichnisse; Substanz liegt dort keine (`AGENTS.md`, Abschnitt 11a). Die Kategorie `Portabilitaet` der Diagnose prüft danach, ob alle Zeiger und alle Einstiegsdateien vollständig sind.

Beide Skripte laufen zuerst, damit die Diagnose den aktuellen Stand prüft. Falls eines einen Datei-Sperr-Fehler auf `INDEX.md` oder `AGENTS.md` meldet (z.B. weil der Scheduler-Task parallel läuft): kurz warten und nochmal ausführen. Nie den betroffenen Auto-Block von Hand nachtragen.

### 2. Diagnose
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Leo\00_INDEX\scripts\health-check.ps1"
```
Das Skript ist rein lesend und prüft deterministisch: Git/Versionierung (inkl. gesetztem `core.hooksPath` für den Pre-Commit-Hook), Scheduled Task, Auto-Block-Integrität, Themenordner-Registrierung, Index-Abdeckung (kuratierte Beschreibungen), Skill-Registry, Encoding, Inbox, Basiskontext, Portabilitätsdateien, Harness-Memory-Füllstand (meldet jeden Fund als Handlungsbedarf, **Herkunft** (zwei Prüfungen: Pfadverweise in Backticks müssen auf real existierende Dateien zeigen, auch die Belege im Archiv; und jede Wissensdatei muss ihren Status in sich tragen, per `geprueft:` oder als Vorschlagshinweis im Text), **Formatdisziplin** (Themenordner enthalten nur Markdown, alles andere gehört ins Archiv oder nach Artifacts), weil ein harness-eigener Memory-Speicher für Leo nicht zugelassen ist: Root-`AGENTS.md` Abschnitt 1), tote Verweise (Wikilinks und Markdown-Links auf `.md`-Dateien), den Frontmatter-Standard für neu angelegte Dateien (inklusive Umlautersatz-Prüfung der `titel:`- und `zweck:`-Werte; die Wortliste im Skript ist sprachspezifisch und bei einem nicht-deutschen Repo zu leeren oder zu ersetzen), **Lean** (Drift-Wächter über der Grösse der Root-AGENTS.md, Trennlinie steuernd/begründend aus Abschnitt 10; dazu der Messlauf-Wächter, der bei vorhandenem Prüfset (Datei Pruefset.md in `10_System`) warnt, wenn eine Kernänderung ohne Nachmessung vorliegt oder der letzte Messlauf älter als 42 Tage ist, und dann den Skill `leo-system-optimierung` vorschlägt) sowie den kompletten `stand:`-Workflow für dynamische Dokumente: (a) veraltete Stände (> 60 Tage, ausgenommen Dateien mit eigenem `gueltig_bis`), (b) nicht nachgeführte Stände, (c) fehlende Kennzeichnung, (d) abgelaufenes `gueltig_bis`. Jede Zeile trägt `[OK]`, `[INFO]`, `[WARN]` oder `[FAIL]`; am Ende steht ein VERDIKT (Exit Code 0/1/2).

### 3. Sicher Behebbares direkt beheben (nicht fragen, machen)
Für jeden Befund zuerst einordnen: bekannte, abgestimmte Ausnahme (im Bericht kennzeichnen, keine Aktion) oder echter Handlungsbedarf. Dann direkt beheben, was mechanisch sicher ist:

- **Fehlende kuratierte Index-Beschreibungen (Delta-Verfahren):** Arbeitsliste ist die Trefferliste der Diagnose-Kategorie `Index-Abdeckung`, sie nennt jede Datei ohne Beschreibung namentlich; das grosse `00_INDEX\INDEX-Geruest.md` wird dafür NICHT gelesen (der frühere Selbstvergleich las das komplette Gerüst und rechnete nach, was das Skript deterministisch schon geliefert hatte). Für jede gemeldete Datei: Datei lesen und beschreiben. Format: `- **Relativpfad** — Beschreibung`. Rein deskriptiv: worum es geht, welche Fragen die Datei beantwortet, welche Begriffe und Synonyme sie abdeckt. NUR beschreiben, was real in der Datei steht. Bestehende, unveränderte Beschreibungen nicht anfassen. Auto-Blöcke nie verändern. Hinweis: Die Root-`INDEX.md` enthält bei den Themenbereichen bewusst KEINE einzelnen Datei-Beschreibungen; die gehören ausschliesslich in die lokale `_INDEX.md`.
- **Fehlende `stand:`-Kennzeichnung:** Meldet der Check dynamisch klingende Dateien ohne `stand:`, die Datei kurz anlesen. Ist der Inhalt wirklich veränderlich (Aufgaben, Status, Plan, Verlauf): `stand: YYYY-MM-DD` ins Frontmatter ergänzen. Ist die Datei statisch: im Abschlussbericht zur Bestätigung vorschlagen, sie als Ausnahme in `health-check.ps1` zu führen.
- **`stand:` in dieser Session bearbeiteter Dateien:** auf das echte Tagesdatum aktualisieren, falls versäumt.
- **Gemeldeter `stand:`-Drift:** Datei kurz anlesen; war die Änderung inhaltlich, `stand:` auf das Datum der letzten Git-Änderung setzen. War sie inhaltsneutral (Linkziel repariert, Metadaten, Umlaut-Korrektur), bleibt `stand:` unangetastet, denn es bedeutet das Datum der letzten inhaltlichen Änderung oder Prüfung (AGENTS.md, Abschnitt 7); stattdessen den Commit-Hash in `00_INDEX\drift-ausnahmen.txt` eintragen, damit die Warnung verschwindet, ohne dass die Datei eine Prüfung behauptet, die nie stattfand (präzisiert 30.08.2026).
- **Register-/Registry-Lücken:** fehlender Registereintrag für eine existierende Skill-Datei nachtragen; kaputte Verweise korrigieren.
- **Tote Verweise:** Zeigt ein Wikilink oder Markdown-Link auf eine `.md`-Datei, die es nicht gibt, zuerst per Volltextsuche prüfen, ob die Zieldatei umbenannt oder verschoben wurde. Gefunden: Link korrigieren. Nicht gefunden: nicht raten, sondern im Abschlussbericht zur Entscheidung vorlegen.
- **Fehlendes oder unzulässiges Frontmatter:** Fehlt `titel`, `zweck` oder `type`, die Datei lesen und die Felder aus dem realen Inhalt ergänzen, nie erfinden. Trägt `type` einen Wert ausserhalb der Liste aus Root-`AGENTS.md` Abschnitt 5, auf den passenden zulässigen Wert setzen. Braucht der Fall wirklich einen neuen Wert, im Bericht vorschlagen, statt die Liste eigenmächtig zu erweitern.
- **Kategorie `Herkunft`, gemeldete Pfadverweise ins Leere:** Jeden Treffer einzeln ansehen, nie pauschal löschen. Drei Fälle, drei Behandlungen: Der Pfad ist falsch geschrieben und die Datei existiert anderswo, dann korrigieren. Die Datei existiert wirklich nicht mehr, dann den Verweis entfernen und, falls die Aussage auf ihm stand, die Aussage als unbelegt kennzeichnen statt sie stehen zu lassen. Die Datei liegt ausserhalb des Repos, dann den Pfad vollständig schreiben, damit erkennbar ist, wo sie liegt. Das ist der Fall, in dem ein Beleg plausibel klingt und trotzdem keiner ist; er wird nie durch Weglassen des Verweises "behoben".
- **Kategorie `Herkunft`, Dateien ohne Statusausweis:** Nicht selbst bestätigen. Für jede gemeldete Datei kurz prüfen, ob der Repo-Besitzer ihren Inhalt je bestätigt hat (Sessionlog, eigene Aussage). Ist das belegbar, im Abschlussbericht vorlegen und erst nach seinem Ja `geprueft:` setzen. Ist es nicht belegbar, direkt beheben, indem der wahre Status als erste Zeile unter der Überschrift in die Datei geschrieben wird: "**Status:** Aus den genannten Quellen erarbeitet, nicht bestätigt (kein `geprueft:`)." Das behauptet nichts, es macht nur sichtbar, was das Fehlen des Feldes ohnehin bedeutet, und zwar dort, wo die nächste Session es liest.
- **Kategorie `Herkunft`, gemeldete Belegketten:** Ein Zyklus heisst, zwei Notizen belegen sich gegenseitig; eine Sackgasse heisst, die zitierte Notiz nennt selbst keine Quelle. Beides wird nie dadurch behoben, dass der Verweis verschwindet. Richtig ist, die ursprüngliche Quelle in der Zeile zu nennen: Absender und Datum, Archivpfad oder URL. Findest du sie nicht, wird die Aussage als unbelegt gekennzeichnet und `[NAME]` vorgelegt.
- **Kategorie `Links`, Verweise ohne Begründung:** Halbsatz ergänzen, warum der Verweis dort steht, oder den Verweis streichen. Nicht erfinden: Wenn du den Grund nicht aus der Datei erkennst, öffne sie kurz; ergibt sich kein Zusammenhang, ist das Streichen die richtige Antwort.
- **Kategorie `Formatdisziplin`:** Nicht-Markdown in einem Themenordner. Inhalt prüfen, was Wissen ist als Markdown übernehmen, danach die Datei ins Belegarchiv (fremde Quelle) oder nach Artifacts (selbst erzeugt) verschieben. Verschieben und Löschen erst nach Rücksprache, das entscheidet der Repo-Besitzer (Abschnitt 12).
- **Datei-Sperr-Fehler:** Skript einfach erneut laufen lassen.
- **Bug im mechanischen Skript selbst:** beheben und die neue Logik kurz bestätigen lassen, nicht nur den Symptomausschlag wegklicken.

### 4. Inbox behandeln
Für jede Datei in `90_Inbox` (ausser README.md): kurz anlesen und einordnen. Zwei Fälle:
- **Braucht inhaltliche Verarbeitung** (Mails, PDFs, Scans, Rohmaterial, dessen Wissen in eine konsolidierte Notiz gehört): NICHT verschieben, NICHT eigenmächtig verarbeiten. Im Abschlussbericht vorschlagen, die Datei verlustfrei in eine Wissensnotiz zu konsolidieren und die Rohquelle danach (git-gesichert) zu löschen. Der Health Check verarbeitet keine Inhalte.
- **Passt unverändert als eigenständige `.md` in einen Themenordner** (z.B. importierte Deep-Research-Berichte): Zielordner und ggf. besseren Dateinamen vorschlagen. **Verschieben NUR mit Bestätigung**, das ist die einzige Rückfrage dieses Skills. Nach Bestätigung:
```powershell
Move-Item -Path "C:\Leo\90_Inbox\<datei>" -Destination "C:\Leo\<zielordner>\<neuer-name>"
```

### 5. Entscheidungsbedarf sammeln (nicht eigenmächtig handeln)

**Jeder offene Befund wird so vorgelegt, dass ein "ja" genügt.** Nicht "die Datei X ist abgelaufen, was möchtest du tun?", sondern der fertig ausformulierte Zug: welche Datei, welche Aktion, welcher konkrete Wert oder Wortlaut, und was danach anders ist. Der Repo-Besitzer soll bestätigen, nicht die Lösung selbst ausarbeiten. Gibt es mehr als einen sinnvollen Weg, kommen maximal drei Varianten, davon eine begründet empfohlen und zuerst genannt. Formulierungsmuster: "Vorschlag: `gueltig_bis` in `<Datei>` auf 2026-09-30 verlängern, weil der Termin verschoben wurde. Ja?"

Befunde, die eine Entscheidung brauchen, klar benennen und je einen konkreten Vorschlag machen, aber nicht selbst entscheiden:
- **Abgelaufenes `gueltig_bis`** (Root-`AGENTS.md`, Abschnitt 7): Datei kurz anlesen und einen der drei Wege vorschlagen: erledigt (verbliebenes Dauerwissen in die zuständige Wissensdatei übernehmen, Datei löschen), verlängern (konkretes neues Datum nennen) oder als Historie behalten (`gueltig_bis` entfernen, damit die Datei aus der Prüfung fällt). Löschen und Übernehmen passieren erst nach einem Ja, das Feld selbst darf der Skill nicht eigenmächtig entfernen.
- Dazu: `stand:`-Daten älter als 60 Tage, git behind/Konflikte, deaktivierter Scheduled Task, Portabilitäts-Drift, grosse Aufräumaktionen, alles rund um `01_Basiskontext`. Meldet der Check, dass sich das Harness-Memory gefüllt hat (WARN Harness-Memory): **kein Repo-Mirror** (das ist bewusst ausgeschlossen, Root-`AGENTS.md` Abschnitt 1) - stattdessen jede Datei kurz lesen, Inhalt mit Dauerwert in die passende Repo-Datei migrieren (Basiskontext-Ziele mit Bestätigung, alles andere direkt), danach die Harness-Memory-Datei löschen. Im Bericht kurz auflisten, was migriert und gelöscht wurde.

### 6. Erneut prüfen (nur wenn etwas behoben wurde)
Wurde in Schritt 3 bis 5 nichts verändert, entfällt dieser Schritt (eine unveränderte Lage erneut zu diagnostizieren, bestätigt nur den ersten Bericht). Nach Korrekturen die Diagnose (Schritt 2) einmal wiederholen; Schritt 1 nur erneut, wenn Register, Skills oder Ordnerstruktur angefasst wurden. Kritische FAILs (Merge-Konflikt-Marker, kaputte Auto-Blöcke, doppelte Ordnernummern, unregistrierte Themenordner) IMMER beheben oder explizit als offen benennen.

### 7. Zeitstempel schreiben
```powershell
Get-Date -Format "yyyy-MM-dd HH:mm" | Set-Content -Path "C:\Leo\10_System\health-check-last-run.txt" -Encoding UTF8
```
Damit weiss `leo-wrap-up`, wann der letzte volle Check lief. Diese Datei wird mit committet, nicht ignoriert.

### 8. Committen und pushen (ohne Rückfrage)
```powershell
cd C:\Leo
git status                       # zuerst lesen: was ist offen, und was davon ist wirklich meins?
git add "<pfad1>" "<pfad2>"      # NUR die in dieser Session bearbeiteten Dateien, nie -A
git commit -m "System-Refresh: <Kurzbeschreibung>"
git pull --rebase
git push
```
**Die mechanischen Indexdateien gehören in denselben Commit.** Schritt 1 ändert alle `_INDEX.md` sowie `00_INDEX\INDEX.md` und `00_INDEX\INDEX-Geruest.md`, auch in Themenordnern, die du inhaltlich nicht angefasst hast; die Diagnose meldet sie als "erwartete Index-Drift". Sie sind Ergebnis deines eigenen Laufs und werden mitgestaged, per Pfad wie alles andere; das Verbot betrifft `git add -A`, nicht das Stagen von Skript-Output. `10_System\health-check-last-run.txt` aus Schritt 7 gehört ebenfalls in den Commit.

Ruft ein anderer Skill diesen Skill auf (z.B. Wrap-Up), gilt dessen Commit-Message. Schlägt der Rebase fehl (Konflikt): nichts erzwingen, melden. Commit + Push brauchen keine Bestätigung, Sicherheit kommt aus der Versionierung.

### 9. Abschlussbericht
Drei Teile plus Verdikt:
- **Automatisch behoben:** <Liste>.
- **Bekannte Ausnahmen (keine Aktion nötig):** <Liste>.
- **Offen, braucht eine Entscheidung:** <Liste mit je einem umsetzungsfertigen Vorschlag, den ein "ja" auslöst (siehe Schritt 5)>.
- Verdikt in einem Satz: "System aktuell und gepusht" / "System aktuell mit offenen Hinweisen" / "System NICHT einsatzbereit, folgendes zuerst klären: ...".

## Regeln
- Commit und Push sind Teil des Skills und brauchen keine Bestätigung. Verschieben, Löschen und Überschreiben von Wissensdateien dagegen NUR mit Bestätigung.
- Anti-Halluzination: nur melden und beschreiben, was Skript bzw. Datei real hergeben. Keine Vermutungen als Fakt.
- Basiskontext-Schutz: Befunde zu `01_Basiskontext` nur melden; Änderungen dort nur mit expliziter Bestätigung plus Changelog-Eintrag.

## Definition of Done
- [ ] Index-Skript und Diagnose-Skript sind fehlerfrei durchgelaufen (bei Datei-Sperre: wiederholt)
- [ ] Jeder Befund ist genau einer Kategorie zugeordnet: behoben, bekannte Ausnahme oder offen mit konkreter Empfehlung
- [ ] Kuratierte Beschreibungen für alle neuen oder geänderten Dateien ergänzt
- [ ] Keine kritischen FAILs unerwähnt; Diagnose nach Korrekturen wiederholt, bis der Bericht stabil ist
- [ ] Zeitstempel in `10_System\health-check-last-run.txt` geschrieben
- [ ] Committet und gepusht, oder der Konflikt ist gemeldet
- [ ] Abschlussbericht mit Verdikt geliefert
