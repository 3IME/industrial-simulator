class_name IoTable
extends RefCounted
## Registre en memoire de tous les points d'E/S du modele industriel.
##
## Indexe par id et par adresse industrielle. Les machines et le lien PLC
## passent par cette table : c'est la frontiere unique entre simulation
## et automate.

const IoPointScript = preload("res://io/io_point.gd")

var _by_id := {}          # id -> IoPoint
var _by_address := {}     # address -> id


func add_point(point) -> Error:
    if point == null or point.id == "":
        return ERR_INVALID_PARAMETER
    if _by_id.has(point.id):
        return ERR_ALREADY_EXISTS
    if point.address != "" and _by_address.has(point.address):
        return ERR_ALREADY_EXISTS
    _by_id[point.id] = point
    if point.address != "":
        _by_address[point.address] = point.id
    return OK


func get_point(point_id: String):
    return _by_id.get(point_id)


func get_by_address(address: String):
    var point_id: String = _by_address.get(address, "")
    if point_id == "":
        return null
    return _by_id[point_id]


func has_point(point_id: String) -> bool:
    return _by_id.has(point_id)


func remove_point(point_id: String) -> Error:
    var point = get_point(point_id)
    if point == null:
        return ERR_DOES_NOT_EXIST
    if point.address != "" and _by_address.get(point.address) == point_id:
        _by_address.erase(point.address)
    _by_id.erase(point_id)
    return OK


func set_value(point_id: String, new_value: Variant, time_usec: int = -1) -> Error:
    var point = get_point(point_id)
    if point == null:
        return ERR_DOES_NOT_EXIST
    point.set_value(new_value, time_usec)
    return OK


func get_value(point_id: String, default: Variant = null) -> Variant:
    var point = get_point(point_id)
    if point == null:
        return default
    return point.value


func point_count() -> int:
    return _by_id.size()


func all_points() -> Array:
    return _by_id.values()


## Points lus par le PLC (capteurs, compteurs, encodeurs).
func inputs() -> Array:
    return all_points().filter(func(point): return point.is_input())


## Points ecrits par le PLC (actionneurs, consignes).
func outputs() -> Array:
    return all_points().filter(func(point): return point.is_output())


## Instantane serialisable (future API REST / WebSocket).
func to_dicts() -> Array:
    return all_points().map(func(point): return point.to_dict())
