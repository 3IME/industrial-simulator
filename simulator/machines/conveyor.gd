class_name Conveyor
extends RefCounted
## Machine virtuelle : convoyeur logique (aucun rendu 3D).
##
## Commandes (sorties PLC, lues dans apply_outputs) :
##   <id>.run             marche (DIGITAL_OUTPUT, %QX0.0)
##   <id>.stop            arret prioritaire (DIGITAL_OUTPUT, %QX0.1)
##   <id>.speed_command   consigne de vitesse 0-100 % (ANALOG_OUTPUT, %QW0)
##   <id>.reset_counters  RAZ compteurs + encodeur, sur front montant (DIGITAL_OUTPUT, %QX1.0)
##
## Etats publies (entrees PLC, ecrits dans scan_inputs) :
##   sensor_entry / sensor_exit     capteurs photo-electriques (%IX0.0 / %IX0.1)
##   <id>.running                   en marche (%IX1.0)
##   <id>.speed                     vitesse reelle en m/s (%IW0)
##   <id>.position                  front de la boite en m, -1 si absente (%IW1)
##   <id>.counter_entry             passages au capteur d'entree (COUNTER, %IW2)
##   <id>.counter_exit              passages au capteur de sortie (COUNTER, %IW3)
##   <id>.belt_encoder              encodeur de bande en impulsions (ENCODER, %IW4)
##
## Semantique de commande : niveaux (pas de maintien). run = true et stop = false
## -> convoyeur en marche ; stop est prioritaire. Le maintien/memoire est de la
## logique d'automatisme : il vit dans le PLC, pas ici.
##
## La boite est modelee par son front (box_position) ; elle occupe
## [box_position - box_length, box_position]. Un capteur a l'abscisse s
## est detecte tant que le front a depasse s et que l'arriere non.

const IoPointScript = preload("res://io/io_point.gd")
const EdgeCounterScript = preload("res://io/edge_counter.gd")

## Parametres numeriques configurables via FactoryBuilder (tous > 0).
const NUMERIC_PARAMS = [
    "length", "box_length", "entry_position", "exit_position",
    "max_speed", "pulses_per_meter",
]

var id := "conveyor_01"

# Parametres geometriques (metres) et mecaniques
var length := 2.0
var box_length := 0.2
var entry_position := 0.3
var exit_position := 1.7
var max_speed := 0.5         # m/s a 100 %
var pulses_per_meter := 1000.0

# Commandes (ecrites par apply_outputs)
var cmd_run := false
var cmd_stop := false
var cmd_speed_pct := 100.0
var cmd_reset_counters := false

# Etat
var running := false
var speed := 0.0
var box_present := false
var box_position := 0.0
var entry_sensor := false
var exit_sensor := false
var boxes_exited := 0
var belt_travel := 0.0       # distance parcourue par la bande (m), base encodeur

var _entry_counter = EdgeCounterScript.new()
var _exit_counter = EdgeCounterScript.new()
var _reset_edge = EdgeCounterScript.new()


## Applique des parametres de definition d'usine (validation stricte).
## 'id' est gere par le FactoryBuilder et refuse ici pour eviter les incoherences.
func configure(params: Dictionary) -> Error:
    if params.has("id"):
        return ERR_INVALID_PARAMETER
    for key in NUMERIC_PARAMS:
        if params.has(key):
            var value = params[key]
            if not (value is int or value is float) or float(value) <= 0.0:
                return ERR_INVALID_PARAMETER
            set(key, float(value))
    return OK


