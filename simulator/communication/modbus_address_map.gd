class_name ModbusAddressMap
extends RefCounted
## Projection des adresses canoniques IEC 61131-3 vers les zones Modbus (ADR-011).
##
##   %IX<octet>.<bit>  -> discrete inputs,  offset = octet * 8 + bit
##   %QX<octet>.<bit>  -> coils,            offset = octet * 8 + bit
##   %IW<n>            -> input registers,  offset = n
##   %QW<n>            -> holding registers, offset = n
##
## La projection est derivee du mapping JSON : aucune configuration supplementaire
## n'est requise. Les adresses non projetables sont collectees dans `errors`.

enum Zone { COILS, DISCRETE_INPUTS, INPUT_REGISTERS, HOLDING_REGISTERS }

## Entrees de projection : { variable, zone, offset, scale (optionnel) }
var projections: Array = []
var errors: Array = []

var _max_offset := {}
var _by_variable := {}


func _init(mapping = null) -> void:
    _max_offset = {
        Zone.COILS: -1,
        Zone.DISCRETE_INPUTS: -1,
        Zone.INPUT_REGISTERS: -1,
        Zone.HOLDING_REGISTERS: -1,
    }
    if mapping == null:
        return
    for entry in mapping.entries:
        var parsed: Dictionary = parse_address(str(entry["address"]))
        if parsed.is_empty():
            errors.append(
                "adresse non projetable en Modbus : '" + str(entry["address"])
                + "' (variable : " + str(entry["variable"]) + ")"
            )
            continue
        var projection := {
            "variable": str(entry["variable"]),
            "zone": parsed["zone"],
            "offset": parsed["offset"],
        }
        if entry.has("scale") and entry["scale"] != null:
            projection["scale"] = float(entry["scale"])
        projections.append(projection)
        _by_variable[projection["variable"]] = projection
        if parsed["offset"] > _max_offset[parsed["zone"]]:
            _max_offset[parsed["zone"]] = parsed["offset"]


## Analyse une adresse IEC. Retourne { zone, offset } ou {} si invalide.
static func parse_address(address: String) -> Dictionary:
    if not address.begins_with("%"):
        return {}
    var body := address.substr(1)
    if body.length() < 3:
        return {}
    var area := body.substr(0, 2)
    var rest := body.substr(2)
    match area:
        "IX", "QX":
            var dot := rest.find(".")
            if dot <= 0 or dot != rest.rfind("."):
                return {}
            var byte_s := rest.substr(0, dot)
            var bit_s := rest.substr(dot + 1)
            if not byte_s.is_valid_int() or not bit_s.is_valid_int():
                return {}
            var byte_i := int(byte_s)
            var bit_i := int(bit_s)
            if byte_i < 0 or bit_i < 0 or bit_i > 7:
                return {}
            var zone: int = Zone.DISCRETE_INPUTS if area == "IX" else Zone.COILS
            return { "zone": zone, "offset": byte_i * 8 + bit_i }
        "IW", "QW":
            if not rest.is_valid_int():
                return {}
            var n := int(rest)
            if n < 0:
                return {}
            var zone_reg: int = Zone.INPUT_REGISTERS if area == "IW" else Zone.HOLDING_REGISTERS
            return { "zone": zone_reg, "offset": n }
        _:
            return {}


func bank_size(zone: int) -> int:
    var max_offset: int = _max_offset.get(zone, -1)
    return max_offset + 1


func projection_for_variable(variable: String):
    return _by_variable.get(variable)


func projections_for_zone(zone: int) -> Array:
    return projections.filter(func(p): return p["zone"] == zone)
