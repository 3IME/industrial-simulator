extends SceneTree
## Usine headless : construite depuis un fichier de definition JSON, avec le
## serveur Modbus TCP actif. C'est le point d'entree pour brancher un vrai PLC
## (OpenPLC en Phase 3) ou n'importe quel client Modbus.
##
## Utilisation :
##   godot --headless --path simulator --script res://run_headless.gd -- [options]
## Options :
##   --config=chemin   fichier de definition (defaut : res://config/factory.json)
##   --port=N          port d'ecoute Modbus (defaut : celui de la definition, sinon 502)
##   --no-spawn        ne pas poser de boite au demarrage
##   --box=N           pose une nouvelle boite toutes les N secondes (0 = une seule)
##
## Ctrl+C pour arreter.

const FactoryBuilder = preload("res://simulation/factory_builder.gd")

var factory: Dictionary = {}
var engine = null
var io = null
var timestep := 1.0 / 60.0
var accumulator := 0.0
var elapsed := 0.0
var report_timer := 0.0
var spawn_box := true
var respawn_interval := 0.0
var respawn_timer := 0.0


func _initialize() -> void:
    var config_path := "res://config/factory.json"
    var requested_port := -1
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--config="):
            config_path = arg.substr(9)
        elif arg.begins_with("--port="):
            requested_port = int(arg.substr(7))
        elif arg == "--no-spawn":
            spawn_box = false
        elif arg.begins_with("--box="):
            respawn_interval = float(arg.substr(6))
            if respawn_interval > 0.0:
                spawn_box = true

    print("=== Industrial Simulator - usine headless ===")
    factory = FactoryBuilder.build_from_file(config_path)
    if not factory.get("ok", false):
        printerr("ERREUR de construction : " + str(factory.get("error", "?")))
        quit(1)
        return
    engine = factory["engine"]
    io = factory["io"]
    timestep = float(factory["timestep"])

    print("Usine chargee : " + str(factory["name"]) + " ("
        + str(factory["machines"].size()) + " machine(s), timestep "
        + str(snappedf(timestep, 0.0001)) + " s)")
    for warning in factory.get("warnings", []):
        print("  AVERTISSEMENT : " + str(warning))

    var link = factory.get("modbus")
    if link != null:
        var port: int = requested_port if requested_port > 0 else link.server.port
        var err: int = link.listen(port)
        if err != Error.OK:
            printerr("ERREUR : ecoute Modbus impossible sur le port " + str(port) + " (deja pris ?)")
            quit(1)
            return
        print("Modbus TCP esclave actif : port " + str(port)
            + ", unit id " + str(link.server.unit_id)
            + " (coils=%QX, discrete inputs=%IX, input regs=%IW, holding regs=%QW)")
    else:
        print("Pas de section 'modbus' dans la definition : simulation sans serveur.")

    if spawn_box and not _spawn_box():
        print("Aucune machine ne peut recevoir de boite.")

    print("Cycle en cours. Ctrl+C pour arreter.")
    _report()


func _process(delta: float) -> bool:
    accumulator += delta
    var steps := 0
    while accumulator >= timestep and steps < 10:
        engine.step(timestep)
        accumulator -= timestep
        elapsed += timestep
        steps += 1

    if spawn_box and respawn_interval > 0.0:
        respawn_timer += delta
        if respawn_timer >= respawn_interval:
            respawn_timer = 0.0
            _spawn_box()

    report_timer += delta
    if report_timer >= 2.0:
        report_timer = 0.0
        _report()
    return false


func _spawn_box() -> bool:
    for machine in factory["machines"]:
        if machine.has_method("spawn_box"):
            return machine.spawn_box()
    return false


func _report() -> void:
    var line := "[t=%6.1fs] " % elapsed
    line += "entry=%d exit=%d | run=%d stop=%d | running=%d speed=%.2f m/s pos=%.2f m | enc=%d" % [
        int(bool(io.get_value("sensor_entry", false))),
        int(bool(io.get_value("sensor_exit", false))),
        int(bool(io.get_value("conveyor_01.run", false))),
        int(bool(io.get_value("conveyor_01.stop", false))),
        int(bool(io.get_value("conveyor_01.running", false))),
        float(io.get_value("conveyor_01.speed", 0.0)),
        float(io.get_value("conveyor_01.position", -1.0)),
        int(io.get_value("conveyor_01.belt_encoder", 0)),
    ]
    print(line)
