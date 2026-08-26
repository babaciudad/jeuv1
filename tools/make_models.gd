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
	{
		"id": "gardien", "attaque": "1H_Melee_Attack_Chop",
		"gestes": {
			"gardien_lourd": "2H_Melee_Attack_Chop",
			"gardien_rapide": "1H_Melee_Attack_Slice_Horizontal",
		},
	},
	{
		"id": "mage", "attaque": "Spellcast_Shoot",
		"gestes": {
			"mage_baton": "2H_Melee_Attack_Stab",
			"mage_trait": "Spellcast_Shoot",
		},
	},
	{
		"id": "soigneur", "attaque": "Spellcast_Raise",
		"gestes": {
			"soigneur_lame": "1H_Melee_Attack_Slice_Diagonal",
			"soigneur_soin": "Spellcast_Raise",
		},
	},
	{
		"id": "archer", "attaque": "1H_Ranged_Shoot",
		"gestes": {
			"archer_dague": "1H_Melee_Attack_Stab",
			"archer_fleche": "1H_Ranged_Shoot",
		},
	},
	{
		"id": "gobelin", "attaque": "1H_Melee_Attack_Slice_Diagonal",
		"gestes": {
			"gobelin_coup": "1H_Melee_Attack_Slice_Diagonal",
		},
	},
	{
		"id": "warden", "attaque": "2H_Melee_Attack_Chop",
		"gestes": {
			"boss_swing": "2H_Melee_Attack_Slice",
			"boss_slam": "2H_Melee_Attack_Chop",
		},
	},
]

## Vitesses, en mètres par seconde, auxquelles la marche et la course ont
## l'air justes UNE FOIS LES JAMBES RALLONGÉES. Les clips ont été animés pour
## un personnage deux fois plus court sur pattes : la même cadence couvre
## maintenant beaucoup plus de sol, et c'est ce nombre-là qui l'annonce au
## mélangeur.
const MARCHE: float = 2.0
const COURSE: float = 5.0

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
		model.hurt_alt = &"Hit_B"
		model.death = &"Death_A"
		model.death_alt = &"Death_B"
		model.walk_back = &"Walking_Backwards"
		model.strafe_left = &"Running_Strafe_Left"
		model.strafe_right = &"Running_Strafe_Right"
		model.walk_clip_speed = MARCHE
		model.run_clip_speed = COURSE
		var table: Dictionary = entry["gestes"]
		var gestes: Dictionary[StringName, StringName] = {}
		for cle: String in table:
			var valeur: String = table[cle]
			gestes[StringName(cle)] = StringName(valeur)
		model.attack_clips = gestes
		model.run_speed = 3.4
		model.blend_time = 0.16
		var code: int = ResourceSaver.save(model, "res://models/%s.tres" % id)
		print("%s : %d" % [id, code])
	quit(0)
