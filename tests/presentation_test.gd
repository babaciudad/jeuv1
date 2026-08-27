## Ce que le joueur VOIT : la crête, les props posés, le las, la caméra.
##
## Chaque test de cette suite est né d'un défaut mesuré par la chasse : une
## digue rendue à vingt-cinq centimètres au lieu de soixante-quinze, une porte
## de marée qui pendait en l'air, un râteau aux dents de quarante centimètres,
## une caméra sous le miroir de l'horizon.
extends GdUnitTestSuite

func test_la_crete_de_la_digue_garde_sa_pleine_largeur() -> void:
	# La moyenne des coins rabotait une demi-case de chaque côté : une crête de
	# trois cases n'en montrait qu'une. Le maximum la garde entière.
	var taille: Vector2i = Vector2i(7, 1)
	var hauteurs: PackedFloat32Array = PackedFloat32Array(
		[-1.10, -1.10, 0.45, 0.45, 0.45, 0.12, 0.12])
	# Les coins 2,3,4,5 touchent une case de talus : tous à pleine hauteur.
	for coin: int in [2, 3, 4, 5]:
		assert_float(VueMarais.hauteur_de_coin(hauteurs, taille, coin, 0)) \
			.override_failure_message("le coin %d rabote la crête" % coin) \
			.is_equal_approx(0.45, 0.0001)
	# La crête rendue va du coin 2 au coin 5 : trois cases pleines, 0,75 m.
	# Et loin de la crête, le fond reste le fond.
	assert_float(VueMarais.hauteur_de_coin(hauteurs, taille, 1, 0)) \
		.is_equal_approx(-1.10, 0.0001)

func test_aucun_prop_ne_flotte_ni_ne_coule() -> void:
	# Treize props sur cinquante-six étaient posés à « hauteur de talus » sans
	# regarder le sol : la porte de marée pendait à 1,53 m au-dessus du fond.
	var marais: Marais = Etier.batir()
	marais.maree(Etier.MAREE_HAUTE)
	var attirail: Attirail = Attirail.new()
	add_child(attirail)
	var _g: Variant = auto_free(attirail)
	attirail.garnir(marais)
	var fautifs: int = 0
	var pire: float = 0.0
	for enfant: Node in attirail.get_children():
		var objet: Node3D = enfant as Node3D
		if objet == null:
			continue
		var plan: Vector2 = Vector2(objet.position.x, objet.position.z)
		var sol: float = marais.hauteur_sol(plan)
		var ecart: float = objet.position.y - sol
		# Les cadres de vanne se posent sur le SEUIL de leur vanne : pour eux,
		# l'écart au sol local peut être la profondeur du chenal qu'ils
		# enjambent. On tolère donc l'écart d'un seuil de talus, jamais plus.
		if ecart > Reglages.HAUTEUR_TALUS + 1.2 or ecart < -0.30:
			fautifs += 1
			pire = maxf(pire, absf(ecart))
	prints("props hors sol :", fautifs, "— pire écart :", pire, "m")
	assert_int(fautifs).is_equal(0)

func test_le_las_fait_cinq_metres_et_garde_sa_tete() -> void:
	# Étirer tout le modèle donnait des dents de quarante centimètres. La tête
	# garde sa taille ; seul le manche s'allonge.
	var paquet: PackedScene = load(VueActeur.LAS) as PackedScene
	assert_object(paquet).is_not_null()
	var outil: Node3D = paquet.instantiate() as Node3D
	add_child(outil)
	var _g: Variant = auto_free(outil)
	VueActeur._allonger_le_manche(outil)
	var instance: MeshInstance3D = VueActeur._premier_maillage(outil)
	assert_object(instance).is_not_null()
	var boite: AABB = instance.mesh.get_aabb()
	prints("las opéré :", boite.size, "— prise à", -boite.position.y, "m du bout")
	assert_float(boite.size.y).is_equal_approx(VueActeur.LONGUEUR_LAS, 0.05)
	# La tête n'a pas grandi : sa largeur d'origine était de 0,71 m.
	assert_float(boite.size.x).is_between(0.65, 0.78)

