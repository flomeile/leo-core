# schutzliste.ps1
# Zweck: Gemeinsame Logik fuer die Sperre der Fremdsysteme (guard-fremdsysteme.ps1, seit 6.0), die
# Versionspruefung und den Health-Check: Welche Repos sind eingehaengt, was steht in ihren Schutzlisten,
# und ist die Firmenschicht eingehaengt, die eine Organisation verlangt.
#
# SCHUTZLISTE: Ein eingehaengtes Repo (Skill leo-repo-einhaengen) kann im Wurzelordner eine Datei
# schutzliste.txt tragen. Jede Zeile ist eine Angabe, # ist Kommentar:
#   adresse: <host oder host/pfad>     dorthin schreibt der Agent nur ueber ein Werkzeug mit Freigabefenster
#   schluessel: <dateiname, * erlaubt>  Schluesseldatei, die der Agent nie liest, schreibt oder nennt
#   werkzeug: <pfad im Repo>           das Werkzeug mit Freigabefenster, ueber das geschrieben werden darf
#   werkzeug: <org/repo>:<pfad>        dasselbe in einem anderen eingehaengten Repo (seit dem Schlusstest von 6.0)
# Schluessel selbst liegen nie in einem Repo, nur ihr Dateiname steht hier.
# Gelesen wird die Fassung auf GitHub (upstream, sonst origin; Zweig HEAD, main oder master), nicht die
# Arbeitskopie: Was der Agent im Ordner aendert, lockert die Liste nicht. Die Datei im Ordner kann sie nur
# verschaerfen (ihre Adressen und Schluessel gelten zusaetzlich, ihre Werkzeuge nie).
#
# FIRMENSCHICHT: Setzt eine Organisation in ihrer zentralen Richtlinie die Umgebungsvariable
# LEO_FIRMENSCHICHT (Adresse oder organisation/repo), muss dieses Repo eingehaengt sein (AGENTS.md
# Abschnitt 16). Ohne die Variable gibt es keine Pflicht.
#
# ZWISCHENSPEICHER: Die Suche nach eingehaengten Repos laeuft durch das ganze Repo und waere bei jedem
# Werkzeugaufruf zu langsam. Ihr Ergebnis liegt deshalb bis zu zehn Minuten in <Temp>/leo-schutzliste,
# ausserhalb des Arbeitsbereichs, den der Agent beschreiben darf.
# ASCII-only: laeuft unter Windows PowerShell 5.1 und PowerShell 7.

. (Join-Path $PSScriptRoot 'eingehaengt-ausschluss.ps1')

