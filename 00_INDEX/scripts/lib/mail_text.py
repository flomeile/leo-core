r"""Gemeinsame HTML/Text- und Adress-Hilfsfunktionen für Mails, genutzt von gmail-senden.py
(Freigabefenster, Zitatblock einer Antwort, Header-Aufbau). Eine Funktion, ein Ort statt zwei
Kopien, die auseinanderlaufen (AGENTS.md, Abschnitt 5). Kein Sendeweg, keine Google-Aufrufe:
reine Text- und Adressumwandlung.
"""

import re
import html as htmlmod
from email.utils import getaddresses, parseaddr, formataddr

_BQ_START = "\x01BQ\x01"
_BQ_END = "\x02BQ\x02"

# Was nie als Text gelesen werden darf: Kopfbereich, Stylesheets, Skripte, Kommentare. Outlook- und
# Newsletter-HTML tragen davon Hunderte Zeilen; ohne diesen Schritt stand CSS als "Mailtext" im
# Fenster und in der Markdown.
_UNSICHTBAR = re.compile(r"(?is)<\s*(head|style|script|title)\b[^>]*>.*?</\s*\1\s*>|<!--.*?-->")


def sichtbar_html(html):
    """Nur der sichtbare Teil eines HTML-Dokuments: ohne head, style, script, Kommentare, und bei
    einem vollstaendigen Dokument nur der Inhalt von <body>. Auch fuer den Zitatblock einer
    Antwort, damit kein fremdes Stylesheet in Leos Mail wandert."""
    html = _UNSICHTBAR.sub(" ", html or "")
    # Die Huelle (html, body, DOCTYPE) faellt weg, ihr Inhalt bleibt; kein "erstes body nehmen":
    # ein Zitatblock kann ein ganzes fremdes Dokument enthalten, und dann laege alles vor und
    # nach dessen body ausserhalb des Treffers.
    return re.sub(r"(?is)<\s*/?\s*(html|body)\b[^>]*>|<!DOCTYPE[^>]*>", " ", html)


def nur_text(html):
    """HTML zu lesbarem Text: Absätze und Zeilenumbrüche bleiben als Zeilen erhalten. Grobe
    Vorschau (Sperrbegriff-Suche, Spracherkennung, Signatur-Anzeige im Fenster), keine Links
    oder Listen-Aufbereitung; dafür html_zu_text."""
    t = sichtbar_html(html)
    t = re.sub(r"(?i)<\s*(br|/p|/div|/li|/tr|/h[1-6])\s*/?>", "\n", t)
    t = re.sub(r"(?i)<\s*/t[dh]\s*>", "\t", t)          # Zellgrenze bleibt sichtbar
    t = re.sub(r"<[^>]+>", " ", t)
    t = htmlmod.unescape(t)
    t = re.sub(r"[ \t]+", " ", t)
    t = "\n".join(z.strip() for z in t.splitlines())
    return re.sub(r"\n\s*\n+", "\n\n", t).strip()


def html_zu_text(html, zitate_markieren=False):
    """Lesbarer Klartext aus HTML: Absätze bleiben Absätze, Links werden zu "Text (URL)",
    Aufzählungen zu "- ", Tabellenzellen durch Tabulator getrennt, damit beim Bearbeiten oder
    Lesen nichts Unsichtbares verloren geht oder zusammenklebt.

    zitate_markieren=True (fürs Lesen eingehender Mails, wenn kein text/plain-Teil vorliegt):
    <blockquote>-Blöcke (der zitierte Vorgänger in einer Antwort) werden zeilenweise mit "> "
    gekennzeichnet statt wie jeder andere Block einfach durchzulaufen. Default False ändert am
    bestehenden Verhalten (Freigabefenster-Editor) nichts."""
    html = sichtbar_html(html)
    if zitate_markieren:
        # Sentinels auf eigene Zeilen, damit die Tiefenzählung unten zeilenweise arbeiten kann
        html = re.sub(r"(?is)<blockquote[^>]*>", "\n" + _BQ_START + "\n", html)
        html = re.sub(r"(?is)</blockquote>", "\n" + _BQ_END + "\n", html)

    def link(m):
        url, text = m.group(1), re.sub(r"<[^>]+>", "", m.group(2)).strip()
        return text if (text == url or url.startswith("mailto:") and url[7:] == text) else "%s (%s)" % (text, url)

    t = re.sub(r"(?is)<a\s[^>]*href=['\"]([^'\"]+)['\"][^>]*>(.*?)</a>", link, html)
    t = re.sub(r"(?i)<\s*li[^>]*>", "\n- ", t)
    t = re.sub(r"(?i)<\s*br\s*/?>", "\n", t)
    t = re.sub(r"(?i)<\s*/(p|div|ul|ol|table|h[1-6])\s*>", "\n\n", t)   # Blockende = Absatzgrenze
    t = re.sub(r"(?i)<\s*/tr\s*>", "\n", t)
    t = re.sub(r"(?i)<\s*/t[dh]\s*>", "\t", t)
    t = re.sub(r"<[^>]+>", "", t)
    t = htmlmod.unescape(t)
    t = "\n".join(z.strip() for z in t.splitlines())
    t = re.sub(r"\n{3,}", "\n\n", t).strip()
    if zitate_markieren:
        t = _markiere_zitate(t)
    return t


