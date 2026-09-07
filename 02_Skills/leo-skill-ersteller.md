---
name: leo-skill-ersteller
trigger: '"neuen skill", "skill erstellen", "skill bauen"'
zweck: Baut einen neuen Skill normgerecht und trägt ihn ins Register ein
type: skill
version: 1.7
---

# Skill: Leo Skill-Ersteller

Baut neue Skills so, dass sie im System zuverlässig funktionieren. Diese Datei ist auch der Bauplan (Norm), an dem sich jeder Skill orientiert.

## Norm: So muss jeder Skill aufgebaut sein

1. **Ablageort und Name:** `02_Skills\leo-<name>.md` — die Repo-Datei ist die einzige Wahrheit. Das Präfix `leo-` ist Pflicht, es macht sichtbar, dass der Skill in C:\Leo liegt und von dort funktioniert, unabhängig vom Harness. Keine harness-spezifischen Command-Dateien als Ersatz oder Kopie.
2. **Harness-neutral:** Der Skill muss aus jedem Harness mit Datei-Zugriff plus PowerShell ausführbar sein (Coding-Agent UND Chat-Session). Native Werkzeuge bevorzugen, PowerShell nur wo nötig; wo PowerShell nötig ist, den Befehl konkret angeben.
3. **Frontmatter:** name (mit `leo-`-Präfix), trigger (Liste der Trigger-Worte, OHNE Präfix, so wie sie natürlich gesagt/getippt werden), zweck, type: skill, version.
4. **Titel:** `# Skill: Leo <Name>`
5. **Kurzbeschreibung:** ein bis zwei Sätze, was der Skill tut, plus Voraussetzungen (welche Werkzeuge nötig sind).
6. **Wann ausführen:** klare Trigger, klare Nicht-Fälle.
7. **Schritte:** nummeriert, mit absoluten Pfaden (C:\Leo\...).
8. **Regeln:** inklusive Anti-Halluzination und, falls schreibend, Bestätigungs-/Changelog-Pflichten.
9. **Definition of Done:** letzter Abschnitt jedes Skills, eine Checkliste überprüfbarer Kriterien (`- [ ] ...`). Vor der Abschluss-Bestätigung wird jeder Punkt real geprüft, nicht aus dem Gedächtnis abgehakt; ein nicht erfüllbarer Punkt wird offen benannt statt still übergangen. Warum: Ohne DoD erklärt das LLM eine Ausführung für fertig, sobald sie plausibel aussieht; die Checkliste macht "fertig" überprüfbar und deckt vergessene Schritte (Commit, Registereintrag, Verifikation) mechanisch auf. Kriterien beschreiben prüfbare Ergebnisse ("Registereintrag existiert"), keine Absichten ("sorgfältig gearbeitet").

## Handwerk: Woran man einen guten Skill erkennt

Die Norm oben regelt die Form. Diese Prinzipien trennen einen wirksamen Skill von einem mittelmässigen. Ein Skill wird oft ausgeführt und selten gelesen: eine Stunde Sorgfalt beim Bauen amortisiert sich über jede spätere Ausführung, ein Fehler ebenso.

- **Trigger und Zweck sind die Schnittstelle.** Beim Nachschlagen im Register entscheidet das LLM anhand von Trigger-Worten und Zweck, ob dieser Skill gemeint ist. Trigger-Worte so wählen, wie sie real gesagt oder getippt werden; der Zweck-Satz muss die Frage "wann greift der?" allein beantworten. Immer auch die Nicht-Fälle benennen: Über-Auslösung ist der häufigste Grund, warum ein Skill nervt.
- **Begründe das Warum, nicht nur das Was.** "Zitate nie paraphrasieren, weil falsche Zuschreibung der häufigste Zitatfehler ist" verallgemeinert auf unbekannte Fälle; ein blankes "NIE paraphrasieren" nicht. Häufige Grossbuchstaben-Befehle (MUSS, NIE, IMMER) ohne Begründung sind ein Warnzeichen für eine fehlende Erklärung.
- **Nur schreiben, was das LLM nicht schon weiss.** Das LLM weiss, was eine Mail ist; es kennt deine Eskalationsregeln nicht. Jeder generische Satz kostet Kontext, den ein spezifischer Satz besser nutzt. Dichte vor Dekoration.
- **Über das Beispiel hinaus verallgemeinern.** Der Skill läuft auf vielen Eingaben; Anweisungen, die nur auf das eine Beispiel im Skill passen, versagen auf allen anderen.
- **Feste Ausgabeform als Vorlage zeigen.** Hat die Ausgabe eine feste Struktur, sie als Vorlage in einem Codeblock zeigen, nicht in Prosa beschreiben.
- **Kalibrierung in beide Richtungen.** Benennen, wie Unter-Nutzung aussieht und wie Über-Nutzung, und welche schlimmer ist. Eine grobe Schwelle hilft mehr als "mit Augenmass".
- **Mindestens ein realistisches Beispiel.** Plausibel unordentliche Eingabe, die echte Ausgabe des Skills. Realistisch heisst mit Tippfehlern, vergrabenen Details und Kontext, nicht das sterilisierte Lehrbuch-Beispiel.
- **Anti-Overfitting.** Ein Skill beschreibt Geschmack, er ersetzt nicht das Urteil. Keine Regel so stur befolgen, dass das Ergebnis schlechter wird.

