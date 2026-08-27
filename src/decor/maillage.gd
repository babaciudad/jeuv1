## Sortir un maillage d'un fichier importé, et lui donner le vent.
##
## Un `.glb` s'importe en `PackedScene` : pour le semer par milliers en
## `MultiMesh`, il faut en extraire le `Mesh`, et pour qu'il plie au vent il
## faut remplacer ses matériaux — en gardant leur couleur et leur texture,
## sinon toute la végétation devient grise.
class_name Maillage
extends RefCounted

static var _cache: Dictionary[String, Mesh] = {}

## Le premier maillage trouvé dans un fichier, avec ses matériaux remplacés par
## le shader de vent.
static func au_vent(chemin: String) -> Mesh:
	if _cache.has(chemin):
		return _cache[chemin]
	var maille: Mesh = _extraire(chemin)
	if maille != null:
		_ventiler(maille)
	_cache[chemin] = maille
	return maille

static func _extraire(chemin: String) -> Mesh:
	if not ResourceLoader.exists(chemin):
		push_warning("Modèle introuvable : %s" % chemin)
		return null
	var paquet: PackedScene = load(chemin) as PackedScene
	if paquet == null:
		return null
	var racine: Node = paquet.instantiate()
	var trouve: MeshInstance3D = _premier_maillage(racine)
	var maille: Mesh = null
	if trouve != null:
		maille = trouve.mesh
	racine.free()
	return maille

static func _premier_maillage(noeud: Node) -> MeshInstance3D:
	var instance: MeshInstance3D = noeud as MeshInstance3D
	if instance != null and instance.mesh != null:
		return instance
	for enfant: Node in noeud.get_children():
		var trouve: MeshInstance3D = Maillage._premier_maillage(enfant)
		if trouve != null:
			return trouve
	return null

## Remplace chaque matériau de surface par le shader de vent, en lui repassant
## la couleur et la texture d'origine. Sans ça, ou bien la plante ne bouge pas,
## ou bien elle perd sa matière.
static func _ventiler(maille: Mesh) -> void:
	var shader: Shader = load("res://shaders/vegetation.gdshader") as Shader
	if shader == null:
		return
	for surface: int in range(maille.get_surface_count()):
		var origine: StandardMaterial3D = \
			maille.surface_get_material(surface) as StandardMaterial3D
		var materiau: ShaderMaterial = ShaderMaterial.new()
		materiau.shader = shader
		if origine != null:
			materiau.set_shader_parameter(&"teinte", origine.albedo_color)
			if origine.albedo_texture != null:
				materiau.set_shader_parameter(&"image", origine.albedo_texture)
				materiau.set_shader_parameter(&"avec_image", true)
		maille.surface_set_material(surface, materiau)

## Recopie la force du vent dans tous les matériaux d'un semis.
static func souffler(maille: Mesh, vent: float) -> void:
	if maille == null:
		return
	for surface: int in range(maille.get_surface_count()):
		var materiau: ShaderMaterial = \
			maille.surface_get_material(surface) as ShaderMaterial
		if materiau != null:
			materiau.set_shader_parameter(&"vent", vent)
