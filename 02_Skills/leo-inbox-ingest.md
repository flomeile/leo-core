---
name: leo-inbox-ingest
trigger: '"ingest", "ingesten", "inbox verarbeiten", "verarbeite die inbox", "übernimm das ins repo"'
zweck: Inbox-Rohquellen (PDF, Scans, Office-Dateien, Mails, Screenshots) ohne Informationsverlust und ohne Halluzination in konsolidierte Wissensnotizen der Themenordner überführen, offene Punkte gesammelt zur Entscheidung vorlegen, Rohquellen danach ins Belegarchiv verschieben (gelöscht wird nur, was keinen Belegwert hat)
type: skill
version: 1.0
---

# Skill: Leo Inbox-Ingest

Der Standardweg, wie neues Wissen ins Repo kommt: Rohquellen aus `90_Inbox` werden vollständig gelesen, mit dem bestehenden Wissen abgeglichen, in die passenden Notizen der Themenordner konsolidiert und nach bestandener Verifikation ins Belegarchiv `<Repo> Archiv` verschoben (Schritt 7). Das Repo ist ein abfragbares Gedächtnis, keine Dateiablage (`AGENTS.md`, Abschnitt 5). Teil des Grundgerüsts seit 4.3; vorher verwies die `AGENTS.md` auf Ingest-Grundsätze, ohne sie mitzuliefern.

Voraussetzungen: Datei-Schreibzugriff, PowerShell (Zeitstempel, Git, Index-Skript) und ein Werkzeug plus Modell, das PDF und Bilder lesen kann (Vision). Fehlt eine dieser Fähigkeiten: betroffene Dateien NICHT verarbeiten, sondern `[NAME]` sofort und präzise melden, welche Datei warum nicht lesbar ist und welches Werkzeug oder Modell es bräuchte. Nie still degradieren, nie raten.

## Wann ausführen

- Wenn `[NAME]` ein Trigger-Wort nennt, mit oder ohne Nennung einzelner Dateien.
- Ohne Nennung einzelner Dateien gilt: die gesamte `90_Inbox` (ausser `README.md`); vorher den Umfang in Zahlen nennen (`AGENTS.md`, Abschnitt 1, Auftrag ohne Eingrenzung).
- Auch dann, wenn die Quelle keine Datei ist, sondern eine URL im Auftrag. Der Umfang ist dann genau diese URL, die Inbox bleibt unangetastet, und der Archivschritt entfällt.
- Ebenso, wenn `[NAME]` den Text direkt in den Auftrag kopiert. Der Umfang ist genau dieser Text, der Archivschritt entfällt. Ein solcher Text ist meist ein Ausschnitt: Jahreszahl, Absenderrolle und Anlass fehlen typischerweise und gehören in die Fragensammlung statt in eine stille Annahme. In der Quellenliste der Zielnotiz steht die Herkunft ausformuliert ("von `[NAME]` am TT.MM.JJJJ direkt in die Session eingebracht, keine Datei"), damit später niemand eine archivierte Rohdatei sucht, die es nie gab.
- NICHT für: neue Themenordner (`leo-themenordner-anlegen`), Session-Zusammenfassungen (`leo-wrap-up`), reine Ablage-Hygiene ohne inhaltliche Verarbeitung (`leo-system-health-check`). Eigene Abläufe für besondere Unterlagen (etwa Personalunterlagen, die gar nicht ins Repo sollen) gehören als eigene Regel nach `MEIN-SYSTEM.md` oder in die lokale `AGENTS.md` des Themenordners und gehen diesem Skill vor.

## Grundsätze (nicht verhandelbar)

Der Massstab: Ein LLM, das später auf dem Repo arbeitet, darf aus einer ingesteten Notiz keine einzige falsche Aussage ziehen können.

