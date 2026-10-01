extends Node3D
## Scene 3D du prototype.
##
## Construit l'usine depuis le JSON (hall 120 x 90 m, 20 m de haut), habillee
## d'assets CC0 (Kenney Factory Kit + textures PolyScan / Poly Haven — cf.
## simulator/assets/CREDITS.md), et fait tourner le moteur en temps reel avec
## le serveur Modbus TCP actif. AUCUNE logique d'automatisme ici : le rendu ne
## fait que LIRE l'etat des machines (ADR-013). La logique vit dans le PLC.
##
## Controles : fleches pour marcher, souris regarder, Maj courir, Espace sauter,
## Echap liberer la souris, B poser une boite.

const FactoryBuilder = preload("res://simulation/factory_builder.gd")
const FpsController = preload("res://ui/fps_controller.gd")
const RobotKukaView = preload("res://ui/robot_kuka_view.gd")

const BELT_COLOR := Color(0.25, 0.27, 0.30)
const FRAME_COLOR := Color(0.55, 0.25, 0.08)
const BOX_COLOR := Color(0.85, 0.65, 0.15)
const SENSOR_OFF := Color(0.35, 0.08, 0.08)
const SENSOR_ON := Color(0.95, 0.15, 0.15)
const EXTINGUISHER_MODEL := "res://assets/safety/extinguisher.glb"
const EXTINGUISHER_SIGN := "res://assets/safety/sign_extinguisher_si31.png"
const URGENCUE_BOX := "res://assets/safety/urgence4.glb"
const TABLEAU := "res://assets/props/tableau.glb"
# Modele source : bbox 0.565 x 1.088 x 0.34 m, base a y=0.
# Cible : extincteur de 0.62 m pose sur support mural (base a 0.70 m).
const EXTINGUISHER_SCALE := 0.62 / 1.088
# Props 3D fournis par 3IME (dossier assets/props/, cf. CREDITS.md)
const PROP_PENDANT_LAMP := "res://assets/props/pendant_lamp.glb"
const PROP_FLUO_FIXTURE := "res://assets/props/fluorescent_fixture.glb"
const PROP_SECURITY_DOOR := "res://assets/props/security_door.glb"
const PROP_ADULT := "res://assets/props/adult_static.glb"
const PROP_GONDOLA := "res://assets/props/gondola.glb"
const PROP_IRON_MINER := "res://assets/props/iron_miner.glb"
const PROP_BRIDGE := "res://assets/props/bridge_fragment.glb"
const PROP_VOXEL_MACHINE := "res://assets/props/voxel_machine.glb"
const PROP_VOXEL_MACHINE_2 := "res://assets/props/voxel_machine_2.glb"
const PROP_MODULAR_CONVEYOR := "res://assets/props/modular_conveyor.glb"
const PROP_OFFICE_CHAIR := "res://assets/props/office_chair.glb"
const PROP_GAME := "res://assets/props/industrial_game.glb"
const PROP_DUMPSTER := "res://assets/props/steel_dumpster.glb"
const PROP_ELEVATOR := "res://assets/props/elevator.glb"
const PROP_BOLLARD := "res://assets/props/bollard.glb"
const PROP_TRACK_FENCE := "res://assets/props/track_fence.glb"
const PROP_DECK_PLATE := "res://assets/props/deck_plate.glb"
const PROP_MEZZANINE_FLOOR := "res://assets/props/mezzanine_floor.glb"
const PROP_MEZZANINE_WALKWAY := "res://assets/props/mezzanine_walkway.glb"
const PROP_STAIR_3M := "res://assets/props/stair_3m.glb"
const PROP_CELL_STAIR := "res://assets/props/cell_stair.glb"
const PROP_LADDER_CAGE := "res://assets/props/ladder_cage.glb"
const PROP_OFFICE_CABIN := "res://assets/props/office_cabin.glb"
const PROP_CLINICIAN_DESK := "res://assets/props/clinician_desk.glb"
const PROP_ELECTRIC_MOTOR := "res://assets/props/electric_motor.glb"
const PROP_ENGINE_LATHE := "res://assets/props/engine_lathe.glb"
const PROP_PILLAR_DRILL := "res://assets/props/pillar_drill.glb"
const PROP_PRESS_BRAKE := "res://assets/props/press_brake.glb"
const PROP_HYDRAULIC_PRESS := "res://assets/props/hydraulic_press.glb"
const PROP_VERTICAL_MILL := "res://assets/props/vertical_mill.glb"
const PROP_AUTO_ROTATE := "res://assets/props/auto_rotate.glb"
# Annonces sonores d'usine fournies par 3IME — touches 1 a 7
const ANNONCES := [
    {"touche": KEY_1, "nom": "evacuation", "chemin": "res://assets/sounds/annonces/evacuation.mp3"},
    {"touche": KEY_2, "nom": "evacuation incendie", "chemin": "res://assets/sounds/annonces/evacuation_incendie.mp3"},
    {"touche": KEY_3, "nom": "fumer", "chemin": "res://assets/sounds/annonces/fumer.mp3"},
    {"touche": KEY_4, "nom": "maintenance", "chemin": "res://assets/sounds/annonces/maintenance.mp3"},
    {"touche": KEY_5, "nom": "presse", "chemin": "res://assets/sounds/annonces/presse.mp3"},
    {"touche": KEY_6, "nom": "camion", "chemin": "res://assets/sounds/annonces/camion.mp3"},
    {"touche": KEY_7, "nom": "zone production", "chemin": "res://assets/sounds/annonces/zone_production.mp3"},
    {"touche": KEY_8, "nom": "confinement", "chemin": "res://assets/sounds/annonces/confinement.mp3"},
]
var _annonce_player: AudioStreamPlayer = null

# Dimensions du hall (120 x 90 m, 20 m de haut) ; le convoyeur occupe x=0..2
const HALL_MIN_X := -58.0
const HALL_MAX_X := 62.0
const HALL_MIN_Z := -45.0
const HALL_MAX_Z := 45.0
const HALL_HEIGHT := 20.0

# Assets CC0 — voir simulator/assets/CREDITS.md
const CONVEYOR_PIECE := "res://assets/kenney_factory/conveyor.glb"
const BOX_MODEL := "res://assets/kenney_factory/box-small.glb"
const TEX_FLOOR_D := "res://assets/textures/floor_tiles_1k_diff.jpg"
const TEX_FLOOR_N := "res://assets/textures/floor_tiles_1k_nor.jpg"
const TEX_FLOOR_R := "res://assets/textures/floor_tiles_1k_rough.jpg"
const TEX_WALL_D := "res://assets/textures/concrete_wall_004_diff.jpg"
const TEX_WALL_N := "res://assets/textures/concrete_wall_004_nor_gl.jpg"
const TEX_ROOF_D := "res://assets/textures/corrugated_iron_02_diff.jpg"
const TEX_ROOF_N := "res://assets/textures/corrugated_iron_02_nor_gl.jpg"

# Modeles Kenney : conveyor.glb = 1 x 0.4 x 1 m, base a y=0.
# Le convoyeur est rehausse (CONVEYOR_LIFT) a hauteur de travail reelle.
const CONVEYOR_LIFT := 0.5
const BELT_TOP := 0.4 + 0.5
# Largeur du modele box-small.glb (0.595 m), pour la mise a l'echelle
const BOX_MODEL_WIDTH := 0.595

