# guard-git.ps1
# Zweck: PreToolUse-Hook fuer Bash und PowerShell mit drei Sperren, unabhaengig vom Berechtigungsmodus:
#   1. Pauschales Stagen: "git add -A", "git add --all", "git add ." (seit 3.3), dazu die Gleichwerte ./, :/, *
#      und "git stage" (seit der Zweitpruefung von 6.0); "git add -u" und "git commit -a" bleiben frei.
#   2. Push auf den Standardzweig eines fremden Repos (seit 6.0); Push auf eine Adresse statt ein Remote, auch
#      im eigenen Repo; subtree push, send-pack, Alias fuer push, GIT_DIR (seit der Zweitpruefung von 6.0).
#   3. Mergen eines Pull Requests: "gh pr merge" und Merge ueber "gh api", in jedem Repo (seit 6.0); schreibende
#      "gh api"-Aufrufe auf Dateien, Zweige und Merges und "gh repo sync" mit Ziel (seit der Zweitpruefung).
#   Seit dem Schlusstest von 6.0 zusaetzlich: git und gh hinter einem Starter ohne Anfuehrungszeichen (cmd /c,
#   powershell -Command, pwsh -File <gh-wrapper.ps1>), ueber Start-Process, eine Variable oder einen kodierten
#   Befehl; Einstellungen, die das Push-Ziel bestimmen (-c, git config, origin umbiegen); im eigenen Repo nur
#   Push auf origin; "--no-dry-run" hebt "--dry-run" auf; "gh alias set". Lesendes "gh api .../merge" ist frei.
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
$unklarGrund = "Push gesperrt, weil die Sperre das Ziel nicht sicher bestimmen kann (Pfad aus einer Variable, --all, --mirror, ':' als Ziel, GIT_DIR oder GIT_WORK_TREE, ein Alias oder ein Ordner, den es nicht gibt). Schreib den Befehl ausdruecklich, etwa: git -C <Repo-Pfad> push origin <themenzweig>."
$adresseGrund = "Push auf eine Adresse oder einen Pfad statt auf ein eingerichtetes Remote ist gesperrt, auch im eigenen Repo: So gelangt Inhalt in ein Repo, dessen Besitzer die Sperre nicht kennt (AGENTS.md Abschnitt 12). Pushe auf ein eingerichtetes Remote (im eigenen Repo origin). Soll ein neues Ziel dazukommen, sag [NAME] in einem Satz, wohin und warum."
$apiGrund = "Schreibender Aufruf ueber gh gesperrt: Er aendert Dateien, Zweige oder Merges eines Repos direkt auf GitHub, am Pull Request vorbei (AGENTS.md Abschnitt 12). Weg: lokal auf einem Themenzweig committen, pushen und einen Pull Request oeffnen; gemergt wird vom Besitzer."
$aliasGrund = "Ein Git-Alias fuer push, subtree oder send-pack ist gesperrt: Die Sperre koennte das Ziel dann nicht mehr sehen (AGENTS.md Abschnitt 12). Schreib den Befehl aus, etwa: git push origin <themenzweig>."
$stageGrund = "Pauschales Stagen ist gesperrt: git add -A, --all, . und ihre Gleichwerte (./, :/, *) nehmen den halbfertigen Stand anderer Sessions und die offene Bearbeitung des Besitzers mit (AGENTS.md Abschnitt 12). Nur die eigenen Dateien einzeln stagen: git add -- <datei> <datei>."
$remoteGrund = "Push im eigenen Repo nur auf origin: Ein anderes oder neu angelegtes Remote waere ein Push auf eine Adresse in zwei Schritten (AGENTS.md Abschnitt 12). Pushe mit: git push origin <zweig>. Soll ein neues Ziel dazukommen, sag [NAME] in einem Satz, wohin und warum."
$konfigGrund = "Gesperrt: Die Einstellung legt fest, wohin gepusht wird (origin umbiegen, Push-Regeln, push.default, url.*.insteadOf, Push-Remote eines Zweigs), und wuerde die Push-Sperre am Ziel vorbeifuehren (AGENTS.md Abschnitt 12). Pushe ausdruecklich, etwa: git push origin <themenzweig>. Muss die Einstellung wirklich geaendert werden, sag [NAME] in einem Satz, welche und warum; er setzt sie selbst."
$startGrund = "Gesperrt: git oder gh ueber Start-Process, eine Variable oder einen kodierten Befehl kann die Push- und Merge-Sperre nicht pruefen (AGENTS.md Abschnitt 12). Ruf git oder gh direkt auf, etwa: git push origin <themenzweig>."
$ghAliasGrund = "Gesperrt: Ein gh-Alias versteckt den eigentlichen Befehl vor der Merge-Sperre (AGENTS.md Abschnitt 12). Schreib den gh-Befehl aus."
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

