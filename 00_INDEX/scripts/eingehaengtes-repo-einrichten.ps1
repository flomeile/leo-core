# Richtet ein geteiltes Repo, das als verschachtelter Ordner in diesem Repo liegt, fuer die Arbeit mit dem Assistenten ein
# (seit Leo Core 4.5, Skill leo-repo-einhaengen):
#   (1) Ordner im aeusseren .gitignore eintragen, damit der Inhalt nie ins eigene, private Repo gelangt, und in .ignore
#       wieder fuer die Suche freigeben, damit der Agent das Wissen darin findet
#   (2) im inneren Repo die Identitaet auf die geschaeftliche Adresse setzen (nie eine private, AGENTS.md Abschnitt 14)
#   (3) im inneren Repo drei Stubs in .git/hooks anlegen: pre-commit, commit-msg, pre-push; sie rufen den Sperrbegriff-Hook
#       00_INDEX/githooks/eingehaengt-pre-commit mit der eigenen Liste 00_INDEX/scripts/lib/wissensrepo-sperrbegriffe.txt
#   (4) die Einrichtung pruefen, auch dass der Hook wirklich laeuft
# Aufruf:  pwsh -File 00_INDEX\scripts\eingehaengtes-repo-einrichten.ps1 -Ordner "<Themenordner>\<repo>" -Email "<geschaeftliche Adresse>"
#          (Ordner relativ zu diesem Repo oder absolut; das innere Repo muss schon geklont sein; -Email ist Pflicht, damit nie
#          die globale Git-Adresse, oft eine private, in die Historie eines geteilten Repos gelangt.)
# Das Repo wird aus dem Ort dieses Skripts bestimmt; -Leo ueberschreibt das nur fuer Tests.
# ASCII-only mit Absicht: Ein .ps1 mit Umlauten in Strings braucht ein BOM, sonst liest PowerShell 5.1 falsch.
# Das Skript aendert im inneren Repo nur die lokale Git-Identitaet und .git/hooks, im eigenen Repo nur .gitignore.
param(
    [Parameter(Mandatory = $true)][string]$Ordner,
    [Parameter(Mandatory = $true)][string]$Email,
    [string]$Name = '',
    [string]$Leo = '',
    [switch]$Alleinstehend   # Repo liegt ausserhalb dieses Repos: nur Identitaet und Stubs, kein .gitignore
)
$ErrorActionPreference = 'Stop'
if (-not $Leo) { $Leo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }

$hookQuelle = (Resolve-Path (Join-Path $PSScriptRoot '..\githooks\eingehaengt-pre-commit')).Path
# Wie im Hook: LEO_WISSENSREPO_SPERRBEGRIFFE ersetzt die Liste (Tests), sonst die eigene Liste dieses Repos.
$liste = if ($env:LEO_WISSENSREPO_SPERRBEGRIFFE) { $env:LEO_WISSENSREPO_SPERRBEGRIFFE } else { Join-Path $PSScriptRoot 'lib\wissensrepo-sperrbegriffe.txt' }
if (-not (Test-Path -LiteralPath $liste)) { throw "Sperrbegriff-Liste nicht gefunden: $liste" }