func test_la_camera_ne_passe_ni_sous_le_sol_ni_sous_l_horizon() -> void:
	var marais: Marais = Etier.batir()
	marais.maree(Etier.MAREE_HAUTE)
	var rig: CameraRig = CameraRig.new()
	add_child(rig)
	var _g: Variant = auto_free(rig)
	rig.regarder(marais)
	rig.plancher_hors_grille = Etier.MAREE_HAUTE - 0.01 + CameraRig.GARDE_EAU
	# Piquée vers le bas depuis la marqueterie : la caméra recule vers un talus.
	rig.tangage = CameraRig.TANGAGE_MAX
	rig.lacet = 0.0
	rig.cadrer(Vector3(Etier.OEILLET_DU_SEL.x, 0.04, Etier.OEILLET_DU_SEL.y), 1.0)
	var oeil: Node3D = rig.get_node(NodePath("Oeil")) as Node3D
	var plan: Vector2 = Vector2(oeil.global_position.x, oeil.global_position.z)
	var sol_max: float = marais.hauteur_sol(plan)
	for autour: Vector2 in [Vector2(0.3, 0), Vector2(-0.3, 0),
			Vector2(0, 0.3), Vector2(0, -0.3)]:
		sol_max = maxf(sol_max, marais.hauteur_sol(plan + autour))
	prints("œil :", oeil.global_position.y, "— sol voisin max :", sol_max)
	assert_float(oeil.global_position.y).is_greater_equal(sol_max + 0.30)
	# Et au-delà du bord du niveau, jamais sous le miroir de l'horizon.
	rig.cadrer(Vector3(62.0, 0.45, 42.0), 1.0)
	prints("œil hors grille :", oeil.global_position.y)
	assert_float(oeil.global_position.y).is_greater_equal(Etier.MAREE_HAUTE + 0.20)

func test_les_gestes_du_metier_ont_leur_clip() -> void:
	# Les clips étaient chargés dans le rig et jamais joués : on ouvrait une
	# vanne sans bouger un doigt, et le cristallisé apparaissait debout.
	for nom: StringName in [&"vanne", &"cueillette", &"levee"]:
		assert_bool(Animateur.TRAVAUX.has(nom)).override_failure_message(
			"le geste %s n'a pas de clip câblé" % nom).is_true()
	# Et la mort demande une entrée qui EXISTE : « state_1 », pas « 1 » —
	# la requête « 1 » était ignorée avec une erreur console, et le joueur
	# mourait debout en pose d'attente.
	var source: String = FileAccess.get_file_as_string(
		"res://src/presentation/animation/animateur.gd")
	assert_bool(source.contains("\"state_1\"")).is_true()
	assert_bool(source.contains("transition_request\", &\"1\"")).is_false()

func test_le_travail_immobilise_le_temps_du_geste() -> void:
	var monde: Monde = Monde.new()
	monde.marais = Etier.batir()
	monde.marais.maree(Etier.MAREE_HAUTE)
	monde.ladure = Etier.DEPART
	var joueur: Acteur = Acteur.new()
	joueur.camp = Acteur.Camp.PALUDIER
	joueur.position = Etier.PORTE_DE_MAREE
	var _a: Acteur = monde.ajouter(joueur)
	var simulation: Simulation = Simulation.new()
	var c: Commande = Commande.new()
	c.interagit = true
	var commandes: Dictionary[int, Commande] = {}
	commandes[joueur.id] = c
	simulation.avancer(monde, commandes)
	assert_int(joueur.etat).is_equal(Acteur.Etat.TRAVAIL)
	assert_str(String(joueur.geste)).is_equal("vanne")
	var ou: Vector2 = joueur.position
	# Il pousse de toutes ses forces pendant le geste : il ne bouge pas.
	var marche: Commande = Commande.new()
	marche.direction = Vector2(0.0, 1.0)
	commandes[joueur.id] = marche
	for _i: int in range(Reglages.TICKS_TRAVAIL_VANNE - 2):
		simulation.avancer(monde, commandes)
	assert_float(joueur.position.distance_to(ou)).is_less(0.05)
	for _i: int in range(6):
		simulation.avancer(monde, commandes)
	assert_int(joueur.etat).is_equal(Acteur.Etat.LIBRE)
