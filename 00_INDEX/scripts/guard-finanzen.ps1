# guard-finanzen.ps1
# Zweck: Sperre fuer Geldplattformen, gespeicherte Zugangsdaten und Sicherheitsmails, dazu ein Sicherheits-Audit
# (AGENTS.md Abschnitt 18, "Geld, Anmeldedaten, Sicherheitsmails und Token-Rechte", seit 6.1).
#
# WARUM ES DAS GIBT: Ein Agent mit Browser-Steuerung arbeitet in jedem Tab, in dem sein Besitzer angemeldet ist.
# Eine angemeldete Sitzung bei einer Bank hat die Zwei-Faktor-Pruefung schon hinter sich; dort schuetzt der zweite
# Faktor nicht mehr. Dasselbe gilt fuer gespeicherte Zugangsdaten (Passwoerter im Browser, Git-Login, Tresore des
# Betriebssystems) und fuer Mails mit Einmalcodes oder Anmeldelinks: Wer sie lesen kann, kann sich anmelden. Eine
# Textregel haelt das nicht auf, ein Hook schon.
#
# DREI BETRIEBSARTEN
#   Hook (Standard, Eingabe JSON auf stdin):
#     PreToolUse  - Geldplattformen, Webmail, Passwortverwaltungen und Konto-Sicherheitsseiten im Browser,
#                   Javascript an Passwortfeldern, Anmelde- und Bestaetigungslinks aufrufen, Codes in Formulare
#                   tippen, HTTP und Browserstarts gegen Geldplattformen aus der Shell, Auslesen von Zugangsdaten
#                   (Shell, Read, Grep, Glob, Dateien).
#     PostToolUse - blendet Sicherheitsmails (Muster in sicherheitsmail.json) in der Ausgabe von Bash, PowerShell,
#                   Read, Grep und MCP-Werkzeugen aus, bevor das Modell sie sieht (updatedToolOutput); merkt sich
#                   die Tab-Adressen der Browser je Session.
#     SessionStart - fuehrt den Audit aus (Ergebnis 24 Stunden zwischengespeichert) und legt neue oder seit sieben
#                   Tagen nicht gemeldete Befunde dem Agenten und dem Besitzer vor.
#   -Audit        - gibt alle Befunde als Markdown aus (mit -Json als JSON, fuer den Health-Check).
#
# WAS ALS GELDPLATTFORM GILT (Get-HostArt): jeder Host mit "bank", "sparkasse", "banque", "banca" oder
#   "raiffeisen" im Namen, Kantonalbanken (*kb.ch) und eine feste Liste von Brokern, Neobanken, Vorsorge- und
#   Zahlungsdiensten, Kartenherausgebern und Krypto-Boersen; dazu Passwortverwaltungen und Web-Tresore. Die Liste
#   steht fest im Skript, weil es aus einer Kopie ausserhalb des Repos laeuft und der Agent es dort nicht lockern
#   kann. Ausnahmen (Recherche): worldbank.org, bankrate.com. Einen Lesezugang zu einer Geldplattform gibt es nur
#   ueber einen eigenen, im Zielsystem widerrufbaren Leseschluessel, den der Besitzer anlegt (10_System\Zugaenge.md).
# BEKANNTE GRENZEN: textbasiert. Ein Klick auf einen Link zu einer Bank laeuft durch, erst die naechste Aktion im
#   Tab ist gesperrt. Eine Bank ohne Stichwort im Namen und ausserhalb der Liste erkennt sie nicht. Ein selbst
#   geschriebenes Skript, das einen Mailspeicher direkt oeffnet, sieht die Sperre nur ueber seine Ausgabe. Was das
#   Modell nicht sieht, erhaelt die Telemetrie des Werkzeugs trotzdem (Doku zu updatedToolOutput).
# Durchlass = stilles Exit 0. Ein eigener Fehler endet im Durchlassen, AUSSER der Aufruf nennt eine Geldplattform,
# eine Passwortverwaltung oder einen Zugangsdatenspeicher: dann wird gesperrt.
# ASCII-only, laeuft unter Windows PowerShell 5.1 und PowerShell 7 (auch macOS/Linux). Regressionsreihe:
# guard-finanzen-tests.ps1.
param(
    [switch]$Audit,
    [switch]$Json,
    [string]$Repo = ''
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$istWindows = [System.IO.Path]::DirectorySeparatorChar -eq '\'
$istMac = (-not $istWindows) -and (Test-Path -LiteralPath '/System/Library/CoreServices')
$heim = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($env:HOME) { $env:HOME } else { [System.IO.Path]::GetTempPath() }

function Write-Deny([string]$reason) {
    $out = @{ hookSpecificOutput = @{ hookEventName = "PreToolUse"; permissionDecision = "deny"; permissionDecisionReason = $reason } }
    $out | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

# Zustand (Tab-Gedaechtnis, Audit-Zwischenspeicher) liegt ausserhalb jedes Repos. LEO_FINANZEN_DIR nur fuer die
# Testreihe; der Verteiler leo-hook.ps1 leert die Variable, bevor er die Sperre startet.
$stateDir = if ($env:LEO_FINANZEN_DIR) { $env:LEO_FINANZEN_DIR }
            elseif ($env:LOCALAPPDATA) { Join-Path (Join-Path $env:LOCALAPPDATA 'Leo') 'finanzen-browser' }
            else { Join-Path $heim '.leo-finanzen' }
$grund = "Gesperrt: Der Agent greift nie auf Geldplattformen (Banken, Broker, Vorsorge, Zahlungsdienste, Karten, Krypto), gespeicherte Zugangsdaten oder Sicherheitsmails zu (AGENTS.md Abschnitt 18). Lesen geht nur ueber einen eigenen, im Zielsystem widerrufbaren Leseschluessel (10_System\Zugaenge.md). Was dort geschehen muss, macht der Besitzer selbst."
$raw = ""
$tabsDatei = $null

# ---------------------------------------------------------------- Listen und Muster

$finanzListe = @(
    'postfinance\.ch', 'ubs\.com', 'credit-suisse\.com', 'cler\.ch', 'valiant\.ch', 'yuh\.com', 'neon-free\.ch',
    'zak\.ch', 'radicant\.com', 'swissquote\.(ch|com)', 'truewealth\.ch', 'viac\.ch', 'finpension\.ch',
    'frankly\.ch', 'selma\.io', 'inyova\.ch', 'twint\.ch', 'viseca\.ch', 'cornercard\.ch', 'swisscard\.ch',
    'cembra\.ch', 'one-digitalservice\.ch',
    'etoro\.com', 'degiro\.[a-z.]+', 'interactivebrokers\.[a-z.]+', 'ibkr\.com', 'trading212\.com',
    'scalable\.capital', 'traderepublic\.com', 'flatex\.[a-z.]+', 'comdirect\.de', 'robinhood\.com', 'schwab\.com',
    'fidelity\.com', 'vanguard\.com', 'etrade\.com', 'webull\.com', 'plus500\.com', 'xtb\.com', 'ig\.com',
    'cmcmarkets\.com', 'home\.saxo', 'saxotrader\.com', 'onvista\.de', 'smartbroker\.de',
    'revolut\.com', 'wise\.com', 'n26\.com', 'bunq\.com', 'monzo\.com', 'dkb\.de', 'ing\.[a-z]{2,3}', 'chime\.com',
    'paypal\.[a-z.]+', 'venmo\.com', 'cash\.app', 'klarna\.com', 'payoneer\.com', 'skrill\.com', 'neteller\.com',
    'dashboard\.stripe\.com', 'americanexpress\.com', 'chase\.com', 'wellsfargo\.com', 'citi\.com', 'hsbc\.[a-z.]+',
    'barclays\.[a-z.]+', 'santander\.[a-z.]+', 'bnpparibas\.[a-z.]+', 'unicredit\.[a-z.]+', 'abnamro\.[a-z.]+',
    'coinbase\.com', 'binance\.[a-z.]+', 'kraken\.com', 'bitpanda\.com', 'bitstamp\.net', 'crypto\.com',
    'bitvavo\.com', 'bybit\.com', 'okx\.com', 'kucoin\.com', 'gemini\.com', 'blockchain\.com', 'metamask\.io',
    'ledger\.com', 'trezor\.io', 'exodus\.com'
)
$finanzListeRe = '(?i)^(?:[a-z0-9-]+\.)*(?:' + ($finanzListe -join '|') + ')$'
$bankWortRe = '(?i)(bank|sparkasse|banque|banca|raiffeisen)'
$kantonalRe = '(?i)^(?:[a-z0-9-]+\.)*[a-z]{0,5}kb\.ch$'
$ausnahmeRe = '(?i)^(?:[a-z0-9-]+\.)*(worldbank\.org|bankrate\.com)$'
$pwHostRe = '(?i)^(?:[a-z0-9-]+\.)*(passwords\.google\.com|1password\.com|vault\.bitwarden\.com|vault\.bitwarden\.eu|lastpass\.com|dashlane\.com|keepersecurity\.com|pass\.proton\.me|nordpass\.com|roboform\.com)$'
$pwUrlRe = '(?i)^(chrome|edge|brave|opera|vivaldi)://(password-manager|settings/(passwords|autofill|payments|addresses)|wallet)'
# Konto-Sicherheitsseiten (Wiederherstellung, Zweitfaktor, Token) gelten wie Passwortverwaltungen.
$kontoHostRe = '(?i)^(myaccount\.google\.com|security\.google\.com|account\.microsoft\.com|account\.live\.com|mysignins\.microsoft\.com|appleid\.apple\.com|account\.apple\.com|accounts\.firefox\.com)$'
$kontoPfadRe = '(?i)^((www\.)?github\.com/settings|gitlab\.com/-/(profile|user_settings)|(www\.)?claude\.ai/settings|platform\.openai\.com/(api-keys|settings))(/|$)'
# Webmail im Browser (jede Adresse mail.<anbieter>.<endung>, dazu Anbieter mit eigener Adresse): Ein Bildschirmfoto einer Mail laesst sich nicht ausblenden. Mails liest der Agent nur ueber
# Leseskripte oder Connectoren, deren Ausgabe diese Sperre nach dem Aufruf prueft.
$postHostRe = '(?i)^(mail\.[a-z0-9-]+\.[a-z]{2,6}|inbox\.google\.com|outlook\.(live|office|office365)\.com|(navigator-[a-z0-9]+\.)?gmx\.(net|ch|de|at)|(www\.)?web\.de|webmail\.[a-z0-9.-]+|[a-z0-9-]+\.webmail\.[a-z0-9.-]+)$'
$postPfadRe = '(?i)^((www\.)?bluewin\.ch/[a-z]{2}/(e-?mail|webmail)|(www\.)?icloud\.com/mail)(/|$)'
$anmeldungRe = '(?i)(log-?in|sign-?in|signon|auth|verif|2fa|mfa|otp|passwor|security|recover|reset|account)'
$linkWortRe = '(?i)(reset|recover|verif|confirm|magic|otp|2fa|mfa|passwor|activat|sign-?in|log-?in|auth|token|invite)'
$jsPwRe = '(?i)(type\s*=\s*\\?[''"]?password|\[type\s*=\s*\\?[''"]?password|navigator\.credentials|PasswordCredential|autocomplete\s*=\s*\\?[''"]?(current|new)-password|one-time-code)'
$credRe = '(?i)(Login Data|Web Data|logins\.json|key4\.db|cookies\.sqlite|Network[\\/]+Cookies|User Data[\\/]+Local State|git(-|\s+)credential(-manager)?\s+(fill|get)|credential-manager\s+get|gh\s+auth\s+token|gh\s+auth\s+status\s+[^|;&]*--show-token|vaultcmd|Get-StoredCredential|CredentialManager|CredRead|ProtectedData\]?::Unprotect|CryptUnprotectData|win32crypt|keyring\.get_password|browser_cookie3|pycookiecheat|rookiepy|remote-debugging-port|Network\.getAllCookies|Storage\.getCookies|security\s+find-(generic|internet)-password|secret-tool\s+lookup)'
$httpRe = '(?i)(curl|wget|Invoke-WebRequest|Invoke-RestMethod|iwr\s|irm\s|requests\.|urllib|http\.client|httpx|aiohttp|WebClient|HttpClient|fetch\(|Start-Process|\bstart\s|\bopen\s|xdg-open|chrome(\.exe)?|msedge(\.exe)?|firefox(\.exe)?|explorer(\.exe)?)'
$dateiEndung = '(?i)^(py|ps1|psm1|md|txt|csv|tsv|json|jsonl|xml|xlsx?|docx?|pptx?|pdf|html?|js|ts|css|log|ya?ml|ini|cfg|exe|dll|png|jpe?g|gif|svg|zip|eml|msg|sh|bat|cmd|toml|lock|db|sqlite)$'
$codeRe = '^\s*(\d{6,8}|\d{3}[ -]\d{3}|[A-Za-z0-9]{4,5}-[A-Za-z0-9]{4,5})\s*$'
$kurzCodeRe = '^\s*\d{4,5}\s*$'
$speicherRe = '(?i)(Login Data|Web Data|logins\.json|key4\.db|cookies\.sqlite|Network[\\/]+Cookies|User Data[\\/]+Local State)'

# Sicherheitsmails: Muster aus sicherheitsmail.json neben diesem Skript (in jeder Kopie der Sperren ebenfalls daneben)
$smMuster = @()
$smBeleg = @()
$smFenster = 400
$smHinweis = '[Ausgeblendet von guard-finanzen: sicherheitsrelevante Mail zu Anmeldung oder Konto. Nicht verwenden und nicht weitergeben; der Besitzer liest sie bei Bedarf selbst.]'
$smDatei = Join-Path $PSScriptRoot 'sicherheitsmail.json'
try {
    $sm = [IO.File]::ReadAllText($smDatei, [Text.Encoding]::UTF8) | ConvertFrom-Json
    $smMuster = @($sm.muster | ForEach-Object { New-Object System.Text.RegularExpressions.Regex($_, 'IgnoreCase') })
    $smBeleg = @($sm.beleg | Where-Object { $_ } | ForEach-Object { New-Object System.Text.RegularExpressions.Regex($_, 'IgnoreCase') })
    if ($sm.fenster) { $smFenster = [int]$sm.fenster }
    if ($sm.hinweis) { $smHinweis = [string]$sm.hinweis }
} catch { }

# ---------------------------------------------------------------- Hilfsfunktionen

function Get-Wert($obj, [string]$name) {
    if ($null -eq $obj) { return $null }
    $p = $obj.PSObject.Properties[$name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

function Get-HostArt([string]$h) {
    $h = $h.ToLower().TrimEnd('.')
    if ($h -match $ausnahmeRe) { return "frei" }
    if ($h -match $pwHostRe -or $h -match $kontoHostRe) { return "pw" }
    if ($h -match $postHostRe) { return "post" }
    if ($h -match $finanzListeRe -or $h -match $kantonalRe) { return "geld" }
    $labels = $h -split '\.'
    if ($labels.Count -ge 2 -and (($labels[0..($labels.Count - 2)] -join '.') -match $bankWortRe)) { return "geld" }
    return "frei"
}

function Get-Ziel([string]$url) {
    # "geld:<host>", "pw:<adresse>", "post:<host>", "anmeldung:<host>" (Anmelde- oder Kontoseite), "frei:<host>" oder "?"
    if ([string]::IsNullOrWhiteSpace($url)) { return "?" }
    $u = $url.Trim()
    if ($u -match $pwUrlRe) { return ("pw:" + $u) }
    if ($u -notmatch '^[a-zA-Z][a-zA-Z0-9+.\-]*:') { $u = "https://" + $u }
    try { $x = [uri]$u } catch { return "?" }
    $h = $x.Host.ToLower()
    if ([string]::IsNullOrEmpty($h)) { return ("frei:" + $x.Scheme) }
    $art = Get-HostArt $h
    if ($art -eq "frei" -and (($h + $x.AbsolutePath) -match $kontoPfadRe)) { $art = "pw" }
    if ($art -eq "frei" -and (($h + $x.AbsolutePath) -match $postPfadRe)) { $art = "post" }
    if ($art -eq "frei" -and (($h + $x.AbsolutePath) -match $anmeldungRe)) { $art = "anmeldung" }
    return ($art + ":" + $h)
}

function Test-Sicherheitslink([string]$url) {
    # Anmelde-, Bestaetigungs- und Passwortlinks mit Einmal-Token (aus Mails): nie aufrufen.
    try { $x = [uri]$url } catch { return $false }
    if ($x.Host -match '^(localhost|127\.0\.0\.1|\[::1\])$') { return $false }
    $teil = [uri]::UnescapeDataString($x.AbsolutePath + '?' + $x.Query)
    if ($teil -notmatch $linkWortRe) { return $false }
    foreach ($s in ($teil -split '[/?&=#]')) { if ($s -match '^[A-Za-z0-9_\-.~+]{24,}$' -and $s -match '\d' -and $s -match '[A-Za-z]') { return $true } }
    return $false
}

function Test-TextFinanz([string]$text) {
    if ($text -match '(?i)(chrome|edge|brave|opera|vivaldi)://(password-manager|settings/(passwords|autofill|payments)|wallet)') { return $true }
    foreach ($m in [regex]::Matches($text, '(?i)(?<![a-z0-9.@-])((?:[a-z0-9-]+\.)+([a-z]{2,10}))(?![a-z0-9-])')) {
        if ($m.Groups[2].Value -match $dateiEndung) { continue }
        if ((Get-HostArt $m.Groups[1].Value) -ne "frei") { return $true }
    }
    return $false
}

function Test-Gesperrt([string]$ziel) { return ($ziel.StartsWith("geld:") -or $ziel.StartsWith("pw:") -or $ziel.StartsWith("post:")) }

function Get-SmTreffer([string]$t) {
    # Ein Muster zaehlt nur mit Beleg im Umkreis (Code, Link mit Token, Klick-Aufforderung); so schlaegt eine
    # Anleitung, die das Wort nur erwaehnt, nicht an. Ohne Belegliste zaehlt jedes Muster.
    $treffer = New-Object System.Collections.ArrayList
    foreach ($r in $script:smMuster) {
        foreach ($m in $r.Matches($t)) {
            $ok = ($script:smBeleg.Count -eq 0)
            if (-not $ok) {
                $a = [Math]::Max(0, $m.Index - $script:smFenster); $e = [Math]::Min($t.Length, $m.Index + $m.Length + $script:smFenster)
                $umkreis = $t.Substring($a, $e - $a)
                foreach ($b in $script:smBeleg) { if ($b.IsMatch($umkreis)) { $ok = $true; break } }
            }
            if ($ok) { [void]$treffer.Add($m) }
        }
    }
    return , $treffer
}

function Test-Sicherheitsmail([string]$t) { return ((Get-SmTreffer $t).Count -gt 0) }

function Hide-Sicherheitsmail([string]$t) {
    # Schwaerzt rund um jeden Treffer 1200 Zeichen (auf Zeilengrenzen erweitert), damit Code und Link mitgehen.
    $bereiche = New-Object System.Collections.ArrayList
    foreach ($m in (Get-SmTreffer $t)) {
        $a = [Math]::Max(0, $m.Index - 1200); $e = [Math]::Min($t.Length, $m.Index + $m.Length + 1200)
        $z = $t.LastIndexOf("`n", [Math]::Max(0, $a)); if ($z -ge 0 -and $a -gt 0) { $a = $z + 1 }
        $z2 = $t.IndexOf("`n", [Math]::Min($t.Length - 1, [Math]::Max(0, $e - 1))); if ($z2 -ge 0) { $e = $z2 } else { $e = $t.Length }
        [void]$bereiche.Add(@($a, $e))
    }
    if ($bereiche.Count -eq 0) { return $t }
    $sortiert = @($bereiche | Sort-Object { $_[0] })
    $sb = New-Object System.Text.StringBuilder
    $pos = 0; $curA = -1; $curE = -1
    foreach ($b in $sortiert) {
        if ($curA -lt 0) { $curA = $b[0]; $curE = $b[1]; continue }
        if ($b[0] -le $curE) { $curE = [Math]::Max($curE, $b[1]); continue }
        [void]$sb.Append($t.Substring($pos, $curA - $pos)).Append($script:smHinweis); $pos = $curE
        $curA = $b[0]; $curE = $b[1]
    }
    [void]$sb.Append($t.Substring($pos, $curA - $pos)).Append($script:smHinweis)
    if ($curE -lt $t.Length) { [void]$sb.Append($t.Substring($curE)) }
    return $sb.ToString()
}

$script:geschwaerzt = $false
function Edit-Ausgabe($o) {
    # Geht die Antwort eines Werkzeugs rekursiv durch und schwaerzt jede Zeichenkette mit Sicherheitsmail. Die
    # Struktur bleibt gleich, damit die Antwort zum Ausgabeformat des Werkzeugs passt (updatedToolOutput).
    if ($null -eq $o) { return $null }
    if ($o -is [string]) {
        if (Test-Sicherheitsmail $o) { $script:geschwaerzt = $true; return (Hide-Sicherheitsmail $o) }
        return $o
    }
    if ($o -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in @($o.PSObject.Properties)) { $p.Value = Edit-Ausgabe $p.Value }
        return $o
    }
    if ($o -is [System.Array]) {
        for ($i = 0; $i -lt $o.Count; $i++) { $o[$i] = Edit-Ausgabe $o[$i] }
        Write-Output -NoEnumerate $o
        return
    }
    return $o
}

# Schreibt eine Zustandsdatei ueber eine Zwischendatei: Laufen dieselbe Sperre aus dem Repo und aus der Kopie
# gleichzeitig (Leo-Kind ohne Haertung), liest keine von beiden je eine halb geschriebene Datei.
function Save-Datei([string]$ziel, [string]$text) {
    New-Item -ItemType Directory -Force (Split-Path $ziel) | Out-Null
    $tmp = $ziel + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    [IO.File]::WriteAllText($tmp, $text, (New-Object System.Text.UTF8Encoding($false)))
    try {
        if (Test-Path -LiteralPath $ziel) { [IO.File]::Replace($tmp, $ziel, $null) } else { [IO.File]::Move($tmp, $ziel) }
    } catch {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        throw
    }
}

function Read-Tabs {
    $t = @{}
    if ($script:tabsDatei -and (Test-Path -LiteralPath $script:tabsDatei)) {
        $o = [IO.File]::ReadAllText($script:tabsDatei, [Text.Encoding]::UTF8) | ConvertFrom-Json
        foreach ($p in $o.PSObject.Properties) { $t[$p.Name] = [string]$p.Value }
    }
    return $t
}

function Save-Tabs($t) { Save-Datei $script:tabsDatei ($t | ConvertTo-Json -Compress) }

function Test-BrowserAktion([string]$fam, [string]$name, $inp, $tabs) {
    $tabId = [string](Get-Wert $inp "tabId")
    $front = "$fam`:_front"
    $frontId = [string]$tabs["$fam`:_frontid"]
    $key = if ($tabId) { "$fam`:$tabId" } else { $front }
    $zielTab = if ($tabs.ContainsKey($key)) { $tabs[$key] } else { "?" }

    if ($name -eq "javascript_tool") {
        $js = [string](Get-Wert $inp "text")
        if ($js -match $jsPwRe -or $js -match $credRe -or (Test-TextFinanz $js)) { return ("Javascript an Anmeldedaten oder Geldplattformen. " + $grund) }
    }
    # Codes aus Sicherheitsmails nie weiterverwenden: kein Eintippen von Einmalcodes
    $eingabe = ""
    if ($name -eq "form_input") { $eingabe = [string](Get-Wert $inp "value") }
    if ($name -eq "computer" -and [string](Get-Wert $inp "action") -eq "type") { $eingabe = [string](Get-Wert $inp "text") }
    if ($eingabe -and ($eingabe -match $codeRe -or ($eingabe -match $kurzCodeRe -and $zielTab.StartsWith("anmeldung:")))) {
        return ("Eingabe sieht aus wie ein Einmal- oder Wiederherstellungscode. Solche Codes gibt nur der Besitzer selbst ein. " + $grund)
    }
    switch -Regex ($name) {
        '^(navigate|preview_start|tabs_create(_mcp)?)$' {
            $url = [string](Get-Wert $inp "url")
            if ($name -eq "navigate" -and ($url -eq "back" -or $url -eq "forward")) {
                $tabs[$key] = "?"; if ($tabId -and $tabId -eq $frontId) { $tabs[$front] = "?" }; return ""
            }
            if (-not $url) {
                if ($name -ne "navigate") { $tabs[$front] = "frei:about:blank"; $tabs["$fam`:_frontid"] = "" }
                return ""
            }
            $ziel = Get-Ziel $url
            if ($ziel.StartsWith("post:")) { return ("Webmail im Browser ist gesperrt (" + $ziel.Substring(5) + "): Mails liest der Agent nur ueber Leseskripte oder Connectoren, deren Ausgabe die Sperre auf Sicherheitsmails prueft. " + $grund) }
            if (Test-Gesperrt $ziel) { return ("Aufruf von " + $ziel.Substring($ziel.IndexOf(':') + 1) + ". " + $grund) }
            $voll = if ($url -match '^[a-zA-Z][a-zA-Z0-9+.\-]*:') { $url } else { "https://" + $url }
            if (Test-Sicherheitslink $voll) { return ("Das sieht aus wie ein Anmelde-, Bestaetigungs- oder Passwortlink mit Einmal-Token. Solche Links oeffnet nur der Besitzer. " + $grund) }
            if ($name -eq "navigate") {
                $tabs[$key] = $ziel
                if ($tabId) { if ($tabId -eq $frontId) { $tabs[$front] = $ziel } elseif (-not $frontId) { $tabs[$front] = "?" } }
            } else { $tabs[$front] = $ziel; $tabs["$fam`:_frontid"] = "" }
            return ""
        }
        '^tabs_select$' {
            $tabs["$fam`:_frontid"] = $tabId
            $tabs[$front] = if ($tabs.ContainsKey("$fam`:$tabId")) { $tabs["$fam`:$tabId"] } else { "?" }
            if (Test-Gesperrt $tabs[$front]) { return ("Dieser Tab zeigt eine Geldplattform, Webmail oder Passwortverwaltung. " + $grund) }
            return ""
        }
        '^(computer|form_input|find|read_page|get_page_text|javascript_tool|file_upload|upload_image|scroll_to)$' {
            if (Test-Gesperrt $zielTab) { return ("Dieser Tab zeigt " + $zielTab.Substring($zielTab.IndexOf(':') + 1) + ". " + $grund) }
            return ""
        }
        default { return "" }
    }
}

# ---------------------------------------------------------------- Audit

function Get-RepoPfad {
    # Das Repo des Leo-Kinds: ausdruecklich (-Repo), vom Verteiler gesetzt (LEO_REPO_PFAD, wenn die Sperre aus der
    # Kopie laeuft) oder zwei Ebenen ueber diesem Skript (Lauf aus dem Repo).
    if ($Repo) { return $Repo.TrimEnd('\', '/') }
    if ($env:LEO_REPO_PFAD -and (Test-Path -LiteralPath (Join-Path $env:LEO_REPO_PFAD 'AGENTS.md'))) { return $env:LEO_REPO_PFAD.TrimEnd('\', '/') }
    $kandidat = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    if ($kandidat -and (Test-Path -LiteralPath (Join-Path (Join-Path $kandidat '00_INDEX') 'scripts')) -and (Test-Path -LiteralPath (Join-Path $kandidat 'AGENTS.md'))) { return $kandidat }
    return ''
}

function Get-Hash([string]$p) {
    # .NET statt Get-FileHash: Windows PowerShell 5.1, aus PowerShell 7 gestartet, findet Get-FileHash nicht.
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($p))) -replace '-', '') } finally { $sha.Dispose() }
}

# Orte der Browser- und Mailprofile je Plattform
function Get-BrowserOrte {
    if ($istWindows) {
        return @{
            chromium = @(@{ n = 'Chrome'; p = (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data') }, @{ n = 'Edge'; p = (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data') }, @{ n = 'Brave'; p = (Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data') })
            firefox = @((Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'))
            mail = @((Join-Path $env:APPDATA 'Thunderbird\Profiles'))
        }
    }
    if ($istMac) {
        $as = Join-Path $heim 'Library/Application Support'
        return @{
            chromium = @(@{ n = 'Chrome'; p = (Join-Path $as 'Google/Chrome') }, @{ n = 'Edge'; p = (Join-Path $as 'Microsoft Edge') }, @{ n = 'Brave'; p = (Join-Path $as 'BraveSoftware/Brave-Browser') })
            firefox = @((Join-Path $as 'Firefox/Profiles'))
            mail = @((Join-Path $heim 'Library/Thunderbird/Profiles'))
        }
    }
    $cfg = Join-Path $heim '.config'
    return @{
        chromium = @(@{ n = 'Chrome'; p = (Join-Path $cfg 'google-chrome') }, @{ n = 'Chromium'; p = (Join-Path $cfg 'chromium') }, @{ n = 'Edge'; p = (Join-Path $cfg 'microsoft-edge') }, @{ n = 'Brave'; p = (Join-Path $cfg 'BraveSoftware/Brave-Browser') })
        firefox = @((Join-Path $heim '.mozilla/firefox'))
        mail = @((Join-Path $heim '.thunderbird'))
    }
}

# Rechte und Widerruf aus einer Zeile von 10_System\Zugaenge.md. Die Spalten werden ueber die Kopfzeile gefunden
# ("Rechte", "Widerruf", erste Spalte = System), damit jede Tabellenform eines Kinds passt.
function Get-ZugangsSpalten([string]$text) {
    $sp = @{ system = 1; rechte = -1; widerruf = -1 }
    foreach ($z in ($text -split "`n")) {
        if ($z -notmatch '^\|') { continue }
        $teile = @($z -split '\|' | ForEach-Object { $_.Trim() })
        for ($i = 0; $i -lt $teile.Count; $i++) {
            if ($teile[$i] -match '(?i)^rechte') { $sp.rechte = $i }
            if ($teile[$i] -match '(?i)^widerruf') { $sp.widerruf = $i }
        }
        if ($sp.rechte -ge 0) { break }
    }
    return $sp
}

function Invoke-Audit {
    $befunde = New-Object System.Collections.ArrayList
    function Add-Befund([string]$id, [string]$schwere, [string]$titel, [string]$befund, [string]$behebung) {
        [void]$befunde.Add([pscustomobject]@{ id = $id; schwere = $schwere; titel = $titel; befund = $befund; behebung = $behebung })
    }
    $repoPfad = Get-RepoPfad
    $profil = $heim
    $orte = Get-BrowserOrte

    # A1 Passwortspeicher der Browser
    $pwSpeicher = @()
    foreach ($b in $orte.chromium) {
        if (-not (Test-Path -LiteralPath $b.p)) { continue }
        foreach ($pr in @(Get-ChildItem -LiteralPath $b.p -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' })) {
            $speicher = @(@('Login Data', 'Login Data For Account') | ForEach-Object { Join-Path $pr.FullName $_ } | Where-Object { Test-Path -LiteralPath $_ })
            if ($speicher.Count -eq 0) { continue }
            $kb = [int](($speicher | ForEach-Object { (Get-Item -LiteralPath $_).Length } | Measure-Object -Sum).Sum / 1024)
            $pwSpeicher += ($b.n + " " + $pr.Name + " (" + $kb + " KB)")
        }
    }
    if ($pwSpeicher.Count -gt 0) {
        Add-Befund ("browser-passwort:" + ($pwSpeicher -replace ' \(\d+ KB\)', '' -join ',')) "mittel" ("Passwortspeicher in Browsern: " + ($pwSpeicher -join ', ')) `
            "Jeder Browser legt seinen Passwortspeicher als Datei ins Benutzerprofil; ob Eintraege darin sind, prueft der Audit bewusst nicht (er oeffnet die Datei nicht). Jeder Prozess unter deinem Konto kann die Datei kopieren; die Sperre blockt die bekannten Wege fuer den Agenten, aber nur textbasiert." `
            "Passwoerter in einen Passwortmanager mit Masterpasswort verschieben und im Browser loeschen. Chrome, Edge und Brave: Menue (drei Punkte), Passwoerter und Autofill, Passwortmanager, Einstellungen, 'Speichern von Passwoertern anbieten' ausschalten; danach unter 'Passwoerter' alle Eintraege loeschen. Pro Profil wiederholen."
    }
    foreach ($ff in $orte.firefox) {
        foreach ($pr in @(Get-ChildItem -LiteralPath $ff -Directory -ErrorAction SilentlyContinue)) {
            if (Test-Path -LiteralPath (Join-Path $pr.FullName 'logins.json')) {
                Add-Befund ("browser-passwort:Firefox:" + $pr.Name) "mittel" ("Firefox, Profil " + $pr.Name + ": gespeicherte Passwoerter") `
                    "Firefox speichert Passwoerter im Profil (logins.json); ohne Hauptpasswort sind sie fuer jeden Prozess unter deinem Konto entschluesselbar." `
                    "In Firefox unter Einstellungen, Datenschutz und Sicherheit, ein Hauptpasswort setzen oder die Passwoerter in einen Passwortmanager verschieben und loeschen."
            }
        }
    }

    # A2 Browser-Steuerung in einem Profil mit angemeldeten Sitzungen
    $cd = ($orte.chromium | Where-Object { $_.n -eq 'Chrome' } | Select-Object -First 1).p
    $gesteuert = @()
    foreach ($pr in @(Get-ChildItem -LiteralPath $cd -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' })) {
        $ext = Join-Path $pr.FullName 'Extensions'
        $gefunden = $false
        foreach ($m in @(Get-ChildItem -LiteralPath $ext -Recurse -Filter 'manifest.json' -Depth 2 -ErrorAction SilentlyContinue)) {
            try {
                $t = [IO.File]::ReadAllText($m.FullName)
                if ($t -match '"name"\s*:\s*"[^"]*Claude' -or $m.FullName -match 'fcoeoabgfenejglbffodgkkbkcdhcgfn') { $gefunden = $true; break }
                if ($t -match '"name"\s*:\s*"__MSG_(\w+)__"') {
                    $key = $matches[1]
                    $loc = Join-Path (Join-Path (Join-Path $m.DirectoryName '_locales') 'en') 'messages.json'
                    if ((Test-Path -LiteralPath $loc) -and ([IO.File]::ReadAllText($loc) -match ('"' + $key + '"\s*:\s*\{\s*"message"\s*:\s*"[^"]*Claude'))) { $gefunden = $true; break }
                }
            } catch { }
        }
        if ($gefunden) { $gesteuert += $pr }
    }
    # Anzeigenamen und Chrome-Anmeldung aus der Profilliste des Browsers (nur Name und Konto, nichts Geheimes)
    $profilInfo = @{}
    try {
        $lsj = [IO.File]::ReadAllText((Join-Path $cd 'Local State')) | ConvertFrom-Json
        foreach ($p in $lsj.profile.info_cache.PSObject.Properties) { $profilInfo[$p.Name] = $p.Value }
    } catch { }
    $klickProfil = "Ein eigenes Chrome-Profil nur fuer den Agenten anlegen: Chrome, Profilbild oben rechts, 'Hinzufuegen', 'Ohne Konto fortfahren'. Die Erweiterung Claude in Chrome nur dort installieren und in allen anderen Profilen unter chrome://extensions entfernen."
    foreach ($pr in $gesteuert) {
        $info = $profilInfo[$pr.Name]
        $anzeige = if ($info -and $info.name) { [string]$info.name } else { $pr.Name }
        $sync = if ($info) { [string]$info.user_name } else { '' }
        $pref = $null; try { $pref = [IO.File]::ReadAllText((Join-Path $pr.FullName 'Preferences')) | ConvertFrom-Json } catch { }
        $webKonten = @(); if ($pref) { $webKonten = @($pref.account_info | ForEach-Object { ([string]$_.email) -replace '^[^@]*@', '@' } | Where-Object { $_ } | Select-Object -Unique) }
        $wer = "'" + $anzeige + "' (" + $pr.Name + ")"
        if ($gesteuert.Count -gt 1 -or $sync) {
            Add-Befund ("browser-steuerung:" + $pr.Name) "hoch" ("Claude in Chrome im Profil " + $wer + $(if ($sync) { ", mit Chrome synchronisiert" } else { ", eines von mehreren Profilen mit der Erweiterung" })) `
                "In diesem Profil liegen die Sitzungen der Seiten, bei denen du angemeldet bist; eine angemeldete Sitzung hat die Zwei-Faktor-Pruefung schon hinter sich. Mit Synchronisation kommen Passwoerter, Verlauf und Sitzungen deiner anderen Geraete dazu. Die Sperre blockt Geldplattformen, Webmail, Passwortverwaltungen und Konto-Sicherheitsseiten, aber nicht jede Seite mit Konto." `
                $klickProfil
            continue
        }
        # Genau ein Profil mit der Erweiterung, nicht synchronisiert: das Agentenprofil. Hier wird seine Einrichtung geprueft.
        if ($webKonten.Count -gt 0) {
            Add-Befund ("agentenprofil-konto:" + $pr.Name) "mittel" ("Agentenprofil " + $wer + ": im Web bei Google angemeldet (" + ($webKonten -join ', ') + ")") `
                "Mit dieser Anmeldung erreicht der Agent im Browser alle Google-Dienste des Kontos. Gmail im Web, Kontoeinstellungen und Passwortverwaltung sperrt die Sperre; Drive, Docs und Kalender bleiben offen." `
                "Nur angemeldet lassen, wenn der Agent dort Google-Dienste im Browser bedienen soll. Sonst im Profil auf google.com oben rechts aufs Profilbild, 'Abmelden'."
        } else {
            Add-Befund ("agentenprofil:" + $pr.Name) "info" ("Agentenprofil " + $wer + " ohne Google-Anmeldung") "Claude in Chrome laeuft nur in diesem Profil. Bei welchen anderen Seiten du dort angemeldet bist, prueft der Audit nicht (er oeffnet keine Cookies)." "Im Agentenprofil nirgends mit Bank, Mail oder Passwortmanager anmelden."
        }
        $pwAn = (-not $pref) -or ((Get-Wert $pref 'credentials_enable_service') -ne $false)
        $af = if ($pref) { Get-Wert $pref 'autofill' } else { $null }
        $adrAn = (Get-Wert $af 'profile_enabled') -ne $false
        $kartAn = (Get-Wert $af 'credit_card_enabled') -ne $false
        if ($pwAn -or $adrAn -or $kartAn) {
            $was = @(); if ($pwAn) { $was += 'Passwoerter speichern' }; if ($adrAn) { $was += 'Adressen' }; if ($kartAn) { $was += 'Zahlungsmethoden' }
            Add-Befund ("agentenprofil-autofill:" + $pr.Name) "mittel" ("Agentenprofil " + $wer + ": " + ($was -join ', ') + " eingeschaltet") `
                "Was der Browser dort speichert und automatisch ausfuellt, steht dem Agenten in jedem Formular zur Verfuegung." `
                "Im Agentenprofil: Chrome-Menue (drei Punkte), 'Passwoerter und Autofill'. Unter 'Google Passwortmanager', 'Einstellungen' den Schalter 'Speichern von Passwoertern anbieten' und 'Automatisch anmelden' ausschalten. Unter 'Zahlungsmethoden' den Schalter 'Zahlungsmethoden speichern und ausfuellen' ausschalten. Unter 'Adressen und mehr' den Schalter 'Adressen speichern und ausfuellen' ausschalten."
        }
        # Erweiterungen, die eine andere Software ins Profil gelegt hat und die auf Freigabe warten (Chrome-Sperrgrund 8192)
        try {
            $sp = [IO.File]::ReadAllText((Join-Path $pr.FullName 'Secure Preferences')) | ConvertFrom-Json
            $wartend = @()
            foreach ($e in $sp.extensions.settings.PSObject.Properties) {
                if (@($e.Value.disable_reasons) -contains 8192) { $n = [string]$e.Value.manifest.name; $wartend += $(if ($n) { $n } else { $e.Name }) }
            }
            if ($wartend.Count -gt 0) {
                Add-Befund ("agentenprofil-fremd:" + $pr.Name) "mittel" ("Agentenprofil " + $wer + ": Erweiterungen von aussen warten auf Freigabe: " + ($wartend -join '; ')) `
                    "Andere Software auf dem Rechner hat diese Erweiterungen ins Profil gelegt; Chrome sperrt sie, bis du zustimmst. Eine Erweiterung im Agentenprofil sieht jede Seite, die der Agent oeffnet." `
                    "Nicht zustimmen. Im Agentenprofil das Chrome-Menue (drei Punkte) oeffnen, oben auf den Eintrag 'Neue Erweiterung hinzugefuegt (...)' klicken und 'Aus Chrome entfernen' waehlen, fuer jede einzeln."
            }
        } catch { }
    }

    # A3 Lokale Mailspeicher (Sicherheitsmails darin)
    $mail = @()
    foreach ($pfad in $orte.mail) {
        if (Test-Path -LiteralPath $pfad) { $mail += @(Get-ChildItem -LiteralPath $pfad -Directory -ErrorAction SilentlyContinue | Where-Object { (Test-Path (Join-Path $_.FullName 'ImapMail')) -or (Test-Path (Join-Path $_.FullName 'Mail')) } | ForEach-Object { 'Thunderbird ' + $_.Name }) }
    }
    if ($istWindows -and $env:LOCALAPPDATA -and @(Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Microsoft\Outlook') -Filter '*.ost' -ErrorAction SilentlyContinue).Count -gt 0) { $mail += 'Outlook (OST)' }
    if ($istMac -and (Test-Path -LiteralPath (Join-Path $heim 'Library/Mail'))) { $mail += 'Apple Mail' }
    if ($mail.Count -gt 0) {
        Add-Befund "mailspeicher" "mittel" ("Lokale Mailspeicher lesbar: " + ($mail -join ', ')) `
            "Codes und Anmeldelinks, die per Mail kommen, liegen dort fuer jeden Prozess lesbar. Die Sperre blendet Sicherheitsmails in Ausgaben aus; ein eigenes Skript, das die Dateien direkt oeffnet und nur verwendet statt ausgibt, faengt sie nicht ab." `
            "Den Zweitfaktor bei Geldplattformen, Mailkonten und Passwortmanager auf App, Passkey oder SMS umstellen, nicht per Mail. Wo ein Dienst nur Mail-Codes kennt, das Konto auf eine Adresse legen, deren Postfach der Agent nicht liest."
    }

    # A4 Git-Anmeldung im Credential-Speicher
    $helper = ''
    try { $alt = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $helper = (& git config --global --get credential.helper 2>$null); $ErrorActionPreference = $alt } catch { }
    if ($helper) {
        Add-Befund "git-credential" "mittel" ("Git-Anmeldung im Credential-Speicher (" + $helper + ")") `
            "Jeder Prozess unter deinem Konto kann das gespeicherte Git-Login abrufen und damit in alle Repos des Kontos pushen. Die Sperre blockt den Abruf ueber git credential im Agenten." `
            "Fuer den Agenten ein feingranulares Token nur fuer seine Repos anlegen (GitHub, Settings, Developer settings, Fine-grained tokens) oder einen SSH-Schluessel mit Passphrase verwenden."
    }

    # A5 Passwortdatenbanken ausserhalb der Sperrliste
    $gesperrt = @()
    if ($repoPfad) {
        $gp = Join-Path (Join-Path $repoPfad '00_INDEX') 'gesperrte-pfade.txt'
        if (Test-Path -LiteralPath $gp) { $gesperrt = @(Get-Content -LiteralPath $gp -Encoding UTF8 | ForEach-Object { ($_ -split '#')[0].Trim() } | Where-Object { $_ -and $_ -ne 'keine' -and $_ -ne 'none' } | ForEach-Object { $_ -replace '^~', $profil }) }
    }
    $suchorte = @('Documents', 'Desktop', 'Downloads') | ForEach-Object { Join-Path $profil $_ }
    $suchorte += @(Get-ChildItem -LiteralPath $profil -Directory -Filter 'OneDrive*' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    # Cloud-Ablagen, die als Laufwerk eingebunden sind (Google Drive fuer den Desktop: "Meine Ablage" bzw. "My Drive")
    if ($istWindows) {
        foreach ($lw in @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
            foreach ($n in @('Meine Ablage', 'My Drive')) { $p = Join-Path $lw.Root $n; if (Test-Path -LiteralPath $p) { $suchorte += $p } }
        }
    }
    $dbs = @()
    foreach ($o in $suchorte) {
        if (-not (Test-Path -LiteralPath $o)) { continue }
        $dbs += @(Get-ChildItem -LiteralPath $o -Recurse -Depth 3 -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.kdbx', '.opvault', '.1pux') } | ForEach-Object { $_.FullName })
    }
    $offen = @($dbs | Where-Object { $d = $_; -not ($gesperrt | Where-Object { $d.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }) })
    if ($offen.Count -gt 0) {
        Add-Befund "passwortdatenbank" "info" ("Passwortdatenbank ausserhalb der gesperrten Pfade: " + ($offen -join '; ')) `
            "Die Datei ist mit dem Masterpasswort verschluesselt, und Schluesseldateien sind fuer den Agenten gesperrt. Liegt sie ausserhalb der Sperrliste, ist nur das Dateimuster der Schutz." `
            "Den Ordner mit freigeben.ps1 -Sperren in 00_INDEX\gesperrte-pfade.txt eintragen (macht nur der Besitzer, in seinem eigenen Fenster)."
    }

    # A6 Geheimnisse in Umgebungsvariablen (Windows: Benutzer und Rechner; macOS/Linux: die geerbte Umgebung)
    $bereiche = if ($istWindows) { @('User', 'Machine') } else { @('Process') }
    foreach ($bereich in $bereiche) {
        $vars = [Environment]::GetEnvironmentVariables($bereich)
        foreach ($k in $vars.Keys) {
            if ([string]$k -match '(?i)(token|secret|passw|api_?key|private_?key|access_?key|client_?secret|auth)') {
                $weg = if ($istWindows) { "[Environment]::SetEnvironmentVariable('" + $k + "', `$null, '" + $bereich + "')" } else { "die Zeile export " + $k + "=... aus der Startdatei der Shell (etwa ~/.zshrc) entfernen" }
                Add-Befund ("umgebung:" + $bereich + ":" + $k) "hoch" ("Moegliches Geheimnis in der Umgebungsvariable " + $k + " (" + $bereich + ")") `
                    "Umgebungsvariablen erbt jeder Prozess, auch jede Shell des Agenten; ein einziger Befehl gibt den Wert aus." `
                    ("Wert in eine Datei verschieben, die nur das Skript liest, und die Variable loeschen: " + $weg)
            }
        }
    }

    # A7 Windows-Anmeldeinformationen
    if ($istWindows) {
        try {
            $ziele = @(& cmdkey /list 2>$null | Where-Object { $_ -match '(?i)^\s*(target|ziel)\s*:' } | ForEach-Object { ($_ -split ':', 2)[1].Trim() })
            if ($ziele.Count -gt 0) {
                Add-Befund "windows-anmeldeinformationen" "info" ("Windows-Anmeldeinformationsverwaltung: " + $ziele.Count + " Eintraege") `
                    ("Gespeicherte Anmeldungen (unter anderem " + (($ziele | Select-Object -First 6) -join ', ') + ") sind ueber DPAPI fuer jeden Prozess unter deinem Konto abrufbar. Die Sperre blockt die bekannten Abrufwege im Agenten.") `
                    "Nicht mehr gebrauchte Eintraege entfernen: Systemsteuerung, Anmeldeinformationsverwaltung, Windows-Anmeldeinformationen, Eintrag aufklappen, 'Entfernen'."
            }
        } catch { }
    }

    # A8 SSH-Schluessel
    $ssh = Join-Path $profil '.ssh'
    $schluessel = @(Get-ChildItem -LiteralPath $ssh -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^id_' -and $_.Extension -ne '.pub' })
    if ($schluessel.Count -gt 0) {
        Add-Befund "ssh-schluessel" "mittel" ("Private SSH-Schluessel: " + (($schluessel | ForEach-Object Name) -join ', ')) `
            "Ohne Passphrase genuegt die Datei, um sich bei jedem Server anzumelden, der den Schluessel kennt. Ob eine Passphrase gesetzt ist, prueft der Audit bewusst nicht (er oeffnet die Datei nicht)." `
            ("Passphrase setzen: ssh-keygen -p -f `"" + (Join-Path $ssh '<Dateiname>') + "`"")
    }

    # A9 Zugangsdaten von Cloud- und Entwicklerwerkzeugen im Klartext
    $klartext = @(
        @{ p = '.git-credentials'; w = 'Git-Zugangsdaten im Klartext' }, @{ p = '.netrc'; w = 'netrc mit Zugangsdaten' }, @{ p = '_netrc'; w = 'netrc mit Zugangsdaten' },
        @{ p = '.aws/credentials'; w = 'AWS-Zugangsschluessel' }, @{ p = '.azure/msal_token_cache.json'; w = 'Azure-Anmeldung' }, @{ p = '.kube/config'; w = 'Kubernetes-Zugang' },
        @{ p = '.docker/config.json'; w = 'Docker-Registry-Anmeldung' }, @{ p = '.npmrc'; w = 'npm-Token' }, @{ p = '.pypirc'; w = 'PyPI-Token' },
        @{ p = 'AppData/Roaming/gcloud/credentials.db'; w = 'Google-Cloud-Anmeldung' }, @{ p = '.config/gcloud/credentials.db'; w = 'Google-Cloud-Anmeldung' }
    )
    foreach ($k in $klartext) {
        $f = Join-Path $profil ($k.p -replace '/', [string][System.IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $f)) { continue }
        if ($k.p -in @('.npmrc', '.docker/config.json')) { try { if ([IO.File]::ReadAllText($f) -notmatch '(_authToken|"auth"\s*:)') { continue } } catch { continue } }
        Add-Befund ("klartext:" + $k.p) "hoch" ($k.w + ": " + $f) `
            "Diese Datei enthaelt einen Zugang im Klartext oder als lokale Sitzung; jeder Prozess unter deinem Konto kann ihn verwenden." `
            "Wird der Zugang nicht gebraucht: im Dienst abmelden bzw. das Token widerrufen und die Datei loeschen. Wird er gebraucht: auf die noetigen Rechte beschraenken und in 10_System\Zugaenge.md eintragen."
    }

    # A10 Wo die Sperren laufen: Haertung mit Adminrechten (verwaltete Einstellungen) oder Kopie im Benutzerprofil
    if ($repoPfad) {
        try {
            $lib = Join-Path (Join-Path $PSScriptRoot 'lib') 'arbeitsbereich.ps1'
            . $lib
            $ort = Get-HaertungsOrt $repoPfad
            $haertBefehl = if ($istWindows) { "powershell -NoProfile -ExecutionPolicy Bypass -File `"" + (Join-Path $repoPfad '00_INDEX\scripts\sperre-haerten.ps1') + "`"" } else { "sudo pwsh -NoProfile -File `"" + (Join-Path $repoPfad '00_INDEX/scripts/sperre-haerten.ps1') + "`"" }
            if (Test-Path -LiteralPath $ort.dropin) {
                $st = Get-HaertungsStand $repoPfad $ort
                if ($st.stand -eq 'veraltet') {
                    Add-Befund "haertung-veraltet" "hoch" ("Schutzkopie der Sperren veraltet: " + ($st.abweichend -join ', ')) `
                        "Diese Sperren oder Muster wirken erst, wenn die Schutzkopie erneuert ist; bis dahin gilt der alte Stand." `
                        ("Der Besitzer fuehrt in seinem eigenen Fenster aus: " + $haertBefehl)
                }
            } else {
                $po = Get-ProfilOrt $repoPfad
                $eingetragen = (Test-Path -LiteralPath $po.settings) -and ([IO.File]::ReadAllText($po.settings)).Contains((ConvertTo-Json $po.kopie).Trim('"'))
                if (-not $eingetragen) {
                    Add-Befund "sperren-nur-im-repo" "mittel" "Sperren gelten nur in diesem Repo" `
                        "In jedem anderen Projekt arbeitet der Agent ohne Sperren, auch ohne diese." `
                        ("Einrichten mit: " + $(if ($istWindows) { 'powershell -NoProfile -ExecutionPolicy Bypass -File' } else { 'pwsh -NoProfile -File' }) + " `"" + (Join-Path (Join-Path (Join-Path $repoPfad '00_INDEX') 'scripts') 'hooks-einrichten.ps1') + "`" (der Agent darf es selbst ausfuehren, braucht Netz).")
                } elseif (-not (Test-Path -LiteralPath (Join-Path $po.kopie '00_INDEX/scripts/guard-finanzen.ps1'))) {
                    Add-Befund "kopie-ohne-finanzsperre" "info" "Kopie der Sperren fuer alle Projekte noch ohne Finanz-Sperre" `
                        "Die Kopie stammt aus einer Version vor 6.1; in anderen Projekten fehlt diese Sperre noch." `
                        "Nichts zu tun: Der naechste Start von Claude Code im Repo erneuert die Kopie, sobald das Update abgeschlossen ist."
                }
                Add-Befund "haertung-ohne-admin" "info" "Sperren nicht mit Adminrechten gehaertet" `
                    "Die Sperren laufen aus einer Kopie im Benutzerprofil. Gegen ein Versehen genuegt das; mit Absicht koennte ein Prozess unter deinem Konto sie aendern." `
                    ("Wer das ausschliessen will, fuehrt in seinem eigenen Fenster aus: " + $haertBefehl)
            }
        } catch { }
    }

    # A11 Benutzerkontensteuerung
    if ($istWindows) {
        try {
            $uac = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction Stop
            if ($uac.EnableLUA -eq 0) {
                Add-Befund "uac-aus" "hoch" "Benutzerkontensteuerung ausgeschaltet" "Ohne Benutzerkontensteuerung kann jeder Prozess, auch der Agent, die Schutzkopie der Sperren aendern." "Systemsteuerung, Benutzerkonten, 'Einstellungen der Benutzerkontensteuerung aendern', Regler mindestens auf die zweite Stufe von oben, Neustart."
            } elseif ($uac.ConsentPromptBehaviorAdmin -eq 0) {
                Add-Befund "uac-ohne-rueckfrage" "hoch" "Benutzerkontensteuerung erhoeht ohne Rueckfrage" "Ein Prozess mit Administratorkonto bekommt Adminrechte ohne Klick; damit ist die Schutzkopie der Sperren nicht geschuetzt." "Systemsteuerung, Benutzerkonten, 'Einstellungen der Benutzerkontensteuerung aendern', Regler mindestens auf die zweite Stufe von oben."
            }
        } catch { }
    }

    # A12 Claude Code ohne Rueckfragen
    $cs = Join-Path (Join-Path $profil '.claude') 'settings.json'
    if (Test-Path -LiteralPath $cs) {
        try {
            $c = [IO.File]::ReadAllText($cs) | ConvertFrom-Json
            if ([string](Get-Wert (Get-Wert $c 'permissions') 'defaultMode') -eq 'bypassPermissions' -or (Get-Wert $c 'skipDangerousModePermissionPrompt') -eq $true) {
                Add-Befund "claude-bypass" "mittel" "Claude Code laeuft standardmaessig ohne Rueckfragen" "Im Modus bypassPermissions laeuft jeder Befehl ohne Bestaetigung; nur die Sperren halten dann noch etwas auf." "In $cs den Wert permissions.defaultMode entfernen oder auf 'default' bzw. 'auto' setzen."
            }
        } catch { }
    }

    # A13 Codex ohne diese Sperre
    if ($repoPfad -and (Test-Path -LiteralPath (Join-Path (Join-Path $repoPfad '.codex') 'hooks.json'))) {
        Add-Befund "codex-ohne-sperre" "info" "In Codex gilt die Finanz-Regel nur als Text" "Diese Sperre ist nur in Claude Code eingehaengt; ob Codex die Ereignisse nach dem Werkzeugaufruf und beim Sessionstart kennt, ist nicht belegt." "In Codex keine Browser-Steuerung und keine Aufgaben mit Geld, Mail oder Zugangsdaten."
    }

    # A14 Musterdatei fuer Sicherheitsmails
    if ($script:smMuster.Count -eq 0) {
        Add-Befund "sicherheitsmail-muster" "hoch" "Muster fuer Sicherheitsmails fehlen" ("Ohne " + $smDatei + " blendet die Sperre keine Sicherheitsmails aus.") "sicherheitsmail.json aus der eingespielten Version wiederherstellen (liegt im Repo unter 00_INDEX\scripts); ist die Haertung eingerichtet, danach sperre-haerten.ps1 erneut ausfuehren."
    }

    # B Zugaenge (Token, Schluessel) und ihre Rechte. Gefuehrt in 10_System\Zugaenge.md; fehlt die Datei, gilt
    # jeder Zugang als unregistriert, gewollt: Rechte und Widerruf eines unbekannten Zugangs sind unbekannt.
    $zugaenge = ''
    if ($repoPfad) { $zd = Join-Path (Join-Path $repoPfad '10_System') 'Zugaenge.md'; if (Test-Path -LiteralPath $zd) { $zugaenge = [IO.File]::ReadAllText($zd, [Text.Encoding]::UTF8) } }
    $spalten = Get-ZugangsSpalten $zugaenge
    $zeilen = @($zugaenge -split "`n" | Where-Object { $_ -match '^\|' -and $_ -notmatch '^\|\s*:?-' })
    # Weitere Zugangsregister in Nachbarprojekten mit eigener AGENTS.md (etwa ein zweites Repo desselben Besitzers)
    $weitere = @()
    if ($repoPfad) {
        foreach ($d in @(Get-ChildItem -LiteralPath (Split-Path -Parent $repoPfad) -Directory -ErrorAction SilentlyContinue | Where-Object { $_.FullName -ne $repoPfad -and (Test-Path -LiteralPath (Join-Path $_.FullName 'AGENTS.md')) })) {
            $weitere += @(Get-ChildItem -LiteralPath $d.FullName -Recurse -Depth 3 -File -Filter '*Zugaenge*.md' -ErrorAction SilentlyContinue)
        }
    }
    $schreibRe = '(?i)(schreib|senden|send\b|gmail\.send|(\u00e4|ae)ndern|anlegen|l(\u00f6|oe)schen|push|admin|write|hochladen|aktion|documents|spreadsheets|script\.projects|scope `drive`|alle Repos|Contents|kommentar|review)'
    $schreibRe = $schreibRe -replace '\\u00e4', [string][char]0xE4 -replace '\\u00f6', [string][char]0xF6
    $dateien = @(Get-ChildItem -LiteralPath $profil -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\.' -and $_.Name -match '(?i)(token|key|secret|credential|client|oauth|apikey|passw)' })
    foreach ($f in $dateien) {
        $zeile = @($zeilen | Where-Object { $_.Contains($f.Name) } | Select-Object -First 1)
        $rechte = ''; $widerruf = ''; $system = ''
        if ($zeile.Count -gt 0) {
            $sp = @($zeile[0] -split '\|' | ForEach-Object { $_.Trim() })
            if ($sp.Count -gt $spalten.system) { $system = $sp[$spalten.system] }
            if ($spalten.rechte -ge 0 -and $sp.Count -gt $spalten.rechte) { $rechte = $sp[$spalten.rechte] }
            if ($spalten.widerruf -ge 0 -and $sp.Count -gt $spalten.widerruf) { $widerruf = $sp[$spalten.widerruf] }
            if (-not $rechte) { $rechte = $zeile[0] }
        }
        $scopes = @(); $oauthClient = $false
        if ($f.Extension -eq '.json') {
            try {
                $jt = [IO.File]::ReadAllText($f.FullName)
                $j = $jt | ConvertFrom-Json
                if ((Get-Wert $j 'installed') -or (Get-Wert $j 'web')) { $oauthClient = $true }
                # Nur Google-Scopes sind hier deutbar; andere Dienste gehen ueber Zugaenge.md.
                if ($jt -match 'googleapis\.com/auth/') {
                    $s = Get-Wert $j 'scopes'; if (-not $s) { $s = (Get-Wert $j 'scope') -split ' ' }
                    $scopes = @($s | Where-Object { $_ } | ForEach-Object { ([string]$_) -replace '^https://www\.googleapis\.com/auth/', '' })
                }
            } catch { }
        }
        if ($oauthClient) {
            Add-Befund ("zugang-client:" + $f.Name) "info" ("OAuth-Client-Datei: " + $f.Name) "Kennung der App beim Anbieter, allein kein Zugang zu Daten; mit ihr lassen sich aber neue Anmeldungen anstossen." "Nur behalten, solange ein Token darauf aufbaut; sonst im Cloud-Projekt des Anbieters loeschen."
            continue
        }
        $schreibend = $null
        if ($scopes.Count -gt 0) { $schreibend = [bool](@($scopes | Where-Object { $_ -notmatch '(?i)(readonly|^openid$|userinfo|^email$|^profile$)' }).Count) }
        elseif ($rechte -match '(?i)^\s*(nur\s+)?lesen\s*(:|$|\()' -and $rechte -notmatch '(?i)schreiben\s+nur|und\s+schreiben') { $schreibend = $false }
        elseif ($rechte -match $schreibRe) { $schreibend = $true }
        elseif ($rechte -match '(?i)(\blesen\b|\bread\b)') { $schreibend = $false }
        $wer = if ($system) { $system } else { $f.Name }
        $detail = if ($scopes.Count -gt 0) { "Scopes: " + ($scopes -join ', ') } elseif ($rechte) { "Rechte laut Zugaenge.md: " + ($(if ($rechte.Length -gt 300) { $rechte.Substring(0, 300) + ' ...' } else { $rechte })) } else { "" }
        $anderes = $null
        if ($zeile.Count -eq 0) {
            foreach ($w in $weitere) {
                $wz = @(Get-Content -LiteralPath $w.FullName -Encoding UTF8 | Where-Object { $_.Contains($f.Name) })
                if ($wz.Count -gt 0) { $mitRechten = @($wz | Where-Object { $_ -match '(?i)rechte' }); $anderes = @{ datei = $w.FullName; zeile = $(if ($mitRechten.Count -gt 0) { $mitRechten[0] } else { $wz[0] }) }; break }
            }
        }
        if ($anderes) {
            $artW = if ($anderes.zeile -match $schreibRe) { 'schreibend' } elseif ($anderes.zeile -match '(?i)(\blesen\b|\bread\b)') { 'lesend' } else { 'unklar' }
            $weit = ($anderes.zeile -match '(?i)alle\s+scopes|scopes?\s*:?\s*"?alle|full\s+access|vollzugriff')
            Add-Befund ("zugang-anderes-register:" + $f.Name) $(if ($weit) { "hoch" } elseif ($artW -eq 'lesend') { "info" } else { "mittel" }) ("Zugang in anderem Register gefuehrt: " + $f.Name + $(if ($weit) { " (alle Rechte des Kontos)" } else { "" })) `
                ("Eingetragen in " + $anderes.datei + ". " + $(switch ($artW) { 'schreibend' { "Die Zeile dort nennt schreibende Rechte." } 'lesend' { "Die Zeile dort nennt nur lesende Rechte." } default { "Die Zeile dort nennt keine Rechte." } })) `
                $(if ($weit) { "Den Zugang durch einen mit den noetigen Rechten ersetzen und den alten im Dienst widerrufen; Weg im Register dort." } elseif ($artW -eq 'unklar') { "Im Register dort die Rechte und den Widerruf eintragen." } else { "Rechte dort pruefen; schreibende Rechte nur behalten, wenn sie gebraucht werden und ueber einen Weg mit Vorschau und Freigabe laufen." })
        } elseif ($zeile.Count -eq 0) {
            Add-Befund ("zugang-unregistriert:" + $f.Name) "hoch" ("Zugang ohne Eintrag in Zugaenge.md: " + $f.Name) `
                ("Die Datei " + $f.FullName + " sieht aus wie ein Schluessel oder Token, steht aber nicht in 10_System\Zugaenge.md. Rechte und Widerruf sind damit unbekannt. " + $detail) `
                "Klaeren, wofuer der Zugang ist: Eintrag in 10_System\Zugaenge.md mit Rechten und Widerruf (eine Tabelle mit den Spalten System, Datei, Rechte und Widerruf genuegt), oder im Zielsystem widerrufen und die Datei loeschen."
        } elseif ($schreibend -eq $true) {
            Add-Befund ("zugang-schreibend:" + $f.Name) "mittel" ("Zugang mit schreibenden Rechten: " + $wer) `
                ($f.Name + ". " + $detail) `
                ("Pruefen, ob das Schreiben noch gebraucht wird. Falls nein: Rechte im Zielsystem auf Lesen beschraenken. Falls ja: jede Schreibhandlung nur ueber ein Werkzeug mit Vorschau und Freigabe. Widerruf: " + $(if ($widerruf) { $widerruf } else { 'siehe Zugaenge.md' }))
        } elseif ($schreibend -eq $false) {
            Add-Befund ("zugang-lesend:" + $f.Name) "info" ("Zugang nur lesend: " + $wer) ($f.Name + ". " + $detail) ("Kein Verstoss, wenn das Lesen im Auftrag des Besitzers geschieht. Widerruf: " + $(if ($widerruf) { $widerruf } else { 'siehe Zugaenge.md' }))
        } else {
            Add-Befund ("zugang-unklar:" + $f.Name) "mittel" ("Rechte unklar: " + $wer) ($f.Name + ": Zugaenge.md nennt keine eindeutigen Rechte.") "In 10_System\Zugaenge.md die Spalte Rechte genau fuehren (lesen, schreiben, senden, welche Bereiche)."
        }
    }
    # gh CLI
    try {
        $alt = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        $ghStatus = (& gh auth status 2>&1 | Out-String)
        $ErrorActionPreference = $alt
        if ($ghStatus -match '(?i)logged in') {
            $konto = [regex]::Match($ghStatus, '(?i)account\s+(\S+)').Groups[1].Value
            $sc = [regex]::Match($ghStatus, "(?i)Token scopes:\s*([^\r\n]*)").Groups[1].Value
            Add-Befund "zugang-schreibend:gh" "mittel" ("GitHub CLI angemeldet (" + $konto + ")") `
                ("Scopes laut gh: " + $(if ($sc) { $sc } else { 'keine Angabe (feingranulares Token)' })) `
                "Token auf die noetigen Repos und Rechte beschraenken (Administration nur wo noetig): GitHub, Settings, Developer settings, Fine-grained tokens, Token bearbeiten."
        }
    } catch { }

    return @($befunde)
}

function Format-Befunde($befunde) {
    $rang = @{ hoch = 0; mittel = 1; info = 2 }
    $z = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($b in @($befunde | Sort-Object { $rang[$_.schwere] }, titel)) {
        $n++
        [void]$z.Add(("{0}. [{1}] {2}" -f $n, $b.schwere, $b.titel))
        [void]$z.Add("   Befund: " + $b.befund)
        [void]$z.Add("   Behebung: " + $b.behebung)
    }
    return ($z -join "`n")
}

if ($Audit) {
    $b = Invoke-Audit
    if ($Json) { ConvertTo-Json -InputObject @($b) -Depth 5 }
    elseif ($b.Count -eq 0) { "Sicherheits-Audit: keine Befunde." }
    else {
        "Sicherheits-Audit (" + (Get-Date -Format 'yyyy-MM-dd HH:mm') + "): " + $b.Count + " Befunde, " + @($b | Where-Object schwere -eq 'hoch').Count + " hoch, " + @($b | Where-Object schwere -eq 'mittel').Count + " mittel, " + @($b | Where-Object schwere -eq 'info').Count + " info"
        ""
        Format-Befunde $b
    }
    exit 0
}

# ---------------------------------------------------------------- Hook

try {
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding($false)))).ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    $tool = [string](Get-Wert $in "tool_name")
    $ereignis = [string](Get-Wert $in "hook_event_name")
    $sid = [string](Get-Wert $in "session_id")
    if (-not $sid) { $sid = "ohne-session" }
    $sid = ($sid -replace '[^A-Za-z0-9\-]', '')
    $tabsDatei = Join-Path $stateDir ("tabs-" + $sid + ".json")
    $ti = Get-Wert $in "tool_input"

    # --- SessionStart: Befunde melden (neu oder seit sieben Tagen nicht gemeldet)
    if ($ereignis -eq "SessionStart") {
        # Nur fuer Sessions, in denen ein Mensch liest: Ein Lauf ohne Bedienung wuerde die Meldung verbrauchen, ohne
        # dass sie jemand sieht, und ein Testkind im Temp-Ordner bekaeme sie in jede Messung. Nach einer Verdichtung
        # des Verlaufs ebenfalls nicht.
        $proj = [string]$env:CLAUDE_PROJECT_DIR
        $temp = [IO.Path]::GetTempPath().TrimEnd('\', '/')
        if ($env:LEO_GRUNDPFLEGE -eq 'aus' -or [string](Get-Wert $in "source") -eq 'compact' -or ($proj -and $proj.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase))) { exit 0 }
        New-Item -ItemType Directory -Force $stateDir | Out-Null
        $cache = Join-Path $stateDir "audit.json"
        $gemeldet = Join-Path $stateDir "audit-gemeldet.json"
        $befunde = $null
        if (Test-Path -LiteralPath $cache) {
            try {
                $c = [IO.File]::ReadAllText($cache, [Text.Encoding]::UTF8) | ConvertFrom-Json
                if (((Get-Date) - [datetime]$c.zeit).TotalHours -lt 24) { $befunde = @($c.befunde) }
            } catch { $befunde = $null }
        }
        if ($null -eq $befunde) {
            $befunde = @(Invoke-Audit)
            Save-Datei $cache (@{ zeit = (Get-Date).ToString('s'); befunde = $befunde } | ConvertTo-Json -Depth 5)
        }
        $relevant = @($befunde | Where-Object { $_.schwere -ne 'info' })
        if ($relevant.Count -eq 0) { exit 0 }
        $hash = (@($relevant | ForEach-Object { $_.id } | Sort-Object) -join '|')
        $melden = $true
        if (Test-Path -LiteralPath $gemeldet) {
            try {
                $g = [IO.File]::ReadAllText($gemeldet, [Text.Encoding]::UTF8) | ConvertFrom-Json
                if ($g.hash -eq $hash -and ((Get-Date) - [datetime]$g.zeit).TotalDays -lt 7) { $melden = $false }
            } catch { }
        }
        if (-not $melden) { exit 0 }
        # Laeuft die Sperre beim Start zweimal (aus dem Repo und aus der Kopie im Benutzerprofil), meldet nur die erste.
        $sperre = Join-Path $stateDir "audit-melden.lock"
        try { $fs = [IO.File]::Open($sperre, 'CreateNew', 'Write'); $fs.Close() }
        catch {
            if ((Test-Path -LiteralPath $sperre) -and ((Get-Date) - (Get-Item -LiteralPath $sperre).LastWriteTime).TotalSeconds -lt 120) { exit 0 }
            [IO.File]::WriteAllText($sperre, '')
        }
        Save-Datei $gemeldet (@{ hash = $hash; zeit = (Get-Date).ToString('s') } | ConvertTo-Json)
        $hoch = @($relevant | Where-Object schwere -eq 'hoch').Count
        $befehl = if ($istWindows) { 'powershell -NoProfile -ExecutionPolicy Bypass -File <Repo>\00_INDEX\scripts\guard-finanzen.ps1 -Audit' } else { 'pwsh -NoProfile -File <Repo>/00_INDEX/scripts/guard-finanzen.ps1 -Audit' }
        $kontext = "SICHERHEITS-AUDIT (guard-finanzen.ps1, AGENTS.md Abschnitt 18): Melde dem Besitzer in deiner ersten Antwort jeden der folgenden Befunde mit seiner Behebung, vollstaendig und ohne ihn zu fragen, ob er sie sehen will. Schreibende Zugaenge sind zu melden mit Vorschlag zur Behebung; nur lesende Zugaenge im Auftrag sind kein Verstoss. Vollstaendige Liste inklusive Info-Befunde: $befehl`n`n" + (Format-Befunde $relevant)
        if ($kontext.Length -gt 9500) { $kontext = $kontext.Substring(0, 9500) + "`n... (gekuerzt; vollstaendig mit -Audit)" }
        @{ systemMessage = ("Sicherheits-Audit: " + $relevant.Count + " Befunde (" + $hoch + " hoch). Der Agent meldet sie mit Behebung in der ersten Antwort."); hookSpecificOutput = @{ hookEventName = "SessionStart"; additionalContext = $kontext } } | ConvertTo-Json -Depth 5 -Compress
        exit 0
    }

    # --- PostToolUse: Sicherheitsmails ausblenden, Browser-Tabs merken
    if ($ereignis -eq "PostToolUse") {
        $antwort = Get-Wert $in "tool_response"
        $neu = $null
        $pruefen = $true
        if ($tool -eq "Read") {
            # Eigene Dateien im Repo des Leo-Kinds (Regeln, Doku, Code) nicht schwaerzen; Mails darin (90_Inbox, .eml,
            # .msg, .mbox) schon. In einem fremden Projekt wird jede gelesene Datei geprueft.
            $fp = [string](Get-Wert $ti "file_path")
            $eigen = Get-RepoPfad
            if ($eigen -and $fp) {
                $a = $fp.Replace('/', '\').TrimEnd('\'); $b = $eigen.Replace('/', '\').TrimEnd('\') + '\'
                if ($a.StartsWith($b, [StringComparison]::OrdinalIgnoreCase) -and $fp -notmatch '(?i)(\\|/)90_Inbox(\\|/)' -and $fp -notmatch '(?i)\.(eml|msg|mbox)$') { $pruefen = $false }
            }
        }
        if ($pruefen -and $null -ne $antwort -and $smMuster.Count -gt 0) {
            $neu = Edit-Ausgabe $antwort
        }
        if ($tool -match '^mcp__') {
            $name = ($tool -split '__')[-1]
            $fam = if ($tool -match 'claude-in-chrome') { "x" } else { "c" }
            if ($name -match '^(tabs_context|tabs_context_mcp|preview_start|tabs_create|tabs_create_mcp|tabs_select|navigate|computer|form_input|javascript_tool|browser_batch|find|read_page|get_page_text)$') {
                $tabs = Read-Tabs
                $text = (ConvertTo-Json (Get-Wert $in "tool_response") -Depth 12 -Compress) -replace '\\"', '"' -replace '\\\\', '\'
                if ($name -match '^tabs_context') {
                    foreach ($b in [regex]::Matches($text, '\{[^{}]*?"tabId"\s*:[^{}]*\}')) {
                        $id = [regex]::Match($b.Value, '"tabId"\s*:\s*"?([A-Za-z0-9_\-]+)').Groups[1].Value
                        $url = [regex]::Match($b.Value, '"(origin|url)"\s*:\s*"([^"]*)"').Groups[2].Value
                        if (-not $id) { continue }
                        $tabs["$fam`:$id"] = if ($url) { Get-Ziel $url } else { "?" }
                        if ($b.Value -match '"(isActive|active)"\s*:\s*true') { $tabs["$fam`:_front"] = $tabs["$fam`:$id"]; $tabs["$fam`:_frontid"] = $id }
                    }
                }
                elseif ($name -match '^(preview_start|tabs_create)') {
                    $m1 = [regex]::Match($text, '"?tabId"?\s*[:=]\s*"?([A-Za-z0-9_\-]+)')
                    if ($m1.Success) {
                        $id = $m1.Groups[1].Value
                        $tabs["$fam`:$id"] = if ($tabs.ContainsKey("$fam`:_front")) { $tabs["$fam`:_front"] } else { "?" }
                        $tabs["$fam`:_frontid"] = $id
                    }
                }
                foreach ($t in [regex]::Matches($text, 'tabId\s+([A-Za-z0-9_\-]+):\s*"[^"]*"\s*\("([^"]+)"\)')) {
                    $tabs["$fam`:" + $t.Groups[1].Value] = Get-Ziel $t.Groups[2].Value
                }
                $ausgefuehrt = [regex]::Match($text, 'Executed on tabId:\s*([A-Za-z0-9_\-]+)')
                $eingabeTab = [string](Get-Wert $ti "tabId")
                if ($ausgefuehrt.Success -and -not $eingabeTab) {
                    $id = $ausgefuehrt.Groups[1].Value
                    $tabs["$fam`:_frontid"] = $id
                    if ($tabs.ContainsKey("$fam`:$id")) { $tabs["$fam`:_front"] = $tabs["$fam`:$id"] }
                }
                $origin = [regex]::Match($text, 'captured at origin\s+(https?://[^\s\)"]+)')
                if ($origin.Success) {
                    $k = if ($eingabeTab) { "$fam`:$eingabeTab" } elseif ($ausgefuehrt.Success) { "$fam`:" + $ausgefuehrt.Groups[1].Value } else { "$fam`:_front" }
                    $tabs[$k] = Get-Ziel $origin.Groups[1].Value
                    if (-not $eingabeTab) { $tabs["$fam`:_front"] = $tabs[$k] }
                }
                try { Save-Tabs $tabs } catch { }
            }
        }
        if ($script:geschwaerzt) {
            $out = @{ hookSpecificOutput = @{ hookEventName = "PostToolUse"; updatedToolOutput = $neu; additionalContext = "guard-finanzen hat in dieser Ausgabe eine Sicherheitsmail (Code, Anmelde- oder Passwortlink) ausgeblendet. Nicht danach suchen, nichts daraus verwenden; dem Besitzer in einem Satz melden, dass eine solche Mail ausgeblendet wurde." } }
            $out | ConvertTo-Json -Depth 40 -Compress
        }
        exit 0
    }

    # --- PreToolUse
    if ($tool -eq "Bash" -or $tool -eq "PowerShell") {
        $cmd = [string](Get-Wert $ti "command")
        if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }
        if ($cmd -match $credRe) { Write-Deny ("Zugangsdaten auslesen ist gesperrt. " + $grund) }
        if ($cmd -match $httpRe -and (Test-TextFinanz $cmd)) { Write-Deny ("Aufruf einer Geldplattform oder Passwortverwaltung aus der Shell. " + $grund) }
        foreach ($u in [regex]::Matches($cmd, '(?i)https?://[^\s''"<>|]+')) {
            if ($cmd -match $httpRe -and (Test-Sicherheitslink $u.Value)) { Write-Deny ("Anmelde-, Bestaetigungs- oder Passwortlink aus der Shell. " + $grund) }
        }
        exit 0
    }

    if ($tool -match '^(Read|Grep|Glob|NotebookRead)$') {
        $text = (@((Get-Wert $ti "file_path"), (Get-Wert $ti "notebook_path"), (Get-Wert $ti "path"), (Get-Wert $ti "glob"), (Get-Wert $ti "pattern")) | Where-Object { $_ }) -join ' '
        if ($tool -eq "Grep") { $text = (@((Get-Wert $ti "path"), (Get-Wert $ti "glob")) | Where-Object { $_ }) -join ' ' }
        if ($text -match $speicherRe) {
            Write-Deny ("Passwort-, Karten- und Cookie-Speicher der Browser sind gesperrt. " + $grund)
        }
        exit 0
    }

    if ($tool -match '^(Write|Edit|MultiEdit|NotebookEdit)$') {
        $pfad = ([string](Get-Wert $ti "file_path") + [string](Get-Wert $ti "notebook_path")) -replace '/', '\'
        $inhalt = [string](Get-Wert $ti "content") + "`n" + [string](Get-Wert $ti "new_string") + "`n" + [string](Get-Wert $ti "new_source")
        foreach ($e in @(Get-Wert $ti "edits")) { if ($e) { $inhalt += "`n" + [string](Get-Wert $e "new_string") } }
        # Die Sperre selbst, ihre Reihe und Markdown (Regeln, Doku) nennen die Muster, ohne sie auszufuehren.
        if ($pfad -match '(?i)(\\00_INDEX\\scripts\\guard-finanzen(-tests)?\.ps1|\.md)$') { exit 0 }
        if ($inhalt -match $credRe) { Write-Deny ("Datei mit Zugriff auf Zugangsdaten gesperrt (" + $pfad + "). " + $grund) }
        if ($inhalt -match $httpRe -and (Test-TextFinanz $inhalt)) {
            Write-Deny ("Datei mit Zugriff auf eine Geldplattform gesperrt (" + $pfad + "). " + $grund)
        }
        exit 0
    }

    if ($tool -match '^mcp__') {
        $name = ($tool -split '__')[-1]
        $fam = if ($tool -match 'claude-in-chrome') { "x" } else { "c" }
        $tabs = Read-Tabs
        if ($name -eq "browser_batch") {
            foreach ($a in @(Get-Wert $ti "actions")) {
                $n2 = ([string](Get-Wert $a "name") -split '__')[-1]
                $g = Test-BrowserAktion $fam $n2 (Get-Wert $a "input") $tabs
                if ($g) { Write-Deny ("Im Batch: " + $g) }
            }
        }
        else {
            $g = Test-BrowserAktion $fam $name $ti $tabs
            if ($g) { Write-Deny $g }
        }
        try { Save-Tabs $tabs } catch { }
        exit 0
    }
    exit 0
}
catch {
    $betroffen = $false
    try { $betroffen = ($raw -match $credRe) -or (Test-TextFinanz $raw) } catch { $betroffen = ($raw -match '(?i)(bank|password|credential|cookie)') }
    if ($raw -match '"hook_event_name"\s*:\s*"(PostToolUse|SessionStart)"') { exit 0 }
    if (-not $betroffen -and $raw -match '"tool_name"\s*:\s*"mcp__') {
        try {
            if (-not $tabsDatei) {
                $ms = [regex]::Match($raw, '"session_id"\s*:\s*"([A-Za-z0-9\-]+)"')
                $tabsDatei = Join-Path $stateDir ("tabs-" + $(if ($ms.Success) { $ms.Groups[1].Value } else { "ohne-session" }) + ".json")
            }
            if ((Test-Path -LiteralPath $tabsDatei) -and ((Get-Content -LiteralPath $tabsDatei -Raw) -match '(geld|pw|post):')) { $betroffen = $true }
        } catch { $betroffen = $true }
    }
    if ($betroffen) { Write-Deny ("Die Finanz-Sperre konnte den Aufruf nicht pruefen (" + $_.Exception.Message + "); gesperrt, weil er Geldplattformen oder Zugangsdaten betrifft.") }
    exit 0
}
