# Architecture

## Vue d'ensemble

Industrial Simulator sépare strictement l'usine virtuelle de la logique d'automatisme. La simulation 3D n'expose **jamais** de logique PLC : elle expose des entrées/sorties industrielles abstraites, que lit et écrit un automate externe.

```
┌─────────────────────────────────────────────┐
│ Godot 4 — rendu 3D, HUD, (futur) éditeur    │  simulator/scenes, simulator/ui
├─────────────────────────────────────────────┤
│ Simulation Engine — cycle déterministe      │  simulator/simulation
├─────────────────────────────────────────────┤
│ Industrial Model — machines, capteurs       │  simulator/machines
├─────────────────────────────────────────────┤
│ I/O Abstraction Layer — table d'E/S         │  simulator/io
├─────────────────────────────────────────────┤
│ Communication Layer — contrat PlcLink       │  simulator/communication
│ (Phase 2 : serveur Modbus TCP)              │
├─────────────────────────────────────────────┤
│ PLC externe — OpenPLC, SoftPLC, automate    │  hors du simulateur
└─────────────────────────────────────────────┘
```

Règles absolues :

* **Le moteur 3D ne connaît pas OpenPLC.** Il ne connaît que la table d'E/S.
* **OpenPLC ne connaît pas Godot.** Il ne voit qu'un esclave Modbus TCP.
* **La logique d'automatisme (ladder, Structured Text…) vit dans le PLC**, pas en GDScript.

## Modules

| Module | Rôle | Dépend de |
|---|---|---|
| `simulator/io` | Modèle d'E/S abstrait : `IoPoint`, `IoTable`, `IoMapping` | rien |
| `simulator/simulation` | `SimulationEngine` : le cycle en 6 temps, timestep fixe | rien (reçoit tout par injection) |
| `simulator/machines` | Machines virtuelles logiques (`Conveyor`, puis vérins, moteurs…) | `io` |
| `simulator/communication` | Contrat `PlcLink` + implémentations (`NullPlcLink`, puis Modbus TCP) | `io` (contrat uniquement) |
| `simulator/scenes`, `simulator/ui` | Rendu Godot, HUD — Phase 5 | cœur, en lecture d'état |
| `plc/` | Programmes OpenPLC, mappings — Phase 3 | rien (projet séparé) |
| `backend/` | Différé — voir ADR-003 | — |

Le cœur (`io`, `simulation`, `machines`) n'utilise que des `RefCounted` : aucun `Node`, aucune scène, aucun rendu. Il est donc exécutable et testable en headless, et pourrait être porté tel quel dans un autre runtime.

## Modèle I/O

Un point d'E/S (`IoPoint`) porte :

* `id` — identifiant unique (ex. `sensor_entry`, `conveyor_01.run`)
* `io_name` — nom lisible
* `io_type` — `DIGITAL_INPUT`, `DIGITAL_OUTPUT`, `ANALOG_INPUT`, `ANALOG_OUTPUT`, `COUNTER`, `ENCODER`
* `value` — `bool` pour les points digitaux, `float` pour les analogiques, `int` pour compteurs/encodeurs
* `unit` — unité éventuelle (`m/s`, `%`…)
* `address` — adresse industrielle canonique IEC 61131-3 (`%IX0.0`, `%QX0.1`, `%IW0`, `%QW0`…)
* `description`, `quality` (`GOOD`/`BAD`/`UNCERTAIN`), `timestamp_usec`

Sens des points (vue PLC) :

* **entrées PLC** (le PLC les lit) : `DIGITAL_INPUT`, `ANALOG_INPUT`, `COUNTER`, `ENCODER`
* **sorties PLC** (le PLC les écrit) : `DIGITAL_OUTPUT`, `ANALOG_OUTPUT`

La `IoTable` est le registre en mémoire de tous les points, indexée par `id` et par `address`. Elle fournit des instantanés sérialisables (`to_dicts()`) qui alimenteront l'API REST et le WebSocket (Phases ultérieures).

## Mapping PLC ↔ simulation

