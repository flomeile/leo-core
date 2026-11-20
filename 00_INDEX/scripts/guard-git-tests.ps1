# guard-git-tests.ps1
# Zweck: Regressionsreihe fuer guard-git.ps1: pauschales Stagen (seit 3.3), Push auf den Standardzweig
# fremder Repos und Mergen (seit 6.0).
#
# PFLICHT: Wer den Hook aendert, faehrt diese Reihe vorher und nachher, unter pwsh und mit
# -Exe powershell. Eine Sperre ohne Testfall zaehlt nicht (AGENTS.md, Abschnitt 18).
#
# WIE: Die Reihe baut Wegwerf-Repos mit einem lokalen Ersatz fuer GitHub (Bare-Repos) in einem Ordner im
# Temp-Verzeichnis und ruft den Hook mit JSON auf stdin auf, so wie das Werkzeug es tut. Es wird nichts
# ausserhalb dieses Ordners geschrieben und nichts gepusht, ausser in die eigenen Bare-Repos beim Aufbau.
#
# AUFRUF:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File "<Repo>\00_INDEX\scripts\guard-git-tests.ps1"
#   ... -Exe powershell      Hook unter Windows PowerShell 5.1
#   ... -Skript <pfad>       gegen eine Arbeitskopie des Hooks
# Bewusst ASCII-only: laeuft unter Windows PowerShell 5.1 genauso wie unter PowerShell 7.
param(
    [string]$Skript = (Join-Path $PSScriptRoot 'guard-git.ps1'),
    [string]$Exe = ''
)
$ErrorActionPreference = 'Stop'
$isWindowsHost = [System.IO.Path]::DirectorySeparatorChar -eq '\'
$psExe = if ($Exe) { (Get-Command $Exe -ErrorAction SilentlyContinue).Source } else { (Get-Command $(if ($isWindowsHost) { 'pwsh.exe' } else { 'pwsh' }) -ErrorAction SilentlyContinue).Source }
if (-not $psExe -and $isWindowsHost) { $psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source }
if (-not $psExe) { 'Kein passender PowerShell-Interpreter gefunden.'; exit 1 }
$utf8 = New-Object System.Text.UTF8Encoding($false)

