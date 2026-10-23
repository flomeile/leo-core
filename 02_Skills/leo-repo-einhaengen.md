---
name: leo-repo-einhaengen
trigger: '"repo einhängen", "wissensrepo einhängen", "geteiltes repo einhängen", "repo synchronisieren", "wissensrepo synchronisieren"'
zweck: Ein geteiltes Wissensrepo (Anleitungen, Regeln, Kontext eines Teams) als Ordner in dieses Repo einhängen und darin sicher arbeiten, also klonen oder forken, einrichten, Stand abgleichen, Änderungen per Pull Request vorschlagen
type: skill
version: 1.1
---

# Skill: Leo Repo einhängen

Ein **Wissensrepo** ist ein geteiltes Git-Repo, das mehrere Personen und ihre Agenten nutzen, zum Beispiel die Arbeitsanleitungen eines Teams. Es hat genau einen **Owner**: Nur er führt Änderungen in `main` zusammen, alle anderen schlagen sie per Pull Request vor.

**Eingehängt heisst:** Eine lokale Kopie des Wissensrepos liegt als Unterordner in einem Themenordner dieses Repos. Sie behält ihr eigenes Git. Dieses Repo ignoriert den Ordner (`.gitignore`), sein Inhalt gelangt nie in dein privates Repo. Gefunden wird er trotzdem wie jeder andere Ordner: Der Index führt ihn mit seinen Dateien, als fremdes Repo markiert, und die Suche findet ihn, weil das Einrichtungsskript ihn in `.ignore` freigibt (`AGENTS.md`, Abschnitt 4). Der Health-Check prüft ihn nach den Regeln eines geteilten Repos (gesichert, auffindbar, aktuell, ohne tote Links), nicht nach deinen eigenen (Frontmatter, kuratierte Beschreibungen). Umgekehrt sichert ein Hook, dass nichts Privates oder Vertrauliches aus deinem System in das geteilte Repo gelangt (`AGENTS.md`, Abschnitt 14). Der Agent hat deinen Kontext zuerst geladen und liest dann die `AGENTS.md` des Wissensrepos wie die lokale `AGENTS.md` eines Themenordners (`AGENTS.md`, Abschnitt 2).

**Zwei Wege, je nach deiner Rolle auf GitHub:**
- **Owner-Weg** (Rolle Admin oder Write): Du klonst das Repo selbst und arbeitest auf Zweigen darin.
- **Fork-Weg** (Rolle Read, der Normalfall für alle ausser dem Owner): Du legst auf GitHub eine eigene Kopie an (Fork), klonst diese und trägst das Original als zweite Quelle `upstream` ein. Änderungen gehen als Pull Request aus deinem Fork an das Original.

**Voraussetzungen:** Git for Windows (bringt das `sh` mit, in dem der Hook läuft; unter macOS und Linux ist `sh` ohnehin da), PowerShell 7 (`pwsh`), ein GitHub-Konto mit Zugriff auf das Wissensrepo (der Owner lädt dich ein; die Einladung kommt per Mail und wird dort angenommen) und für den Fork-Weg am bequemsten die GitHub CLI `gh`, angemeldet mit deinem Konto (`gh auth status` zeigt es). Fehlt `gh`, geht der Fork auch im Browser (Schritt 4). Fehlt etwas anderes, richtet der Agent es zuerst ein, mit einer Klickanleitung für `[NAME]`.

## Wann ausführen

- Ein Wissensrepo soll im Agenten benutzbar werden ("hänge das Repo X ein"), oder `[NAME]` will in einem eingehängten Repo den Stand abgleichen oder eine Änderung vorschlagen.
- Von selbst vorschlagen, wenn `[NAME]` ein geteiltes Repo erwähnt, das der Agent lesen soll, oder wenn der Health-Check in der Kategorie `Eingehaengte Repos` einen FAIL meldet (dann Schritt 5, Einrichten, nachholen).
- **Nicht:** für ein Repo, dessen Owner unbekannt ist (zuerst klären, wer `main` zusammenführt), und nicht für dein eigenes, privates Repo.

## Schritte: Einhängen (einmal je Repo)

