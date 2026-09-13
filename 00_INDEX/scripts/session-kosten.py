# session-kosten.py: Verbrauch aller Claude-Code-Sessions aus den lokalen Transkripten messen.
# Hintergrund: AGENTS.md Abschnitt 1 (Buendelungsregel) und Abschnitt 13 (Kostenlogik: Aufwand ist
# Aufrufe mal Verlaufslaenge). Seit 3.3 Teil des Grundgeruests.
#
# Quelle: <Benutzerordner>\.claude\projects\<projekt>\<session>.jsonl (ein Eintrag je Modellaufruf mit
# Feld usage; Subagenten liegen als jsonl in einem Unterordner mit der Session-Id). Aufrufe werden
# ueber die Nachrichten-Id entdoppelt, weil ein Aufruf mit Text und Werkzeug zweimal geloggt wird.
# Bewertet wird zu API-LISTENPREISEN je Modell (Tabelle unten, USD je Mio. Token). Wer im Abo arbeitet,
# liest die Zahl als Gegenwert, nicht als Rechnung; wie Cache-Lesungen auf eine Abo-Limite zaehlen,
# ist nicht dokumentiert.
#
# Gemessen werden ALLE Sessions des Werkzeugs auf diesem Rechner, auch die aus anderen Ordnern
# (sie tragen ihren Projektordner in Klammern). Der Bericht enthaelt je Session die ersten 80 Zeichen
# der ersten Eingabe als Titel; wer das nicht im Repo haben will, nimmt 00_INDEX/session-kosten.md
# in die .gitignore auf.
#
# Aufruf:
#   python 00_INDEX/scripts/session-kosten.py                 schreibt 00_INDEX\session-kosten.md (letzte 14 Tage)
#   python 00_INDEX/scripts/session-kosten.py --tage 30       anderer Zeitraum
#   python 00_INDEX/scripts/session-kosten.py --health        gibt nur Befundzeilen "OK|..." / "WARN|..." aus
#                                                             (liest health-check.ps1, Kategorie Lean)
# Schwellen (AGENTS.md Abschnitt 13): WARN bei einer Session mit mehr als 200 Aufrufen und bei einem
# Tag ueber SCHWELLE_TAG_USD. Bewusst KEINE Quote "Werkzeuge je Aufruf": Sie sieht nur parallele
# Werkzeugaufrufe in einem Zug, nicht die Buendelung in ein Skript (ein Skript mit zehn Schritten ist
# ein Werkzeug in einem Aufruf) und ist damit als Mass fuer die Regel blind. Was zaehlt, sind die
# Modellaufrufe je Session und der Kontext je Aufruf (Cache-Lesen geteilt durch Aufrufe): Jeder Aufruf
# kostet Kontext mal Cache-Preis.
import json, os, sys, re, datetime
from pathlib import Path
from collections import defaultdict
sys.stdout.reconfigure(encoding="utf-8")

PREISE = {  # USD je Mio. Token: Eingabe, Cache-Lesen, Cache-Schreiben, Ausgabe. Stand 11.09.2026; bei Preisaenderung hier nachfuehren.
    "claude-opus-5": (5.0, 0.50, 6.25, 25.0),
    "claude-fable-5-1": (10.0, 0.25, 12.50, 50.0),
    "claude-fable-5": (10.0, 1.00, 12.50, 50.0),
    "claude-sonnet-5": (2.0, 0.20, 2.50, 10.0),
    "claude-haiku-4-5-20251001": (1.0, 0.10, 1.25, 5.0),
}
STANDARD = PREISE["claude-opus-5"]  # unbekanntes Modell: zum Opus-Preis bewertet
SCHWELLE_AUFRUFE, SCHWELLE_TAG_USD, KONTEXT_AB = 200, 300.0, 30
KALTSTART_TOKEN = 50000

repo = Path(__file__).resolve().parents[2]
# Claude Code benennt den Projektordner nach dem Repo-Pfad: Laufwerksdoppelpunkt und Trenner werden zu "-".
repo_key = re.sub(r"[:\\/]", "-", str(repo))
basis = Path.home() / ".claude" / "projects"
tage = 14
health = "--health" in sys.argv
if "--tage" in sys.argv:
    tage = int(sys.argv[sys.argv.index("--tage") + 1])
seit = datetime.date.today() - datetime.timedelta(days=tage)

