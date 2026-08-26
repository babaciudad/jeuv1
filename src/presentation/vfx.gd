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

## Blanc de cœur. Les premières fractions de seconde d'un impact, d'un éclat
## ou d'une gerbe ne sont PAS de la couleur de l'effet : elles sont blanches,
## parce que ce qui brille fort brûle le capteur. C'est ce virage du blanc
## vers la couleur qui fait qu'un effet a l'air d'une décharge d'énergie et
## non d'un confetti coloré.
const CORE: Color = Color(1.0, 0.97, 0.90)

var _age: float = 0.0
var _life: float = 0.3
var _kind: Kind = Kind.IMPACT
var _materials: Array[StandardMaterial3D] = []
## Couleur de destination de chaque matériau, dans le même ordre. Elle n'est
## pas lue sur le matériau : celui-ci porte la couleur de l'INSTANT, qui part
## du blanc.
var _material_tones: Array[Color] = []
## Couleur de DÉPART de chaque matériau. Blanc pour ce qui brille, la couleur
## elle-même pour ce qui ne brille pas — une poussière n'a jamais été blanche
## de chaleur.
var _material_cores: Array[Color] = []
var _shards: Array[Node3D] = []
var _velocities: Array[Vector3] = []
## Longueur au repos de chaque fragment. Un éclat lancé s'ÉTIRE dans le sens
## de sa course : c'est ce qui sépare une étincelle d'un cube qui vole.
var _shard_lengths: Array[float] = []
var _rings: Array[Node3D] = []
var _base_scales: Array[float] = []
## Retard d'apparition de chaque anneau, en fraction de vie. Trois anneaux qui
## partent ensemble font un seul anneau épais ; décalés, ils font une onde.
var _ring_delays: Array[float] = []
var _lights: Array[OmniLight3D] = []
var _light_energies: Array[float] = []
## Voiles plats face caméra : l'éclair de la première image.
var _flares: Array[Node3D] = []

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
			_flare(color, 1.05, 0.55)
		Kind.HIT:
			# L'anneau était posé un mètre AU-DESSUS du point d'apparition,
			# parce que l'effet naissait aux pieds et devait remonter au buste.
			# Il naît maintenant directement au point touché : le mètre en trop
			# le mettait au-dessus de la tête.
			_add_ring(0.34, 0.62, color, 0.0)
			# Une SECONDE onde, en retard et plus large. Un coup qui porte
			# n'a pas un contour, il en a deux : le point d'impact et ce qui
			# part de lui. Sur une seule image d'un jeu à soixante, c'est la
			# différence entre « il s'est passé quelque chose » et « il s'est
			# passé quelque chose de violent ».
			_add_ring(0.20, 0.30, color, 0.0, 0.22)
			_burst(14, color, 3.4, 0.095)
			# Un éclair court. C'est ce qui manquait le plus : sans lumière,
			# une gerbe rouge sur un sol de sel blanc ne se voit pas, et le
			# seul signe qu'un coup a porté était la barre de vie.
			_flash(color, 4.2, 2.6)
			_flare(color, 1.5, 0.62)
		Kind.HEAL:
			_add_ring(0.34, 0.52, color, 0.05)
			_add_ring(0.20, 0.34, color, 0.55, 0.26)
			_add_ring(0.26, 0.40, color, 1.05, 0.52)
			_rise(9, color, 1.5, 0.05)
			_flash(color, 3.4, 1.1)
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
			_flare(color, 1.8, 0.70)
		Kind.RINSE:
			_add_ring(0.46, 0.66, color, 1.75)
			_add_ring(0.30, 0.42, color, 1.4, 0.20)
			# Une ride au SOL, après coup : ce qui tombe finit par toucher.
			_add_ring(0.28, 0.38, color, 0.03, 0.55)
			_rain(14, color, 0.05)
			_flash(color, 3.6, 1.2)
		Kind.MOTE:
			_burst(1, color, 0.0, 0.05)
		Kind.DUST:
			# PAS D'ADDITIF ICI, et c'est tout le sujet. De la poussière est
			# de la matière qui BOUCHE : posée en additif sur un dallage de
			# sel déjà clair, elle n'ajoutait rigoureusement rien de visible.
			# Une roulade ne soulevait donc rien du tout — le seul genre
			# d'effet dont on ne remarque pas l'absence, et le seul qui donne
			# du poids à une esquive.
			_add_ring(0.24, 0.40, color, 0.04)
			_puffs(10, color, 1.6)

