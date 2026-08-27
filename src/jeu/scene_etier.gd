## L'étier : la scène jouable du tutoriel.
##
## Elle assemble et cadence, elle ne décide de rien. La simulation avance au
## tick dans `_physics_process` ; tout le reste — corps, caméra, eau, bandeau —
## se contente de recopier son état à l'image, ce qui est l'invariant 2 rendu
## littéral.
class_name SceneEtier
extends Node3D

var monde: Monde = null
var simulation: Simulation = Simulation.new()
var tutoriel: Tutoriel = Tutoriel.new()

var _vue_marais: VueMarais = null
var _semis: Semis = null
var _oiseaux: Oiseaux = null
var _ambiance: Ambiance = null
var _ciel: Ciel = null
var _camera: CameraRig = null
var _hud: Hud = null
var _corps: Dictionary[int, VueActeur] = {}
var _derniere_commande: Commande = Commande.new()

func _ready() -> void:
	monde = Monde.new()
	monde.marais = Etier.batir()
	monde.marais.maree(Etier.MAREE_HAUTE)
	monde.ladure = Etier.LADURE
	var las: Geste = load("res://data/combat/las_lourd.tres") as Geste
	if las != null:
		monde.gestes[las.nom] = las

	var joueur: Acteur = Acteur.new()
	joueur.camp = Acteur.Camp.PALUDIER
	joueur.position = Etier.DEPART
	# Il regarde vers le nord, c'est-à-dire vers la porte de marée : le premier
	# pas est indiqué par le cadrage, pas par une flèche.
	joueur.cap = 0.0
	var _pose: Acteur = monde.ajouter(joueur)

	_ciel = Ciel.new()
	add_child(_ciel)

	_vue_marais = VueMarais.new()
	_vue_marais.name = "Marais"
	add_child(_vue_marais)
	_vue_marais.construire(monde.marais, Bruit.commun())
	_vue_marais.prolonger(420.0, Reglages.HAUTEUR_TALUS - 0.06, Bruit.commun())

	_semis = Semis.new()
	_semis.name = "Semis"
	add_child(_semis)
	_semis.semer(monde.marais, 320.0)
	_semis.souffler(0.22)

	var attirail: Attirail = Attirail.new()
	attirail.name = "Attirail"
	add_child(attirail)
	attirail.garnir(monde.marais)

	_oiseaux = Oiseaux.new()
	_oiseaux.name = "Oiseaux"
	add_child(_oiseaux)
	_oiseaux.peupler(monde.marais)

	_camera = CameraRig.new()
	_camera.name = "Camera"
	add_child(_camera)
	_camera.regarder(monde.marais)
	_camera.lacet = PI

	_ambiance = Ambiance.new()
	_ambiance.name = "Ambiance"
	add_child(_ambiance)
	_ambiance.monter(monde.marais)

	_hud = Hud.new()
	add_child(_hud)

	_suivre_les_corps()

func _physics_process(_delta: float) -> void:
	if monde == null:
		return
	var joueur: Acteur = monde.joueur()
	if joueur == null:
		return

	var commande: Commande = Commande.new()
	if joueur.vivant():
		commande = Entree.lire(_camera.cap())
	_derniere_commande = commande

	var commandes: Dictionary[int, Commande] = {}
	commandes[joueur.id] = commande
	simulation.avancer(monde, commandes)
	tutoriel.progresser(monde, commande, Reglages.DUREE_TICK)
	_suivre_les_corps()

	# La simulation redépose elle-même le joueur à la ladure : la présentation
	# n'a qu'à remonter un corps neuf, l'arbre d'animation ayant une mort sans
	# retour qu'on ne rembobine pas.
	if monde.joueur_redepose_ce_tick:
		_remonter_le_corps(joueur)

func _process(delta: float) -> void:
	if monde == null:
		return
	var joueur: Acteur = monde.joueur()
	if joueur == null:
		return
	for id: int in _corps:
		var vue: VueActeur = _corps[id]
		if vue.acteur == null:
			continue
		var sol: float = monde.marais.hauteur_sol(vue.acteur.position)
		var geste: Geste = monde.geste_nomme(vue.acteur.geste)
		var duree: float = 0.0
		if geste != null:
			duree = float(geste.duree) * Reglages.DUREE_TICK
		vue.suivre(sol, duree, delta)

	_vue_marais.rafraichir(monde.vent_est)
	_ciel.regler(monde.vent_est)
	# Le vent d'est plie la végétation avant qu'on en parle : c'est le lieu qui
	# annonce la fleur, pas le bandeau.
	_semis.souffler(maxf(0.22, monde.vent_est))
	_camera.cadrer(Vector3(joueur.position.x,
		monde.marais.hauteur_sol(joueur.position), joueur.position.y), delta)
	_ambiance.suivre(monde, delta)
	_hud.rafraichir(monde, tutoriel)

func _exit_tree() -> void:
	# Les caches statiques survivent à la scène : on les rend avant que le
	# moteur ne compte ce qui reste, sinon il sort sur un message d'erreur.
	Maillage.vider()
	Bruit.vider()

## Monte un corps pour chaque acteur qui n'en a pas encore. C'est ainsi qu'un
## cristallisé apparaît : le tutoriel l'ajoute au monde, et la présentation le
## découvre au tick suivant sans qu'on ait rien à lui dire.
func _suivre_les_corps() -> void:
	for acteur: Acteur in monde.acteurs:
		if _corps.has(acteur.id):
			continue
		var vue: VueActeur = VueActeur.new()
		vue.name = "Corps_%d" % acteur.id
		add_child(vue)
		vue.monter(acteur, acteur.camp == Acteur.Camp.CRISTALLISE)
		_corps[acteur.id] = vue

## Le corps a joué sa mort : on le remonte à neuf plutôt que de rembobiner un
## arbre d'animation dont la mort est un aiguillage sans retour.
func _remonter_le_corps(joueur: Acteur) -> void:
	if _corps.has(joueur.id):
		var ancien: VueActeur = _corps[joueur.id]
		_corps.erase(joueur.id)
		ancien.queue_free()
	_suivre_les_corps()
