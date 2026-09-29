# Programmes PLC

Programmes d'automatisme exécutés par un **vrai PLC externe** — le simulateur n'en contient aucune logique.

```
plc/
├── openplc/           programme + guide de branchement (Phase 3, testé)
│   ├── conveyor.st    logique ST : capteur d'entree -> marche, capteur de sortie -> arret
│   └── README.md      guide pas-a-pas complet (Docker ou natif, pieges inclus)
├── examples/          variantes futures (logique ST plus riche, exemples pedagogiques)
└── mappings/          correspondances simulateur <-> Modbus <-> locations OpenPLC
    └── conveyor_openplc.md
```

Le premier programme a été **validé de bout en bout avec OpenPLC v3** (2026-09-29) : capteur virtuel → Modbus TCP → OpenPLC → moteur virtuel.
