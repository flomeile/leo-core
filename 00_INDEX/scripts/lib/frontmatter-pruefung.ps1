# frontmatter-pruefung.ps1
# Zweck: Gemeinsame Pruefregeln fuer das YAML-Frontmatter von Markdown-Dateien (seit 4.9).
#
# WARUM ES DAS GIBT: Ein einziges falsches Zeichen in einem Frontmatter-Wert macht den ganzen
# Block ungueltig. Der Editor zeigt die Eigenschaften dann als fehlerhaft oder gar nicht an,
# Filter und Abfragen ueber type:, stand: oder zweck: sehen die Datei nicht mehr, und im
# Quelltext ist der Fehler fast unsichtbar. Die Textregel in AGENTS.md Abschnitt 5 allein
# reicht dafuer nicht: Ein Modell schreibt "zweck: Ablauf: Schritt fuer Schritt" in gutem
# Glauben. Deshalb prueft dieselbe Logik an zwei Stellen:
#   pruef-frontmatter.ps1 (PostToolUse-Hook): jede geschriebene .md sofort, das Modell
#                          repariert im selben Zug
#   health-check.ps1      (Kategorie Frontmatter): den ganzen Bestand, auch was von Hand im
#                          Editor oder von einem anderen Werkzeug geschrieben wurde
# Eine Regel steht nur hier; wer sie aendert, aendert beide Pruefungen zugleich.
#
# WAS SIE PRUEFT: kein vollstaendiger YAML-Parser (Windows PowerShell 5.1 bringt keinen mit),
# sondern die Faelle, die einen einfachen "schluessel: wert"-Block brechen oder still
# verfaelschen: Doppelpunkt mit Leerzeichen, ' #', Steuerzeichen am Wertanfang (Backtick, &,
# *, ! usw.), Backslash in doppelten Anfuehrungszeichen, offene Anfuehrungszeichen, Text nach
# dem schliessenden Anfuehrungszeichen, doppelte Schluessel, Tabulatoren, fehlendes Leerzeichen
# nach dem Doppelpunkt, ungeschlossener Block. Gueltig bleiben Uhrzeiten (07:45), 1:1, URLs,
# zitierte Werte, Listen [a, b] und Blockwerte (| oder >).
# Regressionsreihe: pruef-frontmatter-tests.ps1 im Ordner darueber. Wer eine Regel ergaenzt,
# ergaenzt dort einen Fall.
# ASCII-only, laeuft unter Windows PowerShell 5.1 und PowerShell 7.

function Test-LeoFrontmatterWert {
    # Prueft einen einzelnen Wert (ohne fuehrende Leerzeichen). Liefert $null oder den Befund als Text.
    param([string]$Wert)
    $v = $Wert.TrimEnd()
    if ($v -eq '') { return $null }
    if ($v.Contains("`t")) { return 'Tabulator im Wert' }
    if ($v.StartsWith('"')) {
        if ($v -match '^"(?:[^"\\]|\\.)*"\s*(#.*)?$') {
            # In doppelten Anfuehrungszeichen ist \ ein Escape: Aus C:\neu wird still ein Zeilenumbruch,
            # aus C:\temp ein Tabulator. Erlaubt bleiben nur \\ und \".
            if (($v -replace '\\\\', '') -match '\\[^"]') { return 'Backslash in doppelten Anfuehrungszeichen (etwa ein Windows-Pfad); einfache Anfuehrungszeichen nehmen' }
            return $null
        }
        return 'doppelte Anfuehrungszeichen nicht sauber: Wert muss mit " enden, ein " im Inneren braucht \"'
    }
    if ($v.StartsWith("'")) {
        if ($v -match "^'(?:[^']|'')*'\s*(#.*)?$") { return $null }
        return "einfache Anfuehrungszeichen nicht sauber: Wert muss mit ' enden, ein ' im Inneren wird verdoppelt ('')"
    }
    if ($v.StartsWith('[')) {
        if ($v -match '^\[[^\[\]{}]*\]$') {
            foreach ($teil in $v.Substring(1, $v.Length - 2).Split(',')) {
                $t = $teil.Trim()
                if ($t -match '^["'']') { continue }
                if ($t -match ':(\s|$)') { return 'Doppelpunkt mit Leerzeichen in einem Listeneintrag' }
            }
            return $null
        }
        return 'beginnt mit [ und ist keine geschlossene Liste [a, b]'
    }
    if ($v.StartsWith('{')) {
        if ($v -match '^\{[^{}]*\}$') { return $null }
        return 'beginnt mit { und ist kein geschlossenes Objekt'
    }
    if ($v -match '^[|>][+-]?[0-9]?$') { return $null }   # Blockwert, der Inhalt folgt eingerueckt
    if ($v.StartsWith('#')) { return 'beginnt mit #, YAML liest den Rest als Kommentar, der Wert ist leer' }
    if ($v -match '^[&*!%@`,\]}|>]') { return "beginnt mit dem Steuerzeichen $($v[0])" }
    if ($v -match '^[-?:](\s|$)') { return "beginnt mit '$($v[0]) ', YAML liest das als Struktur" }
    if ($v -match ':(\s|$)') { return 'Doppelpunkt mit Leerzeichen danach (oder am Ende)' }
    if ($v -match '\s#') { return "' #' im Wert, YAML schneidet ab dort als Kommentar ab" }
    return $null
}

