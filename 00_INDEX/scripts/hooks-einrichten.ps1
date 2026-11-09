# hooks-einrichten.ps1
# Zweck: Richtet die Hook-Befehle in .claude\settings.json (und .codex\hooks.json) fuer die
# Plattform dieses Rechners ein und setzt die vier Sperren auf "sperren, wenn der Hook nicht
# startet" (AGENTS.md Abschnitt 18, seit 5.1).
#
# WARUM ES DAS GIBT: Die mitgelieferten Hook-Befehle rufen "powershell", das gibt es nur unter
# Windows. Auf macOS und Linux startete deshalb bis 5.0 kein Hook, bis der Besitzer die Befehle
# von Hand umschrieb, und ein Hook, der nicht startet, liess bis dahin alles durch. Bei einer
# Standardsperre ist das der gefaehrlichste Fall: Alles sieht richtig aus, und nichts ist gesperrt.
# Seit 5.1 tragen die vier Sperren "onFailure": "block" (Claude Code ab 2.1.295): Startet der
# Hook nicht, laeuft er in eine Zeitueberschreitung oder endet er mit einem Fehler, sperrt Claude
# Code den Werkzeugaufruf. Dieses Skript schreibt dazu die Befehle so, dass sie hier starten.
#
# FOLGE, DIE DER BESITZER KENNEN MUSS: Fehlt auf macOS oder Linux PowerShell 7, kann der Agent
# nach diesem Skript gar kein Werkzeug mehr benutzen, bis PowerShell 7 installiert ist. Das ist
# gewollt. Das Skript selbst laeuft ohnehin nur mit PowerShell 7, prueft also durch sein Laufen,
# dass es da ist. Installation auf dem Mac: brew install --cask powershell
#
# WAS ES ANFASST: nur Hook-Eintraege, deren Befehl eines der Kernskripte startet (guard-read,
# guard-workspace, guard-git, guard-mail, eingehaengte-repos-aktuell, pruef-frontmatter). Eigene
# Hooks und alle anderen Schluessel bleiben, wie sie sind. In .codex\hooks.json wird statt
# ${CLAUDE_PROJECT_DIR} der ausgeschriebene Repo-Pfad eingesetzt; "onFailure" kommt dort nicht
# hinein, weil nicht belegt ist, dass Codex den Schluessel kennt.
#
# AUFRUF (der Agent darf es selbst ausfuehren; es schreibt nur ins Repo):
#   Windows:       powershell -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\hooks-einrichten.ps1"
#   macOS/Linux:   pwsh -NoProfile -File "<Repo>/00_INDEX/scripts/hooks-einrichten.ps1"
#   -Pruefen       aendert nichts, meldet nur, was zu tun waere (Exit 1, wenn etwas fehlt)
# Testparameter: -Plattform windows|posix, -Pwsh <Pfad>, -Datei <settings.json>, -CodexDatei <hooks.json>
# ASCII-only: laeuft unter Windows PowerShell 5.1 und PowerShell 7.
param(
    [switch]$Pruefen,
    [ValidateSet('', 'windows', 'posix')][string]$Plattform = '',
    [string]$Pwsh = '',
    [string]$Datei = '',
    [string]$CodexDatei = ''
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $Plattform) { $Plattform = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { 'windows' } else { 'posix' } }
if (-not $Datei) { $Datei = Join-Path (Join-Path $repo '.claude') 'settings.json' }
if (-not $CodexDatei) { $CodexDatei = Join-Path (Join-Path $repo '.codex') 'hooks.json' }
if ($Plattform -eq 'posix' -and -not $Pwsh) {
    $Pwsh = Join-Path $PSHOME 'pwsh'
    if (-not (Test-Path -LiteralPath $Pwsh)) { $Pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source }
    if (-not $Pwsh) { "PowerShell 7 (pwsh) nicht gefunden. Auf dem Mac installieren mit: brew install --cask powershell"; exit 2 }
}

$kernRx = '00_INDEX[\\/]+scripts[\\/]+(guard-read|guard-workspace|guard-git|guard-mail|eingehaengte-repos-aktuell|pruef-frontmatter)\.ps1"?(.*)$'
$sperren = @('guard-read', 'guard-workspace', 'guard-git', 'guard-mail')

