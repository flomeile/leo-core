r"""Sendet eine Mail über das Google-Konto des Besitzers (Gmail API), mit der gemeinsamen
OAuth-Anmeldung aus google_zugang.py (Token im Benutzerprofil, Einrichtung in
10_System\Google-Anbindung.md). Das ist der einzige Sendeweg des Systems; der Hook
guard-mail.ps1 sperrt jeden anderen. Regel: AGENTS.md, Abschnitt 16.

REGELN, DIE DIESES SKRIPT ERZWINGT (kein Schalter dagegen):
  1. Jede Mail legt oben offen, dass der KI-Assistent sie geschrieben hat, dass sie Fehler
     enthalten kann und kritisch zu prüfen ist (OFFENLEGUNG); unten steht seine Signatur (FUSS).
     Beides in der Sprache des Mailtexts (Deutsch oder Englisch, automatisch erkannt).
  2. Der Besitzer (BESITZER_ADRESSE) steht IMMER im CC. Ein --cc ergänzt ihn, ersetzt ihn nie.
  3. Absender ist die eigene Adresse des Assistenten (ABSENDER_ADRESSE, eine Plus-Adresse
     desselben Kontos; Gmail nimmt sie ohne weitere Einrichtung als Absender an) mit
     Anzeigename (ABSENDER_NAME; keine Klammern darin, die gelten im Header als Kommentar).

KONTROLLE VOR DEM VERSAND (das System versendet nie Vertrauliches, und weil Vertraulichkeit am
Inhalt nicht sicher erkennbar ist, sichert dieses Skript den Weg):
  4. Text, den ein Modell geschrieben hat, geht nur hinaus, wenn der Besitzer ihn am Bildschirm
     freigibt: Der Aufruf aus einer Session öffnet ein Fenster mit Absender, Empfängern, Betreff,
     Anhängen und dem vollständigen Text (auf Wunsch gerendert im Browser); gesendet wird erst
     nach seinem Klick auf "Senden". Kein Fenster, kein Klick, kein Versand; ein Modell kann den
     Klick nicht behaupten, weil das Skript selbst auf ihn wartet. Empfänger, CC, Betreff, Text
     und Anhangauswahl sind im Fenster änderbar, Offenlegung, CC des Besitzers und Signatur nicht.
  4a. Tastatursicher: Das Fenster erscheint ohne Tastaturfokus, kein Feld und kein Knopf reagiert
     auf Tasten, bevor der Besitzer es mit der Maus anklickt, es gibt keinen Standardknopf und
     keine Enter-Bindung, und Senden nimmt in den ersten zwei Sekunden keinen Klick an. Wer beim
     Aufgehen tippt, tippt ins Leere.
  4b. Verpasst der Besitzer das Fenster (nach WARTEZEIT Sekunden schliesst es ohne Versand),
     legt das Skript die Mail als Paket in die WIEDERVORLAGE ab; --offen listet die Pakete,
     --wiedervorlage <kennung> öffnet das Fenster für genau diese Mail neu.
  5. Direkt senden dürfen nur registrierte Routinen ohne Modell (ROUTINEN, erkannt am Pfad des
     laufenden Skripts, nicht an einem Schalter) und nur an ERLAUBTE_DOMAINS_DIREKT.
  5a. EMPFAENGER_MIT_FREIGABEPFLICHT bekommen nie eine Mail ohne ausdrückliches Häkchen des
     Besitzers im Fenster; eine Routine bricht ab, sobald eine dieser Adressen empfängt.
  6. Kein Repo- und kein Archivpfad als Mailtext oder Anhang: Dateien unter dem Repo und unter
     dem Belegarchiv (<Repo> Archiv) werden abgewiesen. Der Mailtext entsteht im Scratchpad der
     Session; soll eine Repo-Datei mit, wird sie vorher dorthin kopiert, die Kopie ist der
     bewusste Schritt.
  7. Sperrbegriffe (mail-sperrbegriffe.txt im selben Ordner, deine Liste) sind ein zweites Netz:
     im Fenster rot markiert, Sendeknopf erst nach dem Häkchen "Geprüft, trotzdem senden"; eine
     Routine bricht ab.

Aufrufe:
  python gmail-senden.py --auth
      einmalige Anmeldung (öffnet den Browser); dasselbe wie google-sheets-fetch.py --auth
  python gmail-senden.py --an <mail> [--cc <mail>] --betreff "<text>" --html <datei> [--anhang <datei>]... [--sprache de|en]
      aus einer Session; das Werkzeug braucht ein Timeout von 600000 ms, weil das Skript auf den
      Klick wartet. --wartezeit <s> verkürzt die Wartezeit (Tests).
  python gmail-senden.py --antwort-auf <message-id|gmail-id> --html <datei> [--anhang <datei>]... [--an <mail>] [--cc <mail>] [--betreff "<text>"]
      Antwort im bestehenden Thread: --an/--betreff entfallen, sie kommen aus der Originalnachricht
      (Allen-antworten-Standard, Betreff "Re: ..." ohne Dopplung); --an/--cc/--betreff überschreiben
      den Standard. In-Reply-To, References und die Gmail-threadId werden gesetzt, der bisherige
      Verlauf wird nach der Signatur als Zitat angehängt. Ohne auffindbare Originalnachricht:
      FEHLER, es wird nie ein neuer Thread aufgemacht.
  python gmail-senden.py --offen
      listet die abgelegten Pakete (verpasste Fenster).
  python gmail-senden.py --wiedervorlage <kennung>
      öffnet das Fenster für ein abgelegtes Paket neu.

Exitcodes: 0 gesendet, 3 abgelehnt (FEHLER), 4 abgebrochen oder Fenster verpasst.

Für eine Routine ohne Modell (Regel 5): Das Routinenskript lädt dieses Modul aus seiner Datei
(importlib), baut die Nachricht mit baue_nachricht(...) und sendet mit sende(msg); es steht mit
seinem Pfad in ROUTINEN. Aus einer Session ist sende() nicht nutzbar.
"""

import sys
import re
import json
import base64
import argparse
import pathlib
import os
import shutil
import secrets
import datetime
import html as htmlmod
import tempfile
import webbrowser

