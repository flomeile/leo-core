---
name: leo-faktencheck
trigger: '"faktencheck", "fakten prüfen", "fakten checken", "stimmt das", "verifizieren", "quellen prüfen", "belege prüfen"'
zweck: Jede überprüfbare Tatsachenbehauptung in einem Text vor Versand oder Veröffentlichung einzeln gegen Primärquellen prüfen und ein Urteil je Behauptung plus korrigierte Fassung liefern
type: skill
version: 1.0
---

# Skill: Leo Faktencheck

Prüft einen fertigen Text Behauptung für Behauptung gegen echte Quellen (Websuche), bevor er rausgeht, und liefert ein Urteil je Behauptung samt Quelle plus einen korrigierten Entwurf. Ergänzt den Voice-Check: `leo-voice-check` prüft, ob der Text nach dem Besitzer klingt; dieser Skill prüft, ob die Fakten darin stimmen. Zwei getrennte Tore für ausgehende Texte.

Voraussetzungen: Websuch-Werkzeug (ohne echte Suche wird NICHT simuliert, siehe Schritt 3 und Regeln). Eine falsche Zahl in einem versendeten Text entwertet den ganzen Text.

## Wann ausführen

- Wenn `[NAME]` ein Trigger-Wort nennt.
- Von selbst als Vorschlag (oder direkt, wenn ohnehin ein ausgehender Text entsteht), sobald ein Text Zahlen, Daten, Preise, Zitate, Namen, Titel, Rankings oder Superlative trägt (Mail, Angebot, Präsentation, Post, Brief, Sachpassage). Nicht aufdrängen, einmal anbieten.
- NICHT für reine Meinungstexte, Fiktion, interne Brainstorms oder Texte, die nicht rausgehen. Für den Stil ist `leo-voice-check` zuständig, nicht dieser Skill.

## Grundsatz

Text aus dem Gedächtnis (dem des Besitzers oder deinem) erbt veraltete Fakten. "Ich erinnere mich, dass das stimmt" ist eine Hypothese, nie eine Prüfung. Jede geprüfte Aussage bekommt eine anklickbare Quelle oder das ehrliche Urteil "nicht verifizierbar". Nie ein Urteil ohne Quelle behaupten.

## Schritte

### 1. Behauptungen extrahieren
Den Text lesen und jede überprüfbare Tatsachenbehauptung herausziehen, nummeriert, im Originalwortlaut (Präzision zählt: "der grösste Anbieter" und "einer der grössten Anbieter" sind zwei verschiedene Behauptungen mit verschiedenem Wahrheitswert).

Keine Behauptungen (überspringen): Meinungen, Prognosen, eigene Erlebnisse des Besitzers, weiche Verallgemeinerungen, echtes Allgemeinwissen (Wasser kocht bei 100 °C auf Meereshöhe). Im Zweifel als Behauptung behandeln.

### 2. Nach Risiko sortieren
In dieser Reihenfolge prüfen, weil diese Kategorien am häufigsten falsch sind und am teuersten, wenn sie falsch sind:
1. **Zahlen:** Statistiken, Preise, Prozente, Daten, Mengen.
2. **Zitate:** zugeschriebene Aussagen (Wortlaut UND Zuschreibung prüfen; falsch zugeschriebene echte Zitate sind der häufigste Zitatfehler).
3. **Personen und Titel:** Namen, Schreibweisen, aktuelle Rollen (Funktionen veralten schnell).
4. **Superlative und Absolutaussagen:** erster, einziger, grösster, nie, immer. Ein einziges Gegenbeispiel kippt sie, also fallen sie am häufigsten.
5. **Medizinische, rechtliche, finanzielle Aussagen:** höchster Einsatz, nur Primärquellen-Standard.
6. **Namen von Produkten, Studien, Gesetzen, Organisationen:** leicht zu verwechseln, leicht zu prüfen.

Bei mehr als rund 25 Behauptungen: den Besitzer informieren, die Hochrisiko-Stufen vollständig prüfen, den Rest als ungeprüft ausweisen statt still zu überspringen.

### 3. Gegen Quellen prüfen
Für jede Behauptung suchen. Quellenregeln:
- **Primär schlägt sekundär.** Die Meldung des Unternehmens, die Studie selbst, der amtliche Datensatz, das Transkript. Ein Aggregator, der eine Quelle zitiert, ist ein Zeiger, keine Prüfung: dem Zeiger folgen.
- **Datum prüfen.** Eine Quelle von 2021 belegt nur, was 2021 galt. Für Veränderliches (Preise, Marktanteile, Funktionen) eine aktuelle Quelle verlangen und das Stand-Datum notieren.
- **Zwei unabhängige Quellen für überraschende Behauptungen.** Und sicherstellen, dass beide nicht denselben Ursprung zitieren.
- **Überall wiederholt heisst nicht wahr.** Virale Zahlen haben tausend Zitate und null Primärquelle. Findest du keinen Ursprung, ist das ein Befund: als nicht verifizierbar markieren.

