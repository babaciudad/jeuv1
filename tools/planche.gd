## Planche de présentation des six personnages importés.
##
##   godot --rendering-driver vulkan --resolution 1280x720 res://tools/planche.tscn
##
## Outil de vérification : il ne fait pas partie du jeu. Il monte un studio
## minimal — sol, fond, trois sources — pose les six modèles en ligne et
## enregistre une planche d'ensemble puis, pour chacun, un portrait au repos
## et une image en pleine attaque.
extends Node3D

const IDS: Array[String] = ["gardien", "mage", "soigneur", "archer",
	"gobelin", "warden"]
const NOMS: Array[String] = ["GARDIEN", "MAGE", "SOIGNEUR", "ARCHER",
	"GOBELIN", "LE GARDIEN DES BRAISES"]
const PAS: float = 2.5
const DOSSIER: String = "/home/user/shots/perso"

var _camera: Camera3D
var _players: Array[AnimationPlayer] = []
var _datas: Array[ModelData] = []
var _frame: int = 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DOSSIER)
	_build_studio()
	_build_cast()
	add_child(InkPass.new())

# ---------------------------------------------------------------------------
# Studio
# ---------------------------------------------------------------------------

func _build_studio() -> void:
	var sol: PlaneMesh = PlaneMesh.new()
	sol.size = Vector2(60.0, 60.0)
	var plancher: MeshInstance3D = MeshInstance3D.new()
	plancher.mesh = sol
	plancher.material_override = _matiere(Color(0.60, 0.61, 0.58))
	add_child(plancher)

	var fond: BoxMesh = BoxMesh.new()
	fond.size = Vector3(60.0, 12.0, 0.6)
	var mur: MeshInstance3D = MeshInstance3D.new()
	mur.mesh = fond
	mur.material_override = _matiere(Color(0.44, 0.46, 0.45))
	mur.position = Vector3(0.0, 6.0, -5.0)
	add_child(mur)

	var cle: DirectionalLight3D = DirectionalLight3D.new()
	cle.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(28.0), 0.0)
	cle.light_energy = 1.35
	cle.light_color = Color(1.0, 0.94, 0.86)
	cle.shadow_enabled = true
	cle.shadow_normal_bias = 1.2
	add_child(cle)

	var appoint: DirectionalLight3D = DirectionalLight3D.new()
	appoint.rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(-140.0), 0.0)
	appoint.light_energy = 0.9
	appoint.light_color = Color(0.62, 0.74, 1.0)
	add_child(appoint)

	var holder: WorldEnvironment = WorldEnvironment.new()
	holder.environment = _ambiance()
	holder.camera_attributes = _exposition()
	add_child(holder)

	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.current = true
	add_child(_camera)

func _matiere(teinte: Color) -> StandardMaterial3D:
	var matiere: StandardMaterial3D = StandardMaterial3D.new()
	matiere.albedo_color = teinte
	matiere.roughness = 0.95
	matiere.metallic = 0.0
	return matiere

func _ambiance() -> Environment:
	var ambiance: Environment = Environment.new()
	ambiance.background_mode = Environment.BG_COLOR
	ambiance.background_color = Color(0.030, 0.032, 0.044)
	ambiance.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiance.ambient_light_color = Color(0.36, 0.46, 0.52)
	ambiance.ambient_light_energy = 0.70
	ambiance.ssao_enabled = true
	ambiance.ssao_radius = 0.9
	ambiance.ssao_intensity = 1.6
	ambiance.tonemap_mode = Environment.TONE_MAPPER_ACES
	ambiance.tonemap_white = 3.2
	ambiance.adjustment_enabled = true
	ambiance.adjustment_contrast = 1.14
	ambiance.adjustment_saturation = 1.08
	return ambiance

func _exposition() -> CameraAttributesPractical:
	var reglage: CameraAttributesPractical = CameraAttributesPractical.new()
	reglage.exposure_multiplier = 1.05
	reglage.auto_exposure_enabled = true
	reglage.auto_exposure_scale = 0.38
	reglage.auto_exposure_min_sensitivity = 40.0
	reglage.auto_exposure_max_sensitivity = 420.0
	reglage.auto_exposure_speed = 3.0
	return reglage

# ---------------------------------------------------------------------------
# Distribution
# ---------------------------------------------------------------------------

func _build_cast() -> void:
	for index: int in IDS.size():
		var data: ModelData = load("res://models/%s.tres" % IDS[index])
		_datas.append(data)
		var corps: Node3D = data.scene.instantiate() as Node3D
		add_child(corps)
		var sel: SaltBody = SaltBody.dress(corps, data.id, Color.WHITE)
		corps.scale = Vector3.ONE * maxf(0.001, data.scale)
		corps.position = Vector3(_abscisse(index),
			data.lift + sel.lift * maxf(0.001, data.scale), 0.0)
		var lecteur: AnimationPlayer = _lecteur(corps)
		_players.append(lecteur)
		if lecteur != null and lecteur.has_animation(data.idle):
			lecteur.play(data.idle)

		var etiquette: Label3D = Label3D.new()
		etiquette.text = NOMS[index]
		etiquette.font_size = 96
		etiquette.pixel_size = 0.0016
		etiquette.position = Vector3(_abscisse(index), 0.06, 1.1)
		etiquette.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)
		etiquette.modulate = Color(1.0, 0.96, 0.88)
		etiquette.outline_size = 22
		etiquette.outline_modulate = Color(0.05, 0.04, 0.04)
		add_child(etiquette)

func _abscisse(index: int) -> float:
	return (float(index) - 2.5) * PAS

func _lecteur(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var trouve: AnimationPlayer = _lecteur(child)
		if trouve != null:
			return trouve
	return null

# ---------------------------------------------------------------------------
# Prises de vue
# ---------------------------------------------------------------------------

func _cadre_ligne() -> void:
	_camera.position = Vector3(0.0, 1.15, 11.0)
	_camera.look_at(Vector3(0.0, 0.95, 0.0))

func _cadre_portrait(index: int) -> void:
	var x: float = _abscisse(index)
	_camera.position = Vector3(x + 0.85, 1.05, 2.45)
	_camera.look_at(Vector3(x, 0.82, 0.0))

func _pose(index: int, animation: StringName, fraction: float) -> void:
	var lecteur: AnimationPlayer = _players[index]
	if lecteur == null or not lecteur.has_animation(animation):
		return
	lecteur.play(animation)
	lecteur.seek(lecteur.get_animation(animation).length * fraction, true)
	lecteur.advance(0.0)

func _prise(nom: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [DOSSIER, nom])
	print("[planche] %s" % nom)

func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 6:
		_cadre_ligne()
	if _frame == 12:
		await _prise("00_ligne")
	var debut: int = 16
	for index: int in IDS.size():
		var base: int = debut + index * 12
		if _frame == base:
			_cadre_portrait(index)
			_pose(index, _datas[index].idle, 0.35)
		if _frame == base + 4:
			await _prise("%02d_%s_repos" % [index + 1, IDS[index]])
		if _frame == base + 6:
			_pose(index, _datas[index].attack, 0.45)
		if _frame == base + 10:
			await _prise("%02d_%s_attaque" % [index + 1, IDS[index]])
	if _frame > debut + IDS.size() * 12 + 6:
		get_tree().quit(0)