1. **Jede Aussage ist rückführbar.** Jeder Satz in einer Zielnotiz stammt aus genau einer benennbaren Quelle (der Rohquelle, einer bestehenden Repo-Datei oder dem Auftragstext). Was sich nicht zuordnen lässt, wird nicht geschrieben.
2. **Keine Verschmelzung unabhängiger Aussagen.** Zwei Quellen, die zum selben Thema Verschiedenes sagen, bleiben zwei getrennt zitierte Aussagen. Beispiel: Eine Planung nennt "Integration über einen Partner", ein Protokoll nennt Gespräche mit Firma X; daraus wird NIE "Firma X ist der Partner", sondern zwei getrennte Stränge plus eine offene Frage.
3. **Keine erfundenen Zusammenhänge.** Korrelationen, Kausalitäten und Schlussfolgerungen nur, wenn eine Quelle sie ausdrücklich belegt. Eine naheliegende, aber unbelegte Folgerung wird weggelassen oder gekennzeichnet ("Schlussfolgerung, nicht belegt") und in die Fragensammlung aufgenommen.
4. **Nachfragen schon bei geringer Unsicherheit.** Sobald ein Fakt (Name, Zahl, Datum, Betrag, Zuständigkeit) nicht hundertprozentig sicher gelesen oder verstanden ist, wird er NICHT übernommen, sondern als Frage gesammelt. Lieber fünf Fragen zu viel als eine falsche Information im Repo.
5. **Keine unabgesprochenen Unsicherheiten in Notizen.** Alles Unsichere ist in der Notiz ausdrücklich als unsicher gekennzeichnet UND steht in der Fragensammlung, oder es steht gar nicht in der Notiz.
6. **Ins Archiv verschoben wird erst nach bestandenem Verifikationspass** (Schritt 6). Gelöscht wird nur, was keinen Belegwert hat (Schritt 7).

## Schritte

### 1. Zeit holen und Umfang festlegen
```powershell
Get-Date -Format "yyyy-MM-dd HH:mm"
```
Umfang: die genannten Dateien, sonst alle Dateien in `90_Inbox` ausser `README.md`. Eine leere Fragensammlung beginnen; sie wird in allen folgenden Schritten befüllt und in Schritt 10 gesammelt vorgelegt. Zwischendurch wird NICHT einzeln nachgefragt.

### 2. Quellen vollständig lesen
Jede Quelle ganz lesen, nichts überspringen. Rohmaterial wird vor dem Lesen per Skript eingedampft, nie von `[NAME]` von Hand (`AGENTS.md`, Abschnitt 1, Bündelungsregel).

**Konvertierung nach Markdown ist eine Beschleunigung, die Rohquelle bleibt die Quelle.** Ist ein Konverter installiert (etwa `anydoc` oder `markitdown`), ist er der Standardweg für alles, was das Werkzeug nicht nativ öffnen kann: Docx, Doc, Xlsx, Xls, Pptx, Ppt, RTF, EPUB, ODT, ODS, ODP, CSV. Ziel der Konvertierung ist immer der Scratchpad, nie ein Themenordner und nie die Inbox. Vier Regeln:

- **Bei PDF bleibt das native Lesen der Standard.** Ein konvertiertes PDF wird nur dann Lesegrundlage, wenn die Quelle einspaltiger Fliesstext ist (Mailausdruck, Bericht, Vertrag) UND eine Stichprobe an zwei Originalseiten bestätigt, dass Reihenfolge und Absatzgrenzen stimmen. Bei mehrspaltigen Layouts, Kacheln, Formularen und Präsentationsausdrucken mischen Konverter Text aus getrennten Feldern in dieselbe Zeile, und aus zwei richtigen Aussagen wird eine falsche dritte.
- **Kann das Werkzeug ein PDF nicht anzeigen, wird es in Bilder gerendert, statt auf einen Textextrakt auszuweichen.** Mit PyMuPDF (falls installiert): `import fitz; d = fitz.open(quelle)`, dann je Seite `p.get_pixmap(dpi=170).save(...)` in den Scratchpad, die PNG danach als Bild lesen. Der Grund ist ein Datenfehler, keine Bequemlichkeit: Textextrakte wie `pdftotext -layout` ordnen die Werte mehrspaltiger Zahlentabellen nachweislich der falschen Zeile zu, und der Extrakt sieht dabei völlig plausibel aus. Bei Zahlenwerken gilt deshalb: Bild lesen und, wo es auf die Zeilenzuordnung ankommt, koordinatengenau prüfen (`p.get_text("words")` liefert je Wort x/y). Zwei Fallstricke: Ein Python-Modul, das im Benutzerverzeichnis installiert ist, fehlt im isolierten Modus (`python -I`) und kann in einem anderen Shell-Werkzeug unsichtbar sein; eine Meldung "No module named ..." ist deshalb erst ein Befund, wenn derselbe Aufruf in der anderen Shell und ohne `-I` gescheitert ist (`AGENTS.md`, Abschnitt 6, Werkzeug ausgeschöpft).
- **Eine leere oder auffällig kurze Ausgabe ist ein Warnsignal, kein Befund.** Eine Präsentation aus reinen Bildfolien liefert 0 Byte bei Erfolgsmeldung. Unter etwa 200 Byte wird immer die Rohquelle selbst angesehen. Aus einer leeren Konvertierung folgt nie die Aussage, das Dokument habe keinen Inhalt (`AGENTS.md`, Abschnitt 6: eine Lücke ist kein Fakt).
- **"Nicht konvertierbar"** (Bild-PDF, verschlüsselt, beschädigt) ist kein Grund, die Quelle zu überspringen: Dann gilt der Weg über Vision, und fehlt die Vision-Fähigkeit, wird gemeldet statt geraten.

