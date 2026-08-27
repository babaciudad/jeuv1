## Les textures de bruit dont vivent les shaders.
##
## Rien n'est importé : tout est calculé au démarrage. Tant que la provenance
## des textures n'est pas tranchée, un bruit fabriqué ici a une licence claire
## — la nôtre — et ne coûte pas un octet au dépôt.
##
## TROIS bruits, et pas un seul répété. `NoiseTexture2D` produit du L8 : ses
## trois canaux portent la même valeur, si bien qu'un shader qui lit `.r` pour
## les rides, `.g` pour le grain et `.b` pour les plaques lit trois fois le même
## motif et les superpose exactement. Toute la matière disparaît alors dans une
## seule couche uniforme, et l'image paraît lisse sans qu'aucun réglage ne
## puisse y changer quoi que ce soit. On assemble donc l'image à la main.
class_name Bruit
extends RefCounted

const COTE: int = 512

static var _cache: ImageTexture = null

## Vide le cache, pour que la fermeture du jeu soit silencieuse.
static func vider() -> void:
	_cache = null

static func _couche(graine: int, frequence: float, octaves: int) -> FastNoiseLite:
	var bruit: FastNoiseLite = FastNoiseLite.new()
	bruit.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bruit.seed = graine
	bruit.frequency = frequence
	bruit.fractal_type = FastNoiseLite.FRACTAL_FBM
	bruit.fractal_octaves = octaves
	bruit.fractal_lacunarity = 2.05
	bruit.fractal_gain = 0.48
	return bruit

## Un bruit sans couture à trois motifs indépendants :
##   rouge  — les rides de l'eau, fin et nerveux ;
##   vert   — le grain de l'argile, moyen ;
##   bleu   — les grandes plaques, lent, qui font la géologie.
static func commun() -> ImageTexture:
	if _cache != null:
		return _cache
	var couches: Array[FastNoiseLite] = [
		_couche(18040, 0.030, 3),
		_couche(77213, 0.014, 4),
		_couche(4051, 0.0055, 3)]
	var image: Image = Image.create_empty(COTE, COTE, false, Image.FORMAT_RGB8)
	# Les couches sont échantillonnées sur un TORE : deux tours de cercle par
	# axe. C'est ce qui rend la texture répétable sans couture visible, ce dont
	# on a absolument besoin sur un sol de plusieurs hectares.
	for y: int in range(COTE):
		var av: float = TAU * float(y) / float(COTE)
		for x: int in range(COTE):
			var au: float = TAU * float(x) / float(COTE)
			var teinte: Color = Color(0.0, 0.0, 0.0, 1.0)
			for k: int in range(3):
				var rayon: float = 64.0 * (1.0 + float(k))
				var valeur: float = couches[k].get_noise_3d(
					cos(au) * rayon, sin(au) * rayon,
					cos(av) * rayon + sin(av) * rayon)
				teinte[k] = clampf(valeur * 0.5 + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, teinte)
	image.generate_mipmaps()
	_cache = ImageTexture.create_from_image(image)
	return _cache
