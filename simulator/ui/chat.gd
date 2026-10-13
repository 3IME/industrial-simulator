extends CanvasLayer
## Chat de session (chantier 8 de la feuille de route reseau).
## Touche T : ouvrir/fermer la barre de saisie ; Entree : envoyer ;
## Echap : fermer. Liste deroulante : diffusion a tous ou destinataire
## unique (le serveur route). Journal en bas a gauche, 8 derniers
## messages, fondu des lignes anciennes.

const NB_LIGNES := 8
const DUREE_AFFICHAGE := 12.0

# acces runtime (les identifiants d'autoload ne resolvent pas a la
# compilation dans tous les contextes — tests --script notamment)
var _manager: Node = null

var _racine: Control = null
var _journal: VBoxContainer = null
var _zone_popups: VBoxContainer = null
var _son_pop: AudioStreamPlayer = null
var _barre: HBoxContainer = null
var _saisie: LineEdit = null
var _destinataires: OptionButton = null
var _lignes: Array = []          # [{label, chrono}]


func _ready() -> void:
	layer = 5
	_construire_journal()
	_construire_barre()
	_manager = get_node_or_null("/root/NetworkManager")
	if _manager != null:
		_manager.message_recu.connect(_sur_message)


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
		var nom := str(_manager.noms_pairs.get(id_pair, "ELEVE %d" % (id_pair - 1)))
		_destinataires.add_item(nom, id_pair)


func _sur_message(_id_expediteur: int, nom: String, texte: String, prive: bool) -> void:
	var prefixe := "[prive] " if prive else ""
	_ajouter_ligne("%s%s : %s" % [prefixe, nom, texte])
	_ajouter_popup(prefixe, nom, texte)
	if _son_pop.stream != null:
		_son_pop.play()


## Encadre temporaire centre-haut : nom + debut du message, bordure
## rouge, 3,5 s puis fondu de 0,4 s.
func _ajouter_popup(prefixe: String, nom: String, texte: String) -> void:
	var panneau := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.9)
	style.border_color = Color(1.0, 0.22, 0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panneau.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	var extrait := texte.substr(0, 70)
	if texte.length() > 70:
		extrait += "..."
	label.text = "%s%s : %s" % [prefixe, nom, extrait]
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	panneau.add_child(label)
	_zone_popups.add_child(panneau)
	panneau.modulate.a = 0.0
	var tween := panneau.create_tween()
	tween.tween_property(panneau, "modulate:a", 1.0, 0.15)
	tween.tween_interval(3.5)
	tween.tween_property(panneau, "modulate:a", 0.0, 0.4)
	tween.tween_callback(panneau.queue_free)


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
	if _manager != null:
		_manager.envoyer_message(texte, destinataire)
	var session = get_node_or_null("/root/NetworkSession")
	var nom: String = session.nom_joueur if session != null else ""
	if nom == "":
		nom = "PROF" if (session != null and session.est_hote()) else "ELEVE"
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
	# Racine plein ecran : les ancres 'bas' ne resolvent pas contre un
	# CanvasLayer directement, il faut un parent Control plein cadre
	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_racine)
	_journal = VBoxContainer.new()
	# rectangle explicite via offsets d'ancres : bas-gauche de l'ecran,
	# 560 x 220 px (les lignes s'empilent du haut vers le bas du cadre,
	# la plus recente reste visible au bas)
	_journal.anchor_left = 0.0
	_journal.anchor_top = 1.0
	_journal.anchor_right = 0.0
	_journal.anchor_bottom = 1.0
	_journal.offset_left = 14
	_journal.offset_top = -234
	_journal.offset_right = 574
	_journal.offset_bottom = -14
	_journal.add_theme_constant_override("separation", 2)
	_racine.add_child(_journal)


func _construire_barre() -> void:
	_barre = HBoxContainer.new()
	_barre.anchor_left = 0.5
	_barre.anchor_top = 1.0
	_barre.anchor_right = 0.5
	_barre.anchor_bottom = 1.0
	_barre.offset_left = -330
	_barre.offset_top = -70
	_barre.offset_right = 330
	_barre.offset_bottom = -30
	_barre.add_theme_constant_override("separation", 8)
	_barre.visible = false
	_racine.add_child(_barre)
	# Popup MMO/Steam : centre-haut (tiers superieur, la ou le regard
	# se pose en jeu), empilement vertical, encadre rouge
	_zone_popups = VBoxContainer.new()
	_zone_popups.anchor_left = 0.5
	_zone_popups.anchor_top = 0.0
	_zone_popups.anchor_right = 0.5
	_zone_popups.anchor_bottom = 0.0
	_zone_popups.offset_left = -330
	_zone_popups.offset_top = 84
	_zone_popups.offset_right = 330
	_zone_popups.offset_bottom = 284
	_zone_popups.add_theme_constant_override("separation", 6)
	_racine.add_child(_zone_popups)
	_son_pop = AudioStreamPlayer.new()
	var son = load("res://assets/sounds/pop.mp3")
	if son != null:
		_son_pop.stream = son
		_son_pop.volume_db = -6.0
	add_child(_son_pop)

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
