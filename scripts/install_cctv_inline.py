# Installe le CCTV inline dans main.gd (remplace le bloc test par le vrai code)
import re

p = "simulator/scenes/main.gd"
s = open(p, encoding="utf-8").read()

# membres
s = s.replace("var _cctv = null", """var _cctv = null
var _cctv_composite: SubViewport = null
var _cctv_cams: Array[Camera3D] = []
var _cctv_orig: Array[Vector3] = []
var _cctv_recs: Array[ColorRect] = []
var _cctv_mats: Array[ShaderMaterial] = []
var _cctv_labels: Array[Label] = []
var _cctv_perte: Array[Label] = []
var _cctv_temps := 0.0""", 1)

# trouver et remplacer le bloc TEST 4 par le code CCTV complet
debut = s.index("    # TEST 4 :")
fin = s.index('    print("TEST: 4 cameras en 2x2') + len("    print(\"TEST: 4 cameras en 2x2 sur l'ecran\")")
nouveau = '''    # Videosurveillance : 4 camera reelles, grille 2x2 sur la TV
    var comp := SubViewport.new()
    comp.size = Vector2i(640, 360)
    comp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    comp.transparent_bg = false
    add_child(comp)
    var fond_cctv := ColorRect.new()
    fond_cctv.color = Color(0.005, 0.008, 0.008)
    fond_cctv.size = Vector2(640, 360)
    comp.add_child(fond_cctv)
    var cams_cctv: Array[Camera3D] = []
    var orig_cctv: Array[Vector3] = []
    var recs_cctv: Array[ColorRect] = []
    var mats_cctv: Array[ShaderMaterial] = []
    var hrs_cctv: Array[Label] = []
    var pertes_cctv: Array[Label] = []
    var flux_cctv := [
        {"pos": Vector3(0.0, 6.0, 38.0), "visee": Vector3(0.0, 1.0, 18.0),
         "nom": "CAM 01 — ENTREE", "intensite": 0.15, "teinte": Color(0.92, 1.0, 0.96)},
        {"pos": Vector3(1.5, 6.0, 6.0), "visee": Vector3(1.0, 0.5, 0.0),
         "nom": "CAM 02 — PRODUCTION", "intensite": 0.35, "teinte": Color(0.85, 0.95, 1.0)},
        {"pos": Vector3(-20.0, 5.5, -5.0), "visee": Vector3(-20.0, 0.5, -14.0),
         "nom": "CAM 03 — EXPOSITION", "intensite": 0.25, "teinte": Color(0.95, 0.98, 0.9)},
        {"pos": Vector3(10.0, 5.0, -40.0), "visee": Vector3(10.0, 1.2, -44.5),
         "nom": "CAM 04 — FOND SALLE", "intensite": 0.45, "teinte": Color(0.8, 1.0, 0.85)},
    ]
    for k in range(4):
        var conf: Dictionary = flux_cctv[k]
        var vpk := SubViewport.new()
        vpk.size = Vector2i(320, 180)
        vpk.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        vpk.transparent_bg = false
        add_child(vpk)
        var camk := Camera3D.new()
        camk.fov = 72.0
        vpk.add_child(camk)
        camk.position = conf.pos
        camk.look_at(conf.visee, Vector3.UP)
        camk.current = true
        cams_cctv.append(camk)
        orig_cctv.append(camk.rotation)

        var coin := Vector2(320.0 * (k % 2), 180.0 * (k / 2))
        var txk := TextureRect.new()
        txk.position = coin
        txk.size = Vector2(320, 180)
        txk.texture = vpk.get_texture()
        txk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        txk.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var matk := ShaderMaterial.new()
        matk.shader = preload("res://ui/cctv_flux.gdshader")
        matk.set_shader_parameter("intensite", conf.intensite)
        matk.set_shader_parameter("teinte", conf.teinte)
        txk.material = matk
        mats_cctv.append(matk)
        comp.add_child(txk)

        var nomk := Label.new()
        nomk.text = conf.nom
        nomk.position = coin + Vector2(8, 5)
        nomk.add_theme_font_size_override("font_size", 16)
        nomk.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
        nomk.mouse_filter = Control.MOUSE_FILTER_IGNORE
        comp.add_child(nomk)

        var reck := ColorRect.new()
        reck.color = Color(1.0, 0.05, 0.03)
        reck.size = Vector2(8, 8)
        reck.position = coin + Vector2(275, 9)
        reck.mouse_filter = Control.MOUSE_FILTER_IGNORE
        comp.add_child(reck)
        recs_cctv.append(reck)

        var hrk := Label.new()
        hrk.name = "Horloge_%d" % k
        hrk.text = "00:00:00"
        hrk.position = coin + Vector2(8, 155)
        hrk.add_theme_font_size_override("font_size", 14)
        hrk.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
        hrk.mouse_filter = Control.MOUSE_FILTER_IGNORE
        comp.add_child(hrk)
        hrs_cctv.append(hrk)

        var pdk := Label.new()
        pdk.text = "PERTE DE SIGNAL"
        pdk.position = coin + Vector2(60, 78)
        pdk.add_theme_font_size_override("font_size", 18)
        pdk.add_theme_color_override("font_color", Color(1.0, 0.2, 0.15))
        pdk.visible = false
        pdk.mouse_filter = Control.MOUSE_FILTER_IGNORE
        comp.add_child(pdk)
        pertes_cctv.append(pdk)

    _cctv_composite = comp
    _cctv_cams = cams_cctv
    _cctv_orig = orig_cctv
    _cctv_recs = recs_cctv
    _cctv_mats = mats_cctv
    _cctv_labels = hrs_cctv
    _cctv_perte = pertes_cctv

    var verre_cctv := StandardMaterial3D.new()
    verre_cctv.albedo_texture = comp.get_texture()
    verre_cctv.emission_enabled = true
    verre_cctv.emission_texture = comp.get_texture()
    verre_cctv.emission_energy_multiplier = 0.8
    verre_cctv.metallic = 0.6
    verre_cctv.roughness = 0.15
    ecran.material_override = verre_cctv
    print("CCTV : 4 flux actifs sur l'ecran du bureau")'''

