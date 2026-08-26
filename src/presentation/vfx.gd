## Un effet visuel bref : anneau, éclats, halo.
##
## Invariant 2 : présentation pure. Un effet ne blesse personne, ne soigne
## personne et n'existe pas dans la simulation. Il naît d'un changement
## D'ÉTAT DÉJÀ ARRIVÉ (des points de vie qui ont baissé, un projectile qui a
## disparu) et se contente de le rendre lisible.
##
## Invariant 1 ne s'applique pas ici : un effet est daté en secondes réelles,
## pas en ticks. C'est justement parce qu'il ne touche pas au jeu qu'il a le
## droit de suivre la fréquence d'affichage. Confondre les deux horloges est
## l'erreur que l'invariant 1 interdit — pas en avoir deux.
class_name Vfx
extends Node3D

enum Kind {
	## Un projectile s'est éteint : éclat sec au point de disparition.
	IMPACT,
	## Un acteur a perdu des points de vie : gerbe rouge vers le haut.
	HIT,
	## Un acteur en a regagné : anneaux qui montent.
	HEAL,
	## Un lancer commence : anneau au sol sous le lanceur.
	CAST,
	## Un éclat de verre de saumure se brise : la gerbe des sorts. Beaucoup
	## de fragments, une lumière franche, et c'est fini avant qu'on l'ait lu.
	SHATTER,
	## Le rinçage : la saumure emporte le sel. Gouttes qui TOMBENT, anneau qui
	## descend — l'inverse exact d'un soin qui monte, parce que dans ce monde
	## on ne rend pas de la vie, on enlève quelque chose.
	RINSE,
	## Une escarbille de traînée : un seul fragment qui s'éteint sur place.
	MOTE,
	## Poussière de sel soulevée par une roulade : basse, large, sans lumière.
	## C'est ce qui donne du poids à une esquive — sans elle, un corps qui se
	## jette au sol ne touche rien.
	DUST,
}

const DURATIONS: Dictionary[Kind, float] = {
	Kind.IMPACT: 0.32,
	Kind.HIT: 0.34,
	Kind.HEAL: 0.75,
	Kind.CAST: 0.42,
	Kind.SHATTER: 0.40,
	Kind.RINSE: 0.80,
	Kind.MOTE: 0.26,
	Kind.DUST: 0.55,
}

var _age: float = 0.0
var _life: float = 0.3
var _kind: Kind = Kind.IMPACT
var _materials: Array[StandardMaterial3D] = []
var _shards: Array[Node3D] = []
var _velocities: Array[Vector3] = []
var _rings: Array[Node3D] = []
var _base_scales: Array[float] = []
var _lights: Array[OmniLight3D] = []
var _light_energies: Array[float] = []

## Fabrique et pose l'effet. `at` est en coordonnées monde.
static func spawn(parent: Node3D, kind: Kind, at: Vector3, color: Color) -> Vfx:
	var effect: Vfx = Vfx.new()
	effect.name = "Vfx"
	parent.add_child(effect)
	effect.global_position = at
	effect._build(kind, color)
	return effect

func _build(kind: Kind, color: Color) -> void:
	_kind = kind
	_life = DURATIONS.get(kind, 0.3)
	match kind:
		Kind.IMPACT:
			_add_ring(0.18, 0.34, color, 0.0)
			_burst(7, color, 3.4, 0.075)
		Kind.HIT:
			# L'anneau était posé un mètre AU-DESSUS du point d'apparition,
			# parce que l'effet naissait aux pieds et devait remonter au buste.
			# Il naît maintenant directement au point touché : le mètre en trop
			# le mettait au-dessus de la tête.
			_add_ring(0.34, 0.62, color, 0.0)
			_burst(14, color, 3.4, 0.095)
			# Un éclair court. C'est ce qui manquait le plus : sans lumière,
			# une gerbe rouge sur un sol de sel blanc ne se voit pas, et le
			# seul signe qu'un coup a porté était la barre de vie.
			_flash(color, 4.2, 2.6)
		Kind.HEAL:
			_add_ring(0.34, 0.52, color, 0.05)
			_add_ring(0.20, 0.34, color, 0.55)
			_burst(6, color, 1.1, 0.07)
		Kind.CAST:
			_add_ring(0.52, 0.78, color, 0.02)
			_add_ring(0.34, 0.46, color, 0.02)
			# Éclats qui MONTENT vers la main : un sort se rassemble avant de
			# partir. C'est le seul télégraphe qu'un adversaire ait, donc il
			# doit se lire avant le tir, pas pendant.
			_rise(8, color, 2.1, 0.055)
			_flash(color, 5.0, 2.2)
		Kind.SHATTER:
			_add_ring(0.16, 0.30, color, 0.0)
			_burst(14, color, 5.2, 0.055)
			_flash(color, 6.5, 4.0)
		Kind.RINSE:
			_add_ring(0.46, 0.66, color, 1.75)
			_add_ring(0.30, 0.42, color, 1.4)
			_rain(10, color, 0.05)
			_flash(color, 3.6, 1.2)
		Kind.MOTE:
			_burst(1, color, 0.0, 0.05)
		Kind.DUST:
			_add_ring(0.24, 0.40, color, 0.05)
			_burst(9, color, 1.9, 0.075)

## Anneau plat, posé à `height`. Additif : il éclaire au lieu de masquer, ce
## qui le rend lisible sur un sol sombre comme sur une armure claire.
func _add_ring(inner: float, outer: float, color: Color, height: float) -> void:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 20
	torus.ring_segments = 5
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = torus
	instance.material_override = _additive(color)
	instance.position = Vector3(0.0, height, 0.0)
	add_child(instance)
	_rings.append(instance)
	_base_scales.append(1.0)

