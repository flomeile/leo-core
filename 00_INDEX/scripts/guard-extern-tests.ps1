# guard-extern-tests.ps1
# Zweck: Regressionsreihe fuer guard-extern.ps1 (Connector-Sperre, seit 6.0). Die Freigabeliste wird in
# einer Kopie des Hooks im Temp-Verzeichnis geprueft, damit die echte Liste unberuehrt bleibt.
# AUFRUF:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\guard-extern-tests.ps1"
#   ... -Exe powershell      Hook unter Windows PowerShell 5.1
# Bewusst ASCII-only.
param([string]$Exe = '')
$ErrorActionPreference = 'Stop'
$isWindowsHost = [System.IO.Path]::DirectorySeparatorChar -eq '\'
$psExe = if ($Exe) { (Get-Command $Exe -ErrorAction SilentlyContinue).Source } else { (Get-Command $(if ($isWindowsHost) { 'pwsh.exe' } else { 'pwsh' }) -ErrorAction SilentlyContinue).Source }
if (-not $psExe -and $isWindowsHost) { $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$b = Join-Path ([System.IO.Path]::GetTempPath().TrimEnd('\', '/')) ('guard-extern-tests-' + [System.Guid]::NewGuid().ToString('N'))
$skripte = Join-Path (Join-Path $b '00_INDEX') 'scripts'
New-Item -ItemType Directory -Force -Path $skripte | Out-Null
$kopie = Join-Path $skripte 'guard-extern.ps1'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'guard-extern.ps1') -Destination $kopie
$liste = Join-Path (Join-Path $b '00_INDEX') 'extern-freigaben.txt'

$fehler = 0; $anzahl = 0
function Ruf([string]$tool) {
    $json = @{ hook_event_name = 'PreToolUse'; tool_name = $tool; tool_input = @{ x = 1 } } | ConvertTo-Json -Compress
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$kopie`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.Write($json); $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($out -match '"permissionDecision"\s*:\s*"deny"') { return 'DENY' }
    if ([string]::IsNullOrWhiteSpace($out)) { return 'PASS' }
    return 'FEHLER: ' + ($out.Trim() -replace "`r?`n", ' ')
}
function Pruef([string]$name, [string]$ist, [string]$soll) {
    $script:anzahl++
    if ($ist -ne $soll) { $script:fehler++ }
    '{0,-46} {1,-6} {2,-8} {3}' -f $name, $soll, $ist, $(if ($ist -eq $soll) { 'ok' } else { 'ABWEICHUNG' })
}

"Interpreter: $psExe"
''
Pruef '1 Mail senden'                     (Ruf 'mcp__a1b2__send_message') 'DENY'
Pruef '2 Mail suchen'                     (Ruf 'mcp__a1b2__search_threads') 'PASS'
Pruef '3 Entwurf anlegen'                 (Ruf 'mcp__a1b2__create_draft') 'PASS'
Pruef '4 Termin anlegen'                  (Ruf 'mcp__c3__create_event') 'DENY'
Pruef '5 Datei in Drive anlegen'          (Ruf 'mcp__d4__create_file') 'DENY'
Pruef '6 Datei teilen'                    (Ruf 'mcp__d4__share_file') 'DENY'
Pruef '7 Datei lesen'                     (Ruf 'mcp__d4__read_file_content') 'PASS'
Pruef '8 kein Connector'                  (Ruf 'Bash') 'PASS'
# Seit der Zweitpruefung von 6.0: dasselbe Werkzeug unter anderem Namen, weitere Wirkungen nach aussen.
Pruef '13 slack_send_message'             (Ruf 'mcp__slack__slack_send_message') 'DENY'
Pruef '14 gmail_send_email'               (Ruf 'mcp__z9__gmail_send_email') 'DENY'
Pruef '15 sendMessage (Grossbuchstabe)'   (Ruf 'mcp__t1__sendMessage') 'DENY'
Pruef '16 Zugriff anfragen (Mail)'        (Ruf 'mcp__d4__request_access') 'DENY'
Pruef '17 geteilte Ablage anlegen'        (Ruf 'mcp__d4__create_shared_drive') 'DENY'
Pruef '18 Entwurf loeschen'               (Ruf 'mcp__a1b2__delete_draft') 'DENY'
Pruef '19 Freigabe aufheben (unshare)'    (Ruf 'mcp__d4__unshare_file') 'PASS'
Pruef '20 Label anlegen'                  (Ruf 'mcp__a1b2__create_label') 'PASS'
Pruef '21 Sitzung der App loeschen'       (Ruf 'mcp__ccd_session_mgmt__delete_session') 'PASS'
# Seit dem Schlusstest von 6.0 PASS: Eine Nachricht an eine Sitzung derselben App verlaesst den Rechner nicht.
Pruef '22 App: Nachricht an Sitzung'      (Ruf 'mcp__ccd_session_mgmt__send_message') 'PASS'
Pruef '23 Suchen mit Wort im Namen'       (Ruf 'mcp__a1b2__search_sent_items') 'PASS'
# Schlusstest von 6.0: post, publish, invite, merge.
Pruef '24 slack_post_message'             (Ruf 'mcp__slack__slack_post_message') 'DENY'
Pruef '25 chat_postMessage'               (Ruf 'mcp__s2__chat_postMessage') 'DENY'
Pruef '26 post_comment'                   (Ruf 'mcp__s2__post_comment') 'DENY'
Pruef '27 publish_post'                   (Ruf 'mcp__b7__publish_post') 'DENY'
Pruef '28 invite_user'                    (Ruf 'mcp__s2__invite_user') 'DENY'
Pruef '29 merge_pull_request'             (Ruf 'mcp__gh__merge_pull_request') 'DENY'
Pruef '30 App: Automerge setzen'          (Ruf 'mcp__ccd_pr__set_auto_merge') 'DENY'
Pruef '31 Beitraege lesen (posts)'        (Ruf 'mcp__b7__list_posts') 'PASS'
[System.IO.File]::WriteAllLines($liste, [string[]]@('# Test', 'create_event   # Kalender erlaubt', 'mcp__d4__create_file'), $utf8)
Pruef '9 freigegebene Endung'             (Ruf 'mcp__c3__create_event') 'PASS'
Pruef '10 freigegebener voller Name'      (Ruf 'mcp__d4__create_file') 'PASS'
Pruef '11 gleiche Endung anderer Server'  (Ruf 'mcp__e5__create_file') 'DENY'
Pruef '12 nicht freigegeben bleibt zu'    (Ruf 'mcp__a1b2__send_message') 'DENY'

Remove-Item -LiteralPath $b -Recurse -Force -ErrorAction SilentlyContinue
''
if ($fehler -eq 0) { "ALLE $anzahl FAELLE BESTANDEN"; exit 0 }
"$fehler VON $anzahl FAELLEN ABWEICHEND"
exit 1
