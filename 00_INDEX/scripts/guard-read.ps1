# guard-read.ps1
# Zweck: PreToolUse-Hook. Die Lese-Haelfte der Standardsperre (AGENTS.md Abschnitt 18, seit 5.0):
# Der Agent liest ab Werk nur im eigenen Repo, in "<Repo> Archiv", "<Repo> Artifacts" und im
# Scratchpad. Alles andere ist zu, bis der Besitzer es mit 00_INDEX\scripts\freigeben.ps1 in
# 00_INDEX\freigegebene-pfade.txt eintraegt. Zugangsdaten bleiben immer zu, auch in einer Freigabe.
#
# WARUM ES DAS GIBT: Was der Agent liest, wandert in den Kontext und damit zum Modellanbieter.
# Bis 4.11 war Lesen frei und gesperrt nur, was der Besitzer in gesperrte-pfade.txt eintrug. Das
# setzt voraus, dass jeder Besitzer weiss, welche Ordner auf seinem Rechner heikel sind, und daran
# denkt, sie einzutragen; bei mehreren Besitzern stand die Liste leer. Seit 5.0 gilt deshalb das
# Umgekehrte: zu ab Werk, offen nur, was der Besitzer selbst freigibt. Der Agent oeffnet nie
# selbst; er erklaert die Sperre und gibt den fertigen Befehl aus (Meldung unten).
#
# DREI STUFEN, in dieser Reihenfolge:
#   (1) Zugangsdaten (.env, Schluessel- und Zertifikatsdateien, .ssh, .aws, Token-Dateien):
#       immer gesperrt, auch im Repo und in einer Freigabe. Es gibt keinen Befehl dafuer.
#   (2) gesperrte-pfade.txt: sperrt einen Pfad und alles darunter, auch innerhalb einer Freigabe.
#   (3) Arbeitsbereich: eingebaute Zonen plus freigegebene-pfade.txt; alles andere ist gesperrt.
# Die Zonen, die Listen und die Pfaderkennung stehen in lib\arbeitsbereich.ps1, gemeinsam mit
# guard-workspace.ps1 (Schreiben), damit Lesen und Schreiben ueber dieselben Pfade urteilen.
#
# WAS ER PRUEFT: Read und NotebookRead (Dateipfad), Grep und Glob (Suchpfad, ohne Angabe das
# Arbeitsverzeichnis; bei Glob dazu ein absoluter Anfang des Musters), Bash und PowerShell (jeder
# absolute Pfad im Befehlstext, Variablen wie $env:USERPROFILE und die Tilde aufgeloest, relative
# Pfade mit .., und das Arbeitsverzeichnis selbst).
#
# WAS ER NICHT KANN: Er sieht nur den Text des Aufrufs. Wer einen Pfad aus Teilstuecken
# zusammensetzt oder ein Skript startet, das die Datei selbst oeffnet, kommt an ihm vorbei. Die
# Sperre ist gegen das Versehen gebaut, nicht gegen die Absicht; was gegen Absicht hilft (ein
# eigenes Windows-Konto mit Dateirechten, verwaltete Einstellungen), steht in ANLEITUNG.md.
# Skripte im Repo, die ihre Token selbst aus dem Benutzerprofil lesen, sieht er deshalb nicht und
# soll er auch nicht sehen. Connectoren (MCP) fallen nicht unter diese Sperre.
#
# EINRICHTUNG: Eingehaengt in .claude\settings.json und .codex\hooks.json, Ereignis PreToolUse,
# Matcher Read|Grep|Glob|NotebookRead|Bash|PowerShell.
# Eingabe: JSON auf stdin. Ausgabe: JSON nur beim Blockieren, Exitcode immer 0.
# ASCII-only mit BOM, damit es unter Windows PowerShell 5.1 und PowerShell 7 gleich laeuft.
# Regressionsreihe: guard-read-tests.ps1 im selben Ordner, Pflicht vor und nach jeder Aenderung.

