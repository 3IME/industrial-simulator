extends RefCounted
## Tests de la machine virtuelle Conveyor (logique pure, sans moteur).

const Conveyor = preload("res://machines/conveyor.gd")
const IoMapping = preload("res://io/io_mapping.gd")
const IoTable = preload("res://io/io_table.gd")
const EdgeCounter = preload("res://io/edge_counter.gd")


func run(t) -> void:
    t.begin_suite("conveyor")

    # --- EdgeCounter : composant genrique des points COUNTER ---
    var ec = EdgeCounter.new()
    t.check(not ec.observe(false), "pas de front au repos")
    t.check(ec.observe(true), "front montant detecte")
    t.check_eq(ec.count, 1, "compteur incremente")
    t.check(not ec.observe(true), "signal haut maintenu : pas de nouveau front")
    ec.observe(false)
    t.check(ec.observe(true), "second front compte")
    t.check_eq(ec.count, 2, "compteur = 2")
    ec.reset()
    t.check_eq(ec.count, 0, "RAZ du compteur")
    t.check(not ec.observe(true), "apres RAZ, signal tenu haut : toujours pas de front")

    # --- Machine ---
    var c = Conveyor.new()
    t.check(c.spawn_box(), "pose d'une boite")
    t.check(not c.spawn_box(), "pas deux boites simultanees")
    t.check(c.box_present, "boite presente")
    t.check_almost_eq(c.box_position, c.entry_position, 0.000001, "boite posee sur le capteur d'entree")

    # Points d'E/S : 12, ids uniques, coherents avec le fichier de mapping
    var points = c.create_io_points()
    t.check_eq(points.size(), 12, "12 points d'E/S")
    var ids := {}
    for point in points:
        ids[point.id] = true
    t.check_eq(ids.size(), 12, "ids uniques")

    var mapping = IoMapping.from_file("res://config/conveyor_io_map.json")
    t.check_not_null(mapping, "mapping du prototype charge")
    for point in points:
        t.check(mapping.has_variable(point.id), "variable mappee : " + point.id)
        t.check_eq(
            mapping.address_for_variable(point.id),
            point.address,
            "adresse coherente : " + point.id
        )

    # Marche manuelle : 1 s a pleine vitesse -> la boite avance de 0.5 m
    c.cmd_run = true
    c.update(0.0)
    t.check(c.running, "running quand cmd_run")
    t.check_almost_eq(c.speed, 0.5, 0.0001, "vitesse nominale a 100 %")
    for i in range(60):
        c.update(1.0 / 60.0)
    t.check_almost_eq(c.box_position, 0.3 + 0.5, 0.01, "boite avancee de 0.5 m en 1 s")

    # Arret prioritaire
    c.cmd_stop = true
    c.update(0.0)
    t.check(not c.running, "stop prioritaire sur run")
    t.check_almost_eq(c.speed, 0.0, 0.0001, "vitesse nulle a l'arret")
    var frozen: float = c.box_position
    c.update(1.0)
    t.check_almost_eq(c.box_position, frozen, 0.000001, "boite immobile a l'arret")

    # Consigne de vitesse a 50 %
    var c2 = Conveyor.new()
    c2.spawn_box()
    c2.cmd_run = true
    c2.cmd_speed_pct = 50.0
    c2.update(0.0)
    t.check_almost_eq(c2.speed, 0.25, 0.0001, "vitesse proportionnelle a la consigne")

    # Application reelle des commandes depuis la table (contrat apply_outputs)
    var io = IoTable.new()
    for point in c2.create_io_points():
        io.add_point(point)
    io.set_value("conveyor_01.run", false)
    io.set_value("conveyor_01.stop", false)
    io.set_value("conveyor_01.speed_command", 25.0)
    c2.apply_outputs(io)
    t.check(not c2.cmd_run, "apply_outputs lit run depuis la table")
    t.check_almost_eq(c2.cmd_speed_pct, 25.0, 0.0001, "apply_outputs lit la consigne")

    # Publication des etats vers la table (contrat scan_inputs)
    io.set_value("conveyor_01.run", true)
    c2.apply_outputs(io)
    c2.update(0.0)
    c2.refresh_sensors(0.0)
    c2.scan_inputs(io)
    t.check_eq(io.get_value("conveyor_01.running"), true, "running publie")
    t.check_almost_eq(float(io.get_value("conveyor_01.speed")), 0.125, 0.0001, "vitesse publiee")
    t.check_eq(io.get_value("sensor_entry"), true, "capteur d'entree publie (boite posee dessus)")

    # Fenetres des capteurs : la boite quitte l'entree, couvre la sortie, puis sort
    var c3 = Conveyor.new()
    c3.spawn_box()
    c3.cmd_run = true
    c3.update(0.0)
    c3.refresh_sensors(0.0)
    t.check(c3.entry_sensor, "entry couvert au depart")
    t.check(not c3.exit_sensor, "exit non couvert au depart")

    var guard := 0
    while c3.box_position < 0.55 and guard < 1000:
        c3.update(1.0 / 60.0)
        c3.refresh_sensors(1.0 / 60.0)
        guard += 1
    t.check(not c3.entry_sensor, "entry libere apres passage (front > 0.5)")

    guard = 0
    while c3.box_present and c3.box_position < 1.8 and guard < 2000:
        c3.update(1.0 / 60.0)
        c3.refresh_sensors(1.0 / 60.0)
        guard += 1
    t.check(c3.exit_sensor, "exit couvert vers 1.8")
    t.check(c3.box_present, "boite encore presente a 1.8")

    guard = 0
    while c3.box_present and guard < 10000:
        c3.update(1.0 / 60.0)
        c3.refresh_sensors(1.0 / 60.0)
        guard += 1
    t.check(not c3.box_present, "boite totalement sortie")
    t.check_eq(c3.boxes_exited, 1, "compteur de boites sorties")
    t.check(not c3.exit_sensor, "capteur exit libere apres sortie")
    c3.scan_inputs(io)
    t.check_eq(io.get_value("conveyor_01.position"), -1.0, "position -1 quand pas de boite")

    # Reset
    c3.reset()
    t.check(not c3.box_present, "reset : plus de boite")
    t.check_eq(c3.boxes_exited, 0, "reset : compteur a zero")
    t.check(not c3.running, "reset : a l'arret")