# Eigen ist ein Repo aus der Liste; das Belegarchiv nur ohne Remote (vierte Pruefung von 6.0: ein fremdes Repo, das
# unter dem Namen "<Repo> Archiv" geklont wurde, galt sonst als eigen). Das erste Element ist das eigene Repo.
function Test-Eigen([string]$top, $erlaubt) {
    for ($i = 0; $i -lt @($erlaubt).Count; $i++) {
        if (-not (Test-Gleich $top $erlaubt[$i])) { continue }
        if ($i -eq 1 -and (Get-GitWert $top @('remote'))) { return $false }
        return $true
    }
    return $false
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

# Ein Push-Ziel, das kein eingerichtetes Remote ist: Adresse (https://, ssh://, git@host:), Pfad oder .git-Datei.
function Test-Adresse([string]$s) {
    if (-not $s -or $s -eq '.') { return $false }
    return ($s -match '://' -or $s -match '^[^\s/\\@]+@[^\s:]+:' -or $s -match '[\\/]' -or $s -match '(?i)\.git$')
}

function Test-Push([string]$dir, $argumente, $erlaubt) {
    if ($script:gitUmgebung) { Write-Deny $unklarGrund }
    if (-not $dir -or -not (Test-Path -LiteralPath $dir -PathType Container)) { Write-Deny $unklarGrund }
    $topRoh = Get-GitWert $dir @('rev-parse', '--show-toplevel')
    if (-not $topRoh) { return }
    $top = Resolve-Pfad $topRoh $null
    if (-not $top) { Write-Deny $unklarGrund }
    $eigen = Test-Eigen $top $erlaubt

    # Im eigenen Repo ist jeder Push frei, ausser auf eine Adresse; in einem fremden gilt die volle Pruefung.
    $pos = @()
    $ziel = ''
    $trocken = $false
    $j = 0
    while ($j -lt $argumente.Count) {
        $a = [string]$argumente[$j].t
        # Die letzte Angabe gilt: "--dry-run --no-dry-run" pusht wirklich (seit dem Schlusstest von 6.0).
        if ($a -in @('--dry-run', '-n')) { $trocken = $true; $j++; continue }
        if ($a -eq '--no-dry-run') { $trocken = $false; $j++; continue }
        if ($a -match '^--repo=(.*)$') { $ziel = $matches[1]; $j++; continue }
        if ($a -eq '--repo') { if ($j + 1 -lt $argumente.Count) { $ziel = [string]$argumente[$j + 1].t }; $j += 2; continue }
        if (-not $eigen) {
            if ($a -match '[\$`]') { Write-Deny $unklarGrund }
            if ($a -in @('--all', '--mirror', '--branches')) { Write-Deny $unklarGrund }
        }
        if ($a -in @('-o', '--push-option', '--receive-pack', '--exec', '-P', '--prefix', '-m', '--message')) { $j += 2; continue }
        if ($a.StartsWith('-')) { $j++; continue }
        $pos += $a
        $j++
    }
    if ($trocken) { return }
    # Ein Repository auf der Befehlszeile geht --repo vor (wie bei git selbst).
    if ($pos.Count -gt 0) { $ziel = $pos[0] }
    if (Test-Adresse $ziel) { Write-Deny $adresseGrund }
    $aktZweig = Get-GitWert $top @('symbolic-ref', '--quiet', '--short', 'HEAD')
    $remote = $ziel
    if (-not $remote -and $aktZweig) {
        foreach ($schl in @(('branch.' + $aktZweig + '.pushremote'), 'remote.pushdefault', ('branch.' + $aktZweig + '.remote'))) {
            $r = Get-GitWert $top @('config', '--get', $schl)
            if ($r) { $remote = $r; break }
        }
    }
    if (-not $remote) { $remote = 'origin' }
    # Im eigenen Repo nur auf origin (seit dem Schlusstest von 6.0): Ein neu angelegtes Remote ("git remote add x
    # <adresse>") waere sonst ein Push auf eine Adresse in zwei Schritten.
    if ($eigen) {
        if ($remote -cne 'origin') { Write-Deny $remoteGrund }
        return
    }
    # Wechselt ein frueherer Abschnitt desselben Befehls den Zweig (git switch main && git push), gilt der
    # aktuelle Zweig beim Pruefen nicht mehr (vierte Pruefung von 6.0): ein implizites Ziel ist dann unklar.
    if ($script:zweigGewechselt) {
        if ($pos.Count -le 1) { Write-Deny $unklarGrund }
        foreach ($rs in $pos[1..($pos.Count - 1)]) { if ($rs -match '(^|[+:])(HEAD|@)(:|$)') { Write-Deny $unklarGrund } }
    }
    $schutz = @('main', 'master')
    $sym = Get-GitWert $top @('symbolic-ref', '--quiet', '--short', ('refs/remotes/' + $remote + '/HEAD'))
    if ($sym -and $sym.Contains('/')) { $schutz += $sym.Substring($sym.IndexOf('/') + 1) }

    $ziele = @()
    if ($pos.Count -le 1) {
        if ((Get-GitWert $top @('config', '--get', 'push.default')) -eq 'matching') { Write-Deny $unklarGrund }
        # Eingetragene Push-Regeln des Remotes bestimmen das Ziel selbst (remote.<name>.push, mirror); im Zweifel gesperrt.
        if (Get-GitWert $top @('config', '--get-all', ('remote.' + $remote + '.push'))) { Write-Deny $unklarGrund }
        if ((Get-GitWert $top @('config', '--get', ('remote.' + $remote + '.mirror'))) -eq 'true') { Write-Deny $unklarGrund }
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
            # "heads/main" loest git wie refs/heads/main auf (vierte Pruefung von 6.0).
            $dst = $dst -creplace '^(refs/)?heads/', ''
            if ($dst -like 'refs/*') { continue }
            $ziele += $dst
        }
    }
    foreach ($z in $ziele) { if ($schutz -contains $z) { Write-Deny (Get-PushGrund $z $top) } }
}

