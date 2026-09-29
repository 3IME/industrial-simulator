class_name RobotKuka
extends RefCounted
## Bras robot industriel 6 axes (type KUKA) - logique articulaire.
##
## Les six angles articulaires (A1..A6, degres) sont l'etat de la machine.
## Parametre "demo" (defaut vrai) : trajectoire de demonstration - chaque
## axe suit une sinusoide lente, phasee, comme un bras en mouvement
## d'attente/parade. A faux, le bras garde sa pose (les consignes PLC et
## la cinematique complete arrivent en Phase 11 - Robots).
##
## Points d'E/S publies (entrees PLC, %IW) : les 6 angles en dixiemes de deg.

const IoPointScript = preload("res://io/io_point.gd")

const JOINT_NAMES := ["a1", "a2", "a3", "a4", "a5", "a6"]

## Trajectoire demo : amplitude (deg), pulsation (rad/s) et phase par axe.
const DEMO_AMPLITUDE := [70.0, 16.0, 26.0, 45.0, 22.0, 90.0]
const DEMO_PULSATION := [0.35, 0.55, 0.45, 0.9, 0.75, 1.2]
const DEMO_PHASE := [0.0, 1.1, 2.2, 0.6, 2.9, 1.7]

var id := "kuka_01"
var demo := true
var demo_time := 0.0
var angles_deg: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]


func configure(params: Dictionary) -> Error:
    if params.has("id"):
        return ERR_INVALID_PARAMETER
    if params.has("demo"):
        demo = bool(params["demo"])
    return OK


func create_io_points() -> Array:
    var points: Array = []
    var addresses := ["%IW5", "%IW6", "%IW7", "%IW8", "%IW9", "%IW10"]
    for i in range(JOINT_NAMES.size()):
        points.append(IoPointScript.new(
            id + "." + JOINT_NAMES[i] + "_deg", IoPointScript.Type.ANALOG_INPUT,
            addresses[i], "", 0.0, "deg",
            "Angle articulaire A" + str(i + 1) + " du bras " + id
        ))
    return points


func apply_outputs(_io) -> void:
    pass    # consignes PLC : Phase 11


func update(dt: float) -> void:
    if demo:
        demo_time += dt
        for i in range(angles_deg.size()):
            angles_deg[i] = DEMO_AMPLITUDE[i] * sin(
                DEMO_PULSATION[i] * demo_time + DEMO_PHASE[i]
            )


func refresh_sensors(_dt: float) -> void:
    pass    # pas de capteurs physiques sur le bras pour l'instant


func scan_inputs(io) -> void:
    for i in range(JOINT_NAMES.size()):
        io.set_value(id + "." + JOINT_NAMES[i] + "_deg", angles_deg[i])


func reset() -> void:
    demo_time = 0.0
    for i in range(angles_deg.size()):
        angles_deg[i] = 0.0
