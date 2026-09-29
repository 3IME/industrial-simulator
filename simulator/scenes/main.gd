extends Node3D
## Scene 3D du prototype (Phase 5).
##
## Construit l'usine depuis le JSON, cree le rendu correspondant et fait
## tourner le moteur en temps reel avec le serveur Modbus TCP actif.
## AUCUNE logique d'automatisme ici : le rendu ne fait que LIRE l'etat des
## machines (ADR-013). La logique vit dans le PLC externe.
##
## Controles : B = poser une boite ; clic gauche + souris = orbiter ;
## molette = zoom.

const FactoryBuilder = preload("res://simulation/factory_builder.gd")

const BELT_COLOR := Color(0.25, 0.27, 0.30)
const FRAME_COLOR := Color(0.55, 0.25, 0.08)
const BOX_COLOR := Color(0.85, 0.65, 0.15)
const SENSOR_OFF := Color(0.35, 0.08, 0.08)
const SENSOR_ON := Color(0.95, 0.15, 0.15)

# Dimensions du hall (le convoyeur occupe x=0..length, axe X)
const HALL_MIN_X := -5.0
const HALL_MAX_X := 7.0
const HALL_MIN_Z := -4.5
const HALL_MAX_Z := 4.5
const HALL_HEIGHT := 4.0

var factory: Dictionary = {}
var engine = null
var io = null
var conveyor = null
var timestep := 1.0 / 60.0
var accumulator := 0.0
var auto_box := false
var box_timer := 0.0
var capture_mode := false

var box_visual: MeshInstance3D
var entry_lamp: MeshInstance3D
var exit_lamp: MeshInstance3D
var hud = null


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
            # Prise de vue automatique (preuve visuelle / CI) : capture apres
            # 1,5 s puis quitte. Usage : godot --path simulator -- --capture
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
        if link.listen(port) != Error.OK:
            push_error("ecoute Modbus impossible sur le port " + str(port))
            get_tree().quit(1)
            return
        print("Modbus TCP esclave actif : port ", port, ", unit id ", link.server.unit_id)

    var belt_length := 2.0
    if conveyor != null:
        belt_length = conveyor.length
    _build_hall(belt_length)
    _build_visuals()
    hud = get_node_or_null(^"HUD")
    if hud != null:
        hud.setup(io, link)

    if conveyor != null:
        conveyor.spawn_box()
    print("Scene prete. B : poser une boite ; clic gauche : orbiter ; molette : zoom.")
    if capture_mode:
        _capture_and_quit()


## Capture le rendu apres un court delai (le temps que la boite avance un peu).
func _capture_and_quit() -> void:
    await get_tree().create_timer(1.5).timeout
    var image := get_viewport().get_texture().get_image()
    image.save_png("res://capture_3d.png")
    print("Capture ecrite : res://capture_3d.png")
    get_tree().quit(0)


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


func _process(_delta: float) -> void:
    _sync_visuals()
    if hud != null:
        hud.refresh()


func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_B:
        if conveyor != null and conveyor.spawn_box():
            print("Boite posee sur le capteur d'entree.")


