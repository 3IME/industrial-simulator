# Installe les changements : labels 5BP, keypad 2x, video OGV
p = "simulator/scenes/main.gd"
s = open(p, encoding="utf-8").read()

# 1) labels 5BP : à DROITE de la boite (z négatif vers la porte), 10 cm d'écart
old_lbl = '''        # a droite de la boite (z+), aligne avec chaque bouton
        lbl.position = boite_pos + Vector3(-0.01, -0.088 + 0.048 * btn, 0.18)
        lbl.rotation = Vector3(0.0, PI / 2.0, 0.0)'''
assert old_lbl in s, "ancre labels introuvable"
s = s.replace(old_lbl, '''        # a droite de la boite : 10 cm vers la porte, texte part du bord
        lbl.position = boite_pos + Vector3(-0.01, -0.088 + 0.048 * btn, -0.10)
        lbl.rotation = Vector3(0.0, PI / 2.0, 0.0)''', 1)

# 2) keypad : 2x plus grand, à droite de la boite 5BP
old_kp = '''    var keypad_pos := Vector3(cx - 3.70, 0.45, cz + 1.2)
    _place_prop("res://assets/props/keypad_lock.glb", keypad_pos,
        Vector3(0.0, PI / 2.0, 0.0))
    _add_static_box(keypad_pos + Vector3(0.03, 0.0, 0.0),
        Vector3(0.05, 0.14, 0.10), "keypad_code")'''
assert old_kp in s, "ancre keypad introuvable"
s = s.replace(old_kp, '''    var keypad_pos := Vector3(cx - 3.70, 0.60, cz + 2.0)
    _place_prop("res://assets/props/keypad_lock.glb", keypad_pos,
        Vector3(0.0, PI / 2.0, 0.0), 2.0)
    _add_static_box(keypad_pos + Vector3(0.05, 0.0, 0.0),
        Vector3(0.08, 0.28, 0.18), "keypad_code")''', 1)

# 3) remplacer la fonction video par la vraie implementation OGV
old_video = '''func _jouer_video_nostromo() -> void:
    if _video_jouee:
        return
    _video_jouee = true
    # Charger la video A LA DEMANDE (peu utilisee, pas de preload)
    var chemin := "res://assets/videos/nostromo_destruct.mp4"
    if not ResourceLoader.exists(chemin):
        push_warning("video introuvable : " + chemin)
        _video_jouee = false
        return
    # TODO : lecture video sur l'ecran a la place des cameras
    # (Godot ne supporte que .ogv en natif — conversion necessaire)
    print("VIDEO : format MP4 non supporte nativement par Godot.")
    print("VIDEO : convertir en .ogv (Theora) pour lecture sur l'ecran.")
    _video_jouee = false'''
assert old_video in s, "ancre video introuvable"

new_video = (
    'func _jouer_video_nostromo() -> void:\n'
    '\tif _video_jouee:\n'
    '\t\treturn\n'
    '\tvar flux = load("res://assets/videos/nostromo_destruct.ogv")\n'
    '\tif flux == null:\n'
    '\t\tpush_warning("video introuvable")\n'
    '\t\treturn\n'
    '\t_video_jouee = true\n'
    '\tprint("VIDEO : Nostromo — touche 0 pour revenir aux cameras")\n'
    '\t# SubViewport pour la video, assigne a l\'ecran via le mechanisme differe\n'
    '\tvar vp_vid := SubViewport.new()\n'
    '\tvp_vid.size = Vector2i(640, 360)\n'
    '\tvp_vid.render_target_update_mode = SubViewport.UPDATE_ALWAYS\n'
    '\tadd_child(vp_vid)\n'
    '\tvar lecteur := VideoStreamPlayer.new()\n'
    '\tlecteur.stream = flux\n'
    '\tlecteur.autoplay = true\n'
    '\tlecteur.size = Vector2(640, 360)\n'
    '\tvp_vid.add_child(lecteur)\n'
    '\t_video_vp = vp_vid\n'
    '\t# declencher la re-assignation du materiau de l\'ecran\n'
    '\t_cctv_composite_a_assigner = vp_vid\n'
    '\t_cctv_frames_attente = 0'
)
s = s.replace(old_video, new_video, 1)

# 4) membres pour la video
s = s.replace("var _video_jouee := false",
"""var _video_jouee := false
var _video_vp: SubViewport = null""", 1)

# 5) touche 0 : couper l'alarme ET/OU la video
s = s.replace(
    '''        if event.keycode == KEY_0 and _alarme_active:
            _couper_alarme()
            return''',
    '''        if event.keycode == KEY_0:
            if _video_jouee:
                _arreter_video()
                return
            if _alarme_active:
                _couper_alarme()
                return''', 1)

# 6) fonction d'arret : detruire le viewport video, retablir les cameras
anchor_arret = "const ANNONCES_BOITE :="
assert anchor_arret in s
s = s.replace(anchor_arret,
    'func _arreter_video() -> void:\n'
    '\t_video_jouee = false\n'
    '\tif _video_vp != null:\n'
    '\t\t_video_vp.queue_free()\n'
    '\t\t_video_vp = null\n'
    '\t# retablir le composite CCTV sur l\'ecran\n'
    '\tif _cctv_composite != null:\n'
    '\t\t_cctv_composite_a_assigner = _cctv_composite\n'
    '\t\t_cctv_frames_attente = 0\n'
    '\tprint("VIDEO : arretee — retour aux cameras")\n'
    '\n\n'
    + anchor_arret, 1)

open(p, "w", encoding="utf-8", newline="\n").write(s)
print("labels + keypad 2x + video OGV installés")
