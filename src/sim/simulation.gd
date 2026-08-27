## Avance le monde d'un tick, et c'est tout ce qu'elle fait.
##
## Invariant 1 : le tick est la seule unité de temps. Aucune valeur de delta
## variable n'entre ici ; la durée d'un tick est une constante.
## Invariant 2 : la simulation ne connaît pas la présentation. Elle ne lit ni
## clavier, ni caméra, ni nœud. Elle lit des commandes et écrit un monde.
class_name Simulation
extends RefCounted

## Fenêtre d'invulnérabilité d'une esquive, en ticks, depuis son début.
const ESQUIVE_INTOUCHABLE_DEBUT: int = 3
const ESQUIVE_INTOUCHABLE_FIN: int = 17
const ESQUIVE_DUREE: int = 30
const ESQUIVE_VITESSE: float = 7.4
const DOULEUR_DUREE: int = 22

## Avance d'un tick. `commandes` associe l'id d'un acteur à son intention ; un
## acteur sans commande ne fait rien de délibéré, ce qui est le cas de tous les
## cristallisés (leur intention vient de `decider`).
func avancer(monde: Monde, commandes: Dictionary[int, Commande]) -> void:
	monde.tick += 1
	monde.vanne_ouverte_ce_tick = -1
	monde.sel_tire_ce_tick = false
	monde.fleur_cueillie_ce_tick = false
	monde.joueur_redepose_ce_tick = false
	var duree: float = Reglages.DUREE_TICK

	for acteur: Acteur in monde.acteurs:
		if not acteur.vivant():
			_saumurer(monde, acteur)
			continue
		var commande: Commande = null
		if commandes.has(acteur.id):
			commande = commandes[acteur.id]
		if commande == null:
			commande = decider(monde, acteur)
		_avancer_acteur(monde, acteur, commande, duree)

	_resoudre_coups(monde)
	_separer_les_corps(monde)

	monde.marais.ecouler(duree)
	if monde.evaporation > 0.0:
		monde.marais.evaporer(monde.evaporation, duree)
	monde.marais.former_fleur(monde.vent_est, duree)

# ---------------------------------------------------------------------------
# Un acteur, un tick
# ---------------------------------------------------------------------------

func _avancer_acteur(monde: Monde, acteur: Acteur, commande: Commande,
		duree: float) -> void:
	acteur.vient_de_tomber = false

	# L'état courant s'écoule d'abord : c'est lui qui décide si l'acteur a
	# seulement le droit de vouloir quelque chose.
	if acteur.etat != Acteur.Etat.LIBRE:
		acteur.ticks_etat -= 1
		acteur.ticks_geste += 1
		if acteur.etat == Acteur.Etat.ESQUIVE:
			acteur.intouchable = acteur.ticks_geste >= ESQUIVE_INTOUCHABLE_DEBUT \
				and acteur.ticks_geste <= ESQUIVE_INTOUCHABLE_FIN
		if acteur.ticks_etat <= 0:
			# Un cristallisé qui vient de finir son geste marque un temps. C'est
			# dans ce temps-là que le joueur frappe.
			if acteur.etat == Acteur.Etat.FRAPPE \
					and acteur.camp == Acteur.Camp.CRISTALLISE:
				acteur.attente = Reglages.REPIT_CRISTALLISE
			acteur.etat = Acteur.Etat.LIBRE
			acteur.ticks_etat = 0
			acteur.intouchable = false
			acteur.geste = &""
			acteur.ticks_geste = 0

	if acteur.peut_agir() and commande.interagit:
		_interagir(monde, acteur)

	if acteur.peut_agir():
		if commande.esquive and acteur.depenser(Reglages.ENDURANCE_ESQUIVE):
			acteur.etat = Acteur.Etat.ESQUIVE
			acteur.ticks_etat = ESQUIVE_DUREE
			acteur.ticks_geste = 0
			acteur.geste = &"esquive"
			var vers: Vector2 = commande.direction
			if vers == Vector2.ZERO:
				vers = Vector2(sin(acteur.cap), cos(acteur.cap))
			acteur.vitesse = vers.normalized() * ESQUIVE_VITESSE
		elif commande.frappe:
			var geste: Geste = monde.geste_nomme(&"las_lourd")
			if geste != null and acteur.depenser(geste.cout_endurance):
				acteur.etat = Acteur.Etat.FRAPPE
				acteur.ticks_etat = geste.duree
				acteur.ticks_geste = 0
				acteur.geste = geste.nom
				acteur.touches.clear()

	_deplacer(monde, acteur, commande, duree)
	_endurance(acteur, duree)

