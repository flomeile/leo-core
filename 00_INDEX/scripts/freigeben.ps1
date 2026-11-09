# freigeben.ps1
# Zweck: Der Befehl, mit dem [NAME] selbst festlegt, was sein Agent ausserhalb des eigenen
# Arbeitsbereichs lesen oder schreiben darf (Standardsperre, AGENTS.md Abschnitt 18, seit 5.0).
#
# NUR DER BESITZER FUEHRT IHN AUS, in seinem eigenen PowerShell-Fenster. Der Agent kann es nicht:
# guard-workspace.ps1 blockiert jeden Aufruf aus einer Session, und dieses Skript verlangt eine
# Antwort an der Tastatur und bricht ab, wenn seine Eingabe umgeleitet ist (so laufen die
# Shell-Werkzeuge eines Agenten). Gibt dein Agent dir diesen Befehl, liest du ihn, entscheidest
# und fuehrst ihn selbst aus.
#
# BEI JEDER FREIGABE WAEHLST DU DIE STUFE SELBST: nur Lesen, oder Lesen und Schreiben. Es gibt
# dafuer bewusst keinen Schalter, damit die Entscheidung nie in einem vorgefertigten Befehl steckt.
#
# AUFRUF (Pfade mit Leerzeichen in Anfuehrungszeichen):
#   powershell -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\freigeben.ps1"
#       zeigt, was gerade frei und gesperrt ist
#   ... freigeben.ps1 "C:\Pfad\zum\Ordner"                   Ordner freigeben, fragt nach der Stufe
#   ... freigeben.ps1 "C:\Pfad\zum\Ordner" -Entziehen        Freigabe zuruecknehmen
#   ... freigeben.ps1 "C:\Pfad\in\der\Freigabe" -Sperren     Unterordner wieder sperren
#   ... freigeben.ps1 "C:\Pfad\in\der\Freigabe" -Entsperren  diese Sperre aufheben
#
# Was es tut: eine Zeile in 00_INDEX\freigegebene-pfade.txt (oder gesperrte-pfade.txt) eintragen,
# aendern oder entfernen und die Aenderung mit Git committen, damit jede Freigabe im Verlauf
# steht. Es wirkt ab dem naechsten Werkzeugaufruf des Agenten, ohne Neustart. Zugangsdaten (.env,
# Schluessel, .ssh, .aws, Token-Dateien) bleiben immer gesperrt; dafuer gibt es keinen Befehl.
# ASCII-only: laeuft unter Windows PowerShell 5.1 und PowerShell 7.
param(
    [Parameter(Position = 0)][string]$Pfad,
    [switch]$Entziehen,
    [switch]$Sperren,
    [switch]$Entsperren
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path $PSScriptRoot 'lib') 'arbeitsbereich.ps1')
$repoRoh = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ab = Get-Arbeitsbereich $repoRoh

$kopfFreigabe = @(
    '# freigegebene-pfade.txt'
    '# Ordner ausserhalb des Repos, die du deinem Agenten geoeffnet hast. Ab Werk steht hier'
    '# nichts: Dein Agent arbeitet nur im eigenen Repo, in "<Repo> Archiv", "<Repo> Artifacts"'
    '# und im Scratchpad (AGENTS.md, Abschnitt 18).'
    '#'
    '# Jede Zeile traegt vorn die Stufe, die du gewaehlt hast:'
    '#   lesen: <Pfad>                 dein Agent darf dort nur lesen'
    '#   lesen-und-schreiben: <Pfad>   dein Agent darf dort auch aendern, anlegen und loeschen'
    '# Ein Eintrag gilt fuer den Pfad und alles darunter.'
    '#'
    '# Diese Datei pflegst nur du, mit 00_INDEX\scripts\freigeben.ps1 in deinem eigenen'
    '# PowerShell-Fenster (Aufruf ohne Pfad zeigt den Stand und die Befehle). Dein Agent kann sie'
    '# lesen, aber weder schreiben noch den Befehl ausfuehren; beides blockieren die Hooks.'
    '# Einen Unterordner sperrst du mit freigeben.ps1 "<Pfad>" -Sperren wieder.'
    '# Zugangsdaten (.env, Schluessel, .ssh, .aws, Token-Dateien) bleiben immer gesperrt.'
    '#'
    '# Diese Datei gehoert dir (Kern-Dateien.md, Kategorie B): Ein Update ersetzt sie nie.'
)
$kopfSperre = @(
    '# gesperrte-pfade.txt'
    '# Ordner, die dein Agent nie lesen oder schreiben darf, auch wenn ein Ordner darueber in'
    '# freigegebene-pfade.txt freigegeben ist. Pflege nur mit freigeben.ps1 "<Pfad>" -Sperren.'
)

