# guard-finanzen-tests.ps1
# Zweck: Regressionsreihe fuer guard-finanzen.ps1 (Finanz-Sperre, seit 6.1): speist Werkzeugaufrufe als JSON in die
# Sperre und prueft die Entscheidung (deny oder Durchlass), das Ausblenden von Sicherheitsmails und die Meldung beim
# Sessionstart. Der Zustand der Sperre liegt waehrend der Reihe in einem Testordner unter Temp.
# AUFRUF:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\guard-finanzen-tests.ps1"
#   ... -Exe powershell      Sperre unter Windows PowerShell 5.1
# Exit 0 = alle gruen. Bewusst ASCII-only. Die Faelle nehmen erfundene Adressen (example.org, bank.example) und
# bekannte Plattformen nur dort, wo die feste Liste der Sperre sie nennt.
param([string]$Exe = '')
$ErrorActionPreference = 'Stop'
$isWindowsHost = [System.IO.Path]::DirectorySeparatorChar -eq '\'
$psExe = if ($Exe) { (Get-Command $Exe -ErrorAction SilentlyContinue).Source } else { (Get-Command $(if ($isWindowsHost) { 'pwsh.exe' } else { 'pwsh' }) -ErrorAction SilentlyContinue).Source }
if (-not $psExe -and $isWindowsHost) { $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source }
$hook = Join-Path $PSScriptRoot 'guard-finanzen.ps1'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$tmp = Join-Path ([System.IO.Path]::GetTempPath().TrimEnd('\', '/')) ('guard-finanzen-tests-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force $tmp | Out-Null
# Ein Projekt ausserhalb des Temp-Ordners, damit die Meldung beim Sessionstart nicht als Testkind gilt. Es wird nur
# als Name uebergeben, nie angelegt.
$fremdProjekt = Join-Path $(if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }) 'leo-finanzen-testprojekt-gibt-es-nicht'

function Roh($eingabe, [string]$rohtext = '', [string]$argumente = '', [hashtable]$umgebung = @{}) {
    $json = if ($rohtext) { $rohtext } else { $eingabe | ConvertTo-Json -Depth 8 -Compress }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$hook`" $argumente"
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.UseShellExecute = $false
    $psi.StandardOutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $psi.EnvironmentVariables['LEO_FINANZEN_DIR'] = $tmp
    $psi.EnvironmentVariables['CLAUDE_PROJECT_DIR'] = $repo
    if ($psi.EnvironmentVariables.ContainsKey('LEO_GRUNDPFLEGE')) { $psi.EnvironmentVariables.Remove('LEO_GRUNDPFLEGE') }
    if ($psi.EnvironmentVariables.ContainsKey('LEO_REPO_PFAD')) { $psi.EnvironmentVariables.Remove('LEO_REPO_PFAD') }
    foreach ($k in $umgebung.Keys) { $psi.EnvironmentVariables[$k] = [string]$umgebung[$k] }
    $p = [System.Diagnostics.Process]::Start($psi)
    $b = (New-Object System.Text.UTF8Encoding($false)).GetBytes($json)
    $p.StandardInput.BaseStream.Write($b, 0, $b.Length); $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd(); $err = $p.StandardError.ReadToEnd(); $p.WaitForExit()
    if ($err.Trim()) { $out += "`nSTDERR: " + $err.Trim() }
    return $out
}
function Entscheid($eingabe, [string]$rohtext = '') {
    $out = Roh $eingabe $rohtext
    if ([string]::IsNullOrWhiteSpace($out)) { return @{ d = 'durchlass'; r = '' } }
    try { $o = $out | ConvertFrom-Json } catch { return @{ d = 'fehler'; r = $out } }
    return @{ d = $o.hookSpecificOutput.permissionDecision; r = $o.hookSpecificOutput.permissionDecisionReason }
}
$sid = 'test-session-1'
function Bash([string]$c) { @{ tool_name = 'Bash'; session_id = $sid; tool_input = @{ command = $c } } }
function PsBefehl([string]$c) { @{ tool_name = 'PowerShell'; session_id = $sid; tool_input = @{ command = $c } } }
function Nav([string]$u, [string]$fam = 'claude-in-chrome') { @{ tool_name = "mcp__$fam`__navigate"; session_id = $sid; tool_input = @{ url = $u } } }
function Js([string]$t) { @{ tool_name = 'mcp__claude-in-chrome__javascript_tool'; session_id = $sid; tool_input = @{ action = 'javascript_exec'; text = $t } } }
function Mcp([string]$name, [hashtable]$inp, [string]$s = $sid) { @{ tool_name = "mcp__claude-in-chrome__$name"; session_id = $s; tool_input = $inp } }
function Post([string]$name, $antwort, [string]$s) { @{ tool_name = "mcp__claude-in-chrome__$name"; session_id = $s; hook_event_name = 'PostToolUse'; tool_input = @{}; tool_response = $antwort } }
function Datei([string]$pfad, [string]$inhalt) { @{ tool_name = 'Write'; session_id = $sid; tool_input = @{ file_path = $pfad; content = $inhalt } } }
$imRepo = { param([string]$rel) Join-Path $repo $rel }

$faelle = @(
    # Browser: Plattformen aus der festen Liste
    @('Neobank gesperrt', (Nav 'https://app.revolut.com'), 'deny', 'revolut'),
    @('Broker ohne Schema gesperrt', (Nav 'www.trading212.com/login'), 'deny', 'trading212'),
    @('Broker mit Laenderendung gesperrt', (Nav 'https://www.interactivebrokers.co.uk/portal'), 'deny', 'interactivebrokers'),
    @('Zahlungsdienst gesperrt', (Nav 'https://www.paypal.com/myaccount'), 'deny', 'paypal'),
    @('Krypto-Boerse gesperrt', (Nav 'https://www.coinbase.com/home'), 'deny', 'coinbase'),
    @('Krypto mit Laenderendung gesperrt', (Nav 'https://www.binance.co.uk'), 'deny', 'binance'),
    @('Kartenherausgeber gesperrt', (Nav 'https://www.americanexpress.com/de-ch/account'), 'deny', 'americanexpress'),
    @('Stripe-Dashboard gesperrt', (Nav 'https://dashboard.stripe.com/payments'), 'deny', 'stripe'),
    @('Eingebauter Browser gesperrt', (Nav 'https://app.n26.com' 'Claude_Browser'), 'deny', 'n26'),
    # Browser: allgemeine Regeln (Stichwort, Kantonalbank)
    @('Unbekannte Bank mit Stichwort gesperrt', (Nav 'https://online.musterbank.example'), 'deny', 'musterbank'),
    @('E-Banking-Unterdomain gesperrt', (Nav 'https://ebanking.example-finanz.ch'), 'deny', 'ebanking'),
    @('Sparkasse gesperrt', (Nav 'https://www.sparkasse-musterstadt.de'), 'deny', 'sparkasse'),
    @('Kantonalbank gesperrt', (Nav 'https://banking.bekb.ch'), 'deny', 'bekb.ch'),
    # Passwortverwaltung und Konto-Sicherheitsseiten
    @('Chrome-Passwortverwaltung gesperrt', (Nav 'chrome://password-manager/passwords'), 'deny', 'password-manager'),
    @('Chrome-Einstellungen Zahlungsarten gesperrt', (Nav 'chrome://settings/payments'), 'deny', 'Gesperrt'),
    @('Google-Passwortverwaltung gesperrt', (Nav 'https://passwords.google.com'), 'deny', 'passwords.google.com'),
    @('Passwortmanager-Tresor gesperrt', (Nav 'https://vault.bitwarden.com'), 'deny', 'bitwarden'),
    @('preview_start mit Bank gesperrt', @{ tool_name = 'mcp__Claude_Browser__preview_start'; session_id = $sid; tool_input = @{ url = 'https://www.musterbank.example' } }, 'deny', 'musterbank'),
    @('Batch mit Navigation zu Broker gesperrt', (Mcp 'browser_batch' @{ actions = @(@{ name = 'navigate'; input = @{ url = 'https://www.etrade.com' } }) }), 'deny', 'Im Batch'),
    # Browser: Javascript an Anmeldedaten, auf jeder Seite
    @('Passwortfeld auslesen gesperrt', (Js "document.querySelector('input[type=password]').value"), 'deny', 'Anmeldedaten'),
    @('Passwortfeld mit Anfuehrungszeichen gesperrt', (Js 'document.querySelector("input[type=\"password\"]").value'), 'deny', 'Anmeldedaten'),
    @('navigator.credentials gesperrt', (Js 'navigator.credentials.get({password:true})'), 'deny', 'Anmeldedaten'),
    @('fetch an eine Bank gesperrt', (Js "fetch('https://api.musterbank.example/x')"), 'deny', 'Anmeldedaten'),
    # Shell
    @('curl an Neobank gesperrt', (Bash 'curl -s https://api.revolut.com/accounts'), 'deny', 'Shell'),
    @('curl an unbekannte Bank gesperrt', (Bash 'curl https://api.examplebank.com/v1/accounts'), 'deny', 'Shell'),
    @('Start-Process Broker gesperrt', (PsBefehl 'Start-Process "https://www.trading212.com"'), 'deny', 'Shell'),
    @('Chrome mit Bank starten gesperrt', (PsBefehl '& "C:\Program Files\Google\Chrome\Application\chrome.exe" https://ebanking.musterbank.example'), 'deny', 'Shell'),
    @('Mac: open mit Zahlungsdienst gesperrt', (Bash 'open https://www.paypal.com'), 'deny', 'Shell'),
    @('Chrome mit Passwortverwaltung starten gesperrt', (PsBefehl '& chrome.exe chrome://password-manager'), 'deny', 'Shell'),
    @('Chrome-Passwortdatei kopieren gesperrt', (Bash 'cp "$LOCALAPPDATA/Google/Chrome/User Data/Default/Login Data" /tmp/x'), 'deny', 'Zugangsdaten'),
    @('Chrome-Kartendaten lesen gesperrt', (PsBefehl 'Get-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Web Data"'), 'deny', 'Zugangsdaten'),
    @('Chrome-Cookies lesen gesperrt', (Bash 'sqlite3 "/c/Users/x/AppData/Local/Google/Chrome/User Data/Default/Network/Cookies" .tables'), 'deny', 'Zugangsdaten'),
    @('Chrome-Schluessel Local State gesperrt', (Bash 'cat "C:/Users/x/AppData/Local/Google/Chrome/User Data/Local State"'), 'deny', 'Zugangsdaten'),
    @('Firefox-Passwoerter gesperrt', (Bash 'cat ~/AppData/Roaming/Mozilla/Firefox/Profiles/a.default/logins.json'), 'deny', 'Zugangsdaten'),
    @('git credential fill gesperrt', (Bash "printf 'protocol=https\nhost=example.org\n' | git credential fill"), 'deny', 'Zugangsdaten'),
    @('git credential-manager get gesperrt', (Bash 'git credential-manager get'), 'deny', 'Zugangsdaten'),
    @('gh auth token gesperrt', (Bash 'gh auth token'), 'deny', 'Zugangsdaten'),
    @('gh auth status --show-token gesperrt', (Bash 'gh auth status --show-token'), 'deny', 'Zugangsdaten'),
    @('DPAPI entschluesseln gesperrt', (PsBefehl "[System.Security.Cryptography.ProtectedData]::Unprotect(`$b, `$null, 'CurrentUser')"), 'deny', 'Zugangsdaten'),
    @('win32crypt gesperrt', (Bash "python -c `"import win32crypt`""), 'deny', 'Zugangsdaten'),
    @('Windows-Tresor gesperrt', (PsBefehl "vaultcmd /listcreds:`"Windows Credentials`" /all"), 'deny', 'Zugangsdaten'),
    @('Get-StoredCredential gesperrt', (PsBefehl 'Get-StoredCredential -Target git:https://example.org'), 'deny', 'Zugangsdaten'),
    @('Mac-Schluesselbund gesperrt', (Bash 'security find-generic-password -s example -w'), 'deny', 'Zugangsdaten'),
    @('Linux-Schluesselbund gesperrt', (Bash 'secret-tool lookup service example'), 'deny', 'Zugangsdaten'),
    @('keyring gesperrt', (Bash "python -c `"import keyring; print(keyring.get_password('x','y'))`""), 'deny', 'Zugangsdaten'),
    @('browser_cookie3 gesperrt', (Bash "python -c `"import browser_cookie3; browser_cookie3.chrome()`""), 'deny', 'Zugangsdaten'),
    @('Chrome-Fernsteuerung gesperrt', (PsBefehl '& chrome.exe --remote-debugging-port=9222'), 'deny', 'Zugangsdaten'),
    # Lesen
    @('Read auf Chrome-Passwortdatei gesperrt', @{ tool_name = 'Read'; session_id = $sid; tool_input = @{ file_path = 'C:\Users\x\AppData\Local\Google\Chrome\User Data\Default\Login Data' } }, 'deny', 'Browser'),
    @('Glob auf Firefox-Schluessel gesperrt', @{ tool_name = 'Glob'; session_id = $sid; tool_input = @{ path = 'C:\Users\x\AppData\Roaming\Mozilla'; pattern = '**/key4.db' } }, 'deny', 'Browser'),
    # Dateien
    @('Skript mit Aufruf einer Bank gesperrt', (Datei 'C:\Users\x\scratch\b.ps1' 'Invoke-RestMethod https://api.musterbank.example/x'), 'deny', 'Geldplattform'),
    @('Python mit browser_cookie3 gesperrt', (Datei (& $imRepo '00_INDEX\scripts\x.py') "import browser_cookie3`nc = browser_cookie3.chrome()"), 'deny', 'Zugangsdaten'),
    # Durchlass
    @('Suche nach einer Bank laeuft durch', (Nav 'https://www.google.com/search?q=revolut.com+gebuehren'), 'durchlass', ''),
    @('Aehnlicher Name laeuft durch', (Nav 'https://notpaypal.com'), 'durchlass', ''),
    @('Gemini von Google laeuft durch', (Nav 'https://gemini.google.com/app'), 'durchlass', ''),
    @('Weltbank (Recherche) laeuft durch', (Nav 'https://data.worldbank.org/indicator'), 'durchlass', ''),
    @('Nachschlagewerk laeuft durch', (Nav 'https://de.wikipedia.org/wiki/Bankgeheimnis'), 'durchlass', ''),
    @('Repo-Suche nach Bankname laeuft durch', (Bash 'grep -rn revolut.com 10_System'), 'durchlass', ''),
    @('Mailadresse einer Bank im Befehl laeuft durch', (Bash 'python lies.py --suche from:info@example.org --ziel C:\tmp\x'), 'durchlass', ''),
    @('Download mit Bankwort im Dateinamen laeuft durch', (Bash 'curl -o Bankauszug.pdf https://example.org/x.pdf'), 'durchlass', ''),
    @('git status laeuft durch', (Bash 'git status -sb'), 'durchlass', ''),
    @('gh auth status ohne Token laeuft durch', (Bash 'gh auth status'), 'durchlass', ''),
    @('Markdown mit Bankadresse laeuft durch', (Datei (& $imRepo '10_System\Notiz.md') 'curl https://api.revolut.com ist gesperrt'), 'durchlass', ''),
    @('Sperre selbst schreiben laeuft durch', (Datei (& $imRepo '00_INDEX\scripts\guard-finanzen.ps1') 'git credential fill'), 'durchlass', ''),
    @('Javascript ohne Bezug laeuft durch', (Js 'document.title'), 'durchlass', ''),
    @('Read einer normalen Datei laeuft durch', @{ tool_name = 'Read'; session_id = $sid; tool_input = @{ file_path = (& $imRepo 'AGENTS.md') } }, 'durchlass', ''),
    @('Kein Werkzeug der Sperre laeuft durch', @{ tool_name = 'WebSearch'; session_id = $sid; tool_input = @{ query = 'paypal.com' } }, 'durchlass', '')
)

$gruen = 0; $alle = 0
"Interpreter: $psExe"
''
foreach ($f in $faelle) {
    $alle++
    $e = Entscheid $f[1]
    $ok = ($e.d -eq $f[2]) -and ([string]::IsNullOrEmpty($f[3]) -or $e.r -like ('*' + $f[3] + '*'))
    if ($ok) { $gruen++; 'OK    ' + $f[0] } else { 'FEHLT ' + $f[0] + ' (erhalten: ' + $e.d + ' / ' + $e.r + ')' }
}

function Pruefe([string]$titel, $eingabe, [string]$soll) {
    $script:alle++
    $e = Entscheid $eingabe
    if ($e.d -eq $soll) { $script:gruen++; 'OK    ' + $titel } else { 'FEHLT ' + $titel + ' (erhalten: ' + $e.d + ' / ' + $e.r + ')' }
}

# Tab-Gedaechtnis: eine angemeldete Banksitzung in einem Tab, den der Agent nicht selbst geoeffnet hat
$s2 = 'test-session-2'
$null = Entscheid (Post 'tabs_context_mcp' @{ tabs = @(@{ tabId = '101'; url = 'https://ebanking.musterbank.example/secure'; isActive = $true }, @{ tabId = '102'; url = 'https://de.wikipedia.org'; isActive = $false }) } $s2)
Pruefe 'Bank-Tab: read_page gesperrt' (Mcp 'read_page' @{ tabId = '101' } $s2) 'deny'
Pruefe 'Bank-Tab: Screenshot gesperrt' (Mcp 'computer' @{ tabId = '101'; action = 'screenshot' } $s2) 'deny'
Pruefe 'Bank-Tab im Vordergrund: get_page_text ohne tabId gesperrt' (Mcp 'get_page_text' @{} $s2) 'deny'
Pruefe 'Bank-Tab: Klick gesperrt' (Mcp 'computer' @{ tabId = '101'; action = 'left_click'; coordinate = @(10, 10) } $s2) 'deny'
Pruefe 'Bank-Tab: form_input gesperrt' (Mcp 'form_input' @{ tabId = '101'; ref = 'ref_1'; value = '1000' } $s2) 'deny'
Pruefe 'Bank-Tab: in den Vordergrund holen gesperrt' (Mcp 'tabs_select' @{ tabId = '101' } $s2) 'deny'
Pruefe 'Freier Tab: read_page laeuft durch' (Mcp 'read_page' @{ tabId = '102' } $s2) 'durchlass'
$s3 = 'test-session-3'
$null = Entscheid (Post 'computer' @{ text = 'Executed on tabId: 7. Tabs: tabId 7: "Konto" ("https://www.trading212.com/portfolio")' } $s3)
Pruefe 'Link zum Broker gefolgt: naechste Aktion gesperrt' (Mcp 'computer' @{ action = 'left_click'; coordinate = @(5, 5) } $s3) 'deny'

# Einmalcodes und Links aus Sicherheitsmails: nicht weiterverwenden
Pruefe 'Link mit Einmal-Token (Passwort) gesperrt' (Nav 'https://accounts.example.com/password/reset?token=Ab3dEf9hIjKlMn0pQrStUvWx12') 'deny'
Pruefe 'Bestaetigungslink mit Token gesperrt' (Nav 'https://app.example.org/verify-email/eyJhbGciOiJIUzI1NiJ9abc123XYZ') 'deny'
Pruefe 'Gewoehnlicher Link mit langer Kennung laeuft durch' (Nav 'https://docs.google.com/document/d/1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789/edit') 'durchlass'
Pruefe 'curl auf Link mit Einmal-Token gesperrt' (Bash 'curl https://example.com/auth/magic?token=Ab3dEf9hIjKlMn0pQrStUvWx12') 'deny'
Pruefe 'Sechsstelligen Code eintippen gesperrt' (Mcp 'form_input' @{ ref = 'ref_3'; value = '482913' } 'test-session-4') 'deny'
Pruefe 'Code mit Leerschlag eintippen gesperrt' (Mcp 'computer' @{ action = 'type'; text = '482 913' } 'test-session-4') 'deny'
Pruefe 'Ersatzcode eintippen gesperrt' (Mcp 'form_input' @{ ref = 'ref_3'; value = 'AB12C-9XY7Z' } 'test-session-4') 'deny'
Pruefe 'Normaler Text eintippen laeuft durch' (Mcp 'computer' @{ action = 'type'; text = 'Guten Tag Frau Muster' } 'test-session-4') 'durchlass'
$null = Entscheid (Mcp 'navigate' @{ url = 'https://login.example.com/verify' } 'test-session-5')
Pruefe 'Vierstelliger Code auf Anmeldeseite gesperrt' (Mcp 'computer' @{ action = 'type'; text = '4821' } 'test-session-5') 'deny'
Pruefe 'Vierstellige Zahl auf normaler Seite laeuft durch' (Mcp 'computer' @{ action = 'type'; text = '4821' } 'test-session-4') 'durchlass'

# Webmail und Konto-Sicherheitsseiten im Browser
Pruefe 'Gmail im Web gesperrt' (Nav 'https://mail.google.com/mail/u/0/#inbox') 'deny'
Pruefe 'Outlook im Web gesperrt' (Nav 'https://outlook.office.com/mail/') 'deny'
Pruefe 'GMX gesperrt' (Nav 'https://navigator-bs.gmx.net/mail') 'deny'
Pruefe 'Webmail-Unterdomain gesperrt' (Nav 'https://webmail.example.org/') 'deny'
Pruefe 'Webmail eines beliebigen Anbieters gesperrt' (Nav 'https://mail.anbieter-beispiel.ch/') 'deny'
Pruefe 'Google-Kontosicherheit gesperrt' (Nav 'https://myaccount.google.com/security') 'deny'
Pruefe 'GitHub-Tokenseite gesperrt' (Nav 'https://github.com/settings/tokens') 'deny'
Pruefe 'GitHub-Repo laeuft durch' (Nav 'https://github.com/example-org/example') 'durchlass'
Pruefe 'Google Drive laeuft durch' (Nav 'https://drive.google.com/drive/my-drive') 'durchlass'

# Sicherheitsmails in Ausgaben ausblenden (PostToolUse, updatedToolOutput)
function PruefeAusgabe([string]$titel, $eingabe, [bool]$soll, [string]$darfNicht = '', [hashtable]$umgebung = @{}) {
    $script:alle++
    $out = Roh $eingabe '' '' $umgebung
    $ok = $false
    if ($soll) {
        if (-not [string]::IsNullOrWhiteSpace($out)) {
            try {
                $o = $out | ConvertFrom-Json
                $txt = ($o.hookSpecificOutput.updatedToolOutput | ConvertTo-Json -Depth 20 -Compress)
                $ok = ($txt -match 'Ausgeblendet von guard-finanzen') -and (-not $darfNicht -or $txt -notmatch $darfNicht) -and ($o.hookSpecificOutput.hookEventName -eq 'PostToolUse')
            } catch { $ok = $false }
        }
    } else { $ok = [string]::IsNullOrWhiteSpace($out) }
    if ($ok) { $script:gruen++; 'OK    ' + $titel } else { 'FEHLT ' + $titel + ' (Ausgabe: ' + $out.Length + ' Zeichen)' }
}
function PostTool([string]$tool, $inp, $antwort) { @{ tool_name = $tool; session_id = 'test-session-6'; hook_event_name = 'PostToolUse'; tool_input = $inp; tool_response = $antwort } }
$mailText = "Von: noreply@example.org`nBetreff: Ihr Best" + [char]0xE4 + "tigungscode`n`nIhr Best" + [char]0xE4 + "tigungscode lautet 482913. Er ist 10 Minuten gueltig."
PruefeAusgabe 'Bash: Mail mit Code ausgeblendet, Code weg' (PostTool 'Bash' @{ command = 'python lies.py' } @{ stdout = ("Mail 1: Offerte`n" + $mailText + "`nMail 3: Protokoll"); stderr = ''; interrupted = $false; isImage = $false }) $true '482913'
PruefeAusgabe 'Bash: englische Mail mit Link ausgeblendet' (PostTool 'Bash' @{ command = 'x' } @{ stdout = 'Click here to reset your password: https://x.example/r?t=abc'; stderr = ''; interrupted = $false; isImage = $false }) $true 't=abc'
PruefeAusgabe 'Bash: Anleitung mit Stichwort, ohne Code, bleibt' (PostTool 'Bash' @{ command = 'grep x' } @{ stdout = ('Anmeldung per Einmal' + 'code an die Vereinsadresse, siehe Handbuch Kapitel 3'); stderr = ''; interrupted = $false; isImage = $false }) $false
PruefeAusgabe 'Bash: kurzer Code nach Stichwort ausgeblendet' (PostTool 'Bash' @{ command = 'x' } @{ stdout = 'Ihr SMS-Code: 4821'; stderr = ''; interrupted = $false; isImage = $false }) $true '4821'
PruefeAusgabe 'Bash: normale Ausgabe bleibt unveraendert' (PostTool 'Bash' @{ command = 'git status' } @{ stdout = "On branch main`nnothing to commit"; stderr = ''; interrupted = $false; isImage = $false }) $false
PruefeAusgabe 'Read ausserhalb des Repos: Mail ausgeblendet' (PostTool 'Read' @{ file_path = 'C:\Users\x\scratch\thread.md' } @{ type = 'text'; file = @{ filePath = 'C:\Users\x\scratch\thread.md'; content = $mailText; numLines = 4 } }) $true '482913'
$regel = & $imRepo '10_System\Notiz.md'
PruefeAusgabe 'Read eigener Datei im Repo bleibt' (PostTool 'Read' @{ file_path = $regel } @{ type = 'text'; file = @{ filePath = $regel; content = $mailText; numLines = 4 } }) $false
$inbox = & $imRepo '90_Inbox\mail.eml'
PruefeAusgabe 'Read einer Mail in 90_Inbox ausgeblendet' (PostTool 'Read' @{ file_path = $inbox } @{ type = 'text'; file = @{ filePath = $inbox; content = $mailText; numLines = 4 } }) $true '482913'
PruefeAusgabe 'Read im fremden Projekt: Mail ausgeblendet' (PostTool 'Read' @{ file_path = (Join-Path $fremdProjekt 'mail.md') } @{ type = 'text'; file = @{ filePath = (Join-Path $fremdProjekt 'mail.md'); content = $mailText; numLines = 4 } }) $true '482913' @{ CLAUDE_PROJECT_DIR = $fremdProjekt }
PruefeAusgabe 'MCP: Mail-Thread mit Code ausgeblendet' (PostTool 'mcp__abc__get_thread' @{ thread_id = '1' } @(@{ type = 'text'; text = ('482913 is your verification code') })) $true '482913'
PruefeAusgabe 'Browser: Webmail mit Code ausgeblendet' (PostTool 'mcp__claude-in-chrome__get_page_text' @{ } @{ text = 'Posteingang: Your sign-in code is 773311' }) $true '773311'

# SessionStart: Laeufe ohne Bedienung, Verdichtung und Testkinder im Temp-Ordner bekommen keine Meldung und verbrauchen sie nicht
$alle++
$k1 = Roh @{ hook_event_name = 'SessionStart'; session_id = 'k1'; source = 'startup' } '' '' @{ LEO_GRUNDPFLEGE = 'aus'; CLAUDE_PROJECT_DIR = $fremdProjekt }
$k2 = Roh @{ hook_event_name = 'SessionStart'; session_id = 'k2'; source = 'compact' } '' '' @{ CLAUDE_PROJECT_DIR = $fremdProjekt }
$k3 = Roh @{ hook_event_name = 'SessionStart'; session_id = 'k3'; source = 'startup' } '' '' @{ CLAUDE_PROJECT_DIR = (Join-Path ([System.IO.Path]::GetTempPath()) 'claude\kind') }
$verbraucht = Test-Path (Join-Path $tmp 'audit-gemeldet.json')
if ([string]::IsNullOrWhiteSpace($k1 + $k2 + $k3) -and -not $verbraucht) { $gruen++; 'OK    SessionStart still ohne Bedienung, nach Verdichtung und im Testkind' } else { 'FEHLT SessionStart still ohne Bedienung, nach Verdichtung und im Testkind (verbraucht: ' + $verbraucht + ')' }

# SessionStart: meldet einmal, dann nicht erneut (gleiche Befunde, unter sieben Tagen)
$alle++
$ss1 = Roh @{ hook_event_name = 'SessionStart'; session_id = 's7'; source = 'startup' } '' '' @{ CLAUDE_PROJECT_DIR = $fremdProjekt }
$ss2 = Roh @{ hook_event_name = 'SessionStart'; session_id = 's8'; source = 'startup' } '' '' @{ CLAUDE_PROJECT_DIR = $fremdProjekt }
$ok1 = $false
try { $ok1 = [string]::IsNullOrWhiteSpace($ss1) -or (($ss1 | ConvertFrom-Json).hookSpecificOutput.hookEventName -eq 'SessionStart') } catch { }
if ($ok1 -and [string]::IsNullOrWhiteSpace($ss2)) { $gruen++; 'OK    SessionStart meldet einmal, danach still' } else { 'FEHLT SessionStart meldet einmal, danach still (1: ' + $ss1.Length + ' Zeichen, 2: ' + $ss2.Length + ' Zeichen)' }
# Zwei Laeufe gleichzeitig (Sperre aus dem Repo und aus der Kopie): hoechstens eine Meldung
$alle++
foreach ($n in @('audit-gemeldet.json', 'audit-melden.lock')) { Remove-Item -LiteralPath (Join-Path $tmp $n) -Force -ErrorAction SilentlyContinue }
$gesperrt = Join-Path $tmp 'audit-melden.lock'
[System.IO.File]::WriteAllText($gesperrt, '')
$ss3 = Roh @{ hook_event_name = 'SessionStart'; session_id = 's9'; source = 'startup' } '' '' @{ CLAUDE_PROJECT_DIR = $fremdProjekt }
if ([string]::IsNullOrWhiteSpace($ss3)) { $gruen++; 'OK    SessionStart: zweiter gleichzeitiger Lauf meldet nicht' } else { 'FEHLT SessionStart: zweiter gleichzeitiger Lauf meldet nicht (' + $ss3.Length + ' Zeichen)' }
$alle++
$aj = Roh $null 'x' '-Audit -Json'
try { $null = $aj | ConvertFrom-Json; $gruen++; 'OK    Audit liefert gueltiges JSON' } catch { 'FEHLT Audit liefert gueltiges JSON (' + $aj.Length + ' Zeichen)' }
$alle++
$ohneZ = Roh $null 'x' ('-Audit -Json -Repo "' + $tmp + '"')
try { $null = $ohneZ | ConvertFrom-Json; $gruen++; 'OK    Audit ohne Zugaenge.md laeuft' } catch { 'FEHLT Audit ohne Zugaenge.md laeuft (' + $ohneZ.Length + ' Zeichen)' }

# Kaputte Eingabe
$alle++
$e = Entscheid $null '{"tool_name":"Bash","tool_input":{"command":"curl https://api.revolut.com" kaputt'
if ($e.d -eq 'deny') { $gruen++; 'OK    Kaputte Eingabe mit Bank gesperrt' } else { 'FEHLT Kaputte Eingabe mit Bank gesperrt (' + $e.d + ')' }
$alle++
$e = Entscheid $null '{"tool_name":"Bash","tool_input":{"command":"ls" kaputt'
if ($e.d -eq 'durchlass') { $gruen++; 'OK    Kaputte Eingabe ohne Bezug laeuft durch' } else { 'FEHLT Kaputte Eingabe ohne Bezug laeuft durch (' + $e.d + ')' }

# ASCII-Pruefung (laeuft unter Windows PowerShell 5.1)
foreach ($d in @($hook, (Join-Path $PSScriptRoot 'sicherheitsmail.json'))) {
    $alle++
    $bytes = [System.IO.File]::ReadAllBytes($d)
    if (@($bytes | Where-Object { $_ -gt 127 }).Count -eq 0) { $gruen++; 'OK    ASCII-only: ' + (Split-Path -Leaf $d) } else { 'FEHLT ASCII-only: ' + (Split-Path -Leaf $d) }
}

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
''
"$gruen von $alle gruen"
if ($gruen -eq $alle) { exit 0 } else { exit 1 }
