# -*- coding: utf-8 -*-
"""Etape 1 du ZAI_PROMPT.md : extraction des assets Factory-IO (export
Unity/AssetRipper) vers le projet Godot.

- source OBJ   : D:/Bidon 4/Assets Factory/SAV/Mesh (370, sans .mtl)
- source Unity : D:/Bidon 4/Assets Factory/ExportedProject/Assets
  (Mesh/*.asset + .meta, Material/*.mat, Texture2D/*.png, GameObject/*.prefab)
- destination  : Factory IO/assets/imported/ (prefixe FIO_)

Produit :
  FIO_<obj>.obj           copie de l'OBJ source
  FIO_<obj>.mtl           materiau Wavefront (map_Kd + map_bump)
  FIO_<tex>.png           textures (albedo, normale)
  FIO_<obj>.tres          StandardMaterial3D Godot (pour l'etape 2)
  manifest.json           nom, type, chemins, statut
"""
import json
import os
import re
import shutil
import sys

SRC_UNITY = r"D:\Bidon 4\Assets Factory\ExportedProject\Assets"
SRC_OBJ = r"D:\Bidon 4\Assets Factory\SAV\Mesh"
DST = r"D:\Bidon 4\Factory IO\simulator\assets\imported"

RE_GUID = re.compile(r"guid: ([0-9a-f]{32})")
RE_TEX = re.compile(
    r"(_\w+):\s*\n\s*m_Texture: \{fileID: \d+, guid: ([0-9a-f]{32})")
RE_MTL = re.compile(
    r"guid: ([0-9a-f]{32}), type: 2")


def index_guids(racine):
    """guid -> chemin relatif dans ExportedProject/Assets."""
    index = {}
    for dossier, _, fichiers in os.walk(racine):
        for nom in fichiers:
            if not nom.endswith(".meta"):
                continue
            chemin = os.path.join(dossier, nom)
            try:
                with open(chemin, encoding="utf-8", errors="ignore") as f:
                    m = RE_GUID.search(f.read(400))
                if m:
                    index[m.group(1)] = os.path.relpath(chemin[:-5], racine)
            except OSError:
                pass
    return index


def yaml_map(mats):
    """Charge un .mat et retourne {slot: guid_texture}."""
    slots = {}
    try:
        with open(mats, encoding="utf-8", errors="ignore") as f:
            texte = f.read()
    except OSError:
        return slots
    for slot, guid in RE_TEX.findall(texte):
        slots.setdefault(slot, guid)
    return slots


def lier_mesh_materiaux(guids, index):
    """Parcourt les .prefab : mesh_guid -> [material_guid] (ordre des
    sous-meshes). Complété par tous les prefabs (dernier vu gagne)."""
    liaisons = {}
    dossier_go = os.path.join(SRC_UNITY, "GameObject")
    for nom in os.listdir(dossier_go):
        if not nom.endswith(".prefab"):
            continue
        try:
            with open(os.path.join(dossier_go, nom),
                      encoding="utf-8", errors="ignore") as f:
                texte = f.read()
        except OSError:
            continue
        # blocs MeshFilter : m_Mesh {guid}, le composant porte
        # m_GameObject {fileID} ; blocs MeshRenderer : m_Materials guids
        # -> approximation robuste : associer chaque mesh du prefab aux
        #    materiaux du prefab (les SAV OBJ sont des sous-meshes d'un
        #    meme modele, l'ordre des materiaux suit les sous-meshes)
        meshes = RE_GUID.findall(texte[:0])  # vide : voir ci-dessous
        # extraction structuree minimale : lignes m_Mesh / m_Materials
        mesh_gu = []
        for m in re.finditer(
                r"m_Mesh: \{fileID: \d+, guid: ([0-9a-f]{32})", texte):
            mesh_gu.append(m.group(1))
        mat_gu = []
        for bloc in re.finditer(r"m_Materials:(.*?)(?:\n  [A-Z]|\Z)",
                                texte, re.S):
            mat_gu += RE_MTL.findall(bloc.group(1))
        for i, mg in enumerate(mesh_gu):
            liaisons[mg] = mat_gu  # liste complete ; le rang _subN choisira
    return liaisons


def nom_meshDepuisIndex():
    """mesh_guid -> nom du mesh (basename sans extension)."""
    noms = {}
    dossier = os.path.join(SRC_UNITY, "Mesh")
    for nom in os.listdir(dossier):
        if nom.endswith(".asset.meta"):
            with open(os.path.join(dossier, nom),
                      encoding="utf-8", errors="ignore") as f:
                m = RE_GUID.search(f.read(400))
            if m:
                noms[m.group(1)] = nom[:-len(".asset.meta")]
    return noms


