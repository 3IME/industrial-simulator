import bpy
import math
from mathutils import Vector

# ============================================================
# BOUTON D'ALARME INCENDIE - V2
# Modèle 3D plus fidèle à la photo fournie
#
# Dimensions approximatives : 120 x 120 x 42 mm
# Orientation :
#   X = largeur
#   Y = profondeur (avant = -Y)
#   Z = hauteur
#
# Le modèle est pensé pour Godot :
# - géométrie raisonnablement légère
# - détails importants en relief
# - matériaux simples
# - export GLB automatique
# ============================================================

# ---------------- PARAMÈTRES ----------------
W = 0.120
H = 0.120
D = 0.042

OUTPUT = bpy.path.abspath("//bouton_alarme_incendie_V2.glb")

# Dimensions des éléments de façade
FRONT_MARGIN = 0.006
PANEL_W = 0.083
PANEL_H = 0.047
PANEL_Z = 0.0685

BUTTON_Z = 0.0695

# ---------------- MATÉRIAUX ----------------
def make_mat(name, color, roughness=0.4, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = color
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    return m

RED = make_mat("Plastique rouge", (0.63, 0.012, 0.018, 1), 0.32)
RED_LIGHT = make_mat("Rouge façade", (0.78, 0.018, 0.025, 1), 0.34)
RED_DARK = make_mat("Rouge intérieur", (0.35, 0.006, 0.009, 1), 0.40)
RED_HIGHLIGHT = make_mat("Rouge rebord", (0.86, 0.025, 0.030, 1), 0.28)
WHITE = make_mat("Blanc panneau", (0.92, 0.91, 0.87, 1), 0.52)
BLACK = make_mat("Noir impression", (0.008, 0.008, 0.007, 1), 0.48)
WHITE_PLASTIC = make_mat("Blanc pictogramme", (0.95, 0.95, 0.91, 1), 0.38)
GLASS = make_mat("Plastique transparent", (0.75, 0.85, 0.82, 1), 0.20)
GLASS.node_tree.nodes["Principled BSDF"].inputs["Transmission Weight"].default_value = 0.15


# ---------------- OUTILS ----------------
def bevel(obj, width, segments=3):
    mod = obj.modifiers.new("Arrondis", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def cube(name, loc, dims, mat, bevel_width=0.0, segments=3):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        o.data.materials.append(mat)
    if bevel_width:
        bevel(o, bevel_width, segments)
    return o


def cyl(name, loc, radius, depth, mat, rot=(math.pi/2, 0, 0),
        vertices=32, bevel_width=0.0):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=loc,
        rotation=rot
    )
    o = bpy.context.object
    o.name = name
    if mat:
        o.data.materials.append(mat)
    if bevel_width:
        bevel(o, bevel_width, 2)
    return o


def text(name, body, loc, size, mat, extrude=0.00012,
         align="CENTER", font_bold=False):
    bpy.ops.object.text_add(
        location=loc,
        rotation=(math.pi/2, 0, 0)
    )
    o = bpy.context.object
    o.name = name
    o.data.body = body
    o.data.align_x = align
    o.data.align_y = "CENTER"
    o.data.size = size
    o.data.extrude = extrude
    o.data.bevel_depth = 0.000025
    o.data.space_character = 1.0
    o.data.materials.append(mat)
    return o


def make_poly(name, verts, mat, face=(0,1,2)):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], [face])
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def arrow(name, x, z, direction):
    # Triangle frontal très proche de la photo
    y = -D/2 - 0.0040
    w = 0.014
    h = 0.010

    if direction == "right":
        pts = [
            (x-w/2, y, z-h/2),
            (x-w/2, y, z+h/2),
            (x+w/2, y, z),
        ]
    else:
        pts = [
            (x+w/2, y, z-h/2),
            (x+w/2, y, z+h/2),
            (x-w/2, y, z),
        ]

    return make_poly(name, pts, BLACK)


# ---------------- NETTOYAGE ----------------
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


# ============================================================
# 1. CORPS PRINCIPAL
# ============================================================
body = cube(
    "01_Boitier_principal",
    (0, 0, H/2),
    (W, D, H),
    RED,
    bevel_width=0.0065,
    segments=5
)