## Ressources lourdes chargees par le code (pre-chargees en arriere-plan
## par le splash — cf. ui/splash.gd) : le chargement threade de main.tscn
## seul ne couvre rien, la scene est construite par _ready().
static func heavy_resources() -> Array:
    return [
        CONVEYOR_PIECE, BOX_MODEL,
        TEX_FLOOR_D, TEX_FLOOR_N, TEX_FLOOR_R, TEX_WALL_D, TEX_WALL_N,
        TEX_ROOF_D, TEX_ROOF_N,
        EXTINGUISHER_MODEL, EXTINGUISHER_SIGN,
        PROP_PENDANT_LAMP, PROP_FLUO_FIXTURE, PROP_SECURITY_DOOR,
        PROP_ADULT, PROP_GONDOLA, PROP_IRON_MINER, PROP_BRIDGE,
        PROP_VOXEL_MACHINE, PROP_VOXEL_MACHINE_2, PROP_MODULAR_CONVEYOR,
        PROP_OFFICE_CHAIR, PROP_GAME, PROP_DUMPSTER, PROP_ELEVATOR,
    ]


var factory: Dictionary = {}
var engine = null
var io = null
var conveyor = null
var timestep := 1.0 / 60.0
var accumulator := 0.0
var auto_box := false
var box_timer := 0.0
var capture_mode := false
var _adult_node: Node3D = null
var _dans_bureau := false
var _alarme_active := false
var _verre_player: AudioStreamPlayer = null
var _alarme_player: AudioStreamPlayer = null
var _adult_check := 0.0
var _extinguisher_model: PackedScene = null
var player_node: Node3D = null

var box_visual: Node3D
var entry_lamp: MeshInstance3D
var exit_lamp: MeshInstance3D
var hud = null


const BUILD_TAG := "e9553ef · adulte 1,60 m + garde-fou auto"


func _ready() -> void:
    var config_path := "res://config/factory.json"
    var modbus_port := -1
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--config="):
            config_path = arg.substr(9)
        elif arg.begins_with("--port="):
            modbus_port = int(arg.substr(7))
        elif arg == "--box":
            auto_box = true
        elif arg == "--capture":
            capture_mode = true

    factory = FactoryBuilder.build_from_file(config_path)
    if not factory.get("ok", false):
        push_error("usine invalide : " + str(factory.get("error", "?")))
        get_tree().quit(1)
        return
    engine = factory["engine"]
    io = factory["io"]
    timestep = float(factory["timestep"])
    for machine in factory["machines"]:
        if machine.has_method("spawn_box"):
            conveyor = machine

    var link = factory.get("modbus")
    if link != null:
        var port: int = modbus_port if modbus_port > 0 else link.server.port
        if link.listen(port) == Error.OK:
            print("Modbus TCP esclave actif : port ", port, ", unit id ", link.server.unit_id)
        else:
            # Non fatal : la scene reste utilisable sans PLC (port deja pris ?)
            push_warning("ecoute Modbus impossible sur le port " + str(port) + " ; simulation sans serveur")
            link = null

    var belt_length := 2.0
    if conveyor != null:
        belt_length = conveyor.length
    _build_hall(belt_length)
    _build_visuals()
    _spawn_robot()
    _spawn_player()

    hud = get_node_or_null(^"HUD")
    if hud != null:
        hud.setup(io, link)

    if conveyor != null:
        conveyor.spawn_box()
    # Ceinture de securite : liberer la souris si la fenetre se ferme
    get_tree().root.close_requested.connect(
        func() -> void: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    )
    print("Scene prete. Fleches : marcher | souris : regarder | Maj : courir | Ctrl : baisser | Espace : saut | B : boite | 1-8 : annonces | clic porte usine : quitter | clic bureau : entrer | clic urgence : alarme (0 : couper)")
    _show_build_badge()
    _verre_player = AudioStreamPlayer.new()
    add_child(_verre_player)
    _alarme_player = AudioStreamPlayer.new()
    _alarme_player.volume_db = -4.0
    add_child(_alarme_player)

    _annonce_player = AudioStreamPlayer.new()
    _annonce_player.volume_db = -4.0
    add_child(_annonce_player)
    if capture_mode:
        _capture_and_quit()


## Badge de version affiche 15 s au lancement : permet de verifier d'un
## coup d'oeil que la fenetre ouverte est bien la version courante.
func _show_build_badge() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 10
    add_child(layer)
    var label := Label.new()
    label.text = "BUILD " + BUILD_TAG
    label.position = Vector2(12, 8)
    label.add_theme_font_size_override("font_size", 18)
    label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
    layer.add_child(label)
    var tween := create_tween()
    tween.tween_interval(15.0)
    tween.tween_property(label, "modulate:a", 0.0, 1.0)
    tween.tween_callback(layer.queue_free)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_0 and _alarme_active:
            _couper_alarme()
            return
        for annonce in ANNONCES:
            if event.keycode == annonce.touche:
                _jouer_annonce(annonce.nom, annonce.chemin)
                return
    _clic_interaction(event)


func _jouer_annonce(nom: String, chemin: String) -> void:
    var flux = load(chemin)
    if flux == null or _annonce_player == null:
        push_warning("annonce introuvable : " + chemin)
        return
    _annonce_player.stream = flux
    _annonce_player.play()
    print("Annonce : ", nom)


## Clic sur les elements interactifs (raycast depuis la camera) :
## porte d'usine -> quitter ; bureau de chantier -> entrer/sortir.
## (les touches 1-7 des annonces sont traitees ci-dessus)
func _clic_interaction(event: InputEvent) -> void:
    if not (event is InputEventMouseButton and event.pressed):
        return
    if event.button_index != MOUSE_BUTTON_LEFT:
        return
    if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        return
    if _dans_bureau:
        var cam_in := get_viewport().get_camera_3d()
        if cam_in != null:
            var q_in := PhysicsRayQueryParameters3D.create(
                cam_in.global_position,
                cam_in.global_position - cam_in.global_transform.basis.z * 6.0)
            var hit_in: Dictionary = get_world_3d().direct_space_state.intersect_ray(q_in)
            if not hit_in.is_empty() and hit_in.collider is StaticBody3D                     and hit_in.collider.has_meta("interaction")                     and hit_in.collider.get_meta("interaction") == "porte_bureau_interieur":
                _sortir_bureau()
        return
    var cam := get_viewport().get_camera_3d()
    if cam == null:
        return
    # Cone de precision : rayon central, puis 4 decalages (~1,7 deg) —
    # le premier objet INTERACTIF touche gagne (portee 12 m).
    var base := -cam.global_transform.basis.z
    var impact: Dictionary = {}
    for decalage in [Vector3.ZERO, Vector3(0.03, 0, 0), Vector3(-0.03, 0, 0),
            Vector3(0, 0.03, 0), Vector3(0, -0.03, 0)]:
        var direction: Vector3 = (base + decalage).normalized()
        var query := PhysicsRayQueryParameters3D.create(
            cam.global_position, cam.global_position + direction * 12.0)
        var essai: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
        if not essai.is_empty() and essai.collider is StaticBody3D                 and essai.collider.has_meta("interaction"):
            impact = essai
            break
    if impact.is_empty():
        return
    var collider = impact.collider
    if collider.get_meta("interaction") == "porte_usine":
        print("Porte de l'usine : sortie du simulateur")
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        get_tree().quit(0)
    elif collider.get_meta("interaction") == "bureau":
        _entrer_bureau()
    elif collider.get_meta("interaction") == "alarme_incendie":
        _declencher_alarme(impact.position)


func _entrer_bureau() -> void:
    if player_node != null:
        player_node.position = Vector3(-54.9, 0.2, -57.5)
        player_node.rotation.y = 0.0          # regarde le fond de la piece (bureau)
    _dans_bureau = true
    print("Bureau de chantier : entree")


func _sortir_bureau() -> void:
    if player_node != null:
        player_node.position = Vector3(-54.5, 0.2, -30.0)
        player_node.rotation.y = PI / 2.0     # regarde le mur (la cabine)
    _dans_bureau = false
    print("Bureau de chantier : sortie")