Formatregeln:
- **Mails: bevorzugt als `.eml` oder `.html`.** Beide behalten die echten Linkziele, die ein PDF- oder Text-Export verliert; bei Newsletter- und Kampagnenmails sind die Links oft der eigentliche Inhalt. Vor dem Lesen per Skript Markup, Styles und Tracking-Links entfernen (bei Newslettern oft mehr als die Hälfte des Textes, und jeder folgende Modellaufruf zahlt sie erneut), Linkziele separat als Liste ausgeben. **Ein Textauszug einer Mail enthält ihre Anhänge nicht und nennt sie oft nicht einmal.** Deshalb im selben Schritt die MIME-Teile auflisten und jeden Anhang in den Scratchpad schreiben (Python `email` mit `policy.default`, Ausgabe mit `PYTHONIOENCODING=utf-8`); ist die Mail deutlich grösser als ihr Text, liegt fast sicher ein Anhang drin. Die Anhänge bleiben in der archivierten Mail.
- **Scans, Handschrift, Screenshots:** per Bild-Lesen erfassen. Unleserliches als `[unleserlich]` festhalten, unsicher Gelesenes als `[unsicher gelesen: "..."]`. Solche Stellen kommen in die Fragensammlung; der Fakt wird bis zur Klärung nicht übernommen (Grundsatz 4). Bei Handschrift-OCR das Jahr gegen Dateiname und Inhalt plausibilisieren: OCR verliest Jahreszahlen zuverlässig, und ein falsches Jahr wandert über die Zusammenfassung in den Index und verschiebt das Dokument um Jahre.
- **Docx:** Konverter lassen eingebettete Bilder stumm weg, und gerade ein Diagramm trägt oft Namen, die im Text nicht stehen. Deshalb `word/media/` im Docx-Zip auflisten, jedes Bild extrahieren und als Bild lesen; dazu die Metadaten in `docProps/core.xml` (Autor, Erstell- und Änderungsdatum), weil ein Entwurf ohne Datum im Text sein Datum dort trägt.
- **Excel:** ALLE Arbeitsblätter lesen, auch solche mit Namen wie "ALT", "Archiv" oder "Entwurf". Dort liegt regelmässig der Entwurfsstand mit den Positionen einzelner Personen und abgeschafften Regelungen, und genau das erklärt, warum die gültige Fassung so aussieht. Zwei Prüfungen gegen die Konvertierung: Passt die Zahl der Abschnitte zur Zahl der Blätter, und beginnt eine Tabelle mit leerer Kopfzeile (dann stehen die echten Spaltentitel in der ersten Datenzeile)?
- **Cloud-Dokumente** (Google Drive und Vergleichbares): bevorzugt als Export (PDF, Docx, Xlsx) in die Inbox. Liegt nur ein Link vor und ist ein Connector verfügbar, wird er genutzt; **Tabellen immer als Xlsx herunterladen, nie als CSV oder Textabruf**: Diese brechen bei grossen Dateien lautlos ab und liefern nur das erste Blatt. Nach jedem Abruf prüfen, ob der letzte Datensatz zum erwarteten Aktualitätsstand passt; eine laufend gepflegte Liste, die Jahre in der Vergangenheit endet, ist abgeschnitten.
- **URL als einzige Quelle:** per Web-Werkzeug abrufen. Liefert der erste Abruf eine Zusammenfassung statt des Textes, ein zweites Mal gezielt nach dem Rohtext fragen und beide gegeneinander halten; weichen sie ab, gilt Grundsatz 4. Gibt die Seite nur Login-Wall, Cookie-Banner oder Teaser her, wird nichts übernommen, sondern gemeldet. Als Quellendatum zählt das Abrufdatum; ein Veröffentlichungsdatum nur, wenn es real auf der Seite steht.
- **Audio und Video:** Erst prüfen, ob ein Transkriptionsweg existiert (`ffmpeg` plus `whisper` oder `faster-whisper`); fehlt er, wird die Datei NICHT ausgewertet und das Fehlende präzise gemeldet. Solche Dateien werden **nie gelöscht und nie ins Repo gelegt** (eine grosse Mediendatei in Git ist ein Fehler, ihre Löschung ein unwiederbringlicher Verlust), sondern in den Artefakte-Ordner `<Repo> Artifacts` verschoben, mit einer `README.md`, die festhält, was nicht ausgewertet wurde und wie es nachzuholen wäre.
- **Nicht lesbares Format oder fehlende Vision-Fähigkeit:** Datei überspringen und präzise melden (Datei, Grund, was es bräuchte). Nie aus Dateinamen oder Bruchstücken auf den Inhalt schliessen.

