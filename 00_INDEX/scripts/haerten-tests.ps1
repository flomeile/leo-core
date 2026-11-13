# haerten-tests.ps1
# Zweck: Regressionstest fuer die Haertung der Standardsperre (seit 5.1): hooks-einrichten.ps1
# (Hook-Befehle je Plattform, "onFailure": "block"), sperre-haerten.ps1 (verwaltete Einstellungen
# und Schutzkopie) und den Verteiler leo-hook.ps1.
#
# PFLICHT: vor und nach jeder Aenderung an einem der drei Skripte oder an lib\arbeitsbereich.ps1,
# unter beiden Interpretern (Datei einmal mit pwsh, einmal mit powershell starten).
#
# AUFRUF (schreibt nur in einen Testordner im Temp-Verzeichnis, nie in den Systemordner, und fordert
# nie Administratorrechte an):
#   pwsh -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\haerten-tests.ps1"
#   powershell -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\haerten-tests.ps1" -Exe powershell
#
# UNGEPRUEFT AUF DIESER PLATTFORM: Die Faelle mit "posix" im Namen pruefen nur die erzeugten
# Befehle fuer macOS/Linux als Text. Ob sie auf einem Mac starten, zeigt erst ein Lauf dort; bis
# dahin gelten sie als ungeprueft. Ebenso die Sandbox-Einstellungen und die echte Rechteerhoehung.
# Bewusst ASCII-only.
param([string]$Exe = "")

