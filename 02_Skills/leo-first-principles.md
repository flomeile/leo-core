---
name: leo-first-principles
trigger: '"first principles", "first-principles", "dekonstruiere das", "von grund auf neu denken", "fundamental hinterfragen"'
zweck: Ein bestehendes Modell, einen Prozess oder eine Branchenlösung radikal auf fundamentale Wahrheiten dekonstruieren und von Null neu aufbauen, Wahrheit strikt von Konvention getrennt, mit konkretem erstem Zug am Ende
type: skill
version: 1.0
---

# Skill: Leo First Principles

Dekonstruiert eine bestehende Lösung (Modell, Prozess, Branchenstandard, Preislogik) auf ihre fundamentalen, objektiv wahren Komponenten und baut von dort eine Lösung von Null auf, ohne Konventionen oder "best practices" ungeprüft zu übernehmen. Funktioniert themenneutral (Business, Privates, Admin, Gesundheit).

Voraussetzungen: keine besonderen Werkzeuge. Websuche ist hilfreich für den Annahmen-Check (Marktpreise, Benchmarks), wenn verfügbar; ohne Websuche werden externe Zahlen als ungeprüfte Annahmen gekennzeichnet, nie als Fakt gesetzt.

## Wann ausführen

- Wenn `[NAME]` ein Trigger-Wort nennt und ein Objekt benennt (Prozess, Geschäftsmodell, Preismodell, Branchenlösung, Gewohnheit).
- Von selbst als einzeiliger Vorschlag bei strategischen Weichenstellungen, bei "das haben wir immer so gemacht"-Verdacht, bei Make-or-Buy-Fragen, bei Kosten- oder Zeitblöcken, die niemand erklären kann.
- NICHT für bereits entschiedene Fragen: dort zählt Umsetzung, keine erneute Grundsatzanalyse.
- NICHT als Ersatz für eine fällige reale Handlung. Beschreibt der Basiskontext des Besitzers ein Vermeidungs- oder Aufschiebemuster und würde die Analyse erkennbar einen anstehenden ersten Schritt ersetzen, das vor Beginn offen benennen und fragen, welche Handlung die Analyse ersetzt. Führt der Besitzer den Auftrag danach fort, ausführen.
- NICHT für Faktenprüfung eines Textes (`leo-faktencheck`) oder Stil (`leo-voice-check`).

## Schritte

### 0. Kontext ziehen statt Platzhalter füllen
Den Basiskontext lesen (falls in der Session noch nicht geschehen) und die betroffenen Themenordner per Suchstrategie (`AGENTS.md`, Abschnitt 4) heranziehen: Die Analyse arbeitet mit dem echten Kontext des Besitzers, nicht mit generischen Platzhaltern. Fehlt nur eine Angabe (z.B. was den Besitzer am Bestehenden stört), genau eine Rückfrage stellen, dann arbeiten.

### 1. Dekonstruktion
Was sind die fundamentalen, objektiv wahren Komponenten des Problems? Branchenstandards und "best practices" bewusst ignorieren. Was ist physisch, faktisch oder logisch notwendig? Welche Grundwahrheiten (physikalisch, psychologisch, ökonomisch, rechtlich) gelten unveränderlich? Jede Grundwahrheit muss den Test bestehen: "Gilt das auch, wenn niemand in der Branche es so macht?"

### 2. Annahmen-Check
Welche Annahmen der aktuellen Lösung sind arbiträr? Warum kostet es X, warum dauert es Y, warum läuft es in diesen Schritten? Ziel: mindestens drei arbiträre Annahmen identifizieren; gibt es begründet weniger, das explizit sagen statt Annahmen zu erfinden. Externe Zahlen (Marktpreise, Benchmarks) belegen (Websuche oder Repo-Quelle) oder als ungeprüfte Annahme kennzeichnen.

### 3. Neuaufbau
Nur mit den Grundwahrheiten aus Schritt 1 bei Null anfangen: Wie sähe die Lösung aus? Welche Komponenten sind wirklich erforderlich? Was unterscheidet sie vom Status quo, und warum? Wichtig: Radikal anders ist das Ziel des Denkwegs, kein Pflichtergebnis. Hält der Status quo der Prüfung stand, ist genau das der Befund; ein erzwungener Umsturz wäre eine Gefälligkeitsantwort.

