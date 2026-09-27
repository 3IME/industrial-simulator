# Registre des décisions architecturales (ADR)

Chaque décision non triviale est consignée ici : contexte, décision, conséquences. Une ADR n'est jamais modifiée : elle est remplacée par une nouvelle qui la référence.

---

## ADR-001 — Cœur de simulation en GDScript, dans le projet Godot

* **Date** : 2026-09-27 (Phase 0)
* **Contexte** : le projet vise Godot 4.x ; le cahier des charges indique que « GDScript est probablement le choix le plus simple » pour faire vivre l'usine virtuelle. Une alternative était d'implémenter le cœur (modèle I/O, moteur, Modbus) dans un backend séparé (.NET ou Delphi) et de n'utiliser Godot que pour le rendu.
* **Décision** : le cœur de simulation (`simulator/io`, `simulator/simulation`, `simulator/machines`) est écrit en GDScript, en classes `RefCounted` sans aucune dépendance aux `Node`/scènes. Il s'exécute et se teste en headless (`godot --headless --script`).
* **Conséquences** : une seule stack à maintenir au démarrage ; tests sans éditeur ; l'extraction future vers un backend reste possible car la couche communication est isolée derrière le contrat `PlcLink` et le modèle I/O est sérialisable en JSON.

## ADR-002 — Runner de tests maison, sans addon

* **Date** : 2026-09-27 (Phase 0)
* **Contexte** : il faut des tests automatisés en Phase 0. GUT et gdUnit4 sont de bonnes solutions mais ajoutent un addon tiers au premier commit du projet.
* **Décision** : mini-framework d'assertions (`simulator/tests/test_framework.gd`) + runner `SceneTree` (`run_tests.gd`), zéro dépendance. Code de sortie = nombre d'échecs (0 = succès).
* **Conséquences** : CI trivial (une commande). Si le besoin apparaît (mocks, rapports, parallélisation), migration vers GUT/gdUnit4 documentée par une nouvelle ADR — les fichiers de test seront peu nombreux à convertir.

## ADR-003 — Backend séparé différé

* **Date** : 2026-09-27 (Phase 0)
* **Contexte** : le cahier des charges mentionne un backend (`.Core`, `.Modbus`, `.OpcUa`, `.Api`) et une option Delphi « lorsque cela apporte un avantage clair ». Rien dans les phases 1 à 5 ne l'exige : le simulateur Godot peut porter lui-même le serveur Modbus.
* **Décision** : le dossier `backend/` est créé avec un README de placeholder, sans code. Un backend ne sera ajouté que lorsqu'un avantage clair sera démontré (ex. : serveur OPC UA, API REST multi-clients, SCADA).
* **Conséquences** : moins de moving parts maintenant ; la structure du dépôt reste prête à l'accueillir ; décision réversible.

## ADR-004 — Adresses canoniques IEC 61131-3, projection Modbus configurable

* **Date** : 2026-09-27 (Phase 0)
* **Contexte** : il faut un adressage stable, lisible par automaticiens, indépendant du protocole. Modbus n'a que 4 zones numériques (coils, discrete inputs, input registers, holding registers).
* **Décision** : les points d'E/S portent une adresse canonique au format IEC 61131-3 (`%IX0.0`, `%QX0.1`, `%IW0`, `%QW0`). La projection vers les zones Modbus (offsets) sera une table de conversion configurable, documentée en Phase 2.
* **Conséquences** : le mapping JSON reste stable même si la disposition Modbus change ; l'ajout d'OPC UA plus tard n'imposera pas de renommer les variables.

## ADR-005 — Frontières par contrats duck-typés

* **Date** : 2026-09-27 (Phase 0)
* **Contexte** : GDScript n'a pas d'interfaces natives ; il faut pourtant isoler strictement machines/communication/moteur.
* **Décision** : les frontières sont des contrats documentés dans ARCHITECTURE.md (`Machine`, `PlcLink`), vérifiés par les tests. Les appels sont conditionnés par `has_method()` côté moteur.
* **Conséquences** : aucun couplage dur ; n'importe quel objet respectant le contrat est accepté (y compris les fakes de test). Une future annotation `@abstract` ou des classes de base pourront durcir le contrat sans casser l'existant.