1. **Owner und Modus klären.** Lies `README` und `AGENTS.md` des Wissensrepos auf GitHub, bevor irgendetwas anderes geschieht (`gh repo view <organisation>/<repo>` oder im Browser). Sie nennen den Owner und den Modus. Fehlt der Owner, Stopp: `[NAME]` fragt im Team nach.
2. **Die eigene Rolle feststellen:** `gh api repos/<organisation>/<repo> --jq .permissions`. `admin` oder `push` auf `true` heisst Owner-Weg, nur `pull` auf `true` heisst Fork-Weg. Antwortet GitHub mit "Not Found", ist die Einladung noch nicht angenommen oder fehlt; dann Stopp und `[NAME]` sagen, wen er fragen muss. Wer unsicher ist, geht den Fork-Weg.
3. **Zielordner wählen:** ein Unterordner im passenden Themenordner, nie ein eigener Hauptordner für geteilte Repos, weil dort die `AGENTS.md` der Themenordner auf dem Pfad fehlt, die dem Agenten den Zusammenhang gibt. Nennt das `README` des Wissensrepos einen Ordnernamen, gilt dieser; sonst ein Name, der zeigt, dass hier ein geteiltes Repo liegt und was darin steht, zum Beispiel `<repo> (geteilt)`. Existiert der passende Themenordner noch nicht, zuerst den Skill `leo-themenordner-anlegen` vorschlagen. Der Ordner muss in diesem Repo liegen.
4. **Klonen.** Owner-Weg:
   ```powershell
   git clone https://github.com/<organisation>/<repo>.git "<Themenordner>\<Ordnername>"
   ```
   Fork-Weg: zuerst den Fork anlegen, dann den eigenen Fork klonen und das Original als `upstream` eintragen.
   ```powershell
   gh repo fork <organisation>/<repo> --clone=false
   git clone https://github.com/<eigenes-konto>/<repo>.git "<Themenordner>\<Ordnername>"
   git -C "<Themenordner>\<Ordnername>" remote add upstream https://github.com/<organisation>/<repo>.git
   ```
   Ohne `gh` legt `[NAME]` den Fork im Browser an: `https://github.com/<organisation>/<repo>` öffnen, oben rechts auf **Fork** klicken, dann auf **Create fork**. Meldet GitHub, dass Forken nicht erlaubt ist, hat die Organisation es für private Repos abgeschaltet: Stopp, der Owner muss es freigeben (Organisation, **Settings**, **Member privileges**, **Allow forking of private repositories**, und im Repo **Settings**, **Allow forking**).