### 4. Implementierung
Welche Barrieren stehen zwischen der First-Principles-Lösung und der Realität, und welche davon sind echt (Physik, Recht, Vertrag, Cash) versus Konvention ("das haben wir immer so gemacht")? Wie lässt sich die Lösung klein und billig prototypisch testen? Was wäre, in einem Satz, die disruptive Innovation?

### 5. Erster Zug
Die Analyse endet immer mit einem konkreten, kleinen, real ausführbaren ersten Schritt (wen ansprechen, was testen, was messen) samt Zeithorizont. Eine First-Principles-Analyse ohne ersten Zug ist Kopfarbeit ohne Wirkung.

## Ausgabeform

```markdown
## First Principles: <Objekt>

### Grundwahrheiten (gelten unveränderlich)
- ...

### Arbiträre Annahmen der heutigen Lösung
1. ... (warum arbiträr)
2. ...
3. ...

### Neuaufbau von Null
<Lösung, hergeleitet nur aus den Grundwahrheiten; Unterschiede zum Status quo begründet>

### Barrieren
- Echt: ...
- Konvention: ...

### Prototyp-Test
<kleinster billiger Test>

### Disruptive Innovation
<ein Satz>

### Erster Zug
<konkreter Schritt, Zeithorizont>
```

## Beispiel

Eingabe (realistisch unordentlich): "first principles: unser angebotsprozess. jeder kopiert aus alten angeboten, der produktkopf muss am schluss trotzdem alles nochmal anfassen, dauert teils 2 wochen. warum eigentlich"

Auszug der erwarteten Ausgabe: Grundwahrheiten (ein Angebot braucht rechtlich verbindliche Leistungsbeschreibung, Preis, Gültigkeit; der Kunde entscheidet nach Nutzen und Vertrauen, nicht nach Dokumentlänge). Arbiträre Annahmen (Angebote müssen vom Produktkopf persönlich geprüft werden; jedes Angebot ist ein Unikat; 20 Seiten wirken professioneller als 4). Neuaufbau (modulare Bausteine mit vorab freigegebenen Preisrahmen, Prüfung nur bei Abweichung vom Rahmen). Barrieren (echt: Preisfreigabe-Kompetenz ist Governance; Konvention: "das hat immer der Produktkopf geprüft"). Erster Zug (die letzten fünf Angebote nebeneinanderlegen und messen, wie viel Prozent Text identisch war; diese Woche, 30 Minuten).

## Regeln

- Grundwahrheiten strikt von Konventionen und Meinungen trennen; im Zweifel gehört eine Aussage zu den Annahmen, nicht zu den Wahrheiten.
- Anti-Halluzination: keine erfundenen Marktzahlen, Kosten oder Kundenaussagen. Belegen oder als Annahme kennzeichnen (`AGENTS.md`, Abschnitt 6).
- Ehrlicher Widerspruch statt Pflicht-Disruption: Wenn die bestehende Lösung den Grundwahrheiten bereits entspricht, das klar sagen.
- Ergebnisse mit strategischem Wert als Wissensdatei im passenden Themenordner anbieten, nicht nur im Chat lassen.
- Nach jeder Ausführung: sichtbar gewordene Schwächen des Skills direkt verbessern (Version hochzählen) und kurz informieren.

## Definition of Done

- [ ] Grundwahrheiten klar von Konventionen getrennt aufgelistet
- [ ] Mindestens drei arbiträre Annahmen identifiziert (oder begründet, warum es weniger sind)
- [ ] Neuaufbau nur aus den Grundwahrheiten hergeleitet; Abweichung vom Status quo begründet oder Status quo ausdrücklich bestätigt
- [ ] Barrieren in echt versus Konvention eingeordnet und ein kleiner Prototyp-Test benannt
- [ ] Disruptive Innovation in einem Satz formuliert
- [ ] Konkreter erster Zug mit Zeithorizont steht am Ende
- [ ] Externe Zahlen belegt oder als ungeprüfte Annahme gekennzeichnet
