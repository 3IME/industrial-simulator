# Docker

Recette **testée le 2026-09-29** pour exécuter le runtime OpenPLC v3 en conteneur (voir [le guide de branchement](../plc/openplc/README.md)).

## Image utilisée

`tuttas/openplc_v3` (communautaire, basée sur le dépôt officiel OpenPLC_v3) — l'installation officielle « OpenPLC Runtime for Windows » via Cygwin est fragile ; l'image Docker est reproductible.

## Démarrage

```bash
docker run -d --name openplc \
  -p 127.0.0.1:8080:8080 \
  -p 127.0.0.1:15050:502 \
  tuttas/openplc_v3
```

* `8080` → interface web (login par défaut `openplc`/`openplc`).
* `15050` → serveur Modbus **d'OpenPLC lui-même** (son image %I/%Q), utile pour inspecter ce que le programme voit (`plc/mappings/conveyor_openplc.md`).

## Configurer

Tout se fait dans l'interface web (programme ST, slave device « simulateur », Start PLC) — pas-à-pas complet dans [plc/openplc/README.md](../plc/openplc/README.md). Les points Docker spécifiques :

1. **Le slave device doit pointer vers une IPv4 du poste hôte** (ex. l'adresse LAN), pas `host.docker.internal` : sur les Docker Desktop récents ce nom ne résout qu'en IPv6, que le libmodus d'OpenPLC ne gère pas (`Connection failed ... Invalid argument`).
2. **Baud rate 9600** même en TCP (sinon division par zéro : le runtime meurt de « Floating point exception » dès la connexion).
3. Le simulateur écoute sur **1502** (OpenPLC garde le 502).

## Pérenniser / nettoyer

```bash
docker stop openplc      # arreter
docker start openplc     # reprendre (programme et slave device conserves)
docker rm -f openplc     # detruire (l'etat interne est perdu : revoir le guide)
```

À terme (Phases 5+) : une image du simulateur headless pour la CI, et un `docker-compose.yml` simulatant les deux bouts.