# -Repo: gesetzt, wenn der Hook als Schutzkopie ausserhalb des Repos laeuft (Haertung mit
# verwalteten Einstellungen, sperre-haerten.ps1, seit 5.1). Ohne Angabe ist das Repo der Ordner
# zwei Ebenen ueber diesem Skript. Die Listen kommen immer aus dem 00_INDEX neben diesem Skript.
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
    # Als UTF-8-Bytes schreiben: Die Konsole nimmt sonst die OEM-Codepage, und ein Umlaut im
    # Pfad kommt beim Agenten verstuemmelt an (gemessen im Ende-zu-Ende-Lauf zu 5.0).
    $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes(($out | ConvertTo-Json -Depth 5 -Compress))
    $s = [Console]::OpenStandardOutput(); $s.Write($bytes, 0, $bytes.Length); $s.Flush()
    exit 0
}

# Eingebaute Muster fuer Zugangsdaten. Sie greifen auf Dateinamen und Ordnernamen, nicht
# auf Woerter im Fliesstext: ".env" nur als eigenes Namensstueck (python-dotenv oder
# ".environment" bleiben frei), Endungen nur am Wortende, Ordner nur mit Trenner davor
# und dahinter. Wer ein Muster ergaenzt, ergaenzt einen Fall in guard-read-tests.ps1.
$credentialPatterns = @(
    @{ re = '(?i)(?:^|[\s"''=:(,\\/])\.env(?:rc|\.[A-Za-z0-9_.-]+)?(?=$|[\s"'');|&>)])'; was = ".env-Datei" }
    @{ re = '(?i)[A-Za-z0-9_.\\/~:-]+\.(?:pem|key|pfx|p12|kdbx|ppk)(?=$|[\s"'');|&>)])'; was = "Schluessel- oder Zertifikatsdatei (.pem, .key, .pfx, .p12, .kdbx, .ppk)" }
    @{ re = '(?i)(?:^|[\\/])id_(?:rsa|ed25519|ecdsa|dsa)(?:\.pub)?(?=$|[\s"'');|&>)])'; was = "SSH-Schluessel" }
    @{ re = '(?i)(?:^|[\\/~])\.(?:ssh|aws|gnupg|azure|kube)(?=[\\/]|$|[\s"''])'; was = "Credentials-Ordner (.ssh, .aws, .gnupg, .azure, .kube)" }
    @{ re = '(?i)(?:^|[\s"''=\\/])(?:[.A-Za-z0-9_-]*?[-_.])?(?:tokens?|secrets?|credentials?)(?:[-_.][A-Za-z0-9_-]+)*\.(?:txt|json|ya?ml|ini)(?=$|[\s"'');|&>)])'; was = "Token- oder Secret-Datei" }
)

function Normalize-Text([string]$s) {
    # Beide Pfadwelten auf eine Form fuer die Textsuche nach gesperrten Pfaden: Backslash zu
    # Slash, Git-Bash /c/... zu C:/..., ~ und $HOME zum Benutzerprofil.
    $t = $s -replace '\\', '/'
    if ($homePath) {
        $h = $homePath -replace '\\', '/'
        $t = $t -replace '(?<![A-Za-z0-9_])~(?=/|$)', $h
        $t = $t -replace '\$\{?HOME\}?(?![A-Za-z0-9_])', $h
        $t = $t -replace '\$env:USERPROFILE(?![A-Za-z0-9_])', $h
    }
    $t = [regex]::Replace($t, '(?<![A-Za-z0-9_])/([a-zA-Z])/', { param($m) $m.Groups[1].Value.ToUpper() + ':/' })
    return $t
}

