extends CharacterBody3D
## Personnage en vue subjective, a hauteur d'homme (1,60 m d'yeux).
##
## Controles : ZQSD/WASD (touches physiques, compatible AZERTY/QWERTY),
## souris pour regarder (clic dans la fenetre pour capturer la souris),
## Maj pour courir, Espace pour sauter, Echap pour liberer la souris.

const WALK_SPEED := 4.0
const SPRINT_SPEED := 8.0
const JUMP_VELOCITY := 4.5
const GRAVITY := 9.8
const MOUSE_SENSITIVITY := 0.0025
const EYE_HEIGHT := 1.6
const FOOTSTEPPER_SCRIPT := preload("res://addons/footstepper/footstepper.gd")
const FOOTSTEPPER_PROFILE := preload("res://addons/footstepper/footstepper_sound_profile.gd")
const SOUNDS_DIR := "res://addons/footstepper/sounds/default"

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

    _setup_footstepper()


## Ne JAMAIS quitter (ni changer de scene) en laissant la souris capturee :
## Windows maintiendrait le curseur confine au rectangle de la fenetre.
func _exit_tree() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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


## Sons de pas / saut / atterrisage (addon Footstepper, code MIT ;
## sons CC0 Kenney - voir simulator/assets/CREDITS.md).
## Mode automatique : l'enfant direct du CharacterBody3D detecte seul
## la distance parcourue (pas), l'impulsion verticale (saut) et le
## retour au sol (atterrissage).
func _setup_footstepper() -> void:
    var profile = FOOTSTEPPER_PROFILE.new()

    # Varier les pas : randomizer sur les 5 pas béton
    var steps := AudioStreamRandomizer.new()
    var count := 0
    for path in [
        SOUNDS_DIR + "/footstep.ogg",
        SOUNDS_DIR + "/footstep_001.ogg",
        SOUNDS_DIR + "/footstep_002.ogg",
        SOUNDS_DIR + "/footstep_003.ogg",
        SOUNDS_DIR + "/footstep_004.ogg",
    ]:
        var stream = load(path)
        if stream != null:
            steps.add_stream(count, stream)
            count += 1
    if count > 0:
        profile.sound_footstep = steps
    profile.sound_jump = load(SOUNDS_DIR + "/jump.ogg")
    profile.sound_land = load(SOUNDS_DIR + "/land.ogg")

    var stepper = FOOTSTEPPER_SCRIPT.new()
    stepper.name = "Footstepper"
    stepper.footstep_distance = 1.8
    stepper.audio_volume = -8.0
    stepper.audio_pitch_variation = 0.12
    stepper.audio_number_of_players = 4
    stepper.default_sound_profile = profile
    add_child(stepper)
