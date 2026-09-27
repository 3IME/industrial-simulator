extends RefCounted
## Tests du FactoryBuilder : definition d'usine declarative JSON (ADR-009).

const FactoryBuilder = preload("res://simulation/factory_builder.gd")

const VALID := """
{
  "version": 1,
  "name": "Usine de test",
  "simulation": { "timestep": 0.05, "input_timeout_usec": 250000 },
  "io_mapping": "user://indusim_test_mapping.json",
  "machines": [
    { "type": "conveyor", "id": "conv_a", "params": { "length": 3.0 } }
  ]
}
"""

const TEST_MAPPING := """
{
  "version": 1,
  "mappings": [
    { "address": "%IX0.0", "variable": "sensor_entry" },
    { "address": "%QX0.0", "variable": "conv_a.run" },
    { "address": "%IW9", "variable": "variable_fantome" }
  ]
}
"""


func run(t) -> void:
    t.begin_suite("factory_builder")

    # Mapping temporaire (avec une variable fantome pour tester les avertissements)
    var f = FileAccess.open("user://indusim_test_mapping.json", FileAccess.WRITE)
    f.store_string(TEST_MAPPING)
    f.close()

    # --- Construction valide depuis un dictionnaire ---
    var json := JSON.new()
    json.parse(VALID)
    var result: Dictionary = FactoryBuilder.build_from_dict(json.get_data())
    t.check(result.get("ok", false), "construction valide")
    t.check_eq(result.get("name", ""), "Usine de test", "nom de l'usine")
    t.check_eq(result.get("machines", []).size(), 1, "une machine construite")
    t.check_eq(result["machines"][0].id, "conv_a", "id de machine applique")
    t.check_almost_eq(float(result.get("timestep", 0.0)), 0.05, 0.000001, "timestep lu depuis JSON")
    t.check_eq(int(result.get("input_timeout_usec", -1)), 250000, "watchdog lu depuis JSON")
    t.check_eq(result.get("engine", null).machines.size(), 1, "machine branchee au moteur")
    t.check_eq(result.get("io", null).point_count(), 12, "12 points d'E/S pour un convoyeur")
    t.check_almost_eq(float(result["machines"][0].length), 3.0, 0.000001, "parametre length applique")
    t.check_eq(
        result["io"].get_by_address("%QX0.0").id, "conv_a.run",
        "adresse du mapping appliquee au point"
    )
    var found_warning := false
    for w in result.get("warnings", []):
        if str(w).contains("variable_fantome"):
            found_warning = true
    t.check(found_warning, "avertissement pour variable du mapping sans point d'E/S")

    # --- Fichier reel du depot ---
    var real: Dictionary = FactoryBuilder.build_from_file("res://config/factory.json")
    t.check(real.get("ok", false), "factory.json du depot se construit")
    t.check_eq(real.get("io", null).point_count(), 12, "factory.json : 12 points")
    t.check(real.get("warnings", []).is_empty(), "factory.json : aucun avertissement")
    t.check_not_null(real.get("modbus", null), "factory.json : lien Modbus present (a l'ecoute sur demande)")
    t.check_eq(
        real["io"].get_by_address("%IW4").id, "conveyor_01.belt_encoder",
        "factory.json : adresse de l'encodeur"
    )
    t.check_almost_eq(float(real.get("timestep", 0.0)), 1.0 / 60.0, 0.001, "factory.json : timestep 60 Hz")

    # --- Smoke test : l'usine construite depuis JSON fonctionne bout en bout ---
    var engine = real["engine"]
    var io = real["io"]
    var conveyor = real["machines"][0]
    conveyor.spawn_box()
    io.set_value("conveyor_01.run", true)
    engine.advance(0.1, 1.0 / 60.0)
    t.check(conveyor.box_position > 0.31, "la boite avance dans l'usine construite depuis JSON")
    t.check_eq(io.get_value("conveyor_01.running"), true, "etat publie dans l'usine construite")

    # --- Cas d'erreur (retour ok=false, jamais de crash) ---
    var one_conveyor: Array = [{ "type": "conveyor", "id": "c1" }]
    t.check(not FactoryBuilder.build_from_file("res://config/absent.json").get("ok", true), "fichier absent -> erreur")
    t.check(not FactoryBuilder.build_from_dict({}).get("ok", true), "definition sans machines -> erreur")
    t.check(not FactoryBuilder.build_from_dict({ "machines": [{ "type": "fusee", "id": "f1" }] }).get("ok", true), "type de machine inconnu -> erreur")
    t.check(not FactoryBuilder.build_from_dict({ "machines": [{ "type": "conveyor" }] }).get("ok", true), "machine sans id -> erreur")
    t.check(
        not FactoryBuilder.build_from_dict({ "machines": [
            { "type": "conveyor", "id": "c1" },
            { "type": "conveyor", "id": "c1" },
        ] }).get("ok", true),
        "id de machine duplique -> erreur"
    )
    t.check(
        not FactoryBuilder.build_from_dict({ "machines": [
            { "type": "conveyor", "id": "c1", "params": { "length": -1.0 } },
        ] }).get("ok", true),
        "parametre invalide -> erreur"
    )
    t.check(
        not FactoryBuilder.build_from_dict({ "machines": [
            { "type": "conveyor", "id": "c1", "params": { "id": "autre" } },
        ] }).get("ok", true),
        "params.id refuse -> erreur"
    )
    t.check(
        not FactoryBuilder.build_from_dict({ "machines": one_conveyor, "simulation": { "timestep": 0.0 } }).get("ok", true),
        "timestep nul -> erreur"
    )
    t.check(
        not FactoryBuilder.build_from_dict({ "machines": one_conveyor, "io_mapping": "res://config/absent.json" }).get("ok", true),
        "mapping absent -> erreur"
    )
    var broken = FactoryBuilder.build_from_dict({ "machines": [{ "type": "fusee", "id": "f1" }] })
    t.check(str(broken.get("error", "")).contains("fusee"), "message d'erreur explicite")

    # --- Section modbus (Phase 2) : lien cree, a l'ecoute seulement sur demande ---
    var json_mod := JSON.new()
    json_mod.parse(VALID)    # reutilise la definition valide (io_mapping en user://)
    var def_mod: Dictionary = json_mod.get_data()
    def_mod["modbus"] = { "port": 15022, "unit_id": 3 }
    var built_mod: Dictionary = FactoryBuilder.build_from_dict(def_mod)
    t.check(
        built_mod.get("ok", false),
        "usine avec section modbus construite (erreur : " + str(built_mod.get("error", "")) + ")"
    )
    t.check_not_null(built_mod.get("modbus", null), "lien Modbus present dans le resultat")
    t.check_eq(built_mod["modbus"].server.port, 15022, "port Modbus applique")
    t.check_eq(built_mod["modbus"].server.unit_id, 3, "unit id applique")
    t.check(not built_mod["modbus"].server.is_listening(), "le serveur n'ecoute pas automatiquement")
    t.check(built_mod["engine"].plc_link != null, "lien branche au moteur")

    var nomap: Dictionary = { "machines": [{ "type": "conveyor", "id": "c1" }], "modbus": { "port": 502 } }
    t.check(not FactoryBuilder.build_from_dict(nomap).get("ok", true), "modbus sans io_mapping -> erreur")
    var badport: Dictionary = { "machines": one_conveyor, "io_mapping": "user://indusim_test_mapping.json", "modbus": { "port": 99999 } }
    t.check(not FactoryBuilder.build_from_dict(badport).get("ok", true), "port Modbus invalide -> erreur")

    # Menage du fichier temporaire
    var dir = DirAccess.open("user://")
    if dir != null:
        dir.remove("indusim_test_mapping.json")
