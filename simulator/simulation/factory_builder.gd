class_name FactoryBuilder
extends RefCounted
## Construit une usine complete (moteur + table d'E/S + machines) depuis une
## definition JSON declarative (ADR-009). Ajouter un type de machine = creer
## sa classe (contrat machine) + une entree dans MACHINE_TYPES : ni le moteur,
## ni cette classe n'ont a changer.
##
## Format de definition (simulator/config/factory.json) :
##   {
##     "version": 1,
##     "name": "...",
##     "simulation": { "timestep": 0.0166..., "input_timeout_usec": 0 },
##     "io_mapping": "res://config/conveyor_io_map.json",
##     "machines": [
##       { "type": "conveyor", "id": "conveyor_01", "params": { ... } }
##     ]
##   }
##
## Retour : { "ok": true, ... } en cas de succes (voir le code),
## ou { "ok": false, "error": "message" } en cas d'echec.

const MACHINE_TYPES = {
    "conveyor": preload("res://machines/conveyor.gd"),
    "robot_kuka": preload("res://machines/robot_kuka.gd"),
}

const IoTableScript = preload("res://io/io_table.gd")
const IoMappingScript = preload("res://io/io_mapping.gd")
const SimulationEngineScript = preload("res://simulation/simulation_engine.gd")
const ModbusPlcLinkScript = preload("res://communication/modbus_plc_link.gd")


static func build_from_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return _error("fichier de definition introuvable : " + path)
    var json := JSON.new()
    if json.parse(FileAccess.get_file_as_string(path)) != OK:
        return _error("JSON invalide dans " + path)
    var parsed = json.get_data()
    if not (parsed is Dictionary):
        return _error("la definition doit etre un objet JSON")
    return build_from_dict(parsed)


static func build_from_dict(def: Dictionary) -> Dictionary:
    var io = IoTableScript.new()

    # --- Machines ---
    var machine_defs = def.get("machines", [])
    if not (machine_defs is Array) or machine_defs.is_empty():
        return _error("aucune machine definie (champ 'machines')")
    var machines: Array = []
    var seen_ids := {}
    for entry in machine_defs:
        if not (entry is Dictionary):
            return _error("machine invalide : un objet etait attendu")
        var machine_type := str(entry.get("type", ""))
        if not MACHINE_TYPES.has(machine_type):
            return _error(
                "type de machine inconnu : '" + machine_type
                + "' (types connus : " + ", ".join(MACHINE_TYPES.keys()) + ")"
            )
        var machine_id := str(entry.get("id", ""))
        if machine_id == "":
            return _error("machine de type '" + machine_type + "' sans id")
        if seen_ids.has(machine_id):
            return _error("id de machine duplique : " + machine_id)
        seen_ids[machine_id] = true

        var machine = MACHINE_TYPES[machine_type].new()
        machine.id = machine_id
        var params = entry.get("params", {})
        if not (params is Dictionary):
            return _error("params invalides pour " + machine_id)
        if machine.has_method("configure"):
            var err: int = machine.configure(params)
            if err != OK:
                return _error("parametres invalides pour " + machine_id + " (code " + str(err) + ")")

        for point in machine.create_io_points():
            var result: int = io.add_point(point)
            if result != OK:
                return _error(
                    "point d'E/S refuse pour " + machine_id + " : " + point.id
                    + " (id ou adresse dupliquee ?)"
                )
        machines.append(machine)

    # --- Mapping : les adresses du fichier ecrasent les adresses par defaut ---
    var warnings: Array = []
    var mapping = null
    if def.has("io_mapping"):
        mapping = IoMappingScript.from_file(str(def["io_mapping"]))
        if mapping == null:
            return _error("mapping introuvable ou invalide : " + str(def["io_mapping"]))
        for point in io.all_points():
            if mapping.has_variable(point.id):
                point.address = mapping.address_for_variable(point.id)
            elif point.address != "":
                warnings.append("point sans entree de mapping, adresse par defaut gardee : " + point.id)
        for entry in mapping.entries:
            if not io.has_point(str(entry["variable"])):
                warnings.append("variable du mapping sans point d'E/S correspondant : " + str(entry["variable"]))

    # --- Modbus TCP (optionnel) : cree le lien, n'ecoute PAS automatiquement ---
    var modbus_link = null
    if def.has("modbus"):
        if mapping == null:
            return _error("la section 'modbus' exige un 'io_mapping'")
        var mod = def["modbus"]
        if not (mod is Dictionary):
            return _error("section 'modbus' invalide (objet attendu)")
        var modbus_port := int(mod.get("port", 502))
        if modbus_port <= 0 or modbus_port > 65535:
            return _error("port Modbus invalide : " + str(modbus_port))
        var modbus_unit := int(mod.get("unit_id", 1))
        if modbus_unit < 1 or modbus_unit > 255:
            return _error("unit_id Modbus invalide : " + str(modbus_unit))
        modbus_link = ModbusPlcLinkScript.new(io, mapping, modbus_port, modbus_unit)
        if not modbus_link.address_map.errors.is_empty():
            return _error("; ".join(modbus_link.address_map.errors))

    # --- Parametres de simulation ---
    var sim = def.get("simulation", {})
    if not (sim is Dictionary):
        return _error("section 'simulation' invalide (objet attendu)")
    var timestep := float(sim.get("timestep", 1.0 / 60.0))
    if timestep <= 0.0:
        return _error("timestep invalide (doit etre > 0)")
    var input_timeout := int(sim.get("input_timeout_usec", 0))
    if input_timeout < 0:
        return _error("input_timeout_usec invalide (doit etre >= 0)")

    var engine = SimulationEngineScript.new(io, null)
    engine.input_timeout_usec = input_timeout
    if modbus_link != null:
        engine.plc_link = modbus_link
    for machine in machines:
        engine.add_machine(machine)

    return {
        "ok": true,
        "name": str(def.get("name", "usine sans nom")),
        "engine": engine,
        "io": io,
        "machines": machines,
        "timestep": timestep,
        "input_timeout_usec": input_timeout,
        "warnings": warnings,
        "modbus": modbus_link,
    }


static func _error(message: String) -> Dictionary:
    return { "ok": false, "error": message }
