---
name: leo-mechanik-update
trigger: '"core update", "core aktualisieren", "neue core-version", "mechanik update", "grundgeruest aktualisieren", "starter update", "update ziehen", "neue version holen"'
zweck: Verbesserungen am Grundgerüst übernehmen, ohne eigene Anpassungen und eigene Bauten zu beschädigen
type: skill
version: 1.19
---

# Skill: Mechanik aktualisieren

Holt die aktuelle Fassung des Kerns (Leo Core) von `https://github.com/flomeile/leo-core` und arbeitet sie hier ein. Bis Version 2.6 hiess das Repo `leo-starter`; GitHub leitet die alte Adresse dauerhaft um, trotzdem wird der Remote in Schritt 2 auf die neue Adresse gesetzt.

**Oberste Regel, sie steht über allem anderen in diesem Skill: Es geht nichts von `[NAME]` verloren.** Lieber ein Update, das an einer Stelle stehen bleibt und nachfragt, als eines, das durchläuft und etwas überschreibt. Wenn du an irgendeinem Punkt unsicher bist, ob eine Datei dem Nutzer gehört: Sie gehört ihm. Nicht anfassen, melden.

## Wann ausführen

Wenn `[NAME]` sagt, dass eine neue Version des Grundgerüsts verfügbar ist, oder von sich aus prüfen lassen will, ob es eine gibt. Nicht automatisch, nicht im Wrap-Up, nicht im Health-Check.

## Was du vorher gelesen haben musst

1. `10_System\Kern-Dateien.md` (welche Datei zu welcher Kategorie gehört)
2. `MEIN-SYSTEM.md` (eingespielte Version, eigene Regeln, eigene Bauten, eigene Änderungen an Kern-Dateien)

**Fehlt eine der beiden Dateien lokal, kommt dieses System von einer Version vor 1.3.** Dann gilt zuerst der Sonderfall ganz unten in diesem Skill, und die beiden Dateien liest du so lange aus der Zielversion (`git show <Zielversion>:10_System/Kern-Dateien.md`) statt lokal.

## Schritte

### 1. Sicherheitsnetz spannen

Ohne diesen Schritt wird nicht weitergearbeitet.

```powershell
cd <Repo-Pfad aus MEIN-SYSTEM.md>
git status --short
```

Ist irgendetwas offen, alles committen, bevor das Update beginnt:

```powershell
$offen = @(git status --porcelain | ForEach-Object { ($_.Substring(3) -split ' -> ')[-1].Trim('"') })
if ($offen.Count -gt 0) { git add -- $offen; git commit -m "Stand vor Mechanik-Update" }
```

Hier wird bewusst alles Offene gestaged, abweichend von der Regel "nur die eigenen Pfade" in der `AGENTS.md`, Abschnitt 12: Der Zweck ist genau, den kompletten Ist-Zustand einzufrieren, damit jeder Schritt danach rückgängig gemacht werden kann. Aufgezählt statt pauschal, weil seit 3.3 der Hook `guard-git.ps1` die Formen `git add -A`, `--all` und `.` in jedem Modus sperrt und dieser Skill sich sonst selbst blockieren würde (gefunden im kalten Messlauf zum Release 3.3, bevor es ein Nutzer fand). Die Liste aus `git status` ergibt denselben Commit, nur mit sichtbaren Pfaden, und die Sperre bleibt unangetastet. Sag `[NAME]` in einem Satz, dass dieser Commit der Rückweg ist und wie er ihn nutzt: `git reset --hard <Commit-Hash>` stellt den Zustand von jetzt wieder her.

Gibt es kein Git-Repo in diesem Ordner, brich hier ab und sag es. Ohne Versionierung ist ein Update nicht verantwortbar; der Weg dorthin steht in `ANLEITUNG.md`, Teil 5.

### 2. Quelle anbinden und holen

Einmalig, falls noch nicht vorhanden:

```powershell
git remote add upstream https://github.com/flomeile/leo-core.git
git remote set-url --push upstream DISABLED
```

Existiert `upstream` bereits und zeigt noch auf die alte Adresse `flomeile/leo-starter` (prüfen mit `git remote -v`), wird er aktiv umgesetzt, statt auf die Umleitung von GitHub zu vertrauen; die Umleitung bricht, sobald jemand den alten Namen neu belegt:

```powershell
git remote set-url upstream https://github.com/flomeile/leo-core.git
git remote set-url --push upstream DISABLED
```

Dann immer:

```powershell
git fetch upstream --tags
```

Prüfe mit `git remote -v`, ob `upstream` schon existiert, bevor du ihn hinzufügst. Ein zweiter Versuch schlägt sonst fehl, was kein Problem ist, aber unnötig verwirrt.

**Die zweite Zeile ist neu und wird auch dann ausgeführt, wenn `upstream` schon existiert.** Sie schaltet die Push-Adresse dieses Remotes ab. `upstream` zeigt auf ein öffentliches Repository und wird nur zum Holen gebraucht; ein versehentliches `git push upstream main` hätte dagegen den kompletten Inhalt dieses privaten Systems dorthin geschrieben. In den meisten Fällen fängt GitHub das ohnehin ab, weil niemand ausser dem Herausgeber dort schreiben darf, aber das ist eine fremde Einstellung und keine eigene Absicherung. Nach `git remote -v` muss bei `(push)` `DISABLED` stehen; `git fetch upstream` funktioniert unverändert weiter, ein Push scheitert hörbar. Sag `[NAME]` in einem Satz, dass du das gemacht hast und warum.

