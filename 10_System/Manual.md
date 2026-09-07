---
titel: Manual (Bedien-Anleitung)
zweck: Alltags-Anleitung, wie das KI-System aus allen Endpunkten genutzt wird
type: systemdoku
version: 1.1
letzte_aenderung: 2026-08-03
---

# Manual: So nutzt du dein KI-System

Alles Wissen liegt als Markdown in `C:\Leo`. Jedes LLM mit Datei-Zugriff liest zu Beginn die `AGENTS.md` im Root und weiss dann alles: Regeln, Suchstrategie, Rollen. Du legst Markdowns ab, das System findet und pflegt sie.

Für die einmalige Ersteinrichtung (Repo, Git, Scheduler, Harness) siehe `ANLEITUNG.md` im Root. Dieses Manual ist für den laufenden Alltag.

## Welches Werkzeug wofür

| Aufgabe | Werkzeug | Warum |
|---|---|---|
| Wissensfragen, Alltag, kleine Textarbeit | Chat-Harness auf `C:\Leo` mit günstigem Modell | Günstigster Weg: gezieltes Lesen, Cent-Bereich pro Frage |
| Dasselbe im Claude-Abo | Claude Desktop / Claude Code auf den Ordner | Liest CLAUDE.md/AGENTS.md automatisch, kein Setup |
| Bau- und Wartungsarbeit am System (Struktur, Skripte, viele Dateien, Git) | Coding-Agent (z.B. Claude Code) | Native Such-/Editier-Werkzeuge, testet Skripte selbst |
| Deep Research | Gemini / Claude (extern) | Bericht als Markdown in `90_Inbox` ablegen, danach hier weiterverarbeiten |

Faustregel: Abfragen = Chat-Harness mit günstigem Modell (siehe `Modellwahl.md`). Umbauten = Coding-Agent, Aufträge bündeln, pro Thema eine frische Session.

## Projekt-Setup (nur für Chat-Harnesses nötig)

Coding-Agents und Claude-Produkte finden AGENTS.md/CLAUDE.md selbst. Ein reiner Chat-Harness liest nichts automatisch; darum braucht jedes Projekt genau EINEN Satz als Systemprompt:

```
Lies zuerst C:\Leo\AGENTS.md vollständig und befolge sie für die gesamte Session.
```

Dazu im Projekt: Datei- und PowerShell-Zugriff aktivieren (ohne PowerShell keine Volltextsuche), ein tool-fähiges Modell wählen, bei Bedarf Websuche einschalten. Mehr nicht. Rolle und Fokus regelt die AGENTS.md-Mechanik selbst.

## So promptest du

- **Alles durchsuchen:** einfach fragen, oder explizit: "Durchsuche das ganze Repo zu <Thema>." Das LLM geht über Index + Volltextsuche über alle Ordner.
- **Bestimmte Rolle:** Thema nennen reicht meistens; das LLM erkennt den Bereich und lädt die Rollen-Regeln selbst. Erzwingen: "Als mein <Rolle> (<Ordner>): ..."
- **Am System arbeiten:** "Als System-Experte (10_System): ..."

## Tägliche Arbeit

- **Frage stellen:** Das LLM liest Root-Index, lokalen Index, sucht mit Synonymen im Inhalt, liest die Treffer, antwortet.
- **An einer Datei arbeiten:** Datei nennen oder finden lassen. ACHTUNG: Manche Harnesses schreiben ohne Rückfrage; Sicherheit kommt aus Git (Rollback jederzeit).
- **Neues Wissen ablegen:** Das LLM legt die Datei im passenden Ordner ab (oder du selbst in Obsidian). Der mechanische Index zieht automatisch nach; Beschreibungen kommen beim nächsten "health check" oder Wrap-Up.
- **Neues Thema:** "neuer themenordner" sagen; der Skill legt Ordner, Rolle, Routing und Index vollständig an.

## Skills

Trigger-Wort nennen, das LLM schlägt in `02_Skills\Skill-Register.md` nach und führt den Skill aus. Die Alltags-Trigger im Kern:

- **"wrap up"** am Ende einer substanziellen Session (Zusammenfassung, Lernschleife, Update, Push).
- **"health check"** wann immer du unsicher bist, ob alles aktuell ist (prüft alles, behebt sicher Behebbares, Inbox, Push).

Selten gebraucht: "neuer themenordner", "skill erstellen". Dazu vier Arbeits-Skills, die von selbst anspringen: Voice-Check und Faktencheck bei ausgehenden Texten, Notiz bei offenen Punkten, First Principles bei Grundsatzfragen. Weitere Skills baust du bei Bedarf über den Skill-Ersteller.

## Session beenden (Wrap-Up)

"wrap up" sagen: Zusammenfassung nach `03_Sessionlogs`, Lernschleife (Korrekturen und Erkenntnisse werden in Skills, AGENTS.md bzw. Wissensdateien zurückgeschrieben; fehlt eine passende Wissensdatei, wird sie angelegt, Überholtes wird ersetzt, neue Dateien bekommen sofort ihre Index-Beschreibung), danach Index-Update, Commit und Push. Der volle Health-Check läuft dabei nur, wenn er fällig ist (letzter Lauf über 24h her oder strukturelle Session).

## Versionierung und Rollback

- Automatisch: Task Scheduler (täglich) und optional Obsidian-Git committen und pushen auf das private GitHub-Repo. Sofort geht mit "health check" oder "wrap up".
- Rollback ohne Kommandozeile: Obsidian-Git-Plugin (Datei-Historie) oder GitHub-Weboberfläche (History, gewünschten Stand öffnen und Inhalt zurückkopieren). Für grössere Rollbacks: Coding-Agent beauftragen.

## Wartung (fast nichts)

- Index-Mechanik, Git-Sync: laufen automatisch. Nichts zu tun.
- Alles andere (Beschreibungsqualität, Inbox, veraltete Stände, fehlende Kennzeichnungen): gelegentlich "health check" (läuft auch beim Wrap-Up mit, wenn fällig).
- `Modellwahl.md` älter als 3 Monate: "modellwahl aktualisieren" sagen (LLM mit Websuche nötig).
- Fehler oder komisches Verhalten: Coding-Agent oder System-Experten-Session fragen; nie selbst an Skripten raten.
