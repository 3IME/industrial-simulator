extends SceneTree
## Outil : dimensions reelles (AABB) des modeles importes.

func _initialize() -> void:
    for path in [
        "res://assets/kenney_factory/conveyor.glb",
        "res://assets/kenney_factory/conveyor-long.glb",
        "res://assets/kenney_factory/box-large.glb",
        "res://assets/kenney_factory/box-small.glb",
        "res://assets/kenney_factory/button-floor-round.glb",
    ]:
        var scene = load(path)
        if scene == null:
            print(path, " : ECHEC de chargement")
            continue
        var instance = scene.instantiate()
        var aabb := AABB()
        for child in instance.find_children("*", "MeshInstance3D", true, false):
            var mi: MeshInstance3D = child
            if mi.mesh != null:
                aabb = aabb.merge(mi.get_aabb())
        print(path, " -> position ", aabb.position, " taille ", aabb.size)
        instance.free()
    quit(0)
