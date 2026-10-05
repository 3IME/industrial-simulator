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
const SIGN_SORTIE := "res://assets/safety/sign_sortie_secours.png"
const SIGN_DAE := "res://assets/safety/sign_dae.png"
const SIGN_RASSEMBLEMENT := "res://assets/safety/sign_rassemblement.png"
const HUMM_SOUND := "res://assets/sounds/annonces/humm.mp3"
const HUMM_PORTEE := 5.0        # audible a 5 m
const HUMM_VOLUME_MAX := -2.0   # dB a bout portant
const FUMEE_MAX_PARTICLES := 3000
const FUMEE_VITESSE := 0.06     # taux de remplissage par seconde
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
const PROP_TOOL_TROLLEYS := "res://assets/props/tool_trolleys.glb"
const PROP_STRETCHFAB := "res://assets/props/stretchfab.glb"
const PROP_STORAGE_CART := "res://assets/props/storage_cart.glb"
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
const PROP_TRANSPALLET := "res://assets/props/transpallet.glb"
const PROP_WORK_TABLE_BLUE := "res://assets/props/work_table_blue.glb"
const PROP_WOODEN_PALLET := "res://assets/props/wooden_pallet1.glb"
const PROP_SCHOOL_CABINET := "res://assets/props/school_cabinet.glb"
const PROP_COMPUTER_ROOM := "res://assets/props/computer_room.glb"
const PROP_STEEL_BIN := "res://assets/props/steel_bin.glb"
const PROP_WELDING := "res://assets/props/welding_machine.glb"
const PROP_VF_2TR := "res://assets/props/vf_2tr.glb"
const PROP_VF_2TR_MED := "res://assets/props/vf_2tr_med.glb"
const PROP_VF_2TR_LOW := "res://assets/props/vf_2tr_low.glb"
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
        "res://assets/textures/fire_01.png",
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
var _fn_close_requested: Callable   # deconnectee dans _exit_tree
var _dans_wc := false
var _dans_classe := false
var _alarme_active := false
var _en_confinement := false
var _cctv = null
var _cctv_composite: SubViewport = null
var _cctv_flux: Array[SubViewport] = []   # 4 SubViewport individuels
var _cctv_cams: Array[Camera3D] = []
var _cctv_orig: Array[Vector3] = []
var _cctv_recs: Array[ColorRect] = []
var _cctv_mats: Array[ShaderMaterial] = []
var _cctv_labels: Array[Label] = []
var _cctv_perte: Array[Label] = []
var _cctv_temps := 0.0
var _cctv_ecran: MeshInstance3D = null
var _cctv_composite_a_assigner: SubViewport = null
var _cctv_frames_attente := 0
var _humm_player: AudioStreamPlayer3D = null
var _chaudiere_player: AudioStreamPlayer3D = null
var _fumee_parts: Array[GPUParticles3D] = []
var _fumee_niveau := 0.0        # 0 = rien, 1 = usine remplie
var _gyrophare_pivots: Array[Node3D] = []
var _gyrophare_roues: Array[Node3D] = []   # girophares muraux : tournent sur leur axe
var _lumiere_bureau: OmniLight3D = null
var _lumieres_classe: Array[OmniLight3D] = []
var _interrupteur_classe_son: AudioStreamPlayer3D = null
var _interrupteur_son: AudioStreamPlayer3D = null
var _chasse_son: AudioStreamPlayer3D = null
var _lavabo_son: AudioStreamPlayer3D = null
var _gyrophare_spots: Array[SpotLight3D] = []
var _fumee_active := false
var _fumee_ramp_gris: GradientTexture1D = null
var _fumee_ramp_vert: GradientTexture1D = null
var _flammes: GPUParticles3D = null
var _flammes_light: OmniLight3D = null
var sprinklers: SprinklerManager = null
var _eau_son: AudioStreamPlayer = null
var _etiquette_sprinkler: Label3D = null
var _lumieres_rouges := false
var _lumieres_originales: Array = []   # [{node, color, energy}]
var _env_originale := {}               # {color, energy}
var _code_saisi := ""
var _mode_code := false
var _video_jouee := false
var _video_vp: SubViewport = null
var _keypad_led_rouge: OmniLight3D = null
var _keypad_led_verte: OmniLight3D = null
var _verre_player: AudioStreamPlayer = null
var _alarme_player: AudioStreamPlayer = null
var _adult_check := 0.0
var _extinguisher_model: PackedScene = null
var player_node: Node3D = null

var box_visual: Node3D
var entry_lamp: MeshInstance3D
var exit_lamp: MeshInstance3D
var hud = null
var lod_manager: LodManager = null
var _robot_view: Node3D = null


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
    lod_manager = LodManager.new()
    add_child(lod_manager)
    _build_hall(belt_length)
    _build_visuals()
    _spawn_robot()
    _spawn_player()

    hud = get_node_or_null(^"HUD")
    if hud != null:
        hud.setup(io, link)

    if conveyor != null:
        conveyor.spawn_box()
    # Ceinture de securite : liberer la souris si la fenetre se ferme.
    # Callable stocke : la racine SURVIT a un rechargement de scene, la
    # connexion serait sinon accumulee a chaque reload -> debranchee dans
    # _exit_tree().
    _fn_close_requested = func() -> void: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    get_tree().root.close_requested.connect(_fn_close_requested)
    print("Scene prete. Fleches : marcher | souris : regarder | Maj : courir | Ctrl : baisser | Espace : saut | B : boite | annonces : boutons du decor (boite 5BP, alarmes) | clic porte usine : quitter | clic bureau : entrer | clic urgence : alarme (M : couper)")
    if lod_manager != null:
        # Zones mutuellement exclusives : dans le bureau -> atelier masque,
        # dans l'atelier -> bureau masque, dans le hall -> tout visible.
        var z_bureau: int = lod_manager.register_zone("bureau",
            AABB(Vector3(-59.0, -1.0, -66.5), Vector3(9.5, 5.0, 11.0)))
        var z_atelier: int = lod_manager.register_zone("atelier",
            AABB(Vector3(50.0, -1.0, -17.0), Vector3(12.0, 8.0, 33.0)))
        lod_manager.zone_exclusive(z_bureau, z_atelier)
        var z_wc: int = lod_manager.register_zone("wc",
            AABB(Vector3(-65.9, -1.0, -14.6), Vector3(3.5, 5.0, 3.2)))
        lod_manager.zone_exclusive(z_wc, z_bureau)
        lod_manager.zone_exclusive(z_wc, z_atelier)
        var z_classe: int = lod_manager.register_zone("classe",
            AABB(Vector3(-10.0, -1.0, -54.6), Vector3(11.0, 5.0, 7.2)))
        lod_manager.zone_exclusive(z_classe, z_bureau)
        lod_manager.zone_exclusive(z_classe, z_atelier)
        lod_manager.zone_exclusive(z_classe, z_wc)
        # jamais masques : gyrophares (alerte), robot, joueur
        var exclus_zone: Array = [_robot_view]
        exclus_zone.append_array(_gyrophare_pivots)
        var nb_bureau: int = lod_manager.zone_ramasser_par_position(
            z_bureau, self, exclus_zone)
        var nb_atelier: int = lod_manager.zone_ramasser_par_position(
            z_atelier, self, exclus_zone)
        var nb_wc: int = lod_manager.zone_ramasser_par_position(
            z_wc, self, exclus_zone)
        var nb_classe: int = lod_manager.zone_ramasser_par_position(
            z_classe, self, exclus_zone)
        print("Zones LOD : bureau ", nb_bureau, " objets, atelier ",
            nb_atelier, " objets, wc ", nb_wc, " objets, classe ",
            nb_classe, " objets")
        print("LOD global : ", lod_manager.stats())
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


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_H and hud != null:
            hud.visible = not hud.visible
            return
        if _mode_code:
            _saisir_code(event)
            return
        if event.keycode == KEY_M:
            if _video_jouee:
                _arreter_video()
                return
            if _alarme_active:
                _couper_alarme()
                return
    _clic_interaction(event)


## Clic sur les elements interactifs (raycast depuis la camera) :
## porte d'usine -> quitter ; bureau de chantier -> entrer/sortir.
## (les annonces se declenchent par les boutons/switch du decor ;
## touche M : couper alarme/video)
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
            if not hit_in.is_empty() and hit_in.collider is StaticBody3D                     and hit_in.collider.has_meta("interaction"):
                if hit_in.collider.get_meta("interaction") == "porte_bureau_interieur":
                    _sortir_bureau()
                elif hit_in.collider.get_meta("interaction") == "alarme_incendie":
                    _declencher_alarme(hit_in.position)
                elif hit_in.collider.get_meta("interaction") == "confinement":
                    _declencher_confinement()
                elif hit_in.collider.get_meta("interaction") == "evacuation":
                    _declencher_evacuation_bouton()
                elif String(hit_in.collider.get_meta("interaction")).begins_with("bouton_boite_"):
                    _bouton_boite(int(str(hit_in.collider.get_meta("interaction")).split("_")[-1]))
                elif hit_in.collider.get_meta("interaction") == "keypad_code":
                    _activer_keypad()
                elif hit_in.collider.get_meta("interaction") == "interrupteur_bureau":
                    _basculer_lumiere_bureau()
                elif hit_in.collider.get_meta("interaction") == "switch_sprinkler":
                    _basculer_sprinklers()
        return
    if _dans_classe:
        var cam_cl := get_viewport().get_camera_3d()
        if cam_cl != null:
            var q_cl := PhysicsRayQueryParameters3D.create(
                cam_cl.global_position,
                cam_cl.global_position - cam_cl.global_transform.basis.z * 6.0)
            var hit_cl: Dictionary = get_world_3d().direct_space_state.intersect_ray(q_cl)
            if not hit_cl.is_empty() and hit_cl.collider is StaticBody3D                     and hit_cl.collider.has_meta("interaction")                 and hit_cl.collider.get_meta("interaction") == "porte_classe_sortie":
                _sortir_classe()
            elif hit_cl.collider.get_meta("interaction") == "interrupteur_classe":
                _basculer_lumiere_classe()
        return
    if _dans_wc:
        var cam_wc := get_viewport().get_camera_3d()
        if cam_wc != null:
            var q_wc := PhysicsRayQueryParameters3D.create(
                cam_wc.global_position,
                cam_wc.global_position - cam_wc.global_transform.basis.z * 6.0)
            var hit_wc: Dictionary = get_world_3d().direct_space_state.intersect_ray(q_wc)
            if not hit_wc.is_empty() and hit_wc.collider is StaticBody3D                     and hit_wc.collider.has_meta("interaction"):
                if hit_wc.collider.get_meta("interaction") == "porte_wc_sortie":
                    _sortir_wc()
                elif hit_wc.collider.get_meta("interaction") == "toilettes_wc":
                    _tirer_chasse()
                elif hit_wc.collider.get_meta("interaction") == "lavabo_wc":
                    _ouvrir_robinet()
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
    # Un brise-vitre se casse a bout de bras : portee courte imposee.
    var collider = impact.collider
    if (collider.get_meta("interaction") == "alarme_incendie"
            or collider.get_meta("interaction") == "confinement")             and cam.global_position.distance_to(impact.position) > 2.5:
        print("Trop loin : approchez-vous du boitier")
        return
    if collider.get_meta("interaction") == "porte_usine":
        print("Porte de l'usine : sortie du simulateur")
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        get_tree().quit(0)
    elif collider.get_meta("interaction") == "bureau":
        _entrer_bureau()
    elif collider.get_meta("interaction") == "porte_wc":
        _entrer_wc()
    elif collider.get_meta("interaction") == "porte_classe":
        _entrer_classe()
    elif collider.get_meta("interaction") == "switch_sprinkler":
        _basculer_sprinklers()
    elif collider.get_meta("interaction") == "alarme_incendie":
        _declencher_alarme(impact.position)
    elif collider.get_meta("interaction") == "confinement":
        _declencher_confinement()
    elif collider.get_meta("interaction") == "evacuation":
        _declencher_evacuation_bouton()
    elif String(collider.get_meta("interaction")).begins_with("bouton_boite_"):
        _bouton_boite(int(str(collider.get_meta("interaction")).split("_")[-1]))
    elif collider.get_meta("interaction") == "keypad_code":
        _activer_keypad()


func _maj_rendu_cctv() -> void:
    ## Les 5 SubViewport CCTV (composite + 4 flux) ne rendent QUE quand le
    ## joueur est dans le bureau : la TV n'est visible que la-bas, on
    ## economise 5 rendus 3D complets en permanence ailleurs.
    var mode := SubViewport.UPDATE_ALWAYS if _dans_bureau         else SubViewport.UPDATE_DISABLED
    if _cctv_composite != null:
        _cctv_composite.render_target_update_mode = mode
    for vp in _cctv_flux:
        vp.render_target_update_mode = mode


func _basculer_sprinklers() -> void:
    ## Switch a couteaux du bureau : marche/arret du reseau sprinklers.
    ## Appelle depuis les DEUX chaines d'interaction (bureau + generale).
    if sprinklers == null:
        return
    sprinklers.set_arme(not sprinklers.arme)
    var clic_sw = load("res://assets/sounds/button-press.mp3")
    if clic_sw != null and _verre_player != null:
        _verre_player.stream = clic_sw
        _verre_player.play()
    print("SPRINKLERS : ", "ARMES" if sprinklers.arme else "HORS SERVICE")


func _entrer_bureau() -> void:
    if player_node != null:
        player_node.position = Vector3(-54.9, 0.2, -57.5)
        player_node.rotation.y = 0.0          # regarde le fond de la piece (bureau)
    _dans_bureau = true
    _maj_rendu_cctv()
    print("Bureau de chantier : entree")