def lies(pfad):
    """Eine Transkriptdatei: Kennzahlen je Session, Modellaufrufe ueber die Nachrichten-Id entdoppelt."""
    aufrufe, erste_frage, titel, effort, start, entry = {}, "", "", set(), None, ""
    for zeile in open(pfad, encoding="utf-8", errors="replace"):
        try:
            o = json.loads(zeile)
        except ValueError:
            continue
        if o.get("customTitle"):
            titel = o["customTitle"]
        if o.get("type") == "user" and not erste_frage:
            c = o.get("message", {}).get("content", "")
            t = c if isinstance(c, str) else " ".join(x.get("text", "") for x in c if isinstance(x, dict))
            t = t.strip()
            if t and not t.startswith("<"):
                erste_frage = re.sub(r"\s+", " ", t)[:80]
                start = o.get("timestamp", "")
                entry = o.get("entrypoint", "")
        if o.get("type") != "assistant":
            continue
        m = o.get("message", {})
        u = m.get("usage")
        if not u:
            continue
        if o.get("effort"):
            effort.add(o["effort"])
        werkzeuge = sum(1 for c in m.get("content", []) if isinstance(c, dict) and c.get("type") == "tool_use")
        alt = aufrufe.get(m.get("id"))
        aufrufe[m.get("id")] = (m.get("model"), u, o.get("timestamp", ""), (alt[3] if alt else 0) + werkzeuge)
    return aufrufe, erste_frage, titel, effort, start, entry

sessions = []
if basis.is_dir():
    for projekt in basis.glob("*"):
        if not projekt.is_dir():
            continue
        for f in projekt.glob("*.jsonl"):
            aufrufe, frage, titel, effort, start, entry = lies(f)
            if not aufrufe:
                continue
            sub = list((projekt / f.stem).glob("**/*.jsonl"))
            for s in sub:
                a2, *_ = lies(s)
                for k, v in a2.items():
                    aufrufe["sub:" + str(k)] = v
            tokens = dict(eingabe=0, cache_lesen=0, cache_schreiben=0, ausgabe=0)
            usd = 0.0; werkzeuge = 0; kalt = 0; modelle = set(); datum = None; n = 0
            for i, (modell, u, ts, wz) in enumerate(sorted(aufrufe.values(), key=lambda x: x[2])):
                d = ts[:10]
                if not d:
                    continue
                try:
                    dd = datetime.date.fromisoformat(d)
                except ValueError:
                    continue
                if dd < seit:
                    continue
                datum = datum or dd
                n += 1; werkzeuge += wz; modelle.add(modell or "?")
                p = PREISE.get(modell, STANDARD)
                e, cr, cw, a = (u.get("input_tokens", 0), u.get("cache_read_input_tokens", 0),
                                u.get("cache_creation_input_tokens", 0), u.get("output_tokens", 0))
                tokens["eingabe"] += e; tokens["cache_lesen"] += cr; tokens["cache_schreiben"] += cw; tokens["ausgabe"] += a
                usd += (e * p[0] + cr * p[1] + cw * p[2] + a * p[3]) / 1e6
                if i > 0 and cw >= KALTSTART_TOKEN:
                    kalt += 1
            if n == 0:
                continue
            sessions.append(dict(id=f.stem[:8], projekt=projekt.name, datum=datum, titel=titel or frage or "(ohne Titel)",
                                 aufrufe=n, werkzeuge=werkzeuge, kalt=kalt,
                                 modelle=sorted(modelle), effort=sorted(effort), usd=usd, tokens=tokens,
                                 subagenten=len(sub), entry=entry))

sessions.sort(key=lambda s: (s["datum"], -s["usd"]), reverse=True)
je_tag = defaultdict(float)
for s in sessions:
    je_tag[s["datum"]] += s["usd"]

befunde = []
if not basis.is_dir():
    befunde.append(("INFO", f"Kein Transkriptordner unter {basis}; Session-Kosten nicht messbar (kein Claude Code auf diesem Rechner, oder anderer Speicherort)."))
for s in sessions:
    if s["aufrufe"] > SCHWELLE_AUFRUFE:
        befunde.append(("WARN", f"Session {s['id']} vom {s['datum']} ({s['titel'][:50]}): {s['aufrufe']} Modellaufrufe, {s['usd']:.0f} USD Listenpreis. AGENTS.md Abschnitt 13: ueber {SCHWELLE_AUFRUFE} Aufrufe ist ein Befund; Ablauf auf Buendelung pruefen."))
for d, v in sorted(je_tag.items(), reverse=True):
    if v > SCHWELLE_TAG_USD:
        befunde.append(("WARN", f"Tag {d}: {v:.0f} USD Listenpreis ueber alle Sessions (Schwelle {SCHWELLE_TAG_USD:.0f})."))
