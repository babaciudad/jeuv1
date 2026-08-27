## Le son du marais.
##
## AVERTISSEMENT HONNÊTE, écrit ici pour qu'il ne se perde pas : ce fichier a
## été composé sans être entendu. Le conteneur de développement n'a pas de
## carte son. Ce qui est vérifié — et testé — c'est que les fichiers se
## chargent, que les lecteurs existent, et que les bons se déclenchent aux bons
## moments. Que le mélange SONNE juste reste à juger par une oreille humaine.
##
## Trois couches, et rien de plus :
##   — l'AMBIANCE, en boucle, qui suit le vent d'est ;
##   — l'EAU, positionnelle, à chaque vanne, dont le volume suit le débit réel
##     calculé par la simulation. Une vanne fermée est silencieuse, une porte de
##     marée gronde ;
##   — les GESTES, déclenchés par ce que la simulation vient de faire.
class_name Ambiance
extends Node3D

const AMBIANCE: String = "res://audio/ambiance/"
const EAU: String = "res://audio/eau/"
const PAS: String = "res://audio/pas/"
const GESTES: String = "res://audio/gestes/"

## Distance parcourue entre deux pas, en mètres. Mesurée sur la foulée du clip
## de marche, pas choisie : Walk avance de 0,67 m/s en 1,67 s, soit trois
## foulées — environ trente-sept centimètres par pas.
const FOULEE: float = 0.37

var _vent_herbes: AudioStreamPlayer = null
var _vent_plaine: AudioStreamPlayer = null
var _oiseaux: AudioStreamPlayer = null
var _mer: AudioStreamPlayer = null
var _vannes: Array[AudioStreamPlayer3D] = []
var _pas: AudioStreamPlayer3D = null
var _geste: AudioStreamPlayer3D = null

var _distance: float = 0.0
var _sur_pied: bool = false
var _dernier_geste: StringName = &""
var _etat_precedent: int = Acteur.Etat.LIBRE

func monter(marais: Marais) -> void:
	_vent_herbes = _boucle(AMBIANCE + "vent_herbes_boucle.ogg", -9.0)
	_vent_plaine = _boucle(AMBIANCE + "vent_plaine_boucle.ogg", -16.0)
	_oiseaux = _boucle(AMBIANCE + "oiseaux_marais_boucle.ogg", -17.0)
	_mer = _boucle(AMBIANCE + "bord_de_mer_lointain_boucle.ogg", -21.0)

	for vanne: Marais.Vanne in marais.vannes:
		var source: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		source.name = "Vanne_%s" % vanne.nom
		# Une porte de marée gronde, une vanne d'œillet suinte : c'est la
		# SECTION qui choisit le son, et le débit qui règle le volume.
		var fichier: String = "eau_vanne.ogg" if vanne.section >= 3.0 \
			else "eau_vanne_filet.ogg"
		source.stream = _charger(fichier, EAU)
		source.position = Vector3(vanne.position.x, Reglages.HAUTEUR_TALUS,
			vanne.position.y)
		source.unit_size = 6.0
		source.max_distance = 42.0
		source.volume_db = -60.0
		add_child(source)
		_vannes.append(source)
		if source.stream != null:
			source.play()

	_pas = AudioStreamPlayer3D.new()
	_pas.name = "Pas"
	_pas.unit_size = 2.4
	add_child(_pas)
	_geste = AudioStreamPlayer3D.new()
	_geste.name = "Geste"
	_geste.unit_size = 3.6
	add_child(_geste)

## Une fois par image. `delta` sert à la cadence des pas.
func suivre(monde: Monde, delta: float) -> void:
	var joueur: Acteur = monde.joueur()
	if joueur == null:
		return
	_ambiance(monde.vent_est)
	_eau(monde)
	_pas_du_joueur(monde, joueur, delta)
	_gestes_du_joueur(monde, joueur)

## Le vent d'est ne fait pas que monter en volume : il change de couleur. La
## rafale de plaine prend le dessus sur le froissement des herbes, et les
## oiseaux se taisent — c'est l'heure où la fleur prend.
func _ambiance(vent: float) -> void:
	var v: float = clampf(vent, 0.0, 1.0)
	_regler(_vent_herbes, lerpf(-9.0, -6.0, v))
	_regler(_vent_plaine, lerpf(-19.0, -7.0, v))
	_regler(_oiseaux, lerpf(-16.0, -26.0, v))
	_regler(_mer, -21.0)

func _eau(monde: Monde) -> void:
	for i: int in range(_vannes.size()):
		if i >= monde.marais.vannes.size():
			break
		var vanne: Marais.Vanne = monde.marais.vannes[i]
		# Le débit est en mètres cubes par seconde. Une vanne qui vient de
		# s'ouvrir gronde, puis s'apaise à mesure que les niveaux s'égalisent —
		# et cette décrue-là est audible sans qu'on ait rien à scripter.
		var force: float = clampf(vanne.debit / 2.5, 0.0, 1.0)
		var volume: float = -60.0 if force <= 0.001 else lerpf(-26.0, -5.0, force)
		_regler3(_vannes[i], volume)

