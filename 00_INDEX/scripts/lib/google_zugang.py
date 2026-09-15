r"""Gemeinsame Google-Anmeldung (OAuth) für alle Skripte der Google-Anbindung:
gmail-senden.py (Gmail API, senden und für Antworten lesen) und google-sheets-fetch.py
(Drive API, Sheet als xlsx exportieren). Ein Token, ein Ort, eine Scope-Liste: Ein Skript, das
mit einem Token ohne seinen Scope startet, würde eine Neuanmeldung verlangen; deshalb tragen
alle Skripte dieselbe Liste und melden sich über dieses Modul an.

Einrichtung Schritt für Schritt: 10_System\Google-Anbindung.md (Cloud-Projekt, Drive API und
Gmail API, Nutzertyp, OAuth-Client vom Typ Desktop-App, erste Anmeldung mit --auth).

Dateien im Benutzerprofil, bewusst nicht im Repo (Zugangsdaten gehören nicht nach Git):
  %USERPROFILE%\.leo-google-client.json   OAuth-Client aus der Google-Cloud-Konsole (heruntergeladen)
  %USERPROFILE%\.leo-google-token.json    wird bei der ersten Anmeldung angelegt und danach erneuert

Erste Anmeldung (öffnet den Browser):
  python google-sheets-fetch.py --auth      oder      python gmail-senden.py --auth
"""

import os
import pathlib

SCOPES = ["https://www.googleapis.com/auth/drive.readonly",
          "https://www.googleapis.com/auth/gmail.send",
          "https://www.googleapis.com/auth/gmail.readonly"]

HOME = pathlib.Path(os.environ.get("USERPROFILE") or pathlib.Path.home())
CLIENT_FILE = HOME / ".leo-google-client.json"
TOKEN_FILE = HOME / ".leo-google-token.json"

PIP_HINWEIS = "pip install google-auth-oauthlib google-api-python-client"


class KeineAnmeldung(Exception):
    """Es gibt kein gültiges Token und der Lauf darf keinen Browser öffnen."""


def hole_credentials(interaktiv=False, anmelde_hinweis="python google-sheets-fetch.py --auth"):
    """Gültige Credentials oder KeineAnmeldung. interaktiv=True öffnet bei Bedarf den Browser
    (nur mit --auth aus einer bedienten Sitzung); ein kopfloser Lauf bekommt stattdessen die
    Meldung, welcher Befehl einmal zu laufen hat."""
    try:
        from google.oauth2.credentials import Credentials
        from google.auth.transport.requests import Request
    except ImportError:
        raise KeineAnmeldung("Python-Bibliotheken fehlen. Einmalig: " + PIP_HINWEIS)

    creds = None
    if TOKEN_FILE.exists():
        try:
            creds = Credentials.from_authorized_user_file(str(TOKEN_FILE), SCOPES)
        except Exception:
            creds = None

    if creds and creds.valid:
        return creds

    if creds and creds.expired and creds.refresh_token:
        try:
            creds.refresh(Request())
            TOKEN_FILE.write_text(creds.to_json(), encoding="utf-8")
            return creds
        except Exception as e:
            if not interaktiv:
                raise KeineAnmeldung("Das gespeicherte Google-Token lässt sich nicht erneuern (%s). Einmal: %s" % (e, anmelde_hinweis))

    if not interaktiv:
        raise KeineAnmeldung("Keine gültige Google-Anmeldung. Einmal: %s" % anmelde_hinweis)

    if not CLIENT_FILE.exists():
        raise KeineAnmeldung("Die Datei %s fehlt. Sie kommt aus der Google-Cloud-Konsole (OAuth-Client, Typ Desktop-App); "
                             "Anleitung in 10_System\\Google-Anbindung.md." % CLIENT_FILE)

    from google_auth_oauthlib.flow import InstalledAppFlow
    flow = InstalledAppFlow.from_client_secrets_file(str(CLIENT_FILE), SCOPES)
    creds = flow.run_local_server(port=0, prompt="consent")
    TOKEN_FILE.write_text(creds.to_json(), encoding="utf-8")
    print("Anmeldung gespeichert: %s" % TOKEN_FILE)
    return creds


def dienst(name, version, creds):
    """Ein Google-API-Dienst ohne Discovery-Cache (der Cache schreibt sonst Dateien ins Profil)."""
    from googleapiclient.discovery import build
    return build(name, version, credentials=creds, cache_discovery=False)
