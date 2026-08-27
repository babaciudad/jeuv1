## Une vue rapprochée d'un corps qui marche, pour juger du modèle et du
## mouvement.
##
## Ce n'est pas une pose figée : la simulation tourne vraiment, l'acteur reçoit
## vraiment une commande, et l'arbre d'animation la traduit vraiment. Une pose
## figée dirait seulement que le maillage se charge ; ceci dit que la chaîne
## entière fonctionne.
class_name ApercuCorps
extends Node3D

@export var oeil: Vector3 = Vector3(3.4, 1.75, 3.6)
@export var recul: float = 3.6
@export var hauteur_oeil: float = 1.35
@export var vent: float = 0.0
## Direction commandée, dans le plan du marais.
@export var direction: Vector2 = Vector2(0.0, 1.0)
@export var court: bool = false
@export var frappe_au_tick: int = -1
@export var cristallise: bool = false
@export var depart: Vector2 = Vector2(46.8, 12.0)

var monde: Monde = null
var simulation: Simulation = Simulation.new()
var vue: VueActeur = null

var _camera: Camera3D = null
var _vue_marais: VueMarais = null

func _ready() -> void:
	monde = Monde.new()
	monde.marais = Etier.batir()
	monde.marais.maree(Etier.MAREE_HAUTE)
	monde.gestes[&"las_lourd"] = load("res://data/combat/las_lourd.tres") as Geste

	var acteur: Acteur = Acteur.new()
	acteur.position = depart
	acteur.camp = Acteur.Camp.CRISTALLISE if cristallise else Acteur.Camp.PALUDIER
	var _pose: Acteur = monde.ajouter(acteur)

	var ciel: Ciel = Ciel.new()
	add_child(ciel)
	ciel.regler(vent)

	_vue_marais = VueMarais.new()
	add_child(_vue_marais)
	_vue_marais.construire(monde.marais, Bruit.commun())
	_vue_marais.prolonger(420.0, Reglages.HAUTEUR_TALUS - 0.06, Bruit.commun())
	_vue_marais.rafraichir(vent)

	vue = VueActeur.new()
	add_child(vue)
	vue.monter(acteur, cristallise)

	_camera = Camera3D.new()
	_camera.fov = 46.0
	_camera.far = 400.0
	add_child(_camera)
	_camera.make_current()
	_cadrer()

func _physics_process(_delta: float) -> void:
	if monde == null:
		return
	var commande: Commande = Commande.new()
	commande.direction = direction
	commande.court = court
	commande.cap = atan2(direction.x, direction.y)
	if frappe_au_tick >= 0 and monde.tick == frappe_au_tick:
		commande.frappe = true
	var commandes: Dictionary[int, Commande] = {}
	var joueur: Acteur = monde.joueur()
	if joueur == null:
		joueur = monde.acteurs[0]
	commandes[joueur.id] = commande
	simulation.avancer(monde, commandes)

func _process(delta: float) -> void:
	if vue == null or vue.acteur == null:
		return
	var sol: float = monde.marais.hauteur_sol(vue.acteur.position)
	var geste: Geste = monde.geste_nomme(vue.acteur.geste)
	var duree: float = 0.0
	if geste != null:
		duree = float(geste.duree) * Reglages.DUREE_TICK
	vue.suivre(sol, duree, delta)
	_vue_marais.rafraichir(vent)
	_cadrer()

## La caméra suit de dos, à hauteur d'épaule, sans jamais tourner d'elle-même :
## on juge le mouvement du corps, pas celui de la caméra.
func _cadrer() -> void:
	if _camera == null or vue == null or vue.acteur == null:
		return
	var a: Acteur = vue.acteur
	var avant: Vector3 = Vector3(sin(a.cap), 0.0, cos(a.cap))
	var cible: Vector3 = Vector3(a.position.x, 0.0, a.position.y)
	var sol: float = monde.marais.hauteur_sol(a.position)
	_camera.position = cible + Vector3(0.0, sol + hauteur_oeil, 0.0) - avant * recul
	_camera.look_at(cible + Vector3(0.0, sol + 1.0, 0.0), Vector3.UP)