func _deplacer(monde: Monde, acteur: Acteur, commande: Commande,
		duree: float) -> void:
	var voulue: Vector2 = Vector2.ZERO

	match acteur.etat:
		Acteur.Etat.LIBRE:
			var allure: float = Reglages.VITESSE_MARCHE
			if commande.court and acteur.endurance > 0.0 \
					and commande.direction.length_squared() > 0.001:
				allure = Reglages.VITESSE_COURSE
				# La course se PAIE. Sans ça il n'y a aucune raison de marcher,
				# et la moitié du vocabulaire souls-like perd son sens.
				acteur.endurance = maxf(0.0, acteur.endurance
					- Reglages.ENDURANCE_PAR_SECONDE_DE_COURSE * duree)
				acteur.repos_avant_regen = int(
					Reglages.ENDURANCE_DELAI * float(Reglages.TICKS_PAR_SECONDE))
			voulue = commande.direction.limit_length(1.0) * allure
			# Le cap suit la direction de marche ; à l'arrêt, il suit la caméra.
			if commande.direction.length_squared() > 0.001:
				acteur.cap = _tourner_vers(acteur.cap,
					atan2(commande.direction.x, commande.direction.y), duree)
			else:
				acteur.cap = _tourner_vers(acteur.cap, commande.cap, duree)
		Acteur.Etat.FRAPPE:
			var geste: Geste = monde.geste_nomme(acteur.geste)
			if geste != null and acteur.ticks_geste <= geste.fin_coup:
				voulue = Vector2(sin(acteur.cap), cos(acteur.cap)) * geste.poussee
		Acteur.Etat.ESQUIVE:
			# La roulade garde son élan : elle n'est pas pilotable en cours.
			voulue = acteur.vitesse
		_:
			voulue = Vector2.ZERO

	# L'eau ralentit tout, et c'est la seule punition dont on ait besoin : on
	# ne meurt pas de tomber d'un talus, on devient lent, bruyant et exposé.
	var profondeur: float = monde.marais.profondeur_eau(acteur.position)
	if profondeur > Reglages.EAU_GENANTE:
		voulue *= Reglages.FACTEUR_EAU

	var taux: float = Reglages.ACCELERATION
	if voulue.length_squared() < acteur.vitesse.length_squared():
		taux = Reglages.FREINAGE
	acteur.vitesse = acteur.vitesse.move_toward(voulue, taux * duree)

	var avant_sur_talus: bool = monde.marais.est_talus(acteur.position)
	var suivante: Vector2 = acteur.position + acteur.vitesse * duree
	if monde.marais.dans_la_grille(suivante):
		acteur.position = suivante
	else:
		# On GLISSE le long du bord au lieu de se figer. Annuler tout le
		# mouvement gelait le joueur dès qu'une diagonale poussait contre la
		# limite de la carte : seul l'axe bloqué s'annule.
		var en_x: Vector2 = Vector2(suivante.x, acteur.position.y)
		var en_y: Vector2 = Vector2(acteur.position.x, suivante.y)
		if monde.marais.dans_la_grille(en_x):
			acteur.position = en_x
			acteur.vitesse.y = 0.0
		elif monde.marais.dans_la_grille(en_y):
			acteur.position = en_y
			acteur.vitesse.x = 0.0
		else:
			acteur.vitesse = Vector2.ZERO

	acteur.eau_sous_les_pieds = monde.marais.profondeur_eau(acteur.position)
	if avant_sur_talus and not monde.marais.est_talus(acteur.position):
		acteur.vient_de_tomber = true
	_noyade(acteur, duree)

## Ce qui arrive à qui entre dans une eau où l'on ne marche plus.
##
## Pas de mort instantanée : on laisse au joueur le temps de comprendre et de
## ressortir — quarante-deux ticks, soit sept dixièmes de seconde. Passé ce
## délai, le sel reprend son dû et le corps est redéposé à la ladure.
func _noyade(acteur: Acteur, duree: float) -> void:
	if acteur.eau_sous_les_pieds <= Reglages.EAU_MORTELLE:
		acteur.ticks_immerge = 0
		return
	# On coule : plus de course, plus d'élan. On se débat.
	acteur.vitesse = acteur.vitesse.limit_length(
		Reglages.VITESSE_MARCHE * Reglages.FACTEUR_EAU * 0.6)
	acteur.ticks_immerge += 1
	if acteur.ticks_immerge >= Reglages.TICKS_DE_NOYADE:
		acteur.ticks_immerge = 0
		acteur.blesser(acteur.vie_max * 4.0)

func _endurance(acteur: Acteur, duree: float) -> void:
	if acteur.repos_avant_regen > 0:
		acteur.repos_avant_regen -= 1
		return
	if acteur.etat == Acteur.Etat.LIBRE or acteur.etat == Acteur.Etat.DOULEUR:
		acteur.endurance = minf(Reglages.ENDURANCE_MAX,
			acteur.endurance + Reglages.ENDURANCE_REGEN * duree)

