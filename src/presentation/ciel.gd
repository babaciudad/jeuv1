## Le ciel, la lumière et l'air du marais.
##
## « La beauté est dans l'eau et la lumière, pas dans l'architecture. Un marais
## salant au couchant est un miroir horizontal de plusieurs kilomètres carrés.
## C'est ça, l'image du jeu. »
##
## Tout est donc réglé pour une seule chose : un soleil bas, rasant, qui frappe
## une nappe d'eau immobile. Le soleil est presque à l'horizon, la brume porte
## sa couleur, et les réflexions d'écran sont allumées parce que c'est elles
## qui font le miroir.
class_name Ciel
extends Node3D

## Élévation du soleil, en degrés.
##
## Six degrés donnaient la plus belle lumière et une image inutilisable : à ce
## rasant-là, une surface quasi plate se couvre d'acné d'ombre, parce que la
## carte d'ombres n'a plus assez de résolution en profondeur pour distinguer un
## talus de lui-même. Douze degrés gardent le cuivre et l'ombre longue, et la
## carte redevient lisible. C'est un compromis, et il est mesuré, pas supposé.
const ELEVATION_COUCHANT: float = 12.0
## Azimut, en degrés. Le soleil se couche à l'ouest, et l'étier vient de l'ouest.
const AZIMUT_COUCHANT: float = -104.0

## Facteur global de brume. Un pour le rendu du jeu, zéro pour regarder la
## géométrie sans voile quand on met la lumière au point.
var brume: float = 1.0
## Énergie de la lumière ambiante venue du ciel.
var ambiante: float = 1.0
## Ombres portées. Se coupe pour distinguer une ombre d'un défaut de matière.
var ombres: bool = true
## Point blanc du tonemap ACES, et exposition.
var blanc: float = 1.4
var exposition: float = 1.0

var _soleil: DirectionalLight3D = null
var _environnement: WorldEnvironment = null
var _ciel: ProceduralSkyMaterial = null
var _atmosphere: Environment = null

func _ready() -> void:
	_batir_soleil()
	_batir_environnement()
	regler(0.0)

## Fait tourner le ciel au vent d'est. À zéro, le couchant est calme et doré ;
## à un, l'air s'assèche, la lumière durcit et la brume se lève de l'eau —
## c'est le signe que la fleur va prendre.
func regler(vent: float) -> void:
	var t: float = clampf(vent, 0.0, 1.0)
	if _soleil != null:
		_soleil.light_color = Color(1.0, 0.706, 0.470).lerp(
			Color(1.0, 0.836, 0.690), t)
		_soleil.light_energy = lerpf(3.20, 3.90, t)
	if _ciel != null:
		_ciel.sky_horizon_color = Color(0.855, 0.573, 0.340).lerp(
			Color(0.905, 0.716, 0.520), t)
		_ciel.ground_horizon_color = Color(0.470, 0.360, 0.255).lerp(
			Color(0.556, 0.470, 0.360), t)
	if _atmosphere != null:
		# Le vent d'est chasse la brume basse et la remplace par une lumière
		# plus sèche : moins de voile, plus de contraste.
		_atmosphere.volumetric_fog_density = lerpf(0.0011, 0.0004, t) * brume
		_atmosphere.fog_density = lerpf(0.0038, 0.0015, t) * brume

func _batir_soleil() -> void:
	_soleil = DirectionalLight3D.new()
	_soleil.name = "Couchant"
	_soleil.rotation_degrees = Vector3(-ELEVATION_COUCHANT, AZIMUT_COUCHANT, 0.0)
	_soleil.shadow_enabled = ombres
	# Un soleil rasant étire les ombres à l'infini : sans un biais généreux et
	# une plage lointaine, les talus se rayent d'acné d'ombre sur toute la carte.
	_soleil.directional_shadow_mode = \
		DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_soleil.directional_shadow_max_distance = 110.0
	_soleil.directional_shadow_split_1 = 0.06
	_soleil.directional_shadow_split_2 = 0.17
	_soleil.directional_shadow_split_3 = 0.44
	_soleil.directional_shadow_blend_splits = true
	_soleil.shadow_bias = 0.028
	_soleil.shadow_normal_bias = 3.4
	_soleil.light_angular_distance = 0.7
	add_child(_soleil)