## Hall industriel : sol beton, murs, plafond avec poutrelles et luminaires,
## porte, extincteurs, marquage de securite. Tout est procedural (ADR-013) -
## aucun asset externe sous copyright.
func _build_hall(belt_length: float) -> void:
    var hall_w: float = HALL_MAX_X - HALL_MIN_X
    var hall_d: float = HALL_MAX_Z - HALL_MIN_Z
    var center_x: float = (HALL_MIN_X + HALL_MAX_X) / 2.0
    var center_z: float = (HALL_MIN_Z + HALL_MAX_Z) / 2.0

    # Eclairage d'ambiance (le plafond ferme la scene)
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.05, 0.06, 0.08)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.55, 0.56, 0.6)
    env.ambient_light_energy = 0.7
    world_env.environment = env
    add_child(world_env)

    var concrete := StandardMaterial3D.new()
    concrete.albedo_color = Color(0.42, 0.42, 0.44)
    var wall_mat := StandardMaterial3D.new()
    wall_mat.albedo_color = Color(0.72, 0.74, 0.76)
    var plinth_mat := StandardMaterial3D.new()
    plinth_mat.albedo_color = Color(0.30, 0.33, 0.36)
    var beam_mat := StandardMaterial3D.new()
    beam_mat.albedo_color = Color(0.45, 0.48, 0.52)
    var yellow_mat := StandardMaterial3D.new()
    yellow_mat.albedo_color = Color(0.9, 0.75, 0.05)

    # Sol (beton) - remplace le grand plan neutre de la premiere version
    var floor_mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(hall_w, hall_d)
    floor_mesh.mesh = plane
    floor_mesh.position = Vector3(center_x, 0, center_z)
    floor_mesh.material_override = concrete
    add_child(floor_mesh)

    # Marquage de securite : deux bandes jaunes le long du convoyeur
    for z in [-0.65, 0.65]:
        var strip := MeshInstance3D.new()
        var strip_box := BoxMesh.new()
        strip_box.size = Vector3(belt_length + 0.4, 0.005, 0.12)
        strip.mesh = strip_box
        strip.position = Vector3(belt_length / 2.0, 0.003, z)
        strip.material_override = yellow_mat
        add_child(strip)

    # Murs (4) + plinthe
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
        var wall := MeshInstance3D.new()
        var wall_box := BoxMesh.new()
        wall_box.size = Vector3(size.x, size.y, 0.15) if along_x else Vector3(0.15, size.y, size.x)
        wall.mesh = wall_box
        wall.position = pos
        wall.material_override = wall_mat
        add_child(wall)
        # Plinthe sombre en pied de mur
        var plinth := MeshInstance3D.new()
        var plinth_box := BoxMesh.new()
        plinth_box.size = Vector3(size.x, 0.4, 0.18) if along_x else Vector3(0.18, 0.4, size.x)
        plinth.mesh = plinth_box
        plinth.position = pos + Vector3(0, -(HALL_HEIGHT / 2.0 - 0.2), 0)
        plinth.material_override = plinth_mat
        add_child(plinth)

    # Porte sur le mur x = HALL_MIN_X (encadrement + vantail)
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

    # Plafond + poutrelles + luminaires
    var ceiling := MeshInstance3D.new()
    var ceiling_plane := PlaneMesh.new()
    ceiling_plane.size = Vector2(hall_w, hall_d)
    ceiling.mesh = ceiling_plane
    ceiling.rotation = Vector3(PI, 0, 0)
    ceiling.position = Vector3(center_x, HALL_HEIGHT, center_z)
    ceiling.material_override = plinth_mat
    add_child(ceiling)

    for x in [HALL_MIN_X + 2.0, center_x, HALL_MAX_X - 2.0]:
        var beam := MeshInstance3D.new()
        var beam_box := BoxMesh.new()
        beam_box.size = Vector3(0.25, 0.3, hall_d)
        beam.mesh = beam_box
        beam.position = Vector3(x, HALL_HEIGHT - 0.15, center_z)
        beam.material_override = beam_mat
        add_child(beam)

    var lamp_mat := StandardMaterial3D.new()
    lamp_mat.emission_enabled = true
    lamp_mat.emission = Color(1.0, 0.97, 0.85)
    lamp_mat.emission_energy_multiplier = 2.5
    lamp_mat.albedo_color = Color(0.9, 0.9, 0.85)
    for x in [center_x - 2.5, center_x + 2.5]:
        var lamp := MeshInstance3D.new()
        var lamp_box := BoxMesh.new()
        lamp_box.size = Vector3(1.2, 0.08, 0.25)
        lamp.mesh = lamp_box
        lamp.position = Vector3(x, HALL_HEIGHT - 0.45, center_z)
        lamp.material_override = lamp_mat
        add_child(lamp)
        var light := OmniLight3D.new()
        light.position = Vector3(x, HALL_HEIGHT - 0.7, center_z)
        light.omni_range = 7.0
        light.light_energy = 1.1
        light.light_color = Color(1.0, 0.97, 0.9)
        add_child(light)

    # Extincteurs muraux (2) avec panneau
    _build_extinguisher(Vector3(HALL_MIN_X + 0.12, 0, -2.5), 0.0)
    _build_extinguisher(Vector3(HALL_MAX_X - 0.12, 0, 2.5), PI)


