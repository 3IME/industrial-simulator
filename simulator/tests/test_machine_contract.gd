extends RefCounted
## Tests de contrat machine : tout type enregistre dans le registre du
## FactoryBuilder doit respecter le contrat documente dans ARCHITECTURE.md.
## Ajouter une machine au registre l'ajoute automatiquement a ces tests.

const FactoryBuilder = preload("res://simulation/factory_builder.gd")
const IoTable = preload("res://io/io_table.gd")
const IoPoint = preload("res://io/io_point.gd")
const SimulationEngine = preload("res://simulation/simulation_engine.gd")
const NullPlcLink = preload("res://communication/null_plc_link.gd")

const REQUIRED_METHODS = [
    "apply_outputs", "update", "refresh_sensors", "scan_inputs", "create_io_points",
]


func run(t) -> void:
    t.begin_suite("contrat_machine")
    for machine_type in FactoryBuilder.MACHINE_TYPES.keys():
        var machine = FactoryBuilder.MACHINE_TYPES[machine_type].new()

        # Methodes du contrat
        for method in REQUIRED_METHODS:
            t.check(machine.has_method(method), machine_type + " expose " + method + "()")

        # Points d'E/S valides : ajoutables (ids et adresses uniques), sens defini
        var points = machine.create_io_points()
        t.check(points.size() > 0, machine_type + " definit au moins un point d'E/S")
        var io = IoTable.new()
        for point in points:
            t.check_eq(io.add_point(point), Error.OK, machine_type + " : point ajoutable : " + point.id)
            t.check(point.is_input() != point.is_output(), machine_type + " : sens coherent : " + point.id)
        t.check_eq(io.point_count(), points.size(), machine_type + " : ids et adresses uniques")

        # Un cycle complet sans commande ne casse rien et publie toutes les entrees
        var engine = SimulationEngine.new(io, NullPlcLink.new())
        engine.add_machine(machine)
        engine.step(1.0 / 60.0)
        for point in io.inputs():
            t.check_eq(
                point.quality, IoPoint.Quality.GOOD,
                machine_type + " : entree publiee en bonne qualite : " + point.id
            )
            t.check(point.timestamp_usec > 0, machine_type + " : entree horodatee : " + point.id)
