extends RefCounted
## Tests du modele IoPoint.

const IoPoint = preload("res://io/io_point.gd")


func run(t) -> void:
    t.begin_suite("io_point")

    # Construction et valeurs par defaut
    var p = IoPoint.new("sensor_01", IoPoint.Type.DIGITAL_INPUT, "%IX0.0")
    t.check_eq(p.id, "sensor_01", "id")
    t.check_eq(p.address, "%IX0.0", "adresse")
    t.check_eq(p.io_name, "sensor_01", "nom par defaut = id")
    t.check_eq(p.value, false, "valeur digitale par defaut")
    t.check(p.is_input(), "DIGITAL_INPUT est une entree")
    t.check(not p.is_output(), "DIGITAL_INPUT n'est pas une sortie")
    t.check(p.is_digital(), "DIGITAL_INPUT est digital")
    t.check_eq(p.quality, IoPoint.Quality.GOOD, "qualite GOOD par defaut")

    p = IoPoint.new("moteur", IoPoint.Type.DIGITAL_INPUT, "%IX0.0", "Capteur moteur")
    t.check_eq(p.io_name, "Capteur moteur", "nom explicite conserve")

    # Ecriture et horloge injectee
    p.set_value(true, 42)
    t.check_eq(p.value, true, "set_value bool")
    t.check_eq(p.timestamp_usec, 42, "horodatage injecte")

    p.set_value(1, 43)
    t.check(p.value is bool and p.value == true, "coercion int -> bool pour un point digital")

    # Points analogiques
    var analog = IoPoint.new("motor_speed", IoPoint.Type.ANALOG_OUTPUT, "%QW0", "", 75.0, "%")
    t.check_eq(analog.value, 75.0, "valeur analogique initiale")
    t.check(analog.is_output(), "ANALOG_OUTPUT est une sortie")
    t.check(not analog.is_input(), "ANALOG_OUTPUT n'est pas une entree")
    analog.set_value("12.5", 100)
    t.check(analog.value is float, "coercion vers float pour un point analogique")
    t.check_almost_eq(float(analog.value), 12.5, 0.0001, "valeur analogique depuis chaine")

    # Compteurs : coercion vers int
    var counter = IoPoint.new("counter_01", IoPoint.Type.COUNTER, "%IW5")
    counter.set_value(2.7, 1)
    t.check(counter.value is int and counter.value == 2, "coercion float -> int pour un compteur")

    # Encodeur : bien une entree PLC
    var encoder = IoPoint.new("enc_01", IoPoint.Type.ENCODER)
    t.check(encoder.is_input(), "ENCODER est une entree")

    # Qualite
    p.set_bad(77)
    t.check_eq(p.quality, IoPoint.Quality.BAD, "set_bad")
    t.check_eq(p.timestamp_usec, 77, "set_bad horodate")
    t.check_eq(p.value, true, "set_bad ne change pas la valeur")

    # Serialisation des types
    var types := [
        IoPoint.Type.DIGITAL_INPUT,
        IoPoint.Type.DIGITAL_OUTPUT,
        IoPoint.Type.ANALOG_INPUT,
        IoPoint.Type.ANALOG_OUTPUT,
        IoPoint.Type.COUNTER,
        IoPoint.Type.ENCODER,
    ]
    for i in range(types.size()):
        var round_trip: int = IoPoint.type_from_string(IoPoint.type_to_string(types[i]))
        t.check_eq(round_trip, types[i], "aller-retour type " + IoPoint.type_to_string(types[i]))
    t.check_eq(IoPoint.type_from_string("NIMPORTE_QUOI"), -1, "type inconnu -> -1")

    # Snapshot serialisable
    var d := p.to_dict()
    t.check(
        d.has_all([
            "id", "name", "type", "value", "unit", "address", "description",
            "quality", "timestamp_usec"
        ]),
        "to_dict contient tous les champs"
    )
    t.check_eq(d["type"], "DIGITAL_INPUT", "to_dict type")
    t.check_eq(d["id"], "moteur", "to_dict id")