# gh api: schreibende Aufrufe auf Inhalte, Zweige und Merges eines Repos (Commit am Pull Request vorbei).
# Methode aus -X/--method; ohne Angabe macht ein Feld (-f, -F, --field, --raw-field, --input) einen POST.
function Test-GhApi($rest) {
    $methode = ''
    $feld = $false
    $ziel = ''
    $text = ($rest -join ' ')
    for ($m = 0; $m -lt $rest.Count; $m++) {
        $a = [string]$rest[$m]
        if ($a -cmatch '^-X(.+)$') { $methode = $matches[1]; continue }
        if ($a -match '^--method=(.+)$') { $methode = $matches[1]; continue }
        if ($a -in @('-X', '--method')) { if ($m + 1 -lt $rest.Count) { $methode = [string]$rest[$m + 1] }; $m++; continue }
        if ($a -cin @('-f', '-F', '--field', '--raw-field', '--input')) { $feld = $true; $m++; continue }
        # Angehaengter Wert (-fbase=main, -Fquery=@q): ebenfalls ein Feld, also POST (vierte Pruefung von 6.0).
        if ($a -cmatch '^-[fF].') { $feld = $true; continue }
        if ($a -match '^--(field|raw-field|input)=') { $feld = $true; continue }
        if ($a -cin @('-H', '--header', '-q', '--jq', '-t', '--template', '--hostname', '--cache', '-p', '--preview')) { $m++; continue }
        if ($a.StartsWith('-')) { continue }
        if (-not $ziel) { $ziel = $a }
    }
    if (-not $methode) { $methode = if ($feld) { 'POST' } else { 'GET' } }
    # Volle Adresse und Varianten auf den Pfad zurueckfuehren (https://api.github.com/graphql, graphql/, /repositories/<id>).
    $ziel = (($ziel -replace '(?i)^https?://[^/]+(/api/v3)?', '') -replace '(?i)(^|/)repositories/\d+/', '$1repos/x/x/').Trim('/')
    if ($ziel -match '(?i)^graphql$') {
        if ($text -match '(?i)\b(mergeBranch|mergePullRequest|enablePullRequestAutoMerge|enqueuePullRequest|updatePullRequestBranch)\b') { Write-Deny $mergeGrund }
        if ($text -match '(?i)\b(createCommitOnBranch|updateRefs?|createRef|deleteRef|updateBranchProtectionRule|deleteBranchProtectionRule|updateRepository|deleteRepository)\b') { Write-Deny $apiGrund }
        if ($text -match '(?i)(^|\s)(-F|--field)\s*\S*=@|(^|\s)-F[^\s=]*=@|(^|\s)--input\b') { Write-Deny $apiGrund }
    }
    # Lesen bleibt frei, auch auf .../merge (GET prueft nur, ob gemergt ist; seit dem Schlusstest von 6.0).
    if ($methode.ToUpper() -eq 'GET' -or $methode.ToUpper() -eq 'HEAD') { return }
    if ($ziel -match '(?i)(^|/)repos/[^/]+/[^/]+/(merges\b|merge-upstream\b|pulls/\d+/merge\b)' -or $text -match '(?i)\bmerge_method\b') { Write-Deny $mergeGrund }
    if ($ziel -match '(?i)(^|/)repos/[^/]+/[^/]+/(contents(/|$)|git/(refs|commits|trees|blobs|tags)\b|branches/[^/]+/(rename|protection)\b|rulesets\b)') { Write-Deny $apiGrund }
    # Das Repo selbst aendern oder loeschen (Standardzweig umstellen, loeschen): seit der vierten Pruefung von 6.0.
    if ($ziel -match '(?i)(^|/)repos/[^/]+/[^/]+$' -and $methode.ToUpper() -in @('PATCH', 'DELETE', 'PUT')) { Write-Deny $apiGrund }
    if ($ziel -match '(?i)^/?graphql$') {
        if ($text -match '(?i)\b(mergeBranch|mergePullRequest|enablePullRequestAutoMerge)\b') { Write-Deny $mergeGrund }
        if ($text -match '(?i)\b(createCommitOnBranch|updateRefs?|createRef|deleteRef)\b') { Write-Deny $apiGrund }
        # Abfrage aus einer Datei (-F query=@datei, --input): unsichtbar, also im Zweifel gesperrt.
        if ($text -match '(?i)(^|\s)(-F|--field)\s*\S*=@|(^|\s)--input\b') { Write-Deny $apiGrund }
    }
}

