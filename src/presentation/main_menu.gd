## Écran d'accueil : choix de la classe, hôte ou client, tutoriel.
##
## Invariant 2 : le menu est de la présentation. Il ne simule rien — il
## remplit un NetOptions et passe la main à la scène de jeu.
##
## Lancé avec --host ou --connect sur la ligne de commande, il s'efface
## aussitôt : tools/netharness.ps1 doit pouvoir démarrer quatre instances sans
## que quelqu'un clique quatre fois.
class_name MainMenu
extends Control

const GAME_SCENE: String = "res://scenes/game.tscn"

const COLOR_BACK: Color = Color(0.06, 0.055, 0.075)
const COLOR_CARD: Color = Color(0.13, 0.12, 0.16)
const COLOR_CARD_ON: Color = Color(0.24, 0.22, 0.28)
const COLOR_TEXT: Color = Color(0.90, 0.88, 0.82)
const COLOR_DIM: Color = Color(0.62, 0.60, 0.58)

var _classes: Array[PlayerData] = []
var _cards: Array[Button] = []
var _selected: int = 0
var _hosting: bool = true
var _host_button: Button
var _join_button: Button
var _address: LineEdit
var _port: LineEdit
var _summary: Label
var _tutorial: CheckBox

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_classes()
	if _launch_from_command_line():
		return
	_build()

## Une instance lancée avec des arguments réseau ne passe pas par le menu.
func _launch_from_command_line() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not (args.has("--host") or args.has("--connect")):
		return false
	_start(NetOptions.from_command_line())
	return true

func _load_classes() -> void:
	for path: String in NetBootstrap.CLASS_PATHS:
		var fiche: PlayerData = load(path)
		if fiche != null:
			_classes.append(fiche)

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build() -> void:
	var back: ColorRect = ColorRect.new()
	back.color = COLOR_BACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 14)
	column.offset_left = 60.0
	column.offset_right = -60.0
	column.offset_top = 40.0
	column.offset_bottom = -40.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)

	column.add_child(_title("SOULS-LIKE", 46, COLOR_TEXT))
	column.add_child(_title("tranche verticale — coopératif jusqu'à 4", 17, COLOR_DIM))
	column.add_child(_spacer(18))
	column.add_child(_title("CHOISIS TA CLASSE", 20, COLOR_TEXT))

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for index: int in _classes.size():
		var card: Button = _make_card(_classes[index])
		card.pressed.connect(_on_card_pressed.bind(index))
		row.add_child(card)
		_cards.append(card)

	_summary = _title("", 17, COLOR_DIM)
	_summary.custom_minimum_size = Vector2(0.0, 46.0)
	column.add_child(_summary)
	column.add_child(_spacer(10))

	column.add_child(_build_network_row())
	column.add_child(_spacer(6))

	_tutorial = CheckBox.new()
	_tutorial.text = "  Afficher le tutoriel"
	_tutorial.button_pressed = true
	_tutorial.add_theme_font_size_override("font_size", 17)
	_tutorial.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_tutorial)
	column.add_child(_spacer(12))

	var play: Button = Button.new()
	play.text = "JOUER"
	play.add_theme_font_size_override("font_size", 26)
	play.custom_minimum_size = Vector2(260.0, 56.0)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_on_play_pressed)
	column.add_child(play)

	column.add_child(_spacer(8))
	column.add_child(_title("ZQSD déplacement · souris caméra · clic gauche et droit attaques · "
		+ "espace roulade · E interagir · F3 diagnostic", 14, COLOR_DIM))

	_on_card_pressed(0)
	_set_hosting(true)

func _build_network_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	_host_button = Button.new()
	_host_button.text = "Héberger"
	_host_button.toggle_mode = true
	_host_button.custom_minimum_size = Vector2(130.0, 38.0)
	_host_button.pressed.connect(_set_hosting.bind(true))
	row.add_child(_host_button)

	_join_button = Button.new()
	_join_button.text = "Rejoindre"
	_join_button.toggle_mode = true
	_join_button.custom_minimum_size = Vector2(130.0, 38.0)
	_join_button.pressed.connect(_set_hosting.bind(false))
	row.add_child(_join_button)

	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "adresse de l'hôte"
	_address.custom_minimum_size = Vector2(190.0, 38.0)
	row.add_child(_address)

	_port = LineEdit.new()
	_port.text = str(NetOptions.DEFAULT_PORT)
	_port.custom_minimum_size = Vector2(90.0, 38.0)
	row.add_child(_port)
	return row

func _make_card(fiche: PlayerData) -> Button:
	var card: Button = Button.new()
	card.text = fiche.display_name
	card.toggle_mode = true
	card.custom_minimum_size = Vector2(180.0, 96.0)
	card.add_theme_font_size_override("font_size", 22)
	card.add_theme_color_override("font_color", fiche.color)
	card.add_theme_color_override("font_hover_color", fiche.color.lightened(0.3))
	card.add_theme_color_override("font_pressed_color", fiche.color.lightened(0.3))
	return card

func _title(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _spacer(height: float) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	return spacer

# ---------------------------------------------------------------------------
# Interactions
# ---------------------------------------------------------------------------

func _on_card_pressed(index: int) -> void:
	_selected = index
	for card_index: int in _cards.size():
		var chosen: bool = card_index == index
		_cards[card_index].button_pressed = chosen
		# Le style « enfoncé » d'un bouton assombrit : sans ce contraste, la
		# carte choisie se lit comme désactivée plutôt que comme choisie.
		_cards[card_index].modulate = Color(1.0, 1.0, 1.0) if chosen \
			else Color(0.52, 0.52, 0.55)
	if index < _classes.size():
		var fiche: PlayerData = _classes[index]
		_summary.text = "%s\n%d points de vie · %d endurance · %d poise" % [
			fiche.summary, fiche.max_health, fiche.max_stamina, fiche.max_poise]

func _set_hosting(hosting: bool) -> void:
	_hosting = hosting
	_host_button.button_pressed = hosting
	_join_button.button_pressed = not hosting
	# Une adresse ne sert à rien quand on héberge : la griser évite la
	# question « pourquoi ça ne marche pas ».
	_address.editable = not hosting
	_address.modulate = Color(1.0, 1.0, 1.0, 0.45 if hosting else 1.0)

func _on_play_pressed() -> void:
	var options: NetOptions = NetOptions.new()
	options.role = NetOptions.Role.HOST if _hosting else NetOptions.Role.CLIENT
	options.address = _address.text.strip_edges()
	options.port = clampi(_port.text.to_int(), 1024, 65535)
	options.class_index = _selected
	options.label = _classes[_selected].display_name if _selected < _classes.size() else ""
	options.show_tutorial = _tutorial.button_pressed
	_start(options)

## Remplace le menu par la scène de jeu. Les options sont posées AVANT
## l'entrée dans l'arbre : NetBootstrap monte sa session dans son _ready.
func _start(options: NetOptions) -> void:
	var packed: PackedScene = load(GAME_SCENE)
	var scene: Node = packed.instantiate()
	var net: Node = scene.get_node_or_null("Net")
	if net is NetBootstrap:
		(net as NetBootstrap).configure(options)
	get_tree().root.add_child.call_deferred(scene)
	queue_free()
