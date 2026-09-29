extends RefCounted
## Tests du mapping PLC <-> simulation (IoMapping).

const IoMapping = preload("res://io/io_mapping.gd")

const VALID := """
{
  "version": 1,
  "mappings": [
    { "address": "%IX0.0", "variable": "sensor_entry" },
    { "address": "%QX0.0", "variable": "conveyor_01.run" }
  ]
}
"""

const DUPLICATE_ADDRESS := """
{
  "version": 1,
  "mappings": [
    { "address": "%IX0.0", "variable": "sensor_entry" },
    { "address": "%IX0.0", "variable": "sensor_exit" }
  ]
}
"""

const DUPLICATE_VARIABLE := """
{
  "version": 1,
  "mappings": [
    { "address": "%IX0.0", "variable": "sensor_entry" },
    { "address": "%IX0.1", "variable": "sensor_entry" }
  ]
}
"""

const ONE_VALID_ONE_INCOMPLETE := """
{
  "version": 1,
  "mappings": [
    { "address": "%IX0.0", "variable": "sensor_entry" },
    { "address": "%IX0.1" }
  ]
}
"""


func run(t) -> void:
    t.begin_suite("io_mapping")

    # Chargement nominal depuis du texte JSON
    var m = IoMapping.from_json_text(VALID)
    t.check_not_null(m, "JSON valide charge")
    t.check_eq(m.size(), 2, "2 entrees")
    t.check_eq(m.variable_for_address("%IX0.0"), "sensor_entry", "adresse -> variable")
    t.check_eq(m.address_for_variable("conveyor_01.run"), "%QX0.0", "variable -> adresse")
    t.check(m.has_address("%QX0.0"), "has_address")
    t.check(m.has_variable("sensor_entry"), "has_variable")
    t.check(not m.has_address("%IW7"), "adresse absente")
    t.check_eq(m.variable_for_address("%IW7"), "", "lookup vide -> chaine vide")

    # Erreurs de chargement
    t.check_is_null(IoMapping.from_json_text("{ ceci n'est pas du json"), "JSON invalide -> null")
    t.check_is_null(IoMapping.from_json_text("{}"), "dictionnaire sans mappings -> null")
    t.check_is_null(IoMapping.from_json_text("[]"), "racine non dictionnaire -> null")
    t.check_is_null(IoMapping.from_json_text(DUPLICATE_ADDRESS), "adresse dupliquee -> null")
    t.check_is_null(IoMapping.from_json_text(DUPLICATE_VARIABLE), "variable dupliquee -> null")
    t.check_is_null(IoMapping.from_file("res://config/inexistant.json"), "fichier absent -> null")

    # Entree incomplete ignoree, entrees valides conservees
    var partial = IoMapping.from_json_text(ONE_VALID_ONE_INCOMPLETE)
    t.check_not_null(partial, "fichier avec entree incomplete charge")
    t.check_eq(partial.size(), 1, "seule l'entree complete est conservee")

    # Chargement du vrai fichier de configuration du prototype
    var real = IoMapping.from_file("res://config/conveyor_io_map.json")
    t.check_not_null(real, "fichier de mapping du prototype charge")
    t.check_eq(real.size(), 18, "18 entrees dans conveyor_io_map.json (convoyeur + bras)")
    t.check_eq(real.variable_for_address("%QW0"), "conveyor_01.speed_command", "projection %QW0")
    t.check_eq(real.variable_for_address("%IX0.1"), "sensor_exit", "projection %IX0.1")
