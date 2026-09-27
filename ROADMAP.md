# Feuille de route

Le projet avance **par phases**, dans l'ordre. Une phase n'est commencée que lorsque la précédente est terminée et testée.

| Phase | Objectif | Statut |
|---|---|---|
| 0 | Architecture + squelette du projet | ✅ Terminée |
| 1 | I/O Engine complet (compteurs, encodeurs, qualité, snapshot) | ✅ Terminée |
| 2 | Modbus TCP (serveur esclave dans le simulateur) | ⬜ |
| 3 | OpenPLC : programme, mapping, documentation de bout en bout | ⬜ |
| 4 | Convoyeur + capteurs + boîte (logique industrielle complète) | ⬜ |
| 5 | Simulation 3D (sol, convoyeur, boîte, caméra, HUD) | ⬜ |
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
* **Phase 2 — Modbus TCP** : serveur Modbus TCP (esclave) dans `simulator/communication`, zones coils / discrete inputs / input registers / holding registers, projection configurable depuis les adresses `%`, tests automatisés (client de test Modbus).
* **Phase 3 — OpenPLC** : programme minimal (`si sensor_entry alors conveyor`, `si sensor_exit alors stop`), mapping, documentation pas-à-pas (installation OpenPLC, connexion au simulateur).
* **Phase 4 — Convoyeur + capteurs** : machine virtuelle complète avec boîte, capteurs d'entrée/sortie, comportement logique validé de bout en bout.
* **Phase 5 — Simulation 3D** : sol, convoyeur, boîte, capteurs rendus en 3D, caméra contrôlable, HUD (RUN/STOP, états des capteurs, vitesse).
* **Phase 6+** : éditeur de scènes, machines supplémentaires, OPC UA, HMI/SCADA, injection de pannes, robots/AGV, plateforme de formation.

## Premier milestone — critères d'acceptation

Le premier milestone n'est atteint que lorsque **toutes** les cases suivantes sont validées :

| # | Critère | État |
|---|---|---|
| 1 | Le projet se charge dans Godot | ✅ (Phase 0, scène minimale) |
| 2 | Un convoyeur virtuel existe (logique) | ✅ (Phase 0, headless) |
| 3 | Deux capteurs existent (logique) | ✅ (Phase 0, headless) |
| 4 | Le moteur d'I/O fonctionne | ✅ (Phase 0, testé) |
| 5 | Modbus TCP fonctionne | ⬜ (Phase 2) |
| 6 | OpenPLC lit les capteurs | ⬜ (Phase 3) |
| 7 | OpenPLC commande le convoyeur | ⬜ (Phase 3) |
| 8 | Une boîte virtuelle se déplace en 3D | ⬜ (Phase 5) |
| 9 | Le capteur d'entrée détecte la boîte, le PLC démarre le convoyeur | ⬜ (Phase 3/5) |
| 10 | Le capteur de sortie détecte la boîte, le PLC arrête le convoyeur | ⬜ (Phase 3/5) |
| 11 | Les tests automatisés passent | ✅ (Phase 0, headless) |
| 12 | La documentation explique comment reproduire le test | ✅ (ce fichier + docs/, complété en Phase 3) |

> Remarque : le cœur logique (moteur, convoyeur, capteurs, cycle complet simulé avec un faux PLC) est déjà démontré par les tests de la Phase 0 — voir `simulator/tests/test_simulation_engine.gd`. Il ne manque que Modbus TCP, OpenPLC et le rendu 3D.
