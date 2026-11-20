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
$r = Starte $einrichten "-OhneProfil -Plattform windows -Datei `"$sw`" -CodexDatei `"$keinCodex`" -Pruefen"
Pruef "1 Pruefen meldet fehlendes onFailure" $r.code "1"
$r = Starte $einrichten "-OhneProfil -Plattform windows -Datei `"$sw`" -CodexDatei `"$keinCodex`""
$j = Get-Content -LiteralPath $sw -Raw -Encoding UTF8 | ConvertFrom-Json
Pruef "2 Windows: Sperre hat onFailure block" ([string]$j.hooks.PreToolUse[0].hooks[0].onFailure) "block"
Pruef "3 Windows: Befehl bleibt powershell" ([string]$j.hooks.PreToolUse[0].hooks[0].command -like 'powershell -NoProfile*guard-read.ps1"') "True"
Pruef "4 Eigener Hook unveraendert" ([string]$j.hooks.PreToolUse[1].hooks[0].command) "echo eigener-hook"
Pruef "5 Eigener Hook ohne onFailure" ([string]$j.hooks.PreToolUse[1].hooks[0].onFailure) ""
Pruef "6 SessionStart ohne onFailure" ([string]$j.hooks.SessionStart[0].hooks[0].onFailure) ""
Pruef "7 permissions bleiben" ([string]$j.permissions.deny[0]) "Read(**/.env)"
$r = Starte $einrichten "-OhneProfil -Plattform windows -Datei `"$sw`" -CodexDatei `"$keinCodex`" -Pruefen"
Pruef "8 Zweiter Lauf: nichts mehr zu tun" $r.code "0"
$r = Starte $einrichten "-OhneProfil -Plattform posix -Pwsh /opt/homebrew/bin/pwsh -Datei `"$sp`" -CodexDatei `"$keinCodex`""
$j = Get-Content -LiteralPath $sp -Raw -Encoding UTF8 | ConvertFrom-Json
Pruef "9 posix (ungeprueft): Befehl mit pwsh-Pfad" ([string]$j.hooks.PreToolUse[0].hooks[0].command) '"/opt/homebrew/bin/pwsh" -NoProfile -File "${CLAUDE_PROJECT_DIR}/00_INDEX/scripts/guard-read.ps1"'
Pruef "10 posix (ungeprueft): -Hook bleibt" ([string]$j.hooks.SessionStart[0].hooks[0].command -like '*eingehaengte-repos-aktuell.ps1" -Hook SessionStart') "True"
Pruef "11 posix (ungeprueft): onFailure block" ([string]$j.hooks.PreToolUse[0].hooks[0].onFailure) "block"
$cx = Join-Path $tmp 'codex.json'
[System.IO.File]::WriteAllText($cx, '{ "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"PFAD-ZU-DEINEM-REPO\\00_INDEX\\scripts\\guard-read.ps1\"" } ] } ] } }', $utf8)
$r = Starte $einrichten "-OhneProfil -Plattform windows -Datei `"$sw`" -CodexDatei `"$cx`""
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
$anderes = Join-Path $tmp 'anderes Projekt'
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-read" $eingabe @{ CLAUDE_PROJECT_DIR = $anderes }
Pruef "31 Anderes Projekt: Lesen ausserhalb gesperrt (6.0)" (Urteil $r) "DENY"
$eingabeP = (@{ tool_name = 'Write'; cwd = $anderes; tool_input = @{ file_path = (Join-Path $anderes 'a.md') } } | ConvertTo-Json -Compress -Depth 5)
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-workspace" $eingabeP @{ CLAUDE_PROJECT_DIR = $anderes }
Pruef "31b Anderes Projekt: im Projekt schreiben frei" (Urteil $r) "PASS"
$eingabeR = (@{ tool_name = 'Write'; cwd = $anderes; tool_input = @{ file_path = (Join-Path $repo 'x.md') } } | ConvertTo-Json -Compress -Depth 5)
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-workspace" $eingabeR @{ CLAUDE_PROJECT_DIR = $anderes }
Pruef "31c Anderes Projekt: ins Leo-Kind schreiben zu" (Urteil $r) "DENY"
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-read" '{"tool_name":"Bash","cwd":"x","tool_input":{"command":"cat .env"}}' @{ CLAUDE_PROJECT_DIR = $anderes }
Pruef "31d Anderes Projekt: Zugangsdaten zu" (Urteil $r) "DENY"
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-git" '{"tool_name":"Bash","cwd":"x","tool_input":{"command":"gh pr merge 3"}}' @{ CLAUDE_PROJECT_DIR = $anderes }
Pruef "31e Anderes Projekt: Mergen zu" (Urteil $r) "DENY"
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-extern" '{"tool_name":"mcp__x__send_message","tool_input":{}}' @{ CLAUDE_PROJECT_DIR = $anderes }
Pruef "31f Anderes Projekt: Connector-Versand zu" (Urteil $r) "DENY"
$r = Starte $verteiler "-Repo `"$repo`" -Skript version-check -Hook SessionStart" '{"source":"compact"}' @{ CLAUDE_PROJECT_DIR = $anderes }
Pruef "31g Anderes Projekt: keine Kern-Hooks" ([string]($r.code -eq 0 -and -not $r.out.Trim())) "True"
$eingabeD = (@{ tool_name = 'Write'; cwd = $homePath; tool_input = @{ file_path = (Join-Path $desktop 'x.md') } } | ConvertTo-Json -Compress -Depth 5)
$r = Starte $verteiler "-Repo `"$repo`" -Skript guard-workspace" $eingabeD @{ CLAUDE_PROJECT_DIR = $homePath }
Pruef "31h Projekt = Benutzerordner: kein Arbeitsbereich" (Urteil $r) "DENY"
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