func _tourner_vers(depuis: float, vers: float, duree: float) -> float:
	var pas: float = Reglages.VITESSE_CAP * duree
	return depuis + clampf(angle_difference(depuis, vers), -pas, pas)

## Ce qu'il advient d'un corps mort.
##
## Un paludier n'est pas effacé : il est saumuré, puis redéposé à la ladure. Un
## cristallisé, lui, reste où il est tombé — le sel le garde aussi, mais plus
## personne ne vient le chercher.
func _saumurer(monde: Monde, acteur: Acteur) -> void:
	if acteur.camp != Acteur.Camp.PALUDIER:
		return
	acteur.ticks_mort += 1
	if acteur.ticks_mort < Reglages.REPOS_APRES_MORT:
		return
	acteur.ticks_mort = 0
	acteur.ticks_immerge = 0
	acteur.etat = Acteur.Etat.LIBRE
	acteur.ticks_etat = 0
	acteur.ticks_geste = 0
	acteur.geste = &""
	acteur.intouchable = false
	acteur.vitesse = Vector2.ZERO
	acteur.vie = acteur.vie_max
	acteur.endurance = Reglages.ENDURANCE_MAX
	acteur.repos_avant_regen = 0
	acteur.position = monde.ladure
	monde.joueur_redepose_ce_tick = true

# ---------------------------------------------------------------------------
# Le travail
#
# Ouvrir une vanne et cueillir la fleur sont des gestes de métier, donc des
# règles de SIMULATION et non des scripts de niveau. C'est ce qui permet au
# tutoriel de les enseigner sans rien câbler, et aux raccourcis d'un acte
# entier d'être exactement le même geste.
# ---------------------------------------------------------------------------

func _interagir(monde: Monde, acteur: Acteur) -> void:
	if acteur.camp != Acteur.Camp.PALUDIER:
		return
	# Une vanne d'abord : c'est le geste qui commande le lieu — et il va dans
	# les DEUX sens. Un paludier ne fait pas qu'ouvrir : il DOSE. Une vanne
	# qu'on ne pouvait qu'ouvrir rendait le geste irréversible, et ouvrir
	# celle de l'œillet trop tôt noyait la fleur pour toujours : la saumure
	# d'aval se diluait sans retour possible. Fermer est le retour.
	var vanne: int = monde.marais.vanne_a_portee(acteur.position)
	if vanne >= 0:
		var ouverte: bool = not monde.marais.vannes[vanne].ouverte
		monde.marais.vannes[vanne].ouverte = ouverte
		if ouverte:
			monde.vanne_ouverte_ce_tick = vanne
		_travailler(acteur, &"vanne", Reglages.TICKS_TRAVAIL_VANNE)
		return
	# Sinon, la fleur, si le ciel l'a laissée prendre là où on se tient.
	var bassin: int = monde.marais.bassin_sous(acteur.position)
	if monde.marais.cueillir(bassin) > 0.0:
		monde.fleur += 1
		monde.fleur_cueillie_ce_tick = true
		_travailler(acteur, &"cueillette", Reglages.TICKS_TRAVAIL_CUEILLETTE)

## Engage un geste de travail : le corps s'immobilise le temps de le faire.
## C'est ce qui permet à la présentation de jouer le clip du métier — et ce
## qui donne au geste son petit coût d'engagement, comme tout dans ce jeu.
func _travailler(acteur: Acteur, nom: StringName, ticks: int) -> void:
	acteur.etat = Acteur.Etat.TRAVAIL
	acteur.ticks_etat = ticks
	acteur.ticks_geste = 0
	acteur.geste = nom

# ---------------------------------------------------------------------------
# Les coups
# ---------------------------------------------------------------------------

