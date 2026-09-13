# guard-workspace.ps1
# Zweck: PreToolUse-Hook. Blockiert jeden SCHREIBENDEN Zugriff ausserhalb des Repos.
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
# WAS ER NICHT TUT: Lesen bleibt frei. Der Schaden entsteht beim Veraendern, und
# ein Diagnoseblick in eine fremde Datei soll keine Rueckfrage kosten.
#
# GRENZE, DIE MAN KENNEN MUSS: Dieser Hook liegt IM Repo, weil dort das ganze
# System liegt (AGENTS.md Abschnitt 11: kein Systembestandteil ausserhalb).
# Ein Agent mit Schreibrecht auf das Repo koennte ihn also selbst entschaerfen.
# Genau das verbietet AGENTS.md Abschnitt 18 ausdruecklich: Die Ausnahmeliste
# unten zu erweitern, um an ein blockiertes Ziel zu kommen, ist die Umgehung der
# Regel und nicht ihre Anwendung.
#
# EINRICHTUNG: Der Hook wirkt nur, wenn er in .claude\settings.json unter
# hooks.PreToolUse eingehaengt ist. Die Datei liegt im Paket bei. Ohne sie ist
# Abschnitt 18 eine reine Textregel. Unter Windows startet die mitgelieferte
# Konfiguration "powershell"; unter macOS/Linux muss sie "pwsh" aufrufen und
# POSIX-Pfade verwenden, siehe ANLEITUNG.md. Fehlt der Interpreter, blockiert der
# Hook nichts.
#
# ANPASSEN: Brauchst du dauerhaft einen weiteren Ort ausserhalb des Repos, traegst
# DU ihn unten in $allowPatterns ein, nicht der Agent nebenbei.
#
# Eingabe: JSON auf stdin. Ausgabe: JSON auf stdout NUR beim Blockieren.
#
# Bewusst ASCII-only geschrieben und trotzdem mit BOM gespeichert: Dieses Skript
# laeuft bei jedem einzelnen Werkzeugaufruf und muss unter Windows PowerShell 5.1
# genauso starten wie unter PowerShell 7.

$ErrorActionPreference = "Stop"

