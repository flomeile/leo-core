# health-check.ps1
# Zweck: Read-only Diagnose des gesamten KI_REPO-Systems. Veraendert NICHTS am Repo.
# Denkt NICHT selbst nach: rein deterministische, mechanische Pruefungen, keine Halluzination.
#
# WICHTIG: Vor diesem Health Check IMMER zuerst build-index-geruest.ps1 laufen lassen,
# damit hier der aktuelle Stand geprueft wird, nicht ein veralteter (siehe Skill
# leo-system-health-check.md).
#
# Manche Pruefungen (z.B. Themenordner-Erkennung) sind absichtlich UNABHAENGIG von
# build-index-geruest.ps1 neu implementiert statt von dort importiert - damit dieser
# Check auch einen Bug im Generator-Skript selbst findet (ist am 2026-07-07 passiert:
# ein hartcodierter "^2\d_"-Filter haette 3X-Themenordner unsichtbar gemacht).
#
# Aufruf: pwsh -NoProfile -ExecutionPolicy Bypass -File "<REPO>\00_INDEX\scripts\health-check.ps1"
# Exit Code: 0 = alles ok (nur OK/INFO), 1 = mind. 1 WARN, 2 = mind. 1 FAIL.
# Der Repo-Root wird automatisch aus $PSScriptRoot abgeleitet (verschiebbar, kein Hardcode).

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$results = New-Object System.Collections.Generic.List[PSCustomObject]

# Verzeichnisse, die bei JEDEM rekursiven Scan uebersprungen werden. Neben .git und
# .obsidian gehoert .claude dazu: Coding-Agents legen unter .claude\worktrees\ komplette
# Arbeitskopien des Repos an. Ohne diesen Ausschluss laeuft der Check in solche Kopien
# hinein und meldet jede Datei doppelt - inklusive Phantom-Befunden, weil die
# Ausnahmelisten unten auf Relativpfaden ab Repo-Root basieren und der Worktree-Praefix
# sie nicht mehr treffen laesst (Befund 2026-07-17: zwei bereits abgestimmte
# stand:-Ausnahmen wurden aus dem Worktree heraus erneut als WARN gemeldet).
# Die uebrigen Werkzeug-Verzeichnisse tragen die generierten Skill-Zeiger (Abschnitt 11a).
# Sie sind Konfiguration, kein Wissen, und werden weder indexiert noch auf Frontmatter,
# stand: oder tote Links geprueft. Identisch zu $excludeDirs in build-index-geruest.ps1
# und zu is_fm_exempt() im pre-commit-Hook zu halten.
$excludedDirPattern = '\\\.(git|obsidian|claude|agents|gemini|cursor|cline|opencode|github)\\'

function Add-Check([string]$Level, [string]$Category, [string]$Message) {
    $results.Add([PSCustomObject]@{ Level = $Level; Category = $Category; Message = $Message })
}

# Skill-Praefix dieses Systems (seit 2.4). Das Grundgeruest nennt seine Skills
# durchgaengig leo-*, wer sein System umbenannt hat, hat lokal andere Dateinamen.
# Jede Kern-Datei, die einen Skill beim Namen nennt (Kern-Dateien.md, Verweise
# zwischen Skills), zeigt bei ihm dann scheinbar ins Leere. Das ist kein Fehler
# seines Systems, sondern eine Namenskonvention, und wird auch nicht heilbar:
# Diese Dateien kommen bei jedem Update neu aus dem Grundgeruest. Gemessen im
# Trockenlauf am 31.08.2026: 1 FAIL und 8 WARN, die kein Nutzer je loswerden kann.
# Test-RepoPfad loest deshalb beide Schreibweisen auf.
$skillPraefix = 'leo-'
# Name dieses Systems (seit 2.6). Wer sein System umbenannt hat, benennt seine
# Scheduled Tasks danach; der Task-Check unten fand die vorher nicht und verlangte
# als Umgehung einen Task namens "Leo ..." in einem System, in dem sonst kein
# "Leo" mehr vorkommt. Ein solcher Fremdname wird frueher oder spaeter aufgeraeumt,
# und damit geht die Pruefung still aus. Gemeldet als Issue #4 im Grundgeruest.
# Zwei Absicherungen beim Aufloesen: getrimmt, und ein leer gelassener Wert faellt
# auf "Leo" zurueck statt ein Leerzeichen als Suchmuster zu liefern (das passte auf
# einem Testrechner auf 59 von 224 Tasks).
$sysName = 'Leo'
$msPfadFuerPraefix = Join-Path $repo "MEIN-SYSTEM.md"
if (Test-Path -LiteralPath $msPfadFuerPraefix) {
    $msRoh = Get-Content -LiteralPath $msPfadFuerPraefix -Raw -Encoding UTF8
    if ($msRoh -match '(?m)^\|\s*Skill-Pr[äa]fix\s*\|[^|]*\|\s*`?([a-z0-9]+-)`?\s*\|') { $skillPraefix = $Matches[1] }
    if ($msRoh -match '(?m)^\|\s*Systemname\s*\|[^|]*\|\s*`?([^|`]+?)`?\s*\|') {
        $sysNameKandidat = $Matches[1].Trim()
        if ($sysNameKandidat.Length -ge 2) { $sysName = $sysNameKandidat }
    }
}

function Test-RepoPfad([string]$RelPfad) {
    if ([string]::IsNullOrWhiteSpace($RelPfad)) { return $false }
    $norm = $RelPfad.Replace('\', '/')
    if (Test-Path -LiteralPath (Join-Path $repo $norm)) { return $true }
    if ($skillPraefix -ne 'leo-' -and $norm -match '(^|/)leo-([\w-]+\.md)$') {
        $alt = $norm -replace '(^|/)leo-([\w-]+\.md)$', ('$1' + $skillPraefix + '$2')
        if (Test-Path -LiteralPath (Join-Path $repo $alt)) { return $true }
    }
    return $false
}

Write-Output "=== Leo System Health Check ==="
Write-Output "Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output ""

# ---------------------------------------------------------------------------
# 1) GIT & VERSIONIERUNG
# ---------------------------------------------------------------------------
$cat = "Git"
if (-not (Test-Path (Join-Path $repo ".git"))) {
    Add-Check "FAIL" $cat "Kein .git-Ordner gefunden unter $repo - ist das ueberhaupt das Repo-Root?"
} else {
    if (Test-Path (Join-Path $repo ".git\index.lock")) {
        Add-Check "WARN" $cat "git index.lock vorhanden - evtl. laeuft parallel ein anderer Git-Prozess (z.B. der automatische Sync-Task). Health Check ggf. gleich nochmal laufen lassen."
    }

    $statusRaw = & git -C $repo status --porcelain 2>&1
    if ($LASTEXITCODE -ne 0) {
        Add-Check "FAIL" $cat "git status fehlgeschlagen: $statusRaw"
    } else {
        $mechanicalPattern = '(^|[/\\])(_INDEX\.md|INDEX\.md|INDEX-Geruest\.md|AGENTS\.md)$'
        $unexpected = @()
        $mechanical = @()
        foreach ($line in $statusRaw) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $path = $line.Substring(3).Trim('"')
            if ($path -match $mechanicalPattern) { $mechanical += $path } else { $unexpected += $path }
        }
        if ($mechanical.Count -gt 0) {
            Add-Check "INFO" $cat "$($mechanical.Count) mechanisch gepflegte Datei(en) mit unstaged Aenderungen (erwartete Index-Drift, wird beim naechsten Commit erfasst): $($mechanical -join ', ')"
        }
        if ($unexpected.Count -gt 0) {
            Add-Check "WARN" $cat "$($unexpected.Count) unerwartete uncommitted Aenderung(en), die kein reines Index-Update sind - pruefen ob gewollt: $($unexpected -join ', ')"
        }
        if ($mechanical.Count -eq 0 -and $unexpected.Count -eq 0) {
            Add-Check "OK" $cat "Working Tree sauber, keine uncommitted Aenderungen."
        }
    }

    $null = & git -C $repo fetch --quiet 2>&1
    if ($LASTEXITCODE -ne 0) {
        Add-Check "INFO" $cat "git fetch fehlgeschlagen (evtl. offline) - Vergleich mit origin/main uebersprungen."
    } else {
        $counts = & git -C $repo rev-list --left-right --count 'origin/main...HEAD' 2>&1
        if ($LASTEXITCODE -eq 0 -and $counts -match '^(\d+)\s+(\d+)$') {
            $behind = [int]$matches[1]; $ahead = [int]$matches[2]
            if ($behind -gt 0) { Add-Check "WARN" $cat "Lokaler main ist $behind Commit(s) hinter origin/main - pull nachholen." }
            if ($ahead -gt 0) { Add-Check "WARN" $cat "Lokaler main ist $ahead Commit(s) vor origin/main - noch nicht gepusht." }
            if ($behind -eq 0 -and $ahead -eq 0) { Add-Check "OK" $cat "Lokaler main deckungsgleich mit origin/main." }
        } else {
            Add-Check "INFO" $cat "Konnte Ahead/Behind zu origin/main nicht bestimmen (evtl. kein main/origin-Tracking-Branch)."
        }
    }

    $conflicts = & git -C $repo grep -l "^<<<<<<< " -- "*.md" 2>$null
    if ($conflicts) {
        Add-Check "FAIL" $cat "Ungeloeste Merge-Konflikt-Marker gefunden in: $($conflicts -join ', ')"
    } else {
        Add-Check "OK" $cat "Keine Merge-Konflikt-Marker in .md-Dateien."
    }

    # 1b) Pre-Commit-Hook: IST core.hooksPath gesetzt, und liegt der Hook dort?
    # Der Hook ist versioniert, die EINSTELLUNG nicht: Auf einem neuen Rechner
    # (oder nach einem frischen Clone) existiert die Datei, greift aber nicht.
    # Ohne diese Pruefung waere die Durchsetzung still abwesend - ein Check, der
    # nichts prueft und trotzdem gruen meldet, ist gefaehrlicher als keiner.
    $expectedHooks = "00_INDEX/githooks"
    $hooksPath = (& git -C $repo config core.hooksPath 2>$null | Select-Object -First 1)
    $hookFile = Join-Path $repo "00_INDEX\githooks\pre-commit"
    if (-not (Test-Path $hookFile)) {
        Add-Check "FAIL" $cat "Die Hook-Datei 00_INDEX\githooks\pre-commit fehlt im Repo - der Schutz gegen Konflikt-Marker und zerstoerte AUTO-Bloecke ist weg."
    } elseif ([string]::IsNullOrWhiteSpace($hooksPath)) {
        Add-Check "FAIL" $cat "core.hooksPath ist NICHT gesetzt: der Pre-Commit-Hook liegt zwar im Repo, wird aber von Git ignoriert. Einmalig setzen mit: git config core.hooksPath $expectedHooks"
    } elseif (($hooksPath -replace '\\', '/').TrimEnd('/') -ne $expectedHooks) {
        Add-Check "WARN" $cat "core.hooksPath zeigt auf '$hooksPath' statt auf '$expectedHooks' - der Hook laeuft so nicht. Pruefen und ggf. korrigieren: git config core.hooksPath $expectedHooks"
    } else {
        Add-Check "OK" $cat "Pre-Commit-Hook aktiv (core.hooksPath = $expectedHooks, Hook-Datei vorhanden)."
    }
}
Write-Output "Git-Checks erledigt."

# ---------------------------------------------------------------------------
# 2) SCHEDULED TASKS (automatischer Sync)
# ---------------------------------------------------------------------------
$cat = "Scheduled Tasks"
try {
    # Der eigene Systemname wird mit Wortgrenzen gesucht, "Leo" und das alte
    # "KI-REPO" bleiben unveraendert im Muster: Bestandsnutzer merken nichts.
    # Die Wortgrenzen sind noetig, weil kurze Namen sonst fremde Tasks einsammeln
    # (Systemname "AI" traf auf einem Testrechner 23 von 224 Tasks, alles Office,
    # Google und Geraetehersteller). Aus demselben Grund bleiben die Tasks des
    # Betriebssystems unter \Microsoft\ aussen vor; eigene Tasks liegen dort nie.
    $taskMuster = '\b' + [regex]::Escape($sysName) + '\b|Leo|KI[-_]?REPO'
    $tasks = Get-ScheduledTask -ErrorAction Stop |
        Where-Object { $_.TaskPath -notlike '\Microsoft\*' -and $_.TaskName -match $taskMuster }
    if (-not $tasks -or $tasks.Count -eq 0) {
        Add-Check "WARN" $cat "Keine Scheduled Task gefunden, deren Name '$sysName' (oder 'Leo', oder alt 'KI-REPO') enthaelt - automatischer Index-Sync/Git-Push laeuft evtl. nicht (mehr)."
    } else {
        foreach ($t in $tasks) {
            $info = Get-ScheduledTaskInfo -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue
            $state = $t.State
            $lastResult = if ($info) { $info.LastTaskResult } else { $null }
            $lastRun = if ($info) { $info.LastRunTime } else { $null }
            if ($state -eq "Disabled") {
                Add-Check "WARN" $cat "Task '$($t.TaskName)' ist DEAKTIVIERT."
            } elseif ($lastResult -in @(267008, 267009, 267011)) {
                # 0x0004xxxx sind ZUSTAENDE des Task Schedulers, keine Fehler:
                # 267008 = bereit (noch kein abgeschlossener Lauf), 267009 = laeuft
                # gerade, 267011 = noch nie gelaufen (erster Trigger steht aus).
                # Befund aus dem Betrieb eines Nutzersystems (30.08.2026): Ein frisch registrierter
                # Task meldete sonst sofort einen "Fehlercode", und ein Task, der
                # waehrend seines eigenen Diagnoselaufs prueft, meldete sich selbst
                # als fehlgeschlagen, weil er noch lief.
                Add-Check "INFO" $cat "Task '$($t.TaskName)' meldet Zustand $lastResult (bereit/laeuft/noch nie gelaufen). Kein Fehler."
            } elseif ($null -ne $lastResult -and $lastResult -ne 0) {
                Add-Check "WARN" $cat "Task '$($t.TaskName)' letzter Lauf mit Fehlercode $lastResult (Stand $lastRun)."
            } else {
                # Ein Task, der OK meldet, aber seit Wochen nicht lief, ist praktisch
                # derselbe Ausfall wie ein fehlender Task, sieht im Bericht aber gruen
                # aus (Befund aus einem Nutzersystem, 30.08.2026: fuenf Tage ganz ohne registrierten
                # Task blieben unsichtbar, weil das Protokoll durch Handlaeufe gefuellt
                # aussah). 14 Tage decken auch zweiwoechentliche Turnusse ab.
                $lastRunAlter = if ($lastRun -and $lastRun.Year -gt 2000) { ((Get-Date) - $lastRun).TotalDays } else { $null }
                if ($null -ne $lastRunAlter -and $lastRunAlter -gt 14) {
                    Add-Check "WARN" $cat "Task '$($t.TaskName)' meldet OK, lief aber zuletzt vor $([int]$lastRunAlter) Tagen ($lastRun). Ein Task ohne Laeufe ist praktisch kein Task: Trigger und Rechnerlaufzeiten pruefen."
                } else {
                    Add-Check "OK" $cat "Task '$($t.TaskName)' aktiv, letzter Lauf ok ($lastRun)."
                }
            }
        }
    }
} catch {
    Add-Check "INFO" $cat "Get-ScheduledTask nicht verfuegbar oder fehlgeschlagen ($($_.Exception.Message)) - Task-Pruefung uebersprungen."
}
Write-Output "Scheduled-Task-Checks erledigt."

# ---------------------------------------------------------------------------
# 3) AUTO-BLOCK-MARKER-INTEGRITAET
# ---------------------------------------------------------------------------
$cat = "Auto-Bloecke"
function Test-AutoBlockMarkers([string]$file, [string[]]$blockNames) {
    if (-not (Test-Path $file)) { Add-Check "FAIL" $cat "Datei fehlt: $file"; return }
    $text = Get-Content -Path $file -Raw -Encoding UTF8
    foreach ($name in $blockNames) {
        $beginTag = "<!-- AUTO:${name}:BEGIN -->"
        $endTag = "<!-- AUTO:${name}:END -->"
        $beginCount = ([regex]::Matches($text, [regex]::Escape($beginTag))).Count
        $endCount = ([regex]::Matches($text, [regex]::Escape($endTag))).Count
        $bi = $text.IndexOf($beginTag)
        $ei = $text.IndexOf($endTag)
        if ($beginCount -ne 1 -or $endCount -ne 1) {
            Add-Check "FAIL" $cat "$file : Auto-Block '$name' hat $beginCount BEGIN- und $endCount END-Marker (je genau 1 erwartet)."
        } elseif ($bi -ge $ei) {
            Add-Check "FAIL" $cat "$file : Auto-Block '$name' - BEGIN-Marker liegt nach END-Marker."
        } else {
            Add-Check "OK" $cat "$file : Auto-Block '$name' intakt."
        }
    }
}
Test-AutoBlockMarkers (Join-Path $repo "00_INDEX\INDEX.md") @("BAUM", "BEREICHE")
Test-AutoBlockMarkers (Join-Path $repo "AGENTS.md") @("ROLLEN", "SKILLS")
Write-Output "Auto-Block-Checks erledigt."

