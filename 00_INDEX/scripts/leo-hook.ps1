# leo-hook.ps1
# Zweck: Verteiler fuer die Hooks aus den verwalteten Einstellungen (Haertung mit sperre-haerten.ps1,
# seit 5.1) und aus den persoenlichen Einstellungen (~/.claude/settings.json, eingerichtet von
# hooks-einrichten.ps1, seit 6.0). Laeuft aus einer Kopie der Sperren ausserhalb des Repos und startet
# von dort den eigentlichen Hook.
#
# DIE SPERREN GREIFEN IN JEDER SITZUNG DES RECHNERS (seit 6.0): Bis 5.3 liess dieser Verteiler alles
# durch, was nicht im Repo des Leo-Kinds lief; jede Sitzung in einem anderen Ordner lief damit ohne
# Sperre, auch fuer denselben Agenten mit denselben Zugangsdaten. Seither gilt:
#   - Im Repo des Leo-Kinds (und darunter, etwa in Arbeitsbaeumen) laufen alle Kern-Hooks wie bisher.
#   - In jedem anderen Projekt laufen nur die Sperren. Der Projektordner der Sitzung ist dort der
#     erlaubte Arbeitsbereich (samt "<Projekt> Archiv", "<Projekt> Artifacts" und Scratchpad); Zugangsdaten,
#     Mailversand, Fremdsysteme, Connectoren und Pushes bleiben gesperrt wie im Leo-Kind, und die
#     Freigabelisten des Leo-Kinds gelten auch dort. Ein zu weiter Projektordner (Laufwerk,
#     Benutzerordner, Ordner aller Benutzer) gibt keinen Arbeitsbereich her. Eigene Skripte eines fremden
#     Projekts laufen nie.
#
# WOHER DER HOOK KOMMT: Die Sperren (guard-*.ps1) aus der Kopie neben diesem Skript, damit der Agent sie
# nicht veraendern kann. Ihre Testschalter ueber Umgebungsvariablen werden vorher geleert, damit eine
# Einstellung im Repo sie nicht lockern kann. Fehlt eine Sperre in der Kopie, sperrt der Verteiler
# (Exit 2). Die uebrigen Kern-Hooks (eingehaengte-repos-aktuell, pruef-frontmatter, version-check) aus dem
# Repo selbst: Sie schuetzen nichts, und das Update soll sie ohne Adminrechte erneuern koennen.
#
# Eingabe: JSON auf stdin, wird an den Hook durchgereicht (derselbe Prozess liest sie).
# ASCII-only: laeuft unter Windows PowerShell 5.1 und PowerShell 7.
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][ValidateSet('guard-read', 'guard-workspace', 'guard-git', 'guard-mail', 'guard-fremdsysteme', 'guard-extern', 'eingehaengte-repos-aktuell', 'pruef-frontmatter', 'version-check')][string]$Skript,
    [string]$Hook = ''
)

$ErrorActionPreference = 'Stop'

# Unvollstaendige Kopie (seit 6.0, Zweitpruefung): Statt mit einem Ladefehler zu enden, sperrt der Verteiler mit
# einer Meldung, die sagt, wie die Kopie heilt. Exit 2 zeigt Claude Code die Meldung als Sperrgrund an.
$teile = @('lib\arbeitsbereich.ps1', 'lib\schutzliste.ps1', 'lib\eingehaengt-ausschluss.ps1', 'guard-read.ps1', 'guard-workspace.ps1', 'guard-git.ps1', 'guard-mail.ps1', 'guard-fremdsysteme.ps1', 'guard-extern.ps1')
$fehlt = @($teile | Where-Object { -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot ($_ -replace '\\', [string][System.IO.Path]::DirectorySeparatorChar))) })
if ($fehlt.Count -gt 0) {
    $imSystem = $PSScriptRoot -notmatch '[\\/]\.leo-sperren[\\/]'
    $weg = if ($imSystem) { 'Der Besitzer fuehrt sperre-haerten.ps1 in seinem eigenen Fenster erneut aus (Adminrechte).' } else { "Claude Code neu starten: Der Sessionstart stellt die Kopie ohne Netz wieder her. Sonst fuehrt der Besitzer in seinem eigenen Fenster aus: powershell -NoProfile -ExecutionPolicy Bypass -File `"$Repo\00_INDEX\scripts\hooks-einrichten.ps1`" -NurProfil" }
    [Console]::Error.WriteLine("Die Kopie der Sperren ist unvollstaendig (" + ($fehlt -join ', ') + " fehlt in $PSScriptRoot). Bis sie repariert ist, bleibt jeder Werkzeugaufruf gesperrt, absichtlich. $weg Sag das der Person in zwei Saetzen; du kannst es nicht selbst beheben.")
    exit 2
}
. (Join-Path (Join-Path $PSScriptRoot 'lib') 'arbeitsbereich.ps1')

$kind = (Normalize-AbsolutePath $Repo)
$zone = $kind
$nurSperren = $false
if ($env:CLAUDE_PROJECT_DIR -and -not (Test-PathWithin $env:CLAUDE_PROJECT_DIR $kind)) {
    $nurSperren = $true
    $proj = Normalize-AbsolutePath $env:CLAUDE_PROJECT_DIR
    $zone = if ((-not $proj) -or (Test-ZuWeit $proj)) { Join-Path (Join-Path $tempPath 'claude') 'leo-kein-projekt' } else { $proj }
}

foreach ($v in @('LEO_GUARD_FREIGABE_KONFIG', 'LEO_GUARD_READ_KONFIG')) {
    Remove-Item -Path ('Env:' + $v) -ErrorAction SilentlyContinue
}
$env:LEO_KIND_REPO = $kind

if ($Skript -like 'guard-*') {
    $ziel = Join-Path $PSScriptRoot ($Skript + '.ps1')
    if (-not (Test-Path -LiteralPath $ziel)) {
        [Console]::Error.WriteLine("Sperre $Skript fehlt in der Kopie ($PSScriptRoot). Der Besitzer fuehrt sperre-haerten.ps1 oder hooks-einrichten.ps1 erneut aus.")
        exit 2
    }
    if ($Skript -in @('guard-read', 'guard-workspace')) { & $ziel -Repo $zone }
    elseif ($Skript -in @('guard-git', 'guard-fremdsysteme')) { & $ziel -Repo $kind }
    else { & $ziel }
    exit $LASTEXITCODE
}

if ($nurSperren) { exit 0 }
$ziel = Join-Path (Join-Path (Join-Path $kind '00_INDEX') 'scripts') ($Skript + '.ps1')
if (-not (Test-Path -LiteralPath $ziel)) { exit 0 }
if ($Hook) { & $ziel -Hook $Hook } else { & $ziel }
exit $LASTEXITCODE