## Bris de verre sonore + visuel, puis evacuation incendie en boucle.
func _declencher_alarme(pos: Vector3) -> void:
    _alarme_active = true
    print("ALERTE : brise-vitre actionne")
    var verre = load("res://assets/sounds/annonces/verre.mp3")
    if verre != null and _verre_player != null:
        _verre_player.stream = verre
        _verre_player.play()
    _eclats_de_verre(pos)
    await get_tree().create_timer(0.9).timeout
    if not _alarme_active:
        return
    var flux = load("res://assets/sounds/annonces/evacuation_incendie.mp3")
    if flux != null and _alarme_player != null:
        flux.loop = true
        _alarme_player.stream = flux
        _alarme_player.play()
        print("Evacuation incendie en boucle — touche 0 pour couper")


func _couper_alarme() -> void:
    _alarme_active = false
    if _alarme_player != null:
        _alarme_player.stop()
    print("Alarme coupee")


## Petits eclats de verre physiques qui tombent (effet bonus).
func _eclats_de_verre(pos: Vector3) -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.75, 0.9, 1.0, 0.7)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.metallic = 0.4
    mat.roughness = 0.1
    for i in range(12):
        var eclat := RigidBody3D.new()
        var mesh := MeshInstance3D.new()
        var bx := BoxMesh.new()
        bx.size = Vector3(0.03, 0.03, 0.01)
        mesh.mesh = bx
        mesh.material_override = mat
        eclat.add_child(mesh)
        var forme := CollisionShape3D.new()
        var boite := BoxShape3D.new()
        boite.size = Vector3(0.03, 0.03, 0.01)
        forme.shape = boite
        eclat.add_child(forme)
        eclat.position = pos + Vector3(randf() * 0.08 - 0.04, 0.0, randf() * 0.08 - 0.04)
        add_child(eclat)
        eclat.apply_central_impulse(Vector3(
            randf() * 2.0 - 1.0, randf() * 1.5, randf() * 2.0 - 1.0))
        get_tree().create_timer(3.0).timeout.connect(eclat.queue_free)


func _physics_process(delta: float) -> void:
    accumulator += delta
    var steps := 0
    while accumulator >= timestep and steps < 5:
        engine.step(timestep)
        accumulator -= timestep
        steps += 1

    if auto_box and conveyor != null:
        box_timer += delta
        if box_timer >= 10.0:
            box_timer = 0.0
            conveyor.spawn_box()


func _process(delta: float) -> void:
    # Garde-fou periodique : si l'echelle rendue de l'adulte derive
    # (quel que soit la cause), elle est recallee en moins de 2 s.
    if _adult_node != null:
        _adult_check += delta
        if _adult_check >= 2.0:
            _adult_check = 0.0
            _clamp_prop_height(_adult_node, 1.60, "adulte")
    _sync_visuals()
    if hud != null:
        if hud.joueur == null and player_node != null:
            hud.joueur = player_node
        hud.refresh()


func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_B:
        if conveyor != null and conveyor.spawn_box():
            print("Boite posee sur le capteur d'entree.")


## Personnage en vue subjective, hauteur d'yeux 1,60 m (fps_controller.gd).
func _spawn_player() -> void:
    var player := FpsController.new()
    player.position = Vector3(3.5, 1.0, 4.5)
    player_node = player
    add_child(player)


## Bras robot 6 axes : vue articulaire pilotee par la machine logique.
## Pose derriere la bande, portee tournee vers le convoyeur.
func _spawn_robot() -> void:
    var robot_machine = null
    for machine in factory["machines"]:
        if machine.get("angles_deg") != null:
            robot_machine = machine
    if robot_machine == null:
        return
    var view := RobotKukaView.new()
    view.position = Vector3(2.6, 0, -1.6)
    view.rotation.y = -PI / 2.0    # portee du bras (+X) tournee vers la bande (+Z)
    add_child(view)
    view.setup(robot_machine)
    # Enveloppe de collision approximative du bras en mouvement
    _add_static_box(Vector3(2.6, 0.6, -1.6), Vector3(1.4, 1.2, 1.4))


# ---------------------------------------------------------------------------
# Materiaux
# ---------------------------------------------------------------------------

func _mat_texture(diff_path: String, nor_path: String, world_tile: float, tint := Color.WHITE) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    var diff = load(diff_path)
    var nor = load(nor_path)
    if diff != null:
        mat.albedo_texture = diff
        mat.albedo_color = tint
    if nor != null:
        mat.normal_enabled = true
        mat.normal_texture = nor
    mat.roughness = 0.9
    # Mapping triplanaire : la texture suit les dimensions reelles du hall,
    # sans etirement, quelle que soit la taille des surfaces.
    mat.uv1_triplanar = true
    var density := 1.0 / world_tile
    mat.uv1_scale = Vector3(density, density, density)
    return mat


func _add_static_box(pos: Vector3, box_size: Vector3, interaction := "") -> StaticBody3D:
    var body := StaticBody3D.new()
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = box_size
    shape.shape = box
    body.position = pos
    if interaction != "":
        body.set_meta("interaction", interaction)
    body.add_child(shape)
    add_child(body)
    return body


# ---------------------------------------------------------------------------
# Hall industriel
# ---------------------------------------------------------------------------

