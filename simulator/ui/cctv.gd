extends Node3D
## Systeme de videosurveillance : N camera 3D reelles (balayage lent),
## chacune rendue dans un SubViewport basse resolution, composees en
## grille 2x2 dans un viewport composite avec shader surveillance,
## etiquettes CAM + REC clignotant + horodatage. La texture composite
## est exposee pour l'ecran 3D (TV du bureau).
##
## Usage : var cctv = preload("res://ui/cctv.gd").new()
##         cctv.setup([{pos, visee, nom, intensite, teinte}, ...]) ; add_child(cctv)
##         ecran.material.albedo_texture = cctv.texture

const FLUX_SHADER := preload("res://ui/cctv_flux.gdshader")
const LARGEUR_FLUX := 320
const HAUTEUR_FLUX := 180

var texture: ViewportTexture = null
var _composite: SubViewport = null

var _cams: Array = []          # Camera3D avec balayage
var _originales: Array = []    # rotations initiales
var _temps := 0.0
var _recs: Array = []          # pastilles REC
var _alarmes: Array = []       # etat alarme par flux
var _no_signal: Array = []
var _materiaux: Array = []     # etiquettes PERTE DE SIGNAL


func setup(flux: Array) -> void:
	var composite := SubViewport.new()
	composite.size = Vector2(LARGEUR_FLUX * 4, HAUTEUR_FLUX * 2 + 2)
	composite.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(composite)
	_composite = composite
	texture = composite.get_texture()

	for i in range(flux.size()):
		var conf: Dictionary = flux[i]
		# camera reelle dans l'usine
		var vp := SubViewport.new()
		vp.size = Vector2(LARGEUR_FLUX, HAUTEUR_FLUX)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var cam := Camera3D.new()
		cam.fov = 72.0
		cam.position = conf.pos
		cam.look_at_from_position(conf.pos, conf.visee, Vector3.UP)
		vp.add_child(cam)
		_cams.append(cam)
		_originales.append(cam.rotation)
		_alarmes.append(false)

		# quadrant dans le composite
		var tx := TextureRect.new()
		tx.texture = vp.get_texture()
		tx.position = Vector2((i % 2) * LARGEUR_FLUX * 2.0,
				(i / 2) * (HAUTEUR_FLUX * 2.0 + 2.0))
		tx.size = Vector2(LARGEUR_FLUX * 2.0, HAUTEUR_FLUX * 2.0)
		var mat := ShaderMaterial.new()
		mat.shader = FLUX_SHADER
		mat.set_shader_parameter("intensite", conf.get("intensite", 0.3))
		mat.set_shader_parameter("teinte", conf.get("teinte", Color(0.9, 1.0, 0.95)))
		tx.material = mat
		_materiaux.append(mat)
		composite.add_child(tx)

		# etiquettes : nom, horodatage, REC, perte de signal
		var coin := tx.position
		var nom := Label.new()
		nom.text = conf.nom
		nom.position = coin + Vector2(10, 8)
		nom.add_theme_font_size_override("font_size", 26)
		nom.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
		composite.add_child(nom)

		var rec := ColorRect.new()
		rec.color = Color(1.0, 0.1, 0.1)
		rec.size = Vector2(14, 14)
		rec.position = coin + Vector2(LARGEUR_FLUX * 2.0 - 120.0, 16.0)
		composite.add_child(rec)
		_recs.append(rec)
		var texte_rec := Label.new()
		texte_rec.text = "REC"
		texte_rec.position = coin + Vector2(LARGEUR_FLUX * 2.0 - 100.0, 6.0)
		texte_rec.add_theme_font_size_override("font_size", 26)
		texte_rec.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		composite.add_child(texte_rec)

		var horloge := Label.new()
		horloge.name = "Horloge"
		horloge.position = coin + Vector2(10, HAUTEUR_FLUX * 2.0 - 40.0)
		horloge.add_theme_font_size_override("font_size", 24)
		horloge.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85))
		composite.add_child(horloge)

		var perte := Label.new()
		perte.text = "PERTE DE SIGNAL"
		perte.position = coin + Vector2(LARGEUR_FLUX - 140.0, HAUTEUR_FLUX - 20.0)
		perte.add_theme_font_size_override("font_size", 34)
		perte.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
		perte.visible = false
		composite.add_child(perte)
		_no_signal.append(perte)


## Flux en mode alarme (glitchs lourds + PERTE DE SIGNAL).
func set_alarme(index: int, actif: bool) -> void:
	if index < 0 or index >= _cams.size():
		return
	_alarmes[index] = actif
	if index < _materiaux.size():
		_materiaux[index].set_shader_parameter("alarme", 1.0 if actif else 0.0)
	_no_signal[index].visible = actif


func _process(delta: float) -> void:
	_temps += delta
	# balayage lent de chaque camera (amplitude et vitesse legerement
	# differentes par camera pour un rendu naturel)
	for i in range(_cams.size()):
		var vitesse := 0.3 + 0.05 * i
		var amplitude := 0.06
		_cams[i].rotation.y = _originales[i].y + sin(_temps * vitesse) * amplitude
		_cams[i].rotation.x = _originales[i].x \
				+ sin(_temps * vitesse * 0.7) * amplitude * 0.3
	# REC clignote, horloge a jour (les Labels se nomment Horloge, Horloge2...)
	var allume := fmod(_temps, 1.0) < 0.6
	for rec in _recs:
		rec.visible = allume
	var heure := Time.get_time_string_from_system().substr(0, 8)
	var composite: SubViewport = _composite
	for enfant in composite.get_children():
		if enfant is Label and enfant.name.begins_with("Horloge"):
			enfant.text = heure