## Les points d'E/S de la machine, prets a etre ajoutes a une IoTable.
## Les adresses sont les valeurs par defaut du prototype ; le FactoryBuilder
## les ecrase par celles du mapping JSON quand il existe.
func create_io_points() -> Array:
    return [
        IoPointScript.new(
            "sensor_entry", IoPointScript.Type.DIGITAL_INPUT, "%IX0.0",
            "", false, "", "Capteur photo-electrique d'entree du convoyeur"
        ),
        IoPointScript.new(
            "sensor_exit", IoPointScript.Type.DIGITAL_INPUT, "%IX0.1",
            "", false, "", "Capteur photo-electrique de sortie du convoyeur"
        ),
        IoPointScript.new(
            id + ".running", IoPointScript.Type.DIGITAL_INPUT, "%IX1.0",
            "", false, "", "Le convoyeur est en marche"
        ),
        IoPointScript.new(
            id + ".speed", IoPointScript.Type.ANALOG_INPUT, "%IW0",
            "", 0.0, "m/s", "Vitesse reelle du convoyeur"
        ),
        IoPointScript.new(
            id + ".position", IoPointScript.Type.ANALOG_INPUT, "%IW1",
            "", -1.0, "m", "Position du front de la boite, -1 si absente"
        ),
        IoPointScript.new(
            id + ".counter_entry", IoPointScript.Type.COUNTER, "%IW2",
            "", 0, "", "Passages comptes au capteur d'entree"
        ),
        IoPointScript.new(
            id + ".counter_exit", IoPointScript.Type.COUNTER, "%IW3",
            "", 0, "", "Passages comptes au capteur de sortie"
        ),
        IoPointScript.new(
            id + ".belt_encoder", IoPointScript.Type.ENCODER, "%IW4",
            "", 0, "impulsions", "Encodeur de bande (distance parcourue)"
        ),
        IoPointScript.new(
            id + ".run", IoPointScript.Type.DIGITAL_OUTPUT, "%QX0.0",
            "", false, "", "Commande de marche"
        ),
        IoPointScript.new(
            id + ".stop", IoPointScript.Type.DIGITAL_OUTPUT, "%QX0.1",
            "", false, "", "Commande d'arret (prioritaire)"
        ),
        IoPointScript.new(
            id + ".speed_command", IoPointScript.Type.ANALOG_OUTPUT, "%QW0",
            "", 100.0, "%", "Consigne de vitesse 0-100 %"
        ),
        IoPointScript.new(
            id + ".reset_counters", IoPointScript.Type.DIGITAL_OUTPUT, "%QX1.0",
            "", false, "", "RAZ compteurs et encodeur (front montant)"
        ),
    ]


## Contrat machine : lit ses commandes dans la table (sorties PLC).
func apply_outputs(io) -> void:
    cmd_run = bool(io.get_value(id + ".run", false))
    cmd_stop = bool(io.get_value(id + ".stop", false))
    cmd_speed_pct = float(io.get_value(id + ".speed_command", 100.0))
    cmd_reset_counters = bool(io.get_value(id + ".reset_counters", false))
    if _reset_edge.observe(cmd_reset_counters):
        _entry_counter.reset()
        _exit_counter.reset()
        belt_travel = 0.0


## Contrat machine : physique/logique du convoyeur, un pas dt.
func update(_dt: float) -> void:
    running = cmd_run and not cmd_stop
    speed = (max_speed * cmd_speed_pct / 100.0) if running else 0.0
    belt_travel += speed * _dt
    if box_present and speed > 0.0:
        box_position += speed * _dt
        # La boite est totalement sortie quand son arriere depasse la fin.
        if box_position - box_length >= length:
            box_present = false
            box_position = 0.0
            boxes_exited += 1


## Contrat machine : recalcule l'etat brut des capteurs (lu au cycle suivant).
func refresh_sensors(_dt: float) -> void:
    entry_sensor = _box_covers(entry_position)
    exit_sensor = _box_covers(exit_position)
    _entry_counter.observe(entry_sensor)
    _exit_counter.observe(exit_sensor)


## Contrat machine : publie capteurs et etats dans la table (entrees PLC).
func scan_inputs(io) -> void:
    io.set_value("sensor_entry", entry_sensor)
    io.set_value("sensor_exit", exit_sensor)
    io.set_value(id + ".running", running)
    io.set_value(id + ".speed", speed)
    io.set_value(id + ".position", box_position if box_present else -1.0)
    io.set_value(id + ".counter_entry", _entry_counter.count)
    io.set_value(id + ".counter_exit", _exit_counter.count)
    io.set_value(id + ".belt_encoder", int(round(belt_travel * pulses_per_meter)))


## Pose une boite sur le convoyeur. Par defaut le front de la boite est pose
## sur le capteur d'entree (scénario du prototype : la boite arrive sur le
## capteur, le PLC detecte et demarre le convoyeur). front_position < 0 =>
## entry_position. Retourne false s'il y a deja une boite.
func spawn_box(front_position: float = -1.0) -> bool:
    if box_present:
        return false
    box_present = true
    box_position = entry_position if front_position < 0.0 else front_position
    return true


func reset() -> void:
    running = false
    speed = 0.0
    box_present = false
    box_position = 0.0
    entry_sensor = false
    exit_sensor = false
    boxes_exited = 0
    belt_travel = 0.0
    cmd_run = false
    cmd_stop = false
    cmd_speed_pct = 100.0
    cmd_reset_counters = false
    _entry_counter = EdgeCounterScript.new()
    _exit_counter = EdgeCounterScript.new()
    _reset_edge = EdgeCounterScript.new()


## Valeur courante de l'encodeur en impulsions (facilite les tests/affichages).
func encoder_pulses() -> int:
    return int(round(belt_travel * pulses_per_meter))


## Un capteur a l'abscisse s est detecte si la boite couvre s.
func _box_covers(s: float) -> bool:
    if not box_present:
        return false
    var front: float = box_position
    var back: float = box_position - box_length
    return front >= s and back <= s
