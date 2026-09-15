# guard-mail.ps1
# Zweck: PreToolUse-Hook fuer Bash und PowerShell. Sperrt jeden Mailversand aus einer
# Session, der nicht ueber das eine Skript laeuft, das die Mailregeln des Systems traegt
# (00_INDEX\scripts\lib\gmail-senden.py; Regel in AGENTS.md, Abschnitt 16):
#   - jede Mail legt offen, dass der KI-Assistent sie geschrieben hat und dass sie Fehler
#     enthalten kann,
#   - der Besitzer steht IMMER im CC,
#   - Absender ist die eigene Adresse des Assistenten,
#   - Text aus einer Session geht nur hinaus, wenn der Besitzer ihn im Freigabefenster auf
#     seinem Bildschirm sieht und auf "Senden" klickt (Details in gmail-senden.py).
# Dieser Hook stellt sicher, dass kein anderer Weg (eigener Gmail-API-Aufruf, smtplib,
# Send-MailMessage, .NET-Mail, Kommandozeilen-Mailer, Mail-Client per COM, das Modul
# gmail-senden.py aus einem eigenen python -c oder aus einer Kopie, Tastatur- oder
# Maus-Automation, die den Klick im Freigabefenster ersetzen wuerde) an den Regeln vorbei
# eine Mail absetzt. Direkt senden darf nur eine in gmail-senden.py registrierte Routine
# ohne Modell (Liste ROUTINEN im Konfigurationsblock), und auch sie sendet ueber das Skript.
#
# WIE guard-workspace.ps1 UND guard-git.ps1: Durchlass = stilles Exit 0, JSON nur beim
# Blockieren, jeder eigene Fehler endet im Durchlassen (der normale Berechtigungsweg
# bleibt). ASCII-only mit BOM, laeuft unter Windows PowerShell 5.1 und PowerShell 7.
# Bewusst ein eigener Hook und nicht Teil von guard-workspace.ps1: Ein Fehler in einem
# neuen Hook darf den bewaehrten nicht mitreissen (AGENTS.md, Abschnitt 18).
#
# EINRICHTUNG: Eingehaengt in .claude\settings.json (und .codex\hooks.json), Ereignis
# PreToolUse, Matcher Bash|PowerShell. Beide Dateien liegen im Paket bei.
# Regressionsreihe: guard-mail-tests.ps1 im selben Ordner, Pflicht vor und nach jeder
# Aenderung an diesem Skript.
#
# BEKANNTE GRENZE (wie bei den anderen Sperren): Der Hook sieht nur den Text des
# Werkzeugaufrufs. Wer einen Sendeweg aus Teilstuecken zusammensetzt oder ihn in eine
# Datei schreibt und diese ausfuehrt, kommt vorbei. Die Sperre ist gegen das Versehen
# gebaut, nicht gegen die Umgehung; die Regel in AGENTS.md gilt daneben als Textregel.

$ErrorActionPreference = "Stop"