## Tout est procedural ou CC0 (ADR-013) - aucun asset sous copyright.
func _build_hall(belt_length: float) -> void:
    var hall_w: float = HALL_MAX_X - HALL_MIN_X
    var hall_d: float = HALL_MAX_Z - HALL_MIN_Z
    var center_x: float = (HALL_MIN_X + HALL_MAX_X) / 2.0
    var center_z: float = (HALL_MIN_Z + HALL_MAX_Z) / 2.0

    # Eclairage d'ambiance
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.05, 0.06, 0.08)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.5, 0.51, 0.55)
    env.ambient_light_energy = 0.65
    world_env.environment = env
    add_child(world_env)

    # Materiaux textures (CC0 - cf. assets/CREDITS.md), densite en metres
    # monde par repetition (triplanaire), repli couleur pleine si absent.
    var floor_mat := _mat_texture(TEX_FLOOR_D, TEX_FLOOR_N, 3.0)
    var rough_map = load(TEX_FLOOR_R)
    if rough_map != null:
        floor_mat.roughness_texture = rough_map
        floor_mat.roughness = 1.0
    var wall_mat := _mat_texture(TEX_WALL_D, TEX_WALL_N, 6.0)
    var roof_mat := _mat_texture(TEX_ROOF_D, TEX_ROOF_N, 4.0)
    var plinth_mat := StandardMaterial3D.new()
    plinth_mat.albedo_color = Color(0.30, 0.33, 0.36)
    var beam_mat := StandardMaterial3D.new()
    beam_mat.albedo_color = Color(0.45, 0.48, 0.52)
    var yellow_mat := StandardMaterial3D.new()
    yellow_mat.albedo_color = Color(0.9, 0.75, 0.05)

    # Sol texture + collision (le personnage marche dessus)
    var floor_mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(hall_w, hall_d)
    floor_mesh.mesh = plane
    floor_mesh.position = Vector3(center_x, 0, center_z)
    floor_mesh.material_override = floor_mat
    add_child(floor_mesh)
    _add_static_box(Vector3(center_x, -0.5, center_z), Vector3(hall_w + 0.3, 1.0, hall_d + 0.3))

    # Marquage de securite : deux bandes jaunes le long du convoyeur
    for z in [-0.65, 0.65]:
        var strip := MeshInstance3D.new()
        var strip_box := BoxMesh.new()
        strip_box.size = Vector3(belt_length + 0.4, 0.005, 0.12)
        strip.mesh = strip_box
        strip.position = Vector3(belt_length / 2.0, 0.003, z)
        strip.material_override = yellow_mat
        add_child(strip)

    # Murs (4) + plinthe + collision
    var wall_specs := [
        [Vector3(center_x, HALL_HEIGHT / 2.0, HALL_MIN_Z), Vector2(hall_w, HALL_HEIGHT)],
        [Vector3(center_x, HALL_HEIGHT / 2.0, HALL_MAX_Z), Vector2(hall_w, HALL_HEIGHT)],
        [Vector3(HALL_MIN_X, HALL_HEIGHT / 2.0, center_z), Vector2(hall_d, HALL_HEIGHT)],
        [Vector3(HALL_MAX_X, HALL_HEIGHT / 2.0, center_z), Vector2(hall_d, HALL_HEIGHT)],
    ]
    for spec in wall_specs:
        var pos: Vector3 = spec[0]
        var size: Vector2 = spec[1]
        var along_x := absf(pos.z - center_z) > 0.01
        var wall_size := Vector3(size.x, size.y, 0.15) if along_x else Vector3(0.15, size.y, size.x)
        var wall := MeshInstance3D.new()
        var wall_box := BoxMesh.new()
        wall_box.size = wall_size
        wall.mesh = wall_box
        wall.position = pos
        wall.material_override = wall_mat
        add_child(wall)
        _add_static_box(pos, wall_size)
        var plinth := MeshInstance3D.new()
        var plinth_box := BoxMesh.new()
        plinth_box.size = Vector3(size.x, 0.4, 0.18) if along_x else Vector3(0.18, 0.4, size.x)
        plinth.mesh = plinth_box
        plinth.position = pos + Vector3(0, -(HALL_HEIGHT / 2.0 - 0.2), 0)
        plinth.material_override = plinth_mat
        add_child(plinth)

    # Porte de securite 3D sur le mur x = HALL_MIN_X ; repli : porte plate
    var door_prop := _place_prop(PROP_SECURITY_DOOR,
        Vector3(HALL_MIN_X + 0.28, 0.0, 0.0),
        Vector3(0.0, PI / 2.0, 0.0), 2.2)
    if door_prop != null:
        _add_static_box(Vector3(HALL_MIN_X + 0.28, 1.1, 0.0),
            Vector3(0.35, 2.3, 1.5), "porte_usine")
    else:
        var door_mat := StandardMaterial3D.new()
        door_mat.albedo_color = Color(0.5, 0.55, 0.6)
        var door := MeshInstance3D.new()
        var door_box := BoxMesh.new()
        door_box.size = Vector3(0.06, 2.2, 1.0)
        door.mesh = door_box
        door.position = Vector3(HALL_MIN_X + 0.02, 1.1, 0)
        door.material_override = door_mat
        add_child(door)
        var frame := MeshInstance3D.new()
        var frame_box := BoxMesh.new()
        frame_box.size = Vector3(0.08, 2.4, 1.2)
        frame.mesh = frame_box
        frame.position = Vector3(HALL_MIN_X, 1.2, 0)
        frame.material_override = plinth_mat
        add_child(frame)

    # Plafond texture tole
    var ceiling := MeshInstance3D.new()
    var ceiling_plane := PlaneMesh.new()
    ceiling_plane.size = Vector2(hall_w, hall_d)
    ceiling.mesh = ceiling_plane
    ceiling.rotation = Vector3(PI, 0, 0)
    ceiling.position = Vector3(center_x, HALL_HEIGHT, center_z)
    ceiling.material_override = roof_mat
    add_child(ceiling)

    # Poutrelles du plafond, tous les 12 m environ
    var beam_count := int(hall_w / 12.0)
    for i in range(beam_count + 1):
        var beam_x: float = HALL_MIN_X + 6.0 + i * (hall_w - 12.0) / beam_count
        var beam := MeshInstance3D.new()
        var beam_box := BoxMesh.new()
        beam_box.size = Vector3(0.35, 0.6, hall_d)
        beam.mesh = beam_box
        beam.position = Vector3(beam_x, HALL_HEIGHT - 0.35, center_z)
        beam.material_override = beam_mat
        add_child(beam)

    # Lumiere directionnelle douce avec OMBRES (une seule pour tout le
    # hall : raisonnable sur GPU integre) — c'est elle qui donne au
    # personnage et aux machines leur ombre portee.
    var soleil := DirectionalLight3D.new()
    soleil.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
    soleil.light_color = Color(1.0, 0.97, 0.92)
    soleil.light_energy = 0.55
    soleil.shadow_enabled = true
    add_child(soleil)

    # Grille de luminaires (3 x 3) + lumieres reelles
    var lamp_mat := StandardMaterial3D.new()
    lamp_mat.emission_enabled = true
    lamp_mat.emission = Color(1.0, 0.97, 0.85)
    lamp_mat.emission_energy_multiplier = 2.5
    lamp_mat.albedo_color = Color(0.9, 0.9, 0.85)
    for gx in 3:
        for gz in 3:
            var lamp_x: float = HALL_MIN_X + hall_w * (0.2 + 0.3 * gx)
            var lamp_z: float = HALL_MIN_Z + hall_d * (0.2 + 0.3 * gz)
            var lamp := MeshInstance3D.new()
            var lamp_box := BoxMesh.new()
            lamp_box.size = Vector3(2.0, 0.12, 0.4)
            lamp.mesh = lamp_box
            lamp.position = Vector3(lamp_x, HALL_HEIGHT - 1.0, lamp_z)
            lamp.material_override = lamp_mat
            add_child(lamp)
            var light := OmniLight3D.new()
            light.position = Vector3(lamp_x, HALL_HEIGHT - 1.4, lamp_z)
            light.omni_range = 35.0
            light.light_energy = 1.4
            light.light_color = Color(1.0, 0.97, 0.9)
            add_child(light)

    # Extincteurs muraux : mur du fond (z min) et mur droit (x max)
    for x in [-20.0, 10.0, 40.0]:
        _build_extinguisher(Vector3(x, 0, HALL_MIN_Z + 0.09), -PI / 2.0)
    for z in [-15.0, 15.0]:
        _build_extinguisher(Vector3(HALL_MAX_X - 0.09, 0, z), PI)

    _build_props()
    _build_alarmes()
    _build_expo()
    _build_expo2()
    _build_office_cabin()
    _build_bureau_interieur()


func _build_extinguisher(anchor: Vector3, wall_rotation: float) -> void:
    var pivot := Node3D.new()
    pivot.position = anchor
    pivot.rotation.y = wall_rotation
    add_child(pivot)

    _build_extinguisher_sign(pivot)

    if _load_extinguisher_model():
        var model: Node3D = _extinguisher_model.instantiate()
        model.scale = Vector3.ONE * EXTINGUISHER_SCALE
        # bbox source en x : [-0.26..+0.30] ; on degage le mur (X local = interieur)
        model.position = Vector3(0.16, 0.70, 0)
        pivot.add_child(model)
    else:
        _build_extinguisher_procedural(pivot)


## Charge (une seule fois) le modele GLB de l'extincteur. Faux => fallback.
func _load_extinguisher_model() -> bool:
    if _extinguisher_model == null:
        if not ResourceLoader.exists(EXTINGUISHER_MODEL):
            return false
        var loaded = load(EXTINGUISHER_MODEL)
        if loaded == null or not loaded is PackedScene:
            return false
        _extinguisher_model = loaded
    return true


