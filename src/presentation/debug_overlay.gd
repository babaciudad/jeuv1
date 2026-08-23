## Affichage de diagnostic réseau, masqué par défaut, bascule avec F3.
##
## Invariant 2 : la présentation lit la simulation, dans ce sens et seulement
## celui-là. Ce nœud n'écrit rien et ne décide rien.
extends Label

@export var bootstrap_path: NodePath

var _bootstrap: NetBootstrap

func _ready() -> void:
	visible = false
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	add_theme_constant_override("outline_size", 5)
	var node: Node = get_node_or_null(bootstrap_path)
	if node is NetBootstrap:
		_bootstrap = node as NetBootstrap

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_diagnostics"):
		visible = not visible
	if not visible or _bootstrap == null or _bootstrap.simulation == null:
		return
	var lines: PackedStringArray = PackedStringArray()
	if not _bootstrap.options.label.is_empty():
		lines.append(_bootstrap.options.label)
	lines.append(_bootstrap.options.describe())
	lines.append("tick %d  images/s %d" % [
		_bootstrap.simulation.current_tick, Engine.get_frames_per_second()])
	if _bootstrap.clock != null:
		lines.append("ecart %d  aller-retour %.1f ms" % [
			_bootstrap.simulation.tick_error(),
			float(_bootstrap.clock.last_rtt_usec) / 1000.0])
		lines.append("recalages %d  rendu au tick %.1f" % [
			_bootstrap.sync.resyncs, _bootstrap.sync.render_tick()])
	else:
		lines.append("autorite locale")
	if _bootstrap.world != null:
		lines.append("acteurs %d  raccourci %s" % [
			_bootstrap.world.actors.size(),
			"ouvert" if _bootstrap.world.shortcut_open else "ferme"])
	if _bootstrap.transport != null:
		lines.append("pairs %s" % str(_bootstrap.transport.peer_ids()))
	lines.append("commandes en retard %d" % _bootstrap.simulation.buffer.dropped_late)
	text = "\n".join(lines)