# ---------------------------------------------------------------------------
# 4) THEMENORDNER-REGISTRIERUNG VOLLSTAENDIG (unabhaengig neu implementiert)
# ---------------------------------------------------------------------------
$cat = "Themenordner"

function Test-IsThemenordnerHC([System.IO.DirectoryInfo]$dir) {
    if ($dir.Name -notmatch "^(\d+)_") { return $false }
    $num = [int]$matches[1]
    if ($num -lt 20) { return $false }
    $agentsFile = Join-Path $dir.FullName "AGENTS.md"
    if (-not (Test-Path $agentsFile)) { return $false }
    $hasRolle = (Get-Content -Path $agentsFile -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String -Pattern "^#\s+Rolle:").Count -gt 0
    return $hasRolle
}

$allNumberedDirs = Get-ChildItem -Path $repo -Directory | Where-Object { $_.Name -match "^(\d+)_" }
$dupGroups = $allNumberedDirs | Group-Object { [regex]::Match($_.Name, "^(\d+)_").Groups[1].Value } | Where-Object { $_.Count -gt 1 }
foreach ($g in $dupGroups) {
    Add-Check "FAIL" $cat "Doppelt vergebene Ordnernummer '$($g.Name)': $($g.Group.Name -join ', ')"
}

$themen = $allNumberedDirs | Where-Object { Test-IsThemenordnerHC $_ }
if ($themen.Count -eq 0) {
    Add-Check "WARN" $cat "Kein einziger Themenordner erkannt - pruefen, ob das plausibel ist."
}

$indexText = Get-Content -Path (Join-Path $repo "00_INDEX\INDEX.md") -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
$agentsText = Get-Content -Path (Join-Path $repo "AGENTS.md") -Raw -Encoding UTF8 -ErrorAction SilentlyContinue

foreach ($t in $themen) {
    $name = $t.Name
    $missing = @()
    if (-not (Test-Path (Join-Path $t.FullName "_INDEX.md"))) { $missing += "_INDEX.md fehlt" }
    if (-not (Test-Path (Join-Path $t.FullName "README.md"))) { $missing += "README.md fehlt" }
    if ($agentsText -notmatch [regex]::Escape("| $name |")) { $missing += "kein Eintrag in AGENTS.md ROLLEN-Tabelle" }
    if ($indexText -notmatch [regex]::Escape("**$name**")) { $missing += "kein Eintrag in INDEX.md Themenbereiche" }
    if ($missing.Count -gt 0) {
        Add-Check "FAIL" $cat "$name : $($missing -join '; ')"
    } else {
        Add-Check "OK" $cat "$name vollstaendig registriert (Rolle, README, lokaler Index, INDEX.md-Eintrag)."
    }
}
Write-Output "Themenordner-Checks erledigt."

# ---------------------------------------------------------------------------
# 5) LOKALE INDEX-ABDECKUNG (kuratierte Beschreibungen)
# ---------------------------------------------------------------------------
$cat = "Index-Abdeckung"
$excludedMeta = @("AGENTS.md", "README.md", "_INDEX.md")
# Dauer-Ausnahmen von der Beschreibungspflicht: Dateien/Ordner, die zu gross oder zu
# zahlreich fuer sinnvolle Einzelbeschreibungen sind (z.B. ein langes Manuskript, ein
# Archiv-Ordner). Hier bewusst leer; bei Bedarf selbst eintragen. Format:
# "Themenordner/relativer Pfad" oder "Themenordner/Unterordner/*" (Wildcard).
$knownCoverageExclusions = @(
)

