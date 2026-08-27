## Ramène n'importe quel modèle importé à la taille qu'il devrait avoir.
##
## Aucun des vingt-six oiseaux versés n'est à une échelle cohérente : mesurés,
## ils vont de cinquante centimètres à CENT QUATRE-VINGT-DIX-SEPT MÈTRES
## d'envergure. Les props sont plus sages mais viennent de trois trames
## différentes. Faire confiance à l'échelle d'un fichier n'est donc pas une
## option, et corriger fichier par fichier serait à refaire au prochain asset.
##
## On mesure ici, dans le moteur, sur la scène instanciée — donc en tenant
## compte des transformations de nœuds, ce qu'une lecture du glTF ne fait pas —
## puis on applique un facteur uniforme. Un modèle mal calibré devient
## impossible : c'est la taille VOULUE qui décide, pas celle qu'il portait.
class_name Echelle
extends RefCounted

## Boîte englobante d'une scène instanciée, dans le repère de sa racine.
##
## On additionne les boîtes de chaque maillage EN LEUR APPLIQUANT la chaîne de
## transformations qui les porte. C'est là toute la différence avec une lecture
## du fichier glTF : un modèle dont l'échelle vit dans ses nœuds mesure zéro
## quand on ne lit que ses sommets.
## La transformation propre de la racine est EXCLUE : la boîte est rendue dans
## son repère local. Sans ça, `caler_hauteur` mesurerait une taille qui contient
## déjà l'échelle qu'il vient de poser, et un second appel la remettrait au
## carré.
static func boite(racine: Node3D) -> AABB:
	var boites: Array[AABB] = []
	_collecter_local(racine, Transform3D.IDENTITY, boites)
	if boites.is_empty():
		return AABB()
	var totale: AABB = boites[0]
	for i: int in range(1, boites.size()):
		totale = totale.merge(boites[i])
	return totale

static func _collecter_local(noeud: Node, vers: Transform3D,
		dans: Array[AABB]) -> void:
	var maille: MeshInstance3D = noeud as MeshInstance3D
	if maille != null and maille.mesh != null:
		dans.append(vers * maille.mesh.get_aabb())
	for enfant: Node in noeud.get_children():
		var spatial: Node3D = enfant as Node3D
		var local: Transform3D = vers
		if spatial != null:
			local = vers * spatial.transform
		_collecter_local(enfant, local, dans)

## Cale la scène sur une HAUTEUR voulue, en mètres.
static func caler_hauteur(racine: Node3D, hauteur: float) -> float:
	return _caler(racine, hauteur, boite(racine).size.y)

## Cale la scène sur une LARGEUR voulue — pour un oiseau en vol, c'est son
## envergure, qui est la seule dimension qu'on lise vraiment de loin.
static func caler_envergure(racine: Node3D, envergure: float) -> float:
	var taille: Vector3 = boite(racine).size
	return _caler(racine, envergure, maxf(taille.x, taille.z))

## Cale sur la PLUS GRANDE dimension. C'est la bonne mesure pour tout ce qui
## est plat ou couché : une planche de six centimètres d'épaisseur ramenée à
## douze devient large de deux mètres soixante, et une toiture en devient une
## halle. Ce qui compte alors, c'est sa longueur, pas son épaisseur.
static func caler_dimension(racine: Node3D, dimension: float) -> float:
	var t: Vector3 = boite(racine).size
	return _caler(racine, dimension, maxf(maxf(t.x, t.y), t.z))

static func _caler(racine: Node3D, voulue: float, mesuree: float) -> float:
	if mesuree < 0.0001:
		push_warning("Boîte englobante dégénérée : %s reste à son échelle."
			% racine.name)
		return 1.0
	var facteur: float = voulue / mesuree
	racine.scale = Vector3.ONE * facteur
	return facteur
