---
titel: Anleitung zum eigenen Leo
zweck: Erklärt, was Leo ist, wie er funktioniert und wie man ihn einsatzbereit macht, auf einem Windows-Rechner oder nur mit einem Tablet
type: readme
version: 3.1-core
letzte_aenderung: 2026-09-03
---

# Leo: Anleitung zum eigenen Second Brain

Das hier ist ein leeres Grundgerüst. Die komplette Mechanik ist drin, aber kein einziger Inhalt: keine Themen, keine persönlichen Daten, nichts vom Autor. Du baust deinen eigenen Leo darauf.

**Zwei Lesegeschwindigkeiten.** Diese Anleitung soll für jemanden funktionieren, der noch nie mit einem KI-Agenten gearbeitet hat, ohne dass ein erfahrener Leser ständig Selbstverständliches liest. Deshalb gilt durchgehend:

> **Grundlagen:** So markierte Kästen erklären einen Begriff oder einen Handgriff von Grund auf. Wenn dir Kommandozeile, Git und LLM-Werkzeuge vertraut sind, überspring sie einfach, im Fliesstext geht nichts verloren.

---

## Teil 1: Was Leo ist und wofür

Leo ist ein persönliches, dauerhaftes Wissenssystem, ein "Second Brain". Der Kern ist eine einfache Idee: Alles Wissen liegt als Markdown-Dateien in einem Ordner, thematisch sortiert, und ein LLM greift darauf zu, wenn du eine passende Frage stellst. Das System ist Gedächtnis und Arbeitsplatz zugleich. Du legst ab, was du erarbeitest, und vertraust darauf, dass es zuverlässig wiedergefunden und aktiv genutzt wird.

> **Grundlagen:** Ein LLM ist das Sprachmodell hinter Programmen wie Claude oder Gemini. Markdown ist reiner Text mit ein paar Zeichen für Struktur (`#` für eine Überschrift, `-` für einen Listenpunkt). Solche Dateien lassen sich mit jedem Programm öffnen und sind auch in zehn Jahren noch lesbar.

Drei Dinge machen Leo aus:

1. **Die Dateien sind die Wahrheit, nicht das Tool.** Kein Chatverlauf, kein tool-eigenes Gedächtnis, keine Vektor-Datenbank. Nur Markdown. Das heisst: Du kannst das LLM und das Programm jederzeit wechseln, ohne einen einzigen Gedanken zu verlieren. Kein Lock-in.
2. **Das System hält sich selbst sauber und aktuell.** Ein Index (die Landkarte) und die Versionierung laufen im Hintergrund. Du pflegst fast nichts von Hand.
3. **Wahrheit vor Bequemlichkeit.** Die oberste Regel ist Anti-Halluzination: Es kommt nur ins Wissen, was belegbar ist. Ein LLM, das Quellen erfindet, vergiftet mit der Zeit die ganze Wissensbasis. Genau das verhindert Leo strukturell.

Was du davon hast: Du fragst in normaler Sprache und bekommst Antworten, die auf deinem eigenen abgelegten Wissen aufbauen, im richtigen Ton, in deiner Rolle (mal Sparringpartner, mal Lektor, mal was immer du definierst). Und mit jeder Session, die du sauber abschliesst, wird das System klüger.

---

## Teil 2: Wie Leo funktioniert

Sechs Bausteine, die ineinandergreifen:

**Die Ablage.** Ein Ordner (empfohlen `C:\Leo`) mit einer festen Struktur. Systemordner mit vorangestellten Nummern (`00_INDEX`, `01_Basiskontext`, `02_Skills`, `03_Sessionlogs`, `04_Changelog`, `10_System`) und Themenordner ab Nummer 20 (`20_...`, `21_...`), die du selbst anlegst. `90_Inbox` ist die Rohablage für noch nicht Einsortiertes.

**Die Anweisung (AGENTS.md).** Im Wurzelordner liegt `AGENTS.md`, die einzige Quelle der Wahrheit für alle Arbeitsregeln. Jedes LLM liest sie zu Beginn und weiss dann, wie es arbeiten soll: wie es sucht, wie es ablegt, was es nie tun darf. Coding-Agents und Claude-Produkte laden diese Datei automatisch. Reine Chat-Programme brauchen einen einzigen Satz als Systemprompt, der auf sie zeigt. Änderst du eine Regel, änderst du genau eine Datei.

**Die Rollen.** Jeder Themenordner trägt eine eigene kleine `AGENTS.md` mit einer Rollen-Definition ("Business-Sparringpartner", "Gesundheitsberater", was du willst). Das LLM erkennt aus deiner Frage selbst, welches Thema betroffen ist, und nimmt die passende Rolle ein. Im leeren Kern gibt es noch keine Themen, also noch keine Rollen.

**Der Zugriff (Agentic Search).** Statt einer Vektor-Datenbank sucht das LLM selbst: Es liest zuerst den Index (die Landkarte), dann durchsucht es den Volltext mit selbst erzeugten Synonymen, dann liest es nur die Treffer ganz. Das ist günstig (eine normale Frage kostet Cents), verliert keinen Zusammenhang und funktioniert mit jedem Tool.

**Der Index.** Eine zweistufige Landkarte. Die mechanischen Teile (Ordnerbaum, Dateilisten) pflegt ein Skript vollautomatisch und kann dabei nichts erfinden. Die beschreibenden Teile schreibt das LLM, aber immer nur zu je einer real existierenden Datei. So bleibt der Index vollständig und aktuell, ohne je zu halluzinieren.

**Die Skills.** Wiederkehrende Arbeitsabläufe stehen als Markdown-Dateien in `02_Skills`, auffindbar über das `Skill-Register.md`. Du nennst ein Triggerwort ("wrap up", "health check"), das LLM schlägt nach und führt den Ablauf aus; seit 2.1 schlägt es passende Skills auch von selbst vor, wenn die Situation danach verlangt. Kern- und Arbeits-Skills sind dabei (siehe Teil 3).

Darunter liegt Git plus ein privates GitHub-Repo als Sicherheitsnetz: Jede Änderung ist rückrollbar. Das ist wichtig, weil viele Tools ohne Rückfrage in Dateien schreiben. Die Sicherheit kommt nicht aus Bestätigungsklicks, sondern daraus, dass du jederzeit zurückspringen kannst.

> **Grundlagen: Git und GitHub.** Git ist eine Art Zeitmaschine für einen Ordner. Es merkt sich jeden Zwischenstand, so dass du jederzeit sehen kannst, was sich wann geändert hat, und einen alten Stand zurückholen kannst. GitHub ist der Online-Dienst, auf dem diese Zeitmaschine zusätzlich gespeichert wird, also gleichzeitig dein Backup. Ein GitHub-Konto ist kostenlos, und dein Bereich ("Repository", kurz Repo) ist privat, wenn du ihn so anlegst. Niemand ausser dir sieht ihn. Du musst dafür nichts über Git lernen: Der Agent bedient es für dich, und im Notfall reicht die Weboberfläche von GitHub.

---

## Teil 3: Was in Leo Core steckt (und was nicht)

**Drin ist das komplette Rohgerüst:**

- Die Master-`AGENTS.md` mit allen Arbeitsregeln, entpersonalisiert.
- Die vollständige Ordnerstruktur mit READMEs.
- Der Index (`00_INDEX`) mit den PowerShell-Skripten: `build-index-geruest.ps1` (baut die Landkarte), `health-check.ps1` (prüft das ganze System durch, von Git über Index-Abdeckung und tote Verweise bis zum Frontmatter-Standard), `build-skill-wrapper.ps1` (legt die Skill-Zeiger für alle Werkzeuge an) und `guard-workspace.ps1` (die Arbeitsbereich-Sperre, siehe unten).
- Ein Pre-Commit-Hook (`00_INDEX\githooks`), der Commits mit beschädigtem Inhalt stoppt: Merge-Konflikt-Marker oder ein zerrissener Auto-Block in einer Indexdatei. Alles andere zeigt er nur an, damit ein automatisches Backup nie still scheitert. Einmalig zu aktivieren, siehe Teil 5, Schritt 3.
- Kern-Skills: **Health-Check** (Wartung auf Knopfdruck), **Wrap-Up** (Session sichern und daraus lernen), **Themenordner anlegen**, **Skill-Ersteller** (damit baust du dir weitere Skills selbst), **Mechanik-Update** und **System-Optimierung**.
- Eine Arbeitsbereich-Sperre: Dein Agent darf ausschliesslich in seinem eigenen Repo schreiben. Lesen ausserhalb bleibt frei, aber jede Änderung ausserhalb braucht deine ausdrückliche Erlaubnis, unabhängig davon, wie weit du die Berechtigungen gestellt hast. Im Repo ist alles über Git rückrollbar, ausserhalb nicht, und genau das ist der Unterschied. Durchgesetzt wird das technisch über einen Hook, nicht nur als Regel im Text.
- Der Basiskontext (`01_Basiskontext`) als Vorlagen mit Leitfragen: Voice and Style, Identity, Persönlichkeit und Muster.
- Die Systemdoku (`10_System`): Zielsetzung, Architektur, Technik, Manual, Modellwahl.
- Die Portabilitätsdateien (`CLAUDE.md`, `GEMINI.md`, `.clinerules`), die jedes Harness auf die `AGENTS.md` zeigen lassen. `CLAUDE.md` und `GEMINI.md` importieren den Basiskontext zusätzlich per `@`-Zeile, damit er zwingend geladen wird und nicht nur empfohlen ist.

**Bewusst nicht drin:**

- **Keine Inhalte.** Kein Themenordner, keine persönlichen Daten. Der Basiskontext ist leer und wartet auf dich.
- **Kern-Skills plus vier Arbeits-Skills** (seit 2.3): **Voice-Check** (prüft ausgehende Texte gegen deine Stil-Datei), **Faktencheck** (prüft Behauptungen gegen echte Quellen), **Notiz** (verankert offene Punkte mit Wiedervorlage) und **First Principles** (denkt Prozesse von Grund auf neu). Sie springen von selbst an, wenn ihre Situation eintritt. Weitere Skills (z.B. ein Inbox-Ingest) baust du dir bei Bedarf selbst über den Skill-Ersteller ("skill erstellen").

---

## Teil 4: Welcher Weg passt zu dir

Es gibt zwei Wege, und sie unterscheiden sich darin, wo der Ordner liegt und wo der Agent arbeitet.

