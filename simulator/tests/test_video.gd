extends SceneTree
func _initialize() -> void:
    var f = load("res://assets/videos/nostromo_destruct.ogv")
    if f == null:
        print("RESULTAT: null")
    else:
        print("RESULTAT: ", f.get_class(), " taille=", f.get_size())
    quit(0)
