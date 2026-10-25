extends CanvasLayer
## Fenetre de confirmation de sortie (design maintenance industrielle) :
## bande hachee jaune/noir, panneau sombre bordure orange, boutons
## NON / OUI. Entree = Oui, Echap = Non. Le personnage est fige tant
## que la fenetre est ouverte.

signal confirme

var _racine: Control = null
var _bouton_oui: Button = null


func _ready() -> void:
	layer = 100
	visible = false
	_construire()


func ouvrir() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_group("joueur", "set_physics_process", false)
	get_tree().call_group("joueur", "set_process_input", false)
	_bouton_oui.grab_focus()


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
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 18
	panneau.add_theme_stylebox_override("panel", style)
	panneau.set_anchors_preset(Control.PRESET_CENTER)
	panneau.offset_left = -240
	panneau.offset_right = 240
	panneau.offset_top = -140
	panneau.offset_bottom = 140
	add_child(panneau)

	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 14)
	panneau.add_child(colonne)

	# Bande de danger hachee jaune/noir (signale l'arret d'installation)
	var bande := TextureRect.new()
	bande.texture = _tex_rayures()
	bande.custom_minimum_size = Vector2(0, 12)
	bande.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bande.stretch_mode = TextureRect.STRETCH_TILE
	colonne.add_child(bande)

	var titre := Label.new()
	titre.text = "ARRET DU SIMULATEUR"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 22)
	titre.add_theme_color_override("font_color", Color(1.0, 0.42, 0.0))
	colonne.add_child(titre)

	var message := Label.new()
	message.text = "Voulez-vous vraiment quitter l'usine ?\nLa session en cours sera fermee."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 15)
	message.add_theme_color_override("font_color", Color(0.78, 0.8, 0.85))
	colonne.add_child(message)

	var boutons := HBoxContainer.new()
	boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	boutons.add_theme_constant_override("separation", 20)
	colonne.add_child(boutons)

	var non := Button.new()
	non.text = "NON"
	non.custom_minimum_size = Vector2(150, 46)
	non.add_theme_font_size_override("font_size", 18)
	var style_non := StyleBoxFlat.new()
	style_non.bg_color = Color(0.23, 0.24, 0.27)
	style_non.set_corner_radius_all(8)
	non.add_theme_stylebox_override("normal", style_non)
	non.pressed.connect(fermer)
	boutons.add_child(non)

	var oui := Button.new()
	oui.text = "OUI, QUITTER"
	oui.custom_minimum_size = Vector2(190, 46)
	oui.add_theme_font_size_override("font_size", 18)
	var style_oui := StyleBoxFlat.new()
	style_oui.bg_color = Color(1.0, 0.42, 0.0)
	style_oui.set_corner_radius_all(8)
	oui.add_theme_stylebox_override("normal", style_oui)
	var style_oui_hover := StyleBoxFlat.new()
	style_oui_hover.bg_color = Color(1.0, 0.54, 0.2)
	style_oui_hover.set_corner_radius_all(8)
	oui.add_theme_stylebox_override("hover", style_oui_hover)
	oui.pressed.connect(_quitter)
	boutons.add_child(oui)
	_bouton_oui = oui


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
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_quitter()
			get_viewport().set_input_as_handled()


func _quitter() -> void:
	fermer()
	confirme.emit()
	print("Sortie confirmee : arret du simulateur")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().quit(0)