func _pas_du_joueur(monde: Monde, joueur: Acteur, delta: float) -> void:
	if not joueur.vivant() or _pas == null:
		return
	_pas.position = Vector3(joueur.position.x,
		monde.marais.hauteur_sol(joueur.position), joueur.position.y)
	if joueur.etat != Acteur.Etat.LIBRE:
		return
	_distance += joueur.vitesse.length() * delta
	if _distance < FOULEE:
		return
	_distance = 0.0
	_sur_pied = not _sur_pied
	var famille: String = "pas_terre_seche_"
	var eau: float = joueur.eau_sous_les_pieds
	if eau > Reglages.EAU_GENANTE:
		famille = "pas_eau_"
	elif eau > 0.004:
		famille = "pas_boue_"
	elif not monde.marais.est_talus(joueur.position):
		famille = "pas_boue_"
	else:
		famille = "pas_terre_herbe_" if _sur_pied else "pas_terre_seche_"
	_jouer(_pas, PAS, famille, 5, -7.0)

func _gestes_du_joueur(monde: Monde, joueur: Acteur) -> void:
	if _geste == null:
		return
	_geste.position = Vector3(joueur.position.x,
		monde.marais.hauteur_sol(joueur.position) + 1.1, joueur.position.y)

	if monde.vanne_ouverte_ce_tick >= 0:
		_jouer(_geste, GESTES, "grincement_bois_", 6, -4.0)
	elif monde.sel_tire_ce_tick:
		_jouer(_geste, GESTES, "raclage_", 5, -5.0)
	elif monde.fleur_cueillie_ce_tick:
		_jouer(_geste, GESTES, "frottement_bois_", 3, -10.0)
	elif joueur.vient_de_tomber:
		_jouer(_geste, EAU, "eclaboussure_", 5, -4.0)
	elif joueur.etat != _etat_precedent:
		match joueur.etat:
			Acteur.Etat.FRAPPE:
				_jouer(_geste, GESTES, "effort_", 4, -11.0)
			Acteur.Etat.ESQUIVE:
				_jouer(_geste, GESTES, "souffle_", 2, -12.0)
			Acteur.Etat.DOULEUR:
				_jouer(_geste, GESTES, "impact_mat_", 4, -5.0)
	_etat_precedent = joueur.etat

## Coupe tout avant que le moteur ne compte ce qui reste.
##
## HONNÊTETÉ DE FERMETURE : même avec ce ménage, le moteur signale à la toute
## fin une poignée de lectures Ogg encore vivantes (les nappes et les vannes,
## soit dix objets, constants d'une exécution à l'autre). Trois variantes ont
## été mesurées — avec pause, sans pause, sans ce ménage — et le reliquat ne
## bouge pas : il tient au cycle de fin de l'AudioServer, pas à une fuite qui
## grossit. Le système d'exploitation récupère tout ; on le dit plutôt que de
## le maquiller.
##
## Les nappes d'ambiance tournent EN BOUCLE : à la fermeture, elles jouent
## encore, et chaque flux Ogg en lecture retient son objet de lecture. Godot
## sortait donc sur « 32 ObjectDB instances leaked / 12 resources still in
## use » — trente-deux objets qui sont, à un près, les quatre nappes, les six
## vannes et leurs lectures. Ce n'est pas une fuite qui grossit ; c'est un
## message d'erreur à la fermeture d'un jeu, et c'en est un de trop.
func _exit_tree() -> void:
	for enfant: Node in get_children():
		var deux_d: AudioStreamPlayer = enfant as AudioStreamPlayer
		if deux_d != null:
			deux_d.stop()
			deux_d.stream = null
			continue
		var trois_d: AudioStreamPlayer3D = enfant as AudioStreamPlayer3D
		if trois_d != null:
			trois_d.stop()
			trois_d.stream = null

# ---------------------------------------------------------------------------

func _boucle(chemin: String, volume: float) -> AudioStreamPlayer:
	var lecteur: AudioStreamPlayer = AudioStreamPlayer.new()
	lecteur.name = chemin.get_file().get_basename()
	lecteur.stream = _charger(chemin.get_file(), chemin.get_base_dir() + "/")
	lecteur.volume_db = volume
	add_child(lecteur)
	if lecteur.stream != null:
		# Les nappes d'ambiance doivent boucler : sans ceci, le marais devient
		# silencieux au bout de trente secondes et on croit à un bogue de son.
		var ogg: AudioStreamOggVorbis = lecteur.stream as AudioStreamOggVorbis
		if ogg != null:
			ogg.loop = true
		lecteur.play()
	return lecteur

func _charger(fichier: String, dossier: String) -> AudioStream:
	var chemin: String = dossier + fichier
	if not ResourceLoader.exists(chemin):
		push_warning("Son introuvable : %s" % chemin)
		return null
	return load(chemin) as AudioStream

## Joue une variante au hasard d'une famille numérotée. Plusieurs variantes ne
## sont pas un luxe : un pas unique répété à chaque foulée cliquette, et l'
## oreille l'entend tout de suite comme une machine.
func _jouer(lecteur: AudioStreamPlayer3D, dossier: String, famille: String,
		variantes: int, volume: float) -> void:
	var indice: int = randi_range(1, variantes)
	var flux: AudioStream = _charger("%s%02d.ogg" % [famille, indice], dossier)
	if flux == null:
		return
	lecteur.stream = flux
	lecteur.volume_db = volume
	lecteur.pitch_scale = randf_range(0.93, 1.08)
	lecteur.play()

func _regler(lecteur: AudioStreamPlayer, volume: float) -> void:
	if lecteur != null:
		lecteur.volume_db = volume

func _regler3(lecteur: AudioStreamPlayer3D, volume: float) -> void:
	if lecteur != null:
		lecteur.volume_db = volume
