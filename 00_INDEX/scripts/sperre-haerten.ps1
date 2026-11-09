# sperre-haerten.ps1
# Zweck: Richtet die Haertung der Standardsperre mit verwalteten Einstellungen von Claude Code ein
# (Managed Settings, AGENTS.md Abschnitt 18, seit 5.1). Danach kann der Agent seine eigenen
# Sperren nicht mehr abschalten oder umschreiben, auch nicht mit Absicht: Hooks und Sperrlisten
# liegen dann in einem Systemordner, den nur ein Administrator aendern kann.
#
# NUR DER BESITZER FUEHRT ES AUS, in seinem eigenen Fenster. Es fragt einmal nach und fordert
# dann Administratorrechte an: unter Windows im Fenster der Benutzerkontensteuerung, auf dem Mac
# mit dem Passwort. Der Agent kann es nicht starten (guard-workspace.ps1 blockiert den Aufruf und
# jede Rechteerhoehung aus einer Session). Drei Regeln dazu: Claude nie "als Administrator
# ausfuehren", die Benutzerkontensteuerung nie abschalten, und nie eine Abfrage der
# Benutzerkontensteuerung oder ein Passwortfenster bestaetigen, das man nicht selbst ausgeloest hat.
#
# WAS ES EINRICHTET:
#   1. Eine Schutzkopie der vier Sperren, ihrer gemeinsamen Logik, des Verteilers leo-hook.ps1 und
#      der beiden Freigabelisten unter <Systemordner>\leo\<Repo-Name>.
#   2. Eine eigene Datei in <Systemordner>\managed-settings.d (eine bestehende managed-settings.json
#      der IT bleibt unangetastet) mit:
#      - allowManagedHooksOnly: Hooks aus den Projekt- und Benutzereinstellungen laufen nicht mehr,
#        nur diese. Das gilt fuer alle Projekte auf dem Rechner.
#      - allen Kern-Hooks des Leo-Kinds ueber den Verteiler; die Sperren greifen nur im Repo des
#        Leo-Kinds, andere Projekte merken davon nichts.
#      - "onFailure": "block" fuer die vier Sperren und den Lese-Verboten fuer Zugangsdaten.
#      - auf dem Mac auf Wunsch (-Sandbox) die eingebaute Sandbox von Claude Code, ebenfalls fest.
#   Systemordner: Windows C:\Program Files\ClaudeCode, macOS /Library/Application Support/ClaudeCode,
#   Linux /etc/claude-code.
#
# NACH JEDEM UPDATE UND JEDER FREIGABE: Die Schutzkopie aendert sich nicht von selbst. freigeben.ps1
# uebernimmt eine Freigabe selbst (mit einer Abfrage nach Adminrechten); nach einem Update meldet der
# Health-Check die Abweichung, und der Besitzer fuehrt diesen Befehl erneut aus.
#
# AUFRUF:
#   Windows:  powershell -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\sperre-haerten.ps1"
#   macOS:    sudo pwsh -NoProfile -File "<Repo>/00_INDEX/scripts/sperre-haerten.ps1"
#   -Pruefen     zeigt nur den Stand, braucht keine Adminrechte
#   -Entfernen   nimmt die Haertung zurueck
#   -NurListen   uebernimmt nur die beiden Freigabelisten (ruft freigeben.ps1 auf)
#   -Sandbox     macOS/Linux: zusaetzlich die Sandbox fest einschalten (gilt fuer alle Projekte)
# Testparameter: -Ziel <Ordner> ersetzt den Systemordner und laeuft ohne Rueckfrage und ohne Adminrechte.
# ASCII-only: laeuft unter Windows PowerShell 5.1 und PowerShell 7.
param(
    [switch]$Pruefen,
    [switch]$Entfernen,
    [switch]$NurListen,
    [switch]$Sandbox,
    [string]$Ziel = '',
    [switch]$Erhoeht,
    [string]$Protokoll = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path $PSScriptRoot 'lib') 'arbeitsbereich.ps1')