# --- KONFIGURATION (dein Anteil, Kategorie B in 10_System\Kern-Dateien.md: ein Update ersetzt nur,
# --- was ausserhalb dieses Blocks steht). Einmal ausfüllen, danach sendet das Skript.
BESITZER_NAME = "[NAME]"                              # z.B. "Anna Muster"
BESITZER_ADRESSE = "name@example.com"                 # das Google-Konto, über das gesendet wird; steht in jeder Mail im CC
ASSISTENT_NAME = "Leo"                                # wie dein System heisst (MEIN-SYSTEM.md, Abschnitt 1)
ABSENDER_ADRESSE = "name+leo@example.com"             # Plus-Adresse desselben Kontos; Gmail nimmt sie ohne Einrichtung als Absender
ABSENDER_NAME = "Leo, KI-Assistent von [NAME]"        # Anzeigename, ohne Klammern
ORGANISATION = ""                                     # optional, erscheint in der Signatur (z.B. Firma)
ROUTINEN = []                                         # pathlib.Path-Liste registrierter Routinen ohne Modell, die direkt senden dürfen
ERLAUBTE_DOMAINS_DIREKT = ()                          # z.B. ("@example.com",); Routinen senden nur an diese Domains
EMPFAENGER_MIT_FREIGABEPFLICHT = set()                # Adressen (klein), die nie ohne dein ausdrückliches Häkchen im Fenster Mail bekommen
WARTEZEIT = 480                                       # Sekunden, bis sich das Fenster ohne Klick schliesst (unter dem Werkzeug-Timeout von 600 s)
OFFENLEGUNG = {
    "de": ("<p style='border:1px solid #c9a227;background:#fff8e1;padding:8px 12px;font-size:smaller'>"
           "<b>Diese Mail hat {assistent} geschrieben</b>, der KI-Assistent von {besitzer}. Sie kann Fehler enthalten und ist kritisch zu pr&uuml;fen.</p>"),
    "en": ("<p style='border:1px solid #c9a227;background:#fff8e1;padding:8px 12px;font-size:smaller'>"
           "<b>This mail was written by {assistent}</b>, {besitzer}'s AI assistant. It may contain errors and should be checked critically.</p>"),
}
FUSS = {
    "de": ("<p style='margin-top:18px;color:#4A5164;font-size:smaller;border-top:1px solid #E2E2DA;padding-top:8px'>"
           "<b>{assistent}</b><br>KI-Assistent von {besitzer}{org}<br>"
           "<span style='color:#7C8497'>Antworten an diese Mail erreichen {besitzer} und {assistent}.</span></p>"),
    "en": ("<p style='margin-top:18px;color:#4A5164;font-size:smaller;border-top:1px solid #E2E2DA;padding-top:8px'>"
           "<b>{assistent}</b><br>AI assistant to {besitzer}{org}<br>"
           "<span style='color:#7C8497'>Replies to this mail reach {besitzer} and {assistent}.</span></p>"),
}
# --- ENDE KONFIGURATION ---

HIER = pathlib.Path(__file__).resolve()
_LIB = HIER.parent
if str(_LIB) not in sys.path:                     # robust auch beim Laden aus einer Routine (importlib)
    sys.path.insert(0, str(_LIB))
from mail_text import (nur_text, html_zu_text, sichtbar_html, dekodiere,          # AGENTS.md Abschnitt 5: eine Funktion, ein Ort
                       parse_adressen, adresse_gueltig, nur_adresse, anzeige, header_wert)
import google_zugang
SCRIPTS = HIER.parent.parent                      # 00_INDEX\scripts
REPO = SCRIPTS.parent.parent                      # das Repo
ARCHIV = REPO.parent / (REPO.name + " Archiv")    # das Belegarchiv (AGENTS.md Abschnitt 18)
GESPERRTE_WURZELN = [REPO, ARCHIV]
SPERRLISTE = HIER.parent / "mail-sperrbegriffe.txt"
WIEDERVORLAGE = REPO.parent / (REPO.name + " Artifacts") / "_Cache" / "mail-freigaben"
ANMELDEN = "python \"%s\" --auth" % HIER


class Abgelehnt(Exception):
    """Ein Verstoss gegen die Regeln oben; wird als FEHLER gemeldet, nichts wird gesendet."""


def _fmt(vorlage):
    org = (", " + ORGANISATION) if ORGANISATION else ""
    return vorlage.format(assistent=htmlmod.escape(ASSISTENT_NAME), besitzer=htmlmod.escape(BESITZER_NAME), org=htmlmod.escape(org))


# ---------------------------------------------------------------- Prüfungen

def pruefe_konfiguration():
    """Ein Skript mit Platzhaltern sendet nicht; die Werte stehen im Konfigurationsblock oben."""
    if "[NAME]" in BESITZER_NAME or "[NAME]" in ABSENDER_NAME or BESITZER_ADRESSE == "name@example.com" \
            or ABSENDER_ADRESSE == "name+leo@example.com" or not adresse_gueltig(BESITZER_ADRESSE) or not adresse_gueltig(ABSENDER_ADRESSE):
        raise Abgelehnt("Konfigurationsblock am Anfang von %s ist nicht ausgefuellt (BESITZER_NAME, BESITZER_ADRESSE, "
                        "ABSENDER_ADRESSE, ABSENDER_NAME). Anleitung: 10_System\\Google-Anbindung.md" % HIER.name)


def pruefe_pfad(pfad, was):
    """Regel 6: Kein Repo- und kein Archivpfad als Mailtext oder Anhang."""
    p = pathlib.Path(pfad).resolve()
    if not p.is_file():
        raise Abgelehnt("%s nicht gefunden: %s" % (was, p))
    for wurzel in GESPERRTE_WURZELN:
        if p == wurzel or wurzel in p.parents:
            raise Abgelehnt("%s liegt unter %s; Repo- und Archivdateien gehen nie direkt in eine Mail. "
                            "Mailtext ins Scratchpad schreiben; eine Datei, die ausdruecklich mit soll, "
                            "vorher ins Scratchpad kopieren." % (was, wurzel))
    return p


def lade_sperrbegriffe():
    if not SPERRLISTE.exists():
        return []
    zeilen = SPERRLISTE.read_text(encoding="utf-8").splitlines()
    return [z.strip() for z in zeilen if z.strip() and not z.strip().startswith("#")]


def finde_sperrbegriffe(betreff, html, anhaenge):
    """Regel 7: Treffer der Sperrliste in Betreff, Text, Anhangnamen und Textanhängen."""
    begriffe = lade_sperrbegriffe()
    material = [("Betreff", betreff), ("Text", nur_text(html))]
    for a in anhaenge or []:
        p = pathlib.Path(a)
        material.append(("Anhangname", p.name))
        if p.suffix.lower() in (".txt", ".md", ".html", ".htm", ".csv", ".json", ".xml"):
            try:
                material.append(("Anhang %s" % p.name, p.read_text(encoding="utf-8", errors="ignore")))
            except OSError:
                pass
    treffer = []
    muster = [(b, re.compile((r"\b" if b[0].isalnum() else "") + re.escape(b), re.IGNORECASE)) for b in begriffe]
    for wo, text in material:
        for b, m in muster:
            if m.search(text):
                treffer.append("%s: %s" % (wo, b))
    return treffer


def freigabepflichtig_unter(adressen):
    """Regel 5a: Empfänger, die nie ohne ausdrückliches Häkchen des Besitzers Mail bekommen."""
    pflicht = {a.strip().lower() for a in EMPFAENGER_MIT_FREIGABEPFLICHT}
    return [a for a in adressen if (nur_adresse(a) or (a or "").strip().lower()) in pflicht]


