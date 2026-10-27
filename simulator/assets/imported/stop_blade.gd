extends Node3D
## Lame de cisaillement (stop blade) : structure fixe + lame mobile qui
## coulisse verticalement. Pilotable : basculer() / ouvrir() / fermer()
## (clic sur la lame, ou appel depuis un script / le PLC plus tard).

const Y_FERME := 0.1287
const Y_OUVERT := 0.2487
const DUREE := 0.5

var ouvert := false
var _tween: Tween = null

@onready var lame: Node3D = $Lame


func _ready() -> void:
	lame.position.y = Y_FERME
	var corps_lame: StaticBody3D = $Lame/Corps
	corps_lame.input_event.connect(_sur_clic_lame)


func ouvrir() -> void:
	_animer(Y_OUVERT, true)


func fermer() -> void:
	_animer(Y_FERME, false)


func basculer() -> void:
	if ouvert:
		fermer()
	else:
		ouvrir()


func _animer(y_cible: float, etat: bool) -> void:
	ouvert = etat
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(lame, "position:y", y_cible, DUREE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _sur_clic_lame(_camera: Node, event: InputEvent, _pos: Vector3,
		_norm: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		basculer()
