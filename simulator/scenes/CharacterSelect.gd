extends Control
## Ecran de choix du role (Eleve / Professeur) pour le futur mode reseau.
## Spec 3IME : cartes animees, design industriel cyan/orange, scanlines.

# --- REFERENCES AUX NODES ---
@onready var student_card: PanelContainer = $MainContainer/CharacterGrid/StudentCard
@onready var teacher_card: PanelContainer = $MainContainer/CharacterGrid/TeacherCard
@onready var student_image: TextureRect = $MainContainer/CharacterGrid/StudentCard/VBoxContainer/StudentImage
@onready var teacher_image: TextureRect = $MainContainer/CharacterGrid/TeacherCard/VBoxContainer/TeacherImage
@onready var confirm_button: Button = $MainContainer/ConfirmButton

# --- VARIABLES ---
var selected_role: String = ""
var _float_tween: Tween = null   # flottement idle : une seule instance

# --- INITIALISATION ---
func _ready() -> void:
	# Connexion des signaux de souris (survol)
	student_card.mouse_entered.connect(_on_card_hover.bind(student_card, true))
	student_card.mouse_exited.connect(_on_card_hover.bind(student_card, false))
	teacher_card.mouse_entered.connect(_on_card_hover.bind(teacher_card, true))
	teacher_card.mouse_exited.connect(_on_card_hover.bind(teacher_card, false))

	# Connexion des clics
	student_card.gui_input.connect(_on_card_click.bind("eleve", student_card))
	teacher_card.gui_input.connect(_on_card_click.bind("professeur", teacher_card))

	# Connexion du bouton de validation
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.disabled = true

	# Pivot centre : les grossissements (hover/pop) partent du centre de
	# la carte et non du coin haut-gauche. Attendre une frame pour que
	# les tailles des conteneurs soient connues.
	await get_tree().process_frame
	student_card.pivot_offset = student_card.size / 2.0
	teacher_card.pivot_offset = teacher_card.size / 2.0
	confirm_button.pivot_offset = confirm_button.size / 2.0

	# Animation d'entree
	_animate_entry()

# --- ANIMATION D'ENTREE (les cartes arrivent du bas) ---
func _animate_entry() -> void:
	student_card.modulate.a = 0
	teacher_card.modulate.a = 0
	student_card.position.y += 60
	teacher_card.position.y += 60

	var tween = create_tween().set_parallel(true)
	tween.tween_property(student_card, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(teacher_card, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(student_card, "position:y", student_card.position.y - 60, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(teacher_card, "position:y", teacher_card.position.y - 60, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- ANIMATION DE SURVOL (hover) ---
func _on_card_hover(card: PanelContainer, is_hovering: bool) -> void:
	var image: TextureRect
	if card == student_card:
		image = student_image
	else:
		image = teacher_image

	var tween = create_tween().set_parallel(true)

	if is_hovering:
		# La carte grossit
		tween.tween_property(card, "scale", Vector2(1.08, 1.08), 0.2) \
			.set_trans(Tween.TRANS_SINE)
		# Effet lumineux
		tween.tween_property(card, "modulate", Color(1.2, 1.2, 1.2), 0.2)
		# L'image flotte de haut en bas (effet "idle") — instance unique
		if _float_tween != null:
			_float_tween.kill()
		_float_tween = create_tween().set_loops()
		_float_tween.tween_property(image, "position:y", image.position.y - 10, 0.6) \
			.set_trans(Tween.TRANS_SINE)
		_float_tween.tween_property(image, "position:y", image.position.y, 0.6) \
			.set_trans(Tween.TRANS_SINE)
	else:
		# Arreter le flottement avant de revenir a la normale
		if _float_tween != null:
			_float_tween.kill()
			_float_tween = null
			image.position.y = 0.0
		tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.2)
		tween.tween_property(card, "modulate", Color(1.0, 1.0, 1.0), 0.2)

# --- SELECTION D'UNE CARTE ---
func _on_card_click(event: InputEvent, role: String, card: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_role = role
		print("Role selectionne : ", selected_role)

		# Petit "pop" de la carte selectionnee
		var tween = create_tween()
		tween.tween_property(card, "scale", Vector2(0.95, 0.95), 0.1)
		tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.1)

		# Mise en evidence visuelle
		student_card.modulate = Color(1, 1, 1) if role == "eleve" else Color(0.5, 0.5, 0.5)
		teacher_card.modulate = Color(1, 1, 1) if role == "professeur" else Color(0.5, 0.5, 0.5)

		# Activation du bouton
		confirm_button.disabled = false

		# Animation "pulse" du bouton de validation
		var btn_tween = create_tween()
		btn_tween.tween_property(confirm_button, "scale", Vector2(1.1, 1.1), 0.15)
		btn_tween.tween_property(confirm_button, "scale", Vector2(1.0, 1.0), 0.15)

# --- VALIDATION ---
func _on_confirm_pressed() -> void:
	if selected_role == "":
		return

	print("Lancement du jeu en tant que : ", selected_role)

	# Animation de sortie (fondu au noir)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)

	# Puis changement de scene
	tween.tween_callback(func() -> void:
		# Stocke le role dans un singleton (ex: GameManager.player_role)
		# get_tree().change_scene_to_file("res://scenes/Game.tscn")
		print("Changement de scene vers le jeu...")
	)
