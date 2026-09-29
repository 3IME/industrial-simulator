extends Node3D
## Defile les images du folioscope (chaque image est un maillage simple,
## sans squelette : la taille ne peut pas deriver au rendu).
## Usage : enfant de l'instance de adult_flipbook.glb.

# Duree de la boucle d'animation d'origine (cf. scripts/bake_flipbook.py)
const DUREE_BOUCLE := 5.37
const N_IMAGES := 24

var frames: Array = []
var _t := 0.0


func _ready() -> void:
    for child in get_children():
        if child is MeshInstance3D:
            frames.append(child)
            child.visible = false
    if not frames.is_empty():
        frames[0].visible = true


func _process(delta: float) -> void:
    if frames.is_empty():
        return
    _t += delta
    var idx := int(fmod(_t / (DUREE_BOUCLE / N_IMAGES), frames.size()))
    for i in range(frames.size()):
        frames[i].visible = i == idx