$b = Join-Path ([System.IO.Path]::GetTempPath().TrimEnd('\', '/')) ('guard-git-tests-' + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $b | Out-Null
function G { param([Parameter(ValueFromRemainingArguments)]$a) $alt = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; & git @a 2>&1 | Out-Null; $ErrorActionPreference = $alt }
function P([string[]]$teile) { $p = $b; foreach ($t in $teile) { $p = Join-Path $p $t }; return $p }

foreach ($r in @(@{ n = 'remote.git'; z = 'main' }, @{ n = 'remote-trunk.git'; z = 'trunk' })) {
    G init -q --bare -b $r.z (P @($r.n))
    $seed = P @('seed-' + $r.z)
    G init -q -b $r.z $seed
    G -C $seed -c user.email=t@example.org -c user.name=t commit -q --allow-empty -m start
    G -C $seed remote add origin (P @($r.n))
    G -C $seed push -q origin ($r.z)
    G -C $seed push -q origin ($r.z + ':feature/x')
}
$remote = P @('remote.git')
$fremd = P @('fremd')
$fremdFeature = P @('fremd-feature')
$trunk = P @('fremd-trunk')
$kind = P @('Mein Agent')
$archiv = P @('Mein Agent Archiv')
$nested = Join-Path (Join-Path $kind '20_Team') 'geteiltes repo'
$leer = P @('leer')
G clone -q $remote $fremd
G clone -q $remote $fremdFeature
G -C $fremdFeature switch -q -c feature/x --track origin/feature/x
G clone -q (P @('remote-trunk.git')) $trunk
G clone -q $remote $kind
G init -q -b main $archiv
G clone -q $remote $nested
New-Item -ItemType Directory -Force -Path $leer | Out-Null
$fremdPosix = if ($isWindowsHost) { '/' + $fremd.Substring(0, 1).ToLower() + ($fremd.Substring(2) -replace '\\', '/') } else { $fremd }

$faelle = @(
    @{ n = '1 git add -A';                     erw = 'DENY'; cwd = $kind;   cmd = 'git add -A' }
    @{ n = '2 git add --all';                  erw = 'DENY'; cwd = $kind;   cmd = 'git add --all && git commit -m x' }
    @{ n = '3 git add . nach Trenner';         erw = 'DENY'; cwd = $kind;   cmd = 'Set-Location x; git add .' }
    @{ n = '4 git add Datei';                  erw = 'PASS'; cwd = $kind;   cmd = 'git add -- a.md ./b.md' }
    @{ n = '5 Erwaehnung im Commit-Text';      erw = 'PASS'; cwd = $kind;   cmd = 'git commit -m "Regel: kein git add -A mehr"' }
    @{ n = '6 eigenes Repo push main';         erw = 'PASS'; cwd = $kind;   cmd = 'git push origin main' }
    @{ n = '7 eigenes Repo push ohne Ziel';    erw = 'PASS'; cwd = $kind;   cmd = 'git push' }
    @{ n = '8 Archiv push';                    erw = 'PASS'; cwd = $kind;   cmd = "git -C '$archiv' push origin main" }
    @{ n = '9 fremd push origin main';         erw = 'DENY'; cwd = $fremd;  cmd = 'git push origin main' }
    @{ n = '10 fremd push auf main';           erw = 'DENY'; cwd = $fremd;  cmd = 'git push' }
    @{ n = '11 fremd push Themenzweig';        erw = 'PASS'; cwd = $fremdFeature; cmd = 'git push' }
    @{ n = '12 fremd push -u feature';         erw = 'PASS'; cwd = $fremd;  cmd = 'git push -u origin feature/x' }
    @{ n = '13 fremd HEAD:main';               erw = 'DENY'; cwd = $fremdFeature; cmd = 'git push origin HEAD:main' }
    @{ n = '14 fremd x:refs/heads/main';       erw = 'DENY'; cwd = $fremd;  cmd = 'git push origin feature/x:refs/heads/main' }
    @{ n = '15 fremd force +main';             erw = 'DENY'; cwd = $fremd;  cmd = 'git push -f origin +main' }
    @{ n = '16 fremd --delete main';           erw = 'DENY'; cwd = $fremd;  cmd = 'git push origin --delete main' }
    @{ n = '17 fremd --all';                   erw = 'DENY'; cwd = $fremdFeature; cmd = 'git push --all origin' }
    @{ n = '18 fremd Tag';                     erw = 'PASS'; cwd = $fremd;  cmd = 'git push origin v1.0' }
    @{ n = '19 -C fremd aus eigenem Repo';     erw = 'DENY'; cwd = $kind;   cmd = "git -C `"$fremd`" push origin main" }
    @{ n = '20 Bash cd fremd';                 erw = 'DENY'; cwd = $kind;   cmd = "cd $fremdPosix && git push origin main 2>&1 | tail -3" }
    @{ n = '21 PowerShell Set-Location';       erw = 'DENY'; cwd = $kind;   cmd = "Set-Location '$fremd'; git push" }
    @{ n = '22 eingehaengt main';              erw = 'DENY'; cwd = $kind;   cmd = "git -C `"$nested`" push origin main" }
    @{ n = '23 eingehaengt Themenzweig';       erw = 'PASS'; cwd = $kind;   cmd = "git -C `"$nested`" push origin feature/x" }
    @{ n = '24 pwsh -c eingebettet';           erw = 'DENY'; cwd = $kind;   cmd = "pwsh -NoProfile -c `"git -C '$fremd' push origin main`"" }
    @{ n = '25 Pfad aus Variable';             erw = 'DENY'; cwd = $kind;   cmd = 'cd $ziel && git push origin main' }
    @{ n = '26 trunk als Standardzweig';       erw = 'DENY'; cwd = $trunk;  cmd = 'git push origin trunk' }
    @{ n = '27 Ordner fehlt';                  erw = 'DENY'; cwd = $kind;   cmd = "git -C '$(P @('gibtsnicht'))' push origin main" }
    @{ n = '28 kein Git-Repo';                 erw = 'PASS'; cwd = $leer;   cmd = 'git push origin main' }
    @{ n = '29 Doppelpunkt matching';          erw = 'DENY'; cwd = $fremd;  cmd = 'git push origin :' }
    @{ n = '30 gh pr merge';                   erw = 'DENY'; cwd = $fremd;  cmd = 'gh pr merge 5 --squash' }
    @{ n = '31 gh pr merge im eigenen Repo';   erw = 'DENY'; cwd = $kind;   cmd = 'gh pr merge 5 --merge --repo o/r' }
    @{ n = '32 gh api merge';                  erw = 'DENY'; cwd = $kind;   cmd = 'gh api -X PUT repos/o/r/pulls/3/merge' }
    @{ n = '33 gh pr create';                  erw = 'PASS'; cwd = $kind;   cmd = 'gh pr create --base main --head feature/x --title t --body-file x.txt' }
    @{ n = '34 gh pr view';                    erw = 'PASS'; cwd = $kind;   cmd = 'gh pr view 3 --repo o/r' }
    @{ n = '35 Push im Commit-Text';           erw = 'PASS'; cwd = $fremd;  cmd = 'git commit -m "Sperre fuer git push origin main gebaut"' }
    @{ n = '36 -C mit /c-Pfad';                erw = 'DENY'; cwd = $kind;   cmd = "git -C `"$fremdPosix`" push origin main" }
    @{ n = '37 lokaler Merge, fetch';          erw = 'PASS'; cwd = $fremd;  cmd = 'git merge --no-ff feature/x; git fetch origin; git status -sb' }
    @{ n = '38 anderes Werkzeug';              erw = 'PASS'; cwd = $kind;   tool = 'Write'; cmd = '' }
)

function Ruf($fall) {
    $tool = if ($fall.tool) { $fall.tool } else { 'Bash' }
    $ti = if ($tool -eq 'Write') { @{ file_path = (Join-Path $kind 'x.md') } } else { @{ command = $fall.cmd } }
    $json = @{ session_id = 'test'; hook_event_name = 'PreToolUse'; cwd = $fall.cwd; tool_name = $tool; tool_input = $ti } | ConvertTo-Json -Depth 5 -Compress
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Skript`" -Repo `"$kind`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $utf8
    $p = [System.Diagnostics.Process]::Start($psi)
    $bytes = $utf8.GetBytes($json); $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length); $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd() + $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($out -match '"permissionDecision"\s*:\s*"deny"') { return 'DENY' }
    if ([string]::IsNullOrWhiteSpace($out)) { return 'PASS' }
    return 'FEHLER: ' + ($out.Trim() -replace "`r?`n", ' ')
}

"Geprueft wird: $Skript"
"Interpreter:   $psExe"
''
$fehler = 0
'{0,-34} {1,-6} {2,-8} {3}' -f 'Fall', 'Erw.', 'Ist', 'Urteil'
'-' * 62
foreach ($f in $faelle) {
    $ist = Ruf $f
    $ok = if ($ist -eq $f.erw) { 'ok' } else { 'ABWEICHUNG' }
    if ($ist -ne $f.erw) { $fehler++ }
    '{0,-34} {1,-6} {2,-8} {3}' -f $f.n, $f.erw, $ist, $ok
}
Remove-Item -LiteralPath $b -Recurse -Force -ErrorAction SilentlyContinue
''
if ($fehler -eq 0) { "ALLE $($faelle.Count) FAELLE BESTANDEN"; exit 0 }
"$fehler VON $($faelle.Count) FAELLEN ABWEICHEND"
exit 1
