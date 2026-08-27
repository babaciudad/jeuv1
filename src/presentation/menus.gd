## L'écran-titre, la pause, la fin de saison.
##
## Le jeu se lançait directement dans le marais, sans nom, sans pause, sans
## moyen de quitter autrement qu'en tuant la fenêtre, et finissait sans le
## dire. Trois cartes réparent ça, dans le style du bandeau : sobres, sombres,
## sans un ornement de plus que nécessaire.
class_name Menus
extends CanvasLayer

signal commencer(reprendre: bool)
signal recommencer
signal quitter

enum Carte { AUCUNE, TITRE, PAUSE, FIN }

var carte: Carte = Carte.AUCUNE

var _voile: ColorRect = null
var _titre: Label = null
var _sous_titre: Label = null
var _boutons: VBoxContainer = null

func _ready() -> void:
	layer = 20
	# Les cartes vivent PENDANT la pause : c'est leur raison d'être.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_voile = ColorRect.new()
	_voile.color = Color(0.05, 0.045, 0.04, 0.0)
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_voile)

	var colonne: VBoxContainer = VBoxContainer.new()
	colonne.set_anchors_preset(Control.PRESET_CENTER)
	colonne.grow_horizontal = Control.GROW_DIRECTION_BOTH
	colonne.grow_vertical = Control.GROW_DIRECTION_BOTH
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_theme_constant_override(&"separation", 10)
	_voile.add_child(colonne)

	_titre = Label.new()
	_titre.add_theme_font_size_override(&"font_size", 44)
	_titre.add_theme_color_override(&"font_color", Color(0.93, 0.90, 0.83))
	_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(_titre)

	_sous_titre = Label.new()
	_sous_titre.add_theme_font_size_override(&"font_size", 16)
	_sous_titre.add_theme_color_override(&"font_color", Color(0.72, 0.68, 0.60))
	_sous_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colonne.add_child(_sous_titre)

	var espace: Control = Control.new()
	espace.custom_minimum_size = Vector2(0.0, 18.0)
	colonne.add_child(espace)

	_boutons = VBoxContainer.new()
	_boutons.alignment = BoxContainer.ALIGNMENT_CENTER
	_boutons.add_theme_constant_override(&"separation", 6)
	colonne.add_child(_boutons)

	fermer()

func _unhandled_input(evenement: InputEvent) -> void:
	if not evenement.is_action_pressed(&"release_mouse"):
		return
	match carte:
		Carte.AUCUNE:
			ouvrir_pause()
		Carte.PAUSE:
			reprendre()
		_:
			pass

## L'écran-titre. Le jeu attend, en pause, que la saison commence.
func ouvrir_titre(sauvegarde_existante: bool) -> void:
	_montrer(Carte.TITRE, "Le Sel de Guérande",
		"Un marais. Une saison. Deux sels.", 0.55)
	if sauvegarde_existante:
		_bouton("Reprendre la saison", func() -> void:
			fermer()
			commencer.emit(true))
	_bouton("Nouvelle saison", func() -> void:
		fermer()
		commencer.emit(false))
	_bouton("Quitter", func() -> void: quitter.emit())

func ouvrir_pause() -> void:
	_montrer(Carte.PAUSE, "Pause", "La marée n'attend pas — mais elle veut bien.", 0.62)
	_bouton("Reprendre", reprendre)
	_bouton("Recommencer la saison", func() -> void: recommencer.emit())
	_bouton("Sauvegarder et quitter", func() -> void: quitter.emit())

## La fin : la seule chose que le tutoriel promettait de dire.
func ouvrir_fin() -> void:
	_montrer(Carte.FIN, "La saison est commencée.",
		"L'étier est ouvert, la fleur est cueillie. La suite descendra, comme l'eau.", 0.55)
	_bouton("Rester sur le marais", reprendre)
	_bouton("Recommencer la saison", func() -> void: recommencer.emit())
	_bouton("Quitter", func() -> void: quitter.emit())

func reprendre() -> void:
	fermer()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func fermer() -> void:
	carte = Carte.AUCUNE
	_voile.visible = false
	get_tree().paused = false

func _montrer(quoi: Carte, titre: String, sous_titre: String,
		opacite: float) -> void:
	carte = quoi
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_titre.text = titre
	_sous_titre.text = sous_titre
	_voile.color.a = opacite
	_voile.visible = true
	for enfant: Node in _boutons.get_children():
		enfant.queue_free()

func _bouton(texte: String, action: Callable) -> void:
	var bouton: Button = Button.new()
	bouton.text = texte
	bouton.flat = true
	bouton.custom_minimum_size = Vector2(300.0, 40.0)
	bouton.add_theme_font_size_override(&"font_size", 18)
	bouton.add_theme_color_override(&"font_color", Color(0.88, 0.85, 0.78))
	bouton.add_theme_color_override(&"font_hover_color", Color(1.0, 0.97, 0.90))
	var _c: int = bouton.pressed.connect(action)
	_boutons.add_child(bouton)
	if _boutons.get_child_count() == 1:
		bouton.grab_focus()
