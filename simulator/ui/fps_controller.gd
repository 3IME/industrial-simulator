extends CharacterBody3D
## Personnage en vue subjective, a hauteur d'homme (1,60 m d'yeux).
##
## Controles : fleches directionnelles pour marcher,
## souris pour regarder (clic dans la fenetre pour capturer la souris),
## Maj pour courir, Espace pour sauter, Echap pour liberer la souris.

const WALK_SPEED := 4.0
const SPRINT_SPEED := 8.0
const JUMP_VELOCITY := 4.5
const GRAVITY := 9.8
const MOUSE_SENSITIVITY := 0.0025
const EYE_HEIGHT := 1.6
const EYE_CROUCH := 0.9
const CROUCH_SPEED := 2.0
const ARMS_MODEL := "res://assets/props/arms_split.glb"
# Rapprochement des mains : decalage local (unites du modele) de chaque
# bras vers l'axe central (mesure par silhouette vue joueur).
const ARMS_RAPPROCHE := 2.6
const CLICK_SOUND := "res://addons/footstepper/sounds/default/jump.ogg"
const ARMS_SCALE := 0.06
const ARMS_BASE := Vector3(0.0, -0.35, -0.10)
const ARMS_ROT_X := PI / 2.0    # bras tendus vers l'avant, mains visibles
const FOOTSTEPPER_SCRIPT := preload("res://addons/footstepper/footstepper.gd")
const FOOTSTEPPER_PROFILE := preload("res://addons/footstepper/footstepper_sound_profile.gd")
const SOUNDS_DIR := "res://addons/footstepper/sounds/default"

var pitch := 0.0
var _eye := EYE_HEIGHT
var _arms: Node3D = null
var _bob := 0.0
var _press := 0.0        # avancee de la main au clic (1 = avancee)
var _arm_right: Node3D = null
var _click_sound: AudioStreamPlayer = null
var cam: Camera3D


func _ready() -> void:
    var capsule := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.3
    shape.height = 1.75
    capsule.shape = shape
    capsule.position = Vector3(0, 0.875, 0)
    add_child(capsule)

    # Silhouette de corps : invisible mais projette une OMBRE (les FPS
    # font voir l'ombre du joueur sans voir son corps).
    var ombre_corps := MeshInstance3D.new()
    var capsule_ombre := CapsuleMesh.new()
    capsule_ombre.radius = 0.3
    capsule_ombre.height = 1.75
    ombre_corps.mesh = capsule_ombre
    ombre_corps.position = Vector3(0, 0.875, 0)
    ombre_corps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
    add_child(ombre_corps)

    cam = Camera3D.new()
    cam.position = Vector3(0, EYE_HEIGHT, 0)
    add_child(cam)
    cam.make_current()

    # Mains en vue subjective (maillage statique depouille de son squelette :
    # echelle fiable dans tout contexte de rendu)
    var arms_scene = load(ARMS_MODEL)
    if arms_scene != null and arms_scene is PackedScene:
        _arms = arms_scene.instantiate()
        _arms.scale = Vector3.ONE * ARMS_SCALE
        _arms.position = ARMS_BASE
        _arms.rotation.x = ARMS_ROT_X
        for mesh_enfant in _arms.get_children():
            if mesh_enfant is GeometryInstance3D:
                mesh_enfant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        cam.add_child(_arms)
        for enfant in _arms.get_children():
            if enfant is Node3D:
                if "gauche" in enfant.name:
                    enfant.position.x += ARMS_RAPPROCHE
                elif "droit" in enfant.name:
                    enfant.position.x -= ARMS_RAPPROCHE
                    _arm_right = enfant

    _click_sound = AudioStreamPlayer.new()
    var click_stream = load(CLICK_SOUND)
    if click_stream != null:
        _click_sound.stream = click_stream
        _click_sound.volume_db = -10.0
        add_child(_click_sound)

    # Reticule discret au centre de l'ecran : le point vise par le clic
    var viseur_couche := CanvasLayer.new()
    var viseur := Label.new()
    viseur.text = "+"
    viseur.add_theme_font_size_override("font_size", 22)
    viseur.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
    viseur.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    viseur.add_theme_constant_override("outline_size", 6)
    viseur_couche.add_child(viseur)
    add_child(viseur_couche)
    # centrage manuel deterministe (les presets d'ancrage ont deja piégé)
    viseur.position = (get_viewport().get_visible_rect().size - Vector2(14.0, 24.0)) / 2.0

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
        elif event.button_index == MOUSE_BUTTON_LEFT:
            _press = 1.0
            if _click_sound != null:
                _click_sound.play()
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
    floor_max_angle = deg_to_rad(55.0)
    floor_snap_length = 0.5  # marcher sur les rampes/escaliers
    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
        velocity.y = JUMP_VELOCITY

    var forward := 0.0
    var side := 0.0
    if Input.is_physical_key_pressed(KEY_UP):
        forward -= 1.0
    if Input.is_physical_key_pressed(KEY_DOWN):
        forward += 1.0
    if Input.is_physical_key_pressed(KEY_LEFT):
        side -= 1.0
    if Input.is_physical_key_pressed(KEY_RIGHT):
        side += 1.0

    var crouch := Input.is_physical_key_pressed(KEY_CTRL)
    _eye = lerpf(_eye, EYE_CROUCH if crouch else EYE_HEIGHT,
        clampf(delta * 10.0, 0.0, 1.0))
    cam.position.y = _eye
    var speed := CROUCH_SPEED if crouch else (
        SPRINT_SPEED if Input.is_physical_key_pressed(KEY_SHIFT)
        else WALK_SPEED)
    var direction := (transform.basis * Vector3(side, 0, forward)).normalized()
    if direction.length() > 0.0:
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, speed)
        velocity.z = move_toward(velocity.z, 0.0, speed)

    move_and_slide()
    _animate_arms(delta, crouch)


## Balancement procedural des mains, lie au deplacement reel :
## cadence et amplitude suivent la vitesse (marche/course/accroupi),
## petit dip sur les sauts et chutes.
func _animate_arms(delta: float, crouch: bool) -> void:
    if _arms == null:
        return
    var hspeed := Vector2(velocity.x, velocity.z).length()
    var intensite := clampf(hspeed / WALK_SPEED, 0.0, 1.6)
    _bob += delta * hspeed * 2.4
    var cible := ARMS_BASE
    if crouch:
        cible.y -= 0.06
    cible.y -= absf(cos(_bob)) * 0.022 * intensite
    cible.x += sin(_bob) * 0.016 * intensite
    cible.y += clampf(-velocity.y * 0.01, -0.05, 0.05)
    _arms.position = _arms.position.lerp(cible, clampf(delta * 8.0, 0.0, 1.0))
    # Clic : la main droite avance (le gauche ne bouge pas).
    _press = maxf(0.0, _press - delta * 6.0)
    if _arm_right != null:
        _arm_right.rotation.y = _press * 0.22
        _arm_right.position.z = -_press * 0.58

    var tangage := clampf(velocity.y * 0.012, -0.1, 0.1)
    _arms.rotation.x = lerpf(_arms.rotation.x, ARMS_ROT_X + tangage,
        clampf(delta * 6.0, 0.0, 1.0))

    # Geste d'appui au clic : SEUL le bras droit pousse vers l'avant
    # (pivot du poignet + petite poussee), le gauche reste immobile.

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


## Remplace le materiau d'un bras par le shader a doigts articules,
## en conservant la texture d'origine.