def pruefe_domains(adressen):
    """Regel 5: Routinen senden nur an die erlaubten Domains."""
    if not ERLAUBTE_DOMAINS_DIREKT:
        raise Abgelehnt("ERLAUBTE_DOMAINS_DIREKT ist leer; eine Routine darf dann an niemanden direkt senden.")
    for adr in adressen:
        if not (nur_adresse(adr) or adr.strip().lower()).endswith(tuple(d.lower() for d in ERLAUBTE_DOMAINS_DIREKT)):
            raise Abgelehnt("Direktversand nur an %s; %s ist nicht erlaubt. Alles andere laeuft ueber das Freigabefenster."
                            % (" und ".join(ERLAUBTE_DOMAINS_DIREKT), adr))


def pruefe_platz():
    """Dieses Skript sendet nur an seinem Platz im Repo; eine Kopie an anderer Stelle sendet nicht."""
    if HIER.name != "gmail-senden.py" or not (REPO / "AGENTS.md").is_file() or not (REPO / ".git").exists() \
            or not (SCRIPTS / "guard-mail.ps1").is_file():
        raise Abgelehnt("gmail-senden.py laeuft nicht an seinem Platz (%s); Kopien senden nicht." % HIER)


def aufrufer():
    """Pfad des laufenden Hauptskripts; '-c' und Kopien an anderer Stelle fallen durch."""
    try:
        return pathlib.Path(sys.argv[0]).resolve()
    except (OSError, ValueError):
        return None


def _routinen():
    return [pathlib.Path(r).resolve() for r in ROUTINEN]


# ---------------------------------------------------------------- Nachricht

def erkenne_sprache(html):
    """Deutsch oder Englisch, aus dem Mailtext: zählt häufige Funktionswörter beider Sprachen.
    Standard bei Gleichstand ist Deutsch; --sprache schlägt die Erkennung."""
    text = " " + re.sub(r"\s+", " ", nur_text(html)).lower() + " "
    de = sum(text.count(" %s " % w) for w in ("und", "der", "die", "das", "nicht", "ist", "ich", "mit", "wir", "bitte", "auch", "sind"))
    en = sum(text.count(" %s " % w) for w in ("the", "and", "is", "you", "with", "not", "please", "are", "this", "for", "we", "of"))
    return "en" if en > de else "de"


def cc_mit_besitzer(cc):
    """Regel 2. Nimmt einen String (Kommandozeile, CC-Feld im Fenster) oder eine Liste (Paket).
    Trenner Komma, Semikolon oder Leerzeichen, 'Name <adresse>' bleibt lesbar erhalten, Doppelte
    fallen weg, der Besitzer steht am Ende, wenn er fehlt. Ungültige Einträge bleiben stehen und
    werden im Fenster benannt, damit ein Tippfehler nicht still verschwindet."""
    eintraege = cc if isinstance(cc, (list, tuple)) else [cc or ""]
    liste, gesehen = [], set()
    for e in eintraege:
        for n, a in parse_adressen(e):
            if a.lower() in gesehen:
                continue
            gesehen.add(a.lower())
            liste.append(anzeige(n, a))
    if BESITZER_ADRESSE.lower() not in gesehen:
        liste.append(BESITZER_ADRESSE)
    return liste


def pruefe_empfaenger(an, cc_liste):
    """An und jeder CC-Eintrag einzeln; ein Tippfehler wird mit dem Eintrag benannt statt lautlos
    in einen kaputten Header zu wandern. Gibt den Fehlertext oder None."""
    an_eintraege = parse_adressen(an)
    schlecht = [a for _, a in an_eintraege if not adresse_gueltig(a)]
    if not an_eintraege or schlecht:
        return "Empfänger %s ist keine gültige Mailadresse." % (repr(schlecht[0]) if schlecht else "(leer)")
    cc_schlecht = [a for c in (cc_liste or []) for _, a in parse_adressen(c) if not adresse_gueltig(a)]
    if cc_schlecht:
        return "CC-Eintrag %r ist keine gültige Mailadresse (mehrere Adressen mit Komma trennen)." % cc_schlecht[0]
    return None


def koerper_final(html, sprache=None):
    sprache = sprache or erkenne_sprache(html)
    return _fmt(OFFENLEGUNG[sprache]) + "\n" + html + "\n" + _fmt(FUSS[sprache])


def mime(an, cc_liste, betreff, koerper, anhaenge, in_reply_to=None, references=None):
    """Baut die Nachricht als multipart/alternative (Klartext plus HTML), bei Anhängen darin
    eingebettet in multipart/mixed. Der Klartext-Teil ist Standard und bei Spamfiltern ein
    Pluspunkt (reine HTML-Mails gelten als verdächtig). Date wird gesetzt (RFC 5322); Gmail
    ersetzt den Wert beim Senden durch seine Serverzeit, das ist unschädlich. Empfänger-Header
    entstehen über header_wert, weil ein Eintrag mit Umlaut im Namen sonst als Ganzes kodiert
    würde, Adresse inklusive. in_reply_to/references: nur bei einer Antwort gesetzt."""
    from email.mime.multipart import MIMEMultipart
    from email.mime.text import MIMEText
    from email.mime.base import MIMEBase
    from email import encoders
    from email.utils import formataddr, formatdate
    import mimetypes
    alternative = MIMEMultipart("alternative")
    alternative.attach(MIMEText(html_zu_text(koerper, zitate_markieren=True), "plain", "utf-8"))
    alternative.attach(MIMEText(koerper, "html", "utf-8"))
    if anhaenge:
        msg = MIMEMultipart("mixed")
        msg.attach(alternative)
    else:
        msg = alternative
    msg["From"] = formataddr((ABSENDER_NAME, ABSENDER_ADRESSE))
    msg["To"] = header_wert([an])
    if cc_liste:
        msg["Cc"] = header_wert(cc_liste)
    msg["Subject"] = betreff
    msg["Date"] = formatdate(localtime=True)
    if in_reply_to:
        msg["In-Reply-To"] = in_reply_to
    if references:
        msg["References"] = references
    for a in anhaenge or []:
        p = pathlib.Path(a)
        typ, _ = mimetypes.guess_type(p.name)
        haupt, unter = (typ or "application/octet-stream").split("/", 1)
        teil = MIMEBase(haupt, unter)
        teil.set_payload(p.read_bytes())
        encoders.encode_base64(teil)
        teil.add_header("Content-Disposition", "attachment", filename=p.name)
        msg.attach(teil)
    return msg


def baue_nachricht(an, cc, betreff, html, anhaenge, sprache=None):
    """Baut die MIME-Nachricht mit erzwungener Offenlegung und erzwungenem CC (Regeln 1 bis 3).
    Für Routinen; gibt (msg, cc_liste)."""
    pruefe_konfiguration()
    cc_liste = cc_mit_besitzer(cc)
    return mime(an, cc_liste, betreff, koerper_final(html, sprache), anhaenge), cc_liste


# ---------------------------------------------------------------- Google

def hole_credentials(interaktiv=False):
    try:
        return google_zugang.hole_credentials(interaktiv, anmelde_hinweis=ANMELDEN)
    except google_zugang.KeineAnmeldung as e:
        raise Abgelehnt(str(e))


