# pruef-frontmatter-tests.ps1
# Regressionsreihe fuer pruef-frontmatter.ps1 und lib\frontmatter-pruefung.ps1 (seit 4.9). Pflicht vor und
# nach jeder Aenderung an einem der beiden. Legt Testdateien in einem Wegwerf-Ordner unter TEMP an und ruft den
# Hook so auf, wie Claude Code es tut (JSON auf stdin, CLAUDE_PROJECT_DIR auf den Wegwerf-Ordner).
# Aufruf: pwsh -NoProfile -File pruef-frontmatter-tests.ps1 [-Exe powershell]   Exit 0 = alle gruen.
# -Exe bestimmt, unter welchem Interpreter der Hook laeuft; .claude\settings.json ruft powershell (5.1),
# deshalb beide fahren. Erwartung je Fall: still (keine Ausgabe), block (Befund im Frontmatter) oder
# hinweis (nur Erinnerung an stand:).
# ASCII-only; Umlaute im Testinhalt werden aus Zeichencodes gebaut.
param([string]$Exe = 'pwsh')
$ErrorActionPreference = 'Stop'
$hook = Join-Path $PSScriptRoot 'pruef-frontmatter.ps1'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('pruef-fm-tests-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$aussen = Join-Path ([IO.Path]::GetTempPath()) ('pruef-fm-aussen-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp, $aussen | Out-Null
$ue = [char]0x00FC
$heute = Get-Date -Format 'yyyy-MM-dd'
$utf8 = New-Object System.Text.UTF8Encoding($false)
# Ein- und Ausgabe des Treibers als UTF-8, damit Fall 24 den Umlaut im Pfad so uebergibt wie Claude Code.
# Grenze: Der Hook erbt die Konsolen-Codepage des Treibers; ob er seine Antwort selbst auf UTF-8 stellt,
# kann diese Reihe deshalb nicht unterscheiden (gemessen 28.10.2026), sie prueft das Lesen des Pfads.
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$faelle = @(
    @{ n = '01 sauber';                         erw = 'still';   fm = @('titel: Packliste', 'zweck: Was auf jede Reise mitkommt', 'type: wissensnotiz') }
    @{ n = '02 Doppelpunkt im Wert';            erw = 'block';   fm = @('titel: Packliste', 'zweck: Vereinsreise: Anmeldung') }
    @{ n = '03 Doppelpunkt zitiert';            erw = 'still';   fm = @("zweck: 'Vereinsreise: Anmeldung'") }
    @{ n = '04 Uhrzeit, Verhaeltnis, URL';      erw = 'still';   fm = @('zweck: Abfahrt 07:45 laut https://example.org/fahrplan', 'mischung: 2:1') }
    @{ n = '05 Raute nach Leerzeichen';         erw = 'block';   fm = @('ort: Tisch #3 im Saal') }
    @{ n = '06 Raute ohne Leerzeichen';         erw = 'still';   fm = @('ort: Tisch#3 im Saal') }
    @{ n = '07 Backtick am Anfang';             erw = 'block';   fm = @('beleg: `C:\Ablage\Rezepte\brot.pdf`') }
    @{ n = '08 Backtick in einfachen Zeichen';  erw = 'still';   fm = @("beleg: '``C:\Ablage\Rezepte\brot.pdf``'") }
    @{ n = '09 Backslash in doppelten';         erw = 'block';   fm = @('beleg: "C:\Ablage\neu.md"') }
    @{ n = '10 offenes Anfuehrungszeichen';     erw = 'block';   fm = @('titel: "Halb offen') }
    @{ n = '11 Text nach Anfuehrungszeichen';   erw = 'block';   fm = @('titel: "Vorspeise" und Rest') }
    @{ n = '12 doppelter Schluessel';           erw = 'block';   fm = @('titel: Einkauf', 'titel: Wocheneinkauf') }
    @{ n = '13 ohne Leerzeichen nach :';        erw = 'block';   fm = @('titel:Einkauf') }
    @{ n = '14 Liste inline und Block';         erw = 'still';   fm = @('tags: [reise, verein, sommer]', 'mitbringen:', '  - Zelt', '  - Kocher') }
    @{ n = '15 Blockwert mit Doppelpunkt';      erw = 'still';   fm = @('zweck: >', '  Ablauf: erst packen, dann laden', '  zweite Zeile', 'type: x') }
    @{ n = '16 Umlaut im Wert';                 erw = 'still';   fm = @("titel: Fr${ue}hst${ue}ck f${ue}r alle") }
    @{ n = '17 stand in der Vergangenheit';     erw = 'hinweis'; fm = @('titel: Einkauf', 'stand: 2020-01-01') }
    @{ n = '18 stand heute';                    erw = 'still';   fm = @('titel: Einkauf', "stand: $heute") }
    @{ n = '19 stand abgeschlossen';            erw = 'still';   fm = @('titel: Einkauf', 'stand: abgeschlossen 2020-01-01') }
    @{ n = '20 Befund und alter stand';         erw = 'block';   fm = @('titel: Reise: Nord', 'stand: 2020-01-01') }
    @{ n = '21 nicht geschlossen';              erw = 'block';   fm = @('titel: Einkauf'); offen = $true }
    @{ n = '22 Datei ausserhalb des Repos';     erw = 'still';   fm = @('titel: Reise: Nord'); aussen = $true }
    @{ n = '23 keine md-Datei';                 erw = 'still';   fm = @('titel: Reise: Nord'); endung = '.txt' }
    @{ n = '24 Umlaut im Dateinamen';           erw = 'block';   fm = @('titel: Reise: Nord'); name = "Pr${ue}fung"; text = "Pr${ue}fung.md" }
    @{ n = '25 Tabulator zur Einrueckung';      erw = 'block';   fm = @('mitbringen:', "`t- Zelt") }
)

$ok = 0; $i = 0
Write-Output "Interpreter: $Exe"
try {
    foreach ($f in $faelle) {
        $i++
        $endung = if ($f.endung) { $f.endung } else { '.md' }
        $ordner = if ($f.aussen) { $aussen } else { $tmp }
        $name = if ($f.name) { $f.name } else { "fall$i" }
        $datei = Join-Path $ordner ($name + $endung)
        $text = '---' + "`n" + ($f.fm -join "`n") + "`n" + $(if ($f.offen) { '' } else { "---`n" }) + "`n# Inhalt`n"
        [IO.File]::WriteAllText($datei, $text, $utf8)
        $ein = @{ tool_name = 'Edit'; tool_input = @{ file_path = $datei } } | ConvertTo-Json -Compress
        $env:CLAUDE_PROJECT_DIR = $tmp
        $ErrorActionPreference = 'Continue'
        $aus = ($ein | & $Exe -NoProfile -ExecutionPolicy Bypass -File $hook) -join ''
        $ErrorActionPreference = 'Stop'
        $ist = if (-not $aus) { 'still' } elseif ($aus -match '"decision":\s*"block"') { 'block' } elseif ($aus -match 'additionalContext') { 'hinweis' } else { 'unbekannt' }
        $gut = $ist -eq $f.erw
        if ($gut -and $f.text -and -not $aus.Contains($f.text)) { $gut = $false; $ist = "$ist ohne '$($f.text)'" }
        if ($gut) { $ok++ }
        '{0,-36} {1,-8} {2,-8} {3}' -f $f.n, $f.erw, $ist, $(if ($gut) { 'ok' } else { "FEHLER $aus" })
        Remove-Item -LiteralPath $datei -Force
    }
} finally {
    Remove-Item -LiteralPath $tmp, $aussen -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:\CLAUDE_PROJECT_DIR -ErrorAction SilentlyContinue
}
''
if ($ok -eq $faelle.Count) { "ALLE $ok FAELLE BESTANDEN"; exit 0 } else { "$ok von $($faelle.Count) bestanden"; exit 1 }
