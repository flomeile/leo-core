# build-skill-wrapper.ps1 (Version 2)
# Zweck: Erzeugt aus 02_Skills\Skill-Register.md duenne Zeiger in den Skill-Verzeichnissen
# ALLER gaengigen Harnesses, damit die Repo-Skills ueberall nativ anspringen
# (Autovervollstaendigung mit /name, automatisches Laden anhand der Beschreibung).
#
# WICHTIG, das ist der ganze Punkt dieses Skripts:
# Die Zeiger enthalten KEINE Substanz. Sie nennen Name, Trigger und Zweck und sagen dem
# Modell, es soll die echte Datei in 02_Skills lesen und ausfuehren. Die Wahrheit bleibt
# ausschliesslich in 02_Skills. Wer alle Zeiger-Verzeichnisse loescht, verliert nur die
# Bequemlichkeit: Leo funktioniert unveraendert weiter, weil das Skill-Register in jedem
# Harness den Weg zur Datei beschreibt (Root-AGENTS.md, Abschnitt 11).
#
# WARUM MEHRERE VERZEICHNISSE:
# Ein Werkzeugwechsel darf keine Vorbereitung kosten. Wer Leo in einem anderen Werkzeug
# oeffnet, soll dort sofort dieselben Skills haben, ohne dass vorher jemand etwas baut.
# Deshalb werden die Zeiger auf Vorrat in alle bekannten Pfade geschrieben, auch in die
# von Werkzeugen, die heute niemand benutzt. Das ist die eine Stelle, an der die
# YAGNI-Regel bewusst nicht gilt: Der Vorrat IST hier der Zweck.
#
# Format der erzeugten Dateien folgt der Agent-Skills-Spezifikation (agentskills.io,
# offener Standard seit 12/2025): nur die Felder "name" und "description" im Frontmatter.
# Diese Teilmenge wird ueberall akzeptiert (Claude Code, Codex, Cursor, Gemini CLI,
# Cline, OpenCode, claude.ai-Upload, Skills-API). Ein Claude-Code-eigenes Zusatzfeld
# wuerde anderswo einen harten Fehler ausloesen, deshalb bleibt es bei den zwei Feldern.
#
# Aufruf: pwsh -NoProfile -ExecutionPolicy Bypass -File "<REPO>\00_INDEX\scripts\build-skill-wrapper.ps1"
# Der Repo-Root wird aus dem Skript-Speicherort abgeleitet, kein hartcodierter Pfad.

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$registerFile = Join-Path $repo "02_Skills\Skill-Register.md"

# UTF-8 ohne BOM, identisch unter Windows PowerShell 5.1 und PowerShell 7.
# Begruendung an der Schreibstelle weiter unten.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Zielverzeichnisse je Harness (Stand 07.08.2026, Quelle: agentskills.io-Oekosystem).
# Neues Harness? Hier EINE Zeile ergaenzen, Skript laufen lassen, fertig.
# Skills mit Seiteneffekten, die NIE von selbst anspringen duerfen:
# Seit die Zeiger existieren, stehen alle Beschreibungen im Kontext, und das Modell darf
# einen passenden Skill ohne Trigger-Wort laden. Bei einem Skill, der loescht, pusht oder
# nach aussen sendet, ist das gefaehrlich; leo-mechanik-update etwa ersetzt Kern-Dateien.
# Solche Skills werden doppelt abgesichert:
#   1) Ein Warnsatz in der description. Spec-konform, wirkt in jedem Werkzeug, ist aber
#      nur eine Bitte an das Modell.
#   2) disable-model-invocation im Frontmatter, ABER nur im Claude-Code-Zeiger. Das Feld
#      gehoert nicht zu den sechs Spec-Feldern und wuerde beim Upload zu claude.ai oder
#      beim Packaging einen harten Fehler ausloesen; in den uebrigen Pfaden bleibt es weg.
# Baust du einen eigenen Skill mit Seiteneffekten, traegst du ihn hier nach.
# Wrap-Up und Health-Check stehen bewusst NICHT drin: dass die von selbst anspringen,
# wenn eine Session zu Ende geht, ist gewollt.
#
# Das Kriterium ist nicht nur "loescht oder sendet", sondern auch "kostet Geld":
# leo-system-optimierung startet je Lauf mehrere kalte Modell-Aufrufe und gehoert
# deshalb ebenso hierher (Befund 31.08.2026, gemeldet von einem Nutzer des
# Grundgeruests und im Ursprungssystem bestaetigt: Die Liste war dort sogar leer).
# leo-inbox-ingest (seit 4.3) verschiebt Rohquellen ins Archiv und committet; er wird vorgeschlagen,
# nicht ungefragt gestartet.
$noAutoInvoke = @("leo-mechanik-update", "leo-system-optimierung", "leo-inbox-ingest")