## Anneau plat, posé à `height`. Additif : il éclaire au lieu de masquer, ce
## qui le rend lisible sur un sol sombre comme sur une armure claire.
func _add_ring(inner: float, outer: float, color: Color, height: float,
		delay: float = 0.0) -> void:
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
	_ring_delays.append(delay)

## Voile plat tourné vers la caméra : l'éblouissement de la première image.
## Un anneau et des éclats mettent trois images à se lire ; à soixante images
## par seconde, un coup dure quatre images. Ce voile-là est vu.
func _flare(color: Color, size: float, height: float) -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = quad
	var material: StandardMaterial3D = _additive(color)
	# Face caméra quoi qu'il arrive : un voile vu par la tranche n'éblouit
	# personne.
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	instance.material_override = material
	instance.position = Vector3(0.0, height, 0.0)
	add_child(instance)
	_flares.append(instance)

## Éclats jetés dans toutes les directions. Le pas angulaire est fixe et non
## tiré au hasard : deux joueurs doivent voir la même gerbe, et un effet ne
## doit jamais dépendre d'une source d'aléa que la simulation ne connaît pas.
func _burst(count: int, color: Color, speed: float, size: float) -> void:
	for index: int in count:
		var angle: float = TAU * float(index) / float(count)
		var lift: float = 0.55 + 0.45 * float(index % 3)
		# Vitesses INÉGALES. Une gerbe dont tous les éclats vont à la même
		# allure reste un anneau : on lit le cercle, pas la projection. Le pas
		# est fixe et non tiré au hasard — deux joueurs doivent voir la même
		# gerbe.
		var pace: float = speed * (0.62 + 0.38 * float((index * 7) % 5))
		var shard: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(size, size, size * 2.2)
		shard.mesh = box
		shard.material_override = _additive(color)
		shard.position = Vector3(0.0, 0.9, 0.0)
		add_child(shard)
		_shards.append(shard)
		_shard_lengths.append(size * 2.2)
		_velocities.append(
			Vector3(cos(angle), lift, sin(angle)) * pace)

## Bouffées de poussière : opaques, pâles, lentes, et sans lumière. Elles
## montent à peine et s'élargissent beaucoup — c'est ce qui distingue un
## nuage soulevé d'une gerbe projetée.
func _puffs(count: int, color: Color, speed: float) -> void:
	for index: int in count:
		var angle: float = TAU * float(index) / float(count)
		var puff: MeshInstance3D = MeshInstance3D.new()
		var blob: SphereMesh = SphereMesh.new()
		blob.radius = 0.13 + 0.05 * float(index % 3)
		blob.height = blob.radius * 1.7
		blob.radial_segments = 7
		blob.rings = 4
		puff.mesh = blob
		puff.material_override = _powder(color)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.position = Vector3(cos(angle) * 0.22, 0.10, sin(angle) * 0.22)
		add_child(puff)
		_shards.append(puff)
		# Longueur nulle : une bouffée ne s'étire pas, elle enfle.
		_shard_lengths.append(0.0)
		var pace: float = speed * (0.55 + 0.30 * float(index % 4))
		_velocities.append(
			Vector3(cos(angle) * pace, 0.55 + 0.20 * float(index % 2),
				sin(angle) * pace))

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
		_shard_lengths.append(size * 3.4)
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
		_shard_lengths.append(size * 5.0)
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
	# On part du BLANC : `_process` fera le virage vers `color`. Poser la
	# couleur finale tout de suite revient à se priver du seul instant où un
	# effet a l'air chaud.
	material.albedo_color = CORE
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials.append(material)
	_material_cores.append(CORE)
	_material_tones.append(color)
	return material

