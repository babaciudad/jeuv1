## Affichage de diagnostic réseau.
##
## Invariant 2 : la présentation lit la simulation, dans ce sens et seulement
## celui-là. Ce nœud n'écrit rien, ne décide rien, et vit dans _process — pas
## dans _physics_process : rafraîchir plus souvent qu'un tick n'apporterait
## rien, rafraîchir moins ne coûte rien.
extends Label

@export var bootstrap_path: NodePath

var _bootstrap: NetBootstrap

func _ready() -> void:
	var node: Node = get_node_or_null(bootstrap_path)
	if node is NetBootstrap:
		_bootstrap = node as NetBootstrap

func _process(_delta: float) -> void:
	if _bootstrap == null or _bootstrap.simulation == null:
		text = "aucune session"
		return
	var lines: PackedStringArray = PackedStringArray()
	if not _bootstrap.options.label.is_empty():
		lines.append(_bootstrap.options.label)
	lines.append(_bootstrap.options.describe())
	lines.append("tick %d" % _bootstrap.simulation.current_tick)
	if _bootstrap.clock != null:
		lines.append("cible %d (écart %d)" % [
			_bootstrap.clock.target_tick(Time.get_ticks_usec()),
			_bootstrap.simulation.tick_error()])
		lines.append("aller-retour %.1f ms" % (float(_bootstrap.clock.last_rtt_usec) / 1000.0))
	else:
		lines.append("autorité locale")
	if _bootstrap.transport != null:
		lines.append("pairs %s" % str(_bootstrap.transport.peer_ids()))
	lines.append("commandes en retard %d" % _bootstrap.simulation.buffer.dropped_late)
	text = "\n".join(lines)