$repo = Normalize-AbsolutePath (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$ort = Get-HaertungsOrt $repo $Ziel
$test = [bool]$Ziel

function Melde([string]$t) {
    $t
    if ($Protokoll) { Add-Content -LiteralPath $Protokoll -Value $t -Encoding UTF8 }
}

if ($Pruefen) {
    $s = Get-HaertungsStand $repo $ort
    "Haertung fuer $repo"
    "  Systemordner:  $($ort.system)"
    "  Stand:         $($s.stand)"
    foreach ($a in $s.abweichend) { "  weicht ab:     $a" }
    if ($s.stand -eq 'fehlt') { exit 1 }
    exit 0
}

# --- Rueckfrage und Rechteerhoehung (nicht in der Testreihe) ----------------------------------
function Test-Admin {
    if ($isWindowsHost) {
        return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    return ((& id -u) -eq '0')
}
if (-not $test -and -not $Erhoeht) {
    if ([Console]::IsInputRedirected) {
        "sperre-haerten.ps1 laeuft nur in deinem eigenen Fenster, weil es nachfragt und Adminrechte anfordert. Aus einer Agenten-Session heraus ist es gesperrt (AGENTS.md Abschnitt 18). Nichts geaendert."
        exit 2
    }
    ""
    if ($Entfernen) { "Haertung entfernen fuer $repo." }
    elseif ($NurListen) { "Die Freigabelisten in die Schutzkopie uebernehmen, damit die Aenderung gilt." }
    else {
        "Haertung einrichten fuer $repo"
        ""
        "  - Die Sperren deines Agenten kommen in einen Systemordner, den nur ein Administrator aendern kann:"
        "    $($ort.kopie)"
        "  - Claude Code fuehrt danach nur noch diese Hooks aus, in allen Projekten auf diesem Rechner."
        "    Eigene Hooks anderer Projekte laufen dann nicht mehr. Die Sperren selbst greifen nur im Repo"
        "    deines Agenten; andere Projekte merken davon nichts."
        "  - Nach jedem Update deines Agenten fuehrst du diesen Befehl erneut aus (der Health-Check meldet es)."
        "  - Drei Regeln: Claude nie 'als Administrator ausfuehren', die Benutzerkontensteuerung nie"
        "    abschalten, und nie eine Rechteabfrage bestaetigen, die du nicht selbst ausgeloest hast."
    }
    ""
    # Beim Uebernehmen der Listen hat der Besitzer in freigeben.ps1 schon bestaetigt.
    if (-not $NurListen) {
        $antwort = Read-Host "Fortfahren? Danach fragt dein System nach Administratorrechten. (j/n)"
        if ($antwort -notmatch '^\s*(j|ja|y|yes)\s*$') { "Abgebrochen, nichts geaendert."; exit 1 }
    }
    if (-not (Test-Admin)) {
        $schalter = @()
        if ($Entfernen) { $schalter += '-Entfernen' }
        if ($NurListen) { $schalter += '-NurListen' }
        if ($Sandbox) { $schalter += '-Sandbox' }
        if ($isWindowsHost) {
            $log = Join-Path ([System.IO.Path]::GetTempPath()) ('leo-haerten-' + [System.Guid]::NewGuid().ToString('N') + '.log')
            $argl = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Erhoeht -Protokoll "' + $log + '" ' + ($schalter -join ' ')
            try { Start-Process -FilePath 'powershell' -Verb RunAs -Wait -ArgumentList $argl }
            catch { "Die Benutzerkontensteuerung wurde abgelehnt. Nichts geaendert."; exit 1 }
            if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Encoding UTF8; Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue }
            else { "Kein Ergebnis vom erhoehten Lauf erhalten. Pruefen mit -Pruefen." }
            exit 0
        }
        $pw = Join-Path $PSHOME 'pwsh'
        & sudo $pw -NoProfile -File $PSCommandPath -Erhoeht @schalter
        exit $LASTEXITCODE
    }
}

try {
    # --- Entfernen ------------------------------------------------------------------------------
    if ($Entfernen) {
        if (Test-Path -LiteralPath $ort.dropin) { Remove-Item -LiteralPath $ort.dropin -Force }
        if (Test-Path -LiteralPath $ort.kopie) { Remove-Item -LiteralPath $ort.kopie -Recurse -Force }
        Melde "Haertung entfernt. Ab dem naechsten Start von Claude Code gelten wieder die Hooks aus dem Repo."
        exit 0
    }

    # --- Schutzkopie ----------------------------------------------------------------------------
    $liste = if ($NurListen) { $haertungsListen } else { $haertungsDateien + $haertungsListen }
    foreach ($rel in $liste) {
        $q = Join-Path $repo $rel
        $k = Join-Path $ort.kopie $rel
        if (Test-Path -LiteralPath $q) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $k) | Out-Null
            Copy-Item -LiteralPath $q -Destination $k -Force
        } elseif (Test-Path -LiteralPath $k) { Remove-Item -LiteralPath $k -Force }
    }
    if ($NurListen) { Melde "Freigabelisten in die Schutzkopie uebernommen; sie gelten ab dem naechsten Werkzeugaufruf."; exit 0 }

    # --- Verwaltete Einstellungen ---------------------------------------------------------------
    $exe = if ($isWindowsHost) { 'powershell -NoProfile -ExecutionPolicy Bypass -File' } else { '"' + (Join-Path $PSHOME 'pwsh') + '" -NoProfile -File' }
    $verteiler = Join-Path (Join-Path (Join-Path $ort.kopie '00_INDEX') 'scripts') 'leo-hook.ps1'
    $kernRx = '00_INDEX[\\/]+scripts[\\/]+(guard-read|guard-workspace|guard-git|guard-mail|eingehaengte-repos-aktuell|pruef-frontmatter)\.ps1"?(?:\s+-Hook\s+(\w+))?'
    $settings = Get-Content -LiteralPath (Join-Path (Join-Path $repo '.claude') 'settings.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $hooks = [ordered]@{}
    $fremd = @()
    foreach ($ereignis in $settings.hooks.PSObject.Properties) {
        $gruppen = @()
        foreach ($gruppe in @($ereignis.Value)) {
            $neue = @()
            foreach ($h in @($gruppe.hooks)) {
                if ([string]$h.type -eq 'command' -and [string]$h.command -match $kernRx) {
                    $name = $matches[1]
                    $cmd = $exe + ' "' + $verteiler + '" -Repo "' + $repo + '" -Skript ' + $name
                    if ($matches[2]) { $cmd += ' -Hook ' + $matches[2] }
                    $e = [ordered]@{ type = 'command'; command = $cmd }
                    if ($h.timeout) { $e.timeout = $h.timeout }
                    if ($ereignis.Name -eq 'PreToolUse' -and $name -like 'guard-*') { $e.onFailure = 'block' }
                    $neue += $e
                } else { $fremd += ($ereignis.Name + ': ' + [string]$h.command) }
            }
            if ($neue.Count -gt 0) {
                $g = [ordered]@{}
                if ($gruppe.matcher) { $g.matcher = $gruppe.matcher }
                $g.hooks = $neue
                $gruppen += $g
            }
        }
        if ($gruppen.Count -gt 0) { $hooks[$ereignis.Name] = $gruppen }
    }
    $deny = @('Read(**/.env)', 'Read(**/.env.*)', 'Read(**/*.pem)', 'Read(**/*.key)', 'Read(**/*.pfx)',
              'Read(**/*.p12)', 'Read(**/*.kdbx)', 'Read(**/*.ppk)', 'Read(**/id_rsa*)', 'Read(**/id_ed25519*)',
              'Read(~/.ssh/**)', 'Read(~/.aws/**)', 'Read(~/.gnupg/**)', 'Read(~/.azure/**)', 'Read(~/.kube/**)',
              'Edit(**/00_INDEX/freigegebene-pfade.txt)', 'Edit(**/00_INDEX/gesperrte-pfade.txt)')
    $verwaltet = [ordered]@{
        allowManagedHooksOnly = $true
        permissions = [ordered]@{ deny = $deny }
        hooks = $hooks
    }
    if ($Sandbox -and -not $isWindowsHost) {
        $ab = Get-Arbeitsbereich $repo
        $verwaltet.sandbox = [ordered]@{
            enabled = $true
            failIfUnavailable = $true
            allowUnsandboxedCommands = $false
            filesystem = [ordered]@{
                denyRead = @('~/.ssh', '~/.aws', '~/.gnupg', '~/.azure', '~/.kube')
                allowWrite = @(@($ab.archiv, $ab.artifacts) + @($ab.freigabenSchreiben))
            }
        }
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ort.dropin) | Out-Null
    $text = $verwaltet | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText($ort.dropin, $text + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))

    Melde "Haertung eingerichtet."
    Melde "  Verwaltete Einstellungen: $($ort.dropin)"
    Melde "  Schutzkopie der Sperren:  $($ort.kopie)"
    if ($fremd.Count -gt 0) {
        Melde "  Nicht uebernommen (eigene Hooks, sie liefen sonst in allen Projekten und laufen jetzt nicht mehr):"
        foreach ($f in $fremd) { Melde "    $f" }
    }
    Melde "Wirkt ab dem naechsten Start von Claude Code. Danach in deinem Agenten testen: 'Lies eine Datei auf meinem Desktop' muss mit einer Sperrmeldung enden."
    exit 0
} catch {
    Melde ("Fehler: " + $_.Exception.Message + ". Nichts Halbes stehen lassen: mit -Entfernen zuruecknehmen und erneut ausfuehren.")
    exit 1
}
