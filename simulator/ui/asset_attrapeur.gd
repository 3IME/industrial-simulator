extends Control
## Recepteur plein ecran du placement d'asset FIO : actif seulement en
## mode manuel (clic vignette -> la grille suit la souris -> clic au
## sol pour poser ; Echap ou clic droit pour annuler).

var navire: Node = null
var _donnee: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func demarrer_manuel(donnee: Dictionary) -> void:
	_donnee = donnee
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# pas de position initiale : la grille n'apparait qu'au premier
	# mouvement de souris (sinon elle surgissait pres du panneau)


func _gui_input(event: InputEvent) -> void:
	if not visible or _donnee.is_empty():
		return
	if event is InputEventMouseMotion:
		(navire as Node).montrer_references(_donnee, event.position)
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			(navire as Node).deposer(event.position)
		else:
			(navire as Node).annuler()
		terminer()
		accept_event()


func terminer() -> void:
	_donnee = {}
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
