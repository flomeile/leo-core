---
titel: Kern-Dateien
zweck: Legt fest, welche Dateien zum Grundgerüst gehören und bei einem Update ersetzt werden dürfen, und welche dir gehören
type: systemdoku
version: 3.4
stand: 2026-09-15
---

# Kern-Dateien: was ein Update anfassen darf

Diese Liste ist die Grundlage für den Skill `leo-mechanik-update`. Sie beantwortet eine einzige Frage: Wenn das Grundgerüst weiterentwickelt wird, welche Dateien dürfen bei dir ersetzt werden, ohne dass etwas von dir verloren geht.

Drei Kategorien, und die Zuordnung ist bindend.

## A. Kern: wird bei einem Update ersetzt

Diese Dateien sind Mechanik. Sie sind bei allen Nutzern identisch und sollen es bleiben. **Editiere sie nicht.** Was du ändern willst, gehört nach `MEIN-SYSTEM.md`.

| Datei | Was sie tut |
|---|---|
| `AGENTS.md` | Die Arbeitsregeln. Enthält bewusst keine Namen und keine Pfade, die aufgelöst werden müssten |
| `10_System\Kern-Dateien.md` | Diese Liste |
| `02_Skills\leo-mechanik-update.md` | Der Update-Skill selbst |
| `02_Skills\leo-wrap-up.md` | Kern-Skill |
| `02_Skills\leo-system-health-check.md` | Kern-Skill |
| `02_Skills\leo-themenordner-anlegen.md` | Kern-Skill |
| `02_Skills\leo-skill-ersteller.md` | Kern-Skill |
| `02_Skills\leo-system-optimierung.md` | Kern-Skill: Regeltreue-Messung mit kaltem Prüfset (seit 1.18) |
| `02_Skills\leo-voice-check.md` | Arbeits-Skill: ausgehende Texte gegen die eigene Voice-Datei prüfen (seit 2.3) |
| `02_Skills\leo-faktencheck.md` | Arbeits-Skill: Tatsachenbehauptungen gegen Primärquellen prüfen (seit 2.3) |
| `02_Skills\leo-notiz.md` | Arbeits-Skill: offene Punkte als Status-Block mit Wiedervorlage verankern (seit 2.3) |
| `02_Skills\leo-first-principles.md` | Arbeits-Skill: Modelle und Prozesse von Grund auf neu denken (seit 2.3) |
| `10_System\Pruefset-Vorlage.md` | Vorlage für das eigene Prüfset; die daraus angelegte `Pruefset.md` gehört dir und wird nie ersetzt (seit 1.18) |
| `02_Skills\README.md` | Erklärt, was ein Skill ist |
| `00_INDEX\scripts\build-index-geruest.ps1` | Index-Automatik |
| `00_INDEX\scripts\health-check.ps1` | Prüfskript |
| `00_INDEX\scripts\build-skill-wrapper.ps1` | Erzeugt die Skill-Zeiger für alle Werkzeuge (Abschnitt 11a) |
| `00_INDEX\scripts\guard-workspace.ps1` | Arbeitsbereich-Sperre, blockiert Schreibzugriffe ausserhalb des Repos und erzeugte Ausgabeformate in Themenordnern (Abschnitte 5 und 18) |
| `00_INDEX\scripts\guard-workspace-tests.ps1` | Regressionsreihe für die Arbeitsbereich-Sperre, Pflicht vor und nach jeder Änderung am Hook (seit 3.2; seit 3.3 mit eigener Reihe für macOS/Linux) |
| `00_INDEX\scripts\guard-git.ps1` | Sperre gegen pauschales Stagen (`git add -A`, `--all`, `.`), als Hook wirksam in jedem Berechtigungsmodus (Abschnitt 12, seit 3.3) |
| `00_INDEX\scripts\guard-git-tests.ps1` | Regressionsreihe für die Stagen-Sperre (seit 3.3) |
| `00_INDEX\scripts\guard-mail.ps1` | Mailversand-Sperre: jede Mail aus einer Session geht nur über `lib\gmail-senden.py`, jeder andere Sendeweg ist blockiert (Abschnitt 16, seit 3.4) |
| `00_INDEX\scripts\guard-mail-tests.ps1` | Regressionsreihe für die Mailversand-Sperre (seit 3.4) |
| `00_INDEX\scripts\lib\google_zugang.py` | Gemeinsame Google-Anmeldung (OAuth, Token im Benutzerprofil, eine Scope-Liste) für alle Skripte der Google-Anbindung (seit 3.4) |
| `00_INDEX\scripts\lib\mail_text.py` | HTML-, Text- und Adresshilfen für das Sendeskript (seit 3.4) |
| `00_INDEX\scripts\lib\google-sheets-fetch.py` | Holt ein Google Sheet als xlsx und Markdown-Tabelle in den Zwischenspeicher, für kopflose Läufe ohne Connector (seit 3.4) |
| `10_System\Google-Anbindung.md` | Einmalige Einrichtung des Google-Zugangs (Cloud-Projekt, APIs, Nutzertyp, OAuth-Client) und Kurzfassung der Mailregeln (seit 3.4) |
| `00_INDEX\scripts\session-kosten.py` | Misst den Verbrauch aller lokalen Claude-Code-Sessions zu Listenpreisen und liefert dem Health-Check die Ausreisser (Abschnitt 13, seit 3.3); die Berichtsdatei, die dabei entsteht (`00_INDEX\session-kosten.md`), gehört dir |
| `00_INDEX\scripts\weekly-diagnose.ps1` | Unbeaufsichtigte Wochendiagnose; bei jedem Lauf entsteht `10_System\health-check-report.txt`, und diese Berichtsdatei gehört dir (seit 1.19) |
| `00_INDEX\githooks\pre-commit` | Schutz vor beschädigten Commits |
| `.gitattributes` | Zeilenenden-Behandlung |
| `README.md` | Was dieses Grundgerüst ist. Beschreibt die Mechanik, nicht dich |
| `.github\ISSUE_TEMPLATE\mechanik-befund.md` | Die Issue-Vorlage für Befunde am Kern; wirkt nur im Core-Repo, gehört aber zur Mechanik (Lücke, gefunden im kalten Update-Lauf am 03.09.2026) |
| `00_INDEX\README.md` | Erklärt, wie die Indexdateien zusammenspielen |

