## Les objets du métier, posés là où un paludier les aurait posés.
##
## Ceux-là ne sont pas semés : ils sont PLACÉS, et chacun raconte quelque chose.
## Une vanne a son cadre de bois et sa barre. Une ladure porte ce qu'on y a
## entassé et les outils qu'on y laisse. Une digue est jalonnée de pieux, parce
## qu'un talus d'argile s'effondre si personne ne le tient.
##
## C'est la règle du lore appliquée au décor : « dans les Salines, on se bat
## avec ce qui sert à travailler ». Alors le décor, lui aussi, ne montre que ce
## qui sert à travailler.
class_name Attirail
extends Node3D

const DOSSIER: String = "res://models/marais/props/"

var _marais: Marais = null
## Altitude imposée pour l'assemblage en cours (les cadres de vanne se posent
## sur le SEUIL de leur vanne, pas sur le fond du chenal qu'ils enjambent).
var _sol_impose: float = -1000.0

func garnir(marais: Marais) -> void:
	_marais = marais
	_ladure()
	_vannes(marais)
	_digue(marais)

## La ladure : la plateforme où l'on entasse ce qu'on a tiré du fond. C'est le
## seul endroit habité du niveau, et le point de repos.
func _ladure() -> void:
	var centre: Vector2 = Etier.LADURE
	_poser("brouette.glb", centre + Vector2(-1.35, 0.90), 0.9, 1.0)
	_poser("tonneau.glb", centre + Vector2(1.20, -0.60), 2.4, 1.0)
	_poser("tonneau_ouvert.glb", centre + Vector2(1.85, 0.15), 0.7, 1.0)
	_poser("panier_osier.glb", centre + Vector2(0.35, 1.30), 1.9, 1.0)
	_poser("panier_01.glb", centre + Vector2(-0.40, 1.55), 3.4, 1.0)
	_poser("seau_bois.glb", centre + Vector2(0.95, 1.55), 0.4, 1.0)
	_poser("planches_tas.glb", centre + Vector2(-2.20, -0.80), 1.2, 1.0)
	_poser("caisse.glb", centre + Vector2(-1.75, -1.60), 5.6, 1.0)
	_poser("sac_toile.glb", centre + Vector2(-0.90, -1.85), 2.1, 1.0)
	_poser("fagot.glb", centre + Vector2(2.40, 1.10), 1.5, 1.0)
	# Les outils du métier, posés contre le tas. Le las et la lousse sont les
	# armes du joueur : les voir traîner là, c'est dire qu'ils sont des outils.
	_poser("rateau.glb", centre + Vector2(2.05, -1.35), 4.2, 1.0)
	_poser("pelle.glb", centre + Vector2(2.45, -1.05), 4.6, 1.0)
	_poser("fourche.glb", centre + Vector2(-2.60, 0.30), 2.8, 1.0)
	_poser("etal_bois.glb", centre + Vector2(3.30, 0.40), 0.0, 1.0)
	# L'échelle vaut 1 : depuis que le calage se fait sur une taille voulue,
	# ce facteur MULTIPLIE la cible au lieu de multiplier le modèle. À 2,4 il
	# faisait de l'appentis une halle de six mètres.
	_poser("appentis_ossature.glb", centre + Vector2(4.20, -1.20), 0.0, 1.0)
	_poser("appentis_toit.glb", centre + Vector2(4.20, -1.20), 0.0, 1.0)

## Chaque vanne reçoit son cadre de bois. Sans lui, une vanne n'est qu'un trou
## dans un talus et le joueur ne voit pas où interagir.
func _vannes(marais: Marais) -> void:
	for vanne: Marais.Vanne in marais.vannes:
		var ou: Vector2 = vanne.position
		var large: bool = vanne.section >= 3.0
		# Tout le cadre se pose sur le SEUIL : les pieds décalés d'une porte
		# tombaient dans le chenal qu'elle enjambe, et la porte de marée — le
		# deuxième geste du tutoriel — pendait à 1,53 m au-dessus du fond.
		_sol_impose = marais.hauteur_sol(vanne.position)
		_poser("pieu.glb", ou + Vector2(-0.55, 0.0), 0.0, 1.0)
		_poser("pieu.glb", ou + Vector2(0.55, 0.0), 0.0, 1.0)
		_poser("poutre.glb", ou + Vector2(0.0, 0.10), PI * 0.5, 1.0)
		if large:
			# La porte de marée est une vraie porte : elle gronde, elle se voit.
			_poser("planches.glb", ou + Vector2(0.0, -0.35), PI * 0.5, 1.3)
			_poser("barriere_passage.glb", ou + Vector2(0.0, 0.85), PI * 0.5, 1.0)
			_poser("panneau_bois.glb", ou + Vector2(-1.10, 0.55), 0.6, 1.0)
		else:
			_poser("planche.glb", ou + Vector2(0.0, -0.28), PI * 0.5, 0.9)
		_sol_impose = -1000.0