# Très légère coque frontale : elle donne le bombé visible sur la photo.
front_shell = cube(
    "02_Coque_facade",
    (0, -D/2 - 0.0017, H/2),
    (W-0.009, 0.0040, H-0.010),
    RED_LIGHT,
    bevel_width=0.005,
    segments=4
)

# Rebord intérieur / ligne de séparation sur la façade.
inner_face = cube(
    "03_Face_interieure",
    (0, -D/2 - 0.0035, H/2),
    (W-0.015, 0.0022, H-0.020),
    RED,
    bevel_width=0.004,
    segments=3
)


# ============================================================
# 2. PANNEAU BLANC ENCASTRÉ
# ============================================================
# Ouverture sombre légèrement plus grande.
recess = cube(
    "10_Encadrement_fonce",
    (0, -D/2 - 0.0050, PANEL_Z),
    (PANEL_W+0.006, 0.0022, PANEL_H+0.006),
    RED_DARK,
    bevel_width=0.0018,
    segments=2
)

# Petit rebord rouge autour du panneau.
bezel = cube(
    "11_Rebord_panneau",
    (0, -D/2 - 0.0062, PANEL_Z),
    (PANEL_W+0.0025, 0.0020, PANEL_H+0.0025),
    RED_HIGHLIGHT,
    bevel_width=0.0012,
    segments=2
)

# Surface blanche légèrement en retrait.
panel = cube(
    "12_Panneau_blanc",
    (0, -D/2 - 0.0072, PANEL_Z),
    (PANEL_W, 0.0015, PANEL_H),
    WHITE,
    bevel_width=0.0014,
    segments=2
)

# Plaque transparente très fine : effet vitre/plastique.
cover = cube(
    "13_Vitre_panneau",
    (0, -D/2 - 0.0081, PANEL_Z),
    (PANEL_W-0.001, 0.00045, PANEL_H-0.001),
    GLASS,
    bevel_width=0.0007,
    segments=2
)


# ============================================================
# 3. TEXTE ET SYMBOLES
# ============================================================
Y = -D/2 - 0.0088

text(
    "20_Texte_alarme",
    "ALARME INCENDIE",
    (0, Y, 0.0842),
    0.0068,
    BLACK,
    extrude=0.00008
)

# Bouton central noir légèrement bombé.
cyl(
    "21_Bouton_central",
    (0, Y-0.0003, BUTTON_Z),
    0.0072,
    0.0025,
    BLACK,
    vertices=48,
    bevel_width=0.00045
)

# Petit anneau autour du bouton pour donner le relief de la pièce.
cyl(
    "22_Anneau_bouton",
    (0, Y+0.00015, BUTTON_Z),
    0.0090,
    0.0007,
    RED_DARK,
    vertices=48,
    bevel_width=0.00025
)

# Remettre le bouton par-dessus l'anneau.
cyl(
    "23_Bouton_surface",
    (0, Y-0.00035, BUTTON_Z),
    0.00715,
    0.0027,
    BLACK,
    vertices=48,
    bevel_width=0.00055
)

arrow("24_Fleche_gauche", -0.0215, BUTTON_Z, "right")
arrow("25_Fleche_droite", 0.0215, BUTTON_Z, "left")

text(
    "26_Texte_appuyez",
    "APPUYEZ ICI",
    (0, Y, 0.0572),
    0.0050,
    BLACK,
    extrude=0.00007
)

text(
    "27_Texte_necessite",
    "EN CAS DE NECESSITE",
    (0, Y, 0.0504),
    0.00415,
    BLACK,
    extrude=0.00006
)


# ============================================================
# 4. PARTIE SUPÉRIEURE : PLAQUE + PICTOGRAMME
# ============================================================
icon_z = 0.1015

icon_recess = cube(
    "30_Recess_pictogramme",
    (0, -D/2 - 0.0048, icon_z),
    (0.043, 0.0020, 0.022),
    RED_DARK,
    bevel_width=0.0012,
    segments=2
)

# Contour de maison blanc.
y = -D/2 - 0.0062
x0 = -0.009
x1 = 0.009
z0 = 0.0962
z1 = 0.1080
zr = 0.1035

curve = bpy.data.curves.new("31_Contour_maison_curve", "CURVE")
curve.dimensions = "3D"
curve.bevel_depth = 0.00085
curve.bevel_resolution = 1