Die generierten Skill-Zeiger in `.claude\skills\`, `.agents\skills\`, `.gemini\skills\`, `.cursor\skills\`, `.cline\skills\` und `.opencode\skills\` stehen bewusst in keiner der drei Kategorien: Sie werden bei jedem Health-Check neu aus deinem Register erzeugt und sind jederzeit wegwerfbar. Ein Update muss sie weder ersetzen noch schützen. Eigene Skills, die du dort liegen siehst, sind kein Verlust, wenn sie verschwinden: Die Wahrheit steht in `02_Skills`.

Ausnahme innerhalb dieser Dateien: **Inhalte von `AUTO:...:BEGIN/END`-Blöcken gehören nie zum Kern.** Sie werden maschinell erzeugt (z.B. die Rollen-Tabelle in der `AGENTS.md`) und nach einem Update ohnehin neu geschrieben, sobald das Index-Skript läuft.

## B. Kern mit lokalem Anteil: wird eingearbeitet, nie ersetzt

Diese Dateien sind Mechanik, tragen aber zwingend etwas von dir. Ein Update darf sie nur inhaltlich nachziehen und muss deinen Anteil erhalten.

| Datei | Dein Anteil |
|---|---|
| `CLAUDE.md` | Die `@`-Importzeilen, die auf deine Basiskontext-Dateien zeigen |
| `GEMINI.md` | dasselbe |
| `.clinerules` | dasselbe, hier als textliche Leseanweisung statt als Import |
| `.claude\settings.json` | Hängt die drei Sperren ein (Arbeitsbereich, seit 3.3 pauschales Stagen, seit 3.4 Mailversand). Dein Anteil sind eigene Berechtigungen und weitere Hooks, die ein Update nicht anfassen darf; unter macOS/Linux ausserdem der ausgeschriebene `pwsh`-Pfad in den Hook-Befehlen (`ANLEITUNG.md`, Teil 5, Schritt 7a) |
| `.codex\hooks.json` | Hängt dieselben Sperren in Codex ein (seit 3.2). Dein Anteil ist der ausgeschriebene Pfad zu deinem Repo, den ein Update nie durch den Platzhalter zurückersetzt, dazu eigene weitere Hooks |
| `.github\copilot-instructions.md` | dasselbe |
| `ANLEITUNG.md` | Nichts, solange du sie nicht ergänzt hast. Wenn doch, gilt sie als deine Datei |
| `.gitignore` | Deine eigenen Ignore-Zeilen. Neue Zeilen aus dem Grundgerüst werden ergänzt, deine nie entfernt |
| `10_System\Detailregeln aus AGENTS.md.md` | Alle Präzedenzfälle und Langbegründungen darin; das Grundgerüst liefert nur die leere Keimdatei (seit 1.18) |
| `00_INDEX\scripts\lib\gmail-senden.py` | Der Konfigurationsblock am Anfang zwischen `# --- KONFIGURATION` und `# --- ENDE KONFIGURATION` (dein Name, deine Adressen, Signatur, registrierte Routinen, erlaubte Domains, Wartezeit). Ein Update ersetzt alles ausserhalb des Blocks und lässt den Block stehen (seit 3.4) |
| `00_INDEX\scripts\lib\mail-sperrbegriffe.txt` | Alles darin: deine Sperrliste für den Mailversand; das Grundgerüst liefert nur die Keimdatei mit Beispielen (seit 3.4) |

