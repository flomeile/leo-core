# guard-workspace.ps1
# Zweck: PreToolUse-Hook. Die Schreib-Haelfte der Standardsperre (AGENTS.md Abschnitt 18):
# blockiert jeden SCHREIBENDEN Zugriff ausserhalb des Arbeitsbereichs, dazu jeden Versuch des
# Agenten, die Freigaben selbst zu aendern.
#
# WARUM ES DAS GIBT:
# Der Agent arbeitet an einem Second Brain, nicht am Dateisystem. Alles, was er
# veraendert, gehoert ins Repo, weil dort Git jede Aenderung rueckrollbar macht.
# Ausserhalb gibt es dieses Netz nicht: eine falsch geratene Pfadangabe, ein
# uebereifriges "ich raeume das gleich mit auf", ein Tippfehler im Zielpfad, und
# es trifft Dateien, die niemand versioniert hat. Eine Textregel allein reicht
# dafuer nicht, die kann ein LLM uebersehen. Dieser Hook laeuft vor dem
# Werkzeugaufruf und entscheidet ohne das Modell. Die Regel selbst steht in der
# AGENTS.md, Abschnitt 18; dieses Skript ist nur ihre Durchsetzung.
#
# ARBEITSBEREICH (seit 5.0 gemeinsam mit guard-read.ps1, Logik in lib\arbeitsbereich.ps1):
# das Repo, "<Repo> Archiv", "<Repo> Artifacts", das Scratchpad, dazu der Memory-Pfad des
# Werkzeugs (nur zum Loeschen nach der Migration ins Repo) und alles, was der Besitzer in
# 00_INDEX\freigegebene-pfade.txt freigegeben hat, ausser was darin in gesperrte-pfade.txt steht.
# Das LESEN prueft guard-read.ps1.
#
# DIE FREIGABEN GEHOEREN DEM BESITZER (seit 5.0). Der Agent schreibt weder
# freigegebene-pfade.txt noch gesperrte-pfade.txt und fuehrt freigeben.ps1 nie aus; beides
# blockiert dieser Hook. Bis 4.11 stand hier eine Liste $allowPatterns zum Erweitern von Hand;
# die eingebauten Zonen stehen weiter darin, eigene Orte kommen nur noch ueber freigeben.ps1.
#
# GRENZE, DIE MAN KENNEN MUSS: Dieser Hook liegt IM Repo, weil dort das ganze
# System liegt (AGENTS.md Abschnitt 11). Ein Agent mit Schreibrecht auf das Repo
# koennte ihn also selbst entschaerfen. Genau das verbietet AGENTS.md Abschnitt 18
# ausdruecklich. Die Sperre ist gegen das Versehen gebaut, nicht gegen die Absicht.
#
# EINRICHTUNG: Der Hook wirkt nur, wenn er in .claude\settings.json unter
# hooks.PreToolUse eingehaengt ist. Die Datei liegt im Paket bei. Ohne sie ist
# Abschnitt 18 eine reine Textregel. Unter Windows startet die mitgelieferte
# Konfiguration "powershell"; unter macOS/Linux muss sie "pwsh" aufrufen und
# POSIX-Pfade verwenden, siehe ANLEITUNG.md. Fehlt der Interpreter, blockiert der
# Hook nichts.
#
# Eingabe: JSON auf stdin. Ausgabe: JSON auf stdout NUR beim Blockieren.
#
# Bewusst ASCII-only geschrieben und trotzdem mit BOM gespeichert: Dieses Skript
# laeuft bei jedem einzelnen Werkzeugaufruf und muss unter Windows PowerShell 5.1
# genauso starten wie unter PowerShell 7.

# -Repo: gesetzt, wenn der Hook als Schutzkopie ausserhalb des Repos laeuft (Haertung mit
# verwalteten Einstellungen, sperre-haerten.ps1, seit 5.1). Ohne Angabe ist das Repo der Ordner
# zwei Ebenen ueber diesem Skript. Die Listen kommen immer aus dem 00_INDEX neben diesem Skript.
param([string]$Repo = '')

$ErrorActionPreference = "Stop"