function Neuer-Befehl([string]$name, [string]$rest, [string]$wurzel) {
    if ($Plattform -eq 'windows') {
        return 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $wurzel + '\00_INDEX\scripts\' + $name + '.ps1"' + $rest
    }
    return '"' + $Pwsh + '" -NoProfile -File "' + $wurzel + '/00_INDEX/scripts/' + $name + '.ps1"' + $rest
}

# Geht alle Hook-Eintraege einer geladenen Datei durch und gibt die Liste der Aenderungen zurueck.
function Richte-Ein($json, [string]$wurzel, [switch]$MitOnFailure) {
    $aenderungen = @()
    if (-not $json.hooks) { return $aenderungen }
    foreach ($ereignis in $json.hooks.PSObject.Properties) {
        foreach ($gruppe in @($ereignis.Value)) {
            foreach ($h in @($gruppe.hooks)) {
                if (-not $h -or [string]$h.type -ne 'command') { continue }
                $cmd = [string]$h.command
                if ($cmd -notmatch $kernRx) { continue }
                $name = $matches[1]
                $rest = $matches[2]
                $neu = Neuer-Befehl $name $rest $wurzel
                if ($cmd -ne $neu) {
                    $h.command = $neu
                    $aenderungen += "$($ereignis.Name) / ${name}: Befehl fuer $Plattform"
                }
                if ($MitOnFailure -and $ereignis.Name -eq 'PreToolUse' -and $sperren -contains $name) {
                    if ([string]$h.onFailure -ne 'block') {
                        if ($h.PSObject.Properties['onFailure']) { $h.onFailure = 'block' }
                        else { $h | Add-Member -NotePropertyName onFailure -NotePropertyValue 'block' }
                        $aenderungen += "PreToolUse / ${name}: onFailure block"
                    }
                }
            }
        }
    }
    return $aenderungen
}

function Schreibe-Json($json, [string]$pfad) {
    $text = $json | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText($pfad, $text + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
}

$fehlt = $false
if (Test-Path -LiteralPath $Datei) {
    $json = Get-Content -LiteralPath $Datei -Raw -Encoding UTF8 | ConvertFrom-Json
    $wurzel = if ($Plattform -eq 'windows') { '${CLAUDE_PROJECT_DIR}' } else { '${CLAUDE_PROJECT_DIR}' }
    $a = @(Richte-Ein $json $wurzel -MitOnFailure)
    if ($a.Count -eq 0) { "Claude Code ($Datei): eingerichtet, nichts zu tun." }
    else {
        $fehlt = $true
        if ($Pruefen) { "Claude Code ($Datei): fehlt noch:"; $a | ForEach-Object { "  $_" } }
        else { Schreibe-Json $json $Datei; "Claude Code ($Datei): eingerichtet:"; $a | ForEach-Object { "  $_" } }
    }
} else { "Keine $Datei gefunden; nichts eingerichtet." ; $fehlt = $true }

if (Test-Path -LiteralPath $CodexDatei) {
    $cj = Get-Content -LiteralPath $CodexDatei -Raw -Encoding UTF8 | ConvertFrom-Json
    $b = @(Richte-Ein $cj $repo)
    if ($b.Count -eq 0) { "Codex ($CodexDatei): eingerichtet, nichts zu tun." }
    else {
        if ($Pruefen) { "Codex ($CodexDatei): fehlt noch:"; $b | ForEach-Object { "  $_" } }
        else { Schreibe-Json $cj $CodexDatei; "Codex ($CodexDatei): eingerichtet:"; $b | ForEach-Object { "  $_" }; "In Codex muss jeder Hook nach einer Aenderung in den Einstellungen wieder freigeschaltet werden (ANLEITUNG.md, Schritt 7b)." }
    }
}

# Claude Code kennt "onFailure" erst ab 2.1.295; aeltere Fassungen lassen einen Hook, der nicht
# startet, weiter durch.
$ErrorActionPreference = 'Continue'
$v = (& claude --version 2>$null | Select-Object -First 1)
$ErrorActionPreference = 'Stop'
if ($v -match '(\d+)\.(\d+)\.(\d+)') {
    $alt = ([int]$matches[1] -lt 2) -or ([int]$matches[1] -eq 2 -and ([int]$matches[2] -lt 1 -or ([int]$matches[2] -eq 1 -and [int]$matches[3] -lt 295)))
    if ($alt) { "Claude Code $($matches[0]) ist aelter als 2.1.295: Ein Hook, der nicht startet, sperrt dort noch nicht. Aktualisieren mit: claude update" }
}
if ($Pruefen -and $fehlt) { exit 1 }
exit 0
