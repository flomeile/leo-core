# guard-read-tests.ps1
# Zweck: Regressionstest fuer die Lese-Sperre "guard-read.ps1" (Standardsperre seit 5.0).
#
# PFLICHT: Wer den Hook oder lib\arbeitsbereich.ps1 aendert, faehrt diese Reihe vorher und
# nachher, unter beiden Interpretern. Eine Sperre ohne Testfall zaehlt nicht (AGENTS.md,
# Abschnitt 18).
#
# AUFRUF (es wird nichts gelesen und nichts geschrieben, nur geurteilt):
#   pwsh -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\guard-read-tests.ps1"
#   ... -Exe powershell    faehrt den Hook unter Windows PowerShell 5.1, wie ihn die
#                          mitgelieferte settings.json unter Windows startet
#   ... -Skript "<Repo>\00_INDEX\scripts\guard-read-neu.ps1"   gegen eine Arbeitskopie
#
# Die Reihe legt eigene Freigabe- und Sperrlisten im Temp-Ordner an und reicht sie dem Hook ueber
# LEO_GUARD_FREIGABE_KONFIG und LEO_GUARD_READ_KONFIG; die echten Listen in 00_INDEX bleiben
# unberuehrt. Die Pfade werden zur Laufzeit gebildet, damit die Reihe in jedem System laeuft.
# Bewusst ASCII-only: Umlaute kommen aus [char]-Codes.
param(
    [string]$Skript = (Join-Path $PSScriptRoot 'guard-read.ps1'),
    [string]$Exe = ""
)

