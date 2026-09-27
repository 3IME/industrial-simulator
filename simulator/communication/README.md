# Couche communication

Cette couche isole le cœur de simulation des protocoles industriels.

## Contrat `PlcLink`

Toute implémentation fournit deux méthodes (voir ARCHITECTURE.md) :

* `publish_inputs(io)` — rend les entrées disponibles pour le PLC ;
* `pull_outputs(io)` — récupère les sorties écrites par le PLC.

## Implémentations

* `null_plc_link.gd` — **NullPlcLink** (Phase 0) : ne fait rien ; permet au cycle de tourner sans automate (et aux tests de simuler des PLC en fake).
* `modbus/` — **Phase 2** : serveur Modbus TCP (esclave) exposant coils / discrete inputs / input registers / holding registers, projetés depuis les adresses `%` via le mapping JSON.

Le cœur de simulation ne connaît que le contrat : ajouter OPC UA (Phase 8) n'impactera ni le moteur, ni les machines.