def _sende_roh(msg, thread_id=None):
    """Der einzige Aufruf der Gmail-API zum Senden. Prüft Platz und Aufrufer (Regel 5).
    thread_id: nur bei --antwort-auf gesetzt, hängt die Mail serverseitig in den Thread."""
    pruefe_platz()
    pruefe_konfiguration()
    wer = aufrufer()
    if wer != HIER and wer not in _routinen():
        raise Abgelehnt("Senden nur aus gmail-senden.py selbst oder einer registrierten Routine (%s); Aufrufer war %s"
                        % (", ".join(r.name for r in _routinen()) or "keine registriert", wer))
    dienst = google_zugang.dienst("gmail", "v1", hole_credentials())
    raw = base64.urlsafe_b64encode(msg.as_bytes()).decode("ascii")
    body = {"raw": raw}
    if thread_id:
        body["threadId"] = thread_id
    return dienst.users().messages().send(userId="me", body=body).execute().get("id")


def sende(msg):
    """Direktversand für registrierte Routinen (Regel 5). Aus einer Session nicht nutzbar: der
    Aufrufer muss eine Routine sein, alle Empfänger in den erlaubten Domains, keiner davon
    freigabepflichtig, kein Sperrbegriff."""
    wer = aufrufer()
    if wer not in _routinen():
        raise Abgelehnt("Direktversand ist registrierten Routinen vorbehalten; aus einer Session laeuft jede Mail ueber das "
                        "Freigabefenster (python gmail-senden.py --an ... --betreff ... --html ...).")
    from email.utils import getaddresses
    adressen = [a for _, a in getaddresses([msg.get("To", ""), msg.get("Cc", "")])]
    pruefe_domains(adressen)
    pflicht = freigabepflichtig_unter(adressen)
    if pflicht:
        raise Abgelehnt("Freigabepflichtiger Empfaenger (%s); eine Routine schreibt ihn nie an, das braucht das "
                        "ausdrueckliche Haekchen im Freigabefenster (Regel 5a)." % ", ".join(pflicht))
    html = ""
    for teil in msg.walk():
        if teil.get_content_type() == "text/html":
            html = teil.get_payload(decode=True).decode("utf-8", errors="ignore")
    treffer = finde_sperrbegriffe(msg.get("Subject", ""), html, [])
    if treffer:
        raise Abgelehnt("Sperrbegriff im Routinelauf, Mail nicht gesendet: " + "; ".join(treffer))
    return _sende_roh(msg)


# ---------------------------------------------------------------- Antwort auf eine bestehende Nachricht (--antwort-auf)

_RE_PRAEFIX = re.compile(r"^\s*(re|aw|wg|fwd?)\s*:\s*", re.IGNORECASE)


def loese_original(kennung):
    """Für --antwort-auf: findet die Originalnachricht per Gmail-ID oder RFC-Message-ID und
    liefert die Header, die eine Antwort braucht. Kein Treffer: Abgelehnt, es wird nie ein
    neuer Thread aufgemacht statt der Antwort."""
    dienst = google_zugang.dienst("gmail", "v1", hole_credentials())
    kennung = kennung.strip()
    felder = ["Message-ID", "References", "Subject", "From", "Reply-To", "To", "Cc", "Date"]
    nachricht = None
    if re.match(r"^[0-9a-fA-F]{10,}$", kennung):
        try:
            nachricht = dienst.users().messages().get(userId="me", id=kennung, format="metadata", metadataHeaders=felder).execute()
        except Exception:
            nachricht = None
    if nachricht is None:
        roh = kennung if kennung.startswith("<") else "<%s>" % kennung.strip("<>")
        try:
            treffer = dienst.users().messages().list(userId="me", q="rfc822msgid:%s" % roh).execute().get("messages") or []
        except Exception:
            treffer = []
        if not treffer:
            raise Abgelehnt("Originalnachricht zu --antwort-auf %r nicht gefunden; es wird kein neuer Thread aufgemacht." % kennung)
        nachricht = dienst.users().messages().get(userId="me", id=treffer[0]["id"], format="metadata", metadataHeaders=felder).execute()
    headers = (nachricht.get("payload") or {}).get("headers") or []

    def h(name):
        for x in headers:
            if x.get("name", "").lower() == name.lower():
                return x.get("value", "")
        return ""
    return {"id": nachricht["id"], "thread_id": nachricht["threadId"], "message_id": h("Message-ID"), "references": h("References"),
            "subject": h("Subject"), "from": h("From"), "reply_to": h("Reply-To"), "to": h("To"), "cc": h("Cc"), "date": h("Date")}


def antwort_betreff(original_betreff):
    """'Re: <Original>', aber kein doppeltes Re; ein Betreff, der schon mit Re/AW/WG/Fwd beginnt,
    bleibt unverändert."""
    text = (original_betreff or "").strip()
    if _RE_PRAEFIX.match(text):
        return text
    return "Re: %s" % text if text else "Re:"


def antwort_kopf(original, an_override=None, cc_override=None):
    """Aus der Originalnachricht (Dict von loese_original) die Header und Standard-Empfänger
    einer Antwort: In-Reply-To, References, Betreff, An/CC im Allen-antworten-Standard (eigene
    Adressen ausgeschlossen). --an/--cc überschreiben den Standard vollständig. Reine Funktion,
    kein Netzzugriff."""
    from email.utils import getaddresses, parseaddr
    msg_id = (original.get("message_id") or "").strip() or None
    refs_alt = (original.get("references") or "").strip()
    references = (refs_alt + " " + msg_id).strip() if (refs_alt and msg_id) else (msg_id or refs_alt or None)
    betreff = antwort_betreff(original.get("subject") or "")
    # Nackte Adresse, kein "Name <adresse>": Von Gmail kommt "From" immer mit Namen.
    eigene = {BESITZER_ADRESSE.lower(), ABSENDER_ADRESSE.lower()}
    an = an_override if an_override else parseaddr(original.get("reply_to") or original.get("from") or "")[1]
    if not an_override and an.lower() in eigene:
        # Antwort auf eine eigene Mail (Nachfassen): Empfänger ist der erste fremde Empfänger des Originals.
        fremde = [a for _, a in getaddresses([original.get("to") or "", original.get("cc") or ""]) if a and a.lower() not in eigene]
        an = fremde[0] if fremde else an
    if cc_override is not None:
        cc = cc_override
    else:
        an_adressen = {a.lower() for _, a in parse_adressen(an)}
        adressen = getaddresses([original.get("to") or "", original.get("cc") or ""])
        cc = ", ".join(anzeige(n, a) for n, a in adressen if a and a.lower() not in eigene and a.lower() not in an_adressen)
    return {"in_reply_to": msg_id, "references": references, "betreff": betreff, "an": an, "cc": cc}


