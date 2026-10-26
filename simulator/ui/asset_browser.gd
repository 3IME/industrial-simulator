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
var _liste: GridContainer = null
var _manifeste: Array = []
var _grille: MeshInstance3D = null
var _fantome: Node3D = null
var _attrapeur: Control = null
var _monde: Node3D = null
var _entree_courante: Dictionary = {}
var _derniere_pos_souris := Vector2.ZERO
var _angle_fantome := 0.0            # rotation du fantome (R, pas 45)
var _fantome_cle := ""
var _apercu_en_cours := false     # generation serialisee des miniatures

## Echelle manuelle pour les modeles dont les unites ne sont pas en
## metres (ex : RetroReflectiveMirror exporte en ~1 cm) ; 1.0 sinon.
const ECHELLES := {"RetroReflectiveMirror": 35.0}


func _echelle_de(nom: String) -> float:
	for cle in ECHELLES:
		if nom.findn(cle) >= 0:
			return float(ECHELLES[cle])
	return 1.0               # chemin du fantome charge
var _deposes: Array = []             # [{mesh, corps, surbrillance}]
var _selection := -1                 # indice dans _deposes (-1 : aucun)

## Vignette draggable : clic = mode manuel, glisser = drag GUI.
class VignetteAsset:
	extends Button

	func _ready() -> void:
		clip_text = true
		text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		expand_icon = true
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		add_theme_constant_override("icon_max_width", 110)
		custom_minimum_size = Vector2(130, 132)
		add_theme_font_size_override("font_size", 10)

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
var _maquette: Node3D = null
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