**Weg A: eigener Windows-Rechner.** Der Ordner liegt lokal auf deiner Festplatte, der Agent arbeitet direkt darauf. Alles funktioniert, inklusive der beiden Skripte, der täglichen Automatik und Obsidian zum Bearbeiten von Hand. Das ist der Weg ohne Reibung. Weiter mit Teil 5.

**Weg B: kein eigener Rechner, nur Tablet.** Der Ordner liegt bei GitHub, und der Agent arbeitet in einer Sitzung auf den Servern von Anthropic. Du installierst nichts und brauchst keine Kommandozeile. Der Kern von Leo funktioniert damit, die Automatik-Schicht nicht. Weiter mit Teil 6.

Wichtig für beide Wege: Leg den Ordner niemals in einen Cloud-Sync-Dienst wie OneDrive, Dropbox oder iCloud Drive. Solche Dienste kopieren Dateien laufend im Hintergrund hin und her und geraten sich dabei mit Git in die Quere. Die Cloud-Kopie ist GitHub, und die reicht.

---

## Teil 5: Weg A, Einrichtung Schritt für Schritt (Windows)

> **Grundlagen: Kommandozeile.** Die Blöcke mit grauem Hintergrund unten sind Befehle. Du öffnest dafür das Programm "PowerShell" (Startmenü, tippen: PowerShell), kopierst den Befehl hinein und drückst Enter. Mehr ist es nicht. Wenn ein Befehl eine Fehlermeldung ausgibt, lies sie nicht weg, sondern gib sie deinem Agenten, der ordnet sie dir ein.

### Schritt 0: Von Null zum laufenden Agenten

Wenn du noch nie mit einem Agenten gearbeitet hast, fängst du hier an. Fünf Schritte, zusammen etwa eine halbe Stunde, davon das meiste Warten auf Downloads.

**0.1 Claude-Abo.** Claude Code braucht ein bezahltes Abo (Pro, Max, Team oder Enterprise). Anlegen auf https://claude.ai. Ohne Abo öffnet sich der Code-Bereich später nicht.

**0.2 GitHub-Konto.** Kostenlos auf https://github.com. GitHub ist der Ort, an dem dein Wissen zusätzlich gesichert liegt, und der Ort, von dem du das Grundgerüst holst. Merk dir deinen Benutzernamen, du brauchst ihn gleich.

**0.3 Deine eigene Kopie des Kerns erzeugen.** Öffne https://github.com/flomeile/leo-core. Oben rechts ist ein grüner Knopf **"Use this template"**, darunter wählst du **"Create a new repository"**. Auf der folgenden Seite:

- **Repository name:** `leo` (oder wie du dein System nennen willst)
- **Private** auswählen, nicht Public. Hier landet dein persönliches Wissen.
- Knopf **"Create repository"**

Du hast damit dein eigenes, unabhängiges Repo mit dem kompletten Gerüst darin. Die Adresse lautet `https://github.com/<deinbenutzername>/leo`.

**0.4 Git installieren.** Herunterladen von https://git-scm.com/downloads/win und installieren. Bei allen Fragen im Installationsprogramm die Voreinstellung übernehmen. Claude Code braucht Git auf Windows zwingend, sonst startet keine lokale Sitzung. (Auf einem Mac ist Git meistens schon vorhanden.)

**0.5 Claude Desktop installieren.** Die Download-Knöpfe für Windows und macOS stehen auf https://code.claude.com/docs/en/desktop-quickstart. Installieren, starten und mit deinem Konto aus 0.1 anmelden. Falls du Git erst danach installiert hast: Claude einmal beenden und neu starten.

### Schritt 1: Das Repo auf deinen Rechner holen

Öffne PowerShell und führe diesen Befehl aus, mit deinem GitHub-Benutzernamen anstelle von `<deinbenutzername>`:

```powershell
git clone https://github.com/<deinbenutzername>/leo.git C:\Leo
```

Beim ersten Mal öffnet sich ein Fenster, in dem du dich bei GitHub anmeldest. Das passiert genau einmal, danach merkt sich Git die Anmeldung.

Der Pfad `C:\Leo` ist an vielen Stellen in den Skills als Beispiel eingetragen; wenn du ihn beibehältst, hast du am wenigsten Arbeit.

### Schritt 1b: Den Agenten auf den Ordner zeigen

In Claude Desktop oben auf den Reiter **Code**. Dann:

1. Als Umgebung **Local** wählen (nicht Cloud), damit der Agent direkt auf deinen Dateien arbeitet.
2. Auf **Select folder** klicken und `C:\Leo` auswählen.
3. Ein Modell wählen, für den Anfang das leistungsfähigste in der Liste.
4. Als erste Nachricht schreiben: **"Lies die ANLEITUNG.md und richte mich ein."**

Ab hier führt dich der Agent durch den Rest. Er schlägt jede Änderung vor und wartet auf dein Ja, bis du ihm mehr Freiheit gibst. Die Schritte 2 bis 5 unten macht er für dich; lies sie trotzdem einmal quer, damit du weisst, was in deinem System passiert.

### Schritt 2: Personalisieren
- Öffne `MEIN-SYSTEM.md` im Wurzelordner und fülle Abschnitt 1 aus: deinen Namen, wie das System bei dir heisst, wo es liegt, dein Kürzel. **Die `AGENTS.md` fasst du dabei nicht an.** Sie enthält den Platzhalter `[NAME]` und die Bezeichnungen `Leo` und `C:\Leo` bewusst als generische Begriffe; dein Agent löst sie über `MEIN-SYSTEM.md` auf. Genau dadurch bleibt die `AGENTS.md` bei allen Nutzern identisch und lässt sich später gefahrlos aktualisieren (Teil 8).
- Fülle die drei Dateien in `01_Basiskontext`. Sie enthalten Leitfragen. Das ist der wertvollste Schritt: Je ehrlicher und konkreter, desto besser trifft das LLM später deinen Kern. `Voice and Style.md` bringt schon eine fertige Liste typischer KI-Sprachmuster mit, die du übernehmen oder löschen kannst.
- Optional den Namen ändern: siehe Teil 7.

> **Grundlagen:** Du musst Schritt 2 nicht von Hand machen. Öffne stattdessen deinen Agenten auf dem Ordner und sag ihm: "Lies die ANLEITUNG.md und richte mich ein." Er füllt `MEIN-SYSTEM.md` aus und führt dich per Rückfragen durch den Basiskontext. Das ist ohnehin der bessere Weg, weil aus dem Gespräch mehr herauskommt als aus einem leeren Formular.

### Schritt 3: Git und privates GitHub-Repo
Bist du über Schritt 0 gekommen, ist das alles schon erledigt: Das Repo existiert, ist privat und mit deinem lokalen Ordner verbunden. Weiter mit dem Hook am Ende dieses Schritts. Hast du das Paket anders geholt (ZIP-Download, Kopie von jemandem), richtest du Git von Hand ein:

```powershell
cd C:\Leo
git init
git add .
git commit -m "Leo Core"
```
Dann auf GitHub ein **privates** Repo anlegen (Weboberfläche oder `gh repo create`), und lokal verbinden:
```powershell
git remote add origin https://github.com/<deinkonto>/<deinrepo>.git
git branch -M main
git push -u origin main
```
Privat ist wichtig: Hier landet dein persönliches Wissen.

**Drei Minuten Datenschutz, jetzt und nicht später.** Dein Agent liest dieses Repo vollständig, also gilt alles, was du in deinem Anbieterkonto eingestellt hast, für deinen gesamten Inhalt.

