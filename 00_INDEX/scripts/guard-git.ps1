# guard-git.ps1
# Zweck: PreToolUse-Hook fuer Bash und PowerShell mit drei Sperren, unabhaengig vom Berechtigungsmodus:
#   1. Pauschales Stagen: "git add -A", "git add --all", "git add ." (seit 3.3).
#   2. Push auf den Standardzweig eines fremden Repos (seit 6.0).
#   3. Mergen eines Pull Requests: "gh pr merge" und Merge ueber "gh api", in jedem Repo (seit 6.0).
#
# WARUM 1: Die Regel "nur die eigenen Pfade stagen" (AGENTS.md, Abschnitt 12) laesst sich auch als
# Verbotsliste in den Werkzeug-Einstellungen hinterlegen, die greift aber nur in den Modi, in denen das
# Werkzeug um Erlaubnis fragt. Hooks laufen in jedem Modus. Bewusst NICHT in guard-workspace.ps1: Ein
# Fehler in einem neuen Hook darf den bewaehrten nicht mitreissen (AGENTS.md, Abschnitt 18).
#
# WARUM 2 UND 3: In einem geteilten Repo gilt "nur der Besitzer schreibt auf den Standardzweig und
# merget, alle anderen kommen per Pull Request". Wer Schreibrecht hat, wird von GitHub daran nicht in
# jedem Plan gehindert, und ein Agent leiht sich die Rechte seines Besitzers. Deshalb sperrt die
# Agentenseite (AGENTS.md, Abschnitt 12):
#   - Push auf den Standardzweig nur im eigenen Repo und im Belegarchiv "<Repo> Archiv". Jedes andere
#     Repo ist fremd, auch ein eingehaengtes Repo, das als Ordner in diesem Repo liegt: Massgeblich ist der
#     Wurzelordner des Git-Repos (git rev-parse --show-toplevel), nicht der Pfad.
#   - Standardzweig heisst: main, master und der Zweig, auf den refs/remotes/<remote>/HEAD zeigt.
#   - Gemergt wird nie vom Agenten, auch nicht im eigenen Repo: Der Merge gehoert dem Besitzer.
# IM ZWEIFEL GESPERRT: Laesst sich das Ziel eines Pushes nicht sicher bestimmen (Pfad aus einer Variable,
# --all, --mirror, Ordner existiert nicht), wird gesperrt. Ein eigener Fehler endet im Sperren, sobald der
# Befehl git push oder gh ... merge enthaelt; sonst im Durchlassen.
# GRENZE: Ein Push, der in einer Skriptdatei steckt, ist fuer diesen Hook unsichtbar; er sieht nur den
# Kommandotext (AGENTS.md, Abschnitt 18, "Die Hooks schuetzen gegen das Versehen").
#
# -Repo: das Repo dieses Systems. Der Verteiler leo-hook.ps1 uebergibt es, weil dieses Skript nach der
# Haertung aus einer Schutzkopie laeuft; ohne Angabe gilt der Ordner zwei Ebenen ueber diesem Skript.
# Eingabe: JSON auf stdin (tool_name, tool_input.command, cwd). Ausgabe: JSON nur beim Blockieren,
# Exitcode immer 0. ASCII-only mit BOM: laeuft unter Windows PowerShell 5.1 und PowerShell 7.
# Regressionsreihe: guard-git-tests.ps1 im selben Ordner, unter pwsh und mit -Exe powershell.
param([string]$Repo = '')

$ErrorActionPreference = "Stop"

function Write-Deny([string]$reason) {
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

$istWindows = [System.IO.Path]::DirectorySeparatorChar -eq '\'
$heim = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }

$mergeGrund = "Mergen ist gesperrt, in jedem Repo: gh pr merge und ein Merge ueber gh api fuehrt nur der Besitzer des Repos aus, nie ein Agent (AGENTS.md Abschnitt 12). Gib [NAME] die Adresse des Pull Requests; der Besitzer klickt auf GitHub 'Merge pull request'."
$unklarGrund = "Push gesperrt, weil die Sperre das Ziel nicht sicher bestimmen kann (Pfad aus einer Variable, --all, --mirror, ':' als Ziel oder ein Ordner, den es nicht gibt). Schreib den Befehl ausdruecklich, etwa: git -C <Repo-Pfad> push origin <themenzweig>."
function Get-PushGrund([string]$zweig, [string]$top) {
    return "Push auf den Standardzweig '" + $zweig + "' von " + $top + " ist gesperrt: Ausserhalb des eigenen Repos und des Belegarchivs schreibst du nie direkt auf den Standardzweig; ein eingehaengtes Repo gilt als fremd (AGENTS.md Abschnitt 12). Weg: auf einen Themenzweig pushen und einen Pull Request oeffnen, gemergt wird vom Besitzer des Repos."
}

