# version-check-tests.ps1
# Regressionsreihe fuer version-check.ps1 (Versionspruefung und Mitteilungen, seit 5.3) mit echten Git-Repos in
# TEMP: aktuell und Rueckstand von Hand und als Hook, beide Nutzungsmodi, Widerspruch zwischen MEIN-SYSTEM.md und
# AGENTS.md, fehlende Version, kein Netz, 24-Stunden-Takt, Mitteilungen neu, schon gelesen, leer, nicht abrufbar,
# mehr als drei, Umlaute, Steuerzeichen, Repo des Herausgebers, LEO_GRUNDPFLEGE=aus, Verdichtung, dazu die
# Hook-Einrichtung fuer Windows und macOS/Linux mit der echten .claude\settings.json.
# Aufruf: pwsh -NoProfile -File version-check-tests.ps1 [-Exe powershell]   Exit 0 = alle gruen.
# -Exe bestimmt, unter welchem Interpreter das gepruefte Skript laeuft; die Hooks in .claude\settings.json rufen
# powershell (5.1), deshalb beide fahren. ASCII-only; Umlaute in Testdaten entstehen ueber [char].
param([string]$Exe = 'pwsh')
$ErrorActionPreference = 'Stop'
$skript = Join-Path $PSScriptRoot 'version-check.ps1'
$repoEcht = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$w = Join-Path ([System.IO.Path]::GetTempPath()) ("version-check-tests-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force $w | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
# Claude Code liest die Hook-Ausgabe als UTF-8; der Testtreiber dekodiert sie deshalb genauso.
[Console]::OutputEncoding = $utf8
$ok = 0; $fail = 0
function Check([string]$name, [bool]$cond, [string]$info = '') {
    if ($cond) { $script:ok++; Write-Output "OK    $name" } else { $script:fail++; Write-Output "FAIL  $name  $info" }
}
function G { param([Parameter(ValueFromRemainingArguments = $true)]$a) $ErrorActionPreference = 'Continue'; & git @a 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw "git $a" } }

# Quelle: ein Bare-Repo mit Tags, wie GitHub es per git ls-remote zeigt.
function Quelle([string]$name, [string[]]$tags) {
    $q = Join-Path $w "quelle-$name.git"; G init -q --bare -b main $q
    $d = Join-Path $w "quelle-dev-$name"; G init -q -b main $d
    G -C $d config user.email t@example.com; G -C $d config user.name T
    [System.IO.File]::WriteAllText((Join-Path $d 'a.md'), 'x', $utf8); G -C $d add a.md; G -C $d commit -q -m x
    foreach ($t in $tags) { G -C $d tag $t }
    G -C $d push -q $q main --tags
    return $q
}
# Ein Kind-System: MEIN-SYSTEM.md mit Versionstabelle und Modus, AGENTS.md mit Frontmatter-Version.
function Kind([string]$name, [string]$eingespielt, [string]$agents, [string]$modus = 'benutzen') {
    $r = Join-Path $w "kind-$name"; New-Item -ItemType Directory -Force (Join-Path $r '10_System') | Out-Null
    G init -q -b main $r
    $zeile = if ($eingespielt) { "| Eingespielte Version | $eingespielt |" } else { "| Eingespielte Version | *(trag hier ein)* |" }
    [System.IO.File]::WriteAllText((Join-Path $r 'MEIN-SYSTEM.md'), "# Mein System`n`n- **Nutzungsmodus:** $modus`n`n## 4. Version`n`n| | |`n|---|---|`n$zeile`n", $utf8)
    [System.IO.File]::WriteAllText((Join-Path $r 'AGENTS.md'), "---`ntitel: AGENTS.md`nversion: $agents`n---`n`n# Regeln`n", $utf8)
    return $r
}
function Mitteilungen([string]$name, [string[]]$zeilen) {
    $p = Join-Path $w "mitteilungen-$name.md"
    [System.IO.File]::WriteAllText($p, ("---`ntitel: Mitteilungen`n---`n`n# Mitteilungen`n`n" + ($zeilen -join "`n") + "`n"), $utf8)
    return $p
}
function Lauf([string]$repo, [string]$quelle, [string]$mitt, [switch]$Hook, [string]$eingabe = '{"source":"startup"}') {
    $ErrorActionPreference = 'Continue'
    $argumente = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $skript, '-Repo', $repo, '-Quelle', $quelle, '-Mitteilungen', $mitt)
    if ($Hook) { $argumente += @('-Hook', 'SessionStart'); $out = $eingabe | & $Exe @argumente 2>&1 } else { $out = & $Exe @argumente 2>&1 }
    $text = (($out | ForEach-Object { "$_" }) -join "`n").Trim()
    $kontext = ''
    if ($Hook -and $text) { try { $kontext = [string](($text | ConvertFrom-Json).hookSpecificOutput.additionalContext) } catch { $kontext = 'KEIN-JSON: ' + $text } }
    return @{ text = $text; kontext = $kontext; code = $LASTEXITCODE }
}
function Stempel([string]$repo) { Join-Path $repo '10_System\version-check-last-run.txt' }
function Gelesen([string]$repo) { $p = Join-Path $repo '10_System\mitteilungen-last-run.txt'; if (Test-Path -LiteralPath $p) { @(Get-Content -LiteralPath $p -Encoding UTF8) } else { @() } }
function StempelSetzen([string]$repo, [datetime]$zeit, [string]$neueste) {
    [System.IO.File]::WriteAllLines((Stempel $repo), [string[]]@($zeit.ToString('yyyy-MM-dd HH:mm'), "neueste $neueste"), $utf8)
}

