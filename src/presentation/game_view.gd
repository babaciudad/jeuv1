## Miroir visuel du monde simulé.
##
## Invariant 2 : sens unique. Ce nœud crée, met à jour et détruit des vues à
## partir de World ; il n'écrit jamais dans la simulation et ne lui pose jamais
## de question à laquelle elle ne répond pas déjà par ses données.
class_name GameView
extends Node3D

@export var bootstrap_path: NodePath

var _bootstrap: NetBootstrap
var _level_view: LevelView
var _actors_root: Node3D
var _views: Dictionary[int, ActorView] = {}
var _shortcut_shown: bool = false

func _ready() -> void:
	_actors_root = Node3D.new()
	_actors_root.name = "Actors"
	add_child(_actors_root)
	_level_view = LevelView.new()
	_level_view.name = "Level"
	add_child(_level_view)

	var node: Node = get_node_or_null(bootstrap_path)
	if node is NetBootstrap:
		_bootstrap = node as NetBootstrap
		if _bootstrap.world != null:
			_on_world_ready(_bootstrap.world)
		else:
			_bootstrap.world_ready.connect(_on_world_ready)

func _on_world_ready(world: World) -> void:
	_level_view.build(world.level)
	_shortcut_shown = world.shortcut_open
	_level_view.set_shortcut_open(_shortcut_shown)

func _process(_delta: float) -> void:
	if _bootstrap == null or _bootstrap.world == null:
		return
	var world: World = _bootstrap.world
	if world.shortcut_open != _shortcut_shown:
		_shortcut_shown = world.shortcut_open
		_level_view.set_shortcut_open(_shortcut_shown)

	var camera: Camera3D = get_viewport().get_camera_3d()
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	var local: Actor = world.local_actor()
	var player_distance: float = 0.0
	if local != null and camera != null:
		player_distance = eye.distance_to(Vector3(local.position.x, 0.9, local.position.y))
	for actor: Actor in world.actors.values():
		var view: ActorView = _views.get(actor.id, null)
		if view == null:
			view = _make_view(world, actor)
		view.refresh(actor, eye, actor.id == world.local_actor_id, player_distance)

	for actor_id: int in _views.keys():
		if not world.actors.has(actor_id):
			_views[actor_id].queue_free()
			_views.erase(actor_id)

func _make_view(world: World, actor: Actor) -> ActorView:
	var data: EnemyData = world.data_for(actor)
	var is_boss: bool = data != null and data.is_boss
	var view: ActorView = ActorView.new()
	view.name = "Actor_%d" % actor.id
	_actors_root.add_child(view)
	view.setup(actor, actor.id == world.local_actor_id, is_boss)
	_views[actor.id] = view
	return view

func simulated_world() -> World:
	return _bootstrap.world if _bootstrap != null else null

## Position visible du personnage local, pour la caméra. Retourne false tant
## qu'il n'y en a pas : sur un client, le personnage n'existe qu'une fois que
## l'hôte l'a annoncé.
func local_view_position(out: Array[Vector3]) -> bool:
	if _bootstrap == null or _bootstrap.world == null:
		return false
	var actor: Actor = _bootstrap.world.local_actor()
	if actor == null:
		return false
	out.append(Vector3(actor.position.x, 0.0, actor.position.y))
	return true