## Panneau normalise (pictogramme extincteur) au-dessus du support.
func _build_extinguisher_sign(pivot: Node3D) -> void:
    var sign := MeshInstance3D.new()
    var tex = load(EXTINGUISHER_SIGN)
    if tex != null and tex is Texture2D:
        var quad := QuadMesh.new()
        quad.size = Vector2(0.36, 0.36)
        var mat := StandardMaterial3D.new()
        mat.albedo_texture = tex
        mat.roughness = 0.75
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        # Leger effet lumineux : ces panneaux sont photoluminescents en vrai.
        mat.emission_enabled = true
        mat.emission = Color(0.35, 0.35, 0.35)
        quad.material = mat
        sign.mesh = quad
        # Face avant du quad (+Z local du maillage) tournee vers l'interieur
        # du hall (+X local du pivot).
        sign.rotation.y = PI / 2.0
    else:
        var sign_red := StandardMaterial3D.new()
        sign_red.emission_enabled = true
        sign_red.albedo_color = Color(0.85, 0.1, 0.1)
        sign_red.emission = Color(0.6, 0.02, 0.02)
        var sign_box := BoxMesh.new()
        sign_box.size = Vector3(0.03, 0.3, 0.3)
        sign.mesh = sign_box
        sign.material_override = sign_red
    sign.position = Vector3(0.02, 2.05, 0)
    pivot.add_child(sign)


## Repli procedurale si le modele GLB est absent.
func _build_extinguisher_procedural(pivot: Node3D) -> void:
    var red := StandardMaterial3D.new()
    red.albedo_color = Color(0.82, 0.05, 0.05)
    var black := StandardMaterial3D.new()
    black.albedo_color = Color(0.05, 0.05, 0.05)
    var white := StandardMaterial3D.new()
    white.albedo_color = Color(0.92, 0.92, 0.92)

    # Corps rouge
    var body := MeshInstance3D.new()
    var body_cyl := CylinderMesh.new()
    body_cyl.top_radius = 0.09
    body_cyl.bottom_radius = 0.09
    body_cyl.height = 0.55
    body.mesh = body_cyl
    body.position = Vector3(0.06, 1.35, 0)
    body.material_override = red
    pivot.add_child(body)

    # Poignee noire + base + support mural
    var handle := MeshInstance3D.new()
    var handle_box := BoxMesh.new()
    handle_box.size = Vector3(0.05, 0.1, 0.16)
    handle.mesh = handle_box
    handle.position = Vector3(0.06, 1.68, 0)
    handle.material_override = black
    pivot.add_child(handle)
    var base := MeshInstance3D.new()
    var base_box := BoxMesh.new()
    base_box.size = Vector3(0.16, 0.03, 0.16)
    base.mesh = base_box
    base.position = Vector3(0.06, 1.06, 0)
    base.material_override = black
    pivot.add_child(base)
    var bracket := MeshInstance3D.new()
    var bracket_box := BoxMesh.new()
    bracket_box.size = Vector3(0.03, 0.5, 0.12)
    bracket.mesh = bracket_box
    bracket.position = Vector3(0.01, 1.35, 0)
    bracket.material_override = white
    pivot.add_child(bracket)


## Pose un prop GLB fourni (retourne null si absent => l'appelant replie).
func _place_prop(path: String, pos: Vector3, rot: Vector3, prop_scale := 1.0) -> Node3D:
    if not ResourceLoader.exists(path):
        return null
    var scene = load(path)
    if scene == null or not scene is PackedScene:
        return null
    var node: Node3D = scene.instantiate()
    node.position = pos
    node.rotation = rot
    node.scale = Vector3.ONE * prop_scale
    add_child(node)
    return node


## Boitiers d'alarme incendie (brise-vitre) pres de CHAQUE extincteur
## et dans le bureau (mur de gauche). Modele aute couche : redresse par
## X 90 deg + demi-tour Y 180 (l'avant etait vers le mur). Clic ->
## bris de verre sonore et visuel puis evacuation en boucle (touche 0
## pour couper).
func _build_alarmes() -> void:
    # mur du fond (face +Z) : a cote des extincteurs x = -20, 10, 40
    for x in [-20.0, 10.0, 40.0]:
        _placer_alarme(Vector3(x - 1.4, 1.46, HALL_MIN_Z + 0.06),
            Vector3(PI / 2.0, PI, 0.0), Vector3(0.0, 0.0, 1.0))
    # mur droit (face -X) : extincteurs z = -15 et +15
    for z in [-15.0, 15.0]:
        _placer_alarme(Vector3(HALL_MAX_X - 0.06, 1.46, z - 1.4),
            Vector3(PI / 2.0, -PI / 2.0, 0.0), Vector3(-1.0, 0.0, 0.0))
    # bureau : mur de GAUCHE de la piece interieure (face interieure +X)
    _placer_alarme(Vector3(-58.66, 1.46, -59.0),
        Vector3(PI / 2.0, -PI / 2.0, 0.0), Vector3(1.0, 0.0, 0.0))


func _placer_alarme(pos: Vector3, rot: Vector3, face: Vector3) -> void:
    _place_prop(URGENCUE_BOX, pos, rot)
    # zone cliquable fine DEVANT la facade (face explicite : le panneau
    # etait enterre dans le mur, le rayon touchait toujours le mur)
    _add_static_box(pos + face * 0.07, Vector3(0.24, 0.24, 0.05),
        "alarme_incendie")


## Props 3D : lampes au plafond, adulte anime pres de la porte, gondole au mur.
## Garde-fou d'echelle : mesure la hauteur rendue du prop et la ramene a
## target_h si elle s'en ecarte (protection contre un cache d'import ou un
## asset dont l'echelle varie). Ne fait rien si la hauteur est correcte.
func _clamp_prop_height(node: Node3D, target_h: float, label: String) -> void:
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
    if aabb.size.y <= 0.01:
        return
    var ratio := target_h / aabb.size.y
    if absf(ratio - 1.0) > 0.08:
        push_warning("prop %s : hauteur %.2f m recallee a %.2f m" % [label, aabb.size.y, target_h])
        node.scale *= ratio


func _build_props() -> void:
    # Deux luminaires au plafond, au-dessus de la zone convoyeur / robot
    _place_prop(PROP_PENDANT_LAMP, Vector3(1.0, HALL_HEIGHT - 3.0, 0.0), Vector3.ZERO)
    _place_prop(PROP_FLUO_FIXTURE, Vector3(2.6, HALL_HEIGHT - 0.01, -1.6), Vector3(0.0, 0.6, 0.0))
    var lamp_light := OmniLight3D.new()
    lamp_light.position = Vector3(1.0, HALL_HEIGHT - 4.3, 0.0)
    lamp_light.light_color = Color(1.0, 0.85, 0.7)
    lamp_light.omni_range = 12.0
    lamp_light.light_energy = 1.2
    add_child(lamp_light)
    var fluo_light := OmniLight3D.new()
    fluo_light.position = Vector3(2.6, HALL_HEIGHT - 0.6, -1.6)
    fluo_light.light_color = Color(0.95, 0.98, 1.0)
    fluo_light.omni_range = 10.0
    fluo_light.light_energy = 1.0
    add_child(fluo_light)

    # Adulte anime (salut) a cote de la porte, mur gauche.
    # Recule du mur : l'animation de salut deplace les hanches de ~30 cm
    # lateralement, trop pres il penetrerait le mur pendant le salut.
    var adult := _place_prop(PROP_ADULT,
        Vector3(HALL_MIN_X + 16.4, 0.0, 1.9), Vector3(0.0, PI / 2.0, 0.0))
    if adult != null:
        _clamp_prop_height(adult, 1.60, "adulte")
        _adult_node = adult
        for anim_player in adult.find_children("*", "AnimationPlayer"):
            for anim_name in anim_player.get_animation_list():
                var anim: Animation = anim_player.get_animation(anim_name)
                anim.loop_mode = Animation.LOOP_LINEAR
                anim_player.play(anim_name)

    # Gondole (rayonnage) contre le mur gauche
    var gondola := _place_prop(PROP_GONDOLA,
        Vector3(HALL_MIN_X + 0.42, 0.95, 4.2), Vector3(0.0, PI / 2.0, 0.0))
    if gondola != null:
        _add_static_box(Vector3(HALL_MIN_X + 0.42, 0.95, 4.2), Vector3(0.62, 1.9, 1.0))


