# guard-fremdsysteme.ps1
# Zweck: PreToolUse-Hook (seit 6.0, AGENTS.md Abschnitt 16). Sperrt drei Dinge, unabhaengig vom
# Berechtigungsmodus:
#   1. Direktes Schreiben in Fremdsysteme (Google, Microsoft 365, Slack und vergleichbare Dienste, dazu
#      die Adressen aus den Schutzlisten der eingehaengten Repos). Geschrieben wird dort nur ueber ein
#      Werkzeug mit Freigabefenster, das in einer Schutzliste als "werkzeug:" eingetragen ist; lesen
#      bleibt frei. Erkannt wird ein Schreibzugriff, wenn ein Befehl, ein Skript, das geschrieben wird,
#      oder Code im Browser eine geschuetzte Adresse oder Bibliothek nennt UND ein Schreibmerkmal traegt
#      (POST, PUT, PATCH, DELETE, Datenversand, Schreibaufruf einer Bibliothek).
#   2. Schluesseldateien aus den Schutzlisten: weder lesen noch schreiben noch nennen.
#   3. Schluessel in einem Repo: keine Schluesseldatei (.env, *.pem, *token*.json und Verwandte) und kein
#      Inhalt, der wie ein Zugangsschluessel aussieht, wird in ein Git-Repo geschrieben.
# Dazu die Pflicht der Organisation: Verlangt sie eine Firmenschicht (LEO_FIRMENSCHICHT, lib\schutzliste.ps1)
# und ist sie nicht eingehaengt, sperrt dieser Hook jedes Schreiben von Dateien ausser den Schritten des
# Einhaengens, bis sie eingehaengt ist.
#
# WARUM: Ein Agent mit Shell kann jeden Dienst im Netz direkt ansprechen, mit den Zugangsdaten seines
# Besitzers. Ein Werkzeug mit Freigabefenster zeigt vorher, was passiert, und der Mensch entscheidet mit
# einem Mausklick; ein eigener Aufruf zeigt nichts.
# GRENZE: Der Hook sieht nur den Text eines Aufrufs. Wer eine Adresse aus Teilstuecken zusammensetzt oder
# ein vorhandenes Skript startet, das selbst schreibt, kommt an ihm vorbei (AGENTS.md Abschnitt 18, "Die
# Hooks schuetzen gegen das Versehen"). Markdown- und Textdateien werden nicht auf Schreibzugriffe geprueft,
# weil Dokumentation die Adressen nennen darf.
#
# -Repo: das Repo dieses Systems (dort liegen die eingehaengten Repos). Der Verteiler leo-hook.ps1 uebergibt
# es; ohne Angabe gilt der Ordner zwei Ebenen ueber diesem Skript.
# Durchlass = stilles Exit 0. Ein eigener Fehler sperrt, wenn der Text eine Adresse der Grundliste mit einem
# Schreibmerkmal traegt; sonst laesst er durch. ASCII-only, BOM: laeuft unter Windows PowerShell 5.1.
# Regressionsreihe: guard-fremdsysteme-tests.ps1.
param([string]$Repo = '')

$ErrorActionPreference = 'Stop'

function Write-Deny([string]$reason) {
    @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } } | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

