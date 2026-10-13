extends CanvasLayer
## Chat de session (chantier 8 de la feuille de route reseau).
## Touche T : ouvrir/fermer la barre de saisie ; Entree : envoyer ;
## Echap : fermer. Liste deroulante : diffusion a tous ou destinataire
## unique (le serveur route). Journal en bas a gauche, 8 derniers
## messages, fondu des lignes anciennes.

const NB_LIGNES := 8
const DUREE_AFFICHAGE := 12.0

var _journal: VBoxContainer = null
var _barre: HBoxContainer = null
var _saisie: LineEdit = null
var _destinataires: OptionButton = null
var _lignes: Array = []          # [{label, chrono}]


func _ready() -> void:
	layer = 5
	_construire_journal()
	_construire_barre()
	NetworkManager.message_recu.connect(_sur_message)


func _process(delta: float) -> void:
	for ligne in _lignes:
		ligne["chrono"] = float(ligne["chrono"]) - delta
		var reste: float = float(ligne["chrono"])
		var opacite: float = clampf(reste / 3.0, 0.0, 1.0) if reste < 3.0 else 1.0
		(ligne["label"] as Label).modulate.a = opacite
		if reste <= 0.0 and not _barre.visible:
			(ligne["label"] as Label).visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T and not _barre.visible:
			_ouvrir()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _barre.visible:
			_fermer()
			get_viewport().set_input_as_handled()


func _ouvrir() -> void:
	maj_destinataires()
	_barre.visible = true
	_saisie.grab_focus()


func _fermer() -> void:
	_barre.visible = false
	_saisie.release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Roster : "Tous" + chaque pair connu (id -> nom affichable).
func maj_destinataires() -> void:
	_destinataires.clear()
	_destinataires.add_item("Tous", 0)
	var id_moi := multiplayer.get_unique_id()
	for id_pair in multiplayer.get_peers():
		if id_pair == id_moi:
			continue
		var nom := str(NetworkManager.noms_pairs.get(id_pair, "ELEVE %d" % (id_pair - 1)))
		_destinataires.add_item(nom, id_pair)


func _sur_message(_id_expediteur: int, nom: String, texte: String, prive: bool) -> void:
	var prefixe := "[prive] " if prive else ""
	_ajouter_ligne("%s%s : %s" % [prefixe, nom, texte])


func _envoyer() -> void:
	var texte := _saisie.text.strip_edges()
	_saisie.clear()
	if texte == "":
		_fermer()
		return
	var indice := _destinataires.selected
	if indice < 0:
		indice = 0
	var destinataire: int = _destinataires.get_item_id(indice)
	NetworkManager.envoyer_message(texte, destinataire)
	var nom := NetworkSession.nom_joueur
	if nom == "":
		nom = "PROF" if NetworkSession.est_hote() else "ELEVE"
	var cible := "" if destinataire == 0 else " [a %s]" % _destinataires.get_item_text(indice)
	_ajouter_ligne("%s%s : %s%s" % [
		"" if destinataire == 0 else "[prive] ", nom, texte, cible])
	_fermer()


func _ajouter_ligne(texte: String) -> void:
	var label := Label.new()
	label.text = texte
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.05))
	label.add_theme_constant_override("outline_size", 6)
	_journal.add_child(label)
	_lignes.append({"label": label, "chrono": DUREE_AFFICHAGE})
	while _lignes.size() > NB_LIGNES:
		var ancienne: Dictionary = _lignes.pop_front()
		(ancienne["label"] as Label).queue_free()


func _construire_journal() -> void:
	_journal = VBoxContainer.new()
	_journal.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_journal.position = Vector2(14, -14)
	_journal.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_journal.size = Vector2(560, 220)
	_journal.add_theme_constant_override("separation", 2)
	add_child(_journal)


func _construire_barre() -> void:
	_barre = HBoxContainer.new()
	_barre.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_barre.position = Vector2(-330, -70)
	_barre.size = Vector2(660, 40)
	_barre.add_theme_constant_override("separation", 8)
	_barre.visible = false
	add_child(_barre)

	_destinataires = OptionButton.new()
	_destinataires.add_theme_font_size_override("font_size", 14)
	_destinataires.custom_minimum_size = Vector2(140, 36)
	_barre.add_child(_destinataires)

	_saisie = LineEdit.new()
	_saisie.placeholder_text = "Message... (Entree : envoyer, Echap : fermer)"
	_saisie.custom_minimum_size = Vector2(460, 36)
	_saisie.max_length = 120
	_barre.add_child(_saisie)
	_saisie.text_submitted.connect(func(_t: String) -> void: _envoyer())
