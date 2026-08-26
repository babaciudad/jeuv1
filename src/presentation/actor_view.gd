## Représentation visible d'un acteur : un squelette de pivots habillé de
## primitives, animé par procédure.
##
## Invariant 2 : lecture seule. Cette vue ne décide de rien, elle traduit un
## état de simulation en pose et en couleur. Elle n'a pas le droit d'inventer
## un mouvement que la simulation ignore : tout ce qu'elle anime se déduit de
## la position, de l'état et de l'attaque en cours.
##
## Un skin ne change RIEN au jeu : ni hitbox, ni portée, ni rayon de collision.
## Il habille un cylindre de simulation, il ne le remplace pas. C'est pourquoi
## il vit dans res://data/skins/ et non dans la fiche de classe.
##
## Deux systèmes d'animation coexistent dans ce projet et ne doivent JAMAIS
## être confondus :
##   — AttackRunner : l'AnimationPlayer qui ouvre et ferme les hitboxes, en
##     ticks, dans la simulation, faisant autorité (invariant 8) ;
##   — ce fichier : la démarche, le balancement, le geste d'arme, en secondes
##     réelles, purement décoratif.
## Le second lit l'état du premier ; l'inverse serait une faute.
class_name ActorView
extends Node3D

const COLOR_WEAPON_IDLE: Color = Color(0.62, 0.62, 0.66)
## Une hitbox ouverte doit se voir sans ambiguïté : c'est le seul repère de
## rythme du jeu, et le tutoriel l'enseigne explicitement.
const COLOR_WEAPON_ACTIVE: Color = Color(1.0, 0.85, 0.35)
## Anneau posé sous le personnage local. Les classes ayant chacune sa couleur,
## c'est le seul repère qui dise « c'est toi » sans la contredire.
const COLOR_SELF_RING: Color = Color(0.95, 0.92, 0.70)

## Un acteur situé entre la caméra et le personnage la bouche. On l'estompe
## plutôt que de reculer la caméra, ce qui est impossible quand un ennemi
## poursuit par derrière. Le seuil est relatif au personnage, pas absolu.
const FADE_MARGIN: float = 0.2
const FADE_FULL_AT: float = 1.2
## On n'efface jamais complètement : un ennemi invisible est pire qu'un
## ennemi gênant.
const FADE_FLOOR: float = 0.25

## Radians de foulée par mètre parcouru. Cale le pas sur la DISTANCE et non
## sur le temps : un personnage ralenti par un mur ne pédale pas dans le vide,
## et deux joueurs de vitesses différentes ont naturellement des cadences
## différentes sans rien à régler.
const STRIDE_PER_METRE: float = 2.9
## Vitesse au-delà de laquelle la foulée est à pleine amplitude.
const FULL_STRIDE_SPEED: float = 3.6
## Lissage des membres, en unités par seconde. Sans lui, sortir d'une roulade
## remet les bras droits d'un seul image, ce qui claque.
const LIMB_BLEND_RATE: float = 9.0
## Le geste d'arme se cale plus vite que la marche : un coup doit partir sec.
const ATTACK_BLEND_RATE: float = 16.0
## Coude au repos : jamais tout à fait tendu, sinon la silhouette est raide.
const ELBOW_REST_DEGREES: float = -18.0
## Angles de bras porteur d'arme, selon le moment de l'attaque.
const ARM_WINDUP_DEGREES: float = -125.0
const ARM_STRIKE_DEGREES: float = 55.0
const ARM_CAST_DEGREES: float = -95.0
const ARM_HEAL_DEGREES: float = -150.0

## Hauteur du pivot de roulade, en mètres, pour un personnage de taille
## standard. C'est le bassin : un corps qui se roule tourne autour de ses
## hanches.
const ROLL_PIVOT_HEIGHT: float = 0.58
## Écrasement vertical au milieu de la roulade. Le corps se ramasse.
const ROLL_TUCK: float = 0.26
## Radians d'inclinaison par mètre par seconde carré d'accélération, et butée.
const LEAN_PER_ACCEL: float = 0.019
const LEAN_MAX: float = 0.21
## Recul à l'impact : distance en mètres, et durée en secondes. Court, sec, et
## il ne déplace RIEN dans la simulation — c'est le porte-pièces qui bouge,
## pas l'acteur.
const RECOIL_METRES: float = 0.26
const RECOIL_SECONDS: float = 0.16

