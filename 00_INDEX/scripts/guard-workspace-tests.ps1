# guard-workspace-tests.ps1
# Zweck: Regressionstest fuer die Arbeitsbereich-Sperre "guard-workspace.ps1".
#
# WARUM ES DAS GIBT: Der Guard ist die einzige Mechanik, die das Dateisystem
# ausserhalb des Repos schuetzt, und er ist genau so viel wert wie sein letzter
# Test. Die Luecke bei zur Laufzeit berechneten Zielpfaden ("Join-Path
# ([Environment]::GetFolderPath('Desktop')) ...") fiel nur auf, weil ein Agent
# sie zufaellig ausnutzte, und sie bestand ueber Monate unbemerkt.
#
# PFLICHT: Wer den Guard aendert, faehrt diese Reihe vorher und nachher. Wer eine
# neue Sperre einbaut, ergaenzt einen Fall. Eine Sperre ohne Testfall zaehlt nicht.
#
# AUFRUF (es wird nichts geschrieben, nur geurteilt):
#   pwsh -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\guard-workspace-tests.ps1"
# Optional gegen eine Arbeitskopie, BEVOR sie scharfgeschaltet wird:
#   ... -File <diese Datei> -Skript "<Repo>\00_INDEX\scripts\guard-workspace-neu.ps1"
#
# Die Faelle sind bewusst nicht an feste Pfade gebunden: Repo, Artefakte-Ordner,
# Belegarchiv und Benutzerordner werden zur Laufzeit aufgeloest, damit die Reihe
# in jedem System laeuft und nicht nur in dem, in dem sie geschrieben wurde.
#
# Bewusst ASCII-only, gleicher Grund wie beim Guard selbst: laeuft unter Windows
# PowerShell 5.1 genauso wie unter PowerShell 7.
#   ... -Exe powershell   faehrt den Guard unter Windows PowerShell 5.1, wie ihn die
#                         mitgelieferte settings.json unter Windows startet
param(
    [string]$Skript = (Join-Path $PSScriptRoot 'guard-workspace.ps1'),
    [string]$Exe = ""
)

