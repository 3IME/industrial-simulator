# GODOT_INSTRUCTIONS_TRANSSTOCKEUR.md

## Objectif

Ce document explique à une IA / développeur Godot comment importer et utiliser le fichier GLB généré par Blender pour piloter un système automatisé de stockage de tôles.

Le GLB représente un magasin vertical de tôles inspiré des architectures industrielles de type KASTO :

- longueur : 90 m ;
- hauteur : 15 m ;
- 10 positions/stations ;
- 22 niveaux ;
- cassettes ;
- tôles ;
- deux rails au sol ;
- transstockeur ;
- chariot vertical ;
- deux fourches ;
- éléments de sécurité ;
- matériaux industriels et métalliques ;
- animation Blender de démonstration facultative.

## 1. Principe fondamental

**Blender fournit le modèle 3D. Godot fournit la logique et le comportement.**

Blender sert à :
- créer la géométrie ;
- créer les matériaux ;
- positionner les racks ;
- créer les cassettes et tôles ;
- créer le transstockeur ;
- fournir éventuellement une animation de démonstration.

Godot doit gérer :
- position actuelle du transstockeur ;
- station cible ;
- niveau cible ;
- déplacement X ;
- déplacement Z ;
- fourches ;
- prise et dépose ;
- inventaire ;
- états ;
- sécurité ;
- commandes utilisateur ;
- ordonnancement des tâches.

**Ne pas utiliser l'animation Blender comme système principal de commande.** Elle sert uniquement de démonstration ou de référence visuelle.

## 2. Import du GLB

Placer le fichier par exemple ici :

```text
res://models/rack.glb
```

Créer une scène Godot qui encapsule le modèle :

```text
rack
└── Model
    └── GLB
```

Éviter de modifier directement le fichier GLB. La logique doit être ajoutée autour du modèle dans Godot.

## 3. Hiérarchie importante du transstockeur

Le GLB V3 contient notamment :

```text
TRANSSTOCKEUR_ROOT
│
├── CRANE_CHASSIS
├── CRANE_LOWER_FRAME
├── CRANE_MAST
├── CRANE_MAST_REAR
├── CRANE_TOP
├── CRANE_WHEEL_0
├── CRANE_WHEEL_1
├── CRANE_WHEEL_2
├── CRANE_WHEEL_3
├── CRANE_MOTOR
│
└── CARRIAGE_Z
    ├── VERTICAL_CARRIAGE
    ├── CARRIAGE_MECHANICAL_BOX
    ├── FORK_LEFT
    ├── FORK_RIGHT
    ├── FORK_TIP_LEFT
    └── FORK_TIP_RIGHT
```

Ces noms doivent être considérés comme des identifiants stables.

## 4. Axes du système

Le modèle Blender utilise :

```text
X = longueur de l'installation
Y = profondeur / largeur
Z = hauteur
```

Donc :

```text
TRANSSTOCKEUR_ROOT.position.x → déplacement horizontal
CARRIAGE_Z.position.z          → déplacement vertical
```

Le déplacement X doit être appliqué à `TRANSSTOCKEUR_ROOT`.

Le déplacement Z doit être appliqué à `CARRIAGE_Z`.

Ne pas déplacer `CARRIAGE_Z` en X pour commander le transstockeur.

## 5. Stations

La V3 possède 10 positions principales sur 90 m :

```text
STATION_0
STATION_1
STATION_2
STATION_3
STATION_4
STATION_5
STATION_6
STATION_7
STATION_8
STATION_9
```

Les positions approximatives sont :

```text
0  = 2.5 m
1  ≈ 12.22 m
2  ≈ 21.94 m
3  ≈ 31.67 m
4  ≈ 41.39 m
5  ≈ 51.11 m
6  ≈ 60.83 m
7  ≈ 70.56 m
8  ≈ 80.28 m
9  = 87.5 m
```

Ces valeurs ne doivent pas être codées en dur dans le système final. Il est préférable de créer des `Marker3D` dans Godot.

Exemple :

```text
Stations
├── Station_00
├── Station_01
├── ...
└── Station_09
```

Le contrôleur peut alors utiliser :

```gdscript
var target_x = stations[station_id].global_position.x
```

## 6. Niveaux

Il y a 22 niveaux :

```text
Level_00
Level_01
...
Level_21
```

Créer idéalement :

```text
Levels
├── Level_00
├── Level_01
├── ...
└── Level_21
```

Chaque niveau peut être un `Marker3D` contenant la hauteur cible.

Le contrôleur utilise :

```gdscript
var target_z = levels[level_id].position.z
```

## 7. Machine à états

Utiliser une machine à états pour empêcher les mouvements incompatibles.

Exemple :

```gdscript
enum CraneState:
    IDLE
    MOVING_X
    MOVING_Z
    ALIGNING
    EXTENDING_FORKS
    RETRACTING_FORKS
    PICKING
    CARRYING
    DROPPING
    ERROR
```

Le transstockeur ne doit pas démarrer une nouvelle opération mécanique tant que l'opération précédente n'est pas terminée.

## 8. Déplacement X