## Un coup touche quand le tick du geste tombe dans sa fenêtre, que la cible est
## dans la portée et dans l'arc. C'est tout : pas de test de collision, pas de
## physique. Une fenêtre en ticks et un arc, c'est reproductible partout.
func _resoudre_coups(monde: Monde) -> void:
	for attaquant: Acteur in monde.acteurs:
		if attaquant.etat != Acteur.Etat.FRAPPE:
			continue
		var geste: Geste = monde.geste_nomme(attaquant.geste)
		if geste == null or not geste.coup_actif(attaquant.ticks_geste):
			continue
		# Le las TRAVAILLE avant de frapper. Tiré au fond d'un œillet mûr et
		# presque sec, il ramène du gros sel — c'est son seul emploi véritable,
		# et c'est ce qui rend les cristallisés tristes plutôt que monstrueux :
		# ils refont exactement ce geste-là.
		# Une part par GESTE, au premier tick de la fenêtre — pas une par tick :
		# la fenêtre en compte onze, et le compteur montait de onze par coup.
		# Et une part PRISE au bassin : le stock s'épuise, l'œillet se racle.
		if attaquant.ticks_geste == geste.debut_coup \
				and attaquant.camp == Acteur.Camp.PALUDIER:
			var sous: int = monde.marais.bassin_sous(attaquant.position)
			if monde.marais.tirer_gros_sel(sous):
				monde.gros_sel += 1
				monde.sel_tire_ce_tick = true

		var avant: Vector2 = Vector2(sin(attaquant.cap), cos(attaquant.cap))
		for cible: Acteur in monde.acteurs:
			if cible.id == attaquant.id or not cible.vivant():
				continue
			if cible.camp == attaquant.camp:
				continue
			if cible.intouchable:
				continue
			# La fenêtre est une FENÊTRE : chaque tick peut toucher, mais jamais
			# deux fois le même corps dans le même geste. Sans cette garde, un
			# corps présent dès l'ouverture prenait un coup PAR TICK — onze fois
			# les dégâts — et mourait dans un seul balayage.
			if attaquant.touches.has(cible.id):
				continue
			var ecart: Vector2 = cible.position - attaquant.position
			var distance: float = ecart.length()
			if distance > geste.portee or distance < 0.001:
				continue
			var angle: float = rad_to_deg(absf(avant.angle_to(ecart)))
			if angle > geste.demi_angle:
				continue
			attaquant.touches.append(cible.id)
			cible.blesser(geste.degats)
			if cible.vivant():
				cible.etat = Acteur.Etat.DOULEUR
				cible.ticks_etat = DOULEUR_DUREE
				cible.ticks_geste = 0
				cible.geste = &"douleur"
				cible.vitesse = ecart.normalized() * 2.2

## Deux corps ne s'interpénètrent pas.
##
## On traversait le cristallisé comme du brouillard : on ressortait dans son
## dos, l'esquive n'avait pas de raison d'être latérale, et l'espace du combat
## ne voulait rien dire. La résolution est déterministe — ordre fixe des
## paires, chacun recule de la moitié du chevauchement — donc rejouable.
func _separer_les_corps(monde: Monde) -> void:
	var minimum: float = Reglages.RAYON_CORPS * 2.0
	for i: int in range(monde.acteurs.size()):
		var a: Acteur = monde.acteurs[i]
		if not a.vivant():
			continue
		for j: int in range(i + 1, monde.acteurs.size()):
			var b: Acteur = monde.acteurs[j]
			if not b.vivant():
				continue
			var ecart: Vector2 = b.position - a.position
			var distance: float = ecart.length()
			if distance >= minimum:
				continue
			# Deux corps exactement superposés n'ont pas d'axe : on en impose un.
			var axe: Vector2 = ecart / distance if distance > 0.0001 \
				else Vector2(1.0, 0.0)
			var pousse: float = (minimum - distance) * 0.5
			var recul_a: Vector2 = a.position - axe * pousse
			var recul_b: Vector2 = b.position + axe * pousse
			if monde.marais.dans_la_grille(recul_a):
				a.position = recul_a
			if monde.marais.dans_la_grille(recul_b):
				b.position = recul_b

# ---------------------------------------------------------------------------
# Les cristallisés
# ---------------------------------------------------------------------------

## L'intention d'un cristallisé.
##
## Ce ne sont pas des zombies : ce sont des gestes qui continuent. Celui-ci
## rejoue le seul mouvement qu'il ait jamais fait — tirer au las — et il le
## rejoue qu'il y ait quelqu'un devant lui ou non. Il s'approche parce que le
## sel est là où est le joueur, pas parce qu'il le veut.
func decider(monde: Monde, acteur: Acteur) -> Commande:
	var commande: Commande = Commande.new()
	if acteur.camp != Acteur.Camp.CRISTALLISE or not acteur.peut_agir():
		return commande
	if acteur.attente > 0:
		acteur.attente -= 1
	var proie: Acteur = monde.joueur()
	if proie == null or not proie.vivant():
		return commande

	var geste: Geste = monde.geste_nomme(&"las_lourd")
	var portee: float = 4.0
	if geste != null:
		portee = geste.portee * 0.82

	var ecart: Vector2 = proie.position - acteur.position
	var distance: float = ecart.length()
	commande.cap = atan2(ecart.x, ecart.y)
	if distance > portee:
		commande.direction = ecart.normalized()
	elif acteur.attente <= 0:
		commande.frappe = true
	return commande