Le fichier JSON (ex. [`simulator/config/conveyor_io_map.json`](simulator/config/conveyor_io_map.json)) associe adresses PLC et variables de simulation :

```json
{ "address": "%IX0.0", "variable": "sensor_entry" },
{ "address": "%QX0.0", "variable": "conveyor_01.run" }
```

Le mapping se modifie **sans toucher au code**. Les adresses `%IX/%QX/%IW/%QW` sont la référence canonique du projet ; leur projection vers les zones Modbus (coils, discrete inputs, input registers, holding registers) sera une table de conversion configurable documentée en Phase 2 (ADR-004).

## Contrats d'interfaces

GDScript n'a pas d'interfaces natives : les frontières sont des **contrats duck-typés**, documentés ici et vérifiés par les tests.

**Machine** (objet passé à `SimulationEngine.machines`) :

| Méthode | Obligatoire | Rôle |
|---|---|---|
| `apply_outputs(io)` | oui | lit ses commandes dans la table (sorties PLC) |
| `update(dt)` | oui | avance sa physique/logique d'un pas `dt` |
| `refresh_sensors(dt)` | recommandé | recalcule l'état brut de ses capteurs |
| `scan_inputs(io)` | recommandé | publie capteurs et états dans la table (entrées PLC) |

**PlcLink** (lien vers l'automate, injecté dans le moteur) :

| Méthode | Rôle |
|---|---|
| `publish_inputs(io)` | transmet les entrées au PLC (Phase 2 : côté Modbus, le PLC les lit) |
| `pull_outputs(io)` | récupère les sorties écrites par le PLC |

## Cycle de simulation

Résumé (détail et justification : [docs/simulation/simulation_cycle.md](docs/simulation/simulation_cycle.md)) :

1. `scan_inputs` — lecture des entrées de simulation dans la table d'E/S
2. `publish_inputs` — publication des entrées vers le PLC
3. `pull_outputs` — réception des sorties du PLC
4. `apply_outputs` — application des sorties aux actionneurs
5. `update(dt)` — mise à jour de la simulation
6. `refresh_sensors(dt)` — mise à jour des capteurs (lus au cycle suivant)

Le moteur est **déterministe** : pas de temps fixe, pas d'horloge OS dans le cœur (l'horloge temps réel arrivera en Phase 5 via un `Node` Godot qui pilote `step()`).

## Exemple de flux complet (cible Phase 3)

```
boîte atteint le capteur d'entrée
  → sensor_entry = true (refresh_sensors, fin de cycle N)
  → scan_inputs (cycle N+1) : %IX0.0 = true
  → OpenPLC (ladder : si %IX0.0 alors %QX0.0)
  → %QX0.0 = true → conveyor_01.run (apply_outputs)
  → le convoyeur démarre, la boîte avance
  → sensor_exit = true → %QX0.0 = false → le convoyeur s'arrête
```

## Extension future

L'architecture est prévue pour ajouter sans refonte : vérins, variateurs, vannes, réservoirs, capteurs analogiques, encodeurs, robots, stations, palettes, AGV, ascenseurs, tri, sécurité machine, arrêts d'urgence, défauts, alarmes, HMI, SCADA, recettes, historique, événements, injection de pannes. Chaque machine est un composant autonome implémentant le contrat ci-dessus — jamais une classe monolithique.

## Décisions architecturales

Registre complet : [docs/architecture/decisions.md](docs/architecture/decisions.md). Synthèse :

* **ADR-001** — cœur de simulation en GDScript dans le projet Godot.
* **ADR-002** — tests via un runner headless maison, sans addon externe.
* **ADR-003** — backend séparé différé jusqu'à avantage démontré.
* **ADR-004** — adresses canoniques IEC 61131-3, projection Modbus configurable.
* **ADR-005** — frontières par contrats duck-typés + tests.
* **ADR-006** — moteur déterministe, temps injecté.
* **ADR-007** — licence MIT.
* **ADR-008** — Godot 4.7.2 est la version de référence.
