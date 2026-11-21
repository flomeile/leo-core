# hooks-einrichten.ps1
# Zweck: Richtet die Hook-Befehle in .claude\settings.json (und .codex\hooks.json) fuer die
# Plattform dieses Rechners ein, setzt die Sperren auf "sperren, wenn der Hook nicht startet"
# (AGENTS.md Abschnitt 18, seit 5.1) und richtet seit 6.0 die Sperren fuer alle Projekte des
# Rechners ein, auch ohne Adminrechte.
#
# WARUM ES DAS GIBT: Die mitgelieferten Hook-Befehle rufen "powershell", das gibt es nur unter
# Windows. Auf macOS und Linux startete deshalb bis 5.0 kein Hook, bis der Besitzer die Befehle
# von Hand umschrieb, und ein Hook, der nicht startet, liess bis dahin alles durch. Bei einer
# Standardsperre ist das der gefaehrlichste Fall: Alles sieht richtig aus, und nichts ist gesperrt.
# Seit 5.1 tragen die Sperren "onFailure": "block" (Claude Code ab 2.1.295): Startet der
# Hook nicht, laeuft er in eine Zeitueberschreitung oder endet er mit einem Fehler, sperrt Claude
# Code den Werkzeugaufruf. Dieses Skript schreibt dazu die Befehle so, dass sie hier starten.
#
# SPERREN IN ALLEN PROJEKTEN (seit 6.0): Die Hooks in .claude\settings.json gelten nur im Repo des
# Leo-Kinds. Damit derselbe Agent in einem anderen Ordner nicht ohne Sperre arbeitet, richtet dieses
# Skript zusaetzlich die Sperren in den persoenlichen Einstellungen von Claude Code ein
# (~/.claude/settings.json), die in jedem Projekt gelten:
#   - Die Sperren laufen aus einer Kopie im Benutzerprofil (~/.leo-sperren/<Repo>), nie aus dem Repo.
#     Die Kopie kommt ausschliesslich aus dem offiziellen Versionsstand: aus dem Tag der eingespielten
#     Version, nachdem geprueft ist, dass dieser Tag auf dem Grundgeruest (GitHub) auf denselben Commit
#     zeigt. Was der Agent im Repo an einer Sperre aendert, gelangt so nie in die Kopie. Die Freigabelisten
#     kommen aus dem Repo (sie schreibt nur der Besitzer mit freigeben.ps1).
#   - Ist die Haertung mit Adminrechten eingerichtet (sperre-haerten.ps1), ist das nicht noetig: Dann
#     gelten nur die verwalteten Hooks, und dieses Skript laesst die persoenlichen Einstellungen in Ruhe.
#   - Gegen den Agenten schuetzt beides die Schreibsperre: Profil und Einstellungen liegen ausserhalb des
#     Arbeitsbereichs. Gegen Absicht schuetzt erst die Haertung mit Adminrechten (AGENTS.md Abschnitt 18).
#   - Nicht moeglich ohne Netz oder ohne den Tag auf GitHub: dann bleibt die bisherige Kopie, und das
#     Skript sagt es.
#
# FOLGE, DIE DER BESITZER KENNEN MUSS: Fehlt auf macOS oder Linux PowerShell 7, kann der Agent
# nach diesem Skript gar kein Werkzeug mehr benutzen, bis PowerShell 7 installiert ist. Das ist
# gewollt. Installation auf dem Mac: brew install --cask powershell
#
# WAS ES ANFASST: in .claude\settings.json und .codex\hooks.json nur Hook-Eintraege, deren Befehl eines der
# Kernskripte startet; fehlende Eintraege der Pflichtliste ($pflicht) schreibt es selbst (seit 5.3, Anlass:
# ein vom Modell ueber die Shell geschriebener Eintrag trug Steuerzeichen und haette nie gestartet). Eigene
# Hooks und alle anderen Schluessel bleiben, wie sie sind. In ~/.claude/settings.json nur die eigenen
# Eintraege dieses Repos (erkannt am Pfad der Kopie) und die Leseverbote fuer Zugangsdaten.
#
# AUFRUF (der Agent darf es selbst ausfuehren):
#   Windows:       powershell -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\hooks-einrichten.ps1"
#   macOS/Linux:   pwsh -NoProfile -File "<Repo>/00_INDEX/scripts/hooks-einrichten.ps1"
#   -Pruefen       aendert nichts, meldet nur, was zu tun waere (Exit 1, wenn etwas fehlt)
# Testparameter: -Plattform windows|posix, -Pwsh <Pfad>, -Datei <settings.json>, -CodexDatei <hooks.json>,
#   -Heim <Ordner> (statt des Benutzerprofils), -Quelle <Repo des Grundgeruests>, -System <Systemordner>,
#   -OhneProfil (nur die Projektdateien).
# ASCII-only: laeuft unter Windows PowerShell 5.1 und PowerShell 7.
param(
    [switch]$Pruefen,
    [ValidateSet('', 'windows', 'posix')][string]$Plattform = '',
    [string]$Pwsh = '',
    [string]$Datei = '',
    [string]$CodexDatei = '',
    [string]$Heim = '',
    [string]$Quelle = 'https://github.com/flomeile/leo-core',
    [string]$System = '',
    [switch]$OhneProfil,
    [switch]$NurProfil,
    [switch]$Reparatur,
    [string]$Stand = '',
    [string]$Version = '',
    [switch]$ImKind
)
# -Reparatur ohne -Stand (seit dem Schlusstest von 6.0): nimmt den eigenen gespeicherten Stand aus den persoenlichen
# Einstellungen. -ImKind: laeuft auch im Repo des Kinds; so ruft es die Versionspruefung, wenn -NurProfil die Kopie
# nicht erneuern darf (Update halb fertig, Tag lokal abweichend), und so fuehrt der Besitzer es von Hand aus.
# -NurProfil (seit 6.0): nur die Sperren fuer alle Projekte, ohne die Projektdateien. So ruft es die
# Versionspruefung beim Sessionstart auf, ohne Modell, hoechstens einmal je Tag (version-check.ps1).
# -Reparatur -Stand <commit> -Version <X.Y> (seit 6.0, Zweitpruefung): der Sessionstart in JEDEM Projekt, aus den
# persoenlichen Einstellungen. Fehlt in der Kopie der Sperren eine Datei, sperrt jeder Werkzeugaufruf in jedem
# Projekt; dieser Aufruf stellt sie ohne Netz und ohne Modell wieder her, aus genau dem Commit, der beim
# Einrichten auf GitHub geprueft wurde (er steht in den persoenlichen Einstellungen, die der Agent nicht schreiben
# kann). Ist die Kopie vollstaendig, tut er nichts und sagt nichts.

