# Programmes PLC

Dossier réservé à la **Phase 3** :

```
plc/
├── openplc/     programme OpenPLC du prototype (ladder / Structured Text)
├── examples/    variantes (logique ST, exemples pédagogiques)
└── mappings/    fichiers de mapping PLC ↔ simulateur
```

Rappel architectural : le programme PLC contient **toute** la logique d'automatisme. Le simulateur n'en contient aucune — il ne fait qu'exposer des E/S et simuler la physique.