## Ligne d'exposition : les modeles GLB fournis, espaces de 7 m a z = -10,
## chacun avec son nom au sol (Label3D plat devant lui). Bbox mesurees via
## tests/measure_props.gd (toutes debout a l'identite, echelle 1).
func _build_expo() -> void:
    var items := [
        {"path": PROP_IRON_MINER, "nom": "Mineur de fer automatique",
         "x": -36.0, "y": 0.76, "col": Vector3(1.9, 1.51, 1.33)},
        {"path": PROP_VOXEL_MACHINE, "nom": "Machine industrielle voxel 1",
         "x": -29.0, "y": 0.67, "col": Vector3(1.9, 1.35, 1.9)},
        {"path": PROP_VOXEL_MACHINE_2, "nom": "Machine industrielle voxel 2",
         "x": -22.0, "y": 0.95, "col": Vector3(0.7, 1.9, 0.7)},
        {"path": PROP_MODULAR_CONVEYOR, "nom": "Convoyeur modulaire",
         "x": -15.0, "y": 0.25, "col": Vector3(1.9, 0.51, 0.65)},
        {"path": PROP_GAME, "nom": "Jeu industriel realiste",
         "x": -8.0, "y": 0.30, "col": Vector3(1.9, 0.6, 1.42)},
        {"path": PROP_DUMPSTER, "nom": "Benne en acier vert",
         "x": -1.0, "y": 0.0, "col": Vector3(0.8, 0.73, 0.74)},
        {"path": PROP_ELEVATOR, "nom": "Ascenseur",
         "x": 6.0, "y": 0.0, "col": Vector3(0.63, 0.86, 0.61)},
        {"path": PROP_BRIDGE, "nom": "Fragment de pont",
         "x": 20.0, "y": 0.0, "col": Vector3.ZERO},    # plat : pas de collision
    ]
    for item in items:
        var node := _place_prop(item.path, Vector3(item.x, item.y, -10.0), Vector3.ZERO)
        if node == null:
            continue
        if item.col != Vector3.ZERO:
            _add_static_box(Vector3(item.x, item.col.y / 2.0, -10.0), item.col)
        # Nom au sol, devant l'objet (face au chemin de visite)
        var label := Label3D.new()
        label.text = item.nom
        label.font_size = 48
        label.modulate = Color(1.0, 0.95, 0.8)
        label.outline_size = 12
        label.outline_modulate = Color(0.05, 0.05, 0.08)
        label.position = Vector3(item.x, 0.02, -10.0 + item.col.z / 2.0 + 1.1)
        label.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
        add_child(label)


## Piece interieure du bureau : 8 x 10 m derriere le mur du fond
## (invisible depuis l'usine). Vraie porte dans le mur avant : c'est
## ELLE qu'on clique pour sortir. La porte de la cabine (dans l'usine)
## teleporte vers l'interieur.
func _build_bureau_interieur() -> void:
    var cx := -54.9
    var cz := -61.0
    var mur := StandardMaterial3D.new()
    var papier = load("res://assets/textures/mur_bureau_pattern.jpg")
    if papier != null:
        mur.albedo_texture = papier
        mur.uv1_scale = Vector3(4.0, 1.4, 1.0)    # motif ~2 m
        mur.roughness = 0.9
    else:
        mur.albedo_color = Color(0.78, 0.76, 0.72)
    var sol := StandardMaterial3D.new()
    var parquet = load("res://assets/textures/parquet_basecolor.png")
    if parquet != null:
        sol.albedo_texture = parquet
        sol.uv1_scale = Vector3(4.0, 5.0, 1.0)    # lame ~2 m
        sol.roughness = 0.55
    else:
        sol.albedo_color = Color(0.42, 0.40, 0.38)
    var plafond := StandardMaterial3D.new()
    plafond.albedo_color = Color(0.92, 0.91, 0.88)
    var bois := StandardMaterial3D.new()
    bois.albedo_color = Color(0.45, 0.32, 0.2)

    _room_box(Vector3(cx, -0.1, cz), Vector3(8.0, 0.2, 10.0), sol)
    _room_box(Vector3(cx, 2.9, cz), Vector3(8.0, 0.2, 10.0), plafond)
    _room_box(Vector3(cx, 1.4, cz - 4.9), Vector3(8.0, 2.8, 0.2), mur)      # fond
    _room_box(Vector3(cx - 2.3, 1.4, cz + 4.9), Vector3(3.4, 2.8, 0.2), mur)  # avant gauche
    _room_box(Vector3(cx + 2.3, 1.4, cz + 4.9), Vector3(3.4, 2.8, 0.2), mur)  # avant droite
    _room_box(Vector3(cx, 2.4, cz + 4.9), Vector3(1.2, 0.8, 0.2), mur)      # linteau au-dessus de la porte
    _room_box(Vector3(cx - 3.9, 1.4, cz), Vector3(0.2, 2.8, 10.0), mur)     # gauche
    _room_box(Vector3(cx + 3.9, 1.4, cz), Vector3(0.2, 2.8, 10.0), mur)     # droite

    # Porte visible + zone cliquable (sortie)
    var porte := MeshInstance3D.new()
    var porte_box := BoxMesh.new()
    porte_box.size = Vector3(1.1, 1.95, 0.08)
    porte.mesh = porte_box
    porte.position = Vector3(cx, 0.975, cz + 4.9)
    porte.material_override = bois
    add_child(porte)
    _add_static_box(Vector3(cx, 1.0, cz + 4.9), Vector3(1.2, 2.0, 0.15),
        "porte_bureau_interieur")

    var lampe := OmniLight3D.new()
    lampe.position = Vector3(cx, 2.4, cz)
    lampe.light_color = Color(1.0, 0.93, 0.8)
    lampe.omni_range = 9.0
    lampe.light_energy = 1.3
    add_child(lampe)

    # Tableau au mur de droite, centre (source 4,44 m -> 2,0 m)
    _place_prop(TABLEAU, Vector3(cx + 3.76, 1.5, cz),
        Vector3(0.0, -PI / 2.0, 0.0), 0.45)

    _place_prop(PROP_CLINICIAN_DESK, Vector3(cx, 0.0, cz - 3.9), Vector3.ZERO)
    _place_prop(PROP_OFFICE_CHAIR, Vector3(cx, 0.0, cz - 2.9), Vector3.ZERO)


func _room_box(pos: Vector3, box_size: Vector3, mat: StandardMaterial3D) -> void:
    var mesh := MeshInstance3D.new()
    var bx := BoxMesh.new()
    bx.size = box_size
    mesh.mesh = bx
    mesh.position = pos
    mesh.material_override = mat
    add_child(mesh)
    _add_static_box(pos, box_size)


## Bureau de chantier (site cabin) contre le mur gauche, cote fond
## (x ~ -54, z = -34) : le grand cote le long du mur.
func _build_office_cabin() -> void:
    var cabin := _place_prop(PROP_OFFICE_CABIN,
        Vector3(-54.9, 0.0, -34.0), Vector3.ZERO, 0.65)
    if cabin == null:
        return
    # Plaque cliquable a la porte de la cabine (pas de gros bloc : il
    # ejectait le joueur qui entrait — l'interieur est libre, on marche
    # sur le sol de l'usine).
    _add_static_box(Vector3(-54.9, 1.1, -32.5),
        Vector3(1.2, 2.2, 0.1), "bureau")
    var label := Label3D.new()
    label.text = "Bureau de chantier"
    label.font_size = 48
    label.modulate = Color(1.0, 0.95, 0.8)
    label.outline_size = 12
    label.outline_modulate = Color(0.05, 0.05, 0.08)
    label.position = Vector3(-54.9, 0.02, -34.0 + 2.83 / 2.0 + 1.1)
    label.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
    add_child(label)


