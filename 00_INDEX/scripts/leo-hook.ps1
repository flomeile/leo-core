# leo-hook.ps1
# Zweck: Verteiler fuer die Hooks in den verwalteten Einstellungen (Haertung mit sperre-haerten.ps1,
# AGENTS.md Abschnitt 18, seit 5.1). Laeuft aus der Schutzkopie, die nur mit Adminrechten zu
# aendern ist, und startet von dort den eigentlichen Hook.
#
# WARUM ES DAS GIBT: Verwaltete Einstellungen gelten fuer jede Claude-Code-Sitzung auf diesem
# Rechner, in jedem Projekt. Die Sperren des Leo-Kinds sollen aber nur im Repo des Leo-Kinds
# greifen; wer daneben in einem anderen Projekt arbeitet, soll davon nichts merken. Dieser
# Verteiler prueft deshalb zuerst, in welchem Projekt die Sitzung laeuft, und laesst alles durch,
# was nicht das Leo-Kind ist (stiller Exitcode 0).
#
# WOHER DER HOOK KOMMT: Die vier Sperren (guard-*.ps1) aus der Schutzkopie neben diesem Skript,
# damit der Agent sie nicht veraendern kann; sie bekommen -Repo und lesen die Freigabelisten aus
# der Schutzkopie. Die uebrigen Kern-Hooks (eingehaengte-repos-aktuell, pruef-frontmatter, seit 5.3 version-check) aus dem
# Repo selbst: Sie schuetzen nichts, und das Update soll sie ohne Adminrechte erneuern koennen.
#
# Eingabe: JSON auf stdin, wird an den Hook durchgereicht (derselbe Prozess liest sie).
# ASCII-only: laeuft unter Windows PowerShell 5.1 und PowerShell 7.
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][ValidateSet('guard-read', 'guard-workspace', 'guard-git', 'guard-mail', 'eingehaengte-repos-aktuell', 'pruef-frontmatter', 'version-check')][string]$Skript,
    [string]$Hook = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path $PSScriptRoot 'lib') 'arbeitsbereich.ps1')

# Nur im Leo-Kind: Projekt der Sitzung muss das Repo sein oder darin liegen (Arbeitsbaeume).
if ($env:CLAUDE_PROJECT_DIR -and -not (Test-PathWithin $env:CLAUDE_PROJECT_DIR $Repo)) { exit 0 }

if ($Skript -like 'guard-*') {
    $ziel = Join-Path $PSScriptRoot ($Skript + '.ps1')
    if ($Skript -in @('guard-read', 'guard-workspace')) { & $ziel -Repo $Repo }
    else { & $ziel }
} else {
    $ziel = Join-Path (Join-Path (Join-Path $Repo '00_INDEX') 'scripts') ($Skript + '.ps1')
    if (-not (Test-Path -LiteralPath $ziel)) { exit 0 }
    if ($Hook) { & $ziel -Hook $Hook } else { & $ziel }
}
exit $LASTEXITCODE
