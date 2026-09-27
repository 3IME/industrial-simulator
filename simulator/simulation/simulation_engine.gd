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


func _init(p_io = null, p_plc_link = null) -> void:
    io = p_io
    plc_link = p_plc_link


## Un cycle complet, dans l'ordre documente dans docs/simulation/simulation_cycle.md.
func step(dt: float) -> void:
    # 1. Lire les entrees de simulation (capteurs -> table d'E/S)
    for machine in machines:
        if machine.has_method("scan_inputs"):
            machine.scan_inputs(io)

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
