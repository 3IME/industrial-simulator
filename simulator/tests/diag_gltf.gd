extends SceneTree
## Diagnostic glTF bas niveau : la vraie raison d'un echec d'import.
## Usage : godot --headless --path simulator --script res://tests/diag_gltf.gd

func _initialize() -> void:
    var noms := ["auto_rotate", "clinician_desk", "deck_plate", "electric_motor",
        "engine_lathe", "hydraulic_press", "ladder_cage", "mezzanine_floor",
        "mezzanine_walkway", "pillar_drill", "press_brake", "office_cabin",
        "stair_3m", "track_fence", "vertical_mill", "bollard", "cell_stair"]
    var doc := GLTFDocument.new()
    var echecs := 0
    for nom in noms:
        var etat := GLTFState.new()
        var err := doc.append_from_file("res://assets/props/" + nom + ".glb", etat)
        if err != Error.OK:
            echecs += 1
            print("ECHEC ", nom, " code=", err)
        else:
            print("OK    ", nom)
    print("BILAN ", str(17 - echecs), "/17")
    quit(0)