## Nœud portant tout le corps. La pose d'ensemble — chute, chancellement,
## roulade — s'applique à lui seul, jamais aux pièces une par une.
var _pose: Node3D
## Un pivot par os. Les pièces d'un rôle sont enfants de son pivot ; faire
## tourner le pivot fait tourner tout ce qui pend dessous, et c'est tout ce
## qu'il y a à comprendre pour ajouter une pièce à un skin.
var _pivots: Dictionary[int, Node3D] = {}
var _materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _weapon_flags: Array[bool] = []
var _weapon_pieces: Array[Node3D] = []
var _stand_height: float = 0.0

## Phase de foulée, en radians. Avance avec la distance parcourue.
var _gait: float = 0.0
## Temps propre de la vue, pour le balancement au repos. Décalé par
## l'identifiant de l'acteur : quatre personnages côte à côte qui respirent
## exactement ensemble ont l'air d'un seul objet.
var _clock: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
## Déplacement observé, en mètres par seconde et en coordonnées du monde.
## C'est lui qui pilote le mélange de sol : la vitesse simulée d'un acteur
## distant est interpolée et ne veut rien dire ici.
var _travel: Vector2 = Vector2.ZERO
## Accélération observée, en mètres par seconde carrée. Pilote l'inclinaison.
var _push: Vector2 = Vector2.ZERO
## Recul en cours : temps restant, et direction dans le repère du personnage.
var _recoil: float = 0.0
var _recoil_from: Vector2 = Vector2.ZERO
## Non nul quand la vue est bâtie sur un modèle importé. Dans ce cas le
## squelette de pivots n'existe pas et l'animation procédurale est court-
## circuitée : c'est l'AnimationPlayer du modèle qui pose le personnage.
var _model: ModelData = null
var _animator: SaltAnimator = null
var _has_last: bool = false
var _speed: float = 0.0
## Angles courants, lissés vers leur cible à chaque image.
var _arm_swing: float = 0.0
var _leg_swing: float = 0.0
var _weapon_arm: float = 0.0
## Copiées du skin à la construction : la vue ne doit pas garder une référence
## vers la ressource, qui est partagée entre tous les porteurs du même skin.
var _stride_degrees: float = 34.0
var _idle_bob: float = 0.022

func setup(actor: Actor, color: Color, is_local: bool, skin: SkinData,
		model: ModelData = null) -> void:
	_stand_height = actor.radius * 2.0
	_clock = float(actor.id) * 0.37

	# Un anneau au sol pour TOUS quand on joue en modèles importés : ceux-ci
	# portent leurs propres matériaux, la couleur de classe ne les teinte donc
	# pas, et sans repère on ne sait plus qui est qui à quatre.
	if is_local or model != null:
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = actor.radius * 1.05
		ring.outer_radius = actor.radius * 1.30
		ring.rings = 20
		ring.ring_segments = 5
		var marker: MeshInstance3D = MeshInstance3D.new()
		marker.mesh = ring
		marker.material_override = PrimitiveFactory.material_for(
			COLOR_SELF_RING if is_local else color, false,
			SkinPart.Surface.GLOW, 0.9)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.position = Vector3(0.0, 0.04, 0.0)
		add_child(marker)

	_pose = Node3D.new()
	_pose.name = "Pose"
	add_child(_pose)

	if model != null:
		_build_model(actor, model, color)
		return

	var dressed: SkinData = skin
	if dressed == null or dressed.parts.is_empty():
		dressed = _fallback_skin(actor)
	_stride_degrees = dressed.stride_degrees
	_idle_bob = dressed.idle_bob
	_build_skeleton(dressed)
	for part: SkinPart in dressed.parts:
		_add_part(part, color)

# ---------------------------------------------------------------------------
# Mode modèle importé
# ---------------------------------------------------------------------------

