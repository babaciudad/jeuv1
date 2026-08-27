## Le tutoriel est-il FINISSABLE ?
##
## C'est la seule question qui décide si le jalon est tenu, et c'est une
## question qu'on peut poser à une machine. Un pilote automatique joue les sept
## étapes — marcher, ouvrir la vanne, tirer au las, affronter le cristallisé,
## l'esquiver, se reposer à la ladure, cueillir la fleur — en n'utilisant QUE
## des commandes, exactement comme un joueur au clavier (invariant 3).
##
## Si ce test passe, le tutoriel se termine. S'il échoue, il indique à quelle
## étape on s'est arrêté et depuis combien de temps.
extends GdUnitTestSuite

## Plafond de sécurité : deux minutes de jeu simulé.
const TICKS_MAX: int = 120 * Reglages.TICKS_PAR_SECONDE

class Pilote extends RefCounted:
	var etapes_vues: Array[int] = []
	var ticks_par_etape: Dictionary[int, int] = {}
	var _derniere: int = -1
	var _entree: int = 0

	## Chemin de talus à suivre pour rejoindre l'est du marais. Le pilote
	## pourrait couper à travers les bassins — on n'y meurt pas — mais il y
	## serait lent, et un chemin qui suit les digues teste le terrain qu'on a
	## réellement dessiné.
	const VERS_L_EST: Array[Vector2] = [
		Vector2(Etier.AXE_DIGUE, Etier.AXE_CHAUSSEE),
		Vector2(41.0, Etier.AXE_CHAUSSEE), Vector2(41.9, 12.0)]

	func commande(monde: Monde, tutoriel: Tutoriel, tick: int) -> Commande:
		var joueur: Acteur = monde.joueur()
		var c: Commande = Commande.new()
		if joueur == null or not joueur.vivant():
			return c
		if tutoriel.etape != _derniere:
			_derniere = tutoriel.etape
			_entree = tick
			etapes_vues.append(tutoriel.etape)
		ticks_par_etape[tutoriel.etape] = tick - _entree

		match tutoriel.etape:
			Tutoriel.Etape.MARCHER:
				_aller(c, joueur, Etier.PORTE_DE_MAREE)
			Tutoriel.Etape.VANNE:
				_aller(c, joueur, Etier.PORTE_DE_MAREE)
				c.interagit = joueur.position.distance_to(Etier.PORTE_DE_MAREE) < 1.6
			Tutoriel.Etape.LAS:
				var but: Vector2 = _prochain(joueur, Etier.OEILLET_DU_SEL)
				_aller(c, joueur, but)
				if joueur.position.distance_to(Etier.OEILLET_DU_SEL) < 1.2:
					c.direction = Vector2.ZERO
					c.frappe = joueur.etat == Acteur.Etat.LIBRE
			Tutoriel.Etape.LEVEE, Tutoriel.Etape.ESQUIVE:
				_combattre(c, monde, joueur, tutoriel)
			Tutoriel.Etape.LADURE:
				# On ne tourne pas le dos à un cristallisé vivant : il frappe
				# dans le dos, et le pilote y laissait sa peau à chaque essai.
				var reste: Acteur = tutoriel.cristallise()
				if reste != null and reste.vivant() \
						and reste.position.distance_to(joueur.position) < 7.0:
					_combattre(c, monde, joueur, tutoriel)
				else:
					_aller(c, joueur, Etier.LADURE)
					c.interagit = joueur.position.distance_to(Etier.LADURE) < 1.8
			Tutoriel.Etape.FLEUR:
				_aller(c, joueur, Etier.OEILLET_DE_LA_FLEUR)
				var dedans: bool = joueur.position.distance_to(
					Etier.OEILLET_DE_LA_FLEUR) < 1.6
				if dedans:
					c.direction = Vector2.ZERO
					c.interagit = true
			_:
				pass
		return c

	func _combattre(c: Commande, monde: Monde, joueur: Acteur,
			tutoriel: Tutoriel) -> void:
		var ennemi: Acteur = tutoriel.cristallise()
		if ennemi == null or not ennemi.vivant():
			return
		var ecart: Vector2 = ennemi.position - joueur.position
		var distance: float = ecart.length()
		c.cap = atan2(ecart.x, ecart.y)
		# Il frappe : on sort de son arc. « Le las est lent, et large. »
		# On n'esquive QUE dans la fenêtre où le coup part vraiment : esquiver
		# à chaque image où l'ennemi lève son las vide toute l'endurance et il
		# ne reste plus rien pour frapper — c'est ce qui bloquait le pilote.
		if _danger(monde, ennemi) and distance < 5.4 \
				and joueur.etat == Acteur.Etat.LIBRE \
				and joueur.endurance > Reglages.ENDURANCE_ESQUIVE:
			c.esquive = true
			c.direction = -ecart.normalized()
			return
		if distance > 3.6:
			c.direction = ecart.normalized()
		elif joueur.etat == Acteur.Etat.LIBRE and joueur.endurance \
				> Reglages.ENDURANCE_COUP_LAS + Reglages.ENDURANCE_ESQUIVE:
			# On garde de quoi esquiver. Tout dépenser en coups, c'est se
			# retrouver sans rien quand le las adverse part — et c'est
			# exactement ce qui bloquait ce pilote.
			c.frappe = true

	## Suit le chemin de talus tant qu'on n'est pas encore à l'est.
	func _prochain(joueur: Acteur, final: Vector2) -> Vector2:
		for point: Vector2 in VERS_L_EST:
			if joueur.position.distance_to(point) > 1.4 \
					and joueur.position.x < point.x - 0.6:
				return point
		return final

	## Vrai seulement dans la fenêtre où le coup adverse va porter.
	func _danger(monde: Monde, ennemi: Acteur) -> bool:
		if ennemi.etat != Acteur.Etat.FRAPPE:
			return false
		var geste: Geste = monde.geste_nomme(ennemi.geste)
		if geste == null:
			return false
		return ennemi.ticks_geste >= geste.debut_coup - 16 \
			and ennemi.ticks_geste <= geste.fin_coup

	func _aller(c: Commande, joueur: Acteur, but: Vector2) -> void:
		var ecart: Vector2 = but - joueur.position
		if ecart.length() > 0.35:
			c.direction = ecart.normalized()
			c.cap = atan2(ecart.x, ecart.y)
		else:
			c.cap = joueur.cap

