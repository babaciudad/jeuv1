## Le décor est-il tenable ?
##
## Un semis procédural n'a pas de limite naturelle : une densité mal choisie
## produit deux cent mille brins sans qu'aucune erreur ne se lève, et on ne s'en
## aperçoit qu'à la première image — trop tard. On compte donc, et on tient un
## plafond.
extends GdUnitTestSuite

## Plafond d'instances de végétation. Au-delà, c'est une décision, pas un
## accident : il faut venir changer ce chiffre en sachant pourquoi.
const PLAFOND: int = 26000

func test_le_semis_reste_sous_son_plafond() -> void:
	var marais: Marais = Etier.batir()
	marais.maree(Etier.MAREE_HAUTE)
	var semis: Semis = Semis.new()
	add_child(semis)
	var _garde: Variant = auto_free(semis)
	semis.semer(marais, 90.0)
	var total: int = 0
	for nom: String in semis.instances:
		total += semis.instances[nom]
	prints("semis :", semis.instances.size(), "espèces,", total, "instances")
	assert_int(total).is_less_equal(PLAFOND)
	assert_int(total).is_greater(400)

func test_aucune_plante_n_est_geante() -> void:
	# `roseau_touffe.glb` mesure vingt-cinq mètres sur cent soixante-dix-neuf
	# dans son fichier, alors que son manifeste annonce 1,79 m. Semé tel quel,
	# il avalait la caméra. Le semis normalise désormais chaque modèle sur une
	# hauteur visée ; ce test tient cette promesse pour tous les suivants.
	var marais: Marais = Etier.batir()
	marais.maree(Etier.MAREE_HAUTE)
	var semis: Semis = Semis.new()
	add_child(semis)
	var _garde: Variant = auto_free(semis)
	semis.semer(marais, 90.0)
	var plus_haute: float = 0.0
	var coupable: String = ""
	for nom: String in semis.hauteurs:
		if semis.hauteurs[nom] > plus_haute:
			plus_haute = semis.hauteurs[nom]
			coupable = nom
	for nom: String in semis.hauteurs:
		prints("   %-28s %6.2f m  x%d" % [nom, semis.hauteurs[nom],
			semis.instances[nom]])
	prints("plante la plus haute :", plus_haute, "m —", coupable)
	assert_float(plus_haute).is_less(5.0)

func test_rien_ne_pousse_au_milieu_d_un_bassin() -> void:
	# Les roseaux tiennent la rive. S'il en pousse au centre d'un œillet, c'est
	# que la carte de distance est fausse — et un œillet planté de roseaux
	# n'est plus un œillet.
	var marais: Marais = Etier.batir()
	marais.maree(Etier.MAREE_HAUTE)
	var semis: Semis = Semis.new()
	add_child(semis)
	var _garde: Variant = auto_free(semis)
	semis.semer(marais, 0.0)
	var fautifs: int = 0
	var examines: int = 0
	for enfant: Node in semis.get_children():
		var instance: MultiMeshInstance3D = enfant as MultiMeshInstance3D
		if instance == null or instance.multimesh == null:
			continue
		for i: int in range(instance.multimesh.instance_count):
			var p: Vector3 = instance.multimesh.get_instance_transform(i).origin
			var plan: Vector2 = Vector2(p.x, p.z)
			examines += 1
			# Plus de quatre-vingts centimètres d'eau sous les pieds : on n'est
			# plus sur une rive, on est au milieu.
			if marais.profondeur_eau(plan) > 0.11:
				fautifs += 1
	prints("plantes examinées :", examines, " hors rive :", fautifs)
	assert_int(fautifs).is_equal(0)