## Instancie le modèle et retient son AnimationPlayer. Rien d'autre n'est
## touché : la pose d'ensemble, l'estompage et le suivi de position marchent
## à l'identique, puisqu'ils s'appliquent au porte-pièces et au nœud racine.
func _build_model(actor: Actor, model: ModelData, tint: Color) -> void:
	_model = model
	var instance: Node = model.scene.instantiate()
	_pose.add_child(instance)
	# Le rig importé n'est qu'une source de MOUVEMENT : `SaltBody` cache tout
	# ce qu'il apporte de visible et rebâtit le personnage en primitives, dans
	# la direction artistique du sel. Rien de ce qui s'affiche ne vient d'un
	# pack.
	var salt: SaltBody = SaltBody.dress(instance as Node3D, model.id, tint)
	for index: int in salt.pieces.size():
		var piece: MeshInstance3D = salt.pieces[index]
		var material: StandardMaterial3D = \
			piece.material_override as StandardMaterial3D
		if material == null:
			continue
		_materials.append(material)
		_base_colors.append(salt.colors[index])
		_weapon_flags.append(salt.weapons[index])
		if salt.weapons[index]:
			_weapon_pieces.append(piece)
	if instance is Node3D:
		var body: Node3D = instance as Node3D
		body.scale = Vector3.ONE * maxf(0.001, model.scale)
		body.rotation.y = deg_to_rad(model.yaw_degrees)
		body.position.y = model.lift + salt.lift * maxf(0.001, model.scale)
	# Ne PAS réassigner `root_node` de l'AnimationPlayer pour isoler le modèle :
	# cela casse la résolution des pistes de squelette et le personnage reste
	# figé en T. SaltAnimator s'en charge autrement.
	if instance is Node3D:
		_animator = SaltAnimator.build(instance as Node3D, model)
	_stand_height = actor.radius * 2.0

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Squelette de pivots. Les positions viennent du skin, pas d'une constante :
## un gobelin d'un mètre vingt et un warden de deux mètres n'ont pas les
## épaules à la même hauteur.
func _build_skeleton(skin: SkinData) -> void:
	var shoulder_l: Vector3 = Vector3(-skin.shoulder.x, skin.shoulder.y, skin.shoulder.z)
	var hip_l: Vector3 = Vector3(-skin.hip.x, skin.hip.y, skin.hip.z)
	var elbow: Vector3 = Vector3(0.0, -absf(skin.elbow_drop), 0.0)
	var knee: Vector3 = Vector3(0.0, -absf(skin.knee_drop), 0.0)

	_make_pivot(SkinPart.Role.HEAD, skin.neck, _pose)
	_make_pivot(SkinPart.Role.ARM_R, skin.shoulder, _pose)
	_make_pivot(SkinPart.Role.ARM_L, shoulder_l, _pose)
	_make_pivot(SkinPart.Role.FOREARM_R, elbow, _pivots[SkinPart.Role.ARM_R])
	_make_pivot(SkinPart.Role.FOREARM_L, elbow, _pivots[SkinPart.Role.ARM_L])
	_make_pivot(SkinPart.Role.THIGH_R, skin.hip, _pose)
	_make_pivot(SkinPart.Role.THIGH_L, hip_l, _pose)
	_make_pivot(SkinPart.Role.SHIN_R, knee, _pivots[SkinPart.Role.THIGH_R])
	_make_pivot(SkinPart.Role.SHIN_L, knee, _pivots[SkinPart.Role.THIGH_L])

func _make_pivot(role: SkinPart.Role, at: Vector3, parent: Node3D) -> void:
	var pivot: Node3D = Node3D.new()
	pivot.name = SkinPart.Role.keys()[role]
	pivot.position = at
	parent.add_child(pivot)
	_pivots[role] = pivot

func _add_part(part: SkinPart, tint: Color) -> void:
	var color: Color = PrimitiveFactory.color_for(part, tint)
	if part.is_weapon:
		color = COLOR_WEAPON_IDLE
	var instance: MeshInstance3D = PrimitiveFactory.instance_for(part, color)
	if instance == null:
		return
	var host: Node3D = _pivots.get(part.role, _pose)
	host.add_child(instance)
	_materials.append(instance.material_override as StandardMaterial3D)
	_base_colors.append(color)
	_weapon_flags.append(part.is_weapon)
	if part.is_weapon:
		_weapon_pieces.append(instance)

