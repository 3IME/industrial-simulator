extends Node3D
## Garde-fou d'echelle pour personnage a squelette, mesure sur le RENDU REEL.
##
## Contrairement a une boite englobante de maillage (pose de repos, trompeuse
## pour un maillage skinne), ce garde-fou mesure la position MONDE de chaque os
## a chaque frame et ramene l'os le plus haut a TARGET_H en ajustant l'echelle
## du parent. Toute derive (x100, x10...) est corrigee en une frame.
##
## Usage : ajouter ce noeud comme enfant de l'instance du personnage.

const TARGET_H := 1.60
const TOLERANCE := 0.05    # correction seulement au-dela de 5 % d'ecart

var _skeleton: Skeleton3D = null
var _host: Node3D = null


func _ready() -> void:
    _host = get_parent() as Node3D
    for node in _host.find_children("*", "Skeleton3D", true, false):
        _skeleton = node
        break


func _process(_delta: float) -> void:
    if _skeleton == null or _host == null:
        return
    var max_world_y := 0.0
    for i in _skeleton.get_bone_count():
        var pose: Transform3D = _skeleton.get_bone_global_pose(i)
        var world: Vector3 = _skeleton.global_transform * pose.origin
        max_world_y = maxf(max_world_y, world.y)
    if max_world_y < 0.05:
        return
    var ratio := TARGET_H / max_world_y
    if absf(ratio - 1.0) > TOLERANCE:
        _host.scale *= ratio