func _entrer_wc() -> void:
    if player_node != null:
        player_node.position = Vector3(-63.4, 0.2, -13.0)
        player_node.rotation.y = PI / 2.0    # regarde le fond (ouest)
    _dans_wc = true
    print("Local WC : entree")


func _sortir_wc() -> void:
    if player_node != null:
        player_node.position = Vector3(-56.8, 0.2, -13.0)
        player_node.rotation.y = PI / 2.0    # face a la porte WC du hall
    _dans_wc = false
    print("Local WC : sortie")


func _entrer_classe() -> void:
    if player_node != null:
        player_node.position = Vector3(-4.5, 0.2, -48.7)
        player_node.rotation.y = 0.0        # regarde le fond de la classe
    _dans_classe = true
    print("Classe : entree")


func _sortir_classe() -> void:
    if player_node != null:
        player_node.position = Vector3(-4.5, 3.2, -43.6)
        player_node.rotation.y = 0.0        # sur la mezzanine, face a la porte
    _dans_classe = false
    print("Classe : sortie")


func _sortir_bureau() -> void:
    if player_node != null:
        player_node.position = Vector3(-54.5, 0.2, -30.0)
        player_node.rotation.y = PI / 2.0     # regarde le mur (la cabine)
    _dans_bureau = false
    _maj_rendu_cctv()
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
    _fumee_verte(false)
    _fumee_active = true
    if _flammes != null:
        _flammes.amount = 120
        _flammes.emitting = true
        if sprinklers != null:
            sprinklers.set_feu(_flammes.position, true)
    if _flammes_light != null:
        _flammes_light.light_energy = 2.0
    await get_tree().create_timer(0.9).timeout
    if not _alarme_active:
        return
    var flux = load("res://assets/sounds/annonces/evacuation_incendie.mp3")
    if flux != null and _alarme_player != null:
        flux.loop = true
        _alarme_player.stream = flux
        _alarme_player.play()
        print("Evacuation incendie en boucle — touche M pour couper")


func _fumee_verte(actif: bool) -> void:
    ## Fumee VERTE pendant le confinement, grise pour l'incendie.
    if _fumee_ramp_vert == null or _fumee_ramp_gris == null:
        return
    for part in _fumee_parts:
        var mat_p: ParticleProcessMaterial = part.process_material
        mat_p.color_ramp = _fumee_ramp_vert if actif else _fumee_ramp_gris


func _couper_alarme() -> void:
    _alarme_active = false
    _en_confinement = false
    _fumee_active = false
    _fumee_verte(false)
    if _flammes != null:
        _flammes.emitting = false
        _flammes.amount = 0
    if sprinklers != null:
        sprinklers.set_feu(Vector3.ZERO, false)
    if _flammes_light != null:
        _flammes_light.light_energy = 0.0
    if _cctv_mats.size() > 3:
        _cctv_mats[3].set_shader_parameter("alarme", 0.0)
    if _cctv_perte.size() > 3:
        _cctv_perte[3].visible = false
    if _alarme_player != null:
        _alarme_player.stop()
    print("Alarme coupee")


## Clavier a code : clic pour activer, chiffres au clavier, code 2027.
## La video Nostromo est chargee A LA DEMANDE (peu utilisee).
const CODE_SECRET := "2027"

func _activer_keypad() -> void:
    _mode_code = true
    _code_saisi = ""
    _maj_leds()
    print("KEYPAD : saisissez 4 chiffres (Echap pour annuler)")

func _maj_leds() -> void:
    if _keypad_led_rouge != null:
        _keypad_led_rouge.light_energy = 0.0 if _mode_code else 1.5
    if _keypad_led_verte != null:
        _keypad_led_verte.light_energy = 1.5 if _mode_code else 0.0

func _saisir_code(event: InputEventKey) -> void:
    if event.keycode == KEY_ESCAPE:
        _mode_code = false
        _code_saisi = ""
        _maj_leds()
        print("KEYPAD : annule")
        return
    var chiffre = event.unicode - 48  # code ASCII '0' = 48
    if chiffre < 0 or chiffre > 9:
        return
    _code_saisi += str(chiffre)
    print("KEYPAD : ", _code_saisi)
    if _code_saisi.length() >= 4:
        _mode_code = false
        _maj_leds()
        if _code_saisi == CODE_SECRET:
            print("KEYPAD : code accepte — lecture video")
            _jouer_video_nostromo()
        else:
            print("KEYPAD : code refuse")
        _code_saisi = ""

## Passage en alerte rouge : toutes les lumieres de l'usine et du bureau.
func _lumieres_alerte_rouge() -> void:
    if _lumieres_rouges:
        return
    _lumieres_rouges = true
    _lumieres_originales = []
    var rouge := Color(1.0, 0.1, 0.05)
    for enfant in find_children("*", "Light3D", true, false):
        if enfant is OmniLight3D or enfant is DirectionalLight3D:
            _lumieres_originales.append({
                "node": enfant,
                "color": enfant.light_color,
                "energy": enfant.light_energy,
            })
            enfant.light_color = rouge
            enfant.light_energy = maxf(enfant.light_energy, 0.5)
    # ambiance rouge
    var env_nodes := find_children("*", "WorldEnvironment", true, false)
    for env_node in env_nodes:
        var env: Environment = env_node.environment
        if env != null:
            _env_originale = {
                "color": env.ambient_light_color,
                "energy": env.ambient_light_energy,
            }
            env.ambient_light_color = Color(0.4, 0.05, 0.03)
            env.ambient_light_energy = 0.5
    print("ALERTES : lumieres rouges")


## Restauration des lumieres d'origine.
func _lumieres_restauration() -> void:
    if not _lumieres_rouges:
        return
    _lumieres_rouges = false
    for sauvegarde in _lumieres_originales:
        var node: Light3D = sauvegarde["node"]
        if is_instance_valid(node):
            node.light_color = sauvegarde["color"]
            node.light_energy = sauvegarde["energy"]
    if not _env_originale.is_empty():
        var env_nodes2 := find_children("*", "WorldEnvironment", true, false)
        for env_node2 in env_nodes2:
            var env2: Environment = env_node2.environment
            if env2 != null:
                env2.ambient_light_color = _env_originale["color"]
                env2.ambient_light_energy = _env_originale["energy"]
    _lumieres_originales = []
    print("ALERTES : lumieres restaurees")


func _jouer_video_nostromo() -> void:
    if _video_jouee:
        return
    var flux = load("res://assets/videos/nostromo_destruct.ogv")
    if flux == null:
        push_warning("video .ogv introuvable")
        return
    _video_jouee = true
    _lumieres_alerte_rouge()
    print("VIDEO : Nostromo — touche M pour revenir aux cameras")
    # SubViewport pour la video, assigne a l'ecran via le mechanisme differe
    var vp_vid := SubViewport.new()
    vp_vid.size = Vector2i(640, 360)
    vp_vid.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(vp_vid)
    # fond noir pour couvrir tout le viewport
    var fond_noir := ColorRect.new()
    fond_noir.color = Color(0, 0, 0)
    fond_noir.size = Vector2(640, 360)
    vp_vid.add_child(fond_noir)
    var lecteur := VideoStreamPlayer.new()
    lecteur.stream = flux
    lecteur.autoplay = true
    # VideoStreamTheora n'a pas get_size() — remplir le viewport,
    # le lecteur preserve le ratio avec expand_mode par defaut
    lecteur.expand = true
    lecteur.size = Vector2(640, 360)
    vp_vid.add_child(lecteur)
    _video_vp = vp_vid
    # declencher la re-assignation du materiau de l'ecran
    _cctv_composite_a_assigner = vp_vid
    _cctv_frames_attente = 0


func _arreter_video() -> void:
    _video_jouee = false
    _lumieres_restauration()
    if _video_vp != null:
        _video_vp.queue_free()
        _video_vp = null
    # retablir le composite CCTV sur l'ecran
    if _cctv_composite != null:
        _cctv_composite_a_assigner = _cctv_composite
        _cctv_frames_attente = 0
    print("VIDEO : arretee — retour aux cameras")


const ANNONCES_BOITE := [
    "res://assets/sounds/annonces/camion.mp3",
    "res://assets/sounds/annonces/fumer.mp3",
    "res://assets/sounds/annonces/maintenance.mp3",
    "res://assets/sounds/annonces/presse.mp3",
    "res://assets/sounds/annonces/zone_production.mp3",
]


func _bouton_boite(index: int) -> void:
    if index < 0 or index >= ANNONCES_BOITE.size():
        return
    print("Boite 5BP : bouton ", index + 1)
    var flux = load(ANNONCES_BOITE[index])
    if flux != null and _annonce_player != null:
        _annonce_player.stream = flux
        _annonce_player.play()


## Bouton d'evacuation (meme principe que le confinement) : boucle
## d'evacuation.mp3, coupure par la touche M.
func _declencher_evacuation_bouton() -> void:
    _alarme_active = true
    _en_confinement = false
    print("BOUTON EVACUATION")
    var clic = load("res://assets/sounds/annonces/bouton_au.mp3")
    var attente := 0.6
    if clic != null and _verre_player != null:
        _verre_player.stream = clic
        _verre_player.play()
        attente = clic.get_length() + 0.2
    await get_tree().create_timer(attente).timeout
    if not _alarme_active or _en_confinement:
        return
    var flux = load("res://assets/sounds/annonces/evacuation.mp3")
    if flux != null and _alarme_player != null:
        flux.loop = true
        _alarme_player.stream = flux
        _alarme_player.play()
        print("Evacuation en boucle — touche M pour couper")


## Arret d'urgence : annonce de confinement en boucle (touche M).
func _declencher_confinement() -> void:
    _alarme_active = true
    _en_confinement = true
    _fumee_verte(true)
    _fumee_active = true
    if _cctv_mats.size() > 3:
        _cctv_mats[3].set_shader_parameter("alarme", 1.0)
    if _cctv_perte.size() > 3:
        _cctv_perte[3].visible = true
    print("ARRET D'URGENCE : confinement annonce")
    # Clic du bouton d'abord, puis boucle de confinement
    var clic = load("res://assets/sounds/annonces/bouton_au.mp3")
    var attente := 0.6
    if clic != null and _verre_player != null:
        _verre_player.stream = clic
        _verre_player.play()
        attente = clic.get_length() + 0.2
    await get_tree().create_timer(attente).timeout
    if not _alarme_active:
        return
    var flux = load("res://assets/sounds/annonces/confinement.mp3")
    if flux != null and _alarme_player != null:
        flux.loop = true
        _alarme_player.stream = flux
        _alarme_player.play()
        print("Confinement en boucle — touche M pour couper")


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
        # SceneTreeTimer survit au noeud : garder la validite avant free
        # (sinon warning "previously freed" si la scene quitte < 3 s)
        get_tree().create_timer(3.0).timeout.connect(
            func() -> void:
                if is_instance_valid(eclat):
                    eclat.queue_free())


func _exit_tree() -> void:
    ## La racine survit a la scene : sans deconnexion, un rechargement de
    ## main.gd accumulerait les lambdas sur close_requested.
    var racine := get_tree().root if get_tree() != null else null
    if racine != null and _fn_close_requested.is_valid()             and racine.close_requested.is_connected(_fn_close_requested):
        racine.close_requested.disconnect(_fn_close_requested)


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
    if lod_manager != null and player_node != null:
        lod_manager.setup_si_absent(player_node)

    # Gyrophares (bureau + 16 murs) : rotation ~1,4 tour/s, faisceaux bleus
    # horizontaux qui pulsent pendant l'alerte (incendie/evac/confinement)
    if _alarme_active:
        var energie := 12.0 + 6.0 * sin(Time.get_ticks_msec() * 0.012)
        for pivot: Node3D in _gyrophare_pivots:
            pivot.rotation.y += delta * 9.0
        for roue: Node3D in _gyrophare_roues:
            roue.rotate_object_local(Vector3.UP, delta * 9.0)
        for faisceau: SpotLight3D in _gyrophare_spots:
            faisceau.visible = true
            faisceau.light_energy = energie
    else:
        for faisceau: SpotLight3D in _gyrophare_spots:
            faisceau.visible = false
    # Garde-fou periodique : si l'echelle rendue de l'adulte derive
    # (quel que soit la cause), elle est recallee en moins de 2 s.
    if _adult_node != null:
        _adult_check += delta
        if _adult_check >= 2.0:
            _adult_check = 0.0
            _clamp_prop_height(_adult_node, 1.60, "adulte")
    # Dump debug du composite (une seule fois, frame 5)
    if _cctv_composite != null and _cctv_frames_attente < 5:
        _cctv_frames_attente += 1
        if _cctv_frames_attente == 5:
            var img_dbg = _cctv_composite.get_texture().get_image()
            img_dbg.save_png("res://debug_composite.png")
            print("DBG composite dump : ", img_dbg.get_size())

    # Texture CCTV : attendre 3 frames puis assigner + dump debug
    if _cctv_composite_a_assigner != null:
        _cctv_frames_attente += 1

        if _cctv_frames_attente >= 3:
            var tex_cctv = _cctv_composite_a_assigner.get_texture()
            if tex_cctv != null:
                var verre := StandardMaterial3D.new()
                verre.albedo_texture = tex_cctv
                verre.emission_enabled = true
                verre.emission_texture = tex_cctv
                verre.emission_energy_multiplier = 0.8
                verre.metallic = 0.6
                verre.roughness = 0.15
                verre.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
                if _cctv_ecran != null:
                    _cctv_ecran.material_override = verre
                _cctv_composite_a_assigner = null
                print("CCTV : texture ", tex_cctv.get_size(), " assignee (frame ",
                    _cctv_frames_attente, ")")

    # Flicker de la lumiere des flammes
    if _flammes_light != null and _flammes_light.light_energy > 0.0:
        var ft := fmod(_cctv_temps * 3.0, 1.0)
        _flammes_light.light_energy = 2.0 + sin(ft * 31.4) * 0.5 + sin(ft * 7.3) * 0.8 + randf() * 0.4

    # Lutte incendie par sprinklers : l'eau maitrise les flammes
    if sprinklers != null:
        if _alarme_active and sprinklers.arrosage_actif                 and _flammes != null and _flammes.amount > 0:
            _flammes.amount = maxi(_flammes.amount - int(round(delta * 10.0)), 0)
            if _flammes.amount == 0:
                _flammes.emitting = false
                sprinklers.set_feu(Vector3.ZERO, false)
                print("INCENDIE : maitrise par les sprinklers")
        if _eau_son != null:
            if sprinklers.arrosage_actif and not _eau_son.playing:
                _eau_son.play()
            elif not sprinklers.arrosage_actif and _eau_son.playing:
                _eau_son.stop()
        if _etiquette_sprinkler != null:
            var txt_e := "SPRINKLERS : HORS SERVICE"
            if sprinklers.arme:
                txt_e = "SPRINKLERS : ARMES"
                if sprinklers.arrosage_actif:
                    txt_e = "SPRINKLERS : LUTTE
