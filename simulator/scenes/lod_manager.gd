class_name LodManager
extends Node

## Gestionnaire de LOD global (optimisation RENDU uniquement, ADR-013).
##
## Deux mecanismes complementaires :
##
## 1. CULLING PAR DISTANCE - generalise a tous les objets :
##    sur chaque VisualInstance3D enregistre on fixe
##    visibility_range_end = f(taille de l'objet). C'est le MOTEUR qui
##    gere, CAMERA PAR CAMERA : le joueur et les 4 cameras CCTV evaluent
##    chacune leur distance, donc aucun objet ne disparait de la TV.
##    Cout GDScript : zero (une seule fois a l'enregistrement).
##
## 2. GROUPES MULTI-NIVEAUX - objets disposant de plusieurs maillages
##    (ex : Haas 405k / 101k / 13k triangles) : bascule du niveau actif
##    selon la distance du joueur, avec HYSTERESIS anti-clignotement
##    (descente agressive des que le seuil est franchi, remontee
##    seulement apres marge de retour).
##
## Volontairement hors LOD : particules (fumee/flammes), gyrophares et
## leurs lumieres, convoyeur anime, viewmodel du joueur.

const FACTEUR := 55.0        # culling a rayon * FACTEUR (metres)
const DIST_MIN := 40.0       # jamais cullle plus pres de 40 m
const DIST_MAX := 130.0      # ni plus loin que 130 m
const DIST_LABEL := 45.0     # les noms au sol
const HYSTERESIS := 2.5      # marge de retour vers un niveau superieur
const PERIODE := 0.1         # s entre deux mises a jour des groupes

var _origine: Node3D = null
var _groupes: Array = []
var _chrono := 0.0
var _instances_gerees := 0


func setup(p_origine: Node3D) -> void:
    _origine = p_origine


func setup_si_absent(p_origine: Node3D) -> void:
    if _origine == null:
        _origine = p_origine


func register_cull(noeud: Node, distance: float) -> void:
    ## Masque l'objet et tous ses descendants au-dela de `distance`
    ## (evaluation par camera, faite par le moteur).
    if not is_instance_valid(noeud):
        return
    _applique(noeud, distance)
    for enfant in noeud.find_children("*", "VisualInstance3D", true, false):
        _applique(enfant, distance)


func auto_register(noeud: Node3D) -> void:
    ## Culling automatique calcule depuis la taille reelle du prop
    ## (AABB de ses meshes). Appele par _place_prop pour TOUS les props.
    var boite := _boite(noeud)
    if boite == AABB():
        return
    var rayon := boite.size.length() / 2.0
    register_cull(noeud, clampf(rayon * FACTEUR, DIST_MIN, DIST_MAX))


func register_levels(noeuds: Array, seuils: Array, centre: Vector3) -> void:
    ## noeuds[0] = meilleure qualite ; seuils[i] = distance de bascule
    ## du niveau i vers le niveau i+1.
    if noeuds.size() != seuils.size() + 1:
        push_warning("LOD : nombre de noeuds / seuils incoherent")
        return
    for i in noeuds.size():
        noeuds[i].visible = (i == 0)
    _groupes.append({"noeuds": noeuds, "seuils": seuils,
                     "centre": centre, "actif": 0})


func stats() -> String:
    return "%d instances en culling, %d groupe(s) multi-niveaux" % [
        _instances_gerees, _groupes.size()]


func _process(delta: float) -> void:
    if _origine == null or _groupes.is_empty():
        return
    _chrono += delta
    if _chrono < PERIODE:
        return
    _chrono = 0.0
    var pos := _origine.global_position
    for groupe in _groupes:
        var dist := pos.distance_to(groupe["centre"])
        var cible: int = groupe["actif"]
        # descente : agressive, des que le seuil est franchi
        while cible < groupe["seuils"].size() and dist >= groupe["seuils"][cible]:
            cible += 1
        # remontee : seulement avec la marge d'hysteresis
        while cible > 0 and dist < groupe["seuils"][cible - 1] - HYSTERESIS:
            cible -= 1
        if cible != groupe["actif"]:
            for i in groupe["noeuds"].size():
                groupe["noeuds"][i].visible = (i == cible)
            groupe["actif"] = cible


func _applique(noeud: Node, distance: float) -> void:
    if noeud is VisualInstance3D:
        noeud.visibility_range_end = distance
        _instances_gerees += 1


func _boite(racine: Node3D) -> AABB:
    ## AABB des meshes sous `racine` (transformation de racine exclue).
    var acc: Array = []
    for c in racine.get_children():
        if c is Node3D:
            _collecte(c, Transform3D.IDENTITY, acc)
    if acc.is_empty():
        return AABB()
    var boite: AABB = acc[0]
    for i in range(1, acc.size()):
        boite = boite.merge(acc[i])
    return boite


func _collecte(noeud: Node3D, xf: Transform3D, acc: Array) -> void:
    var x := xf * noeud.transform
    var m := noeud as MeshInstance3D
    if m != null:
        acc.append(x * m.get_aabb())
    for c in noeud.get_children():
        if c is Node3D:  # ignorer AnimationPlayer & autres non-spatiaux
            _collecte(c, x, acc)