$targets = @(
    @{ Pfad = ".claude\skills";   Fuer = "Claude Code, Claude Desktop"; ClaudeFelder = $true },
    @{ Pfad = ".agents\skills";   Fuer = "Codex CLI, Cursor, Gemini CLI (neutraler Standardpfad)" },
    @{ Pfad = ".gemini\skills";   Fuer = "Gemini CLI (eigener Pfad, zusaetzlich zum neutralen)" },
    @{ Pfad = ".cursor\skills";   Fuer = "Cursor (eigener Pfad)" },
    @{ Pfad = ".cline\skills";    Fuer = "Cline (VS Code)" },
    @{ Pfad = ".opencode\skills"; Fuer = "OpenCode" }
)

if (-not (Test-Path $registerFile)) {
    Write-Error "Skill-Register nicht gefunden: $registerFile"
    exit 1
}

# --- Register parsen ---------------------------------------------------------
# Tabellenformat: | Skill | Trigger-Worte | Datei | Zweck |
# Kopf- und Trennzeile werden uebersprungen, ebenso alles ausserhalb der Tabelle.

$rows = @()
foreach ($line in (Get-Content -Path $registerFile -Encoding UTF8)) {
    $t = $line.Trim()
    if (-not $t.StartsWith("|")) { continue }
    if ($t -match "^\|\s*Skill\s*\|") { continue }
    if ($t -match "^\|\s*-+") { continue }

    $cols = ($t.Trim("|") -split "\|") | ForEach-Object { $_.Trim() }
    if ($cols.Count -lt 4) { continue }

    # Spalte 3 ist der Pfad, z.B. 02_Skills/leo-wrap-up.md
    if ($cols[2] -notmatch "([^/\\]+)\.md\s*$") { continue }
    $slug = $matches[1]

    $rows += [pscustomobject]@{
        Slug    = $slug
        Titel   = $cols[0]
        Trigger = $cols[1]
        Zweck   = $cols[3]
        Datei   = $cols[2] -replace "/", "\"
    }
}

if ($rows.Count -eq 0) {
    Write-Error "Keine Skill-Zeilen im Register erkannt. Tabellenformat geprueft?"
    exit 1
}

# --- Zeiger-Inhalte vorbereiten ----------------------------------------------

$bodies = @{}

foreach ($r in $rows) {
    # description bleibt einzeilig und unter dem Limit von 1536 Zeichen, das sich
    # Claude Code fuer die Skill-Liste setzt. Der Zweck wird dafuer am Semikolon
    # bzw. hart gekuerzt; die vollstaendige Fassung steht im Register und im Skill.
    $zweck = $r.Zweck
    if ($zweck.Length -gt 320) {
        $cut = $zweck.Substring(0, 320)
        $lastSep = [Math]::Max($cut.LastIndexOf(";"), $cut.LastIndexOf(","))
        if ($lastSep -gt 160) { $cut = $cut.Substring(0, $lastSep) }
        $zweck = $cut.TrimEnd() + " (vollstaendig im Skill)"
    }

    # YAML: einfach gequotet, damit die doppelten Anführungszeichen der Trigger-Worte
    # literal bleiben. Einfache Anführungszeichen im Text werden verdoppelt.
    $desc = "Trigger: $($r.Trigger). $zweck"
    if ($noAutoInvoke -contains $r.Slug) {
        $desc = "NUR auf ausdrueckliche Anweisung ausfuehren, nie selbstaendig: dieser Skill hat Seiteneffekte, die sich nicht zurueckdrehen lassen. " + $desc
    }
    $desc = $desc -replace "'", "''"
    $desc = $desc -replace "\s+", " "

    $fm = @("---", "name: $($r.Slug)", "description: '$desc'")
    $fmClaude = $fm + @("disable-model-invocation: true")
    $fm += "---"
    $fmClaude += "---"

    # Erstes Element leer, damit der Join direkt hinter dem "---" des Frontmatters
    # eine echte Leerzeile erzeugt statt die Ueberschrift anzukleben.
    $rest = @(
        "",
        "",
        "# $($r.Titel)",
        "",
        "Diese Datei ist nur ein Zeiger, sie enthält keine Anweisung.",
        "",
        "Die vollständige und einzig verbindliche Arbeitsanweisung steht in ``$($r.Datei)``.",
        "Lies diese Datei jetzt vollständig und führe sie exakt so aus, wie sie es beschreibt.",
        "Ersetze sie nicht durch den Inhalt dieser Datei hier und kürze sie nicht ab.",
        "",
        "---",
        "",
        "Erzeugt von ``00_INDEX\scripts\build-skill-wrapper.ps1`` aus ``02_Skills\Skill-Register.md``.",
        "Nicht von Hand ändern: Änderungen gehen beim nächsten Lauf verloren.",
        "Dieses Verzeichnis ist wegwerfbar, das System läuft ohne es unverändert weiter."
    ) -join "`r`n"

    # Zwei Fassungen: eine spec-konforme fuer alle Harnesses, eine mit dem
    # Claude-Code-eigenen Feld nur fuer .claude\skills\.
    $bodies[$r.Slug] = @{
        Spec   = (($fm       -join "`r`n") + $rest + "`r`n")
        Claude = (($fmClaude -join "`r`n") + $rest + "`r`n")
    }
}

