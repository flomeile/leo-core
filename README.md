---
titel: Leo
zweck: Einstiegspunkt für Menschen
type: readme
---

# Leo: Dein Second Brain

Harness-unabhängiges Wissenssystem. Alles Wissen liegt als Markdown in thematischen Ordnern; jedes LLM mit Datei- und Werkzeug-Zugriff kann darauf arbeiten.

Dies ist **Leo Core**, Version 5.3: das leere Grundgerüst mit der kompletten Mechanik, aber ohne Inhalte. Du füllst es mit deinen eigenen Themen. Bis Version 2.6 hiess dieses Repo `leo-starter`; "Starter" beschrieb den ersten Tag, "Core" beschreibt, was es geworden ist: ein laufend aktualisierter Kern, den die abgeleiteten Systeme ziehen (Skill `leo-mechanik-update`) und an den sie Verbesserungen zurückschicken. Die Kernschicht, die ein Update ersetzt, steht in `10_System\Kern-Dateien.md`; alles Persönliche bleibt stehen.

## Ab Werk zu: was dein Agent auf deinem Rechner sieht

**Seit 5.0 liest und schreibt dein Agent nur in seinem Arbeitsbereich:** im eigenen Repo, in den Ordnern `<Repo> Archiv` und `<Repo> Artifacts` daneben und im Scratchpad seines Werkzeugs. Alles andere auf deinem Rechner ist für ihn zu, bis du es selbst freigibst; Zugangsdaten (`.env`-Dateien, Schlüssel, `.ssh`, `.aws`, Token-Dateien) bleiben immer zu. Der Grund: Was dein Agent liest, geht an den Anbieter des Sprachmodells, und was er ausserhalb des Repos verändert, kann Git nicht zurückholen.

**Freigeben kannst nur du**, mit dem Befehl `00_INDEX\scripts\freigeben.ps1` in deinem eigenen PowerShell-Fenster, und jedes Mal entscheidest du, ob dein Agent dort nur lesen oder auch schreiben darf. Dein Agent kann das nicht, auch nicht auf deine Bitte hin; braucht er einen Ordner, erklärt er dir den Grund und gibt dir den fertigen Befehl. **Ehrlich zur Grenze:** Die Sperre besteht aus Hooks, die vor jedem Schritt des Agenten prüfen. Sie fangen das Versehen zuverlässig ab, aber allein nicht die Absicht; wer sie gezielt umgehen will, kommt vorbei. Seit 5.1 bleibt die Sperre zu, wenn ein Hook nicht startet, und mit einem Befehl kannst du sie härten: Die Sperren kommen in einen Systemordner, den nur ein Administrator ändern kann, und dein Agent kann sie dann nicht mehr abschalten (`ANLEITUNG.md`, Teil 5, Schritt 7c).

**Auf macOS und Linux brauchst du PowerShell 7, bevor du deinen Agenten startest** (`brew install --cask powershell`, danach ein Einrichtungsbefehl, `ANLEITUNG.md`, Teil 5, Schritt 7a). Ohne PowerShell 7 kann dein Agent nichts lesen, nichts schreiben und keinen Befehl ausführen, weil die Sperre zu bleibt, wenn sie nicht startet. Getestet ist der Kern nur unter Windows; Rückmeldungen vom Mac sind als Issue oder Pull Request willkommen.

## Zwei Regeln für den Betrieb

**1. Lass den Agenten am System arbeiten, nicht dich selbst.** Wenn etwas angelegt, umgebaut, aufgeräumt oder aktualisiert werden soll, sag es deinem Agenten, statt die Dateien von Hand zu bearbeiten. Der Grund steht in diesem Repo: Die `AGENTS.md` und die Skills enthalten die genauen Anweisungen, wie das jeweils zu geschehen hat, damit Index, Verweise, Frontmatter und Versionierung konsistent bleiben. Der Agent liest sie und hält sich daran, du müsstest sie erst nachlesen. Inhalte selbst schreiben ist etwas anderes und jederzeit in Ordnung, dafür ist es dein Repo.

**2. Hol dir hin und wieder die Updates.** Das Gerüst wird weiterentwickelt. Sag dazu einfach "mechanik update" zu deinem Agenten. Er holt die neue Fassung von GitHub und arbeitet sie ein, ohne deine Inhalte, deine Personalisierung oder deine selbstgebauten Skills anzutasten. Wie das abgesichert ist, steht in `ANLEITUNG.md`, Teil 8 und in `10_System\Kern-Dateien.md`.

## Einen Fehler in der Mechanik gefunden?

Melde ihn als Issue **in diesem Repo** (`flomeile/leo-core`), nicht in deiner eigenen Kopie. Hast du die Behebung schon gebaut, geht sie als Pull Request aus einem Fork dieses Repos zurück; der Ablauf steht in `ANLEITUNG.md`, Teil 8, "Verbesserungen zurückgeben". Beim Anlegen erscheint die Vorlage "Befund an der Mechanik". Sie fragt genau das ab, was zur Behebung gebraucht wird, insbesondere deine Umgebung: Die meisten Befunde hängen daran, und was auf einem Rechner läuft, beweist nichts über den anderen.

**Zwei Dinge, die dabei zählen.** Dieses Repo ist öffentlich und ein Issue bleibt dauerhaft auffindbar, deshalb gehört kein Inhalt aus deinem eigenen System hinein, keine Personendaten und kein wörtliches Zitat aus einer privaten Datei. Und ein Befund wird gemessen statt übernommen: Ein Vorschlag kann zutreffen und trotzdem mit einer Konvention kollidieren, die von aussen nicht sichtbar ist. Wird er abgeändert, steht der Grund als Antwort im Issue.

## Zuerst lesen

**`ANLEITUNG.md`** im Root: Sinn, Funktionsweise und die Schritt-für-Schritt-Einrichtung. Das ist dein Startpunkt. Sie deckt zwei Wege ab, einen mit eigenem Windows-Rechner und einen ohne eigenen Rechner (nur Tablet), und markiert Erklärungen für Einsteiger als **Grundlagen**-Kästen, die ein erfahrener Leser überspringen kann.

## Einstieg (nach der Einrichtung)

- **Für LLMs und Agents:** `AGENTS.md` im Root (Master-Anweisung, Mechanik) plus `MEIN-SYSTEM.md` (deine persönliche Ebene darüber, hat bei Widerspruch Vorrang). Themenordner haben eigene lokale `AGENTS.md` (Rollen).
- **Für dich:** `10_System\Manual.md` (Bedienung: welches Werkzeug wofür, wie prompten, Wartung).
- **Landkarte:** `00_INDEX\INDEX.md` (Baum + Bereiche), lokale `_INDEX.md` je Themenordner.

## Struktur (Kurzfassung)

- Systemordner: `00_INDEX` Landkarte, `01_Basiskontext` Kernkontext (geschützt), `02_Skills` Skills, `03_Sessionlogs` Session-Wissen, `04_Changelog` Basiskontext-Protokoll, `10_System` Systemdoku
- Themenordner (`2X_*`): dein thematisches Wissen mit eigener Rolle, legst du selbst an. `90_Inbox` ist die Rohablage.

Versionierung: Git, automatischer Push auf ein privates GitHub-Repo (Task Scheduler + optional Obsidian-Git).
