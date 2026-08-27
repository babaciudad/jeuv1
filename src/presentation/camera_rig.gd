## La caméra de troisième personne.
##
## Elle suit le corps de dos, à la souris, et ne fait rien d'autre. Deux
## précautions valent d'être dites :
##
##   — elle vise un point AU-DESSUS des pieds, jamais les pieds. Dans un lieu
##     parfaitement plat, viser le sol donne un horizon collé en haut de
##     l'écran et on ne voit plus le ciel — or le ciel EST le sujet ;
##   — elle ne passe jamais sous le terrain. Il n'y a pas un seul corps de
##     collision dans ce jeu : la simulation fait autorité et le décor n'est
##     que du maillage. On interroge donc le marais directement.
class_name CameraRig
extends Node3D

const DISTANCE: float = 4.6
const HAUTEUR_CIBLE: float = 1.30
const SENSIBILITE: float = 0.0026
const TANGAGE_MIN: float = -0.50
const TANGAGE_MAX: float = 0.62
## Garde au-dessus du sol, en mètres.
const GARDE: float = 0.35
## Lissage de la position, en secondes.
const TAU: float = 0.055

var lacet: float = 0.0
var tangage: float = 0.10

var _camera: Camera3D = null
var _marais: Marais = null
var _amorce: bool = false

func _ready() -> void:
	_camera = Camera3D.new()
	_camera.name = "Oeil"
	_camera.fov = 68.0
	_camera.far = 500.0
	_camera.near = 0.08
	add_child(_camera)
	_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func regarder(marais: Marais) -> void:
	_marais = marais

func _unhandled_input(evenement: InputEvent) -> void:
	var souris: InputEventMouseMotion = evenement as InputEventMouseMotion
	if souris != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		lacet -= souris.relative.x * SENSIBILITE
		tangage = clampf(tangage - souris.relative.y * SENSIBILITE,
			TANGAGE_MIN, TANGAGE_MAX)
	if evenement.is_action_pressed(&"release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var clic: InputEventMouseButton = evenement as InputEventMouseButton
	if clic != null and clic.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func cadrer(cible: Vector3, delta: float) -> void:
	if _camera == null:
		return
	var vise: Vector3 = cible + Vector3(0.0, HAUTEUR_CIBLE, 0.0)
	var direction: Vector3 = Vector3(
		sin(lacet) * cos(tangage), sin(tangage), cos(lacet) * cos(tangage))
	var voulue: Vector3 = vise + direction * DISTANCE

	if _marais != null:
		var sol: float = _marais.hauteur_sol(Vector2(voulue.x, voulue.z))
		voulue.y = maxf(voulue.y, sol + GARDE)

	if not _amorce:
		_camera.global_position = voulue
		_amorce = true
	else:
		_camera.global_position = _camera.global_position.lerp(
			voulue, clampf(delta / TAU, 0.0, 1.0))
	_camera.look_at(vise, Vector3.UP)

## Cap de la caméra, en radians, dans la convention du jeu : c'est lui que la
## commande transporte, et c'est lui qui oriente le corps à l'arrêt.
func cap() -> float:
	return lacet + PI