func _batir_environnement() -> void:
	_ciel = ProceduralSkyMaterial.new()
	_ciel.sky_top_color = Color(0.185, 0.268, 0.395)
	_ciel.sky_horizon_color = Color(0.855, 0.573, 0.340)
	_ciel.sky_curve = 0.13
	_ciel.ground_bottom_color = Color(0.215, 0.190, 0.160)
	_ciel.ground_horizon_color = Color(0.470, 0.360, 0.255)
	_ciel.ground_curve = 0.06
	_ciel.sun_angle_max = 4.0
	_ciel.sun_curve = 0.06
	_ciel.energy_multiplier = 1.0

	var ciel: Sky = Sky.new()
	ciel.sky_material = _ciel
	ciel.radiance_size = Sky.RADIANCE_SIZE_256

	_atmosphere = Environment.new()
	_atmosphere.background_mode = Environment.BG_SKY
	_atmosphere.sky = ciel
	_atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# Mesuré, et contre-intuitif : à contribution 1.0, `ambient_light_energy`
	# n'a AUCUN effet — l'ambiante vient entièrement de la carte de radiance du
	# ciel. Deux captures à 1.6 et 3.0 d'énergie sortaient bit pour bit
	# identiques. Il faut donc laisser une part à une ambiante de couleur pour
	# avoir la moindre prise sur le remplissage des ombres.
	_atmosphere.ambient_light_sky_contribution = 0.55
	# Bleu-violet, et pas doré : à l'heure où le soleil est orange, ce qui
	# éclaire les ombres est le reste du ciel, qui est froid. C'est ce contraste
	# chaud/froid qui fait lire un couchant.
	_atmosphere.ambient_light_color = Color(0.335, 0.395, 0.530)
	# Réglage mesuré, pas choisi. À 1.0, l'ambiante délave tout le sol et il ne
	# reste plus une ombre. À 0.16, les talus dos au soleil tombaient au noir
	# absolu, avec des bords déchiquetés qu'on prenait pour de l'acné d'ombre
	# alors que c'était simplement l'absence de remplissage. Un couchant réel a
	# un hémisphère de ciel entier pour remplir ses ombres : 0.62 rend ça.
	_atmosphere.ambient_light_energy = ambiante
	# Le miroir. Sans réflexions d'écran, une nappe d'eau lisse n'est qu'une
	# surface grise : c'est cette ligne-là qui fait l'image du jeu.
	_atmosphere.ssr_enabled = true
	_atmosphere.ssr_max_steps = 96
	_atmosphere.ssr_fade_in = 0.2
	_atmosphere.ssr_fade_out = 6.0
	_atmosphere.ssr_depth_tolerance = 0.35
	# SDFGI a été essayé pour rattraper les ombres de talus et débranché : sur
	# une géométrie aussi plate et aussi fine, il n'apportait rien de visible
	# et coûtait un tiers du temps de rendu. Ce qui sauve ces ombres est plus
	# simple — un ciel de couchant est une source hémisphérique énorme, et
	# c'est l'ambiante qui doit la porter.
	_atmosphere.ssao_enabled = true
	_atmosphere.ssao_radius = 1.4
	_atmosphere.ssao_intensity = 1.5
	# Une brume basse, tenue près de l'eau : c'est elle qui donne au marais sa
	# profondeur, un lieu parfaitement plat n'en ayant aucune par lui-même.
	_atmosphere.fog_enabled = true
	_atmosphere.fog_light_color = Color(0.780, 0.640, 0.505)
	_atmosphere.fog_light_energy = 0.55
	_atmosphere.fog_sun_scatter = 0.22
	_atmosphere.fog_density = 0.0038
	_atmosphere.fog_aerial_perspective = 0.10
	# La brume de hauteur est un piège dans un lieu plat : elle s'ajoute SOUS
	# `fog_height`, et ici toute la scène — caméra comprise — est sous 1,6 m.
	# À 0,9 de densité, elle nappait l'image entière d'un voile crème contre
	# lequel aucun réglage d'exposition ne pouvait rien.
	_atmosphere.fog_height = 0.85
	_atmosphere.fog_height_density = 0.06
	_atmosphere.volumetric_fog_enabled = true
	_atmosphere.volumetric_fog_density = 0.0016
	_atmosphere.volumetric_fog_albedo = Color(0.900, 0.830, 0.760)
	# Émission nulle. Une brume qui rayonne d'elle-même ajoute de la lumière
	# partout, y compris là où il n'y en a pas : c'est le plus sûr moyen de
	# délaver une image sans qu'aucun réglage d'exposition n'y puisse rien.
	_atmosphere.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	_atmosphere.volumetric_fog_length = 96.0
	_atmosphere.volumetric_fog_gi_inject = 0.6
	_atmosphere.glow_enabled = true
	_atmosphere.glow_intensity = 0.22
	# Zéro, et c'est important : `glow_bloom` fait baver TOUS les pixels quel
	# que soit leur niveau, seuil compris. À 0,10 sur un ciel de couchant, il
	# suffisait à lever toute l'image de cinquante niveaux de gris.
	_atmosphere.glow_bloom = 0.0
	_atmosphere.glow_hdr_threshold = 1.45
	# Linéaire, et c'est un choix mesuré. ACES relevait les tons moyens de façon
	# massive — la même scène passait de 122 à 193 de luminance moyenne au sol —
	# et écrasait du même coup le contraste entre l'argile et l'eau. Un couchant
	# n'a pas besoin d'être filmique : il a besoin d'être contrasté.
	_atmosphere.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_atmosphere.tonemap_white = blanc
	_atmosphere.tonemap_exposure = exposition
	_atmosphere.adjustment_enabled = true
	_atmosphere.adjustment_saturation = 1.06
	_atmosphere.adjustment_contrast = 1.04

	_environnement = WorldEnvironment.new()
	_environnement.name = "Atmosphere"
	_environnement.environment = _atmosphere
	add_child(_environnement)

## Coupe toutes les couches atmosphériques pour ne garder que la lumière et
## les matières. Sert à savoir laquelle de ces couches délave une image :
## quand tout est allumé, on ne peut qu'émettre des hypothèses.
func nu() -> void:
	if _atmosphere == null:
		return
	_atmosphere.fog_enabled = false
	_atmosphere.volumetric_fog_enabled = false
	_atmosphere.glow_enabled = false
	_atmosphere.ssao_enabled = false
	_atmosphere.adjustment_enabled = false
	# Tonemap linéaire : on veut lire les valeurs, pas les regarder.
	_atmosphere.tonemap_mode = Environment.TONE_MAPPER_LINEAR
