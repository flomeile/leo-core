<#
.SYNOPSIS
    Wegwerf-Kopie des Repos fuer die kalten Prueflaeufe (Skill leo-system-optimierung, seit 4.3).

.DESCRIPTION
    Regel: Fiktiver Testinhalt kommt nie ins echte Repo, auch nicht voruebergehend. Ein Prueffall
    arbeitet mit erfundenen Eingaben; haelt der Pruefling sie fuer echt, schreibt er sie in eine
    Wissensdatei oder committet sie, und ein automatischer Sync kann den Stand uebernehmen, bevor
    jemand zurueckbaut. Deshalb laufen die Prueffaelle in einer Kopie unter
    "<Repo> Artifacts\_Cache\pruefkopie", nie im Repo selbst.

    Die Kopie ist ein flacher Klon (--depth 1) des letzten Commits: keine Historie, wenige Sekunden
    fuer das Anlegen, der Aufwand waechst nur mit dem Arbeitsbaum. Offene, nicht committete
    Aenderungen sind bewusst nicht dabei.

    Warum das dicht ist: Die Hooks in .claude\settings.json laufen ueber ${CLAUDE_PROJECT_DIR}, also
    aus der Kopie, und guard-workspace.ps1 leitet seinen Repo-Pfad aus dem eigenen Ort ab. In der
    Kopie ist deshalb nur die Kopie selbst beschreibbar; das echte Repo, der Artefakte-Ordner und das
    Archiv liegen ausserhalb und werden blockiert. Der Remote wird entfernt, damit ein Test-Commit
    nirgends hingeht.

.EXAMPLE
    pwsh -NoProfile -File 00_INDEX\scripts\pruefkopie.ps1 -Modus anlegen
    pwsh -NoProfile -File 00_INDEX\scripts\pruefkopie.ps1 -Modus loeschen
#>
param([Parameter(Mandatory)][ValidateSet('anlegen', 'loeschen')][string]$Modus)

$ErrorActionPreference = 'Stop'
$repo = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)).TrimEnd('\', '/')
$ziel = Join-Path (Join-Path (Join-Path (Split-Path -Parent $repo) ((Split-Path -Leaf $repo) + ' Artifacts')) '_Cache') 'pruefkopie'

if (Test-Path -LiteralPath $ziel) {
    Remove-Item -LiteralPath $ziel -Recurse -Force
}
if ($Modus -eq 'loeschen') {
    "Pruefkopie geloescht: $ziel"
    exit 0
}

$quelle = 'file:///' + (($repo -replace '\\', '/').TrimStart('/'))
git clone -q --depth 1 --single-branch $quelle $ziel
if ($LASTEXITCODE -ne 0) { throw "Klon fehlgeschlagen ($LASTEXITCODE)" }
git -C $ziel remote remove origin
$commit = git -C $ziel log -1 --format='%h %s'
"Pruefkopie angelegt: $ziel (Stand $commit, ohne Remote)"