## C. Deins: wird nie angefasst

Alles andere. Ein Update liest diese Dateien höchstens, um zu prüfen, ob deine eigenen Bauten noch zur neuen Mechanik passen, und meldet dir das. Geändert wird hier nichts.

- `MEIN-SYSTEM.md`, Abschnitte 1, 2 und 5: dein Inhalt, ein Update fasst ihn nie an.

  **Eine eng begrenzte Ausnahme, Abschnitt 3 und 4 derselben Datei.** Die beiden sind die Buchhaltung des Update-Skills über sich selbst und nicht dein Inhalt: Abschnitt 4 trägt die eingespielte Version, Abschnitt 3 die Liste deiner Abweichungen an Kern-Dateien. Beides schreibt der Skill fort, weil er sonst beim nächsten Lauf nicht weiss, von welchem Stand du kommst und was dir gehört. Er darf dort ausschliesslich diese beiden Dinge und den Schutzhinweis darüber schreiben, nie etwas anderes und nie in Abschnitt 1, 2 oder 5.
- `01_Basiskontext\*` (deine Person, dein Stil, deine Ziele)
- Alle Themenordner, die du angelegt hast, samt ihrer lokalen `AGENTS.md` und `_INDEX.md`
- `10_System\*` ausser `Kern-Dateien.md` (Architektur, Technik, Manual, Modellwahl, Zielsetzung beschreiben **dein** System, sobald du es aufgebaut hast)
- Alle Skills, die du selbst gebaut hast
- `02_Skills\Skill-Register.md` (dein Verzeichnis, wächst mit deinen Skills; der Update-Skill schlägt dir nur die Zeile für neue Kern-Skills vor)
- `00_INDEX\INDEX.md`, `00_INDEX\INDEX-Geruest.md` und alle `_INDEX.md` (maschinell erzeugt, aus deinen Inhalten)
- `00_INDEX\drift-ausnahmen.txt` (Commits, die der Health-Check bei der Drift-Prüfung überspringt; sie stammen aus deiner Historie, deshalb gehört die Datei dir. Sie liegt bewusst neben dem Prüfskript und nicht darin, weil das Skript Kategorie A ist und ein dort eingetragener Hash beim nächsten Update verloren wäre)
- `00_INDEX\lean-baseline.txt` (die Referenzgrössen, gegen die der Health-Check das Wachstum deines Pflichtkontexts misst. Sie beschreiben dein System, nicht das Grundgerüst, und der Check schreibt sie selbst fort. Löschen ist ungefährlich: Der nächste Lauf legt sie mit deinen heutigen Werten neu an)
- Der Kostenbericht, der bei jedem Health-Check neu entsteht: `00_INDEX\session-kosten.md` (mechanisch erzeugt aus deinen Transkripten, deshalb deins; steht in der `.gitignore`, weil er die Titel aller Sessions deines Rechners trägt)
- `03_Sessionlogs\*`, `04_Changelog\*`, `90_Inbox\*`