s = s[:debut] + nouveau + s[fin:]

# animation dans _process
old_proc = "    _sync_visuals()\n    if hud != null:"
assert old_proc in s
s = s.replace(old_proc, """    # Animation CCTV : balayage, REC, horloges
    if _cctv_composite != null:
        _cctv_temps += delta
        for i in range(_cctv_cams.size()):
            var vitesse := 0.3 + 0.05 * i
            _cctv_cams[i].rotation.y = _cctv_orig[i].y + sin(_cctv_temps * vitesse) * 0.06
            _cctv_cams[i].rotation.x = _cctv_orig[i].x + sin(_cctv_temps * vitesse * 0.7) * 0.018
        var allume_cctv := fmod(_cctv_temps, 1.0) < 0.6
        for rec in _cctv_recs:
            rec.visible = allume_cctv
        var heure_cctv := Time.get_time_string_from_system().substr(0, 8)
        for hr in _cctv_labels:
            hr.text = heure_cctv

    _sync_visuals()
    if hud != null:""", 1)

# liaison confinement -> CAM 04
s = s.replace("""    if _cctv != null:
        _cctv.set_alarme(3, true)
    print("ARRET D'URGENCE : confinement annonce")""",
"""    if _cctv_mats.size() > 3:
        _cctv_mats[3].set_shader_parameter("alarme", 1.0)
    if _cctv_perte.size() > 3:
        _cctv_perte[3].visible = true
    print("ARRET D'URGENCE : confinement annonce")""", 1)

s = s.replace("""    if _cctv != null:
        _cctv.set_alarme(3, false)""",
"""    if _cctv_mats.size() > 3:
        _cctv_mats[3].set_shader_parameter("alarme", 0.0)
    if _cctv_perte.size() > 3:
        _cctv_perte[3].visible = false""", 1)

open(p, "w", encoding="utf-8", newline="\n").write(s)
print("CCTV inline installe avec animation et liaison confinement")