Beim Lesen das Quellendatum bestimmen (Datum des Inhalts, etwa Maildatum, nicht das Änderungsdatum der Datei). Mehrere Quellen werden in Schritt 5 chronologisch verarbeitet, älteste zuerst.

### 3. Bestehendes Wissen abgleichen

**Zuerst prüfen, ob die Quelle schon einmal verarbeitet wurde.** Rohquellen tauchen wieder in der Inbox auf, etwa ein erneut exportierter Mailverlauf, der den bereits verarbeiteten Teil mitbringt. Wer das übersieht, schreibt dieselbe Information ein zweites Mal an einen zweiten Ort. Deshalb nach dem Dateinamen und nach charakteristischen Textstellen im Repo suchen; die Quellenlisten bestehender Notizen führen verarbeitete Quellen mit ihrem Archivpfad unter `Beleg:`. Bei einem Treffer wird der Umfang auf den wirklich neuen Teil eingegrenzt und im Bericht benannt, was schon abgedeckt war und wo.

**Ein Auftrag, ein externes Dokument 1:1 abzulegen, steht unter dem Vorbehalt dieses Abgleichs.** Kommt ein Dokument mit dem Anspruch, Leitplanke oder Standard zu sein (extern erstellter Bericht, Konzept, Regelwerk, fremder Skill), und widerlegt der Abgleich es an tragenden Stellen, wird es NICHT abgelegt und nachträglich kommentiert. Stattdessen: Befund melden, bevor geschrieben wird, und eine ersetzende Fassung vorschlagen. Ein falsches Leitdokument bleibt nicht allein; es wird zitiert und in Folgeprodukte überführt, und keine Kopie trägt den Kommentar mit.

Suchstrategie aus `AGENTS.md`, Abschnitt 4: Root-Index, lokale `_INDEX.md` der betroffenen Themen, Synonym-Volltextsuche im Datei-Inhalt, nur Treffer ganz lesen, inklusive `stand:`-Prüfung. Für jeden Zielordner die lokale `AGENTS.md` lesen, inklusive der übergeordneten auf dem Pfad (Abschnitt 2).

### 4. Zuordnung entscheiden
Je Quelle bzw. je thematischem Block einer Quelle genau eine Option:
- **Fortschreiben:** Es gibt eine passende lebende Notiz. Default, wenn vorhanden.
- **Neue Notiz:** Thema klar, aber noch keine passende Notiz. Anlegen im passenden Themenordner.
- **Aufteilen:** Eine Quelle trägt Information für mehrere Themenordner. Jeder Teil geht in die passende Notiz, jede Zielnotiz zitiert dieselbe Quelle, die Notizen verweisen aufeinander, wo der Zusammenhang zählt. Archiviert wird erst, wenn ALLE Teile verifiziert übernommen sind.
- **Ausnahme eigenständiger Wert:** Die Rohquelle bleibt als saubere `.md` (nie als PDF, Scan oder Bild) im Themenordner, wenn (a) der Wortlaut selbst das Wissen ist (Verträge, rechtlich relevante Zusagen, eigene Mitschriften mit eigenen Markierungen), (b) noch nicht ausgewertetes Material absehbar gebraucht wird (dann mit `stand:` und Vermerk, was offen ist), oder (c) ein Nachschlagewerk als Ganzes konsultiert wird. Im Zweifel: Fragensammlung. Format für jede so behaltene Rohquelle, immer alle drei Teile:
  1. **Frontmatter davor** nach `AGENTS.md`, Abschnitt 5 (`type: rohquelle`).
  2. **Der Originaltext bleibt byte-identisch**, auch Tippfehler und eigene Markierungen. Geprüft wird das technisch, nicht behauptet: Die neue Datei muss den alten Textkörper als exakte Teilzeichenkette enthalten. Beim Formatwechsel (`.txt` nach `.md`) vorher die Kodierung feststellen (BOM, Umlaut als `C3 BC`?), sonst zerstört das Einlesen als falsche Kodierung still alle Sonderzeichen.
  3. **Ein Abschnitt "Einordnung ins Repo" am Ende**, durch Trennlinie und Überschrift als nicht zur Quelle gehörend gekennzeichnet: nur Querverweise mit Begründung, festgestellte Abweichungen zu bestehenden Repo-Aussagen und die Quellenangabe, keine Zusammenfassung.
