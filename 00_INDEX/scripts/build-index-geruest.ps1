# build-index-geruest.ps1 (Version 2)
# Zweck: Haelt alle MECHANISCHEN Index-Anteile aktuell. Kein LLM, keine Halluzination.
# Listet nur real existierende Dateien; Geloeschtes faellt automatisch raus.
#
# Das Skript macht drei Dinge:
# 1) INDEX-Geruest.md neu erzeugen: vollstaendige, deterministische Baumliste aller .md-Dateien
#    (volle Hierarchie, alle Ebenen), mit Basis-Beschreibung, Groesse, Aenderungsdatum.
# 2) 00_INDEX\INDEX.md: aktualisiert den Auto-Block "BAUM" (Ordnerbaum mit Dateizahlen).
# 3) Je Themenordner (Ordner mit lokaler AGENTS.md/Rolle, numerischer Praefix >= 20 -
#    siehe Test-IsThemenordner; NICHT auf "2X" begrenzt, 30_, 31_, ... zaehlen genauso):
#    legt _INDEX.md an, falls fehlend; aktualisiert den Auto-Block "DATEILISTE"; entfernt
#    kuratierte Beschreibungs-Eintraege zu nicht mehr existierenden Dateien.
#
# Auto-Bloecke sind durch Marker begrenzt (<!-- AUTO:NAME:BEGIN --> / <!-- AUTO:NAME:END -->).
# Alles zwischen den Markern gehoert dem Skript. Nie von Hand aendern.
#
# Aufruf: pwsh -NoProfile -ExecutionPolicy Bypass -File "<REPO>\00_INDEX\scripts\build-index-geruest.ps1"
# Der Repo-Root wird automatisch aus dem Skript-Speicherort ($PSScriptRoot) abgeleitet.
# Das Skript ist dadurch verschiebbar: kein hartcodierter Pfad, funktioniert an jedem Ort.

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
# .claude ist Harness-Territorium, kein Wissen: Konfiguration und vor allem
# .claude\worktrees\ (vollstaendige Zweitkopien des Repos aus Parallel-Sessions).
# Git ignoriert diese Kopien via .git\info\exclude, das Skript laeuft aber ueber
# das Dateisystem und wuerde sie sonst mitindexieren (jede Datei doppelt).
# Dieselbe Logik gilt fuer die uebrigen Werkzeug-Verzeichnisse und die generierten
# Skill-Zeiger darin (AGENTS.md Abschnitt 11a): Konfiguration, kein Wissen.
$excludeDirs = @(".git", ".obsidian", ".claude", ".agents", ".gemini", ".cursor", ".cline", ".opencode", ".github")
$metaNames = @("INDEX.md", "INDEX-Geruest.md", "_INDEX.md")
$now = Get-Date -Format "yyyy-MM-dd HH:mm"

# --- Hilfsfunktionen ---------------------------------------------------------

function Get-BasisDesc([string]$filePath) {
    # Erste Ueberschrift (# ...) oder erste inhaltliche Zeile als Basis-Beschreibung.
    $desc = ""
    $content = Get-Content -Path $filePath -Encoding UTF8 -ErrorAction SilentlyContinue
    foreach ($line in $content) {
        $trim = $line.Trim()
        if ($trim -match "^#\s+(.+)$") { return $matches[1].Trim() }
        if ($desc -eq "" -and $trim -ne "" -and $trim -notmatch "^---$" -and $trim -notmatch "^(titel|zweck|type|version|name|trigger|date|time|topic|context|tags|stand|hinweis|erzeugt|letzte_aenderung):") {
            $desc = $trim
        }
    }
    if ($desc -eq "") { $desc = "(keine Beschreibung gefunden)" }
    return $desc
}

