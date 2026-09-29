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

    # Sol
    var floor_mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(20, 20)
    floor_mesh.mesh = plane
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color(0.20, 0.22, 0.24)
    floor_mesh.material_override = floor_mat
    add_child(floor_mesh)

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
