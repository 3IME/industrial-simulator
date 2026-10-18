# Récupération et intégration des assets Factory IO dans IndustrialSimulator

## Contexte

J'ai un programme Godot nommé **IndustrialSimulator** situé dans :
`D:\Bidon 4\Factory IO`

J'ai une **export Unity** (format YAML texte, pas de `.unitypackage`) située dans :
`D:\Bidon 4\Assets Factory\ExportedProject`

Cette export contient :
- des meshes (YAML `--- !u!43` + fichiers `.fbx`/`.obj`/`.blend` référencés par GUID),
- des textures (`.png`, `.tga`, `.jpg`) référencées par GUID,
- des matériaux (`.mat` YAML) qui référencent des textures par GUID,
- des prefabs (`.prefab` YAML) qui référencent meshes et matériaux par GUID,
- des animations (`.anim` YAML),
- des fichiers audio (`.wav`, `.mp3`, `.ogg`),
- des fichiers `.meta` qui font le lien **GUID → chemin réel**.

## Objectif

1. **Extraire** les assets utiles (OBJ + textures + animations + audio) depuis `ExportedProject`.
2. **Les copier** dans le projet Godot `Factory IO` (dans `res://assets/imported/`).
3. **Afficher** dans l'éditeur (ou en jeu) une **fenêtre à droite** listant les OBJ texturés.
4. Permettre le **glisser/déposer** d'un OBJ depuis cette fenêtre vers la scène 3D de l'usine (placement au sol, à la position du curseur).
5. **Ne pas** inclure de DLL, de package externe, ni de commande système. Uniquement des fichiers d'assets (`.glb`, `.obj`, `.png`, `.wav`, etc.) et du code GDScript.
6. **Filtrer** plus tard les OBJ inutiles (ne pas tout garder). Pour l'instant, tout importer, mais prévoir une liste noire/`whitelist` configurable.

## Contraintes techniques

- **Godot 4.x** (GDScript uniquement).
- **Pas de DLL**, pas de plugin binaire, pas de dépendance externe.
- Les assets doivent être **copiés physiquement** dans `res://assets/imported/` en mettant 'FIO_' devant leur nom.
- Le glisser/déposer se fait **dans le jeu** (pas dans l'éditeur Godot) : une fenêtre UI à droite, une scène 3D au centre.
- Les OBJ doivent être **texturés** : chaque OBJ doit avoir son matériau `.tres` avec la texture associée.
- Les fichiers `.meta` sont la source de vérité pour résoudre les GUID.

## Ce qui a déjà été fait

- Un script Python `unity_mesh_to_obj.py` convertit les meshes YAML en `.obj` (fonctionne pour certains, mais pas tous — à améliorer si besoin).
- Un script Python `resolve_guids.py` construit un `guid_index.json` (GUID → chemin) à partir des `.meta`.
- Un fichier `resolved_references.json` liste toutes les références `{fileID, guid, type}` résolues.

## Ce qui reste à faire

### Étape 1 — Extraction automatique des assets utiles

Écrire un **script Python** (à exécuter une fois, hors Godot) qui :

1. Lit `guid_index.json`.
2. Parcourt les `.prefab` pour identifier les meshes, matériaux et textures réellement utilisés.
3. Copie les fichiers sources (`.fbx`, `.obj`, `.blend`, `.png`, `.tga`, `.jpg`, `.wav`, `.mp3`, `.ogg`, `.anim`) dans un dossier de sortie `D:\Bidon 4\Factory IO\assets\imported\`.
4. Pour chaque mesh : génère un `.obj` si nécessaire (via `unity_mesh_to_obj.py`), OU copie le `.fbx`/`.obj` source.
5. Pour chaque matériau : génère un `StandardMaterial3D` Godot (`.tres`) qui référence la texture albédo et la normal map.
6. Pour chaque animation : tente de générer un `.tres` Godot (voir plus bas).
7. Pour chaque audio : copie simplement le fichier.
8. Génère un `manifest.json` qui liste, pour chaque asset, son nom, son type, son chemin Godot, et son statut (utilisé/inutile).

### Étape 2 — Fenêtre UI de glisser/déposer

Créer une scène Godot `AssetBrowser.tscn` avec :

- Un `PanelContainer` à droite (largeur ~300 px).
- Un `ItemList` ou une `GridContainer` affichant les vignettes des OBJ.
- Chaque vignette : un `TextureRect` (aperçu 3D rendu via `SubViewport`) + un `Label` (nom).
- Un `ScrollContainer` pour naviguer.
- Un champ de recherche (filtre par nom).
- Un bouton "Actualiser".

Le `AssetBrowser` est chargé dans la scène principale `IndustrialSimulator` et positionné à droite.

**Glisser/déposer** :
- Au clic sur une vignette, on démarre un drag (`Control.set_drag_preview`).
- Au drop sur la scène 3D, on fait un `RayCast` depuis la caméra vers le sol, et on instancie le `.glb`/`.obj` à la position d'impact.
- Le nœud instancié est parenté au `Node3D` "Usine".

### Étape 3 — Aperçu 3D dans la fenêtre

Pour chaque OBJ, générer un aperçu via :
- Une `SubViewport` avec une `Camera3D` et une lumière.
- Le mesh chargé dans la `SubViewport`.
- Un rendu une fois (`render_target_update_mode = UPDATE_ONCE`) puis texture mise en cache.

Pour éviter de tout précharger, faire un **lazy loading** : ne charger l'aperçu que lorsque la vignette devient visible.

### Étape 4 — Filtrage des OBJ inutiles

Créer un fichier `assets_filter.json` dans `res://assets/imported/` :

```json
{
  "blacklist": ["Cube", "Sphere", "Plane", "Default-Mesh"],
  "whitelist": []
}