## Deuxieme ligne d'exposition (z = -16) : modeles fournis en unitees
## arbitraires (pipeline STEP), normalises par dimension cible. Table
## generee depuis tests/measure_props.gd (cf. scripts/dequantize_gltf.py
## pour la conversion KHR_mesh_quantization -> flottants).
func _build_expo2() -> void:
    var items := [
        {"path": PROP_BOLLARD, "nom": "Borne de securite jaune",
         "x": -56.0, "y": 0.0, "s": 1.0, "col": Vector3(0.24, 0.90, 0.24)},
        {"path": PROP_TRACK_FENCE, "nom": "Cloture de voie",
         "x": -49.6, "y": 0.0, "s": 1.0, "col": Vector3(4.18, 2.20, 0.34)},
        {"path": PROP_DECK_PLATE, "nom": "Plaque de caillebotis",
         "x": -43.2, "y": 0.0, "s": 1.0, "col": Vector3.ZERO},
        {"path": PROP_MEZZANINE_FLOOR, "nom": "Plancher de mezzanine",
         "x": -36.8, "y": 0.0, "s": 1.0, "col": Vector3(6.0, 4.01, 3.04)},
        {"path": PROP_MEZZANINE_WALKWAY, "nom": "Passerelle de mezzanine",
         "x": -30.4, "y": 0.0, "s": 1.0, "col": Vector3(2.0, 3.54, 1.16)},
        {"path": PROP_STAIR_3M, "nom": "Escalier 3 m",
         "x": -24.0, "y": 0.0, "s": 0.75, "col": Vector3(1.16, 3.05, 2.58)},
        {"path": PROP_CELL_STAIR, "nom": "Escalier de cage",
         "x": -17.6, "y": 0.0, "s": 0.75, "col": Vector3(0.80, 3.05, 2.84)},
        {"path": PROP_LADDER_CAGE, "nom": "Echelle a cage",
         "x": -11.2, "y": 0.0, "s": 0.75, "col": Vector3(0.69, 3.05, 0.65)},
        {"path": PROP_ELECTRIC_MOTOR, "nom": "Moteur electrique",
         "x": 8.0, "y": 0.0, "s": 1.0, "col": Vector3(1.14, 0.93, 0.86)},
        {"path": PROP_ENGINE_LATHE, "nom": "Tour d'atelier",
         "x": 14.4, "y": 0.0, "s": 1.0, "col": Vector3(2.51, 2.00, 1.04)},
        {"path": PROP_PILLAR_DRILL, "nom": "Perceuse a colonne",
         "x": 20.8, "y": 0.0, "s": 1.0, "col": Vector3(0.85, 2.16, 0.68)},
        {"path": PROP_PRESS_BRAKE, "nom": "Presse a plier la tole",
         "x": 27.2, "y": 0.0, "s": 1.0, "col": Vector3(2.34, 2.10, 1.38)},
        {"path": PROP_HYDRAULIC_PRESS, "nom": "Presse hydraulique",
         "x": 33.6, "y": 0.0, "s": 1.0, "col": Vector3(1.54, 2.26, 0.82)},
        {"path": PROP_VERTICAL_MILL, "nom": "Fraiseuse verticale",
         "x": 40.0, "y": 0.0, "s": 1.0, "col": Vector3(1.39, 2.59, 1.39)},
        {"path": PROP_AUTO_ROTATE, "nom": "Plateau tournant",
         "x": 46.4, "y": 0.0, "s": 1.0, "col": Vector3(0.64, 1.21, 1.85)},
    ]
    for item in items:
        var node := _place_prop(item.path, Vector3(item.x, item.y, -16.0),
            Vector3.ZERO, item.s)
        if node == null:
            continue
        if item.col != Vector3.ZERO:
            _add_static_box(Vector3(item.x, item.col.y / 2.0, -16.0), item.col)
        var label := Label3D.new()
        label.text = item.nom
        label.font_size = 48
        label.modulate = Color(1.0, 0.95, 0.8)
        label.outline_size = 12
        label.outline_modulate = Color(0.05, 0.05, 0.08)
        label.position = Vector3(item.x, 0.02, -16.0 + item.col.z / 2.0 + 1.1)
        label.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
        add_child(label)


# ---------------------------------------------------------------------------
# Machines (rendu)
# ---------------------------------------------------------------------------

## Construit le rendu a partir des parametres geometriques de la machine.
## Le convoyeur va de x=0 (entree) a x=length (sortie), axe X.
func _build_visuals() -> void:
    var belt_length := 2.0
    var entry_x := 0.3
    var exit_x := 1.7
    var box_size := 0.2
    if conveyor != null:
        belt_length = conveyor.length
        entry_x = conveyor.entry_position
        exit_x = conveyor.exit_position
        box_size = conveyor.box_length

    # Convoyeur : modeles Kenney (1 m par piece) rehausse sur un chassssis,
    # ou repli procedurale
    var conveyor_scene = load(CONVEYOR_PIECE)
    if conveyor_scene != null:
        var count := int(ceil(belt_length))
        for i in range(count):
            var piece = conveyor_scene.instantiate()
            piece.position = Vector3(i + 0.5, CONVEYOR_LIFT, 0)
            add_child(piece)
        _build_conveyor_frame(belt_length)
    else:
        _build_procedural_conveyor(belt_length)
    # Le personnage ne traverse pas le convoyeur
    _add_static_box(Vector3(belt_length / 2.0, BELT_TOP / 2.0, 0), Vector3(belt_length + 0.2, BELT_TOP, 1.0))

    # Capteurs : potes lateraux + lampes sur la bande
    entry_lamp = _build_sensor(entry_x, "capteur_entree")
    exit_lamp = _build_sensor(exit_x, "capteur_sortie")

    # Boite virtuelle : modele Kenney a l'echelle logique, ou repli procedurale
    var box_scene = load(BOX_MODEL)
    if box_scene != null:
        box_visual = box_scene.instantiate()
        var scale_factor := box_size / BOX_MODEL_WIDTH
        box_visual.scale = Vector3(scale_factor, scale_factor, scale_factor)
    else:
        var box_mesh_node := MeshInstance3D.new()
        var box_mesh := BoxMesh.new()
        box_mesh.size = Vector3(box_size, box_size, box_size)
        box_mesh_node.mesh = box_mesh
        var box_mat := StandardMaterial3D.new()
        box_mat.albedo_color = BOX_COLOR
        box_mesh_node.material_override = box_mat
        box_visual = box_mesh_node
    add_child(box_visual)


## Chassis metallique sous le convoyeur (le modele Kenney etant une piece
## pleine de 0,4 m, on le porte a hauteur de travail sur des longerres).
func _build_conveyor_frame(belt_length: float) -> void:
    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color(0.28, 0.30, 0.33)
    for z in [-0.38, 0.38]:
        var rail := MeshInstance3D.new()
        var rail_box := BoxMesh.new()
        rail_box.size = Vector3(belt_length, CONVEYOR_LIFT, 0.07)
        rail.mesh = rail_box
        rail.position = Vector3(belt_length / 2.0, CONVEYOR_LIFT / 2.0, z)
        rail.material_override = steel
        add_child(rail)
    for x in [0.3, belt_length / 2.0, belt_length - 0.3]:
        var foot := MeshInstance3D.new()
        var foot_box := BoxMesh.new()
        foot_box.size = Vector3(0.08, CONVEYOR_LIFT, 0.85)
        foot.mesh = foot_box
        foot.position = Vector3(x, CONVEYOR_LIFT / 2.0, 0)
        foot.material_override = steel
        add_child(foot)