- **Zweifelsfall:** Zielordner unklar oder ein neuer Themenordner wäre nötig. Datei bleibt in der Inbox, Frage in die Fragensammlung (gegebenenfalls mit Vorschlag `leo-themenordner-anlegen`). Themenordner werden NIE vom Ingest angelegt.

### 5. Konsolidieren
Chronologisch, älteste Quelle zuerst. Verarbeitungseinheit ist die Zielnotiz: erst alle Quellen sammeln, die dieselbe Notiz betreffen, dann die Notiz einmal sauber schreiben.

**Schreiben für das LLM:**
- **Frontmatter ist Pflicht:** `titel`, `zweck`, `type` aus der Liste in `AGENTS.md`, Abschnitt 5, dazu `stand:` (echtes Tagesdatum aus Schritt 1), sobald der Inhalt veränderlich ist, und `herkunft:` nach Abschnitt 6.
- Dateiname sprechend, ohne Sonderzeichen; zeitgebundene Dokumente mit Präfix `YYYY-MM-DD_`.
- Bei längeren Notizen ein Management Summary an den Anfang; Tabellen für aufzählbare Fakten, Fliesstext für Zusammenhänge.
- Auffindbarkeit: zentrale Begriffe UND ihre Synonyme natürlich im Text; die Volltextsuche findet nur, was wörtlich dasteht.
- Ein Abschnitt "Unsicherheiten und offene Fragen", wo es Unsicheres gibt.
- Quellenliste am Ende: jede Quelle mit Absender, Datum, Betreff oder Titel und Verarbeitungsdatum, plus Archivpfad in Backticks unter `Beleg:` (oder der Vermerk "ohne Belegwert, gelöscht").

**Fremder Wortlaut wird verdichtet, nicht kopiert.** Bei urheberrechtlich geschütztem Fremdmaterial (Artikel, Bücher, Posts, Videos Dritter) steht in der Zielnotiz die Verdichtung in der Arbeitssprache; einzelne Sätze im Original nur, wo die Form selbst den Wert trägt, in Anführungszeichen und dem Urheber zugeordnet. Material aus dem eigenen Umfeld (eigene Mitschriften, an `[NAME]` gerichtete Mails, Verträge, Protokolle) bleibt dagegen im Wortlaut, wo der Wortlaut die Sache ist.

**Fortschreibung und Widerspruch, drei Fälle:**
1. **Fortschreibung:** Die neue Quelle ist belegbar jünger und beschreibt denselben veränderlichen Zustand. Der alte Wert wird ersetzt, die Quellenliste dokumentiert es. Hat die Historie eigenen Wert (Verschiebungen, Preisentwicklung, Strategiewechsel), bleibt der alte Stand als datierte Verlaufszeile; ist das unklar: Fragensammlung.
2. **Echter Widerspruch:** Zwei Quellen sagen Unvereinbares, und es ist nicht belegbar, welche gilt. BEIDE Aussagen bleiben mit Quelle in der Notiz, ausdrücklich als Widerspruch gekennzeichnet, dazu eine Frage mit genau drei Auflösungsvorschlägen, einer davon empfohlen und begründet.
3. **Widerspruch zum Basiskontext:** `01_Basiskontext` wird im Ingest NIE geändert (`AGENTS.md`, Abschnitt 8). Befund in die Fragensammlung, mit drei Vorschlägen inklusive Empfehlung; Umsetzung nur nach ausdrücklicher Bestätigung plus Changelog-Eintrag.

**Querverweise sind Pflicht, wo eine echte Beziehung besteht**, und zwar in beide Richtungen: Die neue Notiz zeigt auf die bestehende, und die bestehende bekommt den Rückverweis, sonst bleibt die Verbindung beim Lesen der alten Datei unsichtbar. Form und Begründungspflicht: `AGENTS.md`, Abschnitt 5. Nur auf Dateien verlinken, deren Existenz und Inhalt im selben Lauf per Werkzeug geprüft wurden. Nie mit einem Wikilink auf eine archivierte Rohquelle zeigen; sie liegt ausserhalb des Repos und wird textlich zitiert plus Archivpfad in Backticks. Sparsam und begründet: Fünf Verweise ohne Grund sind schlechter als zwei mit. Anlässe sind dieselbe Person, dasselbe Projekt, Quelle zu Synthese, Vorgänger zu Nachfolger, Entscheid zu Umsetzung; reine Wortüberschneidung ist keiner.

