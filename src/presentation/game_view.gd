## Miroir visuel du monde simulé.
##
## Invariant 2 : sens unique. Ce nœud crée, met à jour et détruit des vues à
## partir de World ; il n'écrit jamais dans la simulation et ne lui pose jamais
## de question à laquelle elle ne répond pas déjà par ses données.
class_name GameView
extends Node3D

## Un coup se lit en rouge, un soin en vert. Deux couleurs, pas plus : un
## joueur doit pouvoir dire d'un coup d'œil, au fond du couloir, si son
## coéquipier prend cher ou remonte.
## Espacement des escarbilles de traînée, en secondes.
const TRAIL_INTERVAL: float = 0.045
## Poussière de sel : presque blanche, à peine froide.
const COLOR_DUST: Color = Color(0.88, 0.90, 0.86)
const COLOR_HIT: Color = Color(1.0, 0.26, 0.20)
## Saumure : ce qui soigne dans ce monde lave le sel, il n'est
## donc ni vert ni doré, il est de la couleur de l'eau qui reste.
const COLOR_HEAL: Color = Color(0.46, 0.94, 0.84)

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
## Dernière position connue de chaque projectile. Un projectile qui disparaît
## ne dit pas où il s'est éteint : il faut l'avoir noté avant.
var _flight_positions: Dictionary[int, Vector3] = {}
var _flight_colors: Dictionary[int, Color] = {}
## Vrai tant que l'acteur roule : sert à ne soulever la poussière qu'une fois.
var _dodge_seen: Dictionary[int, bool] = {}
## Prochaine date de dépôt d'une escarbille, par projectile.
var _trail_due: Dictionary[int, float] = {}
## Horloge d'affichage, en secondes. Sert aux effets, jamais au jeu.
var _clock: float = 0.0
## Rotation cumulée des sorts en vol, en radians.
var _flight_spin: float = 0.0
## Points de vie à l'image précédente. Les effets naissent d'un ÉCART déjà
## constaté, jamais d'un événement que la vue aurait deviné : la simulation ne
## prévient personne, et c'est très bien ainsi (invariant 2).
var _last_health: Dictionary[int, int] = {}
## Attaques déjà saluées par un anneau de lancer, pour n'en poser qu'un.
var _cast_seen: Dictionary[int, int] = {}
var _shortcut_shown: bool = false
## Position de chaque acteur au tick précédent et au tick courant. La
## présentation affiche un point ENTRE les deux, choisi par la fraction
## d'avancement de l'image physique.
##
## Sans cela, la simulation à 60 Hz et un écran à 144 Hz donnent deux images
## identiques sur trois puis un saut — ce qui se lit comme un jeu qui saccade,
## alors que la carte graphique s'ennuie. C'est le défaut le plus visible que
## le projet ait eu, et il était documenté dans CameraRig comme un compromis
## assumé : il ne l'était pas, c'était une erreur.
var _previous: Dictionary[int, Vector2] = {}
var _current: Dictionary[int, Vector2] = {}
## Au-delà de ce déplacement en un tick, on ne peut plus parler de mouvement :
## c'est une réapparition ou un recalage réseau. Interpoler ferait glisser le
## personnage à travers la chapelle.
const TELEPORT_METRES: float = 2.5

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
	if _bootstrap.simulation != null \
			and not _bootstrap.simulation.tick_advanced.is_connected(_on_tick):
		_bootstrap.simulation.tick_advanced.connect(_on_tick)
	_level_view.build(world.level)
	_shortcut_shown = world.shortcut_open
	_level_view.set_shortcut_open(_shortcut_shown)

## Appelé après chaque tick simulé : ce qui était la position courante devient
## la position précédente, et l'on note la nouvelle.
func _on_tick(_tick: int) -> void:
	if _bootstrap == null or _bootstrap.world == null:
		return
	for actor: Actor in _bootstrap.world.actors.values():
		var was: Vector2 = _current.get(actor.id, actor.position)
		_previous[actor.id] = was
		_current[actor.id] = actor.position

## Position à afficher pour un acteur, entre son tick précédent et le courant.
func _shown_position(actor: Actor) -> Vector2:
	var from: Vector2 = _previous.get(actor.id, actor.position)
	var to: Vector2 = _current.get(actor.id, actor.position)
	if from.distance_to(to) > TELEPORT_METRES:
		return actor.position
	return from.lerp(to, clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0))