function Zeige-Stand {
    ""
    "Standardsperre von '" + $ab.name + "' (AGENTS.md Abschnitt 18)"
    ""
    "Immer frei (Lesen und Schreiben):"
    "  " + $ab.repo
    "  " + $ab.archiv
    "  " + $ab.artifacts
    foreach ($s in @($ab.scratch | Select-Object -Unique)) { "  " + $s + "   (Scratchpad)" }
    ""
    "Von dir freigegeben (" + $ab.freigabeDatei + "):"
    $zeilen = @()
    if (Test-Path -LiteralPath $ab.freigabeDatei) {
        foreach ($l in Get-Content -LiteralPath $ab.freigabeDatei -Encoding UTF8) {
            $z = Split-ListenZeile $l
            if ($z) { $zeilen += ("  " + $z.pfad + "   (" + $(if ($z.stufe -eq 'lesen') { 'nur lesen' } else { 'lesen und schreiben' }) + ")") }
        }
    }
    if ($zeilen.Count -eq 0) { "  (nichts)" } else { $zeilen }
    ""
    "Darin wieder gesperrt (" + $ab.sperrDatei + "):"
    if ($ab.sperren.Count -eq 0) { "  (nichts)" } else { foreach ($s in $ab.sperren) { "  " + $s } }
    ""
    "Alles andere auf diesem Rechner ist fuer den Agenten zu. Zugangsdaten bleiben immer zu."
    ""
    "Befehle (in deinem eigenen PowerShell-Fenster):"
    "  Freigeben:            " + (Get-FreigabeBefehl 'C:\Pfad\zum\Ordner' $ab) + "   (fragt nach der Stufe)"
    "  Zuruecknehmen:        dasselbe mit -Entziehen"
    "  Unterordner sperren:  dasselbe mit -Sperren, aufheben mit -Entsperren"
    ""
}

if (-not $Pfad) { Zeige-Stand; exit 0 }

if (([int]$Entziehen.IsPresent + [int]$Sperren.IsPresent + [int]$Entsperren.IsPresent) -gt 1) {
    "Bitte nur einen der Schalter -Entziehen, -Sperren oder -Entsperren angeben."
    exit 1
}

# Nur im eigenen Terminal: Die Shell-Werkzeuge eines Agenten leiten die Eingabe um.
if ([Console]::IsInputRedirected) {
    "freigeben.ps1 laeuft nur in deinem eigenen PowerShell-Fenster, weil es eine Antwort an der Tastatur verlangt. Aus einer Agenten-Session heraus ist es gesperrt (AGENTS.md Abschnitt 18). Nichts geaendert."
    exit 2
}

# Pfad bestimmen: ~ und Variablen aufloesen, relative Angaben gegen das aktuelle Verzeichnis.
$roh = $Pfad.Trim().Trim('"').Trim("'")
$roh = Expand-BekannteVariablen $roh
$ziel = Normalize-AbsolutePath $roh
if (-not $ziel) { $ziel = Normalize-AbsolutePath (Join-Path (Get-Location).Path $roh) }
if (-not $ziel) { "Kein gueltiger Pfad: $Pfad"; exit 1 }

$istSperre = $Sperren.IsPresent -or $Entsperren.IsPresent
$entfernen = $Entziehen.IsPresent -or $Entsperren.IsPresent
$datei = if ($istSperre) { $ab.sperrDatei } else { $ab.freigabeDatei }
$kopf = if ($istSperre) { $kopfSperre } else { $kopfFreigabe }
$stufe = ''