%d tete(s) - eau %.1f cm" % [
                        sprinklers.nb_actifs, sprinklers.niveau_eau * 100.0]
            if _etiquette_sprinkler.text != txt_e:
                _etiquette_sprinkler.text = txt_e

    # Fumee : monter progressivement pendant l'alerte, dissiper apres
    if _fumee_active and _fumee_niveau < 1.0:
        _fumee_niveau = minf(_fumee_niveau + delta * FUMEE_VITESSE, 1.0)
    elif not _fumee_active and _fumee_niveau > 0.0:
        _fumee_niveau = maxf(_fumee_niveau - delta * FUMEE_VITESSE * 2.0, 0.0)
    if _fumee_parts.size() > 0:
        var nb: int = int(_fumee_niveau * FUMEE_MAX_PARTICLES / _fumee_parts.size())
        var vis: bool = _fumee_niveau > 0.01
        for fumee in _fumee_parts:
            fumee.amount = nb
            fumee.emitting = vis

    # Animation CCTV : balayage, REC, horloges
    if _cctv_composite != null:
        _cctv_temps += delta
        for i in range(_cctv_cams.size()):
            var vitesse := 0.3 + 0.05 * i
            _cctv_cams[i].rotation.y = _cctv_orig[i].y + sin(_cctv_temps * vitesse) * 0.06
            _cctv_cams[i].rotation.x = _cctv_orig[i].x + sin(_cctv_temps * vitesse * 0.7) * 0.018
        var allume_cctv := fmod(_cctv_temps, 1.0) < 0.6
        for rec in _cctv_recs:
            rec.visible = allume_cctv
        var heure_cctv := Time.get_time_string_from_system().substr(0, 8)
        for hr in _cctv_labels:
            hr.text = heure_cctv

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
    _robot_view = view
    view.position = Vector3(2.6, 0, -1.6)
    view.rotation.y = -PI / 2.0    # portee du bras (+X) tournee vers la bande (+Z)
    add_child(view)
    view.setup(robot_machine)
    if lod_manager != null:
        lod_manager.register_cull(_robot_view, 130.0)
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

    # Table de travail bleue a gauche de la chaudiere
    _place_prop("res://assets/props/work_table.glb",
        Vector3(HALL_MAX_X - 0.75, 0.0, 34.0),
        Vector3(0.0, -PI / 2.0, 0.0), 1.0)
    _add_static_box(Vector3(HALL_MAX_X - 0.75, 0.88, 34.0),
        Vector3(0.87, 1.76, 1.90))

    # Luminaire fluorescent 2 m au-dessus de la table (sommet 1,76 m ->
    # base du luminaire a 3,76 m), dans l'axe de la table, avec sa lumiere
    _place_prop("res://assets/props/fluorescent_fixture.glb",
        Vector3(HALL_MAX_X - 0.75, 3.76, 34.0), Vector3.ZERO, 1.0)
    var luminaire := OmniLight3D.new()
    luminaire.light_color = Color(0.95, 0.98, 1.0)
    luminaire.light_energy = 1.6
    luminaire.omni_range = 9.0
    luminaire.position = Vector3(HALL_MAX_X - 0.75, 3.70, 34.0)
    add_child(luminaire)

    # Flammes de la chaudiere (activees pendant l'alerte incendie)
    _flammes = GPUParticles3D.new()
    _flammes.amount = 60
    _flammes.lifetime = 1.2
    _flammes.position = Vector3(HALL_MAX_X - 0.90, 0.2, 25.0)

    var mat_fl := ParticleProcessMaterial.new()
    mat_fl.direction = Vector3(0, 1, 0)
    mat_fl.spread = 20.0
    mat_fl.initial_velocity_min = 1.0
    mat_fl.initial_velocity_max = 2.0
    mat_fl.gravity = Vector3(0, 1.0, 0)
    mat_fl.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    mat_fl.emission_sphere_radius = 0.2
    mat_fl.radial_velocity_min = 0.0
    mat_fl.radial_velocity_max = 0.5
    mat_fl.scale_min = 0.9
    mat_fl.scale_max = 1.4
    mat_fl.angle_min = -180.0
    mat_fl.angle_max = 180.0
    # Taille : petit -> grand
    var size_c := Curve.new()
    size_c.add_point(Vector2(0.0, 0.2))
    size_c.add_point(Vector2(0.5, 0.8))
    size_c.add_point(Vector2(1.0, 1.4))
    var size_t := CurveTexture.new()
    size_t.curve = size_c
    mat_fl.scale_curve = size_t
    # Alpha : apparition rapide -> fondu long (point cle du tutoriel)
    var alpha_c := Curve.new()
    alpha_c.add_point(Vector2(0.0, 0.0))
    alpha_c.add_point(Vector2(0.15, 1.0))
    alpha_c.add_point(Vector2(0.8, 0.8))
    alpha_c.add_point(Vector2(1.0, 0.0))
    var alpha_t := CurveTexture.new()
    alpha_t.curve = alpha_c
    mat_fl.alpha_curve = alpha_t
    # Couleur : jaune -> orange -> rouge sombre
    var grad_fl := Gradient.new()
    grad_fl.set_color(0, Color(1.0, 0.95, 0.6))
    grad_fl.set_color(1, Color(0.4, 0.05, 0.0))
    grad_fl.add_point(0.3, Color(1.0, 0.6, 0.1))
    grad_fl.add_point(0.6, Color(0.9, 0.2, 0.0))
    var grad_fl_t := GradientTexture1D.new()
    grad_fl_t.gradient = grad_fl
    mat_fl.color_ramp = grad_fl_t
    _flammes.process_material = mat_fl

    var quad_fl := QuadMesh.new()
    quad_fl.size = Vector2(1.5, 1.5)
    var surf_fl := StandardMaterial3D.new()
    surf_fl.albedo_texture = load("res://assets/textures/fire_01.png")
    surf_fl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    surf_fl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    surf_fl.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    surf_fl.vertex_color_use_as_albedo = true
    surf_fl.vertex_color_is_srgb = true
    surf_fl.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    quad_fl.material = surf_fl
    _flammes.draw_pass_1 = quad_fl
    _flammes.emitting = false
    add_child(_flammes)

    # Lumiere orange avec flicker organique (courbe, pas sin())
    _flammes_light = OmniLight3D.new()
    _flammes_light.position = Vector3(HALL_MAX_X - 1.5, 5.0, 25.0)
    _flammes_light.light_color = Color(1.0, 0.5, 0.1)
    _flammes_light.omni_range = 15.0
    _flammes_light.light_energy = 0.0
    add_child(_flammes_light)

    # Emitters de fumee (actives pendant l'alerte incendie)
        # Ramps de couleur partagees : gris (incendie) et vert (confinement)
    var grad_f := Gradient.new()
    grad_f.set_color(0, Color(0.12, 0.12, 0.14))
    grad_f.set_color(1, Color(0.35, 0.35, 0.38))
    _fumee_ramp_gris = GradientTexture1D.new()
    _fumee_ramp_gris.gradient = grad_f
    var grad_v := Gradient.new()
    grad_v.set_color(0, Color(0.05, 0.38, 0.10))
    grad_v.set_color(1, Color(0.40, 0.90, 0.45))
    _fumee_ramp_vert = GradientTexture1D.new()
    _fumee_ramp_vert.gradient = grad_v
    for pos_fumee in [
        Vector3(-20.0, 0.5, -44.0), Vector3(10.0, 0.5, -44.0),
        Vector3(40.0, 0.5, -44.0), Vector3(61.0, 0.5, -15.0),
        Vector3(61.0, 0.5, 15.0), Vector3(-15.0, 0.5, 44.0),
        Vector3(20.0, 0.5, 44.0), Vector3(-57.0, 0.5, 8.0),
        Vector3(-57.0, 0.5, -20.0),
    ]:
        var fumee := GPUParticles3D.new()
        var mat_fumee := ParticleProcessMaterial.new()
        mat_fumee.direction = Vector3(0, 1, 0)
        mat_fumee.spread = 40.0
        mat_fumee.initial_velocity_min = 0.5
        mat_fumee.initial_velocity_max = 1.5
        mat_fumee.gravity = Vector3(0, 1.0, 0)
        mat_fumee.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
        mat_fumee.emission_sphere_radius = 0.5
        mat_fumee.scale_min = 5.0
        mat_fumee.scale_max = 14.0
        mat_fumee.angle_min = -180.0
        mat_fumee.angle_max = 180.0
        # Taille : petit -> tres grand
        var sz_c := Curve.new()
        sz_c.add_point(Vector2(0.0, 0.3))
        sz_c.add_point(Vector2(0.5, 0.9))
        sz_c.add_point(Vector2(1.0, 1.6))
        var sz_t := CurveTexture.new()
        sz_t.curve = sz_c
        mat_fumee.scale_curve = sz_t
        # Alpha : apparition douce -> fondu tres long
        var al_c := Curve.new()
        al_c.add_point(Vector2(0.0, 0.0))
        al_c.add_point(Vector2(0.2, 0.6))
        al_c.add_point(Vector2(0.7, 0.5))
        al_c.add_point(Vector2(1.0, 0.0))
        var al_t := CurveTexture.new()
        al_t.curve = al_c
        mat_fumee.alpha_curve = al_t
        # Couleur : ramp partagee (gris incendie ; bascule verte au confinement)
        mat_fumee.color_ramp = _fumee_ramp_gris
        fumee.process_material = mat_fumee
        var quad_f := QuadMesh.new()
        quad_f.size = Vector2(6, 6)
        var surf_f := StandardMaterial3D.new()
        surf_f.albedo_texture = load("res://assets/textures/fire_01.png")
        surf_f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        surf_f.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        surf_f.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        surf_f.vertex_color_use_as_albedo = true
        surf_f.vertex_color_is_srgb = true
        surf_f.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
        quad_f.material = surf_f
        fumee.draw_pass_1 = quad_f
        fumee.amount = 0
        fumee.lifetime = 8.0
        fumee.position = pos_fumee
        fumee.emitting = false
        add_child(fumee)
        _fumee_parts.append(fumee)

    # Lettres geantes N/S/E/O peintes sur les murs (5 m, style usine ancienne)
    _lettre_mur("N", Vector3(center_x, 10.0, HALL_MIN_Z + 0.10), 0.0)       # Nord = z min
    _lettre_mur("S", Vector3(center_x, 10.0, HALL_MAX_Z - 0.10), PI)        # Sud = z max
    _lettre_mur("E", Vector3(HALL_MAX_X - 0.10, 10.0, center_z), -PI / 2.0)  # Est = x max
    _lettre_mur("O", Vector3(HALL_MIN_X + 0.10, 10.0, center_z), -PI / 2.0) # Ouest = x min

    # Extincteurs muraux : mur du fond (z min) et mur droit (x max)
    for x in [-20.0, 10.0, 40.0]:
        _build_extinguisher(Vector3(x, 0, HALL_MIN_Z + 0.09), -PI / 2.0)
    for z in [-15.0, 15.0]:
        _build_extinguisher(Vector3(HALL_MAX_X - 0.09, 0, z), PI)
    # Mur avant (z max) : deux kits
    for x in [-13.6, 21.4]:
        _build_extinguisher(Vector3(x, 0, HALL_MAX_Z - 0.09), PI / 2.0)
    # Mur gauche : kit a droite de la porte de sortie
    _build_extinguisher(Vector3(HALL_MIN_X + 0.09, 0, -1.2), 0.0)
    _build_securite_signs()

    _build_props()
    _build_alarmes()
    _build_expo()
    _build_expo2()

    # Plancher a 4 m : visuel + collision marchable
    var mez_y := 3.0  # dalle marchable MESUREE a 3,0 m (le haut de
    # l'AABB, 4,0 m, est la rambarde integree du modele, bord sud)
    var mez_z := HALL_MIN_Z + 1.52  # bord nord du deck COLLE au mur
    # (deck 3,04 m de large ; escaliers 1,06 m centres sur mez_z :
    # ils suivent le deck et restent a ~1 m du mur)
    var mez_debut_x := -40.0
    var mez_fin_x := 31.0

    # Plancher visuel (plusieurs sections de 6 m)
    for mx in range(int(mez_debut_x), int(mez_fin_x), 6):
        var seg_len: float = minf(6.0, mez_fin_x - mx)
        _place_prop(PROP_MEZZANINE_FLOOR,
            Vector3(mx + seg_len / 2.0, 0.0, mez_z),
            Vector3.ZERO, 1.0)
    # Collision du plancher : surface fine marchable a y=4.
    # Largeur MESUREE du modele : 3,04 m (l'ancienne collision de 6,0 m
    # laissait flotter le joueur ~1,5 m au-dela du deck visuel)
    _add_static_box(Vector3((mez_debut_x + mez_fin_x) / 2.0, mez_y - 0.1, mez_z),
        Vector3(mez_fin_x - mez_debut_x, 0.2, 3.04))
    # Garde-corps au bord REEL du deck (mez_z + 1,52), plus a +2,9
    _add_static_box(Vector3((mez_debut_x + mez_fin_x) / 2.0, mez_y + 0.55, mez_z + 1.52),
        Vector3(mez_fin_x - mez_debut_x, 1.1, 0.1))
    # Ligne jaune de securite au sol (facon usine) DEVANT la mezzanine,
    # ~70 cm au sud du garde-corps, sur toute la longueur du deck
    var ligne_jaune := MeshInstance3D.new()
    var ligne_box := BoxMesh.new()
    ligne_box.size = Vector3(mez_fin_x - mez_debut_x, 0.012, 0.12)
    var mat_ligne := StandardMaterial3D.new()
    mat_ligne.albedo_color = Color(1.0, 0.82, 0.0)
    mat_ligne.roughness = 0.55
    ligne_box.material = mat_ligne
    ligne_jaune.mesh = ligne_box
    ligne_jaune.position = Vector3((mez_debut_x + mez_fin_x) / 2.0, 0.006, mez_z + 2.2)
    add_child(ligne_jaune)

    # ESCALIERS visuels (positions conservees), montent le long de X vers les
    # extremites ouvertes de la mezzanine (le garde-corps bloque le bord sud).
    # Modele mesure : reculement local Z [-2.03, +1.76] (3.79 m) ; PALIER a
    # y=3,05 m (1 204 sommets) — le 4,07 m de l'AABB n'est que la rambarde.
    # Echelle 0,98 : palier a 3,0 m, pile la hauteur du deck.
    _place_prop(PROP_CELL_STAIR, Vector3(-41.82, 0.0, mez_z),
        Vector3(0.0, PI / 2.0, 0.0), 0.96)
    _place_prop(PROP_CELL_STAIR, Vector3(32.92, 0.0, mez_z),
        Vector3(0.0, -PI / 2.0, 0.0), 0.96)
    # Rampes de collision INVISIBLES : meme diagonale exacte que les marches
    # (bas de marche -> haut de marche), pente 39 deg < floor_max_angle 55 deg.
    _make_ramp_x(mez_z, -43.77, -40.00, 3.00)
    _make_ramp_x(mez_z, 34.87, 31.00, 3.00)
    # Ponts plats invisibles : comblement exact du raccord rampe/deck
    _add_static_box(Vector3(-40.10, 3.00, mez_z), Vector3(0.20, 0.1, 1.4))
    _add_static_box(Vector3(31.10, 3.00, mez_z), Vector3(0.20, 0.1, 1.4))

    # Porte d'acces a la CLASSE (door-school) COLLEE au mur nord, posee sur
    # le deck (y = 4). Modele 1,74 x 4,20 m -> echelle 0,6. CLIC -> classe.
    var porte_mez_x := (mez_debut_x + mez_fin_x) / 2.0
    var porte_mez_z := -44.895   # face interieure du mur : -44,925 + demi-profondeur
    _place_prop("res://assets/props/door_school.glb",
        Vector3(porte_mez_x, mez_y - 0.01, porte_mez_z), Vector3.ZERO, 0.6)
    _add_static_box(Vector3(porte_mez_x, mez_y + 1.4, -44.75),
        Vector3(1.20, 3.0, 0.35), "porte_classe")

    # Reseau de lutte incendie par sprinklers : tetes sous la charpente,
    # plan d'eau au sol, son du jet, etiquette d'etat au switch du bureau.
    sprinklers = SprinklerManager.new()
    add_child(sprinklers)
    sprinklers.construire(self, HALL_MIN_X, HALL_MAX_X, HALL_MIN_Z, HALL_MAX_Z)
    _eau_son = AudioStreamPlayer.new()
    var jet_eau = load("res://assets/sounds/water.mp3")
    if jet_eau != null:
        jet_eau.loop = true
        _eau_son.stream = jet_eau
        _eau_son.volume_db = -8.0
    add_child(_eau_son)
    _etiquette_sprinkler = Label3D.new()
    _etiquette_sprinkler.text = "SPRINKLERS : HORS SERVICE"
    _etiquette_sprinkler.position = Vector3(-58.76, 1.86, -60.4)
    _etiquette_sprinkler.rotation.y = PI / 2.0
    _etiquette_sprinkler.pixel_size = 0.0035
    _etiquette_sprinkler.font_size = 48
    _etiquette_sprinkler.outline_size = 12
    _etiquette_sprinkler.modulate = Color(1.0, 0.85, 0.3)
    add_child(_etiquette_sprinkler)
    var marque_sprinkler := Label3D.new()
    marque_sprinkler.text = "SPRINKLER"
    marque_sprinkler.position = Vector3(-58.76, 0.78, -60.4)
    marque_sprinkler.rotation.y = PI / 2.0
    marque_sprinkler.pixel_size = 0.0035
    marque_sprinkler.font_size = 40
    marque_sprinkler.outline_size = 12
    marque_sprinkler.modulate = Color(1.0, 0.85, 0.3)
    add_child(marque_sprinkler)

    _build_office_cabin()
    _build_bureau_interieur()
    _build_local_wc()
    _build_classe()
    _build_gyrophares_murs()


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
    if lod_manager != null:
        lod_manager.auto_register(node)
    return node


