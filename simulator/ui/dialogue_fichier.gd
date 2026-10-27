extends CanvasLayer
## Fenetre de fichiers (Enregistrer sous / Ouvrir) — design maintenance
## industrielle, comme la confirmation de sortie. Dossier fixe
## user://sauvegardes (affiche en console) ; choix du nom + liste des
## sauvegardes existantes. Entree = valider, Echap = annuler.

signal fichier_choisi(chemin: String)

const DOSSIER := "user://sauvegardes"

var mode := "save"             # "save" ou "open"
var _racine: Control = null
var _champ_nom: LineEdit = null
var _liste: ItemList = null
var _bouton_valider: Button = null


func _ready() -> void:
	layer = 101
	visible = false
	DirAccess.make_dir_recursive_absolute(DOSSIER)
	_construire()


func ouvrir(mode_demande: String, nom_defaut := "") -> void:
	mode = mode_demande
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_group("joueur", "set_physics_process", false)
	get_tree().call_group("joueur", "set_process_input", false)
	_champ_nom.text = nom_defaut
	_remplir_liste()
	if mode == "save":
		_bouton_valider.text = "ENREGISTRER"
	else:
		_bouton_valider.text = "OUVRIR"
	_champ_nom.grab_focus()


func fermer() -> void:
	visible = false
	get_tree().call_group("joueur", "set_physics_process", true)
	get_tree().call_group("joueur", "set_process_input", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _construire() -> void:
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.55)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(voile)

	var panneau := PanelContainer.new()
	panneau.custom_minimum_size = Vector2(480, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.97)
	style.border_color = Color(1.0, 0.42, 0.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panneau.add_theme_stylebox_override("panel", style)
	panneau.set_anchors_preset(Control.PRESET_CENTER)
	panneau.offset_left = -250
	panneau.offset_right = 250
	panneau.offset_top = -170
	panneau.offset_bottom = 170
	add_child(panneau)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 12)
	panneau.add_child(colonne)

	var bande := TextureRect.new()
	bande.texture = _tex_rayures()
	bande.custom_minimum_size = Vector2(0, 12)
	bande.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bande.stretch_mode = TextureRect.STRETCH_TILE
	colonne.add_child(bande)

	var titre := Label.new()
	titre.text = "ENREGISTRER SOUS..."
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 20)
	titre.add_theme_color_override("font_color", Color(1.0, 0.42, 0.0))
	colonne.add_child(titre)

	_champ_nom = LineEdit.new()
	_champ_nom.placeholder_text = "nom_de_la_sauvegarde"
	_champ_nom.add_theme_font_size_override("font_size", 16)
	_champ_nom.text_submitted.connect(func(_t: String) -> void: _valider())
	colonne.add_child(_champ_nom)

	_liste = ItemList.new()
	_liste.custom_minimum_size = Vector2(0, 130)
	_liste.add_theme_font_size_override("font_size", 13)
	_liste.item_selected.connect(func(indice: int) -> void:
		_champ_nom.text = _liste.get_item_text(indice))
	colonne.add_child(_liste)

	var boutons := HBoxContainer.new()
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	boutons.add_theme_constant_override("separation", 20)
	colonne.add_child(boutons)

	var annuler := Button.new()
	annuler.text = "ANNULER"
	annuler.custom_minimum_size = Vector2(140, 44)
	annuler.add_theme_font_size_override("font_size", 16)
	var style_annuler := StyleBoxFlat.new()
	style_annuler.bg_color = Color(0.23, 0.24, 0.27)
	style_annuler.set_corner_radius_all(8)
	annuler.add_theme_stylebox_override("normal", style_annuler)
	annuler.pressed.connect(fermer)
	boutons.add_child(annuler)

	_bouton_valider = Button.new()
	_bouton_valider.text = "ENREGISTRER"
	_bouton_valider.custom_minimum_size = Vector2(180, 44)
	_bouton_valider.add_theme_font_size_override("font_size", 16)
	var style_valider := StyleBoxFlat.new()
	style_valider.bg_color = Color(1.0, 0.42, 0.0)
	style_valider.set_corner_radius_all(8)
	_bouton_valider.add_theme_stylebox_override("normal", style_valider)
	var style_valider_hover := StyleBoxFlat.new()
	style_valider_hover.bg_color = Color(1.0, 0.54, 0.2)
	style_valider_hover.set_corner_radius_all(8)
	_bouton_valider.add_theme_stylebox_override("hover", style_valider_hover)
	_bouton_valider.pressed.connect(_valider)
	boutons.add_child(_bouton_valider)


func _remplir_liste() -> void:
	_liste.clear()
	var dossier := DirAccess.open(DOSSIER)
	if dossier == null:
		return
	for nom in dossier.get_files():
		if nom.ends_with(".json"):
			_liste.add_item(nom.trim_suffix(".json"))


func _valider() -> void:
	var nom := _champ_nom.text.strip_edges().replace(" ", "_")
	if nom == "":
		return
	if not nom.ends_with(".json"):
		nom += ".json"
	fichier_choisi.emit(DOSSIER + "/" + nom)
	fermer()


func _tex_rayures() -> ImageTexture:
	var cote := 32
	var img := Image.create(cote, cote, false, Image.FORMAT_RGB8)
	for x in cote:
		for y in cote:
			var jaune := ((x + y) % 32) < 16
			img.set_pixel(x, y,
				Color(1.0, 0.82, 0.0) if jaune else Color(0.06, 0.06, 0.06))
	return ImageTexture.create_from_image(img)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			fermer()
			get_viewport().set_input_as_handled()
