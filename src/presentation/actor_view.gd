## Représentation visible d'un acteur.
##
## Invariant 2 : lecture seule. Cette vue ne décide de rien, elle traduit un
## état de simulation en pose et en couleur.
##
## Aucun modèle importé : capsule et boîte, éclairage par sommet, dans l'esprit
## PS1/PS2 demandé. La lisibilité du combat ne dépend d'aucun asset.
class_name ActorView
extends Node3D

const COLOR_LOCAL: Color = Color(0.56, 0.75, 0.48)
const COLOR_ALLY: Color = Color(0.45, 0.62, 0.78)
const COLOR_GRUNT: Color = Color(0.71, 0.34, 0.31)
const COLOR_BOSS: Color = Color(0.48, 0.31, 0.71)
const COLOR_WEAPON_IDLE: Color = Color(0.62, 0.62, 0.66)
## Une hitbox ouverte doit se voir sans ambiguïté : c'est la seule information
## dont le joueur a besoin pour apprendre le rythme d'un ennemi.
const COLOR_WEAPON_ACTIVE: Color = Color(1.0, 0.85, 0.35)
## Un acteur situé entre la caméra et le personnage la bouche. On l'estompe
## plutôt que de reculer la caméra, ce qui est impossible quand un ennemi
## poursuit par derrière. Le seuil est relatif au personnage, pas absolu : à
## distance fixe, la même valeur serait trop tôt de près et trop tard de loin.
const FADE_MARGIN: float = 0.2
const FADE_FULL_AT: float = 1.2
## On n'efface jamais complètement : un ennemi invisible est pire qu'un
## ennemi gênant.
const FADE_FLOOR: float = 0.25

var _body: MeshInstance3D
var _weapon: MeshInstance3D
var _body_material: StandardMaterial3D
var _weapon_material: StandardMaterial3D
var _base_color: Color = COLOR_LOCAL

func setup(actor: Actor, is_local: bool, is_boss: bool) -> void:
	_base_color = _pick_color(actor, is_local, is_boss)

	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = actor.radius
	capsule.height = actor.radius * 4.0
	_body_material = _make_material(_base_color)
	_body = MeshInstance3D.new()
	_body.mesh = capsule
	_body.material_override = _body_material
	_body.position = Vector3(0.0, actor.radius * 2.0, 0.0)
	add_child(_body)

	var blade: BoxMesh = BoxMesh.new()
	blade.size = Vector3(0.14, 0.14, actor.radius * 3.0)
	_weapon_material = _make_material(COLOR_WEAPON_IDLE)
	_weapon = MeshInstance3D.new()
	_weapon.mesh = blade
	_weapon.material_override = _weapon_material
	# Le nœud regarde vers -Z : l'arme se place devant, donc en -Z.
	_weapon.position = Vector3(actor.radius * 0.7, actor.radius * 1.8, -actor.radius * 1.4)
	add_child(_weapon)

func _apply_fade(camera_position: Vector3, is_local: bool, player_distance: float) -> void:
	var alpha: float = 1.0
	if not is_local and player_distance > 0.0:
		var distance: float = global_position.distance_to(camera_position)
		# Positif quand l'acteur est devant le personnage vu de la caméra.
		var intrusion: float = player_distance - distance
		var hidden: float = clampf(
			inverse_lerp(FADE_MARGIN, FADE_FULL_AT, intrusion), 0.0, 1.0)
		alpha = maxf(FADE_FLOOR, 1.0 - hidden)
	# Le mélange alpha ne s'active qu'en cas de besoin : laissé en permanence,
	# il imposerait un tri par profondeur à toute la scène pour rien.
	var mode: BaseMaterial3D.Transparency = BaseMaterial3D.TRANSPARENCY_DISABLED \
		if alpha >= 0.99 else BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_material.transparency = mode
	_weapon_material.transparency = mode
	_body_material.albedo_color.a = alpha
	_weapon_material.albedo_color.a = alpha

func _pick_color(actor: Actor, is_local: bool, is_boss: bool) -> Color:
	if actor.kind == Actor.Kind.ENEMY:
		return COLOR_BOSS if is_boss else COLOR_GRUNT
	return COLOR_LOCAL if is_local else COLOR_ALLY

func _make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material

func refresh(actor: Actor, camera_position: Vector3, is_local: bool,
		player_distance: float) -> void:
	position = Vector3(actor.position.x, 0.0, actor.position.y)
	if not actor.facing.is_zero_approx():
		var forward: Vector3 = Vector3(actor.facing.x, 0.0, actor.facing.y)
		look_at(position + forward, Vector3.UP)

	var open: bool = actor.runner != null and actor.runner.hitbox_open
	_weapon_material.albedo_color = COLOR_WEAPON_ACTIVE if open else COLOR_WEAPON_IDLE
	_weapon.visible = actor.is_alive()

	match actor.state:
		Actor.State.DEAD:
			# Couché : la mort doit se lire d'un coup d'œil, de loin.
			rotate_object_local(Vector3.RIGHT, -PI * 0.5)
			_body_material.albedo_color = _base_color.darkened(0.55)
			_body.position.y = actor.radius
		Actor.State.STAGGERED:
			_body_material.albedo_color = _base_color.lightened(0.35)
			_body.position.y = actor.radius * 1.8
		Actor.State.DODGING:
			# Écrasé au sol : la fenêtre d'invulnérabilité doit être visible.
			_body_material.albedo_color = _base_color.lightened(0.15)
			_body.position.y = actor.radius * 1.1
		_:
			_body_material.albedo_color = _base_color
			_body.position.y = actor.radius * 2.0

	# En dernier : les couleurs d'état viennent d'être réécrites, appliquer le
	# fondu avant elles reviendrait à l'effacer.
	_apply_fade(camera_position, is_local, player_distance)