def _original_body(nachricht_id):
    """Body der Originalnachricht für den Zitatblock: HTML wenn vorhanden, sonst Klartext.
    Anhänge werden nicht angefasst (das Zitat zeigt nur Text)."""
    dienst = google_zugang.dienst("gmail", "v1", hole_credentials())
    msg = dienst.users().messages().get(userId="me", id=nachricht_id, format="full").execute()
    treffer = {"html": None, "text": None}

    def suche(payload):
        if payload.get("filename") or payload.get("mimeType") == "message/rfc822":
            return                                             # Anhänge und eingebettete Mails sind nicht der Body
        typ = payload.get("mimeType")
        if typ == "text/html" and treffer["html"] is None:
            treffer["html"] = payload
        elif typ == "text/plain" and treffer["text"] is None:
            treffer["text"] = payload
        for kind in payload.get("parts") or []:
            suche(kind)
    suche(msg.get("payload") or {})

    def text_von(payload):
        body = payload.get("body") or {}
        data = body.get("data")
        if data is None and body.get("attachmentId"):
            data = dienst.users().messages().attachments().get(userId="me", messageId=nachricht_id, id=body["attachmentId"]).execute().get("data")
        if not data:
            return ""
        content_type = next((h.get("value", "") for h in payload.get("headers") or [] if h.get("name", "").lower() == "content-type"), "")
        return dekodiere(base64.urlsafe_b64decode(data + "=" * (-len(data) % 4)), content_type)
    if treffer["html"] is not None:
        return sichtbar_html(text_von(treffer["html"])), True     # ohne head/style/script des Absenders
    if treffer["text"] is not None:
        return text_von(treffer["text"]), False
    return "", False


def zitat_block(original):
    """Zitatblock für eine Antwort: Datumzeile 'Am ... schrieb ...:' plus Blockquote mit dem
    Originaltext. Braucht original['id'] für den vollen Body, deshalb Netzzugriff und bewusst
    von antwort_kopf getrennt (das bleibt offline testbar)."""
    from email.utils import parsedate_to_datetime, parseaddr
    try:
        wann = parsedate_to_datetime(original.get("date") or "").strftime("%d.%m.%Y um %H:%M")
    except Exception:
        wann = original.get("date") or ""
    name, adresse = parseaddr(original.get("from") or "")
    wer = "%s <%s>" % (name, adresse) if name else adresse
    body_html, ist_html = _original_body(original["id"])
    inhalt = body_html if ist_html else "<p>%s</p>" % "<br>".join(htmlmod.escape(z) for z in body_html.splitlines())
    return ("<p style='color:#7C8497'>Am %s schrieb %s:</p>"
            "<blockquote style='margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex'>%s</blockquote>"
            ) % (wann, htmlmod.escape(wer), inhalt)


# ---------------------------------------------------------------- Freigabefenster

def text_zu_html(text):
    """Bearbeiteten Klartext zurück in schlichtes HTML: Absätze, Zeilenumbrüche, Aufzählungen,
    URLs und Mailadressen als Links."""
    def verlinke(s):
        s = htmlmod.escape(s)
        s = re.sub(r"(https?://[^\s<)]*[^\s<).,;:])", r"<a href='\1'>\1</a>", s)
        return re.sub(r"(?<![\w/'])([\w.+-]+@[\w-]+(?:\.[\w-]+)+)", r"<a href='mailto:\1'>\1</a>", s)
    teile = []
    for absatz in re.split(r"\n\s*\n", text.strip()):
        zeilen = [z for z in absatz.splitlines()]
        if zeilen and all(z.strip().startswith("- ") for z in zeilen if z.strip()):
            teile.append("<ul>" + "".join("<li>%s</li>" % verlinke(z.strip()[2:]) for z in zeilen if z.strip()) + "</ul>")
        else:
            teile.append("<p>%s</p>" % "<br>".join(verlinke(z) for z in zeilen))
    return "\n".join(teile)


def fenster_ohne_fokus_zeigen(wurzel):
    """Zeigt das Fenster im Vordergrund, OHNE ihm den Tastaturfokus zu geben (Regel 4a).
    Windows: Das Fenster bekommt den Stil WS_EX_NOACTIVATE, kann also gar nicht aktiviert werden
    (SW_SHOWNOACTIVATE allein reicht nicht), wird topmost gezeigt, die Taskleiste blinkt, kurzer
    Hinweiston. Erst der erste Mausklick ins Fenster hebt den Stil auf und holt die Tastatur.
    Ohne ctypes (anderes System) normal einblenden, aber nie focus_force."""
    wurzel.update_idletasks()
    try:
        import ctypes
        from ctypes import wintypes
        user32 = ctypes.windll.user32
        hwnd = user32.GetParent(wurzel.winfo_id()) or wurzel.winfo_id()
        GWL_EXSTYLE, WS_EX_NOACTIVATE = -20, 0x08000000
        user32.SetWindowLongW(hwnd, GWL_EXSTYLE, user32.GetWindowLongW(hwnd, GWL_EXSTYLE) | WS_EX_NOACTIVATE)
        user32.ShowWindow(hwnd, 4)                                    # SW_SHOWNOACTIVATE
        user32.SetWindowPos(hwnd, -1, 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0010)  # TOPMOST, NOSIZE, NOMOVE, NOACTIVATE

        class FLASHWINFO(ctypes.Structure):
            _fields_ = [("cbSize", wintypes.UINT), ("hwnd", wintypes.HWND), ("dwFlags", wintypes.DWORD),
                        ("uCount", wintypes.UINT), ("dwTimeout", wintypes.DWORD)]
        fi = FLASHWINFO(ctypes.sizeof(FLASHWINFO), hwnd, 0x00000002 | 0x0000000C, 0, 0)  # FLASHW_TRAY | FLASHW_TIMERNOFG
        user32.FlashWindowEx(ctypes.byref(fi))

        def freischalten(_ereignis=None):
            # Erster Mausklick ins Fenster: ab jetzt darf es die Tastatur nehmen (zum Tippen in ein Feld).
            user32.SetWindowLongW(hwnd, GWL_EXSTYLE, user32.GetWindowLongW(hwnd, GWL_EXSTYLE) & ~WS_EX_NOACTIVATE)
            user32.SetForegroundWindow(hwnd)
            wurzel.unbind_all("<Button-1>")
        wurzel.bind_all("<Button-1>", freischalten, add="+")
    except Exception:
        wurzel.deiconify()
        wurzel.attributes("-topmost", True)
    try:
        import winsound
        winsound.MessageBeep(winsound.MB_ICONASTERISK)
    except Exception:
        pass


