## Les oiseaux du marais.
##
## Un marais salant sans oiseaux est une flaque. Ce sont eux qui disent que le
## lieu est vivant, et ils le disent d'autant mieux qu'ils ne s'occupent pas du
## joueur : les échassiers travaillent leur vase, les mouettes tournent haut.
##
## Deux familles, deux traitements :
##   — les POSÉS se tiennent dans l'eau peu profonde, immobiles ou presque.
##     C'est là qu'un héron passe sa journée ;
##   — les TOURNANTS décrivent des cercles lents au-dessus du marais, chacun sur
##     son propre cercle et à sa propre allure, sinon ils forment un manège.
class_name Oiseaux
extends Node3D

const DOSSIER: String = "res://models/marais/faune/"

## Hauteur voulue d'un oiseau posé, en mètres. Un héron fait un mètre, une
## échasse quarante centimètres — et le fichier n'en sait rien : mesurés, les
## vingt-six oiseaux versés vont de 0,50 m à CENT QUATRE-VINGT-DIX-SEPT MÈTRES.
const TAILLE_POSES: Dictionary[String, float] = {
	"heron.glb": 0.98, "heron_gris.glb": 0.94, "aigrette.glb": 0.62,
	"grande_aigrette.glb": 0.92, "echasse.glb": 0.36, "canard.glb": 0.34,
	"canard_colvert.glb": 0.32, "oie_posee.glb": 0.55,
	"mouette_posee.glb": 0.38,
}
## Envergure voulue d'un oiseau en vol, en mètres.
const ENVERGURES: Dictionary[String, float] = {
	"mouette_vol.glb": 1.15, "goeland_planeur.glb": 1.45,
	"mouette_planeur.glb": 1.20, "echassier_vol.glb": 1.70,
	"oiseau_vol_leger.glb": 0.85, "oiseau_vol_petit.glb": 0.70,
	"pigeon_vol.glb": 0.65,
}

class Tournant extends RefCounted:
	var noeud: Node3D = null
	var centre: Vector3 = Vector3.ZERO
	var rayon: float = 20.0
	var altitude: float = 14.0
	var vitesse: float = 0.16
	var phase: float = 0.0

var _tournants: Array[Tournant] = []

