# guard-read-tests.ps1
# Zweck: Regressionstest fuer die Lese-Sperre "guard-read.ps1".
#
# PFLICHT: Wer den Hook aendert, faehrt diese Reihe vorher und nachher. Eine Sperre
# ohne Testfall zaehlt nicht (AGENTS.md, Abschnitt 18).
#
# AUFRUF (es wird nichts gelesen und nichts geschrieben, nur geurteilt):
#   pwsh -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\guard-read-tests.ps1"
# Optional gegen eine Arbeitskopie: ... -Skript "<Repo>\00_INDEX\scripts\guard-read-neu.ps1"
#
# Die Reihe legt eine eigene Liste gesperrter Pfade im Temp-Ordner an und reicht sie dem
# Hook ueber LEO_GUARD_READ_KONFIG; die echte 00_INDEX\gesperrte-pfade.txt bleibt unberuehrt.
# Bewusst ASCII-only: laeuft unter Windows PowerShell 5.1 genauso wie unter PowerShell 7.
param(
    [string]$Skript = (Join-Path $PSScriptRoot 'guard-read.ps1')
)

$isWindowsHost = [System.IO.Path]::DirectorySeparatorChar -eq '\'
$repo = [System.IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$profil = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }

$psExe = (Get-Command $(if ($isWindowsHost) { 'pwsh.exe' } else { 'pwsh' }) -ErrorAction SilentlyContinue).Source
if (-not $psExe -and $isWindowsHost) { $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source }
if (-not $psExe) { "Kein passender PowerShell-Interpreter gefunden."; exit 1 }

# Testliste gesperrter Pfade, nur fuer diese Reihe.
$gesperrt = if ($isWindowsHost) { 'C:\Kundenkonfigurationen' } else { '/srv/kundenkonfigurationen' }
$gesperrtSlash = $gesperrt -replace '\\', '/'
$gesperrtGitBash = if ($isWindowsHost) { '/c/Kundenkonfigurationen' } else { $gesperrt }
$konfig = Join-Path ([System.IO.Path]::GetTempPath()) ('guard-read-tests-' + [System.Guid]::NewGuid().ToString('N') + '.txt')
@("# Testliste der Regressionsreihe", "", $gesperrt, "~/gesperrt-privat", "keine") | Set-Content -LiteralPath $konfig -Encoding UTF8
$env:LEO_GUARD_READ_KONFIG = $konfig

