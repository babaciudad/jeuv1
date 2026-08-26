## Filme une sequence de jeu et fait le tour des cinq zones du niveau.
##
## Se branche en autoload le temps d'une prise :
##
##   [autoload]
##   _Film="*res://tools/film.gd"
##   godot --path . --resolution 1280x720 --rendering-driver vulkan -- --host
##
## Outil de verification, hors jeu. Il n'est jamais charge par le jeu lui-meme.
extends Node

const DOSSIER: String = "/home/user/shots/film"
## Ou se teleporter, et sous quel nom garder l'image.
const ZONES: Dictionary[int, Vector2] = {
	180: Vector2(0.0, -22.0), 196: Vector2(0.0, 6.0),
	212: Vector2(0.0, 20.0), 228: Vector2(-8.0, 74.0),
	244: Vector2(0.0, 128.0),
}
const NOMS: Dictionary[int, String] = {
	188: "zone1_halle", 204: "zone2_bassin", 220: "zone3_parvis",
	236: "zone4_tables", 252: "zone5_arene",
}
var _frame: int = 0
var _boot: NetBootstrap = null
var _view: GameView = null
var _oeil: Camera3D = null

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DOSSIER)

func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_walk(child))
	return out

func _process(_delta: float) -> void:
	_frame += 1
	if _boot == null:
		for node: Node in _walk(get_tree().root):
			if node is NetBootstrap:
				_boot = node as NetBootstrap
			if node is GameView:
				_view = node as GameView
	if _boot == null or _view == null:
		if _frame > 400:
			get_tree().quit(1)
		return
	var world: World = _view.simulated_world()
	if world == null:
		return
	var me: Actor = world.local_actor()
	if me == null:
		return
	if _frame == 20:
		# Face au premier cristallise du parvis.
		me.position = Vector2(-9.0, 15.0)
		me.facing = Vector2(0.0, 1.0)
	# 22 -> 118 : on marche sur lui et on frappe trois fois. Le combat entier
	# doit tenir dans la pellicule : approche, coup, encaissement, chute.
	if _frame >= 24 and _frame < 40:
		_boot.submit_command(Command.Type.MOVE, {"d": Vector2(0.0, 1.0)})
	if _frame == 46 or _frame == 78 or _frame == 110:
		_boot.submit_command(Command.Type.ATTACK,
			{"i": 0, "d": Vector2(0.0, 1.0)})
	if _frame >= 24 and _frame < 136 and _frame % 4 == 0:
		await _prise("combat_%03d" % _frame)
	if _frame == 140:
		me.position = Vector2(0.0, -26.0)
		me.facing = Vector2(0.0, 1.0)
	if _frame == 144:
		_boot.submit_command(Command.Type.DODGE, {"d": Vector2(0.0, 1.0)})
	if _frame >= 145 and _frame < 169 and _frame % 2 == 0:
		await _prise("roulade_%03d" % _frame)

	# Tour des cinq zones : on se pose, on laisse une image passer, on garde.
	if _frame >= 172:
		_boot.submit_command(Command.Type.MOVE, {"d": Vector2(0.0, 0.12)})
	if ZONES.has(_frame):
		me.position = ZONES[_frame]
		me.facing = Vector2(0.0, 1.0)
	if NOMS.has(_frame):
		await _prise(NOMS[_frame])
	# Vue d'ensemble : une camera a nous, tres haut, pour voir la silhouette du
	# niveau entier et reperer ce qui flotte.
	if _frame == 262:
		var oeil: Camera3D = Camera3D.new()
		add_child(oeil)
		oeil.fov = 55.0
		oeil.position = Vector3(0.0, 96.0, 178.0)
		oeil.look_at(Vector3(0.0, 0.0, 58.0))
		oeil.current = true
		_oeil = oeil
	if _frame == 268:
		await _prise("vue_densemble")
	if _frame == 272 and _oeil != null:
		_oeil.position = Vector3(-96.0, 40.0, 60.0)
		_oeil.look_at(Vector3(0.0, 8.0, 70.0))
	if _frame == 278:
		await _prise("vue_ouest")
	if _frame == 282 and _oeil != null:
		_oeil.position = Vector3(-4.0, 14.0, 88.0)
		_oeil.look_at(Vector3(20.0, 14.0, 112.0))
	if _frame == 288:
		await _prise("vue_arene")
	if _frame > 294:
		get_tree().quit(0)

func _prise(nom: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [DOSSIER, nom])
	print("[film] %s" % nom)
