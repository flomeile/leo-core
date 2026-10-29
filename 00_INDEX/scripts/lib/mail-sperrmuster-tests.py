r"""Regressionsreihe für mail_sperrmuster.py (Regel 7a von gmail-senden.py, seit Leo Core 4.10).

Aufruf: python 00_INDEX\scripts\lib\mail-sperrmuster-tests.py   (Exit 0 = alle Fälle grün)
Die Schlüssel sind zusammengesetzt, damit eine Sperre beim Commit diese Datei nicht als Leck liest.
"""

import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")
from mail_sperrmuster import finde_zugangsdaten, finde_kennnummern, formatiere_ohne_fund

X = "aB3dE5fG7hJ9kL1mN2pQ4rS6tU8vW0xY"
HART = [
    ("sk-" + "ant-api03-" + X, "Anthropic-Schlüssel"),
    ("gh" + "p_" + X + "1234", "GitHub-Token"),
    ("github" + "_pat_" + X, "GitHub-Token"),
    ("AK" + "IAIOSFODNN7EXAMPLE", "AWS-Schlüssel"),
    ("-----BEGIN " + "OPENSSH PRIVATE KEY-----", "privater Schlüssel"),
    ("ya" + "29." + X, "Google-Zugriffstoken"),
    ("1/" + "/0" + X, "Google-Refresh-Token"),
    ('{"refresh' + '_token": "abc"}', "Anmeldedatei (Token-Feld)"),
]
MARKIERT = [
    ("Karte 4111 1111 1111 1111 bitte belasten", "Kartennummer"),
    ("Karte 5555555555554444", "Kartennummer"),
    ("AHV 756.9217.0769.85", "AHV-Nummer"),
    ("IBAN CH93 0076 2011 6238 5295 7 bei der Bank", "IBAN"),
    ("IBAN DE89370400440532013000", "IBAN"),
    ("Schlüssel 0123456789abcdef0123456789abcdef01234567 im Log", "möglicher API-Schlüssel (40 Hex-Zeichen)"),
]
FREI = [
    "Erklärung: Anthropic-Schlüssel beginnen mit sk-" + "ant- und sind geheim.",
    "Ruf mich an: +49 30 1234 5678",
    "Treffpunkt am 14.03.2027 um 10:30, Rechnung 2027-0042, Commit 1a2b3c4d",
    "Preis EUR 1'299.00 für zwei Velos, Seriennummer 1234567890",
    "UID CHE-123.456.789 MWST",
    "AHV 756.9217.0769.86 (falsche Prüfziffer)",
    "Karte 4111 1111 1111 1112 (falsche Prüfziffer)",
    "IBAN CH93 0076 2011 6238 5295 8 (falsche Prüfziffer)",
    "Mitgliedsnummer 1111111111111111",
]

fehler = []
for text, art in HART:
    t = finde_zugangsdaten([("Text", text)])
    if not any(a == art for _, a, _ in t):
        fehler.append("HART verfehlt: %s erwartet in %r, bekam %r" % (art, text[:30], formatiere_ohne_fund(t)))
for text, art in MARKIERT:
    t = finde_kennnummern([("Text", text)])
    if not any(a == art for _, a, _ in t):
        fehler.append("MARKIERT verfehlt: %s erwartet in %r, bekam %r" % (art, text, formatiere_ohne_fund(t)))
    if finde_zugangsdaten([("Text", text)]):
        fehler.append("MARKIERT fälschlich hart: %r" % text)
for text in FREI:
    t = finde_zugangsdaten([("Text", text)]) + finde_kennnummern([("Text", text)])
    if t:
        fehler.append("FREI fälschlich getroffen: %r -> %r" % (text, formatiere_ohne_fund(t)))
# Die Meldung ohne Wert darf den Wert nie enthalten
geheim = "sk-" + "ant-api03-" + X
if geheim in " ".join(formatiere_ohne_fund(finde_zugangsdaten([("Text", geheim)]))):
    fehler.append("formatiere_ohne_fund gibt den Wert preis")
# Die IBAN wird ohne das Folgewort markiert
t = finde_kennnummern([("Text", "IBAN CH93 0076 2011 6238 5295 7 BEI")])
if not t or t[0][2] != "CH93 0076 2011 6238 5295 7":
    fehler.append("IBAN-Kürzung falsch: %r" % [f for _, _, f in t])

gesamt = len(HART) + len(MARKIERT) + len(FREI) + 2
print("%d Fälle, %d Fehler" % (gesamt, len(fehler)))
for f in fehler:
    print("  " + f)
sys.exit(1 if fehler else 0)