### 3. Ausgangs- und Zielversion bestimmen

- **Zielversion:** der höchste Tag `vX.Y` nach dem Fetch, ermittelt mit `git tag -l "v*" --sort=v:refname`; der letzte Eintrag der Liste ist die Zielversion. Der Zusatz `--sort=v:refname` ist nicht optional: Ohne ihn sortiert Git die Tags als Text, und dabei steht `v1.10` vor `v1.9`, was die ältere Fassung zur Zielversion machen würde.
- **Ausgangsversion:** der Wert aus `MEIN-SYSTEM.md`, Abschnitt 4.

Sind beide gleich, ist nichts zu tun. Sag das und höre auf.

Ist die Angabe nicht lesbar (bei Systemen vor Version 1.3 fehlt sie ganz, bei späteren kann die Tabelle umgebaut worden sein), ermittle die Ausgangsversion selbst. **Nimm dafür die `AGENTS.md`**, sie ist der zuverlässigste Marker: bei allen Nutzern identisch, in jeder Version anders, und ihr Name ändert sich nie. Vergleiche sie gegen `git show vX.Y:AGENTS.md` der verfügbaren Tags und nimm die Version, die exakt passt; im Trockenlauf am 31.08.2026 traf das die richtige Version auf Anhieb, bei einem System mit zerstörter Versionstabelle. Die Kern-Skills taugen dafür nur eingeschränkt, weil sie bei umbenannten Systemen anders heissen als im Tag. Findest du keine Übereinstimmung, arbeite ohne Ausgangsversion weiter und behandle in Schritt 5 jede Kern-Datei als "lokal verändert". Das ist langsamer und fragt öfter, aber es ist sicher.

### 4. Verstehen, was sich geändert hat

Lies zwei Dinge, bevor du irgendetwas schreibst:

```powershell
git diff <Ausgangsversion>..<Zielversion> --stat
```

Und den Abschnitt "Versionen dieses Pakets" in der Upstream-Fassung der Anleitung:

```powershell
git show <Zielversion>:ANLEITUNG.md
```

**Der Diff ist kumulativ, und genau so ist er gemeint.** Er vergleicht den Zustand dieses Systems mit dem Zustand, der eingespielt werden soll, und überspringt dabei jede Zwischenversion. Das ist richtig und nicht ungenau: Springt ein System von 1.9 auf 2.6, zählt der Unterschied zwischen 1.9 und 2.6, nicht die sieben Schritte dazwischen. Eine Regel, die unterwegs eingeführt und wieder entfernt wurde, taucht deshalb gar nicht auf, und das ist korrekt, weil sie heute nicht gilt. Die Changelog-Zeilen liest du dagegen für **alle** übersprungenen Versionen, nicht nur für die Zielversion: Der Diff zeigt, was anders ist, die Zeilen sagen, warum. Sie stehen ohnehin alle in derselben Datei.

Fasse `[NAME]` in drei bis fünf Sätzen zusammen, was die neue Version bringt und warum es ihn interessiert. Kommt er über mehrere Versionen, sag ihm das ausdrücklich und nenne die Spanne. Das ist keine Höflichkeit: Wer nicht weiss, was sich ändert, kann in Schritt 5 nicht entscheiden. Dieselben Versionszeilen sind nach dem Update die Grundlage der Release Note, die den Bericht eröffnet (Schritt 9, Punkt 1); lies sie deshalb ganz, nicht nur die neueste.

### 4b. Konflikt-Check gegen die persönliche Ebene

Dieser Schritt läuft **vor dem ersten Schreibvorgang**, und dafür gibt es einen Grund: Solange nichts geschrieben ist, ist Nichtstun noch die billigste Option. Ein Konflikt zwischen der neuen Mechanik und dem, was `[NAME]` sich selbst eingerichtet hat, kann die Frage berühren, ob dieses Update überhaupt so eingespielt wird.

**Was gegen was gemessen wird:** links der heutige Zustand dieses Systems, rechts der Zustand nach dem Update, also die Zielversion. Nicht die Zwischenversionen, nicht "was v2.4 gebracht hat", sondern der kumulative Unterschied aus Schritt 4.

Auf der linken Seite liest du genau vier Dinge:

1. `MEIN-SYSTEM.md`, Abschnitt 2 (eigene Regeln)
2. `MEIN-SYSTEM.md`, Abschnitt 3 (eigene Bauten und eigene Änderungen an Kern-Dateien)
3. `MEIN-SYSTEM.md`, Abschnitt 5 (Setup: Werkzeug, Automatik, Besonderheiten)
4. Die eigenen Skills in `02_Skills`, die nicht in der Kernliste stehen