## Silhouette de repli : un skin absent ne doit pas rendre un personnage
## invisible, seulement anonyme. Elle passe par le même squelette que les
## autres — un cas particulier de plus serait un cas particulier à maintenir.
func _fallback_skin(actor: Actor) -> SkinData:
	var skin: SkinData = SkinData.new()
	var height: float = actor.radius * 4.0
	skin.neck = Vector3(0.0, height * 0.80, 0.0)
	skin.shoulder = Vector3(actor.radius * 0.75, height * 0.72, 0.0)
	skin.hip = Vector3(actor.radius * 0.40, height * 0.46, 0.0)
	skin.elbow_drop = height * 0.18
	skin.knee_drop = height * 0.23

	var torso: SkinPart = SkinPart.new()
	torso.shape = SkinPart.Shape.CAPSULE
	torso.size = Vector3(actor.radius * 0.62, height * 0.44, 0.0)
	torso.offset = Vector3(0.0, height * 0.60, 0.0)
	torso.tinted = true
	skin.parts.append(torso)

	var head: SkinPart = SkinPart.new()
	head.role = SkinPart.Role.HEAD
	head.shape = SkinPart.Shape.SPHERE
	head.size = Vector3(actor.radius * 0.42, 0.0, 0.0)
	head.offset = Vector3(0.0, actor.radius * 0.34, 0.0)
	head.tinted = true
	head.tint_shift = 0.2
	skin.parts.append(head)

	skin.parts.append(_stub(SkinPart.Role.ARM_R, actor.radius, skin.elbow_drop))
	skin.parts.append(_stub(SkinPart.Role.ARM_L, actor.radius, skin.elbow_drop))
	skin.parts.append(_stub(SkinPart.Role.THIGH_R, actor.radius, skin.knee_drop))
	skin.parts.append(_stub(SkinPart.Role.THIGH_L, actor.radius, skin.knee_drop))

	var blade: SkinPart = SkinPart.new()
	blade.role = SkinPart.Role.FOREARM_R
	blade.shape = SkinPart.Shape.BOX
	blade.size = Vector3(0.10, 0.10, actor.radius * 2.6)
	blade.offset = Vector3(0.0, -skin.elbow_drop * 0.6, -actor.radius * 1.1)
	blade.is_weapon = true
	skin.parts.append(blade)
	return skin

func _stub(role: SkinPart.Role, radius: float, drop: float) -> SkinPart:
	var limb: SkinPart = SkinPart.new()
	limb.role = role
	limb.shape = SkinPart.Shape.BOX
	limb.size = Vector3(radius * 0.34, drop * 1.9, radius * 0.34)
	limb.offset = Vector3(0.0, -drop * 0.9, 0.0)
	limb.tinted = true
	limb.tint_shift = -0.3
	return limb

# ---------------------------------------------------------------------------
# Rafraîchissement
# ---------------------------------------------------------------------------

## `shown` est la position INTERPOLÉE entre le tick précédent et le tick
## courant, pas `actor.position`. La simulation avance à 60 Hz ; un écran à
## 144 Hz affiche donc deux images sur trois exactement identiques, et la
## troisième saute. C'est ce qui se voit comme un jeu qui saccade, alors même
## que la carte graphique s'ennuie.
func refresh(actor: Actor, camera_position: Vector3, is_local: bool,
		player_distance: float, delta: float, shown: Vector2,
		dodge: float = 0.0) -> void:
	position = Vector3(shown.x, 0.0, shown.y)
	if not actor.facing.is_zero_approx():
		var forward: Vector3 = Vector3(actor.facing.x, 0.0, actor.facing.y)
		look_at(position + forward, Vector3.UP)

	_recoil = maxf(0.0, _recoil - delta)
	_advance_gait(shown, delta)
	if _animator != null and _animator.ready():
		_animator.drive(actor, _travel, actor.facing)
	elif _model == null:
		_animate(actor, delta)
	_apply_pose(actor, dodge)
	var open: bool = actor.runner != null and actor.runner.hitbox_open
	_apply_colors(actor, open, _fade_alpha(camera_position, is_local, player_distance))
	_apply_smear(open)

