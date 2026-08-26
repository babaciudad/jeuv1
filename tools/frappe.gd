## Ou la simulation frappe, contre ou l'arme se trouve VRAIMENT.
##
##   [autoload]
##   _Frappe="*res://tools/frappe.gd"
##   godot --path . --fixed-fps 60 -- --host
##
## La simulation resout un cone : sommet a `actor.position`, axe `actor.facing`.
## Le joueur, lui, ne voit pas un cone : il voit une arme. Si les deux ne sont
## pas au meme endroit, le coup « ne tape pas au bon endroit », et aucun
## reglage de portee n'y changera rien.
##
## On mesure donc, a l'image PRECISE ou la boite s'ouvre : la position et le
## cap de la simulation, et la position monde du fer de l'arme.
extends Node

var _frame: int = 0
var _boot: NetBootstrap = null
var _view: GameView = null
var _dit: bool = false
var _loin: float = -1.0
var _pres: float = 1e9
var _gauche: float = -180.0
var _droite: float = 180.0
var _images: int = 0
var _quoi: StringName = &""
var _rang: int = 0

## Les gestes sont ceux de la CLASSE INCARNEE : on ne peut pas mesurer le
## coup de dague de l'archer en jouant le gardien. Une passe par classe, via
## `--class 0..3`. Les tirs n'ont pas de fer qui balaie : ils sont ecartes.
var _gestes: Array[StringName] = []
## Une attaque toutes les deux secondes : le temps qu'elle s'ouvre, se ferme
## et que la recuperation laisse repartir la suivante.
const PERIODE: int = 120
const DEPART: int = 60

func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_walk(child))
	return out

func _fer(vue: ActorView) -> Node3D:
	# Les pieces sont greffees sous une attache par os, nommee `Sel_<os>`.
	# L'arme pend a la main droite : on prend, sous cette attache, le maillage
	# le plus eloigne du poignet — c'est le bout du fer.
	var attache: Node3D = null
	for node: Node in _walk(vue):
		if node is Node3D and node.name == "Sel_hand_r":
			attache = node as Node3D
			break
	if attache == null:
		return null
	var loin: Node3D = null
	var mieux: float = -1.0
	for node: Node in _walk(attache):
		if not (node is MeshInstance3D):
			continue
		var n3: Node3D = node as Node3D
		var d: float = n3.global_position.distance_to(attache.global_position)
		if d > mieux:
			mieux = d
			loin = n3
	return loin

func _process(_delta: float) -> void:
	_frame += 1
	if _boot == null:
		for node: Node in _walk(get_tree().root):
			if node is NetBootstrap:
				_boot = node as NetBootstrap
			if node is GameView:
				_view = node as GameView
	if _boot == null or _view == null:
		if _frame > 400:
			get_tree().quit(1)
		return
	var world: World = _view.simulated_world()
	if world == null:
		return
	var moi: Actor = world.local_actor()
	if moi == null:
		return
	if _frame == 20:
		moi.position = Vector2(0.0, 14.0)
		moi.facing = Vector2(0.0, 1.0)
	if _gestes.is_empty():
		var fiches: Array[AttackData] = world.attacks_for(moi)
		if fiches.is_empty():
			return
		for fiche: AttackData in fiches:
			if fiche != null and fiche.projectile == null:
				_gestes.append(fiche.id)
		print("[frappe] gestes au corps-a-corps : %s" % str(_gestes))
	if _frame >= DEPART and (_frame - DEPART) % PERIODE == 0:
		if _rang > 0:
			_rapport()
		if _rang >= _gestes.size():
			get_tree().quit(0)
			return
		_quoi = _gestes[_rang]
		_rang += 1
		moi.facing = Vector2(0.0, 1.0)
		_boot.submit_command(Command.Type.ATTACK, {"a": _quoi})
	if moi.runner != null and moi.runner.hitbox_open:
		var vue: ActorView = null
		for node: Node in _walk(get_tree().root):
			if node is ActorView and (node as ActorView).uses_model():
				vue = node as ActorView
				break
		if vue != null:
			var fer: Node3D = _fer(vue)
			if fer != null:
				var p: Vector3 = fer.global_position
				var vers: Vector2 = Vector2(p.x, p.z) - moi.position
				var angle: float = rad_to_deg(moi.facing.angle_to(vers))
				_loin = maxf(_loin, vers.length())
				_pres = minf(_pres, vers.length())
				_gauche = maxf(_gauche, angle)
				_droite = minf(_droite, angle)
				_images += 1

func _rapport() -> void:
	if _images == 0:
		print("[frappe] %s : boite jamais ouverte" % _quoi)
		return
	var fiche: AttackData = load("res://data/attacks/%s.tres" % _quoi)
	var milieu: float = (_gauche + _droite) * 0.5
	var demi: float = (_gauche - _droite) * 0.5
	print("[frappe] %-16s fer %.2f a %.2f m, balaie %+.0f a %+.0f "
		% [_quoi, _pres, _loin, _droite, _gauche]
		+ "(centre %+.0f, demi %.0f)  |  fiche portee %.2f demi-angle %.0f"
		% [milieu, demi, fiche.range_meters, fiche.half_angle_degrees])
	_loin = -1.0
	_pres = 1e9
	_gauche = -180.0
	_droite = 180.0
	_images = 0
