# Brancher OpenPLC sur le simulateur — guide pas-à-pas

Ce guide reproduit exactement le test validé le 2026-09-29 : un **vrai runtime OpenPLC v3** contrôle le convoyeur virtuel via Modbus TCP. La logique d'automatisme vit dans OpenPLC (Structured Text), le simulateur n'expose que des E/S.

```
boîte sur le capteur d'entrée → %IX100.0 = 1 ─┐
                                              ├─ OpenPLC (ST, tâche 50 ms)
sortie coil 0 ← %QX100.0 = 1 ◄────────────────┘
     │
     ▼
convoyeur.run → la boîte avance → capteur de sortie → %IX100.1 = 1 → arrêt
```

## 0. Prérequis

* le simulateur (ce dépôt) avec Godot 4.7.2 ;
* OpenPLC v3 : soit via **Docker** (testé, voir `docker/README.md`), soit installé nativement (Cygwin/WSL). L'« OpenPLC Runtime for Windows » du site officiel installe le runtime sous Cygwin — le paquet doit être complet (`Runtime/bin` rempli) ;
* le programme : [`conveyor.st`](conveyor.st) (ce dossier).

## 1. Lancer le simulateur (port 1502)

OpenPLC occupe déjà le port 502 avec son propre serveur Modbus : le simulateur écoute donc sur **1502**.

```bat
scripts\run_simulator.bat --port=1502 --box=12
```

Une boîte est posée sur le capteur d'entrée. Le rapport périodique affiche l'état (`entry=1 exit=0 | run=0 ...`).

## 2. Ouvrir l'interface d'OpenPLC

* Docker : `http://127.0.0.1:8080` — identifiants par défaut `openplc` / `openplc`.
* Le dashboard doit afficher « Stopped ».

## 3. Charger le programme

1. Page **Programs** → *Upload program* → sélectionner un des deux programmes de ce dossier :
   * [`conveyor.st`](conveyor.st) — logique minimale du cahier des charges (la boîte s'immobilise au capteur de sortie) ;
   * [`conveyor_cycle.st`](conveyor_cycle.st) — **cycle continu** : arrêt 2 s au capteur de sortie, évacuation de la boîte, attente de la suivante (temporisations TON dans le PLC).
2. La compilation démarre automatiquement ; attendre « Compilation finished successfully » (une trentaine de secondes en Docker).

### Pourquoi ce fichier a cette forme (pièges)

* **Programme IEC complet exigé** : `PROGRAM prog0 ... END_PROGRAM` + `CONFIGURATION Config0 ... END_CONFIGURATION` — des instructions ST nues sont refusées par matiec (`unknown syntax error`).
* **Variables localisées par `AT`** : la syntaxe directe `IF %IX0.0` n'est pas acceptée par ce matiec ; on déclare `sensor_entry AT %IX100.0 : BOOL;`.
* **Blocs `VAR` séparés** : variables `AT` et variables internes (instances TON, drapeaux) ne peuvent pas partager un même bloc `VAR` (`invalid located variable declaration`) — voir `conveyor_cycle.st` pour la structure à deux blocs.
* **%I/%Q100, pas %I/%Q0** : OpenPLC range les E/S des *devices distants* à partir de **%IX100.0 / %QX100.0** (voir `updateBuffersIn_MB()` dans `core/modbus_master.cpp`). La bande basse %I0/%Q0 est l'image de son propre serveur Modbus. C'est LE piège principal : un programme sur %IX0.0 compile et tourne, mais ne voit jamais le simulateur.

## 4. Déclarer le simulateur comme slave device

Page **Slave Devices** → *Add slave device* :

| Champ | Valeur |
|---|---|
| Device Name | `simulateur` |
| Device Type | Generic Modbus TCP Device |
| Slave ID | `1` (l'unit id du serveur du simulateur) |
| IP Address | voir remarque réseau ci-dessous |
| IP Port | `1502` |
| **Baud Rate** | **`9600`** (voir piège ci-dessous) |

Puis les zones (correspondance exacte dans [../mappings/conveyor_openplc.md](../mappings/conveyor_openplc.md)) :

| Zone du formulaire | Start | Size | Rôle |
|---|---|---|---|
| Discrete Inputs (lire) | 0 | 2 | `sensor_entry`, `sensor_exit` → %IX100.0/.1 |
| Coils (écrire) | 0 | 1 | `conveyor_01.run` ← %QX100.0 |
| Input Registers (lire) | 0 | 5 | vitesse, position, compteurs, encodeur → %IW100..104 |
| Holding Registers (écrire) | 0 | 0 | (non utilisé par la logique minimale) |

### Piège du baud rate (crash SIGFPE)

Même pour un device TCP, le maître Modbus d'OpenPLC **divise par le baud rate** (`(10⁹×28)/rtu_baud` dans sa boucle de scrutation). Un baud vide → division par zéro → **« Floating point exception », le runtime meurt silencieusement** dès que la connexion réussit. Mettre 9600.

### Remarque réseau (Docker)

Avec Docker Desktop récent, `host.docker.internal` peut ne résoudre qu'en **IPv6**, que le libmodbus d'OpenPLC ne gère pas (« Connection failed ... Invalid argument », sans jamais réessayer en IPv4). Utiliser une **IPv4 du poste hôte** (l'adresse LAN, ex. `192.168.1.17`, ou l'IP de `vEthernet (WSL)`). En installation native, `127.0.0.1` convient.

## 5. Démarrer et vérifier

Bouton **Start PLC**. Le runtime logue `Connected to MB device simulateur`, puis tout se joue en silence (aucun log = tout va bien). Dans la console du simulateur :

```
[t=224.4s] entry=1 exit=0 | run=0 running=0 pos=0.30 | coil0=0
[t=226.4s] entry=0 exit=0 | run=1 running=1 speed=0.50 pos=0.81 | coil0=1   ← OpenPLC démarre
[t=228.4s] entry=0 exit=1 | run=0 running=0 pos=1.80 | coil0=0              ← OpenPLC arrête
```

La boîte reste posée sur le capteur de sortie (la logique minimale s'arrête là) : c'est le comportement du cahier des charges. Vérification croisée possible dans la page **Monitoring** d'OpenPLC (`%IX100.0`, `%QX100.0`).

## 6. En cas de problème

| Symptôme | Cause probable |
|---|---|
| `Connection failed ... Invalid argument` | `host.docker.internal` en IPv6 → mettre une IPv4 d'hôte |
| Le runtime disparaît aussitôt démarré | baud rate vide → SIGFPE → mettre 9600 |
| Connecté, aucune erreur, convoyeur immobile | programme sur %I0/%Q0 → utiliser %I/%Q100 |
| `unknown syntax error` à la compilation | instructions ST sans `PROGRAM`/`CONFIGURATION`, ou `%IX0.0` direct au lieu d'une variable `AT` |
| Le port 8080 ne répond plus | port publié perdu après un échec d'allocation → recréer le conteneur |

## 7. Arrêter

* Simulateur : `Ctrl+C` dans sa console.
* OpenPLC (Docker) : bouton *Stop PLC* dans l'UI, puis `docker stop openplc`.
