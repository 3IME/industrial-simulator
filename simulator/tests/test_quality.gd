extends RefCounted
## Tests qualite/horloge : horloge injectee (ADR-010), watchdog d'entrees.

const IoTable = preload("res://io/io_table.gd")
const IoPoint = preload("res://io/io_point.gd")
const SimulationEngine = preload("res://simulation/simulation_engine.gd")


## Machine minimale qui ne publie jamais sensor_b (pour excer le watchdog).
class PartialMachine extends RefCounted:
    func create_io_points() -> Array:
        var IoPointScript = preload("res://io/io_point.gd")
        return [
            IoPointScript.new("sensor_a", IoPointScript.Type.DIGITAL_INPUT, "%IX0.0"),
            IoPointScript.new("sensor_b", IoPointScript.Type.DIGITAL_INPUT, "%IX0.1"),
        ]

    func scan_inputs(io) -> void:
        io.set_value("sensor_a", true)

    func apply_outputs(_io) -> void:
        pass

    func update(_dt) -> void:
        pass

    func refresh_sensors(_dt) -> void:
        pass


func run(t) -> void:
    t.begin_suite("qualite_horloge")

    # --- Horloge injectee dans la table ---
    var io = IoTable.new()
    io.add_point(IoPoint.new("s1", IoPoint.Type.DIGITAL_INPUT, "%IX0.0"))
    io.clock_usec = 1000
    io.set_value("s1", true)
    t.check_eq(io.get_point("s1").timestamp_usec, 1000, "horodatage pris depuis l'horloge de la table")
    io.set_value("s1", false, 555)
    t.check_eq(io.get_point("s1").timestamp_usec, 555, "horodatage explicite prioritaire sur l'horloge")
    io.clock_usec = -1
    io.set_value("s1", true)
    t.check(io.get_point("s1").timestamp_usec > 1000, "horloge reelle quand aucune horloge n'est injectee")

    # --- Watchdog unitaire : seules les entrees agees passent BAD ---
    var io2 = IoTable.new()
    io2.add_point(IoPoint.new("old_in", IoPoint.Type.DIGITAL_INPUT, "%IX0.0"))
    io2.add_point(IoPoint.new("fresh_in", IoPoint.Type.DIGITAL_INPUT, "%IX0.1"))
    io2.add_point(IoPoint.new("old_out", IoPoint.Type.DIGITAL_OUTPUT, "%QX0.0"))
    io2.set_value("old_in", true, 100)
    io2.set_value("fresh_in", false, 5000)
    io2.set_value("old_out", true, 100)

    t.check_eq(io2.mark_stale_inputs(1000, 6000), 1, "une seule entree marquee")
    t.check_eq(io2.get_point("old_in").quality, IoPoint.Quality.BAD, "entree perimee -> BAD")
    t.check_eq(io2.get_point("fresh_in").quality, IoPoint.Quality.GOOD, "entree fraiche -> GOOD")
    t.check_eq(io2.get_point("old_out").quality, IoPoint.Quality.GOOD, "sortie perimee non concernee")
    t.check_eq(io2.mark_stale_inputs(1000, 7000), 0, "pas de double marquage")

    io2.set_value("old_in", true, 8000)
    t.check_eq(io2.get_point("old_in").quality, IoPoint.Quality.GOOD, "reecriture -> retour au GOOD")

    # --- Integration moteur : capteur jamais publie -> BAD via le watchdog ---
    var machine = PartialMachine.new()
    var io3 = IoTable.new()
    for point in machine.create_io_points():
        io3.add_point(point)
    var engine = SimulationEngine.new(io3, null)
    engine.input_timeout_usec = 500000    # 0.5 s
    engine.add_machine(machine)
    engine.advance(0.6, 1.0 / 60.0)
    t.check_eq(io3.get_point("sensor_a").quality, IoPoint.Quality.GOOD, "capteur publie -> GOOD")
    t.check_eq(io3.get_point("sensor_b").quality, IoPoint.Quality.BAD, "capteur jamais publie -> BAD (watchdog)")
    t.check(engine.elapsed_seconds() > 0.59, "horloge simulee avancee avec le temps")
    t.check_eq(int(engine.sim_time_usec), 36 * 16667, "horloge simulee deterministe (36 pas arrondis a 16667 us)")

    # Le watchdog est desactive par defaut
    var engine2 = SimulationEngine.new(IoTable.new(), null)
    t.check_eq(engine2.input_timeout_usec, 0, "watchdog desactive par defaut")
