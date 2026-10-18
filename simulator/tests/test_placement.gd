extends SceneTree
var frames := 0
var nav = null
var attrapeur = null

func _initialize() -> void:
	nav = preload("res://ui/asset_browser.gd").new()
	get_root().add_child(nav)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		nav._panneau.visible = true
		print("TEST panneau ouvert, boutons=", nav._liste.get_child_count())
		attrapeur = nav._attrapeur
		var entree: Dictionary = nav._manifeste[0]
		attrapeur.demarrer_manuel(entree)
	if frames == 8:
		print("TEST apres demarrage : attrapeur visible=", attrapeur.visible,
			" grille=", nav._grille.visible, " fantome=", nav._fantome.visible,
			" entree=", not nav._entree_courante.is_empty())
		var mv := InputEventMouseMotion.new()
		mv.position = Vector2(576, 324)
		attrapeur._gui_input(mv)
		print("TEST apres mouvement : grille=", nav._grille.visible,
			" pos=", nav._grille.position)
	if frames == 11:
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = true
		clic.position = Vector2(576, 324)
		var avant: int = nav._monde.get_child_count()
		attrapeur._gui_input(clic)
		await process_frame
		print("TEST apres clic : depose=", nav._monde.get_child_count() - avant,
			" grille restante=", nav._grille.visible)
		quit(0)
		return true
	return frames > 11
