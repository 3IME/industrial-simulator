extends RefCounted
## Tests du SimulationEngine : cycle complet avec des faux PLC.
##
## Le scenario 1 demontre des la Phase 0 la chaine demandee par le cahier des
## charges : capteur virtuel -> moteur d'E/O -> PLC (fake) -> moteur virtuel.

const IoTable = preload("res://io/io_table.gd")
const Conveyor = preload("res://machines/conveyor.gd")
const SimulationEngine = preload("res://simulation/simulation_engine.gd")
const NullPlcLink = preload("res://communication/null_plc_link.gd")


## Fake implementant exactement la logique OpenPLC prevue en Phase 3 :
## SI sensor_entry ALORS conveyor = TRUE ; SI sensor_exit ALORS conveyor = FALSE.
class FakePlc extends RefCounted:
    var run_latch := false
    var saw_entry := false
    var saw_exit := false
    var ever_saw_entry := false
    var ever_saw_exit := false

    func publish_inputs(io) -> void:
        saw_entry = bool(io.get_value("sensor_entry", false))
        saw_exit = bool(io.get_value("sensor_exit", false))
        ever_saw_entry = ever_saw_entry or saw_entry
        ever_saw_exit = ever_saw_exit or saw_exit

    func pull_outputs(io) -> void:
        if saw_entry:
            run_latch = true
        if saw_exit:
            run_latch = false
        io.set_value("conveyor_01.run", run_latch)


## PLC fictif qui commande la marche en permanence (pour tester la sortie de boite).
class RunAlwaysPlc extends RefCounted:
    func publish_inputs(_io) -> void:
        pass

    func pull_outputs(io) -> void:
        io.set_value("conveyor_01.run", true)


func _build(link) -> Array:
    var conveyor = Conveyor.new()
    var io = IoTable.new()
    for point in conveyor.create_io_points():
        io.add_point(point)
    var engine = SimulationEngine.new(io, link)
    engine.add_machine(conveyor)
    return [engine, conveyor]


func _final_position_after_scenario() -> float:
    var built = _build(FakePlc.new())
    var engine = built[0]
    var conveyor = built[1]
    conveyor.spawn_box()
    engine.advance(10.0, 1.0 / 60.0)
    return conveyor.box_position


func run(t) -> void:
    t.begin_suite("simulation_engine")
    var dt := 1.0 / 60.0

    # --- Scenario 1 : logique du cahier des charges, de bout en bout ---
    # La boite posee sur le capteur d'entree -> le PLC demarre le convoyeur ->
    # la boite atteint le capteur de sortie -> le PLC arrete le convoyeur.
    var fake := FakePlc.new()
    var built = _build(fake)
    var engine = built[0]
    var conveyor = built[1]
    conveyor.spawn_box()
    engine.advance(10.0, dt)

    t.check_eq(engine.step_count, 600, "600 pas en 10 s a 60 Hz")
    t.check(fake.ever_saw_entry, "le PLC a vu le capteur d'entree")
    t.check(fake.ever_saw_exit, "le PLC a vu le capteur de sortie")
    t.check(not fake.saw_entry, "en fin de scenario la boite a quitte le capteur d'entree")
    t.check(not fake.run_latch, "le PLC a coupe la marche")
    t.check(not conveyor.running, "convoyeur arrete")
    t.check_almost_eq(conveyor.speed, 0.0, 0.0001, "vitesse nulle a la fin")
    t.check(conveyor.box_present, "boite toujours sur le convoyeur (arretee au capteur de sortie)")
    t.check(
        conveyor.box_position > 1.68 and conveyor.box_position < 1.73,
        "arret au capteur de sortie (position ~1.7, obtenue : " + str(conveyor.box_position) + ")"
    )
    t.check_eq(conveyor.boxes_exited, 0, "aucune boite sortie dans ce scenario")
    t.check_eq(engine.io.get_value("conveyor_01.running"), false, "etat arrete publie dans la table")

    # --- Scenario 2 : PLC qui maintient la marche -> la boite sort du convoyeur ---
    var built2 = _build(RunAlwaysPlc.new())
    var engine2 = built2[0]
    var conveyor2 = built2[1]
    conveyor2.spawn_box()
    engine2.advance(10.0, dt)

    t.check(not conveyor2.box_present, "boite totalement sortie")
    t.check_eq(conveyor2.boxes_exited, 1, "compteur de sortie = 1")
    t.check_eq(engine2.io.get_value("conveyor_01.position"), -1.0, "position -1 publiee")
    t.check_eq(engine2.io.get_value("conveyor_01.speed"), 0.5, "vitesse 0.5 publiee")

    # --- Scenario 3 : NullPlcLink : le cycle tourne sans automate, rien ne bouge ---
    var built3 = _build(NullPlcLink.new())
    var engine3 = built3[0]
    var conveyor3 = built3[1]
    conveyor3.spawn_box()
    engine3.advance(1.0, dt)

    t.check_eq(engine3.step_count, 60, "60 pas sans PLC")
    t.check_almost_eq(
        conveyor3.box_position, conveyor3.entry_position, 0.000001,
        "boite immobile sans commande PLC"
    )
    t.check(conveyor3.box_present, "boite presente")
    t.check_eq(engine3.io.get_value("sensor_entry"), true, "capteur d'entree publie quand meme")

    # --- Scenario 4 : determinisme (ADR-006) ---
    var run_a: float = _final_position_after_scenario()
    var run_b: float = _final_position_after_scenario()
    t.check_eq(run_a, run_b, "deux executions identiques -> meme position finale")

    # --- Ordre du cycle : les capteurs rafraichis en fin de cycle sont lus au suivant ---
    var built4 = _build(RunAlwaysPlc.new())
    var engine4 = built4[0]
    var conveyor4 = built4[1]
    conveyor4.spawn_box()
    engine4.step(dt)
    t.check_eq(engine4.io.get_value("sensor_entry"), false, "au 1er pas, la table n'a pas encore le capteur")
    engine4.step(dt)
    t.check_eq(engine4.io.get_value("sensor_entry"), true, "au 2e pas, le capteur rafraichi est lu")
    t.check_eq(engine4.io.get_value("conveyor_01.run"), true, "le PLC a deja reagi au 2e pas")
