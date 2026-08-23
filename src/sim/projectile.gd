## Projectile en vol.
##
## Ne porte aucune position : elle se déduit du tick courant. Deux machines qui
## connaissent l'origine, la direction et le tick de départ obtiennent la même
## trajectoire à la case près, sans échanger un seul octet de plus.
class_name Projectile
extends RefCounted

var id: int = 0
## Acteur qui a tiré. Sert à savoir qui déclare la touche (invariant 5) et à
## ne pas se toucher soi-même.
var owner_id: int = 0
## Index de l'attaque dans les données du tireur, pour retrouver dégâts et
## vitesse sans les recopier ici.
var attack_index: int = 0
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2(0.0, 1.0)
var spawn_tick: int = 0
## Marqué à la première touche ou au premier mur : un projectile ne traverse
## rien et ne touche qu'une fois.
var spent: bool = false

## Identifiant déduit du tireur et du tick de départ, donc identique sur
## toutes les machines. C'est ce qui permet au client de prédire son propre tir
## sans que l'instantané de l'hôte n'en crée un second à côté.
static func make_id(shooter_id: int, fired_at_tick: int) -> int:
	return shooter_id * 4096 + (fired_at_tick % 4096)

func position_at(tick: int, speed: float) -> Vector2:
	var elapsed: int = maxi(0, tick - spawn_tick)
	return origin + direction * speed * (float(elapsed) * SimConfig.TICK_DURATION_SEC)

func age(tick: int) -> int:
	return tick - spawn_tick
