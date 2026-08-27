## Mesure la vitesse au sol de chaque clip de locomotion.
##
## Un clip de marche est joué SUR PLACE : rien dans le fichier ne dit à quelle
## allure il est censé faire avancer un corps. Si on se trompe, les pieds
## patinent — le personnage glisse comme sur de la glace, ou pédale dans le
## vide. C'est le défaut d'animation le plus visible d'un jeu en troisième
## personne, et il ne se voit pas sur une capture d'écran.
##
## On le mesure donc. À chaque pas de temps on regarde lequel des deux pieds
## est le plus bas — c'est celui qui porte — et de combien il s'est déplacé
## depuis le pas précédent. Un pied qui porte ne glisse pas sur le sol : c'est
## le SOL qui défile sous le corps, et la distance parcourue par ce pied dans
## le repère du personnage est exactement celle dont le corps aurait dû avancer.
extends SceneTree

const CLIPS: Array[StringName] = [
	&"Walk", &"Jog", &"Sprint", &"Walk_Carry",
	&"plus/Walk_Backwards", &"plus/Strafe_left", &"plus/Strafe_right",
	&"Zombie_Walk", &"plus/Zombie_Walk_2", &"Crouch_Walk"]
const ECHANTILLONS: int = 240

func _initialize() -> void:
	# gestes_base.glb porte le corps ET son lecteur d'animation ; corps.glb, lui,
	# n'a aucune animation, donc aucun AnimationPlayer. C'est donc le paquet de
	# gestes qui sert de rig, et le second paquet vient s'y greffer.
	var corps: PackedScene = load("res://models/humain/gestes_base.glb") as PackedScene
	if corps == null:
		push_error("gestes_base.glb introuvable")
		quit(2)
		return
	var rig: Node = corps.instantiate()
	root.add_child(rig)
	var lecteur: AnimationPlayer = _trouver_lecteur(rig)
	var squelette: Skeleton3D = _trouver_squelette(rig)
	if lecteur == null or squelette == null:
		push_error("lecteur=%s squelette=%s" % [str(lecteur), str(squelette)])
		quit(2)
		return

	_greffer(lecteur, "res://models/humain/gestes_plus.glb", &"plus")
	# Sans image traitée, un AnimationPlayer n'applique jamais sa pose : en
	# headless il faut le piloter à la main, pas à pas.
	lecteur.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

	print("OS (%d) : %s" % [squelette.get_bone_count(),
		", ".join(_noms_os(squelette).slice(0, 24))])
	var gauche: int = squelette.find_bone("foot_l")
	var droit: int = squelette.find_bone("foot_r")
	if gauche < 0 or droit < 0:
		gauche = squelette.find_bone("ball_l")
		droit = squelette.find_bone("ball_r")
	print("pieds : foot_l=%d foot_r=%d" % [gauche, droit])
	print("")
	print("%-26s %8s %8s %8s" % ["clip", "duree", "m/s", "pas"])

	for nom: StringName in CLIPS:
		if not lecteur.has_animation(nom):
			print("%-26s  absent" % nom)
			continue
		var clip: Animation = lecteur.get_animation(nom)
		var resultat: Array[float] = _mesurer(lecteur, squelette, nom, clip.length,
			gauche, droit)
		print("%-26s %7.2fs %7.2f %7d" % [nom, clip.length, resultat[0], int(resultat[1])])
	quit(0)

## Renvoie [vitesse en m/s, nombre de foulées détectées].
func _mesurer(lecteur: AnimationPlayer, squelette: Skeleton3D, nom: StringName,
		duree: float, gauche: int, droit: int) -> Array[float]:
	var distance: float = 0.0
	var precedent: int = -1
	var position_precedente: Vector3 = Vector3.ZERO
	var foulees: int = 0
	var pas_de_temps: float = duree / float(ECHANTILLONS)
	lecteur.play(nom)
	lecteur.seek(0.0, true, true)
	for i: int in range(ECHANTILLONS + 1):
		if i > 0:
			lecteur.advance(pas_de_temps)
		# La pose des os n'est recalculée qu'à la demande : sans ceci, on relit
		# la même pose de repos à chaque échantillon et toutes les vitesses
		# sortent à zéro.
		squelette.force_update_all_bone_transforms()
		var pg: Vector3 = _pose_globale(squelette, gauche).origin
		var pd: Vector3 = _pose_globale(squelette, droit).origin
		var porteur: int = gauche
		var position: Vector3 = pg
		if pd.y < pg.y:
			porteur = droit
			position = pd
		if porteur == precedent:
			var pas: Vector3 = position - position_precedente
			pas.y = 0.0
			distance += pas.length()
		else:
			foulees += 1
		precedent = porteur
		position_precedente = position
	if duree <= 0.0:
		return [0.0, 0.0]
	return [distance / duree, float(foulees)]

## Pose globale d'un os, calculée en remontant ses parents.
##
## `get_bone_global_pose` rendait obstinément la même valeur à tous les
## instants d'un clip, alors que la pose LOCALE du bassin, elle, était bien
## animée : son cache ne se rafraîchit pas hors d'une image de rendu. On
## chaîne donc les poses locales à la main, ce qui ne dépend d'aucun cache.
func _pose_globale(squelette: Skeleton3D, os: int) -> Transform3D:
	var accumule: Transform3D = Transform3D.IDENTITY
	var courant: int = os
	while courant >= 0:
		accumule = squelette.get_bone_pose(courant) * accumule
		courant = squelette.get_bone_parent(courant)
	return accumule

func _arbre(noeud: Node, marge: String) -> void:
	print("%s%s (%s)" % [marge, noeud.name, noeud.get_class()])
	for enfant: Node in noeud.get_children():
		_arbre(enfant, marge + "  ")

func _greffer(lecteur: AnimationPlayer, chemin: String, prefixe: StringName) -> void:
	var paquet: PackedScene = load(chemin) as PackedScene
	if paquet == null:
		return
	var source_rig: Node = paquet.instantiate()
	var source: AnimationPlayer = _trouver_lecteur(source_rig)
	if source == null:
		source_rig.free()
		return
	for nom: StringName in source.get_animation_library_list():
		var bibliotheque: AnimationLibrary = source.get_animation_library(nom)
		if bibliotheque != null and not lecteur.has_animation_library(prefixe):
			lecteur.add_animation_library(prefixe, bibliotheque)
	source_rig.free()

func _noms_os(squelette: Skeleton3D) -> PackedStringArray:
	var noms: PackedStringArray = PackedStringArray()
	for i: int in range(squelette.get_bone_count()):
		noms.append(squelette.get_bone_name(i))
	return noms

func _trouver_lecteur(noeud: Node) -> AnimationPlayer:
	var lecteur: AnimationPlayer = noeud as AnimationPlayer
	if lecteur != null:
		return lecteur
	for enfant: Node in noeud.get_children():
		var trouve: AnimationPlayer = _trouver_lecteur(enfant)
		if trouve != null:
			return trouve
	return null

func _trouver_squelette(noeud: Node) -> Skeleton3D:
	var squelette: Skeleton3D = noeud as Skeleton3D
	if squelette != null:
		return squelette
	for enfant: Node in noeud.get_children():
		var trouve: Skeleton3D = _trouver_squelette(enfant)
		if trouve != null:
			return trouve
	return null