def freigabe_im_fenster(an, cc_liste, betreff, html, anhaenge, sprache, wartezeit=WARTEZEIT, hinweis="", zitat_html=None):
    """Regel 4: Fenster auf dem Bildschirm des Besitzers. Empfänger, Betreff, Text und
    Anhangauswahl sind dort änderbar; Offenlegung, CC des Besitzers und Signatur nicht.
    zitat_html (nur bei --antwort-auf): der bisherige Verlauf, unter der Signatur als fester,
    nicht bearbeitbarer Text gezeigt und beim Senden unverändert an den Körper angehängt.
    Gibt (wahl, an, cc_liste, betreff, html, anhaenge, text) zurück; wahl ist "senden",
    "abbrechen" oder "zeit"."""
    try:
        import tkinter as tk
        from tkinter import ttk, scrolledtext
        wurzel = tk.Tk()
        wurzel.withdraw()
    except Exception as e:  # kein Bildschirm (Kopflos, Remote): kein Versand
        raise Abgelehnt("Kein Freigabefenster moeglich (%s); ohne Klick des Besitzers wird nichts gesendet." % e)

    sprache = sprache or erkenne_sprache(html)
    text_original = html_zu_text(html)
    ergebnis = {"wahl": "zeit", "an": an, "cc": cc_liste, "betreff": betreff, "html": html, "anhaenge": list(anhaenge), "text": text_original}
    start = datetime.datetime.now()

    wurzel.title("%s möchte eine Mail senden" % ASSISTENT_NAME)
    wurzel.geometry("880x780")  # Startwert; wird unten auf den tatsächlichen Platzbedarf angepasst
    rahmen = ttk.Frame(wurzel, padding=12)
    rahmen.pack(fill="both", expand=True)
    fett = ("Segoe UI", 10, "bold")
    normal = ("Segoe UI", 10)

    def zeile(label):
        f = ttk.Frame(rahmen)
        f.pack(fill="x", pady=1)
        ttk.Label(f, text=label, width=10, font=fett).pack(side="left", anchor="n")
        return f

    if hinweis:
        ttk.Label(zeile("Hinweis"), text=hinweis, foreground="#1f5fbf", font=normal, wraplength=740, justify="left").pack(side="left")
    ttk.Label(zeile("Von"), text="%s <%s>" % (ABSENDER_NAME, ABSENDER_ADRESSE), font=normal).pack(side="left")
    an_var = tk.StringVar(value=an)
    ttk.Entry(zeile("An"), textvariable=an_var, font=normal, takefocus=0).pack(side="left", fill="x", expand=True)
    cc_var = tk.StringVar(value=", ".join(c for c in cc_liste if nur_adresse(c) != BESITZER_ADRESSE.lower()))
    f_cc = zeile("CC")
    ttk.Entry(f_cc, textvariable=cc_var, font=normal, takefocus=0).pack(side="left", fill="x", expand=True)
    ttk.Label(f_cc, text=" + du, immer", foreground="#7C8497", font=("Segoe UI", 9)).pack(side="left")
    betreff_var = tk.StringVar(value=betreff)
    ttk.Entry(zeile("Betreff"), textvariable=betreff_var, font=normal, takefocus=0).pack(side="left", fill="x", expand=True)

    # Anhänge: je einer mit Häkchen (mitsenden) und Knopf zum Öffnen; ein Anhang wird geprüft, bevor er freigegeben wird.
    f_anh = zeile("Anhänge")
    anhang_vars = []
    if not anhaenge:
        ttk.Label(f_anh, text="keine", font=normal).pack(side="left")
    else:
        spalte = ttk.Frame(f_anh)
        spalte.pack(side="left", fill="x", expand=True)
        for a in anhaenge:
            p = pathlib.Path(a)
            r = ttk.Frame(spalte)
            r.pack(fill="x")
            v = tk.BooleanVar(value=True)
            anhang_vars.append((a, v))
            ttk.Checkbutton(r, text="%s (%.0f KB) mitsenden" % (p.name, p.stat().st_size / 1024), variable=v, takefocus=0).pack(side="left")
            ttk.Button(r, text="Öffnen", width=8, takefocus=0, command=lambda pf=str(p): _oeffne(pf)).pack(side="left", padx=(8, 0))

    achtung_var = tk.StringVar(value="")
    ttk.Label(rahmen, textvariable=achtung_var, foreground="#b00020", font=normal, wraplength=840, justify="left").pack(anchor="w", pady=(4, 0))

    ttk.Label(rahmen, text="Offenlegung (fest): " + nur_text(_fmt(OFFENLEGUNG[sprache])), foreground="#7C8497",
              font=("Segoe UI", 9), wraplength=840, justify="left").pack(anchor="w", pady=(8, 2))
    ttk.Label(rahmen, text="Mailtext, hier direkt änderbar (zum Tippen zuerst hineinklicken):", font=("Segoe UI", 9, "bold")).pack(anchor="w")
    box = scrolledtext.ScrolledText(rahmen, wrap="word", font=normal, height=16, undo=True, takefocus=0)
    box.pack(fill="both", expand=True)
    box.insert("1.0", text_original)
    ttk.Label(rahmen, text="Signatur (fest): " + nur_text(_fmt(FUSS[sprache])).replace("\n", " "), foreground="#7C8497",
              font=("Segoe UI", 9), wraplength=840, justify="left").pack(anchor="w", pady=(2, 0))
    if zitat_html:
        ttk.Label(rahmen, text="Bisheriger Verlauf (fest, wird nach der Signatur angehängt):", font=("Segoe UI", 9, "bold")).pack(anchor="w", pady=(8, 2))
        zitat_box = scrolledtext.ScrolledText(rahmen, wrap="word", font=("Segoe UI", 9), height=6, takefocus=0)
        zitat_box.pack(fill="both")
        zitat_box.insert("1.0", nur_text(zitat_html))
        zitat_box.configure(state="disabled", background="#F4F4F0", foreground="#4A5164")

    def aktueller_stand():
        text = box.get("1.0", "end-1c")
        html_neu = html if text.strip() == text_original.strip() else text_zu_html(text)
        cc_neu = cc_mit_besitzer(cc_var.get())
        anh_neu = [a for a, v in anhang_vars if v.get()]
        return an_var.get().strip(), cc_neu, betreff_var.get().strip(), html_neu, anh_neu, text

    def gruende_fuer(an_neu, cc_neu, betreff_neu, html_neu, anh_neu):
        g = ["Empfänger %s: nur mit deinem ausdrücklichen Go" % h for h in freigabepflichtig_unter([an_neu] + cc_neu)]
        g += finde_sperrbegriffe(betreff_neu, html_neu, anh_neu)
        return g

    def markiere(treffer):
        box.tag_remove("treffer", "1.0", "end")
        box.tag_configure("treffer", background="#ffd6d6")
        for t in treffer:
            begriff = t.split(": ", 1)[1]
            pos_start = "1.0"
            while True:
                pos = box.search(begriff, pos_start, stopindex="end", nocase=True)
                if not pos:
                    break
                ende = "%s+%dc" % (pos, len(begriff))
                box.tag_add("treffer", pos, ende)
                pos_start = ende

    knoepfe = ttk.Frame(rahmen)
    knoepfe.pack(fill="x", pady=(10, 0))
    rest = tk.StringVar(value="")
    ttk.Label(knoepfe, textvariable=rest, foreground="#7C8497").pack(side="left")
    geprueft = tk.BooleanVar(value=False)
    haken = ttk.Checkbutton(knoepfe, text="Geprüft, trotzdem senden", variable=geprueft, takefocus=0)

    def pruefe_und_zeige():
        an_neu, cc_neu, betreff_neu, html_neu, anh_neu, _ = aktueller_stand()
        g = gruende_fuer(an_neu, cc_neu, betreff_neu, html_neu, anh_neu)
        markiere([x for x in g if ": " in x and not x.startswith("Empfänger")])
        if g:
            achtung_var.set("Achtung: " + "; ".join(g) + ". Senden erst nach dem Häkchen unten.")
            haken.pack(side="left", padx=(12, 0))
        else:
            achtung_var.set("")
            haken.pack_forget()
        return g

    def im_browser():
        an_neu, cc_neu, betreff_neu, html_neu, anh_neu, _ = aktueller_stand()
        with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False, encoding="utf-8") as f:
            f.write("<html><head><meta charset='utf-8'></head><body style='font-family:sans-serif;max-width:760px;margin:24px auto'>"
                    "<p style='color:#7C8497'>Vorschau. An: %s, CC: %s, Betreff: %s, Anhänge: %s</p><hr>%s</body></html>"
                    % (htmlmod.escape(an_neu), htmlmod.escape(", ".join(cc_neu)), htmlmod.escape(betreff_neu),
                       htmlmod.escape(", ".join(pathlib.Path(a).name for a in anh_neu) or "keine"), koerper_final(html_neu, sprache)))
        webbrowser.open("file:///" + f.name.replace("\\", "/"))

    def uebernehmen(wahl):
        an_neu, cc_neu, betreff_neu, html_neu, anh_neu, text = aktueller_stand()
        ergebnis.update({"wahl": wahl, "an": an_neu, "cc": cc_neu, "betreff": betreff_neu, "html": html_neu, "anhaenge": anh_neu, "text": text})
        wurzel.destroy()

    def senden():
        if (datetime.datetime.now() - start).total_seconds() < 2:   # Schutz gegen einen Klick, der nicht dem Fenster galt
            return
        an_neu, cc_neu, betreff_neu, html_neu, anh_neu, text = aktueller_stand()
        fehler = pruefe_empfaenger(an_neu, cc_neu)
        if fehler:
            achtung_var.set("Achtung: " + fehler)
            return
        if not betreff_neu or not text.strip():
            achtung_var.set("Achtung: Betreff und Text dürfen nicht leer sein.")
            return
        if pruefe_und_zeige() and not geprueft.get():
            return
        uebernehmen("senden")

    ttk.Button(knoepfe, text="Abbrechen (verwerfen)", takefocus=0, command=lambda: uebernehmen("abbrechen")).pack(side="right", padx=(6, 0))
    ttk.Button(knoepfe, text="Senden", takefocus=0, command=senden).pack(side="right")
    ttk.Button(knoepfe, text="Im Browser ansehen", takefocus=0, command=im_browser).pack(side="right", padx=(0, 12))
    pruefe_und_zeige()

    # Fenster auf den tatsächlichen Platzbedarf höhen: Bei fester Höhe clippt Tk Widgets unten aus dem
    # sichtbaren Bereich, ohne das zu melden, und der Senden-Knopf kann unsichtbar werden.
    try:
        wurzel.update_idletasks()
        hoehe = min(wurzel.winfo_reqheight() + 10, wurzel.winfo_screenheight() - 80)
        wurzel.geometry("880x%d+60+30" % max(hoehe, 500))
    except Exception:
        pass

    ablauf = {"sek": int(wartezeit)}

    def tick():
        ablauf["sek"] -= 1
        if ablauf["sek"] <= 0:
            uebernehmen("zeit")  # Stand am Zeitablauf sichern, statt Änderungen zu verwerfen
            return
        rest.set("schliesst ohne Versand in %d:%02d" % divmod(ablauf["sek"], 60))
        wurzel.after(1000, tick)

    wurzel.protocol("WM_DELETE_WINDOW", lambda: uebernehmen("abbrechen"))
    wurzel.after(1000, tick)
    fenster_ohne_fokus_zeigen(wurzel)
    wurzel.mainloop()
    return ergebnis["wahl"], ergebnis["an"], ergebnis["cc"], ergebnis["betreff"], ergebnis["html"], ergebnis["anhaenge"], ergebnis["text"]


