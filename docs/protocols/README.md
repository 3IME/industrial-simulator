# Documentation des protocoles

## Modbus TCP — Phase 2 (à venir)

Ce dossier documentera précisément :

* les **quatre zones** Modbus exposées par le simulateur (esclave) :
  * *coils* — sorties digitales écrites par le PLC (`%QX`)
  * *discrete inputs* — entrées digitales lues par le PLC (`%IX`)
  * *input registers* — entrées analogiques/compteurs lus par le PLC (`%IW`)
  * *holding registers* — sorties analogiques écrites par le PLC (`%QW`)
* la **table de projection** configurable entre adresses canoniques IEC 61131-3 et offsets Modbus (ADR-004) ;
* le port par défaut, le format des trames attendues et les tests automatisés associés.

## OPC UA — Phase 8 (à venir)

Décision d'implémentation à l'étude (backend séparé ou bibliothèque intégrée) — voir ADR-003.
