# guard-extern.ps1
# Zweck: PreToolUse-Hook fuer die Werkzeuge der Connectoren (MCP, seit 6.0, AGENTS.md Abschnitt 16). Sperrt
# die Aufrufe, die etwas versenden, loeschen, teilen oder in einen Google-Dienst schreiben, also genau die
# Wirkungen, die die Dateisperren nicht sehen: Mail senden, Termin loeschen oder zusagen, Datei teilen,
# Datei in Drive anlegen oder aendern, Termin anlegen oder aendern (ein Termin mit Gaesten verschickt
# Einladungen).
#
# WARUM: Diese Wirkungen sind nicht rueckrollbar und gehen an Dritte. Die Berechtigungsabfrage des
# Werkzeugs bremst sie nur, solange niemand auf "Erlauben" klickt; eine Rueckfrage zaehlt nicht als
# Sicherheitskontrolle. Schreiben in Google laeuft deshalb ueber ein Werkzeug mit Freigabefenster wie in
# der Sperre fuer Fremdsysteme (guard-fremdsysteme.ps1), nicht ueber den Connector.
#
# FREIGABEN: Die Datei 00_INDEX\extern-freigaben.txt gehoert dem Besitzer. Jede Zeile ist ein freigegebenes
# Werkzeug (Endung wie "create_event" oder der volle Name); alles ab '#' ist Kommentar. Ein eingetragenes
# Werkzeug laeuft wieder ueber den normalen Berechtigungsweg. Eintragen kann nur der Besitzer selbst, mit
# freigeben.ps1 -Werkzeug <name> in seinem eigenen Fenster; der Agent schreibt die Datei nie. Nach der
# Haertung liest dieser Hook die Kopie in der Schutzkopie.
#
# Die Endungen gelten fuer jeden Connector, weil die Kennung des Servers im Namen (mcp__<id>__<name>) je
# Einrichtung wechselt. Lesen, Suchen und Entwuerfe bleiben frei.
# Durchlass = stilles Exit 0. Ein eigener Fehler sperrt, wenn das Werkzeug eine gesperrte Endung traegt.
# ASCII-only: laeuft unter Windows PowerShell 5.1 und PowerShell 7. Regressionsreihe: guard-extern-tests.ps1.

$ErrorActionPreference = 'Stop'

$gesperrt = @(
    'send_message', 'reply', 'forward', 'send_email', 'send_draft',   # Mail: senden
    'trash_message', 'trash_thread', 'delete_message',                # Mail: loeschen
    'mark_message_spam', 'mark_thread_spam',                          # Mail: Spam-Einstufung
    'create_event', 'update_event', 'delete_event', 'respond_to_event', # Kalender
    'share_file', 'trash_file', 'delete_file',                        # Drive: teilen, loeschen
    'create_file', 'update_file', 'copy_file'                         # Drive: in Google schreiben
)

# Seit der Zweitpruefung von 6.0 zaehlt nicht nur die genaue Endung: Connectoren nennen dasselbe Werkzeug
# verschieden (slack_send_message, gmail_send_email, sendMessage). Gesperrt ist deshalb jede Endung, die eines
# dieser Woerter enthaelt (Woerter getrennt an _ und an Grossbuchstaben), dazu weitere Wirkungen nach aussen.
$sperrWoerter = @('send', 'reply', 'forward', 'trash', 'delete', 'spam', 'share')
$gesperrtZusatz = @('request_access', 'create_shared_drive', 'update_shared_drive', 'move_file')
# Werkzeuge der Desktop-App selbst (Sitzungen, Seitenleiste, geplante Aufgaben) wirken nicht nach aussen; fuer sie
# gilt nur die genaue Liste oben, nicht die Wortregel.
function Test-Gesperrt([string]$endung, [string]$server = '') {
    if ($gesperrt -contains $endung -or $gesperrtZusatz -contains $endung) { return $true }
    if ($server -match '^(ccd_.*|scheduled-tasks)$') { return $false }
    $woerter = @((($endung -creplace '([a-z0-9])([A-Z])', '$1_$2').ToLower()) -split '[_\-]+' | Where-Object { $_ })
    foreach ($w in $woerter) { if ($sperrWoerter -contains $w) { return $true } }
    return $false
}

function Write-Deny([string]$reason) {
    @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } } | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

$tool = ''
$suffix = ''
try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding($false)))).ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $tool = [string]($raw | ConvertFrom-Json).tool_name
    if ($tool -notmatch '^mcp__') { exit 0 }
    $suffix = ($tool -split '__')[-1]
    $server = [string](($tool -split '__')[1])
    if (-not (Test-Gesperrt $suffix $server)) { exit 0 }

    $datei = Join-Path (Split-Path -Parent $PSScriptRoot) 'extern-freigaben.txt'
    if (Test-Path -LiteralPath $datei) {
        $freigaben = @(Get-Content -LiteralPath $datei -Encoding UTF8 | ForEach-Object { ($_ -split '#')[0].Trim() } | Where-Object { $_ })
        if ($freigaben -contains $suffix -or $freigaben -contains $tool) { exit 0 }
    }
    $befehl = 'powershell -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\freigeben.ps1" -Werkzeug ' + $suffix
    Write-Deny ("Wirkung nach aussen gesperrt: '" + $suffix + "' versendet, loescht, teilt oder schreibt in einem externen System, und das ist nicht rueckrollbar (AGENTS.md Abschnitt 16). Schreiben in Google und vergleichbare Dienste laeuft nur ueber ein Werkzeug mit Freigabefenster; nennt eine eingehaengte Firmenschicht eines (README.md, schutzliste.txt), nimm es. Sonst sag [NAME] in zwei Saetzen, was du tun wolltest. Will er dieses Werkzeug dauerhaft erlauben, fuehrt nur er selbst in seinem eigenen Fenster aus (Repo-Pfad einsetzen): " + $befehl + " . Du schreibst die Freigabeliste nie und suchst keinen anderen Weg.")
} catch {
    if ($suffix -and (Test-Gesperrt $suffix ([string](($tool -split '__')[1])))) { Write-Deny ("Die Connector-Sperre konnte den Aufruf nicht pruefen (" + $_.Exception.Message + ") und sperrt deshalb '" + $suffix + "'.") }
    exit 0
}
