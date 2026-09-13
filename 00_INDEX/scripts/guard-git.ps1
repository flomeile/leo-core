# guard-git.ps1
# Zweck: PreToolUse-Hook. Blockiert "git add -A", "git add --all" und "git add ." in jedem
# Shell-Werkzeug, unabhaengig vom Berechtigungsmodus.
#
# WARUM ES DAS GIBT (seit 3.3): Die Regel "nur die eigenen Pfade stagen" (AGENTS.md,
# Abschnitt 12) laesst sich auch als Verbotsliste in den Werkzeug-Einstellungen
# hinterlegen. Eine solche Liste greift aber nur in den Modi, in denen das Werkzeug
# ueberhaupt um Erlaubnis fragt. Sobald ein Lauf mit vollen Rechten arbeitet (etwa ein
# unbeaufsichtigter Lauf aus einer geplanten Aufgabe), ist sie wirkungslos; im
# Ursprungssystem am 11.09.2026 gemessen: "git add -A" lief in so einem Modus durch,
# waehrend die Arbeitsbereich-Sperre als Hook weiterhin blockierte. Hooks laufen in
# jedem Modus. Deshalb steht die Regel hier als eigener Hook, und bewusst NICHT in
# guard-workspace.ps1: Ein Fehler in einem neuen Hook darf den bewaehrten nicht
# mitreissen (AGENTS.md, Abschnitt 18, Umgang mit dem Hook).
#
# WAS ER BLOCKIERT: git add mit -A, --all oder "." als Ziel, mit oder ohne -C <Pfad>, in
# Bash und PowerShell. "git add ./datei" bleibt erlaubt (Punkt gefolgt von Schraegstrich).
# Alles andere laeuft durch, ohne Ausgabe (stiller Exitcode 0, siehe guard-workspace.ps1).
#
# EINRICHTUNG: Eingehaengt in .claude\settings.json (und .codex\hooks.json), Ereignis
# PreToolUse, Matcher Bash|PowerShell. Beide Dateien liegen im Paket bei.
# Eingabe: JSON auf stdin. Ausgabe: JSON nur beim Blockieren, Exitcode immer 0.
# ASCII-only mit BOM, damit es unter Windows PowerShell 5.1 und PowerShell 7 gleich laeuft.
# Regressionsreihe: guard-git-tests.ps1 im selben Ordner, Pflicht vor und nach jeder
# Aenderung an diesem Skript.

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

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $in = $raw | ConvertFrom-Json
    $tool = [string]$in.tool_name
    if ($tool -ne "Bash" -and $tool -ne "PowerShell") { exit 0 }
    $cmd = [string]$in.tool_input.command
    if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

    # git [-C <pfad>] [weitere optionen] add [optionen] (-A | --all | .) am Ende oder vor Leerraum.
    # "git" muss an Kommando-Position stehen: am Anfang, nach einem Trenner (; & | Klammer,
    # Zeilenumbruch) oder nach einem oeffnenden Anfuehrungszeichen (pwsh -c "git add -A").
    # Nicht mitten in einem Text: Eine Commit-Botschaft, die "git add -A" erwaehnt, ist kein
    # Kommando (so beim ersten Einsatz des Hooks den eigenen Commit blockiert).
    $muster = '(?im)(?:^|[;&|(\r\n"''`]\s*)git\b(?:\s+-C\s+(?:"[^"]*"|''[^'']*''|\S+))?(?:\s+-\S+)*\s+add\b[^\r\n;&|"'']*?(?:\s|^)(?:-A|--all|\.)(?=\s|$|[;&|"''])'
    if ($cmd -match $muster) {
        Write-Deny "Pauschales Stagen ist gesperrt: git add -A, --all und . nehmen den halbfertigen Stand anderer Sessions und die offene Bearbeitung des Besitzers mit (AGENTS.md Abschnitt 12). Nur die eigenen Dateien einzeln stagen: git add -- <datei> <datei>."
    }
    exit 0
} catch {
    # Ein Fehler im Hook darf den Betrieb nicht anhalten: still durchlassen.
    exit 0
}
