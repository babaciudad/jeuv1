## Interface : vie, endurance, boss, invites.
##
## Invariant 2 : lecture seule sur la simulation. L'interface n'a aucun moyen
## d'agir sur le monde, et c'est volontaire — une barre de vie qui pourrait
## soigner serait un bug attendant son heure.
class_name Hud
extends Control

const BAR_WIDTH: float = 320.0
const BAR_HEIGHT: float = 18.0
const MARGIN: float = 20.0

const COLOR_BACK: Color = Color(0.06, 0.05, 0.07, 0.85)
const COLOR_HEALTH: Color = Color(0.72, 0.22, 0.20)
const COLOR_STAMINA: Color = Color(0.45, 0.66, 0.32)
const COLOR_BOSS: Color = Color(0.60, 0.35, 0.78)

@export var bootstrap_path: NodePath

var _bootstrap: NetBootstrap
var _health_fill: ColorRect
var _stamina_fill: ColorRect
var _boss_root: Control
var _boss_fill: ColorRect
var _boss_label: Label
var _prompt: Label
var _status: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var node: Node = get_node_or_null(bootstrap_path)
	if node is NetBootstrap:
		_bootstrap = node as NetBootstrap

	_health_fill = _make_bar(Vector2(MARGIN, MARGIN), BAR_WIDTH, BAR_HEIGHT, COLOR_HEALTH)
	_stamina_fill = _make_bar(Vector2(MARGIN, MARGIN + BAR_HEIGHT + 6.0),
		BAR_WIDTH, BAR_HEIGHT * 0.7, COLOR_STAMINA)
	_build_boss_bar()
	_prompt = _make_label(24, Color(0.95, 0.90, 0.75))
	_status = _make_label(34, Color(0.90, 0.35, 0.30))

func _make_bar(at: Vector2, width: float, height: float, color: Color) -> ColorRect:
	var back: ColorRect = ColorRect.new()
	back.color = COLOR_BACK
	back.position = at
	back.size = Vector2(width, height)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var fill: ColorRect = ColorRect.new()
	fill.color = color
	fill.position = Vector2(2.0, 2.0)
	fill.size = Vector2(width - 4.0, height - 4.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	return fill

func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = ""
	add_child(label)
	return label

func _build_boss_bar() -> void:
	_boss_root = Control.new()
	_boss_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_root.visible = false
	add_child(_boss_root)
	var back: ColorRect = ColorRect.new()
	back.color = COLOR_BACK
	back.size = Vector2(BAR_WIDTH * 1.8, BAR_HEIGHT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_root.add_child(back)
	_boss_fill = ColorRect.new()
	_boss_fill.color = COLOR_BOSS
	_boss_fill.position = Vector2(2.0, 2.0)
	_boss_fill.size = Vector2(BAR_WIDTH * 1.8 - 4.0, BAR_HEIGHT - 4.0)
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_boss_fill)
	_boss_label = Label.new()
	_boss_label.position = Vector2(0.0, -26.0)
	_boss_label.size = Vector2(BAR_WIDTH * 1.8, 24.0)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_boss_label.add_theme_constant_override("outline_size", 6)
	_boss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_root.add_child(_boss_label)

func _process(_delta: float) -> void:
	var viewport: Vector2 = get_viewport_rect().size
	_prompt.size = Vector2(viewport.x, 30.0)
	_prompt.position = Vector2(0.0, viewport.y - 110.0)
	_status.size = Vector2(viewport.x, 40.0)
	_status.position = Vector2(0.0, viewport.y * 0.42)
	_boss_root.position = Vector2((viewport.x - BAR_WIDTH * 1.8) * 0.5, viewport.y - 64.0)

	if _bootstrap != null and not _bootstrap.failure_reason.is_empty():
		_status.text = _bootstrap.failure_reason
		_prompt.text = ""
		return
	if _bootstrap == null or _bootstrap.world == null:
		_status.text = "connexion..."
		return
	var world: World = _bootstrap.world
	var actor: Actor = world.local_actor()
	if actor == null:
		_status.text = "en attente de l'hote..."
		return

	_health_fill.size.x = (BAR_WIDTH - 4.0) * _ratio(actor.health, actor.max_health)
	_stamina_fill.size.x = (BAR_WIDTH - 4.0) \
		* _ratio(actor.stamina_centi, actor.max_stamina_centi)
	_status.text = _status_text(actor)
	_prompt.text = _prompt_text(world, actor)
	_refresh_boss(world, actor)

func _ratio(value: int, maximum: int) -> float:
	if maximum <= 0:
		return 0.0
	return clampf(float(value) / float(maximum), 0.0, 1.0)

func _status_text(actor: Actor) -> String:
	if actor.is_alive():
		return ""
	return "VOUS ETES MORT"

func _prompt_text(world: World, actor: Actor) -> String:
	if not actor.is_alive():
		return "un allie doit se reposer au feu, ou attendez"
	var level: LevelData = world.level
	if not world.shortcut_open \
			and actor.position.distance_to(level.shortcut_switch_position) <= level.shortcut_switch_radius:
		return "E — ouvrir le raccourci"
	if actor.position.distance_to(level.bonfire_position) <= level.bonfire_radius:
		return "E — se reposer au feu"
	return ""

func _refresh_boss(world: World, actor: Actor) -> void:
	var boss: Actor = null
	for enemy: Actor in world.enemies():
		var data: EnemyData = world.data_for(enemy)
		if data != null and data.is_boss:
			boss = enemy
			break
	if boss == null or not boss.is_alive() \
			or actor.position.distance_to(boss.position) > 22.0:
		_boss_root.visible = false
		return
	_boss_root.visible = true
	_boss_fill.size.x = (BAR_WIDTH * 1.8 - 4.0) * _ratio(boss.health, boss.max_health)
	var data: EnemyData = world.data_for(boss)
	_boss_label.text = String(data.id) if data != null else "boss"