## Un coup vient d'arriver sur cet acteur. `from` est la provenance en
## coordonnées du monde ; le corps part dans l'autre sens.
##
## Purement visuel : la simulation a déjà décidé des dégâts et de la position.
## Le porte-pièces recule et se ramasse, puis revient — le personnage, lui,
## n'a pas bougé d'un centimètre.
func impact(from: Vector2) -> void:
	_recoil = RECOIL_SECONDS
	_recoil_from = from

## Vrai si cette vue est bâtie sur un modèle importé.
func uses_model() -> bool:
	return _model != null

## La foulée avance avec la distance réellement parcourue, mesurée entre deux
## images. C'est la seule mesure disponible pour un acteur distant, dont la
## position est interpolée et dont la vitesse simulée ne veut rien dire ici.
func _advance_gait(shown: Vector2, delta: float) -> void:
	_clock += delta
	if not _has_last:
		_last_position = shown
		_has_last = true
		return
	var step: Vector2 = shown - _last_position
	var travelled: float = step.length()
	_last_position = shown
	if delta > 0.0:
		# Lissé comme la vitesse scalaire, et pour la même raison : un paquet
		# réseau en retard ferait un sprint d'une image.
		var mesure: Vector2 = step / delta
		# Accélération, lissée deux fois : une différence de vitesse brute est
		# du bruit, et une inclinaison qui suit du bruit est un tremblement.
		_push = _push.lerp((mesure - _travel) / delta,
			clampf(delta * 6.0, 0.0, 1.0))
		_travel = _travel.lerp(mesure, clampf(delta * 12.0, 0.0, 1.0))
		# Lissage : un paquet réseau en retard fait un saut de position, et un
		# saut de position ferait un sprint d'une image sans ce filtre.
		_speed = lerpf(_speed, travelled / delta, clampf(delta * 12.0, 0.0, 1.0))
	_gait = fmod(_gait + travelled * STRIDE_PER_METRE, TAU)

func _animate(actor: Actor, delta: float) -> void:
	var moving: float = clampf(_speed / FULL_STRIDE_SPEED, 0.0, 1.0)
	var grounded: bool = actor.state != Actor.State.DEAD
	var amplitude: float = 0.0
	if grounded:
		amplitude = deg_to_rad(_stride_degrees) * moving
	var swing: float = sin(_gait) * amplitude

	var leg_rate: float = clampf(delta * LIMB_BLEND_RATE, 0.0, 1.0)
	_leg_swing = lerpf(_leg_swing, swing, leg_rate)
	_arm_swing = lerpf(_arm_swing, -swing * 0.75, leg_rate)

	_set_pitch(SkinPart.Role.THIGH_R, _leg_swing)
	_set_pitch(SkinPart.Role.THIGH_L, -_leg_swing)
	# Le genou ne plie que vers l'arrière, et surtout quand la cuisse revient :
	# c'est ce qui distingue une jambe d'un balancier.
	_set_pitch(SkinPart.Role.SHIN_R, -maxf(0.0, -_leg_swing) * 1.15)
	_set_pitch(SkinPart.Role.SHIN_L, -maxf(0.0, _leg_swing) * 1.15)

	var target: float = deg_to_rad(_weapon_target(actor))
	_weapon_arm = lerpf(_weapon_arm, target,
		clampf(delta * ATTACK_BLEND_RATE, 0.0, 1.0))
	_set_pitch(SkinPart.Role.ARM_R, _weapon_arm)
	_set_pitch(SkinPart.Role.ARM_L, -_arm_swing)
	var rest: float = deg_to_rad(ELBOW_REST_DEGREES)
	_set_pitch(SkinPart.Role.FOREARM_R, rest * (1.0 - moving * 0.4))
	_set_pitch(SkinPart.Role.FOREARM_L, rest - absf(_arm_swing) * 0.5)

	# La tête regarde là où le corps va, avec un temps de retard.
	_set_pitch(SkinPart.Role.HEAD, sin(_gait * 2.0) * amplitude * 0.12)

	var bob: float = 0.0
	if grounded:
		bob = sin(_clock * 2.1) * _idle_bob * (1.0 - moving) \
			+ absf(sin(_gait)) * 0.035 * moving
	_pose.position.y = bob

