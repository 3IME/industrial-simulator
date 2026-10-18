extends Control
## Recepteur plein ecran du placement d'asset FIO. Deux modes :
##   - DRAG GUI : la vignette est glissee (get_drag_data) — le
##     navigateur active ce recepteur pendant le drag ; _can_drop_data
##     affiche grille+fantome sous le curseur, _drop_data depose.
##   - MANUEL : clic vignette puis clic au sol (Echap/clic droit
##     annulent).

var navire: Node = null
var _donnee: Dictionary = {}
var _mode_drag := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func demarrer_manuel(donnee: Dictionary) -> void:
	_mode_drag = false
	_donnee = donnee
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# pas de position initiale : la grille n'apparait qu'au premier
	# mouvement de souris (sinon elle surgissait pres du panneau)


## Appele par le navigateur quand un drag GUI est en cours : visible
## pour etre cible de depot, sans toucher au mode souris.
func armer_drag() -> void:
	_mode_drag = true
	visible = true


func _can_drop_data(_point: Vector2, donnee: Variant) -> bool:
	if donnee is Dictionary and donnee.has("fio"):
		_donnee = donnee["fio"]
		(navire as Node).montrer_references(_donnee, _point)
		return true
	return false


func _drop_data(_point: Vector2, donnee: Variant) -> void:
	if donnee is Dictionary and donnee.has("fio"):
		(navire as Node).forcer_entree(donnee["fio"])
		(navire as Node).deposer(_point)
	terminer()


func _gui_input(event: InputEvent) -> void:
	if _mode_drag or _donnee.is_empty():
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
	_mode_drag = false
	visible = false
	(navire as Node).masquer_references()
	if not (navire as Node).drag_gui_actif():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_DRAG_END and _mode_drag:
		# depose ailleurs ou drag annule : tout ranger
		terminer()