**Herkunft und Haltbarkeit kennzeichnen:**
- **Kein `geprueft:` auf Ingest-Ergebnisse**, sondern `herkunft: quelle` (oder `vorschlag`, wo die Verdichtung überwiegt). Das Feld `geprueft:` setzt nur eine Session, in der `[NAME]` den Inhalt gesehen und bestätigt hat (`AGENTS.md`, Abschnitt 6).
- **Eigene Schlüsse im Satz markieren** ("Einordnung (nicht aus der Quelle): ..."). Beim Ingest landen Quelle und Verdichtung im selben Absatz, und die Grenze sieht danach niemand mehr.
- **`gueltig_bis:` setzen, wo die Notiz einen belegten Horizont hat** (Termin, Frist, Angebot); nur, wenn das Datum aus der Quelle oder vom Besitzer kommt.

**Sensible Daten:** Bei Gesundheitsdaten, Daten privater Dritter oder Zugangsdaten in einer Quelle: aktiver Hinweis im Abschlussbericht (`AGENTS.md`, Abschnitt 14). Zugangsdaten (Passwörter, Schlüssel, Tokens) werden NIE in Notizen übernommen, nur gemeldet.

### 6. Verifikationspass (Pflicht, vor jeder Archivierung oder Löschung)
Jede Rohquelle ein zweites Mal vollständig durchgehen und JEDE enthaltene Information genau einer Kategorie zuordnen. **Dieser Pass läuft an der Rohquelle selbst, nie an einer Konvertierung davon:** Ein Konverter kann still etwas weglassen, und ein zweiter Durchgang über sein Ergebnis übersähe denselben Verlust ein zweites Mal.
- **(a) Übernommen:** steht verifiziert in einer Zielnotiz. Verifiziert heisst: die Stelle in der Notiz wirklich nachschlagen, nicht aus dem Gedächtnis bestätigen.
- **(b) Bewusst verworfen:** irrelevant (Grussformeln, Duplikate, Prozessrauschen), mit Ein-Satz-Begründung im Bericht.
- **(c) Unsicher oder widersprüchlich:** steht in der Fragensammlung und ist, falls in einer Notiz erwähnt, dort als unsicher gekennzeichnet.

Bleibt eine Information unkategorisiert, ist der Pass nicht bestanden: nacharbeiten, Schritt 6 wiederholen.

**6a. Fremde Rechercheberichte stichprobenartig gegen Primärquellen prüfen.** Stammt die Quelle von einem anderen KI-System (Deep Research und Vergleichbares), ist sie ein Modellergebnis mit derselben Fehleranfälligkeit, die dieses Regelwerk sonst überall unterstellt. Geprüft wird mindestens: die Quellenliste selbst (Anbieter- und Prüfberichtsquellen oder nur Aggregatoren und Vergleichsblogs?), drei bis fünf Einzelaussagen mit Entscheidungsgewicht (Preise und Rechtsaussagen zuerst) und die Aktualität an einem Punkt, den der Bericht nicht kennen kann. Was nicht besteht, wird nicht übernommen, sondern als geprüft und verworfen festgehalten, mit Gegenbeleg.

**6b. Kreuzprüfung, wenn eine Lieferung Primärzahlen und deren Auslegung enthält** (Zahlenwerk plus Bericht dazu). Jede Zahl des auslegenden Dokuments einzeln gegen die Primärquelle rechnen, in drei Kategorien: rechnerisch widerlegt, Widerspruch im Dokument selbst, nicht nachvollziehbar. Der Befund kommt als eigener Abschnitt in die Zielnotiz, und auch das, was der Bericht richtig macht, wird festgehalten. Zuerst prüfen, ob das Dokument in sich aufgeht (Unterposten gegen Summe, Kontrollzeile gegen Total, Spalte gegen die Vorlage des Autors), erst danach fremde Quellen danebenlegen: Eine Spalte, die nur von einer anderen Basis abweicht, ist eine Frage der Basis, kein Fehler. Eine Zahl, die an drei Stellen mit drei Werten steht, ist kein Rechenfehler, sondern ein Punkt, den nur der Autor auflösen kann.

**6c. Eine Differenz gegen den Vorstand halten, bevor sie als Anomalie gilt.** Liefert eine Quelle Gesamtkennzahlen und Einzelposten, werden sie aufgerechnet. Geht die Rechnung nicht auf, wird dieselbe Rechnung am Datenstand des letzten Laufs wiederholt, bevor etwas über die Differenz behauptet wird: Gab es sie damals nicht, ist sie seither entstanden; gab es sie in anderer Höhe, wächst sie mit etwas Benennbarem; gab es sie in exakt derselben Höhe, ist sie ein stehender Posten, den bisher niemand bemerkt hat, und genau das ist der Fund. Die Differenz wird nie weggerechnet, sondern als offener Punkt mit konkretem Prüfweg vorgelegt.