function Write-Decision([string]$decision, [string]$reason) {
    if ($decision -ne "deny") { exit 0 }
    $out = @{
        hookSpecificOutput = @{
            hookEventName            = "PreToolUse"
            permissionDecision       = "deny"
            permissionDecisionReason = $reason
        }
    }
    $out | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

$grund = "Mailversand gesperrt: Mails aus einer Session gehen ausschliesslich ueber python <Repo>\00_INDEX\scripts\lib\gmail-senden.py, das ein Freigabefenster auf dem Bildschirm des Besitzers oeffnet; gesendet wird erst nach seinem Klick auf Senden (Werkzeug-Timeout 600000 ms setzen). Direkt senden darf nur eine dort registrierte Routine ohne Modell. Nur in diesem Skript sind die Regeln erzwungen: Offenlegung, Besitzer immer im CC, eigene Absenderadresse, Freigabe durch den Besitzer, kein Repo-Pfad als Text oder Anhang, Sperrbegriffe (AGENTS.md, Abschnitt 16). Ein eigener Sendeweg wird nie gebaut, das Modul nie aus python -c geladen, das Skript nie kopiert, der Klick im Fenster nie automatisiert; braucht es eine neue Faehigkeit, wird sie in gmail-senden.py ergaenzt."

try {

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { Write-Decision "defer" "" }
$in = $raw | ConvertFrom-Json
$tool = [string]$in.tool_name
if ($tool -ne "Bash" -and $tool -ne "PowerShell") { Write-Decision "defer" "" }

$cmd = [string]$in.tool_input.command
if ([string]::IsNullOrWhiteSpace($cmd)) { Write-Decision "defer" "" }

# Fremde Sendewege, die ohne die Regeln auskommen wuerden.
$sendewege = @(
    'messages\(\)\.send\(',              # Gmail API ueber die Python-Bibliothek
    'users/me/messages/send',            # Gmail API roh (curl, Invoke-WebRequest)
    'users/me/drafts',                   # Gmail-Entwuerfe roh
    'gmail\.googleapis\.com',            # dito
    'smtplib',                           # Python SMTP
    'Send-MailMessage',                  # PowerShell SMTP
    'System\.Net\.Mail',                 # .NET SMTP
    'MailKit', 'MimeKit',                # .NET Bibliotheken
    'sendmail', 'msmtp', 'blat\b',       # Kommandozeilen-Mailer
    'NovellGroupWareSession',            # Novell-Mail-Client per COM (Senden ueber den Client)
    'outlook\.application'               # Outlook COM
)
foreach ($muster in $sendewege) {
    if ($cmd -match $muster) { Write-Decision "deny" $grund }
}

# Das Sendemodul selbst: nur als Skriptaufruf an seinem Platz, nie als Modul aus eigenem Code.
$modulMissbrauch = @(
    'python[^\r\n|;&]*\s-c\s[^\r\n]*gmail[-_]senden',                     # python -c mit dem Modul
    '(import|import_module|spec_from_file_location|exec_module|runpy|exec\()[^\r\n]*gmail[-_]senden',
    'gmail[-_]senden[^\r\n]*(import_module|spec_from_file_location|exec_module)',
    '(\bcp\b|\bcopy\b|Copy-Item|\bmv\b|\bmove\b|Move-Item)[^\r\n|;&]*gmail-senden\.py'  # Kopie oder Verschiebung
)
foreach ($muster in $modulMissbrauch) {
    if ($cmd -match $muster) { Write-Decision "deny" $grund }
}

# Tastatur- und Maus-Automation, die den Klick im Freigabefenster ersetzen koennte.
$eingabeAutomation = @(
    'SendKeys', 'SendInput', 'keybd_event', 'mouse_event', 'SetCursorPos', 'user32\.dll',
    'System\.Windows\.Automation', 'UIAutomation', 'pyautogui', 'pywinauto', 'pynput', 'AutoHotkey', '\bxdotool\b',
    'WScript\.Shell', 'AppActivate'
)
foreach ($muster in $eingabeAutomation) {
    if ($cmd -match $muster) { Write-Decision "deny" ("Eingabe-Automation gesperrt (" + $muster + "): Der Klick im Freigabefenster von gmail-senden.py gehoert dem Besitzer; Tastatur- oder Maussteuerung aus einer Session ersetzt ihn nicht (AGENTS.md, Abschnitt 16).") }
}

# python ... gmail-senden.py: nur der Pfad im Repo (scripts\lib\gmail-senden.py) direkt hinter python.
if ($cmd -match 'python[^\r\n|;&]*[\\/\s"'']gmail-senden\.py') {
    if ($cmd -notmatch 'python(3|\.exe)?\s+"?[^"\s;&|]*scripts[\\/]lib[\\/]gmail-senden\.py') { Write-Decision "deny" $grund }
}

Write-Decision "defer" ""

} catch {
    Write-Decision "defer" ""
}