## Angle du bras porteur d'arme. Toute la lisibilité du combat tient dans ces
## quatre valeurs : levé en arrière pendant la préparation, abattu devant
## pendant la hitbox, tendu droit devant pour un lancer, levé haut pour un
## soin. Un joueur doit pouvoir lire l'intention avant l'impact.
func _weapon_target(actor: Actor) -> float:
	var runner: AttackRunner = actor.runner
	if runner == null or runner.finished or runner.attack == null:
		if actor.state == Actor.State.DODGING:
			return -40.0
		return 0.0
	var attack: AttackData = runner.attack
	if attack.heal > 0:
		return ARM_HEAL_DEGREES
	if attack.projectile != null:
		return ARM_CAST_DEGREES
	if runner.hitbox_open:
		return ARM_STRIKE_DEGREES
	return ARM_WINDUP_DEGREES

func _set_pitch(role: SkinPart.Role, radians: float) -> void:
	var pivot: Node3D = _pivots.get(role, null)
	if pivot != null:
		pivot.rotation.x = radians

## Traînée d'arme : une copie fantôme derrière la lame, visible uniquement
## pendant que la hitbox est ouverte. C'est un doublon de la couleur d'arme,
## et c'est voulu — le repère de rythme mérite deux signaux plutôt qu'un.
func _apply_smear(open: bool) -> void:
	for piece: Node3D in _weapon_pieces:
		piece.scale = Vector3(1.0, 1.0, 1.28) if open else Vector3.ONE

## La pose d'ensemble s'applique au porte-pièces, jamais au nœud racine :
## celui-ci porte l'orientation du personnage, et la mort ne doit pas la faire
## tourner.
func _apply_pose(actor: Actor, dodge: float) -> void:
	# Un corps monté sur squelette a ses propres animations de chute et
	# d'esquive : les doubler d'une bascule du porte-pièces le coucherait deux
	# fois. La ROULADE, elle, n'existe dans aucune bibliothèque d'animation —
	# les paquets fournissent des pas de côté — donc c'est ici qu'elle se
	# fait, et c'est la seule pose qu'on impose à un modèle.
	if _model != null:
		if actor.state == Actor.State.DODGING:
			_apply_roll(dodge)
		else:
			_apply_lean(actor)
		return
	match actor.state:
		Actor.State.DEAD:
			# Couché : la mort doit se lire d'un coup d'œil, de loin.
			_pose.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
			_pose.position = Vector3(0.0, _stand_height * 0.15, 0.0)
		Actor.State.STAGGERED:
			_pose.rotation = Vector3(0.22, 0.0, 0.0)
		Actor.State.DODGING:
			# Ramassé au sol : la fenêtre d'invulnérabilité doit être visible.
			_pose.rotation = Vector3(-0.55, 0.0, 0.0)
			_pose.position = Vector3(0.0, -_stand_height * 0.28, 0.0)
		_:
			_pose.rotation = Vector3.ZERO

## Inclinaison du corps dans le sens de l'ACCÉLÉRATION : on se penche pour
## partir, on se redresse pour s'arrêter, on s'incline dans un virage. Aucune
## bibliothèque d'animation ne le fournit — un clip de course est droit — et
## c'est pourtant ce qui fait la différence entre un personnage qui se déplace
## et un personnage qui glisse.
##
## Le pivot est aux pieds, volontairement : c'est un corps qui bascule sur ses
## appuis, pas une figurine qui tourne.
func _apply_lean(actor: Actor) -> void:
	var pitch: float = 0.0
	var roll: float = 0.0
	if actor.state != Actor.State.DEAD and actor.state != Actor.State.STAGGERED:
		var forward: Vector2 = actor.facing.normalized() 			if not actor.facing.is_zero_approx() else Vector2(0.0, 1.0)
		var right: Vector2 = Vector2(forward.y, -forward.x)
		pitch = clampf(_push.dot(forward) * LEAN_PER_ACCEL,
			-LEAN_MAX, LEAN_MAX)
		roll = clampf(-_push.dot(right) * LEAN_PER_ACCEL,
			-LEAN_MAX, LEAN_MAX)
	# -X penche vers l'avant : `look_at` fait pointer le -Z du nœud vers la
	# cible, donc l'avant du personnage est en -Z.
	var basis: Basis = Basis.from_euler(Vector3(-pitch, 0.0, roll))
	var offset: Vector3 = Vector3.ZERO
	if _recoil > 0.0:
		var part: float = _recoil / RECOIL_SECONDS
		# Sortie brutale, retour lent : un corps encaisse d'un coup et se
		# replace en titubant.
		var amount: float = sin(part * PI * 0.5) * RECOIL_METRES
		var away: Vector3 = (global_position
			- Vector3(_recoil_from.x, 0.0, _recoil_from.y))
		away.y = 0.0
		if away.length() > 0.01:
			offset = global_transform.basis.inverse() * away.normalized() * amount
		basis = basis.scaled(Vector3(1.0 + part * 0.05, 1.0 - part * 0.09,
			1.0 + part * 0.05))
	_pose.transform = Transform3D(basis, offset)