### 7. Rohquellen ins Archiv legen
Nur Quellen archivieren, deren Inhalt vollständig aus (a) und (b) besteht. Quellen mit offenen (c)-Punkten oder Zweifelsfällen bleiben in der Inbox, bis `[NAME]` entschieden hat (Schritt 11).

**Verschieben statt löschen.** Die Rohquelle wandert nach `<Repo> Archiv\<Themenordner>\YYYY-MM-DD_Sprechender Name.ext`, Themenordner benannt wie im Repo, Datum das der Quelle. Der Ingest-Auftrag ist die Freigabe dafür (`AGENTS.md`, Abschnitt 12). Gibt es im Archiv noch keine `AGENTS.md`, wird sie beim ersten Gebrauch nach `AGENTS.md`, Abschnitt 5, angelegt. **Der Archivpfad gehört in die Zielnotiz**, in Backticks unter `Beleg:`, zusätzlich zur textlichen Quellenangabe; der Health-Check prüft in der Kategorie `Herkunft` mechanisch, ob er auf eine existierende Datei zeigt.

**Immer `-LiteralPath` verwenden und danach prüfen, ob die Datei wirklich am Ziel liegt.** Dateinamen aus Mailanhängen und Exporten tragen oft eckige Klammern, die PowerShell in `-Path` als Zeichenklasse liest; dann wird nichts verschoben und auch kein Fehler gemeldet, und ohne Gegenprüfung entsteht eine falsche Erledigt-Meldung (`AGENTS.md`, Abschnitt 6).

```powershell
$archiv = Join-Path (Split-Path -Parent (git rev-parse --show-toplevel)) ((Split-Path -Leaf (git rev-parse --show-toplevel)) + ' Archiv')
$ziel = Join-Path $archiv '<Themenordner>'
New-Item -ItemType Directory -Path $ziel -Force | Out-Null
Move-Item -LiteralPath '90_Inbox\<datei>' -Destination (Join-Path $ziel '<YYYY-MM-DD>_<name>.<ext>')
Get-ChildItem -LiteralPath $ziel | Select-Object Name, Length, LastWriteTime
Get-ChildItem '90_Inbox' | Select-Object -ExpandProperty Name
```

Hat das Archiv ein eigenes lokales Git (empfohlen, ohne Remote, weil dort Originale mit Personendaten liegen), wird die Ablage dort committet, die Datei einzeln gestaged (nie `git add -A`, der Hook `guard-git.ps1` blockiert es auch dort).

**Nicht archiviert, sondern gelöscht wird nur, was keinen Belegwert hat:** ein Screenshot als Notizersatz, ein Text, der direkt im Auftrag stand, eine Webseite (dort gehören URL, Abrufdatum und Auszug in die Notiz), und was `[NAME]` für diesen Lauf ausdrücklich gelöscht haben will. Im Zweifel archivieren: Eine überflüssige Datei im Archiv kostet Platz, eine gelöschte Quelle ist endgültig weg. Jede archivierte und jede gelöschte Datei steht im Abschlussbericht mit Ziel bzw. Grund.

