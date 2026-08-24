## La passe d'encre : un quad plein écran qui redessine l'image.
##
## Invariant 2 : présentation pure, et même le bout le plus pur — elle ne lit
## rien de la simulation, elle ne lit que l'image déjà rendue.
##
## C'est ici que se joue la direction artistique. Le raisonnement tient en une
## phrase : une géométrie simple éclairée en PBR lisse se lit comme de la 3D
## ratée, la MÊME géométrie passée à l'encre se lit comme un parti pris. On ne
## cherche pas à cacher que ce sont des volumes simples — on les assume, en les
## dessinant.
##
## Le quad n'est PAS dans le monde : son shader écrit `POSITION` directement,
## il occupe l'écran quoi qu'il arrive. D'où l'AABB personnalisée énorme —
## sans elle le moteur le supprimerait dès que la caméra regarde ailleurs, et
## l'effet clignoterait sans qu'on comprenne pourquoi.
class_name InkPass
extends MeshInstance3D

## Le matériau est une RESSOURCE, pas un objet fabriqué au démarrage. C'est
## délibéré : sélectionner le nœud « Ink » dans l'éditeur donne accès à tous
## les réglages de la direction artistique — épaisseur du trait, nombre de
## valeurs, encre, sépia, papier, hachure, grain — et ils s'appliquent en
## direct pendant que le jeu tourne. Une DA qui ne se règle qu'en recompilant
## n'est pas dirigeable.
const MATERIAL: String = "res://shaders/ink.tres"
const SHADER: String = "res://shaders/ink.gdshader"

func _ready() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mesh = quad
	# Dessiné après tout le reste : c'est une passe de post-traitement, elle
	# doit avoir l'image complète sous les yeux.
	sorting_offset = 1000.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	extra_cull_margin = 16384.0

	if ResourceLoader.exists(MATERIAL):
		material_override = load(MATERIAL) as ShaderMaterial
		if material_override != null:
			return
	# Repli : le matériau réglé a disparu, on repart du shader nu plutôt que
	# de rendre la scène sans aucune passe — mieux vaut une DA aux valeurs par
	# défaut qu'une image brute qui ne ressemble à rien du jeu.
	var shader: Shader = load(SHADER) as Shader
	if shader == null:
		push_warning("Passe d'encre absente : le rendu restera brut.")
		return
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material_override = material
