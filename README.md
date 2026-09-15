---
titel: Leo
zweck: Einstiegspunkt für Menschen
type: readme
---

# Leo: Dein Second Brain

Harness-unabhängiges Wissenssystem. Alles Wissen liegt als Markdown in thematischen Ordnern; jedes LLM mit Datei- und Werkzeug-Zugriff kann darauf arbeiten.

Dies ist **Leo Core**, Version 3.7: das leere Grundgerüst mit der kompletten Mechanik, aber ohne Inhalte. Du füllst es mit deinen eigenen Themen. Bis Version 2.6 hiess dieses Repo `leo-starter`; "Starter" beschrieb den ersten Tag, "Core" beschreibt, was es geworden ist: ein laufend aktualisierter Kern, den die abgeleiteten Systeme ziehen (Skill `leo-mechanik-update`) und an den sie Verbesserungen zurückschicken. Die Kernschicht, die ein Update ersetzt, steht in `10_System\Kern-Dateien.md`; alles Persönliche bleibt stehen.


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