# Name eines Programms aus einem Wort: ohne Pfad und ohne .exe, klein.
function Get-WortName([string]$t) {
    return ((($t -replace '^.*[\\/]', '') -replace '(?i)\.exe$', '')).ToLower()
}

# git config: schreibende Aufrufe auf Schluessel, die das Push-Ziel bestimmen. Lesen bleibt frei.
# Seit der vierten Pruefung von 6.0: push.default statt jeder push.*-Schluessel (push.autoSetupRemote und
# push.followTags bestimmen kein fremdes Ziel), dazu include.path (eine eingebundene Datei kann alles setzen) und
# followRemoteHEAD (ohne refs/remotes/<remote>/HEAD kennt die Sperre den Standardzweig nicht).
$konfigSchluessel = '(?i)^(remote\.[^=\s]+\.(url|pushurl|push|mirror|followremotehead)|remote\.pushdefault|push\.default|branch\.[^=\s]+\.(pushremote|remote)|url\..+\.(insteadof|pushinsteadof)|include\.path|includeif\..+\.path)$'
function Test-GitConfig($nach) {
    $woerter = @($nach | ForEach-Object { [string]$_.t })
    $pos = @()
    $schreibt = $false
    $liest = $false
    for ($m = 0; $m -lt $woerter.Count; $m++) {
        $a = $woerter[$m]
        if ($a -in @('--get', '--get-all', '--get-regexp', '--get-urlmatch', '--list', '-l', '--get-color', '--get-colorbool')) { $liest = $true; continue }
        if ($a -in @('--add', '--replace-all', '--unset', '--unset-all', '--rename-section', '--remove-section', '-e', '--edit')) { $schreibt = $true; continue }
        if ($a -in @('-f', '--file', '--blob', '--type', '--default', '--comment', '--value')) { $m++; continue }
        if ($a.StartsWith('-')) { continue }
        $pos += $a
    }
    if ($pos.Count -gt 0 -and $pos[0] -in @('get', 'list')) { return }
    if ($pos.Count -gt 0 -and $pos[0] -in @('set', 'unset', 'rename-section', 'remove-section', 'edit')) { $schreibt = $true; $pos = @($pos | Select-Object -Skip 1) }
    if ($liest -and -not $schreibt) { return }
    if (-not $schreibt -and $pos.Count -lt 2) { return }
    foreach ($p in $pos) {
        if ($p -match $konfigSchluessel) { Write-Deny $konfigGrund }
        if ($p -match '(?i)^(remote|url|branch|push)(\.|$)' -and ($woerter -contains '--rename-section' -or $woerter -contains '--remove-section' -or $woerter -contains 'rename-section' -or $woerter -contains 'remove-section')) { Write-Deny $konfigGrund }
    }
    if ($woerter -contains '-e' -or $woerter -contains '--edit' -or $woerter -contains 'edit') { Write-Deny $konfigGrund }
}

