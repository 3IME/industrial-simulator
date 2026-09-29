extends CharacterBody3D
## Personnage en vue subjective, a hauteur d'homme (1,60 m d'yeux).
##
## Controles : ZQSD/WASD (touches physiques, compatible AZERTY/QWERTY),
## souris pour regarder, Maj pour courir, Espace pour sauter,
## Echap pour liberer la souris, clic pour la recapturer.

const WALK_SPEED := 4.0
const SPRINT_SPEED := 8.0
const JUMP_VELOCITY := 4.5
const GRAVITY := 9.8
const MOUSE_SENSITIVITY := 0.0025
const EYE_HEIGHT := 1.6

var pitch := 0.0
var cam: Camera3D


func _ready() -> void:
    var capsule := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.3
    shape.height = 1.75
    capsule.shape = shape
    capsule.position = Vector3(0, 0.875, 0)
    add_child(capsule)

    cam = Camera3D.new()
    cam.position = Vector3(0, EYE_HEIGHT, 0)
    add_child(cam)
    cam.make_current()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotation.y -= event.relative.x * MOUSE_SENSITIVITY
        pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.45, 1.45)
        cam.rotation.x = pitch
    elif event is InputEventMouseButton and event.pressed:
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
        velocity.y = JUMP_VELOCITY

    var forward := 0.0
    var side := 0.0
    if Input.is_physical_key_pressed(KEY_W):
        forward -= 1.0
    if Input.is_physical_key_pressed(KEY_S):
        forward += 1.0
    if Input.is_physical_key_pressed(KEY_A):
        side -= 1.0
    if Input.is_physical_key_pressed(KEY_D):
        side += 1.0

    var speed := SPRINT_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED
    var direction := (transform.basis * Vector3(side, 0, forward)).normalized()
    if direction.length() > 0.0:
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, speed)
        velocity.z = move_toward(velocity.z, 0.0, speed)

    move_and_slide()