try {
    . (Join-Path (Join-Path $PSScriptRoot 'lib') 'arbeitsbereich.ps1')

    # Eingabe ausdruecklich als UTF-8 lesen: [Console]::In nimmt die OEM-Codepage, und aus einem Umlaut im Pfad werden zwei falsche Zeichen (Leo Core, Meldung #10).
    $raw = (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding($false)))).ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    $tool = [string]$in.tool_name
    $cwd = [string]$in.cwd
    $ti = $in.tool_input

    $text = $null
    $pfade = @()
    $istShell = $false
    switch ($tool) {
        "Read"         { $text = [string]$ti.file_path; $pfade = @(Resolve-TargetPath $text $cwd) }
        "NotebookRead" { $text = [string]$ti.notebook_path; $pfade = @(Resolve-TargetPath $text $cwd) }
        { $_ -in @("Grep", "Glob") } {
            $text = [string]$ti.path
            if ([string]::IsNullOrWhiteSpace($text)) { $pfade = @(Normalize-AbsolutePath $cwd) }
            else { $pfade = @(Resolve-TargetPath $text $cwd) }
            if ($tool -eq "Glob") {
                # Ein Muster kann selbst absolut sein (C:/Users/x/**/*.md). Geprueft wird sein
                # fester Anfang bis zum ersten Platzhalter.
                $basis = ([string]$ti.pattern -split '[*?\[{]')[0]
                $nb = Normalize-AbsolutePath $basis
                if ($nb) { $pfade = @($nb) }
            }
        }
        { $_ -in @("Bash", "PowerShell") } { $text = [string]$ti.command; $istShell = $true }
        default        { exit 0 }
    }
    if ([string]::IsNullOrWhiteSpace($text) -and $pfade.Count -eq 0) { exit 0 }

    $ab = Get-Arbeitsbereich $(if ($Repo) { $Repo } else { Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }) (Split-Path -Parent $PSScriptRoot)

    # (1) Zugangsdaten, eingebaut, gelten ueberall.
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        foreach ($p in $credentialPatterns) {
            if ($text -match $p.re) {
                Write-Deny ("Lesen gesperrt: " + $p.was + " im Aufruf. Zugangsdaten gehoeren nie in den Kontext eines Modells; was einmal drin war, gilt als kompromittiert (AGENTS.md Abschnitt 18). Diese Sperre gilt ueberall, auch im Repo und in einem freigegebenen Ordner, und kein Befehl hebt sie auf. Sag [NAME] das in einem Satz. Braucht ein Skript den Wert, liest das Skript ihn selbst aus dem Benutzerprofil; nenne hoechstens den Namen der Variable, nie ihren Wert.")
            }
        }
    }

    if ($istShell) {
        $cmdN = Expand-BekannteVariablen $text
        $pfade = @(Get-AbsolutePfade $cmdN $cwd)
        # Das Arbeitsverzeichnis zaehlt mit: "ls" oder "cat x" liest dort, ohne einen Pfad zu nennen.
        if (-not [string]::IsNullOrWhiteSpace($cwd)) { $pfade += $cwd }
    }

    # (2) Gesperrte Pfade: zuerst als Text (faengt jede Erwaehnung, auch in Code), dann je Pfad.
    if ($ab.sperren.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($text)) {
        $norm = Normalize-Text $text
        $cmp = if ($isWindowsHost) { 'IgnoreCase' } else { 'None' }
        foreach ($b in $ab.sperren) {
            $bn = ($b -replace '\\', '/').TrimEnd('/')
            # Nur ganze Pfadteile: C:/Kunden sperrt nicht C:/Kunden-alt.
            if ([regex]::IsMatch($norm, ([regex]::Escape($bn) + '(?=$|[/\s"'';|&)<>,`])'), $cmp)) {
                Write-Deny (Get-SperrHinweis "Lesen" $b $ab)
            }
        }
    }
    foreach ($p in $pfade) {
        if (-not $p) { continue }
        if (Get-Sperre $p $ab) { Write-Deny (Get-SperrHinweis "Lesen" (Normalize-AbsolutePath $p) $ab) }
    }

    # (3) Arbeitsbereich: eingebaute Zonen und Freigaben, alles andere zu.
    foreach ($p in ($pfade | Select-Object -Unique)) {
        if (-not $p) { continue }
        if (-not (Test-LesenErlaubt $p $ab)) {
            $n = Normalize-AbsolutePath $p
            if (-not $n) { $n = $p }
            Write-Deny (Get-SperrHinweis "Lesen" $n $ab)
        }
    }
    exit 0
} catch {
    # Ein Fehler im Hook darf den Betrieb nicht anhalten: still durchlassen. Dass die Sperre
    # wirkt, misst die Regressionsreihe und meldet der Health-Check, nicht dieser Zweig.
    # Die Reihe setzt LEO_GUARD_DEBUG, damit ein abgefangener Fehler dort nicht als PASS durchgeht.
    if ($env:LEO_GUARD_DEBUG) { "HOOK-FEHLER: " + $_.Exception.Message + " (Zeile " + $_.InvocationInfo.ScriptLineNumber + ")" }
    exit 0
}