$ErrorActionPreference = 'Stop'
. (Join-Path (Join-Path $PSScriptRoot 'lib') 'arbeitsbereich.ps1')
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $Plattform) { $Plattform = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { 'windows' } else { 'posix' } }
if (-not $Datei) { $Datei = Join-Path (Join-Path $repo '.claude') 'settings.json' }
if (-not $CodexDatei) { $CodexDatei = Join-Path (Join-Path $repo '.codex') 'hooks.json' }
if ($Plattform -eq 'posix' -and -not $Pwsh) {
    $Pwsh = Join-Path $PSHOME 'pwsh'
    if (-not (Test-Path -LiteralPath $Pwsh)) { $Pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source }
    if (-not $Pwsh) { "PowerShell 7 (pwsh) nicht gefunden. Auf dem Mac installieren mit: brew install --cask powershell"; exit 2 }
}

$kernRx = '00_INDEX[\\/]+scripts[\\/]+(guard-read|guard-workspace|guard-git|guard-mail|guard-fremdsysteme|guard-extern|eingehaengte-repos-aktuell|pruef-frontmatter|version-check)\.ps1"?(.*)$'
$sperren = @('guard-read', 'guard-workspace', 'guard-git', 'guard-mail', 'guard-fremdsysteme', 'guard-extern')
$matcherJe = @{
    'guard-workspace'    = 'Write|Edit|NotebookEdit|MultiEdit|Bash|PowerShell'
    'guard-git'          = 'Bash|PowerShell'
    'guard-mail'         = 'Bash|PowerShell'
    'guard-read'         = 'Read|Grep|Glob|NotebookRead|Bash|PowerShell'
    'guard-fremdsysteme' = 'Bash|PowerShell|Write|Edit|MultiEdit|NotebookEdit|Read|NotebookRead|Grep|Glob|mcp__.*javascript.*'
    'guard-extern'       = 'mcp__.*'
}

function Neuer-Befehl([string]$name, [string]$rest, [string]$wurzel) {
    if ($Plattform -eq 'windows') {
        return 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $wurzel + '\00_INDEX\scripts\' + $name + '.ps1"' + $rest
    }
    return '"' + $Pwsh + '" -NoProfile -File "' + $wurzel + '/00_INDEX/scripts/' + $name + '.ps1"' + $rest
}