$isWindowsHost = [System.IO.Path]::DirectorySeparatorChar -eq '\'
$repo      = [System.IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$artifacts = Join-Path (Split-Path -Parent $repo) ((Split-Path -Leaf $repo) + " Artifacts")
$archiv    = Join-Path (Split-Path -Parent $repo) ((Split-Path -Leaf $repo) + " Archiv")
$up        = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
$desktop   = Join-Path $up 'Desktop'

# PowerShell 7 bevorzugt, Windows PowerShell nur unter Windows als Rueckfall.
$psExe = (Get-Command $(if ($isWindowsHost) { 'pwsh.exe' } else { 'pwsh' }) -ErrorAction SilentlyContinue).Source
if (-not $psExe -and $isWindowsHost) { $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source }
if (-not $psExe -and -not $isWindowsHost) {
    $portablePwsh = Join-Path $PSHOME 'pwsh'
    if (Test-Path -LiteralPath $portablePwsh) { $psExe = $portablePwsh }
}
if ($Exe) { $psExe = (Get-Command $Exe -ErrorAction SilentlyContinue).Source }
if (-not $psExe) { "Kein passender PowerShell-Interpreter gefunden."; exit 1 }
$desktopDatei = Join-Path $desktop 'x.txt'

$windowsFaelle = @(
    # Zur Laufzeit berechnete Ziele: der Fall, fuer den diese Reihe gebaut wurde.
    @{ n = "1 GetFolderPath Desktop";      erw = "DENY"; tool = "Bash"; cmd = "`$d = Join-Path ([Environment]::GetFolderPath('Desktop')) 'x.txt'; [System.IO.File]::WriteAllText(`$d, 'x')" }
    @{ n = "2 env:USERPROFILE Desktop";    erw = "DENY"; tool = "Bash"; cmd = "Set-Content -LiteralPath `"`$env:USERPROFILE\Desktop\x.txt`" -Value 'x'" }
    @{ n = "3 Tilde Bash";                 erw = "DENY"; tool = "Bash"; cmd = "touch ~/test.txt" }
    @{ n = "5 env:LOCALAPPDATA fremd";     erw = "DENY"; tool = "Bash"; cmd = "New-Item -Path `"`$env:LOCALAPPDATA\Fremd\y.txt`" -ItemType File" }
    # Dieselben Ziele literal geschrieben: muessen unveraendert blockiert bleiben.
    @{ n = "4 literal Benutzerordner";     erw = "DENY"; tool = "Bash"; cmd = "[System.IO.File]::WriteAllText('$up\Desktop\x.txt', 'x')" }
    @{ n = "11 Write-Werkzeug ausserhalb"; erw = "DENY"; tool = "Write"; file = "$up\Desktop\x.md" }
    # Erlaubte Bereiche: muessen durchgehen, sonst wird die Sperre abgeschaltet.
    @{ n = "6 Scratchpad ueber env:TEMP";  erw = "PASS"; tool = "Bash"; cmd = "Set-Content -LiteralPath `"`$env:TEMP\claude\projekt\scratchpad\x.txt`" -Value 'x'" }
    @{ n = "7 Repo literal";               erw = "PASS"; tool = "Bash"; cmd = "Set-Content -LiteralPath '$repo\90_Inbox\x.md' -Value 'x'" }
    @{ n = "8 Artefakte-Ordner literal";   erw = "PASS"; tool = "Bash"; cmd = "Copy-Item '$repo\x.md' '$artifacts\x.md'" }
    @{ n = "14 Belegarchiv literal";       erw = "PASS"; tool = "Bash"; cmd = "Move-Item '$repo\90_Inbox\a.pdf' '$archiv\a.pdf'" }
    @{ n = "9 Memory-Pfad loeschen";       erw = "PASS"; tool = "Bash"; cmd = "Remove-Item `"`$env:USERPROFILE\.claude\projects\projekt\memory\alt.md`"" }
    @{ n = "12 Write-Werkzeug im Repo";    erw = "PASS"; tool = "Write"; file = "$repo\90_Inbox\x.md" }
    @{ n = "13 Repo-Pfad im git-Kommando"; erw = "PASS"; tool = "Bash"; cmd = "git add $repo\10_System\Kern-Dateien.md" }
    # Lesen bleibt frei, auch mit berechnetem Pfad ausserhalb des Repos.
    @{ n = "10 Lesen ausserhalb";          erw = "PASS"; tool = "Bash"; cmd = "Get-Content ([Environment]::GetFolderPath('Desktop') + '\x.txt')" }
    # Seit 3.3 (macOS-Fassung des Guards, Windows-Reihe): Bash-Variablen in geschweifter
    # Form, und Zeichenketten in Anfuehrungszeichen, die mit \ oder / beginnen, ohne
    # Pfad zu sein. Beides waren Abweichungen der ersten Fassung.
    @{ n = "15 HOME geschweift";           erw = "DENY"; tool = "Bash"; cmd = "touch `"`${HOME}/Desktop/x.txt`"" }
    @{ n = "16 HOMEDRIVE HOMEPATH";        erw = "DENY"; tool = "Bash"; cmd = "Set-Content `"`$env:HOMEDRIVE`$env:HOMEPATH\Desktop\x.txt`" 'x'" }
    @{ n = "17 Escape in Anfuehrungszeichen"; erw = "PASS"; tool = "Bash"; cmd = "printf `"\n`" >> x.md" }
    @{ n = "18 dev-null in Anfuehrungszeichen"; erw = "PASS"; tool = "Bash"; cmd = "git add x 2>`"/dev/null`"" }
)

$posixFaelle = @(
    @{ n = "1 GetFolderPath Desktop";      erw = "DENY"; tool = "Bash"; cmd = "`$d = Join-Path ([Environment]::GetFolderPath('Desktop')) 'x.txt'; [System.IO.File]::WriteAllText(`$d, 'x')" }
    @{ n = "2 HOME Desktop";               erw = "DENY"; tool = "Bash"; cmd = "touch `"`$HOME/Desktop/x.txt`"" }
    @{ n = "3 Tilde Bash";                 erw = "DENY"; tool = "Bash"; cmd = "touch ~/test.txt" }
    @{ n = "4 literal Benutzerordner";     erw = "DENY"; tool = "Bash"; cmd = "touch '$desktop/x.txt'" }
    @{ n = "5 anderer Temp-Ordner";        erw = "DENY"; tool = "Bash"; cmd = "touch '$([System.IO.Path]::GetTempPath())fremd/x.txt'" }
    @{ n = "6 Scratchpad ueber TMPDIR";    erw = "PASS"; tool = "Bash"; cmd = "touch `"`$TMPDIR/claude/projekt/x.txt`"" }
    @{ n = "7 Repo literal";               erw = "PASS"; tool = "Bash"; cmd = "touch '$repo/90_Inbox/x.md'" }
    @{ n = "8 Artefakte-Ordner literal";   erw = "PASS"; tool = "Bash"; cmd = "cp '$repo/x.md' '$artifacts/x.md'" }
    @{ n = "9 Memory-Pfad loeschen";       erw = "PASS"; tool = "Bash"; cmd = "rm '$up/.claude/projects/projekt/memory/alt.md'" }
    @{ n = "10 Lesen ausserhalb";          erw = "PASS"; tool = "Bash"; cmd = "cat '$desktop/x.txt'" }
    @{ n = "11 Write-Werkzeug ausserhalb"; erw = "DENY"; tool = "Write"; file = "$desktop/x.md" }
    @{ n = "12 Write-Werkzeug im Repo";    erw = "PASS"; tool = "Write"; file = "$repo/90_Inbox/x.md" }
    @{ n = "13 fremdes Arbeitsverzeichnis"; erw = "DENY"; tool = "Bash"; cmd = "touch x.md"; cwd = $desktop }
    @{ n = "14 Belegarchiv literal";       erw = "PASS"; tool = "Bash"; cmd = "mv '$repo/90_Inbox/a.pdf' '$archiv/a.pdf'" }
    # Seit 3.3: Geraetedateien und die geschweifte Variablenform.
    @{ n = "15 dev-null Umleitung";        erw = "PASS"; tool = "Bash"; cmd = "git add x 2>/dev/null" }
    @{ n = "16 HOME geschweift";           erw = "DENY"; tool = "Bash"; cmd = "touch `"`${HOME}/Desktop/x.txt`"" }
)

# Gemeinsame Folgefaelle: Temp-Variablen duerfen einander nicht als Praefix
# treffen; relative Ziele und einfache Umleitungen brauchen dieselbe Grenze
# wie absolute Ziele. Die Kommandos sind nur Hook-Eingaben, sie laufen nicht.
$folgeFaelle = @(
    @{ n = "19 env:TMPDIR Scratchpad";     erw = "PASS"; tool = "PowerShell"; cmd = 'Set-Content "$env:TMPDIR/claude/projekt/x.txt" -Value x' }
    @{ n = "20 env:TEMP Scratchpad";       erw = "PASS"; tool = "PowerShell"; cmd = 'Set-Content "$env:TEMP/claude/projekt/x.txt" -Value x' }
    @{ n = "21 env:TMP Scratchpad";        erw = "PASS"; tool = "PowerShell"; cmd = 'Set-Content "$env:TMP/claude/projekt/x.txt" -Value x' }
    @{ n = "22 Write relativer Ausbruch";  erw = "DENY"; tool = "Write"; file = "../outside/x.md" }
    @{ n = "23 Edit relativer Ausbruch";   erw = "DENY"; tool = "Edit"; file = "../outside/x.md" }
    @{ n = "24 Write relativ im Repo";     erw = "PASS"; tool = "Write"; file = "90_Inbox/x.md" }
    @{ n = "25 Shell relativer Ausbruch";  erw = "DENY"; tool = "Bash"; cmd = "touch ../outside/x.md" }
    @{ n = "26 Shell Punkt-Punkt im Repo"; erw = "PASS"; tool = "Bash"; cmd = "touch notes/../90_Inbox/x.md" }
    @{ n = "27 Shell tiefer Ausbruch";     erw = "DENY"; tool = "Bash"; cmd = "touch notes/../../outside/x.md" }
    @{ n = "28 Ausbruch mit Leerzeichen";  erw = "DENY"; tool = "Bash"; cmd = 'touch "../outside dir/x.md"' }
    @{ n = "29 Relativ mit Leerzeichen";   erw = "PASS"; tool = "Bash"; cmd = 'touch "notes/../90_Inbox/file with spaces.md"' }
    @{ n = "30 Einfaches > ausserhalb";    erw = "DENY"; tool = "Bash"; cmd = "printf x > $desktop/x.md" }
    @{ n = "31 Einfaches > im Repo";       erw = "PASS"; tool = "Bash"; cmd = "printf x > 90_Inbox/x.md" }
    @{ n = "32 Einfaches > mit Ausbruch";  erw = "DENY"; tool = "Bash"; cmd = "printf x > ../outside/x.md" }
    @{ n = "33 Einfaches > nach dev-null"; erw = "PASS"; tool = "Bash"; cmd = "printf x > /dev/null" }
    @{ n = "34 > ist nur zitierter Text";  erw = "PASS"; tool = "Bash"; cmd = "printf 'a > b'"; cwd = $desktop }
    # Seit 4.8: Lesen ausserhalb mit Stream-Umleitung ist kein Schreiben. Die erste
    # Fassung von 30 bis 34 zaehlte jedes > und sperrte diese Faelle.
    @{ n = "35 grep fremd 2>/dev/null";    erw = "PASS"; tool = "Bash"; cmd = "grep foo '$desktopDatei' 2>/dev/null" }
    @{ n = "36 Get-Content fremd 2>`$null"; erw = "PASS"; tool = "PowerShell"; cmd = "Get-Content '$desktopDatei' 2>`$null" }
    @{ n = "37 cat fremd 2>&1 | head";     erw = "PASS"; tool = "Bash"; cmd = "cat '$desktopDatei' 2>&1 | head" }
    @{ n = "38 ls fremd 2>/dev/null";      erw = "PASS"; tool = "Bash"; cmd = "ls '$up' 2>/dev/null" }
    @{ n = "39 git -C fremd log 2>&1";     erw = "PASS"; tool = "Bash"; cmd = "git -C '$up' log -1 2>&1" }
    @{ n = "40 Pfeil -> im Heredoc";       erw = "PASS"; tool = "Bash"; cmd = "python3 - <<'PY'`ndef f() -> str:`n    return open('$desktopDatei').read()`nPY" }
    @{ n = "41 >/dev/null und > `$null";    erw = "PASS"; tool = "Bash"; cmd = "grep x '$desktopDatei' >/dev/null 2>&1; Get-Content '$desktopDatei' > `$null" }
    @{ n = "42 Vergleich >= im Code";      erw = "PASS"; tool = "Bash"; cmd = "python3 -c `"print(len(open('$desktopDatei').read()) >= 1)`"" }
    @{ n = "43 fremd lesen, > Scratchpad"; erw = "PASS"; tool = "Bash"; cmd = "cat '$desktopDatei' > `"`$env:TEMP/claude/projekt/b.txt`"" }
    @{ n = "44 > ohne Abstand ausserhalb"; erw = "DENY"; tool = "Bash"; cmd = "echo x >'$desktopDatei'" }
    @{ n = "45 > Ziel mit Leerzeichen";    erw = "DENY"; tool = "Bash"; cmd = "echo x > '$(Join-Path $up 'Eigene Dateien')/x.txt'" }
    @{ n = "46 > absolut ins Repo";        erw = "PASS"; tool = "Bash"; cmd = "echo x > '$(Join-Path $repo '90_Inbox')/x.md'" }
    @{ n = "47 1> ausserhalb";             erw = "DENY"; tool = "Bash"; cmd = "echo x 1> '$desktopDatei'" }
    # Seit 4.8: git tag auflisten ist Lesen, setzen bleibt Schreiben.
    @{ n = "48 git tag auflisten + Lesen"; erw = "PASS"; tool = "Bash"; cmd = "ls '$up' 2>/dev/null; git tag --sort=-creatordate | head -3" }
    @{ n = "49 git tag nackt + Lesen";     erw = "PASS"; tool = "Bash"; cmd = "cat '$desktopDatei'; git tag" }
    @{ n = "50 git tag setzen ausserhalb"; erw = "DENY"; tool = "Bash"; cmd = "cd '$(Join-Path $up 'fremd')' && git tag v1.0" }
    # Seit 4.11: Verkettung nach git tag und zitiertes /dev/null (Rueckmeldung aus PR #9).
    @{ n = "51 git tag && Lesen fremd";    erw = "PASS"; tool = "Bash"; cmd = "git tag && cat '$desktopDatei'" }
    @{ n = "52 >`"/dev/null`" cwd fremd";   erw = "PASS"; tool = "Bash"; cmd = "cat x >`"/dev/null`""; cwd = $desktop }
    @{ n = "53 > zitiertes Ziel fremd";    erw = "DENY"; tool = "Bash"; cmd = "printf x >`"$desktopDatei`"" }
)
# Seit 5.0: Freigaben des Besitzers, Unter-Sperren, die Freigabelisten und freigeben.ps1.
# Die Freigabe traegt Umlaut und Leerzeichen; die Reihe reicht dem Hook eigene Testlisten
# ueber LEO_GUARD_FREIGABE_KONFIG und LEO_GUARD_READ_KONFIG, die echten bleiben unberuehrt.
$utf8 = New-Object System.Text.UTF8Encoding($false)
$frei = Join-Path (Join-Path $up ("Projekte " + [char]0x00C4)) 'Verein'
$freiUnter = Join-Path $frei 'Mitglieder'
$freiNurLesen = Join-Path (Join-Path $up ("Projekte " + [char]0x00C4)) "Nur Lesen"
$id = [System.Guid]::NewGuid().ToString('N')
$tmpDir = [System.IO.Path]::GetTempPath().TrimEnd('\', '/')
$freiKonfig = Join-Path $tmpDir ("guard-workspace-tests-frei-$id.txt")
$sperrKonfig = Join-Path $tmpDir ("guard-workspace-tests-sperre-$id.txt")
[System.IO.File]::WriteAllLines($freiKonfig, [string[]]@("# Testliste", ("lesen-und-schreiben: " + $frei), ("lesen: " + $freiNurLesen)), $utf8)
[System.IO.File]::WriteAllLines($sperrKonfig, [string[]]@("# Testliste", $freiUnter), $utf8)
$fg = Join-Path (Join-Path '00_INDEX' 'scripts') 'freigeben.ps1'
$freigabeFaelle = @(
    @{ n = "54 Write in Freigabe";         erw = "PASS"; tool = "Write"; file = (Join-Path $frei 'protokoll.md') }
    @{ n = "55 Set-Content in Freigabe";   erw = "PASS"; tool = "PowerShell"; cmd = "Set-Content -LiteralPath `"$(Join-Path $frei 'a b.md')`" -Value x" }
    @{ n = "56 Write in Unter-Sperre";     erw = "DENY"; tool = "Write"; file = (Join-Path $freiUnter 'liste.md'); muss = "-Entsperren" }
    @{ n = "57 Write Freigabeliste";       erw = "DENY"; tool = "Write"; file = (Join-Path (Join-Path $repo '00_INDEX') 'freigegebene-pfade.txt') }
    @{ n = "58 Edit Sperrliste";           erw = "DENY"; tool = "Edit"; file = (Join-Path (Join-Path $repo '00_INDEX') 'gesperrte-pfade.txt') }
    @{ n = "59 Add-Content Freigabeliste"; erw = "DENY"; tool = "PowerShell"; cmd = "Add-Content 00_INDEX/freigegebene-pfade.txt 'C:\x'" }
    @{ n = "60 >> in Freigabeliste";       erw = "DENY"; tool = "Bash"; cmd = "echo /x >> 00_INDEX/freigegebene-pfade.txt" }
    @{ n = "61 > in Sperrliste";           erw = "DENY"; tool = "Bash"; cmd = "printf '' > 00_INDEX/gesperrte-pfade.txt" }
    @{ n = "62 git checkout Freigabeliste"; erw = "DENY"; tool = "Bash"; cmd = "git checkout v5.0 -- 00_INDEX/freigegebene-pfade.txt" }
    @{ n = "63 git add Sperrliste";        erw = "DENY"; tool = "Bash"; cmd = "git add 00_INDEX/gesperrte-pfade.txt" }
    @{ n = "64 Freigabeliste lesen";       erw = "PASS"; tool = "PowerShell"; cmd = "Get-Content 00_INDEX/freigegebene-pfade.txt" }
    @{ n = "65 git log Freigabeliste";     erw = "PASS"; tool = "Bash"; cmd = "git log --oneline -- 00_INDEX/freigegebene-pfade.txt" }
    @{ n = "66 Liste lesen, dann touch";   erw = "PASS"; tool = "Bash"; cmd = "cat 00_INDEX/gesperrte-pfade.txt; touch 90_Inbox/x.md" }
    @{ n = "67 freigeben.ps1 per -File";   erw = "DENY"; tool = "PowerShell"; cmd = "powershell -NoProfile -File $fg `"C:\x`""; muss = "nur [NAME] selbst" }
    @{ n = "68 freigeben.ps1 per &";       erw = "DENY"; tool = "PowerShell"; cmd = "& .\$fg 'C:\x'" }
    @{ n = "69 freigeben.ps1 per pwsh -c"; erw = "DENY"; tool = "Bash"; cmd = "pwsh -c `"& './00_INDEX/scripts/freigeben.ps1' 'C:\x'`"" }
    @{ n = "70 freigeben.ps1 2. Segment";  erw = "DENY"; tool = "PowerShell"; cmd = "Get-Content x.md; .\$fg 'C:\y'" }
    @{ n = "71 freigeben.ps1 lesen";       erw = "PASS"; tool = "Bash"; cmd = "cat 00_INDEX/scripts/freigeben.ps1" }
    @{ n = "72 freigeben.ps1 git checkout"; erw = "PASS"; tool = "Bash"; cmd = "git checkout v5.0 -- 00_INDEX/scripts/freigeben.ps1" }
    @{ n = "73 freigeben.ps1 git add+commit"; erw = "PASS"; tool = "Bash"; cmd = "git add 00_INDEX/scripts/freigeben.ps1 && git commit -m x -- 00_INDEX/scripts/freigeben.ps1" }
    @{ n = "74 Write ausserhalb mit Befehl"; erw = "DENY"; tool = "Write"; file = "$desktop\x.md"; muss = "freigeben.ps1`" `"$desktop`"" }
    @{ n = "75 Praefix-Falle neben Freigabe"; erw = "DENY"; tool = "Write"; file = (Join-Path ($frei + '-alt') 'x.md') }
    # Seit 5.0: Eine Freigabe nur zum Lesen oeffnet das Schreiben nicht.
    @{ n = "78 Write in Lese-Freigabe";    erw = "DENY"; tool = "Write"; file = (Join-Path $freiNurLesen 'x.md'); muss = "nur zum Lesen" }
    @{ n = "79 Shell in Lese-Freigabe";    erw = "DENY"; tool = "PowerShell"; cmd = "Set-Content -LiteralPath `"$(Join-Path $freiNurLesen 'y.md')`" -Value x" }
    @{ n = "81 Umlaut in der Meldung heil"; erw = "DENY"; tool = "Write"; file = (Join-Path $freiNurLesen 'z.md'); muss = $freiNurLesen }
    @{ n = "80 Lese-Freigabe nur lesen";   erw = "PASS"; tool = "PowerShell"; cmd = "Get-Content -LiteralPath `"$(Join-Path $freiNurLesen 'y.md')`"" }
    # Seit 5.1: keine Rechteerhoehung aus der Session, Haertungsbefehl nur durch den Besitzer.
    @{ n = "82 Start-Process -Verb RunAs";  erw = "DENY"; tool = "PowerShell"; cmd = "Start-Process powershell -Verb RunAs -ArgumentList '-File x.ps1'" }
    @{ n = "83 sudo";                       erw = "DENY"; tool = "Bash"; cmd = "sudo cp a.txt /etc/x" }
    @{ n = "84 osascript Adminrechte";      erw = "DENY"; tool = "Bash"; cmd = "osascript -e 'do shell script `"ls`" with administrator privileges'" }
    @{ n = "85 runas";                      erw = "DENY"; tool = "Bash"; cmd = "runas /user:Administrator cmd" }
    @{ n = "86 sperre-haerten.ps1 starten"; erw = "DENY"; tool = "PowerShell"; cmd = "powershell -NoProfile -File 00_INDEX\scripts\sperre-haerten.ps1"; muss = "nur [NAME] selbst" }
    @{ n = "87 sperre-haerten.ps1 lesen";   erw = "PASS"; tool = "Bash"; cmd = "cat 00_INDEX/scripts/sperre-haerten.ps1" }
    @{ n = "88 sperre-haerten.ps1 git add"; erw = "PASS"; tool = "Bash"; cmd = "git add 00_INDEX/scripts/sperre-haerten.ps1" }
    @{ n = "90 sperre-haerten -Pruefen";    erw = "PASS"; tool = "PowerShell"; cmd = "powershell -NoProfile -File 00_INDEX\scripts\sperre-haerten.ps1 -Pruefen" }
    @{ n = "91 -Pruefen mit -Entfernen";    erw = "DENY"; tool = "PowerShell"; cmd = "powershell -NoProfile -File 00_INDEX\scripts\sperre-haerten.ps1 -Pruefen -Entfernen" }
    @{ n = "89 hooks-einrichten erlaubt";   erw = "PASS"; tool = "PowerShell"; cmd = "powershell -NoProfile -File 00_INDEX\scripts\hooks-einrichten.ps1 -Pruefen" }
)
if ($isWindowsHost) {
    $freigabeFaelle += @(
        @{ n = "76 touch /tmp/claude";     erw = "PASS"; tool = "Bash"; cmd = "touch /tmp/claude/projekt/x.txt" }
        @{ n = "77 touch /tmp fremd";      erw = "DENY"; tool = "Bash"; cmd = "touch /tmp/fremd/x.txt" }
    )
}
$faelle = @(if ($isWindowsHost) { $windowsFaelle } else { $posixFaelle }) + $folgeFaelle + $freigabeFaelle

function Ruf($skript, $fall, $exe, $cwd) {
    $ti = if ($fall.tool -in @("Write","Edit")) { @{ file_path = $fall.file } } else { @{ command = $fall.cmd } }
    $json = @{ session_id = "test"; hook_event_name = "PreToolUse"; cwd = $cwd; tool_name = $fall.tool; tool_input = $ti } | ConvertTo-Json -Depth 5 -Compress
    # Seit 5.0 als UTF-8-Bytes ueber ProcessStartInfo statt per Pipe: Ein Pipe kodiert je nach
    # Version anders, und die Faelle mit Umlaut im Pfad wuerden unter 5.1 am Treiber scheitern
    # statt am Hook. Dazu die Testlisten und LEO_GUARD_DEBUG, damit ein abgefangener
    # Hook-Fehler als FEHLER erscheint und nicht als PASS.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$skript`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $utf8
    $psi.EnvironmentVariables['LEO_GUARD_FREIGABE_KONFIG'] = $freiKonfig
    $psi.EnvironmentVariables['LEO_GUARD_READ_KONFIG'] = $sperrKonfig
    $psi.EnvironmentVariables['LEO_GUARD_DEBUG'] = '1'
    $p = [System.Diagnostics.Process]::Start($psi)
    $bytes = $utf8.GetBytes($json)
    $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($out -match '"permissionDecision"\s*:\s*"deny"') {
        if ($fall.ContainsKey('muss')) {
            $grund = ''
            try { $grund = [string](($out | ConvertFrom-Json).hookSpecificOutput.permissionDecisionReason) } catch { }
            if ($grund.IndexOf($fall.muss, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return "DENY ohne '" + $fall.muss + "'" }
        }
        return "DENY"
    }
    if ([string]::IsNullOrWhiteSpace($out)) { return "PASS" }
    return "FEHLER: " + ($out.Trim() -replace "`r?`n", " ")
}

"Geprueft wird: $Skript"
"Repo:          $repo"
"Interpreter:   $psExe"
""
$fehler = 0
"{0,-30} {1,-6} {2,-8} {3}" -f "Fall", "Erw.", "Ist", "Urteil"
"-" * 62
foreach ($f in $faelle) {
    $cwd = if ($f.ContainsKey('cwd')) { $f.cwd } else { $repo }
    $ist = Ruf $Skript $f $psExe $cwd
    $ok = if ($ist -eq $f.erw) { "ok" } else { "ABWEICHUNG" }
    if ($ist -ne $f.erw) { $fehler++ }
    "{0,-30} {1,-6} {2,-8} {3}" -f $f.n, $f.erw, $ist, $ok
}
Remove-Item -LiteralPath $freiKonfig, $sperrKonfig -ErrorAction SilentlyContinue
""
if ($fehler -eq 0) { "ALLE $($faelle.Count) FAELLE BESTANDEN"; exit 0 }
else { "$fehler VON $($faelle.Count) FAELLEN ABWEICHEND"; exit 1 }