## Boitiers d'alarme incendie (brise-vitre) pres de CHAQUE extincteur
## et dans le bureau (mur de gauche). Modele aute couche : redresse par
## X 90 deg + demi-tour Y 180 (l'avant etait vers le mur). Clic ->
## bris de verre sonore et visuel puis evacuation en boucle (touche M
## pour couper).
func _build_alarmes() -> void:
    # mur du fond (face +Z) : a cote des extincteurs x = -20, 10, 40
    for x in [-20.0, 10.0, 40.0]:
        _placer_alarme(Vector3(x - 1.4, 1.46, HALL_MIN_Z + 0.06),
            Vector3(PI / 2.0, PI, 0.0), Vector3(0.0, 0.0, 1.0))
    # mur droit (face -X) : extincteurs z = -15 et +15
    for z in [-15.0, 15.0]:
        _placer_alarme(Vector3(HALL_MAX_X - 0.06, 1.46, z - 1.4),
            Vector3(PI / 2.0, PI / 2.0, 0.0), Vector3(-1.0, 0.0, 0.0))
    # mur avant (z max, face -Z) : deux kits
    for x in [-15.0, 20.0]:
        _placer_alarme(Vector3(x - 1.4, 1.46, HALL_MAX_Z - 0.06),
            Vector3(PI / 2.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0))
    # mur gauche : kit a droite de la porte de sortie (face +X)
    _placer_alarme(Vector3(HALL_MIN_X + 0.13, 1.46, -2.6),
        Vector3(PI / 2.0, -PI / 2.0, 0.0), Vector3(1.0, 0.0, 0.0))

    # bureau : mur de GAUCHE de la piece interieure (face interieure +X)
    _placer_alarme(Vector3(-58.66, 1.46, -59.0),
        Vector3(PI / 2.0, -PI / 2.0, 0.0), Vector3(1.0, 0.0, 0.0))


func _placer_alarme(pos: Vector3, rot: Vector3, face: Vector3) -> void:
    _place_prop(URGENCUE_BOX, pos, rot)
    # zone cliquable fine DEVANT la facade (face explicite : le panneau
    # etait enterre dans le mur, le rayon touchait toujours le mur)
    _add_static_box(pos + face * 0.07, Vector3(0.24, 0.24, 0.05),
        "alarme_incendie")


## Lettre geante peinte sur un mur (5 m, style vieille usine).
func _lettre_mur(lettre: String, pos: Vector3, yaw: float) -> void:
    var lbl := Label3D.new()
    lbl.text = lettre
    lbl.font_size = 560     # ~5 m de haut sur un mur de 20 m
    lbl.modulate = Color(0.72, 0.68, 0.60, 0.85)  # blanc use, semi-transparent
    lbl.outline_size = 16
    lbl.outline_modulate = Color(0.4, 0.36, 0.3, 0.4)  # contour terre
    lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    lbl.no_depth_test = false
    lbl.shaded = true       # recoit l'eclairage (pas un panneau lumineux)
    lbl.position = pos
    lbl.rotation.y = yaw
    add_child(lbl)


## Panneau de securite mural (image plate sur quad, face a la salle).
func _place_sign(texture_path: String, pos: Vector3, size_m: Vector2, yaw: float) -> void:
    var tex = load(texture_path)
    if tex == null or not tex is Texture2D:
        push_warning("panneau introuvable : " + texture_path)
        return
    var quad := MeshInstance3D.new()
    var qm := QuadMesh.new()
    qm.size = size_m
    quad.mesh = qm
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = tex
    mat.roughness = 0.75
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.emission_enabled = true
    mat.emission = Color(0.35, 0.35, 0.35)
    quad.material_override = mat
    quad.position = pos
    quad.rotation.y = yaw
    add_child(quad)


