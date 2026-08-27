## Rend une scène hors écran et enregistre une image, avec ses chiffres.
##
## C'est l'œil du projet. Sans lui, « c'est beau » est une opinion ; avec lui,
## c'est un fichier qu'on regarde et des compteurs qu'on lit. Il tourne en
## rendu logiciel (lavapipe) sous Xvfb : l'image est donc juste, mais AUCUNE
## durée mesurée ici n'a de rapport avec une vraie carte graphique. On ne
## mesure ici que ce qui est indépendant du matériel : primitives, appels de
## dessin, objets à l'écran.
##
## Usage :
##   godot --path . --script res://outils/capture.gd -- \
##       scene=res://scenes/etier.tscn sortie=/tmp/vue.png images=30
extends SceneTree

## Images laissées passer avant la prise. Il en faut quelques-unes : les ombres,
## la brume volumétrique et le ciel se stabilisent sur plusieurs images.
var _restantes: int = 30
var _sortie: String = "/tmp/capture.png"
var _etat: int = 0

func _initialize() -> void:
	var chemin_scene: String = ""
	for brut: String in OS.get_cmdline_user_args():
		var morceaux: PackedStringArray = brut.split("=", true, 1)
		if morceaux.size() != 2:
			continue
		match morceaux[0]:
			"scene": chemin_scene = morceaux[1]
			"sortie": _sortie = morceaux[1]
			"images": _restantes = int(morceaux[1])

	if chemin_scene == "":
		push_error("capture : argument scene= manquant.")
		quit(2)
		return
	if not ResourceLoader.exists(chemin_scene):
		push_error("capture : scène introuvable : %s" % chemin_scene)
		quit(2)
		return

	var paquet: PackedScene = load(chemin_scene) as PackedScene
	if paquet == null:
		push_error("capture : %s n'est pas une PackedScene." % chemin_scene)
		quit(2)
		return
	root.add_child(paquet.instantiate())

func _process(_delta: float) -> bool:
	match _etat:
		0:
			_restantes -= 1
			if _restantes <= 0:
				_etat = 1
				_prendre()
		2:
			return true
	return false

func _prendre() -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var erreur: Error = image.save_png(_sortie)
	if erreur != OK:
		push_error("capture : écriture impossible (%d) : %s" % [erreur, _sortie])
		_etat = 2
		return

	# Les seuls chiffres qui veuillent dire quelque chose en rendu logiciel :
	# ils comptent ce que la scène demande, pas ce que le matériel encaisse.
	var primitives: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var dessins: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var video: int = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)

	print("CAPTURE %s" % _sortie)
	print("  taille      : %dx%d" % [image.get_width(), image.get_height()])
	print("  primitives  : %d" % primitives)
	print("  appels      : %d" % dessins)
	print("  mem video   : %.1f Mo" % (float(video) / 1048576.0))
	print("  noeuds      : %d" % root.get_tree().get_node_count())
	_etat = 2
