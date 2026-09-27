class_name IoMapping
extends RefCounted
## Association configurable entre adresses PLC et variables de simulation.
##
## Charge depuis JSON : le mapping change sans toucher au code source.
## Format attendu :
##   {
##     "version": 1,
##     "mappings": [
##       { "address": "%IX0.0", "variable": "sensor_entry" }
##     ]
##   }

var version := 1
var entries: Array = []       # Array[Dictionary] { "address": ..., "variable": ... }
var _by_address := {}         # address -> variable
var _by_variable := {}        # variable -> address


## Construit depuis un dictionnaire deja parse. Le constructeur ne valide
## PAS (GDScript n'a pas de constructeur qui echoue proprement) : passer
## par from_json_text / from_file qui retournent null en cas d'erreur.
func _init(raw: Dictionary = {}) -> void:
    if raw.is_empty():
        return
    version = int(raw.get("version", 1))
    var mappings = raw.get("mappings", [])
    if mappings is Array:
        for entry in mappings:
            if entry is Dictionary and entry.has("address") and entry.has("variable"):
                var address: String = str(entry["address"])
                var variable: String = str(entry["variable"])
                if address != "" and variable != "":
                    entries.append({"address": address, "variable": variable})
                    _by_address[address] = variable
                    _by_variable[variable] = address


## Retourne un IoMapping valide, ou null si le JSON est invalide,
## vide, ou contient des adresses/variables dupliquees.
static func from_json_text(text: String):
    var parsed = JSON.parse_string(text)
    if parsed == null or not (parsed is Dictionary):
        return null
    var mapping = new(parsed)
    if mapping.entries.is_empty():
        return null
    # Validations structurelles que _init ne fait pas (uniquement les doublons) :
    if mapping._by_address.size() != mapping.entries.size():
        return null  # adresses dupliquees
    if mapping._by_variable.size() != mapping.entries.size():
        return null  # variables dupliquees
    return mapping


## Retourne un IoMapping valide, ou null (fichier absent ou invalide).
static func from_file(path: String):
    if not FileAccess.file_exists(path):
        return null
    return from_json_text(FileAccess.get_file_as_string(path))


func variable_for_address(address: String) -> String:
    return _by_address.get(address, "")


func address_for_variable(variable: String) -> String:
    return _by_variable.get(variable, "")


func size() -> int:
    return entries.size()


func has_address(address: String) -> bool:
    return _by_address.has(address)


func has_variable(variable: String) -> bool:
    return _by_variable.has(variable)
