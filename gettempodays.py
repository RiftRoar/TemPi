#!/usr/bin/env python3
# coding: utf-8
"""
Script robuste pour récupérer les couleurs Tempo via l'API RTE.
Produit /var/www/html/output.txt :
  ligne1 = couleur du jour (ex: BLUE)
  ligne2 = couleur de demain (ou "NA" si pas encore publié)
"""

import sys
import requests
import json
import socket
import logging
import time
from datetime import datetime, timedelta, timezone

# Si tu veux voir les warnings HTTPS (verify=False)
logging.captureWarnings(True)

# --- CONFIG ---
TOKEN_URL = "https://digital.iservices.rte-france.com/token/oauth"
API_BASE = "https://digital.iservices.rte-france.com/open_api/tempo_like_supply_contract/v1/tempo_like_calendars"
CLIENT_ID = ''
CLIENT_SECRET = ''
OUTPUT_FILE = '/var/www/html/output.txt'
REQUEST_VERIFY = False   # mettre True si tu as les bons certificats
SLEEP_SECONDS = 900      # 15 minutes

# --- utilitaires ---
def internet_est_disponible(host="www.google.com", port=80, timeout=3):
    try:
        socket.create_connection((host, port), timeout=timeout)
        return True
    except OSError:
        return False

def iso_local_midnights_range():
    """
    Retourne (start_iso, end_iso) en ISO8601 avec offset local.
    Période = J-1 00:00:00+offset  -> J+1 00:00:00+offset
    """
    now_local = datetime.now().astimezone()
    today_midnight = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
    start = (today_midnight - timedelta(days=1))
    end = (today_midnight + timedelta(days=2))
    return start.isoformat(), end.isoformat()

def get_new_token():
    token_req_payload = {'grant_type': 'client_credentials'}
    try:
        resp = requests.post(TOKEN_URL, data=token_req_payload, verify=REQUEST_VERIFY,
                             allow_redirects=False, auth=(CLIENT_ID, CLIENT_SECRET), timeout=10)
    except Exception as e:
        print("Erreur réseau lors de la demande de token:", e, file=sys.stderr)
        raise

    if resp.status_code != 200:
        print("Failed to obtain token from the OAuth 2.0 server:", resp.status_code, resp.text, file=sys.stderr)
        sys.exit(1)

    print("Successfully obtained a new token")
    tokens = resp.json()
    return tokens.get('access_token')

# --- wait internet ---
while not internet_est_disponible():
    print("En attente de connexion Internet...")
    time.sleep(5)

token = get_new_token()

# --- boucle principale ---
while True:
    start_iso, end_iso = iso_local_midnights_range()

    test_api_url = (
        f"{API_BASE}?start_date={start_iso}&end_date={end_iso}&fallback_status=true"
    )

    print("Requête :", test_api_url)
    headers = {'Authorization': f'Bearer {token}'}

    try:
        resp = requests.get(test_api_url, headers=headers, verify=REQUEST_VERIFY, timeout=15)
    except Exception as e:
        print("Erreur réseau lors de l'appel API :", e)
        time.sleep(60)
        continue

    if resp.status_code == 401:
        print("Token invalide/expiré (401) — récupération d'un nouveau token")
        token = get_new_token()
        continue

    print("HTTP status:", resp.status_code)
    text = resp.text
    print("Réponse brute :", text)

    try:
        data = resp.json()
    except ValueError as e:
        print("Réponse non JSON :", e)
        time.sleep(SLEEP_SECONDS)
        continue

    if 'error' in data:
        print("Erreur API:", data.get('error'), data.get('error_description'))
        time.sleep(SLEEP_SECONDS)
        continue

    # --- parsing normal ---
    try:
        tempo = data['tempo_like_calendars']
        values = tempo.get('values', [])

        print("Nombre d'entrées renvoyées :", len(values))

        # Correction : on trie par date ASC
        values_sorted = sorted(values, key=lambda x: x.get("start_date", ""))

        print("Ordre trié par date :")
        for v in values_sorted:
            print(" -", v.get("start_date"), "=>", v.get("value"))

        # Aujourd’hui = avant-dernier
        # Demain = dernier
        if len(values_sorted) >= 2:
            value_today = values_sorted[-2].get("value", "NA")
            value_tomorrow = values_sorted[-1].get("value", "NA")
        elif len(values_sorted) == 1:
            value_today = values_sorted[0].get("value", "NA")
            value_tomorrow = "NA"
        else:
            value_today = "NA"
            value_tomorrow = "NA"

        print("Value ajd :", value_today)
        print("Value demain :", value_tomorrow)

        # --- ÉCRITURE FICHIER + DEBUG ---
        try:
            line_today = f"{value_today}\n"
            line_tomorrow = f"{value_tomorrow}\n"

            print("DEBUG → Contenu écrit dans le fichier :")
            print(line_today, end='')
            print(line_tomorrow, end='')

            with open(OUTPUT_FILE, 'w') as f:
                f.write(line_today)
                f.write(line_tomorrow)

        except Exception as e:
            print("Impossible d'écrire le fichier :", e)

    except KeyError as e:
        print("Erreur de parsing, clé manquante :", e)
        print("Contenu JSON :", json.dumps(data, indent=2))

    time.sleep(SLEEP_SECONDS)
