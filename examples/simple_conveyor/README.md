# Exemple : simple_conveyor

Le scénario de référence du premier milestone, complet et testé.

## Composition

* **Simulateur** : usine `simulator/config/factory.json` — un convoyeur (`conveyor_01`), deux capteurs photo-électriques, une boîte, compteurs, encodeur.
* **Automate** : [`plc/openplc/conveyor.st`](../../plc/openplc/conveyor.st) — logique ST « capteur d'entrée → marche, capteur de sortie → arrêt », exécutée par OpenPLC v3 (voir [le guide](../../plc/openplc/README.md)).
* **Mapping** : [`plc/mappings/conveyor_openplc.md`](../../plc/mappings/conveyor_openplc.md).

## Reproduire le test validé

1. Simulateur : `scripts\run_simulator.bat --port=1502 --box=12`
2. OpenPLC v3 (Docker : voir [`docker/README.md`](../../docker/README.md)) → charger `conveyor.st`, déclarer le slave device (guide, section 4), **Start PLC**.
3. Observer la console du simulateur : la boîte détectée à l'entrée déclenche la marche, le capteur de sortie arrête le convoyeur (boîte immobilisée à ~1,8 m, encodeur ~1500 impulsions).

## Sans OpenPLC : répétition générale

Le script [`rehearsal_client.py`](rehearsal_client.py) rejoue **exactement** la même logique en client Modbus (aucune dépendance) :

```
python examples/simple_conveyor/rehearsal_client.py 127.0.0.1 1502
```

Si la répétition générale fait tourner le convoyeur mais pas OpenPLC, le problème est dans la configuration OpenPLC — voir le tableau de dépannage du guide.

## Trace de référence (test réel du 2026-09-29, OpenPLC v3 sous Docker)

```
[t=224.4s] entry=1 exit=0 | run=0 running=0 speed=0.00 pos=0.30 m | coil0=0
[t=226.4s] entry=0 exit=0 | run=1 running=1 speed=0.50 pos=0.81 m | coil0=1   <- OpenPLC demarre
[t=228.4s] entry=0 exit=1 | run=0 running=0 speed=0.00 pos=1.80 m | coil0=0   <- OpenPLC arrete
```
