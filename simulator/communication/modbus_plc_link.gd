class_name ModbusPlcLink
extends RefCounted
## Pont entre le contrat PlcLink et le serveur Modbus TCP (ADR-011).
##
## Au cycle du moteur :
##   publish_inputs : table d'E/S -> banques d'entrees (discrete inputs, input registers)
##   pull_outputs   : sorties ECRITES par le maitre (coils, holding registers) -> table.
##     Seules les sorties reellement ecrites par le maitre sont rapatriees :
##     une sortie jamais ecrite garde la valeur par defaut de la table.
##   poll           : traite le reseau (hook optionnel appele par le moteur en
##     debut de cycle).
##
## Mise a l'echelle des registres (valeur d'ingenieur <-> brut 16 bits) :
##   brut = round(valeur * scale), interprete en signe complement a deux ;
##   scale par entree du mapping ("scale"), sinon 100 pour les points
##   ANALOG_* (precision 0,01) et 1 pour COUNTER / ENCODER.

const ModbusTcpServerScript = preload("res://communication/modbus_tcp_server.gd")
const ModbusAddressMapScript = preload("res://communication/modbus_address_map.gd")
const IoPointScript = preload("res://io/io_point.gd")

var server = null            # ModbusTcpServer
var address_map = null       # ModbusAddressMap
var io = null                # IoTable de reference

var _proj_by_coil_offset := {}      # offset -> projection
var _proj_by_holding_offset := {}


func _init(p_io = null, p_mapping = null, p_port: int = 502, p_unit_id: int = 1) -> void:
    io = p_io
    address_map = ModbusAddressMapScript.new(p_mapping)
    server = ModbusTcpServerScript.new()
    server.port = p_port
    server.unit_id = p_unit_id
    server.configure_bank_sizes(
        address_map.bank_size(ModbusAddressMapScript.Zone.COILS),
        address_map.bank_size(ModbusAddressMapScript.Zone.DISCRETE_INPUTS),
        address_map.bank_size(ModbusAddressMapScript.Zone.INPUT_REGISTERS),
        address_map.bank_size(ModbusAddressMapScript.Zone.HOLDING_REGISTERS)
    )
    for projection in address_map.projections:
        if projection["zone"] == ModbusAddressMapScript.Zone.COILS:
            _proj_by_coil_offset[projection["offset"]] = projection
        elif projection["zone"] == ModbusAddressMapScript.Zone.HOLDING_REGISTERS:
            _proj_by_holding_offset[projection["offset"]] = projection


## Se met a l'ecoute (le port, si > 0, remplace celui de la construction).
func listen(p_port: int = -1) -> Error:
    return server.listen(p_port)


func stop() -> void:
    server.stop()


## Traitement reseau : appele par le moteur en debut de cycle (hook optionnel),
## et/ou par un Node Godot a chaque frame en Phase 5.
func poll() -> void:
    server.poll()


## Contrat PlcLink (temps 2 du cycle) : entrees de la table -> banques Modbus.
func publish_inputs(table = null) -> void:
    var target = table if table != null else io
    if target == null:
        return
    for projection in address_map.projections:
        var point = target.get_point(projection["variable"])
        if point == null:
            continue
        if projection["zone"] == ModbusAddressMapScript.Zone.DISCRETE_INPUTS:
            server.discrete_inputs[projection["offset"]] = bool(point.value)
        elif projection["zone"] == ModbusAddressMapScript.Zone.INPUT_REGISTERS:
            server.input_registers[projection["offset"]] = _encode_register(point, projection)


## Contrat PlcLink (temps 3 du cycle) : ecritures du maitre -> table d'E/S.
func pull_outputs(table = null) -> void:
    var target = table if table != null else io
    if target == null:
        return
    var dirty_coils: Dictionary = server.take_dirty_coils()
    for offset in dirty_coils:
        var projection = _proj_by_coil_offset.get(offset)
        if projection != null:
            target.set_value(projection["variable"], bool(server.coils[offset]))
    var dirty_holding: Dictionary = server.take_dirty_holding()
    for offset in dirty_holding:
        var projection = _proj_by_holding_offset.get(offset)
        if projection != null:
            var point = target.get_point(projection["variable"])
            if point != null:
                var raw: int = int(server.holding_registers[offset])
                var signed := raw - 65536 if raw >= 32768 else raw
                target.set_value(projection["variable"], signed / _scale_for(point, projection))


func _scale_for(point, projection) -> float:
    var configured = projection.get("scale")
    if configured != null:
        return float(configured)
    match point.io_type:
        IoPointScript.Type.ANALOG_INPUT, IoPointScript.Type.ANALOG_OUTPUT:
            return 100.0
        _:
            return 1.0


func _encode_register(point, projection) -> int:
    var raw := int(round(float(point.value) * _scale_for(point, projection)))
    raw = clampi(raw, -32768, 32767)
    return raw & 0xFFFF
