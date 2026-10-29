r"""Muster für das Mail-Sperrnetz von gmail-senden.py (Regel 7a, seit Leo Core 4.10).

Die Wortliste mail-sperrbegriffe.txt trifft Ziffernfolgen und Schlüssel strukturell nicht: Ein API-Schlüssel
oder eine Kartennummer ist kein Wort, das man auf eine Liste setzen kann. Dafür steht dieses Modul.

Zwei Klassen:
  ZUGANGSDATEN   Schlüssel und Tokens mit anbieterüblicher Form. Sperren hart, im Freigabefenster auch mit
                 Häkchen nicht sendbar, in einer Routine Abbruch. Es gibt keinen legitimen Grund, einen
                 Zugangsschlüssel per Mail zu verschicken.
  KENNNUMMERN    Kartennummer (Luhn), AHV-Nummer (EAN-13-Prüfziffer), IBAN (Modulo 97) und 40 Hex-Zeichen
                 (Form vieler API-Schlüssel). Wie Sperrbegriffe: rot markiert, Senden erst nach dem Häkchen,
                 weil etwa die eigene IBAN auf einer Rechnung legitim ist; in einer Routine Abbruch.

Jede Funktion nimmt material = [(wo, text), ...] und gibt [(wo, art, fund), ...]. Der Fund selbst gehört
nur ins Fenster (zum Markieren), nie in eine Meldung, die eine Session liest: dafür formatiere_ohne_fund.
Regressionsreihe: mail-sperrmuster-tests.py im selben Ordner.
"""

import re

ZUGANGSDATEN = [
    ("Anthropic-Schlüssel", re.compile(r"sk-ant-[A-Za-z0-9_-]{10,}")),
    ("OpenAI-Schlüssel", re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9]{20,}")),
    ("GitHub-Token", re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})")),
    ("AWS-Schlüssel", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("privater Schlüssel", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("Google-Zugriffstoken", re.compile(r"\bya29\.[A-Za-z0-9_-]{20,}")),
    ("Google-Refresh-Token", re.compile(r"\b1//0[A-Za-z0-9_-]{20,}")),
    ("Slack-Token", re.compile(r"\bxox[abpr]-[A-Za-z0-9-]{10,}")),
    ("Anmeldedatei (Token-Feld)", re.compile(r"\"(?:refresh_token|client_secret|access_token|api_key)\"\s*:", re.IGNORECASE)),
]

_KARTE = re.compile(r"(?<![\d.])(?:\d[ -]?){12,18}\d(?![\d])")
_AHV = re.compile(r"(?<!\d)756[. ]?\d{4}[. ]?\d{4}[. ]?\d{2}(?!\d)")
_IBAN = re.compile(r"\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]){11,30}")
_HEX40 = re.compile(r"(?<![0-9a-fA-F])[0-9a-f]{40}(?![0-9a-fA-F])")


def _luhn(ziffern):
    summe = 0
    for i, z in enumerate(reversed(ziffern)):
        n = int(z)
        if i % 2 == 1:
            n *= 2
            if n > 9:
                n -= 9
        summe += n
    return summe % 10 == 0


def _ean13(ziffern):
    s = sum(int(z) * (3 if i % 2 else 1) for i, z in enumerate(ziffern[:12]))
    return (10 - s % 10) % 10 == int(ziffern[12])


def _iban_gueltig(kompakt):
    if not (15 <= len(kompakt) <= 34):
        return False
    umgestellt = kompakt[4:] + kompakt[:4]
    try:
        return int("".join(str(int(c, 36)) for c in umgestellt)) % 97 == 1
    except ValueError:
        return False


def _iban_im(kandidat):
    """Der Kandidat kann gierig ein Folgewort mitnehmen; die längste gültige Kürzung zählt."""
    kompakt = kandidat.replace(" ", "")
    for laenge in range(len(kompakt), 14, -1):
        if _iban_gueltig(kompakt[:laenge]):
            # auf die Länge im Original (mit Leerzeichen) zurückrechnen
            n, i = 0, 0
            while n < laenge:
                if kandidat[i] != " ":
                    n += 1
                i += 1
            return kandidat[:i]
    return None


def finde_zugangsdaten(material):
    treffer = []
    for wo, text in material:
        for art, muster in ZUGANGSDATEN:
            for m in muster.finditer(text or ""):
                treffer.append((wo, art, m.group(0)))
    return treffer


def finde_kennnummern(material):
    treffer = []
    for wo, text in material:
        text = text or ""
        ahv_stellen = set()
        for m in _AHV.finditer(text):
            ziffern = re.sub(r"\D", "", m.group(0))
            if _ean13(ziffern):
                treffer.append((wo, "AHV-Nummer", m.group(0)))
                ahv_stellen.add(m.start())
        for m in _KARTE.finditer(text):
            ziffern = re.sub(r"\D", "", m.group(0))
            if (13 <= len(ziffern) <= 19 and ziffern[0] in "23456" and len(set(ziffern)) > 1
                    and _luhn(ziffern) and m.start() not in ahv_stellen):
                treffer.append((wo, "Kartennummer", m.group(0).strip()))
        for m in _IBAN.finditer(text):
            fund = _iban_im(m.group(0))
            if fund:
                treffer.append((wo, "IBAN", fund))
        for m in _HEX40.finditer(text):
            treffer.append((wo, "möglicher API-Schlüssel (40 Hex-Zeichen)", m.group(0)))
    return treffer


def formatiere_ohne_fund(treffer):
    """Für Meldungen, die eine Session oder ein Protokoll liest: Ort und Art, nie der Wert."""
    return ["%s: %s" % (wo, art) for wo, art, _ in treffer]
