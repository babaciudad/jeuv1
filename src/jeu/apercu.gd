## Une vue fixe du marais, pour la capture et rien d'autre.
##
## Ce n'est pas le jeu : c'est l'œil qu'on braque sur le lieu pour juger de la
## lumière et de l'eau sans avoir à y jouer. La caméra regarde vers l'ouest,
## c'est-à-dire vers le soleil couchant et vers l'étier — dans l'axe du miroir.
class_name Apercu
extends Node3D

@export var oeil: Vector3 = Vector3(59.0, 6.2, 31.0)
@export var vise: Vector3 = Vector3(9.0, 0.2, 20.0)
@export var champ: float = 58.0
@export var vent: float = 0.0
@export var marnage: float = 1.0
@export var brume: float = 1.0
## Allègement du semis pour les captures : ce conteneur rend en logiciel.
@export var densite: float = 1.0
@export var avec_decor: bool = true
## Coupe brume, halo et corrections : on ne regarde que la lumière.
@export var depouille: bool = false
## Cache les nappes d'eau : sert à savoir si un défaut vient du sol ou d'elles.
@export var sans_eau: bool = false
@export var ambiante: float = 1.0
@export var blanc: float = 1.4
@export var exposition: float = 1.0
@export var ombres: bool = true
## Affiche les normales : l'eau en magenta, le sol en couleurs d'axes.
@export var debug_normales: bool = false
## Albédo uniforme : l'eau en cyan, le sol en gris. Isole la lumière.
@export var debug_albedo: bool = false

var marais: Marais = null

func _ready() -> void:
	marais = Etier.batir()
	marais.maree(lerpf(Etier.MAREE_BASSE, Etier.MAREE_HAUTE,
		clampf(marnage, 0.0, 1.0)))

	var ciel: Ciel = Ciel.new()
	# Les réglages AVANT l'entrée dans l'arbre : c'est `_ready` qui construit
	# l'environnement, et il lit ces valeurs. Les poser après ne fait rien —
	# deux captures rigoureusement identiques à des ambiantes différentes ont
	# suffi à le montrer.
	ciel.brume = brume
	ciel.ambiante = ambiante
	ciel.ombres = ombres
	ciel.blanc = blanc
	ciel.exposition = exposition
	add_child(ciel)
	ciel.regler(vent)
	if depouille:
		ciel.nu()

	var vue: VueMarais = VueMarais.new()
	vue.name = "Marais"
	add_child(vue)
	vue.construire(marais, Bruit.commun())
	# Le lointain est un miroir au niveau de la MER : de loin, le marais
	# continue à perte de vue.
	vue.prolonger(420.0, Etier.MAREE_HAUTE - 0.01, Bruit.commun())
	vue.rafraichir(vent)

	if avec_decor:
		var semis: Semis = Semis.new()
		semis.name = "Semis"
		add_child(semis)
		semis.semer(marais, 90.0, densite, Etier.MAREE_HAUTE - 0.01)
		semis.souffler(maxf(vent, 0.22))

		var attirail: Attirail = Attirail.new()
		attirail.name = "Attirail"
		add_child(attirail)
		attirail.garnir(marais)

		var oiseaux: Oiseaux = Oiseaux.new()
		oiseaux.name = "Oiseaux"
		add_child(oiseaux)
		oiseaux.peupler(marais)
	if debug_normales or debug_albedo:
		for enfant: Node in vue.get_children():
			var maille: MeshInstance3D = enfant as MeshInstance3D
			if maille == null:
				continue
			var mat: ShaderMaterial = maille.material_override as ShaderMaterial
			if mat != null:
				mat.set_shader_parameter(&"debug_normales", debug_normales)
				mat.set_shader_parameter(&"debug_albedo", debug_albedo)
	if sans_eau:
		for enfant: Node in vue.get_children():
			if enfant.name.begins_with("Eau_"):
				var nappe: MeshInstance3D = enfant as MeshInstance3D
				if nappe != null:
					nappe.visible = false

	var camera: Camera3D = Camera3D.new()
	camera.name = "Oeil"
	camera.fov = champ
	camera.far = 400.0
	camera.position = oeil
	add_child(camera)
	camera.look_at(vise, Vector3.UP)
	camera.make_current()
