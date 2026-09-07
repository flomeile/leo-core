---
titel: Skill-Register
zweck: Zentrale Liste aller Skills mit Trigger-Wort und Dateipfad
type: skill-register
version: 3.1-core
letzte_aenderung: 2026-09-03
---

# Skill-Register

Die Root-`AGENTS.md` verweist auf diese Datei. Wenn ein Trigger-Wort genannt wird, schau hier nach, welcher Skill gemeint ist, öffne die zugehörige Datei und führe sie gemäss ihrer Anweisung aus.

Für den Alltag reichen zwei Trigger: **"wrap up"** am Ende einer substanziellen Session, **"health check"** wann immer unklar ist, ob alles aktuell ist. Der Rest läuft automatisch (Task Scheduler täglich, optional Obsidian-Git laufend). Und wer nie ein Trigger-Wort sagt, weil er nur MIT dem System arbeitet: Nutzungsmodus `benutzen` in `MEIN-SYSTEM.md`, Abschnitt 5 eintragen, dann fährt das LLM fällige Wartung ungefragt selbst (AGENTS.md, Abschnitt 1, seit 1.19).

Namenskonvention: Alle Skill-Dateien tragen das Präfix `leo-`. Das macht sichtbar, dass der Skill in `C:\Leo` liegt und von dort aus funktioniert, unabhängig vom Harness. Trigger-Worte selbst brauchen das Präfix nicht.