Für jede neue oder geänderte Regel aus Schritt 4: Widerspricht sie einem dieser vier Punkte? Typische Treffer sind ein neu zur Pflicht gewordenes Frontmatter-Feld gegen eine eigene Regel, die es aussetzt, ein umbenannter Kern-Skill, auf den ein eigener Skill zeigt, ein neuer Automatismus gegen eine Setup-Notiz, die ihn abgeschaltet hat, oder eine Regel, die sich umgekehrt hat.

**Lokale `AGENTS.md` in Themenordnern werden hier nicht durchsucht**, das wäre bei jedem Update ein kompletter Lesedurchgang über alle Themen. Stattdessen gehört in den Bericht ein Satz an `[NAME]`: Lokale Regeln unterhalb der Wurzel dürfen dem Grundgerüst nicht widersprechen, und wenn dir eine solche Stelle im Alltag auffällt, melde sie. Für dich als LLM gilt derselbe Satz als Daueraufgabe: Fällt dir bei normaler Arbeit in einem Themenordner eine lokale Regel auf, die gegen die Wurzel-`AGENTS.md` läuft, behandelst du sie nach denselben zwei Stufen wie unten.

**Zwei Stufen, wenn etwas gefunden wird:**

- **Stufe 1, du entscheidest**, wenn der Fall eindeutig ist: Die eigene Regel bezieht sich auf etwas, das es nicht mehr gibt, oder die neue Mechanik sagt dasselbe in besseren Worten. Dann trag die Auflösung vor und mach sie, sag im Bericht in einem Satz, was du getan hast.
- **Stufe 2, `[NAME]` entscheidet**, sobald es nicht eindeutig ist. Dann legst du es ihm so vor, dass ein Wort als Antwort reicht: was er heute eingestellt hat, was die neue Fassung will, was passiert, wenn er nichts tut, und ein empfohlener Weg, zuerst genannt und begründet. Keine Fachbegriffe aus dem Systeminneren, kein Diff, kein Dateipfad ohne Erklärung dazu.

**Steht in `MEIN-SYSTEM.md`, Abschnitt 5 der Nutzungsmodus `benutzen`, gilt Stufe 2 verschärft.** Dieser Mensch arbeitet inhaltlich mit dem System und hat nicht vor, sich mit seiner Mechanik zu befassen. Er bekommt den Konflikt in zwei, drei Sätzen Alltagssprache, mit deiner Empfehlung und der Frage, ob er ihr folgen will. Verstehe seine Antwort als Entscheidung und trag sie selbst ein. Kann er auch damit nichts anfangen, wähle den Weg, der seine eigene Einstellung erhält, und sag ihm, dass du das getan hast.

Findest du keinen Konflikt, steht das ebenfalls im Bericht, in einer Zeile. Ein stiller Schritt sieht aus wie ein vergessener.

### 5. Dateien einarbeiten, Kategorie für Kategorie

Gehe die Liste aus `10_System\Kern-Dateien.md` durch. Für jede Datei gilt genau einer der folgenden Fälle.

**Vorher, einmal für den ganzen Schritt: den lokalen Dateinamen bestimmen.** Die Kernliste nennt die Skills mit dem Präfix des Grundgerüsts (`leo-`). Hat der Nutzer sein System umbenannt, heissen seine Dateien anders, und dann zeigt die Liste auf einen Namen, den es hier nicht gibt. Löse deshalb für jeden Kern-Skill zuerst auf, wie er lokal wirklich heisst:

1. Präfix aus `MEIN-SYSTEM.md`, Abschnitt 1, Zeile "Skill-Präfix" lesen.
2. In `02_Skills` die Datei suchen, deren Name auf denselben Teil hinter dem Präfix endet (aus `leo-wrap-up.md` wird bei Präfix `w1-` also `w1-wrap-up.md`).
3. Gibt es sie, ist das der lokale Name. Gibt es sie nicht, ist der Skill neu und wird unter dem lokalen Präfix angelegt.
4. Existieren beide Namen nebeneinander, wird nichts überschrieben: melden und `[NAME]` fragen, welcher gilt. Zwei Dateien mit denselben Trigger-Worten sind ein stiller Fehler, der erst auffällt, wenn der falsche Skill läuft.

Fehlt `MEIN-SYSTEM.md` oder steht dort noch der Platzhalter, gilt `leo-` wie ausgeliefert.

**Kategorie A, lokal unverändert.** Bei gleichnamigen Dateien fragst du das Git selbst, statt Texte zu vergleichen:

```powershell
git diff --quiet <Ausgangsversion> -- "<datei>"
```

Exitcode 0 heisst unverändert, alles andere heisst verändert. **Vergleiche den Text nicht von Hand**, und wenn doch, normalisiere vorher die Zeilenenden. Der Grund ist gemessen (Trockenlauf 31.08.2026): Der Pre-Commit-Hook lag lokal mit LF und kam aus `git show` mit CRLF zurück, Byte für Byte derselbe Inhalt, 218 Unterschiede im nackten Textvergleich. Ein Kind-System hätte die Datei fälschlich als "vom Nutzer angepasst" behandelt und den Nutzer unnötig gefragt. Git kennt die Regeln aus `.gitattributes` und macht diesen Fehler nicht.

