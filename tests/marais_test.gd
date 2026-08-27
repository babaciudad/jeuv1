## L'hydraulique du marais : ce que le lore affirme doit être mesurable.
extends GdUnitTestSuite

func _marais_a_deux_bassins(fond_amont: float, fond_aval: float) -> Marais:
	var marais: Marais = Marais.new()
	marais.preparer(Vector2.ZERO, Vector2(20.0, 10.0), 1.0)
	var haut: PackedVector2Array = PackedVector2Array([
		Vector2(1, 1), Vector2(8, 1), Vector2(8, 9), Vector2(1, 9)])
	var bas: PackedVector2Array = PackedVector2Array([
		Vector2(12, 1), Vector2(19, 1), Vector2(19, 9), Vector2(12, 9)])
	var a: int = marais.creuser(&"amont", haut, fond_amont, 0.30, 0.10)
	var b: int = marais.creuser(&"aval", bas, fond_aval, 0.02, 0.02)
	var _v: int = marais.relier(&"vanne", a, b, Vector2(10, 5), false)
	return marais

func test_une_vanne_fermee_ne_laisse_rien_passer() -> void:
	var marais: Marais = _marais_a_deux_bassins(0.30, 0.00)
	var avant: float = marais.bassins[1].volume
	for _i: int in range(600):
		marais.ecouler(Reglages.DUREE_TICK)
	assert_float(marais.bassins[1].volume).is_equal_approx(avant, 0.0001)

func test_l_eau_descend_de_l_amont_vers_l_aval() -> void:
	var marais: Marais = _marais_a_deux_bassins(0.30, 0.00)
	marais.vannes[0].ouverte = true
	var amont_avant: float = marais.bassins[0].volume
	var aval_avant: float = marais.bassins[1].volume
	for _i: int in range(600):
		marais.ecouler(Reglages.DUREE_TICK)
	assert_float(marais.bassins[0].volume).is_less(amont_avant)
	assert_float(marais.bassins[1].volume).is_greater(aval_avant)

func test_rien_ne_remonte_jamais() -> void:
	# L'aval est plein, l'amont presque vide : malgré la vanne ouverte, le
	# niveau de l'amont ne doit pas monter d'un millimètre.
	var marais: Marais = Marais.new()
	marais.preparer(Vector2.ZERO, Vector2(20.0, 10.0), 1.0)
	var haut: PackedVector2Array = PackedVector2Array([
		Vector2(1, 1), Vector2(8, 1), Vector2(8, 9), Vector2(1, 9)])
	var bas: PackedVector2Array = PackedVector2Array([
		Vector2(12, 1), Vector2(19, 1), Vector2(19, 9), Vector2(12, 9)])
	var a: int = marais.creuser(&"amont", haut, 0.30, 0.01, 0.1)
	var b: int = marais.creuser(&"aval", bas, 0.00, 0.28, 0.1)
	var _v: int = marais.relier(&"vanne", a, b, Vector2(10, 5), true)
	var niveau_avant: float = marais.bassins[0].niveau()
	for _i: int in range(600):
		marais.ecouler(Reglages.DUREE_TICK)
	assert_float(marais.bassins[0].niveau()).is_less_equal(niveau_avant + 0.0001)

func test_le_volume_total_se_conserve() -> void:
	var marais: Marais = _marais_a_deux_bassins(0.30, 0.00)
	marais.vannes[0].ouverte = true
	var total_avant: float = marais.bassins[0].volume + marais.bassins[1].volume
	for _i: int in range(1200):
		marais.ecouler(Reglages.DUREE_TICK)
	var total_apres: float = marais.bassins[0].volume + marais.bassins[1].volume
	assert_float(total_apres).is_equal_approx(total_avant, 0.001)

func test_l_ecoulement_converge_et_n_oscille_pas() -> void:
	# Deux bassins de fonds égaux et de niveaux différents doivent s'égaliser
	# sans jamais se dépasser : un pas de temps trop grand ferait osciller.
	var marais: Marais = _marais_a_deux_bassins(0.00, 0.00)
	marais.vannes[0].ouverte = true
	# Trente secondes de jeu : c'est la promesse faite au joueur qui ouvre une
	# vanne. Le dépassement est vérifié à chaque tick, l'égalisation à la fin.
	for _i: int in range(30 * Reglages.TICKS_PAR_SECONDE):
		marais.ecouler(Reglages.DUREE_TICK)
		assert_float(marais.bassins[0].niveau()) \
			.is_greater_equal(marais.bassins[1].niveau() - 0.001)
	var ecart: float = absf(marais.bassins[0].niveau() - marais.bassins[1].niveau())
	assert_float(ecart).is_less(0.01)

func test_l_evaporation_concentre_le_sel() -> void:
	# Le sel ne s'évapore pas : quand l'eau baisse, la salinité monte. C'est
	# tout le métier, et c'est ce qui fait cristalliser un œillet.
	var marais: Marais = _marais_a_deux_bassins(0.30, 0.00)
	var salinite_avant: float = marais.bassins[0].salinite
	for _i: int in range(600):
		marais.evaporer(0.002, Reglages.DUREE_TICK)
	assert_float(marais.bassins[0].salinite).is_greater(salinite_avant)

func test_un_talus_n_est_pas_un_bassin() -> void:
	var marais: Marais = _marais_a_deux_bassins(0.30, 0.00)
	# Entre les deux polygones, à x=10, il n'y a aucun bassin : c'est le talus.
	assert_bool(marais.est_talus(Vector2(10.0, 5.0))).is_true()
	assert_bool(marais.est_talus(Vector2(4.0, 5.0))).is_false()
	assert_float(marais.profondeur_eau(Vector2(10.0, 5.0))).is_equal(0.0)
	assert_float(marais.profondeur_eau(Vector2(4.0, 5.0))).is_greater(0.0)

