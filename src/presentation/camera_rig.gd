## Caméra troisième personne.
##
## Invariant 2 : la simulation ne connaît pas ce nœud et ne peut pas le
## joindre. La caméra suit ce que la simulation affirme ; elle n'a aucun avis.
##
## Aucune interpolation d'image : la simulation tourne à 60 Hz et la caméra
## lit la position du tick courant. Sur un écran à fréquence plus élevée, le
## déplacement se verra par paliers. C'est un compromis assumé pour la tranche
## verticale : lisser introduirait un retard visuel, et dans un jeu où l'on
## esquive à la fenêtre près, le retard coûte plus cher que le palier.
class_name CameraRig
extends Node3D

@export var game_view_path: NodePath
@export var distance: float = 6.0
@export var shoulder_height: float = 1.7
@export var pitch_min_degrees: float = -60.0
@export var pitch_max_degrees: float = 20.0
## Vitesse à laquelle la caméra rejoint sa cible verrouillée, en radians par
## seconde.
const LOCK_TURN: float = 4.2

var _shake: float = 0.0
var _shake_clock: float = 0.0

## Nombre de positions testées entre le personnage et la caméra pour trouver
## la plus reculée qui reste dégagée.
const OCCLUSION_STEPS: int = 14
## Distance minimale : en deçà, on est dans le personnage.
const MIN_DISTANCE: float = 1.4
## Marge autour d'un acteur en deçà de laquelle la caméra le traverserait.
const ACTOR_CLEARANCE: float = 0.6
## Marge sous le plafond et au-dessus du sol.
##
## Le test de dégagement ne connaissait que le plan XZ. Dans le couloir, haut
## de 3,6 m, la caméra reculée et inclinée passait AU-DESSUS du plafond : le
## point restait dans le praticable vu de dessus, donc jugé libre, et le haut
## de l'écran se remplissait de la dalle vue par en dessous. C'est le bug qui
## ressemblait le plus à « la caméra part en vrille ».
## Généreuse à dessein : il ne s'agit pas seulement d'éviter de traverser la
## dalle, mais de ne pas la laisser manger le haut de l'écran. Dans le boyau à
## 3,6 m, la caméra reculée montait à 3,0 m — sous le plafond, donc « libre »,
## mais avec un mètre de dalle plein cadre. Elle rentre maintenant.
const CEILING_CLEARANCE: float = 1.05
const FLOOR_CLEARANCE: float = 0.35

## Amplitude maximale de secousse, en radians, et vitesse d'extinction. Une
## secousse qui dure est un mal de mer ; celle-ci est finie en un tiers de
## seconde.
const SHAKE_MAX: float = 0.035
const SHAKE_DECAY: float = 0.11

var _camera: Camera3D
var _game_view: GameView
## Au départ, la caméra regarde vers le +Z, c'est-à-dire vers le couloir. Le
## joueur apparaît dos au feu et face à ce qui l'attend.
var _yaw: float = PI
var _pitch: float = -0.22

func _ready() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.position = Vector3(0.0, 0.0, distance)
	_camera.current = true
	_camera.fov = 70.0
	add_child(_camera)
	var node: Node = get_node_or_null(game_view_path)
	if node is GameView:
		_game_view = node as GameView

## Appelé par la lecture d'entrée, qui est le seul endroit du projet autorisé
## à connaître la souris.
func add_look(relative: Vector2, sensitivity: float) -> void:
	_yaw -= relative.x * sensitivity
	_pitch = clampf(_pitch - relative.y * sensitivity,
		deg_to_rad(pitch_min_degrees), deg_to_rad(pitch_max_degrees))

## Lacet courant, en radians. Lu par le tutoriel pour savoir si le joueur a
## compris que la souris tourne la caméra.
func look_yaw() -> float:
	return _yaw

## Direction « vers l'avant de la caméra », projetée dans le plan de la
## simulation. C'est ce qui rend le déplacement relatif à la vue.
func planar_forward() -> Vector2:
	var forward: Vector3 = -global_basis.z
	var flat: Vector2 = Vector2(forward.x, forward.z)
	return flat.normalized() if flat.length() > 0.001 else Vector2(0.0, 1.0)

func planar_right() -> Vector2:
	var right: Vector3 = global_basis.x
	var flat: Vector2 = Vector2(right.x, right.z)
	return flat.normalized() if flat.length() > 0.001 else Vector2(1.0, 0.0)

## Secoue la caméra. Appelé quand le personnage local encaisse : c'est la
## moitié de ce qui fait qu'un coup se SENT, l'autre étant l'arrêt sur image
## du corps touché.
func shake(force: float) -> void:
	_shake = minf(_shake + force, SHAKE_MAX)

