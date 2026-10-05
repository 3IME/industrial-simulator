extends RefCounted
## Tests du reseau sprinklers (SprinklerManager) : selection des tetes,
## cascade, accumulation et drainage de l'eau. Logique pure, appelee
## manuellement via _process(delta) — aucun rendu necessaire.

const SprinklerManager = preload("res://scenes/sprinkler_manager.gd")


func run(t) -> void:
    t.begin_suite("sprinklers")

    var mgr = SprinklerManager.new()
    var racine := Node3D.new()
    mgr.construire(racine, -20.0, 20.0, -20.0, 20.0)

    # --- etat initial ---
    t.check(not mgr.arme, "reseau desarme par defaut")
    t.check_eq(mgr.nb_actifs, 0, "aucune tete active au repos")
    t.check_eq(mgr.niveau_eau, 0.0, "niveau d'eau nul au repos")

    # feu centre, reseau desarme : rien ne se passe
    mgr.set_feu(Vector3(0.0, 0.2, 0.0), true)
    mgr._process(0.1)
    mgr._process(0.1)
    t.check_eq(mgr.nb_actifs, 0, "desarme : le feu ne declenche rien")

    # --- armement : jet d'essai general, puis seules les tetes du feu ---
    mgr.set_arme(true)
    mgr._process(0.1)
    t.check_eq(mgr.nb_actifs, 9, "armement : test general, toutes les tetes ouvertes")
    var duree_test: float = mgr.DUREE_TEST
    for _i in range(int((duree_test + 1.0) / 0.1)):   # le test est termine
        mgr._process(0.1)
    t.check(mgr.nb_actifs >= 3, "seules les tetes pres du feu restent ouvertes (obtenu: %d)" % mgr.nb_actifs)
    t.check(mgr.nb_actifs <= 4, "pas plus que le disque de couverture (obtenu: %d)" % mgr.nb_actifs)
    t.check(mgr.arrosage_actif, "arrosage actif signale")

    # --- accumulation ---
    var niveau_avant: float = mgr.niveau_eau
    for _i in range(30):   # 3 s d'arrosage
        mgr._process(0.1)
    t.check(mgr.niveau_eau > niveau_avant, "le niveau monte pendant l'arrosage")
    t.check(mgr.niveau_eau > 0.01, "eau visible au sol (> 1 cm) apres 5 s")

    # --- bouchon : niveau plafonne ---
    for _i in range(5000):  # 500 s d'arrosage
        mgr._process(0.1)
    t.check_almost_eq(mgr.niveau_eau, mgr.NIVEAU_MAX, 0.0005,
        "niveau plafonne a NIVEAU_MAX")

    # --- feu eteint : les tetes se ferment, l'eau draine ---
    mgr.set_feu(Vector3.ZERO, false)
    mgr._process(0.1)
    mgr._process(0.1)
    t.check_eq(mgr.nb_actifs, 0, "plus de feu : toutes les tetes fermees")
    t.check(not mgr.arrosage_actif, "arrosage arrete")
    var garde_drain := 600   # max 60 s de drainage borne par DRAINAGE
    while mgr.niveau_eau > 0.02 and garde_drain > 0:
        mgr._process(0.1)
        garde_drain -= 1
    t.check(mgr.niveau_eau < 0.05, "le niveau redescend (drainage)")

    # --- rearmement sans feu : test bref puis silence ---
    mgr.set_arme(true)
    mgr._process(0.1)
    t.check(mgr.nb_actifs > 0, "armement sans feu : jet d'essai visible")
    for _i in range(int((mgr.DUREE_TEST + 1.0) / 0.1)):
        mgr._process(0.1)
    t.check_eq(mgr.nb_actifs, 0, "apres le test, sans feu : aucune tete ouverte")
    t.check(not mgr.arrosage_actif, "sans feu : pas d'arrosage prolonge")