5. **Einrichten:**
   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File "00_INDEX\scripts\eingehaengtes-repo-einrichten.ps1" -Ordner "<Themenordner>\<Ordnername>" -Email "<geschäftliche Adresse von [NAME]>" -Name "<Vor- und Nachname>"
   ```
   Das Skript trägt den Ordner in deiner `.gitignore` ein, gibt ihn in `.ignore` für die Suche frei, setzt im eingehängten Repo deine geschäftliche Adresse als Git-Identität (nie die globale, die oft privat ist), legt dort drei Hooks an (Commit, Commit-Nachricht, Push) und prüft, dass sie laufen und dass dein Repo den Ordner nicht versioniert. Es bricht ab, wenn die Adresse auf deiner Sperrliste steht, wenn ein eigener Hook im Repo liegt oder wenn ein `core.hooksPath` die Hooks übergehen würde. Bei einem Abbruch: Meldung an `[NAME]`, nichts umgehen.
6. **Sperrliste prüfen:** `00_INDEX\scripts\lib\wissensrepo-sperrbegriffe.txt` gehört dir. Beim ersten Einhängen schlägt der Agent `[NAME]` vor, sie um die eigenen privaten Themenordner, die Anbieter der eigenen privaten Mailadressen und Begriffe aus dem eigenen Leben zu ergänzen, die in keine Firmenanleitung gehören. Schreiben erst nach dem Ja.
7. **Modus prüfen:** Die `AGENTS.md` des Wissensrepos nennt Owner und Modus. Fehlt die Modus-Zeile, gilt dort "Zweige mit Freigabe" (`AGENTS.md`, Abschnitt 12); die fehlende Zeile wird als Pull Request vorgeschlagen, nie still ergänzt.
8. **Abschluss:** Index-Skript und Health-Check laufen lassen; der Index zeigt den Ordner als eingehängtes Repo, die Kategorie `Eingehaengte Repos` zeigt ihn als gesichert und ohne Rückstand. `[NAME]` bekommt in zwei Sätzen, was jetzt geht: der Agent liest das Repo bei Fragen zum Thema, "repo synchronisieren" holt den neuen Stand, Änderungen schlägt der Agent als Pull Request vor.

## Schritte: Arbeiten im eingehängten Repo (jedes Mal)

1. **Stand abgleichen, bevor gearbeitet wird** (Frischecheck, `AGENTS.md`, Abschnitt 12; zu Sessionbeginn erledigt das die Grundpflege in Abschnitt 1, vor einer Änderung trotzdem nochmals): `git -C "<Ordner>" fetch --all --prune`, dann `git -C "<Ordner>" status -sb`. Steht dort `behind` oder `diverged`, wird nicht gearbeitet, sondern abgeglichen oder gefragt. Owner-Weg: `git -C "<Ordner>" switch main`, `git -C "<Ordner>" pull --ff-only`. Fork-Weg: `git -C "<Ordner>" switch main`, `git -C "<Ordner>" merge --ff-only upstream/main`, `git -C "<Ordner>" push origin main` (der eigene Fork wird nachgezogen; das gehört zum Synchronisieren und braucht kein eigenes Ja). Scheitert `--ff-only`, liegen eigene Commits auf `main`: nicht zusammenführen, `[NAME]` fragen.
2. **Ein Zweig je Änderung:** `git -C "<Ordner>" switch -c <thema>`. Nie auf `main` committen, nie `git add -A`; nur die eigenen Dateien einzeln stagen.
3. **Commit.** Der Hook läuft von selbst und blockiert Treffer der Sperrliste, private Autoradressen und Binärdateien. Er wird nicht mit `--no-verify` überfahren; das entscheidet nur `[NAME]`. Eine Binärdatei (Bild, PDF) geht erst durch, wenn `[NAME]` sie angesehen hat (sichtbare Namen, Bildmetadaten); dann `LEO_BINAER_GEPRUEFT=1` vor den Befehl, nie von sich aus.
4. **Pushen und Pull Request öffnen.** Ein Push ist eine Aktion nach aussen: nur auf Auftrag oder Ja von `[NAME]`. Owner-Weg: `git -C "<Ordner>" push -u origin <thema>`, dann `gh pr create --repo <organisation>/<repo> --base main --head <thema> --title "<Titel>" --body "<Text>"`. Fork-Weg: `git -C "<Ordner>" push -u origin <thema>` (in den eigenen Fork), dann `gh pr create --repo <organisation>/<repo> --base main --head <eigenes-konto>:<thema> --title "<Titel>" --body "<Text>"`. Titel und Text sind Pflicht, weil `gh pr create` ohne Terminal sonst abbricht statt nachzufragen; liegt im Repo eine Vorlage (`.github/pull_request_template.md`), folgt der Text ihr. Ohne `gh`: Nach dem Push zeigt GitHub auf der Seite des Forks den Knopf **Compare & pull request**. Die Adresse des Pull Requests steht in der Antwort. **Zusammengeführt wird nie vom Agenten**, auch nicht, wenn `[NAME]` selbst Owner ist: Der Owner prüft und merget selbst.
5. **Sprache gegenüber `[NAME]`:** Synchronisieren, Speichern, Vorschlagen statt Git-Begriffe. Nach jeder grösseren Aufgabe im Repo daran erinnern, dass der Vorschlag erst nach dem Merge durch den Owner für alle gilt.
6. **Rangfolge:** Fachliches und Format bestimmt das Wissensrepo, Stimme und Person bringt dein System; bei Widerspruch in der Sache gewinnt das Repo.
7. **Nie hineinschreiben:** Privates und Vertrauliches von `[NAME]` oder Dritten, Kundendaten, Personendaten ausser Funktionskontakten (Name, Funktion, Firma, geschäftliche Adresse und Nummer), persönliche Meinungen über Personen, Inhalte aus deinem eigenen Repo (`AGENTS.md`, Abschnitt 14). Im Zweifel nichts hineinschreiben und `[NAME]` fragen.

## Gesund und aktuell halten

- **Aktuell:** Der Health-Check holt bei jedem Lauf den Stand des Originals und meldet, wenn dort neue Commits liegen; dann "repo synchronisieren" vorschlagen (im Nutzungsmodus `benutzen` selbst ausführen, es ist ein reiner Abgleich ohne Wirkung nach aussen ausser dem Nachziehen des eigenen Forks).
- **Gesund:** Er meldet tote Links im geteilten Repo, ungespeicherte Änderungen auf `main`, eine fehlende Suchfreigabe und jede Lücke in der Absicherung. Fehler im Inhalt des geteilten Repos werden nie still im eigenen Klon behoben, sondern als Pull Request vorgeschlagen; für die inhaltliche Pflege ist der Owner zuständig.

## Regeln

- Keine Annahme über die Rolle: Wer nicht sicher ist, ob er Schreibrecht hat, geht den Fork-Weg.
- Ein Befund über das Wissensrepo (eine Anleitung weicht von der Wirklichkeit ab) wird als Pull Request vorgeschlagen, nicht still korrigiert und nicht nur im eigenen Repo notiert.
- Der Hook ist das zweite Netz, nicht das erste: Er fängt Stichworte, keine heikle Aussage ohne Stichwort. Das erste Netz ist die Regel in Schritt 7 und die Prüfung jedes Pull Requests durch den Owner.
- Kein Abgleich vor jedem Werkzeugaufruf: Er wäre langsam und bräuchte bei jedem Aufruf Netz. **Seit 4.7 läuft der Abgleich stattdessen bei jedem Sessionstart und spätestens alle 24 Stunden** (`AGENTS.md`, Abschnitt 1, Grundpflege): Die Hooks `SessionStart` und `UserPromptSubmit` rufen `00_INDEX\scripts\eingehaengte-repos-aktuell.ps1`, das `main` per Fast-Forward nachzieht, wenn dort nichts Eigenes liegt, und das Repo sonst mit Grund sperrt; in einem Werkzeug ohne diese Hooks ruft der Agent das Skript zu Beginn der Session selbst. Ein gesperrtes Repo wird nicht benutzt, bis es abgeglichen ist. Schritt 1 bleibt trotzdem Pflicht vor jeder Änderung, weil zwischen Sessionstart und Änderung Stunden liegen können, und der Fork wird dort nachgezogen, was das Skript nicht tut.
- Bringt ein eingehängtes Repo eigene Werkzeuge mit, die in fremden Systemen schreiben, prüfen diese Werkzeuge den Stand am besten selbst bei jedem Aufruf und brechen bei Rückstand ab: Sie brauchen das Netz ohnehin, und eine Textregel überliest ein Agent, der das Werkzeug direkt aufruft.
- Nicht gesehen werden vom Hook: Kommentare und Issues auf GitHub, Bearbeitungen im GitHub-Web, Binärinhalte und Merge-Commits, die GitHub selbst erzeugt. Dort gilt Schritt 7 ohne mechanisches Netz.
- **Wer auf GitHub zusammenführt, stellt dort zuerst die Adresse privat:** GitHub, Profilbild, **Settings**, **Emails**, Häkchen bei **Keep my email addresses private** und bei **Block command line pushes that expose my email**. Ohne diese Einstellung trägt jeder Merge-Commit, den GitHub beim Zusammenführen eines Pull Requests erzeugt, die Hauptadresse des Kontos als Autor, oft eine private, und kein lokaler Hook kann das verhindern. Das betrifft den Owner, aber auch jeden, der im eigenen Fork über die Weboberfläche zusammenführt.
- **Den eingehängten Ordner nie in einem Notiz-Werkzeug umbenennen oder verschieben** (etwa Obsidian mit automatischer Link-Aktualisierung): Das Werkzeug schreibt dabei Links in den Dateien des geteilten Repos um, oft auf Pfade deines eigenen Systems. Umbenennen nur über den Agenten (Ordner verschieben, Zeile in der `.gitignore` anpassen, Einrichtungsskript erneut laufen lassen) und danach `git -C "<Ordner>" status` prüfen: Auf `main` dürfen keine ungespeicherten Änderungen liegen. Der Health-Check warnt, wenn doch.

## Definition of Done

- [ ] Owner und Modus aus `README` und `AGENTS.md` des Wissensrepos bekannt
- [ ] Rolle festgestellt, Owner-Weg oder Fork-Weg gewählt; beim Fork-Weg `upstream` eingetragen
- [ ] Einrichtungsskript meldet OK, Health-Check zeigt den Ordner in `Eingehaengte Repos` als OK
- [ ] Vor jeder Arbeit Stand abgeglichen
- [ ] Änderungen nur als Pull Request, Adresse in der Antwort, nichts zusammengeführt
