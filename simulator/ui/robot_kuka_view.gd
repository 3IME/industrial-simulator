extends Node3D
## Vue 3D du bras robot 6 axes : hierarchie articulaire sur les pieces STL
## converties (assembly coordinates conservees - cf. assets/kuka/).
## Le rendu ne fait que LIRE les angles de la machine logique (ADR-013).
##
## Hierarchie (pivots deduits des articulations du modele, en metres) :
##   base (statique)
##   A1 : lacisage (axe Y)   -> colonne + tout ce qui est au-dessus
##   A2 : epaule (axe Z)     -> bras superieur
##   A3 : coude (axe Z)      -> avant-bras
##   A4 : roulis avant-bras (axe X)
##   A5 : poignet (axe Z)
##   A6 : pince/bride (axe X)

const PART_BASE := "res://assets/kuka/01_base.glb"
const PART_COLUMN := "res://assets/kuka/02_2nd_axis.glb"
const PART_ARM := "res://assets/kuka/03_first_arm.glb"
const PART_FOREARM_JOINT := "res://assets/kuka/04_second_arm.glb"
const PART_FOREARM_COVER := "res://assets/kuka/05_second_arm_cover.glb"
const PART_HEAD := "res://assets/kuka/06_head.glb"
const PART_TOOL := "res://assets/kuka/07_tool_base.glb"

# Pivots (metres, repere d'assemblage : base au sol, bras tendu vers +X)
const P_A1 := Vector3(0.043, 0.0, -0.037)
const P_A2 := Vector3(0.06, 0.38, -0.04)
const P_A3 := Vector3(0.13, 0.95, -0.03)
const P_A4 := Vector3(0.13, 0.97, -0.03)
const P_A5 := Vector3(0.54, 0.985, -0.03)
const P_A6 := Vector3(0.63, 0.985, -0.03)

static func heavy_resources() -> Array:
    return [PART_BASE, PART_COLUMN, PART_ARM, PART_FOREARM_JOINT,
            PART_FOREARM_COVER, PART_HEAD, PART_TOOL]


var machine = null    # RobotKuka (logique)
var joints: Array = []


func setup(p_machine) -> void:
    machine = p_machine


func _ready() -> void:
    _build()


func _build() -> void:
    # Materiau "KUKA" : gris metal + details orange
    var orange := StandardMaterial3D.new()
    orange.albedo_color = Color(0.95, 0.42, 0.05)
    orange.metallic = 0.4
    orange.roughness = 0.45
    var grey := StandardMaterial3D.new()
    grey.albedo_color = Color(0.35, 0.36, 0.38)
    grey.metallic = 0.7
    grey.roughness = 0.35

    # Piece statique : base
    _add_part(PART_BASE, grey)

    # A1 : lacisage (axe Y)
    var j1 := _joint(P_A1, P_A1, Vector3.UP)
    _add_part(PART_COLUMN, orange, j1)
    # A2 : epaule (axe Z)
    var j2 := _joint(P_A2 - P_A1, P_A2, Vector3.FORWARD, j1)
    _add_part(PART_ARM, orange, j2)
    # A3 + A4 : coude et roulis de l'avant-bras
    var j3 := _joint(P_A3 - P_A2, P_A3, Vector3.FORWARD, j2)
    var j4 := _joint(P_A4 - P_A3, P_A4, Vector3.RIGHT, j3)
    _add_part(PART_FOREARM_JOINT, grey, j4)
    _add_part(PART_FOREARM_COVER, orange, j4)
    # A5 : poignet ; A6 : bride outil
    var j5 := _joint(P_A5 - P_A4, P_A5, Vector3.FORWARD, j4)
    _add_part(PART_HEAD, grey, j5)
    var j6 := _joint(P_A6 - P_A5, P_A6, Vector3.RIGHT, j5)
    _add_part(PART_TOOL, grey, j6)

    joints = [j1, j2, j3, j4, j5, j6]


## offset = position RELATIVE au parent (composition FK) ;
## pivot_absolu = position du pivot dans le repere d'ASSEMBLAGE.
## Le contre-noeud doit annuler le pivot ABSOLU pour que les pieces,
## posees a leurs coordonnees d'assemblage, retombent a leur place :
## annuler l'offset relatif laisserait le repere a P_(i-1), pas a l'origine.
func _joint(offset: Vector3, pivot_absolu: Vector3, axis: Vector3, parent: Node = null) -> Node3D:
    var joint := Node3D.new()
    joint.position = offset
    joint.rotation = Vector3.ZERO
    if parent == null:
        add_child(joint)
    else:
        parent.add_child(joint)
    var counter := Node3D.new()
    counter.position = -pivot_absolu
    joint.add_child(counter)
    joint.set_meta("counter", counter)
    joint.set_meta("axis", axis)
    return joint


func _add_part(path: String, material: StandardMaterial3D, joint: Node = null) -> void:
    var scene = load(path)
    if scene == null:
        push_warning("piece robot absente : " + path)
        return
    var part = scene.instantiate()
    var counter: Node3D = joint.get_meta("counter") if joint != null else null
    if counter != null:
        counter.add_child(part)
    else:
        add_child(part)
    for mesh in part.find_children("*", "MeshInstance3D", true, false):
        mesh.material_override = material



func _process(_delta: float) -> void:
    if machine == null:
        return
    var angles: Array = machine.angles_deg
    for i in range(joints.size()):
        if i >= angles.size():
            break
        var joint: Node3D = joints[i]
        var axis: Vector3 = joint.get_meta("axis")
        joint.rotation = axis * deg_to_rad(float(angles[i]))

