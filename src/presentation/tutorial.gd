## Tutoriel : apprend les mécaniques dans l'ordre où elles servent.
##
## Invariant 2 : purement présentation. Il observe l'état de la simulation et
## affiche du texte ; il ne déclenche rien, ne bloque rien, et le jeu se
## déroulerait exactement pareil sans lui.
##
## Chaque étape se valide en FAISANT la chose, jamais en appuyant sur
## « suivant » : un tutoriel qu'on peut traverser sans rien comprendre ne sert
## à rien.
class_name Tutorial
extends Label

@export var bootstrap_path: NodePath
@export var camera_rig_path: NodePath

## Lacet cumulé, en radians, au-delà duquel on considère que le joueur a
## compris que la souris tourne la caméra.
const LOOK_TARGET: float = 1.4
## Distance à parcourir pour valider le déplacement.
const MOVE_TARGET: float = 6.0
## Profondeur, en z, à partir de laquelle on est engagé dans le couloir.
const CORRIDOR_DEPTH: float = 10.0
## Une étape validée reste affichée ce temps-là, en secondes, pour que le
## joueur voie qu'il a réussi.
const CONFIRM_SECONDS: float = 1.6

enum Step {
	LOOK,
	MOVE,
	DODGE,
	ATTACK,
	SECOND,
	REST,
	ADVANCE,
	KILL,
	SHORTCUT,
	DONE,
}

var _bootstrap: NetBootstrap
var _rig: CameraRig
var _step: Step = Step.LOOK
var _confirm_left: float = 0.0
var _looked: float = 0.0
var _last_yaw: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _has_origin: bool = false
var _last_state: Actor.State = Actor.State.IDLE
var _dodged: bool = false
var _attacked_main: bool = false
var _attacked_second: bool = false
var _rested: bool = false
var _killed: bool = false
var _shortcut: bool = false
var _wired: bool = false

func _ready() -> void:
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	add_theme_constant_override("outline_size", 6)
	add_theme_font_size_override("font_size", 20)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = ""
	var node: Node = get_node_or_null(bootstrap_path)
	if node is NetBootstrap:
		_bootstrap = node as NetBootstrap
	var rig: Node = get_node_or_null(camera_rig_path)
	if rig is CameraRig:
		_rig = rig as CameraRig

func _process(delta: float) -> void:
	if _bootstrap == null or _bootstrap.options == null or not _bootstrap.options.show_tutorial:
		text = ""
		return
	if Input.is_action_just_pressed("toggle_diagnostics"):
		# Le diagnostic et le tutoriel se disputeraient l'écran.
		_step = Step.DONE
	var world: World = _bootstrap.world
	if world == null:
		return
	_wire(world)
	var actor: Actor = world.local_actor()
	if actor == null or _step == Step.DONE:
		text = "" if _step == Step.DONE else text
		return

	_observe(actor)
	if _confirm_left > 0.0:
		_confirm_left -= delta
		if _confirm_left <= 0.0:
			_advance()
		return
	if _is_done(world, actor):
		text = "%s  ✓" % _instruction(world)
		_confirm_left = CONFIRM_SECONDS
		return
	text = _instruction(world)

func _wire(world: World) -> void:
	if _wired:
		return
	_wired = true
	world.bonfire_rested.connect(func() -> void: _rested = true)
	world.shortcut_opened.connect(func() -> void: _shortcut = true)
	world.actor_died.connect(func(actor_id: int) -> void:
		var dead: Actor = world.actor_or_null(actor_id)
		if dead != null and dead.kind == Actor.Kind.ENEMY:
			_killed = true)

## Enregistre ce que le joueur vient de faire. On observe des transitions
## d'état, pas des touches : le tutoriel ignore le clavier, comme tout le
## reste de la simulation.
func _observe(actor: Actor) -> void:
	if not _has_origin:
		_origin = actor.position
		_has_origin = true
		# La caméra ne démarre pas à zéro : sans cette prise de référence, le
		# tout premier écart validerait l'étape avant que le joueur n'ait
		# touché la souris.
		if _rig != null:
			_last_yaw = _rig.look_yaw()
		_last_state = actor.state
		return
	if _rig != null:
		var yaw: float = _rig.look_yaw()
		_looked += absf(wrapf(yaw - _last_yaw, -PI, PI))
		_last_yaw = yaw
	if actor.state != _last_state:
		if actor.state == Actor.State.DODGING:
			_dodged = true
		elif actor.state == Actor.State.ATTACKING:
			if actor.attack_index == 0:
				_attacked_main = true
			elif actor.attack_index >= 1:
				_attacked_second = true
		_last_state = actor.state

func _is_done(world: World, actor: Actor) -> bool:
	match _step:
		Step.LOOK:
			return _looked >= LOOK_TARGET
		Step.MOVE:
			return actor.position.distance_to(_origin) >= MOVE_TARGET
		Step.DODGE:
			return _dodged
		Step.ATTACK:
			return _attacked_main
		Step.SECOND:
			return _attacked_second
		Step.REST:
			return _rested
		Step.ADVANCE:
			return actor.position.y >= CORRIDOR_DEPTH
		Step.KILL:
			return _killed
		Step.SHORTCUT:
			return world.shortcut_open
		_:
			return false

func _advance() -> void:
	if _step < Step.DONE:
		_step = (int(_step) + 1) as Step

func _instruction(world: World) -> String:
	var fiche: PlayerData = world.class_for(world.local_actor())
	var seconde: String = "ta seconde arme"
	if fiche != null and fiche.attacks.size() > 1 and fiche.attacks[1].heal > 0:
		seconde = "ton soin"
	match _step:
		Step.LOOK:
			return "Bouge la souris. La caméra décide où tu frappes."
		Step.MOVE:
			return "Avance avec ZQSD. Le déplacement suit la caméra."
		Step.DODGE:
			return "Espace pour rouler. Tu es invulnérable pendant la roulade, pas avant."
		Step.ATTACK:
			return "Clic gauche pour frapper. Tu frappes là où tu regardes."
		Step.SECOND:
			return "Clic droit pour %s. Chaque classe en a une." % seconde
		Step.REST:
			return "Entre dans l'anneau orange et appuie sur E. Le feu te soigne et remet les gobelins en place."
		Step.ADVANCE:
			return "Descends le couloir au nord. Un gobelin s'éveille à huit mètres."
		Step.KILL:
			return "Son arme devient JAUNE quand son coup part. C'est ton seul repère : roule à ce moment-là, puis frappe."
		Step.SHORTCUT:
			return "Le boss est au fond. Depuis son arène, E sur le repère bleu ouvre un raccourci définitif vers le feu."
		_:
			return ""
