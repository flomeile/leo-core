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
param(
    [string]$Skript = (Join-Path $PSScriptRoot 'guard-workspace.ps1')
)

$repo      = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
$artifacts = (Join-Path (Split-Path -Parent $repo) ((Split-Path -Leaf $repo) + " Artifacts")).TrimEnd('\')
$archiv    = (Join-Path (Split-Path -Parent $repo) ((Split-Path -Leaf $repo) + " Archiv")).TrimEnd('\')
$up        = $env:USERPROFILE

# PowerShell 7 bevorzugt, Windows PowerShell als Rueckfall: Ein System ohne pwsh
# soll die Reihe trotzdem fahren koennen.
$psExe = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
if (-not $psExe) { $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source }
if (-not $psExe) { "Weder pwsh.exe noch powershell.exe gefunden."; exit 1 }

$faelle = @(
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
)

function Ruf($skript, $fall, $exe, $cwd) {
    $ti = if ($fall.tool -in @("Write","Edit")) { @{ file_path = $fall.file } } else { @{ command = $fall.cmd } }
    $json = @{ session_id = "test"; hook_event_name = "PreToolUse"; cwd = $cwd; tool_name = $fall.tool; tool_input = $ti } | ConvertTo-Json -Depth 5 -Compress
    $out = $json | & $exe -NoProfile -ExecutionPolicy Bypass -File $skript 2>&1 | Out-String
    if ($out -match '"permissionDecision"\s*:\s*"deny"') { return "DENY" }
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
    $ist = Ruf $Skript $f $psExe $repo
    $ok = if ($ist -eq $f.erw) { "ok" } else { "ABWEICHUNG" }
    if ($ist -ne $f.erw) { $fehler++ }
    "{0,-30} {1,-6} {2,-8} {3}" -f $f.n, $f.erw, $ist, $ok
}
""
if ($fehler -eq 0) { "ALLE $($faelle.Count) FAELLE BESTANDEN"; exit 0 }
else { "$fehler VON $($faelle.Count) FAELLEN ABWEICHEND"; exit 1 }
