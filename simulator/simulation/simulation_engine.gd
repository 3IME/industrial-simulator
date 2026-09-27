class_name SimulationEngine
extends RefCounted
## Moteur de simulation : cycle deterministe a pas de temps fixe.
##
## Contrats duck-types (voir ARCHITECTURE.md) :
##   machine  : apply_outputs(io), update(dt) [obligatoires],
##              scan_inputs(io), refresh_sensors(dt) [recommandes]
##   plc_link : publish_inputs(io), pull_outputs(io)
##
## Le moteur ne depend d'aucune classe concrete : tout est injecte.
## Aucune horloge OS ici (ADR-006) : le pilotage temps reel se fera
## en Phase 5 par un Node Godot qui appellera step().

var io = null              # IoTable
var plc_link = null        # implemente le contrat PlcLink
var machines: Array = []
var step_count := 0

## Horloge simulee (ADR-010) : avance de dt a chaque pas ; injectee dans la
## table d'E/S pour des horodatages deterministes.
var sim_time_usec := 0

## Watchdog qualite : si > 0, les entrees non rafraichies depuis ce delai
## (microsecondes) sont marquees BAD en debut de cycle. 0 = desactive.
var input_timeout_usec := 0


func _init(p_io = null, p_plc_link = null) -> void:
    io = p_io
    plc_link = p_plc_link


func elapsed_seconds() -> float:
    return sim_time_usec / 1000000.0


## Un cycle complet, dans l'ordre documente dans docs/simulation/simulation_cycle.md.
func step(dt: float) -> void:
    # 0. Reseau (hook optionnel du PlcLink) : requetes du PLC en attente.
    #    Modbus : ecritures du maitre -> banques de sorties (appliquees au temps 4).
    if plc_link != null and plc_link.has_method("poll"):
        plc_link.poll()

    sim_time_usec += int(round(dt * 1000000.0))
    if io != null:
        io.clock_usec = sim_time_usec

    # 1. Lire les entrees de simulation (capteurs -> table d'E/S)
    for machine in machines:
        if machine.has_method("scan_inputs"):
            machine.scan_inputs(io)

    # 1b. Watchdog qualite : entrees non rafraichies -> BAD
    if input_timeout_usec > 0 and io != null:
        io.mark_stale_inputs(sim_time_usec - input_timeout_usec, sim_time_usec)

    # 2. Publier les entrees vers le PLC
    if plc_link != null:
        plc_link.publish_inputs(io)

    # 3. Recevoir les sorties du PLC
    if plc_link != null:
        plc_link.pull_outputs(io)

    # 4. Appliquer les sorties aux actionneurs
    for machine in machines:
        if machine.has_method("apply_outputs"):
            machine.apply_outputs(io)

    # 5. Mettre a jour la simulation
    for machine in machines:
        if machine.has_method("update"):
            machine.update(dt)

    # 6. Mettre a jour les capteurs (lus au temps 1 du cycle suivant)
    for machine in machines:
        if machine.has_method("refresh_sensors"):
            machine.refresh_sensors(dt)

    step_count += 1


## Execute exactement round(secondes / dt) cycles : pour les tests et
## les scenarios reproductibles.
func advance(seconds: float, dt: float) -> void:
    var steps := int(round(seconds / dt))
    for i in range(steps):
        step(dt)


func add_machine(machine) -> void:
    machines.append(machine)
