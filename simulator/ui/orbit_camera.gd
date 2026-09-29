extends Camera3D
## Camera orbitale : clic gauche + deplacement pour tourner, molette pour
## zoomer. La cible est le milieu du convoyeur.

var target := Vector3(1.0, 0.6, 0.0)
var distance := 5.5
var yaw := 0.7
var pitch := 0.40
var dragging := false

# L'orbite reste a l'interieur du hall (12 x 9 m, hauteur 4 m)
const MIN_DISTANCE := 2.5
const MAX_DISTANCE := 8.5
const MAX_PITCH := 1.2


func _ready() -> void:
    _update_transform()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        match event.button_index:
            MOUSE_BUTTON_LEFT:
                dragging = event.pressed
            MOUSE_BUTTON_WHEEL_UP:
                if event.pressed:
                    distance = clampf(distance - 0.4, MIN_DISTANCE, MAX_DISTANCE)
                    _update_transform()
            MOUSE_BUTTON_WHEEL_DOWN:
                if event.pressed:
                    distance = clampf(distance + 0.4, MIN_DISTANCE, MAX_DISTANCE)
                    _update_transform()
    elif event is InputEventMouseMotion and dragging:
        yaw -= event.relative.x * 0.005
        pitch = clampf(pitch + event.relative.y * 0.005, 0.08, MAX_PITCH)
        _update_transform()


func _update_transform() -> void:
    var offset := Vector3(
        cos(pitch) * sin(yaw),
        sin(pitch),
        cos(pitch) * cos(yaw)
    ) * distance
    global_position = target + offset
    look_at(target, Vector3.UP)
