## Le son se déclenche-t-il ?
##
## Je ne peux pas ENTENDRE ce jeu : ce conteneur n'a pas de carte son, et Godot
## y bascule sur un pilote muet. Ce que je peux vérifier, et que je vérifie ici,
## c'est que les fichiers existent et se chargent, que les lecteurs sont montés,
## et que les bons se déclenchent aux bons moments. Le MÉLANGE — les volumes
## relatifs, la couleur du vent — reste à juger par une oreille humaine, et
## c'est dit dans src/presentation/ambiance.gd.
extends GdUnitTestSuite

func _monde() -> Monde:
	var monde: Monde = Monde.new()
	monde.marais = Etier.batir()
	monde.marais.maree(Etier.MAREE_HAUTE)
	monde.ladure = Etier.LADURE
	var las: Geste = load("res://data/combat/las_lourd.tres") as Geste
	monde.gestes[las.nom] = las
	var joueur: Acteur = Acteur.new()
	joueur.camp = Acteur.Camp.PALUDIER
	joueur.position = Etier.DEPART
	var _p: Acteur = monde.ajouter(joueur)
	return monde

func test_tous_les_sons_du_jeu_existent_et_se_chargent() -> void:
	var attendus: PackedStringArray = PackedStringArray([
		"res://audio/ambiance/vent_herbes_boucle.ogg",
		"res://audio/ambiance/vent_plaine_boucle.ogg",
		"res://audio/ambiance/oiseaux_marais_boucle.ogg",
		"res://audio/ambiance/bord_de_mer_lointain_boucle.ogg",
		"res://audio/eau/eau_vanne.ogg",
		"res://audio/eau/eau_vanne_filet.ogg",
	])
	# Chaque famille de sons doit avoir toutes ses variantes : un pas unique
	# répété à chaque foulée cliquette, et l'oreille l'entend comme une machine.
	var familles: Dictionary[String, int] = {
		"res://audio/pas/pas_terre_seche_": 5,
		"res://audio/pas/pas_terre_herbe_": 5,
		"res://audio/pas/pas_boue_": 5,
		"res://audio/pas/pas_eau_": 5,
		"res://audio/eau/eclaboussure_": 5,
		"res://audio/gestes/raclage_": 5,
		"res://audio/gestes/grincement_bois_": 6,
		"res://audio/gestes/effort_": 4,
		"res://audio/gestes/souffle_": 2,
		"res://audio/gestes/impact_mat_": 4,
		"res://audio/gestes/frottement_bois_": 3,
	}
	for prefixe: String in familles:
		var combien: int = familles[prefixe]
		for i: int in range(1, combien + 1):
			attendus.append("%s%02d.ogg" % [prefixe, i])
	var manquants: PackedStringArray = PackedStringArray()
	for chemin: String in attendus:
		if not ResourceLoader.exists(chemin):
			manquants.append(chemin)
		elif load(chemin) as AudioStream == null:
			manquants.append(chemin + " (illisible)")
	prints("sons attendus :", attendus.size(), " manquants :", manquants.size())
	assert_array(Array(manquants)).is_empty()

func test_les_nappes_d_ambiance_tournent_en_boucle() -> void:
	var monde: Monde = _monde()
	var ambiance: Ambiance = Ambiance.new()
	add_child(ambiance)
	var _g: Variant = auto_free(ambiance)
	ambiance.monter(monde.marais)
	var boucles: int = 0
	for enfant: Node in ambiance.get_children():
		var lecteur: AudioStreamPlayer = enfant as AudioStreamPlayer
		if lecteur == null or lecteur.stream == null:
			continue
		boucles += 1
		var ogg: AudioStreamOggVorbis = lecteur.stream as AudioStreamOggVorbis
		assert_bool(ogg != null and ogg.loop).override_failure_message(
			"%s ne boucle pas : le marais deviendrait muet en trente secondes"
				% lecteur.name).is_true()
		assert_bool(lecteur.playing).is_true()
	prints("nappes d'ambiance en boucle :", boucles)
	assert_int(boucles).is_equal(4)

func test_une_vanne_fermee_est_muette_et_une_vanne_ouverte_gronde() -> void:
	var monde: Monde = _monde()
	var ambiance: Ambiance = Ambiance.new()
	add_child(ambiance)
	var _g: Variant = auto_free(ambiance)
	ambiance.monter(monde.marais)
	var simulation: Simulation = Simulation.new()

	simulation.avancer(monde, {})
	ambiance.suivre(monde, Reglages.DUREE_TICK)
	var porte: int = monde.marais.vanne_nommee(&"porte_de_maree")
	var source: AudioStreamPlayer3D = ambiance.get_node(
		NodePath("Vanne_porte_de_maree")) as AudioStreamPlayer3D
	assert_object(source).is_not_null()
	assert_float(source.volume_db).is_less(-50.0)

	monde.marais.vannes[porte].ouverte = true
	for _i: int in range(4):
		simulation.avancer(monde, {})
	ambiance.suivre(monde, Reglages.DUREE_TICK)
	prints("porte de marée ouverte : débit =",
		monde.marais.vannes[porte].debit, "volume =", source.volume_db)
	assert_float(source.volume_db).is_greater(-30.0)

func test_le_geste_du_las_declenche_un_raclage() -> void:
	var monde: Monde = _monde()
	var ambiance: Ambiance = Ambiance.new()
	add_child(ambiance)
	var _g: Variant = auto_free(ambiance)
	ambiance.monter(monde.marais)
	var geste: AudioStreamPlayer3D = ambiance.get_node(
		NodePath("Geste")) as AudioStreamPlayer3D
	assert_object(geste).is_not_null()
	monde.sel_tire_ce_tick = true
	ambiance.suivre(monde, Reglages.DUREE_TICK)
	assert_object(geste.stream).is_not_null()
	assert_str(geste.stream.resource_path).contains("raclage_")
