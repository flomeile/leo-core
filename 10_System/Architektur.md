---
titel: Architektur
zweck: Die Zielarchitektur des KI-Systems
type: systemdoku
version: 1.1
letzte_aenderung: 2026-08-03
---

# Architektur des KI-Systems

## Zielbild in fünf Sätzen
Ein lokales Repo (`C:\Leo`) mit thematischen Markdown-Ordnern ist die einzige Quelle der Wahrheit. Eine herstellerneutrale `AGENTS.md` im Root trägt alle Arbeitsregeln; lokale `AGENTS.md` je Themenordner definieren die Rollen, die das LLM selbstständig anhand der Frage aktiviert. Das LLM greift agentisch über Datei-Werkzeuge und Volltextsuche zu, geführt von einem zweistufigen, teilmechanischen Index. Skills sind harness-neutrale Markdown-Anweisungen, auffindbar über ein Register. Git plus GitHub sichert alles automatisch; die Mechanik (Index, Sync) läuft ohne LLM per Task Scheduler.

## Die drei Schichten
1. **Ablage (Repo):** lokale Markdown-Dateien, thematisch geordnet, in Obsidian editierbar, versioniert. Tool-unabhängig.
2. **Zugriff (Werkzeuge):** native Werkzeuge des jeweiligen Harness (Coding-Agent: Read/Grep/Edit; Chat: Filesystem + PowerShell). PowerShell nur, wo native Werkzeuge fehlen.
3. **Anweisung (AGENTS-Mechanik):** Root-`AGENTS.md` (alle allgemeinen Regeln) + lokale `AGENTS.md` je Themenordner (Rolle, themenspezifische Regeln). `CLAUDE.md` und `GEMINI.md` sind nur Verweise. Chat-Harnesses ohne Auto-Load brauchen einen Einzeiler-Systemprompt, der auf AGENTS.md zeigt; mehr nicht.

## Rollen-Routing
Das LLM erkennt aus der Frage selbst, welche Themenordner betroffen sind, liest deren lokale AGENTS.md und nimmt die Rolle(n) ein. Mehrere Themen gleichzeitig sind normal. Explizite Rollen-Vorgabe im Prompt schlägt die Selbsterkennung. Die Zuordnungstabelle steht in der Root-AGENTS.md und wird vom Index-Skript mechanisch gepflegt.

## Wissenszugriff: Agentic Search, nicht RAG
Primärzugriff: Root-Index lesen, lokalen Themen-Index lesen, mit Synonymen im Inhalt suchen (Grep bzw. Select-String), nur Treffer ganz lesen. Kein RAG im Normalbetrieb (kein Chunk-Verlust, keine Vektor-Halluzination, in Obsidian editierbar, harness-unabhängig). RAG nur bei echtem Bedarf für einen einzelnen, sehr grossen Ordner nachrüsten.

## Der Index (Herzstück), zweistufig und teilmechanisch
- **Root `00_INDEX\INDEX.md`:** Ordnerbaum (Auto-Block, mechanisch), Themenbereiche, Beschreibungen der Systemdateien. Klein, wird bei jeder Frage gelesen.
- **`_INDEX.md` je Themenordner:** Dateiliste als Baum (Auto-Block, mechanisch) plus kuratierte Beschreibungen. Skaliert mit tiefer Verschachtelung: pro Frage wird nur der Index des betroffenen Themas gelesen.
- **`INDEX-Geruest.md`:** vollständige deterministische Baumliste. Sicherheitsnetz und Delta-Quelle.
- **Pflege:** Das Skript `build-index-geruest.ps1` (Task Scheduler, ohne LLM) hält alle mechanischen Teile aktuell, legt fehlende lokale Indizes an und löscht kuratierte Einträge zu nicht mehr existierenden Dateien. Das LLM (Skill `leo-system-health-check`) schreibt nur Beschreibungen, rein deskriptiv, nur im Delta.

## Aktualitäts-Mechanik (gegen veraltete Zustände)
- Struktur (Ordner, Dateien): ausschliesslich mechanisch in Auto-Blöcken, laufend vom Scheduler erneuert. Strukturaussagen werden nie von Hand dupliziert.
- Dynamische Inhalte (Aufgaben, Status, Verläufe): tragen PFLICHTMAESSIG `stand: YYYY-MM-DD` im Frontmatter; das LLM prüft den Stand beim Lesen, aktualisiert ihn beim Schreiben; der System-Health-Check meldet veraltete Stände und fehlende Kennzeichnungen mechanisch.
- Zeitgebundene Referenzen (z.B. `Modellwahl.md`): datiert, mit eingebauter Aktualisierungs-Anweisung per Websuche.

## Externe Quellen (MCP/Connectors)
Externe Systeme hängen am Harness, nicht am Repo: Die Anbindung lebt in der Harness-Konfiguration, das Repo bleibt reines Markdown plus Git und damit lock-in-frei. Externe Systeme sind Live-Quellen, kein zweites Gedächtnis; standardmässig read-only, Dauerwissen wandert per Ingest ins Repo. Regeln: Root-AGENTS.md Abschnitt 16.

## Zentrale Regeln, harness-unabhängig
Die Wahrheit über Arbeitsregeln liegt in EINER Datei: `C:\Leo\AGENTS.md`. Coding-Agents und Claude-Produkte laden sie automatisch (direkt oder via CLAUDE.md-Verweis); Chat-Projekte verweisen mit einem Einzeiler darauf. Ändert man die Regeln, ändert man eine Datei.

## Was bewusst NICHT verwendet wird
- **Harness-eigene Memory-Speicher:** ein zweites, undurchsichtiges Gedächtnis neben den Markdowns, nicht versioniert, nicht lock-in-frei. Widerspricht dem Kernprinzip (Root-AGENTS.md Abschnitt 1).
- **RAG / Vektor-Datenbanken im Normalbetrieb:** siehe oben, nur bei echtem Bedarf für einen einzelnen sehr grossen Ordner.