func _process(delta: float) -> void:
	if _bootstrap == null or _bootstrap.world == null:
		return
	_clock += delta
	_flight_spin = delta * 9.0
	var world: World = _bootstrap.world
	if world.shortcut_open != _shortcut_shown:
		_shortcut_shown = world.shortcut_open
		_level_view.set_shortcut_open(_shortcut_shown)

	_watch_health(world)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	var local: Actor = world.local_actor()
	var player_distance: float = 0.0
	if local != null and camera != null:
		var here: Vector2 = _shown_position(local)
		player_distance = eye.distance_to(Vector3(here.x, 0.9, here.y))
	for actor: Actor in world.actors.values():
		var view: ActorView = _views.get(actor.id, null)
		if view != null and _view_data_index.get(actor.id, -99) != actor.data_index:
			view.queue_free()
			_views.erase(actor.id)
			view = null
		if view == null:
			view = _make_view(world, actor)
		view.refresh(actor, eye, actor.id == world.local_actor_id, player_distance,
			delta, _shown_position(actor), world.dodge_progress(actor))
		_watch_cast(actor)
		_watch_dodge(actor)

	for actor_id: int in _views.keys():
		if not world.actors.has(actor_id):
			_views[actor_id].queue_free()
			_views.erase(actor_id)
			_view_data_index.erase(actor_id)
			_last_health.erase(actor_id)
			_cast_seen.erase(actor_id)
			_previous.erase(actor_id)
			_current.erase(actor_id)

	_refresh_projectiles(world)

## Un projectile n'a pas de position stockée : on la demande au monde, qui la
## recalcule depuis son tick de départ.
## Escarbilles laissées derrière un sort. Espacées en TEMPS et non par image :
## à 30 comme à 144 images par seconde, la traînée a la même densité.
func _drop_trail(flight_id: int, at: Vector3, tone: Color) -> void:
	var next: float = _trail_due.get(flight_id, 0.0)
	if _clock < next:
		return
	_trail_due[flight_id] = _clock + TRAIL_INTERVAL
	Vfx.spawn(_actors_root, Vfx.Kind.MOTE, at, tone)

func _refresh_projectiles(world: World) -> void:
	for projectile: Projectile in world.projectiles.values():
		var view: MeshInstance3D = _flights.get(projectile.id, null)
		if view == null:
			view = _make_flight(world, projectile)
			if view == null:
				continue
		var at: Vector2 = world.projectile_position(projectile)
		view.position = Vector3(at.x, 1.1, at.y)
		_flight_positions[projectile.id] = view.position
		var heading: Vector3 = Vector3(projectile.direction.x, 0.0, projectile.direction.y)
		if not heading.is_zero_approx():
			view.look_at(view.position + heading, Vector3.UP)
			# Le prisme est couché sur le côté et tourne sur son axe de vol :
			# un éclat de verre qui file scintille, une boîte qui glisse non.
			view.rotate_object_local(Vector3.FORWARD, _flight_spin)
		var tone: Color = _flight_colors.get(projectile.id, Color.WHITE)
		_drop_trail(projectile.id, view.position, tone)
	for flight_id: int in _flights.keys():
		if not world.projectiles.has(flight_id):
			# Éteint : mur, cible, ou portée épuisée. La simulation ne dit pas
			# laquelle, et la vue n'a pas à le savoir — un éclat au dernier
			# point connu dit tout ce que le joueur a besoin de lire.
			var where: Vector3 = _flight_positions.get(flight_id, Vector3.ZERO)
			var tone: Color = _flight_colors.get(flight_id, Color.WHITE)
			Vfx.spawn(_actors_root, Vfx.Kind.SHATTER, where, tone)
			_flights[flight_id].queue_free()
			_flights.erase(flight_id)
			_flight_positions.erase(flight_id)
			_flight_colors.erase(flight_id)
			_trail_due.erase(flight_id)

## Un sort en vol, en trois couches : un éclat de verre plein, un halo additif
## plus large, et une VRAIE lumière. La lumière est ce qui change tout — un
## sort qui traverse un couloir sombre doit éclairer les murs au passage,
## sinon ce n'est qu'un autocollant qui glisse sur l'écran.
func _make_flight(world: World, projectile: Projectile) -> MeshInstance3D:
	var attack: AttackData = world.projectile_attack(projectile)
	if attack == null or attack.projectile == null:
		return null
	var tone: Color = attack.projectile.color
	var thickness: float = attack.projectile.radius * 1.5
	var length: float = attack.projectile.radius * 2.0 + 1.0

	# Un prisme allongé dans le sens du vol, et non une bille : à huit mètres,
	# une sphère du rayon de la hitbox fait cinq pixels et se perd. L'éclat se
	# voit, et sa longueur dit dans quel sens il part.
	var shard: PrismMesh = PrismMesh.new()
	shard.size = Vector3(thickness, thickness, length)
	var view: MeshInstance3D = MeshInstance3D.new()
	view.mesh = shard
	view.material_override = _flight_material(tone, false)
	view.rotation.z = PI * 0.5
	_actors_root.add_child(view)

	var halo: MeshInstance3D = MeshInstance3D.new()
	var glow: PrismMesh = PrismMesh.new()
	glow.size = Vector3(thickness * 2.6, thickness * 2.6, length * 1.35)
	halo.mesh = glow
	halo.material_override = _flight_material(tone, true)
	view.add_child(halo)

	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.omni_range = 5.2
	lamp.light_energy = 2.4
	lamp.light_color = tone
	lamp.shadow_enabled = false
	view.add_child(lamp)

	_flights[projectile.id] = view
	_flight_colors[projectile.id] = tone
	return view