# Geht alle Hook-Eintraege einer geladenen Datei durch und gibt die Liste der Aenderungen zurueck.
function Richte-Ein($json, [string]$wurzel, [switch]$MitOnFailure) {
    $aenderungen = @()
    if (-not $json.hooks) { return $aenderungen }
    foreach ($ereignis in $json.hooks.PSObject.Properties) {
        foreach ($gruppe in @($ereignis.Value)) {
            foreach ($h in @($gruppe.hooks)) {
                if (-not $h -or [string]$h.type -ne 'command') { continue }
                $cmd = [string]$h.command
                if ($cmd -notmatch $kernRx) { continue }
                $name = $matches[1]
                $rest = $matches[2]
                $neu = Neuer-Befehl $name $rest $wurzel
                if ($cmd -ne $neu) {
                    $h.command = $neu
                    $aenderungen += "$($ereignis.Name) / ${name}: Befehl fuer $Plattform"
                }
                if ($MitOnFailure -and $ereignis.Name -eq 'PreToolUse' -and $sperren -contains $name) {
                    if ([string]$h.onFailure -ne 'block') {
                        if ($h.PSObject.Properties['onFailure']) { $h.onFailure = 'block' }
                        else { $h | Add-Member -NotePropertyName onFailure -NotePropertyValue 'block' }
                        $aenderungen += "PreToolUse / ${name}: onFailure block"
                    }
                }
            }
        }
    }
    return $aenderungen
}

# Kern-Hooks, die dieses Skript selbst eintraegt, statt sie dem Update-Skill zu ueberlassen (seit 5.3,
# seit 6.0 auch die beiden neuen Sperren). Ein beschaedigter Eintrag (Steuerzeichen im Befehl) wird
# entfernt und neu geschrieben.
$pflicht = @(
    @{ ereignis = 'SessionStart'; name = 'version-check'; rest = ' -Hook SessionStart'; timeout = 60; matcher = '' }
    @{ ereignis = 'PreToolUse'; name = 'guard-fremdsysteme'; rest = ''; timeout = 0; matcher = $matcherJe['guard-fremdsysteme'] }
    @{ ereignis = 'PreToolUse'; name = 'guard-extern'; rest = ''; timeout = 0; matcher = $matcherJe['guard-extern'] }
)
function Ergaenze-Pflicht($json, [string]$wurzel, [switch]$MitOnFailure) {
    $aenderungen = @()
    if (-not $json.PSObject.Properties['hooks']) { $json | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) }
    foreach ($p in $pflicht) {
        $liste = $json.hooks.PSObject.Properties[$p.ereignis]
        $da = $false
        if ($liste) {
            foreach ($gruppe in @($liste.Value)) {
                if (-not $gruppe -or -not $gruppe.PSObject.Properties['hooks']) { continue }
                $alt = @($gruppe.hooks)
                $neu = @($alt | Where-Object { -not ([string]$_.command -match '[\x00-\x1F]' -and [string]$_.command -match ([regex]::Escape($p.name.Substring(1)) + '\.ps1')) })
                if ($neu.Count -ne $alt.Count) { $gruppe.hooks = $neu; $aenderungen += "$($p.ereignis) / $($p.name): beschaedigten Eintrag entfernt (Steuerzeichen im Befehl)" }
                foreach ($h in $neu) { if ([string]$h.command -match $kernRx -and $matches[1] -eq $p.name) { $da = $true } }
            }
        }
        if ($da) { continue }
        $eintrag = [ordered]@{ type = 'command' }
        if ($p.timeout) { $eintrag.timeout = $p.timeout }
        $eintrag.command = (Neuer-Befehl $p.name $p.rest $wurzel)
        if ($MitOnFailure -and $p.ereignis -eq 'PreToolUse') { $eintrag.onFailure = 'block' }
        $eintrag = [pscustomobject]$eintrag
        if ($p.matcher) {
            $gruppeNeu = [pscustomobject]@{ matcher = $p.matcher; hooks = @($eintrag) }
            if ($liste) { $liste.Value = @(@($liste.Value) + $gruppeNeu) }
            else { $json.hooks | Add-Member -NotePropertyName $p.ereignis -NotePropertyValue @($gruppeNeu) -Force }
        } else {
            $erste = if ($liste) { @($liste.Value | Where-Object { $_ -and $_.PSObject.Properties['hooks'] }) | Select-Object -First 1 } else { $null }
            if ($erste) { $erste.hooks = @(@($erste.hooks) + $eintrag) }
            else { $json.hooks | Add-Member -NotePropertyName $p.ereignis -NotePropertyValue @([pscustomobject]@{ hooks = @($eintrag) }) -Force }
        }
        $aenderungen += "$($p.ereignis) / $($p.name): Eintrag ergaenzt"
    }
    return $aenderungen
}

