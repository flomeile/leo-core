---
titel: Google-Anbindung (Gmail und Drive ohne Connector)
zweck: Einmalige Einrichtung und Regeln des Bausatzes, mit dem das System Mails über das eigene Google-Konto sendet und Google Sheets als Datei abholt, auch in kopflosen Läufen
type: systemdoku
version: 3.4
stand: 2026-09-15
---

# Google-Anbindung: Gmail und Drive ohne Connector

Der Bausatz besteht aus vier Kern-Dateien in `00_INDEX\scripts`:

| Datei | Was sie tut |
|---|---|
| `lib\google_zugang.py` | Die gemeinsame Anmeldung (OAuth) mit Token im Benutzerprofil, eine Scope-Liste für alle Skripte |
| `lib\gmail-senden.py` | Der einzige Sendeweg: erzwingt Offenlegung, Besitzer im CC, eigene Absenderadresse und Signatur, öffnet für jeden Text aus einer Session ein Freigabefenster, kann im bestehenden Thread antworten |
| `lib\google-sheets-fetch.py` | Exportiert ein Google Sheet als xlsx und auf Wunsch als Markdown-Tabelle, damit ein kopfloser Lauf es lesen kann |
| `guard-mail.ps1` | Der Hook, der jeden anderen Sendeweg aus einer Session sperrt (eingehängt in `.claude\settings.json` und `.codex\hooks.json`); Reihe: `guard-mail-tests.ps1` |

Dazu `00_INDEX\scripts\lib\mail_text.py` (HTML- und Adresshilfen) und `00_INDEX\scripts\lib\mail-sperrbegriffe.txt` (deine Sperrliste). Die Regeln dahinter stehen in der `AGENTS.md`, Abschnitt 16 (Mailversand). Ob du den Bausatz brauchst, entscheidet eine konkrete, wiederkehrende Aufgabe (YAGNI für Anbindungen, ebenfalls Abschnitt 16); der Hook wirkt unabhängig davon und sperrt fremde Sendewege auch in einem System, das nie eine Mail sendet.

## Warum kein Connector

Ein Connector hängt an der Sitzung der App. Ein kopfloser Lauf aus einer geplanten Aufgabe hat keine Sitzung und ist damit blind für alles, was nur über einen Connector erreichbar ist. Deshalb derselbe Weg wie bei jeder anderen Live-Quelle: deterministisch abholen, als Datei ablegen, das Modell liest die Datei. Und für das Senden gilt: Ein Skript kann Regeln erzwingen, ein Connector nicht.

**Zugang mit dem eigenen Konto, kein Dienstkonto.** Ein Dienstkonto müsste auf jedes geteilte Sheet erst freigegeben werden; mit der eigenen Anmeldung sieht das Skript genau das, was du siehst. Die Anmeldung hängt nicht an einem Abo oder Plan des LLM-Werkzeugs; sie überlebt jeden Wechsel dort.

## Einmalige Einrichtung

Am PC im Browser, angemeldet mit dem Google-Konto, über das gesendet und gelesen werden soll. Zwei Kontotypen, ein Unterschied in Schritt 4 und 5:

1. `console.cloud.google.com` öffnen. Erscheint eine Frage nach den Nutzungsbedingungen, zustimmen.
2. Oben links auf die Projektauswahl klicken (steht "Projekt auswählen" oder ein Projektname), dann rechts oben im Dialog auf **"Neues Projekt"**. Als Name den Namen deines Systems eintragen (im Gerüst `Leo`), auf **"Erstellen"** klicken, danach oben links dieses Projekt auswählen.
3. Oben in die Suchleiste `Google Drive API` eintippen, in der Trefferliste **"Google Drive API"** anklicken, dann auf den blauen Knopf **"Aktivieren"**. Dasselbe für `Gmail API`. Ohne die Gmail API bricht der Versand mit "Gmail API has not been used in project" ab.
4. In der Suchleiste `OAuth-Zustimmungsbildschirm` eintippen und den Treffer öffnen (englisch "OAuth consent screen"). Ausfüllen: App-Name wie das Projekt, Nutzersupport-E-Mail und Entwickler-E-Mail je die eigene Adresse. Alles Weitere leer lassen, "Speichern und fortfahren" bis zum Dashboard. **Nutzertyp:**
   - **Google-Workspace-Konto (Firma):** **"Intern"** wählen (Seite "Zielgruppe", Knopf "Als intern festlegen"). Damit entfallen Veröffentlichung, Überprüfung und die Warnung "nicht überprüft", und das Token läuft nicht ab.
   - **Privates Google-Konto:** **"Extern"** wählen, dann Schritt 5.
