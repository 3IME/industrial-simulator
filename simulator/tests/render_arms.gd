extends SceneTree
## Rendu des bras VUS PAR LA CAMERA DU JOUEUR (vue subjective exacte)
## pour caler placement/rotation avant integration.
## Usage : godot --path simulator --script res://tests/render_arms.gd

var frames := 0
var scene: PackedScene
var banc: Node3D
var cam: Camera3D
var arms: Node3D

func _initialize() -> void:
    banc = Node3D.new()
    get_root().add_child(banc)
    cam = Camera3D.new()
    banc.add_child(cam)
    cam.make_current()
    var lum := DirectionalLight3D.new()
    lum.rotation_degrees = Vector3(-40, -30, 0)
    banc.add_child(lum)
    scene = load("res://assets/props/arms_viewmodel.glb")
    _pose_candidate(Vector3(0.0, -0.35, -0.10), PI / 2.0, 0.06)

func _pose_candidate(pos: Vector3, rot_x: float, scale: float) -> void:
    if arms != null:
        arms.queue_free()
    arms = scene.instantiate()
    arms.position = pos
    arms.rotation.x = rot_x
    arms.scale = Vector3.ONE * scale
    banc.add_child(arms)

func _process(_delta: float) -> bool:
    frames += 1
    if frames < 5:
        return false
    var img := get_root().get_viewport().get_texture().get_image()
    img.save_png("res://render_arms.png")
    print("rendu ecrit")
    quit(0)
    return true
