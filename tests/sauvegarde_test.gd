## La sauvegarde : ce qui est écrit se relit, et rien d'autre.
extends GdUnitTestSuite

func _monde() -> Monde:
	var monde: Monde = Monde.new()
	monde.marais = Etier.batir()
	monde.marais.maree(Etier.MAREE_HAUTE)
	monde.ladure = Etier.DEPART
	var las: Geste = load("res://data/combat/las_lourd.tres") as Geste
	monde.gestes[las.nom] = las
	var joueur: Acteur = Acteur.new()
	joueur.camp = Acteur.Camp.PALUDIER
	joueur.position = Etier.DEPART
	var _p: Acteur = monde.ajouter(joueur)
	return monde

func test_une_saison_se_retient_et_se_reprend() -> void:
	# On joue un début de saison : porte ouverte, eau descendue, sel tiré,
	# cristallisé levé et blessé, checkpoint gagné. Puis on photographie, on
	# reconstruit un monde NEUF, on applique — et tout doit y être.
	var monde: Monde = _monde()
	var tutoriel: Tutoriel = Tutoriel.new()
	var simulation: Simulation = Simulation.new()
	var porte: int = monde.marais.vanne_nommee(&"porte_de_maree")
	monde.marais.vannes[porte].ouverte = true
	for _i: int in range(15 * Reglages.TICKS_PAR_SECONDE):
		simulation.avancer(monde, {})
	monde.gros_sel = 7
	monde.fleur = 1
	monde.ladure = Etier.LADURE
	tutoriel.etape = Tutoriel.Etape.LADURE
	tutoriel._lever_le_cristallise(monde)
	tutoriel.cristallise().blesser(20.0)
	monde.joueur().position = Etier.LADURE
	monde.joueur().vie = 66.0

	var donnees: Dictionary = Sauvegarde.extraire(monde, tutoriel)
	# Aller-retour par le JSON, comme sur disque : les types y fondent.
	var rejoue: Variant = JSON.parse_string(JSON.stringify(donnees))
	assert_bool(rejoue is Dictionary).is_true()
	var relu: Dictionary = rejoue

	var neuf: Monde = _monde()
	var tutoriel_neuf: Tutoriel = Tutoriel.new()
	assert_bool(Sauvegarde.appliquer(relu, neuf, tutoriel_neuf)).is_true()

	assert_int(int(tutoriel_neuf.etape)).is_equal(int(Tutoriel.Etape.LADURE))
	assert_int(neuf.gros_sel).is_equal(7)
	assert_int(neuf.fleur).is_equal(1)
	assert_vector(neuf.ladure).is_equal(Etier.LADURE)
	assert_vector(neuf.joueur().position).is_equal(Etier.LADURE)
	assert_float(neuf.joueur().vie).is_equal_approx(66.0, 0.001)
	assert_bool(neuf.marais.vannes[porte].ouverte).is_true()
	# L'eau descendue est toujours descendue : les volumes ont voyagé.
	var vasiere: int = neuf.marais.bassin_nomme(&"vasiere_nord")
	assert_float(neuf.marais.bassins[vasiere].volume).is_equal_approx(
		monde.marais.bassins[vasiere].volume, 0.001)
	# Le cristallisé est revenu, blessé comme on l'a laissé.
	var ennemi: Acteur = tutoriel_neuf.cristallise()
	assert_object(ennemi).is_not_null()
	assert_float(ennemi.vie).is_equal_approx(
		Reglages.VIE_CRISTALLISE - 20.0, 0.001)

func test_une_sauvegarde_illisible_ne_charge_pas_un_monde_faux() -> void:
	var neuf: Monde = _monde()
	var tutoriel: Tutoriel = Tutoriel.new()
	assert_bool(Sauvegarde.appliquer({"version": 99}, neuf, tutoriel)).is_false()
	assert_bool(Sauvegarde.appliquer({}, neuf, tutoriel)).is_false()
	# Et le monde n'a pas bougé.
	assert_int(neuf.gros_sel).is_equal(0)
	assert_int(int(tutoriel.etape)).is_equal(int(Tutoriel.Etape.MARCHER))

func test_un_cristallise_mort_reste_mort_au_rechargement() -> void:
	# « Le sel garde ce qui s'y dissout » — la sauvegarde aussi. Un ennemi
	# vaincu qui ressusciterait au rechargement trahirait la règle du monde.
	var monde: Monde = _monde()
	var tutoriel: Tutoriel = Tutoriel.new()
	tutoriel.etape = Tutoriel.Etape.LADURE
	tutoriel._lever_le_cristallise(monde)
	tutoriel.cristallise().blesser(9999.0)
	var rejoue: Variant = JSON.parse_string(
		JSON.stringify(Sauvegarde.extraire(monde, tutoriel)))
	var relu: Dictionary = rejoue
	var neuf: Monde = _monde()
	var tutoriel_neuf: Tutoriel = Tutoriel.new()
	assert_bool(Sauvegarde.appliquer(relu, neuf, tutoriel_neuf)).is_true()
	var ennemi: Acteur = tutoriel_neuf.cristallise()
	assert_object(ennemi).is_not_null()
	assert_bool(ennemi.vivant()).is_false()