Le déplacement horizontal doit être progressif.

Ne pas téléporter le transstockeur avec :

```gdscript
position.x = target_x
```

Utiliser une interpolation ou une `Tween`.

Exemple conceptuel :

```gdscript
func move_to_station(station_id: int):
    var target_x = stations[station_id].global_position.x
    current_state = CraneState.MOVING_X

    await move_crane_x(target_x)

    current_station = station_id
    current_state = CraneState.IDLE
```

La vitesse doit être paramétrable :

```gdscript
@export var speed_x: float = 5.0
```

## 9. Déplacement Z

`CARRIAGE_Z` est enfant de `TRANSSTOCKEUR_ROOT`.

Le contrôleur doit modifier sa position locale en Z :

```gdscript
CARRIAGE_Z.position.z = target_z
```

Pour un mouvement normal, utiliser une interpolation ou une `Tween`, pas une téléportation.

Exemple :

```gdscript
func move_to_level(level_id: int):
    var target_z = levels[level_id].position.z
    current_state = CraneState.MOVING_Z

    await move_carriage_z(target_z)

    current_level = level_id
    current_state = CraneState.IDLE
```

Vitesse paramétrable :

```gdscript
@export var speed_z: float = 3.0
```

## 10. Fourches

Les fourches sont :

```text
FORK_LEFT
FORK_RIGHT
FORK_TIP_LEFT
FORK_TIP_RIGHT
```

Elles doivent être considérées comme un ensemble mécanique.

Créer un contrôleur de fourches avec au minimum :

```text
RETRACTED
EXTENDING
EXTENDED
RETRACTING
```

Les transformations doivent être locales à `CARRIAGE_Z`.

Ne pas déplacer les fourches en coordonnées globales.

## 11. LOAD_SOCKET

Créer dans Godot :

```text
CARRIAGE_Z
└── LOAD_SOCKET
```

Ce `Node3D` représente l'emplacement de la cassette lorsqu'elle est transportée.

Lorsqu'une cassette est prise, elle peut être rattachée au socket :

```gdscript
cassette.reparent(load_socket)
cassette.position = Vector3.ZERO
```

Ainsi elle suit automatiquement le transstockeur.

## 12. Cycle de prise / dépôt

Le cycle normal est :

```text
IDLE
 ↓
MOVE_TO_STATION
 ↓
MOVE_TO_LEVEL
 ↓
ALIGN
 ↓
EXTEND_FORKS
 ↓
PICK_CASSETTE
 ↓
RETRACT_FORKS
 ↓
MOVE_TO_DESTINATION
 ↓
MOVE_TO_DESTINATION_LEVEL
 ↓
ALIGN
 ↓
EXTEND_FORKS
 ↓
DROP_CASSETTE
 ↓
RETRACT_FORKS
 ↓
IDLE
```

## 13. Prise d'une cassette

Avant une prise :

1. vérifier que la station existe ;
2. vérifier que le niveau existe ;
3. vérifier qu'une cassette est présente ;
4. aller à la station ;
5. aller au niveau ;
6. vérifier l'alignement ;
7. sortir les fourches ;
8. rattacher la cassette au `LOAD_SOCKET` ;
9. rétracter les fourches.

Exemple conceptuel :

```gdscript
cassette.reparent(load_socket)
cassette.position = Vector3.ZERO
```

## 14. Dépose

Pour déposer :

1. aller à la station cible ;
2. aller au niveau cible ;
3. vérifier l'alignement ;
4. sortir les fourches ;
5. retirer la cassette du `LOAD_SOCKET` ;
6. la rattacher à son emplacement de stockage ;
7. rétracter les fourches ;
8. mettre à jour l'inventaire.

## 15. Inventaire logique

Ne pas utiliser directement la géométrie 3D comme base de données.

Créer une représentation logique indépendante.

Exemple :

```gdscript
class_name StorageSlot

var station_id: int
var level_id: int
var occupied: bool
var material_id: String
var thickness: float
var width: float
var length: float
```

Exemple de donnée :

```text
Station = 4
Level = 12
Occupied = true
Material = S235
Thickness = 5.0 mm
Width = 1500 mm
Length = 3000 mm
```

## 16. Architecture Godot recommandée

```text
SheetMetalStorage
│
├── StorageManager
├── CraneController
├── InventoryManager
├── JobManager
├── SafetyController
│
├── Model
│   └── GLB
│
├── Stations
│
├── Levels
│
└── UI
```

Responsabilités :

### StorageManager
Gestion des emplacements.

### CraneController
Déplacement du transstockeur et des fourches.

### InventoryManager
Gestion des tôles et cassettes.

### JobManager
Gestion des ordres `GET`, `PUT`, `MOVE`.

### SafetyController
Limites, collisions, arrêt d'urgence et interverrouillages.

## 17. Exemple d'ordre utilisateur

Une demande peut être représentée par :

```gdscript
{
    "type": "GET",
    "station": 4,
    "level": 12
}
```

Le `JobManager` transforme cette demande en séquence :

