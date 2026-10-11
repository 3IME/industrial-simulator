extends SceneTree
## Phase 2 du GODOT_INSTRUCTIONS_RACK : le GLB importe, la nomenclature
## cle est atteignable (TRANSSTOCKEUR_ROOT, CARRIAGE_Z, fourches).

func _initialize() -> void:
    var scene: PackedScene = load("res://assets/props/rack.glb")
    if scene == null:
        print("RACK ECHEC : chargement")
        quit(1)
        return
    var rack: Node3D = scene.instantiate()
    get_root().add_child(rack)
    var noms := {}
    for noeud in rack.find_children("*", "Node", true, false):
        noms[noeud.name] = true
    for cle in ["TRANSSTOCKEUR_ROOT", "CARRIAGE_Z", "FORK_LEFT", "FORK_RIGHT"]:
        if not noms.has(cle):
            print("RACK ECHEC : noeud absent ", cle)
            quit(1)
            return
    # AABB monde au sol (base attendue a y = -7.5, origine a mi-hauteur)
    var aabb := AABB()
    var premier := true
    for m in rack.find_children("*", "MeshInstance3D", true, false):
        if m.mesh == null:
            continue
        var b: AABB = m.global_transform * m.mesh.get_aabb()
        if premier:
            aabb = b
            premier = false
        else:
            aabb = aabb.merge(b)
    print("RACK AABB ", aabb.position, " -> ", aabb.end)
    print("RACK OK")
    quit(0)
