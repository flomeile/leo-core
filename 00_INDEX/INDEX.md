---
titel: INDEX (Landkarte des Leo)
zweck: Einstiegspunkt der Agentic Search; Hierarchie, Bereiche, Systemdateien
type: index
version: 1.0-core
hinweis: Der Ordnerbaum wird mechanisch aktualisiert (build-index-geruest.ps1). Beschreibungen sind kuratiert und rein deskriptiv. Der Auto-Block "Ordnerbaum" unten traegt die aktuelle Stand-Zeitangabe.
---

# INDEX: Landkarte des Leo

So nutzt du diese Landkarte: (1) Im Ordnerbaum unten orientieren. (2) **Pflichtschritt für JEDEN Themenordner in der Liste "Themenbereiche" unten: den lokalen Index `<Ordner>\_INDEX.md` lesen** — dort und NUR dort stehen die Dateiliste und die kuratierten Beschreibungen der einzelnen Dokumente, dieser Root-Index enthält sie bewusst nicht. (3) Danach Volltextsuche mit Synonymen im Datei-Inhalt (siehe AGENTS.md, Suchstrategie). (4) Nur Treffer ganz lesen. Die vollständige mechanische Dateiliste steht in `INDEX-Geruest.md`.

Im frischen Kern ist die Themenbereichs-Liste leer, bis du den ersten Themenordner anlegst (Skill `leo-themenordner-anlegen`, Trigger "neuer themenordner").

## Ordnerbaum (mechanisch aktuell)
<!-- AUTO:BAUM:BEGIN -->
Stand: 2026-09-03 14:35 (mechanisch aktualisiert, Anzahl = .md-Dateien inkl. Unterordner)

- 00_INDEX\  (1 Dateien)
  - githooks\  (0 Dateien)
  - scripts\  (0 Dateien)
- 01_Basiskontext\  (4 Dateien)
- 02_Skills\  (12 Dateien)
- 03_Sessionlogs\  (1 Dateien)
- 04_Changelog\  (2 Dateien)
- 10_System\  (10 Dateien)
- 90_Inbox\  (1 Dateien)
<!-- AUTO:BAUM:END -->

## Themenbereiche (mechanisch aktuell)

Diese Liste zeigt nur Rolle und Pfade, KEINE Datei-Beschreibungen. Die eigentlichen Beschreibungen der einzelnen Dokumente stehen ausschliesslich in der jeweils verlinkten lokalen `_INDEX.md` des betroffenen Ordners (siehe `10_System\Architektur.md`, Abschnitt "Der Index"): der Root-Index bleibt klein und wird bei jeder Frage geladen, die Details liegen lokal. **Bevor eine Datei als "nicht vorhanden" gilt: immer zuerst die lokale `_INDEX.md` des betroffenen Ordners lesen.**

<!-- AUTO:BEREICHE:BEGIN -->

<!-- AUTO:BEREICHE:END -->

## Systemordner (kuratierte Beschreibungen)

### Root

- **AGENTS.md** — Master-Anweisung für jedes LLM: Grundprinzip inkl. YAGNI-Prüfung, Rollen-Routing, Werkzeuge, Suchstrategie, Ablage, Anti-Halluzination, Aktualität, Session-Wissen und Lernschleife, Index-Regeln, Skills, Versionierung, Kosten, Datenschutz, Live-Daten, externe Tools. Zu Sessionbeginn lesen.
- **MEIN-SYSTEM.md** — Die persönliche Ebene über der AGENTS.md: wer `[NAME]` ist, wie das System hier heisst und wo es liegt, eigene Regeln (haben Vorrang vor der AGENTS.md), eigene Skills und Ordner, eingespielte Version des Grundgerüsts, Setup-Notizen. Wird von Updates nie angefasst. In jeder Session zusammen mit der AGENTS.md lesen.
- **CLAUDE.md** — Minimaler Verweis auf AGENTS.md und MEIN-SYSTEM.md (für Harnesses, die CLAUDE.md automatisch laden).
- **GEMINI.md** — Minimaler Verweis auf AGENTS.md und MEIN-SYSTEM.md (für Gemini CLI, das standardmässig GEMINI.md lädt).
- **README.md** — Einstieg für Menschen: was das Repo ist, Struktur-Kurzfassung, Verweis auf ANLEITUNG.md.
- **ANLEITUNG.md** — Sinn und Funktionsweise von Leo plus die Schritt-für-Schritt-Ersteinrichtung (Repo, Git, Scheduler, Harness, Personalisierung).

### 01_Basiskontext (Kernkontext, für inhaltliche Arbeit zu Sessionbeginn laden)

- **01_Basiskontext\Identity.md** — Vorlage für Werte, Haltung, Fundament und die Mensch-KI-Grenze. Leitfragen, die du mit deinen Angaben füllst.
- **01_Basiskontext\Persoenlichkeit und Muster.md** — Vorlage für die Bedienungsanleitung des Sparringpartners: Stärken, Stolpersteine, Umgang. Optional, falls du Sparring willst.
- **01_Basiskontext\Voice and Style.md** — Schreibstil- und Tonregeln für alle generierten Texte: generische KI-Tell-Liste (Default) plus Leitfragen für deine persönlichen Regeln.

### 02_Skills