Für umbenannte Dateien (anderes Präfix) geht dieser Befehl nicht, weil Git sie als andere Datei sieht. Dort vergleichst du den Inhalt gegen `git show <Ausgangsversion>:02_Skills/leo-<name>.md` und ersetzt vorher in beiden Fassungen `\r\n` durch `\n`.

Unterschiede innerhalb von `AUTO:...:BEGIN/END`-Blöcken zählen in beiden Fällen nicht, die werden ohnehin neu erzeugt. Ist die Datei unverändert, übernimm die neue Fassung.

Bei gleichem Dateinamen genügt:

```powershell
git checkout <Zielversion> -- "<datei>"
```

Heisst die Datei lokal anders, wird der Inhalt geholt und unter dem lokalen Namen abgelegt, damit nicht eine zweite Datei neben der eigenen entsteht:

```powershell
git show "<Zielversion>:02_Skills/leo-<name>.md" | Set-Content -LiteralPath "02_Skills\<lokales-praefix><name>.md" -Encoding UTF8
```

Der Dateiname des Nutzers bleibt in beiden Fällen unangetastet, aktualisiert wird nur der Inhalt.

**Kategorie A, lokal verändert.** Der Nutzer hat eingegriffen, ob absichtlich oder nicht. Jetzt wird nicht ersetzt. Lies drei Fassungen: die lokale, die alte Upstream-Fassung, die neue Upstream-Fassung. Bestimme daraus, was die neue Version inhaltlich ändert, und trage genau diese Änderung in die lokale Fassung ein, ohne die Anpassung des Nutzers anzurühren. Berührt die Neuerung dieselbe Stelle, an der der Nutzer etwas geändert hat, entscheidest du nicht selbst: Zeig beide Fassungen und frag, welche gilt.

Melde am Ende jede Datei dieser Gruppe, auch die, die glattgegangen ist. `[NAME]` muss wissen, wo sein System vom Grundgerüst abweicht.

**Kategorie B.** Immer einarbeiten, nie ersetzen. Welche Dateien dazugehören, steht in `10_System\Kern-Dateien.md` und nicht in dieser Aufzählung; die Liste dort wächst, diese hier ist nur die Erklärung, was "einarbeiten" jeweils heisst. Ein Vergleich gegen die Liste ist Pflicht, bevor du eine Datei anfasst.

- **`CLAUDE.md`, `GEMINI.md`, `.clinerules`, `.github\copilot-instructions.md`:** Der lokale Anteil sind die `@`-Importzeilen bzw. die textliche Leseanweisung, die auf die tatsächlich vorhandenen Basiskontext-Dateien zeigen. Übernimm alles Neue aus der Zielversion, lass die Zeilen des Nutzers unverändert stehen, auch wenn sie andere Dateinamen tragen als das Grundgerüst.
- **`.claude\settings.json`:** Das ist eine JSON-Datei, kein Fliesstext, und sie wird zusammengeführt statt überschrieben. Vorgehen: Lies die lokale Datei vollständig, nimm aus der Zielversion NUR die Schlüssel dazu, die lokal fehlen, und lass alles Bestehende unangetastet, insbesondere `permissions.allow` und `permissions.deny`. In der Regel sind die einzigen neuen Einträge die Hooks unter `hooks.PreToolUse`: die Arbeitsbereich-Sperre (`guard-workspace.ps1`), seit 3.3 die Sperre gegen pauschales Stagen (`guard-git.ps1`), seit 3.4 die Mailversand-Sperre (`guard-mail.ps1`) und seit 3.8 die Lese-Sperre (`guard-read.ps1`, Matcher `Read|Grep|Glob|NotebookRead|Bash|PowerShell`); fehlt einer davon lokal, wird genau dieser Eintrag ergänzt. Die Zielversion trägt seit 3.8 ausserdem `permissions.deny` mit Lese-Verboten für Schlüsseldateien; das ist die zweite, werkzeugeigene Ebene neben dem Hook und wird beim Nutzer NICHT ergänzt, weil `permissions` ihm gehört; er kann die Zeilen aus der Zielversion selbst übernehmen. Zur Lese-Sperre gehört die Keimdatei `00_INDEX\gesperrte-pfade.txt` (Kategorie B): fehlt sie lokal, wird sie aus der Zielversion angelegt, existiert sie, bleibt sie unangetastet. Hat der Nutzer dort bereits eigene Hooks, wird der neue Eintrag ergänzt und kein bestehender ersetzt. Läuft das System unter macOS/Linux, trägt der lokale Anteil in jedem Hook-Befehl den ausgeschriebenen `pwsh`-Pfad statt `powershell`; ein neuer Eintrag bekommt dieselbe Form wie die vorhandenen. **Claude Code fragt beim Schreiben dieser Datei immer nach**, weil sie Hooks trägt; in einem Lauf ohne Bedienung (etwa `claude -p`) wird der Prompt nie bestätigt. Dann nicht dreimal probieren, sondern einmal, und den fertigen JSON-Block für den fehlenden Eintrag im Bericht vorlegen, damit `[NAME]` ihn selbst einträgt oder den Prompt in einer bedienten Session bestätigt (gemessen im kalten Lauf zu 3.3). Existiert die Datei lokal gar nicht, leg sie aus der Zielversion an. **Diese Datei nie blind mit `git checkout <Zielversion> -- .claude/settings.json` überschreiben:** Der Nutzer verliert damit stillschweigend alle Berechtigungen, die er sich eingerichtet hat, und merkt es erst, wenn ihn das Werkzeug bei jedem zweiten Befehl wieder fragt.