Fehlt das Websuch-Werkzeug: NICHT aus dem Gedächtnis simulieren. Behauptungen extrahieren und sortieren, je Behauptung eine Einschätzung mit Vertrauensstufe NIEDRIG/MITTEL/HOCH geben, klar kennzeichnen, dass nichts gegen Live-Quellen geprüft wurde, und empfehlen, den Lauf mit Suche zu wiederholen.

### 4. Urteile fällen
Genau diese fünf Urteile, weil sie zu verschiedenen Korrekturen führen:
- **BESTÄTIGT:** deckt sich mit einer verlässlichen Quelle. Quelle nennen.
- **VERALTET:** war wahr, ist nicht mehr aktuell. Aktuellen Wert plus Stand-Datum liefern.
- **UNGENAU:** grob richtig, so geschrieben falsch (falsches Jahr, zu stark gerundet, überzogener Superlativ). Korrigierten Wortlaut liefern.
- **NICHT VERIFIZIERBAR:** keine ausreichende Quelle in beide Richtungen. Nicht als falsch behandeln, aber empfehlen, sie zu streichen oder abzuschwächen (der Besitzer kann sie sonst bei Nachfrage nicht verteidigen).
- **FALSCH:** von verlässlichen Quellen widerlegt. Zeigen, was die Quelle wirklich sagt.

### 5. Bericht, dann Reparatur
Bericht in diesem Format:
```
## Faktencheck-Bericht
N Behauptungen geprüft: X bestätigt, Y zu ändern, Z nicht verifizierbar.

1. "exakter Behauptungstext" — BESTÄTIGT
   Quelle: [Name + Link], Stand [Datum]
2. "exakter Behauptungstext" — FALSCH
   Quelle sagt: [was wirklich dasteht]
   Korrekturvorschlag: [Ersatzwortlaut]
...
```
Danach anbieten, die Korrekturen einzuarbeiten und einen korrigierten Entwurf zu liefern. Beim Einarbeiten NUR ändern, was die Urteile verlangen; Stil und Stimme nicht anfassen (das ist `leo-voice-check`, und das Mischen macht den Diff unprüfbar).

## Regeln
- **Nie abnicken.** Kommen in einem zahlenlastigen Text alle Behauptungen im ersten Durchgang als BESTÄTIGT zurück, die zwei bis drei überraschendsten erneut prüfen. Ein Faktencheck, der nichts findet, muss dieses Ergebnis verdienen.
- **"Konnte ich nicht verifizieren" ist eine respektable Antwort.** Der zu vermeidende Fehler ist ein Urteil ohne Quelle. Jedes BESTÄTIGT und jedes FALSCH trägt eine anklickbare Quelle.
- **Prüfe, was dasteht, nicht was gemeint war.** Steht "Studien zeigen" (Plural) und du findest eine Studie, ist das UNGENAU. Überziehen ist ein Sachfehler, keine Stilfrage.
- **Anti-Halluzination:** keine erfundenen Quellen, Zahlen oder Links. Live-Daten-Regel der `AGENTS.md` (Abschnitt 15) beachten, Quellen zitieren.
- **Datenschutz:** keine sensiblen Firmen- oder Privatdaten unnötig in Suchanfragen geben (`AGENTS.md`, Abschnitt 14). Interne Zahlen prüft man nicht per Websuche.
- Nach jeder Ausführung: sichtbar gewordene Schwächen des Skills direkt verbessern (Version hochzählen) und kurz informieren.

## Definition of Done
- [ ] Jede überprüfbare Tatsachenbehauptung extrahiert, nummeriert und im Originalwortlaut festgehalten
- [ ] Hochrisiko-Kategorien (Zahlen, Zitate, Personen/Titel, Superlative) vollständig geprüft; bei über 25 Behauptungen ist Ungeprüftes ausgewiesen
- [ ] Jedes Urteil trägt eine anklickbare Quelle oder lautet ehrlich NICHT VERIFIZIERBAR; kein Urteil aus dem Gedächtnis
- [ ] Ohne Websuch-Werkzeug: nichts simuliert, Einschätzungen als ungeprüft gekennzeichnet und Wiederholung mit Suche empfohlen
- [ ] Bericht im vorgegebenen Format geliefert, Korrektur-Einarbeitung angeboten
- [ ] Beim Einarbeiten nur geändert, was die Urteile verlangen
