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
	160: Vector2(0.0, -22.0), 176: Vector2(0.0, 6.0),
	192: Vector2(0.0, 20.0), 208: Vector2(-8.0, 74.0),
	224: Vector2(0.0, 128.0),
}
const NOMS: Dictionary[int, String] = {
	168: "zone1_halle", 184: "zone2_bassin", 200: "zone3_parvis",
	216: "zone4_tables", 232: "zone5_arene",
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
		me.position = Vector2(0.0, -26.0)
		me.facing = Vector2(0.0, 1.0)
	# 24 -> 68 : course en avant, une image sur deux gardee
	if _frame >= 22 and _frame < 70:
		_boot.submit_command(Command.Type.MOVE, {"d": Vector2(0.0, 1.0)})
	if _frame >= 30 and _frame < 70 and _frame % 4 == 0:
		await _prise("course_%02d" % _frame)
	# 72 : roulade
	if _frame == 72:
		_boot.submit_command(Command.Type.DODGE, {"d": Vector2(0.0, 1.0)})
	if _frame >= 74 and _frame < 100 and _frame % 3 == 0:
		await _prise("roulade_%02d" % _frame)
	# 104 : attaque
	if _frame == 104:
		_boot.submit_command(Command.Type.ATTACK,
			{"i": 0, "d": Vector2(0.0, 1.0)})
	if _frame >= 106 and _frame < 140 and _frame % 3 == 0:
		await _prise("coup_%02d" % _frame)
	# Tour des cinq zones : on se pose, on laisse une image passer, on garde.
	if _frame >= 150:
		_boot.submit_command(Command.Type.MOVE, {"d": Vector2(0.0, 0.12)})
	if ZONES.has(_frame):
		me.position = ZONES[_frame]
		me.facing = Vector2(0.0, 1.0)
	if NOMS.has(_frame):
		await _prise(NOMS[_frame])
	# Vue d'ensemble : une camera a nous, tres haut, pour voir la silhouette du
	# niveau entier et reperer ce qui flotte.
	if _frame == 250:
		var oeil: Camera3D = Camera3D.new()
		add_child(oeil)
		oeil.fov = 55.0
		oeil.position = Vector3(0.0, 96.0, 178.0)
		oeil.look_at(Vector3(0.0, 0.0, 58.0))
		oeil.current = true
		_oeil = oeil
	if _frame == 256:
		await _prise("vue_densemble")
	if _frame == 260 and _oeil != null:
		_oeil.position = Vector3(-96.0, 40.0, 60.0)
		_oeil.look_at(Vector3(0.0, 8.0, 70.0))
	if _frame == 266:
		await _prise("vue_ouest")
	if _frame == 270 and _oeil != null:
		_oeil.position = Vector3(-4.0, 14.0, 88.0)
		_oeil.look_at(Vector3(20.0, 14.0, 112.0))
	if _frame == 276:
		await _prise("vue_arene")
	if _frame > 282:
		get_tree().quit(0)

func _prise(nom: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [DOSSIER, nom])
	print("[film] %s" % nom)
