# pruef-frontmatter.ps1
# Zweck: PostToolUse-Hook nach Write, Edit und MultiEdit auf eine .md-Datei im Repo (seit 4.9).
#
# WARUM ES DAS GIBT: Zwei Fehler entstehen beim Schreiben laufend und fallen erst spaet auf.
#   (1) Ungueltiges Frontmatter: ein Doppelpunkt, ein ' #', ein Backtick am Wertanfang, ein
#       Windows-Pfad in doppelten Anfuehrungszeichen. Der Block ist dann kein gueltiges YAML
#       mehr; der Editor zeigt die Eigenschaften als fehlerhaft, Filter ueber type: oder
#       stand: sehen die Datei nicht. Bisher fand das erst der naechste Health-Check, oft Tage
#       spaeter und nicht mehr in der Session, die den Fehler gemacht hat.
#   (2) stand: nicht nachgefuehrt (AGENTS.md Abschnitt 7): Eine Datei wird inhaltlich geaendert,
#       ihr stand: bleibt auf dem alten Datum, und sie gilt danach als ungeprueft oder veraltet.
# Der Hook prueft deshalb jede geschriebene .md sofort:
#   - Befund im Frontmatter: Er gibt ihn als Blockgrund an das Modell zurueck, das die Datei im
#     selben Zug repariert. Die Regeln stehen in lib\frontmatter-pruefung.ps1, dieselben wie im
#     Health-Check (Kategorie Frontmatter).
#   - stand: vor heute: Er erinnert das Modell, es auf heute zu setzen, wenn die Aenderung
#     inhaltlich war. Das Datum setzt er bewusst nicht selbst: Eine rein mechanische Aenderung
#     (Link, Tippfehler, Metadaten) laesst stand: stehen, und das entscheidet nur, wer die
#     Aenderung kennt.
#
# WAS ER NICHT SIEHT: Aenderungen von Hand im Editor oder aus einem anderen Werkzeug ohne Hook.
# Die faengt der Health-Check (Kategorien Frontmatter und Aktualitaet).
#
# EINRICHTUNG: Eingehaengt in .claude\settings.json, Ereignis PostToolUse, Matcher
# Write|Edit|MultiEdit. Er blockiert nie den Werkzeugaufruf selbst (der ist schon gelaufen),
# sondern gibt nur Rueckmeldung an das Modell. Jeder eigene Fehler endet still in Exit 0;
# mit der Umgebungsvariable LEO_HOOK_DEBUG=1 schreibt er ihn auf stderr.
# Eingabe: JSON auf stdin (als UTF-8 gelesen, sonst verlieren Umlaute im Pfad ihre Form).
# Regressionsreihe: pruef-frontmatter-tests.ps1 im selben Ordner, Pflicht vor und nach jeder
# Aenderung an diesem Skript oder an der Lib.
# ASCII-only, laeuft unter Windows PowerShell 5.1 und PowerShell 7. Bewusst 'Continue' statt
# 'Stop': Unter 5.1 wuerde 'Stop' jede Meldung auf stderr zum Abbruch machen; Fehler, die zaehlen,
# werfen hier ohnehin (.NET-Aufrufe, -ErrorAction Stop) und landen im catch.

$ErrorActionPreference = 'Continue'
# Die Antwort geht als UTF-8 zurueck; unter 5.1 waere es sonst die Konsolen-Codepage, und ein
# Umlaut im Dateinamen kaeme beim Modell als anderes Zeichen an.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding($false)))).ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json -ErrorAction Stop
    if (@('Write', 'Edit', 'MultiEdit') -notcontains [string]$in.tool_name) { exit 0 }
    $pfad = [string]$in.tool_input.file_path
    if (-not $pfad -or $pfad -notmatch '\.md$') { exit 0 }
    if (-not [IO.File]::Exists($pfad)) { exit 0 }

    $trenner = [IO.Path]::DirectorySeparatorChar
    $repo = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
    $repo = [IO.Path]::GetFullPath($repo).TrimEnd('\', '/')
    $voll = [IO.Path]::GetFullPath($pfad)
    $vergleich = if ($trenner -eq '\') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $voll.StartsWith($repo + $trenner, $vergleich)) { exit 0 }
    $rel = $voll.Substring($repo.Length + 1)

    . (Join-Path (Join-Path $PSScriptRoot 'lib') 'frontmatter-pruefung.ps1')
    $zeilen = [IO.File]::ReadAllLines($voll, [Text.Encoding]::UTF8)

    $teile = @()
    $befunde = Test-LeoFrontmatter $zeilen
    if ($befunde.Count -gt 0) {
        $liste = ($befunde | ForEach-Object { "Zeile $($_.Zeile)$(if ($_.Schluessel) { " ($($_.Schluessel):)" }): $($_.Problem)" }) -join '; '
        $teile += "Das Frontmatter von $rel ist kein gueltiges YAML, der Editor zeigt die Eigenschaften dann als fehlerhaft: $liste. Repariere es jetzt: den Wert in einfache Anfuehrungszeichen setzen ('...', ein ' im Inneren verdoppeln) oder das Zeichen umformulieren (AGENTS.md Abschnitt 5)."
    }

    $stand = Get-LeoFrontmatterStand $zeilen
    $heute = Get-Date -Format 'yyyy-MM-dd'
    if ($stand -and $stand -match '^\d{4}-\d{2}-\d{2}$' -and $stand -lt $heute) {
        $teile += "$rel traegt stand: $stand, heute ist $heute. War diese Aenderung inhaltlich (neue Aussage, Status, Entscheid, Eintrag), setze stand: jetzt auf $heute; war sie rein mechanisch (Link, Tippfehler, Metadaten), lass stand: stehen (AGENTS.md Abschnitt 7)."
    }

    if ($teile.Count -eq 0) { exit 0 }
    $text = 'Hinweis vom Hook pruef-frontmatter.ps1: ' + ($teile -join ' ')
    if ($befunde.Count -gt 0) {
        @{ decision = 'block'; reason = $text } | ConvertTo-Json -Compress
    } else {
        @{ hookSpecificOutput = @{ hookEventName = 'PostToolUse'; additionalContext = $text } } | ConvertTo-Json -Compress -Depth 4
    }
    exit 0
} catch {
    if ($env:LEO_HOOK_DEBUG) { [Console]::Error.WriteLine("FEHLER Zeile $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)") }
    exit 0
}
