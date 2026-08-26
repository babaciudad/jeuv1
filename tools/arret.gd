## Mesure le patinage des pieds PENDANT UN ARRET, en jeu.
##
##   [autoload]
##   _Arret="*res://tools/arret.gd"
##   godot --path . --fixed-fps 60 -- --host
##
## `tools/pas.gd` mesure la course etablie ; il ne peut pas voir ce defaut-ci,
## parce qu'il pilote le melangeur en direct et court-circuite justement le
## filtre qui est en cause. Ici on fait courir le personnage POUR DE VRAI, on
## lache la commande, et on regarde ce que les pieds fabriquent.
##
## COMMENT ON DEFINIT LE PATINAGE. Un pied POSE ne bouge pas dans le monde :
## dans le repere du squelette, il doit donc reculer d'exactement ce que le
## corps avance. Le patinage d'une image est le RESTE :
##
##   glissade = |dz_pied_local + dz_corps_monde|
##
## et on retient, a chaque image, le plus petit des deux pieds — c'est celui
## qui est pose. Prendre le plus BAS ne marche pas : au moment ou le pied
## d'appui quitte le sol, le pied qui passe devant descend plus bas que lui,
## et on se met a suivre une jambe en vol. La premiere version de cet outil
## faisait exactement ca et comptait 0,31 m de « glissade » en deux images —
## soit un pied a plus de six metres par seconde, ce qu'aucun appui ne fait.
## Elle differenciait meme, a l'occasion, la position de DEUX pieds
## differents, et appelait la difference un patinage.
##
## Outil de verification, hors jeu. Il faut un contexte de rendu : sans lui le
## squelette n'est jamais pose et toutes les mesures sortent a zero.
extends Node

const TEMOIN: int = 40
const COURSE: int = 90
const ARRET: int = 40

var _frame: int = 0
var _boot: NetBootstrap = null
var _view: GameView = null
var _os: Skeleton3D = null
var _pieds: Vector2i = Vector2i(-1, -1)
var _zg: float = 0.0
var _zd: float = 0.0
var _amorce: bool = false
var _pire: float = 0.0
var _apres: float = 0.0
var _pieds_faits: float = 0.0
var _corps_fait: float = 0.0
var _temoin: float = 0.0
var _mesure: bool = false
var _vue: ActorView = null
var _anim: SaltAnimator = null

func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_walk(child))
	return out

func _squelette(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for c: Node in node.get_children():
		var f: Skeleton3D = _squelette(c)
		if f != null:
			return f
	return null

func _process(delta: float) -> void:
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
	if _frame == 10:
		me.position = Vector2(0.0, 14.0)
		me.facing = Vector2(0.0, 1.0)
	if _os == null:
		for node: Node in _walk(get_tree().root):
			if node is ActorView and (node as ActorView).uses_model():
				_vue = node as ActorView
				_anim = _vue.animator()
				_os = _squelette(node)
				if _os != null:
					var g: int = _os.find_bone("ball_l")
					var d: int = _os.find_bone("ball_r")
					_pieds = Vector2i(g, d)
					break
	if _os == null or _pieds.x < 0:
		return
	var zg: float = _os.get_bone_global_pose(_pieds.x).origin.z
	var zd: float = _os.get_bone_global_pose(_pieds.y).origin.z
	if not _amorce:
		_amorce = true
		_zg = zg
		_zd = zd
		return
	# Le corps avance le long de +z : la commande de course est (0, 1).
	var corps: float = me.velocity.length() * delta
	# Reste de chaque pied, et on garde le mieux pose des deux.
	var reste: float = minf(absf(zg - _zg + corps), absf(zd - _zd + corps))
	_zg = zg
	_zd = zd

	# Temoin : le meme comptage sur un personnage qui ne bouge pas du tout.
	# Sans lui on ne sait pas si les centimetres comptes plus bas sont du
	# patinage ou le simple report d'appui de l'animation d'attente.
	if _frame > 12 and _frame <= 12 + TEMOIN:
		_temoin += reste
		return
	# Course etablie, puis on LACHE.
	if _frame >= 12 + TEMOIN and _frame < 12 + TEMOIN + COURSE:
		_boot.submit_command(Command.Type.MOVE, {"d": Vector2(0.0, 1.0)})
	if _frame == 12 + TEMOIN + COURSE:
		_mesure = true
		print("[arret] lache a l'image %d, vitesse %.2f m/s"
			% [_frame, me.velocity.length()])
	if _mesure and _frame > 12 + TEMOIN + COURSE:
		_pieds_faits += reste
		_corps_fait += corps
		_pire = maxf(_pire, reste)
		if me.velocity.length() <= 0.001:
			_apres += reste
		if _anim != null:
			print("[trace] %3d  v %.2f  melange %.2f  cadence %.2f  glisse %.4f"
				% [_frame, me.velocity.length(), _anim.ground_blend().y,
				_anim.ground_scale(), reste])
	if _frame > 12 + TEMOIN + COURSE + ARRET:
		print("[arret] temoin immobile %.3f m sur %d images" % [_temoin, TEMOIN])
		print("[arret] corps %.3f m   glissade %.3f m   pire image %.4f m"
			% [_corps_fait, _pieds_faits, _pire])
		print("[arret] dont APRES arret complet : %.4f m" % [_apres])
		print("[arret] glissade rapportee au trajet %+.0f %%"
			% [100.0 * _pieds_faits / maxf(0.0001, _corps_fait)])
		get_tree().quit(0)