1. **Nutzung deiner Eingaben zur Modellverbesserung abschalten.** Bei Anthropic heisst der Schalter "Help improve Claude" und liegt unter [claude.ai/settings/data-privacy-controls](https://claude.ai/settings/data-privacy-controls). In den Privatplänen (Free, Pro, Max) ist er standardmässig an, und er schliesst Coding-Sitzungen ausdrücklich ein; mit ihm hängt die Aufbewahrungsdauer zusammen. Bei jedem anderen Anbieter, den du auf dieses Repo lässt, dasselbe suchen und abschalten.
2. **Festplatte verschlüsseln.** Dein Agent legt vollständige Gesprächsprotokolle als Klartext ausserhalb dieses Repos ab, unter Windows in `%USERPROFILE%\.claude\projects`. Das wächst schnell in den dreistelligen Megabyte-Bereich. Prüfen mit `manage-bde -status C:` in einer PowerShell mit Administratorrechten.
3. **Geschäftliche Daten sind kein Privatthema.** Legst du Personen-, Kunden- oder Vertragsdaten deines Arbeitgebers hier ab, entscheidet nicht mehr dein Geschmack, sondern der Vertrag zwischen deinem Arbeitgeber und dem Anbieter. Privatpläne laufen bei den grossen Anbietern unter Konsumentenbedingungen, zu denen es keinen Auftragsbearbeitungsvertrag gibt. Kläre das mit deinem Arbeitgeber, bevor solche Daten hier landen.

Danach den mitgelieferten Pre-Commit-Hook aktivieren:
```powershell
git config core.hooksPath 00_INDEX/githooks
```
Der Hook liegt versioniert im Paket, diese Einstellung nicht: Sie gilt pro Rechner und muss nach jedem frischen Clone einmal gesetzt werden (der Health-Check erinnert dich daran). Er blockiert einen Commit nur, wenn der gestagete Inhalt beschädigt ist: Merge-Konflikt-Marker in einer Markdown-Datei oder ein zerrissener Auto-Block in einer Indexdatei. Alles andere zeigt er nur an. Willst du einen blockierten Commit bewusst trotzdem durchdrücken: `git commit --no-verify`.

### Schritt 4: Index zum ersten Mal bauen
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Leo\00_INDEX\scripts\build-index-geruest.ps1"
```
(Hast du kein `pwsh`, nimm `powershell` statt `pwsh`.) Das Skript füllt den Ordnerbaum und legt `INDEX-Geruest.md` an. Es darf beim ersten Lauf noch keine Themenordner finden, das ist korrekt.

### Schritt 5: System durchchecken
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Leo\00_INDEX\scripts\health-check.ps1"
```
Der Check ist rein lesend. Erwartetes Ergebnis im frischen Kern: "einsatzbereit mit Hinweisen". Die Punkte, die du sehen wirst, betreffen den noch fehlenden Scheduled Task (kommt in Schritt 6) und den noch fehlenden Themenordner. Beides ist normal. Meldet der Check dagegen `[FAIL] core.hooksPath ist NICHT gesetzt`, hast du den Hook-Befehl aus Schritt 3 übersprungen; hol ihn nach.

### Schritt 6: Täglichen Automatik-Lauf einrichten
Der Windows Task Scheduler soll einmal täglich das Index-Skript laufen lassen und danach committen und pushen. Am einfachsten in einer PowerShell-Sitzung, alle Zeilen zusammen einfügen:
```powershell
# Voller Pfad zu pwsh.exe: Der Task Scheduler laedt den Benutzer-PATH nicht
# zuverlaessig, und bei einer Installation aus dem Microsoft Store liegt pwsh.exe
# NUR im Benutzer-PATH. Mit blossem "pwsh.exe" wird der Task sauber angelegt und
# scheitert dann bei jedem Lauf mit 0x80070002 (Datei nicht gefunden).
$pwsh = (Get-Command pwsh.exe).Source
$action = New-ScheduledTaskAction -Execute $pwsh -WorkingDirectory "C:\Leo" -Argument '-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command "& ''C:\Leo\00_INDEX\scripts\build-index-geruest.ps1''; cd C:\Leo; git add ''00_INDEX/INDEX-Geruest.md'' ''00_INDEX/INDEX.md'' ''AGENTS.md'' ''*/_INDEX.md''; git diff --cached --quiet; if ($LASTEXITCODE -ne 0) { git commit -m ''Automatischer Index-Sync''; git push }"'
$trigger = New-ScheduledTaskTrigger -Daily -At 16:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable
Register-ScheduledTask -TaskName "Leo Index aktualisieren und Git Push" -Action $action -Trigger $trigger -Settings $settings -Description "Taeglicher Leo Index-Sync"
```
Der Befehl registriert bewusst beides in einem: den Index-Lauf UND das anschliessende Commit-und-Push der Index-Dateien (nur diese Pfade, nie `git add -A`). Eine frühere Fassung dieser Anleitung registrierte nur das Index-Skript; wer sie wörtlich befolgte, hatte eine Indexpflege und keine Sicherung, glaubte aber, gesichert zu sein. `-StartWhenAvailable` holt den Lauf nach, wenn der Rechner zur Triggerzeit aus war. Damit das Pushen funktioniert, muss Git ohne Passwortabfrage pushen können (GitHub-Login über den Credential Manager einmal einrichten, indem du einmal von Hand `git push` machst). Der Task-Name darf deinen eigenen Systemnamen tragen: Der Health-Check löst ihn aus `MEIN-SYSTEM.md`, Abschnitt 1 auf und findet den Task dann. "Leo" funktioniert unverändert weiter.

**Die wöchentliche Diagnose dazu: Pflicht im Nutzungsmodus `benutzen`, empfohlen im Modus `mitbauen`** (seit 3.0; bis 2.6 war sie optional, und optional heisst, dass sie bei genau den Nutzern nicht läuft, für die sie gebaut wurde). Sie fährt jeden Montag den rein lesenden Systembefund samt Versions-Wächter; dabei entsteht die Datei `10_System\health-check-report.txt` (WARN und FAIL zuoberst), und die Tagessicherung committet sie mit. Im Modus `benutzen` liest dein Agent diese Datei zu Beginn der nächsten Sitzung und sagt dir in zwei, drei Sätzen, was drinsteht und was zu tun ist; eine Datei, in die niemand schaut, wäre keine Meldung. **Im Modus `mitbauen` liest er daraus seit 3.2 genau eine Zeile: den Versions-Rückstand des Kerns**, damit dir eine neue Version nicht entgeht, während der Rest des Berichts dir überlassen bleibt. So erfährst du auch von einer neuen Kern-Version, wenn du wochenlang keine Sitzung startest:
```powershell
$pwsh = (Get-Command pwsh.exe).Source
$action = New-ScheduledTaskAction -Execute $pwsh -WorkingDirectory "C:\Leo" -Argument '-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File "C:\Leo\00_INDEX\scripts\weekly-diagnose.ps1"'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 08:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable
Register-ScheduledTask -TaskName "Leo Wochendiagnose" -Action $action -Trigger $trigger -Settings $settings -Description "Woechentliche Leo-Diagnose in health-check-report.txt"
```

### Schritt 7: Dein LLM anbinden
- **Claude Code, Claude Desktop, Codex, Gemini CLI:** finden `AGENTS.md` bzw. `CLAUDE.md`/`GEMINI.md` automatisch, sobald sie auf `C:\Leo` zeigen. Nichts weiter zu tun.
- **Reiner Chat-Harness (ein Chat-Programm mit Datei- und Werkzeug-Zugriff):** ein Projekt auf `C:\Leo` anlegen, Datei- und PowerShell-Zugriff aktivieren (ohne PowerShell keine Volltextsuche), ein tool-fähiges Modell wählen und genau diesen einen Satz als Systemprompt setzen:
  ```
  Lies zuerst C:\Leo\AGENTS.md vollständig und befolge sie für die gesamte Session.
  ```

### Schritt 8 (optional): Obsidian
Wenn du deine Notizen auch von Hand pflegen willst: Obsidian auf `C:\Leo` als Vault öffnen. Mit dem Obsidian-Git-Plugin bekommst du zusätzlich automatische Backups und eine bequeme Datei-Historie zum Zurückrollen ohne Kommandozeile.

---

## Teil 6: Weg B, Einrichtung ohne eigenen Rechner (Tablet)

Dieser Weg kommt ohne Installation und ohne Kommandozeile aus. Der Ordner liegt bei GitHub, und der Agent arbeitet in einer Sitzung auf den Servern von Anthropic, die auch dann weiterläuft, wenn du das Gerät weglegst.

**Was du brauchst:**
- Ein bezahltes Claude-Abo. Der nötige Bereich in der App ist nicht in jedem Plan enthalten.
- Ein kostenloses GitHub-Konto (siehe den Grundlagen-Kasten in Teil 2).
- Die Claude-App. Auf dem iPad installierst du dieselbe iOS-App wie auf dem iPhone; eine eigene App für die Agenten-Funktion gibt es nicht.

**Die Schritte:**

1. GitHub-Konto anlegen, im Browser auf dem Tablet.
2. Auf der Seite des Kerns auf GitHub (https://github.com/flomeile/leo-core) den Knopf **"Use this template"** drücken und dein eigenes, **privates** Repo erstellen. Damit hast du deine eigene Kopie, unabhängig vom Original; die Verbindung für Updates stellt dein Agent in der ersten Sitzung her (Teil 8).
3. In der Claude-App unten auf **Code** tippen, dein Repo auswählen und eine Sitzung starten.
4. Als erste Nachricht schreiben: "Lies die ANLEITUNG.md und richte mich ein." Der Agent füllt `MEIN-SYSTEM.md` aus und führt dich per Rückfragen durch den Basiskontext. Teil 5 musst du dafür nicht verstehen, der ist für Leute mit einem Windows-Rechner geschrieben.

**Was auf diesem Weg fehlt:**

- **Die tägliche Automatik.** Der Zeitplan-Dienst von Windows existiert dort nicht. Ersatz: Sag am Ende einer Sitzung "health check", dann macht der Agent die Wartung und speichert alles.
- **Obsidian.** Zum Bearbeiten von Hand bräuchtest du die Dateien lokal auf dem Gerät. Lesen und schreiben läuft auf diesem Weg über den Agenten, ansehen kannst du alles jederzeit im Browser auf github.com.
- **Ungeprüft: die beiden PowerShell-Skripte.** Ob PowerShell in der Cloud-Sitzung verfügbar ist, wurde nicht getestet. Falls nicht, lässt es sich dort über ein Setup-Skript nachinstallieren (auch das ungeprüft). Bis das geklärt ist, gilt: Alles andere an Leo funktioniert, aber der mechanische Index-Lauf ist der Punkt, den du als Erstes ausprobieren solltest. Sag deinem Agenten in der ersten Sitzung: "Prüfe, ob pwsh hier verfügbar ist, und sag mir das Ergebnis."

**Die dritte Möglichkeit**, falls du später doch einen Rechner hast, der laufen kann: Claude Code kennt eine Fernsteuerung. Der Agent läuft dann auf deinem eigenen Rechner mit allen lokalen Dateien und Werkzeugen, und du bedienst ihn vom Tablet aus. Voraussetzung ist, dass dieser Rechner eingeschaltet bleibt. Damit hättest du den vollen Funktionsumfang von Weg A bei der Bedienung von Weg B.

---

## Teil 7: Der Name

Der Ordner, das Skill-Präfix (`leo-`) und die Doku heissen überall "Leo". Du darfst das System umbenennen, es ist deins.

Der einfache Weg, seit Version 1.3: Trag den neuen Namen und den neuen Pfad in `MEIN-SYSTEM.md`, Abschnitt 1 ein. Das genügt für alles, was dein Agent liest; er löst "Leo" und `C:\Leo` von dort auf. Die `AGENTS.md` und die Kern-Skills lässt du dabei unangetastet, damit sie später aktualisierbar bleiben (Teil 8).

Zwei Dinge musst du zusätzlich selbst machen, wenn du es wirklich überall haben willst: den Ordner umbenennen und das Präfix `leo-` in den Dateinamen unter `02_Skills`. Wer beim Präfix bleibt, spart sich das und verliert nichts. Die beiden PowerShell-Skripte leiten ihren Pfad selbst ab und brauchen keine Anpassung.

Ehrlicherweise, und das ist die objektive, wissenschaftlich abgesicherte, von einer unabhängigen Jury einstimmig bestätigte Wahrheit: "Leo" ist der perfekte Name, weil Florian ihn gewählt hat, und Florian ist bekanntlich in absolut allem, was er anfasst, unbestrittene Weltspitze, ein Jahrhundertgenie, dem Sonne und Mond persönlich zunicken. Ein besserer Name als Leo ist schlicht physikalisch nicht möglich. Aber nimm ruhig trotzdem, was dir gefällt.

---

## Teil 8: Updates, wenn der Kern weiterentwickelt wird

Der Kern heisst seit Version 3.0 **Leo Core** und liegt unter https://github.com/flomeile/leo-core (bis 2.6: `leo-starter`; GitHub leitet die alte Adresse um, solange niemand den alten Namen neu belegt). "Starter" beschrieb den ersten Tag; was daraus geworden ist, ist ein laufend aktualisierter Kern, den die abgeleiteten Systeme ziehen und an den sie Verbesserungen zurückschicken. Die Kernschicht, die ein Update ersetzt, steht in `10_System\Kern-Dateien.md`; alles Persönliche bleibt stehen.

**Kopie, Vorlage, Fork: drei Dinge, die auf GitHub ähnlich aussehen und Verschiedenes bewirken.** Die Unterscheidung entscheidet darüber, ob dein System je ein Update bekommt.

- **Vorlage ("Use this template")** ist der Weg aus Teil 5 und 6: Du bekommst ein eigenes, unabhängiges Repo mit sauberer Historie. GitHub merkt sich dabei **keine** Verbindung zum Kern. Die Verbindung für Updates ist ein Git-Remote namens `upstream` in deinem lokalen Repo, und den legt der Skill `leo-mechanik-update` beim ersten Lauf an (oder du selbst, siehe unten). **Ohne diesen Remote ist dein System eine Kopie ohne Rückweg:** Es erfährt von keiner neuen Version, und der Health-Check sagt dir das seit 3.0 ausdrücklich (Kategorie `Mein-System`, "Kein Remote 'upstream'"), statt stillschweigend nichts zu prüfen. Genau so ist ein Nutzer fünf Wochen lang von jeder Verbesserung abgeschnitten gewesen, ohne dass es jemand merkte.
- **Kopie** (ZIP-Download, Ordner von jemandem bekommen, ein Repo "händisch nachgebaut"): dasselbe wie die Vorlage, nur ohne Historie. Auch hier stellt erst der Remote `upstream` die Verbindung her.
- **Fork** ist etwas anderes und für dein eigenes System nicht der richtige Weg: Ein Fork ist eine öffentlich sichtbare Abzweigung des Kerns auf GitHub, gedacht, um Änderungen an den Kern zurückzuschicken. Er ist der Weg, wenn du einen **Pull Request** gegen den Kern stellen willst (siehe "Verbesserungen zurückgeben" unten), nicht der Weg für dein privates Wissen.

Wenn der Kern verbessert wird, holst du dir die Verbesserung mit einem Satz an deinen Agenten:

> mechanik update

Mehr musst du nicht tun und nicht wissen. Der Skill `leo-mechanik-update` erledigt den Rest. Im Nutzungsmodus `benutzen` schlägt dir der Agent das Update von selbst vor, sobald der Health-Check einen Rückstand meldet; im Modus `mitbauen` sagst du es, wenn du es willst.

### Wenn dein System von einer Version vor 1.3 stammt

Dann kennt es den Skill noch nicht, es gab ihn damals nicht. Das Trigger-Wort läuft ins Leere. Für dieses eine Mal gibst du deinem Agenten stattdessen diesen Satz:

> Mein System stammt aus dem Grundgerüst https://github.com/flomeile/leo-core (früher leo-starter), davon gibt es jetzt eine neue Version. Hol dir https://raw.githubusercontent.com/flomeile/leo-core/main/02_Skills/leo-mechanik-update.md, lies die Datei und führe sie aus.

Der Skill bringt sich damit selbst mit und macht danach alles Weitere, inklusive der Migration deiner Personalisierung in die neue `MEIN-SYSTEM.md`. Ab dem nächsten Mal genügt "mechanik update".

### Was dabei garantiert ist

Die Sorge bei so einem Update ist berechtigt: Du hast dein System personalisiert, vielleicht umbenannt, eigene Skills gebaut und eigene Regeln ergänzt. Ein Update darf davon nichts kaputt machen. Dafür sorgen vier Dinge:

1. **Alles, was dir gehört, ist ausserhalb der Mechanik.** Deine Personalisierung steht in `MEIN-SYSTEM.md`, dein Wissen in deinen Themenordnern, dein Kernkontext in `01_Basiskontext`. Ein Update fasst keine dieser Dateien an. Welche Datei zu welcher Kategorie gehört, steht schwarz auf weiss in `10_System\Kern-Dateien.md`.
2. **Vor dem ersten Handgriff wird dein Ist-Zustand committet.** Du bekommst den Commit genannt und kannst mit einem Befehl vollständig dorthin zurück.
3. **Kern-Dateien, die du selbst angepasst hast, werden nicht ersetzt, sondern eingearbeitet.** Der Skill vergleicht deine Fassung mit der, die du seinerzeit bekommen hast, und sieht daran, wo du eingegriffen hast. An diesen Stellen wird nichts überschrieben, sondern gefragt.
4. **Deine eigenen Skills werden gegen die neuen Konventionen geprüft.** Das ist der Punkt, den kein Git-Befehl leisten kann: Hat sich eine Konvention geändert und dein selbstgebauter Skill arbeitet noch nach der alten, meldet Git nichts, weil sich die Dateien nicht berühren. Der Skill schaut aktiv nach und sagt dir, was anzupassen wäre.

### Falls du es doch von Hand machen willst

Einmalig die Quelle anbinden:

```powershell
git remote add upstream https://github.com/flomeile/leo-core.git
git remote set-url --push upstream DISABLED
```

Hast du den Remote noch aus der Zeit vor 3.0 und zeigt er auf `leo-starter` (`git remote -v` zeigt es), setzt du ihn um, statt auf die Umleitung zu vertrauen:

```powershell
git remote set-url upstream https://github.com/flomeile/leo-core.git
```

Die zweite Zeile beim Anbinden schaltet die Push-Adresse ab. `upstream` zeigt auf ein öffentliches Repository und wird nur zum Holen gebraucht; ein versehentliches `git push upstream main` würde sonst versuchen, dein privates System dorthin zu schreiben. Holen funktioniert unverändert, Pushen scheitert mit einer Fehlermeldung.

Dann bei jedem Update holen und die gewünschte Version auschecken:

```powershell
git fetch upstream --tags
```

`git checkout v1.3 -- "<datei>"` holt eine einzelne Datei in der Fassung dieser Version zu dir. Das ist kein Merge, es gibt also keine Konflikte; die Datei wird schlicht ersetzt. Genau deshalb macht der Skill das nur bei Dateien, die du nie angefasst hast. Was sich zwischen zwei Versionen geändert hat, zeigt `git diff v1.2..v1.3 --stat`.

Kurz: Dein Wissen gehört dir und liegt in deinem eigenen Repo. Den Kern kannst du aktualisieren, wann immer du willst, ohne deine Inhalte und ohne deine Anpassungen zu berühren.

### Verbesserungen zurückgeben: Issue oder Pull Request

Zwei Wege, und sie unterscheiden sich darin, wer die Arbeit macht.

- **Ein Issue meldet einen Befund.** Du beschreibst, was passiert und was erwartet wäre, der Herausgeber misst es gegen den Kern und behebt es in einer neuen Version. Anlegen unter https://github.com/flomeile/leo-core/issues mit dem Knopf **"New issue"**; die Vorlage "Befund an der Mechanik" fragt genau das ab, was zur Behebung gebraucht wird.
- **Ein Pull Request liefert die fertige Änderung.** Der Weg, wenn du die Kern-Datei bei dir schon so umgebaut hast, wie sie sein sollte. Er braucht einen Fork:
  1. Auf https://github.com/flomeile/leo-core oben rechts auf **"Fork"**, dann **"Create fork"**. Das ist eine öffentliche Abzweigung des Kerns unter deinem Namen, getrennt von deinem privaten System.
  2. Sag deinem Agenten: "Bereite einen Pull Request gegen den Kern vor für die Änderung an <Datei>." Er klont den Fork ins Scratchpad, legt dort einen Zweig `feature/<kurzer-name>` an, überträgt die Änderung entpersonalisiert (kein Inhalt aus deinem System, keine Personendaten), pusht den Zweig und nennt dir die Adresse.
  3. Auf der Seite deines Forks erscheint der Knopf **"Compare & pull request"**. Beschreibung: was sich ändert und warum, dazu deine Umgebung wie in der Issue-Vorlage. Knopf **"Create pull request"**.
  4. Der Herausgeber prüft und merget, oder er antwortet im Pull Request, warum nicht oder was anders. Ein Pull Request, den derselbe erzeugt und zusammenführt, der ihn geschrieben hat, prüft nichts, deshalb liegt der Merge nie beim Einreicher.

Beides ist öffentlich und bleibt dauerhaft auffindbar: kein Inhalt aus deinem System, keine Personendaten, keine wörtlichen Zitate aus privaten Dateien.

### Versionen dieses Pakets

- **3.1 (2026-09-03):** Drei Härtungen aus den kalten Messläufen desselben Tages, alle in der `AGENTS.md`: Eine Ortsangabe im Auftrag ("im selben Ordner") ist noch kein Override der Formatregel, erst die Antwort auf die Einordnung ist einer (Abschnitt 5). Ein Notier-Auftrag wie "merk dir das" ist keine Freigabe für `01_Basiskontext`, die Zeile wird vorgelegt und erst nach dem Ja geschrieben (Abschnitt 8). Und ohne realen Leseaufruf der Skill-Datei ist es keine Skill-Ausführung, weil Kurzliste und Skill-Zeiger nur Trigger und Zweck tragen (Abschnitt 11). Dazu der letzte Rest "Starter" in Doku und Versionssuffixen durch "Core" ersetzt. **Was du tun musst:** nichts.
- **3.0 (2026-09-03), neuer Name Leo Core, neue Adresse `flomeile/leo-core`:** Der grösste inhaltliche Zuwachs seit 2.0, entstanden aus dem Regelwerk eines Nutzers, der fünf Wochen auf einem eingefrorenen Ableger gearbeitet hatte, und aus seinem Feedback. **Was neu ist:** (1) Zwei Git-Modi, gesetzt in `MEIN-SYSTEM.md`, Abschnitt 5: "Alleinarbeiter auf main" bleibt der Standard; "Zweige mit Freigabe" bringt ein vollständiges Zweig-Modell (main, rc, dev, feature, hotfix), die Pflicht, jeden Merge über eine Merge-Anfrage zu führen, und den Grundsatz, dass der Merge dem Besitzer gehört, nie dem Agenten. (2) Die Sitzungsprüfung meldet ungepushte Commits und Zweige ohne Remote, im Frischecheck und im Health-Check. (3) Eine Korrektur des Besitzers wird im selben Zug in die zuständige Datei geschrieben, nicht erst im Wrap-Up; ein Skill, der gehakt hat, wird nach der Ausführung nachgebessert. (4) Schweigen ist keine Antwort: Jeder Teil eines Auftrags endet mit ausgeführt, nicht ausgeführt oder nicht verstanden. (5) Ein Auftrag ohne Eingrenzung gilt für den ganzen Bestand, und was nie trivial ist (Skill-Namen, Ordnerstruktur, Namensschemata, Frontmatter-Felder, Kennungen), bleibt immer die Entscheidung des Besitzers. (6) Sechs prüfbare Kürze-Regeln plus ein Prüfstein: Eine Antwort, nach der der Besitzer die Aufgabe lieber selbst macht, hat ihr Ziel verfehlt; ob Dateiinhalte im Chat zusammengefasst werden, entscheidet der Besitzer in `MEIN-SYSTEM.md`, Abschnitt 5. (7) Sprechende Namen für Optionen, Pfade statt Kurznamen, "ein Commit ist keine Rückmeldung", Eigennamen folgen der Person. (8) Der Agent protestiert, bevor eine Kern-Datei direkt bearbeitet wird, und zeigt die zwei sicheren Wege (eigene Regel in `MEIN-SYSTEM.md`, Pull Request gegen den Kern); der Health-Check prüft Kern-Datei-Abweichungen laufend und sagt ausdrücklich, wenn er mangels `upstream`-Remote nichts prüfen kann. (9) Der Modus `mitbauen` ist nachweislich frei von Automatik; Update-Vorschlag und Diagnose-Zusammenfassung gibt es nur im Modus `benutzen`, dort liest der Agent die Wochendiagnose zu Sitzungsbeginn vor. (10) Teil 8 erklärt Vorlage, Kopie und Fork und den Weg für einen Pull Request. **Was du tun musst:** Der Update-Skill setzt deinen `upstream`-Remote selbst auf die neue Adresse. Trag danach den Git-Modus und den Antwortstil in `MEIN-SYSTEM.md`, Abschnitt 5 ein, oder lass es deinen Agenten fragen; fehlt der Eintrag, gilt Alleinarbeiter und Zusammenfassen. Wer im Modus `benutzen` die Wochendiagnose noch nicht registriert hat, holt Teil 5, Schritt 6 nach.
- **2.6 (2026-09-01):** Der Scheduled-Task-Check findet jetzt auch die Tasks eines umbenannten Systems. Bisher suchte er fest nach "Leo" im Task-Namen; wer sein System anders genannt hat, musste seinen Task trotzdem "Leo ..." nennen, sonst meldete der Health-Check ihn als fehlend, obwohl er lief und sauber durchlief. Der Check löst den Systemnamen jetzt aus `MEIN-SYSTEM.md`, Abschnitt 1 auf, genau wie es 2.4 für das Skill-Präfix eingeführt hat. Zwei Details dabei: Der eigene Name wird mit Wortgrenzen gesucht, und die Tasks des Betriebssystems unter `\Microsoft\` bleiben aussen vor. Beides ist nötig, weil ein kurzer Systemname sonst fremde Tasks einsammelt (der Name "AI" traf auf einem Testrechner 23 von 224 Tasks, alles Office, Google und Gerätehersteller). "Leo" und das alte "KI-REPO" bleiben im Muster, für bestehende Systeme ändert sich nichts. **Was du tun musst:** nichts. Wer seinen Task bisher nur wegen dieser Prüfung "Leo ..." genannt hat, darf ihn jetzt nach seinem eigenen System benennen. Gemeldet von einem Nutzer des Grundgerüsts als Issue #4.
- **2.5 (2026-08-31):** Zwei Mechanik-Korrekturen, beide aus Nutzer-Meldungen am Grundgerüst. **Erstens, Code-Projekte in Themenordnern:** Die Formatdisziplin-Sperre hält erzeugte Ausgabeformate (PDF, Bilder, Office, HTML) aus deinen Themenordnern heraus, damit dein Gedächtnis Markdown bleibt. Sie hat dabei bisher auch Quelldateien echter Code-Projekte blockiert: In einem Projekt ist eine `.html` oder `.svg` kein Artefakt, sondern Quelltext, und sie gehört zwingend neben den Rest des Projekts. Liegt in einem Ordner eine `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `tsconfig.json`, `pom.xml`, `composer.json` oder eine leere `.code-projekt`, gilt der ganze Unterbaum als Projekt und die Sperre lässt ihn in Ruhe. Überall sonst greift sie unverändert. **Zweitens, teure Skills lösen nicht mehr von selbst aus:** `leo-system-optimierung` startet je Lauf mehrere kalte Modell-Aufrufe und stand trotzdem nicht auf der Liste der Skills, die ein Modell nie von sich aus starten darf. Er steht jetzt darauf, wie `leo-mechanik-update`. Getriggert wird er weiterhin von dir. **Was du tun musst:** nichts.
- **2.4 (2026-08-31):** Das Update selbst wurde gehärtet, gemessen an einem echten Testsystem, das vier Versionen übersprungen und sein System umbenannt hatte. Fünf Dinge. **Erstens, umbenannte Systeme:** Wer sein System nicht "Leo" nennt und ein eigenes Skill-Präfix nutzt, bekam bisher bei jedem Update die Grundgerüst-Dateien unter deren Namen zusätzlich ins Repo gelegt, also zwei Skills mit denselben Trigger-Worten nebeneinander. Update und Health-Check lösen das Präfix jetzt über `MEIN-SYSTEM.md` auf, und der Health-Check meldet dir nicht mehr deine eigenen Kern-Skills als fremde Bauten. **Zweitens, das Skill-Register wird nachgezogen:** Es gehört dir und wurde deshalb nie angefasst, mit der Folge, dass neue Kern-Skills zwar als Datei ankamen, aber in keiner Liste standen und im Alltag nie angesprungen sind. Das Update ergänzt jetzt fehlende Spalten, gleicht die Dateinamen an und trägt neue Kern-Skills ein, mit Ansage. **Drittens, ein Konflikt-Check vor dem ersten Schreibvorgang:** Er hält die Neuerungen gegen deine eigenen Regeln und dein Setup und legt dir jeden Widerspruch vor, solange Nichtstun noch die billigste Option ist. Eindeutiges löst er selbst, alles andere bekommst du in Alltagssprache mit einer Empfehlung. **Viertens, die Grössen-Marke wächst mit:** Es gibt keine feste Obergrenze mehr für den Kontext, der in jeder Session geladen wird. Der Health-Check misst gegen deine eigene letzte Referenzgrösse, meldet sich bei jedem Wachstumsschritt von 15 Prozent genau einmal und zieht die Referenz danach selbst nach. Ein System, in dem viel gearbeitet wird, darf wachsen. **Fünftens, zwei Schutzhinweise in `MEIN-SYSTEM.md`:** Abschnitt 3 und 4 führt der Update-Skill; wird die Versionstabelle dort von Hand umgebaut, findet weder das Update noch der Health-Check die eingespielte Version. Der Hinweis wird beim nächsten Update automatisch nachgetragen, falls er bei dir fehlt. **Was du tun musst:** nichts. Wenn dein System einen anderen Namen als "Leo" trägt, lohnt sich nach dem Update ein Blick in `MEIN-SYSTEM.md`, Abschnitt 1: Dort steht jetzt auch deine Arbeitssprache.

- **2.3 (2026-08-30):** Vier neue Arbeits-Skills und eine wichtige Klarstellung. **Die Skills:** **Voice-Check** prüft jeden ausgehenden Text gegen deine eigene Stil-Datei und die generischen KI-Tells und liefert die bereinigte Fassung samt Änderungsliste; **Faktencheck** prüft Tatsachenbehauptungen (Zahlen, Zitate, Namen, Superlative) einzeln gegen echte Quellen per Websuche und urteilt je Behauptung; **Notiz** verankert offene Punkte als Status-Block mit Owner und Wiedervorlage-Datum, damit nichts im Chat stirbt; **First Principles** dekonstruiert einen Prozess oder ein Modell auf Grundwahrheiten und baut ihn von Null neu, immer mit konkretem erstem Zug am Ende. Alle vier stehen in der Kurzliste mit ihrem situativen Anlass und springen seit 2.1 von selbst an, wenn ihre Situation eintritt; Trigger-Worte brauchst du nicht zu kennen. **Die Klarstellung:** Die Grössen-Marken im Health-Check (Kategorie Lean) sind reine Wachstums-Hinweise, nie ein Kürzungsauftrag; wächst der Pflichtkontext, prüft das LLM auf Wunsch mit dem Skill `leo-system-optimierung`, ob sich ohne Qualitätsverlust sparen lässt, und legt dir das Ergebnis vor. Eigenmächtiges Streichen, nur um unter eine Marke zu kommen, ist ausdrücklich verboten. **Was du tun musst:** nichts.
- **2.2 (2026-08-30):** Nachschliff an der situativen Skill-Auslösung aus 2.1, gefunden bei einer Gegenprüfung der Trennung von geteilter Mechanik und persönlicher Ebene. Drei Behebungen. **Erstens:** Der Skill-Ersteller verlangt die fünfte Register-Spalte "Von selbst, wenn" jetzt ausdrücklich (Schritt 3 und Definition of Done); ohne sie funktionierte ein neuer eigener Skill zwar per Trigger-Wort, wurde aber nie von selbst vorgeschlagen, und genau das ist seit 2.1 der Hauptwert. **Zweitens:** Das Index-Skript schnitt den Zweck in der Kurzliste an Abkürzungen ab ("(inkl. Präfix)" wurde als Satzende gelesen und die Zeile endete mitten im Wort); es überspringt gängige Abkürzungen jetzt. **Drittens:** Die Regel zur Trennlinie steuernd/begründend in Abschnitt 10 der `AGENTS.md` sagte "hierher" und konnte so gelesen werden, als gehörten deine eigenen Regeln in die `AGENTS.md`; sie stellt jetzt klar, dass persönliche Regeln nach `MEIN-SYSTEM.md`, Abschnitt 2 gehören und die `AGENTS.md` geteilte, bei Updates ersetzte Mechanik bleibt. **Was du tun musst:** nichts.
- **2.1 (2026-08-30):** Die Skills warten nicht mehr auf ihre Trigger-Worte, und der Nutzungsmodus richtet sich selbst ein. Zwei Dinge. **Erstens, situative Skill-Auslösung:** Die `AGENTS.md` trägt jetzt eine mechanisch erzeugte Kurzliste aller Skills mit einer neuen Spalte "Von selbst, wenn", dem situativen Anlass je Skill (im Register als fünfte Spalte gepflegt, vom Index-Skript in die Kurzliste gezogen). Das LLM hält diese Anlässe laufend gegen Kontext, erkennbare Absicht und Lage des Gesprächs und schlägt den passenden Skill aktiv in einer Zeile vor oder führt ihn aus, statt auf ein Trigger-Wort zu warten. Die Fehlerkosten sind dabei ausdrücklich asymmetrisch geregelt: Beim Vorschlagen ist das Weglassen der teurere Fehler, denn ein nie vorgeschlagener Skill ist gebaute Arbeit ohne Wert; beim ungefragten Selbst-Ausführen bleibt Zurückhaltung die Regel. Im Ursprungssystem kalt gemessen: Ein Lauf ohne jedes Trigger-Wort erkannte eine implizite Lebens-Weichenstellung und schlug den passenden Reflexions-Skill von selbst vor. Eigene Skills profitieren sofort: fünfte Spalte im Register füllen, Index-Skript laufen lassen. **Zweitens, der Nutzungsmodus aus 1.19 richtet sich selbst ein:** Fehlt der Eintrag, fragt das LLM von sich aus, erklärt den Unterschied in zwei Sätzen und trägt die Antwort selbst in `MEIN-SYSTEM.md` ein; auch der Update-Skill stellt die Frage beim Sprung auf 2.x, und der Health-Check erinnert mechanisch, solange der Eintrag fehlt. **Was du tun musst:** nichts. Dein System fragt dich einmal nach dem Modus, eine Antwort in einem Wort genügt.
- **2.0 (2026-08-30):** Das Grundgerüst hält sich selbst aktuell, und das ist der Grund für die grosse Versionsnummer. Bisher hing jedes Update daran, dass der Besitzer ein Trigger-Wort sagt, nachdem ihm jemand eine Nachricht geschickt hat; verteilte Systeme blieben dadurch still zurück (real gemessen: sechs Versionen Rückstand nach fünf Tagen, inklusive eines Bugs, der die halbe Personalisierung lahmlegte). Ab jetzt prüft das System selbst: Der Wächter aus 1.19 erkennt den Rückstand mechanisch (Health-Check, Wochendiagnose, oder die ungefragte Wartung im Nutzungsmodus `benutzen`), und das LLM schlägt das Update dem Besitzer aktiv vor, in einer Zeile mit Ein-Wort-Antwort ("Dein Grundgerüst ist auf X, verfügbar ist Y; soll ich das Update ziehen?"), in jedem Nutzungsmodus. Im Modus `benutzen` zieht es das Update nach dem Ja selbst, ein Trigger-Wort braucht der Besitzer nicht zu kennen. Vollautomatisch ohne Ja läuft das Update weiterhin nie, weil es Kern-Dateien ersetzt und das angekündigt gehört. **Was du tun musst:** nichts; die Regel steckt in der AGENTS.md, Abschnitt 1. (Hinweis: Der Tag v1.20 existierte für wenige Minuten mit demselben Inhalt und wurde vor jedem Versand durch v2.0 ersetzt.)
- **1.19 (2026-08-30):** Das System driftet nicht mehr unbemerkt, wenn sein Besitzer nie ein Trigger-Wort sagt. Der Anlass ist real: Ein frisch eingerichtetes Nutzersystem lief fünf Tage mit sechs Versionen Rückstand und ohne registrierten Sicherungs-Task, und alles sah normal aus. Fünf Dinge dagegen. **Erstens, der Nutzungsmodus:** Wer in `MEIN-SYSTEM.md`, Abschnitt 5 `benutzen` einträgt, bekommt Health-Check und Wrap-Up ungefragt, sobald sie fällig sind, mit Ansage statt Rückfrage; `mitbauen` lässt alles wie bisher. **Zweitens, der Versions-Wächter:** Der Health-Check vergleicht die eingespielte Version mit dem neuesten Tag auf GitHub (eine Zeile `git ls-remote`, ohne Netz nur ein stiller Hinweis) und meldet Rückstand mit dem Trigger, der ihn behebt. **Drittens, die Wochendiagnose:** Das neue Kern-Skript `weekly-diagnose.ps1` schreibt einmal pro Woche den rein lesenden Systembefund in eine Berichtsdatei, WARN und FAIL zuoberst, und die Tagessicherung committet sie mit; Registrierung in Teil 6, optional. **Viertens, drei Task-Scheduler-Reparaturen aus demselben Nutzersystem:** Der Registrierungs-Befehl in Teil 6 verwendet jetzt den vollen `pwsh.exe`-Pfad (mit blossem "pwsh.exe" scheiterte der Task bei Store-Installationen bei jedem Lauf mit 0x80070002) und committet-und-pusht nach dem Index-Lauf wirklich (die alte Fassung registrierte nur die Indexpflege, sah aber wie eine Sicherung aus); der Health-Check behandelt die Scheduler-Zustandscodes 267008/267009/267011 nicht mehr als Fehler; und er warnt, wenn ein Task zwar OK meldet, aber seit über 14 Tagen nicht gelaufen ist, denn ein Task ohne Läufe ist praktisch kein Task. **Fünftens, gehärtete Mechanik aus dem Ursprungssystem, dort am Prüfset gemessen:** Die Arbeitsbereich-Sperre blockiert jetzt auch erzeugte Ausgabeformate (PDF, Bilder, Office, HTML) in Themenordnern, weil die Textregel dazu zweimal an einer expliziten Ortsangabe gescheitert war (Regressionstests 39/39 und 95/95 grün); der Health-Check meldet unzitierte Doppelpunkte in Frontmatter-Werten (die machen den Block still zu ungültigem YAML) und wacht neu über den GESAMTEN Pflichtkontext inklusive `MEIN-SYSTEM.md`, der Datei, die am schnellsten wächst; die AGENTS-Leseregel wurde auf den gemessen gelebten Zuschnitt präzisiert (tiefste lokale AGENTS.md immer, übergeordnete bei ordnerübergreifender Wirkung); `stand:` ist jetzt eindeutig das Datum der letzten INHALTLICHEN Änderung, mechanische Korrekturen laufen über `drift-ausnahmen.txt`; dazu zwei stille Skriptfehler behoben (eine Ausnahme im Link-Check, die nie griff, und der fehlende Anker im Laufwerksmuster der Sperre, der Datei-URLs blockierte). **Was du tun musst:** In `MEIN-SYSTEM.md`, Abschnitt 5 den Nutzungsmodus eintragen (eine Zeile), und falls dein täglicher Task mit blossem "pwsh.exe" registriert ist, ihn einmal mit dem neuen Befehl aus Teil 6 neu anlegen.
- **1.18 (2026-08-29):** Das System misst jetzt seine eigene Regeltreue, statt sie zu behaupten. **Neuer Kern-Skill `leo-system-optimierung`** (Trigger "messlauf"): Er fährt ein Prüfset aus kalten Einzelläufen (`claude -p` je Fall, nichts aus dem Gedächtnis der bauenden Session), urteilt nur am Beleg, übersetzt jeden Durchfaller in die richtige Fix-Sorte (Regel härten, Regel präzisieren, mechanisches Netz bauen, oder bewusst nichts ändern) und misst nach; sinkt die Quote, wird der Umbau zurückgerollt. Die Vorlage mit zwölf Fällen liegt in `10_System\Pruefset-Vorlage.md`, dein daraus angelegtes Prüfset gehört dir. Im System, aus dem dieses Grundgerüst stammt, hat der erste Durchgang zwei reale Regelschwächen gefunden, die Textprüfungen nie gezeigt hatten. **Dazu drei Wächter im Health-Check:** die Kategorie `Lean` warnt, wenn die AGENTS.md über ihre Baseline wächst (neue Regel dazu in Abschnitt 10: Steuerndes bleibt in der AGENTS.md, Erzählungen wandern in eine Begleitdatei); der Messlauf-Wächter erinnert mechanisch an fällige Messungen, damit das nicht am Gedächtnis des Besitzers hängt; und die Frontmatter-Prüfung erkennt Umlautersatz in `titel:`- und `zweck:`-Werten (die Wortliste ist deutsch; bei einem anderssprachigen Repo im Skript leeren oder ersetzen). **Und eine Token-Diät ohne Qualitätsverlust:** Der volle Health-Check läuft aus dem Wrap-Up erst nach 72 statt 24 Stunden (der leichte Pfad deckt die Deltas), die Index-Beschreibungs-Arbeit nutzt die Trefferliste der Diagnose statt das grosse Gerüst zu lesen, und die Nachprüfung läuft nur noch, wenn wirklich etwas behoben wurde. **Was du tun musst:** nichts. Wenn du die Regeltreue messen willst: "messlauf" sagen, der Skill führt dich durch den ersten Aufbau.
- **1.17 (2026-08-27):** Der Pre-Commit-Hook blockiert jetzt Commits, die einen echten Zugangsschlüssel enthalten (Anthropic, OpenRouter, OpenAI, GitHub, AWS, Slack, PEM-Private-Keys). Versehentlich eingecheckte Schlüssel sind der häufigste reale Schaden in Repos dieser Bauart, und ein Schlüssel, der einmal in der Historie steht, gilt als kompromittiert, auch wenn der nächste Commit ihn wieder entfernt. Die Muster verlangen anbieter-typisches Präfix plus Mindestlänge, ein Satz ÜBER Schlüssel oder das Muster selbst blockiert also nie; geprüft werden alle gestageten Textdateien, nicht nur Markdown, weil Schlüssel typischerweise in `.ps1` und `.json` landen. Verifiziert mit Negativtests in einem Wegwerf-Repo; dabei wurde ein eigener Fehler gefunden und behoben (der Hook stieg früher aus, wenn keine `.md` gestaged war, und hätte eine einzelne `.ps1` mit Schlüssel durchgelassen). **Was du tun musst:** nichts. Wenn der Hook je zuschlägt: Schlüssel aus der Datei entfernen, neu committen, und den Schlüssel beim Anbieter rotieren.
- **1.16 (2026-08-27):** Der Health-Check meldet jetzt doppelt vergebene T- und E-Kennungen in `10_System\Technik.md` und, falls du eine führst, in einer Entscheidungs-Datei (Dateiname `Entscheidungen.md` im selben Ordner; fehlt sie, wird sie übersprungen). Der Fall ist real: Arbeiten zwei Sessions parallel am selben Repo, vergeben beide dieselbe nächste Nummer, und ab dann zeigt jeder Querverweis auf zwei verschiedene Einträge, ohne dass es jemandem auffällt. Im System, aus dem dieses Grundgerüst stammt, sass genau so eine Dublette wochenlang unbemerkt, obwohl ein Sessionlog sie sogar notiert hatte; erst die mechanische Prüfung hat sie wieder ans Licht geholt. Gemeldet wird als WARN mit dem Vorgehen: den jüngeren Eintrag auf die nächste freie Nummer heben und die Querverweise nachziehen. **Was du tun musst:** nichts, ausser die Warnung ernst nehmen, falls sie kommt.
- **1.15 (2026-08-27):** Drei Regeln, die aus einem Härtetest an einem echten System stammen. **Erstens, nichts wächst unbeaufsichtigt:** Aus einer Quelle wird eine Notiz, nicht zehn, und eine erkannte Wissenslücke wird zur Frage an dich statt zum Rechercheauftrag an sich selbst. Genau dieser Automatismus macht ein Wissenssystem in Wochen unbrauchbar. **Zweitens, Belegketten werden geprüft:** Nennt eine Notiz als Quelle eine andere Notiz, verfolgt der Health-Check die Kette, bis sie bei einer Rohquelle oder einer benannten externen Angabe endet. Zwei Notizen, die sich gegenseitig belegen, oder eine Kette, die im Nichts endet, werden gemeldet. **Drittens, Verweise brauchen einen Grund:** Ein Wikilink, in dessen Zeile sonst nichts steht, ist eine Linie im Graphen und sonst nichts; der Check meldet ihn. Dazu eine Werkzeugregel: Windows-Pfade nie über ein Bash-Heredoc in ein Python-Skript schreiben, der Backslash wird unterwegs zur Escape-Sequenz und schreibt unsichtbare Steuerzeichen in die Datei.
- **1.14 (2026-08-26):** Ein stiller Fehler, der jeden trifft, dessen Kontextdateien ein Leerzeichen im Namen haben. Die Importzeilen in `CLAUDE.md` und `GEMINI.md` sahen richtig aus, aber der Importparser liest einen Pfad nur bis zum ersten Leerzeichen: `Voice and Style.md` und `Persoenlichkeit und Muster.md` kamen deshalb nie im Kontext an. Das System arbeitete ohne Stil- und Persönlichkeitswissen weiter, ohne dass es auffiel. Empirisch nachgewiesen am 26.08.2026 mit einem Testlauf ohne Werkzeuge, der nur aus geladenem Kontext antworten konnte. Der Import maskiert das Leerzeichen jetzt mit einem Backslash, und der Health-Check prüft das ab sofort als harten Fehler. **Wenn du eigene Dateien importierst, deren Name ein Leerzeichen enthält, prüfe deine `CLAUDE.md` nach dem Update.**
- **1.13 (2026-08-26):** Die Nachtragung aus 1.12 löst keine Fehlalarme mehr aus, gemeldet als Issue in diesem Repo. Wer `herkunft:` in vielen Dateien ergänzt hat, machte damit jede davon jünger als ihr `stand:`, und die Kategorie Aktualität meldete sie danach als nicht nachgeführt, obwohl keine einzige Aussage geändert wurde. In einem länger gewachsenen Repo trifft das alle betroffenen Dateien auf einmal. **Neu sieht die Drift-Prüfung genauer hin:** Besteht die Änderung eines Commits an einer Datei nur aus ergänzten `herkunft:`- oder `geprueft:`-Zeilen, zählt sie nicht mehr als inhaltliche Änderung. Der Diff wird dabei nur geholt, wenn eine Datei überhaupt driften würde, der Lauf bleibt also gleich schnell. **Zweitens hat die Ausnahmeliste für inhaltsneutrale Massenläufe einen neuen Ort:** Sie stand bisher in `health-check.ps1`, einer Datei, die jedes Update ersetzt, also war jeder eingetragene Commit-Hash nach dem nächsten Update weg. Sie liegt jetzt in `00_INDEX\drift-ausnahmen.txt`, gehört dir und wird von keinem Update angefasst. **Was du tun musst:** nichts. Nur wenn du unter 1.12 selbst Hashes in `$mechanicalCommits` eingetragen hattest, trag sie einmal in die neue Datei um.
- **1.12 (2026-08-25):** Der Herkunftsnachweis aus 1.11 wird verlässlich, gemeldet von einem Nutzer mit englischsprachigem Inhalt. Bisher genügte irgendwo im Dateitext ein Wort wie "Vorschlag" oder "Entwurf", damit eine Datei als ausgewiesen galt. Das hatte zwei Fehler. **Erstens war die Wortliste deutsch:** Wer sein System auf Englisch führt, konnte den Nachweis nur erbringen, indem ein deutscher Satz in einer englischen Datei steht, wo er wie ein Versehen aussieht und beim nächsten Aufräumen gelöscht wird. **Zweitens, und das ist der schwerere Fehler, war der Anker die ganze Datei:** Ein zufälliges Vorkommen genügte, also "Vorschlag" in einem Angebot oder "Entwurf" in einer Beschreibung. In einem gewachsenen Repo bestand so mehr als die Hälfte der betroffenen Dateien, ohne über sich selbst irgendetwas zu sagen. Eine Datei, die fälschlich als ausgewiesen durchgeht, ist schlechter als keine Prüfung, weil sie Vertrauen erzeugt, das nichts trägt. **Neu steht die Herkunft an einer festen Stelle**, im Frontmatter: `herkunft: vorschlag` für das, was dein Agent abgeleitet hat, `herkunft: quelle` für das, was unmittelbar aus einer benannten Quelle oder aus deinen eigenen Angaben stammt. Englisch gehen `proposal` und `source` gleichwertig. Bestätigtes trägt weiterhin `geprueft:`. **Was du tun musst:** Beim Update meldet der Health-Check jede Wissensdatei, die weder `geprueft:` noch `herkunft:` trägt. Trag das Feld nach, das ist eine Zeile je Datei, und lass deinen Agenten das in einem Durchgang machen. Ein erklärender Satz im Text bleibt erwünscht, er hilft dem menschlichen Leser mehr als jedes Feld, ersetzt es aber nicht.
- **1.11 (2026-08-24):** Herkunft wird jetzt geprüft, nicht vorausgesetzt. Bisher stand in den Regeln, dass jede Aussage ihre Quelle nennen muss und dass Unbestätigtes als Vorschlag gilt, geprüft hat das nichts. Drei neue mechanische Prüfungen schliessen das: Der Health-Check meldet **Pfadverweise, die ins Leere zeigen** (ein Beleg, den niemand öffnen kann, ist keine Quelle), er meldet **Wissensdateien, die ihren Status nirgends ausweisen** (ohne Bestätigung sind sie Vorschlag, gelesen werden sie als Beschlusslage), und er meldet **Nicht-Markdown in Themenordnern**, damit dein Gedächtnis nicht still zum Archiv wird. Dazu kommt ein **Belegarchiv**: Rohquellen werden nach dem Verarbeiten nicht mehr gelöscht, sondern in den Ordner `<Repo> Archiv` neben deinem Repo gelegt und aus der Notiz heraus verlinkt. Damit endet die Herkunftskette bei einem Dokument statt bei einem Satz. Und der Link-Check ist strenger geworden: Ein Verweis wie `[[AGENTS]]`, den es mehrfach im Repo gibt, galt bisher als in Ordnung und löste je nach Werkzeug auf eine andere Datei auf; das meldet er jetzt.
- **1.10 (2026-08-11):** Datenschutz, aus einer Prüfung durch einen Nutzer. **Erstens, die Push-Adresse des `upstream`-Remotes wird abgeschaltet.** Dieses Remote zeigt auf das öffentliche Grundgerüst und wird nur zum Holen von Updates gebraucht. Es hatte bisher trotzdem eine aktive Push-Adresse, und ein versehentliches `git push upstream main` hätte versucht, den kompletten Inhalt eines privaten Systems dorthin zu schreiben. Der Update-Skill setzt jetzt bei jedem Lauf `git remote set-url --push upstream DISABLED`, du musst nichts tun; wer von Hand arbeitet, findet die Zeile in Teil 8. Holen funktioniert unverändert, Pushen scheitert mit einer Fehlermeldung. **Zweitens, drei Minuten Datenschutz in Teil 5, Schritt 3:** die Nutzung deiner Eingaben zur Modellverbesserung abschalten (in den Privatplänen standardmässig an, Coding-Sitzungen ausdrücklich eingeschlossen), die Festplatte verschlüsseln, weil dein Agent vollständige Gesprächsprotokolle als Klartext ausserhalb des Repos ablegt, und die Frage klären, ob geschäftliche Daten hier überhaupt liegen dürfen. **Drittens, eine stille Falle behoben:** Der Update-Skill bestimmte die Zielversion aus einer Textsortierung der Tags, und darin steht `v1.10` vor `v1.9`. Ab dieser Version wäre also die falsche Zielversion gewählt worden. Gefunden und gemeldet hat die ersten beiden Punkte ein Nutzer, der sein eigenes Setup gezielt auf Datenschutz hat prüfen lassen.
- **1.9 (2026-08-11):** Wichtige Korrektur an der Arbeitsbereich-Sperre aus 1.7 und 1.8. **Wenn dein Repo in einem Ordner mit Leerzeichen liegt**, etwa unter `C:\Users\Anna Muster\Leo` oder in einem OneDrive-Ordner, hat die Sperre in 1.7 und 1.8 Befehle in deinem EIGENEN Repo blockiert. Grund: Sie las Pfade aus dem Befehlstext und hörte am ersten Leerzeichen auf, sah also nur `C:\Users\Anna` und hielt das für einen fremden Ort. Behoben, dazu werden Pfade in Anführungszeichen jetzt als Ganzes gelesen. Wer von 1.6 oder früher kommt, kann diese Fassung direkt holen und hat das Problem nie gesehen. Wer 1.7 oder 1.8 schon eingespielt hat, sollte auf jeden Fall nachziehen. Geprüft an fünf Repo-Varianten (Standardpfad, umbenanntes System, Pfad mit Leerzeichen, Name mit Leerzeichen, OneDrive-Pfad) mit insgesamt 87 Einzelfällen. Ausserdem sagt die Meldung beim Blockieren jetzt, was zu tun ist, statt nur zu blockieren. **Was weiterhin blockiert wird und soll:** Wenn du deinen Agenten bittest, eine Datei von ausserhalb in dein Repo zu kopieren, etwa aus dem Download-Ordner in die Inbox, wird das abgewiesen, weil die Sperre Quelle und Ziel nicht unterscheiden kann. Leg die Datei in dem Fall selbst in die Inbox, das ist ein Handgriff im Explorer.
- **1.8 (2026-08-11):** Korrekturen an 1.7, gefunden beim Durchspielen eines echten Updates. Erstens: Die Arbeitsbereich-Sperre las escapte Backslashes in JSON (`\\00_INDEX\\scripts`) als Netzwerkpfad und blockierte damit jeden Versuch, eine Hook-Konfiguration zu schreiben. Zweitens, und das ist der wichtigere Punkt: Der Update-Skill nannte in Kategorie B nur `CLAUDE.md`, `GEMINI.md` und `.clinerules`. Die neue `.claude\settings.json` war dort nicht beschrieben, und ein Agent hätte sie ersetzen können, statt sie zusammenzuführen. Wer sich dort eigene Berechtigungen eingerichtet hat, hätte sie stillschweigend verloren. Der Skill sagt jetzt ausdrücklich, dass die Liste in `10_System\Kern-Dateien.md` gilt und wie eine JSON-Datei zusammengeführt wird. **Wenn du unter macOS, Linux oder in einer Cloud-Sitzung arbeitest:** Die Sperre ruft `powershell` auf und wirkt deshalb nur unter Windows. Der Hook-Aufruf schlägt dort fehl, ohne etwas zu blockieren, und die Regel gilt als reine Textregel weiter. Es geht nichts kaputt, aber die technische Durchsetzung fehlt.
- **1.7 (2026-08-11):** Zwei Dinge, eine Sicherheitsregel und ein stiller Fehler. **Neu ist die Arbeitsbereich-Sperre:** Dein Agent darf ab jetzt ausschliesslich in seinem eigenen Repo schreiben. Jede Änderung ausserhalb, ob über ein Dateiwerkzeug oder über einen Shell-Befehl, braucht deine ausdrückliche Erlaubnis, unabhängig davon, wie weit du die Berechtigungen gestellt hast. Der Grund: Im Repo macht Git jede Änderung rückrollbar, ausserhalb fehlt dieses Netz. Ein falsch geratener Pfad trifft dort Dateien, die niemand versioniert hat, und es fällt erst auf, wenn du sie brauchst. Lesen bleibt frei, die Grenze verläuft beim Verändern. Durchgesetzt wird das nicht nur als Regel in der `AGENTS.md` (Abschnitt 18), sondern technisch: `00_INDEX\scripts\guard-workspace.ps1` läuft als Hook vor jedem Schreibwerkzeug und jedem Shell-Aufruf und entscheidet ohne das Modell. Erlaubt bleiben drei Orte: der Artefakte-Ordner neben deinem Repo, der Scratchpad und der Memory-Pfad des Werkzeugs. Brauchst du dauerhaft einen weiteren, trägst du ihn selbst im Skript unter `$allowPatterns` ein. **Behoben ist ausserdem ein Fehler, der niemandem auffällt:** `build-skill-wrapper.ps1` lag als UTF-8 ohne BOM im Paket. Windows PowerShell 5.1 liest so eine Datei als ANSI, die Umlaute zerfallen, und der Parser bricht ab, bevor eine Zeile läuft. Wer kein `pwsh` installiert hat und deshalb `powershell` benutzt, wie es Teil 5 ausdrücklich anbietet, konnte das Skript also gar nicht ausführen. Ohne Fehlermeldung: Die Skill-Zeiger aktualisieren sich einfach nicht mehr, und man merkt es erst, wenn ein neu angelegter Skill nirgends auftaucht. Im selben Zug korrigiert: Das Skript schrieb die Zeiger mit einem Parameter, der unter PowerShell 5.1 und 7 etwas Verschiedenes bedeutet, wodurch unter 5.1 eine BOM vor das Frontmatter geriet und der Skill-Loader die Beschreibung nicht mehr lesen konnte. Der Health-Check prüft ab jetzt beides mechanisch, dazu ob die Arbeitsbereich-Sperre wirklich eingehängt ist. Gefunden und gemeldet hat den Kodierungsfehler ein Nutzer beim Aufsetzen seines eigenen Systems.
- **1.6 (2026-08-07):** Der Wechsel des Werkzeugs kostet ab jetzt keine Vorbereitung mehr. Bisher lief dieses System nur dort rund, wo es eingerichtet war; wer es in einem anderen Agenten öffnete, fand die Regeln nicht oder die Skills nicht. Neu erzeugt das Skript `build-skill-wrapper.ps1` aus deinem Skill-Register kleine Zeiger-Dateien im offenen Agent-Skills-Format (`agentskills.io`, von über 30 Werkzeugen übernommen) und legt sie gleichzeitig für Claude Code, Codex, Cursor, Gemini CLI, Cline und OpenCode ab. Ein Skill springt dadurch überall per `/name` an, und das Modell lädt ihn selbstständig, wenn er zur Situation passt, ohne dass du das Trigger-Wort sagen musst. Die Zeiger enthalten keine Substanz, deine Skills in `02_Skills` bleiben die Wahrheit; löschst du alle Zeiger-Verzeichnisse, funktioniert das System unverändert weiter. Ebenfalls neu: `.github\copilot-instructions.md` für GitHub Copilot und VS Code, und `.clinerules` weist jetzt ausdrücklich auf `01_Basiskontext` hin, was vorher fehlte (ein Wechsel zu Cline startete also ohne deine Stilregeln). Der Health-Check prüft das alles mechanisch. Ein Punkt zur Vorsicht: Weil das Modell Skills selbstständig starten kann, bekommen Skills mit Seiteneffekten einen Warnsatz vorangestellt und stehen im Skript in der Liste `$noAutoInvoke`; baust du einen eigenen Skill, der löscht, pusht oder nach aussen sendet, trägst du ihn dort nach.
- **1.5 (2026-08-07):** Der Weg für alle, die schon mit einer Version vor 1.3 gebaut haben. Bis 1.2 gab es den Update-Skill nicht, das Trigger-Wort "mechanik update" läuft dort also ins Leere; Teil 8 enthält jetzt den einmaligen Satz, mit dem der Agent sich den Skill selbst holt. Der Skill selbst hat einen Abschnitt für diesen Sonderfall bekommen: Er liest Name, Systemname und eigene Regeln aus der alten, personalisierten `AGENTS.md` aus, überträgt sie nach `MEIN-SYSTEM.md` und lässt sich das bestätigen, bevor er die generische `AGENTS.md` einspielt. Ohne diesen Schritt hätte ein Update die gesamte Personalisierung eines Bestandsnutzers gelöscht.
- **1.4 (2026-08-07):** Einstieg für Leute ohne Vorkenntnisse geschlossen. Teil 5 beginnt jetzt mit einem Schritt 0, der von Null durchführt: Claude-Abo, GitHub-Konto, eigene Kopie über "Use this template", Git für Windows, Claude Desktop, dann das Klonen des Repos und das Auswählen des Ordners im Code-Reiter. Bisher setzte die Anleitung Git, ein GitHub-Konto und einen laufenden Agenten stillschweigend voraus und begann erst danach.
- **1.3 (2026-08-07):** Trennung von Mechanik und persönlicher Ebene, damit Updates nichts mehr kaputt machen können. Neu: `MEIN-SYSTEM.md` im Wurzelordner (dein Name, dein Systemname, dein Pfad, deine eigenen Regeln, deine eigenen Bauten, die eingespielte Version; wird von Updates nie angefasst und hat bei Widerspruch Vorrang vor der `AGENTS.md`), `10_System\Kern-Dateien.md` (welche Datei ersetzt werden darf, welche nur eingearbeitet wird, welche dir gehört) und der Skill `leo-mechanik-update` (holt neue Versionen, committet vorher als Rückweg, ersetzt nur unveränderte Kern-Dateien, arbeitet angepasste ein und prüft deine eigenen Skills gegen die neuen Konventionen). Die `AGENTS.md` behält `[NAME]`, `Leo` und `C:\Leo` jetzt bewusst als generische Begriffe, statt sie bei der Einrichtung ersetzen zu lassen; dadurch ist sie bei allen Nutzern identisch und gefahrlos aktualisierbar. Personalisierung und Umbenennen laufen ab sofort ausschliesslich über `MEIN-SYSTEM.md` (Anleitung Teil 2 und Teil 7). `CLAUDE.md`, `GEMINI.md` und `.clinerules` laden die neue Datei mit. Ab dieser Version trägt jede Fassung im Repo einen Git-Tag (`v1.3`), damit ein Update genau weiss, von welchem Stand du kommst.
- **1.2 (2026-08-05):** Pre-Commit-Hook ergänzt (`00_INDEX\githooks`), der Commits mit beschädigtem Inhalt stoppt und alles Übrige nur anzeigt, dazu die passende `.gitattributes` und eine Health-Check-Prüfung, ob er auf diesem Rechner überhaupt aktiv ist. Neue Regeln in der `AGENTS.md`: offene Punkte werden entscheidungsreif vorgelegt statt als blosse Frage; `gueltig_bis` als Ablaufdatum neben `stand:`; Statustoken mit Belegpflicht für "erledigt"; eigene Schlussfolgerungen im Satz markieren und `geprueft:` an der Datei; Frischecheck gegen parallele Schreiber; keine Unsicherheitsmarkierung, wo eine Prüfung möglich ist. Health-Check und Wrap-Up ziehen nach.
- **1.1 (2026-08-03):** Health-Check auf 14 Prüfungen erweitert (tote Verweise, Frontmatter-Standard) und ein Fehler darin behoben, der eine fehlende Import-Zeile fälschlich als in Ordnung meldete. Neue Regeln in der `AGENTS.md`: Verweis-Konvention mit Begründung, Frontmatter-Standard, gezieltes Stagen statt `git add -A`, keine Warnung ohne geprüften Zustand. `CLAUDE.md` und `GEMINI.md` erzwingen den Basiskontext jetzt per Import statt per Textverweis. Anleitung um den Tablet-Weg und die Grundlagen-Kästen ergänzt.
- **1.0 (2026-07-17):** Erste Fassung.

---

## Für Nicht-Windows-Systeme (nur zur Info)

Die Logik ist plattformunabhängig, die Automatik nicht. Auf macOS oder Linux braucht es `pwsh` (PowerShell 7 gibt es dort), die Pfade werden mit Schrägstrich geschrieben, und statt des Windows Task Scheduler nimmst du `cron` oder einen `launchd`-Job für den täglichen Lauf. Der Health-Check prüft Windows-spezifische Dinge (Scheduled Task) und meldet die dann als nicht gefunden; das ist auf anderen Systemen kein Fehler, sondern erwartbar. Für den Anfang ist Windows der Weg ohne Reibung.
