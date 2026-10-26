# -*- coding: utf-8 -*-
p = "simulator/scenes/main.gd"
s = open(p, encoding="utf-8").read()

# 1. la croix ouvre le dialogue : auto-accept OFF + branchement
old = """    # Ceinture de securite : liberer la souris si la fenetre se ferme.
    # Callable stocke : la racine SURVIT a un rechargement de scene, la
    # connexion serait sinon accumulee a chaque reload -> debranchee dans
    # _exit_tree().
    _fn_close_requested = func() -> void: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    get_tree().root.close_requested.connect(_fn_close_requested)"""
assert old in s, "ceinture"
s = s.replace(old, """    # La croix de la fenetre n'est PAS acceptee automatiquement :
    # close_requested ouvre la confirmation de sortie (OUI/NON).
    get_tree().set_auto_accept_quit(false)
    get_tree().root.close_requested.connect(_demander_quitter)""")

# 2. membre lambda supprime (le dialogue gere tout)
old2 = "var _fn_close_requested: Callable   # deconnectee dans _exit_tree"
assert old2 in s, "membre lambda"
s = s.replace(old2 + "\n", "")

# 3. _exit_tree : deconnexion du handler
old3 = """func _exit_tree() -> void:
    ## La racine survit a la scene : sans deconnexion, un rechargement de
    ## main.gd accumulerait les lambdas sur close_requested.
    var racine := get_tree().root if get_tree() != null else null
    if racine != null and _fn_close_requested.is_valid() \\
            and racine.close_requested.is_connected(_fn_close_requested):
        racine.close_requested.disconnect(_fn_close_requested)"""
assert old3 in s, "exit tree"
s = s.replace(old3, """func _exit_tree() -> void:
    ## Deconnexion propre du handler de fermeture (la racine survit a
    ## un rechargement de scene).
    if get_tree() == null:
        return
    var racine := get_tree().root
    if racine.close_requested.is_connected(_demander_quitter):
        racine.close_requested.disconnect(_demander_quitter)""")

# 4. _demander_quitter : ignore si deja ouvert (deuxieme clic croix)
old4 = """func _demander_quitter() -> void:
    ## Ouvre la fenetre de confirmation (OUI / NON) : l'arret n'a lieu
    ## que si l'utilisateur confirme.
    if _dialogue_sortie != null:
        _dialogue_sortie.ouvrir()"""
assert old4 in s, "demander"
s = s.replace(old4, """func _demander_quitter() -> void:
    ## Ouvre la fenetre de confirmation (OUI / NON) : l'arret n'a lieu
    ## que si l'utilisateur confirme. Lie a la croix de la fenetre ET
    ## aux portes de sortie.
    if _dialogue_sortie == null or _dialogue_sortie.visible:
        return
    _dialogue_sortie.ouvrir()""")

open(p, "w", encoding="utf-8", newline="\n").write(s)
print("OK croix -> confirmation")
