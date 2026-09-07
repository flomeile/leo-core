---
name: leo-notiz
trigger: '"notiere an geeigneter stelle", "an geeigneter stelle notieren", "notier das", "nicht vergessen", "merk dir das"'
zweck: Einen offenen Punkt so im Repo verankern, dass er mechanisch wiederkommt statt im Chat zu sterben - zustaendige Datei finden, gegen Bestehendes pruefen, Status-Block mit Owner und Wiedervorlage setzen
type: skill
version: 1.0
---

# Skill: Leo Notiz

Verankert einen offenen Punkt (Aufgabe, Entscheid mit Nachlauf, Frage an eine Person, aufgeschobene Arbeit) so im Repo, dass er von selbst wiederkommt. Voraussetzungen: keine besonderen, die Repo-Suchwerkzeuge genügen.

Was "notiere an geeigneter Stelle" heisst: Der Punkt darf nicht vergessen gehen, er ist gegen bestehende Notizen geprüft, er ist terminiert und zugewiesen, er ist maschinell auffindbar, und seine Abhängigkeiten sind benannt. Dieser Skill ist die Mechanik dafür.

## Wann ausführen

Immer, wenn `[NAME]` sinngemäss verlangt, dass etwas nicht verloren gehen darf. Auch ohne Trigger-Wort selbst ausführen, wenn am Ende einer Arbeit etwas Offenes zurückbleibt, das keinen Ort mit Datum hat (`AGENTS.md`, Abschnitt 11: formt vorhandene Arbeit, also selbst ausführen). NICHT für blosse Fakten ohne Handlungsbedarf: Die werden als normale Wissensnotiz in der zuständigen Datei abgelegt, ohne Status-Block. Über-Auslösung ist hier billiger als Unter-Auslösung: Ein doppelt geprüfter Punkt kostet eine Suche, ein vergessener kostet den Besitzer genau die Arbeit, die er delegiert hat.

## Schritte

1. **Zuständige Datei finden** (Suchstrategie aus `AGENTS.md`, Abschnitt 4). Erst prüfen, ob eine Agenda- oder Wissensdatei den Punkt schon führt; dann dort nachführen statt doppeln. Eine neue Datei nur, wenn wirklich keine passt.
2. **Gegen Bestehendes prüfen:** Synonym-Volltextsuche über das Repo. Steht derselbe Punkt schon woanders, wird dort nachgeführt und höchstens ein Verweis gesetzt (eine Information hat genau einen Ort). Widerspricht der Punkt einer bestehenden Aussage, wird der Widerspruch gemeldet statt still notiert.
3. **Als Status-Block anlegen**, exakt in dieser Form, weil das Status-Token den Zustand maschinell zählbar macht (`AGENTS.md`, Abschnitt 7) und eine Volltextsuche nach `**Status:** offen` alle offenen Punkte findet:

   ```
   ### <Titel des Punkts>
   **Status:** offen (oder blockiert/laufend), <ein Halbsatz Zustand; bei blockiert: wodurch>
   **Owner:** <eine Person, nie ein Team>
   **Nächster Zug:** <eine konkrete Handlung; muss der Besitzer etwas in einer fremden Oberfläche tun, mit Klickanleitung>
   **Wiedervorlage:** YYYY-MM-DD
   ```

   Ohne Wiedervorlage-Datum kein Block: Ein Punkt ohne Datum ist ein Punkt, an den sich niemand erinnert. Wer einen festen Wochenrhythmus hat, baut sich über den Skill-Ersteller einen Briefing-Skill, der alle fälligen Blöcke einsammelt; bis dahin gehört die Suche nach überfälligen `**Status:**`-Blöcken zu jedem Health-Check-Gespräch.
4. **Datei-Pflege:** `stand:` der Datei auf das echte Tagesdatum. Entsteht eine neue Datei, sofort Frontmatter nach `AGENTS.md` Abschnitt 5 plus kuratierte Index-Beschreibung.
5. **Rückmeldung, ein Satz:** in welcher Datei der Punkt liegt und wann er wiederkommt.

## Regeln

- Anti-Halluzination: Nur notieren, was der Besitzer gesagt hat oder was belegt offen ist. Eine eigene Ableitung wird im Block als solche markiert.
- Erledigt wird ein Block nur mit Beleg im selben Satz (`AGENTS.md`, Abschnitt 7); beim Erledigen die Wiedervorlage entfernen oder auf den nächsten Turnus setzen.
- Nutzt der Besitzer ein externes Aufgaben-Werkzeug, kann der Punkt dort zusätzlich als Erinnerung angelegt werden (nur mit Freigabe, `AGENTS.md` Abschnitt 16); der Repo-Block bleibt trotzdem die Wahrheit. Braucht die Erledigung eine neue LLM-Session, trägt die Erinnerung den fertigen, kopierfertigen Startprompt mit Pfaden und erwartetem Material; ein Aufgabentitel ohne Startprompt gibt dem Besitzer die Arbeit zurück, den Auftrag neu zu formulieren.

## Beispiel

Eingabe: "das mit dem backup check darf nicht vergessen gehn, notiere an geeigneter stelle"
Ergebnis: Block "Backup-Status verifizieren" in der zuständigen Systemdatei, Status offen, Owner der Besitzer, nächster Zug mit dem Kommando und was er zurückmelden soll, Wiedervorlage auf den nächsten Montag. Rückmeldung: "Liegt in <Datei>, Wiedervorlage <Datum>."

## Definition of Done

- [ ] Punkt liegt in genau einer Datei, im Status-Block-Format aus Schritt 3
- [ ] Wiedervorlage-Datum und Owner gesetzt, Abhängigkeiten benannt
- [ ] Duplikat- und Widerspruchsprüfung per Volltextsuche gelaufen
- [ ] `stand:` aktualisiert; bei neuer Datei Frontmatter und Index-Beschreibung vorhanden
- [ ] Der Besitzer weiss in einem Satz, wo der Punkt liegt und wann er wiederkommt
