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
	## Un acteur en a regagné : anneaux verts qui montent.
	HEAL,
	## Un lancer commence : anneau au sol sous le lanceur.
	CAST,
}

const DURATIONS: Dictionary[Kind, float] = {
	Kind.IMPACT: 0.32,
	Kind.HIT: 0.45,
	Kind.HEAL: 0.75,
	Kind.CAST: 0.30,
}

var _age: float = 0.0
var _life: float = 0.3
var _kind: Kind = Kind.IMPACT
var _materials: Array[StandardMaterial3D] = []
var _shards: Array[Node3D] = []
var _velocities: Array[Vector3] = []
var _rings: Array[Node3D] = []
var _base_scales: Array[float] = []

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
			_add_ring(0.30, 0.52, color, 1.0)
			_burst(9, color, 2.6, 0.085)
		Kind.HEAL:
			_add_ring(0.34, 0.52, color, 0.05)
			_add_ring(0.20, 0.34, color, 0.55)
			_burst(6, color, 1.1, 0.07)
		Kind.CAST:
			_add_ring(0.52, 0.78, color, 0.02)
			_add_ring(0.34, 0.46, color, 0.02)

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

	var grow: float = 1.0 + t * (2.6 if _kind == Kind.IMPACT else 1.4)
	for index: int in _rings.size():
		var ring: Node3D = _rings[index]
		ring.scale = Vector3.ONE * (_base_scales[index] * grow)
		if _kind == Kind.HEAL:
			ring.position.y += delta * 1.35

	for index: int in _shards.size():
		var shard: Node3D = _shards[index]
		var velocity: Vector3 = _velocities[index]
		shard.position += velocity * delta
		# Gravité : les éclats retombent, ce qui donne du poids au coup.
		_velocities[index] = velocity + Vector3.DOWN * 7.0 * delta
		shard.rotate_y(delta * 6.0)

	if _age >= _life:
		queue_free()
