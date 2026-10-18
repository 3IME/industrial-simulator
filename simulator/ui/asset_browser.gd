extends CanvasLayer
## Navigateur d'assets FIO (etape 2 ZAI_PROMPT) : panneau a droite,
## touche J. Deux facons de placer :
##   - cliquer une vignette puis cliquer au sol (mode manuel) ;
##   - glisser-deposer la vignette vers l'usine.
## Pendant le placement : GRILLE lumineuse type papier millimetre
## (carreaux fins 20x20, trait epais tous les 5 -> grands carreaux
## de 1 m sur une tuile de 4 m) + objet fantome ; magnetisme 20 cm.

const TUILE := 4.0          # m couverts par la tuile de grille
const PAS_AIMANT := 0.2     # magnetisme au petit carreau (20 cm)

var _racine: Control = null
var _panneau: PanelContainer = null
var _recherche: LineEdit = null
var _liste: VBoxContainer = null
var _manifeste: Array = []
var _grille: MeshInstance3D = null
var _fantome: MeshInstance3D = null
var _attrapeur: Control = null
var _monde: Node3D = null
var _entree_courante: Dictionary = {}

## Vignette draggable : clic = mode manuel, glisser = drag GUI.
class VignetteAsset:
	extends Button

	func _ready() -> void:
		clip_text = true
		icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		expand_icon = true
		custom_minimum_size = Vector2(280, 38)
		add_theme_font_size_override("font_size", 12)

	func _get_drag_data(_point: Vector2) -> Variant:
		var navire := _trouver_navire()
		if navire == null:
			return null
		return navire._get_drag_data_vignette(self, _point)

	func _trouver_navire() -> Node:
		var p := get_parent()
		while p != null:
			if p.has_method("drag_gui_actif"):
				return p
			p = p.get_parent()
		return null
var _file_apercus: Array = []     # vignettes en attente de miniature
var _rendu: SubViewport = null
var _maquette: MeshInstance3D = null
var _cache_apercus := {}          # chemin obj -> texture


func _ready() -> void:
	layer = 4
	_monde = get_node_or_null("/root/Main")
	if _monde == null:
		_monde = get_tree().current_scene
	_charger_manifeste()
	_construire_ui()
	_construire_rendu()
	_construire_references_3d()
	_panneau.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			_panneau.visible = not _panneau.visible
			if _panneau.visible:
				# liberer la souris : sans cela les clics/glissers de
				# vignettes n'atteignent jamais l'interface (souris
				# capturee par le controleur FPS)
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				annuler()
				_attrapeur.terminer()
				if not _attrapeur.visible:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _attrapeur.visible:
			annuler()
			_attrapeur.terminer()
			get_viewport().set_input_as_handled()


func _charger_manifeste() -> void:
	var brut = _lire_json("res://assets/imported/manifest.json")
	var tout: Array = brut["assets"] if brut != null else []
	var filtre = _lire_json("res://assets/imported/assets_filter.json")
	var noire: Array = filtre["blacklist"] if filtre != null else []
	var blanche: Array = filtre["whitelist"] if filtre != null else []
	_manifeste = []
	for entree in tout:
		var nom: String = entree["nom"]
		var garde := true
		if noire.size() > 0:
			for mot in noire:
				if mot != "" and nom.findn(mot) >= 0:
					garde = false
		if blanche.size() > 0 and not blanche.any(
				func(m): return nom.findn(m) >= 0):
			garde = false
		if garde:
			_manifeste.append(entree)


## JSON silencieux : fichier absent (pck incomplet, filtre non cree)
## -> null sans erreur moteur.
func _lire_json(chemin: String) -> Variant:
	if not FileAccess.file_exists(chemin):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(chemin))


