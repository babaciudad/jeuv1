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
## Fiche avec laquelle chaque vue a été bâtie. Une classe annoncée après coup
## change la couleur ET la taille du personnage : la vue doit être refaite,
## pas repeinte.
var _view_data_index: Dictionary[int, int] = {}
var _flights: Dictionary[int, MeshInstance3D] = {}
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
		if view != null and _view_data_index.get(actor.id, -99) != actor.data_index:
			view.queue_free()
			_views.erase(actor.id)
			view = null
		if view == null:
			view = _make_view(world, actor)
		view.refresh(actor, eye, actor.id == world.local_actor_id, player_distance)

	for actor_id: int in _views.keys():
		if not world.actors.has(actor_id):
			_views[actor_id].queue_free()
			_views.erase(actor_id)
			_view_data_index.erase(actor_id)

	_refresh_projectiles(world)

## Un projectile n'a pas de position stockée : on la demande au monde, qui la
## recalcule depuis son tick de départ.
func _refresh_projectiles(world: World) -> void:
	for projectile: Projectile in world.projectiles.values():
		var view: MeshInstance3D = _flights.get(projectile.id, null)
		if view == null:
			view = _make_flight(world, projectile)
			if view == null:
				continue
		var at: Vector2 = world.projectile_position(projectile)
		view.position = Vector3(at.x, 1.1, at.y)
		var heading: Vector3 = Vector3(projectile.direction.x, 0.0, projectile.direction.y)
		if not heading.is_zero_approx():
			view.look_at(view.position + heading, Vector3.UP)
	for flight_id: int in _flights.keys():
		if not world.projectiles.has(flight_id):
			_flights[flight_id].queue_free()
			_flights.erase(flight_id)

func _make_flight(world: World, projectile: Projectile) -> MeshInstance3D:
	var attack: AttackData = world.projectile_attack(projectile)
	if attack == null or attack.projectile == null:
		return null
	# Un trait allongé dans le sens du vol, et non une bille : à huit mètres,
	# une sphère du rayon de la hitbox fait cinq pixels et se perd. Le trait
	# se voit, et sa longueur dit dans quel sens il part.
	var bolt: BoxMesh = BoxMesh.new()
	var thickness: float = attack.projectile.radius * 1.4
	bolt.size = Vector3(thickness, thickness, attack.projectile.radius * 2.0 + 1.1)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = attack.projectile.color
	# Non éclairé : un projectile doit rester visible dans le noir du couloir.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var view: MeshInstance3D = MeshInstance3D.new()
	view.mesh = bolt
	view.material_override = material
	_actors_root.add_child(view)
	_flights[projectile.id] = view
	return view

func _make_view(world: World, actor: Actor) -> ActorView:
	var view: ActorView = ActorView.new()
	view.name = "Actor_%d" % actor.id
	_actors_root.add_child(view)
	view.setup(actor, _color_for(world, actor), actor.id == world.local_actor_id)
	_views[actor.id] = view
	_view_data_index[actor.id] = actor.data_index
	return view

## La couleur vient de la fiche de l'acteur, jamais d'une table à part : une
## classe ajoutée dans res://data/ se voit sans toucher à la présentation.
func _color_for(world: World, actor: Actor) -> Color:
	if actor.kind == Actor.Kind.ENEMY:
		var data: EnemyData = world.data_for(actor)
		return data.color if data != null else Color(0.7, 0.35, 0.3)
	var fiche: PlayerData = world.class_for(actor)
	return fiche.color if fiche != null else Color(0.6, 0.7, 0.5)

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
