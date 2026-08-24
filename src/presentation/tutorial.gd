## Tutoriel : des runes gravées dans le sol, à l'endroit où chaque geste sert.
##
## Invariant 2 : purement présentation. Il observe l'état de la simulation et
## allume des lumières ; il ne déclenche rien, ne bloque rien, et le jeu se
## déroulerait exactement pareil sans lui — `--no-tutorial` le prouve à chaque
## exécution du banc réseau.
##
## Ce qu'il n'est PAS, et c'est délibéré : une liste de consignes en haut de
## l'écran qu'on lit une fois et qu'on ne relit jamais. Une rune se croise, se
## lit sur place, et s'ÉTEINT quand on a fait la chose. Le monde garde la
## trace de ce qu'on sait ; il n'y a pas d'étape courante, pas de « suivant »,
## et rien n'attend le joueur. Deux joueurs peuvent en être à des runes
## différentes, ce qui est le cas normal en coopération.
##
## Chaque rune se valide en FAISANT la chose, jamais en appuyant sur une
## touche : un tutoriel qu'on peut traverser sans rien comprendre ne sert à
## rien.
class_name Tutorial
extends Node3D

@export var bootstrap_path: NodePath
@export var camera_rig_path: NodePath
@export var label_path: NodePath

## Lacet cumulé, en radians, au-delà duquel on considère que le joueur a
## compris que la souris tourne la caméra.
const LOOK_TARGET: float = 1.4
## Distance à parcourir pour valider le déplacement, en mètres.
const MOVE_TARGET: float = 5.0
## Vitesse d'apparition et de disparition du texte, en unités par seconde.
const FADE_RATE: float = 4.5
## Une rune éteinte garde une braise, pour qu'on voie qu'on est déjà passé.
const EMBER: float = 0.16

class Rune extends RefCounted:
	var data: TutorialSign
	var root: Node3D
	var materials: Array[StandardMaterial3D] = []
	## La colonne de lueur, tenue à part : elle ne doit se voir que sur la
	## rune qu'on lit. Au même éclat que la gravure, onze runes allumées
	## transforment la nef en chantier balisé.
	var shaft: StandardMaterial3D
	var lamp: OmniLight3D
	var learned: bool = false
	var read_left: float = 0.0
	var glow: float = 0.0

var _bootstrap: NetBootstrap
var _rig: CameraRig
var _label: Label
var _runes: Array[Rune] = []
var _built: bool = false
var _wired: bool = false
var _shown: Rune = null
var _alpha: float = 0.0

## Ce que le joueur a déjà fait. Observé sur des transitions d'état, jamais
## sur des touches : le tutoriel ignore le clavier, comme toute la simulation.
var _looked: float = 0.0
var _last_yaw: float = 0.0
var _travelled: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
var _has_reference: bool = false
var _last_state: Actor.State = Actor.State.IDLE
var _did: Dictionary[int, bool] = {}

func _ready() -> void:
	var node: Node = get_node_or_null(bootstrap_path)
	if node is NetBootstrap:
		_bootstrap = node as NetBootstrap
	var rig: Node = get_node_or_null(camera_rig_path)
	if rig is CameraRig:
		_rig = rig as CameraRig
	var label: Node = get_node_or_null(label_path)
	if label is Label:
		_label = label as Label
		_style(_label)