## Panneaux de securite muraux :
## sortie de secours au-dessus de la porte, DAE a droite,
## point de rassemblement sur la cabine du bureau.
func _build_securite_signs() -> void:
    # Sortie de secours : au-dessus de la porte usine (mur gauche, face +X)
    # porte a z=0, cadre jusqu'a ~2,3 m -> panneau a 2,65 m
    _place_sign(SIGN_SORTIE, Vector3(HALL_MIN_X + 0.10, 2.65, 0.0),
        Vector2(0.50, 0.26), PI / 2.0)
    # DAE (defibrillateur) : a droite de la porte (z negatif, face +X)
    _place_sign(SIGN_DAE, Vector3(HALL_MIN_X + 0.10, 2.05, -1.8),
        Vector2(0.24, 0.36), PI / 2.0)
    _chaudiere_player = AudioStreamPlayer3D.new()
    var chau_flux = load("res://assets/sounds/annonces/chaudiere.mp3")
    if chau_flux != null:
        chau_flux.loop = true
        _chaudiere_player.stream = chau_flux
        _chaudiere_player.position = Vector3(HALL_MAX_X - 1.0, 1.0, 25.0)
        _chaudiere_player.unit_size = 4.0
        _chaudiere_player.max_distance = 4.0
        _chaudiere_player.max_db = -2.0
        _chaudiere_player.volume_db = -2.0
        add_child(_chaudiere_player)
        _chaudiere_player.play()

    # Chaudiere murale sur le mur est (face a la salle)
    _place_prop("res://assets/props/chaudiere.glb",
        Vector3(HALL_MAX_X - 0.90, 2.0, 25.0), Vector3(0.0, PI, 0.0), 6.0)
    _add_static_box(Vector3(HALL_MAX_X - 0.90, 2.00, 25.0),
        Vector3(1.83, 8.01, 6.00))

    # Jeu industriel realiste : x3, face a la salle, 5 m a l'ouest de la chaufferie
    _place_prop(PROP_GAME, Vector3(51.5, 0.90, 30.0),
        Vector3(0.0, -PI / 2.0, 0.0), 3.0)
    _add_static_box(Vector3(51.5, 0.90, 30.0), Vector3(4.26, 1.80, 5.70))

    # Ascenseur : agrandi a 3 m de haut (modele 0,86 m -> echelle 3,5),
    # plaque contre le mur nord en x=57
    _place_prop(PROP_ELEVATOR, Vector3(57.0, 0.0, -43.8), Vector3.ZERO, 3.5)
    _add_static_box(Vector3(57.0, 1.5, -43.8), Vector3(2.21, 3.0, 2.12))

    # Atelier mur Est : tour, fraiseuse, presse hydraulique, presse a
    # plier et perceuse a colonne entre les 2 extincteurs (z = -15 / +15),
    # dos au mur, face a la salle, 1,50 m d'ecart entre machines. SANS textes.
    _place_prop(PROP_ENGINE_LATHE, Vector3(61.33, 0.0, -8.07),
        Vector3(0.0, -PI / 2.0, 0.0), 1.0)
    _add_static_box(Vector3(61.33, 1.00, -8.07), Vector3(1.04, 2.00, 2.51))
    _place_prop(PROP_VERTICAL_MILL, Vector3(61.15, 0.0, -4.62),
        Vector3(0.0, -PI / 2.0, 0.0), 1.0)
    _add_static_box(Vector3(61.15, 1.30, -4.62), Vector3(1.39, 2.59, 1.39))
    _place_prop(PROP_HYDRAULIC_PRESS, Vector3(61.44, 0.0, -1.65),
        Vector3(0.0, -PI / 2.0, 0.0), 1.0)
    _add_static_box(Vector3(61.44, 1.13, -1.65), Vector3(0.82, 2.26, 1.54))
    _place_prop(PROP_PRESS_BRAKE, Vector3(61.16, 0.0, 1.79),
        Vector3(0.0, -PI / 2.0, 0.0), 1.0)
    _add_static_box(Vector3(61.16, 1.05, 1.79), Vector3(1.38, 2.10, 2.34))
    _place_prop(PROP_PILLAR_DRILL, Vector3(61.51, 0.0, 4.89),
        Vector3(0.0, -PI / 2.0, 0.0), 1.0)
    _add_static_box(Vector3(61.51, 1.08, 4.89), Vector3(0.68, 2.16, 0.85))

    # Clotures de voie : 10 m a l'ouest du mur Est, sur toute la longueur
    # entre les 2 extincteurs (7 sections de 4,18 m bout a bout)
    for k in range(-3, 4):
        var zf: float = 4.18 * k
        _place_prop(PROP_TRACK_FENCE, Vector3(51.73, 0.0, zf),
            Vector3(0.0, PI / 2.0, 0.0), 1.0)
        _add_static_box(Vector3(51.73, 1.10, zf), Vector3(0.34, 2.20, 4.18))

    # 5 tables bleues dosees contre la face est de la cloture, entre le
    # mur et la barriere, face aux machines (sens inverse des machines)
    for zt in [-4.4, -2.2, 0.0, 2.2, 4.4]:
        _place_prop(PROP_WORK_TABLE_BLUE, Vector3(52.34, 0.0, zt),
            Vector3(0.0, PI / 2.0, 0.0), 1.0)
        _add_static_box(Vector3(52.34, 0.88, zt), Vector3(0.87, 1.76, 1.90))

    # 4 armoires scolaires : 2 a gauche (nord) et 2 a droite (sud) des
    # etablis bleus, dos COLLE a la cloture (face est = x 51,90), face aux
    # machines. Modele 3,95 m de haut -> echelle 0,5 (~2 m). Le GLB est une
    # vitrine dont les battants sont modelises OUVERTS en biais (ils
    # donnaient l'impression d'armoires tournees) : on les masque.
    for za in [-6.26, -7.58, 6.26, 7.58]:
        var cab_scene: PackedScene = load(PROP_SCHOOL_CABINET)
        if cab_scene == null:
            continue
        var cab: Node3D = cab_scene.instantiate()
        cab.position = Vector3(52.50, 0.106, za)
        cab.rotation = Vector3(0.0, 3.0 * PI / 4.0, 0.0)
        cab.scale = Vector3.ONE * 0.5
        for partie in cab.find_children("Cube_02[56]*", "MeshInstance3D", true, false):
            partie.visible = false  # battants ouverts du GLB : masques
        add_child(cab)
        _add_static_box(Vector3(52.50, 0.99, za), Vector3(1.20, 1.97, 1.22))

    # Barriere d'angle en "L" : au bout a droite (sud) de la ligne de
    # clotures, a 90 deg, entre la cloture et le mur Est
    _place_prop(PROP_TRACK_FENCE, Vector3(53.99, 0.0, 14.46), Vector3.ZERO, 1.0)
    _add_static_box(Vector3(53.99, 1.10, 14.46), Vector3(4.18, 2.20, 0.34))

    # Panneau WC sur le mur OUEST (z = -13), face a la salle, POSÉ AU SOL
    # (bas de l'image a y=0). Image portrait 1259x2869 -> 1,00 x 2,28 m (taille porte).
    var wc_tex = load("res://assets/textures/wc.png")
    if wc_tex != null:
        var wc_mat := StandardMaterial3D.new()
        wc_mat.albedo_texture = wc_tex
        wc_mat.cull_disabled = true
        wc_mat.roughness = 0.8
        var wc_panneau := MeshInstance3D.new()
        var wc_quad := QuadMesh.new()
        wc_quad.size = Vector2(1.00, 2.28)
        wc_quad.material = wc_mat
        wc_panneau.mesh = wc_quad
        wc_panneau.position = Vector3(-57.88, 1.14, -13.0)
        wc_panneau.rotation.y = PI / 2.0  # face vers l'est (salle)
        add_child(wc_panneau)

    # Panneau "local maintenance" sur la derniere cloture a droite,
    # face a la salle (banniere 730x234 px -> 1,56 x 0,50 m)
    var panneau_tex = load("res://assets/textures/local-maintenance.png")
    if panneau_tex != null:
        var panneau_mat := StandardMaterial3D.new()
        panneau_mat.albedo_texture = panneau_tex
        panneau_mat.cull_disabled = true
        panneau_mat.roughness = 0.8
        var panneau := MeshInstance3D.new()
        var quad := QuadMesh.new()
        quad.size = Vector2(1.56, 0.50)
        quad.material = panneau_mat
        panneau.mesh = quad
        panneau.position = Vector3(51.54, 1.50, 12.54)
        panneau.rotation.y = -PI / 2.0  # face vers l'ouest (salle)
        add_child(panneau)

    # 2 transpalettes a gauche (nord) de l'extincteur de gauche,
    # legerement en desordre
    _place_prop(PROP_TRANSPALLET, Vector3(58.5, 0.01, -17.0),
        Vector3(0.0, 0.35, 0.0), 1.0)
    _add_static_box(Vector3(58.5, 0.63, -17.0), Vector3(0.90, 1.26, 1.80))
    _place_prop(PROP_TRANSPALLET, Vector3(59.8, 0.01, -18.4),
        Vector3(0.0, -2.4, 0.0), 1.0)
    _add_static_box(Vector3(59.8, 0.63, -18.4), Vector3(0.90, 1.26, 1.80))

    # 3 palettes en bois a cote des transpalettes, en desordre
    # (10 cm de haut : franchissables, pas de collision)
    _place_prop(PROP_WOODEN_PALLET, Vector3(57.6, 0.0, -18.2),
        Vector3(0.0, 0.6, 0.0), 1.0)
    _place_prop(PROP_WOODEN_PALLET, Vector3(58.9, 0.0, -19.3),
        Vector3(0.0, -1.1, 0.0), 1.0)
    _place_prop(PROP_WOODEN_PALLET, Vector3(60.3, 0.0, -17.6),
        Vector3(0.0, 2.3, 0.0), 1.0)

    # Machine voxel 2 geante : modeele 1,90 m -> echelle 6,32 = 12 m de
    # haut, zone sud-ouest (x -38 / z 32). Origine a mi-hauteur -> y = 6.
    # Sans texte.
    _place_prop(PROP_VOXEL_MACHINE_2, Vector3(-38.0, 6.0, 32.0),
        Vector3.ZERO, 6.32)
    _add_static_box(Vector3(-38.0, 6.0, 32.0), Vector3(4.39, 12.0, 4.45))

    # Machine a commande numerique VF-2TR (Haas), en (39, -28), debout
    # face au sud. Transformations BATIES (gltf-transform join) : les 3
    # niveaux de detail partagent exactement la meme enveloppe
    # 3,17 x 2,72 x 2,34 m (piles la doc constructeur 3,15 x 2,25 x 2,72).
    #   haute   : 405 430 triangles (joueur < 8 m)
    #   moyenne : 101 346 triangles (8-18 m)
    #   basse   :  12 726 triangles (> 18 m)
    # Le niveau actif est choisi dans _process selon la distance joueur.
    _placer_haas(-28.0)   # premiere machine
    _placer_haas(-18.0)   # deuxieme machine, 10 m devant (sud)
    _placer_haas(-38.0)   # troisieme machine, 10 m derriere (nord)

    # Chariots de stockage a cote de chaque Haas, cote EST. Sans texte.
    for zc_haas in [-38.0, -28.0, -18.0]:
        _place_prop(PROP_STORAGE_CART, Vector3(40.95, 0.50, zc_haas),
            Vector3.ZERO, 1.0)
        _add_static_box(Vector3(40.95, 0.50, zc_haas),
            Vector3(0.40, 1.00, 0.86))



    # Panneau "caution wet floor" entre le cafe et le bureau de chantier
    _place_prop("res://assets/props/caution_wet_floor.glb",
        Vector3(-57.0, 0.0, -20.0), Vector3.ZERO)

    # Poubelle a droite de la machine a cafe
    _place_prop("res://assets/props/steel_bin.glb",
        Vector3(-57.0 - 1.90, 0.0, -8.0 - 0.075), Vector3.ZERO)
    _add_static_box(Vector3(-57.0, 0.19, -8.0), Vector3(0.35, 0.38, 0.35))

    # Distributeur de cafe a droite du DAE (mur gauche, face a la salle)
    # offset interne : centre du modele a (-11.455, 0.90, 7.925)
    # position = cible - offset_apres_rotation_y_90 (x<->z inverses)
    # R_y(90) : (x,y,z)->(z,y,-x) donc le centre devient (7.925, 0.90, 11.455)
    var cafe_offset := Vector3(7.925, 0.90, 11.455)
    _place_prop("res://assets/props/distributeur_cafe.glb",
        Vector3(-65.325, 0.0, -17.455),
        Vector3(0.0, PI / 2.0, 0.0))
    _add_static_box(Vector3(-57.40, 0.90, -6.0), Vector3(0.93, 1.80, 0.81))

    # Chariot de stockage a gauche des gondoles
    _place_prop("res://assets/props/storage_cart.glb",
        Vector3(HALL_MIN_X + 0.55, 0.50, 6.0), Vector3(0.0, PI / 2.0, 0.0))

    # Trousse de secours sous le defibrillateur
    _place_prop("res://assets/props/first_aid_kit.glb",
        Vector3(HALL_MIN_X + 0.6, 1.0, -1.8), Vector3(0.0, 0.0, 0.0), 0.04)

    # Defibrillateur sous le panneau DAE
    _place_prop("res://assets/safety/defibrillator.glb",
        Vector3(HALL_MIN_X + 0.14, 1.25, -1.8), Vector3(0.0, PI / 2.0, 0.0))

    # Point de rassemblement : sur la cabine du bureau (face +Z vers l'usine)
    _place_sign(SIGN_RASSEMBLEMENT, Vector3(HALL_MIN_X + 0.08, 1.50, -31.15),
        Vector2(0.22, 0.33), PI / 2.0)


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
    # 8 lampes pendantes : 4 cote gauche, 4 cote droit, 10 m du sol
    for lx in [-30.0, -10.0, 10.0, 30.0]:
        for lz in [-10.0, 10.0]:
            _place_prop(PROP_PENDANT_LAMP, Vector3(lx, 10.0, lz), Vector3.ZERO)
    _place_prop(PROP_FLUO_FIXTURE, Vector3(2.6, HALL_HEIGHT - 0.01, -1.6), Vector3(0.0, 0.6, 0.0))
    for lx2 in [-30.0, -10.0, 10.0, 30.0]:
        for lz2 in [-10.0, 10.0]:
            var orange_light := OmniLight3D.new()
            orange_light.position = Vector3(lx2, 9.3, lz2)
            orange_light.light_color = Color(1.0, 0.45, 0.08)
            orange_light.omni_range = 18.0
            orange_light.light_energy = 3.0
            add_child(orange_light)
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
    for z_gondole in range(10):
        var gz := 8.0 + z_gondole * 2.0
        _place_prop(PROP_GONDOLA,
            Vector3(HALL_MIN_X + 0.42, 0.95, gz), Vector3(0.0, PI / 2.0, 0.0))
        _add_static_box(Vector3(HALL_MIN_X + 0.42, 0.95, gz), Vector3(0.62, 1.9, 1.0))


