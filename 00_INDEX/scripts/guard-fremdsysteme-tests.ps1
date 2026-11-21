# guard-fremdsysteme-tests.ps1
# Zweck: Regressionsreihe fuer guard-fremdsysteme.ps1 (seit 6.0): Schreiben in Fremdsysteme, Schutzlisten
# eingehaengter Repos (Adressen, Schluessel, Werkzeuge), Schluessel in Repos, Pflicht der Firmenschicht,
# dazu die Meldung der Versionspruefung zur Firmenschicht.
#
# WIE: Baut in einem Ordner im Temp-Verzeichnis ein Leo-Kind mit einem eingehaengten Repo, dessen
# schutzliste.txt nur auf seinem lokalen Ersatz fuer GitHub (Bare-Repo) steht, und ruft den Hook mit JSON
# auf stdin auf. Nichts wird gesendet, nichts ausserhalb des Testordners geschrieben (ausser dem
# Zwischenspeicher der Schutzliste unter <Temp>/leo-schutzliste, den die Reihe am Ende entfernt).
#
# AUFRUF:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\guard-fremdsysteme-tests.ps1"
#   ... -Exe powershell      Hook unter Windows PowerShell 5.1
# Bewusst ASCII-only.
param(
    [string]$Skript = (Join-Path $PSScriptRoot 'guard-fremdsysteme.ps1'),
    [string]$Exe = ''
)
$ErrorActionPreference = 'Stop'
$isWindowsHost = [System.IO.Path]::DirectorySeparatorChar -eq '\'
$psExe = if ($Exe) { (Get-Command $Exe -ErrorAction SilentlyContinue).Source } else { (Get-Command $(if ($isWindowsHost) { 'pwsh.exe' } else { 'pwsh' }) -ErrorAction SilentlyContinue).Source }
if (-not $psExe -and $isWindowsHost) { $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$temp = [System.IO.Path]::GetTempPath().TrimEnd('\', '/')
$b = Join-Path $temp ('guard-fremd-tests-' + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $b | Out-Null
function G { param([Parameter(ValueFromRemainingArguments)]$a) $alt = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; & git @a 2>&1 | Out-Null; $ErrorActionPreference = $alt }

# Ersatz fuer GitHub: Bare-Repo des eingehaengten Repos mit Schutzliste und Werkzeug.
$fern = Join-Path $b 'fachagent.git'
$seed = Join-Path $b 'seed'
G init -q --bare -b main $fern
G init -q -b main $seed
New-Item -ItemType Directory -Force -Path (Join-Path $seed 'tools') | Out-Null
[System.IO.File]::WriteAllText((Join-Path $seed 'schutzliste.txt'), "# Test`nadresse: erp.example.org`nschluessel: .erp-key*`nwerkzeug: tools/erp.py`n", $utf8)
[System.IO.File]::WriteAllText((Join-Path $seed 'tools/erp.py'), "print('werkzeug')`n", $utf8)
G -C $seed add -- schutzliste.txt tools/erp.py
G -C $seed -c user.email=t@example.org -c user.name=t commit -q -m start
G -C $seed remote add origin $fern
G -C $seed push -q origin main
$kind = Join-Path $b 'Mein Agent'
G init -q -b main $kind
$nested = Join-Path (Join-Path $kind '20_Team') 'fachagent'
G clone -q $fern $nested
# Lokal wird die Schutzliste geleert: Massgeblich bleibt die Fassung auf dem Ersatz fuer GitHub.
[System.IO.File]::WriteAllText((Join-Path $nested 'schutzliste.txt'), "# lokal geleert`n", $utf8)
# Seit der Zweitpruefung von 6.0: ein eingehaengtes Repo ohne Abgleich, dessen lokale Schutzliste einen
# Durchlass eintragen will, und eine Attrappe der Firmenschicht (git init plus remote add, ohne Klon).
$lokal = Join-Path $kind '40_Lokal'
G init -q -b main $lokal
New-Item -ItemType Directory -Force -Path (Join-Path $lokal 'tools') | Out-Null
[System.IO.File]::WriteAllText((Join-Path $lokal 'schutzliste.txt'), "werkzeug: tools/frei.py`nadresse: lokal.example.org`n", $utf8)
$attrappe = Join-Path $kind '50_Attrappe'
G init -q -b main $attrappe
G -C $attrappe remote add origin https://github.com/beispiel-org/attrappe.git
$scratch = Join-Path (Join-Path $temp 'claude') 'guard-fremd-tests'
$heim = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
$fsKurz = ((Split-Path -Leaf $b) + '/fachagent').ToLower()

$fehler = 0; $anzahl = 0
function Ruf([string]$tool, $ti, [hashtable]$umgebung = @{}) {
    $json = @{ session_id = 'test'; hook_event_name = 'PreToolUse'; cwd = $kind; tool_name = $tool; tool_input = $ti } | ConvertTo-Json -Depth 6 -Compress
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Skript`" -Repo `"$kind`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $utf8
    $psi.EnvironmentVariables.Remove('LEO_FIRMENSCHICHT')
    foreach ($k in $umgebung.Keys) { $psi.EnvironmentVariables[$k] = $umgebung[$k] }
    $p = [System.Diagnostics.Process]::Start($psi)
    $bytes = $utf8.GetBytes($json); $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length); $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($out -match '"permissionDecision"\s*:\s*"deny"') { return 'DENY' }
    if ([string]::IsNullOrWhiteSpace($out)) { return 'PASS' }
    return 'FEHLER: ' + ($out.Trim() -replace "`r?`n", ' ')
}
function Pruef([string]$name, [string]$ist, [string]$soll) {
    $script:anzahl++
    if ($ist -ne $soll) { $script:fehler++ }
    '{0,-50} {1,-6} {2,-8} {3}' -f $name, $soll, $ist, $(if ($ist -eq $soll) { 'ok' } else { 'ABWEICHUNG' })
}
function B([string]$c) { return @{ command = $c } }
function W([string]$pfad, [string]$inhalt) { return @{ file_path = $pfad; content = $inhalt } }

"Geprueft wird: $Skript"
"Interpreter:   $psExe"
''
Pruef '1 curl POST an Google Kalender'        (Ruf 'Bash' (B 'curl -X POST https://www.googleapis.com/calendar/v3/calendars/primary/events -d @x.json')) 'DENY'
Pruef '2 curl GET an Google (lesen frei)'     (Ruf 'Bash' (B 'curl -s https://www.googleapis.com/calendar/v3/calendars/primary/events')) 'PASS'
Pruef '3 Invoke-RestMethod Post Asana'        (Ruf 'PowerShell' (B 'Invoke-RestMethod -Method Post -Uri https://app.asana.com/api/1.0/tasks -Body $b')) 'DENY'
Pruef '4 python requests.post'                (Ruf 'Bash' (B "python -c `"import requests; requests.post('https://api.notion.com/v1/pages', json={})`"")) 'DENY'
Pruef '5 Skript mit Airtable schreiben'       (Ruf 'Write' (W (Join-Path $scratch 'a.py') "from pyairtable import Api`nt = Api('x').table('b', 'c')`nt.create({'Name': 'x'})`n")) 'DENY'
Pruef '6 Markdown nennt Adresse und POST'     (Ruf 'Write' (W (Join-Path $kind 'notiz.md') "curl -X POST https://api.notion.com/v1/pages")) 'PASS'
Pruef '7 Adresse aus Schutzliste (GitHub)'    (Ruf 'Bash' (B 'curl -X POST https://erp.example.org/api/x')) 'DENY'
Pruef '8 Werkzeug aus Schutzliste'            (Ruf 'Bash' (B "python `"$nested\tools\erp.py`" -d plan.json https://erp.example.org")) 'PASS'
Pruef '9 Werkzeug als Modul geladen'          (Ruf 'Bash' (B "python -c `"import importlib.util as u; u.spec_from_file_location('e','tools/erp.py'); import requests; requests.post('https://erp.example.org/x')`"")) 'DENY'
Pruef '10 Schluessel lesen (Read)'            (Ruf 'Read' @{ file_path = (Join-Path $heim '.erp-key.txt') }) 'DENY'
Pruef '11 Schluessel nennen (Bash)'           (Ruf 'Bash' (B 'type %USERPROFILE%\.erp-key.txt')) 'DENY'
Pruef '12 .env ins Repo schreiben'            (Ruf 'Write' (W (Join-Path $kind '.env') 'A=1')) 'DENY'
Pruef '13 Token als Inhalt ins Repo'          (Ruf 'Write' (W (Join-Path $kind 'x.md') ('Token: ghp_' + ('a' * 36)))) 'DENY'
Pruef '14 .env im Scratchpad (kein Repo)'     (Ruf 'Write' (W (Join-Path $scratch '.env') 'A=1')) 'PASS'
Pruef '15 Browser-Code fetch POST'            (Ruf 'mcp__abc__javascript_tool' @{ action = 'javascript_exec'; text = "fetch('https://api.notion.com/v1/pages', {method: 'POST'})" }) 'DENY'
Pruef '16 Grep harmlos'                       (Ruf 'Grep' @{ pattern = 'Rechnung'; path = $kind }) 'PASS'
Pruef '17 Edit eines Skripts mit Slack-Post'  (Ruf 'Edit' @{ file_path = (Join-Path $kind 'x.py'); old_string = 'a'; new_string = "from slack_sdk import WebClient`nWebClient().chat_postMessage(channel='x', text='y')" }) 'DENY'
Pruef '18 normaler Befehl'                    (Ruf 'Bash' (B 'git status -sb')) 'PASS'
# Seit der Pruefung von 6.0: Umgehungen ueber das Werkzeug, weitere Schreibmerkmale, falsche Sperren beim Lesen.
Pruef '25 Werkzeug nur im Kommentar erwaehnt'  (Ruf 'Bash' (B 'curl -X POST https://erp.example.org/api/x # tools/erp.py')) 'DENY'
Pruef '26 Werkzeug verkettet mit curl'        (Ruf 'Bash' (B "python `"$nested\tools\erp.py`"; curl -X POST https://erp.example.org/x")) 'DENY'
Pruef '27 Werkzeug mit Hintergrund-&'         (Ruf 'Bash' (B "python `"$nested/tools/erp.py`" & curl -X POST https://erp.example.org/x")) 'DENY'
Pruef '28 Werkzeug, Python mit Leerzeichen'   (Ruf 'PowerShell' (B "& `"C:\Program Files\Python312\python.exe`" `"$nested\tools\erp.py`" --data x https://erp.example.org")) 'PASS'
Pruef '29 curl -f -s lesen'                   (Ruf 'Bash' (B 'curl -f -s https://www.googleapis.com/calendar/v3/calendars/primary/events')) 'PASS'
Pruef '30 curl -D lesen (Kopfzeilen)'         (Ruf 'Bash' (B 'curl -D h.txt https://www.googleapis.com/calendar/v3/calendars/primary/events')) 'PASS'
Pruef '31 curl -sSd schreibt'                 (Ruf 'Bash' (B 'curl -sSd @x.json https://www.googleapis.com/calendar/v3/calendars/primary/events')) 'DENY'
Pruef '32 httpie POST'                        (Ruf 'Bash' (B 'http POST https://api.notion.com/v1/pages a=b')) 'DENY'
Pruef '33 requests.request POST'              (Ruf 'Bash' (B "python -c `"import requests; requests.request('POST', 'https://api.notion.com/v1/pages')`"")) 'DENY'
Pruef '34 WebClient UploadString'             (Ruf 'PowerShell' (B "(New-Object Net.WebClient).UploadString('https://hooks.slack.com/services/x', 'a')")) 'DENY'
Pruef '35 -Method:Post'                       (Ruf 'PowerShell' (B 'Invoke-WebRequest -Uri https://api.notion.com/v1/pages -Method:Post')) 'DENY'
Pruef '36 Invoke-RestMethod GET lesen'        (Ruf 'PowerShell' (B 'Invoke-RestMethod -Uri https://www.googleapis.com/calendar/v3/calendars/primary/events -Method Get -Headers $h')) 'PASS'
Pruef '37 Skript ruft update_cells'           (Ruf 'Write' (W (Join-Path $scratch 'b.py') "import pygsheets`nwks.update_cells(crange='A1', values=[[1]])`n")) 'DENY'
Pruef '38 Schluessel sk-proj als Inhalt'      (Ruf 'Write' (W (Join-Path $kind 'y.md') ('Schluessel: sk-proj-' + ('a' * 40)))) 'DENY'
Pruef '39 .netrc ins Repo'                    (Ruf 'Write' (W (Join-Path $kind '.netrc') 'machine x')) 'DENY'
Pruef '40 Commit-Botschaft nennt Adresse'     (Ruf 'Bash' (B 'git commit -m "Sperre fuer googleapis.com erweitert" -- notiz.md')) 'PASS'
Pruef '41 Mailwerkzeug des Kerns starten'     (Ruf 'Bash' (B 'python 00_INDEX/scripts/lib/gmail-senden.py --an a@example.org --betreff x --text-datei y.txt')) 'PASS'
Pruef '42 Wort mit sk- ist kein Schluessel'   (Ruf 'Write' (W (Join-Path $kind 'z.md') ('task-' + ('a' * 40)))) 'PASS'
# Seit der Zweitpruefung von 6.0: Schreibmerkmale ohne Leerzeichen, abgekuerzte Parameter, weitere Dienste,
# der Durchlass nur fuer das echte Werkzeug, lokale Schutzliste nur verschaerfend; dazu Kontrollen gegen Fehlsperren.
Pruef '43 curl -d@datei'                      (Ruf 'Bash' (B 'curl -d@daten https://api.notion.com/v1/pages')) 'DENY'
Pruef '44 curl -d''{json}'' ohne Leerzeichen' (Ruf 'Bash' (B "curl -d'{`"a`":1}' https://api.notion.com/v1/pages")) 'DENY'
Pruef '45 curl -Ffile=@x'                     (Ruf 'Bash' (B 'curl -Ffile=@x https://content.dropboxapi.com/2/files/upload')) 'DENY'
Pruef '46 irm -Met Post -Bo (abgekuerzt)'     (Ruf 'PowerShell' (B 'Invoke-RestMethod https://api.notion.com/v1/pages -Met Post -Bo $b')) 'DENY'
Pruef '47 irm GET mit -TimeoutSec lesen'      (Ruf 'PowerShell' (B 'Invoke-RestMethod -Uri https://api.notion.com/v1/pages/x -TimeoutSec 10 -Headers $h')) 'PASS'
Pruef '48 iwr GET mit -OutFile -Force lesen'  (Ruf 'PowerShell' (B 'Invoke-WebRequest https://api.notion.com/v1/pages/x -OutFile a.json -Force')) 'PASS'
Pruef '49 urllib Request(url, data)'          (Ruf 'Bash' (B "python -c `"import urllib.request as u; u.urlopen(u.Request('https://api.notion.com/v1/pages', b'{}'))`"")) 'DENY'
Pruef '50 urllib Request mit headers lesen'   (Ruf 'Bash' (B "python -c `"import urllib.request as u; print(u.urlopen(u.Request('https://api.notion.com/v1/x', headers={'a': 'b'})).read())`"")) 'PASS'
Pruef '51 SharePoint REST POST'               (Ruf 'Bash' (B 'curl -X POST https://firma.sharepoint.com/_api/web/lists -d x')) 'DENY'
Pruef '52 Teams-Webhook POST'                 (Ruf 'Bash' (B 'curl -X POST https://firma.webhook.office.com/webhookb2/x -d x')) 'DENY'
Pruef '53 Google-Formular absenden'           (Ruf 'Bash' (B 'curl -X POST https://docs.google.com/forms/d/e/x/formResponse -d entry.1=x')) 'DENY'
Pruef '54 Werkzeug-Attrappe gleiches Ende'    (Ruf 'Bash' (B "python `"$scratch\tools\erp.py`" --data x https://erp.example.org")) 'DENY'
Pruef '55 Werkzeug relativ zum Arbeitsordner' (Ruf 'Bash' (B 'python 20_Team/fachagent/tools/erp.py --data x https://erp.example.org')) 'PASS'
Pruef '56 lokale Schutzliste: kein Durchlass' (Ruf 'Bash' (B "python `"$lokal\tools\frei.py`" --data x https://api.notion.com/v1/pages")) 'DENY'
Pruef '57 lokale Schutzliste verschaerft'     (Ruf 'Bash' (B 'curl -X POST https://lokal.example.org/x')) 'DENY'
Pruef '58 Firmenschicht-Attrappe ohne Klon'   (Ruf 'Write' (W (Join-Path $kind 'x.md') 'x') @{ LEO_FIRMENSCHICHT = 'beispiel-org/attrappe' }) 'DENY'
$pflicht = @{ LEO_FIRMENSCHICHT = 'https://github.com/beispiel-org/firmenschicht' }
Pruef '19 Firmenschicht fehlt: Datei schreiben' (Ruf 'Write' (W (Join-Path $kind 'x.md') 'x') $pflicht) 'DENY'
Pruef '20 Firmenschicht fehlt: 00_INDEX frei' (Ruf 'Write' (W (Join-Path (Join-Path $kind '00_INDEX') 'x.md') 'x') $pflicht) 'PASS'
Pruef '21 Firmenschicht fehlt: Shell frei'    (Ruf 'Bash' (B 'git clone https://github.com/beispiel-org/firmenschicht') $pflicht) 'PASS'
Pruef '22 Firmenschicht da: schreiben frei'   (Ruf 'Write' (W (Join-Path $kind 'x.md') 'x') @{ LEO_FIRMENSCHICHT = $fsKurz }) 'PASS'
Pruef '22b Firmenschicht fehlt: .gitignore frei' (Ruf 'Edit' @{ file_path = (Join-Path $kind '.gitignore'); old_string = 'a'; new_string = 'b' } $pflicht) 'PASS'
Pruef '22c Firmenschicht fehlt: MEIN-SYSTEM frei' (Ruf 'Edit' @{ file_path = (Join-Path $kind 'MEIN-SYSTEM.md'); old_string = 'a'; new_string = 'b' } $pflicht) 'PASS'
Pruef '22d Firmenschicht fehlt: neuer Themenordner' (Ruf 'Write' (W (Join-Path $kind '30_Neu\README.md') 'x') $pflicht) 'DENY'

# Versionspruefung meldet die fehlende Firmenschicht bei jedem Start.
$vc = Join-Path $PSScriptRoot 'version-check.ps1'
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $psExe
$psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$vc`" -Hook SessionStart -Repo `"$kind`" -Quelle `"$(Join-Path $b 'gibtsnicht.git')`" -Mitteilungen `"$(Join-Path $b 'keine.md')`""
$psi.UseShellExecute = $false; $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
$psi.EnvironmentVariables['LEO_FIRMENSCHICHT'] = 'beispiel-org/firmenschicht'
$p = [System.Diagnostics.Process]::Start($psi); $p.StandardInput.Write('{"source":"startup"}'); $p.StandardInput.Close()
$out = $p.StandardOutput.ReadToEnd(); $p.WaitForExit()
Pruef '23 Versionspruefung: Pflicht im Kontext' ([string]($out -match 'PFLICHT DER ORGANISATION' -and $out -match 'beispiel-org/firmenschicht')) 'True'

# Die Schutzliste wird aus dem Zwischenspeicher gelesen; nach dessen Loeschen wieder frisch.
Get-ChildItem -LiteralPath (Join-Path $temp 'leo-schutzliste') -Filter '*.json' -ErrorAction SilentlyContinue | Where-Object { $_.Name -like ('*' + (Split-Path -Leaf $b) + '*') } | Remove-Item -Force
Pruef '24 Nach geleertem Zwischenspeicher'    (Ruf 'Bash' (B 'curl -X POST https://erp.example.org/api/x')) 'DENY'

Get-ChildItem -LiteralPath (Join-Path $temp 'leo-schutzliste') -Filter '*.json' -ErrorAction SilentlyContinue | Where-Object { $_.Name -like ('*' + (Split-Path -Leaf $b) + '*') } | Remove-Item -Force
Remove-Item -LiteralPath $b -Recurse -Force -ErrorAction SilentlyContinue
''
if ($fehler -eq 0) { "ALLE $anzahl FAELLE BESTANDEN"; exit 0 }
"$fehler VON $anzahl FAELLEN ABWEICHEND"
exit 1