## Éclats jetés dans toutes les directions. Le pas angulaire est fixe et non
## tiré au hasard : deux joueurs doivent voir la même gerbe, et un effet ne
## doit jamais dépendre d'une source d'aléa que la simulation ne connaît pas.
func _burst(count: int, color: Color, speed: float, size: float) -> void:
	for index: int in count:
		var angle: float = TAU * float(index) / float(count)
		var lift: float = 0.55 + 0.45 * float(index % 3)
		var shard: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(size, size, size * 2.2)
		shard.mesh = box
		shard.material_override = _additive(color)
		shard.position = Vector3(0.0, 0.9, 0.0)
		add_child(shard)
		_shards.append(shard)
		_velocities.append(
			Vector3(cos(angle), lift, sin(angle)) * speed)

## Éclats qui montent en spirale vers la main du lanceur.
func _rise(count: int, color: Color, height: float, size: float) -> void:
	for index: int in count:
		var angle: float = TAU * float(index) / float(count)
		var radius: float = 0.42 + 0.18 * float(index % 2)
		var shard: MeshInstance3D = MeshInstance3D.new()
		var prism: PrismMesh = PrismMesh.new()
		prism.size = Vector3(size, size * 3.4, size)
		shard.mesh = prism
		shard.material_override = _additive(color)
		shard.position = Vector3(cos(angle) * radius, 0.05, sin(angle) * radius)
		add_child(shard)
		_shards.append(shard)
		_velocities.append(Vector3(-cos(angle) * 0.5, height, -sin(angle) * 0.5))

## Gouttes qui tombent : le rinçage. La gravité normale les fait accélérer,
## donc on les lâche déjà lancées vers le bas.
func _rain(count: int, color: Color, size: float) -> void:
	for index: int in count:
		var angle: float = TAU * float(index) / float(count)
		var radius: float = 0.20 + 0.16 * float(index % 3)
		var drop: MeshInstance3D = MeshInstance3D.new()
		var capsule: CapsuleMesh = CapsuleMesh.new()
		capsule.radius = size
		capsule.height = size * 5.0
		capsule.radial_segments = 6
		capsule.rings = 2
		drop.mesh = capsule
		drop.material_override = _additive(color)
		drop.position = Vector3(cos(angle) * radius, 1.9, sin(angle) * radius)
		add_child(drop)
		_shards.append(drop)
		_velocities.append(Vector3(0.0, -1.4 - 0.4 * float(index % 3), 0.0))

## Éclair bref. Une lumière VRAIE, pas un aplat additif : c'est elle qui fait
## qu'un sort éclaire le mur d'en face, et c'est ce qui manquait le plus.
func _flash(color: Color, reach: float, energy: float) -> void:
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.omni_range = reach
	lamp.light_energy = energy
	lamp.light_color = color
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.0, 1.0, 0.0)
	add_child(lamp)
	_lights.append(lamp)
	_light_energies.append(energy)

func _additive(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials.append(material)
	return material

## Vitesse d'expansion des anneaux, par genre.
func _spread() -> float:
	match _kind:
		Kind.IMPACT:
			return 2.6
		Kind.SHATTER:
			return 3.4
		Kind.CAST:
			return -0.45
		Kind.RINSE:
			return 0.6
		Kind.DUST:
			return 2.2
		_:
			return 1.4

## Gravité appliquée aux fragments. Négative pour un lancer : les éclats
## remontent vers la main au lieu de retomber.
func _gravity() -> float:
	match _kind:
		Kind.CAST:
			return -3.0
		Kind.SHATTER:
			return 5.0
		Kind.RINSE:
			return 5.5
		Kind.MOTE:
			return 0.6
		Kind.DUST:
			return 1.6
		_:
			return 7.0

func _process(delta: float) -> void:
	_age += delta
	var t: float = clampf(_age / _life, 0.0, 1.0)
	# Décroissance quadratique : l'effet est franc à l'apparition et s'efface
	# sans traîner. Une décroissance linéaire donne une bouillie permanente
	# quand trois ennemis frappent en même temps.
	var alpha: float = (1.0 - t) * (1.0 - t)
	for material: StandardMaterial3D in _materials:
		var color: Color = material.albedo_color
		color.a = alpha
		material.albedo_color = color

	# La lumière s'éteint plus vite que les éclats : un éclair qui traîne se
	# lit comme une lampe allumée, pas comme un impact.
	for index: int in _lights.size():
		_lights[index].light_energy = _light_energies[index] * pow(1.0 - t, 3.0)

	var grow: float = 1.0 + t * _spread()
	for index: int in _rings.size():
		var ring: Node3D = _rings[index]
		ring.scale = Vector3.ONE * (_base_scales[index] * grow)
		if _kind == Kind.HEAL:
			ring.position.y += delta * 1.35
		elif _kind == Kind.RINSE:
			ring.position.y -= delta * 2.0
		elif _kind == Kind.CAST:
			ring.position.y += delta * 0.5

	var gravity: float = _gravity()
	for index: int in _shards.size():
		var shard: Node3D = _shards[index]
		var velocity: Vector3 = _velocities[index]
		shard.position += velocity * delta
		# Gravité : les éclats retombent, ce qui donne du poids au coup. Les
		# éclats d'un sort en cours de lancer, eux, sont ASPIRÉS vers le haut.
		_velocities[index] = velocity + Vector3.DOWN * gravity * delta
		shard.rotate_y(delta * 6.0)

	if _age >= _life:
		queue_free()