# git remote im eigenen Repo: origin darf nicht umgebogen, umbenannt oder ersetzt werden (seit dem Schlusstest
# von 6.0). Ein anderes Remote anlegen bleibt frei, gepusht wird im eigenen Repo nur auf origin.
function Test-GitRemote([string]$dir, $nach, $erlaubt) {
    $woerter = @($nach | ForEach-Object { [string]$_.t } | Where-Object { -not $_.StartsWith('-') })
    if ($woerter.Count -lt 2) { return }
    if (-not $dir -or -not (Test-Path -LiteralPath $dir -PathType Container)) { return }
    $topRoh = Get-GitWert $dir @('rev-parse', '--show-toplevel')
    if (-not $topRoh) { return }
    $top = Resolve-Pfad $topRoh $null
    $eigen = Test-Eigen $top $erlaubt
    $aktion = $woerter[0]
    # In einem fremden Repo bestimmt refs/remotes/<remote>/HEAD, welcher Zweig geschuetzt ist (vierte Pruefung von 6.0).
    if (-not $eigen) { if ($aktion -eq 'set-head') { Write-Deny $konfigGrund }; return }
    $name = $woerter[1]
    $originDa = [bool](Get-GitWert $top @('config', '--get', 'remote.origin.url'))
    switch ($aktion) {
        'add' { if ($name -ceq 'origin' -and $originDa) { Write-Deny $konfigGrund } }
        'set-url' { if ($name -ceq 'origin' -and -not ($woerter.Count -ge 3 -and $woerter[2] -ceq 'DISABLED')) { Write-Deny $konfigGrund } }
        { $_ -in @('rename', 'remove', 'rm') } { if ($woerter -ccontains 'origin') { Write-Deny $konfigGrund } }
    }
}

