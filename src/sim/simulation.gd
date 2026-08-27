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
	var duree: float = Reglages.DUREE_TICK

	for acteur: Acteur in monde.acteurs:
		if not acteur.vivant():
			continue
		var commande: Commande = null
		if commandes.has(acteur.id):
			commande = commandes[acteur.id]
		if commande == null:
			commande = decider(monde, acteur)
		_avancer_acteur(monde, acteur, commande, duree)

	_resoudre_coups(monde)

	monde.marais.ecouler(duree)
	if monde.evaporation > 0.0:
		monde.marais.evaporer(monde.evaporation, duree)

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
			acteur.etat = Acteur.Etat.LIBRE
			acteur.ticks_etat = 0
			acteur.intouchable = false
			acteur.geste = &""
			acteur.ticks_geste = 0

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

	_deplacer(monde, acteur, commande, duree)
	_endurance(acteur, duree)

func _deplacer(monde: Monde, acteur: Acteur, commande: Commande,
		duree: float) -> void:
	var voulue: Vector2 = Vector2.ZERO

	match acteur.etat:
		Acteur.Etat.LIBRE:
			var allure: float = Reglages.VITESSE_MARCHE
			if commande.court and acteur.endurance > 0.0:
				allure = Reglages.VITESSE_COURSE
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
		acteur.vitesse = Vector2.ZERO

	acteur.eau_sous_les_pieds = monde.marais.profondeur_eau(acteur.position)
	if avant_sur_talus and not monde.marais.est_talus(acteur.position):
		acteur.vient_de_tomber = true

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
		# Un seul tick de la fenêtre porte réellement le coup, sinon une
		# fenêtre de neuf ticks infligerait neuf fois les dégâts.
		if attaquant.ticks_geste != geste.debut_coup:
			continue
		var avant: Vector2 = Vector2(sin(attaquant.cap), cos(attaquant.cap))
		for cible: Acteur in monde.acteurs:
			if cible.id == attaquant.id or not cible.vivant():
				continue
			if cible.camp == attaquant.camp:
				continue
			if cible.intouchable:
				continue
			var ecart: Vector2 = cible.position - attaquant.position
			var distance: float = ecart.length()
			if distance > geste.portee or distance < 0.001:
				continue
			var angle: float = rad_to_deg(absf(avant.angle_to(ecart)))
			if angle > geste.demi_angle:
				continue
			cible.blesser(geste.degats)
			if cible.vivant():
				cible.etat = Acteur.Etat.DOULEUR
				cible.ticks_etat = DOULEUR_DUREE
				cible.ticks_geste = 0
				cible.geste = &"douleur"
				cible.vitesse = ecart.normalized() * 2.2

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
	else:
		commande.frappe = true
	return commande
