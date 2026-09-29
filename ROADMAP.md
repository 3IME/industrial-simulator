# Feuille de route

Le projet avance **par phases**, dans l'ordre. Une phase n'est commencée que lorsque la précédente est terminée et testée.

| Phase | Objectif | Statut |
|---|---|---|
| 0 | Architecture + squelette du projet | ✅ Terminée |
| 1 | I/O Engine complet (compteurs, encodeurs, qualité, snapshot) | ✅ Terminée |
| 2 | Modbus TCP (serveur esclave dans le simulateur) | ✅ Terminée |
| 3 | OpenPLC : programme, mapping, documentation de bout en bout | ✅ Terminée (test réel) |
| 4 | Convoyeur + capteurs + boîte (logique industrielle complète) | ✅ Terminée (cycle continu réel) |
| 5 | Simulation 3D (sol, convoyeur, boîte, caméra, HUD) | ✅ Terminée |
| 6 | Éditeur de scènes | ⬜ |
| 7 | Machines supplémentaires (vérins, variateurs, vannes…) | ⬜ |
| 8 | OPC UA | ⬜ |
| 9 | HMI / SCADA | ⬜ |
| 10 | Injection de pannes | ⬜ |
| 11 | Robots / AGV | ⬜ |
| 12 | Plateforme de formation industrielle | ⬜ |

## Détail des phases

* **Phase 0 — Architecture + squelette** : structure du dépôt, documentation fondatrice, modèle I/O de base (`IoPoint`, `IoTable`, `IoMapping`), `SimulationEngine` minimal déterministe, machine logique `Conveyor`, tests unitaires headless, squelette Godot (scène minimale). *Aucune 3D réelle, pas d'OPC UA, pas de robots.*
* **Phase 1 — I/O Engine** *(terminée)* : compteurs d'événements (`EdgeCounter`) exposés en points `COUNTER` sur le convoyeur, encodeur de bande (`ENCODER`), RAZ des compteurs par commande PLC, horloge simulée injectée dans la table (horodatages déterministes), watchdog de qualité (`input_timeout_usec` : entrées non rafraîchies → `BAD`), définition d'usine déclarative JSON via `FactoryBuilder` (registre de types, adresses écrasées par le mapping, timestep configurable), suite de tests de contrat automatique pour toute machine du registre.
* **Phase 2 — Modbus TCP** *(terminée)* : serveur **esclave Modbus TCP** en GDScript pur, zéro dépendance — FC 01/02/03/04/05/06/0F/10 + exceptions 01/02/03 ; projection automatique des adresses `%IEC` vers coils / discrete inputs / input registers / holding registers depuis le mapping JSON (`ModbusAddressMap`) ; image d'E/S synchronisée au cycle (`ModbusPlcLink`, seules les sorties réellement écrites par le maître sont rapatriées) ; échelle ×100 par défaut pour les analogiques, surcharge par entrée ; lanceur headless `scripts/run_simulator.bat` pour brancher un vrai client ; tests sur sockets réelles en boucle locale, y compris la chaîne complète capteur → Modbus → client → convoyeur. Documentation : [docs/protocols/modbus_tcp.md](docs/protocols/modbus_tcp.md).
* **Phase 3 — OpenPLC** *(terminée, validée avec un automate réel le 2026-09-29)* : programme ST `conveyor.st` (variables localisées %I/%Q100, mémoire SET/RESET), guide de branchement complet avec les quatre pièges OpenPLC v3 (programme IEC complet, bande %I/%Q100, baud rate obligatoire, IPv4 pour libmodbus — ADR-012), mapping détaillé, runtime Docker documenté, client de répétition générale sans OpenPLC (`examples/simple_conveyor/rehearsal_client.py`). **Le cycle complet capteur → Modbus → OpenPLC → convoyeur → capteur → arrêt a été observé avec un vrai OpenPLC v3.**
* **Phase 4 — Convoyeur + capteurs** *(terminée, validée avec OpenPLC réel)* : programme `conveyor_cycle.st` — **cycle continu** avec temporisations TON dans le PLC (arrêt 2 s au capteur de sortie, évacuation de la boîte, attente de la suivante) ; observé en boucle réelle sur plusieurs cycles. Cinquième piège matiec documenté (ADR-012) : blocs `VAR` séparés pour variables `AT` et variables internes.
* **Phase 5 — Simulation 3D** *(terminée)* : scène Godot construite depuis le JSON de l'usine (sol, convoyeur avec châssis, boîte, capteurs à lampes), caméra orbitale (clic + molette), HUD temps réel (capteurs, commandes, vitesse, position, encodeur, trafic Modbus), pilotage temps réel à pas fixe, Modbus actif au lancement, touche B pour poser une boîte, capture automatique `--capture` (preuve visuelle : `docs/assets/scene_3d_phase5.png`). Le rendu ne fait que **lire** l'état (ADR-013).
* **Phase 6+** : éditeur de scènes, machines supplémentaires, OPC UA, HMI/SCADA, injection de pannes, robots/AGV, plateforme de formation.

## Premier milestone — critères d'acceptation

Le premier milestone n'est atteint que lorsque **toutes** les cases suivantes sont validées :

| # | Critère | État |
|---|---|---|
| 1 | Le projet se charge dans Godot | ✅ (Phase 0, scène minimale) |
| 2 | Un convoyeur virtuel existe (logique) | ✅ (Phase 0, headless) |
| 3 | Deux capteurs existent (logique) | ✅ (Phase 0, headless) |
| 4 | Le moteur d'I/O fonctionne | ✅ (Phase 0, testé) |
| 5 | Modbus TCP fonctionne | ✅ (Phase 2, testé sur sockets réelles) |
| 6 | OpenPLC lit les capteurs | ✅ (Phase 3, test réel) |
| 7 | OpenPLC commande le convoyeur | ✅ (Phase 3, test réel) |
| 8 | Une boîte virtuelle se déplace en 3D | ✅ (Phase 5, capture + scène validées) |
| 9 | Le capteur d'entrée détecte la boîte, le PLC démarre le convoyeur | ✅ (Phase 3, test réel) |
| 10 | Le capteur de sortie détecte la boîte, le PLC arrête le convoyeur | ✅ (Phase 3, test réel) |
| 11 | Les tests automatisés passent | ✅ (Phase 0, headless) |
| 12 | La documentation explique comment reproduire le test | ✅ (ce fichier + docs/, complété en Phase 3) |

> **Premier milestone : ATTEINT le 2026-09-29** — les 12 critères sont validés, dont huit sur un vrai OpenPLC v3 (cycle observé en continu) et le rendu 3D (capture vérifiée + scène testée headless).
