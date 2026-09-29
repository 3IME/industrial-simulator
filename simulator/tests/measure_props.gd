extends SceneTree
## Outil de mesure : bbox de chaque prop GLB telle que Godot le rend (a l'identite).
## Usage : godot --headless --path simulator --script res://tests/measure_props.gd

const PROPS := [
    "res://assets/props/pendant_lamp.glb",
    "res://assets/props/fluorescent_fixture.glb",
    "res://assets/props/security_door.glb",
    "res://assets/props/adult_waving.glb",
    "res://assets/props/gondola.glb",
    "res://assets/props/iron_miner.glb",
    "res://assets/props/bridge_fragment.glb",
    "res://assets/props/voxel_machine.glb",
    "res://assets/props/voxel_machine_2.glb",
    "res://assets/props/modular_conveyor.glb",
    "res://assets/props/office_chair.glb",
    "res://assets/props/industrial_game.glb",
    "res://assets/props/steel_dumpster.glb",
    "res://assets/props/elevator.glb",
]

var frames := 0
var bench := Node3D.new()

func _initialize() -> void:
    get_root().add_child(bench)

func _process(_delta: float) -> bool:
    frames += 1
    if frames < 5:
        return false
    for path in PROPS:
        var scene: PackedScene = load(path)
        if scene == null:
            print(path, " ABSENT")
            continue
        var node: Node3D = scene.instantiate()
        node.position = Vector3(0, 50, 0)
        bench.add_child(node)
        var aabb := AABB()
        var first := true
        for m in node.find_children("*", "MeshInstance3D", true, false):
            if m.mesh == null:
                continue
            var box: AABB = m.global_transform * m.mesh.get_aabb()
            if first:
                aabb = box
                first = false
            else:
                aabb = aabb.merge(box)
        print("%s taille=(%.2f, %.2f, %.2f) min=(%.2f, %.2f, %.2f)" % [
            path.get_file(), aabb.size.x, aabb.size.y, aabb.size.z,
            aabb.position.x, aabb.position.y - 50.0, aabb.position.z])
        bench.remove_child(node)
        node.queue_free()
    quit(0)
    return true
