# eingehaengte-repos-aktuell.ps1
# Zweck: Eingehaengte Repos (Ordner mit eigenem .git unterhalb dieses Repos: geteilte Wissensrepos und Fachagenten mit
# eigener Struktur und Logik, Skill leo-repo-einhaengen) werden nur auf dem neuesten Stand benutzt. Geprueft wird bei
# jedem Sessionstart und spaetestens alle 24 Stunden, je nachdem, was haeufiger ist (seit 4.7, AGENTS.md Abschnitt 1,
# Grundpflege).
#
# WARUM ES DAS GIBT: Ein eingehaengtes Repo gehoert anderen und aendert sich ohne Zutun dieses Systems. Wer auf einem
# alten Stand arbeitet, folgt einer Anleitung, die der Owner laengst korrigiert hat, und baut Pull Requests auf einen
# Stand, den es nicht mehr gibt. Eine Textregel allein ueberliest ein Agent, der direkt ins Thema einsteigt.
#
# Ablauf je eingehaengtem Repo: das Original holen (upstream, sonst origin), Rueckstand von main zaehlen, und
#   - aktuell: nichts tun
#   - Rueckstand, sauberer Arbeitsbaum auf main: selbst nachziehen (nur Fast-Forward, nie mergen, nie ueberschreiben)
#   - Rueckstand auf einem anderen Zweig: main nachziehen (Fast-Forward ohne Checkout) und melden, dass der Zweig zurueckliegt
#   - sonst (lokale Aenderungen auf main, auseinandergelaufen, kein Netz, kein Original): GESPERRT mit Grund
# Die Meldung geht als Kontext an das Modell (Hook-Ausgabe), das sie dem Besitzer weitergibt; ein gesperrtes Repo wird
# nicht benutzt, bis es synchronisiert ist. Jeder Lauf schreibt den Zeitstempel 10_System\eingehaengte-repos-last-run.txt
# (steht in der .gitignore); an ihm erkennt ein Agent ohne Hook, dass er das Skript selbst rufen muss.
#
# AUFRUF:
#   als SessionStart-Hook:       powershell -File eingehaengte-repos-aktuell.ps1 -Hook SessionStart     (prueft immer)
#   als UserPromptSubmit-Hook:   powershell -File eingehaengte-repos-aktuell.ps1 -Hook UserPromptSubmit (prueft, wenn > 24 h her)
#   von Hand oder in Werkzeugen ohne Hook: pwsh -File eingehaengte-repos-aktuell.ps1   (Ausgabe als Text, Exit 1 bei Sperre)
# Blockiert nie einen Werkzeugaufruf; ein eigener Fehler endet in einer Hinweiszeile mit Grund statt im Schweigen.
# ASCII-only, laeuft unter Windows PowerShell 5.1 und PowerShell 7. Bewusst ErrorActionPreference Continue: Unter 5.1
# wird jede Git-Meldung auf stderr bei Stop zum Abbruch, auch mit 2>$null; Fehler werden ueber den Exitcode geprueft.
param(
    [string]$Repo = '',
    [ValidateSet('', 'SessionStart', 'UserPromptSubmit')][string]$Hook = '',
    [string]$Stand = '',
    [int]$Stunden = 24
)
$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

function Ausgabe([string]$text, [bool]$gesperrt) {
    if ($Hook) {
        if ($text) {
            @{ hookSpecificOutput = @{ hookEventName = $Hook; additionalContext = $text } } | ConvertTo-Json -Depth 4 -Compress
        }
        exit 0
    }
    if ($text) { Write-Output $text }
    if ($gesperrt) { exit 1 } else { exit 0 }
}