## Roulade : un tour complet vers l'avant, pivoté à hauteur de HANCHE et non
## aux pieds. Tourner autour des pieds ferait décrire au personnage un arc de
## cercle d'un mètre de rayon — il partirait en l'air, et c'est exactement
## l'erreur qu'on fait la première fois.
##
## Le corps se ramasse au début et se redresse à la fin ; l'échelle verticale
## suit, ce qui donne l'impression d'un corps qui se roule en boule plutôt
## que d'une planche qui pivote.
func _apply_roll(progress: float) -> void:
	var eased: float = clampf(progress, 0.0, 1.0)
	# Le tour n'est pas linéaire : vif au décollage, il finit posé, à l'image
	# du profil de vitesse que la simulation applique au même moment.
	var turn: float = 1.0 - pow(1.0 - eased, 2.0)
	var pivot: Vector3 = Vector3(0.0, ROLL_PIVOT_HEIGHT * _body_scale(), 0.0)
	var basis: Basis = Basis(Vector3.RIGHT, -TAU * turn)
	var tuck: float = 1.0 - sin(eased * PI) * ROLL_TUCK
	basis = basis.scaled(Vector3(1.0, tuck, 1.0))
	_pose.transform = Transform3D(basis, pivot - basis * pivot)

## Hauteur du personnage rapportée à celle pour laquelle les constantes de
## roulade sont réglées : un gobelin ne roule pas autour du même axe qu'un
## boss.
func _body_scale() -> float:
	return clampf(_stand_height / 0.90, 0.6, 1.8)

func _fade_alpha(camera_position: Vector3, is_local: bool, player_distance: float) -> float:
	if is_local or player_distance <= 0.0:
		return 1.0
	var distance: float = global_position.distance_to(camera_position)
	# Positif quand l'acteur est devant le personnage vu de la caméra.
	var intrusion: float = player_distance - distance
	var hidden: float = clampf(
		inverse_lerp(FADE_MARGIN, FADE_FULL_AT, intrusion), 0.0, 1.0)
	return maxf(FADE_FLOOR, 1.0 - hidden)

func _apply_colors(actor: Actor, weapon_open: bool, alpha: float) -> void:
	var shift: float = 0.0
	match actor.state:
		Actor.State.DEAD:
			shift = -0.55
		Actor.State.STAGGERED:
			shift = 0.35
		Actor.State.DODGING:
			shift = 0.15
		_:
			shift = 0.0
	# Le mélange alpha ne s'active qu'en cas de besoin : laissé en permanence,
	# il imposerait un tri par profondeur à toute la scène pour rien.
	var mode: BaseMaterial3D.Transparency = BaseMaterial3D.TRANSPARENCY_DISABLED \
		if alpha >= 0.99 else BaseMaterial3D.TRANSPARENCY_ALPHA
	for index: int in _materials.size():
		var base: Color = _base_colors[index]
		if _weapon_flags[index]:
			base = COLOR_WEAPON_ACTIVE if weapon_open else COLOR_WEAPON_IDLE
		var tinted: Color = base
		if shift > 0.0:
			tinted = base.lightened(shift)
		elif shift < 0.0:
			tinted = base.darkened(-shift)
		tinted.a = alpha
		_materials[index].albedo_color = tinted
		_materials[index].transparency = mode
