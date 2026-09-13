# guard-git-tests.ps1
# Zweck: Regressionstest fuer die Sperre gegen pauschales Stagen "guard-git.ps1".
#
# PFLICHT: Wer den Hook aendert, faehrt diese Reihe vorher und nachher. Eine Sperre
# ohne Testfall zaehlt nicht (AGENTS.md, Abschnitt 18).
#
# AUFRUF (es wird nichts geschrieben, nur geurteilt):
#   pwsh -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\guard-git-tests.ps1"
# Optional gegen eine Arbeitskopie: ... -Skript "<Repo>\00_INDEX\scripts\guard-git-neu.ps1"
#
# Bewusst ASCII-only: laeuft unter Windows PowerShell 5.1 genauso wie unter PowerShell 7.
param(
    [string]$Skript = (Join-Path $PSScriptRoot 'guard-git.ps1')
)

$isWindowsHost = [System.IO.Path]::DirectorySeparatorChar -eq '\'
$repo = [System.IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))

$psExe = (Get-Command $(if ($isWindowsHost) { 'pwsh.exe' } else { 'pwsh' }) -ErrorAction SilentlyContinue).Source
if (-not $psExe -and $isWindowsHost) { $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source }
if (-not $psExe) { "Kein passender PowerShell-Interpreter gefunden."; exit 1 }

$faelle = @(
    @{ n = "1 git add -A";                  erw = "DENY"; tool = "Bash"; cmd = "git add -A" }
    @{ n = "2 git add --all";               erw = "DENY"; tool = "Bash"; cmd = "git add --all && git commit -m x" }
    @{ n = "3 git add .";                   erw = "DENY"; tool = "Bash"; cmd = "git add ." }
    @{ n = "4 git -C repo add -A";          erw = "DENY"; tool = "Bash"; cmd = "git -C '$repo' add -A" }
    @{ n = "5 in pwsh -c";                  erw = "DENY"; tool = "Bash"; cmd = "pwsh -NoProfile -c `"git add -A`"" }
    @{ n = "6 nach Trenner";                erw = "DENY"; tool = "PowerShell"; cmd = "Set-Location x; git add ." }
    @{ n = "7 einzelne Datei";              erw = "PASS"; tool = "Bash"; cmd = "git add 90_Inbox/x.md 10_System/y.md" }
    @{ n = "8 Punkt-Schraegstrich";         erw = "PASS"; tool = "Bash"; cmd = "git add ./90_Inbox/x.md" }
    @{ n = "9 Erwaehnung in Commit-Text";   erw = "PASS"; tool = "Bash"; cmd = "git commit -m `"Regel: kein git add -A mehr`"" }
    @{ n = "10 git add mit -- und Datei";   erw = "PASS"; tool = "Bash"; cmd = "git add -- x.md" }
    @{ n = "11 anderes Werkzeug";           erw = "PASS"; tool = "Write"; file = "$repo\90_Inbox\x.md" }
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