func test_aucun_prop_ni_oiseau_n_est_hors_d_echelle() -> void:
	# Aucun des vingt-six oiseaux versés n'est à une échelle cohérente : mesurés
	# dans leur fichier, ils vont de 0,50 m à CENT QUATRE-VINGT-DIX-SEPT MÈTRES
	# d'envergure. On ne corrige donc pas fichier par fichier, on cale à
	# l'instanciation — et ce test tient la promesse pour tout ce qui viendra.
	var marais: Marais = Etier.batir()
	marais.maree(Etier.MAREE_HAUTE)

	var attirail: Attirail = Attirail.new()
	add_child(attirail)
	var _g1: Variant = auto_free(attirail)
	attirail.garnir(marais)
	var plus_gros: float = 0.0
	var coupable: String = ""
	for enfant: Node in attirail.get_children():
		var objet: Node3D = enfant as Node3D
		if objet == null:
			continue
		var taille: Vector3 = Echelle.boite(objet).size * objet.scale
		var m: float = maxf(maxf(taille.x, taille.y), taille.z)
		if m > plus_gros:
			plus_gros = m
			coupable = String(objet.name)
	var vus: Dictionary[String, float] = {}
	for enfant: Node in attirail.get_children():
		var objet: Node3D = enfant as Node3D
		if objet == null:
			continue
		var t: Vector3 = Echelle.boite(objet).size * objet.scale
		var m: float = maxf(maxf(t.x, t.y), t.z)
		if not vus.has(String(objet.name)) or vus[String(objet.name)] < m:
			vus[String(objet.name)] = m
	for nom: String in vus:
		if vus[nom] > 1.9:
			prints("   grand prop :", nom, vus[nom])
	prints("prop le plus grand :", plus_gros, "m —", coupable)
	assert_float(plus_gros).is_less(3.2)

	var oiseaux: Oiseaux = Oiseaux.new()
	add_child(oiseaux)
	var _g2: Variant = auto_free(oiseaux)
	oiseaux.peupler(marais)
	var plus_grand: float = 0.0
	var oiseau_coupable: String = ""
	var comptes: int = 0
	for enfant: Node in oiseaux.get_children():
		var objet: Node3D = enfant as Node3D
		if objet == null:
			continue
		comptes += 1
		var taille: Vector3 = Echelle.boite(objet).size * objet.scale
		var m: float = maxf(maxf(taille.x, taille.y), taille.z)
		if m > plus_grand:
			plus_grand = m
			oiseau_coupable = String(objet.name)
	prints("oiseaux :", comptes, " le plus grand :", plus_grand, "m —",
		oiseau_coupable)
	assert_int(comptes).is_greater(15)
	assert_float(plus_grand).is_less(2.2)

func test_un_modele_aberrant_est_ecarte_du_semis() -> void:
	# `roseau_touffe.glb` mesure 25 × 22,86 × 179 mètres. Ramené à 1,75 m de
	# haut il restait long de treize mètres et couchait des lames pâles en
	# travers de tout le marais. Le semis doit le refuser, pas le rapetisser.
	var marais: Marais = Etier.batir()
	marais.maree(Etier.MAREE_HAUTE)
	var semis: Semis = Semis.new()
	add_child(semis)
	var _g: Variant = auto_free(semis)
	semis.semer(marais, 90.0)
	assert_bool(semis.instances.has("roseau_touffe.glb")).is_false()
	# Et plus généralement : rien de semé ne doit être démesurément long.
	for nom: String in semis.instances:
		var trouve: Mesh = null
		for enfant: Node in semis.get_children():
			var mm: MultiMeshInstance3D = enfant as MultiMeshInstance3D
			if mm != null and String(mm.name) == "Semis_" + nom.get_basename():
				trouve = mm.multimesh.mesh
		if trouve == null:
			continue
		var t: Vector3 = trouve.get_aabb().size
		var rapport: float = maxf(t.x, t.z) / maxf(t.y, 0.001)
		assert_float(rapport).override_failure_message(
			"%s est %.0f fois plus large que haut" % [nom, rapport]) \
			.is_less_equal(Semis.ANISOTROPIE_MAX)