func _construire_ui() -> void:
	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_racine)

	_attrapeur = preload("res://ui/asset_attrapeur.gd").new()
	_attrapeur.navire = self
	_racine.add_child(_attrapeur)

	_panneau = PanelContainer.new()
	_panneau.anchor_left = 1.0
	_panneau.anchor_right = 1.0
	_panneau.anchor_top = 0.0
	_panneau.anchor_bottom = 1.0
	_panneau.offset_left = -312
	_panneau.offset_top = 60
	_panneau.offset_right = -6
	_panneau.offset_bottom = -60
	_racine.add_child(_panneau)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 6)
	_panneau.add_child(colonne)

	var titre := Label.new()
	titre.text = "ASSETS USINE (%d)" % _manifeste.size()
	titre.add_theme_font_size_override("font_size", 15)
	colonne.add_child(titre)

	_recherche = LineEdit.new()
	_recherche.placeholder_text = "Rechercher..."
	_recherche.text_changed.connect(func(_t: String) -> void: _remplir())
	colonne.add_child(_recherche)

	var bouton := Button.new()
	bouton.text = "Actualiser"
	bouton.pressed.connect(func() -> void:
		_charger_manifeste()
		_remplir())
	colonne.add_child(bouton)

	var defilement := ScrollContainer.new()
	defilement.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(defilement)

	_liste = VBoxContainer.new()
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.add_child(_liste)
	_remplir()


func _remplir() -> void:
	for enfant in _liste.get_children():
		enfant.queue_free()
	var filtre_texte := _recherche.text.strip_edges().to_lower()
	for entree in _manifeste:
		if filtre_texte != "" and not entree["nom"].to_lower().contains(filtre_texte):
			continue
		var vignette := VignetteAsset.new()
		vignette.text = entree["nom"]
		vignette.clip_text = true
		vignette.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		vignette.expand_icon = true
		vignette.custom_minimum_size = Vector2(280, 38)
		vignette.add_theme_font_size_override("font_size", 12)
		vignette.pressed.connect(func() -> void:
			_attrapeur.demarrer_manuel(entree))
		vignette.set_meta("fio", entree)
		_liste.add_child(vignette)
		_file_apercus.append({"vignette": vignette, "entree": entree})


## --- Grille papier millimetre + fantome ------------------------------

func _tex_grille() -> ImageTexture:
	var cote := 500            # 20 carreaux de 25 px
	var pas := 25
	var img := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.92, 0.94, 0.97, 0.10))
	for i in range(21):
		var epais := i % 5 == 0
		var couleur := Color(0.93, 0.95, 0.98, 0.85 if epais else 0.45)
		for k in range(3 if epais else 1):
			if i * pas + k < cote:
				for j in cote:
					img.set_pixel(i * pas + k, j, couleur)
					img.set_pixel(j, i * pas + k, couleur)
	return ImageTexture.create_from_image(img)


## Apercu 3D 96x96 : un seul SubViewport reutilise, maquette eclairée,
## cadence de 2 rendus par frame tant que le panneau est ouvert.
func _construire_rendu() -> void:
	_rendu = SubViewport.new()
	_rendu.size = Vector2i(96, 96)
	_rendu.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_rendu)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0, 0.6, 2.2)
	camera.rotation_degrees = Vector3(-14, 0, 0)
	_rendu.add_child(camera)
	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-35, 30, 0)
	lumiere.light_energy = 1.4
	_rendu.add_child(lumiere)
	var ambiance := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.11, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.6)
	env.ambient_light_energy = 1.0
	ambiance.environment = env
	_rendu.add_child(ambiance)
	_maquette = MeshInstance3D.new()
	_rendu.add_child(_maquette)