func _monde() -> Monde:
	var monde: Monde = Monde.new()
	monde.marais = Etier.batir()
	monde.marais.maree(Etier.MAREE_HAUTE)
	monde.ladure = Etier.LADURE
	var las: Geste = load("res://data/combat/las_lourd.tres") as Geste
	assert_object(las).is_not_null()
	monde.gestes[las.nom] = las
	var joueur: Acteur = Acteur.new()
	joueur.camp = Acteur.Camp.PALUDIER
	joueur.position = Etier.DEPART
	var _pose: Acteur = monde.ajouter(joueur)
	return monde

func test_le_tutoriel_se_termine() -> void:
	var monde: Monde = _monde()
	var simulation: Simulation = Simulation.new()
	var tutoriel: Tutoriel = Tutoriel.new()
	var pilote: Pilote = Pilote.new()

	var tick: int = 0
	while tick < TICKS_MAX and tutoriel.etape != Tutoriel.Etape.FINI:
		var c: Commande = pilote.commande(monde, tutoriel, tick)
		var commandes: Dictionary[int, Commande] = {}
		commandes[monde.joueur().id] = c
		simulation.avancer(monde, commandes)
		tutoriel.progresser(monde, c, Reglages.DUREE_TICK)
		tick += 1

	var secondes: float = float(tick) / float(Reglages.TICKS_PAR_SECONDE)
	prints("tutoriel : etape finale =", tutoriel.etape, "en", secondes, "s")
	prints("  etapes traversees :", pilote.etapes_vues)
	prints("  gros sel =", monde.gros_sel, " fleur =", monde.fleur)
	assert_int(tutoriel.etape).is_equal(Tutoriel.Etape.FINI)

func test_chaque_etape_est_franchie_dans_l_ordre() -> void:
	var monde: Monde = _monde()
	var simulation: Simulation = Simulation.new()
	var tutoriel: Tutoriel = Tutoriel.new()
	var pilote: Pilote = Pilote.new()
	var tick: int = 0
	while tick < TICKS_MAX and tutoriel.etape != Tutoriel.Etape.FINI:
		var c: Commande = pilote.commande(monde, tutoriel, tick)
		var commandes: Dictionary[int, Commande] = {}
		commandes[monde.joueur().id] = c
		simulation.avancer(monde, commandes)
		tutoriel.progresser(monde, c, Reglages.DUREE_TICK)
		tick += 1
	# Le pilote n'enregistre pas FINI : la boucle s'arrête dès qu'on y entre,
	# donc il ne reçoit plus la main. Ce sont les sept étapes JOUÉES qu'on
	# vérifie ici, et l'arrivée est vérifiée à part.
	assert_array(pilote.etapes_vues).is_equal([
		Tutoriel.Etape.MARCHER, Tutoriel.Etape.VANNE, Tutoriel.Etape.LAS,
		Tutoriel.Etape.LEVEE, Tutoriel.Etape.ESQUIVE, Tutoriel.Etape.LADURE,
		Tutoriel.Etape.FLEUR])
	assert_int(tutoriel.etape).is_equal(Tutoriel.Etape.FINI)

