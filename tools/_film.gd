extends Node
## Filme une sequence de jeu : course, roulade, attaque, sur le mannequin.

const DOSSIER: String = "/home/user/shots/film"
var _frame: int = 0
var _boot: NetBootstrap = null
var _view: GameView = null

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
	if _frame > 144:
		get_tree().quit(0)

func _prise(nom: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [DOSSIER, nom])
	print("[film] %s" % nom)