## ADR-006 — Moteur déterministe, temps injecté

* **Date** : 2026-09-27 (Phase 0)
* **Contexte** : un cycle de simulation doit être reproductible au pas près pour déboguer un automate ; les tests ont besoin de résultats exacts.
* **Décision** : `SimulationEngine.step(dt)` reçoit le pas de temps en paramètre ; aucun appel à l'horloge OS dans le cœur (les horodatages des points d'E/S acceptent un temps injecté). `advance(secondes, dt)` exécute n pas pour les tests. Le pilotage temps réel (accumulation) arrivera en Phase 5 via un `Node` Godot.
* **Conséquences** : déterminisme complet en headless ; le timestep deviendra configurable (scène/JSON) sans toucher au moteur.

## ADR-007 — Licence MIT

* **Date** : 2026-09-27 (Phase 0)
* **Contexte** : le projet est explicitement open source ; il faut une licence compatible avec un écosystème ouvert (Godot est MIT).
* **Décision** : MIT.
* **Conséquences** : adoption facile, y compris en formation. Réversible avant les premières contributions externes si la communauté en décide autrement.

## ADR-008 — Godot 4.7.2 comme version de référence

* **Date** : 2026-09-27 (Phase 0)
* **Contexte** : Godot 4.x évolue vite ; les projets Godot ne sont pas toujours transposables entre versions majeures/mineures.
* **Décision** : la version de référence est **Godot 4.7.2 stable** (édition standard). Le binaire console peut être posé dans `tools/godot/` (ignoré par git) ; les scripts de test utilisent `GODOT_BIN` ou ce chemin, sinon `godot` du PATH.
* **Conséquences** : environnement reproductible pour tous les contributeurs ; montée de version = décision explicite + ADR + passage des tests.

## ADR-009 — Définition d'usine déclarative JSON + registre de types de machines

* **Date** : 2026-09-27 (Phase 1)
* **Contexte** : il faut pouvoir décrire une usine (machines, paramètres, mapping, timestep) sans écrire de code, et ajouter de nouveaux types de machines (Phases 6-11) sans toucher au moteur ni au chargeur.
* **Décision** : `FactoryBuilder` (`simulator/simulation/factory_builder.gd`) construit moteur + table d'E/S + machines depuis un JSON (`simulator/config/factory.json`). Les types de machines sont référencés dans un registre (`MACHINE_TYPES`) : ajouter une machine = sa classe (contrat machine) + une entrée au registre. Les adresses des points sont écrasées par celles du mapping JSON ; les paramètres numériques sont validés strictement par chaque machine (`configure()`).
* **Conséquences** : les erreurs de définition sont détectées à la construction avec un message explicite (retour `{ok: false, error}`) ; le même fichier alimente la future scène 3D et l'éditeur (Phase 6) ; limite connue actuelle : les ids `sensor_entry`/`sensor_exit` du convoyeur ne sont pas préfixés par l'id machine, une usine à deux convoyeurs est donc rejetée (correction prévue avec les machines multiples).

## ADR-010 — Horloge simulée injectée + watchdog de qualité

* **Date** : 2026-09-27 (Phase 1)
* **Contexte** : l'horodatage des points d'E/S par l'horloge OS rendait les snapshots non reproductibles ; et la notion de qualité (`GOOD/BAD/UNCERTAIN`) exigée par le cahier des charges n'avait pas de mécanisme concret.
* **Décision** : le moteur tient une horloge simulée (`sim_time_usec`, avance de `round(dt × 10⁶)` par pas) et l'injecte dans la table (`IoTable.clock_usec`) : toute écriture non horodatée utilise cette horloge. Le moteur applique en outre un watchdog paramétrable (`input_timeout_usec`) : au temps 1b du cycle, toute **entrée** non rafraîchie depuis ce délai est marquée `BAD` ; une réécriture la repasse `GOOD`. Les sorties (écrites par le PLC) ne sont pas concernées.
* **Conséquences** : snapshots et horodatages déterministes ; le PLC (Phase 3) pourra détecter un capteur mort via la qualité, comme sur une vraie installation ; le coût par cycle reste négligeable (parcours des seules entrées).
