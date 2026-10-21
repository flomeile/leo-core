# Hilfsfunktionen fuer eingehaengte Repos (seit 4.5, Skill leo-repo-einhaengen).
# Ein eingehaengtes Repo ist ein Ordner mit eigenem .git unterhalb dieses Repos (ein geteiltes Wissensrepo, das andere
# Personen besitzen). Der Index fuehrt es sichtbar markiert als fremdes Repo, damit der Agent es findet; die eigenen
# Pruefungen (Frontmatter, kuratierte Beschreibungen, Links) wenden die Regeln dieses Systems nie darauf an, sondern der
# Health-Check prueft es in der Kategorie "Eingehaengte Repos" nach den Regeln eines geteilten Repos.
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

# Kurzname des Originals (organisation/repo): upstream, sonst origin, sonst der Ordnername. Fuer die Markierung im Index.
function Get-EingehaengtQuelle {
    param([Parameter(Mandatory = $true)][string]$Ordner)
    $url = [string](git -C $Ordner remote get-url upstream 2>$null)
    if (-not $url) { $url = [string](git -C $Ordner remote get-url origin 2>$null) }
    if (-not $url) { return (Split-Path -Leaf $Ordner) }
    return (($url -replace '\.git$', '') -replace '^.*[:/]([^/:]+/[^/:]+)$', '$1')
}

# Stand gegen das Original: holt upstream (Fork-Weg) oder origin (Owner-Weg) und zaehlt, wie viele Commits auf dessen main
# lokal fehlen. Rueckgabe: Zahl, oder $null, wenn nicht abrufbar (kein Netz, kein Remote).
function Get-EingehaengtRueckstand {
    param([Parameter(Mandatory = $true)][string]$Ordner)
    $quelle = if (git -C $Ordner remote get-url upstream 2>$null) { 'upstream' } elseif (git -C $Ordner remote get-url origin 2>$null) { 'origin' } else { return $null }
    git -C $Ordner fetch -q $quelle 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    $ziel = "$quelle/main"
    git -C $Ordner rev-parse -q --verify $ziel 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { $ziel = "$quelle/master"; git -C $Ordner rev-parse -q --verify $ziel 2>$null | Out-Null; if ($LASTEXITCODE -ne 0) { return $null } }
    $lokal = if (git -C $Ordner rev-parse -q --verify main 2>$null) { 'main' } else { 'HEAD' }
    return [int](git -C $Ordner rev-list --count "$lokal..$ziel" 2>$null)
}

# Tote relative Links in den Markdown-Dateien eines eingehaengten Repos (Ziel existiert nicht im Repo). Externe Adressen,
# reine Anker und Mailadressen zaehlen nicht, Vorlagen-Ordner (templates, vorlagen) auch nicht: Dort sind Links Platzhalter. Rueckgabe: Liste "datei -> ziel".
function Get-EingehaengtToteLinks {
    param([Parameter(Mandatory = $true)][string]$Ordner)
    $tot = New-Object System.Collections.Generic.List[string]
    $dateien = @(Get-ChildItem -LiteralPath $Ordner -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notmatch '\\(templates?|vorlagen?)\\' })
    foreach ($f in $dateien) {
        $text = [IO.File]::ReadAllText($f.FullName)
        foreach ($m in [regex]::Matches($text, '\]\(([^)\s]+)\)')) {
            $ziel = $m.Groups[1].Value
            if ($ziel -match '^(https?:|mailto:|#|[a-z]+://)') { continue }
            $ziel = ($ziel -split '#')[0]
            if (-not $ziel) { continue }
            $ziel = [uri]::UnescapeDataString($ziel).Replace('/', '\')
            if (-not (Test-Path -LiteralPath (Join-Path $f.DirectoryName $ziel))) {
                $tot.Add(($f.FullName.Substring($Ordner.Length + 1).Replace('\', '/')) + ' -> ' + $m.Groups[1].Value)
            }
        }
    }
    return $tot
}

# Regex fuer Skripte, die mit einem Ausschlussmuster auf FullName arbeiten (-notmatch); leer, wenn nichts eingehaengt ist.
function Get-EingehaengtMuster {
    $teile = @($EingehaengteOrdner | ForEach-Object { [regex]::Escape($_ + '\') })
    if ($teile.Count -eq 0) { return '' }
    return '(?:' + ($teile -join '|') + ')'
}