func _input(event: InputEvent) -> void:
	# fleches : deplacement de l'objet selectionne — traite AVANT le
	# GUI sinon le ScrollContainer de la liste les intercepte
	if event is InputEventKey and event.pressed and not event.echo \
			and _selection >= 0 \
			and [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN].has(event.keycode):
		var sel_i: Dictionary = _deposes[_selection]
		var deplacement := Vector3.ZERO
		match event.keycode:
			KEY_LEFT:
				deplacement.x = -PAS_AIMANT
			KEY_RIGHT:
				deplacement.x = PAS_AIMANT
			KEY_UP:
				deplacement.z = -PAS_AIMANT
			KEY_DOWN:
				deplacement.z = PAS_AIMANT
		for cible_i in ["mesh", "corps", "surbrillance"]:
			sel_i[cible_i].position += deplacement
		_cadrer_selection()
		get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	_sur_evenement_souris(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			_panneau.visible = not _panneau.visible
			if _panneau.visible:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				annuler()
				_attrapeur.terminer()
				if not _attrapeur.visible:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_maj_blocage_joueur()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			if _attrapeur.visible and not _entree_courante.is_empty():
				_angle_fantome = fmod(_angle_fantome + PI / 4.0, TAU)
				_fantome.rotation.y = _angle_fantome
			elif _selection >= 0:
				var sel_r: Dictionary = _deposes[_selection]
				sel_r["mesh"].rotation.y += PI / 12.0   # 15 degres
				sel_r["corps"].rotation.y = sel_r["mesh"].rotation.y
				_cadrer_selection()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _attrapeur.visible:
			if get_viewport().gui_is_dragging():
				pass   # drag natif en cours : NOTIFICATION_DRAG_END
				       # rangera proprement, ne pas recapturer la souris
			else:
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

	_liste = GridContainer.new()
	_liste.columns = 2
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste.add_theme_constant_override("h_separation", 8)
	_liste.add_theme_constant_override("v_separation", 8)
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
		vignette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vignette.expand_icon = true
		vignette.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vignette.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		vignette.add_theme_constant_override("icon_max_width", 110)
		vignette.custom_minimum_size = Vector2(130, 132)
		vignette.add_theme_font_size_override("font_size", 10)
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
	# MONDE PROPRE : un SubViewport partage par defaut le World3D de
	# la scene parente — les echantillons de miniatures apparaissaient
	# donc DANS l'usine (meme monde), un par un au rythme des vignettes
	_rendu.own_world_3d = true
	_rendu.world_3d = World3D.new()
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
	_maquette = Node3D.new()
	_rendu.add_child(_maquette)


var _diag_drag := false

func _diag_dragasset() -> void:
	# test automatique : ouvrir le panneau puis declencher un VRAI
	# drag GUI depuis la premiere vignette (force_drag)
	_panneau.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().process_frame
	await get_tree().process_frame
	var vignette: Control = _liste.get_child(0) if _liste.get_child_count() > 0 else null
	if vignette == null:
		print("DIAG : aucune vignette")
		return
	var donnee: Variant = vignette._get_drag_data(Vector2.ZERO)
	print("DIAG : drag reel lance depuis ", vignette.text,
		" data=", donnee != null)
	await get_tree().create_timer(0.8).timeout
	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(320, 180)
	Input.parse_input_event(mv)
	await get_tree().create_timer(0.4).timeout
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = Vector2(320, 180)
	Input.parse_input_event(rel)
	print("DIAG : relachement injecte")


func _process(_delta: float) -> void:
	# drag GUI en cours : le recepteur plein ecran doit etre visible
	# pour recevoir le depot
	if "--auto-dragasset" in OS.get_cmdline_user_args() and not _diag_drag:
		_diag_drag = true
		_diag_dragasset()
	if get_viewport().gui_is_dragging():
		_derniere_pos_souris = get_viewport().get_mouse_position()
		if not _attrapeur.visible:
			_attrapeur.armer_drag()
		# suivi garanti du fantome pendant TOUT le vol, meme si
		# _can_drop_data n'est pas sollicite par le drag natif
		if not _entree_courante.is_empty():
			_maj_fantome(_derniere_pos_souris)
	elif _attrapeur._mode_drag or not _entree_courante.is_empty():
		# le drag vient de se terminer : depot autonome a la DERNIERE
		# position connue (get_mouse_position peut etre remis a zero
		# par Godot au moment ou le drag natif se termine)
		if not _entree_courante.is_empty() \
				and not sur_panneau(_derniere_pos_souris):
			deposer(_derniere_pos_souris)
		else:
			annuler()
		_attrapeur.terminer()
	elif _selection < 0 and (_grille.visible or _fantome.visible):
		# RAMASSE-MIETTES : hors drag, hors mode manuel ET hors
		# SELECTION (la grille reste affichee tant qu un objet est
		# selectionne en jaune) — auto-guerison a la frame suivante
		annuler()
	if _apercu_en_cours:
		return
	if not _panneau.visible or _file_apercus.is_empty() or _rendu == null:
		return
	_apercu_en_cours = true
	_generer_apercus()


## Genere les miniatures SEQUENTIELLEMENT : _process etant rappele
## chaque frame, deux chaines d'await paralleles capturaient la
## maquette d'un AUTRE objet (icones melangees/grises/orange-noir).
func _generer_apercus() -> void:
	while _panneau.visible and not _file_apercus.is_empty():
		var travail: Dictionary = _file_apercus.pop_front()
		var vignette: Button = travail["vignette"]
		var entree: Dictionary = travail["entree"]
		if not is_instance_valid(vignette):
			continue
		var chemin_obj: String = entree["obj"]
		if _cache_apercus.has(chemin_obj):
			vignette.icon = _cache_apercus[chemin_obj]
			continue
		# detacher IMMEDIATEMENT (queue_free est differe d'une frame)
		for enfant_p in _maquette.get_children():
			_maquette.remove_child(enfant_p)
			enfant_p.queue_free()
		var ressource_p = load("res://" + chemin_obj)
		var echantillon: Node3D = null
		if ressource_p is PackedScene:
			echantillon = ressource_p.instantiate()
			_maquette.add_child(echantillon)
		elif ressource_p is Mesh:
			var mi_p := MeshInstance3D.new()
			mi_p.mesh = ressource_p
			_maquette.add_child(mi_p)
			echantillon = mi_p
		if echantillon != null:
			var boite: AABB = _boite_de(echantillon)
			var rayon := boite.size.length() * 0.5
			var echelle := _echelle_de(entree["nom"])
			if echelle == 1.0:
				echelle = clampf(1.4 / maxf(rayon, 0.001), 0.25, 1.5)
			_maquette.scale = Vector3.ONE * echelle
			_maquette.position = -boite.get_center() * echelle
			# 2 frames de rendu avant capture (materiaux + draw)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			if is_instance_valid(vignette):
				var texture := ImageTexture.create_from_image(
					_rendu.get_texture().get_image())
				_cache_apercus[chemin_obj] = texture
				vignette.icon = texture
		for enfant_p in _maquette.get_children():
			_maquette.remove_child(enfant_p)
			enfant_p.queue_free()
		await get_tree().process_frame
	_apercu_en_cours = false


func _construire_references_3d() -> void:
	_grille = MeshInstance3D.new()
	var plan := PlaneMesh.new()
	# GRILLE FIXE : tout le sol de l'usine (hall 120 x 90 m), la
	# texture de 4 m se repete (uv1_scale) — petits carreaux 20 cm,
	# traits epais 1 m. Seul l'OBJET se deplace dessus.
	plan.size = Vector2(120.0, 90.0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _tex_grille()
	mat.uv1_scale = Vector3(120.0 / TUILE, 90.0 / TUILE, 1.0)
	plan.material = mat
	_grille.mesh = plan
	_grille.position = Vector3(2.0, 0.02, 0.0)   # centre du hall
	_grille.visible = false

	_fantome = Node3D.new()
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


func maj_blocage() -> void:
	_maj_blocage_joueur()


func montrer_references(entree: Dictionary, position_ecran: Vector2) -> void:
	_entree_courante = entree
	_charger_fantome(entree)
	_fantome.scale = Vector3.ONE * _echelle_de(entree["nom"])
	_maj_fantome(position_ecran)


## Charge la ressource du fantome (Mesh ou PackedScene) une fois par
## objet (cle = chemin) ; le fantome est un Node3D porteur.
func _charger_fantome(entree: Dictionary) -> void:
	var chemin: String = entree["obj"]
	if _fantome_cle == chemin:
		return
	_fantome_cle = chemin
	for enfant in _fantome.get_children():
		enfant.queue_free()
	var ressource = load("res://" + chemin)
	if ressource is PackedScene:
		_fantome.add_child(ressource.instantiate())
	elif ressource is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = ressource
		_fantome.add_child(mi)


## AABB locale d'un noeud (ses meshes, echelle/rotation incluses).
func _boite_de(noeud: Node3D) -> AABB:
	var acc := AABB()
	var premier := true
	for m in noeud.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		var b: AABB = m.global_transform * m.mesh.get_aabb()
		if premier:
			acc = b
			premier = false
		else:
			acc = acc.merge(b)
	if premier:
		return AABB(Vector3(-0.25, -0.25, -0.25), Vector3(0.5, 0.5, 0.5))
	acc.position -= noeud.global_transform.origin
	return acc


## Positionne le fantome sous la position ecran donnee, snapped aux
## intersections des carreaux (20 cm). La grille, fixe, est juste
## montree pendant le placement.
func _maj_fantome(position_ecran: Vector2) -> void:
	var point := _position_sol(position_ecran)
	_fantome.position = Vector3(point.x,
		point.y - _boite_de(_fantome).position.y, point.z)
	_grille.visible = true
	_fantome.visible = true


func deposer(position_ecran: Vector2) -> void:
	if not _entree_courante.is_empty() and _monde != null:
		var ressource = load("res://" + _entree_courante["obj"])
		var point_dep := _position_sol(position_ecran)
		if point_dep == Vector3.ZERO:
			# raycast rate (rayon rasant, HUD) : REPLI au plan du sol
			var cam_dep := get_viewport().get_camera_3d()
			if cam_dep == null:
				annuler()
				return
			var origine_r := cam_dep.project_ray_origin(position_ecran)
			var direction_r := cam_dep.project_ray_normal(position_ecran)
			if absf(direction_r.y) < 0.001:
				annuler()
				return
			var t_r := -origine_r.y / direction_r.y
			if t_r <= 0.0 or t_r > 250.0:
				annuler()
				return
			var p_r := origine_r + direction_r * t_r
			point_dep = Vector3(
				clampf(snappedf(p_r.x, PAS_AIMANT), -57.0, 61.0),
				0.01,
				clampf(snappedf(p_r.z, PAS_AIMANT), -44.0, 44.0))
			print("FIO : raycast rate — repli au sol en ", point_dep)
		if instance != null:
			_creer_objet(_entree_courante, point_dep, _angle_fantome)
	annuler()


func _sur_evenement_souris(event: InputEvent) -> void:
	# clic droit : selectionner / deselectionner un objet depose
	# (visee au centre quand la souris est capturee)
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT \
			and not get_viewport().gui_is_dragging():
		_selectionner_sous_viseur()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed \
			and (event.button_index == MOUSE_BUTTON_WHEEL_UP \
			or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) \
			and _selection >= 0:
		var pas := 0.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.1
		var sel_m: Dictionary = _deposes[_selection]
		sel_m["mesh"].position.y = maxf(sel_m["mesh"].position.y + pas, 0.01)
		sel_m["corps"].position.y = maxf(sel_m["corps"].position.y + pas, 0.01)
		_cadrer_selection()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed \
			and event.keycode == KEY_DELETE and _selection >= 0:
		supprimer_selection()
		get_viewport().set_input_as_handled()


func _selectionner_sous_viseur() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _monde == null:
		return
	var pos_ecran := get_viewport().get_mouse_position() \
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
		else get_viewport().get_visible_rect().size / 2.0
	var origine := camera.project_ray_origin(pos_ecran)
	var direction := camera.project_ray_normal(pos_ecran)
	var requete := PhysicsRayQueryParameters3D.create(
		origine, origine + direction * 200.0)
	var impact: Dictionary = _monde.get_world_3d().direct_space_state \
		.intersect_ray(requete)
	deselectionner()
	if impact.is_empty() or not impact.collider.has_meta("fio_indice"):
		return
	_selection = int(impact.collider.get_meta("fio_indice"))
	if _selection >= _deposes.size() or _deposes[_selection].is_empty():
		_selection = -1
		return
	_deposes[_selection]["surbrillance"].visible = true
	_grille.visible = true
	_panneau.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_maj_blocage_joueur()
	print("FIO selection : ", _deposes[_selection]["nom"],
		" (R : rotation, molette : hauteur, SUPPR : supprimer)")


## Recalcule la surbrillance apres rotation/deplacement.
func _cadrer_selection() -> void:
	if _selection < 0 or _selection >= _deposes.size() \
			or _deposes[_selection].is_empty():
		return
	var sel_c: Dictionary = _deposes[_selection]
	var noeud_c: Node3D = sel_c["mesh"]
	var boite_c := _boite_de(noeud_c)
	var cadre_c: MeshInstance3D = sel_c["surbrillance"]
	cadre_c.position = noeud_c.position + boite_c.get_center()
	cadre_c.rotation.y = noeud_c.rotation.y


func deselectionner() -> void:
	if _selection >= 0 and _selection < _deposes.size() \
			and not _deposes[_selection].is_empty():
		_deposes[_selection]["surbrillance"].visible = false
	_selection = -1
	if _entree_courante.is_empty() and not _attrapeur.visible:
		_grille.visible = false
	_maj_blocage_joueur()


func supprimer_selection() -> void:
	if _selection < 0 or _selection >= _deposes.size() \
			or _deposes[_selection].is_empty():
		return
	var sel_s: Dictionary = _deposes[_selection]
	print("FIO supprime : ", sel_s["nom"])
	sel_s["mesh"].queue_free()
	sel_s["corps"].queue_free()
	sel_s["surbrillance"].queue_free()
	_deposes[_selection] = {}
	_selection = -1
	_grille.visible = false
	_maj_blocage_joueur()


## Bloque/libere le personnage (fleches, physique) pendant les
## operations du navigateur : plus de 'personnage qui bouge avec
## l'objet'.
func _maj_blocage_joueur() -> void:
	var bloquer := _attrapeur.visible or _selection >= 0 or _panneau.visible
	get_tree().call_group("joueur", "set_physics_process", not bloquer)
	get_tree().call_group("joueur", "set_process_input", not bloquer)


func panneau_ouvert() -> bool:
	return _panneau != null and _panneau.visible


func sur_panneau(position_ecran: Vector2) -> bool:
	return _panneau.visible \
		and _panneau.get_global_rect().has_point(position_ecran)


func derniere_pos_souris() -> Vector2:
	return _derniere_pos_souris


func forcer_entree(entree: Dictionary) -> void:
	_entree_courante = entree


func drag_gui_actif() -> bool:
	return get_viewport().gui_is_dragging()


func masquer_references() -> void:
	_grille.visible = false
	_fantome.visible = false


func _get_drag_data_vignette(vignette: Control, _point: Vector2) -> Variant:
	var entree: Dictionary = vignette.get_meta("fio")
	_entree_courante = entree
	_charger_fantome(entree)
	_maj_fantome(get_viewport().get_mouse_position())
	var apercu := Label.new()
	apercu.text = vignette.text
	vignette.set_drag_preview(apercu)
	return {"fio": entree}


## Instancie un objet FIO (Mesh ou PackedScene) + collision +
## surbrillance, et l'inscrit dans le registre. Utilise par deposer()
## ET par le chargement de sauvegarde.
func _creer_objet(entree: Dictionary, point_dep: Vector3, angle: float) -> void:
	var ressource = load("res://" + entree["obj"])
	var instance: Node3D = null
	if ressource is PackedScene:
		instance = ressource.instantiate()
	elif ressource is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = ressource
		instance = mi
	if instance == null or _monde == null:
		return
	instance.scale = Vector3.ONE * _echelle_de(entree["nom"])
	# attacher AVANT de mesurer : global_transform invalide hors arbre
	_monde.add_child(instance)
	instance.rotation.y = angle
	var boite: AABB = _boite_de(instance)
	instance.position = Vector3(point_dep.x,
		point_dep.y - boite.position.y, point_dep.z)
	var corps := StaticBody3D.new()
	corps.position = instance.position + boite.get_center()
	corps.rotation.y = angle
	var forme := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = boite.size
	forme.shape = cube
	corps.add_child(forme)
	corps.set_meta("fio_indice", _deposes.size())
	_monde.add_child(corps)
	var cadre := MeshInstance3D.new()
	var cube_sel := BoxMesh.new()
	cube_sel.size = boite.size + Vector3(0.06, 0.06, 0.06)
	var mat_sel := StandardMaterial3D.new()
	mat_sel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_sel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_sel.albedo_color = Color(1.0, 0.85, 0.1, 0.35)
	cube_sel.material = mat_sel
	cadre.mesh = cube_sel
	cadre.position = instance.position + boite.get_center()
	cadre.rotation.y = angle
	cadre.visible = false
	_monde.add_child(cadre)
	_deposes.append({"mesh": instance, "corps": corps,
		"surbrillance": cadre, "nom": entree["nom"], "obj": entree["obj"]})


func annuler() -> void:
	_entree_courante = {}
	_angle_fantome = 0.0
	_fantome.rotation.y = 0.0
	_fantome_cle = ""
	for enfant in _fantome.get_children():
		enfant.queue_free()
	_grille.visible = false
	_fantome.visible = false