func peupler(marais: Marais) -> void:
	var alea: RandomNumberGenerator = RandomNumberGenerator.new()
	alea.seed = 5150
	var emprise: Rect2 = marais.etendue()
	var centre: Vector2 = emprise.get_center()

	# Les échassiers : dans l'eau, jamais sur le chemin du joueur.
	var poses: PackedStringArray = PackedStringArray([
		"heron.glb", "heron_gris.glb", "aigrette.glb", "grande_aigrette.glb",
		"echasse.glb", "canard.glb", "canard_colvert.glb", "oie_posee.glb",
		"mouette_posee.glb"])
	var places: int = 0
	var essais: int = 0
	while places < 14 and essais < 900:
		essais += 1
		var ou: Vector2 = Vector2(
			alea.randf_range(emprise.position.x + 2.0, emprise.end.x - 2.0),
			alea.randf_range(emprise.position.y + 2.0, emprise.end.y - 2.0))
		var eau: float = marais.profondeur_eau(ou)
		if eau < 0.01 or eau > 0.16:
			continue
		if ou.distance_to(Etier.DEPART) < 6.0:
			continue
		var fichier: String = poses[alea.randi_range(0, poses.size() - 1)]
		var oiseau: Node3D = _charger(fichier)
		if oiseau == null:
			continue
		add_child(oiseau)
		var voulue: float = 0.5
		if TAILLE_POSES.has(fichier):
			voulue = TAILLE_POSES[fichier]
		var _f: float = Echelle.caler_hauteur(oiseau, voulue)
		oiseau.position = Vector3(ou.x, marais.niveau_eau(ou) - 0.03, ou.y)
		oiseau.rotation.y = alea.randf_range(0.0, TAU)
		_jouer(oiseau, PackedStringArray(["idle", "Idle", "static",
			"Standing Idle", "BirdRig|Standing Idle", "default-loop"]))
		places += 1

	# Les tournants : haut, lents, chacun sur son cercle.
	var voliers: PackedStringArray = PackedStringArray([
		"mouette_vol.glb", "goeland_planeur.glb", "mouette_planeur.glb",
		"echassier_vol.glb", "oiseau_vol_leger.glb", "oiseau_vol_petit.glb",
		"pigeon_vol.glb"])
	for i: int in range(9):
		var fichier: String = voliers[i % voliers.size()]
		var oiseau: Node3D = _charger(fichier)
		if oiseau == null:
			continue
		add_child(oiseau)
		var envergure: float = 1.1
		if ENVERGURES.has(fichier):
			envergure = ENVERGURES[fichier]
		var _e: float = Echelle.caler_envergure(oiseau, envergure)
		var t: Tournant = Tournant.new()
		t.noeud = oiseau
		t.centre = Vector3(centre.x + alea.randf_range(-18.0, 18.0), 0.0,
			centre.y + alea.randf_range(-14.0, 14.0))
		t.rayon = alea.randf_range(11.0, 34.0)
		t.altitude = alea.randf_range(7.0, 22.0)
		t.vitesse = alea.randf_range(0.09, 0.24) * (1.0 if i % 2 == 0 else -1.0)
		t.phase = alea.randf_range(0.0, TAU)
		_tournants.append(t)
		_jouer(oiseau, PackedStringArray(["Gliding", "BirdRig|Gliding",
			"Flapping", "BirdRig|Flapping", "ArmatureAction", "Flying",
			"storkFly_B_", "Take 001"]))

func _process(delta: float) -> void:
	for t: Tournant in _tournants:
		t.phase += t.vitesse * delta
		var ou: Vector3 = t.centre + Vector3(
			cos(t.phase) * t.rayon, t.altitude, sin(t.phase) * t.rayon)
		t.noeud.position = ou
		# Il regarde là où il va : la tangente au cercle, pas son centre.
		var tangente: Vector3 = Vector3(-sin(t.phase), 0.0, cos(t.phase)) \
			* signf(t.vitesse)
		t.noeud.rotation.y = atan2(tangente.x, tangente.z)
		# Une aile qui tourne s'incline. Sans ce roulis, l'oiseau glisse à plat
		# comme une décalque.
		t.noeud.rotation.z = -signf(t.vitesse) * 0.28

func _charger(fichier: String) -> Node3D:
	var chemin: String = DOSSIER + fichier
	if not ResourceLoader.exists(chemin):
		push_warning("Oiseau introuvable : %s" % chemin)
		return null
	var paquet: PackedScene = load(chemin) as PackedScene
	if paquet == null:
		return null
	return paquet.instantiate() as Node3D

## Joue le premier clip disponible parmi les noms proposés. Les vingt-six
## oiseaux viennent de sources différentes et ne nomment pas leurs animations
## de la même façon : on essaie, dans l'ordre, et on se tait si rien ne colle.
func _jouer(oiseau: Node3D, noms: PackedStringArray) -> void:
	var lecteur: AnimationPlayer = Animateur.trouver_lecteur(oiseau)
	if lecteur == null:
		return
	for nom: String in noms:
		if lecteur.has_animation(StringName(nom)):
			lecteur.play(StringName(nom))
			lecteur.speed_scale = randf_range(0.82, 1.18)
			# Chacun entre dans son cycle à un moment différent, sinon les neuf
			# battent des ailes exactement ensemble.
			lecteur.seek(randf() * lecteur.get_animation(
				StringName(nom)).length, true)
			return
	# À défaut, le premier clip du fichier, quel qu'il soit.
	var liste: PackedStringArray = lecteur.get_animation_list()
	if liste.size() > 0:
		lecteur.play(StringName(liste[0]))
