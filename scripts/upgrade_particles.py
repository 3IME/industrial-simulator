# Ameliore les flammes et la fumee selon le tutoriel fourni par l'utilisateur
p = "simulator/scenes/main.gd"
s = open(p, encoding="utf-8").read()

# === 1) REMPLACER LES FLAMMES (bloc complet) ===
debut_fl = s.index("    _flammes = GPUParticles3D.new()")
fin_fl = s.index("    # Emitters de fumee")
nouvelles_flammes = '''    _flammes = GPUParticles3D.new()
    _flammes.amount = 60
    _flammes.lifetime = 1.2
    _flammes.position = Vector3(HALL_MAX_X - 0.90, 0.2, 25.0)

    var mat_fl := ParticleProcessMaterial.new()
    mat_fl.direction = Vector3(0, 1, 0)
    mat_fl.spread = 20.0
    mat_fl.initial_velocity_min = 1.0
    mat_fl.initial_velocity_max = 2.0
    mat_fl.gravity = Vector3(0, 1.0, 0)
    mat_fl.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    mat_fl.emission_sphere_radius = 0.2
    mat_fl.radial_velocity_min = 0.0
    mat_fl.radial_velocity_max = 0.5
    mat_fl.scale_min = 0.9
    mat_fl.scale_max = 1.4
    mat_fl.angle_min = -180.0
    mat_fl.angle_max = 180.0
    # Taille : petit -> grand
    var size_c := Curve.new()
    size_c.add_point(Vector2(0.0, 0.2))
    size_c.add_point(Vector2(0.5, 0.8))
    size_c.add_point(Vector2(1.0, 1.4))
    var size_t := CurveTexture.new()
    size_t.curve = size_c
    mat_fl.scale_curve = size_t
    # Alpha : apparition rapide -> fondu long (point cle du tutoriel)
    var alpha_c := Curve.new()
    alpha_c.add_point(Vector2(0.0, 0.0))
    alpha_c.add_point(Vector2(0.15, 1.0))
    alpha_c.add_point(Vector2(0.8, 0.8))
    alpha_c.add_point(Vector2(1.0, 0.0))
    var alpha_t := CurveTexture.new()
    alpha_t.curve = alpha_c
    mat_fl.alpha_curve = alpha_t
    # Couleur : jaune -> orange -> rouge sombre
    var grad_fl := Gradient.new()
    grad_fl.set_color(0, Color(1.0, 0.95, 0.6))
    grad_fl.set_color(1, Color(0.4, 0.05, 0.0))
    grad_fl.add_point(0.3, Color(1.0, 0.6, 0.1))
    grad_fl.add_point(0.6, Color(0.9, 0.2, 0.0))
    var grad_fl_t := GradientTexture1D.new()
    grad_fl_t.gradient = grad_fl
    mat_fl.color_ramp = grad_fl_t
    _flammes.process_material = mat_fl

    var quad_fl := QuadMesh.new()
    quad_fl.size = Vector2(1.5, 1.5)
    var surf_fl := StandardMaterial3D.new()
    surf_fl.albedo_texture = load("res://assets/textures/fire_01.png")
    surf_fl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    surf_fl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    surf_fl.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    surf_fl.vertex_color_use_as_albedo = true
    surf_fl.vertex_color_is_srgb = true
    surf_fl.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    quad_fl.material = surf_fl
    _flammes.draw_pass_1 = quad_fl
    _flammes.emitting = false
    add_child(_flammes)

    # Lumiere orange avec flicker organique (courbe, pas sin())
    _flammes_light = OmniLight3D.new()
    _flammes_light.position = Vector3(HALL_MAX_X - 1.5, 5.0, 25.0)
    _flammes_light.light_color = Color(1.0, 0.5, 0.1)
    _flammes_light.omni_range = 15.0
    _flammes_light.light_energy = 0.0
    add_child(_flammes_light)

'''
s = s[:debut_fl] + nouvelles_flammes + s[fin_fl:]

