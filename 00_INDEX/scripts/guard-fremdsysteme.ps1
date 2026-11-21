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
    'api.hubapi.com', 'salesforce.com/services', 'simple_salesforce',
    # Seit der Zweitpruefung von 6.0: SharePoint und OneDrive for Business (REST), Teams- und Power-Automate-
    # Webhooks, Formulare von Google und Microsoft.
    'sharepoint.com', 'webhook.office.com', 'logic.azure.com', 'api.powerplatform.com',
    'docs.google.com/forms', 'forms.office.com',
    # Seit der vierten Pruefung von 6.0: weitere Google-Adressen (clients6, Apps-Script-Antworten), die Node-Pakete
    # von Google und Slack, Box, Discord-Webhooks, pydrive und exchangelib.
    'googleapis', '@googleapis', 'clients6.google.com', 'script.googleusercontent.com', '@slack/web-api',
    'api.box.com', 'upload.box.com', 'discord.com/api/webhooks', 'discordapp.com/api/webhooks', 'pydrive', 'pydrive2', 'exchangelib'
)
# Die Anmeldung schreibt nichts: Der Abruf eines Zugriffstokens ist ein POST an Google, gehoert aber zu jedem
# lesenden Skript (seit der vierten Pruefung von 6.0; vorher sperrte er jedes Lese-Skript mit Anmeldung).
$anmeldeAdressen = '(?i)https?://(oauth2\.googleapis\.com/token|accounts\.google\.com/o/oauth2/token|www\.googleapis\.com/oauth2/v4/token)\b'
# Schreibmerkmale. Die Kurzoptionen von curl und wget sind gross-klein-genau (-d schreibt, -D liest; -F
# schreibt, -f liest), auch in einem Buendel wie -sSd; alles andere ohne Ruecksicht auf Gross-Klein.
# Seit der Zweitpruefung von 6.0 auch ohne Leerzeichen (-d@datei, -d'{...}', -Ffeld=@x), die abgekuerzten
# PowerShell-Parameter (-Me Post, -Bo, -B) und urllib mit Daten als zweitem Argument.
$schreibMerkmal = '(?i)(-X\s*["'']?(POST|PUT|PATCH|DELETE)\b|--request\s+["'']?(POST|PUT|PATCH|DELETE)\b|(^|\s)(?-i:-d|--data(-raw|-binary|-urlencode|-ascii)?|-F|--form(-string)?|--json|-T|--upload-file|--post-data|--post-file|--body-data|--body-file)(\s|=|$)|(^|\s)(?-i:-[A-Za-z]{1,3}[dFT])(\s|$)|(^|\s)(?-i:-[A-Za-z]{0,3}d)[@''"{\[]|(^|\s)(?-i:-d)[A-Za-z0-9_.]+=|(^|\s)(?-i:-F)[A-Za-z0-9_.\[\]-]+=|--method=(POST|PUT|PATCH|DELETE)\b|-Me(t(h(o(d)?)?)?)?[\s:]+["'']?(Post|Put|Patch|Delete)\b|-Body\b|-Bo(d)?(\s|:|$)|(^|\s)-B(\s|:)|-InF(i(l(e)?)?)?\b|\burlopen\s*\(\s*[^,()]+,\s*(?![A-Za-z_]+\s*=)[^)\s]|\bRequest\s*\(\s*[^,()]+,\s*(?![A-Za-z_]+\s*=)[^)\s]|(^|\s)(http|https|xh)\s+(POST|PUT|PATCH|DELETE)\b|\.(post|put|patch|delete)\s*\(|request\s*\(\s*["''](POST|PUT|PATCH|DELETE)|method\s*[:=]\s*["''](POST|PUT|PATCH|DELETE)|Upload(String|Data|File|Values)(Async)?\s*\(|Request\s*\([^)]*\bdata\s*=|\.(batchUpdate|batch_update|batchClear|batch_clear|append_row|append_rows|update_cell|update_cells|update_acell|values_update|values_append|values_clear|values_batch_update|insert_row|insert_rows|delete_rows|delete_columns|add_worksheet|del_worksheet|add_task|update_task|close_task|delete_task|add_comment|create_page|chat_postMessage|files_upload|files_upload_v2|emptyTrash|copyTo|copy_to)\s*\(|\)\s*\.(create|insert|update|patch|delete|append|share|clear|copy|move|trash|send|modify|upload)\s*\(' +
    # Seit der vierten Pruefung von 6.0: curl-Buendel mit mehr Schaltern (-sSLkd), Konfigurationsdatei (-K, --config),
    # httpie mit Feldern (implizit POST), -CustomMethod, [WebRequestMethod]::Post, HttpClient (PostAsync, SendAsync),
    # WebClient.OpenWrite, method mit Backtick, sendBeacon, und Schreiben per GET (Google-Formular, Apps Script).
    '|(^|\s)(?-i:-[sSLkvifgqI]{1,8}[dFT])(\s|$|[@''"{\[])|(^|\s)(?-i:-K|--config)(\s|=|$)|(^|\s)(http|https|xh)(\.exe)?\s+(-\S+\s+)*\S+\s+[A-Za-z_][\w.-]*:?=|-CustomMethod\s+["'']?(POST|PUT|PATCH|DELETE)\b|WebRequestMethod\]::(Post|Put|Patch|Delete)\b|\.(Post|Put|Patch|Delete|Send)(As[A-Za-z]+)?Async\s*\(|OpenWrite\s*\(|method\s*[:=]\s*`(POST|PUT|PATCH|DELETE)|sendBeacon|formResponse|/macros/s/[^\s/]+/exec)'
