---
titel: Modellwahl
zweck: Aktuelle Modellempfehlungen für den Betrieb des Systems
type: systemdoku
stand: 2026-10-19
---

# Modellwahl (Stand: siehe `stand:` im Frontmatter)

Die Modell-Landschaft ändert sich schnell. Diese Datei ist bewusst datiert: Ist der Stand älter als 3 Monate, soll das LLM darauf hinweisen und auf Zuruf ("modellwahl aktualisieren") per Websuche aktualisieren (Preise pro 1M Tokens Input/Output, Tool-Calling-Qualität, neue Herausforderer; Anweisung am Ende dieser Datei). Die konkreten Modellnamen unten sind ein Ausgangspunkt vom Oktober 2026, kein Dauerstand.

## Standardmodell: Sonnet-Klasse (seit 4.3)

Das Grundgerüst arbeitet standardmässig mit der Sonnet-Klasse in ihrer aktuellen Version, in Claude Code gesetzt über `"model": "sonnet"` in `.claude\settings.json` (Regel in `AGENTS.md`, Abschnitt 13). Das Alias löst auf das neueste Sonnet-Modell auf; Stand 19.10.2026 ist das Claude Sonnet 5.5 (`claude-sonnet-5-5`, 2 USD Eingabe, 10 USD Ausgabe, Cache-Lesen 0.10 USD je Mio. Token, Abkündigung nicht vor 28.09.2027; Quelle: Anthropic, Models overview und Pricing).

Warum Sonnet und nicht die günstigste Klasse: Dieses System arbeitet in mehrstufigen Suchketten (Index lesen, suchen, Treffer lesen, schreiben, prüfen) und hält ein umfangreiches Regelwerk ein. Werkzeug-Zuverlässigkeit und Regeltreue zählen dort mehr als der letzte Cent, denn eine fehlgeschlagene Suchkette oder eine übersehene Regel kostet mehr, als ein kleineres Modell spart. Bis 4.2 stand hier Haiku 4.5 als Default für den Chat-Betrieb; das war eine Empfehlung für reines Nachschlagen und passt nicht mehr zum heutigen Umfang der Mechanik.

Anforderungen an jedes Modell, das hier arbeitet: zuverlässiges mehrstufiges Tool-Calling, gute Beherrschung der Arbeitssprache, Prompt-Caching.

1. **Sonnet-Klasse** (Standard): siehe oben.
2. **Haiku-Klasse** (z.B. Claude Haiku 5.5): deutlich günstiger, für Massenarbeit ohne mehrstufige Suche (Umformatieren, einfache Extraktion). Vor dem Einsatz als Default über einen eigenen API-Schlüssel gegen das eigene Prüfset laufen lassen.
3. **Günstigere Herausforderer** (z.B. offene Gewichte wie die GLM-Reihe): oft in Tool-Use-Benchmarks stark und deutlich billiger; im eigenen Betrieb gegen das Prüfset testen, bevor sie eine Aufgabe übernehmen.

## Empfehlung nach Aufgabe

| Aufgabe | Modell |
|---|---|
| Wissensfragen, Alltag | Sonnet-Klasse (Standard) |
| Massenarbeit ohne mehrstufige Suche | Haiku-Klasse oder ein günstigerer Herausforderer (testen) |
| Anspruchsvolles Sparring, Redigat, Strategie | Frontier-Modell (z.B. Claude Sonnet in aktueller Version) |
| Bau-/Wartungsarbeit (Coding-Agent) | Standard-Modell des Coding-Agents; Opus-Klasse nur für echte Architekturarbeit |
| Verarbeitung von PDFs/Scans (Vision nötig) | Modell mit Vision, Sonnet-Klasse oder stärker (Bild-/Handschrift-Erkennung hängt an der Modellqualität) |
| Sensible Inhalte ohne Cloud | lokales Modell (Qualität geringer; nur wenn Datenschutz es verlangt) |

Prompt-Caching aktivieren, wo das Harness es anbietet: Bei Agentic Search wird derselbe Kontext pro Tool-Call wiederholt; ohne Caching zahlt man ihn jedes Mal voll.

## Claude-Abo (Claude Code / Desktop-App): Modell und Effort je Aufgabe

Effort-Stufen (Low, Medium, High als Default, Extra/"xhigh", Max) erhöhen Denk-Tokens und Tool-Runden, also den Verbrauch. Faustregeln:

- Innerhalb eines Modells bringt Effort über High schnell abnehmenden Ertrag. Der bessere Hebel ab dort ist die nächsthöhere Modellklasse auf Medium/High.
- Die neuesten Modelle leisten auf niedrigen Stufen bereits viel. Im Zweifel eine Effort-Stufe runter, im Zweifel beim Modell eine Klasse rauf.
- Für Sparring mit erwünschtem Widerspruch die stärkere, rigorosere Modellklasse wählen; explizite Anweisungen im Basiskontext übersteuern die Modell-Defaults ohnehin weitgehend.

| Aufgabe | Modell | Effort |
|---|---|---|
| Wissensfragen, kleine Dateipflege | Sonnet-Klasse | Medium |
| Wrap-Up, Health-Check, normale Bauarbeit | Sonnet-Klasse | High |
| Anspruchsvolles Sparring, Redigat, Strategie | Opus-Klasse | High |
| Fehler wäre sehr teuer, Kosten zweitrangig | Opus-Klasse | Max (neigt zum Überdenken, gezielt einsetzen) |

Modell-Check vor Arbeitsbeginn: siehe Root-`AGENTS.md`, Abschnitt 13 (Wechselvorschlag nur, bevor Kontext eingelesen wurde).

## Anweisung zur Aktualisierung (für das LLM)

1. Websuche: aktuelle Preise und Tool-Calling-Bewertungen der oben genannten Modellklassen plus neue Herausforderer (Quellen z.B. openrouter.ai, artificialanalysis.ai, Anbieter-Doku).
2. Empfehlungen neu begründen, Tabelle und Stand-Datum aktualisieren. Nichts ungeprüft aus dem Trainingswissen übernehmen; Preise nur mit aktueller Quelle.
3. Die Änderungen in 3 Sätzen zusammenfassen.