gesamt = sum(je_tag.values())
# Kontext je Aufruf (Tausend Token, Cache-Lesen geteilt durch Aufrufe) ueber alle Sessions ab KONTEXT_AB Aufrufen:
# das ist der Preistreiber je Aufruf; die Zahl der Aufrufe je Session steht daneben.
gross = [s for s in sessions if s["aufrufe"] >= KONTEXT_AB]
kontext_k = (sum(s["tokens"]["cache_lesen"] for s in gross) / sum(s["aufrufe"] for s in gross) / 1000) if gross else 0.0
kalt_gesamt = sum(s["kalt"] for s in sessions)
if basis.is_dir():
    befunde.append(("OK" if not any(b[0] == "WARN" for b in befunde) else "INFO",
        f"Session-Kosten der letzten {tage} Tage: {gesamt:.0f} USD Listenpreis in {len(sessions)} Sessions ({sum(s['aufrufe'] for s in sessions)} Aufrufe, {kalt_gesamt} Kaltstarts), im Schnitt {kontext_k:.0f}k Token Kontext je Aufruf in Sessions ab {KONTEXT_AB} Aufrufen. Bericht: 00_INDEX\\session-kosten.md"))

if health:
    for stufe, text in befunde:
        print(f"{stufe}|{text}")
    sys.exit(0)

heute = datetime.date.today().isoformat()
z = []
z.append("---")
z.append("titel: Session-Kosten (erzeugt)")
z.append(f"zweck: Verbrauch aller Claude-Code-Sessions der letzten {tage} Tage zu API-Listenpreisen, erzeugt von 00_INDEX/scripts/session-kosten.py; nie von Hand aendern")
z.append("type: systemdoku")
z.append(f"stand: {heute}")
z.append("---")
z.append("")
z.append(f"# Session-Kosten, letzte {tage} Tage (Stand {heute})")
z.append("")
z.append("Erzeugt von `00_INDEX\\scripts\\session-kosten.py` aus den lokalen Transkripten. Zahlen sind API-Listenpreise je Modell (Tabelle im Skript), nicht die Abo-Rechnung. Kontext/Aufruf = aus dem Cache gelesene Token je Modellaufruf in Tausend; jeder Aufruf kostet diesen Kontext zum Cache-Preis, deshalb zaehlen wenige Aufrufe und ein kleiner Verlauf (`AGENTS.md` Abschnitte 1 und 13). Sessions ausserhalb dieses Repos tragen ihren Projektordner in Klammern. Kalt = Aufrufe, bei denen der Verlauf nach Cache-Verfall neu geschrieben wurde (Pause ueber die Cache-Lebensdauer). Befunde und Schwellen: Abschnitt 13 der `AGENTS.md`.")
z.append("")
z.append("## Befunde")
z.append("")
for stufe, text in befunde:
    z.append(f"- **{stufe}** {text}")
z.append("")
z.append("## Je Tag")
z.append("")
z.append("| Tag | Sessions | Aufrufe | USD |")
z.append("|---|---|---|---|")
for d in sorted(je_tag, reverse=True):
    ss = [s for s in sessions if s["datum"] == d]
    z.append(f"| {d} | {len(ss)} | {sum(s['aufrufe'] for s in ss)} | {je_tag[d]:.0f} |")
z.append(f"| **Summe** | {len(sessions)} | {sum(s['aufrufe'] for s in sessions)} | **{gesamt:.0f}** |")
z.append("")
z.append("## Je Session")
z.append("")
z.append("| Datum | Session | Aufrufe | Werkzeuge | Kontext/Aufruf (k) | Kalt | Modell / Effort | Cache gelesen (Mio.) | Ausgabe (Tsd.) | USD |")
z.append("|---|---|---|---|---|---|---|---|---|---|")
for s in sessions:
    modell = ", ".join(m.replace("claude-", "") for m in s["modelle"])
    eff = "/".join(s["effort"]) if s["effort"] else "?"
    extra = f" (+{s['subagenten']} Subagenten)" if s["subagenten"] else ""
    if s["projekt"] != repo_key: extra += f" ({s['projekt']})"
    kontext = (s["tokens"]["cache_lesen"] / s["aufrufe"] / 1000) if s["aufrufe"] else 0
    z.append(f"| {s['datum']} | {s['titel'].replace('|', '/')}{extra} | {s['aufrufe']} | {s['werkzeuge']} | {kontext:.0f} | {s['kalt']} | {modell} {eff} | {s['tokens']['cache_lesen']/1e6:.1f} | {s['tokens']['ausgabe']/1e3:.0f} | {s['usd']:.1f} |")
z.append("")
ziel = repo / "00_INDEX" / "session-kosten.md"
ziel.write_text("\n".join(z) + "\n", encoding="utf-8")
print(f"{ziel}: {len(sessions)} Sessions, {gesamt:.0f} USD Listenpreis in {tage} Tagen; Befunde: {sum(1 for b in befunde if b[0]=='WARN')} WARN")
