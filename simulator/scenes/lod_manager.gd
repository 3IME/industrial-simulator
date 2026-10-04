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
const DIST_MAX := 400.0      # cap large : dans un hall de ~150 m de
                              # diagonale, les grandes structures restent
                              # visibles ; seuls les petits objets cullent
const DIST_LABEL := 45.0     # les noms au sol
const HYSTERESIS := 2.5      # marge de retour vers un niveau superieur
const PERIODE := 0.1         # s entre deux mises a jour des groupes

var _origine: Node3D = null
var _groupes: Array = []
var _chrono := 0.0
var _instances_gerees := 0
var _zones: Array = []      # [{nom, boite, racines, exclus, visible}]


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
    # taille REELLE : l'AABB des enfants ne voit pas le scale du prop
    # (ascenseur x3,5, chaudiere x6, voxel 2 x6,3 ...)
    var rayon := (boite.size * noeud.scale).length() / 2.0
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


## ZONES : volumes mutuellement exclusifs. Le joueur dans une zone ->
## les zones qui lui sont exclusives sont masquees entierement ; dans le
## hall principal (aucune zone), tout reste visible. Les frontieres
## sont des murs : pas besoin d'hysteresis.

func register_zone(nom: String, boite: AABB) -> int:
    _zones.append({"nom": nom, "boite": boite, "racines": [],
                   "exclus": [], "visible": true})
    return _zones.size() - 1


func zone_exclusive(a: int, b: int) -> void:
    ## Zones mutuellement exclusives (chacune masque l'autre).
    if not _zones[a]["exclus"].has(b):
        _zones[a]["exclus"].append(b)
    if not _zones[b]["exclus"].has(a):
        _zones[b]["exclus"].append(a)


func zone_ramasser_par_position(id_zone: int, racine: Node3D, exclusions: Array = []) -> int:
    ## Ajoute a la zone les enfants DIRECTS de `racine` (props, meubles,
    ## murs...) dont la position est dans la boite. Retourne le compte.
    var boite: AABB = _zones[id_zone]["boite"]
    var compte := 0
    for enfant in racine.get_children():
        var n3d := enfant as Node3D
        if n3d == null or exclusions.has(enfant):
            continue
        if boite.has_point(n3d.global_position):
            _zones[id_zone]["racines"].append(enfant)
            compte += 1
    return compte


func _maj_zones(pos: Vector3) -> void:
    var active := -1
    for i in _zones.size():
        if _zones[i]["boite"].has_point(pos):
            active = i
            break
    for i in _zones.size():
        var cible: bool = not (active != -1 and _zones[active]["exclus"].has(i))
        if _zones[i]["visible"] != cible:
            for r in _zones[i]["racines"]:
                if is_instance_valid(r):
                    r.visible = cible
            _zones[i]["visible"] = cible


func stats() -> String:
    var racines := 0
    for z in _zones:
        racines += z["racines"].size()
    return "%d instances en culling, %d groupe(s) multi-niveaux, %d zone(s) (%d objets)" % [
        _instances_gerees, _groupes.size(), _zones.size(), racines]


func _process(delta: float) -> void:
    if _origine == null or (_groupes.is_empty() and _zones.is_empty()):
        return
    _chrono += delta
    if _chrono < PERIODE:
        return
    _chrono = 0.0
    var pos := _origine.global_position
    if not _zones.is_empty():
        _maj_zones(pos)
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