# WICHTIG: Im Durchlass-Fall gibt dieser Hook NICHTS aus und beendet sich nur mit
# Exitcode 0. Die Hook-Dokumentation kennt zwar einen Rueckgabewert "defer" fuer
# "keine Entscheidung, normaler Berechtigungsweg", aber Claude Code hat damit
# jeden folgenden Werkzeugaufruf mit einem internen Fehler abgebrochen, statt ihn
# auszufuehren. Die Sitzung war danach arbeitsunfaehig und musste ueber
# "git checkout -- .claude/settings.json" von Hand befreit werden. Ein stiller
# Exitcode 0 ist der dokumentierte konservative Weg und bedeutet dasselbe.
function Write-Decision([string]$decision, [string]$reason) {
    if ($decision -ne "deny") { exit 0 }
    $out = @{
        hookSpecificOutput = @{
            hookEventName            = "PreToolUse"
            permissionDecision       = "deny"
            permissionDecisionReason = $reason
        }
    }
    # Als UTF-8-Bytes schreiben: Die Konsole nimmt sonst die OEM-Codepage, und ein Umlaut im
    # Pfad kommt beim Agenten verstuemmelt an (gemessen im Ende-zu-Ende-Lauf zu 5.0).
    $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes(($out | ConvertTo-Json -Depth 5 -Compress))
    $s = [Console]::OpenStandardOutput(); $s.Write($bytes, 0, $bytes.Length); $s.Flush()
    exit 0
}

# Faellt hier etwas aus, darf der Hook den Betrieb nicht blockieren: Eine Sperre,
# die bei einem eigenen Fehler alles anhaelt, ist gefaehrlicher als die Luecke,
# die sie schliesst.
try {

. (Join-Path (Join-Path $PSScriptRoot 'lib') 'arbeitsbereich.ps1')

# Eingabe ausdruecklich als UTF-8 lesen: [Console]::In nimmt die OEM-Codepage, und aus einem Umlaut im Pfad werden zwei falsche Zeichen (Leo Core, Meldung #10).
$raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding($false)))).ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { Write-Decision "durch" "" }
$in = $raw | ConvertFrom-Json

$ab = Get-Arbeitsbereich $(if ($Repo) { $Repo } else { Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }) (Split-Path -Parent $PSScriptRoot)
$repo = $ab.repo
$memoryProjects = if ($homePath) {
    Normalize-AbsolutePath (Join-Path (Join-Path $homePath '.claude') 'projects')
} else { $null }
$memoryPattern = if ($memoryProjects) { Join-Path (Join-Path $memoryProjects '*') 'memory' } else { $null }
$memorySubtreePattern = if ($memoryPattern) { Join-Path $memoryPattern '*' } else { $null }

# --- Eingebaute Bereiche ------------------------------------------------------
# Das Repo selbst, dazu die eingebauten Zonen der Standardsperre und der Memory-Pfad. Die
# Muster enthalten vor dem Stern immer einen echten Verzeichnistrenner: sonst wuerde ein
# Muster fuer C:\Leo auch C:\Leonardo erlauben. Eigene Orte kommen NICHT hier hinein,
# sondern ueber freigeben.ps1 in freigegebene-pfade.txt.
$allowPatterns = @(
    $repo                                          # das Repo selbst
    (Join-Path $repo '*')                         # alles darin
    $ab.artifacts                                  # erzeugte Artefakte (Abschnitt 5)
    (Join-Path $ab.artifacts '*')
    $ab.archiv                                     # Primaerquellen-Archiv (Abschnitt 5)
    (Join-Path $ab.archiv '*')
    $memoryPattern                                 # nur um Harness-Memory zu LOESCHEN
    $memorySubtreePattern
)
foreach ($s in $ab.scratch) { $allowPatterns += @($s, (Join-Path $s '*')) }   # Scratchpad
# Auf POSIX sind die Geraetedateien keine Schreibziele im Sinn der Sperre: Eine
# Umleitung wie "2>/dev/null" steht in fast jedem Shell-Kommando, und ein Guard, der
# sie blockiert, wird abgeschaltet. Unter Windows tauchen diese Pfade nicht auf.
if (-not $isWindowsHost) {
    $allowPatterns += @('/dev/null', '/dev/stdout', '/dev/stderr', '/dev/tty')
}