foreach ($t in $themen) {
    $idx = Join-Path $t.FullName "_INDEX.md"
    if (-not (Test-Path $idx)) { continue }

    $onDisk = Get-ChildItem -Path $t.FullName -Recurse -File -Filter "*.md" |
        Where-Object { $excludedMeta -notcontains $_.Name } |
        ForEach-Object { $_.FullName.Substring($t.FullName.Length + 1).Replace('\', '/') } |
        Where-Object {
            $rel = "$($t.Name)/$_"
            -not ($knownCoverageExclusions | Where-Object { $rel -like $_ })
        }

    $idxText = Get-Content -Path $idx -Raw -Encoding UTF8
    $describedPaths = [regex]::Matches($idxText, '(?m)^- \*\*(.+?)\*\*') | ForEach-Object { $_.Groups[1].Value.Replace('\', '/') }

    $missing = $onDisk | Where-Object { $describedPaths -notcontains $_ }
    if ($missing.Count -gt 0) {
        $shown = $missing | Select-Object -First 15
        $suffix = if ($missing.Count -gt 15) { " (+$($missing.Count - 15) weitere)" } else { "" }
        Add-Check "WARN" $cat "$($t.Name): $($missing.Count) Datei(en) ohne kuratierte Beschreibung: $($shown -join ', ')$suffix"
    } else {
        Add-Check "OK" $cat "$($t.Name): alle Dateien (ausser AGENTS.md/README.md) kuratiert beschrieben."
    }

    $orphaned = $describedPaths | Where-Object { -not (Test-Path (Join-Path $t.FullName $_)) }
    if ($orphaned.Count -gt 0) {
        Add-Check "WARN" $cat "$($t.Name): $($orphaned.Count) kuratierte Beschreibung(en) verweisen auf nicht mehr existierende Dateien (sollte das Generator-Skript eigentlich entfernt haben): $($orphaned -join ', ')"
    }
}

# ---------------------------------------------------------------------------
# 5b) ROOT-INDEX-ABDECKUNG DER SYSTEMORDNER
# ---------------------------------------------------------------------------
# Pruefung 5) oben deckt NUR Themenordner ab (Nummer >= 20, je eigene lokale
# _INDEX.md). Die Systemordner darunter haben keine lokale _INDEX.md; ihre
# kuratierten Beschreibungen stehen in den Abschnitten der Root-INDEX.md. Ohne
# diese Pruefung bleibt dort jede Luecke mechanisch unsichtbar - Befund
# 2026-07-17: leo-markt-monitor.md war seit dem 2026-07-14 unbeschrieben, ohne
# dass ein einziger Health-Check-Lauf das gemeldet haette.
# 03_Sessionlogs und 04_Changelog stehen bewusst NICHT in dieser Liste: sie sind
# in der Root-INDEX.md absichtlich als Sammeleintrag ("03_Sessionlogs\...")
# gefuehrt statt Datei fuer Datei.
$systemCoverageDirs = @("01_Basiskontext", "02_Skills", "10_System")

$describedInRoot = @([regex]::Matches($indexText, '(?m)^- \*\*(.+?\.md)\*\*') | ForEach-Object { $_.Groups[1].Value })

foreach ($sd in $systemCoverageDirs) {
    $sdPath = Join-Path $repo $sd
    if (-not (Test-Path $sdPath)) {
        Add-Check "WARN" $cat "Systemordner $sd wird erwartet, ist aber nicht vorhanden."
        continue
    }
    $onDiskSys = @(Get-ChildItem -Path $sdPath -File -Filter "*.md" |
        Where-Object { $_.Name -ne "README.md" } |
        ForEach-Object { "$sd\$($_.Name)" })

    $missingSys = @($onDiskSys | Where-Object { $describedInRoot -notcontains $_ })
    if ($missingSys.Count -gt 0) {
        Add-Check "WARN" $cat "$sd : $($missingSys.Count) Datei(en) ohne kuratierte Beschreibung in 00_INDEX\INDEX.md: $($missingSys -join ', ')"
    } else {
        Add-Check "OK" $cat "$sd : alle Dateien (ausser README.md) in der Root-INDEX.md kuratiert beschrieben."
    }
}

# Gegenrichtung: eine kuratierte Beschreibung verweist auf eine Datei, die es gar
# nicht gibt. Das faellt sonst niemandem auf, weil der Eintrag ja "da" ist - der
# Verweis laeuft aber ins Leere und keine Agentic Search findet die Datei je.
# Typischer Ausloeser: Eine Datei wird umbenannt (z.B. Umlaut-Korrektur), der
# Index-Eintrag traegt aber weiter den alten Namen. Sammeleintraege ("...") matcht
# die Regex nicht.
$orphanedRoot = @($describedInRoot | Where-Object { -not (Test-RepoPfad $_) })
if ($orphanedRoot.Count -gt 0) {
    Add-Check "FAIL" $cat "$($orphanedRoot.Count) kuratierte Beschreibung(en) in 00_INDEX\INDEX.md verweisen auf nicht existierende Dateien: $($orphanedRoot -join ', ')"
} else {
    Add-Check "OK" $cat "Alle kuratierten Beschreibungen in 00_INDEX\INDEX.md verweisen auf real existierende Dateien."
}
Write-Output "Index-Abdeckungs-Checks erledigt."

# ---------------------------------------------------------------------------
# 6) VERALTETE "stand:"-DATEN (> 60 Tage) UND ABGELAUFENE "gueltig_bis:"-DATEN
# ---------------------------------------------------------------------------
$cat = "Aktualitaet"
$staleFiles = @()
$driftFiles = @()
# 'gueltig_bis:' (optional, AGENTS.md Abschnitt 7) ist die Gegenrichtung zu 'stand:':
# nicht "wann zuletzt geprueft", sondern "ab wann wertlos". Gelesen wird "gueltig bis
# einschliesslich", abgelaufen ist eine Datei also erst am Tag NACH dem eingetragenen
# Datum. Zwei Wirkungen: abgelaufene Dateien werden gemeldet, und Dateien mit eigenem
# Ablaufdatum sind von der pauschalen 60-Tage-Warnung ausgenommen. Letzteres ist
# Absicht: Eine Meeting-Vorbereitung ist nach 60 Tagen tot, ein Strategiepapier nicht,
# und eine Datei, die ihre Frist selbst mitbringt, braucht die grobe Heuristik nicht.
$expiredFiles = @()
# Drift-Ausnahmen: Rohquellen, deren 'stand:' bewusst das Datum des Ursprungsdokuments
# traegt (z.B. Datum einer eingelesenen PDF), nicht das Datum der letzten Git-Aenderung
# (die oft nur die Uebernahme ins Repo ist). Hier bewusst leer; bei Bedarf selbst
# eintragen, Format "Themenordner/relativer Pfad".
$knownDriftExceptions = @(
)
# Ein Commit, der an einer Datei ausschliesslich `herkunft:` oder `geprueft:` im
# Frontmatter ergaenzt hat, aendert keine einzige Aussage darin und darf deshalb keine
# Drift-Warnung ausloesen. Hintergrund (Issue #1 in diesem Repo, 26.08.2026): Der
# Herkunftsnachweis aus Abschnitt 6 der AGENTS.md verlangt genau diese Nachtragung, und
# ein solcher Migrationslauf macht jede betroffene Datei juenger als ihr 'stand:'. In
# einem laenger gewachsenen Repo meldet die Kategorie Aktualitaet danach alle auf einmal,
# obwohl keine Aussage geaendert wurde.
# Geprueft wird der Diff dieses einen Commits fuer diese eine Datei: Bleibt nach Abzug
# der beiden Frontmatter-Felder keine geaenderte Zeile uebrig, war er hier inhaltsneutral.
# Ein leerer oder nicht lesbarer Diff (Merge-Commit, Umbenennung) gilt bewusst als
# inhaltliche Aenderung, die Pruefung faellt also immer auf die Warnung zurueck.
function Test-NurStatusfelder([string]$hash, [string]$pfad) {
    $diff = & git -C $repo show --format="" --unified=0 $hash -- "$pfad" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $diff) { return $false }
    $inhaltszeilen = @($diff | Where-Object { $_ -match '^[+-]' -and $_ -notmatch '^(\+\+\+|---)' })
    if ($inhaltszeilen.Count -eq 0) { return $false }
    foreach ($z in $inhaltszeilen) {
        if ($z -notmatch '^[+-]\s*(herkunft|geprueft):') { return $false }
    }
    return $true
}

# Rein mechanische Commits, die den Inhalt einer Datei NICHT veraendert haben und
# deshalb bei der Drift-Berechnung uebersprungen werden. Hintergrund: Ein Massenlauf
# ueber viele Dateien (z.B. eine Umstellung der Linkschreibweise) aendert keine
# einzige Aussage darin. Wuerde man dafuer ueberall 'stand:' auf den Umstellungstag
# setzen, behaupteten anschliessend auch alte Notizen, sie seien heute geprueft
# worden, also genau die Fehlinformation, die 'stand:' verhindern soll. Umgekehrt
# wuerde eine Dauer-Warnung ueber alle betroffenen Dateien den Check unbrauchbar
# machen. Deshalb: Commit ueberspringen, 'stand:' unangetastet lassen.
#
# Die Liste steht bewusst NICHT hier im Skript, sondern in 00_INDEX\drift-ausnahmen.txt:
# health-check.ps1 gehoert zum Kern und wird bei jedem Mechanik-Update ersetzt, ein hier
# eingetragener Hash waere danach weg. Die Ausnahmedatei gehoert dir und wird von keinem
# Update angefasst. Format: eine Zeile je Commit, alles ab '#' ist Kommentar. Neue
# Eintraege NUR fuer nachweislich inhaltsneutrale Massenlaeufe.
$mechanicalCommits = @()
$driftAusnahmeDatei = Join-Path $repo "00_INDEX\drift-ausnahmen.txt"
if (Test-Path -LiteralPath $driftAusnahmeDatei) {
    $mechanicalCommits = @(Get-Content -LiteralPath $driftAusnahmeDatei -Encoding UTF8 -ErrorAction SilentlyContinue |
        ForEach-Object { ($_ -split '#')[0].Trim() } |
        Where-Object { $_ -match '^[0-9a-fA-F]{7,40}$' })
}
Get-ChildItem -Path $repo -Recurse -Filter "*.md" -File | Where-Object { $_.Name -ne "_INDEX.md" -and $_.FullName -notmatch $excludedDirPattern } | ForEach-Object {
    $hasExpiry = $false
    $gb = Select-String -Path $_.FullName -Pattern '^gueltig_bis:\s*(\d{4}-\d{2}-\d{2})' -List -ErrorAction SilentlyContinue
    if ($gb) {
        $hasExpiry = $true
        $gbStr = $gb.Matches[0].Groups[1].Value
        $gbDate = [datetime]::ParseExact($gbStr, "yyyy-MM-dd", $null)
        if ((Get-Date).Date -gt $gbDate.Date) {
            $expiredDays = (New-TimeSpan -Start $gbDate.Date -End (Get-Date).Date).Days
            $expiredFiles += "$($_.FullName.Substring($repo.Length + 1)) (gueltig_bis $gbStr, seit $expiredDays Tag(en) abgelaufen)"
        }
    }
    $m = Select-String -Path $_.FullName -Pattern '^stand:\s*(\d{4}-\d{2}-\d{2})' -List -ErrorAction SilentlyContinue
    if ($m) {
        $standStr = $m.Matches[0].Groups[1].Value
        $d = [datetime]::ParseExact($standStr, "yyyy-MM-dd", $null)
        $age = (New-TimeSpan -Start $d -End (Get-Date)).Days
        if ($age -gt 60 -and -not $hasExpiry) {
            $staleFiles += "$($_.FullName.Substring($repo.Length + 1)) (Stand $standStr, $age Tage alt)"
        }
        # 6b) Drift: Datei wurde laut Git DEUTLICH nach dem eingetragenen stand:
        # geaendert (> 7 Tage) - stand: wurde beim Bearbeiten nicht nachgefuehrt.
        $rel = $_.FullName.Substring($repo.Length + 1).Replace('\', '/')
        if ($knownDriftExceptions -contains $rel) { return }
        # Juengste Aenderung suchen, die kein rein mechanischer Commit war.
        $gitDateRaw = $null
        $hist = & git -C $repo log --format="%H %ad" --date=format:%Y-%m-%d -- "$($_.FullName)" 2>$null
        if ($LASTEXITCODE -eq 0) {
            foreach ($line in @($hist)) {
                $parts = "$line".Split(' ')
                if ($parts.Count -lt 2) { continue }
                $skip = $false
                foreach ($mc in $mechanicalCommits) { if ($parts[0].StartsWith($mc)) { $skip = $true; break } }
                if ($skip) { continue }
                # Der Blick in den Diff lohnt erst, wenn dieser Commit ueberhaupt eine
                # Warnung ausloesen wuerde. Liegt er innerhalb der Toleranz, wird kein
                # git show aufgerufen: Die teurere Pruefung trifft nur Kandidaten.
                if ("$($parts[1])" -match '^\d{4}-\d{2}-\d{2}$') {
                    $kandidat = [datetime]::ParseExact($parts[1], "yyyy-MM-dd", $null)
                    if ((New-TimeSpan -Start $d -End $kandidat).Days -gt 7 -and (Test-NurStatusfelder $parts[0] $_.FullName)) { continue }
                }
                $gitDateRaw = $parts[1]
                break
            }
        }
        if ("$gitDateRaw" -match '^\d{4}-\d{2}-\d{2}$') {
            $gitDate = [datetime]::ParseExact("$gitDateRaw", "yyyy-MM-dd", $null)
            $lagDays = (New-TimeSpan -Start $d -End $gitDate).Days
            if ($lagDays -gt 7) {
                $driftFiles += "$($_.FullName.Substring($repo.Length + 1)) (stand: $standStr, letzte Git-Aenderung $gitDateRaw)"
            }
        }
    }
}
if ($staleFiles.Count -gt 0) {
    Add-Check "WARN" $cat "$($staleFiles.Count) Datei(en) mit 'stand:' aelter als 60 Tage: $($staleFiles -join ' | ')"
} else {
    Add-Check "OK" $cat "Keine 'stand:'-Datumsangabe aelter als 60 Tage (Dateien mit eigenem 'gueltig_bis' sind hier ausgenommen)."
}
if ($expiredFiles.Count -gt 0) {
    Add-Check "WARN" $cat "$($expiredFiles.Count) Datei(en) mit abgelaufenem 'gueltig_bis': $($expiredFiles -join ' | ') - je Datei entscheiden: erledigt (Inhalt in die zustaendige Wissensdatei uebernehmen und Datei loeschen), verlaengern (neues Datum) oder als Historie behalten ('gueltig_bis' entfernen)."
} else {
    Add-Check "OK" $cat "Keine Datei mit abgelaufenem 'gueltig_bis'."
}
if ($driftFiles.Count -gt 0) {
    Add-Check "WARN" $cat "$($driftFiles.Count) Datei(en) wurden nach ihrem 'stand:'-Datum weiter geaendert, ohne dass stand: nachgefuehrt wurde: $($driftFiles -join ' | ')"
} else {
    Add-Check "OK" $cat "Alle 'stand:'-Datumsangaben passen zur letzten Git-Aenderung (Toleranz 7 Tage)."
}

# 6c) Dynamische Dateien OHNE 'stand:'-Kennzeichnung.
# 'stand:' im Frontmatter ist die verbindliche Kennzeichnung fuer Dokumente mit
# variablem Input (AGENTS.md Abschnitt 7). Zwei Heuristiken, damit nichts durchrutscht:
# (a) Dateiname klingt dynamisch, (b) Inhalt enthaelt offene Checkboxen oder eine
# Status-Spalte in einer Tabelle (faengt dynamische Inhalte hinter unauffaelligen
# Namen), (c) Datei liegt in einem Ordner, dessen Inhalt per lokaler AGENTS.md
# als lebende Arbeitsdokumente definiert ist. Bewusst WARN, nicht FAIL.
$dynamicNamePattern = '(aufgaben|taskliste|tasks|status|todo|to-do|verlauf|backlog|pendenzen|checklist|plan)'
$dynamicContentPattern = '(^\s*[-*] \[[ xX]\] )|(\|\s*Status\s*\|)'
$dynamicDirPattern = '\\__KEIN_LEBEND_ORDNER_DEFINIERT__\\'
# Ausnahmen: dynamisch klingender Name/Inhalt/Ort, aber tatsaechlich statisch.
# Hier bewusst leer; bei Bedarf selbst eintragen. Format: "Themenordner/relativer Pfad".
$knownStaticExceptions = @(
)
$untagged = @()
Get-ChildItem -Path $repo -Recurse -Filter "*.md" -File |
    Where-Object {
        $_.FullName -notmatch $excludedDirPattern -and
        $_.FullName -notmatch '\\(00_INDEX|02_Skills|03_Sessionlogs)\\' -and
        $_.Name -notin @("README.md", "AGENTS.md", "_INDEX.md")
    } | ForEach-Object {
        $rel = $_.FullName.Substring($repo.Length + 1).Replace('\', '/')
        if ($knownStaticExceptions -contains $rel) { return }
        $nameHit = $_.BaseName -match $dynamicNamePattern
        $dirHit = $_.FullName -match $dynamicDirPattern
        $contentHit = $false
        if (-not ($nameHit -or $dirHit)) {
            $contentHit = [bool](Select-String -Path $_.FullName -Pattern $dynamicContentPattern -List -ErrorAction SilentlyContinue)
        }
        if (-not ($nameHit -or $dirHit -or $contentHit)) { return }
        $hasStand = Select-String -Path $_.FullName -Pattern '^stand:\s*\d{4}-\d{2}-\d{2}' -List -ErrorAction SilentlyContinue
        if (-not $hasStand) {
            $reason = if ($nameHit) { "Name" } elseif ($dirHit) { "Ordner mit lebenden Arbeitsdokumenten" } else { "Inhalt: Checkboxen/Status-Tabelle" }
            $untagged += "$rel ($reason)"
        }
    }
if ($untagged.Count -gt 0) {
    Add-Check "WARN" $cat "$($untagged.Count) dynamische Datei(en) ohne 'stand:'-Frontmatter (Kennzeichnungspflicht, AGENTS.md Abschnitt 7): $($untagged -join ', ') - 'stand:' ergaenzen oder als statische Ausnahme in health-check.ps1 eintragen."
} else {
    Add-Check "OK" $cat "Alle als dynamisch erkannten Dateien (Name/Inhalt/Ordner) tragen die 'stand:'-Kennzeichnung."
}
Write-Output "Aktualitaets-Checks erledigt."

# ---------------------------------------------------------------------------
# 7) SKILL-REGISTRY-KONSISTENZ
# ---------------------------------------------------------------------------
$cat = "Skills"
$skillDir = Join-Path $repo "02_Skills"
$registerFile = Join-Path $skillDir "Skill-Register.md"

if (-not (Test-Path $registerFile)) {
    Add-Check "FAIL" $cat "Skill-Register.md fehlt komplett."
} else {
    $registerText = Get-Content -Path $registerFile -Raw -Encoding UTF8
    $skillFiles = Get-ChildItem -Path $skillDir -Filter "*.md" -File | Where-Object { $_.Name -notin @("README.md", "Skill-Register.md") }

    $unregistered = @()
    foreach ($sf in $skillFiles) {
        if ($registerText -notmatch [regex]::Escape("02_Skills/$($sf.Name)") -and $registerText -notmatch [regex]::Escape("02_Skills\$($sf.Name)")) {
            $unregistered += $sf.Name
        }
    }
    if ($unregistered.Count -gt 0) {
        Add-Check "WARN" $cat "Skill-Datei(en) existieren, sind aber nicht im Skill-Register eingetragen: $($unregistered -join ', ')"
    }

    $registerRows = [regex]::Matches($registerText, '(?m)^\|[^\n|]+\|[^\n|]+\|\s*(02_Skills[/\\][^\s|]+\.md)\s*\|')
    $brokenRefs = @()
    foreach ($rm in $registerRows) {
        $relPath = $rm.Groups[1].Value.Replace('\', '/')
        if (-not (Test-Path (Join-Path $repo $relPath))) { $brokenRefs += $relPath }
    }
    if ($brokenRefs.Count -gt 0) {
        # Haeufigste Ursache bei umbenannten Systemen: Das Register nennt die Skills noch
        # mit dem Praefix des Grundgeruests, die Dateien tragen laengst das eigene. Der
        # Hinweis spart die Suche nach der Ursache (Trockenlauf 31.08.2026).
        $nurPraefix = @($brokenRefs | Where-Object {
            $bn = Split-Path $_ -Leaf
            $rest = $bn -replace '^[a-z0-9]+-', ''
            @(Get-ChildItem -Path $skillDir -Filter "*$rest" -File -ErrorAction SilentlyContinue).Count -gt 0
        })
        $zusatz = ""
        if ($nurPraefix.Count -gt 0) {
            $zusatz = " Bei $($nurPraefix.Count) davon existiert dieselbe Datei unter einem anderen Praefix: Das Register wurde beim Umbenennen des Systems nicht nachgezogen. Dateinamen im Register auf das eigene Praefix aendern (MEIN-SYSTEM.md, Abschnitt 1), danach das Index-Skript laufen lassen."
        }
        Add-Check "FAIL" $cat "Skill-Register verweist auf nicht existierende Datei(en): $($brokenRefs -join ', ').$zusatz"
    }

    $triggerRows = [regex]::Matches($registerText, '(?m)^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|')
    $allTriggers = New-Object System.Collections.Generic.List[PSCustomObject]
    foreach ($tr in $triggerRows) {
        $skillName = $tr.Groups[1].Value.Trim()
        if ($skillName -eq "Skill" -or $skillName -match "^-+$") { continue }
        $triggerCol = $tr.Groups[2].Value
        $words = [regex]::Matches($triggerCol, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value.Trim().ToLower() }
        foreach ($w in $words) { $allTriggers.Add([PSCustomObject]@{ Skill = $skillName; Word = $w }) }
    }
    $dupTriggers = $allTriggers | Group-Object Word | Where-Object { $_.Count -gt 1 }
    foreach ($d in $dupTriggers) {
        $owners = ($d.Group.Skill | Select-Object -Unique)
        if ($owners.Count -gt 1) {
            Add-Check "FAIL" $cat "Trigger-Wort '$($d.Name)' ist mehrdeutig, verwendet von: $($owners -join ', ')"
        }
    }
    if ($skillFiles.Count -gt 0 -and $unregistered.Count -eq 0 -and $brokenRefs.Count -eq 0 -and $dupTriggers.Count -eq 0) {
        Add-Check "OK" $cat "$($skillFiles.Count) Skill-Dateien, Register vollstaendig und konsistent, Trigger-Woerter eindeutig."
    }
}
Write-Output "Skill-Registry-Checks erledigt."

# ---------------------------------------------------------------------------
# 8) ENCODING-SANITY
# ---------------------------------------------------------------------------
$cat = "Encoding"
$replacementChar = [char]0xFFFD
$badFiles = Get-ChildItem -Path $repo -Recurse -Filter "*.md" -File |
    Where-Object { $_.FullName -notmatch $excludedDirPattern } |
    ForEach-Object {
        $hit = Select-String -Path $_.FullName -Pattern ([regex]::Escape($replacementChar)) -List -ErrorAction SilentlyContinue
        if ($hit) { $_.FullName.Substring($repo.Length + 1) }
    }
if ($badFiles) {
    Add-Check "WARN" $cat "Replacement-Zeichen (Encoding-Problem) gefunden in: $($badFiles -join ', ')"
} else {
    Add-Check "OK" $cat "Keine Encoding-Artefakte (Replacement-Zeichen) gefunden."
}
Write-Output "Encoding-Checks erledigt."

# ---------------------------------------------------------------------------
# 9) INBOX
# ---------------------------------------------------------------------------
$cat = "Inbox"
# Rekursiv und ueber alle Dateitypen: In der Inbox liegen typischerweise PDFs, Scans und
# Office-Dateien, und seit dem 30.07.2026 auch Unterordner. Eine Pruefung nur auf *.md
# direkt im Ordner meldete eine volle Inbox als leer.
$inboxRoot = Join-Path $repo "90_Inbox"
$inboxFiles = Get-ChildItem -Path $inboxRoot -File -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object { $_.FullName.Substring($inboxRoot.Length + 1) } |
    Where-Object { $_ -ne "README.md" }
if ($inboxFiles.Count -gt 0) {
    $shown = $inboxFiles | Select-Object -First 10
    $liste = $shown -join ', '
    if ($inboxFiles.Count -gt $shown.Count) { $liste += ", ... und $($inboxFiles.Count - $shown.Count) weitere" }
    Add-Check "WARN" $cat "$($inboxFiles.Count) unsortierte Datei(en) in 90_Inbox: $liste - wird im Skill 'leo-system-health-check' (Schritt Inbox) behandelt."
} else {
    Add-Check "OK" $cat "90_Inbox leer (bis auf README.md), inkl. Unterordner und Nicht-Markdown-Dateien."
}
Write-Output "Inbox-Check erledigt."

# ---------------------------------------------------------------------------
# 10) 01_BASISKONTEXT - KUERZLICHE AENDERUNGEN (gegen Changelog abgleichen)
# ---------------------------------------------------------------------------
$cat = "Basiskontext"
$changelogFile = Join-Path $repo "04_Changelog\Changelog.md"
if (-not (Test-Path $changelogFile)) {
    Add-Check "WARN" $cat "04_Changelog\Changelog.md fehlt - Aenderungen an 01_Basiskontext koennten unprotokolliert sein."
}
Get-ChildItem -Path (Join-Path $repo "01_Basiskontext") -Filter "*.md" -File -ErrorAction SilentlyContinue | ForEach-Object {
    $lastLog = & git -C $repo log -1 --format="%ad|%s" --date=format:%Y-%m-%d -- "$($_.FullName)" 2>&1
    if ($LASTEXITCODE -eq 0 -and $lastLog -match '^(\d{4}-\d{2}-\d{2})\|(.*)$') {
        $d = [datetime]::ParseExact($matches[1], "yyyy-MM-dd", $null)
        $age = (New-TimeSpan -Start $d -End (Get-Date)).Days
        if ($age -le 14) {
            Add-Check "INFO" $cat "$($_.Name) vor $age Tag(en) geaendert (Commit: '$($matches[2])') - gegen Changelog abgleichen, falls nicht bereits bestaetigt."
        }
    }
}
Write-Output "Basiskontext-Checks erledigt."

# ---------------------------------------------------------------------------
# 11) HARNESS-PORTABILITAETSDATEIEN
# ---------------------------------------------------------------------------
$cat = "Portabilitaet"
foreach ($f in @("CLAUDE.md", "GEMINI.md", ".clinerules", ".github/copilot-instructions.md")) {
    $full = Join-Path $repo $f
    if (-not (Test-Path $full)) {
        Add-Check "FAIL" $cat "$f fehlt im Root."
        continue
    }
    $content = Get-Content -Path $full -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($content)) {
        Add-Check "FAIL" $cat "$f ist leer."
    } elseif ($content -notmatch "AGENTS\.md") {
        Add-Check "WARN" $cat "$f verweist nicht erkennbar auf AGENTS.md."
    } else {
        Add-Check "OK" $cat "$f vorhanden und verweist auf AGENTS.md."
    }
}
# Seit E21/E22 duerfen sich CLAUDE.md und GEMINI.md im Wortlaut unterscheiden: Claude Code
# importiert mit "@Pfad", Gemini CLI verlangt "@./Pfad" (Memory Import Processor), und
# GEMINI.md traegt zusaetzlich einen Verifikations-Hinweis. Ein Byte-Vergleich wuerde das
# als Fehler melden und waere ab sofort Dauerrauschen. Geprueft wird deshalb die Eigenschaft,
# auf die es wirklich ankommt: Beide Dateien muessen dieselbe Menge an Dateien importieren
# (AGENTS.md plus alle Dateien in 01_Basiskontext), damit der Basiskontext-Zwang in jedem
# Harness greift und nicht nur in Claude Code.
function Get-ImportSet([string]$file) {
    $set = New-Object System.Collections.Generic.HashSet[string]
    $raw = Get-Content -Path $file -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $raw) { return ,$set }
    $raw = [regex]::Replace($raw, '`[^`\r\n]*`', '')   # Beispiele in Backticks ignorieren
    foreach ($line in ($raw -split "`r?`n")) {
        if ($line -match '^\s*@(\.{1,2}/)?(.+?)\s*$') {
            # Maskierte Leerzeichen ("Voice\ and\ Style.md") zuerst zuruecknehmen, sonst
            # macht die Ersetzung darunter aus dem Escape-Backslash einen Pfadtrenner.
            $ziel = $matches[2] -replace '\\ ', ' '
            [void]$set.Add(($ziel -replace '\\', '/').Trim().ToLower())
        }
    }
    # Komma-Operator: verhindert, dass PowerShell die Menge beim Return entrollt. Ohne
    # ihn kommt bei einem LEEREN Set $null zurueck, der Contains-Aufruf unten wirft, und
    # der Check meldet danach faelschlich OK - also ausgerechnet dann gruen, wenn gar
    # kein Import vorhanden ist.
    return ,$set
}
$claudeImports = Get-ImportSet (Join-Path $repo "CLAUDE.md")
$geminiImports = Get-ImportSet (Join-Path $repo "GEMINI.md")
$expected = New-Object System.Collections.Generic.HashSet[string]
[void]$expected.Add("agents.md")
Get-ChildItem -Path (Join-Path $repo "01_Basiskontext") -Filter "*.md" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "README.md" } |
    ForEach-Object { [void]$expected.Add("01_basiskontext/$($_.Name.ToLower())") }

# Ein Import, der DASTEHT, ist noch kein Import, der LAEDT. Enthaelt ein Dateiname ein
# Leerzeichen, liest der Importparser den Pfad nur bis dorthin, und die Datei kommt nie
# im Kontext an, waehrend die Zeile voellig richtig aussieht. Am 26.08.2026 empirisch
# nachgewiesen; ein maskiertes Leerzeichen ("Voice\ and\ Style.md") laedt, ein
# Anfuehrungszeichen nicht. Diese Pruefung ist FAIL und nicht WARN: Ohne den geladenen
# Basiskontext arbeitet das System ohne Stil- und Personenwissen weiter, ohne dass es
# jemandem auffaellt.
$importUnescaped = @()
foreach ($datei in @("CLAUDE.md", "GEMINI.md")) {
    $pfad = Join-Path $repo $datei
    if (-not (Test-Path -LiteralPath $pfad)) { continue }
    foreach ($line in (Get-Content -LiteralPath $pfad -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($line -notmatch '^\s*@(\S.*)$') { continue }
        $ziel = $matches[1].Trim()
        if ($ziel -match '^"') { $importUnescaped += "$datei -> $ziel (Anfuehrungszeichen funktionieren nicht)"; continue }
        if ($ziel -match '(?<!\\) ') { $importUnescaped += "$datei -> $ziel" }
    }
}
if ($importUnescaped.Count -gt 0) {
    Add-Check "FAIL" $cat "$($importUnescaped.Count) Importzeile(n) mit unmaskiertem Leerzeichen im Pfad. Diese Dateien werden NICHT geladen, obwohl die Zeile dasteht. Leerzeichen mit Backslash maskieren. Treffer: $($importUnescaped -join ' | ')"
} else {
    Add-Check "OK" $cat "Alle Importpfade in CLAUDE.md und GEMINI.md sind ladbar: kein unmaskiertes Leerzeichen, keine Anfuehrungszeichen."
}
foreach ($pair in @(@{ n = "CLAUDE.md"; s = $claudeImports }, @{ n = "GEMINI.md"; s = $geminiImports })) {
    $missing = @($expected | Where-Object { -not $pair.s.Contains($_) })
    if ($missing.Count -gt 0) {
        Add-Check "WARN" $cat "$($pair.n) importiert $($missing.Count) Pflichtdatei(en) nicht: $($missing -join ', '). Ohne Import ist der Basiskontext-Zwang aus E21 in diesem Harness wirkungslos."
    } else {
        Add-Check "OK" $cat "$($pair.n) importiert AGENTS.md und alle $($expected.Count - 1) Basiskontext-Dateien (E21)."
    }
}

# Die Werkzeuge ohne Import-Mechanik (.clinerules, copilot-instructions.md) koennen den
# Basiskontext nicht laden, sie muessen ihn textlich anweisen. Ohne diesen Satz startet
# ein Wechsel dorthin ohne Stilregeln, und genau das soll der Basiskontext-Zwang verhindern.
foreach ($f in @(".clinerules", ".github/copilot-instructions.md")) {
    $full = Join-Path $repo $f
    if (-not (Test-Path $full)) { continue }
    $content = Get-Content -Path $full -Raw -Encoding UTF8
    if ($content -notmatch "01_Basiskontext") {
        Add-Check "WARN" $cat "$f weist nicht auf 01_Basiskontext hin. Dieses Werkzeug kennt keinen Import; ohne die textliche Anweisung greift der Basiskontext-Zwang dort nicht (AGENTS.md Abschnitt 11a)."
    } else {
        Add-Check "OK" $cat "$f weist textlich auf 01_Basiskontext hin (Ersatz fuer den fehlenden Import)."
    }
}

# Skill-Zeiger in allen Werkzeug-Pfaden (AGENTS.md Abschnitt 11a). Geprueft wird, ob jedes
# Zielverzeichnis genau die Skills aus dem Register traegt. Faellt eines zurueck, fehlen
# beim Wechsel in dieses Werkzeug still ein paar Skills - der Fehler, den man erst merkt,
# wenn man ihn schon gemacht hat. Die Liste ist identisch zu $targets in
# build-skill-wrapper.ps1 zu halten; wer eine aendert, zieht die andere nach.
$skillTargets = @(".claude/skills", ".agents/skills", ".gemini/skills", ".cursor/skills", ".cline/skills", ".opencode/skills")
$registerSlugs = @()
$regFile = Join-Path $repo "02_Skills\Skill-Register.md"
if (Test-Path $regFile) {
    foreach ($line in (Get-Content -Path $regFile -Encoding UTF8)) {
        $t = $line.Trim()
        if (-not $t.StartsWith("|")) { continue }
        $cols = ($t.Trim("|") -split "\|") | ForEach-Object { $_.Trim() }
        if ($cols.Count -lt 4) { continue }
        if ($cols[2] -match "([^/\\]+)\.md\s*$") { $registerSlugs += $matches[1] }
    }
}
if ($registerSlugs.Count -eq 0) {
    Add-Check "WARN" $cat "Keine Skills aus dem Register gelesen - Zeiger-Pruefung uebersprungen."
} else {
    $behind = @()
    foreach ($rel in $skillTargets) {
        $dir = Join-Path $repo ($rel -replace '/', '\')
        $missing = @($registerSlugs | Where-Object { -not (Test-Path (Join-Path $dir "$_\SKILL.md")) })
        if ($missing.Count -gt 0) { $behind += "$rel (fehlen: $($missing.Count))" }
    }
    if ($behind.Count -gt 0) {
        Add-Check "WARN" $cat "Skill-Zeiger unvollstaendig in: $($behind -join ', '). Behebung: pwsh -NoProfile -ExecutionPolicy Bypass -File `"$repo\00_INDEX\scripts\build-skill-wrapper.ps1`""
    } else {
        Add-Check "OK" $cat "Skill-Zeiger vollstaendig: $($registerSlugs.Count) Skills in allen $($skillTargets.Count) Werkzeug-Pfaden (Abschnitt 11a)."
    }
}
# Kodierung der PowerShell-Skripte.
# Windows PowerShell 5.1 liest eine .ps1 ohne BOM als ANSI. Enthaelt die Datei Umlaute,
# zerfallen sie beim Parsen (aus einem Umlaut werden zwei Zeichen, deren zweites der
# 5.1er Tokenizer als Anfuehrungszeichen liest), und das Skript bricht ab, bevor eine
# Zeile laeuft. Auf einem Rechner ohne PowerShell 7 ist es damit unbenutzbar, und der
# Schaden ist still: Es erscheint keine Fehlermeldung, die betroffene Automatik hoert
# einfach auf zu wirken. Zulaessig ist deshalb beides: BOM oder durchgehend ASCII.
$psBad = @()
foreach ($ps in (Get-ChildItem -Path $repo -Recurse -Filter "*.ps1" -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.FullName -notmatch '\\\.git\\' })) {
    $bytes = [System.IO.File]::ReadAllBytes($ps.FullName)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if ($hasBom) { continue }
    if (@($bytes | Where-Object { $_ -gt 127 }).Count -gt 0) {
        $psBad += $ps.FullName.Replace("$repo\", "")
    }
}
if ($psBad.Count -gt 0) {
    Add-Check "FAIL" $cat "PowerShell-Skript ohne BOM, aber mit Nicht-ASCII-Zeichen: $($psBad -join ', '). Unter Windows PowerShell 5.1 (ohne installiertes pwsh) bricht der Parser ab, ohne dass im Alltag eine Meldung erscheint. Behebung: Datei als UTF-8 MIT BOM speichern oder die Umlaute entfernen."
} else {
    Add-Check "OK" $cat "Alle .ps1 sind unter Windows PowerShell 5.1 lesbar (BOM vorhanden oder ASCII-only)."
}

# Gegenrichtung: Die erzeugten Skill-Zeiger duerfen KEINE BOM tragen. Eine BOM vor dem
# "---" macht das Frontmatter fuer den Skill-Loader unlesbar, der Skill zeigt dann als
# Beschreibung nur noch "---". Entstehen kann das, wenn build-skill-wrapper.ps1 mit
# "Set-Content -Encoding UTF8" unter 5.1 laeuft, wo dieser Parameter BOM bedeutet.
# Das Skript schreibt deshalb inzwischen ueber .NET.
$bomZeiger = @()
foreach ($rel in $skillTargets) {
    $dir = Join-Path $repo ($rel -replace '/', '\')
    foreach ($sk in (Get-ChildItem -Path $dir -Recurse -Filter "SKILL.md" -File -ErrorAction SilentlyContinue)) {
        $b = [System.IO.File]::ReadAllBytes($sk.FullName)
        if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) {
            $bomZeiger += $sk.FullName.Replace("$repo\", "")
        }
    }
}
if ($bomZeiger.Count -gt 0) {
    Add-Check "FAIL" $cat "Skill-Zeiger mit BOM vor dem Frontmatter: $($bomZeiger.Count) Datei(en), z.B. $($bomZeiger[0]). Der Skill-Loader liest die Beschreibung dann nicht. Behebung: die betroffenen Dateien loeschen und build-skill-wrapper.ps1 erneut laufen lassen."
} else {
    Add-Check "OK" $cat "Kein Skill-Zeiger traegt eine BOM vor dem Frontmatter."
}

# Arbeitsbereich-Sperre (AGENTS.md Abschnitt 18). Ohne den Hook-Eintrag ist die Regel
# nur Text, und genau das ist der Zustand, den sie ersetzen soll.
$guardSkript = Join-Path $repo "00_INDEX\scripts\guard-workspace.ps1"
$guardSettings = Join-Path $repo ".claude\settings.json"
if (-not (Test-Path $guardSkript)) {
    Add-Check "FAIL" $cat "guard-workspace.ps1 fehlt. Die Arbeitsbereich-Sperre aus AGENTS.md Abschnitt 18 ist damit nicht durchgesetzt."
} elseif (-not (Test-Path $guardSettings)) {
    Add-Check "WARN" $cat "guard-workspace.ps1 vorhanden, aber .claude\settings.json fehlt. In Claude Code ist die Arbeitsbereich-Sperre damit nur eine Textregel."
} elseif ((Get-Content -Path $guardSettings -Raw -Encoding UTF8) -notmatch "guard-workspace") {
    Add-Check "WARN" $cat ".claude\settings.json haengt guard-workspace.ps1 nicht als PreToolUse-Hook ein. Die Sperre wirkt dann nicht."
} else {
    $guardSettingsText = Get-Content -Path $guardSettings -Raw -Encoding UTF8
    $guardIsWindows = [System.IO.Path]::DirectorySeparatorChar -eq '\'
    if (-not $guardIsWindows -and $guardSettingsText -match '"command"\s*:\s*"powershell(?:\s|\")') {
        Add-Check "WARN" $cat ".claude\settings.json haengt den Guard ein, ruft unter macOS/Linux aber die Windows-Befehlszeile powershell auf. Auf den absoluten pwsh-Pfad und POSIX-Pfade umstellen (ANLEITUNG.md Schritt 7a); sonst wirkt die Sperre nicht."
    } else {
        Add-Check "OK" $cat "Arbeitsbereich-Sperre eingehaengt. Ob der Hook im Werkzeug freigeschaltet ist, muss mit der Regressionsreihe und einem echten Blockierfall gegengemessen werden."
    }
    # Zweiter Hook seit 3.3: die Sperre gegen pauschales Stagen (AGENTS.md Abschnitt 12).
    # Eine Verbotsliste in den Einstellungen greift in einem Modus mit vollen Rechten nicht,
    # ein Hook schon. Fehlt der Eintrag, ist die Regel dort nur Text.
    $gitGuardSkript = Join-Path $repo "00_INDEX\scripts\guard-git.ps1"
    if (-not (Test-Path $gitGuardSkript)) {
        Add-Check "WARN" $cat "guard-git.ps1 fehlt. Die Sperre gegen pauschales Stagen (git add -A) aus AGENTS.md Abschnitt 12 ist damit nur eine Textregel."
    } elseif ($guardSettingsText -notmatch "guard-git") {
        Add-Check "WARN" $cat ".claude\settings.json haengt guard-git.ps1 nicht als PreToolUse-Hook ein. In einem Lauf mit vollen Rechten ist git add -A dann nicht gesperrt. Eintrag aus der Zielversion ergaenzen (Skill leo-mechanik-update, Kategorie B)."
    } else {
        Add-Check "OK" $cat "Sperre gegen pauschales Stagen eingehaengt (guard-git.ps1)."
    }
    # Dritter Hook seit 3.4: die Mailversand-Sperre (AGENTS.md Abschnitt 16). Ohne sie ist
    # "Mails nur ueber gmail-senden.py" eine Textregel, und ein Modell unter Aufgabendruck
    # baut sich einen eigenen Sendeweg ohne Offenlegung, CC und Freigabefenster.
    $mailGuardSkript = Join-Path $repo "00_INDEX\scripts\guard-mail.ps1"
    if (-not (Test-Path $mailGuardSkript)) {
        Add-Check "WARN" $cat "guard-mail.ps1 fehlt. Die Mailversand-Sperre aus AGENTS.md Abschnitt 16 ist damit nur eine Textregel."
    } elseif ($guardSettingsText -notmatch "guard-mail") {
        Add-Check "WARN" $cat ".claude\settings.json haengt guard-mail.ps1 nicht als PreToolUse-Hook ein. Ein eigener Sendeweg aus einer Session ist dann nicht gesperrt. Eintrag aus der Zielversion ergaenzen (Skill leo-mechanik-update, Kategorie B)."
    } else {
        Add-Check "OK" $cat "Mailversand-Sperre eingehaengt (guard-mail.ps1)."
    }
}

Write-Output "Portabilitaets-Checks erledigt."

# ---------------------------------------------------------------------------
# 12) HARNESS-MEMORY (muss leer bleiben: kein zweites Gedaechtnis neben dem Repo)
# ---------------------------------------------------------------------------
# Hintergrund: Manche Harnesses (z.B. Claude Code) fuehren ausserhalb des Repos
# einen eigenen, persistenten Memory-Speicher. Fuer Leo ist der nicht zugelassen
# (Root-AGENTS.md Abschnitt 1, Entscheid 15.07.2026, Technik T17e): Er waere ein
# zweites, nicht portables Gedaechtnis neben den Markdown-Dateien, und er laesst
# sich nicht einmal sichern (der Pfad ist ein Reparse-Point, git kann ihn nicht
# traversieren). Ein Mirror-Schritt ins Repo wurde geprueft und VERWORFEN.
# Richtig ist: Inhalt mit Dauerwert in die zustaendige Repo-Datei migrieren,
# danach die Memory-Datei loeschen. Diese Pruefung meldet deshalb jeden
# Fuellstand groesser 0 als Handlungsbedarf.
$cat = "Harness-Memory"
$memSlug = ($repo -replace ':', '-' -replace '[\\/]', '-')
$memPath = Join-Path $env:USERPROFILE ".claude\projects\$memSlug\memory"
if (-not (Test-Path $memPath)) {
    Add-Check "INFO" $cat "Harness-Memory-Pfad nicht gefunden ($memPath) - evtl. anderes Harness/Benutzer. Keine Aktion."
} else {
    try {
        $memCount = (Get-ChildItem -Path $memPath -File -Recurse -Force -ErrorAction Stop | Measure-Object).Count
        if ($memCount -gt 0) {
            Add-Check "WARN" $cat "Harness-Memory enthaelt $memCount Datei(en) - ein harness-eigener Memory-Speicher ist fuer Leo nicht zugelassen (Root-AGENTS.md Abschnitt 1). Jede Datei lesen, Inhalt mit Dauerwert in die zustaendige Repo-Datei migrieren (Ziele in 01_Basiskontext nur mit Bestaetigung), danach die Memory-Datei loeschen. KEINEN Repo-Mirror bauen (Technik T17e). Pfad: $memPath"
        } else {
            Add-Check "OK" $cat "Harness-Memory leer - kein zweites Gedaechtnis neben dem Repo (Root-AGENTS.md Abschnitt 1)."
        }
    } catch {
        Add-Check "INFO" $cat "Harness-Memory-Pfad nicht lesbar (Reparse-Point: $($_.Exception.Message)) - Fuellstand nicht bestimmbar, spaeter erneut pruefen."
    }
}
Write-Output "Harness-Memory-Check erledigt."

# ---------------------------------------------------------------------------
# 12b) CLI-STAND (Update des Werkzeugs verfuegbar?)
# ---------------------------------------------------------------------------
# Seit 3.3. Ein veraltetes Werkzeug faellt im Alltag nicht auf, weil nichts fehlschlaegt;
# Verbesserungen und Fehlerbehebungen bleiben einfach aus. Vergleicht die installierte
# Claude-Code-CLI mit der aktuellen Version auf npm; WARN nennt den einen Befehl.
# Fail-open: ohne Netz, ohne npm oder ohne diese CLI nur INFO, nie ein Befund.
$cat = "CLI"
try {
    $inst = $null
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        $inst = (& claude --version 2>$null | Select-Object -First 1) -replace '[^0-9.].*$', ''
    }
    $akt = $null
    if ($inst -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        try { $akt = (& npm view @anthropic-ai/claude-code version 2>$null | Select-Object -Last 1).Trim() } catch { }
    }
    if (-not $inst) {
        Add-Check "INFO" $cat "Keine Claude-Code-CLI gefunden; CLI-Stand nicht pruefbar (bei einem anderen Werkzeug erwartbar)."
    } elseif (-not $akt) {
        Add-Check "INFO" $cat "Installiert $inst; aktuelle Version auf npm nicht abrufbar (kein Netz oder npm fehlt). Kein Befund ueber die CLI."
    } elseif ($inst -eq $akt) {
        Add-Check "OK" $cat "Claude Code $inst ist aktuell (npm: $akt)."
    } else {
        Add-Check "WARN" $cat "Claude Code Update verfuegbar: installiert $inst, aktuell $akt. In der Kommandozeile: claude update"
    }
} catch { Add-Check "INFO" $cat "CLI-Pruefung fehlgeschlagen: $($_.Exception.Message)" }
Write-Output "CLI-Check erledigt."
Write-Output ""


# ---------------------------------------------------------------------------
# 13) TOTE LINKS (Wikilinks und Markdown-Links auf .md-Dateien)
# ---------------------------------------------------------------------------
# Hintergrund: Seit 26.07.2026 sind Querverweise zwischen Wissensdateien echte
# Obsidian-Links statt Pfadnennungen in Backticks (Root-AGENTS.md Abschnitt 5,
# Entscheid E22). Der Nutzen dieser Umstellung haengt daran, dass die Links auch
# stimmen: Ein toter Verweis kostet das LLM eine Fehlsuche und ist im Fliesstext
# unsichtbar. Beim Umstellungslauf waren 26 der bestehenden Pfadnennungen bereits
# verrottet (umbenannte, versionierte oder geloeschte Ziele). Diese Pruefung
# faengt genau das mechanisch ab.
#
# Aufloesung wie in Obsidian: exakter vault-relativer Pfad ODER eindeutiger
# Dateiname. Reine Abschnittslinks ([[#Ueberschrift]]) werden uebersprungen,
# ebenso alles in Code-Bloecken und Inline-Code (dort stehen Beispiele, keine
# echten Verweise).
$cat = "Links"
$mdAll = Get-ChildItem -Path $repo -Recurse -File -Filter "*.md" |
    Where-Object { $_.FullName -notmatch $excludedDirPattern }

$relByLower = @{}
$byBase = @{}
foreach ($f in $mdAll) {
    $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
    $relByLower[$rel.ToLower()] = $rel
    $bn = $f.Name.ToLower()
    if (-not $byBase.ContainsKey($bn)) { $byBase[$bn] = New-Object System.Collections.Generic.List[string] }
    $byBase[$bn].Add($rel)
}

$deadLinks = New-Object System.Collections.Generic.List[string]
$ambiguousLinks = New-Object System.Collections.Generic.List[string]
$linkCount = 0
foreach ($f in $mdAll) {
    $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
    $raw = Get-Content -Path $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $raw) { continue }
    # Code-Bloecke und Inline-Code entfernen, damit Beispiele nicht als Verweis zaehlen.
    $txt = [regex]::Replace($raw, '(?s)```.*?```', '')
    $txt = [regex]::Replace($txt, '`[^`\r\n]*`', '')

    foreach ($m in [regex]::Matches($txt, '\[\[([^\]]+)\]\]')) {
        $target = ($m.Groups[1].Value -split '\|')[0]
        $target = ($target -split '#')[0].Trim()
        if ([string]::IsNullOrWhiteSpace($target)) { continue }   # reiner Abschnittslink
        $linkCount++
        $probe = ($target + '.md').ToLower()
        $bn = (Split-Path $probe -Leaf)
        # Qualifizierter Verweis (mit Ordnerpfad). Obsidian akzeptiert dafuer drei
        # Schreibweisen: vault-relativ ab Repo-Wurzel, relativ zum Ordner der
        # Quelldatei, und als eindeutiges Pfad-Ende. Wer nur eine davon prueft,
        # meldet intakte Verweise als tot, und eine Warnung, die falsch liegt, wird
        # nach dem dritten Mal ignoriert.
        if ($probe -match '[\\/]') {
            $probeSlash = $probe -replace '\\', '/'
            if ($relByLower.ContainsKey($probeSlash)) { continue }
            $relDir = (Split-Path $rel -Parent) -replace '\\', '/'
            if ($relDir -and $relByLower.ContainsKey("$relDir/$probeSlash".ToLower())) { continue }
            $suffixHits = @($relByLower.Keys | Where-Object { $_.EndsWith("/$probeSlash") })
            if ($suffixHits.Count -eq 1) { continue }
            if ($suffixHits.Count -gt 1) {
                $ambiguousLinks.Add("$rel -> [[$target]] ($($suffixHits.Count) Kandidaten)")
            } else {
                $deadLinks.Add("$rel -> [[$target]]")
            }
            continue
        }
        # Blosser Dateiname: die Eindeutigkeit entscheidet, NICHT ein zufaelliger
        # Treffer im Repo-Root. Stand die Root-Pruefung zuerst, loeste [[AGENTS]]
        # aus einem Themenordner stumm auf die Root-AGENTS.md auf, obwohl die
        # lokale gemeint war. Der Check meldete "alle Verweise loesen auf", und das
        # LLM suchte den zitierten Abschnitt im falschen Dokument. Ein Verweis, der
        # je nach Werkzeug woanders landet, ist kein gueltiger Verweis, auch wenn
        # irgendeine Datei dieses Namens existiert.
        if (-not $byBase.ContainsKey($bn)) {
            $deadLinks.Add("$rel -> [[$target]]")
        } elseif ($byBase[$bn].Count -gt 1) {
            $ambiguousLinks.Add("$rel -> [[$target]] ($($byBase[$bn].Count) Kandidaten)")
        }
    }

    foreach ($m in [regex]::Matches($txt, '\]\(([^)]+\.md)\)')) {
        $t = $m.Groups[1].Value
        if ($t -match '^(https?|mailto):') { continue }
        $linkCount++
        $t = [uri]::UnescapeDataString(($t -split '#')[0])
        $combined = Join-Path (Split-Path $f.FullName -Parent) ($t -replace '/', '\')
        $norm = try { [System.IO.Path]::GetFullPath($combined) } catch { $null }
        if ($norm -and (Test-Path -LiteralPath $norm)) { continue }
        if ($relByLower.ContainsKey($t.ToLower() -replace '\\', '/')) { continue }
        $deadLinks.Add("$rel -> ($t)")
    }
}

if ($deadLinks.Count -gt 0) {
    $sample = ($deadLinks | Select-Object -First 10) -join ' | '
    Add-Check "WARN" $cat "$($deadLinks.Count) tote(r) Verweis(e) von $linkCount geprueften Links. Ziel umbenannt, versioniert oder geloescht - Verweis nachziehen oder entfernen, nicht stehen lassen. Erste Treffer: $sample"
} else {
    Add-Check "OK" $cat "Alle $linkCount Verweise (Wikilinks und Markdown-Links auf .md) loesen auf eine real existierende Datei auf."
}
# Verweise ohne Begruendung. AGENTS.md Abschnitt 5 verlangt zu jedem Wikilink einen
# Halbsatz, WARUM er da steht. Der Halbsatz ist der eigentliche Wert: Er sagt dem
# lesenden Modell, ob sich das Oeffnen lohnt. Ein Link ohne ihn ist eine Linie im
# Graphen und sonst nichts, und genau daraus besteht ein Wissensnetz, das sich selbst
# verknuepft. Geprueft wird nur der eindeutige Fall: eine Zeile, in der ausser dem
# Verweis so gut wie nichts steht.
# $fmExemptNames wird erst in Abschnitt 14 definiert; hier stand die Variable frueher
# vor ihrer Definition und die Ausnahme lief still ins Leere (Befund 30.08.2026 im
# Ursprungssystem, dort identisch behoben). Namensliste identisch zu Abschnitt 14 halten.
$linkExemptNames = @("AGENTS.md", "CLAUDE.md", "GEMINI.md", "_INDEX.md", "README.md")
$linksOhneGrund = @()
foreach ($f in $mdLinkSources) {
    $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
    if ($rel -notmatch '^\d\d_') { continue }
    if ($rel -match '^(00_INDEX|01_Basiskontext|02_Skills|03_Sessionlogs|04_Changelog|10_System|90_Inbox)/') { continue }
    if ($linkExemptNames -contains $f.Name) { continue }
    $zeilenNr = 0
    foreach ($line in (Get-Content -LiteralPath $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        $zeilenNr++
        if ($line -notmatch '\[\[') { continue }
        $rest = ([regex]::Replace($line, '\[\[[^\]]*\]\]', '')).Trim(" `t-*|>#[]()")
        if ($rest.Length -lt 25) { $linksOhneGrund += "$rel Z$zeilenNr" }
    }
}
if ($linksOhneGrund.Count -gt 0) {
    $sampleG = ($linksOhneGrund | Select-Object -First 10) -join ' | '
    Add-Check "WARN" $cat "$($linksOhneGrund.Count) Verweis(e) stehen ohne Begruendung in der Zeile. AGENTS.md Abschnitt 5 verlangt einen Halbsatz, warum der Verweis da ist; ohne ihn muss die naechste Session die Datei oeffnen, um das herauszufinden. Ergaenzen oder Verweis streichen. Treffer: $sampleG"
} else {
    Add-Check "OK" $cat "Jeder Verweis in einem Themenordner steht in einem Satz, der sagt, warum er da ist."
}
if ($ambiguousLinks.Count -gt 0) {
    $sampleA = ($ambiguousLinks | Select-Object -First 10) -join ' | '
    Add-Check "WARN" $cat "$($ambiguousLinks.Count) mehrdeutige(r) Verweis(e): das Ziel existiert unter diesem Namen mehrfach, die Aufloesung haengt vom Werkzeug ab. Mit Ordnerpfad qualifizieren ([[<Themenordner>/<Datei>]]) oder, bei Systemdateien, als Pfad in Backticks schreiben (AGENTS.md Abschnitt 5). Treffer: $sampleA"
} else {
    Add-Check "OK" $cat "Kein Verweis ueber einen mehrdeutigen Dateinamen: jeder Wikilink zeigt auf genau eine Datei."
}
Write-Output "Link-Check erledigt."
Write-Output ""


# ---------------------------------------------------------------------------
# 14) FRONTMATTER-STANDARD FUER NEUE DATEIEN
# ---------------------------------------------------------------------------
# Hintergrund: NEU angelegte Dateien sollen zuverlaessig und einheitlich Frontmatter
# tragen (Root-AGENTS.md Abschnitt 5). Geprueft werden nur Dateien, die laut Git AM
# oder NACH dem Stichtag unten erstmals hinzugefuegt wurden.
# Stichtag: In einem frisch aufgesetzten Repo gibt es keinen Altbestand, deshalb steht
# er hier auf 1970 und die Pflicht gilt fuer alles. Hast du spaeter Dateien ohne
# Frontmatter, die bewusst so bleiben sollen (Bestandsschutz), setzt du hier das Datum
# ein, ab dem die Regel greifen soll, z.B. ParseExact("2027-01-01", ...).
$cat = "Frontmatter"
$fmCutoff = [datetime]::ParseExact("1970-01-01", "yyyy-MM-dd", $null)
$fmRequired = @("titel", "zweck", "type")
$fmAllowedTypes = @("wissensnotiz", "rohquelle", "synthese", "arbeitsdokument",
                    "rollen-regeln", "themen-index", "readme", "basiskontext", "systemdoku",
                    "master-regeln")
# Ausgenommen: Dateiklassen mit eigenem, in sich einheitlichem Schema, das ein Skill
# fest vorgibt (Skills: name/trigger/zweck/type; Sessionlogs: date/time/topic/context/
# tags/type; Indexdateien: vom Generator erzeugt). Diese Regel hier gilt fuer
# Wissensdateien, nicht fuer generierte oder schablonierte Systemdateien, sonst wuerde
# der Check jeden neuen Sessionlog und jeden neuen Skill anmeckern, obwohl beide ihrem
# eigenen Standard exakt folgen.
$fmExemptPrefix = @("02_Skills/", "03_Sessionlogs/", "00_INDEX/", "04_Changelog/")
$fmExemptNames  = @("AGENTS.md", "CLAUDE.md", "GEMINI.md", "_INDEX.md", "README.md")
# Anlagedatum je Datei in EINEM git-Aufruf bestimmen (pro Datei waere es ~250 Aufrufe).
$addDates = @{}
$logOut = & git -C $repo log --diff-filter=A --date=format:%Y-%m-%d --format="D:%ad" --name-only -- "*.md" 2>$null
if ($LASTEXITCODE -eq 0) {
    $curDate = $null
    foreach ($line in @($logOut)) {
        $l = "$line".Trim()
        if ($l -match '^D:(\d{4}-\d{2}-\d{2})$') { $curDate = $matches[1]; continue }
        if ($l -eq "" -or -not $curDate) { continue }
        # git log laeuft von neu nach alt, das Ueberschreiben laesst am Ende den AELTESTEN
        # Add stehen. Genau der ist gewollt: das echte Anlagedatum, nicht ein spaeterer
        # Re-Add nach einer Umbenennung.
        $addDates[$l] = $curDate
    }
}
$fmIssues = @()
foreach ($f in $mdAll) {
    $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
    if (-not $addDates.ContainsKey($rel)) { continue }   # noch nie committet: erst nach dem Commit pruefbar
    $added = [datetime]::ParseExact($addDates[$rel], "yyyy-MM-dd", $null)
    if ($added -lt $fmCutoff) { continue }               # Bestandsschutz
    if ($fmExemptNames -contains $f.Name) { continue }
    $isExempt = $false
    foreach ($p in $fmExemptPrefix) { if ($rel.StartsWith($p)) { $isExempt = $true; break } }
    if ($isExempt) { continue }
    $head = Get-Content -Path $f.FullName -TotalCount 25 -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $head -or $head[0].Trim() -ne "---") {
        $fmIssues += "$rel (kein Frontmatter)"
        continue
    }
    $keys = @()
    $typeVal = $null
    for ($i = 1; $i -lt $head.Count; $i++) {
        if ($head[$i].Trim() -eq "---") { break }
        if ($head[$i] -match '^([a-zA-Z_]+):\s*(.*)$') {
            $keys += $matches[1]
            if ($matches[1] -eq "type") { $typeVal = $matches[2].Trim().Trim('"') }
        }
    }
    $missing = @($fmRequired | Where-Object { $keys -notcontains $_ })
    if ($missing.Count -gt 0) { $fmIssues += "$rel (fehlt: $($missing -join ', '))" }
    elseif ($typeVal -and ($fmAllowedTypes -notcontains $typeVal)) {
        $fmIssues += "$rel (type '$typeVal' nicht in der Liste aus AGENTS.md Abschnitt 5)"
    }
}
if ($fmIssues.Count -gt 0) {
    Add-Check "WARN" $cat "$($fmIssues.Count) Datei(en) erfuellen den Frontmatter-Standard nicht: $($fmIssues -join ' | ')"
} else {
    Add-Check "OK" $cat "Alle seit dem Stichtag angelegten Dateien tragen titel, zweck und einen zulaessigen type."
}
Write-Output "Frontmatter-Check erledigt."
Write-Output ""


# ---------------------------------------------------------------------------
# HERKUNFT (Provenienz)
# ---------------------------------------------------------------------------
# AGENTS.md Abschnitt 6 verlangt dreierlei: Quelle zitieren, eigene Schluesse im
# Satz markieren, `geprueft:` nur nach Bestaetigung. Ohne mechanische Gegenprobe
# haengt das allein an der Disziplin des schreibenden Modells, und genau dort
# faengt ein Wissenssystem unbemerkt an, Erfundenes wie Belegtes auszugeben.
# Was pruefbar ist, wird hier geprueft. Ob eine Aussage stimmt, kann kein Skript
# wissen; ob ihr Beleg ueberhaupt existiert und ob eine Datei ihren Status
# ausweist, sehr wohl.
$cat = "Herkunft"

# Das Belegarchiv liegt als Geschwisterordner "<Repo> Archiv" neben dem Repo
# (AGENTS.md Abschnitt 5). Fehlt es, bleibt $archivRoot leer und die
# Archivpruefung schaltet sich still ab.
$archivKandidat = Join-Path (Split-Path -Parent $repo) ((Split-Path -Leaf $repo) + " Archiv")
$archivRoot = if (Test-Path -LiteralPath $archivKandidat) { $archivKandidat.TrimEnd('\') } else { $null }

# --- a) Pfadverweise in Backticks, die ins Leere zeigen ---------------------
# Der Link-Check oben sieht nur Wikilinks und Markdown-Links. Verweise auf
# Systemdateien und auf Archivbelege stehen aber als Pfad in Backticks, und die
# waren bis hierhin voellig ungeprueft: die Stelle, an der ein Beleg plausibel
# benannt sein kann und trotzdem nirgendwohin zeigt.
$provIssues = @()
# Zustandsdateien, die erst zur Laufzeit entstehen (Zeitstempel des letzten Laufs),
# sind keine Belege: Im frischen Repo existieren sie noch nicht, und ein Skill, der
# sie erwaehnt, verweist auf ein Werkzeugergebnis, nicht auf eine Quelle.
$phPattern  = '[<>*?%]|\.\.\.|YYYY|^~|last-run\.txt$|^zustand-'
$cmdPattern = '^(git|pwsh|powershell|cd|python|schtasks|npm)\s|\s--\s'
# 90_Inbox ist ausgenommen: Rohquellen verlassen die Inbox nach dem Ingest, ihr
# Zitat in der Zieldatei bleibt bewusst stehen und ist die Herkunftsangabe selbst.
$provExemptTarget = '^90_Inbox[\\/]'
# Ein Satz, der das Anlegen einer Datei ankuendigt, verweist nicht auf sie.
# Seit 3.3 um Formen erweitert, die im Alltag dieselbe Ankuendigung tragen und vom
# urspruenglichen Muster nicht erfasst wurden: "der Agent entwirft X", "legt ... in X an",
# "Ergebnis: X" und der Absatzmarker "Naechster Zug:", unter dem in Agenda-Dokumenten der
# geplante naechste Schritt steht. Der Umlaut steht als Punkt-Platzhalter, damit das
# Muster unabhaengig von der Kodierung der Quelldatei greift.
$planPattern = '(?i)(anlegen|anzulegen|neue Datei|wird erzeugt|entsteht|erstellen|festhalten|Ergebnis als|Ergebnis:|entwirft|entwerfen|legt .{0,60} an\b|N.chster Zug|geplant|soll .{0,30}(entstehen|stehen)|gibt es nicht|existiert nicht|nicht vorhanden|fehlt noch|noch nicht angelegt|wurde nie)'
$topLevel = @(Get-ChildItem -Path $repo -Directory | Where-Object { $_.Name -notmatch '^\.' } | ForEach-Object { $_.Name.ToLower() })
$allBaseNames = @{}
foreach ($x in (Get-ChildItem -Path $repo -Recurse -File | Where-Object { $_.FullName -notmatch $excludedDirPattern })) {
    $allBaseNames[$x.Name.ToLower()] = $true
}
foreach ($f in $mdAll) {
    $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
    if ($rel -match '^(03_Sessionlogs|04_Changelog)/') { continue }   # Append-only, alte Pfade sind dort Historie
    $raw = Get-Content -Path $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $raw) { continue }
    $noFence = [regex]::Replace($raw, '(?s)```.*?```', '')
    foreach ($m in [regex]::Matches($noFence, '`([^`\r\n]+)`')) {
        $t = $m.Groups[1].Value.Trim()
        if ($t -notmatch '[\\/]') { continue }
        # Archivbelege tragen jede erdenkliche Endung: PDF, Scan, Docx, Mailexport.
        # Die Endungsliste haelt nur bei Repo-Verweisen das Rauschen fern (Fliesstext
        # mit Schraegstrich). Ein Archivpfad wird immer geprueft, egal worauf er endet:
        # Sonst laeuft die Belegpruefung leer und meldet trotzdem gruen.
        $istArchivPfad = $archivRoot -and ($t -replace '\\','/').ToLower().StartsWith((($archivRoot -replace '\\','/') + '/').ToLower())
        if (-not $istArchivPfad -and $t -notmatch '\.(md|ps1|txt|json)$') { continue }
        if ($t -match $phPattern -or $t -match $cmdPattern) { continue }
        $p = $t -replace '\\', '/'
        if ($p -match '^[A-Za-z]:') {
            if ($istArchivPfad) {
                if (Test-Path -LiteralPath ($p -replace '/', '\')) { continue }
                $provIssues += "$rel -> $t (Beleg fehlt im Archiv)"
                continue
            }
            $repoSlash = ($repo -replace '\\','/') + '/'
            if ($p.ToLower().StartsWith($repoSlash.ToLower())) { $p = $p.Substring($repoSlash.Length) } else { continue }
        }
        if ($p -match $provExemptTarget) { continue }
        $firstSeg = ($p -split '/')[0].ToLower()
        $baseName = (Split-Path $p -Leaf).ToLower()
        if (($topLevel -notcontains $firstSeg) -and (-not $allBaseNames.ContainsKey($baseName))) { continue }
        $abs    = Join-Path $repo ($p -replace '/', '\')
        $absRel = Join-Path (Split-Path $f.FullName -Parent) ($p -replace '/', '\')
        if ((Test-Path -LiteralPath $abs) -or (Test-Path -LiteralPath $absRel)) { continue }
        # Umbenanntes System: leo-x.md im Text, w1-x.md auf der Platte (siehe Test-RepoPfad)
        if (Test-RepoPfad $p) { continue }
        # Fenster seit 3.3 von 120 auf 200 Zeichen vor dem Treffer erweitert: Der
        # Ankuendigungsmarker steht am Satzanfang ("Naechster Zug: ..."), und ein Satz ist
        # regelmaessig laenger als 120 Zeichen; mit dem alten Fenster fiel derselbe Satz je
        # nach Laenge mal durch und mal nicht.
        $ctxStart = [Math]::Max(0, $m.Index - 200)
        $ctx = $noFence.Substring($ctxStart, [Math]::Min(400, $noFence.Length - $ctxStart))
        if ($ctx -match $planPattern) { continue }
        $provIssues += "$rel -> $t"
    }
}
if ($provIssues.Count -gt 0) {
    $provIssues = $provIssues | Select-Object -Unique
    $sampleP = ($provIssues | Select-Object -First 12) -join ' | '
    Add-Check "WARN" $cat "$($provIssues.Count) Pfadverweis(e) in Backticks zeigen auf eine Datei, die es nicht gibt. Ein benannter Beleg, den niemand oeffnen kann, ist keine Quelle: Pfad korrigieren, Verweis entfernen oder als geplant kennzeichnen. Treffer: $sampleP"
} else {
    Add-Check "OK" $cat "Alle Pfadverweise in Backticks zeigen auf real existierende Dateien (Platzhalter, Kommandos, 90_Inbox-Zitate und fremde Systeme ausgenommen)."
}

# --- b) Herkunft jeder Wissensdatei: bestaetigt, aus einer Quelle, oder Vorschlag ---
# Fehlt `geprueft:`, ist der Inhalt laut Abschnitt 6 ein Vorschlag. Diese Regel ist
# beim Lesen aber unsichtbar: Ein Modell in einer Session sieht das Anlagedatum
# einer Datei nicht und liest eine unbestaetigte Synthese wie Beschlusslage.
# Deshalb muss die Herkunft IN der Datei stehen, an einer festen Stelle.
# Rohquellen sind ausgenommen: Eine unveraenderte Quelle ist der Beleg selbst.
#
# WARUM EIN FELD UND NICHT EIN WORT IM TEXT. Frueher genuegte ein Wortfund irgendwo
# im Dateiinhalt. Zwei Fehler daran, beide von einem Nutzer dieses Grundgeruests
# gemeldet, dessen Inhalt ueberwiegend englisch ist:
#   1. Sprachbindung. Die Wortliste war deutsch. In einem englischsprachigen Repo
#      liess sich der Ausweis nur erbringen, indem ein deutscher Satz in einer
#      englischen Datei steht. Er sieht dort aus wie ein Versehen und wird geloescht.
#   2. Der schwerere Fehler: Der Anker war der gesamte Dateiinhalt. Ein zufaelliges
#      Vorkommen genuegte, etwa "Vorschlag" in einem Angebot oder "Entwurf" in einer
#      Beschreibung. In einem gewachsenen Repo bestand so mehr als die Haelfte der
#      betroffenen Dateien, ohne ueber sich selbst irgendetwas zu sagen.
# Eine Datei, die faelschlich als ausgewiesen durchgeht, ist schlechter als keine
# Pruefung: Sie erzeugt Vertrauen, das nichts traegt. Der Anker ist deshalb ein
# Frontmatter-Feld mit geschlossenem Vokabular und deutschen wie englischen Werten.
#
# Das Feld heisst bewusst `herkunft:` und nicht `status:`. `**Status:**` bezeichnet im
# Fliesstext nach Abschnitt 7 den Arbeitszustand eines Blocks (offen, laufend,
# blockiert, erledigt). Dieselbe Vokabel zweimal mit zwei Bedeutungen zu belegen ist
# der Weg, auf dem solche Konventionen zerfallen.
#   vorschlag / proposal: vom LLM abgeleitet, nicht bestaetigt.
#   quelle / source:      unmittelbar aus einer benannten Quelle oder aus den eigenen
#                         Angaben des Nutzers, keine Ableitung, aber nicht bestaetigt.
$herkunftFeld = '(?im)^herkunft:\s*(vorschlag|proposal|quelle|source)\s*$'
$unklarStatus = @()
foreach ($f in $mdAll) {
    $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
    if ($rel -notmatch '^\d\d_') { continue }
    if ($rel -match '^(00_INDEX|01_Basiskontext|02_Skills|03_Sessionlogs|04_Changelog|10_System|90_Inbox)/') { continue }
    if ($fmExemptNames -contains $f.Name) { continue }
    $raw = Get-Content -Path $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $raw) { continue }
    # Nur der Frontmatter-Block zaehlt, nicht die ganze Datei. Genau die fehlende
    # Eingrenzung war der Fehler oben: Wer im Fliesstext sucht, findet frueher oder
    # spaeter irgendwo etwas. Hat eine Datei kein Frontmatter, bleibt $fm leer und
    # sie wird zu Recht gemeldet.
    $fm = ''
    if ($raw -match '(?s)^\uFEFF?---\r?\n(.*?)\r?\n---\r?\n') { $fm = $matches[1] }
    if ($fm -match '(?m)^type:\s*rohquelle\s*$') { continue }
    if ($fm -match '(?m)^geprueft:\s*\S') { continue }
    if ($fm -match $herkunftFeld) { continue }
    $unklarStatus += $rel
}
if ($unklarStatus.Count -gt 0) {
    $sampleS = ($unklarStatus | Select-Object -First 10) -join ' | '
    Add-Check "WARN" $cat "$($unklarStatus.Count) Wissensdatei(en) weisen ihre Herkunft nicht aus: weder 'geprueft:' noch 'herkunft:' im Frontmatter. Ohne Bestaetigung sind sie Vorschlag, gelesen werden sie als Beschlusslage. Setzen: 'geprueft: <Kuerzel> <datum>' nach der Bestaetigung, sonst 'herkunft: vorschlag' (vom LLM abgeleitet) oder 'herkunft: quelle' (unmittelbar aus einer benannten Quelle oder aus deinen eigenen Angaben). Englische Werte proposal und source sind gleichwertig. Treffer: $sampleS"
} else {
    Add-Check "OK" $cat "Jede Wissensdatei weist ihre Herkunft im Frontmatter aus: geprueft: (bestaetigt) oder herkunft: (vorschlag beziehungsweise quelle)."
}
# --- Belegketten: endet jede Kette bei einer echten Quelle? --------------------
# Wenn eine Notiz als Quelle eine ANDERE Notiz nennt, ist ihr Beleg selbst ein
# Erzeugnis. Das ist erlaubt und oft richtig, aber nur, solange die Kette irgendwo
# bei etwas endet, das nicht aus diesem System stammt: einer Rohquelle, einem
# Archivbeleg, einer benannten externen Quelle. Endet sie nicht, ist der Beleg ein
# Selbstverweis, und so entsteht Wissen, das auf Wissen steht, das niemand geprueft
# hat. Gemeldet werden Zyklus (A belegt B, B belegt A) und Sackgasse (die zitierte
# Notiz nennt selbst keine Quelle). Die blosse Tiefe wird NICHT gemeldet.
$quellZeile = '(?im)^\s*(\*\*)?(Quelle|Quellen|Beleg|Belege|Grundlage)(n)?(\*\*)?\s*:'
$fmCache = @{}
function Get-FrontmatterType([string]$pfad) {
    if ($fmCache.ContainsKey($pfad)) { return $fmCache[$pfad] }
    $typ = ""
    $roh = Get-Content -LiteralPath $pfad -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($roh -and $roh -match '(?s)^\uFEFF?---\r?\n(.*?)\r?\n---\r?\n') {
        if ($matches[1] -match '(?m)^type:\s*(\S+)') { $typ = $matches[1] }
    }
    $fmCache[$pfad] = $typ
    return $typ
}
function Get-Belege([string]$relPfad) {
    $voll = Join-Path $repo ($relPfad -replace '/', '\')
    $roh = Get-Content -LiteralPath $voll -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $roh) { return @{ intern = @(); extern = $false; hatQuelle = $false } }
    $intern = New-Object System.Collections.Generic.List[string]
    $extern = $false; $hatQuelle = $false
    foreach ($line in ($roh -split "`r?`n")) {
        if ($line -notmatch $quellZeile) { continue }
        $hatQuelle = $true
        $ziele = @()
        foreach ($m in [regex]::Matches($line, '\[\[([^\]]+)\]\]')) { $ziele += (($m.Groups[1].Value -split '\|')[0] -split '#')[0].Trim() }
        foreach ($m in [regex]::Matches($line, '\]\(([^)]+\.md)\)')) { $ziele += [uri]::UnescapeDataString(($m.Groups[1].Value -split '#')[0]) }
        foreach ($z in $ziele) {
            $probe = ($z + '.md') -replace '\\', '/'
            if ($z -match '\.md$') { $probe = $z -replace '\\', '/' }
            $treffer = $null
            if ($relByLower.ContainsKey($probe.ToLower())) { $treffer = $relByLower[$probe.ToLower()] }
            else {
                $bn = (Split-Path $probe -Leaf).ToLower()
                if ($byBase.ContainsKey($bn) -and $byBase[$bn].Count -eq 1) { $treffer = $byBase[$bn][0] }
                else {
                    $dir = (Split-Path $relPfad -Parent) -replace '\\', '/'
                    if ($dir -and $relByLower.ContainsKey("$dir/$probe".ToLower())) { $treffer = $relByLower["$dir/$probe".ToLower()] }
                }
            }
            if ($treffer) { $intern.Add($treffer) } else { $extern = $true }
        }
        $rest = [regex]::Replace($line, '\[\[[^\]]+\]\]', '')
        $rest = [regex]::Replace($rest, '\[[^\]]*\]\([^)]+\)', '')
        $rest = ($rest -replace $quellZeile, '').Trim(' .,;:*-')
        if ($rest.Length -ge 15) { $extern = $true }
    }
    return @{ intern = @($intern); extern = $extern; hatQuelle = $hatQuelle }
}
$belegCache = @{}
function Resolve-Beleg([string]$rel) {
    if (-not $belegCache.ContainsKey($rel)) { $belegCache[$rel] = Get-Belege $rel }
    return $belegCache[$rel]
}
$kettenBefunde = @(); $kettenGeprueft = 0
foreach ($f in $mdAll) {
    $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
    if ($rel -notmatch '^\d\d_') { continue }
    if ($rel -match '^(00_INDEX|01_Basiskontext|02_Skills|03_Sessionlogs|04_Changelog|10_System|90_Inbox)/') { continue }
    if ($fmExemptNames -contains $f.Name) { continue }
    $start = Resolve-Beleg $rel
    if (-not $start.hatQuelle -or $start.intern.Count -eq 0) { continue }
    if ($start.extern) { continue }
    $kettenGeprueft++
    $pfadListe = New-Object System.Collections.Generic.List[string]
    $pfadListe.Add($rel)
    $aktuell = $start; $tiefe = 0; $ergebnis = $null
    while ($tiefe -lt 6) {
        $tiefe++
        $naechste = @($aktuell.intern)[0]
        if (-not $naechste) { $ergebnis = "Sackgasse"; break }
        if ($pfadListe -contains $naechste) { $pfadListe.Add($naechste); $ergebnis = "Zyklus"; break }
        $pfadListe.Add($naechste)
        if ((Get-FrontmatterType (Join-Path $repo ($naechste -replace '/', '\'))) -eq 'rohquelle') { $ergebnis = "ok"; break }
        $aktuell = Resolve-Beleg $naechste
        if ($aktuell.extern) { $ergebnis = "ok"; break }
        if (-not $aktuell.hatQuelle -or $aktuell.intern.Count -eq 0) { $ergebnis = "Sackgasse"; break }
    }
    if (-not $ergebnis) { $ergebnis = "zu tief" }
    if ($ergebnis -ne "ok") { $kettenBefunde += "$ergebnis`: " + ($pfadListe -join ' -> ') }
}
if ($kettenBefunde.Count -gt 0) {
    $sampleK = ($kettenBefunde | Select-Object -First 8) -join ' | '
    Add-Check "WARN" $cat "$($kettenBefunde.Count) Belegkette(n) enden nicht bei einer echten Quelle. Ein Zyklus heisst, zwei Notizen belegen sich gegenseitig; eine Sackgasse heisst, die zitierte Notiz nennt selbst keine Quelle. In beiden Faellen steht Wissen auf Wissen. Beheben, indem die urspruengliche Quelle in der Zeile genannt wird (Absender und Datum, Archivpfad oder URL). Treffer: $sampleK"
} else {
    Add-Check "OK" $cat "Alle $kettenGeprueft rein internen Belegketten enden bei einer Rohquelle oder einer benannten externen Angabe: kein Zyklus, keine Sackgasse."
}
Write-Output "Herkunfts-Check erledigt."
Write-Output ""


# ---------------------------------------------------------------------------
# FORMATDISZIPLIN (das Repo ist Gedaechtnis, kein Archiv)
# ---------------------------------------------------------------------------
# AGENTS.md Abschnitt 5: Themenordner tragen kuratiertes Wissen als Markdown.
# PDFs, Scans, Exportformate und erzeugte Ausgabeformate gehoeren in die
# Geschwisterordner "<Repo> Archiv" bzw. "<Repo> Artifacts". Ohne Pruefung
# sickert das ueber Backups und Handablagen ein und macht das Repo still zum
# Archiv: Binaerdateien blaehen Git auf, und die Suche kann Wissen nicht mehr
# von Rohmaterial unterscheiden.
$cat = "Formatdisziplin"
$fremdformate = Get-ChildItem -Path $repo -Recurse -File |
    Where-Object {
        $_.FullName -notmatch $excludedDirPattern -and
        $_.Extension -ne ".md" -and
        # Zustandsdateien der Skripte sind Mechanik, kein Archivgut.
        $_.Name -notlike "*last-run.txt" -and
        $_.Name -notlike "zustand-*.json" -and
        (($_.FullName.Substring($repo.Length + 1) -replace '\\', '/') -match '^\d\d_') -and
        (($_.FullName.Substring($repo.Length + 1) -replace '\\', '/') -notmatch '^(00_INDEX|01_Basiskontext|02_Skills|03_Sessionlogs|04_Changelog|10_System)/')
    }
if ($fremdformate.Count -gt 0) {
    $liste = ($fremdformate | ForEach-Object { $_.FullName.Substring($repo.Length + 1) -replace '\\', '/' }) -join ' | '
    Add-Check "WARN" $cat "$($fremdformate.Count) Nicht-Markdown-Datei(en) in Themenordnern. Inhalt als Wissensnotiz uebernehmen, Datei ins Archiv bzw. nach Artifacts verschieben oder loeschen - aber erst nach Ruecksprache (Abschnitt 12). Treffer: $liste"
} else {
    Add-Check "OK" $cat "Themenordner enthalten ausschliesslich Markdown: kein Rohformat, kein erzeugtes Ausgabeformat, kein Archivgut."
}
Write-Output "Formatdisziplin-Check erledigt."
Write-Output ""

# ---------------------------------------------------------------------------
# SYSTEMDOKU: T-/E-Kennungen muessen eindeutig sein
# ---------------------------------------------------------------------------
# Arbeiten zwei Sessions parallel, koennen beide dieselbe naechste Nummer
# vergeben (T23 und T23). Ab dann zeigt jeder Querverweis auf zwei verschiedene
# Eintraege, und kein Leser merkt es. Die Pruefung liest nur Ueberschriften und
# kostet praktisch nichts. Fehlt eine der Dateien, wird sie uebersprungen.
$cat = "Systemdoku"
$kennungsDateien = @(
    @{ Pfad = "10_System\Technik.md";        Muster = '^##\s+(T\d+)\b' },
    @{ Pfad = "10_System\Entscheidungen.md"; Muster = '^##\s+(E\d+)\b' }
)
foreach ($kd in $kennungsDateien) {
    $kdVoll = Join-Path $repo $kd.Pfad
    if (-not (Test-Path -LiteralPath $kdVoll)) { continue }
    $kdTreffer = @(Select-String -LiteralPath $kdVoll -Pattern $kd.Muster | ForEach-Object { $_.Matches[0].Groups[1].Value })
    $kdDoppelt = @($kdTreffer | Group-Object | Where-Object { $_.Count -gt 1 })
    if ($kdDoppelt.Count -gt 0) {
        Add-Check "WARN" $cat "$($kd.Pfad): Kennung(en) mehrfach vergeben: $(($kdDoppelt | ForEach-Object { $_.Name }) -join ', '). Vermutlich haben parallele Sessions dieselbe Nummer benutzt. Den juengeren Eintrag auf die naechste freie Nummer heben und die Querverweise nachziehen."
    } else {
        Add-Check "OK" $cat "$($kd.Pfad): alle $($kdTreffer.Count) Kennungen eindeutig."
    }
}
Write-Output "Systemdoku-Check erledigt."
Write-Output ""


# ---------------------------------------------------------------------------
# FRONTMATTER-WERTE: Umlautersatz in titel:/zweck:
# ---------------------------------------------------------------------------
# Die Umlaut-Regel (AGENTS.md, Kopf) gilt auch fuer Frontmatter-WERTE; nur die
# Schluessel sind ASCII. Beobachtung aus der Praxis: Modelle schreiben "Haelt"
# oder "fuer" in zweck:-Werte, obwohl der Fliesstext korrekt ist, vermutlich
# weil die ASCII-Schluessel daneben stehen; Textregeln allein haben das nicht
# verhindert, deshalb dieses mechanische Netz. Die Heuristik ist eine Liste
# eindeutiger deutscher Ersatzmuster; bewusst keine generische ae/oe/ue-Suche,
# weil korrekte Woerter wie "Quelle", "Steuer" oder "Dauer" sonst anschlagen.
# SPRACHHINWEIS: Arbeitet dein Repo nicht auf Deutsch, die Liste leeren oder
# durch eigene Muster ersetzen; ein leeres $umlautTells schaltet den Check ab.
$cat = "Frontmatter"
$fmWertCutoffTag = "2026-08-29"   # Bestandsschutz: nur Dateien ab diesem Anlagedatum pruefen
$umlautTells = '(?i)\b(fuer|ueber\w*|haelt|traegt|laeuft|laesst|enthaelt|erklaert|gehoert|noetig|moeglich\w*|spaeter\w*|waehrend|taeglich\w*|woechentlich\w*|zustaendig\w*|rueck\w*|pruef\w*|uebersicht\w*|schluessel\w*|verfuegbar\w*|regelmaessig\w*|zusaetzlich\w*|vollstaendig\w*|grundsaetzlich\w*|ausfuehr\w*|einfuehr\w*|durchfuehr\w*|aenderung\w*|qualitaet\w*|aktivitaet\w*)\b'
if ($umlautTells) {
    $fmWertCutoff = [datetime]::ParseExact($fmWertCutoffTag, "yyyy-MM-dd", $null)
    $fmWertBefunde = New-Object System.Collections.Generic.List[string]
    foreach ($f in $mdAll) {
        $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
        if ($fmExemptNames -contains $f.Name) { continue }
        $skipPrefix = $false
        foreach ($p in $fmExemptPrefix) { if ($rel.StartsWith($p)) { $skipPrefix = $true; break } }
        if ($skipPrefix) { continue }
        $addDatum = $addDates[$rel]
        if (-not $addDatum -or ([datetime]::ParseExact($addDatum, "yyyy-MM-dd", $null) -lt $fmWertCutoff)) { continue }
        $kopf = Get-Content -Path $f.FullName -TotalCount 12 -Encoding UTF8
        foreach ($zeile in $kopf) {
            if ($zeile -match '^(titel|zweck):\s*(.+)$') {
                if ($Matches[2] -match $umlautTells) { $fmWertBefunde.Add("$rel ($($Matches[1]):)") }
            }
        }
    }
    if ($fmWertBefunde.Count -gt 0) {
        $sampleFW = ($fmWertBefunde | Select-Object -First 8) -join ' | '
        Add-Check "WARN" $cat "$($fmWertBefunde.Count) seit $fmWertCutoffTag angelegte Datei(en) mit Umlautersatz (ae/oe/ue) in titel:- oder zweck:-Werten. Die Umlaut-Regel gilt auch fuer Frontmatter-Werte, nur die Schluessel sind ASCII (AGENTS.md, Kopf). Werte korrigieren. Treffer: $sampleFW"
    } else {
        Add-Check "OK" $cat "Keine Umlautersatz-Muster in titel:/zweck:-Werten neu angelegter Dateien (Bestand vor $fmWertCutoffTag ist ausgenommen)."
    }
    Write-Output "Frontmatter-Werte-Check erledigt."
    Write-Output ""
}

# ---------------------------------------------------------------------------
# FRONTMATTER-WERTE: unzitierter Doppelpunkt mit Leerzeichen
# ---------------------------------------------------------------------------
# Ein unzitierter Wert mit "Doppelpunkt plus Leerzeichen" (oder Doppelpunkt am
# Zeilenende) macht den YAML-Block ungueltig, und der Fehler ist im Editor fast
# unsichtbar. Zitierte Werte ("titel: \"X: Y\""), Zeiten (17:10), 1:1 und URLs
# sind gueltig und schlagen nicht an. Im Ursprungssystem am 30.08.2026 am
# Gesamtbestand kalibriert: 0 Fehltreffer ueber alle Werte mit Doppelpunkt.
$cat = "Frontmatter"
$fmDoppelpunkt = @()
foreach ($f in $mdAll) {
    $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
    $kopf = Get-Content -Path $f.FullName -TotalCount 25 -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $kopf -or $kopf[0].Trim() -ne '---') { continue }
    for ($i = 1; $i -lt $kopf.Count; $i++) {
        if ($kopf[$i].Trim() -eq '---') { break }
        if ($kopf[$i] -match '^([a-zA-Z_-]+):\s+(.*)$') {
            $fmSchluessel = $Matches[1]
            $wert = $Matches[2].Trim()
            if ($wert -match '^["'']') { continue }
            if ($wert -match ':(\s|$)') { $fmDoppelpunkt += "$rel (${fmSchluessel}:)" }
        }
    }
}
if ($fmDoppelpunkt.Count -gt 0) {
    $sampleDP = ($fmDoppelpunkt | Select-Object -First 8) -join ' | '
    Add-Check "WARN" $cat "$($fmDoppelpunkt.Count) Datei(en) mit unzitiertem Doppelpunkt in einem Frontmatter-Wert; der Block ist damit ungueltiges YAML. Wert umformulieren (Doppelpunkt raus) oder in Anfuehrungszeichen setzen. Treffer: $sampleDP"
} else {
    Add-Check "OK" $cat "Kein Frontmatter-Wert bricht seinen Block durch einen unzitierten Doppelpunkt (Zeiten, 1:1 und URLs ohne Leerzeichen danach sind gueltig und ausgenommen)."
}
Write-Output "Doppelpunkt-Check erledigt."
Write-Output ""

# ---------------------------------------------------------------------------
# EIGENE SKILLS OHNE EINTRAG IN MEIN-SYSTEM.md (Abschnitt 3)
# ---------------------------------------------------------------------------
# MEIN-SYSTEM.md Abschnitt 3 ist die Liste, die der Update-Skill liest, um eigene
# Bauten zu schonen. Sie veraltet still (Befund aus einem Nutzersystem, 30.08.2026). Mechanisch
# pruefbar ist der Skill-Teil: Jede Skill-Datei, die nicht zum Kern gehoert und
# in MEIN-SYSTEM.md nirgends genannt wird, fehlt dort. Die Kernliste wird aus
# 10_System\Kern-Dateien.md gelesen (eine Wahrheit, keine Kopie); die statische
# Liste darunter ist nur der Rueckfall, falls die Datei fehlt.
$cat = "Mein-System"
$kernSkills = @('leo-mechanik-update.md','leo-skill-ersteller.md','leo-system-health-check.md',
                'leo-system-optimierung.md','leo-themenordner-anlegen.md','leo-wrap-up.md')
$kernDateienPfad = Join-Path $repo "10_System\Kern-Dateien.md"
if (Test-Path -LiteralPath $kernDateienPfad) {
    $ausListe = @(Select-String -LiteralPath $kernDateienPfad -Pattern '02_Skills\\(leo-[\w-]+\.md)' -AllMatches |
        ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    if ($ausListe.Count -gt 0) { $kernSkills = $ausListe }
}
$meinSystemPfad = Join-Path $repo "MEIN-SYSTEM.md"
if (Test-Path -LiteralPath $meinSystemPfad) {
    $msText = Get-Content -LiteralPath $meinSystemPfad -Raw -Encoding UTF8

    # Praefix-Aufloesung (seit 2.4): Die Kernliste nennt die Skills mit dem Praefix des
    # Grundgeruests (leo-). Wer sein System umbenannt hat, hat lokal andere Dateinamen.
    # Ohne diese Aufloesung gelten bei ihm ALLE Kern-Skills als eigene Bauten, und die
    # Meldung unten warnt dauerhaft vor Dateien, die gar nicht ihm gehoeren; die eine
    # echte Warnung geht darin unter. Gemessen in einem Trockenlauf am 31.08.2026:
    # 11 gemeldete "eigene" Skills, von denen genau einer wirklich eigen war.
    $praefix = 'leo-'
    if ($msText -match '(?m)^\|\s*Skill-Pr[äa]fix\s*\|[^|]*\|\s*`?([a-z0-9]+-)`?\s*\|') { $praefix = $Matches[1] }
    if ($praefix -ne 'leo-') {
        $kernSkills = @($kernSkills | ForEach-Object { $_ -replace '^leo-', $praefix })
    }

    $eigeneOhneEintrag = @(Get-ChildItem (Join-Path $repo "02_Skills") -Filter "*.md" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin (@("README.md","Skill-Register.md") + $kernSkills) } |
        Where-Object { -not $msText.Contains($_.Name) } |
        ForEach-Object { $_.Name })
    if ($eigeneOhneEintrag.Count -gt 0) {
        Add-Check "WARN" $cat "$($eigeneOhneEintrag.Count) eigene Skill-Datei(en) ohne Eintrag in MEIN-SYSTEM.md Abschnitt 3: $($eigeneOhneEintrag -join ', '). Ohne den Eintrag muss der Update-Skill raten, was dir gehoert."
    } else {
        Add-Check "OK" $cat "Jeder eigene Skill (ausserhalb des Kerns) ist in MEIN-SYSTEM.md genannt."
    }

    # Versions-Rueckstand (Befund aus einem Nutzersystem, 30.08.2026): Wer nie ein Trigger-Wort sagt,
    # zieht nie ein Update und erfaehrt es nicht; sechs Versionen Rueckstand nach
    # fuenf Tagen, darunter ein Bug, der die halbe Personalisierung lahmlegte. Die
    # billigste Pruefung im ganzen Check: eingespielte Version (Abschnitt 4) gegen
    # den hoechsten Tag im Grundgeruest-Repo. Kein Netz oder kein Git: nur INFO.
    $quelleRepo = "https://github.com/flomeile/leo-core"
    $eingespielt = $null
    if ($msText -match '(?m)^\|\s*Eingespielte Version\s*\|\s*([0-9]+\.[0-9]+)\s*\|') { $eingespielt = $Matches[1] }
    if ($eingespielt) {
        $tagsRaw = & git ls-remote --tags $quelleRepo 2>$null
        if ($LASTEXITCODE -eq 0 -and $tagsRaw) {
            $neueste = @($tagsRaw | ForEach-Object { if ($_ -match 'refs/tags/v([0-9]+\.[0-9]+)$') { [version]$Matches[1] } }) |
                Sort-Object | Select-Object -Last 1
            if ($neueste -and ([version]$eingespielt -lt $neueste)) {
                Add-Check "WARN" $cat "Grundgeruest-Rueckstand: eingespielt ist $eingespielt, verfuegbar ist $neueste. Update ansteht: Trigger 'mechanik update' (Skill leo-mechanik-update). Steht in Abschnitt 4 von MEIN-SYSTEM.md noch der Auslieferungswert, dort zuerst die real eingespielte Version eintragen."
            } elseif ($neueste) {
                Add-Check "OK" $cat "Grundgeruest aktuell: Version $eingespielt entspricht dem neuesten Stand ($neueste)."
            }
        } else {
            Add-Check "INFO" $cat "Grundgeruest-Version nicht pruefbar (kein Netz oder git ls-remote fehlgeschlagen). Kein Befund."
        }
    } else {
        Add-Check "INFO" $cat "In MEIN-SYSTEM.md Abschnitt 4 ist keine eingespielte Version lesbar (Muster '| Eingespielte Version | X.Y |'). Beim Einrichten eintragen, sonst kann niemand Rueckstand erkennen."
    }

    # Kern-Datei-Abweichungen (seit 3.0): Wer eine Kern-Datei direkt bearbeitet, verliert die
    # Aenderung beim naechsten Update oder blockiert es. Bisher fiel das erst beim Update auf.
    # Hier laufend: jede Datei der Kategorie A gegen die Fassung der eingespielten Version
    # (Tag v<eingespielt> aus dem Remote upstream) vergleichen. Abweichungen, die nicht in
    # MEIN-SYSTEM.md Abschnitt 3 stehen, sind ein WARN. Fehlt der Remote oder der Tag, sagt
    # der Check das ausdruecklich: Ein Waechter, der stillschweigend nichts prueft, ist
    # schlimmer als keiner (Anlass: ein Nutzersystem, das als Kopie ohne jede Verbindung
    # zum Kern fuenf Wochen lang von keinem Update erreicht wurde).
    $upstreamUrl = & git -C $repo remote get-url upstream 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $upstreamUrl) {
        Add-Check "INFO" $cat "Kein Remote 'upstream' auf das Core-Repo. Kern-Datei-Abweichungen sind damit NICHT pruefbar, und ein Update kann nicht gezogen werden. Anbindung (einmalig): git remote add upstream $quelleRepo.git ; git remote set-url --push upstream DISABLED"
    } elseif ($eingespielt) {
        if ($upstreamUrl -match 'github\.com[/:]flomeile/leo-starter') {
            Add-Check "WARN" $cat "Remote 'upstream' zeigt noch auf die alte Adresse ($upstreamUrl). Umsetzen: git remote set-url upstream $quelleRepo.git ; die Umleitung von GitHub bricht, sobald jemand den alten Namen neu belegt."
        }
        $tag = "v$eingespielt"
        $null = & git -C $repo rev-parse --verify --quiet "$tag^{commit}" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Add-Check "INFO" $cat "Tag $tag der eingespielten Version liegt lokal nicht vor (git fetch upstream --tags nachholen). Kern-Datei-Abweichungen in diesem Lauf nicht pruefbar."
        } else {
            $kernA = @()
            if (Test-Path -LiteralPath $kernDateienPfad) {
                $inA = $false
                foreach ($zeile in (Get-Content -LiteralPath $kernDateienPfad -Encoding UTF8)) {
                    if ($zeile -match '^## A\.') { $inA = $true; continue }
                    if ($zeile -match '^## B\.') { break }
                    if ($inA -and $zeile -match '^\|\s*`([^`]+)`\s*\|') { $kernA += $Matches[1] }
                }
            }
            $abweichend = @()
            foreach ($k in $kernA) {
                $relTag = $k -replace '\\','/'
                $rel = $relTag
                if ($praefix -ne 'leo-') { $rel = $rel -replace '/leo-', "/$praefix" }
                $lokal = Join-Path $repo $rel
                if (-not (Test-Path -LiteralPath $lokal)) { continue }
                $weicht = $false
                if ($rel -eq $relTag) {
                    & git -C $repo diff --quiet $tag -- $rel 2>$null
                    if ($LASTEXITCODE -eq 1) { $weicht = $true }
                } else {
                    # Umbenannter Skill (eigenes Praefix): Der lokale Pfad existiert im Tag nicht,
                    # git diff meldet dann immer "anders". Deshalb Inhalt gegen die Tag-Fassung
                    # unter dem Grundgeruest-Namen vergleichen, Zeilenenden normalisiert
                    # (kalt gemessen am 03.09.2026: ohne das galten alle zehn Kern-Skills eines
                    # umbenannten Systems als abweichend, obwohl sie identisch waren).
                    # Die Ausgabe von git wird mit [Console]::OutputEncoding gelesen, und die steht
                    # unter Windows oft auf einer OEM-Codepage (ibm850). Jeder Umlaut im Skill kommt
                    # dann verstuemmelt an, der Vergleich meldet alle Kern-Skills als abweichend,
                    # obwohl sie byteidentisch sind (kalt gemessen am 13.09.2026: 9 von 9 falsch).
                    # Deshalb fuer diesen einen Aufruf auf UTF-8 umschalten und danach zuruecksetzen.
                    $prevEnc = [Console]::OutputEncoding
                    try {
                        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
                        $tagInhalt = (& git -C $repo show "${tag}:${relTag}" 2>$null) -join "`n"
                    } finally { [Console]::OutputEncoding = $prevEnc }
                    if ($LASTEXITCODE -eq 0) {
                        $lokalInhalt = ([System.IO.File]::ReadAllText($lokal)) -replace "`r`n","`n"
                        $tagInhalt = ($tagInhalt -replace "`r`n","`n").TrimEnd("`n")
                        if ($lokalInhalt.TrimEnd("`n") -ne $tagInhalt) { $weicht = $true }
                    }
                }
                if ($weicht) {
                    $name = Split-Path $rel -Leaf
                    if (-not $msText.Contains($name)) { $abweichend += $rel }
                }
            }
            if ($abweichend.Count -gt 0) {
                Add-Check "WARN" $cat "$($abweichend.Count) Kern-Datei(en) weichen von der eingespielten Version $eingespielt ab und stehen nicht in MEIN-SYSTEM.md Abschnitt 3: $($abweichend -join ', '). Beim naechsten Update geht die Aenderung verloren oder blockiert es. Wege: eigene Regel nach MEIN-SYSTEM.md Abschnitt 2, Pull Request gegen das Core-Repo, oder Eintrag in Abschnitt 3 (siehe 10_System\Kern-Dateien.md)."
            } else {
                Add-Check "OK" $cat "Keine unerklaerte Abweichung an Kern-Dateien gegenueber Version $eingespielt ($($kernA.Count) Dateien geprueft)."
            }
        }
    }

    # Nutzungsmodus gesetzt? (seit 2.1) Das LLM ist verantwortlich, den Modus im
    # Gespraech zu klaeren und einzutragen (AGENTS.md, Abschnitt 1); diese Pruefung
    # ist der mechanische Anstoss dafuer. Gesetzt heisst: hinter dem Feld steht
    # mitbauen oder benutzen, nicht mehr der kursive Platzhalter.
    if ($msText -match '(?m)^\s*-\s*\*\*Nutzungsmodus:\*\*\s*`?(mitbauen|benutzen)`?\b') {
        Add-Check "OK" $cat "Nutzungsmodus ist gesetzt: $($Matches[1])."
    } else {
        Add-Check "WARN" $cat "In MEIN-SYSTEM.md Abschnitt 5 ist kein Nutzungsmodus gesetzt (mitbauen oder benutzen). Das LLM fragt den Besitzer in der naechsten Session, erklaert den Unterschied kurz und traegt die Antwort selbst ein (AGENTS.md, Abschnitt 1, seit 2.1)."
    }
} else {
    Add-Check "WARN" $cat "MEIN-SYSTEM.md fehlt im Root. Die persoenliche Ebene (Name, Pfade, eigene Regeln, eingespielte Version) hat damit keinen Ort."
}
Write-Output "Mein-System-Check erledigt."
Write-Output ""


# ---------------------------------------------------------------------------
# LEAN (Groesse des in jeder Session geladenen Pflichtkontexts)
# ---------------------------------------------------------------------------
# AGENTS.md Abschnitt 10, Trennlinie steuernd/begruendend: Die Root-AGENTS.md
# traegt nur normative Regeln, Erzaehlungen wandern in die Begleitdatei
# 10_System\Detailregeln aus AGENTS.md.md. Die Schwelle ist ein Drift-Waechter
# ueber der eigenen Baseline, kein Zielwert: Waechst die Datei darueber, sind
# Erzaehlungen zurueckgewachsen; dann auslagern, nie Regeln loeschen.
# Passe $leanSchwelleKB an, wenn du die Baseline deiner AGENTS.md bewusst
# verschiebst (Startwert des Grundgeruests: rund 51 KB, Schwelle 60).
$cat = "Lean"

# Mitwachsende Marke statt fester Grenze (seit 2.4). Eine feste KB-Zahl waere
# eine Wachstumsbremse, und das ist ausdruecklich nicht der Zweck: Wer viel
# arbeitet, dessen System wird groesser und besser. Der Zweck ist ein Hinweis
# von Zeit zu Zeit, dass sich ein Optimierungslauf lohnen koennte, ohne dass
# dabei je Qualitaet geopfert wird. Deshalb misst der Check gegen die eigene
# letzte Referenzgroesse: Waechst der Pflichtkontext seit dem letzten Hinweis um
# mehr als 15 Prozent, meldet er sich einmal und zieht die Referenz danach selbst
# nach. So kommt der Hinweis bei jedem Wachstumsschritt genau einmal und nie als
# Dauerwarnung, und ein erfolgreicher Optimierungslauf senkt die Referenz sofort.
# Die Baseline-Datei gehoert dem Besitzer (Kern-Dateien.md, Kategorie C). Wer neu
# kalibrieren will, loescht sie einfach; der naechste Lauf legt sie neu an.
$leanWachstum = 1.15
$leanBaselinePfad = Join-Path $repo "00_INDEX\lean-baseline.txt"

$agentsSize = (Get-Item (Join-Path $repo "AGENTS.md")).Length
$kontextDateien = @((Join-Path $repo "AGENTS.md"), (Join-Path $repo "CLAUDE.md"), (Join-Path $repo "MEIN-SYSTEM.md")) +
    @(Get-ChildItem (Join-Path $repo "01_Basiskontext") -Filter "*.md" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "README.md" } | ForEach-Object { $_.FullName })
$kontextTotal = ($kontextDateien | Where-Object { Test-Path $_ } | ForEach-Object { (Get-Item $_).Length } | Measure-Object -Sum).Sum

$leanBasis = @{ agents = 0.0; kontext = 0.0 }
if (Test-Path -LiteralPath $leanBaselinePfad) {
    foreach ($z in (Get-Content -LiteralPath $leanBaselinePfad -Encoding UTF8)) {
        if ($z -match '^\s*agents_kb\s*=\s*([0-9.]+)') { $leanBasis.agents = [double]$Matches[1] }
        if ($z -match '^\s*kontext_kb\s*=\s*([0-9.]+)') { $leanBasis.kontext = [double]$Matches[1] }
    }
}

function Write-LeanBaseline([double]$AgentsKB, [double]$KontextKB) {
    $inhalt = @(
        "# Referenzgroessen fuer den Wachstums-Hinweis des Health-Checks (Kategorie Lean).",
        "# Keine Grenze und kein Zielwert: Der Check meldet sich, wenn der in jeder Session",
        "# geladene Pflichtkontext seit diesen Werten um mehr als 15 Prozent gewachsen ist,",
        "# und schreibt die Werte danach selbst fort. Wachstum wird nie gekappt.",
        "# Neu kalibrieren: diese Datei loeschen, der naechste Lauf legt sie neu an.",
        ("agents_kb=" + $AgentsKB.ToString("0.0", [System.Globalization.CultureInfo]::InvariantCulture)),
        ("kontext_kb=" + $KontextKB.ToString("0.0", [System.Globalization.CultureInfo]::InvariantCulture)),
        ("gesetzt=" + (Get-Date -Format "yyyy-MM-dd"))
    )
    Set-Content -LiteralPath $leanBaselinePfad -Value $inhalt -Encoding UTF8
}

$agentsKB = [math]::Round($agentsSize / 1KB, 1)
$kontextKB = [math]::Round($kontextTotal / 1KB, 1)

if ($leanBasis.agents -le 0 -or $leanBasis.kontext -le 0) {
    Write-LeanBaseline $agentsKB $kontextKB
    Add-Check "INFO" $cat ("Wachstums-Referenz neu angelegt: AGENTS.md {0:N1} KB, Pflichtkontext {1:N1} KB. Ab jetzt meldet sich der Check, wenn einer der beiden Werte um mehr als 15 Prozent darueber liegt." -f $agentsKB, $kontextKB)
} else {
    $agentsGewachsen  = $agentsKB  -gt ($leanBasis.agents  * $leanWachstum)
    $kontextGewachsen = $kontextKB -gt ($leanBasis.kontext * $leanWachstum)
    if ($agentsGewachsen -or $kontextGewachsen) {
        $teile = @()
        if ($agentsGewachsen)  { $teile += ("AGENTS.md {0:N1} KB statt {1:N1} KB" -f $agentsKB, $leanBasis.agents) }
        if ($kontextGewachsen) { $teile += ("Pflichtkontext {0:N1} KB statt {1:N1} KB" -f $kontextKB, $leanBasis.kontext) }
        Add-Check "WARN" $cat ("Der in jeder Session geladene Kontext ist spuerbar gewachsen: " + ($teile -join ", ") + ". Das ist normal, wenn viel gearbeitet wurde, und KEIN Kuerzungsauftrag. Bei Gelegenheit mit dem Skill leo-system-optimierung (Trigger 'messlauf') pruefen, ob sich etwas ohne jeden Verlust an Arbeitsqualitaet sparen laesst, und das Ergebnis dem Besitzer vorlegen. Nie eigenmaechtig streichen, damit eine Zahl faellt. Die Referenz ist auf die heutigen Werte nachgezogen, der Hinweis kommt also erst beim naechsten Wachstumsschritt wieder.")
        Write-LeanBaseline $agentsKB $kontextKB
    } else {
        if ($agentsKB -lt $leanBasis.agents -or $kontextKB -lt $leanBasis.kontext) {
            Write-LeanBaseline ([math]::Min($agentsKB, $leanBasis.agents)) ([math]::Min($kontextKB, $leanBasis.kontext))
        }
        Add-Check "OK" $cat ("Pflichtkontext jeder Session: AGENTS.md {0:N1} KB, gesamt {1:N1} KB (Referenz {2:N1} / {3:N1} KB, Hinweis ab plus 15 Prozent)." -f $agentsKB, $kontextKB, $leanBasis.agents, $leanBasis.kontext)
    }
}

# Messlauf-Waechter: Die Regeltreue-Messung (Skill leo-system-optimierung,
# Pruefset in 10_System\Pruefset.md) darf nicht daran haengen, dass jemand an
# sie denkt. Existiert ein Pruefset, wird gewarnt, wenn eine Kernaenderung
# (AGENTS.md, Einstiegsdateien, Settings, Guard-Hook) laut Git NACH dem letzten
# protokollierten Messlauf liegt oder der letzte Lauf aelter als 42 Tage ist.
# Ohne Pruefset ist die Messung optional; dann nur ein stiller INFO-Hinweis.
$pruefsetPfad = Join-Path $repo "10_System\Pruefset.md"
if (Test-Path $pruefsetPfad) {
    $laufDaten = Select-String -Path $pruefsetPfad -Pattern '^#{2,3} .*Lauf.*?(\d{4}-\d{2}-\d{2})' | ForEach-Object { $_.Matches[0].Groups[1].Value }
    $letzterLauf = ($laufDaten | Sort-Object | Select-Object -Last 1)
    if ($letzterLauf) {
        $kernPfade = @("AGENTS.md", "CLAUDE.md", ".claude/settings.json", "00_INDEX/scripts/guard-workspace.ps1")
        $kernDatum = (& git -C $repo log -1 --format=%ad --date=format:%Y-%m-%d -- @kernPfade 2>$null)
        $laufDT = [datetime]::ParseExact($letzterLauf, "yyyy-MM-dd", $null)
        if ($kernDatum -and ([datetime]::ParseExact($kernDatum, "yyyy-MM-dd", $null) -gt $laufDT)) {
            Add-Check "WARN" $cat "Kernaenderung vom $kernDatum liegt nach dem letzten Pruefset-Messlauf ($letzterLauf). Nachmessung faellig: Skill leo-system-optimierung fahren (Trigger 'messlauf')."
        } elseif (((Get-Date) - $laufDT).TotalDays -gt 42) {
            Add-Check "WARN" $cat "Letzter Pruefset-Messlauf am $letzterLauf, aelter als 42 Tage. Stichprobe faellig: Skill leo-system-optimierung fahren (Trigger 'messlauf')."
        } else {
            Add-Check "OK" $cat "Letzter Pruefset-Messlauf am $letzterLauf, keine ungemessene Kernaenderung seither."
        }
    } else {
        Add-Check "WARN" $cat "In 10_System\Pruefset.md ist kein Messlauf-Datum erkennbar (Muster '## ... Lauf ... YYYY-MM-DD'). Protokollformat pruefen."
    }
} else {
    Add-Check "INFO" $cat "Kein 10_System\Pruefset.md vorhanden. Die Regeltreue-Messung ist optional; die Vorlage liegt in 10_System\Pruefset-Vorlage.md (Skill leo-system-optimierung)."
}
# Session-Kosten (seit 3.3): 00_INDEX\scripts\session-kosten.py misst den Verbrauch aller
# lokalen Claude-Code-Transkripte der letzten 14 Tage zu API-Listenpreisen und schreibt
# 00_INDEX\session-kosten.md. Hier nur die Befundzeilen (Session ueber 200 Aufrufe, Tag
# ueber der Kostenschwelle, sonst eine OK-Zeile mit Summe und Kontext je Aufruf).
# Hintergrund AGENTS.md Abschnitt 1 (Buendelungsregel) und 13. Braucht Python im PATH;
# fehlt es, ist das ein INFO und kein Befund: Die Messung ist Zusatz, nicht Grundlage.
$kostenSkript = Join-Path $repo "00_INDEX\scripts\session-kosten.py"
if (Test-Path -LiteralPath $kostenSkript) {
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Add-Check "INFO" $cat "Python nicht im PATH; Session-Kosten nicht gemessen (00_INDEX\scripts\session-kosten.py, optional)."
    } else {
        $kostenZeilen = @()
        try {
            $kostenZeilen = & python $kostenSkript --health 2>&1
            & python $kostenSkript 2>&1 | Out-Null
            Remove-Item -LiteralPath (Join-Path $repo "00_INDEX\scripts\__pycache__") -Recurse -Force -ErrorAction SilentlyContinue
        } catch { $kostenZeilen = @("WARN|session-kosten.py liess sich nicht starten: $($_.Exception.Message)") }
        foreach ($kz in $kostenZeilen) {
            $kz = [string]$kz
            if ($kz -match '^(OK|WARN|INFO)\|(.+)$') {
                $stufe = if ($Matches[1] -eq "INFO") { "OK" } else { $Matches[1] }
                Add-Check $stufe $cat $Matches[2]
            }
        }
        if (-not ($kostenZeilen | Where-Object { [string]$_ -match '^(OK|WARN|INFO)\|' })) {
            Add-Check "WARN" $cat "session-kosten.py lieferte keine Befundzeile (Ausgabe: $(($kostenZeilen | Select-Object -First 1)))."
        }
    }
}
Write-Output "Lean-Check erledigt."
Write-Output ""


# ---------------------------------------------------------------------------
# BERICHT
# ---------------------------------------------------------------------------
Write-Output "=== Ergebnis ==="
foreach ($r in $results) {
    Write-Output "[$($r.Level)] [$($r.Category)] $($r.Message)"
}
Write-Output ""

$okC = ($results | Where-Object Level -eq "OK").Count
$infoC = ($results | Where-Object Level -eq "INFO").Count
$warnC = ($results | Where-Object Level -eq "WARN").Count
$failC = ($results | Where-Object Level -eq "FAIL").Count

Write-Output "Zusammenfassung: $okC OK, $infoC INFO, $warnC WARN, $failC FAIL"

if ($failC -gt 0) {
    Write-Output "VERDIKT: SYSTEM NICHT EINSATZBEREIT - $failC kritische(s) Problem(e) beheben."
    exit 2
} elseif ($warnC -gt 0) {
    Write-Output "VERDIKT: SYSTEM EINSATZBEREIT MIT HINWEISEN - $warnC Punkt(e) pruefen/beheben."
    exit 1
} else {
    Write-Output "VERDIKT: SYSTEM VOLLSTAENDIG GESUND."
    exit 0
}
