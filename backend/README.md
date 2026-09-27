# Backend (différé)

Ce dossier est un **placeholder** : aucun code backend n'existe en Phase 0.

Décision : le cœur de simulation vit dans le projet Godot (ADR-001). Un backend séparé (.NET ou Delphi) ne sera ajouté que lorsqu'un avantage clair sera démontré — par exemple un serveur OPC UA, une API REST multi-clients ou une passerelle SCADA (ADR-003).

La structure envisagée à ce moment-là reste celle du cahier des charges :

```
backend/
├── IndustrialSimulator.Core/     modèle I/O (miroir du modèle GDScript, JSON-compatible)
├── IndustrialSimulator.Modbus/
├── IndustrialSimulator.OpcUa/
├── IndustrialSimulator.Api/
└── IndustrialSimulator.Tests/
```