func _flight_material(tone: Color, additive: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	# Non éclairé : un projectile doit rester visible dans le noir du couloir.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if not additive:
		material.albedo_color = tone.lightened(0.35)
		return material
	var faint: Color = tone
	faint.a = 0.30
	material.albedo_color = faint
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

## Un écart de points de vie déjà arrivé se traduit en gerbe. La vue ne
## décide de rien : elle n'a même pas le moyen de savoir QUI a frappé.
func _watch_health(world: World) -> void:
	for actor: Actor in world.actors.values():
		var previous: int = _last_health.get(actor.id, actor.health)
		_last_health[actor.id] = actor.health
		if actor.health == previous:
			continue
		var at: Vector3 = Vector3(actor.position.x, 0.0, actor.position.y)
		if actor.health >= previous:
			Vfx.spawn(_actors_root, Vfx.Kind.RINSE, at, COLOR_HEAL)
			continue
		Vfx.spawn(_actors_root, Vfx.Kind.HIT, at, COLOR_HIT)
		var view: ActorView = _views.get(actor.id, null)
		if view != null:
			view.impact(_nearest_other(world, actor))
		if actor.id != world.local_actor_id:
			continue
		# La caméra ne tremble QUE pour le personnage local : secouer l'écran
		# parce qu'un allié à vingt mètres a pris un coup n'apprend rien et
		# donne le mal de mer.
		var rig: Node = get_viewport().get_camera_3d()
		if rig != null and rig.get_parent() is CameraRig:
			var force: float = clampf(
				float(previous - actor.health) / 40.0, 0.25, 1.0)
			(rig.get_parent() as CameraRig).shake(0.030 * force)

## D'où vient le coup ? La simulation ne le dit pas — elle n'a pas à le dire,
## puisque la vue n'en tire aucune conséquence de jeu. L'acteur le plus proche
## est la meilleure approximation disponible, et elle est juste dans le cas
## qui compte : un corps à corps.
func _nearest_other(world: World, victim: Actor) -> Vector2:
	var best: Vector2 = victim.position - victim.facing
	var closest: float = INF
	for other: Actor in world.actors.values():
		if other.id == victim.id or not other.is_alive():
			continue
		var gap: float = other.position.distance_squared_to(victim.position)
		if gap < closest:
			closest = gap
			best = other.position
	return best

## Anneau au sol au premier tick d'un lancer. Compté en ticks écoulés et non
## par un signal : la simulation n'en émet aucun, et un client qui rejoue ses
## commandes repasserait deux fois sur le même signal s'il y en avait un.
func _watch_cast(actor: Actor) -> void:
	var runner: AttackRunner = actor.runner
	if runner == null or runner.finished or runner.attack == null:
		_cast_seen.erase(actor.id)
		return
	if runner.attack.projectile == null and runner.attack.heal <= 0:
		return
	var started: int = _cast_seen.get(actor.id, -1)
	if started >= 0:
		return
	_cast_seen[actor.id] = runner.elapsed_ticks
	var tone: Color = COLOR_HEAL if runner.attack.heal > 0 \
		else runner.attack.projectile.color
	Vfx.spawn(_actors_root, Vfx.Kind.CAST,
		Vector3(actor.position.x, 0.06, actor.position.y), tone)

## Poussière de sel au départ d'une roulade. Comme pour le lancer, l'effet
## naît d'un CHANGEMENT D'ÉTAT déjà arrivé, jamais d'un signal : un client qui
## rejoue ses commandes repasserait deux fois sur le même signal.
func _watch_dodge(actor: Actor) -> void:
	var rolling: bool = actor.state == Actor.State.DODGING
	if rolling == _dodge_seen.get(actor.id, false):
		return
	_dodge_seen[actor.id] = rolling
	if not rolling:
		return
	Vfx.spawn(_actors_root, Vfx.Kind.DUST,
		Vector3(actor.position.x, 0.04, actor.position.y), COLOR_DUST)

func _make_view(world: World, actor: Actor) -> ActorView:
	var view: ActorView = ActorView.new()
	view.name = "Actor_%d" % actor.id
	_actors_root.add_child(view)
	var id: StringName = _skin_id(world, actor)
	view.setup(actor, _color_for(world, actor), actor.id == world.local_actor_id,
		SkinLibrary.for_id(id), ModelLibrary.for_id(id))
	_views[actor.id] = view
	_view_data_index[actor.id] = actor.data_index
	return view

## Le skin se résout par l'identifiant de la fiche : res://data/skins/<id>.tres.
## Aucune table dans le code — ajouter une classe et son skin ne demande de
## toucher à aucun fichier .gd.
func _skin_id(world: World, actor: Actor) -> StringName:
	if actor.kind == Actor.Kind.ENEMY:
		var data: EnemyData = world.data_for(actor)
		return data.id if data != null else &""
	var fiche: PlayerData = world.class_for(actor)
	return fiche.id if fiche != null else &""

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
	var shown: Vector2 = _shown_position(actor)
	out.append(Vector3(shown.x, 0.0, shown.y))
	return true
