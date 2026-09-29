# Crédits des assets

Ce dossier contient des assets librement réutilisables (aucun asset sous copyright
de produit commercial — voir la règle 9 de CONTRIBUTING.md).

## Bras robot 6 axes (dossier `kuka/`)

* Fichiers STL fournis par **3IME** (propriétaire du projet), convertis en GLB
  (échelle cm → m, repère Z-up → Y-up) ; coordonnées d'assemblage d'origine
  conservées — 7 pièces : base, colonne, bras, avant-bras, carénage, poignet, bride.

## Addon Footstepper (dossier `../addons/footstepper/`)

* « Footstepper » par **Dragon1Freak** — code sous licence **MIT**
  (https://store.godotengine.org/asset/dragon1freak/footstepper/,
  source : https://github.com/dragon1freak/df-godot-utils).
* Seul le cœur de l'addon est embarqué (scripts, icônes, plugin) ; les
  scènes d'exemple et les sons d'exemple (dont certains sous licence
  custom FilmCow, incompatibles avec la règle 9 de CONTRIBUTING) sont
  exclus.
* `sounds/default/` : sons **CC0** de Kenney — « Impact Sounds »
  (https://kenney.nl/assets/impact-sounds) — 5 pas béton (randomizer),
  saut (impactGeneric_light_000) et atterrissage (impactMetal_heavy_000).

## Props 3D (dossier `props/`)

* Modèles fournis par **3IME** (propriétaire du projet) :
  * `pendant_lamp.glb`, `fluorescent_fixture.glb` (lampes au plafond),
    `security_door.glb` (porte de sécurité murale), `gondola.glb`
    (rayonnage mural), `adult_waving.glb` (personnage animé « salut »).
* `adult_waving.glb` : l'export source mélangeait maillage en
  mètres et squelette en centimètres (racine `scale 0.01`) — les données
  POSITION du maillage ont été multipliées par 100 pour rétablir la cohérence
  skinnage/animation.
* `adult_flipbook.glb` : personnage en FOLIOSCOPE — 24 maillages simples
  (un par instant de l'animation, sans squelette) défilés par
  `ui/adult_flipbook.gd`. Généré par `scripts/bake_flipbook.py`
  (échelle commune 1,60 m, pieds regroundés par image, recentrage sur
  les hanches). Le mouvement revient sans rig : la taille ne peut pas
  dériver au rendu.
* `adult_static.glb` : variante figée de secours (pose de repos bras
  baissés), générée par `scripts/bake_static_adult.py` (convention IBM
  vérifiée par `scripts/diag_skinning.py`). Non utilisée par défaut.
* `adult_waving.glb` : le modèle animé d'origine (retouche unique :
  POSITION ×100, son export mixant maillage en mètres et rig en cm).
  Non chargé par défaut : son squelette rend géant chez l'utilisateur
  (os mesurés à 1,5-1,75 m pendant que le maillage rend ×100).

## Équipements de sécurité (dossier `safety/`)

* `extinguisher.glb` et `sign_extinguisher_si31.png` (converti depuis un GIF —
  Godot n'importe pas le GIF) fournis par **3IME** (propriétaire du projet).
* Échelle ramenée à 0,62 m de haut, fixation murale à 0,70 m (poignée ~1,2 m,
  hauteur normalisée de préhension), panneau à 2,05 m.

## Kenney — Factory Kit (modèles 3D, `kenney_factory/`)

* Auteur : Kenney (kenney.nl) — licence **CC0 1.0** (domaine public).
* Source : miroir « shorepine/kenney » sur GitHub (dossier `3d/factory`),
  qui redistribue les kits officiels kenney.nl sous la même licence CC0.
* Fichiers concernés : `*.glb`, `Textures/colormap.png`, `LICENSE-kenney.txt`.

## Poly Haven — textures (dossier `textures/`)

* Source : polyhaven.com — licence **CC0 1.0** (domaine public).
* Textures utilisées :
  * `floor_tiles_1k_*` (sol, dalles béton géométriques) — voir PolyScan ci-dessous
  * `concrete_wall_004` (mur béton) — diffuse + normale 1k
  * `corrugated_iron_02` (tôle ondulée, plafond) — diffuse + normale 1k

## PolyScan — texture de sol (dossier `textures/`)

* Asset : « Geometric Concrete Floor Tiles » — polyscann.com
  (https://polyscann.com/asset/geometric-concrete-floor-tiles-34e98a)
* Licence **CC0 1.0** (domaine public).
* Fichiers : `floor_tiles_1k_diff.jpg`, `floor_tiles_1k_nor.jpg`,
  `floor_tiles_1k_rough.jpg` (extraits du pack 1K).