- **`00_INDEX\scripts\lib\gmail-senden.py` und `mail-sperrbegriffe.txt`** (seit 3.4): Beim Sendeskript ist der lokale Anteil der Konfigurationsblock am Anfang zwischen `# --- KONFIGURATION` und `# --- ENDE KONFIGURATION` (Name, Adressen, Signatur, Routinen, Domains, Wartezeit). Vorgehen: die lokale Datei lesen, den Block herausschneiden, die Zielversion übernehmen und den lokalen Block an die Stelle des Blocks der Zielversion setzen; bringt die Zielversion einen neuen Schlüssel im Block mit, wird er mit seinem Standardwert ergänzt und im Bericht genannt. Die Datei nie mit `git checkout <Zielversion> -- ...` überschreiben: Der Nutzer verliert damit seine Adressen, und das Skript sendet danach nicht mehr (Platzhalter-Sperre), was erst beim nächsten Mailversuch auffällt. Die Sperrliste `mail-sperrbegriffe.txt` gehört dem Nutzer vollständig; existiert sie lokal, bleibt sie unangetastet, fehlt sie, kommt die Keimdatei aus der Zielversion.
- **`.codex\hooks.json`:** Ebenfalls JSON und ebenfalls zusammenführen statt überschreiben, mit einer Besonderheit: Der lokale Anteil ist der ausgeschriebene Pfad zum Repo des Nutzers. Codex kennt keine Pfad-Abkürzung, deshalb steht dort ein echter Pfad, wo die Zielversion nur den Platzhalter `PFAD-ZU-DEINEM-REPO` trägt. **Diesen Platzhalter nie zurückschreiben:** Damit wäre die Sperre in Codex ab dem nächsten Start wirkungslos, ohne dass irgendetwas fehlschlägt. Existiert die Datei lokal nicht und arbeitet der Nutzer gar nicht mit Codex, leg sie an und sag ihm in einem Satz, dass sie unbenutzt danebenliegt, statt sie stillschweigend wegzulassen. Und weise ihn darauf hin, dass ein neuer Hook in Codex erst nach seiner Freigabe in der Oberfläche wirkt (`ANLEITUNG.md`, Teil 5, Schritt 7b).

Ein Hinweis zur Arbeitsbereich-Sperre, damit du sie richtig einordnest: Die mitgelieferten Hook-Befehle rufen als Windows-Vorlage `powershell` auf. Unter macOS/Linux muss der lokale Anteil stattdessen den absoluten Pfad zu `pwsh` und POSIX-Pfade enthalten (`ANLEITUNG.md`, Teil 5, Schritt 7a/7b). Solange das nicht eingerichtet und gegengemessen ist, schlägt der Hook-Aufruf dort fehl, ohne etwas zu blockieren; die Regel in `AGENTS.md` Abschnitt 18 gilt dann als reine Textregel weiter. Melde das dem Nutzer, statt den Hook-Eintrag stillschweigend wegzulassen.

**Kategorie C.** Nicht anfassen. Kein Ausnahmefall, keine Ausrede, auch nicht "das wäre aber besser so".

**Dateien, die in keiner der drei Kategorien stehen, gehören zu C und werden nicht ersetzt.** Das gilt auch dann, wenn sie lokal unverändert sind und ein Ersetzen deshalb harmlos aussieht: Genau so verschwindet eine Anpassung, die jemand später gemacht hat und die niemand mehr findet. Gemessen am 31.08.2026 in einem kalten Lauf, in dem ein Update vier solche Dateien mitnahm und das selbst als Ermessensentscheidung bezeichnete. Fällt dir eine Datei auf, die offensichtlich zum Grundgerüst gehört und trotzdem fehlt, ist das ein Fehler in der Liste: melden, damit sie dort ergänzt wird, und in diesem Lauf die Finger davon lassen.

**Neue Kern-Dateien.** Bringt die Zielversion eine Datei mit, die es lokal nicht gibt, leg sie an und sag, wozu sie da ist.

**Gelöschte Kern-Dateien.** Fehlt eine Datei in der Zielversion, die lokal existiert: nicht löschen, nur melden. Löschen entscheidet `[NAME]`.

### 5b. Skill-Register nachziehen

`02_Skills\Skill-Register.md` gehört dem Nutzer (Kategorie C) und wird deshalb nie ersetzt. Trotzdem hängt die Mechanik daran: Das Index-Skript baut aus dem Register die Skill-Kurzliste in der `AGENTS.md`, und nur was dort steht, sieht das LLM im Alltag. Bleibt das Register auf dem alten Stand, ist ein neuer Kern-Skill zwar als Datei da und für die tägliche Arbeit trotzdem unsichtbar.

Gemessen im Trockenlauf am 31.08.2026 an einem System, das von 2.0 kam: Nach einem formal fehlerfreien Update standen vier neue Kern-Skills im Ordner und in keiner Liste, und die Spalte "Von selbst, wenn" blieb komplett leer, weil das Register sie noch gar nicht kannte. Die situative Skill-Auslösung, das Hauptmerkmal der Version, wäre bei diesem Nutzer nie angesprungen, ohne dass irgendetwas nach Fehler ausgesehen hätte.

