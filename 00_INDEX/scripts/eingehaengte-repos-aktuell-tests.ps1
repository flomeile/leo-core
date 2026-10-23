# eingehaengte-repos-aktuell-tests.ps1
# Regressionsreihe fuer eingehaengte-repos-aktuell.ps1 mit echten Git-Repos in TEMP: aktuell, Rueckstand sauber auf main
# (nachziehen), Rueckstand mit lokalen Aenderungen (sperren), Rueckstand auf einem Zweig (melden), auseinandergelaufen
# (sperren), ohne Remote (sperren), Original nicht erreichbar (sperren), Hook-Ausgabe, 24-Stunden-Takt und Zeitstempel.
# Aufruf: pwsh -NoProfile -File eingehaengte-repos-aktuell-tests.ps1 [-Exe powershell]   Exit 0 = alle gruen.
# -Exe bestimmt, unter welchem Interpreter das gepruefte Skript laeuft; die Hooks in .claude\settings.json rufen
# powershell (5.1), deshalb beide fahren. ASCII-only.
param([string]$Exe = 'pwsh')
$ErrorActionPreference = 'Stop'
$skript = Join-Path $PSScriptRoot 'eingehaengte-repos-aktuell.ps1'
$w = Join-Path $env:TEMP ("repos-aktuell-tests-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force $w | Out-Null
$ok = 0; $fail = 0
function Check([string]$name, [bool]$cond, [string]$info = '') {
    if ($cond) { $script:ok++; Write-Output "OK    $name" } else { $script:fail++; Write-Output "FAIL  $name  $info" }
}
function G { param([Parameter(ValueFromRemainingArguments = $true)]$a) $ErrorActionPreference = 'Continue'; & git @a 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw "git $a" } }
function Lauf([string]$repo, [string]$hook = '', [string]$stand = (Join-Path $w 'stand.json')) {
    $ErrorActionPreference = 'Continue'
    # Ein leeres Argument laesst Windows PowerShell 5.1 beim Aufruf weg; -Stand deshalb nur, wenn gesetzt.
    $argumente = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $skript, '-Repo', $repo)
    if ($hook) { $argumente += @('-Hook', $hook) }
    if ($stand) { $argumente += @('-Stand', $stand) }
    if ($hook) { $out = '{}' | & $Exe @argumente 2>&1 } else { $out = & $Exe @argumente 2>&1 }
    return @{ text = (($out | ForEach-Object { "$_" }) -join "`n"); code = $LASTEXITCODE }
}
function Neu([string]$name) {
    $orig = Join-Path $w "orig-$name.git"; G init -q --bare -b main $orig
    $dev = Join-Path $w "dev-$name"; G clone -q $orig $dev
    G -C $dev config user.email t@example.com; G -C $dev config user.name T
    Set-Content -LiteralPath (Join-Path $dev 'a.md') 'eins'; G -C $dev add a.md; G -C $dev commit -q -m eins; G -C $dev push -q origin HEAD:main
    $repo = Join-Path $w "system-$name"; New-Item -ItemType Directory -Force (Join-Path $repo 'thema') | Out-Null
    $kopie = Join-Path $repo 'thema\geteilt'; G clone -q $orig $kopie
    G -C $kopie config user.email t@example.com; G -C $kopie config user.name T
    return @{ dev = $dev; repo = $repo; kopie = $kopie; orig = $orig }
}
function Vor($r) { Add-Content -LiteralPath (Join-Path $r.dev 'a.md') 'neu'; G -C $r.dev commit -q -am neu; G -C $r.dev push -q origin HEAD:main }

Write-Output "Interpreter: $Exe"
try {
    $r = Neu 'aktuell'
    $e = Lauf $r.repo; Check 'aktuell: keine Meldung, Exit 0' ($e.code -eq 0 -and -not $e.text) $e.text

    $r = Neu 'sauber'; Vor $r
    $e = Lauf $r.repo; Check 'Rueckstand sauber auf main: nachgezogen' ($e.code -eq 0 -and $e.text -match 'NACHGEZOGEN') $e.text
    Check 'Rueckstand sauber: Datei ist neu' ((Get-Content -LiteralPath (Join-Path $r.kopie 'a.md')) -contains 'neu')

    $r = Neu 'schmutzig'; Vor $r; Add-Content -LiteralPath (Join-Path $r.kopie 'a.md') 'lokal'
    $e = Lauf $r.repo; Check 'lokale Aenderungen: gesperrt, Exit 1' ($e.code -eq 1 -and $e.text -match 'GESPERRT.*ungespeicherte') $e.text
    Check 'lokale Aenderungen: nichts ueberschrieben' ((Get-Content -LiteralPath (Join-Path $r.kopie 'a.md')) -contains 'lokal')

    $r = Neu 'zweig'; G -C $r.kopie switch -q -c arbeit; Vor $r
    $e = Lauf $r.repo; Check 'Zweig: main nachgezogen, Zweig gemeldet' ($e.text -match 'ZWEIG' -and [int](git -C $r.kopie rev-list --count 'main..origin/main') -eq 0) $e.text

    $r = Neu 'auseinander'; Vor $r; Add-Content -LiteralPath (Join-Path $r.kopie 'b.md') 'x'; G -C $r.kopie add b.md; G -C $r.kopie commit -q -m lokal
    $e = Lauf $r.repo; Check 'auseinandergelaufen: gesperrt' ($e.code -eq 1 -and $e.text -match 'auseinandergelaufen') $e.text

    $r = Neu 'ohneremote'; G -C $r.kopie remote remove origin
    $e = Lauf $r.repo; Check 'ohne Remote: gesperrt' ($e.code -eq 1 -and $e.text -match 'kein Original') $e.text

    $r = Neu 'weg'; G -C $r.kopie remote set-url origin (Join-Path $w 'gibt-es-nicht.git')
    $e = Lauf $r.repo; Check 'Original nicht erreichbar: gesperrt' ($e.code -eq 1 -and $e.text -match 'nicht erreichbar') $e.text

    $r = Neu 'hook'; Vor $r
    $stand = Join-Path $w 'hook-stand.json'
    $e = Lauf $r.repo 'SessionStart' $stand
    $j = $e.text | ConvertFrom-Json
    Check 'SessionStart: Kontext fuer das Modell' ($j.hookSpecificOutput.hookEventName -eq 'SessionStart' -and $j.hookSpecificOutput.additionalContext -match 'NACHGEZOGEN') $e.text
    Vor $r
    $e = Lauf $r.repo 'UserPromptSubmit' $stand
    Check 'UserPromptSubmit innert 24 h: keine Pruefung' (-not $e.text) $e.text
    @{ zeit = (Get-Date).AddHours(-25).ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath $stand -Encoding UTF8
    $e = Lauf $r.repo 'UserPromptSubmit' $stand
    Check 'UserPromptSubmit nach 24 h: geprueft und nachgezogen' ($e.text -match 'NACHGEZOGEN') $e.text

    $r = Neu 'stempel'
    $e = Lauf $r.repo '' ''
    Check 'ohne -Stand: Zeitstempel in 10_System geschrieben' (Test-Path -LiteralPath (Join-Path $r.repo '10_System\eingehaengte-repos-last-run.txt')) $e.text
}
finally {
    Remove-Item -LiteralPath $w -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Output ""
Write-Output "$ok von $($ok + $fail) gruen"
if ($fail -gt 0) { exit 1 }
