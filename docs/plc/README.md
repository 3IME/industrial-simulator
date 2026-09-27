# Documentation PLC / OpenPLC

## Phase 3 (à venir)

Ce dossier contiendra :

* le **programme OpenPLC minimal** du premier prototype :
  * `SI sensor_entry (%IX0.0) = TRUE ALORS conveyor (%QX0.0) = TRUE`
  * `SI sensor_exit (%IX0.1) = TRUE ALORS conveyor (%QX0.0) = FALSE`
* le **mapping** utilisé (également versionné dans `plc/mappings/`) ;
* les **étapes pas-à-pas** : installer OpenPLC, charger le programme, configurer l'esclave Modbus TCP du simulateur, lancer et vérifier le cycle complet ;
* la **procédure de reproduction du test** de bout en bout exigée par le premier milestone.