$schutzCacheOrdner = Join-Path ([System.IO.Path]::GetTempPath().TrimEnd('\', '/')) 'leo-schutzliste'
$schutzCacheMinuten = 10

function Invoke-SchutzGit([string]$ordner, [string[]]$argumente) {
    $alt = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $o = & git -C $ordner @argumente 2>$null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $alt
    if ($code -ne 0) { return $null }
    return (@($o) -join "`n")
}

# organisation/repo in Kleinbuchstaben aus einer Adresse oder einer Kurzform.
function Get-RepoKurzname([string]$angabe) {
    if (-not $angabe) { return '' }
    $a = (($angabe.Trim() -replace '\\', '/') -replace '\.git$', '').TrimEnd('/')
    if ($a -match '([^/:\s]+)/([^/:\s]+)$') { return ($matches[1] + '/' + $matches[2]).ToLower() }
    return $a.ToLower()
}

function ConvertFrom-SchutzlisteText([string]$text) {
    $e = @{ adressen = @(); schluessel = @(); werkzeuge = @() }
    if (-not $text) { return $e }
    foreach ($z in ($text -split "`r?`n")) {
        $l = ($z -split '#')[0].Trim()
        if ($l -match '^(?i)(adresse|schluessel|werkzeug)\s*:\s*(\S.*)$') {
            $wert = $matches[2].Trim()
            switch ($matches[1].ToLower()) {
                'adresse'    { $e.adressen += $wert.ToLower() }
                'schluessel' { $e.schluessel += $wert }
                'werkzeug'   { $e.werkzeuge += ($wert -replace '\\', '/') }
            }
        }
    }
    return $e
}

# Die Fassung der Schutzliste auf GitHub (Remote-Stand upstream, sonst origin; HEAD, main oder master).
# $null, wenn das Repo noch nie abgeglichen wurde (kein Remote-Stand); '' bei Stand ohne Datei.
function Read-SchutzlisteRemote([string]$ordner) {
    $remote = if (Invoke-SchutzGit $ordner @('remote', 'get-url', 'upstream')) { 'upstream' } else { 'origin' }
    foreach ($ref in @("$remote/HEAD", "$remote/main", "$remote/master")) {
        $t = Invoke-SchutzGit $ordner @('show', ($ref + ':schutzliste.txt'))
        if ($null -ne $t) { return $t }
        if ($null -ne (Invoke-SchutzGit $ordner @('rev-parse', '--verify', '--quiet', $ref))) { return '' }
    }
    return $null
}

function Get-SchutzStand([string]$repo, [switch]$Frisch) {
    $slug = ($repo -replace '[^A-Za-z0-9]', '-').Trim('-')
    # -v2: seit der Zweitpruefung von 6.0 tragen die Werkzeuge ihren vollen Pfad und die Repos den Abgleich.
    # -v3: seit dem Schlusstest von 6.0 auch Werkzeuge in einem anderen eingehaengten Repo (<org/repo>:<pfad>).
    $datei = Join-Path $schutzCacheOrdner ($slug + '-v3.json')
    if (-not $Frisch -and (Test-Path -LiteralPath $datei)) {
        try {
            $alter = ((Get-Date) - (Get-Item -LiteralPath $datei).LastWriteTime).TotalMinutes
            if ($alter -lt $schutzCacheMinuten) {
                $c = [System.IO.File]::ReadAllText($datei) | ConvertFrom-Json
                return @{ repos = @($c.repos); adressen = @($c.adressen); schluessel = @($c.schluessel); werkzeuge = @($c.werkzeuge) }
            }
        } catch { }
    }
    $stand = @{ repos = @(); adressen = @(); schluessel = @(); werkzeuge = @() }
    $listen = @()
    foreach ($o in @(Get-EingehaengteOrdner $repo)) {
        $url = Invoke-SchutzGit $o @('remote', 'get-url', 'upstream')
        if (-not $url) { $url = Invoke-SchutzGit $o @('remote', 'get-url', 'origin') }
        $fern = Read-SchutzlisteRemote $o
        $stand.repos += [pscustomobject]@{ pfad = [string]$o; quelle = (Get-RepoKurzname $url); abgeglichen = ($null -ne $fern) }
        # Die Datei im Ordner kann die Liste nur verschaerfen: Adressen und Schluessel aus ihr gelten zusaetzlich,
        # Werkzeuge (der Durchlass) nur aus der Fassung auf GitHub. Ein Werkzeug gilt mit seinem vollen Pfad
        # im eingehaengten Repo, nicht ueber das Ende eines beliebigen Pfads.
        $datei1 = Join-Path $o 'schutzliste.txt'
        $lokal = if (Test-Path -LiteralPath $datei1) { ConvertFrom-SchutzlisteText ([System.IO.File]::ReadAllText($datei1)) } else { ConvertFrom-SchutzlisteText '' }
        $l = ConvertFrom-SchutzlisteText ([string]$fern)
        $stand.adressen += @($l.adressen) + @($lokal.adressen)
        $stand.schluessel += @($l.schluessel) + @($lokal.schluessel)
        $listen += @{ ordner = [string]$o; werkzeuge = @($l.werkzeuge) }
    }
    # Werkzeuge erst, wenn alle Repos bekannt sind: "werkzeug: <org/repo>:<pfad>" (seit dem Schlusstest von 6.0) meint
    # ein Werkzeug in einem anderen eingehaengten, abgeglichenen Repo, etwa wenn die Firmenschicht die Werkzeuge der
    # Fachagenten nennt; "werkzeug: <pfad>" wie bisher eines im eigenen Repo der Liste. Nie ein absoluter Pfad, nie "..".
    foreach ($e in $listen) {
        foreach ($w in @($e.werkzeuge)) {
            if (-not $w) { continue }
            $basis = $e.ordner
            $rel = $w
            if ($w -match '^([^/:\s]+/[^/:\s]+):(.+)$') {
                $soll = (Get-RepoKurzname $matches[1])
                $rel = $matches[2].Trim()
                $basis = $null
                foreach ($r in @($stand.repos)) { if ([string]$r.quelle -eq $soll -and $r.abgeglichen -eq $true) { $basis = [string]$r.pfad; break } }
                if (-not $basis) { continue }
            }
            if ($rel -match '(^|/)\.\.(/|$)' -or $rel -match '^([A-Za-z]:|/)') { continue }
            try { $stand.werkzeuge += (([System.IO.Path]::GetFullPath((Join-Path $basis $rel))) -replace '\\', '/') } catch { }
        }
    }
    try {
        New-Item -ItemType Directory -Force -Path $schutzCacheOrdner | Out-Null
        $json = [pscustomobject]$stand | ConvertTo-Json -Depth 5 -Compress
        [System.IO.File]::WriteAllText($datei, $json, (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
    return $stand
}

# Kurzname der verlangten Firmenschicht, leer ohne Pflicht.
function Get-FirmenschichtSoll { return (Get-RepoKurzname ([string]$env:LEO_FIRMENSCHICHT)) }

function Test-FirmenschichtFehlt($stand) {
    $soll = Get-FirmenschichtSoll
    if (-not $soll) { return $false }
    # Eingehaengt heisst: ein Klon mit Remote-Stand, nicht nur ein Ordner mit passender Adresse (git init plus
    # remote add genuegt nicht).
    foreach ($r in @($stand.repos)) { if ([string]$r.quelle -eq $soll -and $r.abgeglichen -eq $true) { return $false } }
    return $true
}