function Add-FileTree {
    # Haengt einen Baum (Dateien + Unterordner, rekursiv) an $out an.
    param([string]$dirPath, [int]$depth, [System.Collections.Generic.List[string]]$out, [bool]$withMeta)
    $indent = "  " * $depth
    $files = Get-ChildItem -Path $dirPath -File -Filter "*.md" | Where-Object { $metaNames -notcontains $_.Name } | Sort-Object Name
    foreach ($f in $files) {
        if ($withMeta) {
            $desc = Get-BasisDesc $f.FullName
            $kb = [math]::Round($f.Length / 1KB, 1)
            $dat = $f.LastWriteTime.ToString("yyyy-MM-dd")
            $out.Add("$indent- $($f.Name) | $desc | $kb KB | $dat")
        } else {
            $out.Add("$indent- $($f.Name)")
        }
    }
    $dirs = Get-ChildItem -Path $dirPath -Directory | Where-Object { $excludeDirs -notcontains $_.Name } | Sort-Object Name
    foreach ($d in $dirs) {
        $out.Add("$indent- $($d.Name)\")
        Add-FileTree -dirPath $d.FullName -depth ($depth + 1) -out $out -withMeta $withMeta
    }
}

function Add-DirTree {
    # Haengt einen reinen Ordnerbaum (mit Anzahl .md-Dateien je Ordner, rekursiv gezaehlt) an $out an.
    param([string]$dirPath, [int]$depth, [System.Collections.Generic.List[string]]$out)
    $dirs = Get-ChildItem -Path $dirPath -Directory | Where-Object { $excludeDirs -notcontains $_.Name } | Sort-Object Name
    foreach ($d in $dirs) {
        $count = @(Get-ChildItem -Path $d.FullName -Recurse -File -Filter "*.md" | Where-Object { $metaNames -notcontains $_.Name }).Count
        $indent = "  " * $depth
        $out.Add("$indent- $($d.Name)\  ($count Dateien)")
        Add-DirTree -dirPath $d.FullName -depth ($depth + 1) -out $out
    }
}

function Write-RepoFile([string]$path, [string]$text) {
    # Schreibt UTF-8 OHNE BOM, in jeder PowerShell-Version gleich (seit 3.3).
    # Grund: "Set-Content -Encoding UTF8" bedeutet in Windows PowerShell 5.1 UTF-8
    # MIT BOM und erst ab PowerShell 7 ohne. Startet der Scheduler pwsh (7) und eine
    # Session einmal powershell (5.1), tragen alle erzeugten Indexdateien plus die
    # AGENTS.md ein BOM als einzige Aenderung im Diff. Diese Funktion macht das
    # Ergebnis unabhaengig davon, wer das Skript startet. Kein -NoNewline noetig:
    # WriteAllText haengt von sich aus nichts an.
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Set-AutoBlock([string]$file, [string]$blockName, [string[]]$bodyLines) {
    # Ersetzt den Inhalt zwischen den Markern des benannten Auto-Blocks. Rein mechanisch.
    if (-not (Test-Path $file)) { Write-Output "WARNUNG: $file fehlt, Auto-Block $blockName nicht aktualisiert."; return }
    $begin = "<!-- AUTO:{0}:BEGIN -->" -f $blockName
    $end = "<!-- AUTO:{0}:END -->" -f $blockName
    $text = Get-Content -Path $file -Raw -Encoding UTF8
    $i = $text.IndexOf($begin)
    $j = $text.IndexOf($end)
    if ($i -lt 0 -or $j -lt $i) { Write-Output "WARNUNG: Marker AUTO:$blockName fehlen in $file."; return }
    $body = ($bodyLines -join "`r`n")
    $newText = $text.Substring(0, $i + $begin.Length) + "`r`n" + $body + "`r`n" + $text.Substring($j)
    # $newText enthaelt ueber $text.Substring($j) bereits das originale Dateiende samt
    # Zeilenumbruch. Write-RepoFile haengt nichts an; wuerde hier etwas angehaengt,
    # wuechse die Datei bei JEDEM Lauf um eine Leerzeile (taeglicher Scheduler =
    # taegliches Wachstum und eine sinnlose Aenderung im Commit).
    Write-RepoFile -path $file -text $newText
}

# --- 1) INDEX-Geruest.md -----------------------------------------------------

$allFiles = @(Get-ChildItem -Path $repo -Recurse -File -Filter "*.md" |
    Where-Object { $_.FullName -notmatch "\\\.(git|obsidian|claude)\\" -and $metaNames -notcontains $_.Name })

$g = New-Object System.Collections.Generic.List[string]
$g.Add("---")
$g.Add("titel: Index-Geruest (mechanisch erzeugt)")
$g.Add("zweck: Vollstaendige, deterministische Baumliste aller Markdown-Dateien im Repo")
$g.Add("type: index-geruest")
$g.Add("erzeugt: $now")
$g.Add("hinweis: Automatisch erzeugt. Nicht von Hand bearbeiten. Sicherheitsnetz und Delta-Quelle fuer die kuratierten Indizes.")
$g.Add("---")
$g.Add("")
$g.Add("# Index-Geruest")
$g.Add("")
$g.Add("Mechanisch aus dem Dateisystem erzeugt am $now. Volle Hierarchie, jede real existierende .md-Datei.")
$g.Add("Format je Datei: Name | Basis-Beschreibung (erste Ueberschrift) | Groesse | geaendert.")
$g.Add("")
Add-FileTree -dirPath $repo -depth 0 -out $g -withMeta $true
$g.Add("")
$g.Add("---")
$g.Add("Ende des Geruests. Anzahl Dateien: $($allFiles.Count)")

$geruestFile = Join-Path $repo "00_INDEX\INDEX-Geruest.md"
Write-RepoFile -path $geruestFile -text (($g -join "`r`n") + "`r`n")
Write-Output "Index-Geruest geschrieben: $geruestFile ($($allFiles.Count) Dateien)"

# --- 2) Ordnerbaum in INDEX.md -----------------------------------------------

$tree = New-Object System.Collections.Generic.List[string]
$tree.Add("Stand: $now (mechanisch aktualisiert, Anzahl = .md-Dateien inkl. Unterordner)")
$tree.Add("")
Add-DirTree -dirPath $repo -depth 0 -out $tree
Set-AutoBlock -file (Join-Path $repo "00_INDEX\INDEX.md") -blockName "BAUM" -bodyLines $tree
Write-Output "Ordnerbaum in INDEX.md aktualisiert."

# --- 2b) Rollen-Tabelle in AGENTS.md und Themenbereiche in INDEX.md -----------
# Quelle der Wahrheit fuer die Rolle ist die lokale AGENTS.md des Ordners
# (Zeile "# Rolle: ..."). Tabelle und Bereichsliste werden daraus mechanisch erzeugt.

function Get-Rolle([string]$agentsFile) {
    $c = Get-Content -Path $agentsFile -Encoding UTF8 -ErrorAction SilentlyContinue
    foreach ($line in $c) {
        if ($line -match "^#\s+Rolle:\s*(.+)$") { return $matches[1].Trim() }
    }
    return "(Rolle fehlt: Zeile '# Rolle: ...' in der lokalen AGENTS.md ergaenzen)"
}

function Test-IsThemenordner([System.IO.DirectoryInfo]$dir) {
    # Themenordner = Ordner mit eigener Rolle (lokale AGENTS.md, "# Rolle: ..."), dessen
    # numerischer Praefix >= 20 ist. Bewusst NICHT hart auf "2X" begrenzt: 30_, 31_, ...
    # zaehlen genauso, damit neue Themenbereiche jenseits von 29 automatisch als
    # Themenordner erkannt werden (eigene _INDEX.md, Eintrag in INDEX.md BEREICHE).
    # Ordner mit Praefix < 20 (00_INDEX, 01_Basiskontext, 02_Skills, 03_Sessionlogs,
    # 04_Changelog, 10_System, ...) sind Systemordner und werden hier ausgeschlossen.
    if ($dir.Name -notmatch "^(\d+)_") { return $false }
    return [int]$matches[1] -ge 20
}

$roleDirs = Get-ChildItem -Path $repo -Directory | Where-Object { Test-Path (Join-Path $_.FullName "AGENTS.md") } | Sort-Object Name

$rollen = New-Object System.Collections.Generic.List[string]
$rollen.Add("| Ordner | Rolle |")
$rollen.Add("|---|---|")
foreach ($d in $roleDirs) {
    $rolle = Get-Rolle (Join-Path $d.FullName "AGENTS.md")
    $rollen.Add("| $($d.Name) | $rolle |")
}
Set-AutoBlock -file (Join-Path $repo "AGENTS.md") -blockName "ROLLEN" -bodyLines $rollen
Write-Output "Rollen-Tabelle in AGENTS.md aktualisiert ($($roleDirs.Count) Ordner)."

# --- Skill-Kurzliste in AGENTS.md (seit 2.1) ---------------------------------
# Zweck: Name, Trigger, erster Zwecksatz und der situative Anlass ("Von selbst,
# wenn") aller Skills stehen dadurch in jeder Session im Kontext. Das LLM soll
# Skills aktiv vorschlagen, wenn die Situation passt, statt auf ein Trigger-Wort
# zu warten; die Substanz bleibt im Register und in der Skill-Datei.
$registerFile = Join-Path $repo "02_Skills\Skill-Register.md"
$skillLines = New-Object System.Collections.Generic.List[string]
$skillLines.Add("| Skill | Trigger-Worte | Wofuer | Von selbst, wenn |")
$skillLines.Add("|---|---|---|---|")
$anzSkills = 0
if (Test-Path $registerFile) {
    foreach ($zeile in (Get-Content -Path $registerFile -Encoding UTF8)) {
        $t = $zeile.Trim()
        if (-not $t.StartsWith("|")) { continue }
        if ($t -match "^\|\s*Skill\s*\|") { continue }
        if ($t -match "^\|\s*-+") { continue }
        $cols = ($t.Trim("|") -split "\|") | ForEach-Object { $_.Trim() }
        if ($cols.Count -lt 4) { continue }
        if ($cols[2] -notmatch "\.md\s*$") { continue }
        $zweck = $cols[3]
        # Erster Satz, danach gekappt: Die Kurzliste soll klein bleiben, sonst
        # kostet sie in jeder Session genau das, was sie sparen soll.
        # Satzende suchen, aber Abkuerzungen ueberspringen: "(inkl. Praefix)" ist kein
        # Satzende, und ein dort abgeschnittener Zweck liest sich wie ein Fehler.
        $abk = @("inkl", "z.B", "u.a", "ca", "bzw", "ggf", "evtl", "etc", "Nr", "vgl", "ff", "usw")
        $suchAb = 30
        while ($true) {
            $punkt = $zweck.IndexOf(". ", $suchAb)
            if ($punkt -lt 0) { break }
            $vor = $zweck.Substring(0, $punkt)
            $letztes = ($vor -split "[\s\(\[]")[-1]
            if ($abk -contains $letztes) { $suchAb = $punkt + 2; continue }
            $zweck = $zweck.Substring(0, $punkt)
            break
        }
        if ($zweck.Length -gt 200) { $zweck = $zweck.Substring(0, 197) + "..." }
        $anlassSp = if ($cols.Count -ge 5) { $cols[4] } else { "" }
        $skillLines.Add("| $($cols[0]) | $($cols[1]) | $zweck | $anlassSp |")
        $anzSkills++
    }
}
if ($anzSkills -gt 0) {
    Set-AutoBlock -file (Join-Path $repo "AGENTS.md") -blockName "SKILLS" -bodyLines $skillLines
    Write-Output "Skill-Kurzliste in AGENTS.md aktualisiert ($anzSkills Skills)."
} else {
    Write-Output "WARNUNG: Keine Skill-Zeilen im Register erkannt, Kurzliste nicht angetastet."
}

$bereiche = New-Object System.Collections.Generic.List[string]
foreach ($d in ($roleDirs | Where-Object { Test-IsThemenordner $_ })) {
    $rolle = Get-Rolle (Join-Path $d.FullName "AGENTS.md")
    $bereiche.Add("- **$($d.Name)** | Rolle: $rolle | Regeln: $($d.Name)\AGENTS.md | Datei-Beschreibungen stehen NICHT hier, sondern in -> $($d.Name)\_INDEX.md (IMMER dort lesen)")
}
Set-AutoBlock -file (Join-Path $repo "00_INDEX\INDEX.md") -blockName "BEREICHE" -bodyLines $bereiche
Write-Output "Themenbereiche in INDEX.md aktualisiert."

# --- 3) Lokale _INDEX.md je Themenordner --------------------------------------

$themeDirs = $roleDirs | Where-Object { Test-IsThemenordner $_ } | Sort-Object Name
foreach ($t in $themeDirs) {
    $idx = Join-Path $t.FullName "_INDEX.md"

    # 3a) Anlegen, falls fehlend (Template)
    if (-not (Test-Path $idx)) {
        $tpl = @(
            "---",
            "titel: Lokaler Index $($t.Name)",
            "type: themen-index",
            "hinweis: Dateiliste mechanisch (Skript), Beschreibungen kuratiert (LLM). Auto-Bloecke nicht von Hand aendern.",
            "---",
            "",
            "# Lokaler Index: $($t.Name)",
            "",
            "Beschreibt die Wissensdateien in diesem Ordner. Erst die Dateiliste pruefen (immer aktuell), dann die kuratierten Beschreibungen nutzen. Fehlt eine Beschreibung, gilt die Basis-Beschreibung aus der Dateiliste.",
            "",
            "## Dateiliste (mechanisch aktuell)",
            "<!-- AUTO:DATEILISTE:BEGIN -->",
            "<!-- AUTO:DATEILISTE:END -->",
            "",
            "## Beschreibungen (kuratiert)",
            'Format je Eintrag: "- **Relativpfad** - Beschreibung". Eintraege zu geloeschten Dateien entfernt das Skript automatisch.',
            ""
        )
        Write-RepoFile -path $idx -text (($tpl -join "`r`n") + "`r`n")
        Write-Output "Neu angelegt: $idx"
    }

    # 3b) Dateiliste aktualisieren
    $list = New-Object System.Collections.Generic.List[string]
    $list.Add("Stand: $now")
    $list.Add("")
    Add-FileTree -dirPath $t.FullName -depth 0 -out $list -withMeta $true
    Set-AutoBlock -file $idx -blockName "DATEILISTE" -bodyLines $list

    # 3c) Kuratierte Eintraege zu geloeschten Dateien entfernen (rein loeschend, nie erzeugend)
    $linesIdx = Get-Content -Path $idx -Encoding UTF8
    $result = New-Object System.Collections.Generic.List[string]
    $inCurated = $false
    $skipContinuation = $false
    $removed = @()
    foreach ($ln in $linesIdx) {
        if ($ln -match "^## Beschreibungen") { $inCurated = $true; $skipContinuation = $false; $result.Add($ln); continue }
        elseif ($ln -match "^## ") { $inCurated = $false; $skipContinuation = $false }
        if ($inCurated -and $ln -match "^- \*\*(.+?)\*\*") {
            $relp = $matches[1]
            if (Test-Path (Join-Path $t.FullName $relp)) { $skipContinuation = $false; $result.Add($ln) }
            else { $skipContinuation = $true; $removed += $relp }
            continue
        }
        if ($inCurated -and $skipContinuation) {
            if ($ln -match "^\s+\S") { continue } else { $skipContinuation = $false }
        }
        $result.Add($ln)
    }
    if ($removed.Count -gt 0) {
        Write-RepoFile -path $idx -text (($result -join "`r`n") + "`r`n")
        Write-Output "Bereinigt in $($t.Name)\_INDEX.md (Datei existiert nicht mehr): $($removed -join ', ')"
    }
    Write-Output "Lokaler Index aktualisiert: $idx"
}

Write-Output "Fertig. $now"