# Grundliste: Adressen und Bibliotheken von Diensten, in die ohne Werkzeug nie geschrieben wird.
$grundAdressen = @(
    'googleapis.com', 'script.google.com', 'gspread', 'pygsheets', 'googleapiclient',
    'graph.microsoft.com', 'outlook.office.com/api', 'outlook.office365.com', 'msgraph', 'o365',
    'slack.com/api', 'hooks.slack.com', 'slack_sdk',
    'api.notion.com', 'notion_client',
    'atlassian.net', 'api.atlassian.com',
    'api.dropboxapi.com', 'content.dropboxapi.com',
    'api.airtable.com', 'pyairtable',
    'app.asana.com/api', 'api.trello.com',
    'api.hubapi.com', 'salesforce.com/services', 'simple_salesforce'
)
# Schreibmerkmale. Die Kurzoptionen von curl und wget sind gross-klein-genau (-d schreibt, -D liest; -F
# schreibt, -f liest), auch in einem Buendel wie -sSd; alles andere ohne Ruecksicht auf Gross-Klein.
$schreibMerkmal = '(?i)(-X\s*["'']?(POST|PUT|PATCH|DELETE)\b|--request\s+["'']?(POST|PUT|PATCH|DELETE)\b|(^|\s)(?-i:-d|--data(-raw|-binary|-urlencode|-ascii)?|-F|--form(-string)?|--json|-T|--upload-file|--post-data|--post-file|--body-data|--body-file)(\s|=|$)|(^|\s)(?-i:-[A-Za-z]{1,3}[dFT])(\s|$)|--method=(POST|PUT|PATCH|DELETE)\b|-Method[\s:]+["'']?(Post|Put|Patch|Delete)\b|-Body\b|-InFile\b|(^|\s)(http|https|xh)\s+(POST|PUT|PATCH|DELETE)\b|\.(post|put|patch|delete)\s*\(|request\s*\(\s*["''](POST|PUT|PATCH|DELETE)|method\s*[:=]\s*["''](POST|PUT|PATCH|DELETE)|Upload(String|Data|File|Values)(Async)?\s*\(|Request\s*\([^)]*\bdata\s*=|\.(create|insert|update|patch|delete|batchUpdate|batch_update|append|append_row|append_rows|update_cell|update_cells|update_acell|values_update|values_append|values_clear|insert_row|insert_rows|delete_rows|add_worksheet|del_worksheet|share|clear|copy|move|trash|send|modify|add_task|update_task|close_task|delete_task|add_comment|create_page|chat_postMessage|files_upload|upload)\s*\()'
$modulLaden = '(?i)(import_module|spec_from_file_location|SourceFileLoader|runpy|importlib)'
# Ein Werkzeug aus einer Schutzliste gilt nur, wenn der Befehl genau dieses Werkzeug startet: ein Aufruf, kein
# Verketten mit ; & | oder Zeilenumbruch, kein $( ) und keine Backticks, und vor dem Pfad steht hoechstens ein
# Interpreter mit Schaltern. Sonst reicht es, den Pfad in einem Kommentar zu erwaehnen.
$verkettung = '(;|&|\||\r|\n|\$\(|`)'
$interp = '(python3?|py|pwsh|powershell|node|bash|sh)(\.exe)?'
$aufrufVor = '^\s*(("[^"]*?' + $interp + '"|''[^'']*?' + $interp + '''|[^\s"'']*?' + $interp + ')(\s+-{1,2}[A-Za-z][^\s"'']*)*\s+)?("[^"]*|''[^'']*|[^\s"'']*)$'
$geheimInhalt = '-----BEGIN [A-Z ]*PRIVATE KEY-----|AIza[0-9A-Za-z_\-]{35}|ghp_[0-9A-Za-z]{36}|gho_[0-9A-Za-z]{36}|github_pat_[0-9A-Za-z_]{40,}|xox[baprs]-[0-9A-Za-z\-]{10,}|(?<![A-Za-z0-9])sk-ant-[0-9A-Za-z_\-]{20,}|(?<![A-Za-z0-9])sk-proj-[0-9A-Za-z_\-]{20,}|(?<![A-Za-z0-9])sk-[A-Za-z0-9]{32,}|ya29\.[0-9A-Za-z_\-]{20,}|(?<![A-Z0-9])AKIA[0-9A-Z]{16}'
$schluesselName = '(?i)(^\.env(\..*)?$|\.(pem|key|pfx|p12|kdbx|ppk)$|^id_(rsa|ed25519|ecdsa)|token[^\\/]*\.json$|credential[^\\/]*\.json$|client_secret[^\\/]*\.json$|service[-_]?account[^\\/]*\.json$|^\.(netrc|git-credentials|pypirc)$|[-_.]key\.txt$|^\.?[^\\/]*-key$)'

$fremdGrund = "Schreiben in ein Fremdsystem ist gesperrt: '{0}' wird nur ueber ein Werkzeug mit Freigabefenster beschrieben, nie mit einem eigenen Aufruf, Skript oder Code im Browser (AGENTS.md Abschnitt 16). Lesen bleibt frei. Gibt es fuer diesen Dienst ein Werkzeug (eine Firmenschicht nennt es in ihrer README.md und in schutzliste.txt), nimm es. Sonst sag [NAME] in zwei Saetzen, was du schreiben wolltest und dass es dafuer ein Werkzeug mit Freigabefenster braucht; such keinen anderen Weg."
$schluesselGrund = "Gesperrt: '{0}' ist eine Schluesseldatei aus einer Schutzliste. Du liest, schreibst und nennst sie nie; das Werkzeug, das sie braucht, liest sie selbst (AGENTS.md Abschnitte 16 und 18)."
$repoSchluesselGrund = "Gesperrt: Schluessel liegen nie in einem Repo, weder als Datei ('{0}') noch als Inhalt einer Datei (AGENTS.md Abschnitt 16). Ein Schluessel gehoert in eine Datei im Benutzerprofil, die nur das Werkzeug liest. Hat [NAME] dir einen Schluessel gegeben, sag ihm das und lass ihn den Schluessel selbst dort ablegen."

function Test-InGitRepo([string]$pfad) {
    try { $d = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($pfad)) } catch { return $false }
    for ($i = 0; $i -lt 40 -and $d; $i++) {
        if (Test-Path -LiteralPath (Join-Path $d '.git')) { return $true }
        $d = [System.IO.Path]::GetDirectoryName($d)
    }
    return $false
}

function Get-Treffer([string]$text, $adressen) {
    $t = $text.ToLower()
    foreach ($a in $adressen) {
        if (-not $a) { continue }
        $rx = '(?<![a-z0-9_])' + [regex]::Escape($a) + '(?![a-z0-9_])'
        if ($t -match $rx) { return $a }
    }
    return $null
}

$text = ''
try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding($false)))).ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    $tool = [string]$in.tool_name
    $ti = $in.tool_input
    $pfad = ''
    $schreibt = $false
    switch -Regex ($tool) {
        '^(Bash|PowerShell)$'           { $text = [string]$ti.command }
        '^Write$'                       { $text = [string]$ti.content; $pfad = [string]$ti.file_path; $schreibt = $true }
        '^Edit$'                        { $text = [string]$ti.new_string; $pfad = [string]$ti.file_path; $schreibt = $true }
        '^MultiEdit$'                   { $text = (@($ti.edits) | ForEach-Object { [string]$_.new_string }) -join "`n"; $pfad = [string]$ti.file_path; $schreibt = $true }
        '^NotebookEdit$'                { $text = [string]$ti.new_source; $pfad = [string]$ti.notebook_path; $schreibt = $true }
        '^(Read|NotebookRead)$'         { $pfad = [string]$ti.file_path; if (-not $pfad) { $pfad = [string]$ti.notebook_path } }
        '^(Grep|Glob)$'                 { $pfad = [string]$ti.path; $text = [string]$ti.pattern + ' ' + [string]$ti.glob }
        '(?i)javascript'                { $text = (@($ti.text, $ti.code, $ti.script, $ti.function) | Where-Object { $_ }) -join "`n" }
        default                         { exit 0 }
    }

    if (-not $Repo) { $Repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
    . (Join-Path (Join-Path $PSScriptRoot 'lib') 'schutzliste.ps1')
    $stand = Get-SchutzStand $Repo

    # --- Pflicht der Organisation: Firmenschicht eingehaengt ------------------------------------------
    if ($schreibt -and (Test-FirmenschichtFehlt $stand)) {
        $stand = Get-SchutzStand $Repo -Frisch
        if (Test-FirmenschichtFehlt $stand) {
            $leaf = [System.IO.Path]::GetFileName($pfad)
            $imIndex = $pfad -match '[\\/]00_INDEX[\\/]'
            $scratch = Join-Path ([System.IO.Path]::GetTempPath().TrimEnd('\', '/')) 'claude'
            $imTemp = $pfad.StartsWith($scratch, [System.StringComparison]::OrdinalIgnoreCase)
            if (-not $imIndex -and -not $imTemp -and $leaf -notin @('.gitignore', '.ignore', 'MEIN-SYSTEM.md')) {
                $soll = Get-FirmenschichtSoll
                Write-Deny ("Deine Organisation verlangt, dass ihre Firmenschicht '" + $soll + "' eingehaengt ist, und sie fehlt. Bis sie eingehaengt ist, schreibst du keine Dateien (AGENTS.md Abschnitt 16, Firmenschicht). Sag [NAME] das in zwei Saetzen und haeng sie jetzt mit ihm ein, mit dem Skill leo-repo-einhaengen: https://github.com/" + $soll + " . Fehlt [NAME] der Zugriff auf GitHub, wendet er sich an die Person, die ihm Leo Core gegeben hat.")
            }
        }
    }

    # --- Schluesseldateien aus den Schutzlisten ------------------------------------------------------
    foreach ($s in @($stand.schluessel)) {
        if (-not $s) { continue }
        $rx = '(?i)' + ([regex]::Escape([string]$s) -replace '\\\*', '[^\s"''\\/]*')
        if (($pfad -and $pfad -match $rx) -or ($text -and $text -match $rx)) { Write-Deny ($schluesselGrund -f $s) }
    }

    # --- Schluessel in einem Repo ---------------------------------------------------------------------
    if ($schreibt -and $pfad) {
        $leaf = [System.IO.Path]::GetFileName($pfad)
        $imRepo = Test-InGitRepo $pfad
        if ($imRepo -and $leaf -match $schluesselName) { Write-Deny ($repoSchluesselGrund -f $leaf) }
        if ($imRepo -and $text -cmatch $geheimInhalt) { Write-Deny ($repoSchluesselGrund -f $leaf) }
    }

    # --- Schreiben in Fremdsysteme --------------------------------------------------------------------
    if (-not $text) { exit 0 }
    if ($schreibt -and $pfad -match '(?i)\.(md|markdown|txt)$') { exit 0 }
    if ($tool -match '^(Read|NotebookRead|Grep|Glob)$') { exit 0 }
    $treffer = Get-Treffer $text (@($grundAdressen) + @($stand.adressen))
    if (-not $treffer) { exit 0 }
    if ($text -notmatch $schreibMerkmal) { exit 0 }
    if ($tool -match '^(Bash|PowerShell)$' -and $text -notmatch $modulLaden) {
        $norm = (($text -replace '\\', '/').Trim()) -replace '^&\s*', ''
        if ($norm -notmatch $verkettung) {
            foreach ($w in @($stand.werkzeuge)) {
                if (-not $w) { continue }
                $i = $norm.ToLower().IndexOf(([string]$w).ToLower())
                if ($i -ge 0 -and $norm.Substring(0, $i) -match $aufrufVor) { exit 0 }
            }
        }
    }
    Write-Deny ($fremdGrund -f $treffer)
} catch {
    if ($text -and (Get-Treffer $text $grundAdressen) -and $text -match $schreibMerkmal) {
        Write-Deny ("Die Sperre fuer Fremdsysteme konnte den Aufruf nicht pruefen (" + $_.Exception.Message + ") und sperrt deshalb, weil er in einen Dienst zu schreiben scheint (AGENTS.md Abschnitt 16).")
    }
    exit 0
}