def _markiere_zitate(t):
    """Zeilenweise Tiefenzählung: eine Zeile, die nur den Start-Sentinel trägt, erhöht die Tiefe,
    eine mit dem Ende-Sentinel senkt sie, jede andere Zeile bekommt "> " je Tiefe. Zwei frühere
    Fassungen scheiterten an verschachtelten Zitaten (Antwort auf eine Antwort): die naive
    Paarung liess "BQ" als Text stehen, die stückweise Zählung klebte an der Grenze zweier
    Ebenen Präfixe zusammen (">> >")."""
    ergebnis, tiefe, am_anfang, trenner = [], 0, False, False

    def leerzeile():
        return ("> " * tiefe).rstrip()
    for zeile in t.split("\n"):
        if zeile == _BQ_START:
            if trenner:
                ergebnis.append(leerzeile())
                trenner = False
            tiefe += 1
            am_anfang = True                                   # Leerzeilen am Blockanfang fallen weg
        elif zeile == _BQ_END:
            while ergebnis and ergebnis[-1] == leerzeile():    # und am Blockende
                ergebnis.pop()
            tiefe = max(0, tiefe - 1)
            trenner = True                                     # nach dem Block eine Leerzeile, bevor es weitergeht
        elif zeile.strip():
            if trenner:
                ergebnis.append(leerzeile())
                trenner = False
            ergebnis.append(("> " * tiefe + zeile) if tiefe else zeile)
            am_anfang = False
        elif tiefe == 0:
            ergebnis.append(zeile)
        elif not am_anfang and not trenner and ergebnis and ergebnis[-1] != leerzeile():
            ergebnis.append(leerzeile())                       # hoechstens eine Leerzeile je Absatz
    return re.sub(r"\n{3,}", "\n\n", "\n".join(ergebnis)).strip("\n")


# ---------------------------------------------------------------- Zeichensatz eines MIME-Teils

def dekodiere(rohbytes, content_type=""):
    """Bytes eines text/*-Teils zu str. Die Gmail-API liefert Body-Bytes im Zeichensatz des
    Absenders, nicht in UTF-8; aeltere Mail-Clients kommen als iso-8859-1 oder
    windows-1252, und ein blindes UTF-8-Decode macht aus jedem Umlaut ein Ersatzzeichen.
    Reihenfolge: strikt UTF-8 (trifft die Mehrheit und laesst sich an einem Latin-1-Text mit
    Umlauten nicht faelschlich erreichen), dann der deklarierte Zeichensatz, dann UTF-8 mit
    Ersatzzeichen."""
    if not rohbytes:
        return ""
    try:
        return rohbytes.decode("utf-8")
    except UnicodeDecodeError:
        pass
    m = re.search(r"(?i)charset\s*=\s*\"?([\w.:-]+)", content_type or "")
    if m:
        try:
            return rohbytes.decode(m.group(1).strip('"').lower())
        except (UnicodeDecodeError, LookupError):
            pass
    return rohbytes.decode("utf-8", errors="replace")


# ---------------------------------------------------------------- Adressen

_ADRESSE = re.compile(r"^[^@\s<>\"',;]+@[^@\s<>\"',;]+\.[^@\s<>\"',;]+$")


def parse_adressen(text):
    """Eine von Hand oder aus einem Header stammende Empfaengerangabe in [(name, adresse)].
    Toleriert Komma, Semikolon (Outlook) und blosses Leerzeichen als Trenner, "Name <adresse>",
    Namen mit Komma in Anfuehrungszeichen und leere Eintraege; laesst Ungueltiges als Eintrag
    stehen, damit der Aufrufer es benennen kann (adresse_gueltig)."""
    s = (text or "").replace(";", ",")
    if "<" in s or '"' in s:
        paare = getaddresses([s])
    else:
        paare = [("", t) for t in re.split(r"[,\s]+", s)]
    return [(n.strip(), a.strip()) for n, a in paare if a and a.strip()]


def adresse_gueltig(adresse):
    return bool(_ADRESSE.match((adresse or "").strip()))


def nur_adresse(eintrag):
    """'Name <a@b.ch>' oder 'a@b.ch' -> 'a@b.ch' (klein)."""
    return parseaddr(eintrag or "")[1].strip().lower()


def anzeige(name, adresse):
    """Lesbare Form fuers Fenster und die Ablage: 'Name <adresse>' oder nackte Adresse, ohne
    Header-Kodierung."""
    return "%s <%s>" % (name, adresse) if name else adresse


def header_wert(eintraege):
    """RFC-konformer Header aus Anzeige-Strings: jeder Eintrag einzeln geparst und mit
    formataddr kodiert. Noetig, weil ein Header wie 'Juerg Mueller <j@x.ch>' mit echten Umlauten
    als Ganzes zu einem einzigen encoded-word wird, Adresse inklusive, und die Mail dann keinen
    gueltigen Empfaenger mehr traegt."""
    teile = []
    for e in eintraege:
        for n, a in parse_adressen(e):
            teile.append(formataddr((n, a)))
    return ", ".join(teile)
