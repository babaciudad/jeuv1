## Le combat : la fenêtre de coup, les corps, le bord du monde.
##
## Ces tests existent parce que trois défauts graves ont été trouvés en jouant
## contre la simulation : la fenêtre de coup annoncée sur onze ticks n'en
## faisait porter qu'un seul, les corps se traversaient comme du brouillard,
## et une diagonale contre le bord de la carte figeait le joueur sur place.
extends GdUnitTestSuite

func _monde() -> Monde:
	var monde: Monde = Monde.new()
	monde.marais = Etier.batir()
	monde.marais.maree(Etier.MAREE_HAUTE)
	monde.ladure = Etier.LADURE
	var las: Geste = load("res://data/combat/las_lourd.tres") as Geste
	assert_object(las).is_not_null()
	monde.gestes[las.nom] = las
	return monde

func _paludier(monde: Monde, ou: Vector2) -> Acteur:
	var a: Acteur = Acteur.new()
	a.camp = Acteur.Camp.PALUDIER
	a.position = ou
	return monde.ajouter(a)

func _cristallise(monde: Monde, ou: Vector2) -> Acteur:
	var a: Acteur = Acteur.new()
	a.camp = Acteur.Camp.CRISTALLISE
	a.position = ou
	a.vie = Reglages.VIE_CRISTALLISE
	a.vie_max = Reglages.VIE_CRISTALLISE
	# Un répit infini : ces tests mesurent le coup du joueur, pas le sien.
	a.attente = 100000
	return monde.ajouter(a)

func _frapper(monde: Monde, joueur: Acteur, simulation: Simulation) -> void:
	var c: Commande = Commande.new()
	c.cap = 0.0
	c.frappe = true
	var commandes: Dictionary[int, Commande] = {}
	commandes[joueur.id] = c
	simulation.avancer(monde, commandes)
	assert_int(joueur.etat).is_equal(Acteur.Etat.FRAPPE)

func test_la_fenetre_de_coup_est_une_vraie_fenetre() -> void:
	# Le las balaie 183 ms, visibles à l'œil nu. Un corps qui entre dans l'arc
	# PENDANT le balayage doit être touché — il passait au travers du manche.
	var monde: Monde = _monde()
	var joueur: Acteur = _paludier(monde, Etier.LADURE)
	var ennemi: Acteur = _cristallise(monde, Etier.LADURE + Vector2(0.0, 12.0))
	var geste: Geste = monde.geste_nomme(&"las_lourd")
	var simulation: Simulation = Simulation.new()

	_frapper(monde, joueur, simulation)
	# On laisse passer le début de la fenêtre, cible hors de portée.
	while joueur.ticks_geste < geste.debut_coup + 4:
		simulation.avancer(monde, {})
	assert_float(ennemi.vie).is_equal(ennemi.vie_max)
	# La cible entre dans l'arc au beau milieu du balayage.
	ennemi.position = joueur.position + Vector2(
		sin(joueur.cap), cos(joueur.cap)) * 2.0
	simulation.avancer(monde, {})
	prints("touché au tick", joueur.ticks_geste, "de la fenêtre [",
		geste.debut_coup, ",", geste.fin_coup, "] : vie", ennemi.vie)
	# Et on laisse la fenêtre se finir : UN coup, exactement, pas onze.
	while joueur.etat == Acteur.Etat.FRAPPE:
		simulation.avancer(monde, {})
	assert_float(ennemi.vie).is_equal_approx(
		ennemi.vie_max - geste.degats, 0.001)

func test_un_geste_ne_touche_jamais_deux_fois_le_meme_corps() -> void:
	# Onze ticks de fenêtre ne font pas onze fois les dégâts.
	var monde: Monde = _monde()
	var joueur: Acteur = _paludier(monde, Etier.LADURE)
	var ennemi: Acteur = _cristallise(monde,
		Etier.LADURE + Vector2(0.0, 1.8))
	var geste: Geste = monde.geste_nomme(&"las_lourd")
	var simulation: Simulation = Simulation.new()

	_frapper(monde, joueur, simulation)
	for _i: int in range(geste.duree + 4):
		simulation.avancer(monde, {})
	prints("vie après un geste complet dans l'arc :", ennemi.vie)
	assert_float(ennemi.vie).is_equal_approx(
		ennemi.vie_max - geste.degats, 0.001)