def main():
    os.makedirs(DST, exist_ok=True)
    print("Indexation des GUID (.meta)...")
    index = index_guids(SRC_UNITY)
    print(" ", len(index), "GUID")
    print("Liaisons prefab mesh->materiaux...")
    liaisons = lier_mesh_materiaux(index, {})
    noms_mesh = nom_meshDepuisIndex()
    guid_par_nom_mesh = {v: k for k, v in noms_mesh.items()}

    # materiaux en cache : guid_mat -> {albedo, normale, nom}
    cache_mat = {}
    manifest = []
    textures_copiees = set()
    stats = {"obj": 0, "texturés": 0, "vierges": 0, "sans_materiau": 0}

    objs = sorted(f for f in os.listdir(SRC_OBJ) if f.endswith(".obj"))
    for nom_obj in objs:
        base = nom_obj[:-4]
        # "<Model>__<Mesh>[_subN]"
        m = re.match(r"(.+?)__(.+?)(?:_sub(\d+))?$", base)
        if not m:
            continue
        mesh_nom = m.group(2)
        rang_sub = int(m.group(3) or 0)
        guid_mesh = guid_par_nom_mesh.get(mesh_nom)
        mat_gu = liaisons.get(guid_mesh, []) if guid_mesh else []
        guid_mat = mat_gu[rang_sub] if rang_sub < len(mat_gu) else (
            mat_gu[0] if mat_gu else None)

        # copie de l'OBJ
        shutil.copy2(os.path.join(SRC_OBJ, nom_obj),
                     os.path.join(DST, "FIO_" + base + ".obj"))
        stats["obj"] += 1

        entree = {"nom": base, "type": "mesh",
                  "obj": "assets/imported/FIO_" + base + ".obj"}
        if not guid_mat or guid_mat not in index:
            entree["statut"] = "sans_materiau"
            stats["sans_materiau"] += 1
            manifest.append(entree)
            continue

        # materiau (cache)
        if guid_mat not in cache_mat:
            chemin_mat = os.path.join(SRC_UNITY, index[guid_mat])
            slots = yaml_map(chemin_mat)
            albedo = slots.get("_MainTex")
            normale = slots.get("_BumpMap")
            cache_mat[guid_mat] = {
                "nom": os.path.splitext(os.path.basename(chemin_mat))[0],
                "albedo": index.get(albedo) if albedo else None,
                "normale": index.get(normale) if normale else None,
            }
        mat = cache_mat[guid_mat]
        tex_alb = None
        tex_nrm = None
        for slot, chemin in (("_albedo", mat["albedo"]),
                             ("_normale", mat["normale"])):
            if chemin and chemin.lower().endswith(".png"):
                dest = "FIO_" + os.path.splitext(
                    os.path.basename(chemin))[0].replace(" ", "_") + ".png"
                if dest not in textures_copiees:
                    shutil.copy2(os.path.join(SRC_UNITY, chemin),
                                 os.path.join(DST, dest))
                    textures_copiees.add(dest)
                if slot == "_albedo":
                    tex_alb = dest
                else:
                    tex_nrm = dest
        if tex_alb is None:
            entree["statut"] = "vierge (materiau sans texture)"
            stats["vierges"] += 1
            manifest.append(entree)
            continue

        # .tres StandardMaterial3D (etape 2 : applique a l'instanciation)
        nom_tres = "FIO_" + base + ".tres"
        etapes = 2 if tex_nrm else 1
        lignes = ['[gd_resource type="StandardMaterial3D" '
                  'load_steps=%d format=3]' % (etapes + 1), '']
        lignes.append('[ext_resource type="Texture2D" '
                      'path="res://assets/imported/%s" id="1"]' % tex_alb)
        if tex_nrm:
            lignes.append('[ext_resource type="Texture2D" '
                          'path="res://assets/imported/%s" id="2"]' % tex_nrm)
        lignes.append('')
        lignes.append('[resource]')
        lignes.append('resource_name = "FIO %s"' % mat["nom"])
        lignes.append('albedo_texture = ExtResource("1")')
        if tex_nrm:
            lignes.append('normal_enabled = true')
            lignes.append('normal_texture = ExtResource("2")')
        with open(os.path.join(DST, nom_tres), "w", encoding="utf-8",
                  newline="\n") as f:
            f.write("\n".join(lignes) + "\n")
        entree.update({
            "statut": "texturé",
            "materiau": mat["nom"],
            "albedo": "assets/imported/" + tex_alb,
            "normale": "assets/imported/" + tex_nrm if tex_nrm else None,
            "tres": "assets/imported/" + nom_tres,
        })
        stats["texturés"] += 1
        manifest.append(entree)

    with open(os.path.join(DST, "manifest.json"), "w",
              encoding="utf-8") as f:
        json.dump({"stats": stats, "assets": manifest}, f,
                  ensure_ascii=False, indent=1)
    print("Manifeste :", stats)


if __name__ == "__main__":
    sys.exit(main())
