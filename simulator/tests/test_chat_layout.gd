extends SceneTree
## Verifie que les lignes du journal de chat tombent DANS l'ecran
## (regression : ancres 'bas' mal resolues sous CanvasLayer -> y<0).

var frames := 0
var chat_ref = null

func _initialize() -> void:
	chat_ref = preload("res://ui/chat.gd").new()
	get_root().add_child(chat_ref)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		# viewport headless = 64x64 : forcer la racine a la taille reelle
		chat_ref._racine.size = Vector2(1152, 648)
		chat_ref._racine.reset_size()
		chat_ref._racine.size = Vector2(1152, 648)
	if frames == 4 and chat_ref._lignes.is_empty():
		chat_ref._ajouter_ligne("PROF : test ligne 1")
		chat_ref._ajouter_ligne("ELEVE : test ligne 2")
	if frames == 6:
		print("VIEWPORT ", get_root().size)
		print("RACINE ", chat_ref._racine.get_rect(), " journal=", chat_ref._journal.get_rect())
	if frames < 10:
		return false
	var nb_visibles := 0
	for ligne in chat_ref._lignes:
		var rect: Rect2 = (ligne["label"] as Label).get_global_rect()
		print("LIGNE rect=", rect)
		if rect.position.x >= 0 and rect.position.y >= 0 \
				and rect.end.x <= 1152 and rect.end.y <= 648:
			nb_visibles += 1
	if nb_visibles == chat_ref._lignes.size() and nb_visibles > 0:
		print("CHAT_LAYOUT OK")
		quit(0)
	else:
		print("CHAT_LAYOUT ECHEC")
		quit(1)
	return true
