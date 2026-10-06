extends SceneTree
## Verifie que l'ecran de selection Eleve/Professeur charge, s'installe
## et que le script attache fonctionne (references @onready resolvees,
## clic simule activer le bouton).

var frames := 0

func _initialize() -> void:
    var scene: PackedScene = load("res://scenes/CharacterSelect.tscn")
    if scene == null:
        print("ECHEC : scene introuvable")
        quit(1)
        return
    get_root().add_child(scene.instantiate())

func _process(_d: float) -> bool:
    frames += 1
    if frames < 5:
        return false
    var ecran := get_root().get_node_or_null("CharacterSelect")
    if ecran == null:
        print("ECHEC : noeud absent de l'arbre")
        quit(1)
        return true
    var ok_carte: bool = ecran.get_node_or_null("MainContainer/CharacterGrid/StudentCard") != null \
        and ecran.get_node_or_null("MainContainer/CharacterGrid/TeacherCard") != null
    var bouton: Button = ecran.get_node("MainContainer/ConfirmButton")
    var ok_shader: bool = ecran.get_node_or_null("ScanlineEffect") != null
    # clic simule sur la carte eleve via l'API publique du script
    var ev := InputEventMouseButton.new()
    ev.button_index = MOUSE_BUTTON_LEFT
    ev.pressed = true
    ecran._on_card_click(ev, "eleve",
        ecran.get_node("MainContainer/CharacterGrid/StudentCard"))
    var role_ok: bool = ecran.selected_role == "eleve"
    var bouton_active: bool = not bouton.disabled
    print("RESULTAT cartes=", ok_carte, " shader=", ok_shader,
        " role=", role_ok, " bouton_active=", bouton_active)
    if ok_carte and ok_shader and role_ok and bouton_active:
        print("CHARACTER_SELECT OK")
        quit(0)
    else:
        print("CHARACTER_SELECT ECHEC")
        quit(1)
    return true