# Allgemeine Methodennamen (update, clear, share ...) zaehlen ungekettet nur, wenn eine Bibliothek im Text steht, deren
# Objekte so schreiben (gspread: ws.update, sh.share). Ohne sie sperrten rows.append, set.update und dict.copy jedes
# Lese-Skript, das eine Google-Adresse nennt (seit der vierten Pruefung von 6.0; googleapiclient kettet immer).
$methodeAllgemein = '(?i)\.(create|insert|update|patch|delete|share|clear|copy|move|trash|send|modify|upload)\s*\('
$bibliothekUngekettet = '(?i)\b(gspread|pygsheets|pyairtable|notion_client|slack_sdk|simple_salesforce|pydrive2?|exchangelib|o365|dropbox)\b'
$modulLaden = '(?i)(import_module|spec_from_file_location|SourceFileLoader|runpy|importlib)'
# Ein Werkzeug aus einer Schutzliste gilt nur, wenn der Befehl genau dieses Werkzeug startet: ein Aufruf, kein
# Verketten mit ; & | oder Zeilenumbruch, kein $( ) und keine Backticks, und vor dem Pfad steht hoechstens ein
# Interpreter mit Schaltern. Sonst reicht es, den Pfad in einem Kommentar zu erwaehnen.
$verkettung = '(;|&|\||\r|\n|\$\(|`)'
$interp = '(python3?|py|pwsh|powershell|node|bash|sh)(\.exe)?'
$aufrufSkript = '^\s*(?:(?:"[^"]*?' + $interp + '"|''[^'']*?' + $interp + '''|[^\s"'']*?' + $interp + ')(?:\s+-{1,2}[A-Za-z][^\s"'']*)*\s+)?(?:"(?<sq>[^"]+)"|''(?<se>[^'']+)''|(?<so>[^\s"'']+))'
$geheimInhalt = '-----BEGIN [A-Z ]*PRIVATE KEY-----|AIza[0-9A-Za-z_\-]{35}|ghp_[0-9A-Za-z]{36}|gho_[0-9A-Za-z]{36}|github_pat_[0-9A-Za-z_]{40,}|xox[baprs]-[0-9A-Za-z\-]{10,}|(?<![A-Za-z0-9])sk-ant-[0-9A-Za-z_\-]{20,}|(?<![A-Za-z0-9])sk-proj-[0-9A-Za-z_\-]{20,}|(?<![A-Za-z0-9])sk-[A-Za-z0-9]{32,}|ya29\.[0-9A-Za-z_\-]{20,}|(?<![A-Z0-9])AKIA[0-9A-Z]{16}' +
    # Seit der vierten Pruefung von 6.0: PGP-Schluessel, Google-Client-Geheimnis und Refresh-Token, AWS-Geheimnis,
    # GitLab-, weitere GitHub-, Slack-App- und Stripe-Schluessel.
    '|-----BEGIN PGP PRIVATE KEY BLOCK-----|GOCSPX-[0-9A-Za-z_\-]{20,}|(?<![A-Za-z0-9])1//0[0-9A-Za-z_\-]{30,}|(?i:aws_secret_access_key)\s*[:=]\s*["'']?[A-Za-z0-9/+]{40}|glpat-[0-9A-Za-z_\-]{20,}|gh[sur]_[0-9A-Za-z]{36}|xapp-[0-9A-Za-z\-]{20,}|sk_live_[0-9A-Za-z]{20,}'
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

function Get-AlleTexte($o, [int]$tiefe = 0) {
    if ($null -eq $o -or $tiefe -gt 8) { return }
    if ($o -is [string]) { return $o }
    if ($o -is [System.Collections.IEnumerable]) { foreach ($x in $o) { Get-AlleTexte $x ($tiefe + 1) }; return }
    if ($o -is [System.Management.Automation.PSCustomObject]) { foreach ($p in $o.PSObject.Properties) { Get-AlleTexte $p.Value ($tiefe + 1) }; return }
    return [string]$o
}

function Get-Treffer([string]$text, $adressen) {
    $t = ($text -replace $anmeldeAdressen, ' ').ToLower()
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
        # Browser (seit der vierten Pruefung von 6.0 auch der Sammelaufruf browser_batch mit verschachtelten Aktionen und
        # navigate): jeder Text im Aufruf zaehlt, in beliebiger Tiefe.
        '(?i)(javascript|browser_batch|navigate)' { $text = (@(Get-AlleTexte $ti) | Where-Object { $_ }) -join "`n" }
        default                         { exit 0 }
    }

    if (-not $Repo) { $Repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
    . (Join-Path (Join-Path $PSScriptRoot 'lib') 'schutzliste.ps1')
    $stand = Get-SchutzStand $Repo

    # --- Pflicht der Organisation: Firmenschicht eingehaengt ------------------------------------------
    if ($schreibt -and (Test-FirmenschichtFehlt $stand)) {
        $stand = Get-SchutzStand $Repo -Frisch
        if (Test-FirmenschichtFehlt $stand) {
            # Ausgenommen sind nur die Schritte des Einhaengens, verankert im eigenen Repo (seit der vierten Pruefung
            # von 6.0; vorher galt jeder Ordner namens 00_INDEX und jede MEIN-SYSTEM.md irgendwo, und Temp\claudeX).
            $voll = ''
            try { $voll = [System.IO.Path]::GetFullPath($pfad) } catch { $voll = '' }
            $wurzel = ''
            try { $wurzel = [System.IO.Path]::GetFullPath($Repo).TrimEnd('\', '/') } catch { $wurzel = '' }
            $sep = [System.IO.Path]::DirectorySeparatorChar
            $ic = [System.StringComparison]::OrdinalIgnoreCase
            $imIndex = $wurzel -and $voll.StartsWith($wurzel + $sep + '00_INDEX' + $sep, $ic)
            $scratch = Join-Path ([System.IO.Path]::GetTempPath().TrimEnd('\', '/')) 'claude'
            $imTemp = $voll.StartsWith($scratch + $sep, $ic)
            $wurzelDatei = $false
            foreach ($n in @('.gitignore', '.ignore', 'MEIN-SYSTEM.md')) { if ($wurzel -and $voll.Equals((Join-Path $wurzel $n), $ic)) { $wurzelDatei = $true } }
            if (-not $imIndex -and -not $imTemp -and -not $wurzelDatei) {
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
    # Nur Markdown darf Adressen und Schreibaufrufe nennen (Dokumentation). Seit der vierten Pruefung von 6.0 nicht mehr
    # .txt, und Markdown wird nie mit einem Interpreter gestartet: "python notiz.md" fuehrte sonst Code aus, den diese
    # Sperre beim Schreiben bewusst nicht geprueft hatte.
    if ($tool -match '^(Bash|PowerShell)$' -and $text -match '(?i)(^|[\s;&|(])(python3?|py|node|deno|bun|ruby|perl|bash|sh|pwsh|powershell)(\.exe)?\s+(-\S+\s+)*["'']?[^\s"'';|&]+\.(md|markdown)(["''\s;|&)]|$)') {
        Write-Deny "Gesperrt: Eine Markdown-Datei wird nie als Programm gestartet. Markdown ist Dokumentation und wird von der Sperre fuer Fremdsysteme deshalb nicht geprueft (AGENTS.md Abschnitt 16). Leg Code in eine Datei mit seiner Endung (.py, .ps1, .js)."
    }
    if ($schreibt -and $pfad -match '(?i)\.(md|markdown)$') { exit 0 }
    if ($tool -match '^(Read|NotebookRead|Grep|Glob)$') { exit 0 }
    $alleAdressen = @($grundAdressen) + @($stand.adressen)
    $treffer = Get-Treffer $text $alleAdressen
    if (-not $treffer) { exit 0 }
    # Zeilen, die nur den Token-Abruf tragen (POST an die Anmeldeadresse, keine andere Adresse), zaehlen fuer das
    # Schreibmerkmal nicht mit; eine Zeile mit Anmeldung UND einer weiteren Adresse bleibt drin.
    $pruefText = (@($text -split "`r?`n" | Where-Object { -not ($_ -match $anmeldeAdressen -and -not (Get-Treffer $_ $alleAdressen)) })) -join "`n"
    $schreibend = ($pruefText -match $schreibMerkmal) -or (($pruefText -match $bibliothekUngekettet) -and ($pruefText -match $methodeAllgemein))
    if (-not $schreibend) { exit 0 }
    if ($tool -match '^(Bash|PowerShell)$' -and $text -notmatch $modulLaden) {
        $norm = (($text -replace '\\', '/').Trim()) -replace '^&\s*', ''
        # Das gestartete Skript wird aufgeloest (relativ zum Arbeitsordner) und muss genau ein Werkzeug aus der
        # Schutzliste sein, mit vollem Pfad im eingehaengten Repo; ein gleichnamiges Skript anderswo gilt nicht.
        if ($norm -notmatch $verkettung -and $norm -match $aufrufSkript) {
            $skriptPfad = @($matches['sq'], $matches['se'], $matches['so']) | Where-Object { $_ } | Select-Object -First 1
            $basis = [string]$in.cwd
            if (-not $basis) { $basis = [string]$env:CLAUDE_PROJECT_DIR }
            $voll = ''
            try {
                if ([System.IO.Path]::IsPathRooted($skriptPfad)) { $voll = [System.IO.Path]::GetFullPath($skriptPfad) }
                elseif ($basis) { $voll = [System.IO.Path]::GetFullPath((Join-Path $basis $skriptPfad)) }
            } catch { $voll = '' }
            $voll = $voll -replace '\\', '/'
            foreach ($w in @($stand.werkzeuge)) {
                if ($w -and $voll -and $voll.Equals([string]$w, [System.StringComparison]::OrdinalIgnoreCase)) { exit 0 }
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