def _oeffne(pfad):
    """Anhang mit dem Standardprogramm öffnen (Windows: os.startfile, sonst webbrowser)."""
    try:
        os.startfile(pfad)          # type: ignore[attr-defined]
    except AttributeError:
        webbrowser.open("file:///" + str(pfad).replace("\\", "/"))


# ---------------------------------------------------------------- Wiedervorlage (Regel 4b)

def paket_ablegen(an, cc_liste, betreff, html, anhaenge, sprache, kennung=None, zitat_html=None, antwort_auf=None, hinweis=None):
    """Legt eine Mail als Paket in die Wiedervorlage (verpasstes Fenster); mit kennung wird ein
    bestehendes Paket mit dem aktuellen Stand überschrieben. Gibt die Kennung. Bei einer Antwort
    trägt das Paket die Thread-Bindung und den Zitatblock, damit die Wiedervorlage im Thread bleibt."""
    neu = kennung is None
    kennung = kennung or secrets.token_hex(4)
    mappe = WIEDERVORLAGE / kennung
    mappe.mkdir(parents=True, exist_ok=not neu)
    alt = json.loads((mappe / "paket.json").read_text(encoding="utf-8")) if (mappe / "paket.json").is_file() else {}
    (mappe / "mail.html").write_text(html, encoding="utf-8")
    if zitat_html is not None:
        (mappe / "zitat.html").write_text(zitat_html, encoding="utf-8")
    namen = []
    for a in anhaenge:
        quelle = pathlib.Path(a)
        ziel = mappe / quelle.name
        if quelle.resolve() != ziel.resolve():
            shutil.copy2(quelle, ziel)
        namen.append(ziel.name)
    (mappe / "paket.json").write_text(json.dumps({
        "kennung": kennung, "an": an, "cc": cc_liste, "betreff": betreff, "sprache": sprache,
        "anhaenge": namen, "erstellt": alt.get("erstellt") or datetime.datetime.now().strftime("%d.%m.%Y %H:%M"),
        "antwort_auf": antwort_auf if antwort_auf is not None else alt.get("antwort_auf"),
        "hinweis": hinweis if hinweis is not None else alt.get("hinweis"),
    }, ensure_ascii=False, indent=1), encoding="utf-8")
    return kennung


def pakete():
    """Alle offenen Pakete, älteste zuerst."""
    liste = []
    if WIEDERVORLAGE.exists():
        for m in WIEDERVORLAGE.iterdir():
            p = m / "paket.json"
            if m.is_dir() and p.is_file():
                liste.append(json.loads(p.read_text(encoding="utf-8")))
    return sorted(liste, key=lambda x: x["erstellt"])


def paket_laden(kennung):
    kennung = re.sub(r"[^0-9a-f]", "", kennung.lower())
    mappe = WIEDERVORLAGE / kennung
    if not (mappe / "paket.json").is_file():
        raise Abgelehnt("Kein offenes Paket %s in %s (schon gesendet oder verworfen?)." % (kennung, WIEDERVORLAGE))
    p = json.loads((mappe / "paket.json").read_text(encoding="utf-8"))
    p["mappe"] = mappe
    zpfad = mappe / "zitat.html"
    p["zitat_html"] = zpfad.read_text(encoding="utf-8") if zpfad.is_file() else None
    return p


