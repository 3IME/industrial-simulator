# Couche communication

Cette couche isole le cœur de simulation des protocoles industriels.

## Contrat `PlcLink`

Toute implémentation fournit (voir ARCHITECTURE.md) :

* `publish_inputs(io)` — rend les entrées disponibles pour le PLC ;
* `pull_outputs(io)` — récupère les sorties écrites par le PLC ;
* `poll()` *(optionnel)* — traite le réseau ; appelé par le moteur au temps 0 du cycle.

## Implémentations

* `null_plc_link.gd` — **NullPlcLink** : ne fait rien ; le cycle tourne sans automate (tests, mise au point).
* `modbus_tcp_server.gd` — **ModbusTcpServer** (Phase 2) : esclave Modbus TCP en GDScript pur — FC 01/02/03/04/05/06/0F/10, exceptions 01/02/03, quatre banques mémoire (image d'E/S).
* `modbus_address_map.gd` — **ModbusAddressMap** : projection des adresses `%IEC` du mapping JSON vers coils / discrete inputs / input registers / holding registers.
* `modbus_plc_link.gd` — **ModbusPlcLink** : pont entre le contrat `PlcLink` et le serveur — synchronisation des banques aux temps 2/3 du cycle, mise à l'échelle des registres (×100 par défaut, surcharge `"scale"` par entrée).

Documentation complète : [docs/protocols/modbus_tcp.md](../../docs/protocols/modbus_tcp.md).

Le cœur de simulation ne connaît que le contrat : ajouter OPC UA (Phase 8) n'impactera ni le moteur, ni les machines.