func _process(delta: float) -> void:
	_aim_at_lock(delta)
	rotation = Vector3(_pitch, _yaw, 0.0)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * SHAKE_DECAY)
		# Deux sinusoïdes de fréquences premières entre elles : ça ne boucle
		# pas visiblement, et ça ne demande aucun tirage aléatoire — deux
		# joueurs qui prennent le même coup voient la même secousse.
		_shake_clock += delta
		rotation += Vector3(
			sin(_shake_clock * 61.0) * _shake,
			sin(_shake_clock * 43.0) * _shake * 0.8,
			sin(_shake_clock * 79.0) * _shake * 0.5)
	if _game_view == null:
		return
	var found: Array[Vector3] = []
	if not _game_view.local_view_position(found):
		return
	position = found[0] + Vector3(0.0, shoulder_height, 0.0)
	_camera.position.z = _clear_distance()

## VERROUILLAGE : la caméra se tourne toute seule vers l'adversaire accroché.
##
## Sans ça, le verrouillage ne sert à rien. Le personnage aurait beau rester
## face à sa cible, le joueur devrait suivre à la souris pour la garder à
## l'écran — c'est-à-dire faire exactement le travail que le verrouillage est
## censé lui épargner. C'est la caméra qui fait la démarche de souls-like,
## autant que l'orientation du personnage.
##
## Elle ne SAUTE pas : elle rejoint le cap voulu à vitesse bornée, et le joueur
## peut toujours corriger à la souris par-dessus. Un recadrage instantané rend
## malade et enlève tout contrôle.
func _aim_at_lock(delta: float) -> void:
	if _game_view == null:
		return
	var world: World = _game_view.simulated_world()
	if world == null:
		return
	var me: Actor = world.local_actor()
	if me == null or me.lock_target_id == 0:
		return
	var target: Actor = world.actor_or_null(me.lock_target_id)
	if target == null or not target.is_alive():
		return
	var toward: Vector2 = target.position - me.position
	if toward.length() < 0.4:
		return
	# Lacet voulu pour que la cible soit droit devant. Le repère de la
	# simulation est (x, z) ; le lacet de la caméra tourne autour de Y.
	var wanted: float = atan2(-toward.x, -toward.y)
	var gap: float = wrapf(wanted - _yaw, -PI, PI)
	_yaw += clampf(gap, -LOCK_TURN * delta, LOCK_TURN * delta)
	# Et un peu de plongée, proportionnelle à la distance : de près on regarde
	# vers le bas, de loin presque à l'horizontale. C'est ce qui garde les deux
	# corps dans le cadre sans que personne ne touche à la souris.
	var wanted_pitch: float = deg_to_rad(
		lerpf(-26.0, -9.0, clampf(toward.length() / 16.0, 0.0, 1.0)))
	var pitch_gap: float = wanted_pitch - _pitch
	_pitch = clampf(_pitch + clampf(pitch_gap, -LOCK_TURN * delta,
		LOCK_TURN * delta), deg_to_rad(pitch_min_degrees),
		deg_to_rad(pitch_max_degrees))

## Recule la caméra le plus loin possible sans traverser un mur ni un acteur.
##
## Pas de SpringArm3D ni de corps physique : la simulation décrit déjà la
## géométrie et les acteurs, et en ajouter une seconde description pour la
## seule caméra créerait deux vérités à maintenir. On interroge donc la même
## donnée que celle contre laquelle le personnage se cogne.
func _clear_distance() -> float:
	var world: World = _game_view.simulated_world()
	if world == null or world.level == null:
		return distance
	var pivot: Vector3 = global_position
	var away: Vector3 = global_basis.z
	for step: int in range(OCCLUSION_STEPS, 0, -1):
		var candidate: float = distance * float(step) / float(OCCLUSION_STEPS)
		if candidate < MIN_DISTANCE:
			break
		if _is_clear(world, pivot + away * candidate):
			return candidate
	return MIN_DISTANCE

func _is_clear(world: World, probe: Vector3) -> bool:
	var flat: Vector2 = Vector2(probe.x, probe.z)
	if not SimMath.point_is_free(flat, world.level.walkable, world.blockers()):
		return false
	# La hauteur compte autant que le plan : une salle basse doit ramener la
	# caméra vers le personnage, pas la laisser sortir par le toit.
	if probe.y > world.level.height_at(flat) - CEILING_CLEARANCE:
		return false
	if probe.y < FLOOR_CLEARANCE:
		return false
	for actor: Actor in world.actors.values():
		if actor.id == world.local_actor_id or not actor.is_alive():
			continue
		if flat.distance_to(actor.position) < actor.radius + ACTOR_CLEARANCE:
			return false
	return true