## Schritte zum Bauen eines neuen Skills

### 1. Anforderung klären
Frag: Was soll der Skill tun, wodurch wird er ausgelöst, schreibt er Dateien, braucht er PowerShell oder Websuche?

### 2. Skill-Datei schreiben
Erstelle `02_Skills\leo-<name>.md` nach der Norm oben. Schlank und eindeutig; ein Skill löst genau eine Aufgabe.

### 3. Ins Register eintragen
Ergänze die Tabelle in `02_Skills\Skill-Register.md`: Name, Trigger-Worte, Datei, Zweck, und die fünfte Spalte "Von selbst, wenn" mit dem situativen Anlass, bei dem der Skill auch ohne Trigger-Wort vorgeschlagen oder ausgeführt werden soll (seit 2.1; sie speist die Kurzliste in der `AGENTS.md`, Abschnitt 11). Ein Skill ohne diese Spalte funktioniert per Trigger-Wort weiter, wird aber nie von selbst vorgeschlagen, und genau das macht den Grossteil seines Werts im Alltag aus.

Danach den Skill-Zeiger nachziehen, damit der neue Skill per `/name` anspringt:
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Leo\00_INDEX\scripts\build-skill-wrapper.ps1"
```
Das Skript schreibt den Zeiger in alle sechs Werkzeug-Pfade, damit der neue Skill auch nach einem Werkzeugwechsel sofort da ist (Pflicht aus `AGENTS.md` Abschnitt 11a). Der Zeiger enthält keine Substanz, er verweist nur auf die Skill-Datei. Zwei Punkte dabei: Das Frontmatter des Skills bleibt bei den Feldern der Agent-Skills-Spezifikation (`name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`) oder bei der Norm oben, keine werkzeugeigenen Felder. Und hat der neue Skill Seiteneffekte (löscht, pusht, sendet nach aussen), trägst du seinen Namen in die Liste `$noAutoInvoke` im Skript ein, sonst kann das Modell ihn ungefragt starten.

### 4. Index aktualisieren
Führe den Skill `02_Skills\leo-system-health-check.md` aus (aktualisiert Index-Mechanik und Beschreibungen und committet).

### 5. Bestätigen
"Skill <Name> gebaut, ins Register eingetragen, Index aktualisiert. Trigger: <...>."

## Regeln
- Keine Trigger-Worte doppelt vergeben (Kollision im Register vermeiden).
- Anti-Halluzination beachten.
- Nach jeder Skill-Ausführung im Betrieb: Wenn ein Fehler oder eine Schwachstelle sichtbar wurde, den betroffenen Skill direkt verbessern (Version hochzählen) und kurz informieren.

## Definition of Done
- [ ] Neue Skill-Datei erfüllt alle neun Normpunkte, inklusive eigener Definition of Done
- [ ] Trigger-Worte gegen das komplette Register auf Kollision geprüft
- [ ] Registereintrag in `02_Skills\Skill-Register.md` existiert (Name, Trigger, Datei, Zweck, "Von selbst, wenn")
- [ ] Index-Mechanik gelaufen, Beschreibung der neuen Skill-Datei kuratiert
- [ ] Abschluss-Bestätigung nennt Skill-Namen und Trigger-Worte