## Ligne d'exposition : les modeles GLB fournis, espaces de 7 m a z = -10,
## chacun avec son nom au sol (Label3D plat devant lui). Bbox mesurees via
## tests/measure_props.gd (toutes debout a l'identite, echelle 1).
func _build_expo() -> void:
    var items := [
        {"path": PROP_IRON_MINER, "nom": "Mineur de fer automatique",
         "x": -36.0, "y": 0.76, "col": Vector3(1.9, 1.51, 1.33)},
        {"path": PROP_VOXEL_MACHINE, "nom": "Machine industrielle voxel 1",
         "x": -29.0, "y": 0.67, "col": Vector3(1.9, 1.35, 1.9)},
        {"path": PROP_MODULAR_CONVEYOR, "nom": "Convoyeur modulaire",
         "x": -15.0, "y": 0.25, "col": Vector3(1.9, 0.51, 0.65)},
        {"path": PROP_TOOL_TROLLEYS, "nom": "Chariots d'outils",
         "x": -22.0, "y": 0.84, "col": Vector3(0.60, 1.71, 3.23)},
        {"path": PROP_STRETCHFAB, "nom": "Stretchfab",
         "x": -8.0, "y": 0.0, "col": Vector3(1.25, 0.32, 1.17)},
        {"path": PROP_DUMPSTER, "nom": "Benne en acier vert",
         "x": -1.0, "y": 0.0, "col": Vector3(0.8, 0.73, 0.74)},
        {"path": PROP_WELDING, "nom": "Poste de soudure",
         "x": 6.0, "y": 0.46, "col": Vector3(1.00, 0.92, 0.50)},
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
        if lod_manager != null:
            lod_manager.register_cull(label, LodManager.DIST_LABEL)

    # Passerelle "Colony" : fragments NON TOURNES (2,77 m en X, 5,14 m en
    # Z a rotation zero), poses bout a bout le long de la ligne d'expo
    # (z = -10) : 37 fragments couvrent -54,9 (3 m apres le mur ouest /
    # porte) a 47,6 (3 m avant la cloture du service maintenance a 51,73).
    # Plat : pas de collision.
    for k_pont in range(37):
        _place_prop(PROP_BRIDGE, Vector3(-53.515 + 2.77 * k_pont, 0.0, -10.0),
            Vector3.ZERO, 1.0)


## Piece interieure du bureau : 8 x 10 m derriere le mur du fond
## (invisible depuis l'usine). Vraie porte dans le mur avant : c'est
## ELLE qu'on clique pour sortir. La porte de la cabine (dans l'usine)
## teleporte vers l'interieur.
## Salle de CLASSE : 10 x 6 m derriere le mur nord (acces par la porte
## door-school de la mezzanine). Murs clairs, sol parquet, deux lumieres
## (passent au rouge a l'alerte comme toutes les Light3D).
func _build_classe() -> void:
    var cxc := -4.5
    var czc := -51.0
    var mur := StandardMaterial3D.new()
    var mur_tex = load("res://assets/textures/blanc_classe.jpg")
    if mur_tex != null:
        mur.albedo_texture = mur_tex
        mur.uv1_scale = Vector3(3.0, 1.0, 1.0)   # motif ~3 x 2,8 m
        mur.roughness = 0.9
    else:
        mur.albedo_color = Color(0.87, 0.85, 0.80)
        mur.roughness = 0.9
    var sol_mat := StandardMaterial3D.new()
    var parquet = load("res://assets/textures/parquet_basecolor.png")
    if parquet != null:
        sol_mat.albedo_texture = parquet
        sol_mat.uv1_scale = Vector3(5.0, 3.0, 1.0)
        sol_mat.roughness = 0.55
    else:
        sol_mat.albedo_color = Color(0.45, 0.4, 0.35)
    var plafond_mat := StandardMaterial3D.new()
    plafond_mat.albedo_color = Color(0.93, 0.93, 0.9)

    # Sol, plafond (2,8 m) et 4 murs - interieur 10 (X) x 6 (Z) m
    _room_box(Vector3(cxc, -0.1, czc), Vector3(10.4, 0.2, 6.4), sol_mat)
    _room_box(Vector3(cxc, 2.8, czc), Vector3(10.4, 0.2, 6.4), plafond_mat)
    _room_box(Vector3(cxc - 5.1, 1.4, czc), Vector3(0.2, 2.8, 6.4), mur)
    _room_box(Vector3(cxc + 5.1, 1.4, czc), Vector3(0.2, 2.8, 6.4), mur)
    _room_box(Vector3(cxc, 1.4, czc - 3.1), Vector3(10.4, 2.8, 0.2), mur)
    _room_box(Vector3(cxc, 1.4, czc + 3.1), Vector3(10.4, 2.8, 0.2), mur)

    # Deux lumieres (rouge a l'alerte automatiquement, bascules par
    # l'interrupteur du mur est)
    for dx_l in [-2.5, 2.5]:
        var lum := OmniLight3D.new()
        lum.position = Vector3(cxc + dx_l, 2.6, czc)
        lum.light_color = Color(1.0, 0.96, 0.88)
        lum.light_energy = 1.3
        lum.omni_range = 9.0
        add_child(lum)
        _lumieres_classe.append(lum)

    # Interrupteur de lumiere : mur EST, cote sud (proche du passage de
    # la porte). Clic -> allume/eteint les deux lumieres + son de clic.
    _place_prop("res://assets/props/light_switch.glb",
        Vector3(cxc + 4.93, 1.15, czc + 2.2), Vector3(0.0, -PI / 2.0, 0.0), 0.125)
    _add_static_box(Vector3(cxc + 4.93, 1.15, czc + 2.2),
        Vector3(0.12, 0.16, 0.10), "interrupteur_classe")
    _interrupteur_classe_son = AudioStreamPlayer3D.new()
    var clic_cl = load("res://assets/sounds/button-press.mp3")
    if clic_cl != null:
        _interrupteur_classe_son.stream = clic_cl
    _interrupteur_classe_son.position = Vector3(cxc + 4.93, 1.15, czc + 2.2)
    _interrupteur_classe_son.unit_size = 2.0
    add_child(_interrupteur_classe_son)

    # Amenagement : baie informatique au fond (mur nord), armoire scolaire
    # sur le mur ouest, poubelle acier a gauche de la porte, gyrophare
    # d'alerte au plafond (systeme global : rotation bleue + rouge alarme)
    _place_prop(PROP_COMPUTER_ROOM, Vector3(cxc-0.5, 0.672, czc),
        Vector3(0.0, PI, 0.0), 4.2)
    _add_static_box(Vector3(cxc-0.5, 0.672, czc), Vector3(4.20, 1.34, 3.00))
    var cab_cl_scene: PackedScene = load(PROP_SCHOOL_CABINET)
    if cab_cl_scene != null:
        var cab_cl: Node3D = cab_cl_scene.instantiate()
        cab_cl.position = Vector3(cxc - 4.4, 0.106, czc)
        cab_cl.rotation = Vector3(0.0, 3.0 * PI / 4.0, 0.0)
        cab_cl.scale = Vector3.ONE * 0.5
        for partie in cab_cl.find_children("Cube_02[56]*", "MeshInstance3D", true, false):
            partie.visible = false   # battants ouverts du GLB : masques
        add_child(cab_cl)
        _add_static_box(Vector3(cxc - 4.4, 0.99, czc), Vector3(1.20, 1.97, 1.22))
    _place_prop(PROP_STEEL_BIN, Vector3(cxc + 4.2 - 1.90, -0.034, czc + 3.25),
        Vector3(0.0, 0.7, 0.0), 1.0)   # origine GLB decentree de +1,90 m en X
    _add_static_box(Vector3(cxc + 4.2, 0.19, czc + 3.25),
        Vector3(0.35, 0.38, 0.35))

    # Tableau craie (1,88 x 1,28 m, face +Z, epaisseur 10 cm) colle au
    # mur EST, face vers l'ouest ; bureau d'enseignant + laptop + chaise
    # face au tableau
    _place_prop("res://assets/props/tableau_craie.glb",
        Vector3(cxc + 4.98, 0.86, czc), Vector3(0.0, -PI / 2.0, 0.0), 1.0)
    _add_static_box(Vector3(cxc + 4.94, 1.48, czc), Vector3(0.12, 1.28, 1.88))
    _place_prop("res://assets/props/desk_2.glb",
        Vector3(cxc + 2.6, 0.0, czc), Vector3(0.0, PI / 2.0, 0.0), 1.0)
    _add_static_box(Vector3(cxc + 2.6, 0.38, czc), Vector3(0.80, 0.76, 1.60))
    _place_prop("res://assets/props/laptop.glb",
        Vector3(cxc + 2.6, 0.87, czc), Vector3(0.0, 0.0, 0.0), 0.35)
    _place_prop("res://assets/props/office_chair.glb",
        Vector3(cxc + 3.6, 0.0, czc), Vector3(0.0, -PI / 2.0, 0.0), 1.0)
    _add_static_box(Vector3(cxc + 3.6, 0.51, czc), Vector3(0.60, 1.02, 0.59))
    _cree_gyrophare(Vector3(cxc, 2.8, czc), true)

    # Porte de sortie visible (mur sud, cote interieur) + collider cliquable
    _add_static_box(Vector3(cxc, 1.2, czc + 3.0),
        Vector3(1.2, 2.2, 0.2), "porte_classe_sortie")
    var porte_mat := StandardMaterial3D.new()
    porte_mat.albedo_color = Color(0.42, 0.26, 0.13)  # brun bois franc, comme l'exterieur
    porte_mat.roughness = 0.6
    porte_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var porte_panneau := MeshInstance3D.new()
    var porte_box := BoxMesh.new()
    porte_box.size = Vector3(1.04, 2.5, 0.05)
    porte_panneau.mesh = porte_box
    porte_panneau.material_override = porte_mat
    porte_panneau.position = Vector3(cxc, 1.26, czc + 2.97)
    add_child(porte_panneau)
    var poignee := MeshInstance3D.new()
    var poignee_box := BoxMesh.new()
    poignee_box.size = Vector3(0.14, 0.04, 0.04)
    poignee.mesh = poignee_box
    var poignee_mat := StandardMaterial3D.new()
    poignee_mat.albedo_color = Color(0.35, 0.36, 0.38)
    poignee_mat.metallic = 0.8
    poignee.material_override = poignee_mat
    poignee.position = Vector3(cxc + 0.35, 1.05, czc + 2.97)
    add_child(poignee)


## Machine Haas VF-2TR a trois niveaux de detail, centree en (39, zc),
## debout face au sud. Chaque machine a son propre groupe LOD.
func _placer_haas(zc: float) -> void:
    var niveaux: Array[Node3D] = []
    for chemin_vf in [PROP_VF_2TR, PROP_VF_2TR_MED, PROP_VF_2TR_LOW]:
        var scene_vf: PackedScene = load(chemin_vf)
        if scene_vf == null:
            continue
        var machine_vf: Node3D = scene_vf.instantiate()
        machine_vf.position = Vector3(39.393, 0.505, zc - 0.399)
        machine_vf.rotation = Vector3(PI / 2.0, 0.0, 0.0)
        machine_vf.visible = niveaux.is_empty()  # haute qualite d'abord
        add_child(machine_vf)
        niveaux.append(machine_vf)
    _add_static_box(Vector3(39.0, 1.362, zc), Vector3(3.17, 2.72, 2.34))
    if lod_manager != null:
        lod_manager.register_levels(niveaux, [8.0, 18.0],
            Vector3(39.0, 1.0, zc))
        for niveau_haas in niveaux:
            lod_manager.auto_register(niveau_haas)
    # Bruit d'usinage module par la distance : AudioStreamPlayer3D gere
    # l'attenuation (unit_size 2,5 + coupure a 22 m : proche des machines).
    # Legger detunable entre les deux machines (pas de phasage).
    var son_cnc := AudioStreamPlayer3D.new()
    var flux_cnc = load("res://assets/sounds/cnc_process.mp3")
    if flux_cnc != null:
        flux_cnc.loop = true
        son_cnc.stream = flux_cnc
        son_cnc.position = Vector3(39.0, 1.4, zc)
        son_cnc.unit_size = 2.5      # chute rapide : audible sur ~10 m
        son_cnc.max_db = -6.0
        son_cnc.max_distance = 22.0  # coupure nette au-dela
        son_cnc.pitch_scale = 0.97 if zc > -20.0 else 1.0
        add_child(son_cnc)
        son_cnc.play()


## Local WC : 2,5 x 2 m derriere le mur ouest (acces par la porte WC du
## hall). Murs carreles, toilettes au fond (CLIC = chasse d'eau), papier
## a gauche, serviette et LAVABO a droite, gyrophare d'alerte horizontal
## en haut du mur du fond (meme systeme que les 17 autres ; la lumiere
## du local passe au rouge comme toutes les Light3D).
func _build_local_wc() -> void:
    var cxw := -64.25          # centre (profondeur 2,5 m vers l'ouest)
    var czw := -13.0
    var carrelage := StandardMaterial3D.new()
    var tex_carrelage = load("res://assets/textures/toilet_tile_texture.png")
    if tex_carrelage != null:
        carrelage.albedo_texture = tex_carrelage
        carrelage.uv1_scale = Vector3(4.0, 4.0, 1.0)   # carreaux ~25 cm
        carrelage.roughness = 0.3
    else:
        carrelage.albedo_color = Color(0.85, 0.88, 0.9)
    var sol_mat := StandardMaterial3D.new()
    sol_mat.albedo_color = Color(0.6, 0.62, 0.65)
    var plafond_mat := StandardMaterial3D.new()
    plafond_mat.albedo_color = Color(0.95, 0.95, 0.95)

    # Sol, plafond (2,5 m) et 4 murs - interieur 2,5 (X) x 2 (Z) m
    _room_box(Vector3(cxw, -0.1, czw), Vector3(2.9, 0.2, 2.4), sol_mat)
    _room_box(Vector3(cxw, 2.5, czw), Vector3(2.9, 0.2, 2.4), plafond_mat)
    _room_box(Vector3(cxw - 1.35, 1.25, czw), Vector3(0.2, 2.5, 2.4), carrelage)
    _room_box(Vector3(cxw + 1.35, 1.25, czw), Vector3(0.2, 2.5, 2.4), carrelage)
    _room_box(Vector3(cxw, 1.25, czw - 1.1), Vector3(2.9, 2.5, 0.2), carrelage)
    _room_box(Vector3(cxw, 1.25, czw + 1.1), Vector3(2.9, 2.5, 0.2), carrelage)

    # Lumiere du local (passe au rouge a l'alerte, comme toutes les Light3D)
    var lumiere_wc := OmniLight3D.new()
    lumiere_wc.position = Vector3(cxw, 2.25, czw)
    lumiere_wc.light_color = Color(1.0, 0.97, 0.9)
    lumiere_wc.light_energy = 1.2
    lumiere_wc.omni_range = 6.0
    add_child(lumiere_wc)

    # Toilettes au fond (mur ouest), face a la porte. COLLER CLIQUABLE :
    # clic sur la cuvette -> chasse d'eau (toilet-flush.mp3)
    _place_prop("res://assets/props/toilet.glb",
        Vector3(-65.12, 0, czw), Vector3(0.0, PI / 2.0, 0.0), 0.45)
    _add_static_box(Vector3(-65.12, 0.43, czw),
        Vector3(0.76, 0.86, 0.54), "toilettes_wc")
    _chasse_son = AudioStreamPlayer3D.new()
    var son_chasse = load("res://assets/sounds/toilet-flush.mp3")
    if son_chasse != null:
        _chasse_son.stream = son_chasse
    _chasse_son.position = Vector3(-65.12, 0.8, czw)
    _chasse_son.unit_size = 3.0
    _chasse_son.max_db = -2.0
    add_child(_chasse_son)
    # Papier toilette a gauche (mur sud)
    _place_prop("res://assets/props/toilet-paper.glb",
        Vector3(-65.0, 0.95, czw + 0.91), Vector3(0.0, PI, 0.0), 1.0)
    # Serviette pres de l'angle (mur nord) et LAVABO a droite, cote porte
    _place_prop("res://assets/props/towel.glb",
        Vector3(-65.0, 1.46, czw - 0.94), Vector3.ZERO, 0.7)
    _place_prop("res://assets/props/lavabo.glb",
        Vector3(-64.3, 0.5, czw - 0.62), Vector3(0, - PI / 2.0, 0), 1.0)
    # Clic sur le lavabo -> lavabo.mp3 (robinet)
    _add_static_box(Vector3(-64.3, 0.5, czw - 0.62),
        Vector3(0.47, 2, 0.56), "lavabo_wc")
    _lavabo_son = AudioStreamPlayer3D.new()
    var son_lavabo = load("res://assets/sounds/lavabo.mp3")
    if son_lavabo != null:
        _lavabo_son.stream = son_lavabo
    _lavabo_son.position = Vector3(-64.3, 0.9, czw - 0.28)
    _lavabo_son.unit_size = 3.0
    _lavabo_son.max_db = -2.0
    add_child(_lavabo_son)

    # Gyrophare d'alerte en haut du mur du fond, fixation horizontale
    _cree_gyrophare(Vector3(-65.47, 2.1, czw), false, true)

    # Portes : entree cote hall (sur l'image WC), sortie cote local
    _add_static_box(Vector3(-57.85, 1.14, -13.0),
        Vector3(0.12, 2.28, 1.0), "porte_wc")
    _add_static_box(Vector3(cxw + 1.2, 1.2, czw),
        Vector3(0.12, 2.2, 1.0), "porte_wc_sortie")
    # Porte visible : panneau + poignee sur le mur est (cote interieur)
    var porte_mat := StandardMaterial3D.new()
    porte_mat.albedo_color = Color(45.0 / 255.0, 95.0 / 255.0, 105.0 / 255.0)
    porte_mat.roughness = 0.5
    var porte_panneau := MeshInstance3D.new()
    var porte_box := BoxMesh.new()
    porte_box.size = Vector3(0.05, 2.1, 1.0)
    porte_panneau.mesh = porte_box
    porte_panneau.material_override = porte_mat
    porte_panneau.position = Vector3(cxw + 1.22, 1.05, czw)
    add_child(porte_panneau)
    var poignee := MeshInstance3D.new()
    var poignee_box := BoxMesh.new()
    poignee_box.size = Vector3(0.04, 0.04, 0.14)
    poignee.mesh = poignee_box
    var poignee_mat := StandardMaterial3D.new()
    poignee_mat.albedo_color = Color(0.35, 0.36, 0.38)
    poignee_mat.metallic = 0.8
    poignee.material_override = poignee_mat
    poignee.position = Vector3(cxw + 1.18, 1.05, czw + 0.35)
    add_child(poignee)


## Robinet du lavabo du local WC (clic sur le lavabo).
func _ouvrir_robinet() -> void:
    if _lavabo_son != null:
        _lavabo_son.play()
        print("Local WC : robinet du lavabo")


## Tirer la chasse d'eau du local WC (clic sur la cuvette).
func _tirer_chasse() -> void:
    if _chasse_son != null:
        _chasse_son.play()
        print("Local WC : chasse d'eau")


## Interrupteur du bureau : allume/eteint la lampe du plafond + son.
func _basculer_lumiere_bureau() -> void:
    if _lumiere_bureau != null:
        _lumiere_bureau.visible = not _lumiere_bureau.visible
        print("Lumiere du bureau : ",
            "allumee" if _lumiere_bureau.visible else "eteinte")
    if _interrupteur_son != null:
        _interrupteur_son.play()


func _basculer_lumiere_classe() -> void:
    var allumer: bool = _lumieres_classe.is_empty() or not _lumieres_classe[0].visible
    for lum_c in _lumieres_classe:
        lum_c.visible = allumer
    print("Lumieres de la classe : ", "allumees" if allumer else "eteintes")
    if _interrupteur_classe_son != null:
        _interrupteur_classe_son.play()


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
    # Face interieure de la porte : gris ardoise bleute (choix utilisateur)
    var porte_bur_mat := StandardMaterial3D.new()
    porte_bur_mat.albedo_color = Color(70.0 / 255.0, 75.0 / 255.0, 85.0 / 255.0)
    porte_bur_mat.roughness = 0.6
    porte_bur_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var porte_bur_panneau := MeshInstance3D.new()
    var porte_bur_box := BoxMesh.new()
    porte_bur_box.size = Vector3(1.06, 1.90, 0.05)
    porte_bur_panneau.mesh = porte_bur_box
    porte_bur_panneau.material_override = porte_bur_mat
    porte_bur_panneau.position = Vector3(cx, 0.975, cz + 4.83)
    add_child(porte_bur_panneau)

    var lampe := OmniLight3D.new()
    lampe.position = Vector3(cx, 2.4, cz)
    lampe.light_color = Color(1.0, 0.93, 0.8)
    lampe.omni_range = 9.0
    lampe.light_energy = 1.3
    add_child(lampe)
    _lumiere_bureau = lampe

    # Interrupteur a lame (switch a couteaux) sur le mur de gauche, a
    # cote du boitier d'alarme incendie (z = -59). Modele bake (join),
    # echelle 0,1.
    _place_prop("res://assets/props/switch_couteaux.glb",
        Vector3(-58.50, 1.0, -59.0), Vector3(0.0, PI / 2.0, 0.0), 0.05)
    _add_static_box(Vector3(-58.50, 1.0, -59.0), Vector3(0.30, 0.55, 0.35),
        "switch_sprinkler")

    # Golden Play Button : affichage direct de la ressource utilisateur
    # (texture d'origine du GLB, aucun materiau substitue)
    var golden_scene: PackedScene = load("res://assets/props/golden_play_button.glb")
    if golden_scene != null:
        var golden_m: Node3D = golden_scene.instantiate()
        golden_m.position = Vector3(cx + 1.8, 1.55, cz - 4.76)
        golden_m.rotation = Vector3(0.0, 0.0, 0.0)
        golden_m.scale = Vector3.ONE * 5.0
        add_child(golden_m)

    # Interrupteur de lumiere : mur avant, a DROITE de la porte (cote
    # oppose au keypad). Modele 0,69 x 1,0 m -> echelle 0,125 (~9 x 12,5 cm).
    # Clic -> allume/eteint la lampe + son button-press.mp3
    _place_prop("res://assets/props/light_switch.glb",
        Vector3(cx + 1.0, 1.15, cz + 4.74), Vector3(0.0, PI/2, 0.0), 0.125)
    _add_static_box(Vector3(cx + 1.0, 1.15, cz + 4.74),
        Vector3(0.12, 0.16, 0.10), "interrupteur_bureau")
    _interrupteur_son = AudioStreamPlayer3D.new()
    var son_clic = load("res://assets/sounds/button-press.mp3")
    if son_clic != null:
        _interrupteur_son.stream = son_clic
    _interrupteur_son.position = Vector3(cx + 1.0, 1.15, cz + 4.74)
    _interrupteur_son.unit_size = 2.0
    _interrupteur_son.max_db = -4.0
    add_child(_interrupteur_son)

    # Tableau au mur de droite, centre (source 4,44 m -> 2,0 m)
    _place_prop(TABLEAU, Vector3(cx + 3.76, 1.5, cz),
        Vector3(0.0, PI / 2.0, 0.0), 0.45)

    # Image manga affichee sur le tableau (mur de droite du bureau)
    var manga_tex = load("res://assets/props/tableau_Manga.jpg")
    if manga_tex != null:
        var manga := MeshInstance3D.new()
        var manga_quad := QuadMesh.new()
        manga_quad.size = Vector2(1.90, 1.90)
        var manga_mat := StandardMaterial3D.new()
        manga_mat.albedo_texture = manga_tex
        manga_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        manga_quad.material = manga_mat
        manga.mesh = manga_quad
        manga.position = Vector3(cx + 3.68, 1.5, cz)
        manga.rotation.y = -PI / 2.0
        add_child(manga)

    # Ecran TV 65" (16:9 : 1,45 x 0,82 m) derriere la table, au mur du fond
    var bezel := MeshInstance3D.new()
    var bezel_box := BoxMesh.new()
    bezel_box.size = Vector3(1.55, 0.92, 0.06)
    bezel.mesh = bezel_box
    bezel.position = Vector3(cx, 1.65, cz - 4.66)
    var noir := StandardMaterial3D.new()
    noir.albedo_color = Color(0.05, 0.05, 0.06)
    noir.roughness = 0.4
    bezel.material_override = noir
    add_child(bezel)
    var ecran := MeshInstance3D.new()
    var ecran_quad := QuadMesh.new()
    ecran_quad.size = Vector2(1.45, 0.82)
    ecran.mesh = ecran_quad
    ecran.position = Vector3(cx, 1.65, cz - 4.62)
    add_child(ecran)
    # Videosurveillance : 4 camera reelles, grille 2x2 sur la TV
    var comp := SubViewport.new()
    comp.size = Vector2i(640, 360)
    comp.render_target_update_mode = SubViewport.UPDATE_DISABLED
    comp.transparent_bg = false
    comp.disable_3d = true
    comp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
    add_child(comp)
    var fond_cctv := ColorRect.new()
    fond_cctv.color = Color(0.005, 0.008, 0.008)
    fond_cctv.size = Vector2(640, 360)
    comp.add_child(fond_cctv)
    var cams_cctv: Array[Camera3D] = []
    var orig_cctv: Array[Vector3] = []
    var recs_cctv: Array[ColorRect] = []
    var mats_cctv: Array[ShaderMaterial] = []
    var hrs_cctv: Array[Label] = []
    var pertes_cctv: Array[Label] = []
    var flux_cctv := [
        {"pos": Vector3(0.0, 6.0, 38.0), "visee": Vector3(0.0, 1.0, 18.0),
         "nom": "CAM 01 — ENTREE", "intensite": 0.15, "teinte": Color(0.92, 1.0, 0.96)},
        {"pos": Vector3(1.5, 6.0, 6.0), "visee": Vector3(1.0, 0.5, 0.0),
         "nom": "CAM 02 — PRODUCTION", "intensite": 0.35, "teinte": Color(0.85, 0.95, 1.0)},
        {"pos": Vector3(-20.0, 5.5, -5.0), "visee": Vector3(-20.0, 0.5, -14.0),
         "nom": "CAM 03 — EXPOSITION", "intensite": 0.25, "teinte": Color(0.95, 0.98, 0.9)},
        {"pos": Vector3(10.0, 5.0, -40.0), "visee": Vector3(10.0, 1.2, -44.5),
         "nom": "CAM 04 — FOND SALLE", "intensite": 0.45, "teinte": Color(0.8, 1.0, 0.85)},
    ]
    for k in range(4):
        var conf: Dictionary = flux_cctv[k]
        var vpk := SubViewport.new()
        vpk.size = Vector2i(320, 180)
        vpk.render_target_update_mode = SubViewport.UPDATE_DISABLED
        vpk.transparent_bg = false
        vpk.disable_3d = false
        add_child(vpk)
        var camk := Camera3D.new()
        camk.fov = 72.0
        vpk.add_child(camk)
        camk.position = conf.pos
        camk.look_at(conf.visee, Vector3.UP)
        camk.current = true
        cams_cctv.append(camk)
        orig_cctv.append(camk.rotation)
        _cctv_flux.append(vpk)

        var coin := Vector2(320.0 * (k % 2), 180.0 * (k / 2))
        var txk := TextureRect.new()
        txk.position = coin
        txk.size = Vector2(320, 180)
        txk.texture = vpk.get_texture()
        txk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        txk.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var matk := ShaderMaterial.new()
        matk.shader = preload("res://ui/cctv_flux.gdshader")
        matk.set_shader_parameter("intensite", conf.intensite)
        matk.set_shader_parameter("teinte", conf.teinte)
        txk.material = matk
        mats_cctv.append(matk)
        comp.add_child(txk)

        var nomk := Label.new()
        nomk.text = conf.nom
        nomk.position = coin + Vector2(8, 5)
        nomk.add_theme_font_size_override("font_size", 16)
        nomk.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
        nomk.mouse_filter = Control.MOUSE_FILTER_IGNORE
        comp.add_child(nomk)

        var reck := ColorRect.new()
        reck.color = Color(1.0, 0.05, 0.03)
        reck.size = Vector2(8, 8)
        reck.position = coin + Vector2(275, 9)
        reck.mouse_filter = Control.MOUSE_FILTER_IGNORE
        comp.add_child(reck)
        recs_cctv.append(reck)

        var hrk := Label.new()
        hrk.name = "Horloge_%d" % k
        hrk.text = "00:00:00"
        hrk.position = coin + Vector2(8, 155)
        hrk.add_theme_font_size_override("font_size", 14)
        hrk.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
        hrk.mouse_filter = Control.MOUSE_FILTER_IGNORE
        comp.add_child(hrk)
        hrs_cctv.append(hrk)

        var pdk := Label.new()
        pdk.text = "PERTE DE SIGNAL"
        pdk.position = coin + Vector2(60, 78)
        pdk.add_theme_font_size_override("font_size", 18)
        pdk.add_theme_color_override("font_color", Color(1.0, 0.2, 0.15))
        pdk.visible = false
        pdk.mouse_filter = Control.MOUSE_FILTER_IGNORE
        comp.add_child(pdk)
        pertes_cctv.append(pdk)

    _cctv_composite = comp
    _cctv_cams = cams_cctv
    _cctv_orig = orig_cctv
    _cctv_recs = recs_cctv
    _cctv_mats = mats_cctv
    _cctv_labels = hrs_cctv
    _cctv_perte = pertes_cctv

    # La texture du composite n'est valide qu'apres le premier rendu :
    # attendre une frame avant de l'assigner a l'ecran.
    _cctv_ecran = ecran
    _cctv_composite_a_assigner = comp
    print("CCTV : 4 flux actifs (texture differee d'une frame)")




    # 3 coffrets electriques dans l'atelier, contre le mur du fond
    # (z = HALL_MIN_Z), x ~ -54, face a la salle (+Z)
    for dx in [-55.5, -54.2, -52.9]:
        _place_prop("res://assets/props/control_box.glb",
            Vector3(dx, 1.06, HALL_MIN_Z + 0.20), Vector3.ZERO, 2.0)
    # Bourdonnement electrique des armoires : volume proportionnel
    # a la proximite (AudioStreamPlayer3D avec attenuation)
    _humm_player = AudioStreamPlayer3D.new()
    var humm_flux = load(HUMM_SOUND)
    if humm_flux != null:
        humm_flux.loop = true
        _humm_player.stream = humm_flux
        _humm_player.position = Vector3(-54.2, 1.5, HALL_MIN_Z + 0.3)
        _humm_player.unit_size = HUMM_PORTEE
        _humm_player.max_distance = HUMM_PORTEE
        _humm_player.max_db = HUMM_VOLUME_MAX
        _humm_player.volume_db = HUMM_VOLUME_MAX
        add_child(_humm_player)
        _humm_player.play()

    # Boite a 5 boutons (Boite5BP) sur le mur, sous les champignons AU
    var boite_pos := Vector3(cx - 3.72, 1.50, cz + 1.2)
    _place_prop("res://assets/props/boite_5bp.glb", boite_pos,
        Vector3(PI / 2.0, PI / 2.0, 0.0), 1.25)
    for btn in range(5):
        _add_static_box(
            boite_pos + Vector3(-0.06, -0.088 + 0.048 * btn, 0.0),
            Vector3(0.04, 0.04, 0.04),
            "bouton_boite_" + str(btn))
    # Tableau blanc (whiteboard 2,63x1,33 m) sur le mur gauche,
    # a cote des interrupteurs (AU, keypad, boite 5BP)
    # modele deja a hauteur murale (min.y = 1,71) — abaissé de 30 cm
    _place_prop("res://assets/props/whiteboard.glb",
        Vector3(cx - 3.66, -0.60, -62.0), Vector3(0.0, PI / 2.0, 0.0))


    # Gyrophare bleu du bureau : a mi-chemin entre la lampe (cz) et la
    # porte (cz + 4,9), plaque au plafond. En alerte (incendie, evacuation,
    # confinement -> _alarme_active) le dome tourne et deux faisceaux bleus
    # horizontaux balaient la piece, comme un vrai gyrophare.
    _cree_gyrophare(Vector3(cx, 2.8, cz + 2.45), true)

    # Laptop sur le bureau, clavier vers le siege
    _place_prop("res://assets/props/laptop.glb",
        Vector3(cx, 0.88, cz - 2.3), Vector3(0.0, PI / 2.0, 0.0), 0.35)
    # 2 tabourets medievaux devant le bureau (cote porte)
    for dx_stool in [-0.9, 0.9]:
        _place_prop("res://assets/props/medieval_stool.glb",
            Vector3(cx + dx_stool, 0.35, cz - 1.4), Vector3.ZERO, 0.35)
        _add_static_box(Vector3(cx + dx_stool, 0.35, cz - 1.4), Vector3(0.28, 0.70, 0.30))

    # 2 armoires vertes (filing cabinet) a droite de la porte
    var fc_offset := Vector3(0.57, 0.965, 1.24)
    for dx in [-2.2, -3.2]:
        _place_prop("res://assets/props/filing_cabinet.glb",
            Vector3(cx + dx - fc_offset.x, -0.04, cz + 4.3 - fc_offset.z),
            Vector3(0.0, PI, 0.0))
        _add_static_box(Vector3(cx + dx, 0.925, cz + 4.3), Vector3(0.55, 1.85, 0.95))

    # Poubelle (steel_bin) a gauche de la table
    # offset interne du modele compense : centre a (1.90, 0.22, 0.075)
    _place_prop("res://assets/props/steel_bin.glb",
        Vector3(cx - 1.0 - 1.90, 0.0, cz - 2.2 - 0.075), Vector3.ZERO)
    _add_static_box(Vector3(cx - 1.0, 0.19, cz - 2.2), Vector3(0.35, 0.38, 0.35))

    # Clavier a code (keypad_lock) sous la boite 5BP
    var keypad_pos := Vector3(cx + 2.0, 1.30, cz + 4.72)
    _place_prop("res://assets/props/keypad_lock.glb", keypad_pos,
        Vector3(0.0, PI, 0.0), 2.0)
    _add_static_box(keypad_pos + Vector3(0.0, 0.0, -0.06),
        Vector3(0.18, 0.28, 0.08), "keypad_code")
    # LEDs du clavier : rouge (veille) / verte (saisie active)
    _keypad_led_rouge = OmniLight3D.new()
    _keypad_led_rouge.position = keypad_pos + Vector3(0.0, 0.12, -0.06)
    _keypad_led_rouge.light_color = Color(1.0, 0.1, 0.05)
    _keypad_led_rouge.omni_range = 0.8
    _keypad_led_rouge.light_energy = 1.5
    add_child(_keypad_led_rouge)
    _keypad_led_verte = OmniLight3D.new()
    _keypad_led_verte.position = keypad_pos + Vector3(0.0, 0.12, -0.06)
    _keypad_led_verte.light_color = Color(0.1, 1.0, 0.15)
    _keypad_led_verte.omni_range = 0.8
    _keypad_led_verte.light_energy = 0.0
    add_child(_keypad_led_verte)

    # Noms des boutons, ecriture petite, a cote de la boite
    var noms_boutons := ["Camion", "Fumer", "Maintenance", "Presse", "Zone prod."]
    for btn in range(5):
        var lbl := Label3D.new()
        lbl.text = noms_boutons[btn]
        lbl.font_size = 11
        lbl.modulate = Color(0.85, 0.87, 0.9)
        lbl.outline_size = 4
        lbl.outline_modulate = Color(0.05, 0.05, 0.08)
        # Alignement a gauche : largeur fixe + alignement
        lbl.width = 300.0
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        # Ancrage : le label s'etend depuis son origine vers la droite
        lbl.position = boite_pos + Vector3(0.01, -0.088 + 0.048 * btn, -0.15)
        lbl.rotation = Vector3(0.0, PI / 2.0, 0.0)
        add_child(lbl)

    # Arret d'urgence "champignon" (modele fourni par 3IME, 7 cm) a cote
    # de l'alarme, mur gauche : declenche le confinement (touche M).
    # cx - 3.7 = 8 cm devant la cloison (face interieure a cx - 3.8) :
    # ancre plus profond enterre le modele dans le mur.
    var au_pos := Vector3(cx - 3.70, 1.12, cz + 3.3)
    _place_prop("res://assets/props/estop_mushroom.gltf", au_pos,
        Vector3(0.0, -PI / 2.0, PI))
    _add_static_box(au_pos + Vector3(0.05, 0.0, 0.0),
        Vector3(0.05, 0.14, 0.14), "confinement")
    # Second bouton AU au-dessus : evacuation
    var ev_pos := Vector3(cx - 3.70, 1.52, cz + 3.3)
    _place_prop("res://assets/props/estop_mushroom.gltf", ev_pos,
        Vector3(0.0, -PI / 2.0, PI))
    _add_static_box(ev_pos + Vector3(0.05, 0.0, 0.0),
        Vector3(0.05, 0.14, 0.14), "evacuation")
    var etiquette_ev := Label3D.new()
    etiquette_ev.text = "Evacuation"
    etiquette_ev.font_size = 22
    etiquette_ev.modulate = Color(1.0, 0.95, 0.8)
    etiquette_ev.outline_size = 8
    etiquette_ev.outline_modulate = Color(0.05, 0.05, 0.08)
    etiquette_ev.position = Vector3(cx - 3.72, 1.36, cz + 3.3)
    etiquette_ev.rotation = Vector3(0.0, PI / 2.0, 0.0)
    add_child(etiquette_ev)
    var etiquette_au := Label3D.new()
    etiquette_au.text = "Confinement"
    etiquette_au.font_size = 22
    etiquette_au.modulate = Color(1.0, 0.95, 0.8)
    etiquette_au.outline_size = 10
    etiquette_au.outline_modulate = Color(0.05, 0.05, 0.08)
    etiquette_au.position = Vector3(cx - 3.72, 0.96, cz + 3.3)
    etiquette_au.rotation = Vector3(0.0, PI / 2.0, 0.0)
    add_child(etiquette_au)

    _place_prop(PROP_CLINICIAN_DESK, Vector3(cx, 0.0, cz - 2.2), Vector3(0.0, PI, 0.0))
    _add_static_box(Vector3(cx, 0.375, cz - 2.2), Vector3(1.40, 0.75, 0.75))
    _place_prop(PROP_OFFICE_CHAIR, Vector3(cx, 0.0, cz - 2.9), Vector3.ZERO)
    _add_static_box(Vector3(cx, 0.51, cz - 2.9), Vector3(0.60, 1.02, 0.60))


func _room_box(pos: Vector3, box_size: Vector3, mat: StandardMaterial3D) -> void:
    var mesh := MeshInstance3D.new()
    var bx := BoxMesh.new()
    bx.size = box_size
    mesh.mesh = bx
    mesh.position = pos
    mesh.material_override = mat
    add_child(mesh)
    _add_static_box(pos, box_size)


## Rampe marchable : monte de (x, 0, z_bas) a (x, y_haut, z_haut).
## Pente 30 deg (confortable pour move_and_slide). Extremites exactes.
func _make_ramp_x(z: float, x_bas: float, x_haut: float, y_haut: float, largeur := 1.4) -> void:
    ## Rampe de collision INVISIBLE le long de X (aucun visuel : les escaliers
    ## modeles servent de rendu). Extremites exactes : (x_bas, 0) -> (x_haut, y_haut).
    var dx := x_haut - x_bas
    var longueur := sqrt(dx * dx + y_haut * y_haut)
    var body := StaticBody3D.new()
    var col := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(longueur, 0.3, largeur)
    col.shape = box
    col.rotation.z = atan2(y_haut, dx)
    body.add_child(col)
    body.position = Vector3((x_bas + x_haut) / 2.0, y_haut / 2.0, z)
    add_child(body)


func _cree_gyrophare(pos: Vector3, retourne := false, horizontal := false) -> void:
    ## Gyrophare standard : pivot tournant + dome (modele 3,1 m -> echelle
    ## 0,1) + deux faisceaux horizontaux opposes, comme un vrai gyrophare
    ## a reflecteurs. Pivot et faisceaux enregistres pour _process.
    var scene_glb: PackedScene = load("res://assets/props/gyrophare_bleu.glb")
    if scene_glb == null:
        return
    var pivot := Node3D.new()
    pivot.position = pos
    add_child(pivot)
    # Porteuse = noeud qui porte dome et faisceaux. En fixation MURALE,
    # une roue interne orientee (axe local Y vers +X monde) permet au
    # dome de tourner sur SON PROPRE axe - comme un vrai gyrophare mural
    # - au lieu de basculer autour de la verticale.
    var porteuse := pivot
    if horizontal:
        var roue := Node3D.new()
        roue.rotation.z = -PI / 2.0
        pivot.add_child(roue)
        porteuse = roue
    var dome: Node3D = scene_glb.instantiate()
    dome.scale = Vector3.ONE * 0.1
    if retourne:
        dome.rotation.x = PI  # plafond : base en haut, dome vers le bas
    porteuse.add_child(dome)
    # Lampe integree du GLB (energie importee a 4348 !) : eteinte
    for lumiere in dome.find_children("*", "Light3D", true, false):
        var l_modele: Light3D = lumiere
        l_modele.light_energy = 0.0
    # Deux faisceaux horizontaux opposes, a hauteur du dome
    for direction in [0.0, PI]:
        var faisceau := SpotLight3D.new()
        faisceau.light_color = Color(0.15, 0.48, 1.0)
        faisceau.light_energy = 0.0
        faisceau.spot_range = 45.0
        faisceau.spot_angle = 30.0
        faisceau.visible = false
        faisceau.position = Vector3(
            0.0,
            0.10 if horizontal else (-0.15 if retourne else 0.12),
            0.0)
        faisceau.rotation.y = direction
        porteuse.add_child(faisceau)
        _gyrophare_spots.append(faisceau)
    if horizontal:
        _gyrophare_roues.append(porteuse)
    else:
        _gyrophare_pivots.append(pivot)


func _build_gyrophares_murs() -> void:
    ## 4 gyrophares par mur de l'usine (16 au total, + celui du bureau).
    ## A 5,5 m : au-dessus du garde-corps de la mezzanine (5,1 m).
    var y := 5.5
    for x_mur in [-40.0, -15.0, 10.0, 35.0]:
        _cree_gyrophare(Vector3(x_mur, y, HALL_MIN_Z + 0.2))  # mur nord
        _cree_gyrophare(Vector3(x_mur, y, HALL_MAX_Z - 0.2))  # mur sud
    for z_mur in [-30.0, -10.0, 10.0, 30.0]:
        _cree_gyrophare(Vector3(HALL_MIN_X + 0.2, y, z_mur))  # mur ouest
        _cree_gyrophare(Vector3(HALL_MAX_X - 0.2, y, z_mur))  # mur est


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
        {"path": PROP_DECK_PLATE, "nom": "Plaque de caillebotis",
         "x": -43.2, "y": 0.0, "s": 1.0, "col": Vector3.ZERO},
        {"path": PROP_ELECTRIC_MOTOR, "nom": "Moteur electrique",
         "x": 8.0, "y": 0.0, "s": 1.0, "col": Vector3(1.14, 0.93, 0.86)},
        {"path": PROP_TRANSPALLET, "nom": "Transpallet",
         "x": 46.4, "y": 0.01, "s": 1.0, "col": Vector3(0.62, 1.26, 1.71)},
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
        if lod_manager != null:
            lod_manager.register_cull(label, LodManager.DIST_LABEL)


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
        # Ecran TV du bureau (videosurveillance) : activer le rendu CCTV
        # comme si le joueur etait entre dans le bureau
        _dans_bureau = true
        _maj_rendu_cctv()
        player_node.position = Vector3(-54.9, 0.0, -62.3)
        player_node.rotation.y = 0.0
        for cam in player_node.find_children("*", "Camera3D"):
            cam.rotation.x = 0.06
        await get_tree().create_timer(0.8).timeout
        var tv_shot := get_viewport().get_texture().get_image()
        tv_shot.save_png("res://capture_3d_tv.png")
        print("Capture ecrite : res://capture_3d_tv.png")

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