5. **Nur beim privaten Konto, sonst läuft der Zugang nach sieben Tagen ab:** Auf derselben Seite den Knopf **"App veröffentlichen"** (englisch "Publish app") drücken und die Rückfrage bestätigen. Der Status muss danach "In Produktion" lauten. Bleibt er auf "Testing", muss die Anmeldung jede Woche wiederholt werden. Ist der Knopf gesperrt, fehlt meist eine Angabe auf der Branding-Seite (App-Name, Support-Adresse).
6. In der Suchleiste `Anmeldedaten` eintippen (englisch "Credentials"), oben auf **"+ Anmeldedaten erstellen"**, dann **"OAuth-Client-ID"**. Als Anwendungstyp **"Desktop-App"** wählen, Name wie das Projekt, auf "Erstellen".
7. Im Bestätigungsfenster auf **"JSON herunterladen"** klicken. Die Datei landet in den Downloads und heisst etwa `client_secret_1234....json`.
8. Diese Datei ins Benutzerprofil verschieben und dabei umbenennen. In PowerShell, ein Befehl:

   ```powershell
   Move-Item "$env:USERPROFILE\Downloads\client_secret_*.json" "$env:USERPROFILE\.leo-google-client.json"
   ```

9. Einmalig die Python-Bibliotheken installieren (`openpyxl` nur, wenn `google-sheets-fetch.py --markdown` gebraucht wird):

   ```powershell
   pip install google-auth-oauthlib google-api-python-client openpyxl
   ```

10. Die erste Anmeldung durchführen. Es öffnet sich der Browser: das richtige Google-Konto wählen und die drei Zugriffe bestätigen (Drive lesen, Gmail senden, Gmail lesen). Beim privaten Konto kommt die Warnung "Google hat diese App nicht überprüft": auf **"Erweitert"** und dann auf **"Weiter zu <Projektname> (unsicher)"** klicken; das ist die eigene App.

    ```powershell
    python "C:\Leo\00_INDEX\scripts\lib\gmail-senden.py" --auth
    ```

11. Den Konfigurationsblock am Anfang von `00_INDEX\scripts\lib\gmail-senden.py` ausfüllen: dein Name und deine Adresse (`BESITZER_NAME`, `BESITZER_ADRESSE`), die Absenderadresse des Assistenten als Plus-Adresse desselben Kontos (`ABSENDER_ADRESSE`, z.B. `anna.muster+leo@example.com`; Gmail nimmt sie ohne weitere Einrichtung als Absender an, Antworten darauf landen in deinem Posteingang) und der Anzeigename (`ABSENDER_NAME`, ohne Klammern). Der Block ist dein Anteil an dieser Datei; ein Update ersetzt nur, was ausserhalb steht (`Kern-Dateien.md`, Kategorie B).
12. Testen, nur an dich selbst. Das Fenster erscheint ohne Tastaturfokus; zum Senden hineinklicken. Der Werkzeugaufruf braucht ein Timeout von 600000 ms, weil das Skript auf den Klick wartet.

    ```powershell
    Set-Content "$env:TEMP\test.html" "<p>Testmail.</p>"
    python "C:\Leo\00_INDEX\scripts\lib\gmail-senden.py" --an deine@adresse --betreff "Test" --html "$env:TEMP\test.html"
    ```

**Wo die Zugangsdaten liegen und warum nicht im Repo:** `%USERPROFILE%\.leo-google-client.json` und `%USERPROFILE%\.leo-google-token.json`. Beide geben Zugriff auf dein Google-Konto und gehören nicht nach Git; das Skript-Prinzip aus Abschnitt 16 der `AGENTS.md` gilt (kein Token je in einem Kommandotext oder im Lesewerkzeug).

**Scopes, bewusst drei und in allen Skripten dieselben:** `drive.readonly`, `gmail.send`, `gmail.readonly`. Ein Skript, das mit einem Token ohne seinen Scope startet, würde eine Neuanmeldung verlangen; deshalb tragen alle Skripte über `google_zugang.py` dieselbe Liste. Die Leseberechtigung braucht `--antwort-auf` (die Originalnachricht für den Thread), sonst nichts; ein eigenes Leseskript bringt der Bausatz nicht mit.

## Was das Sendeskript erzwingt

Kurzfassung der Regeln, die in `gmail-senden.py` als Code stehen und in der `AGENTS.md`, Abschnitt 16 als Regel; ein Schalter dagegen existiert nicht:

