# freigeben-tests.ps1
# Zweck: Regressionstest fuer den Freigabebefehl freigeben.ps1 und die Listenlogik in
# lib\arbeitsbereich.ps1 (Standardsperre, seit 5.0).
#
# PFLICHT: Wer freigeben.ps1 oder die Listenlogik aendert, faehrt diese Reihe vorher und nachher,
# unter beiden Interpretern (die Datei selbst einmal mit pwsh, einmal mit powershell starten).
#
# AUFRUF (schreibt nur Testlisten im Temp-Ordner, nie die echten Listen in 00_INDEX):
#   pwsh -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\freigeben-tests.ps1"
#   powershell -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\freigeben-tests.ps1" -Exe powershell
#
# Was NICHT geprueft werden kann: der Ja-Weg von freigeben.ps1, weil er eine echte Tastatur
# verlangt. Geprueft wird stattdessen, dass der Befehl aus einer umgeleiteten Eingabe (so laufen
# die Shell-Werkzeuge eines Agenten) nichts aendert, und die Listenlogik, die er danach aufruft.
# Bewusst ASCII-only: Umlaute kommen aus [char]-Codes.
param([string]$Exe = "")

$isWindowsHost = [System.IO.Path]::DirectorySeparatorChar -eq '\'
. (Join-Path (Join-Path $PSScriptRoot 'lib') 'arbeitsbereich.ps1')
$repo = [System.IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$psExe = (Get-Command $(if ($isWindowsHost) { 'pwsh.exe' } else { 'pwsh' }) -ErrorAction SilentlyContinue).Source
if (-not $psExe -and $isWindowsHost) { $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source }
if ($Exe) { $psExe = (Get-Command $Exe -ErrorAction SilentlyContinue).Source }
if (-not $psExe) { "Kein passender PowerShell-Interpreter gefunden."; exit 1 }

$utf8 = New-Object System.Text.UTF8Encoding($false)
$id = [System.Guid]::NewGuid().ToString('N')
$liste = Join-Path $tempPath ("freigeben-tests-$id.txt")
$sperre = Join-Path $tempPath ("freigeben-tests-sperre-$id.txt")
$frei = Join-Path (Join-Path $homePath ("Projekte " + [char]0x00C4)) 'Verein Neu'
$fehler = 0
$anzahl = 0
function Pruef([string]$name, $ist, $soll) {
    $script:anzahl++
    $ok = ([string]$ist -eq [string]$soll)
    if (-not $ok) { $script:fehler++ }
    "{0,-48} {1,-16} {2,-16} {3}" -f $name, $soll, $ist, $(if ($ok) { "ok" } else { "ABWEICHUNG" })
}

function Ruf-Hook([string]$skript, $eingabe) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$skript`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $utf8
    $psi.EnvironmentVariables['LEO_GUARD_FREIGABE_KONFIG'] = $liste
    $psi.EnvironmentVariables['LEO_GUARD_READ_KONFIG'] = $sperre
    $psi.EnvironmentVariables['LEO_GUARD_DEBUG'] = '1'
    $p = [System.Diagnostics.Process]::Start($psi)
    $bytes = $utf8.GetBytes(($eingabe | ConvertTo-Json -Depth 5 -Compress))
    $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($out -match '"permissionDecision"\s*:\s*"deny"') { return "DENY" }
    if ([string]::IsNullOrWhiteSpace($out)) { return "PASS" }
    return "FEHLER: " + ($out.Trim() -replace "`r?`n", " ")
}
$leseHook = Join-Path $PSScriptRoot 'guard-read.ps1'
$leseEingabe = @{ tool_name = 'Read'; cwd = $repo; tool_input = @{ file_path = (Join-Path $frei 'a.md') } }

"Interpreter:   $psExe"
"Testliste:     $liste"
""
"{0,-48} {1,-16} {2,-16} {3}" -f "Fall", "Soll", "Ist", "Urteil"
"-" * 90

# Listenlogik
Pruef "1 Hook vor der Freigabe"                (Ruf-Hook $leseHook $leseEingabe) "DENY"
Pruef "2 Eintragen legt Datei mit Kopf an"     (Set-PfadInListe $liste $frei -kopf @('# Kopf') -stufe 'lesen') "hinzugefuegt"
Pruef "3 Kopfzeile steht in der Datei"         (@(Get-Content -LiteralPath $liste -Encoding UTF8)[0]) "# Kopf"
Pruef "4 Umlaut und Leerzeichen zurueckgelesen" (@(Read-PfadListe $liste)[0]) (Normalize-AbsolutePath $frei)
Pruef "4a Zeile traegt die Stufe"              (@(Get-Content -LiteralPath $liste -Encoding UTF8)[-1]) ("lesen: " + (Normalize-AbsolutePath $frei))
Pruef "4b Lesen oeffnet das Schreiben nicht"   (@(Read-PfadListe $liste -NurSchreiben).Count) "0"
Pruef "5 Hook nach der Freigabe"               (Ruf-Hook $leseHook $leseEingabe) "PASS"
Pruef "6 Doppelt eintragen"                    (Set-PfadInListe $liste $frei -stufe 'lesen') "schon-da"
$tildeForm = '~' + [System.IO.Path]::DirectorySeparatorChar + $frei.Substring($homePath.Length).TrimStart('\', '/')
Pruef "7 Tilde-Form gilt als derselbe Pfad"    (Set-PfadInListe $liste $tildeForm -stufe 'lesen') "schon-da"
Pruef "7a Stufe wechseln"                      (Set-PfadInListe $liste $frei -stufe 'lesen-und-schreiben') "geaendert"
Pruef "7b Danach genau eine Zeile dafuer"      (@(Read-PfadListe $liste).Count) "1"
Pruef "7c Jetzt auch Schreiben offen"          (@(Read-PfadListe $liste -NurSchreiben).Count) "1"
Pruef "7d Zeile ohne Stufe gilt als lesen"     ((Split-ListenZeile $frei).stufe) "lesen"
Pruef "8 Entfernen"                            (Set-PfadInListe $liste $frei -Entfernen) "entfernt"
Pruef "9 Entfernen, nicht vorhanden"           (Set-PfadInListe $liste $frei -Entfernen) "nicht-gefunden"
Pruef "10 Hook nach dem Entziehen"             (Ruf-Hook $leseHook $leseEingabe) "DENY"
Pruef "11 Kopf bleibt nach dem Entfernen"      (@(Get-Content -LiteralPath $liste -Encoding UTF8)[0]) "# Kopf"
$fehlerText = ''
try { Set-PfadInListe $liste 'relativer\pfad' | Out-Null } catch { $fehlerText = 'abgelehnt' }
Pruef "12 Relativer Pfad wird abgelehnt"       $fehlerText "abgelehnt"

# Breite Freigaben
$wurzel = if ($isWindowsHost) { 'C:\' } else { '/' }
Pruef "13 Laufwerkswurzel ist zu weit"         (Test-ZuWeit $wurzel) "True"
Pruef "14 Benutzerordner ist zu weit"          (Test-ZuWeit $homePath) "True"
Pruef "15 Ordner aller Benutzer ist zu weit"   (Test-ZuWeit (Split-Path -Parent $homePath)) "True"
Pruef "16 Projektordner ist nicht zu weit"     (Test-ZuWeit $frei) "False"
Pruef "17 Vorschlag fuer Datei ist ihr Ordner" (Get-FreigabeZiel (Join-Path $frei 'x.pdf')) (Normalize-AbsolutePath $frei)
Pruef "18 Vorschlag nie der Benutzerordner"    (Get-FreigabeZiel (Join-Path $homePath 'x.pdf')) (Normalize-AbsolutePath (Join-Path $homePath 'x.pdf'))

# freigeben.ps1 aus einer umgeleiteten Eingabe (der Weg eines Agenten): aendert nichts.
$vorher = [System.IO.File]::ReadAllText($liste)
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $psExe
$psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'freigeben.ps1')`" `"$frei`""
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = $utf8
$psi.EnvironmentVariables['LEO_GUARD_FREIGABE_KONFIG'] = $liste
$psi.EnvironmentVariables['LEO_GUARD_READ_KONFIG'] = $sperre
$p = [System.Diagnostics.Process]::Start($psi)
$p.StandardInput.WriteLine('j')
$p.StandardInput.Close()
$ausgabe = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
$p.WaitForExit()
Pruef "19 freigeben.ps1 mit Eingabe 'j' umgeleitet" $p.ExitCode "2"
Pruef "20 Liste dabei unveraendert"            ([System.IO.File]::ReadAllText($liste) -eq $vorher) "True"
Pruef "21 Meldung nennt das eigene Fenster"    ($ausgabe -match 'eigenen PowerShell-Fenster') "True"

# Ohne Pfad zeigt der Befehl nur den Stand und aendert nichts.
$psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'freigeben.ps1')`""
$p = [System.Diagnostics.Process]::Start($psi)
$p.StandardInput.Close()
$ausgabe = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
$p.WaitForExit()
Pruef "22 Uebersicht ohne Pfad"                $p.ExitCode "0"
Pruef "23 Uebersicht nennt die Standardsperre" ($ausgabe -match 'Standardsperre') "True"

Remove-Item -LiteralPath $liste, $sperre -ErrorAction SilentlyContinue
""
if ($fehler -eq 0) { "ALLE $anzahl FAELLE BESTANDEN"; exit 0 }
else { "$fehler VON $anzahl FAELLEN ABWEICHEND"; exit 1 }
