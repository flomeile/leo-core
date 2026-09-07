---
titel: Zielsetzung
zweck: Das anwender- und value-orientierte Zielbild des KI-Systems
type: systemdoku
version: 1.1
letzte_aenderung: 2026-08-03
---

# Zielsetzung: Warum dieses System existiert

Diese Datei hält fest, WOFUER das System gebaut wurde, aus Sicht des Anwenders. Sie ist der Massstab: Jede technische Entscheidung muss diesen Zielen dienen. Wenn eine Lösung diesen Zielen widerspricht, ist die Lösung falsch, nicht das Ziel.

## Das Kernziel: ein Second Brain
Ein persönliches, dauerhaftes Wissenssystem, in das du alles ablegen kannst, was du erarbeitest und für wichtig hältst, mit dem Vertrauen, dass ein LLM zuverlässig darauf zugreift, wenn eine passende Frage gestellt wird. Das System ist Gedächtnis und Arbeitsplatz zugleich.

## Was das System tun muss

### 1. Wissen ablegen und wiederfinden
Du legst Markdown-Dateien ab (eigene Notizen, Session-Zusammenfassungen, importierte Recherchen, gegebene Dokumente). Das LLM muss dieses Wissen zuverlässig finden und aktiv nutzen, wenn es relevant ist. Kein Wissen darf "unsichtbar" bleiben, nur weil es der Index nicht wörtlich beschreibt.

### 2. An Dateien arbeiten
Das System ist nicht nur Lesespeicher. Das LLM muss Dateien direkt bearbeiten können (schreiben, ergänzen, redigieren): Strukturen aufbauen, Texte redigieren, Aufgabenlisten fortschreiben, Konzepte entwickeln.

### 3. Verschiedene Rollen bedienen
Aus demselben Wissensfundus soll das LLM unterschiedliche Rollen einnehmen (je nach den Themenordnern, die du anlegst). Jede Rolle fokussiert bestimmte Themen, hat aber Zugriff auf das Gesamtbild.

### 4. Mitwachsen, möglichst automatisch
Die Wissensbasis wächst laufend. Das Einpflegen und Aktuellhalten (besonders des Index) soll weitgehend automatisch passieren und kaum Wartungsaufwand erzeugen. Anspruch: "ein Wort plus ein Klick" (z.B. "wrap up"), plus unsichtbare Automatik im Hintergrund (Task Scheduler). Keine Vollautomatik dort, wo Kontrolle nötig ist (Basiskontext).

## Was das System können muss (nicht verhandelbar)

### Unabhängigkeit (kein Lock-in)
Das System muss mit jedem Harness und jedem LLM funktionieren, solange es Markdown lesen und schreiben kann. Die Wahrheit gehört keinem Tool. Du kannst das Modell jederzeit wechseln ohne Kontextverlust.

### Zuverlässigkeit und Wahrheit
Absolute Priorität: keine Halluzinationen in der Wissensbasis. Ein Wissenssystem, das Quellen erfindet und Folgedokumente auf falschen Quellen aufbaut, kompromittiert sich selbst. Das darf strukturell nicht passieren. Nur belegbare Quellen kommen rein (siehe Root-`AGENTS.md`, Abschnitt Anti-Halluzination).

### Radikale Einfachheit
Das System muss so einfach zu bedienen sein, dass man keine Anwendungsfehler machen kann, solange man dem Manual folgt. Kein selbstgebauter Apparat, der von der eigentlichen Arbeit ablenkt.

### Sicherheit
Manche Harnesses schreiben ohne Rückfrage in Dateien. Das System braucht daher eine verlässliche Versionierung (Git + GitHub) als Sicherheitsnetz, sodass jede Fehländerung rückrollbar ist.

### Kostenkontrolle
Der Wissenszugriff darf keine Token-Verbrennungsfalle werden. Das LLM liest gezielt, nicht blind ganze Ordner. Usability und Kostenkontrolle sind gleich wichtig.

### Lebendigkeit und Wartbarkeit
Das System wird sich weiterentwickeln. Es muss sich selbst erklären und in einem eigenen Meta-Bereich (`10_System`) dokumentiert sein, in dem man Fragen zu Troubleshooting, neuen Funktionen und Bedienung stellen kann, ohne dass geraten wird.

## Der Massstab
Das System arbeitet auf Weltklasse-Niveau. Konsistenz, Klarheit und Zuverlässigkeit müssen auch einer Prüfung durch externe LLMs standhalten.