Deshalb dieser Schritt, und weil die Datei dem Nutzer gehört, mit Ansage statt stillschweigend. Drei Dinge, in dieser Reihenfolge:

1. **Spalten angleichen.** Vergleiche die Kopfzeile der Register-Tabelle mit der aus der Zielversion (`git show <Zielversion>:02_Skills/Skill-Register.md`). Fehlt eine Spalte, ergänze sie samt Trennzeile und fülle sie für die Kern-Skills aus deren Zielfassung. Für die eigenen Skills des Nutzers lässt du die neue Zelle leer und sagst ihm, was dort hingehört und warum es sich lohnt.
2. **Dateinamen auf das lokale Präfix ziehen.** Nennt das Register `leo-…`, während die Dateien anders heissen, sind das tote Verweise; der Health-Check meldet sie als FAIL. Namen angleichen, Zweck und Trigger unverändert lassen.
3. **Neue Kern-Skills eintragen**, mit Name, Trigger-Worten, Datei unter dem lokalen Präfix, Zweck und dem situativen Anlass aus der Zielfassung.
4. **Dieselbe Namensangleichung in den kuratierten Index-Beschreibungen** in `00_INDEX\INDEX.md`. Dort steht je Datei eine Zeile `- **Pfad** — Beschreibung`; nennt sie einen Skill unter dem Grundgerüst-Präfix, den es lokal anders gibt, zieh den Namen nach. Sonst meldet der Health-Check diese Zeilen als tote Verweise (FAIL, Kategorie Index-Abdeckung).
5. **Für jeden neu dazugekommenen Kern-Skill eine kuratierte Index-Beschreibung schreiben**, im selben Format wie die bestehenden. Ohne sie findet keine Suche den Skill, und der Health-Check meldet ihn als unbeschrieben.

Eigene Skills des Nutzers rührst du dabei nicht an, ausser um eine fehlende Spalte anzulegen. Sag in einem Satz, was du am Register und an den Index-Beschreibungen geändert hast.

### 6. Prüfen, ob die eigenen Bauten noch passen

Der Teil, den kein Git-Befehl leisten kann und der der eigentliche Grund ist, warum dieser Skill existiert.

Nimm die Liste "Was ich selbst gebaut habe" aus `MEIN-SYSTEM.md` und dazu alles, was in `02_Skills` liegt und nicht in der Kern-Liste steht. Prüfe für jeden eigenen Skill und jede eigene Konvention, ob die Änderungen aus Schritt 4 sie berühren. Typische Fälle: Das Frontmatter-Schema wurde erweitert, eine Statuszeile hat neue Token bekommen, ein Kern-Skill wurde umbenannt und ein eigener Skill verweist auf den alten Namen, eine Regel hat sich umgekehrt.

Git meldet hier nichts, weil sich die Dateien nicht berühren. Ein eigener Skill, der gegen die alte Norm arbeitet, läuft nach dem Update weiter und tut das Falsche.

Melde jeden Fund mit der konkreten Zeile und einem fertigen Vorschlag, was zu ändern wäre. Ändere die eigenen Skills des Nutzers nicht selbst, ausser er sagt es.

### 7. Nachziehen und prüfen

```powershell
powershell -File 00_INDEX\scripts\build-index-geruest.ps1
```

Das füllt die `AUTO:...`-Blöcke wieder, insbesondere die Rollen-Tabelle und die Skill-Kurzliste in der `AGENTS.md`. Danach die Skill-Zeiger neu erzeugen, sonst fehlen die neuen Skills in allen Werkzeug-Verzeichnissen und springen dort nicht an:

```powershell
powershell -File 00_INDEX\scripts\build-skill-wrapper.ps1
```

Und zuletzt:

```powershell
powershell -File 00_INDEX\scripts\health-check.ps1
```

Meldet der Health-Check etwas Neues, das vorher nicht da war, gehört es in den Bericht.

**Führt das Update über 3.8 und hat `00_INDEX\gesperrte-pfade.txt` keinen Eintrag** (der Health-Check meldet das als WARN), fragst du `[NAME]` noch in derselben Antwort, welche Ordner auf seinem Rechner in keine Cloud-KI dürfen (Kundenkonfigurationen, Exporte unter NDA, Gesundheitsdaten, alles unter Geheimhaltung), mit einem Beispielpfad, wie ein Eintrag aussieht. Trag seine Antwort selbst ein, eine Zeile je Pfad; sagt er, es gebe nichts, trag das Wort `keine` ein. Das ist die einzige Situation, in der das LLM diese Datei schreibt, und nur mit seinem Wort im selben Gespräch (AGENTS.md, Abschnitt 18). Ohne diese Frage bleibt die Lese-Sperre bei den eingebauten Mustern stehen, und genau die Ordner, für die sie gebaut ist, bleiben offen.

### 8. Stand fortschreiben und committen

