## Le bandeau : endurance, vie, ce qu'on a récolté, et la consigne du moment.
##
## Il montre le moins possible. Le lore est explicite : le joueur doit
## apprendre « œillet », « ladure », « las » comme il apprend « Estus », et
## l'opacité est un atout. On ne définit donc aucun mot ; on les emploie.
class_name Hud
extends CanvasLayer

const MARGE: float = 26.0
const LARGEUR_JAUGE: float = 320.0
const HAUTEUR_JAUGE: float = 9.0

var _vie: ColorRect = null
var _vie_fond: ColorRect = null
var _endurance: ColorRect = null
var _endurance_fond: ColorRect = null
var _consigne: Label = null
var _indication: Label = null
var _recolte: Label = null

func _ready() -> void:
	layer = 10
	var racine: Control = Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(racine)

	_vie_fond = _jauge(racine, Vector2(MARGE, MARGE), Color(0.07, 0.06, 0.05, 0.62))
	_vie = _jauge(racine, Vector2(MARGE, MARGE), Color(0.72, 0.27, 0.22, 0.92))
	_endurance_fond = _jauge(racine, Vector2(MARGE, MARGE + 16.0),
		Color(0.07, 0.06, 0.05, 0.62))
	_endurance = _jauge(racine, Vector2(MARGE, MARGE + 16.0),
		Color(0.68, 0.62, 0.42, 0.92))

	# Le gris et le blanc : les deux sels, et jamais le même compteur.
	_recolte = _texte(racine, 15, Color(0.88, 0.86, 0.80, 0.85))
	_recolte.position = Vector2(MARGE, MARGE + 34.0)

	_consigne = _texte(racine, 19, Color(0.95, 0.93, 0.88, 0.95))
	_consigne.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_consigne.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_consigne.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_consigne.position = Vector2(0.0, -84.0)
	_consigne.custom_minimum_size = Vector2(900.0, 0.0)

	_indication = _texte(racine, 15, Color(0.80, 0.76, 0.66, 0.78))
	_indication.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_indication.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indication.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_indication.position = Vector2(0.0, -56.0)
	_indication.custom_minimum_size = Vector2(900.0, 0.0)

	# La seule ligne hors-fiction du jeu, et elle est nécessaire : la souris est
	# capturée au démarrage, et sans ce mot personne ne devine comment la
	# rendre. Elle se tient dans un coin et n'occupe pas la place de la consigne.
	var souris: Label = _texte(racine, 13, Color(0.72, 0.68, 0.60, 0.55))
	souris.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	souris.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	souris.grow_vertical = Control.GROW_DIRECTION_BEGIN
	souris.position = Vector2(-MARGE - 210.0, -MARGE - 18.0)
	souris.text = "Échap : libérer la souris"

func rafraichir(monde: Monde, tutoriel: Tutoriel) -> void:
	var joueur: Acteur = monde.joueur()
	if joueur == null:
		return
	_vie.size.x = LARGEUR_JAUGE * clampf(joueur.vie / joueur.vie_max, 0.0, 1.0)
	_endurance.size.x = LARGEUR_JAUGE * clampf(
		joueur.endurance / Reglages.ENDURANCE_MAX, 0.0, 1.0)
	_recolte.text = "gros sel %d      fleur %d" % [monde.gros_sel, monde.fleur]
	_consigne.text = tutoriel.consigne()
	var indication: String = tutoriel.indication()
	var avancement: float = tutoriel.avancement()
	if avancement >= 0.0 and indication != "":
		indication = "%s      %d %%" % [indication, int(roundf(avancement * 100.0))]
	_indication.text = indication

func _jauge(parent: Control, ou: Vector2, teinte: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = teinte
	rect.position = ou
	rect.size = Vector2(LARGEUR_JAUGE, HAUTEUR_JAUGE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func _texte(parent: Control, taille: int, teinte: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override(&"font_size", taille)
	label.add_theme_color_override(&"font_color", teinte)
	label.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override(&"shadow_offset_y", 2)
	label.add_theme_constant_override(&"shadow_offset_x", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