$isWindowsHost = [System.IO.Path]::DirectorySeparatorChar -eq '\'
$repo = [System.IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$repoName = Split-Path -Leaf $repo
$archiv = Join-Path (Split-Path -Parent $repo) ($repoName + " Archiv")
$artifacts = Join-Path (Split-Path -Parent $repo) ($repoName + " Artifacts")
$profil = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
$desktop = Join-Path $profil 'Desktop'
$tmp = [System.IO.Path]::GetTempPath().TrimEnd('\', '/')
$scratch = Join-Path (Join-Path (Join-Path $tmp 'claude') 'projekt') 'scratchpad'
$harness = Join-Path (Join-Path (Join-Path $profil '.claude') 'projects') ($repo -replace '[^A-Za-z0-9]', '-')
$fremdProjekt = Join-Path (Join-Path (Join-Path $profil '.claude') 'projects') 'C--Fremdes-Projekt'

$psExe = (Get-Command $(if ($isWindowsHost) { 'pwsh.exe' } else { 'pwsh' }) -ErrorAction SilentlyContinue).Source
if (-not $psExe -and $isWindowsHost) { $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source }
if ($Exe) { $psExe = (Get-Command $Exe -ErrorAction SilentlyContinue).Source }
if (-not $psExe) { "Kein passender PowerShell-Interpreter gefunden."; exit 1 }

# Testlisten. Freigabe mit Umlaut und Leerzeichen, darin eine Unter-Sperre.
$ae = [string][char]0x00E4
$frei = Join-Path (Join-Path $profil ("Projekte " + [char]0x00C4)) 'Verein'
$freiUnter = Join-Path $frei 'Mitglieder'
$freiNachbar = $frei + '-alt'
$nichtFrei = Join-Path (Join-Path $profil ("Projekte " + [char]0x00C4)) 'Andere'
$gesperrt = if ($isWindowsHost) { 'C:\Kundenkonfigurationen' } else { '/srv/kundenkonfigurationen' }
$gesperrtSlash = $gesperrt -replace '\\', '/'
$gesperrtGitBash = if ($isWindowsHost) { '/c/Kundenkonfigurationen' } else { $gesperrt }
$umlaut = 'Anh' + $ae + 'nge-Test'
$gesperrtUmlaut = if ($isWindowsHost) { "C:\$umlaut" } else { "/srv/$umlaut" }
$id = [System.Guid]::NewGuid().ToString('N')
$freiKonfig = Join-Path $tmp ("guard-read-tests-frei-$id.txt")
$sperrKonfig = Join-Path $tmp ("guard-read-tests-sperre-$id.txt")
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($freiKonfig, [string[]]@("# Testliste", ("lesen: " + $frei)), $utf8)
[System.IO.File]::WriteAllLines($sperrKonfig, [string[]]@("# Testliste der Regressionsreihe", "", $gesperrt, "~/gesperrt-privat", "keine", $gesperrtUmlaut, $freiUnter), $utf8)

$faelle = @(
    # Zugangsdaten: immer gesperrt.
    @{ n = "1 Read .env";                          erw = "DENY"; tool = "Read"; file = "$repo\.env" }
    @{ n = "2 Read .env.production";               erw = "DENY"; tool = "Read"; file = "$repo\config\.env.production" }
    @{ n = "3 Read SSH-Schluessel";                erw = "DENY"; tool = "Read"; file = "$profil\.ssh\id_ed25519" }
    @{ n = "4 Read AWS-Credentials";               erw = "DENY"; tool = "Read"; file = "$profil\.aws\credentials" }
    @{ n = "5 Read .pem";                          erw = "DENY"; tool = "Read"; file = "$profil\Downloads\server.pem" }
    @{ n = "6 Read Token-Datei";                   erw = "DENY"; tool = "Read"; file = "$profil\.mein-dienst-token.txt" }
    @{ n = "10 Bash cat .env";                     erw = "DENY"; tool = "Bash"; cmd = "cat .env"; muss = "kein Befehl" }
    @{ n = "11 Bash type Schluesseldatei";         erw = "DENY"; tool = "Bash"; cmd = "type `"$profil\keys\server.key`"" }
    @{ n = "13 PowerShell Get-Content .ssh";       erw = "DENY"; tool = "PowerShell"; cmd = "Get-Content ~/.ssh/config" }
    @{ n = "14 Bash secrets.json";                 erw = "DENY"; tool = "Bash"; cmd = "python -c `"print(open('secrets.json').read())`"" }
    @{ n = "51 Zugangsdaten trotz Freigabe .env";  erw = "DENY"; tool = "Read"; file = (Join-Path $frei '.env') }
    @{ n = "52 Zugangsdaten trotz Freigabe .key";  erw = "DENY"; tool = "Bash"; cmd = "cat `"$(Join-Path $frei 'server.key')`"" }
    # Gesperrte Pfade (die alte Liste wirkt weiter).
    @{ n = "7 Read gesperrter Ordner";             erw = "DENY"; tool = "Read"; file = "$gesperrt\kunde-a\driver.xml" }
    @{ n = "8 Read gesperrt, Slash-Form";          erw = "DENY"; tool = "Read"; file = "$gesperrtSlash/kunde-a/driver.xml" }
    @{ n = "9 Grep im gesperrten Ordner";          erw = "DENY"; tool = "Grep"; path = "$gesperrt" }
    @{ n = "12 Bash gesperrt in Git-Bash-Form";    erw = "DENY"; tool = "Bash"; cmd = "head -50 $gesperrtGitBash/kunde-a/policy.xml" }
    @{ n = "15 Read gesperrt mit Tilde";           erw = "DENY"; tool = "Read"; file = "$profil\gesperrt-privat\notiz.md" }
    @{ n = "27 Read gesperrt mit Umlaut";          erw = "DENY"; tool = "Read"; file = "$gesperrtUmlaut\a.txt" }
    @{ n = "28 Bash gesperrt mit Umlaut";          erw = "DENY"; tool = "Bash"; cmd = "cat `"$gesperrtUmlaut/b.txt`"" }
    # Ausserhalb des Arbeitsbereichs: seit 5.0 gesperrt, mit Freigabebefehl in der Meldung.
    @{ n = "17 Read fremde Datei ausserhalb";      erw = "DENY"; tool = "Read"; file = "$desktop\bericht.md"; muss = "freigeben.ps1`" `"$desktop`"" }
    @{ n = "29 Bash cat ausserhalb";               erw = "DENY"; tool = "Bash"; cmd = "cat '$desktop\bericht.md'"; muss = "freigeben.ps1" }
    @{ n = "30 Grep Pfad ausserhalb";              erw = "DENY"; tool = "Grep"; path = "$profil\Documents" }
    @{ n = "31 Glob absolutes Muster ausserhalb";  erw = "DENY"; tool = "Glob"; pattern = (($profil -replace '\\', '/') + '/Documents/**/*.md') }
    @{ n = "34 ls Tilde";                          erw = "DENY"; tool = "Bash"; cmd = "ls ~" }
    @{ n = "35 Get-ChildItem env:USERPROFILE";     erw = "DENY"; tool = "PowerShell"; cmd = "Get-ChildItem `$env:USERPROFILE\Documents" }
    @{ n = "36 GetFolderPath Desktop lesen";       erw = "DENY"; tool = "PowerShell"; cmd = "Get-Content ([Environment]::GetFolderPath('Desktop') + '\x.txt')" }
    @{ n = "37 git -C ausserhalb";                 erw = "DENY"; tool = "Bash"; cmd = "git -C '$profil\anderes-repo' log -1" }
    @{ n = "38 cd .. und ls";                      erw = "DENY"; tool = "Bash"; cmd = "cd .. && ls" }
    @{ n = "39 Arbeitsverzeichnis ausserhalb";     erw = "DENY"; tool = "Bash"; cmd = "ls"; cwd = $desktop }
    @{ n = "45 fremder Projektordner Werkzeug";    erw = "DENY"; tool = "Read"; file = (Join-Path $fremdProjekt 'sitzung.jsonl') }
    @{ n = "53 Praefix-Falle neben Freigabe";      erw = "DENY"; tool = "Read"; file = (Join-Path $freiNachbar 'x.md') }
    @{ n = "55 Umlaut-Pfad nicht freigegeben";     erw = "DENY"; tool = "Bash"; cmd = "cat `"$(Join-Path $nichtFrei 'x.md')`"" }
    @{ n = "68 Umlaut in der Meldung heil";       erw = "DENY"; tool = "Read"; file = (Join-Path $nichtFrei 'x.md'); muss = $nichtFrei }
    @{ n = "63 Meldung fragt nach der Stufe";     erw = "DENY"; tool = "Read"; file = "$desktop\bericht.md"; muss = "welche Stufe die Aufgabe braucht" }
    # Eingebaute Zonen: frei.
    @{ n = "16 Read Repo-Datei";                   erw = "PASS"; tool = "Read"; file = "$repo\AGENTS.md" }
    @{ n = "24 Grep im Repo";                      erw = "PASS"; tool = "Grep"; path = "$repo\10_System" }
    @{ n = "33 Grep ohne Pfad im Repo";            erw = "PASS"; tool = "Grep"; path = "" }
    @{ n = "32 Glob relatives Muster";             erw = "PASS"; tool = "Glob"; pattern = "**/*.md" }
    @{ n = "40 Read Archiv";                       erw = "PASS"; tool = "Read"; file = (Join-Path $archiv '2026-01-01_Quelle.pdf') }
    @{ n = "41 Bash cat Artifacts";                erw = "PASS"; tool = "Bash"; cmd = "cat `"$(Join-Path $artifacts 'x\README.md')`"" }
    @{ n = "42 Scratchpad ueber env:TEMP";         erw = "PASS"; tool = "PowerShell"; cmd = "Get-Content `"`$env:TEMP\claude\projekt\scratchpad\x.txt`"" }
    @{ n = "43 Scratchpad literal";                erw = "PASS"; tool = "Read"; file = (Join-Path $scratch 'x.txt') }
    @{ n = "44 Werkzeugausgabe eigenes Projekt";   erw = "PASS"; tool = "Read"; file = (Join-Path (Join-Path (Join-Path $harness 'sitzung') 'tool-results') 'a.txt') }
    @{ n = "54 Read Freigabeliste im Repo";        erw = "PASS"; tool = "Read"; file = "$repo\00_INDEX\freigegebene-pfade.txt" }
    @{ n = "61 Bash Repo-Pfad absolut";            erw = "PASS"; tool = "Bash"; cmd = "cat `"$repo\AGENTS.md`"" }
    # Freigabe mit Umlaut und Leerzeichen: frei; darin die Unter-Sperre: gesperrt.
    @{ n = "46 Read in Freigabe";                  erw = "PASS"; tool = "Read"; file = (Join-Path $frei 'protokoll.md') }
    @{ n = "47 Bash cat in Freigabe";              erw = "PASS"; tool = "Bash"; cmd = "cat `"$(Join-Path $frei 'a b.md')`"" }
    @{ n = "48 Grep in Freigabe";                  erw = "PASS"; tool = "Grep"; path = $frei }
    @{ n = "49 Read Unter-Sperre in Freigabe";     erw = "DENY"; tool = "Read"; file = (Join-Path $freiUnter 'liste.xlsx'); muss = "-Entsperren" }
    @{ n = "50 Bash Unter-Sperre in Freigabe";     erw = "DENY"; tool = "Bash"; cmd = "ls `"$freiUnter`"" }
    # Keine Pfade, keine Sperre.
    @{ n = "18 Bash python-dotenv";                erw = "PASS"; tool = "Bash"; cmd = "pip install python-dotenv" }
    @{ n = "19 Bash .environment";                 erw = "PASS"; tool = "Bash"; cmd = "cat .environment" }
    @{ n = "20 Bash tokenizer.json";               erw = "PASS"; tool = "Bash"; cmd = "cat models/tokenizer.json" }
    @{ n = "21 PowerShell env-Variable";           erw = "PASS"; tool = "PowerShell"; cmd = "`$env:PATH -split ';'" }
    @{ n = "22 Bash Wort monkey";                  erw = "PASS"; tool = "Bash"; cmd = "grep -n monkey 10_System/Technik.md" }
    @{ n = "23 Bash Skript liest Token selbst";    erw = "PASS"; tool = "Bash"; cmd = "pwsh -File 00_INDEX/scripts/health-check.ps1" }
    @{ n = "25 Write bleibt Sache des anderen Hooks"; erw = "PASS"; tool = "Write"; file = "$profil\.env" }
    @{ n = "26 Marker keine ist kein Pfad";         erw = "PASS"; tool = "Bash"; cmd = "echo keine Aenderung" }
    @{ n = "58 URL ist kein Pfad";                 erw = "PASS"; tool = "Bash"; cmd = "curl -s https://example.org/a/b/c" }
    @{ n = "62 git log HEAD-Tilde";                erw = "PASS"; tool = "Bash"; cmd = "git log HEAD~3 --oneline 2>/dev/null" }
)
if ($isWindowsHost) {
    $faelle += @(
        @{ n = "56 Git-Bash /tmp/claude";          erw = "PASS"; tool = "Bash"; cmd = "cat /tmp/claude/projekt/x.txt" }
        @{ n = "57 Git-Bash /tmp fremd";           erw = "DENY"; tool = "Bash"; cmd = "cat /tmp/fremd/x.txt" }
        @{ n = "59 UNC-Pfad";                      erw = "DENY"; tool = "Bash"; cmd = "type \\server\freigabe\x.txt" }
        @{ n = "60 Git-Bash /c/ ausserhalb";       erw = "DENY"; tool = "Bash"; cmd = "cat /c/Users/jemand/notiz.md" }
        # Seit 5.0: Programme mit vollem Pfad aufrufen verlangt keine Freigabe.
        @{ n = "64 Programm unter Programme";      erw = "PASS"; tool = "PowerShell"; cmd = "& `"$env:ProgramFiles\Beispiel\werkzeug.exe`" --version" }
        @{ n = "65 Programm-Datei anderswo";       erw = "PASS"; tool = "Bash"; cmd = "/c/Werkzeuge/Python/python.exe -c `"print(1)`"" }
        @{ n = "66 Windows-Ordner lesen";          erw = "PASS"; tool = "Read"; file = "$env:SystemRoot\System32\drivers\etc\hosts" }
        @{ n = "67 Programm liest Datei aussen";   erw = "DENY"; tool = "Bash"; cmd = "/c/Werkzeuge/Python/python.exe '$desktop\skript.py'" }
    )
}

function Ruf($skript, $fall, $exe) {
    $ti = switch ($fall.tool) {
        "Read"       { @{ file_path = $fall.file } }
        "Write"      { @{ file_path = $fall.file; content = "x" } }
        "Grep"       { @{ pattern = "x"; path = $fall.path } }
        "Glob"       { @{ pattern = $fall.pattern } }
        default      { @{ command = $fall.cmd } }
    }
    $cwd = if ($fall.ContainsKey('cwd')) { $fall.cwd } else { $repo }
    $json = @{ session_id = "test"; hook_event_name = "PreToolUse"; cwd = $cwd; tool_name = $fall.tool; tool_input = $ti } | ConvertTo-Json -Depth 5 -Compress
    # Die Eingabe geht als UTF-8-Bytes an den Hook, so wie Claude Code sie schickt. Ein Pipe
    # aus PowerShell kodiert je nach Version anders und verdeckt Fehler beim Lesen (Meldung #10).
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
"Interpreter:   $psExe"
"Freigabe:      $frei"
""
$fehler = 0
"{0,-42} {1,-6} {2,-8} {3}" -f "Fall", "Erw.", "Ist", "Urteil"
"-" * 70
foreach ($f in $faelle) {
    $ist = Ruf $Skript $f $psExe
    $ok = if ($ist -eq $f.erw) { "ok" } else { "ABWEICHUNG" }
    if ($ist -ne $f.erw) { $fehler++ }
    "{0,-42} {1,-6} {2,-8} {3}" -f $f.n, $f.erw, $ist, $ok
}
Remove-Item -LiteralPath $freiKonfig, $sperrKonfig -ErrorAction SilentlyContinue
""
if ($fehler -eq 0) { "ALLE $($faelle.Count) FAELLE BESTANDEN"; exit 0 }
else { "$fehler VON $($faelle.Count) FAELLEN ABWEICHEND"; exit 1 }