poly = curve.splines.new("POLY")
pts = [
    (x0, y, z0),
    (x0, y, zr),
    (0,  y, z1),
    (x1, y, zr),
    (x1, y, z0),
]
poly.points.add(len(pts)-1)

for p, co in zip(poly.points, pts):
    p.co = (*co, 1)

poly.use_cyclic_u = False

house = bpy.data.objects.new("31_Pictogramme_maison", curve)
bpy.context.collection.objects.link(house)
house.data.materials.append(WHITE_PLASTIC)

# Petite flamme stylisée composée de deux gouttes/courbes.
# Elle n'est pas une reproduction exacte du logo : c'est un détail 3D
# approximatif pour conserver un modèle léger.
flame_outer = text(
    "32_Pictogramme_flamme",
    "♠",
    (0, y-0.0002, 0.1005),
    0.0105,
    WHITE_PLASTIC,
    extrude=0.00008
)


# ============================================================
# 5. LOGO INFÉRIEUR
# ============================================================
# Bloc blanc discret + nom de marque approximatif.
logo_x = -0.047
logo_y = -D/2 - 0.0088

cube(
    "40_Bloc_logo",
    (logo_x, logo_y+0.0001, 0.0185),
    (0.008, 0.0010, 0.0075),
    WHITE_PLASTIC,
    bevel_width=0.00025,
    segments=1
)

text(
    "41_Logo_Nugelec",
    "NUGELEC",
    (logo_x+0.006, logo_y, 0.0185),
    0.0037,
    WHITE_PLASTIC,
    align="LEFT",
    extrude=0.00006
)


# ============================================================
# 6. DÉTAILS DU BOÎTIER
# ============================================================
# Ligne de joint supérieure.
cube(
    "50_Joint_superieur",
    (0, -D/2 - 0.0027, H-0.010),
    (W-0.018, 0.0010, 0.0013),
    RED_DARK,
    bevel_width=0.00035,
    segments=1
)

# Petites lignes verticales latérales suggérant les jonctions du plastique.
for x in (-W/2 + 0.006, W/2 - 0.006):
    cube(
        "51_Joint_lateral",
        (x, -D/2 - 0.0028, H/2),
        (0.0010, 0.0008, H-0.030),
        RED_DARK,
        bevel_width=0.00025,
        segments=1
    )

# Deux petites vis/points de fixation inférieurs, très discrets.
for x in (-0.050, 0.050):
    cyl(
        "52_Detail_fixation",
        (x, -D/2 - 0.0042, 0.0062),
        0.00115,
        0.0007,
        RED_DARK,
        vertices=16
    )


# ============================================================
# 7. SUPPORT ARRIÈRE LÉGÈREMENT VISIBLE
# ============================================================
# Une petite extension arrière donne de la profondeur si l'objet est vu de côté.
rear = cube(
    "60_Coque_arriere",
    (0, D/2 - 0.002, H/2),
    (W-0.012, 0.005, H-0.012),
    RED,
    bevel_width=0.004,
    segments=3
)


# ============================================================
# 8. ORGANISATION
# ============================================================
# Créer une collection dédiée.
if "ALARME_INCENDIE_V2" in bpy.data.collections:
    collection = bpy.data.collections["ALARME_INCENDIE_V2"]
else:
    collection = bpy.data.collections.new("ALARME_INCENDIE_V2")
    bpy.context.scene.collection.children.link(collection)

# Déplacer les objets de la scène dans la collection.
for obj in list(bpy.context.scene.objects):
    if obj.name not in collection.objects:
        # Un objet peut être dans plusieurs collections ; on le relie à la nouvelle.
        collection.objects.link(obj)


# ============================================================
# 9. ORIGINE DU MODÈLE
# ============================================================
# Origine globale : centre au niveau du sol.
# Le boîtier va de Z=0 à Z=H.


# ============================================================
# 10. EXPORT GLB
# ============================================================
bpy.ops.object.select_all(action="SELECT")

bpy.ops.export_scene.gltf(
    filepath=OUTPUT,
    export_format="GLB",
    use_selection=True,
    export_apply=True
)

print("")
print("================================================")
print(" ALARME INCENDIE V2")
print(" GLB créé :")
print(OUTPUT)
print("================================================")