- **Offenlegung** oben in jeder Mail (der KI-Assistent hat sie geschrieben, sie kann Fehler enthalten), **Signatur** unten, beides in der Sprache des Textes (Deutsch oder Englisch, automatisch erkannt, `--sprache` erzwingt).
- **Du im CC**, immer; `--cc` ergänzt dich, ersetzt dich nie.
- **Eigene Absenderadresse** des Assistenten mit Anzeigename.
- **Freigabefenster für jeden Text aus einer Session:** Absender, Empfänger, Betreff, Anhänge (mit Öffnen-Knopf und Häkchen) und der volle Text, direkt änderbar; "Im Browser ansehen" zeigt die fertige Mail; gesendet wird erst nach dem Klick auf Senden. Ohne Bildschirm (kopflos, Remote) gibt es keinen Versand aus einer Session. Das Fenster ist tastatursicher: kein Fokus beim Erscheinen, kein Feld reagiert auf Tasten, bevor du es anklickst, Senden nimmt in den ersten zwei Sekunden keinen Klick an. Verpasst du es (acht Minuten), liegt die Mail als Paket in `<Repo> Artifacts\_Cache\mail-freigaben`; `--offen` listet, `--wiedervorlage <kennung>` öffnet das Fenster neu.
- **Direkt senden dürfen nur registrierte Routinen ohne Modell** (Liste `ROUTINEN` im Konfigurationsblock, erkannt am Pfad des laufenden Skripts), nur an `ERLAUBTE_DOMAINS_DIREKT`, nie an `EMPFAENGER_MIT_FREIGABEPFLICHT`, nie mit Sperrbegriff. Eine Routine lädt das Modul aus seiner Datei, baut mit `baue_nachricht(...)` und sendet mit `sende(msg)`.
- **Kein Repo- und kein Archivpfad als Mailtext oder Anhang.** Der Text entsteht im Scratchpad; eine Repo-Datei, die mit soll, wird vorher dorthin kopiert.
- **Sperrbegriffe** aus `mail-sperrbegriffe.txt`: rot markiert, Senden erst nach dem Häkchen "Geprüft, trotzdem senden"; eine Routine bricht ab.
- **Antworten bleiben im Thread:** `--antwort-auf <Message-ID oder Gmail-ID>` setzt In-Reply-To, References und die Thread-ID, übernimmt Empfänger und "Re:"-Betreff aus dem Original und hängt den Verlauf als Zitat an; ohne auffindbares Original bricht der Aufruf ab, statt einen neuen Thread zu öffnen.

**Der Hook `guard-mail.ps1`** sperrt daneben jeden anderen Sendeweg aus einer Session: eigene Gmail-API-Aufrufe, `smtplib`, `Send-MailMessage`, .NET-Mail, Kommandozeilen-Mailer, Mail-Clients per COM, das Laden des Sendemoduls aus eigenem Code (`python -c`, `spec_from_file_location`), jede Kopie des Skripts und jede Tastatur- oder Maus-Automation, die den Klick im Fenster ersetzen könnte. Er sieht nur den Text des Werkzeugaufrufs (dieselbe Grenze wie bei der Arbeitsbereich-Sperre, `AGENTS.md`, Abschnitt 18). Wer ihn ändert, fährt vorher und nachher `guard-mail-tests.ps1`.

## Ein Sheet abholen

```powershell
python "C:\Leo\00_INDEX\scripts\lib\google-sheets-fetch.py" --sheet <ID> --xlsx "<Repo> Artifacts\_Cache\google\liste.xlsx" --markdown "<Repo> Artifacts\_Cache\google\liste.md" --zeilen 10
```

Die ID steht in der URL des Sheets (`docs.google.com/spreadsheets/d/<ID>/edit`); `<Repo> Artifacts` ist der Geschwisterordner neben deinem Repo für erzeugte Dateien (`AGENTS.md`, Abschnitt 18), ausgeschrieben also der Pfad deines Repos plus " Artifacts". Die Markdown-Datei trägt die letzten Zeilen des ersten Blattes (oder `--blatt <Name>`) als Tabelle, Kopfzeile aus der ersten Zeile; scheitert der Abruf, steht der Fehler in der Markdown-Datei, damit ein kopfloser Lauf eine Lücke nicht für eine unauffällige Woche hält. Deutung macht das Skript keine; die Einordnung gehört dem Modell, das die Datei liest. Eine Routine, die daraus einen Bericht baut und versendet, ist dein eigener Bau: Sie steht als Skript in `00_INDEX\scripts`, holt über dieses Skript, sendet über `gmail-senden.py` und steht dort in `ROUTINEN`.
