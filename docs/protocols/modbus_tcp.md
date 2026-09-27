# Modbus TCP

Le simulateur embarque un **esclave (serveur) Modbus TCP** écrit en GDScript pur, sans aucune dépendance (ADR-011). Un PLC externe — OpenPLC, SoftPLC, automate physique, outil de test — s'y connecte en **client Modbus** et commande l'usine virtuelle.

## Démarrage rapide

```bash
# Windows
scripts\run_simulator.bat

# Linux / Git Bash
scripts/run_simulator.sh
```

L'usine définie dans `simulator/config/factory.json` démarre avec le serveur Modbus à l'écoute (port **502** par défaut, unit id **1**). Une boîte est posée sur le capteur d'entrée du convoyeur. Options utiles : `--port=1502` (port alternatif), `--box=8` (une nouvelle boite toutes les 8 s), `--no-spawn`.

## Les quatre zones Modbus

Le serveur expose quatre banques mémoire (« image d'E/S ») :

| Zone Modbus | Sens (vue PLC) | Adresses IEC projetées | Offset Modbus |
|---|---|---|---|
| **coils** (FC01/05/0F) | écritures du PLC | `%QX<octet>.<bit>` | `octet * 8 + bit` |
| **discrete inputs** (FC02) | lectures du PLC | `%IX<octet>.<bit>` | `octet * 8 + bit` |
| **input registers** (FC04) | lectures du PLC | `%IW<n>` | `n` |
| **holding registers** (FC03/06/10) | écritures du PLC | `%QW<n>` | `n` |

Exemples : `%IX0.0` → discrete input 0 (capteur d'entrée), `%QX0.0` → coil 0 (commande de marche), `%IW2` → input register 2 (compteur d'entrée), `%QW0` → holding register 0 (consigne de vitesse).

La projection est **entièrement dérivée du mapping JSON** (`simulator/config/conveyor_io_map.json`) — changer une adresse dans le mapping change l'offset Modbus, sans toucher au code.

## Table d'E/S du prototype

| Adresse | Zone / offset | Variable | Sens | Échelle |
|---|---|---|---|---|
| %IX0.0 | DI 0 | `sensor_entry` | PLC lit | booléen |
| %IX0.1 | DI 1 | `sensor_exit` | PLC lit | booléen |
| %IX1.0 | DI 8 | `conveyor_01.running` | PLC lit | booléen |
| %IW0 | IR 0 | `conveyor_01.speed` | PLC lit | ×100 (m/s → centièmes) |
| %IW1 | IR 1 | `conveyor_01.position` | PLC lit | ×100 |
| %IW2 | IR 2 | `conveyor_01.counter_entry` | PLC lit | ×1 |
| %IW3 | IR 3 | `conveyor_01.counter_exit` | PLC lit | ×1 |
| %IW4 | IR 4 | `conveyor_01.belt_encoder` | PLC lit | ×1 (impulsions) |
| %QX0.0 | coil 0 | `conveyor_01.run` | PLC écrit | booléen |
| %QX0.1 | coil 1 | `conveyor_01.stop` | PLC écrit | booléen |
| %QX1.0 | coil 8 | `conveyor_01.reset_counters` | PLC écrit | front montant |
| %QW0 | HR 0 | `conveyor_01.speed_command` | PLC écrit | ×100 (% → centièmes) |

## Mise à l'échelle des registres (16 bits)

* Points **analogiques** : `brut = round(valeur_ingénieur × échelle)`, échelle par défaut **100** (précision 0,01) ; échelle spécifiable par entrée du mapping (`"scale": 10.0`).
* **Compteurs et encodeurs** : échelle 1 (valeur directe).
* Interprétation **signée en complément à deux** à la lecture (ex. : position `-1.0` m sans boîte → brut `-100`).
* Les registres sont limités à ±32767.

## Codes fonction supportés

| FC | Fonction | Accès |
|---|---|---|
| 01 | Read Coils | lecture coils |
| 02 | Read Discrete Inputs | lecture discrete inputs |
| 03 | Read Holding Registers | lecture holding registers |
| 04 | Read Input Registers | lecture input registers |
| 05 | Write Single Coil | écriture coil |
| 06 | Write Single Register | écriture holding register |
| 0F | Write Multiple Coils | écriture coils en lot |
| 10 | Write Multiple Registers | écriture holding registers en lot |

Exceptions retournées : **01** (fonction inconnue), **02** (adresse hors banque), **03** (valeur invalide). Les requêtes avec un **unit id différent** de celui configuré ne reçoivent **aucune réponse** (comportement routeur standard).

## Synchronisation avec le cycle de simulation

Les banques forment l'image d'E/S, synchronisée à chaque cycle du moteur (voir [docs/simulation/simulation_cycle.md](../simulation/simulation_cycle.md)) :

1. **temps 0** — `poll()` : les requêtes Modbus en attente sont traitées (les écritures du PLC atterrissent dans les banques de sorties) ;
2. **temps 2** — `publish_inputs` : capteurs et états sont copiés de la table d'E/S vers les banques d'entrées (ce que le PLC lira) ;
3. **temps 3** — `pull_outputs` : **seules les sorties réellement écrites par le maître** depuis le cycle précédent sont rapatriées dans la table — une sortie jamais écrite par le PLC garde sa valeur par défaut (sémantique d'un automate réel : sortie à 0/non connectée).

Conséquence pratique : le PLC peut lire les entrées à tout moment, il voit toujours un état cohérent (celui du dernier cycle complet).

## Tester avec un client externe

Avec Python et [pymodbus](https://pymodbus.readthedocs.io/) (`pip install pymodbus`) :

```python
from pymodbus.client import ModbusTcpClient

c = ModbusTcpClient("127.0.0.1", 502)  # port du simulateur
c.connect()

# Le capteur d'entree voit la boite ?
print(c.read_discrete_inputs(0, 1, slave=1).bits[0])   # %IX0.0 -> True

# Demarrer le convoyeur (%QX0.0)
c.write_coil(0, True, slave=1)

# Vitesse reelle (%IW0) : 0.5 m/s -> 50
print(c.read_input_registers(0, 1, slave=1).registers[0])
```

Les tests automatisés (`scripts/run_tests.bat`, suite `modbus_tcp`) rejouent exactement ce scénario avec un client interne : lecture des capteurs, commande du convoyeur, consigne de vitesse, compteurs, exceptions.

## Paramètres de configuration

Dans `factory.json` :

```json
"modbus": { "port": 502, "unit_id": 1 }
```

* `port` — port d'écoute (502 par défaut ; sous 1024, certains OS exigent des privilèges, utiliser 1502 pour les tests).
* `unit_id` — identifiant d'unité Modbus (1 par défaut).
* L'adresse de bind par défaut est toutes les interfaces ; pour un usage local, le pare-feu peut afficher une demande à la première écoute — sans risque pour les tests en boucle locale.

Le serveur **n'écoute jamais au simple chargement** d'une usine : il démarre explicitement (`run_simulator`, appel explicite à `listen()`), jamais dans les tests de construction.