func _process(_delta: float) -> void:
	# drag GUI en cours : le recepteur plein ecran doit etre visible
	# pour recevoir le depot
	if get_viewport().gui_is_dragging():
		if not _attrapeur.visible:
			_attrapeur.armer_drag()
	elif _attrapeur._mode_drag:
		_attrapeur.terminer()
	if not _panneau.visible or _file_apercus.is_empty() or _rendu == null:
		return
	for _i in range(2):
		if _file_apercus.is_empty():
			return
		var travail: Dictionary = _file_apercus.pop_front()
		var vignette: Button = travail["vignette"]
		var entree: Dictionary = travail["entree"]
		if not is_instance_valid(vignette):
			continue
		var chemin_obj: String = entree["obj"]
		if _cache_apercus.has(chemin_obj):
			vignette.icon = _cache_apercus[chemin_obj]
			continue
		var mesh = load("res://" + chemin_obj)
		if mesh is Mesh:
			_maquette.mesh = mesh
			if entree.has("tres"):
				var mat = load("res://" + entree["tres"])
				if mat is Material:
					_maquette.material_override = mat
			# recadrer la camera sur la boite reelle du mesh
			var boite: AABB = mesh.get_aabb()
			var rayon := boite.size.length() * 0.5
			var echelle := 1.4 / maxf(rayon, 0.001)
			_maquette.scale = Vector3.ONE * echelle
			_maquette.position = -boite.get_center() * echelle
			await RenderingServer.frame_post_draw
			if is_instance_valid(vignette):
				var texture := ImageTexture.create_from_image(
					_rendu.get_texture().get_image())
				_cache_apercus[chemin_obj] = texture
				vignette.icon = texture
		_maquette.mesh = null


func _construire_references_3d() -> void:
	_grille = MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(TUILE, TUILE)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _tex_grille()
	plan.material = mat
	_grille.mesh = plan
	_grille.visible = false

	_fantome = MeshInstance3D.new()
	var mat_f := StandardMaterial3D.new()
	mat_f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_f.albedo_color = Color(0.85, 0.9, 1.0, 0.5)
	_fantome.material_override = mat_f
	_fantome.visible = false

	if _monde != null:
		_monde.add_child(_grille)
		_monde.add_child(_fantome)


func _position_sol(position_ecran: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _monde == null:
		return Vector3.ZERO
	var origine := camera.project_ray_origin(position_ecran)
	var direction := camera.project_ray_normal(position_ecran)
	var requete := PhysicsRayQueryParameters3D.create(
		origine, origine + direction * 200.0)
	var impact: Dictionary = _monde.get_world_3d().direct_space_state \
		.intersect_ray(requete)
	if impact.is_empty():
		return Vector3.ZERO
	return Vector3(
		snappedf(impact.position.x, PAS_AIMANT),
		impact.position.y + 0.01,
		snappedf(impact.position.z, PAS_AIMANT))


func montrer_references(entree: Dictionary, position_ecran: Vector2) -> void:
	_entree_courante = entree
	var mesh = load("res://" + entree["obj"])
	if mesh is Mesh:
		_fantome.mesh = mesh
	var point := _position_sol(position_ecran)
	_grille.position = point + Vector3(0, 0.02, 0)
	_fantome.position = point
	_grille.visible = true
	_fantome.visible = true


func deposer(position_ecran: Vector2) -> void:
	if not _entree_courante.is_empty() and _monde != null:
		var mesh = load("res://" + _entree_courante["obj"])
		if mesh is Mesh:
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			if _entree_courante.has("tres"):
				var mat = load("res://" + _entree_courante["tres"])
				if mat is Material:
					instance.material_override = mat
			instance.position = _position_sol(position_ecran)
			_monde.add_child(instance)
			print("Asset FIO depose : ", _entree_courante["nom"])
	annuler()


func drag_gui_actif() -> bool:
	return get_viewport().gui_is_dragging()


func masquer_references() -> void:
	_grille.visible = false
	_fantome.visible = false


func _get_drag_data_vignette(vignette: Control, point: Vector2) -> Variant:
	var apercu := Label.new()
	apercu.text = vignette.text
	vignette.set_drag_preview(apercu)
	return {"fio": vignette.get_meta("fio")}


func annuler() -> void:
	_entree_courante = {}
	_grille.visible = false
	_fantome.visible = false