## Matière de poussière : opaque, mate, non éclairée, et surtout PAS additive.
## Elle bouche ce qu'il y a derrière, ce qui est la seule chose qu'on demande
## à de la poussière.
func _powder(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials.append(material)
	_material_cores.append(color)
	_material_tones.append(color)
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
	# Le virage du blanc vers la couleur se fait dans le PREMIER QUART de la
	# vie de l'effet, pas sur toute sa durée : au-delà, ce n'est plus une
	# décharge qui refroidit, c'est un dégradé.
	var cooled: float = clampf(t * 4.0, 0.0, 1.0)
	for index: int in _materials.size():
		var material: StandardMaterial3D = _materials[index]
		var color: Color = _material_cores[index].lerp(
			_material_tones[index], cooled)
		color.a = alpha
		material.albedo_color = color

	# La lumière s'éteint plus vite que les éclats : un éclair qui traîne se
	# lit comme une lampe allumée, pas comme un impact.
	for index: int in _lights.size():
		_lights[index].light_energy = _light_energies[index] * pow(1.0 - t, 3.0)

	var spread: float = _spread()
	for index: int in _rings.size():
		var ring: Node3D = _rings[index]
		var delay: float = _ring_delays[index]
		# Un anneau en retard n'existe pas encore : le montrer à l'échelle
		# zéro laisse un point brillant au centre pendant tout son retard.
		ring.visible = t >= delay
		var own: float = clampf((t - delay) / maxf(1.0 - delay, 0.001),
			0.0, 1.0)
		var grow: float = 1.0 + own * spread
		# À PLAT, jamais en volume. Un tore mis à l'échelle sur ses trois axes
		# épaissit son tube en même temps qu'il s'élargit : au bout de sa
		# course, l'onde est un beignet. Une onde de choc s'étale, elle
		# n'enfle pas.
		ring.scale = Vector3(_base_scales[index] * grow, 1.0,
			_base_scales[index] * grow)
		if _kind == Kind.HEAL:
			ring.position.y += delta * 1.35
		elif _kind == Kind.RINSE and ring.position.y > 0.10:
			ring.position.y -= delta * 2.0
		elif _kind == Kind.CAST:
			ring.position.y += delta * 0.5

	# Le voile s'ouvre vite et meurt encore plus vite : il ne dure que le
	# temps qu'on ne peut pas ne pas voir.
	for index: int in _flares.size():
		var flare: Node3D = _flares[index]
		flare.scale = Vector3.ONE * (0.45 + t * 2.4)
		flare.visible = t < 0.45

	var gravity: float = _gravity()
	for index: int in _shards.size():
		var shard: Node3D = _shards[index]
		var velocity: Vector3 = _velocities[index]
		shard.position += velocity * delta
		# Gravité : les éclats retombent, ce qui donne du poids au coup. Les
		# éclats d'un sort en cours de lancer, eux, sont ASPIRÉS vers le haut.
		_velocities[index] = velocity + Vector3.DOWN * gravity * delta
		var length: float = _shard_lengths[index]
		if length <= 0.0:
			# Une bouffée de poussière enfle et ralentit : elle ne tourne pas
			# et elle ne s'étire pas.
			shard.scale = Vector3.ONE * (1.0 + t * 2.6)
			_velocities[index] = _velocities[index] * (1.0 - delta * 2.2)
			continue
		# ÉTIREMENT DANS LE SENS DE LA COURSE. Un éclat rapide est une traînée,
		# pas un dé qui tournoie : c'est ce qui manquait le plus à la gerbe.
		# Le facteur est borné, sinon un éclat lancé à cinq mètres par seconde
		# devient une aiguille de trente centimètres.
		var pace: float = _velocities[index].length()
		if pace > 0.01:
			var forward: Vector3 = _velocities[index] / pace
			var up: Vector3 = Vector3.UP
			if absf(forward.dot(up)) > 0.98:
				up = Vector3.FORWARD
			shard.basis = Basis.looking_at(forward, up)
			shard.scale = Vector3(1.0, 1.0,
				clampf(1.0 + pace * 0.34 / maxf(length, 0.01), 1.0, 5.0))

	if _age >= _life:
		queue_free()