# --- Ohne Adminrechte: Sperren aus dem Versionsstand im Benutzerprofil (seit 6.0) ------------------
# Ein Mini-Kind mit den Kern-Skripten aus dem Arbeitsstand, committet und mit Tag v6.0; die Quelle ist das
# Kind selbst (gleicher Tag, gleicher Commit). Das Profil ist ein Testordner, nie das echte.
$mini = Join-Path $tmp 'Mini Kind'
$heimT = Join-Path $tmp 'Heim'
$sysT = Join-Path $tmp 'kein System'
foreach ($rel in ($haertungsDateien + @('00_INDEX/scripts/hooks-einrichten.ps1'))) {
    $q = Join-Path $repo $rel; $z = Join-Path $mini $rel
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $z) | Out-Null
    Copy-Item -LiteralPath $q -Destination $z
}
New-Item -ItemType Directory -Force -Path (Join-Path $mini '.claude') | Out-Null
Copy-Item -LiteralPath (Join-Path $repo '.claude/settings.json') -Destination (Join-Path $mini '.claude/settings.json')
[System.IO.File]::WriteAllText((Join-Path $mini 'MEIN-SYSTEM.md'), "| Eingespielte Version | 6.0 |`n", $utf8)
[System.IO.File]::WriteAllText((Join-Path $mini 'AGENTS.md'), "---`nversion: 6.0`n---`n", $utf8)
$ErrorActionPreference = 'Continue'
& git init -q -b main $mini 2>&1 | Out-Null
& git -C $mini add -- . 2>&1 | Out-Null
& git -C $mini -c user.email=t@example.org -c user.name=t commit -q -m mini 2>&1 | Out-Null
& git -C $mini tag v6.0 2>&1 | Out-Null
$ErrorActionPreference = 'Stop'
$miniEinrichten = Join-Path $mini '00_INDEX/scripts/hooks-einrichten.ps1'
$po = Get-ProfilOrt $mini $heimT
$r = Starte $miniEinrichten "-Plattform windows -Heim `"$heimT`" -Quelle `"$mini`" -System `"$sysT`""
Pruef "50 Profil: Kopie der Sperren angelegt" ([string]((Test-Path -LiteralPath (Join-Path $po.kopie '00_INDEX/scripts/guard-fremdsysteme.ps1')) -and (Test-Path -LiteralPath (Join-Path $po.kopie '00_INDEX/scripts/leo-hook.ps1')))) "True"
$us = Get-Content -LiteralPath $po.settings -Raw -Encoding UTF8 | ConvertFrom-Json
$eig = @($us.hooks.PreToolUse | Where-Object { [string]$_.hooks[0].command -like ('*' + $po.kopie + '*') })
Pruef "51 Profil: sechs Sperren in den Einstellungen" $eig.Count "6"
Pruef "52 Profil: mit onFailure block" (@($eig | Where-Object { $_.hooks[0].onFailure -eq 'block' }).Count) "6"
Pruef "53 Profil: Leseverbote dazu" ([string](@($us.permissions.deny) -contains 'Read(~/.ssh/**)')) "True"
$r = Starte $miniEinrichten "-Plattform windows -Heim `"$heimT`" -Quelle `"$mini`" -System `"$sysT`" -Pruefen"
Pruef "54 Profil: zweiter Lauf nichts zu tun" $r.code "0"
Pruef "54b Profil: Versionsmarke 6.0" ([string]((Get-Content -LiteralPath (Join-Path $po.kopie 'version.txt') -Raw).Trim())) "6.0"
# -NurProfil (Aufruf der Versionspruefung): richtet nur das Profil ein, Projektdateien bleiben.
$projVorher = (Get-FileHash -LiteralPath (Join-Path $mini '.claude/settings.json')).Hash
Remove-Item -LiteralPath $po.settings -Force
$r = Starte $miniEinrichten "-Plattform windows -Heim `"$heimT`" -Quelle `"$mini`" -System `"$sysT`" -NurProfil"
Pruef "54c NurProfil: Einstellungen wieder da" ([string](Test-Path -LiteralPath $po.settings)) "True"
Pruef "54d NurProfil: Meldung fuer die Versionspruefung" ([string]($r.out -match 'Alle Projekte: Sperren aus Version [0-9.]+ eingerichtet \(')) "True"
Pruef "54e NurProfil: Projektdatei unberuehrt" ([string]((Get-FileHash -LiteralPath (Join-Path $mini '.claude/settings.json')).Hash -eq $projVorher)) "True"
# Der Agent aendert eine Sperre im Repo: Sie gelangt nie in die Kopie.
Add-Content -LiteralPath (Join-Path $mini '00_INDEX/scripts/guard-read.ps1') -Value 'exit 0 # gelockert'
$r = Starte $miniEinrichten "-Plattform windows -Heim `"$heimT`" -Quelle `"$mini`" -System `"$sysT`""
Pruef "55 Profil: Aenderung im Repo bleibt draussen" ([string]((Get-Content -LiteralPath (Join-Path $po.kopie '00_INDEX/scripts/guard-read.ps1') -Raw) -notmatch 'gelockert')) "True"
# Ein Tag, der lokal auf einen anderen Commit zeigt als auf der Quelle: keine Erneuerung.
$fremdQ = Join-Path $tmp 'Quelle anders'
$ErrorActionPreference = 'Continue'
& git init -q -b main $fremdQ 2>&1 | Out-Null
& git -C $fremdQ -c user.email=t@example.org -c user.name=t commit -q --allow-empty -m anders 2>&1 | Out-Null
& git -C $fremdQ tag v6.0 2>&1 | Out-Null
$ErrorActionPreference = 'Stop'
$r = Starte $miniEinrichten "-Plattform windows -Heim `"$heimT`" -Quelle `"$fremdQ`" -System `"$sysT`""
Pruef "56 Profil: falscher Tag, nicht erneuert" ([string]($r.out -match 'nicht erneuert')) "True"
# Fremde Eintraege in den persoenlichen Einstellungen bleiben.
$us.hooks.PreToolUse = @(@($us.hooks.PreToolUse) + [pscustomobject]@{ matcher = 'Bash'; hooks = @([pscustomobject]@{ type = 'command'; command = 'echo eigener' }) })
[System.IO.File]::WriteAllText($po.settings, ($us | ConvertTo-Json -Depth 20), $utf8)
$r = Starte $miniEinrichten "-Plattform windows -Heim `"$heimT`" -Quelle `"$mini`" -System `"$sysT`""
$us = Get-Content -LiteralPath $po.settings -Raw -Encoding UTF8 | ConvertFrom-Json
Pruef "57 Profil: eigener Hook bleibt, keine Doppel" ([string](@($us.hooks.PreToolUse).Count)) "7"
# Der Verteiler aus der Profil-Kopie sperrt in einem anderen Projekt.
$vp = Join-Path (Join-Path (Join-Path $po.kopie '00_INDEX') 'scripts') 'leo-hook.ps1'
$r = Starte $vp "-Repo `"$mini`" -Skript guard-read" $eingabe @{ CLAUDE_PROJECT_DIR = $anderes }
Pruef "58 Profil-Verteiler: anderes Projekt gesperrt" (Urteil $r) "DENY"
# Mit Haertung braucht es das Profil nicht.
$ortMini = Get-HaertungsOrt $mini $sysT
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ortMini.dropin) | Out-Null
[System.IO.File]::WriteAllText($ortMini.dropin, '{}', $utf8)
$r = Starte $miniEinrichten "-Plattform windows -Heim `"$heimT`" -Quelle `"$mini`" -System `"$sysT`""
Pruef "59 Profil: bei Haertung nichts" ([string]($r.out -match 'Haertung mit Adminrechten ist eingerichtet')) "True"

# --- Nur der Besitzer, nie aus einer Session -------------------------------------------------------
$r = Starte $haerten "" "j`n"
# Im Repo des Herausgebers (Release-Gate gesetzt) bricht es schon davor ab, mit Exit 3.
$istHerausgeber = [bool](& git -C $repo config --get leo.releaseGate 2>$null)
Pruef "42 Nie aus einer Session, nie beim Herausgeber" $r.code $(if ($istHerausgeber) { "3" } else { "2" })

Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
""
if ($fehler -eq 0) { "ALLE $anzahl FAELLE BESTANDEN"; exit 0 }
else { "$fehler VON $anzahl FAELLEN ABWEICHEND"; exit 1 }
