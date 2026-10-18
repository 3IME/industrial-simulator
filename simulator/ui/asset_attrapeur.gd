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
	avertir_position()


func _notification(quoi: int) -> void:
	if quoi == NOTIFICATION_VISIBILITY_CHANGED and visible:
		avertir_position()


func avertir_position() -> void:
	if visible and not _donnee.is_empty():
		(navire as Node).montrer_references(
			_donnee, get_global_mouse_position())


func _gui_input(event: InputEvent) -> void:
	if not visible or _donnee.is_empty():
		return
	if event is InputEventMouseMotion:
		(navire as Node).montrer_references(_donnee, event.position)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			(navire as Node).deposer(event.position)
		else:
			(navire as Node).annuler()
		terminer()
	elif event is InputEventKey and event.pressed \
			and event.keycode == KEY_ESCAPE:
		(navire as Node).annuler()
		terminer()


func terminer() -> void:
	_donnee = {}
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
