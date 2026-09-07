---
titel: Technik
zweck: Technische Lösungen und Stolperfallen des Systems, mit Problem, Lösung, Begründung
type: systemdoku
version: 1.1
letzte_aenderung: 2026-08-03
---

# Technik: Probleme, Lösungen, Begründungen

Diese Datei dokumentiert die technische Substanz. Jeder Eintrag folgt dem Muster Problem, Lösung, Begründung. Sie ist lebende Systemdoku: Jede erwähnte Datei-/Skill-/Pfadbezeichnung muss mit der Realität übereinstimmen und wird bei Umbenennungen sofort nachgezogen (im Unterschied zu Append-only-Logs in `03_Sessionlogs` und `04_Changelog`, die nie rückwirkend umgeschrieben werden).

## Umgebung
- Betriebssystem: Windows (die Automatik und beide Skripte sind auf Windows ausgelegt: Backslash-Pfade, Windows Task Scheduler, `Get-ScheduledTask`).
- Anwenderprofil: fortgeschrittener Tech-Anwender, kein Developer.
- Nötig: Git, PowerShell (bordeigen: Windows PowerShell 5.1; empfohlen zusätzlich PowerShell 7 / `pwsh`). Optional: VS Code, Obsidian mit Obsidian-Git-Plugin.
- Repo: `C:\Leo` (lokal, NICHT in einem Cloud-Sync-Ordner wie OneDrive, sonst kollidieren Sync und Git).
- Modellzugriff: frei wählbar (Claude-Abo, OpenRouter-Key o.ä.), harness- und modellunabhängig.

## Agentic Search statt RAG
**Problem:** RAG (Vektor-DB, Chunks) lässt das LLM nur Fragmente statt ganzer Dateien sehen, verliert Zusammenhang und ist bei kleinen Wissensmengen schlechter.
**Lösung:** Primärzugriff ist Agentic Search: Das LLM sucht selbst über Werkzeuge und liest ganze Dateien.
**Begründung:** Wissensmengen sind klein bis mittel. Agentic Search vermeidet Chunk-Verlust und Vektor-Halluzination, ganze Dateien geben besseren Zusammenhang, alles bleibt in Obsidian editierbar und harness-unabhängig. RAG nur bei echtem Bedarf für einen einzelnen sehr grossen Ordner nachrüsten.

## Volltextsuche via PowerShell
**Problem:** Das Filesystem-Werkzeug vieler Chat-Harnesses (`search_files`) sucht NUR nach Dateinamen/Pfaden (Glob), NICHT im Datei-Inhalt. Wer nur liest, was der Index vorgibt, übersieht alles, was der Index nicht wörtlich beschreibt.
**Lösung:** Inhaltssuche über PowerShell `Select-String`:
```powershell
Get-ChildItem -Path 'C:\Leo' -Recurse -Filter '*.md' | Select-String -Pattern 'Begriff','Synonym' -List | Select-Object -ExpandProperty Path
```
Gibt nur Trefferpfade zurück (token-sparsam), rekursiv über alle Ebenen. Coding-Agents nutzen stattdessen ihr natives Grep-Werkzeug.
**Begründung:** Löst die Blindheit ohne Token-Verschwendung und ohne RAG. Keyword-Suche findet nur wörtliche Treffer; deshalb generiert das LLM selbst Synonyme (Suchstrategie in der Root-AGENTS.md).

## Index als Hybrid, nicht-generativ
**Problem:** Wie bleibt der Index vollständig, aktuell und aussagekräftig, ohne zu halluzinieren?
**Lösung:** Mechanisches Gerüst per PowerShell (`build-index-geruest.ps1`) listet alle real existierenden .md-Dateien, kann keine übersehen und keine erfinden, gelöschte fallen automatisch raus. Deskriptive Beschreibungen schreibt das LLM, aber nur zu je einer realen Datei, rein beschreibend, ohne erfundene Querverweise.
**Begründung:** Das LLM synthetisiert und verkettet nichts über die einzelne Datei hinaus und kann strukturell keine falsche Quelle bauen.