# === 2) AMELIORER LA FUMEE (structure tutoriel) ===
# trouver le bloc de la boucle for pos_fumee et le remplacer
debut_f = s.index("        var fumee := GPUParticles3D.new()")
fin_f = s.index("        _fumee_parts.append(fumee)")
nouvelle_fumee = '''        var fumee := GPUParticles3D.new()
        var mat_fumee := ParticleProcessMaterial.new()
        mat_fumee.direction = Vector3(0, 1, 0)
        mat_fumee.spread = 40.0
        mat_fumee.initial_velocity_min = 0.5
        mat_fumee.initial_velocity_max = 1.5
        mat_fumee.gravity = Vector3(0, 1.0, 0)
        mat_fumee.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
        mat_fumee.emission_sphere_radius = 0.5
        mat_fumee.scale_min = 5.0
        mat_fumee.scale_max = 14.0
        mat_fumee.angle_min = -180.0
        mat_fumee.angle_max = 180.0
        # Taille : petit -> tres grand
        var sz_c := Curve.new()
        sz_c.add_point(Vector2(0.0, 0.3))
        sz_c.add_point(Vector2(0.5, 0.9))
        sz_c.add_point(Vector2(1.0, 1.6))
        var sz_t := CurveTexture.new()
        sz_t.curve = sz_c
        mat_fumee.scale_curve = sz_t
        # Alpha : apparition douce -> fondu tres long
        var al_c := Curve.new()
        al_c.add_point(Vector2(0.0, 0.0))
        al_c.add_point(Vector2(0.2, 0.6))
        al_c.add_point(Vector2(0.7, 0.5))
        al_c.add_point(Vector2(1.0, 0.0))
        var al_t := CurveTexture.new()
        al_t.curve = al_c
        mat_fumee.alpha_curve = al_t
        # Couleur : gris fonce -> gris clair
        var grad_f := Gradient.new()
        grad_f.set_color(0, Color(0.12, 0.12, 0.14))
        grad_f.set_color(1, Color(0.35, 0.35, 0.38))
        var grad_ft := GradientTexture1D.new()
        grad_ft.gradient = grad_f
        mat_fumee.color_ramp = grad_ft
        fumee.process_material = mat_fumee
        var quad_f := QuadMesh.new()
        quad_f.size = Vector2(6, 6)
        var surf_f := StandardMaterial3D.new()
        surf_f.albedo_texture = load("res://assets/textures/fire_01.png")
        surf_f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        surf_f.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        surf_f.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        surf_f.vertex_color_use_as_albedo = true
        surf_f.vertex_color_is_srgb = true
        surf_f.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
        quad_f.material = surf_f
        fumee.draw_pass_1 = quad_f
        fumee.amount = 0
        fumee.lifetime = 8.0
        fumee.position = pos_fumee
        fumee.emitting = false
'''
s = s[:debut_f] + nouvelle_fumee + s[fin_f:]

# === 3) FLICKER avec courbe bruitee (pas sin) ===
s = s.replace(
    "    if _flammes_light != null and _flammes_light.light_energy > 0.0:\n        _flammes_light.light_energy = 1.5 + sin(_cctv_temps * 15.0) * 0.5 + randf() * 0.3",
    "    if _flammes_light != null and _flammes_light.light_energy > 0.0:\n        var ft := fmod(_cctv_temps * 3.0, 1.0)\n        _flammes_light.light_energy = 2.0 + sin(ft * 31.4) * 0.5 + sin(ft * 7.3) * 0.8 + randf() * 0.4")

# === 4) Ajouter la texture aux heavy_resources ===
a = 'TEX_ROOF_N := "res://assets/textures/corrugated_iron_02_nor_gl.jpg"'
assert a in s
s = s.replace(a, a + '''
        "res://assets/textures/fire_01.png",''', 1)
# corriger : les chemins dans heavy_resources sont sans le prefix const
s = s.replace('"res://assets/textures/fire_01.png",',
              '"res://assets/textures/fire_01.png",', 1)

open(p, "w", encoding="utf-8", newline="\n").write(s)
print("flammes + fumee ameliorees selon tutoriel")