function Resolve-Pfad([string]$p, [string]$basis) {
    if ([string]::IsNullOrWhiteSpace($p)) { return $null }
    if ($p -match '[\$`*?%]') { return $null }
    if ($p -eq '~') { $p = $heim } elseif ($p -match '^~[\\/]') { $p = Join-Path $heim $p.Substring(2) }
    if ($istWindows -and $p -match '^/([a-zA-Z])(/.*)?$') {
        $rest = if ($matches[2]) { $matches[2].Substring(1) } else { '' }
        $p = $matches[1].ToUpper() + ':\' + ($rest -replace '/', '\')
    }
    $absolut = if ($istWindows) { $p -match '^[a-zA-Z]:[\\/]' -or $p -match '^\\\\' } else { $p.StartsWith('/') }
    if (-not $absolut) {
        if (-not $basis) { return $null }
        $p = Join-Path $basis $p
    }
    try { return [System.IO.Path]::GetFullPath($p).TrimEnd('\', '/') } catch { return $null }
}

function Test-Gleich([string]$a, [string]$b) {
    if (-not $a -or -not $b) { return $false }
    if ($istWindows) { return $a.Equals($b, [System.StringComparison]::OrdinalIgnoreCase) }
    return $a.Equals($b, [System.StringComparison]::Ordinal)
}

function Get-GitWert([string]$dir, [string[]]$argumente) {
    $alt = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $o = & git -C $dir @argumente 2>$null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $alt
    if ($code -ne 0 -or -not $o) { return '' }
    return ([string](@($o)[0])).Trim()
}

# Zerlegt einen Kommandotext in Abschnitte (getrennt durch ; & | Klammern und Zeilenumbruch) und jeden
# Abschnitt in Woerter. Anfuehrungszeichen halten ein Wort zusammen; zitierte Woerter sind markiert, damit
# ein eingebetteter Befehl (pwsh -c "git push ...") selbst geprueft werden kann.
function Get-Abschnitte([string]$s) {
    $abschnitte = New-Object System.Collections.ArrayList
    $aktuell = New-Object System.Collections.ArrayList
    $sb = New-Object System.Text.StringBuilder
    $hat = $false
    $zitiert = $false
    $trenner = ';&|(){}' + "`r`n"
    $i = 0
    $n = $s.Length
    while ($i -le $n) {
        $ende = ($i -eq $n)
        $c = if ($ende) { [char]0 } else { $s[$i] }
        if (-not $ende -and ($c -eq '"' -or $c -eq "'")) {
            $j = $s.IndexOf($c, $i + 1)
            if ($j -lt 0) { $j = $n }
            [void]$sb.Append($s.Substring($i + 1, $j - $i - 1))
            $hat = $true
            $zitiert = $true
            $i = $j + 1
            continue
        }
        $istTrenner = $ende -or $trenner.IndexOf($c) -ge 0
        if ($istTrenner -or $c -eq ' ' -or $c -eq "`t") {
            if ($hat) {
                [void]$aktuell.Add(@{ t = $sb.ToString(); q = $zitiert })
                [void]$sb.Clear()
                $hat = $false
                $zitiert = $false
            }
            if ($istTrenner -and $aktuell.Count -gt 0) {
                [void]$abschnitte.Add(@($aktuell.ToArray()))
                $aktuell = New-Object System.Collections.ArrayList
            }
            $i++
            continue
        }
        [void]$sb.Append($c)
        $hat = $true
        $i++
    }
    return ,$abschnitte
}

# Umleitungen (> datei, 2>$null, 2>&1) sind keine Argumente des Befehls.
function Remove-Umleitungen($woerter) {
    $rein = @()
    $k = 0
    while ($k -lt $woerter.Count) {
        $t = [string]$woerter[$k].t
        if (-not $woerter[$k].q -and $t -match '^\d*[<>]{1,2}$') { $k += 2; continue }
        if (-not $woerter[$k].q -and $t -match '^\d*[<>]') { $k++; continue }
        $rein += $woerter[$k]
        $k++
    }
    return ,$rein
}

function Test-Push([string]$dir, $argumente, $erlaubt) {
    if (-not $dir -or -not (Test-Path -LiteralPath $dir -PathType Container)) { Write-Deny $unklarGrund }
    $topRoh = Get-GitWert $dir @('rev-parse', '--show-toplevel')
    if (-not $topRoh) { return }
    $top = Resolve-Pfad $topRoh $null
    if (-not $top) { Write-Deny $unklarGrund }
    foreach ($e in $erlaubt) { if (Test-Gleich $top $e) { return } }

    $pos = @()
    $j = 0
    while ($j -lt $argumente.Count) {
        $a = [string]$argumente[$j].t
        if ($a -match '[\$`]') { Write-Deny $unklarGrund }
        if ($a -in @('--all', '--mirror', '--branches')) { Write-Deny $unklarGrund }
        if ($a -in @('-o', '--push-option', '--repo', '--receive-pack', '--exec')) { $j += 2; continue }
        if ($a.StartsWith('-')) { $j++; continue }
        $pos += $a
        $j++
    }
    $aktZweig = Get-GitWert $top @('symbolic-ref', '--quiet', '--short', 'HEAD')
    $remote = 'origin'
    if ($pos.Count -gt 0) { $remote = $pos[0] }
    elseif ($aktZweig) {
        $r = Get-GitWert $top @('config', '--get', ('branch.' + $aktZweig + '.remote'))
        if ($r) { $remote = $r }
    }
    $schutz = @('main', 'master')
    $sym = Get-GitWert $top @('symbolic-ref', '--quiet', '--short', ('refs/remotes/' + $remote + '/HEAD'))
    if ($sym -and $sym.Contains('/')) { $schutz += $sym.Substring($sym.IndexOf('/') + 1) }

    $ziele = @()
    if ($pos.Count -le 1) {
        if ((Get-GitWert $top @('config', '--get', 'push.default')) -eq 'matching') { Write-Deny $unklarGrund }
        if (-not $aktZweig) { return }
        $ziele += $aktZweig
        $up = Get-GitWert $top @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}')
        if ($up -and $up.Contains('/')) { $ziele += $up.Substring($up.IndexOf('/') + 1) }
    } else {
        foreach ($rs in $pos[1..($pos.Count - 1)]) {
            $s = $rs.TrimStart('+')
            if ($s -eq ':' -or $s.Contains('*')) { Write-Deny $unklarGrund }
            $dst = if ($s.Contains(':')) { $s.Substring($s.IndexOf(':') + 1) } else { $s }
            if ($dst -eq '') { continue }
            if ($dst -in @('HEAD', '@')) { $dst = $aktZweig; if (-not $dst) { continue } }
            $dst = $dst -replace '^refs/heads/', ''
            if ($dst -like 'refs/*') { continue }
            $ziele += $dst
        }
    }
    foreach ($z in $ziele) { if ($schutz -contains $z) { Write-Deny (Get-PushGrund $z $top) } }
}

function Test-Befehle([string]$text, [string]$cwd, $erlaubt, [int]$tiefe) {
    if ($tiefe -gt 4) { return }
    foreach ($roh in (Get-Abschnitte $text)) {
        $w = Remove-Umleitungen $roh
        if ($w.Count -eq 0) { continue }
        # Eingebettete Befehle in Anfuehrungszeichen (pwsh -c "...", bash -c '...', cmd /c "...", iex "...") selbst
        # pruefen, aber nur hinter einem solchen Aufruf: Eine Commit-Botschaft (-m "gh pr merge ...") ist kein Befehl.
        for ($x = 0; $x -lt $w.Count; $x++) {
            $t = $w[$x]
            if (-not $t.q -or $t.t -notmatch '(?i)\b(git|gh)\b|gh-[\w-]+\.ps1') { continue }
            $vor = if ($x -gt 0) { ([string]$w[$x - 1].t).ToLower() } else { '' }
            if ($x -eq 0 -or $vor -in @('-c', '-command', '/c', '/k', 'iex', 'invoke-expression', 'eval', 'exec')) { Test-Befehle $t.t $cwd $erlaubt ($tiefe + 1) }
        }
        $k = 0
        while ($k -lt $w.Count -and -not $w[$k].q -and ($w[$k].t -match '^[A-Za-z_][A-Za-z0-9_]*=' -or $w[$k].t -in @('env', 'command', 'time', 'nohup', 'exec', 'sudo'))) { $k++ }
        if ($k -ge $w.Count) { continue }
        $exe = ([string]$w[$k].t) -replace '^.*[\\/]', ''
        $exe = ($exe -replace '(?i)\.exe$', '').ToLower()

        if ($exe -in @('cd', 'chdir', 'pushd', 'set-location', 'sl', 'push-location')) {
            $ziel = $null
            for ($m = $k + 1; $m -lt $w.Count; $m++) {
                if (-not $w[$m].q -and $w[$m].t -match '^-') { continue }
                $ziel = $w[$m].t
                break
            }
            if ($null -eq $ziel) { $cwd = $heim } else { $cwd = Resolve-Pfad $ziel $cwd }
            continue
        }

        if ($exe -eq 'gh' -or $exe -match '^gh-[\w-]+\.ps1$') {
            $rest = @($w | Select-Object -Skip ($k + 1) | ForEach-Object { [string]$_.t })
            for ($m = 0; $m -lt $rest.Count - 1; $m++) {
                if ($rest[$m] -eq 'pr' -and $rest[$m + 1] -eq 'merge') { Write-Deny $mergeGrund }
            }
            if ($rest -contains 'api' -and (($rest -join ' ') -match '(?i)/merge\b|mergePullRequest|enablePullRequestAutoMerge|merge_method')) { Write-Deny $mergeGrund }
            continue
        }

        if ($exe -eq 'git') {
            $dir = $cwd
            $unklar = $false
            $m = $k + 1
            while ($m -lt $w.Count -and ([string]$w[$m].t).StartsWith('-')) {
                $o = [string]$w[$m].t
                if ($o -eq '-C') {
                    $p = if ($m + 1 -lt $w.Count) { [string]$w[$m + 1].t } else { '' }
                    $dir = Resolve-Pfad $p $dir
                    if (-not $dir) { $unklar = $true }
                    $m += 2
                    continue
                }
                if ($o -eq '-c' -or $o -eq '--config-env') { $m += 2; continue }
                if ($o -match '^--(git-dir|work-tree|namespace)') { $unklar = $true }
                $m++
            }
            if ($m -lt $w.Count -and $w[$m].t -eq 'push') {
                if ($unklar) { Write-Deny $unklarGrund }
                Test-Push $dir @($w | Select-Object -Skip ($m + 1)) $erlaubt
            }
        }
    }
}

$cmd = ''
try {
    # Eingabe ausdruecklich als UTF-8 lesen: [Console]::In nimmt die OEM-Codepage, und aus einem Umlaut im Pfad werden zwei falsche Zeichen (Meldung #10).
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding($false)))).ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    $tool = [string]$in.tool_name
    if ($tool -ne "Bash" -and $tool -ne "PowerShell") { exit 0 }
    $cmd = [string]$in.tool_input.command
    if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

    # 1. git [-C <pfad>] [weitere optionen] add [optionen] (-A | --all | .) am Ende oder vor Leerraum.
    # "git" muss an Kommando-Position stehen: am Anfang, nach einem Trenner (; & | Klammer,
    # Zeilenumbruch) oder nach einem oeffnenden Anfuehrungszeichen (pwsh -c "git add -A").
    # Nicht mitten in einem Text: Eine Commit-Botschaft, die "git add -A" erwaehnt, ist kein
    # Kommando (so beim ersten Einsatz des Hooks den eigenen Commit blockiert).
    $muster = '(?im)(?:^|[;&|(\r\n"''`]\s*)git\b(?:\s+-C\s+(?:"[^"]*"|''[^'']*''|\S+))?(?:\s+-\S+)*\s+add\b[^\r\n;&|"'']*?(?:\s|^)(?:-A|--all|\.)(?=\s|$|[;&|"''])'
    if ($cmd -match $muster) {
        Write-Deny "Pauschales Stagen ist gesperrt: git add -A, --all und . nehmen den halbfertigen Stand anderer Sessions und die offene Bearbeitung des Besitzers mit (AGENTS.md Abschnitt 12). Nur die eigenen Dateien einzeln stagen: git add -- <datei> <datei>."
    }

    # 2. und 3.: nur pruefen, wenn der Text ueberhaupt danach aussieht (spart die Zerlegung bei jedem Aufruf).
    if ($cmd -notmatch '(?i)\bpush\b' -and $cmd -notmatch '(?i)\bmerge') { exit 0 }
    if (-not $Repo) { $Repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
    $leo = Resolve-Pfad $Repo $null
    $erlaubt = @($leo, (Resolve-Pfad ($leo + ' Archiv') $null))
    $cwd = Resolve-Pfad ([string]$in.cwd) $null
    if (-not $cwd -and $env:CLAUDE_PROJECT_DIR) { $cwd = Resolve-Pfad $env:CLAUDE_PROJECT_DIR $null }
    Test-Befehle $cmd $cwd $erlaubt 0
    exit 0
} catch {
    # Ein eigener Fehler laesst durch, ausser der Befehl will pushen oder mergen: dann wird gesperrt.
    if ($cmd -match '(?i)\bgit\b[\s\S]*\bpush\b' -or $cmd -match '(?i)\bgh\b[\s\S]*\bmerge') {
        Write-Deny ("Die Push- und Merge-Sperre konnte den Befehl nicht pruefen (" + $_.Exception.Message + ") und sperrt deshalb. Schreib den Befehl einfacher, etwa: git -C <Repo-Pfad> push origin <themenzweig>.")
    }
    exit 0
}
