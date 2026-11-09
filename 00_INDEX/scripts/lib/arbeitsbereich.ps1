# arbeitsbereich.ps1
# Zweck: Gemeinsame Pfadlogik der Standardsperre (seit 5.0). Wird per Dot-Sourcing geladen von
# guard-read.ps1 (Lesen), guard-workspace.ps1 (Schreiben), freigeben.ps1 (der Befehl des
# Besitzers) und health-check.ps1. Eine Regel, ein Ort: Lese- und Schreibsperre urteilen ueber
# dieselben Zonen, dieselbe Freigabeliste und dieselbe Pfaderkennung, sonst laufen sie auseinander.
#
# DIE STANDARDSPERRE (AGENTS.md Abschnitt 18): Ab Werk liest und schreibt der Agent nur in
#   - dem eigenen Repo,
#   - den Geschwisterordnern "<Repo> Archiv" und "<Repo> Artifacts",
#   - dem Scratchpad des Werkzeugs (<Temp>\claude).
# Dazu kommt, nur zum Lesen, die Werkzeug-Infrastruktur, ohne die der Agent nicht arbeitet: der
# eigene Projektordner des Werkzeugs (~/.claude/projects/<Repo-Name>, dort legt Claude Code grosse
# Werkzeugausgaben und das Memory ab) und die Skill- und Plugin-Ordner des Werkzeugs
# (~/.claude/skills, ~/.claude/plugins) sowie die Programmordner des Rechners. Alles andere ist zu,
# bis der Besitzer es mit
# 00_INDEX\scripts\freigeben.ps1 in 00_INDEX\freigegebene-pfade.txt eintraegt. Innerhalb einer
# Freigabe sperrt 00_INDEX\gesperrte-pfade.txt einzelne Unterordner wieder.
#
# Bewusst ASCII-only: laeuft unter Windows PowerShell 5.1 genauso wie unter PowerShell 7.
# Die Testlisten der Regressionsreihen kommen ueber LEO_GUARD_FREIGABE_KONFIG und
# LEO_GUARD_READ_KONFIG; im Betrieb sind beide Variablen nicht gesetzt.