## Zentrale Regeln via AGENTS.md
**Problem:** Es gibt keinen globalen Systemprompt, der harness-übergreifend automatisch greift.
**Lösung:** Alle allgemeinen Regeln liegen in `C:\Leo\AGENTS.md` (herstellerneutraler Standard). `CLAUDE.md`/`GEMINI.md` sind Verweise darauf. Jeder Themenordner trägt eine lokale `AGENTS.md` mit Rolle; das Routing steht in der Root-AGENTS.md.
**Aktivierung je Harness:** Coding-Agents (Claude Code, Codex, Gemini CLI) und Claude-Produkte laden AGENTS.md/CLAUDE.md automatisch. Reine Chat-Harnesses brauchen pro Projekt einen Einzeiler-Systemprompt: "Lies zuerst C:\Leo\AGENTS.md vollständig und befolge sie für die gesamte Session."

## Skills als Markdown, nicht als Feature
**Problem:** Harness-eigene Skill-/Plugin-Systeme führen zu Packaging-Aufwand und Pfad-Chaos über mehrere Interfaces.
**Lösung:** Skills sind Markdown-Dateien in `02_Skills`, auffindbar über `Skill-Register.md`.
**Begründung:** Lesbar, versioniert, in Obsidian editierbar, harness-unabhängig, kein Packaging-Apparat.

## Sicherheit aus Git, nicht aus Bestätigungen
**Problem:** Viele Harnesses schreiben ohne Rückfrage in Dateien.
**Lösung:** Git-Versionierung ist das Sicherheitsnetz (Rollback jederzeit möglich), nicht eine Bestätigung pro Schreibvorgang. Git ist daher nicht optional. Automatik: Task Scheduler (Index-Sync + Push, täglich) und optional Obsidian-Git.

## Windows PowerShell 5.1 und Encoding (Stolperfalle)
**Problem:** Der Task Scheduler ruft je nach Konfiguration `powershell.exe` (5.1) auf. PS 5.1 interpretiert UTF-8-Skripte OHNE BOM als ANSI; Nicht-ASCII-Zeichen im Skript erzeugen dann Parse-Fehler.
**Lösung:** Beide Skripte sind als UTF-8 MIT BOM gespeichert und im Code ASCII-only gehalten (ae/oe/ue statt Umlaute IM SKRIPT-CODE, nicht in den Inhaltsdateien). Geschriebene Markdown-Dateien: `Set-Content -Encoding UTF8`.
**Regel:** Wer eines der Skripte ändert, bleibt ASCII-only und erhält das BOM. Skills rufen `pwsh` auf (oder `powershell.exe`, beide laufen).