$ae = [string][char]0x00E4; $ue = [string][char]0x00FC
Write-Output "Interpreter: $Exe"
try {
    $q = Quelle 'std' @('v5.1', 'v5.2', 'v5.3')
    $q10 = Quelle 'zehn' @('v5.9', 'v5.10')
    $weg = Join-Path $w 'gibt-es-nicht.git'
    $leer = Join-Path $repoEcht 'MITTEILUNGEN.md'
    $keine = Join-Path $w 'keine-mitteilungen.md'

    # --- Von Hand (Rueckfall ohne Hook) -----------------------------------------------------------
    $k = Kind 'hand-aktuell' '5.3' '5.3'
    $e = Lauf $k $q $leer
    Check '01 Hand aktuell: AKTUELL 5.3' ($e.text -eq 'AKTUELL 5.3' -and $e.code -eq 0) $e.text
    Check '02 Hand: Zeitstempel zweizeilig (Zeit, neueste 5.3)' ((Get-Content -LiteralPath (Stempel $k))[1] -eq 'neueste 5.3') ((Get-Content -LiteralPath (Stempel $k)) -join '|')
    $k = Kind 'hand-rueck' '5.2' '5.2'
    $e = Lauf $k $q $leer
    Check '03 Hand Rueckstand: erste Zeile unveraendert' ($e.text -eq 'RUECKSTAND eingespielt 5.2 verfuegbar 5.3') $e.text
    $k = Kind 'hand-zehn' '5.9' '5.9'
    $e = Lauf $k $q10 $leer
    Check '04 Versionssortierung: 5.10 ist neuer als 5.9' ($e.text -eq 'RUECKSTAND eingespielt 5.9 verfuegbar 5.10') $e.text
    $k = Kind 'hand-netz' '5.2' '5.2'
    $e = Lauf $k $weg $leer
    Check '05 Hand ohne Netz: UNBEKANNT, Exit 0' ($e.text -like 'UNBEKANNT kein Netz*' -and $e.code -eq 0) $e.text
    Check '06 Hand ohne Netz: kein Zeitstempel' (-not (Test-Path -LiteralPath (Stempel $k)))
    $m = Mitteilungen 'hand' @('- **M1** (2026-11-13): Erste Mitteilung.')
    $k = Kind 'hand-mitt' '5.3' '5.3'
    $e = Lauf $k $q $m
    Check '07 Hand: Mitteilung als eigene Zeile' ($e.text -eq "AKTUELL 5.3`nMITTEILUNG M1 (2026-11-13): Erste Mitteilung.") $e.text

    # --- Hook: Version ----------------------------------------------------------------------------
    $k = Kind 'hook-aktuell' '5.3' '5.3'
    $e = Lauf $k $q $leer -Hook
    Check '08 Hook aktuell, keine Mitteilung: keine Ausgabe' (-not $e.text -and $e.code -eq 0) $e.text
    $k = Kind 'hook-benutzen' '5.2' '5.2' 'benutzen'
    $e = Lauf $k $q $leer -Hook
    Check '09 Hook Rueckstand (benutzen): Auftrag ohne Rueckfrage' ($e.kontext -match 'RUECKSTAND, eingespielt 5\.2, verfuegbar 5\.3' -and $e.kontext -match 'ohne zu fragen' -and $e.kontext -match 'leo-mechanik-update') $e.text
    Check '10 Hook Rueckstand: Satz an die Person nennt die Zielversion' ($e.kontext -match "Ich spiele zuerst Core 5\.3 ein") $e.kontext
    Check '11 Hook: gueltiges JSON mit hookEventName SessionStart' ((($e.text | ConvertFrom-Json).hookSpecificOutput.hookEventName) -eq 'SessionStart') $e.text
    $k = Kind 'hook-mitbauen' '5.2' '5.2' 'mitbauen'
    $e = Lauf $k $q $leer -Hook
    Check '12 Hook Rueckstand (mitbauen): derselbe Auftrag' ($e.kontext -match 'ohne zu fragen und in beiden Nutzungsmodi') $e.text
    $k = Kind 'hook-widerspruch' '2.4' '5.3'
    $e = Lauf $k $q $leer -Hook
    Check '13 Auslieferungswert 2.4 bei AGENTS 5.3: kein Auftrag, nur Hinweis' ($e.kontext -match 'Widerspruch' -and $e.kontext -notmatch 'Spiel das Update') $e.kontext
    $k = Kind 'hook-ohneversion' '' '5.2'
    $e = Lauf $k $q $leer -Hook
    Check '14 Keine lesbare Version: kein Auftrag, nur Hinweis' ($e.kontext -match 'keine eingespielte Version' -and $e.kontext -notmatch 'Spiel das Update') $e.kontext
    $k = Kind 'hook-netz' '5.2' '5.2'
    $e = Lauf $k $weg $leer -Hook
    Check '15 Hook ohne Netz: eine Hinweiszeile, kein Auftrag' ($e.kontext -match 'nicht moeglich' -and $e.kontext -notmatch 'Spiel das Update' -and $e.kontext -notmatch 'Mitteilung') $e.kontext
    Check '16 Hook ohne Netz: kein Zeitstempel (naechster Start prueft erneut)' (-not (Test-Path -LiteralPath (Stempel $k)))

    # --- Hook: 24-Stunden-Takt ----------------------------------------------------------------------
    $k = Kind 'takt' '5.2' '5.2'
    StempelSetzen $k (Get-Date).AddHours(-2) '5.3'
    $e = Lauf $k $weg $leer -Hook
    Check '17 Innert 24 h ohne Netz: Rueckstand aus dem Stand, Auftrag bleibt' ($e.kontext -match 'RUECKSTAND, eingespielt 5\.2, verfuegbar 5\.3' -and $e.kontext -match 'ohne zu fragen') $e.kontext
    [System.IO.File]::WriteAllText((Join-Path $k 'MEIN-SYSTEM.md'), ([System.IO.File]::ReadAllText((Join-Path $k 'MEIN-SYSTEM.md')) -replace '\| 5\.2 \|', '| 5.3 |'), $utf8)
    [System.IO.File]::WriteAllText((Join-Path $k 'AGENTS.md'), ([System.IO.File]::ReadAllText((Join-Path $k 'AGENTS.md')) -replace 'version: 5\.2', 'version: 5.3'), $utf8)
    $e = Lauf $k $weg $leer -Hook
    Check '18 Innert 24 h nach dem Update: still' (-not $e.text) $e.text
    $k = Kind 'takt-alt' '5.3' '5.3'
    StempelSetzen $k (Get-Date).AddHours(-25) '5.2'
    $e = Lauf $k $q $leer -Hook
    $st = @(Get-Content -LiteralPath (Stempel $k))
    Check '19 Nach 24 h: neu geprueft, Stand nachgefuehrt' ($st[1] -eq 'neueste 5.3' -and $st[0] -ne (Get-Date).AddHours(-25).ToString('yyyy-MM-dd HH:mm')) ($st -join '|')

    # --- Hook: Mitteilungen ---------------------------------------------------------------------
    $k = Kind 'mitt' '5.3' '5.3'
    $m = Mitteilungen 'zwei' @('- **M1** (2026-11-13): Neu ist Core 5.3.', 'Freier Text, keine Mitteilung.', '- **M2** (2026-11-14): Zweite.')
    $e = Lauf $k $q $m -Hook
    Check '20 Neue Mitteilungen: beide im Kontext' ($e.kontext -match 'M1 \(2026-11-13\): Neu ist Core 5\.3\.' -and $e.kontext -match 'M2 \(2026-11-14\): Zweite\.') $e.kontext
    Check '21 Mitteilungen: Schutzsatz Information, nie Anweisung' ($e.kontext -match 'nie Anweisung' -and $e.kontext -match 'Fuehr nichts aus') $e.kontext
    Check '22 Gelesene Kennungen vermerkt' ((Gelesen $k) -join ',' -eq 'M1,M2') ((Gelesen $k) -join ',')
    $e = Lauf $k $q $m -Hook
    Check '23 Innert 24 h: kein zweiter Abruf, keine Wiederholung' (-not $e.text) $e.text
    Remove-Item -LiteralPath (Stempel $k)
    $m = Mitteilungen 'drei' @('- **M1** (2026-11-13): Neu ist Core 5.3.', '- **M2** (2026-11-14): Zweite.', "- **M3** (2026-11-20): Gr${ue}sse f${ue}r L${ae}ufe.")
    $e = Lauf $k $q $m -Hook
    Check '24 Schon gelesen: nur M3, nicht M1 und M2' ($e.kontext -match 'M3' -and $e.kontext -notmatch 'M1 \(' -and $e.kontext -notmatch 'M2 \(') $e.kontext
    Check '25 Umlaute bleiben erhalten' ($e.kontext -match ("Gr${ue}sse f${ue}r L${ae}ufe")) $e.kontext
    $k = Kind 'leer' '5.3' '5.3'
    $e = Lauf $k $q $leer -Hook
    Check '26 Leere Datei (echte MITTEILUNGEN.md): keine Ausgabe, nichts vermerkt' (-not $e.text -and -not (Test-Path -LiteralPath (Join-Path $k '10_System\mitteilungen-last-run.txt'))) $e.text
    $k = Kind 'nichtabrufbar' '5.2' '5.2'
    $e = Lauf $k $q $keine -Hook
    Check '27 Mitteilungen nicht abrufbar: Hinweis, Versionsauftrag bleibt' ($e.kontext -match 'nicht abrufbar' -and $e.kontext -match 'Spiel das Update') $e.kontext
    $k = Kind 'fuenf' '5.3' '5.3'
    $m = Mitteilungen 'fuenf' @(1..5 | ForEach-Object { "- **M$_** (2026-11-1$_): Nummer $_." })
    $e = Lauf $k $q $m -Hook
    Check '28 Mehr als drei neu: nur die drei neuesten' ($e.kontext -match 'M3 \(' -and $e.kontext -match 'M5 \(' -and $e.kontext -notmatch 'M2 \(') $e.kontext
    Check '29 Mehr als drei neu: alle als gelesen vermerkt' ((Gelesen $k).Count -eq 5) ((Gelesen $k) -join ',')
    $k = Kind 'lang' '5.3' '5.3'
    $m = Mitteilungen 'lang' @('- **M7** (2026-11-13): ' + ('x' * 400))
    $e = Lauf $k $q $m -Hook
    Check '30 Ueberlange Mitteilung: auf 300 Zeichen gekuerzt' ($e.kontext -match 'x{300} \[gekuerzt\]' -and $e.kontext -notmatch 'x{301}') ''

    # --- Hook: wann er schweigt --------------------------------------------------------------------
    $k = Kind 'herausgeber' '5.2' '5.2'
    G -C $k config leo.releaseGate 'C:/irgendwo/gate.ps1'
    $e = Lauf $k $q $m -Hook
    Check '31 Repo des Herausgebers: still, kein Zeitstempel' (-not $e.text -and -not (Test-Path -LiteralPath (Stempel $k))) $e.text
    $k = Kind 'ohnebedienung' '5.2' '5.2'
    $env:LEO_GRUNDPFLEGE = 'aus'
    try { $e = Lauf $k $q $m -Hook } finally { Remove-Item Env:LEO_GRUNDPFLEGE }
    Check '32 LEO_GRUNDPFLEGE=aus: still' (-not $e.text) $e.text
    $e = Lauf $k $q $m -Hook '{"source":"compact"}'
    Check '33 Nach Verdichtung (compact): still' (-not $e.text) $e.text
    $e = Lauf $k $q $leer -Hook '{"source":"resume"}'
    Check '34 Fortgesetzte Session (resume): Auftrag kommt' ($e.kontext -match 'Spiel das Update') $e.kontext

    # --- Einrichtung der Hooks mit der echten settings.json -----------------------------------------
    $einrichten = Join-Path $PSScriptRoot 'hooks-einrichten.ps1'
    foreach ($pl in @('windows', 'posix')) {
        $sp = Join-Path $w "settings-$pl.json"; Copy-Item -LiteralPath (Join-Path $repoEcht '.claude\settings.json') -Destination $sp
        $cx = Join-Path $w "keine-codex-$pl.json"
        $ErrorActionPreference = 'Continue'
        $null = & $Exe -NoProfile -ExecutionPolicy Bypass -File $einrichten -Plattform $pl -Pwsh '/opt/homebrew/bin/pwsh' -Datei $sp -CodexDatei $cx 2>&1
        $ErrorActionPreference = 'Stop'
        $j = Get-Content -LiteralPath $sp -Raw -Encoding UTF8 | ConvertFrom-Json
        $vc = @($j.hooks.SessionStart | ForEach-Object { $_.hooks } | Where-Object { $_.command -like '*version-check.ps1*' })
        $soll = if ($pl -eq 'windows') { 'powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PROJECT_DIR}\00_INDEX\scripts\version-check.ps1" -Hook SessionStart' } else { '"/opt/homebrew/bin/pwsh" -NoProfile -File "${CLAUDE_PROJECT_DIR}/00_INDEX/scripts/version-check.ps1" -Hook SessionStart' }
        Check "35 Einrichtung ${pl}: Versionspruefung unter SessionStart, Befehl fuer die Plattform" ($vc.Count -eq 1 -and [string]$vc[0].command -eq $soll) ([string]$vc[0].command)
        Check "36 Einrichtung ${pl}: kein onFailure (blockiert nie)" (-not $vc[0].PSObject.Properties['onFailure']) ''
    }
    # Ein Kind vor 5.3 hat den Eintrag nicht; ein Modell, das ihn ueber die Shell schreibt, kann ihn beschaedigen
    # (kalter Update-Lauf 13.11.2026: NUL statt "\0", Tabulator statt "\v"). Beides repariert hooks-einrichten.ps1.
    $alt = Join-Path $w 'settings-ohne.json'
    $j = Get-Content -LiteralPath (Join-Path $repoEcht '.claude\settings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $j.hooks.SessionStart[0].hooks = @($j.hooks.SessionStart[0].hooks | Where-Object { $_.command -notlike '*version-check*' })
    [System.IO.File]::WriteAllText($alt, ($j | ConvertTo-Json -Depth 30), $utf8)
    $ErrorActionPreference = 'Continue'
    $null = & $Exe -NoProfile -ExecutionPolicy Bypass -File $einrichten -Plattform windows -Datei $alt -CodexDatei (Join-Path $w 'keine.json') -Pruefen 2>&1
    $codePruefen = $LASTEXITCODE
    $null = & $Exe -NoProfile -ExecutionPolicy Bypass -File $einrichten -Plattform windows -Datei $alt -CodexDatei (Join-Path $w 'keine.json') 2>&1
    $ErrorActionPreference = 'Stop'
    Check '37 Einrichtung -Pruefen: fehlender Eintrag gemeldet (Exit 1)' ($codePruefen -eq 1) "$codePruefen"
    $j = Get-Content -LiteralPath $alt -Raw -Encoding UTF8 | ConvertFrom-Json
    $start = @($j.hooks.SessionStart | ForEach-Object { $_.hooks })
    Check '38 Einrichtung: fehlender Eintrag ergaenzt, eingehaengte Repos bleibt' (@($start | Where-Object { $_.command -like '*version-check.ps1" -Hook SessionStart' }).Count -eq 1 -and @($start | Where-Object { $_.command -like '*eingehaengte-repos-aktuell.ps1*' }).Count -eq 1) (($start | ForEach-Object { $_.command }) -join ' | ')
    $kaputt = Join-Path $w 'settings-kaputt.json'
    $text = [System.IO.File]::ReadAllText((Join-Path $repoEcht '.claude\settings.json'), $utf8)
    $text = $text.Replace('\\00_INDEX\\scripts\\version-check.ps1', '\u0000_INDEX\\scripts\u000bersion-check.ps1')
    [System.IO.File]::WriteAllText($kaputt, $text, $utf8)
    $ErrorActionPreference = 'Continue'
    $null = & $Exe -NoProfile -ExecutionPolicy Bypass -File $einrichten -Plattform windows -Datei $kaputt -CodexDatei (Join-Path $w 'keine.json') 2>&1
    $ErrorActionPreference = 'Stop'
    $j = Get-Content -LiteralPath $kaputt -Raw -Encoding UTF8 | ConvertFrom-Json
    $start = @($j.hooks.SessionStart | ForEach-Object { $_.hooks })
    $heil = @($start | Where-Object { [string]$_.command -eq 'powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PROJECT_DIR}\00_INDEX\scripts\version-check.ps1" -Hook SessionStart' })
    $krank = @($start | Where-Object { [string]$_.command -match '[\x00-\x1F]' })
    Check '39 Einrichtung: beschaedigter Eintrag ersetzt (genau ein heiler, kein kaputter)' ($heil.Count -eq 1 -and $krank.Count -eq 0) (($start | ForEach-Object { $_.command }) -join ' | ')
}
finally {
    Remove-Item -LiteralPath $w -Recurse -Force -ErrorAction SilentlyContinue
}
""
if ($fail -eq 0) { "ALLE $ok FAELLE BESTANDEN"; exit 0 } else { "$fail VON $($ok + $fail) FAELLEN ABWEICHEND"; exit 1 }