# Pauschales Stagen ueber die Argumente von git add/stage: -A, --all, . und Gleichwerte; ein Buendel mit A.
# git add -u und git commit -a bleiben bewusst frei (nicht freigegeben, AGENTS.md Abschnitt 12).
function Test-Pauschal($argumente) {
    foreach ($w in $argumente) {
        $a = [string]$w.t
        if ($a -cin @('-A', '--all', '.', './', '.\', '*', ':/', ':/:', ':')) { return $true }
        if (-not $w.q -and $a -cmatch '^-[a-zA-Z]*A[a-zA-Z]*$') { return $true }
    }
    return $false
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
            # Dazu eine Shell, die von stdin liest (bash <<< "git push ...", echo "git push ..." | bash): seit der vierten Pruefung von 6.0.
            if ($x -eq 0 -or $vor -in @('-c', '-command', '/c', '/k', 'iex', 'invoke-expression', 'eval', 'exec') -or $vor -match '^-[a-z]+c$') { Test-Befehle $t.t $cwd $erlaubt ($tiefe + 1) }
            elseif ($script:shellLiest -and $vor -notin @('-m', '--message', '-f', '--file', '--body', '-b', '--title', '-t', '--notes')) { Test-Befehle $t.t $cwd $erlaubt ($tiefe + 1) }
        }
        $k = 0
        # Vorsilben samt ihren Schaltern und Zahlen (env -i, nice -n 10, time -p, command -p; vierte Pruefung von 6.0).
        $vorsilben = @('env', 'command', 'time', 'nohup', 'exec', 'sudo', '.', 'eval', 'builtin', 'nice', 'ionice', 'stdbuf', 'unbuffer', 'winpty', 'chrt', 'taskset')
        while ($k -lt $w.Count -and -not $w[$k].q -and ($w[$k].t -match '^[A-Za-z_][A-Za-z0-9_]*=' -or $w[$k].t -in $vorsilben)) {
            $k++
            while ($k -lt $w.Count -and -not $w[$k].q -and ($w[$k].t -match '^-' -or $w[$k].t -match '^\d+$')) { $k++ }
        }
        if ($k -ge $w.Count) { continue }
        $exe = Get-WortName ([string]$w[$k].t)
        $abschnittText = (@($w | Select-Object -Skip $k | ForEach-Object { [string]$_.t }) -join ' ')

        # Programm aus einer Variable (& $g pr merge 1): nicht pruefbar, also im Zweifel gesperrt (seit dem Schlusstest von 6.0).
        if (([string]$w[$k].t) -match '^\$' -and $abschnittText -match '(?i)\b(push|merge)\b') { Write-Deny $startGrund }

        # Starter ohne Anfuehrungszeichen (cmd /c gh pr merge 1, powershell -Command gh ..., pwsh -File ...\gh-x.ps1 pr
        # merge, Start-Process gh ...): Der Rest ab dem ersten Wort, das git, gh oder ein gh-Wrapper ist, wird selbst
        # als Befehl geprueft (seit dem Schlusstest von 6.0). Start-Process mit git oder gh ist bei einem Stichwort
        # der Sperren gesperrt, weil seine Argumentliste (Kommas, ein einzelner Text) nicht sicher lesbar ist.
        $starter = @('cmd', 'pwsh', 'powershell', 'bash', 'sh', 'zsh', 'dash', 'wsl', 'start-process', 'saps', 'start', 'iex', 'invoke-expression', 'call', 'xargs', 'timeout', 'runas', 'invoke-command', 'icm')
        if ($exe -eq 'xargs' -and $abschnittText -match '(?i)\b(git|gh)\b' -and $abschnittText -match '(?i)\b(push|merge)\b') { Write-Deny $startGrund }
        if ($exe -in $starter) {
            if ($exe -in @('pwsh', 'powershell')) {
                for ($m = $k + 1; $m -lt $w.Count - 1; $m++) {
                    $o = ([string]$w[$m].t).ToLower()
                    if ($o -match '^-(e|ec|en[a-z]*)$' -and ($o -in @('-e', '-ec') -or 'encodedcommand'.StartsWith($o.Substring(1)))) {
                        $dekodiert = $null
                        try { $dekodiert = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String([string]$w[$m + 1].t)) } catch { $dekodiert = $null }
                        if ($null -eq $dekodiert) { Write-Deny $startGrund }
                        Test-Befehle $dekodiert $cwd $erlaubt ($tiefe + 1)
                    }
                }
            }
            for ($m = $k + 1; $m -lt $w.Count; $m++) {
                $name = Get-WortName ([string]$w[$m].t)
                if ($name -in @('git', 'gh') -or $name -match '^gh-[\w-]+\.ps1$') {
                    if ($exe -in @('start-process', 'saps', 'start')) {
                        if ($abschnittText -match '(?i)\b(push|merge|merges|api|alias|sync|config|remote|add|stage|subtree|send-pack|http-push)\b') { Write-Deny $startGrund }
                    } else {
                        $teil = @($w | Select-Object -Skip $m | ForEach-Object {
                            $t = [string]$_.t
                            if (-not $_.q) { $t } elseif ($t.Contains('"')) { "'" + $t + "'" } else { '"' + $t + '"' }
                        }) -join ' '
                        Test-Befehle $teil $cwd $erlaubt ($tiefe + 1)
                    }
                    break
                }
            }
        }

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
            # Befehlswoerter ohne Schalter: "gh pr -R o/r merge 1" ist gh pr merge (vierte Pruefung von 6.0).
            $wortFolge = @()
            for ($m = 0; $m -lt $rest.Count; $m++) {
                if ($rest[$m] -cin @('-R', '--repo', '--hostname')) { $m++; continue }
                if ($rest[$m].StartsWith('-')) { continue }
                $wortFolge += $rest[$m]
            }
            if ($wortFolge.Count -ge 2 -and $wortFolge[0] -eq 'pr' -and $wortFolge[1] -eq 'merge') { Write-Deny $mergeGrund }
            if ($wortFolge.Count -ge 2 -and $wortFolge[0] -eq 'repo' -and $wortFolge[1] -in @('delete', 'rename', 'edit', 'archive')) { Write-Deny $apiGrund }
            if ($wortFolge.Count -ge 2 -and $wortFolge[0] -eq 'alias' -and $wortFolge[1] -in @('set', 'import')) { Write-Deny $ghAliasGrund }
            for ($m = 0; $m -lt $rest.Count - 1; $m++) {
                if ($rest[$m] -eq 'pr' -and $rest[$m + 1] -eq 'merge') { Write-Deny $mergeGrund }
                if ($rest[$m] -eq 'alias' -and $rest[$m + 1] -in @('set', 'import')) { Write-Deny $ghAliasGrund }
            }
            # gh api: nur der schreibende Aufruf zaehlt (Test-GhApi); vor "api" stehen hoechstens Optionen.
            $apiAt = [array]::IndexOf([string[]]$rest, 'api')
            if ($apiAt -ge 0 -and -not (@($rest | Select-Object -First $apiAt) | Where-Object { -not $_.StartsWith('-') })) { Test-GhApi @($rest | Select-Object -Skip ($apiAt + 1)) }
            if ($rest.Count -ge 2 -and $rest[0] -eq 'repo' -and $rest[1] -eq 'sync') {
                # Mit einem Repo als Argument schreibt gh repo sync auf dessen Standardzweig; ohne Argument holt es nur.
                $wo = @($rest | Select-Object -Skip 2)
                for ($m = 0; $m -lt $wo.Count; $m++) {
                    if ($wo[$m] -in @('-b', '--branch', '-s', '--source')) { $m++; continue }
                    if (-not $wo[$m].StartsWith('-')) { Write-Deny $apiGrund }
                }
            }
            continue
        }

        if ($exe -eq 'git') {
            $dir = $cwd
            $unklar = $false
            $pushKonfig = $false
            $m = $k + 1
            while ($m -lt $w.Count -and ([string]$w[$m].t).StartsWith('-')) {
                $o = [string]$w[$m].t
                if ($o -ceq '-C') {
                    $p = if ($m + 1 -lt $w.Count) { [string]$w[$m + 1].t } else { '' }
                    $dir = Resolve-Pfad $p $dir
                    if (-not $dir) { $unklar = $true }
                    $m += 2
                    continue
                }
                if ($o -ceq '-c' -or $o -eq '--config-env' -or $o -match '^--config-env=') {
                    $wert = if ($o -match '^--config-env=(.*)$') { $matches[1] } elseif ($m + 1 -lt $w.Count) { [string]$w[$m + 1].t } else { '' }
                    if ($wert -match '(?i)^alias\.' -and $wert -match '(?i)\b(push|subtree|send-pack)\b') { Write-Deny $aliasGrund }
                    # Einstellungen, die das Push-Ziel bestimmen (seit dem Schlusstest von 6.0): push.default=matching,
                    # remote.<name>.push, url.*.pushInsteadOf und Verwandte; gesperrt, sobald damit gepusht wird.
                    if ($wert -match '(?i)^(push\.default|remote\.|branch\.[^=]*\.(remote|pushremote|merge)\b|url\.|include\.|includeif\.)') { $pushKonfig = $true }
                    $m += $(if ($o -match '^--config-env=') { 1 } else { 2 })
                    continue
                }
                if ($o -match '^--(git-dir|work-tree|namespace)') { $unklar = $true }
                $m++
            }
            if ($m -ge $w.Count) { continue }
            $sub = [string]$w[$m].t
            $nach = @($w | Select-Object -Skip ($m + 1))
            if ($sub -eq 'push') {
                if ($unklar -or $pushKonfig) { Write-Deny $unklarGrund }
                Test-Push $dir $nach $erlaubt
            } elseif ($sub -eq 'subtree' -and $nach.Count -gt 0 -and [string]$nach[0].t -eq 'push') {
                if ($unklar -or $pushKonfig) { Write-Deny $unklarGrund }
                Test-Push $dir @($nach | Select-Object -Skip 1) $erlaubt
            } elseif ($sub -eq 'remote') {
                Test-GitRemote $dir $nach $erlaubt
            } elseif ($sub -in @('checkout', 'switch', 'branch', 'symbolic-ref', 'update-ref', 'worktree', 'reset', 'rebase', 'pull', 'stash')) {
                $script:zweigGewechselt = $true
                if ($sub -eq 'update-ref' -and (($nach | ForEach-Object { [string]$_.t }) -join ' ') -match '(?i)refs/(tags|replace)/') { Write-Deny $versionGrund }
            } elseif ($sub -eq 'replace') {
                Write-Deny $versionGrund
            } elseif ($sub -eq 'tag' -and (($nach | ForEach-Object { [string]$_.t }) -join ' ') -cmatch '(^|\s)(-f|--force|-d|--delete)(\s|$)') {
                Write-Deny $versionGrund
            } elseif ($sub -in @('send-pack', 'http-push')) {
                Write-Deny $unklarGrund
            } elseif ($sub -in @('add', 'stage')) {
                if (Test-Pauschal $nach) { Write-Deny $stageGrund }
            } elseif ($sub -eq 'config') {
                $woerter = @($nach | ForEach-Object { [string]$_.t })
                if (($woerter -join ' ') -match '(?i)\balias\.' -and ($woerter -join ' ') -match '(?i)\b(push|subtree|send-pack)\b') { Write-Deny $aliasGrund }
                Test-GitConfig $nach
            }
        }
    }
}

