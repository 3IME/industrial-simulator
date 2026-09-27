class_name IoPoint
extends RefCounted
## Un point d'entree/sortie industriel abstrait.
##
## Brique de base de la couche I/O : aucune dependance au rendu (pas de Node,
## pas de scene). Les types et le sens des points suivent la vue PLC :
## entrees = lus par le PLC, sorties = ecrites par le PLC.

enum Type {
    DIGITAL_INPUT,
    DIGITAL_OUTPUT,
    ANALOG_INPUT,
    ANALOG_OUTPUT,
    COUNTER,
    ENCODER,
}

enum Quality { GOOD, BAD, UNCERTAIN }

var id := ""
var io_name := ""
var io_type: Type = Type.DIGITAL_INPUT
var value: Variant = false
var unit := ""
var address := ""
var description := ""
var quality: Quality = Quality.GOOD
var timestamp_usec := 0


func _init(
    p_id: String = "",
    p_type: Type = Type.DIGITAL_INPUT,
    p_address: String = "",
    p_io_name: String = "",
    p_value: Variant = null,
    p_unit: String = "",
    p_description: String = ""
) -> void:
    id = p_id
    io_type = p_type
    address = p_address
    io_name = p_io_name if p_io_name != "" else p_id
    unit = p_unit
    description = p_description
    if p_value != null:
        set_value(p_value)
    else:
        value = _default_value()


## Entree au sens PLC : le PLC lit la valeur (capteurs, compteurs, encodeurs).
func is_input() -> bool:
    return io_type in [
        Type.DIGITAL_INPUT, Type.ANALOG_INPUT, Type.COUNTER, Type.ENCODER
    ]


## Sortie au sens PLC : le PLC ecrit la valeur (actionneurs, consignes).
func is_output() -> bool:
    return not is_input()


func is_digital() -> bool:
    return io_type == Type.DIGITAL_INPUT or io_type == Type.DIGITAL_OUTPUT


## Ecrit la valeur en la coercant au type du point, puis horodate.
## time_usec permet d'injecter une horloge (determinisme, tests) ; -1 = horloge reelle.
func set_value(new_value: Variant, time_usec: int = -1) -> void:
    value = _coerce(new_value)
    timestamp_usec = time_usec if time_usec >= 0 else Time.get_ticks_usec()
    quality = Quality.GOOD


## Marque le point comme invalide (capteur debranche, communication perdue...).
func set_bad(time_usec: int = -1) -> void:
    quality = Quality.BAD
    timestamp_usec = time_usec if time_usec >= 0 else Time.get_ticks_usec()


func to_dict() -> Dictionary:
    return {
        "id": id,
        "name": io_name,
        "type": type_to_string(io_type),
        "value": value,
        "unit": unit,
        "address": address,
        "description": description,
        "quality": quality_to_string(quality),
        "timestamp_usec": timestamp_usec,
    }


func _default_value() -> Variant:
    match io_type:
        Type.DIGITAL_INPUT, Type.DIGITAL_OUTPUT:
            return false
        Type.ANALOG_INPUT, Type.ANALOG_OUTPUT:
            return 0.0
        _:
            return 0


func _coerce(new_value: Variant) -> Variant:
    if is_digital():
        return bool(new_value)
    match io_type:
        Type.ANALOG_INPUT, Type.ANALOG_OUTPUT:
            return float(new_value)
        _:
            return int(new_value)


static func type_to_string(t: Type) -> String:
    match t:
        Type.DIGITAL_INPUT:
            return "DIGITAL_INPUT"
        Type.DIGITAL_OUTPUT:
            return "DIGITAL_OUTPUT"
        Type.ANALOG_INPUT:
            return "ANALOG_INPUT"
        Type.ANALOG_OUTPUT:
            return "ANALOG_OUTPUT"
        Type.COUNTER:
            return "COUNTER"
        Type.ENCODER:
            return "ENCODER"
        _:
            return "UNKNOWN"


## Retourne le Type correspondant, ou -1 si inconnu.
static func type_from_string(s: String) -> int:
    match s:
        "DIGITAL_INPUT":
            return Type.DIGITAL_INPUT
        "DIGITAL_OUTPUT":
            return Type.DIGITAL_OUTPUT
        "ANALOG_INPUT":
            return Type.ANALOG_INPUT
        "ANALOG_OUTPUT":
            return Type.ANALOG_OUTPUT
        "COUNTER":
            return Type.COUNTER
        "ENCODER":
            return Type.ENCODER
        _:
            return -1


static func quality_to_string(q: Quality) -> String:
    match q:
        Quality.GOOD:
            return "GOOD"
        Quality.BAD:
            return "BAD"
        Quality.UNCERTAIN:
            return "UNCERTAIN"
        _:
            return "UNKNOWN"
