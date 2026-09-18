# guard-read.ps1
# Zweck: PreToolUse-Hook. Blockiert das LESEN von Zugangsdaten und von Ordnern, die der
# Besitzer als gesperrt eingetragen hat, in jedem Lese- und Shell-Werkzeug.
#
# WARUM ES DAS GIBT (seit 3.8): Die Arbeitsbereich-Sperre (guard-workspace.ps1) schuetzt,
# wohin der Agent SCHREIBT. Was er LIEST, war bisher frei, und das ist fuer fast alles
# richtig (AGENTS.md, Abschnitt 18: ein Diagnoseblick in eine fremde Datei soll keine
# Rueckfrage kosten). Zwei Sorten Dateien sind die Ausnahme, weil ihr Inhalt mit dem
# Lesen in den Kontext und damit zum Modellanbieter wandert:
#   (1) Zugangsdaten: .env-Dateien, private Schluessel, Zertifikatsdateien, SSH- und
#       Cloud-Credentials, Token-Dateien. Ein Schluessel, der einmal im Kontext war,
#       gilt als kompromittiert.
#   (2) Gesperrte Ordner des Besitzers: alles, was nach seinen Datenregeln in keine
#       Cloud-KI darf (Kundenkonfigurationen, Exporte unter NDA, Gesundheitsdaten).
#       Welche das sind, weiss nur er; er traegt sie in 00_INDEX\gesperrte-pfade.txt ein.
# Ohne diesen Hook reicht ein "schau dir mal den Ordner X an", und die Datei ist beim
# Anbieter, ohne dass jemand etwas abgetippt hat. Eine Textregel allein faengt das nicht;
# dieser Hook entscheidet vor dem Werkzeugaufruf und ohne das Modell.
#
# WAS ER PRUEFT: Read, Grep, Glob und NotebookRead (deren Pfad-Eingabe) sowie Bash und
# PowerShell (den Befehlstext). Gegen zwei Listen: die eingebauten Muster fuer
# Zugangsdaten unten, und die Pfade aus 00_INDEX\gesperrte-pfade.txt (eine je Zeile,
# absolut, ~ erlaubt; Zeilen mit # sind Kommentar). Ein Treffer blockiert mit Begruendung.
# Alles andere laeuft durch, ohne Ausgabe (stiller Exitcode 0).
#
# WAS ER NICHT KANN: Er sieht nur den Text des Aufrufs. Wer einen Pfad aus Teilstuecken
# zusammensetzt oder ein Skript startet, das die Datei selbst oeffnet, kommt an ihm
# vorbei. Diese Sperre ist gegen das Versehen gebaut, nicht gegen die Umgehung (dieselbe
# Grenze wie bei guard-workspace.ps1). Skripte im Repo, die ihre Token selbst aus dem
# Benutzerprofil lesen, sieht er deshalb nicht und soll er auch nicht sehen.
#
# EINRICHTUNG: Eingehaengt in .claude\settings.json (und .codex\hooks.json), Ereignis
# PreToolUse, Matcher Read|Grep|Glob|NotebookRead|Bash|PowerShell. Beide Dateien liegen im
# Paket bei. Die Datei gesperrte-pfade.txt gehoert dem Besitzer (Kern-Dateien.md, Kategorie
# B); fehlt sie, wirken nur die eingebauten Muster.
# Eingabe: JSON auf stdin. Ausgabe: JSON nur beim Blockieren, Exitcode immer 0.
# ASCII-only mit BOM, damit es unter Windows PowerShell 5.1 und PowerShell 7 gleich laeuft.
# Regressionsreihe: guard-read-tests.ps1 im selben Ordner, Pflicht vor und nach jeder
# Aenderung an diesem Skript. Die Reihe legt ihre Testliste ueber die Umgebungsvariable
# LEO_GUARD_READ_KONFIG daneben; im Betrieb ist die Variable nicht gesetzt.

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
    # Beide Pfadwelten auf eine Form: Backslash zu Slash, Git-Bash /c/... zu C:/...,
    # ~ zum Benutzerprofil. Gross/Klein spielt unter Windows keine Rolle.
    $t = $s -replace '\\', '/'
    $profil = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
    if ($profil) {
        $h = $profil -replace '\\', '/'
        $t = $t -replace '(?<![A-Za-z0-9_])~(?=/|$)', $h
        $t = $t -replace '\$\{?HOME\}?(?![A-Za-z0-9_])', $h
        $t = $t -replace '\$env:USERPROFILE(?![A-Za-z0-9_])', $h
    }
    $t = [regex]::Replace($t, '(?<![A-Za-z0-9_])/([a-zA-Z])/', { param($m) $m.Groups[1].Value.ToUpper() + ':/' })
    return $t
}

function Read-BlockedPaths([string]$konfig) {
    $list = @()
    if (-not (Test-Path -LiteralPath $konfig)) { return $list }
    foreach ($line in Get-Content -LiteralPath $konfig -Encoding UTF8) {
        $l = $line.Trim()
        if ($l -eq '' -or $l.StartsWith('#')) { continue }
        $n = (Normalize-Text $l).TrimEnd('/')
        if ($n -ne '') { $list += $n }
    }
    return $list
}

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    $tool = [string]$in.tool_name

    $text = $null
    switch ($tool) {
        "Read"         { $text = [string]$in.tool_input.file_path }
        "NotebookRead" { $text = [string]$in.tool_input.notebook_path }
        "Grep"         { $text = [string]$in.tool_input.path }
        "Glob"         { $text = [string]$in.tool_input.path }
        "Bash"         { $text = [string]$in.tool_input.command }
        "PowerShell"   { $text = [string]$in.tool_input.command }
        default        { exit 0 }
    }
    if ([string]::IsNullOrWhiteSpace($text)) { exit 0 }

    # (1) Zugangsdaten, eingebaut.
    foreach ($p in $credentialPatterns) {
        if ($text -match $p.re) {
            Write-Deny ("Lesen gesperrt: " + $p.was + " im Aufruf. Zugangsdaten gehoeren nie in den Kontext eines Modells; was einmal drin war, gilt als kompromittiert (AGENTS.md Abschnitt 18). Wenn ein Skript den Wert braucht, liest das Skript ihn selbst aus dem Benutzerprofil.")
        }
    }

    # (2) Gesperrte Pfade des Besitzers.
    $konfig = if ($env:LEO_GUARD_READ_KONFIG) { $env:LEO_GUARD_READ_KONFIG } else { Join-Path (Split-Path -Parent $PSScriptRoot) 'gesperrte-pfade.txt' }
    $blocked = Read-BlockedPaths $konfig
    if ($blocked.Count -gt 0) {
        $norm = Normalize-Text $text
        $cmp = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
        foreach ($b in $blocked) {
            if ($norm.IndexOf($b, $cmp) -ge 0) {
                Write-Deny ("Lesen gesperrt: '" + $b + "' steht in 00_INDEX/gesperrte-pfade.txt. Was dort liegt, darf nach den Datenregeln des Besitzers in keine Cloud-KI (AGENTS.md Abschnitt 18). Wird es wirklich gebraucht, entscheidet der Besitzer im Einzelfall und nimmt den Pfad selbst aus der Liste.")
            }
        }
    }
    exit 0
} catch {
    # Ein Fehler im Hook darf den Betrieb nicht anhalten: still durchlassen.
    exit 0
}