# --- In jedes Zielverzeichnis schreiben --------------------------------------

$known = $rows | ForEach-Object { $_.Slug }
$totalCreated = 0; $totalUpdated = 0; $totalRemoved = 0
$report = @()

foreach ($t in $targets) {
    $skillsDir = Join-Path $repo $t.Pfad
    if (-not (Test-Path $skillsDir)) { New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null }

    $created = 0; $updated = 0; $unchanged = 0; $removed = @()

    foreach ($slug in $known) {
        $dir = Join-Path $skillsDir $slug
        $file = Join-Path $dir "SKILL.md"
        # Das Zusatzfeld gibt es nur im Claude-Pfad und nur fuer die Skills mit Seiteneffekten.
        $body = if ($t.ClaudeFelder -and ($noAutoInvoke -contains $slug)) {
            $bodies[$slug].Claude
        } else {
            $bodies[$slug].Spec
        }

        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

        # Geschrieben wird ueber .NET statt ueber Set-Content -Encoding UTF8, weil
        # dieser Parameter in beiden PowerShell-Generationen etwas ANDERES bedeutet:
        # unter Windows PowerShell 5.1 UTF-8 MIT BOM, unter PowerShell 7 ohne. Eine
        # BOM vor dem "---" macht das Frontmatter fuer den Skill-Loader unlesbar,
        # der Skill zeigt dann als Beschreibung nur noch "---" an. Die Ausgabe muss
        # unabhaengig davon sein, welcher Interpreter das Skript startet, sonst
        # haengt die Funktionsfaehigkeit der Zeiger am Zufall.
        if (Test-Path $file) {
            $old = Get-Content -Path $file -Raw -Encoding UTF8
            if ($old -eq $body) { $unchanged++; continue }
            [System.IO.File]::WriteAllText($file, $body, $utf8NoBom)
            $updated++
        } else {
            [System.IO.File]::WriteAllText($file, $body, $utf8NoBom)
            $created++
        }
    }

    # --- Verwaiste Zeiger entfernen ------------------------------------------
    # Nur Verzeichnisse, die genau eine SKILL.md mit der Erzeuger-Signatur enthalten.
    # Alles andere bleibt unangetastet: dort koennen von Hand angelegte oder aus
    # einem Marketplace installierte Skills liegen, die nichts mit Leo zu tun haben.
    # Ein Skript, das fremde Verzeichnisse loescht, waere gefaehrlich.
    foreach ($dir in (Get-ChildItem -Path $skillsDir -Directory -ErrorAction SilentlyContinue)) {
        if ($known -contains $dir.Name) { continue }
        $file = Join-Path $dir.FullName "SKILL.md"
        if (-not (Test-Path $file)) { continue }
        $content = Get-Content -Path $file -Raw -Encoding UTF8
        if ($content -notmatch "build-skill-wrapper\.ps1") { continue }
        if ((Get-ChildItem -Path $dir.FullName -Recurse -File).Count -ne 1) { continue }
        Remove-Item -Path $dir.FullName -Recurse -Force
        $removed += $dir.Name
    }

    $totalCreated += $created; $totalUpdated += $updated; $totalRemoved += $removed.Count

    $status = if ($created -or $updated -or $removed.Count) {
        "neu $created, aktualisiert $updated, entfernt $($removed.Count)"
    } else { "unveraendert ($unchanged)" }
    $report += "  {0,-18} {1,-58} {2}" -f $t.Pfad, $t.Fuer, $status
}

# --- Bericht -----------------------------------------------------------------

Write-Output "Skill-Zeiger aus dem Register in alle Harness-Pfade geschrieben:"
Write-Output "  Register-Eintraege: $($rows.Count), Zielverzeichnisse: $($targets.Count)"
$report | ForEach-Object { Write-Output $_ }
if ($totalCreated -or $totalUpdated -or $totalRemoved) {
    Write-Output "  Summe: $totalCreated neu, $totalUpdated aktualisiert, $totalRemoved entfernt."
} else {
    Write-Output "  Nichts zu tun, alle Zeiger aktuell."
}
