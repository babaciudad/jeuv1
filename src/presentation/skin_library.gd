## Chargement des skins, par identifiant, avec cache.
##
## Un skin manquant n'est pas une erreur : la vue retombe sur une silhouette
## par défaut. Un personnage sans habillage doit rester jouable.
class_name SkinLibrary
extends RefCounted

const DIRECTORY: String = "res://data/skins/"

static var _cache: Dictionary[StringName, SkinData] = {}

static func for_id(id: StringName) -> SkinData:
	if id == &"":
		return null
	if _cache.has(id):
		return _cache[id]
	var path: String = "%s%s.tres" % [DIRECTORY, id]
	var skin: SkinData = null
	if ResourceLoader.exists(path):
		skin = load(path)
	_cache[id] = skin
	return skin
