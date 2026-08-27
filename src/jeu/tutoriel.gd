## Les sept étapes de l'étier.
##
## « Sept étapes, aucune n'est un panneau de texte hors-fiction. Chacune est un
## geste de paludier qui se trouve être aussi une touche. »
##
## Ce fichier ne fait donc que deux choses : il REGARDE la simulation pour
## savoir si le geste a été fait, et il pose une consigne courte, dans le
## vocabulaire du métier. Il ne câble rien. Ouvrir une vanne, tirer au las,
## cueillir la fleur sont des règles de la simulation : le tutoriel se contente
## de les nommer dans l'ordre où on les apprend.
class_name Tutoriel
extends RefCounted

enum Etape {
	## Marcher sur un talus. Étroit, eau des deux côtés.
	MARCHER,
	## Ouvrir une vanne. Le premier geste du jeu n'est pas un coup.
	VANNE,
	## Le las. Tirer le sel au fond, vers la ladure.
	LAS,
	## Le premier cristallisé. Il rejoue le geste du las.
	LEVEE,
	## L'esquive, apprise contre ce geste-là : large, lisible, lent.
	ESQUIVE,
	## La ladure. Se reposer, comprendre que mourir ne rend pas au néant.
	LADURE,
	## Le vent d'est. La fleur se forme. On apprend à la cueillir.
	FLEUR,
	FINI,
}

## Nombre de gestes du las à donner dans l'œillet avant de passer.
const GESTES_DE_LAS: int = 3
## Distance à laquelle un lieu est « atteint », en mètres.
const APPROCHE: float = 2.2
## Montée du vent d'est, en unités par seconde.
const MONTEE_DU_VENT: float = 0.13
## Évaporation apportée par le vent d'est, en mètres d'eau par seconde.
const EVAPORATION_VENT: float = 0.0020

var etape: Etape = Etape.MARCHER

var _sel_tire: int = 0
var _esquives: int = 0
var _cristallise: Acteur = null
var _etat_precedent: int = Acteur.Etat.LIBRE
var _entre: bool = false

## Ce que le joueur doit comprendre, en une ligne, dans les mots du métier.
func consigne() -> String:
	match etape:
		Etape.MARCHER:
			return "Le talus fait quatre-vingts centimètres. L'eau est des deux côtés."
		Etape.VANNE:
			return "La mer monte. Ouvre la porte et laisse l'eau descendre."
		Etape.LAS:
			return "Le sel a pris au fond. Tire-le vers la ladure."
		Etape.LEVEE:
			return "Il refait le seul geste qu'il ait jamais fait."
		Etape.ESQUIVE:
			if _cristallise != null and not _cristallise.vivant():
				return "Il est retombé. Garde le geste — il resservira."
			return "Le las est lent, et large. Sors de son arc."
		Etape.LADURE:
			return "La ladure. On y pose ce qu'on a tiré du fond."
		Etape.FLEUR:
			return "Le vent tourne à l'est. Elle prend en surface — cueille-la."
		_:
			return "La saison est commencée."

## La touche, et rien de plus. On n'explique pas « œillet ».
func indication() -> String:
	match etape:
		Etape.MARCHER:
			return "ZQSD"
		Etape.VANNE, Etape.LADURE, Etape.FLEUR:
			return "E"
		Etape.LAS, Etape.LEVEE:
			return "Clic gauche"
		Etape.ESQUIVE:
			return "Espace"
		_:
			return ""

## Progression chiffrée de l'étape en cours, de 0 à 1, ou -1 si elle ne se
## compte pas. Le bandeau s'en sert pour montrer qu'on avance.
func avancement() -> float:
	match etape:
		Etape.LAS:
			return clampf(float(_sel_tire) / float(GESTES_DE_LAS), 0.0, 1.0)
		_:
			return -1.0

## Un tick de tutoriel. Appelé APRÈS la simulation, pour lire ce qui vient
## d'arriver.
func progresser(monde: Monde, commande: Commande, duree: float) -> void:
	var joueur: Acteur = monde.joueur()
	if joueur == null:
		return
	if not _entre:
		_entre = true
		_entrer(monde)

	# On compte les esquives en observant la simulation, jamais l'entrée : une
	# esquive refusée faute d'endurance ne doit pas compter comme apprise.
	if joueur.etat == Acteur.Etat.ESQUIVE and _etat_precedent != Acteur.Etat.ESQUIVE:
		_esquives += 1
	_etat_precedent = joueur.etat

	if monde.sel_tire_ce_tick:
		_sel_tire += 1

	if _accompli(monde, joueur, commande):
		_passer(monde)

	if etape == Etape.FLEUR:
		# Le ciel change pendant qu'on joue, il ne bascule pas d'un coup.
		monde.vent_est = minf(0.62, monde.vent_est + MONTEE_DU_VENT * duree)
		monde.evaporation = EVAPORATION_VENT * monde.vent_est
		_doser_l_oeillet(monde)

