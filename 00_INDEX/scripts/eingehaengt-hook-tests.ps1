# Regressionsreihe fuer den Sperrbegriff-Hook, das Einrichtungsskript und den Ausschluss eingehaengter Repos
# (seit Leo Core 4.5, Skill leo-repo-einhaengen). Pflicht vor und nach jeder Aenderung an einem der drei.
# Baut in einem Arbeitsordner ein falsches aeusseres Repo mit einem eingehaengten inneren Repo und prueft: Einrichtung,
# sauberer Commit, Treffer im Inhalt, im Dateinamen, in Autor-Adresse und Commit-Nachricht, Wortanfang, Umlaut-Begriff,
# Bestand wird nicht neu geprueft, fehlende Liste blockiert, Liste mit CRLF und Backslash, Zeile mit "++" am Anfang,
# Latin-1-Datei, Dateiname mit Leerzeichen und Umlaut, commit -a, Binaerdatei, Push mit umgangenem Commit in der Historie,
# fremder Hook, schon versionierter Ordner.
# Aufruf:  pwsh -File 00_INDEX\scripts\eingehaengt-hook-tests.ps1 [-Arbeit <Ordner>]    (Standard: Temp; nur unter pwsh, weil
#          PowerShell 5.1 die Fehlerausgabe von git bei ErrorActionPreference Stop als Abbruch wertet)
# Die Reihe nutzt die Begriffe der Keimdatei (Lohnabrechnung, Arztbericht, Kuendigungsgrund). Hast du sie aus
# deiner Liste entfernt, setzt du fuer den Lauf LEO_WISSENSREPO_SPERRBEGRIFFE auf eine Kopie der Keimdatei.
# ASCII-only mit Absicht: Ein .ps1 mit Umlauten in Strings braucht ein BOM, sonst liest PowerShell 5.1 falsch.
param([string]$Arbeit = $env:TEMP)
$ErrorActionPreference = 'Stop'
$ein = Join-Path $PSScriptRoot 'eingehaengtes-repo-einrichten.ps1'
$base = Join-Path $Arbeit ('hooktest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$outer = Join-Path $base 'aussen'; $inner = Join-Path $outer 'wissen'
New-Item -ItemType Directory -Force -Path $inner | Out-Null
$g = @('-c', 'user.name=Test', '-c', 'user.email=test@example.org', '-c', 'commit.gpgsign=false')
git -C $outer init -q; git -C $inner init -q
[IO.File]::WriteAllText((Join-Path $outer 'start.md'), "x`n"); git -C $outer add start.md; git -C $outer @g commit -q -m init

$fehler = 0
function Check($name, $ok) { if ($ok) { Write-Host "  ok   $name" } else { Write-Host "  FEHLT $name"; $script:fehler++ } }
function Versuch($datei, $text) {
    [IO.File]::WriteAllText((Join-Path $inner $datei), $text, (New-Object Text.UTF8Encoding $false))
    git -C $inner add -- $datei
    $out = git -C $inner @g commit -q -m "t" 2>&1
    return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}

Write-Host "Einrichtung"
& $ein -Ordner 'wissen' -Email 'test@example.org' -Name 'Test' -Leo $outer | Out-Null
Check 'aeusseres .gitignore traegt den Ordner' ((Get-Content (Join-Path $outer '.gitignore') -Raw) -match '/wissen/')
Check '.ignore gibt den Ordner fuer die Suche frei' ((Get-Content (Join-Path $outer '.ignore')) -contains '!/wissen/')
Check 'Stub liegt im inneren Repo' (Test-Path (Join-Path $inner '.git\hooks\pre-commit'))
$stubBytes = [IO.File]::ReadAllBytes((Join-Path $inner '.git\hooks\pre-commit'))
Check 'Stub ohne BOM und ohne CR' (($stubBytes[0] -eq 0x23) -and ($stubBytes -notcontains 0x0D))
Check 'aeusseres Repo sieht den inneren Ordner nicht' (-not (git -C $outer status --porcelain --untracked-files=all | Where-Object { $_ -match 'wissen' }))
& $ein -Ordner 'wissen' -Email 'test@example.org' -Leo $outer | Out-Null
Check 'zweiter Lauf ist idempotent (.gitignore und .ignore nur einmal)' ((([regex]::Matches((Get-Content (Join-Path $outer '.gitignore') -Raw), '/wissen/')).Count -eq 1) -and (([regex]::Matches((Get-Content (Join-Path $outer '.ignore') -Raw), '!/wissen/')).Count -eq 1))
[IO.File]::WriteAllText((Join-Path $inner 'link.md'), "[gut](link.md) [tot](fehlt.md) [extern](https://example.org) [anker](#x)`n")
$toteLinks = @(& { . (Join-Path $PSScriptRoot 'lib\eingehaengt-ausschluss.ps1'); Get-EingehaengtToteLinks $inner })
Check 'tote Links: genau der fehlende Verweis wird gemeldet' (($toteLinks.Count -eq 1) -and ($toteLinks[0] -match 'fehlt\.md'))
Remove-Item (Join-Path $inner 'link.md')

. (Join-Path $PSScriptRoot 'lib\eingehaengt-ausschluss.ps1')
$EingehaengteOrdner = @(Get-EingehaengteOrdner $outer)
Check 'Ausschluss: eingehaengter Ordner wird gefunden' (($EingehaengteOrdner.Count -eq 1) -and ($EingehaengteOrdner[0] -eq $inner))
Check 'Ausschluss: Datei im eingehaengten Ordner ausgeschlossen, Datei ausserhalb nicht' ((Test-EingehaengtPfad (Join-Path $inner 'a.md')) -and -not (Test-EingehaengtPfad (Join-Path $outer 'start.md')))
Check 'Ausschluss: Ordner mit gleichem Namensanfang wird nicht mit ausgeschlossen' (-not (Test-EingehaengtPfad ($inner + '-anders\a.md')))

Write-Host "Hook, Keimdatei"
$r = Versuch 'prozess.md' "# Ablauf`nDer Benutzer wird angelegt, die Gesamtlohnabrechnung ist kein Wortanfang.`n"
Check 'sauberer Text wird committet (Treffer mitten im Wort zaehlt nicht)' ($r.Code -eq 0)
$r = Versuch 'a.md' "Die Lohnabrechnung von Mai liegt bei.`n"
Check 'Begriff im Inhalt blockiert' (($r.Code -ne 0) -and ($r.Out -match 'Lohnabrechnung'))
git -C $inner reset -q
$r = Versuch 'Arztbericht Mai.md' "Neutraler Inhalt.`n"
Check 'Begriff im Dateinamen blockiert' (($r.Code -ne 0) -and ($r.Out -match 'Dateiname'))
git -C $inner reset -q
$r = Versuch 'b.md' ("Der K" + [char]0xFC + "ndigungsgrund steht fest.`n")
Check 'Umlaut-Begriff im Inhalt blockiert' ($r.Code -ne 0)
git -C $inner reset -q

Write-Host "Hook, eigene Liste und Randfaelle"
$kl = Join-Path $base 'liste.txt'
[IO.File]::WriteAllText($kl, "# Test`nGeheimwort`n", (New-Object Text.UTF8Encoding $false))
$env:LEO_WISSENSREPO_SPERRBEGRIFFE = $kl
$r = Versuch 'e.md' "Hier steht GEHEIMWORT gross.`n"
Check 'Gross-/Kleinschreibung egal' ($r.Code -ne 0)
git -C $inner reset -q
$r = Versuch 'f.md' "Das Mehrgeheimwort ist kein Wortanfang.`n"
Check 'Treffer mitten im Wort zaehlt nicht' ($r.Code -eq 0)
[IO.File]::WriteAllText((Join-Path $inner 'g.md'), "Geheimwort`n"); git -C $inner add g.md; git -C $inner @g commit -q --no-verify -m bestand
$r = Versuch 'g.md' "Geheimwort`nneue harmlose Zeile`n"
Check 'Bestand wird nicht neu geprueft, nur die neue Zeile' ($r.Code -eq 0)
[IO.File]::WriteAllBytes($kl, (New-Object Text.UTF8Encoding $false).GetBytes("# Test`r`nGeheimwort`r`nD:\Privat`r`n"))
$r = Versuch 'i.md' "Pfad D:\Privat\x`n"
Check 'Liste mit CRLF, Begriff mit Backslash' ($r.Code -ne 0)
git -C $inner reset -q
$r = Versuch 'j.md' "++ Geheimwort am Zeilenanfang`n"
Check 'Inhaltszeile mit ++ am Anfang wird geprueft' ($r.Code -ne 0)
git -C $inner reset -q
[IO.File]::WriteAllBytes((Join-Path $inner 'k.md'), [Text.Encoding]::GetEncoding(28591).GetBytes("Gr" + [char]0xF6 + "sse und Geheimwort`n"))
git -C $inner add k.md; $out = git -C $inner @g commit -q -m t 2>&1
Check 'Latin-1-Datei wird geprueft (grep -a)' ($LASTEXITCODE -ne 0)
git -C $inner reset -q
$fn = 'Notiz ' + [char]0xFC + ' Geheimwort.md'
$r = Versuch $fn "Neutral.`n"
Check 'Dateiname mit Leerzeichen und Umlaut' (($r.Code -ne 0) -and ($r.Out -match 'Dateiname'))
git -C $inner reset -q
[IO.File]::WriteAllText((Join-Path $inner 'g.md'), "Geheimwort`nGeheimwort neu`n")
$out = git -C $inner @g commit -q -a -m t 2>&1
Check 'git commit -a wird geprueft' ($LASTEXITCODE -ne 0)
git -C $inner checkout -q -- g.md
$env:LEO_WISSENSREPO_SPERRBEGRIFFE = Join-Path $base 'gibt-es-nicht.txt'
$r = Versuch 'h.md' "Harmlos.`n"
Check 'fehlende Liste blockiert den Commit' (($r.Code -ne 0) -and ($r.Out -match 'nicht gefunden'))
Remove-Item Env:LEO_WISSENSREPO_SPERRBEGRIFFE

Write-Host "Identitaet, Nachricht, Binaer, Push"
Check 'drei Stubs liegen im inneren Repo' ((Test-Path (Join-Path $inner '.git\hooks\commit-msg')) -and (Test-Path (Join-Path $inner '.git\hooks\pre-push')))
Check 'lokale Identitaet gesetzt' ((git -C $inner config --local user.email) -eq 'test@example.org')
# Testliste: example.net steht fuer einen privaten Mailanbieter (echte Anbieter stehen in der Keimdatei).
$pl = Join-Path $base 'privat.txt'
[IO.File]::WriteAllText($pl, "# Test`nexample.net`nLohnabrechnung`n", (New-Object Text.UTF8Encoding $false))
$env:LEO_WISSENSREPO_SPERRBEGRIFFE = $pl
$priv = ''; try { & $ein -Ordner 'wissen' -Email 'privat@example.net' -Leo $outer *>&1 | Out-Null } catch { $priv = "$_" }
Check 'private Mailadresse wird beim Einrichten abgelehnt' ($priv -match 'Sperrliste')
[IO.File]::WriteAllText((Join-Path $inner 'm.md'), "Harmlos.`n"); git -C $inner add m.md
$out = git -C $inner -c user.name=T -c user.email=person@example.net -c commit.gpgsign=false commit -q -m t 2>&1
Check 'private Autoradresse blockiert den Commit' (($LASTEXITCODE -ne 0) -and ("$out" -match 'Autor'))
$out = git -C $inner @g commit -q -m "Notiz zur Lohnabrechnung" 2>&1
Check 'Sperrbegriff in der Commit-Nachricht blockiert' (($LASTEXITCODE -ne 0) -and ("$out" -match 'Nachricht'))
$out = git -C $inner @g commit -q -m "Harmloser Titel" 2>&1
Check 'harmlose Nachricht und Autor passieren' ($LASTEXITCODE -eq 0)
[IO.File]::WriteAllBytes((Join-Path $inner 'bild.png'), [byte[]](0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A,0x00,0x00,0x00,0x0D)); git -C $inner add bild.png
$out = git -C $inner @g commit -q -m "Bild" 2>&1
Check 'Binaerdatei blockiert' (($LASTEXITCODE -ne 0) -and ("$out" -match 'Binaer'))
$env:LEO_BINAER_GEPRUEFT = '1'; $out = git -C $inner @g commit -q -m "Bild" 2>&1; $okb = $LASTEXITCODE
Check 'Binaerdatei nach Bestaetigung durch eine Person erlaubt' ($okb -eq 0)
$bare = Join-Path $base 'remote.git'; git init -q --bare $bare; git -C $inner remote add origin $bare
$out = git -C $inner push -q origin HEAD:refs/heads/main 2>&1
Check 'sauberer erster Push (ganze Historie, Binaerdatei bestaetigt) geht durch' ($LASTEXITCODE -eq 0)
Remove-Item Env:LEO_BINAER_GEPRUEFT
[IO.File]::WriteAllText((Join-Path $inner 'n.md'), "Lohnabrechnung im Text`n"); git -C $inner add n.md; git -C $inner @g commit -q --no-verify -m "umgangen"
[IO.File]::WriteAllText((Join-Path $inner 'n.md'), "bereinigt`n"); git -C $inner add n.md; git -C $inner @g commit -q --no-verify -m "bereinigt"
$out = git -C $inner push -q origin HEAD:refs/heads/main 2>&1
Check 'Push blockiert, wenn die Historie einen Sperrbegriff nur als entfernte Zeile traegt (--no-verify umgangen)' (($LASTEXITCODE -ne 0) -and ("$out" -match 'blockiert'))
Remove-Item Env:LEO_WISSENSREPO_SPERRBEGRIFFE

Write-Host "Einrichtung, Abbrueche"
$stub = Join-Path $inner '.git\hooks\pre-commit'
[IO.File]::WriteAllText($stub, "#!/bin/sh`necho fremd`n")
$abbruch = $false; try { & $ein -Ordner 'wissen' -Email 'test@example.org' -Leo $outer *>&1 | Out-Null } catch { $abbruch = $true }
Check 'fremder pre-commit-Hook wird nicht ueberschrieben' ($abbruch -and ((Get-Content -Raw $stub) -match 'fremd'))
$vers = Join-Path $outer 'versioniert'; New-Item -ItemType Directory -Force -Path $vers | Out-Null
[IO.File]::WriteAllText((Join-Path $vers 'a.md'), "a`n"); git -C $outer add versioniert/a.md; git -C $outer @g commit -q -m v; git -C $vers init -q
$meldung = ''; try { & $ein -Ordner 'versioniert' -Email 'test@example.org' -Name 'Test' -Leo $outer *>&1 | Out-Null } catch { $meldung = "$_" }
Check 'schon versionierter Ordner: Abbruch mit richtiger Meldung, .gitignore unveraendert' (($meldung -match 'versioniert') -and -not ((Get-Content (Join-Path $outer '.gitignore') -Raw) -match '/versioniert/'))

Remove-Item -Recurse -Force $base
if ($fehler -gt 0) { Write-Host "FEHLER: $fehler Pruefungen"; exit 1 }
Write-Host "Alle Pruefungen bestanden."
