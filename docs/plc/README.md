# Documentation PLC / OpenPLC

## Phase 3 — terminée et validée avec un automate réel

Le guide complet de branchement (programme ST, slave device, pièges, vérification, dépannage) : **[plc/openplc/README.md](../../plc/openplc/README.md)**.

* Programme : [`plc/openplc/conveyor.st`](../../plc/openplc/conveyor.st)
* Mapping complet : [`plc/mappings/conveyor_openplc.md`](../../plc/mappings/conveyor_openplc.md)
* Scénario de référence : [`examples/simple_conveyor/`](../../examples/simple_conveyor/) (avec client de répétition générale sans OpenPLC)
* Runtime Docker testé : [`docker/README.md`](../docker/README.md)

Trace du test réel (OpenPLC v3, 2026-09-29) :

```
[t=224.4s] entry=1 | run=0 | pos=0.30   <- boite sur le capteur d'entree
[t=226.4s] entry=0 | run=1 speed=0.50   <- le PLC demarre le convoyeur
[t=228.4s] exit=1  | run=0 pos=1.80     <- le PLC arrete au capteur de sortie
```