## Wenn du doch eine Kern-Datei ändern willst

Erlaubt, aber trag es in `MEIN-SYSTEM.md`, Abschnitt 3 ein. Der Update-Skill liest das, überschreibt deine Änderung dann nicht stillschweigend, sondern legt dir die neue Fassung daneben und arbeitet deine Anpassung ein.

Ohne diesen Eintrag merkt der Skill die Abweichung trotzdem (er vergleicht), aber er muss dich dann fragen, statt es zu wissen. Das kostet dich eine Rückfrage, nicht deine Arbeit.

Ergänzen ist dort erwünscht, löschen nicht: Was der Update-Skill in Abschnitt 3 hinterlassen hat, bleibt stehen. Und die Tabelle in Abschnitt 4 wird gar nicht von Hand angefasst, auch nicht kosmetisch; warum, steht dort.

**Seit 3.0 sagt dir der Agent das vorher, nicht erst beim Update.** Willst du eine Datei der Kategorie A ändern oder ihn ändern lassen, protestiert er einmal, bevor er schreibt (`AGENTS.md`, Abschnitt "Diese Datei ist Mechanik"): Die Änderung geht beim nächsten Update verloren oder blockiert es, und es gibt zwei Wege, auf denen sie sicher ist. Der Health-Check prüft dasselbe laufend (Kategorie `Mein-System`): Er vergleicht jede Kern-Datei mit der Fassung der bei dir eingespielten Version und meldet Abweichungen, die in `MEIN-SYSTEM.md`, Abschnitt 3 nicht stehen. Dafür braucht er den Remote `upstream` auf das Core-Repo; fehlt der, sagt er das und prüft nicht stillschweigend nichts.

**Die zwei sicheren Wege, je nachdem, für wen die Änderung ist:**

1. **Nur für dich:** als eigene Regel nach `MEIN-SYSTEM.md`, Abschnitt 2. Sie hat Vorrang vor dem Kern, und kein Update fasst sie an. Das ist der Weg für neunzig Prozent der Fälle, auch wenn die Änderung sich wie eine Verbesserung an der Mechanik anfühlt.
2. **Für alle Systeme auf diesem Kern:** als Pull Request gegen das Core-Repo (Adresse in `MEIN-SYSTEM.md`, Abschnitt 4). Dafür brauchst du einen Fork des Core-Repos auf GitHub, nicht deine Kopie aus der Vorlage; wie das geht, steht in `ANLEITUNG.md`, Teil 8. Ein Issue meldet einen Befund und überlässt die Behebung dem Herausgeber; ein Pull Request liefert die fertige Änderung mit. Beides wird gegen das Core-Repo gemessen, nicht ungeprüft übernommen, und beides ist öffentlich: kein Inhalt aus deinem System, keine Personendaten, keine wörtlichen Zitate aus privaten Dateien.

Die direkte Änderung an der Kern-Datei bleibt erlaubt; sie ist nur der Weg, der beim nächsten Update Arbeit kostet. Bestehst du darauf, trägt der Agent die Abweichung im selben Zug in `MEIN-SYSTEM.md`, Abschnitt 3 ein.

## Für den Fall, dass diese Liste und die Wirklichkeit auseinandergehen

Findest du eine Datei, die hier nicht steht, entscheidet die Kategorie C: Im Zweifel gehört sie dir und wird nicht angefasst. Ein Update, das eine unbekannte Datei überschreibt, ist ein Fehler, kein Feature.
