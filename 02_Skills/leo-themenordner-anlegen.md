---
name: leo-themenordner-anlegen
trigger: '"neuer themenordner", "themenordner anlegen", "neues thema anlegen"'
zweck: Neuen Themenordner vollständig anlegen (Ordner, README, lokale AGENTS.md, Routing, Index)
type: skill
version: 1.0
---

# Skill: Themenordner anlegen

Legt einen neuen Themenordner so an, dass er sofort vollwertig im System funktioniert: Rolle, Routing, Index, Doku. Voraussetzung: Datei-Schreibzugriff plus PowerShell.

## Wann ausführen
- Wenn ein neues Thema als eigener Ordner gewünscht ist.
- NICHT für Unterordner innerhalb bestehender Themen (die legt man einfach an; der Index erfasst sie automatisch).

## Schritte

### 1. Klären
Frag (falls nicht schon gesagt): Themenname? Welche Rolle soll das LLM dort einnehmen? Besondere Regeln (Sensibilität, Stil, Grenzen)?

### 2. Nummer und Name bestimmen
- Aktuelle Themenordner listen (`Get-ChildItem C:\Leo -Directory`), höchste bestehende Themenordner-Nummer ermitteln, nächste freie Nummer verwenden (+1). Die Nummerierung startet im 2X-Bereich (20-29); ist dieser voll, im nächsten Zehnerbereich weiterzählen (30, 31, ...). Das System erkennt jeden Ordner mit numerischem Präfix >= 20 automatisch als Themenordner (siehe `Test-IsThemenordner` in `build-index-geruest.ps1`).
- Ordnername: `<Nummer>_Themenname` (sprechend, keine Sonderzeichen, keine Leerzeichen am Anfang/Ende).

### 3. Ordner und README anlegen
`C:\Leo\<Nummer>_Themenname\README.md` (kurz):
```markdown
---
titel: <Themenname>-Wissensordner
zweck: <ein Satz>
type: readme
---

# <Nummer>_Themenname

<Ein bis zwei Sätze: was hier liegt.>

Regeln und Rolle: siehe `AGENTS.md` in diesem Ordner. Dateiliste: `_INDEX.md`.
```

### 4. Lokale AGENTS.md anlegen
`C:\Leo\<Nummer>_Themenname\AGENTS.md`: Frontmatter, `# Rolle: <Rolle>`, Abschnitt Kontext (was hier liegt, Verweis auf `_INDEX.md`), Abschnitt Regeln (themenspezifisch; Anti-Halluzination und Datenschutz nur ergänzen, wo das Thema Besonderes verlangt; Allgemeines steht schon in der Root-AGENTS.md und wird NICHT dupliziert). Muster:
```markdown
---
titel: Lokale AGENTS.md <Nummer>_Themenname
zweck: Rolle und Regeln für <Thema>
type: rollen-regeln
letzte_aenderung: YYYY-MM-DD
---

# Rolle: <Rolle>

Du bist <Rollenbeschreibung in ein bis zwei Sätzen>.

## Kontext
- Was hier liegt (Verweis auf `_INDEX.md`).
- Frühere Ablagen aktiv heranziehen.

## Regeln
- <themenspezifische Regeln, keine Duplikate der Root-AGENTS.md>
```
Die Zeile `# Rolle: <Rolle>` ist Pflicht: Das Index-Skript liest daraus die Rollen-Tabelle.

### 5. Index-Mechanik laufen lassen (zieht auch das Routing nach)
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Leo\00_INDEX\scripts\build-index-geruest.ps1"
```
Das Skript legt die `_INDEX.md` des neuen Ordners an, aktualisiert den Ordnerbaum UND trägt den Ordner mechanisch in die Rollen-Tabelle (Root-AGENTS.md) und die Themenbereiche (INDEX.md) ein. Nichts von Hand in die Auto-Blöcke schreiben.

### 6. Verifizieren
- Prüfe in `C:\Leo\AGENTS.md` (Auto-Block ROLLEN), dass der neue Ordner mit korrekter Rolle erscheint.
- Prüfe in `C:\Leo\00_INDEX\INDEX.md` im Auto-Block BEREICHE, dass der neue Ordner mit korrekter Rolle UND dem Hinweis "Datei-Beschreibungen stehen NICHT hier, sondern in -> ..." erscheint. Falls nicht (z.B. Datei kurz gesperrt): Skript nochmals laufen lassen.
- Prüfe, dass `C:\Leo\<Nummer>_Themenname\_INDEX.md` existiert.

### 7. Bestätigen
"Themenordner <Nummer>_Themenname angelegt: README, AGENTS.md (Rolle: <Rolle>), lokaler Index erzeugt, Routing mechanisch nachgezogen."

## Regeln
- Keine Regel-Duplikate: Allgemeingültiges bleibt in der Root-AGENTS.md.
- Rolle und Regeln abstimmen, nicht erfinden.
- Nummern nie doppelt vergeben.

## Definition of Done
- [ ] Nummer geprüft und eindeutig, Ordnername ohne Sonderzeichen
- [ ] README.md und lokale AGENTS.md mit Zeile `# Rolle: <Rolle>` existieren, Rolle abgestimmt
- [ ] Index-Skript gelaufen
- [ ] Rollen-Tabelle (Root-AGENTS.md), BEREICHE-Block (INDEX.md) und `_INDEX.md` des neuen Ordners real verifiziert, nicht angenommen
- [ ] Bestätigung nennt Ordner, Rolle und erzeugte Dateien