| Skill | Trigger-Worte | Datei | Zweck | Von selbst, wenn |
|---|---|---|---|---|
| Leo System Health Check | "system health check", "health check", "system prüfen", "systemcheck", "ist alles gesund", "gesundheitscheck system", "alles aktuell", "system aktualisieren", "auf vordermann bringen", "index aktualisieren", "index neu bauen", "inbox aufraeumen", "ablage aufraeumen", "hygiene" | 02_Skills/leo-system-health-check.md | One-Button-Wartung: alles prüfen, sicher Behebbares selbst beheben (Index-Beschreibungen, stand-Daten, Register), Inbox behandeln, committen + pushen | der Besitzer fragt sinngemäss, ob alles aktuell oder gesund ist, oder die Session hat Struktur, Skripte oder Skills verändert |
| Leo Wrap-Up | "wrap up", "session speichern", "zusammenfassen und ablegen", "session beenden" | 02_Skills/leo-wrap-up.md | Session zusammenfassen, in 03_Sessionlogs ablegen; Lernschleife: Dauerwissen in die steuernden Dateien zurückschreiben, fehlende Wissensdateien anlegen, Überholtes ersetzen, sofort indexieren; vollen Health Check nur bei Bedarf | eine substanzielle Session geht erkennbar zu Ende oder hat Korrekturen und Dauerwissen erzeugt, das noch nirgends im Repo steht |
| Leo Themenordner anlegen | "neuer themenordner", "themenordner anlegen", "neues thema anlegen" | 02_Skills/leo-themenordner-anlegen.md | Neuen Themenordner vollständig anlegen (README, AGENTS.md, Routing, Index) | ein neues Thema braucht erkennbar einen eigenen Ordner statt einer Datei in 90_Inbox |
| Leo Skill erstellen | "neuen skill", "skill erstellen", "skill bauen" | 02_Skills/leo-skill-ersteller.md | Baut einen neuen Skill normgerecht (inkl. Präfix) und trägt ihn ins Register ein | ein Ablauf wiederholt sich, oder der Besitzer beschreibt einen wiederkehrenden Wunsch, den kein bestehender Skill trägt |
| Leo Mechanik-Update | "core update", "core aktualisieren", "neue core-version", "mechanik update", "grundgeruest aktualisieren", "starter update", "update ziehen", "neue version holen" | 02_Skills/leo-mechanik-update.md | Holt Verbesserungen am Grundgerüst von GitHub und arbeitet sie ein, ohne eigene Anpassungen und eigene Skills zu beschädigen | der Health-Check meldet einen Versions-Rückstand des Grundgerüsts und der Besitzer hat Ja gesagt (nie ohne Ja) |
| Leo System-Optimierung | "system-optimierung", "system optimieren", "optimierungslauf", "pruefset fahren", "prüfset fahren", "messlauf", "regeltreue messen" | 02_Skills/leo-system-optimierung.md | Misst mit kalten Prüfset-Läufen (dein Prüfset, beim ersten Mal aus der Vorlage `10_System\Pruefset-Vorlage.md` angelegt), ob das System seine eigenen Regeln einhält, leitet aus jedem Durchfaller die richtige Fix-Sorte ab (Regel härten, Regel präzisieren, mechanisches Netz, oder bewusst nichts) und misst nach; sinkt die Quote, wird zurückgerollt. Der Health-Check erinnert mechanisch (Kategorie `Lean`, Messlauf-Wächter) | der Messlauf-Wächter meldet eine ungemessene Kernänderung, eine Kernänderung an AGENTS.md, Settings oder Hooks steht bevor, oder die Lean-Meldung zeigt gewachsenen Pflichtkontext |
| Leo Voice-Check | "voice check", "voice-check", "schleif das", "schleifen", "stil check", "stilcheck" | 02_Skills/leo-voice-check.md | Einen fertigen ausgehenden Text (Mail, Präsentation, Post, Angebot) gegen die eigene Voice-Datei und die generischen KI-Tells prüfen und selbst korrigieren, bereinigte Fassung plus Änderungsliste | ein ausgehender Text entsteht oder wird überarbeitet (Mail, Nachricht, Post, Angebot, Präsentation), immer, ohne Trigger |
| Leo Faktencheck | "faktencheck", "fakten prüfen", "fakten checken", "stimmt das", "verifizieren", "quellen prüfen", "belege prüfen" | 02_Skills/leo-faktencheck.md | Jede überprüfbare Tatsachenbehauptung in einem Text einzeln gegen Primärquellen (Websuche) prüfen, Urteil je Behauptung (bestätigt/veraltet/ungenau/nicht verifizierbar/falsch) mit Quelle, korrigierten Entwurf anbieten | ein ausgehender Text trägt Zahlen, Zitate, Namen, Preise, Rankings oder Superlative |
| Leo Notiz | "notiere an geeigneter stelle", "an geeigneter stelle notieren", "notier das", "nicht vergessen", "merk dir das" | 02_Skills/leo-notiz.md | Einen offenen Punkt so im Repo verankern, dass er mechanisch wiederkommt statt im Chat zu sterben: zuständige Datei finden, gegen Bestehendes prüfen, Status-Block mit Owner, nächstem Zug und Wiedervorlage-Datum setzen | im Gespräch entsteht ein offener Punkt, eine Frist oder eine Zusage ohne Ort mit Datum, auch wenn niemand von Notieren spricht |
| Leo First Principles | "first principles", "first-principles", "dekonstruiere das", "von grund auf neu denken", "fundamental hinterfragen" | 02_Skills/leo-first-principles.md | Ein bestehendes Modell, einen Prozess oder eine Branchenlösung auf fundamentale Wahrheiten dekonstruieren und von Null neu aufbauen (Dekonstruktion, Annahmen-Check, Neuaufbau, Implementierung), Abschluss immer mit konkretem erstem Zug | ein "das haben wir immer so gemacht", ein unerklärter Kosten- oder Zeitblock oder eine Make-or-Buy-Frage taucht auf |

## Regel
Wenn ein neuer Skill gebaut wird (via Skill-Ersteller), wird diese Tabelle ergänzt. Trigger-Worte müssen eindeutig bleiben. Neue Skill-Dateien tragen immer das Präfix `leo-`.

## Hinweis für den Aufbau
Dies ist die Grundausstattung des Kerns: sechs Kern-Skills für die Mechanik plus vier Arbeits-Skills (Voice-Check, Faktencheck, Notiz, First Principles), die von selbst anspringen, wenn ihre Situation eintritt. Weitere Skills (z.B. ein Inbox-Ingest für Rohquellen oder ein Wochenbriefing) baust du dir bei Bedarf selbst über den Skill-Ersteller ("skill erstellen"). Der Ersteller-Skill trägt die Norm dafür.
