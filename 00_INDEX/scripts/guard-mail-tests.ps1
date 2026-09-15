# guard-mail-tests.ps1
# Zweck: Regressionstest fuer die Mailversand-Sperre "guard-mail.ps1".
#
# PFLICHT: Wer den Hook aendert, faehrt diese Reihe vorher und nachher. Eine Sperre
# ohne Testfall zaehlt nicht (AGENTS.md, Abschnitt 18).
#
# AUFRUF (es wird nichts geschrieben und nichts gesendet, nur geurteilt):
#   pwsh -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\guard-mail-tests.ps1"
# Optional gegen eine Arbeitskopie: ... -Skript "<Repo>\00_INDEX\scripts\guard-mail-neu.ps1"
#
# Bewusst ASCII-only: laeuft unter Windows PowerShell 5.1 genauso wie unter PowerShell 7.
param(
    [string]$Skript = (Join-Path $PSScriptRoot 'guard-mail.ps1')
)

$isWindowsHost = [System.IO.Path]::DirectorySeparatorChar -eq '\'
$repo = [System.IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$sender = Join-Path $repo '00_INDEX\scripts\lib\gmail-senden.py'

$psExe = (Get-Command $(if ($isWindowsHost) { 'pwsh.exe' } else { 'pwsh' }) -ErrorAction SilentlyContinue).Source
if (-not $psExe -and $isWindowsHost) { $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source }
if (-not $psExe) { "Kein passender PowerShell-Interpreter gefunden."; exit 1 }

$faelle = @(
    @{ n = "1 smtplib in python -c";           erw = "DENY"; tool = "Bash";       cmd = "python -c `"import smtplib; s=smtplib.SMTP('x')`"" }
    @{ n = "2 Send-MailMessage";               erw = "DENY"; tool = "PowerShell"; cmd = "Send-MailMessage -To a@example.com -Subject x -SmtpServer s" }
    @{ n = "3 Gmail-API roh per curl";         erw = "DENY"; tool = "Bash";       cmd = "curl -X POST https://gmail.googleapis.com/gmail/v1/users/me/messages/send" }
    @{ n = "4 Gmail-Bibliothek direkt";        erw = "DENY"; tool = "Bash";       cmd = "python x.py  # dienst.users().messages().send(userId='me')" }
    @{ n = "5 Modul aus python -c laden";      erw = "DENY"; tool = "Bash";       cmd = "python -c `"import importlib.util as u; s=u.spec_from_file_location('g','$sender')`"" }
    @{ n = "6 Skript kopieren";                erw = "DENY"; tool = "PowerShell"; cmd = "Copy-Item '$sender' C:\Temp\gmail-senden.py" }
    @{ n = "7 Kopie ausserhalb aufrufen";      erw = "DENY"; tool = "Bash";       cmd = "python C:/Temp/gmail-senden.py --an a@example.com --betreff x --html t.html" }
    @{ n = "8 Eingabe-Automation";             erw = "DENY"; tool = "Bash";       cmd = "python -c `"import pyautogui; pyautogui.click(100,100)`"" }
    @{ n = "9 Outlook COM";                    erw = "DENY"; tool = "PowerShell"; cmd = "`$o = New-Object -ComObject outlook.application" }
    @{ n = "10 Sendeskript an seinem Platz";   erw = "PASS"; tool = "Bash";       cmd = "python `"$sender`" --an a@example.com --betreff x --html C:/Temp/t.html" }
    @{ n = "11 Sendeskript --offen";           erw = "PASS"; tool = "PowerShell"; cmd = "python `"$sender`" --offen" }
    @{ n = "12 anderes Python-Skript";         erw = "PASS"; tool = "Bash";       cmd = "python `"$repo\00_INDEX\scripts\session-kosten.py`"" }
    @{ n = "13 Wort Mail im Commit-Text";      erw = "PASS"; tool = "Bash";       cmd = "git commit -m `"Mailregeln dokumentiert`"" }
    @{ n = "14 anderes Werkzeug";              erw = "PASS"; tool = "Write";      file = "$repo\90_Inbox\x.md" }
)

function Ruf($skript, $fall, $exe) {
    $ti = if ($fall.tool -in @("Write","Edit")) { @{ file_path = $fall.file } } else { @{ command = $fall.cmd } }
    $json = @{ session_id = "test"; hook_event_name = "PreToolUse"; cwd = $repo; tool_name = $fall.tool; tool_input = $ti } | ConvertTo-Json -Depth 5 -Compress
    $out = $json | & $exe -NoProfile -ExecutionPolicy Bypass -File $skript 2>&1 | Out-String
    if ($out -match '"permissionDecision"\s*:\s*"deny"') { return "DENY" }
    if ([string]::IsNullOrWhiteSpace($out)) { return "PASS" }
    return "FEHLER: " + ($out.Trim() -replace "`r?`n", " ")
}

"Geprueft wird: $Skript"
"Interpreter:   $psExe"
""
$fehler = 0
"{0,-34} {1,-6} {2,-8} {3}" -f "Fall", "Erw.", "Ist", "Urteil"
"-" * 62
foreach ($f in $faelle) {
    $ist = Ruf $Skript $f $psExe
    $ok = if ($ist -eq $f.erw) { "ok" } else { "ABWEICHUNG" }
    if ($ist -ne $f.erw) { $fehler++ }
    "{0,-34} {1,-6} {2,-8} {3}" -f $f.n, $f.erw, $ist, $ok
}
""
if ($fehler -eq 0) { "ALLE $($faelle.Count) FAELLE BESTANDEN"; exit 0 }
else { "$fehler VON $($faelle.Count) FAELLEN ABWEICHEND"; exit 1 }