$faelle = @(
    @{ n = "1 Read .env";                          erw = "DENY"; tool = "Read"; file = "$repo\.env" }
    @{ n = "2 Read .env.production";               erw = "DENY"; tool = "Read"; file = "$repo\config\.env.production" }
    @{ n = "3 Read SSH-Schluessel";                erw = "DENY"; tool = "Read"; file = "$profil\.ssh\id_ed25519" }
    @{ n = "4 Read AWS-Credentials";               erw = "DENY"; tool = "Read"; file = "$profil\.aws\credentials" }
    @{ n = "5 Read .pem";                          erw = "DENY"; tool = "Read"; file = "$profil\Downloads\server.pem" }
    @{ n = "6 Read Token-Datei";                   erw = "DENY"; tool = "Read"; file = "$profil\.mein-dienst-token.txt" }
    @{ n = "7 Read gesperrter Ordner";             erw = "DENY"; tool = "Read"; file = "$gesperrt\kunde-a\driver.xml" }
    @{ n = "8 Read gesperrt, Slash-Form";          erw = "DENY"; tool = "Read"; file = "$gesperrtSlash/kunde-a/driver.xml" }
    @{ n = "9 Grep im gesperrten Ordner";          erw = "DENY"; tool = "Grep"; path = "$gesperrt" }
    @{ n = "10 Bash cat .env";                     erw = "DENY"; tool = "Bash"; cmd = "cat .env" }
    @{ n = "11 Bash type Schluesseldatei";         erw = "DENY"; tool = "Bash"; cmd = "type `"$profil\keys\server.key`"" }
    @{ n = "12 Bash gesperrt in Git-Bash-Form";    erw = "DENY"; tool = "Bash"; cmd = "head -50 $gesperrtGitBash/kunde-a/policy.xml" }
    @{ n = "13 PowerShell Get-Content .ssh";       erw = "DENY"; tool = "PowerShell"; cmd = "Get-Content ~/.ssh/config" }
    @{ n = "14 Bash secrets.json";                 erw = "DENY"; tool = "Bash"; cmd = "python -c `"print(open('secrets.json').read())`"" }
    @{ n = "15 Read gesperrt mit Tilde";           erw = "DENY"; tool = "Read"; file = "$profil\gesperrt-privat\notiz.md" }
    @{ n = "16 Read Repo-Datei";                   erw = "PASS"; tool = "Read"; file = "$repo\AGENTS.md" }
    @{ n = "17 Read fremde Datei ausserhalb";      erw = "PASS"; tool = "Read"; file = "$profil\Desktop\bericht.md" }
    @{ n = "18 Bash python-dotenv";                erw = "PASS"; tool = "Bash"; cmd = "pip install python-dotenv" }
    @{ n = "19 Bash .environment";                 erw = "PASS"; tool = "Bash"; cmd = "cat .environment" }
    @{ n = "20 Bash tokenizer.json";               erw = "PASS"; tool = "Bash"; cmd = "cat models/tokenizer.json" }
    @{ n = "21 PowerShell env-Variable";           erw = "PASS"; tool = "PowerShell"; cmd = "`$env:PATH -split ';'" }
    @{ n = "22 Bash Wort monkey";                  erw = "PASS"; tool = "Bash"; cmd = "grep -n monkey 10_System/Technik.md" }
    @{ n = "23 Bash Skript liest Token selbst";    erw = "PASS"; tool = "Bash"; cmd = "pwsh -File 00_INDEX/scripts/health-check.ps1" }
    @{ n = "24 Grep im Repo";                      erw = "PASS"; tool = "Grep"; path = "$repo\10_System" }
    @{ n = "25 Write bleibt Sache des anderen Hooks"; erw = "PASS"; tool = "Write"; file = "$profil\.env" }
    @{ n = "26 Marker keine ist kein Pfad";         erw = "PASS"; tool = "Bash"; cmd = "echo keine Aenderung" }
)

function Ruf($skript, $fall, $exe) {
    $ti = switch ($fall.tool) {
        "Read"       { @{ file_path = $fall.file } }
        "Write"      { @{ file_path = $fall.file; content = "x" } }
        "Grep"       { @{ pattern = "x"; path = $fall.path } }
        "Glob"       { @{ pattern = "*"; path = $fall.path } }
        default      { @{ command = $fall.cmd } }
    }
    $json = @{ session_id = "test"; hook_event_name = "PreToolUse"; cwd = $repo; tool_name = $fall.tool; tool_input = $ti } | ConvertTo-Json -Depth 5 -Compress
    $out = $json | & $exe -NoProfile -ExecutionPolicy Bypass -File $skript 2>&1 | Out-String
    if ($out -match '"permissionDecision"\s*:\s*"deny"') { return "DENY" }
    if ([string]::IsNullOrWhiteSpace($out)) { return "PASS" }
    return "FEHLER: " + ($out.Trim() -replace "`r?`n", " ")
}

"Geprueft wird: $Skript"
"Interpreter:   $psExe"
"Testliste:     $konfig"
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
Remove-Item -LiteralPath $konfig -ErrorAction SilentlyContinue
Remove-Item Env:LEO_GUARD_READ_KONFIG -ErrorAction SilentlyContinue
""
if ($fehler -eq 0) { "ALLE $($faelle.Count) FAELLE BESTANDEN"; exit 0 }
else { "$fehler VON $($faelle.Count) FAELLEN ABWEICHEND"; exit 1 }
