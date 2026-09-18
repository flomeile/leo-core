# version-check.ps1
# Zweck: Die billigste Pruefung im ganzen System, als eigener Aufruf ohne Modell: Ist der
# eingespielte Kern (MEIN-SYSTEM.md, Abschnitt 4) hinter dem neuesten Tag des Grundgeruests
# auf GitHub? Eine Zeile Ausgabe, ein Zeitstempel in 10_System\version-check-last-run.txt.
#
# WARUM ES DAS GIBT (seit 4.0): Der Versions-Waechter im Health-Check meldet Rueckstand nur,
# wenn der Health-Check laeuft, und im Modus mitbauen startet den niemand von selbst. Die
# Grundpflege in der AGENTS.md (Abschnitt 1) ruft dieses Skript deshalb zu Beginn einer
# Session, sobald der letzte Lauf laenger als sieben Tage zurueckliegt, in beiden Modi.
# Kostet einen git-ls-remote-Aufruf; ohne Netz nur eine INFO-Zeile, nie ein Abbruch.
#
# AUFRUF: pwsh -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\version-check.ps1"
# AUSGABE (eine Zeile, maschinell lesbar am ersten Wort):
#   AKTUELL <Version>
#   RUECKSTAND eingespielt <X.Y> verfuegbar <Y.Z>
#   UNBEKANNT <Grund>
# Exitcode immer 0. ASCII-only, laeuft unter Windows PowerShell 5.1 und PowerShell 7.

$ErrorActionPreference = "Continue"
$repo = [System.IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$quelleRepo = "https://github.com/flomeile/leo-core"
$stempel = Join-Path $repo "10_System\version-check-last-run.txt"

try {
    Get-Date -Format "yyyy-MM-dd HH:mm" | Set-Content -Path $stempel -Encoding UTF8
} catch { }

$ms = Join-Path $repo "MEIN-SYSTEM.md"
if (-not (Test-Path $ms)) { "UNBEKANNT MEIN-SYSTEM.md fehlt"; exit 0 }
$msText = Get-Content -Path $ms -Raw -Encoding UTF8
$eingespielt = $null
if ($msText -match '(?m)^\|\s*Eingespielte Version\s*\|\s*([0-9]+\.[0-9]+)\s*\|') { $eingespielt = $Matches[1] }
if (-not $eingespielt) { "UNBEKANNT keine eingespielte Version in MEIN-SYSTEM.md Abschnitt 4 lesbar (Muster '| Eingespielte Version | X.Y |')"; exit 0 }

$tagsRaw = & git ls-remote --tags $quelleRepo 2>$null
if ($LASTEXITCODE -ne 0 -or -not $tagsRaw) { "UNBEKANNT kein Netz oder git ls-remote fehlgeschlagen (eingespielt $eingespielt)"; exit 0 }
$neueste = @($tagsRaw | ForEach-Object { if ($_ -match 'refs/tags/v([0-9]+\.[0-9]+)$') { [version]$Matches[1] } }) | Sort-Object | Select-Object -Last 1
if (-not $neueste) { "UNBEKANNT keine Tags gefunden"; exit 0 }
if ([version]$eingespielt -lt $neueste) { "RUECKSTAND eingespielt $eingespielt verfuegbar $neueste" } else { "AKTUELL $eingespielt" }
exit 0