function Test-Allowed([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $true }
    $p = Normalize-AbsolutePath $path
    # Relative Pfade werden hier nicht bewertet, dafuer zaehlt das Arbeitsverzeichnis.
    if (-not $p) { return $true }
    foreach ($pat in $allowPatterns) {
        if ($pat -and (($isWindowsHost -and $p -like $pat) -or (-not $isWindowsHost -and $p -clike $pat))) { return $true }
    }
    # Abgeschnittener Pfad aus einem Kommandotext (Repo in einem Pfad mit Leerzeichen),
    # siehe Test-UnterWurzel in lib\arbeitsbereich.ps1.
    if (Test-UnterWurzel $p (Get-EingebauteZonen $ab)) { return $true }
    # Freigaben des Besitzers, ausser was darin wieder gesperrt ist (seit 5.0).
    # Nur Freigaben der Stufe "lesen-und-schreiben" oeffnen das Schreiben.
    if ((Test-Freigegeben $p $ab -Schreiben) -and -not (Get-Sperre $p $ab)) { return $true }
    return $false
}

# --- Die Freigaben gehoeren dem Besitzer (seit 5.0) ---------------------------
# Die beiden Listen schreibt nur freigeben.ps1, und das startet nur der Besitzer in seinem
# eigenen Terminal. Lesen darf der Agent sie, damit er seine Policy erklaeren kann.
$policyDateien = @('freigegebene-pfade.txt', 'gesperrte-pfade.txt')
$policyRx = '(?i)(?:^|[\\/\s"''])(?:freigegebene|gesperrte)-pfade\.txt'
$policyGrund = "Diese Liste gehoert [NAME]: Sie legt fest, was du ausserhalb deines Arbeitsbereichs lesen und schreiben darfst (AGENTS.md Abschnitt 18). Du schreibst sie nie, auch nicht auf seinen Wunsch hin und auch nicht ueber Git. Aendern kann er sie nur selbst, mit freigeben.ps1 in seinem eigenen PowerShell-Fenster. Sag ihm das in einem Satz und gib ihm in einem Codeblock den passenden Befehl: Freigeben " + (Get-FreigabeBefehl '<Pfad>' $ab) + " ; Freigabe zuruecknehmen mit -Entziehen; einen Unterordner wieder sperren mit -Sperren, die Sperre aufheben mit -Entsperren; ohne Pfad zeigt der Befehl den aktuellen Stand."
function Test-PolicyDatei([string]$path) {
    $p = Normalize-AbsolutePath $path
    if (-not $p) { return $false }
    $name = [System.IO.Path]::GetFileName($p)
    foreach ($d in $policyDateien) {
        if ($name.Equals($d, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-PathWithin $p $repo)) { return $true }
    }
    return $false
}

# Ein Aufruf von freigeben.ps1 aus einer Session. Erlaubt bleibt nur, die Datei zu lesen oder
# mit Git zu verwalten (das Update holt sie mit git checkout); jedes Segment, das mit etwas
# anderem beginnt (powershell, pwsh, &, ., dem Pfad selbst, Start-Process), gilt als Aufruf.
# Seit 5.1 gilt dasselbe fuer sperre-haerten.ps1, den Einrichtungsbefehl der verwalteten
# Einstellungen; $skriptRx waehlt, welches der beiden Skripte geprueft wird.
function Test-FreigebenAufruf([string]$cmd, [string]$skriptRx = 'freigeben\.ps1') {
    if ($cmd -notmatch ('(?i)' + $skriptRx)) { return $false }
    $erlaubt = '(?i)^(?:git|cat|type|gc|get-content|head|tail|less|more|select-string|sls|grep|rg|findstr|diff|fc|compare-object|test-path|get-item|get-childitem|gci|ls|dir|wc|get-filehash|sha256sum|md5sum|file|stat|echo|write-output|write-host)(?:\.exe)?(?=\s|$)'
    foreach ($seg in [regex]::Split($cmd, '\r?\n|;|&&|\|\||\|')) {
        $s = $seg.Trim()
        if ($s -notmatch ('(?i)' + $skriptRx)) { continue }
        # sperre-haerten.ps1 -Pruefen zeigt nur den Stand und aendert nichts; das darf der Agent.
        if ($skriptRx -like 'sperre*' -and $s -match '(?i)\s-Pruefen\b' -and $s -notmatch '(?i)\s-(Entfernen|NurListen|Sandbox|Ziel|Erhoeht|Protokoll)\b') { continue }
        if ($s -match $erlaubt) { continue }
        return $true
    }
    return $false
}

