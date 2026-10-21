# Ausschluss eingehaengter Repos aus Laeufen, die das Dateisystem durchsuchen (seit 4.5, Skill leo-repo-einhaengen).
# Ein eingehaengtes Repo ist ein Ordner mit eigenem .git unterhalb dieses Repos (ein geteiltes Wissensrepo, das andere
# Personen besitzen). Sein Inhalt gehoert anderen und steht im eigenen Index und Health-Check nichts zu: Der Index wuerde
# fremdes Wissen als eigenes ausgeben, der Health-Check wuerde es als eigene Dateien bemaengeln.
# Dot-source:  . (Join-Path $PSScriptRoot 'lib\eingehaengt-ausschluss.ps1'); $EingehaengteOrdner = @(Get-EingehaengteOrdner $repo)
# Danach pro Treffer:  Test-EingehaengtPfad $_.FullName   (wahr = ausschliessen).
# ASCII-only mit Absicht: Ein .ps1 mit Umlauten in Strings braucht ein BOM, sonst liest PowerShell 5.1 falsch.

function Get-EingehaengteOrdner {
    param([Parameter(Mandatory = $true)][string]$Repo)
    $root = $Repo.TrimEnd('\')
    Get-ChildItem -LiteralPath $root -Directory -Recurse -Force -Filter '.git' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne (Join-Path $root '.git') -and $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notmatch '\\\.claude\\' } |
        ForEach-Object { $_.Parent.FullName }
}

# Vergleicht den Pfad mit der Liste in $EingehaengteOrdner des aufrufenden Skripts.
function Test-EingehaengtPfad {
    param([Parameter(Mandatory = $true)][string]$Pfad)
    foreach ($o in $EingehaengteOrdner) {
        if ($Pfad.Equals($o, [StringComparison]::OrdinalIgnoreCase) -or $Pfad.StartsWith($o + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

# Regex fuer Skripte, die mit einem Ausschlussmuster auf FullName arbeiten (-notmatch); leer, wenn nichts eingehaengt ist.
function Get-EingehaengtMuster {
    $teile = @($EingehaengteOrdner | ForEach-Object { [regex]::Escape($_ + '\') })
    if ($teile.Count -eq 0) { return '' }
    return '(?:' + ($teile -join '|') + ')'
}
