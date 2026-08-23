## Chargement des modèles importés, par identifiant, avec cache.
##
## Un modèle manquant n'est pas une erreur : la vue retombe sur le skin en
## primitives. C'est ce qui permet de livrer le jeu sans aucun modèle, puis
## d'en ajouter un par personnage, à son rythme, sans jamais toucher au code.
class_name ModelLibrary
extends RefCounted

const DIRECTORY: String = "res://models/"

static var _cache: Dictionary[StringName, ModelData] = {}

static func for_id(id: StringName) -> ModelData:
	if id == &"":
		return null
	if _cache.has(id):
		return _cache[id]
	var path: String = "%s%s.tres" % [DIRECTORY, id]
	var model: ModelData = null
	if ResourceLoader.exists(path):
		model = load(path) as ModelData
	if model != null and model.scene == null:
		push_warning("Le modèle %s n'a pas de scène ; on garde les primitives." % id)
		model = null
	_cache[id] = model
	return model