## Des pieux le long de la digue, à intervalles inégaux : un talus d'argile se
## tient, et une régularité parfaite trahirait tout de suite la machine.
func _digue(marais: Marais) -> void:
	var alea: RandomNumberGenerator = RandomNumberGenerator.new()
	alea.seed = 90210
	var z: float = 3.0
	while z < 41.0:
		var ou: Vector2 = Vector2(Etier.AXE_DIGUE + alea.randf_range(-0.16, 0.16), z)
		if marais.est_talus(ou):
			_poser("pieu.glb", ou, alea.randf_range(0.0, TAU),
				alea.randf_range(0.7, 1.0))
		z += alea.randf_range(3.4, 6.8)
	var x: float = 12.0
	while x < 41.0:
		var ou: Vector2 = Vector2(x, Etier.AXE_CHAUSSEE + alea.randf_range(-0.14, 0.14))
		if marais.est_talus(ou):
			_poser("pieu.glb", ou, alea.randf_range(0.0, TAU),
				alea.randf_range(0.7, 1.0))
		x += alea.randf_range(4.2, 8.5)

## Hauteur voulue de chaque objet, en mètres. Ce qui n'est pas listé garde sa
## taille de fichier — les props de thebasemesh sont à l'échelle réelle, et on
## ne corrige que ce qui en a besoin.
const HAUTEURS: Dictionary[String, float] = {
	"tonneau.glb": 0.86, "tonneau_ouvert.glb": 0.86, "tonneau_bois.glb": 0.90,
	"caisse.glb": 0.62, "caisse_grande.glb": 0.80, "panier_01.glb": 0.42,
	"panier_osier.glb": 0.40, "seau_bois.glb": 0.32, "sac_toile.glb": 0.55,
	"fagot.glb": 0.40, "planches_tas.glb": 0.55, "brouette.glb": 0.75,
	"etal_bois.glb": 1.05, "appentis_ossature.glb": 2.30,
	"appentis_toit.glb": 2.60, "pieu.glb": 1.10, "poutre.glb": 0.22,
	"planche.glb": 0.10, "planches.glb": 0.12, "barriere_passage.glb": 1.05,
	"panneau_bois.glb": 1.20, "rateau.glb": 1.85, "pelle.glb": 1.05,
	"fourche.glb": 2.05,
}

## Objets PLATS ou COUCHÉS, calés sur leur plus grande dimension. Les caler
## par la hauteur, comme les autres, faisait d'une planche de six centimètres
## d'épaisseur une dalle de deux mètres soixante, et d'un appentis une halle
## de six mètres. C'est leur longueur qu'on lit, pas leur épaisseur.
const DIMENSIONS: Dictionary[String, float] = {
	"planche.glb": 1.60, "planches.glb": 1.30, "planches_demi.glb": 0.90,
	"poutre.glb": 1.90, "etal_bois.glb": 1.70, "appentis_ossature.glb": 2.60,
	"appentis_toit.glb": 2.80, "appentis_plancher.glb": 2.60,
	"barriere_passage.glb": 1.45, "barriere.glb": 1.45,
	"cloture_basse.glb": 1.45, "planches_tas.glb": 1.10,
}

func _poser(fichier: String, ou: Vector2, cap: float, echelle: float) -> void:
	var chemin: String = DOSSIER + fichier
	if not ResourceLoader.exists(chemin):
		push_warning("Prop introuvable : %s" % chemin)
		return
	var paquet: PackedScene = load(chemin) as PackedScene
	if paquet == null:
		return
	var objet: Node3D = paquet.instantiate() as Node3D
	if objet == null:
		return
	add_child(objet)
	# Caler AVANT de poser : `caler_hauteur` écrit `scale`, et l'écraser
	# ensuite remettrait l'objet à la taille de son fichier.
	if DIMENSIONS.has(fichier):
		var grande: float = DIMENSIONS[fichier]
		var _d: float = Echelle.caler_dimension(objet, grande * echelle)
	elif HAUTEURS.has(fichier):
		var voulue: float = HAUTEURS[fichier]
		var _f: float = Echelle.caler_hauteur(objet, voulue * echelle)
	else:
		objet.scale = Vector3.ONE * echelle
	# Le sol RÉEL, pas une constante : treize props sur cinquante-six posés à
	# « hauteur de talus » flottaient au-dessus d'un bassin ou d'un chenal.
	var sol: float = _sol_impose
	if sol < -999.0:
		sol = _marais.hauteur_sol(ou) if _marais != null \
			else Reglages.HAUTEUR_TALUS
	objet.position = Vector3(ou.x, sol - 0.02, ou.y)
	objet.rotation.y = cap
