## Enregistre la texture de bruit sur disque et en donne les statistiques.
##
## Un shader qui échantillonne une texture plate rend une image plate, et rien
## dans l'image ne dit que c'est la texture qui est en cause. On la regarde.
extends SceneTree

var _restantes: int = 30
var _fait: bool = false

func _initialize() -> void:
	# La génération est ASYNCHRONE : demander l'image tout de suite rend une
	# texture vide. On l'amorce, on laisse passer des images, puis on mesure.
	var _amorce: ImageTexture = Bruit.commun()
	root.add_child(TextureRect.new())

func _process(_delta: float) -> bool:
	if _fait:
		return true
	_restantes -= 1
	if _restantes > 0:
		return false
	var texture: ImageTexture = Bruit.commun()
	var image: Image = texture.get_image()
	if image == null:
		print("BRUIT : aucune image — la génération n'a pas abouti.")
		_fait = true
		return false
	var mini: Array[float] = [1.0, 1.0, 1.0]
	var maxi: Array[float] = [0.0, 0.0, 0.0]
	var somme: Array[float] = [0.0, 0.0, 0.0]
	var compte: int = 0
	for y: int in range(0, image.get_height(), 4):
		for x: int in range(0, image.get_width(), 4):
			var c: Color = image.get_pixel(x, y)
			var canaux: Array[float] = [c.r, c.g, c.b]
			for k: int in range(3):
				mini[k] = minf(mini[k], canaux[k])
				maxi[k] = maxf(maxi[k], canaux[k])
				somme[k] += canaux[k]
			compte += 1
	print("BRUIT %dx%d format=%d" % [image.get_width(), image.get_height(),
		image.get_format()])
	for k: int in range(3):
		print("  canal %d : min=%.3f max=%.3f moyenne=%.3f"
			% [k, mini[k], maxi[k], somme[k] / float(compte)])
	var err: Error = image.save_png("/tmp/bruit.png")
	print("  ecriture=%d" % err)
	_fait = true
	return false