func _build_extinguisher(anchor: Vector3, wall_rotation: float) -> void:
    var red := StandardMaterial3D.new()
    red.albedo_color = Color(0.82, 0.05, 0.05)
    var black := StandardMaterial3D.new()
    black.albedo_color = Color(0.05, 0.05, 0.05)
    var sign_red := StandardMaterial3D.new()
    sign_red.emission_enabled = true
    sign_red.albedo_color = Color(0.85, 0.1, 0.1)
    sign_red.emission = Color(0.6, 0.02, 0.02)
    var white := StandardMaterial3D.new()
    white.albedo_color = Color(0.92, 0.92, 0.92)

    var pivot := Node3D.new()
    pivot.position = anchor
    pivot.rotation.y = wall_rotation
    add_child(pivot)

    # Panneau "extincteur" au-dessus
    var sign := MeshInstance3D.new()
    var sign_box := BoxMesh.new()
    sign_box.size = Vector3(0.03, 0.3, 0.3)
    sign.mesh = sign_box
    sign.position = Vector3(0, 2.1, 0)
    sign.material_override = sign_red
    pivot.add_child(sign)

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

    # Poignee noire + base
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
    # Support mural
    var bracket := MeshInstance3D.new()
    var bracket_box := BoxMesh.new()
    bracket_box.size = Vector3(0.03, 0.5, 0.12)
    bracket.mesh = bracket_box
    bracket.position = Vector3(0.01, 1.35, 0)
    bracket.material_override = white
    pivot.add_child(bracket)


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

    # Sol, murs, plafond, extincteurs : cf. _build_hall()

    # Bande du convoyeur
    var belt := MeshInstance3D.new()
    var belt_box := BoxMesh.new()
    belt_box.size = Vector3(belt_length, 0.1, 0.6)
    belt.mesh = belt_box
    belt.position = Vector3(belt_length / 2.0, 0.45, 0)
    var belt_mat := StandardMaterial3D.new()
    belt_mat.albedo_color = BELT_COLOR
    belt.material_override = belt_mat
    add_child(belt)

    # Chassis (deux longerres) et pieds, meme materiau
    var frame_mat := StandardMaterial3D.new()
    frame_mat.albedo_color = FRAME_COLOR
    for z in [-0.32, 0.32]:
        var rail := MeshInstance3D.new()
        var rail_box := BoxMesh.new()
        rail_box.size = Vector3(belt_length + 0.1, 0.25, 0.05)
        rail.mesh = rail_box
        rail.position = Vector3(belt_length / 2.0, 0.28, z)
        rail.material_override = frame_mat
        add_child(rail)

    for x in [0.25, belt_length / 2.0, belt_length - 0.25]:
        for z in [-0.25, 0.25]:
            var foot := MeshInstance3D.new()
            var foot_box := BoxMesh.new()
            foot_box.size = Vector3(0.06, 0.3, 0.06)
            foot.mesh = foot_box
            foot.position = Vector3(x, 0.15, z)
            foot.material_override = frame_mat
            add_child(foot)

    # Capteurs : potes lateraux + lampes sur la bande
    entry_lamp = _build_sensor(entry_x, "capteur_entree")
    exit_lamp = _build_sensor(exit_x, "capteur_sortie")

    # Boite virtuelle
    box_visual = MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = Vector3(box_size, box_size, box_size)
    box_visual.mesh = box_mesh
    var box_mat := StandardMaterial3D.new()
    box_mat.albedo_color = BOX_COLOR
    box_visual.material_override = box_mat
    add_child(box_visual)


func _build_sensor(x_position: float, sensor_name: String) -> MeshInstance3D:
    var post := MeshInstance3D.new()
    var post_mesh := BoxMesh.new()
    post_mesh.size = Vector3(0.05, 0.75, 0.05)
    post.mesh = post_mesh
    post.position = Vector3(x_position, 0.375, 0.4)
    var post_mat := StandardMaterial3D.new()
    post_mat.albedo_color = Color(0.1, 0.1, 0.1)
    post.material_override = post_mat
    add_child(post)

    var lamp := MeshInstance3D.new()
    var lamp_mesh := BoxMesh.new()
    lamp_mesh.size = Vector3(0.08, 0.08, 0.25)
    lamp.mesh = lamp_mesh
    lamp.position = Vector3(x_position, 0.72, 0.28)
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
        # Dessus de la bande a y=0.50, demi-boite 0.10 -> centre a 0.60.
        box_visual.position = Vector3(
            conveyor.box_position - conveyor.box_length / 2.0, 0.60, 0
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
