extends SceneTree
## Diagnostic : quels GLB Kenney se chargent ?
## Usage : godot --headless --path simulator --script res://tests/check_kenney.gd

const DOSSIER := "res://assets/kenney_factory"

func _initialize() -> void:
    var fichiers := [
        "conveyor.glb", "conveyor-long.glb", "conveyor-stripe.glb",
        "box-small.glb", "box-large.glb", "button-floor-round.glb",
    ]
    for f in fichiers:
        var chemin: String = DOSSIER + "/" + f
        var res = load(chemin)
        if res == null:
            print("ECHEC  ", f)
        else:
            print("OK     ", f, "  (", res.get_class(), ")")
    quit(0)