def paket_entfernen(kennung):
    shutil.rmtree(WIEDERVORLAGE / kennung, ignore_errors=True)


def freigabe_durchlaufen(an, cc_liste, betreff, html_pfad, anhaenge, sprache, wartezeit, hinweis="", kennung=None,
                          zitat_html=None, antwort_auf=None):
    """Fenster zeigen, nach der Wahl des Besitzers senden (mit seinen Änderungen aus dem Fenster);
    bei Zeitablauf Paket ablegen. Gibt (wahl, meldung, kennung)."""
    html = pathlib.Path(html_pfad).read_text(encoding="utf-8")
    sprache = sprache or erkenne_sprache(html)
    wahl, an, cc_liste, betreff, html, anhaenge, text = freigabe_im_fenster(an, cc_liste, betreff, html, anhaenge, sprache,
                                                                              wartezeit, hinweis, zitat_html)
    if wahl == "senden":
        koerper = koerper_final(html, sprache)
        if zitat_html:
            koerper += "\n" + zitat_html
        kopf = antwort_auf or {}
        msg = mime(an, cc_liste, betreff, koerper, anhaenge, in_reply_to=kopf.get("in_reply_to"), references=kopf.get("references"))
        mid = _sende_roh(msg, thread_id=kopf.get("thread_id"))
        return wahl, "OK gesendet an %s, CC %s, Betreff %r, %d Anhang/Anhaenge, Gmail-ID %s (im Fenster freigegeben)" % (
            an, ", ".join(cc_liste), betreff, len(anhaenge), mid), kennung
    if wahl == "abbrechen":
        return wahl, "ABGEBROCHEN Die Mail wurde im Freigabefenster verworfen; nichts gesendet.", kennung
    if kennung is None:
        kennung = paket_ablegen(an, cc_liste, betreff, html, anhaenge, sprache, zitat_html=zitat_html, antwort_auf=antwort_auf, hinweis=hinweis)
    return wahl, ("VERPASST Fenster nach %d s ohne Klick geschlossen; nichts gesendet. Paket %s abgelegt in %s; "
                  "neu oeffnen mit: python \"%s\" --wiedervorlage %s" % (wartezeit, kennung, WIEDERVORLAGE, HIER, kennung)), kennung


# ---------------------------------------------------------------- CLI

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--auth", action="store_true", help="einmalige Google-Anmeldung (oeffnet den Browser)")
    ap.add_argument("--an")
    ap.add_argument("--cc")
    ap.add_argument("--betreff")
    ap.add_argument("--html")
    ap.add_argument("--anhang", action="append")
    ap.add_argument("--sprache", choices=["de", "en"], default=None, help="sonst automatisch aus dem Text erkannt")
    ap.add_argument("--wartezeit", type=int, default=WARTEZEIT, help="Sekunden bis das Fenster ohne Klick schliesst")
    ap.add_argument("--offen", action="store_true", help="abgelegte Pakete (verpasste Fenster) auflisten")
    ap.add_argument("--wiedervorlage", metavar="KENNUNG", help="Fenster fuer ein abgelegtes Paket neu oeffnen")
    ap.add_argument("--antwort-auf", metavar="KENNUNG", dest="antwort_auf",
                    help="Message-ID oder Gmail-ID der Originalnachricht; die Antwort bleibt im bestehenden Thread (--an/--betreff entfallen dann)")
    a = ap.parse_args()
    codes = {"senden": 0, "abbrechen": 4, "zeit": 4}
    try:
        if a.auth:
            hole_credentials(interaktiv=True)
            print("OK Google-Anmeldung vorhanden (%s)" % google_zugang.TOKEN_FILE)
            return
        if a.offen:
            liste = pakete()
            if not liste:
                print("Keine offenen Pakete in %s" % WIEDERVORLAGE)
            for p in liste:
                print("%s  %s  an %s  Betreff %r%s" % (p["kennung"], p["erstellt"], p["an"], p["betreff"], ", mit Anhang" if p.get("anhaenge") else ""))
            return
        pruefe_platz()
        pruefe_konfiguration()
        if a.wiedervorlage:
            p = paket_laden(a.wiedervorlage)
            anhaenge = [str(p["mappe"] / n) for n in p["anhaenge"]]
            hinweis = ((p.get("hinweis") + " ") if p.get("hinweis") else "") + "Aus der Wiedervorlage (vorbereitet %s)." % p["erstellt"]
            wahl, meldung, _ = freigabe_durchlaufen(p["an"], p["cc"], p["betreff"], p["mappe"] / "mail.html", anhaenge, p.get("sprache"),
                                                    a.wartezeit, hinweis=hinweis, kennung=p["kennung"],
                                                    zitat_html=p.get("zitat_html"), antwort_auf=p.get("antwort_auf"))
            if wahl in ("senden", "abbrechen"):
                paket_entfernen(p["kennung"])
            print(meldung)
            sys.exit(codes[wahl])

        if not a.html:
            raise Abgelehnt("--html ist Pflicht (oder --wiedervorlage <kennung>, --offen, --auth).")
        html_pfad = pruefe_pfad(a.html, "Mailtext")
        anhaenge = [str(pruefe_pfad(x, "Anhang")) for x in (a.anhang or [])]

        if a.antwort_auf:
            original = loese_original(a.antwort_auf)
            kopf = antwort_kopf(original, a.an, a.cc)
            an, betreff = kopf["an"], (a.betreff or kopf["betreff"])   # --betreff darf das "Re: ..." ersetzen, der Thread bleibt
            cc_liste = cc_mit_besitzer(kopf["cc"])
            fehler = pruefe_empfaenger(an, cc_liste)
            if fehler:
                raise Abgelehnt(fehler)
            zitat_html = zitat_block(original)
            hinweis = "Antwort auf %r von %s, %s." % (original["subject"], original["from"], original["date"])
            fadeninfo = {"thread_id": original["thread_id"], "in_reply_to": kopf["in_reply_to"], "references": kopf["references"]}
            wahl, meldung, kennung = freigabe_durchlaufen(an, cc_liste, betreff, html_pfad, anhaenge, a.sprache, a.wartezeit,
                                                           hinweis=hinweis, zitat_html=zitat_html, antwort_auf=fadeninfo)
        else:
            if not (a.an and a.betreff):
                raise Abgelehnt("--an, --betreff und --html sind Pflicht (oder --antwort-auf <kennung>, oder --wiedervorlage <kennung>).")
            cc_liste = cc_mit_besitzer(a.cc)
            fehler = pruefe_empfaenger(a.an, cc_liste)
            if fehler:
                raise Abgelehnt(fehler)
            wahl, meldung, kennung = freigabe_durchlaufen(a.an, cc_liste, a.betreff, html_pfad, anhaenge, a.sprache, a.wartezeit)
        print(meldung)
        sys.exit(codes[wahl])
    except Abgelehnt as e:
        print("FEHLER " + str(e))
        sys.exit(3)


if __name__ == "__main__":
    main()
