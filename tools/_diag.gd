extends SceneTree
var _frames: int = 0
var _net: NetBootstrap
func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/game.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	_net = scene.get_node("Net") as NetBootstrap
func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 400:
		return false
	for joueur: Actor in _net.world.players():
		var fiche: PlayerData = _net.world.class_for(joueur)
		print("joueur %d : classe=%d (%s) pv=%d/%d"
			% [joueur.id, joueur.data_index,
				fiche.display_name if fiche != null else "?", joueur.health, joueur.max_health])
	return true