```text
GET Station 4 Level 12

1. vérifier l'emplacement
2. aller station 4
3. aller niveau 12
4. aligner
5. sortir les fourches
6. prendre la cassette
7. rentrer les fourches
8. aller à la zone de dépose
9. déposer
10. terminer
```

## 18. Sécurité

Le système doit empêcher :

- de dépasser la longueur de l'installation ;
- de dépasser les 22 niveaux ;
- de descendre sous le niveau minimum ;
- de sortir les fourches hors d'une position autorisée ;
- de prendre une cassette inexistante ;
- de déposer sur un emplacement occupé ;
- de déplacer le chariot pendant une opération incompatible ;
- de déplacer le transstockeur pendant une opération mécanique incompatible ;
- d'exécuter deux ordres incompatibles simultanément.

Tolérance recommandée :

```gdscript
@export var position_tolerance := 0.03
```

Vérification :

```gdscript
if abs(crane_x - target_x) > position_tolerance:
    return
```

Même principe pour Z.

## 19. Animation Blender

Le GLB peut contenir l'animation de démonstration générée dans Blender.

Cette animation ne doit pas piloter le système final.

Elle peut servir à :

- visualiser le fonctionnement ;
- tester le modèle ;
- présenter la machine ;
- vérifier les mouvements.

Lorsque le contrôleur Godot est actif, il doit avoir le contrôle des transformations.

## 20. Nomenclature à conserver

Ne pas renommer ces nœuds sans adapter le contrôleur :

```text
TRANSSTOCKEUR_ROOT
CARRIAGE_Z
FORK_LEFT
FORK_RIGHT
FORK_TIP_LEFT
FORK_TIP_RIGHT
CRANE_CHASSIS
CRANE_MAST
CRANE_TOP
```

Nomenclature recommandée :

```text
STATION_00
STATION_01
...
STATION_09

LEVEL_00
LEVEL_01
...
LEVEL_21

CASSETTE_00_00
CASSETTE_00_01
...
```

Une cassette peut suivre le format :

```text
CASSETTE_<STATION>_<LEVEL>
```

Exemple :

```text
CASSETTE_04_12
```

= station 4, niveau 12.

## 21. Priorité de développement

Développer dans cet ordre :

### Phase 1
Importer le GLB.

### Phase 2
Identifier les nœuds :

```text
TRANSSTOCKEUR_ROOT
CARRIAGE_Z
FORK_LEFT
FORK_RIGHT
```

### Phase 3
Faire fonctionner le déplacement X.

### Phase 4
Ajouter le déplacement Z.

### Phase 5
Ajouter les fourches.

### Phase 6
Ajouter prise / dépose.

### Phase 7
Ajouter l'inventaire.

### Phase 8
Ajouter l'interface utilisateur.

### Phase 9
Ajouter l'ordonnancement automatique.

### Phase 10
Ajouter capteurs, sécurité, collisions et arrêt d'urgence.

## 22. Consigne principale pour l'IA Godot

**Ne pas reconstruire le transstockeur en code.**

Le GLB est la source visuelle du système.

L'IA doit :

1. importer le GLB ;
2. rechercher les nœuds par leur nom ;
3. créer les contrôleurs Godot autour du GLB ;
4. contrôler `TRANSSTOCKEUR_ROOT` pour X ;
5. contrôler `CARRIAGE_Z` pour Z ;
6. contrôler les fourches localement ;
7. créer `LOAD_SOCKET` ;
8. créer les stations et niveaux logiques ;
9. créer l'inventaire ;
10. utiliser une machine à états ;
11. utiliser des mouvements progressifs ;
12. empêcher les mouvements dangereux ;
13. conserver une séparation stricte entre logique et modèle 3D.

## 23. Objectif final

L'utilisateur doit pouvoir demander :

```text
Prends la tôle de la station 4 niveau 12.
```

Godot doit alors exécuter automatiquement :

```text
Station 4
    ↓
Niveau 12
    ↓
Alignement
    ↓
Sortie des fourches
    ↓
Prise cassette
    ↓
Rétraction
    ↓
Transport
    ↓
Station de destination
    ↓
Niveau de destination
    ↓
Sortie des fourches
    ↓
Dépose
    ↓
Rétraction
    ↓
Fin de tâche
```

Le résultat recherché est une simulation crédible d'un véritable transstockeur industriel :

```text
POSITION → ALIGNEMENT → MOUVEMENT → PRISE → TRANSPORT → DÉPOSE
```

## 24. Résumé

```text
GLB
 │
 ├── Modèle usine
 ├── Racks
 ├── Cassettes
 ├── Tôles
 └── Transstockeur
      │
      ├── TRANSSTOCKEUR_ROOT
      │      └── déplacement X
      │
      └── CARRIAGE_Z
             └── déplacement Z
                    │
                    ├── FORK_LEFT
                    ├── FORK_RIGHT
                    │
                    └── LOAD_SOCKET
                           └── Cassette transportée

Godot
 │
 ├── StorageManager
 ├── CraneController
 ├── InventoryManager
 ├── JobManager
 ├── SafetyController
 └── UI
```

**Le GLB fournit le corps du système. Godot fournit le cerveau du système.**