func _style(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_font_size_override("font_size", 21)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = ""
	label.modulate.a = 0.0

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build(world: World) -> void:
	_built = true
	if _bootstrap.options != null and not _bootstrap.options.show_tutorial:
		return
	var path: String = "res://data/tutorial/%s.tres" % world.level.id
	if not ResourceLoader.exists(path):
		return
	var data: TutorialData = load(path) as TutorialData
	if data == null:
		return
	for sign_data: TutorialSign in data.signs:
		_runes.append(_make_rune(sign_data))

## Une rune : un anneau, huit rayons, une colonne de lueur. Gravée à ras du
## sol pour qu'on marche dessus sans buter — elle ne bloque rien, elle n'est
## même pas un obstacle.
func _make_rune(data: TutorialSign) -> Rune:
	var rune: Rune = Rune.new()
	rune.data = data
	rune.root = Node3D.new()
	rune.root.name = "Rune_%s" % data.id
	rune.root.position = Vector3(data.position.x, 0.0, data.position.y)
	add_child(rune.root)

	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.78
	ring.outer_radius = 0.92
	ring.rings = 40
	ring.ring_segments = 6
	rune.materials.append(_glyph(rune.root, ring, Vector3(0.0, 0.03, 0.0),
		Vector3.ZERO, data.tone))

	var inner: TorusMesh = TorusMesh.new()
	inner.inner_radius = 0.30
	inner.outer_radius = 0.38
	inner.rings = 28
	inner.ring_segments = 6
	rune.materials.append(_glyph(rune.root, inner, Vector3(0.0, 0.03, 0.0),
		Vector3.ZERO, data.tone))

	for index: int in 8:
		var angle: float = TAU * float(index) / 8.0
		var bar: BoxMesh = BoxMesh.new()
		bar.size = Vector3(0.07, 0.02, 0.30)
		rune.materials.append(_glyph(rune.root, bar,
			Vector3(cos(angle) * 0.58, 0.03, sin(angle) * 0.58),
			Vector3(0.0, rad_to_deg(-angle), 0.0), data.tone))

	# Colonne de lueur : c'est elle qu'on aperçoit de loin, dans le noir. Basse
	# et fine — un souffle au-dessus de la gravure, pas un projecteur.
	var shaft: CylinderMesh = CylinderMesh.new()
	shaft.top_radius = 0.015
	shaft.bottom_radius = 0.13
	shaft.height = 0.95
	shaft.radial_segments = 12
	shaft.rings = 1
	rune.shaft = _glyph(rune.root, shaft, Vector3(0.0, 0.48, 0.0),
		Vector3.ZERO, data.tone)

	rune.lamp = OmniLight3D.new()
	rune.lamp.position = Vector3(0.0, 0.7, 0.0)
	rune.lamp.omni_range = 5.5
	rune.lamp.light_color = data.tone.lerp(Color(1.0, 0.97, 0.92), 0.5)
	rune.lamp.light_energy = 0.0
	rune.lamp.shadow_enabled = false
	rune.root.add_child(rune.lamp)
	return rune

func _glyph(parent: Node3D, mesh: Mesh, at: Vector3, turn: Vector3,
		tone: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = PrimitiveFactory.material_for(
		tone, false, SkinPart.Surface.GLOW, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation = Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y),
		deg_to_rad(turn.z))
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return material

# ---------------------------------------------------------------------------
# Boucle
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _bootstrap == null or _bootstrap.world == null:
		return
	var world: World = _bootstrap.world
	if not _built:
		_build(world)
	if _runes.is_empty():
		return
	_wire(world)
	var actor: Actor = world.local_actor()
	if actor == null:
		return
	_observe(actor, delta)
	_nearest(actor, delta)
	_paint(delta)

func _wire(world: World) -> void:
	if _wired:
		return
	_wired = true
	world.bonfire_rested.connect(func() -> void:
		_did[TutorialSign.Condition.REST] = true)
	world.shortcut_opened.connect(func() -> void:
		_did[TutorialSign.Condition.SHORTCUT] = true)
	world.hit_declared.connect(func(_target_id: int, _attack_index: int) -> void:
		_did[TutorialSign.Condition.HIT] = true)
	world.actor_died.connect(func(actor_id: int) -> void:
		var dead: Actor = world.actor_or_null(actor_id)
		if dead == null or dead.kind != Actor.Kind.ENEMY:
			return
		# Un mannequin qu'on abat n'apprend pas à tuer : il se relève.
		var data: EnemyData = world.data_for(dead)
		if data != null and data.is_training_dummy:
			return
		_did[TutorialSign.Condition.KILL] = true)

func _observe(actor: Actor, _delta: float) -> void:
	if not _has_reference:
		_has_reference = true
		_last_position = actor.position
		# La caméra ne démarre pas à zéro : sans cette prise de référence, le
		# tout premier écart validerait la rune avant que le joueur n'ait
		# touché la souris.
		if _rig != null:
			_last_yaw = _rig.look_yaw()
		_last_state = actor.state
		return
	if _rig != null:
		var yaw: float = _rig.look_yaw()
		_looked += absf(wrapf(yaw - _last_yaw, -PI, PI))
		_last_yaw = yaw
		if _looked >= LOOK_TARGET:
			_did[TutorialSign.Condition.LOOK] = true
	_travelled += actor.position.distance_to(_last_position)
	_last_position = actor.position
	if _travelled >= MOVE_TARGET:
		_did[TutorialSign.Condition.MOVE] = true
	if actor.state != _last_state:
		if actor.state == Actor.State.DODGING:
			_did[TutorialSign.Condition.DODGE] = true
		elif actor.state == Actor.State.ATTACKING:
			if actor.attack_index == 0:
				_did[TutorialSign.Condition.ATTACK] = true
			elif actor.attack_index >= 1:
				_did[TutorialSign.Condition.SECOND] = true
		_last_state = actor.state

## La rune la plus proche à portée gagne. Une seule parle à la fois : deux
## phrases affichées ensemble n'en laissent passer aucune.
func _nearest(actor: Actor, delta: float) -> void:
	var best: Rune = null
	var best_distance: float = INF
	for rune: Rune in _runes:
		if rune.learned:
			continue
		if _did.get(rune.data.condition, false):
			rune.learned = true
			continue
		var distance: float = actor.position.distance_to(rune.data.position)
		if distance <= rune.data.radius and distance < best_distance:
			best_distance = distance
			best = rune
	if best != null and best.data.condition == TutorialSign.Condition.READ:
		best.read_left += delta
		if best.read_left >= best.data.read_seconds:
			best.learned = true
	_shown = best

func _paint(delta: float) -> void:
	var pulse: float = 0.82 + 0.18 * sin(float(Time.get_ticks_msec()) * 0.0028)
	for rune: Rune in _runes:
		var target: float = EMBER if rune.learned else (1.0 if rune == _shown else 0.26)
		rune.glow = move_toward(rune.glow, target, delta * 2.4)
		var shown: float = rune.glow * pulse
		for material: StandardMaterial3D in rune.materials:
			material.emission_energy_multiplier = 0.25 + shown * 1.5
			var tint: Color = rune.data.tone
			tint.a = clampf(0.20 + shown * 0.70, 0.0, 1.0)
			material.albedo_color = tint
		# La colonne suit le CARRÉ de l'éclat : elle disparaît vite quand on
		# s'éloigne, et ne se voit vraiment que sur la rune qu'on lit.
		var column: Color = rune.data.tone
		column.a = clampf(shown * shown * 0.34, 0.0, 1.0)
		rune.shaft.albedo_color = column
		rune.shaft.emission_energy_multiplier = 0.2 + shown * shown * 1.1
		rune.lamp.light_energy = shown * shown * 1.6

	if _label == null:
		return
	if _shown != null:
		_label.text = _shown.data.line if _shown.data.hint.is_empty() \
			else "%s\n%s" % [_shown.data.line, _shown.data.hint]
		_alpha = move_toward(_alpha, 1.0, delta * FADE_RATE)
		_label.add_theme_color_override("font_color",
			Color.WHITE.lerp(_shown.data.tone, 0.35))
	else:
		_alpha = move_toward(_alpha, 0.0, delta * FADE_RATE)
	_label.modulate.a = _alpha
