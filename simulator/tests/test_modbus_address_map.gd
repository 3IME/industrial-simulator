extends RefCounted
## Tests de la projection d'adresses IEC 61131-3 -> Modbus (ADR-011).

const ModbusAddressMap = preload("res://communication/modbus_address_map.gd")
const IoMapping = preload("res://io/io_mapping.gd")


func run(t) -> void:
    t.begin_suite("modbus_projection")

    # --- Analyse d'adresses valides ---
    var cases := [
        ["%IX0.0", ModbusAddressMap.Zone.DISCRETE_INPUTS, 0],
        ["%IX0.7", ModbusAddressMap.Zone.DISCRETE_INPUTS, 7],
        ["%IX1.0", ModbusAddressMap.Zone.DISCRETE_INPUTS, 8],
        ["%QX0.1", ModbusAddressMap.Zone.COILS, 1],
        ["%QX2.3", ModbusAddressMap.Zone.COILS, 19],
        ["%IW0", ModbusAddressMap.Zone.INPUT_REGISTERS, 0],
        ["%IW12", ModbusAddressMap.Zone.INPUT_REGISTERS, 12],
        ["%QW0", ModbusAddressMap.Zone.HOLDING_REGISTERS, 0],
        ["%QW3", ModbusAddressMap.Zone.HOLDING_REGISTERS, 3],
    ]
    for case in cases:
        var parsed: Dictionary = ModbusAddressMap.parse_address(case[0])
        t.check_eq(parsed.get("zone", -1), case[1], "zone de " + case[0])
        t.check_eq(parsed.get("offset", -1), case[2], "offset de " + case[0])

    # --- Adresses invalides ---
    for bad in ["IX0.0", "%IX0.8", "%IX0", "%IX.1", "%IX0.1.2", "%QX", "%IW", "%IWx", "%IW-1", "%QW-3", "%ZZ0", "", "%QW1.5"]:
        t.check(
            ModbusAddressMap.parse_address(bad).is_empty(),
            "adresse refusee : '" + bad + "'"
        )

    # --- Projection depuis le mapping reel du convoyeur ---
    var mapping = IoMapping.from_file("res://config/conveyor_io_map.json")
    var map = ModbusAddressMap.new(mapping)
    t.check(map.errors.is_empty(), "mapping du convoyeur projetable sans erreur")
    t.check_eq(map.projections.size(), 12, "12 projections")
    t.check_eq(map.bank_size(ModbusAddressMap.Zone.COILS), 9, "banque coils : 9 (offsets 0,1,8)")
    t.check_eq(map.bank_size(ModbusAddressMap.Zone.DISCRETE_INPUTS), 9, "banque discrete : 9")
    t.check_eq(map.bank_size(ModbusAddressMap.Zone.INPUT_REGISTERS), 5, "banque input regs : 5 (0-4)")
    t.check_eq(map.bank_size(ModbusAddressMap.Zone.HOLDING_REGISTERS), 1, "banque holding regs : 1")

    var run_proj = map.projection_for_variable("conveyor_01.run")
    t.check_not_null(run_proj, "projection de conveyor_01.run")
    t.check_eq(run_proj["zone"], ModbusAddressMap.Zone.COILS, "conveyor_01.run -> coils")
    t.check_eq(run_proj["offset"], 0, "conveyor_01.run -> coil 0")
    t.check_eq(map.projection_for_variable("sensor_entry")["offset"], 0, "sensor_entry -> discrete 0")
    t.check_eq(map.projections_for_zone(ModbusAddressMap.Zone.INPUT_REGISTERS).size(), 5, "5 registres d'entree projetes")
    t.check_is_null(map.projection_for_variable("inconnu"), "variable inconnue -> null")

    # --- Echelle optionnelle par entree de mapping ---
    var with_scale = IoMapping.from_json_text("""
{
  "version": 1,
  "mappings": [
    { "address": "%QW0", "variable": "var_a", "scale": 10.0 },
    { "address": "%QW1", "variable": "var_b" }
  ]
}
""")
    var scaled_map = ModbusAddressMap.new(with_scale)
    t.check_eq(
        float(scaled_map.projection_for_variable("var_a").get("scale", 0.0)),
        10.0,
        "echelle explicite conservee"
    )
    t.check(
        not scaled_map.projection_for_variable("var_b").has("scale"),
        "sans echelle explicite : champ absent (defaut par type de point)"
    )

    # --- Adresses non projetables : collectees, pas de crash ---
    var broken = IoMapping.from_json_text("""
{
  "version": 1,
  "mappings": [
    { "address": "%ZZ0", "variable": "var_z" }
  ]
}
""")
    var broken_map = ModbusAddressMap.new(broken)
    t.check_eq(broken_map.projections.size(), 0, "aucune projection valide")
    t.check_eq(broken_map.errors.size(), 1, "une erreur collectee")
    t.check(str(broken_map.errors[0]).contains("%ZZ0"), "message d'erreur explicite")
