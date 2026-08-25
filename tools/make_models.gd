## Génère les fiches ModelData des personnages importés.
##
## `godot --headless --path . -s tools/make_models.gd`
##
## Les modèles viennent des packs KayKit (CC0) : voir models/README.md. Chacun
## apporte 76 à 95 animations ; on n'en câble que sept, celles que la
## simulation sait produire. Le reste est là pour plus tard — bloc, parade,
## réveil de squelette, provocation.
extends SceneTree

## id, fichier, animation d'attaque, échelle.
##
## L'attaque est choisie par classe : un gardien abat une lame, un mage lance
## un sort, un archer décoche. C'est le seul geste qui doit correspondre à ce
## que la fiche d'attaque fait vraiment, sinon on voit une épée tirer une
## flèche.
const CAST: Array[Dictionary] = [
	{"id": "gardien", "attaque": "1H_Melee_Attack_Chop"},
	{"id": "mage", "attaque": "Spellcast_Shoot"},
	{"id": "soigneur", "attaque": "Spellcast_Raise"},
	{"id": "archer", "attaque": "1H_Ranged_Shoot"},
	{"id": "gobelin", "attaque": "1H_Melee_Attack_Slice_Diagonal"},
	{"id": "warden", "attaque": "2H_Melee_Attack_Chop"},
]

func _init() -> void:
	for entry: Dictionary in CAST:
		var id: String = entry["id"]
		var attaque: String = entry["attaque"]
		var path: String = "res://models/%s.glb" % id
		if not ResourceLoader.exists(path):
			printerr("modèle absent : %s" % path)
			continue
		var model: ModelData = ModelData.new()
		model.id = StringName(id)
		model.scene = load(path)
		model.scale = 1.0
		# Les personnages KayKit regardent vers +Z ; l'avant du projet est -Z.
		model.yaw_degrees = 180.0
		model.lift = 0.0
		model.idle = &"Idle"
		model.walk = &"Walking_A"
		model.run = &"Running_A"
		model.attack = StringName(attaque)
		model.dodge = &"Dodge_Forward"
		model.hurt = &"Hit_A"
		model.death = &"Death_A"
		model.run_speed = 3.4
		model.blend_time = 0.16
		var code: int = ResourceSaver.save(model, "res://models/%s.tres" % id)
		print("%s : %d" % [id, code])
	quit(0)