function Test-LeoFrontmatter {
    # Prueft den Frontmatter-Block einer Datei. $Zeilen = alle Zeilen der Datei.
    # Liefert eine Liste von Objekten (Zeile = Zeilennummer in der Datei, Schluessel, Problem); leer, wenn
    # die Datei kein Frontmatter hat oder es sauber ist.
    param([string[]]$Zeilen)
    $befunde = New-Object System.Collections.ArrayList
    if (-not $Zeilen -or $Zeilen.Count -lt 2) { return ,$befunde }
    if ($Zeilen[0].TrimStart([char]0xFEFF).TrimEnd() -ne '---') { return ,$befunde }

    $ende = -1
    for ($i = 1; $i -lt $Zeilen.Count; $i++) { if ($Zeilen[$i].TrimEnd() -eq '---' -or $Zeilen[$i].TrimEnd() -eq '...') { $ende = $i; break } }
    if ($ende -lt 0) {
        [void]$befunde.Add([pscustomobject]@{ Zeile = 1; Schluessel = ''; Problem = 'Frontmatter wird mit --- geoeffnet, aber nie geschlossen' })
        return ,$befunde
    }

    $gesehen = @{}
    $blockEinzug = -1      # Einzug des Schluessels, dessen Blockwert (| oder >) gerade laeuft
    $wertEinzug = -1       # Einzug des Schluessels mit einfachem Wert (fuer Fortsetzungszeilen)
    $schluessel = ''
    for ($i = 1; $i -lt $ende; $i++) {
        $z = $Zeilen[$i]
        $nr = $i + 1
        if ($z.Trim() -eq '') { continue }
        $einzug = $z.Length - $z.TrimStart(' ').Length
        if ($blockEinzug -ge 0) {
            if ($einzug -gt $blockEinzug) { continue }
            $blockEinzug = -1
        }
        if ($z -match '^\s*#') { continue }
        if ($z -match '^\t' -or ($einzug -lt $z.Length -and $z.TrimStart(' ').StartsWith("`t"))) {
            [void]$befunde.Add([pscustomobject]@{ Zeile = $nr; Schluessel = $schluessel; Problem = 'Tabulator zur Einrueckung, YAML erlaubt nur Leerzeichen' }); continue
        }
        if ($z -match '^(\s*)-(\s+(.*))?$') {
            # Listeneintrag; ein Eintrag der Form "- name: wert" ist eine Zuordnung in der Liste
            $item = if ($Matches[3]) { $Matches[3] } else { '' }
            if ($item -match '^([^\s"''#\[{][^:]*?):(\s+(.*))?$') { $item = if ($Matches[3]) { $Matches[3] } else { '' } }
            $p = Test-LeoFrontmatterWert $item
            if ($p) { [void]$befunde.Add([pscustomobject]@{ Zeile = $nr; Schluessel = $schluessel; Problem = "Listeneintrag: $p" }) }
            continue
        }
        if ($z -match '^(\s*)([^\s"''#\[{&*!|>%@`,-][^:]*?|"[^"]*"|''[^'']*''):(\s+(.*))?$') {
            # Schluessel und Wert sichern, bevor das naechste -match $Matches ueberschreibt.
            $k = $Matches[2].Trim()
            $wert = if ($Matches[4]) { $Matches[4] } else { '' }
            if ($einzug -eq 0) {
                $schluessel = $k
                if ($gesehen.ContainsKey($k)) {
                    [void]$befunde.Add([pscustomobject]@{ Zeile = $nr; Schluessel = $k; Problem = "Schluessel doppelt (schon in Zeile $($gesehen[$k]))" })
                } else { $gesehen[$k] = $nr }
            }
            $p = Test-LeoFrontmatterWert $wert
            if ($p) { [void]$befunde.Add([pscustomobject]@{ Zeile = $nr; Schluessel = $k; Problem = $p }) }
            if ($wert.Trim() -match '^[|>][+-]?[0-9]?$') { $blockEinzug = $einzug; $wertEinzug = -1 }
            elseif ($wert.Trim() -ne '') { $wertEinzug = $einzug } else { $wertEinzug = -1 }
            continue
        }
        if ($wertEinzug -ge 0 -and $einzug -gt $wertEinzug) {
            # Fortsetzungszeile eines mehrzeiligen einfachen Werts
            $p = Test-LeoFrontmatterWert $z.Trim()
            if ($p -and $p -notlike 'beginnt mit*') { [void]$befunde.Add([pscustomobject]@{ Zeile = $nr; Schluessel = $schluessel; Problem = "Fortsetzungszeile: $p" }) }
            continue
        }
        [void]$befunde.Add([pscustomobject]@{ Zeile = $nr; Schluessel = ''; Problem = 'Zeile ist weder "schluessel: wert" (Leerzeichen nach dem Doppelpunkt) noch Listeneintrag' })
    }
    return ,$befunde
}

function Get-LeoFrontmatterStand {
    # Liefert den Wert von stand: auf oberster Ebene des Frontmatters oder $null.
    param([string[]]$Zeilen)
    if (-not $Zeilen -or $Zeilen.Count -lt 2) { return $null }
    if ($Zeilen[0].TrimStart([char]0xFEFF).TrimEnd() -ne '---') { return $null }
    for ($i = 1; $i -lt $Zeilen.Count; $i++) {
        if ($Zeilen[$i].TrimEnd() -eq '---') { break }
        if ($Zeilen[$i] -match '^stand:\s*["'']?([^"'']*)["'']?\s*$') { return $Matches[1].Trim() }
    }
    return $null
}