$isWindowsHost = [System.IO.Path]::DirectorySeparatorChar -eq '\'
$pathComparison = if ($isWindowsHost) {
    [System.StringComparison]::OrdinalIgnoreCase
} else {
    [System.StringComparison]::Ordinal
}
$pathSeparators = [char[]]@('\', '/')
$homePath = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
# Ohne Trenner am Ende: GetTempPath liefert ihn mit, und ein Ersatz von $env:TEMP in
# einem Kommandotext ergibt sonst "...\Temp\\claude\...", was die UNC-Suche unten als
# Netzwerkpfad \\claude\... liest und blockiert (Regression, gefunden 13.09.2026 in der
# Windows-Reihe der macOS-Fassung).
$tempPath = [System.IO.Path]::GetTempPath().TrimEnd($pathSeparators)

function Normalize-AbsolutePath([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    $p = $path.Trim().Trim('"').Trim("'")

    if ($homePath) {
        if ($p -eq '~') { $p = $homePath }
        elseif ($p -match '^~[\\/]') { $p = Join-Path $homePath $p.Substring(2) }
    }

    # Git-Bash-Schreibweise /c/Repo/... nur unter Windows umformen. Auf POSIX ist
    # derselbe Text bereits ein regulaerer absoluter Pfad.
    if ($isWindowsHost -and $p -match '^/([a-zA-Z])/(.*)$') {
        $p = $matches[1].ToUpper() + ":\" + ($matches[2] -replace '/', '\')
    }
    if ($isWindowsHost) { $p = $p -replace '/', '\' }

    # Absolut heisst hier: unter Windows ein Laufwerk oder ein UNC-Pfad, auf POSIX ein
    # fuehrender Schraegstrich. IsPathRooted allein reicht nicht: Unter Windows gilt
    # ihm auch "\n" oder "\dev\null" als verwurzelt (aktuelles Laufwerk), und damit
    # wurde jeder Kommandotext mit einer Escape-Sequenz in Anfuehrungszeichen
    # blockiert (printf "\n" >> x.md). Gefunden 13.09.2026, gemessen in der Reihe.
    if ($isWindowsHost) {
        if ($p -notmatch '^[a-zA-Z]:\\' -and $p -notmatch '^\\\\') { return $null }
    } elseif ($p -notmatch '^/') { return $null }
    if (-not [System.IO.Path]::IsPathRooted($p)) { return $null }
    try { $p = [System.IO.Path]::GetFullPath($p) } catch { return $null }
    return $p.TrimEnd($pathSeparators)
}

function Test-PathWithin([string]$path, [string]$root) {
    $p = Normalize-AbsolutePath $path
    $r = Normalize-AbsolutePath $root
    if (-not $p -or -not $r) { return $false }
    if ($p.Equals($r, $pathComparison)) { return $true }
    return $p.StartsWith($r + [System.IO.Path]::DirectorySeparatorChar, $pathComparison)
}

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
    $out | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

# Faellt hier etwas aus, darf der Hook den Betrieb nicht blockieren: Eine Sperre,
# die bei einem eigenen Fehler alles anhaelt, ist gefaehrlicher als die Luecke,
# die sie schliesst.
try {

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { Write-Decision "durch" "" }
$in = $raw | ConvertFrom-Json

$repo = Normalize-AbsolutePath (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
# Der Artefakte-Ordner ist der Geschwisterordner "<Repo> Artifacts". Join-Path statt
# Zeichenkette, weil ein Repo direkt auf einem Laufwerk sonst einen doppelten
# Trenner ergibt: Split-Path liefert dort den Laufwerksnamen samt Trennzeichen.
$artifacts = Normalize-AbsolutePath (Join-Path (Split-Path -Parent $repo) ((Split-Path -Leaf $repo) + " Artifacts"))
# Das Belegarchiv ist der zweite Geschwisterordner, nach demselben Muster gebildet:
# dort liegen die Primaerquellen, aus denen Wissensnotizen entstanden sind
# (Abschnitt 5). Getrennt von Artifacts, weil die Herkunft unterschiedlich ist:
# Artifacts traegt, was das System erzeugt hat, das Archiv, was von aussen kam.
$archiv = Normalize-AbsolutePath (Join-Path (Split-Path -Parent $repo) ((Split-Path -Leaf $repo) + " Archiv"))
$scratch = Normalize-AbsolutePath (Join-Path $tempPath 'claude')
$memoryProjects = if ($homePath) {
    Normalize-AbsolutePath (Join-Path (Join-Path $homePath '.claude') 'projects')
} else { $null }
$memoryPattern = if ($memoryProjects) { Join-Path (Join-Path $memoryProjects '*') 'memory' } else { $null }
$memorySubtreePattern = if ($memoryPattern) { Join-Path $memoryPattern '*' } else { $null }

# --- Erlaubte Bereiche ------------------------------------------------------
# Das Repo selbst, dazu drei Ausnahmen, die je einen Ablauf betreffen, der ohne
# sie bricht. Die Muster enthalten vor dem Stern immer einen echten
# Verzeichnistrenner: sonst wuerde ein Muster fuer C:\Leo auch C:\Leonardo
# erlauben, und eines fuer /Users/a/Leo auch /Users/a/Leo-old.
$allowPatterns = @(
    $repo                                          # das Repo selbst
    (Join-Path $repo '*')                         # alles darin
    $artifacts                                     # erzeugte Artefakte (Abschnitt 5)
    (Join-Path $artifacts '*')
    $archiv                                        # Primaerquellen-Archiv (Abschnitt 5)
    (Join-Path $archiv '*')
    $scratch                                       # Scratchpad des Werkzeugs
    (Join-Path $scratch '*')
    $memoryPattern                                 # nur um Harness-Memory zu LOESCHEN
    $memorySubtreePattern
)
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
    # Abgeschnittener Pfad aus einem Kommandotext. Die Pfad-Regex weiter unten
    # endet am Leerzeichen, weil ein Leerzeichen in einem unquotierten Kommando
    # das naechste Argument einleitet. Liegt das Repo selbst in einem Pfad MIT
    # Leerzeichen (etwa unter "C:\Users\Anna Muster\Mein Leo" oder in einem
    # OneDrive-Ordner), findet sie deshalb nur den Anfang, und ohne diese Regel
    # waere jeder Schreibbefehl mit absolutem Pfad im EIGENEN Repo blockiert.
    # Erlaubt wird nur der echte Abschneidefall: Der Fund muss Anfang eines
    # erlaubten Pfades sein UND dort muss genau ein Leerzeichen folgen.
    foreach ($pat in $allowPatterns) {
        if (-not $pat) { continue }
        $klar = $pat.TrimEnd('*').TrimEnd($pathSeparators)
        if ($klar.Length -gt $p.Length -and
            $klar.StartsWith($p, $pathComparison) -and
            $klar[$p.Length] -eq ' ') { return $true }
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
    $target = [string]$ti.file_path
    if (-not (Test-Allowed $target)) {
        Write-Decision "deny" "Ausserhalb des Repos ($repo) wird nichts geschrieben. Blockierter Pfad: $target. Harte Regel, siehe AGENTS.md Abschnitt 18. Wenn das wirklich gewollt ist, gibt es zwei saubere Wege, und beide entscheidet [NAME]: die Datei von Hand an den Zielort legen, oder den Pfad dauerhaft in die Liste `$allowPatterns in 00_INDEX\scripts\guard-workspace.ps1 eintragen. Diese Liste erweiterst du nicht selbst, um an ein blockiertes Ziel zu kommen."
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

    # Geprueft werden nur schreibende Kommandos. Lesen ausserhalb ist erlaubt, und
    # ein Hook, der jede Suche blockiert, fuehrt nur dazu, dass die Sperre
    # irgendwann abgeschaltet wird.
    $writeVerbs = @(
        'Set-Content','Add-Content','Out-File','New-Item','Remove-Item','Move-Item','Copy-Item',
        'Rename-Item','Clear-Content','Set-ItemProperty','New-ItemProperty','Remove-ItemProperty',
        'Export-Csv','Export-Clixml','Start-Process','Invoke-WebRequest.*-OutFile',
        'WriteAllText','WriteAllBytes','WriteAllLines','AppendAllText',
        '\bmkdir\b','\brmdir\b','\brm\b','\bmv\b','\bcp\b','\btouch\b','\btee\b','\bdel\b','\berase\b',
        '\bgit\s+(add|commit|push|checkout|reset|clean|rm|mv|init|apply|restore|stash|tag)\b',
        '\bnpm\s+(install|i|uninstall|link)\b','\bpip\s+install\b',
        '>>','\|\s*Out-File','\|\s*Set-Content','\|\s*Add-Content',
        '--print-to-pdf','--screenshot'
    )
    $isWrite = $false
    foreach ($v in $writeVerbs) { if ($cmd -match $v) { $isWrite = $true; break } }
    if (-not $isWrite) { Write-Decision "durch" "" }

    # Arbeitsverzeichnis zaehlt mit: ein schreibendes Kommando mit relativen
    # Pfaden trifft sonst unbemerkt ein fremdes Verzeichnis.
    $cwd = [string]$in.cwd
    if (-not (Test-Allowed $cwd)) {
        Write-Decision "deny" "Schreibendes Kommando mit Arbeitsverzeichnis ausserhalb des Repos: $cwd. Harte Regel, siehe AGENTS.md Abschnitt 18."
    }

    # --- Zielpfade aufloesen, die erst zur Laufzeit entstehen (seit 3.2) -------
    # Die Pfadsuche unten liest Pfade als TEXT. Ein Kommando, das sein Ziel erst
    # beim Ausfuehren berechnet, enthaelt gar keinen Pfad und ging deshalb durch:
    #   Join-Path ([Environment]::GetFolderPath('Desktop')) 'x.txt'
    # hat auf den Desktop geschrieben, obwohl Hook und Matcher griffen. Dieselbe
    # Luecke bestand bei $env:USERPROFILE, $HOME und der Bash-Tilde. Gemessen und
    # mit demselben Ziel gegengemessen: berechnet keine Ausgabe, literal ein deny.
    #
    # Die Loesung ist bewusst NICHT, solche Ausdruecke pauschal zu blockieren:
    # Das erlaubte Scratchpad und der Memory-Pfad werden genau so geschrieben,
    # und eine Sperre, die legitime Arbeit trifft, wird irgendwann abgeschaltet.
    # Stattdessen werden die bekannten Ausdruecke durch ihren echten Wert
    # ersetzt, danach entscheidet dieselbe Pruefung wie fuer jeden anderen Pfad.
    #
    # GRENZE, ausdruecklich: Wer sein Ziel aus Teilstuecken zusammensetzt, kommt
    # weiter durch. Diese Sperre ist gegen das Versehen gebaut, nicht gegen die
    # Umgehung; letztere verbietet AGENTS.md Abschnitt 18 als Regel, und die
    # tragende technische Ebene dafuer ist die Sandbox des Werkzeugs.
    #
    # BEKANNTES FALSCH-POSITIV, bewusst behalten: Ein Kommandotext, der eine
    # solche Variable nur ERWAEHNT, statt sie als Ziel zu benutzen, wird ebenfalls
    # aufgeloest und kann blockiert werden. Betroffen sind nur Kommandotexte,
    # also auch Commit-Nachrichten; Repo-Dateien laufen ueber file_path. Abhilfe
    # ist Umformulieren. Eine Blockade zu viel kostet einen Satz, eine Luecke
    # kostet eine Datei.
    $cmdN = $cmd
    $ersatz = [ordered]@{
        '\$\{?env:USERPROFILE\}?'      = $homePath
        # Wortgrenze hinter HOME: sonst frisst das Muster den Anfang von $env:HOMEDRIVE
        # und $HOMEPATH, und aus dem Ziel wird Buchstabensalat, den Windows PowerShell
        # 5.1 nicht mehr als Pfad liest (Bypass, gefunden 13.09.2026).
        '\$\{?env:HOME\}?(?![A-Za-z0-9_])' = $homePath
        '\$\{?env:LOCALAPPDATA\}?'     = $env:LOCALAPPDATA
        '\$\{?env:APPDATA\}?'          = $env:APPDATA
        '\$\{?env:PUBLIC\}?'           = $env:PUBLIC
        '\$\{?env:ONEDRIVE\}?'         = $env:OneDrive
        '\$\{?env:PROGRAMDATA\}?'      = $env:ProgramData
        '\$\{?env:SYSTEMROOT\}?'       = $env:SystemRoot
        '\$\{?env:WINDIR\}?'           = $env:windir
        '\$\{?env:TEMP\}?'             = $tempPath
        '\$\{?env:TMP\}?'              = $tempPath
        '\$\{?env:TMPDIR\}?'           = $tempPath
        '\$\{?env:HOMEDRIVE\}?\$\{?env:HOMEPATH\}?' = $homePath
        '\$\{?HOME\}?(?![A-Za-z0-9_])'   = $homePath
        '\$\{?TMPDIR\}?(?![A-Za-z0-9_])' = $tempPath
    }
    # Ersetzt wird ueber eine Lambda und nicht ueber einen Ersatzstring: In einem
    # Ersatzstring ist "$" ein Sonderzeichen, und ein Pfad, der eines enthaelt,
    # wuerde still verstuemmelt. Eine Lambda gibt den Wert unveraendert zurueck.
    foreach ($k in $ersatz.Keys) {
        $wert = $ersatz[$k]
        if ($wert) { $cmdN = [regex]::Replace($cmdN, $k, { param($m) $wert }.GetNewClosure(), 'IgnoreCase') }
    }
    # [Environment]::GetFolderPath('Desktop') und Verwandte. Der Ordnername wird
    # ueber die .NET-Aufzaehlung selbst aufgeloest, damit die Liste nicht von Hand
    # gepflegt werden muss und auch bei umgeleiteten Ordnern stimmt (ein Desktop
    # unterhalb eines Cloud-Speichers ist der Normalfall).
    $cmdN = [regex]::Replace($cmdN, '\[(?:System\.)?Environment\]::GetFolderPath\(\s*[''"]?(?:System\.Environment\+SpecialFolder\.|SpecialFolder\.)?([A-Za-z]+)[''"]?\s*\)', {
        param($m)
        try {
            $wert = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::($m.Groups[1].Value))
            if ($wert) { return $wert }
        } catch { }
        return $m.Value
    }, 'IgnoreCase')
    # Bash-Tilde am Anfang eines Pfades.
    $up = $homePath
    $cmdN = [regex]::Replace($cmdN, '(?<![\w.])~(?=[\\/])', { param($m) $up }.GetNewClosure())

    # Absolute Pfade im Kommandotext einsammeln: Laufwerk, UNC, Git-Bash-Stil
    # oder ein nativer POSIX-Pfad.
    # Das UNC-Muster verlangt bewusst einen Hostnamen und danach einen EINFACHEN
    # Trenner. Ohne diese Verschaerfung trifft es auch JSON mit escapten
    # Backslashes und blockiert damit jeden Versuch, eine Hook-Konfiguration
    # zu schreiben.
    $found = @()
    # Erster Durchgang: Pfade in Anfuehrungszeichen. Die muessen als GANZES
    # geprueft werden, sonst zerfaellt ein Pfad mit Leerzeichen am ersten
    # Leerzeichen, und die Pruefung urteilt ueber etwas, das so nie gemeint war.
    foreach ($m in [regex]::Matches($cmdN, '"([^"\r\n]+)"|''([^''\r\n]+)''')) {
        $inhalt = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
        if (Normalize-AbsolutePath $inhalt) { $found += $inhalt }
    }
    # Zweiter Durchgang: unquotierte Pfade. Endet zwangslaeufig am Leerzeichen,
    # den Abschneidefall faengt Test-Allowed ab.
    # Der linke Anker vor dem Laufwerksmuster verhindert, dass mitten in einem Wort
    # ein "Laufwerk" gefunden wird: file:///C:/... enthaelt sonst den Fund e:///,
    # und jeder Chrome-Aufruf mit Datei-URL waere blockiert (Fix aus dem
    # Ursprungssystem vom 11.08.2026, hier nachgezogen am 30.08.2026).
    $pathRegexes = if ($isWindowsHost) {
        @('(?<![A-Za-z0-9])[a-zA-Z]:[\\/][^"''`;,|)\s]*', '(?<!\\)\\\\[a-zA-Z0-9._-]+\\(?!\\)[^"''`;,|)\s]+', '(?<![\w.])/[a-zA-Z]/[^"''`;,|)\s]*')
    } else {
        # Der linke Anker verhindert Treffer in URLs wie https://example.org/x.
        @('(?<![A-Za-z0-9:/.])/(?!/)[^"''`;,|)\s]+')
    }
    foreach ($rx in $pathRegexes) {
        foreach ($m in [regex]::Matches($cmdN, $rx)) { $found += $m.Value }
    }
    foreach ($f in ($found | Select-Object -Unique)) {
        if (-not (Test-Allowed $f)) {
            Write-Decision "deny" "Schreibendes Kommando mit Ziel ausserhalb des Repos ($repo). Blockierter Pfad: $f. Harte Regel, siehe AGENTS.md Abschnitt 18. Wenn das wirklich gewollt ist, entscheidet [NAME]: die Datei von Hand an den Zielort legen, oder den Pfad dauerhaft in die Liste `$allowPatterns eintragen. Diese Liste erweiterst du nicht selbst."
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
    Write-Decision "durch" ""
}