# --- Formatdisziplin (AGENTS.md Abschnitt 5, mechanisiert 30.08.2026) --------
# Themenordner tragen kuratiertes Markdown; erzeugte Ausgabeformate (PDF, PNG,
# Office, HTML-Zwischenprodukte) gehoeren in den Artefakte-Ordner neben dem Repo.
# Die Textregel ist im Ursprungssystem zweimal an einer expliziten Ortsangabe
# gescheitert ("speichere es im selben Ordner"); auf eine zweimal wirkungslose
# Textregel folgt ein mechanisches Netz. Zustandsdateien der Skripte sind
# ausgenommen, 90_Inbox bleibt als Transit frei.
$artefaktEndungen = @('.pdf','.png','.jpg','.jpeg','.gif','.svg','.webp','.ico',
                      '.docx','.doc','.xlsx','.xls','.pptx','.ppt','.zip','.7z',
                      '.html','.htm','.mp4','.mp3','.wav')
function Test-ArtefaktVerbot([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    $p = Normalize-AbsolutePath $path
    if (-not $p -or -not (Test-PathWithin $p $repo) -or $p.Equals($repo, $pathComparison)) { return $false }
    $rel = $p.Substring($repo.Length).TrimStart($pathSeparators)
    if ($rel -notmatch '^(2\d|3\d|05)_') { return $false }
    $name = [System.IO.Path]::GetFileName($p)
    if ($name -like '*last-run.txt' -or $name -like 'zustand-*.json') { return $false }
    $ext = [System.IO.Path]::GetExtension($p).ToLower()
    if (-not ($artefaktEndungen -contains $ext)) { return $false }
    # Code-Projekte sind ausgenommen (Befund 31.08.2026, gemeldet von einem Nutzer des
    # Grundgeruests). Die Sperre soll ERZEUGTE Ausgabeformate aus dem Gedaechtnis
    # heraushalten, nicht Quelldateien: In einem Code-Projekt ist eine .html oder .svg
    # kein Artefakt, sondern Quelltext, und sie gehoert zwingend neben den Rest des
    # Projekts. Erkannt wird ein Projekt an einer Markierungsdatei irgendwo zwischen der
    # Datei und dem Themenordner. Bewusst an einer Datei und nicht am Ordnernamen: Einen
    # Namen trifft man versehentlich, eine package.json nicht. Wer ein Projekt ohne solche
    # Datei fuehrt, legt eine leere `.code-projekt` daneben.
    $marker = @('package.json','pyproject.toml','requirements.txt','Cargo.toml','go.mod',
                'tsconfig.json','pom.xml','composer.json','.code-projekt')
    $dir = [System.IO.Path]::GetDirectoryName($p)
    while ($dir -and (Test-PathWithin $dir $repo) -and -not $dir.Equals($repo, $pathComparison)) {
        foreach ($m in $marker) {
            if (Test-Path -LiteralPath (Join-Path $dir $m)) { return $false }
        }
        $dir = [System.IO.Path]::GetDirectoryName($dir)
    }
    return $true
}
$artefaktGrund = "Erzeugte Ausgabeformate gehoeren nicht in Themenordner, sondern in den Artefakte-Ordner neben dem Repo (AGENTS.md, Abschnitt 5). Eine explizite Ortsangabe hebt die Regel nicht still auf: Regel benennen, Artefakte-Pfad vorschlagen; besteht [NAME] auf dem Themenordner, legt er die Datei selbst ab oder entscheidet die Lockerung."

$tool = [string]$in.tool_name
$ti   = $in.tool_input

# --- 1) Dateiwerkzeuge: der Zielpfad steht direkt im Aufruf -------------------
if ($tool -in @("Write", "Edit", "NotebookEdit", "MultiEdit")) {
    $target = Resolve-TargetPath ([string]$ti.file_path) ([string]$in.cwd)
    if (Test-PolicyDatei $target) {
        Write-Decision "deny" ("Schreiben gesperrt: " + $target + ". " + $policyGrund)
    }
    if (-not (Test-Allowed $target)) {
        Write-Decision "deny" (Get-SperrHinweis "Schreiben" $target $ab)
    }
    if (Test-ArtefaktVerbot $target) {
        Write-Decision "deny" "Blockierter Pfad: $target. $artefaktGrund"
    }
    Write-Decision "durch" ""
}

# --- 2) Shell: Pfade aus dem Kommandotext lesen -------------------------------
if ($tool -in @("Bash", "PowerShell")) {
    $cmd = [string]$ti.command
    if ([string]::IsNullOrWhiteSpace($cmd)) { Write-Decision "durch" "" }

    # Den Freigabebefehl fuehrt nur der Besitzer aus, in seinem eigenen Terminal (seit 5.0).
    # Rechteerhoehung aus einer Session (seit 5.1). Der Agent laeuft ohne Adminrechte, und dabei
    # soll es bleiben: Ein Fenster der Benutzerkontensteuerung oder eine Passwortabfrage, die der
    # Agent ausloest, bestaetigt der Besitzer sonst womoeglich, ohne zu wissen, wofuer.
    if ($cmd -match '(?i)(Start-Process[^\r\n;|]*-Verb\s*[''"]?RunAs|\bsudo\b|\bgsudo\b|\brunas(\.exe)?\s|\bdoas\b|with\s+administrator\s+privileges|\bpkexec\b)') {
        Write-Decision "deny" "Gesperrt: Der Befehl wuerde Administratorrechte anfordern (Benutzerkontensteuerung, sudo, runas). Ein Agent fordert nie selbst erhoehte Rechte an, auch nicht auf Wunsch von [NAME] (AGENTS.md Abschnitt 18). Braucht eine Aufgabe Adminrechte, sag ihm in ein, zwei Saetzen, wozu, und gib ihm den Befehl in einem Codeblock, den er selbst in seinem eigenen Fenster ausfuehrt. Erinnere ihn dabei an die Regel: nie eine Abfrage der Benutzerkontensteuerung oder ein Passwortfenster bestaetigen, das er nicht selbst ausgeloest hat."
    }
    if (Test-FreigebenAufruf $cmd 'sperre-haerten\.ps1') {
        Write-Decision "deny" ("Gesperrt: sperre-haerten.ps1 fuehrt nur [NAME] selbst aus, in seinem eigenen Fenster, weil es Administratorrechte braucht und er sie dort bewusst bestaetigt (AGENTS.md Abschnitt 18). Erklaer ihm in ein, zwei Saetzen, was die Haertung bewirkt, und gib ihm den Befehl in einem Codeblock, mit vollem Pfad: " + $(if ($isWindowsHost) { 'powershell -NoProfile -ExecutionPolicy Bypass -File "' } else { 'sudo pwsh -NoProfile -File "' }) + (Join-Path (Join-Path (Join-Path $repo '00_INDEX') 'scripts') 'sperre-haerten.ps1') + '"')
    }
    if (Test-FreigebenAufruf $cmd) {
        $kurz = if ($cmd.Length -gt 300) { $cmd.Substring(0, 300) + " ..." } else { $cmd }
        Write-Decision "deny" ("Gesperrt: freigeben.ps1 fuehrt nur [NAME] selbst aus, in seinem eigenen PowerShell-Fenster, nie du aus einer Session, auch nicht auf seinen Wunsch hin (AGENTS.md Abschnitt 18). Der Befehl verlangt dort ausserdem eine Bestaetigung an der Tastatur. Erklaer ihm in ein, zwei Saetzen, was die Freigabe bewirkt (Lesen und Schreiben in diesem Ordner und allem darunter, Zugangsdaten bleiben gesperrt), und gib ihm den Befehl in einem Codeblock zum Selbstausfuehren, mit vollem Pfad zum Skript, damit er in jedem Fenster laeuft: " + (Get-FreigabeBefehl '<Pfad>' $ab) + " (dazu der Schalter, den du vorgesehen hattest: -Entziehen, -Sperren oder -Entsperren). Dein Aufruf war: " + $kurz)
    }

    # Geprueft werden nur schreibende Kommandos. Das Lesen prueft guard-read.ps1.
    $writeVerbs = @(
        'Set-Content','Add-Content','Out-File','New-Item','Remove-Item','Move-Item','Copy-Item',
        'Rename-Item','Clear-Content','Set-ItemProperty','New-ItemProperty','Remove-ItemProperty',
        'Export-Csv','Export-Clixml','Start-Process','Invoke-WebRequest.*-OutFile',
        'WriteAllText','WriteAllBytes','WriteAllLines','AppendAllText',
        '\bmkdir\b','\brmdir\b','\brm\b','\bmv\b','\bcp\b','\btouch\b','\btee\b','\bdel\b','\berase\b',
        '\bgit\s+(add|commit|push|checkout|reset|clean|rm|mv|init|apply|restore|stash)\b',
        # git tag schreibt nur, wenn ein Tag gesetzt oder geloescht wird; nacktes "git tag"
        # und die Listenoptionen lesen nur. Galt jedes git tag als Schreiben, machte ein
        # Auflisten jeden Lesepfad ausserhalb im selben Kommando zur Sperre (seit 4.8).
        # Ein Verkettungszeichen danach ("git tag && ...") ist kein Tag-Name (seit 4.11).
        '\bgit\s+tag\s+(?!-l\b|--list\b|--sort\b|--points-at\b|--contains\b|--no-contains\b|--merged\b|--no-merged\b|--format\b|-n\d*\b|--column\b)[^\s&|;)]',
        '\bnpm\s+(install|i|uninstall|link)\b','\bpip\s+install\b',
        '>>','\|\s*Out-File','\|\s*Set-Content','\|\s*Add-Content',
        '--print-to-pdf','--screenshot'
    )
    $isWrite = $false
    foreach ($v in $writeVerbs) { if ($cmd -match $v) { $isWrite = $true; break } }

    # Einfache Umleitung der Standardausgabe in eine Datei (seit 4.8): "printf x > ziel"
    # schreibt, ohne dass ein Schreibverb vorkommt. Ausgenommen sind Stream-Umleitungen
    # (2>, 2>&1, >&2, *>), Wegwerfen (>/dev/null, >$null), Pfeile und Vergleiche in Code
    # (->, =>, >=) und ein > in einer zitierten Zeichenkette ("printf 'a > b'"). Die
    # erste Fassung zaehlte jedes > und sperrte damit jedes lesende Kommando mit
    # 2>/dev/null und einem Pfad ausserhalb; das traefe fast jede Sitzung.
    # Seit 4.11 gilt das Wegwerfen auch zitiert (>"/dev/null").
    $umleitungRx = '(?<![>&=*-])(?<![02-9])>(?![>&=])\s*(?![''"]?/dev/null\b|\$null\b)("([^"\r\n]+)"|''([^''\r\n]+)''|([^\s"'';|&)<>]+))'
    function Get-Umleitungsziele([string]$text) {
        $zitate = [regex]::Matches($text, $quotedPattern)
        foreach ($m in [regex]::Matches($text, $umleitungRx)) {
            $imZitat = $false
            foreach ($z in $zitate) {
                if ($m.Index -gt $z.Index -and $m.Index -lt ($z.Index + $z.Length)) { $imZitat = $true; break }
            }
            if ($imZitat) { continue }
            @($m.Groups[2].Value, $m.Groups[3].Value, $m.Groups[4].Value) | Where-Object { $_ } | Select-Object -First 1
        }
    }

    # Die Freigabelisten: jedes schreibende Segment, das eine davon nennt, ist gesperrt, auch
    # git checkout und git add (seit 5.0). Segmentweise, damit "cat ...gesperrte-pfade.txt;
    # touch x" nicht am fremden Schreibverb haengen bleibt.
    if ($cmd -match $policyRx) {
        foreach ($seg in [regex]::Split($cmd, '\r?\n|;|&&|\|\|')) {
            if ($seg -notmatch $policyRx) { continue }
            $segWrite = $false
            foreach ($v in $writeVerbs) { if ($seg -match $v) { $segWrite = $true; break } }
            if (-not $segWrite) {
                foreach ($z in @(Get-Umleitungsziele $seg)) { if ($z -match $policyRx) { $segWrite = $true } }
            }
            if ($segWrite) { Write-Decision "deny" ("Schreiben gesperrt: Der Befehl veraendert eine Freigabeliste. " + $policyGrund) }
        }
    }

    # Ist die Umleitung das einzige Schreibmerkmal, wird nur ihr Ziel geprueft, nicht
    # jeder Pfad im Kommando: Fremdes lesen und ins Repo umleiten bleibt hier erlaubt.
    $nurUmleitung = $false
    if (-not $isWrite) {
        if (@(Get-Umleitungsziele $cmd).Count -gt 0) { $nurUmleitung = $true }
        else { Write-Decision "durch" "" }
    }

    # Arbeitsverzeichnis zaehlt mit: ein schreibendes Kommando mit relativen
    # Pfaden trifft sonst unbemerkt ein fremdes Verzeichnis.
    $cwd = [string]$in.cwd
    if (-not (Test-Allowed $cwd)) {
        Write-Decision "deny" ("Schreibendes Kommando mit Arbeitsverzeichnis ausserhalb des Arbeitsbereichs. " + (Get-SperrHinweis "Schreiben" (Normalize-AbsolutePath $cwd) $ab))
    }

    # Zielpfade, die erst zur Laufzeit entstehen ($env:USERPROFILE, die Tilde,
    # [Environment]::GetFolderPath), werden durch ihren echten Wert ersetzt; danach
    # entscheidet dieselbe Pruefung wie fuer jeden anderen Pfad (lib\arbeitsbereich.ps1).
    $cmdN = Expand-BekannteVariablen $cmd
    $found = @(Get-AbsolutePfade $cmdN $cwd)
    if ($nurUmleitung) {
        $found = @()
        foreach ($ziel in @(Get-Umleitungsziele $cmdN)) {
            if (Normalize-AbsolutePath $ziel) { $found += $ziel }
            elseif ($ziel -match $parentPattern) {
                $aufgeloest = Resolve-TargetPath $ziel $cwd
                if ($aufgeloest) { $found += $aufgeloest }
            }
            # Ein relatives Ziel ohne ".." landet im Arbeitsverzeichnis, das oben geprueft ist.
        }
    }
    foreach ($f in ($found | Select-Object -Unique)) {
        if (-not (Test-Allowed $f)) {
            $n = Normalize-AbsolutePath $f
            if (-not $n) { $n = $f }
            Write-Decision "deny" ("Schreibendes Kommando. " + (Get-SperrHinweis "Schreiben" $n $ab))
        }
    }
    # Formatdisziplin im Shell-Zweig bewusst eng: Nur die AUSGABE-Ziele der bekannten
    # Erzeuger werden geprueft (Chrome-Export, Umleitungen), nicht jeder Pfad im
    # Kommando. Sonst blockiert die Sperre auch das sanktionierte Aufraeumen, etwa
    # Move-Item eines gestrandeten PDFs AUS dem Themenordner in den Artefakte-Ordner.
    foreach ($m in [regex]::Matches($cmdN, '(?:--print-to-pdf=|--screenshot=|>{1,2}\s*)"?([^"\r\n;|]+?)"?(?=\s|$)')) {
        $ziel = $m.Groups[1].Value.Trim()
        if (Test-ArtefaktVerbot $ziel) {
            Write-Decision "deny" "Schreibendes Kommando, blockiertes Ausgabeziel: $ziel. $artefaktGrund"
        }
    }
    Write-Decision "durch" ""
}

Write-Decision "durch" ""

} catch {
    # Die Reihe setzt LEO_GUARD_DEBUG, damit ein abgefangener Fehler dort nicht als PASS durchgeht.
    if ($env:LEO_GUARD_DEBUG) { "HOOK-FEHLER: " + $_.Exception.Message + " (Zeile " + $_.InvocationInfo.ScriptLineNumber + ")"; exit 0 }
    Write-Decision "durch" ""
}