func test_la_fleur_ne_prend_qu_au_vent_d_est() -> void:
	var marais: Marais = _marais_a_deux_bassins(0.30, 0.00)
	# Une saumure mûre, une lame d'eau juste, mais pas un souffle.
	marais.bassins[0].salinite = 0.96
	marais.bassins[0].volume = marais.bassins[0].surface * 0.03
	for _i: int in range(600):
		marais.former_fleur(0.0, Reglages.DUREE_TICK)
	assert_float(marais.bassins[0].fleur).is_equal_approx(0.0, 0.0001)
	for _i: int in range(600):
		marais.former_fleur(0.5, Reglages.DUREE_TICK)
	assert_float(marais.bassins[0].fleur).is_greater(Reglages.FLEUR_PRISE)

func test_trop_de_vent_et_la_fleur_coule() -> void:
	var marais: Marais = _marais_a_deux_bassins(0.30, 0.00)
	marais.bassins[0].salinite = 0.96
	marais.bassins[0].volume = marais.bassins[0].surface * 0.03
	for _i: int in range(600):
		marais.former_fleur(0.5, Reglages.DUREE_TICK)
	var prise: float = marais.bassins[0].fleur
	assert_float(prise).is_greater(0.0)
	# Au-dessus du seuil haut, la pellicule se défait.
	for _i: int in range(600):
		marais.former_fleur(0.98, Reglages.DUREE_TICK)
	assert_float(marais.bassins[0].fleur).is_less(prise)

func test_une_saumure_jeune_ne_donne_pas_de_fleur() -> void:
	var marais: Marais = _marais_a_deux_bassins(0.30, 0.00)
	marais.bassins[0].salinite = 0.40
	marais.bassins[0].volume = marais.bassins[0].surface * 0.03
	for _i: int in range(900):
		marais.former_fleur(0.5, Reglages.DUREE_TICK)
	assert_float(marais.bassins[0].fleur).is_equal_approx(0.0, 0.0001)

func test_le_gros_sel_ne_se_tire_que_d_un_oeillet_sec() -> void:
	var marais: Marais = _marais_a_deux_bassins(0.30, 0.00)
	marais.bassins[0].salinite = 0.96
	# Le stock existe : ce test mesure la règle de l'EAU, pas l'épuisement.
	marais.bassins[0].gros_sel = 5
	marais.bassins[0].volume = marais.bassins[0].surface * 0.30
	assert_bool(marais.sel_au_fond(0)).is_false()
	marais.bassins[0].volume = marais.bassins[0].surface * 0.01
	assert_bool(marais.sel_au_fond(0)).is_true()

func test_on_ne_marche_pas_au_fond_de_l_etier() -> void:
	# Le défaut le plus visible du jeu : le joueur descendait dans un chenal
	# d'un mètre trente et y MARCHAIT, immergé jusqu'au torse, la caméra sous
	# la nappe — et comme le shader d'eau ne s'affichait que par-dessus, il
	# voyait le ciel à travers l'eau. Le lore distingue deux eaux ; le jeu doit
	# les distinguer aussi.
	var monde: Monde = Monde.new()
	monde.marais = Etier.batir()
	monde.marais.maree(Etier.MAREE_HAUTE)
	monde.ladure = Etier.LADURE
	var joueur: Acteur = Acteur.new()
	joueur.camp = Acteur.Camp.PALUDIER
	joueur.position = Vector2(5.0, 12.0)
	var _p: Acteur = monde.ajouter(joueur)

	var profondeur: float = monde.marais.profondeur_eau(joueur.position)
	prints("profondeur au milieu de l'étier :", profondeur, "m")
	assert_float(profondeur).is_greater(Reglages.EAU_MORTELLE)

	var simulation: Simulation = Simulation.new()
	for _i: int in range(Reglages.TICKS_DE_NOYADE + 4):
		simulation.avancer(monde, {})
	assert_bool(joueur.vivant()).override_failure_message(
		"le joueur survit dans 1,31 m d'eau").is_false()

	# Et il est redéposé à la ladure, pas effacé.
	for _i: int in range(Reglages.REPOS_APRES_MORT + 2):
		simulation.avancer(monde, {})
	assert_bool(joueur.vivant()).is_true()
	assert_vector(joueur.position).is_equal(Etier.LADURE)

func test_une_flaque_de_bassin_ne_noie_personne() -> void:
	# L'autre moitié de la règle : « on ne meurt pas de tomber d'un talus ».
	# Trois centimètres d'eau au fond d'un œillet doivent rester inoffensifs.
	var monde: Monde = Monde.new()
	monde.marais = Etier.batir()
	monde.marais.maree(Etier.MAREE_HAUTE)
	monde.ladure = Etier.LADURE
	var joueur: Acteur = Acteur.new()
	joueur.camp = Acteur.Camp.PALUDIER
	joueur.position = Etier.OEILLET_DE_LA_FLEUR
	var _p: Acteur = monde.ajouter(joueur)
	prints("profondeur dans l'œillet :",
		monde.marais.profondeur_eau(joueur.position), "m")
	var simulation: Simulation = Simulation.new()
	for _i: int in range(20 * Reglages.TICKS_PAR_SECONDE):
		simulation.avancer(monde, {})
	assert_bool(joueur.vivant()).override_failure_message(
		"le joueur se noie dans une flaque").is_true()