## Repli si le kit Kenney est absent : bande + chassis proceduraux.
func _build_procedural_conveyor(belt_length: float) -> void:
    var belt := MeshInstance3D.new()
    var belt_box := BoxMesh.new()
    belt_box.size = Vector3(belt_length, 0.1, 0.6)
    belt.mesh = belt_box
    belt.position = Vector3(belt_length / 2.0, BELT_TOP - 0.05, 0)
    var belt_mat := StandardMaterial3D.new()
    belt_mat.albedo_color = BELT_COLOR
    belt.material_override = belt_mat
    add_child(belt)

    var frame_mat := StandardMaterial3D.new()
    frame_mat.albedo_color = FRAME_COLOR
    for z in [-0.32, 0.32]:
        var rail := MeshInstance3D.new()
        var rail_box := BoxMesh.new()
        rail_box.size = Vector3(belt_length + 0.1, 0.25, 0.05)
        rail.mesh = rail_box
        rail.position = Vector3(belt_length / 2.0, 0.15, z)
        rail.material_override = frame_mat
        add_child(rail)


func _build_sensor(x_position: float, sensor_name: String) -> MeshInstance3D:
    var post := MeshInstance3D.new()
    var post_mesh := BoxMesh.new()
    post_mesh.size = Vector3(0.05, BELT_TOP + 0.5, 0.05)
    post.mesh = post_mesh
    post.position = Vector3(x_position, (BELT_TOP + 0.5) / 2.0, 0.6)
    var post_mat := StandardMaterial3D.new()
    post_mat.albedo_color = Color(0.1, 0.1, 0.1)
    post.material_override = post_mat
    add_child(post)

    var lamp := MeshInstance3D.new()
    var lamp_mesh := BoxMesh.new()
    lamp_mesh.size = Vector3(0.08, 0.08, 0.35)
    lamp.mesh = lamp_mesh
    lamp.position = Vector3(x_position, BELT_TOP + 0.12, 0.42)
    lamp.name = sensor_name
    var lamp_mat := StandardMaterial3D.new()
    lamp_mat.emission_enabled = true
    lamp_mat.albedo_color = SENSOR_OFF
    lamp_mat.emission = SENSOR_OFF
    lamp.material_override = lamp_mat
    add_child(lamp)
    return lamp


## Synchronise le rendu avec l'etat logique des machines (lecture seule).
func _sync_visuals() -> void:
    if conveyor == null or box_visual == null:
        return
    var present: bool = conveyor.box_present
    box_visual.visible = present
    if present:
        # box_position = front de la boite ; le rendu place son centre.
        # Les modeles Kenney ont leur base a y=0 : pose sur la bande (0.4).
        box_visual.position = Vector3(
            conveyor.box_position - conveyor.box_length / 2.0, BELT_TOP, 0
        )
    if entry_lamp != null:
        _set_lamp(entry_lamp, conveyor.entry_sensor)
    if exit_lamp != null:
        _set_lamp(exit_lamp, conveyor.exit_sensor)


func _set_lamp(lamp: MeshInstance3D, on: bool) -> void:
    var color: Color = SENSOR_ON if on else SENSOR_OFF
    var mat: StandardMaterial3D = lamp.material_override
    mat.albedo_color = color
    mat.emission = color * (2.0 if on else 0.3)


# ---------------------------------------------------------------------------
# Capture automatique (preuve visuelle / CI)
# ---------------------------------------------------------------------------

func _capture_and_quit() -> void:
    await get_tree().create_timer(1.5).timeout
    var image := get_viewport().get_texture().get_image()
    image.save_png("res://capture_3d.png")
    print("Capture ecrite : res://capture_3d.png")
    # Gros plan sur un extincteur du mur du fond : preuve des assets de securite
    if player_node != null:
        player_node.position = Vector3(10.0, 1.0, -41.0)
        player_node.rotation.y = 0.0
        for cam in player_node.find_children("*", "Camera3D"):
            cam.rotation.x = 0.18
        await get_tree().create_timer(0.4).timeout
        var closeup := get_viewport().get_texture().get_image()
        closeup.save_png("res://capture_3d_extinguisher.png")
        print("Capture ecrite : res://capture_3d_extinguisher.png")
        # AUTOTEST : rayon direct vers le panneau de l'alarme x=8.6
        await get_tree().create_timer(0.3).timeout
        var q_a := PhysicsRayQueryParameters3D.create(
            Vector3(8.6, 1.46, -40.6), Vector3(8.6, 1.46, -44.90))
        var h_a: Dictionary = get_world_3d().direct_space_state.intersect_ray(q_a)
        if not h_a.is_empty() and h_a.collider.has_meta("interaction")                 and h_a.collider.get_meta("interaction") == "alarme_incendie":
            print("AUTOTEST ALARME: panneau touche -> declenchement")
            _declencher_alarme(h_a.position)
            await get_tree().create_timer(1.2).timeout
            if _alarme_active:
                _couper_alarme()
                print("AUTOTEST ALARME: OK")
            else:
                print("AUTOTEST ALARME: ECHEC (pas de boucle)")
        elif h_a.is_empty():
            print("AUTOTEST ALARME: ECHEC (rien touche)")
        else:
            print("AUTOTEST ALARME: ECHEC (meta=",
                h_a.collider.get_meta("interaction") if h_a.collider.has_meta("interaction") else "-", ")")
    # Gros plan sur le bras robot : preuve de l'articulation corrigee
    if player_node != null:
        player_node.position = Vector3(1.2, 0.0, 0.6)
        player_node.rotation.y = -0.57
        for cam in player_node.find_children("*", "Camera3D"):
            cam.rotation.x = 0.12
        await get_tree().create_timer(0.6).timeout
        await get_tree().create_timer(0.6).timeout
        var robot_shot := get_viewport().get_texture().get_image()
        robot_shot.save_png("res://capture_3d_robot.png")
        print("Capture ecrite : res://capture_3d_robot.png")
        # Porte + gondole (mur gauche) et adulte (avance de 15 m)
        player_node.position = Vector3(-36.9, 0.0, 2.6)
        player_node.rotation.y = PI / 2.0 - 0.12
        for cam in player_node.find_children("*", "Camera3D"):
            cam.rotation.x = 0.06
        await get_tree().create_timer(0.4).timeout
        var props_shot := get_viewport().get_texture().get_image()
        props_shot.save_png("res://capture_3d_props.png")
        print("Capture ecrite : res://capture_3d_props.png")
        # Les deux luminaires au plafond
        player_node.position = Vector3(4.0, 0.0, 4.0)
        player_node.rotation.y = 0.43
        for cam in player_node.find_children("*", "Camera3D"):
            cam.rotation.x = 1.2
        await get_tree().create_timer(0.4).timeout
        var lamps_shot := get_viewport().get_texture().get_image()
        lamps_shot.save_png("res://capture_3d_lamps.png")
        print("Capture ecrite : res://capture_3d_lamps.png")
        # Ligne d'exposition des modeles fournis
        player_node.position = Vector3(-38.5, 0.0, -6.5)
        player_node.rotation.y = -PI / 2.0
        for cam in player_node.find_children("*", "Camera3D"):
            cam.rotation.x = 0.04
        await get_tree().create_timer(0.4).timeout
        var expo_shot := get_viewport().get_texture().get_image()
        expo_shot.save_png("res://capture_3d_expo.png")
        print("Capture ecrite : res://capture_3d_expo.png")
        # Controle tardif : l'adulte reste-t-il a taille humaine apres
        # plusieurs boucles d'animation ?
        await get_tree().create_timer(12.0).timeout
        player_node.position = Vector3(-52.6, 0.0, 2.1)
        player_node.rotation.y = PI / 2.0
        for cam in player_node.find_children("*", "Camera3D"):
            cam.rotation.x = 0.05
        await get_tree().create_timer(0.4).timeout
        var late_shot := get_viewport().get_texture().get_image()
        late_shot.save_png("res://capture_3d_props_tard.png")
        print("Capture ecrite : res://capture_3d_props_tard.png")
    # Liberer la souris avant de quitter (sinon curseur confine sous Windows)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    get_tree().quit(0)