function Schreibe-Json($json, [string]$pfad) {
    $text = $json | ConvertTo-Json -Depth 30
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $pfad) | Out-Null
    [System.IO.File]::WriteAllText($pfad, $text + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-Git([string[]]$argumente) {
    $alt = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $o = & git @argumente 2>$null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $alt
    if ($code -ne 0) { return $null }
    return @($o)
}

# Eine Datei aus einem Git-Stand als Bytes, unveraendert (die Ausgabe der Shell wuerde Kodierung und
# Zeilenenden umschreiben). $null, wenn es die Datei dort nicht gibt.
function Get-GitBlob([string]$repoPfad, [string]$objekt) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = '-C "' + $repoPfad + '" cat-file blob "' + $objekt + '"'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $ms = New-Object System.IO.MemoryStream
    $p.StandardOutput.BaseStream.CopyTo($ms)
    [void]$p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) { return $null }
    return ,$ms.ToArray()
}

# Der beim Einrichten auf GitHub gepruefte Stand, wie er im Reparatur-Eintrag der persoenlichen Einstellungen
# steht (dort kann der Agent nicht schreiben): @{ stand = <commit>; version = <X.Y> } oder $null.
function Get-GespeicherterStand($prof, [switch]$Alle) {
    if (-not (Test-Path -LiteralPath $prof.settings)) { return $null }
    try { $s = Get-Content -LiteralPath $prof.settings -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
    if (-not $s.hooks -or -not $s.hooks.PSObject.Properties['SessionStart']) { return $null }
    $heRx = [regex]::Escape((Join-Path (Join-Path (Join-Path $repo '00_INDEX') 'scripts') 'hooks-einrichten.ps1'))
    $alle = @()
    foreach ($g in @($s.hooks.SessionStart)) {
        foreach ($h in @($g.hooks)) {
            $c = [string]$h.command
            if ($c -match 'hooks-einrichten\.ps1' -and $c -match '-Reparatur\s+-Stand\s+([0-9a-f]{40})\s+-Version\s+([0-9]+\.[0-9]+)') {
                $e = @{ stand = $matches[1]; version = $matches[2] }
                if ($c -match $heRx -and -not $Alle) { return $e }
                $alle += $e
            }
        }
    }
    # -Alle (seit dem Schlusstest von 6.0): auch die Staende anderer Repos dieses Rechners, etwa des alten Orts eines
    # verschobenen Repos. Ein Commit, der beim Einrichten auf GitHub geprueft wurde, bleibt geprueft, wo immer er liegt.
    if ($Alle) { return ,$alle }
    return $null
}

# Eigene Eintraege eines Repos, das es nicht mehr gibt (seit dem Schlusstest von 6.0): Nach dem Verschieben oder
# Umbenennen zeigen die alten Eintraege auf ein Repo und eine Kopie, die niemand mehr erneuert; ist die alte Kopie
# unvollstaendig, sperren sie jeden Werkzeugaufruf. Erkannt an der Kopie unter .leo-sperren und dem Verteiler mit
# -Repo, bzw. am Reparatur-Aufruf von hooks-einrichten.ps1; verwaist, wenn dessen hooks-einrichten.ps1 fehlt.
function Test-VerwaisterEintrag([string]$c) {
    $alt = $null
    if ($c -match '[\\/]\.leo-sperren[\\/]' -and $c -match 'leo-hook\.ps1"?\s+-Repo\s+"([^"]+)"') { $alt = $matches[1] }
    elseif ($c -match '"([^"]+)[\\/]00_INDEX[\\/]scripts[\\/]hooks-einrichten\.ps1"' -and $c -match '-Reparatur') { $alt = $matches[1] }
    if (-not $alt) { return $false }
    return -not (Test-Path -LiteralPath (Join-Path (Join-Path (Join-Path $alt '00_INDEX') 'scripts') 'hooks-einrichten.ps1'))
}

# --- Reparatur beim Sessionstart in jedem Projekt (seit 6.0, Zweitpruefung) -------------------------------
if ($Reparatur) {
    $ErrorActionPreference = 'Stop'
    $prof = Get-ProfilOrt $repo $Heim
    try {
        # Im Kind selbst uebernimmt das die Versionspruefung (version-check.ps1, mit -ImKind), damit die beiden
        # Sessionstart-Hooks nicht gleichzeitig in die Kopie schreiben.
        if (-not $ImKind -and $env:CLAUDE_PROJECT_DIR -and (Test-PathWithin $env:CLAUDE_PROJECT_DIR $repo)) { exit 0 }
        if (Test-Path -LiteralPath (Get-HaertungsOrt $repo $System).dropin) { exit 0 }
        $fehlend = @($haertungsDateien | Where-Object { -not (Test-Path -LiteralPath (Join-Path $prof.kopie $_)) })
        if ($fehlend.Count -eq 0) { exit 0 }
        if (-not $Stand) {
            $gesp = Get-GespeicherterStand $prof
            if ($gesp) { $Stand = $gesp.stand; if (-not $Version) { $Version = $gesp.version } }
        }
        if ($Stand -notmatch '^[0-9a-f]{40}$') { throw 'kein gepruefter Stand in den persoenlichen Einstellungen' }
        $blobs = @{}
        foreach ($rel in $haertungsDateien) {
            $inhalt = Get-GitBlob $repo ($Stand + ':' + $rel)
            if ($null -eq $inhalt) { throw "$rel fehlt im Stand $Stand (Repo verschoben oder geloescht?)" }
            $blobs[$rel] = $inhalt
        }
        foreach ($rel in $haertungsDateien) {
            $ziel = Join-Path $prof.kopie $rel
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ziel) | Out-Null
            [System.IO.File]::WriteAllBytes($ziel, $blobs[$rel])
        }
        foreach ($rel in $haertungsListen) {
            $q = Join-Path $repo $rel
            if (Test-Path -LiteralPath $q) { $ziel = Join-Path $prof.kopie $rel; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ziel) | Out-Null; Copy-Item -LiteralPath $q -Destination $ziel -Force }
        }
        if ($Version) { [System.IO.File]::WriteAllText((Join-Path $prof.kopie 'version.txt'), $Version) }
        "Die Kopie der Sperren fuer alle Projekte war unvollstaendig ($($fehlend -join ', ')) und ist ohne Netz aus dem beim Einrichten auf GitHub geprueften Stand $Version wiederhergestellt (hooks-einrichten.ps1 -Reparatur). Sag es der Person in einer Zeile."
    } catch {
        "Die Kopie der Sperren fuer alle Projekte ist unvollstaendig und liess sich nicht wiederherstellen ($($_.Exception.Message)). Bis dahin sperrt Claude Code jeden Werkzeugaufruf, in jedem Projekt. Sag der Person in zwei Saetzen, dass sie in ihrem eigenen PowerShell-Fenster mit Netz ausfuehrt: powershell -NoProfile -ExecutionPolicy Bypass -File `"$repo\00_INDEX\scripts\hooks-einrichten.ps1`" -NurProfil ; wurde das Repo verschoben, denselben Befehl am neuen Ort (er raeumt die alten Eintraege ab); gibt es das Repo nicht mehr, steht der Notausgang in ANLEITUNG.md, Teil 5, Schritt 7c (Sperren aus den persoenlichen Einstellungen entfernen)."
    }
    exit 0
}

$fehlt = $false
if ($NurProfil) { }
elseif (Test-Path -LiteralPath $Datei) {
    $json = Get-Content -LiteralPath $Datei -Raw -Encoding UTF8 | ConvertFrom-Json
    $wurzel = '${CLAUDE_PROJECT_DIR}'
    $a = @(Ergaenze-Pflicht $json $wurzel -MitOnFailure) + @(Richte-Ein $json $wurzel -MitOnFailure)
    if ($a.Count -eq 0) { "Claude Code ($Datei): eingerichtet, nichts zu tun." }
    else {
        $fehlt = $true
        if ($Pruefen) { "Claude Code ($Datei): fehlt noch:"; $a | ForEach-Object { "  $_" } }
        else { Schreibe-Json $json $Datei; "Claude Code ($Datei): eingerichtet:"; $a | ForEach-Object { "  $_" } }
    }
} else { "Keine $Datei gefunden; nichts eingerichtet." ; $fehlt = $true }

if (-not $NurProfil -and (Test-Path -LiteralPath $CodexDatei)) {
    $cj = Get-Content -LiteralPath $CodexDatei -Raw -Encoding UTF8 | ConvertFrom-Json
    $b = @(Richte-Ein $cj $repo)
    if ($b.Count -eq 0) { "Codex ($CodexDatei): eingerichtet, nichts zu tun." }
    else {
        if ($Pruefen) { "Codex ($CodexDatei): fehlt noch:"; $b | ForEach-Object { "  $_" } }
        else { Schreibe-Json $cj $CodexDatei; "Codex ($CodexDatei): eingerichtet:"; $b | ForEach-Object { "  $_" }; "In Codex muss jeder Hook nach einer Aenderung in den Einstellungen wieder freigeschaltet werden (ANLEITUNG.md, Schritt 7b)." }
    }
}

# --- Sperren in allen Projekten, ohne Adminrechte (seit 6.0) ----------------------------------------
function Richte-Profil-Ein {
    $ort = Get-HaertungsOrt $repo $System
    if (Test-Path -LiteralPath $ort.dropin) { "Alle Projekte: Die Haertung mit Adminrechten ist eingerichtet; die persoenlichen Einstellungen braucht es nicht."; return $false }
    if (Invoke-Git @('-C', $repo, 'config', '--get', 'leo.releaseGate')) { "Alle Projekte: Repo des Herausgebers, keine persoenlichen Einstellungen."; return $false }
    $prof = Get-ProfilOrt $repo $Heim

    # Eingespielte Version und ihr Tag, gegen das Grundgeruest geprueft.
    $version = $null
    $ms = Join-Path $repo 'MEIN-SYSTEM.md'
    if (Test-Path -LiteralPath $ms) {
        $t = Get-Content -LiteralPath $ms -Raw -Encoding UTF8
        if ($t -match '(?m)^\|\s*Eingespielte Version\s*\|\s*([0-9]+\.[0-9]+)\s*\|') { $version = $matches[1] }
    }
    $agentsVersion = $null
    $agDatei = Join-Path $repo 'AGENTS.md'
    if (Test-Path -LiteralPath $agDatei) {
        $kopf = (Get-Content -LiteralPath $agDatei -Encoding UTF8 -TotalCount 12) -join "`n"
        if ($kopf -match '(?m)^version:\s*([0-9]+\.[0-9]+)\s*$') { $agentsVersion = $matches[1] }
    }
    if (-not $version) { $version = $agentsVersion }
    if (-not $version) { "Alle Projekte: Keine eingespielte Version lesbar; die Kopie der Sperren bleibt, wie sie ist."; return $true }
    # Waehrend eines Updates traegt die AGENTS.md schon die neue Version, MEIN-SYSTEM.md noch die alte. Eine
    # Kopie aus dem alten Tag passt dann nicht zu den Eintraegen, die dieses Skript schreibt (gefunden in der
    # Pruefung von 6.0: aus v5.3 kaeme ein Verteiler ohne die neuen Sperren, und jeder Werkzeugaufruf in jedem
    # Projekt waere gesperrt). Deshalb nur bei eindeutiger Version und erst ab 6.0, wo es diesen Weg gibt.
    if ($agentsVersion -and $version -ne $agentsVersion) {
        "Alle Projekte: MEIN-SYSTEM.md nennt $version, die AGENTS.md $agentsVersion (Update noch nicht abgeschlossen). Die Kopie der Sperren bleibt, wie sie ist, bis beide dieselbe Version nennen; die Versionspruefung erneuert sie dann beim naechsten Sessionstart."
        return $true
    }
    if ([version]$version -lt [version]'6.0') { "Alle Projekte: Version $version kennt die Sperren im Benutzerprofil noch nicht (erst ab 6.0); nichts eingerichtet."; return $true }
    $tag = 'v' + $version
    $lokal = @(Invoke-Git @('-C', $repo, 'rev-parse', ($tag + '^{commit}')))[0]
    $fern = $null
    $zeilen = Invoke-Git @('ls-remote', '--tags', $Quelle, ('refs/tags/' + $tag), ('refs/tags/' + $tag + '^{}'))
    foreach ($z in @($zeilen)) {
        if ($z -match ('^([0-9a-f]{40})\s+refs/tags/' + [regex]::Escape($tag) + '\^\{\}$')) { $fern = $matches[1] }
    }
    if (-not $fern) { foreach ($z in @($zeilen)) { if ($z -match ('^([0-9a-f]{40})\s+refs/tags/' + [regex]::Escape($tag) + '$')) { $fern = $matches[1] } } }
    # Ohne Netz (seit 6.0, Zweitpruefung): Zeigt der lokale Tag auf genau den Commit, der beim letzten Einrichten
    # auf GitHub geprueft wurde, gilt er als geprueft; so kann eine unvollstaendige Kopie auch offline heilen.
    if ($lokal -and -not $fern) {
        foreach ($gesp in @(Get-GespeicherterStand $prof -Alle)) {
            if ($gesp -and $gesp.version -eq $version -and $gesp.stand -eq $lokal) { $fern = $lokal }
        }
    }
    if (-not $lokal -or -not $fern -or $lokal -ne $fern) {
        $grund = if (-not $lokal) { "Tag $tag fehlt lokal" } elseif (-not $fern) { "Tag $tag auf dem Grundgeruest nicht erreichbar (kein Netz?)" } else { "Tag $tag zeigt lokal auf einen anderen Commit als auf dem Grundgeruest" }
        "Alle Projekte: Kopie der Sperren nicht erneuert ($grund). Die bisherige Kopie bleibt; naechster Versuch beim naechsten Aufruf."
        return $true
    }

    # Kopie aus dem Tag; abweichende Dateien zaehlen. Fehlt im Tag eine Datei der Sperren, wird nichts
    # kopiert und nichts eingetragen: Ein Eintrag ohne passende Kopie sperrt jeden Werkzeugaufruf.
    $blobs = @{}
    foreach ($rel in $haertungsDateien) {
        $inhalt = Get-GitBlob $repo ($tag + ':' + $rel)
        if ($null -eq $inhalt) { "Alle Projekte: $rel fehlt im Tag $tag; Kopie der Sperren nicht erneuert, die bisherige bleibt."; return $true }
        $blobs[$rel] = $inhalt
    }
    $neu = @()
    foreach ($rel in $haertungsDateien) {
        $inhalt = $blobs[$rel]
        $ziel = Join-Path $prof.kopie $rel
        $vorher = if (Test-Path -LiteralPath $ziel) { [System.IO.File]::ReadAllBytes($ziel) } else { $null }
        if ($null -eq $vorher -or [Convert]::ToBase64String($vorher) -ne [Convert]::ToBase64String($inhalt)) {
            $neu += $rel
            if (-not $Pruefen) {
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ziel) | Out-Null
                [System.IO.File]::WriteAllBytes($ziel, $inhalt)
            }
        }
    }
    foreach ($rel in $haertungsListen) {
        $q = Join-Path $repo $rel
        $ziel = Join-Path $prof.kopie $rel
        $qT = if (Test-Path -LiteralPath $q) { [System.IO.File]::ReadAllText($q) } else { $null }
        $zT = if (Test-Path -LiteralPath $ziel) { [System.IO.File]::ReadAllText($ziel) } else { $null }
        if ($qT -ne $zT) {
            $neu += $rel
            if (-not $Pruefen) {
                if ($null -eq $qT) { Remove-Item -LiteralPath $ziel -Force }
                else { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ziel) | Out-Null; Copy-Item -LiteralPath $q -Destination $ziel -Force }
            }
        }
    }

    # Persoenliche Einstellungen: eigene Eintraege ersetzen, fremde behalten.
    $verteiler = Join-Path (Join-Path (Join-Path $prof.kopie '00_INDEX') 'scripts') 'leo-hook.ps1'
    $exe = if ($Plattform -eq 'windows') { 'powershell -NoProfile -ExecutionPolicy Bypass -File' } else { '"' + $Pwsh + '" -NoProfile -File' }
    $us = if (Test-Path -LiteralPath $prof.settings) { Get-Content -LiteralPath $prof.settings -Raw -Encoding UTF8 | ConvertFrom-Json } else { [pscustomobject]@{} }
    if (-not $us.PSObject.Properties['hooks']) { $us | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) }
    $alt = @()
    if ($us.hooks.PSObject.Properties['PreToolUse']) { $alt = @($us.hooks.PreToolUse) }
    $kopieRx = [regex]::Escape($prof.kopie)
    $behalten = @($alt | Where-Object { -not (@($_.hooks) | Where-Object { [string]$_.command -match $kopieRx -or (Test-VerwaisterEintrag ([string]$_.command)) }) })
    $eigene = @()
    foreach ($s in $sperren) {
        $eigene += [pscustomobject]@{ matcher = $matcherJe[$s]; hooks = @([pscustomobject]@{ type = 'command'; command = ($exe + ' "' + $verteiler + '" -Repo "' + (Normalize-AbsolutePath $repo) + '" -Skript ' + $s); onFailure = 'block' }) }
    }
    $vorherJson = ConvertTo-Json @($alt) -Depth 10 -Compress
    $nachher = @($behalten) + @($eigene)
    $nachherJson = ConvertTo-Json @($nachher) -Depth 10 -Compress
    $deny = @('Read(**/.env)', 'Read(**/.env.*)', 'Read(**/*.pem)', 'Read(**/*.key)', 'Read(**/*.pfx)', 'Read(**/*.p12)',
              'Read(**/*.kdbx)', 'Read(**/*.ppk)', 'Read(**/id_rsa*)', 'Read(**/id_ed25519*)', 'Read(~/.ssh/**)',
              'Read(~/.aws/**)', 'Read(~/.gnupg/**)', 'Read(~/.azure/**)', 'Read(~/.kube/**)', 'Read(~/.leo-sperren/**)')
    if (-not $us.PSObject.Properties['permissions']) { $us | Add-Member -NotePropertyName permissions -NotePropertyValue ([pscustomobject]@{}) }
    $denyAlt = @()
    if ($us.permissions.PSObject.Properties['deny']) { $denyAlt = @($us.permissions.deny) }
    $denyNeu = @($denyAlt + @($deny | Where-Object { $denyAlt -notcontains $_ }))
    # Reparatur-Eintrag beim Sessionstart in jedem Projekt, mit dem gerade geprueften Commit (seit 6.0, Zweitpruefung).
    $hePfad = Join-Path (Join-Path (Join-Path $repo '00_INDEX') 'scripts') 'hooks-einrichten.ps1'
    $heRx = [regex]::Escape($hePfad)
    $reparaturBefehl = $exe + ' "' + $hePfad + '" -NurProfil -Reparatur -Stand ' + $lokal + ' -Version ' + $version
    if ($Heim) { $reparaturBefehl += ' -Heim "' + $Heim + '"' }
    $ssAlt = @()
    if ($us.hooks.PSObject.Properties['SessionStart']) { $ssAlt = @($us.hooks.SessionStart) }
    $ssBehalten = @($ssAlt | Where-Object { -not (@($_.hooks) | Where-Object { ([string]$_.command -match $heRx -and [string]$_.command -match '-Reparatur') -or (Test-VerwaisterEintrag ([string]$_.command)) }) })
    $ssNeu = @($ssBehalten) + @([pscustomobject]@{ hooks = @([pscustomobject]@{ type = 'command'; timeout = 60; command = $reparaturBefehl }) })
    $ssVorherJson = ConvertTo-Json @($ssAlt) -Depth 10 -Compress
    $ssNachherJson = ConvertTo-Json @($ssNeu) -Depth 10 -Compress
    $einstellungNeu = ($vorherJson -ne $nachherJson) -or ($denyNeu.Count -ne $denyAlt.Count) -or ($ssVorherJson -ne $ssNachherJson)
    if ($einstellungNeu) { $neu += $prof.settings }
    if ($neu.Count -eq 0) { "Alle Projekte: Sperren aus Version $version eingerichtet, nichts zu tun ($($prof.kopie))."; return $false }
    if ($Pruefen) { "Alle Projekte: fehlt noch:"; $neu | ForEach-Object { "  $_" }; return $true }
    if ($us.hooks.PSObject.Properties['PreToolUse']) { $us.hooks.PreToolUse = $nachher }
    else { $us.hooks | Add-Member -NotePropertyName PreToolUse -NotePropertyValue $nachher }
    if ($us.permissions.PSObject.Properties['deny']) { $us.permissions.deny = $denyNeu }
    else { $us.permissions | Add-Member -NotePropertyName deny -NotePropertyValue $denyNeu }
    if ($us.hooks.PSObject.Properties['SessionStart']) { $us.hooks.SessionStart = $ssNeu }
    else { $us.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue $ssNeu }
    Schreibe-Json $us $prof.settings
    [System.IO.File]::WriteAllText((Join-Path $prof.kopie 'version.txt'), $version)
    "Alle Projekte: Sperren aus Version $version eingerichtet ($($prof.kopie), $($prof.settings)):"
    $neu | ForEach-Object { "  $_" }
    "Wirkt ab dem naechsten Start von Claude Code."
    return $false
}
if (-not $OhneProfil) {
    $ergebnis = @(Richte-Profil-Ein)
    $ergebnis | Where-Object { $_ -is [string] }
    if (@($ergebnis | Where-Object { $_ -is [bool] })[-1]) { $fehlt = $true }
}

# Claude Code kennt "onFailure" erst ab 2.1.295; aeltere Fassungen lassen einen Hook, der nicht
# startet, weiter durch.
if ($NurProfil) { if ($Pruefen -and $fehlt) { exit 1 }; exit 0 }
$ErrorActionPreference = 'Continue'
$v = (& claude --version 2>$null | Select-Object -First 1)
$ErrorActionPreference = 'Stop'
if ($v -match '(\d+)\.(\d+)\.(\d+)') {
    $alt = ([int]$matches[1] -lt 2) -or ([int]$matches[1] -eq 2 -and ([int]$matches[2] -lt 1 -or ([int]$matches[2] -eq 1 -and [int]$matches[3] -lt 295)))
    if ($alt) { "Claude Code $($matches[0]) ist aelter als 2.1.295: Ein Hook, der nicht startet, sperrt dort noch nicht. Aktualisieren mit: claude update" }
}
if ($Pruefen -and $fehlt) { exit 1 }
exit 0