# Die Adresse darf selbst keinen Sperrbegriff tragen (private Mailanbieter, private Konten).
$begriffe = Get-Content -LiteralPath $liste -Encoding UTF8 | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_.Trim() -ne '' -and -not $_.StartsWith('#') }
if (-not $begriffe) { throw "Sperrbegriff-Liste leer: $liste" }
$re = '(?i)(?<![\p{L}\p{N}])(?:' + (($begriffe | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')'
if ($Email -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { throw "Keine gueltige Mailadresse: $Email" }
if ($Email -match $re) { throw "Die Adresse $Email steht auf der Sperrliste (private Adresse?). Es braucht die geschaeftliche Adresse." }

$leoRoot = (Resolve-Path $Leo).Path.TrimEnd('\')
$inner = if ([IO.Path]::IsPathRooted($Ordner)) { $Ordner } else { Join-Path $leoRoot $Ordner }
$inner = (Resolve-Path $inner).Path.TrimEnd('\')
if (-not $Alleinstehend -and -not $inner.StartsWith($leoRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Ordner liegt nicht in $leoRoot : $inner (ausserhalb: -Alleinstehend)" }
if (-not (Test-Path (Join-Path $inner '.git'))) { throw "Kein eigenes Git-Repo im Ordner (kein .git): $inner" }
$rel = if ($Alleinstehend) { '' } else { $inner.Substring($leoRoot.Length + 1).Replace('\', '/') }

# Ein globales oder lokales core.hooksPath wuerde .git/hooks uebergehen: dann wirkt der Stub nicht.
$glob = (git config --global --get core.hooksPath 2>$null)
if ($glob) { throw "Globales core.hooksPath ist gesetzt ($glob): die Stubs in .git/hooks wuerden nicht laufen." }
$loc = (git -C $inner config --local --get core.hooksPath 2>$null)
if ($loc) { throw "Im inneren Repo ist core.hooksPath gesetzt ($loc): die Stubs in .git/hooks wuerden nicht laufen." }
# Vor jeder Aenderung: schon versionierte Dateien (check-ignore meldet sie sonst nur als "nicht ignoriert")
# und fremde Hooks, die ein Stub still ueberschreiben wuerde.
$tracked = if ($Alleinstehend) { $null } else { git -C $leoRoot ls-files -- $rel }
if ($tracked) { throw "Dateien aus $rel sind im aeusseren Repo schon versioniert (zuerst git rm -r --cached, den Besitzer fragen)." }
$stubs = [ordered]@{ 'pre-commit' = 'commit'; 'commit-msg' = 'msg'; 'pre-push' = 'push' }
foreach ($h in $stubs.Keys) {
    $p = Join-Path $inner ".git\hooks\$h"
    if ((Test-Path $p) -and -not ((Get-Content -Raw $p) -match 'eingehaengtes-repo-einrichten\.ps1')) {
        throw "Im inneren Repo liegt schon ein eigener $h-Hook: $p. Nicht ueberschrieben; den Besitzer fragen."
    }
}

# (1) aeusseres .gitignore
$gi = Join-Path $leoRoot '.gitignore'
$zeile = "/$rel/"
$inhalt = if (Test-Path $gi) { [IO.File]::ReadAllText($gi) } else { '' }
$zeilen = $inhalt -split "`r?`n"
if ($Alleinstehend) { Write-Host "gitignore: uebersprungen (-Alleinstehend)" }
elseif ($zeilen -notcontains $zeile) {
    $neu = $inhalt
    if ($neu -and -not $neu.EndsWith("`n")) { $neu += "`n" }
    $neu += "# Eingehaengtes geteiltes Repo (Skill leo-repo-einhaengen)`n$zeile`n"
    [IO.File]::WriteAllText($gi, $neu, (New-Object Text.UTF8Encoding $false))
    Write-Host "gitignore: $zeile eingetragen"
} else { Write-Host "gitignore: $zeile stand schon drin" }

# (1b) .ignore im eigenen Repo: gibt den Ordner fuer die Suche wieder frei. Suchwerkzeuge auf ripgrep-Basis (die Grep- und
# Glob-Werkzeuge der Agenten) ueberspringen alles, was in der .gitignore steht; ohne diese Zeile faende der Agent das Wissen
# im eingehaengten Repo nie. Git liest .ignore nicht, der Ordner bleibt fuer Git ignoriert.
if (-not $Alleinstehend) {
    $ig = Join-Path $leoRoot '.ignore'
    $frei = "!/$rel/"
    $igInhalt = if (Test-Path $ig) { [IO.File]::ReadAllText($ig) } else { '' }
    if (($igInhalt -split "`r?`n") -notcontains $frei) {
        $neuIg = $igInhalt
        if ($neuIg -and -not $neuIg.EndsWith("`n")) { $neuIg += "`n" }
        if (-not $igInhalt) { $neuIg += "# Suchfreigabe fuer eingehaengte Repos (Skill leo-repo-einhaengen): ripgrep liest diese Datei, Git nicht.`n" }
        $neuIg += "$frei`n"
        [IO.File]::WriteAllText($ig, $neuIg, (New-Object Text.UTF8Encoding $false))
        Write-Host ".ignore: $frei eingetragen (Suche findet den Ordner)"
    } else { Write-Host ".ignore: $frei stand schon drin" }
}

# (2) Identitaet nur lokal im inneren Repo
git -C $inner config --local user.email $Email
if ($Name) { git -C $inner config --local user.name $Name }
elseif (-not (git -C $inner config --get user.name)) { throw "Kein Name bekannt: -Name angeben." }
Write-Host "Identitaet im inneren Repo: $(git -C $inner config user.name) <$(git -C $inner config user.email)>"

# (3) Stubs im inneren Repo, LF, ohne BOM
$hookUnix = $hookQuelle.Replace('\', '/')
New-Item -ItemType Directory -Force -Path (Join-Path $inner '.git\hooks') | Out-Null
foreach ($h in $stubs.Keys) {
    $p = Join-Path $inner ".git\hooks\$h"
    $text = "#!/bin/sh`n# Stub von eingehaengtes-repo-einrichten.ps1, nicht committen, liegt in .git`nexec sh `"$hookUnix`" $($stubs[$h]) `"`$@`"`n"
    [IO.File]::WriteAllText($p, $text, (New-Object Text.UTF8Encoding $false))
    Write-Host "Stub: $p"
}

# (4) Pruefung
if (-not $Alleinstehend) {
    git -C $leoRoot check-ignore -q $rel 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Pruefung fehlgeschlagen: $rel wird vom aeusseren Repo nicht ignoriert." }
}
foreach ($h in $stubs.Keys) { if (-not (Test-Path (Join-Path $inner ".git\hooks\$h"))) { throw "Stub $h fehlt." } }
git -C $inner hook run --ignore-missing pre-commit 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Selbsttest fehlgeschlagen: der pre-commit-Hook laeuft im inneren Repo nicht sauber (Exit $LASTEXITCODE)." }
Write-Host "OK: $(if ($Alleinstehend) { $inner } else { "$rel ist eingehaengt, ignoriert und" }) gesichert (pre-commit, commit-msg, pre-push; Selbsttest bestanden)."
Write-Host "Noch zu klaeren (Regel, nicht Skript): Owner- und Modus-Zeile in der AGENTS.md des Repos, Stand abgleichen mit git -C vor jeder Arbeit."