func test_le_chemin_du_tutoriel_est_praticable() -> void:
	# Le terrain du jeu, ce sont des digues de quatre-vingts centimètres. Si
	# l'une d'elles se coupe quelque part, le tutoriel devient une traversée à
	# gué sans que rien ne le signale — sauf ce test.
	var marais: Marais = Etier.batir()
	var digue: Array[Vector2] = [Etier.DEPART, Etier.PORTE_DE_MAREE, Etier.CROISEE]
	for i: int in range(digue.size() - 1):
		var pas: int = maxi(1, int(digue[i].distance_to(digue[i + 1]) / 0.2))
		for k: int in range(pas + 1):
			var p: Vector2 = digue[i].lerp(digue[i + 1], float(k) / float(pas))
			assert_bool(marais.est_talus(p)).override_failure_message(
				"digue nord-sud coupée en %s" % str(p)).is_true()
	var pas_est: int = int((41.9 - Etier.AXE_DIGUE) / 0.2)
	for k: int in range(pas_est + 1):
		var p: Vector2 = Vector2(lerpf(Etier.AXE_DIGUE, 41.9,
			float(k) / float(pas_est)), Etier.AXE_CHAUSSEE)
		assert_bool(marais.est_talus(p)).override_failure_message(
			"chaussée est-ouest coupée en %s" % str(p)).is_true()

func test_un_talus_du_lore_fait_bien_quatre_vingts_centimetres() -> void:
	# Le lore promet un terrain de combat large « comme un homme ». On le
	# mesure : on traverse la digue nord-sud en travers et on compte.
	var marais: Marais = Etier.batir()
	var largeur: float = 0.0
	var x: float = 7.0
	while x < 12.0:
		if marais.est_talus(Vector2(x, 10.0)):
			largeur += 0.01
		x += 0.01
	prints("largeur de la digue mesurée :", largeur, "m")
	# Le lore promet soixante-dix centimètres ; la grille en rend soixante-
	# quinze. On tient cette marge-là, et pas le double.
	assert_float(largeur).is_between(0.70, 0.80)

func test_mourir_redepose_a_la_ladure_sans_remettre_le_monde_a_zero() -> void:
	var monde: Monde = _monde()
	monde.ladure = Etier.LADURE
	var simulation: Simulation = Simulation.new()
	var joueur: Acteur = monde.joueur()
	# On fait descendre de l'eau AVANT de mourir : elle doit y rester.
	var porte: int = monde.marais.vanne_nommee(&"porte_de_maree")
	monde.marais.vannes[porte].ouverte = true
	for _i: int in range(10 * Reglages.TICKS_PAR_SECONDE):
		simulation.avancer(monde, {})
	var vasiere: int = monde.marais.bassin_nomme(&"vasiere_nord")
	var niveau: float = monde.marais.bassins[vasiere].niveau()

	joueur.blesser(9999.0)
	assert_bool(joueur.vivant()).is_false()
	for _i: int in range(Reglages.REPOS_APRES_MORT + 2):
		simulation.avancer(monde, {})
	assert_bool(joueur.vivant()).is_true()
	assert_vector(joueur.position).is_equal(Etier.LADURE)
	assert_float(joueur.vie).is_equal(joueur.vie_max)
	# « Le monde ne se remet pas à zéro : l'eau qu'il a fait descendre est
	# toujours descendue. »
	assert_float(monde.marais.bassins[vasiere].niveau()).is_greater_equal(niveau)

func test_la_porte_de_maree_fait_monter_la_vasiere() -> void:
	# Le premier geste du jeu doit avoir un effet VISIBLE, et mesurable.
	var monde: Monde = _monde()
	var vasiere: int = monde.marais.bassin_nomme(&"vasiere_nord")
	var avant: float = monde.marais.bassins[vasiere].niveau()
	var porte: int = monde.marais.vanne_nommee(&"porte_de_maree")
	monde.marais.vannes[porte].ouverte = true
	for _i: int in range(20 * Reglages.TICKS_PAR_SECONDE):
		monde.marais.ecouler(Reglages.DUREE_TICK)
	var apres: float = monde.marais.bassins[vasiere].niveau()
	prints("vasiere :", avant, "->", apres, "en 20 s")
	assert_float(apres - avant).is_greater(0.08)