In `MEIN-SYSTEM.md`, Abschnitt 4: eingespielte Version und Datum auf den neuen Stand. Trägt der Nutzer Abweichungen an Kern-Dateien mit sich, ergänze Abschnitt 3 um das, was du in Schritt 5 gefunden hast.

**Das sind die einzigen beiden Abschnitte dieser Datei, in die du je schreibst**, dazu der Schutzhinweis unmittelbar darunter. Abschnitt 1, 2 und 5 gehören dem Nutzer, dort ändert ein Update nichts (`10_System\Kern-Dateien.md`, Kategorie C).

**Schutzhinweis nachtragen, falls er fehlt.** Systeme, die vor 2.4 eingerichtet wurden, haben über Abschnitt 3 und 4 keinen Hinweis stehen, dass diese beiden Abschnitte der Skill führt. Ohne ihn baut früher oder später jemand die Versionstabelle um, und danach findet weder dieses Update noch der Health-Check die eingespielte Version. Vorgehen:

1. Prüfen, ob über Abschnitt 3 und über Abschnitt 4 bereits ein solcher Hinweis steht (erkennbar am Zitatblock mit `>` direkt unter der Überschrift).
2. Fehlt er, hol den Wortlaut aus der Zielversion (`git show <Zielversion>:MEIN-SYSTEM.md`) und setz genau diese zwei Blöcke ein, jeweils direkt unter die Überschrift. Sonst nichts an der Datei ändern.
3. Steht er schon da, tu nichts.

Diese Prüfung bleibt dauerhaft in diesem Skill und wird nicht wieder entfernt. Sie fragt den Zustand ab und nicht die Versionsnummer, deshalb läuft sie pro System genau einmal, sie kann nichts doppelt eintragen, und sie greift auch dann, wenn ein System die 2.4 überspringt und von einer älteren Fassung direkt auf eine spätere geht. Sag dem Nutzer in einem Satz, dass du sie eingesetzt hast und warum.

**`stand:` im Frontmatter von `MEIN-SYSTEM.md` auf das heutige Datum setzen**, sobald du an der Datei etwas geändert hast. Ohne das meldet der Health-Check nach jedem Update eine Drift ("Datei wurde nach ihrem stand-Datum geändert"), und zwar bei jedem Nutzer, jedes Mal.

**Führt das Update auf 2.x und fehlt in `MEIN-SYSTEM.md`, Abschnitt 5 ein gesetzter Nutzungsmodus** (Platzhalter oder leer): Frag den Besitzer jetzt, erkläre den Unterschied in zwei, drei Sätzen (`mitbauen`: er löst Wartung und Updates selbst mit Trigger-Worten aus; `benutzen`: das System wartet und aktualisiert sich selbst und fragt nur vor einem Update), trag seine Antwort selbst dort ein und bestätige es in einem Satz. Du bist verantwortlich, dass der Eintrag sauber steht und der Besitzer weiss, was er entschieden hat (AGENTS.md, Abschnitt 1, seit 2.1). Mag er nicht entscheiden, setz `benutzen` und sag ihm, wie er es ändert.

Dann committen, mit einer Nachricht, die den Versionssprung nennt:

```powershell
$offen = @(git status --porcelain | ForEach-Object { ($_.Substring(3) -split ' -> ')[-1].Trim('"') })
git add -- $offen
git commit -m "Mechanik-Update auf Grundgeruest <Zielversion>"
```

Auch hier pfadweise statt `git add -A`, aus demselben Grund wie beim Checkpoint in Schritt 1: Die Sperre `guard-git.ps1` lässt die pauschale Form nicht durch, und alles Offene stammt in diesem Moment aus dem Update selbst.

Push nur, wenn ein `origin` existiert.

### 9. Bericht

Kurz und in dieser Reihenfolge:

1. **Die Release Note, zuoberst und in fester Form** (Vorgabe des Herausgebers, seit 3.9): je eingespielter Version, auch je übersprungener, ein Block mit genau drei Zeilen, aus der Versionszeile der `ANLEITUNG.md` verdichtet, nicht abgeschrieben: **Was sich ändert** (ein bis zwei Sätze, die Neuerung selbst, keine Dateiliste), **Was es dir bringt** (ein Satz aus der Sicht von `[NAME]`), **Was du tun musst** (der Satz aus der Versionszeile; steht dort "nichts", steht hier "nichts"). Bei mehr als drei Versionen in einem Sprung die drei jüngsten so, die älteren in je einer Zeile. Alltagssprache, keine Skript- oder Dateinamen ausser dort, wo `[NAME]` selbst eine Datei anfassen muss, **und in der Arbeitssprache aus `MEIN-SYSTEM.md`, Abschnitt 1** (seit 4.0): Die Versionszeilen der `ANLEITUNG.md` sind deutsch; ist die Arbeitssprache eine andere, wird die Release Note übersetzt, nicht die deutsche Zeile gezeigt. Der Grund: Wer ein Update bekommt und nicht erfährt, was es ändert, kann es weder nutzen noch beurteilen; eine Versionszeile in einer Datei, die niemand öffnet, ist keine Meldung.
2. Von welcher auf welche Version, und ob dabei Versionen übersprungen wurden.
3. Was der Konflikt-Check ergeben hat (Schritt 4b): jeder Fund, wie er aufgelöst wurde, und was noch offen bei `[NAME]` liegt. Kein Fund heisst eine Zeile, nicht Schweigen.
4. Was am Skill-Register geändert wurde (Schritt 5b): ergänzte Spalten, angeglichene Dateinamen, neu eingetragene Skills.
5. Welche Dateien ersetzt wurden.
6. Welche Dateien eingearbeitet wurden, weil lokale Anpassungen darin standen.
7. Was an eigenen Bauten geprüft wurde und was dabei aufgefallen ist.
8. Der Satz zu den lokalen `AGENTS.md` unterhalb der Wurzel (Schritt 4b).
9. Der Commit-Hash aus Schritt 1 als Rückweg.