func test_un_balayage_large_touche_chaque_corps_dans_l_arc() -> void:
	var monde: Monde = _monde()
	var joueur: Acteur = _paludier(monde, Etier.LADURE)
	var gauche: Acteur = _cristallise(monde,
		Etier.LADURE + Vector2(-1.2, 1.6))
	var droite: Acteur = _cristallise(monde,
		Etier.LADURE + Vector2(1.2, 1.6))
	var geste: Geste = monde.geste_nomme(&"las_lourd")
	var simulation: Simulation = Simulation.new()

	_frapper(monde, joueur, simulation)
	for _i: int in range(geste.duree + 4):
		simulation.avancer(monde, {})
	prints("gauche :", gauche.vie, " droite :", droite.vie)
	assert_float(gauche.vie).is_less(gauche.vie_max)
	assert_float(droite.vie).is_less(droite.vie_max)

func test_deux_corps_ne_s_interpenetrent_pas() -> void:
	# On traversait le cristallisé comme du brouillard : on ressortait dans son
	# dos et l'espace du combat ne voulait rien dire.
	var monde: Monde = _monde()
	var a: Acteur = _paludier(monde, Etier.LADURE)
	var b: Acteur = _cristallise(monde, Etier.LADURE + Vector2(0.05, 0.0))
	var simulation: Simulation = Simulation.new()
	for _i: int in range(30):
		simulation.avancer(monde, {})
	var distance: float = a.position.distance_to(b.position)
	prints("distance après séparation :", distance,
		"— minimum :", Reglages.RAYON_CORPS * 2.0)
	assert_float(distance).is_greater_equal(Reglages.RAYON_CORPS * 2.0 - 0.02)

func test_une_diagonale_contre_le_bord_glisse_au_lieu_de_figer() -> void:
	var monde: Monde = _monde()
	var joueur: Acteur = _paludier(monde, Vector2(0.4, 10.0))
	var simulation: Simulation = Simulation.new()
	var c: Commande = Commande.new()
	c.direction = Vector2(-0.707, 0.707)
	c.cap = atan2(c.direction.x, c.direction.y)
	var commandes: Dictionary[int, Commande] = {}
	commandes[joueur.id] = c
	var y_avant: float = joueur.position.y
	for _i: int in range(2 * Reglages.TICKS_PAR_SECONDE):
		simulation.avancer(monde, commandes)
	prints("poussée diagonale contre le bord : y", y_avant, "->",
		joueur.position.y, " x =", joueur.position.x)
	assert_float(joueur.position.y).override_failure_message(
		"le joueur est figé contre le bord de la carte").is_greater(y_avant + 1.0)
	assert_float(joueur.position.x).is_greater_equal(0.0)

func test_un_geste_rapporte_une_part_de_sel_pas_onze() -> void:
	# La fenêtre de coup fait onze ticks : le compteur montait de onze par
	# geste, et de cent quatre-vingt-six en cinq minutes de raclage.
	var monde: Monde = _monde()
	var joueur: Acteur = _paludier(monde, Etier.OEILLET_DU_SEL)
	var geste: Geste = monde.geste_nomme(&"las_lourd")
	var simulation: Simulation = Simulation.new()
	_frapper(monde, joueur, simulation)
	for _i: int in range(geste.duree + 4):
		simulation.avancer(monde, {})
	prints("gros sel après un geste :", monde.gros_sel)
	assert_int(monde.gros_sel).is_equal(1)

func test_un_oeillet_racle_ne_donne_plus_rien() -> void:
	# Le sel est une RÉCOLTE, pas une fontaine : trente parts, puis l'argile.
	var monde: Monde = _monde()
	var joueur: Acteur = _paludier(monde, Etier.OEILLET_DU_SEL)
	var bassin: int = monde.marais.bassin_sous(joueur.position)
	var stock: int = monde.marais.bassins[bassin].gros_sel
	prints("stock initial de l'œillet :", stock)
	assert_int(stock).is_greater(0)
	var simulation: Simulation = Simulation.new()
	# On racle jusqu'à bien au-delà du stock. On se replace à chaque geste :
	# la poussée du las fait avancer, et vingt gestes enchaînés sortent de
	# l'œillet — c'est le terrain qui arrête le raclage, pas le stock.
	for _geste: int in range(stock + 6):
		joueur.position = Etier.OEILLET_DU_SEL
		joueur.vitesse = Vector2.ZERO
		joueur.endurance = Reglages.ENDURANCE_MAX
		_frapper(monde, joueur, simulation)
		while joueur.etat == Acteur.Etat.FRAPPE:
			simulation.avancer(monde, {})
	prints("récolté :", monde.gros_sel, "— stock restant :",
		monde.marais.bassins[bassin].gros_sel)
	assert_int(monde.gros_sel).is_equal(stock)
	assert_bool(monde.marais.sel_au_fond(bassin)).is_false()
