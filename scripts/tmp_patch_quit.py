# -*- coding: utf-8 -*-
p = "simulator/scenes/main.gd"
s = open(p, encoding="utf-8").read()

# 1. membre dialogue
old = "var _etiquette_charge: Label = null"
assert old in s, "membre"
s = s.replace(old, old + "\nvar _dialogue_sortie: CanvasLayer = null")

# 2. porte usine (chaine generale) : dialogue au lieu de quit
old2 = """    if collider.get_meta("interaction") == "porte_usine":
        print("Porte de l'usine : sortie du simulateur")
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        get_tree().quit(0)"""
assert old2 in s, "porte usine"
s = s.replace(old2, """    if collider.get_meta("interaction") == "porte_usine":
        _demander_quitter()""")

# 3. porte secours (chaine classe) : dialogue au lieu de quit
old3 = """            elif hit_cl.collider.get_meta("interaction") == "porte_sortie_jeu":
                print("Porte de secours : sortie du simulateur")
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
                get_tree().quit(0)"""
assert old3 in s, "porte secours"
s = s.replace(old3, """            elif hit_cl.collider.get_meta("interaction") == "porte_sortie_jeu":
                _demander_quitter()""")

# 4. instancier le dialogue a cote du navigateur (disponible solo aussi)
old4 = """    # Navigateur d'assets (touche J) : disponible EN SOLO aussi
    var navigateur := preload("res://ui/asset_browser.gd").new()
    add_child(navigateur)"""
assert old4 in s, "navigateur"
s = s.replace(old4, old4 + """
    # Fenetre de confirmation de sortie (design maintenance industrielle)
    _dialogue_sortie = preload("res://ui/dialogue_quit.gd").new()
    add_child(_dialogue_sortie)""")

# 5. helper
old5 = "func _unhandled_key_input(event: InputEvent) -> void:"
assert old5 in s, "helper ancre"
s = s.replace(old5, """func _demander_quitter() -> void:
    ## Ouvre la fenetre de confirmation (OUI / NON) : l'arret n'a lieu
    ## que si l'utilisateur confirme.
    if _dialogue_sortie != null:
        _dialogue_sortie.ouvrir()


""" + old5, 1)

open(p, "w", encoding="utf-8", newline="\n").write(s)
print("OK main branche")