if (-not $istSperre -and -not $entfernen -and (Test-UnterWurzel $ziel (Get-EingebauteZonen $ab))) {
    "$ziel liegt schon im Arbeitsbereich und ist ohne Freigabe frei. Nichts geaendert."
    exit 0
}

""
if ($entfernen -or $istSperre) {
    if ($entfernen -and $istSperre) { "Sperre aufheben: $ziel"; "Danach gilt dort wieder, was die Freigabe darueber erlaubt." }
    elseif ($entfernen)             { "Freigabe zuruecknehmen: $ziel"; "Dein Agent kann dort danach weder lesen noch schreiben." }
    else                            { "Sperren: $ziel"; "Dein Agent kann dort danach weder lesen noch schreiben, auch wenn ein Ordner darueber freigegeben ist." }
    ""
    $antwort = Read-Host "Fortfahren? (j/n)"
    if ($antwort -notmatch '^\s*(j|ja|y|yes)\s*$') { "Abgebrochen, nichts geaendert."; exit 1 }
} else {
    "Freigeben: $ziel  (samt allen Unterordnern)"
    if (Test-ZuWeit $ziel) {
        ""
        "ACHTUNG: Das ist sehr weit. Eine Laufwerkswurzel oder dein ganzer Benutzerordner hebt die"
        "Standardsperre praktisch auf. Gib besser nur den Ordner frei, den du wirklich brauchst."
    }
    if (-not (Test-Path -LiteralPath $ziel)) { ""; "Hinweis: Diesen Pfad gibt es (noch) nicht." }
    ""
    "Was soll dein Agent dort duerfen?"
    "  l = nur lesen. Risiko: Was er liest, geht an den Anbieter des Sprachmodells."
    "  s = lesen und schreiben. Risiko dazu: Er kann dort Dateien aendern, anlegen und loeschen,"
    "      und ausserhalb des Repos holt Git nichts davon zurueck."
    "  n = abbrechen"
    ""
    $antwort = Read-Host "Deine Wahl (l/s/n)"
    if ($antwort -match '^\s*l\s*$') { $stufe = 'lesen' }
    elseif ($antwort -match '^\s*s\s*$') { $stufe = 'lesen-und-schreiben' }
    else { "Abgebrochen, nichts geaendert."; exit 1 }
}

$ergebnis = Set-PfadInListe $datei $ziel -Entfernen:$entfernen -kopf $kopf -stufe $stufe
switch ($ergebnis) {
    'hinzugefuegt'   { "Eingetragen in $datei." }
    'geaendert'      { "Stufe geaendert in $datei." }
    'schon-da'       { "Stand schon so in $datei. Nichts geaendert."; exit 0 }
    'entfernt'       { "Entfernt aus $datei." }
    'nicht-gefunden' { "Stand nicht in $datei. Nichts geaendert."; exit 0 }
}

# Committen, damit jede Freigabe im Verlauf steht. Nur fuer die echten Listen im Repo.
$listeImRepo = Test-PathWithin $datei $ab.repo
if ($listeImRepo -and (Test-Path -LiteralPath (Join-Path $ab.repo '.git'))) {
    $rel = (Normalize-AbsolutePath $datei).Substring($ab.repo.Length).TrimStart($pathSeparators) -replace '\\', '/'
    $ErrorActionPreference = 'Continue'
    & git -C $ab.repo add -- $rel 2>&1 | Out-Null
    & git -C $ab.repo commit -q -m "Freigaben geaendert mit freigeben.ps1" -- $rel 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { "Mit Git committet." }
    else { "Nicht committet (Git meldet einen Fehler); die Aenderung wirkt trotzdem. Dein Agent nimmt sie beim naechsten Commit mit." }
    $ErrorActionPreference = 'Stop'
}
"Wirkt ab dem naechsten Werkzeugaufruf deines Agenten, ohne Neustart."
$ab = Get-Arbeitsbereich $repoRoh
Zeige-Stand
exit 0