$versionGrund = "Gesperrt: git replace, das Ueberschreiben oder Loeschen eines Tags und update-ref auf Tags aendern, welchen Stand ein Versions-Tag zeigt; davon haengt ab, welche Sperren aus dem geprueften Stand kommen (vierte Pruefung von 6.0). Einen neuen Tag anlegen bleibt frei."
$script:zweigGewechselt = $false
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
    # Gegen den zitierten Text einer Commit-Botschaft schuetzt die Zerlegung unten: Hier wird nur der Text
    # ausserhalb von Anfuehrungszeichen geprueft (eine Botschaft mit einer Zeile "git add -A" ist kein Befehl);
    # ein zitierter Befehl hinter pwsh -c, bash -lc, cmd /c oder iex wird in der Zerlegung selbst geprueft.
    $ohneZitate = ($cmd -replace '"[^"]*"', '""') -replace "'[^']*'", "''"
    $muster = '(?im)(?:^|[;&|(\r\n`]\s*)git\b(?:\s+-C\s+(?:"[^"]*"|''[^'']*''|\S+))?(?:\s+-\S+)*\s+(?:add|stage)\b[^\r\n;&|"'']*?(?:\s|^)(?:-A|--all|\.|\./|\.\\|:/|:/:|\*)(?=\s|$|[;&|"''])'
    if ($ohneZitate -match $muster) { Write-Deny $stageGrund }

    # 2. und 3. und die Gleichwerte des Stagens: nur zerlegen, wenn der Text danach aussieht (spart Zeit bei jedem Aufruf).
    if ($cmd -notmatch '(?i)\b(push|merge|merges|add|stage|subtree|send-pack|http-push|sync|alias|api|config|remote|replace|tag|update-ref|repo)\b' -and $cmd -notmatch '(?i)\s-e[a-z]*\s+[A-Za-z0-9+/=]{16,}') { exit 0 }
    # Nur ausserhalb von Zitaten: Eine Commit-Botschaft, die GIT_DIR erwaehnt, setzt nichts (vierte Pruefung von 6.0).
    $script:gitUmgebung = ($ohneZitate -match '(?i)\bGIT_(DIR|WORK_TREE|COMMON_DIR|CONFIG\w*|NO_REPLACE\w*)\b')
    $script:shellLiest = ($ohneZitate -match '(?i)(<<<|\|\s*(bash|sh|zsh|dash|pwsh|powershell|cmd|iex|invoke-expression)(\.exe)?\b)')
    # gh ersetzt {owner}, {repo} und {branch} selbst; die Klammern sind kein Trenner (vierte Pruefung von 6.0).
    $cmd = $cmd -replace '\{(owner|repo|branch)\}', 'x'
    if (-not $Repo) { $Repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
    $leo = Resolve-Pfad $Repo $null
    $erlaubt = @($leo, (Resolve-Pfad ($leo + ' Archiv') $null))
    $cwd = Resolve-Pfad ([string]$in.cwd) $null
    if (-not $cwd -and $env:CLAUDE_PROJECT_DIR) { $cwd = Resolve-Pfad $env:CLAUDE_PROJECT_DIR $null }
    Test-Befehle $cmd $cwd $erlaubt 0
    exit 0
} catch {
    # Ein eigener Fehler laesst durch, ausser der Befehl will pushen oder mergen: dann wird gesperrt.
    # Kaputte Eingabe (vierte Pruefung von 6.0): ist der Befehl noch nicht gelesen, zaehlt der Rohtext.
    if (-not $cmd -and $raw) { $cmd = [string]$raw }
    if ($cmd -match '(?i)\bgit\b[\s\S]*\bpush\b' -or $cmd -match '(?i)\bgh\b[\s\S]*\bmerge') {
        Write-Deny ("Die Push- und Merge-Sperre konnte den Befehl nicht pruefen (" + $_.Exception.Message + ") und sperrt deshalb. Schreib den Befehl einfacher, etwa: git -C <Repo-Pfad> push origin <themenzweig>.")
    }
    exit 0
}