## Le dosage : le geste central du métier, fait ici PAR le tutoriel.
##
## « Le paludier ouvre et ferme des passages à la main, au pied, pour doser ce
## qui descend. » La fleur exige une lame d'eau précise : trop peu, l'œillet
## est sec ; trop, la pellicule coule et la saumure se dilue. On admet donc
## une lame de trois centimètres puis on referme — et l'évaporation du vent
## d'est fait le reste. Le joueur VOIT le geste juste ; l'acte II le lui
## mettra dans les mains.
func _doser_l_oeillet(monde: Monde) -> void:
	var vanne: int = monde.marais.vanne_nommee(&"vanne_oeillet")
	if vanne < 0 or not monde.marais.vannes[vanne].ouverte:
		return
	var bassin: int = monde.marais.bassin_sous(Etier.OEILLET_DE_LA_FLEUR)
	if bassin >= 0 and monde.marais.bassins[bassin].profondeur() >= 0.030:
		monde.marais.vannes[vanne].ouverte = false

func _accompli(monde: Monde, joueur: Acteur, commande: Commande) -> bool:
	match etape:
		Etape.MARCHER:
			return joueur.position.distance_to(Etier.PORTE_DE_MAREE) <= APPROCHE
		Etape.VANNE:
			var porte: int = monde.marais.vanne_nommee(&"porte_de_maree")
			return porte >= 0 and monde.marais.vannes[porte].ouverte
		Etape.LAS:
			return _sel_tire >= GESTES_DE_LAS
		Etape.LEVEE:
			# Le cristallisé a porté son geste : le joueur a vu que son arme et
			# celle de l'ennemi sont le même outil. C'est là qu'on enseigne
			# l'esquive — et s'il l'a abattu pendant qu'il se levait, la leçon
			# passe quand même : exiger un geste d'un mort bloquait le tutoriel.
			return _cristallise != null and (_cristallise.geste == &"las_lourd"
				or not _cristallise.vivant())
		Etape.ESQUIVE:
			# Cette étape enseigne l'esquive, pas la victoire. Exiger en plus
			# que le cristallisé soit mort menait à une impasse : un joueur qui
			# l'abat sans jamais esquiver n'avait plus rien à esquiver, et le
			# tutoriel ne pouvait plus avancer. La leçon suffit.
			return _esquives >= 1
		Etape.LADURE:
			return commande.interagit \
				and joueur.position.distance_to(Etier.LADURE) <= APPROCHE
		Etape.FLEUR:
			return monde.fleur >= 1
		_:
			return false

func _passer(monde: Monde) -> void:
	if etape == Etape.FINI:
		return
	etape = (etape + 1) as Etape
	_entrer(monde)

## Ce que l'étape met en place en s'ouvrant.
func _entrer(monde: Monde) -> void:
	match etape:
		Etape.LEVEE:
			_lever_le_cristallise(monde)
		Etape.FLEUR:
			# Se reposer à la ladure l'a RÉCLAMÉE : c'est ici qu'on renaît
			# désormais. Avant ce repos, mourir redéposait à trente mètres du
			# premier pas — le checkpoint se gagne, comme tout dans ce jeu.
			monde.ladure = Etier.LADURE
			# On rouvre la vanne de l'œillet pour que sa saumure soit à la bonne
			# lame d'eau : trop peu, il est sec ; trop, la pellicule coule.
			var vanne: int = monde.marais.vanne_nommee(&"vanne_oeillet")
			if vanne >= 0:
				monde.marais.vannes[vanne].ouverte = true
		_:
			pass

## « Un paludier qui meurt dans son œillet ne pourrit pas. Il cristallise. Et au
## bout de quelques saisons, il se relève, refaisant du las le seul geste qu'il
## ait jamais fait. »
func _lever_le_cristallise(monde: Monde) -> void:
	if _cristallise != null:
		return
	var corps: Acteur = Acteur.new()
	corps.camp = Acteur.Camp.CRISTALLISE
	corps.position = Etier.LEVEE_DU_CRISTALLISE
	corps.vie = Reglages.VIE_CRISTALLISE
	corps.vie_max = Reglages.VIE_CRISTALLISE
	# Il SE LÈVE — trois secondes et demie de Zombie_Rise, le moment que le
	# lore promet. Le clip était chargé dans le rig et jamais joué : le
	# cristallisé apparaissait debout, comme posé là par l'éditeur.
	corps.etat = Acteur.Etat.TRAVAIL
	corps.ticks_etat = Reglages.TICKS_LEVEE
	corps.geste = &"levee"
	_cristallise = monde.ajouter(corps)

func cristallise() -> Acteur:
	return _cristallise
