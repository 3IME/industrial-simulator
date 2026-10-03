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
    "res://assets/safety/urgence4.glb",
    "res://assets/props/tableau.glb",
    "res://assets/safety/defibrillator.glb",
    "res://assets/props/boite_5bp.glb",
    "res://assets/props/control_box.glb",
    "res://assets/props/keypad_lock.glb",
    "res://assets/props/distributeur_cafe.glb",
    "res://assets/props/steel_bin.glb",
    "res://assets/props/whiteboard.glb",
    "res://assets/props/caution_wet_floor.glb",
    "res://assets/props/chaudiere.glb",
    "res://assets/props/filing_cabinet.glb",
    "res://assets/props/golden_play_button.glb",
    "res://assets/props/medieval_stool.glb",
    "res://assets/props/laptop.glb",
    "res://assets/props/transpallet.glb",
    "res://assets/props/estop_mushroom.gltf",
    "res://assets/props/auto_rotate.glb",
    "res://assets/props/clinician_desk.glb",
    "res://assets/props/deck_plate.glb",
    "res://assets/props/electric_motor.glb",
    "res://assets/props/engine_lathe.glb",
    "res://assets/props/hydraulic_press.glb",
    "res://assets/props/ladder_cage.glb",
    "res://assets/props/mezzanine_floor.glb",
    "res://assets/props/mezzanine_walkway.glb",
    "res://assets/props/pillar_drill.glb",
    "res://assets/props/press_brake.glb",
    "res://assets/props/office_cabin.glb",
    "res://assets/props/stair_3m.glb",
    "res://assets/props/track_fence.glb",
    "res://assets/props/vertical_mill.glb",
    "res://assets/props/bollard.glb",
    "res://assets/props/cell_stair.glb",
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