## .claude ist Harness-Territorium (Scan-Ausschluss)
**Problem:** Coding-Agents legen unter `.claude\worktrees\` vollständige Arbeitskopien des Repos an. Git ignoriert diese, ein Skript über das Dateisystem würde sie sonst mitindexieren (jede Datei doppelt).
**Lösung:** `.git`, `.obsidian` und `.claude` werden von JEDEM rekursiven Scan über das Repo ausgeschlossen. Beide Skripte tun das bereits.
**Regel:** Wer eine Scan-Regel in einem der beiden Skripte ändert, prüft das jeweils andere mit. Sie laufen über denselben Baum und dürfen nicht auseinanderdriften.

## Kein harness-eigenes Memory
**Problem:** Manche Coding-Agents bieten einen persistenten Memory-Speicher ausserhalb des Repos an.
**Lösung:** Für Leo nicht genutzt (Root-AGENTS.md Abschnitt 1). Ein solcher Speicher wäre ein zweites, nicht portables Gedächtnis, ist meist nicht versionierbar (der Pfad ist oft ein Reparse-Point, den Git nicht traversieren kann) und widerspricht dem Grundprinzip. `health-check.ps1` meldet jeden Fund als Handlungsbedarf: Inhalt in die passende Repo-Datei migrieren, danach die Memory-Datei löschen. Kein Repo-Mirror.

## Pre-Commit-Hook: Durchsetzung unabhängig vom Harness
**Problem:** Eine Deny-Regel in der Konfiguration eines Coding-Agents wirkt nur in dessen eigenem Werkzeug. Sobald noch etwas anderes committet (Task Scheduler, Obsidian-Git, eine zweite Session, du selbst auf der Kommandozeile), läuft es an dieser Durchsetzung vorbei. Eine Regel, die nur an einer von vier Stellen greift, ist keine.
**Lösung:** `00_INDEX\githooks\pre-commit` (POSIX-sh, versioniert), aktiviert per `git config core.hooksPath 00_INDEX/githooks`. Er prüft den GESTAGETEN Inhalt (`git show :<datei>`), nicht die Datei auf der Platte: nur der landet im Commit.
**Zuschnitt, bewusst eng.** Blockiert wird ausschliesslich Beschädigung: Merge-Konflikt-Marker (`^<<<<<<< ` oder `^>>>>>>> `) in einer gestageten `.md`, und zerstörte `AUTO:...:BEGIN/END`-Paare in den mechanisch gepflegten Indexdateien (`AGENTS.md`, `00_INDEX/INDEX.md`, `*/_INDEX.md`). Die nackte Trennlinie `=======` wird bewusst nicht geprüft, sie ist in Markdown eine legitime Überschriften-Unterstreichung; und Dateien, die die Auto-Marker nur in Prosa nennen, dürfen nie blockieren. Alles Übrige (fehlendes Frontmatter, unbekannter `type`, abgelaufenes `gueltig_bis`) wird nur ausgegeben und bleibt Sache des Health-Checks.
**Warum so eng:** Ein Hook, der zuschlägt, lässt auch das Obsidian-Backup scheitern, und zwar in einer Plugin-Oberfläche, in der die Meldung womöglich niemand liest. Ein Backup, das still nichts mehr sichert, ist schlimmer als eines, das zu viel einsammelt. Aus demselben Grund ist der Hook fail open: Fehlt eines der benutzten Werkzeuge (`awk`, `sed`, `grep`, `date`), meldet er das und lässt den Commit durch. Notausgang: `git commit --no-verify`.
**Zwei Fallstricke:** (a) `core.hooksPath` ist eine lokale Einstellung und wird nicht mitversioniert; nach einem frischen Clone liegt der Hook da und tut nichts. Deshalb prüft `health-check.ps1` (Kategorie `Git`) mechanisch, ob der Pfad gesetzt ist und die Datei existiert. (b) Steht `core.autocrlf` auf `true` (Windows-Standard), checkt Git den Hook mit CRLF aus, und `/bin/sh` bricht bei JEDEM Commit mit `\r: command not found` ab. Dagegen die mitgelieferte `.gitattributes` mit `00_INDEX/githooks/* text eol=lf`.
**Regel:** Die Ausnahmelisten für den Frontmatter-Hinweis im Hook sind identisch zu denen in `health-check.ps1` gehalten. Wer eine ändert, zieht die andere nach.

## Sonderzeichen in Pfaden (Coding-Agent)
**Problem:** Manche Bash-Tools reichen Umlaute in Dateipfaden nicht sauber durch (das ä kommt als Ersatzzeichen an, "Datei nicht gefunden").
**Lösung:** Pfade mit Sonderzeichen nicht aus Bash-Tool-Output kopieren, sondern korrekt eintippen, oder für Verzeichnisauflistungen das PowerShell-Werkzeug statt des Bash-Werkzeugs nutzen.

## Betrieb: was automatisch läuft
- Task Scheduler ruft das Index-Skript (`build-index-geruest.ps1`) täglich auf und pusht. Das hält Ordnerbaum, Dateilisten und Rollen-Tabelle mechanisch aktuell und sichert nach GitHub. KEINE Diagnose, KEINE kuratierten Beschreibungen, KEINE `stand:`-Pflege (dafür fehlt dem Scheduler die LLM-Urteilsfähigkeit). Wer das sofort und vollständig will: `leo-system-health-check` ("health check").
- Einrichtung des Scheduled Task: siehe `ANLEITUNG.md` im Root.

## Offene technische Punkte
- Konkretes Websuch-Werkzeug je Harness prüfen und im Manual festhalten.
