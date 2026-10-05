class_name SprinklerManager
extends Node

## Reseau de lutte incendie par sprinklers (rendu + mini-simulation
## locale). Equipement du simulateur, pas une machine PLC : comme les
## gyrophares et la fumee, il VIT dans la scene (ADR-013).
##
## Trois niveaux :
##   1. gouttelettes GPUParticles3D en cone (pas une pluie verticale) ;
##   2. declenchement INDIVIDUEL de chaque tete : une tete n'arrose que
##      si le reseau est arme (switch a lame du bureau) ET qu'un incendie
##      brule dans son rayon de couverture — en cascade, la tete la plus
##      proche du feu s'ouvre la premiere ;
##   3. accumulation d'eau au sol : le niveau monte avec le nombre de
##      tetes ouvertes (12 cm max) puis se draine, plan d'eau translucent
##      qui suit le niveau.
##
## L'eau maitrise le feu : main.gd reduit les flammes tant que
## `arrosage_actif` est vrai (cf. _process de la scene).

const HAUTEUR_TETE := 5.0        # tetes suspendues sous la charpente
const RAYON_COUVERTURE := 13.0   # disque couvert par une tete (au sol)
const DELAI_PAR_METRE := 0.22    # cascade : la chaleur met du temps a monter
const DEBIT_TETE := 0.0011       # m d'eau / s apportes par une tete ouverte
const DRAINAGE := 0.00035        # evacuation du sol / s
const NIVEAU_MAX := 0.12         # 12 cm

var arme := false                # switch a lame ferme : reseau sous tension
var niveau_eau := 0.0
var nb_actifs := 0
var arrosage_actif := false      # au moins une tete arrose

var _tetes: Array = []           # [{noeud, particles, ampoule, pos, delai, chrono, actif}]
var _feu_pos := Vector3.ZERO
var _feu_actif := false
var _plan_eau: MeshInstance3D = null


## Grille de tetes + plan d'eau + collision gouttes/sol.
func construire(racine: Node3D, x_min: float, x_max: float,
        z_min: float, z_max: float) -> void:
	var x := x_min + 4.0
	while x <= x_max - 3.0:
		var z := z_min + 3.0
		while z <= z_max - 2.0:
			_tetes.append(_cree_tete(racine, Vector3(x, HAUTEUR_TETE, z)))
			z += 12.0
		x += 12.0
	# Les gouttes disparaissent au contact du sol (collision particules,
	# pas physique) : une seule boite couvre le hall.
	var sol_col := GPUParticlesCollisionBox3D.new()
	sol_col.position = Vector3((x_min + x_max) / 2.0, -1.0,
		(z_min + z_max) / 2.0)
	sol_col.size = Vector3(x_max - x_min + 2.0, 2.0, z_max - z_min + 2.0)
	racine.add_child(sol_col)
	# Plan d'eau : translucide, plat, monte avec le niveau.
	var plan := PlaneMesh.new()
	plan.size = Vector2(x_max - x_min - 2.0, z_max - z_min - 2.0)
	plan.center_offset = Vector3((x_min + x_max) / 2.0, 0.0,
		(z_min + z_max) / 2.0)
	var mat_eau := StandardMaterial3D.new()
	mat_eau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_eau.albedo_color = Color(0.30, 0.55, 0.95, 0.42)
	mat_eau.roughness = 0.05
	mat_eau.metallic = 0.2
	plan.material = mat_eau
	_plan_eau = MeshInstance3D.new()
	_plan_eau.mesh = plan
	_plan_eau.visible = false
	racine.add_child(_plan_eau)


func set_arme(v: bool) -> void:
	arme = v


## Signale l'incendie (position + actif) au reseau : appele par la scene
## a chaque declenchement / coupure d'alarme.
func set_feu(pos: Vector3, actif: bool) -> void:
	_feu_pos = pos
	_feu_actif = actif


func _process(delta: float) -> void:
	if _tetes.is_empty():
		return
	var actifs := 0
	for tete in _tetes:
		# distance HORIZONTALE : la hauteur des tetes ne doit pas
		# fausser la detection au sol
		var dist_feu: float = Vector2(tete["pos"].x - _feu_pos.x,
			tete["pos"].z - _feu_pos.z).length()
		var cible: bool = arme and _feu_actif \
			and dist_feu <= RAYON_COUVERTURE
		if cible:
			tete["chrono"] += delta
		else:
			tete["chrono"] = 0.0
		# cascade : plus la tete est loin du feu, plus son ampoule met
		# de temps a eclater
		var ouvert: bool = cible \
			and tete["chrono"] >= dist_feu * DELAI_PAR_METRE
		if ouvert != tete["actif"]:
			tete["actif"] = ouvert
			tete["particles"].emitting = ouvert
			var mat_amp: StandardMaterial3D = tete["ampoule"].material_override
			mat_amp.emission = Color(0.3, 0.6, 1.0) if ouvert \
				else Color(1.0, 0.2, 0.1)
		if ouvert:
			actifs += 1
	nb_actifs = actifs
	arrosage_actif = actifs > 0
	if actifs > 0:
		niveau_eau = minf(niveau_eau + DEBIT_TETE * actifs * delta, NIVEAU_MAX)
	else:
		niveau_eau = maxf(niveau_eau - DRAINAGE * delta, 0.0)
	if _plan_eau != null:
		_plan_eau.visible = niveau_eau > 0.002
		if _plan_eau.visible:
			_plan_eau.position.y = 0.004 + niveau_eau


func _cree_tete(racine: Node3D, pos: Vector3) -> Dictionary:
	var noeud := Node3D.new()
	noeud.position = pos
	racine.add_child(noeud)
	# Bec : petit cylindre metal + ampoule thermique rouge (bleue quand
	# la tete est ouverte).
	var bec := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.05
	cyl.height = 0.16
	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.55, 0.56, 0.58)
	mat_metal.metallic = 0.8
	mat_metal.roughness = 0.4
	cyl.material = mat_metal
	bec.mesh = cyl
	bec.position = Vector3(0.0, 0.08, 0.0)
	noeud.add_child(bec)
	var ampoule := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	var mat_amp := StandardMaterial3D.new()
	mat_amp.albedo_color = Color(0.9, 0.1, 0.05)
	mat_amp.emission_enabled = true
	mat_amp.emission = Color(1.0, 0.2, 0.1)
	mat_amp.emission_energy_multiplier = 0.8
	ampoule.mesh = sphere
	ampoule.material_override = mat_amp   # override : lisible par _process
	ampoule.position = Vector3(0.0, -0.02, 0.0)
	noeud.add_child(ampoule)
	# Jet conique : vitesse initiale vers le bas + dispersion laterale,
	# chute gravitaire, gouttes fines translucides.
	var particles := GPUParticles3D.new()
	particles.amount = 350
	particles.lifetime = 0.9
	particles.one_shot = false
	particles.local_coords = true
	particles.emitting = false
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 40.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 10.0
	mat.gravity = Vector3(0.0, -9.8, 0.0)
	mat.scale_min = 0.35
	mat.scale_max = 0.8
	mat.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	particles.process_material = mat
	var goutte := QuadMesh.new()
	goutte.size = Vector2(0.05, 0.09)
	var mat_goutte := StandardMaterial3D.new()
	mat_goutte.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_goutte.albedo_color = Color(0.60, 0.80, 1.0, 0.50)
	mat_goutte.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat_goutte.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	goutte.material = mat_goutte
	particles.draw_pass_1 = goutte
	noeud.add_child(particles)
	return {"noeud": noeud, "particles": particles, "ampoule": ampoule,
		"pos": pos, "chrono": 0.0, "actif": false}