## Definition of Done

- Kein Inhalt aus Kategorie C wurde verändert. In `MEIN-SYSTEM.md` wurden ausschliesslich Abschnitt 3, Abschnitt 4 und der Schutzhinweis darüber angefasst.
- Der Konflikt-Check aus Schritt 4b ist gelaufen, vor dem ersten Schreibvorgang, und sein Ergebnis steht im Bericht.
- Jede lokal angepasste Kern-Datei wurde eingearbeitet statt ersetzt, und jede davon steht im Bericht.
- Kein Kern-Skill liegt doppelt, unter zwei Präfixen, im Ordner `02_Skills`.
- Das Skill-Register trägt alle Kern-Skills unter ihrem lokalen Namen, mit allen Spalten der Zielversion, und das Index-Skript ist danach gelaufen (Schritt 5b und 7).
- `MEIN-SYSTEM.md` trägt ein aktuelles `stand:`-Datum, wenn daran etwas geändert wurde.
- Die eigenen Skills wurden gegen die neuen Konventionen geprüft.
- `MEIN-SYSTEM.md`, Abschnitt 4 trägt die neue Version, und über Abschnitt 3 und 4 steht der Schutzhinweis.
- Index-Skript und Health-Check sind gelaufen.
- `[NAME]` kennt den Commit, auf den er zurücksetzen kann.

## Sonderfall: erstes Update von einer Version vor 1.3

Erkennbar daran, dass `MEIN-SYSTEM.md` und `10_System\Kern-Dateien.md` lokal fehlen. Bis Version 1.2 gab es die Trennung von Mechanik und persönlicher Ebene nicht: Der Nutzer hat damals bei der Einrichtung den Platzhalter `[NAME]` überall in der `AGENTS.md` durch seinen Namen ersetzt, vielleicht auch das System umbenannt. Die neue `AGENTS.md` bringt `[NAME]` bewusst zurück. Ein blosses Ersetzen würde die Personalisierung also löschen.

Deshalb kommt vor Schritt 5 eine Migration. Reihenfolge:

1. **Werte aus der alten `AGENTS.md` auslesen**, bevor du sie anfasst: Wie heisst die Person (steht überall dort, wo im Original `[NAME]` stand)? Wie heisst das System (steht "Leo" oder etwas anderes)? Wo liegt das Repo? Welches Skill-Präfix tragen die Dateien in `02_Skills`?
2. **Eigene Regeln finden.** Vergleiche die lokale `AGENTS.md` mit `git show <Ausgangsversion>:AGENTS.md`. Alles, was über die Namensersetzung hinausgeht, hat der Nutzer selbst ergänzt. Das ist der wertvollste Teil und darf auf keinen Fall verloren gehen.
3. **`MEIN-SYSTEM.md` aus der Zielversion holen** (`git checkout <Zielversion> -- MEIN-SYSTEM.md`) und sofort füllen: Abschnitt 1 mit den Werten aus Punkt 1, Abschnitt 2 mit den eigenen Regeln aus Punkt 2, Abschnitt 3 mit allem, was der Nutzer sonst an Kern-Dateien geändert hat, Abschnitt 4 mit der Zielversion.
4. **Dem Nutzer zeigen, was du nach `MEIN-SYSTEM.md` übertragen hast, und bestätigen lassen.** Erst danach die neue `AGENTS.md` einspielen. Das ist die einzige Stelle in diesem Skill, an der eine Bestätigung zwingend ist, weil hier eine gewachsene Datei durch eine generische ersetzt wird.
5. Danach weiter mit Schritt 5 des normalen Ablaufs für alle übrigen Dateien.

Zwei Dinge, die dabei oft übersehen werden: Der Nutzer hat vielleicht die kursive Hinweiszeile am Anfang der alten `AGENTS.md` gelöscht, wie es die damalige Anleitung verlangte; das ist keine eigene Regel, sondern erwartetes Verhalten und braucht keine Rückfrage. Und heisst das System nicht "Leo", tragen die Skill-Dateien womöglich ein anderes Präfix; dann bleibt dieses Präfix, und nur der Inhalt der Kern-Skills wird aktualisiert, nicht ihr Dateiname.

## Wenn etwas schiefgeht

Der Zustand vor dem Update liegt im Commit aus Schritt 1. `git reset --hard <Hash>` stellt ihn vollständig wieder her, inklusive aller Dateien, die dieser Skill angefasst hat. Sag das dem Nutzer im Zweifel lieber einmal zu viel.