- **02_Skills\Skill-Register.md** — Zentrale Liste aller Skills; die EINZIGE Wahrheit für Trigger-Worte und Pfade. Zuerst lesen, wenn ein Trigger-Wort genannt wird.
- **02_Skills\leo-system-health-check.md** — Der EINE Wartungs-Skill (One-Button): Diagnose des Gesamtsystems via `00_INDEX\scripts\health-check.ps1`, behebt sicher Behebbares selbst (Index-Beschreibungen, stand-Daten, Register), behandelt die Inbox mit Bestätigung, committet und pusht.
- **02_Skills\leo-wrap-up.md** — Session zusammenfassen, in 03_Sessionlogs ablegen, Lernschleife (Dauerwissen in die steuernden Dateien zurückschreiben, fehlende Wissensdateien anlegen, Überholtes ersetzen, sofort indexieren); vollen Health-Check nur bei Bedarf.
- **02_Skills\leo-themenordner-anlegen.md** — Neuen Themenordner vollständig anlegen (Ordner, README, lokale AGENTS.md, Index; Routing zieht das Skript nach).
- **02_Skills\leo-skill-ersteller.md** — Norm und Anleitung, um neue Skills zu bauen (inkl. leo-Präfix und Definition of Done) und ins Register einzutragen.
- **02_Skills\leo-mechanik-update.md** — Holt Verbesserungen am Grundgerüst von GitHub (`upstream`-Remote, Versions-Tags) und arbeitet sie ein, ohne eigene Anpassungen zu beschädigen: erst committen als Rückweg, Kern-Dateien nur dort ersetzen, wo lokal nichts geändert wurde, sonst einarbeiten, eigene Skills gegen die neuen Konventionen prüfen, Stand in MEIN-SYSTEM.md fortschreiben.
- **02_Skills\leo-system-optimierung.md** — Misst mit kalten Prüfset-Läufen, ob das System seine eigenen Regeln einhält (Trigger "messlauf"): Prüfset fahren, am Beleg urteilen, je Durchfaller die richtige Fix-Sorte wählen, nachmessen, bei sinkender Quote zurückrollen. Erster Aufbau aus `10_System\Pruefset-Vorlage.md`.
- **02_Skills\leo-voice-check.md** — Prüft einen fertigen ausgehenden Text (Mail, Präsentation, Post, Angebot) gegen die eigene Voice-Datei und die generischen KI-Tells (Floskeln, Pauschalaussagen, Reframe-Konstruktionen, Verb-Aufblähung, Haltung, Verständlichkeit) und liefert die bereinigte Fassung samt Änderungsliste. Springt bei jedem ausgehenden Text von selbst an.
- **02_Skills\leo-faktencheck.md** — Prüft jede überprüfbare Tatsachenbehauptung eines Textes einzeln gegen Primärquellen per Websuche (Zahlen, Zitate, Personen, Superlative zuerst), fällt je Behauptung eines von fünf Urteilen mit Quelle und bietet den korrigierten Entwurf an. Ohne Websuch-Werkzeug wird nichts simuliert.
- **02_Skills\leo-notiz.md** — Verankert einen offenen Punkt so im Repo, dass er wiederkommt: zuständige Datei suchen, Duplikate und Widersprüche prüfen, Status-Block mit Owner, nächstem Zug und Wiedervorlage-Datum setzen, stand: und Index nachziehen.
- **02_Skills\leo-first-principles.md** — Dekonstruiert ein Modell, einen Prozess oder eine Branchenlösung auf fundamentale Grundwahrheiten und baut von Null neu auf (Dekonstruktion, Annahmen-Check, Neuaufbau, Barrieren, Prototyp-Test), endet immer mit einem konkreten ersten Zug samt Zeithorizont.

### 03_Sessionlogs / 04_Changelog

- **03_Sessionlogs\...** — Wrap-Up-Zusammenfassungen, thematisch in Unterordnern. Ab Ablage sofort auffindbar.
- **04_Changelog\...** — Protokoll aller Änderungen am Basiskontext.

### 10_System (Rolle: System-Experte, siehe lokale AGENTS.md)

- **10_System\Zielsetzung.md** — Warum das System existiert; Massstab jeder Entscheidung. Themen: Second Brain, Rollen, Unabhängigkeit, Anti-Halluzination, Einfachheit, Sicherheit, Kostenkontrolle.
- **10_System\Architektur.md** — Zielarchitektur: Schichten, AGENTS-Mechanik, zweistufiger Index, Agentic Search, Aktualitäts-Mechanik.
- **10_System\Technik.md** — Technische Lösungen und Umgebung mit Problem/Lösung/Begründung: Agentic Search, PowerShell-Volltextsuche, Index-Hybrid, Encoding/BOM, Scan-Ausschlüsse, kein Harness-Memory.
- **10_System\Manual.md** — Bedienungsanleitung: welches Werkzeug wofür, Projekt-Setup, Prompting-Muster, Skills, Wrap-Up, Rollback, Wartung.
- **10_System\Modellwahl.md** — Modellempfehlungen für den Betrieb, mit Stand-Datum und Aktualisierungs-Anleitung.
- **10_System\Kern-Dateien.md** — Legt fest, welche Dateien zum Grundgerüst gehören und bei einem Update ersetzt werden dürfen (Kategorie A), welche nur eingearbeitet werden (B) und welche dir gehören und nie angefasst werden (C). Grundlage für den Skill `leo-mechanik-update`.
- **10_System\Detailregeln aus AGENTS.md.md** — Nimmt nach der Trennlinie steuernd/begründend die Präzedenzfälle und Langbegründungen auf, die nicht in die Root-AGENTS.md gehören; wächst über die Lernschleife des Wrap-Ups und wird von Updates nie ersetzt.
- **10_System\Pruefset-Vorlage.md** — Vorlage für das eigene Regeltreue-Prüfset (zwölf Fälle mit Eingabe, Erwartung, hartem Abbruchkriterium und geprüfter Regel; generische Fälle sofort nutzbar, Platzhalter für repo-spezifische). Wird im selben Ordner zur Datei Pruefset.md kopiert, die ab dann dir gehört.
- **10_System\AGENTS.md** — Lokale Rollen-Datei: System-Experte.
