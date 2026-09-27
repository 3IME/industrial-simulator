extends RefCounted
## Tests de la IoTable.

const IoTable = preload("res://io/io_table.gd")
const IoPoint = preload("res://io/io_point.gd")


func run(t) -> void:
    t.begin_suite("io_table")

    var table = IoTable.new()
    t.check_eq(table.point_count(), 0, "table vide au depart")

    # Ajout nominal
    var r := table.add_point(IoPoint.new("sensor_entry", IoPoint.Type.DIGITAL_INPUT, "%IX0.0"))
    t.check_eq(r, Error.OK, "ajout nominal")
    t.check_eq(table.point_count(), 1, "un point")

    # Doublons et parametres invalides
    t.check_eq(
        table.add_point(IoPoint.new("sensor_entry", IoPoint.Type.DIGITAL_INPUT, "%IX9.9")),
        Error.ERR_ALREADY_EXISTS,
        "id duplique refuse"
    )
    t.check_eq(
        table.add_point(IoPoint.new("sensor_exit", IoPoint.Type.DIGITAL_INPUT, "%IX0.0")),
        Error.ERR_ALREADY_EXISTS,
        "adresse dupliquee refusee"
    )
    t.check_eq(table.add_point(null), Error.ERR_INVALID_PARAMETER, "point null refuse")
    t.check_eq(
        table.add_point(IoPoint.new("", IoPoint.Type.DIGITAL_INPUT)),
        Error.ERR_INVALID_PARAMETER,
        "id vide refuse"
    )

    # Adresses sans doublon acceptees (adresse optionnelle)
    t.check_eq(
        table.add_point(IoPoint.new("no_address", IoPoint.Type.DIGITAL_INPUT)),
        Error.OK,
        "point sans adresse accepte"
    )

    # Acces par adresse
    t.check_eq(table.get_by_address("%IX0.0").id, "sensor_entry", "acces par adresse")
    t.check_is_null(table.get_by_address("%QX9.9"), "adresse inconnue -> null")

    # Lecture / ecriture de valeurs
    t.check_eq(table.set_value("sensor_entry", true, 10), Error.OK, "set_value nominal")
    t.check_eq(table.get_value("sensor_entry"), true, "get_value")
    t.check_eq(
        table.set_value("ghost", true),
        Error.ERR_DOES_NOT_EXIST,
        "set_value sur point absent -> erreur"
    )
    t.check_eq(table.get_value("ghost", 123), 123, "get_value valeur par defaut")

    # Suppression
    t.check_eq(table.remove_point("sensor_entry"), Error.OK, "remove_point nominal")
    t.check(not table.has_point("sensor_entry"), "point supprime")
    t.check_is_null(table.get_by_address("%IX0.0"), "adresse liberee")
    t.check_eq(table.remove_point("sensor_entry"), Error.ERR_DOES_NOT_EXIST, "double suppression")

    # Sens des points et snapshot
    var table2 = IoTable.new()
    table2.add_point(IoPoint.new("di1", IoPoint.Type.DIGITAL_INPUT, "%IX0.0"))
    table2.add_point(IoPoint.new("di2", IoPoint.Type.DIGITAL_INPUT, "%IX0.1"))
    table2.add_point(IoPoint.new("ai1", IoPoint.Type.ANALOG_INPUT, "%IW0"))
    table2.add_point(IoPoint.new("do1", IoPoint.Type.DIGITAL_OUTPUT, "%QX0.0"))
    table2.add_point(IoPoint.new("do2", IoPoint.Type.DIGITAL_OUTPUT, "%QX0.1"))
    table2.add_point(IoPoint.new("ao1", IoPoint.Type.ANALOG_OUTPUT, "%QW0"))
    t.check_eq(table2.inputs().size(), 3, "3 entrees PLC (2 DI + 1 AI)")
    t.check_eq(table2.outputs().size(), 3, "3 sorties PLC (2 DO + 1 AO)")
    var dicts = table2.to_dicts()
    t.check_eq(dicts.size(), 6, "snapshot de 6 points")
    t.check(dicts[0].has("id"), "snapshot serialisable")
