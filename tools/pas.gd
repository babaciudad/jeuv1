## Mesure le patinage des pieds, en jeu, sur chaque personnage.
##
## Le personnage avance en ligne droite a sa vitesse simulee reelle ; on lit a
## chaque image la position du pied qui touche le sol et on compare la vitesse
## a laquelle il recule a celle a laquelle le corps avance. Les deux doivent
## etre egales : c'est la definition d'un pas qui ne glisse pas.
##
##   godot --path . --rendering-driver vulkan --fixed-fps 60 res://tools/pas.tscn
##
## Outil de verification, hors jeu. Il faut un contexte de rendu : sans lui le
## squelette n'est jamais pose et toutes les mesures sortent a zero, sans que
## rien ne le signale.
extends Node3D

const IDS: Array[String] = ["gardien", "archer", "mage", "soigneur",
	"gobelin", "warden"]
## Vitesses lues dans data/classes et data/actors.
const VITESSES: Array[float] = [4.2, 5.3, 4.8, 4.9, 3.4, 3.4]
const CHAUFFE: int = 150
const IMAGES: int = 900

var _anims: Array[SaltAnimator] = []
var _os: Array[Skeleton3D] = []
var _pieds: Array[Vector2i] = []
var _sol: Array[float] = []
var _avant: Array[Vector3] = []
var _recul: Array[float] = []
var _temps: Array[float] = []
var _frame: int = 0

func _squelette(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for c: Node in node.get_children():
		var f: Skeleton3D = _squelette(c)
		if f != null:
			return f
	return null

func _ready() -> void:
	for id: String in IDS:
		var data: ModelData = load("res://models/%s.tres" % id)
		var rig: Node3D = data.scene.instantiate() as Node3D
		add_child(rig)
		_anims.append(SaltAnimator.build(rig, data))
		var sk: Skeleton3D = _squelette(rig)
		_os.append(sk)
		var g: int = sk.find_bone("ball_l")
		var d: int = sk.find_bone("ball_r")
		_pieds.append(Vector2i(g, d))
		_sol.append(1e9)
		_avant.append(Vector3.ZERO)
		_recul.append(0.0)
		_temps.append(0.0)

func _process(delta: float) -> void:
	_frame += 1
	for index: int in IDS.size():
		var v: float = VITESSES[index]
		var animateur: SaltAnimator = _anims[index]
		if not animateur.ready():
			continue
		animateur._drive_ground(Vector2(0.0, v), Vector2(0.0, 1.0))
		var sk: Skeleton3D = _os[index]
		var g: Vector3 = sk.get_bone_global_pose(_pieds[index].x).origin
		var d: Vector3 = sk.get_bone_global_pose(_pieds[index].y).origin
		var pied: Vector3 = g if g.y <= d.y else d
		_sol[index] = minf(_sol[index], pied.y)
		if _frame < CHAUFFE:
			_avant[index] = pied
			continue
		# Appui : le pied touche, et il touchait deja a l'image precedente.
		var pose: bool = pied.y <= _sol[index] + 0.03 \
			and _avant[index].y <= _sol[index] + 0.03
		var meme: bool = absf(pied.x - _avant[index].x) < 0.08
		if pose and meme:
			_recul[index] += _avant[index].z - pied.z
			_temps[index] += delta
		_avant[index] = pied
	if _frame <= IMAGES:
		return
	print("--- pas : recul du pied d'appui contre avancee du corps ---")
	for index: int in IDS.size():
		var t: float = maxf(_temps[index], 0.0001)
		var recul: float = _recul[index] / t
		print("%-10s corps %.2f m/s   pied %.2f m/s   ecart %+4.0f %%"
			% [IDS[index], VITESSES[index], recul,
				100.0 * (recul / VITESSES[index] - 1.0)])
	get_tree().quit(0)
