# Machines virtuelles

Une machine est une **classe logique** `RefCounted` (jamais un `Node`) implémentant le contrat décrit dans ARCHITECTURE.md :

* `apply_outputs(io)` — lit ses commandes (sorties PLC) dans la table d'E/S ;
* `update(dt)` — avance sa logique/physique ;
* `refresh_sensors(dt)` — recalcule ses capteurs ;
* `scan_inputs(io)` — publie capteurs et états (entrées PLC).

Le rendu 3D d'une machine (Phase 5) sera un `Node3D` séparé qui **lit** son état logique — jamais l'inverse.

Machines prévues : convoyeur (Phase 0, logique), puis vérins, moteurs, variateurs, pompes, vannes, réservoirs, capteurs analogiques, encodeurs, robots, stations, palettes, AGV… (Phases 6-11).