### 8. Index und Beschreibungen nachziehen
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "00_INDEX\scripts\build-index-geruest.ps1"
```
Danach in den `_INDEX.md` der betroffenen Themenordner die kuratierten Beschreibungen der neuen oder veränderten Notizen ergänzen (Format `- **Relativpfad** — Beschreibung`, nur was real in der Datei steht, Auto-Blöcke nie anfassen). Ein voller Health-Check ist nach einem Ingest nicht nötig.

### 9. Committen und pushen (ohne Rückfrage)
```powershell
git status                      # zuerst lesen: was ist offen, und was davon ist wirklich meins?
git add "<pfad1>" "<pfad2>"      # NUR die in diesem Lauf bearbeiteten Dateien, nie -A
git commit -m "Ingest: <Themen>"
git fetch origin
git status -sb                  # steht dort "behind", zuerst git pull --rebase
git push
```
Die Indexdateien, die das Skript in Schritt 8 geändert hat, gehören in denselben Commit; sie sind Ergebnis des eigenen Laufs und werden per Pfad mitgestaged. Fremde Änderungen, die nicht aus diesem Lauf stammen, bleiben liegen und werden im Bericht erwähnt. Schlägt der Rebase fehl: nichts erzwingen, melden.

### 10. Abschlussbericht mit Fragensammlung
In dieser Reihenfolge:
1. **Übernommen:** je Quelle die Zielnotiz(en) mit der Kernaussage in einem Satz.
2. **Bewusst verworfen (b):** jede verworfene Information mit Ein-Satz-Begründung.
3. **Unsicherheiten und Widersprüche (c):** vollständige Liste.
4. **Archivierte** (mit Archivpfad), **gelöschte** (mit Grund) und **behaltene Rohquellen** (mit Grund).
5. **Datenschutz-Hinweise**, falls einschlägig.
6. **Offene Fragen:** jede Frage einzeln, mit GENAU drei konkreten Auflösungsvorschlägen, einer davon empfohlen und in zwei bis drei Sätzen begründet; nummeriert, sodass eine Antwort mit Ziffern genügt.

### 11. Nachlauf (nach den Antworten)
Entschiedene Fragen einarbeiten, jetzt geklärte Rohquellen nach Schritt 7 archivieren, Schritte 8 und 9 wiederholen (`Ingest-Aufloesung: <Thema>`). Unbeantwortete Fragen bleiben offen, die Dateien bleiben in der Inbox. **Bringt eine Antwort neues Material** (eine zusätzliche Datei, eine Erklärung mit eigenem Dauerwert), ist der Nachlauf ein eigener Ingest-Durchgang mit eigener Zuordnung, statt es in die Notiz zu quetschen, die die Frage ausgelöst hat: Sonst landet allgemeines Wissen in einer Einzelnotiz und ist nur noch über diesen Umweg auffindbar. Markiert der Besitzer eine eigene Angabe als unsicher ("glaube ich"), wird sie geprüft, bevor sie abgelegt wird.

## Regeln
- Die Grundsätze schlagen alles, auch Kosten- und Zeitüberlegungen. Der Verifikationspass wird nie übersprungen, auch nicht bei scheinbar trivialen Quellen.
- Modell- und Werkzeugneutralität: Die Präzision kommt aus dem Prozess (Zwei-Pass-Verifikation, Fragensammlung, Rateverbot), nicht aus der Modellintelligenz. Fehlende Fähigkeiten werden sofort und konkret gemeldet. Modellempfehlung: `10_System\Modellwahl.md` (für Scans und Handschrift mindestens die Sonnet-Klasse).
- Keine Einzel-Rückfragen zwischendurch, alles läuft über die Fragensammlung; einzige Ausnahme ist ein unverständlicher Auftrag.
- Bei grossen oder heiklen Ingests eine Vorab-Fragerunde: Nach dem Lesen und dem Abgleich, aber vor dem Schreiben, werden die schon erkennbaren Unklarheiten (Personenzuordnungen, Herkunft einzelner Abschnitte, Behalten oder Archivieren) nummeriert gestellt. Das ersetzt die Fragensammlung am Ende nicht, verhindert aber, dass falsche Annahmen überhaupt in Notizen landen.
- Basiskontext-Schutz strikt: `01_Basiskontext` nie im Ingest ändern, nur Befund melden.
- Trigger-Abgrenzung: "inbox aufraeumen" und "ablage aufraeumen" gehören zum Health-Check (Ablage-Hygiene); dieser Skill ist die inhaltliche Verarbeitung.

## Definition of Done
- [ ] Jede Quelle im Umfang vollständig gelesen oder präzise als nicht lesbar gemeldet (Datei, Grund, benötigte Fähigkeit)
- [ ] Verifikationspass bestanden, an der Rohquelle geprüft, nicht an einer Konvertierung
- [ ] Übernommene Aussagen in den Zielnotizen real nachgeschlagen
- [ ] Nur vollständig verarbeitete Quellen archiviert, Ablage per Werkzeug gegengeprüft, Archivpfad in der Zielnotiz (gelöscht nur, was keinen Belegwert hat)
- [ ] `stand:` aller bearbeiteten Notizen auf das echte Tagesdatum gesetzt
- [ ] Jede neue Datei trägt `titel`, `zweck`, `type` und `herkunft:` (oder `geprueft:` nach Bestätigung)
- [ ] Eigene Schlüsse im Satz markiert, `gueltig_bis:` gesetzt, wo ein belegter Horizont besteht
- [ ] Neue oder wesentlich erweiterte Notizen beidseitig verlinkt, wo eine belegbare Beziehung besteht
- [ ] Index-Mechanik gelaufen, Beschreibungen kuratiert
- [ ] Committet und gepusht, oder der Konflikt ist gemeldet
- [ ] Abschlussbericht vollständig, jede offene Frage mit genau drei Vorschlägen, einer begründet empfohlen