$isWindowsHost = [System.IO.Path]::DirectorySeparatorChar -eq '\'
$pathComparison = if ($isWindowsHost) {
    [System.StringComparison]::OrdinalIgnoreCase
} else {
    [System.StringComparison]::Ordinal
}
$pathSeparators = [char[]]@('\', '/')
$homePath = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
# Ohne Trenner am Ende: GetTempPath liefert ihn mit, und ein Ersatz von $env:TEMP in
# einem Kommandotext ergibt sonst "...\Temp\\claude\...", was die UNC-Suche als
# Netzwerkpfad \\claude\... liest (Regression, gefunden 13.09.2026).
$tempPath = [System.IO.Path]::GetTempPath().TrimEnd($pathSeparators)
$quotedPattern = '"([^"\r\n]+)"|''([^''\r\n]+)'''
$parentPattern = if ($isWindowsHost) { '(?:^|[\\/])\.\.(?:[\\/]|$)' } else { '(?:^|/)\.\.(?:/|$)' }

function Normalize-AbsolutePath([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    $p = $path.Trim().Trim('"').Trim("'")

    if ($homePath) {
        if ($p -eq '~') { $p = $homePath }
        elseif ($p -match '^~[\\/]') { $p = Join-Path $homePath $p.Substring(2) }
    }

    # Git-Bash kennt /tmp als den Temp-Ordner des Benutzers (seit 5.0). Ohne diese Umformung
    # galt "/tmp/x" unter Windows als relativer Pfad und wurde gar nicht geprueft.
    if ($isWindowsHost -and $p -match '^/tmp(?:/(.*))?$') {
        $p = $tempPath + '\' + ($matches[1] -replace '/', '\')
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
    # Eine Laufwerkswurzel behaelt ihren Trenner: "C:" ohne Trenner heisst unter Windows
    # "aktuelles Verzeichnis auf C:", nicht die Wurzel.
    if ($isWindowsHost -and $p -match '^[a-zA-Z]:\\$') { return $p }
    if (-not $isWindowsHost -and $p -eq '/') { return $p }
    return $p.TrimEnd($pathSeparators)
}

function Test-PathWithin([string]$path, [string]$root) {
    $p = Normalize-AbsolutePath $path
    $r = Normalize-AbsolutePath $root
    if (-not $p -or -not $r) { return $false }
    if ($p.Equals($r, $pathComparison)) { return $true }
    $rt = $r.TrimEnd($pathSeparators)
    return $p.StartsWith($rt + [System.IO.Path]::DirectorySeparatorChar, $pathComparison)
}

# Relative Werkzeugziele gegen das gemeldete Arbeitsverzeichnis aufloesen.
# Ein erlaubtes cwd allein erlaubt noch keinen Ausbruch ueber "../".
function Resolve-TargetPath([string]$path, [string]$cwd) {
    $absolute = Normalize-AbsolutePath $path
    if ($absolute -or [string]::IsNullOrWhiteSpace($path)) { return $absolute }
    $base = Normalize-AbsolutePath $cwd
    if (-not $base) { return $null }
    $relative = $path.Trim().Trim('"').Trim("'")
    return Normalize-AbsolutePath ([System.IO.Path]::Combine($base, $relative))
}

# Liegt $p in einer der Wurzeln? Dazu der Abschneidefall aus einem Kommandotext: Die
# Pfadsuche endet bei unquotierten Pfaden am Leerzeichen. Liegt eine Wurzel selbst in einem
# Pfad MIT Leerzeichen ("C:\Users\Anna Muster\Mein Leo"), findet sie nur den Anfang; erlaubt
# wird dieser Fund nur, wenn er Anfang der Wurzel ist UND dort genau ein Leerzeichen folgt.
function Test-UnterWurzel([string]$p, $wurzeln) {
    $n = Normalize-AbsolutePath $p
    if (-not $n) { return $false }
    foreach ($w in @($wurzeln)) {
        if (-not $w) { continue }
        if (Test-PathWithin $n $w) { return $true }
        $klar = ([string]$w).TrimEnd($pathSeparators)
        if ($klar.Length -gt $n.Length -and $klar.StartsWith($n, $pathComparison) -and $klar[$n.Length] -eq ' ') { return $true }
    }
    return $false
}

# Bekannte Variablen in einem Kommandotext durch ihren echten Wert ersetzen (seit 3.2).
# Die Pfadsuche liest Pfade als TEXT; ein Kommando, das sein Ziel erst beim Ausfuehren
# berechnet ($env:USERPROFILE, $HOME, die Tilde, [Environment]::GetFolderPath('Desktop')),
# enthaelt sonst gar keinen Pfad und ging durch. Ersetzt wird ueber eine Lambda und nicht ueber
# einen Ersatzstring: Dort ist "$" ein Sonderzeichen, und ein Pfad mit "$" wuerde verstuemmelt.
# GRENZE: Wer sein Ziel aus Teilstuecken zusammensetzt, kommt weiter durch. Die Sperre ist
# gegen das Versehen gebaut, nicht gegen die Absicht (AGENTS.md Abschnitt 18).
# BEKANNTES FALSCH-POSITIV, bewusst behalten: Ein Kommandotext, der eine solche Variable nur
# ERWAEHNT (etwa in einer Commit-Nachricht), wird ebenfalls aufgeloest und kann blockiert
# werden. Abhilfe ist Umformulieren; eine Blockade zu viel kostet einen Satz, eine Luecke eine Datei.
function Expand-BekannteVariablen([string]$cmd) {
    $cmdN = $cmd
    $ersatz = [ordered]@{
        '\$\{?env:USERPROFILE\}?'      = $homePath
        # Wortgrenze hinter HOME: sonst frisst das Muster den Anfang von $env:HOMEDRIVE
        # und $HOMEPATH (Bypass, gefunden 13.09.2026).
        '\$\{?env:HOME\}?(?![A-Za-z0-9_])' = $homePath
        '\$\{?env:LOCALAPPDATA\}?'     = $env:LOCALAPPDATA
        '\$\{?env:APPDATA\}?'          = $env:APPDATA
        '\$\{?env:PUBLIC\}?'           = $env:PUBLIC
        '\$\{?env:ONEDRIVE\}?'         = $env:OneDrive
        '\$\{?env:PROGRAMDATA\}?'      = $env:ProgramData
        '\$\{?env:SYSTEMROOT\}?'       = $env:SystemRoot
        '\$\{?env:WINDIR\}?'           = $env:windir
        # Genau den Variablennamen treffen: TMP darf nicht TMPDIR zerlegen.
        '\$\{?env:TEMP(?![A-Za-z0-9_])\}?'   = $tempPath
        '\$\{?env:TMP(?![A-Za-z0-9_])\}?'    = $tempPath
        '\$\{?env:TMPDIR(?![A-Za-z0-9_])\}?' = $tempPath
        '\$\{?env:HOMEDRIVE\}?\$\{?env:HOMEPATH\}?' = $homePath
        '%USERPROFILE%'                  = $homePath
        '\$\{?HOME\}?(?![A-Za-z0-9_])'   = $homePath
        '\$\{?TMPDIR\}?(?![A-Za-z0-9_])' = $tempPath
    }
    foreach ($k in $ersatz.Keys) {
        $wert = $ersatz[$k]
        if ($wert) { $cmdN = [regex]::Replace($cmdN, $k, { param($m) $wert }.GetNewClosure(), 'IgnoreCase') }
    }
    # [Environment]::GetFolderPath('Desktop') und Verwandte, ueber die .NET-Aufzaehlung selbst
    # aufgeloest, damit auch umgeleitete Ordner (Desktop in einem Cloud-Speicher) stimmen.
    $cmdN = [regex]::Replace($cmdN, '\[(?:System\.)?Environment\]::GetFolderPath\(\s*[''"]?(?:System\.Environment\+SpecialFolder\.|SpecialFolder\.)?([A-Za-z]+)[''"]?\s*\)', {
        param($m)
        try {
            $wert = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::($m.Groups[1].Value))
            if ($wert) { return $wert }
        } catch { }
        return $m.Value
    }, 'IgnoreCase')
    # Tilde am Anfang eines Pfades, mit Trenner dahinter oder allein ("ls ~").
    $up = $homePath
    $cmdN = [regex]::Replace($cmdN, '(?<![\w.~-])~(?=[\\/]|$|[\s"'';|&)])', { param($m) $up }.GetNewClosure())
    return $cmdN
}

# Absolute Pfade aus einem (bereits aufgeloesten) Kommandotext einsammeln, dazu relative mit
# Elternsegmenten (..), aufgeloest gegen das Arbeitsverzeichnis.
function Get-AbsolutePfade([string]$cmdN, [string]$cwd) {
    $found = @()
    # Erster Durchgang: Pfade in Anfuehrungszeichen, als GANZES geprueft, sonst zerfaellt ein
    # Pfad mit Leerzeichen am ersten Leerzeichen.
    foreach ($m in [regex]::Matches($cmdN, $quotedPattern)) {
        $inhalt = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
        if (Normalize-AbsolutePath $inhalt) { $found += $inhalt }
        elseif ($inhalt -match $parentPattern -and $inhalt -notmatch '^[A-Za-z][A-Za-z0-9+.-]*://') {
            $aufgeloest = Resolve-TargetPath $inhalt $cwd
            if ($aufgeloest) { $found += $aufgeloest }
        }
    }
    # Zweiter Durchgang: unquotierte Pfade. Endet am Leerzeichen; den Abschneidefall faengt
    # Test-UnterWurzel ab. Der linke Anker vor dem Laufwerksmuster verhindert Funde mitten in
    # einem Wort (file:///C:/... enthielte sonst "e:///"). Das UNC-Muster verlangt einen
    # Hostnamen und danach einen EINFACHEN Trenner, sonst traefe es JSON mit escapten Backslashes.
    $pathRegexes = if ($isWindowsHost) {
        @('(?<![A-Za-z0-9])[a-zA-Z]:[\\/][^"''`;,|)\s]*',
          '(?<!\\)\\\\[a-zA-Z0-9._-]+\\(?!\\)[^"''`;,|)\s]+',
          '(?<![\w.])/[a-zA-Z]/[^"''`;,|)\s]*',
          '(?<![\w.:/-])/tmp(?=[/\s"'';|&)]|$)[^"''`;,|)\s]*')
    } else {
        # Der linke Anker verhindert Treffer in URLs wie https://example.org/x.
        @('(?<![A-Za-z0-9:/.])/(?!/)[^"''`;,|)\s]+')
    }
    foreach ($rx in $pathRegexes) {
        foreach ($m in [regex]::Matches($cmdN, $rx)) { $found += $m.Value }
    }
    # Unquotierte relative Pfade mit Elternsegmenten. Zitierte Argumente wurden oben als Ganzes
    # geprueft und duerfen hier nicht nochmals am Leerzeichen zerfallen. URLs bleiben frei.
    $unquotedPaths = [regex]::Replace($cmdN, $quotedPattern, ' ')
    foreach ($m in [regex]::Matches($unquotedPaths, '[^"''`;,|()<>\s]+')) {
        $pfad = $m.Value
        if ($pfad -match $parentPattern -and $pfad -notmatch '^[A-Za-z][A-Za-z0-9+.-]*://' -and
            -not (Normalize-AbsolutePath $pfad)) {
            $aufgeloest = Resolve-TargetPath $pfad $cwd
            if ($aufgeloest) { $found += $aufgeloest }
        }
    }
    return @($found | Select-Object -Unique)
}

# Eine Pfadliste lesen (freigegebene-pfade.txt, gesperrte-pfade.txt): eine Angabe je Zeile,
# absolut, ~ und $HOME erlaubt, # ist Kommentar. "keine"/"none" ist der alte Marker des
# Besitzers fuer "nichts gesperrt" (bis 4.11) und kein Pfad.
#
# Eine Freigabe traegt vorn ihre Stufe (seit 5.0, Vorgabe des Herausgebers: der Besitzer
# entscheidet bei jeder Freigabe selbst, ob nur gelesen oder auch geschrieben werden darf):
#   lesen: C:\Pfad                  nur Lesen
#   lesen-und-schreiben: C:\Pfad    Lesen und Schreiben
# Eine Zeile ohne Stufe gilt als "lesen", die vorsichtigere Lesart.
$stufenRx = '^(?i)(lesen-und-schreiben|lesen)\s*:\s+(.+)$'

function Split-ListenZeile([string]$zeile) {
    $l = $zeile.Trim()
    if ($l -eq '' -or $l.StartsWith('#') -or $l -ieq 'keine' -or $l -ieq 'none') { return $null }
    $stufe = 'lesen'
    if ($l -match $stufenRx) { $stufe = $matches[1].ToLower(); $l = $matches[2].Trim() }
    $n = Normalize-AbsolutePath (Expand-BekannteVariablen $l)
    if (-not $n) { return $null }
    return @{ pfad = $n; stufe = $stufe }
}

function Read-PfadListe([string]$datei, [switch]$NurSchreiben) {
    $list = @()
    if (-not $datei -or -not (Test-Path -LiteralPath $datei)) { return $list }
    foreach ($line in Get-Content -LiteralPath $datei -Encoding UTF8) {
        $z = Split-ListenZeile $line
        if (-not $z) { continue }
        if ($NurSchreiben -and $z.stufe -ne 'lesen-und-schreiben') { continue }
        $list += $z.pfad
    }
    return $list
}

# $indexOrdner: wo die beiden Listen liegen. Leer heisst <Repo>/00_INDEX. Die Schutzkopie der
# Haertung (sperre-haerten.ps1) gibt ihren eigenen Ordner an, damit dort die Kopien gelten, die
# nur mit Adminrechten zu aendern sind.
function Get-Arbeitsbereich([string]$repoRoh, [string]$indexOrdner = '') {
    $repo = Normalize-AbsolutePath $repoRoh
    $eltern = Split-Path -Parent $repo
    $name = Split-Path -Leaf $repo
    $index = Join-Path $repo '00_INDEX'
    $listen = if ($indexOrdner) { $indexOrdner } else { $index }
    $scratch = @(Normalize-AbsolutePath (Join-Path $tempPath 'claude'))
    # Unter Windows kann TEMP in der 8.3-Kurzform stehen (C:\Users\ANNAMU~1\...), waehrend das
    # Werkzeug die Langform meldet. Die Langform ueber LOCALAPPDATA kommt deshalb dazu.
    if ($isWindowsHost -and $env:LOCALAPPDATA) {
        $scratch += Normalize-AbsolutePath (Join-Path (Join-Path $env:LOCALAPPDATA 'Temp') 'claude')
    }
    $werkzeugLesen = @()
    if ($homePath) {
        $claudeDir = Join-Path $homePath '.claude'
        # Claude Code legt den Projektordner unter dem Repo-Pfad ab, jedes Zeichen ausser
        # Buchstaben und Ziffern wird zum Bindestrich (C:\Leo -> C--Leo).
        $werkzeugLesen += Normalize-AbsolutePath (Join-Path (Join-Path $claudeDir 'projects') ($repo -replace '[^A-Za-z0-9]', '-'))
        $werkzeugLesen += Normalize-AbsolutePath (Join-Path $claudeDir 'skills')
        $werkzeugLesen += Normalize-AbsolutePath (Join-Path $claudeDir 'plugins')
    }
    # Programmordner, nur lesend (seit 5.0): Dort liegen Programme, keine Daten des Besitzers.
    # Ohne diese Zone wuerde jeder Aufruf eines Programms mit vollem Pfad (Chrome fuer einen
    # PDF-Export, LibreOffice, ein Python unter Programme) eine Freigabe verlangen, und ein Agent,
    # der seinen Besitzer fuer Selbstverstaendliches um Erlaubnis bittet, nervt.
    $programme = @()
    if ($isWindowsHost) {
        foreach ($v in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432, $env:SystemRoot)) {
            if ($v) { $programme += Normalize-AbsolutePath $v }
        }
        if ($env:LOCALAPPDATA) { $programme += Normalize-AbsolutePath (Join-Path $env:LOCALAPPDATA 'Programs') }
    } else {
        $programme = @('/Applications', '/System', '/usr', '/bin', '/sbin', '/opt', '/Library/Frameworks')
    }
    $freigabeDatei = if ($env:LEO_GUARD_FREIGABE_KONFIG) { $env:LEO_GUARD_FREIGABE_KONFIG } else { Join-Path $listen 'freigegebene-pfade.txt' }
    $sperrDatei = if ($env:LEO_GUARD_READ_KONFIG) { $env:LEO_GUARD_READ_KONFIG } else { Join-Path $listen 'gesperrte-pfade.txt' }
    return @{
        repo          = $repo
        name          = $name
        archiv        = Normalize-AbsolutePath (Join-Path $eltern ($name + ' Archiv'))
        artifacts     = Normalize-AbsolutePath (Join-Path $eltern ($name + ' Artifacts'))
        scratch       = $scratch
        werkzeugLesen = $werkzeugLesen
        programme     = @($programme | Where-Object { $_ })
        freigabeDatei = $freigabeDatei
        sperrDatei    = $sperrDatei
        freigaben     = @(Read-PfadListe $freigabeDatei)
        freigabenSchreiben = @(Read-PfadListe $freigabeDatei -NurSchreiben)
        sperren       = @(Read-PfadListe $sperrDatei)
        freigebenSkript = Join-Path (Join-Path $index 'scripts') 'freigeben.ps1'
    }
}

# Die eingebauten Zonen, in denen gelesen UND geschrieben werden darf.
function Get-EingebauteZonen($ab) {
    return @($ab.repo, $ab.archiv, $ab.artifacts) + @($ab.scratch)
}

# Liefert die Sperre aus gesperrte-pfade.txt, unter der $p liegt, sonst $null.
function Get-Sperre([string]$p, $ab) {
    foreach ($s in @($ab.sperren)) {
        if (Test-PathWithin $p $s) { return $s }
    }
    return $null
}

function Test-Freigegeben([string]$p, $ab, [switch]$Schreiben) {
    if ($Schreiben) { return (Test-UnterWurzel $p $ab.freigabenSchreiben) }
    return (Test-UnterWurzel $p $ab.freigaben)
}

function Test-LesenErlaubt([string]$p, $ab) {
    if (Test-UnterWurzel $p ((Get-EingebauteZonen $ab) + @($ab.werkzeugLesen) + @($ab.programme))) { return $true }
    if (-not $isWindowsHost -and $p -match '^/dev/(null|stdout|stderr|stdin|tty|fd/)') { return $true }
    # Ein Programm mit vollem Pfad aufzurufen ist kein Lesen von Daten (python.exe, git.exe).
    if ($isWindowsHost -and $p -match '(?i)\.(exe|com|cmd|bat|msc)$') { return $true }
    return (Test-Freigegeben $p $ab)
}

# Eine Freigabe dieser Breite hebt die Sperre praktisch auf: Laufwerkswurzel, Benutzerordner
# selbst oder der Ordner aller Benutzer.
function Test-ZuWeit([string]$p) {
    $n = Normalize-AbsolutePath $p
    if (-not $n) { return $false }
    if ($isWindowsHost -and $n -match '^[a-zA-Z]:\\?$') { return $true }
    if ($n -eq '/') { return $true }
    if ($homePath) {
        $h = Normalize-AbsolutePath $homePath
        if ($h -and ($n.Equals($h, $pathComparison) -or $n.Equals((Split-Path -Parent $h), $pathComparison))) { return $true }
    }
    if ($n -match '^\\\\[^\\]+\\[^\\]+$') { return $true }
    return $false
}

# Der Ordner, den der Agent dem Besitzer zur Freigabe vorschlaegt: bei einer Datei ihr
# Ordner, nie eine Laufwerkswurzel oder der Benutzerordner selbst.
function Get-FreigabeZiel([string]$p) {
    $n = Normalize-AbsolutePath $p
    if (-not $n) { return $p }
    $ziel = $n
    $istDatei = $false
    try {
        if (Test-Path -LiteralPath $n -PathType Leaf) { $istDatei = $true }
        elseif (-not (Test-Path -LiteralPath $n -PathType Container) -and [System.IO.Path]::GetExtension($n)) { $istDatei = $true }
    } catch { }
    if ($istDatei) {
        $eltern = Split-Path -Parent $n
        if ($eltern -and -not (Test-ZuWeit $eltern)) { $ziel = $eltern }
    }
    return $ziel
}

function Get-FreigabeBefehl([string]$ziel, $ab, [string]$schalter = '') {
    $exe = if ($isWindowsHost) { 'powershell -NoProfile -ExecutionPolicy Bypass -File' } else { 'pwsh -NoProfile -File' }
    $s = $exe + ' "' + $ab.freigebenSkript + '" "' + $ziel + '"'
    if ($schalter) { $s += ' -' + $schalter }
    return $s
}

function Get-ZonenText($ab) {
    return "im eigenen Repo (" + $ab.repo + "), in den Ordnern '" + $ab.name + " Archiv' und '" + $ab.name + " Artifacts' daneben und im Scratchpad"
}

# Der Hinweis, den jede Sperre der Standardsperre traegt (AGENTS.md Abschnitt 18): Grund,
# Sperre und der fertige Befehl, den nur der Besitzer selbst ausfuehrt.
function Get-SperrHinweis([string]$art, [string]$p, $ab) {
    $ziel = Get-FreigabeZiel $p
    $sperre = Get-Sperre $p $ab
    if ($sperre) {
        return ($art + " gesperrt: " + $p + " liegt unter '" + $sperre + "', und dieser Pfad steht in 00_INDEX/gesperrte-pfade.txt. Der Besitzer hat ihn bewusst gesperrt, auch wenn ein Ordner darueber freigegeben ist (AGENTS.md Abschnitt 18). Oeffne die Sperre nie selbst und such keinen anderen Weg an die Datei. Sag [NAME] in ein, zwei Saetzen, was du wolltest und dass dieser Ordner gesperrt ist. Will er ihn wirklich oeffnen, fuehrt er selbst in seinem eigenen PowerShell-Fenster aus (der Befehl fragt nur nach einer Bestaetigung; danach gilt dort die Stufe der Freigabe darueber): " + (Get-FreigabeBefehl $sperre $ab 'Entsperren'))
    }
    $nurLesend = ''
    if ($art -eq 'Schreiben' -and (Test-Freigegeben $p $ab)) {
        $nurLesend = " Der Ordner ist schon freigegeben, aber nur zum Lesen; derselbe Befehl fragt [NAME] erneut nach der Stufe."
    }
    return ($art + " gesperrt: " + $p + " liegt ausserhalb des Arbeitsbereichs." + $nurLesend + " Ab Werk liest und schreibt dieses System nur " + (Get-ZonenText $ab) + "; alles andere auf diesem Rechner bleibt zu, bis [NAME] es selbst freigibt, damit nichts ungefragt gelesen, veraendert oder zum Modellanbieter geschickt wird (AGENTS.md Abschnitt 18). Oeffne die Sperre nie selbst und such keinen anderen Weg an die Datei. Brauchst du den Ordner fuer die Aufgabe wirklich (sonst frag nicht und arbeite ohne ihn weiter), sag [NAME] in wenigen Saetzen: wozu du ihn brauchst; welches Risiko jede Stufe hat (nur Lesen: der Inhalt geht an den Modellanbieter; Lesen und Schreiben: dazu kannst du dort Dateien aendern und loeschen, ohne dass Git sie zurueckholt); welche Stufe die Aufgabe braucht. Die Stufe waehlt er selbst, der Befehl fragt ihn danach. Gib ihm in einem Codeblock diesen Befehl fuer sein eigenes PowerShell-Fenster, zeichengleich: " + (Get-FreigabeBefehl $ziel $ab) + " . Zugangsdaten bleiben auch nach einer Freigabe gesperrt.")
}

# Eine Zeile in eine Pfadliste eintragen oder daraus entfernen. Nur fuer freigeben.ps1 und die
# Testreihe; der Agent schreibt diese Listen nie (guard-workspace.ps1 blockiert es).
# $stufe ist bei der Freigabeliste "lesen" oder "lesen-und-schreiben", bei der Sperrliste leer.
# Rueckgabe: hinzugefuegt, geaendert (gleicher Pfad, andere Stufe), schon-da, entfernt, nicht-gefunden.
function Set-PfadInListe([string]$datei, [string]$pfad, [switch]$Entfernen, [string[]]$kopf = @(), [string]$stufe = '') {
    $ziel = Normalize-AbsolutePath $pfad
    if (-not $ziel) { throw "Kein absoluter Pfad: $pfad" }
    $zeile = if ($stufe) { $stufe + ': ' + $ziel } else { $ziel }
    $zeilen = @()
    if (Test-Path -LiteralPath $datei) { $zeilen = @(Get-Content -LiteralPath $datei -Encoding UTF8) }
    else { $zeilen = @($kopf) }
    $treffer = @()
    $gleicheStufe = $false
    for ($i = 0; $i -lt $zeilen.Count; $i++) {
        $z = Split-ListenZeile ([string]$zeilen[$i])
        if ($z -and $z.pfad.Equals($ziel, $pathComparison)) {
            $treffer += $i
            if (-not $stufe -or $z.stufe -eq $stufe) { $gleicheStufe = $true }
        }
    }
    if (-not $Entfernen -and $treffer.Count -gt 0 -and -not $gleicheStufe) {
        $neu = @()
        for ($i = 0; $i -lt $zeilen.Count; $i++) { if ($treffer -notcontains $i) { $neu += $zeilen[$i] } }
        $neu += $zeile
        [System.IO.File]::WriteAllLines($datei, [string[]]$neu, (New-Object System.Text.UTF8Encoding($false)))
        return 'geaendert'
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    if ($Entfernen) {
        if ($treffer.Count -eq 0) { return 'nicht-gefunden' }
        $neu = @()
        for ($i = 0; $i -lt $zeilen.Count; $i++) { if ($treffer -notcontains $i) { $neu += $zeilen[$i] } }
        [System.IO.File]::WriteAllLines($datei, [string[]]$neu, $utf8)
        return 'entfernt'
    }
    if ($treffer.Count -gt 0) { return 'schon-da' }
    $zeilen += $zeile
    [System.IO.File]::WriteAllLines($datei, [string[]]$zeilen, $utf8)
    return 'hinzugefuegt'
}

# --- Haertung mit verwalteten Einstellungen (sperre-haerten.ps1, seit 5.1) -------------------
# Wo Claude Code seine verwalteten Einstellungen liest und wo die Schutzkopie der Sperren liegt.
# Beides ist nur mit Administratorrechten zu aendern. $systemOrdner ersetzt den Systemordner in
# der Testreihe.
$haertungsDateien = @(
    '00_INDEX/scripts/guard-read.ps1', '00_INDEX/scripts/guard-workspace.ps1',
    '00_INDEX/scripts/guard-git.ps1', '00_INDEX/scripts/guard-mail.ps1',
    '00_INDEX/scripts/leo-hook.ps1', '00_INDEX/scripts/lib/arbeitsbereich.ps1')
$haertungsListen = @('00_INDEX/freigegebene-pfade.txt', '00_INDEX/gesperrte-pfade.txt')

function Get-HaertungsOrt([string]$repo, [string]$systemOrdner = '') {
    $sys = $systemOrdner
    if (-not $sys) {
        if ($isWindowsHost) { $sys = Join-Path $env:ProgramFiles 'ClaudeCode' }
        elseif ($IsMacOS) { $sys = '/Library/Application Support/ClaudeCode' }
        else { $sys = '/etc/claude-code' }
    }
    $n = Normalize-AbsolutePath $repo
    $slug = ($n -replace '[^A-Za-z0-9]', '-').Trim('-')
    return @{
        system = $sys
        dropin = Join-Path (Join-Path $sys 'managed-settings.d') ('50-leo-' + $slug + '.json')
        kopie  = Join-Path (Join-Path $sys 'leo') $slug
    }
}

# Stand der Haertung: fehlt, aktuell oder veraltet (die Schutzkopie weicht vom Repo ab, etwa nach
# einem Update oder einer Freigabe, die noch nicht uebernommen ist). Liefert dazu die Abweichungen.
function Get-HaertungsStand([string]$repo, $ort) {
    if (-not (Test-Path -LiteralPath $ort.dropin)) { return @{ stand = 'fehlt'; abweichend = @() } }
    $ab = @()
    foreach ($rel in ($haertungsDateien + $haertungsListen)) {
        $q = Join-Path $repo $rel
        $k = Join-Path $ort.kopie $rel
        $qda = Test-Path -LiteralPath $q
        $kda = Test-Path -LiteralPath $k
        if (-not $qda -and -not $kda) { continue }
        if ($qda -ne $kda) { $ab += $rel; continue }
        $hq = (Get-FileHash -LiteralPath $q -Algorithm SHA256).Hash
        $hk = (Get-FileHash -LiteralPath $k -Algorithm SHA256).Hash
        if ($hq -ne $hk) { $ab += $rel }
    }
    return @{ stand = $(if ($ab.Count -eq 0) { 'aktuell' } else { 'veraltet' }); abweichend = $ab }
}