$isWindowsHost = [System.IO.Path]::DirectorySeparatorChar -eq '\'
. (Join-Path (Join-Path $PSScriptRoot 'lib') 'arbeitsbereich.ps1')
$repo = Normalize-AbsolutePath (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$psExe = (Get-Command $(if ($isWindowsHost) { 'pwsh.exe' } else { 'pwsh' }) -ErrorAction SilentlyContinue).Source
if (-not $psExe -and $isWindowsHost) { $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source }
if ($Exe) { $psExe = (Get-Command $Exe -ErrorAction SilentlyContinue).Source }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$tmp = Join-Path $tempPath ('haerten-tests-' + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$sys = Join-Path $tmp 'System Ordner'
$desktop = Join-Path $homePath 'Desktop'
$fehler = 0; $anzahl = 0
function Pruef([string]$name, $ist, $soll) {
    $script:anzahl++
    $ok = ([string]$ist -eq [string]$soll)
    if (-not $ok) { $script:fehler++ }
    "{0,-52} {1,-12} {2,-12} {3}" -f $name, $soll, $ist, $(if ($ok) { "ok" } else { "ABWEICHUNG" })
}
function Starte([string]$skript, [string]$argumente, [string]$eingabe = '', [hashtable]$umgebung = @{}) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$skript`" $argumente"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $utf8
    foreach ($k in $umgebung.Keys) { $psi.EnvironmentVariables[$k] = $umgebung[$k] }
    $p = [System.Diagnostics.Process]::Start($psi)
    if ($eingabe) { $b = $utf8.GetBytes($eingabe); $p.StandardInput.BaseStream.Write($b, 0, $b.Length) }
    $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return @{ code = $p.ExitCode; out = $out }
}
function Urteil($r) {
    if ($r.out -match '"permissionDecision"\s*:\s*"deny"') { return 'DENY' }
    if ([string]::IsNullOrWhiteSpace($r.out)) { return 'PASS' }
    return 'FEHLER'
}

"Interpreter:   $psExe"
"Testordner:    $tmp"
""
"{0,-52} {1,-12} {2,-12} {3}" -f "Fall", "Soll", "Ist", "Urteil"
"-" * 90

# --- hooks-einrichten.ps1 ------------------------------------------------------------------------
$einrichten = Join-Path $PSScriptRoot 'hooks-einrichten.ps1'
$alt = @'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Read|Bash", "hooks": [ { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PROJECT_DIR}\\00_INDEX\\scripts\\guard-read.ps1\"" } ] },
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "echo eigener-hook" } ] }
    ],
    "SessionStart": [ { "hooks": [ { "type": "command", "timeout": 90, "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PROJECT_DIR}\\00_INDEX\\scripts\\eingehaengte-repos-aktuell.ps1\" -Hook SessionStart" } ] } ]
  },
  "permissions": { "deny": [ "Read(**/.env)" ] }
}
'@
$sw = Join-Path $tmp 'settings-win.json'; [System.IO.File]::WriteAllText($sw, $alt, $utf8)
$sp = Join-Path $tmp 'settings-posix.json'; [System.IO.File]::WriteAllText($sp, $alt, $utf8)
$keinCodex = Join-Path $tmp 'gibt-es-nicht.json'
$r = Starte $einrichten "-Plattform windows -Datei `"$sw`" -CodexDatei `"$keinCodex`" -Pruefen"
Pruef "1 Pruefen meldet fehlendes onFailure" $r.code "1"
$r = Starte $einrichten "-Plattform windows -Datei `"$sw`" -CodexDatei `"$keinCodex`""
$j = Get-Content -LiteralPath $sw -Raw -Encoding UTF8 | ConvertFrom-Json
Pruef "2 Windows: Sperre hat onFailure block" ([string]$j.hooks.PreToolUse[0].hooks[0].onFailure) "block"
Pruef "3 Windows: Befehl bleibt powershell" ([string]$j.hooks.PreToolUse[0].hooks[0].command -like 'powershell -NoProfile*guard-read.ps1"') "True"
Pruef "4 Eigener Hook unveraendert" ([string]$j.hooks.PreToolUse[1].hooks[0].command) "echo eigener-hook"
Pruef "5 Eigener Hook ohne onFailure" ([string]$j.hooks.PreToolUse[1].hooks[0].onFailure) ""
Pruef "6 SessionStart ohne onFailure" ([string]$j.hooks.SessionStart[0].hooks[0].onFailure) ""
Pruef "7 permissions bleiben" ([string]$j.permissions.deny[0]) "Read(**/.env)"
$r = Starte $einrichten "-Plattform windows -Datei `"$sw`" -CodexDatei `"$keinCodex`" -Pruefen"
Pruef "8 Zweiter Lauf: nichts mehr zu tun" $r.code "0"
$r = Starte $einrichten "-Plattform posix -Pwsh /opt/homebrew/bin/pwsh -Datei `"$sp`" -CodexDatei `"$keinCodex`""
$j = Get-Content -LiteralPath $sp -Raw -Encoding UTF8 | ConvertFrom-Json
Pruef "9 posix (ungeprueft): Befehl mit pwsh-Pfad" ([string]$j.hooks.PreToolUse[0].hooks[0].command) '"/opt/homebrew/bin/pwsh" -NoProfile -File "${CLAUDE_PROJECT_DIR}/00_INDEX/scripts/guard-read.ps1"'
Pruef "10 posix (ungeprueft): -Hook bleibt" ([string]$j.hooks.SessionStart[0].hooks[0].command -like '*eingehaengte-repos-aktuell.ps1" -Hook SessionStart') "True"
Pruef "11 posix (ungeprueft): onFailure block" ([string]$j.hooks.PreToolUse[0].hooks[0].onFailure) "block"
$cx = Join-Path $tmp 'codex.json'
[System.IO.File]::WriteAllText($cx, '{ "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"PFAD-ZU-DEINEM-REPO\\00_INDEX\\scripts\\guard-read.ps1\"" } ] } ] } }', $utf8)
$r = Starte $einrichten "-Plattform windows -Datei `"$sw`" -CodexDatei `"$cx`""
$j = Get-Content -LiteralPath $cx -Raw -Encoding UTF8 | ConvertFrom-Json
Pruef "12 Codex: Platzhalter durch Repo ersetzt" ([string]$j.hooks.PreToolUse[0].hooks[0].command -like ('*"' + $repo + '\00_INDEX\scripts\guard-read.ps1"')) "True"
Pruef "13 Codex: kein onFailure" ([string]$j.hooks.PreToolUse[0].hooks[0].onFailure) ""

# --- sperre-haerten.ps1 im Testordner -----------------------------------------------------------
$haerten = Join-Path $PSScriptRoot 'sperre-haerten.ps1'
$ort = Get-HaertungsOrt $repo $sys
$r = Starte $haerten "-Ziel `"$sys`""
Pruef "20 Einrichten im Testordner" $r.code "0"
$d = Get-Content -LiteralPath $ort.dropin -Raw -Encoding UTF8 | ConvertFrom-Json
Pruef "21 allowManagedHooksOnly" ([string]$d.allowManagedHooksOnly) "True"
$lese = @($d.hooks.PreToolUse | ForEach-Object { $_.hooks } | Where-Object { $_.command -like '*-Skript guard-read' })
Pruef "22 Lese-Sperre ueber Verteiler" $lese.Count "1"
Pruef "23 Lese-Sperre mit onFailure block" ([string]$lese[0].onFailure) "block"
Pruef "24 Verteiler aus der Schutzkopie" ([string]$lese[0].command -like ('*' + $ort.kopie + '*leo-hook.ps1" -Repo "' + $repo + '"*')) "True"
$start = @($d.hooks.SessionStart | ForEach-Object { $_.hooks })
Pruef "25 SessionStart uebernommen mit -Hook" ([string]$start[0].command -like '*-Skript eingehaengte-repos-aktuell -Hook SessionStart') "True"
Pruef "26 SessionStart ohne onFailure" ([string]$start[0].onFailure) ""
Pruef "26b Versionspruefung ueber Verteiler mit -Hook (seit 5.3)" (@($start | Where-Object { [string]$_.command -like '*-Skript version-check -Hook SessionStart' }).Count) "1"
Pruef "27 Deny fuer Freigabeliste" (@($d.permissions.deny) -contains 'Edit(**/00_INDEX/freigegebene-pfade.txt)') "True"
Pruef "28 Schutzkopie hat Lese-Sperre und Logik" ((Test-Path -LiteralPath (Join-Path $ort.kopie '00_INDEX/scripts/guard-read.ps1')) -and (Test-Path -LiteralPath (Join-Path $ort.kopie '00_INDEX/scripts/lib/arbeitsbereich.ps1'))) "True"
$r = Starte $haerten "-Ziel `"$sys`" -Pruefen"
Pruef "29 Stand aktuell" ($r.out -match 'Stand:\s+aktuell') "True"

# --- Verteiler aus der Schutzkopie ---------------------------------------------------------------
$verteiler = Join-Path (Join-Path (Join-Path $ort.kopie '00_INDEX') 'scripts') 'leo-hook.ps1'
$eingabe = (@{ tool_name = 'Read'; cwd = $repo; tool_input = @{ file_path = (Join-Path $desktop 'x.md') } } | ConvertTo-Json -Compress -Depth 5)
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-read" $eingabe @{ CLAUDE_PROJECT_DIR = $repo }
Pruef "30 Leo-Kind: Lesen ausserhalb gesperrt" (Urteil $r) "DENY"
$r = Starte $verteiler "-Repo `"$repo`" -Skript version-check -Hook SessionStart" '{"source":"compact"}' @{ CLAUDE_PROJECT_DIR = $repo }
Pruef "30b Verteiler startet die Versionspruefung (seit 5.3)" $r.code "0"
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-read" $eingabe @{ CLAUDE_PROJECT_DIR = (Join-Path $tmp 'anderes Projekt') }
Pruef "31 Anderes Projekt: nichts gesperrt" (Urteil $r) "PASS"
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-read" $eingabe @{ CLAUDE_PROJECT_DIR = (Join-Path (Join-Path $repo '.claude') 'worktrees\a') }
Pruef "32 Arbeitsbaum im Repo: gesperrt" (Urteil $r) "DENY"
$frei = Join-Path $tmp 'Freigabe Test'
[System.IO.File]::WriteAllLines((Join-Path $ort.kopie '00_INDEX/freigegebene-pfade.txt'), [string[]]@("lesen: $frei"), $utf8)
$eingabeFrei = (@{ tool_name = 'Read'; cwd = $repo; tool_input = @{ file_path = (Join-Path $frei 'a.md') } } | ConvertTo-Json -Compress -Depth 5)
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-read" $eingabeFrei @{ CLAUDE_PROJECT_DIR = $repo }
Pruef "33 Freigabe aus der Schutzkopie gilt" (Urteil $r) "PASS"
$eingabeW = (@{ tool_name = 'Write'; cwd = $repo; tool_input = @{ file_path = (Join-Path $desktop 'x.md') } } | ConvertTo-Json -Compress -Depth 5)
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-workspace" $eingabeW @{ CLAUDE_PROJECT_DIR = $repo }
Pruef "34 Schreiben ausserhalb gesperrt" (Urteil $r) "DENY"
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-read" '{"tool_name":"Bash","cwd":"x","tool_input":{"command":"cat .env"}}' @{ CLAUDE_PROJECT_DIR = $repo }
Pruef "35 Zugangsdaten gesperrt" (Urteil $r) "DENY"
$r = Starte $haerten "-Ziel `"$sys`" -Pruefen"
Pruef "36 Abweichende Liste: veraltet" ($r.out -match 'veraltet' -and $r.out -match 'freigegebene-pfade') "True"
$r = Starte $haerten "-Ziel `"$sys`" -NurListen"
$r = Starte $haerten "-Ziel `"$sys`" -Pruefen"
Pruef "37 Nach -NurListen wieder aktuell" ($r.out -match 'Stand:\s+aktuell') "True"
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-read" $eingabeFrei @{ CLAUDE_PROJECT_DIR = $repo }
Pruef "38 Freigabe nach Uebernahme wieder zu" (Urteil $r) "DENY"
Remove-Item -LiteralPath (Join-Path $ort.kopie '00_INDEX/scripts/lib/arbeitsbereich.ps1') -Force
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-read" $eingabe @{ CLAUDE_PROJECT_DIR = $repo }
Pruef "39 Kaputte Schutzkopie: Fehlercode, nicht 0" ($r.code -ne 0) "True"
$r = Starte $haerten "-Ziel `"$sys`" -Entfernen"
Pruef "40 Entfernen" ((Test-Path -LiteralPath $ort.dropin) -or (Test-Path -LiteralPath $ort.kopie)) "False"
$r = Starte $haerten "-Ziel `"$sys`" -Pruefen"
Pruef "41 Danach Stand fehlt" ($r.out -match 'Stand:\s+fehlt') "True"

# --- Nur der Besitzer, nie aus einer Session -------------------------------------------------------
$r = Starte $haerten "" "j`n"
# Im Repo des Herausgebers (Release-Gate gesetzt) bricht es schon davor ab, mit Exit 3.
$istHerausgeber = [bool](& git -C $repo config --get leo.releaseGate 2>$null)
Pruef "42 Nie aus einer Session, nie beim Herausgeber" $r.code $(if ($istHerausgeber) { "3" } else { "2" })

Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
""
if ($fehler -eq 0) { "ALLE $anzahl FAELLE BESTANDEN"; exit 0 }
else { "$fehler VON $anzahl FAELLEN ABWEICHEND"; exit 1 }