try {
    if (-not $Repo) { $Repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
    $root = [System.IO.Path]::GetFullPath($Repo).TrimEnd('\', '/')
    if (-not $Stand) { $Stand = Join-Path (Join-Path $root '10_System') 'eingehaengte-repos-last-run.txt' }
    if ($Hook) { $null = [Console]::In.ReadToEnd() }
    $jetzt = Get-Date
    if ($Hook -eq 'UserPromptSubmit' -and (Test-Path -LiteralPath $Stand)) {
        $letzt = [datetime]((Get-Content -LiteralPath $Stand -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop).zeit)
        if (($jetzt - $letzt).TotalHours -lt $Stunden) { exit 0 }
    }
    . (Join-Path $PSScriptRoot 'lib\eingehaengt-ausschluss.ps1')
    $ordner = @(Get-EingehaengteOrdner $root)
    $zeilen = New-Object System.Collections.Generic.List[string]
    $gesperrt = $false
    foreach ($o in $ordner) {
        $rel = $o.Substring($root.Length + 1)
        $quelle = if (git -C $o remote get-url upstream 2>$null) { 'upstream' } elseif (git -C $o remote get-url origin 2>$null) { 'origin' } else { '' }
        if (-not $quelle) { $zeilen.Add("GESPERRT ${rel}: kein Original als Remote, der Stand ist nicht pruefbar. Nicht benutzen; den Besitzer fragen."); $gesperrt = $true; continue }
        git -C $o fetch -q $quelle main 2>$null
        if ($LASTEXITCODE -ne 0) { $zeilen.Add("GESPERRT ${rel}: das Original ($quelle) ist nicht erreichbar (Netz?). Nicht benutzen, bis die Pruefung gelingt."); $gesperrt = $true; continue }
        $zweig = [string](git -C $o branch --show-current 2>$null)
        $hinterMain = [int](git -C $o rev-list --count "main..$quelle/main" 2>$null)
        $vorMain = [int](git -C $o rev-list --count "$quelle/main..main" 2>$null)
        $sauber = -not [string](git -C $o status --porcelain 2>$null)
        if ($hinterMain -gt 0) {
            if ($vorMain -gt 0) { $zeilen.Add("GESPERRT ${rel}: main ist $hinterMain hinter und $vorMain vor dem Original (auseinandergelaufen). Nicht benutzen; den Besitzer fragen."); $gesperrt = $true; continue }
            if ($zweig -eq 'main') {
                if (-not $sauber) { $zeilen.Add("GESPERRT ${rel}: $hinterMain neue Aenderung(en) im Original, aber lokale ungespeicherte Aenderungen auf main. Nicht benutzen; zuerst klaeren."); $gesperrt = $true; continue }
                git -C $o merge -q --ff-only "$quelle/main" 2>$null
                if ($LASTEXITCODE -ne 0) { $zeilen.Add("GESPERRT ${rel}: Nachziehen (Fast-Forward) gescheitert. Nicht benutzen; zuerst klaeren."); $gesperrt = $true; continue }
                $zeilen.Add("NACHGEZOGEN ${rel}: $hinterMain neue Aenderung(en) aus dem Original uebernommen. Geaenderte Regeln und Anleitungen vor der naechsten Arbeit darin neu lesen.")
            } else {
                git -C $o fetch -q $quelle "main:main" 2>$null
                $zeilen.Add("ZWEIG ${rel}: main aus dem Original nachgezogen ($hinterMain); gearbeitet wird auf Zweig '$zweig', der dahinter liegt. Fuer neue Arbeit zuerst auf main wechseln.")
            }
        } elseif ($zweig -ne 'main' -and [int](git -C $o rev-list --count "HEAD..$quelle/main" 2>$null) -gt 0) {
            $zeilen.Add("ZWEIG ${rel}: Zweig '$zweig' liegt hinter main des Originals. Fuer neue Arbeit zuerst auf main wechseln.")
        }
    }
    $dir = Split-Path -Parent $Stand
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force $dir -ErrorAction Stop | Out-Null }
    @{ zeit = $jetzt.ToString('o'); repos = $ordner.Count; gesperrt = $gesperrt } | ConvertTo-Json | Set-Content -LiteralPath $Stand -Encoding UTF8 -ErrorAction Stop
    if ($zeilen.Count -eq 0) { Ausgabe '' $false }
    $text = "Stand der eingehaengten Repos (Pruefung " + $jetzt.ToString('dd.MM.yyyy HH:mm') + "): " + ($zeilen -join ' | ') + " -- Dem Besitzer in der Antwort nennen, was nachgezogen oder gesperrt ist, mit Grund."
    Ausgabe $text $gesperrt
}
catch {
    Ausgabe ("Pruefung der eingehaengten Repos gescheitert (" + $_.Exception.Message + "). Bis sie gelingt, eingehaengte Repos nicht benutzen und den Grund dem Besitzer nennen.") $true
}
