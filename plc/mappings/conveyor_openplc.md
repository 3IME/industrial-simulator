# Mapping Modbus du prototype convoyeur

Correspondance complète entre les trois vues : adresses IEC du simulateur, zones Modbus servies par le simulateur (esclave, port 1502), et locations OpenPLC (slave device « simulateur »).

## Entrées lues par le PLC (FC02 — discrete inputs)

| Simulateur (%IEC) | Zone Modbus | Variable | Location OpenPLC | Signification |
|---|---|---|---|---|
| %IX0.0 | DI 0 | `sensor_entry` | %IX100.0 | capteur d'entrée (boîte présente) |
| %IX0.1 | DI 1 | `sensor_exit` | %IX100.1 | capteur de sortie |
| %IX1.0 | DI 8 | `conveyor_01.running` | %IX101.0 | convoyeur en marche |

## Entrées analogiques lues par le PLC (FC04 — input registers)

| Simulateur (%IEC) | Zone Modbus | Variable | Location OpenPLC | Échelle |
|---|---|---|---|---|
| %IW0 | IR 0 | `conveyor_01.speed` | %IW100 | ×100 (m/s) |
| %IW1 | IR 1 | `conveyor_01.position` | %IW101 | ×100 (m, −1 sans boîte) |
| %IW2 | IR 2 | `conveyor_01.counter_entry` | %IW102 | ×1 |
| %IW3 | IR 3 | `conveyor_01.counter_exit` | %IW103 | ×1 |
| %IW4 | IR 4 | `conveyor_01.belt_encoder` | %IW104 | ×1 (impulsions) |

## Sorties écrites par le PLC (FC05/FC15 — coils ; FC06/FC10 — holding registers)

| Simulateur (%IEC) | Zone Modbus | Variable | Location OpenPLC | Signification |
|---|---|---|---|---|
| %QX0.0 | coil 0 | `conveyor_01.run` | %QX100.0 | commande de marche |
| %QX0.1 | coil 1 | `conveyor_01.stop` | %QX100.1 | arrêt prioritaire |
| %QX1.0 | coil 8 | `conveyor_01.reset_counters` | %QX101.0 | RAZ compteurs (front montant) |
| %QW0 | HR 0 | `conveyor_01.speed_command` | %QW100 | ×100 (% de vitesse) |

## Rappel des conventions

* Le **simulateur** parle en adresses `%IEC` basées à 0 (%IX0.0 = DI 0) — projection automatique depuis `simulator/config/conveyor_io_map.json` (ADR-011).
* **OpenPLC** décale toute les E/S des devices distants de **100** : DI 0 → %IX100.0, IR 0 → %IW100, coil 0 → %QX100.0 (`updateBuffersIn_MB`, bande basse réservée à son propre serveur Modbus).
* Un seul slave device est déclaré ; avec plusieurs devices, les locations se suivent séquentiellement dans l'ordre de déclaration (d'où l'intérêt de garder un device = une machine quand possible).
